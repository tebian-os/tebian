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

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEBIAN_VERSION="${1:-trixie}"

# Check we're in the right directory
if [ ! -d "Tebian" ]; then
    echo -e "${RED}Error: Run this from the Tebian parent directory${NC}"
    echo "  cd ~ && bash Tebian/scripts/build-iso.sh"
    exit 1
fi

TEBIAN_SRC="$(pwd)/Tebian"

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Building Tebian x86_64 ISO${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Install build dependencies
echo -e "${YELLOW}Installing build dependencies...${NC}"
sudo apt update
sudo apt install -y live-build

BUILD_DIR="tebian-build-amd64"
ISO_NAME="tebian-$(date +%Y%m%d).iso"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Initialize live-build (no debian-installer — we use our own)
lb config \
    --architecture amd64 \
    --distribution "$DEBIAN_VERSION" \
    --binary-images iso-hybrid \
    --bootloaders "grub-efi,syslinux" \
    --bootappend-live "boot=live components quiet splash" \
    --debian-installer none \
    --mode debian \
    --archive-areas "main contrib non-free non-free-firmware" \
    --parent-mirror-bootstrap http://deb.debian.org/debian \
    --parent-mirror-binary http://deb.debian.org/debian \
    --mirror-bootstrap http://deb.debian.org/debian \
    --mirror-binary http://deb.debian.org/debian

# ── Package lists ──
mkdir -p config/package-lists

cat > config/package-lists/live.list.chroot << 'EOF'
# Live boot (required — mounts squashfs as root)
live-boot
live-boot-initramfs-tools

# Live session packages (for running the installer)
linux-image-amd64
firmware-linux
firmware-iwlwifi
firmware-misc-nonfree
sudo
curl
bash-completion
nano
git

# Installer dependencies
parted
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
EOF

# ── Copy Tebian repo into live filesystem ──
mkdir -p config/includes.chroot/home/user/Tebian
rsync -a --exclude='node_modules' --exclude='dist' --exclude='.astro' "$TEBIAN_SRC/" config/includes.chroot/home/user/Tebian/

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

# ── Hooks ──
mkdir -p config/hooks/live

# Create live user
cat > config/hooks/live/0100-tebian-user.hook.chroot << 'EOF'
#!/bin/bash
useradd -m -s /bin/bash user
echo "user:user" | chpasswd
usermod -aG sudo user
chown -R user:user /home/user/Tebian
EOF
chmod +x config/hooks/live/0100-tebian-user.hook.chroot

# Passwordless sudo for live session (installer needs root)
cat > config/hooks/live/0110-live-sudo.hook.chroot << 'EOF'
#!/bin/bash
echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/live-user
chmod 440 /etc/sudoers.d/live-user
EOF
chmod +x config/hooks/live/0110-live-sudo.hook.chroot

# Auto-launch installer on live boot login
cat > config/hooks/live/0200-autostart.hook.chroot << 'EOF'
#!/bin/bash
cat >> /home/user/.bash_profile << 'PROFILE'
# Tebian Live Session
clear
echo ""
echo "  ┌───────────────────────────────┐"
echo "  │       T E B I A N             │"
echo "  │                               │"
echo "  │  [1] Install Tebian           │"
echo "  │  [2] Shell (try before install)│"
echo "  │                               │"
echo "  └───────────────────────────────┘"
echo ""
read -p "  Select [1/2]: " choice
case "$choice" in
    1) sudo tebian-installer ;;
    2) echo ""; echo "  Type 'sudo tebian-installer' to install later."; echo "" ;;
    *) echo ""; echo "  Type 'sudo tebian-installer' to install later."; echo "" ;;
esac
PROFILE
chown user:user /home/user/.bash_profile
EOF
chmod +x config/hooks/live/0200-autostart.hook.chroot

# ── Build ──
echo ""
echo -e "${YELLOW}Building ISO (this takes 10-20 minutes)...${NC}"
sudo lb build

if [ -f live-image-*.iso ]; then
    mv live-image-*.iso "../$ISO_NAME"
    cd ..
    SIZE=$(du -h "$ISO_NAME" | awk '{print $1}')
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Created: $ISO_NAME ($SIZE)${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "  Test:  qemu-system-x86_64 -m 2048 -enable-kvm -cdrom $ISO_NAME"
    echo "  Flash: dd if=$ISO_NAME of=/dev/sdX bs=4M status=progress && sync"
    echo ""
    echo "  Boot → auto-login → installer menu"
else
    cd ..
    echo -e "${RED}Build failed${NC}"
    exit 1
fi
