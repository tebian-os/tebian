#!/bin/bash
# ==============================================================================
# TEBIAN ISO BUILD (Podman)
# Runs scripts/build-iso.sh inside a clean debian:trixie container,
# so the build never touches this machine's packages or /tmp. Works on Linux
# natively and on macOS through a Podman machine (x86_64 emulation — slow).
#
# Usage: build/build.sh [--release]
#   --release  Build from committed git state only (passed to build-iso.sh)
# Output: tebian-YYYYMMDD.iso + .sha256 in the folder that contains the repo
#         (where test-vm.sh looks), or in TEBIAN_OUTPUT_DIR if set
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd -P "$SCRIPT_DIR/.." && pwd)"
# Named here, on the host, and passed in: the container runs on UTC, so an
# evening build would otherwise be named for tomorrow and look like a failure
ISO_NAME="tebian-$(date +%Y%m%d).iso"
OUTPUT_DIR="${TEBIAN_OUTPUT_DIR:-$(dirname "$REPO_DIR")}"

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Tebian ISO Builder (Podman)${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

if ! command -v podman >/dev/null; then
    echo -e "${RED}podman is not installed${NC} (Debian: sudo apt install podman)"
    exit 1
fi

# macOS runs containers in a VM that may be stopped; Linux has no machine
if ! podman info >/dev/null 2>&1; then
    if [ "$(uname -s)" = Darwin ]; then
        echo -e "${YELLOW}Starting Podman machine...${NC}"
        podman machine start
    else
        echo -e "${RED}podman is not working${NC} — check 'podman info'"
        exit 1
    fi
fi

# A previous ISO from the same day would mask a failed build
if [ -e "$OUTPUT_DIR/$ISO_NAME" ]; then
    echo -e "${YELLOW}Replacing existing $ISO_NAME${NC}"
    rm -f "$OUTPUT_DIR/$ISO_NAME" "$OUTPUT_DIR/$ISO_NAME.sha256"
fi

echo -e "${YELLOW}Building container image...${NC}"
podman build --platform linux/amd64 -t tebian-builder -f "$SCRIPT_DIR/Containerfile" "$SCRIPT_DIR"

echo ""
if [ "$(uname -m)" = x86_64 ]; then
    echo -e "${YELLOW}Building ISO inside container (10-20 min)...${NC}"
else
    echo -e "${YELLOW}Building ISO inside container (x86_64 emulation — expect 30-60 min)...${NC}"
fi
echo ""

# --privileged: live-build needs loop devices, mounts and chroot.
# The output mount is a dedicated subfolder, not $HOME itself — the
# container only ever sees the source tree and one empty-ish folder.
BUILD_OUT="$OUTPUT_DIR/.tebian-build-out"
mkdir -p "$BUILD_OUT"
# Checked explicitly: under set -e a failing build would otherwise exit
# here silently, without the "Build failed" message below
if ! podman run --rm --platform linux/amd64 --privileged \
    -v "$REPO_DIR:/build/tebian-os:Z" \
    -v "$BUILD_OUT:/build/output:Z" \
    -e TEBIAN_OUTPUT_DIR=/build/output \
    -e TEBIAN_ISO_NAME="$ISO_NAME" \
    tebian-builder \
    bash /build/tebian-os/scripts/build-iso.sh "$@"; then
    echo -e "${RED}Build failed inside the container — check output above${NC}"
    exit 1
fi

if [ -f "$BUILD_OUT/$ISO_NAME" ]; then
    mv -f "$BUILD_OUT/$ISO_NAME" "$BUILD_OUT/$ISO_NAME.sha256" "$OUTPUT_DIR/"
    rmdir "$BUILD_OUT" 2>/dev/null || true
    SIZE=$(du -h "$OUTPUT_DIR/$ISO_NAME" | awk '{print $1}')
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Created: $OUTPUT_DIR/$ISO_NAME ($SIZE)${NC}"
    echo -e "${GREEN}  SHA256:  $(cut -d' ' -f1 "$OUTPUT_DIR/$ISO_NAME.sha256")${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "  Test:  bash $REPO_DIR/scripts/test-vm.sh --boot-only"
    echo "  Flash: sudo dd if=$ISO_NAME of=/dev/sdX bs=4M status=progress oflag=sync"
    echo "         (or Ventoy / Rufus in DD mode / balenaEtcher)"
else
    echo -e "${RED}Build failed — no $ISO_NAME produced, check output above${NC}"
    exit 1
fi
