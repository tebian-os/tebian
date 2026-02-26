# Tebian V3.1.0 Roadmap

## Completed (v3.1.0)
- [x] **Minimal base install**: sway + fuzzel + network-manager only (3 packages)
- [x] **First boot onboarding**: Base (minimal) vs Desktop (familiar) mode selection
- [x] **Conditional sway config**: Optional features only load if installed
- [x] **Install Essentials menu**: Fuzzel menu to install optional components
- [x] **Fonts & Icons documentation**: Documented in ARCHITECTURE.md
- [x] **Package checks**: Menus check if tools are installed before using
- [x] **Keybind viewer**: `Super+?` or via Settings menu, interactive
- [x] **Bar visibility toggle**: Always on / Super only via Desktop & UI menu
- [x] **Super+L lock screen toggle**: Enable/disable via Screen Lock menu
- [x] **App Preload**: Install/toggle via Performance menu
- [x] **Audio output selector**: Switch sinks via Settings menu
- [x] **System info viewer**: Quick system stats via Settings menu
- [x] **Config backup/restore**: Export and restore configs via Settings menu

## Completed (v3.0.2)
- [x] **Hardware-agnostic status bar**: Auto-detects backlight, GPU (Intel/AMD), WiFi interface, battery, Bluetooth
- [x] **Documentation accuracy**: Keybinding fixes, marked planned features
- [x] **Kitty config**: Fixed duplicate keybindings in all themes
- [x] **Theme switching**: Include-based (no more fragile sed)
- [x] **Portable paths**: All scripts use $HOME or $TEBIAN_DIR
- [x] **Functional bootstrap**: bootstrap.sh + desktop.sh work
- [x] **Touchpad support**: Wildcard `input type:touchpad` works on all laptops
- [x] **Light theme readable**: Fixed bar colors for paper theme
- [x] **Uninstall script**: uninstall.sh for clean removal
- [x] **User config template**: config.user with examples
- [x] **Version system**: tebian-version script
- [x] **Error handling**: tebian-common library with logging
- [x] **Server mode cleanup**: bootstrap.sh option 2 removes Tebian, leaves pure Debian
- [x] **Multi-arch ISO builder**: build-iso.sh supports PC, ARM64, Raspberry Pi

## ISO/Image Targets

| Target | Arch | Output | Use Case |
|--------|------|--------|----------|
| `pc` | amd64 | ISO | PC/Mac |
| `arm64` | arm64 | ISO | ARM servers, VMs |
| `pi` | arm64 | SD image | Pi 4/5 |
| `pi32` | armhf | SD image | Pi 3/Zero 2 |

## Future (v3.2+)
- [ ] Fleet sync via T-Link (Tailscale/Headscale)
- [ ] Software stack installers (gaming, dev, creative)
- [ ] DE switcher (Hyprland, Wayfire, GNOME)

## Hardware Auto-Detection (v3.1.0)
- [x] **Dynamic HiDPI Scaling**: Auto-detect in Desktop mode, manual option in fuzzel
- [x] **Nvidia Support**: Auto-detect in Desktop mode, manual option in fuzzel
- [x] **Laptop Power Profiles**: Auto-detect in Desktop mode (TLP), manual option in fuzzel
- [x] **CPU Microcode**: Auto-detect Intel vs AMD in Desktop mode, manual option in fuzzel

## Core Optimizations
- [x] ZRAM: Configured in desktop.sh
- [x] Kernel swappiness tuning: Included in RAM Boost install
- [x] Preload for frequently used apps: Via Performance menu
