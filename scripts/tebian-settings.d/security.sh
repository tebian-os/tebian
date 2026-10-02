# shellcheck shell=bash
# tebian-settings module: security.sh
# Sourced by tebian-settings — do not run directly

# AppArmor profile mode — /sys/.../profiles is root-readable only and lines
# look like "name (enforce)". Echoes: enforce | complain | unknown
# (unknown when sudo creds aren't cached and the file can't be read)
aa_profile_mode() {
    local n
    n=$(sudo -n grep -c '(enforce)' /sys/kernel/security/apparmor/profiles 2>/dev/null)
    if [ -z "$n" ]; then echo "unknown"
    elif [ "$n" -gt 0 ]; then echo "enforce"
    else echo "complain"; fi
}

security_menu() {
    while true; do
    # Detect state without sudo where possible. ufw.service is oneshot and
    # reports "active" even when ENABLED=no — the conf file is the real state.
    UFW_ACTIVE=$(grep -q '^ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null && echo "ON" || echo "OFF")
    F2B_ACTIVE=$(systemctl is-active --quiet fail2ban && echo "ON" || echo "OFF")
    SSH_ACTIVE=$(systemctl is-active --quiet ssh && echo "ON" || echo "OFF")

    if [[ "$UFW_ACTIVE" == "ON" ]]; then
        SEC_LABEL="🔓 Restore Standard Security (Current: Hardened)"
    else
        SEC_LABEL="🛡️ Enable Hardened Security (Current: Standard)"
    fi

    if [[ "$SSH_ACTIVE" == "ON" ]]; then
        SSH_LABEL="🛑 Disable Remote Access (SSH)"
    else
        SSH_LABEL="🌍 Enable Remote Access (SSH)"
    fi

    # Detect SSH key-only mode — check our specific file, not all of sshd_config.d
    if [ -f /etc/ssh/sshd_config.d/99-tebian-keyonly.conf ]; then
        SSH_KEY_LABEL="🔑 Revert SSH to Password Auth (Current: Key-Only)"
    else
        SSH_KEY_LABEL="🔑 Harden SSH (Key-Only Mode)"
    fi

    # Detect kernel hardening sysctl
    if [ -f /etc/sysctl.d/99-tebian-hardening.conf ]; then
        KERN_LABEL="🧠 Remove Kernel Hardening (Current: Hardened)"
    else
        KERN_LABEL="🧠 Enable Kernel Hardening"
    fi

    # Detect AppArmor state — Enforcing / Complain / Active(unknown) / Off
    if systemctl is-active --quiet apparmor 2>/dev/null && [ -d /sys/kernel/security/apparmor ]; then
        case "$(aa_profile_mode)" in
            enforce)  AA_LABEL="󰒃 AppArmor (Enforcing)" ;;
            complain) AA_LABEL="󰒃 AppArmor (Complain)" ;;
            *)        AA_LABEL="󰒃 AppArmor (Active)" ;;
        esac
    else
        AA_LABEL="󰒃 AppArmor (OFF)"
    fi

    # Detect Firejail sandbox (browsers + networked apps)
    FJ_COUNT=0
    for _fj_bin in firefox firefox-esr chromium chromium-browser google-chrome-stable thunderbird evolution signal-desktop telegram-desktop discord; do
        [ -L /usr/local/bin/$_fj_bin ] && FJ_COUNT=$((FJ_COUNT + 1))
    done
    if [ "$FJ_COUNT" -gt 0 ]; then
        FJ_LABEL="󰈡 Firejail App Sandbox (ON — $FJ_COUNT apps)"
    else
        FJ_LABEL="󰈡 Firejail App Sandbox (OFF)"
    fi

    # Detect Tor
    if systemctl is-active --quiet tor 2>/dev/null; then
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

    # Detect Paranoid Mode (transparent Tor + MAC randomization)
    if [ -f /etc/systemd/system/tebian-tor-iptables.service ] && [ -f /etc/NetworkManager/conf.d/99-tebian-mac-random.conf ]; then
        PARANOID_LABEL="☠️ Paranoid Mode (ON)"
    else
        PARANOID_LABEL="☠️ Paranoid Mode (OFF)"
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
        SUDO_LABEL="🔑 Passwordless sudo (Current: On)"
    else
        SUDO_LABEL="🔑 Passwordless sudo (Current: Off)"
    fi

    # Skip the login screen after the disk passphrase — only offered when the
    # system disk really is encrypted (tebian-autologin decides)
    AUTOLOGIN_LABEL=""
    case "$(tebian-autologin status 2>/dev/null)" in
        on)  AUTOLOGIN_LABEL="🔓 Skip Login After Disk Unlock (Current: On)" ;;
        off) AUTOLOGIN_LABEL="🔓 Skip Login After Disk Unlock (Current: Off)" ;;
    esac

    SEC_OPTS="$PARANOID_LABEL
