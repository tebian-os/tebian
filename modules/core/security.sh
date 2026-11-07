#!/bin/bash
# ==============================================================================
# TEBIAN SECURITY MODULE
# Usage: bash security.sh [minimal|standard|hardened|paranoid|paranoid-off|tor-on|tor-off|
#                         dns-on [quad9|cloudflare]|dns-off|mac-on|mac-off|ssh-keyonly|ssh-password]
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[security]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[security]${NC} $1"; }
log_error() { echo -e "${RED}[security]${NC} $1" >&2; }

PROFILE="${1:-standard}"
# Present exactly while paranoid mode's transparent Tor is set up
TOR_RULES=/etc/tebian-tor-iptables.sh
# Key-only SSH. sshd keeps the FIRST value it reads for a setting and reads
# sshd_config.d/*.conf in name order, so this must sort before anything
# else there (cloud-init's 50-cloud-init.conf turns passwords on)
SSH_KEYONLY=/etc/ssh/sshd_config.d/00-tebian-keyonly.conf
SSH_KEYONLY_OLD=/etc/ssh/sshd_config.d/99-tebian-keyonly.conf

# --- Helper functions ---

ensure_ufw() {
    if ! command -v ufw &>/dev/null; then
        sudo apt install -y ufw
    fi
}

ensure_fail2ban() {
    if ! command -v fail2ban-client &>/dev/null; then
        sudo apt install -y fail2ban
    fi
}

ensure_apparmor() {
    if ! command -v aa-enforce &>/dev/null; then
        sudo apt install -y apparmor apparmor-utils
    fi
}

# Launchers start apps from their .desktop Exec= line, which Debian writes
# as an absolute path (/usr/bin/chromium, /usr/lib/firefox-esr/...) — that
# bypasses a /usr/local/bin symlink entirely. So each sandboxed browser also
# gets a per-user .desktop override that runs it through firejail.
FIREJAIL_MARK="X-Tebian-Firejail=true"
APPS_DIR="$HOME/.local/share/applications"

desktop_file_for() {
    case "$1" in
        google-chrome-stable) echo google-chrome.desktop ;;
        *) echo "$1.desktop" ;;
    esac
}

firejail_symlink() {
    local bin="$1" desktop
    if command -v firejail &>/dev/null && command -v "$bin" &>/dev/null; then
        sudo ln -sf /usr/bin/firejail "/usr/local/bin/$bin"
        desktop=$(desktop_file_for "$bin")
        if [ -f "/usr/share/applications/$desktop" ]; then
            mkdir -p "$APPS_DIR"
            # Rebuilt from the system file each time, so it never stacks
            # "firejail firejail" and picks up package changes
            sed -E -e 's|^Exec=|Exec=firejail |' \
                   -e "0,/^\[Desktop Entry\]/s||[Desktop Entry]\n$FIREJAIL_MARK|" \
                "/usr/share/applications/$desktop" > "$APPS_DIR/$desktop"
        fi
        log_info "Firejail sandbox enabled for $bin"
    fi
}

# Every /usr/local/bin link into firejail — the profiles link browsers,
# the Settings menu also mail and chat apps
firejail_linked_apps() {
    local link
    for link in /usr/local/bin/*; do
        [ -L "$link" ] && [[ "$(readlink "$link")" == */firejail ]] && basename "$link"
    done
    return 0
}

firejail_remove_symlink() {
    local bin="$1" desktop
    desktop=$(desktop_file_for "$bin")
    if [ -L "/usr/local/bin/$bin" ] && readlink "/usr/local/bin/$bin" | grep -q firejail; then
        sudo rm -f "/usr/local/bin/$bin"
        log_info "Firejail sandbox removed for $bin"
    fi
    # Only our own override — never a .desktop file the user made
    if grep -qsxF "$FIREJAIL_MARK" "$APPS_DIR/$desktop"; then
        rm -f "$APPS_DIR/$desktop"
    fi
}

# --- SSH safety ---
# The account that would be locked out: the invoking user, even under sudo
ssh_user_home() {
    if [ -n "${SUDO_USER:-}" ]; then getent passwd "$SUDO_USER" | cut -d: -f6; else echo "$HOME"; fi
}

