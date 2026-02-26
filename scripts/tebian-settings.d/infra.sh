# tebian-settings module: infra.sh
# Sourced by tebian-settings — do not run directly

infra_menu() {
    while true; do
    INF_OPTS="󰡨 Containers\0icon\x1fapplications-utilities
󰾵 Virtualization\0icon\x1fcomputer
󰌘 T-Link\0icon\x1fnetwork-vpn
─────────────────────────────────
󰌍 Back"

    INF_CHOICE=$(echo -e "$INF_OPTS" | tfuzzel -d -p " 󰡨 Infrastructure | ")

    if [[ "$INF_CHOICE" =~ "Back" || -z "$INF_CHOICE" ]]; then return; fi

    if [[ "$INF_CHOICE" =~ "Containers" ]]; then
        containers_menu
    elif [[ "$INF_CHOICE" =~ "Virtualization" ]]; then
        vm_menu
    elif [[ "$INF_CHOICE" =~ "T-Link" ]]; then
        tlink_menu
    fi
    done
}

containers_menu() {
    while true; do
    # Check what's installed
    HAS_PODMAN=$(command -v podman >/dev/null && echo "YES" || echo "NO")
    HAS_DOCKER=$(command -v docker >/dev/null && echo "YES" || echo "NO")
    HAS_DISTROBOX=$(command -v distrobox >/dev/null && echo "YES" || echo "NO")
    HAS_ALPINE=$(distrobox list 2>/dev/null | grep -q "alpine" && echo "YES" || echo "NO")
    HAS_ARCH=$(distrobox list 2>/dev/null | grep -q "arch" && echo "YES" || echo "NO")

    C_OPTS="⛰️ Alpine Linux (musl, 5MB, containers)
󰣖 Arch Linux (AUR access)
📦 Install Podman
🐳 Install Docker + Compose
📦 Install Distrobox
─────────────────────────────────
󰌍 Back"

    if [[ "$HAS_PODMAN" == "YES" ]]; then
        C_OPTS+="\n✅ Podman installed"
    fi
    if [[ "$HAS_DOCKER" == "YES" ]]; then
        C_OPTS+="\n✅ Docker installed"
    fi

    C_CHOICE=$(echo -e "$C_OPTS" | tfuzzel -d -p " 󰏗 Containers | ")

    if [[ "$C_CHOICE" =~ "Back" || -z "$C_CHOICE" ]]; then return; fi

    if [[ "$C_CHOICE" =~ "Alpine Linux" ]]; then
        $TERM_CMD bash -c "echo '📦 Installing Alpine Linux container...';
        if ! command -v distrobox &> /dev/null; then
            echo 'Installing Distrobox & Podman first...';
            sudo apt update && sudo apt install -y distrobox podman;
        fi;
        distrobox create --name alpine --image alpine:latest;
        echo '--------------------------------';
        echo '✅ Alpine container created!';
        echo 'To enter: distrobox enter alpine';
        echo '--------------------------------';
        read -p 'Press Enter to close...'"
    elif [[ "$C_CHOICE" =~ "Arch Linux" ]]; then
        $TERM_CMD bash -c "echo '📦 Installing Arch Linux container (AUR access)...';
        if ! command -v distrobox &> /dev/null; then
            echo 'Installing Distrobox & Podman first...';
            sudo apt update && sudo apt install -y distrobox podman;
        fi;
        distrobox create --name arch --image archlinux:latest;
        echo '--------------------------------';
        echo '✅ Arch container created!';
        echo 'To enter: distrobox enter arch';
        echo 'To use AUR inside:';
        echo '  1. distrobox enter arch';
        echo '  2. git clone https://aur.archlinux.org/yay.git';
        echo '  3. cd yay && makepkg -si';
        echo '--------------------------------';
        read -p 'Press Enter to close...'"
    elif [[ "$C_CHOICE" =~ "Install Podman" ]]; then
        $TERM_CMD bash -c "echo 'Installing Podman...';
        sudo apt update && sudo apt install -y podman;
        echo '✅ Podman installed.';
        read -p 'Press Enter to close...'"
    elif [[ "$C_CHOICE" =~ "Install Docker" ]]; then
        $TERM_CMD bash -c "echo 'Installing Docker & Docker Compose...';
        sudo apt update && sudo apt install -y docker.io docker-compose-v2;
        sudo systemctl enable --now docker;
        sudo adduser \$USER docker;
        echo '--------------------------------';
        echo '✅ Docker installed!';
        echo '⚠️  Log out and back in for group changes.';
        echo '--------------------------------';
        read -p 'Press Enter to close...'"
    elif [[ "$C_CHOICE" =~ "Install Distrobox" ]]; then
        $TERM_CMD bash -c "echo 'Installing Distrobox & Podman...';
        sudo apt update && sudo apt install -y distrobox podman;
        echo '✅ Distrobox installed.';
        read -p 'Press Enter to close...'"
    fi
    done
}

