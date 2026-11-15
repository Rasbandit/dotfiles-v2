#!/usr/bin/env python3
"""UserPromptSubmit hook: surface docs/context/INDEX.md lines that match the prompt.

Reads the hook JSON on stdin, finds the nearest docs/context/INDEX.md at or above
cwd, and prints index lines sharing 2+ meaningful words with the prompt. Stdout
is added to the model's context. Never blocks a prompt: any error exits 0 silently.
"""
import json
import re
import sys
from pathlib import Path

MIN_SHARED_WORDS = 2
MAX_LINES = 5
STOPWORDS = {
    "the", "and", "for", "with", "that", "this", "from", "have", "has", "not",
    "are", "was", "but", "you", "your", "can", "all", "any", "how", "why",
    "what", "when", "into", "out", "use", "using", "doc", "docs", "context",
}


def words(text: str) -> set[str]:
    return {w for w in re.findall(r"[a-z0-9]{3,}", text.lower()) if w not in STOPWORDS}


def find_index(start: Path) -> Path | None:
    for d in [start, *start.parents]:
        candidate = d / "docs" / "context" / "INDEX.md"
        if candidate.is_file():
            return candidate
    return None


def main() -> None:
    payload = json.load(sys.stdin)
    prompt_words = words(payload.get("prompt", ""))
    index = find_index(Path(payload.get("cwd") or "."))
    if not prompt_words or index is None:
        return
    hits = [
        line.strip()
        for line in index.read_text().splitlines()
        if line.lstrip().startswith(("-", "*"))
        and len(words(line) & prompt_words) >= MIN_SHARED_WORDS
    ]
    if hits:
        print(f"Relevant context docs (from {index}):")
        print("\n".join(hits[:MAX_LINES]))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # a routing hint must never block the user's prompt
    sys.exit(0)
