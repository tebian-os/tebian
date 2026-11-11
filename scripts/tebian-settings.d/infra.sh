# shellcheck shell=bash
# tebian-settings module: infra.sh
# Sourced by tebian-settings — do not run directly

infra_menu() {
    while true; do
    INF_OPTS="󰡨 Containers
󰾵 Virtualization
󰌘 T-Link
󰌍 Back"

    INF_CHOICE=$(echo -e "$INF_OPTS" | tfuzzel -d -p " 󰡨 Infrastructure | ")

    [ -n "$INF_CHOICE" ] || menu_close
    if is_back "$INF_CHOICE"; then return; fi

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
        C_OPTS="󰏗 Linux Containers [Distrobox + Podman] (Not Installed)
󰡨 Docker + Compose, for servers (Not Installed)
󰌍 Back"

        C_CHOICE=$(echo -e "$C_OPTS" | tfuzzel -d -p " 󰡨 Containers | ")

        [ -n "$C_CHOICE" ] || menu_close
        if is_back "$C_CHOICE"; then return; fi

        if [[ "$C_CHOICE" =~ "Distrobox" ]]; then
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
        elif [[ "$C_CHOICE" =~ "Docker" ]]; then
            container_install_docker
        fi
        # Installed or not, show the menu again: returning on a failed or
        # cancelled install dropped the user a level up with no word why
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
                CONTAINER_LIST+="󰄬 $name ($image)\n"
            else
                CONTAINER_LIST+="󰄰 $name ($image)\n"
            fi
        done < <(distrobox list --no-color 2>/dev/null | tail -n +2)
    fi

    # Docker containers. Unreachable right after the install (the docker
    # group applies from the next login) or with the service stopped
    local docker_ok=false
    command -v docker &>/dev/null && docker info &>/dev/null && docker_ok=true
    if $docker_ok; then
        while IFS='|' read -r name state image; do
            [ -z "$name" ] && continue
            name=$(echo "$name" | xargs)
            state=$(echo "$state" | xargs)
            image=$(echo "$image" | xargs)
            HAS_CONTAINERS=true
            if [[ "$state" == "running" ]]; then
                CONTAINER_LIST+="󰡨 󰄬 $name ($image)\n"
            else
                CONTAINER_LIST+="󰡨 󰄰 $name ($image)\n"
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
    if $docker_ok; then
        C_OPTS+="󰡨 New Docker Container\n"
    elif command -v docker &>/dev/null; then
        C_OPTS+="󰡨 Docker (Not Running)\n"
    else
        C_OPTS+="󰡨 Docker + Compose (Not Installed)\n"
    fi
    if ! command -v distrobox &>/dev/null; then
        C_OPTS+="󰏗 Distrobox + Podman (Not Installed)\n"
    fi
    C_OPTS+="󰌍 Back"

    C_CHOICE=$(echo -e "$C_OPTS" | tfuzzel -d -p " 󰡨 Containers | ")

    [ -n "$C_CHOICE" ] || menu_close
    if is_back "$C_CHOICE"; then return; fi

    if [[ "$C_CHOICE" =~ "New Docker Container" ]]; then
        docker_create_menu
    elif [[ "$C_CHOICE" =~ "New Container" ]]; then
        container_create_menu
    elif [[ "$C_CHOICE" == *"Docker + Compose (Not Installed)"* ]]; then
        container_install_docker
    elif [[ "$C_CHOICE" == *"Docker (Not Running)"* ]]; then
        tnotify "Docker" "Docker isn't reachable. Just installed it? Log out and back in. Otherwise start it: sudo systemctl start docker"
    elif [[ "$C_CHOICE" == *"Distrobox + Podman (Not Installed)"* ]]; then
        $TERM_CMD bash -c "echo 'Installing Distrobox + Podman...';
        sudo apt update && sudo apt install -y distrobox podman;
        if [ -f /etc/apparmor.d/crun ] && ! grep -q 'unconfined' /etc/apparmor.d/crun; then
            sudo sed -i 's/profile crun \/usr\/bin\/crun {/profile crun \/usr\/bin\/crun flags=(unconfined) {/' /etc/apparmor.d/crun;
            sudo apparmor_parser -r /etc/apparmor.d/crun 2>/dev/null;
        fi;
        echo 'Done!'; read -p 'Press Enter...'"
    else
        # Container entry — the glyphs in front are gone in Text Mode, so
        # take the name after them (names start with a letter or digit) and
        # route by membership, not by icon
        local sel_name
        sel_name=$(echo "$C_CHOICE" | sed -E 's/^[^[:alnum:]]*//; s/ \(.*//')
        if [ -n "$sel_name" ]; then
            if command -v docker &>/dev/null && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qxF "$sel_name"; then
                docker_action_menu "$sel_name"
            elif command -v distrobox &>/dev/null && distrobox list --no-color 2>/dev/null | awk -F'|' 'NR>1 {t=$2; gsub(/^ +| +$/,"",t); print t}' | grep -qxF "$sel_name"; then
                container_action_menu "$sel_name"
            fi
        fi
    fi
    done
}

