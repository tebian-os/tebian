# shellcheck shell=bash
# tebian-settings module: wifi-bt.sh
# Sourced by tebian-settings — do not run directly

wifi_menu() {
    while true; do
        # Get current WiFi state
        WIFI_STATE=$(nmcli radio wifi)

        if [ "$WIFI_STATE" = "disabled" ]; then
            # WiFi is OFF - show toggle to enable
            W_OPTS="󰤮 WiFi: OFF (click to enable)
󰌍 Back"

            W_CHOICE=$(echo -e "$W_OPTS" | tfuzzel -d -p " 󰖩 WiFi | ")

            if is_back "$W_CHOICE"; then return; fi

            if [[ "$W_CHOICE" =~ "WiFi: OFF" ]]; then
                nmcli radio wifi on
                tnotify "WiFi" "Enabled - scanning..."
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null &
                sleep 2
            fi
        else
            # WiFi is ON - scan and show networks
            notify-send -t 2000 "WiFi" "Scanning..." 2>/dev/null

            # Ensure the WiFi device is managed by NetworkManager
            local wifi_dev
            wifi_dev=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '/wifi/{print $1; exit}')
            if [ -n "$wifi_dev" ]; then
                local dev_state
                dev_state=$(nmcli -t -f DEVICE,STATE device 2>/dev/null | grep "^${wifi_dev}:" | cut -d: -f2)
                if [ "$dev_state" = "unmanaged" ]; then
                    nmcli device set "$wifi_dev" managed yes 2>/dev/null
                    sleep 2
                fi
            fi

            # Rescan with retry — some adapters need more time after boot
            nmcli dev wifi rescan 2>/dev/null
            sleep 2
            local scan_result
            # SECURITY too, so open networks aren't asked for a password
            scan_result=$(nmcli -t -f SIGNAL,SECURITY,SSID device wifi list 2>/dev/null)
            if [ -z "$scan_result" ]; then
                # Retry once if first scan returned empty
                nmcli dev wifi rescan 2>/dev/null
                sleep 3
                scan_result=$(nmcli -t -f SIGNAL,SECURITY,SSID device wifi list 2>/dev/null)
            fi

            # Get current connection
            # -f2- keeps SSIDs containing colons intact; terse mode escapes : as \:
            CURRENT_SSID=$(nmcli -t -f ACTIVE,SSID dev wifi | grep "^yes:" | cut -d: -f2- | sed 's/\\:/:/g')
            [ -n "$CURRENT_SSID" ] && CURRENT_LABEL="󰤨 Connected: $CURRENT_SSID" || CURRENT_LABEL=""

            # Get available networks (terse mode handles SSIDs with spaces)
            # Dedupe per SSID after the descending signal sort — nmcli emits one
            # row per BSS, so one network can appear half a dozen times
            WIFI_LIST=$(echo "$scan_result" | sort -rn -t: | awk '{k=$0; sub(/^[^:]*:[^:]*:/,"",k)} !seen[k]++' | while IFS=: read -r signal _ ssid; do
                ssid=${ssid//\\:/:}
                [ -z "$ssid" ] && continue
                [ "$ssid" = "--" ] && continue
                [ "$ssid" = "$CURRENT_SSID" ] && continue
                if [ "$signal" -ge 80 ]; then icon="󰤨";
                elif [ "$signal" -ge 60 ]; then icon="󰤥";
                elif [ "$signal" -ge 40 ]; then icon="󰤢";
                elif [ "$signal" -ge 20 ]; then icon="󰤟";
                else icon="󰤯"; fi
                echo "$icon $ssid ($signal%)"
            done)

            # Show message if no networks found
            if [ -z "$WIFI_LIST" ] && [ -z "$CURRENT_SSID" ]; then
                WIFI_LIST="(No networks found — try again)"
            fi

            W_OPTS="󰤮 Turn WiFi OFF
$CURRENT_LABEL
$WIFI_LIST
󰌍 Back"

            # sed drops the blank row left by an empty CURRENT_LABEL. printf,
            # not echo -e: network names come from anyone nearby, and one
            # named "Cafe\c" cut the menu off at that point
            SSID_RAW=$(printf '%s\n' "$W_OPTS" | sed '/^$/d' | tfuzzel -d -p " 󰖩 WiFi | ")

            if is_back "$SSID_RAW"; then return; fi

            if [[ "$SSID_RAW" =~ "Turn WiFi OFF" ]]; then
                nmcli radio wifi off
                tnotify "WiFi" "Disabled"
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null &
            elif [[ "$SSID_RAW" =~ "Connected:" ]]; then
                # Offer to disconnect
                DISC=$(echo -e "No, keep connected\nYes, disconnect" | tfuzzel -d -p " Disconnect from $CURRENT_SSID? | ")
                if [[ "$DISC" =~ "Yes" ]]; then
                    local wifi_dev
                    wifi_dev=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '/wifi/{print $1; exit}')
                    nmcli dev disconnect "${wifi_dev:-wlan0}" 2>/dev/null || nmcli con down "$CURRENT_SSID" 2>/dev/null
                    tnotify "WiFi" "Disconnected from $CURRENT_SSID"
                    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null &
                fi
            elif [[ "$SSID_RAW" == *"No networks found"* ]]; then
                continue
            else
                # Connect to selected network — strip only known signal icons,
                # never the SSID's first word (icons are gone in no_icons mode)
                SSID=$(echo "$SSID_RAW" | sed -E 's/^[󰤨󰤥󰤢󰤟󰤯] //; s/ \([0-9]{1,3}%\)$//')
                wifi_connect "$SSID" "$scan_result"
            fi
        fi
    done
}

