# tebian-settings module: infra.sh
# Sourced by tebian-settings — do not run directly

infra_menu() {
    while true; do
    INF_OPTS="󰡨 Containers
󰾵 Virtualization
󰌘 T-Link
󰌍 Back"

    INF_CHOICE=$(echo -e "$INF_OPTS" | tfuzzel -d -p " 󰡨 Infrastructure | ")

    if [[ "$INF_CHOICE" == *"󰌍 Back"* || -z "$INF_CHOICE" ]]; then return; fi

    if [[ "$INF_CHOICE" =~ "Containers" ]]; then
        containers_menu
    elif [[ "$INF_CHOICE" =~ "Virtualization" ]]; then
        vm_menu
    elif [[ "$INF_CHOICE" =~ "T-Link" ]]; then
        tlink_menu
    fi
    done
}

containers_menu() {
    while true; do
    # If no container engine at all, offer setup
    if ! command -v distrobox &>/dev/null && ! command -v docker &>/dev/null; then
        C_OPTS="📦 Setup Containers (Distrobox + Podman)
🐳 Install Docker + Compose (servers)
󰌍 Back"

        C_CHOICE=$(echo -e "$C_OPTS" | tfuzzel -d -p " 󰡨 Containers | ")

        if [[ "$C_CHOICE" == *"󰌍 Back"* || -z "$C_CHOICE" ]]; then return; fi

        if [[ "$C_CHOICE" =~ "Setup Containers" ]]; then
            $TERM_CMD bash -c "echo 'Installing Distrobox + Podman...';
            echo '';
            sudo apt update && sudo apt install -y distrobox podman;
            if [ -f /etc/apparmor.d/crun ] && ! grep -q 'unconfined' /etc/apparmor.d/crun; then
                echo 'Fixing crun AppArmor profile...';
                sudo sed -i 's/profile crun \/usr\/bin\/crun {/profile crun \/usr\/bin\/crun flags=(unconfined) {/' /etc/apparmor.d/crun;
                sudo apparmor_parser -r /etc/apparmor.d/crun 2>/dev/null;
            fi;
            echo '';
            echo 'Container engine ready!';
            read -p 'Press Enter to continue...'"
        elif [[ "$C_CHOICE" =~ "Install Docker" ]]; then
            container_install_docker
        fi
        command -v distrobox &>/dev/null || command -v docker &>/dev/null || return
        continue
    fi

    # Build unified container list
    local CONTAINER_LIST=""
    local HAS_CONTAINERS=false

    # Distrobox containers
    if command -v distrobox &>/dev/null; then
        while IFS='|' read -r _id name status image; do
            [ -z "$name" ] && continue
            name=$(echo "$name" | xargs)
            status=$(echo "$status" | xargs)
            image=$(echo "$image" | xargs)
            HAS_CONTAINERS=true
            if [[ "$status" == *"Up"* ]]; then
                CONTAINER_LIST+="🟢 $name ($image)\n"
            else
                CONTAINER_LIST+="⚪ $name ($image)\n"
            fi
        done < <(distrobox list --no-color 2>/dev/null | tail -n +2)
    fi

    # Docker containers
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        while IFS='|' read -r name state image; do
            [ -z "$name" ] && continue
            name=$(echo "$name" | xargs)
            state=$(echo "$state" | xargs)
            image=$(echo "$image" | xargs)
            HAS_CONTAINERS=true
            if [[ "$state" == "running" ]]; then
                CONTAINER_LIST+="🐳 🟢 $name ($image)\n"
            else
                CONTAINER_LIST+="🐳 ⚪ $name ($image)\n"
            fi
        done < <(docker ps -a --format '{{.Names}}|{{.State}}|{{.Image}}' 2>/dev/null)
    fi

    local C_OPTS=""
    if $HAS_CONTAINERS; then
        C_OPTS+="$CONTAINER_LIST"
    fi
    if command -v distrobox &>/dev/null; then
        C_OPTS+="󰐊 New Container\n"
    fi
    if command -v docker &>/dev/null; then
        C_OPTS+="🐳 New Docker Container\n"
    else
        C_OPTS+="🐳 Install Docker + Compose\n"
    fi
    if ! command -v distrobox &>/dev/null; then
        C_OPTS+="📦 Setup Distrobox + Podman\n"
    fi
    C_OPTS+="󰌍 Back"

    C_CHOICE=$(echo -e "$C_OPTS" | tfuzzel -d -p " 󰡨 Containers | ")

    if [[ "$C_CHOICE" == *"󰌍 Back"* || -z "$C_CHOICE" ]]; then return; fi

    if [[ "$C_CHOICE" =~ "New Docker Container" ]]; then
        docker_create_menu
    elif [[ "$C_CHOICE" =~ "New Container" ]]; then
        container_create_menu
    elif [[ "$C_CHOICE" =~ "Install Docker" ]]; then
        container_install_docker
    elif [[ "$C_CHOICE" =~ "Setup Distrobox" ]]; then
        $TERM_CMD bash -c "echo 'Installing Distrobox + Podman...';
        sudo apt update && sudo apt install -y distrobox podman;
        if [ -f /etc/apparmor.d/crun ] && ! grep -q 'unconfined' /etc/apparmor.d/crun; then
            sudo sed -i 's/profile crun \/usr\/bin\/crun {/profile crun \/usr\/bin\/crun flags=(unconfined) {/' /etc/apparmor.d/crun;
            sudo apparmor_parser -r /etc/apparmor.d/crun 2>/dev/null;
        fi;
        echo 'Done!'; read -p 'Press Enter...'"
    elif [[ "$C_CHOICE" =~ ^🐳 ]]; then
        local sel_name
        sel_name=$(echo "$C_CHOICE" | sed 's/^🐳 [^ ]* //;s/ (.*//')
        docker_action_menu "$sel_name"
    elif [[ "$C_CHOICE" =~ ^🟢 ]] || [[ "$C_CHOICE" =~ ^⚪ ]]; then
        local sel_name
        sel_name=$(echo "$C_CHOICE" | sed 's/^[^ ]* //;s/ (.*//')
        container_action_menu "$sel_name"
    fi
    done
}

