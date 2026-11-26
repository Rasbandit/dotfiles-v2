#!/bin/bash
# Give the physical pads back to everything else once the Switch game exits.
[ "$3" = "switch" ] || exit 0
inputplumber devices manage-all; sudo -n /usr/bin/systemctl stop inputplumber
