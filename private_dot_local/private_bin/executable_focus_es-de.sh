#!/bin/bash

# Path to the ES-DE AppImage
APP_PATH="/home/${USER}/Applications/ES-DE_x64.AppImage"

# Assumed window title for ES-DE (change if needed, e.g., check with 'wmctrl -l')
WINDOW_TITLE="ES-DE"

# Check if the AppImage is already running
if pgrep -f "$APP_PATH" > /dev/null; then
    echo "ES-DE is already running. Switching focus..."
    # Activate the window by title
    wmctrl -a "$WINDOW_TITLE"
else
    echo "Launching ES-DE..."
    # Launch the AppImage in the background
    "$APP_PATH" &
fi