#!/bin/bash
set -uo pipefail

# ============================================================================
# Dotfiles Bootstrap Script
# Run with: curl -sL https://s.ras.band/setup | bash
#
# Wrapped in main() so bash fully buffers the script before executing.
# This prevents curl | bash from stalling on interactive reads.
# ============================================================================

main() {

read -rsp "This script requires sudo. Enter your password: " SUDO_PASS </dev/tty
echo ""
if ! echo "$SUDO_PASS" | sudo -S true 2>/dev/null; then
    echo "Incorrect password. Exiting."
    exit 1
fi

# Keep sudo token alive in the background for the duration of the script
( while true; do echo "$SUDO_PASS" | sudo -Sv 2>/dev/null; sleep 50; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

export ANSIBLE_BECOME_PASS="$SUDO_PASS"

REPO="Rasbandit/dotfiles-v2"
BRANCH="main"

CHEZMOI_DIR="$HOME/.config/chezmoi"
MACHINE_TYPE_FILE="$CHEZMOI_DIR/machine-type"
FEATURES_FILE="$CHEZMOI_DIR/features"

echo "============================================"
echo "  Dotfiles Bootstrap - Setting up machine  "
echo "============================================"
echo ""

# ============================================================================
# Detect OS
# ============================================================================
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS. Exiting."
    exit 1
fi

echo "Detected OS: $OS"
echo ""

# ============================================================================
# Environment detection functions
# ============================================================================

detect_environment() {
    # Virtualization
    ENV_VIRT_TYPE=""
    if command -v systemd-detect-virt &>/dev/null; then
        ENV_VIRT_TYPE=$(systemd-detect-virt 2>/dev/null || true)
    fi
    ENV_IS_CONTAINER=false
    if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
        ENV_IS_CONTAINER=true
    elif [ "$ENV_VIRT_TYPE" = "docker" ] || [ "$ENV_VIRT_TYPE" = "podman" ] \
      || [ "$ENV_VIRT_TYPE" = "lxc" ] || [ "$ENV_VIRT_TYPE" = "lxc-libvirt" ] \
      || [ "$ENV_VIRT_TYPE" = "systemd-nspawn" ] || [ "$ENV_VIRT_TYPE" = "wsl" ]; then
        ENV_IS_CONTAINER=true
    fi

    # WSL
    ENV_IS_WSL=false
    if grep -qi microsoft /proc/version 2>/dev/null; then
        ENV_IS_WSL=true
    fi

    # Cloud provider
    ENV_CLOUD=""
    if [ -f /sys/class/dmi/id/product_name ]; then
        local product
        product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
        case "$product" in
            *"Google Compute"*|*"Google"*)   ENV_CLOUD="gcp" ;;
            *"Amazon"*|*"aws"*)              ENV_CLOUD="aws" ;;
            *"Microsoft"*|*"Virtual Machine"*) ENV_CLOUD="azure" ;;
            *"Droplet"*|*"DigitalOcean"*)    ENV_CLOUD="digitalocean" ;;
            *"Vultr"*)                       ENV_CLOUD="vultr" ;;
            *"Linode"*|*"Akamai"*)           ENV_CLOUD="linode" ;;
        esac
    fi
    if [ -z "$ENV_CLOUD" ] && command -v cloud-init &>/dev/null; then
        ENV_CLOUD="cloud-init-present"
    fi

    # Desktop environment
    ENV_DESKTOP="${XDG_CURRENT_DESKTOP:-}"
    [ -z "$ENV_DESKTOP" ] && ENV_DESKTOP="${DESKTOP_SESSION:-}"

    # Display server
    ENV_DISPLAY=""
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        ENV_DISPLAY="Wayland (${WAYLAND_DISPLAY})"
    elif [ -n "${DISPLAY:-}" ]; then
        ENV_DISPLAY="X11 (${DISPLAY})"
    fi

    # Systemd target
    ENV_SYSTEMD_TARGET=""
    if command -v systemctl &>/dev/null; then
        ENV_SYSTEMD_TARGET=$(systemctl get-default 2>/dev/null || true)
    fi

    # DE packages installed
    ENV_DE_PACKAGES=""
    command -v gnome-shell &>/dev/null && ENV_DE_PACKAGES="gnome-shell"
    command -v plasmashell &>/dev/null && ENV_DE_PACKAGES="${ENV_DE_PACKAGES:+$ENV_DE_PACKAGES }plasmashell"
    command -v xfce4-session &>/dev/null && ENV_DE_PACKAGES="${ENV_DE_PACKAGES:+$ENV_DE_PACKAGES }xfce4-session"

    # SSH
    ENV_VIA_SSH=false
    if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]; then
        ENV_VIA_SSH=true
    fi

    # Chassis type
    ENV_CHASSIS=""
    ENV_CHASSIS_TYPE=""
    if [ -f /sys/class/dmi/id/chassis_type ]; then
        local chassis_id
        chassis_id=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)
        case "$chassis_id" in
            3|4|5|6|7)    ENV_CHASSIS="desktop";  ENV_CHASSIS_TYPE="$chassis_id" ;;
            8|9|10|11|14) ENV_CHASSIS="laptop";   ENV_CHASSIS_TYPE="$chassis_id" ;;
            17|23)        ENV_CHASSIS="server";   ENV_CHASSIS_TYPE="$chassis_id" ;;
            *)            ENV_CHASSIS="unknown";  ENV_CHASSIS_TYPE="$chassis_id" ;;
        esac
    fi

    # Battery
    ENV_HAS_BATTERY=false
    if ls /sys/class/power_supply/BAT* &>/dev/null 2>&1; then
        ENV_HAS_BATTERY=true
    fi

    # Raspberry Pi
    ENV_IS_RPI=false
    ENV_RPI_MODEL=""
    if [ -f /proc/device-tree/model ]; then
        ENV_RPI_MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || true)
        case "$ENV_RPI_MODEL" in
            *"Raspberry Pi"*) ENV_IS_RPI=true ;;
        esac
    fi

    # Platform summary
    ENV_PLATFORM="bare metal"
    if [ "$ENV_IS_CONTAINER" = true ]; then
        ENV_PLATFORM="container (${ENV_VIRT_TYPE:-detected})"
    elif [ "$ENV_IS_WSL" = true ]; then
        ENV_PLATFORM="WSL"
    elif [ -n "$ENV_CLOUD" ]; then
        ENV_PLATFORM="cloud VM ($ENV_CLOUD)"
    elif [ -n "$ENV_VIRT_TYPE" ] && [ "$ENV_VIRT_TYPE" != "none" ]; then
        ENV_PLATFORM="VM ($ENV_VIRT_TYPE)"
    fi
}

