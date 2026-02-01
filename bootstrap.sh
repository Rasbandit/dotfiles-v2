#!/bin/bash
set -euo pipefail

# ============================================================================
# Dotfiles Bootstrap Script
# Run with: curl -sL https://bit.ly/bandit-dotfiles-init | bash
# ============================================================================

REPO="Rasbandit/dotfiles"  # Change to your repo
BRANCH="main"

echo "============================================"
echo "  Dotfiles Bootstrap - Setting up machine  "
echo "============================================"
echo ""

# Detect OS
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
# Step 1: Install essential packages
# ============================================================================
echo "[1/5] Installing essential packages..."

case $OS in
    fedora)
        sudo dnf install -y git curl ansible python3-pip
        ;;
    ubuntu|debian)
        sudo apt update
        sudo apt install -y git curl ansible python3-pip
        ;;
    arch)
        sudo pacman -Sy --noconfirm git curl ansible python-pip
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Install ansible community general collection
ansible-galaxy collection install community.general

# ============================================================================
# Step 2: Install chezmoi
# ============================================================================
echo ""
echo "[2/5] Installing chezmoi..."

if ! command -v chezmoi &>/dev/null; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
    export PATH="$HOME/.local/bin:$PATH"
fi

# ============================================================================
# Step 3: Initialize chezmoi with dotfiles repo
# ============================================================================
echo ""
echo "[3/5] Initializing chezmoi with dotfiles..."

# This will prompt for machine-specific values (hostname, machine type, email)
chezmoi init --apply "$REPO" --branch "$BRANCH"

# ============================================================================
# Step 4: Run Ansible playbook
# ============================================================================
echo ""
echo "[4/5] Running Ansible playbook..."
echo "This will prompt for your sudo password."
echo ""

CHEZMOI_SOURCE=$(chezmoi source-path)
cd "$CHEZMOI_SOURCE/ansible"

# Prompt for machine type
echo "What type of machine is this?"
echo "1) desktop-gaming"
echo "2) laptop"
echo "3) server"
read -p "Enter choice [1-3]: " machine_choice

case $machine_choice in
    1) MACHINE_TYPE="desktop-gaming" ;;
    2) MACHINE_TYPE="laptop" ;;
    3) MACHINE_TYPE="server" ;;
    *) MACHINE_TYPE="laptop" ;;
esac

export MACHINE_TYPE

# Run ansible
ansible-playbook setup.yml --ask-become-pass

# ============================================================================
# Step 5: Final setup
# ============================================================================
echo ""
echo "[5/5] Final setup..."

# Reload bashrc
if [ -f ~/.bashrc ]; then
    source ~/.bashrc 2>/dev/null || true
fi

echo ""
echo "============================================"
echo "  Bootstrap Complete!                       "
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Log out and back in for group changes"
echo "  2. Start xremap: systemctl --user start xremap"
echo "  3. Configure 1Password and run: chezmoi apply"
echo ""
echo "Useful commands:"
echo "  dots_diff   - See what would change"
echo "  dots_apply  - Apply dotfile changes"
echo "  dots_update - Pull and apply updates"
echo "  dots_edit   - Edit a managed file"
echo ""
