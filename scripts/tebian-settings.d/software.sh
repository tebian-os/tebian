# shellcheck shell=bash
# tebian-settings module: software.sh
# Sourced by tebian-settings — do not run directly

software_hub() {
    while true; do
    SH_OPTS="󰖟 Web Browser
📦 Package Browser
󰚩 AI Tools
󰊴 Software & Gaming
󰆍 Terminal
󰑓 Install Essentials
󰍹 Desktop Environments
󰌍 Back"

    SH_CHOICE=$(echo -e "$SH_OPTS" | tfuzzel -d -p " 󰏗 Software | ")

    if is_back "$SH_CHOICE"; then return; fi

    if [[ "$SH_CHOICE" =~ "Web Browser" ]]; then
        browser_menu
    elif [[ "$SH_CHOICE" =~ "Package Browser" ]]; then
        package_browser
    elif [[ "$SH_CHOICE" =~ "AI Tools" ]]; then
        ai_tools_menu
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

# The install logic lives in tebian-browser, shared with onboarding
browser_menu() {
    while true; do
    local BR_OPTS="" BR_ID BR_CHOICE BR_ACT BR_NAME
    for BR_ID in $(tebian-browser list); do
        if tebian-browser installed "$BR_ID"; then
            BR_OPTS+="🟢 $(tebian-browser label "$BR_ID") (Installed)\n"
        else
            BR_OPTS+="⚪ $(tebian-browser label "$BR_ID")\n"
        fi
    done

    BR_CHOICE=$(echo -e "${BR_OPTS}󰌍 Back" | tfuzzel -d -p " 󰖟 Web Browser | " --width 78)

    if is_back "$BR_CHOICE"; then return; fi

    BR_ID=$(tebian-browser id-of "$BR_CHOICE") || continue
    BR_NAME=$(tebian-browser name "$BR_ID")

    if tebian-browser installed "$BR_ID"; then
        BR_ACT=$(echo -e "󰖟 Launch $BR_NAME\n󰆴 Remove $BR_NAME\n󰌍 Back" | tfuzzel -d -p " $BR_NAME | ")
        if is_back "$BR_ACT"; then continue; fi
        if [[ "$BR_ACT" =~ "Launch" ]]; then
            tebian-browser launch "$BR_ID"
            return
        elif [[ "$BR_ACT" =~ "Remove" ]]; then
            $TERM_CMD bash -c "tebian-browser remove '$BR_ID'; read -p 'Press Enter to close...'"
            tnotify "Web Browser" "$BR_NAME removed"
        fi
    else
        $TERM_CMD bash -c "tebian-browser install '$BR_ID'; read -p 'Press Enter to close...'"
        if tebian-browser installed "$BR_ID"; then
            tnotify "Web Browser" "$BR_NAME installed"
        fi
    fi
    done
}

# Sources and install logic live in tebian-ai-tools. Not on Mod+D or in
# onboarding, unlike a browser: not everyone wants these.
ai_tools_menu() {
    local AI_IDS
    AI_IDS=$(tebian-ai-tools list)
    if [ -z "$AI_IDS" ]; then
        tnotify "AI Tools" "These tools only publish 64-bit builds"
        return
    fi

    while true; do
    local AI_OPTS="" AI_ID AI_CHOICE AI_ACT AI_NAME AI_GROUP AI_LAST="" AI_ACTIONS
    for AI_ID in $AI_IDS; do
        AI_GROUP=$(tebian-ai-tools group "$AI_ID")
        if [ "$AI_GROUP" != "$AI_LAST" ]; then
            if [ "$AI_GROUP" = app ]; then
                AI_OPTS+="── Desktop Apps\n"
            else
                AI_OPTS+="── Terminal Tools\n"
            fi
            AI_LAST=$AI_GROUP
        fi
        if tebian-ai-tools installed "$AI_ID"; then
            AI_OPTS+="🟢 $(tebian-ai-tools label "$AI_ID") (Installed)\n"
        else
            AI_OPTS+="⚪ $(tebian-ai-tools label "$AI_ID")\n"
        fi
    done

    AI_CHOICE=$(echo -e "${AI_OPTS}󰌍 Back" | tfuzzel -d -p " 󰚩 AI Tools | " --width 70)

    if is_back "$AI_CHOICE"; then return; fi

    # The group headers match no tool, so picking one just redraws
    AI_ID=$(tebian-ai-tools id-of "$AI_CHOICE") || continue
    AI_NAME=$(tebian-ai-tools name "$AI_ID")

    if ! tebian-ai-tools installed "$AI_ID"; then
        # In a terminal because it stops to show the source and ask first
        $TERM_CMD bash -c "tebian-ai-tools install '$AI_ID'; read -p 'Press Enter to close...'"
        if tebian-ai-tools installed "$AI_ID"; then
            tnotify "AI Tools" "$AI_NAME installed"
        fi
        continue
    fi

    AI_ACTIONS="󰐊 Open $AI_NAME\n󰚰 Update $AI_NAME"
    if tebian-ai-tools can-remove "$AI_ID"; then
        AI_ACTIONS+="\n󰆴 Remove $AI_NAME"
    fi
    AI_ACT=$(echo -e "$AI_ACTIONS\n󰌍 Back" | tfuzzel -d -p " $AI_NAME | ")
    if is_back "$AI_ACT"; then continue; fi

    if [[ "$AI_ACT" =~ "Open" ]]; then
        if [ "$(tebian-ai-tools group "$AI_ID")" = app ]; then
            tebian-ai-tools run "$AI_ID"
        else
            $TERM_CMD tebian-ai-tools run "$AI_ID" &
        fi
        return
    elif [[ "$AI_ACT" =~ "Update" ]]; then
        $TERM_CMD bash -c "tebian-ai-tools update '$AI_ID'; read -p 'Press Enter to close...'"
    elif [[ "$AI_ACT" =~ "Remove" ]]; then
        $TERM_CMD bash -c "tebian-ai-tools remove '$AI_ID'; read -p 'Press Enter to close...'"
    fi
    done
}

de_menu() {
    while true; do
    # Detect installed DEs
    # NOTE: COSMIC was removed — it isn't in Debian trixie's repos and the only
    # install paths are fragile third-party/Ubuntu-built repos. Re-add here once
    # Debian ships cosmic-session (trixie-backports or Debian 14), no repo needed.
    local gnome_status kde_status cinnamon_status

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

    DE_OPTS="󰍹 Desktop Environments
$gnome_status
$kde_status
$cinnamon_status
 Sway is always available at login
󰌍 Back"

    DE_CHOICE=$(echo -e "$DE_OPTS" | tfuzzel -d -p " 󰍹 DEs | ")

    if is_back "$DE_CHOICE"; then return; fi

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
                adwaita-icon-theme 2>&1
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

    if is_back "$E_CHOICE"; then return; fi

    if [[ "$E_CHOICE" =~ "Legacy System Utils" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing Full Debian Standard Utilities...'
            echo 'This restores all tools usually found in a standard Debian install.'
            echo 'Packages: man-db info texinfo plocate nfs-common bind9-host dnsutils'
            echo '          telnet ftp netcat-openbsd traceroute whois lsof strace time'
            echo '          bc dc file tree rsync'
            echo ''
            sudo apt update
            sudo apt install -y \
                man-db info texinfo plocate nfs-common \
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
            # Switch greetd to the nwg-hello login screen only when nwg-hello
            # is there to start: otherwise this replaced a working greeter
            # (tuigreet, say) with one that can't run, and nothing to log in
            # with. The shipped config is installed rather than a copy of it
            # here, so it keeps its NVIDIA and keyboard-layout handling.
            greetd_cfg=\"\${TEBIAN_DIR:-\$HOME/Tebian}/configs/greetd/config.toml\"
            if [ -f /etc/greetd/config.toml ] && ! grep -q 'nwg-hello' /etc/greetd/config.toml; then
                if [ -f /etc/nwg-hello/sway-config ] && [ -f \"\$greetd_cfg\" ]; then
                    echo 'Configuring login screen (old config kept as /etc/greetd/config.toml.tebian-bak)...'
                    sudo cp -a /etc/greetd/config.toml /etc/greetd/config.toml.tebian-bak &&
                        sudo install -m 644 \"\$greetd_cfg\" /etc/greetd/config.toml
                else
                    echo 'Login screen left as it is: nwg-hello is not installed.'
                fi
            fi
            echo ''
            echo 'Done! Some features require Sway restart.'
            read -p 'Press Enter to close...'
        "
        if command -v thunar >/dev/null; then
            tnotify "Tebian" "Desktop Essentials installed!"
        fi
    elif [[ "$E_CHOICE" =~ "File Manager" ]]; then
        $TERM_CMD bash -c "sudo apt update && sudo apt install -y thunar thunar-archive-plugin file-roller; echo 'Done!'; read -p 'Press Enter...'"
    elif [[ "$E_CHOICE" =~ "Notifications" ]]; then
        $TERM_CMD bash -c "
            sudo apt update && sudo apt install -y mako-notifier
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
    
    # The choice lives in config.user's "terminal" block; the base config's
    # `set $term` is only the fallback
    DEFAULT_TERM=$(tebian_block_get terminal | awk '$1 == "set" && $2 == "$term" { print $3; exit }')
    [ -n "$DEFAULT_TERM" ] || DEFAULT_TERM=$(grep '^set \$term' ~/.config/sway/config 2>/dev/null | cut -d' ' -f3)
    
    TERM_OPTS="[$HAS_KITTY] kitty - GPU accelerated, feature-rich (Default)
[$HAS_FOOT] foot - Lightweight, fastest startup
[$HAS_ALACRITTY] alacritty - GPU, Rust-based, minimal
[$HAS_GNOME] gnome-terminal - Traditional, tabs support
Current default: ${DEFAULT_TERM:-kitty}
󰌍 Back"

    T_CHOICE=$(echo -e "$TERM_OPTS" | tfuzzel -d -p " 󰆍 Terminal | ")

    if is_back "$T_CHOICE"; then return; fi
    # Informational row — contains a terminal name, don't treat as an install pick
    if [[ "$T_CHOICE" =~ "Current default" ]]; then continue; fi

    if [[ "$T_CHOICE" =~ "kitty" ]]; then
        $TERM_CMD bash -c '
            echo "Installing kitty terminal..."
            sudo apt update && sudo apt install -y kitty || { echo ""; echo "Install failed."; read -p "Press Enter..."; exit 1; }

            # Only seed a config if there is none — an existing one carries
            # the theme and font already chosen
            glass="${TEBIAN_DIR:-$HOME/Tebian}/configs/themes/glass/kitty.conf"
            mkdir -p ~/.config/kitty
            if [ ! -f ~/.config/kitty/kitty.conf ] && [ -f "$glass" ]; then
                cp "$glass" ~/.config/kitty/kitty.conf
            fi

            echo ""
            echo "Done! kitty is now your default terminal."
            read -p "Press Enter..."
        '
    elif [[ "$T_CHOICE" =~ "foot" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing foot terminal...'
            sudo apt update && sudo apt install -y foot || { echo ''; echo 'Install failed.'; read -p 'Press Enter...'; exit 1; }


            # Only seed a config if there is none, as for kitty
            mkdir -p ~/.config/foot
            if [ ! -f ~/.config/foot/foot.ini ]; then
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
            fi

            echo ''
            echo 'Done! foot is now your default terminal.'
            echo 'foot is extremely lightweight (~1MB vs kitty ~5MB)'
            read -p 'Press Enter...'
        "
    elif [[ "$T_CHOICE" =~ "alacritty" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing alacritty terminal...'
            sudo apt update && sudo apt install -y alacritty || { echo ''; echo 'Install failed.'; read -p 'Press Enter...'; exit 1; }


            # Only seed a config if there is none, as for kitty
            mkdir -p ~/.config/alacritty
            if [ ! -f ~/.config/alacritty/alacritty.toml ]; then
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
            fi

            echo ''
            echo 'Done! alacritty is now your default terminal.'
            read -p 'Press Enter...'
        "
    elif [[ "$T_CHOICE" =~ "gnome-terminal" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing gnome-terminal...'
            sudo apt update && sudo apt install -y gnome-terminal || { echo ''; echo 'Install failed.'; read -p 'Press Enter...'; exit 1; }


            echo ''
            echo 'Done! gnome-terminal is now your default terminal.'
            read -p 'Press Enter...'
        "
    else
        continue
    fi

    # Make it the default only if the install worked. `set $term` alone
    # isn't enough: sway expands variables as it reads each line, so the
    # Mod+Return binding in the base config already holds the old value
    # and has to be declared again after it.
    local picked
    picked=$(echo "$T_CHOICE" | grep -oE 'kitty|foot|alacritty|gnome-terminal' | head -1)
    if [ -n "$picked" ] && command -v "$picked" >/dev/null; then
        tebian_block_set terminal "set \$term $picked" 'bindsym $mod+Return exec $term'
        tnotify "Terminal" "$picked is now the default terminal (Mod+Return)"
    else
        tnotify "Terminal" "${picked:-Terminal} was not installed — default unchanged"
        continue
    fi

    # This session's terminal follows the pick: get_term would still answer
    # kitty whenever kitty is installed. Not gnome-terminal, which returns
    # at once instead of waiting for the command it runs, and every
    # "$TERM_CMD bash -c ..." here relies on that wait.
    case "$picked" in
        kitty|foot|alacritty) TERM_CMD="$picked -e" ;;
    esac
    swaymsg reload 2>/dev/null &
    tnotify "Tebian" "Terminal updated. Sway reloaded."
    done
}

software_menu() {
    while true; do
    # Detect states
    HAS_STEAM=$(command -v steam >/dev/null && echo "YES" || echo "NO")
    HAS_HEROIC=$(ls ~/Applications/Heroic.AppImage &>/dev/null && echo "YES" || echo "NO")
    # Older Tebian forced Mojang's .deb past dpkg and held it, which leaves
    # apt refusing every install and upgrade; it gets its own fix-it entry
    if dpkg-query -W minecraft-launcher >/dev/null 2>&1; then
        HAS_MC="DEB"
    elif [ -x ~/Games/minecraft-launcher/minecraft-launcher ]; then
        HAS_MC="YES"
    else
        HAS_MC="NO"
    fi
    HAS_POKE=$(ls ~/Games/PokeMMO/PokeMMO.sh &>/dev/null && echo "YES" || echo "NO")
    # Steam (needs i386) and the Minecraft launcher only exist for x86-64
    local ARCH
    ARCH=$(dpkg --print-architecture 2>/dev/null)

    # Build Dynamic Menu
    APPS="󰌍 Back
📦 Install Flatpak Support
📦 Install Distrobox (AUR)
📦 Install Nix Package Manager"
    
    # Steam Logic
    if [[ "$HAS_STEAM" == "YES" ]]; then
        APPS+="\n󰓓 Launch Steam\n󰆴 Uninstall Steam"
    elif [[ "$ARCH" == "amd64" ]]; then
        APPS+="\n󰓓 Install Steam"
    fi

    # Heroic Logic
    if [[ "$HAS_HEROIC" == "YES" ]]; then
        APPS+="\n󰍳 Launch Heroic (Epic/GOG)\n󰆴 Uninstall Heroic"
    else
        APPS+="\n󰍳 Install Heroic (Epic/GOG)"
    fi

    # Minecraft Logic
    if [[ "$HAS_MC" == "DEB" ]]; then
        APPS+="\n󰺵 Reinstall Minecraft (fixes blocked updates)\n󰆴 Uninstall Minecraft"
    elif [[ "$HAS_MC" == "YES" ]]; then
        APPS+="\n󰺵 Launch Minecraft\n󰆴 Uninstall Minecraft"
    elif [[ "$ARCH" == "amd64" ]]; then
        APPS+="\n󰺵 Install Minecraft"
    fi

    # PokeMMO Logic
    if [[ "$HAS_POKE" == "YES" ]]; then
        APPS+="\n󰄛 Launch PokeMMO\n󰆴 Uninstall PokeMMO"
    else
        APPS+="\n󰄛 Install PokeMMO"
    fi

    APPS+="\n󰊴 Install Lutris"

    # Graphics driver channel — newer Mesa via backports helps gaming
    if dpkg-query -W -f='${Version}' mesa-vulkan-drivers 2>/dev/null | grep -q bpo; then
        APPS+="\n󰢮 Graphics Drivers (Current: Backports)"
    else
        APPS+="\n󰢮 Graphics Drivers (Current: Debian Stable)"
    fi

    A_CHOICE=$(echo -e "$APPS" | tfuzzel -d -p " 󰊴 Software | " --width 50)
    
    if is_back "$A_CHOICE"; then return; fi

    # Action Handlers
    if [[ "$A_CHOICE" =~ "Install Flatpak" ]]; then
        $TERM_CMD bash -c "echo 'Installing Flatpak & Flathub...'; sudo apt update && sudo apt install -y flatpak && flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; read -p 'Done! Reboot recommended. Press Enter...'"
    elif [[ "$A_CHOICE" =~ "Install Distrobox" ]]; then
        $TERM_CMD bash -c "echo 'Installing Distrobox & Podman...'; sudo apt update && sudo apt install -y distrobox podman; echo '--------------------------------'; echo 'To use AUR:'; echo '1. distrobox create --name arch --image archlinux'; echo '2. distrobox enter arch'; echo '3. sudo pacman -S --needed git base-devel'; echo '4. git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si'; read -p 'Done! Press Enter...'"
    elif [[ "$A_CHOICE" =~ "Install Nix" ]]; then
        # Debian's own Nix packages: signed by the Debian archive like
        # everything else apt installs, instead of piping a script from
        # nixos.org into a root shell
        $TERM_CMD bash -c '
            echo "Installing Nix Package Manager (Debian package)..."
            echo ""
            if ! sudo apt update || ! sudo apt install -y nix-setup-systemd; then
                echo ""
                echo "❌ Install failed."
                read -p "Press Enter..."; exit 1
            fi
            # The daemon only serves members of nix-users
            sudo usermod -aG nix-users "$USER"
            echo ""
            echo "✅ Done. Log out and back in (for the nix-users group), then:"
            echo "   nix-channel --add https://nixos.org/channels/nixpkgs-unstable"
            echo "   nix-channel --update"
            read -p "Press Enter..."
        '

    elif [[ "$A_CHOICE" =~ "Install Steam" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing Steam...'
            echo ''
            # Steam requires contrib + non-free repos and i386 architecture
            sudo dpkg --add-architecture i386
            # Enable contrib and non-free on Debian sources (either format)
            source \"\$TEBIAN_COMMON\"
            tebian_apt_add_components 'contrib non-free'
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
        $TERM_CMD bash -c '
            fail() { echo ""; echo "❌ $1"; read -p "Press Enter..."; exit 1; }
            case "$(dpkg --print-architecture)" in
                amd64) asset=x86_64 ;;
                arm64) asset=arm64 ;;
                *) fail "Heroic publishes no build for this CPU." ;;
            esac
            # AppImages mount themselves with FUSE 2, which Debian no longer
            # installs by default; without it Heroic silently never starts
            echo "Installing FUSE 2 (AppImages need it)..."
            sudo apt update
            sudo apt install -y libfuse2t64 || sudo apt install -y libfuse2 || fail "Could not install FUSE 2."
            echo ""
            HEROIC_VER=$(curl -fsSL https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest | grep -oP "\"tag_name\": \"v\K[^\"]*")
            [ -n "$HEROIC_VER" ] || fail "Could not look up the latest Heroic release."
            echo "Downloading Heroic $HEROIC_VER ($asset)..."
            mkdir -p ~/Applications
            if curl --proto "=https" -fL -o ~/Applications/Heroic.AppImage "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v${HEROIC_VER}/Heroic-${HEROIC_VER}-linux-${asset}.AppImage"; then
                chmod +x ~/Applications/Heroic.AppImage
            else
                rm -f ~/Applications/Heroic.AppImage
                fail "Download failed — check your connection or the release page."
            fi
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
            echo ""
            echo "Done!"
            read -p "Press Enter..."
        '
    elif [[ "$A_CHOICE" =~ "Launch Heroic" ]]; then
        # Installs from before Heroic's menu entry pulled in FUSE 2 lack it
        if ! compgen -G "/usr/lib/*/libfuse.so.2" >/dev/null && ! compgen -G "/lib/*/libfuse.so.2" >/dev/null; then
            tebian_term_apt_install libfuse2t64 || { tnotify "Heroic" "Heroic needs FUSE 2 (libfuse2t64) to start"; continue; }
        fi
        setsid ~/Applications/Heroic.AppImage >/dev/null 2>&1 &
    elif [[ "$A_CHOICE" =~ "Uninstall Heroic" ]]; then
        rm -f ~/Applications/Heroic.AppImage ~/.local/share/applications/heroic.desktop && notify-send "Tebian" "Heroic removed."

    elif [[ "$A_CHOICE" =~ "Install Minecraft" || "$A_CHOICE" =~ "Reinstall Minecraft" ]]; then
        # Mojang's tarball, unpacked in the home folder. Their .deb depends
        # on library names from before Debian's 64-bit time transition
        # (libgdk-pixbuf2.0-0), which trixie doesn't have, so it can't be
        # installed by apt; forcing it past dpkg instead left an unmet
        # dependency that blocked every apt install and upgrade, security
        # updates included. The launcher fetches its own Java.
        $TERM_CMD bash -c '
            fail() { echo ""; echo "❌ $1"; read -p "Press Enter..."; exit 1; }
            echo "Installing Minecraft..."
            echo ""
            sudo -v || fail "Authentication failed."
            if dpkg-query -W minecraft-launcher >/dev/null 2>&1; then
                echo "Removing the old Minecraft package that was blocking apt..."
                sudo apt-mark unhold minecraft-launcher >/dev/null 2>&1
                sudo dpkg --purge minecraft-launcher || fail "Could not remove the old minecraft-launcher package."
                echo ""
            fi
            # Same libraries the .deb asks for, by the names this release uses
            pick() { if apt-cache show "$1" >/dev/null 2>&1; then echo "$1"; else echo "$2"; fi; }
            sudo apt update
            echo ""
            echo "Installing the libraries the launcher needs..."
            sudo apt install -y "$(pick libgtk-3-0t64 libgtk-3-0)" "$(pick libgdk-pixbuf-2.0-0 libgdk-pixbuf2.0-0)" \
                "$(pick libasound2t64 libasound2)" "$(pick libcups2t64 libcups2)" \
                libnss3 libgbm1 libxss1 libxtst6 xdg-utils xwayland || fail "Could not install the libraries."
            echo ""
            echo "Downloading the launcher from Mojang..."
            tmp=$(mktemp -d) || fail "Could not create a temporary folder."
            trap "rm -rf \"$tmp\"" EXIT
            curl --proto "=https" -fSL -o "$tmp/mc.tar.gz" https://launcher.mojang.com/download/Minecraft.tar.gz ||
                fail "Download failed."
            tar -xzf "$tmp/mc.tar.gz" -C "$tmp" && [ -x "$tmp/minecraft-launcher/minecraft-launcher" ] ||
                fail "The download is not the launcher Mojang usually ships."
            mkdir -p ~/Games
            rm -rf ~/Games/minecraft-launcher
            mv "$tmp/minecraft-launcher" ~/Games/ || fail "Could not install to ~/Games."
            mkdir -p ~/.local/share/applications
            cat > ~/.local/share/applications/minecraft-launcher.desktop << DESKEOF
[Desktop Entry]
Name=Minecraft Launcher
Comment=Official Minecraft launcher
Exec=$HOME/Games/minecraft-launcher/minecraft-launcher
Icon=applications-games
Type=Application
Categories=Game;
DESKEOF
            echo ""
            echo "Done! Launch Minecraft from the menu."
            read -p "Press Enter..."
        '
    elif [[ "$A_CHOICE" =~ "Launch Minecraft" ]]; then
        setsid ~/Games/minecraft-launcher/minecraft-launcher >/dev/null 2>&1 &
    elif [[ "$A_CHOICE" =~ "Uninstall Minecraft" ]]; then
        # Worlds and settings live in ~/.minecraft and are kept
        if [[ "$HAS_MC" == "DEB" ]]; then
            $TERM_CMD bash -c "sudo apt-mark unhold minecraft-launcher >/dev/null 2>&1; sudo dpkg --purge minecraft-launcher; rm -f ~/.local/share/applications/minecraft-launcher.desktop; read -p 'Minecraft removed (worlds in ~/.minecraft are kept). Enter...'"
        else
            rm -rf ~/Games/minecraft-launcher ~/.local/share/applications/minecraft-launcher.desktop &&
                tnotify "Tebian" "Minecraft removed (worlds in ~/.minecraft are kept)"
        fi

    elif [[ "$A_CHOICE" =~ "Install PokeMMO" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing PokeMMO...'
            echo ''
            echo 'Installing dependencies...'
            sudo apt update
            sudo apt install -y default-jre unzip xwayland 2>/dev/null || true
            echo 'Downloading PokeMMO client...'
            mkdir -p ~/Games/PokeMMO
            # Private temp file: a fixed /tmp name can be planted by another user
            zip=\$(mktemp --suffix=.zip) || exit 1
            curl --proto '=https' -fSL -o \"\$zip\" https://dl.pokemmo.com/PokeMMO-Client.zip || { rm -f \"\$zip\"; echo 'Download failed.'; read -p 'Press Enter...'; exit 1; }
            echo 'Extracting...'
            unzip -o \"\$zip\" -d ~/Games/PokeMMO
            rm -f \"\$zip\"
            chmod +x ~/Games/PokeMMO/PokeMMO.sh 2>/dev/null
            mkdir -p ~/.local/share/applications
            cat > ~/.local/share/applications/pokemmo.desktop << DESKEOF
[Desktop Entry]
Name=PokeMMO
Comment=Free Pokemon MMO
Exec=bash -c \"cd \\\$HOME/Games/PokeMMO && ./PokeMMO.sh\"
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
    elif [[ "$A_CHOICE" =~ "Graphics Drivers" ]]; then
        gfx_drivers_menu
    fi
    done
}

# ── Graphics drivers (Mesa channel) ──
# Debian stable freezes Mesa for ~2 years; trixie-backports tracks a recent
# series with months of GPU fixes (Intel ANV especially — game artifacts).
# backports is NotAutomatic, so enabling the repo upgrades nothing by itself;
# only the Mesa set is pulled from it, explicitly, with -t.
gfx_drivers_menu() {
    while true; do
        local mesa_ver channel
        mesa_ver=$(dpkg-query -W -f='${Version}' mesa-vulkan-drivers 2>/dev/null)
        if echo "$mesa_ver" | grep -q bpo; then channel="Backports"; else channel="Debian Stable"; fi

        G_OPTS="󰋼 Installed: Mesa ${mesa_ver%%-*} (${channel})
󰢮 Switch to Backports — newer Mesa, fixes game glitches
󰒙 Switch to Debian Stable — revert to the frozen version
󰌍 Back"

        G_CHOICE=$(echo -e "$G_OPTS" | tfuzzel -d -p " 󰢮 Graphics | ")
        if is_back "$G_CHOICE"; then return; fi

        if [[ "$G_CHOICE" =~ "Switch to Backports" ]]; then
            $TERM_CMD bash -c "
                echo 'Enabling trixie-backports (NotAutomatic: nothing else will upgrade)...'
                # A second entry for a suite already in the sources makes
                # apt warn 'configured multiple times' on every update
                if ! grep -rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/; then
                    echo 'deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware' | sudo tee /etc/apt/sources.list.d/tebian-backports.list >/dev/null
                fi
                sudo apt update
                PKGS='mesa-vulkan-drivers libgl1-mesa-dri'
                # Steam needs the 32-bit half too — match whatever is installed
                if dpkg -l mesa-vulkan-drivers:i386 2>/dev/null | grep -q '^ii'; then
                    PKGS=\"\$PKGS mesa-vulkan-drivers:i386 libgl1-mesa-dri:i386\"
                fi
                echo ''
                echo \"Installing from backports: \$PKGS\"
                sudo apt install -y -t trixie-backports \$PKGS
                echo ''
                echo 'Done — reboot (or log out/in) so everything picks up the new driver.'
                read -p 'Press Enter...'
            "
        elif [[ "$G_CHOICE" =~ "Switch to Debian Stable" ]]; then
            $TERM_CMD bash -c "
                # Downgrade the Mesa family back to stable, then drop the repo
                # file this toggle created.
                PKGS=\$(dpkg-query -W -f='\${Package}:\${Architecture} \${Version}\n' 2>/dev/null | grep bpo | grep -E 'mesa|libgl|libegl|libgbm|gallium|vulkan|libdrm|llvm|spirv' | cut -d' ' -f1 | sed 's|\$|/trixie|')
                if [ -z \"\$PKGS\" ]; then
                    echo 'Nothing from backports installed — already on stable.'
                else
                    echo \"Downgrading: \$PKGS\"
                    sudo apt install -y --allow-downgrades \$PKGS
                fi
                # Keep the repo while anything else still comes from it (e.g.
                # Quickshell for the Modern bar's panels) — dropping it would
                # silently stop those packages getting updates
                if dpkg-query -W -f='\${Version}\n' 2>/dev/null | grep -q bpo; then
                    echo 'Other backports packages are installed — keeping trixie-backports enabled.'
                else
                    sudo rm -f /etc/apt/sources.list.d/tebian-backports.list
                fi
                sudo apt update
                echo ''
                echo 'Back on Debian stable Mesa — reboot (or log out/in) to apply.'
                read -p 'Press Enter...'
            "
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

    if is_back "$PB_CHOICE"; then return; fi

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
    RESULTS=$(apt-cache search "$QUERY" 2>/dev/null | pkg_rank_by_name "$QUERY" ' - ')
    local COUNT
    COUNT=$(echo "$RESULTS" | grep -c . 2>/dev/null; true)

    if [[ "$COUNT" -eq 0 ]]; then
        notify-send "Package Browser" "No results for: $QUERY"
        return
    fi

    if [[ "$COUNT" -gt 50 ]]; then
        notify-send "Package Browser" "$COUNT results — showing the best 50. Try a more specific search."
    fi

    # Ranked above, so the package actually searched for is never cut off
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
            MENU+=$'\n'"󰄬 $PKG_NAME - $DESC"
        else
            MENU+=$'\n'"󰄰 $PKG_NAME - $DESC"
        fi
    done <<< "$TOP_RESULTS"

    local SEL
    SEL=$(printf '%s\n' "$MENU" | tfuzzel -d -p " 󰏗 Results ($COUNT) | ")

    if is_back "$SEL"; then return; fi

    # Extract package name — strip only the known status icons (in no_icons
    # mode the icon is already gone, so a blanket "delete first word" would
    # eat the package name itself), then take the first field
    local SEL_PKG
    SEL_PKG=$(echo "$SEL" | sed -E 's/^[[:space:]]*[󰄬󰄰✓✗] *//; s/^[[:space:]]+//' | awk '{print $1}')
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

    if is_back "$A_CHOICE"; then return; fi

    # Whole-label matches: the description row can contain "Install" too
    if [[ "$A_CHOICE" == *"Uninstall $PKG" ]]; then
        $TERM_CMD bash -c "
            echo 'Removing $PKG...'
            sudo apt remove -y '$PKG'
            echo ''
            echo 'Done!'
            read -p 'Press Enter to close...'
        "
    elif [[ "$A_CHOICE" == *"Install $PKG" ]]; then
        $TERM_CMD bash -c "
            echo 'Installing $PKG...'
            sudo apt update && sudo apt install -y '$PKG'
            echo ''
            echo 'Done!'
            read -p 'Press Enter to close...'
        "
    fi
}

# Sort search results so the package you typed comes first: exact name,
# then names starting with the query, then names containing it, then
# matches only in the description; shorter names first among name matches
# (git, git-all, git-lfs before git-buildpackage-...). apt-cache's own
# order is by package index, and only 50 are shown: searching "firefox"
# or "git" left the package itself off the list entirely.
# Reads "name<SEP>rest" lines. Args: query sep
pkg_rank_by_name() {
    Q="$1" SEP="$2" awk '
        BEGIN { q = tolower(ENVIRON["Q"]); sep = ENVIRON["SEP"] }
        {
            i = index($0, sep)
            name = tolower(i ? substr($0, 1, i - 1) : $0)
            if (name == q) r = 0
            else if (index(name, q) == 1) r = 1
            else if (index(name, q)) r = 2
            else r = 3
            # Description-only matches keep the order apt-cache gave
            print r "\t" (r < 3 ? length(name) : 0) "\t" NR "\t" $0
        }' | sort -t $'\t' -k1,1n -k2,2n -k3,3n | cut -f4-
}

apt_installed_browser() {
    while true; do
        local INSTALLED
        INSTALLED=$(apt-mark showmanual 2>/dev/null | sort)
        local COUNT
        COUNT=$(echo "$INSTALLED" | grep -c . 2>/dev/null; true)

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

        if is_back "$SEL"; then return; fi

        local SEL_PKG
        SEL_PKG=$(echo "$SEL" | awk '{print $1}')
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

    # Name first so it can be ranked like the APT results. Remotes so the
    # install comes from the remote that has the app, not always flathub;
    # before the description, which can be empty (read would then shift)
    local RESULTS
    RESULTS=$(flatpak search "$QUERY" --columns=name,application,remotes,description 2>/dev/null |
        pkg_rank_by_name "$QUERY" $'\t')
    local COUNT
    COUNT=$(echo "$RESULTS" | grep -c . 2>/dev/null; true)

    if [[ "$COUNT" -eq 0 ]]; then
        notify-send "Package Browser" "No Flatpak results for: $QUERY"
        return
    fi

    # Check which are installed
    local INSTALLED_APPS
    INSTALLED_APPS=$(flatpak list --app --columns=application 2>/dev/null)

    local MENU="󰌍 Back"
    local -A APP_REMOTE=()
    while IFS=$'\t' read -r APP_NAME APP_ID APP_REMOTES APP_DESC; do
        [ -z "$APP_ID" ] && continue
        APP_REMOTE[$APP_ID]="${APP_REMOTES%%,*}"
        local LABEL="$APP_NAME"
        [ -n "$APP_DESC" ] && LABEL="$APP_NAME - $APP_DESC"
        if echo "$INSTALLED_APPS" | grep -qx "$APP_ID"; then
            MENU+=$'\n'"󰄬 $LABEL [$APP_ID]"
        else
            MENU+=$'\n'"󰄰 $LABEL [$APP_ID]"
        fi
    done <<< "$RESULTS"

    local SEL
    SEL=$(printf '%s\n' "$MENU" | tfuzzel -d -p " 󰏗 Flatpak ($COUNT) | ")

    if is_back "$SEL"; then return; fi

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

    if is_back "$FP_CHOICE"; then return; fi

    # Whole-label matches: "Uninstall org.x.Installer" contains "Install"
    if [[ "$FP_CHOICE" == *"Uninstall $APP_ID" ]]; then
        APP_ID="$APP_ID" $TERM_CMD bash -c '
            echo "Removing $APP_ID..."
            flatpak uninstall -y "$APP_ID"
            echo ""
            echo "Done!"
            read -p "Press Enter to close..."
        '
    elif [[ "$FP_CHOICE" == *"Install $APP_ID" ]]; then
        local FP_REMOTE="${APP_REMOTE[$APP_ID]:-flathub}"
        APP_ID="$APP_ID" FP_REMOTE="$FP_REMOTE" $TERM_CMD bash -c '
            echo "Installing $APP_ID from $FP_REMOTE..."
            flatpak install -y "$FP_REMOTE" "$APP_ID"
            echo ""
            echo "Done!"
            read -p "Press Enter to close..."
        '
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
        COUNT=$(echo "$INSTALLED" | grep -c . 2>/dev/null; true)

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

        if is_back "$SEL"; then return; fi

        local APP_ID
        APP_ID=$(echo "$SEL" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
        [ -z "$APP_ID" ] && continue

        local FP_OPTS="󰆴 Uninstall $APP_ID
󰌍 Back"

        local FP_CHOICE
        FP_CHOICE=$(echo -e "$FP_OPTS" | tfuzzel -d -p " 󰏗 $APP_ID | ")

        if is_back "$FP_CHOICE"; then continue; fi

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

