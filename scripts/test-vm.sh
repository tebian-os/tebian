#!/bin/bash
# ==============================================================================
# TEBIAN VM TEST
# Builds the ISO (if needed) and boots it in QEMU for quick testing
#
# Usage:
#   ./test-vm.sh                # Build if no ISO yet, then boot (UEFI)
#   ./test-vm.sh --boot-only    # Skip build, boot the newest ISO
#   ./test-vm.sh --rebuild      # Force a fresh build first
#   ./test-vm.sh --bios         # Legacy BIOS (SeaBIOS) instead of UEFI
#   ./test-vm.sh --secureboot   # UEFI with Secure Boot on (Microsoft keys,
#                               # like a stock laptop)
#   ./test-vm.sh --disk         # Boot the installed system (no ISO attached)
#   ./test-vm.sh --ram=2048     # Guest RAM in MB (default 4096) — 2048 or
#                               # less exercises the low-memory boot entry
#   ./test-vm.sh --fresh        # Wipe the test disk and NVRAM first
#
# Files (outside the repo, so they can never ship in an ISO):
#   ~/tebian-test.qcow2              test disk
#   ~/tebian-test.OVMF_VARS*.fd      per-mode UEFI NVRAM, so boot entries the
#                                    installer creates survive a VM reboot
#                                    the way they do on real hardware
# ISOs are looked up in ~/ and ~/iso/, newest first.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEBIAN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# The repo's parent (~/ on the dev machine) — where build.sh and ISOs live
WORK_DIR="${TEBIAN_WORK_DIR:-$(dirname "$TEBIAN_DIR")}"
VM_DISK="$WORK_DIR/tebian-test.qcow2"
DISK_SIZE="20G"
RAM="4096"
CPUS="2"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# nullglob, not ls on raw patterns: a missing ~/iso/ makes ls exit non-zero,
# which pipefail + set -e turn into a silent exit of the whole script
find_iso() {
    local isos
    shopt -s nullglob
    isos=("$WORK_DIR"/tebian-*.iso "$WORK_DIR"/iso/tebian-*.iso)
    shopt -u nullglob
    [ "${#isos[@]}" -gt 0 ] || return 0
    ls -t "${isos[@]}" | head -1
}

BUILD=true
FORCE_REBUILD=false
FIRMWARE=uefi
BOOT_ISO=true
FRESH=false
for arg in "$@"; do
    case "$arg" in
        --boot-only)  BUILD=false ;;
        --rebuild)    FORCE_REBUILD=true ;;
        --bios)       FIRMWARE=bios ;;
        --secureboot) FIRMWARE=secureboot ;;
        --disk)       BOOT_ISO=false; BUILD=false ;;
        --ram=*)      RAM="${arg#--ram=}" ;;
        --fresh)      FRESH=true ;;
        -h|--help)    sed -n '3,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo -e "${RED}Unknown option: $arg${NC} (see --help)"; exit 1 ;;
    esac
done
[[ "$RAM" =~ ^[0-9]+$ ]] || { echo -e "${RED}--ram needs a number of MB${NC}"; exit 1; }

if ! command -v qemu-system-x86_64 &>/dev/null; then
    echo -e "${YELLOW}Installing QEMU...${NC}"
    sudo apt update && sudo apt install -y qemu-system-x86 qemu-utils ovmf
fi

if $BUILD; then
    EXISTING_ISO=$(find_iso)
    if [ -n "$EXISTING_ISO" ] && ! $FORCE_REBUILD; then
        echo -e "${YELLOW}Found existing ISO: $(basename "$EXISTING_ISO")${NC}"
        echo -e "${YELLOW}Use --rebuild to force a fresh build${NC}"
    else
        echo -e "${GREEN}Building ISO...${NC}"
        # Prefer the container wrapper when it exists — it keeps the host clean
        if [ -x "$WORK_DIR/build.sh" ]; then
            "$WORK_DIR/build.sh"
        else
            sudo env TEBIAN_OUTPUT_DIR="$WORK_DIR" bash "$SCRIPT_DIR/build-iso.sh"
        fi
    fi
fi

