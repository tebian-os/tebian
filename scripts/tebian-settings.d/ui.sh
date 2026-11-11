# shellcheck shell=bash
# tebian-settings module: ui.sh
# Sourced by tebian-settings — do not run directly

# Desktop & UI. One line per setting, its state in brackets: (ON)/(OFF) for
# switches, (Current: X) for a choice. Ordered bar, then windows, then look,
# so related settings sit together.
ui_menu() {
    while true; do
    local bar_mode bar_pos modern=0 w_state w_place
    local STYLE_LABEL POS_LABEL VIS_LABEL CLOCK_LABEL STATS_LABEL WEATHER_LABEL
    local DOCK_LABEL LAYOUT_LABEL TITLE_LABEL SNAP_LABEL FX_LABEL ICON_LABEL

    # Bar style: Modern (Waybar: hover buttons, drop-down menus) or Classic
    if tebian_block_has bar-style; then
        modern=1
        STYLE_LABEL="󰕮 Bar Style (Current: Modern)"
    else
        STYLE_LABEL="󰕮 Bar Style (Current: Classic)"
    fi

    bar_pos=$(bar_get position)
    if [ "$bar_pos" = bottom ]; then
        POS_LABEL="󰞒 Bar Position (Current: Bottom)"
    else
        POS_LABEL="󰞑 Bar Position (Current: Top)"
    fi

    bar_mode=$(bar_get mode)
    case "$bar_mode" in
        hide)      VIS_LABEL="󰆪 Bar Visibility (Current: Auto-hide)" ;;
        invisible) VIS_LABEL="󰆪 Bar Visibility (Current: Hidden)" ;;
        *)         VIS_LABEL="󰆪 Bar Visibility (Current: Always Shown)" ;;
    esac

    if [ -f "$HOME/.config/tebian/clock-12h" ]; then
        CLOCK_LABEL="󰥔 Clock (Current: 12-hour)"
    else
        CLOCK_LABEL="󰥔 Clock (Current: 24-hour)"
    fi

    if [ -f "$HOME/.config/tebian/bar_perf_off" ]; then
        STATS_LABEL="󰍛 Bar Stats (OFF)"
    else
        STATS_LABEL="󰍛 Bar Stats (ON)"
    fi

    # Weather is a Modern bar module (tebian-weather; off until a place is
    # set). The Classic bar has nowhere to show it, and says so rather than
    # offering a switch that changes nothing.
    IFS=$'\t' read -r w_state w_place < <(tebian-weather status 2>/dev/null)
    if [ "$modern" = 0 ]; then
        WEATHER_LABEL="󰖐 Weather in Bar (Modern Bar Only)"
    elif [ "$w_state" = on ]; then
        WEATHER_LABEL="󰖐 Weather in Bar (ON: $w_place)"
    else
        WEATHER_LABEL="󰖐 Weather in Bar (OFF)"
    fi

    if tebian-dock status >/dev/null 2>&1; then
        DOCK_LABEL="󰀻 Dock (ON)"
    else
        DOCK_LABEL="󰀻 Dock (OFF)"
    fi

    if tebian_block_has floating-mode; then
        LAYOUT_LABEL="󰖲 Window Layout (Current: Floating)"
    else
        LAYOUT_LABEL="󰕰 Window Layout (Current: Tiling)"
    fi

    # Title bars (the theme sets pixel 2 = OFF by default)
    if tebian_block_has titlebars; then
        TITLE_LABEL="󰘖 Title Bars (ON)"
    else
        TITLE_LABEL="󰘕 Title Bars (OFF)"
    fi

    # Window snapping: drag a floating window to an edge or corner. Built
    # into Tebian's sway (and patched SwayFX); on by default there, so only
    # "off" is written down. Shown in tiling mode too: dialogs float. A
    # build from before thirds and Snap Assist says an update is waiting.
    if ! tebian_snap_supported; then
        SNAP_LABEL="󰖲 Window Snapping (Not Installed)"
    elif tebian_block_has snap-off; then
        SNAP_LABEL="󰖳 Window Snapping (OFF)"
    elif tebian_snap_rev2; then
        SNAP_LABEL="󰖲 Window Snapping (ON)"
    else
        SNAP_LABEL="󰖲 Window Snapping (ON, Update Available)"
    fi

    # Window effects (SwayFX)
    if [ ! -f "$HOME/.config/tebian/swayfx-installed" ]; then
        FX_LABEL="󰂵 Window Effects (Not Installed)"
    elif [ "$(fx_get blur)" = enable ]; then
        FX_LABEL="󰂵 Window Effects (ON)"
    else
        FX_LABEL="󰂵 Window Effects (OFF)"
    fi

    if [ -f "$HOME/.config/tebian/no_icons" ]; then
        ICON_LABEL="󰇄 Menu Icons (OFF)"
    else
        ICON_LABEL="󰇄 Menu Icons (ON)"
    fi

    U_CHOICE=$(printf '%s\n' "$STYLE_LABEL" "$POS_LABEL" "$VIS_LABEL" "$CLOCK_LABEL" \
        "$STATS_LABEL" "$WEATHER_LABEL" "$DOCK_LABEL" "$LAYOUT_LABEL" "$TITLE_LABEL" \
        "$SNAP_LABEL" "$FX_LABEL" "$ICON_LABEL" "󰛖 Font Rendering" \
        "󰌌 Keyboard Shortcuts" "󰌍 Back" | tfuzzel -d -p " 󰇄 Desktop & UI | " --width 44)

    [ -n "$U_CHOICE" ] || menu_close
    if is_back "$U_CHOICE"; then return; fi

    # Matched on the words: Text Mode strips the icons
    case "$U_CHOICE" in
        *"Bar Style"*)      bar_style_toggle ;;
        *"Bar Position"*)
            if [ "$bar_pos" = bottom ]; then
                bar_set_position top
                tnotify "UI" "Bar moved to the top"
            else
                bar_set_position bottom
                tnotify "UI" "Bar moved to the bottom"
            fi ;;
        *"Bar Visibility"*) bar_visibility_menu ;;
        *"Clock ("*)        clock_format_toggle ;;
        *"Bar Stats"*)      bar_stats_toggle ;;
        *"Weather in Bar"*)
            if [ "$modern" = 1 ]; then
                weather_menu
            else
                tnotify "Weather" "Weather shows in the Modern bar — switch Bar Style to Modern first"
            fi ;;
        *"Dock ("*)         dock_menu ;;
        *"Window Layout"*)  window_layout_toggle ;;
        *"Title Bars"*)
            if tebian_block_has titlebars; then
                titlebars_set off
                tnotify "UI" "Title bars off"
            else
                titlebars_set on
                tnotify "UI" "Title bars on"
            fi ;;
        *"Window Snapping"*) window_snapping_menu ;;
        *"Window Effects"*"Not Installed"*) window_effects_install ;;
        *"Window Effects"*) window_effects_menu ;;
        *"Menu Icons"*)     ui_icons_toggle ;;
        *"Font Rendering"*) font_rendering_menu ;;
        *"Keyboard Shortcuts"*) keybinds_list ;;
    esac
    done
}