has_ssh_key() {
    grep -qsE '^[^#]*(ssh-(ed25519|rsa|dss)|ecdsa-sha2-|sk-(ssh|ecdsa))' "$(ssh_user_home)/.ssh/authorized_keys"
}

sshd_in_use() {
    local u
    for u in ssh.service ssh.socket; do
        systemctl is-active --quiet "$u" 2>/dev/null && return 0
        systemctl is-enabled --quiet "$u" 2>/dev/null && return 0
    done
    return 1
}

# Every port sshd actually listens on: its effective config (a custom Port
# is common on servers), a socket-activated ssh.socket, and — if this very
# session came in over SSH — the port it arrived on, whatever the config says
ssh_ports() {
    local ports=""
    if sshd_in_use; then
        ports=$(sudo sshd -T 2>/dev/null | awk '$1 == "port" { print $2 }')
        ports+=" $(systemctl show ssh.socket -p Listen --value 2>/dev/null |
                   grep -oE ':[0-9]+ \(Stream\)' | grep -oE '[0-9]+')"
        [ -n "${ports// /}" ] || ports=22
    fi
    [ -n "${SSH_CONNECTION:-}" ] && ports+=" $(echo "$SSH_CONNECTION" | awk '{ print $4 }')"
    echo "$ports" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -un
}

# Undo what hardened adds, when moving to a lower profile
remove_hardening() {
    if [ -f /etc/sysctl.d/99-tebian-hardening.conf ]; then
        sudo rm -f /etc/sysctl.d/99-tebian-hardening.conf
        sudo sysctl --system >/dev/null 2>&1 || true
        log_info "Removed hardened kernel settings (defaults fully return after a reboot)"
    fi
    if [ -f "$SSH_KEYONLY" ] || [ -f "$SSH_KEYONLY_OLD" ]; then
        ssh_password_on
    fi
}

ssh_reload() {
    sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
}

# What sshd will actually do — another drop-in can still win, and saying
# "key-only" while passwords work would be worse than saying nothing
sshd_password_auth() {
    local cfg
    cfg=$(sudo sshd -T 2>/dev/null) || return 1
    awk '$1 == "passwordauthentication" { print $2; exit }' <<< "$cfg"
}

ssh_keyonly_on() {
    # Never without a key to log in with: on a headless Pi reached over
    # SSH, disabling passwords first would be a lockout
    if ! has_ssh_key; then
        log_warn "SSH password login left ON: no key in $(ssh_user_home)/.ssh/authorized_keys."
        log_warn "Add one (ssh-copy-id from your other machine), then try again."
        return 1
    fi
    sudo mkdir -p /etc/ssh/sshd_config.d
    printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nX11Forwarding no\n' |
        sudo tee "$SSH_KEYONLY" >/dev/null
    sudo rm -f "$SSH_KEYONLY_OLD"
    if ! command -v sshd >/dev/null && [ ! -x /usr/sbin/sshd ]; then
        log_info "SSH set to key-only authentication (applies once openssh-server is installed)"
        return 0
    fi
    # The 00- file is read first and wins, so it can make someone's own
    # setup invalid (e.g. AuthenticationMethods needing keyboard-interactive
    # for 2FA). A reload then fails quietly and the running sshd carries on,
    # but sshd would refuse to start at the next boot: a headless machine
    # would be locked out. Check first and back out if sshd rejects it.
    if ! sudo sshd -t 2>/dev/null; then
        sudo rm -f "$SSH_KEYONLY"
        log_warn "SSH left as it was: key-only conflicts with your sshd settings."
        log_warn "To see why, test it by hand: sudo sshd -t"
        return 1
    fi
    ssh_reload
    if [ "$(sshd_password_auth)" = no ]; then
        log_info "SSH set to key-only authentication"
    else
        log_warn "SSH still accepts passwords — another file in /etc/ssh overrides it."
        log_warn "Check: sudo sshd -T | grep -i passwordauthentication"
        return 1
    fi
}

ssh_password_on() {
    sudo rm -f "$SSH_KEYONLY" "$SSH_KEYONLY_OLD"
    ssh_reload
    log_info "SSH password logins allowed again"
}

# --- Profile handlers ---