determine_machine_type() {
    SUGGESTED_TYPE=""
    CONFIDENCE=""
    REASONS=()

    # Rule 1: Container (not WSL) → temporary
    if [ "$ENV_IS_CONTAINER" = true ] && [ "$ENV_IS_WSL" = false ]; then
        SUGGESTED_TYPE="temporary"
        CONFIDENCE="high"
        REASONS+=("Container environment (${ENV_VIRT_TYPE:-detected}) — ephemeral by nature")
        return
    fi

    # Rule 2: WSL → workstation
    if [ "$ENV_IS_WSL" = true ]; then
        SUGGESTED_TYPE="workstation"
        CONFIDENCE="medium"
        REASONS+=("Windows Subsystem for Linux — dev environment parity with host")
        return
    fi

    # Rule 3: Active desktop session (DE + display) → workstation
    if [ -n "$ENV_DESKTOP" ] && [ -n "$ENV_DISPLAY" ]; then
        SUGGESTED_TYPE="workstation"
        CONFIDENCE="high"
        REASONS+=("Active desktop session: $ENV_DESKTOP on $ENV_DISPLAY")
        [ "$ENV_HAS_BATTERY" = true ] && REASONS+=("Battery present (laptop hardware)")
        [ "$ENV_VIA_SSH" = true ] && REASONS+=("Note: connected via SSH")
        return
    fi

    # Rule 4: Cloud VM + no desktop + multi-user target → server
    if [ -n "$ENV_CLOUD" ] && [ -z "$ENV_DESKTOP" ] \
      && [ "$ENV_SYSTEMD_TARGET" = "multi-user.target" ]; then
        SUGGESTED_TYPE="server"
        CONFIDENCE="high"
        REASONS+=("Cloud VM ($ENV_CLOUD) with no desktop environment")
        REASONS+=("Systemd target: multi-user.target")
        return
    fi

    # Rule 5: Headless (no graphical target + no DE + no DE packages) → server
    if [ "$ENV_SYSTEMD_TARGET" != "graphical.target" ] \
      && [ -z "$ENV_DESKTOP" ] && [ -z "$ENV_DE_PACKAGES" ]; then
        SUGGESTED_TYPE="server"
        CONFIDENCE="high"
        REASONS+=("No graphical target, no desktop environment, no DE packages")
        [ "$ENV_IS_RPI" = true ] && REASONS+=("Raspberry Pi: $ENV_RPI_MODEL")
        [ -n "$ENV_CLOUD" ] && REASONS+=("Cloud provider: $ENV_CLOUD")
        return
    fi

    # Rule 6: Graphical target set but no active session → workstation
    if [ "$ENV_SYSTEMD_TARGET" = "graphical.target" ]; then
        SUGGESTED_TYPE="workstation"
        if [ -n "$ENV_DE_PACKAGES" ]; then
            CONFIDENCE="high"
            REASONS+=("Graphical target with DE packages installed: $ENV_DE_PACKAGES")
        else
            CONFIDENCE="medium"
            REASONS+=("Graphical target set, but no DE packages detected")
        fi
        [ "$ENV_VIA_SSH" = true ] && REASONS+=("Note: connected via SSH (session may not be visible)")
        return
    fi

    # Rule 7: DE packages installed but multi-user target → workstation (low)
    if [ -n "$ENV_DE_PACKAGES" ] && [ "$ENV_SYSTEMD_TARGET" = "multi-user.target" ]; then
        SUGGESTED_TYPE="workstation"
        CONFIDENCE="low"
        REASONS+=("DE packages installed ($ENV_DE_PACKAGES) but multi-user target")
        return
    fi

    # Rule 8: Battery present → workstation (medium)
    if [ "$ENV_HAS_BATTERY" = true ]; then
        SUGGESTED_TYPE="workstation"
        CONFIDENCE="medium"
        REASONS+=("Battery present (laptop hardware) but no GUI signals")
        return
    fi

    # Rule 9: Chassis hint
    if [ -n "$ENV_CHASSIS" ] && [ "$ENV_CHASSIS" != "unknown" ]; then
        case "$ENV_CHASSIS" in
            laptop|desktop)
                SUGGESTED_TYPE="workstation"
                CONFIDENCE="low"
                REASONS+=("Chassis type: $ENV_CHASSIS (DMI type $ENV_CHASSIS_TYPE)")
                ;;
            server)
                SUGGESTED_TYPE="server"
                CONFIDENCE="medium"
                REASONS+=("Chassis type: server (DMI type $ENV_CHASSIS_TYPE)")
                ;;
        esac
        if [ -n "$SUGGESTED_TYPE" ]; then
            return
        fi
    fi

    # Rule 10: Fallback
    SUGGESTED_TYPE="workstation"
    CONFIDENCE="low"
    REASONS+=("No strong signals detected — defaulting to workstation")
}

