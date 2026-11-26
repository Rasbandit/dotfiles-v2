#!/usr/bin/env python3
"""Pin Ryujinx players 1-4 to InputPlumber's virtual Xbox pads, all with the same settings.

InputPlumber gives every pad the same SDL GUID, so ids are just "<n>-<GUID>"; Ryujinx binds
pads by connect order, including ones plugged in mid-game. Settings come from
~/.config/Ryujinx/input-player-template.json (synced by chezmoi), so Ryujinx rewriting
Config.json can't drift them. ES-DE args: $1 rom, $2 game name, $3 system.
"""
import json, os, sys

GUID = "00000003-045e-0000-120b-000001000000"  # InputPlumber virtual Xbox pad (045e:0b12, version 0001)
PLAYERS = 4
DIR = os.path.expanduser("~/.config/Ryujinx")


def players(template):
    return [dict(template, id=f"{n}-{GUID}", player_index=f"Player{n + 1}",
                 name=f"Xbox Series X Controller ({n})") for n in range(PLAYERS)]


def main():
    if sys.argv[3:4] != ["switch"]:
        return
    cfg_path = os.path.join(DIR, "Config.json")
    try:
        with open(os.path.join(DIR, "input-player-template.json")) as f:
            template = json.load(f)
        with open(cfg_path) as f:
            cfg = json.load(f)
    except FileNotFoundError:
        return  # Ryujinx never run on this machine yet
    cfg["input_config"] = players(template)
    tmp = cfg_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
    os.replace(tmp, cfg_path)


if __name__ == "__main__":
    main()
