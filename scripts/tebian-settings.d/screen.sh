# shellcheck shell=bash
# tebian-settings module: screen.sh
# Sourced by tebian-settings — do not run directly

# Save current output layout to persistent config so it survives restarts.
# Switched-off outputs are left out on purpose: a saved "disable" outlives
# the setup it was made for, and a laptop panel turned off while docked
# then stayed off after undocking, a black screen at every login.
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
        # Virtual screens report no refresh rate; "@0.000Hz" is not one sway accepts
        rate = f'@{r/1000:.3f}Hz' if r else ''
        lines.append(f'output {name} pos {x} {y} res {w}x{h}{rate}')
print('\n'.join(lines))
" > "$outfile" 2>/dev/null
}

# Screen submenu: brightness, displays, capture, lock, night light
screen_all_menu() {
    while true; do
        # Night light state
        if ! command -v wlsunset &>/dev/null; then
            NIGHT_LABEL="󰖔 Night Light (Not Installed)"
        elif pgrep -x wlsunset &>/dev/null; then
            NIGHT_LABEL="󰖔 Night Light (ON)"
        else
            NIGHT_LABEL="󰖔 Night Light (OFF)"
        fi

        S_OPTS="󰃠 $(brightness_label)
󰍹 Displays
󰄀 Capture (Print: screenshot, Super+Print: more)
󰌾 Lock & Idle (Super+L: lock now)
$NIGHT_LABEL
󰌍 Back"

        S_CHOICE=$(echo -e "$S_OPTS" | tfuzzel -d -p " Screen | ")

        [ -n "$S_CHOICE" ] || menu_close
        if is_back "$S_CHOICE"; then return; fi

        if [[ "$S_CHOICE" =~ "Brightness" ]]; then
            screen_menu
        elif [[ "$S_CHOICE" =~ "Displays" ]]; then
            display_output_menu
        elif [[ "$S_CHOICE" =~ "Capture" ]]; then
            capture_menu
        elif [[ "$S_CHOICE" =~ "Lock" ]]; then
            lock_menu
        elif [[ "$S_CHOICE" =~ "Night Light" ]]; then
            night_light_menu
        fi
    done
}

# CPU/RAM figures in the Classic bar (status.sh)
# CPU and RAM in the bar. Listed in Desktop & UI with the bar's other settings.
bar_stats_toggle() {
    mkdir -p "$HOME/.config/tebian"
    if [ -f "$HOME/.config/tebian/bar_perf_off" ]; then
        rm "$HOME/.config/tebian/bar_perf_off"
        tnotify "UI" "Bar stats on"
    else
        touch "$HOME/.config/tebian/bar_perf_off"
        tnotify "UI" "Bar stats off"
    fi
    # Restart status bar to apply
    pkill -f '\.local/bin/status\.sh' 2>/dev/null
    swaymsg reload >/dev/null 2>&1 &
}

night_light_menu() {
    # Install wlsunset if needed
    if ! command -v wlsunset &>/dev/null; then
        NL_CHOICE=$(printf '%s\n' "󰖔 Install Night Light (wlsunset)" "󰌍 Back" \
            | tfuzzel -d -p " 󰖔 Night Light (Not Installed) | ")
        [ -n "$NL_CHOICE" ] || menu_close
        if is_back "$NL_CHOICE"; then return; fi
        # Straight on to the settings once it is there, rather than back out
        if ! tebian_term_apt_install wlsunset || ! command -v wlsunset &>/dev/null; then
            tnotify "Night Light" "wlsunset could not be installed"
            return
        fi
    fi

    while true; do
        # Read saved temperature or default
        local CONF="$HOME/.config/tebian/nightlight.conf"
        local TEMP=$(cat "$CONF" 2>/dev/null)
        : "${TEMP:=3500}"

        local NL_ON=0 m45="" m35="" m25="" m15=""
        if pgrep -x wlsunset &>/dev/null; then
            NL_ON=1
            TOGGLE="󰖔 Night Light (ON)"
        else
            TOGGLE="󰖔 Night Light (OFF)"
        fi
        # The warmth it has, or will have when switched on
        case "$TEMP" in
            4500) m45="  ● current" ;;
            3500) m35="  ● current" ;;
            2500) m25="  ● current" ;;
            1500) m15="  ● current" ;;
        esac

        NL_OPTS="$TOGGLE
