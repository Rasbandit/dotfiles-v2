#!/bin/bash
set -euo pipefail

# ============================================================================
# Dotfiles Bootstrap Script
# Run with: curl -sL https://raw.githubusercontent.com/Rasbandit/dotfiles-v2/main/bootstrap.sh | bash
# ============================================================================

REPO="Rasbandit/dotfiles-v2"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/Rasbandit/dotfiles-v2/main"

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
# Elevate sudo early so password isn't prompted mid-script
# ============================================================================
echo "This script requires sudo. Please enter your password:"
sudo -v
echo ""

# ============================================================================
# Prompt: Machine type
# ============================================================================
echo "What type of machine is this?"
echo "  1) temporary  - Quick SSH session, just give me my shell"
echo "  2) server     - Persistent server, no desktop"
echo "  3) laptop     - Full setup, no gaming extras"
echo "  4) desktop    - Full setup with gaming packages"
echo ""
read -rp "Enter choice [1-4]: " machine_choice

case $machine_choice in
    1) MACHINE_TYPE="temporary" ;;
    2) MACHINE_TYPE="server" ;;
    3) MACHINE_TYPE="laptop" ;;
    4) MACHINE_TYPE="desktop" ;;
    *) echo "Invalid choice. Defaulting to laptop."; MACHINE_TYPE="laptop" ;;
esac

echo ""

# ============================================================================
# Prompt: Terminal tools
# ============================================================================
read -rp "Install terminal tools? [Y/n]: " tools_choice
case "${tools_choice:-Y}" in
    [Yy]*|"") INSTALL_TOOLS=true ;;
    *) INSTALL_TOOLS=false ;;
esac

echo ""
echo "Machine type : $MACHINE_TYPE"
echo "Install tools: $INSTALL_TOOLS"
echo ""

# ============================================================================
# Path 1: Temporary
# ============================================================================
if [ "$MACHINE_TYPE" = "temporary" ]; then
    echo "--- Temporary setup: fast, no git auth, no ansible ---"
    echo ""

    mkdir -p ~/.config

    echo "[1/4] Downloading config files..."
    curl -fsSL "$RAW_BASE/dot_aliases"        -o ~/.aliases
    curl -fsSL "$RAW_BASE/dot_bash_functions" -o ~/.bash_functions
    curl -fsSL "$RAW_BASE/dot_bashrc"         -o ~/.bashrc
    curl -fsSL "$RAW_BASE/private_dot_config/starship.toml" -o ~/.config/starship.toml

    echo "[2/4] Writing minimal .gitconfig (no 1Password signing)..."
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

    echo "[3/4] Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y

    if [ "$INSTALL_TOOLS" = true ]; then
        echo "[4/4] Installing terminal essentials..."
        case $OS in
            fedora)
                sudo dnf install -y fzf zoxide bat ripgrep colordiff jq fastfetch
                if ! command -v eza &>/dev/null; then
                    sudo dnf install -y eza 2>/dev/null || \
                        { command -v cargo &>/dev/null && cargo install eza; } || \
                        echo "Warning: eza not available, skipping."
                fi
                ;;
            ubuntu|debian)
                sudo apt update -q
                sudo apt install -y fzf zoxide bat ripgrep jq colordiff
                if ! command -v eza &>/dev/null; then
                    if command -v cargo &>/dev/null; then
                        cargo install eza
                    fi
                fi
                ;;
            arch)
                sudo pacman -Sy --noconfirm fzf zoxide bat eza ripgrep colordiff jq fastfetch
                ;;
            *)
                echo "Warning: unsupported OS '$OS', skipping tool install."
                ;;
        esac
    else
        echo "[4/4] Skipping tool install."
    fi

    echo ""
    echo "============================================"
    echo "  Done! Run: exec bash                      "
    echo "============================================"
    exit 0
fi

# ============================================================================
# Shared: install prerequisites (server / laptop / desktop)
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
# Shared: install chezmoi
# ============================================================================
echo "[2] Installing chezmoi..."

if ! command -v chezmoi &>/dev/null; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
    export PATH="$HOME/.local/bin:$PATH"
fi

# ============================================================================
# Shared: persist machine type for ansible
# ============================================================================
mkdir -p ~/.config/chezmoi
echo "$MACHINE_TYPE" > ~/.config/chezmoi/machine-type

# ============================================================================
# Path 2: Server
# ============================================================================
if [ "$MACHINE_TYPE" = "server" ]; then
    echo "--- Server setup: persistent, no desktop ---"
    echo ""

    echo "[3] Pre-creating chezmoi config (non-interactive)..."
    cat > ~/.config/chezmoi/chezmoi.toml <<CHEZMOI
[data]
    hostname = "$(hostname)"
    machineType = "server"
    email = "todd.rasband@gmail.com"
[onepassword]
    command = "op"
    prompt = false
CHEZMOI

    # Prevent run_after from prompting — ansible runs below
    touch ~/.config/chezmoi-ansible-done

    echo "[4] Cloning dotfiles repo (no apply — 1Password not set up yet)..."
    chezmoi init --force "$REPO" --branch "$BRANCH"

    CHEZMOI_SOURCE=$(chezmoi source-path)

    if [ ! -d "$CHEZMOI_SOURCE/ansible" ]; then
        echo "ERROR: chezmoi source dir missing — clone may have failed."
        echo "  Expected: $CHEZMOI_SOURCE/ansible"
        exit 1
    fi

    if [ "$INSTALL_TOOLS" = true ]; then
        echo "[5] Running ansible (terminal tag only)..."
        cd "$CHEZMOI_SOURCE/ansible"
        ansible-galaxy collection install community.general
        MACHINE_TYPE="$MACHINE_TYPE" ansible-playbook setup.yml --tags terminal --ask-become-pass
    fi

    echo ""
    echo "============================================"
    echo "  Server setup complete!                    "
    echo "============================================"
    echo ""
    echo "Next: set up 1Password CLI, then run:"
    echo "  chezmoi apply"
    exit 0
fi

# ============================================================================
# Path 3+4: Laptop / Desktop (full setup)
# ============================================================================
echo "--- Full setup: $MACHINE_TYPE ---"
echo ""

echo "[3] Installing ansible collections..."
ansible-galaxy collection install community.general

# Prevent run_after from asking to run ansible — we run it below
touch ~/.config/chezmoi-ansible-done

echo "[4] Running chezmoi init --apply (interactive)..."
chezmoi init --apply "$REPO" --branch "$BRANCH"

echo "[5] Running ansible playbook..."
CHEZMOI_SOURCE=$(chezmoi source-path)
cd "$CHEZMOI_SOURCE/ansible"
ansible-playbook setup.yml --ask-become-pass

echo ""
echo "============================================"
echo "  Phase 1 Complete!                         "
echo "============================================"
echo ""
echo "Next steps:"
echo ""
echo "  1. Log out and back in for group changes"
echo ""
echo "  2. Set up 1Password:"
echo "     - Install and sign in to 1Password desktop app"
echo "     - Settings → Developer → Enable 'Connect with 1Password CLI'"
echo "     - Open a new terminal, test: op account list"
echo ""
echo "  3. Run Phase 2 (after 1Password is ready):"
echo "     cd ~/.local/share/chezmoi/ansible"
echo "     ansible-playbook setup.yml --ask-become-pass --tags phase2"
echo ""
echo "Useful commands:"
echo "  dots_diff   - See what would change"
echo "  dots_apply  - Apply dotfile changes"
echo "  dots_update - Pull and apply updates"
echo "  dots_edit   - Edit a managed file"
