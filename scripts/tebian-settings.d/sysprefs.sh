# shellcheck shell=bash
# tebian-settings module: sysprefs.sh
# Sourced by tebian-settings — do not run directly
#
# System preferences: the machine-wide settings a new user expects to find
# (name, clock, language, printers, notifications). Every entry is its own
# argument-less function so the settings search can open it directly.

# The words of a menu choice without its icon: in Text Mode tfuzzel already
# strips it, in Icon Mode it is still there. Matching on the start of the
# words keeps a label's own text (a computer called "printers") from
# selecting some other entry.
sysprefs_words() {
    local c="$1"
    printf '%s' "${c#"${c%%[[:alnum:]]*}"}"
}

# Time zone, automatic time and the keyboard are changed through systemd's
# *ctl tools, which polkit allows: in the Tebian desktop lxpolkit asks for the
# password in a dialog. The base install runs no agent, and the call then
# fails with "Interactive authentication required" — so the same command runs
# through sudo in a terminal, where it can ask. Any other failure (a cancelled
# dialog, a bad value) is the caller's to report, with SYSPREFS_ERR. Callers
# read the setting back instead of trusting the status: a terminal's exit
# status is not its command's. Returns 0 done, 1 failed, 2 ran in a terminal.
SYSPREFS_ERR=""
sysprefs_privileged() {
    # stdin closed: with a terminal on stdin the *ctl tools start a text
    # password prompt of their own, which nobody would see from a menu
    SYSPREFS_ERR=$("$@" 2>&1 </dev/null >/dev/null) && return 0
    case "$SYSPREFS_ERR" in
        *"nteractive authentication required"*|*InteractiveAuthorizationRequired*) ;;
        *) return 1 ;;
    esac
    $TERM_CMD bash -c '
        echo "This change needs your password:"
        echo "  $*"
        echo
        if sudo "$@"; then
            echo; echo "Done."
            sleep 1
        else
            echo; echo "Not changed — see the message above."
            read -rp "Press Enter to close. "
        fi
    ' _ "$@"
    SYSPREFS_ERR=""
    return 2
}

system_menu() {
    while true; do
    local host zone now lang dnd printers
    host=$(hostname 2>/dev/null)
    zone=$(sysprefs_timezone)
    now=$(date '+%H:%M')
    lang=$(sysprefs_system_lang)
    case "$(sysprefs_dnd_state)" in
        on)  dnd="Do Not Disturb: ON" ;;
        off) dnd="Do Not Disturb: OFF" ;;
        *)   dnd="" ;;
    esac
    if sysprefs_printing_installed; then
        printers="󰈔 Printers"
    else
        printers="󰈔 Printers (Not Installed)"
    fi

    local OPTS="󰋅 About This Computer
󰌢 Computer Name: ${host:-unknown}
󰥔 Date & Time: ${zone:-unknown}, $now
󰖟 Language & Region: ${lang:-not set}
$printers
󰍡 Notifications${dnd:+ ($dnd)}
󰌍 Back"

    local CHOICE
    CHOICE=$(echo -e "$OPTS" | tfuzzel -d -p " 󰒓 System | " --width 50)
    [ -n "$CHOICE" ] || menu_close
    if is_back "$CHOICE"; then return; fi

    case "$(sysprefs_words "$CHOICE")" in
        "About This Computer"*) sysinfo_menu ;;
        "Computer Name"*)       hostname_menu ;;
        "Date & Time"*)         datetime_menu ;;
        "Language & Region"*)   locale_menu ;;
        "Printers"*)            printers_menu ;;
        "Notifications"*)       notifications_menu ;;
    esac
    done
}

# ---------------------------------------------------------------------------
# Computer Name
# ---------------------------------------------------------------------------

# A hostname is one RFC 1123 label: what other machines on the network, the
# shell prompt and sudo's /etc/hosts lookup all agree on. Prints why a name
# is refused and returns 1; the name is expected already lowercased.
sysprefs_hostname_check() {
    local n="$1"
    if [ -z "$n" ]; then
        echo "The name can't be empty"
    elif [[ "$n" == *[[:space:]]* ]]; then
        echo "No spaces — use a hyphen, e.g. my-laptop"
    elif [[ "$n" == *.* ]]; then
        echo "Just the name, without dots or a domain"
    elif [ "${#n}" -gt 63 ]; then
        echo "At most 63 characters (this is ${#n})"
    elif [[ "$n" == -* || "$n" == *- ]]; then
        echo "It can't start or end with a hyphen"
    # Spelled out: in a UTF-8 locale a-z also matches letters like é
    elif [[ ! "$n" =~ ^[abcdefghijklmnopqrstuvwxyz0123456789-]+$ ]]; then
        echo "Only letters a-z, digits and hyphens"
    else
        return 0
    fi
    return 1
}

