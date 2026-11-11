# shellcheck shell=bash
# tebian-settings module: audio.sh
# Sourced by tebian-settings — do not run directly

# Audio submenu: mixer, output, input, microphone mute
audio_menu() {
    while true; do
        local out_label in_label mute_label choice out in
        if command -v wpctl &>/dev/null; then
            out=$(audio_default_name SINK)
            in=$(audio_default_name SOURCE)
            if [ -z "$in" ]; then
                mute_label="Microphone (None found)"
            elif mic_is_muted; then
                mute_label="Microphone (Muted)"
            else
                mute_label="Microphone (ON)"
            fi
            out_label="Output Device (${out:+Current: }${out:-None found})"
            in_label="Input Device (${in:+Current: }${in:-None found})"
        else
            out_label="Output Device (PipeWire Not Installed)"
            in_label="Input Device (PipeWire Not Installed)"
            mute_label="Microphone (PipeWire Not Installed)"
        fi

        choice=$(printf '%s\n' "󰕾 Audio Mixer" "󰓃 $out_label" "󰍬 $in_label" \
            "󰍭 $mute_label" "󰌍 Back" | tfuzzel -d -p " Audio | " --width 60)

        [ -n "$choice" ] || menu_close
        if is_back "$choice"; then return; fi

        # Matched from the start, after the glyph (none in text mode): the
        # labels carry device names, which could contain another label's words
        choice="${choice#"${choice%%[A-Za-z]*}"}"
        case "$choice" in
            "Audio Mixer"*)     audio_mixer ;;
            "Output Device"*)   audio_output_menu ;;
            "Input Device"*)    audio_input_menu ;;
            "Microphone"*)      mic_mute_toggle ;;
        esac
    done
}

audio_mixer() {
    if command -v pulsemixer &>/dev/null; then
        $TERM_CMD pulsemixer
    elif command -v pavucontrol &>/dev/null; then
        pavucontrol &
    else
        $TERM_CMD bash -c "echo 'No audio mixer found.'; echo ''; read -p 'Install pulsemixer now? [Y/n] ' a; [[ \"\$a\" =~ ^[Nn] ]] || sudo apt install -y pulsemixer; read -p 'Press Enter...'"
    fi
}

# wpctl ships with wireplumber, which the desktop install pulls in through
# pipewire-audio. A base install (sway, fuzzel, network-manager) has no sound
# server at all, so offer it rather than fail quietly.
audio_need_wpctl() {
    command -v wpctl &>/dev/null && return 0
    local c
    c=$(printf '%s\n' "󰏗 Install PipeWire (sound server)" "󰌍 Back" \
        | tfuzzel -d -p " PipeWire not installed | ")
    if [ -z "$c" ] || is_back "$c"; then return 1; fi
    if tebian_term_apt_install pipewire-audio wireplumber; then
        # The user services start on the next login, not in this session
        tnotify "Audio" "PipeWire installed. Log out and back in to use it."
    else
        tnotify "Audio" "PipeWire install failed"
    fi
    return 1
}

# Print the Audio devices of one wpctl status section, one per line:
#   <id>\t<1 if default, else 0>\t<name>
# Lines look like " │  *   55. Built-in Audio Analog Stereo   [vol: 0.65]".
# Only the "Audio" block counts: "Video" has its own Sinks and Sources
# (webcams), and "Filters" sits between Sources and Streams. A section ends
# at the next "├─ Name:" header. The id is the first number after the tree
# glyphs, so names with brackets or "2." inside them survive; only a
# trailing "[vol: ...]" is cut.
audio_nodes() {
    local want="$1"
    wpctl status 2>/dev/null | W="$want" awk '
        /^[^ \t]/ { top = $1; sect = ""; next }
        /─ [A-Za-z][A-Za-z ]*:[ \t]*$/ {
            s = $0
            sub(/^[^A-Za-z]*/, "", s); sub(/:[ \t]*$/, "", s)
            sect = s; next
        }
        top != "Audio" || sect != ENVIRON["W"] { next }
        match($0, /^[^0-9*]*\*?[ \t]*[0-9]+\./) {
            head = substr($0, 1, RLENGTH); name = substr($0, RLENGTH + 1)
            def = (index(head, "*") > 0)
            id = head; sub(/\.$/, "", id); sub(/^.*[^0-9]/, "", id)
            sub(/[ \t]+\[vol:[^]]*\][ \t]*$/, "", name)
            gsub(/^[ \t]+|[ \t]+$/, "", name)
            if (name == "") name = "Device " id
            print id "\t" def "\t" name
        }'
}

