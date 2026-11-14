---
name: triage
description: Triage a pasted alert (Grafana, CloudWatch, ECS-TASK-CRASH, Sentry, Unraid, CI RED, PROD APPLY FAILED, Discord bot) - deploy noise or real, with evidence, then an issue or an alert fix. Use when the user pastes an alert, or asks "is this from you", "is this real", "are we fixing these".
argument-hint: <pasted alert text>
---

Goal: in a few minutes, answer **real bug, expected noise, or our own action**. Prove it with evidence; never guess. Everything here is read-only: no prod changes, no restarts, no silences.

## 1. Place it in time
- Pull the alert's timestamp, service, and IDs (task ARN, run URL, alert name).
- Was something deploying or merging then? Check: the infra apply runs (`gh run list -R engram-app/engram-infra`), ECS deployments, recent merges to main, and your own session's actions. "Is this from you?" means: check your own actions first.

## 2. Get the evidence
- **Logs:** Loki only receives warning and error lines (FireLens routing). The FULL container stdout, including migration output and boot crashes, is in CloudWatch `/ecs/engram-saas-prod`, stream `engram-engram-firelens-<task-id>`:
  `aws logs get-log-events --log-group-name /ecs/engram-saas-prod --log-stream-name engram-engram-firelens-<task> --start-from-head --profile engram-audit --region us-east-1`
- **Metrics:** VictoriaMetrics datasource `efjt5zm3rh62od`. Tasks up by role: `count by (role) (up{job="prometheus.scrape.engram_app", env="prod"} == 1)`.
- **DB:** read-only via the bastion as `engram_audit_ro` (RLS hides tenant rows, so use `pg_stat_user_tables` for counts). Stop the bastion after.
- **Baseline:** compare the same window on a previous day or before the deploy. A raw count rise means nothing unless volume is flat.

## 3. Verdict and action
- **Real bug** (crash, data risk, user-facing errors): file an issue in the owning repo with the exact log lines, the timeline, the root cause, and fix candidates. Recommend the fix.
- **Noise** (expected deploy stop, a known bot class, a threshold too tight): propose the alert fix as a PR in engram-infra. Don't merge it. Never add a blanket silence.
- **Our own action:** say which action, and whether it needs undoing.

## 4. Report (3 lines)
```
Verdict: <real / noise / ours> - <one-line root cause>
Evidence: <the single most convincing log line or metric, with where it came from>
Action: <issue or PR link, or "none needed" and why>
```