# Rewrites /etc/hosts (stdin to stdout) for a new name. Debian resolves its
# own name through the 127.0.1.1 line; if it still names the old host, sudo
# warns "unable to resolve host" on every call. The old name — and a
# fully-qualified old.domain form — become the new one in place; a line that
# never named the old host is replaced; a missing line is added.
# shellcheck disable=SC2016  # awk program, not shell
SYSPREFS_HOSTS_AWK='
$1 == "127.0.1.1" && !done {
    line = "127.0.1.1"; seen = 0
    for (i = 2; i <= NF; i++) {
        n = $i
        if (n ~ /^#/) break
        if (n == old) n = new
        else if (old != "" && index(n, old ".") == 1) n = new substr(n, length(old) + 1)
        if (n == new) seen = 1
        line = line "\t" n
    }
    if (!seen) line = "127.0.1.1\t" new
    print line
    done = 1
    next
}
{ print }
END { if (!done) print "127.0.1.1\t" new }'

hostname_menu() {
    local cur new msg="" prompt
    cur=$(hostname 2>/dev/null)
    while true; do
        if [ -n "$msg" ]; then
            prompt=" 󰌢 $msg — try again: "
        else
            prompt=" 󰌢 New computer name (now: ${cur:-unknown}): "
        fi
        new=$(tfuzzel -d --prompt-only "$prompt" --width 60 < /dev/null) || return
        # Empty is Escape or Enter on nothing: leave the name as it is
        [ -n "$new" ] || return
        # Hostnames are case-insensitive and shown in lower case everywhere
        new="${new,,}"
        msg=$(sysprefs_hostname_check "$new") && break
    done
    if [ "$new" = "$cur" ]; then
        tnotify "Computer Name" "It is already called $cur"
        return
    fi

    # hostnamectl alone would be a polkit call, but /etc/hosts needs root
    # either way: one terminal, one password, both changes
    $TERM_CMD bash -c '
        old="$1" new="$2" prog="$3"
        fail() { echo; echo "❌ $1"; read -rp "Press Enter to close. "; exit 1; }
        echo "Renaming this computer: $old → $new"
        echo
        sudo hostnamectl set-hostname "$new" || fail "The name was not changed."
        tmp=$(mktemp) || fail "Name changed, but /etc/hosts was not updated."
        if awk -v old="$old" -v new="$new" "$prog" /etc/hosts > "$tmp" &&
           sudo install -m 644 "$tmp" /etc/hosts; then
            rm -f "$tmp"
        else
            rm -f "$tmp"
            fail "Name changed, but /etc/hosts was not updated — sudo may warn \"unable to resolve host\"."
        fi
        echo "Done."
        sleep 1
    ' _ "$cur" "$new" "$SYSPREFS_HOSTS_AWK"

    if [ "$(hostname 2>/dev/null)" = "$new" ]; then
        tnotify "Computer Name" "This computer is now called $new"
    else
        tnotify "Computer Name" "Not changed — it is still called $cur"
    fi
}

# ---------------------------------------------------------------------------
# Date & Time
# ---------------------------------------------------------------------------

sysprefs_timezone() {
    local z
    z=$(timedatectl show -p Timezone --value 2>/dev/null)
    [ -n "$z" ] || z=$(cat /etc/timezone 2>/dev/null)
    [ -n "$z" ] || { z=$(readlink /etc/localtime 2>/dev/null); z="${z#*zoneinfo/}"; }
    printf '%s' "$z"
}

datetime_menu() {
    while true; do
    local zone now ntp can clock_fmt ntp_label
    zone=$(sysprefs_timezone)
    now=$(date '+%a %d %b %Y, %H:%M %Z')
    ntp=$(timedatectl show -p NTP --value 2>/dev/null)
    can=$(timedatectl show -p CanNTP --value 2>/dev/null)
    if [ "$can" != yes ]; then
        ntp_label="󰑓 Automatic Time (Not Installed)"
    elif [ "$ntp" = yes ]; then
        ntp_label="󰑓 Automatic Time (ON)"
    else
        ntp_label="󰑓 Automatic Time (OFF)"
    fi
    if [ -f "$HOME/.config/tebian/clock-12h" ]; then
        clock_fmt="12-hour"
    else
        clock_fmt="24-hour"
    fi

    local OPTS="󰥔 Now: $now
󰥔 Time Zone: ${zone:-unknown}
$ntp_label
󰥔 Clock Format: $clock_fmt
󰌍 Back"

    local CHOICE
    CHOICE=$(echo -e "$OPTS" | tfuzzel -d -p " 󰥔 Date & Time | " --width 50)
    [ -n "$CHOICE" ] || menu_close
    if is_back "$CHOICE"; then return; fi

    case "$(sysprefs_words "$CHOICE")" in
        "Time Zone"*)      timezone_menu ;;
        "Automatic Time"*) ntp_toggle ;;
        # The same switch as in Desktop & UI, beside the bar's other settings
        "Clock Format"*)   clock_format_toggle ;;
    esac
    done
}

