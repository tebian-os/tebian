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
        BAR_LABEL="󰆪 Show Bar Always (Current: Auto-hide)"
    elif [[ "$BAR_MODE" == "invisible" ]]; then
        BAR_LABEL="󰆪 Show Bar Always (Current: Hidden)"
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

    # Detect title bars (theme sets pixel 2 = OFF by default)
    if grep -q '# tebian-titlebars-on' "$HOME/.config/sway/config.user" 2>/dev/null; then
        TITLE_LABEL="󰘖 Title Bars (ON)"
    else
        TITLE_LABEL="󰘕 Title Bars (OFF)"
    fi

    # Detect edge snapping (only show when floating mode is active)
    if grep -q '# tebian-floating-mode' "$HOME/.config/sway/config.user" 2>/dev/null; then
        if pgrep -f tebian-edge-snap > /dev/null 2>&1; then
            SNAP_LABEL="󰖲 Edge Snapping (ON)"
        else
            SNAP_LABEL="󰖳 Edge Snapping (OFF)"
        fi
    else
        SNAP_LABEL=""
    fi

    # Detect window effects (swayfx)
    if [ -f "$HOME/.config/tebian/swayfx-installed" ]; then
        if grep -q '^blur enable # tebian-swayfx' "$HOME/.config/sway/config.user" 2>/dev/null; then
            FX_LABEL="󰖲 Window Effects (ON)"
        else
            FX_LABEL="󰖲 Window Effects (OFF)"
        fi
    else
        FX_LABEL="󰖲 Window Effects (Not Installed)"
    fi

    UI_OPTS="$ICON_LABEL
