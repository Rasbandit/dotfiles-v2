#!/usr/bin/env bash
# Detect available Engram backends and output JSON status.
# Usage: bash detect-capabilities.sh [vault_path]
# Output: JSON object with cli, engram, filesystem booleans and vault info.

set -euo pipefail

VAULT_PATH="${1:-}"

# Obsidian CLI is permanently retired (crash-loops and OOMs the host).
# Local filesystem vault probing is also retired — Engram MCP is remote-only on this host.
cli_available=false
cli_vaults="[]"
fs_available=false
fs_path=""
if [[ -n "$VAULT_PATH" && -d "$VAULT_PATH" ]]; then
  fs_available=true
  fs_path="$VAULT_PATH"
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
