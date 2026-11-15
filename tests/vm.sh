#!/bin/bash
# ==============================================================================
# TEBIAN VM CHECK
# The whole road a new user takes, with nobody watching: boot the ISO in a
# hidden QEMU machine, let the installer run unattended, boot the installed
# disk, log in at the greeter, shut down — then read the installed system's
# own journal off the disk to see what really happened. Run it on an ISO
# before publishing it:
#
#   bash tests/vm.sh [tebian.iso]      # default: newest ~/tebian-*.iso
#   bash tests/vm.sh --bios [iso]      # legacy BIOS instead of UEFI
#   bash tests/vm.sh --keep ...        # keep the work dir after a pass
#   bash tests/vm.sh --reuse           # skip the install: boot the disk a
#                                      # kept or failed run left behind
#
# Takes 10-40 minutes. Needs qemu-system-x86, ovmf, python3, e2fsprogs
# (debugfs) and fdisk (sfdisk); no root. KVM is used when available.
#
# Everything lives in a work dir outside the repo (TEBIAN_VM_DIR, default
# ~/.cache/tebian-vm) — never the disk scripts/test-vm.sh uses for manual
# tests. On a failure it is kept: screenshots (*.png) and the installed
# system's journal (journal.txt) are there to look at.
#
# How it knows, without trusting the screen: the installer's answers come
# in through QEMU's fw_cfg (see load_answers in scripts/tebian-installer),
# and the verdict comes from files on the installed disk, read with debugfs
# after the machine is off.
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $*"; }
note() { echo -e "${YELLOW}…${NC} $*"; }
fails=0
fail() { echo -e "${RED}✗${NC} $*"; fails=$((fails + 1)); }
stop() { echo -e "${RED}✗${NC} $*"; echo "  Left for inspection: $WORK"; exit 1; }

FIRMWARE=uefi
KEEP=false
REUSE=false
ISO=""
for arg in "$@"; do
    case "$arg" in
        --bios) FIRMWARE=bios ;;
        --keep) KEEP=true ;;
        --reuse) REUSE=true; KEEP=true ;;
        -h|--help) sed -n '3,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "Unknown option: $arg (see --help)"; exit 1 ;;
        *) ISO="$arg" ;;
    esac
done

WORK="${TEBIAN_VM_DIR:-$HOME/.cache/tebian-vm}"
if [ -z "$ISO" ] && ! $REUSE; then
    shopt -s nullglob
    isos=("$HOME"/tebian-*.iso)
    shopt -u nullglob
    [ "${#isos[@]}" -gt 0 ] || { echo "No ISO given and none in ~/ (build one: ./build.sh)"; exit 1; }
    # shellcheck disable=SC2012
    ISO=$(ls -t "${isos[@]}" | head -1)
fi
if ! $REUSE; then
    ISO=$(realpath "$ISO")
    [ -r "$ISO" ] || { echo "Can't read $ISO"; exit 1; }
fi

PATH="$PATH:/usr/sbin:/sbin"   # debugfs and sfdisk, for a non-root user
for tool in qemu-system-x86_64 qemu-img python3 debugfs sfdisk journalctl; do
    command -v "$tool" >/dev/null || { echo "Missing: $tool"; exit 1; }
done

# The one login this throwaway machine has
VM_USER=tester
VM_PASS=tebian-vm-check

if $REUSE; then
    [ -f "$WORK/disk.qcow2" ] || { echo "--reuse: no installed disk in $WORK"; exit 1; }
else
    rm -rf "$WORK"
    mkdir -p "$WORK"
fi
# QEMU's control socket is addressed relative to here: a unix socket path
# can't be longer than 107 bytes, and a work dir easily is
cd "$WORK"

ACCEL=()
if [ -w /dev/kvm ]; then
    ACCEL=(-enable-kvm -cpu host)
else
    note "No KVM — this will take a long time"
