# shellcheck shell=bash
# tebian-settings module: wifi-bt.sh
# Sourced by tebian-settings — do not run directly

wifi_menu() {
    while true; do
        # Get current WiFi state
        WIFI_STATE=$(nmcli radio wifi)

        if [ "$WIFI_STATE" = "disabled" ]; then
            # WiFi is OFF - show toggle to enable
            W_OPTS="󰤮 WiFi (OFF)
󰌍 Back"

            W_CHOICE=$(echo -e "$W_OPTS" | tfuzzel -d -p " 󰖩 WiFi | ")

            [ -n "$W_CHOICE" ] || menu_close
            if is_back "$W_CHOICE"; then return; fi

            if [[ "$W_CHOICE" =~ "WiFi (OFF)" ]]; then
                if nmcli radio wifi on; then
                    tnotify "WiFi" "WiFi on — scanning..."
                else
                    tnotify "WiFi" "Could not turn WiFi on"
                fi
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload >/dev/null 2>&1 &
                sleep 2
            fi
        else
            # WiFi is ON - scan and show networks
            notify-send -t 2000 "WiFi" "Scanning..." 2>/dev/null

            # Ensure the WiFi device is managed by NetworkManager
            local wifi_dev
            wifi_dev=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2 == "wifi" {print $1; exit}')
            if [ -n "$wifi_dev" ]; then
                local dev_state
                dev_state=$(nmcli -t -f DEVICE,STATE device 2>/dev/null | grep "^${wifi_dev}:" | cut -d: -f2)
                if [ "$dev_state" = "unmanaged" ]; then
                    nmcli device set "$wifi_dev" managed yes 2>/dev/null
                    sleep 2
                fi
            fi

            # Rescan with retry — some adapters need more time after boot.
            # Not without an adapter: that was five seconds' wait for nothing
            local scan_result=""
            if [ -n "$wifi_dev" ]; then
                nmcli dev wifi rescan 2>/dev/null
                sleep 2
                # SECURITY too, so open networks aren't asked for a password
                scan_result=$(nmcli -t -f SIGNAL,SECURITY,SSID device wifi list 2>/dev/null)
                if [ -z "$scan_result" ]; then
                    # Retry once if first scan returned empty
                    nmcli dev wifi rescan 2>/dev/null
                    sleep 3
                    scan_result=$(nmcli -t -f SIGNAL,SECURITY,SSID device wifi list 2>/dev/null)
                fi
            fi

            # Unescaped (terse mode writes : as \: and \ as \\)
            CURRENT_SSID=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep -m1 "^yes:" | cut -d: -f2- | nm_unescape)

            # One row per network, with what picking it means kept beside
            # it, and the pick read back by position (--index): network
            # names come from anyone nearby, and one named "Back", "WiFi
            # (ON)" or "Connected: x" was taken for that entry (Text Mode
            # also strips an emoji, so a name could not be matched back)
            local -a rows=() kinds=() ssids=() secs=()
            local signal sec ssid icon
            rows+=("󰖩 WiFi (ON)"); kinds+=(toggle); ssids+=(""); secs+=("")
            if [ -n "$CURRENT_SSID" ]; then
                rows+=("󰤨 $CURRENT_SSID  ● connected"); kinds+=(current); ssids+=("$CURRENT_SSID"); secs+=("")
            fi
            # Dedupe per SSID after the descending signal sort — nmcli emits one
            # row per BSS, so one network can appear half a dozen times
            while IFS=: read -r signal sec ssid; do
                ssid=$(printf '%s' "$ssid" | nm_unescape)
                [ -z "$ssid" ] && continue
                [ "$ssid" = "--" ] && continue
                [ "$ssid" = "$CURRENT_SSID" ] && continue
                if [ "$signal" -ge 80 ]; then icon="󰤨";
                elif [ "$signal" -ge 60 ]; then icon="󰤥";
                elif [ "$signal" -ge 40 ]; then icon="󰤢";
                elif [ "$signal" -ge 20 ]; then icon="󰤟";
                else icon="󰤯"; fi
                rows+=("$icon $ssid ($signal%)"); kinds+=(net); ssids+=("$ssid"); secs+=("$sec")
            done < <(printf '%s\n' "$scan_result" | sort -rn -t: | awk '{k=$0; sub(/^[^:]*:[^:]*:/,"",k)} !seen[k]++')

            if [ -z "$wifi_dev" ]; then
                rows+=("(No WiFi adapter found)"); kinds+=(none); ssids+=(""); secs+=("")
            elif [ ${#rows[@]} -eq 1 ]; then
                rows+=("(No networks found — try again)"); kinds+=(none); ssids+=(""); secs+=("")
            fi
            rows+=("󰌍 Back"); kinds+=(back); ssids+=(""); secs+=("")

            local pick
            # printf, not echo -e: a network named "Cafe\c" cut the menu off
            pick=$(printf '%s\n' "${rows[@]}" | tfuzzel -d --index -p " 󰖩 WiFi | " --width 50)
            [ -n "$pick" ] || menu_close
            # Typed text that matched nothing: show the list again
            [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -lt ${#rows[@]} ] || continue

            case "${kinds[$pick]}" in
                back) return ;;
                none) continue ;;
                toggle)
                    if nmcli radio wifi off; then
                        tnotify "WiFi" "WiFi off"
                    else
                        tnotify "WiFi" "Could not turn WiFi off"
                    fi
                    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload >/dev/null 2>&1 &
                    ;;
                current) wifi_current_menu "$CURRENT_SSID" "$wifi_dev" ;;
                net) wifi_connect "${ssids[$pick]}" "${secs[$pick]}" ;;
            esac
        fi
    done
}