apply_minimal() {
    log_info "Applying MINIMAL security profile..."

    # Disable UFW if active
    if command -v ufw &>/dev/null; then
        sudo ufw disable 2>/dev/null || true
        log_info "Firewall disabled"
    fi

    # Stop fail2ban if running
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        sudo systemctl stop fail2ban
        sudo systemctl disable fail2ban
        log_info "fail2ban disabled"
    fi

    # AppArmor is left as Debian ships it. Putting every profile into
    # complain mode would make "minimal" weaker than a stock Debian install.

    # Remove every Firejail link, the ones Settings added for mail and chat
    # apps included
    local app
    for app in $(firejail_linked_apps); do
        firejail_remove_symlink "$app"
    done

    log_info "Minimal profile applied"
}

apply_standard() {
    log_info "Applying STANDARD security profile..."

    # UFW
    ensure_ufw
    sudo ufw default deny incoming
    local port
    for port in $(ssh_ports); do
        sudo ufw allow "$port/tcp" comment 'SSH' >/dev/null
        log_info "Firewall: SSH port $port kept open"
    done
    sudo ufw --force enable
    log_info "Firewall enabled (deny incoming)"

    # fail2ban
    ensure_fail2ban
    sudo systemctl enable --now fail2ban
    log_info "fail2ban enabled"

    # AppArmor on, with Debian's profiles in the modes Debian ships them.
    # Force-enforcing everything (aa-enforce /etc/apparmor.d/*) flips
    # profiles Debian deliberately ships in complain mode or disabled, and
    # breaks apps in ways that are hard to trace back to this.
    ensure_apparmor
    sudo systemctl enable --now apparmor 2>/dev/null || true
    if [ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = Y ]; then
        log_info "AppArmor active"
    else
        log_warn "AppArmor is not enabled in this kernel — its profiles have no effect here"
    fi

    # Firejail for browsers
    if ! command -v firejail &>/dev/null; then
        sudo apt install -y firejail firejail-profiles
    fi
    firejail_symlink firefox
    firejail_symlink firefox-esr
    firejail_symlink chromium
    firejail_symlink chromium-browser
    firejail_symlink google-chrome-stable

    log_info "Standard profile applied"
}

apply_hardened() {
    log_info "Applying HARDENED security profile..."

    # Start with standard
    apply_standard

    # Extended kernel hardening
    cat <<'EOF' | sudo tee /etc/sysctl.d/99-tebian-hardening.conf
# Tebian hardened profile
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1
kernel.dmesg_restrict=1
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.icmp_echo_ignore_broadcasts=1
# "-": skipped rather than an error where IPv6 is off (ipv6.disable=1)
-net.ipv6.conf.all.accept_redirects=0
-net.ipv6.conf.default.accept_redirects=0
EOF
    # -e: a key this kernel lacks mustn't abort the rest of the profile
    sudo sysctl -e -p /etc/sysctl.d/99-tebian-hardening.conf
    log_info "Extended kernel hardening applied"

    # SSH key-only (refused, with a note, when there's no key to log in with)
    ssh_keyonly_on || true

    log_info "Hardened profile applied"
}

toggle_tor_on() {
    log_info "Enabling Tor routing (per-app via proxychains4)..."
    sudo apt install -y tor proxychains4

    # Configure proxychains to use Tor
    if [ -f /etc/proxychains4.conf ]; then
        sudo sed -i 's/^strict_chain/#strict_chain/' /etc/proxychains4.conf
        sudo sed -i 's/^#dynamic_chain/dynamic_chain/' /etc/proxychains4.conf
    fi

    sudo systemctl enable --now tor
    log_info "Tor enabled. Use: proxychains4 <command> to route through Tor"
}

toggle_tor_off() {
    if [ -f "$TOR_RULES" ]; then
        # Paranoid mode sends all traffic into Tor; stopping it now would
        # just cut the network. Leaving paranoid mode stops Tor properly.
        log_warn "Transparent Tor (paranoid) is active — leave the paranoid profile to stop Tor."
        return 0
    fi
    log_info "Disabling Tor routing..."
    if systemctl is-active --quiet tor 2>/dev/null; then
        sudo systemctl stop tor
        sudo systemctl disable tor
    fi
    log_info "Tor disabled"
}

DNS_CONF=/etc/systemd/resolved.conf.d/99-tebian-dns.conf
NM_DNS_CONF=/etc/NetworkManager/conf.d/99-tebian-dns-resolved.conf