ISO=""
if $BOOT_ISO; then
    ISO=$(find_iso)
    if [ -z "$ISO" ]; then
        echo -e "${RED}No ISO found in $WORK_DIR or $WORK_DIR/iso${NC}"
        echo "  Build one: $WORK_DIR/build.sh  (or: sudo bash scripts/build-iso.sh)"
        exit 1
    fi
    echo ""
    echo -e "${GREEN}ISO: $ISO${NC}"
fi

if $FRESH; then
    echo -e "${YELLOW}Wiping test disk and NVRAM...${NC}"
    rm -f "$VM_DISK" "$WORK_DIR"/tebian-test.OVMF_VARS*.fd
fi
if [ ! -f "$VM_DISK" ]; then
    echo -e "${GREEN}Creating ${DISK_SIZE} virtual disk at $VM_DISK...${NC}"
    qemu-img create -f qcow2 "$VM_DISK" "$DISK_SIZE" >/dev/null
fi

ACCEL=()
if [ -w /dev/kvm ]; then
    ACCEL=(-enable-kvm -cpu host)
    echo -e "${GREEN}KVM acceleration: enabled${NC}"
else
    echo -e "${YELLOW}KVM not available — VM will be slow${NC}"
fi

# Writable NVRAM copied from the pristine template on first use. Kept per
# mode: Secure Boot VARS carry enrolled Microsoft keys, plain ones don't.
nvram() {
    local template="$1" copy="$2"
    [ -f "$copy" ] || cp "$template" "$copy"
    echo "$copy"
}

FW=()
MACHINE=(-machine q35)
case "$FIRMWARE" in
    uefi)
        code=/usr/share/OVMF/OVMF_CODE_4M.fd
        vars_t=/usr/share/OVMF/OVMF_VARS_4M.fd
        if [ ! -f "$code" ] || [ ! -f "$vars_t" ]; then
            echo -e "${RED}OVMF not found${NC} — sudo apt install ovmf (or use --bios)"; exit 1
        fi
        FW=(-drive if=pflash,format=raw,readonly=on,file="$code"
            -drive if=pflash,format=raw,file="$(nvram "$vars_t" "$WORK_DIR/tebian-test.OVMF_VARS.fd")")
        echo -e "${GREEN}Firmware: UEFI${NC}"
        ;;
    secureboot)
        code=/usr/share/OVMF/OVMF_CODE_4M.ms.fd
        vars_t=/usr/share/OVMF/OVMF_VARS_4M.ms.fd
        if [ ! -f "$code" ] || [ ! -f "$vars_t" ]; then
            echo -e "${RED}Secure Boot OVMF not found${NC} — sudo apt install ovmf"; exit 1
        fi
        # The secboot firmware build only runs with SMM, which keeps the
        # guest OS from rewriting the key store behind the firmware's back
        MACHINE=(-machine q35,smm=on -global driver=cfi.pflash01,property=secure,value=on)
        FW=(-drive if=pflash,format=raw,readonly=on,file="$code"
            -drive if=pflash,format=raw,file="$(nvram "$vars_t" "$WORK_DIR/tebian-test.OVMF_VARS.ms.fd")")
        echo -e "${GREEN}Firmware: UEFI + Secure Boot (Microsoft keys)${NC}"
        ;;
    bios)
        MACHINE=(-machine pc)
        echo -e "${GREEN}Firmware: legacy BIOS (SeaBIOS)${NC}"
        ;;
esac

MEDIA=(-drive file="$VM_DISK",format=qcow2,if=virtio)
if [ -n "$ISO" ]; then
    MEDIA+=(-drive file="$ISO",media=cdrom,readonly=on -boot order=d)
else
    MEDIA+=(-boot order=c)
fi

echo -e "${GREEN}Booting VM (${RAM}MB RAM, ${CPUS} CPUs)...${NC}"
echo -e "${YELLOW}  Close VM window or Ctrl+C to stop${NC}"
echo ""

qemu-system-x86_64 \
    "${MACHINE[@]}" \
    "${ACCEL[@]}" \
    -m "$RAM" \
    -smp "$CPUS" \
    "${FW[@]}" \
    "${MEDIA[@]}" \
    -device virtio-vga \
    -display gtk \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-tablet \
    -nic user,model=virtio-net-pci