# One bar setting, mode or position. The config.user block is the truth: it
# is written at once, while sway applies the change a moment later, so asking
# sway straight after a change still gave the old answer. Sway is asked only
# when nothing was ever chosen.
bar_get() {
    local v
    v=$(tebian_block_get "bar-$1" 2>/dev/null | awk '$1 == "bar" { print $4; exit }')
    [ -n "$v" ] || v=$(swaymsg -r -t get_bar_config bar-0 2>/dev/null |
        sed -n "s/.*\"$1\": *\"\([a-z]*\)\".*/\1/p" | head -1)
    echo "$v"
}

# Always shown, shown while Super is held, or gone. Three states, so a list
# rather than a switch (Desktop Feel's Minimal uses the third).
bar_visibility_menu() {
    local cur V m_dock="" m_hide="" m_inv=""
    cur=$(bar_get mode)
    case "$cur" in
        hide)      m_hide="  ● current" ;;
        invisible) m_inv="  ● current" ;;
        *)         m_dock="  ● current" ;;
    esac
    V=$(printf '%s\n' "󰆪 Always Shown$m_dock" "󰆪 Auto-hide: shows while Super is held$m_hide" \
        "󰆪 Hidden: no bar at all$m_inv" "󰌍 Back" | tfuzzel -d -p " 󰆪 Bar Visibility | ")
    [ -n "$V" ] || menu_close
    case "$V" in
        *"Always Shown"*) bar_set_mode dock;      tnotify "UI" "Bar always shown" ;;
        *"Auto-hide"*)    bar_set_mode hide;      tnotify "UI" "Bar auto-hides — hold Super to see it" ;;
        *"Hidden"*)       bar_set_mode invisible; tnotify "UI" "Bar hidden — Settings (Super+S) brings it back" ;;
    esac
}

# Floating (windows open free, like Windows or macOS) or tiling (windows
# share the screen)
window_layout_toggle() {
    if tebian_block_has floating-mode; then
        remove_floating_mode
        swaymsg '[app_id=".*"] floating disable' >/dev/null 2>&1
        swaymsg '[class=".*"] floating disable' >/dev/null 2>&1
        tnotify "UI" "Tiling windows"
        swaymsg reload >/dev/null 2>&1 &
    else
        setup_floating_mode
        tnotify "UI" "Floating windows"
        # for_window rules only reach windows opened later; convert the open
        # ones too, or tiled and floating windows end up mixed together
        ( swaymsg reload && swaymsg '[tiling] floating enable' ) >/dev/null 2>&1 &
    fi
}

# titlebars_set on|off — for windows opened from now on (the config.user
# block, which beats the theme's pixel 2) and for the ones already open,
# which keep whatever border they were given when they appeared
titlebars_set() {
    local b="pixel 2"
    if [ "$1" = on ]; then
        b="normal 2"
        tebian_block_set titlebars "${TEBIAN_TITLEBAR_LINES[@]}"
    else
        tebian_block_remove titlebars
    fi
    swaymsg "default_border $b" >/dev/null 2>&1
    swaymsg "default_floating_border $b" >/dev/null 2>&1
    swaymsg "[app_id=\".*\"] border $b" >/dev/null 2>&1
    swaymsg "[class=\".*\"] border $b" >/dev/null 2>&1
}

