#!/bin/bash
# ==============================================================================
# TEBIAN UNINSTALL (V2.0)
# Removes Tebian's configs and scripts and reverts the system changes it made
# (login screen, root-owned helpers, security profile extras). Asks before
# each group that goes beyond your own home directory.
# ==============================================================================

set -uo pipefail   # no -e: one missing file must not stop the rest of the revert

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

TEBIAN_DIR="${TEBIAN_DIR:-$HOME/Tebian}"

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Run this as your normal user, not root — it cleans up your home directory.${NC}"
    exit 1
fi

step() { echo -e "  ${GREEN}✓${NC} $*"; }
note() { echo -e "  ${YELLOW}•${NC} $*"; }
ask() { local r; read -r -p "  $1 " r || r=""; [[ "$r" =~ ^[Yy] ]]; }

echo "  ████████╗███████╗██████╗ ███╗   ██╗"
echo "  ╚══██╔══╝██╔════╝██╔══██╗████╗  ██║"
echo "     ██║   █████╗  ██████╔╝██╔██╗ ██║"
echo "     ██║   ██╔══╝  ██╔══██╗██║╚██╗██║"
echo "     ██║   ███████╗██║  ██║██║ ╚████║"
echo "     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝"
echo ""
echo "  Uninstall Tebian"
echo ""
echo "  From your home directory this removes:"
echo "    - sway, kitty, fuzzel, mako, gtklock, wob configs and Tebian's settings"
echo "    - Tebian scripts in ~/.local/bin"
echo "  System-wide it reverts (you'll be asked for your password):"
echo "    - Tebian's login screen (your previous one is restored if there was one)"
echo "    - Tebian's helpers in /usr/local, its udev rule and apt hook"
echo "    - Security profile extras: hardened kernel/SSH settings, browser"
echo "      sandbox links, transparent Tor, MAC randomization, DNS-over-TLS"
echo ""
echo "  Your ~/Tebian folder stays (delete it yourself if you like)."
echo ""
ask "Continue? [y/N]" || { echo "  Cancelled."; exit 0; }

# --- Home directory -------------------------------------------------------------
echo ""
echo "  Home directory..."

rm -rf ~/.config/sway ~/.config/kitty ~/.config/fuzzel ~/.config/mako \
       ~/.config/gtklock ~/.config/wob ~/.config/tebian
rm -f ~/.config/tebian-onboarded
rm -f ~/.config/environment.d/tebian-*.conf
rm -f ~/.config/fontconfig/conf.d/50-tebian-font-rendering.conf
rm -f ~/.config/xdg-desktop-portal/sway-portals.conf
rm -rf ~/.local/share/tebian
step "Configs removed"

# Scripts: everything the Tebian tree ships, plus the naming patterns in case
# the tree is gone. tebian-settings.d is a directory — rm -f alone fails on it.
rm -rf ~/.local/bin/tebian-settings.d
if [ -d "$TEBIAN_DIR/scripts" ]; then
    for script in "$TEBIAN_DIR/scripts/"*; do
        [ -f "$script" ] && rm -f ~/.local/bin/"$(basename "$script")"
    done
fi
rm -f ~/.local/bin/tebian-* ~/.local/bin/t-add ~/.local/bin/t-fetch \
      ~/.local/bin/t-launch ~/.local/bin/tfuzzel ~/.local/bin/status.sh \
      ~/.local/bin/update-all
step "Scripts removed"

# The t-fetch block desktop.sh appended to .bashrc
if grep -q "# Tebian Startup Fetch" ~/.bashrc 2>/dev/null; then
    sed -i '/^# Tebian Startup Fetch/,/^fi$/d' ~/.bashrc
    step "Startup fetch removed from ~/.bashrc"
fi

