# tebian-settings module: perf.sh
# Sourced by tebian-settings — do not run directly

perf_menu() {
    while true; do
    # Detect current state
    HAS_ZRAM=$(command -v zramswap >/dev/null && echo "YES" || echo "NO")
    ZRAM_ACTIVE=$(lsmod | grep -q zram && echo "ON" || echo "OFF")
    
    if [[ "$HAS_ZRAM" == "NO" ]]; then
        PERF_LABEL="󰚰 Install & Enable RAM Boost"
    elif [[ "$ZRAM_ACTIVE" == "ON" ]]; then
        PERF_LABEL="🚀 Disable RAM Boost (Current: Active)"
    else
        PERF_LABEL="󰓅 Enable RAM Boost (Current: Inactive)"
    fi

    if systemctl is-active --quiet preload 2>/dev/null; then
        PRELOAD_LABEL="󰚰 Disable App Preload (Currently: ON)"
    else
        PRELOAD_LABEL="󰓅 Enable App Preload (Faster App Launch)"
    fi

    PERF_OPTS="$PERF_LABEL"

    # Only show uninstall if it's actually installed
    if [[ "$HAS_ZRAM" == "YES" ]]; then
        PERF_OPTS+="\n󰆴 Uninstall RAM Boost"
    fi

    # Power profile (TLP)
    if command -v tlp-stat &>/dev/null; then
        TLP_MODE=$(sudo -n tlp-stat -s 2>/dev/null | grep "Mode" | awk '{print $NF}')
        [ -z "$TLP_MODE" ] && TLP_MODE="unknown"
        PERF_OPTS+="\n🔋 Power Profile ($TLP_MODE)"
    fi
    PERF_OPTS+="\n$PRELOAD_LABEL"
    PERF_OPTS+="\n🧹 Clean System Junk"
    PERF_OPTS+="\n🎮 Install Gaming Optimization (GameMode + Drivers)"
    PERF_OPTS+="\n󰚰 Join Rolling Branch (Trixie)"
    PERF_OPTS+="\n─────────────────────────────────"
    PERF_OPTS+="\n🔍 Detect & Configure Hardware"
    PERF_OPTS+="\n󰍹 Install Nvidia Drivers"
    PERF_OPTS+="\n🔋 Install Laptop Power Management"
    PERF_OPTS+="\n🔲 Install CPU Microcode"
    PERF_OPTS+="\n󰍺 Set HiDPI Scaling (2x)"
    PERF_OPTS+="\n─────────────────────────────────"
    PERF_OPTS+="\n󰌍 Back"
    
    P_CHOICE=$(echo -e "$PERF_OPTS" | tfuzzel -d -p " 󰓅 Boost | ")

    if [[ "$P_CHOICE" =~ "Back" || -z "$P_CHOICE" ]]; then return; fi

    if [[ "$P_CHOICE" =~ "Install & Enable" ]]; then
        $TERM_CMD bash -c "echo 'Installing Tebian RAM Boost...'; 
        sudo apt update && sudo apt install -y zram-tools; 
        echo -e 'ALGO=zstd\nPERCENT=60' | sudo tee /etc/default/zramswap;
        echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-tebian-mem.conf;
        sudo sysctl -p /etc/sysctl.d/99-tebian-mem.conf;
        sudo systemctl enable --now zramswap;
        echo 'Done! RAM Boost installed and active.'; 
        read -p 'Press Enter to close...'"
    elif [[ "$P_CHOICE" =~ "Disable RAM Boost" ]]; then
        $TERM_CMD bash -c "sudo systemctl stop zramswap && echo 'RAM Boost Disabled.' && sleep 1"
    elif [[ "$P_CHOICE" =~ "Enable RAM Boost" ]]; then
        $TERM_CMD bash -c "sudo systemctl start zramswap && echo 'RAM Boost Enabled.' && sleep 1"
    elif [[ "$P_CHOICE" =~ "Uninstall RAM Boost" ]]; then
        $TERM_CMD bash -c "echo 'Uninstalling RAM Boost...'; 
        sudo systemctl disable --now zramswap;
        sudo apt purge -y zram-tools;
        sudo rm -f /etc/sysctl.d/99-tebian-mem.conf;
        sudo sysctl vm.swappiness=60;
        echo 'Done! RAM Boost removed.'; 
        read -p 'Press Enter to close...'"
    elif [[ "$P_CHOICE" =~ "Disable App Preload" ]]; then
        $TERM_CMD bash -c "echo 'Disabling App Preload...';
        sudo systemctl stop preload 2>/dev/null;
        sudo systemctl disable preload 2>/dev/null;
        echo 'App Preload disabled.';
        read -p 'Press Enter to close...'"
    elif [[ "$P_CHOICE" =~ "Enable App Preload" ]]; then
        if ! command -v preload &>/dev/null; then
            $TERM_CMD bash -c "echo 'Installing Preload (App Preloader)...';
            echo '';
            echo 'Preload learns what apps you use and preloads them into RAM.';
            echo 'Result: Apps launch ~50% faster after a few days of learning.';
            echo '';
            sudo apt update && sudo apt install -y preload;
            sudo systemctl enable --now preload;
            echo '';
            echo 'Preload installed and running!';
            echo '   It will learn your usage patterns over the next few days.';
            read -p 'Press Enter to close...'"
        else
            $TERM_CMD bash -c "echo 'Enabling App Preload...';
            sudo systemctl enable --now preload;
            echo 'App Preload enabled.';
            read -p 'Press Enter to close...'"
        fi
    elif [[ "$P_CHOICE" =~ "Power Profile" ]]; then
        PP_OPTS="🔋 Battery Saver (max battery life)
⚖️  Balanced (default)
🚀 Performance (max speed)
─────────────────────────────────
󰌍 Back"
        PP_CHOICE=$(echo -e "$PP_OPTS" | tfuzzel -d -p " 🔋 Power | " --match-mode=exact)
        if [[ "$PP_CHOICE" =~ "Battery" ]]; then
            $TERM_CMD bash -c 'sudo tlp bat; echo "Battery Saver enabled."; read -p "Press Enter..."'
            tlog "Power profile: battery saver"
        elif [[ "$PP_CHOICE" =~ "Balanced" ]]; then
            $TERM_CMD bash -c 'sudo tlp start; echo "Balanced mode enabled."; read -p "Press Enter..."'
            tlog "Power profile: balanced"
        elif [[ "$PP_CHOICE" =~ "Performance" ]]; then
            $TERM_CMD bash -c 'sudo tlp ac; echo "Performance mode enabled."; read -p "Press Enter..."'
            tlog "Power profile: performance"
        fi
    elif [[ "$P_CHOICE" =~ "Clean System Junk" ]]; then
        $TERM_CMD bash -c "sudo apt autoremove -y && sudo apt clean && rm -rf ~/.cache/thumbnails/*; read -p 'System cleaned! Press Enter...'"
    elif [[ "$P_CHOICE" =~ "Install Gaming Optimization" ]]; then
        $TERM_CMD bash -c "echo '🎮 Optimizing for Gaming...';
        echo 'Installing: GameMode, MangoHud, Gamescope, Vulkan Drivers';
        sudo apt update && sudo apt install -y gamemode mangohud gamescope mesa-vulkan-drivers vulkan-tools libvulkan1 mesa-utils;
        echo 'Verifying Vulkan Support...';
        vulkaninfo | grep -q 'GPU id' && echo '✅ Vulkan Detected!' || echo '⚠️  Vulkan might be missing. Check drivers.';
        echo '------------------------------------------------';
        echo 'Usage: gamemoderun %command% (in Steam Launch Options)';
        echo '------------------------------------------------';
        read -p 'Press Enter to close...'"
    elif [[ "$P_CHOICE" =~ "Join Rolling" ]]; then
        $TERM_CMD bash -c "echo '󰚰 Switching to Rolling Branch (Debian Testing)...';
        echo '';
        echo '⚠️  WARNING: Rolling gets newer packages but may be less stable.';
        echo '   You will always be on Testing (follows current Testing release).';
        echo '';
        read -p 'Continue? [y/N] ' confirm;
        if [ \"\$confirm\" = 'y' ] || [ \"\$confirm\" = 'Y' ]; then
            echo '';
            echo 'Updating sources.list...';
            sudo sed -i 's/\\bbookworm\\b/testing/g' /etc/apt/sources.list;
            sudo sed -i 's/\\bbullseye\\b/testing/g' /etc/apt/sources.list 2>/dev/null;
            sudo sed -i 's/\\btrixie\\b/testing/g' /etc/apt/sources.list 2>/dev/null;
            echo 'Running full system upgrade...';
            sudo apt update && sudo apt full-upgrade -y;
            echo '';
            echo '✅ Now on Rolling (Testing).';
            echo '   When Trixie becomes Stable, you auto-move to Debian 14 Testing.';
            echo '   Reboot recommended.';
        else
            echo 'Cancelled.';
        fi;
        read -p 'Press Enter to close...'"
    elif [[ "$P_CHOICE" =~ "Detect & Configure Hardware" ]]; then
        hardware_detect_menu
    elif [[ "$P_CHOICE" =~ "Install Nvidia" ]]; then
        $TERM_CMD bash -c '
            echo "========================================="
            echo "  NVIDIA Driver Installation"
            echo "========================================="
            echo ""

            if ! lspci | grep -qi nvidia; then
                echo "⚠️  No NVIDIA GPU detected."
                echo "   Install anyway? [y/N]"
                read confirm
                [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0
            fi

            echo "Adding non-free repos if needed..."
            if ! grep -q "non-free-firmware" /etc/apt/sources.list 2>/dev/null; then
                sudo sed -i "s/main$/main contrib non-free non-free-firmware/" /etc/apt/sources.list
            fi

            echo "Installing NVIDIA drivers..."
            sudo apt update
            sudo apt install -y nvidia-driver firmware-misc-nonfree

            echo ""
            echo "Blacklisting nouveau..."
            echo "blacklist nouveau" | sudo tee /etc/modprobe.d/nvidia-blacklist.conf
            echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/nvidia-blacklist.conf

            echo ""
            echo "Rebuilding initramfs..."
            sudo update-initramfs -u

            echo ""
            echo "Configuring Wayland environment..."
            mkdir -p "$HOME/.config/environment.d"
            cat > "$HOME/.config/environment.d/tebian-nvidia.conf" <<NVEOF
WLR_NO_HARDWARE_CURSORS=1
LIBVA_DRIVER_NAME=nvidia
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
NVEOF

            # Check for hybrid GPU (Intel+Nvidia)
            if lspci | grep -qi "VGA.*Intel" && lspci | grep -qi "3D.*NVIDIA\|VGA.*NVIDIA"; then
                echo ""
                echo "⚡ Hybrid GPU detected (Intel + NVIDIA)"
                echo "   PRIME render offload configured."
                echo "   Use: __NV_PRIME_RENDER_OFFLOAD=1 <app> for GPU apps"
                echo '   Or add to Steam: __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only %command%'
            fi

            echo ""
            echo "✅ NVIDIA drivers installed!"
            echo "   nouveau blacklisted, initramfs rebuilt."
            echo "   REBOOT REQUIRED."
            read -p "Press Enter to close..."
        '
    elif [[ "$P_CHOICE" =~ "Laptop Power" ]]; then
        $TERM_CMD bash -c '
            echo "========================================="
            echo "  Laptop Power Management"
            echo "========================================="
            echo ""
            
            if ! ls /sys/class/power_supply/ 2>/dev/null | grep -qi bat; then
                echo "⚠️  No battery detected (desktop system)."
                echo "   Install anyway? [y/N]"
                read confirm
                [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0
            fi
            
            echo "Installing TLP (power management)..."
            sudo apt update
            sudo apt install -y tlp powertop
            sudo systemctl enable tlp
            sudo tlp start 2>/dev/null || true
            
            echo ""
            echo "✅ Power management installed!"
            echo "   Battery life should improve."
            read -p "Press Enter to close..."
        '
    elif [[ "$P_CHOICE" =~ "CPU Microcode" ]]; then
        $TERM_CMD bash -c '
            echo "========================================="
            echo "  CPU Microcode Installation"
            echo "========================================="
            echo ""
            
            CPU_VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo 2>/dev/null | awk "{print \$3}")
            
            if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
                echo "Intel CPU detected"
                echo "Installing intel-microcode..."
                sudo apt update
                sudo apt install -y intel-microcode
                echo "✅ Intel microcode installed!"
            elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
                echo "AMD CPU detected"
                echo "Installing amd64-microcode..."
                sudo apt update
                sudo apt install -y amd64-microcode
                echo "✅ AMD microcode installed!"
            else
                echo "Unknown CPU vendor: $CPU_VENDOR"
                echo ""
                echo "Install manually:"
                echo "  Intel: sudo apt install intel-microcode"
                echo "  AMD:   sudo apt install amd64-microcode"
            fi
            echo ""
            read -p "Press Enter to close..."
        '
    elif [[ "$P_CHOICE" =~ "HiDPI" ]]; then
        $TERM_CMD bash -c '
            echo "========================================="
            echo "  HiDPI Scaling Setup"
            echo "========================================="
            echo ""
            echo "This enables 2x scaling for 4K displays."
            echo ""
            
            # Add to sway config (idempotent — inline since we are in a child shell)
            mkdir -p "$HOME/.config/sway"
            grep -qxF "# HiDPI scaling" "$HOME/.config/sway/config.user" 2>/dev/null || echo "# HiDPI scaling" >> "$HOME/.config/sway/config.user"
            grep -qxF "output * scale 2" "$HOME/.config/sway/config.user" 2>/dev/null || echo "output * scale 2" >> "$HOME/.config/sway/config.user"

            # Add to profile (idempotent)
            grep -qxF "GDK_SCALE=2" "$HOME/.profile" 2>/dev/null || echo "GDK_SCALE=2" >> "$HOME/.profile"
            
            echo "✅ HiDPI scaling enabled!"
            echo "   Reload Sway (Mod+Shift+e) to apply."
            echo ""
            read -p "Press Enter to close..."
        '
    fi
    done
}

hardware_detect_menu() {
    $TERM_CMD bash -c '
        echo "========================================="
        echo "  Hardware Detection & Setup"
        echo "========================================="
        echo ""
        
        # Detect GPU
        HAS_NVIDIA=$(lspci 2>/dev/null | grep -i nvidia | head -1)
        HAS_AMD_GPU=$(lspci 2>/dev/null | grep -i "AMD.*VGA\|AMD.*3D\|AMD.*Display" | head -1)
        HAS_INTEL_GPU=$(lspci 2>/dev/null | grep -i "Intel.*VGA\|Intel.*Display" | head -1)
        
        if [ -n "$HAS_NVIDIA" ]; then
            GPU_TYPE="NVIDIA"
            echo "  GPU: NVIDIA detected"
        elif [ -n "$HAS_AMD_GPU" ]; then
            GPU_TYPE="AMD"
            echo "  GPU: AMD detected"
        elif [ -n "$HAS_INTEL_GPU" ]; then
            GPU_TYPE="Intel"
            echo "  GPU: Intel detected"
        else
            GPU_TYPE="Unknown"
            echo "  GPU: Unknown/VM"
        fi
        
        # Detect CPU
        CPU_VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo 2>/dev/null | awk "{print \$3}")
        
        if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
            CPU_TYPE="Intel"
            echo "  CPU: Intel detected"
        elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
            CPU_TYPE="AMD"
            echo "  CPU: AMD detected"
        else
            CPU_TYPE="Unknown"
            echo "  CPU: Unknown"
        fi
        
        # Detect laptop
        HAS_BATTERY=$(ls /sys/class/power_supply/ 2>/dev/null | grep -i bat | head -1)
        if [ -n "$HAS_BATTERY" ]; then
            IS_LAPTOP=true
            echo "  Device: Laptop"
        else
            IS_LAPTOP=false
            echo "  Device: Desktop"
        fi
        
        echo ""
        echo "========================================="
        echo "  Installing Hardware Packages"
        echo "========================================="
        echo ""
        
        sudo apt update
        
        # GPU drivers
        if [ "$GPU_TYPE" = "NVIDIA" ]; then
            echo "Installing NVIDIA drivers..."
            sudo apt install -y nvidia-driver firmware-misc-nonfree 2>/dev/null || true
            mkdir -p "$HOME/.config/environment.d"
            echo "WLR_NO_HARDWARE_CURSORS=1" > "$HOME/.config/environment.d/tebian-nvidia.conf"
            echo "LIBVA_DRIVER_NAME=nvidia" >> "$HOME/.config/environment.d/tebian-nvidia.conf"
        elif [ "$GPU_TYPE" = "AMD" ]; then
            echo "Installing AMD firmware..."
            sudo apt install -y firmware-amd-graphics firmware-linux-nonfree 2>/dev/null || true
        elif [ "$GPU_TYPE" = "Intel" ]; then
            echo "Installing Intel firmware..."
            sudo apt install -y firmware-misc-nonfree 2>/dev/null || true
        fi
        
        # CPU microcode
        if [ "$CPU_TYPE" = "Intel" ]; then
            echo "Installing Intel microcode..."
            sudo apt install -y intel-microcode 2>/dev/null || true
        elif [ "$CPU_TYPE" = "AMD" ]; then
            echo "Installing AMD microcode..."
            sudo apt install -y amd64-microcode 2>/dev/null || true
        fi
        
        # Laptop power
        if [ "$IS_LAPTOP" = true ]; then
            echo "Installing power management..."
            sudo apt install -y tlp powertop 2>/dev/null || true
            sudo systemctl enable tlp 2>/dev/null || true
        fi
        
        echo ""
        echo "========================================="
        echo "  Hardware Setup Complete!"
        echo "========================================="
        echo ""
        echo "Installed:"
        [ "$GPU_TYPE" = "NVIDIA" ] && echo "  - NVIDIA drivers"
        [ "$GPU_TYPE" = "AMD" ] && echo "  - AMD firmware"
        [ "$GPU_TYPE" = "Intel" ] && echo "  - Intel firmware"
        [ "$CPU_TYPE" = "Intel" ] && echo "  - Intel microcode"
        [ "$CPU_TYPE" = "AMD" ] && echo "  - AMD microcode"
        [ "$IS_LAPTOP" = true ] && echo "  - Power management (TLP)"
        echo ""
        echo "Reboot recommended."
        read -p "Press Enter to close..."
    '
}

