# shellcheck shell=bash
# tebian-settings module: system.sh
# Sourced by tebian-settings — do not run directly

# The facts are rows of their own so they are easy to read; picking one does
# nothing but show the page again
sysinfo_menu() {
    local HOSTNAME UPTIME KERNEL CPU MEM_TOTAL MEM_USED DISK_USED DISK_TOTAL GPU CHOICE
    while true; do
    HOSTNAME=$(hostname)
    UPTIME=$(uptime -p 2>/dev/null || uptime)
    KERNEL=$(uname -r)
    CPU=$(lscpu | grep "Model name" | sed 's/Model name:\s*//' | head -1)
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    GPU=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display" | head -1 | sed 's/.*: //')

    # printf, not echo -e: a CPU or GPU name may hold a backslash
    CHOICE=$(printf '%s\n' \
        "󰌢 Host: $HOSTNAME" \
        "󰓅 Uptime: $UPTIME" \
        "󰍛 Kernel: $KERNEL" \
        "󰚰 CPU: ${CPU:-Unknown}" \
        "󰍛 RAM: $MEM_USED / $MEM_TOTAL" \
        "󰋊 Disk: $DISK_USED / $DISK_TOTAL" \
        "󰢻 GPU: ${GPU:-Not detected}" \
        "󰚰 Easter Egg: TempleOS in a VM" \
        "󰌍 Back" | tfuzzel -d -p " 󰋅 About This Computer | " --width 50 --lines 15)
    [ -n "$CHOICE" ] || menu_close
    is_back "$CHOICE" && return

    if [[ "$(sysprefs_words "$CHOICE")" == "Easter Egg: TempleOS"* ]]; then
        temple_os
    fi
    done
}

temple_os() {
    $TERM_CMD bash -c "
        echo '╔══════════════════════════════════════╗'
        echo '║     GOD'\''S LONELY PROGRAMMER           ║'
        echo '║     TempleOS - Terry A. Davis         ║'
        echo '║     \"An act of God.\"                  ║'
        echo '╚══════════════════════════════════════╝'
        echo ''
        echo '  640x480. 16 colors. HolyC. No networking.'
        echo '  The way God intended.'
        echo ''
        if ! command -v qemu-system-x86_64 &>/dev/null; then
            echo '  QEMU not found. Installing...'
            sudo apt update && sudo apt install -y qemu-system-x86 qemu-utils
        fi
        TEMPLE_ISO=\"/tmp/TempleOS.iso\"
        if [ ! -f \"\$TEMPLE_ISO\" ]; then
            echo '  Downloading TempleOS ISO (~20MB)...'
            curl -fSL 'https://archive.org/download/TempleOS_ISO_Archive/TOS_Distro.ISO' \\
                -o \"\$TEMPLE_ISO\" 2>/dev/null || \\
            curl -fSL 'https://templeos.org/Downloads/TOS_Distro.ISO' \\
                -o \"\$TEMPLE_ISO\" || {
                echo '  Download failed. Try manually:'
                echo '  https://archive.org/details/TempleOS_ISO_Archive'
                read -p '  Press Enter...'
                exit 1
            }
        fi
        echo ''
        echo '  Launching TempleOS (live mode)...'
        echo '  (Close the QEMU window to exit)'
        echo ''
        qemu-system-x86_64 \\
            -m 512 \\
            -cdrom \"\$TEMPLE_ISO\" \\
            -boot d \\
            -display gtk \\
            -soundhw pcspk 2>/dev/null || \\
        qemu-system-x86_64 \\
            -m 512 \\
            -cdrom \"\$TEMPLE_ISO\" \\
            -boot d \\
            -display gtk
        echo ''
        echo '  God'\''s temple has closed.'
        read -p '  Press Enter...'
    "
}

