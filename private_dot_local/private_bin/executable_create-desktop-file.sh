#!/bin/bash

# Usage: ./create_desktop_file.sh "App Name" "/path/to/executable" "/path/to/icon" "Optional comment"

# Check if at least app name and executable are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 \"App Name\" \"/path/to/executable\" [\"/path/to/icon\"] [\"Optional comment\"]"
    echo "Example: $0 \"My App\" \"/usr/bin/myapp\" \"/usr/share/icons/myicon.png\" \"A cool app\""
    exit 1
fi

APP_NAME="$1"
EXEC_PATH="$2"
ICON_PATH="${3:-}"  # Optional
COMMENT="${4:-}"    # Optional

# Directory for user-specific desktop files
DESKTOP_DIR="$HOME/.local/share/applications"

# Ensure the directory exists
mkdir -p "$DESKTOP_DIR"

# Generate a safe filename (lowercase, replace spaces with hyphens)
FILENAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g').desktop
DESKTOP_FILE="$DESKTOP_DIR/$FILENAME"

# Create the desktop file content
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Exec=$EXEC_PATH
EOF

# Add Icon if provided
if [ -n "$ICON_PATH" ]; then
    echo "Icon=$ICON_PATH" >> "$DESKTOP_FILE"
fi

# Add Comment if provided
if [ -n "$COMMENT" ]; then
    echo "Comment=$COMMENT" >> "$DESKTOP_FILE"
fi

# Add terminal and startup settings (adjust as needed)
echo "Terminal=false" >> "$DESKTOP_FILE"
echo "StartupWMClass=$APP_NAME" >> "$DESKTOP_FILE"  # Optional, helps with window matching

echo "Desktop file created at: $DESKTOP_FILE"
echo "You can now search for '$APP_NAME' in your application menu."