container_create_menu() {
    local CR_OPTS="󰣖 Arch Linux - AUR, bleeding edge
⛰️ Alpine Linux - Minimal (5MB), musl
 Ubuntu - Stable, huge repos
 Fedora - Latest packages, DNF
󰣖 Kali Linux - Security & pentesting
󰣖 Parrot OS - Security & privacy
 openSUSE Tumbleweed - Rolling release
📝 Custom Image
󰌍 Back"

    local CR_CHOICE
    CR_CHOICE=$(echo -e "$CR_OPTS" | tfuzzel -d -p " 󰐊 New Container | ")

    if [[ "$CR_CHOICE" == *"󰌍 Back"* || -z "$CR_CHOICE" ]]; then return; fi

    local image="" box_name=""
    if [[ "$CR_CHOICE" =~ "Arch" ]]; then
        image="archlinux:latest"; box_name="arch"
    elif [[ "$CR_CHOICE" =~ "Alpine" ]]; then
        image="alpine:latest"; box_name="alpine"
    elif [[ "$CR_CHOICE" =~ "Ubuntu" ]]; then
        image="ubuntu:latest"; box_name="ubuntu"
    elif [[ "$CR_CHOICE" =~ "Fedora" ]]; then
        image="fedora:latest"; box_name="fedora"
    elif [[ "$CR_CHOICE" =~ "Kali" ]]; then
        image="docker.io/kalilinux/kali-rolling"; box_name="kali"
    elif [[ "$CR_CHOICE" =~ "Parrot" ]]; then
        image="docker.io/parrotsec/security"; box_name="parrot"
    elif [[ "$CR_CHOICE" =~ "openSUSE" ]]; then
        image="opensuse/tumbleweed:latest"; box_name="opensuse"
    elif [[ "$CR_CHOICE" =~ "Custom" ]]; then
        image=$(echo "" | tfuzzel -d -p " 📝 Image (e.g. debian:sid): ")
        if [ -z "$image" ]; then return; fi
        box_name=$(echo "$image" | sed 's|.*/||;s|:.*||')
    fi

    [ -z "$image" ] && return

    # Check if name already exists
    if distrobox list --no-color 2>/dev/null | grep -qw "$box_name"; then
        tnotify "Containers" "$box_name already exists"
        return
    fi

    $TERM_CMD bash -c "echo '=== Creating $box_name ==='
    echo 'Image: $image'
    echo ''
    distrobox create --name '$box_name' --image '$image' -Y
    echo ''
    echo '✅ $box_name created!'
    echo ''
    echo 'Enter with: distrobox enter $box_name'
    if [[ '$box_name' == 'arch' ]]; then
        echo ''
        echo 'AUR setup (inside container):'
        echo '  sudo pacman -S --needed base-devel git'
        echo '  git clone https://aur.archlinux.org/yay.git'
        echo '  cd yay && makepkg -si'
    fi
    read -p 'Press Enter to close...'"
}

