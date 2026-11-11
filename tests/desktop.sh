#!/bin/bash
# ==============================================================================
# TEBIAN DESKTOP CHECKS
# What the Desktop & UI switches do to real windows, not what they write
# down. "Title Bars (ON)" once passed every check while the browser had no
# title bar: the setting was saved and the label matched, but nothing had
# looked at a window. So this starts a sway of its own with no screen
# (headless backend, its own runtime dir and HOME — the session it is run
# from is not touched), opens real windows, flips each switch through the
# same functions Settings calls, and asks sway what the windows and the bar
# look like — straight away, and again for a window opened afterwards.
#
# Needs sway, foot or kitty, and python3; zenity stands in for the apps that
# draw their own frame (GTK dialogs, Chromium-family browsers). Skips, with
# a note, when they are missing. Run by tests/run.sh, or on its own.
# ==============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fails=0
pass() { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; fails=$((fails + 1)); }
skip() { echo -e "${YELLOW}!${NC} desktop checks skipped — $*"; exit 0; }

command -v sway >/dev/null || skip "sway not installed"
command -v python3 >/dev/null || skip "python3 not installed"
TERM_APP=""
for t in foot kitty; do command -v "$t" >/dev/null && { TERM_APP=$t; break; }; done
[ -n "$TERM_APP" ] || skip "no terminal (foot or kitty) to open as a test window"

REAL_PATH=$PATH
W=$(mktemp -d)
export HOME="$W/home" XDG_RUNTIME_DIR="$W/run"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache"
mkdir -p "$HOME/.config/sway" "$HOME/.config/tebian" "$HOME/.config/wob" "$W/bin" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY SWAYSOCK DISPLAY I3SOCK DBUS_SESSION_BUS_ADDRESS

# Settings stops and restarts helpers by name (wob, the status script). By
# name is by name: the developer's own would go too, so here it does nothing.
printf '#!/bin/sh\nexit 0\n' > "$W/bin/pkill"
cp "$W/bin/pkill" "$W/bin/notify-send"
chmod +x "$W/bin/pkill" "$W/bin/notify-send"
export PATH="$W/bin:$ROOT/scripts:$REAL_PATH"

# The shipped theme and bar, without the session's helpers (notifications,
# idle lock, polkit...): those belong to a real login
cp "$ROOT/configs/themes/glass/sway-theme" "$HOME/.config/sway/theme"
: > "$HOME/.config/sway/config.user"
cat > "$HOME/.config/sway/config" <<EOF
set \$mod Mod4
include ~/.config/sway/theme
xwayland disable
output HEADLESS-1 resolution 1280x800
bar {
    position top
    mode dock
    status_command while echo test; do sleep 600; done
}
include ~/.config/sway/config.user
EOF

