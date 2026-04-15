# tebian-settings module: screen.sh
# Sourced by tebian-settings — do not run directly

# Save current output layout to persistent config so it survives restarts
save_display_layout() {
    local outfile="$HOME/.config/sway/outputs"
    mkdir -p "$HOME/.config/sway"
    swaymsg -t get_outputs 2>/dev/null | python3 -c "
import json, sys
outputs = json.load(sys.stdin)
lines = []
for o in outputs:
    name = o['name']
    if o.get('active'):
        x = o.get('rect', {}).get('x', 0)
        y = o.get('rect', {}).get('y', 0)
        m = o.get('current_mode', {})
        w = m.get('width', 1920)
        h = m.get('height', 1080)
        r = m.get('refresh', 60000)
        lines.append(f'output {name} pos {x} {y} res {w}x{h}@{r/1000:.3f}Hz')
    else:
        lines.append(f'output {name} disable')
print('\n'.join(lines))
" > "$outfile" 2>/dev/null
}

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

        S_OPTS="󰃠 Brightness
󰍹 Displays
󰄀 Screenshots (Print: region, Shift+Print: full)
󰌾 Lock & Idle (Mod+L: lock now)
$PERF_LABEL
$NIGHT_LABEL
󰌍 Back"

        S_CHOICE=$(echo -e "$S_OPTS" | tfuzzel -d -p " Screen | ")

        if [[ -z "$S_CHOICE" ]] || [[ "$S_CHOICE" == *"󰌍 Back"* ]]; then return; fi

        if [[ "$S_CHOICE" =~ "Brightness" ]]; then
            screen_menu
        elif [[ "$S_CHOICE" =~ "Displays" ]]; then
            display_output_menu
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
            swaymsg reload 2>/dev/null &
        elif [[ "$S_CHOICE" =~ "Night Light" ]]; then
            night_light_menu
        fi
    done
}

night_light_menu() {
    # Install wlsunset if needed
    if ! command -v wlsunset &>/dev/null; then
        NL_OPTS="󰖔 Install Night Light (wlsunset)
󰌍 Back"
        NL_CHOICE=$(echo -e "$NL_OPTS" | tfuzzel -d -p " 󰖔 Night Light | ")
        if [[ "$NL_CHOICE" =~ "Install" ]]; then
            $TERM_CMD bash -c 'sudo apt update && sudo apt install -y wlsunset; echo "Done!"; read -p "Press Enter..."'
        fi
        return
    fi

    while true; do
        # Read saved temperature or default
        local CONF="$HOME/.config/tebian/nightlight.conf"
        local TEMP=$(cat "$CONF" 2>/dev/null)
        : "${TEMP:=3500}"

        if pgrep -x wlsunset &>/dev/null; then
            TOGGLE="󰖔 Turn Off"
        else
            TOGGLE="󰖔 Turn On"
        fi

        NL_OPTS="$TOGGLE
󰖔 Low Warmth (4500K)
󰖔 Medium Warmth (3500K)
󰖔 High Warmth (2500K)
󰖔 Max Warmth (1500K)
Current: ${TEMP}K
󰌍 Back"
        NL_CHOICE=$(echo -e "$NL_OPTS" | tfuzzel -d -p " 󰖔 Night Light | ")

        if [[ -z "$NL_CHOICE" ]] || [[ "$NL_CHOICE" == *"󰌍 Back"* ]] || [[ "$NL_CHOICE" =~ "Current" ]]; then return; fi

        if [[ "$NL_CHOICE" =~ "Turn Off" ]]; then
            pkill wlsunset
            tnotify "Night Light" "Disabled"
        elif [[ "$NL_CHOICE" =~ "Turn On" ]]; then
            pkill wlsunset 2>/dev/null
            wlsunset -t "$TEMP" -T 6500 &
            disown
            tnotify "Night Light" "Enabled (${TEMP}K)"
        elif [[ "$NL_CHOICE" =~ "Low" ]]; then
            TEMP=4500
            echo "$TEMP" > "$CONF"
            pkill wlsunset 2>/dev/null
            wlsunset -t "$TEMP" -T 6500 &
            disown
            tnotify "Night Light" "Low warmth (4500K)"
        elif [[ "$NL_CHOICE" =~ "Medium" ]]; then
            TEMP=3500
            echo "$TEMP" > "$CONF"
            pkill wlsunset 2>/dev/null
            wlsunset -t "$TEMP" -T 6500 &
            disown
            tnotify "Night Light" "Medium warmth (3500K)"
        elif [[ "$NL_CHOICE" =~ "High" ]]; then
            TEMP=2500
            echo "$TEMP" > "$CONF"
            pkill wlsunset 2>/dev/null
            wlsunset -t "$TEMP" -T 6500 &
            disown
            tnotify "Night Light" "High warmth (2500K)"
        elif [[ "$NL_CHOICE" =~ "Max" ]]; then
            TEMP=1500
            echo "$TEMP" > "$CONF"
            pkill wlsunset 2>/dev/null
            wlsunset -t "$TEMP" -T 6500 &
            disown
            tnotify "Night Light" "Max warmth (1500K)"
        fi
    done
}

