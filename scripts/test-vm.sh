#!/bin/bash
# ==============================================================================
# TEBIAN VM TEST
# Builds ISO (if needed) and boots it in QEMU for quick testing
#
# Usage:
#   ./test-vm.sh              # Build + boot
#   ./test-vm.sh --boot-only  # Skip build, boot latest ISO
#   ./test-vm.sh --rebuild    # Force rebuild even if ISO exists
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEBIAN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ISO_DIR="$TEBIAN_DIR"
VM_DIR="$TEBIAN_DIR/.vm"
VM_DISK="$VM_DIR/tebian-test.qcow2"
DISK_SIZE="20G"
RAM="4096"
CPUS="2"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Find latest ISO
find_iso() {
    ls -t "$ISO_DIR"/tebian-*.iso 2>/dev/null | head -1
}

# Parse args
BUILD=true
FORCE_REBUILD=false
for arg in "$@"; do
    case "$arg" in
        --boot-only) BUILD=false ;;
        --rebuild) FORCE_REBUILD=true ;;
    esac
done

# Install QEMU if needed
if ! command -v qemu-system-x86_64 &>/dev/null; then
    echo -e "${YELLOW}Installing QEMU...${NC}"
    sudo apt update && sudo apt install -y qemu-system-x86 qemu-utils ovmf
fi

# Build ISO
if $BUILD; then
    EXISTING_ISO=$(find_iso)
    if [ -n "$EXISTING_ISO" ] && ! $FORCE_REBUILD; then
        echo -e "${YELLOW}Found existing ISO: $(basename "$EXISTING_ISO")${NC}"
        echo -e "${YELLOW}Use --rebuild to force a fresh build${NC}"
    else
        echo -e "${GREEN}Building ISO...${NC}"
        sudo bash "$SCRIPT_DIR/build-iso.sh"
    fi
fi

ISO=$(find_iso)
if [ -z "$ISO" ]; then
    echo -e "${RED}No ISO found in $ISO_DIR${NC}"
    echo "  Run: sudo bash scripts/build-iso.sh"
    exit 1
fi

echo ""
echo -e "${GREEN}ISO: $(basename "$ISO")${NC}"

# Create VM disk if needed
mkdir -p "$VM_DIR"
if [ ! -f "$VM_DISK" ]; then
    echo -e "${GREEN}Creating ${DISK_SIZE} virtual disk...${NC}"
    qemu-img create -f qcow2 "$VM_DISK" "$DISK_SIZE"
fi

# Check for KVM support
KVM_FLAG=""
if [ -w /dev/kvm ]; then
    KVM_FLAG="-enable-kvm"
    echo -e "${GREEN}KVM acceleration: enabled${NC}"
else
    echo -e "${YELLOW}KVM not available — VM will be slow${NC}"
fi

# Find OVMF firmware for UEFI boot
OVMF=""
for path in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/qemu/OVMF.fd; do
    if [ -f "$path" ]; then
        OVMF="$path"
        break
    fi
done

echo -e "${GREEN}Booting VM (${RAM}MB RAM, ${CPUS} CPUs)...${NC}"
echo -e "${YELLOW}  Close VM window or Ctrl+C to stop${NC}"
echo ""

# Boot with UEFI if available, BIOS fallback
if [ -n "$OVMF" ]; then
    echo -e "${GREEN}UEFI boot: $OVMF${NC}"
    qemu-system-x86_64 \
        $KVM_FLAG \
        -m "$RAM" \
        -smp "$CPUS" \
        -drive if=pflash,format=raw,readonly=on,file="$OVMF" \
        -drive file="$VM_DISK",format=qcow2 \
        -cdrom "$ISO" \
        -boot d \
        -device virtio-vga \
        -display gtk \
        -device qemu-xhci \
        -device usb-kbd \
        -device usb-mouse \
        -nic user,model=virtio-net-pci
else
    echo -e "${YELLOW}BIOS boot (OVMF not found)${NC}"
    qemu-system-x86_64 \
        $KVM_FLAG \
        -m "$RAM" \
        -smp "$CPUS" \
        -drive file="$VM_DISK",format=qcow2 \
        -cdrom "$ISO" \
        -boot d \
        -vga virtio \
        -device qemu-xhci \
        -device usb-kbd \
        -device usb-mouse \
        -nic user,model=virtio-net-pci
fi
