#!/bin/bash

# Generic focus-or-run script for Wayland (GNOME)
# Requires: activate-window-by-title@lucaswerkmeister.de GNOME extension
#
# Usage: focus-or-run.sh <window_match> [command]
#
# Tries WM class first, then falls back to title substring matching.
#
# Examples:
#   focus-or-run.sh "1Password" "1password"
#   focus-or-run.sh "com.mitchellh.ghostty" "ghostty"

WINDOW_MATCH="$1"
COMMAND="${2:-$1}"

if [[ -z "$WINDOW_MATCH" ]]; then
    echo "Usage: focus-or-run.sh <window_match> [command]"
    exit 1
fi

DBUS_DEST="org.gnome.Shell"
DBUS_PATH="/de/lucaswerkmeister/ActivateWindowByTitle"
DBUS_IFACE="de.lucaswerkmeister.ActivateWindowByTitle"

# Track last activated app to enable cycling
LAST_APP_FILE="/tmp/.focus-or-run-last"
LAST_APP=$(cat "$LAST_APP_FILE" 2>/dev/null)

# If same app as last activation, cycle; otherwise jump to most recent
if [[ "$LAST_APP" == "$WINDOW_MATCH" ]]; then
    SORT_ORDER="lowest_user_time"
else
    SORT_ORDER="highest_user_time"
fi

echo "$WINDOW_MATCH" > "$LAST_APP_FILE"

gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" \
    --method "$DBUS_IFACE.setSortOrder" "$SORT_ORDER" >/dev/null 2>&1

# Try WM class first
result=$(gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" \
    --method "$DBUS_IFACE.activateByWmClass" "$WINDOW_MATCH" 2>/dev/null)

if [[ "$result" == "(true,)" ]]; then
    exit 0
fi

# Fall back to title substring
result=$(gdbus call --session --dest "$DBUS_DEST" --object-path "$DBUS_PATH" \
    --method "$DBUS_IFACE.activateBySubstring" "$WINDOW_MATCH" 2>/dev/null)

if [[ "$result" == "(true,)" ]]; then
    exit 0
fi

# Window not found, run the command
$COMMAND
