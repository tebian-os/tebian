#!/bin/bash
# ==============================================================================
# TEBIAN CHECKS
# Fast, side-effect-free checks for the whole tree: every shell script must
# parse and pass shellcheck at error level, Python helpers must compile, and
# a few invariants that have bitten us before are pinned down here so they
# can't quietly come back. Run from anywhere: bash tests/run.sh
#
# tests/ is left out of the ISO (build-iso.sh) — it's for developers only.
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fails=0
pass() { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; fails=$((fails + 1)); }

# Shell scripts are found by shebang, not extension: most tools in scripts/
# have none. Tracked files only, so local junk doesn't fail the run.
shell_files=()
py_files=()
while IFS= read -r f; do
    [ -f "$f" ] || continue
    first=$(head -c 64 "$f" 2>/dev/null | tr -d '\0' | head -n1 || true)
    case "$first" in
        '#!'*python*) py_files+=("$f") ;;
        '#!'*bash*|'#!'*/sh*) shell_files+=("$f") ;;
        *) [[ "$f" == *.sh ]] && shell_files+=("$f") ;;
    esac
done < <(git ls-files 2>/dev/null || find . -type f -not -path './.git/*')

# 1. Syntax
bad=0
for f in "${shell_files[@]}"; do
    bash -n "$f" 2>/dev/null || { fail "bash -n: $f"; bad=1; }
done
[ "$bad" = 0 ] && pass "bash -n: ${#shell_files[@]} scripts parse"

# 2. shellcheck at error level (warnings are a judgement call; errors aren't)
if command -v shellcheck >/dev/null; then
    if out=$(shellcheck -S error -s bash "${shell_files[@]}" 2>&1); then
        pass "shellcheck -S error: clean"
    else
        echo "$out" | head -40
        fail "shellcheck reported errors"
    fi
else
    echo -e "${YELLOW}!${NC} shellcheck not installed — skipped (sudo apt install shellcheck)"
fi

# 3. Python helpers compile (no bytecode written into the tree)
for f in "${py_files[@]}"; do
    python3 -I -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$f" \
        || fail "python syntax: $f"
done
[ "${#py_files[@]}" -gt 0 ] && pass "python: ${#py_files[@]} files parse"

# 4. Patched sway must rank above Debian's base package but below any Debian
#    stable/security update, or those updates never install.
if command -v dpkg >/dev/null; then
    rev=$(grep -oE '\+[0-9a-z]*tebian' scripts/tebian-build-sway | head -1 || true)
    v="1.10.1-2${rev}1"
    if [ -z "$rev" ]; then
        fail "sway version: can't find the +…tebian suffix in tebian-build-sway"
    elif dpkg --compare-versions "$v" gt 1.10.1-2 &&
         dpkg --compare-versions "$v" lt 1.10.1-2+deb13u1; then
        pass "sway version $v sits between Debian's base and its updates"
    else
        fail "sway version $v blocks Debian updates or loses to the base package"
    fi
fi

# 4b. greetd's own config parser is stricter than TOML (no multi-line
#     strings): a file it can't read means no login screen at all. greetd
#     stops later on (no greeter user here) — only parse errors count.
if command -v greetd >/dev/null; then
    out=$(timeout 5 greetd -c configs/greetd/config.toml 2>&1 || true)
    if grep -qiE 'configuration error|unable to read|expected' <<< "$out"; then
        fail "greetd can't parse configs/greetd/config.toml:"; echo "$out" | head -3
    else
        pass "greetd parses configs/greetd/config.toml"
    fi
else
    echo -e "${YELLOW}!${NC} greetd not installed — login-screen config not checked"
fi

# 5. Nothing that doesn't belong to users may ship: scratch notes and TODO
#    files in the tree are rsync'd straight into the ISO.
stray=$(git ls-files | grep -iE '(^|/)(TODO|NOTES|scratch)[^/]*$|(^|/)CLAUDE\.md$' || true)
if [ -n "$stray" ]; then
    fail "stray dev files would ship in the ISO:"; echo "$stray"
else
    pass "no stray notes/TODO files in the tree"
fi

# 6. Install docs must use HTTPS (tebian.org/install over plain HTTP is
#    a tamperable first hop).
# A bare "curl tebian.org/..." counts too: curl defaults to http://.
plain=$(git grep -nE 'http://(www\.)?tebian\.org|(curl|wget)[^|]*[[:space:]](www\.)?tebian\.org' \
            -- ':!tests' || true)
