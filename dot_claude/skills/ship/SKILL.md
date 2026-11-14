---
name: ship
description: Take a PR from "code done" to merged safely - adversarial review posted, fixes applied, red/green proof, rebase, CI watch, merge on green. Use on "/ship", "merge when green", "get it merge worthy", "adversarial review and do fixes", "get this merged", "rebase and merge".
argument-hint: <PR number or branch> [more PRs, merged in the order given]
---

Ship each PR in `$ARGUMENTS` one at a time. Every merge forces a rebase on the others, so never run CI on a PR that will need a rebase before it can merge.

## 1. Consolidate first
- List the open PRs for the same initiative (`gh pr list --author @me`, or by branch prefix). If several belong to one initiative, fold them into one branch and close the others with "superseded by ...". One initiative = one PR.
- Cancel in-flight CI runs on branches that will need a rebase anyway (`gh run cancel`).

## 2. Review (skip only for release-please PRs)
- If the PR has no `ADVERSARIAL REVIEW:` comment at its current head, spawn ONE background reviewer agent (a different agent than the author). The reviewer must:
  - hunt for real defects, not style
  - hunt for duplication: for each new function, constant or component in the diff, grep the repo for an existing one that does the same job. A copy of existing logic is always a finding (severity Important), never an accepted risk; the fix is to rewrite it into one shared module and point every caller at it
  - in Engram repos, flag new CPU-bound pure code (parsing, tokenizing, hashing, regex, encoding) written in Elixir or TS where a Rust NIF/WASM home exists; see the repo's NIF/WASM rules
  - for each defect: write a failing test, fix it, commit signed, push once
  - post `gh pr comment` starting `ADVERSARIAL REVIEW: <APPROVE|REQUEST_CHANGES> @ <sha>`, with each finding's severity, file:line, scenario, and fix SHA or accepted risk
  - run only targeted tests locally, under `systemd-run --user --scope -p MemoryMax=4G`
- If a fix touches crypto, auth, sync or data paths, spawn a fresh delta-check agent on just those commits.

## 3. Merge
- Up to date with main? If BEHIND: rebase LOCALLY in a temp detached worktree (keeps commit signatures; check `git log --format=%G?`). Use `gh pr update-branch` (a merge, not a rebase) only for bot PRs. Never `git stash`.
- Watch CI with one background command that merges only if every check passes AND the head SHA is unchanged:
  `gh pr merge <n> --squash --match-head-commit <sha>`
- Never `--auto`, never `--admin`, never merge on red. A known flake gets ONE rerun and a named issue, never a silent retry loop.
- Then the next PR in the list: rebase it onto the new main, and repeat.

## 4. Report
Use the `/checkin` shape. Name each PR by what it does. State which test proves the fix.
