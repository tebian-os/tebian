# Tebian

A usability layer for Debian. Debian 13 (trixie) underneath, a Sway (Wayland)
desktop on top, and one fuzzel-driven Control Center for everything in
between. Everything is plain, readable bash.

**Website:** [tebian.org](https://tebian.org)
**Version:** see [VERSION](./VERSION) — 3.2.0 at the time of writing
**License:** MIT

## Install

### From the ISO (x86_64 PCs)

Download the latest ISO and its checksum from
[GitHub Releases](https://github.com/tebian-os/tebian/releases/latest), verify
it, and write it to a USB stick (Ventoy, Rufus in DD mode, balenaEtcher, or
`dd` all work):

```bash
sha256sum -c tebian-*.iso.sha256
sudo dd if=tebian-YYYYMMDD.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

The ISO boots on UEFI and legacy BIOS machines. The live session logs in
automatically and starts the text-mode installer, which offers:

- erase a disk, or install alongside Windows / another Linux (dual-boot)
- optional full-disk encryption
- **Desktop** (Sway), **Server with SSH + firewall**, or **bare server** modes
- WiFi set up in the installer carries over to the installed system

Boot menu entries: the default copies the live system into RAM (fast, and the
USB can be removed); **low memory** runs straight from the USB for machines
with around 2 GB of RAM; **safe graphics** adds `nomodeset` for GPUs that show
a black screen.

**Live session login:** user `user`, password `user` (passwordless sudo). You
only need this if you leave the installer — restart it with
`sudo tebian-installer`. `cat /etc/tebian-release` shows which build you are
running.

### On an existing Debian 13 system

```bash
curl -sL tebian.org/install | bash
```

Needs Debian 13 (trixie) or newer, including Raspberry Pi OS and Armbian
images built on trixie — this is the way to install on ARM boards. It asks
whether to set up the Tebian desktop or a hardened headless server.

## Using it

| Keys | Action |
|---|---|
| `Super+D` | App launcher |
| `Super+S` | Control Center (settings) |
| `Super+A` | App drawer |
| `Super+Enter` | Terminal |
| `Super+Shift+/` | Keybinding cheat sheet |

The Control Center (`Super+S`) covers WiFi, Bluetooth, audio, displays,
themes, updates and power, with more under **More**, including:

- **Desktop & UI → Font Rendering** — hinting and subpixel toggles
  (defaults: medium hinting, RGB subpixel)
- **Software → Graphics Drivers** — switch Mesa between Debian stable and
  trixie-backports for newer GPU drivers
- **Drives** — USB automount, a Windows-style repair offer for drives with
  filesystem errors, safe eject, and formatting a USB drive back into one
  partition (Drive Doctor)
- security profiles, performance tweaks, containers and self-hosting
  templates, backups

11 themes ship in-tree (glass — the default — cyber, dracula, everforest,
gruvbox, material, nord, paper, rose-pine, solid, tokyo-night), each with
matching wallpaper, bar, notification, lock screen and terminal colours.

## Structure

```
bootstrap.sh        # Mode picker (desktop / server) used by install.sh
install.sh          # Remote installer (curl | bash)
tebian.conf         # Per-machine manifest applied by tebian-rebuild
scripts/            # Control Center, menus, installer, ISO builder, tools
configs/            # sway, kitty, mako, greetd, udev rules, themes
modules/            # core/ (security), hw/ (x86, pi)
config/             # live-build inputs (boot menu, templates)
assets/             # wallpapers, plymouth splash
```

## Building the ISO

On a Debian 13 machine with Podman, from the directory that contains
`tebian-os/`:

```bash
./build.sh --release   # container build of the committed tree
```

or directly on a Debian host: `bash tebian-os/scripts/build-iso.sh --release`.
`--release` builds only committed files (`git archive HEAD`) and records the
commit in `/etc/tebian-release`; without it the working tree ships as-is,
which is meant for development. A `.sha256` file is written next to the ISO.
Test boots: `bash tebian-os/scripts/test-vm.sh --boot-only` (add `--bios` or
`--secureboot`).

## Uninstall

`bash ~/Tebian/scripts/uninstall.sh` removes Tebian's scripts and configs
and, asking before each step, reverts the system changes it made.

## Manifesto

See [MANIFESTO.md](./MANIFESTO.md).
