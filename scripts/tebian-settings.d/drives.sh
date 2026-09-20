# Drives — USB automount, repair offers and safe eject.
# The work happens in tebian-drive-doctor; this is only its control panel.

# True while the session watcher is alive
_drive_doctor_running() {
    local pid
    pid=$(cat "${XDG_RUNTIME_DIR:-/tmp}/tebian-drive-doctor/watch.pid" 2>/dev/null)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

# Installs from before Drive Doctor existed have a sway config without its
# exec line, and tebian-update never rewrites that file. config.user is the
# include that is ours to append to.
_drive_doctor_autostart() {
    grep -qs "tebian-drive-doctor" "$HOME/.config/sway/config" "$HOME/.config/sway/config.user" && return
    mkdir -p "$HOME/.config/sway"
    idempotent_append "exec_always bash -c 'command -v tebian-drive-doctor && tebian-drive-doctor watch' # tebian-drive-doctor" \
        "$HOME/.config/sway/config.user"
}

drives_menu() {
    local flag_off="$HOME/.config/tebian/drive_doctor_off"
    local flag_ask="$HOME/.config/tebian/drive_automount_off"
    local pid_file="${XDG_RUNTIME_DIR:-/tmp}/tebian-drive-doctor/watch.pid"
    local rule="/etc/udev/rules.d/90-tebian-drive-doctor.rules"
    local probe="/usr/local/bin/tebian-drive-probe"

    while true; do
        local opts disk part label mounted

        if [ -f "$flag_off" ]; then
            opts="󰋊 Drive Doctor (Current: Off)"
        elif _drive_doctor_running; then
            opts="󰋊 Drive Doctor (Current: On)"
        else
            opts="󰋊 Drive Doctor (Current: Not running — select to start)"
        fi
        if [ -f "$flag_ask" ]; then
            opts+="\n󰑓 Healthy Drives (Current: Ask before mounting)"
        else
            opts+="\n󰑓 Healthy Drives (Current: Mount automatically)"
        fi
        opts+="\n󰍉 Check Plugged-in Drives Now"

        # Without the root-side probe, sick drives are only noticed once a
        # mount has already failed — offer the install rather than hide it
        if [ ! -f "$rule" ] || [ ! -x "$probe" ]; then
            opts+="\n󰒃 Install Health Probe (Missing — needs sudo)"
        fi

        # One eject entry per USB disk that has something mounted
        while read -r disk; do
            mounted=""
            while read -r part; do
                findmnt -n -S "$part" >/dev/null 2>&1 && mounted=1
            done < <(lsblk -nrpo NAME "$disk")
            [ -n "$mounted" ] || continue
            label=$(lsblk -nro LABEL "$disk" | grep -m1 .) || label="USB drive"
            opts+="\n⏏ Eject $label ($disk)"
        done < <(lsblk -dnrpo NAME,TRAN | awk '$2=="usb"{print $1}')

        opts+="\n󰌍 Back"

        D_CHOICE=$(echo -e "$opts" | tfuzzel -d -p " 󰋊 Drives | ")
        if is_back "$D_CHOICE"; then return; fi

        if [[ "$D_CHOICE" =~ "Drive Doctor" ]]; then
            mkdir -p "$HOME/.config/tebian"
            if [ -f "$flag_off" ] || ! _drive_doctor_running; then
                rm -f "$flag_off"
                _drive_doctor_autostart
                setsid tebian-drive-doctor watch >/dev/null 2>&1 &
                tnotify "Drives" "Drive Doctor on — USB drives mount when plugged in"
            else
                touch "$flag_off"
                [ -f "$pid_file" ] && kill "$(cat "$pid_file")" 2>/dev/null
                tnotify "Drives" "Drive Doctor off — USB drives are left alone"
            fi
        elif [[ "$D_CHOICE" =~ "Healthy Drives" ]]; then
            mkdir -p "$HOME/.config/tebian"
            if [ -f "$flag_ask" ]; then
                rm -f "$flag_ask"
                tnotify "Drives" "Healthy drives mount automatically"
            else
                touch "$flag_ask"
                tnotify "Drives" "You'll be asked before any drive is mounted"
            fi
        elif [[ "$D_CHOICE" =~ "Check Plugged-in" ]]; then
            # --all: also re-ask about drives that were ignored earlier
            tebian-drive-doctor scan --all &
            return
        elif [[ "$D_CHOICE" =~ "Install Health Probe" ]]; then
            local _tdir="${TEBIAN_DIR:-$HOME/Tebian}"
            $TERM_CMD bash -c "
                echo 'Installing the Drive Doctor health probe (udev rule + root-owned script)...'
                sudo install -o root -g root -m 755 '$_tdir/scripts/tebian-drive-probe' '$probe' &&
                sudo install -o root -g root -m 644 '$_tdir/configs/udev/90-tebian-drive-doctor.rules' '$rule' &&
                sudo udevadm control --reload &&
                echo 'Done — replug any USB drive to have it checked.' ||
                echo 'Install failed.'
                read -rp 'Press Enter to close. '
            "
            tlog "Drives: health probe install attempted"
        elif [[ "$D_CHOICE" =~ Eject.*\((/dev/[a-zA-Z0-9]+)\) ]]; then
            tebian-drive-doctor eject "${BASH_REMATCH[1]}"
        fi
    done
}
