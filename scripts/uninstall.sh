#!/bin/bash
# ==============================================================================
# TEBIAN UNINSTALL (V1.1)
# Reverts to pure Debian. Your configs go with it.
# ==============================================================================

set -e

echo "  ████████╗███████╗██████╗ ███╗   ██╗"
echo "  ╚══██╔══╝██╔════╝██╔══██╗████╗  ██║"
echo "     ██║   █████╗  ██████╔╝██╔██╗ ██║"
echo "     ██║   ██╔══╝  ██╔══██╗██║╚██╗██║"
echo "     ██║   ███████╗██║  ██║██║ ╚████║"
echo "     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝"
echo ""
echo "  Uninstall Tebian"
echo ""
echo "  This will remove:"
echo "    - ~/.config/sway/"
echo "    - ~/.config/kitty/"
echo "    - ~/.config/fuzzel/"
echo "    - ~/.config/mako/"
echo "    - ~/.config/gtklock/"
echo "    - ~/.local/bin/tebian-*"
echo "    - ~/.local/bin/status.sh"
echo "    - ~/.local/bin/update-all"
echo ""
echo "  Your Tebian/ folder will remain (delete manually if desired)."
echo ""
read -p "  Continue? [y/N] " choice

if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    echo "  Cancelled."
    exit 0
fi

echo ""
echo "  Removing configs..."

rm -rf ~/.config/sway
rm -rf ~/.config/kitty
rm -rf ~/.config/fuzzel
rm -rf ~/.config/mako
rm -rf ~/.config/gtklock

echo "  Removing scripts..."

rm -f ~/.local/bin/tebian-*
rm -f ~/.local/bin/status.sh
rm -f ~/.local/bin/update-all
rm -f ~/.local/bin/t-fetch
rm -f ~/.local/bin/t-add
rm -f ~/.local/bin/t-launch

echo ""
read -p "  Remove desktop packages? (sway, fuzzel, kitty, mako, etc.) [y/N] " pkg_choice

if [[ "$pkg_choice" =~ ^[Yy]$ ]]; then
    echo "  Removing packages..."
    sudo apt remove -y \
        sway swaybg swayidle gtklock \
        fuzzel mako kitty \
        grim slurp wl-clipboard cliphist \
        brightnessctl autotiling wob \
        2>/dev/null || echo "  Some packages may not be installed."
    sudo apt autoremove -y
fi

echo ""
echo "  Done. You're back to pure Debian."
