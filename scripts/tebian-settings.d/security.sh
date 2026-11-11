# shellcheck shell=bash
# tebian-settings module: security.sh
# Sourced by tebian-settings — do not run directly

# The security module does the work for the menu entries that have a
# profile counterpart, so Settings, tebian-rebuild and install all leave
# the machine in the same state
security_module() { echo "${TEBIAN_DIR:-$HOME/Tebian}/modules/core/security.sh"; }

# The profile the machine is in, from its state (no sudo needed). ufw.service
# is oneshot and reports "active" even when ENABLED=no — the conf file is
# the real state.
security_current_profile() {
    if systemctl is-enabled --quiet tebian-tor-iptables 2>/dev/null; then echo paranoid
    elif [ -f /etc/sysctl.d/99-tebian-hardening.conf ]; then echo hardened
    elif grep -q '^ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null; then echo standard
    else echo minimal
    fi
}

security_menu() {
    while true; do
    local cur_profile
    cur_profile=$(security_current_profile)
    SSH_ACTIVE=$(systemctl is-active --quiet ssh && echo "ON" || echo "OFF")

    SEC_LABEL="󰒃 Security Profile (Current: ${cur_profile^})"

    if [[ "$SSH_ACTIVE" == "ON" ]]; then
        SSH_LABEL="󰆍 Remote Access / SSH (ON)"
    else
        SSH_LABEL="󰆍 Remote Access / SSH (OFF)"
    fi

    # Detect SSH key-only mode — check our specific file (00- now; 99- on
    # older installs), not all of sshd_config.d
    if [ -f /etc/ssh/sshd_config.d/00-tebian-keyonly.conf ] || [ -f /etc/ssh/sshd_config.d/99-tebian-keyonly.conf ]; then
        SSH_KEY_LABEL="󰌆 SSH Key-Only Login (ON)"
    else
        SSH_KEY_LABEL="󰌆 SSH Key-Only Login (OFF)"
    fi

    # Detect kernel hardening sysctl
    if [ -f /etc/sysctl.d/99-tebian-hardening.conf ]; then
        KERN_LABEL="󰍛 Kernel Hardening (ON)"
    else
        KERN_LABEL="󰍛 Kernel Hardening (OFF)"
    fi

    # AppArmor: the kernel decides whether it can run at all (some Pi
    # kernels don't enable it), the service whether profiles are loaded
    if [ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" != Y ]; then
        AA_LABEL="󰒃 AppArmor (Not in this kernel)"
    elif systemctl is-active --quiet apparmor 2>/dev/null; then
        AA_LABEL="󰒃 AppArmor (ON)"
    else
        AA_LABEL="󰒃 AppArmor (OFF)"
    fi

    # Detect Firejail sandbox (browsers + networked apps)
    FJ_COUNT=$(firejail_link_count)
    if [ "$FJ_COUNT" -gt 0 ]; then
        FJ_LABEL="󰈡 Firejail App Sandbox (ON — $FJ_COUNT app$([ "$FJ_COUNT" = 1 ] || echo s))"
    else
        FJ_LABEL="󰈡 Firejail App Sandbox (OFF)"
    fi

    # Detect Tor. In Paranoid Mode all traffic depends on it — its own
    # toggle must not stop it (that would leave the machine offline)
    if [ -f /etc/tebian-tor-iptables.sh ]; then
        TOR_LABEL="󰗹 Tor Routing (ON — via Paranoid)"
    elif systemctl is-active --quiet tor 2>/dev/null; then
        TOR_LABEL="󰗹 Tor Routing (ON)"
    else
        TOR_LABEL="󰗹 Tor Routing (OFF)"
    fi

    # Detect DNS Privacy
    if [ -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf ]; then
        DNS_LABEL="󰇖 DNS Privacy (ON)"
    else
        DNS_LABEL="󰇖 DNS Privacy (OFF)"
    fi

    # Detect Paranoid Mode (transparent Tor + MAC randomization). Its rules
    # unit failing means traffic is NOT going through Tor — say so
    if [ -f /etc/systemd/system/tebian-tor-iptables.service ]; then
        if ! systemctl is-active --quiet tebian-tor-iptables 2>/dev/null; then
            PARANOID_LABEL="󰗹 Paranoid Mode (FAILED — traffic not via Tor)"
        else
            PARANOID_LABEL="󰗹 Paranoid Mode (ON)"
        fi
    else
        PARANOID_LABEL="󰗹 Paranoid Mode (OFF)"
    fi

    # Detect auto-updates
    if dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'; then
        AUTOUPDATE_LABEL="󰚰 Auto Security Updates (ON)"
    else
        AUTOUPDATE_LABEL="󰚰 Auto Security Updates (OFF)"
    fi

    # Passwordless sudo — tested by behaviour (sudoers files are root-only
    # readable): -k ignores cached credentials, so this only succeeds when a
    # NOPASSWD rule applies
    if sudo -k -n true 2>/dev/null; then
        SUDO_LABEL="󰌆 Passwordless sudo (ON)"
    else
        SUDO_LABEL="󰌆 Passwordless sudo (OFF)"
    fi

    # Skip the login screen after the disk passphrase — only offered when the
    # system disk really is encrypted (tebian-autologin decides)
    AUTOLOGIN_LABEL=""
    case "$(tebian-autologin status 2>/dev/null)" in
        on)  AUTOLOGIN_LABEL="󰌾 Skip Login After Disk Unlock (ON)" ;;
        off) AUTOLOGIN_LABEL="󰌾 Skip Login After Disk Unlock (OFF)" ;;
    esac

    SEC_OPTS="$PARANOID_LABEL
