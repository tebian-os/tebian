#!/bin/bash
# Tebian x86 Module - Applied to standard PC/Laptop hardware

echo "󰘔 Initializing x86/Generic Hardware..."

# 1. Standard Kernel Headers & Tools
echo "🚀 Installing x86 Kernel & Graphics drivers..."
sudo apt install -y linux-headers-amd64 \
    mesa-vulkan-drivers mesa-va-drivers \
    libgl1-mesa-dri intel-media-va-driver mesa-vdpau-drivers

# 2. Touchpad / Input Support
echo "🚀 Installing Libinput & Gesture support..."
sudo apt install -y libinput-bin libinput-tools xserver-xorg-input-libinput

echo "✅ x86/Generic hardware optimized."
