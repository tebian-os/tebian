# tebian-settings module: security.sh
# Sourced by tebian-settings — do not run directly

security_menu() {
    while true; do
    # Detect state — use systemctl (no sudo needed) where possible
    UFW_ACTIVE=$(systemctl is-active --quiet ufw && echo "ON" || echo "OFF")
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

    # Detect AppArmor state — three states: Enforcing / Complain / Off
    if systemctl is-active --quiet apparmor 2>/dev/null && [ -d /sys/kernel/security/apparmor ]; then
        if grep -q ' enforce' /sys/kernel/security/apparmor/profiles 2>/dev/null; then
            AA_LABEL="󰒃 AppArmor (Enforcing)"
        else
            AA_LABEL="󰒃 AppArmor (Complain)"
        fi
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

    SEC_OPTS="$PARANOID_LABEL
$SEC_LABEL
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

    if [[ "$S_CHOICE" == *"󰌍 Back"* || -z "$S_CHOICE" ]]; then return; fi

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
            tnotify "Security" "SSH set to key-only"
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
        if [[ "$FJ_ACT" == *"󰌍 Back"* || -z "$FJ_ACT" ]]; then continue; fi
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
        tnotify "Security" "Firejail sandboxing enabled"
    elif [[ "$S_CHOICE" =~ "Tor" ]] && [[ "$S_CHOICE" =~ "ON" ]]; then
        TOR_ACT=$(echo -e "󰗹 Disable Tor Service\n󰆴 Disable & Uninstall Tor\n󰌍 Back" | tfuzzel -d -p " 󰗹 Tor | ")
        if [[ "$TOR_ACT" == *"󰌍 Back"* || -z "$TOR_ACT" ]]; then continue; fi
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
        $TERM_CMD bash -c "echo 'Disabling DNS-over-TLS...';
        sudo rm -f /etc/systemd/resolved.conf.d/99-tebian-dns.conf;
        sudo rm -f /etc/NetworkManager/conf.d/99-tebian-dns-resolved.conf;
        sudo systemctl restart systemd-resolved 2>/dev/null;
        # Restore NetworkManager DNS control
        sudo rm -f /etc/resolv.conf 2>/dev/null;
        sudo systemctl restart NetworkManager 2>/dev/null;
        echo 'Done! Using default DNS.';
        read -p 'Press Enter to close...'"
        tnotify "Security" "DNS Privacy disabled"
    elif [[ "$S_CHOICE" =~ "DNS Privacy" ]]; then
        DNS_PROVIDER=$(echo -e "🛡️ Quad9 (privacy + malware blocking)\n⚡ Cloudflare (fast + privacy)\n󰌍 Back" | tfuzzel -d -p " 󰇖 DNS Provider | ")
        if [[ "$DNS_PROVIDER" == *"󰌍 Back"* || -z "$DNS_PROVIDER" ]]; then continue; fi
        $TERM_CMD bash -c "echo 'Enabling DNS-over-TLS...';
        sudo mkdir -p /etc/systemd/resolved.conf.d;
        if [[ '$DNS_PROVIDER' =~ 'Cloudflare' ]]; then
            printf '[Resolve]\nDNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com\nDNSOverTLS=yes\nDNSSEC=allow-downgrade\nDomains=~.\n' | sudo tee /etc/systemd/resolved.conf.d/99-tebian-dns.conf;
        else
            printf '[Resolve]\nDNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net\nDNSOverTLS=yes\nDNSSEC=allow-downgrade\nDomains=~.\n' | sudo tee /etc/systemd/resolved.conf.d/99-tebian-dns.conf;
        fi;
        # Tell NetworkManager to use systemd-resolved
        sudo mkdir -p /etc/NetworkManager/conf.d;
        printf '[main]\ndns=systemd-resolved\n' | sudo tee /etc/NetworkManager/conf.d/99-tebian-dns-resolved.conf;
        sudo systemctl enable --now systemd-resolved 2>/dev/null;
        sudo systemctl restart systemd-resolved;
        if [ ! -L /etc/resolv.conf ] || ! readlink /etc/resolv.conf | grep -q stub-resolv; then
            sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf;
        fi;
        sudo systemctl restart NetworkManager 2>/dev/null;
        echo '';
        echo 'Done! DNS-over-TLS enabled.';
        read -p 'Press Enter to close...'"
        tnotify "Security" "DNS Privacy enabled"
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
    done
}

