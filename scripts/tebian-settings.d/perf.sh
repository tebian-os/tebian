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

perf_cpu_vendor() {
    grep -m1 "vendor_id" /proc/cpuinfo 2>/dev/null | awk '{print $3}'
}

# One line per feature, its state in brackets. Something that is installed
# and can be taken out opens a small menu of its actions (switch, status,
# uninstall) rather than sitting beside separate Install/Uninstall lines.
perf_menu() {
    while true; do
    local opts zram_label preload_label uc_label="" hidpi_label rolling_label

    if ! perf_pkg_installed zram-tools; then
        zram_label="󰓅 RAM Boost (Not Installed)"
    elif systemctl is-active --quiet zramswap 2>/dev/null; then
        zram_label="󰓅 RAM Boost (ON)"
    else
        zram_label="󰓅 RAM Boost (OFF)"
    fi

    if ! perf_pkg_installed preload; then
        preload_label="󰓅 App Preload (Not Installed)"
    elif systemctl is-active --quiet preload 2>/dev/null; then
        preload_label="󰓅 App Preload (ON)"
    else
        preload_label="󰓅 App Preload (OFF)"
    fi

    # Microcode exists only for Intel and AMD CPUs: on others (a Raspberry
    # Pi) there is nothing to install, so the line is left out
    if perf_pkg_installed intel-microcode || perf_pkg_installed amd64-microcode; then
        uc_label="󰄬 CPU Microcode (Installed)"
    elif [[ "$(perf_cpu_vendor)" =~ ^(GenuineIntel|AuthenticAMD)$ ]]; then
        uc_label="󰄰 CPU Microcode (Not Installed)"
    fi

    # HiDPI (the bare line is how older versions wrote it)
    if tebian_block_has hidpi || grep -qxF "output * scale 2" "$TEBIAN_SWAY_USER" 2>/dev/null; then
        hidpi_label="󰍺 HiDPI Scaling 2x (ON)"
    else
        hidpi_label="󰍺 HiDPI Scaling 2x (OFF)"
    fi

    # Rolling (either apt sources format)
    if [[ "$(tebian_apt_suite)" =~ ^(testing|sid|unstable)$ ]]; then
        rolling_label="󰄬 Rolling Branch (ON)"
    else
        rolling_label="󰚰 Rolling Branch (OFF)"
    fi

    opts="$zram_label
$preload_label"
    # The package, not tlp-stat: what Uninstall takes away is the package
    if perf_pkg_installed tlp; then
        opts+="
󰌪 Power Mode
󰌪 Laptop Power Management (Installed)"
    else
        opts+="
󰌪 Laptop Power Management (Not Installed)"
    fi
    if perf_pkg_installed gamemode; then
        opts+="
󰊴 Gaming Optimization (Installed)"
    else
        opts+="
󰊴 Gaming Optimization (Not Installed)"
    fi
    if perf_pkg_installed nvidia-driver; then
        opts+="
󰍹 Nvidia Drivers (Installed)"
    else
        opts+="
󰍹 Nvidia Drivers (Not Installed)"
    fi
    opts+="${uc_label:+
$uc_label}
$hidpi_label
󰆴 Clean System Junk
$rolling_label
󰍉 Detect & Configure Hardware
󰌍 Back"

    P_CHOICE=$(printf '%s\n' "$opts" | tfuzzel -d -p " 󰓅 Boost | ")

    [ -n "$P_CHOICE" ] || menu_close
    if is_back "$P_CHOICE"; then return; fi

    case "$(sysprefs_words "$P_CHOICE")" in
        "RAM Boost (Not Installed)"*)               perf_zram_install ;;
        "RAM Boost"*)                               perf_zram_menu ;;
        "App Preload (Not Installed)"*)             perf_preload_install ;;
        "App Preload"*)                             perf_preload_menu ;;
        "Power Mode"*)                              power_mode_menu ;;
        "Laptop Power Management (Not Installed)"*) perf_tlp_install ;;
        "Laptop Power Management"*)                 perf_tlp_menu ;;
        "Gaming Optimization (Not Installed)"*)     perf_gaming_install ;;
        "Gaming Optimization"*)                     perf_gaming_menu ;;
        "Nvidia Drivers (Not Installed)"*)          perf_nvidia_install ;;
        "Nvidia Drivers"*)                          perf_nvidia_menu ;;
        "CPU Microcode (Not Installed)"*)           perf_microcode_install ;;
        "CPU Microcode"*)                           perf_microcode_status ;;
        "HiDPI Scaling"*)                           perf_hidpi_toggle ;;
        "Clean System Junk"*)                       perf_clean ;;
        "Rolling Branch (ON)"*)
            tnotify "Rolling Branch" "Already on Debian Testing — going back to stable needs a reinstall" ;;
        "Rolling Branch"*)                          perf_rolling_join ;;
        "Detect & Configure Hardware"*)             hardware_detect_menu ;;
    esac
    done
}

