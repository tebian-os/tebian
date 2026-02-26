#!/bin/bash
# ==============================================================================
# TEBIAN OS BOOTSTRAP (V2.2)
# Runs on first boot or manual install
# Philosophy: One question. Sane defaults.
# ==============================================================================

set -euo pipefail

TEBIAN_DIR="${TEBIAN_DIR:-$HOME/Tebian}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common library if available
if [ -f "$SCRIPT_DIR/scripts/tebian-common" ]; then
    source "$SCRIPT_DIR/scripts/tebian-common"
    trap_error
fi

# Transaction log
BOOTSTRAP_LOG="$HOME/.local/share/tebian-bootstrap.log"
mkdir -p "$HOME/.local/share"
blog() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$BOOTSTRAP_LOG"; }

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

clear
echo "  ┌───────────────┐"
echo "  │  T E B I A N  │"
echo "  └───────────────┘"
echo ""
echo "  [1] Tebian"
echo "  [2] Server"
echo ""
read -p "  Select [1/2]: " choice

case "$choice" in
    1)
        # Check Tebian directory exists for desktop mode
        if [ ! -d "$TEBIAN_DIR" ]; then
            echo -e "${RED}Error: Tebian directory not found at $TEBIAN_DIR${NC}"
            echo "Set TEBIAN_DIR environment variable if installed elsewhere"
            exit 1
        fi

        if [ ! -f "$TEBIAN_DIR/scripts/desktop.sh" ]; then
            echo -e "${RED}Error: scripts/desktop.sh not found in $TEBIAN_DIR${NC}"
            exit 1
        fi

        # Pre-flight checks
        echo ""
        echo "  Running pre-flight checks..."
        if ! ping -c1 -W3 1.1.1.1 &>/dev/null; then
            echo -e "${RED}  ✗ No internet connection. Connect to a network first.${NC}"
            exit 1
        fi
        echo -e "${GREEN}  ✓ Internet connection${NC}"

        AVAIL_KB=$(df --output=avail / 2>/dev/null | tail -1)
        if [ -n "$AVAIL_KB" ] && [ "$AVAIL_KB" -lt 2097152 ]; then
            echo -e "${RED}  ✗ Less than 2GB disk space available. Free up space first.${NC}"
            exit 1
        fi
        echo -e "${GREEN}  ✓ Disk space OK${NC}"

        echo ""
        blog "Starting Tebian Desktop installation"
        echo -e "${GREEN}Installing Tebian Desktop...${NC}"
        if bash "$TEBIAN_DIR/scripts/desktop.sh"; then
            # Apply manifest if it exists
            if [ -f "$TEBIAN_DIR/tebian.conf" ]; then
                echo ""
                echo -e "${GREEN}Applying system manifest...${NC}"
                bash "$TEBIAN_DIR/scripts/tebian-rebuild"
            fi
            echo ""
            blog "Desktop installation complete"
            echo -e "${GREEN}✅ Done. Reboot for graphical login, or type 'sway' to start now.${NC}"
        else
            echo ""
            blog "Desktop installation FAILED"
            echo -e "${RED}❌ Installation failed. Check the output above.${NC}"
            exit 1
        fi
        ;;
    2)
        echo ""
        blog "Server mode selected"
        echo -e "${GREEN}Server mode selected.${NC}"
        echo ""
        echo "  Configuring for headless server..."
        
        # Install SSH and Firewall (Critical for headless)
        if command -v apt &>/dev/null; then
            echo "  Installing Server Essentials (SSH, UFW, Core Utils)..."
            sudo apt update && sudo apt install -y \
                openssh-server ufw fail2ban \
                curl wget git htop btop bash-completion unzip
            
            # Secure SSH
            sudo ufw default deny incoming
            sudo ufw allow ssh
            sudo ufw --force enable
            sudo systemctl enable --now ssh
            sudo systemctl enable --now fail2ban
            echo "  ✓ Firewall active (SSH allowed)"
        fi
        
        echo ""
        echo -e "${RED}  This will remove all Tebian Desktop files ($TEBIAN_DIR).${NC}"
        read -p "  Type DELETE to confirm: " confirm_delete
        if [ "$confirm_delete" != "DELETE" ]; then
            echo "  Cancelled. Desktop files kept."
        else
            echo "  Removing Tebian Desktop files..."
            if [ -d "$TEBIAN_DIR" ]; then
                rm -rf "$TEBIAN_DIR"
                echo -e "${GREEN}  ✓ Removed $TEBIAN_DIR${NC}"
            fi
        fi
        
        rm -f ~/.local/bin/tebian-* 2>/dev/null || true
        rm -f ~/.local/bin/status.sh 2>/dev/null || true
        rm -f ~/.local/bin/update-all 2>/dev/null || true
        
        echo ""
        echo -e "${GREEN}✅ Pure Debian.${NC}"
        ;;
    *)
        echo ""
        echo -e "${RED}Invalid choice. Run $0 again.${NC}"
        exit 1
        ;;
esac
