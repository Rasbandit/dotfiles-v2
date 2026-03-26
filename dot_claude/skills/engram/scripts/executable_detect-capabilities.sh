#!/usr/bin/env bash
# Detect available Engram backends and output JSON status.
# Usage: bash detect-capabilities.sh [vault_path]
# Output: JSON object with cli, engram, filesystem booleans and vault info.

set -euo pipefail

VAULT_PATH="${1:-}"

# --- Obsidian CLI ---
cli_available=false
cli_vaults="[]"
if command -v obsidian &>/dev/null; then
  if obsidian vault 2>/dev/null | grep -q '/'; then
    cli_available=true
    cli_vaults=$(obsidian vault 2>/dev/null | \
      sed -n 's/.*\t\(.*\)/"\1"/p' | \
      paste -sd',' | sed 's/^/[/;s/$/]/')
    cli_vaults="${cli_vaults:-[]}"
  fi
fi

# --- Filesystem probe ---
fs_available=false
fs_path=""
if [[ -n "$VAULT_PATH" && -d "$VAULT_PATH" ]]; then
  fs_available=true
  fs_path="$VAULT_PATH"
else
  # Check common vault locations
  for candidate in \
    "$HOME/Documents/Obsidian" \
    "$HOME/Obsidian" \
    "$HOME/vaults" \
    "$HOME/Documents/vaults"; do
    if [[ -d "$candidate" ]]; then
      # Look for a vault (directory containing .obsidian/)
      first_vault=$(find "$candidate" -maxdepth 2 -name ".obsidian" -type d 2>/dev/null | head -1)
      if [[ -n "$first_vault" ]]; then
        fs_available=true
        fs_path="$(dirname "$first_vault")"
        break
      fi
    fi
  done
fi

# --- Output ---
cat <<EOF
{
  "cli": $cli_available,
  "cli_vaults": $cli_vaults,
  "engram": false,
  "filesystem": $fs_available,
  "filesystem_path": "$fs_path"
}
EOF
