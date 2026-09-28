#!/bin/bash
# ==============================================================================
# TEBIAN ISO BUILDER
# Builds bootable x86_64 PC live ISO using Debian live-build
# The live session boots to a whiptail installer (tebian-installer)
# Requires: a Debian host (or ~/build.sh, which runs this in a container).
# Runs as root or as a user with sudo; missing build tools are installed.
#
# Usage: build-iso.sh [debian-version] [--release]
#   --release  Build from committed git state only (git archive HEAD).
#              Untracked files and uncommitted edits will NOT ship.
#              Use this for distribution ISOs; plain mode for dev iteration.
#
# Environment:
#   TEBIAN_OUTPUT_DIR  where the ISO and its .sha256 land (default: current dir)
#   TEBIAN_ISO_NAME    output file name (default: tebian-YYYYMMDD.iso) — the
#                      container wrapper passes this so the host and the
#                      container (which runs on UTC) agree on the date
#   TEBIAN_BUILD_DIR   scratch build tree (default: /tmp/tebian-build-amd64)
#
# For ARM boards (Pi, Armbian, etc.), use the remote installer instead:
#   curl -sL tebian.org/install | bash
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEBIAN_VERSION="trixie"
RELEASE_BUILD=""
EXPORT_DIR=""
for arg in "$@"; do
    case "$arg" in
        --release) RELEASE_BUILD="yes" ;;
        *) DEBIAN_VERSION="$arg" ;;
    esac
done
OUTPUT_DIR="${TEBIAN_OUTPUT_DIR:-$(pwd)}"
ISO_NAME="${TEBIAN_ISO_NAME:-tebian-$(date +%Y%m%d).iso}"

# Root in a container has no sudo installed and doesn't need it
SUDO=""
[ "$EUID" -ne 0 ] && SUDO="sudo"