$BAR_LABEL
$POS_LABEL
$FLOAT_LABEL
$TITLE_LABEL
${SNAP_LABEL:+$SNAP_LABEL
}$FX_LABEL
󰌌 Keybinds (Mod+S: settings, Mod+D: apps)
󰍽 Input Devices
󰌍 Back"
    
    U_CHOICE=$(echo -e "$UI_OPTS" | tfuzzel -d -p " 󰇄 UI | ")

    if [[ "$U_CHOICE" == *"󰌍 Back"* || -z "$U_CHOICE" ]]; then return; fi

    if [[ "$U_CHOICE" =~ "Disable UI Icons" ]]; then
        mkdir -p "$HOME/.config/tebian"
        touch "$HOME/.config/tebian/no_icons"
        tnotify "Tebian UI" "Text Mode Enabled (Icons Hidden)"
    elif [[ "$U_CHOICE" =~ "Enable UI Icons" ]]; then
        rm -f "$HOME/.config/tebian/no_icons"
        tnotify "Tebian UI" "Icon Mode Enabled"
    elif [[ "$U_CHOICE" =~ "Show Bar Always" ]]; then
        swaymsg "bar mode dock" &
        safe_sed_replace "^bar " "^}" 's/^[[:space:]]*mode[[:space:]]+(hide|dock|invisible)/    mode dock/' "$HOME/.config/sway/config"
        tnotify "UI" "Bar set to always visible"
    elif [[ "$U_CHOICE" =~ "Hide Bar" ]]; then
        swaymsg "bar mode hide" &
        safe_sed_replace "^bar " "^}" 's/^[[:space:]]*mode[[:space:]]+(hide|dock|invisible)/    mode hide/' "$HOME/.config/sway/config"
        tnotify "UI" "Bar hidden (press Super to show)"
    elif [[ "$U_CHOICE" =~ "Bar Position" ]]; then
        if [[ "$BAR_POS" == "top" ]]; then
            sed -i -E 's/^[[:space:]]*position[[:space:]]+(top|bottom)/    position bottom/' "$HOME/.config/sway/config"
            sed -i 's/^anchor = .*/anchor = top center/' "$HOME/.config/wob/wob.ini" 2>/dev/null
            tnotify "UI" "Bar moved to bottom"
            swaymsg reload 2>/dev/null &
        else
            sed -i -E 's/^[[:space:]]*position[[:space:]]+(top|bottom)/    position top/' "$HOME/.config/sway/config"
            sed -i 's/^anchor = .*/anchor = bottom center/' "$HOME/.config/wob/wob.ini" 2>/dev/null
            tnotify "UI" "Bar moved to top"
            swaymsg reload 2>/dev/null &
        fi
    elif [[ "$U_CHOICE" =~ "Floating" ]]; then
        setup_floating_mode
        tnotify "UI" "Floating mode enabled"
        swaymsg reload 2>/dev/null &
    elif [[ "$U_CHOICE" =~ "Tiling" ]]; then
        remove_floating_mode
        swaymsg '[app_id=".*"] floating disable' 2>/dev/null
        swaymsg '[class=".*"] floating disable' 2>/dev/null
        tnotify "UI" "Tiling mode enabled"
        swaymsg reload 2>/dev/null &
    elif [[ "$U_CHOICE" =~ "Title Bars" ]] && [[ "$U_CHOICE" =~ "ON" ]]; then
        # Turn OFF title bars — remove override, theme's pixel 2 takes effect
        sed -i '/# tebian-titlebars/d' "$HOME/.config/sway/config.user" 2>/dev/null
        swaymsg "default_border pixel 2" 2>/dev/null
        swaymsg "default_floating_border pixel 2" 2>/dev/null
        swaymsg '[app_id=".*"] border pixel 2' 2>/dev/null
        swaymsg '[class=".*"] border pixel 2' 2>/dev/null
        tnotify "UI" "Title bars disabled"
    elif [[ "$U_CHOICE" =~ "Title Bars" ]]; then
        # Turn ON title bars — write explicit override to beat theme's pixel 2
        sed -i '/# tebian-titlebars/d' "$HOME/.config/sway/config.user" 2>/dev/null
        idempotent_append "default_border normal 2 # tebian-titlebars-on" "$HOME/.config/sway/config.user"
        idempotent_append "default_floating_border normal 2 # tebian-titlebars-on" "$HOME/.config/sway/config.user"
        swaymsg "default_border normal 2" 2>/dev/null
        swaymsg "default_floating_border normal 2" 2>/dev/null
        swaymsg '[app_id=".*"] border normal 2' 2>/dev/null
        swaymsg '[class=".*"] border normal 2' 2>/dev/null
        tnotify "UI" "Title bars enabled"
    elif [[ "$U_CHOICE" =~ "Edge Snapping" ]] && [[ "$U_CHOICE" =~ "ON" ]]; then
        pkill -f tebian-edge-snap 2>/dev/null
        sed -i '/tebian-edge-snap/d' "$HOME/.config/sway/config.user" 2>/dev/null
        tnotify "UI" "Edge snapping disabled"
    elif [[ "$U_CHOICE" =~ "Edge Snapping" ]] && [[ "$U_CHOICE" =~ "OFF" ]]; then
        if ! command -v python3 &>/dev/null || ! python3 -c "import i3ipc" 2>/dev/null; then
            tnotify "Edge Snap" "Installing python3-i3ipc..."
            sudo apt install -y python3-i3ipc 2>/dev/null
        fi
        pkill -f tebian-edge-snap 2>/dev/null
        sleep 0.2
        tebian-edge-snap &
        disown
        idempotent_append "exec_always bash -c 'pkill -f tebian-edge-snap; sleep 0.2; tebian-edge-snap &' # tebian-floating-mode" "$HOME/.config/sway/config.user"
        tnotify "UI" "Edge snapping enabled"
    elif [[ "$U_CHOICE" =~ "Window Effects" ]] && [[ "$U_CHOICE" =~ "Not Installed" ]]; then
        window_effects_install
    elif [[ "$U_CHOICE" =~ "Window Effects" ]]; then
        window_effects_menu
    elif [[ "$U_CHOICE" =~ "Keybinds" ]]; then
        KEY_LIST="Mod+D ··· App Launcher
