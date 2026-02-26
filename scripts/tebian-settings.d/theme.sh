# tebian-settings module: theme.sh
# Sourced by tebian-settings — do not run directly

theme_menu() {
    while true; do
    # Detect current theme from theme file header (format: "# Nord Theme - ...")
    CURRENT_THEME=$(head -1 "$HOME/.config/sway/theme" 2>/dev/null | sed -n 's/^# \(.*\) Theme.*/\1/p')
    _tm() { local name="$1"; local desc="$2"; [[ "${CURRENT_THEME,,}" == "${name,,}" ]] && echo "● $name - $desc" || echo "$name - $desc"; }

    THEME_OPTS="󰋩 Custom Wallpaper
─────────────────────────────────
$(_tm Glass "Transparent Dark")
$(_tm Solid "Clean Dark")
$(_tm Cyber "Neon Gamer")
$(_tm Paper "Light Mode")
$(_tm Nord "Arctic Blue")
$(_tm Dracula "Dark Purple")
$(_tm "Tokyo Night" "City Blues")
$(_tm Gruvbox "Warm Retro")
$(_tm Everforest "Forest Green")
$(_tm Material "Modern Blue")
$(_tm "Rose Pine" "Soft Pink")
─────────────────────────────────
󰇄 Desktop Feel
🔤 Font Manager
─────────────────────────────────
󰌍 Back"

    T_CHOICE=$(echo -e "$THEME_OPTS" | tfuzzel -d -p " 󰏘 Themes | ")

    if [[ "$T_CHOICE" =~ "Back" || -z "$T_CHOICE" ]]; then return; fi

    if [[ "$T_CHOICE" =~ "Custom Wallpaper" ]]; then
        custom_wallpaper_menu
    elif [[ "$T_CHOICE" =~ "Glass" ]]; then
        tebian-theme glass
    elif [[ "$T_CHOICE" =~ "Solid" ]]; then
        tebian-theme solid
    elif [[ "$T_CHOICE" =~ "Cyber" ]]; then
        tebian-theme cyber
    elif [[ "$T_CHOICE" =~ "Paper" ]]; then
        tebian-theme paper
    elif [[ "$T_CHOICE" =~ "Nord" ]]; then
        tebian-theme nord
    elif [[ "$T_CHOICE" =~ "Dracula" ]]; then
        tebian-theme dracula
    elif [[ "$T_CHOICE" =~ "Tokyo Night" ]]; then
        tebian-theme tokyo-night
    elif [[ "$T_CHOICE" =~ "Gruvbox" ]]; then
        tebian-theme gruvbox
    elif [[ "$T_CHOICE" =~ "Everforest" ]]; then
        tebian-theme everforest
    elif [[ "$T_CHOICE" =~ "Material" ]]; then
        tebian-theme material
    elif [[ "$T_CHOICE" =~ "Rose Pine" ]]; then
        tebian-theme rose-pine
    elif [[ "$T_CHOICE" =~ "Desktop Feel" ]]; then
        feel_menu
    elif [[ "$T_CHOICE" =~ "Font Manager" ]]; then
        font_menu
    fi
    done
}

custom_wallpaper_menu() {
    WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
    SHIPPED_DIR="$HOME/Tebian/assets/wallpapers"
    TARGET_DIR="$HOME/.local/share/backgrounds/tebian"
    
    mkdir -p "$WALLPAPER_DIR"
    
    while true; do
        SHIPPED=$(find "$SHIPPED_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort)
        CUSTOM=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) 2>/dev/null | sort)
        
        W_OPTS="📂 Open Wallpaper Folder
─────────────────────────────────
󰏘 Tebian Wallpapers
─────────────────────────────────
󰌍 Back"
        
        while IFS= read -r img; do
            [ -n "$img" ] && W_OPTS+="\n$(basename "$img")"
        done <<< "$SHIPPED"
        
        if [ -n "$CUSTOM" ]; then
            W_OPTS+="\n─────────────────────────────────
