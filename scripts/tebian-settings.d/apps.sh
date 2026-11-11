# shellcheck shell=bash
# tebian-settings module: apps.sh
# Sourced by tebian-settings — do not run directly
#
# Default Apps (browser, file manager, terminal) and Startup Apps. Both list
# apps from the shared index in tebian-common (tebian_apps_list) and always
# act by desktop-id, since names are not unique.

# ------------------------------------------------------------------------------
# Reading .desktop files
# ------------------------------------------------------------------------------

# The application dirs in the index's precedence order, so a desktop-id here
# resolves to the same file Mod+D shows. Falls back to tebian-menu's list
# if the index helper is not there (an older tebian-common).
apps_desktop_dirs() {
    if declare -F _tebian_app_dirs >/dev/null; then
        _tebian_app_dirs
        return
    fi
    local d
    for d in "$HOME/.local/share/applications" \
             "$HOME/.local/share/flatpak/exports/share/applications" \
             /usr/share/applications /var/lib/flatpak/exports/share/applications; do
        [ -d "$d" ] && printf '%s\n' "$d"
    done
}

# id<TAB>Categories<TAB>MimeType for every .desktop file, first file per id
# winning. The index leaves these two keys out, and reading them per app
# would be a few hundred awk runs; this is one. Only [Desktop Entry] counts:
# an action group can carry keys of its own.
apps_desktop_meta() {
    local d f
    local -a files=()
    while IFS= read -r d; do
        for f in "$d"/*.desktop; do
            [ -f "$f" ] && files+=("$f")
        done
    done < <(apps_desktop_dirs)
    [ ${#files[@]} -gt 0 ] || return 0
    awk '
        FNR == 1 {
            id = FILENAME; sub(/.*\//, "", id)
            skip = (id in seen); seen[id] = 1; group = ""
            if (!skip) { order[++n] = id; cat[id] = ""; mime[id] = "" }
        }
        skip { next }
        { sub(/[ \t\r]+$/, "") }
        /^\[/ { group = $0; next }
        group != "[Desktop Entry]" { next }
        /^Categories[ \t]*=/ && !(id in gotc) { gotc[id]; v = $0; sub(/^[^=]*=[ \t]*/, "", v); cat[id] = v }
        /^MimeType[ \t]*=/   && !(id in gotm) { gotm[id]; v = $0; sub(/^[^=]*=[ \t]*/, "", v); mime[id] = v }
        END { for (i = 1; i <= n; i++) print order[i] "\t" cat[order[i]] "\t" mime[order[i]] }
    ' "${files[@]}"
}

# Launchable apps of one kind, as id<TAB>name<TAB>icon (index order):
#   browser      Categories has WebBrowser, or it handles http(s) links
#   filemanager  handles inode/directory and calls itself a FileManager
#                (editors such as VS Code claim inode/directory too)
apps_candidates() {
    local kind="$1"
    declare -F tebian_apps_list >/dev/null || return 0
    K="$kind" awk -F'\t' '
        NR == FNR { cat[$1] = ";" $2 ";"; mime[$1] = ";" $3 ";"; next }
        !($1 in cat) { next }
        ENVIRON["K"] == "browser" &&
            (cat[$1] ~ /;WebBrowser;/ || mime[$1] ~ /;x-scheme-handler\/https?;/) { print $1 "\t" $2 "\t" $3 }
        ENVIRON["K"] == "filemanager" &&
            mime[$1] ~ /;inode\/directory;/ && cat[$1] ~ /;FileManager;/ { print $1 "\t" $2 "\t" $3 }
    ' <(apps_desktop_meta) <(tebian_apps_list)
}

# A name to show for a desktop-id, even one that is no longer installed
apps_name_of() {
    local id="$1" name
    [ -n "$id" ] || { echo "Not Set"; return; }
    if declare -F tebian_app_name >/dev/null && name=$(tebian_app_name "$id"); then
        echo "$name"
    else
        echo "${id%.desktop} (not installed)"
    fi
}

# The same, with the id added when another app has that name (Firefox from
# Debian and from Flatpak), so "Current: Firefox" says which one
apps_label_of() {
    local id="$1" name n=0
    [ -n "$id" ] || { echo "Not Set"; return; }
    name=$(apps_name_of "$id")
    if declare -F tebian_apps_list >/dev/null; then
        n=$(tebian_apps_list | N="$name" awk -F'\t' '$2 == ENVIRON["N"] { n++ } END { print n + 0 }')
    fi
    [ "$n" -gt 1 ] && name+=" (${id%.desktop})"
    echo "$name"
}

