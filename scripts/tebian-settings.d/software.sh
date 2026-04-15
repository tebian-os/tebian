# tebian-settings module: software.sh
# Sourced by tebian-settings — do not run directly

software_hub() {
    while true; do
    SH_OPTS="📦 Package Browser
󰊴 Software & Gaming
󰆍 Terminal
󰑓 Install Essentials
󰍹 Desktop Environments
󰌍 Back"

    SH_CHOICE=$(echo -e "$SH_OPTS" | tfuzzel -d -p " 󰏗 Software | ")

    if [[ "$SH_CHOICE" == *"󰌍 Back"* || -z "$SH_CHOICE" ]]; then return; fi

    if [[ "$SH_CHOICE" =~ "Package Browser" ]]; then
        package_browser
    elif [[ "$SH_CHOICE" =~ "Software & Gaming" ]]; then
        software_menu
    elif [[ "$SH_CHOICE" =~ "Terminal" ]]; then
        terminal_menu
    elif [[ "$SH_CHOICE" =~ "Essentials" ]]; then
        essentials_menu
    elif [[ "$SH_CHOICE" =~ "Desktop Environments" ]]; then
        de_menu
    fi
    done
}

de_menu() {
    while true; do
    # Detect installed DEs
    local gnome_status kde_status cinnamon_status cosmic_status

    if dpkg -l gnome-shell 2>/dev/null | grep -q '^ii'; then
        gnome_status="🟢 GNOME (Installed — Remove)"
    else
        gnome_status="⚪ GNOME (Install)"
    fi

    if dpkg -l kde-plasma-desktop 2>/dev/null | grep -q '^ii'; then
        kde_status="🟢 KDE Plasma (Installed — Remove)"
    else
        kde_status="⚪ KDE Plasma (Install)"
    fi

    if dpkg -l cinnamon-desktop-environment 2>/dev/null | grep -q '^ii'; then
        cinnamon_status="🟢 Cinnamon (Installed — Remove)"
    else
        cinnamon_status="⚪ Cinnamon (Install)"
    fi

    if dpkg -l cosmic-desktop 2>/dev/null | grep -q '^ii' || [ -f /usr/bin/cosmic-session ]; then
        cosmic_status="🟢 COSMIC (Installed — Remove)"
    else
        cosmic_status="⚪ COSMIC (Install)"
    fi

    DE_OPTS="󰍹 Desktop Environments
$gnome_status
$kde_status
$cinnamon_status
$cosmic_status
 Sway is always available at login
󰌍 Back"

    DE_CHOICE=$(echo -e "$DE_OPTS" | tfuzzel -d -p " 󰍹 DEs | ")

    if [[ "$DE_CHOICE" == *"󰌍 Back"* || -z "$DE_CHOICE" ]]; then return; fi

    # GNOME
    if [[ "$DE_CHOICE" =~ "GNOME" ]] && [[ "$DE_CHOICE" =~ "Remove" ]]; then
        CONFIRM=$(echo -e "Yes, remove GNOME\n󰌍 Cancel" | tfuzzel -d -p " Remove GNOME? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            $TERM_CMD bash -c "
                echo 'Removing GNOME...'
                sudo apt remove -y gnome-shell gnome-session gnome-control-center gnome-terminal nautilus gdm3 2>/dev/null
                sudo apt autoremove -y 2>/dev/null
                echo ''
                echo 'GNOME removed. Your files are untouched.'
                read -p 'Press Enter to close...'
            "
            tnotify "Desktop" "GNOME removed"
        fi
    elif [[ "$DE_CHOICE" =~ "GNOME" ]] && [[ "$DE_CHOICE" =~ "Install" ]]; then
        $TERM_CMD bash -c "
            echo '========================================='
            echo '  Installing GNOME Desktop'
            echo '========================================='
            echo ''
            echo 'This will download ~1.5GB of packages.'
            echo 'Sway remains your default — pick GNOME at login.'
            echo ''
            sudo apt update
            sudo apt install -y --no-install-recommends \
                gnome-shell gnome-session gnome-control-center \
                gnome-terminal nautilus gnome-text-editor \
                gnome-system-monitor gnome-tweaks \
                adwaita-icon-theme-full 2>&1
            # Prevent gdm from taking over — keep greetd
            sudo systemctl disable gdm 2>/dev/null || true
            sudo systemctl enable greetd 2>/dev/null || true
            echo ''
            echo 'Done! Select GNOME at the login screen.'
            read -p 'Press Enter to close...'
        "
        tnotify "Desktop" "GNOME installed — select it at login"

    # KDE Plasma
    elif [[ "$DE_CHOICE" =~ "KDE Plasma" ]] && [[ "$DE_CHOICE" =~ "Remove" ]]; then
        CONFIRM=$(echo -e "Yes, remove KDE Plasma\n󰌍 Cancel" | tfuzzel -d -p " Remove KDE? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            $TERM_CMD bash -c "
                echo 'Removing KDE Plasma...'
                sudo apt remove -y kde-plasma-desktop plasma-workspace sddm 2>/dev/null
                sudo apt autoremove -y 2>/dev/null
                echo ''
                echo 'KDE Plasma removed. Your files are untouched.'
                read -p 'Press Enter to close...'
            "
            tnotify "Desktop" "KDE Plasma removed"
        fi
    elif [[ "$DE_CHOICE" =~ "KDE Plasma" ]] && [[ "$DE_CHOICE" =~ "Install" ]]; then
        $TERM_CMD bash -c "
            echo '========================================='
            echo '  Installing KDE Plasma Desktop'
            echo '========================================='
            echo ''
            echo 'This will download ~2GB of packages.'
            echo 'Sway remains your default — pick Plasma at login.'
            echo ''
            sudo apt update
            sudo apt install -y --no-install-recommends \
                kde-plasma-desktop plasma-workspace \
                konsole dolphin kate plasma-nm \
                breeze-icon-theme 2>&1
            # Prevent sddm from taking over — keep greetd
            sudo systemctl disable sddm 2>/dev/null || true
            sudo systemctl enable greetd 2>/dev/null || true
            echo ''
            echo 'Done! Select Plasma at the login screen.'
            read -p 'Press Enter to close...'
        "
        tnotify "Desktop" "KDE Plasma installed — select it at login"

    # Cinnamon
    elif [[ "$DE_CHOICE" =~ "Cinnamon" ]] && [[ "$DE_CHOICE" =~ "Remove" ]]; then
        CONFIRM=$(echo -e "Yes, remove Cinnamon\n󰌍 Cancel" | tfuzzel -d -p " Remove Cinnamon? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            $TERM_CMD bash -c "
                echo 'Removing Cinnamon...'
                sudo apt remove -y cinnamon-desktop-environment cinnamon lightdm 2>/dev/null
                sudo apt autoremove -y 2>/dev/null
                echo ''
                echo 'Cinnamon removed. Your files are untouched.'
                read -p 'Press Enter to close...'
            "
            tnotify "Desktop" "Cinnamon removed"
        fi
    elif [[ "$DE_CHOICE" =~ "Cinnamon" ]] && [[ "$DE_CHOICE" =~ "Install" ]]; then
        $TERM_CMD bash -c "
            echo '========================================='
            echo '  Installing Cinnamon Desktop'
            echo '========================================='
            echo ''
            echo 'This will download ~1GB of packages.'
            echo 'Sway remains your default — pick Cinnamon at login.'
            echo ''
            sudo apt update
            sudo apt install -y --no-install-recommends \
                cinnamon-desktop-environment 2>&1
            # Prevent lightdm from taking over — keep greetd
            sudo systemctl disable lightdm 2>/dev/null || true
            sudo systemctl enable greetd 2>/dev/null || true
            echo ''
            echo 'Done! Select Cinnamon at the login screen.'
            read -p 'Press Enter to close...'
        "
        tnotify "Desktop" "Cinnamon installed — select it at login"

    # COSMIC
    elif [[ "$DE_CHOICE" =~ "COSMIC" ]] && [[ "$DE_CHOICE" =~ "Remove" ]]; then
        CONFIRM=$(echo -e "Yes, remove COSMIC\n󰌍 Cancel" | tfuzzel -d -p " Remove COSMIC? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            $TERM_CMD bash -c "
                echo 'Removing COSMIC...'
                sudo apt remove -y cosmic-desktop cosmic-session cosmic-greeter 2>/dev/null
                sudo apt autoremove -y 2>/dev/null
                echo ''
                echo 'COSMIC removed. Your files are untouched.'
                read -p 'Press Enter to close...'
            "
            tnotify "Desktop" "COSMIC removed"
        fi
    elif [[ "$DE_CHOICE" =~ "COSMIC" ]] && [[ "$DE_CHOICE" =~ "Install" ]]; then
        $TERM_CMD bash -c "
            echo '========================================='
            echo '  Installing COSMIC Desktop'
            echo '========================================='
            echo ''
            echo 'COSMIC requires the System76 repository.'
            echo 'Sway remains your default — pick COSMIC at login.'
            echo ''
            # Add System76 COSMIC repo if not present
            if [ ! -f /etc/apt/sources.list.d/system76-cosmic.list ]; then
                echo 'Adding COSMIC repository...'
                curl -fsSL https://apt.pop-os.org/key/cosmic-archive-keyring.gpg | sudo tee /usr/share/keyrings/cosmic-archive-keyring.gpg > /dev/null
                echo 'deb [signed-by=/usr/share/keyrings/cosmic-archive-keyring.gpg] https://apt.pop-os.org/release trixie main' | sudo tee /etc/apt/sources.list.d/system76-cosmic.list > /dev/null
            fi
            sudo apt update
            sudo apt install -y cosmic-desktop 2>&1
            # Prevent cosmic-greeter from taking over — keep greetd
            sudo systemctl disable cosmic-greeter 2>/dev/null || true
            sudo systemctl enable greetd 2>/dev/null || true
            echo ''
            echo 'Done! Select COSMIC at the login screen.'
            read -p 'Press Enter to close...'
        "
        tnotify "Desktop" "COSMIC installed — select it at login"
    fi
    done
}

essentials_menu() {
    while true; do
    E_OPTS="󰑓 Install All Essentials (Recommended)
Install File Manager (thunar)
Install Notifications (mako)
Install Clipboard Manager
Install Screenshot Tools
Install Screen Lock & Idle
Install Volume OSD (wob)
Install Brightness Control
Install Auto-tiling
Install Legacy System Utils (man, locate...)
󰌍 Back"
    
    E_CHOICE=$(echo -e "$E_OPTS" | tfuzzel -d -p " 󰑓 Essentials | ")

    if [[ "$E_CHOICE" == *"󰌍 Back"* || -z "$E_CHOICE" ]]; then return; fi

    if [[ "$E_CHOICE" =~ "Legacy System Utils" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing Full Debian Standard Utilities...'
            echo 'This restores all tools usually found in a standard Debian install.'
            echo 'Packages: man-db info texinfo mlocate nfs-common bind9-host dnsutils'
            echo '          telnet ftp netcat-openbsd traceroute whois lsof strace time'
            echo '          bc dc file tree rsync'
            echo ''
            sudo apt update
            sudo apt install -y \
                man-db info texinfo mlocate nfs-common \
                bind9-host dnsutils telnet ftp netcat-openbsd \
                traceroute whois lsof strace time \
                bc dc file tree rsync
            echo ''
            echo 'Done! Standard utilities restored.'
            read -p 'Press Enter to close...'
        "
    elif [[ "$E_CHOICE" =~ "Install All" ]]; then
        $TERM_CMD bash -c "
            echo '========================================='
            echo '  Installing Desktop Essentials'
            echo '========================================='
            echo ''
            echo 'Your password is needed to install packages.'
            echo ''
            sudo -v || { echo 'Authentication failed.'; read -p 'Press Enter...'; exit 1; }
            echo ''
            sudo apt update
            sudo apt install -y \
                cliphist \
                xwayland wget \
                pavucontrol \
                gvfs gvfs-backends adwaita-qt \
                thunar papirus-icon-theme \
                btop zram-tools
            echo ''
            echo 'Configuring...'
            mkdir -p ~/.config/mako
            [ -f ~/.config/mako/config ] || echo 'default-timeout=5000' > ~/.config/mako/config
            tebian-lockscreen-setup
            # ZRAM
            if command -v zramctl &>/dev/null; then
                echo -e 'ALGO=zstd\nPERCENT=60' | sudo tee /etc/default/zramswap > /dev/null 2>&1
                sudo systemctl restart zramswap 2>/dev/null || true
            fi
            # Configure greetd for nwg-hello
            if [ -f /etc/greetd/config.toml ] && ! grep -q 'nwg-hello' /etc/greetd/config.toml; then
                echo 'Configuring login screen...'
                sudo tee /etc/greetd/config.toml > /dev/null << 'GREETDCFG'
[terminal]
vt = 7

[default_session]
command = "sway --config /etc/nwg-hello/sway-config"
user = "greeter"
GREETDCFG
            fi
            echo ''
            echo 'Done! Some features require Sway restart.'
            read -p 'Press Enter to close...'
        "
        tnotify "Tebian" "Desktop Essentials installed!"
    elif [[ "$E_CHOICE" =~ "File Manager" ]]; then
        $TERM_CMD bash -c "sudo apt update && sudo apt install -y thunar thunar-archive-plugin file-roller; echo 'Done!'; read -p 'Press Enter...'"
    elif [[ "$E_CHOICE" =~ "Notifications" ]]; then
        $TERM_CMD bash -c "
            sudo apt update && sudo apt install -y mako
            mkdir -p ~/.config/mako
            [ -f ~/.config/mako/config ] || echo 'default-timeout=5000' > ~/.config/mako/config
            echo 'Done! Run: mako & to start'; read -p 'Press Enter...'
        "
    elif [[ "$E_CHOICE" =~ "Clipboard" ]]; then
        $TERM_CMD bash -c "sudo apt update && sudo apt install -y wl-clipboard cliphist; echo 'Done! Press Mod+V for clipboard history'; read -p 'Press Enter...'"
    elif [[ "$E_CHOICE" =~ "Screenshot" ]]; then
        $TERM_CMD bash -c "sudo apt update && sudo apt install -y grim slurp; echo 'Done! Print key takes screenshots'; read -p 'Press Enter...'"
    elif [[ "$E_CHOICE" =~ "Screen Lock" ]]; then
        $TERM_CMD bash -c "
            sudo apt update && sudo apt install -y gtklock swayidle
            tebian-lockscreen-setup
            echo 'Done! Auto-locks after 5 min idle'; read -p 'Press Enter...'
        "
    elif [[ "$E_CHOICE" =~ "Volume OSD" ]]; then
        $TERM_CMD bash -c "sudo apt update && sudo apt install -y wob; echo 'Done! Volume keys show OSD'; read -p 'Press Enter...'"
    elif [[ "$E_CHOICE" =~ "Brightness" ]]; then
        $TERM_CMD bash -c "sudo apt update && sudo apt install -y brightnessctl; echo 'Done! Brightness keys work'; read -p 'Press Enter...'"
    elif [[ "$E_CHOICE" =~ "Auto-tiling" ]]; then
        $TERM_CMD bash -c "sudo apt update && sudo apt install -y autotiling; echo 'Done! Windows auto-tile'; read -p 'Press Enter...'"
    fi
    done
}

terminal_menu() {
    while true; do
    HAS_KITTY=$(command -v kitty &>/dev/null && echo "✓" || echo " ")
    HAS_FOOT=$(command -v foot &>/dev/null && echo "✓" || echo " ")
    HAS_ALACRITTY=$(command -v alacritty &>/dev/null && echo "✓" || echo " ")
    HAS_GNOME=$(command -v gnome-terminal &>/dev/null && echo "✓" || echo " ")
    
    DEFAULT_TERM=$(grep '^set \$term' ~/.config/sway/config 2>/dev/null | cut -d' ' -f3)
    
    TERM_OPTS="[$HAS_KITTY] kitty - GPU accelerated, feature-rich (Default)
[$HAS_FOOT] foot - Lightweight, fastest startup
[$HAS_ALACRITTY] alacritty - GPU, Rust-based, minimal
[$HAS_GNOME] gnome-terminal - Traditional, tabs support
Current default: ${DEFAULT_TERM:-kitty}
󰌍 Back"

    T_CHOICE=$(echo -e "$TERM_OPTS" | tfuzzel -d -p " 󰆍 Terminal | ")

    if [[ "$T_CHOICE" == *"󰌍 Back"* || -z "$T_CHOICE" ]]; then return; fi

    if [[ "$T_CHOICE" =~ "kitty" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing kitty terminal...'
            sudo apt update && sudo apt install -y kitty

            echo ''
            echo 'Setting as default terminal...'
            sed -i 's/^set \$term .*/set \$term kitty/' ~/.config/sway/config

            mkdir -p ~/.config/kitty
            if [ -f "${TEBIAN_DIR:-$HOME/Tebian}/configs/themes/glass/kitty.conf" ]; then
                cp "${TEBIAN_DIR:-$HOME/Tebian}/configs/themes/glass/kitty.conf" ~/.config/kitty/kitty.conf
            fi

            echo ''
            echo 'Done! kitty is now your default terminal.'
            read -p 'Press Enter...'
        "
    elif [[ "$T_CHOICE" =~ "foot" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing foot terminal...'
            sudo apt update && sudo apt install -y foot

            echo ''
            echo 'Setting as default terminal...'
            sed -i 's/^set \$term .*/set \$term foot/' ~/.config/sway/config

            mkdir -p ~/.config/foot
            cat > ~/.config/foot/foot.ini << 'FOOTCONF'
[main]
font=JetBrainsMono Nerd Font:size=11
pad=12x12

[colors]
background=2e3440
foreground=eceff4
selection-background=434c5e
selection-foreground=eceff4
FOOTCONF

            echo ''
            echo 'Done! foot is now your default terminal.'
            echo 'foot is extremely lightweight (~1MB vs kitty ~5MB)'
            read -p 'Press Enter...'
        "
    elif [[ "$T_CHOICE" =~ "alacritty" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing alacritty terminal...'
            sudo apt update && sudo apt install -y alacritty

            echo ''
            echo 'Setting as default terminal...'
            sed -i 's/^set \$term .*/set \$term alacritty/' ~/.config/sway/config

            mkdir -p ~/.config/alacritty
            cat > ~/.config/alacritty/alacritty.toml << 'ALACONF'
[font]
normal = { family = \"JetBrainsMono Nerd Font\", style = \"Regular\" }
size = 11.0

[colors.primary]
background = \"#2e3440\"
foreground = \"#eceff4\"

[window.padding]
x = 12
y = 12
ALACONF

            echo ''
            echo 'Done! alacritty is now your default terminal.'
            read -p 'Press Enter...'
        "
    elif [[ "$T_CHOICE" =~ "gnome-terminal" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing gnome-terminal...'
            sudo apt update && sudo apt install -y gnome-terminal

            echo ''
            echo 'Setting as default terminal...'
            sed -i 's/^set \$term .*/set \$term gnome-terminal/' ~/.config/sway/config

            echo ''
            echo 'Done! gnome-terminal is now your default terminal.'
            read -p 'Press Enter...'
        "
    else
        continue
    fi

    # Refresh TERM_CMD so this session uses the new terminal
    TERM_CMD=$(get_term)
    swaymsg reload 2>/dev/null &
    tnotify "Tebian" "Terminal updated. Sway reloaded."
    done
}

software_menu() {
    while true; do
    # Detect states
    HAS_STEAM=$(command -v steam >/dev/null && echo "YES" || echo "NO")
    HAS_HEROIC=$(ls ~/Applications/Heroic.AppImage &>/dev/null && echo "YES" || echo "NO")
    HAS_MC=$(command -v minecraft-launcher >/dev/null && echo "YES" || echo "NO")
    HAS_POKE=$(ls ~/Games/PokeMMO/PokeMMO.sh &>/dev/null && echo "YES" || echo "NO")

    # Build Dynamic Menu
    APPS="󰌍 Back
📦 Install Flatpak Support
📦 Install Distrobox (AUR)
📦 Install Nix Package Manager"
    
    # Steam Logic
    if [[ "$HAS_STEAM" == "YES" ]]; then
        APPS+="\n󰓓 Launch Steam\n󰆴 Uninstall Steam"
    else
        APPS+="\n󰓓 Install Steam"
    fi

    # Heroic Logic
    if [[ "$HAS_HEROIC" == "YES" ]]; then
        APPS+="\n󰍳 Launch Heroic (Epic/GOG)\n󰆴 Uninstall Heroic"
    else
        APPS+="\n󰍳 Install Heroic (Epic/GOG)"
    fi

    # Minecraft Logic
    if [[ "$HAS_MC" == "YES" ]]; then
        APPS+="\n󰺵 Launch Minecraft\n󰆴 Uninstall Minecraft"
    else
        APPS+="\n󰺵 Install Minecraft"
    fi

    # PokeMMO Logic
    if [[ "$HAS_POKE" == "YES" ]]; then
        APPS+="\n󰄛 Launch PokeMMO\n󰆴 Uninstall PokeMMO"
    else
        APPS+="\n󰄛 Install PokeMMO"
    fi

    APPS+="\n󰊴 Install Lutris"

    A_CHOICE=$(echo -e "$APPS" | tfuzzel -d -p " 󰊴 Software | ")
    
    if [[ "$A_CHOICE" == *"󰌍 Back"* || -z "$A_CHOICE" ]]; then return; fi

    # Action Handlers
    if [[ "$A_CHOICE" =~ "Install Flatpak" ]]; then
        $TERM_CMD bash -c "echo 'Installing Flatpak & Flathub...'; sudo apt update && sudo apt install -y flatpak && flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; read -p 'Done! Reboot recommended. Press Enter...'"
    elif [[ "$A_CHOICE" =~ "Install Distrobox" ]]; then
        $TERM_CMD bash -c "echo 'Installing Distrobox & Podman...'; sudo apt update && sudo apt install -y distrobox podman; echo '--------------------------------'; echo 'To use AUR:'; echo '1. distrobox create --name arch --image archlinux'; echo '2. distrobox enter arch'; echo '3. git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si'; read -p 'Done! Press Enter...'"
    elif [[ "$A_CHOICE" =~ "Install Nix" ]]; then
        $TERM_CMD bash -c "echo 'Installing Nix Package Manager...'
        echo ''
        echo 'Downloading installer with signature verification...'
        INSTALLER=/tmp/nix-install.sh
        curl -fsSL -o \"\$INSTALLER\" https://nixos.org/nix/install
        # Verify the installer is a shell script (basic check)
        if ! head -1 \"\$INSTALLER\" | grep -q '^#!/'; then
            echo 'ERROR: Downloaded file does not look like a shell script.'
            rm -f \"\$INSTALLER\"
            read -p 'Press Enter...'
            exit 1
        fi
        chmod +x \"\$INSTALLER\"
        sh \"\$INSTALLER\" --daemon
        rm -f \"\$INSTALLER\"
        echo ''
        echo 'Done! Please restart your shell.'
        read -p 'Press Enter...'"
    
    elif [[ "$A_CHOICE" =~ "Install Steam" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing Steam...'
            echo ''
            # Steam requires contrib + non-free repos and i386 architecture
            sudo dpkg --add-architecture i386
            # Enable contrib and non-free if not already present
            SOURCES_FILE='/etc/apt/sources.list'
            if [ -f \"\$SOURCES_FILE\" ] && ! grep -qE '^deb .* contrib' \"\$SOURCES_FILE\"; then
                echo 'Enabling contrib and non-free repositories...'
                sudo sed -i '/^deb .*main/ s/\$/ contrib non-free/' \"\$SOURCES_FILE\"
            fi
            sudo apt update
            sudo apt install -y xwayland 2>/dev/null || true
            if ! sudo apt install -y steam-installer; then
                echo ''
                echo 'steam-installer failed. Trying steam-launcher...'
                sudo apt install -y steam-launcher 2>/dev/null || echo 'Steam install failed. You may need to install from store.steampowered.com'
            fi
            echo ''
            echo 'Done!'
            read -p 'Press Enter...'
        "
    elif [[ "$A_CHOICE" =~ "Launch Steam" ]]; then
        $TERM_CMD bash -c "steam 2>&1; echo ''; echo 'Steam exited.'; read -p 'Press Enter...'" &
    elif [[ "$A_CHOICE" =~ "Uninstall Steam" ]]; then
        $TERM_CMD bash -c "sudo apt purge -y steam-installer steam; sudo apt autoremove -y; read -p 'Steam removed. Enter...'"
    
    elif [[ "$A_CHOICE" =~ "Install Heroic" ]]; then
        $TERM_CMD bash -c "
            mkdir -p ~/Applications
            curl -L -o ~/Applications/Heroic.AppImage https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest/download/Heroic-\$(curl -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest | grep -oP '\"tag_name\": \"v\K[^\"]*')-x86_64.AppImage && chmod +x ~/Applications/Heroic.AppImage
            mkdir -p ~/.local/share/applications
            cat > ~/.local/share/applications/heroic.desktop << DESKEOF
[Desktop Entry]
Name=Heroic Games Launcher
Comment=Epic Games & GOG client
Exec=$HOME/Applications/Heroic.AppImage
Icon=heroic
Type=Application
Categories=Game;
DESKEOF
            echo 'Done!'
            read -p 'Press Enter...'
        "
    elif [[ "$A_CHOICE" =~ "Launch Heroic" ]]; then
        ~/Applications/Heroic.AppImage &
    elif [[ "$A_CHOICE" =~ "Uninstall Heroic" ]]; then
        rm -f ~/Applications/Heroic.AppImage ~/.local/share/applications/heroic.desktop && notify-send "Tebian" "Heroic removed."

    elif [[ "$A_CHOICE" =~ "Install Minecraft" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing Minecraft...'
            echo ''
            echo 'Downloading launcher...'
            curl -fSL -o /tmp/mc.deb https://launcher.mojang.com/download/Minecraft.deb || { echo 'Download failed.'; read -p 'Press Enter...'; exit 1; }
            echo 'Installing dependencies...'
            sudo apt update
            sudo apt install -y default-jre libasound2t64 libgtk-3-0t64 libcups2t64 xdg-utils xwayland 2>/dev/null || true
            # The .deb uses old dependency names (pre-t64 transition) — force install then hold
            sudo dpkg -i --force-depends /tmp/mc.deb
            sudo apt-mark hold minecraft-launcher
            rm -f /tmp/mc.deb
            echo ''
            echo 'Done! Launch Minecraft from the menu.'
            read -p 'Press Enter...'
        "
    elif [[ "$A_CHOICE" =~ "Launch Minecraft" ]]; then
        minecraft-launcher &
    elif [[ "$A_CHOICE" =~ "Uninstall Minecraft" ]]; then
        $TERM_CMD bash -c "sudo apt purge -y minecraft-launcher; sudo apt autoremove -y; read -p 'Minecraft removed. Enter...'"

    elif [[ "$A_CHOICE" =~ "Install PokeMMO" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing PokeMMO...'
            echo ''
            echo 'Installing dependencies...'
            sudo apt update
            sudo apt install -y default-jre unzip xwayland 2>/dev/null || true
            echo 'Downloading PokeMMO client...'
            mkdir -p ~/Games/PokeMMO
            curl -fSL -o /tmp/PokeMMO-Client.zip https://dl.pokemmo.com/PokeMMO-Client.zip || { echo 'Download failed.'; read -p 'Press Enter...'; exit 1; }
            echo 'Extracting...'
            unzip -o /tmp/PokeMMO-Client.zip -d ~/Games/PokeMMO
            rm -f /tmp/PokeMMO-Client.zip
            chmod +x ~/Games/PokeMMO/PokeMMO.sh 2>/dev/null
            mkdir -p ~/.local/share/applications
            cat > ~/.local/share/applications/pokemmo.desktop << DESKEOF
[Desktop Entry]
Name=PokeMMO
Comment=Free Pokemon MMO
Exec=bash -c "cd \\\$HOME/Games/PokeMMO && ./PokeMMO.sh"
Icon=applications-games
Type=Application
Categories=Game;
DESKEOF
            echo ''
            echo 'Done! PokeMMO installed to ~/Games/PokeMMO'
            read -p 'Press Enter...'
        "
    elif [[ "$A_CHOICE" =~ "Launch PokeMMO" ]]; then
        bash -c "cd ~/Games/PokeMMO && ./PokeMMO.sh" &
    elif [[ "$A_CHOICE" =~ "Uninstall PokeMMO" ]]; then
        rm -rf ~/Games/PokeMMO ~/.local/share/applications/pokemmo.desktop && notify-send "Tebian" "PokeMMO removed."
    
    elif [[ "$A_CHOICE" =~ "Install Lutris" ]]; then
        $TERM_CMD bash -c "echo 'Installing Lutris...'; sudo apt update && sudo apt install -y lutris; echo 'Done!'; read -p 'Press Enter to close...'"
    fi
    done
}

package_browser() {
    while true; do
    PB_OPTS="󰍉 Search APT Packages
󰍉 Search Flatpak Apps
󰏗 Browse Installed (APT)
󰏗 Browse Installed (Flatpak)
󰌍 Back"

    PB_CHOICE=$(echo -e "$PB_OPTS" | tfuzzel -d -p " 󰏗 Packages | ")

    if [[ "$PB_CHOICE" == *"󰌍 Back"* || -z "$PB_CHOICE" ]]; then return; fi

    if [[ "$PB_CHOICE" =~ "Search APT" ]]; then
        apt_search
    elif [[ "$PB_CHOICE" =~ "Search Flatpak" ]]; then
        flatpak_search
    elif [[ "$PB_CHOICE" =~ "Installed (APT)" ]]; then
        apt_installed_browser
    elif [[ "$PB_CHOICE" =~ "Installed (Flatpak)" ]]; then
        flatpak_installed_browser
    fi
    done
}

apt_search() {
    local QUERY
    QUERY=$(echo "" | tfuzzel -d -p " 󰍉 APT Search: ")
    if [[ -z "$QUERY" ]]; then return; fi

    local RESULTS
    RESULTS=$(apt-cache search "$QUERY" 2>/dev/null)
    local COUNT
    COUNT=$(echo "$RESULTS" | grep -c . 2>/dev/null || echo 0)

    if [[ "$COUNT" -eq 0 ]]; then
        notify-send "Package Browser" "No results for: $QUERY"
        return
    fi

    if [[ "$COUNT" -gt 200 ]]; then
        notify-send "Package Browser" "$COUNT results — showing first 50. Try a more specific search."
    fi

    # Get first 50 results
    local TOP_RESULTS
    TOP_RESULTS=$(echo "$RESULTS" | head -50)

    # Batch check install state
    local PKG_NAMES
    PKG_NAMES=$(echo "$TOP_RESULTS" | awk -F' - ' '{print $1}')
    local INSTALLED_PKGS
    INSTALLED_PKGS=$(echo "$PKG_NAMES" | xargs dpkg -l 2>/dev/null | awk '/^ii/{print $2}')

    local MENU="󰌍 Back"
    while IFS= read -r LINE; do
        local PKG_NAME
        PKG_NAME=$(echo "$LINE" | awk -F' - ' '{print $1}')
        local DESC="${LINE#* - }"
        if echo "$INSTALLED_PKGS" | grep -qx "$PKG_NAME"; then
            MENU+="\n󰄬 $PKG_NAME - $DESC"
        else
            MENU+="\n󰄰 $PKG_NAME - $DESC"
        fi
    done <<< "$TOP_RESULTS"

    local SEL
    SEL=$(echo -e "$MENU" | tfuzzel -d -p " 󰏗 Results ($COUNT) | ")

    if [[ "$SEL" == *"󰌍 Back"* || -z "$SEL" ]]; then return; fi

    # Extract package name — strip leading emoji + space, get first word
    local SEL_PKG
    SEL_PKG=$(echo "$SEL" | sed 's/^[^ ]* //' | awk '{print $1}')
    apt_package_action "$SEL_PKG"
}

apt_package_action() {
    local PKG="$1"
    local IS_INSTALLED=false
    dpkg -l "$PKG" 2>/dev/null | grep -q "^ii" && IS_INSTALLED=true

    local DESC
    DESC=$(apt-cache show "$PKG" 2>/dev/null | awk -F': ' '/^Description:/{print $2; exit}')
    local SIZE
    SIZE=$(apt-cache show "$PKG" 2>/dev/null | awk -F': ' '/^Installed-Size:/{print $2; exit}')

    local ACTION_OPTS="󰌍 Back"
    if $IS_INSTALLED; then
        ACTION_OPTS+="\n󰆴 Uninstall $PKG"
    else
        ACTION_OPTS+="\n󰏗 Install $PKG"
    fi
    ACTION_OPTS+="\n󰋽 $DESC"
    [ -n "$SIZE" ] && ACTION_OPTS+="\n󰋊 Size: ${SIZE} KB"

    local A_CHOICE
    A_CHOICE=$(echo -e "$ACTION_OPTS" | tfuzzel -d -p " 󰏗 $PKG | ")

    if [[ "$A_CHOICE" == *"󰌍 Back"* || -z "$A_CHOICE" ]]; then return; fi

    if [[ "$A_CHOICE" =~ "Install" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing $PKG...'
            sudo apt update && sudo apt install -y '$PKG'
            echo ''
            echo 'Done!'
            read -p 'Press Enter to close...'
        "
    elif [[ "$A_CHOICE" =~ "Uninstall" ]]; then
        $TERM_CMD bash -c "
            echo 'Removing $PKG...'
            sudo apt remove -y '$PKG'
            echo ''
            echo 'Done!'
            read -p 'Press Enter to close...'
        "
    fi
}

apt_installed_browser() {
    while true; do
        local INSTALLED
        INSTALLED=$(apt-mark showmanual 2>/dev/null | sort)
        local COUNT
        COUNT=$(echo "$INSTALLED" | grep -c . 2>/dev/null || echo 0)

        if [[ "$COUNT" -eq 0 ]]; then
            notify-send "Package Browser" "No manually installed packages found."
            return
        fi

        local MENU="󰌍 Back"
        while IFS= read -r PKG; do
            [ -z "$PKG" ] && continue
            MENU+="\n  $PKG"
        done <<< "$INSTALLED"

        local SEL
        SEL=$(echo -e "$MENU" | tfuzzel -d -p " 󰏗 Installed APT ($COUNT) | ")

        if [[ "$SEL" == *"󰌍 Back"* || -z "$SEL" ]]; then return; fi

        local SEL_PKG
        SEL_PKG=$(echo "$SEL" | sed 's/^[^ ]* //')
        apt_package_action "$SEL_PKG"
    done
}

flatpak_search() {
    if ! command -v flatpak &>/dev/null; then
        echo -e "󰌍 Back\n󰏗 Flatpak not installed\n󰏗 Install via: Software > Software & Gaming" | tfuzzel -d -p " 󰏗 Flatpak | "
        return
    fi

    local QUERY
    QUERY=$(echo "" | tfuzzel -d -p " 󰍉 Flatpak Search: ")
    if [[ -z "$QUERY" ]]; then return; fi

    local RESULTS
    RESULTS=$(flatpak search "$QUERY" --columns=application,name,description 2>/dev/null | tail -n +1)
    local COUNT
    COUNT=$(echo "$RESULTS" | grep -c . 2>/dev/null || echo 0)

    if [[ "$COUNT" -eq 0 ]]; then
        notify-send "Package Browser" "No Flatpak results for: $QUERY"
        return
    fi

    # Check which are installed
    local INSTALLED_APPS
    INSTALLED_APPS=$(flatpak list --app --columns=application 2>/dev/null)

    local MENU="󰌍 Back"
    while IFS=$'\t' read -r APP_ID APP_NAME APP_DESC; do
        [ -z "$APP_ID" ] && continue
        local LABEL="$APP_NAME"
        [ -n "$APP_DESC" ] && LABEL="$APP_NAME - $APP_DESC"
        if echo "$INSTALLED_APPS" | grep -qx "$APP_ID"; then
            MENU+="\n󰄬 $LABEL [$APP_ID]"
        else
            MENU+="\n󰄰 $LABEL [$APP_ID]"
        fi
    done <<< "$RESULTS"

    local SEL
    SEL=$(echo -e "$MENU" | tfuzzel -d -p " 󰏗 Flatpak ($COUNT) | ")

    if [[ "$SEL" == *"󰌍 Back"* || -z "$SEL" ]]; then return; fi

    # Extract app ID from brackets
    local APP_ID
    APP_ID=$(echo "$SEL" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
    [ -z "$APP_ID" ] && return

    local IS_INSTALLED=false
    echo "$INSTALLED_APPS" | grep -qx "$APP_ID" && IS_INSTALLED=true

    local FP_OPTS="󰌍 Back"
    if $IS_INSTALLED; then
        FP_OPTS+="\n󰆴 Uninstall $APP_ID"
    else
        FP_OPTS+="\n󰏗 Install $APP_ID"
    fi

    local FP_CHOICE
    FP_CHOICE=$(echo -e "$FP_OPTS" | tfuzzel -d -p " 󰏗 $APP_ID | ")

    if [[ "$FP_CHOICE" == *"󰌍 Back"* || -z "$FP_CHOICE" ]]; then return; fi

    if [[ "$FP_CHOICE" =~ "Install" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing $APP_ID...'
            flatpak install -y flathub '$APP_ID'
            echo ''
            echo 'Done!'
            read -p 'Press Enter to close...'
        "
    elif [[ "$FP_CHOICE" =~ "Uninstall" ]]; then
        $TERM_CMD bash -c "
            echo 'Removing $APP_ID...'
            flatpak uninstall -y '$APP_ID'
            echo ''
            echo 'Done!'
            read -p 'Press Enter to close...'
        "
    fi
}

flatpak_installed_browser() {
    if ! command -v flatpak &>/dev/null; then
        echo -e "󰌍 Back\n󰏗 Flatpak not installed\n󰏗 Install via: Software > Software & Gaming" | tfuzzel -d -p " 󰏗 Flatpak | "
        return
    fi

    while true; do
        local INSTALLED
        INSTALLED=$(flatpak list --app --columns=application,name 2>/dev/null)
        local COUNT
        COUNT=$(echo "$INSTALLED" | grep -c . 2>/dev/null || echo 0)

        if [[ "$COUNT" -eq 0 ]]; then
            notify-send "Package Browser" "No Flatpak apps installed."
            return
        fi

        local MENU="󰌍 Back"
        while IFS=$'\t' read -r APP_ID APP_NAME; do
            [ -z "$APP_ID" ] && continue
            MENU+="\n  $APP_NAME [$APP_ID]"
        done <<< "$INSTALLED"

        local SEL
        SEL=$(echo -e "$MENU" | tfuzzel -d -p " 󰏗 Installed Flatpak ($COUNT) | ")

        if [[ "$SEL" == *"󰌍 Back"* || -z "$SEL" ]]; then return; fi

        local APP_ID
        APP_ID=$(echo "$SEL" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
        [ -z "$APP_ID" ] && continue

        local FP_OPTS="󰆴 Uninstall $APP_ID
󰌍 Back"

        local FP_CHOICE
        FP_CHOICE=$(echo -e "$FP_OPTS" | tfuzzel -d -p " 󰏗 $APP_ID | ")

        if [[ "$FP_CHOICE" == *"󰌍 Back"* || -z "$FP_CHOICE" ]]; then continue; fi

        if [[ "$FP_CHOICE" =~ "Uninstall" ]]; then
            $TERM_CMD bash -c "
                echo 'Removing $APP_ID...'
                flatpak uninstall -y '$APP_ID'
                echo ''
                echo 'Done!'
                read -p 'Press Enter to close...'
            "
        fi
    done
}

