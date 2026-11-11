# shellcheck shell=bash
# tebian-settings module: theme.sh
# Sourced by tebian-settings — do not run directly

theme_menu() {
    while true; do
    # Detect current theme from theme file header (format: "# Nord Theme - ...")
    CURRENT_THEME=$(head -1 "$HOME/.config/sway/theme" 2>/dev/null | sed -n 's/^# \(.*\) Theme.*/\1/p')
    # The mark goes after the name, as in every other Settings list
    _tm() { local name="$1"; local desc="$2"; [[ "${CURRENT_THEME,,}" == "${name,,}" ]] && echo "$name - $desc  ● current" || echo "$name - $desc"; }

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

    [ -n "$T_CHOICE" ] || menu_close
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

# Picked by position (--index): file names are the user's own, and one
# named "Back (2).jpg" was taken for Back, or with an emoji in it, could not
# be matched back in Text Mode (which strips emoji)
custom_wallpaper_menu() {
    WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
    SHIPPED_DIR="${TEBIAN_DIR:-$HOME/Tebian}/assets/wallpapers"
    TARGET_DIR="$HOME/.local/share/backgrounds/tebian"

    mkdir -p "$WALLPAPER_DIR"

    while true; do
        SHIPPED=$(find "$SHIPPED_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort)
        CUSTOM=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) 2>/dev/null | sort)

        # The one in use is a copy, so it is found by content
        local -a rows=("󰷊 Open Wallpaper Folder") files=("")
        local img mark heading list
        for heading in "── Tebian Wallpapers" "── My Wallpapers"; do
            if [ "$heading" = "── Tebian Wallpapers" ]; then list=$SHIPPED; else list=$CUSTOM; fi
            [ -n "$list" ] || continue
            rows+=("$heading"); files+=("")
            while IFS= read -r img; do
                [ -n "$img" ] || continue
                mark=""
                cmp -s "$img" "$TARGET_DIR/default.jpg" && mark="  ● current"
                rows+=("$(basename "$img")$mark"); files+=("$img")
            done <<< "$list"
        done
        rows+=("󰌍 Back"); files+=("")

        local pick
        pick=$(printf '%s\n' "${rows[@]}" | tfuzzel -d --index -p " 󰋩 Wallpaper | ")

        [ -n "$pick" ] || menu_close
        [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -lt ${#rows[@]} ] || continue
        [ "$pick" -eq $((${#rows[@]} - 1)) ] && return

        if [ "$pick" -eq 0 ]; then
            if command -v thunar &>/dev/null; then
                thunar "$WALLPAPER_DIR" &
            elif command -v xdg-open &>/dev/null; then
                xdg-open "$WALLPAPER_DIR" >/dev/null 2>&1 &
            else
                tnotify "Wallpaper" "No file manager installed. Put pictures in ~/Pictures/Wallpapers to list them here."
                continue
            fi
            return
        fi

        # A heading
        SELECTED=${files[$pick]}
        [ -n "$SELECTED" ] || continue

        mkdir -p "$TARGET_DIR"
        if ! cp "$SELECTED" "$TARGET_DIR/default.jpg"; then
            tnotify "Wallpaper" "Could not set $(basename "$SELECTED")"
            continue
        fi
        pkill swaybg 2>/dev/null; sleep 0.1
        setsid -f swaybg -i "$TARGET_DIR/default.jpg" -m fill </dev/null >/dev/null 2>&1
        tnotify "Wallpaper" "Wallpaper set: $(basename "$SELECTED")"
    done
}

feel_menu() {
    while true; do
    # A feel is a bundle of Desktop & UI settings, each of which can be
    # changed on its own afterwards, so the mark goes on the one the
    # desktop matches now (none, once it has been customised) rather than
    # on the one applied last
    local cur m_w="" m_m="" m_t="" m_n=""
    cur=$(feel_current)
    case "$cur" in
        Windows) m_w="  ● current" ;;
        macOS)   m_m="  ● current" ;;
        Tiling)  m_t="  ● current" ;;
        Minimal) m_n="  ● current" ;;
    esac

    FEEL_OPTS="󰍹 Windows - Floating, bar bottom, title bars$m_w
 macOS - Floating, bar top, title bars$m_m
󰕰 Tiling - Tiling, bar auto-hide, no title bars$m_t
󰆌 Minimal - Tiling, no bar, no title bars, no gaps$m_n
󰌍 Back"

    F_CHOICE=$(echo "$FEEL_OPTS" | tfuzzel -d -p " 󰇄 Desktop Feel | " --width 52)

    [ -n "$F_CHOICE" ] || menu_close
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

# The feel the desktop matches right now, or nothing
feel_current() {
    local float=0 titles=0 pos mode gaps
    tebian_block_has floating-mode && float=1
    tebian_block_has titlebars && titles=1
    pos=$(bar_get position); mode=$(bar_get mode)
    gaps=$(tebian_block_get gaps 2>/dev/null | awk '$1 == "gaps" && $2 == "inner" { print $3; exit }')
    # Gaps only tell Minimal (none) from the rest (the feel's, or the theme's)
    [ "$gaps" = 0 ] || gaps=some
    case "$float:$titles:${pos:-top}:${mode:-dock}:$gaps" in
        1:1:bottom:dock:some) echo Windows ;;
        1:1:top:dock:some)    echo macOS ;;
        0:0:top:hide:some)    echo Tiling ;;
        0:0:top:invisible:0)  echo Minimal ;;
    esac
}