# Copy the configs a backup covers into <dir> (dereferencing symlinks, so
# the backup holds files, not links into the repo)
backup_configs() {
    local dir="$1" item
    mkdir -p "$dir" || return 1
    for item in sway kitty fuzzel mako gtklock; do
        [ -d "$HOME/.config/$item" ] || continue
        cp -rL "$HOME/.config/$item" "$dir/" || return 1
    done
    for item in .bashrc .bash_profile .profile; do
        [ -f "$HOME/$item" ] || continue
        cp "$HOME/$item" "$dir/" || return 1
    done
    printf 'Tebian Backup - %s\nHostname: %s\n' "${dir##*/}" "$(hostname)" > "$dir/manifest.txt"
}

backup_menu() {
    while true; do
    BACKUP_OPTS="󰆏 Backup Configs to ~/Tebian-Backup
󰑋 Restore from Backup
󰈔 View Backups
󰌍 Back"

    B_CHOICE=$(echo -e "$BACKUP_OPTS" | tfuzzel -d -p " 󰆏 Backup | ")

    [ -n "$B_CHOICE" ] || menu_close
    if is_back "$B_CHOICE"; then return; fi

    if [[ "$B_CHOICE" =~ "Backup Configs" ]]; then
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        if backup_configs "$HOME/Tebian-Backup/$TIMESTAMP"; then
            tnotify "Backup Complete" "Saved to ~/Tebian-Backup/$TIMESTAMP"
        else
            tnotify "Backup" "Could not write ~/Tebian-Backup/$TIMESTAMP"
        fi

    elif [[ "$B_CHOICE" =~ "Restore" ]]; then
        BACKUP_DIR="$HOME/Tebian-Backup"

        # List available backups
        BACKUPS=$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -10)
        if [ -z "$BACKUPS" ]; then
            tnotify "Restore" "No backups found"
            continue
        fi
        # printf, not echo -e: a folder name may hold a backslash. A picker
        # inside the restore: Escape cancels it, back to this menu
        R_CHOICE=$(printf '%s\n' "󰌍 Back" "$BACKUPS" | tfuzzel -d -p " 󰑋 Restore | ")
        [ -n "$R_CHOICE" ] || continue
        if is_back "$R_CHOICE"; then
            continue
        fi

        RESTORE_DIR="$BACKUP_DIR/$R_CHOICE"

        # Stray files in ~/Tebian-Backup show up in the list — don't "restore"
        # from something that isn't a backup directory
        if [ ! -d "$RESTORE_DIR" ]; then
            tnotify "Restore" "Not a backup: $R_CHOICE"
            continue
        fi

        # Restoring replaces the current configs — ask, and keep them first
        # as a backup of their own, so a wrong pick can be undone
        local confirm
        confirm=$(echo -e "No, cancel\nYes, replace my current configs" | tfuzzel -d --match-mode=exact -p " Restore $R_CHOICE? | " --width 50)
        [[ "$confirm" =~ "Yes" ]] || continue
        local before
        before="$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)-before-restore"
        if ! backup_configs "$before"; then
            tnotify "Restore" "Could not back up the current configs first — nothing was changed"
            continue
        fi

        # Each item is copied next to its target, then swapped in: the
        # result is exactly the backup (no leftover files mixed in), and a
        # failed copy leaves the current one in place
        local item failed=""
        for item in sway kitty fuzzel mako gtklock; do
            [ -d "$RESTORE_DIR/$item" ] || continue
            rm -rf "$HOME/.config/$item.restoring"
            if cp -r "$RESTORE_DIR/$item" "$HOME/.config/$item.restoring"; then
                rm -rf "$HOME/.config/$item"
                mv "$HOME/.config/$item.restoring" "$HOME/.config/$item" || failed+=" $item"
            else
                rm -rf "$HOME/.config/$item.restoring"
                failed+=" $item"
            fi
        done
        for item in .bashrc .bash_profile .profile; do
            [ -f "$RESTORE_DIR/$item" ] || continue
            cp "$RESTORE_DIR/$item" "$HOME/$item" || failed+=" $item"
        done

        swaymsg reload >/dev/null 2>&1 &
        if [ -n "$failed" ]; then
            tnotify "Restore incomplete" "Not restored:$failed — your previous configs are in ${before#"$HOME"/}"
        else
            tnotify "Restore Complete" "Restored from $R_CHOICE (previous configs: ${before#"$HOME"/})"
        fi

    elif [[ "$B_CHOICE" =~ "View Backups" ]]; then
        BACKUP_DIR="$HOME/Tebian-Backup"
        if [ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
            # Every backup, then what the newest one holds
            $TERM_CMD bash -c 'ls -la "$1"; echo; newest=$(ls -1t "$1" | head -1); echo "Newest: $newest"; ls -la "$1/$newest" 2>/dev/null; read -p "Press Enter..."' _ "$BACKUP_DIR"
        else
            tnotify "Backup" "No backups found"
        fi
    fi
    done
}

