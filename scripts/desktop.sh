#!/bin/bash
# ==============================================================================
# TEBIAN BASE INSTALLER (V3.0)
# Installs minimal GUI: Sway, fuzzel, kitty, NM, pipewire, greetd
# Desktop extras are installed by tebian-onboard if user picks "Desktop"
# ==============================================================================

set -euo pipefail

TEBIAN_DIR="${TEBIAN_DIR:-$HOME/Tebian}"
CONFIG_DIR="$HOME/.config"
LOCAL_BIN="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Platform detection
ARCH=$(uname -m)
IS_PI=false
if [ -f /sys/firmware/devicetree/base/model ] && grep -qi "raspberry" /sys/firmware/devicetree/base/model 2>/dev/null; then
    IS_PI=true
fi

# Check if running on Debian/Ubuntu
if [ ! -f /etc/debian_version ]; then
    log_error "Tebian requires Debian or a Debian-based distro"
    exit 1
fi

log_info "Installing packages..."

if ! sudo apt update; then
    log_error "Failed to update package lists"
    exit 1
fi

# Base packages — minimum needed to boot sway + show onboard fuzzel menu
# Desktop extras (pcmanfm, mako, grim, bluetooth, etc.) are installed by
# tebian-onboard if the user picks "Desktop (Familiar)"
PACKAGES=(
    sway swaybg
    fuzzel
    kitty
    pipewire wireplumber pipewire-pulse
    fonts-noto fonts-jetbrains-mono
    network-manager
    curl
    greetd nwg-hello libnotify-bin
)

# Optional packages (don't fail if missing)
OPTIONAL_PACKAGES=()

if ! sudo apt install -y "${PACKAGES[@]}"; then
    log_error "Failed to install packages"
    exit 1
fi

# Optional packages — try but don't fail
for pkg in "${OPTIONAL_PACKAGES[@]}"; do
    sudo apt install -y "$pkg" 2>/dev/null || log_info "Optional package '$pkg' not available, skipping"
done

# Platform-specific hardware setup
if [[ "$IS_PI" == true ]]; then
    log_info "Applying Raspberry Pi hardware optimizations..."
    if [ -f "$TEBIAN_DIR/modules/hw/pi.sh" ]; then
        bash "$TEBIAN_DIR/modules/hw/pi.sh"
    fi
elif [[ "$ARCH" == "x86_64" ]]; then
    log_info "Applying x86 hardware optimizations..."
    if [ -f "$TEBIAN_DIR/modules/hw/x86.sh" ]; then
        bash "$TEBIAN_DIR/modules/hw/x86.sh"
    fi
fi

log_info "Installing JetBrainsMono Nerd Font..."

FONT_DIR="$HOME/.local/share/fonts"
if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
    mkdir -p "$FONT_DIR"
    NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
    if curl -fsSL "$NERD_URL" -o /tmp/JetBrainsMono.tar.xz; then
        tar -xf /tmp/JetBrainsMono.tar.xz -C "$FONT_DIR"
        fc-cache -f "$FONT_DIR"
        rm -f /tmp/JetBrainsMono.tar.xz
        log_info "Nerd Font installed"
    else
        log_error "Failed to download Nerd Font (icons may not display correctly)"
    fi
else
    log_info "Nerd Font already installed"
fi

log_info "Creating directory structure..."

mkdir -p "$LOCAL_BIN"
mkdir -p "$HOME/.local/share/backgrounds/tebian"
mkdir -p "$HOME/Pictures/Screenshots"
mkdir -p "$HOME/Downloads"
mkdir -p "$HOME/Applications"
mkdir -p "$HOME/Games"
mkdir -p "$HOME/Workspace"
mkdir -p "$HOME/Archive"

log_info "Setting up configs..."

mkdir -p "$CONFIG_DIR"

# Sway
mkdir -p "$CONFIG_DIR/sway"
if [ ! -f "$TEBIAN_DIR/configs/sway/config" ]; then
    log_error "Sway config not found at $TEBIAN_DIR/configs/sway/config"
    exit 1
fi
cp "$TEBIAN_DIR/configs/sway/config" "$CONFIG_DIR/sway/config"

if [ ! -f "$TEBIAN_DIR/configs/themes/glass/sway-theme" ]; then
    log_error "Glass theme not found"
    exit 1
fi
cp "$TEBIAN_DIR/configs/themes/glass/sway-theme" "$CONFIG_DIR/sway/theme"

# config.user - preserve if exists
if [ ! -f "$CONFIG_DIR/sway/config.user" ]; then
    if [ -f "$TEBIAN_DIR/configs/sway/config.user" ]; then
        cp "$TEBIAN_DIR/configs/sway/config.user" "$CONFIG_DIR/sway/config.user"
    else
        touch "$CONFIG_DIR/sway/config.user"
    fi
fi

# Kitty
mkdir -p "$CONFIG_DIR/kitty"
cp "$TEBIAN_DIR/configs/themes/glass/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"

