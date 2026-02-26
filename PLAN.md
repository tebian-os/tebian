# TEBIAN DEVELOPMENT PLAN (v3.0)

## The Core Philosophy
**"Arch flexibility, Debian stability, Sovereign power."**
We reject the fragility of rolling releases. We reject the bloat of corporate distros. We build a fortress.

---

## 1. The Fleet (Product Line)

| Variant | Role | Base | Build Target |
| :--- | :--- | :--- | :--- |
| **Tebian** | The Desktop Flagship | Debian 13 (Trixie) | **x86_64 ISO** (PC/Mac) |
| **Tebian Core** | The Server / Infrastructure | Debian Stable (Min) | **x86_64 ISO** (VPS) <br> **ARM64 ISO** (AWS/VMs) |
| **Tebian Pi** | The Maker / IoT | RPi OS Lite | **ARM64 IMG** (Pi 4/5) |
| **Tebian Mobile**| The Communicator | Mobian / Droidian | **Mobian IMG** / **Droidian Installer** |

**Mobile Support:**
- **Mobian:** Pure Debian mobile - works on Librem 5, PinePhone, PineTab
- **Droidian:** Android-phone friendly - works on Pixel, OnePlus, Xiaomi, Samsung
- Both share the same Tebian configs, themes, and dotfiles via T-Sync

**Unified Strategy:**
- **T-Link:** All nodes connected via Wireguard mesh/Tailscale.
- **T-Sync:** Configs synced via private git (`~/.config` is portable).
- **T-Push:** One command updates the entire fleet.

---

## Phase 1: Critical Infrastructure (The Foundation)
- [ ] **Memory:** `zram-tools` (zstd) + `vm.swappiness=10`.
- [ ] **Security:** `ufw` (Deny Incoming) + `fail2ban`.
- [ ] **Snapshots:** `timeshift` (The "Undo" button).
- [ ] **Base UI:** Sway + Wayland + WOB (Feedback) + Fuzzel.

## Phase 2: The Meta-Layer (Compatibility)
**"The OS that runs other OSs."**

### 2.1 `t-mac` (The iOS Dev Box)
- **Goal:** One-click macOS VM setup for Xcode/App Store access.
- **Tech:** Docker-OSX / OSX-KVM.
- **Features:** USB passthrough (iPhone), Shared Folders, iCloud valid.

### 2.2 `t-win` (The Dual-Boot Guardian)
- **Goal:** Safe, guided Windows partitioning for Anti-Cheat games.
- **Tech:** `os-prober` + `grub-customizer` logic.

### 2.3 `t-droid` (Android Runtime)
- **Goal:** Run Android apps seamlessly on Desktop/Mobile.
- **Tech:** Waydroid (Containerized Android).

---

## Phase 3: The Setup Experience
### 3.1 `tebian-welcome` (First Breath)
- Minimal terminal greeting.
- "Ghost Mode" instruction.
- Links to `tebian-settings`.

### 3.2 `tebian-settings` (The Hub)
- **Software:** Flatpak, Distrobox (AUR), Nix.
- **Gaming:** GameMode, Vulkan, Steam.
- **Network:** T-Link (Tailscale/Headscale).
- **Virtualization:** Mac/Win VM wizards.

---

## Phase 4: The Sovereign Cloud (Self-Hosting)
### 4.1 The "Mothership" Stack
A `docker-compose` stack for your **Tebian Core** server:
- **Sync:** Syncthing (Files).
- **Pass:** Vaultwarden (Passwords).
- **Chat:** Matrix/Synapse.
- **VPN:** Headscale (Tailscale control).

---

## Phase 5: The UI Engine
### 5.1 Default: "Stealth Glass"
- **Behavior:** Bar hidden (Hold Super). Windows tiled.
- **Feedback:** WOB overlay for volume/brightness.
- **Aesthetic:** Transparent, Blur, Keyboard-centric.

### 5.2 The Theme Engine
- **Goal:** Allow users to switch vibes instantly via Settings.
- **Themes:**
    - **Glass:** (Default) Transparent, Minimal.
    - **Solid:** High contrast, visible bar (Business/Accessiblity).
    - **Cyber:** Neon outlines, heavy bloom (Gamer).
    - **Paper:** Light mode, flat colors (Writer).

---

## Phase 6: Local Intelligence (AI)
- **Tool:** `t-ask` (CLI Assistant).
- **Engine:** Ollama (Llama 3 / Mistral).
- **Privacy:** 100% Local. No API keys. No data leaving.

---

## Phase 7: Tebian Vision (Spatial Computing)
**"The Infinite Workspace."**

### 7.1 Desktop Vision (VR/XR)
- **Goal:** True spatial tiling window management.
- **Stack:** SimulaVR (Haskell-based VR WM) + Monado (OpenXR).
- **Hardware:** Quest 2/3 (via ALVR), Valve Index (Native).

### 7.2 Mobile Vision (AR Cyberdeck)
- **Goal:** Pocketable multi-monitor setup.
- **Hardware:** XREAL Air / Rokid Max (USB-C Glasses).
- **Stack:** `xr-hardware` + custom 3DOF driver integration.
- **Experience:** Phone = Keyboard. Glasses = Monitor.

---

## Phase 8: Tebian Mobile
**"The phone that respects you."**

### 8.1 Supported Platforms
| Platform | Base | Target Devices | Install Method |
| :--- | :--- | :--- | :--- |
| **Mobian** | Debian Mobile | Librem 5, PinePhone, PineTab | SD Card / eMMC image |
| **Droidian** | Debian + Halium | Pixel 3/4/5/6, OnePlus, Xiaomi, Samsung | Installer (fastboot) |

### 8.2 Mobian (Freedom Hardware)
- **Best for:** Purism Librem 5, Pine64 devices
- **Pure Linux:** No Android layers, native drivers
- **Phosh:** GNOME-style mobile shell
- **Apps:** All native Debian + Flatpak mobile apps

### 8.3 Droidian (Mainstream Phones)
- **Best for:** Converting Android phones to Linux
- **Halium layer:** Uses Android drivers via libhybris
- **Supported:** Pixel (best), OnePlus (good), others (varies)
- **Install:** `tebian-mobile-install` detects device, flashes Droidian

### 8.4 Shared Tebian Features
Both platforms get:
- T-Link mesh connectivity to your fleet
- T-Sync dotfiles from your desktop
- Sway/Phosh theme matching
- Waydroid for Android app compatibility
- Terminal-first workflow

---

## Why Tebian Wins
| Feature | Arch | Fedora | Tebian |
| :--- | :--- | :--- | :--- |
| **Stability** | ❌ Breaks often | ✅ Stable | ✅ **Debian Stable** |
| **Packages** | ✅ AUR | ✅ RPM Fusion | ✅ **Backports + Nix + Flatpak** |
| **Vibe** | ❌ Elitist | ❌ Corporate | ✅ **Sovereign / Underground** |
| **Ecosystem**| ❌ DIY | ❌ None | ✅ **Unified Fleet (PC+Pi+Phone)** |
| **MacOS** | ❌ Manual | ❌ Manual | ✅ **`t-mac` One-Click** |