Mod+A ··· All Apps (Drawer)
Mod+S ··· Settings
Mod+Return ··· Terminal
Mod+Shift+Q ··· Close Window
Mod+F ··· Fullscreen
Mod+Space ··· Toggle Float/Tile
Mod+R ··· Resize Mode
Mod+L ··· Lock Screen
Mod+Tab ··· Switch Workspace
Mod+1-9 ··· Go to Workspace
Mod+Shift+? ··· Show Key Helper
Print ··· Screenshot (Region)
Shift+Print ··· Screenshot (Full)
Mod+V ··· Clipboard History
Ctrl+Left/Right ··· Switch Workspace
󰌍 Back"
        echo -e "$KEY_LIST" | tfuzzel -d -p " 󰌌 Keybinds | "
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
⌨️  Keyboard Layout
󰍽 Mouse Speed
󰌍 Back"

    I_CHOICE=$(echo -e "$INPUT_OPTS" | tfuzzel -d -p " 󰍽 Input | ")
    if [[ "$I_CHOICE" == *"󰌍 Back"* || -z "$I_CHOICE" ]]; then return; fi

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
        SPEED_OPTS="Slow (0.5x)
Normal (1x)
Fast (2x)
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
󰌍 Back"
        KB=$(echo -e "$LAYOUTS" | tfuzzel -d -p " ⌨️ Layout | ")
        if [[ ! "$KB" == *"󰌍 Back"* ]] && [ -n "$KB" ]; then
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

window_effects_install() {
    INSTALL_CHOICE=$(echo -e "󰖲 Install SwayFX (build from source, ~5 min)\n󰌍 Back" | tfuzzel -d -p " 󰖲 Effects | ")
    if [[ "$INSTALL_CHOICE" =~ "Install" ]]; then
        $TERM_CMD bash -c "tebian-install-swayfx; echo ''; read -p 'Press Enter to close...'"
    fi
}

window_effects_menu() {
    while true; do
    # Read current values from config.user
    local cfg="$HOME/.config/sway/config.user"
    local blur_on=false
    grep -q '^blur enable # tebian-swayfx' "$cfg" 2>/dev/null && blur_on=true

    local cur_passes cur_radius cur_corner cur_shadow cur_dim
    cur_passes=$(grep '^blur_passes' "$cfg" 2>/dev/null | awk '{print $2}')
    cur_radius=$(grep '^blur_radius' "$cfg" 2>/dev/null | awk '{print $2}')
    cur_corner=$(grep '^corner_radius' "$cfg" 2>/dev/null | awk '{print $2}')
    cur_shadow=$(grep '^shadow_blur_radius' "$cfg" 2>/dev/null | awk '{print $2}')
    cur_dim=$(grep '^default_dim_inactive' "$cfg" 2>/dev/null | awk '{print $2}')
    : "${cur_passes:=2}" "${cur_radius:=5}" "${cur_corner:=8}" "${cur_shadow:=20}" "${cur_dim:=0.1}"

    if $blur_on; then
        TOGGLE_LABEL="󰖲 Effects: ON (click to disable)"
    else
        TOGGLE_LABEL="󰖲 Effects: OFF (click to enable)"
    fi

    FX_OPTS="$TOGGLE_LABEL
󰂵 Blur Strength (passes: $cur_passes, radius: $cur_radius)
󰘖 Corner Radius ($cur_corner)
󰘚 Shadows (radius: $cur_shadow)
󰌁 Dim Inactive ($cur_dim)
󰌍 Back"

    FX_CHOICE=$(echo -e "$FX_OPTS" | tfuzzel -d -p " 󰖲 Effects | ")

    if [[ "$FX_CHOICE" == *"󰌍 Back"* || -z "$FX_CHOICE" ]]; then return; fi

    if [[ "$FX_CHOICE" =~ "Effects:" ]]; then
        if $blur_on; then
            # Disable all effects
            sed -i 's/^blur enable # tebian-swayfx/blur disable # tebian-swayfx/' "$cfg"
            sed -i 's/^shadows enable # tebian-swayfx/shadows disable # tebian-swayfx/' "$cfg"
            sed -i 's/^corner_radius [0-9]* # tebian-swayfx/corner_radius 0 # tebian-swayfx/' "$cfg"
            sed -i 's/^default_dim_inactive [0-9.]* # tebian-swayfx/default_dim_inactive 0 # tebian-swayfx/' "$cfg"
            swaymsg reload 2>/dev/null &
            tnotify "Effects" "Window effects disabled"
        else
            # Enable all effects
            sed -i 's/^blur disable # tebian-swayfx/blur enable # tebian-swayfx/' "$cfg"
            sed -i 's/^shadows disable # tebian-swayfx/shadows enable # tebian-swayfx/' "$cfg"
            sed -i "s/^corner_radius 0 # tebian-swayfx/corner_radius $cur_corner # tebian-swayfx/" "$cfg"
            sed -i "s/^default_dim_inactive 0 # tebian-swayfx/default_dim_inactive $cur_dim # tebian-swayfx/" "$cfg"
            swaymsg reload 2>/dev/null &
            tnotify "Effects" "Window effects enabled"
        fi

    elif [[ "$FX_CHOICE" =~ "Blur Strength" ]]; then
        BLUR_OPTS="Light (1 pass, radius 3)
Medium (2 passes, radius 5)
Heavy (3 passes, radius 8)
󰌍 Back"
        B_CHOICE=$(echo -e "$BLUR_OPTS" | tfuzzel -d -p " 󰂵 Blur | ")
        case "$B_CHOICE" in
            *Light*) _bp=1; _br=3 ;;
            *Medium*) _bp=2; _br=5 ;;
            *Heavy*) _bp=3; _br=8 ;;
            *) continue ;;
        esac
        sed -i "s/^blur_passes .* # tebian-swayfx/blur_passes $_bp # tebian-swayfx/" "$cfg"
        sed -i "s/^blur_radius .* # tebian-swayfx/blur_radius $_br # tebian-swayfx/" "$cfg"
        swaymsg reload 2>/dev/null &
        tnotify "Effects" "Blur set to $_bp passes, radius $_br"

    elif [[ "$FX_CHOICE" =~ "Corner Radius" ]]; then
        CR_OPTS="None (0)