timezone_menu() {
    local cur zones
    cur=$(sysprefs_timezone)
    zones=$(timedatectl list-timezones 2>/dev/null)
    if [ -z "$zones" ]; then
        tnotify "Time Zone" "No time zones found — is the tzdata package installed?"
        return
    fi
    # Current zone on top; typing a city finds the rest
    local CHOICE
    CHOICE=$({
        echo "󰌍 Back"
        [ -n "$cur" ] && echo "$cur (current)"
        grep -vxF -- "${cur:-//}" <<< "$zones"
    } | tfuzzel -d -p " 󰥔 Time Zone (type a city) | " --width 50)
    [ -n "$CHOICE" ] || menu_close
    if is_back "$CHOICE"; then return; fi

    local zone="${CHOICE% (current)}"
    # Only a name from the list: it ends up in a root-owned symlink
    if ! grep -qxF -- "$zone" <<< "$zones"; then
        tnotify "Time Zone" "Not a time zone: $zone"
        return
    fi
    [ "$zone" = "$cur" ] && return

    sysprefs_privileged timedatectl set-timezone "$zone"
    if [ "$(sysprefs_timezone)" = "$zone" ]; then
        tnotify "Time Zone" "Set to $zone — it is now $(date '+%H:%M')"
        # The Modern bar's clock reads the zone once, at start; sway
        # restarts the bar on reload
        swaymsg reload >/dev/null 2>&1 &
    else
        tnotify "Time Zone" "Not changed${SYSPREFS_ERR:+: $SYSPREFS_ERR}"
    fi
}

# Automatic time is systemd-timesyncd; timedatectl reports CanNTP=no
# without it (it can be left out of a minimal system)
ntp_toggle() {
    local ntp can want
    ntp=$(timedatectl show -p NTP --value 2>/dev/null)
    can=$(timedatectl show -p CanNTP --value 2>/dev/null)
    if [ "$can" != yes ]; then
        local confirm
        confirm=$(echo -e "No, cancel\nYes, install systemd-timesyncd" | tfuzzel -d --match-mode=exact -p " Automatic time needs systemd-timesyncd. Install it? | " --width 70)
        [[ "$confirm" =~ "Yes" ]] || return
        if ! tebian_term_apt_install systemd-timesyncd; then
            tnotify "Automatic Time" "systemd-timesyncd could not be installed"
            return
        fi
        ntp=no
    fi
    if [ "$ntp" = yes ]; then want=false; else want=true; fi

    sysprefs_privileged timedatectl set-ntp "$want"
    local now_ntp
    now_ntp=$(timedatectl show -p NTP --value 2>/dev/null)
    if [ "$want" = true ] && [ "$now_ntp" = yes ]; then
        tnotify "Automatic Time" "On — the clock is kept right from the network"
    elif [ "$want" = false ] && [ "$now_ntp" = no ]; then
        tnotify "Automatic Time" "Off — the clock is no longer synced"
    else
        tnotify "Automatic Time" "Not changed${SYSPREFS_ERR:+: $SYSPREFS_ERR}"
    fi
}

# ---------------------------------------------------------------------------
# Language & Region
# ---------------------------------------------------------------------------

# The system language greetd and sway sessions start with (they read
# /etc/default/locale at login), which can differ from this session's $LANG
# until the next login
sysprefs_system_lang() {
    local l
    l=$(sed -n 's/^[[:space:]]*LANG=//p' /etc/default/locale 2>/dev/null | tail -1)
    l="${l//\"/}"
    printf '%s' "${l:-${LANG:-}}"
}