# True if a well-known name resolves within a few seconds
dns_works() {
    for _ in 1 2 3 4 5; do
        timeout 3 getent ahosts deb.debian.org >/dev/null 2>&1 && return 0
        sleep 1
    done
    return 1
}

# Settings → Security → DNS Privacy runs these too, so the menu and
# tebian-rebuild leave the machine in the same state
toggle_dns_on() {
    local provider="${2:-quad9}" servers
    case "$provider" in
        cloudflare) servers="1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com" ;;
        quad9)      servers="9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net" ;;
        *) log_error "Unknown DNS provider: $provider (quad9 or cloudflare)"; return 1 ;;
    esac
    log_info "Enabling DNS-over-TLS ($provider)..."

    # trixie ships systemd-resolved as its own package, not installed by
    # default. Installing it is the only step allowed to fail: nothing has
    # been changed yet. (Without it, a stub resolv.conf kills all DNS.)
    if ! dpkg -s systemd-resolved >/dev/null 2>&1; then
        if ! sudo apt install -y systemd-resolved; then
            log_error "Could not install systemd-resolved — DNS settings left unchanged."
            return 1
        fi
    fi

    sudo mkdir -p /etc/systemd/resolved.conf.d /etc/NetworkManager/conf.d
    printf '[Resolve]\nDNS=%s\nDNSOverTLS=yes\nDNSSEC=allow-downgrade\nDomains=~.\n' "$servers" |
        sudo tee "$DNS_CONF" >/dev/null
    # NetworkManager hands each connection's DNS to resolved instead of
    # writing resolv.conf itself
    printf '[main]\ndns=systemd-resolved\n' | sudo tee "$NM_DNS_CONF" >/dev/null
    # Failures here are caught by the check below, which rolls back; under
    # set -e they would exit with the NetworkManager conf already written
    sudo systemctl enable systemd-resolved || true
    sudo systemctl restart systemd-resolved || true

    # Only repoint resolv.conf once resolved is demonstrably up
    if ! systemctl is-active --quiet systemd-resolved || [ ! -f /run/systemd/resolve/stub-resolv.conf ]; then
        log_error "systemd-resolved did not start — rolling back."
        toggle_dns_off
        return 1
    fi
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    sudo systemctl restart NetworkManager 2>/dev/null || true

    # Some networks block port 853 (DNS-over-TLS). No DNS at all is worse
    # than no privacy.
    if ! dns_works; then
        log_error "No DNS answers over TLS (the network may block port 853) — rolling back."
        toggle_dns_off
        return 1
    fi
    log_info "DNS-over-TLS enabled ($provider)"
}

# Hand /etc/resolv.conf back to NetworkManager
toggle_dns_off() {
    log_info "Disabling DNS-over-TLS..."
    sudo rm -f "$DNS_CONF" "$NM_DNS_CONF"
    # Without NetworkManager (a server or minimal image on systemd-networkd)
    # nothing would write a new resolv.conf: keep resolved, now with the
    # network's own DNS, rather than leave the machine with none at all
    if ! systemctl is-active --quiet NetworkManager 2>/dev/null; then
        if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
            sudo systemctl restart systemd-resolved || true
        fi
        log_info "DNS-over-TLS disabled (using your network's DNS)"
        return 0
    fi
    sudo systemctl disable --now systemd-resolved 2>/dev/null || true
    # Only a symlink into systemd-resolved: a regular file here is already
    # someone else's (NetworkManager's or the admin's)
    if [ -L /etc/resolv.conf ] && readlink /etc/resolv.conf | grep -q '/systemd/resolve/'; then
        sudo rm -f /etc/resolv.conf
    fi
    # With the file gone and resolved stopped, NetworkManager writes a fresh
    # /etc/resolv.conf from the connection's DNS servers on restart
    sudo systemctl restart NetworkManager 2>/dev/null || true
    log_info "DNS-over-TLS disabled (using your network's DNS)"
}

