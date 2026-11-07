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
echo "    - sway, kitty, fuzzel, mako, gtklock, wob configs (moved to a backup"
echo "      folder in your home, not deleted) and Tebian's settings"
echo "    - Tebian scripts in ~/.local/bin"
echo "  System-wide it reverts (you'll be asked for your password):"
echo "    - Tebian's login screen (your previous one is restored if there was one)"
echo "    - Tebian's helpers in /usr/local, its udev rule and apt hook"
echo "    - Security profile extras: hardened kernel/SSH settings, app"
echo "      sandbox links, transparent Tor, MAC randomization, DNS-over-TLS"
echo "    - Passwordless sudo, if it was turned on in Settings"
echo ""
echo "  Your ~/Tebian folder stays (delete it yourself if you like)."
echo ""
ask "Continue? [y/N]" || { echo "  Cancelled."; exit 0; }

# --- Home directory -------------------------------------------------------------
echo ""
echo "  Home directory..."

# These folders also hold the user's own files (sway config.user, scripts,
# themes), so they are moved aside rather than deleted
CONFIG_BACKUP="$HOME/tebian-configs-$(date +%Y%m%d-%H%M%S)"
for d in sway kitty fuzzel mako gtklock wob; do
    [ -e ~/.config/$d ] || continue
    mkdir -p "$CONFIG_BACKUP"
    mv ~/.config/$d "$CONFIG_BACKUP/"
    # Configs the user had before Tebian replaced them (desktop.sh)
    for pre in "$CONFIG_BACKUP/$d/"*.pre-tebian; do
        [ -f "$pre" ] || continue
        mkdir -p ~/.config/$d
        cp -p "$pre" ~/.config/$d/"$(basename "${pre%.pre-tebian}")"
        step "Your pre-Tebian ~/.config/$d/$(basename "${pre%.pre-tebian}") is back"
    done
done
rm -rf ~/.config/tebian
rm -f ~/.config/tebian-onboarded
rm -f ~/.config/environment.d/tebian-*.conf
rm -f ~/.config/fontconfig/conf.d/50-tebian-font-rendering.conf
rm -f ~/.config/xdg-desktop-portal/sway-portals.conf
rm -rf ~/.local/share/tebian
if [ -d "$CONFIG_BACKUP" ]; then
    step "Configs moved to ${CONFIG_BACKUP/#$HOME/~}"
else
    step "Configs removed"
fi

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

# Tebian's sway build (tebian-build-sway): back to Debian's own package,
# the newest version Debian's archive has that isn't a Tebian build
# (+tebianN builds before 3.5, +0tebianN since)
sway_ver=$(dpkg-query -W -f='${Version}' sway 2>/dev/null || true)
if [[ "$sway_ver" =~ \+0?tebian ]]; then
    debian_sway=$(apt-cache madison sway 2>/dev/null | awk -F'|' '$2 !~ /tebian/ { gsub(/ /, "", $2); print $2; exit }')
    if [ -n "$debian_sway" ] && sudo apt-get install -y --allow-downgrades "sway=$debian_sway" >/dev/null; then
        step "Sway: Debian's package restored ($debian_sway)"
    else
        echo "  Could not restore Debian's sway; run: sudo apt install --reinstall sway/$(. /etc/os-release && echo "$VERSION_CODENAME")"
    fi
fi

# Firejail links: every /usr/local/bin entry that points at firejail —
# Settings sandboxes mail and chat apps too, and a link left behind breaks
# that app once firejail is removed
for link in /usr/local/bin/*; do
    if [ -L "$link" ] && [[ "$(readlink "$link")" == */firejail ]]; then
        sudo rm -f "$link"
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
for f in /etc/sysctl.d/99-tebian-hardening.conf /etc/sysctl.d/99-tebian.conf \
         /etc/sysctl.d/99-tebian-mem.conf; do
    [ -f "$f" ] && { sudo rm -f "$f"; changed_sysctl=1; }
done
[ -n "$changed_sysctl" ] && step "Hardened kernel settings removed (defaults return after reboot)"
changed_ssh=""
for f in /etc/ssh/sshd_config.d/00-tebian-keyonly.conf /etc/ssh/sshd_config.d/99-tebian-keyonly.conf \
         /etc/ssh/sshd_config.d/99-tebian.conf; do
    [ -f "$f" ] && { sudo rm -f "$f"; changed_ssh=1; }
done
if [ -n "$changed_ssh" ]; then
    sudo systemctl reload ssh 2>/dev/null
    step "SSH settings back to Debian defaults"
fi

