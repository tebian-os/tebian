#!/bin/bash
# Tebian Pi Module - Applied to all Raspberry Pi 4/5 hardware

echo "󰠟 Initializing Tebian Pi Hardware..."

# 1. Pi-specific Kernel Headers & Tools
echo "🚀 Installing Pi Kernel & GPIO tools..."
sudo apt install -y raspberrypi-kernel-headers \
    gpio-utils raspi-config libraspberrypi-bin

# 2. Graphics Driver Optimization
echo "󰠟 Enabling V3D/VC4 Acceleration..."
# Ensure the GL driver is active in config.txt
if ! grep -q "dtoverlay=vc4-kms-v3d" /boot/firmware/config.txt; then
    echo "dtoverlay=vc4-kms-v3d" | sudo tee -a /boot/firmware/config.txt
fi

echo "✅ Tebian Pi hardware optimized."
