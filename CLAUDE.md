# Claude Instructions for this Repo

## CRITICAL: Never rewrite files containing special characters

Files in this repo contain Nerd Font / Powerline Unicode glyphs (e.g. starship.toml).
These appear invisible or as empty boxes in diffs and text but are real characters.

**NEVER use the Write tool on these files.** It will silently drop all special characters.

Instead:
- Use the **Edit tool** for targeted changes
- If Edit fails to match due to special characters, use **Python** to do the replacement:
  ```python
  content = open(filepath).read()
  content = content.replace(old, new)
  open(filepath, 'w').write(content)
  ```
- Inspect exact bytes first if needed: `repr(line)` in Python shows `\ue0b0` etc.

Files known to contain special characters:
- `private_dot_config/starship.toml`
