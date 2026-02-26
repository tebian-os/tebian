# TEBIAN ARCHITECTURE

> "Linux is to Debian as Debian is to Tebian."

---

## The Core Concept

Tebian is not a distro. It's a usability layer on top of Debian.

```
┌─────────────────────────────────────┐
│  Tebian    (you see this)           │  1 folder, 1 script
├─────────────────────────────────────┤
│  Debian    (the foundation)         │  50,000 packages, stability
├─────────────────────────────────────┤
│  Linux     (the kernel)             │  Hardware abstraction
└─────────────────────────────────────┘
```

Each layer removes one level of complexity:
- Linux: "Here's a kernel, good luck"
- Debian: "Here's a system, figure out the DE"
- Tebian: "Here's a desktop, use it"

---

## What Tebian Actually Is

```
Debian ISO
    +
Tebian/ folder (in $HOME)
    ├── bootstrap.sh        # Main entry point
    ├── desktop.sh          # Called by bootstrap for GUI install
    ├── configs/            # Symlinked to ~/.config/
    ├── scripts/            # Copied to ~/.local/bin/
    └── assets/             # Wallpapers, etc.
```

That's it. Debian plus one folder.

### The Entire "Distro"

```
Tebian/
├── VERSION              # Current version (e.g., 3.0.1)
├── bootstrap.sh         # Main entry point, asks Desktop? [1/2]
├── desktop.sh           # Installs GUI stack + configs
├── uninstall.sh         # Reverts to pure Debian
├── build-iso.sh         # Creates bootable ISO
├── configs/
│   ├── sway/config      # Main sway config (includes theme)
│   ├── sway/config.user # User customizations (preserved)
│   ├── kitty/
│   └── themes/          # glass, solid, cyber, paper
│       └── glass/
│           ├── sway-theme    # Included by sway
│           ├── kitty.conf
│           ├── fuzzel.ini
│           ├── mako
│           └── gtklock
├── scripts/             # Copied to ~/.local/bin/
│   ├── tebian-common    # Shared functions
│   ├── tebian-version   # Version checker
│   ├── tebian-settings  # Settings hub
│   ├── tebian-menu      # App launcher
│   ├── tebian-theme     # Theme switcher
│   ├── tebian-welcome   # First-run welcome
│   ├── status.sh        # Waybar alternative
│   └── update-all       # System updater
└── assets/
    └── wallpapers/
```

**No:**
- Custom kernel
- Forked packages
- Repo
- Patches
- Branding bloat

**Yes:**
- Debian
- One folder
- One script

---

## The Bootstrap Script

On first boot (or manual run), the user sees:

```
  ████████╗███████╗██████╗ ███╗   ██╗
  ╚══██╔══╝██╔════╝██╔══██╗████╗  ██║
     ██║   █████╗  ██████╔╝██╔██╗ ██║
     ██║   ██╔══╝  ██╔══██╗██║╚██╗██║
     ██║   ███████╗██║  ██║██║ ╚████║
     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝

  [1] Tebian Desktop (Sway + Wayland)
  [2] Tebian Server (Headless / Base Debian)

  Select edition [1/2]: 
```

**Option 1** runs `desktop.sh` → installs 3 packages + configs → first boot onboarding
**Option 2** deletes Tebian folder → leaves pure Debian

---

## The Desktop Script (Minimal)

```bash
#!/bin/bash
# desktop.sh - Installs minimal Tebian desktop

# Base install: 3 packages only
apt update
apt install -y sway fuzzel network-manager

# Copy configs to ~/.config/
# Copy scripts to ~/.local/bin/

# Done. First boot onboarding handles the rest.
```

### First Boot Onboarding

After first login to Sway, fuzzel opens:

```
┌─────────────────────────────────────┐
│  Welcome to Tebian                  │
│                                     │
│  Base (Minimal)                     │
│     Just sway + fuzzel.             │
│     You configure everything.       │
│                                     │
│  Desktop (Familiar)                 │
│     Adds: file manager, clipboard,  │
│     notifications, screenshots,     │
│     screen lock, floating windows   │
│                                     │
└─────────────────────────────────────┘
```

### Install Essentials Menu

Any time via fuzzel → Install Essentials:

