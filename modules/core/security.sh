#!/bin/bash
# ==============================================================================
# TEBIAN SECURITY MODULE
# Usage: bash security.sh [minimal|standard|hardened|paranoid|tor-on|tor-off|dns-on|dns-off|mac-on|mac-off|paranoid-off]
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
    if [ -f /etc/ssh/sshd_config.d/99-tebian-keyonly.conf ]; then
        sudo rm -f /etc/ssh/sshd_config.d/99-tebian-keyonly.conf
        sudo systemctl reload ssh 2>/dev/null || true
        log_info "SSH password logins allowed again"
    fi
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

    # Remove Firejail browser symlinks
    firejail_remove_symlink firefox
    firejail_remove_symlink firefox-esr
    firejail_remove_symlink chromium
    firejail_remove_symlink chromium-browser
    firejail_remove_symlink google-chrome-stable

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
    log_info "AppArmor active"

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
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
EOF
    sudo sysctl -p /etc/sysctl.d/99-tebian-hardening.conf
    log_info "Extended kernel hardening applied"

    # SSH key-only — but never without a key to log in with. On a headless
    # Pi reached over SSH, disabling passwords first would be a lockout.
    if has_ssh_key; then
        sudo mkdir -p /etc/ssh/sshd_config.d
        printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nX11Forwarding no\n' |
            sudo tee /etc/ssh/sshd_config.d/99-tebian-keyonly.conf >/dev/null
        sudo systemctl reload ssh 2>/dev/null || true
        log_info "SSH set to key-only authentication"
    else
        log_warn "SSH password login left ON: no key in $(ssh_user_home)/.ssh/authorized_keys."
        log_warn "Add one (ssh-copy-id from your other machine), then re-apply the hardened profile."
    fi

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

toggle_dns_on() {
    local provider="${2:-quad9}"
    log_info "Enabling DNS-over-TLS ($provider)..."

    # trixie ships systemd-resolved as its own package, not installed by
    # default. Without it, pointing resolv.conf at its stub kills all DNS.
    if ! dpkg -s systemd-resolved >/dev/null 2>&1; then
        if ! sudo apt install -y systemd-resolved; then
            log_error "Could not install systemd-resolved — DNS settings left unchanged."
            return 1
        fi
    fi

    sudo mkdir -p /etc/systemd/resolved.conf.d
    case "$provider" in
        cloudflare)
            cat <<'EOF' | sudo tee /etc/systemd/resolved.conf.d/99-tebian-dns.conf
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
DNSOverTLS=yes
DNSSEC=allow-downgrade
Domains=~.
EOF
            ;;
        *)  # quad9 (default)
            cat <<'EOF' | sudo tee /etc/systemd/resolved.conf.d/99-tebian-dns.conf
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
DNSOverTLS=yes
DNSSEC=allow-downgrade
Domains=~.
EOF
            ;;
    esac

    sudo systemctl enable --now systemd-resolved
    sudo systemctl restart systemd-resolved

    # Only repoint resolv.conf once resolved is demonstrably up
    if ! systemctl is-active --quiet systemd-resolved || [ ! -f /run/systemd/resolve/stub-resolv.conf ]; then
        sudo rm -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf
        log_error "systemd-resolved did not start — DNS settings left unchanged."
        return 1
    fi
    if [ ! -L /etc/resolv.conf ] || ! readlink /etc/resolv.conf | grep -q stub-resolv; then
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    fi

    log_info "DNS-over-TLS enabled ($provider)"
}

toggle_dns_off() {
    log_info "Disabling DNS-over-TLS..."
    sudo rm -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        sudo systemctl restart systemd-resolved
    fi
    log_info "DNS-over-TLS disabled (using default DNS)"
}

enable_transparent_tor() {
    log_info "Enabling TRANSPARENT Tor (all traffic forced through Tor)..."
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
ip6tables -w -N TEBIAN_TOR

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
iptables -w -A TEBIAN_TOR -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -w -A TEBIAN_TOR -o lo -j ACCEPT
iptables -w -A TEBIAN_TOR -m owner --uid-owner \$TOR_UID -j ACCEPT
iptables -w -A TEBIAN_TOR -p udp --sport 68 --dport 67 -j ACCEPT
# DNS over TCP to a LAN resolver would be forwarded upstream in the clear
iptables -w -A TEBIAN_TOR -p tcp --dport 53 -j REJECT
for net in \$LAN; do iptables -w -A TEBIAN_TOR -d \$net -j ACCEPT; done
iptables -w -A TEBIAN_TOR -j REJECT

ip6tables -w -A TEBIAN_TOR -o lo -j ACCEPT
ip6tables -w -A TEBIAN_TOR -m owner --uid-owner \$TOR_UID -j ACCEPT
ip6tables -w -A TEBIAN_TOR -j REJECT

# First in OUTPUT, ahead of ufw's chains — ufw accepts new outgoing
# connections, which would let UDP out before it ever reached this chain
iptables -w -t nat -I OUTPUT 1 -j TEBIAN_TOR
iptables -w -I OUTPUT 1 -j TEBIAN_TOR
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
    sudo rm -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf 2>/dev/null
    sudo systemctl restart systemd-resolved 2>/dev/null || true

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
    *)
        log_error "Unknown profile: $PROFILE"
        echo "Usage: bash security.sh [minimal|standard|hardened|paranoid|paranoid-off|tor-on|tor-off|dns-on|dns-off|mac-on|mac-off]"
        exit 1
        ;;
esac
