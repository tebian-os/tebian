#!/bin/bash
# ==============================================================================
# TEBIAN REMOTE INSTALLER
# Usage: curl -sL tebian.org/install | bash
# Local: bash install.sh --local
# Fleet: curl -sL tebian.org/install | bash -s -- --repo https://git.company.com/org/tebian.git
# Works on: Debian 13 (trixie) or newer, and trixie-based Raspberry Pi OS / Armbian
#
# Unattended: TEBIAN_MODE=desktop|server skips the menu (needed when there's
# no terminal to ask on). TEBIAN_CHANNEL=main installs the unreleased
# development branch instead of the latest verified release.
# ==============================================================================

set -euo pipefail
# Let failures inside $(...) abort too (bash otherwise drops -e there)
shopt -s inherit_errexit

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

TEBIAN_DIR="$HOME/Tebian"
TEBIAN_GH="https://github.com/tebian-os/tebian"
TEBIAN_CHANNEL="${TEBIAN_CHANNEL:-stable}"
USE_GIT=""
TEBIAN_REPO=""
USE_LOCAL=""
LOCAL_SRC=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)
            USE_LOCAL="yes"
            # Check if next arg is a path (not another flag)
            if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
                LOCAL_SRC="$2"
                shift 2
            else
                shift
            fi
            ;;
        --repo)
            USE_GIT="yes"
            TEBIAN_REPO="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo ""
echo "  ┌───────────────┐"
echo "  │  T E B I A N  │"
echo "  └───────────────┘"
echo ""

# --- Supported system check ---------------------------------------------------
# Tebian depends on trixie-era packages (sway 1.10, nwg-hello, gtklock). On
# bookworm or Ubuntu the package install fails halfway through, after system
# files have already been changed — so refuse up front instead.
check_supported_os() {
    if [ ! -f /etc/os-release ] || [ ! -f /etc/debian_version ]; then
        echo -e "${RED}  Error: Tebian requires Debian 13 (trixie) or newer.${NC}"
        exit 1
    fi
    local id ver code pretty
    id=$(. /etc/os-release && echo "${ID:-}")
    ver=$(. /etc/os-release && echo "${VERSION_ID:-}")
    code=$(. /etc/os-release && echo "${VERSION_CODENAME:-}")
    pretty=$(. /etc/os-release && echo "${PRETTY_NAME:-unknown}")

    local ok=""
    case "$id" in
        # raspbian = 32-bit Raspberry Pi OS; 64-bit Pi OS and Armbian report debian
        debian|raspbian)
            if [[ "$ver" =~ ^[0-9]+$ ]] && [ "$ver" -ge 13 ]; then
                ok=1
            fi
            # testing/unstable carry no VERSION_ID
            case "$code" in trixie|forky|duke|sid) ok=1 ;; esac
            ;;
    esac

    if [ -z "$ok" ]; then
        if [ "${TEBIAN_FORCE:-}" = 1 ]; then
            echo -e "${YELLOW}  ⚠ $pretty is not supported — continuing because TEBIAN_FORCE=1.${NC}"
            echo ""
            return
        fi
        echo -e "${RED}  Error: $pretty is not supported.${NC}"
        echo ""
        echo "  Tebian needs Debian 13 (trixie) or newer, or a trixie-based"
        echo "  Raspberry Pi OS / Armbian. Older releases and Ubuntu lack packages"
        echo "  Tebian depends on (sway 1.10, nwg-hello, gtklock)."
        echo ""
        echo "  To try anyway: curl -sL tebian.org/install | TEBIAN_FORCE=1 bash"
        exit 1
    fi
}
check_supported_os

echo -e "  ${GREEN}Detected:${NC} $(. /etc/os-release && echo "$PRETTY_NAME")"
echo -e "  ${GREEN}Architecture:${NC} $(uname -m)"
if [ -f /sys/firmware/devicetree/base/model ]; then
    echo -e "  ${GREEN}Hardware:${NC} $(tr -d '\0' < /sys/firmware/devicetree/base/model)"
fi
echo ""

# --- Terminal for prompts -----------------------------------------------------
# Under `curl ... | bash` stdin is the script itself, so a plain `read` gets
# EOF (and `read -p` doesn't even show its prompt). Prompts read /dev/tty.
HAVE_TTY=""
if ( : </dev/tty ) 2>/dev/null; then
    HAVE_TTY=1
