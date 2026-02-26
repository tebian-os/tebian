# HONORARY SURVIVORS

> Distros Tebian doesn't kill - and why.

---

## The Line

```
Survives:  Different base, paradigm, or purpose
Dies:      Same base, different packages/config
```

Tebian kills fragmentation, not innovation.

---

## Final Survivors (9)

### Anonymity & Security (Structural)

| Distro | Why it survives |
|--------|-----------------|
| **Tails** | Amnesic, RAM-only, Tor at kernel level, designed to leave zero trace. Not packages - a completely different threat model. |
| **Qubes** | Security through isolation. Xen hypervisor, every app in its own VM. Can't replicate with packages. |
| **Whonix** | Two-VM architecture (Gateway + Workstation). Tor is the network, not an add-on. |

### Different Paradigm

| Distro | Why it survives |
|--------|-----------------|
| **Gentoo** | Source-based. You compile everything with USE flags for your exact hardware. Not binary packages. |

### Different Base / Special Purpose

| Distro | Why it survives |
|--------|-----------------|
| **Alpine** | musl (not glibc), busybox (not coreutils), OpenRC (not systemd). ~5MB container base. Security-first. Container standard. |
| **Tiny Core** | 16MB, bootable, GUI included. Smallest usable Linux. For embedded, recovery, extreme minimal. |
| **Puppy Linux** | RAM-based (~300MB), runs from USB, saves to single file. Best for ancient hardware. User-friendly. No installation needed. |

### Independent Operating Systems (Not Linux)

| Distro | Why it survives |
|--------|-----------------|
| **TempleOS** | Not Linux. Own kernel, own compiler (HolyC), own paradigm. 640x480, 16-color. Created by Terry Davis. Designed as "God's temple." Completely unique. |

### Size Comparison (Old Hardware / Minimal)

| Distro | Size | Runs in RAM | Purpose |
|--------|------|-------------|---------|
| Alpine | 5MB (container) / 50MB+ (bootable) | Optional | Servers, containers, musl |
| Tiny Core | 16MB | Yes | Extreme minimal, embedded |
| Puppy | ~300MB | Yes | Old hardware, user-friendly |

All three survive because they serve different niches. None beats the others.

---

## What Actually Dies

### Debian/Ubuntu Spins (~100+ distros)

```
Ubuntu, Mint, Pop!_OS, Elementary, Zorin, KDE Neon, LXLE, Bodhi, etc.
→ Same base, just packages + theme
```

### Arch-Based (~20+ distros)

```
Manjaro, Endeavour, Garuda, Arco, Artix, Parabola, etc.
→ Same base, just packages + installer
→ Fragile rolling release
```

### Security "Distros"

```
Kali, Parrot, BlackArch
→ Just tools. apt install works fine.
→ fuzzel menu option
```

### Gaming "Distros"

```
Pop!_OS, Nobara
→ Just gaming stack.
→ fuzzel menu: Install Gaming Mode
```

### Generic Desktop

```
MX, Solus, Deepin, China OS, etc.
→ Just DE variations.
```

### Immutable "Distros"

```
Fedora Silverblue, openSUSE MicroOS, Flatcar, Endless OS
→ Just OSTree/Btrfs + containers.
→ fuzzel menu: Enable Immutable Mode / System Snapshots
```

### Declarative "Distros"

```
NixOS, Guix
→ Declarative hell. Not FHS compliant. Too academic.
→ Use nix package manager on Tebian instead.
```

### Enterprise "Distros"

```
RHEL, Rocky, Alma, CentOS
→ Enterprise distros sell liability, not technology. We stick to the source.
→ fuzzel menu: Enterprise Hardening (ufw + fail2ban + audit)
```

### Independent But Same Philosophy

```
Void
→ Minimal + runit = Tebian with init choice.
→ fuzzel menu: Switch to runit / OpenRC

Devuan
→ Debian without systemd = Tebian with init choice.
```

### Meta-Distros

```
Bedrock Linux
→ Merges multiple package managers.
→ Tebian already has: apt + flatpak + nix + distrobox.
→ Problem solved. No need for Bedrock.
```

### Niche / Zombie Distros

```
Slackware
→ Oldest surviving, but barely used (~10k users).
→ Nostalgia project at this point.

SliTaz
→ 30MB, but Tiny Core is smaller, Puppy is more usable.
→ No real advantage. Middle ground with no purpose.
```