vm_menu() {
    while true; do
    # Detect isolated workspace state
    if command -v virsh &>/dev/null && virsh dominfo tebian-workstation &>/dev/null 2>&1; then
        WS_STATE=$(virsh domstate tebian-workstation 2>/dev/null || echo "unknown")
        if [[ "$WS_STATE" == "running" ]]; then
            ISO_LABEL="☠️ Secure Workspace (Running)"
        else
            ISO_LABEL="☠️ Secure Workspace (Stopped)"
        fi
    else
        ISO_LABEL="☠️ Secure Workspace (Not Setup)"
    fi

    VM_OPTS="$ISO_LABEL
─────────────────────────────────
󰀵 Launch macOS (Xcode/App Store)
󰖳 Launch Windows (Legacy Support)
󰚰 Install KVM Core (Required First)
🍎 Setup macOS VM (Fetch Installer)
🪟 Setup Windows 11 VM (Safe Mode)
─────────────────────────────────
󰌍 Back"

    V_CHOICE=$(echo -e "$VM_OPTS" | tfuzzel -d -p " 󰾵 VMs | ")

    if [[ "$V_CHOICE" =~ "Back" || -z "$V_CHOICE" ]]; then return; fi

    if [[ "$V_CHOICE" =~ "Secure Workspace" ]]; then
        secure_workspace_menu
    elif [[ "$V_CHOICE" =~ "Launch macOS" ]]; then
        if [ -f "$HOME/Applications/OSX-KVM/OpenCore-Boot.sh" ]; then
             cd "$HOME/Applications/OSX-KVM" && ./OpenCore-Boot.sh &
        else
             notify-send "Error" "macOS VM not found. Run 'Setup macOS VM' first."
        fi
    elif [[ "$V_CHOICE" =~ "Launch Windows" ]]; then
         notify-send "Tebian VM" "Launching Windows..."
         # Placeholder: virt-manager --connect qemu:///system --show-domain-console win11 &
    elif [[ "$V_CHOICE" =~ "Install KVM Core" ]]; then
        $TERM_CMD bash -c "echo 'Installing KVM/QEMU Stack...'; 
        sudo apt update && sudo apt install -y qemu-system-x86 qemu-utils python3 python3-pip bridge-utils virt-manager libvirt-daemon-system; 
        sudo adduser \$USER libvirt;
        sudo adduser \$USER kvm;
        echo '------------------------------------------------';
        echo '✅ KVM Installed.';
        echo '⚠️  You MUST reboot your computer now for groups to apply.';
        echo '------------------------------------------------';
        read -p 'Press Enter to close...'"
    elif [[ "$V_CHOICE" =~ "Setup macOS VM" ]]; then
        $TERM_CMD bash -c "echo '🍎 Setting up macOS (OSX-KVM)...';
        mkdir -p ~/Applications && cd ~/Applications;
        git clone --depth 1 https://github.com/kholia/OSX-KVM.git;
        cd OSX-KVM;
        echo 'Downloading macOS Base System (Apple Servers)...';
        ./fetch-macOS-v2.py;
        echo 'Converting Image...';
        qemu-img convert BaseSystem.dmg -O raw BaseSystem.img;
        echo 'Creating Virtual Disk (64GB)...';
        qemu-img create -f qcow2 mac_hdd_ng.img 64G;
        echo '------------------------------------------------';
        echo '✅ Setup Complete!';
        echo 'To install: Select Launch macOS in menu -> Boot BaseSystem -> Disk Utility (Format Disk) -> Reinstall macOS.';
        echo '------------------------------------------------';
        read -p 'Press Enter to close...'"
    elif [[ "$V_CHOICE" =~ "Setup Windows 11" ]]; then
        $TERM_CMD bash -c "echo 'Downloading Windows 11 TPM Bypass Script...';
        # Placeholder for win11-install script
        echo 'This will set up a Win11 VM with TPM bypass for anti-cheat compatibility.';
        read -p 'Feature coming in v2.1. Press Enter...'"
    fi
    done
}

