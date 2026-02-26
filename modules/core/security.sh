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

firejail_symlink() {
    local bin="$1"
    if command -v firejail &>/dev/null && command -v "$bin" &>/dev/null; then
        local real_path
        real_path=$(which "$bin")
        sudo ln -sf /usr/bin/firejail "/usr/local/bin/$bin"
        log_info "Firejail sandbox enabled for $bin"
    fi
}

firejail_remove_symlink() {
    local bin="$1"
    if [ -L "/usr/local/bin/$bin" ] && readlink "/usr/local/bin/$bin" | grep -q firejail; then
        sudo rm -f "/usr/local/bin/$bin"
        log_info "Firejail sandbox removed for $bin"
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

    # AppArmor to complain mode
    if command -v aa-complain &>/dev/null; then
        sudo aa-complain /etc/apparmor.d/* 2>/dev/null || true
        log_info "AppArmor set to complain mode"
    fi

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
    if systemctl is-active --quiet ssh 2>/dev/null; then
        sudo ufw allow ssh
    fi
    sudo ufw --force enable
    log_info "Firewall enabled (deny incoming)"

    # fail2ban
    ensure_fail2ban
    sudo systemctl enable --now fail2ban
    log_info "fail2ban enabled"

    # AppArmor enforce
    ensure_apparmor
    sudo aa-enforce /etc/apparmor.d/* 2>/dev/null || true
    log_info "AppArmor set to enforce mode"

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

    # SSH key-only
    sudo mkdir -p /etc/ssh/sshd_config.d
    printf 'PasswordAuthentication no\nX11Forwarding no\n' | sudo tee /etc/ssh/sshd_config.d/99-tebian-keyonly.conf
    sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
    log_info "SSH set to key-only authentication"

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

    sudo apt install -y systemd-resolved 2>/dev/null || true

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

    # Point resolv.conf to resolved
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

    # Save rules to a script so they persist
    cat <<EOFW | sudo tee /etc/tebian-tor-iptables.sh
#!/bin/bash
# Tebian transparent Tor iptables rules
iptables -t nat -F
iptables -t nat -A OUTPUT -m owner --uid-owner $tor_uid -j RETURN
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports 9040
iptables -t nat -A OUTPUT -p udp -j REDIRECT --to-ports 9040
# Block non-Tor DNS leaks
iptables -A OUTPUT -p udp --dport 53 -m owner ! --uid-owner $tor_uid -j REJECT
# Allow Tor user and local traffic
iptables -A OUTPUT -m owner --uid-owner $tor_uid -j ACCEPT
iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
EOFW
    sudo chmod +x /etc/tebian-tor-iptables.sh
    sudo bash /etc/tebian-tor-iptables.sh

    # Persist across reboots via systemd
    cat <<'EOF' | sudo tee /etc/systemd/system/tebian-tor-iptables.service
[Unit]
Description=Tebian Transparent Tor iptables rules
After=tor.service
Requires=tor.service

[Service]
Type=oneshot
ExecStart=/etc/tebian-tor-iptables.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable tebian-tor-iptables.service

    log_info "Transparent Tor enabled — ALL traffic now routes through Tor"
}

disable_transparent_tor() {
    log_info "Disabling transparent Tor..."

    # Flush iptables nat rules
    sudo iptables -t nat -F 2>/dev/null || true
    # Remove DNS block rule
    sudo iptables -D OUTPUT -p udp --dport 53 -m owner ! --uid-owner "$(id -u debian-tor 2>/dev/null || id -u tor 2>/dev/null || echo 0)" -j REJECT 2>/dev/null || true

    # Remove systemd service
    sudo systemctl stop tebian-tor-iptables.service 2>/dev/null || true
    sudo systemctl disable tebian-tor-iptables.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/tebian-tor-iptables.service
    sudo rm -f /etc/tebian-tor-iptables.sh
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

    log_info "PARANOID profile applied — you are now anonymous"
    log_warn "Verify at: https://check.torproject.org"
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

case "$PROFILE" in
    minimal)      apply_minimal ;;
    standard)     apply_standard ;;
    hardened)     apply_hardened ;;
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