elif [ -z "${TEBIAN_MODE:-}" ]; then
    echo -e "${RED}  Error: no terminal available to ask questions on.${NC}"
    echo ""
    echo "  Run this from an interactive terminal (over SSH, use ssh -t), or"
    echo "  choose the mode up front for an unattended install:"
    echo "    curl -sL tebian.org/install | TEBIAN_MODE=desktop bash"
    exit 1
fi

# ask <prompt> <default> — echoes the answer, or the default when unattended
ask() {
    local reply=""
    if [ -n "$HAVE_TTY" ]; then
        read -r -p "$1" reply </dev/tty || true
    fi
    echo "${reply:-$2}"
}

# --- Verified download --------------------------------------------------------
# Default channel: the latest GitHub release. Its tebian-src.tar.gz is checked
# against the SHA256SUMS published with the same release, and a missing entry
# is a hard failure — never a silent "verified". Both files come from GitHub,
# so this catches corrupted, truncated or mismatched downloads; it cannot
# detect a compromised GitHub account (that would need signed releases).
#
# fetch_tebian <workdir> — prints the path of the extracted source tree
fetch_tebian() {
    local work="$1" tarball="$1/tebian-src.tar.gz" tag expected top

    if [ "$TEBIAN_CHANNEL" = main ]; then
        echo -e "${YELLOW}  ⚠ TEBIAN_CHANNEL=main: installing the development branch, unverified.${NC}" >&2
        curl -fsSL -o "$tarball" "$TEBIAN_GH/archive/refs/heads/main.tar.gz"
    else
        # The /releases/latest redirect names the tag without needing the API
        tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$TEBIAN_GH/releases/latest" |
              sed -n 's|.*/releases/tag/||p')
        if [ -z "$tag" ]; then
            echo -e "${RED}  ✗ Could not find the latest Tebian release (network down?).${NC}" >&2
            return 1
        fi
        echo "  Downloading Tebian $tag..." >&2
        # Both files by tag, so a release published mid-download can't pair
        # one release's tarball with another's checksums
        if ! curl -fsSL -o "$tarball" "$TEBIAN_GH/releases/download/$tag/tebian-src.tar.gz" ||
           ! curl -fsSL -o "$work/SHA256SUMS" "$TEBIAN_GH/releases/download/$tag/SHA256SUMS"; then
            echo -e "${RED}  ✗ Release $tag is missing tebian-src.tar.gz or SHA256SUMS.${NC}" >&2
            echo "    To install the unverified development branch instead:" >&2
            echo "    curl -sL tebian.org/install | TEBIAN_CHANNEL=main bash" >&2
            return 1
        fi
        expected=$(awk '$2 == "tebian-src.tar.gz" || $2 == "*tebian-src.tar.gz" { print $1 }' "$work/SHA256SUMS")
        if [ -z "$expected" ]; then
            echo -e "${RED}  ✗ SHA256SUMS for $tag has no entry for tebian-src.tar.gz — refusing.${NC}" >&2
            return 1
        fi
        if ! echo "$expected  $tarball" | sha256sum -c --quiet - >/dev/null 2>&1; then
            echo -e "${RED}  ✗ Checksum mismatch! The download is corrupted or was tampered with.${NC}" >&2
            echo "    Expected: $expected" >&2
            echo "    Got:      $(sha256sum "$tarball" | awk '{print $1}')" >&2
            return 1
        fi
        echo -e "${GREEN}  ✓ Checksum verified${NC}" >&2
    fi

    mkdir -p "$work/src"
    tar xzf "$tarball" -C "$work/src"
    # Exactly one top-level directory (tebian/ or tebian-main/)
    top=$(find "$work/src" -mindepth 1 -maxdepth 1 -type d)
    if [ "$(printf '%s\n' "$top" | wc -l)" -ne 1 ] || [ ! -f "$top/bootstrap.sh" ] ||
       [ ! -d "$top/scripts" ] || [ ! -f "$top/VERSION" ]; then
        echo -e "${RED}  ✗ The downloaded archive doesn't look like Tebian.${NC}" >&2
        return 1
    fi
    echo "$top"
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Local mode: use the local tebian-os directory
if [[ "$USE_LOCAL" == "yes" ]]; then
    # Auto-detect source directory if not specified
    if [ -z "$LOCAL_SRC" ]; then
        SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -f "$SCRIPT_PATH/bootstrap.sh" ] && [ -d "$SCRIPT_PATH/scripts" ]; then
            LOCAL_SRC="$SCRIPT_PATH"
        elif [ -d "$HOME/tebian-os/scripts" ]; then
            LOCAL_SRC="$HOME/tebian-os"
        else
            echo -e "${RED}  Error: Could not auto-detect tebian-os directory${NC}"
            echo "  Usage: bash install.sh --local /path/to/tebian-os"
            exit 1
        fi
    fi

    LOCAL_SRC="$(cd "$LOCAL_SRC" && pwd)"

    if [ ! -f "$LOCAL_SRC/bootstrap.sh" ] || [ ! -d "$LOCAL_SRC/scripts" ]; then
        echo -e "${RED}  Error: $LOCAL_SRC doesn't look like a tebian-os directory${NC}"
        echo "  Expected: bootstrap.sh and scripts/ in $LOCAL_SRC"
        exit 1
    fi

    echo -e "${GREEN}  Local mode:${NC} $LOCAL_SRC"

    if [ "$LOCAL_SRC" != "$TEBIAN_DIR" ]; then
        if [ -d "$TEBIAN_DIR" ]; then
            echo -e "${YELLOW}  Updating $TEBIAN_DIR from local source...${NC}"
        else
            echo "  Linking local source to $TEBIAN_DIR..."
        fi
        rm -rf "$TEBIAN_DIR"
        ln -sf "$LOCAL_SRC" "$TEBIAN_DIR"
        echo -e "${GREEN}  ✓ Symlinked $TEBIAN_DIR -> $LOCAL_SRC${NC}"
    else
        echo -e "${GREEN}  ✓ Source is already at $TEBIAN_DIR${NC}"
    fi