tlink_menu() {
    while true; do
    TL_OPTS="󰌄 Fleet Management (Servers & Deploy)
🌐 Network Setup (Tailscale)
🔒 VPN (WireGuard)
─────────────────────────────────
󰋜 Quick Status
─────────────────────────────────
󰌍 Back"

    TL_CHOICE=$(echo -e "$TL_OPTS" | tfuzzel -d -p " 󰌄 T-Link | ")

    if [[ "$TL_CHOICE" =~ "Back" || -z "$TL_CHOICE" ]]; then return; fi

    if [[ "$TL_CHOICE" =~ "Fleet Management" ]]; then
        tebian-tlink
    elif [[ "$TL_CHOICE" =~ "Network Setup" ]]; then
        tlink_network_menu
    elif [[ "$TL_CHOICE" =~ "VPN" ]]; then
        vpn_menu
    elif [[ "$TL_CHOICE" =~ "Quick Status" ]]; then
        tlink_status
    fi
    done
}

vpn_menu() {
    while true; do
    # Detect WireGuard state
    if command -v wg &>/dev/null; then
        WG_IFACE=$(sudo -n wg show 2>/dev/null | head -1 | awk '{print $2}')
        if [ -n "$WG_IFACE" ]; then
            WG_LABEL="✅ WireGuard Active ($WG_IFACE)"
        else
            WG_LABEL="⚠️ WireGuard Installed (No Tunnel)"
        fi
    else
        WG_LABEL="📦 WireGuard Not Installed"
    fi

    VPN_OPTS="$WG_LABEL
─────────────────────────────────"

    if ! command -v wg &>/dev/null; then
        VPN_OPTS+="\n📦 Install WireGuard"
    else
        if [ -n "$WG_IFACE" ]; then
            VPN_OPTS+="\n🛑 Disconnect ($WG_IFACE)"
        fi
        # List available configs
        WG_CONFIGS=$(ls /etc/wireguard/*.conf 2>/dev/null | xargs -I{} basename {} .conf)
        if [ -n "$WG_CONFIGS" ]; then
            for cfg in $WG_CONFIGS; do
                VPN_OPTS+="\n🚀 Connect: $cfg"
            done
        fi
        VPN_OPTS+="\n📝 Import Config File"
        VPN_OPTS+="\n🔑 Generate Keypair"
    fi

    VPN_OPTS+="\n─────────────────────────────────\n󰌍 Back"

    VP_CHOICE=$(echo -e "$VPN_OPTS" | tfuzzel -d -p " 🔒 VPN | ")

    if [[ "$VP_CHOICE" =~ "Back" || -z "$VP_CHOICE" ]]; then return; fi

    if [[ "$VP_CHOICE" =~ "Install WireGuard" ]]; then
        $TERM_CMD bash -c "echo 'Installing WireGuard...';
        sudo apt update && sudo apt install -y wireguard wireguard-tools;
        echo '';
        echo '✅ WireGuard installed.';
        echo 'Import a .conf file or generate keys to get started.';
        read -p 'Press Enter to close...'"
    elif [[ "$VP_CHOICE" =~ "Disconnect" ]]; then
        $TERM_CMD bash -c "echo 'Disconnecting WireGuard...';
        sudo wg-quick down '$WG_IFACE' 2>/dev/null || sudo wg-quick down wg0;
        echo 'Disconnected.';
        read -p 'Press Enter to close...'"
    elif [[ "$VP_CHOICE" =~ "Connect:" ]]; then
        TUNNEL=$(echo "$VP_CHOICE" | sed 's/.*Connect: //')
        $TERM_CMD bash -c "echo 'Connecting to $TUNNEL...';
        sudo wg-quick up '$TUNNEL';
        echo '';
        sudo wg show;
        echo '';
        read -p 'Press Enter to close...'"
    elif [[ "$VP_CHOICE" =~ "Import Config" ]]; then
        $TERM_CMD bash -c "echo '=== Import WireGuard Config ===';
        echo '';
        echo 'Place your .conf file path below.';
        echo 'It will be copied to /etc/wireguard/';
        echo '';
        read -p 'Config file path: ' CONF_PATH;
        if [ -f \"\$CONF_PATH\" ]; then
            CONF_NAME=\$(basename \"\$CONF_PATH\");
            sudo cp \"\$CONF_PATH\" /etc/wireguard/;
            sudo chmod 600 /etc/wireguard/\"\$CONF_NAME\";
            echo \"✅ Imported \$CONF_NAME\";
        else
            echo '✗ File not found.';
        fi;
        read -p 'Press Enter to close...'"
    elif [[ "$VP_CHOICE" =~ "Generate Keypair" ]]; then
        $TERM_CMD bash -c "echo '=== WireGuard Keypair ===';
        echo '';
        PRIVKEY=\$(wg genkey);
        PUBKEY=\$(echo \"\$PRIVKEY\" | wg pubkey);
        echo \"Private Key: \$PRIVKEY\";
        echo \"Public Key:  \$PUBKEY\";
        echo '';
        echo '⚠️  Save these securely. The private key is NOT stored.';
        echo '';
        read -p 'Press Enter to close...'"
    fi
    done
}

tlink_network_menu() {
    while true; do
    if command -v tailscale >/dev/null; then
        TS_STATUS=$(tailscale status --json 2>/dev/null | grep -q '"BackendState":"Running"' && echo "Active" || echo "Inactive")
        TS_IP=$(tailscale ip -4 2>/dev/null)
        
        if [ "$TS_STATUS" == "Active" ]; then
            TL_LABEL="✅ Tailscale Active ($TS_IP)"
            TL_ACTION="🛑 Disconnect"
        else
            TL_LABEL="⚠️ Tailscale Inactive"
            TL_ACTION="🚀 Connect"
        fi
        
        TL_OPTS="$TL_LABEL
$TL_ACTION
🏰 Connect to Headscale (Self-Hosted)
📋 Show Network Status
─────────────────────────────────
󰌍 Back"
    else
        TL_OPTS="📦 Install Tailscale
─────────────────────────────────
󰌍 Back"
    fi

    TL_CHOICE=$(echo -e "$TL_OPTS" | tfuzzel -d -p " 🌐 Network | ")

    if [[ "$TL_CHOICE" =~ "Back" || -z "$TL_CHOICE" ]]; then return; fi

    if [[ "$TL_CHOICE" =~ "Install Tailscale" ]]; then
        $TERM_CMD bash -c "echo 'Installing Tailscale via apt repository...'
        echo ''
        # Add Tailscale apt repo (signed with their GPG key)
        curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
        curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
        sudo apt update
        sudo apt install -y tailscale
        echo ''
        echo 'Tailscale installed via signed apt repository.'
        read -p 'Press Enter...'"
    elif [[ "$TL_CHOICE" =~ "Connect" ]] && ! [[ "$TL_CHOICE" =~ "Headscale" ]]; then
        $TERM_CMD bash -c "sudo tailscale up; read -p 'Connected! Press Enter...'"
    elif [[ "$TL_CHOICE" =~ "Headscale" ]]; then
        SERVER_URL=$(echo "" | tfuzzel -d -p " 🏰 Headscale URL: ")
        if [ -n "$SERVER_URL" ]; then
            HEADSCALE_URL="$SERVER_URL" $TERM_CMD bash -c 'sudo tailscale up --login-server "$HEADSCALE_URL"; read -p "Connected! Press Enter..."'
        fi
    elif [[ "$TL_CHOICE" =~ "Disconnect" ]]; then
        $TERM_CMD bash -c "sudo tailscale down; read -p 'Disconnected. Press Enter...'"
    elif [[ "$TL_CHOICE" =~ "Network Status" ]]; then
        $TERM_CMD bash -c "tailscale status; read -p 'Press Enter...'"
    fi
    done
}

tlink_status() {
    SERVERS_FILE="$HOME/.config/tebian/servers.conf"
    
    STATUS="󰌄 T-LINK STATUS
─────────────────────────────────
Network:"
    
    if command -v tailscale >/dev/null; then
        TS_STATUS=$(tailscale status --json 2>/dev/null | grep -q '"BackendState":"Running"' && echo "✅ Connected" || echo "⚠️ Inactive")
        TS_IP=$(tailscale ip -4 2>/dev/null)
        STATUS+="
  Tailscale: $TS_STATUS"
        [ -n "$TS_IP" ] && STATUS+="
  IP: $TS_IP"
    else
        STATUS+="
  Tailscale: Not installed"
    fi
    
    STATUS+="
─────────────────────────────────
Servers:"
    
    if [ -f "$SERVERS_FILE" ]; then
        SERVERS=$(grep -v "^#" "$SERVERS_FILE" | grep "=" | head -5)
        for line in $SERVERS; do
            NAME=$(echo "$line" | cut -d= -f1)
            IP=$(echo "$line" | cut -d= -f2)
            if ping -c 1 -W 1 "$IP" &>/dev/null; then
                STATUS+="
  ● $NAME"
            else
                STATUS+="
  ○ $NAME (offline)"
            fi
        done
    else
        STATUS+="
  No servers configured"
    fi
    
    STATUS+="
─────────────────────────────────
󰌍 Back"
    
    CHOICE=$(echo -e "$STATUS" | tfuzzel -d -p "" --width 40 --lines 15)
    
    # Back returns to tlink_menu's while loop
    return
}

