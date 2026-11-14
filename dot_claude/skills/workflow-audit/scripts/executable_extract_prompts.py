#!/usr/bin/env python3
"""Extract the user's own typed prompts from Claude Code transcripts.

Usage: extract_prompts.py <out_dir> [days=7]

Writes:
  prompts.tsv  - every prompt: timestamp, project, text (newlines as " ⏎ ")
  mid.txt      - prompts 80-2000 chars (the ones worth reading), truncated to 600
  stats.txt    - counts, length stats, exact repeats, theme frequencies
Skips: subagent/sidechain turns, meta turns, tool results, system reminders,
cross-session/agent messages, compaction summaries, pastes over 2000 chars.
"""
import collections, datetime, glob, json, os, re, statistics, sys

out = sys.argv[1]
days = int(sys.argv[2]) if len(sys.argv) > 2 else 7
os.makedirs(out, exist_ok=True)
cut = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)).isoformat()

THEMES = {
    "status asks (check in / report / where are we)": r"\b(check in|report|status|where (are|is) we|what'?s (the )?(status|left)|what'?s next)\b",
    "approvals (do it / go / yes / do recommended)": r"^(ok[, ]*)?(yeah |yes )?(do it|go|yes|proceed|keep going|continue|do recommended|do all)",
    "merge / CI / rebase": r"\b(merge|green|rebase|ci\b|pipeline|checks)",
    "review / prove / coverage": r"\b(adversarial|review|coverage|prove|proof)",
    "consolidate / one PR": r"\b(consolidat|one pr|single pr|fewer pr|bundle|as few)",
    "explain simpler / educate": r"\b(simpler|simple|educate|explain|break (it )?down|junior)",
    "repeat / again / I told you": r"\b(again|i told you|already said|i said|remember|reminder|stop (doing|asking))",
    "rigor intensifiers (dig deep / no stone / savage)": r"\b(dig (deep|in)|no stone|savage|brutal|ax murderer|validate|best practice|research)",
    "root cause / bandaid": r"\b(root cause|bandaid|band-aid|proper fix|core fix|core issue)",
    "cost / budget / cpu": r"\b(token|budget|cost|cpu|memory|ram|bill)",
    "local machine safety": r"\b(locally|this (vm|machine|box)|crash(ed|ing)? (the )?(vm|terminal))",
    "other agents / coordination": r"\b(agent|session|coordinate|chat with)",
    "pasted alerts": r"(FIRING|ALARM|alert from|CI RED|APPLY FAILED|ECS-TASK-CRASH)",
}

rows = []
for f in glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl")):
    if os.path.getmtime(f) < (datetime.datetime.now().timestamp() - days * 86400):
        continue
    proj = os.path.basename(os.path.dirname(f)).replace("-home-open-claw-documents-code-projects-", "")
    for line in open(f, errors="ignore"):
        try:
            o = json.loads(line)
        except ValueError:
            continue
        if o.get("type") != "user" or o.get("isSidechain") or o.get("isMeta"):
            continue
        ts = o.get("timestamp", "")
        if ts < cut:
            continue
        c = (o.get("message") or {}).get("content")
        if isinstance(c, list):
            t = " ".join(x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text")
        else:
            t = c or ""
        t = re.sub(r"<system-reminder>.*?</system-reminder>", "", t, flags=re.S).strip()
        if (not t or t.startswith("<") or "tool_use_id" in t or t.startswith("Caveat:")
                or "This session is being continued" in t or "cross-session-message" in t):
            continue
        rows.append((ts, proj, t))
rows.sort()

with open(f"{out}/prompts.tsv", "w") as w:
    for ts, p, t in rows:
        w.write(f"{ts[:16]}\t{p}\t{t.replace(chr(10), ' ⏎ ')}\n")

keep = [r for r in rows if len(r[2]) <= 2000]
with open(f"{out}/mid.txt", "w") as w:
    for ts, p, t in keep:
        if len(t) > 80:
            w.write(f"[{ts[5:16]}] {t[:600].replace(chr(10), ' ⏎ ')}\n")

L = [len(r[2]) for r in rows] or [0]
with open(f"{out}/stats.txt", "w") as w:
    w.write(f"prompts={len(rows)} (<=2000 chars: {len(keep)}) days={days}\n")
    w.write(f"median_len={statistics.median(L)} long_pastes={sum(1 for x in L if x > 2000)}\n")
    w.write("projects: " + str(collections.Counter(r[1] for r in rows).most_common(10)) + "\n\n")
    w.write("exact repeats (short prompts):\n")
    rep = collections.Counter(r[2].strip().lower() for r in keep if len(r[2]) < 200)
    for t, n in rep.most_common(30):
        if n > 1:
            w.write(f"  {n:3d}  {t[:100]}\n")
    w.write("\nthemes:\n")
    for k, v in THEMES.items():
        n = sum(1 for r in keep if re.search(v, r[2], re.I))
        w.write(f"  {n:4d} {100 * n / max(len(keep), 1):4.0f}%  {k}\n")
print(open(f"{out}/stats.txt").read())
print(f"mid.txt: {sum(1 for _ in open(out + '/mid.txt'))} lines, ~{os.path.getsize(out + '/mid.txt') // 4} tokens")
