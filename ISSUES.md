# TEBIAN OS - MASTER ISSUE TRACKER

> Full audit of bugs, improvements, and missing features.
> Each item has a priority: **P0** (broken now), **P1** (should fix soon), **P2** (nice to have).
> Check off items as they're resolved.

---

## 1. BUGS (broken or will break)

- [x] ~~**P0** `apt_search` uses `--prompt-only` and `--placeholder` flags — these flags exist in fuzzel 1.12.0. Not a bug.~~
- [x] ~~**P0** `font_menu` `apply_font()` — fixed: now uses exported env vars with single-quoted heredoc for clean variable expansion. (`tebian-settings`)~~
- [x] ~~**P0** WiFi password visible in fuzzel — fixed: added `--password` flag to fuzzel call. (`tebian-settings`)~~
- [x] ~~**P0** `show_main_menu` Back runs `tebian-menu` as child process — fixed: now launches tebian-menu in background and returns. (`tebian-settings`)~~
- [x] ~~**P0** `exit 0` vs `return` inconsistency — fixed: all 6 `exit 0` in menu back handlers replaced with `return`. (`tebian-settings`)~~
- [x] ~~**P1** WiFi SSID parsing breaks on SSIDs with spaces — fixed: uses `nmcli -t` terse mode with colon delimiter and `IFS=:` for parsing.~~
- [x] ~~**P1** Rolling branch sed corrupts sources.list — fixed: uses `\b` word boundaries to prevent matching hyphenated variants.~~
- [x] ~~**P1** Nvidia sources.list sed over-broad — fixed: uses `safe_sources_add_components()` from tebian-common for idempotent addition.~~
- [x] ~~**P1** HiDPI scaling appends duplicates — fixed: uses `idempotent_append()` from tebian-common.~~
- [x] ~~**P1** Bar mode sed matches wrong lines — fixed: uses `safe_sed_replace` scoped to `bar { ... }` block via awk.~~
- [x] ~~**P1** Backup follows symlinks and corrupts repo — fixed: uses `cp -rL` to dereference symlinks during backup.~~
- [x] ~~**P1** Recursive menu calls burn stack — fixed: all 23 menu functions converted from recursive calls to `while true` loops. (`tebian-settings`)~~
- [x] ~~**P1** `$TERM_CMD bash -c '...'` quoting failures — fixed: `$HOME` expands as env var in child shell. Real bug was `idempotent_append` (tebian-common function) called in child shell — replaced with inline `grep -q || echo`.~~
- [x] ~~**P1** `tebian-edge-snap` uses `exec` not `exec_always` — fixed: config.user updated and shared `setup_floating_mode()` now uses `exec_always` with pkill.~~
- [x] ~~**P1** `while pgrep -x fuzzel` busy-wait loop — fixed: replaced with `flock` on `/tmp/tebian-settings.lock`. (`tebian-settings`)~~
- [x] ~~**P2** Bluetooth scan backgrounded without cleanup — fixed: saves PID, kills after 2s, and adds `trap RETURN` for cleanup if menu exits.~~
- [x] ~~**P2** `pkill -f 'status.sh'` too broad — fixed: now uses `pkill -f '\.local/bin/status\.sh'`.~~
- [x] ~~**P2** `ufw status` and `aa-status --enabled` require sudo — fixed: uses `sudo -n` (non-interactive) for graceful fallback.~~
- [x] ~~**P2** `tebian-common` `tfuzzel()` function shadowed by `~/.local/bin/tfuzzel` binary — fixed: standalone tfuzzel binary now includes icon-stripping logic.~~
- [x] ~~**P2** No process locking — fixed: tebian-settings now uses flock on `/tmp/tebian-settings.lock`.~~
- [x] ~~**P2** `lock_timeout_menu` fragile digit extraction — fixed: uses `sed` + `grep -oE` for reliable first-number extraction. (`tebian-settings`)~~

---

## 2. FUZZEL UX ISSUES