# Pick one app from id<TAB>name<TAB>icon lines on stdin; prints its id.
# Args: prompt, id to mark "● current". Names shared by two apps get the
# id added so both can be told apart and each label maps to one id. The
# labels carry no glyph (the icon goes to fuzzel out of band), so icon and
# text mode return the same text. Returns 1 on Back or Escape.
apps_pick() {
    local prompt="$1" current="${2:-}"
    local -a ids=() names=() icons=() labels=()
    local -A count=()
    local id name icon i choice
    # Split on \x1f, not tab: read collapses runs of a whitespace IFS, so an
    # empty icon field would take the next field's value
    while IFS=$'\x1f' read -r id name icon _; do
        [ -n "$id" ] || continue
        name="${name:-${id%.desktop}}"
        ids+=("$id"); names+=("$name"); icons+=("$icon")
        count[$name]=$(( ${count[$name]:-0} + 1 ))
    done < <(tr '\t' '\037')
    for i in "${!ids[@]}"; do
        labels[i]="${names[$i]}"
        [ "${count[${names[$i]}]}" -gt 1 ] && labels[i]+=" (${ids[$i]%.desktop})"
        [ "${ids[$i]}" = "$current" ] && labels[i]+="  ● current"
    done

    # Piped straight in, never held in a variable: the "\0icon\x1f"
    # separator is a NUL, which bash variables drop
    choice=$( {
        for i in "${!ids[@]}"; do
            if [ -n "${icons[$i]}" ]; then
                printf '%s\0icon\x1f%s\n' "${labels[$i]}" "${icons[$i]}"
            else
                printf '%s\n' "${labels[$i]}"
            fi
        done
        printf '%s\n' "󰌍 Back"
    } | tfuzzel -d -p " $prompt | " --width 60) || return 1
    [ -n "$choice" ] || return 1
    # Apps before Back: "Back In Time" is a real app, and is_back takes
    # anything starting "Back " for the Back row
    for i in "${!labels[@]}"; do
        if [ "${labels[$i]}" = "$choice" ]; then
            echo "${ids[$i]}"
            return 0
        fi
    done
    return 1
}

# ------------------------------------------------------------------------------
# Default Apps
# ------------------------------------------------------------------------------

# xdg-utils is what browsers and file managers consult (xdg-open), but the
# desktop install does not pull it in; offer it rather than fail quietly
apps_need_xdg() {
    command -v xdg-settings &>/dev/null && command -v xdg-mime &>/dev/null && return 0
    local c
    c=$(printf '%s\n' "󰏗 Install xdg-utils (sets default apps)" "󰌍 Back" \
        | tfuzzel -d -p " xdg-utils not installed | ")
    if [ -z "$c" ] || is_back "$c"; then return 1; fi
    if tebian_term_apt_install xdg-utils; then
        tnotify "Default Apps" "xdg-utils installed"
        return 0
    fi
    tnotify "Default Apps" "xdg-utils install failed"
    return 1
}

apps_current_browser() {
    command -v xdg-settings &>/dev/null || return 0
    xdg-settings get default-web-browser 2>/dev/null | head -1
}

apps_current_file_manager() {
    command -v xdg-mime &>/dev/null || return 0
    xdg-mime query default inode/directory 2>/dev/null | head -1
}

apps_current_terminal() {
    local t
    if declare -F tebian_term_cmd >/dev/null; then t=$(tebian_term_cmd)
    elif declare -F get_term >/dev/null; then t=$(get_term)
    else t="$TERM_CMD"; fi
    echo "${t%% *}"
}