# DNS-over-TLS: undone the way Settings undoes it — resolv.conf goes back
# to NetworkManager
if [ -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf ] ||
   [ -f /etc/NetworkManager/conf.d/99-tebian-dns-resolved.conf ]; then
    sudo rm -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf \
               /etc/NetworkManager/conf.d/99-tebian-dns-resolved.conf
    sudo systemctl disable --now systemd-resolved 2>/dev/null
    if [ -L /etc/resolv.conf ] && readlink /etc/resolv.conf | grep -q '/systemd/resolve/'; then
        sudo rm -f /etc/resolv.conf
    fi
    sudo systemctl restart NetworkManager 2>/dev/null
    step "DNS-over-TLS removed"
fi

# Nouveau blacklist from Settings → Graphics Drivers. Only without an
# Nvidia driver installed: with one, nouveau must stay off
if [ -f /etc/modprobe.d/nvidia-blacklist.conf ]; then
    if dpkg-query -W -f='${Status}' nvidia-driver 2>/dev/null | grep -q "ok installed"; then
        note "Nouveau blacklist kept (/etc/modprobe.d/nvidia-blacklist.conf): the Nvidia driver is installed"
    else
        sudo rm -f /etc/modprobe.d/nvidia-blacklist.conf
        sudo update-initramfs -u >/dev/null 2>&1
        step "Nouveau blacklist removed (takes effect after reboot)"
    fi
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

if [ -f /etc/NetworkManager/conf.d/99-tebian-mac-random.conf ]; then
    sudo rm -f /etc/NetworkManager/conf.d/99-tebian-mac-random.conf
    note "MAC randomization removed — takes effect when NetworkManager restarts (next boot)"
fi

# Passwordless sudo (Settings → Security) — last, so the steps above
# didn't need the password again. Removing it must not take sudo
# away: older installs granted sudo only through such a file, not the sudo
# group — so a password-required rule goes in first, as the Settings
# toggle does. Every file is checked with visudo before it goes in.
sudo_nopasswd_files=()
sudo test -f /etc/sudoers.d/tebian-nopasswd && sudo_nopasswd_files+=(/etc/sudoers.d/tebian-nopasswd)
if sudo test -f "/etc/sudoers.d/$USER" &&
   [ "$(sudo grep -cvE '^[[:space:]]*(#|$)' "/etc/sudoers.d/$USER")" = 1 ] &&
   sudo grep -qxE "$USER ALL=\(ALL(:ALL)?\) NOPASSWD: ?ALL" "/etc/sudoers.d/$USER"; then
    sudo_nopasswd_files+=("/etc/sudoers.d/$USER")
fi
if [ ${#sudo_nopasswd_files[@]} -gt 0 ]; then
    if [ "$(sudo passwd -S "$USER" 2>/dev/null | cut -d' ' -f2)" != P ]; then
        note "Passwordless sudo kept: $USER has no password (set one with passwd, then re-run)"
    else
        ok_rule=""
        if id -nG "$USER" | tr ' ' '\n' | grep -qx sudo || sudo test -f /etc/sudoers.d/tebian-sudo; then
            sudo rm -f "${sudo_nopasswd_files[@]}" && ok_rule=1
        else
            tmp=$(mktemp)
            printf '%s ALL=(ALL:ALL) ALL\n' "$USER" > "$tmp"
            # One sudo call: once the password rule is in, the next sudo
            # would already ask for the password
            sudo visudo -cqf "$tmp" &&
                sudo sh -c 'install -o root -g root -m 0440 "$1" /etc/sudoers.d/tebian-sudo && shift && rm -f "$@"' \
                    sh "$tmp" "${sudo_nopasswd_files[@]}" && ok_rule=1
            rm -f "$tmp"
        fi
        if [ -n "$ok_rule" ]; then
            step "Passwordless sudo removed (sudo asks for your password again)"
        else
            note "Passwordless sudo kept: could not install a password rule to replace it"
        fi
    fi
fi

echo ""
echo -e "${GREEN}  Tebian has been removed.${NC}"
echo ""
echo "  Left in place:"
echo "    - ~/Tebian (the source folder)"
[ -d "$CONFIG_BACKUP" ] &&
    echo "    - Your previous Tebian configs, in ${CONFIG_BACKUP/#$HOME/~}"
echo "    - Packages installed along the way that you may use elsewhere"
echo "      (ufw, fail2ban, firejail, apparmor, tor, NetworkManager, fonts),"
echo "      and apt repositories added for apps (e.g. Tailscale)"
[ -n "${ok_rule:-}" ] &&
    echo "    - Your sudo rule (sudo group or /etc/sudoers.d/tebian-sudo; password required)"
[ -f /etc/apt/sources.list.d/tebian-backports.list ] &&
    echo "    - The backports repository (Settings → Graphics Drivers): /etc/apt/sources.list.d/tebian-backports.list"
echo "    - Boot splash and kernel boot options set by the Tebian installer"
echo ""
echo "  Reboot to finish."