# Connect to SSID. Arg 2 is the SIGNAL:SECURITY:SSID scan, to tell open
# networks from secured ones.
wifi_connect() {
    local SSID="$1" scan="$2" sec="" err PASS rc
    sec=$(echo "$scan" | while IFS=: read -r _ s rest; do
        [ "${rest//\\:/:}" = "$SSID" ] && { echo "$s"; break; }
    done)

    # A saved network connects with what NetworkManager already knows,
    # instead of asking for the password every time
    if nmcli -t -f connection.id connection show id "$SSID" >/dev/null 2>&1; then
        tnotify "WiFi" "Connecting to $SSID..."
        if nmcli connection up id "$SSID" >/dev/null 2>&1; then
            tnotify "WiFi" "Connected to $SSID"
            return
        fi
        # Fall through: the saved password may be out of date
    fi

    if [ -z "$sec" ] || [ "$sec" = "--" ]; then
        err=$(nmcli dev wifi connect "$SSID" 2>&1 >/dev/null); rc=$?
    else
        # Esc cancels; before, an empty answer went on to connect anyway
        PASS=$(echo "" | tfuzzel -d --password -p " 󰷦 Password for $SSID | ")
        [ -n "$PASS" ] || return
        # (`nmcli connection load` refuses files outside NM's profile
        # dirs, so the old tempfile approach never connected. The
        # password is briefly visible in ps — acceptable on a
        # single-user desktop, and the tradeoff that actually works.)
        err=$(nmcli dev wifi connect "$SSID" password "$PASS" 2>&1 >/dev/null); rc=$?
        unset PASS
    fi
    if [ "$rc" -eq 0 ]; then
        tnotify "WiFi" "Connected to $SSID"
    else
        # nmcli says why (wrong password, out of range, ...)
        tnotify "WiFi" "Could not connect to $SSID: ${err#Error: }"
    fi
}