fi
case "$FIRMWARE" in
    uefi)
        [ -f /usr/share/OVMF/OVMF_CODE_4M.fd ] || { echo "OVMF not found (apt install ovmf, or use --bios)"; exit 1; }
        # A private copy of the NVRAM: the boot entry the installer creates
        # has to survive into the second boot, as it does on real hardware
        $REUSE || cp /usr/share/OVMF/OVMF_VARS_4M.fd vars.fd
        # shellcheck disable=SC2054  # the commas are QEMU's, inside one argument
        FW=(-machine q35
            -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd
            -drive if=pflash,format=raw,file=vars.fd) ;;
    bios)
        FW=(-machine pc) ;;
esac

# Starts the machine in the background; extra arguments are the media
vm_start() {
    rm -f qmp.sock
    qemu-system-x86_64 "${FW[@]}" "${ACCEL[@]}" -m 4096 -smp 2 \
        -drive file=disk.qcow2,format=qcow2,if=virtio "$@" \
        -device virtio-vga -display none \
        -device qemu-xhci -device usb-kbd \
        -nic user,model=virtio-net-pci \
        -qmp unix:qmp.sock,server,nowait -no-reboot > qemu.log 2>&1 &
    VM_PID=$!
}
# Stops it if the script ends early, whatever the reason
trap '[ -n "${VM_PID:-}" ] && kill "$VM_PID" 2>/dev/null || true' EXIT

# Waits until the machine has switched itself off; fails after $1 seconds
vm_wait_off() {
    local left="$1"
    while kill -0 "$VM_PID" 2>/dev/null; do
        [ "$left" -gt 0 ] || return 1
        sleep 5; left=$((left - 5))
    done
    wait "$VM_PID" 2>/dev/null || true
    VM_PID=""
}