󰖔 Low Warmth (4500K)$m45
󰖔 Medium Warmth (3500K)$m35
󰖔 High Warmth (2500K)$m25
󰖔 Max Warmth (1500K)$m15
󰌍 Back"
        NL_CHOICE=$(echo "$NL_OPTS" | tfuzzel -d -p " 󰖔 Night Light | ")

        [ -n "$NL_CHOICE" ] || menu_close
        if is_back "$NL_CHOICE"; then return; fi

        local NEW_TEMP=""
        if [[ "$NL_CHOICE" =~ "Night Light" ]] && [ "$NL_ON" = 1 ]; then
            pkill -x wlsunset
            # It takes a moment to go, and the menu drawn next asks whether
            # it is running: without the wait it still said ON
            for _ in 1 2 3 4 5 6 7 8 9 10; do
                pgrep -x wlsunset >/dev/null || break
                sleep 0.1
            done
            # Stays off after the next login too
            tebian_block_remove nightlight
            tnotify "Night Light" "Off"
        elif [[ "$NL_CHOICE" =~ "Night Light" ]]; then
            NEW_TEMP=$TEMP
        elif [[ "$NL_CHOICE" =~ "Low" ]]; then
            NEW_TEMP=4500
        elif [[ "$NL_CHOICE" =~ "Medium" ]]; then
            NEW_TEMP=3500
        elif [[ "$NL_CHOICE" =~ "High" ]]; then
            NEW_TEMP=2500
        elif [[ "$NL_CHOICE" =~ "Max" ]]; then
            NEW_TEMP=1500
        fi

        if [ -n "$NEW_TEMP" ]; then
            TEMP=$NEW_TEMP
            mkdir -p "$(dirname "$CONF")"
            echo "$TEMP" > "$CONF"
            pkill -x wlsunset 2>/dev/null
            # Near-constant warmth: with the default sun-based schedule (lat/long 0)
            # the display would stay at the 6500K day temp during computed daytime
            wlsunset -t "$TEMP" -T $((TEMP + 100)) &
            disown
            # Started by sway at login as well; nothing did before, so it
            # was off again after every logout or reboot
            tebian_block_set nightlight "exec wlsunset -t $TEMP -T $((TEMP + 100))"
            tnotify "Night Light" "On (${TEMP}K)"
        fi
    done
}

# brightnessctl's view of the screen backlight: "<percent>", or "none"
# (a desktop monitor has none: its brightness is on its own buttons), or
# "missing" (not installed). -c backlight: the first device is otherwise
# whatever brightnessctl finds first, a keyboard light on some laptops.
brightness_level() {
    command -v brightnessctl &>/dev/null || { echo missing; return; }
    local pct
    pct=$(brightnessctl -m -c backlight 2>/dev/null | head -1 | cut -d, -f4)
    pct=${pct%\%}
    [[ "$pct" =~ ^[0-9]+$ ]] && echo "$pct" || echo none
}

brightness_label() {
    local lvl
    lvl=$(brightness_level)
    case "$lvl" in
        missing) echo "Brightness (Not Installed)" ;;
        none)    echo "Brightness (Not adjustable here)" ;;
        *)       echo "Brightness (Current: ${lvl}%)" ;;
    esac
}

screen_menu() {
    while true; do
    local lvl S_CHOICE
    lvl=$(brightness_level)
    if [ "$lvl" = missing ]; then
        # The base install has no brightnessctl; offer it, as the keys need it too
        if ! tebian_term_apt_install brightnessctl || ! command -v brightnessctl &>/dev/null; then
            tnotify "Brightness" "brightnessctl could not be installed"
            return
        fi
        continue
    fi
    if [ "$lvl" = none ]; then
        tnotify "Brightness" "No brightness control for this screen. Use the buttons on the monitor."
        return
    fi
    S_CHOICE=$(printf '%s\n' "󰃠 Brighter (+10%)" "󰃟 Dimmer (-10%)" "󰌍 Back" \
        | tfuzzel -d -p " 󰃠 Brightness ${lvl}% | ")

    [ -n "$S_CHOICE" ] || menu_close
    if is_back "$S_CHOICE"; then return; fi

    if [[ "$S_CHOICE" =~ "Brighter" ]]; then
        brightnessctl -q -c backlight set +10% || tnotify "Brightness" "Could not change the brightness"
    elif [[ "$S_CHOICE" =~ "Dimmer" ]]; then
        brightnessctl -q -c backlight set 10%- || tnotify "Brightness" "Could not change the brightness"
    fi
    done
}