$SEC_LABEL
󰌆 Change Password
${AUTOLOGIN_LABEL:+$AUTOLOGIN_LABEL
}$SUDO_LABEL
$SSH_LABEL
$SSH_KEY_LABEL
$KERN_LABEL
$AA_LABEL
$FJ_LABEL
$TOR_LABEL
$DNS_LABEL
$AUTOUPDATE_LABEL
󰒃 Security Tools
󰍉 View Open Ports
󰍉 View Security Logs
󰌍 Back"

    S_CHOICE=$(echo -e "$SEC_OPTS" | tfuzzel -d -p " Security | " --width 48)

    [ -n "$S_CHOICE" ] || menu_close
    if is_back "$S_CHOICE"; then return; fi

    if [[ "$S_CHOICE" == *"Paranoid Mode (ON)"* || "$S_CHOICE" == *"Paranoid Mode (FAILED"* ]]; then
        local _tdir="${TEBIAN_DIR:-$HOME/Tebian}"
        $TERM_CMD bash -c "echo '=== Disabling Paranoid Mode ===';
        echo '';
        echo 'Reverting transparent Tor and MAC randomization...';
        echo '(Hardened security settings like UFW/AppArmor remain active)';
        echo '';
        if [ -f '$_tdir/modules/core/security.sh' ]; then
            bash '$_tdir/modules/core/security.sh' paranoid-off;
        else
            echo 'Removing Tor iptables routing...';
            sudo systemctl stop tebian-tor-iptables 2>/dev/null;
            sudo systemctl disable tebian-tor-iptables 2>/dev/null;
            sudo rm -f /etc/systemd/system/tebian-tor-iptables.service;
            echo 'Removing MAC randomization...';
            sudo rm -f /etc/NetworkManager/conf.d/99-tebian-mac-random.conf;
            sudo systemctl restart NetworkManager 2>/dev/null;
        fi;
        echo '';
        echo 'Normal networking restored.';
        read -p 'Press Enter to close...'"
        # The terminal step can fail (sudo refused); report what is there now
        if [ -f /etc/systemd/system/tebian-tor-iptables.service ]; then
            tnotify "Security" "Paranoid Mode is still on — see the terminal output"
        else
            tnotify "Security" "Paranoid Mode off"
        fi
    elif [[ "$S_CHOICE" == *"Paranoid Mode (OFF)"* ]]; then
        local _tdir="${TEBIAN_DIR:-$HOME/Tebian}"
        $TERM_CMD bash -c "echo '=== PARANOID MODE ===';
        echo '';
        echo 'This will:';
        echo '  - Enable ALL hardened security features';
        echo '  - Force ALL traffic through Tor (transparent proxy)';
        echo '  - Randomize your MAC address on every connection';
        echo '  - Route DNS through Tor (no leaks)';
        echo '';
        echo 'WARNING: Internet will be slower. Some services may break.';
        echo '';
        read -p 'Enable Paranoid Mode? [y/N]: ' confirm;
        if [[ \"\$confirm\" =~ ^[Yy]$ ]]; then
            echo '';
            if [ -f '$_tdir/modules/core/security.sh' ]; then
                bash '$_tdir/modules/core/security.sh' paranoid;
            else
                echo 'Error: Security module not found at $_tdir/modules/core/security.sh';
            fi;
            echo '';
            echo 'Verify: open https://check.torproject.org in your browser';
        else
            echo 'Cancelled.';
        fi;
        read -p 'Press Enter to close...'"
        # Silent when cancelled inside the terminal
        if [ -f /etc/systemd/system/tebian-tor-iptables.service ]; then
            if systemctl is-active --quiet tebian-tor-iptables 2>/dev/null; then
                tnotify "Security" "Paranoid Mode on"
            else
                tnotify "Security" "Paranoid Mode FAILED — traffic is not going through Tor"
            fi
        fi
    elif [[ "$S_CHOICE" == *"Security Profile"* ]]; then
        security_profile_menu "$cur_profile"
    elif [[ "$S_CHOICE" == *"Passwordless sudo"* ]]; then
        passwordless_sudo_toggle "$S_CHOICE"
    elif [[ "$S_CHOICE" == *"Change Password"* ]]; then
        change_password_flow
    elif [[ "$S_CHOICE" == *"Skip Login After Disk Unlock"* ]]; then
        autologin_toggle
    elif [[ "$S_CHOICE" == *"Remote Access"* ]]; then
        ssh_toggle
    elif [[ "$S_CHOICE" == *"Key-Only Login (OFF)"* ]]; then
        if [[ "$SSH_ACTIVE" != "ON" ]]; then
            tnotify "Security" "Turn on Remote Access / SSH first"
        else
            SECMOD="$(security_module)" $TERM_CMD bash -c '
            echo "Hardening SSH to Key-Only Mode..."
            echo ""
            echo "Password logins stop; only the keys in ~/.ssh/authorized_keys work."
            echo "(Refused if that file has no key — that would be a lockout.)"
            echo ""
            read -p "Continue? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                bash "$SECMOD" ssh-keyonly
            else
                echo "Cancelled."
            fi
            read -p "Press Enter to close..."'
            # Only report success if it really happened inside the terminal
            if [ -f /etc/ssh/sshd_config.d/00-tebian-keyonly.conf ]; then
                tnotify "Security" "SSH set to key-only"
            fi
        fi
    elif [[ "$S_CHOICE" == *"Key-Only Login (ON)"* ]]; then
        SECMOD="$(security_module)" $TERM_CMD bash -c '
        echo "Reverting SSH to allow password auth..."
        bash "$SECMOD" ssh-password
        read -p "Press Enter to close..."'
        if [ -f /etc/ssh/sshd_config.d/00-tebian-keyonly.conf ] || [ -f /etc/ssh/sshd_config.d/99-tebian-keyonly.conf ]; then
            tnotify "Security" "SSH key-only login is still on — see the terminal output"
        else
            tnotify "Security" "SSH key-only login off (passwords work again)"
        fi
    elif [[ "$S_CHOICE" == *"Kernel Hardening (OFF)"* ]]; then
        $TERM_CMD bash -c "echo 'Applying kernel hardening...';
        cat <<'SYSEOF' | sudo tee /etc/sysctl.d/99-tebian-hardening.conf
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
SYSEOF
        sudo sysctl -e -p /etc/sysctl.d/99-tebian-hardening.conf;
        echo '';
        echo 'Done! Kernel hardening applied.';
        read -p 'Press Enter to close...'"
        if [ -f /etc/sysctl.d/99-tebian-hardening.conf ]; then
            tnotify "Security" "Kernel hardening on"
        else
            tnotify "Security" "Kernel hardening not turned on — see the terminal output"
        fi
    elif [[ "$S_CHOICE" == *"Kernel Hardening (ON)"* ]]; then
        $TERM_CMD bash -c "echo 'Removing kernel hardening...';
        sudo rm -f /etc/sysctl.d/99-tebian-hardening.conf;
        echo '';
        echo 'Done. The hardened values stay in effect until you reboot;';
        echo 'after that the kernel starts with its defaults again.';
        read -p 'Press Enter to close...'"
        if [ -f /etc/sysctl.d/99-tebian-hardening.conf ]; then
            tnotify "Security" "Kernel hardening is still on — see the terminal output"
        else
            tnotify "Security" "Kernel hardening off (defaults return after a reboot)"
        fi
    elif [[ "$S_CHOICE" == *"AppArmor"* ]]; then
        apparmor_menu
    elif [[ "$S_CHOICE" == *"Firejail App Sandbox (ON"* ]]; then
        FJ_ACT=$(echo -e "󰈡 Turn Off Sandboxing (keep Firejail installed)\n󰆴 Turn Off & Uninstall Firejail\n󰌍 Back" | tfuzzel -d -p " 󰈡 Firejail | ")
        [ -n "$FJ_ACT" ] || menu_close
        is_back "$FJ_ACT" && continue
        if [[ "$FJ_ACT" == *"Turn Off"* ]]; then
            $TERM_CMD bash -c "echo 'Removing Firejail sandboxing...';
            for bin in firefox firefox-esr chromium chromium-browser google-chrome-stable thunderbird evolution signal-desktop telegram-desktop discord; do
                if [ -L /usr/local/bin/\$bin ] && readlink /usr/local/bin/\$bin | grep -q firejail; then
                    sudo rm -f /usr/local/bin/\$bin;
                    echo \"Removed sandbox for \$bin\";
                fi
            done;
            if echo '$FJ_ACT' | grep -q 'Uninstall'; then
                echo '';
                echo 'Uninstalling Firejail...';
                sudo apt purge -y firejail firejail-profiles 2>/dev/null;
            fi;
            echo '';
            echo 'Done!';
            read -p 'Press Enter to close...'"
            # Drop the menu overrides, then put back those of apps whose
            # sandbox link is still there (sudo refused in the terminal):
            # without them their menu launches would run unsandboxed
            firejail_desktop_overrides remove
            FJ_COUNT=$(firejail_link_count)
            if [ "$FJ_COUNT" -gt 0 ]; then
                firejail_desktop_overrides add
                tnotify "Security" "Firejail sandbox is still on for $FJ_COUNT app$([ "$FJ_COUNT" = 1 ] || echo s) — see the terminal output"
            else
                tnotify "Security" "Firejail sandbox off"
            fi
        fi
    elif [[ "$S_CHOICE" == *"Firejail App Sandbox (OFF)"* ]]; then
        $TERM_CMD bash -c "echo 'Enabling Firejail sandboxing...';
        echo '';
        echo 'This sandboxes browsers AND networked apps:';
        echo '  Browsers: firefox, chromium, chrome';
        echo '  Email: thunderbird, evolution';
        echo '  Chat: signal, telegram, discord';
        echo '';
        echo 'Not covered: Helium (uses its own Chromium sandbox)';
        echo '             Zen (runs in the Flatpak sandbox)';
        echo '';
        sudo apt update && sudo apt install -y firejail firejail-profiles;
        for bin in firefox firefox-esr chromium chromium-browser google-chrome-stable thunderbird evolution signal-desktop telegram-desktop discord; do
            if command -v \$bin &>/dev/null; then
                sudo ln -sf /usr/bin/firejail /usr/local/bin/\$bin;
                echo \"Sandbox enabled for \$bin\";
            fi
        done;
        echo '';
        echo 'Done! Networked apps will launch in Firejail sandbox.';
        read -p 'Press Enter to close...'"
        firejail_desktop_overrides add
        FJ_COUNT=$(firejail_link_count)
        if [ "$FJ_COUNT" -gt 0 ]; then
            tnotify "Security" "Firejail sandbox on for $FJ_COUNT app$([ "$FJ_COUNT" = 1 ] || echo s) (menu launches included)"
        else
            tnotify "Security" "Firejail sandbox not turned on — no supported app found, or see the terminal output"
        fi
    elif [[ "$S_CHOICE" == *"Tor Routing (ON — via Paranoid)"* ]]; then
        tnotify "Security" "In Paranoid Mode all traffic goes through Tor — turn Paranoid Mode off to stop it"
    elif [[ "$S_CHOICE" == *"Tor Routing (ON)"* ]]; then
        TOR_ACT=$(echo -e "󰗹 Turn Off Tor (keep it installed)\n󰆴 Turn Off & Uninstall Tor\n󰌍 Back" | tfuzzel -d -p " 󰗹 Tor | ")
        [ -n "$TOR_ACT" ] || menu_close
        is_back "$TOR_ACT" && continue
        local tor_purge=""
        [[ "$TOR_ACT" =~ "Uninstall" ]] && tor_purge=1
        SECMOD="$(security_module)" TOR_PURGE="$tor_purge" $TERM_CMD bash -c '
        bash "$SECMOD" tor-off
        # Never remove Tor while transparent Tor still depends on it
        if [ -n "$TOR_PURGE" ] && [ ! -f /etc/tebian-tor-iptables.sh ]; then
            echo "Uninstalling Tor and proxychains4..."
            sudo apt purge -y tor proxychains4
            sudo apt autoremove -y
        fi
        read -p "Press Enter to close..."'
        if systemctl is-active --quiet tor 2>/dev/null; then
            tnotify "Security" "Tor is still running — see the terminal output"
        else
            tnotify "Security" "Tor routing off"
        fi
    elif [[ "$S_CHOICE" == *"Tor Routing (OFF)"* ]]; then
        SECMOD="$(security_module)" $TERM_CMD bash -c '
        bash "$SECMOD" tor-on
        echo ""
        echo "Example: proxychains4 curl https://check.torproject.org"
        read -p "Press Enter to close..."'
        if systemctl is-active --quiet tor 2>/dev/null; then
            tnotify "Security" "Tor routing on"
        fi
    elif [[ "$S_CHOICE" == *"DNS Privacy (ON)"* ]]; then
        SECMOD="$(security_module)" $TERM_CMD bash -c '
            source "$TEBIAN_COMMON"
            bash "$SECMOD" dns-off
            echo ""
            if dns_works; then
                echo "✅ Done — using your network'"'"'s DNS again."
            else
                echo "⚠️  DNS is not answering yet. Reconnecting to your network usually"
                echo "   fixes it; /etc/resolv.conf is back under NetworkManager."
            fi
            read -p "Press Enter to close..."
        '
        if [ -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf ]; then
            tnotify "Security" "DNS Privacy is still on — see the terminal output"
        else
            tnotify "Security" "DNS Privacy off"
        fi
    elif [[ "$S_CHOICE" == *"DNS Privacy (OFF)"* ]]; then
        DNS_PROVIDER=$(echo -e "󰇖 Quad9 (privacy + malware blocking)\n󰇖 Cloudflare (fast + privacy)\n󰌍 Back" | tfuzzel -d -p " 󰇖 DNS Provider | ")
        if [ -z "$DNS_PROVIDER" ] || is_back "$DNS_PROVIDER"; then continue; fi
        local dns_provider
        case "$DNS_PROVIDER" in
            *Cloudflare*) dns_provider=cloudflare ;;
            *Quad9*)      dns_provider=quad9 ;;
            *) continue ;;
        esac
        # The module checks that names still resolve and rolls back if not
        # (some networks block DNS-over-TLS's port 853)
        SECMOD="$(security_module)" DNS_PROVIDER="$dns_provider" $TERM_CMD bash -c '
            bash "$SECMOD" dns-on "$DNS_PROVIDER"
            read -p "Press Enter to close..."
        '
        if [ -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf ]; then
            tnotify "Security" "DNS Privacy on"
        else
            tnotify "Security" "DNS Privacy not enabled — see the terminal output"
        fi
    elif [[ "$S_CHOICE" == *"Auto Security Updates"* ]]; then
        auto_updates_toggle
    elif [[ "$S_CHOICE" == *"Security Tools"* ]]; then
        security_tools_menu
    elif [[ "$S_CHOICE" == *"View Open Ports"* ]]; then
        $TERM_CMD bash -c "echo '=== Open Ports ==='; echo ''; sudo ss -tulnp; echo ''; read -p 'Press Enter to close...'"
    elif [[ "$S_CHOICE" == *"View Security Logs"* ]]; then
        security_logs_menu
    fi
    security_record_profile
    done
}