# Config Tracking keeps the history of this machine's own settings in a
# repository of its own, outside ~/Tebian: ~/Tebian belongs to tebian-update,
# and turning it into a git repo made every update take the git-pull path
# and fail. Work tree is $HOME; only the files listed here are tracked.
CONFIG_GIT_DIR="$HOME/.local/share/tebian/config.git"
CONFIG_TRACKED=(
    .config/tebian/machine.conf
    .config/sway/config.user .config/sway/outputs
    .config/kitty/kitty.conf .config/fuzzel/fuzzel.ini .config/mako/config
)
cfg_git() { git --git-dir="$CONFIG_GIT_DIR" --work-tree="$HOME" "$@"; }

config_menu() {
    while true; do
    TEBIAN_DIR="${TEBIAN_DIR:-$HOME/Tebian}"
    local MACHINE_CONF="$HOME/.config/tebian/machine.conf"
    local TRACK_OPTS cfg_remote
    if [ -d "$CONFIG_GIT_DIR" ]; then
        cfg_remote=$(cfg_git remote get-url origin 2>/dev/null)
        TRACK_OPTS="󰊢 View Config Changes
󰆓 Save Config Snapshot
󰋚 Config History
󰆓 Config Remote (Current: ${cfg_remote:-Not Set})"
        [ -n "$cfg_remote" ] && TRACK_OPTS+="
󰕒 Push Config to Remote"
    else
        TRACK_OPTS="󰊢 Config Tracking (OFF)"
    fi

    # ~/Tebian as a git clone of Tebian (fleet or dev machine): one that
    # tracks a remote, which is what tebian-update pulls. Its branch and
    # remote go on the lines that act on them, not on lines of their own
    # that do nothing when picked.
    if command -v git &>/dev/null && [ -d "$TEBIAN_DIR/.git" ] &&
       git -C "$TEBIAN_DIR" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
        # Empty on a detached HEAD
        GIT_BRANCH=$(git -C "$TEBIAN_DIR" branch --show-current 2>/dev/null)
        GIT_DIRTY=$(git -C "$TEBIAN_DIR" status --porcelain 2>/dev/null | head -1)
        GIT_REMOTE=$(git -C "$TEBIAN_DIR" remote get-url origin 2>/dev/null)
        if [ -n "$GIT_DIRTY" ]; then
            STATUS_LABEL="Branch: ${GIT_BRANCH:-detached}, Modified"
        else
            STATUS_LABEL="Branch: ${GIT_BRANCH:-detached}, No Changes"
        fi

        C_OPTS="󰚰 Update Tebian
󰑓 Rebuild System
󰏫 Edit Machine Settings
󰊢 View Tebian Diff ($STATUS_LABEL)
󰆓 Tebian Remote (Current: ${GIT_REMOTE:-Not Set})
$TRACK_OPTS
󰌍 Back"
    else
        C_OPTS="󰚰 Update Tebian
󰑓 Rebuild System
󰏫 Edit Machine Settings
$TRACK_OPTS
󰌍 Back"
    fi

    # printf, not echo -e: a remote URL may hold a backslash
    C_CHOICE=$(printf '%s\n' "$C_OPTS" | tfuzzel -d -p " 󰑀 Config | " --width 50)

    [ -n "$C_CHOICE" ] || menu_close
    if is_back "$C_CHOICE"; then return; fi
    C_CHOICE=$(sysprefs_words "$C_CHOICE")

    if [[ "$C_CHOICE" == "Update Tebian"* ]]; then
        $TERM_CMD bash -c "
            tebian-update
            read -p 'Press Enter to close...'
        "
    elif [[ "$C_CHOICE" == "Rebuild System"* ]]; then
        $TERM_CMD bash -c "
            echo '=== Tebian Rebuild ==='
            echo ''
            bash '$TEBIAN_DIR/scripts/tebian-rebuild'
            echo ''
            read -p 'Press Enter to close...'
        "
    elif [[ "$C_CHOICE" == "Edit Machine Settings"* ]]; then
        # This machine's choices live in machine.conf, layered over
        # ~/Tebian/tebian.conf — which is Tebian's file (tracked in git on
        # fleet machines), so editing it here would block updates
        if [ ! -f "$MACHINE_CONF" ]; then
            mkdir -p "${MACHINE_CONF%/*}"
            {
                echo "# This machine's settings. Each KEY=\"value\" here overrides the default"
                echo "# in ~/Tebian/tebian.conf (see that file for every key). Settings records"
                echo "# your choices here; apply edits with: tebian-rebuild"
            } > "$MACHINE_CONF"
        fi
        $TERM_CMD nano "$MACHINE_CONF"
    elif [[ "$C_CHOICE" == "View Tebian Diff"* ]]; then
        $TERM_CMD bash -c "
            echo '=== Config Changes ==='
            echo ''
            cd '$TEBIAN_DIR'
            git diff
            echo ''
            echo '=== Status ==='
            git status
            echo ''
            read -p 'Press Enter to close...'
        "
    elif [[ "$C_CHOICE" == "Tebian Remote"* ]]; then
        $TERM_CMD bash -c "
            echo '=== Set Git Remote ==='
            echo ''
            CURRENT=\$(git -C '$TEBIAN_DIR' remote get-url origin 2>/dev/null || echo 'none')
            echo \"Current remote: \$CURRENT\"
            echo ''
            read -p 'New remote URL: ' NEW_URL
            if [ -n \"\$NEW_URL\" ]; then
                if git -C '$TEBIAN_DIR' remote get-url origin &>/dev/null; then
                    git -C '$TEBIAN_DIR' remote set-url origin \"\$NEW_URL\"
                else
                    git -C '$TEBIAN_DIR' remote add origin \"\$NEW_URL\"
                fi
                echo \"Remote set to: \$NEW_URL\"
            else
                echo 'Cancelled.'
            fi
            read -p 'Press Enter to close...'
        "
    elif [[ "$C_CHOICE" == "Config Tracking"* ]]; then
        CONFIG_GIT_DIR="$CONFIG_GIT_DIR" TRACKED="${CONFIG_TRACKED[*]}" $TERM_CMD bash -c '
            fail() { echo ""; echo "❌ $1"; read -p "Press Enter to close..."; exit 1; }
            echo "=== Enable Config Tracking ==="
            echo ""
            echo "Keeps a history of your own settings (machine.conf, sway"
            echo "config.user and outputs, kitty, fuzzel and mako configs) in"
            echo "${CONFIG_GIT_DIR/#$HOME/~}. ~/Tebian is not touched."
            echo ""
            read -p "Continue? [Y/n]: " confirm
            [[ "$confirm" =~ ^[Nn]$ ]] && { echo "Cancelled."; read -p "Press Enter to close..."; exit 0; }
            if ! command -v git >/dev/null; then
                echo "Installing git..."
                { sudo apt update -qq && sudo apt install -y git; } || fail "Could not install git"
            fi
            g() { git --git-dir="$CONFIG_GIT_DIR" --work-tree="$HOME" "$@"; }
            mkdir -p "${CONFIG_GIT_DIR%/*}"
            git init -q --bare "$CONFIG_GIT_DIR" || fail "git init failed"
            # Only the listed files: the work tree is all of $HOME
            g config status.showUntrackedFiles no
            # A fresh system has no git identity, and commit refuses without one
            g config user.name >/dev/null || g config user.name "${USER:-$(id -un)}"
            g config user.email >/dev/null || g config user.email "${USER:-$(id -un)}@$(hostname)"
            cd "$HOME" || fail "No home directory"
            for f in $TRACKED; do [ -f "$f" ] && { g add -- "$f" || fail "Could not add $f"; }; done
            g commit -q -m "Initial snapshot" || fail "The first commit failed — see the message above"
            echo ""
            echo "Done! Config tracking enabled."
            echo "Save Config Snapshot records changes; View Config Changes shows them."
            read -p "Press Enter to close..."
        '
    elif [[ "$C_CHOICE" == "View Config Changes"* ]]; then
        CONFIG_GIT_DIR="$CONFIG_GIT_DIR" $TERM_CMD bash -c '
            cd "$HOME" && git --git-dir="$CONFIG_GIT_DIR" --work-tree="$HOME" -c color.ui=always diff | less -R
            git --git-dir="$CONFIG_GIT_DIR" --work-tree="$HOME" status --short
            read -p "Press Enter to close..."
        '
    elif [[ "$C_CHOICE" == "Save Config Snapshot"* ]]; then
        CONFIG_GIT_DIR="$CONFIG_GIT_DIR" TRACKED="${CONFIG_TRACKED[*]}" $TERM_CMD bash -c '
            g() { git --git-dir="$CONFIG_GIT_DIR" --work-tree="$HOME" "$@"; }
            cd "$HOME" || exit 1
            # Files that appeared since tracking began (e.g. machine.conf)
            for f in $TRACKED; do [ -f "$f" ] && g add -- "$f"; done
            g add -u
            if g diff --cached --quiet; then
                echo "Nothing changed since the last snapshot."
            else
                read -p "Describe this snapshot (optional): " msg
                if g commit -q -m "${msg:-Snapshot $(date "+%Y-%m-%d %H:%M")}"; then
                    echo "Snapshot saved."
                else
                    echo "❌ The snapshot was not saved — see the message above."
                fi
            fi
            read -p "Press Enter to close..."
        '
    elif [[ "$C_CHOICE" == "Config History"* ]]; then
        CONFIG_GIT_DIR="$CONFIG_GIT_DIR" $TERM_CMD bash -c '
            git -c color.ui=always --git-dir="$CONFIG_GIT_DIR" log --stat --date=short | less -R
        '
    elif [[ "$C_CHOICE" == "Config Remote"* ]]; then
        CONFIG_GIT_DIR="$CONFIG_GIT_DIR" $TERM_CMD bash -c '
            g() { git --git-dir="$CONFIG_GIT_DIR" "$@"; }
            echo "Current remote: $(g remote get-url origin 2>/dev/null || echo none)"
            echo ""
            read -p "New remote URL (your own private repo): " url
            if [ -z "$url" ]; then
                echo "Cancelled."
            elif g remote get-url origin >/dev/null 2>&1; then
                g remote set-url origin "$url" && echo "Remote set to: $url"
            else
                g remote add origin "$url" && echo "Remote set to: $url"
            fi
            read -p "Press Enter to close..."
        '
    elif [[ "$C_CHOICE" == "Push Config to Remote"* ]]; then
        CONFIG_GIT_DIR="$CONFIG_GIT_DIR" $TERM_CMD bash -c '
            if git --git-dir="$CONFIG_GIT_DIR" push -u origin HEAD; then
                echo "Pushed."
            else
                echo "❌ Push failed — see the message above."
            fi
            read -p "Press Enter to close..."
        '
    fi
    done
}

# Stay-awake switches (tebian-awake): until turned off or logout
power_awake_state() {
    local k v
    awake_idle=0 awake_lid=0 laptop=0
    while IFS=$'\t' read -r k v; do
        case "$k" in idle) awake_idle=$v ;; lid) awake_lid=$v ;; laptop) laptop=$v ;; esac
    done < <(tebian-awake status 2>/dev/null)
}