# Snapping itself, Snap Assist, and the rebuild that brings a build from
# before thirds and Snap Assist up to date. tebian-update points here when
# SwayFX needs rebuilding, so the rebuild has to be reachable while
# snapping is on, not only when it is missing.
window_snapping_menu() {
    local S_CHOICE
    while true; do
        if ! tebian_snap_supported; then
            window_snapping_install
            return
        fi
        local -a opts=()
        if tebian_block_has snap-off; then
            opts+=("󰖳 Snapping (OFF)")
        else
            opts+=("󰖲 Snapping (ON): drag a window to an edge or corner")
        fi
        if tebian_snap_rev2; then
            if tebian_snap_assist_enabled; then
                opts+=("󰖲 Snap Assist (ON): offers a window for the other half")
            else
                opts+=("󰖳 Snap Assist (OFF)")
            fi
        else
            opts+=("󰚰 Update Snapping (adds thirds and Snap Assist)")
        fi
        opts+=("󰌍 Back")
        S_CHOICE=$(printf '%s\n' "${opts[@]}" | tfuzzel -d -p " 󰖲 Window Snapping | " --width 52)
        [ -n "$S_CHOICE" ] || menu_close
        is_back "$S_CHOICE" && return
        case "$S_CHOICE" in
            # First: its label mentions Snap Assist too
            *"Update Snapping"*) window_snapping_install ;;
            *"Snap Assist"*)     snap_assist_toggle ;;
            *"Snapping (ON)"*)
                tebian_block_set snap-off "floating_snap disable"
                swaymsg floating_snap disable >/dev/null 2>&1
                tnotify "UI" "Window snapping off" ;;
            *"Snapping (OFF)"*)
                tebian_block_remove snap-off
                swaymsg floating_snap enable >/dev/null 2>&1
                tnotify "UI" "Window snapping on" ;;
        esac
    done
}

# Text Mode: menus without icons (tfuzzel strips them when this file exists)
ui_icons_toggle() {
    if [ -f "$HOME/.config/tebian/no_icons" ]; then
        rm -f "$HOME/.config/tebian/no_icons"
        tnotify "UI" "Menu icons on"
    else
        mkdir -p "$HOME/.config/tebian"
        touch "$HOME/.config/tebian/no_icons"
        tnotify "UI" "Menu icons off (Text Mode)"
    fi
}

bar_style_toggle() {
    if tebian_block_has bar-style; then
        bar_style_set classic
    else
        bar_style_set modern
    fi
}

# The bar's clock, 12- or 24-hour. Also reached from System > Date & Time.
clock_format_toggle() {
    mkdir -p "$HOME/.config/tebian"
    if [ -f "$HOME/.config/tebian/clock-12h" ]; then
        rm -f "$HOME/.config/tebian/clock-12h"
        tnotify "Clock" "24-hour clock"
    else
        touch "$HOME/.config/tebian/clock-12h"
        tnotify "Clock" "12-hour clock"
    fi
    # The bar reads it at start; sway restarts the bar on reload
    swaymsg reload >/dev/null 2>&1 &
}

# Weather in the Modern bar: set a place when it's off, change or stop it
# when it's on
weather_menu() {
    local w_state W_CHOICE
    IFS=$'\t' read -r w_state _ < <(tebian-weather status 2>/dev/null)
    if [ "$w_state" != on ]; then
        tebian-weather setup
        return
    fi
    W_CHOICE=$(echo -e "󰖐 Change Place\n󰖪 Turn Off Weather\n󰌍 Back" | tfuzzel -d -p " 󰖐 Weather | ")
    [ -n "$W_CHOICE" ] || menu_close
    if [[ "$W_CHOICE" =~ "Change Place" ]]; then
        tebian-weather setup
    elif [[ "$W_CHOICE" =~ "Turn Off" ]]; then
        tebian-weather off
        tnotify "Weather" "Off — nothing is fetched any more"
    fi
}

# A reference list (the key helper, Super+Shift+?, runs things). Snapping
# keys are listed only when they are bound: floating mode writes them, and
# an older sway build has halves but no thirds.
keybinds_list() {
    local snap="" c
    if grep -q '^bindsym \$mod+Ctrl+Left snap left' "$HOME/.config/sway/config.user" 2>/dev/null; then
        if tebian_snap_rev2; then
            snap="Super+Ctrl+Left/Right ··· Snap Window: half, third, two thirds
Super+Ctrl+Up/Down ··· Maximize or Top Quarter / Restore or Bottom Quarter
Super+Ctrl+Return / BackSpace ··· Maximize / Restore Window
Super+Ctrl+1 2 3 ··· Snap to Left / Middle / Right Third
Super+Ctrl+Shift+Left/Right ··· Move Window to Other Monitor
"
        else
            snap="Super+Ctrl+Left/Right ··· Snap Window to Half
Super+Ctrl+Up/Down ··· Maximize / Restore Window
"
        fi
    fi
    local lock=""
    grep -q "bindsym.*exec gtklock" "$HOME/.config/sway/config.user" 2>/dev/null &&
        lock="Super+L ··· Lock Screen
"
    local cu="$HOME/.config/sway/config.user" ws="" wsmenu=""
    grep -q '^bindsym \$mod+Tab ' "$cu" 2>/dev/null && ws="Super+Tab ··· Switch Workspace
"
    grep -q '^bindsym \$mod+Alt+Left ' "$cu" 2>/dev/null && ws+="Super+Alt+Left/Right ··· Previous/Next Workspace
"
    grep -q '^bindsym \$mod+w ' "$cu" 2>/dev/null && wsmenu="Super+W ··· Workspace Menu
"
    local KEY_LIST="Super+D ··· App Launcher
Super+A ··· All Apps (Drawer)
Super+S ··· Settings
Super+Return ··· Terminal
Super+Shift+Q ··· Close Window
Super+F ··· Fullscreen
Super+Space ··· Toggle Float/Tile
${snap}Super+R ··· Resize Mode
Super+Arrows ··· Move Focus
Super+Shift+Arrows ··· Move Window
Super+Shift+Tab ··· Switch Window
${lock}${ws}Super+1-9 ··· Go to Workspace
Super+Shift+1-9 ··· Move Window to Workspace
${wsmenu}Super+V ··· Clipboard History
Super+. ··· Emoji Picker
Print ··· Screenshot (Region)
Shift+Print ··· Screenshot (Full)
Super+Print ··· Capture Menu (record, copy text, QR)
Ctrl+Print ··· Record Screen (again to stop)
Super+Shift+? ··· Key Helper
Super+Shift+E ··· Log Out (Exit Sway)
󰌍 Back"
    c=$(echo "$KEY_LIST" | tfuzzel -d -p " 󰌌 Keyboard Shortcuts | " --width 64)
    [ -n "$c" ] || menu_close
}

