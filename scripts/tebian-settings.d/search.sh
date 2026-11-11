# shellcheck shell=bash
# tebian-settings module: search.sh
# Sourced by tebian-settings — do not run directly
#
# The settings search: one row per setting a person might look for, typed
# into the Settings top level or into Mod+D (tebian-settings --search-list,
# listed after the apps). Picking one opens its own function, so "time zone"
# lands on the time zone list, not on a menu two levels above it.
#
# Rows: id | label | other words | where it lives | function
#   id        stable name for `tebian-settings --open <id>`
#   label     what the setting is called in its menu
#   other     the words people type for it instead, comma separated
#   where     the menus above it, "" for the Settings top level
#   function  argument-less; the leaf where one exists, else the nearest menu
#
# fuzzel only matches what it shows, so each "other word" becomes its own
# line, "Hostname  (Computer Name)": it reads as what that thing is called
# here, and nothing hidden is matched. Words the label already contains
# are left out, since typing them finds the label line anyway.
# tests/run.sh checks that every function exists and every id is unique.

SETTINGS_INDEX='
wifi|WiFi|Wireless, Wi-Fi, WLAN, Internet, Network, Hotspot||wifi_menu
bluetooth|Bluetooth|Headphones, Earbuds, Pair a Device, Wireless Mouse, BT||bluetooth_menu
audio|Audio|Sound, Volume||audio_menu
audio-output|Output Device|Speakers, Headphones, Sound Output, HDMI Audio|Audio|audio_output_menu
audio-input|Input Device|Microphone, Mic, Recording, Headset|Audio|audio_input_menu
mic-mute|Mute Microphone|Mic Mute, Unmute Microphone|Audio|mic_mute_toggle
audio-mixer|Audio Mixer|Volume Mixer, App Volume, Pulsemixer, Pavucontrol|Audio|audio_mixer
screen|Screen|Display||screen_all_menu
brightness|Brightness|Backlight, Dim the Screen|Screen|screen_menu
displays|Displays|Monitor, External Monitor, Second Screen, Multiple Monitors, Turn Off a Screen|Screen|display_output_menu
display-layout|Display Layout|Resolution, Refresh Rate, Scale, Arrange Monitors, wdisplays|Screen > Brightness|display_layout_gui
night-light|Night Light|Blue Light, Warm Screen, Color Temperature, Redshift, Eye Strain|Screen|night_light_menu
capture|Capture|Screenshot, Screenshots, Print Screen, Screen Capture, Snip, Snipping Tool|Screen|capture_menu
screen-recording|Record Screen|Screen Recording, Screen Recorder, Record Video, Screencast|Screen > Capture|capture_record
copy-text|Copy Text from Screen|OCR, Text Recognition, Extract Text|Screen > Capture|capture_text
scan-qr|Scan QR Code|QR, Barcode|Screen > Capture|capture_qr
emoji|Emoji Picker|Emoticons, Smiley, Special Characters|Keyboard & Mouse|capture_emoji
lock|Lock & Idle|Lock Screen, Auto-Lock, Screen Lock, Idle, Screensaver|Screen|lock_menu
lock-timeout|Lock Timeout|Auto-Lock Time, Idle Time, Lock After|Screen > Lock & Idle|lock_timeout_menu
bar-stats|Bar Stats|CPU in Bar, RAM in Bar, System Monitor in Bar|Screen|bar_stats_toggle
themes|Themes|Dark Mode, Light Mode, Colors, Appearance, Look, Nord, Dracula, Gruvbox, Tokyo Night, Rose Pine, Everforest||theme_menu
wallpaper|Wallpaper|Background, Desktop Picture, Desktop Background|Themes|custom_wallpaper_menu
desktop-feel|Desktop Feel|Windows Style, macOS Style, Window Layout Style|Themes|feel_menu
fonts|Fonts|Font, Typeface, JetBrains Mono, Terminus|Themes > Font Manager|font_menu
keyboard-mouse|Keyboard & Mouse|Input Devices, Trackpad, Touchpad, Tap to Click, Natural Scroll, Scroll Direction||input_device_menu
keyboard-layout|Keyboard Layout|Keyboard Language, Input Language, Dvorak, AZERTY, QWERTZ, Colemak|Keyboard & Mouse|keyboard_layout_menu
mouse-speed|Mouse Speed|Pointer Speed, Mouse Acceleration, Cursor Speed, Sensitivity|Keyboard & Mouse|mouse_speed_menu
scroll-speed|Scroll Speed|Touchpad Scroll Speed|Keyboard & Mouse|scroll_speed_menu
software|Software|Install Apps, Apps, Programs, App Store||software_hub
web-browsers|Web Browser|Install a Browser, Firefox, Helium, Zen|Software|browser_menu
web-apps|Web Apps|Website as App, Install Web App, PWA, Site Shortcut, Web Shortcut|Software|webapps_menu
web-app-add|Add Web App|New Web App, Make a Site an App|Software > Web Apps|webapps_add
package-browser|Package Browser|Install a Package, Uninstall, Remove an App, apt, Flatpak|Software|package_browser
ai-tools|AI Tools|Claude Code, Codex, OpenCode, T3 Code, Hermes, Grok, Antigravity|Software|ai_tools_menu
gaming|Software & Gaming|Games, Steam, Heroic, Minecraft, Lutris, Nix, Distrobox|Software|software_menu
graphics-drivers|Graphics Drivers|Mesa, GPU Driver, Vulkan|Software > Software & Gaming|gfx_drivers_menu
terminal|Terminal|Default Terminal, kitty, foot, alacritty|Software|terminal_menu
essentials|Install Essentials|Clipboard Manager, File Manager, Volume OSD|Software|essentials_menu
desktop-environments|Desktop Environments|GNOME, KDE Plasma, Cinnamon|Software|de_menu
update|System Update|Updates, Upgrade, Update Everything, Patches||system_update
security|Security|Privacy, Protection||security_menu
security-profile|Security Profile|Firewall, UFW, fail2ban, Hardened|Security|security_profile_menu
password|Change Password|Password, Login Password, passwd, Disk Passphrase|Security|change_password_flow
autologin|Skip Login After Disk Unlock|Autologin, Automatic Login, Log In Automatically|Security|autologin_toggle
sudo-password|Passwordless sudo|sudo, Admin Password|Security|passwordless_sudo_toggle
ssh|Remote Access (SSH)|SSH, Remote Login, sshd|Security|ssh_toggle
auto-updates|Auto Security Updates|Automatic Updates, Unattended Upgrades|Security|auto_updates_toggle
apparmor|AppArmor|Mandatory Access Control|Security|apparmor_menu
paranoid|Paranoid Mode|Route Everything Through Tor, MAC Randomization|Security|security_menu
tor|Tor Routing|Tor, Anonymous Browsing, proxychains|Security|security_menu
dns-privacy|DNS Privacy|DNS over TLS, Encrypted DNS, Quad9, Cloudflare DNS|Security|security_menu
kernel-hardening|Kernel Hardening|sysctl Hardening|Security|security_menu
firejail|Firejail App Sandbox|Sandbox, Browser Sandbox|Security|security_menu
open-ports|View Open Ports|Listening Ports, Network Services|Security|security_menu
security-logs|Security Logs|Login Attempts, Auth Log, Firewall Log|Security|security_logs_menu
security-tools|Security Tools|Pentest, nmap, Wireshark, Kali, Metasploit|Security|security_tools_menu
system|System|Preferences||system_menu
about|About This Computer|System Info, Specs, Hardware, CPU, RAM, Memory, Disk Space, Kernel, Uptime|System|sysinfo_menu
hostname|Computer Name|Hostname, Device Name, PC Name, Rename this Computer|System|hostname_menu
datetime|Date & Time|Clock, Time, Date|System|datetime_menu
timezone|Time Zone|Timezone, City, Region Time|System > Date & Time|timezone_menu
ntp|Automatic Time|NTP, Time Sync, Network Time, Wrong Time|System > Date & Time|ntp_toggle
clock-format|Clock Format|12-Hour Clock, 24-Hour Clock, AM/PM, Bar Clock|System > Date & Time|clock_format_toggle
language|Language & Region|Language, Locale, Region, Translation, Display Language|System|locale_menu
printers|Printers|Printer, Printing, Print, CUPS|System|printers_menu
notifications|Notifications|Alerts, Popups|System|notifications_menu
dnd|Do Not Disturb|DND, Quiet Mode, Focus, Silence Notifications, Mute Notifications|System > Notifications|dnd_toggle
notification-history|Notification History|Missed Notifications, Clear Notifications|System > Notifications|notification_history_menu
power|Power|Shutdown, Shut Down, Turn Off, Reboot, Restart, Sleep, Suspend, Log Out, Logout, Keep Awake, Lid Close||power_menu
power-mode|Power Mode|Battery Saver, Power Saver, Performance Mode, Battery Life, TLP|More > Performance|power_mode_menu
more|More|Advanced||more_menu
desktop-ui|Desktop & UI|Bar, Taskbar, Panel, Title Bars, Floating Windows, Tiling, Window Snapping, Window Effects, Blur, Rounded Corners, Hide Bar, Bar Position|More|ui_menu
dock|Dock|Taskbar, App Dock, Running Apps, Mac Dock, Auto-hide Dock|More > Desktop & UI|dock_menu
snap-assist|Snap Assist|Fill Other Half, Window Picker, Snap Thirds, Side by Side|More > Desktop & UI|snap_assist_toggle
text-mode|UI Icons|Text Mode, Icons in Menus, Nerd Font Icons|More > Desktop & UI|ui_icons_toggle
bar-style|Bar Style|Modern Bar, Classic Bar, Waybar|More > Desktop & UI|bar_style_toggle
weather|Weather in Bar|Weather, Forecast, Temperature|More > Desktop & UI|weather_menu
font-rendering|Font Rendering|Blurry Text, Font Smoothing, Hinting, Subpixel, ClearType|More > Desktop & UI|font_rendering_menu
keybinds|Keybinds|Keyboard Shortcuts, Shortcuts, Hotkeys, Key Bindings|More > Desktop & UI|keybinds_list
default-apps|Default Apps|Default Programs, Open With|More|default_apps_menu
default-browser|Default Web Browser|Default Browser, Open Links With|More > Default Apps|default_browser_menu
default-file-manager|Default File Manager|Files App, Thunar|More > Default Apps|default_file_manager_menu
startup-apps|Startup Apps|Startup, Autostart, Start at Login, Login Items|More|startup_apps_menu
drives|Drives|USB Drive, Disks, Automount, Eject, External Drive, Drive Doctor|More|drives_menu
format-drive|Format a Drive|Format USB, Erase a Drive, exFAT, NTFS|More > Drives|format_drive_menu
performance|Performance|Speed Up, RAM Boost, zram, Gaming Optimization, Nvidia Drivers, CPU Microcode, HiDPI Scaling, Clean System Junk, Rolling Branch|More|perf_menu
infrastructure|Infrastructure|Servers, Homelab|More|infra_menu
containers|Containers|Docker, Distrobox, Podman|More > Infrastructure|containers_menu
virtual-machines|Virtualization|Virtual Machines, VM, Windows VM, macOS VM, KVM, QEMU|More > Infrastructure|vm_menu
secure-workspace|Secure Workspace|Isolated Workspace, Tor Gateway|More > Infrastructure > Virtualization|secure_workspace_menu
tlink|T-Link|Fleet, Deploy, Servers|More > Infrastructure|tlink_menu
vpn|VPN|WireGuard|More > Infrastructure > T-Link|vpn_menu
tailscale|Network Setup (Tailscale)|Tailscale, Headscale, Mesh VPN|More > Infrastructure > T-Link|tlink_network_menu
backup|Backup & Restore|Backup, Restore, Back Up My Settings|More|backup_menu
config-tracking|Config Tracking|Git, Config History, Snapshots, Update Tebian, Rebuild System, Machine Settings|More|config_menu
'