# The switches stay in the menu after a pick, showing their new state, like
# every other switch in Settings
power_menu() {
    local awake_idle awake_lid laptop IDLE_LABEL LID_LABEL MODE_LINES
    while true; do
    power_awake_state
    if [ "$awake_idle" = 1 ]; then
        IDLE_LABEL="󰅶 Keep Awake (ON: no auto-lock, screen stays on)"
    else
        IDLE_LABEL="󰾪 Keep Awake (OFF)"
    fi
    LID_LABEL=""
    if [ "$laptop" = 1 ]; then
        if [ "$awake_lid" = 1 ]; then
            LID_LABEL="󰌢 Keep Running with Lid Closed (ON)"
        else
            LID_LABEL="󰌢 Keep Running with Lid Closed (OFF)"
        fi
    fi

    MODE_LINES=$(power_mode_lines)

    POWER_OPTS="󰜉 Reboot
󰐥 Shutdown
󰤄 Sleep
󰍃 Logout
$IDLE_LABEL
${LID_LABEL:+$LID_LABEL
}${MODE_LINES:+$MODE_LINES
}󰌍 Back"
    P_CHOICE=$(echo -e "$POWER_OPTS" | tfuzzel -d --match-mode=exact -p " 󰐥 Power | ")

    [ -n "$P_CHOICE" ] || menu_close
    if is_back "$P_CHOICE"; then return; fi

    # Power modes, then the drop-down again so the switch shows its new state
    power_mode_pick "$P_CHOICE" && continue

    # The notification says the state tebian-awake reports afterwards, not
    # the one the pick asked for
    local was
    if [[ "$P_CHOICE" =~ "Keep Awake" ]]; then
        was=$awake_idle
        tebian-awake idle toggle >/dev/null 2>&1
        power_awake_state
        if [ "$awake_idle" = "$was" ]; then
            tnotify "Keep Awake" "Couldn't change it — still $([ "$was" = 1 ] && echo on || echo off)"
        elif [ "$awake_idle" = 1 ]; then
            tnotify "Keep Awake" "On until you turn it off or log out"
        else
            tnotify "Keep Awake" "Off — auto-lock is back"
        fi
        continue
    elif [[ "$P_CHOICE" =~ "Lid Closed" ]]; then
        was=$awake_lid
        tebian-awake lid toggle >/dev/null 2>&1
        power_awake_state
        if [ "$awake_lid" = "$was" ]; then
            tnotify "Lid Closed" "Couldn't change it — still $([ "$was" = 1 ] && echo "keeps running" || echo "sleeps") with the lid closed"
        elif [ "$awake_lid" = 1 ]; then
            tnotify "Lid Closed" "Keeps running with the lid closed, until you turn it off or log out"
        else
            tnotify "Lid Closed" "Closing the lid puts the laptop to sleep"
        fi
        continue
    fi

    if [[ "$P_CHOICE" =~ "Reboot" || "$P_CHOICE" =~ "Shutdown" ]]; then
        local action=poweroff what="shut down"
        [[ "$P_CHOICE" =~ "Reboot" ]] && action=reboot what=restart
        # Blank the display to hide the Sway→Plymouth transition — but only
        # once systemd has accepted the request. Blanking first left a black
        # screen with a live session behind it whenever the reboot was
        # refused (an inhibitor, another user logged in).
        if systemctl "$action"; then
            swaymsg output '*' power off >/dev/null 2>&1
        else
            tnotify "Power" "The system refused to $what — see: systemd-inhibit --list"
        fi
    elif [[ "$P_CHOICE" =~ "Sleep" ]]; then
        systemctl suspend ||
            tnotify "Power" "The system refused to sleep — see: systemd-inhibit --list"
    elif [[ "$P_CHOICE" =~ "Logout" ]]; then swaymsg exit
    fi
    return
    done
}