input_device_menu() {
    while true; do
    # Get touchpad identifier
    TOUCHPAD_ID=$(swaymsg -t get_inputs 2>/dev/null | python3 -c "
import json, sys
try:
    for i in json.load(sys.stdin):
        if i.get('type') == 'touchpad':
            print(i['identifier']); break
except: pass
" 2>/dev/null)

    # Get current touchpad settings
    if [ -n "$TOUCHPAD_ID" ]; then
        TAP_STATE=$(swaymsg -t get_inputs 2>/dev/null | python3 -c "
import json, sys
for i in json.load(sys.stdin):
    if i.get('identifier') == '$TOUCHPAD_ID':
        lp = i.get('libinput', {})
        tap = lp.get('tap', 'disabled')
        nscroll = lp.get('natural_scroll', 'disabled')
        print(f'{tap}|{nscroll}')
        break
" 2>/dev/null)
        TAP=$(echo "$TAP_STATE" | cut -d'|' -f1)
        NSCROLL=$(echo "$TAP_STATE" | cut -d'|' -f2)
        [ "$TAP" = "enabled" ] && TAP_LABEL="Tap to Click (ON)" || TAP_LABEL="Tap to Click (OFF)"
        [ "$NSCROLL" = "enabled" ] && NSCROLL_LABEL="Natural Scroll (ON)" || NSCROLL_LABEL="Natural Scroll (OFF)"
        INPUT_OPTS="󰍽 $TAP_LABEL
󰍽 $NSCROLL_LABEL
󰍽 Scroll Speed"
    else
        INPUT_OPTS="(No touchpad detected)"
    fi

    INPUT_OPTS="$INPUT_OPTS
󰌌 Keyboard Layout
󰌌 Emoji Picker (Super+.)
󰍽 Mouse Speed
󰌍 Back"

    I_CHOICE=$(echo -e "$INPUT_OPTS" | tfuzzel -d -p " 󰍽 Input | ")
    [ -n "$I_CHOICE" ] || menu_close
    if is_back "$I_CHOICE"; then return; fi

    SWAY_CFG="$HOME/.config/sway/config.user"

    if [[ "$I_CHOICE" =~ "Tap to Click" ]]; then
        sed -i '/input type:touchpad.*tap /d' "$SWAY_CFG" 2>/dev/null
        if [[ "$TAP" = "enabled" ]]; then
            swaymsg "input type:touchpad tap disabled"
            echo 'input type:touchpad tap disabled' >> "$SWAY_CFG"
            tnotify "Input" "Tap to Click disabled"
        else
            swaymsg "input type:touchpad tap enabled"
            echo 'input type:touchpad tap enabled' >> "$SWAY_CFG"
            tnotify "Input" "Tap to Click enabled"
        fi
    elif [[ "$I_CHOICE" =~ "Natural Scroll" ]]; then
        sed -i '/input type:touchpad.*natural_scroll /d' "$SWAY_CFG" 2>/dev/null
        if [[ "$NSCROLL" = "enabled" ]]; then
            swaymsg "input type:touchpad natural_scroll disabled"
            echo 'input type:touchpad natural_scroll disabled' >> "$SWAY_CFG"
            tnotify "Input" "Natural Scroll disabled"
        else
            swaymsg "input type:touchpad natural_scroll enabled"
            echo 'input type:touchpad natural_scroll enabled' >> "$SWAY_CFG"
            tnotify "Input" "Natural Scroll enabled"
        fi
    elif [[ "$I_CHOICE" =~ "Scroll Speed" ]]; then
        scroll_speed_menu
    elif [[ "$I_CHOICE" =~ "Keyboard Layout" ]]; then
        keyboard_layout_menu
    elif [[ "$I_CHOICE" =~ "Emoji Picker" ]]; then
        capture_emoji
    elif [[ "$I_CHOICE" =~ "Mouse Speed" ]]; then
        mouse_speed_menu
    fi
    done
}

scroll_speed_menu() {
    local SWAY_CFG="$HOME/.config/sway/config.user" SPEED_OPTS SP FACTOR
    SPEED_OPTS="Slow (0.5x)
Normal (1x)
Fast (2x)
󰌍 Back"
    SP=$(echo -e "$SPEED_OPTS" | tfuzzel -d -p " Scroll Speed | ")
    [ -n "$SP" ] || menu_close
    case "$SP" in
        *Slow*) FACTOR="0.5" ;;
        *Normal*) FACTOR="1.0" ;;
        *Fast*) FACTOR="2.0" ;;
        *) return ;;
    esac
    swaymsg "input type:touchpad scroll_factor $FACTOR"
    sed -i '/input type:touchpad.*scroll_factor/d' "$SWAY_CFG" 2>/dev/null
    echo "input type:touchpad scroll_factor $FACTOR" >> "$SWAY_CFG"
    tnotify "Input" "Scroll speed set to $FACTOR"
}

