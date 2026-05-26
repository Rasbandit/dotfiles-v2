# Sun-Driven Theme Toggle — Design

**Date:** 2026-05-26
**Status:** Approved
**Replaces:** darkman (commit 7a41d67)

## Problem

The auto light/dark theme toggle (darkman, added in 7a41d67) never worked on this
machine: the gnome Ansible role's `darkman.yml` tasks never re-ran, so the service
stayed disabled/inactive and the `~/.local/share/{dark,light}-mode.d` transition
scripts were never created. Even when started, darkman has no concept of a manual
override, and we want explicit, fully-owned control tied to the sun cycle.

## Goal

A single, self-contained mechanism that:

1. Switches the OS color-scheme (dark/light) based on the local sun cycle.
2. Respects a manual override **until the next sun event** (next sunrise or sunset).
3. Polls every 5 minutes so a missed transition (suspend/downtime) self-heals.
4. Is fully owned by us — no dependence on darkman internals.

## Approach (chosen: A — self-contained poll)

One Python script computes today's sunrise/sunset for configured coordinates,
derives the desired mode, and applies it **only when the sun boundary is crossed**.
A systemd user timer runs it at login and every 5 minutes.

### Why "only on boundary crossing" gives manual-override-for-free

The script never reconciles *within* a sun period. It only acts when `desired`
differs from the last mode the sun-logic itself applied (`state`). So a manual
change mid-period is never overwritten — the next poll sees `desired == state`
and does nothing. At the next sunrise/sunset, `desired` flips, `desired != state`,
and auto-switching resumes.

## Components (all chezmoi-managed)

| Component | Path in repo | Deployed to |
|---|---|---|
| Toggle script | `private_dot_local/private_bin/executable_theme-sun-toggle` | `~/.local/bin/theme-sun-toggle` |
| Config | `private_dot_config/theme-sun/config` | `~/.config/theme-sun/config` |
| systemd service | `private_dot_config/systemd/user/theme-sun.service` | `~/.config/systemd/user/theme-sun.service` |
| systemd timer | `private_dot_config/systemd/user/theme-sun.timer` | `~/.config/systemd/user/theme-sun.timer` |
| State file (runtime) | — (not managed) | `~/.local/state/theme-sun/last-mode` |

### Config format

```
LAT=40.76190
LON=-111.903
```

Seeded with the coordinates geoclue resolved for this machine. Plain `KEY=value`,
parsed by the script. Poll interval lives in the `.timer`, not here.

### Core logic (pseudocode)

```
config = read_config()                          # LAT, LON
sunrise, sunset = solar_events(today, LAT, LON) # local time
desired = "light" if sunrise <= now < sunset else "dark"
last = read_state()                             # last mode sun-logic applied, or None

if last is None:            apply(desired); save(desired)   # first run
elif desired != last:       apply(desired); save(desired)   # sun boundary crossed
else:                       pass                            # same period → respect manual
```

`apply(mode)` runs:
`gsettings set org.gnome.desktop.interface color-scheme prefer-<mode>`

Scope is **color-scheme only** — every other tool the user runs follows the OS
dark/light setting. No GTK theme name swapping.

### Solar calculation

Pure-stdlib implementation of the NOAA sunrise/sunset algorithm (no external
dependencies). Inputs: date, latitude, longitude. Output: local sunrise and sunset
`datetime`s. Must match a known reference within a few minutes' tolerance.

### Scheduling

- `theme-sun.service` — `Type=oneshot`, `ExecStart=%h/.local/bin/theme-sun-toggle`.
- `theme-sun.timer` — `OnStartupSec` (fires shortly after login/graphical session)
  + `OnUnitActiveSec=5min`. `WantedBy=timers.target`.
- Enabled per existing repo pattern for systemd user units.

## Teardown of darkman

- Ansible: remove the `include_tasks: darkman.yml` from
  `ansible/roles/gnome/tasks/main.yml`; delete `darkman.yml`; add a task to
  disable + stop `darkman.service` and enable the new `theme-sun.timer`.
- Delete `private_dot_config/darkman/`.
- Remove the `~/.local/share/{dark,light}-mode.d/00-gnome-color-scheme.sh` scripts
  (and stop/disable the running darkman service on this machine).
- `darkman` and `geoclue2` packages: left installed (harmless); we only disable the
  service. geoclue is no longer required since coords are configured. Removing the
  package from the dnf install list is deferred to avoid churn.

## Testing (TDD)

Pure functions are unit-tested with pytest:

- `desired_mode(now, sunrise, sunset)` — boundary cases: just before/after sunrise,
  just before/after sunset, midnight.
- `decide(desired, last)` — first run (last=None), boundary crossed, same period.
- `solar_events(date, lat, lon)` — against a known reference value within tolerance.

`apply_mode` (gsettings shell-out) and file I/O are thin and tested via integration
where practical, not unit-mocked.

## Edge cases

- **First run / new day with stale state:** state from a prior day differing from
  current desired → treated as a boundary crossing → applies correctly.
- **DST / timezone:** sunrise/sunset recomputed each run for today in local time.
- **Polar/extreme latitudes:** out of scope (user is at ~40°N).
- **Switching precision:** within the 5-minute poll window — accepted.

## Out of scope

- GTK3 legacy theme name swapping.
- Per-app theme control.
- A GUI/applet for toggling (use `gsettings`/quick settings directly).
