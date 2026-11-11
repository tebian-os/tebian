# shellcheck shell=bash
# tebian-settings module: webapps.sh
# Sourced by tebian-settings — do not run directly
#
# Web Apps: a site as its own app in Super+D and the dock. The work is done by
# tebian-webapp; this is only its menu. Apps are picked by position
# (fuzzel --index), never by label: a web app may be called "Back" or
# "Add Web App" and is still just that app.

# The tebian-webapp next to Settings (a checkout run in place), else PATH's
webapps_run() {
    local w="${SCRIPT_DIR:-}/tebian-webapp"
    [ -x "$w" ] || w=tebian-webapp
    "$w" "$@"
}

webapps_menu() {
    while true; do
        local -a ids=() names=() urls=() icons=()
        local id name url icon pick host line i
        while IFS= read -r line; do
            id="${line%%$'\t'*}"; line="${line#*$'\t'}"
            name="${line%%$'\t'*}"; line="${line#*$'\t'}"
            url="${line%%$'\t'*}"; icon="${line#*$'\t'}"
            ids+=("$id"); names+=("$name"); urls+=("$url"); icons+=("$icon")
        done < <(webapps_run list 2>/dev/null)

        # Printed straight into the pipe: the icon separator is a NUL, which
        # bash variables drop (see tfuzzel)
        pick=$( {
            printf '%s\n' "󰐊 Add Web App"
            for i in "${!ids[@]}"; do
                host="${urls[$i]#*://}"; host="${host%%[/?#]*}"
                if [ -n "${icons[$i]}" ]; then
                    printf '%s  (%s)\0icon\x1f%s\n' "${names[$i]}" "$host" "${icons[$i]}"
                else
                    printf '%s  (%s)\n' "${names[$i]}" "$host"
                fi
            done
            printf '%s\n' "󰌍 Back"
        } | tfuzzel -d --index -p " 󰖟 Web Apps | " --width 60)
        [ -n "$pick" ] || menu_close
        # Enter on typed text that matched nothing: show it again
        [[ "$pick" =~ ^[0-9]+$ ]] || continue
        if [ "$pick" -eq 0 ]; then
            webapps_add
        elif [ "$pick" -le "${#ids[@]}" ]; then
            webapps_app_menu "${ids[pick - 1]}" "${names[pick - 1]}" "${urls[pick - 1]}"
        else
            return 0
        fi
    done
}

# Web apps open in a Chrome-based browser's app mode. Firefox has none, so
# with only Firefox (or Zen) installed this says so and offers the browser
# menu, instead of making a launcher that could never open.
webapps_need_browser() {
    webapps_run browser >/dev/null 2>&1 && return 0
    local c
    # The why is in the prompt: a row of its own was one more thing to pick
    c=$(printf '%s\n' "󰖟 Get a Chrome-based browser (Helium)" "󰌍 Back" \
        | tfuzzel -d -p " 󰖟 Web apps need a Chrome-based browser (Firefox and Zen have no app mode) | " --width 90)
    [ -n "$c" ] || return 1
    is_back "$c" && return 1
    [[ "$c" == *"Get a Chrome-based browser"* ]] || return 1
    if declare -F browser_menu >/dev/null; then
        browser_menu
    else
        tnotify "Web Apps" "Install Helium in Settings > Software > Web Browser"
    fi
    webapps_run browser >/dev/null 2>&1
}

# Asks until tebian-webapp accepts the text or Escape; prints what it made
# of it (trimmed name, normalized URL). Args: what to run, prompt.
webapps_ask() {
    local check="$1" prompt="$2" text out msg=""
    while true; do
        if [ -n "$msg" ]; then
            text=$(tfuzzel -d --prompt-only " 󰖟 $msg — try again: " --width 70 < /dev/null) || return 1
        else
            text=$(tfuzzel -d --prompt-only " 󰖟 $prompt " --width 70 < /dev/null) || return 1
        fi
        [ -n "$text" ] || return 1
        if out=$(webapps_run "$check" "$text" 2>&1); then
            printf '%s\n' "$out"
            return 0
        fi
        msg="$out"
    done
}

webapps_add() {
    webapps_need_browser || return
    local name url id rc=0
    name=$(webapps_ask check-name "Name of the web app:") || return
    url=$(webapps_ask check-url "Address of $name (e.g. mail.example.com):") || return
    tnotify "Web Apps" "Adding $name..."
    id=$(webapps_run add "$name" "$url" 2>&1) || rc=$?
    case "$rc" in
        0) tnotify "Web Apps" "$name added: find it in Super+D" ;;
        3) webapps_need_browser ;;
        *) tnotify "Web Apps" "Could not add $name: $id" ;;
    esac
}

# Args: id, name, url
webapps_app_menu() {
    local id="$1" name="$2" url="$3" pin c new err
    while true; do
        if webapps_run pinned "$id" 2>/dev/null; then pin="󰄬 Pinned to Menu (ON)"; else pin="󰄰 Pinned to Menu (OFF)"; fi
        c=$(printf '%s\n' "󰐊 Open" "󰏫 Rename" "󰖟 Change Address" "$pin" "󰆴 Remove" "󰌍 Back" \
            | tfuzzel -d -p " 󰖟 $name | " --width 60)
        [ -n "$c" ] || menu_close
        is_back "$c" && return
        c="${c#"${c%%[A-Za-z]*}"}"
        case "$c" in
            Open*)
                if tebian_app_launch "$id"; then
                    menu_close
                fi
                tnotify "Web Apps" "Could not open $name"
                ;;
            Rename*)
                new=$(webapps_ask check-name "New name for $name:") || continue
                if err=$(webapps_run rename "$id" "$new" 2>&1); then
                    tnotify "Web Apps" "$name is now called $new"
                    name="$new"
                else
                    tnotify "Web Apps" "Could not rename $name: $err"
                fi
                ;;
            "Change Address"*)
                new=$(webapps_ask check-url "New address (now $url):") || continue
                if err=$(webapps_run set-url "$id" "$new" 2>&1); then
                    tnotify "Web Apps" "$name now opens $new"
                    url="$new"
                else
                    tnotify "Web Apps" "Could not change the address: $err"
                fi
                ;;
            "Pinned to Menu (ON)"*)
                if err=$(webapps_run unpin "$id" 2>&1); then
                    tnotify "Web Apps" "$name unpinned from Super+D"
                else
                    tnotify "Web Apps" "Could not unpin $name: $err"
                fi
                ;;
            "Pinned to Menu (OFF)"*)
                if err=$(webapps_run pin "$id" 2>&1); then
                    tnotify "Web Apps" "$name pinned to Super+D"
                else
                    tnotify "Web Apps" "$err"
                fi
                ;;
            Remove*)
                # By position: the name is in the label and could read "Back"
                c=$(printf '%s\n' "󰆴 Remove $name" "󰌍 Back" |
                    tfuzzel -d --index -p " 󰖟 $name | " --width 60)
                [ "$c" = 0 ] || continue
                if webapps_run remove "$id"; then
                    tnotify "Web Apps" "$name removed"
                    return
                fi
                tnotify "Web Apps" "Could not remove $name"
                ;;
        esac
    done
}