bluetooth_menu() {
    # Auto-install bluetooth if not present (Base mode doesn't include it)
    if ! command -v bluetoothctl &>/dev/null; then
        INSTALL_BT=$(echo -e "󰂯 Install Bluetooth\n󰌍 Back" | tfuzzel -d -p " Bluetooth not installed | ")
        if [[ "$INSTALL_BT" =~ "Install" ]]; then
            tnotify "Bluetooth" "Downloading Bluetooth..."
            $TERM_CMD bash -c "
                echo 'Installing Bluetooth...'
                sudo apt update && sudo apt install -y bluez blueman python3-dbus python3-gi libspa-0.2-bluetooth rfkill
                sudo systemctl enable --now bluetooth
                source ~/.local/bin/tebian-common && tebian_bt_agent_start
                systemctl --user restart pipewire wireplumber 2>/dev/null
                echo ''
                echo 'Done! Bluetooth is ready.'
                read -p 'Press Enter...'
            "
            tnotify "Bluetooth" "Installed!"
        fi
        # If install failed or user backed out, return
        command -v bluetoothctl &>/dev/null || return
    fi

    while true; do
        # bluetoothctl waits for bluetoothd and froze Settings when the
        # service wasn't running; ask systemd first, and cap every query
        if ! systemctl is-active --quiet bluetooth; then
            B_CHOICE=$(printf '%s\n' "󰂲 Bluetooth service is stopped — start it" "󰌍 Back" | tfuzzel -d -p " 󰂯 Bluetooth | ")
            if is_back "$B_CHOICE"; then return; fi
            $TERM_CMD bash -c "sudo systemctl enable --now bluetooth || read -p 'Press Enter...'"
            systemctl is-active --quiet bluetooth || return
        fi

        # Get current power state
        BT_POWER=$(timeout 5 bluetoothctl show 2>/dev/null | grep -o "Powered: yes\|Powered: no" | head -1)

        if [[ "$BT_POWER" == "Powered: no" ]] || [ -z "$BT_POWER" ]; then
            # Bluetooth is OFF
            B_OPTS="󰂲 Bluetooth: OFF (click to enable)
󰌍 Back"

            B_CHOICE=$(echo -e "$B_OPTS" | tfuzzel -d -p " 󰂯 Bluetooth | ")

            if is_back "$B_CHOICE"; then return; fi

            if [[ "$B_CHOICE" =~ "Bluetooth: OFF" ]]; then
                # A radio switched off by rfkill (airplane mode, a laptop
                # key) refuses power on until it is unblocked; the session
                # user may do that without root
                if ! timeout 5 bluetoothctl power on >/dev/null 2>&1; then
                    rfkill unblock bluetooth 2>/dev/null
                    sleep 1
                    timeout 5 bluetoothctl power on >/dev/null 2>&1
                fi
                if timeout 5 bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
                    tnotify "Bluetooth" "Enabled"
                else
                    tnotify "Bluetooth" "Could not turn Bluetooth on (blocked by a hardware switch?)"
                fi
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null &
                sleep 1
            fi
        else
            # Bluetooth is ON — build device lists

            # Connected devices
            CONNECTED=""
            while read -r _ mac name; do
                [ -z "$mac" ] && continue
                CONNECTED+="󰂱 $name [$mac] (connected)"$'\n'
            done < <(bluetoothctl devices Connected 2>/dev/null)

            # Paired but not connected
            PAIRED=""
            PAIRED_MACS=""
            while read -r _ mac name; do
                [ -z "$mac" ] && continue
                # Skip if already listed as connected
                if echo "$CONNECTED" | grep -q "$mac"; then continue; fi
                PAIRED+="󰂯 $name [$mac] (paired)"$'\n'
                PAIRED_MACS+="$mac "
            done < <(bluetoothctl devices Paired 2>/dev/null)

            B_OPTS="󰂲 Turn Bluetooth OFF
${CONNECTED}${PAIRED}󰴈 Scan for new devices...
󰀱 Open Blueman (full manager)
󰌍 Back"

            # printf, not echo -e: device names are chosen by whoever owns
            # the device, and escapes in them rewrote the menu
            B_CHOICE=$(printf '%s\n' "$B_OPTS" | sed '/^$/d' | tfuzzel -d -p " 󰂯 Bluetooth | ")

            if is_back "$B_CHOICE"; then return; fi

            if [[ "$B_CHOICE" =~ "Turn Bluetooth OFF" ]]; then
                bluetoothctl power off
                tnotify "Bluetooth" "Disabled"
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null &

            elif [[ "$B_CHOICE" =~ "Scan for new devices" ]]; then
                bt_scan_and_pair

            elif [[ "$B_CHOICE" =~ "Open Blueman" ]]; then
                # bluetuith isn't packaged for Debian; Blueman ships with
                # the Tebian desktop and is the full GUI manager
                if command -v blueman-manager &>/dev/null || tebian_term_apt_install blueman; then
                    setsid blueman-manager >/dev/null 2>&1 &
                else
                    tnotify "Bluetooth" "Blueman could not be installed"
                fi

            elif [[ "$B_CHOICE" =~ "(connected)" ]]; then
                # Connected device — offer disconnect or forget
                DEV_MAC=$(echo "$B_CHOICE" | grep -oP '\[\K[A-F0-9:]+(?=\])')
                DEV_NAME=$(echo "$B_CHOICE" | sed 's/^[^ ]* //;s/ \[.*$//')
                ACTION=$(echo -e "󰂲 Disconnect\n Forget (unpair)\n󰌍 Cancel" | tfuzzel -d -p " $DEV_NAME | ")
                if [[ "$ACTION" =~ "Disconnect" ]]; then
                    bluetoothctl disconnect "$DEV_MAC" 2>/dev/null
                    tnotify "Bluetooth" "Disconnected from $DEV_NAME"
                    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null &
                elif [[ "$ACTION" =~ "Forget" ]]; then
                    bluetoothctl disconnect "$DEV_MAC" 2>/dev/null
                    bluetoothctl remove "$DEV_MAC" 2>/dev/null
                    tnotify "Bluetooth" "Removed $DEV_NAME"
                fi

            elif [[ "$B_CHOICE" =~ "(paired)" ]]; then
                # Paired but not connected — offer connect or forget
                DEV_MAC=$(echo "$B_CHOICE" | grep -oP '\[\K[A-F0-9:]+(?=\])')
                DEV_NAME=$(echo "$B_CHOICE" | sed 's/^[^ ]* //;s/ \[.*$//')
                ACTION=$(echo -e "󰂱 Connect\n Forget (unpair)\n󰌍 Cancel" | tfuzzel -d -p " $DEV_NAME | ")
                if [[ "$ACTION" =~ "Connect" ]]; then
                    tnotify "Bluetooth" "Connecting to $DEV_NAME..."
                    # Explains a failure itself
                    tebian-panel-bluetooth connect "$DEV_MAC" &&
                        tnotify "Bluetooth" "Connected to $DEV_NAME"
                    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null &
                elif [[ "$ACTION" =~ "Forget" ]]; then
                    bluetoothctl remove "$DEV_MAC" 2>/dev/null
                    tnotify "Bluetooth" "Removed $DEV_NAME"
                fi
            fi
        fi
    done
}

