#!/bin/bash
# Switch games only: wrap physical pads in identical virtual Xbox pads so Ryujinx's saved ids always match.
[ "$3" = "switch" ] || exit 0
sudo -n /usr/bin/systemctl start inputplumber && inputplumber devices manage-all --enable \
  || logger -t inputplumber-switch "failed to enable InputPlumber"