# A feature's own small menu: the given lines and Back. Leaves the words of
# the pick (icon dropped) in PERF_PICK; returns 1 on Back. Run in the
# menu's own shell, not in $(...), so Escape can close Settings.
PERF_PICK=""
perf_pick() {
    local prompt="$1"; shift
    PERF_PICK=$(printf '%s\n' "$@" "󰌍 Back" | tfuzzel -d -p " $prompt | ")
    [ -n "$PERF_PICK" ] || menu_close
    is_back "$PERF_PICK" && return 1
    PERF_PICK=$(sysprefs_words "$PERF_PICK")
}

# --- RAM Boost ---
# Swappiness is raised, not lowered: swapping to zram is compression in
# RAM, far cheaper than dropping file cache, so the kernel should use
# it readily (the kernel docs suggest above 100 for in-memory swap).
# The old vm.swappiness=10 left most of the zram device unused.
perf_zram_install() {
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
    perf_notify "RAM Boost" "Installed and on" "Not on — see the terminal output" \
        systemctl is-active --quiet zramswap
}

perf_zram_menu() {
    local state
    while true; do
        state=OFF; systemctl is-active --quiet zramswap 2>/dev/null && state=ON
        perf_pick "󰓅 RAM Boost" "󰓅 RAM Boost ($state)" "󰆴 Uninstall RAM Boost" || return
        case "$PERF_PICK" in
            "RAM Boost (ON)"*)
                $TERM_CMD bash -c "sudo systemctl disable --now zramswap && echo 'RAM Boost disabled.' || echo 'Failed to stop.'; read -p 'Press Enter...'"
                perf_notify "RAM Boost" "Off" "Still on — see the terminal output" \
                    bash -c '! systemctl is-active --quiet zramswap' ;;
            "RAM Boost (OFF)"*)
                $TERM_CMD bash -c "sudo systemctl enable --now zramswap && echo 'RAM Boost enabled.' || echo 'Failed to start.'; read -p 'Press Enter...'"
                perf_notify "RAM Boost" "On" "Did not start — see the terminal output" \
                    systemctl is-active --quiet zramswap ;;
            "Uninstall"*)
                $TERM_CMD bash -c "echo 'Uninstalling RAM Boost...';
                sudo systemctl disable --now zramswap 2>/dev/null;
                sudo apt purge -y zram-tools;
                sudo rm -f /etc/sysctl.d/99-tebian-mem.conf;
                sudo sysctl --system >/dev/null 2>&1;
                echo '';
                echo 'RAM Boost removed.';
                read -p 'Press Enter to close...'"
                if perf_pkg_installed zram-tools; then
                    tnotify "RAM Boost" "Not removed — see the terminal output"
                else
                    tnotify "RAM Boost" "Uninstalled"
                    return
                fi ;;
        esac
    done
}

# --- App Preload ---
perf_preload_install() {
    $TERM_CMD bash -c "echo 'Installing Preload (App Preloader)...';
    echo '';
    echo 'Preload learns what apps you use and preloads them into RAM.';
    echo 'Result: Apps launch ~50% faster after a few days of learning.';
    echo '';
    if ! { sudo apt update && sudo apt install -y preload; }; then
        echo ''; echo '❌ preload did not install — nothing was changed.';
        read -p 'Press Enter to close...'; exit 1;
    fi;
    sudo systemctl enable --now preload;
    echo '';
    echo 'Preload installed and running!';
    echo '   It will learn your usage patterns over the next few days.';
    read -p 'Press Enter to close...'"
    perf_notify "App Preload" "Installed and on" "Not on — see the terminal output" \
        systemctl is-active --quiet preload
}

perf_preload_menu() {
    local state
    while true; do
        state=OFF; systemctl is-active --quiet preload 2>/dev/null && state=ON
        perf_pick "󰓅 App Preload" "󰓅 App Preload ($state)" "󰆴 Uninstall App Preload" || return
        case "$PERF_PICK" in
            "App Preload (ON)"*)
                $TERM_CMD bash -c "echo 'Disabling App Preload...';
                sudo systemctl stop preload;
                sudo systemctl disable preload;
                echo 'App Preload disabled.';
                read -p 'Press Enter to close...'"
                perf_notify "App Preload" "Off" "Still on — see the terminal output" \
                    bash -c '! systemctl is-active --quiet preload' ;;
            "App Preload (OFF)"*)
                $TERM_CMD bash -c "echo 'Enabling App Preload...';
                sudo systemctl enable --now preload;
                echo 'App Preload enabled.';
                read -p 'Press Enter to close...'"
                perf_notify "App Preload" "On" "Did not start — see the terminal output" \
                    systemctl is-active --quiet preload ;;
            "Uninstall"*)
                $TERM_CMD bash -c "echo 'Uninstalling App Preload...';
                sudo systemctl disable --now preload 2>/dev/null;
                sudo apt purge -y preload;
                echo '';
                echo 'App Preload removed.';
                read -p 'Press Enter to close...'"
                if perf_pkg_installed preload; then
                    tnotify "App Preload" "Not removed — see the terminal output"
                else
                    tnotify "App Preload" "Uninstalled"
                    return
                fi ;;
        esac
    done
}

