# shellcheck shell=bash
# tebian-settings module: perf.sh
# Sourced by tebian-settings — do not run directly

# The terminals below don't report whether their commands worked, so the
# outcome itself is checked before a notification claims it happened.
# Args: title ok-message fail-message test-command...
perf_notify() {
    local title="$1" ok="$2" bad="$3"; shift 3
    if "$@" >/dev/null 2>&1; then
        tnotify "$title" "$ok"
    else
        tnotify "$title" "$bad"
    fi
}

perf_pkg_installed() {
    local status
    status=$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)
    [[ "$status" == *"ok installed" ]]
}

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

    # HiDPI (the bare line is how older versions wrote it)
    if tebian_block_has hidpi || grep -qxF "output * scale 2" "$TEBIAN_SWAY_USER" 2>/dev/null; then
        HIDPI_LABEL="󰍺 HiDPI Scaling (2x Active)"
    else
        HIDPI_LABEL="󰍺 Set HiDPI Scaling (2x)"
    fi

    # Rolling (either apt sources format)
    if [[ "$(tebian_apt_suite)" =~ ^(testing|sid|unstable)$ ]]; then
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
        PERF_OPTS+="\n🔋 Power Mode"
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

    if is_back "$P_CHOICE"; then return; fi

    # === Handle choices ===

    # --- RAM Boost ---
    # Swappiness is raised, not lowered: swapping to zram is compression in
    # RAM, far cheaper than dropping file cache, so the kernel should use
    # it readily (the kernel docs suggest above 100 for in-memory swap).
    # The old vm.swappiness=10 left most of the zram device unused.
    if [[ "$P_CHOICE" =~ "Install RAM Boost" ]]; then
        $TERM_CMD bash -c "echo 'Installing Tebian RAM Boost...';
        if ! { sudo apt update && sudo apt install -y zram-tools; }; then
            echo ''; echo '❌ zram-tools did not install — nothing was changed.';
            read -p 'Press Enter to close...'; exit 1;
        fi;
        printf 'ALGO=zstd\nPERCENT=60\n' | sudo tee /etc/default/zramswap >/dev/null;
        echo 'vm.swappiness=150' | sudo tee /etc/sysctl.d/99-tebian-mem.conf >/dev/null;
        sudo sysctl -p /etc/sysctl.d/99-tebian-mem.conf;
        sudo systemctl enable --now zramswap;
        echo '';
        systemctl is-active --quiet zramswap && echo 'Done! RAM Boost installed and active.' || echo '❌ zramswap did not start — see: systemctl status zramswap';
        read -p 'Press Enter to close...'"
        perf_notify "RAM Boost" "Installed and enabled" "Not active — see the terminal output" \
            systemctl is-active --quiet zramswap
    elif [[ "$P_CHOICE" == *"RAM Boost (Active)"* ]]; then
        $TERM_CMD bash -c "sudo systemctl disable --now zramswap && echo 'RAM Boost disabled.' || echo 'Failed to stop.'; read -p 'Press Enter...'"
        perf_notify "RAM Boost" "Disabled" "Still running" \
            bash -c '! systemctl is-active --quiet zramswap'
    elif [[ "$P_CHOICE" == *"RAM Boost (Inactive)"* ]]; then
        $TERM_CMD bash -c "sudo systemctl enable --now zramswap && echo 'RAM Boost enabled.' || echo 'Failed to start.'; read -p 'Press Enter...'"
        perf_notify "RAM Boost" "Enabled" "Did not start" \
            systemctl is-active --quiet zramswap
    elif [[ "$P_CHOICE" =~ "Uninstall RAM Boost" ]]; then
        $TERM_CMD bash -c "echo 'Uninstalling RAM Boost...';
        sudo systemctl disable --now zramswap 2>/dev/null;
        sudo apt purge -y zram-tools;
        sudo rm -f /etc/sysctl.d/99-tebian-mem.conf;
        sudo sysctl --system >/dev/null 2>&1;
        echo '';
        echo 'RAM Boost removed.';
        read -p 'Press Enter to close...'"
        perf_notify "RAM Boost" "Uninstalled" "Not removed — see the terminal output" \
            bash -c '! dpkg-query -W -f="\${Status}" zram-tools 2>/dev/null | grep -q "ok installed"'

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
        perf_notify "App Preload" "Installed and enabled" "Not running — see the terminal output" \
            systemctl is-active --quiet preload
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

    # --- Power Mode / TLP ---
    elif [[ "$P_CHOICE" == *"Power Mode"* ]]; then
        power_mode_menu
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
        perf_notify "Laptop Power" "TLP installed" "TLP was not installed" perf_pkg_installed tlp
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
        perf_notify "Gaming" "Optimization installed" "Not installed — see the terminal output" \
            perf_pkg_installed gamemode

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

            # nvidia-driver lives in non-free; stock Debian 13 sources only
            # carry "main non-free-firmware", in either sources.list or
            # deb822 debian.sources
            echo "Enabling contrib/non-free if needed..."
            source "$TEBIAN_COMMON"
            tebian_apt_add_components "contrib non-free non-free-firmware"

            # Secure Boot only loads signed kernel modules. DKMS signs the
            # driver with its own key, but the firmware must be told to
            # trust that key (MOK enrollment) or the driver is refused at
            # every boot. The EFI variable is readable without root.
            SB=off
            sbvar=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
            if [ -r "$sbvar" ] && [ "$(od -An -tu1 "$sbvar" 2>/dev/null | awk "{print \$NF}")" = 1 ]; then
                SB=on
                echo ""
                echo "🔒 Secure Boot is on. After the install you choose a one-time"
                echo "   password; at the next boot a blue \"MOK management\" screen"
                echo "   asks for it: Enroll MOK → Continue → Yes → password → Reboot."
                echo "   Skip that screen and the NVIDIA driver will not load."
                read -p "   Continue? [y/N] " confirm
                [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0
            fi

            echo "Installing NVIDIA drivers..."
            sudo apt update
            if ! sudo apt install -y nvidia-driver firmware-misc-nonfree mokutil; then
                echo ""
                echo "❌ Driver install failed — nothing else was changed."
                read -p "Press Enter to close..."
                exit 1
            fi

            mok_ok=yes
            if [ "$SB" = on ]; then
                key=/var/lib/dkms/mok.pub
                echo ""
                if [ ! -f "$key" ]; then
                    mok_ok=no
                    echo "⚠️  No DKMS signing key at $key, so the driver is unsigned and"
                    echo "   Secure Boot will refuse it. Turn Secure Boot off in the firmware"
                    echo "   setup, or see wiki.debian.org/SecureBoot."
                elif sudo mokutil --test-key "$key" 2>&1 | grep -qi "already enrolled"; then
                    echo "Secure Boot: the DKMS signing key is already trusted."
                else
                    echo "Secure Boot: enrolling the DKMS signing key."
                    echo "Pick a one-time password (you type it once more at the next boot):"
                    if ! sudo mokutil --import "$key"; then
                        mok_ok=no
                        echo "⚠️  The key was not queued for enrollment, so the driver will not"
                        echo "   load yet. Retry with: sudo mokutil --import $key"
                    fi
                fi
            fi

            echo ""
            echo "Blacklisting nouveau..."
            echo "blacklist nouveau" | sudo tee /etc/modprobe.d/nvidia-blacklist.conf
            echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/nvidia-blacklist.conf

            echo ""
            echo "Rebuilding initramfs..."
            sudo update-initramfs -u

            echo ""
            # Any display controller that is not NVIDIA means a hybrid
            # laptop: the screen runs on the integrated GPU, and pointing
            # GBM, GLX and VA-API at nvidia for everything breaks it. There
            # the NVIDIA GPU is used per app (PRIME offload) instead.
            rm -f "$HOME/.config/environment.d/tebian-nvidia.conf"
            if lspci | grep -E "VGA|3D|Display" | grep -vqi nvidia; then
                echo "⚡ Hybrid graphics (integrated + NVIDIA): the desktop stays on the"
                echo "   integrated GPU. Run a game or app on the NVIDIA GPU with:"
                echo "   __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <app>"
                echo "   (Steam: put that before %command% in the launch options)"
            else
                # tebian-session exports these into sway at login once the
                # nvidia module is loaded, and adds --unsupported-gpu
                echo "Configuring Wayland environment..."
                mkdir -p "$HOME/.config/environment.d"
                cat > "$HOME/.config/environment.d/tebian-nvidia.conf" <<NVEOF
WLR_NO_HARDWARE_CURSORS=1
LIBVA_DRIVER_NAME=nvidia
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
NVEOF
            fi

            echo ""
            if [ "$mok_ok" = yes ]; then
                echo "✅ NVIDIA drivers installed!"
            else
                echo "⚠️  NVIDIA drivers installed, but they will not load until the"
                echo "   Secure Boot step above is done. The desktop still starts without them."
            fi
            echo "   REBOOT REQUIRED."
            read -p "Press Enter to close..."
        '
        perf_notify "Nvidia" "Drivers installed — reboot required" "Drivers were not installed" \
            perf_pkg_installed nvidia-driver

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
        perf_notify "CPU Microcode" "Installed" "Not installed" \
            bash -c 'dpkg-query -W -f="\${Status}\n" intel-microcode amd64-microcode 2>/dev/null | grep -q "ok installed"'
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
    # A config.user block like every other Settings toggle, so it can be
    # found and undone exactly. No GDK_SCALE any more: Wayland apps take
    # the scale from sway, and on top of it GDK_SCALE=2 made XWayland GTK
    # apps 4x. The lines older versions wrote are cleaned up on reset.
    elif [[ "$P_CHOICE" == *"HiDPI Scaling (2x Active)"* ]]; then
        tebian_block_remove hidpi
        sed -i '/^# HiDPI scaling$/d; /^output \* scale 2$/d' "$TEBIAN_SWAY_USER" 2>/dev/null
        sed -i '/^export GDK_SCALE=2$/d; /^GDK_SCALE=2$/d' "$HOME/.profile" 2>/dev/null
        swaymsg 'output * scale 1' >/dev/null 2>&1
        swaymsg reload >/dev/null 2>&1 &
        tnotify "HiDPI" "Reset to 1x"
    elif [[ "$P_CHOICE" =~ "Set HiDPI" ]]; then
        tebian_block_set hidpi 'output * scale 2'
        swaymsg 'output * scale 2' >/dev/null 2>&1
        tnotify "HiDPI" "Scaling set to 2x on every screen (one screen: Screen > Displays)"

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
        $TERM_CMD bash -c '
            source "$TEBIAN_COMMON"
            echo "󰚰 Switch to Rolling (Debian Testing)"
            echo ""
            current=$(tebian_apt_suite)
            if [ -z "$current" ]; then
                echo "No Debian release found in your apt sources — nothing to switch."
                read -p "Press Enter to close..."; exit 1
            fi
            echo "Currently on: $current"
            echo ""
            echo "⚠️  This is ONE-WAY. Testing gets newer packages every day and is"
            echo "   less stable. Going back to a stable release is not supported by"
            echo "   Debian — downgrading a whole system breaks it. The only way back"
            echo "   is a reinstall."
            echo ""
            echo "   Third-party repos (Docker, Tailscale, ...) are left as they are."
            echo "   Backports entries are removed: they do not apply to Testing."
            echo ""
            read -p "Type ROLLING to continue: " confirm
            if [ "$confirm" != "ROLLING" ]; then
                echo "Cancelled — nothing changed."
                read -p "Press Enter to close..."; exit 0
            fi
            echo ""
            changes=$(tebian_apt_switch_suite "$current" testing)
            if [ -z "$changes" ]; then
                echo "❌ No apt sources were changed — not switching."
                read -p "Press Enter to close..."; exit 1
            fi
            echo "$changes"
            echo ""
            echo "Running full system upgrade..."
            if sudo apt update && sudo apt full-upgrade -y; then
                echo ""
                echo "✅ Now on Rolling (Testing). Reboot recommended."
            else
                echo ""
                echo "❌ The upgrade did not finish. Your sources now point at Testing;"
                echo "   fix the error above and run: sudo apt full-upgrade"
            fi
            read -p "Press Enter to close..."
        '
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

        # GPU drivers. The proprietary NVIDIA driver is a big change (DKMS,
        # nouveau blacklisted) — offer it rather than installing it silently.
        if [ "$GPU_TYPE" = "NVIDIA" ]; then
            echo "NVIDIA GPU found. The proprietary driver is available from"
            echo "Settings → Performance → Install Nvidia Drivers."
            echo "(nouveau, the open driver already in use, needs no setup.)"
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
        [ "$GPU_TYPE" = "NVIDIA" ] && echo "  - (NVIDIA: driver install offered separately, see above)"
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

# ── Power mode ──
# With power modes on (tebian-power-modes: tlp-pd from backports) these are
# real modes like Windows': switched over D-Bus with no password, shown in
# the Power panel too, and kept when the charger is plugged or pulled.
# Debian stable's TLP has no modes, only its battery and plugged-in
# settings; picking one holds it until restart, so the menu says that
# instead of pretending they are modes.
# The power-mode switch, and the modes under it once it's on — one line
# each. Shared by Settings > Performance > Power Mode and the bar's Power
# drop-down (power_menu), so both look and behave the same.
power_mode_lines() {
    local status p a line
    status=$(tebian-power-modes status 2>/dev/null)
    case "$status" in
        on)  echo "󰓅 Power Modes (ON)" ;;
        off) echo "󰓅 Power Modes (OFF: Saver / Balanced / Performance)" ;;
    esac
    # Without TLP (status "none") power-profiles-daemon may still offer modes
    [ "$status" = off ] && return
    while IFS=$'\t' read -r p a; do
        case "$p" in
            power-saver) line="   󰌪 Power Saver — longest battery" ;;
            balanced)    line="   󰾅 Balanced" ;;
            performance) line="   󰓅 Performance — fastest, more power and heat" ;;
            *) continue ;;
        esac
        [ "$a" = 1 ] && line+="  ✓"
        echo "$line"
    done < <(tebian-panel-power profiles)
}

# Acts on a line from power_mode_lines; false if it wasn't one of them
power_mode_pick() {
    local p
    case "$1" in
        *"Power Modes (ON)"*)
            # Blocks until the window closes, so the menu reopens up to date
            tebian-power-modes off --window; return ;;
        *"Power Modes (OFF"*)
            tebian-power-modes on --window; return ;;
        *"Power Saver"*) p=power-saver ;;
        *Balanced*)      p=balanced ;;
        *Performance*)   p=performance ;;
        *) return 1 ;;
    esac
    if tebian-panel-power set-profile "$p"; then
        tnotify "Power Mode" "${p^}"
    else
        tnotify "Power Mode" "Couldn't switch to $p"
    fi
}

power_mode_menu() {
    local choice
    while true; do
        choice=$( { power_mode_lines; echo "󰌍 Back"; } | tfuzzel -d -p " 🔋 Power Mode | ")
        is_back "$choice" && return
        power_mode_pick "$choice" || return
    done
}
