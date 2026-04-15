#!/bin/bash
# ==============================================================================
# TEBIAN ISO BUILDER
# Builds bootable x86_64 PC live ISO using Debian live-build
# The live session boots to a whiptail installer (tebian-installer)
# Requires: sudo apt install live-build
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

DEBIAN_VERSION="${1:-trixie}"
OUTPUT_DIR="$(pwd)"

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

# Install build dependencies
echo -e "${YELLOW}Installing build dependencies...${NC}"
sudo apt update
sudo apt install -y live-build

# Build in Linux-native FS by default (WSL /mnt/* mounts are often nodev/noexec and break debootstrap).
BUILD_DIR="${TEBIAN_BUILD_DIR:-/tmp/tebian-build-amd64}"
ISO_NAME="tebian-$(date +%Y%m%d).iso"

# Clean old build (needs sudo — lb build creates root-owned files)
sudo rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Initialize live-build
lb config \
    --architecture amd64 \
    --distribution "$DEBIAN_VERSION" \
    --binary-images iso-hybrid \
    --bootloaders "grub-pc,grub-efi" \
    --bootappend-live "boot=live components toram quiet splash loglevel=0 vt.global_cursor_default=0 cfg80211.ieee80211_regdom=00" \
    --debian-installer none \
    --mode debian \
    --apt-recommends false \
    --archive-areas "main contrib non-free non-free-firmware" \
    --parent-mirror-bootstrap http://deb.debian.org/debian \
    --parent-mirror-binary http://deb.debian.org/debian \
    --mirror-bootstrap http://deb.debian.org/debian \
    --mirror-binary http://deb.debian.org/debian

# ── Bootloader branding ──
if [ -d "$TEBIAN_SRC/config/bootloaders" ]; then
    cp -r "$TEBIAN_SRC/config/bootloaders" config/
    find config/bootloaders -type f -name '._*' -delete

    # Keep UEFI and BIOS menus in sync; UEFI falls back to plain text without grub-efi assets.
    if [ -d "config/bootloaders/grub-pc" ] && [ ! -d "config/bootloaders/grub-efi" ]; then
        mkdir -p "config/bootloaders/grub-efi"
        cp -r config/bootloaders/grub-pc/* config/bootloaders/grub-efi/
    fi

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
EOF

# ── Copy Tebian repo into live filesystem ──
mkdir -p config/includes.chroot/home/user/Tebian
rsync -a --exclude='node_modules' --exclude='dist' --exclude='.astro' --exclude='.git' "$TEBIAN_SRC/" config/includes.chroot/home/user/Tebian/

# Install tebian-installer system-wide
mkdir -p config/includes.chroot/usr/local/bin
cp "$TEBIAN_SRC/scripts/tebian-installer" config/includes.chroot/usr/local/bin/tebian-installer
chmod +x config/includes.chroot/usr/local/bin/tebian-installer

# Also copy bootstrap and session for the installed system
cp "$TEBIAN_SRC/bootstrap.sh" config/includes.chroot/usr/local/bin/tebian-bootstrap
chmod +x config/includes.chroot/usr/local/bin/tebian-bootstrap

cp "$TEBIAN_SRC/scripts/tebian-session" config/includes.chroot/usr/local/bin/tebian-session
chmod +x config/includes.chroot/usr/local/bin/tebian-session

# System wallpaper
mkdir -p config/includes.chroot/usr/share/backgrounds/tebian
cp "$TEBIAN_SRC/assets/wallpapers/glass.jpg" config/includes.chroot/usr/share/backgrounds/tebian/default.jpg

# Plymouth theme for live session
mkdir -p config/includes.chroot/usr/share/plymouth/themes/tebian
cp "$TEBIAN_SRC/assets/plymouth/tebian/tebian.plymouth" config/includes.chroot/usr/share/plymouth/themes/tebian/
cp "$TEBIAN_SRC/assets/plymouth/tebian/tebian.script" config/includes.chroot/usr/share/plymouth/themes/tebian/

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
        sudo mount --bind /dev chroot/dev
        sudo mount --bind /dev/pts chroot/dev/pts 2>/dev/null || true
    fi
}

cleanup_chroot_dev() {
    sudo umount chroot/dev/pts 2>/dev/null || true
    sudo umount chroot/dev 2>/dev/null || true
}

# Split lb build into stages so we can fix /dev between bootstrap/chroot/binary
sudo lb bootstrap
fix_chroot_dev
trap cleanup_chroot_dev EXIT
sudo lb chroot

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
cat > config/includes.binary/boot/grub/loopback.cfg << LOOPEOF
# Ventoy/loopback boot support — \$iso_path is set by Ventoy/GRUB loopback
menuentry "Tebian OS" {
    set gfxpayload=keep
    linux /live/vmlinuz-${KVER} boot=live components toram quiet splash cfg80211.ieee80211_regdom=00 findiso=\$iso_path
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
sudo lb binary

shopt -s nullglob
isos=(live-image-*.iso *.hybrid.iso live-image-*.hybrid.iso)
shopt -u nullglob

if [ "${#isos[@]}" -gt 0 ]; then
    mv "${isos[0]}" "$OUTPUT_DIR/$ISO_NAME"
    SIZE=$(du -h "$OUTPUT_DIR/$ISO_NAME" | awk '{print $1}')
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Created: $ISO_NAME ($SIZE)${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "  Output: $OUTPUT_DIR/$ISO_NAME"
    echo ""
    echo "  Test in QEMU:"
    echo "    qemu-img create -f qcow2 tebian-test.qcow2 20G"
    echo "    qemu-system-x86_64 -m 2048 -enable-kvm -cdrom $OUTPUT_DIR/$ISO_NAME -hda tebian-test.qcow2"
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
