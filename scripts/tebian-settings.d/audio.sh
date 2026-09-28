# shellcheck shell=bash
# tebian-settings module: audio.sh
# Sourced by tebian-settings — do not run directly

# Audio submenu (combines mixer + output)
audio_menu() {
    while true; do
        A_OPTS="󰕾 Audio Mixer
󰔡 Switch Output
󰌍 Back"

        A_CHOICE=$(echo -e "$A_OPTS" | tfuzzel -d -p " Audio | ")

        if is_back "$A_CHOICE"; then return; fi

        if [[ "$A_CHOICE" =~ "Mixer" ]]; then
            if command -v pulsemixer &>/dev/null; then
                $TERM_CMD pulsemixer
            elif command -v pavucontrol &>/dev/null; then
                pavucontrol &
            else
                $TERM_CMD bash -c "echo 'No audio mixer found.'; echo ''; read -p 'Install pulsemixer now? [Y/n] ' a; [[ \"\$a\" =~ ^[Nn] ]] || sudo apt install -y pulsemixer; read -p 'Press Enter...'"
            fi
        elif [[ "$A_CHOICE" =~ "Output" ]]; then
            audio_output_menu
        fi
    done
}

audio_output_menu() {
    # Parse wpctl's Sinks section. Real lines look like:
    #   " │  *   55. Built-in Audio Analog Stereo   [vol: 0.65]"
    # so strip the leading tree/asterisk junk down to the "<id>. name" and
    # bound the range by the next section header, not the first blank line
    # (which only appears after Streams).
    SINKS=$(wpctl status 2>/dev/null | awk '/Sinks:/,/Sources:/' \
        | grep -E '[0-9]+\.' \
        | sed -E 's/^[^0-9]*([0-9]+\.)/\1/; s/[[:space:]]+\[vol.*$//; s/[[:space:]]+$//')

    if [ -z "$SINKS" ]; then
        notify-send "Audio" "No audio outputs found"
        return
    fi

    # Build menu
    MENU="󰌍 Back
$SINKS"

    CHOICE=$(echo -e "$MENU" | tfuzzel -d -p " 󰔡 Output | " --width 40)

    if is_back "$CHOICE"; then
        return
    fi

    # Extract sink ID and set as default
    SINK_ID=$(echo "$CHOICE" | grep -oP '^\d+' | head -1)
    if [ -n "$SINK_ID" ]; then
        wpctl set-default "$SINK_ID"
        notify-send "Audio Output" "Switched to: $(echo "$CHOICE" | sed 's/^[0-9]\+\. //')"
    fi
}

