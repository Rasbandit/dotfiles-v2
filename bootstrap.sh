#!/bin/bash
set -euo pipefail

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
if ! echo "$SUDO_PASS" | sudo -Sv 2>/dev/null; then
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
# Prompt: Machine type
# ============================================================================
if [ "$UPDATE_MODE" = true ]; then
    echo "Current type: $EXISTING_TYPE"
    echo "Change type? (leave blank to keep '$EXISTING_TYPE')"
    echo "  1) temporary   — creature comforts, no auth"
    echo "  2) server      — persistent, headless"
    echo "  3) workstation — full setup (laptop or desktop)"
    echo ""
    read -rp "Enter choice [1-3, or Enter to keep]: " machine_choice </dev/tty
    if [ -z "$machine_choice" ]; then
        MACHINE_TYPE="$EXISTING_TYPE"
    else
        case $machine_choice in
            1) MACHINE_TYPE="temporary" ;;
            2) MACHINE_TYPE="server" ;;
            3) MACHINE_TYPE="workstation" ;;
            *) echo "Invalid choice. Keeping $EXISTING_TYPE."; MACHINE_TYPE="$EXISTING_TYPE" ;;
        esac
    fi
else
    echo "What type of machine is this?"
    echo "  1) temporary   — creature comforts, no auth"
    echo "  2) server      — persistent, headless"
    echo "  3) workstation — full setup (laptop or desktop)"
    echo ""
    read -rp "Enter choice [1-3]: " machine_choice </dev/tty
    case $machine_choice in
        1) MACHINE_TYPE="temporary" ;;
        2) MACHINE_TYPE="server" ;;
        3) MACHINE_TYPE="workstation" ;;
        *) echo "Invalid choice. Defaulting to workstation."; MACHINE_TYPE="workstation" ;;
    esac
fi

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
    ansible-playbook setup.yml --tags terminal
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
    ansible-playbook setup.yml --tags "$ANSIBLE_TAGS"
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
