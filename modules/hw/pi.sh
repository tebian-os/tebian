#!/bin/bash
# Tebian Pi Module - Applied to all Raspberry Pi 4/5 hardware

echo "󰠟 Initializing Tebian Pi Hardware..."

# Install only what this system's repositories actually carry. Raspberry Pi
# OS renames packages between releases (raspberrypi-kernel-headers became
# versioned linux-headers-*, libraspberrypi-bin became raspi-utils), and a
# single unknown name makes apt refuse the whole list.
apt_install_available() {
    local pkg available=()
    for pkg in "$@"; do
        if apt-cache policy "$pkg" 2>/dev/null | grep -q 'Candidate: [^(]'; then
            available+=("$pkg")
        else
            echo "  (skipping $pkg — not in this system's repositories)"
        fi
    done
    [ ${#available[@]} -gt 0 ] && sudo apt install -y "${available[@]}"
}

# 1. Kernel headers (for DKMS modules) & Pi tools
echo "🚀 Installing Pi Kernel & GPIO tools..."
# Headers for the running kernel: Pi OS ships them per kernel version, which
# is the one name guaranteed to match what's booted
apt_install_available "linux-headers-$(uname -r)" raspi-config raspi-utils

# 2. Graphics Driver Optimization
echo "󰠟 Enabling V3D/VC4 Acceleration..."
# Bookworm and later keep config.txt in /boot/firmware; older images in /boot
CONFIG_TXT=""
for f in /boot/firmware/config.txt /boot/config.txt; do
    [ -f "$f" ] && { CONFIG_TXT="$f"; break; }
done
if [ -z "$CONFIG_TXT" ]; then
    echo "  config.txt not found — skipping (not a Raspberry Pi firmware layout)"
elif ! grep -q "^[[:space:]]*dtoverlay=vc4-kms-v3d" "$CONFIG_TXT"; then
    echo "dtoverlay=vc4-kms-v3d" | sudo tee -a "$CONFIG_TXT" >/dev/null
    echo "  Enabled vc4-kms-v3d in $CONFIG_TXT (takes effect after reboot)"
fi

echo "✅ Tebian Pi hardware optimized."
