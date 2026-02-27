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

            if [[ "$W_CHOICE" =~ "Back" || -z "$W_CHOICE" ]]; then return; fi

            if [[ "$W_CHOICE" =~ "WiFi: OFF" ]]; then
                nmcli radio wifi on
                tnotify "WiFi" "Enabled - scanning..."
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
                sleep 2
            fi
        else
            # WiFi is ON - scan and show networks
            notify-send -t 2000 "WiFi" "Scanning..." 2>/dev/null
            nmcli dev wifi rescan 2>/dev/null; sleep 1

            # Get current connection
            CURRENT_SSID=$(nmcli -t -f ACTIVE,SSID dev wifi | grep "^yes:" | cut -d: -f2)
            [ -n "$CURRENT_SSID" ] && CURRENT_LABEL="󰤨 Connected: $CURRENT_SSID" || CURRENT_LABEL=""

            # Get available networks (terse mode handles SSIDs with spaces)
            WIFI_LIST=$(nmcli -t -f SIGNAL,SSID device wifi list 2>/dev/null | sort -rn -t: | while IFS=: read -r signal ssid; do
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

            W_OPTS="󰤮 Turn WiFi OFF
$CURRENT_LABEL
$WIFI_LIST
─────────────────────────────────
󰌍 Back"

            SSID_RAW=$(echo -e "$W_OPTS" | tfuzzel -d -p " 󰖩 WiFi | ")

            if [[ "$SSID_RAW" =~ "Back" || -z "$SSID_RAW" ]]; then return; fi

            if [[ "$SSID_RAW" =~ "Turn WiFi OFF" ]]; then
                nmcli radio wifi off
                tnotify "WiFi" "Disabled"
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
            elif [[ "$SSID_RAW" =~ "Connected:" ]]; then
                # Offer to disconnect
                DISC=$(echo -e "No, keep connected\nYes, disconnect" | tfuzzel -d -p " Disconnect from $CURRENT_SSID? | ")
                if [[ "$DISC" =~ "Yes" ]]; then
                    nmcli dev disconnect wlan0 2>/dev/null || nmcli con down "$CURRENT_SSID" 2>/dev/null
                    tnotify "WiFi" "Disconnected from $CURRENT_SSID"
                    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
                fi
            else
                # Connect to selected network
                SSID=$(echo "$SSID_RAW" | sed 's/^[^ ]* //;s/ ([0-9]\{1,3\}%)$//')
                PASS=$(echo "" | tfuzzel -d --password -p " 󰷦 Password for $SSID | ")

                if [ -n "$PASS" ]; then
                    # Create temporary connection file to avoid password in ps aux
                    CONN_FILE=$(mktemp /tmp/tebian-wifi-XXXXXX)
                    chmod 600 "$CONN_FILE"
                    cat > "$CONN_FILE" <<WIFIEOF
[connection]
id=$SSID
type=wifi

[wifi]
ssid=$SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$PASS

[ipv4]
method=auto

[ipv6]
method=auto
WIFIEOF
                    unset PASS
                    nmcli connection load "$CONN_FILE" 2>/dev/null
                    rm -f "$CONN_FILE"
                    nmcli connection up "$SSID" 2>/dev/null && tnotify "WiFi" "Connected to $SSID" || tnotify "WiFi" "Connection failed"
                else
                    nmcli dev wifi connect "$SSID" && notify-send "WiFi" "Connected to $SSID" || tnotify "WiFi" "Connection failed"
                fi
            fi
        fi
    done
}