mouse_speed_menu() {
    local SWAY_CFG="$HOME/.config/sway/config.user" SPEED_OPTS MS ACCEL
    SPEED_OPTS="Slow (-0.5)
Normal (0)
Fast (0.5)
󰌍 Back"
    MS=$(echo -e "$SPEED_OPTS" | tfuzzel -d -p " Mouse Speed | ")
    [ -n "$MS" ] || menu_close
    case "$MS" in
        *Slow*) ACCEL="-0.5" ;;
        *Normal*) ACCEL="0" ;;
        *Fast*) ACCEL="0.5" ;;
        *) return ;;
    esac
    swaymsg "input type:pointer pointer_accel $ACCEL"
    sed -i '/input type:pointer.*pointer_accel/d' "$SWAY_CFG" 2>/dev/null
    echo "input type:pointer pointer_accel $ACCEL" >> "$SWAY_CFG"
    tnotify "Input" "Mouse speed set to $ACCEL"
}

# Every layout xkeyboard-config knows, "code - Name", sorted by name. Without
# its rules file (a stripped system) the old short list still works.
kb_layout_list() {
    local lst="${TEBIAN_XKB_RULES:-/usr/share/X11/xkb/rules/base.lst}"
    if [ -r "$lst" ]; then
        awk '/^! / { sec = $2; next }
             sec == "layout" && NF >= 2 { c = $1; sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+/, ""); print $0 "\t" c }' "$lst" |
            sort -f | awk -F'\t' '{ print $2 " - " $1 }'
    else
        printf '%s\n' "us - English (US)" "gb - English (UK)" "de - German" "fr - French" \
            "es - Spanish" "it - Italian" "pt - Portuguese" "ru - Russian" "jp - Japanese" "kr - Korean"
    fi
}

# The variants of one layout, "code - Name", in the rules file's order
# (lines there read "  nodeadkeys  de: German (no dead keys)")
kb_variant_list() {
    local lst="${TEBIAN_XKB_RULES:-/usr/share/X11/xkb/rules/base.lst}"
    [ -r "$lst" ] || return 0
    awk -v lay="$1" '/^! / { sec = $2; next }
        sec == "variant" && $2 == lay ":" { c = $1; sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+/, ""); print c " - " $0 }' "$lst"
}

# One "X11 <field>:" value from localectl status. Only the label is cut
# off: values hold colons of their own (Options: compose:ralt)
kb_x11_field() {
    localectl status 2>/dev/null |
        awk -v f="X11 $1:" '{ sub(/^[[:space:]]+/, "") } index($0, f) == 1 { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }'
}

keyboard_layout_menu() {
    local SWAY_CFG="$HOME/.config/sway/config.user"
    local cur cur_var
    cur=$(sed -n 's/^input type:keyboard xkb_layout //p' "$SWAY_CFG" 2>/dev/null | tail -1)
    cur_var=$(sed -n 's/^input type:keyboard xkb_variant //p' "$SWAY_CFG" 2>/dev/null | tail -1)
    [ -n "$cur" ] || cur=$(kb_x11_field Layout)

    local list KB
    list=$(kb_layout_list)
    KB=$({
        echo "󰌍 Back"
        awk -v c="${cur:-us}" '$1 == c { print $0 " (current)"; exit }' <<< "$list"
        awk -v c="${cur:-us}" '$1 != c' <<< "$list"
    } | tfuzzel -d -p " 󰌌 Keyboard Layout (type a language) | " --width 60)
    [ -n "$KB" ] || menu_close
    if is_back "$KB"; then return; fi
    local LAYOUT="${KB%% *}"
    # It goes into sway's config and localectl's arguments: only a name
    # from the list
    if ! awk -v l="$LAYOUT" '$1 == l { f = 1 } END { exit !f }' <<< "$list"; then
        tnotify "Input" "Not a keyboard layout: $LAYOUT"
        return
    fi

    # Variants (no dead keys, Dvorak, ...) as a second step, the plain
    # layout first; Escape here leaves everything as it was
    local VARIANT="" vlist V
    vlist=$(kb_variant_list "$LAYOUT")
    if [ -n "$vlist" ]; then
        local name="${KB#* - }"
        name="${name% (current)}"
        local mark="//"
        [ "$LAYOUT" = "$cur" ] && mark="${cur_var:-default}"
        V=$({
            echo "default - $name"
            echo "$vlist"
            echo "󰌍 Back"
        } | awk -v m="$mark" '$1 == m { $0 = $0 " (current)" } 1' | tfuzzel -d -p " 󰌌 $name: variant | " --width 60)
        if [ -z "$V" ] || is_back "$V"; then return; fi
        VARIANT="${V%% *}"
        [ "$VARIANT" = default ] && VARIANT=""
        if [ -n "$VARIANT" ] && ! awk -v v="$VARIANT" '$1 == v { f = 1 } END { exit !f }' <<< "$vlist"; then
            tnotify "Input" "Not a variant of $LAYOUT: $VARIANT"
            return
        fi
    fi

    # A variant belongs to its layout: one left over from the previous
    # layout makes the keymap fail to compile, so it is always rewritten
    swaymsg "input type:keyboard xkb_layout $LAYOUT" >/dev/null 2>&1
    swaymsg "input type:keyboard xkb_variant \"$VARIANT\"" >/dev/null 2>&1
    sed -i '/input type:keyboard.*xkb_layout/d; /input type:keyboard.*xkb_variant/d' "$SWAY_CFG" 2>/dev/null
    echo "input type:keyboard xkb_layout $LAYOUT" >> "$SWAY_CFG"
    [ -n "$VARIANT" ] && echo "input type:keyboard xkb_variant $VARIANT" >> "$SWAY_CFG"

    # The login screen (greetd exports it to sway) and the consoles read
    # /etc/default/keyboard; localed writes it, asking through the polkit
    # agent (sysprefs.sh falls back to sudo in a terminal when none runs).
    # Model and options are passed back as they are: set-x11-keymap clears
    # whatever it isn't given.
    local model options
    model=$(kb_x11_field Model)
    options=$(kb_x11_field Options)
    sysprefs_privileged localectl set-x11-keymap "$LAYOUT" "$model" "$VARIANT" "$options"
    local now_lay now_var
    now_lay=$(kb_x11_field Layout)
    now_var=$(kb_x11_field Variant)
    if [ "$now_lay" != "$LAYOUT" ] || [ "$now_var" != "$VARIANT" ]; then
        tnotify "Input" "Login screen keeps its old layout (couldn't update /etc/default/keyboard${SYSPREFS_ERR:+: $SYSPREFS_ERR})"
    fi
    tnotify "Input" "Keyboard layout set to $LAYOUT${VARIANT:+ ($VARIANT)}"
}