SWAY_PID=""
cleanup() {
    # Only what was started here: by PID, and the clients go with their sway
    [ -n "$SWAY_PID" ] && kill "$SWAY_PID" 2>/dev/null
    sleep 0.3
    case "$W" in /tmp/*|/var/tmp/*) rm -rf "$W" ;; esac
}
trap cleanup EXIT

WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
    sway -c "$HOME/.config/sway/config" > "$W/sway.log" 2>&1 &
SWAY_PID=$!
for _ in $(seq 50); do
    SWAYSOCK=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock 2>/dev/null | head -1)
    [ -n "$SWAYSOCK" ] && break
    sleep 0.1
done
[ -n "${SWAYSOCK:-}" ] || skip "sway would not start without a screen here ($(tail -1 "$W/sway.log" 2>/dev/null))"
export SWAYSOCK
export WAYLAND_DISPLAY
WAYLAND_DISPLAY=$(basename "$(ls "$XDG_RUNTIME_DIR"/wayland-[0-9] 2>/dev/null | head -1)")

# "app_id border floating|tiled" for every window
windows() {
    swaymsg -t get_tree | python3 -c '
import json, sys
def walk(n, floating=False):
    for c in n.get("nodes", []): walk(c, False)
    for c in n.get("floating_nodes", []): walk(c, True)
    if n.get("app_id"):
        print(n["app_id"], n["border"], "floating" if n["type"] == "floating_con" else "tiled")
walk(json.load(sys.stdin))'
}
# win_is APP FIELD VALUE — field 2 is the border, 3 floating/tiled
win_is() { windows | awk -v a="$1" -v f="$2" -v v="$3" '$1 == a { n++; if ($f != v) bad = 1 } END { exit !(n && !bad) }'; }
wait_win() {  # an app's window is on screen
    for _ in $(seq 60); do windows | grep -q "^$1 " && return 0; sleep 0.1; done
    return 1
}
bar_is() { swaymsg -r -t get_bar_config bar-0 | grep -q "\"$1\": *\"$2\""; }
settle() { sleep 0.6; }
open_term() {  # open_term APP_ID
    if [ "$TERM_APP" = foot ]; then foot -a "$1" sh -c 'sleep 300' >/dev/null 2>&1 &
    else kitty --class "$1" sh -c 'sleep 300' >/dev/null 2>&1 &
    fi
    wait_win "$1"
}
check() {  # check "what" command...
    local what="$1"; shift
    if "$@"; then pass "$what"; else fail "$what — windows now: $(windows | tr '\n' ';')"; fi
}

# The functions Settings itself calls
# shellcheck source=../scripts/tebian-common
source "$ROOT/scripts/tebian-common"
tnotify() { :; }
tlog() { :; }
for m in "$ROOT"/scripts/tebian-settings.d/*.sh; do
    # shellcheck disable=SC1090
    source "$m"
done

open_term t1 || { fail "desktop: could not open a test window ($TERM_APP)"; exit 1; }
HAVE_CSD=0
if command -v zenity >/dev/null; then
    zenity --info --text test >/dev/null 2>&1 &
    wait_win zenity && HAVE_CSD=1
fi

# --- Title bars ---------------------------------------------------------------
titlebars_set on; settle
check "title bars on: an open window gets one" win_is t1 2 normal
[ "$HAVE_CSD" = 1 ] &&
    check "title bars on: an open app with its own frame gets one" win_is zenity 2 normal
swaymsg -q reload; settle
open_term t2
check "title bars on: a window opened later has one" win_is t2 2 normal
if [ "$HAVE_CSD" = 1 ]; then
    swaymsg -q '[app_id="zenity"] kill'; settle
    zenity --info --text test >/dev/null 2>&1 &
    wait_win zenity; settle
    check "title bars on: an app with its own frame, opened later, has one" win_is zenity 2 normal
fi
titlebars_set off; settle
check "title bars off: open windows lose them" win_is t1 2 pixel
swaymsg -q reload; settle
open_term t3
check "title bars off: a window opened later has none" win_is t3 2 pixel

# --- Window layout ------------------------------------------------------------
tebian_block_remove floating-mode
swaymsg -q '[app_id="^t[0-9]$"] floating disable'; settle
window_layout_toggle; sleep 1.5
check "floating layout: open windows float" win_is t1 3 floating
open_term t4
check "floating layout: a window opened later floats" win_is t4 3 floating
window_layout_toggle; sleep 1.5
check "tiling layout: open windows tile" win_is t1 3 tiled
open_term t5
check "tiling layout: a window opened later tiles" win_is t5 3 tiled

# --- Bar ------------------------------------------------------------------------
bar_set_position bottom; sleep 1.5
check "bar position: bottom reaches the bar" bar_is position bottom
check "bar position: the menu reads bottom" test "$(bar_get position)" = bottom
bar_set_position top; sleep 1.5
check "bar position: top reaches the bar" bar_is position top
bar_set_mode hide; settle
check "bar visibility: auto-hide reaches the bar" bar_is mode hide
swaymsg -q reload; settle
check "bar visibility: auto-hide survives a reload" bar_is mode hide
bar_set_mode dock; settle
check "bar visibility: always shown reaches the bar" bar_is mode dock

# --- Desktop Feel ---------------------------------------------------------------
apply_feel Windows; sleep 1.5
check "feel Windows: windows float with title bars" win_is t1 3 floating
check "feel Windows: title bars" win_is t1 2 normal
check "feel Windows: bar at the bottom" bar_is position bottom
check "feel Windows: marked as current" test "$(feel_current)" = Windows
apply_feel Tiling; sleep 1.5
check "feel Tiling: open windows tile" win_is t1 3 tiled
check "feel Tiling: open windows lose their title bars" win_is t1 2 pixel
check "feel Tiling: bar auto-hides" bar_is mode hide
check "feel Tiling: marked as current" test "$(feel_current)" = Tiling

# A config.user that sway rejects would have cost a setting silently
if grep -qE 'Error on line|Unknown/invalid command' "$W/sway.log"; then
    fail "sway rejected a config line: $(grep -E 'Error on line|Unknown/invalid command' "$W/sway.log" | head -3 | tr '\n' ' ')"
else
    pass "sway accepted every config written"
fi

echo
[ "$fails" -eq 0 ] || { echo -e "${RED}$fails desktop check(s) failed.${NC}"; exit 1; }
echo -e "${GREEN}Desktop checks passed.${NC}"