# wdisplays: resolution, refresh rate, scale and arrangement by dragging.
# Not in the desktop install, so it is offered when missing.
display_layout_gui() {
    if ! command -v wdisplays &>/dev/null && ! tebian_term_apt_install wdisplays; then
        tnotify "Display" "wdisplays could not be installed"
        return
    fi
    setsid -f wdisplays >/dev/null 2>&1 < /dev/null
}

# Each screen is a switch: "<name> <make model> (ON: <size>)" or "(OFF)".
# Picked by its connector name (the first word), which sway keeps unique
# and which holds no spaces; the make and model are whatever the monitor
# reports and could hold any words.
display_output_menu() {
    while true; do
    local output_json
    output_json=$(swaymsg -t get_outputs 2>/dev/null)

    OUTPUTS=$(echo "$output_json" | python3 -c "
import json, sys
try:
    for o in json.load(sys.stdin):
        desc = ' '.join(w for w in (o.get('make', ''), o.get('model', '')) if w and w != 'Unknown')
        m = o.get('current_mode')
        state = f\"ON: {m['width']}x{m['height']}\" if o.get('active') and m else 'OFF'
        print(f\"{o['name']}{'  ' + desc if desc else ''} ({state})\")
except Exception:
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

    local -a names=() states=() rows=()
    local line gui="󰌢 Resolution, Scale & Arrangement (wdisplays)"
    command -v wdisplays &>/dev/null || gui="󰌢 Resolution, Scale & Arrangement (Not Installed)"
    while IFS= read -r line; do
        names+=("${line%% *}"); rows+=("󰍹 $line")
        if [[ "$line" == *"(OFF)" ]]; then states+=(off); else states+=(on); fi
    done <<< "$OUTPUTS"
    # Only show layout options when multiple outputs are connected. No
    # "Mirror All": sway cannot mirror outputs; stacking them all at 0,0
    # showed different workspaces on each with a confused cursor
    if [ "$output_count" -gt 1 ]; then
        rows+=("───────────────" "󰇄 Extend Right" "󰇅 Extend Left" "󰆢 Extend Above" \
            "󰆣 Extend Below" "󰍹 Position a Monitor...")
    fi
    rows+=("$gui" "󰌍 Back")

    D_CHOICE=$(printf '%s\n' "${rows[@]}" | tfuzzel -d -p " 󰍹 Displays | " --width 56)
    [ -n "$D_CHOICE" ] || menu_close
    if is_back "$D_CHOICE"; then return; fi

    local picked="" picked_state i
    line="${D_CHOICE#"${D_CHOICE%%[A-Za-z0-9]*}"}"
    for i in "${!names[@]}"; do
        [ "${line%% *}" = "${names[$i]}" ] && { picked=${names[$i]}; picked_state=${states[$i]}; }
    done

    if [ -n "$picked" ]; then
        if [ "$picked_state" = on ]; then
            # Never the last screen: nothing would be left to undo it from
            if [ "${output_count:-0}" -le 1 ]; then
                tnotify "Display" "$picked is the only screen on — not turning it off"
                continue
            fi
            swaymsg "output $picked disable" >/dev/null
            tnotify "Display" "$picked off until you log out or turn it back on"
        else
            swaymsg "output $picked enable" >/dev/null
            tnotify "Display" "$picked on"
        fi
        save_display_layout

    elif [[ "$D_CHOICE" =~ "Resolution, Scale" ]]; then
        display_layout_gui

    elif [[ "$D_CHOICE" =~ "Extend Right" ]]; then
        local pos=0
        echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o.get('active'):
        w = o.get('current_mode',{}).get('width',1920)
        print(o['name'], w)
" 2>/dev/null | while read -r name width; do
            swaymsg "output $name pos $pos 0" >/dev/null
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
                # (command substitution, not `| read` — that runs in a subshell
                # and the variable would stay empty)
                local total_ext
                total_ext=$(echo "$output_json" | python3 -c "
import json, sys
t = sum(o.get('current_mode',{}).get('width',1920) for o in json.load(sys.stdin) if o.get('active') and o['name'] != '$pname')
print(t)
" 2>/dev/null)
                swaymsg "output $name pos ${total_ext:-0} 0" >/dev/null
            else
                swaymsg "output $name pos $ext_offset 0" >/dev/null
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
        local pname ext_h
        pname=$(echo "$primary" | cut -d' ' -f1)
        # Primary sits below the externals, so offset it by the tallest
        # EXTERNAL height — not its own
        ext_h=$(echo "$output_json" | python3 -c "
import json, sys
hs = [o.get('current_mode',{}).get('height',1080) for o in json.load(sys.stdin) if o.get('active') and o['name'] != '$pname']
print(max(hs) if hs else 0)
" 2>/dev/null)
        echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o.get('active'):
        print(o['name'])
" 2>/dev/null | while read -r name; do
            if [ "$name" = "$pname" ]; then
                swaymsg "output $name pos 0 ${ext_h:-0}" >/dev/null
            else
                swaymsg "output $name pos 0 0" >/dev/null
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
                swaymsg "output $name pos 0 0" >/dev/null
            else
                swaymsg "output $name pos 0 $pheight" >/dev/null
            fi
        done
        tnotify "Display" "Extended below"
        save_display_layout

    elif [[ "$D_CHOICE" =~ "Position a Monitor" ]]; then
        display_position_menu "$output_json"

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
        desc = ' '.join(w for w in (o.get('make', ''), o.get('model', '')) if w and w != 'Unknown')
        print(o['name'] + ('  ' + desc if desc else ''))
" 2>/dev/null)

    local pick
    pick=$(printf '%s\n' "$output_list" "󰌍 Back" | tfuzzel -d -p " Which monitor to move? | ")
    [ -n "$pick" ] || menu_close
    if is_back "$pick"; then return; fi

    local move_name
    move_name=$(echo "$pick" | awk '{print $1}')

    # Pick the anchor (relative to which monitor)
    local others
    others=$(echo "$output_json" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if o.get('active') and o['name'] != '$move_name':
        desc = ' '.join(w for w in (o.get('make', ''), o.get('model', '')) if w and w != 'Unknown')
        print(o['name'] + ('  ' + desc if desc else ''))
" 2>/dev/null)

    local anchor
    anchor=$(printf '%s\n' "$others" "󰌍 Back" | tfuzzel -d -p " Relative to which monitor? | ")
    if [ -z "$anchor" ] || is_back "$anchor"; then return; fi

    local anchor_name
    anchor_name=$(echo "$anchor" | awk '{print $1}')

    # Pick direction
    local dir
    dir=$(echo -e "󰇅 Left of $anchor_name
󰇄 Right of $anchor_name
󰆢 Above $anchor_name
󰆣 Below $anchor_name
󰌍 Back" | tfuzzel -d -p " Position $move_name | ")
    if [ -z "$dir" ] || is_back "$dir"; then return; fi

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

    local where
    if [[ "$dir" =~ "Left" ]]; then
        where="left of"
        swaymsg "output $move_name pos $((ax - mw)) $ay" >/dev/null
    elif [[ "$dir" =~ "Right" ]]; then
        where="right of"
        swaymsg "output $move_name pos $((ax + aw)) $ay" >/dev/null
    elif [[ "$dir" =~ "Above" ]]; then
        where="above"
        swaymsg "output $move_name pos $ax $((ay - mh))" >/dev/null
    elif [[ "$dir" =~ "Below" ]]; then
        where="below"
        swaymsg "output $move_name pos $ax $((ay + ah))" >/dev/null
    fi
    [ -n "$where" ] || return
    tnotify "Display" "$move_name moved $where $anchor_name"
    save_display_layout
}


lock_menu() {
    while true; do
    if ! command -v gtklock &>/dev/null; then
        # Offered here rather than sent off to Software > Install Essentials;
        # the same install as there (gtklock, swayidle and its setup)
        L_CHOICE=$(printf '%s\n' "󰌾 Install Screen Lock (gtklock)" "󰌍 Back" \
            | tfuzzel -d -p " 󰌾 Screen Lock (Not Installed) | ")
        [ -n "$L_CHOICE" ] || menu_close
        if is_back "$L_CHOICE"; then return; fi
        $TERM_CMD bash -c "
            sudo apt update && sudo apt install -y gtklock swayidle && tebian-lockscreen-setup
            read -p 'Press Enter...'
        "
        if ! command -v gtklock &>/dev/null; then
            tnotify "Screen Lock" "gtklock could not be installed"
            return
        fi
        continue
    fi

    # The saved setting is the truth (swayidle may just be restarting);
    # tebian_idle_start in tebian-common reads the same file at login
    local AUTOLOCK=on LOCK_MINUTES=5
    # shellcheck disable=SC1090
    [ -f "$TEBIAN_IDLE_CONF" ] && . "$TEBIAN_IDLE_CONF"
    if [ "$AUTOLOCK" = on ]; then
        IDLE_STATE="ON"
        IDLE_LABEL="󰗊 Auto-Lock (ON: after ${LOCK_MINUTES} min idle)"
    else
        IDLE_STATE="OFF"
        IDLE_LABEL="󰗈 Auto-Lock (OFF: still locks on suspend)"
    fi

    if grep -q "bindsym.*exec gtklock" ~/.config/sway/config.user 2>/dev/null; then
        KEY_STATE="ON"
        KEY_LABEL="󰌌 Super+L Locks the Screen (ON)"
    else
        KEY_STATE="OFF"
        KEY_LABEL="󰌌 Super+L Locks the Screen (OFF)"
    fi

    LOCK_OPTS="󰌾 Lock Now
$IDLE_LABEL
$KEY_LABEL
󰔛 Auto-Lock Timeout
󰌍 Back"
    L_CHOICE=$(echo -e "$LOCK_OPTS" | tfuzzel -d -p " 󰌾 Lock | " --width 56)

    [ -n "$L_CHOICE" ] || menu_close
    if is_back "$L_CHOICE"; then return; fi

    if [[ "$L_CHOICE" =~ "Lock Now" ]]; then
        gtklock -d
    elif [[ "$L_CHOICE" =~ "Auto-Lock Timeout" ]]; then
        lock_timeout_menu
    elif [[ "$L_CHOICE" =~ "Auto-Lock" ]]; then
        if [[ "$IDLE_STATE" == "ON" ]]; then
            tebian_idle_set off "$LOCK_MINUTES"
            tnotify "Screen Lock" "Auto-lock off (still locks on suspend)"
        else
            tebian_idle_set on "$LOCK_MINUTES"
            tnotify "Screen Lock" "Auto-lock on ($LOCK_MINUTES min)"
        fi
    elif [[ "$L_CHOICE" =~ "Super+L" ]]; then
        mkdir -p ~/.config/sway
        if [[ "$KEY_STATE" == "ON" ]]; then
            sed -i '/bindsym.*exec gtklock/d' ~/.config/sway/config.user 2>/dev/null
            tnotify "Screen Lock" "Super+L no longer locks the screen"
            swaymsg reload >/dev/null 2>&1 &
        else
            echo 'bindsym $mod+l exec gtklock -d' >> ~/.config/sway/config.user
            tnotify "Screen Lock" "Super+L locks the screen"
            swaymsg reload >/dev/null 2>&1 &
        fi
    fi
    done
}

lock_timeout_menu() {
    local AUTOLOCK=on LOCK_MINUTES=5 m label TO_OPTS=""
    # shellcheck disable=SC1090
    [ -f "$TEBIAN_IDLE_CONF" ] && . "$TEBIAN_IDLE_CONF"
    for m in 1 3 5 10 15 30; do
        label="󰔛 $m minutes"
        [ "$m" = 1 ] && label="󰔛 1 minute"
        [ "$m" = 5 ] && label+=" (default)"
        # Only while auto-lock is on: off, no timeout is in use
        [ "$AUTOLOCK" = on ] && [ "$m" = "$LOCK_MINUTES" ] && label+="  ● current"
        TO_OPTS+="$label"$'\n'
    done
    TO_OPTS+="󰌍 Back"
    T_CHOICE=$(printf '%s\n' "$TO_OPTS" | tfuzzel -d -p " 󰔛 Auto-Lock Timeout | ")

    [ -n "$T_CHOICE" ] || menu_close
    if is_back "$T_CHOICE"; then return; fi

    # Extract number of minutes (first number in the string)
    MINS=$(echo "$T_CHOICE" | sed 's/[^0-9]*//' | grep -oE '^[0-9]+')
    [[ "$MINS" =~ ^[0-9]+$ ]] || return

    # Picking a timeout implies auto-lock on; saved so it survives a login
    tebian_idle_set on "$MINS"
    tnotify "Screen Lock" "Auto-lock on, after $MINS min idle"
}