---

## What Tebian Covers (via fuzzel)

Everything below is a menu option, not a separate distro:

### Desktop Environment

| Want | fuzzel Menu Option |
|------|-------------------|
| Sway (default) | Already installed |
| Hyprland | Switch Desktop → Install Hyprland |
| Wayfire | Switch Desktop → Install Wayfire |
| GNOME | Switch Desktop → Install GNOME |
| XFCE | Switch Desktop → Install XFCE |

### Terminal

| Want | fuzzel Menu Option |
|------|-------------------|
| kitty (default) | Already installed |
| foot | Switch Terminal → Install foot |
| alacritty | Switch Terminal → Install alacritty |
| gnome-terminal | Switch Terminal → Install gnome-terminal |

### System Mode

| Want | fuzzel Menu Option |
|------|-------------------|
| Standard | Default |
| Immutable / Snapshots | Enable System Snapshots (Btrfs/Timeshift) |
| Enterprise Hardening | Enable Hardening (ufw + fail2ban + audit) |

### Software Stack

| Want | fuzzel Menu Option |
|------|-------------------|
| Gaming | Gaming Mode → Install steam gamemode mangohud gamescope vulkan |
| Security / Hacking | Security Mode → Install nmap metasploit burpsuite wireshark |
| Development | Dev Mode → Install rust golang nodejs docker code |
| Creative | Creative Mode → Install gimp inkscape blender krita |
| Office | Office Mode → Install libreoffice thunderbird zoom |
| Media | Media Mode → Install plex obs kdenlive audacity |
| Containers | Container Mode → Install podman docker kubernetes |

### Package Sources

| Want | fuzzel Menu Option |
|------|-------------------|
| apt (Debian) | Already available |
| Flatpak | Install Flatpak + Flathub |
| Nix | Install Nix Package Manager |
| Distrobox (AUR) | Install Distrobox + Podman |
| Alpine (containers) | Containers → Install Alpine |

### Virtualization

| Want | fuzzel Menu Option |
|------|-------------------|
| macOS VM | Virtualization → Setup macOS (OSX-KVM) |
| Windows VM | Virtualization → Setup Windows 11 |
| General VMs | Install KVM/QEMU + virt-manager |

### Networking

| Want | fuzzel Menu Option |
|------|-------------------|
| Fleet / VPN | T-Link → Install Tailscale / Connect to Headscale |
| WiFi | WiFi Setup → Scan and connect |

### Optional Downloads

| Want | fuzzel Menu Option |
|------|-------------------|
| Offline Education Pack | Download Wikipedia + Khan Academy + Encyclopedia (~3GB) |

---

## For The Website

A small section at the bottom:

```
┌─────────────────────────────────────────────────────┐
│              HONORARY SURVIVORS                      │
│                                                     │
│  We don't kill these. They earned their place.      │
│                                                     │
│  ANONYMITY                                          │
│  Tails • Qubes • Whonix                             │
│                                                     │
│  PARADIGM                                           │
│  Gentoo                                             │
│                                                     │
│  DIFFERENT BASE                                     │
│  Alpine • Tiny Core • Puppy                         │
│                                                     │
│  INDEPENDENT (Not Linux)                            │
│  TempleOS                                           │
│                                                     │
│  ─────────────────────────────────────────────────  │
│                                                     │
│  Everything else? Just Debian with extra steps.     │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## The Rule

> If `apt install` + config could make it, it dies.
>
> Survivors need:
> - Different base (musl, 16MB, non-Debian)
> - Different architecture (VM isolation, amnesic)
> - Different paradigm (source-based)
> - Different purpose (extreme minimal, old hardware)

---

## Summary

```
Survives:  9 (8 Linux + TempleOS)
Dies:      ~200+ distros
```

Tebian doesn't kill innovation. It kills redundancy.

---

## Not So Honorable

macOS and Windows aren't distros — but Tebian kills them too.

| OS | How Tebian kills it |
|----|---------------------|
| **macOS** | Need Xcode? Run it in a VM. One-click OSX-KVM setup. USB passthrough, shared folders, iCloud valid. No second machine. No Hackintosh. |
| **Windows** | Anti-cheat games? Proprietary software? Guided dual-boot partitioning. GRUB handles the rest. Not emulation — native when you need it. |

**The message:** Don't switch OS. Make them come to you.

---

*Updated: Feb 18, 2026*