# Arrow-key interactive selector
# Usage: arrow_select RESULT_VAR selected_index label1 label2 [label3 ...]
# Reads from /dev/tty. Sets RESULT_VAR to the chosen index (0-based).
arrow_select() {
    local result_var="$1"
    local selected="$2"
    shift 2
    local -a labels=("$@")
    local count=${#labels[@]}

    # ANSI codes
    local bold="\033[1m"
    local rev="\033[7m"
    local dim="\033[2m"
    local reset="\033[0m"
    local hide_cursor="\033[?25l"
    local show_cursor="\033[?25h"

    # Draw all options + instruction line, each on its own line
    _draw_options() {
        for i in $(seq 0 $((count - 1))); do
            if [ "$i" -eq "$selected" ]; then
                printf "\r\033[2K  ${rev}${bold} > %s ${reset}\n" "${labels[$i]}" >/dev/tty
            else
                printf "\r\033[2K    ${dim}%s${reset}\n" "${labels[$i]}" >/dev/tty
            fi
        done
        printf "\r\033[2K  ↑/↓ to move, Enter to confirm" >/dev/tty
    }

    printf "$hide_cursor" >/dev/tty
    _draw_options

    while true; do
        # Read a single character (raw mode)
        IFS= read -rsn1 key </dev/tty || true

        if [ "$key" = "" ]; then
            # Enter pressed
            break
        elif [ "$key" = $'\x1b' ]; then
            # Escape sequence — read next two chars
            IFS= read -rsn2 seq </dev/tty
            case "$seq" in
                "[A") # Up arrow
                    selected=$(( (selected - 1 + count) % count ))
                    ;;
                "[B") # Down arrow
                    selected=$(( (selected + 1) % count ))
                    ;;
            esac
            # Move cursor up: count lines for options (instruction line has no \n)
            printf "\033[%dA" "$count" >/dev/tty
            _draw_options
        fi
    done

    # Clear the instruction line, show cursor
    printf "\r\033[2K" >/dev/tty
    printf "$show_cursor" >/dev/tty

    eval "$result_var=$selected"
}

