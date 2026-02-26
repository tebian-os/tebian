# tebian-settings module: ui.sh
# Sourced by tebian-settings — do not run directly

ui_menu() {
    while true; do
    # Detect icon state
    if [ -f "$HOME/.config/tebian/no_icons" ]; then
        ICON_LABEL="📦 Enable UI Icons (Text Mode: ON)"
    else
        ICON_LABEL="🚫 Disable UI Icons (Text Mode: OFF)"
    fi

    # Detect bar state
    BAR_MODE=$(swaymsg -r -t get_bar_config bar-0 2>/dev/null | grep '"mode"' | head -1 | cut -d'"' -f4)
    if [[ "$BAR_MODE" == "hide" ]]; then
        BAR_LABEL="󰆪 Show Bar Always (Current: Super Only)"
    else
        BAR_LABEL="󰆪 Hide Bar (Current: Always Visible)"
    fi

    # Detect bar position
    BAR_POS=$(swaymsg -r -t get_bar_config bar-0 2>/dev/null | grep '"position"' | head -1 | cut -d'"' -f4)
    if [[ "$BAR_POS" == "top" ]]; then
        POS_LABEL="󰞑 Bar Position (Current: Top)"
    else
        POS_LABEL="󰞒 Bar Position (Current: Bottom)"
    fi

    # Detect floating mode
    if grep -q '# tebian-floating-mode' "$HOME/.config/sway/config.user" 2>/dev/null; then
        FLOAT_LABEL="󰀻 Switch to Tiling (Current: Floating)"
    else
        FLOAT_LABEL="󰖲 Switch to Floating (Current: Tiling)"
    fi

    # Detect title bars
    if grep -q '# tebian-titlebars' "$HOME/.config/sway/config.user" 2>/dev/null; then
        TITLE_LABEL="󰘖 Title Bars (ON)"
    else
        TITLE_LABEL="󰘕 Title Bars (OFF)"
    fi

    UI_OPTS="$ICON_LABEL
$BAR_LABEL
$POS_LABEL
$FLOAT_LABEL
$TITLE_LABEL
─────────────────────────────────
󰌌 Keybinds (Mod+S: settings, Mod+D: apps)
󰍽 Input Devices
─────────────────────────────────
󰌍 Back"
    
    U_CHOICE=$(echo -e "$UI_OPTS" | tfuzzel -d -p " 󰇄 UI | ")

    if [[ "$U_CHOICE" =~ "Back" || -z "$U_CHOICE" ]]; then return; fi

    if [[ "$U_CHOICE" =~ "Disable UI Icons" ]]; then
        mkdir -p "$HOME/.config/tebian"
        touch "$HOME/.config/tebian/no_icons"
        tnotify "Tebian UI" "Text Mode Enabled (Icons Hidden)"
    elif [[ "$U_CHOICE" =~ "Enable UI Icons" ]]; then
        rm -f "$HOME/.config/tebian/no_icons"
        tnotify "Tebian UI" "Icon Mode Enabled"
    elif [[ "$U_CHOICE" =~ "Show Bar Always" ]]; then
        swaymsg "bar mode dock"
        safe_sed_replace "^bar " "^}" 's/^[[:space:]]*mode[[:space:]]+(hide|dock|invisible)/    mode dock/' "$HOME/.config/sway/config"
        tnotify "UI" "Bar set to always visible"
    elif [[ "$U_CHOICE" =~ "Hide Bar" ]]; then
        swaymsg "bar mode hide"
        safe_sed_replace "^bar " "^}" 's/^[[:space:]]*mode[[:space:]]+(hide|dock|invisible)/    mode hide/' "$HOME/.config/sway/config"
        tnotify "UI" "Bar hidden (press Super to show)"
    elif [[ "$U_CHOICE" =~ "Bar Position" ]]; then
        if [[ "$BAR_POS" == "top" ]]; then
            swaymsg "bar bar-0 position bottom"
            sed -i -E 's/^[[:space:]]*position[[:space:]]+(top|bottom)/    position bottom/' "$HOME/.config/sway/config"
            tnotify "UI" "Bar moved to bottom"
        else
            swaymsg "bar bar-0 position top"
            sed -i -E 's/^[[:space:]]*position[[:space:]]+(top|bottom)/    position top/' "$HOME/.config/sway/config"
            tnotify "UI" "Bar moved to top"
        fi
    elif [[ "$U_CHOICE" =~ "Floating" ]]; then
        setup_floating_mode
        swaymsg '[app_id=".*"] floating enable' 2>/dev/null
        swaymsg '[class=".*"] floating enable' 2>/dev/null
        tnotify "UI" "Floating mode enabled"
    elif [[ "$U_CHOICE" =~ "Tiling" ]]; then
        remove_floating_mode
        swaymsg '[app_id=".*"] floating disable' 2>/dev/null
        swaymsg '[class=".*"] floating disable' 2>/dev/null
        tnotify "UI" "Tiling mode enabled"
    elif [[ "$U_CHOICE" =~ "Title Bars" ]] && [[ "$U_CHOICE" =~ "ON" ]]; then
        sed -i '/# tebian-titlebars/d' "$HOME/.config/sway/config.user" 2>/dev/null
        swaymsg "default_border pixel 2" 2>/dev/null
        swaymsg reload 2>/dev/null
        tnotify "UI" "Title bars disabled"
    elif [[ "$U_CHOICE" =~ "Title Bars" ]]; then
        idempotent_append "default_border normal 2 # tebian-titlebars" "$HOME/.config/sway/config.user"
        idempotent_append "default_floating_border normal 2 # tebian-titlebars" "$HOME/.config/sway/config.user"
        swaymsg "default_border normal 2" 2>/dev/null
        swaymsg reload 2>/dev/null
        tnotify "UI" "Title bars enabled"
    elif [[ "$U_CHOICE" =~ "Keybinds" ]]; then
        $TERM_CMD bash -c "echo '=== Tebian Keybindings ===';
        echo '';
        echo 'Mod+D         App Launcher';
        echo 'Mod+A         All Apps (Drawer)';
        echo 'Mod+S         Settings';
        echo 'Mod+Return    Terminal';
        echo 'Mod+Shift+Q   Close Window';
        echo 'Mod+F         Fullscreen';
        echo 'Mod+Space     Toggle Float/Tile';
        echo 'Mod+R         Resize Mode';
        echo 'Mod+L         Lock Screen';
        echo 'Mod+Tab       Switch Workspace';
        echo 'Mod+1-9       Go to Workspace';
        echo 'Mod+Shift+?   Show Key Helper';
        echo 'Print         Screenshot (Region)';
        echo 'Shift+Print   Screenshot (Full)';
        echo 'Mod+V         Clipboard History';
        echo '';
        read -p 'Press Enter to close...'"
    elif [[ "$U_CHOICE" =~ "Input Devices" ]]; then
        input_device_menu
    fi
    done
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
─────────────────────────────────
⌨️  Keyboard Layout
󰍽 Mouse Speed
─────────────────────────────────
󰌍 Back"

    I_CHOICE=$(echo -e "$INPUT_OPTS" | tfuzzel -d -p " 󰍽 Input | ")
    if [[ "$I_CHOICE" =~ "Back" || -z "$I_CHOICE" ]]; then return; fi

    SWAY_CFG="$HOME/.config/sway/config.user"

    if [[ "$I_CHOICE" =~ "Tap to Click" ]]; then
        if [[ "$TAP" = "enabled" ]]; then
            swaymsg "input type:touchpad tap disabled"
            sed -i '/input type:touchpad.*tap enabled/d' "$SWAY_CFG" 2>/dev/null
            tnotify "Input" "Tap to Click disabled"
        else
            swaymsg "input type:touchpad tap enabled"
            grep -q 'input type:touchpad.*tap enabled' "$SWAY_CFG" 2>/dev/null || echo 'input type:touchpad tap enabled' >> "$SWAY_CFG"
            tnotify "Input" "Tap to Click enabled"
        fi
    elif [[ "$I_CHOICE" =~ "Natural Scroll" ]]; then
        if [[ "$NSCROLL" = "enabled" ]]; then
            swaymsg "input type:touchpad natural_scroll disabled"
            sed -i '/input type:touchpad.*natural_scroll enabled/d' "$SWAY_CFG" 2>/dev/null
            tnotify "Input" "Natural Scroll disabled"
        else
            swaymsg "input type:touchpad natural_scroll enabled"
            grep -q 'input type:touchpad.*natural_scroll enabled' "$SWAY_CFG" 2>/dev/null || echo 'input type:touchpad natural_scroll enabled' >> "$SWAY_CFG"
            tnotify "Input" "Natural Scroll enabled"
        fi
    elif [[ "$I_CHOICE" =~ "Scroll Speed" ]]; then
        SPEED_OPTS="Slow (0.5x)
Normal (1x)
Fast (2x)
─────────────────────────────────
󰌍 Back"
        SP=$(echo -e "$SPEED_OPTS" | tfuzzel -d -p " Scroll Speed | ")
        case "$SP" in
            *Slow*) FACTOR="0.5" ;;
            *Normal*) FACTOR="1.0" ;;
            *Fast*) FACTOR="2.0" ;;
            *) continue ;;
        esac
        swaymsg "input type:touchpad scroll_factor $FACTOR"
        sed -i '/input type:touchpad.*scroll_factor/d' "$SWAY_CFG" 2>/dev/null
        echo "input type:touchpad scroll_factor $FACTOR" >> "$SWAY_CFG"
        tnotify "Input" "Scroll speed set to $FACTOR"
    elif [[ "$I_CHOICE" =~ "Keyboard Layout" ]]; then
        LAYOUTS="us - English (US)
