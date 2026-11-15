#!/bin/bash
# ==============================================================================
# TEBIAN UPGRADE CHECK
# What tebian-update does to an install of every earlier release: for each
# release tag, a throwaway home is laid out the way that release's installer
# left it (its scripts, its sway config and config.user, its theme), and
# this tree's tebian-update is run over it. Afterwards the update must have
# succeeded, every tool in ~/.local/bin must be this tree's, and sway must
# read the resulting config without an error or a key bound twice — the
# warning bar 3.7.5 put on every older install after its first update.
#
#   bash tests/upgrade.sh             # every release tag
#   bash tests/upgrade.sh v3.4.0 ...  # only these
#
# Nothing outside the throwaway home is touched: sudo, curl and the calls
# that would reach the running desktop are stand-ins. Needs git with the
# release tags (skips with a note in a shallow clone) and sway.
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fails=0
pass() { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; fails=$((fails + 1)); }
skip() { echo -e "${YELLOW}!${NC} upgrade checks skipped — $*"; exit 0; }

command -v git >/dev/null || skip "git not installed"
SWAY=$(command -v sway || true)
[ -n "$SWAY" ] || { [ -x /opt/tebian-swayfx/bin/sway ] && SWAY=/opt/tebian-swayfx/bin/sway; }
[ -n "$SWAY" ] || skip "sway not installed"

# Releases older than 3.2 predate tebian-update and its layout
if [ "$#" -gt 0 ]; then
    tags=("$@")
else
    mapfile -t tags < <(git -C "$ROOT" tag --list 'v[0-9]*' --sort=version:refname 2>/dev/null |
                        awk -F'[v.]' '$2 > 3 || ($2 == 3 && $3 >= 2)')
fi
[ "${#tags[@]}" -gt 0 ] || skip "no release tags in this checkout (git fetch --tags)"

# The scripts tebian-update keeps out of ~/.local/bin
SKIP_SCRIPTS=$(sed -n 's/^SKIP_SCRIPTS="\(.*\)"$/\1/p' "$ROOT/scripts/tebian-update")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for tag in "${tags[@]}"; do
    h="$work/$tag"
    home="$h/home"
    mkdir -p "$home/.local/bin" "$home/.config/sway" "$h/bin" "$h/run"
    git -C "$ROOT" archive --prefix=Tebian/ "$tag" | tar x -C "$home"
    old="$home/Tebian"
    for f in "$old"/scripts/*; do
        [ -f "$f" ] && cp "$f" "$home/.local/bin/"
    done
    cp "$old/configs/sway/config" "$home/.config/sway/config"
    cp "$old/configs/themes/glass/sway-theme" "$home/.config/sway/theme"
    [ -f "$old/configs/sway/config.user" ] && cp "$old/configs/sway/config.user" "$home/.config/sway/config.user"
    # Releases that record the sway config's checksum did so at install
    if grep -qs 'sway-config.sha256' "$old/scripts/tebian-update"; then
        mkdir -p "$home/.local/share/tebian"
        sha256sum "$home/.config/sway/config" | cut -d' ' -f1 > "$home/.local/share/tebian/sway-config.sha256"
    fi

    # Stand-ins: root actions are only noted, the network is down, and no
    # sway is running (so nothing reloads the desktop this runs on)
    printf '#!/bin/sh\necho "$*" >> "%s/sudo.log"\n' "$h" > "$h/bin/sudo"
    printf '#!/bin/sh\nexit 1\n' > "$h/bin/pgrep"
    # apt too: the snapping step would otherwise download sway's source
    for tool in curl apt apt-get; do cp "$h/bin/pgrep" "$h/bin/$tool"; done
    printf '#!/bin/sh\nexit 0\n' > "$h/bin/swaymsg"
    chmod +x "$h/bin/"*

    problems=""
    if ! env -i HOME="$home" PATH="$h/bin:/usr/bin:/bin" TEBIAN_UPDATE_SRC="$ROOT" \
            bash "$ROOT/scripts/tebian-update" > "$h/update.log" 2>&1; then
        problems+=" tebian-update failed ($(tail -1 "$h/update.log"));"
    fi
    [ "$(cat "$old/VERSION")" = "$(cat "$ROOT/VERSION")" ] || problems+=" ~/Tebian is still $(cat "$old/VERSION");"
    for f in "$ROOT"/scripts/*; do
        [ -f "$f" ] || continue
        b=${f##*/}
        case " $SKIP_SCRIPTS " in *" $b "*) continue ;; esac
        cmp -s "$f" "$home/.local/bin/$b" || problems+=" ~/.local/bin/$b is not the new one;"
    done

    # Sway reads the config for real (-C: check and exit), with the lines
    # that would start programs commented out. -d because a key bound twice
    # is only an INFO line there, though the desktop shows it as a warning bar
    sed -i -E 's/^([[:space:]]*)(exec(_always)?[[:space:]])/\1# \2/' "$home/.config/sway/config" "$home/.config/sway/config.user" 2>/dev/null || true
    sway_out=$(HOME="$home" XDG_RUNTIME_DIR="$h/run" WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
        PATH="$home/.local/bin:/usr/bin:/bin" timeout 30 "$SWAY" -d -C -c "$home/.config/sway/config" 2>&1 || true)
    sway_bad=$(grep -E '\[ERROR\]|Overwriting binding' <<< "$sway_out" | head -3 | sed 's/^[0-9:.]* //' || true)
    [ -z "$sway_bad" ] || problems+=" sway: $sway_bad;"

    if [ -z "$problems" ]; then
        pass "upgrade from $tag: update runs, tools are current, sway accepts the config"
    else
        fail "upgrade from $tag:$problems"
    fi
done

echo
if [ "$fails" -eq 0 ]; then
    echo -e "${GREEN}Upgrade checks passed.${NC}"
else
    echo -e "${RED}$fails upgrade check(s) failed.${NC}"; exit 1
fi