show_detection_and_prompt() {
    local update_mode="$1"
    local existing_type="${2:-}"

    # Build one-line detection summary
    local -a signals=("$ENV_PLATFORM")
    [ -n "$ENV_CHASSIS" ] && [ "$ENV_CHASSIS" != "unknown" ] && signals+=("$ENV_CHASSIS")
    [ "$ENV_HAS_BATTERY" = true ] && signals+=("battery")
    [ -n "$ENV_DESKTOP" ] && signals+=("$ENV_DESKTOP")
    [ -n "$ENV_DISPLAY" ] && signals+=("$ENV_DISPLAY")
    [ -n "$ENV_SYSTEMD_TARGET" ] && signals+=("$ENV_SYSTEMD_TARGET")
    [ "$ENV_VIA_SSH" = true ] && signals+=("via SSH")
    [ "$ENV_IS_RPI" = true ] && signals+=("$ENV_RPI_MODEL")

    local summary=""
    for s in "${signals[@]}"; do
        summary="${summary:+$summary · }$s"
    done
    echo "  Detected: $summary"
    echo ""

    # Fixed option order with inline tags
    local -a types=("workstation" "server" "temporary")
    local -a descs=("full setup" "persistent headless" "creature comforts")

    if [ "$update_mode" = true ]; then
        echo "  Machine type?  (currently: $existing_type)"
    else
        echo "  Machine type?"
    fi
    echo ""

    # Build display labels with tags
    local -a labels=()
    for i in 0 1 2; do
        local tag=""
        if [ "${types[$i]}" = "$SUGGESTED_TYPE" ] && [ "${types[$i]}" = "$existing_type" ]; then
            tag="  [current, suggested]"
        elif [ "${types[$i]}" = "$SUGGESTED_TYPE" ]; then
            tag="  [suggested]"
        elif [ "${types[$i]}" = "$existing_type" ] && [ "$update_mode" = true ]; then
            tag="  [current]"
        fi
        labels+=("$(printf "%-12s — %-20s%s" "${types[$i]}" "${descs[$i]}" "$tag")")
    done

    # Determine which option to pre-select
    local default_type="$SUGGESTED_TYPE"
    [ "$update_mode" = true ] && default_type="$existing_type"

    local default_idx=0
    for i in 0 1 2; do
        [ "${types[$i]}" = "$default_type" ] && default_idx="$i"
    done

    local chosen_idx
    arrow_select chosen_idx "$default_idx" "${labels[@]}"

    MACHINE_TYPE="${types[$chosen_idx]}"
}