apparmor_menu() {
    local AA_OPTS=""
    if systemctl is-active --quiet apparmor 2>/dev/null && [ -d /sys/kernel/security/apparmor ]; then
        if grep -q ' enforce' /sys/kernel/security/apparmor/profiles 2>/dev/null; then
            AA_OPTS="󰒃 Switch to Complain Mode\n󰒃 Disable AppArmor\n󰌍 Back"
        else
            AA_OPTS="󰒃 Switch to Enforce Mode\n󰒃 Disable AppArmor\n󰌍 Back"
        fi
    else
        AA_OPTS="󰒃 Enable AppArmor (Enforce)\n󰒃 Enable AppArmor (Complain)\n󰌍 Back"
    fi

    local AA_CHOICE
    AA_CHOICE=$(echo -e "$AA_OPTS" | tfuzzel -d -p " 󰒃 AppArmor | ")
    if [[ "$AA_CHOICE" == *"󰌍 Back"* || -z "$AA_CHOICE" ]]; then return; fi

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
    if [[ "$LOG_CHOICE" == *"󰌍 Back"* || -z "$LOG_CHOICE" ]]; then return; fi

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

    if [[ "$ST_CHOICE" == *"󰌍 Back"* || -z "$ST_CHOICE" ]]; then return; fi

    if [[ "$ST_CHOICE" =~ "Recon" ]]; then
        sec_tool_install_menu "Recon & Scanning" \
            "nmap|Nmap - Network Scanner|apt" \
            "masscan|Masscan - Fast Port Scanner|apt" \
            "whois|Whois - Domain Lookup|apt" \
            "dnsutils|DNS Utils (dig, nslookup)|apt" \
            "netdiscover|Netdiscover - ARP Scanner|apt" \
            "recon-ng|Recon-ng - OSINT Framework|apt"
    elif [[ "$ST_CHOICE" =~ "Web" ]]; then
        sec_tool_install_menu "Web Application Testing" \
            "nikto|Nikto - Web Scanner|apt" \
            "sqlmap|SQLMap - SQL Injection|apt" \
            "gobuster|Gobuster - Dir/DNS Brute|apt" \
            "dirb|Dirb - Web Content Scanner|apt" \
            "burpsuite|Burp Suite (Kali Container)|distrobox" \
            "zaproxy|ZAP Proxy - Web App Scanner|apt"
    elif [[ "$ST_CHOICE" =~ "Exploitation" ]]; then
        sec_tool_install_menu "Exploitation Frameworks" \
            "metasploit-framework|Metasploit (Kali Container)|distrobox" \
            "exploitdb|ExploitDB - Exploit Archive|apt" \
            "set|Social Engineering Toolkit (Kali Container)|distrobox"
    elif [[ "$ST_CHOICE" =~ "Wireless" ]]; then
        sec_tool_install_menu "Wireless Attacks" \
            "aircrack-ng|Aircrack-ng - WiFi Cracking|apt" \
            "wifite|Wifite - Automated WiFi Attacks|apt" \
            "kismet|Kismet - Wireless Sniffer|apt"
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

    if [[ "$CHOICE" == *"󰌍 Back"* || -z "$CHOICE" ]]; then return; fi

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

    if [[ -z "$SW_CHOICE" || "$SW_CHOICE" == *"󰌍 Back"* ]]; then return; fi

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
