# tebian-settings module: system.sh
# Sourced by tebian-settings — do not run directly

sysinfo_menu() {
    # Gather system info
    HOSTNAME=$(hostname)
    UPTIME=$(uptime -p 2>/dev/null || uptime)
    KERNEL=$(uname -r)
    CPU=$(lscpu | grep "Model name" | sed 's/Model name:\s*//' | head -1)
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    GPU=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display" | head -1 | sed 's/.*: //')
    
    INFO="󰋅 System Info
─────────────────────────────────
󰌢 Host: $HOSTNAME
󰓅 Uptime: $UPTIME
󰍛 Kernel: $KERNEL
─────────────────────────────────
󰚰 CPU: $CPU
󰍛 RAM: $MEM_USED / $MEM_TOTAL
󰋊 Disk: $DISK_USED / $DISK_TOTAL
─────────────────────────────────
󰢻 GPU: ${GPU:-Not detected}
─────────────────────────────────
󰌍 Back
─────────────────────────────────
An act of God."

    CHOICE=$(echo -e "$INFO" | tfuzzel -d -p "" --width 50 --lines 15)

    if [[ "$CHOICE" =~ "act of God" ]]; then
        temple_os
    fi
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
            curl -fSL 'https://templeos.org/Downloads/TOS_Distro.ISO' \\
                -o \"\$TEMPLE_ISO\" 2>/dev/null || \\
            curl -fSL 'https://archive.org/download/TempleOS_ISO_Archive/TOS_Distro.ISO' \\
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

backup_tracking_menu() {
    while true; do
    BT_OPTS="󰆏 Backup & Restore\0icon\x1fdrive-harddisk
󰑀 Config Tracking (Git)\0icon\x1fvcs-normal
─────────────────────────────────
󰌍 Back"

    BT_CHOICE=$(echo -e "$BT_OPTS" | tfuzzel -d -p " 󰆏 Backup | ")

    if [[ "$BT_CHOICE" =~ "Back" || -z "$BT_CHOICE" ]]; then return; fi

    if [[ "$BT_CHOICE" =~ "Backup & Restore" ]]; then
        backup_menu
    elif [[ "$BT_CHOICE" =~ "Config Tracking" ]]; then
        config_menu
    fi
    done
}

backup_menu() {
    while true; do
    BACKUP_OPTS="󰆏 Backup Configs to ~/Tebian-Backup
󰑋 Restore from Backup
─────────────────────────────────
󰈔 View Current Backup
─────────────────────────────────
󰌍 Back"
    
    B_CHOICE=$(echo -e "$BACKUP_OPTS" | tfuzzel -d -p " 󰆏 Backup | ")
    
    if [[ "$B_CHOICE" =~ "Back" || -z "$B_CHOICE" ]]; then return; fi

    if [[ "$B_CHOICE" =~ "Backup Configs" ]]; then
        BACKUP_DIR="$HOME/Tebian-Backup"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        
        mkdir -p "$BACKUP_DIR/$TIMESTAMP"
        
        # Backup configs (dereference symlinks so we get actual files, not links into repo)
        cp -rL ~/.config/sway "$BACKUP_DIR/$TIMESTAMP/" 2>/dev/null
        cp -rL ~/.config/kitty "$BACKUP_DIR/$TIMESTAMP/" 2>/dev/null
        cp -rL ~/.config/fuzzel "$BACKUP_DIR/$TIMESTAMP/" 2>/dev/null
        cp -rL ~/.config/mako "$BACKUP_DIR/$TIMESTAMP/" 2>/dev/null
        cp -rL ~/.config/gtklock "$BACKUP_DIR/$TIMESTAMP/" 2>/dev/null
        cp ~/.bashrc "$BACKUP_DIR/$TIMESTAMP/" 2>/dev/null
        cp ~/.bash_profile "$BACKUP_DIR/$TIMESTAMP/" 2>/dev/null
        cp ~/.profile "$BACKUP_DIR/$TIMESTAMP/" 2>/dev/null
        
        # Create manifest
        echo "Tebian Backup - $TIMESTAMP" > "$BACKUP_DIR/$TIMESTAMP/manifest.txt"
        echo "Hostname: $(hostname)" >> "$BACKUP_DIR/$TIMESTAMP/manifest.txt"
        
        notify-send "Backup Complete" "Saved to ~/Tebian-Backup/$TIMESTAMP"
        
    elif [[ "$B_CHOICE" =~ "Restore" ]]; then
        BACKUP_DIR="$HOME/Tebian-Backup"
        
        if [ ! -d "$BACKUP_DIR" ]; then
            notify-send "Restore" "No backups found"
            continue
        fi
        
        # List available backups
        BACKUPS=$(ls -1t "$BACKUP_DIR" | head -10)
        R_CHOICE=$(echo -e "󰌍 Back\n$BACKUPS" | tfuzzel -d -p " 󰑋 Restore | ")
        
        if [[ -z "$R_CHOICE" ]] || [[ "$R_CHOICE" =~ "Back" ]]; then
            continue
        fi
        
        RESTORE_DIR="$BACKUP_DIR/$R_CHOICE"
        
        if [ -d "$RESTORE_DIR/sway" ]; then cp -r "$RESTORE_DIR/sway" ~/.config/; fi
        if [ -d "$RESTORE_DIR/kitty" ]; then cp -r "$RESTORE_DIR/kitty" ~/.config/; fi
        if [ -d "$RESTORE_DIR/fuzzel" ]; then cp -r "$RESTORE_DIR/fuzzel" ~/.config/; fi
        if [ -d "$RESTORE_DIR/mako" ]; then cp -r "$RESTORE_DIR/mako" ~/.config/; fi
        if [ -d "$RESTORE_DIR/gtklock" ]; then cp -r "$RESTORE_DIR/gtklock" ~/.config/; fi
        if [ -f "$RESTORE_DIR/.bashrc" ]; then cp "$RESTORE_DIR/.bashrc" ~/; fi
        
        swaymsg reload 2>/dev/null
        notify-send "Restore Complete" "Restored from $R_CHOICE"
        
    elif [[ "$B_CHOICE" =~ "View Current" ]]; then
        BACKUP_DIR="$HOME/Tebian-Backup"
        if [ -d "$BACKUP_DIR" ]; then
            $TERM_CMD bash -c "ls -la $BACKUP_DIR; echo ''; ls -la $BACKUP_DIR/$(ls -1t $BACKUP_DIR | head -1) 2>/dev/null; read -p 'Press Enter...'"
        else
            notify-send "Backup" "No backups found"
        fi
    fi
    done
}

config_menu() {
    while true; do
    TEBIAN_DIR="$HOME/Tebian"

    # Detect git state
    if command -v git &>/dev/null && [ -d "$TEBIAN_DIR/.git" ]; then
        GIT_BRANCH=$(git -C "$TEBIAN_DIR" branch --show-current 2>/dev/null || echo "unknown")
        GIT_DIRTY=$(git -C "$TEBIAN_DIR" status --porcelain 2>/dev/null | head -1)
        GIT_REMOTE=$(git -C "$TEBIAN_DIR" remote get-url origin 2>/dev/null || echo "none")
        if [ -n "$GIT_DIRTY" ]; then
            STATUS_LABEL="branch: $GIT_BRANCH (modified)"
        else
            STATUS_LABEL="branch: $GIT_BRANCH (clean)"
        fi
        REMOTE_LABEL="remote: $GIT_REMOTE"

        C_OPTS="󰋽 $STATUS_LABEL
󰋽 $REMOTE_LABEL
─────────────────────────────────
󰚰 Update Tebian
󰑓 Rebuild System
📝 Edit tebian.conf
󰊢 View Diff
󰆓 Set Remote URL
─────────────────────────────────
󰌍 Back"
    else
        C_OPTS="─────────────────────────────────
󰚰 Update Tebian
󰑓 Rebuild System
📝 Edit tebian.conf
─────────────────────────────────
󰊢 Enable Config Tracking (git)
─────────────────────────────────
󰌍 Back"
    fi

    C_CHOICE=$(echo -e "$C_OPTS" | tfuzzel -d -p " 󰑀 Config | ")

    if [[ -z "$C_CHOICE" || "$C_CHOICE" =~ "Back" ]]; then return; fi

    if [[ "$C_CHOICE" =~ "Update Tebian" ]]; then
        $TERM_CMD bash -c "
            tebian-update
            read -p 'Press Enter to close...'
        "
    elif [[ "$C_CHOICE" =~ "Rebuild System" ]]; then
        $TERM_CMD bash -c "
            echo '=== Tebian Rebuild ==='
            echo ''
            bash '$TEBIAN_DIR/scripts/tebian-rebuild'
            echo ''
            read -p 'Press Enter to close...'
        "
    elif [[ "$C_CHOICE" =~ "Edit tebian.conf" ]]; then
        if [ ! -f "$TEBIAN_DIR/tebian.conf" ]; then
            touch "$TEBIAN_DIR/tebian.conf"
        fi
        $TERM_CMD nano "$TEBIAN_DIR/tebian.conf"
    elif [[ "$C_CHOICE" =~ "View Diff" ]]; then
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
    elif [[ "$C_CHOICE" =~ "Set Remote URL" ]]; then
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
    elif [[ "$C_CHOICE" =~ "Enable Config Tracking" ]]; then
        $TERM_CMD bash -c "
            echo '=== Enable Config Tracking ==='
            echo ''
            echo 'This will install git and initialize version tracking'
            echo 'for your Tebian configuration.'
            echo ''
            read -p 'Continue? [Y/n]: ' confirm
            if [[ \"\$confirm\" =~ ^[Nn]$ ]]; then
                echo 'Cancelled.'
                read -p 'Press Enter to close...'
                exit 0
            fi
            echo ''
            echo 'Installing git...'
            sudo apt update -qq && sudo apt install -y git
            echo ''
            cd '$TEBIAN_DIR'
            git init
            git add -A
            git commit -m 'Initial Tebian config'
            echo ''
            echo 'Done! Config tracking enabled.'
            echo 'Use View Diff to see changes, Set Remote to sync.'
            read -p 'Press Enter to close...'
        "
    fi
    done
}

power_menu() {
    POWER_OPTS="󰜉 Reboot
󰐥 Shutdown
󰤄 Sleep
󰍃 Logout
─────────────────────────────────
󰌍 Back"
    P_CHOICE=$(echo -e "$POWER_OPTS" | tfuzzel -d --match-mode=exact -p " 󰐥 Power | ")
    
    if [[ "$P_CHOICE" =~ "Back" || -z "$P_CHOICE" ]]; then return; fi

    if [[ "$P_CHOICE" =~ "Reboot" ]]; then systemctl reboot
    elif [[ "$P_CHOICE" =~ "Shutdown" ]]; then systemctl poweroff
    elif [[ "$P_CHOICE" =~ "Sleep" ]]; then systemctl suspend
    elif [[ "$P_CHOICE" =~ "Logout" ]]; then swaymsg exit
    fi
}

notification_history_menu() {
    if ! command -v makoctl &>/dev/null; then
        notify-send "Notifications" "mako not installed"
        return
    fi
    # Get notification history from mako (JSON) and format for fuzzel
    HISTORY=$(makoctl history 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for n in data.get('data', [[]])[0]:
        summary = n.get('summary', {}).get('data', 'No title')
        body = n.get('body', {}).get('data', '')
        app = n.get('app-name', {}).get('data', '')
        line = f'{app}: {summary}'
        if body:
            line += f' - {body[:60]}'
        print(line)
except:
    print('No notifications')
" 2>/dev/null)
    if [ -z "$HISTORY" ] || [ "$HISTORY" = "No notifications" ]; then
        HISTORY="(No recent notifications)"
    fi
    HIST_OPTS="$HISTORY
─────────────────────────────────
🗑️  Clear All
─────────────────────────────────
󰌍 Back"
    H_CHOICE=$(echo -e "$HIST_OPTS" | tfuzzel -d -p " 󰍡 Notifications | ")
    if [[ "$H_CHOICE" =~ "Clear All" ]]; then
        makoctl dismiss --all 2>/dev/null
        tnotify "Notifications" "History cleared"
    fi
}

# More drawer (advanced/occasional items)
more_menu() {
    while true; do
    M_OPTS="󰇄 Desktop & UI\0icon\x1fpreferences-desktop-display
󰏗 Software\0icon\x1fapplications-system
─────────────────────────────────
󰒃 Security & Firewall\0icon\x1fsecurity-high
󰡨 Infrastructure\0icon\x1fapplications-utilities
󰓅 Performance\0icon\x1fpreferences-system
─────────────────────────────────
󰋅 System Info\0icon\x1fdialog-information
󰆏 Backup & Tracking\0icon\x1fdrive-harddisk
󰍡 Notification History\0icon\x1fdialog-information
─────────────────────────────────
󰌍 Back"

    M_CHOICE=$(echo -e "$M_OPTS" | tfuzzel -d -p " More | ")

    if [[ -z "$M_CHOICE" ]] || [[ "$M_CHOICE" =~ "Back" ]]; then return; fi

    if [[ "$M_CHOICE" =~ "Desktop & UI" ]]; then
        ui_menu
    elif [[ "$M_CHOICE" =~ "Software" ]]; then
        software_hub
    elif [[ "$M_CHOICE" =~ "Security" ]]; then
        security_menu
    elif [[ "$M_CHOICE" =~ "Infrastructure" ]]; then
        infra_menu
    elif [[ "$M_CHOICE" =~ "Performance" ]]; then
        perf_menu
    elif [[ "$M_CHOICE" =~ "System Info" ]]; then
        sysinfo_menu
    elif [[ "$M_CHOICE" =~ "Backup" ]]; then
        backup_tracking_menu
    elif [[ "$M_CHOICE" =~ "Notification History" ]]; then
        notification_history_menu
    fi
    done
}