# ============================================================================
# Detect existing setup (update mode)
# ============================================================================
EXISTING_TYPE=""
EXISTING_FEATURES=""
UPDATE_MODE=false

if [ -f "$MACHINE_TYPE_FILE" ]; then
    EXISTING_TYPE=$(tr -d '[:space:]' < "$MACHINE_TYPE_FILE")
    EXISTING_FEATURES=""
    [ -f "$FEATURES_FILE" ] && EXISTING_FEATURES=$(tr -d '\n' < "$FEATURES_FILE")
    UPDATE_MODE=true

    echo "Existing setup detected:"
    echo "  Type:     $EXISTING_TYPE"
    echo "  Features: ${EXISTING_FEATURES:-none}"
    echo ""
    read -rp "Update this machine? [Y/n]: " update_choice </dev/tty
    case "${update_choice:-Y}" in
        [Yy]*|"") : ;;
        *) echo "Exiting."; exit 0 ;;
    esac
    echo ""
fi

# ============================================================================
# Detect environment and prompt for machine type
# ============================================================================
detect_environment
determine_machine_type
show_detection_and_prompt "$UPDATE_MODE" "$EXISTING_TYPE"

echo ""

# ============================================================================
# Path: Temporary (shallow clone, no chezmoi, no auth)
# ============================================================================
if [ "$MACHINE_TYPE" = "temporary" ]; then
    echo "--- Temporary setup ---"
    echo ""

    echo "[1/5] Installing prerequisites (git + ansible)..."
    case $OS in
        fedora)        sudo dnf install -y git ansible ;;
        ubuntu|debian) sudo apt update -q && sudo apt install -y git ansible ;;
        arch)          sudo pacman -Sy --noconfirm git ansible ;;
        *)             echo "Unsupported OS: $OS"; exit 1 ;;
    esac

    echo "[2/5] Cloning dotfiles (shallow)..."
    TMPCLONE=$(mktemp -d)
    git clone --depth=1 --branch "$BRANCH" "https://github.com/$REPO.git" "$TMPCLONE/dotfiles"

    echo "[3/5] Copying config files..."
    mkdir -p ~/.config
    cp "$TMPCLONE/dotfiles/dot_aliases"        ~/.aliases
    cp "$TMPCLONE/dotfiles/dot_bash_functions" ~/.bash_functions
    cp "$TMPCLONE/dotfiles/dot_bashrc"         ~/.bashrc
    cp "$TMPCLONE/dotfiles/private_dot_config/starship.toml" ~/.config/starship.toml

    echo "[4/5] Writing minimal .gitconfig (no 1Password signing)..."
    cat > ~/.gitconfig <<'GITCONFIG'
[user]
    name = rasbandit
    email = todd.rasband@gmail.com
[init]
    defaultBranch = main
[pull]
    rebase = true
[alias]
    st = status -s
    pr = pull --rebase
GITCONFIG

    mkdir -p "$CHEZMOI_DIR"
    echo "temporary" > "$MACHINE_TYPE_FILE"
    echo "terminal" > "$FEATURES_FILE"

    echo "[5/5] Running ansible (terminal tag)..."
    mkdir -p ~/.local/bin
    cd "$TMPCLONE/dotfiles/ansible"
    ansible-galaxy collection install community.general
    ansible-playbook setup.yml --tags terminal \
        --extra-vars "ansible_become_password=$SUDO_PASS"
    cd ~
    rm -rf "$TMPCLONE"

    echo ""
    echo "============================================"
    echo "  Done! Reloading shell...                  "
    echo "============================================"
    exec bash
fi