apply_feel() {
    local FEEL="$1"
    mkdir -p "$HOME/.config/tebian" "$HOME/.config/sway"

    # --- Floating mode ---
    if [[ "$FEEL" == "Windows" || "$FEEL" == "macOS" ]]; then
        setup_floating_mode
        swaymsg '[app_id=".*"] floating enable' >/dev/null 2>&1
        swaymsg '[class=".*"] floating enable' >/dev/null 2>&1
    else
        remove_floating_mode
        swaymsg '[app_id=".*"] floating disable' >/dev/null 2>&1
        swaymsg '[class=".*"] floating disable' >/dev/null 2>&1
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
    # titlebars_set (ui.sh) also changes the windows already open; setting
    # only the default left them with the old feel's borders
    if [[ "$FEEL" == "Windows" || "$FEEL" == "macOS" ]]; then
        titlebars_set on
    else
        titlebars_set off
    fi

    # --- Gaps ---
    if [[ "$FEEL" == "Minimal" ]]; then
        tebian_block_set gaps "gaps inner 0" "gaps outer 0"
    else
        tebian_block_set gaps "gaps inner 4" "gaps outer 0"
    fi

    tnotify "Desktop Feel" "$FEEL applied"
    swaymsg reload >/dev/null 2>&1 &
}

font_menu() {
    while true; do
    # The choice saved by apply_font; none yet is the default (JetBrains)
    # shellcheck disable=SC2034  # FONT_SIZE: set by the file, kept local
    local FONT_NAME="" FONT_SIZE="" m_j="" m_t="" m_i="" m_h=""
    # shellcheck disable=SC1090
    [ -f "$HOME/.config/tebian/font" ] && . "$HOME/.config/tebian/font"
    case "${FONT_NAME:-JetBrains Mono}" in
        "JetBrains Mono") m_j="  ● current" ;;
        Terminus)         m_t="  ● current" ;;
        Inter)            m_i="  ● current" ;;
        Hack)             m_h="  ● current" ;;
    esac

    # Where it applies is in the prompt: as a row of its own it looked
    # like a choice and did nothing when picked
    F_OPTS="󰛖 JetBrains Mono (Default/Code)$m_j
󰛖 Terminus (Retro/Pixel)$m_t
󰛖 Inter (Modern/Clean)$m_i
󰛖 Hack (Classic Terminal)$m_h
󰌍 Back"

    F_CHOICE=$(echo "$F_OPTS" | tfuzzel -d -p " 󰛖 Font (desktop, terminal, menus) | " --width 50)

    [ -n "$F_CHOICE" ] || menu_close
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

        tnotify "Font" "Font set: $font_name"
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

