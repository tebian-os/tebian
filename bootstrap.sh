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

# Same gate as install.sh, for when this is run directly: trixie-era
# packages (sway 1.10, nwg-hello, gtklock) don't exist on older releases
os_id=$(. /etc/os-release 2>/dev/null && echo "${ID:-}")
os_ver=$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}")
os_code=$(. /etc/os-release 2>/dev/null && echo "${VERSION_CODENAME:-}")
os_ok=""
case "$os_id" in
    debian|raspbian)
        { [[ "$os_ver" =~ ^[0-9]+$ ]] && [ "$os_ver" -ge 13 ]; } && os_ok=1
        case "$os_code" in trixie|forky|duke|sid) os_ok=1 ;; esac
        ;;
esac
if [ -z "$os_ok" ] && [ "${TEBIAN_FORCE:-}" != 1 ]; then
    echo -e "${RED}Tebian needs Debian 13 (trixie) or newer.${NC} Set TEBIAN_FORCE=1 to try anyway."
    exit 1
fi

# Prompts read the terminal directly: stdin may be a pipe (curl | bash).
# With no terminal at all, TEBIAN_MODE picks the mode unattended.
have_tty() { ( : </dev/tty ) 2>/dev/null; }
ask() {
    local reply=""
    if have_tty; then read -r -p "$1" reply </dev/tty || true; fi
    echo "${reply:-$2}"
}

case "${TEBIAN_MODE:-}" in
    1|desktop|tebian) choice=1 ;;
    2|server)         choice=2 ;;
    "")
        if ! have_tty; then
            echo -e "${RED}No terminal to ask on.${NC} Set TEBIAN_MODE=desktop or TEBIAN_MODE=server."
            exit 1
        fi
        clear
        echo "  ┌───────────────┐"
        echo "  │  T E B I A N  │"
        echo "  └───────────────┘"
        echo ""
        echo "  [1] Tebian"
        echo "  [2] Server"
        echo ""
        choice=$(ask "  Select [1/2]: " "")
        ;;
    *)
        echo -e "${RED}Unknown TEBIAN_MODE '$TEBIAN_MODE' (use desktop or server).${NC}"
        exit 1
        ;;
esac

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
            # Apply the manifest (extra packages, services, Tor/DNS toggles —
            # what a fleet tebian.conf declares). Safe here: nothing has been
            # customized yet on a fresh install.
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
                curl wget git btop bash-completion unzip
            
            # Secure SSH. The port comes from sshd's effective config, so a
            # custom Port can't end up firewalled off; if we're connected
            # over SSH right now, that port stays open whatever sshd says.
            sudo systemctl enable --now ssh
            sudo ufw default deny incoming
            ssh_ports=$(sudo sshd -T 2>/dev/null | awk '$1 == "port" { print $2 }')
            [ -n "${SSH_CONNECTION:-}" ] && ssh_ports+=" $(echo "$SSH_CONNECTION" | awk '{ print $4 }')"
            for p in ${ssh_ports:-22}; do
                sudo ufw allow "$p/tcp" comment 'SSH' >/dev/null
            done
            sudo ufw --force enable
            sudo systemctl enable --now fail2ban
            echo "  ✓ Firewall active (SSH allowed)"
        fi
        
        echo ""
        echo -e "${RED}  This will remove all Tebian Desktop files ($TEBIAN_DIR).${NC}"
        # Unattended installs keep the files — deleting needs a human
        confirm_delete=$(ask "  Type DELETE to confirm: " "")
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
        rm -rf ~/.local/bin/tebian-settings.d
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