# "name - description" for every UTF-8 locale glibc can build. Names are as
# SUPPORTED writes them (de_DE.UTF-8, be_BY@latin): that is what locale.gen
# and update-locale expect. The description is the locale's own title,
# read from all files in one grep — 300+ of them.
sysprefs_locale_list() {
    local supported="${SYSPREFS_SUPPORTED:-/usr/share/i18n/SUPPORTED}"
    local locdir="${SYSPREFS_LOCALES_DIR:-/usr/share/i18n/locales}"
    [ -r "$supported" ] || return 1
    {
        grep -H -m1 '^title' "$locdir"/* 2>/dev/null | sed 's/^/T\t/'
        sed 's/^/S\t/' "$supported"
    } | awk -F'\t' '
        $1 == "T" {
            # Not $2: the title line itself may hold tabs
            line = substr($0, 3)
            f = line; sub(/:title.*/, "", f); sub(/.*\//, "", f)
            t = line; sub(/^[^"]*"/, "", t); sub(/".*/, "", t); sub(/\.$/, "", t)
            sub(/ (language )?locale for (the )?/, ", ", t)
            title[f] = t
            next
        }
        $1 == "S" {
            split($2, w, " ")
            if (w[2] != "UTF-8" || w[1] == "" || w[1] ~ /^#/) next
            key = w[1]; sub(/\.UTF-8/, "", key)
            print w[1] " - " (key in title ? title[key] : w[1])
        }'
}

locale_menu() {
    local cur list
    cur=$(sysprefs_system_lang)
    if ! list=$(sysprefs_locale_list) || [ -z "$list" ]; then
        local confirm
        confirm=$(echo -e "No, cancel\nYes, install locales" | tfuzzel -d --match-mode=exact -p " Languages need the locales package. Install it? | " --width 70)
        [[ "$confirm" =~ "Yes" ]] || return
        tebian_term_apt_install locales && list=$(sysprefs_locale_list)
        if [ -z "$list" ]; then
            tnotify "Language" "The locales package could not be installed"
            return
        fi
    fi

    local CHOICE
    CHOICE=$({
        echo "󰌍 Back"
        awk -v c="$cur" '$1 == c { print $0 " (current)"; exit }' <<< "$list"
        awk -v c="$cur" '$1 != c' <<< "$list"
    } | tfuzzel -d -p " 󰖟 Language & Region (now: ${cur:-not set}) | " --width 70)
    [ -n "$CHOICE" ] || menu_close
    if is_back "$CHOICE"; then return; fi

    local loc="${CHOICE%% *}"
    if ! awk -v l="$loc" '$1 == l { f = 1 } END { exit !f }' <<< "$list" ||
       [[ ! "$loc" =~ ^[A-Za-z0-9_.@-]+$ ]]; then
        tnotify "Language" "Not a language from the list: $loc"
        return
    fi
    if [ "$loc" = "$cur" ]; then
        tnotify "Language" "$loc is already the system language"
        return
    fi

    # Generating a locale and changing the system default are all root and
    # several steps: one terminal, one password
    $TERM_CMD bash -c '
        loc="$1" prog="$2"
        fail() { echo; echo "❌ $1"; read -rp "Press Enter to close. "; exit 1; }
        echo "Setting the system language to $loc"
        echo
        command -v locale-gen >/dev/null || sudo apt install -y locales || fail "Could not install the locales package."
        tmp=$(mktemp) || fail "Could not write a temporary file."
        awk -v loc="$loc" "$prog" /etc/locale.gen > "$tmp" 2>/dev/null ||
            printf "%s UTF-8\n" "$loc" > "$tmp"
        if ! cmp -s "$tmp" /etc/locale.gen; then
            sudo install -m 644 "$tmp" /etc/locale.gen || { rm -f "$tmp"; fail "Could not update /etc/locale.gen."; }
        fi
        rm -f "$tmp"
        echo "Generating $loc (this takes a moment)..."
        sudo locale-gen || fail "locale-gen failed — the language was not changed."
        # LANGUAGE and LC_ALL would keep overriding the new LANG
        sudo update-locale "LANG=$loc" LANGUAGE LC_ALL || fail "update-locale failed — the language was not changed."
        echo
        echo "Done. Log out and back in to use it."
        read -rp "Press Enter to close. "
    ' _ "$loc" "$SYSPREFS_LOCALEGEN_AWK"

    if [ "$(sysprefs_system_lang)" = "$loc" ]; then
        tnotify "Language & Region" "$loc is set — log out and back in to use it"
    else
        tnotify "Language & Region" "Not changed — still ${cur:-not set}"
    fi
}

# Turns on <loc> in /etc/locale.gen (stdin to stdout): uncomments its line
# where Debian's list has it commented, adds it where the file has been cut
# down to the installed locales (Tebian's installer writes just one)
# shellcheck disable=SC2016  # awk program, not shell
SYSPREFS_LOCALEGEN_AWK='
{
    s = $0; sub(/^#[[:space:]]*/, "", s)
    split(s, w, /[[:space:]]+/)
    if (!found && w[1] == loc && w[2] == "UTF-8" && w[3] == "") { print loc " UTF-8"; found = 1; next }
    print
}
END { if (!found) print loc " UTF-8" }'

# ---------------------------------------------------------------------------
# Printers
# ---------------------------------------------------------------------------

sysprefs_printing_installed() {
    command -v system-config-printer >/dev/null 2>&1 &&
        dpkg-query -W -f='${Status}' cups 2>/dev/null | grep -q "ok installed"
}

printers_menu() {
    if ! sysprefs_printing_installed; then
        local confirm
        confirm=$(echo -e "No, cancel\nYes, install printer support" | tfuzzel -d --match-mode=exact -p " Printing needs CUPS and system-config-printer. Install them? | " --width 75)
        [[ "$confirm" =~ "Yes" ]] || return
        if ! tebian_term_apt_install cups system-config-printer; then
            tnotify "Printers" "Printer support could not be installed"
            return
        fi
        tnotify "Printers" "Printer support installed — most USB and network printers are found automatically"
    fi
    setsid system-config-printer >/dev/null 2>&1 &
}

# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

# on / off, or why it can't be told: missing (no mako) / stopped (not running)
sysprefs_dnd_state() {
    command -v makoctl >/dev/null 2>&1 || { echo missing; return; }
    local modes
    modes=$(makoctl mode 2>/dev/null) || { echo stopped; return; }
    if grep -qx do-not-disturb <<< "$modes"; then echo on; else echo off; fi
}

notifications_menu() {
    while true; do
    local dnd_label
    case "$(sysprefs_dnd_state)" in
        on)      dnd_label="󰂛 Do Not Disturb (ON)" ;;
        off)     dnd_label="󰂛 Do Not Disturb (OFF)" ;;
        missing) dnd_label="󰂛 Do Not Disturb (mako not installed)" ;;
        *)       dnd_label="󰂛 Do Not Disturb (mako not running)" ;;
    esac
    local CHOICE
    CHOICE=$(echo -e "$dnd_label\n󰍡 Notification History\n󰌍 Back" | tfuzzel -d -p " 󰍡 Notifications | " --width 45)
    [ -n "$CHOICE" ] || menu_close
    if is_back "$CHOICE"; then return; fi
    case "$(sysprefs_words "$CHOICE")" in
        "Do Not Disturb"*)       dnd_toggle ;;
        "Notification History"*) notification_history_menu ;;
    esac
    done
}