bluetooth_menu() {
    # Auto-install bluetooth if not present (Base mode doesn't include it)
    if ! command -v bluetoothctl &>/dev/null; then
        INSTALL_BT=$(echo -e "󰂯 Install Bluetooth\n󰌍 Back" | tfuzzel -d -p " Bluetooth not installed | ")
        if [[ "$INSTALL_BT" =~ "Install" ]]; then
            tnotify "Bluetooth" "Downloading Bluetooth..."
            $TERM_CMD bash -c "
                echo 'Installing Bluetooth...'
                sudo apt update && sudo apt install -y bluez blueman bluez-tools libspa-0.2-bluetooth rfkill
                sudo systemctl enable --now bluetooth
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
        # Get current power state
        BT_POWER=$(bluetoothctl show 2>/dev/null | grep -o "Powered: yes\|Powered: no" | head -1)

        if [[ "$BT_POWER" == "Powered: no" ]] || [ -z "$BT_POWER" ]; then
            # Bluetooth is OFF
            B_OPTS="󰂲 Bluetooth: OFF (click to enable)
󰌍 Back"

            B_CHOICE=$(echo -e "$B_OPTS" | tfuzzel -d -p " 󰂯 Bluetooth | ")

            if [[ "$B_CHOICE" =~ "Back" || -z "$B_CHOICE" ]]; then return; fi

            if [[ "$B_CHOICE" =~ "Bluetooth: OFF" ]]; then
                bluetoothctl power on
                tnotify "Bluetooth" "Enabled"
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
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
󰀱 Open bluetuith (full manager)
─────────────────────────────────
󰌍 Back"

            B_CHOICE=$(echo -e "$B_OPTS" | sed '/^$/d' | tfuzzel -d -p " 󰂯 Bluetooth | ")

            if [[ "$B_CHOICE" =~ "Back" || -z "$B_CHOICE" ]]; then return; fi

            if [[ "$B_CHOICE" =~ "Turn Bluetooth OFF" ]]; then
                bluetoothctl power off
                tnotify "Bluetooth" "Disabled"
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null

            elif [[ "$B_CHOICE" =~ "Scan for new devices" ]]; then
                bt_scan_and_pair

            elif [[ "$B_CHOICE" =~ "Open bluetuith" ]]; then
                if command -v bluetuith &>/dev/null; then
                    $TERM_CMD bluetuith
                else
                    tnotify "Bluetooth" "bluetuith not installed"
                fi

            elif [[ "$B_CHOICE" =~ "(connected)" ]]; then
                # Connected device — offer disconnect or forget
                DEV_MAC=$(echo "$B_CHOICE" | grep -oP '\[\K[A-F0-9:]+(?=\])')
                DEV_NAME=$(echo "$B_CHOICE" | sed 's/^[^ ]* //;s/ \[.*$//')
                ACTION=$(echo -e "󰂲 Disconnect\n Forget (unpair)\n󰌍 Cancel" | tfuzzel -d -p " $DEV_NAME | ")
                if [[ "$ACTION" =~ "Disconnect" ]]; then
                    bluetoothctl disconnect "$DEV_MAC" 2>/dev/null
                    tnotify "Bluetooth" "Disconnected from $DEV_NAME"
                    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
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
                    if bluetoothctl connect "$DEV_MAC" 2>/dev/null; then
                        tnotify "Bluetooth" "Connected to $DEV_NAME"
                    else
                        tnotify "Bluetooth" "Failed to connect to $DEV_NAME"
                    fi
                    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
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
    # Enable pairing and discovery
    bluetoothctl pairable on 2>/dev/null
    bluetoothctl discoverable on 2>/dev/null

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
    DEV_CHOICE=$(echo -e "$DEV_OPTS" | sed '/^$/d' | tfuzzel -d -p " 󰂰 New devices | ")

    # Disable discoverable after scan
    bluetoothctl discoverable off 2>/dev/null

    if [[ "$DEV_CHOICE" =~ "Back" || -z "$DEV_CHOICE" ]]; then
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

    # bt-agent handles BLE pairing handshake — bluetoothctl can't register
    # an agent in non-interactive/scripted mode, so we use bt-agent from
    # bluez-tools as a standalone background daemon.
    pkill bt-agent 2>/dev/null; sleep 0.3
    bt-agent -c NoInputNoOutput &
    local AGENT_PID=$!
    sleep 0.5

    # Trust + pair + connect as separate commands (agent handles handshake)
    bluetoothctl trust "$SEL_MAC" 2>/dev/null
    sleep 0.5
    local PAIR_RESULT
    PAIR_RESULT=$(timeout 10 bluetoothctl pair "$SEL_MAC" 2>&1)

    if echo "$PAIR_RESULT" | grep -qi "pairing successful\|already paired"; then
        tnotify "Bluetooth" "Paired with $SEL_NAME — connecting..."
        sleep 1

        local CONN_RESULT
        CONN_RESULT=$(timeout 10 bluetoothctl connect "$SEL_MAC" 2>&1)

        if echo "$CONN_RESULT" | grep -qi "connection successful\|already connected"; then
            tnotify "Bluetooth" "Connected to $SEL_NAME"
        else
            tnotify "Bluetooth" "Paired but connect failed — try again from main menu"
        fi
    else
        if echo "$PAIR_RESULT" | grep -qi "not available\|timeout\|failed"; then
            tnotify "Bluetooth" "Pairing failed — make sure $SEL_NAME is in pairing mode"
        else
            tnotify "Bluetooth" "Pairing failed with $SEL_NAME"
        fi
    fi

    # Clean up agent
    kill $AGENT_PID 2>/dev/null; wait $AGENT_PID 2>/dev/null

    bluetoothctl pairable off 2>/dev/null
    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
}
