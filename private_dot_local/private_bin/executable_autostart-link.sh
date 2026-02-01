#!/usr/bin/env bash

set -e

POT="$HOME/.config/autostart-potentials"
DEST="$HOME/.config/autostart"

mkdir -p "$DEST"

function list_potentials() {
    ls "$POT"
}

function list_links() {
    ls -l "$DEST"
}

function link_autostart() {
    for APP in "$@"; do
        if [[ -e "$POT/$APP" ]]; then
            ln -sf "$POT/$APP" "$DEST/$APP"
            echo "Linked $APP"
        else
            echo "No such potential: $APP"
        fi
    done
}

function unlink_autostart() {
    for APP in "$@"; do
        if [[ -L "$DEST/$APP" ]]; then
            rm "$DEST/$APP"
            echo "Unlinked $APP"
        else
            echo "No symlink: $APP"
        fi
    done
}

case "$1" in
    list) list_potentials ;;
    links) list_links ;;
    link) shift; link_autostart "$@" ;;
    unlink) shift; unlink_autostart "$@" ;;
    *)
      echo "Usage: $0 {list|links|link APP…|unlink APP…}"
      ;;
esac
