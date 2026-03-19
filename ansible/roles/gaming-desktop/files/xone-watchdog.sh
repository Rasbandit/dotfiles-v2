#!/usr/bin/env bash
# xone-watchdog.sh — Monitor xone-dongle for radio errors and auto-reset USB
#
# Watches kernel log for xone error bursts (-22 EINVAL, -28 ENOSPC).
# When detected, power-cycles the Xbox Wireless Adapter via USB deauth/reauth,
# then reloads the xone modules.
#
# Installed as: /usr/local/bin/xone-watchdog.sh
# Managed by:   /etc/systemd/system/xone-watchdog.service

set -euo pipefail

VENDOR="045e"
PRODUCT="02e6"
ERROR_THRESHOLD=5          # errors within the window to trigger reset
ERROR_WINDOW=10            # seconds
COOLDOWN=60                # seconds between resets
SETTLE_TIME=15             # seconds to ignore errors after startup
MAX_RESETS=3               # max resets before backing off
BACKOFF_WINDOW=300         # seconds — reset counter after this much quiet time
XHCI_RESET_ENABLED=true    # === FALLBACK: PCI-level xhci reset (see below) ===
                            # Set to false to disable the xhci fallback and revert
                            # to USB-only resets. The xhci reset disconnects ALL
                            # devices on the USB bus (~3s blackout) but recovers
                            # hard-stuck ports that USB authorized cycling can't fix.
LOG_TAG="xone-watchdog"

last_reset=0
error_count=0
window_start=0
reset_count=0
cooldown_logged=false
start_time=$(date +%s)

log() { logger -t "$LOG_TAG" "$*"; echo "$(date -Iseconds) $*"; }

# Find the PCI address of the xhci controller that owns a given USB device.
# Used by the xhci reset fallback — resolves e.g. /sys/bus/usb/devices/1-3
# back to its parent PCI device (e.g. 0000:0f:00.0).
find_xhci_pci_addr() {
    local usb_path="$1"
    local real
    real="$(readlink -f "$usb_path")"
    # Walk up the sysfs path to find the PCI device (format: XXXX:XX:XX.X)
    while [[ -n "$real" && "$real" != "/" ]]; do
        local base
        base="$(basename "$real")"
        if [[ "$base" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
            echo "$base"
            return 0
        fi
        real="$(dirname "$real")"
    done
    return 1
}

find_dongle_usb_path() {
    for dev in /sys/bus/usb/devices/*/idVendor; do
        local dir
        dir="$(dirname "$dev")"
        if [[ "$(cat "$dir/idVendor" 2>/dev/null)" == "$VENDOR" ]] &&
           [[ "$(cat "$dir/idProduct" 2>/dev/null)" == "$PRODUCT" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

reset_dongle() {
    local now
    now=$(date +%s)

    if (( now - last_reset < COOLDOWN )); then
        if [[ "$cooldown_logged" == false ]]; then
            log "Cooldown active — suppressing resets for ${COOLDOWN}s"
            cooldown_logged=true
        fi
        return 1
    fi
    cooldown_logged=false

    if (( reset_count >= MAX_RESETS )); then
        if (( now - last_reset >= BACKOFF_WINDOW )); then
            reset_count=0
            log "Backoff cleared after ${BACKOFF_WINDOW}s quiet — resuming resets"
        else
            log "Max resets ($MAX_RESETS) reached — backing off until errors stop for ${BACKOFF_WINDOW}s"
            return 1
        fi
    fi

    local usb_path
    if ! usb_path=$(find_dongle_usb_path); then
        log "ERROR: Xbox Wireless Adapter not found on USB bus"
        return
    fi

    local auth_file="$usb_path/authorized"
    local usb_dev
    usb_dev="$(basename "$usb_path")"

    log "Resetting Xbox Wireless Adapter at $usb_dev"

    # Unload xone modules
    rmmod xone_gip_gamepad 2>/dev/null || true
    rmmod xone_gip_headset 2>/dev/null || true
    rmmod xone_gip_chatpad 2>/dev/null || true
    rmmod xone_dongle 2>/dev/null || true

    # Stage 1: Power-cycle USB device via authorized flag
    echo 0 > "$auth_file"
    sleep 2
    echo 1 > "$auth_file"
    sleep 3

    # Check if the dongle re-enumerated after USB power-cycle
    if ! lsusb -d "${VENDOR}:${PRODUCT}" &>/dev/null; then
        # Stage 2 (fallback): PCI-level xhci controller reset
        # This tears down and re-initializes the entire USB host controller,
        # which recovers hard-stuck ports that USB authorized cycling can't fix.
        # WARNING: Causes ~3s blackout for ALL devices on this USB bus.
        # To disable this fallback, set XHCI_RESET_ENABLED=false at top of script.
        if [[ "$XHCI_RESET_ENABLED" == true ]]; then
            local pci_addr
            if pci_addr=$(find_xhci_pci_addr "$usb_path"); then
                log "USB power-cycle failed — dongle not found. Falling back to xhci PCI reset ($pci_addr)"
                echo "$pci_addr" > /sys/bus/pci/drivers/xhci_hcd/unbind
                sleep 2
                echo "$pci_addr" > /sys/bus/pci/drivers/xhci_hcd/bind
                sleep 3
            else
                log "ERROR: Could not determine PCI address for xhci controller"
            fi
        else
            log "USB power-cycle failed — dongle not found. xhci fallback disabled (XHCI_RESET_ENABLED=false)"
        fi
    fi

    # Reload all xone modules (gamepad must be loaded for controller input)
    modprobe xone_dongle
    modprobe xone_gip_gamepad
    sleep 5

    log "Reset complete — dongle and gamepad driver re-initialized"
    last_reset=$(date +%s)
    error_count=0
    reset_count=$((reset_count + 1))

    # Append to xone-dongle.log for history
    echo "=== Watchdog Reset $(date -Iseconds) ===" >> /var/log/xone-dongle.log
}

log "Started — monitoring for xone-dongle errors"

# --since=now ensures we only see NEW kernel messages, not replayed boot history
journalctl -fk --no-pager --since=now --grep='xone.*failed' | while read -r line; do
    now=$(date +%s)

    # Ignore errors during initial settle period (module may still be loading)
    if (( now - start_time < SETTLE_TIME )); then
        continue
    fi

    # Reset error counter if outside window
    if (( now - window_start > ERROR_WINDOW )); then
        error_count=0
        window_start=$now
    fi

    error_count=$((error_count + 1))

    if (( error_count >= ERROR_THRESHOLD )); then
        log "Detected $error_count xone errors in ${ERROR_WINDOW}s — triggering USB reset"
        if reset_dongle; then
            # Update start_time to add settle period after reset
            start_time=$(date +%s)
        fi
        # Always reset counter — prevents log spam when cooldown/backoff blocks reset
        error_count=0
        window_start=0
    fi
done
