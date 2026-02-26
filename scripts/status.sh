#!/bin/bash

# Tebian OS - Pure Bash Zero-Fork Status (V3.0)
# Portable across Intel/AMD, laptops/desktops, Pi, etc.
# Dynamically detects hardware at startup.

# ============================================================
# HARDWARE DETECTION (run once at startup)
# ============================================================

# Backlight: find first available backlight device
BACKLIGHT_DEV=""
if [ -d /sys/class/backlight ] && [ -n "$(ls -A /sys/class/backlight 2>/dev/null)" ]; then
    BACKLIGHT_DEV=$(ls /sys/class/backlight/ 2>/dev/null | head -1)
fi
[ -z "$BACKLIGHT_DEV" ] && HAS_BACKLIGHT=0 || HAS_BACKLIGHT=1

# GPU: detect Intel vs AMD vs none
GPU_TYPE="none"
if [ -f /sys/class/drm/card0/gt_cur_freq_mhz ]; then
    GPU_TYPE="intel"
elif [ -d /sys/class/drm/card0/device/hwmon ]; then
    GPU_TYPE="amd"
fi

# WiFi: find wireless interface
WIFI_IF=""
if [ -d /sys/class/net ]; then
    WIFI_IF=$(ls /sys/class/net/ 2>/dev/null | grep -E '^wl|^wlan|^wlp' | head -1)
fi
[ -z "$WIFI_IF" ] && HAS_WIFI=0 || HAS_WIFI=1

# Bluetooth: find hci device and its rfkill
BT_RFKILL=""
if [ -d /sys/class/bluetooth ]; then
    BT_HCI=$(ls /sys/class/bluetooth/ 2>/dev/null | head -1)
    if [ -n "$BT_HCI" ]; then
        # Find rfkill for this hci device
        for rf in /sys/class/bluetooth/$BT_HCI/rfkill*/state; do
            if [ -f "$rf" ]; then
                BT_RFKILL="$rf"
                break
            fi
        done
    fi
fi
[ -z "$BT_RFKILL" ] && HAS_BT=0 || HAS_BT=1

# Battery: find first battery
BAT_DEV=""
if [ -d /sys/class/power_supply ]; then
    BAT_DEV=$(ls /sys/class/power_supply/ 2>/dev/null | grep -iE '^BAT|^bat' | head -1)
fi
[ -z "$BAT_DEV" ] && HAS_BAT=0 || HAS_BAT=1

