#!/bin/bash
# Tebian x86 Module - Applied to standard PC/Laptop hardware

echo "󰘔 Initializing x86/Generic Hardware..."

# Install only what this system's repositories carry — one unknown name
# makes apt refuse the whole list
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

# 1. Kernel headers (for DKMS drivers such as NVIDIA) & graphics
echo "🚀 Installing x86 Kernel & Graphics drivers..."
# linux-headers-amd64 tracks Debian's own kernel; on a custom or
# distribution-specific kernel it would pull in a mismatched set
HEADERS=""
if [ "$(dpkg --print-architecture)" = amd64 ] && dpkg -s linux-image-amd64 >/dev/null 2>&1; then
    HEADERS=linux-headers-amd64
fi
apt_install_available $HEADERS \
    mesa-vulkan-drivers mesa-va-drivers \
    libgl1-mesa-dri intel-media-va-driver mesa-vdpau-drivers

# 2. Touchpad / Input Support
# libinput itself comes with sway (via wlroots); the tools add gesture and
# device debugging. The Xorg input driver is deliberately absent — Tebian
# runs Wayland only.
echo "🚀 Installing Libinput tools..."
apt_install_available libinput-tools

echo "✅ x86/Generic hardware optimized."