# Bar settings persist as config.user blocks: sway applies
# `bar bar-0 <option>` after the bar {} block, and unlike the main config,
# config.user survives updates and rebuilds
bar_set_mode() {
    swaymsg "bar bar-0 mode $1" >/dev/null 2>&1 &
    tebian_block_set bar-mode "bar bar-0 mode $1"
}

# Modern = Waybar through tebian-bar, set as sway's swaybar_command. Classic
# = sway's own swaybar + status.sh (the lean default, and Base mode's bar).
# tebian-bar itself falls back to swaybar if Waybar ever goes missing.
bar_style_set() {
    if [ "$1" = modern ]; then
        # Install first; only switch once Waybar is really there
        # upower feeds the Power panel's battery details (optional extra)
        tebian_term_apt_install waybar upower || return
        # Quickshell draws the rich panels (WiFi so far). Optional: without
        # it the bar's menus fall back to fuzzel drop-downs.
        command -v quickshell >/dev/null || tebian_install_quickshell
        tebian_block_set bar-style "bar bar-0 swaybar_command $HOME/.local/bin/tebian-bar"
        tnotify "UI" "Modern bar on — hover the icons, click for menus"
    else
        tebian_block_remove bar-style
        tnotify "UI" "Classic bar on"
    fi
    # The bar process is replaced on reload
    swaymsg reload >/dev/null 2>&1 &
}

bar_set_position() {
    swaymsg "bar bar-0 position $1" >/dev/null 2>&1 &
    tebian_block_set bar-position "bar bar-0 position $1"
    # wob sits opposite the bar
    local anchor="bottom center"
    [ "$1" = bottom ] && anchor="top center"
    sed -i "s/^anchor = .*/anchor = $anchor/" "$HOME/.config/wob/wob.ini" 2>/dev/null
    pkill -x wob 2>/dev/null   # sway's exec_always line restarts it on reload
    swaymsg reload >/dev/null 2>&1 &
}

# Snapping lives in the compositor, so "installing" it means Tebian's build
# of whichever sway this machine runs: SwayFX if it's installed (rebuilt
# with the patch), otherwise Debian's sway (rebuilt the same way)
window_snapping_install() {
    local what cmd
    if [ -f "$HOME/.config/tebian/swayfx-installed" ]; then
        what="󰖲 Rebuild SwayFX with snapping (about 5 minutes)"
        cmd="tebian-install-swayfx"
    else
        what="󰖲 Build sway with snapping (a few minutes)"
        cmd="tebian-build-sway --install --clean"
    fi
    INSTALL_CHOICE=$(echo -e "$what\n󰌍 Back" | tfuzzel -d -p " 󰖲 Snapping | ")
    if [[ "$INSTALL_CHOICE" =~ "Build" ]] || [[ "$INSTALL_CHOICE" =~ "Rebuild" ]]; then
        $TERM_CMD bash -c "$cmd; echo ''; echo 'Log out and back in to start using it.'; read -p 'Press Enter to close...'"
    fi
}

window_effects_install() {
    INSTALL_CHOICE=$(echo -e "󰖲 Install SwayFX (build from source, ~5 min)\n󰌍 Back" | tfuzzel -d -p " 󰖲 Effects | ")
    if [[ "$INSTALL_CHOICE" =~ "Install" ]]; then
        $TERM_CMD bash -c "tebian-install-swayfx; echo ''; read -p 'Press Enter to close...'"
    fi
}

# SwayFX settings live in the "swayfx" block of config.user. Values are read
# back from it, and every change rewrites the whole block from them.
fx_get() {
    tebian_block_get swayfx | awk -v k="$1" '$1 == k { print $2; exit }'
}

fx_write() {
    local blur="$1" passes="$2" radius="$3" corner="$4" shadows="$5" shadow_r="$6" dim="$7"
    tebian_block_set swayfx \
        "blur $blur" \
        "blur_xray off" \
        "blur_passes $passes" \
        "blur_radius $radius" \
        "corner_radius $corner" \
        "shadows $shadows" \
        "shadow_blur_radius $shadow_r" \
        "default_dim_inactive $dim"
    swaymsg reload 2>/dev/null &
}