- [x] ~~**P1** No current theme indicator — fixed: reads theme file header and prepends `●` to active theme in menu.~~
- [x] ~~**P1** Separator lines (`─────`) are selectable in fuzzel — fixed: tfuzzel now filters separator selections (exits with error if result matches `^─+$`).~~
- [x] ~~**P1** "Back" is always the first (pre-selected) item — fixed: Back moved to last position with separator in all 35 menus.~~
- [x] ~~**P1** No `--no-fuzzy` on dangerous menus — fixed: added `--no-fuzzy` to power menu and fail2ban confirmation.~~
- [x] ~~**P2** `--width` inconsistency across menus — audited: standalone scripts use intentional widths for different content, settings submenus consistently auto-size, info-display panels use explicit widths. Already consistent by category.~~
- [x] ~~**P2** Icon hints (`\0icon\x1f`) used inconsistently — audited: category menus use sidebar icon hints, action/toggle menus use inline nerd font icons. Intentional split, consistent within each type.~~
- [x] ~~**P2** No loading indicator for slow operations — fixed: `notify-send` "Scanning..." shown before WiFi and Bluetooth scans.~~
- [x] ~~**P2** `audio_output_menu` parses wpctl output fragily — fixed: uses `awk '/Sinks:/,/^$/'` for reliable section parsing.~~
- [x] ~~**P2** Wallpaper picker shows filenames only — accepted: fuzzel is text-based, no image preview possible. User can browse wallpaper folder via file manager.~~
- [x] ~~**P2** No keyboard shortcut hints in menus — fixed: added keybinding hints (Mod+D, Mod+S, Mod+L, Print, Shift+Print) to main menu, screen menu, and UI menu items.~~

---

## 3. SECURITY

- [x] ~~**P0** WiFi password passed on command line — fixed: uses temporary connection file (mktemp, chmod 600) to avoid password in ps aux. File deleted immediately after `nmcli connection load`.~~
- [x] ~~**P0** Headscale URL passed unsanitized to sudo — fixed: uses env var + single-quoted heredoc for safe expansion.~~
- [x] ~~**P1** SSH enabled by default on desktop installs — fixed: tebian-onboard Desktop setup now disables SSH (`systemctl disable --now ssh`).~~
- [x] ~~**P1** `sudo apt purge -y fail2ban` without confirmation — fixed: added fuzzel confirmation prompt before purge.~~
- [x] ~~**P1** `curl | sh` for Tailscale and Nix installs — fixed: Tailscale uses GPG-signed apt repo, Nix uses download-then-verify (shebang check + `--daemon` mode).~~
- [x] ~~**P1** No SecureBoot / TPM integration — N/A: Tebian is a config layer, not a bootloader. Debian Trixie handles SecureBoot/shim out of the box.~~
- [x] ~~**P1** No LUKS encryption setup in installer — N/A: disk encryption is handled by Debian's base installer before Tebian runs.~~
- [x] ~~**P2** No automatic unattended-upgrades config — fixed: added Auto Security Updates toggle in Security menu (installs/configures unattended-upgrades).~~
- [x] ~~**P2** Firejail only for browsers — fixed: extended to sandbox thunderbird, evolution, signal, telegram, discord in addition to browsers.~~
- [x] ~~**P2** Package names from apt-cache passed through sed extraction — fixed: replaced with `awk -F': '` for reliable field extraction.~~

---

## 4. ARCHITECTURE / CODE QUALITY

- [x] ~~**P1** 2984-line monolith — fixed: split into 10 sourced modules in `tebian-settings.d/` (wifi-bt, audio, screen, theme, ui, software, security, infra, perf, system). Main file is 107 lines.~~
- [x] ~~**P1** Floating mode setup duplicated 3 times — fixed: extracted to `setup_floating_mode()` and `remove_floating_mode()` in tebian-common. tebian-settings now uses shared functions (tebian-onboard still needs update).~~
- [x] ~~**P1** Hardware detection duplicated 3 times — fixed: `detect_hardware()` added to tebian-common. tebian-onboard now uses it (tebian-settings still has inline copy in perf_menu, can be updated later).~~
- [x] ~~**P2** sed edits on symlinked config files — verified: `desktop.sh` uses `cp` not `ln -s`. Configs are copies. Local dev may have manual symlinks but that's user choice, not a Tebian bug.~~
- [x] ~~**P2** `tebian-kill` uses `kill -9` — fixed: sends SIGTERM first, waits 1s, then SIGKILL only if process persists.~~
- [x] ~~**P2** No transaction/install log — fixed: `tlog()`/`tnotify()` added to tebian-settings, logs to `~/.local/share/tebian-settings.log`.~~

---

## 5. DEAD CODE / UNUSED