# Browser sandbox .desktop overrides (only ours — they carry a marker line)
for f in ~/.local/share/applications/*.desktop; do
    grep -qsxF "X-Tebian-Firejail=true" "$f" && rm -f "$f"
done

# --- System ------------------------------------------------------------------------
echo ""
echo "  System (needs your password)..."
if ! sudo -v; then
    echo -e "${RED}  No sudo — system changes were NOT reverted. Re-run to finish.${NC}"
    exit 1
fi

# Login screen. Only touched when it is Tebian's (greetd running nwg-hello).
if grep -qs "nwg-hello" /etc/greetd/config.toml; then
    prev=$(cat /etc/tebian/previous-display-manager 2>/dev/null || true)
    sudo systemctl disable greetd 2>/dev/null
    if [ -n "$prev" ] && systemctl cat "$prev" >/dev/null 2>&1; then
        sudo systemctl enable "$prev"
        step "Login screen: ${prev%.service} restored (from next boot)"
    else
        note "Login screen: Tebian's disabled — next boot shows a text login"
    fi
    sudo rm -rf /etc/nwg-hello /var/cache/nwg-hello /etc/systemd/system/greetd.service.d
    sudo rm -f /etc/greetd/environments
    if id greeter &>/dev/null; then
        sudo userdel -r greeter 2>/dev/null || sudo userdel greeter 2>/dev/null
    fi
fi
sudo rm -f /usr/share/wayland-sessions/tebian.desktop
sudo rm -rf /etc/tebian

# Root-owned helpers
if systemctl cat tebian-boot-diag.service >/dev/null 2>&1; then
    sudo systemctl disable tebian-boot-diag.service 2>/dev/null
fi
sudo rm -f /etc/systemd/system/tebian-boot-diag.service \
           /usr/local/bin/tebian-session /usr/local/bin/tebian-drive-probe \
           /usr/local/bin/tebian-bootstrap /usr/local/bin/tebian-boot-diag \
           /usr/local/sbin/tebian-nwg-hello-fix /etc/apt/apt.conf.d/80-tebian-nwg-hello
if [ -f /etc/udev/rules.d/90-tebian-drive-doctor.rules ]; then
    sudo rm -f /etc/udev/rules.d/90-tebian-drive-doctor.rules
    sudo udevadm control --reload 2>/dev/null
fi
sudo rm -f /etc/fonts/conf.d/40-tebian-font-rendering.conf
step "Tebian helpers removed from /usr/local and /etc"

# SwayFX (built by tebian-install-swayfx into its own prefix). Only the
# sway/swaymsg symlinks that point into that prefix are removed, so Debian's
# /usr/bin/sway takes over again. (Its effect blocks in config.user went
# with ~/.config/sway above — on plain sway they'd be config errors.)
if [ -d /opt/tebian-swayfx ]; then
    for bin in sway swaymsg; do
        if readlink "/usr/local/bin/$bin" 2>/dev/null | grep -q '^/opt/tebian-swayfx/'; then
            sudo rm -f "/usr/local/bin/$bin"
        fi
    done
    sudo rm -rf /opt/tebian-swayfx
    sudo ldconfig 2>/dev/null
    rm -f "$HOME/.config/tebian/swayfx-installed"
    step "SwayFX removed (Debian's sway is used again)"
fi

# Firejail links: only /usr/local/bin entries that point at firejail
for bin in firefox firefox-esr chromium chromium-browser google-chrome-stable; do
    if [ -L "/usr/local/bin/$bin" ] && readlink "/usr/local/bin/$bin" | grep -q firejail; then
        sudo rm -f "/usr/local/bin/$bin"
    fi
done

# Transparent Tor (paranoid profile). Its rules script knows how to remove
# exactly its own chains.
if [ -f /etc/systemd/system/tebian-tor-iptables.service ] || [ -f /etc/tebian-tor-iptables.sh ]; then
    sudo systemctl stop tebian-tor-iptables.service 2>/dev/null
    [ -x /etc/tebian-tor-iptables.sh ] && sudo /etc/tebian-tor-iptables.sh stop
    sudo systemctl disable tebian-tor-iptables.service 2>/dev/null
    sudo rm -f /etc/systemd/system/tebian-tor-iptables.service /etc/tebian-tor-iptables.sh
    sudo systemctl daemon-reload
    sudo sed -i '/# Tebian transparent proxy/,/^DNSPort/d' /etc/tor/torrc 2>/dev/null
    step "Transparent Tor removed"
fi

# Kernel and SSH drop-ins (hardened profile, and the old core module)
changed_sysctl=""
for f in /etc/sysctl.d/99-tebian-hardening.conf /etc/sysctl.d/99-tebian.conf; do
    [ -f "$f" ] && { sudo rm -f "$f"; changed_sysctl=1; }
done
[ -n "$changed_sysctl" ] && step "Hardened kernel settings removed (defaults return after reboot)"
changed_ssh=""
for f in /etc/ssh/sshd_config.d/99-tebian-keyonly.conf /etc/ssh/sshd_config.d/99-tebian.conf; do
    [ -f "$f" ] && { sudo rm -f "$f"; changed_ssh=1; }
done
if [ -n "$changed_ssh" ]; then
    sudo systemctl reload ssh 2>/dev/null
    step "SSH settings back to Debian defaults"
fi

if [ -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf ]; then
    sudo rm -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf
    sudo systemctl restart systemd-resolved 2>/dev/null
    step "DNS-over-TLS removed"
fi
if [ -f /etc/NetworkManager/conf.d/99-tebian-mac-random.conf ]; then
    sudo rm -f /etc/NetworkManager/conf.d/99-tebian-mac-random.conf
    note "MAC randomization removed — takes effect when NetworkManager restarts (next boot)"
fi

# GRUB: Tebian's wallpaper and console colors
if [ -f /etc/default/grub ] && grep -qE 'tebian|vt\.default_red' /etc/default/grub; then
    sudo sed -i '/^GRUB_BACKGROUND=.*tebian/d' /etc/default/grub
    sudo sed -i -E 's/ ?vt\.default_(red|grn|blu)=[0-9,]+//g' /etc/default/grub
    sudo update-grub >/dev/null 2>&1 && step "GRUB wallpaper and console colors removed"
fi
sudo rm -rf /usr/share/backgrounds/tebian

# Firewall: useful on its own, so it stays unless asked
if systemctl is-active --quiet ufw 2>/dev/null || systemctl is-active --quiet fail2ban 2>/dev/null; then
    echo ""
    if ask "Also turn off the firewall (ufw) and fail2ban that Tebian enabled? [y/N]"; then
        sudo ufw disable 2>/dev/null
        sudo systemctl disable --now fail2ban 2>/dev/null
        step "Firewall and fail2ban turned off"
    else
        note "Firewall and fail2ban left on"
    fi
fi

# --- Packages ------------------------------------------------------------------------
echo ""
if ask "Remove Tebian's desktop packages? (sway, fuzzel, kitty, mako, greetd...) [y/N]"; then
    candidates=(sway swaybg swayidle gtklock fuzzel mako-notifier kitty grim slurp
                wl-clipboard cliphist brightnessctl autotiling wob greetd nwg-hello)
    installed=()
    for pkg in "${candidates[@]}"; do
        dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed" && installed+=("$pkg")
    done
    if [ ${#installed[@]} -gt 0 ]; then
        sudo apt remove -y "${installed[@]}" && sudo apt autoremove -y
        step "Packages removed"
    fi
fi

echo ""
echo -e "${GREEN}  Tebian has been removed.${NC}"
echo ""
echo "  Left in place:"
echo "    - ~/Tebian (the source folder)"
echo "    - Packages installed along the way that you may use elsewhere"
echo "      (ufw, fail2ban, firejail, apparmor, tor, NetworkManager, fonts)"
[ -f /etc/apt/sources.list.d/tebian-backports.list ] &&
    echo "    - The backports repository (Settings → Graphics Drivers): /etc/apt/sources.list.d/tebian-backports.list"
echo "    - Boot splash and kernel boot options set by the Tebian installer"
echo ""
echo "  Reboot to finish."