# --- Laptop Power Management (TLP) ---
perf_tlp_install() {
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
}

perf_tlp_menu() {
    perf_pick "󰌪 Laptop Power Management" "󰆴 Uninstall Laptop Power Management" || return
    case "$PERF_PICK" in
        "Uninstall"*)
            $TERM_CMD bash -c "echo 'Uninstalling Laptop Power Management...';
            sudo systemctl disable --now tlp 2>/dev/null;
            sudo apt purge -y tlp powertop 2>/dev/null;
            sudo apt autoremove -y 2>/dev/null;
            echo '';
            echo 'Power management removed.';
            echo 'System will use default kernel power settings.';
            read -p 'Press Enter to close...'"
            perf_notify "Laptop Power" "TLP uninstalled" "TLP was not removed — see the terminal output" \
                bash -c '! dpkg-query -W -f="\${Status}" tlp 2>/dev/null | grep -q "ok installed"' ;;
    esac
}

# --- Gaming Optimization ---
perf_gaming_install() {
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
}

perf_gaming_menu() {
    while true; do
        perf_pick "󰊴 Gaming Optimization" "󰋽 Status & Steam Launch Options" "󰆴 Uninstall Gaming Optimization" || return
        case "$PERF_PICK" in
            "Status"*)
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
                read -p 'Press Enter to close...'" ;;
            "Uninstall"*)
                $TERM_CMD bash -c "echo 'Uninstalling Gaming Optimization...';
                sudo apt purge -y gamemode mangohud 2>/dev/null;
                sudo apt autoremove -y 2>/dev/null;
                echo '';
                echo 'Gaming tools removed.';
                echo 'Vulkan drivers kept (may be needed by desktop).';
                read -p 'Press Enter to close...'"
                if perf_pkg_installed gamemode; then
                    tnotify "Gaming" "Not removed — see the terminal output"
                else
                    tnotify "Gaming" "Optimization uninstalled"
                    return
                fi ;;
        esac
    done
}

# --- Nvidia Drivers ---
perf_nvidia_install() {
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
}

perf_nvidia_menu() {
    while true; do
        perf_pick "󰍹 Nvidia Drivers" "󰋽 Driver Status" "󰆴 Uninstall Nvidia Drivers" || return
        case "$PERF_PICK" in
            "Driver Status"*)
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
                ' ;;
            "Uninstall"*)
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
                # The terminal asks first; answering no leaves them installed
                if perf_pkg_installed nvidia-driver; then
                    tnotify "Nvidia" "Drivers not removed"
                else
                    tnotify "Nvidia" "Drivers uninstalled — reboot required"
                    return
                fi ;;
        esac
    done
}

# --- CPU Microcode (no uninstall — critical for CPU security) ---
perf_microcode_install() {
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
}

perf_microcode_status() {
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
}

# --- HiDPI Scaling (toggle) ---
# A config.user block like every other Settings toggle, so it can be
# found and undone exactly. No GDK_SCALE any more: Wayland apps take
# the scale from sway, and on top of it GDK_SCALE=2 made XWayland GTK
# apps 4x. The lines older versions wrote are cleaned up on reset.
perf_hidpi_toggle() {
    if tebian_block_has hidpi || grep -qxF "output * scale 2" "$TEBIAN_SWAY_USER" 2>/dev/null; then
        tebian_block_remove hidpi
        sed -i '/^# HiDPI scaling$/d; /^output \* scale 2$/d' "$TEBIAN_SWAY_USER" 2>/dev/null
        sed -i '/^export GDK_SCALE=2$/d; /^GDK_SCALE=2$/d' "$HOME/.profile" 2>/dev/null
        swaymsg 'output * scale 1' >/dev/null 2>&1
        swaymsg reload >/dev/null 2>&1 &
        tnotify "HiDPI Scaling" "Off — back to 1x"
    else
        tebian_block_set hidpi 'output * scale 2'
        swaymsg 'output * scale 2' >/dev/null 2>&1
        tnotify "HiDPI Scaling" "On — 2x on every screen (one screen: Screen > Displays)"
    fi
}