$SEC_LABEL
🔑 Change Password
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

    S_CHOICE=$(echo -e "$SEC_OPTS" | tfuzzel -d -p " Security | ")

    if is_back "$S_CHOICE"; then return; fi

    if [[ "$S_CHOICE" =~ "Paranoid Mode" ]] && [[ "$S_CHOICE" =~ "ON" ]]; then
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
        tnotify "Security" "Paranoid Mode disabled"
    elif [[ "$S_CHOICE" =~ "Paranoid Mode" ]]; then
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
    elif [[ "$S_CHOICE" =~ "Enable Hardened Security" ]]; then
        $TERM_CMD bash -c "echo 'Hardening System...';
        sudo apt update && sudo apt install -y ufw fail2ban;
        sudo ufw default deny incoming;
        # Only allow SSH if it was explicitly enabled
        if systemctl is-active --quiet ssh; then
            sudo ufw allow ssh
        fi
        sudo ufw --force enable;
        sudo systemctl enable --now fail2ban;
        echo 'Done! Firewall active and Fail2Ban running.';
        read -p 'Press Enter to close...'"
        tnotify "Security" "Hardened security enabled"
    elif [[ "$S_CHOICE" =~ "Restore Standard Security" ]]; then
        CONFIRM=$(echo -e "No, cancel\nYes, remove security hardening" | tfuzzel -d --match-mode=exact -p " ⚠️ Remove firewall & fail2ban? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            $TERM_CMD bash -c "echo 'Relaxing Security...';
            sudo ufw --force reset;
            sudo ufw disable;
            sudo systemctl stop fail2ban 2>/dev/null;
            sudo systemctl disable fail2ban 2>/dev/null;
            sudo apt purge -y fail2ban 2>/dev/null;
            echo 'Done! Firewall reset and Fail2Ban removed.';
            read -p 'Press Enter to close...'"
            tnotify "Security" "Standard security restored"
        fi
    elif [[ "$S_CHOICE" =~ "Passwordless sudo" ]]; then
        passwordless_sudo_toggle "$S_CHOICE"
    elif [[ "$S_CHOICE" =~ "Change Password" ]]; then
        change_password_flow
    elif [[ "$S_CHOICE" =~ "Skip Login After Disk Unlock" ]]; then
        if [[ "$S_CHOICE" =~ "Current: On" ]]; then
            $TERM_CMD bash -c 'tebian-autologin disable; echo; read -rp "Press Enter to close. "'
            tnotify "Security" "Login screen shown after disk unlock"
        else
            $TERM_CMD bash -c 'tebian-autologin enable; echo; read -rp "Press Enter to close. "'
            tnotify "Security" "Desktop opens after disk unlock (applies next boot)"
        fi
    elif [[ "$S_CHOICE" =~ "Enable Remote Access" ]]; then
        $TERM_CMD bash -c "echo 'Enabling SSH Server...';
        sudo apt update && sudo apt install -y openssh-server;
        sudo systemctl enable --now ssh;
        # If firewall is active, allow SSH
        if sudo ufw status 2>/dev/null | grep -q 'Status: active'; then
            sudo ufw allow ssh;
            echo 'Firewall updated to allow SSH.';
        fi
        echo '';
        echo 'Done! You can now SSH into this machine.';
        echo 'Your IP addresses:';
        ip -4 a | grep inet | grep -v 127.0.0.1 | awk '{print \"  \" \$2}';
        read -p 'Press Enter to close...'"
        tnotify "Security" "SSH enabled"
    elif [[ "$S_CHOICE" =~ "Disable Remote Access" ]]; then
        $TERM_CMD bash -c "echo 'Disabling SSH Server...';
        sudo systemctl stop ssh;
        sudo systemctl disable ssh;
        sudo ufw delete allow ssh 2>/dev/null;
        echo 'Done! SSH access disabled.';
        read -p 'Press Enter to close...'"
        tnotify "Security" "SSH disabled"
    elif [[ "$S_CHOICE" =~ "Key-Only Mode" ]]; then
        if [[ "$SSH_ACTIVE" != "ON" ]]; then
            tnotify "Security" "SSH is not enabled. Enable SSH first."
        else
            $TERM_CMD bash -c "echo 'Hardening SSH to Key-Only Mode...';
            echo '';
            echo '⚠️  Make sure you have an SSH key configured!';
            echo '   Without one, you will be locked out of remote access.';
            echo '';
            read -p 'Continue? [y/N]: ' confirm;
            if [[ \"\$confirm\" =~ ^[Yy]$ ]]; then
                printf 'PasswordAuthentication no\nX11Forwarding no\n' | sudo tee /etc/ssh/sshd_config.d/99-tebian-keyonly.conf;
                sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null;
                echo '';
                echo 'Done! Password login is now disabled.';
            else
                echo 'Cancelled.';
            fi;
            read -p 'Press Enter to close...'"
            # Only report success if the user actually confirmed inside the
            # terminal (the conf file is only written on confirm)
            if [ -f /etc/ssh/sshd_config.d/99-tebian-keyonly.conf ]; then
                tnotify "Security" "SSH set to key-only"
            fi
        fi
    elif [[ "$S_CHOICE" =~ "Revert SSH to Password" ]]; then
        $TERM_CMD bash -c "echo 'Reverting SSH to allow password auth...';
        sudo rm -f /etc/ssh/sshd_config.d/99-tebian-keyonly.conf;
        sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null;
        echo 'Done! Password authentication restored.';
        read -p 'Press Enter to close...'"
        tnotify "Security" "SSH password auth restored"
    elif [[ "$S_CHOICE" =~ "Enable Kernel Hardening" ]]; then
        $TERM_CMD bash -c "echo 'Applying kernel hardening...';
        cat <<'SYSEOF' | sudo tee /etc/sysctl.d/99-tebian-hardening.conf
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
SYSEOF
        sudo sysctl -p /etc/sysctl.d/99-tebian-hardening.conf;
        echo '';
        echo 'Done! Kernel hardening applied.';
        read -p 'Press Enter to close...'"
        tnotify "Security" "Kernel hardening enabled"
    elif [[ "$S_CHOICE" =~ "Remove Kernel Hardening" ]]; then
        $TERM_CMD bash -c "echo 'Removing kernel hardening...';
        sudo rm -f /etc/sysctl.d/99-tebian-hardening.conf;
        sudo sysctl --system 2>&1 | tail -3;
        echo '';
        echo 'Done! System defaults restored.';
        read -p 'Press Enter to close...'"
        tnotify "Security" "Kernel hardening removed"
    elif [[ "$S_CHOICE" =~ "AppArmor" ]]; then
        apparmor_menu
    elif [[ "$S_CHOICE" =~ "Firejail" ]] && [[ "$S_CHOICE" =~ "ON" ]]; then
        FJ_ACT=$(echo -e "󰈡 Disable Sandboxing (keep Firejail)\n󰆴 Disable & Uninstall Firejail\n󰌍 Back" | tfuzzel -d -p " 󰈡 Firejail | ")
        if is_back "$FJ_ACT"; then continue; fi
        if [[ "$FJ_ACT" =~ "Disable Sandboxing" ]] || [[ "$FJ_ACT" =~ "Uninstall" ]]; then
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
            firejail_desktop_overrides remove
            tnotify "Security" "Firejail sandboxing disabled"
        fi
    elif [[ "$S_CHOICE" =~ "Firejail" ]]; then
        $TERM_CMD bash -c "echo 'Enabling Firejail sandboxing...';
        echo '';
        echo 'This sandboxes browsers AND networked apps:';
        echo '  Browsers: firefox, chromium, chrome';
        echo '  Email: thunderbird, evolution';
        echo '  Chat: signal, telegram, discord';
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
        tnotify "Security" "Firejail sandboxing enabled (menu launches included)"
    elif [[ "$S_CHOICE" =~ "Tor" ]] && [[ "$S_CHOICE" =~ "ON" ]]; then
        TOR_ACT=$(echo -e "󰗹 Disable Tor Service\n󰆴 Disable & Uninstall Tor\n󰌍 Back" | tfuzzel -d -p " 󰗹 Tor | ")
        if is_back "$TOR_ACT"; then continue; fi
        $TERM_CMD bash -c "echo 'Disabling Tor routing...';
        sudo systemctl stop tor;
        sudo systemctl disable tor;
        if echo '$TOR_ACT' | grep -q 'Uninstall'; then
            echo 'Uninstalling Tor and proxychains4...';
            sudo apt purge -y tor proxychains4 2>/dev/null;
            sudo apt autoremove -y 2>/dev/null;
        fi;
        echo 'Done!';
        read -p 'Press Enter to close...'"
        tnotify "Security" "Tor routing disabled"
    elif [[ "$S_CHOICE" =~ "Tor" ]]; then
        $TERM_CMD bash -c "echo 'Enabling Tor routing (per-app via proxychains4)...';
        sudo apt update && sudo apt install -y tor proxychains4;
        if [ -f /etc/proxychains4.conf ]; then
            sudo sed -i 's/^strict_chain/#strict_chain/' /etc/proxychains4.conf;
            sudo sed -i 's/^#dynamic_chain/dynamic_chain/' /etc/proxychains4.conf;
        fi;
        sudo systemctl enable --now tor;
        echo '';
        echo 'Done! Use: proxychains4 <command> to route through Tor';
        echo 'Example: proxychains4 curl https://check.torproject.org';
        read -p 'Press Enter to close...'"
        tnotify "Security" "Tor routing enabled"
    elif [[ "$S_CHOICE" =~ "DNS Privacy" ]] && [[ "$S_CHOICE" =~ "ON" ]]; then
        $TERM_CMD bash -c '
            source "$TEBIAN_COMMON"
            echo "Disabling DNS-over-TLS..."
            dns_privacy_off
            echo ""
            if dns_works; then
                echo "✅ Done — using your network'"'"'s DNS again."
            else
                echo "⚠️  DNS is not answering yet. Reconnecting to your network usually"
                echo "   fixes it; /etc/resolv.conf is back under NetworkManager."
            fi
            read -p "Press Enter to close..."
        '
        tnotify "Security" "DNS Privacy disabled"
    elif [[ "$S_CHOICE" =~ "DNS Privacy" ]]; then
        DNS_PROVIDER=$(echo -e "🛡️ Quad9 (privacy + malware blocking)\n⚡ Cloudflare (fast + privacy)\n󰌍 Back" | tfuzzel -d -p " 󰇖 DNS Provider | ")
        if is_back "$DNS_PROVIDER"; then continue; fi
        local dns_servers
        case "$DNS_PROVIDER" in
            *Cloudflare*) dns_servers="1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com" ;;
            *Quad9*)      dns_servers="9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net" ;;
            *) continue ;;
        esac
        # Servers go in through the environment, never pasted into the script
        DNS_SERVERS="$dns_servers" $TERM_CMD bash -c '
            source "$TEBIAN_COMMON"
            echo "Enabling DNS-over-TLS..."
            echo ""
            # systemd-resolved is its own package on Debian 13 and is not
            # installed by default. Installing it is the first step, and the
            # only one allowed to fail: nothing has been changed yet.
            if ! dpkg-query -W -f="\${Status}" systemd-resolved 2>/dev/null | grep -q "ok installed"; then
                if ! sudo apt install -y systemd-resolved; then
                    echo ""
                    echo "❌ Could not install systemd-resolved — DNS left unchanged."
                    read -p "Press Enter to close..."; exit 1
                fi
            fi
            sudo mkdir -p /etc/systemd/resolved.conf.d /etc/NetworkManager/conf.d
            printf "[Resolve]\nDNS=%s\nDNSOverTLS=yes\nDNSSEC=allow-downgrade\nDomains=~.\n" "$DNS_SERVERS" |
                sudo tee /etc/systemd/resolved.conf.d/99-tebian-dns.conf > /dev/null
            printf "[main]\ndns=systemd-resolved\n" |
                sudo tee /etc/NetworkManager/conf.d/99-tebian-dns-resolved.conf > /dev/null
            sudo systemctl enable systemd-resolved
            sudo systemctl restart systemd-resolved
            sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
            sudo systemctl restart NetworkManager
            echo ""
            echo "Checking that names still resolve..."
            if dns_works; then
                echo "✅ DNS-over-TLS enabled."
            else
                # Some networks block port 853 (DNS-over-TLS). Leaving the
                # machine without DNS is worse than no privacy — roll back.
                echo "❌ No DNS answers over TLS (the network may block port 853)."
                echo "   Rolling back to your network'"'"'s DNS..."
                dns_privacy_off
            fi
            read -p "Press Enter to close..."
        '
        if [ -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf ]; then
            tnotify "Security" "DNS Privacy enabled"
        else
            tnotify "Security" "DNS Privacy not enabled — see the terminal output"
        fi
    elif [[ "$S_CHOICE" =~ "Auto Security Updates" ]] && [[ "$S_CHOICE" =~ "ON" ]]; then
        CONFIRM=$(echo -e "No, keep auto-updates\nYes, disable auto-updates" | tfuzzel -d --match-mode=exact -p " ⚠️ Disable auto security updates? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            $TERM_CMD bash -c "echo 'Disabling automatic security updates...';
            sudo apt remove -y unattended-upgrades;
            echo '';
            echo 'Auto-updates disabled. Run System Update manually.';
            read -p 'Press Enter to close...'"
            tnotify "Security" "Auto security updates disabled"
        fi
    elif [[ "$S_CHOICE" =~ "Auto Security Updates" ]]; then
        $TERM_CMD bash -c "echo 'Enabling automatic security updates...';
        echo '';
        sudo apt update && sudo apt install -y unattended-upgrades;
        # Non-interactive configuration
        sudo mkdir -p /etc/apt/apt.conf.d;
        printf 'APT::Periodic::Update-Package-Lists \"1\";\nAPT::Periodic::Unattended-Upgrade \"1\";\n' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades;
        echo '';
        echo 'Auto-updates enabled! Security patches will install automatically.';
        read -p 'Press Enter to close...'"
        tnotify "Security" "Auto security updates enabled"
    elif [[ "$S_CHOICE" =~ "Security Tools" ]]; then
        security_tools_menu
    elif [[ "$S_CHOICE" =~ "View Open Ports" ]]; then
        $TERM_CMD bash -c "echo '=== Open Ports ==='; echo ''; sudo ss -tulnp; echo ''; read -p 'Press Enter to close...'"
    elif [[ "$S_CHOICE" =~ "View Security Logs" ]]; then
        security_logs_menu
    fi
    security_record_profile
    done
}

