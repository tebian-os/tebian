# tebian-settings module: perf.sh
# Sourced by tebian-settings — do not run directly

perf_menu() {
    while true; do
    # === State detection ===

    # RAM Boost (zram)
    HAS_ZRAM=$(dpkg -l zram-tools 2>/dev/null | grep -q '^ii' && echo "YES" || echo "NO")
    ZRAM_ACTIVE=$(systemctl is-active --quiet zramswap 2>/dev/null && echo "ON" || echo "OFF")

    if [[ "$HAS_ZRAM" == "NO" ]]; then
        ZRAM_LABEL="󰚰 Install RAM Boost (zram)"
    elif [[ "$ZRAM_ACTIVE" == "ON" ]]; then
        ZRAM_LABEL="🚀 RAM Boost (Active)"
    else
        ZRAM_LABEL="󰓅 RAM Boost (Inactive)"
    fi

    # App Preload
    HAS_PRELOAD=$(dpkg -l preload 2>/dev/null | grep -q '^ii' && echo "YES" || echo "NO")
    PRELOAD_ACTIVE=$(systemctl is-active --quiet preload 2>/dev/null && echo "ON" || echo "OFF")

    if [[ "$HAS_PRELOAD" == "NO" ]]; then
        PRELOAD_LABEL="󰚰 Install App Preload (Faster Launch)"
    elif [[ "$PRELOAD_ACTIVE" == "ON" ]]; then
        PRELOAD_LABEL="󰓅 App Preload (Active)"
    else
        PRELOAD_LABEL="󰓅 App Preload (Inactive)"
    fi

    # TLP (Power Management)
    HAS_TLP=$(command -v tlp-stat &>/dev/null && echo "YES" || echo "NO")

    # Gaming
    HAS_GAMING=$(dpkg -l gamemode 2>/dev/null | grep -q '^ii' && echo "YES" || echo "NO")

    # Nvidia
    HAS_NVIDIA_DRV=$(dpkg -l nvidia-driver 2>/dev/null | grep -q '^ii' && echo "YES" || echo "NO")

    # Microcode
    HAS_INTEL_UC=$(dpkg -l intel-microcode 2>/dev/null | grep -q '^ii' && echo "YES" || echo "NO")
    HAS_AMD_UC=$(dpkg -l amd64-microcode 2>/dev/null | grep -q '^ii' && echo "YES" || echo "NO")
    if [[ "$HAS_INTEL_UC" == "YES" || "$HAS_AMD_UC" == "YES" ]]; then
        UC_LABEL="✅ CPU Microcode (Installed)"
    else
        UC_LABEL="🔲 Install CPU Microcode"
    fi

    # HiDPI
    if grep -qxF "output * scale 2" "$HOME/.config/sway/config.user" 2>/dev/null; then
        HIDPI_LABEL="󰍺 HiDPI Scaling (2x Active)"
    else
        HIDPI_LABEL="󰍺 Set HiDPI Scaling (2x)"
    fi

    # Rolling
    if grep -q 'testing' /etc/apt/sources.list 2>/dev/null; then
        ROLLING_LABEL="✅ Rolling Branch (Active)"
    else
        ROLLING_LABEL="󰚰 Join Rolling Branch (Testing)"
    fi

    # === Build menu ===
    PERF_OPTS="$ZRAM_LABEL"
    [[ "$HAS_ZRAM" == "YES" ]] && PERF_OPTS+="\n󰆴 Uninstall RAM Boost"

    PERF_OPTS+="\n$PRELOAD_LABEL"
    [[ "$HAS_PRELOAD" == "YES" ]] && PERF_OPTS+="\n󰆴 Uninstall App Preload"

    if [[ "$HAS_TLP" == "YES" ]]; then
        PERF_OPTS+="\n🔋 Power Profile (TLP)"
        PERF_OPTS+="\n󰆴 Uninstall Laptop Power Management"
    else
        PERF_OPTS+="\n🔋 Install Laptop Power Management"
    fi

    if [[ "$HAS_GAMING" == "YES" ]]; then
        PERF_OPTS+="\n🎮 Gaming Optimization (Installed)"
        PERF_OPTS+="\n󰆴 Uninstall Gaming Optimization"
    else
        PERF_OPTS+="\n🎮 Install Gaming Optimization"
    fi

    if [[ "$HAS_NVIDIA_DRV" == "YES" ]]; then
        PERF_OPTS+="\n󰍹 Nvidia Drivers (Installed)"
        PERF_OPTS+="\n󰆴 Uninstall Nvidia Drivers"
    else
        PERF_OPTS+="\n󰍹 Install Nvidia Drivers"
    fi

    PERF_OPTS+="\n$UC_LABEL"
    PERF_OPTS+="\n$HIDPI_LABEL"
    PERF_OPTS+="\n🧹 Clean System Junk"
    PERF_OPTS+="\n$ROLLING_LABEL"
    PERF_OPTS+="\n🔍 Detect & Configure Hardware"
    PERF_OPTS+="\n󰌍 Back"

    P_CHOICE=$(echo -e "$PERF_OPTS" | tfuzzel -d -p " 󰓅 Boost | ")

    if [[ "$P_CHOICE" == *"󰌍 Back"* || -z "$P_CHOICE" ]]; then return; fi

    # === Handle choices ===

    # --- RAM Boost ---
    if [[ "$P_CHOICE" =~ "Install RAM Boost" ]]; then
        $TERM_CMD bash -c "echo 'Installing Tebian RAM Boost...';
        sudo apt update && sudo apt install -y zram-tools;
        echo -e 'ALGO=zstd\nPERCENT=60' | sudo tee /etc/default/zramswap;
        echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-tebian-mem.conf;
        sudo sysctl -p /etc/sysctl.d/99-tebian-mem.conf;
        sudo systemctl enable --now zramswap;
        echo '';
        echo 'Done! RAM Boost installed and active.';
        read -p 'Press Enter to close...'"
        tnotify "RAM Boost" "Installed and enabled"
    elif [[ "$P_CHOICE" == "🚀 RAM Boost (Active)" ]]; then
        $TERM_CMD bash -c "sudo systemctl stop zramswap && echo 'RAM Boost disabled.' || echo 'Failed to stop.'; read -p 'Press Enter...'"
        tnotify "RAM Boost" "Disabled"
    elif [[ "$P_CHOICE" == "󰓅 RAM Boost (Inactive)" ]]; then
        $TERM_CMD bash -c "sudo systemctl start zramswap && echo 'RAM Boost enabled.' || echo 'Failed to start.'; read -p 'Press Enter...'"
        tnotify "RAM Boost" "Enabled"
    elif [[ "$P_CHOICE" =~ "Uninstall RAM Boost" ]]; then
        $TERM_CMD bash -c "echo 'Uninstalling RAM Boost...';
        sudo systemctl disable --now zramswap 2>/dev/null;
        sudo apt purge -y zram-tools;
        sudo rm -f /etc/sysctl.d/99-tebian-mem.conf;
        sudo sysctl --system >/dev/null 2>&1;
        echo '';
        echo 'RAM Boost removed.';
        read -p 'Press Enter to close...'"
        tnotify "RAM Boost" "Uninstalled"

    # --- App Preload ---
    elif [[ "$P_CHOICE" =~ "Install App Preload" ]]; then
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
        tnotify "App Preload" "Installed and enabled"
    elif [[ "$P_CHOICE" == *"App Preload (Active)"* ]]; then
        $TERM_CMD bash -c "echo 'Disabling App Preload...';
        sudo systemctl stop preload;
        sudo systemctl disable preload;
        echo 'App Preload disabled.';
        read -p 'Press Enter to close...'"
        tnotify "App Preload" "Disabled"
    elif [[ "$P_CHOICE" == *"App Preload (Inactive)"* ]]; then
        $TERM_CMD bash -c "echo 'Enabling App Preload...';
        sudo systemctl enable --now preload;
        echo 'App Preload enabled.';
        read -p 'Press Enter to close...'"
        tnotify "App Preload" "Enabled"
    elif [[ "$P_CHOICE" =~ "Uninstall App Preload" ]]; then
        $TERM_CMD bash -c "echo 'Uninstalling App Preload...';
        sudo systemctl disable --now preload 2>/dev/null;
        sudo apt purge -y preload;
        echo '';
        echo 'App Preload removed.';
        read -p 'Press Enter to close...'"
        tnotify "App Preload" "Uninstalled"

    # --- Power Profile / TLP ---
    elif [[ "$P_CHOICE" =~ "Power Profile" ]]; then
        PP_OPTS="🔋 Battery Saver (max battery life)
⚖️  Balanced (default)
🚀 Performance (max speed)
󰌍 Back"
        PP_CHOICE=$(echo -e "$PP_OPTS" | tfuzzel -d -p " 🔋 Power | " --match-mode=exact)
        if [[ "$PP_CHOICE" == *"󰌍 Back"* || -z "$PP_CHOICE" ]]; then
            continue
        elif [[ "$PP_CHOICE" =~ "Battery" ]]; then
            $TERM_CMD bash -c 'sudo tlp bat; echo "Battery Saver enabled."; read -p "Press Enter..."'
            tnotify "Power Profile" "Battery Saver"
        elif [[ "$PP_CHOICE" =~ "Balanced" ]]; then
            $TERM_CMD bash -c 'sudo tlp start; echo "Balanced mode enabled."; read -p "Press Enter..."'
            tnotify "Power Profile" "Balanced"
        elif [[ "$PP_CHOICE" =~ "Performance" ]]; then
            $TERM_CMD bash -c 'sudo tlp ac; echo "Performance mode enabled."; read -p "Press Enter..."'
            tnotify "Power Profile" "Performance"
        fi
    elif [[ "$P_CHOICE" =~ "Install Laptop Power" ]]; then
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
            sudo systemctl enable --now tlp

            echo ""
            echo "✅ Power management installed!"
            echo "   Battery life should improve."
            read -p "Press Enter to close..."
        '
        tnotify "Laptop Power" "TLP installed"
    elif [[ "$P_CHOICE" =~ "Uninstall Laptop Power" ]]; then
        $TERM_CMD bash -c "echo 'Uninstalling Laptop Power Management...';
        sudo systemctl disable --now tlp 2>/dev/null;
        sudo apt purge -y tlp powertop 2>/dev/null;
        sudo apt autoremove -y 2>/dev/null;
        echo '';
        echo 'Power management removed.';
        echo 'System will use default kernel power settings.';
        read -p 'Press Enter to close...'"
        tnotify "Laptop Power" "TLP uninstalled"

    # --- Gaming Optimization ---
    elif [[ "$P_CHOICE" =~ "Uninstall Gaming" ]]; then
        $TERM_CMD bash -c "echo 'Uninstalling Gaming Optimization...';
        sudo apt purge -y gamemode mangohud 2>/dev/null;
        sudo apt autoremove -y 2>/dev/null;
        echo '';
        echo 'Gaming tools removed.';
        echo 'Vulkan drivers kept (may be needed by desktop).';
        read -p 'Press Enter to close...'"
        tnotify "Gaming" "Optimization uninstalled"
    elif [[ "$P_CHOICE" == *"Gaming Optimization (Installed)"* ]]; then
        $TERM_CMD bash -c "echo '🎮 Gaming Optimization Status';
        echo '';
        echo 'Installed packages:';
        dpkg -l gamemode mangohud mesa-vulkan-drivers vulkan-tools 2>/dev/null | grep '^ii' | awk '{print \"  ✅ \" \$2 \" (\" \$3 \")\"}';
        echo '';
        if command -v vulkaninfo &>/dev/null; then
            echo 'Vulkan:';
            vulkaninfo --summary 2>/dev/null | grep -E 'GPU|driver' | head -5 | sed 's/^/  /';
        fi;
        echo '';
        echo '🎮 Steam Launch Options:';
        echo '   gamemoderun %command%';
        echo '   gamemoderun mangohud %command%  (with FPS overlay)';
        echo '';
        read -p 'Press Enter to close...'"
    elif [[ "$P_CHOICE" =~ "Install Gaming" ]]; then
        $TERM_CMD bash -c "echo '🎮 Installing Gaming Optimization...';
        echo '';
        echo 'Installing: GameMode, MangoHud, Vulkan Drivers';
        sudo apt update && sudo apt install -y gamemode mangohud mesa-vulkan-drivers vulkan-tools libvulkan1 mesa-utils;
        echo '';
        echo 'Verifying Vulkan Support...';
        if command -v vulkaninfo &>/dev/null; then
            vulkaninfo --summary 2>/dev/null | grep -q 'GPU' && echo '✅ Vulkan Detected!' || echo '⚠️  Vulkan might be missing. Check drivers.';
        else
            echo '⚠️  vulkaninfo not found — vulkan-tools may not have installed.';
        fi;
        echo '';
        echo '🎮 Steam Launch Options:';
        echo '   gamemoderun %command%';
        echo '   gamemoderun mangohud %command%  (with FPS overlay)';
        echo '';
        read -p 'Press Enter to close...'"
        tnotify "Gaming" "Optimization installed"

    # --- Nvidia Drivers ---
    elif [[ "$P_CHOICE" =~ "Uninstall Nvidia" ]]; then
        $TERM_CMD bash -c '
            echo "========================================="
            echo "  Uninstall NVIDIA Drivers"
            echo "========================================="
            echo ""
            echo "⚠️  This will remove NVIDIA drivers and restore nouveau."
            echo "   Your display may need a reboot after this."
            echo ""
            read -p "Continue? [y/N] " confirm
            [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0

            echo ""
            echo "Removing NVIDIA drivers..."
            sudo apt purge -y nvidia-driver nvidia-kernel-dkms 2>/dev/null
            sudo apt autoremove -y 2>/dev/null

            echo "Removing nouveau blacklist..."
            sudo rm -f /etc/modprobe.d/nvidia-blacklist.conf

            echo "Removing Wayland NVIDIA env..."
            rm -f "$HOME/.config/environment.d/tebian-nvidia.conf"

            echo "Rebuilding initramfs..."
            sudo update-initramfs -u

            echo ""
            echo "✅ NVIDIA drivers removed."
            echo "   REBOOT REQUIRED to switch to nouveau."
            read -p "Press Enter to close..."
        '
        tnotify "Nvidia" "Drivers uninstalled — reboot required"
    elif [[ "$P_CHOICE" == *"Nvidia Drivers (Installed)"* ]]; then
        $TERM_CMD bash -c '
            echo "========================================="
            echo "  NVIDIA Driver Status"
            echo "========================================="
            echo ""
            dpkg -l nvidia-driver 2>/dev/null | grep "^ii" | awk "{print \"  Version: \" \$3}"
            echo ""
            if command -v nvidia-smi &>/dev/null; then
                nvidia-smi 2>/dev/null || echo "  nvidia-smi not available (reboot may be needed)"
            else
                echo "  nvidia-smi not found"
            fi
            echo ""
            read -p "Press Enter to close..."
        '
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

            if lspci | grep -qi "VGA.*Intel" && lspci | grep -qi "3D.*NVIDIA\|VGA.*NVIDIA"; then
                echo ""
                echo "⚡ Hybrid GPU detected (Intel + NVIDIA)"
                echo "   PRIME render offload configured."
                echo "   Use: __NV_PRIME_RENDER_OFFLOAD=1 <app> for GPU apps"
            fi

            echo ""
            echo "✅ NVIDIA drivers installed!"
            echo "   REBOOT REQUIRED."
            read -p "Press Enter to close..."
        '
        tnotify "Nvidia" "Drivers installed — reboot required"

    # --- CPU Microcode (no uninstall — critical for CPU security) ---
    elif [[ "$P_CHOICE" =~ "Install CPU Microcode" ]]; then
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
        tnotify "CPU Microcode" "Installed"
    elif [[ "$P_CHOICE" =~ "CPU Microcode (Installed)" ]]; then
        $TERM_CMD bash -c '
            echo "========================================="
            echo "  CPU Microcode Status"
            echo "========================================="
            echo ""
            CPU_VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo 2>/dev/null | awk "{print \$3}")
            if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
                dpkg -l intel-microcode 2>/dev/null | grep "^ii" | awk "{print \"  Intel Microcode: \" \$3}"
            elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
                dpkg -l amd64-microcode 2>/dev/null | grep "^ii" | awk "{print \"  AMD Microcode: \" \$3}"
            fi
            echo ""
            echo "  CPU microcode provides security and stability fixes."
            echo "  It should not be removed."
            echo ""
            read -p "Press Enter to close..."
        '

    # --- HiDPI Scaling (toggle) ---
    elif [[ "$P_CHOICE" == *"HiDPI Scaling (2x Active)"* ]]; then
        $TERM_CMD bash -c '
            echo "Resetting HiDPI scaling to 1x..."
            echo ""
            sed -i "/^# HiDPI scaling$/d" "$HOME/.config/sway/config.user" 2>/dev/null
            sed -i "/^output \* scale 2$/d" "$HOME/.config/sway/config.user" 2>/dev/null
            sed -i "/^GDK_SCALE=2$/d" "$HOME/.profile" 2>/dev/null
            echo "✅ HiDPI scaling removed (reset to 1x)."
            echo "   Reload Sway (Mod+Shift+e) to apply."
            echo ""
            read -p "Press Enter to close..."
        '
        tnotify "HiDPI" "Reset to 1x"
    elif [[ "$P_CHOICE" =~ "Set HiDPI" ]]; then
        $TERM_CMD bash -c '
            echo "========================================="
            echo "  HiDPI Scaling Setup"
            echo "========================================="
            echo ""
            echo "This enables 2x scaling for 4K displays."
            echo ""

            mkdir -p "$HOME/.config/sway"
            grep -qxF "# HiDPI scaling" "$HOME/.config/sway/config.user" 2>/dev/null || echo "# HiDPI scaling" >> "$HOME/.config/sway/config.user"
            grep -qxF "output * scale 2" "$HOME/.config/sway/config.user" 2>/dev/null || echo "output * scale 2" >> "$HOME/.config/sway/config.user"
            grep -qxF "GDK_SCALE=2" "$HOME/.profile" 2>/dev/null || echo "GDK_SCALE=2" >> "$HOME/.profile"

            echo "✅ HiDPI scaling enabled!"
            echo "   Reload Sway (Mod+Shift+e) to apply."
            echo ""
            read -p "Press Enter to close..."
        '
        tnotify "HiDPI" "Scaling set to 2x"

    # --- Clean System Junk ---
    elif [[ "$P_CHOICE" =~ "Clean System Junk" ]]; then
        $TERM_CMD bash -c "echo '🧹 Cleaning system...';
        echo '';
        sudo apt autoremove -y;
        sudo apt clean;
        rm -rf ~/.cache/thumbnails/*;
        echo '';
        echo '✅ System cleaned!';
        read -p 'Press Enter to close...'"
        tnotify "Cleanup" "System junk removed"

    # --- Rolling Branch ---
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
            echo '   Reboot recommended.';
        else
            echo 'Cancelled.';
        fi;
        read -p 'Press Enter to close...'"
    elif [[ "$P_CHOICE" =~ "Rolling Branch (Active)" ]]; then
        tnotify "Rolling Branch" "Already on Debian Testing"

    # --- Detect & Configure Hardware ---
    elif [[ "$P_CHOICE" =~ "Detect & Configure" ]]; then
        hardware_detect_menu
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