```
Install All Essentials (Recommended)
─────────────────────────────────
Terminal (kitty)
File Manager (pcmanfm)
Notifications (mako)
Clipboard Manager (wl-clipboard, cliphist)
Screenshot Tools (grim, slurp)
Screen Lock (gtklock, swayidle)
Volume OSD (wob)
Brightness Control (brightnessctl)
Auto-tiling
```

echo "Done. Run 'sway' to launch."
```

---

## Package Philosophy

### Required (always installed)

| Package | Size | Why |
|---------|------|-----|
| **sway** | ~8MB | Window manager / compositor (required) |
| **fuzzel** | ~300KB | App launcher + settings menu (required) |
| **network-manager** | ~8MB | WiFi/network management (required for UX) |

**Total: ~16MB**

### Optional (via first boot onboarding or fuzzel menu)

| Package | Size | Why |
|---------|------|-----|
| kitty | ~5MB | GPU-accelerated terminal |
| pcmanfm | ~1MB | File manager |
| mako | ~50KB | Notification daemon |
| wl-clipboard + cliphist | ~200KB | Clipboard history |
| grim + slurp | ~200KB | Screenshots |
| gtklock + swayidle | ~200KB | Screen lock and auto-lock |
| wob | ~50KB | Volume/brightness OSD |
| brightnessctl | ~50KB | Brightness control for laptops |
| autotiling | ~10KB | Auto-arrange windows |

**All optional: ~7MB**

---

## Fonts & Icons

### Icons in Menus

Tebian uses Nerd Font icons in menus (󰖩 󰂯 🎨 etc).

**Without Nerd Fonts:** Icons appear as boxes (□□□) but menus still work.

### How to Get Icons

Option 1: Install Nerd Fonts
```
fuzzel → Install Essentials → (fonts included in Desktop mode)
```

Option 2: Use emoji icons (work without extra fonts)
```
📶 WiFi
📻 Bluetooth
🎨 Themes
```

Option 3: Text only
```
WiFi Setup
Bluetooth Manager
Themes & Styles
```

### Included in Desktop Mode

When user selects "Desktop" at first boot or installs essentials:
- JetBrains Mono Nerd Font (terminal + code)
- Noto fonts (emoji, symbols)

---

## Why This Approach

### Why mako is now optional

Previously, we said mako was required. But:
- Scripts work without notifications (just no popup)
- User might not care about visual feedback
- 50KB, but still a choice

Now: Install if you want notifications.

### Why no default terminal

Terminals are personal:
- kitty: GPU-accelerated, features
- foot: Minimal, fast
- alacritty: Rust, modern

Many users never use terminal. No forced defaults.

**Think about your setup:**
- If you run lots of background apps (Discord, Steam, Dropbox), a tray helps
- If you mostly use terminal and tiling windows, the built-in bar is cleaner
- More panels = more resources = more complexity

### Stable vs Rolling Branch

Tebian ships on Debian Stable (Bookworm) by default. Power users can switch to Rolling via fuzzel.

| Branch | Updates | Stability | Best For |
|--------|---------|-----------|----------|
| **Stable** | Every ~2 years | Rock solid | Servers, production, low maintenance |
| **Rolling** | Continuous | Mostly stable | Desktop power users, latest software |

**How it works:**
- Default: Stable (Bookworm)
- Via fuzzel (Performance menu): One click to join Rolling
- Servers: Stay on Stable forever unless manually upgraded

**Rolling = Debian Testing:**
- Uses `testing` in sources.list (currently Trixie/Debian 13)
- When Trixie becomes Stable → `testing` auto-points to Debian 14
- When Debian 14 becomes Stable → `testing` auto-points to Debian 15
- **You auto-upgrade major versions forever. No manual intervention.**

**Why Testing instead of Unstable (Sid)?**
- `testing`: Brief freeze before each release → more stable
- `unstable`/`sid`: Never freezes → packages land immediately → more breakage
- Tebian uses Testing for the balance of new + stable

**Stable servers:**
- Stay on their release (Bookworm → Trixie requires manual upgrade)
- Get security updates for ~1 year after new Stable releases
- Won't auto-upgrade to next Stable

---

## Why This Beats Other Distros

*Note: The below describes the vision. Current implementation covers core desktop (Sway, themes, settings). Software stacks and DE switching are planned.*

### The Problem with Choice

**Debian's installer:**

```
Language?
Location?
Keyboard?
Hostname?
Domain?
Root password?
User name?
User password?
Partitioning method?
Partition disks?
...
Choose desktop environment:
  [ ] GNOME
  [ ] XFCE
  [ ] KDE
  [ ] LXDE
  [ ] MATE
  [ ] Cinnamon
  ...