# The same switch as the Modern bar's bell (configs/waybar/config.jsonc):
# mako's do-not-disturb mode, then signal 9 so the bar's indicator follows
dnd_toggle() {
    local state
    state=$(sysprefs_dnd_state)
    case "$state" in
        missing)
            tnotify "Do Not Disturb" "Needs mako — Settings > Software > Install Essentials > Notifications"
            return ;;
        stopped)
            tnotify "Do Not Disturb" "mako (the notification daemon) is not running"
            return ;;
    esac
    if ! makoctl mode -t do-not-disturb >/dev/null 2>&1; then
        tnotify "Do Not Disturb" "mako refused the change"
        return
    fi
    pkill -RTMIN+9 -x waybar 2>/dev/null
    if [ "$state" = on ]; then
        tnotify "Do Not Disturb" "Off — notifications show again"
    else
        # Not a notification: do-not-disturb would hide it straight away
        tlog "Do Not Disturb: on"
        # The mode only hides anything if mako's config says what it does
        if ! grep -qs '^\[.*mode=do-not-disturb' "${XDG_CONFIG_HOME:-$HOME/.config}/mako/config"; then
            makoctl mode -r do-not-disturb >/dev/null 2>&1
            pkill -RTMIN+9 -x waybar 2>/dev/null
            tnotify "Do Not Disturb" "Your mako config has no [mode=do-not-disturb] section, so it would hide nothing — left off"
        fi
    fi
}