# Check if Tebian is already installed
elif [ -d "$TEBIAN_DIR" ]; then
    echo -e "${YELLOW}  Tebian directory already exists at $TEBIAN_DIR${NC}"
    echo ""
    confirm=$(ask "  Update and reinstall? [Y/n]: " Y)
    if [[ "$confirm" =~ ^[Nn] ]]; then
        echo "  Cancelled."
        exit 0
    fi
    echo "  Updating existing install..."
    if command -v git &>/dev/null && [ -d "$TEBIAN_DIR/.git" ]; then
        # --ff-only: never merge over local commits; a refusal is reported
        if ! git -C "$TEBIAN_DIR" pull --ff-only; then
            echo -e "${RED}  ✗ git pull failed — resolve it in $TEBIAN_DIR, then re-run.${NC}"
            exit 1
        fi
    elif [ -L "$TEBIAN_DIR" ]; then
        # A --local install links ~/Tebian to a working copy — never pour a
        # release over someone's source tree
        echo -e "${RED}  ✗ $TEBIAN_DIR links to $(readlink -f "$TEBIAN_DIR") (local mode).${NC}"
        echo "    Update that tree yourself, or use: bash install.sh --local"
        exit 1
    else
        # Download and verify completely before touching the existing tree
        NEW=$(fetch_tebian "$WORK")
        # Keep the machine's own manifest; everything else is Tebian's
        if [ -f "$TEBIAN_DIR/tebian.conf" ]; then
            cp -p "$TEBIAN_DIR/tebian.conf" "$WORK/tebian.conf.keep"
        fi
        cp -a "$NEW/." "$TEBIAN_DIR/"
        if [ -f "$WORK/tebian.conf.keep" ]; then
            cp -p "$WORK/tebian.conf.keep" "$TEBIAN_DIR/tebian.conf"
        fi
        echo -e "${GREEN}  ✓ Updated to $(cat "$TEBIAN_DIR/VERSION")${NC}"
    fi
else
    if [[ "$USE_GIT" == "yes" ]]; then
        # Fleet mode: use git clone for ongoing sync
        echo -e "${YELLOW}  Fleet mode: $TEBIAN_REPO${NC}"
        if ! command -v git &>/dev/null; then
            echo "  Installing git..."
            sudo apt update -qq && sudo apt install -y -qq git
        fi
        echo "  Cloning config repo..."
        git clone --depth 1 "$TEBIAN_REPO" "$TEBIAN_DIR"
    else
        NEW=$(fetch_tebian "$WORK")
        mv "$NEW" "$TEBIAN_DIR"
        echo -e "${GREEN}  ✓ Tebian $(cat "$TEBIAN_DIR/VERSION") downloaded to $TEBIAN_DIR${NC}"
    fi
fi

# Run bootstrap — on the terminal, not the exhausted curl pipe.
# exec skips the EXIT trap, so clean up the download dir first.
rm -rf "$WORK"
trap - EXIT
echo ""
if [ -n "$HAVE_TTY" ]; then
    exec bash "$TEBIAN_DIR/bootstrap.sh" </dev/tty
else
    exec bash "$TEBIAN_DIR/bootstrap.sh" </dev/null
fi