# Undo nmcli's terse-mode escaping (\: and \\) on stdin
nm_unescape() {
    sed 's/\\\(.\)/\1/g'
}

# The network in use: disconnect, or forget its saved password
wifi_current_menu() {
    local ssid="$1" dev="$2" act err profile
    # The saved profile in use, which is often but not always named after
    # the network ("Home 1" after a second setup)
    profile=$(nmcli -g GENERAL.CONNECTION device show "${dev:-wlan0}" 2>/dev/null)
    : "${profile:=$ssid}"
    act=$(printf '%s\n' "󰤭 Disconnect" "󰆴 Forget (remove saved password)" "󰌍 Back" \
        | tfuzzel -d -p " $ssid | ")
    [ -n "$act" ] || return
    if [[ "$act" =~ "Disconnect" ]]; then
        if nmcli dev disconnect "${dev:-wlan0}" >/dev/null 2>&1 || nmcli con down id "$profile" >/dev/null 2>&1; then
            tnotify "WiFi" "Disconnected from $ssid"
        else
            tnotify "WiFi" "Could not disconnect from $ssid"
        fi
    elif [[ "$act" =~ "Forget" ]]; then
        # Disconnects as well: the connection goes with its profile
        if err=$(nmcli connection delete id "$profile" 2>&1 >/dev/null); then
            tnotify "WiFi" "Forgot $ssid"
        else
            tnotify "WiFi" "Could not forget $ssid: ${err#Error: }"
        fi
    else
        return
    fi
    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload >/dev/null 2>&1 &
}