󰋩 My Wallpapers"
            while IFS= read -r img; do
                [ -n "$img" ] && W_OPTS+="\n$(basename "$img")"
            done <<< "$CUSTOM"
        fi
        
        W_CHOICE=$(echo -e "$W_OPTS" | tfuzzel -d -p " 󰋩 Wallpaper | ")
        
        if [[ -z "$W_CHOICE" || "$W_CHOICE" =~ "Back" ]]; then return; fi
        
        if [[ "$W_CHOICE" =~ "Open Wallpaper Folder" ]]; then
            pcmanfm "$WALLPAPER_DIR" &
            return
        fi
        
        [[ "$W_CHOICE" =~ "Wallpapers" || "$W_CHOICE" =~ "───" ]] && continue
        
        if [ -f "$SHIPPED_DIR/$W_CHOICE" ]; then
            SELECTED="$SHIPPED_DIR/$W_CHOICE"
        elif [ -f "$WALLPAPER_DIR/$W_CHOICE" ]; then
            SELECTED="$WALLPAPER_DIR/$W_CHOICE"
        else
            continue
        fi
        
        mkdir -p "$TARGET_DIR"
        cp "$SELECTED" "$TARGET_DIR/default.jpg"
        pkill swaybg 2>/dev/null
        swaybg -i "$TARGET_DIR/default.jpg" -m fill &
        tnotify "Wallpaper" "Applied: $W_CHOICE"
    done
}

feel_menu() {
    while true; do
    CURRENT_FEEL="None"
    [ -f "$HOME/.config/tebian/current-feel" ] && CURRENT_FEEL=$(cat "$HOME/.config/tebian/current-feel")

    FEEL_OPTS="󰍹 Windows - Floating, bar bottom, titlebars
 macOS - Floating, bar top, titlebars
󰕰 Tiling - Tiling, bar auto-hide, no titlebars
󰆌 Minimal - Tiling, no bar, no titlebars, no gaps
─────────────────────────────────
Current: $CURRENT_FEEL
─────────────────────────────────
󰌍 Back"

    F_CHOICE=$(echo -e "$FEEL_OPTS" | tfuzzel -d -p " 󰇄 Feel | ")

    if [[ "$F_CHOICE" =~ "Back" || -z "$F_CHOICE" ]]; then return; fi

    if [[ "$F_CHOICE" =~ "Windows" ]]; then
        apply_feel "Windows"
    elif [[ "$F_CHOICE" =~ "macOS" ]]; then
        apply_feel "macOS"
    elif [[ "$F_CHOICE" =~ "Tiling" ]]; then
        apply_feel "Tiling"
    elif [[ "$F_CHOICE" =~ "Minimal" ]]; then
        apply_feel "Minimal"
    fi
    done
}