# id<TAB>label for every searchable line, primary line first, then one per
# other word. With "nested", the top-level menus' own lines are left out:
# the Settings top level already shows them.
settings_search_list() {
    # One awk, not a bash loop: Mod+D waits for this every time it opens
    printf '%s' "$SETTINGS_INDEX" | awk -F'|' -v mode="${1:-}" -v g="󰒓" '
        $1 == "" { next }
        {
            id = $1; label = $2; where = $4
            if (where != "" || mode != "nested")
                printf "%s\t%s %s  (%s)\n", id, g, label, (where == "" ? "Settings" : where)
            low = tolower(label " " where)
            n = split($3, w, ",")
            for (i = 1; i <= n; i++) {
                gsub(/^ +| +$/, "", w[i])
                if (w[i] == "" || index(low, tolower(w[i]))) continue
                # Just the setting it stands for: with the full path these
                # ran past the edge of the menu
                printf "%s\t%s %s  (%s)\n", id, g, w[i], label
            }
        }'
}

# The function behind an id, or return 1
settings_target() {
    local id fn
    while IFS='|' read -r id _ _ _ fn; do
        [ "$id" = "$1" ] && [ -n "$id" ] && { printf '%s\n' "$fn"; return 0; }
    done <<< "$SETTINGS_INDEX"
    return 1
}

# Open a setting by id; returns 1 only for an id that isn't there. Settings
# that can't work on this machine say so themselves (an offer to install, a
# notification), as in their menus, and a cancelled one is not a failure.
settings_open() {
    local fn
    if ! fn=$(settings_target "${1:-}") || ! declare -F "$fn" >/dev/null; then
        tnotify "Settings" "No such setting: ${1:-(none)}"
        return 1
    fi
    "$fn" || true
}