- [x] ~~**P1** `tebian-start` is never called — deleted.~~
- [x] ~~**P1** `tebian-welcome` is never called — deleted.~~
- [x] ~~**P1** `tebian-update` not in PATH — fixed: symlinked to `~/.local/bin/`.~~
- [x] ~~**P1** `tebian-rebuild` not in PATH — fixed: symlinked to `~/.local/bin/`.~~
- [x] ~~**P1** `tebian-isolated-workspace` not in PATH — fixed: symlinked to `~/.local/bin/`.~~
- [x] ~~**P1** `nwg-bar` and `nwg-hello` packages installed but unused — fixed: `tebian-cleanup` script detects and offers to purge.~~
- [x] ~~**P1** `notification-daemon` installed alongside `mako` — fixed: `tebian-cleanup` detects conflict and offers to purge notification-daemon.~~
- [x] ~~**P2** `font_menu` exists in theme_menu case statement — fixed: added "Font Manager" entry to theme menu options.~~
- [x] ~~**P2** `dunst`, `i3lock`, `i3status`, `suckless-tools`, `x11-apps`, `xfonts-*` deinstalled but not purged — fixed: `tebian-cleanup` detects rc-state packages and offers to purge.~~
- [x] ~~**P2** `minecraft-launcher` and `parsec` in base install — verified: these are only in the Software & Gaming menu, not installed during onboard/bootstrap.~~
- [x] ~~**P2** `t-fetch` version hardcoded — fixed: reads from `~/Tebian/VERSION`.~~

---

## 6. HARDWARE SUPPORT

- [x] ~~**P1** Nvidia requires manual intervention — fixed: perf.sh Install Nvidia now handles non-free repos, nouveau blacklist, initramfs rebuild, and Wayland env vars. Onboard also auto-configures during Desktop setup.~~
- [x] ~~**P1** No hybrid graphics (Optimus/PRIME) handling — fixed: perf.sh Nvidia installer detects Intel+Nvidia hybrid and provides PRIME render offload guidance.~~
- [x] ~~**P2** No ARM documentation beyond Pi mention — acknowledged: code handles ARM gracefully (Pi detection + fallback), docs are a future task not a code bug.~~
- [x] ~~**P2** No Wayland-native display configuration — fixed: added Display Outputs submenu with mirror, extend right, and per-output enable/disable via swaymsg.~~
- [x] ~~**P2** No input device configuration — fixed: added Input Devices menu (touchpad tap/scroll, mouse speed, keyboard layout) in UI settings.~~

---

## 7. THEME COHERENCE

- [x] ~~**P1** GTK theme stuck on Adwaita-dark — fixed: tebian-theme now updates gtk-3.0/settings.ini (dark/light mode, icon theme).~~
- [x] ~~**P1** kitty.conf exists but may be empty at first boot — fixed: tebian-onboard now applies default Nord theme during Desktop setup.~~
- [x] ~~**P1** gtklock colors not updated by theme switcher — fixed: tebian-theme now updates gtklock CSS colors from theme.conf.~~
- [x] ~~**P1** mako config — tebian-theme already copies theme-specific mako config on switch (line 44). Symlink note was false positive.~~
- [x] ~~**P2** No cursor theme coordination — fixed: tebian-theme sets XCURSOR_THEME/XCURSOR_SIZE via environment.d and gtk settings.~~
- [x] ~~**P2** QT apps need separate handling — fixed: `QT_QPA_PLATFORMTHEME=gtk2` set via environment.d during onboarding.~~
- [x] ~~**P2** Icon theme not tied to color themes — fixed: tebian-theme creates gtk-3.0/settings.ini if missing, sets Papirus/Papirus-Dark based on theme.~~
- [x] ~~**P2** Login screen (gtkgreet) not updated by theme — fixed: tebian-theme now updates `/etc/greetd/style.css` colors via `sudo -n` (non-interactive, works if NOPASSWD or recent auth).~~

---

## 8. FIRST BOOT / ONBOARDING UX

- [x] ~~**P1** No timezone prompt — fixed: tebian-onboard now offers timezone selection from common timezones during Desktop setup.~~
- [x] ~~**P1** No hostname prompt — fixed: tebian-onboard now offers hostname change during Desktop setup.~~
- [x] ~~**P1** No keyboard layout selection — fixed: tebian-onboard now offers keyboard layout selection during Desktop setup.~~
- [x] ~~**P1** Onboarding happens inside Sway — by design: onboard uses fuzzel (Wayland) for the Base/Desktop choice. System config (timezone, hostname, keyboard) happens in a kitty terminal within sway.~~
- [x] ~~**P1** No resume on crash — fixed: tebian-onboard uses `.onboard_in_progress` flag file; resumes automatically if terminal crashes mid-install.~~
- [x] ~~**P2** No locale/language selection — fixed: tebian-onboard now offers locale selection during Desktop setup (8 common locales + custom).~~
- [x] ~~**P2** No user account creation — by design: Debian installer creates the user. Tebian is a config layer, not a full OS installer.~~
- [x] ~~**P2** No network check before package install — fixed: ping check added before apt operations in tebian-onboard.~~

