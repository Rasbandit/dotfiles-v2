#!/bin/bash
# Switch games only: wrap physical pads in identical virtual Xbox pads so Ryujinx's saved ids always match.
[ "$3" = "switch" ] || exit 0

count() { grep -c "^N: Name=\"$1\"" /proc/bus/input/devices; }
physical=$(count "Microsoft Xbox Controller")

sudo -n /usr/bin/systemctl start inputplumber && inputplumber devices manage-all --enable \
  || { logger -t inputplumber-switch "failed to enable InputPlumber"; exit 0; }

# Ryujinx numbers players in the order pads appear; wait so all exist before it starts.
for _ in $(seq 50); do
  [ "$(count "Microsoft Xbox Series S|X Controller")" -ge "$physical" ] && exit 0
  sleep 0.2
done
logger -t inputplumber-switch "timed out waiting for $physical virtual pads"