# ============================================================================
# Feature defaults by machine type
# Returns: Y (on), N (off), ask (prompt with N default)
# ============================================================================
feature_default() {
    local feature="$1"
    local type="$2"
    case "$feature" in
        terminal)
            echo "Y" ;;
        1password)
            [ "$type" = "workstation" ] && echo "Y" || echo "ask" ;;
        vscode)
            [ "$type" = "workstation" ] && echo "Y" || echo "N" ;;
        browser)
            [ "$type" = "workstation" ] && echo "Y" || echo "N" ;;
        vpn)
            [ "$type" = "workstation" ] && echo "Y" || echo "N" ;;
        dev-tools)
            [ "$type" = "workstation" ] && echo "Y" || echo "ask" ;;
        gnome)
            if [ "$type" = "workstation" ]; then
                case "${XDG_CURRENT_DESKTOP:-}" in
                    *GNOME*|*gnome*) echo "Y" ;;
                    "")              echo "Y" ;;  # undetectable on workstation → default Y
                    *)               echo "ask" ;;
                esac
            else
                echo "N"
            fi ;;
        openbox)
            echo "ask" ;;
        claude)
            [ "$type" = "workstation" ] && echo "Y" || echo "ask" ;;
        japanese)
            [ "$type" = "workstation" ] && echo "ask" || echo "N" ;;
        apps)
            [ "$type" = "workstation" ] && echo "Y" || echo "N" ;;
        gaming-laptop)
            [ "$type" = "workstation" ] && echo "ask" || echo "N" ;;
        gaming-desktop)
            [ "$type" = "workstation" ] && echo "ask" || echo "N" ;;
        auto-sync)
            [ "$type" = "temporary" ] && echo "N" || echo "Y" ;;
        *)
            echo "N" ;;
    esac
}

# Check if a feature was in the existing features list
feature_installed() {
    local feature="$1"
    echo "$EXISTING_FEATURES" | grep -qw "$feature" && echo "Y" || echo "N"
}

# ============================================================================
# Feature prompts
# ============================================================================
ALL_FEATURES="terminal 1password vscode browser vpn dev-tools gnome openbox claude japanese apps gaming-laptop gaming-desktop auto-sync"

echo "Configure features for $MACHINE_TYPE:"
echo "(Press Enter to accept default, or type y/n to change)"
echo ""

SELECTED_FEATURES=""

for feature in $ALL_FEATURES; do
    default=$(feature_default "$feature" "$MACHINE_TYPE")

    # In update mode: pre-fill from installed state
    if [ "$UPDATE_MODE" = true ]; then
        installed=$(feature_installed "$feature")
        if [ "$installed" = "Y" ]; then
            prefill="Y"
        elif [ "$default" = "N" ]; then
            prefill="N"
        else
            prefill="$default"
        fi
    else
        prefill="$default"
    fi

    # Collapse "ask" → "N" for the prompt default
    [ "$prefill" = "ask" ] && prefill="N"

    # Skip features that are N and weren't previously installed
    if [ "$default" = "N" ]; then
        if [ "$UPDATE_MODE" = false ]; then
            continue
        elif [ "$(feature_installed "$feature")" = "N" ]; then
            continue
        fi
    fi

    if [ "$prefill" = "Y" ]; then
        prompt_str="[Y/n]"
    else
        prompt_str="[y/N]"
    fi

    read -rp "  ${feature}? ${prompt_str}: " choice </dev/tty
    case "${choice:-$prefill}" in
        [Yy]*|Y) SELECTED_FEATURES="$SELECTED_FEATURES $feature" ;;
        *) : ;;
    esac
done

SELECTED_FEATURES="${SELECTED_FEATURES# }"  # trim leading space

echo ""
echo "Selected features: $SELECTED_FEATURES"
echo ""

# ============================================================================
# 1Password detection loop (if selected)
# ============================================================================
if echo "$SELECTED_FEATURES" | grep -qw "1password"; then
    echo "Checking 1Password CLI..."

    # Install op CLI if missing
    if ! command -v op &>/dev/null; then
        echo "  Installing 1Password CLI..."
        case "$OS" in
            fedora)
                sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
                sudo tee /etc/yum.repos.d/1password.repo > /dev/null <<'REPO'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