# Fuzzel
mkdir -p "$CONFIG_DIR/fuzzel"
cp "$TEBIAN_DIR/configs/themes/glass/fuzzel.ini" "$CONFIG_DIR/fuzzel/fuzzel.ini"

# Environment variables (QT theming, etc)
mkdir -p "$CONFIG_DIR/environment.d"
if [ -d "$TEBIAN_DIR/configs/environment.d" ]; then
    cp "$TEBIAN_DIR/configs/environment.d/"* "$CONFIG_DIR/environment.d/" 2>/dev/null || true
fi

log_info "Installing scripts..."

if [ -d "$TEBIAN_DIR/scripts" ]; then
    for script in "$TEBIAN_DIR/scripts/"*; do
        name=$(basename "$script")
        # Skip installer-only scripts and directories
        [ -d "$script" ] && continue
        case "$name" in
            desktop.sh|build-iso.sh|uninstall.sh) continue ;;
            *) cp "$script" "$LOCAL_BIN/" ;;
        esac
    done
    chmod +x "$LOCAL_BIN"/* 2>/dev/null || true

    # Copy modular settings directory
    if [ -d "$TEBIAN_DIR/scripts/tebian-settings.d" ]; then
        mkdir -p "$LOCAL_BIN/tebian-settings.d"
        cp "$TEBIAN_DIR/scripts/tebian-settings.d/"*.sh "$LOCAL_BIN/tebian-settings.d/"
    fi
fi

log_info "Setting up wallpaper..."

if [ -f "$TEBIAN_DIR/assets/wallpapers/glass.jpg" ]; then
    cp "$TEBIAN_DIR/assets/wallpapers/glass.jpg" "$HOME/.local/share/backgrounds/tebian/default.jpg"
elif [ -f "$TEBIAN_DIR/assets/wallpaper.jpg" ]; then
    cp "$TEBIAN_DIR/assets/wallpaper.jpg" "$HOME/.local/share/backgrounds/tebian/default.jpg"
else
    log_info "No wallpaper found, using solid color"
fi

log_info "Setting up graphical login..."

# System wallpaper (needed by greeter and GRUB)
sudo mkdir -p /usr/share/backgrounds/tebian
if [ -f "$HOME/.local/share/backgrounds/tebian/default.jpg" ]; then
    sudo cp "$HOME/.local/share/backgrounds/tebian/default.jpg" /usr/share/backgrounds/tebian/default.jpg
fi

# tebian-session must be system-wide (greetd can't access ~/.local/bin)
sudo cp "$LOCAL_BIN/tebian-session" /usr/local/bin/tebian-session
sudo chmod +x /usr/local/bin/tebian-session

# Create greeter user if needed
if ! id greeter &>/dev/null; then
    sudo useradd -r -m -s /bin/bash greeter
fi
sudo usermod -aG video,input,render greeter 2>/dev/null || true

# Install greetd config files
sudo mkdir -p /etc/greetd
sudo cp "$TEBIAN_DIR/configs/greetd/config.toml" /etc/greetd/config.toml
sudo cp "$TEBIAN_DIR/configs/greetd/style.css" /etc/greetd/style.css
sudo cp "$TEBIAN_DIR/configs/greetd/environments" /etc/greetd/environments

# nwg-hello login screen config
sudo mkdir -p /etc/nwg-hello
sudo cp "$TEBIAN_DIR/configs/nwg-hello/nwg-hello.json" /etc/nwg-hello/nwg-hello.json
sudo cp "$TEBIAN_DIR/configs/nwg-hello/nwg-hello.css" /etc/nwg-hello/nwg-hello.css

# Enable greetd (replaces getty on tty7)
sudo systemctl enable greetd

# Set GRUB wallpaper to system path
if [ -f /etc/default/grub ]; then
    sudo sed -i 's|^GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/usr/share/backgrounds/tebian/default.jpg"|' /etc/default/grub
    sudo update-grub 2>/dev/null || true
fi

# Apply security profile from manifest (or default to standard)
SECURITY_SCRIPT="$TEBIAN_DIR/modules/core/security.sh"
if [ -f "$SECURITY_SCRIPT" ]; then
    SECURITY_PROFILE="standard"
    if [ -f "$TEBIAN_DIR/tebian.conf" ]; then
        source "$TEBIAN_DIR/tebian.conf"
    fi
    log_info "Applying security profile: ${SECURITY_PROFILE:-standard}"
    bash "$SECURITY_SCRIPT" "${SECURITY_PROFILE:-standard}"
fi

echo ""
echo "✅ Tebian Base installed!"
echo ""
echo "─── Quick Start ───"
echo "  Reboot for graphical login, or type 'sway' to start now."
echo "  On first login you'll be asked: Base (Minimal) or Desktop (Familiar)."
echo "  Desktop mode installs extras (file manager, bluetooth, screenshots, etc)."
echo ""
