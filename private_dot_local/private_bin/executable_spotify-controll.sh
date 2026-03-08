#!/bin/bash

# Combined Spotify Control Script
# Controls launching Spotify, play-pause toggle, volume adjustment, and track navigation.
# If Spotify is not running for any action, it will be launched first.
# Usage:
#   ./spotify_master.sh              # Launch Spotify if not running, else toggle play-pause
#   ./spotify_master.sh toggle       # Toggle play-pause
#   ./spotify_master.sh +            # Increase volume by 0.05
#   ./spotify_master.sh -            # Decrease volume by 0.05
#   ./spotify_master.sh next         # Skip to next track
#   ./spotify_master.sh previous     # Go to previous track
#   ./spotify_master.sh skip         # Same as next
#   ./spotify_master.sh back         # Same as previous

# Prerequisites: playerctl and bc must be installed (sudo dnf install playerctl bc)
# Assumes Spotify is installed via Flatpak. If native, change 'flatpak run com.spotify.Client' to 'spotify'

SPOTIFY_CMD="flatpak run com.spotify.Client"
INCREMENT=0.05

# Function to check if Spotify is running
is_spotify_running() {
    playerctl status >/dev/null 2>&1
}

# Function to launch Spotify without starting playback
wait_for_spotify() {
    for i in $(seq 1 20); do
        playerctl -p spotify status >/dev/null 2>&1 && return 0
        sleep 0.25
    done
    return 1
}

launch_spotify_silent() {
    systemd-run --user --no-block -- $SPOTIFY_CMD --minimized
    wait_for_spotify
}

# Function to launch Spotify and start playing
launch_spotify() {
    systemd-run --user --no-block -- $SPOTIFY_CMD --minimized
    wait_for_spotify && playerctl play
}

# Function to toggle play-pause (launches if not running)
toggle_play_pause() {
    if ! is_spotify_running; then
        launch_spotify
    else
        playerctl play-pause
        echo "Toggled play-pause."
    fi
}

# Function to adjust volume (launches Spotify if not running)
adjust_volume() {
    local direction=$1
    if ! is_spotify_running; then
        launch_spotify_silent
    fi

    # Get current volume
    current_vol=$(playerctl volume 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: Could not get current volume."
        exit 1
    fi

    # Calculate new volume
    if [ "$direction" == "up" ]; then
        new_vol=$(echo "scale=3; $current_vol + $INCREMENT" | bc)
        if (( $(echo "$new_vol > 1.0" | bc -l) )); then new_vol=1.0; fi
    else
        new_vol=$(echo "scale=3; $current_vol - $INCREMENT" | bc)
        if (( $(echo "$new_vol < 0.0" | bc -l) )); then new_vol=0.0; fi
    fi

    # Set new volume
    playerctl volume "$new_vol"
    if [ $? -eq 0 ]; then
        echo "Volume set to $new_vol"
    else
        echo "Error: Failed to set volume."
    fi
}

# Function to skip to next track (launches Spotify if not running)
skip_next() {
    if ! is_spotify_running; then
        launch_spotify_silent
    fi
    playerctl next
    echo "Skipped to next track."
}

# Function to go to previous track (launches Spotify if not running)
go_previous() {
    if ! is_spotify_running; then
        launch_spotify_silent
    fi
    playerctl previous
    echo "Went to previous track."
}

# Main logic based on parameter
case "${1:-start}" in
    start|"" )
        if is_spotify_running; then
            toggle_play_pause
        else
            launch_spotify
        fi
        ;;
    toggle|play-pause )
        toggle_play_pause
        ;;
    +|up )
        adjust_volume "up"
        ;;
    -|down )
        adjust_volume "down"
        ;;
    next|skip )
        skip_next
        ;;
    previous|back )
        go_previous
        ;;
    * )
        echo "Invalid parameter. Usage:"
        echo "  $0              # Launch or toggle play-pause"
        echo "  $0 toggle       # Toggle play-pause"
        echo "  $0 +            # Volume up"
        echo "  $0 -            # Volume down"
        echo "  $0 next         # Skip to next track"
        echo "  $0 previous     # Go to previous track"
        echo "  $0 skip         # Same as next"
        echo "  $0 back         # Same as previous"
        exit 1
        ;;
esac