# Skip Login After Disk Unlock: only offered when the system disk really is
# encrypted (tebian-autologin decides)
autologin_toggle() {
    local state
    state=$(tebian-autologin status 2>/dev/null)
    if [ "$state" != on ] && [ "$state" != off ]; then
        tnotify "Security" "Only for an encrypted system disk: there is no disk passphrase to unlock it with"
        return
    fi
    if [ "$state" = on ]; then
        $TERM_CMD bash -c 'tebian-autologin disable; echo; read -rp "Press Enter to close. "'
    else
        $TERM_CMD bash -c 'tebian-autologin enable; echo; read -rp "Press Enter to close. "'
    fi
    # Read back: the terminal step can be refused (sudo)
    case "$(tebian-autologin status 2>/dev/null)" in
        "$state") tnotify "Security" "Skip Login After Disk Unlock unchanged — see the terminal output" ;;
        on)       tnotify "Security" "Skip Login After Disk Unlock on (applies next boot)" ;;
        off)      tnotify "Security" "Skip Login After Disk Unlock off: login screen shown after disk unlock" ;;
    esac
}

# Remote access over SSH, on or off. The firewall opens the port(s) sshd
# really listens on — "ufw allow ssh" is port 22 only, which locks out a
# custom Port.
ssh_toggle() {
    local was=off
    systemctl is-active --quiet ssh && was=on
    if [ "$was" = off ]; then
        $TERM_CMD bash -c '
        echo "Enabling SSH Server..."
        sudo apt update && sudo apt install -y openssh-server
        sudo systemctl enable --now ssh
        if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
            for p in $(sudo sshd -T 2>/dev/null | awk "\$1 == \"port\" { print \$2 }"); do
                sudo ufw allow "$p/tcp" comment SSH >/dev/null && echo "Firewall: SSH port $p open."
            done
        fi
        echo ""
        echo "Done! You can now SSH into this machine."
        echo "Your IP addresses:"
        ip -4 a | grep inet | grep -v 127.0.0.1 | awk "{ print \"  \" \$2 }"
        read -p "Press Enter to close..."'
    else
        $TERM_CMD bash -c '
        echo "Disabling SSH Server..."
        ports=$(sudo sshd -T 2>/dev/null | awk "\$1 == \"port\" { print \$2 }")
        sudo systemctl stop ssh ssh.socket 2>/dev/null
        sudo systemctl disable ssh ssh.socket 2>/dev/null
        sudo ufw delete allow ssh >/dev/null 2>&1
        for p in $ports; do sudo ufw delete allow "$p/tcp" >/dev/null 2>&1; done
        echo "Done! SSH access disabled."
        read -p "Press Enter to close..."'
    fi
    # Read back: the install or sudo can fail inside the terminal
    local now=off
    systemctl is-active --quiet ssh && now=on
    if [ "$now" = "$was" ]; then
        tnotify "Security" "Remote Access / SSH unchanged (${now^^}) — see the terminal output"
    else
        tnotify "Security" "Remote Access / SSH ${now}"
    fi
}

