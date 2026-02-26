# THE TEBIAN MANIFESTO (v3.1)

> "Sovereignty through minimalism. Power through the Fleet."

## 1. The Law of Zero
Performance is not a feature; it is a prerequisite. Tebian rejects "software obesity." If a background process isn't serving the user's immediate goal, it doesn't exist.
**The Law:** Zero bloat. Zero telemetry. Zero friction.

## 2. Stealth Glass UX
The interface is a phantom. It should remain invisible until the moment of action. We prioritize high-performance tiling and "Stealth" aesthetics over desktop metaphors.
**The Law:** The screen belongs to your work, not the OS.

## 3. The Unified Fleet (One Brain, Many Bodies)
A single identity, synced across all nodes. Whether it's a Laptop, a Raspberry Pi, or a Linux Phone, the core philosophy and configuration remain consistent.
**The Law:** Your OS is a fleet, not a machine.

*Current Status: Configs are portable across hardware (Intel/AMD, laptop/desktop). Fleet sync (dotfile syncing across machines) is planned via T-Link.*

## 4. Digital Sovereignty (The Mothership)
You own your data, your secrets, and your infrastructure. Tebian prioritizes local-first workflows and self-hosted cloud sync over third-party dependencies.
**The Law:** If it's on someone else's computer, it isn't yours.

## 5. Local Intelligence (The Private Brain)
AI is a tool for empowerment, not surveillance. Tebian integrates local-only LLMs and tools that work for the user, on the user's hardware, with the user's data.
**The Law:** Intelligence must be private.

## 6. Transparency Over Magic
Every script, every config, and every architectural decision is documented and accessible. If you can't explain why a byte is there, it shouldn't be there.
**The Law:** The user is the root.

---

## Target User: The Digital Sovereign
- The developer who requires a fast, predictable environment.
- The power user who wants a working Wayland desktop without configuring it from scratch.
- The individual who values privacy and local-first computing.
- Anyone who wants a minimal base and adds only what they need.

---

## Current Reality (v3.1)

What Tebian is today:
- **Minimal base**: 3 packages (sway + fuzzel + network-manager)
- **First boot choice**: Base (minimal) or Desktop (familiar)
- **Install Essentials menu**: Add what you want, when you want
- A portable, hardware-agnostic status bar (Intel/AMD, laptop/desktop, Pi)
- A working Sway + Wayland desktop with coordinated theming
- A unified Control Center (16+ categories, fuzzel-based):
  - System Updates (apt + flatpak unified)
  - WiFi with signal strength visualization and on/off toggle
  - Bluetooth with on/off toggle and device management
  - T-Link Fleet Mesh (Tailscale + Headscale self-hosted option)
  - Theme switching (Glass/Solid/Cyber/Paper/Nord/Dracula/etc.)
  - Security hardening toggle (UFW + Fail2Ban)
  - Software & Gaming (Steam, Heroic, Minecraft, PokeMMO, Flatpak, Nix, Distrobox)
  - Performance tuning (ZRAM, GameMode, rolling branch option)
  - Container management (Podman, Docker, Distrobox with Alpine/Arch templates)
  - Virtualization (KVM/QEMU, macOS VM installer, Windows VM)
  - Power, Screenshots, Screen lock with configurable idle

What Tebian is not (yet):
- A multi-device dotfile sync (planned via T-Link)
- Pre-installed anywhere (finders keepers)

---

*Updated: Feb 19, 2026*
*Architecture: Tyler (Tebian)*
*Version: 3.1 - Minimal Release*
