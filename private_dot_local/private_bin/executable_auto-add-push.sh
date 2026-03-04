#!/bin/bash
set -euo pipefail

CHEZMOI_DIR="$HOME/.local/share/chezmoi"

cd "$CHEZMOI_DIR"

REMOTE_BRANCH="origin/main"
LOCAL_BRANCH="main"

# --- Ensure correct remote URLs for push/pull ---
git remote set-url origin https://github.com/Rasbandit/dotfiles-v2.git
git remote set-url --push origin git@github.com:Rasbandit/dotfiles-v2.git

# --- 1. Sync actual dotfiles back to chezmoi source ---
chezmoi re-add

# --- 2. Stage and commit local changes ---
git add -A
if [ -n "$(git diff --cached --name-only)" ]; then
    timestamp=$(date +"%Y-%m-%d %H:%M")
    git commit -m "$timestamp"
    echo "Committed local changes."
fi

# --- 3. Fetch and handle remote changes ---
git fetch origin

LOCAL_COMMIT=$(git rev-parse "$LOCAL_BRANCH")
REMOTE_COMMIT=$(git rev-parse "$REMOTE_BRANCH")
BASE_COMMIT=$(git merge-base "$LOCAL_BRANCH" "$REMOTE_BRANCH")

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    echo "Local and remote are up to date."
elif [ "$LOCAL_COMMIT" = "$BASE_COMMIT" ]; then
    echo "Pulling and rebasing new changes from remote..."
    if ! git pull --rebase origin main; then
        notify-send "Chezmoi sync ERROR" "Rebase failed! Resolve manually in $CHEZMOI_DIR"
        exit 1
    fi
elif [ "$REMOTE_COMMIT" = "$BASE_COMMIT" ]; then
    echo "Local ahead; will push."
else
    echo "Branches have diverged! Attempting rebase..."
    if ! git rebase "$REMOTE_BRANCH"; then
        notify-send "Chezmoi sync ERROR" "Rebase failed! Resolve manually in $CHEZMOI_DIR"
        exit 1
    fi
fi

# --- 4. Check if chezmoi has changes to apply ---
if chezmoi diff --no-pager | grep -q .; then
    echo "Changes detected, applying..."
    if ! chezmoi apply; then
        notify-send "Chezmoi sync ERROR" "Failed to apply changes! Run 'chezmoi apply -v' to see details."
        exit 1
    fi
    echo "Changes applied successfully."
else
    echo "No chezmoi changes to apply."
fi

# --- 5. Push if needed ---
if [ "$(git rev-parse "$LOCAL_BRANCH")" != "$(git rev-parse "$REMOTE_BRANCH")" ]; then
    echo "Pushing to remote..."
    git push
else
    echo "No changes to push."
fi
