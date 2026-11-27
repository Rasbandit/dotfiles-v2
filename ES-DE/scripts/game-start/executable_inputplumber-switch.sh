#!/bin/bash
# Switch games only: wrap physical pads in identical virtual Xbox pads so Ryujinx's saved ids always match.
[ "$3" = "switch" ] || exit 0

VIRTUAL='Microsoft Xbox Series S|X Controller'
count() { grep -c "^N: Name=\"$1\"" /proc/bus/input/devices; }
need=$(( $(count "Microsoft Xbox Controller") - $(count "$VIRTUAL") ))

# Ryujinx numbers players in the order pads appear, so block until every virtual pad exists.
# Listen to udev before enabling so no add event is missed.
coproc UDEV { exec stdbuf -oL udevadm monitor --udev --subsystem-match=input --property; }

sudo -n /usr/bin/systemctl start inputplumber && inputplumber devices manage-all --enable >/dev/null \
  || { logger -t inputplumber-switch "failed to enable InputPlumber"; kill "$UDEV_PID"; exit 0; }

deadline=$((SECONDS + 10))
while [ "$need" -gt 0 ] && IFS= read -r -t $((deadline - SECONDS)) line <&"${UDEV[0]}"; do
  [ "$line" = "NAME=\"$VIRTUAL\"" ] && need=$((need - 1))
done
kill "$UDEV_PID"
[ "$need" -le 0 ] || logger -t inputplumber-switch "timed out, $need virtual pad(s) missing"
