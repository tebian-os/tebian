# tebian-settings module: screen.sh
# Sourced by tebian-settings — do not run directly

# Screen submenu (combines brightness + screenshots + lock)
screen_all_menu() {
    while true; do
        # Detect bar stats state
        if [ -f "$HOME/.config/tebian/bar_perf_off" ]; then
            PERF_LABEL="󰍛 Bar Stats (OFF)"
        else
            PERF_LABEL="󰍛 Bar Stats (ON)"
        fi

        # Night light state
        if pgrep -x wlsunset &>/dev/null; then
            NIGHT_LABEL="󰖔 Night Light (ON)"
        else
            NIGHT_LABEL="󰖔 Night Light (OFF)"
        fi

        S_OPTS="󰃠 Brightness\0icon\x1fvideo-display
󰄀 Screenshots (Print: region, Shift+Print: full)\0icon\x1fcamera-photo
󰌾 Lock & Idle (Mod+L: lock now)\0icon\x1fsystem-lock-screen
$PERF_LABEL\0icon\x1fpreferences-system
$NIGHT_LABEL\0icon\x1fweather-clear-night
─────────────────────────────────
󰌍 Back"

        S_CHOICE=$(echo -e "$S_OPTS" | tfuzzel -d -p " Screen | ")

        if [[ -z "$S_CHOICE" ]] || [[ "$S_CHOICE" =~ "Back" ]]; then return; fi

        if [[ "$S_CHOICE" =~ "Brightness" ]]; then
            screen_menu
        elif [[ "$S_CHOICE" =~ "Screenshots" ]]; then
            screenshot_menu
        elif [[ "$S_CHOICE" =~ "Lock" ]]; then
            lock_menu
        elif [[ "$S_CHOICE" =~ "Bar Stats" ]]; then
            mkdir -p "$HOME/.config/tebian"
            if [ -f "$HOME/.config/tebian/bar_perf_off" ]; then
                rm "$HOME/.config/tebian/bar_perf_off"
            else
                touch "$HOME/.config/tebian/bar_perf_off"
            fi
            # Restart status bar to apply
            pkill -f '\.local/bin/status\.sh' 2>/dev/null
            swaymsg reload 2>/dev/null
        elif [[ "$S_CHOICE" =~ "Night Light" ]]; then
            if pgrep -x wlsunset &>/dev/null; then
                pkill wlsunset
                tnotify "Night Light" "Disabled"
            else
                if ! command -v wlsunset &>/dev/null; then
                    $TERM_CMD bash -c 'sudo apt update && sudo apt install -y wlsunset; echo "Done!"; read -p "Press Enter..."'
                fi
                if command -v wlsunset &>/dev/null; then
                    wlsunset -t 3500 -T 6500 &
                    tnotify "Night Light" "Enabled (warm filter)"
                fi
            fi
        fi
    done
}

screen_menu() {
    while true; do
    SCREEN_OPTS="󰃠 Brightness Up (+10%)
󰃟 Brightness Down (-10%)
─────────────────────────────────
󰍹 Display Outputs
󰌢 Display Layout (GUI)
─────────────────────────────────
󰌍 Back"
    S_CHOICE=$(echo -e "$SCREEN_OPTS" | tfuzzel -d -p " 󰌢 Screen | ")

    if [[ "$S_CHOICE" =~ "Back" || -z "$S_CHOICE" ]]; then return; fi

    if [[ "$S_CHOICE" =~ "Brightness Up" ]]; then brightnessctl set +10%
    elif [[ "$S_CHOICE" =~ "Brightness Down" ]]; then brightnessctl set 10%-
    elif [[ "$S_CHOICE" =~ "Display Outputs" ]]; then display_output_menu
    elif [[ "$S_CHOICE" =~ "Display Layout" ]]; then
        if command -v wdisplays &>/dev/null; then
            wdisplays &
        else
            notify-send "Display" "wdisplays not installed. Install via More > Software."
        fi
    fi
    done
}