# --- Clean System Junk ---
# The terminal's exit status is not its command's, so the clean-up proves
# it finished by deleting a marker file: still there afterwards means the
# password was refused, apt failed or the window was closed early.
perf_clean() {
    local marker
    marker=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/tebian-clean.XXXXXX") || return
    $TERM_CMD bash -c "echo '🧹 Cleaning system...';
    echo '';
    rm -rf ~/.cache/thumbnails/*;
    if sudo apt autoremove -y && sudo apt clean; then
        rm -f '$marker';
        echo '';
        echo '✅ System cleaned!';
    else
        echo '';
        echo '❌ Cleaning did not finish — see the message above.';
    fi;
    read -p 'Press Enter to close...'"
    if [ -e "$marker" ]; then
        rm -f "$marker"
        tnotify "Cleanup" "Not finished — see the terminal output"
    else
        tnotify "Cleanup" "System junk removed"
    fi
}

# --- Rolling Branch ---
perf_rolling_join() {
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
    perf_notify "Rolling Branch" "On — now following Debian Testing" "Not switched — nothing changed" \
        perf_on_rolling
}

perf_on_rolling() {
    [[ "$(tebian_apt_suite)" =~ ^(testing|sid|unstable)$ ]]
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

        # The summary lists what really got installed: a refused password
        # or a package missing from the enabled repos used to be hidden
        # behind "|| true" and still reported as installed
        ok=() failed=()
        inst() {
            local what="$1"; shift
            echo "Installing $what..."
            if sudo apt install -y "$@"; then ok+=("$what"); else failed+=("$what"); fi
        }
        sudo apt update

        # GPU drivers. The proprietary NVIDIA driver is a big change (DKMS,
        # nouveau blacklisted) — offer it rather than installing it silently.
        if [ "$GPU_TYPE" = "NVIDIA" ]; then
            echo "NVIDIA GPU found. The proprietary driver is available from"
            echo "Settings → More → Performance → Nvidia Drivers."
            echo "(nouveau, the open driver already in use, needs no setup.)"
        elif [ "$GPU_TYPE" = "AMD" ]; then
            inst "AMD firmware" firmware-amd-graphics firmware-linux-nonfree
        elif [ "$GPU_TYPE" = "Intel" ]; then
            inst "Intel firmware" firmware-misc-nonfree
        fi

        # CPU microcode
        if [ "$CPU_TYPE" = "Intel" ]; then
            inst "Intel microcode" intel-microcode
        elif [ "$CPU_TYPE" = "AMD" ]; then
            inst "AMD microcode" amd64-microcode
        fi

        # Laptop power
        if [ "$IS_LAPTOP" = true ]; then
            inst "Power management (TLP)" tlp powertop &&
                sudo systemctl enable tlp 2>/dev/null
        fi

        echo ""
        echo "========================================="
        if [ ${#failed[@]} -eq 0 ]; then
            echo "  Hardware Setup Complete!"
        else
            echo "  Hardware Setup Incomplete"
        fi
        echo "========================================="
        echo ""
        [ ${#ok[@]} -gt 0 ] && { echo "Installed:"; printf "  - %s\n" "${ok[@]}"; }
        [ ${#failed[@]} -gt 0 ] && { echo "Not installed (see the messages above):"; printf "  - %s\n" "${failed[@]}"; }
        [ ${#ok[@]} -eq 0 ] && [ ${#failed[@]} -eq 0 ] && echo "Nothing to install for this hardware."
        [ "$GPU_TYPE" = "NVIDIA" ] && echo "  (NVIDIA: driver install offered separately, see above)"
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
        off) echo "󰓅 Power Modes (OFF)" ;;
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
        [ "$a" = 1 ] && line+="  ● current"
        echo "$line"
    done < <(tebian-panel-power profiles)
}

# Acts on a line from power_mode_lines; false if it wasn't one of them
power_mode_pick() {
    local p name
    case "$1" in
        *"Power Modes (ON)"*)
            # Blocks until the window closes, so the menu reopens up to date
            tebian-power-modes off --window; return ;;
        *"Power Modes (OFF"*)
            tebian-power-modes on --window; return ;;
        *"Power Saver"*) p=power-saver name="Power Saver" ;;
        *Balanced*)      p=balanced name=Balanced ;;
        *Performance*)   p=performance name=Performance ;;
        *) return 1 ;;
    esac
    if tebian-panel-power set-profile "$p"; then
        tnotify "Power Mode" "$name"
    else
        tnotify "Power Mode" "Couldn't switch to $name"
    fi
}

power_mode_menu() {
    local choice
    while true; do
        choice=$( { power_mode_lines; echo "󰌍 Back"; } | tfuzzel -d -p " 󰌪 Power Mode | ")
        [ -n "$choice" ] || menu_close
        is_back "$choice" && return
        power_mode_pick "$choice" || return
    done
}
