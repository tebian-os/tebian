# shellcheck shell=bash
# tebian-settings module: theme.sh
# Sourced by tebian-settings — do not run directly

theme_menu() {
    while true; do
    # Detect current theme from theme file header (format: "# Nord Theme - ...")
    CURRENT_THEME=$(head -1 "$HOME/.config/sway/theme" 2>/dev/null | sed -n 's/^# \(.*\) Theme.*/\1/p')
    _tm() { local name="$1"; local desc="$2"; [[ "${CURRENT_THEME,,}" == "${name,,}" ]] && echo "● $name - $desc" || echo "$name - $desc"; }

    THEME_OPTS="󰋩 Custom Wallpaper
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
󰇄 Desktop Feel
󰛖 Font Manager
󰌍 Back"

    T_CHOICE=$(echo -e "$THEME_OPTS" | tfuzzel -d -p " 󰏘 Themes | ")

    if is_back "$T_CHOICE"; then return; fi

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
    SHIPPED_DIR="${TEBIAN_DIR:-$HOME/Tebian}/assets/wallpapers"
    TARGET_DIR="$HOME/.local/share/backgrounds/tebian"
    
    mkdir -p "$WALLPAPER_DIR"
    
    while true; do
        SHIPPED=$(find "$SHIPPED_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort)
        CUSTOM=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) 2>/dev/null | sort)
        
        W_OPTS="📂 Open Wallpaper Folder
󰏘 Tebian Wallpapers
󰌍 Back"
        
        while IFS= read -r img; do
            [ -n "$img" ] && W_OPTS+="\n$(basename "$img")"
        done <<< "$SHIPPED"
        
        if [ -n "$CUSTOM" ]; then
            W_OPTS+="\n󰋩 My Wallpapers"
            while IFS= read -r img; do
                [ -n "$img" ] && W_OPTS+="\n$(basename "$img")"
            done <<< "$CUSTOM"
        fi
        
        W_CHOICE=$(echo -e "$W_OPTS" | tfuzzel -d -p " 󰋩 Wallpaper | ")
        
        if is_back "$W_CHOICE"; then return; fi
        
        if [[ "$W_CHOICE" =~ "Open Wallpaper Folder" ]]; then
            thunar "$WALLPAPER_DIR" &
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
        pkill swaybg 2>/dev/null; sleep 0.1
        swaybg -i "$TARGET_DIR/default.jpg" -m fill &
        disown
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
Current: $CURRENT_FEEL
󰌍 Back"

    F_CHOICE=$(echo -e "$FEEL_OPTS" | tfuzzel -d -p " 󰇄 Feel | ")

    if is_back "$F_CHOICE"; then return; fi

    # Match on the "<name> - " label prefix — descriptions reuse the words
    # (e.g. "Minimal - Tiling, no bar" would otherwise hit the Tiling branch)
    if [[ "$F_CHOICE" =~ "Windows - " ]]; then
        apply_feel "Windows"
    elif [[ "$F_CHOICE" =~ "macOS - " ]]; then
        apply_feel "macOS"
    elif [[ "$F_CHOICE" =~ "Minimal - " ]]; then
        apply_feel "Minimal"
    elif [[ "$F_CHOICE" =~ "Tiling - " ]]; then
        apply_feel "Tiling"
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

    # --- Bar position (bar_set_* live in ui.sh; they persist to config.user) ---
    if [[ "$FEEL" == "Windows" ]]; then
        bar_set_position bottom
    elif [[ "$FEEL" == "macOS" || "$FEEL" == "Tiling" || "$FEEL" == "Minimal" ]]; then
        bar_set_position top
    fi

    # --- Bar visibility ---
    if [[ "$FEEL" == "Minimal" ]]; then
        bar_set_mode invisible
    elif [[ "$FEEL" == "Tiling" ]]; then
        bar_set_mode hide
    else
        bar_set_mode dock
    fi

    # --- Title bars ---
    if [[ "$FEEL" == "Windows" || "$FEEL" == "macOS" ]]; then
        tebian_block_set titlebars "default_border normal 2" "default_floating_border normal 2"
        swaymsg "default_border normal 2" 2>/dev/null
    else
        tebian_block_remove titlebars
        swaymsg "default_border pixel 2" 2>/dev/null
    fi

    # --- Gaps ---
    if [[ "$FEEL" == "Minimal" ]]; then
        tebian_block_set gaps "gaps inner 0" "gaps outer 0"
    else
        tebian_block_set gaps "gaps inner 4" "gaps outer 0"
    fi

    # Save current feel
    echo "$FEEL" > "$HOME/.config/tebian/current-feel"
    tnotify "Desktop Feel" "$FEEL applied"
    swaymsg reload 2>/dev/null &
}

font_menu() {
    while true; do
    F_OPTS="󰛖 JetBrains Mono (Default/Code)
󰛖 Terminus (Retro/Pixel)
󰛖 Inter (Modern/Clean)
󰛖 Hack (Classic Terminal)
⚠️  Applies to Sway, Kitty, & Fuzzel
󰌍 Back"

    F_CHOICE=$(echo -e "$F_OPTS" | tfuzzel -d -p " 󰛖 Fonts | ")

    if is_back "$F_CHOICE"; then return; fi

    # Helper to apply font
    apply_font() {
        local font_name="$1"
        local font_pkg="$2"
        local font_size="$3"

        # Needs a terminal for sudo; don't switch to a font that isn't there
        if ! tebian_term_apt_install "$font_pkg"; then
            tnotify "Font" "$font_pkg could not be installed — font unchanged"
            return
        fi

        # Sway: a config.user block, which overrides the base config's font
        # line and survives updates. kitty/fuzzel: rewrite their font lines,
        # and record the choice so theme switches keep it (tebian-theme reads
        # ~/.config/tebian/font).
        tebian_block_set font "font pango:$font_name $font_size"
        mkdir -p "$HOME/.config/tebian"
        printf 'FONT_NAME=%q\nFONT_SIZE=%q\n' "$font_name" "$font_size" > "$HOME/.config/tebian/font"
        tebian_apply_app_fonts

        tnotify "Font" "$font_name applied"
        swaymsg reload 2>/dev/null &
    }

    if [[ "$F_CHOICE" =~ "JetBrains Mono" ]]; then
        apply_font "JetBrains Mono" "fonts-jetbrains-mono" "11"
    elif [[ "$F_CHOICE" =~ "Terminus" ]]; then
        # -otb: the OpenType build. Plain fonts-terminus is bitmap-only,
        # which pango and kitty can't use
        apply_font "Terminus" "fonts-terminus-otb" "12"
    elif [[ "$F_CHOICE" =~ "Inter" ]]; then
        apply_font "Inter" "fonts-inter" "11"
    elif [[ "$F_CHOICE" =~ "Hack" ]]; then
        apply_font "Hack" "fonts-hack" "11"
    fi
    done
}