# Name of the default SINK or SOURCE, empty if there is none. Asked of the
# node itself rather than the starred status line: the default can be a
# filter (echo cancel, EQ) that is not listed under Sinks/Sources.
audio_default_name() {
    wpctl inspect "@DEFAULT_AUDIO_$1@" 2>/dev/null | awk '
        /^[ \t*]*node\.description = / { d = $0 }
        /^[ \t*]*node\.nick = /        { n = $0 }
        /^[ \t*]*node\.name = /        { m = $0 }
        END {
            v = d != "" ? d : (n != "" ? n : m)
            sub(/^[^=]*= "?/, "", v); sub(/"[ \t]*$/, "", v)
            print v
        }'
}

mic_is_muted() {
    wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED
}

audio_output_menu() { audio_pick_device Sinks; }
audio_input_menu()  { audio_pick_device Sources; }

# Picker for Sinks or Sources. Labels are device names; the default is
# marked "● current", and repeated names (two identical HDMI ports) get
# their position. Picked by position (--index): a device is named by its
# maker, and one called "Back" was taken for the Back entry.
audio_pick_device() {
    local sect="$1" kind title
    if [ "$sect" = Sinks ]; then kind="output"; title="󰓃 Output"
    else kind="input"; title="󰍬 Input"; fi
    audio_need_wpctl || return

    local -a ids=() defs=() names=() labels=()
    local id def name label n=0 cur="" seen l
    while IFS=$'\t' read -r id def name; do
        [ -n "$id" ] || continue
        label="$name"
        seen=0
        for l in "${names[@]}"; do [ "$l" = "$name" ] && seen=$((seen + 1)); done
        [ "$seen" -gt 0 ] && label="$name ($((seen + 1)))"
        [ "$def" = 1 ] && cur="$name"
        ids+=("$id"); defs+=("$def"); names+=("$name"); labels+=("$label")
        n=$((n + 1))
    done < <(audio_nodes "$sect")

    if [ "$n" -eq 0 ]; then
        tnotify "Audio" "No audio ${kind}s found"
        return
    fi
    if [ "$n" -eq 1 ] && [ -n "$cur" ]; then
        tnotify "Audio" "Only one audio $kind: $cur (in use)"
        return
    fi

    local pick i
    local -a shown=()
    for i in "${!labels[@]}"; do
        if [ "${defs[$i]}" = 1 ]; then shown+=("${labels[$i]}  ● current")
        else shown+=("${labels[$i]}"); fi
    done
    pick=$(printf '%s\n' "${shown[@]}" "󰌍 Back" | tfuzzel -d --index -p " $title | " --width 60)
    [ -n "$pick" ] || menu_close
    # Back, or typed text that matched nothing
    [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -lt "$n" ] || return
    [ "${defs[$pick]}" = 1 ] && return
    label="${labels[$pick]}"
    if wpctl set-default "${ids[$pick]}"; then
        tnotify "Audio ${kind^}" "Switched to $label"
    else
        tnotify "Audio ${kind^}" "Could not switch to $label"
    fi
}

# Set to the opposite of what it is, not "toggle": the state is read back
# for the label and the notification, and a toggle read straight after
# could still show the old state
mic_mute_toggle() {
    audio_need_wpctl || return
    if [ -z "$(audio_default_name SOURCE)" ]; then
        tnotify "Microphone" "No microphone found"
        return
    fi
    local want=1 _
    mic_is_muted && want=0
    if ! wpctl set-mute @DEFAULT_AUDIO_SOURCE@ "$want"; then
        tnotify "Microphone" "Could not change mute"
        return
    fi
    # The change lands a moment later; the menu redrawn next asks for it
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if [ "$want" = 1 ]; then mic_is_muted && break; else mic_is_muted || break; fi
        sleep 0.1
    done
    if [ "$want" = 1 ]; then
        tnotify "Microphone" "Microphone muted"
    else
        tnotify "Microphone" "Microphone on"
    fi
}