```

20+ questions. Confusing. Bloated options.

**Tebian's installer:**

```
Tebian Desktop? [Y/n]
```

Done.

### Comparison

| Distro | Base | What they add |
|--------|------|---------------|
| Ubuntu | Debian | Snap, GNOME patches, own repos, Canonical branding |
| Mint | Ubuntu | Cinnamon, more repos, more tools |
| Pop!_OS | Ubuntu | GNOME mods, tiling extension, Nvidia ISOs, repos |
| Manjaro | Arch | Held-back packages, own repos, multiple DE ISOs |
| **Tebian** | Debian | **One folder, one script** |

### What You Eliminate

```
❌ 30+ ISO choices
❌ DE paralysis
❌ Wrong choice = reinstall
❌ Bloat from picking wrong DE
❌ Server users getting desktop files
❌ Desktop users getting server packages
```

### What You Provide

```
✓ 4 downloads (one per architecture)
✓ 1 question (desktop?)
✓ Sane default
✓ Change mind later (fuzzel)
✓ No penalty for picking "wrong"
✓ Pure Debian underneath
```

---

## Minimum Viable Desktop

### The Stack (All C, Minimal)

| Component | Job | Binary | Required? |
|-----------|-----|--------|-----------|
| Sway | Compositor, manages windows | 1 binary | Yes |
| fuzzel | App launcher + settings | 1 binary | Yes |
| mako | Notifications | 1 binary | Yes |
| kitty | Terminal | 1 binary | Optional |
| wob | Volume/brightness OSD | 1 binary | Optional |

No D-Bus soup. No JavaScript. No Python. Just C binaries + bash scripts.

### Required vs Optional

```
Required:
  - Sway (compositor, invisible)
  - fuzzel (launcher, how you do anything)
  - mako (notifications, apps expect this)
  
Optional (install via fuzzel):
  - kitty, foot, alacritty (terminals)
  - wob (volume/brightness overlay)
  - Browser, file manager, etc.
```

---

## Server vs Desktop

### Server Mode

```
Boot → bootstrap.sh → User picks [2] Server
  ↓
rm -rf /opt/tebian
  ↓
Result: Pure Debian. Zero Tebian footprint.
```

Server users get **straight Tebian** - which is just Debian.
No desktop packages. No configs. No scripts. Clean.

### Desktop Mode

```
Boot → bootstrap.sh → User picks [1] Desktop
  ↓
desktop.sh installs packages + links configs
  ↓
Result: Debian + /opt/tebian/ folder
```

Desktop users keep `/opt/tebian/` because configs symlink to it.

---

## Un-Tebian

Desktop users can revert to pure Debian anytime:

```bash
~/Tebian/uninstall.sh
```

This removes configs and scripts. Optionally removes packages. Leaves the Tebian folder in place (delete manually if desired).

Manual removal:
```bash
# Remove configs
rm -rf ~/.config/sway ~/.config/kitty ~/.config/fuzzel ~/.config/mako ~/.config/gtklock

# Remove scripts
rm -f ~/.local/bin/tebian-* ~/.local/bin/status.sh ~/.local/bin/update-all

# Remove desktop packages (optional)
sudo apt remove sway fuzzel kitty mako grim slurp wl-clipboard cliphist \
    swaybg swayidle gtklock brightnessctl autotiling wob