display_output_menu() {
    # Get connected outputs from swaymsg
    OUTPUTS=$(swaymsg -t get_outputs 2>/dev/null | python3 -c "
import json, sys
try:
    outputs = json.load(sys.stdin)
    for o in outputs:
        name = o['name']
        make = o.get('make', '')
        model = o.get('model', '')
        res = f\"{o['current_mode']['width']}x{o['current_mode']['height']}\" if o.get('current_mode') else 'off'
        active = '●' if o.get('active') else '○'
        print(f'{active} {name} - {make} {model} ({res})')
except:
    pass
" 2>/dev/null)
    if [ -z "$OUTPUTS" ]; then
        notify-send "Display" "No outputs detected"
        return
    fi
    D_OPTS="$OUTPUTS
─────────────────────────────────
󰍺 Mirror All
󰇄 Extend Right
─────────────────────────────────
󰌍 Back"
    D_CHOICE=$(echo -e "$D_OPTS" | tfuzzel -d -p " 󰍹 Outputs | ")
    if [[ "$D_CHOICE" =~ "Back" || -z "$D_CHOICE" ]]; then return; fi
    if [[ "$D_CHOICE" =~ "Mirror All" ]]; then
        # Get primary output resolution
        PRIMARY=$(swaymsg -t get_outputs 2>/dev/null | python3 -c "
import json, sys
outputs = json.load(sys.stdin)
if outputs:
    print(outputs[0]['name'])
" 2>/dev/null)
        if [ -n "$PRIMARY" ]; then
            for output in $(swaymsg -t get_outputs 2>/dev/null | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    print(o['name'])
" 2>/dev/null); do
                [ "$output" != "$PRIMARY" ] && swaymsg "output $output pos 0 0"
            done
            tnotify "Display" "Mirrored all outputs"
        fi
    elif [[ "$D_CHOICE" =~ "Extend Right" ]]; then
        # Position outputs side by side
        POS=0
        for output in $(swaymsg -t get_outputs 2>/dev/null | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    print(o['name'], o.get('current_mode',{}).get('width',1920))
" 2>/dev/null | sort); do
            NAME=$(echo "$output" | cut -d' ' -f1)
            WIDTH=$(echo "$output" | cut -d' ' -f2)
            swaymsg "output $NAME pos $POS 0"
            POS=$((POS + WIDTH))
        done
        tnotify "Display" "Extended outputs to the right"
    elif [[ "$D_CHOICE" =~ "●" ]] || [[ "$D_CHOICE" =~ "○" ]]; then
        # Clicked on a specific output — toggle enable/disable
        OUTPUT_NAME=$(echo "$D_CHOICE" | awk '{print $2}')
        if [[ "$D_CHOICE" =~ "●" ]]; then
            swaymsg "output $OUTPUT_NAME disable"
            tnotify "Display" "$OUTPUT_NAME disabled"
        else
            swaymsg "output $OUTPUT_NAME enable"
            tnotify "Display" "$OUTPUT_NAME enabled"
        fi
    fi
}

screenshot_menu() {
    if ! command -v grim &>/dev/null; then
        notify-send "Screenshots" "Not installed. Use Install Essentials menu."
        return
    fi
    
    SCR_OPTS="󰆟 Region (Clipboard)
󰹑 Full Screen (File)
󰷊 Open Screenshots Folder
─────────────────────────────────
󰌍 Back"
    S_CHOICE=$(echo -e "$SCR_OPTS" | tfuzzel -d -p " 󰄀 Snaps | ")

    if [[ "$S_CHOICE" =~ "Back" || -z "$S_CHOICE" ]]; then return; fi

    if [[ "$S_CHOICE" =~ "Region" ]]; then
        grim -g "$(slurp)" - | wl-copy && notify-send "Screenshot" "Region copied to clipboard"
    elif [[ "$S_CHOICE" =~ "Full Screen" ]]; then
        mkdir -p ~/Pictures/Screenshots
        grim ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
        notify-send "Screenshot" "Saved to ~/Pictures/Screenshots/"
    elif [[ "$S_CHOICE" =~ "Open Screenshots" ]]; then
        if command -v pcmanfm &>/dev/null; then
            pcmanfm ~/Pictures/Screenshots &
        else
            notify-send "File Manager" "Not installed"
        fi
    fi
}

lock_menu() {
    while true; do
    if ! command -v gtklock &>/dev/null; then
        tnotify "Screen Lock" "Not installed. Use Install Essentials menu."
        return
    fi

    if pgrep -x swayidle > /dev/null; then
        IDLE_STATE="ON"
        IDLE_LABEL="󰗊 Disable Auto-Lock (Currently: ON)"
    else
        IDLE_STATE="OFF"
        IDLE_LABEL="󰗈 Enable Auto-Lock (Currently: OFF)"
    fi

    if grep -q "bindsym.*exec gtklock" ~/.config/sway/config.user 2>/dev/null; then
        KEY_STATE="ON"
        KEY_LABEL="󰌌 Disable Super+L Keybind (Currently: ON)"
    else
        KEY_STATE="OFF"
        KEY_LABEL="󰌌 Enable Super+L Keybind (Currently: OFF)"
    fi

    LOCK_OPTS="󰌾 Lock Now
$IDLE_LABEL
$KEY_LABEL
󰔛 Set Lock Timeout
─────────────────────────────────
󰌍 Back"
    L_CHOICE=$(echo -e "$LOCK_OPTS" | tfuzzel -d -p " 󰌾 Lock | ")

    if [[ "$L_CHOICE" =~ "Back" || -z "$L_CHOICE" ]]; then return; fi

    if [[ "$L_CHOICE" =~ "Lock Now" ]]; then
        gtklock -d
    elif [[ "$L_CHOICE" =~ "Auto-Lock" ]]; then
        if [[ "$IDLE_STATE" == "ON" ]]; then
            pkill swayidle
            tnotify "Screen Lock" "Auto-lock disabled"
        else
            swayidle -w \
                timeout 300 'gtklock -d' \
                timeout 600 'swaymsg "output * power off"' \
                resume 'swaymsg "output * power on"' \
                before-sleep 'gtklock -d' &
            tnotify "Screen Lock" "Auto-lock enabled (5 min)"
        fi
    elif [[ "$L_CHOICE" =~ "Super+L" ]]; then
        mkdir -p ~/.config/sway
        if [[ "$KEY_STATE" == "ON" ]]; then
            sed -i '/bindsym.*exec gtklock/d' ~/.config/sway/config.user 2>/dev/null
            swaymsg reload
            tnotify "Screen Lock" "Super+L keybind disabled"
        else
            echo 'bindsym $mod+l exec gtklock -d' >> ~/.config/sway/config.user
            swaymsg reload
            tnotify "Screen Lock" "Super+L keybind enabled"
        fi
    elif [[ "$L_CHOICE" =~ "Set Lock Timeout" ]]; then
        lock_timeout_menu
    fi
    done
}

lock_timeout_menu() {
    TO_OPTS="󰔛 1 minute
󰔛 3 minutes
󰔛 5 minutes (default)
󰔛 10 minutes
󰔛 15 minutes
󰔛 30 minutes
─────────────────────────────────
󰌍 Back"
    T_CHOICE=$(echo -e "$TO_OPTS" | tfuzzel -d -p " 󰔛 Timeout | ")

    if [[ "$T_CHOICE" =~ "Back" || -z "$T_CHOICE" ]]; then return; fi

    # Extract number of minutes (first number in the string)
    MINS=$(echo "$T_CHOICE" | sed 's/[^0-9]*//' | grep -oE '^[0-9]+')
    SECS=$((MINS * 60))
    SCREEN_OFF=$((SECS * 2))

     # Restart swayidle with new timeout
     pkill swayidle 2>/dev/null
     swayidle -w \
         timeout "$SECS" 'gtklock -d' \
         timeout "$SCREEN_OFF" 'swaymsg "output * power off"' \
         resume 'swaymsg "output * power on"' \
         before-sleep 'gtklock -d' &
     tnotify "Screen Lock" "Lock timeout set to $MINS minutes"
}