apply_feel() {
    local FEEL="$1"
    mkdir -p "$HOME/.config/tebian" "$HOME/.config/sway"

    # --- Floating mode ---
    if [[ "$FEEL" == "Windows" || "$FEEL" == "macOS" ]]; then
        setup_floating_mode
        swaymsg '[app_id=".*"] floating enable' 2>/dev/null
        swaymsg '[class=".*"] floating enable' 2>/dev/null
    else
        remove_floating_mode
        swaymsg '[app_id=".*"] floating disable' 2>/dev/null
        swaymsg '[class=".*"] floating disable' 2>/dev/null
    fi

    # --- Bar position ---
    if [[ "$FEEL" == "Windows" ]]; then
        swaymsg "bar bar-0 position bottom" 2>/dev/null
        sed -i -E 's/^[[:space:]]*position[[:space:]]+(top|bottom)/    position bottom/' "$HOME/.config/sway/config"
        sed -i 's/^anchor = .*/anchor = top center/' "$HOME/.config/wob/wob.ini" 2>/dev/null
    elif [[ "$FEEL" == "macOS" || "$FEEL" == "Tiling" ]]; then
        swaymsg "bar bar-0 position top" 2>/dev/null
        sed -i -E 's/^[[:space:]]*position[[:space:]]+(top|bottom)/    position top/' "$HOME/.config/sway/config"
        sed -i 's/^anchor = .*/anchor = bottom center/' "$HOME/.config/wob/wob.ini" 2>/dev/null
    fi

    # --- Bar visibility (scoped to bar block to avoid matching mode "resize") ---
    if [[ "$FEEL" == "Minimal" ]]; then
        swaymsg "bar mode invisible" 2>/dev/null
        safe_sed_replace "^bar " "^}" 's/^[[:space:]]*mode[[:space:]]+(hide|dock|invisible)/    mode invisible/' "$HOME/.config/sway/config"
    elif [[ "$FEEL" == "Tiling" ]]; then
        swaymsg "bar mode hide" 2>/dev/null
        safe_sed_replace "^bar " "^}" 's/^[[:space:]]*mode[[:space:]]+(hide|dock|invisible)/    mode hide/' "$HOME/.config/sway/config"
    else
        swaymsg "bar mode dock" 2>/dev/null
        safe_sed_replace "^bar " "^}" 's/^[[:space:]]*mode[[:space:]]+(hide|dock|invisible)/    mode dock/' "$HOME/.config/sway/config"
    fi

    # --- Title bars ---
    local config_user="$HOME/.config/sway/config.user"
    if [[ "$FEEL" == "Windows" || "$FEEL" == "macOS" ]]; then
        # Enable title bars
        grep -q '# tebian-titlebars' "$config_user" 2>/dev/null || {
            echo "default_border normal 2 # tebian-titlebars" >> "$config_user"
            echo "default_floating_border normal 2 # tebian-titlebars" >> "$config_user"
        }
        swaymsg "default_border normal 2" 2>/dev/null
    else
        # Disable title bars
        sed -i '/# tebian-titlebars/d' "$config_user" 2>/dev/null
        swaymsg "default_border pixel 2" 2>/dev/null
    fi

    # --- Gaps ---
    if [[ "$FEEL" == "Minimal" ]]; then
        swaymsg "gaps inner 0" 2>/dev/null
        swaymsg "gaps outer 0" 2>/dev/null
    else
        swaymsg "gaps inner 4" 2>/dev/null
        swaymsg "gaps outer 0" 2>/dev/null
    fi

    # Save current feel
    echo "$FEEL" > "$HOME/.config/tebian/current-feel"
    swaymsg reload 2>/dev/null
    tnotify "Desktop Feel" "$FEEL applied"
}

font_menu() {
    while true; do
    F_OPTS="🔤 JetBrains Mono (Default/Code)
🔤 Terminus (Retro/Pixel)
🔤 Inter (Modern/Clean)
🔤 Hack (Classic Terminal)
─────────────────────────────────
⚠️  Applies to Sway, Kitty, & Fuzzel
─────────────────────────────────
󰌍 Back"

    F_CHOICE=$(echo -e "$F_OPTS" | tfuzzel -d -p " 🔤 Fonts | ")

    if [[ "$F_CHOICE" =~ "Back" || -z "$F_CHOICE" ]]; then return; fi

    # Helper to apply font
    apply_font() {
        local font_name="$1"
        local font_pkg="$2"
        local font_size="$3"

        FONT_NAME="$font_name" FONT_PKG="$font_pkg" FONT_SIZE="$font_size" \
        $TERM_CMD bash -c '
            echo "Installing $FONT_NAME..."
            sudo apt update && sudo apt install -y "$FONT_PKG"

            echo "Applying to configs..."
            # Sway
            sed -i "s/^font pango:.*/font pango:$FONT_NAME $FONT_SIZE/" ~/.config/sway/config
            # Kitty
            sed -i "s/^font_family.*/font_family $FONT_NAME/" ~/.config/kitty/kitty.conf
            # Fuzzel
            sed -i "s/^font=.*/font=$FONT_NAME:size=$FONT_SIZE/" ~/.config/fuzzel/fuzzel.ini

            echo "Reloading Sway..."
            swaymsg reload

            echo "Done! Font changed to $FONT_NAME."
            read -p "Press Enter..."
        '
    }

    if [[ "$F_CHOICE" =~ "JetBrains Mono" ]]; then
        apply_font "JetBrains Mono" "fonts-jetbrains-mono" "11"
    elif [[ "$F_CHOICE" =~ "Terminus" ]]; then
        apply_font "Terminus" "fonts-terminus" "12"
    elif [[ "$F_CHOICE" =~ "Inter" ]]; then
        apply_font "Inter" "fonts-inter" "11"
    elif [[ "$F_CHOICE" =~ "Hack" ]]; then
        apply_font "Hack" "fonts-hack" "11"
    fi
    done
}

