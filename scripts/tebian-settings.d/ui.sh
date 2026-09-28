# shellcheck shell=bash
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
    if tebian_block_has floating-mode; then
        FLOAT_LABEL="󰀻 Switch to Tiling (Current: Floating)"
    else
        FLOAT_LABEL="󰖲 Switch to Floating (Current: Tiling)"
    fi

    # Detect title bars (theme sets pixel 2 = OFF by default)
    if tebian_block_has titlebars; then
        TITLE_LABEL="󰘖 Title Bars (ON)"
    else
        TITLE_LABEL="󰘕 Title Bars (OFF)"
    fi

    # Detect edge snapping (only show when floating mode is active). The
    # config block is the setting; the process may just be restarting.
    if tebian_block_has floating-mode; then
        if tebian_block_has edge-snap; then
            SNAP_LABEL="󰖲 Edge Snapping (ON)"
        else
            SNAP_LABEL="󰖳 Edge Snapping (OFF)"
        fi
    else
        SNAP_LABEL=""
    fi

    # Detect window effects (swayfx)
    if [ -f "$HOME/.config/tebian/swayfx-installed" ]; then
        if [ "$(fx_get blur)" = enable ]; then
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
󰛖 Font Rendering
󰌌 Keybinds (Mod+S: settings, Mod+D: apps)
󰍽 Input Devices
󰌍 Back"
    
    U_CHOICE=$(echo -e "$UI_OPTS" | tfuzzel -d -p " 󰇄 UI | ")

    if is_back "$U_CHOICE"; then return; fi

    if [[ "$U_CHOICE" =~ "Disable UI Icons" ]]; then
        mkdir -p "$HOME/.config/tebian"
        touch "$HOME/.config/tebian/no_icons"
        tnotify "Tebian UI" "Text Mode Enabled (Icons Hidden)"
    elif [[ "$U_CHOICE" =~ "Enable UI Icons" ]]; then
        rm -f "$HOME/.config/tebian/no_icons"
        tnotify "Tebian UI" "Icon Mode Enabled"
    elif [[ "$U_CHOICE" =~ "Show Bar Always" ]]; then
        bar_set_mode dock
        tnotify "UI" "Bar set to always visible"
    elif [[ "$U_CHOICE" =~ "Hide Bar" ]]; then
        bar_set_mode hide
        tnotify "UI" "Bar hidden (press Super to show)"
    elif [[ "$U_CHOICE" =~ "Bar Position" ]]; then
        if [[ "$BAR_POS" == "top" ]]; then
            bar_set_position bottom
            tnotify "UI" "Bar moved to bottom"
        else
            bar_set_position top
            tnotify "UI" "Bar moved to top"
        fi
    elif [[ "$U_CHOICE" =~ "Switch to Floating" ]]; then
        setup_floating_mode
        tnotify "UI" "Floating mode enabled"
        swaymsg reload 2>/dev/null &
    elif [[ "$U_CHOICE" =~ "Switch to Tiling" ]]; then
        remove_floating_mode
        swaymsg '[app_id=".*"] floating disable' 2>/dev/null
        swaymsg '[class=".*"] floating disable' 2>/dev/null
        tnotify "UI" "Tiling mode enabled"
        swaymsg reload 2>/dev/null &
    elif [[ "$U_CHOICE" =~ "Title Bars" ]] && [[ "$U_CHOICE" =~ "ON" ]]; then
        # Turn OFF title bars — remove override, theme's pixel 2 takes effect
        tebian_block_remove titlebars
        swaymsg "default_border pixel 2" 2>/dev/null
        swaymsg "default_floating_border pixel 2" 2>/dev/null
        swaymsg '[app_id=".*"] border pixel 2' 2>/dev/null
        swaymsg '[class=".*"] border pixel 2' 2>/dev/null
        tnotify "UI" "Title bars disabled"
    elif [[ "$U_CHOICE" =~ "Title Bars" ]]; then
        # Turn ON title bars — write explicit override to beat theme's pixel 2
        tebian_block_set titlebars "default_border normal 2" "default_floating_border normal 2"
        swaymsg "default_border normal 2" 2>/dev/null
        swaymsg "default_floating_border normal 2" 2>/dev/null
        swaymsg '[app_id=".*"] border normal 2' 2>/dev/null
        swaymsg '[class=".*"] border normal 2' 2>/dev/null
        tnotify "UI" "Title bars enabled"
    elif [[ "$U_CHOICE" =~ "Edge Snapping" ]] && [[ "$U_CHOICE" =~ "ON" ]]; then
        tebian_block_remove edge-snap
        pkill -f "^[^ ]*python3 [^ ]*tebian-edge-snap" 2>/dev/null
        tnotify "UI" "Edge snapping disabled"
    elif [[ "$U_CHOICE" =~ "Edge Snapping" ]] && [[ "$U_CHOICE" =~ "OFF" ]]; then
        if ! tebian_term_apt_install python3-i3ipc; then
            tnotify "Edge Snap" "python3-i3ipc could not be installed — edge snapping stays off"
            continue
        fi
        tebian_block_set edge-snap "$TEBIAN_EDGE_SNAP_EXEC"
        pkill -f "^[^ ]*python3 [^ ]*tebian-edge-snap" 2>/dev/null
        sleep 0.2
        setsid tebian-edge-snap >/dev/null 2>&1 &
        tnotify "UI" "Edge snapping enabled"
    elif [[ "$U_CHOICE" =~ "Window Effects" ]] && [[ "$U_CHOICE" =~ "Not Installed" ]]; then
        window_effects_install
    elif [[ "$U_CHOICE" =~ "Window Effects" ]]; then
        window_effects_menu
    elif [[ "$U_CHOICE" =~ "Font Rendering" ]]; then
        font_rendering_menu
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
Mod+Alt+Left/Right ··· Previous/Next Workspace
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
        if ! is_back "$KB"; then
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

# Bar settings persist as config.user blocks: sway applies
# `bar bar-0 <option>` after the bar {} block, and unlike the main config,
# config.user survives updates and rebuilds
bar_set_mode() {
    swaymsg "bar bar-0 mode $1" >/dev/null 2>&1 &
    tebian_block_set bar-mode "bar bar-0 mode $1"
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

    if is_back "$FX_CHOICE"; then return; fi

    if [[ "$FX_CHOICE" =~ "Effects:" ]]; then
        if [ "$cur_blur" = enable ]; then
            # Disabling zeroes corners and dim; remember them so re-enabling
            # restores the user's values rather than the defaults
            mkdir -p "$HOME/.config/tebian"
            printf 'corner=%s\ndim=%s\n' "$cur_corner" "$cur_dim" > "$HOME/.config/tebian/fx-saved"
            fx_write disable "$cur_passes" "$cur_radius" 0 disable "$cur_shadow" 0
            tnotify "Effects" "Window effects disabled"
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