# Connect to SSID. Arg 2 is its SECURITY from the scan ("" or "--" when
# open), so open networks aren't asked for a password.
wifi_connect() {
    local SSID="$1" sec="$2" err PASS rc

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
        INSTALL_BT=$(printf '%s\n' "󰂯 Install Bluetooth" "󰌍 Back" | tfuzzel -d -p " 󰂯 Bluetooth (Not Installed) | ")
        [ -n "$INSTALL_BT" ] || menu_close
        if is_back "$INSTALL_BT"; then return; fi
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
        # The terminal has closed by now; it said "Installed!" even when
        # the install had failed or been cancelled
        if ! command -v bluetoothctl &>/dev/null; then
            tnotify "Bluetooth" "Bluetooth could not be installed"
            return
        fi
        tnotify "Bluetooth" "Bluetooth installed"
    fi

    while true; do
        # bluetoothctl waits for bluetoothd and froze Settings when the
        # service wasn't running; ask systemd first, and cap every query
        if ! systemctl is-active --quiet bluetooth; then
            B_CHOICE=$(printf '%s\n' "󰂲 Bluetooth Service (Stopped)" "󰌍 Back" | tfuzzel -d -p " 󰂯 Bluetooth | ")
            [ -n "$B_CHOICE" ] || menu_close
            if is_back "$B_CHOICE"; then return; fi
            $TERM_CMD bash -c "sudo systemctl enable --now bluetooth || read -p 'Press Enter...'"
            if ! systemctl is-active --quiet bluetooth; then
                tnotify "Bluetooth" "The Bluetooth service could not be started"
                return
            fi
        fi

        # Get current power state
        BT_POWER=$(timeout 5 bluetoothctl show 2>/dev/null | grep -o "Powered: yes\|Powered: no" | head -1)

        if [[ "$BT_POWER" == "Powered: no" ]] || [ -z "$BT_POWER" ]; then
            # Bluetooth is OFF
            B_CHOICE=$(printf '%s\n' "󰂲 Bluetooth (OFF)" "󰌍 Back" | tfuzzel -d -p " 󰂯 Bluetooth | ")

            [ -n "$B_CHOICE" ] || menu_close
            if is_back "$B_CHOICE"; then return; fi

            if [[ "$B_CHOICE" =~ "Bluetooth (OFF)" ]]; then
                # A radio switched off by rfkill (airplane mode, a laptop
                # key) refuses power on until it is unblocked; the session
                # user may do that without root
                if ! timeout 5 bluetoothctl power on >/dev/null 2>&1; then
                    rfkill unblock bluetooth 2>/dev/null
                    sleep 1
                    timeout 5 bluetoothctl power on >/dev/null 2>&1
                fi
                if timeout 5 bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
                    tnotify "Bluetooth" "Bluetooth on"
                else
                    tnotify "Bluetooth" "Could not turn Bluetooth on (blocked by a hardware switch?)"
                fi
                pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload >/dev/null 2>&1 &
                sleep 1
            fi
        else
            # Bluetooth is ON. One row per device, with its address and
            # state kept beside it, and the pick read back by position
            # (--index): device names are chosen by whoever owns the
            # device, and one named "Back" or "Scan for new devices", or
            # with "(connected)" in it, was taken for that entry
            local -a rows=() kinds=() macs=() names=()
            local mac name connected=" "
            rows+=("󰂯 Bluetooth (ON)"); kinds+=(toggle); macs+=(""); names+=("")
            while read -r _ mac name; do
                [ -z "$mac" ] && continue
                connected+="$mac "
                rows+=("󰂱 $name [$mac] (connected)"); kinds+=(connected); macs+=("$mac"); names+=("$name")
            done < <(timeout 5 bluetoothctl devices Connected 2>/dev/null)
            # Paired but not connected
            while read -r _ mac name; do
                [ -z "$mac" ] && continue
                [[ "$connected" == *" $mac "* ]] && continue
                rows+=("󰂯 $name [$mac] (paired)"); kinds+=(paired); macs+=("$mac"); names+=("$name")
            done < <(timeout 5 bluetoothctl devices Paired 2>/dev/null)
            rows+=("󰴈 Scan for new devices..." "󰀱 Open Blueman (full manager)" "󰌍 Back")
            kinds+=(scan blueman back); macs+=("" "" ""); names+=("" "" "")

            local pick
            # printf, not echo -e: escapes in a device name rewrote the menu
            pick=$(printf '%s\n' "${rows[@]}" | tfuzzel -d --index -p " 󰂯 Bluetooth | " --width 50)
            [ -n "$pick" ] || menu_close
            # Typed text that matched nothing: show the list again
            [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -lt ${#rows[@]} ] || continue
            DEV_MAC=${macs[$pick]}; DEV_NAME=${names[$pick]}

            case "${kinds[$pick]}" in
                back) return ;;
                toggle)
                    if timeout 5 bluetoothctl power off >/dev/null 2>&1; then
                        tnotify "Bluetooth" "Bluetooth off"
                    else
                        tnotify "Bluetooth" "Could not turn Bluetooth off"
                    fi
                    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload >/dev/null 2>&1 &
                    ;;
                scan) bt_scan_and_pair ;;
                blueman)
                    # bluetuith isn't packaged for Debian; Blueman ships with
                    # the Tebian desktop and is the full GUI manager
                    if command -v blueman-manager &>/dev/null || tebian_term_apt_install blueman; then
                        setsid blueman-manager >/dev/null 2>&1 &
                    else
                        tnotify "Bluetooth" "Blueman could not be installed"
                    fi
                    ;;
                connected)
                    ACTION=$(printf '%s\n' "󰂲 Disconnect" " Forget (unpair)" "󰌍 Back" | tfuzzel -d -p " $DEV_NAME | ")
                    if [[ "$ACTION" =~ "Disconnect" ]]; then
                        if timeout 10 bluetoothctl disconnect "$DEV_MAC" >/dev/null 2>&1; then
                            tnotify "Bluetooth" "Disconnected from $DEV_NAME"
                        else
                            tnotify "Bluetooth" "Could not disconnect from $DEV_NAME"
                        fi
                        pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload >/dev/null 2>&1 &
                    elif [[ "$ACTION" =~ "Forget" ]]; then
                        timeout 10 bluetoothctl disconnect "$DEV_MAC" >/dev/null 2>&1
                        bt_forget "$DEV_MAC" "$DEV_NAME"
                    fi
                    ;;
                paired)
                    ACTION=$(printf '%s\n' "󰂱 Connect" " Forget (unpair)" "󰌍 Back" | tfuzzel -d -p " $DEV_NAME | ")
                    if [[ "$ACTION" =~ "Connect" ]]; then
                        tnotify "Bluetooth" "Connecting to $DEV_NAME..."
                        # Explains a failure itself
                        tebian-panel-bluetooth connect "$DEV_MAC" &&
                            tnotify "Bluetooth" "Connected to $DEV_NAME"
                        pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload >/dev/null 2>&1 &
                    elif [[ "$ACTION" =~ "Forget" ]]; then
                        bt_forget "$DEV_MAC" "$DEV_NAME"
                    fi
                    ;;
            esac
        fi
    done
}