```

Result: Back to pure Debian. No Tebian traces.

---

## Fuzzel: The Universal Interface

Through `tebian-settings`, users access configuration menus.

### Current Implementation Status

**Working Now:**
| Menu | Status |
|------|--------|
| System Update | ✓ `update-all` script |
| WiFi Setup | ✓ `nmtui` wrapper |
| Bluetooth Manager | ✓ `bluetuith` |
| Audio Mixer | ✓ `pulsemixer` |
| Themes & Styles | ✓ 4 themes (glass/solid/cyber/paper) |
| Power Menu | ✓ Suspend/Reboot/Shutdown |
| Desktop & UI | ✓ Floating/Tiling toggle |

**Planned (Roadmap):**
| Menu | Planned Feature |
|------|-----------------|
| T-Link | Fleet mesh (Tailscale/Headscale) |
| Security & Firewall | ufw, fail2ban, auditd |
| Software & Gaming | One-click stack installers |
| Performance & Tools | btop, monitoring |
| Containers | Podman/Docker/Distrobox |
| Virtualization | KVM/QEMU, macOS/Windows VMs |

### Build Your Rig (Planned)

```
┌─────────────────────────────────────────┐
│  Build Your Rig                          │
│  ─────────────────────────────────────  │
│  🎮 Gaming Mode                          │
│     Steam, GameMode, MangoHud, Vulkan    │
│                                         │
│  🔒 Security Mode                        │
│     Kali tools, Parrot apps, hardening   │
│                                         │
│  💻 Dev Mode                             │
│     Rust, Go, Node, Docker, VS Code      │
│                                         │
│  🖥️ Media Mode                           │
│     Plex, OBS, Kdenlive, audio tools     │
│                                         │
│  🏢 Office Mode                          │
│     LibreOffice, Zoom, email clients     │
│                                         │
│  🎨 Creative Mode                        │
│     GIMP, Inkscape, Blender, Krita       │
│                                         │
│  ⬜ Reset to Base                        │
│     Remove all, back to minimal          │
└─────────────────────────────────────────┘
```

### Swap Desktop Environment (Planned)

```
┌─────────────────────────────────────┐
│  Desktop Environment                │
│  ─────────────────────────────────  │
│  ○ Sway (Current)                   │
│  ○ Hyprland (Animated, fancy)       │
│  ○ Wayfire (Compiz-like effects)    │
│  ○ River (Dynamic tagging)          │
│  ○ GNOME (Classic desktop)          │
└─────────────────────────────────────┘
```

### Swap Terminal (Planned)

```
┌─────────────────────────────────────┐
│  Terminal                           │
│  ─────────────────────────────────  │
│  ○ kitty (Current - GPU)            │
│  ○ foot (Lightweight, fast)         │
│  ○ alacritty (GPU, Rust)            │
│  ○ gnome-terminal (Traditional)     │
└─────────────────────────────────────┘
```

**One ISO. Infinite distros.**

*(Note: DE/terminal switching is planned. Currently Sway + kitty only.)*

---

## The Downloads

### Current Debian Downloads

```
debian-12.5.0-amd64-netinst.iso
debian-12.5.0-amd64-DVD-1.iso
debian-live-12.5.0-amd64-gnome.iso
debian-live-12.5.0-amd64-kde.iso
debian-live-12.5.0-amd64-xfce.iso
... (30+ ISOs)
```

### Tebian Downloads

```
tebian-amd64-YYYYMMDD.iso       (PC/Mac - x86_64)
tebian-arm64-YYYYMMDD.iso       (ARM servers/VMs)
tebian-pi-arm64-YYYYMMDD.img    (Raspberry Pi 4/5)
tebian-pi-armhf-YYYYMMDD.img    (Raspberry Pi 3/Zero 2)
```

**Build them yourself:**
```bash
./Tebian/build-iso.sh pc       # PC ISO
./Tebian/build-iso.sh arm64    # ARM64 ISO
./Tebian/build-iso.sh pi       # Pi 4/5 image
./Tebian/build-iso.sh pi32     # Pi 3/Zero 2 image
./Tebian/build-iso.sh mobian   # Mobian image (PinePhone/Librem)
./Tebian/build-iso.sh droidian # Droidian installer (Pixel/etc)
./Tebian/build-iso.sh all      # Build everything
```
tebian-arm64.iso     (ARM servers/VMs)
tebian-mobian.img    (PinePhone, Librem 5, PineTab)
tebian-droidian.zip  (Pixel, OnePlus, Xiaomi, Samsung)
```