window_effects_menu() {
    while true; do
    local cur_blur cur_passes cur_radius cur_corner cur_shadows cur_shadow cur_dim
    cur_blur=$(fx_get blur)
    cur_passes=$(fx_get blur_passes)
    cur_radius=$(fx_get blur_radius)
    cur_corner=$(fx_get corner_radius)
    cur_shadows=$(fx_get shadows)
    cur_shadow=$(fx_get shadow_blur_radius)
    cur_dim=$(fx_get default_dim_inactive)
    : "${cur_blur:=enable}" "${cur_passes:=2}" "${cur_radius:=5}" "${cur_corner:=8}" \
      "${cur_shadows:=enable}" "${cur_shadow:=20}" "${cur_dim:=0.1}"

    if [ "$cur_blur" = enable ]; then
        TOGGLE_LABEL="󰂵 Window Effects (ON)"
    else
        TOGGLE_LABEL="󰂵 Window Effects (OFF)"
    fi

    FX_OPTS="$TOGGLE_LABEL
󰂵 Blur Strength (passes: $cur_passes, radius: $cur_radius)
󰘖 Corner Radius ($cur_corner)
󰘚 Shadows (radius: $cur_shadow)
󰌁 Dim Inactive ($cur_dim)
󰌍 Back"

    FX_CHOICE=$(echo -e "$FX_OPTS" | tfuzzel -d -p " 󰖲 Effects | ")

    [ -n "$FX_CHOICE" ] || menu_close
    if is_back "$FX_CHOICE"; then return; fi

    if [[ "$FX_CHOICE" =~ "Window Effects" ]]; then
        if [ "$cur_blur" = enable ]; then
            # Disabling zeroes corners and dim; remember them so re-enabling
            # restores the user's values rather than the defaults
            mkdir -p "$HOME/.config/tebian"
            printf 'corner=%s\ndim=%s\n' "$cur_corner" "$cur_dim" > "$HOME/.config/tebian/fx-saved"
            fx_write disable "$cur_passes" "$cur_radius" 0 disable "$cur_shadow" 0
            tnotify "Effects" "Window effects off"
        else
            local saved
            if [ -f "$HOME/.config/tebian/fx-saved" ]; then
                saved=$(sed -n 's/^corner=//p' "$HOME/.config/tebian/fx-saved" | head -1)
                [ -n "$saved" ] && [ "$saved" != "0" ] && cur_corner="$saved"
                saved=$(sed -n 's/^dim=//p' "$HOME/.config/tebian/fx-saved" | head -1)
                [ -n "$saved" ] && [ "$saved" != "0" ] && cur_dim="$saved"
            fi
            [ "$cur_corner" = "0" ] && cur_corner=8
            [ "$cur_dim" = "0" ] && cur_dim=0.1
            fx_write enable "$cur_passes" "$cur_radius" "$cur_corner" enable "$cur_shadow" "$cur_dim"
            tnotify "Effects" "Window effects on"
        fi

    elif [[ "$FX_CHOICE" =~ "Blur Strength" ]]; then
        BLUR_OPTS="Light (1 pass, radius 3)
Medium (2 passes, radius 5)
Heavy (3 passes, radius 8)
󰌍 Back"
        B_CHOICE=$(echo -e "$BLUR_OPTS" | tfuzzel -d -p " 󰂵 Blur | ")
        [ -n "$B_CHOICE" ] || menu_close
        case "$B_CHOICE" in
            *Light*) _bp=1; _br=3 ;;
            *Medium*) _bp=2; _br=5 ;;
            *Heavy*) _bp=3; _br=8 ;;
            *) continue ;;
        esac
        fx_write "$cur_blur" "$_bp" "$_br" "$cur_corner" "$cur_shadows" "$cur_shadow" "$cur_dim"
        tnotify "Effects" "Blur set to $_bp passes, radius $_br"

    elif [[ "$FX_CHOICE" =~ "Corner Radius" ]]; then
        CR_OPTS="None (0)
Subtle (4)
Medium (8)
Round (12)
Pill (16)
󰌍 Back"
        C_CHOICE=$(echo -e "$CR_OPTS" | tfuzzel -d -p " 󰘖 Corners | ")
        [ -n "$C_CHOICE" ] || menu_close
        case "$C_CHOICE" in
            *None*) _cr=0 ;;
            *Subtle*) _cr=4 ;;
            *Medium*) _cr=8 ;;
            *Round*) _cr=12 ;;
            *Pill*) _cr=16 ;;
            *) continue ;;
        esac
        fx_write "$cur_blur" "$cur_passes" "$cur_radius" "$_cr" "$cur_shadows" "$cur_shadow" "$cur_dim"
        tnotify "Effects" "Corner radius set to $_cr"

    elif [[ "$FX_CHOICE" =~ "Shadows" ]]; then
        SH_OPTS="Off (0)
Subtle (10)
Medium (20)
Heavy (40)
󰌍 Back"
        S_CHOICE=$(echo -e "$SH_OPTS" | tfuzzel -d -p " 󰘚 Shadows | ")
        [ -n "$S_CHOICE" ] || menu_close
        case "$S_CHOICE" in
            *Off*) _sr=0; _se="disable" ;;
            *Subtle*) _sr=10; _se="enable" ;;
            *Medium*) _sr=20; _se="enable" ;;
            *Heavy*) _sr=40; _se="enable" ;;
            *) continue ;;
        esac
        fx_write "$cur_blur" "$cur_passes" "$cur_radius" "$cur_corner" "$_se" "$_sr" "$cur_dim"
        tnotify "Effects" "Shadows set to $_se (radius $_sr)"

    elif [[ "$FX_CHOICE" =~ "Dim Inactive" ]]; then
        DIM_OPTS="Off (0)
