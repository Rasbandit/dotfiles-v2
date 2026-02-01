#!/bin/bash
set -euo pipefail

GIT_DIR="$HOME/.cfg"
WORK_TREE="$HOME"

# Helper function to run git for the bare dotfiles repo
config() {
    /usr/bin/git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" "$@"
}

REMOTE_BRANCH="origin/main"
LOCAL_BRANCH="main"

# --- Ensure correct remote URLs for push/pull ---
# Set HTTPS URL for fetch/pull, SSH for push
config remote set-url origin https://github.com/Rasbandit/dotfiles.git
config remote set-url --push origin git@github.com:Rasbandit/dotfiles.git

# --- 1. Stage your dotfiles and config changes first (before pulling) ---
config add "$HOME/.setup-scripts/"* "$HOME/.config/autostart-potentials/"*
config add -u

# --- 2. Commit if needed (do this before pulling to avoid conflicts) ---
if [ -n "$(config diff --cached --name-only)" ]; then
    timestamp=$(date +"%Y-%m-%d %H:%M")
    config commit -m "$timestamp"
    echo "Committed local changes."
fi

# --- 3. Pull remote changes (now that working tree is clean) ---
config fetch origin +refs/heads/*:refs/remotes/origin/*

LOCAL_COMMIT=$(config rev-parse "$LOCAL_BRANCH")
REMOTE_COMMIT=$(config rev-parse "$REMOTE_BRANCH")
BASE_COMMIT=$(config merge-base "$LOCAL_BRANCH" "$REMOTE_BRANCH")

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    echo "Local and remote are up to date."
elif [ "$LOCAL_COMMIT" = "$BASE_COMMIT" ]; then
    echo "Pulling and rebasing new changes from remote main..."
    if ! config pull --rebase "$REMOTE_BRANCH"; then
        notify-send "Dotfiles backup ERROR" "Rebase failed due to conflicts! Resolve manually with 'config rebase --continue' or 'config rebase --abort'."
        echo "Rebase failed due to conflicts! Resolve manually."
        exit 1
    fi
elif [ "$REMOTE_COMMIT" = "$BASE_COMMIT" ]; then
    echo "Local ahead; will push any new commits after staging."
else
    echo "Branches have diverged! Attempting rebase..."
    if ! config rebase "$REMOTE_BRANCH"; then
        notify-send "Dotfiles backup ERROR" "Rebase failed due to conflicts! Resolve manually with 'config rebase --continue' or 'config rebase --abort'."
        echo "Rebase failed due to conflicts! Resolve manually."
        exit 1
    fi
fi

# --- 4. Push if there are new commits (this will require SSH key unlock if needed) ---
if [ -n "$(config diff "$LOCAL_BRANCH" "$REMOTE_BRANCH")" ] || [ "$(config rev-parse "$LOCAL_BRANCH")" != "$(config rev-parse "$REMOTE_BRANCH")" ]; then
    echo "Pushing new commit to remote main (this will require your SSH key)..."
    config push
else
    echo "No changes to push."
fi