# Dedicated scan + pair flow
bt_scan_and_pair() {
    # Pairable only: pairing with a device we found doesn't need this
    # computer to be visible to everyone nearby (discoverable)
    bluetoothctl pairable on 2>/dev/null

    notify-send -t 5000 "Bluetooth" "Scanning... put your device in pairing mode" 2>/dev/null

    # Scan for devices (keep scan running long enough to find BLE devices)
    timeout 8 bluetoothctl --timeout 8 scan on >/dev/null 2>&1 &
    local SCAN_PID=$!
    sleep 8
    kill $SCAN_PID 2>/dev/null
    wait $SCAN_PID 2>/dev/null

    # Get all discovered devices, exclude already-paired
    local PAIRED_MACS
    PAIRED_MACS=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}')

    local DISCOVERED=""
    while read -r _ mac name; do
        [ -z "$mac" ] && continue
        [ -z "$name" ] && continue
        # Skip already paired
        if echo "$PAIRED_MACS" | grep -q "$mac"; then continue; fi
        # Skip unnamed/placeholder devices
        [[ "$name" =~ ^[0-9A-F]{2}[-:] ]] && name="Unknown ($mac)"
        DISCOVERED+="󰂰 $name [$mac]"$'\n'
    done < <(bluetoothctl devices 2>/dev/null)

    if [ -z "$DISCOVERED" ]; then
        DISCOVERED="(no new devices found)"$'\n'
    fi

    local DEV_OPTS="${DISCOVERED}󰴈 Scan again
󰌍 Back"

    local DEV_CHOICE
    DEV_CHOICE=$(printf '%s\n' "$DEV_OPTS" | sed '/^$/d' | tfuzzel -d -p " 󰂰 New devices | ")

    if is_back "$DEV_CHOICE"; then
        bluetoothctl pairable off 2>/dev/null
        return
    fi

    if [[ "$DEV_CHOICE" =~ "Scan again" ]]; then
        bt_scan_and_pair
        return
    fi

    if [[ "$DEV_CHOICE" =~ "no new devices" ]]; then
        bluetoothctl pairable off 2>/dev/null
        return
    fi

    # Extract MAC from selection
    local SEL_MAC SEL_NAME
    SEL_MAC=$(echo "$DEV_CHOICE" | grep -oP '\[\K[A-F0-9:]+(?=\])')
    SEL_NAME=$(echo "$DEV_CHOICE" | sed 's/^[^ ]* //;s/ \[.*$//')

    if [ -z "$SEL_MAC" ]; then
        bluetoothctl pairable off 2>/dev/null
        return
    fi

    tnotify "Bluetooth" "Pairing with $SEL_NAME..."

    # The same pairing as the bar's panel: pair, trust, connect, with
    # tebian-bt-agent answering BlueZ. It explains failures itself.
    if tebian-panel-bluetooth pair "$SEL_MAC"; then
        tnotify "Bluetooth" "Connected to $SEL_NAME"
    fi

    bluetoothctl pairable off 2>/dev/null
    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null &
}