Subtle (0.1)
Medium (0.2)
Strong (0.35)
󰌍 Back"
        D_CHOICE=$(echo -e "$DIM_OPTS" | tfuzzel -d -p " 󰌁 Dim | ")
        [ -n "$D_CHOICE" ] || menu_close
        case "$D_CHOICE" in
            *Off*) _dv="0" ;;
            *Subtle*) _dv="0.1" ;;
            *Medium*) _dv="0.2" ;;
            *Strong*) _dv="0.35" ;;
            *) continue ;;
        esac
        fx_write "$cur_blur" "$cur_passes" "$cur_radius" "$cur_corner" "$cur_shadows" "$cur_shadow" "$_dv"
        tnotify "Effects" "Dim inactive set to $_dv"
    fi
    done
}


# ── Font rendering ──
# Debian's baseline (hintslight + no subpixel) reads soft on 1080p panels
# next to Windows ClearType. Ubuntu ships RGB subpixel; Fedora ships medium
# hinting — Tebian defaults to both, and this menu lets users tune it.

# font_rendering_write <slight|medium|full> <rgb|none>
# User conf.d loads after the system 10-* defaults, so mode="assign" here
# cleanly overrides them without touching /etc.
font_rendering_write() {
    local conf="$HOME/.config/fontconfig/conf.d/50-tebian-font-rendering.conf"
    mkdir -p "${conf%/*}"
    cat > "$conf" << FONTEOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<!-- Managed by tebian-settings (UI > Font Rendering) -->
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hint${1}</const></edit>
    <edit name="rgba" mode="assign"><const>${2}</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>
</fontconfig>
FONTEOF
}

font_rendering_menu() {
    local conf="$HOME/.config/fontconfig/conf.d/50-tebian-font-rendering.conf"
    while true; do
        # Current state lives in the conf file itself — no separate state file
        local hint="slight" rgba="none"
        if [ -f "$conf" ]; then
            hint=$(grep -oE 'hint(slight|medium|full)' "$conf" | head -1 | sed 's/^hint//')
            rgba=$(grep -oE '>(rgb|none)<' "$conf" | tr -d '><' | head -1)
            [ -z "$hint" ] && hint="slight"
            [ -z "$rgba" ] && rgba="none"
        fi

        local mark_s="" mark_m="" mark_f="" mark_rgb="" mark_gray=""
        case "$hint" in
            slight) mark_s="  ● current" ;;
            medium) mark_m="  ● current" ;;
            full)   mark_f="  ● current" ;;
        esac
        if [ "$rgba" = "rgb" ]; then mark_rgb="  ● current"; else mark_gray="  ● current"; fi

        FR_OPTS="󰬴 Hinting: Slight — smoothest, best on HiDPI$mark_s
󰬴 Hinting: Medium — balanced, sharper on 1080p$mark_m
󰬴 Hinting: Full — sharpest, may distort letter shapes$mark_f
󰍹 Subpixel: RGB — extra sharpness on LCD panels$mark_rgb
󰍹 Subpixel: Grayscale — safe on any panel/rotation$mark_gray
󰑓 Reset to Debian defaults
󰌍 Back"

        FR_CHOICE=$(echo -e "$FR_OPTS" | tfuzzel -d -p " 󰛖 Fonts | ")
        [ -n "$FR_CHOICE" ] || menu_close
        if is_back "$FR_CHOICE"; then return; fi

        if [[ "$FR_CHOICE" =~ "Reset" ]]; then
            rm -f "$conf"
            tnotify "Fonts" "Debian defaults restored — restart apps to see it"
            continue
        fi

        [[ "$FR_CHOICE" =~ "Hinting: Slight" ]] && hint="slight"
        [[ "$FR_CHOICE" =~ "Hinting: Medium" ]] && hint="medium"
        [[ "$FR_CHOICE" =~ "Hinting: Full" ]]   && hint="full"
        [[ "$FR_CHOICE" =~ "Subpixel: RGB" ]]   && rgba="rgb"
        [[ "$FR_CHOICE" =~ "Grayscale" ]]       && rgba="none"

        font_rendering_write "$hint" "$rgba"
        tnotify "Fonts" "Hinting: ${hint}, subpixel: ${rgba} — restart apps to see it"
    done
}

snap_assist_toggle() {
    if ! tebian_snap_rev2; then
        tnotify "UI" "Snap Assist needs the current sway build — Window Snapping rebuilds it"
    elif tebian_snap_assist_enabled; then
        tebian_snap_assist_set off
        tnotify "UI" "Snap Assist off"
    else
        tebian_snap_assist_set on
        tnotify "UI" "Snap Assist on"
    fi
}

# Settings > More > Desktop & UI > Dock. tebian-dock does the work; this is
# only its menu, with each label showing the current state.
dock_menu() {
    local st on pos ah CHOICE p
    while true; do
        st=$(tebian-dock status 2>/dev/null)
        on=$(sed -n 's/^enabled=//p' <<< "$st")
        pos=$(sed -n 's/^position=//p' <<< "$st")
        ah=$(sed -n 's/^autohide=//p' <<< "$st")
        CHOICE=$(printf '%s\n' "󰀻 Dock (${on^^})" "󰞒 Dock Position (Current: ${pos^})" \
            "󰆪 Dock Auto-hide (${ah^^})" "󰌍 Back" | tfuzzel -d -p " 󰀻 Dock | ")
        [ -n "$CHOICE" ] || menu_close
        is_back "$CHOICE" && return
        case "$CHOICE" in
            *"Dock Position"*)
                p=$(printf 'Bottom\nLeft\nRight\n' | tfuzzel -d -p " 󰞒 Dock Position | ")
                [ -n "$p" ] || continue
                tebian-dock position "${p,,}" ;;
            *"Dock Auto-hide"*) tebian-dock autohide toggle ;;
            *"Dock ("*) tebian-dock toggle >/dev/null ;;
        esac
    done
}