# Run a live-build stage as root. sudo resets the environment, so pass
# SOURCE_DATE_EPOCH through explicitly or release builds would silently
# lose their fixed timestamp on host builds.
lb_run() {
    $SUDO env ${SOURCE_DATE_EPOCH:+SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH"} lb "$@"
}

# Auto-detect Tebian source directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../bootstrap.sh" ]; then
    TEBIAN_SRC="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -d "tebian-os" ]; then
    TEBIAN_SRC="$(cd tebian-os && pwd)"
elif [ -d "Tebian" ]; then
    TEBIAN_SRC="$(cd Tebian && pwd)"
else
    echo -e "${RED}Error: No 'tebian-os' or 'Tebian' directory found${NC}"
    echo "  Run this from the parent directory, or directly: bash tebian-os/scripts/build-iso.sh"
    exit 1
fi

# Verify we're on a Debian system
if [ ! -f /etc/debian_version ]; then
    echo -e "${RED}Error: This script must run on a Debian/Ubuntu system${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Building Tebian x86_64 ISO${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Install build dependencies — only what's missing, so container builds
# (image already has them) don't hit the network for apt on every run
missing=()
command -v lb >/dev/null || missing+=(live-build)
command -v rsync >/dev/null || missing+=(rsync)
[ -n "$RELEASE_BUILD" ] && ! command -v git >/dev/null && missing+=(git)
if [ "${#missing[@]}" -gt 0 ]; then
    echo -e "${YELLOW}Installing build dependencies: ${missing[*]}${NC}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${missing[@]}"
fi

# Build in Linux-native FS by default (WSL /mnt/* mounts are often nodev/noexec and break debootstrap).
BUILD_DIR="${TEBIAN_BUILD_DIR:-/tmp/tebian-build-amd64}"

# Set before anything that can fail partway: a failed bootstrap or chroot
# stage must still unmount the /dev bind mounts and drop the release export
cleanup() {
    $SUDO umount "$BUILD_DIR/chroot/dev/pts" 2>/dev/null || true
    $SUDO umount "$BUILD_DIR/chroot/dev" 2>/dev/null || true
    [ -n "$EXPORT_DIR" ] && rm -rf "$EXPORT_DIR"
    return 0
}
trap cleanup EXIT

TEBIAN_VERSION="$(cat "$TEBIAN_SRC/VERSION" 2>/dev/null || echo 0.0.0)"
RELEASE_ID="dev-$(date +%Y%m%d)"

# ── Release mode: export committed tree and build only from that ──
# git archive HEAD excludes .git, untracked files, and uncommitted edits,
# so a release ISO is reproducible from a commit hash.
if [ -n "$RELEASE_BUILD" ]; then
    # Container/CI builds run as root on a host-owned mount — git refuses
    # to read the repo without this
    git config --global --add safe.directory "$TEBIAN_SRC" 2>/dev/null || true

    if ! git -C "$TEBIAN_SRC" rev-parse HEAD >/dev/null 2>&1; then
        echo -e "${RED}Error: --release requires $TEBIAN_SRC to be a git repository with at least one commit${NC}"
        exit 1
    fi

    COMMIT=$(git -C "$TEBIAN_SRC" rev-parse --short HEAD)
    RELEASE_ID="$COMMIT"
    # Reproducible-builds convention, honoured by live-build: every
    # timestamp in the image comes from the commit, not the build clock
    export SOURCE_DATE_EPOCH="$(git -C "$TEBIAN_SRC" log -1 --format=%ct HEAD)"
    if [ -n "$(git -C "$TEBIAN_SRC" status --porcelain 2>/dev/null)" ]; then
        echo -e "${YELLOW}Warning: uncommitted changes in $TEBIAN_SRC will NOT be included in the ISO${NC}"
        git -C "$TEBIAN_SRC" status --short | head -20
    fi

    EXPORT_DIR=$(mktemp -d /tmp/tebian-release-XXXXXX)
    git -C "$TEBIAN_SRC" archive HEAD | tar -x -C "$EXPORT_DIR"
    TEBIAN_SRC="$EXPORT_DIR"
    TEBIAN_VERSION="$(cat "$TEBIAN_SRC/VERSION" 2>/dev/null || echo 0.0.0)"
    echo -e "${GREEN}[release]${NC} Building from commit $COMMIT (clean git export)"
fi

# Clean old build (needs root — lb build creates root-owned files)
$SUDO rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Initialize live-build
lb config \
    --architecture amd64 \
    --distribution "$DEBIAN_VERSION" \
    --binary-images iso-hybrid \
    --bootloaders "grub-pc,grub-efi" \
    --bootappend-live "boot=live components toram quiet splash loglevel=0 vt.global_cursor_default=0 cfg80211.ieee80211_regdom=00" \
    --iso-volume "TEBIAN_${TEBIAN_VERSION//./_}" \
    --iso-application "Tebian OS ${TEBIAN_VERSION}" \
    --iso-publisher "Tebian OS; https://tebian.org" \
    --debian-installer none \
    --mode debian \
    --apt-recommends false \
    --archive-areas "main contrib non-free non-free-firmware" \
    --parent-mirror-bootstrap http://deb.debian.org/debian \
    --parent-mirror-binary http://deb.debian.org/debian \
    --mirror-bootstrap http://deb.debian.org/debian \
    --mirror-binary http://deb.debian.org/debian

# ── Bootloader branding ──
# live-build reads only config/bootloaders/grub-pc and installs it as
# /boot/grub for BIOS and UEFI alike — the UEFI image just loads that same
# grub.cfg — so a single directory serves both.
if [ -d "$TEBIAN_SRC/config/bootloaders" ]; then
    cp -r "$TEBIAN_SRC/config/bootloaders" config/
    find config/bootloaders -type f -name '._*' -delete
    echo -e "${GREEN}[iso]${NC} Custom boot theme applied"
fi

# ── Package lists ──
mkdir -p config/package-lists

cat > config/package-lists/live.list.chroot << 'EOF'
# Live boot (required — mounts squashfs as root)
live-boot
live-boot-initramfs-tools
live-config
live-config-systemd

# Live session packages (for running the installer)
linux-image-amd64
firmware-linux-nonfree
firmware-iwlwifi
firmware-realtek
firmware-atheros
firmware-bnx2
firmware-bnx2x
firmware-brcm80211
firmware-libertas
firmware-misc-nonfree
firmware-zd1211
firmware-mediatek
firmware-amd-graphics
firmware-sof-signed
rfkill
wireless-tools
wireless-regdb
iw
wpasupplicant
isc-dhcp-client
systemd-sysv
sudo
curl
bash-completion
nano
git

# Installer dependencies
parted
gdisk
dosfstools
e2fsprogs
cryptsetup
debootstrap
ntfs-3g
os-prober
grub-efi-amd64-bin
grub-pc-bin
efibootmgr
rsync
whiptail

# Network (needed to debootstrap from live session)
network-manager

# Clean boot splash
plymouth
plymouth-themes

# Console keyboard layouts. kbd alone ships no keymaps; console-setup's
# ckbcomp compiles the same XKB layout names the installed system uses,
# so the live console can match the layout picked in the installer.
kbd
console-setup
keyboard-configuration
EOF

# ── Copy Tebian repo into live filesystem ──
# The .gitignore filter keeps dev builds from shipping anything git would
# never track (VM disks, site build output, caches); the explicit excludes
# cover dev-only files that are tracked elsewhere or never belong in an ISO.
mkdir -p config/includes.chroot/home/user/Tebian
rsync -a --filter=':- .gitignore' \
    --exclude='.git' --exclude='.vm' --exclude='tebian-site' --exclude='node_modules' \
    --exclude='dist' --exclude='.astro' --exclude='__pycache__' --exclude='*.pyc' \
    --exclude='.DS_Store' --exclude='._*' --exclude='*.iso' --exclude='*.qcow2' \
    --exclude='CLAUDE.md' --exclude='.claude' --exclude='MEMORY.md' \
    "$TEBIAN_SRC/" config/includes.chroot/home/user/Tebian/

# Install tebian-installer system-wide
mkdir -p config/includes.chroot/usr/local/bin
cp "$TEBIAN_SRC/scripts/tebian-installer" config/includes.chroot/usr/local/bin/tebian-installer
chmod +x config/includes.chroot/usr/local/bin/tebian-installer

# Also copy bootstrap and session for the installed system
cp "$TEBIAN_SRC/bootstrap.sh" config/includes.chroot/usr/local/bin/tebian-bootstrap
chmod +x config/includes.chroot/usr/local/bin/tebian-bootstrap

cp "$TEBIAN_SRC/scripts/tebian-session" config/includes.chroot/usr/local/bin/tebian-session
chmod +x config/includes.chroot/usr/local/bin/tebian-session

# Which build this is: `cat /etc/tebian-release` on a live session or in a
# bug report ties it back to a commit (release) or a build date (dev)
mkdir -p config/includes.chroot/etc
cat > config/includes.chroot/etc/tebian-release << RELEOF
TEBIAN_VERSION=$TEBIAN_VERSION
TEBIAN_BUILD=$RELEASE_ID
RELEOF

# System wallpaper
mkdir -p config/includes.chroot/usr/share/backgrounds/tebian
cp "$TEBIAN_SRC/assets/wallpapers/glass.jpg" config/includes.chroot/usr/share/backgrounds/tebian/default.jpg

# Plymouth theme for live session
mkdir -p config/includes.chroot/usr/share/plymouth/themes/tebian
cp "$TEBIAN_SRC/assets/plymouth/tebian/tebian.plymouth" config/includes.chroot/usr/share/plymouth/themes/tebian/
cp "$TEBIAN_SRC/assets/plymouth/tebian/tebian.script" config/includes.chroot/usr/share/plymouth/themes/tebian/

# Font rendering for the live session — same sharp defaults the installer
# seeds for installed users (RGB subpixel + medium hinting). Numbered 40 so
# it overrides Debian's 10-* defaults but still loses to 50-user, keeping
# any per-user toggle authoritative. trixie's fonts.conf does not read
# /etc/fonts/local.conf, so a conf.d drop-in is the only system-wide hook.
mkdir -p config/includes.chroot/etc/fonts/conf.d
cat > config/includes.chroot/etc/fonts/conf.d/40-tebian-font-rendering.conf << 'FONTEOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintmedium</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>
</fontconfig>
FONTEOF

# ── Hooks (chroot hooks go in config/hooks/normal/) ──
mkdir -p config/hooks/normal

# Create live user and configure auto-login
cat > config/hooks/normal/0100-tebian-live.hook.chroot << 'HOOKEOF'
#!/bin/bash
# Create the live user
useradd -m -s /bin/bash user
echo "user:user" | chpasswd
usermod -aG sudo user
chown -R user:user /home/user/Tebian

# Passwordless sudo for live session (installer needs root)
echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/live-user
chmod 440 /etc/sudoers.d/live-user

# Auto-login on tty1 via systemd override
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'GETTY'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin user --noclear %I $TERM
GETTY

# Enable NetworkManager (used by installed system; installer uses wpa_supplicant directly)
systemctl enable NetworkManager 2>/dev/null || true

# Default regulatory domain (world) — needed for Intel LAR WiFi chips
mkdir -p /etc/default
echo 'REGDOMAIN=00' > /etc/default/crda

# Set Tebian Plymouth theme
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme tebian 2>/dev/null
fi

# Auto-launch installer on login
cat >> /home/user/.bash_profile << 'PROFILE'
# Tebian Live Session — launch installer directly
sudo tebian-installer
PROFILE
chown user:user /home/user/.bash_profile
HOOKEOF
chmod +x config/hooks/normal/0100-tebian-live.hook.chroot

# ── Build ──
echo ""
echo -e "${YELLOW}Building ISO (this takes 10-20 minutes)...${NC}"

# Fix: bind-mount /dev into the chroot so /dev/null (and other device nodes)
# actually work. Static mknod nodes created by debootstrap don't function in
# containers / certain namespace setups, causing postinst scripts to fail with
# "cannot create /dev/null: Permission denied".
fix_chroot_dev() {
    if [ -d chroot/dev ] && ! mountpoint -q chroot/dev; then
        echo -e "${YELLOW}Bind-mounting /dev into chroot...${NC}"
        $SUDO mount --bind /dev chroot/dev
        $SUDO mount --bind /dev/pts chroot/dev/pts 2>/dev/null || true
    fi
}

# Split lb build into stages so we can fix /dev between bootstrap/chroot/binary
lb_run bootstrap
fix_chroot_dev
lb_run chroot

# Resolve kernel version and patch grub.cfg before binary stage
KVER=$(ls chroot/boot/vmlinuz-* 2>/dev/null | head -1 | sed 's|.*/vmlinuz-||')
if [ -n "$KVER" ]; then
    echo -e "${GREEN}[iso]${NC} Kernel version: $KVER"
    find config/bootloaders -name 'grub.cfg' -o -name 'loopback.cfg' | xargs sed -i "s/@@KERNEL_VERSION@@/$KVER/g"
else
    echo -e "${YELLOW}[iso]${NC} Warning: could not detect kernel version for grub.cfg"
fi

# Create includes.binary to override loopback.cfg with Ventoy-compatible version
mkdir -p config/includes.binary/boot/grub
# Entries mirror config/bootloaders/grub-pc/grub.cfg — keep the two in step
cat > config/includes.binary/boot/grub/loopback.cfg << LOOPEOF
# Ventoy/loopback boot support — \$iso_path is set by Ventoy/GRUB loopback
menuentry "Tebian OS" {
    set gfxpayload=keep
    linux /live/vmlinuz-${KVER} boot=live components toram quiet splash cfg80211.ieee80211_regdom=00 findiso=\$iso_path
    initrd /live/initrd.img-${KVER}
}
menuentry "Tebian OS (low memory — run from USB)" {
    set gfxpayload=keep
    linux /live/vmlinuz-${KVER} boot=live components quiet splash cfg80211.ieee80211_regdom=00 findiso=\$iso_path
    initrd /live/initrd.img-${KVER}
}
menuentry "Tebian OS (safe graphics)" {
    set gfxpayload=keep
    linux /live/vmlinuz-${KVER} boot=live components toram nomodeset cfg80211.ieee80211_regdom=00 findiso=\$iso_path
    initrd /live/initrd.img-${KVER}
}
LOOPEOF

# lb chroot unmounts /dev when it finishes — re-mount for binary stage
fix_chroot_dev
lb_run binary

shopt -s nullglob
isos=(live-image-*.iso *.hybrid.iso live-image-*.hybrid.iso)
shopt -u nullglob

if [ "${#isos[@]}" -gt 0 ]; then
    mkdir -p "$OUTPUT_DIR"
    mv "${isos[0]}" "$OUTPUT_DIR/$ISO_NAME"
    # Relative name inside the file, so `sha256sum -c` works from the ISO's folder
    (cd "$OUTPUT_DIR" && sha256sum "$ISO_NAME" > "$ISO_NAME.sha256")
    # Run via `sudo build-iso.sh`: hand both files back to the invoking user
    if [ -n "${SUDO_UID:-}" ]; then
        chown "$SUDO_UID:$SUDO_GID" "$OUTPUT_DIR/$ISO_NAME" "$OUTPUT_DIR/$ISO_NAME.sha256" 2>/dev/null || true
    fi
    SIZE=$(du -h "$OUTPUT_DIR/$ISO_NAME" | awk '{print $1}')
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Created: $ISO_NAME ($SIZE)${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "  Output:  $OUTPUT_DIR/$ISO_NAME"
    echo "  SHA256:  $(cut -d' ' -f1 "$OUTPUT_DIR/$ISO_NAME.sha256")"
    echo "  Build:   $TEBIAN_VERSION ($RELEASE_ID)"
    echo ""
    echo "  Test in QEMU:"
    echo "    bash tebian-os/scripts/test-vm.sh --boot-only   (UEFI; --bios / --secureboot also available)"
    echo ""
    echo "  Flash to USB:"
    echo "    dd if=$OUTPUT_DIR/$ISO_NAME of=/dev/sdX bs=4M status=progress && sync"
    echo ""
    echo "  Boot → auto-login → installer menu"
else
    echo -e "${RED}Build failed — no ISO found in $BUILD_DIR${NC}"
    echo "  Check build logs above for errors."
    exit 1
fi
