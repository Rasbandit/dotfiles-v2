---
name: checkin
description: Fixed-shape status report for a user juggling many agents. Use on "/checkin", "check in", "report", "status", "where are we at", "what's next", "I'm managing a lot", "keep it simple", "what do you need from me".
argument-hint: [optional scope, e.g. "v5" or "merges"]
---

The user runs many agents at once and reads this in a few seconds. Every report has the same shape so they never have to ask twice.

## Before writing

Check live state; don't report from memory. Run only what's needed:
- PRs you own: `gh pr view <n> --json state,mergeStateStatus,headRefOid` and `gh pr checks <n>`.
- Background tasks and agents you started: their latest output.
- Prod or staging, if you touched them: `/health`, plus the one metric that matters.

If `$ARGUMENTS` names a scope, report only that.

## Output (exactly this shape)

```
**Moved:** <1-3 bullets: what changed since the last check-in, outcome first>
**Blocked / waiting:** <1-3 bullets: what's in flight, what it waits on, ETA if known. "Nothing" if nothing>
**Next:** <the one next step you're taking without them>
>> NEED: <one question with your default>   (omit this line if you need nothing)
```

Rules:
- Name PRs by what they do ("the folder-delete fix"), never by bare number. A number may follow in parentheses.
- No PR tables, no file lists, no history recap.
- Plain words. Define any metric the first time.
- If something is broken or you are unsure, it goes under Blocked, stated plainly.
- If the user said "dumb brain", "tired", or "keep it simple": at most 5 lines total.