# Capslock LED
CAPS_LED=""
for led in /sys/class/leds/*::capslock /sys/class/leds/input*::caps; do
    if [ -f "$led/brightness" ]; then
        CAPS_LED="$led/brightness"
        break
    fi
done
[ -z "$CAPS_LED" ] && HAS_CAPS=0 || HAS_CAPS=1

# Performance stats toggle
[ -f "$HOME/.config/tebian/bar_perf_off" ] && SHOW_PERF=0 || SHOW_PERF=1

# ============================================================
# STATE VARIABLES
# ============================================================
MEM_USAGE=0

update_mem() {
    local total avail
    while read -r name value _; do
        case "$name" in
            MemTotal:) total=$value ;;
            MemAvailable:) avail=$value ;;
        esac
        [[ -n "$total" && -n "$avail" ]] && break
    done < /proc/meminfo
    MEM_USAGE=$((100 * (total - avail) / total))
}

# ============================================================
# INITIALIZE OUTPUT STRINGS
# ============================================================
counter=0
bat_status=""
wifi_status=""
vol_str="󰕾 --%"
bt_status=""
disk_str="󰋊 --%"
bright_str=""
gpu_str=""
caps_str=""

[ $HAS_BAT -eq 0 ] && bat_status="" || bat_status="󰂃 --%"
[ $HAS_WIFI -eq 0 ] && wifi_status="" || wifi_status="󰤮"
[ $HAS_BT -eq 0 ] && bt_status="" || bt_status="󰂲"
[ $HAS_BACKLIGHT -eq 0 ] && bright_str="" || bright_str="󰃠 --%"

while true; do
    # 1. PER-SECOND UPDATES (Built-ins only)
    
    printf -v date_str '%(%a %d %b %H:%M)T' -1
    
    # Brightness (conditional)
    if [ $HAS_BACKLIGHT -eq 1 ]; then
        read -r bright_cur < /sys/class/backlight/$BACKLIGHT_DEV/actual_brightness 2>/dev/null
        read -r bright_max < /sys/class/backlight/$BACKLIGHT_DEV/max_brightness 2>/dev/null
        if [ -n "$bright_cur" ] && [ -n "$bright_max" ] && [ "$bright_max" -gt 0 ]; then
            bright=$((bright_cur * 100 / bright_max))
            bright_str="󰃠 ${bright}%"
        fi
    fi
    
    update_mem
    
    # GPU (conditional by type)
    case "$GPU_TYPE" in
        intel)
            read -r gpu_cur < /sys/class/drm/card0/gt_cur_freq_mhz 2>/dev/null
            read -r gpu_max < /sys/class/drm/card0/gt_max_freq_mhz 2>/dev/null
            if [ -n "$gpu_cur" ] && [ -n "$gpu_max" ] && [ "$gpu_max" -gt 0 ]; then
                gpu_val=$((gpu_cur * 100 / gpu_max))
                gpu_str="󰓅 ${gpu_val}%"
            fi
            ;;
        amd)
            # AMD uses hwmon for GPU metrics - skip for zero-fork, show nothing
            gpu_str=""
            ;;
        *)
            gpu_str=""
            ;;
    esac
    
    # Capslock (conditional)
    if [ $HAS_CAPS -eq 1 ]; then
        read -r caps < "$CAPS_LED" 2>/dev/null
        [ "$caps" = "1" ] && caps_str="󰪛" || caps_str=""
    fi

    # 2. POLL EVERY 10s
    if [ $((counter % 10)) -eq 0 ]; then
        vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        if [[ $vol_raw =~ ([0-9]+)\.([0-9][0-9]) ]]; then
            vol_val=$((10#${BASH_REMATCH[1]} * 100 + 10#${BASH_REMATCH[2]}))
            [[ $vol_raw == *"[MUTED]"* ]] && vol_icon="󰝟" || vol_icon="󰕾"
            vol_str="$vol_icon ${vol_val}%"
        fi
        
        # WiFi (conditional)
        if [ $HAS_WIFI -eq 1 ]; then
            read -r wifi_stat < /sys/class/net/$WIFI_IF/operstate 2>/dev/null
            if [ "$wifi_stat" = "up" ]; then
                while read -r line; do
                    if [[ $line == *"$WIFI_IF:"* ]]; then
                        sig_raw=${line#*:}
                        sig_raw=($sig_raw)
                        sig=${sig_raw[0]%.*}
                        sig=$((sig * 100 / 70))
                        if [ "$sig" -ge 80 ]; then wifi_icon="󰤨";
                        elif [ "$sig" -ge 60 ]; then wifi_icon="󰤥";
                        elif [ "$sig" -ge 40 ]; then wifi_icon="󰤢";
                        else wifi_icon="󰤟"; fi
                        wifi_status="$wifi_icon"
                        break
                    fi
                done < /proc/net/wireless
            else
                wifi_status="󰤮"
            fi
        fi
        
        disk_str="󰋊 $(df -h / | awk 'NR==2 {print $5}')"
    fi
    
    # 3. POLL EVERY 60s
    if [ $((counter % 60)) -eq 0 ]; then
        # Bluetooth (conditional)
        if [ $HAS_BT -eq 1 ]; then
            read -r bt_state < "$BT_RFKILL" 2>/dev/null
            if [ "$bt_state" = "1" ]; then
                bt_dev=$(bluetoothctl devices Connected 2>/dev/null | head -1 | sed 's/.* //')
                [ -n "$bt_dev" ] && bt_status="󰂱 $bt_dev" || bt_status="󰂯"
            else
                bt_status="󰂲"
            fi
        fi

        # Battery (conditional)
        if [ $HAS_BAT -eq 1 ]; then
            read -r bat_cap < /sys/class/power_supply/$BAT_DEV/capacity 2>/dev/null
            read -r bat_stat < /sys/class/power_supply/$BAT_DEV/status 2>/dev/null
            if [ -n "$bat_cap" ]; then
                if [ "$bat_stat" = "Charging" ]; then bat_icon="󰂄";
                elif [ "$bat_cap" -ge 90 ]; then bat_icon="󰁹";
                elif [ "$bat_cap" -ge 70 ]; then bat_icon="󰂀";
                elif [ "$bat_cap" -ge 40 ]; then bat_icon="󰁾";
                else bat_icon="󰂃"; fi
                bat_status="$bat_icon ${bat_cap}%"
            fi
        fi
    fi
    
    # Build output string dynamically based on available hardware
    parts=()
    [ -n "$caps_str" ] && parts+=("$caps_str")
    [ -n "$wifi_status" ] && parts+=("$wifi_status")
    [ -n "$bt_status" ] && parts+=("$bt_status")
    [ -n "$bat_status" ] && parts+=("$bat_status")
    parts+=("$vol_str")
    [ -n "$bright_str" ] && parts+=("$bright_str")
    if [ $SHOW_PERF -eq 1 ]; then
        parts+=("󰍛 ${MEM_USAGE}%")
        [ -n "$gpu_str" ] && parts+=("$gpu_str")
        parts+=("$disk_str")
    fi
    parts+=("$date_str")
    
    # Join with separator
    output=""
    for p in "${parts[@]}"; do
        [ -n "$output" ] && output+="  |  "
        output+="$p"
    done
    echo "$output"
    
    counter=$((counter + 1))
    sleep 1
done