notification_history_menu() {
    # Without mako there is no history, and no notification to say so
    command -v makoctl &>/dev/null || { sysprefs_offer_mako; return; }
    while true; do
    # mako 1.9+ (trixie has 1.10) prints history as text, one block each:
    #   Notification 12: <summary>
    #     App name: <app>
    # (no body). Becomes "app: summary" per line, newest first.
    HISTORY=$(makoctl history 2>/dev/null | awk '
        function flush() { if (have) print (app != "" ? app ": " : "") summary; have = 0 }
        /^Notification [0-9]+:/ { flush(); summary = $0; sub(/^Notification [0-9]+: ?/, "", summary); app = ""; have = 1; next }
        /^  App name: / { app = $0; sub(/^  App name: /, "", app) }
        END { flush() }' | cut -c1-80)
    if [ -z "$HISTORY" ]; then
        HISTORY="(No recent notifications)"
    fi
    # printf, not echo -e: notification text comes from any app and may
    # hold backslashes
    H_CHOICE=$(printf '%s\n' "$HISTORY" "󰆴 Clear All" "󰌍 Back" | tfuzzel -d -p " 󰍡 Notification History | " --width 60)
    [ -n "$H_CHOICE" ] || menu_close
    is_back "$H_CHOICE" && return
    # Matched without its icon (Text Mode strips it). History lines are
    # "app: summary", so they don't collide with the bare words
    if [[ "$H_CHOICE" =~ ^[^[:alnum:]]*"Clear All"$ ]]; then
        # -h (--no-history) dismisses the visible ones without adding them
        # to history. History itself has no clear command; it lives only in
        # mako's memory, so restarting mako empties it.
        makoctl dismiss -a -h 2>/dev/null || makoctl dismiss --all 2>/dev/null
        systemctl --user restart mako 2>/dev/null || { pkill mako; (mako &) }
        tnotify "Notifications" "History cleared"
    fi
    # A history line is only there to be read: the list shows again
    done
}

# Everything System Update does is update-all's, in a terminal; the Modern
# bar's update indicator is told to look again once it has run
system_update() {
    $TERM_CMD update-all
    pkill -RTMIN+7 -x waybar 2>/dev/null
}

# More drawer (advanced/occasional items)
more_menu() {
    while true; do
    M_OPTS="󰇄 Desktop & UI
󰄬 Default Apps
󰐊 Startup Apps
󰋊 Drives
󰓅 Performance
󰡨 Infrastructure
󰆏 Backup & Restore
󰑀 Config Tracking (Git)
󰌍 Back"

    M_CHOICE=$(echo -e "$M_OPTS" | tfuzzel -d -p " 󰇄 More | ")

    [ -n "$M_CHOICE" ] || menu_close
    if is_back "$M_CHOICE"; then return; fi

    case "$(sysprefs_words "$M_CHOICE")" in
        "Desktop & UI"*)     ui_menu ;;
        "Default Apps"*)     default_apps_menu ;;
        "Startup Apps"*)     startup_apps_menu ;;
        "Drives"*)           drives_menu ;;
        "Performance"*)      perf_menu ;;
        "Infrastructure"*)   infra_menu ;;
        "Backup & Restore"*) backup_menu ;;
        "Config Tracking"*)  config_menu ;;
    esac
    done
}
