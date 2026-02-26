# tebian-settings module: audio.sh
# Sourced by tebian-settings — do not run directly

# Audio submenu (combines mixer + output)
audio_menu() {
    while true; do
        A_OPTS="󰕾 Audio Mixer\0icon\x1fmultimedia-volume-control
󰔡 Switch Output\0icon\x1faudio-speakers
─────────────────────────────────
󰌍 Back"

        A_CHOICE=$(echo -e "$A_OPTS" | tfuzzel -d -p " Audio | ")

        if [[ -z "$A_CHOICE" ]] || [[ "$A_CHOICE" =~ "Back" ]]; then return; fi

        if [[ "$A_CHOICE" =~ "Mixer" ]]; then
            if command -v pulsemixer &>/dev/null; then
                $TERM_CMD pulsemixer
            else
                $TERM_CMD bash -c "echo 'Audio Mixer not installed.'; echo ''; echo 'Install via: More > Essentials'; read -p 'Press Enter...'"
            fi
        elif [[ "$A_CHOICE" =~ "Output" ]]; then
            audio_output_menu
        fi
    done
}

audio_output_menu() {
    # Get list of audio sinks using wpctl's Sinks section specifically
    SINKS=$(wpctl status 2>/dev/null | awk '/Sinks:/,/^$/' | grep -E '^\s+[0-9]+\.' | sed 's/^\s*//')

    if [ -z "$SINKS" ]; then
        notify-send "Audio" "No audio outputs found"
        return
    fi

    # Build menu
    MENU="󰌍 Back
─────────────────────────────────
$SINKS"

    CHOICE=$(echo -e "$MENU" | tfuzzel -d -p " 󰔡 Output | " --width 40)

    if [[ -z "$CHOICE" ]] || [[ "$CHOICE" =~ "Back" ]]; then
        return
    fi

    # Extract sink ID and set as default
    SINK_ID=$(echo "$CHOICE" | grep -oP '^\d+' | head -1)
    if [ -n "$SINK_ID" ]; then
        wpctl set-default "$SINK_ID"
        notify-send "Audio Output" "Switched to: $(echo "$CHOICE" | sed 's/^\s*[0-9]\+\. //')"
    fi
}

