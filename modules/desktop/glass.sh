#!/bin/bash
# Tebian Desktop Module - Applied only to the Flagship role

echo "󰇄 Initializing Tebian Desktop (Stealth Glass UI)..."

# 1. Standard Wayland / Sway stack
echo "󰘔 Installing Sway, Kitty, Wayland components..."
sudo apt install -y sway wayland-protocols swaybg \
    kitty fuzzel grim slurp wl-clipboard \
    pulsemixer brightnessctl mako-notifier autotiling \
    gtklock swayidle libnotify-bin cliphist

# 2. Icon & Fonts for Desktop
echo "󰘔 Installing Fonts & Icons..."
sudo apt install -y fonts-jetbrains-mono-nerd-font \
    adwaita-icon-theme-full hicolor-icon-theme

# 3. Apply custom Tebian configurations
# We assume the user has cloned the config or we'll link it from ~/Tebian/
mkdir -p ~/.config/sway ~/.config/kitty ~/.config/mako ~/.config/gtklock ~/Pictures/Screenshots
ln -sf ~/Tebian/configs/sway/config ~/.config/sway/config
ln -sf ~/Tebian/configs/kitty/kitty.conf ~/.config/kitty/kitty.conf
ln -sf ~/Tebian/configs/mako/config ~/.config/mako/config

echo "✅ Tebian Desktop initialized."