Subtle (4)
Medium (8)
Round (12)
Pill (16)
󰌍 Back"
        C_CHOICE=$(echo -e "$CR_OPTS" | tfuzzel -d -p " 󰘖 Corners | ")
        case "$C_CHOICE" in
            *None*) _cr=0 ;;
            *Subtle*) _cr=4 ;;
            *Medium*) _cr=8 ;;
            *Round*) _cr=12 ;;
            *Pill*) _cr=16 ;;
            *) continue ;;
        esac
        sed -i "s/^corner_radius .* # tebian-swayfx/corner_radius $_cr # tebian-swayfx/" "$cfg"
        swaymsg reload 2>/dev/null &
        tnotify "Effects" "Corner radius set to $_cr"

    elif [[ "$FX_CHOICE" =~ "Shadows" ]]; then
        SH_OPTS="Off (0)
Subtle (10)
Medium (20)
Heavy (40)
󰌍 Back"
        S_CHOICE=$(echo -e "$SH_OPTS" | tfuzzel -d -p " 󰘚 Shadows | ")
        case "$S_CHOICE" in
            *Off*) _sr=0; _se="disable" ;;
            *Subtle*) _sr=10; _se="enable" ;;
            *Medium*) _sr=20; _se="enable" ;;
            *Heavy*) _sr=40; _se="enable" ;;
            *) continue ;;
        esac
        sed -i "s/^shadow_blur_radius .* # tebian-swayfx/shadow_blur_radius $_sr # tebian-swayfx/" "$cfg"
        sed -i "s/^shadows .* # tebian-swayfx/shadows $_se # tebian-swayfx/" "$cfg"
        swaymsg reload 2>/dev/null &
        tnotify "Effects" "Shadows set to $_se (radius $_sr)"

    elif [[ "$FX_CHOICE" =~ "Dim Inactive" ]]; then
        DIM_OPTS="Off (0)
Subtle (0.1)
Medium (0.2)
Strong (0.35)
󰌍 Back"
        D_CHOICE=$(echo -e "$DIM_OPTS" | tfuzzel -d -p " 󰌁 Dim | ")
        case "$D_CHOICE" in
            *Off*) _dv="0" ;;
            *Subtle*) _dv="0.1" ;;
            *Medium*) _dv="0.2" ;;
            *Strong*) _dv="0.35" ;;
            *) continue ;;
        esac
        sed -i "s/^default_dim_inactive .* # tebian-swayfx/default_dim_inactive $_dv # tebian-swayfx/" "$cfg"
        swaymsg reload 2>/dev/null &
        tnotify "Effects" "Dim inactive set to $_dv"
    fi
    done
}