default_apps_menu() {
    while true; do
        local br fm choice
        if command -v xdg-settings &>/dev/null && command -v xdg-mime &>/dev/null; then
            br=$(apps_label_of "$(apps_current_browser)")
            fm=$(apps_label_of "$(apps_current_file_manager)")
        else
            br=""; fm=""
        fi
        # Without xdg-utils there is no current choice to show; picking
        # the row offers to install it
        choice=$(printf '%s\n' "󰖟 Web Browser (${br:+Current: }${br:-xdg-utils Not Installed})" \
            "󰷊 File Manager (${fm:+Current: }${fm:-xdg-utils Not Installed})" \
            "󰆍 Terminal (Current: $(apps_current_terminal))" "󰌍 Back" \
            | tfuzzel -d -p " Default Apps | " --width 60)
        [ -n "$choice" ] || menu_close
        if is_back "$choice"; then return; fi
        # Matched from the start, after the glyph (none in text mode): the
        # current app's name is in the label and could contain another's words
        choice="${choice#"${choice%%[A-Za-z]*}"}"
        case "$choice" in
            "Web Browser"*)  default_browser_menu ;;
            "File Manager"*) default_file_manager_menu ;;
            # The terminal choice is a sway setting, kept by Software's picker
            "Terminal"*)     terminal_menu ;;
        esac
    done
}

default_browser_menu() {
    apps_need_xdg || return
    local cur cands n id
    cur=$(apps_current_browser)
    cands=$(apps_candidates browser)
    n=$(grep -c . <<< "$cands" || true)

    if [ "$n" -eq 0 ]; then
        local c
        c=$(printf '%s\n' "󰖟 Get a Web Browser" "󰌍 Back" | tfuzzel -d -p " No web browser installed | ")
        if [ -z "$c" ] || is_back "$c"; then return; fi
        declare -F browser_menu >/dev/null && browser_menu
        return
    fi
    if [ "$n" -eq 1 ] && [ "${cands%%$'\t'*}" = "$cur" ]; then
        tnotify "Default Apps" "$(apps_name_of "$cur") is the only web browser installed"
        return
    fi

    id=$(apps_pick "󰖟 Web Browser" "$cur" <<< "$cands") || return
    [ "$id" = "$cur" ] && return
    # Generic mode (no GNOME/KDE detected, as under sway) writes the http,
    # https and text/html handlers to mimeapps.list. Some xdg-utils releases
    # refuse there, so do the same by hand when it does.
    if xdg-settings set default-web-browser "$id" 2>/dev/null ||
       xdg-mime default "$id" x-scheme-handler/http x-scheme-handler/https text/html; then
        tnotify "Default Apps" "Web browser: $(apps_label_of "$id")"
    else
        tnotify "Default Apps" "Could not set the web browser to $(apps_name_of "$id")"
    fi
}

default_file_manager_menu() {
    apps_need_xdg || return
    local cur cands n id
    cur=$(apps_current_file_manager)
    cands=$(apps_candidates filemanager)
    n=$(grep -c . <<< "$cands" || true)

    if [ "$n" -eq 0 ]; then
        local c
        c=$(printf '%s\n' "󰏗 Install Thunar" "󰌍 Back" | tfuzzel -d -p " No file manager installed | ")
        if [ -z "$c" ] || is_back "$c"; then return; fi
        if tebian_term_apt_install thunar; then
            tnotify "Default Apps" "Thunar installed"
        else
            tnotify "Default Apps" "Thunar install failed"
        fi
        return
    fi
    if [ "$n" -eq 1 ] && [ "${cands%%$'\t'*}" = "$cur" ]; then
        tnotify "Default Apps" "$(apps_name_of "$cur") is the only file manager installed"
        return
    fi

    id=$(apps_pick "󰷊 File Manager" "$cur" <<< "$cands") || return
    [ "$id" = "$cur" ] && return
    if xdg-mime default "$id" inode/directory; then
        tnotify "Default Apps" "File manager: $(apps_label_of "$id")"
    else
        tnotify "Default Apps" "Could not set the file manager to $(apps_name_of "$id")"
    fi
}

# ------------------------------------------------------------------------------
# Startup Apps
# Kept in config.user's "startup-apps" block, one sway exec line per app:
#
#   # tebian:startup-apps {
#   exec bash -c '. ~/.local/bin/tebian-common && tebian_app_launch thunar.desktop'
#   # tebian:startup-apps }
#
# exec, not exec_always: exec runs once at login, exec_always again on every
# reload and would open a second copy each time. Launching by desktop-id
# through the index runs exactly what Mod+D runs, follows the app if an
# update changes its Exec, and keeps the id in the line, so the list can show
# names and remove the right line. It also keeps the app's own command out of
# sway's parser, which would split an Exec at ";" or ",". Lines a user wrote
# into the block by hand are listed by their command and can be removed too.
# ------------------------------------------------------------------------------

STARTUP_BLOCK="startup-apps"