if [ -n "$plain" ]; then
    fail "plain-http tebian.org links:"; echo "$plain"
else
    pass "tebian.org links are https"
fi

# 7. Settings search: every row opens a function the modules define, and
#    ids (what `tebian-settings --open` takes) are unique. Modules are only
#    sourced — they define functions and variables, nothing runs — in a
#    child shell with a throwaway HOME.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
index_out=$(HOME="$tmp" bash -c '
    for m in scripts/tebian-settings.d/*.sh; do source "$m" || echo "SOURCE-FAILED $m"; done
    printf "%s" "$SETTINGS_INDEX" | while IFS="|" read -r id label words where fn; do
        [ -n "$id" ] || continue
        [ -n "$label" ] && [ -n "$fn" ] || echo "MALFORMED $id"
        declare -F "$fn" >/dev/null || echo "UNDEFINED $id -> $fn"
        echo "ID $id"
    done' 2>&1 || true)
bad=$(grep -E '^(SOURCE-FAILED|MALFORMED|UNDEFINED) ' <<< "$index_out" || true)
dups=$(grep '^ID ' <<< "$index_out" | sort | uniq -d || true)
count=$(grep -c '^ID ' <<< "$index_out" || true)
if [ -n "$bad" ] || [ -n "$dups" ] || [ "$count" -lt 20 ]; then
    fail "settings search index:"; echo "$bad"; [ -z "$dups" ] || echo "duplicate ids: $dups"
    [ "$count" -ge 20 ] || echo "only $count rows read"
else
    pass "settings search: $count rows, all open a defined function, ids unique"
fi

# 8. No entry twice in the Settings top level and More together: the label
#    words without the glyph, and without a hint in parentheses
labels=$( {
    awk '/local -a top=\(/ { f = 1; next } f && /^ *\)/ { exit } f' scripts/tebian-settings |
        sed -E 's/^ *"([^"]*)".*/\1/'
    awk '/^more_menu\(\)/ { f = 1 } f && /M_OPTS="/ { g = 1; sub(/.*M_OPTS="/, "") }
         g { if (sub(/".*/, "")) { print; exit } print }' scripts/tebian-settings.d/system.sh
} | perl -CS -pe 's/[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]//g; s/^\s+//; s/\s*\(.*//' | grep -v '^Back$')
dups=$(sort <<< "$labels" | uniq -d)
if [ -z "$labels" ] || [ "$(wc -l <<< "$labels")" -lt 15 ]; then
    fail "menu labels: couldn't read the top level and More menus"
elif [ -n "$dups" ]; then
    fail "menu entries listed twice in Settings (top level + More):"; echo "$dups"
else
    pass "Settings top level and More: $(wc -l <<< "$labels") entries, none twice"
fi

# 9. The app index (tebian-common) on a fixture tree: a user copy with
#    NoDisplay=true hides the system entry, a missing TryExec hides an app,
#    and only [Desktop Entry]'s own untranslated Name counts
mkdir -p "$tmp/user/applications" "$tmp/sys/applications" "$tmp/home"
printf '[Desktop Entry]\nType=Application\nName=Alpha\nExec=alpha\n' \
    > "$tmp/sys/applications/tebiantest-a.desktop"
printf '[Desktop Entry]\nType=Application\nName=Alpha\nExec=alpha\nNoDisplay=true\n' \
    > "$tmp/user/applications/tebiantest-a.desktop"
printf '[Desktop Entry]\nType=Application\nName=Beta\nExec=beta\nTryExec=/nonexistent/tebian-test-beta\n' \
    > "$tmp/sys/applications/tebiantest-b.desktop"
printf '[Desktop Entry]\nType=Application\nName[de]=Gamma DE\nName=Gamma\nExec=gamma %%U\n\n[Desktop Action new]\nName=New Gamma Window\nExec=gamma --new\n' \
    > "$tmp/sys/applications/tebiantest-c.desktop"
apps=$(HOME="$tmp/home" XDG_DATA_HOME="$tmp/user" XDG_DATA_DIRS="$tmp/sys" XDG_CURRENT_DESKTOP=sway \
    bash -c 'source scripts/tebian-common && tebian_apps_list' 2>&1 | grep '^tebiantest-' || true)
want=$(printf 'tebiantest-c.desktop\tGamma\t\t0')
if [ "$apps" = "$want" ]; then
    pass "app index: NoDisplay override, TryExec, translated and action names handled"
else
    fail "app index on the fixture tree gave:"; printf '%s\n' "$apps" | cat -A | head -5
fi

# 10. Field codes: a quoted code goes with its quotes, %% is a literal %
got=$(bash -c 'source scripts/tebian-common && _tebian_exec_expand "a %U \"%f\" 100%%"' 2>&1 || true)
if [ "$got" = "a   100%" ]; then
    pass "Exec field codes expand as the spec says"
else
    fail "_tebian_exec_expand 'a %U \"%f\" 100%%' gave [$got], expected [a   100%]"
fi

# 11. No key bound twice: config.user is included after the base config, so
#     a second binding there silently replaces the first. Bindings inside a
#     block (mode "resize" { }, bar { }) are separate from the top level.
dups=$(awk '
    { sub(/^[ \t]+/, "") }
    /^#/ { next }
    /\{[ \t]*$/ { scope[++d] = $0; next }
    /^\}/ { if (d) d--; next }
    $1 == "bindsym" {
        k = ""
        for (i = 2; i <= NF; i++) if ($i !~ /^--/) { k = $i; break }
        n = split(tolower(k), p, "+"); # modifiers in any order are one binding
        for (i = 1; i < n; i++) for (j = i + 1; j < n; j++) if (p[j] < p[i]) { t = p[i]; p[i] = p[j]; p[j] = t }
        k = p[n]; for (i = n - 1; i >= 1; i--) k = p[i] "+" k
        s = (d ? scope[d] : "")
        if ((s, k) in seen) print FILENAME ":" FNR ": " k " (also " seen[s, k] ")"
        else seen[s, k] = FILENAME ":" FNR
    }' configs/sway/config configs/sway/config.user)
if [ -n "$dups" ]; then
    fail "sway keys bound twice:"; echo "$dups"
else
    pass "sway: no key bound twice across config and config.user"
fi

# Dock (tebian-dock): on/off is the config.user block, settings land in
# dock.conf, pins in the Mod+D file with hand-added lines kept. A stub
# quickshell, so nothing is started.
if (
    h=$(mktemp -d); trap 'rm -rf "$h"' EXIT
    mkdir -p "$h/bin" "$h/.config/tebian" "$h/Tebian/configs"
    ln -s "$ROOT/configs/panels" "$h/Tebian/configs/panels"
    printf '#!/bin/sh\nexit 0\n' > "$h/bin/quickshell"
    printf '#!/bin/sh\nexit 0\n' > "$h/bin/notify-send"
    chmod +x "$h/bin/quickshell" "$h/bin/notify-send"
    export HOME="$h" TEBIAN_DIR="$h/Tebian" PATH="$h/bin:$PATH"
    unset SWAYSOCK
    d="$ROOT/scripts/tebian-dock"
    ! "$d" status >/dev/null || exit 1
    "$d" on >/dev/null && st=$("$d" status) && grep -qx 'enabled=on' <<< "$st" || exit 1
    grep -qx 'exec tebian-dock run' "$h/.config/sway/config.user" || exit 1
    "$d" position left && [ "$("$d" position)" = left ] || exit 1
    ! "$d" position top 2>/dev/null || exit 1
    "$d" autohide toggle && [ "$("$d" autohide)" = on ] || exit 1
    printf 'kitty.desktop\n# mine\nfoot.desktop' > "$h/.config/tebian/pinned-apps.conf"
    "$d" pin thunar.desktop && "$d" pin thunar.desktop && "$d" unpin kitty.desktop
    [ "$(cat "$h/.config/tebian/pinned-apps.conf")" = $'# mine\nfoot.desktop\nthunar.desktop' ] || exit 1
    ! "$d" pin ../x.desktop 2>/dev/null || exit 1
    "$d" off >/dev/null && ! grep -q 'tebian:dock' "$h/.config/sway/config.user"
); then
    pass "dock: on/off block, position/autohide, pins keep hand-added lines"
else
    fail "dock: tebian-dock state commands"
fi

# Web apps: hostile names and URLs survive the .desktop file and the app
# index unchanged, reach the browser as one argument, and never run
{
    wa=$(mktemp -d); mkdir -p "$wa/bin"
    printf '#!/bin/sh\nfor a; do printf "%%s\\n" "$a"; done > "%s/argv"\n' "$wa" > "$wa/bin/helium"
    printf '#!/bin/sh\nexit 0\n' > "$wa/bin/notify-send"
    chmod +x "$wa/bin/helium" "$wa/bin/notify-send"
    name='x%u;"\`$(touch '"$wa"'/pwned) \\ end'
    url="https://e.com/a'b;c%20d\$(touch\$IFS$wa/pwned2)%u?q=1&r=%c"
    out=$(env -u SWAYSOCK -u WAYLAND_DISPLAY -u XDG_DATA_HOME HOME="$wa" PATH="$wa/bin:$ROOT/scripts:$PATH" bash -c '
        w=scripts/tebian-webapp
        id=$($w add "$1" "$2" --no-icon) || exit 1
        source scripts/tebian-common
        [ "$(tebian_app_name "$id")" = "$1" ] || { echo "name changed"; exit 1; }
        tebian_app_launch "$id" || exit 1
        for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$HOME/argv" ] && break; sleep 0.1; done
        [ "$(cat "$HOME/argv")" = "--app=$2" ] || { echo "argv: $(cat "$HOME/argv")"; exit 1; }
        for bad in "javascript:alert(1)" "file:///etc/passwd" "data:text/html,x" "https://a b" $'"'"'https://a\nExec=x'"'"'; do
            $w check-url "$bad" >/dev/null 2>&1 && { echo "accepted $bad"; exit 1; }
        done
        $w check-name $'"'"'a\nb'"'"' >/dev/null 2>&1 && { echo "accepted a newline"; exit 1; }
        $w remove "$id" && [ ! -e "$HOME/.local/share/applications/$id" ]
    ' _ "$name" "$url" 2>&1) && [ ! -e "$wa/pwned" ] && [ ! -e "$wa/pwned2" ] &&
        pass "web apps: odd names and URLs stay data" || fail "web apps: $out"
    rm -rf "$wa"
}

# Recording: nothing running means "not recording", and the bar gets JSON
if (
    d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
    export XDG_RUNTIME_DIR="$d" HOME="$d"
    ! scripts/tebian-record status >/dev/null 2>&1 &&
        scripts/tebian-record bar | grep -q '"text": *""'
); then
    pass "record: idle status and bar output"
else
    fail "record: status/bar while idle"
fi

# Pins: whoever asks first writes the defaults, never an empty file
if (
    d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
    export HOME="$d"
    source scripts/tebian-common
    tebian_pin_app zz.desktop &&
        grep -qxF kitty.desktop "$d/.config/tebian/pinned-apps.conf" &&
        [ "$(tail -1 "$d/.config/tebian/pinned-apps.conf")" = zz.desktop ]
); then
    pass "pins: first pin keeps the defaults"
else
    fail "pins: first pin lost the defaults"
fi

# The kitty config a user gets is the theme's copy, not configs/kitty: a
# setting added only there never reached anyone (new terminals kept opening
# at the setup window's full-screen size)
bad=0
for f in configs/themes/*/kitty.conf; do
    grep -q '^remember_window_size no' "$f" && grep -q '^initial_window_width' "$f" ||
        { fail "kitty: $f lacks the window size lines of configs/kitty/kitty.conf"; bad=1; }
done
[ "$bad" = 0 ] && pass "kitty: every theme opens new windows at a set size"

# The Modern bar's launcher starts one bar and nothing after it. sway ends
# the bar on every reload and starts the next itself; a launcher that put
# plain swaybar in Waybar's place (3.7.2) left two bars on screen.
if (
    h=$(mktemp -d); trap 'rm -rf "$h"' EXIT
    mkdir -p "$h/bin" "$h/home/.config/sway" "$h/run"
    for c in waybar swaybar swaymsg systemctl dbus-update-activation-environment; do
        printf '#!/bin/sh\necho "$0" >> "%s/started"\nexit 0\n' "$h" > "$h/bin/$c"
        chmod +x "$h/bin/$c"
    done
    HOME="$h/home" XDG_RUNTIME_DIR="$h/run" TEBIAN_DIR="$ROOT" PATH="$h/bin:/usr/bin:/bin" \
        bash "$ROOT/scripts/tebian-bar" -b bar-0 >/dev/null 2>&1
    grep -q '/waybar$' "$h/started" && ! grep -q '/swaybar$' "$h/started"
); then
    pass "bar: when Waybar ends, the launcher starts no second bar"
else
    fail "bar: tebian-bar started swaybar after Waybar ended (two bars after a reload)"
fi

# ...and starts it deaf to the refresh signals (pkill -RTMIN+n -x waybar)
# until it listens for them itself: one arriving while Waybar was still
# loading ended it without a word, and the bar was missing after login.
if (
    h=$(mktemp -d); trap 'rm -rf "$h"' EXIT
    mkdir -p "$h/bin" "$h/home/.config/sway" "$h/run"
    for c in swaybar swaymsg systemctl dbus-update-activation-environment; do
        printf '#!/bin/sh\nexit 0\n' > "$h/bin/$c"; chmod +x "$h/bin/$c"
    done
    # Stands in for Waybar: notes which signals it was started ignoring
    printf '#!/bin/sh\ngrep SigIgn /proc/self/status > "%s/sigign"\n' "$h" > "$h/bin/waybar"
    chmod +x "$h/bin/waybar"
    HOME="$h/home" XDG_RUNTIME_DIR="$h/run" TEBIAN_DIR="$ROOT" PATH="$h/bin:/usr/bin:/bin" \
        bash "$ROOT/scripts/tebian-bar" -b bar-0 >/dev/null 2>&1
    ign=$(awk '{print $2}' "$h/sigign")
    # signals 34-64 are bits 33-63 of the mask
    [ $(( (0x$ign >> 33) & 0x7fffffff )) -eq $(( 0x7fffffff )) ]
); then
    pass "bar: Waybar starts ignoring refresh signals until it handles them"
else
    fail "bar: a refresh signal during Waybar's start would end it (no bar after login)"
fi

# The Wi-Fi fix reaches every install path, and says only what modprobe
# accepts (an "options" line for rtw88_core; a typo there is silently ignored)
wifi_conf="configs/modprobe/tebian-wifi.conf"
if [ "$(grep -v '^[[:space:]]*\(#\|$\)' "$ROOT/$wifi_conf")" = "options rtw88_core disable_lps_deep=y" ] &&
   grep -q "queue_root $wifi_conf .*/etc/modprobe.d/tebian-wifi.conf" "$ROOT/scripts/tebian-update" &&
   grep -q "$wifi_conf\" /etc/modprobe.d/tebian-wifi.conf" "$ROOT/scripts/desktop.sh" &&
   grep -q "$wifi_conf\" *\\\\$" "$ROOT/scripts/tebian-installer" &&
   grep -q "/etc/modprobe.d/tebian-wifi.conf" "$ROOT/scripts/uninstall.sh"; then
    pass "wifi: the Realtek power-save fix is installed by setup, installer and update"
else
    fail "wifi: $wifi_conf is missing from an install path, or not a single rtw88_core option"
fi

# tebian-update takes the power-key line older Tebian wrote into config.user
# out (sway shows a warning bar for a key bound twice), and nothing else; a
# binding of the user's own stays. Runs that section of the real script.
if (
    h=$(mktemp -d); trap 'rm -rf "$h"' EXIT
    sed -n '/^# --- 3b. A power-key line/,/^# --- 3b. Main sway config/p' "$ROOT/scripts/tebian-update" > "$h/part.sh"
    run() { HOME="$h" TEBIAN_DIR="$ROOT" bash -c 'info() { :; }; source "$1"' _ "$h/part.sh"; }
    mkdir -p "$h/.config/sway"; u="$h/.config/sway/config.user"
    printf '%s\n' "# Power button opens Tebian power menu" \
        "bindsym XF86PowerOff exec tebian-settings --power" "" \
        "# Workspace manager (Mod+W)" "bindsym \$mod+w exec tebian-workspace" > "$u"
    run
    [ "$(cat "$u")" = "$(printf '%s\n' "# Workspace manager (Mod+W)" "bindsym \$mod+w exec tebian-workspace")" ] &&
        [ -f "$u.before-update" ] || exit 1
    # The user's own power key: untouched, no backup made
    rm "$u.before-update"
    printf '%s\n' "bindsym XF86PowerOff exec my-power-menu" > "$u"
    run
    [ "$(cat "$u")" = "bindsym XF86PowerOff exec my-power-menu" ] && [ ! -e "$u.before-update" ]
); then
    pass "update: the old power-key line leaves config.user (no warning bar on reload)"
else
    fail "update: config.user still binds XF86PowerOff twice, or lost a line of the user's"
fi

# What the Desktop & UI switches do to real windows (its own hidden sway;
# skips with a note where sway or a terminal is missing)
if bash "$ROOT/tests/desktop.sh"; then
    pass "desktop: switches change real windows (tests/desktop.sh)"
else
    fail "desktop: tests/desktop.sh"
fi

echo
if [ "$fails" -eq 0 ]; then
    echo -e "${GREEN}All checks passed.${NC}"
else
    echo -e "${RED}$fails check(s) failed.${NC}"; exit 1
fi