REPO
                sudo dnf install -y 1password-cli
                ;;
            ubuntu|debian)
                curl -sS https://downloads.1password.com/linux/keys/1password.asc \
                    | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" \
                    | sudo tee /etc/apt/sources.list.d/1password.list > /dev/null
                sudo apt update && sudo apt install -y 1password-cli
                ;;
            *)
                echo "  ⚠ Unsupported OS for auto-install. Install 'op' CLI manually."
                ;;
        esac
    fi

    if command -v op &>/dev/null && op vault list &>/dev/null 2>&1; then
        echo "  ✓ 1Password working."
    else
        echo "  ✗ Not configured."
        echo ""
        if [ "$MACHINE_TYPE" = "server" ]; then
            echo "Server detected. Enter your 1Password Service Account token"
            echo "(create one at https://my.1password.com → Developer → Service Accounts)"
            echo ""

            while true; do
                read -rp "  Paste token (or 's' to skip): " op_token </dev/tty
                if [ "${op_token:-}" = "s" ] || [ "${op_token:-}" = "S" ]; then
                    echo "  Skipping 1Password. Removing from features."
                    SELECTED_FEATURES=$(echo "$SELECTED_FEATURES" | tr ' ' '\n' \
                        | grep -vE "^(1password|claude)$" \
                        | tr '\n' ' ' | sed 's/[[:space:]]*$//')
                    echo "  Updated features: $SELECTED_FEATURES"
                    break
                elif [ -n "${op_token:-}" ]; then
                    export OP_SERVICE_ACCOUNT_TOKEN="$op_token"
                    if op vault list &>/dev/null 2>&1; then
                        echo "  ✓ 1Password working. Continuing."
                        break
                    else
                        unset OP_SERVICE_ACCOUNT_TOKEN
                        echo "  ✗ Invalid token. Try again, or 's' to skip."
                    fi
                else
                    echo "  ✗ No token entered. Try again, or 's' to skip."
                fi
            done
        else
            echo "Set up 1Password now:"
            echo "  1. Install 1Password desktop app"
            echo "  2. Sign in to your account"
            echo "  3. Settings → Developer → Enable 'Connect with 1Password CLI'"
            echo "  4. Open a new terminal and run: op vault list"
            echo ""
            echo "Press Enter when ready, or 's' to skip 1Password for now..."

            while true; do
                read -rp "  > " op_choice </dev/tty
                if [ "${op_choice:-}" = "s" ] || [ "${op_choice:-}" = "S" ]; then
                    echo "  Skipping 1Password. Removing from features."
                    SELECTED_FEATURES=$(echo "$SELECTED_FEATURES" | tr ' ' '\n' \
                        | grep -vE "^(1password|claude)$" \
                        | tr '\n' ' ' | sed 's/[[:space:]]*$//')
                    echo "  Updated features: $SELECTED_FEATURES"
                    break
                else
                    echo "  [checking op vault list...]"
                    if op vault list &>/dev/null 2>&1; then
                        echo "  ✓ 1Password working. Continuing."
                        break
                    else
                        echo "  ✗ Still not configured. Press Enter to retry, or 's' to skip."
                    fi
                fi
            done
        fi
    fi
    echo ""
fi

# ============================================================================
# Write config files
# ============================================================================
mkdir -p "$CHEZMOI_DIR"
echo "$MACHINE_TYPE" > "$MACHINE_TYPE_FILE"
echo "$SELECTED_FEATURES" > "$FEATURES_FILE"

echo "Written:"
echo "  machine-type: $MACHINE_TYPE"
echo "  features:     $SELECTED_FEATURES"
echo ""

# ============================================================================
# Install prerequisites
# ============================================================================
echo "[1] Installing prerequisites..."

case $OS in
    fedora)
        sudo dnf install -y git curl ansible python3-pip
        ;;
    ubuntu|debian)
        sudo apt update -q
        sudo apt install -y git curl ansible python3-pip
        ;;
    arch)
        sudo pacman -Sy --noconfirm git curl ansible python-pip
        echo "Warning: no Arch ansible role exists — base tasks only."
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# ============================================================================
# Install chezmoi
# ============================================================================
echo "[2] Installing chezmoi..."