# Talks to the running machine over QMP, QEMU's control protocol:
#   vm shot NAME.png   screenshot
#   vm type TEXT       type it on the keyboard
#   vm key ctrl+alt+f2 one key or chord (QEMU key names)
#   vm status          running, or why not (io-error: the host disk is full)
vm() {
    python3 - "$@" <<'PY'
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.connect("qmp.sock"); f = s.makefile("rw")
def cmd(name, **args):
    f.write(json.dumps({"execute": name, "arguments": args}) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "error" in r: sys.exit("QMP %s: %s" % (name, r["error"]["desc"]))
        if "return" in r: return r["return"]
def key(*codes):
    cmd("send-key", keys=[{"type": "qcode", "data": c} for c in codes])
NAMES = {"-": "minus", "_": ("shift", "minus"), " ": "spc", ".": "dot", ";": "semicolon"}
f.readline(); cmd("qmp_capabilities")
what, arg = sys.argv[1], (sys.argv[2:] or [""])[0]
if what == "shot": cmd("screendump", filename=arg, format="png")
elif what == "key": key(*arg.split("+"))
elif what == "status": print(cmd("query-status")["status"])
elif what == "type":
    for ch in arg:
        k = NAMES.get(ch, ch.lower())
        key(*((k,) if isinstance(k, str) else k)) if not ch.isupper() else key("shift", k)
PY
}

# Reads from the installed root filesystem, machine off: disk_cat /etc/fstab
disk_open() {
    local start
    qemu-img convert -O raw disk.qcow2 disk.raw
    start=$(sfdisk -d disk.raw | awk -F'[=,]' '/name="root"|type=0FC63DAF|type=83/ { gsub(/ /, "", $2); print $2; exit }')
    [ -n "$start" ] || return 1
    dd if=disk.raw of=root.img bs=512 skip="$start" conv=sparse status=none
    rm -f disk.raw
}
disk_cat() { debugfs -R "cat $1" root.img 2>/dev/null; }

# --- 1. Install ---------------------------------------------------------------
if ! $REUSE; then
echo "ISO: $ISO ($FIRMWARE)"
qemu-img create -f qcow2 disk.qcow2 20G >/dev/null
printf 'disk=/dev/vda\nusername=%s\npassword=%s\nhostname=vmcheck\n' "$VM_USER" "$VM_PASS" > answers
note "Installing unattended (the slow part)..."
vm_start -drive file="$ISO",media=cdrom,readonly=on -boot order=d \
    -fw_cfg name=opt/org.tebian/answers,file=answers
if ! vm_wait_off 3600; then
    vm shot install-stuck.png || true
    stop "install: not finished after an hour — machine is '$(vm status || true)' (see install-stuck.png)"
fi
pass "install: the installer ran and powered the machine off"

# The installer powers off on failure too, so the disk has to say which
disk_open || stop "install: no root partition on the disk"
release=$(disk_cat /etc/tebian-release || true)
if [ -n "$release" ] && [ -n "$(disk_cat /boot/grub/grub.cfg | grep -m1 '^menuentry' || true)" ]; then
    pass "install: system and boot menu are on the disk ($(echo "$release" | tr '\n' ' '))"
else
    stop "install: the disk has no finished system (no /etc/tebian-release or grub.cfg)"
fi
fi

# --- 2. First boot of the installed system -------------------------------------
note "Booting the installed disk..."
vm_start -boot order=c
sleep 90
vm shot greeter.png
# The greeter has the only user selected and the password field focused
vm type "$VM_PASS"
vm key ret
sleep 45
vm shot desktop.png
# Off the way a user at a console would do it — the power button belongs
# to Tebian's power menu, and the journal is only readable after a clean
# shutdown. A second login on tty2, then poweroff (allowed without a
# password for someone sitting at the machine). On the way it leaves a
# file saying sway is running: sway itself writes nothing to the journal.
vm key ctrl+alt+f2
sleep 3
vm type "$VM_USER"; vm key ret; sleep 2
vm type "$VM_PASS"; vm key ret; sleep 5
vm type "if pgrep -x sway; then touch sway-is-up; fi"; vm key ret; sleep 2
vm type "systemctl poweroff"; vm key ret
if vm_wait_off 120; then
    pass "boot: the installed system took a console login and shut down cleanly"
else
    vm shot shutdown-stuck.png || true
    stop "boot: did not shut down from a console login within 2 minutes — not booted? (see greeter.png, shutdown-stuck.png)"
fi

# --- 3. What the installed system says happened --------------------------------
disk_open || stop "boot: root partition gone after the first boot"
rm -rf journal && mkdir journal
debugfs -R "rdump /var/log/journal journal" root.img >/dev/null 2>&1 || true
journalctl -D journal/journal --no-pager -o short-monotonic > journal.txt 2>/dev/null || true
[ -s journal.txt ] || stop "boot: the installed system left no journal"

if grep -q "Reached target graphical.target" journal.txt; then
    pass "boot: reached the graphical target"
else
    fail "boot: never reached the graphical target"
fi
if grep -q "pam_unix(greetd:session): session opened for user $VM_USER" journal.txt; then
    pass "login: the greeter accepted the password"
else
    fail "login: no session opened for $VM_USER through the greeter (see greeter.png, desktop.png)"
fi
if debugfs -R "stat /home/$VM_USER/sway-is-up" root.img 2>/dev/null | grep -q "^Inode:"; then
    pass "desktop: sway was running after the login"
else
    fail "desktop: sway was not running after the login (see desktop.png)"
fi
rm -f root.img
failed_units=$(grep -oE "Failed to start [^ ]+\.(service|mount|socket)" journal.txt | sort -u || true)
if [ -z "$failed_units" ]; then
    pass "boot: no unit failed to start"
else
    fail "boot: $(echo "$failed_units" | tr '\n' ';')"
fi

echo
if [ "$fails" -eq 0 ]; then
    echo -e "${GREEN}VM check passed.${NC}"
    if $KEEP; then echo "  Kept: $WORK"; else cd /; rm -rf "$WORK"; fi
else
    echo -e "${RED}$fails VM check(s) failed.${NC} Screenshots and journal.txt: $WORK"; exit 1
fi
