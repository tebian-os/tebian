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
                sudo apt update && sudo apt install -y bluez blueman libspa-0.2-bluetooth
                sudo systemctl enable --now bluetooth
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

            B_CHOICE=$(echo -e "$B_OPTS" | tfuzzel -d -p " Bluetooth | ")

            if [[ "$B_CHOICE" =~ "Back" || -z "$B_CHOICE" ]]; then return; fi

            if [[ "$B_CHOICE" =~ "Bluetooth: OFF" ]]; then
                bluetoothctl power on
                tnotify "Bluetooth" "Enabled - scanning..."
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
                sleep 2
            fi
        else
            # Bluetooth is ON - show devices
            # Start scan briefly to find devices (with cleanup trap)
            notify-send -t 3000 "Bluetooth" "Scanning for devices..." 2>/dev/null
            bluetoothctl scan on 2>/dev/null &
            SCAN_PID=$!
            trap "kill $SCAN_PID 2>/dev/null" RETURN
            sleep 2
            kill $SCAN_PID 2>/dev/null
            trap - RETURN

            # Get connected devices
            CONNECTED=$(bluetoothctl devices Connected 2>/dev/null | while read -r _ mac name; do
                echo "󰂱 $name (connected)"
            done)

            # Get paired but not connected
            PAIRED=$(bluetoothctl devices Paired 2>/dev/null | while read -r _ mac name; do
                echo "󰂯 $name"
            done)

            # Get available (discovered) devices
            AVAILABLE=$(bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
                echo "$name"
            done | sort -u)

            B_OPTS="󰂲 Turn Bluetooth OFF
$CONNECTED
$PAIRED
󰴈 Scan for new devices
󰀱 Open full manager (bluetuith)
─────────────────────────────────
󰌍 Back"

            B_CHOICE=$(echo -e "$B_OPTS" | tfuzzel -d -p " Bluetooth | ")

            if [[ "$B_CHOICE" =~ "Back" || -z "$B_CHOICE" ]]; then return; fi

            if [[ "$B_CHOICE" =~ "Turn Bluetooth OFF" ]]; then
                bluetoothctl power off
                tnotify "Bluetooth" "Disabled"
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
            elif [[ "$B_CHOICE" =~ "Scan for new devices" ]]; then
                tnotify "Bluetooth" "Scanning..."
                bluetoothctl scan on 2>/dev/null &
                sleep 3
                kill $! 2>/dev/null
            elif [[ "$B_CHOICE" =~ "Open full manager" ]]; then
                $TERM_CMD bluetuith
            elif [[ "$B_CHOICE" =~ "(connected)" ]]; then
                # Connected device - offer disconnect
                DEV_NAME=$(echo "$B_CHOICE" | sed 's/󰂱 //g' | sed 's/ (connected)//g')
                DEV_MAC=$(bluetoothctl devices Connected | grep "$DEV_NAME" | awk '{print $2}')
                bluetoothctl disconnect "$DEV_MAC"
                tnotify "Bluetooth" "Disconnected from $DEV_NAME"
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
            elif [[ -n "$B_CHOICE" ]]; then
                # Try to connect to selected device
                DEV_NAME=$(echo "$B_CHOICE" | sed 's/󰂱\|󰂯//g' | xargs)
                DEV_MAC=$(bluetoothctl devices | grep "$DEV_NAME" | awk '{print $2}')
                if [ -n "$DEV_MAC" ]; then
                    tnotify "Bluetooth" "Connecting to $DEV_NAME..."
                    bluetoothctl connect "$DEV_MAC" && notify-send "Bluetooth" "Connected to $DEV_NAME" || tnotify "Bluetooth" "Connection failed"
                    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload 2>/dev/null
                fi
            fi
        fi
    done
}