container_create_menu() {
    local CR_OPTS="󰣖 Arch Linux - AUR, bleeding edge
󰣖 Alpine Linux - Minimal (5MB), musl
 Ubuntu - Stable, huge repos
 Fedora - Latest packages, DNF
󰣖 Kali Linux - Security & pentesting
󰣖 Parrot OS - Security & privacy
 openSUSE Tumbleweed - Rolling release
󰏫 Custom Image
󰌍 Back"

    local CR_CHOICE
    CR_CHOICE=$(echo -e "$CR_OPTS" | tfuzzel -d -p " 󰐊 New Container | ")

    [ -n "$CR_CHOICE" ] || menu_close
    if is_back "$CR_CHOICE"; then return; fi

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
        image=$(echo "" | tfuzzel -d -p " 󰏫 Image (e.g. debian:sid): ")
        if [ -z "$image" ]; then return; fi
        # Typed text ends up in a command line — only image-reference
        # characters, as for Docker below
        if [[ ! "$image" =~ ^[a-z0-9][a-z0-9._/:@-]*$ ]]; then
            tnotify "Containers" "Not a valid image name: $image"
            return
        fi
        box_name=$(echo "$image" | sed 's|.*/||;s|[:@].*||')
    fi

    [ -z "$image" ] && return

    # Check if name already exists (match the NAME column only — a plain grep
    # would also hit the IMAGE column, e.g. "ubuntu" matching ubuntu:latest)
    if distrobox list --no-color 2>/dev/null | awk -F'|' 'NR>1 {t=$2; gsub(/^ +| +$/,"",t); print t}' | grep -qxF "$box_name"; then
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
    status=$(distrobox list --no-color 2>/dev/null | awk -F'|' -v n="$name" 'NR>1 {t=$2; gsub(/^ +| +$/,"",t); if (t==n) print $3}' | xargs)
    local is_running=false
    [[ "$status" == *"Up"* ]] && is_running=true

    local A_OPTS=""
    A_OPTS+="󰆍 Enter $name\n"
    if $is_running; then
        A_OPTS+="󰅖 Stop $name\n"
    fi
    A_OPTS+="󰕒 Export App to Host Menu\n"
    A_OPTS+="󰒓 Configure $name\n"
    A_OPTS+="󰆴 Remove $name\n"
    A_OPTS+="󰌍 Back"

    local A_CHOICE
    A_CHOICE=$(echo -e "$A_OPTS" | tfuzzel -d -p " 󰡨 $name | ")

    if [ -z "$A_CHOICE" ] || is_back "$A_CHOICE"; then return; fi

    if [[ "$A_CHOICE" == *"Enter $name" ]]; then
        local image
        image=$(distrobox list --no-color 2>/dev/null | awk -F'|' -v n="$name" 'NR>1 {t=$2; gsub(/^ +| +$/,"",t); if (t==n) print $4}' | xargs)
        $TERM_CMD bash -c "
            echo '┌─────────────────────────────────────┐'
            echo '│  Entering container: $name'
            echo '│  Image: ${image:-unknown}'
            echo '│  Type \"exit\" to return to Tebian'
            echo '└─────────────────────────────────────┘'
            echo ''
            distrobox enter '$name' || { echo ''; echo 'Container failed to start. Check errors above.'; read -p 'Press Enter to close...'; }
        "
    # The labels hold the container's name, so match whole labels: with
    # =~ "Stop", picking "Configure Stopwatch" stopped the container
    elif [[ "$A_CHOICE" == *"Stop $name" ]]; then
        if distrobox stop "$name" -Y >/dev/null 2>&1; then
            tnotify "Containers" "$name stopped"
        else
            tnotify "Containers" "Could not stop $name"
        fi
    elif [[ "$A_CHOICE" == *"Export App to Host Menu" ]]; then
        container_export_menu "$name"
    elif [[ "$A_CHOICE" == *"Configure $name" ]]; then
        container_config_menu "$name"
    elif [[ "$A_CHOICE" == *"Remove $name" ]]; then
        local CONFIRM
        CONFIRM=$(echo -e "No, keep it\nYes, remove $name" | tfuzzel -d --match-mode=exact -p " Delete $name? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            if distrobox rm "$name" -f >/dev/null 2>&1; then
                tnotify "Containers" "$name removed"
            else
                tnotify "Containers" "Could not remove $name"
            fi
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
    APP_CHOICE=$(echo -e "$APP_OPTS" | tfuzzel -d -p " 󰕒 Export from $name | ")

    if [ -z "$APP_CHOICE" ] || is_back "$APP_CHOICE"; then return; fi

    # Find the .desktop file matching the selected app name. The name comes
    # from the container's packages, so it goes in as an argument, never
    # into the command text (this runs with your $HOME mounted)
    local desktop_file
    desktop_file=$(distrobox enter "$name" -- bash -c 'grep -rlxF -- "Name=$1" /usr/share/applications/ 2>/dev/null | head -1' _ "$APP_CHOICE" 2>/dev/null)

    if [ -n "$desktop_file" ]; then
        local app_id
        app_id=$(basename "$desktop_file" .desktop)
        if distrobox enter "$name" -- distrobox-export --app "$app_id" >/dev/null 2>&1; then
            tnotify "Export" "$APP_CHOICE exported to host app menu"
        else
            tnotify "Export" "Could not export $APP_CHOICE"
        fi
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
        A_OPTS+="󰅖 Stop $name\n"
    else
        A_OPTS+="󰐊 Start $name\n"
    fi
    A_OPTS+="󰋜 View Logs\n"
    A_OPTS+="󰆴 Remove $name\n"
    A_OPTS+="󰌍 Back"

    local A_CHOICE
    A_CHOICE=$(echo -e "$A_OPTS" | tfuzzel -d -p " 󰡨 $name | ")

    if [ -z "$A_CHOICE" ] || is_back "$A_CHOICE"; then return; fi

    # Whole labels, which hold the name: "Start Stopwatch" matched =~ "Stop"
    if [[ "$A_CHOICE" == *"Enter $name" ]]; then
        $TERM_CMD bash -c "
            echo 'Entering container: $name'
            echo 'Type \"exit\" to return to Tebian'
            echo ''
            docker start '$name' 2>/dev/null
            docker exec -it '$name' sh -c 'exec bash 2>/dev/null || exec sh' || { echo ''; echo 'Failed to enter container.'; read -p 'Press Enter to close...'; }
        "
    elif [[ "$A_CHOICE" == *"Stop $name" ]]; then
        if docker stop "$name" >/dev/null 2>&1; then
            tnotify "Docker" "$name stopped"
        else
            tnotify "Docker" "Could not stop $name"
        fi
    elif [[ "$A_CHOICE" == *"Start $name" ]]; then
        if docker start "$name" >/dev/null 2>&1; then
            tnotify "Docker" "$name started"
        else
            tnotify "Docker" "Could not start $name — see View Logs"
        fi
    elif [[ "$A_CHOICE" == *"View Logs" ]]; then
        $TERM_CMD bash -c "docker logs --tail 100 '$name' 2>&1; echo ''; read -p 'Press Enter to close...'"
    elif [[ "$A_CHOICE" == *"Remove $name" ]]; then
        local CONFIRM
        CONFIRM=$(echo -e "No, keep it\nYes, remove $name" | tfuzzel -d --match-mode=exact -p " Delete $name? | ")
        if [[ "$CONFIRM" =~ "Yes" ]]; then
            if docker rm -f "$name" >/dev/null 2>&1; then
                tnotify "Docker" "$name removed"
            else
                tnotify "Docker" "Could not remove $name"
            fi
        fi
    fi
}

docker_create_menu() {
    local CR_OPTS="󰣖 Alpine SSH Server (port 2222)
󰖟 Nginx Web Server (port 8080)
󰡨 PostgreSQL Database (port 5432)
 Redis Cache (port 6379)
󰏫 Custom Image
󰌍 Back"

    local CR_CHOICE
    CR_CHOICE=$(echo -e "$CR_OPTS" | tfuzzel -d -p " 󰡨 New Docker Container | ")

    [ -n "$CR_CHOICE" ] || menu_close
    if is_back "$CR_CHOICE"; then return; fi

    # Published ports bind to 127.0.0.1: Docker's own iptables rules bypass
    # UFW, so "0.0.0.0" would put these on the LAN (café WiFi included) no
    # matter what the firewall says. Passwords are random per container.
    # They reach docker through the environment ("-e NAME" with no value
    # takes it from there), never as arguments: the terminal's command
    # line, and a server's inside the container, can be read by any local
    # user in /proc.
    local image="" cname="" post_msg="" secret=""
    local -a run_args=()
    if [[ "$CR_CHOICE" =~ "Alpine SSH" ]]; then
        image="alpine:latest"
        cname="alpine-ssh"
        local pubkeys=""
        pubkeys=$(cat "$HOME"/.ssh/id_*.pub 2>/dev/null)
        if [ -n "$pubkeys" ]; then
            # Key login only — no password to leak
            run_args=(-p 127.0.0.1:2222:22 -e "AUTH_KEYS=$pubkeys" "$image" sh -c \
                'apk add --no-cache openssh && ssh-keygen -A && mkdir -p /root/.ssh && printf "%s\n" "$AUTH_KEYS" > /root/.ssh/authorized_keys && chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && printf "PermitRootLogin prohibit-password\nPasswordAuthentication no\n" >> /etc/ssh/sshd_config && exec /usr/sbin/sshd -D')
            post_msg="SSH: ssh root@localhost -p 2222 (logs in with your SSH key)"
        else
            secret=$(docker_random_secret)
            run_args=(-p 127.0.0.1:2222:22 -e ROOT_PW "$image" sh -c \
                'apk add --no-cache openssh && ssh-keygen -A && echo "root:$ROOT_PW" | chpasswd && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && exec /usr/sbin/sshd -D')
            post_msg="SSH: ssh root@localhost -p 2222"
        fi
    elif [[ "$CR_CHOICE" =~ "Nginx" ]]; then
        image="nginx:alpine"
        cname="nginx"
        run_args=(-p 127.0.0.1:8080:80 "$image")
        post_msg="Web server: http://localhost:8080"
    elif [[ "$CR_CHOICE" =~ "PostgreSQL" ]]; then
        image="postgres:16-alpine"
        cname="postgres"
        secret=$(docker_random_secret)
        run_args=(-p 127.0.0.1:5432:5432 -e POSTGRES_PASSWORD -v postgres_data:/var/lib/postgresql/data "$image")
        post_msg="Connect: psql -h localhost -U postgres"
        # POSTGRES_PASSWORD only applies when the data volume is created
        if docker volume inspect postgres_data >/dev/null 2>&1; then
            post_msg+=$'\nNote: the existing postgres_data volume keeps its old password — the one below is ignored.'
        fi
    elif [[ "$CR_CHOICE" =~ "Redis" ]]; then
        image="redis:alpine"
        cname="redis"
        secret=$(docker_random_secret)
        # Through a config file: --requirepass would put it in the server's
        # command line
        run_args=(-p 127.0.0.1:6379:6379 -e REDIS_PASSWORD "$image" sh -c \
            'printf "requirepass %s\n" "$REDIS_PASSWORD" > /tmp/redis.conf && unset REDIS_PASSWORD && exec redis-server /tmp/redis.conf')
        post_msg="Connect: redis-cli -h localhost --askpass"
    elif [[ "$CR_CHOICE" =~ "Custom" ]]; then
        image=$(echo "" | tfuzzel -d -p " 󰏫 Image (e.g. nginx:latest): ")
        [ -z "$image" ] && return
        # Typed text ends up in a command line — only image-reference characters
        if [[ ! "$image" =~ ^[a-z0-9][a-z0-9._/:@-]*$ ]]; then
            tnotify "Docker" "Not a valid image name: $image"
            return
        fi
        cname=$(echo "$image" | sed 's|.*/||;s|[:@].*||')
        run_args=("$image")
    fi

    [ -z "$image" ] && return

    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qxF "$cname"; then
        tnotify "Docker" "$cname already exists"
        return
    fi

    # Credentials are shown once in the terminal and kept in a file only the
    # user can read — not in notifications, which end up in mako's history
    local cred_file="$HOME/.config/tebian/docker-credentials"
    if [ -n "$secret" ]; then
        mkdir -p "$(dirname "$cred_file")"
        ( umask 077; printf '%s  %s  password: %s\n' "$(date '+%F %R')" "$cname" "$secret" >> "$cred_file" )
        chmod 600 "$cred_file"
    fi

    CNAME="$cname" POST_MSG="$post_msg" SECRET="$secret" CRED_FILE="$cred_file" \
    $TERM_CMD bash -c '
        echo "=== Creating $CNAME ==="
        echo ""
        if ROOT_PW="$SECRET" POSTGRES_PASSWORD="$SECRET" REDIS_PASSWORD="$SECRET" \
           docker run --name "$CNAME" -d "$@"; then
            echo ""
            echo "✅ $CNAME created (reachable from this computer only)."
            [ -n "$POST_MSG" ] && echo "" && echo "$POST_MSG"
            if [ -n "$SECRET" ]; then
                echo "Password: $SECRET"
                echo "(saved in $CRED_FILE)"
            fi
        else
            echo ""
            echo "❌ docker run failed."
        fi
        read -p "Press Enter to close..."
    ' _ "${run_args[@]}"
    # The terminal waits for docker run, so the container is there by now
    # if it worked; the terminal already said why if it did not
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qxF "$cname"; then
        if [ -n "$secret" ]; then
            tnotify "Docker" "$cname created — password saved in ~/.config/tebian/docker-credentials"
        else
            tnotify "Docker" "$cname created"
        fi
    else
        tnotify "Docker" "$cname was not created"
    fi
}

# 20 random URL-safe characters
docker_random_secret() {
    head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20
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

# Pick one of the values after the prompt and current one; the current one
# is marked. Prints the value, nothing on Escape or Back.
_infra_pick() {
    local prompt="$1" cur="$2" v rows="" pick
    shift 2
    for v in "$@"; do
        if [ "$v" = "$cur" ]; then rows+="$v  ● current\n"; else rows+="$v\n"; fi
    done
    pick=$(echo -e "${rows}󰌍 Back" | tfuzzel -d -p " $prompt | ")
    [ -n "$pick" ] && ! is_back "$pick" || return 0
    echo "${pick%  ● current}"
}

# Config menu for a VM
vm_config_menu() {
    local vm_name="$1" conf_file="$2" disk_file="$3"
    local cores ram disk_size

    while true; do
    cores=$(vm_conf_get "$conf_file" "cores" "4")
    ram=$(vm_conf_get "$conf_file" "ram" "4")
    disk_size=""
    if [ -n "$disk_file" ] && [ -f "$disk_file" ]; then
        disk_size=$(qemu-img info --output=json "$disk_file" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('virtual-size',0)//1073741824)" 2>/dev/null)
    fi

    local CFG_OPTS="󰘚 CPU Cores (Current: $cores)
󰍛 RAM (Current: ${ram} GB)"
    [ -n "$disk_size" ] && CFG_OPTS+="\n󰋊 Disk Size (Current: ${disk_size} GB)"
    CFG_OPTS+="\n󰌍 Back"

    local CFG_CHOICE
    CFG_CHOICE=$(echo -e "$CFG_OPTS" | tfuzzel -d -p " $vm_name Config | ")

    [ -n "$CFG_CHOICE" ] || menu_close
    if is_back "$CFG_CHOICE"; then return; fi

    if [[ "$CFG_CHOICE" =~ "CPU Cores" ]]; then
        local new_cores
        new_cores=$(_infra_pick "CPU Cores" "$cores" 1 2 4 6 8 12 16)
        if [ -n "$new_cores" ]; then
            vm_conf_set "$conf_file" "cores" "$new_cores"
            tnotify "$vm_name" "CPU set to $new_cores cores"
        fi
    elif [[ "$CFG_CHOICE" =~ "RAM" ]]; then
        local new_ram
        new_ram=$(_infra_pick "RAM (GB)" "$ram" 2 4 6 8 12 16 32)
        if [ -n "$new_ram" ]; then
            vm_conf_set "$conf_file" "ram" "$new_ram"
            tnotify "$vm_name" "RAM set to ${new_ram} GB"
        fi
    elif [[ "$CFG_CHOICE" =~ "Disk" ]]; then
        local new_disk
        # Only sizes it can grow to: a disk image is never shrunk
        local -a sizes=()
        local sz
        for sz in 32 64 128 256 512; do
            [ "$sz" -gt "$disk_size" ] && sizes+=("$sz")
        done
        if [ ${#sizes[@]} -eq 0 ]; then
            tnotify "$vm_name" "Disk is already ${disk_size} GB, the largest size offered"
            continue
        fi
        new_disk=$(_infra_pick "Grow disk to (GB, now ${disk_size})" "" "${sizes[@]}")
        if [ -n "$new_disk" ] && [ "$new_disk" -gt "$disk_size" ] 2>/dev/null; then
            # Fails on a running VM, whose image qemu holds locked
            if qemu-img resize "$disk_file" "${new_disk}G" >/dev/null 2>&1; then
                tnotify "$vm_name" "Disk grown to ${new_disk} GB"
            else
                tnotify "$vm_name" "Disk not resized — shut the VM down first"
            fi
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
    [ "$ram" = "0" ] && ram_label="No Limit" || ram_label="${ram} GB"

    local CFG_OPTS="󰘚 CPU Cores (Current: $cores_label)
󰍛 RAM Limit (Current: $ram_label)
󰌍 Back"

    local CFG_CHOICE
    CFG_CHOICE=$(echo -e "$CFG_OPTS" | tfuzzel -d -p " $name Config | ")

    [ -n "$CFG_CHOICE" ] || menu_close
    if is_back "$CFG_CHOICE"; then return; fi

    # The saved value is only what this menu shows, so it is saved only
    # once podman has applied it — otherwise the label claimed a limit the
    # container never got
    if [[ "$CFG_CHOICE" =~ "CPU Cores" ]]; then
        local new_cores
        new_cores=$(_infra_pick "CPU Cores" "$cores_label" "No Limit" 1 2 4 6 8)
        [ "$new_cores" = "No Limit" ] && new_cores=0
        if [ -z "$new_cores" ]; then
            :
        elif podman update --cpus "$new_cores" "$name" >/dev/null 2>&1; then
            vm_conf_set "$conf_file" "cores" "$new_cores"
            if [ "$new_cores" = 0 ]; then
                tnotify "$name" "CPU limit removed"
            else
                tnotify "$name" "CPU limited to $new_cores cores"
            fi
        else
            tnotify "$name" "Could not change the CPU limit"
        fi
    elif [[ "$CFG_CHOICE" =~ "RAM" ]]; then
        local new_ram
        new_ram=$(_infra_pick "RAM Limit (GB)" "${ram_label% GB}" "No Limit" 1 2 4 8 16)
        [ "$new_ram" = "No Limit" ] && new_ram=0
        if [ -z "$new_ram" ]; then
            :
        elif podman update --memory "$([ "$new_ram" = 0 ] && echo 0 || echo "${new_ram}g")" "$name" >/dev/null 2>&1; then
            vm_conf_set "$conf_file" "ram" "$new_ram"
            if [ "$new_ram" = 0 ]; then
                tnotify "$name" "RAM limit removed"
            else
                tnotify "$name" "RAM limited to ${new_ram} GB"
            fi
        else
            tnotify "$name" "Could not change the RAM limit"
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

    # Setup creates the empty virtual disk along with the installer, so
    # "disk exists" does not mean "installed": while the installer is there
    # Install is offered next to Launch. Showing only Launch hid the Install
    # step that Setup tells you to pick next, and booted an empty disk.
    local win_label=""
    [ -f "$VM_DIR/windows/windows.iso" ] && win_label+="󰍹 Install Windows 11 (Installer Ready)\n"
    [ -f "$VM_DIR/windows/windows.qcow2" ] && win_label+="󰍹 Launch Windows 11\n"
    [ -n "$win_label" ] || win_label="󰍹 Setup Windows 11 VM\n"

    local mac_label=""
    [ -f "$VM_DIR/macos/BaseSystem.img" ] && mac_label+="󰍹 Install macOS (Installer Ready)\n"
    [ -f "$VM_DIR/macos/mac_hdd.qcow2" ] && [ -f "$VM_DIR/macos/OpenCore.qcow2" ] &&
        mac_label+="󰍹 Launch macOS\n"
    [ -n "$mac_label" ] || mac_label="󰍹 Setup macOS VM\n"

    # Detect isolated workspace state
    local iso_label
    if command -v virsh &>/dev/null && virsh dominfo tebian-workstation &>/dev/null 2>&1; then
        local ws_state
        ws_state=$(virsh domstate tebian-workstation 2>/dev/null || echo "unknown")
        if [[ "$ws_state" == "running" ]]; then
            iso_label="󰗹 Secure Workspace (Running)"
        else
            iso_label="󰗹 Secure Workspace (Stopped)"
        fi
    else
        iso_label="󰗹 Secure Workspace (Not Set Up)"
    fi

    local VM_OPTS=""
    if ! $kvm_ok; then
        VM_OPTS+="󰚰 Virtual Machine Support [KVM/QEMU] (Not Installed)\n"
    fi
    # Both guests are x86 only and run on KVM: on an ARM board (a Pi) they
    # could only fail, so say why instead of offering them
    if [ "$(uname -m)" = x86_64 ]; then
        VM_OPTS+="$win_label"
        [ -f "$VM_DIR/windows/windows.qcow2" ] && VM_OPTS+="  Configure Windows VM\n"
        VM_OPTS+="$mac_label"
        [ -f "$VM_DIR/macos/mac_hdd.qcow2" ] && VM_OPTS+="  Configure macOS VM\n"
    else
        VM_OPTS+="󰍹 Windows and macOS VMs (Need an x86 PC)\n"
    fi
    VM_OPTS+="$iso_label\n"
    VM_OPTS+="󰌍 Back"

    V_CHOICE=$(echo -e "$VM_OPTS" | tfuzzel -d -p " 󰾵 VMs | ")

    [ -n "$V_CHOICE" ] || menu_close
    if is_back "$V_CHOICE"; then return; fi

    if [[ "$V_CHOICE" =~ "Virtual Machine Support" ]]; then
        vm_install_kvm
    elif [[ "$V_CHOICE" =~ "Need an x86 PC" ]]; then
        tnotify "VM" "Windows and macOS VMs need an x86-64 PC — this is $(uname -m)"
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

# True when qemu can use KVM; says why not otherwise
vm_kvm_usable() {
    # No device at all: virtualization is switched off in the firmware
    # (or the CPU has none) — logging out again would not help
    if [ ! -e /dev/kvm ]; then
        tnotify "VM" "Hardware virtualization is off — turn on VT-x / AMD-V (SVM) in your BIOS/UEFI settings"
        return 1
    fi
    # The usual failure right after installing KVM: the kvm group only
    # applies from the next login, and qemu then died with no message
    if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
        tnotify "VM" "No access to /dev/kvm yet — log out and back in, then try again"
        return 1
    fi
}

# Runs the macOS VM with the arguments given; qemu's errors go to a log
# and a notification instead of nowhere
vm_run_macos() {
    local VM_DIR="$HOME/VMs/macos"
    (
        if ! qemu-system-x86_64 "$@" 2> "$VM_DIR/qemu.log"; then
            notify-send -u critical "macOS VM stopped with an error" \
                "$(tail -n 3 "$VM_DIR/qemu.log") (full log: $VM_DIR/qemu.log)"
        fi
    ) >/dev/null 2>&1 < /dev/null &
}

# ── Windows VM ──

vm_setup_windows() {
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        tnotify "VM" "Install Virtual Machine Support first (top of this menu)"
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
        # Never over an existing disk: that is an installed Windows
        if [ -f "$VM_DIR/windows.qcow2" ]; then
            echo "Step 2: Keeping the existing virtual disk (windows.qcow2)."
        else
            echo "Step 2: Creating virtual disk (64GB)..."
            qemu-img create -f qcow2 "$VM_DIR/windows.qcow2" 64G
        fi
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

    if [ ! -f "$VM_DIR/windows.iso" ]; then
        tnotify "VM" "No Windows ISO found at ~/VMs/windows/windows.iso"
        return
    fi

    # Create disk if it doesn't exist
    [ -f "$VM_DIR/windows.qcow2" ] || qemu-img create -f qcow2 "$VM_DIR/windows.qcow2" 64G >/dev/null

    vm_run_windows install
}

vm_launch_windows() {
    local VM_DIR="$HOME/VMs/windows"

    if [ ! -f "$VM_DIR/windows.qcow2" ]; then
        tnotify "VM" "No Windows VM found. Run Setup first."
        return
    fi

    vm_run_windows launch
}

# Starts the Windows VM (with its TPM) detached from Settings, which used
# to sit in `wait` for the whole session: reopening Settings killed that
# waiting copy, so the TPM emulator was never stopped. Arg: install|launch
vm_run_windows() {
    local mode="$1" VM_DIR="$HOME/VMs/windows"
    local conf_file="$VM_DIR/vm.conf" cores ram disk_bus
    if ! command -v swtpm &>/dev/null; then
        tnotify "VM" "swtpm missing (Win11 needs TPM) — sudo apt install swtpm"
        return
    fi
    vm_kvm_usable || return
    cores=$(vm_conf_get "$conf_file" "cores" "4")
    ram=$(vm_conf_get "$conf_file" "ram" "4")
    # Windows Setup has no virtio disk or network driver, so a virtio disk
    # showed no drive to install to. NVMe and e1000e work out of the box.
    # disk_bus=virtio in vm.conf keeps a VM that has the virtio drivers.
    disk_bus=$(vm_conf_get "$conf_file" "disk_bus" "nvme")
    local -a disk=(-drive "file=$VM_DIR/windows.qcow2,format=qcow2,if=none,id=disk0")
    if [ "$disk_bus" = virtio ]; then
        disk+=(-device "virtio-blk-pci,drive=disk0")
    else
        disk+=(-device "nvme,drive=disk0,serial=tebian-win")
    fi
    local -a extra=()
    [ "$mode" = install ] && extra=(-cdrom "$VM_DIR/windows.iso" -boot d)

    tnotify "VM" "Starting Windows 11..."
    mkdir -p "$VM_DIR/tpm"
    # setsid: its own session, so it outlives Settings. --terminate stops
    # swtpm when qemu disconnects; the kill afterwards covers a qemu that
    # never connected. qemu's errors go to a log and a notification.
    setsid bash -c '
        VM_DIR="$1"; shift
        swtpm socket --tpmstate dir="$VM_DIR/tpm" \
            --ctrl type=unixio,path="$VM_DIR/tpm/swtpm-sock" \
            --tpm2 --terminate --log level=0 &
        tpm_pid=$!
        sleep 1
        if ! qemu-system-x86_64 "$@" 2> "$VM_DIR/qemu.log"; then
            notify-send -u critical "Windows VM stopped with an error" \
                "$(tail -n 3 "$VM_DIR/qemu.log") (full log: $VM_DIR/qemu.log)"
        fi
        kill "$tpm_pid" 2>/dev/null
    ' _ "$VM_DIR" \
        -name "Windows 11" \
        -machine q35,accel=kvm \
        -cpu host \
        -smp "cores=$cores" \
        -m "${ram}G" \
        "${disk[@]}" \
        "${extra[@]}" \
        -bios /usr/share/ovmf/OVMF.fd \
        -chardev socket,id=chrtpm,path="$VM_DIR/tpm/swtpm-sock" \
        -tpmdev emulator,id=tpm0,chardev=chrtpm \
        -device tpm-tis,tpmdev=tpm0 \
        -device e1000e,netdev=net0 \
        -netdev user,id=net0 \
        -device virtio-vga-gl,xres=1280,yres=720 \
        -display sdl,gl=on \
        -device qemu-xhci \
        -device usb-tablet \
        -audiodev pipewire,id=audio0 \
        -device intel-hda -device hda-duplex,audiodev=audio0 \
        >/dev/null 2>&1 < /dev/null &
}

# ── macOS VM ──

vm_setup_macos() {
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        tnotify "VM" "Install Virtual Machine Support first (top of this menu)"
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

        fail() { echo ""; echo "❌ $1 — nothing after this step was done."; read -p "Press Enter to close..."; exit 1; }

        # OSX-KVM is a third-party repo whose script runs here, so it is
        # pinned to one commit rather than whatever HEAD is that day.
        # Bump it after looking at what changed upstream.
        OSXKVM_COMMIT=4c378a4b5e0b219783683012bec680325eb40719
        if [ ! -d "$VM_DIR/OSX-KVM/.git" ]; then
            echo "Cloning OSX-KVM..."
            git init -q "$VM_DIR/OSX-KVM" &&
                git -C "$VM_DIR/OSX-KVM" remote add origin https://github.com/kholia/OSX-KVM.git ||
                fail "Could not set up the OSX-KVM folder"
        fi
        if [ "$(git -C "$VM_DIR/OSX-KVM" rev-parse HEAD 2>/dev/null)" != "$OSXKVM_COMMIT" ]; then
            git -C "$VM_DIR/OSX-KVM" fetch -q --depth 1 origin "$OSXKVM_COMMIT" &&
                git -C "$VM_DIR/OSX-KVM" -c advice.detachedHead=false checkout -q "$OSXKVM_COMMIT" ||
                fail "Could not fetch OSX-KVM"
        fi
        cd "$VM_DIR/OSX-KVM" || fail "OSX-KVM folder missing"

        echo ""
        echo "Fetching macOS installer from Apple..."
        echo "You will be asked which version to download."
        echo ""
        ./fetch-macOS-v2.py || fail "The macOS download did not finish"
        [ -f BaseSystem.dmg ] || fail "No BaseSystem.dmg was downloaded"

        echo ""
        echo "Converting BaseSystem to raw image..."
        qemu-img convert BaseSystem.dmg -O raw "$VM_DIR/BaseSystem.img" || fail "Could not convert BaseSystem.dmg"

        echo ""
        echo "Creating OpenCore boot image..."
        cp "$VM_DIR/OSX-KVM/OpenCore/OpenCore.qcow2" "$VM_DIR/OpenCore.qcow2" || fail "Could not copy OpenCore"

        echo ""
        # Never over an existing disk: that is an installed macOS
        if [ -f "$VM_DIR/mac_hdd.qcow2" ]; then
            echo "Keeping the existing virtual disk (mac_hdd.qcow2)."
        else
            echo "Creating virtual disk (64GB)..."
            qemu-img create -f qcow2 "$VM_DIR/mac_hdd.qcow2" 64G || fail "Could not create the virtual disk"
        fi

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

    vm_kvm_usable || return
    # A setup that stopped halfway leaves the base system without the boot
    # loader or firmware; qemu then failed with nothing on screen
    [ -f "$VM_DIR/OpenCore.qcow2" ] || cp "$VM_DIR/OSX-KVM/OpenCore/OpenCore.qcow2" "$VM_DIR/OpenCore.qcow2" 2>/dev/null
    if [ ! -f "$VM_DIR/OpenCore.qcow2" ] || [ ! -f "$VM_DIR/OSX-KVM/OVMF_CODE.fd" ]; then
        tnotify "VM" "macOS setup is incomplete — finishing it"
        vm_setup_macos
        return
    fi
    [ -f "$VM_DIR/mac_hdd.qcow2" ] || qemu-img create -f qcow2 "$VM_DIR/mac_hdd.qcow2" 64G >/dev/null

    local cores=$(vm_conf_get "$conf_file" "cores" "4")
    local ram=$(vm_conf_get "$conf_file" "ram" "4")

    tnotify "VM" "Starting macOS installer..."

    vm_run_macos \
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
        -usb -device usb-kbd
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

    vm_kvm_usable || return
    if [ ! -f "$VM_DIR/OSX-KVM/OVMF_CODE.fd" ]; then
        tnotify "VM" "macOS setup is incomplete — finishing it"
        vm_setup_macos
        return
    fi

    tnotify "VM" "Launching macOS..."

    vm_run_macos \
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
        -usb -device usb-kbd
}

tlink_menu() {
    while true; do
    TL_OPTS="󰌄 Fleet Management (Servers & Deploy)
󰖟 Network Setup (Tailscale)
󰌾 VPN (WireGuard)
󰋜 Quick Status
󰌍 Back"

    TL_CHOICE=$(echo -e "$TL_OPTS" | tfuzzel -d -p " 󰌄 T-Link | ")

    [ -n "$TL_CHOICE" ] || menu_close
    if is_back "$TL_CHOICE"; then return; fi

    if [[ "$TL_CHOICE" =~ "Fleet Management" ]]; then
        # Its own menus, in their own process: it exits non-zero when it
        # was closed with Escape, which closes Settings too
        tebian-tlink || menu_close
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
    # State shows on the rows themselves: the tunnel that is up is marked
    # current and has a Disconnect row, rather than an inert status line
    WG_IFACE=""
    if ! command -v wg &>/dev/null; then
        VPN_OPTS="󰏗 WireGuard (Not Installed)"
    else
        # Detect the active tunnel without root — `sudo -n wg show` fails
        # whenever sudo creds aren't cached (the normal fuzzel-launched case)
        WG_IFACE=$(ip -o link show type wireguard 2>/dev/null | head -1 | awk -F': ' '{print $2}')
        VPN_OPTS=""
        if [ -n "$WG_IFACE" ]; then
            VPN_OPTS+="󰅖 Disconnect ($WG_IFACE)"
        fi
        # List available configs — /etc/wireguard is root-only (0700), so merge
        # a direct listing (if readable), a cached-sudo listing, and the names
        # recorded at import time in the user-readable list
        WG_CONFIGS=$({
            ls /etc/wireguard/*.conf 2>/dev/null | xargs -n1 basename 2>/dev/null
            sudo -n find /etc/wireguard -maxdepth 1 -name '*.conf' -printf '%f\n' 2>/dev/null
            cat "$HOME/.config/tebian/wireguard.list" 2>/dev/null
        } | sed 's/\.conf$//' | sort -u)
        if [ -n "$WG_CONFIGS" ]; then
            for cfg in $WG_CONFIGS; do
                if [ "$cfg" = "$WG_IFACE" ]; then
                    VPN_OPTS+="\n󰐊 Connect: $cfg  ● current"
                else
                    VPN_OPTS+="\n󰐊 Connect: $cfg"
                fi
            done
        fi
        VPN_OPTS+="\n󰏫 Import Config File"
        VPN_OPTS+="\n󰌆 Generate Keypair"
        VPN_OPTS="${VPN_OPTS#\\n}"
    fi

    VPN_OPTS+="\n󰌍 Back"

    VP_CHOICE=$(echo -e "$VPN_OPTS" | tfuzzel -d -p " 󰌾 VPN | ")

    [ -n "$VP_CHOICE" ] || menu_close
    if is_back "$VP_CHOICE"; then return; fi

    if [[ "$VP_CHOICE" == *"WireGuard (Not Installed)"* ]]; then
        $TERM_CMD bash -c "echo 'Installing WireGuard...';
        sudo apt update && sudo apt install -y wireguard wireguard-tools;
        echo '';
        echo '✅ WireGuard installed.';
        echo 'Import a .conf file or generate keys to get started.';
        read -p 'Press Enter to close...'"
    elif [[ "$VP_CHOICE" =~ "Disconnect" ]]; then
        # wg-quick only takes down tunnels it brought up; one NetworkManager
        # manages goes down through nmcli instead
        WG_IFACE="$WG_IFACE" $TERM_CMD bash -c 'echo "Disconnecting WireGuard ($WG_IFACE)..."
        if sudo wg-quick down "$WG_IFACE" 2>/dev/null || nmcli connection down "$WG_IFACE" 2>/dev/null; then
            echo "Disconnected."
        else
            echo "❌ $WG_IFACE is still up: neither wg-quick nor NetworkManager manages it."
        fi
        read -p "Press Enter to close..."'
    elif [[ "$VP_CHOICE" =~ "Connect:" ]]; then
        TUNNEL=$(echo "$VP_CHOICE" | sed 's/.*Connect: //; s/  ● current$//')
        # The name comes from a file the user can edit and goes to sudo:
        # only what wg-quick itself accepts as an interface name
        if [[ ! "$TUNNEL" =~ ^[a-zA-Z0-9_=+.-]{1,15}$ ]]; then
            tnotify "VPN" "Not a valid tunnel name: $TUNNEL"
            continue
        fi
        if [ "$TUNNEL" = "$WG_IFACE" ]; then
            tnotify "VPN" "Already connected to $TUNNEL"
            continue
        fi
        TUNNEL="$TUNNEL" $TERM_CMD bash -c 'echo "Connecting to $TUNNEL...";
        sudo wg-quick up "$TUNNEL";
        echo "";
        sudo wg show;
        echo "";
        read -p "Press Enter to close..."'
        if ip -o link show type wireguard 2>/dev/null | grep -q ": $TUNNEL:"; then
            tnotify "VPN" "Connected to $TUNNEL"
        fi
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
            mkdir -p \"\$HOME/.config/tebian\";
            grep -qxF \"\${CONF_NAME%.conf}\" \"\$HOME/.config/tebian/wireguard.list\" 2>/dev/null || echo \"\${CONF_NAME%.conf}\" >> \"\$HOME/.config/tebian/wireguard.list\";
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
        TS_STATUS=$(tailscale status --json 2>/dev/null | grep -q '"BackendState": *"Running"' && echo "Active" || echo "Inactive")
        TS_IP=$(tailscale ip -4 2>/dev/null)
        
        # One switch row: picking it connects or disconnects
        if [ "$TS_STATUS" == "Active" ]; then
            TL_LABEL="󰖟 Tailscale (ON${TS_IP:+: $TS_IP})"
        else
            TL_LABEL="󰖟 Tailscale (OFF)"
        fi

        TL_OPTS="$TL_LABEL
󰌄 Connect to Headscale (Self-Hosted)
󰋜 Show Network Status
󰌍 Back"
    else
        TL_OPTS="󰏗 Tailscale (Not Installed)
󰌍 Back"
    fi

    TL_CHOICE=$(echo -e "$TL_OPTS" | tfuzzel -d -p " 󰖟 Network | ")

    [ -n "$TL_CHOICE" ] || menu_close
    if is_back "$TL_CHOICE"; then return; fi

    if [[ "$TL_CHOICE" == *"Tailscale (Not Installed)"* ]]; then
        # Same pinned-key path as tebian-browser: the key is checked against
        # Tailscale's published fingerprint, and the deb line is written
        # here rather than taken from their server, so neither a swapped key
        # nor a swapped .list can add an apt source trusted as root.
        # Tailscale signs every Debian suite with this one key (2020).
        $TERM_CMD bash -c '
            fail() { echo ""; echo "❌ $1"; read -p "Press Enter..."; exit 1; }
            source "$TEBIAN_COMMON"
            echo "Installing Tailscale from its apt repository..."
            echo ""
            codename=$(. /etc/os-release && echo "${VERSION_CODENAME:-}")
            case "$codename" in
                bookworm|trixie) ;;
                *) fail "No Tailscale repository known for \"${codename:-this release}\". See tailscale.com/download/linux." ;;
            esac
            sudo -v || fail "Authentication failed."
            # gnupg checks the key; not in a minimal Debian
            sudo apt update
            sudo apt install -y gnupg curl ca-certificates || fail "Could not install gnupg."
            tebian_apt_repo_add "https://pkgs.tailscale.com/stable/debian/$codename.asc" \
                2596A99EAAB33821893C0A79458CA832957F5868 \
                /usr/share/keyrings/tailscale-archive-keyring.gpg \
                /etc/apt/sources.list.d/tailscale.list \
                "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian $codename main" ||
                fail "The Tailscale repository was not added."
            sudo apt update && sudo apt install -y tailscale || fail "Tailscale did not install."
            echo ""
            echo "✅ Tailscale installed. Pick \"Tailscale (OFF)\" to sign in."
            read -p "Press Enter..."
        '
    elif [[ "$TL_CHOICE" == *"Tailscale (OFF)"* ]]; then
        $TERM_CMD bash -c "sudo tailscale up && echo '✅ Connected.' || echo '❌ Not connected — see above.'; read -p 'Press Enter...'"
    elif [[ "$TL_CHOICE" == *"Tailscale (ON"* ]]; then
        $TERM_CMD bash -c "sudo tailscale down && echo 'Disconnected.' || echo '❌ Still connected — see above.'; read -p 'Press Enter...'"
    elif [[ "$TL_CHOICE" =~ "Headscale" ]]; then
        SERVER_URL=$(echo "" | tfuzzel -d -p " 󰌄 Headscale URL (https://...): ")
        if [ -z "$SERVER_URL" ]; then
            :
        elif [[ ! "$SERVER_URL" =~ ^https?://[^[:space:]]+$ ]]; then
            tnotify "Tailscale" "Not a server address: $SERVER_URL (it starts with https://)"
        else
            HEADSCALE_URL="$SERVER_URL" $TERM_CMD bash -c 'sudo tailscale up --login-server "$HEADSCALE_URL" && echo "✅ Connected." || echo "❌ Not connected — see above."; read -p "Press Enter..."'
        fi
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
        TS_STATUS=$(tailscale status --json 2>/dev/null | grep -q '"BackendState": *"Running"' && echo "Connected" || echo "Inactive")
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
    [ -n "$CHOICE" ] || menu_close
    # Back (or any line) returns to tlink_menu's while loop
}