# The exec line for a desktop-id. Ids are file names; anything that could
# break out of the quotes is refused rather than escaped.
startup_line_for() {
    [[ "$1" =~ ^[A-Za-z0-9._+-]+\.desktop$ ]] || return 1
    printf "exec bash -c '. ~/.local/bin/tebian-common && tebian_app_launch %s'\n" "$1"
}

# The desktop-id in a startup line, empty for a hand-written one
startup_id_of() {
    [[ "$1" =~ tebian_app_launch\ ([A-Za-z0-9._+-]+\.desktop) ]] && echo "${BASH_REMATCH[1]}"
}

startup_apps_menu() {
    while true; do
        local -a lines=() labels=()
        local line id label i choice
        while IFS= read -r line; do
            [[ "$line" =~ ^[[:space:]]*exec[[:space:]] ]] || continue
            id=$(startup_id_of "$line")
            if [ -n "$id" ]; then
                label=$(apps_label_of "$id")
            else
                label="${line#*exec }"
            fi
            # Two lines with one label (hand-edited) still need their own entry
            for i in "${!labels[@]}"; do
                [ "${labels[$i]}" = "$label" ] && label+=" (${#lines[@]})"
            done
            lines+=("$line"); labels+=("$label")
        done < <(tebian_block_get "$STARTUP_BLOCK")

        # When changes apply is said in the prompt, not in a row of its own
        choice=$( {
            printf '%s\n' "󰐊 Add a Startup App"
            [ ${#labels[@]} -gt 0 ] && printf '%s\n' "${labels[@]}"
            printf '%s\n' "󰌍 Back"
        } | tfuzzel -d -p " Startup Apps (from next login) | " --width 60)
        [ -n "$choice" ] || menu_close

        # App entries first: an app could be called "Add a Startup App", or
        # "Back In Time", which is_back would take for Back
        local picked=""
        for i in "${!labels[@]}"; do
            [ "${labels[$i]}" = "$choice" ] && { picked="$i"; break; }
        done
        if [ -n "$picked" ]; then
            startup_remove "${lines[$picked]}" "${labels[$picked]}"
        elif is_back "$choice"; then
            return
        elif [[ "$choice" == *"Add a Startup App"* ]]; then
            startup_add
        fi
    done
}

startup_add() {
    if ! declare -F tebian_apps_list >/dev/null; then
        tnotify "Startup Apps" "The app list is not available (update Tebian)"
        return
    fi
    local present id line cands
    present=$(tebian_block_get "$STARTUP_BLOCK" | while IFS= read -r line; do startup_id_of "$line"; done)
    # Apps already starting are left out rather than offered twice
    cands=$(tebian_apps_list | awk -F'\t' 'NR == FNR { have[$0]; next } !($1 in have)' \
        <(printf '%s\n' "$present") -)
    if [ -z "$cands" ]; then
        tnotify "Startup Apps" "No more apps to add"
        return
    fi
    id=$(apps_pick "󰐊 Start at Login" <<< "$cands") || return
    if grep -qxF -- "$id" <<< "$present"; then
        tnotify "Startup Apps" "$(apps_label_of "$id") already starts at login"
        return
    fi
    if ! line=$(startup_line_for "$id"); then
        tnotify "Startup Apps" "Can't add $id: unusual file name"
        return
    fi
    tebian_block_add_line "$STARTUP_BLOCK" "$line"
    tnotify "Startup Apps" "$(apps_label_of "$id") will start at next login"
}

# Args: the exact line to drop, its label
startup_remove() {
    local line="$1" label="$2" c l
    c=$(printf '%s\n' "󰆴 Remove $label from Startup" "󰌍 Back" \
        | tfuzzel -d -p " Startup Apps | " --width 60)
    if [ -z "$c" ] || is_back "$c"; then return; fi
    [[ "$c" == *"Remove "* ]] || return
    local -a keep=()
    local dropped=0
    while IFS= read -r l; do
        # Only the first copy goes; a duplicate line is its own entry
        if [ "$dropped" = 0 ] && [ "$l" = "$line" ]; then dropped=1; continue; fi
        keep+=("$l")
    done < <(tebian_block_get "$STARTUP_BLOCK")
    tebian_block_set "$STARTUP_BLOCK" "${keep[@]}"
    tnotify "Startup Apps" "$label removed (takes effect at next login)"
}