# Passwordless sudo on/off. Tebian manages two drop-ins:
#   /etc/sudoers.d/tebian-sudo      USER ALL=(ALL:ALL) ALL          (password)
#   /etc/sudoers.d/tebian-nopasswd  USER ALL=(ALL:ALL) NOPASSWD: ALL
# Turning it off installs the password rule BEFORE removing any NOPASSWD
# grant: installs from before 3.2 gave the user sudo only through a
# NOPASSWD file (not the sudo group), so deleting it alone would take sudo
# away entirely. Every file is checked with visudo before it goes in.
passwordless_sudo_toggle() {
    local choice="$1"
    if [[ ! "$USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        tnotify "Security" "Unexpected username '$USER' — not touching sudoers"
        return
    fi
    if [[ "$choice" =~ "Current: On" ]]; then
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

# Write the profile the system is actually in to tebian.conf, so the next
# tebian-rebuild re-applies what the user chose here instead of the default
# ("standard"). Derived from the machine's state rather than from which
# menu entry was picked — the user can cancel inside the terminal.
security_record_profile() {
    local profile=minimal
    if systemctl is-enabled --quiet tebian-tor-iptables 2>/dev/null; then
        profile=paranoid
    elif [ -f /etc/sysctl.d/99-tebian-hardening.conf ]; then
        profile=hardened
    elif grep -q '^ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null; then
        profile=standard
    fi
    tebian_conf_set SECURITY_PROFILE "$profile"
    # What Settings just did is what's applied — tebian-rebuild compares
    # against this so it doesn't re-run a whole profile over the toggles
    mkdir -p "$HOME/.local/share/tebian"
    echo "$profile" > "$HOME/.local/share/tebian/security-applied"
}

apparmor_menu() {
    local AA_OPTS=""
    if systemctl is-active --quiet apparmor 2>/dev/null && [ -d /sys/kernel/security/apparmor ]; then
        case "$(aa_profile_mode)" in
            enforce)  AA_OPTS="󰒃 Switch to Complain Mode\n󰒃 Disable AppArmor\n󰌍 Back" ;;
            complain) AA_OPTS="󰒃 Switch to Enforce Mode\n󰒃 Disable AppArmor\n󰌍 Back" ;;
            *)        AA_OPTS="󰒃 Switch to Enforce Mode\n󰒃 Switch to Complain Mode\n󰒃 Disable AppArmor\n󰌍 Back" ;;
        esac
    else
        AA_OPTS="󰒃 Enable AppArmor (Enforce)\n󰒃 Enable AppArmor (Complain)\n󰌍 Back"
    fi

    local AA_CHOICE
    AA_CHOICE=$(echo -e "$AA_OPTS" | tfuzzel -d -p " 󰒃 AppArmor | ")
    if is_back "$AA_CHOICE"; then return; fi

    if [[ "$AA_CHOICE" =~ "Enforce" ]]; then
        $TERM_CMD bash -c "echo 'Setting AppArmor to enforce mode...';
        sudo apt install -y apparmor apparmor-utils 2>/dev/null;
        sudo systemctl enable --now apparmor 2>/dev/null;
        sudo aa-enforce /etc/apparmor.d/* 2>/dev/null;
        echo 'Done! AppArmor set to enforce mode.';
        read -p 'Press Enter to close...'"
        tnotify "Security" "AppArmor set to enforce"
    elif [[ "$AA_CHOICE" =~ "Complain" ]]; then
        $TERM_CMD bash -c "echo 'Setting AppArmor to complain mode...';
        sudo apt install -y apparmor apparmor-utils 2>/dev/null;
        sudo systemctl enable --now apparmor 2>/dev/null;
        sudo aa-complain /etc/apparmor.d/* 2>/dev/null;
        echo 'Done! AppArmor set to complain mode (logging only).';
        read -p 'Press Enter to close...'"
        tnotify "Security" "AppArmor set to complain"
    elif [[ "$AA_CHOICE" =~ "Disable" ]]; then
        $TERM_CMD bash -c "echo 'Disabling AppArmor...';
        sudo systemctl stop apparmor;
        sudo systemctl disable apparmor;
        echo 'Done! AppArmor disabled.';
        echo 'Reboot may be needed for full effect.';
        read -p 'Press Enter to close...'"
        tnotify "Security" "AppArmor disabled"
    fi
}

security_logs_menu() {
    local LOG_OPTS=""
    # Build list of available log sources
    systemctl is-active --quiet fail2ban 2>/dev/null && LOG_OPTS+="🛡️ Fail2Ban Logs\n"
    systemctl is-active --quiet ufw 2>/dev/null && LOG_OPTS+="🔥 Firewall (UFW) Logs\n"
    systemctl is-active --quiet ssh 2>/dev/null && LOG_OPTS+="🔑 SSH Auth Logs\n"
    LOG_OPTS+="📋 All Auth Logs\n"
    systemctl is-active --quiet apparmor 2>/dev/null && LOG_OPTS+="󰒃 AppArmor Denials\n"
    LOG_OPTS+="󰌍 Back"

    local LOG_CHOICE
    LOG_CHOICE=$(echo -e "$LOG_OPTS" | tfuzzel -d -p " 󰍉 Security Logs | ")
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
    ST_OPTS="󰍉 Recon & Scanning
󰖟 Web Application Testing
󰚑 Exploitation Frameworks
󰀂 Wireless Attacks
󰌆 Password Cracking
󰈈 Forensics & Recovery
󰛃 Sniffing & Spoofing
󰣖 Install Kali Container
󰣖 Install Parrot Container
󰌍 Back"

    ST_CHOICE=$(echo -e "$ST_OPTS" | tfuzzel -d -p " 󰒃 Security Tools | ")

    if is_back "$ST_CHOICE"; then return; fi

    if [[ "$ST_CHOICE" =~ "Recon" ]]; then
        sec_tool_install_menu "Recon & Scanning" \
            "nmap|Nmap - Network Scanner|apt" \
            "masscan|Masscan - Fast Port Scanner|apt" \
            "whois|Whois - Domain Lookup|apt" \
            "bind9-dnsutils|DNS Utils (dig, nslookup)|apt" \
            "netdiscover|Netdiscover - ARP Scanner|apt" \
            "recon-ng|Recon-ng - OSINT Framework|apt"
    elif [[ "$ST_CHOICE" =~ "Web" ]]; then
        sec_tool_install_menu "Web Application Testing" \
            "nikto|Nikto - Web Scanner|apt" \
            "sqlmap|SQLMap - SQL Injection|apt" \
            "gobuster|Gobuster - Dir/DNS Brute|apt" \
            "dirb|Dirb - Web Content Scanner|apt" \
            "burpsuite|Burp Suite (Kali Container)|distrobox" \
            "zaproxy|ZAP Proxy - Web App Scanner (Kali Container)|distrobox"
    elif [[ "$ST_CHOICE" =~ "Exploitation" ]]; then
        sec_tool_install_menu "Exploitation Frameworks" \
            "metasploit-framework|Metasploit (Kali Container)|distrobox" \
            "exploitdb|ExploitDB - Exploit Archive (Kali Container)|distrobox" \
            "set|Social Engineering Toolkit (Kali Container)|distrobox"
    elif [[ "$ST_CHOICE" =~ "Wireless" ]]; then
        sec_tool_install_menu "Wireless Attacks" \
            "aircrack-ng|Aircrack-ng - WiFi Cracking|apt" \
            "wifite|Wifite - Automated WiFi Attacks|apt" \
            "kismet|Kismet - Wireless Sniffer (Kali Container)|distrobox"
    elif [[ "$ST_CHOICE" =~ "Password" ]]; then
        sec_tool_install_menu "Password Cracking" \
            "john|John the Ripper|apt" \
            "hashcat|Hashcat - GPU Cracker|apt" \
            "hydra|Hydra - Login Brute Forcer|apt" \
            "medusa|Medusa - Parallel Brute Forcer|apt"
    elif [[ "$ST_CHOICE" =~ "Forensics" ]]; then
        sec_tool_install_menu "Forensics & Recovery" \
            "autopsy|Autopsy - Digital Forensics|apt" \
            "binwalk|Binwalk - Firmware Analysis|apt" \
            "foremost|Foremost - File Carver|apt" \
            "sleuthkit|Sleuth Kit - Disk Analysis|apt"
    elif [[ "$ST_CHOICE" =~ "Sniffing" ]]; then
        sec_tool_install_menu "Sniffing & Spoofing" \
            "wireshark|Wireshark - Packet Analyzer|apt" \
            "tcpdump|Tcpdump - CLI Packet Capture|apt" \
            "ngrep|Ngrep - Network Grep|apt" \
            "ettercap-text-only|Ettercap - MITM Framework|apt"
    elif [[ "$ST_CHOICE" =~ "Kali Container" ]]; then
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
    elif [[ "$ST_CHOICE" =~ "Parrot Container" ]]; then
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
        if [[ "$METHOD" == "distrobox" ]]; then
            if distrobox list 2>/dev/null | grep -q "kali"; then
                MENU_ITEMS+="${PREFIX}󰄬 $DISPLAY"
            else
                MENU_ITEMS+="${PREFIX}󰄰 $DISPLAY"
            fi
        else
            if dpkg -l "$PKG" 2>/dev/null | grep -q "^ii"; then
                MENU_ITEMS+="${PREFIX}󰄬 $DISPLAY"
            else
                MENU_ITEMS+="${PREFIX}󰄰 $DISPLAY"
            fi
        fi
    done
    MENU_ITEMS+="\n󰌍 Back"

    local CHOICE
    CHOICE=$(echo -e "$MENU_ITEMS" | tfuzzel -d -p " 󰒃 $CATEGORY | ")

    if is_back "$CHOICE"; then return; fi

    # Find which tool was selected
    for TOOL_SPEC in "${TOOLS[@]}"; do
        local PKG="${TOOL_SPEC%%|*}"
        local REST="${TOOL_SPEC#*|}"
        local DISPLAY="${REST%%|*}"
        local METHOD="${REST##*|}"

        if [[ "$CHOICE" =~ "$DISPLAY" ]]; then
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

secure_workspace_menu() {
    while true; do
    # Detect state
    if command -v virsh &>/dev/null && virsh dominfo tebian-workstation &>/dev/null 2>&1; then
        WS_STATE=$(virsh domstate tebian-workstation 2>/dev/null || echo "unknown")
        GW_STATE=$(virsh domstate tebian-gateway 2>/dev/null || echo "unknown")

        SW_OPTS="󰋽 Gateway: $GW_STATE
󰋽 Workstation: $WS_STATE"
        if [[ "$WS_STATE" == "running" ]]; then
            SW_OPTS+="\n🛑 Stop Workspace
󰍹 Open Workstation (virt-viewer)"
        else
            SW_OPTS+="\n▶️ Start Workspace"
        fi
        SW_OPTS+="\n󰩈 Destroy Workspace (delete everything)"
        SW_OPTS+="\n󰌍 Back"
    else
        SW_OPTS="☠️ Setup Secure Workspace
Architecture:
  Workstation ──▶ Gateway ──▶ Tor ──▶ Internet
  (your work)    (Tor proxy)
  Can't leak IP. Even if compromised.
󰌍 Back"
    fi

    SW_CHOICE=$(echo -e "$SW_OPTS" | tfuzzel -d -p " ☠️ Secure Workspace | ")

    if is_back "$SW_CHOICE"; then return; fi

    if [[ "$SW_CHOICE" =~ "Setup Secure Workspace" ]]; then
        $TERM_CMD bash -c "
            tebian-isolated-workspace setup
            read -p 'Press Enter to close...'
        "
    elif [[ "$SW_CHOICE" =~ "Start Workspace" ]]; then
        $TERM_CMD bash -c "
            tebian-isolated-workspace start
            read -p 'Press Enter to close...'
        "
    elif [[ "$SW_CHOICE" =~ "Stop Workspace" ]]; then
        $TERM_CMD bash -c "
            tebian-isolated-workspace stop
            read -p 'Press Enter to close...'
        "
    elif [[ "$SW_CHOICE" =~ "Open Workstation" ]]; then
        virt-viewer tebian-workstation &>/dev/null &
    elif [[ "$SW_CHOICE" =~ "Destroy Workspace" ]]; then
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
