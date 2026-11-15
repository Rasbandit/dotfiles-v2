#!/usr/bin/env python3
"""Resolve current Obsidian vault root + destination subfolder for yt-ingest.

Walks up from the given cwd looking for `.obsidian/`, then matches the vault root
against config/vault-routing.json. Falls back to `_default` entry.

Usage: vault_resolve.py [cwd]
Output: JSON {vault, destination, destination_exists, frontmatter_extra}
"""
import json
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parent.parent / "config" / "vault-routing.json"

def find_vault(start: Path) -> Path | None:
    for d in [start, *start.parents]:
        if (d / ".obsidian").is_dir():
            return d
    return None

def main() -> int:
    cwd = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    vault = find_vault(cwd)
    if vault is None:
        print(json.dumps({"error": "no vault found", "cwd": str(cwd)}))
        return 1
    routing = json.loads(CONFIG.read_text())
    cfg = routing.get(str(vault), routing["_default"])
    dest = vault / cfg["destination"]
    print(json.dumps({
        "vault": str(vault),
        "destination": str(dest),
        "destination_exists": dest.is_dir(),
        "frontmatter_extra": cfg["frontmatter_extra"],
    }, indent=2))
    return 0

if __name__ == "__main__":
    sys.exit(main())
