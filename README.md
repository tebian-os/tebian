# Tebian

A usability layer for Debian. One ISO. One menu. Desktop, server, gaming, or security workstation — all from a single bootable image.

**Website:** [tebian.org](https://tebian.org)
**Current version:** v0.1.0 (Early Release)
**License:** MIT

## Install

### From ISO (new machines)

Download the latest ISO and flash it to a USB drive:

```
https://github.com/tebian-os/tebian/releases/latest/download/tebian-pc.iso
```

Boot, follow the installer, done.

### On existing Debian-based systems

```bash
curl -sL tebian.org/install | bash
```

Works on Debian, Raspberry Pi OS, Armbian, Ubuntu, and any Debian-based distro. Run on Pi OS Lite for ARM boards, or Debian netinst for minimal x86_64 setups.

## What it is

- **Sway + fuzzel** as the sole UI entry point — no desktop icons, no start menu
- **tebian.conf** is the single source of truth — every feature is declaratively defined
- **`tebian-rebuild`** applies the manifest: install a container template, swap the theme, harden the box, toggle a service
- **9 themes** ship in-tree (glass, cyber, nord, dracula, rose-pine, everforest, tokyo-night, paper, solid) with matching wallpapers, mako, swaylock, kitty configs
- **Strips back to headless Debian** — delete the config folder, reboot, you have base Debian server

## Structure

```
bootstrap.sh        # First-boot init
install.sh          # Remote installer
tebian.conf         # System manifest
scripts/            # Menus, settings, launchers (~40 scripts)
configs/            # sway, kitty, greetd, themes
modules/            # core/, hw/ (x86, pi)
config/             # live-build inputs (bootloaders, templates)
assets/             # wallpapers, plymouth splash
```

## Uninstall

If you decide to return to pure Debian, delete `~/.config/tebian/`, remove `~/Tebian/`, and reboot. Full manual procedure is documented at [tebian.org/docs/un-tebian-guide](https://tebian.org/docs/un-tebian-guide).

## Source

Everything is bash. The website is a Neutron app (Preact + Vite, TypeScript). Browse the install script and installer directly at [tebian.org/source](https://tebian.org/source).

## Manifesto

See [MANIFESTO.md](./MANIFESTO.md).