if ! command -v chezmoi &>/dev/null; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
    export PATH="$HOME/.local/bin:$PATH"
fi

# ============================================================================
# Init chezmoi repo
# ============================================================================
# Prevent run_after scripts from prompting about ansible — we run it below
touch ~/.config/chezmoi-ansible-done

if [ "$UPDATE_MODE" = true ] && chezmoi source-path &>/dev/null 2>&1; then
    CHEZMOI_SOURCE=$(chezmoi source-path)
    echo "Updating chezmoi source..."
    chezmoi update --force || chezmoi init --force "$REPO" --branch "$BRANCH"
    echo "Using chezmoi source: $CHEZMOI_SOURCE"
else
    echo "[3] Pre-creating chezmoi config (non-interactive)..."
    {
        echo '[data]'
        echo "    hostname = \"$(hostname)\""
        echo "    machineType = \"$MACHINE_TYPE\""
        echo '    email = "todd.rasband@gmail.com"'
        if echo "$SELECTED_FEATURES" | grep -qw "1password"; then
            echo ''
            echo '[onepassword]'
            echo '    command = "op"'
            echo '    prompt = true'
        fi
    } > "$CHEZMOI_DIR/chezmoi.toml"

    echo "[3b] Cloning dotfiles repo..."
    chezmoi init --force "$REPO" --branch "$BRANCH"
    CHEZMOI_SOURCE=$(chezmoi source-path)

    if [ "$MACHINE_TYPE" = "server" ]; then
        # Copy shell files immediately for usability
        cp "$CHEZMOI_SOURCE/dot_aliases"        ~/.aliases
        cp "$CHEZMOI_SOURCE/dot_bash_functions" ~/.bash_functions
        cp "$CHEZMOI_SOURCE/dot_bashrc"         ~/.bashrc
    fi
fi

# ============================================================================
# Build ansible tags — delta mode on re-run
# ============================================================================
ANSIBLE_TAGS=""

if [ "$UPDATE_MODE" = true ] && [ -n "$EXISTING_FEATURES" ]; then
    NEW_FEATURES=""
    for f in $SELECTED_FEATURES; do
        if ! echo "$EXISTING_FEATURES" | grep -qw "$f"; then
            NEW_FEATURES="$NEW_FEATURES $f"
        fi
    done
    NEW_FEATURES="${NEW_FEATURES# }"

    if [ -z "$NEW_FEATURES" ]; then
        echo "No new features to install. Skipping Ansible."
    else
        echo "New features to install: $NEW_FEATURES"
        ANSIBLE_TAGS=$(echo "$NEW_FEATURES" | tr ' ' ',')
    fi
else
    ANSIBLE_TAGS=$(echo "$SELECTED_FEATURES" | tr ' ' ',')
fi

# ============================================================================
# Run Ansible
# ============================================================================
if [ -n "${ANSIBLE_TAGS:-}" ]; then
    if [ ! -d "$CHEZMOI_SOURCE/ansible" ]; then
        echo "ERROR: ansible directory not found at $CHEZMOI_SOURCE/ansible"
        exit 1
    fi

    cd "$CHEZMOI_SOURCE/ansible"
    ansible-galaxy collection install community.general

    echo "[4] Running ansible --tags $ANSIBLE_TAGS ..."
    ansible-playbook setup.yml --tags "$ANSIBLE_TAGS" \
        --extra-vars "ansible_become_password=$SUDO_PASS"
fi

# ============================================================================
# Run chezmoi apply
# ============================================================================
echo ""
echo "[5] Applying chezmoi templates..."
chezmoi apply --force

echo ""
echo "============================================"
echo "  Bootstrap Complete!                        "
echo "============================================"
echo ""
echo "  Machine type: $MACHINE_TYPE"
echo "  Features:     $SELECTED_FEATURES"
echo ""
echo "Useful commands:"
echo "  dots_diff     — See what would change"
echo "  dots_apply    — Apply dotfile changes"
echo "  dots_update   — Pull and apply updates"
echo "  dots_features — Show installed features"

}

main "$@"