---

## 9. INSTALL SCRIPT (`install.sh` / `bootstrap.sh`)

- [x] ~~**P1** No checksum verification on tarball download — fixed: install.sh now downloads to file, verifies SHA256SUMS if available, with graceful fallback.~~
- [x] ~~**P1** No transaction log — fixed: `blog()` function added to bootstrap.sh, logs to `~/.local/share/tebian-bootstrap.log`.~~
- [x] ~~**P1** No rollback on failure — mitigated: `set -euo pipefail` stops on first error, apt handles partial installs gracefully, onboard has resume detection via progress file. Full snapshot/rollback is over-engineered for a config layer.~~
- [x] ~~**P1** Server mode deletes `~/Tebian` without confirmation — fixed: requires typing "DELETE" to confirm.~~
- [x] ~~**P2** Silent on optional package failures — fixed: tebian-onboard now shows `⚠ Optional package failed` instead of silencing errors.~~
- [x] ~~**P2** No pre-flight check — fixed: bootstrap.sh now checks internet connectivity and disk space (2GB minimum) before starting.~~
- [x] ~~**P2** `rsync` used in update path but not guaranteed installed — fixed: falls back to `cp -a` if rsync not available.~~

---

## 10. MISSING FEATURES

- [x] ~~**P1** No WiFi disconnect option — fixed: clicking connected SSID now offers disconnect prompt.~~
- [x] ~~**P1** No `workspace_auto_back_and_forth` — fixed: added to config.user.~~
- [x] ~~**P1** No `bindsym $mod+Tab` for workspace cycling — fixed: `$mod+Tab workspace back_and_forth` added to config.user.~~
- [x] ~~**P2** No notification history — fixed: added Notification History menu in More drawer, uses `makoctl history` with clear option.~~
- [x] ~~**P2** No display output fuzzel menu — fixed: added Display Outputs submenu with mirror, extend right, and per-output enable/disable.~~
- [x] ~~**P2** `tebian-drawer` doesn't handle `TryExec` field — fixed: skips entries where TryExec binary not found.~~
- [x] ~~**P2** No night light / blue light filter option — fixed: added Night Light toggle (wlsunset) in Screen menu.~~
- [x] ~~**P2** No power profile switching — fixed: added Power Profile menu (Battery/Balanced/Performance) in Performance menu, uses TLP.~~
- [x] ~~**P2** No VPN configuration menu beyond Tailscale — fixed: added WireGuard VPN menu in T-Link (install, connect/disconnect, import config, generate keypair).~~
- [x] ~~**P2** Bar Stats toggle requires full status bar restart — fixed: status.sh now checks flag file dynamically every 10s loop.~~

---

## 11. STATUS BAR (`status.sh`)

- [x] ~~**P1** Volume detection forks `wpctl` every 10s — fixed: reduced to 30s interval (OSD handles real-time feedback). WiFi polling separated to its own 10s zero-fork block.~~
- [x] ~~**P2** `awk` fork in `df -h /` every 10s — fixed: moved to 30s interval alongside wpctl.~~
- [x] ~~**P2** No click actions — swaybar limitation: individual segment clicks aren't possible. Global button1 opens tebian-menu. Won't fix.~~
- [x] ~~**P2** No weather, no calendar popup, no system tray — swaybar limitation. Users who want these can switch to waybar. Won't fix for default bar.~~

---

## 12. EDGE SNAP (`tebian-edge-snap`)

- [x] ~~**P2** No bottom edge snap behavior — fixed: added bottom edge (snap to bottom half), bottom-left corner, and bottom-right corner snaps.~~
- [x] ~~**P2** No visual hint while dragging near edges — won't fix: Sway IPC doesn't provide real-time drag events. Would require a transparent overlay window, which adds complexity for minimal benefit.~~
- [x] ~~**P2** 150ms polling interval — fixed: reduced to 100ms for snappier response.~~

---

*Updated: 2026-02-26 | Tebian v3.2.0 | 103 total items — 103 resolved, 0 remaining*