screen_menu() {
    while true; do
    SCREEN_OPTS="󰃠 Brightness Up (+10%)
󰃟 Brightness Down (-10%)
󰍹 Display Outputs
󰌢 Display Layout (GUI)
󰌍 Back"
    S_CHOICE=$(echo -e "$SCREEN_OPTS" | tfuzzel -d -p " 󰌢 Screen | ")

    if [[ "$S_CHOICE" == *"󰌍 Back"* || -z "$S_CHOICE" ]]; then return; fi

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
    while true; do
    # Get connected outputs as JSON
    local output_json
    output_json=$(swaymsg -t get_outputs 2>/dev/null)

    OUTPUTS=$(echo "$output_json" | python3 -c "
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
        tnotify "Display" "No outputs detected"
        return
    fi

    # Count active outputs
    local output_count
    output_count=$(echo "$output_json" | python3 -c "
import json, sys
print(len([o for o in json.load(sys.stdin) if o.get('active')]))
" 2>/dev/null)

    D_OPTS="$OUTPUTS"
    # Only show layout options when multiple outputs are connected
    if [ "$output_count" -gt 1 ]; then
        D_OPTS+="\n───────────────"
        D_OPTS+="\n󰍺 Mirror All"
        D_OPTS+="\n󰇄 Extend Right"
        D_OPTS+="\n󰇅 Extend Left"
        D_OPTS+="\n󰆢 Extend Above"
        D_OPTS+="\n󰆣 Extend Below"
        D_OPTS+="\n󰍹 Position a Monitor..."
    fi
    D_OPTS+="\n󰌍 Back"

    D_CHOICE=$(echo -e "$D_OPTS" | tfuzzel -d -p " 󰍹 Displays | ")
    if [[ "$D_CHOICE" == *"󰌍 Back"* || -z "$D_CHOICE" ]]; then return; fi

    if [[ "$D_CHOICE" =~ "Mirror All" ]]; then
        local primary
        primary=$(echo "$output_json" | python3 -c "
import json, sys
outputs = json.load(sys.stdin)
if outputs: print(outputs[0]['name'])
" 2>/dev/null)
        if [ -n "$primary" ]; then
            echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    print(o['name'])
" 2>/dev/null | while read -r out; do
                [ "$out" != "$primary" ] && swaymsg "output $out pos 0 0"
            done
            tnotify "Display" "Mirrored all outputs"
            save_display_layout
        fi

    elif [[ "$D_CHOICE" =~ "Extend Right" ]]; then
        local pos=0
        echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o.get('active'):
        w = o.get('current_mode',{}).get('width',1920)
        print(o['name'], w)
" 2>/dev/null | while read -r name width; do
            swaymsg "output $name pos $pos 0"
            pos=$((pos + width))
        done
        tnotify "Display" "Extended right"
        save_display_layout

    elif [[ "$D_CHOICE" =~ "Extend Left" ]]; then
        # External on the left, primary on the right
        local primary_w
        primary_w=$(echo "$output_json" | python3 -c "
import json, sys
outputs = [o for o in json.load(sys.stdin) if o.get('active')]
if outputs: print(outputs[0]['name'], outputs[0].get('current_mode',{}).get('width',1920))
" 2>/dev/null)
        local pname pwidth
        pname=$(echo "$primary_w" | cut -d' ' -f1)
        pwidth=$(echo "$primary_w" | cut -d' ' -f2)
        local ext_offset=0
        echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o.get('active'):
        print(o['name'], o.get('current_mode',{}).get('width',1920))
" 2>/dev/null | while read -r name width; do
            if [ "$name" = "$pname" ]; then
                # Primary goes on the right — calculate total external width first
                local total_ext=0
                echo "$output_json" | python3 -c "
import json, sys
t = sum(o.get('current_mode',{}).get('width',1920) for o in json.load(sys.stdin) if o.get('active') and o['name'] != '$pname')
print(t)
" 2>/dev/null | read -r total_ext
                swaymsg "output $name pos $total_ext 0"
            else
                swaymsg "output $name pos $ext_offset 0"
                ext_offset=$((ext_offset + width))
            fi
        done
        tnotify "Display" "Extended left"
        save_display_layout

    elif [[ "$D_CHOICE" =~ "Extend Above" ]]; then
        local primary
        primary=$(echo "$output_json" | python3 -c "
import json, sys
outputs = [o for o in json.load(sys.stdin) if o.get('active')]
if outputs: print(outputs[0]['name'], outputs[0].get('current_mode',{}).get('height',1080))
" 2>/dev/null)
        local pname pheight
        pname=$(echo "$primary" | cut -d' ' -f1)
        pheight=$(echo "$primary" | cut -d' ' -f2)
        echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o.get('active'):
        print(o['name'], o.get('current_mode',{}).get('height',1080))
" 2>/dev/null | while read -r name height; do
            if [ "$name" = "$pname" ]; then
                swaymsg "output $name pos 0 $height"
            else
                swaymsg "output $name pos 0 0"
            fi
        done
        tnotify "Display" "Extended above"
        save_display_layout

    elif [[ "$D_CHOICE" =~ "Extend Below" ]]; then
        local primary
        primary=$(echo "$output_json" | python3 -c "
import json, sys
outputs = [o for o in json.load(sys.stdin) if o.get('active')]
if outputs: print(outputs[0]['name'], outputs[0].get('current_mode',{}).get('height',1080))
" 2>/dev/null)
        local pname pheight
        pname=$(echo "$primary" | cut -d' ' -f1)
        pheight=$(echo "$primary" | cut -d' ' -f2)
        echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o.get('active'):
        print(o['name'])
" 2>/dev/null | while read -r name; do
            if [ "$name" = "$pname" ]; then
                swaymsg "output $name pos 0 0"
            else
                swaymsg "output $name pos 0 $pheight"
            fi
        done
        tnotify "Display" "Extended below"
        save_display_layout

    elif [[ "$D_CHOICE" =~ "Position a Monitor" ]]; then
        display_position_menu "$output_json"

    elif [[ "$D_CHOICE" =~ "●" ]] || [[ "$D_CHOICE" =~ "○" ]]; then
        local out_name
        out_name=$(echo "$D_CHOICE" | awk '{print $2}')
        if [[ "$D_CHOICE" =~ "●" ]]; then
            swaymsg "output $out_name disable"
            tnotify "Display" "$out_name disabled"
            save_display_layout
        else
            swaymsg "output $out_name enable"
            tnotify "Display" "$out_name enabled"
            save_display_layout
        fi
    fi
    done
}

display_position_menu() {
    local output_json="$1"

    # List outputs for user to pick which one to move
    local output_list
    output_list=$(echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o.get('active'):
        name = o['name']
        make = o.get('make', '')
        model = o.get('model', '')
        print(f'{name} - {make} {model}')
" 2>/dev/null)

    local pick
    pick=$(echo -e "$output_list\n󰌍 Back" | tfuzzel -d -p " Which monitor to move? | ")
    if [[ "$pick" == *"󰌍 Back"* || -z "$pick" ]]; then return; fi

    local move_name
    move_name=$(echo "$pick" | awk '{print $1}')

    # Pick the anchor (relative to which monitor)
    local others
    others=$(echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o.get('active') and o['name'] != '$move_name':
        name = o['name']
        make = o.get('make', '')
        model = o.get('model', '')
        print(f'{name} - {make} {model}')
" 2>/dev/null)

    local anchor
    anchor=$(echo -e "$others\n󰌍 Back" | tfuzzel -d -p " Relative to which monitor? | ")
    if [[ "$anchor" == *"󰌍 Back"* || -z "$anchor" ]]; then return; fi

    local anchor_name
    anchor_name=$(echo "$anchor" | awk '{print $1}')

    # Pick direction
    local dir
    dir=$(echo -e "⬅️  Left of $anchor_name
➡️  Right of $anchor_name
⬆️  Above $anchor_name
⬇️  Below $anchor_name
󰌍 Back" | tfuzzel -d -p " Position $move_name | ")
    if [[ "$dir" == *"󰌍 Back"* || -z "$dir" ]]; then return; fi

    # Get anchor dimensions and position
    local anchor_info
    anchor_info=$(echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o['name'] == '$anchor_name':
        r = o.get('rect', {})
        m = o.get('current_mode', {})
        print(r.get('x',0), r.get('y',0), m.get('width',1920), m.get('height',1080))
        break
" 2>/dev/null)
    local ax ay aw ah
    ax=$(echo "$anchor_info" | cut -d' ' -f1)
    ay=$(echo "$anchor_info" | cut -d' ' -f2)
    aw=$(echo "$anchor_info" | cut -d' ' -f3)
    ah=$(echo "$anchor_info" | cut -d' ' -f4)

    local move_info
    move_info=$(echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o['name'] == '$move_name':
        m = o.get('current_mode', {})
        print(m.get('width',1920), m.get('height',1080))
        break
" 2>/dev/null)
    local mw mh
    mw=$(echo "$move_info" | cut -d' ' -f1)
    mh=$(echo "$move_info" | cut -d' ' -f2)

    if [[ "$dir" =~ "Left" ]]; then
        swaymsg "output $move_name pos $((ax - mw)) $ay"
    elif [[ "$dir" =~ "Right" ]]; then
        swaymsg "output $move_name pos $((ax + aw)) $ay"
    elif [[ "$dir" =~ "Above" ]]; then
        swaymsg "output $move_name pos $ax $((ay - mh))"
    elif [[ "$dir" =~ "Below" ]]; then
        swaymsg "output $move_name pos $ax $((ay + ah))"
    fi
    tnotify "Display" "$move_name positioned relative to $anchor_name"
    save_display_layout
}

screenshot_menu() {
    if ! command -v grim &>/dev/null; then
        notify-send "Screenshots" "Not installed. Use Install Essentials menu."
        return
    fi
    
    SCR_OPTS="󰆟 Region (Clipboard)
󰹑 Full Screen (File)
󰷊 Open Screenshots Folder
󰌍 Back"
    S_CHOICE=$(echo -e "$SCR_OPTS" | tfuzzel -d -p " 󰄀 Snaps | ")

    if [[ "$S_CHOICE" == *"󰌍 Back"* || -z "$S_CHOICE" ]]; then return; fi

    if [[ "$S_CHOICE" =~ "Region" ]]; then
        mkdir -p ~/Pictures/Screenshots
        FILE=~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
        grim -g "$(slurp)" "$FILE" && wl-copy < "$FILE" && notify-send "Screenshot" "Saved & copied to clipboard"
    elif [[ "$S_CHOICE" =~ "Full Screen" ]]; then
        mkdir -p ~/Pictures/Screenshots
        grim ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
        notify-send "Screenshot" "Saved to ~/Pictures/Screenshots/"
    elif [[ "$S_CHOICE" =~ "Open Screenshots" ]]; then
        if command -v thunar &>/dev/null; then
            thunar ~/Pictures/Screenshots &
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
󰌍 Back"
    L_CHOICE=$(echo -e "$LOCK_OPTS" | tfuzzel -d -p " 󰌾 Lock | ")

    if [[ "$L_CHOICE" == *"󰌍 Back"* || -z "$L_CHOICE" ]]; then return; fi

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
            tnotify "Screen Lock" "Super+L keybind disabled"
            swaymsg reload 2>/dev/null &
        else
            echo 'bindsym $mod+l exec gtklock -d' >> ~/.config/sway/config.user
            tnotify "Screen Lock" "Super+L keybind enabled"
            swaymsg reload 2>/dev/null &
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
󰌍 Back"
    T_CHOICE=$(echo -e "$TO_OPTS" | tfuzzel -d -p " 󰔛 Timeout | ")

    if [[ "$T_CHOICE" == *"󰌍 Back"* || -z "$T_CHOICE" ]]; then return; fi

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