bt_forget() {
    if timeout 10 bluetoothctl remove "$1" >/dev/null 2>&1; then
        tnotify "Bluetooth" "Forgot $2"
    else
        tnotify "Bluetooth" "Could not forget $2"
    fi
    pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload >/dev/null 2>&1 &
}

# Dedicated scan + pair flow
bt_scan_and_pair() {
    # Pairable only: pairing with a device we found doesn't need this
    # computer to be visible to everyone nearby (discoverable)
    timeout 5 bluetoothctl pairable on >/dev/null 2>&1

    notify-send -t 5000 "Bluetooth" "Scanning... put your device in pairing mode" 2>/dev/null

    # Scan for devices (keep scan running long enough to find BLE devices)
    timeout 8 bluetoothctl --timeout 8 scan on >/dev/null 2>&1 &
    local SCAN_PID=$!
    sleep 8
    kill $SCAN_PID 2>/dev/null
    wait $SCAN_PID 2>/dev/null

    # Get all discovered devices, exclude already-paired
    local PAIRED_MACS
    PAIRED_MACS=" $(timeout 5 bluetoothctl devices Paired 2>/dev/null | awk '{print $2}' | tr '\n' ' ') "

    # By position (--index), as in the device list: the names are anyone's
    local -a rows=() macs=() names=()
    local mac name
    while read -r _ mac name; do
        [ -z "$mac" ] && continue
        [ -z "$name" ] && continue
        # Skip already paired
        [[ "$PAIRED_MACS" == *" $mac "* ]] && continue
        # Skip unnamed/placeholder devices
        [[ "$name" =~ ^[0-9A-F]{2}[-:] ]] && name="Unknown ($mac)"
        rows+=("󰂰 $name [$mac]"); macs+=("$mac"); names+=("$name")
    done < <(timeout 5 bluetoothctl devices 2>/dev/null)
    local found=${#rows[@]}
    [ "$found" -gt 0 ] || rows+=("(no new devices found)")
    rows+=("󰴈 Scan again" "󰌍 Back")

    local pick
    pick=$(printf '%s\n' "${rows[@]}" | tfuzzel -d --index -p " 󰂰 New devices | " --width 50)

    if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -lt "$found" ]; then
        tnotify "Bluetooth" "Pairing with ${names[$pick]}..."
        # The same pairing as the bar's panel: pair, trust, connect, with
        # tebian-bt-agent answering BlueZ. It explains failures itself.
        if tebian-panel-bluetooth pair "${macs[$pick]}"; then
            tnotify "Bluetooth" "Connected to ${names[$pick]}"
        fi
        pkill -f '\.local/bin/status\.sh' 2>/dev/null; swaymsg reload >/dev/null 2>&1 &
    elif [[ "$pick" =~ ^[0-9]+$ ]] && [ "${rows[$pick]}" = "󰴈 Scan again" ]; then
        bt_scan_and_pair
        return
    fi
    timeout 5 bluetoothctl pairable off >/dev/null 2>&1
}