container_action_menu() {
    local name="$1"
    local status
    status=$(distrobox list --no-color 2>/dev/null | grep -w "$name" | awk -F'|' '{print $3}' | xargs)
    local is_running=false
    [[ "$status" == *"Up"* ]] && is_running=true

    local A_OPTS=""
    A_OPTS+="󰆍 Enter $name\n"
    if $is_running; then
        A_OPTS+="🛑 Stop $name\n"
    fi
    A_OPTS+="📤 Export App to Host Menu\n"
    A_OPTS+="⚙️ Configure $name\n"
    A_OPTS+="󰆴 Remove $name\n"
    A_OPTS+="󰌍 Back"

    local A_CHOICE
    A_CHOICE=$(echo -e "$A_OPTS" | tfuzzel -d -p " 󰡨 $name | ")

    if [[ "$A_CHOICE" == *"󰌍 Back"* || -z "$A_CHOICE" ]]; then return; fi

    if [[ "$A_CHOICE" =~ "Enter" ]]; then
        local image
        image=$(distrobox list --no-color 2>/dev/null | grep -w "$name" | awk -F'|' '{print $4}' | xargs)
        $TERM_CMD bash -c "
            echo '┌─────────────────────────────────────┐'
            echo '│  Entering container: $name'
            echo '│  Image: ${image:-unknown}'
            echo '│  Type \"exit\" to return to Tebian'
            echo '└─────────────────────────────────────┘'
            echo ''
            distrobox enter '$name' || { echo ''; echo 'Container failed to start. Check errors above.'; read -p 'Press Enter to close...'; }
        "
    elif [[ "$A_CHOICE" =~ "Stop" ]]; then
        distrobox stop "$name" -Y 2>/dev/null
        tnotify "Containers" "$name stopped"
    elif [[ "$A_CHOICE" =~ "Export App" ]]; then
        container_export_menu "$name"
    elif [[ "$A_CHOICE" =~ "Configure" ]]; then
        container_config_menu "$name"
    elif [[ "$A_CHOICE" =~ "Remove" ]]; then
        local CONFIRM
        CONFIRM=$(echo -e "No, keep it\nYes, remove $name" | tfuzzel -d --match-mode=exact -p " ⚠️ Delete $name? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            distrobox rm "$name" -f 2>/dev/null
            tnotify "Containers" "$name removed"
        fi
    fi
}

container_export_menu() {
    local name="$1"
    tnotify "Containers" "Scanning apps in $name..."

    # List .desktop apps inside the container
    local APPS
    APPS=$(distrobox enter "$name" -- bash -c 'for f in /usr/share/applications/*.desktop; do [ -f "$f" ] && grep -m1 "^Name=" "$f" | cut -d= -f2; done' 2>/dev/null)

    if [ -z "$APPS" ]; then
        tnotify "Export" "No apps found in $name"
        return
    fi

    local APP_OPTS="󰌍 Back\n$APPS"
    local APP_CHOICE
    APP_CHOICE=$(echo -e "$APP_OPTS" | tfuzzel -d -p " 📤 Export from $name | ")

    if [[ "$APP_CHOICE" == *"󰌍 Back"* || -z "$APP_CHOICE" ]]; then return; fi

    # Find the .desktop file matching the selected app name
    local desktop_file
    desktop_file=$(distrobox enter "$name" -- bash -c "grep -rl '^Name=$APP_CHOICE\$' /usr/share/applications/ 2>/dev/null | head -1" 2>/dev/null)

    if [ -n "$desktop_file" ]; then
        local app_id
        app_id=$(basename "$desktop_file" .desktop)
        distrobox enter "$name" -- distrobox-export --app "$app_id" 2>/dev/null
        tnotify "Export" "$APP_CHOICE exported to host app menu"
    else
        tnotify "Export" "Could not find .desktop file for $APP_CHOICE"
    fi
}

container_install_docker() {
    $TERM_CMD bash -c "echo 'Installing Docker & Docker Compose...';
    echo '';
    sudo apt update && sudo apt install -y docker.io docker-compose;
    if [ \$? -ne 0 ]; then
        echo '';
        echo '❌ Installation failed. Check errors above.';
        read -p 'Press Enter to close...';
        exit 1;
    fi;
    sudo systemctl enable --now docker;
    sudo adduser \$USER docker;
    echo '';
    echo '✅ Docker installed!';
    echo '⚠️  Log out and back in for group changes.';
    read -p 'Press Enter to close...'"
}

docker_action_menu() {
    local name="$1"
    local state
    state=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null)
    local is_running=false
    [[ "$state" == "running" ]] && is_running=true

    local A_OPTS=""
    if $is_running; then
        A_OPTS+="󰆍 Enter $name\n"
        A_OPTS+="🛑 Stop $name\n"
    else
        A_OPTS+="󰐊 Start $name\n"
    fi
    A_OPTS+="📋 View Logs\n"
    A_OPTS+="󰆴 Remove $name\n"
    A_OPTS+="󰌍 Back"

    local A_CHOICE
    A_CHOICE=$(echo -e "$A_OPTS" | tfuzzel -d -p " 🐳 $name | ")

    if [[ "$A_CHOICE" == *"󰌍 Back"* || -z "$A_CHOICE" ]]; then return; fi

    if [[ "$A_CHOICE" =~ "Enter" ]]; then
        $TERM_CMD bash -c "
            echo 'Entering container: $name'
            echo 'Type \"exit\" to return to Tebian'
            echo ''
            docker start '$name' 2>/dev/null
            docker exec -it '$name' sh -c 'exec bash 2>/dev/null || exec sh' || { echo ''; echo 'Failed to enter container.'; read -p 'Press Enter to close...'; }
        "
    elif [[ "$A_CHOICE" =~ "Stop" ]]; then
        docker stop "$name" 2>/dev/null
        tnotify "Docker" "$name stopped"
    elif [[ "$A_CHOICE" =~ "Start" ]]; then
        docker start "$name" 2>/dev/null
        tnotify "Docker" "$name started"
    elif [[ "$A_CHOICE" =~ "View Logs" ]]; then
        $TERM_CMD bash -c "docker logs --tail 100 '$name' 2>&1; echo ''; read -p 'Press Enter to close...'"
    elif [[ "$A_CHOICE" =~ "Remove" ]]; then
        local CONFIRM
        CONFIRM=$(echo -e "No, keep it\nYes, remove $name" | tfuzzel -d --match-mode=exact -p " ⚠️ Delete $name? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            docker rm -f "$name" 2>/dev/null
            tnotify "Docker" "$name removed"
        fi
    fi
}

docker_create_menu() {
    local CR_OPTS="⛰️ Alpine SSH Server (port 2222)
🌐 Nginx Web Server (port 8080)
🐘 PostgreSQL Database (port 5432)
 Redis Cache (port 6379)
📝 Custom Image
󰌍 Back"

    local CR_CHOICE
    CR_CHOICE=$(echo -e "$CR_OPTS" | tfuzzel -d -p " 🐳 New Docker Container | ")

    if [[ "$CR_CHOICE" == *"󰌍 Back"* || -z "$CR_CHOICE" ]]; then return; fi

    local image="" cname="" docker_cmd=""
    if [[ "$CR_CHOICE" =~ "Alpine SSH" ]]; then
        image="alpine:latest"
        cname="alpine-ssh"
        docker_cmd="docker run --name alpine-ssh -d -p 2222:22 alpine:latest sh -c 'apk add --no-cache openssh && ssh-keygen -A && echo \"PermitRootLogin yes\" >> /etc/ssh/sshd_config && echo \"root:alpine\" | chpasswd && /usr/sbin/sshd -D'"
    elif [[ "$CR_CHOICE" =~ "Nginx" ]]; then
        image="nginx:alpine"
        cname="nginx"
        docker_cmd="docker run --name nginx -d -p 8080:80 nginx:alpine"
    elif [[ "$CR_CHOICE" =~ "PostgreSQL" ]]; then
        image="postgres:16-alpine"
        cname="postgres"
        docker_cmd="docker run --name postgres -d -p 5432:5432 -e POSTGRES_PASSWORD=postgres -v postgres_data:/var/lib/postgresql/data postgres:16-alpine"
    elif [[ "$CR_CHOICE" =~ "Redis" ]]; then
        image="redis:alpine"
        cname="redis"
        docker_cmd="docker run --name redis -d -p 6379:6379 redis:alpine"
    elif [[ "$CR_CHOICE" =~ "Custom" ]]; then
        image=$(echo "" | tfuzzel -d -p " 📝 Image (e.g. nginx:latest): ")
        [ -z "$image" ] && return
        cname=$(echo "$image" | sed 's|.*/||;s|:.*||')
        docker_cmd="docker run --name $cname -d $image"
    fi

    [ -z "$image" ] && return

    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$cname"; then
        tnotify "Docker" "$cname already exists"
        return
    fi

    local post_msg=""
    if [[ "$CR_CHOICE" =~ "Alpine SSH" ]]; then
        post_msg="SSH: ssh root@localhost -p 2222 (password: alpine)"
    elif [[ "$CR_CHOICE" =~ "Nginx" ]]; then
        post_msg="Web server: http://localhost:8080"
    elif [[ "$CR_CHOICE" =~ "PostgreSQL" ]]; then
        post_msg="Connect: psql -h localhost -U postgres (password: postgres)"
    elif [[ "$CR_CHOICE" =~ "Redis" ]]; then
        post_msg="Connect: redis-cli -h localhost"
    fi

    $TERM_CMD bash -c "echo '=== Creating $cname ==='
    echo 'Image: $image'
    echo ''
    $docker_cmd
    echo ''
    echo '✅ $cname created!'
    [ -n '$post_msg' ] && echo '' && echo '$post_msg'
    read -p 'Press Enter to close...'"
}

# ── VM/Container Config Helpers ──

# Read a config value with default fallback
vm_conf_get() {
    local file="$1" key="$2" default="$3"
    if [ -f "$file" ]; then
        local val
        val=$(grep "^${key}=" "$file" 2>/dev/null | tail -1 | cut -d= -f2)
        [ -n "$val" ] && echo "$val" && return
    fi
    echo "$default"
}

# Write a config value
vm_conf_set() {
    local file="$1" key="$2" val="$3"
    mkdir -p "$(dirname "$file")"
    if [ -f "$file" ] && grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s/^${key}=.*/${key}=${val}/" "$file"
    else
        echo "${key}=${val}" >> "$file"
    fi
}

# Config menu for a VM
vm_config_menu() {
    local vm_name="$1" conf_file="$2" disk_file="$3"
    local cores ram disk

    while true; do
    cores=$(vm_conf_get "$conf_file" "cores" "4")
    ram=$(vm_conf_get "$conf_file" "ram" "4")
    disk_size=""
    if [ -n "$disk_file" ] && [ -f "$disk_file" ]; then
        disk_size=$(qemu-img info --output=json "$disk_file" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('virtual-size',0)//1073741824)" 2>/dev/null)
    fi

    local CFG_OPTS="󰘚 CPU Cores: $cores
󰍛 RAM: ${ram}GB"
    [ -n "$disk_size" ] && CFG_OPTS+="\n󰋊 Disk: ${disk_size}GB (resize)"
    CFG_OPTS+="\n󰌍 Back"

    local CFG_CHOICE
    CFG_CHOICE=$(echo -e "$CFG_OPTS" | tfuzzel -d -p " $vm_name Config | ")

    if [[ "$CFG_CHOICE" == *"󰌍 Back"* || -z "$CFG_CHOICE" ]]; then return; fi

    if [[ "$CFG_CHOICE" =~ "CPU Cores" ]]; then
        local new_cores
        new_cores=$(echo -e "1\n2\n4\n6\n8\n12\n16" | tfuzzel -d -p " CPU Cores (now: $cores) | ")
        if [ -n "$new_cores" ]; then
            vm_conf_set "$conf_file" "cores" "$new_cores"
            tnotify "$vm_name" "CPU set to $new_cores cores"
        fi
    elif [[ "$CFG_CHOICE" =~ "RAM" ]]; then
        local new_ram
        new_ram=$(echo -e "2\n4\n6\n8\n12\n16\n32" | tfuzzel -d -p " RAM GB (now: ${ram}GB) | ")
        if [ -n "$new_ram" ]; then
            vm_conf_set "$conf_file" "ram" "$new_ram"
            tnotify "$vm_name" "RAM set to ${new_ram}GB"
        fi
    elif [[ "$CFG_CHOICE" =~ "Disk" ]]; then
        local new_disk
        new_disk=$(echo -e "32\n64\n128\n256\n512" | tfuzzel -d -p " Disk GB (now: ${disk_size}GB) | ")
        if [ -n "$new_disk" ] && [ "$new_disk" -gt "$disk_size" ] 2>/dev/null; then
            qemu-img resize "$disk_file" "${new_disk}G" 2>/dev/null
            tnotify "$vm_name" "Disk resized to ${new_disk}GB"
        elif [ -n "$new_disk" ] && [ "$new_disk" -le "$disk_size" ] 2>/dev/null; then
            tnotify "$vm_name" "Can only grow disk (${disk_size}GB -> larger)"
        fi
    fi
    done
}

# Config menu for a container
container_config_menu() {
    local name="$1"
    local conf_file="$HOME/.config/tebian/containers/${name}.conf"
    mkdir -p "$HOME/.config/tebian/containers"

    local cores ram
    while true; do
    cores=$(vm_conf_get "$conf_file" "cores" "0")
    ram=$(vm_conf_get "$conf_file" "ram" "0")
    local cores_label ram_label
    [ "$cores" = "0" ] && cores_label="No Limit" || cores_label="$cores"
    [ "$ram" = "0" ] && ram_label="No Limit" || ram_label="${ram}GB"

    local CFG_OPTS="󰘚 CPU Cores: $cores_label
󰍛 RAM Limit: $ram_label
󰌍 Back"

    local CFG_CHOICE
    CFG_CHOICE=$(echo -e "$CFG_OPTS" | tfuzzel -d -p " $name Config | ")

    if [[ "$CFG_CHOICE" == *"󰌍 Back"* || -z "$CFG_CHOICE" ]]; then return; fi

    if [[ "$CFG_CHOICE" =~ "CPU Cores" ]]; then
        local new_cores
        new_cores=$(echo -e "No Limit\n1\n2\n4\n6\n8" | tfuzzel -d -p " CPU Cores (now: $cores_label) | ")
        if [[ "$new_cores" =~ "No Limit" ]]; then
            vm_conf_set "$conf_file" "cores" "0"
            podman update --cpus 0 "$name" 2>/dev/null
            tnotify "$name" "CPU limit removed"
        elif [ -n "$new_cores" ]; then
            vm_conf_set "$conf_file" "cores" "$new_cores"
            podman update --cpus "$new_cores" "$name" 2>/dev/null
            tnotify "$name" "CPU set to $new_cores cores"
        fi
    elif [[ "$CFG_CHOICE" =~ "RAM" ]]; then
        local new_ram
        new_ram=$(echo -e "No Limit\n1\n2\n4\n8\n16" | tfuzzel -d -p " RAM GB (now: $ram_label) | ")
        if [[ "$new_ram" =~ "No Limit" ]]; then
            vm_conf_set "$conf_file" "ram" "0"
            podman update --memory 0 "$name" 2>/dev/null
            tnotify "$name" "RAM limit removed"
        elif [ -n "$new_ram" ]; then
            vm_conf_set "$conf_file" "ram" "$new_ram"
            podman update --memory "${new_ram}g" "$name" 2>/dev/null
            tnotify "$name" "RAM set to ${new_ram}GB"
        fi
    fi
    done
}

vm_menu() {
    while true; do
    local VM_DIR="$HOME/VMs"

    # Detect KVM
    local kvm_ok=false
    if command -v qemu-system-x86_64 &>/dev/null; then
        kvm_ok=true
    fi

    # Detect Windows VM
    local win_label
    if [ -f "$VM_DIR/windows/windows.qcow2" ]; then
        win_label="🪟 Launch Windows 11"
    elif [ -f "$VM_DIR/windows/windows.iso" ]; then
        win_label="🪟 Install Windows 11 (ISO Ready)"
    else
        win_label="🪟 Setup Windows 11 VM"
    fi

    # Detect macOS VM
    local mac_label
    if [ -f "$VM_DIR/macos/mac_hdd.qcow2" ] && [ -f "$VM_DIR/macos/OpenCore.qcow2" ]; then
        mac_label="🍎 Launch macOS"
    elif [ -f "$VM_DIR/macos/BaseSystem.img" ]; then
        mac_label="🍎 Install macOS (Base System Ready)"
    else
        mac_label="🍎 Setup macOS VM"
    fi

    # Detect isolated workspace state
    local iso_label
    if command -v virsh &>/dev/null && virsh dominfo tebian-workstation &>/dev/null 2>&1; then
        local ws_state
        ws_state=$(virsh domstate tebian-workstation 2>/dev/null || echo "unknown")
        if [[ "$ws_state" == "running" ]]; then
            iso_label="☠️ Secure Workspace (Running)"
        else
            iso_label="☠️ Secure Workspace (Stopped)"
        fi
    else
        iso_label="☠️ Secure Workspace (Not Setup)"
    fi

    local VM_OPTS=""
    if ! $kvm_ok; then
        VM_OPTS+="󰚰 Install KVM Core (Required First)\n"
    fi
    VM_OPTS+="$win_label\n"
    [ -f "$VM_DIR/windows/windows.qcow2" ] && VM_OPTS+="  Configure Windows VM\n"
    VM_OPTS+="$mac_label\n"
    [ -f "$VM_DIR/macos/mac_hdd.qcow2" ] && VM_OPTS+="  Configure macOS VM\n"
    VM_OPTS+="$iso_label\n"
    VM_OPTS+="󰌍 Back"

    V_CHOICE=$(echo -e "$VM_OPTS" | tfuzzel -d -p " 󰾵 VMs | ")

    if [[ "$V_CHOICE" == *"󰌍 Back"* || -z "$V_CHOICE" ]]; then return; fi

    if [[ "$V_CHOICE" =~ "Install KVM Core" ]]; then
        vm_install_kvm
    elif [[ "$V_CHOICE" =~ "Configure Windows" ]]; then
        vm_config_menu "Windows" "$VM_DIR/windows/vm.conf" "$VM_DIR/windows/windows.qcow2"
    elif [[ "$V_CHOICE" =~ "Configure macOS" ]]; then
        vm_config_menu "macOS" "$VM_DIR/macos/vm.conf" "$VM_DIR/macos/mac_hdd.qcow2"
    elif [[ "$V_CHOICE" =~ "Launch Windows" ]]; then
        vm_launch_windows
    elif [[ "$V_CHOICE" =~ "Install Windows" ]]; then
        vm_install_windows
    elif [[ "$V_CHOICE" =~ "Setup Windows" ]]; then
        vm_setup_windows
    elif [[ "$V_CHOICE" =~ "Launch macOS" ]]; then
        vm_launch_macos
    elif [[ "$V_CHOICE" =~ "Install macOS" ]]; then
        vm_install_macos
    elif [[ "$V_CHOICE" =~ "Setup macOS" ]]; then
        vm_setup_macos
    elif [[ "$V_CHOICE" =~ "Secure Workspace" ]]; then
        secure_workspace_menu
    fi
    done
}

vm_install_kvm() {
    $TERM_CMD bash -c '
        echo "========================================="
        echo "  Installing KVM/QEMU Stack"
        echo "========================================="
        echo ""
        sudo apt update && sudo apt install -y \
            qemu-system-x86 qemu-utils qemu-system-gui \
            ovmf swtpm swtpm-tools \
            libvirt-daemon-system virt-manager \
            python3 bridge-utils
        sudo adduser $USER libvirt 2>/dev/null
        sudo adduser $USER kvm 2>/dev/null
        # Enable libvirtd
        sudo systemctl enable --now libvirtd 2>/dev/null
        echo ""
        echo "========================================="
        echo "  KVM Installed!"
        echo "  Log out and back in for group access."
        echo "========================================="
        read -p "Press Enter to close..."
    '
}

# ── Windows VM ──

vm_setup_windows() {
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        tnotify "VM" "Install KVM Core first"
        return
    fi

    $TERM_CMD bash -c '
        VM_DIR="$HOME/VMs/windows"
        mkdir -p "$VM_DIR"
        echo "========================================="
        echo "  Windows 11 VM Setup"
        echo "========================================="
        echo ""
        echo "Step 1: Download Windows 11 ISO"
        echo ""
        echo "Microsoft requires a browser download."
        echo "Go to: https://www.microsoft.com/software-download/windows11"
        echo ""
        echo "After downloading, move the ISO to:"
        echo "  $VM_DIR/windows.iso"
        echo ""
        read -p "Press Enter once the ISO is at the path above..."

        if [ ! -f "$VM_DIR/windows.iso" ]; then
            echo ""
            echo "ISO not found at $VM_DIR/windows.iso"
            echo "You can also place it there later and select"
            echo "\"Install Windows 11\" from the VM menu."
            read -p "Press Enter to close..."
            exit 0
        fi

        echo ""
        echo "Step 2: Creating virtual disk (64GB)..."
        qemu-img create -f qcow2 "$VM_DIR/windows.qcow2" 64G
        echo ""
        echo "========================================="
        echo "  Ready! Select \"Install Windows 11\""
        echo "  from the VM menu to begin installation."
        echo "========================================="
        read -p "Press Enter to close..."
    '
}

vm_install_windows() {
    local VM_DIR="$HOME/VMs/windows"
    local conf_file="$VM_DIR/vm.conf"

    if [ ! -f "$VM_DIR/windows.iso" ]; then
        tnotify "VM" "No Windows ISO found at ~/VMs/windows/windows.iso"
        return
    fi

    # Create disk if it doesn't exist
    [ -f "$VM_DIR/windows.qcow2" ] || qemu-img create -f qcow2 "$VM_DIR/windows.qcow2" 64G

    local cores=$(vm_conf_get "$conf_file" "cores" "4")
    local ram=$(vm_conf_get "$conf_file" "ram" "4")

    # Setup TPM
    mkdir -p "$VM_DIR/tpm"
    swtpm socket \
        --tpmstate dir="$VM_DIR/tpm" \
        --ctrl type=unixio,path="$VM_DIR/tpm/swtpm-sock" \
        --tpm2 \
        --log level=0 &
    local tpm_pid=$!
    sleep 1

    tnotify "VM" "Starting Windows 11 installer..."

    qemu-system-x86_64 \
        -name "Windows 11" \
        -machine q35,accel=kvm \
        -cpu host \
        -smp cores=$cores \
        -m ${ram}G \
        -drive file="$VM_DIR/windows.qcow2",format=qcow2,if=virtio \
        -cdrom "$VM_DIR/windows.iso" \
        -boot d \
        -bios /usr/share/ovmf/OVMF.fd \
        -chardev socket,id=chrtpm,path="$VM_DIR/tpm/swtpm-sock" \
        -tpmdev emulator,id=tpm0,chardev=chrtpm \
        -device tpm-tis,tpmdev=tpm0 \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0 \
        -device virtio-vga-gl,xres=1280,yres=720 \
        -display sdl,gl=on \
        -device qemu-xhci \
        -device usb-tablet \
        -audiodev pipewire,id=audio0 \
        -device intel-hda -device hda-duplex,audiodev=audio0 &

    # Cleanup TPM on VM exit
    local qemu_pid=$!
    wait $qemu_pid 2>/dev/null
    kill $tpm_pid 2>/dev/null
}

vm_launch_windows() {
    local VM_DIR="$HOME/VMs/windows"
    local conf_file="$VM_DIR/vm.conf"

    if [ ! -f "$VM_DIR/windows.qcow2" ]; then
        tnotify "VM" "No Windows VM found. Run Setup first."
        return
    fi

    local cores=$(vm_conf_get "$conf_file" "cores" "4")
    local ram=$(vm_conf_get "$conf_file" "ram" "4")

    # Setup TPM
    mkdir -p "$VM_DIR/tpm"
    swtpm socket \
        --tpmstate dir="$VM_DIR/tpm" \
        --ctrl type=unixio,path="$VM_DIR/tpm/swtpm-sock" \
        --tpm2 \
        --log level=0 &
    local tpm_pid=$!
    sleep 1

    tnotify "VM" "Launching Windows 11..."

    qemu-system-x86_64 \
        -name "Windows 11" \
        -machine q35,accel=kvm \
        -cpu host \
        -smp cores=$cores \
        -m ${ram}G \
        -drive file="$VM_DIR/windows.qcow2",format=qcow2,if=virtio \
        -bios /usr/share/ovmf/OVMF.fd \
        -chardev socket,id=chrtpm,path="$VM_DIR/tpm/swtpm-sock" \
        -tpmdev emulator,id=tpm0,chardev=chrtpm \
        -device tpm-tis,tpmdev=tpm0 \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0 \
        -device virtio-vga-gl,xres=1280,yres=720 \
        -display sdl,gl=on \
        -device qemu-xhci \
        -device usb-tablet \
        -audiodev pipewire,id=audio0 \
        -device intel-hda -device hda-duplex,audiodev=audio0 &

    local qemu_pid=$!
    wait $qemu_pid 2>/dev/null
    kill $tpm_pid 2>/dev/null
}

# ── macOS VM ──

vm_setup_macos() {
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        tnotify "VM" "Install KVM Core first"
        return
    fi

    $TERM_CMD bash -c '
        VM_DIR="$HOME/VMs/macos"
        mkdir -p "$VM_DIR"
        cd "$VM_DIR"

        echo "========================================="
        echo "  macOS VM Setup (OSX-KVM)"
        echo "========================================="
        echo ""

        # Clone OSX-KVM if not present
        if [ ! -d "$VM_DIR/OSX-KVM" ]; then
            echo "Cloning OSX-KVM..."
            git clone --depth 1 https://github.com/kholia/OSX-KVM.git "$VM_DIR/OSX-KVM"
        fi
        cd "$VM_DIR/OSX-KVM"

        echo ""
        echo "Fetching macOS installer from Apple..."
        echo "You will be asked which version to download."
        echo ""
        ./fetch-macOS-v2.py

        echo ""
        echo "Converting BaseSystem to raw image..."
        qemu-img convert BaseSystem.dmg -O raw "$VM_DIR/BaseSystem.img"

        echo ""
        echo "Creating OpenCore boot image..."
        cp "$VM_DIR/OSX-KVM/OpenCore/OpenCore.qcow2" "$VM_DIR/OpenCore.qcow2"

        echo ""
        echo "Creating virtual disk (64GB)..."
        qemu-img create -f qcow2 "$VM_DIR/mac_hdd.qcow2" 64G

        echo ""
        echo "========================================="
        echo "  macOS VM Ready!"
        echo ""
        echo "  Select \"Install macOS\" from the VM menu"
        echo "  to boot the installer."
        echo ""
        echo "  In the VM:"
        echo "  1. Open Disk Utility"
        echo "  2. Erase the QEMU disk as APFS"
        echo "  3. Quit Disk Utility"
        echo "  4. Select Reinstall macOS"
        echo "========================================="
        read -p "Press Enter to close..."
    '
}

vm_install_macos() {
    local VM_DIR="$HOME/VMs/macos"
    local conf_file="$VM_DIR/vm.conf"

    if [ ! -f "$VM_DIR/BaseSystem.img" ]; then
        tnotify "VM" "No macOS base system. Run Setup first."
        return
    fi

    [ -f "$VM_DIR/mac_hdd.qcow2" ] || qemu-img create -f qcow2 "$VM_DIR/mac_hdd.qcow2" 64G
    [ -f "$VM_DIR/OpenCore.qcow2" ] || cp "$VM_DIR/OSX-KVM/OpenCore/OpenCore.qcow2" "$VM_DIR/OpenCore.qcow2"

    local cores=$(vm_conf_get "$conf_file" "cores" "4")
    local ram=$(vm_conf_get "$conf_file" "ram" "4")

    tnotify "VM" "Starting macOS installer..."

    qemu-system-x86_64 \
        -name "macOS Installer" \
        -machine q35,accel=kvm \
        -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check \
        -smp cores=$cores \
        -m ${ram}G \
        -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
        -drive if=pflash,format=raw,readonly=on,file="$VM_DIR/OSX-KVM/OVMF_CODE.fd" \
        -drive if=pflash,format=raw,file="$VM_DIR/OSX-KVM/OVMF_VARS-1920x1080.fd" \
        -device ich9-intel-hda -device hda-duplex \
        -device ich9-ahci,id=sata \
        -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$VM_DIR/OpenCore.qcow2" \
        -device ide-hd,bus=sata.0,drive=OpenCoreBoot \
        -drive id=BaseSystem,if=none,file="$VM_DIR/BaseSystem.img",format=raw \
        -device ide-hd,bus=sata.1,drive=BaseSystem \
        -drive id=MacHDD,if=none,file="$VM_DIR/mac_hdd.qcow2",format=qcow2 \
        -device ide-hd,bus=sata.2,drive=MacHDD \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0 \
        -device virtio-vga-gl,xres=1280,yres=720 \
        -display sdl,gl=on \
        -device qemu-xhci \
        -device usb-tablet \
        -usb -device usb-kbd &
}

vm_launch_macos() {
    local VM_DIR="$HOME/VMs/macos"
    local conf_file="$VM_DIR/vm.conf"

    if [ ! -f "$VM_DIR/mac_hdd.qcow2" ] || [ ! -f "$VM_DIR/OpenCore.qcow2" ]; then
        tnotify "VM" "No macOS VM found. Run Setup first."
        return
    fi

    local cores=$(vm_conf_get "$conf_file" "cores" "4")
    local ram=$(vm_conf_get "$conf_file" "ram" "4")

    tnotify "VM" "Launching macOS..."

    qemu-system-x86_64 \
        -name "macOS" \
        -machine q35,accel=kvm \
        -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check \
        -smp cores=$cores \
        -m ${ram}G \
        -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
        -drive if=pflash,format=raw,readonly=on,file="$VM_DIR/OSX-KVM/OVMF_CODE.fd" \
        -drive if=pflash,format=raw,file="$VM_DIR/OSX-KVM/OVMF_VARS-1920x1080.fd" \
        -device ich9-intel-hda -device hda-duplex \
        -device ich9-ahci,id=sata \
        -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$VM_DIR/OpenCore.qcow2" \
        -device ide-hd,bus=sata.0,drive=OpenCoreBoot \
        -drive id=MacHDD,if=none,file="$VM_DIR/mac_hdd.qcow2",format=qcow2 \
        -device ide-hd,bus=sata.1,drive=MacHDD \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0 \
        -device virtio-vga-gl,xres=1280,yres=720 \
        -display sdl,gl=on \
        -device qemu-xhci \
        -device usb-tablet \
        -usb -device usb-kbd &
}

tlink_menu() {
    while true; do
    TL_OPTS="󰌄 Fleet Management (Servers & Deploy)
🌐 Network Setup (Tailscale)
🔒 VPN (WireGuard)
󰋜 Quick Status
󰌍 Back"

    TL_CHOICE=$(echo -e "$TL_OPTS" | tfuzzel -d -p " 󰌄 T-Link | ")

    if [[ "$TL_CHOICE" == *"󰌍 Back"* || -z "$TL_CHOICE" ]]; then return; fi

    if [[ "$TL_CHOICE" =~ "Fleet Management" ]]; then
        tebian-tlink
    elif [[ "$TL_CHOICE" =~ "Network Setup" ]]; then
        tlink_network_menu
    elif [[ "$TL_CHOICE" =~ "VPN" ]]; then
        vpn_menu
    elif [[ "$TL_CHOICE" =~ "Quick Status" ]]; then
        tlink_status
    fi
    done
}

vpn_menu() {
    while true; do
    # Detect WireGuard state
    if command -v wg &>/dev/null; then
        WG_IFACE=$(sudo -n wg show 2>/dev/null | head -1 | awk '{print $2}')
        if [ -n "$WG_IFACE" ]; then
            WG_LABEL="✅ WireGuard Active ($WG_IFACE)"
        else
            WG_LABEL="⚠️ WireGuard Installed (No Tunnel)"
        fi
    else
        WG_LABEL="📦 WireGuard Not Installed"
    fi

    VPN_OPTS="$WG_LABEL"

    if ! command -v wg &>/dev/null; then
        VPN_OPTS+="\n📦 Install WireGuard"
    else
        if [ -n "$WG_IFACE" ]; then
            VPN_OPTS+="\n🛑 Disconnect ($WG_IFACE)"
        fi
        # List available configs
        WG_CONFIGS=$(ls /etc/wireguard/*.conf 2>/dev/null | xargs -I{} basename {} .conf)
        if [ -n "$WG_CONFIGS" ]; then
            for cfg in $WG_CONFIGS; do
                VPN_OPTS+="\n🚀 Connect: $cfg"
            done
        fi
        VPN_OPTS+="\n📝 Import Config File"
        VPN_OPTS+="\n🔑 Generate Keypair"
    fi

    VPN_OPTS+="\n󰌍 Back"

    VP_CHOICE=$(echo -e "$VPN_OPTS" | tfuzzel -d -p " 🔒 VPN | ")

    if [[ "$VP_CHOICE" == *"󰌍 Back"* || -z "$VP_CHOICE" ]]; then return; fi

    if [[ "$VP_CHOICE" =~ "Install WireGuard" ]]; then
        $TERM_CMD bash -c "echo 'Installing WireGuard...';
        sudo apt update && sudo apt install -y wireguard wireguard-tools;
        echo '';
        echo '✅ WireGuard installed.';
        echo 'Import a .conf file or generate keys to get started.';
        read -p 'Press Enter to close...'"
    elif [[ "$VP_CHOICE" =~ "Disconnect" ]]; then
        $TERM_CMD bash -c "echo 'Disconnecting WireGuard...';
        sudo wg-quick down '$WG_IFACE' 2>/dev/null || sudo wg-quick down wg0;
        echo 'Disconnected.';
        read -p 'Press Enter to close...'"
    elif [[ "$VP_CHOICE" =~ "Connect:" ]]; then
        TUNNEL=$(echo "$VP_CHOICE" | sed 's/.*Connect: //')
        $TERM_CMD bash -c "echo 'Connecting to $TUNNEL...';
        sudo wg-quick up '$TUNNEL';
        echo '';
        sudo wg show;
        echo '';
        read -p 'Press Enter to close...'"
    elif [[ "$VP_CHOICE" =~ "Import Config" ]]; then
        $TERM_CMD bash -c "echo '=== Import WireGuard Config ===';
        echo '';
        echo 'Place your .conf file path below.';
        echo 'It will be copied to /etc/wireguard/';
        echo '';
        read -p 'Config file path: ' CONF_PATH;
        if [ -f \"\$CONF_PATH\" ]; then
            CONF_NAME=\$(basename \"\$CONF_PATH\");
            sudo cp \"\$CONF_PATH\" /etc/wireguard/;
            sudo chmod 600 /etc/wireguard/\"\$CONF_NAME\";
            echo \"✅ Imported \$CONF_NAME\";
        else
            echo '✗ File not found.';
        fi;
        read -p 'Press Enter to close...'"
    elif [[ "$VP_CHOICE" =~ "Generate Keypair" ]]; then
        $TERM_CMD bash -c "echo '=== WireGuard Keypair ===';
        echo '';
        PRIVKEY=\$(wg genkey);
        PUBKEY=\$(echo \"\$PRIVKEY\" | wg pubkey);
        echo \"Private Key: \$PRIVKEY\";
        echo \"Public Key:  \$PUBKEY\";
        echo '';
        echo '⚠️  Save these securely. The private key is NOT stored.';
        echo '';
        read -p 'Press Enter to close...'"
    fi
    done
}

tlink_network_menu() {
    while true; do
    if command -v tailscale >/dev/null; then
        TS_STATUS=$(tailscale status --json 2>/dev/null | grep -q '"BackendState":"Running"' && echo "Active" || echo "Inactive")
        TS_IP=$(tailscale ip -4 2>/dev/null)
        
        if [ "$TS_STATUS" == "Active" ]; then
            TL_LABEL="✅ Tailscale Active ($TS_IP)"
            TL_ACTION="🛑 Disconnect"
        else
            TL_LABEL="⚠️ Tailscale Inactive"
            TL_ACTION="🚀 Connect"
        fi
        
        TL_OPTS="$TL_LABEL
$TL_ACTION
🏰 Connect to Headscale (Self-Hosted)
📋 Show Network Status
󰌍 Back"
    else
        TL_OPTS="📦 Install Tailscale
󰌍 Back"
    fi

    TL_CHOICE=$(echo -e "$TL_OPTS" | tfuzzel -d -p " 🌐 Network | ")

    if [[ "$TL_CHOICE" == *"󰌍 Back"* || -z "$TL_CHOICE" ]]; then return; fi

    if [[ "$TL_CHOICE" =~ "Install Tailscale" ]]; then
        $TERM_CMD bash -c "echo 'Installing Tailscale via apt repository...'
        echo ''
        # Add Tailscale apt repo (signed with their GPG key)
        curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
        curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
        sudo apt update
        sudo apt install -y tailscale
        echo ''
        echo 'Tailscale installed via signed apt repository.'
        read -p 'Press Enter...'"
    elif [[ "$TL_CHOICE" =~ "Connect" ]] && ! [[ "$TL_CHOICE" =~ "Headscale" ]]; then
        $TERM_CMD bash -c "sudo tailscale up; read -p 'Connected! Press Enter...'"
    elif [[ "$TL_CHOICE" =~ "Headscale" ]]; then
        SERVER_URL=$(echo "" | tfuzzel -d -p " 🏰 Headscale URL: ")
        if [ -n "$SERVER_URL" ]; then
            HEADSCALE_URL="$SERVER_URL" $TERM_CMD bash -c 'sudo tailscale up --login-server "$HEADSCALE_URL"; read -p "Connected! Press Enter..."'
        fi
    elif [[ "$TL_CHOICE" =~ "Disconnect" ]]; then
        $TERM_CMD bash -c "sudo tailscale down; read -p 'Disconnected. Press Enter...'"
    elif [[ "$TL_CHOICE" =~ "Network Status" ]]; then
        $TERM_CMD bash -c "tailscale status; read -p 'Press Enter...'"
    fi
    done
}

tlink_status() {
    SERVERS_FILE="$HOME/.config/tebian/servers.conf"
    
    STATUS="󰌄 T-LINK STATUS
Network:"
    
    if command -v tailscale >/dev/null; then
        TS_STATUS=$(tailscale status --json 2>/dev/null | grep -q '"BackendState":"Running"' && echo "✅ Connected" || echo "⚠️ Inactive")
        TS_IP=$(tailscale ip -4 2>/dev/null)
        STATUS+="
  Tailscale: $TS_STATUS"
        [ -n "$TS_IP" ] && STATUS+="
  IP: $TS_IP"
    else
        STATUS+="
  Tailscale: Not installed"
    fi
    
    STATUS+="
Servers:"
    
    if [ -f "$SERVERS_FILE" ]; then
        SERVERS=$(grep -v "^#" "$SERVERS_FILE" | grep "=" | head -5)
        for line in $SERVERS; do
            NAME=$(echo "$line" | cut -d= -f1)
            IP=$(echo "$line" | cut -d= -f2)
            if ping -c 1 -W 1 "$IP" &>/dev/null; then
                STATUS+="
  ● $NAME"
            else
                STATUS+="
  ○ $NAME (offline)"
            fi
        done
    else
        STATUS+="
  No servers configured"
    fi
    
    STATUS+="
󰌍 Back"
    
    CHOICE=$(echo -e "$STATUS" | tfuzzel -d -p "" --width 40 --lines 15)
    
    # Back returns to tlink_menu's while loop
    return
}