enable_transparent_tor() {
    log_info "Enabling TRANSPARENT Tor (all traffic forced through Tor)..."
    # Everything not going through Tor is cut the moment the rules load,
    # open connections included: say so while it's still possible to stop
    local vpn
    vpn=$(ip -o link show 2>/dev/null | awk -F': ' '$2 ~ /^(tailscale|wg|tun)/ {print $2}' | tr '\n' ' ')
    if [ -n "$vpn" ]; then
        log_warn "VPN interface(s) up: ${vpn% } — they stop working under transparent Tor."
        [ -n "${SSH_CONNECTION:-}" ] && log_warn "You are connected over SSH: if that's through the VPN, this session will drop."
    fi
    sudo apt install -y tor iptables

    # Configure Tor for transparent proxy
    if ! grep -q 'TransPort' /etc/tor/torrc 2>/dev/null; then
        cat <<'EOF' | sudo tee -a /etc/tor/torrc

# Tebian transparent proxy
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 9040
DNSPort 5353
EOF
        sudo systemctl restart tor
    fi
    sudo systemctl enable --now tor

    # iptables rules to redirect all traffic through Tor
    local tor_uid
    tor_uid=$(id -u debian-tor 2>/dev/null || id -u tor 2>/dev/null) || {
        log_error "Could not find Tor user UID"
        return 1
    }
    # Tor refuses to connect with a clock that's far off, and NTP can't get
    # out (an exception wouldn't help: the NTP server's name is looked up
    # through Tor too). Boards without a clock battery (Raspberry Pi) boot
    # with the last shutdown's time, so after days off they stay offline
    # until the clock is set by hand. Fail-closed is the point of this mode.
    if [ ! -e /dev/rtc0 ]; then
        log_warn "No hardware clock: after a long power-off, Tor may not connect until"
        log_warn "the time is set by hand (sudo date -s 'YYYY-MM-DD HH:MM')."
    fi

    # Rules from before this rewrite lived directly in OUTPUT; clear them so
    # they don't linger alongside the new chains
    remove_legacy_tor_rules "$tor_uid"

    # The rules live in their own TEBIAN_TOR chains, jumped to from OUTPUT:
    # Docker, libvirt and ufw rules are never touched, and re-running
    # rebuilds the chains instead of stacking duplicates.
    #
    # Fail-closed by design: new TCP always goes to Tor's TransPort and
    # everything else outbound is rejected, so if Tor is down the machine is
    # offline rather than leaking. IPv6 is rejected outright — Tor's
    # TransPort here is IPv4-only, and dual-stack networks would otherwise
    # carry traffic straight past it.
    cat <<EOFW | sudo tee "$TOR_RULES" >/dev/null
#!/bin/bash
# Tebian transparent Tor rules — generated by modules/core/security.sh.
# Usage: $TOR_RULES [start|stop]
TOR_UID=$tor_uid
LAN="10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16"

remove() {
    local t
    for t in "iptables -w -t nat" "iptables -w" "ip6tables -w"; do
        while \$t -D OUTPUT -j TEBIAN_TOR 2>/dev/null; do :; done
        \$t -F TEBIAN_TOR 2>/dev/null || true
        \$t -X TEBIAN_TOR 2>/dev/null || true
    done
}

if [ "\${1:-start}" = stop ]; then
    remove
    exit 0
fi

set -e
remove
iptables -w -t nat -N TEBIAN_TOR
iptables -w -N TEBIAN_TOR

# nat: Tor's own traffic and loopback leave untouched; all DNS goes to
# Tor's DNSPort, whatever server it was meant for; new TCP goes to TransPort
iptables -w -t nat -A TEBIAN_TOR -m owner --uid-owner \$TOR_UID -j RETURN
iptables -w -t nat -A TEBIAN_TOR -o lo -j RETURN
iptables -w -t nat -A TEBIAN_TOR -p udp --dport 53 -j REDIRECT --to-ports 5353
# .onion addresses are mapped into 10.192.0.0/10 — inside 10/8, so this
# must come before the LAN exemption
iptables -w -t nat -A TEBIAN_TOR -p tcp -d 10.192.0.0/10 -j REDIRECT --to-ports 9040
for net in \$LAN; do iptables -w -t nat -A TEBIAN_TOR -d \$net -j RETURN; done
iptables -w -t nat -A TEBIAN_TOR -p tcp --syn -j REDIRECT --to-ports 9040

# filter: allow what was redirected (it now targets loopback), Tor itself,
# DHCP and the local network; reject the rest (UDP, ICMP, QUIC, WebRTC...)
# Established traffic only in the reply direction (answers to connections
# made TO this machine): NAT only redirects a connection's first packet, so
# a connection opened before these rules — a browser's keep-alive or
# websocket — would otherwise carry on straight past Tor.
iptables -w -A TEBIAN_TOR -m conntrack --ctstate ESTABLISHED,RELATED --ctdir REPLY -j ACCEPT
iptables -w -A TEBIAN_TOR -o lo -j ACCEPT
iptables -w -A TEBIAN_TOR -m owner --uid-owner \$TOR_UID -j ACCEPT
iptables -w -A TEBIAN_TOR -p udp --sport 68 --dport 67 -j ACCEPT
# DNS over TCP to a LAN resolver would be forwarded upstream in the clear
iptables -w -A TEBIAN_TOR -p tcp --dport 53 -j REJECT
for net in \$LAN; do iptables -w -A TEBIAN_TOR -d \$net -j ACCEPT; done
iptables -w -A TEBIAN_TOR -j REJECT

# First in OUTPUT, ahead of ufw's chains — ufw accepts new outgoing
# connections, which would let UDP out before it ever reached this chain.
# IPv4 is complete before IPv6 is touched, so an IPv6 failure can't leave
# IPv4 traffic unredirected.
iptables -w -t nat -I OUTPUT 1 -j TEBIAN_TOR
iptables -w -I OUTPUT 1 -j TEBIAN_TOR

# No IPv6 in this kernel (ipv6.disable=1): nothing to reject, and
# ip6tables would fail
[ -d /proc/sys/net/ipv6 ] || exit 0
ip6tables -w -N TEBIAN_TOR
ip6tables -w -A TEBIAN_TOR -o lo -j ACCEPT
ip6tables -w -A TEBIAN_TOR -m owner --uid-owner \$TOR_UID -j ACCEPT
ip6tables -w -A TEBIAN_TOR -j REJECT
ip6tables -w -I OUTPUT 1 -j TEBIAN_TOR
EOFW
    sudo chmod 755 "$TOR_RULES"
    sudo "$TOR_RULES" start

    # Persist across reboots. Deliberately no Requires=tor.service: the
    # rules must be in place even when Tor fails to start (fail-closed),
    # and before the network comes up at all.
    cat <<EOF | sudo tee /etc/systemd/system/tebian-tor-iptables.service >/dev/null
[Unit]
Description=Tebian Transparent Tor iptables rules
DefaultDependencies=no
After=ufw.service
Before=network-pre.target shutdown.target
Wants=network-pre.target
Conflicts=shutdown.target

[Service]
Type=oneshot
ExecStart=$TOR_RULES start
ExecStop=$TOR_RULES stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable tebian-tor-iptables.service
    # Mark the unit started (the rules were applied directly above) so a
    # later `systemctl stop` runs the stop action
    sudo systemctl start tebian-tor-iptables.service

    log_info "Transparent Tor enabled — TCP and DNS go through Tor; other traffic and IPv6 are blocked"
}