# unattended-upgrades on or off; turning it off asks first
auto_updates_toggle() {
    local was=off
    dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii' && was=on
    if [ "$was" = on ]; then
        CONFIRM=$(echo -e "No, keep auto-updates\nYes, disable auto-updates" | tfuzzel -d --match-mode=exact -p " Disable auto security updates? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            $TERM_CMD bash -c "echo 'Disabling automatic security updates...';
            sudo apt remove -y unattended-upgrades;
            echo '';
            echo 'Auto-updates disabled. Run System Update manually.';
            read -p 'Press Enter to close...'"
            auto_updates_notify "$was"
        fi
    else
        $TERM_CMD bash -c "echo 'Enabling automatic security updates...';
        echo '';
        sudo apt update && sudo apt install -y unattended-upgrades;
        # Non-interactive configuration
        sudo mkdir -p /etc/apt/apt.conf.d;
        printf 'APT::Periodic::Update-Package-Lists \"1\";\nAPT::Periodic::Unattended-Upgrade \"1\";\n' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades;
        echo '';
        echo 'Auto-updates enabled! Security patches will install automatically.';
        read -p 'Press Enter to close...'"
        auto_updates_notify "$was"
    fi
}

# Read back after the terminal step; $1 is the state before it
auto_updates_notify() {
    local now=off
    dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii' && now=on
    if [ "$now" = "$1" ]; then
        tnotify "Security" "Auto security updates unchanged (${now^^}) — see the terminal output"
    else
        tnotify "Security" "Auto security updates ${now}"
    fi
}

# Passwordless sudo on/off. Tebian manages two drop-ins:
#   /etc/sudoers.d/tebian-sudo      USER ALL=(ALL:ALL) ALL          (password)
#   /etc/sudoers.d/tebian-nopasswd  USER ALL=(ALL:ALL) NOPASSWD: ALL
# Turning it off installs the password rule BEFORE removing any NOPASSWD
# grant: installs from before 3.2 gave the user sudo only through a
# NOPASSWD file (not the sudo group), so deleting it alone would take sudo
# away entirely. Every file is checked with visudo before it goes in.
passwordless_sudo_toggle() {
    # The menu passes its label; opened on its own, the state is read here
    local choice="${1:-}"
    if [ -z "$choice" ]; then
        if sudo -k -n true 2>/dev/null; then choice="(ON)"; else choice="(OFF)"; fi
    fi
    if [[ ! "$USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        tnotify "Security" "Unexpected username '$USER' — not touching sudoers"
        return
    fi
    if [[ "$choice" == *"(ON)"* ]]; then
        CONFIRM=$(echo -e "No, keep it\nYes, require my password for sudo" | tfuzzel -d --match-mode=exact -p " Require password for sudo? | ")
        [[ "$CONFIRM" =~ "Yes" ]] || return
        TUSER="$USER" $TERM_CMD bash -c '
            fail() { echo ""; echo "❌ $1 — nothing was changed."; read -p "Press Enter to close..."; exit 1; }
            u="$TUSER"
            # Without a usable password, password-required sudo is no sudo
            [ "$(sudo passwd -S "$u" 2>/dev/null | cut -d" " -f2)" = P ] ||
                fail "$u has no password set (run: passwd)"
            tmp=$(mktemp)
            printf "%s ALL=(ALL:ALL) ALL\n" "$u" > "$tmp"
            sudo visudo -cqf "$tmp" || fail "Generated rule did not validate"
            sudo install -o root -g root -m 0440 "$tmp" /etc/sudoers.d/tebian-sudo || fail "Could not install the rule"
            rm -f "$tmp"
            sudo rm -f /etc/sudoers.d/tebian-nopasswd
            # The installer'"'"'s old per-user file — removed only if it holds
            # nothing but that one line; anything else is the admin'"'"'s
            legacy="/etc/sudoers.d/$u"
            if sudo test -f "$legacy"; then
                if [ "$(sudo grep -cvE "^[[:space:]]*(#|$)" "$legacy")" = 1 ] &&
                   sudo grep -qxE "$u ALL=\(ALL(:ALL)?\) NOPASSWD: ?ALL" "$legacy"; then
                    sudo rm -f "$legacy"
                else
                    echo "Note: $legacy has other rules and was left as is."
                fi
            fi
            sudo visudo -cq || echo "⚠️  visudo reports a problem in another sudoers file — check: sudo visudo -c"
            echo ""
            if sudo -k -n true 2>/dev/null; then
                echo "⚠️  sudo still works without a password — another sudoers rule grants it."
            else
                echo "✅ sudo now asks for your password."
            fi
            read -p "Press Enter to close..."
        '
    else
        TUSER="$USER" $TERM_CMD bash -c '
            fail() { echo ""; echo "❌ $1 — nothing was changed."; read -p "Press Enter to close..."; exit 1; }
            u="$TUSER"
            echo "Allow sudo without a password for $u."
            echo "Anything running as you — including a compromised browser — then"
            echo "gets root silently. Password-required is the safer default."
            echo ""
            read -p "Type YES to continue: " c
            [ "$c" = YES ] || fail "Cancelled"
            tmp=$(mktemp)
            printf "%s ALL=(ALL:ALL) NOPASSWD: ALL\n" "$u" > "$tmp"
            sudo visudo -cqf "$tmp" || fail "Generated rule did not validate"
            sudo install -o root -g root -m 0440 "$tmp" /etc/sudoers.d/tebian-nopasswd || fail "Could not install the rule"
            rm -f "$tmp"
            echo ""
            echo "✅ Passwordless sudo enabled."
            read -p "Press Enter to close..."
        '
    fi
    # Read back: the terminal step can be cancelled or refused
    local now="(OFF)"
    sudo -k -n true 2>/dev/null && now="(ON)"
    if [[ "$choice" == *"$now"* ]]; then
        tnotify "Security" "Passwordless sudo unchanged $now"
    elif [ "$now" = "(ON)" ]; then
        tnotify "Security" "Passwordless sudo on"
    else
        tnotify "Security" "Passwordless sudo off: sudo asks for your password"
    fi
}

# How many apps the Firejail sandbox covers: its /usr/local/bin links
firejail_link_count() {
    local n=0 b
    for b in firefox firefox-esr chromium chromium-browser google-chrome-stable thunderbird evolution signal-desktop telegram-desktop discord; do
        [ -L "/usr/local/bin/$b" ] && n=$((n + 1))
    done
    echo "$n"
}

# The /usr/local/bin symlinks only catch launches by bare name. Menu entries
# whose Exec= holds an absolute path (firefox-esr's is
# /usr/lib/firefox-esr/firefox-esr) bypass them and run unsandboxed. For each
# sandboxed app, write a user override of its .desktop file with the path
# replaced by the bare name. Overrides are tagged so "remove" deletes only
# ours — never a .desktop file the user wrote.
firejail_desktop_overrides() {
    local mode="$1" dir="$HOME/.local/share/applications" f
    mkdir -p "$dir"
    if [ "$mode" = remove ]; then
        grep -l '^X-Tebian-Firejail=true' "$dir"/*.desktop 2>/dev/null | while read -r f; do rm -f "$f"; done
        return 0
    fi

    local link bin target
    for link in /usr/local/bin/*; do
        [ -L "$link" ] && readlink "$link" | grep -q firejail || continue
        bin=$(basename "$link")
        target=$(readlink -f "/usr/bin/$bin" 2>/dev/null)
        for f in /usr/share/applications/*.desktop; do
            [ -f "$f" ] || continue
            local out="$dir/$(basename "$f")"
            # A user's own override wins; leave it alone
            [ -f "$out" ] && ! grep -q '^X-Tebian-Firejail=true' "$out" && continue
            BIN="$bin" TARGET="$target" awk '
                BEGIN { hit = 0 }
                /^Exec=/ {
                    cmd = substr($0, 6); split(cmd, w, " ")
                    if (w[1] ~ /^\// && (w[1] ~ "/" ENVIRON["BIN"] "$" || (ENVIRON["TARGET"] != "" && w[1] == ENVIRON["TARGET"]))) {
                        sub(/^[^ ]+/, ENVIRON["BIN"], cmd); $0 = "Exec=" cmd; hit = 1
                    }
                }
                { lines[++n] = $0 }
                END {
                    if (!hit) exit 1
                    for (i = 1; i <= n; i++) {
                        print lines[i]
                        if (lines[i] == "[Desktop Entry]") print "X-Tebian-Firejail=true"
                    }
                }' "$f" > "$out.tmp" && mv "$out.tmp" "$out" || rm -f "$out.tmp"
        done
    done
}

# Pick a whole profile; the module applies it (the same code install and
# tebian-rebuild run). Paranoid has its own entry in the Security menu.
security_profile_menu() {
    local cur="${1:-$(security_current_profile)}" choice profile mark
    local -a rows=(
        "minimal|Minimal — firewall and fail2ban off"
        "standard|Standard — firewall, fail2ban, AppArmor, browser sandbox"
        "hardened|Hardened — Standard + kernel hardening, key-only SSH"
    )
    local menu="" row
    for row in "${rows[@]}"; do
        mark=""; [ "${row%%|*}" = "$cur" ] && mark="  ● current"
        menu+="${row#*|}$mark\n"
    done
    choice=$(echo -e "${menu}󰌍 Back" | tfuzzel -d -p " Profile | " --width 62)
    [ -n "$choice" ] || menu_close
    is_back "$choice" && return
    # By the leading name: the Hardened row mentions "Standard" too
    case "$choice" in
        "Minimal —"*)  profile=minimal ;;
        "Standard —"*) profile=standard ;;
        "Hardened —"*) profile=hardened ;;
        *) return ;;
    esac
    [ "$profile" = "$cur" ] && { tnotify "Security" "Already on the ${profile^} profile"; return; }

    local warn=""
    [ "$profile" = minimal ] && warn="turns the firewall off"
    [ "$cur" = paranoid ] && warn="ends Paranoid Mode (traffic stops going through Tor)"
    if [ -n "$warn" ]; then
        local confirm
        confirm=$(echo -e "No, cancel\nYes, switch to ${profile^}" | tfuzzel -d --match-mode=exact -p " This $warn | " --width 70)
        [[ "$confirm" =~ "Yes" ]] || return
    fi
    SECMOD="$(security_module)" PROFILE="$profile" $TERM_CMD bash -c '
        bash "$SECMOD" "$PROFILE"
        echo ""
        read -p "Press Enter to close..."'
    local now
    now=$(security_current_profile)
    tnotify "Security" "Security profile: ${now^}"
    # Opened from the search the Security menu isn't there to record it
    security_record_profile
}

# Record what the system is actually in — profile, Tor, DNS privacy — as
# this machine's choices (tebian_conf_set → machine.conf), so the next
# tebian-rebuild, Repair or update re-applies what the user chose here
# instead of the defaults (rebuild turns off Tor and DNS privacy that
# aren't recorded as on). Derived from the machine's state rather than from
# which menu entry was picked — the user can cancel inside the terminal.
security_record_profile() {
    local profile dns_conf=/etc/systemd/resolved.conf.d/99-tebian-dns.conf
    profile=$(security_current_profile)
    tebian_conf_set SECURITY_PROFILE "$profile"
    # Paranoid runs Tor itself; ENABLE_TOR is the per-app toggle
    if [ "$profile" != paranoid ]; then
        if systemctl is-active --quiet tor 2>/dev/null; then
            tebian_conf_set ENABLE_TOR yes
        else
            tebian_conf_set ENABLE_TOR no
        fi
    fi
    if [ -f "$dns_conf" ]; then
        tebian_conf_set ENABLE_DNS_PRIVACY yes
        if grep -qs cloudflare "$dns_conf"; then
            tebian_conf_set DNS_PROVIDER cloudflare
        else
            tebian_conf_set DNS_PROVIDER quad9
        fi
    else
        tebian_conf_set ENABLE_DNS_PRIVACY no
    fi
    # What Settings just did is what's applied — tebian-rebuild compares
    # against this so it doesn't re-run a whole profile over the toggles
    mkdir -p "$HOME/.local/share/tebian"
    echo "$profile" > "$HOME/.local/share/tebian/security-applied"
}

# Profiles stay in the modes Debian ships them in. Forcing all of them to
# enforce (aa-enforce /etc/apparmor.d/*) flips ones Debian deliberately
# ships in complain mode or disabled and breaks apps; forcing all to
# complain is weaker than stock Debian. Neither can be undone cleanly.
apparmor_menu() {
    if [ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" != Y ]; then
        tnotify "Security" "This kernel doesn't enable AppArmor — there is nothing to switch on"
        return
    fi
    local AA_OPTS=""
    if systemctl is-active --quiet apparmor 2>/dev/null; then
        AA_OPTS="󰒃 Turn Off AppArmor\n󰌍 Back"
    else
        AA_OPTS="󰒃 Turn On AppArmor (Debian's profiles)\n󰌍 Back"
    fi

    local AA_CHOICE
    AA_CHOICE=$(echo -e "$AA_OPTS" | tfuzzel -d -p " 󰒃 AppArmor | " --width 42)
    [ -n "$AA_CHOICE" ] || menu_close
    if is_back "$AA_CHOICE"; then return; fi

    if [[ "$AA_CHOICE" == *"Turn On"* ]]; then
        $TERM_CMD bash -c "echo 'Enabling AppArmor...';
        sudo apt install -y apparmor apparmor-utils;
        if sudo systemctl enable --now apparmor; then
            echo 'Done! AppArmor is on, with the profiles in the modes Debian ships them in.';
        else
            echo 'AppArmor could not be started — see: systemctl status apparmor';
        fi;
        read -p 'Press Enter to close...'"
        if systemctl is-active --quiet apparmor 2>/dev/null; then
            tnotify "Security" "AppArmor on"
        else
            tnotify "Security" "AppArmor not turned on — see the terminal output"
        fi
    elif [[ "$AA_CHOICE" == *"Turn Off"* ]]; then
        $TERM_CMD bash -c "echo 'Disabling AppArmor...';
        sudo systemctl stop apparmor;
        sudo systemctl disable apparmor;
        echo 'Done! AppArmor disabled.';
        echo 'Reboot may be needed for full effect.';
        read -p 'Press Enter to close...'"
        if systemctl is-active --quiet apparmor 2>/dev/null; then
            tnotify "Security" "AppArmor is still on — see the terminal output"
        else
            tnotify "Security" "AppArmor off"
        fi
    fi
}

security_logs_menu() {
    local LOG_OPTS=""
    # Build list of available log sources
    systemctl is-active --quiet fail2ban 2>/dev/null && LOG_OPTS+="󰍉 Fail2Ban Logs\n"
    # ufw.service is oneshot and "active" even with the firewall off
    grep -q '^ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null && LOG_OPTS+="󰍉 Firewall (UFW) Logs\n"
    systemctl is-active --quiet ssh 2>/dev/null && LOG_OPTS+="󰍉 SSH Auth Logs\n"
    LOG_OPTS+="󰍉 All Auth Logs\n"
    systemctl is-active --quiet apparmor 2>/dev/null && LOG_OPTS+="󰒃 AppArmor Denials\n"
    LOG_OPTS+="󰌍 Back"

    local LOG_CHOICE
    LOG_CHOICE=$(echo -e "$LOG_OPTS" | tfuzzel -d -p " 󰍉 Security Logs | ")
    [ -n "$LOG_CHOICE" ] || menu_close
    if is_back "$LOG_CHOICE"; then return; fi

    if [[ "$LOG_CHOICE" =~ "Fail2Ban" ]]; then
        $TERM_CMD bash -c "echo '=== Fail2Ban Logs ==='; echo ''; sudo journalctl -u fail2ban --no-pager -n 100; echo ''; read -p 'Press Enter to close...'"
    elif [[ "$LOG_CHOICE" =~ "Firewall" ]]; then
        $TERM_CMD bash -c "echo '=== UFW Firewall Logs ==='; echo ''; sudo journalctl -k --no-pager -n 200 | grep -i UFW | tail -50; echo ''; read -p 'Press Enter to close...'"
    elif [[ "$LOG_CHOICE" =~ "SSH Auth" ]]; then
        $TERM_CMD bash -c "echo '=== SSH Auth Logs ==='; echo ''; sudo journalctl -u ssh --no-pager -n 100; echo ''; read -p 'Press Enter to close...'"
    elif [[ "$LOG_CHOICE" =~ "All Auth" ]]; then
        $TERM_CMD bash -c "echo '=== Auth Logs ==='; echo ''; sudo tail -100 /var/log/auth.log 2>/dev/null || sudo journalctl -t sshd -t sudo --no-pager -n 100; echo ''; read -p 'Press Enter to close...'"
    elif [[ "$LOG_CHOICE" =~ "AppArmor" ]]; then
        $TERM_CMD bash -c "echo '=== AppArmor Denials ==='; echo ''; sudo journalctl -k --no-pager -n 200 | grep -i apparmor | tail -50; echo ''; read -p 'Press Enter to close...'"
    fi
}

security_tools_menu() {
    while true; do
    local boxes kali_label parrot_label
    boxes=$(distrobox list 2>/dev/null | awk -F'|' 'NR > 1 { gsub(/ /, "", $2); print $2 }')
    if grep -qx kali <<< "$boxes"; then kali_label="󰣖 Kali Linux Container (Installed)"; else kali_label="󰣖 Kali Linux Container (Not Installed)"; fi
    if grep -qx parrot <<< "$boxes"; then parrot_label="󰣖 Parrot OS Container (Installed)"; else parrot_label="󰣖 Parrot OS Container (Not Installed)"; fi
    ST_OPTS="󰍉 Recon & Scanning
󰖟 Web Application Testing
󰚑 Exploitation Frameworks
󰀂 Wireless Attacks
󰌆 Password Cracking
󰈈 Forensics & Recovery
󰛃 Sniffing & Spoofing
$kali_label
$parrot_label
󰌍 Back"

    ST_CHOICE=$(echo -e "$ST_OPTS" | tfuzzel -d -p " 󰒃 Security Tools | ")

    [ -n "$ST_CHOICE" ] || menu_close
    if is_back "$ST_CHOICE"; then return; fi

    if [[ "$ST_CHOICE" == *"Recon"* ]]; then
        sec_tool_install_menu "Recon & Scanning" \
            "nmap|Nmap - Network Scanner|apt" \
            "masscan|Masscan - Fast Port Scanner|apt" \
            "whois|Whois - Domain Lookup|apt" \
            "bind9-dnsutils|DNS Utils (dig, nslookup)|apt" \
            "netdiscover|Netdiscover - ARP Scanner|apt" \
            "recon-ng|Recon-ng - OSINT Framework|apt"
    elif [[ "$ST_CHOICE" == *"Web"* ]]; then
        sec_tool_install_menu "Web Application Testing" \
            "nikto|Nikto - Web Scanner|apt" \
            "sqlmap|SQLMap - SQL Injection|apt" \
            "gobuster|Gobuster - Dir/DNS Brute|apt" \
            "dirb|Dirb - Web Content Scanner|apt" \
            "burpsuite|Burp Suite (Kali Container)|distrobox" \
            "zaproxy|ZAP Proxy - Web App Scanner (Kali Container)|distrobox"
    elif [[ "$ST_CHOICE" == *"Exploitation"* ]]; then
        sec_tool_install_menu "Exploitation Frameworks" \
            "metasploit-framework|Metasploit (Kali Container)|distrobox" \
            "exploitdb|ExploitDB - Exploit Archive (Kali Container)|distrobox" \
            "set|Social Engineering Toolkit (Kali Container)|distrobox"
    elif [[ "$ST_CHOICE" == *"Wireless"* ]]; then
        sec_tool_install_menu "Wireless Attacks" \
            "aircrack-ng|Aircrack-ng - WiFi Cracking|apt" \
            "wifite|Wifite - Automated WiFi Attacks|apt" \
            "kismet|Kismet - Wireless Sniffer (Kali Container)|distrobox"
    elif [[ "$ST_CHOICE" == *"Password"* ]]; then
        sec_tool_install_menu "Password Cracking" \
            "john|John the Ripper|apt" \
            "hashcat|Hashcat - GPU Cracker|apt" \
            "hydra|Hydra - Login Brute Forcer|apt" \
            "medusa|Medusa - Parallel Brute Forcer|apt"
    elif [[ "$ST_CHOICE" == *"Forensics"* ]]; then
        sec_tool_install_menu "Forensics & Recovery" \
            "autopsy|Autopsy - Digital Forensics|apt" \
            "binwalk|Binwalk - Firmware Analysis|apt" \
            "foremost|Foremost - File Carver|apt" \
            "sleuthkit|Sleuth Kit - Disk Analysis|apt"
    elif [[ "$ST_CHOICE" == *"Sniffing"* ]]; then
        sec_tool_install_menu "Sniffing & Spoofing" \
            "wireshark|Wireshark - Packet Analyzer|apt" \
            "tcpdump|Tcpdump - CLI Packet Capture|apt" \
            "ngrep|Ngrep - Network Grep|apt" \
            "ettercap-text-only|Ettercap - MITM Framework|apt"
    elif [[ "$ST_CHOICE" == *"Kali Linux Container (Installed)"* ]]; then
        tnotify "Security Tools" "Kali container is set up — open it with: distrobox enter kali"
    elif [[ "$ST_CHOICE" == *"Parrot OS Container (Installed)"* ]]; then
        tnotify "Security Tools" "Parrot container is set up — open it with: distrobox enter parrot"
    elif [[ "$ST_CHOICE" == *"Kali Linux Container"* ]]; then
        $TERM_CMD bash -c "
            echo '=== Install Kali Linux Container ==='
            echo ''
            if ! command -v distrobox &>/dev/null; then
                echo 'Installing distrobox + podman...'
                sudo apt update && sudo apt install -y distrobox podman
            fi
            echo 'Creating Kali container (this may take a few minutes)...'
            distrobox create -n kali -i docker.io/kalilinux/kali-rolling -Y
            echo ''
            echo 'Done! Enter with: distrobox enter kali'
            echo 'Then install tools: sudo apt install -y kali-linux-headless'
            read -p 'Press Enter to close...'
        "
    elif [[ "$ST_CHOICE" == *"Parrot OS Container"* ]]; then
        $TERM_CMD bash -c "
            echo '=== Install Parrot OS Container ==='
            echo ''
            if ! command -v distrobox &>/dev/null; then
                echo 'Installing distrobox + podman...'
                sudo apt update && sudo apt install -y distrobox podman
            fi
            echo 'Creating Parrot container (this may take a few minutes)...'
            distrobox create -n parrot -i docker.io/parrotsec/security -Y
            echo ''
            echo 'Done! Enter with: distrobox enter parrot'
            read -p 'Press Enter to close...'
        "
    fi
    done
}

sec_tool_install_menu() {
    local CATEGORY="$1"
    shift
    local -a TOOLS=("$@")

    while true; do
    # Build menu with install state
    local MENU_ITEMS=""

    for TOOL_SPEC in "${TOOLS[@]}"; do
        local PKG="${TOOL_SPEC%%|*}"
        local REST="${TOOL_SPEC#*|}"
        local DISPLAY="${REST%%|*}"
        local METHOD="${REST##*|}"

        local PREFIX="\n"
        [ -z "$MENU_ITEMS" ] && PREFIX=""
        # State in words: Text Mode strips the glyphs. Container tools get
        # none — whether the tool is inside the container isn't cheap to ask
        if [[ "$METHOD" == "distrobox" ]]; then
            MENU_ITEMS+="${PREFIX}󰣖 $DISPLAY"
        elif dpkg -l "$PKG" 2>/dev/null | grep -q "^ii"; then
            MENU_ITEMS+="${PREFIX}󰄬 $DISPLAY (Installed)"
        else
            MENU_ITEMS+="${PREFIX}󰄰 $DISPLAY (Not Installed)"
        fi
    done
    MENU_ITEMS+="\n󰌍 Back"

    local CHOICE
    CHOICE=$(echo -e "$MENU_ITEMS" | tfuzzel -d -p " 󰒃 $CATEGORY | ")

    [ -n "$CHOICE" ] || menu_close
    if is_back "$CHOICE"; then return; fi

    # Find which tool was selected
    for TOOL_SPEC in "${TOOLS[@]}"; do
        local PKG="${TOOL_SPEC%%|*}"
        local REST="${TOOL_SPEC#*|}"
        local DISPLAY="${REST%%|*}"
        local METHOD="${REST##*|}"

        if [[ "$CHOICE" == *"$DISPLAY"* ]]; then
            if [[ "$METHOD" == "distrobox" ]]; then
                $TERM_CMD bash -c "
                    echo '=== $DISPLAY ==='
                    echo ''
                    echo 'This tool runs inside a Kali container.'
                    if ! command -v distrobox &>/dev/null; then
                        echo 'Installing distrobox + podman...'
                        sudo apt update && sudo apt install -y distrobox podman
                    fi
                    if ! distrobox list 2>/dev/null | grep -q 'kali'; then
                        echo 'Creating Kali container...'
                        distrobox create -n kali -i docker.io/kalilinux/kali-rolling -Y
                    fi
                    echo 'Installing $PKG in Kali container...'
                    distrobox enter kali -- sudo apt update
                    distrobox enter kali -- sudo apt install -y $PKG
                    echo ''
                    echo 'Done! Run with: distrobox enter kali -- $PKG'
                    read -p 'Press Enter to close...'
                "
            else
                if dpkg -l "$PKG" 2>/dev/null | grep -q "^ii"; then
                    $TERM_CMD bash -c "
                        echo '=== $DISPLAY ==='
                        echo ''
                        echo 'Already installed.'
                        echo ''
                        apt-cache show '$PKG' 2>/dev/null | grep -E '^(Description|Size):' | head -5
                        echo ''
                        read -p 'Uninstall? [y/N]: ' confirm
                        if [[ \"\$confirm\" =~ ^[Yy]$ ]]; then
                            sudo apt remove -y '$PKG'
                            echo 'Removed.'
                        fi
                        read -p 'Press Enter to close...'
                    "
                else
                    $TERM_CMD bash -c "
                        echo '=== $DISPLAY ==='
                        echo ''
                        apt-cache show '$PKG' 2>/dev/null | grep -E '^(Description|Size):' | head -5
                        echo ''
                        echo 'Installing $PKG...'
                        sudo apt update && sudo apt install -y '$PKG'
                        echo ''
                        echo 'Done!'
                        read -p 'Press Enter to close...'
                    "
                fi
            fi
            break
        fi
    done
    done
}

# The VMs live in the system libvirt (tebian-isolated-workspace sets
# qemu:///system); a plain virsh as the user asks qemu:///session, finds
# nothing, and the menu offered Setup for a workspace that exists.
secure_workspace_menu() {
    local -a VIRSH=(virsh -c qemu:///system)
    while true; do
    # Detect state
    if command -v virsh &>/dev/null && "${VIRSH[@]}" dominfo tebian-workstation &>/dev/null; then
        WS_STATE=$("${VIRSH[@]}" domstate tebian-workstation 2>/dev/null || echo "unknown")
        GW_STATE=$("${VIRSH[@]}" domstate tebian-gateway 2>/dev/null || echo "unknown")

        SW_OPTS="󰋽 Gateway: $GW_STATE
󰋽 Workstation: $WS_STATE"
        if [[ "$WS_STATE" == "running" ]]; then
            SW_OPTS+="\n󰅖 Stop Workspace
󰍹 Open Workstation (virt-viewer)"
        else
            SW_OPTS+="\n󰐊 Start Workspace"
        fi
        SW_OPTS+="\n󰩈 Destroy Workspace (delete everything)"
        SW_OPTS+="\n󰌍 Back"
    else
        SW_OPTS="󰗹 Setup Secure Workspace
Architecture:
  Workstation ──▶ Gateway ──▶ Tor ──▶ Internet
  (your work)    (Tor proxy)
  Can't leak IP. Even if compromised.
󰌍 Back"
    fi

    SW_CHOICE=$(echo -e "$SW_OPTS" | tfuzzel -d -p " 󰗹 Secure Workspace | ")

    [ -n "$SW_CHOICE" ] || menu_close
    if is_back "$SW_CHOICE"; then return; fi

    if [[ "$SW_CHOICE" == *"Setup Secure Workspace"* ]]; then
        $TERM_CMD bash -c "
            tebian-isolated-workspace setup
            read -p 'Press Enter to close...'
        "
    elif [[ "$SW_CHOICE" == *"Start Workspace"* ]]; then
        $TERM_CMD bash -c "
            tebian-isolated-workspace start
            read -p 'Press Enter to close...'
        "
    elif [[ "$SW_CHOICE" == *"Stop Workspace"* ]]; then
        $TERM_CMD bash -c "
            tebian-isolated-workspace stop
            read -p 'Press Enter to close...'
        "
    elif [[ "$SW_CHOICE" == *"Open Workstation"* ]]; then
        tebian_term_apt_install virt-viewer || continue
        virt-viewer -c qemu:///system tebian-workstation &>/dev/null &
    elif [[ "$SW_CHOICE" == *"Destroy Workspace"* ]]; then
        $TERM_CMD bash -c "
            tebian-isolated-workspace destroy
            read -p 'Press Enter to close...'
        "
    fi
    done
}

# Change the login password and, on an encrypted system, offer to make it the
# disk passphrase too — passwd alone would let the two drift apart, and with
# "Skip Login After Disk Unlock" the disk passphrase is what opens the desktop.
change_password_flow() {
    $TERM_CMD bash -c '
        echo "Change your login password"
        echo "(used for the lock screen, sudo and the login screen)"
        echo
        passwd || { echo; read -rp "Password not changed. Press Enter to close. "; exit 1; }

        src=$(findmnt -no SOURCE / 2>/dev/null)
        # lsblk -s walks from / down to the disk; the row after "crypt" is
        # the encrypted partition itself
        luks=$(lsblk -snrpo NAME,TYPE "$src" 2>/dev/null | awk "f { print \$1; exit } \$2 == \"crypt\" { f = 1 }")
        if [ -n "$luks" ]; then
            echo
            echo "Your disk is encrypted ($luks)."
            read -rp "Use the new password to unlock the disk too? [Y/n] " a
            if [ -z "$a" ] || [[ "$a" =~ ^[Yy] ]]; then
                echo
                echo "cryptsetup will ask for the CURRENT disk passphrase, then the new one twice."
                if sudo cryptsetup luksChangeKey "$luks"; then
                    echo; echo "Disk passphrase updated."
                else
                    echo; echo "Disk passphrase NOT changed — it is still the old one."
                fi
            fi
        fi
        echo
        read -rp "Done. Press Enter to close. "
    '
}