**Mobile platforms:**
- **Mobian:** Native Linux on open hardware (Pine64, Purism)
- **Droidian:** Linux on Android phones via Halium layer

**4 files. That's it.**

---

## Zero Maintenance

### Traditional Distro Maintenance

```
Ubuntu:
  - Build 30,000 packages
  - Mirror them
  - Security patches
  - Sync with upstream
  - Fix breakage
  - Release every 6 months
  = Full-time team required
```

### Tebian Maintenance

```
Tebian:
  - Did bootstrap.sh break? No?
  - Done.
```

**Why:**

```
Your ISO installs:
  sway → apt pulls from Debian
  fuzzel → apt pulls from Debian
  kitty → apt pulls from Debian
  
All updates come from Debian.
You do nothing.
```

Your ISO could be 2 years old:

```
User boots → connects to WiFi → apt update && apt upgrade
→ Now running latest everything
```

### Maintenance Burden

```
Debian: Maintains 50,000 packages
You:    Maintain 1 script + 10 configs

Debian: Security team, mirrors, build servers
You:    A GitHub repo
```

---

## File Structure for ISO Build

```
tebian-iso/
├── config/
│   ├── package-lists/
│   │   └── base.list          # Core packages (both editions)
│   └── includes.chroot/
│       └── opt/
│           └── tebian/
│               ├── bootstrap.sh       # Main installer prompt
│               ├── desktop.sh         # GUI stack installer
│               ├── configs/           # All dotfiles
│               │   ├── sway/
│               │   ├── kitty/
│               │   ├── fuzzel/
│               │   ├── mako/
│               │   └── gtklock/
│               └── scripts/           # ~/local/bin tools
│                   ├── t-fetch
│                   ├── tebian-settings
│                   ├── tebian-menu
│                   ├── status.sh
│                   └── update-all
```

### base.list (minimal shared packages)

```
linux-image-amd64
firmware-linux
firmware-iwlwifi
firmware-misc-nonfree
bash-completion
sudo
nano
curl
wget
git
htop
```

### Build It

```bash
# Install live-build
sudo apt install live-build

# Create project
mkdir tebian-build && cd tebian-build
lb config

# Add your files to config/includes.chroot/
# Run:
sudo lb build
```

---

## The Website

```
┌─────────────────────────────────────────┐
│                                         │
│              TEBIAN                     │
│         The only option.                │
│                                         │
│   ┌─────────────┐  ┌─────────────┐     │
│   │  PC (x86)   │  │  Raspberry  │     │
│   │  Download   │  │  Download   │     │
│   └─────────────┘  └─────────────┘     │
│                                         │
│   ┌─────────────┐  ┌─────────────┐     │
│   │ ARM64/VM    │  │   Phone     │     │
│   │  Download   │  │  Download   │     │
│   └─────────────┘  └─────────────┘     │
│                                         │
│   Server or Desktop. You decide.        │
│   Everything else: fuzzel.              │
│                                         │
└─────────────────────────────────────────┘
```

---

## The Philosophy

### Not Opinionated. The Only Needed Option.

| Approach | What it is |
|----------|------------|
| GNOME forced on you | Opinionated - bloated, can't opt out |
| Arch (DIY everything) | Not opinionated - but overwhelming |
| Ubuntu (snaps pushed) | Opinionated - corporate agenda |
| **Tebian** | **Defaults, but removable** |

Sane starting point, not a locked cage.

### The Law of Zero (from MANIFESTO)

- Zero bloat
- Zero telemetry
- Zero friction
- Zero maintenance (for you)

### User Respect

```
Tebian: "Here's a desktop that works."
Tebian: "Want to change it? Here's fuzzel."
Tebian: "Want server? Say no, get pure Debian."
Tebian: "Your system, your choice."
```

---

## Summary

**Tebian is:**
- Debian + one folder + one script
- One question, not twenty
- Sane defaults, modular everything
- Zero maintenance
- The last distro anyone needs

**Tebian is not:**
- A fork
- A repo
- A corporate product
- Opinionated beyond "here's something that works"

**The tagline:**

> "Debian. Your way."

Or:

> "The only option."

---

*Architecture: Tyler (Tebian)*
*Updated: Feb 19, 2026*
*Version: 3.0.2*