gb - English (UK)
de - German
fr - French
es - Spanish
it - Italian
pt - Portuguese
ru - Russian
jp - Japanese
kr - Korean
─────────────────────────────────
󰌍 Back"
        KB=$(echo -e "$LAYOUTS" | tfuzzel -d -p " ⌨️ Layout | ")
        if [[ ! "$KB" =~ "Back" ]] && [ -n "$KB" ]; then
            LAYOUT=$(echo "$KB" | awk '{print $1}')
            swaymsg "input type:keyboard xkb_layout $LAYOUT"
            sed -i '/input type:keyboard.*xkb_layout/d' "$SWAY_CFG" 2>/dev/null
            echo "input type:keyboard xkb_layout $LAYOUT" >> "$SWAY_CFG"
            tnotify "Input" "Keyboard layout set to $LAYOUT"
        fi
    elif [[ "$I_CHOICE" =~ "Mouse Speed" ]]; then
        SPEED_OPTS="Slow (-0.5)
Normal (0)
Fast (0.5)
─────────────────────────────────
󰌍 Back"
        MS=$(echo -e "$SPEED_OPTS" | tfuzzel -d -p " Mouse Speed | ")
        case "$MS" in
            *Slow*) ACCEL="-0.5" ;;
            *Normal*) ACCEL="0" ;;
            *Fast*) ACCEL="0.5" ;;
            *) continue ;;
        esac
        swaymsg "input type:pointer pointer_accel $ACCEL"
        sed -i '/input type:pointer.*pointer_accel/d' "$SWAY_CFG" 2>/dev/null
        echo "input type:pointer pointer_accel $ACCEL" >> "$SWAY_CFG"
        tnotify "Input" "Mouse speed set to $ACCEL"
    fi
    done
}

