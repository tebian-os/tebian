# Tebian System Map

This document tracks all Tebian-specific scripts, configurations, and organizational changes.

## 1. System Scripts (`~/.local/bin/`)
- **`update-all`**: The master update script (Apt, Rust, Bun, Flatpak).
- **`tebian-settings`**: Fuzzel-based Control Center for WiFi, Power, etc.
- **`t-add`**: Ultra-lean installer (Apt with `--no-install-recommends`).
- **`launcher.sh`**: (Moved from root) Your original launcher script.
- **`status.sh`**: (Moved from root) Your original status script.

## 2. Desktop Integration (`~/.local/share/applications/`)
- **`tebian-settings.desktop`**: Entry for "System Settings".
- **`zen.desktop`**: Custom entry for Zen Browser AppImage.
- **`helium.desktop`**: Custom entry for Helium (with fixed icon).
- **`pcmanfm.desktop`**: Renamed to "Files" (with fixed icon).
- **`kitty.desktop`**: Renamed to "Terminal".
- **`minecraft-launcher.desktop`**: Renamed to "Minecraft".
- **`nvim.desktop`**: Renamed to "Neovim" (launches in Kitty).
- **`com.pokemmo.PokeMMO.Settings.desktop`**: Hidden (NoDisplay=true).
- **`pcmanfm-desktop-pref.desktop`**: Hidden (NoDisplay=true).

## 3. Configuration Modularization
- **`~/.config/sway/config.user`**: The "Shield" file for your personal rice.
- **`~/.bashrc`**: Updated to include `~/.local/bin` in `$PATH`.

## 4. Folder Organization
- **`~/Applications/`**: Hub for Zen and Helium AppImages.
- **`~/Tebian/`**: This project folder (Manifesto, TODO, System Map).
- **`~/Archive/`**: Legacy files like `equivs` and old build artifacts.
- **t-launch**: The Tebian "Smart Start" terminal launcher with workspace selection.
- **tebian-start**: Safe bridge to launch the Sway desktop from the headless terminal.

## 5. Stealth Glass UI Flow (Modern Keybindings)
- **Floating Toggle (`$mod + Space`)**: "Pop" any window out of the grid to float.
- **Floating Modifier (`$mod + Mouse`)**:
    - **Left Click**: Drag and move windows anywhere.
    - **Right Click**: Resize windows dynamically.
- **Resize Mode (`$mod + R`)**: Precision keyboard-based resizing (Arrow keys + Enter).
- **Zero-Fork Status**: High-efficiency, bash-native status bar (Zero overhead).