# The pre-chains version appended these straight into OUTPUT and flushed
# the entire nat table (taking Docker's and libvirt's NAT rules with it)
remove_legacy_tor_rules() {
    local uid="$1" rule
    local legacy_nat=(
        "-m owner --uid-owner $uid -j RETURN"
        "-p udp --dport 53 -j REDIRECT --to-ports 5353"
        "-p tcp --syn -j REDIRECT --to-ports 9040"
        "-p udp -j REDIRECT --to-ports 9040"
    )
    local legacy_filter=(
        "-p udp --dport 53 -m owner ! --uid-owner $uid -j REJECT"
        "-m owner --uid-owner $uid -j ACCEPT"
        "-d 127.0.0.0/8 -j ACCEPT"
        "-d 10.0.0.0/8 -j ACCEPT"
        "-d 172.16.0.0/12 -j ACCEPT"
        "-d 192.168.0.0/16 -j ACCEPT"
    )
    for rule in "${legacy_nat[@]}"; do
        # shellcheck disable=SC2086
        while sudo iptables -w -t nat -D OUTPUT $rule 2>/dev/null; do :; done
    done
    for rule in "${legacy_filter[@]}"; do
        # shellcheck disable=SC2086
        while sudo iptables -w -D OUTPUT $rule 2>/dev/null; do :; done
    done
}

disable_transparent_tor() {
    log_info "Disabling transparent Tor..."

    sudo systemctl stop tebian-tor-iptables.service 2>/dev/null || true
    if [ -x "$TOR_RULES" ]; then
        sudo "$TOR_RULES" stop
    fi
    local uid
    uid=$(id -u debian-tor 2>/dev/null || id -u tor 2>/dev/null || true)
    [ -n "$uid" ] && remove_legacy_tor_rules "$uid"

    sudo systemctl disable tebian-tor-iptables.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/tebian-tor-iptables.service
    sudo rm -f "$TOR_RULES"
    sudo systemctl daemon-reload

    # Remove transparent proxy config from torrc
    sudo sed -i '/# Tebian transparent proxy/,/^DNSPort/d' /etc/tor/torrc 2>/dev/null || true

    log_info "Transparent Tor disabled — normal networking restored"
}

enable_mac_randomization() {
    log_info "Enabling MAC address randomization..."

    sudo mkdir -p /etc/NetworkManager/conf.d
    cat <<'EOF' | sudo tee /etc/NetworkManager/conf.d/99-tebian-mac-random.conf
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF
    sudo systemctl restart NetworkManager 2>/dev/null || true
    log_info "MAC randomization enabled (new MAC on every connection)"
}

disable_mac_randomization() {
    log_info "Disabling MAC address randomization..."
    sudo rm -f /etc/NetworkManager/conf.d/99-tebian-mac-random.conf
    sudo systemctl restart NetworkManager 2>/dev/null || true
    log_info "MAC randomization disabled (using hardware MAC)"
}

apply_paranoid() {
    log_info "Applying PARANOID security profile..."
    log_warn "This will route ALL traffic through Tor and randomize your MAC address."
    log_warn "Internet will be slower. Some services may not work."

    # Start with hardened
    apply_hardened

    # MAC randomization
    enable_mac_randomization

    # DNS through Tor (disable standalone DoT — Tor handles DNS)
    if [ -f "$DNS_CONF" ]; then
        toggle_dns_off
    fi

    # Transparent Tor
    enable_transparent_tor

    log_info "PARANOID profile applied — your IP address is hidden from the sites you visit"
    log_warn "This is not full anonymity: browser fingerprinting, logged-in accounts and"
    log_warn "what you type can still identify you. For anonymous browsing use Tor Browser."
    log_warn "Verify the routing at: https://check.torproject.org"
}

revert_paranoid() {
    log_info "Reverting PARANOID profile..."

    disable_transparent_tor
    disable_mac_randomization

    # Stop Tor
    if systemctl is-active --quiet tor 2>/dev/null; then
        sudo systemctl stop tor
        sudo systemctl disable tor
    fi

    log_info "Paranoid mode disabled — normal networking restored"
}

# --- Main dispatch ---

# Moving to a lower profile undoes what the higher ones added: transparent
# Tor when leaving paranoid (MAC randomization stays — it's its own toggle,
# mac-off), hardened's kernel and SSH settings when dropping below hardened
leave_paranoid() {
    if [ -f "$TOR_RULES" ] || [ -f /etc/systemd/system/tebian-tor-iptables.service ]; then
        revert_paranoid_routing
    fi
}

revert_paranoid_routing() {
    disable_transparent_tor
    if systemctl is-active --quiet tor 2>/dev/null; then
        sudo systemctl stop tor
        sudo systemctl disable tor
    fi
}

case "$PROFILE" in
    minimal)      leave_paranoid; remove_hardening; apply_minimal ;;
    standard)     leave_paranoid; remove_hardening; apply_standard ;;
    hardened)     leave_paranoid; apply_hardened ;;
    paranoid)     apply_paranoid ;;
    paranoid-off) revert_paranoid ;;
    tor-on)       toggle_tor_on ;;
    tor-off)      toggle_tor_off ;;
    dns-on)       toggle_dns_on "$@" ;;
    dns-off)      toggle_dns_off ;;
    mac-on)       enable_mac_randomization ;;
    mac-off)      disable_mac_randomization ;;
    ssh-keyonly)  ssh_keyonly_on ;;
    ssh-password) ssh_password_on ;;
    *)
        log_error "Unknown profile: $PROFILE"
        echo "Usage: bash security.sh [minimal|standard|hardened|paranoid|paranoid-off|tor-on|tor-off|dns-on [quad9|cloudflare]|dns-off|mac-on|mac-off|ssh-keyonly|ssh-password]"
        exit 1
        ;;
esac
