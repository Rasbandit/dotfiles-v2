# Sun-Driven Theme Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace darkman with a self-contained Python script, polled every 5 minutes by a systemd user timer, that switches the GNOME color-scheme based on the local sun cycle and respects manual overrides until the next sun event.

**Architecture:** One executable Python script (`~/.local/bin/theme-sun-toggle`) holds pure functions (`solar_events`, `desired_mode`, `decide`) plus a `main()` that reads config + state and shells out to `gsettings`. A `theme-sun.timer` runs `theme-sun.service` at login and every 5 min. State file at `~/.local/state/theme-sun/last-mode` records the last mode the sun-logic applied; the script only switches when the computed desired mode differs from it (boundary crossing), which makes manual overrides stick until the next sunrise/sunset.

**Tech Stack:** Python 3 stdlib only (`math`, `datetime`, `zoneinfo`), `pytest` for tests, `gsettings`, chezmoi, Ansible, systemd user units.

**Spec:** `docs/superpowers/specs/2026-05-26-sun-theme-toggle-design.md`

---

## File Structure

- Create: `private_dot_local/private_bin/executable_theme-sun-toggle` — the script (logic + main). Deploys to `~/.local/bin/theme-sun-toggle`.
- Create: `private_dot_config/theme-sun/config` — `LAT`/`LON`. Deploys to `~/.config/theme-sun/config`.
- Create: `private_dot_config/systemd/user/theme-sun.service` — oneshot runner.
- Create: `private_dot_config/systemd/user/theme-sun.timer` — login + 5-min schedule.
- Create: `tests/theme-sun/test_theme_sun_toggle.py` — unit tests (loads the script by path via importlib; NOT chezmoi-managed, lives at repo root).
- Modify: `ansible/roles/gnome/tasks/main.yml` — drop darkman include, add teardown + timer enable.
- Delete: `ansible/roles/gnome/tasks/darkman.yml`, `private_dot_config/darkman/config.yaml`.

The test file loads the extensionless script with:
```python
import importlib.util
from pathlib import Path
SRC = Path(__file__).resolve().parents[2] / "private_dot_local/private_bin/executable_theme-sun-toggle"
spec = importlib.util.spec_from_file_location("theme_sun_toggle", SRC)
tst = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tst)
```

---

## Task 1: Solar event calculation

**Files:**
- Create: `private_dot_local/private_bin/executable_theme-sun-toggle`
- Test: `tests/theme-sun/test_theme_sun_toggle.py`

- [ ] **Step 1: Write the failing test**

Create `tests/theme-sun/test_theme_sun_toggle.py`:
```python
import datetime
import importlib.util
from pathlib import Path
from zoneinfo import ZoneInfo

SRC = Path(__file__).resolve().parents[2] / "private_dot_local/private_bin/executable_theme-sun-toggle"
spec = importlib.util.spec_from_file_location("theme_sun_toggle", SRC)
tst = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tst)

SLC_LAT, SLC_LON = 40.7619, -111.903
MDT = ZoneInfo("America/Denver")

def test_solar_events_slc_reference():
    # Reference (darkman, same machine): 2026-05-26 sunset ~20:47 MDT,
    # 2026-05-27 sunrise ~06:01 MDT.
    d = datetime.date(2026, 5, 26)
    sunrise, sunset = tst.solar_events(d, SLC_LAT, SLC_LON, MDT)
    assert sunset.hour == 20 and abs(sunset.minute - 47) <= 5
    assert sunrise.hour == 6 and abs(sunrise.minute - 0) <= 5

def test_solar_events_returns_local_tz():
    d = datetime.date(2026, 5, 26)
    sunrise, sunset = tst.solar_events(d, SLC_LAT, SLC_LON, MDT)
    assert sunrise.tzinfo == MDT and sunset.tzinfo == MDT
    assert sunrise < sunset
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/theme-sun/test_theme_sun_toggle.py -v`
Expected: FAIL — file does not exist / `module_from_spec` error or `AttributeError: solar_events`.

- [ ] **Step 3: Write minimal implementation**

Create `private_dot_local/private_bin/executable_theme-sun-toggle`:
```python
#!/usr/bin/env python3
"""Switch GNOME color-scheme based on the local sun cycle.

Applies a mode only when the sun boundary is crossed (computed desired mode
differs from the last mode this script applied), so manual overrides hold
until the next sunrise/sunset.
"""
import math
import datetime
from zoneinfo import ZoneInfo


def solar_events(date, lat, lon, tz):
    """Return (sunrise, sunset) as tz-aware datetimes in `tz` for `date`.

    Implements the Almanac for Computers (1990) sunrise/sunset algorithm.
    Returns (None, None) if the sun does not rise/set (polar day/night).
    """
    def _event(rising, zenith=90.8333):
        n = date.timetuple().tm_yday
        lng_hour = lon / 15.0
        t = n + ((6 if rising else 18) - lng_hour) / 24.0
        m = (0.9856 * t) - 3.289
        true_long = (m + 1.916 * math.sin(math.radians(m))
                     + 0.020 * math.sin(math.radians(2 * m)) + 282.634) % 360
        ra = math.degrees(math.atan(0.91764 * math.tan(math.radians(true_long)))) % 360
        ra += (math.floor(true_long / 90) * 90) - (math.floor(ra / 90) * 90)
        ra /= 15.0
        sin_dec = 0.39782 * math.sin(math.radians(true_long))
        cos_dec = math.cos(math.asin(sin_dec))
        cos_h = ((math.cos(math.radians(zenith)) - sin_dec * math.sin(math.radians(lat)))
                 / (cos_dec * math.cos(math.radians(lat))))
        if cos_h > 1 or cos_h < -1:
            return None
        h = (360 - math.degrees(math.acos(cos_h))) if rising else math.degrees(math.acos(cos_h))
        h /= 15.0
        local_t = h + ra - (0.06571 * t) - 6.622
        ut = (local_t - lng_hour) % 24
        hours = int(ut)
        minutes = int(round((ut - hours) * 60))
        base = datetime.datetime(date.year, date.month, date.day,
                                 tzinfo=datetime.timezone.utc)
        return (base + datetime.timedelta(hours=hours, minutes=minutes)).astimezone(tz)

    sunrise = _event(rising=True)
    sunset = _event(rising=False)
    return sunrise, sunset
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/theme-sun/test_theme_sun_toggle.py -v`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add private_dot_local/private_bin/executable_theme-sun-toggle tests/theme-sun/test_theme_sun_toggle.py
git commit -m "feat(gnome): add solar_events calc for sun theme toggle"
```

---

## Task 2: Desired-mode and decision logic

**Files:**
- Modify: `private_dot_local/private_bin/executable_theme-sun-toggle`
- Test: `tests/theme-sun/test_theme_sun_toggle.py`

- [ ] **Step 1: Write the failing test**

Append to `tests/theme-sun/test_theme_sun_toggle.py`:
```python
def _dt(h, m=0):
    return datetime.datetime(2026, 5, 26, h, m, tzinfo=MDT)

def test_desired_mode_daytime_is_light():
    assert tst.desired_mode(_dt(12), _dt(6), _dt(20)) == "light"

def test_desired_mode_before_sunrise_is_dark():
    assert tst.desired_mode(_dt(5), _dt(6), _dt(20)) == "dark"

def test_desired_mode_after_sunset_is_dark():
    assert tst.desired_mode(_dt(21), _dt(6), _dt(20)) == "dark"

def test_desired_mode_at_sunrise_boundary_is_light():
    assert tst.desired_mode(_dt(6), _dt(6), _dt(20)) == "light"

def test_decide_first_run_applies():
    assert tst.decide("dark", None) == ("apply", "dark")

def test_decide_boundary_crossed_applies():
    assert tst.decide("dark", "light") == ("apply", "dark")

def test_decide_same_period_skips():
    assert tst.decide("light", "light") == ("skip", "light")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/theme-sun/test_theme_sun_toggle.py -v`
Expected: FAIL — `AttributeError: desired_mode` / `decide`.

- [ ] **Step 3: Write minimal implementation**

Add to `executable_theme-sun-toggle` after `solar_events`:
```python
def desired_mode(now, sunrise, sunset):
    """Return 'light' between sunrise (inclusive) and sunset (exclusive), else 'dark'."""
    if sunrise is None or sunset is None:
        return "dark"
    return "light" if sunrise <= now < sunset else "dark"


def decide(desired, last):
    """Return ('apply', desired) on first run or sun-boundary crossing; else ('skip', last)."""
    if last is None or desired != last:
        return ("apply", desired)
    return ("skip", last)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/theme-sun/test_theme_sun_toggle.py -v`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add private_dot_local/private_bin/executable_theme-sun-toggle tests/theme-sun/test_theme_sun_toggle.py
git commit -m "feat(gnome): add desired_mode and decide logic"
```

---

## Task 3: Config, state I/O, apply, and main()

**Files:**
- Modify: `private_dot_local/private_bin/executable_theme-sun-toggle`
- Test: `tests/theme-sun/test_theme_sun_toggle.py`

- [ ] **Step 1: Write the failing test**

Append to the test file:
```python
def test_read_config_parses_lat_lon(tmp_path):
    p = tmp_path / "config"
    p.write_text("LAT=40.7619\nLON=-111.903\n# comment\n\n")
    cfg = tst.read_config(p)
    assert cfg == {"LAT": 40.7619, "LON": -111.903}

def test_state_roundtrip(tmp_path):
    p = tmp_path / "last-mode"
    assert tst.read_state(p) is None
    tst.write_state(p, "dark")
    assert tst.read_state(p) == "dark"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/theme-sun/test_theme_sun_toggle.py -v`
Expected: FAIL — `AttributeError: read_config` / `read_state`.

- [ ] **Step 3: Write minimal implementation**

Add to the script:
```python
import os
import subprocess
from pathlib import Path

CONFIG_PATH = Path(os.path.expanduser("~/.config/theme-sun/config"))
STATE_PATH = Path(os.path.expanduser("~/.local/state/theme-sun/last-mode"))


def read_config(path=CONFIG_PATH):
    cfg = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        cfg[key.strip()] = float(val.strip())
    return cfg


def read_state(path=STATE_PATH):
    p = Path(path)
    if not p.exists():
        return None
    val = p.read_text().strip()
    return val or None


def write_state(path, mode):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(mode + "\n")


def apply_mode(mode):
    value = "prefer-dark" if mode == "dark" else "prefer-light"
    subprocess.run(
        ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", value],
        check=True,
    )


def main():
    cfg = read_config()
    tz = datetime.datetime.now().astimezone().tzinfo
    now = datetime.datetime.now(tz)
    sunrise, sunset = solar_events(now.date(), cfg["LAT"], cfg["LON"], tz)
    desired = desired_mode(now, sunrise, sunset)
    action, _ = decide(desired, read_state())
    if action == "apply":
        apply_mode(desired)
        write_state(STATE_PATH, desired)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/theme-sun/test_theme_sun_toggle.py -v`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add private_dot_local/private_bin/executable_theme-sun-toggle tests/theme-sun/test_theme_sun_toggle.py
git commit -m "feat(gnome): add config/state IO, gsettings apply, and main"
```

---

## Task 4: Config file and systemd units (chezmoi)

**Files:**
- Create: `private_dot_config/theme-sun/config`
- Create: `private_dot_config/systemd/user/theme-sun.service`
- Create: `private_dot_config/systemd/user/theme-sun.timer`

- [ ] **Step 1: Create the config file**

Create `private_dot_config/theme-sun/config`:
```
# Coordinates for sunrise/sunset calculation (decimal degrees).
LAT=40.7619
LON=-111.903
```

- [ ] **Step 2: Create the service unit**

Create `private_dot_config/systemd/user/theme-sun.service`:
```ini
[Unit]
Description=Set GNOME color-scheme based on the sun cycle
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/theme-sun-toggle
```

- [ ] **Step 3: Create the timer unit**

Create `private_dot_config/systemd/user/theme-sun.timer`:
```ini
[Unit]
Description=Poll the sun cycle every 5 minutes to set the theme

[Timer]
OnStartupSec=30s
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

- [ ] **Step 4: Verify chezmoi sees the new files**

Run: `chezmoi diff ~/.config/theme-sun/config ~/.config/systemd/user/theme-sun.service ~/.config/systemd/user/theme-sun.timer`
Expected: diff shows all three files as new additions.

- [ ] **Step 5: Commit**

```bash
git add private_dot_config/theme-sun/config private_dot_config/systemd/user/theme-sun.service private_dot_config/systemd/user/theme-sun.timer
git commit -m "feat(gnome): add theme-sun config and systemd timer units"
```

---

## Task 5: Ansible teardown of darkman + enable timer

**Files:**
- Modify: `ansible/roles/gnome/tasks/main.yml:117-118`
- Delete: `ansible/roles/gnome/tasks/darkman.yml`
- Delete: `private_dot_config/darkman/config.yaml`

- [ ] **Step 1: Replace the darkman include in main.yml**

In `ansible/roles/gnome/tasks/main.yml`, replace:
```yaml
- name: Include darkman setup
  ansible.builtin.include_tasks: darkman.yml
```
with:
```yaml
- name: Disable and stop darkman (replaced by theme-sun timer)
  ansible.builtin.systemd:
    name: darkman
    enabled: false
    state: stopped
    scope: user
  become: false
  failed_when: false

- name: Reload systemd user daemon
  ansible.builtin.systemd:
    daemon_reload: true
    scope: user
  become: false

- name: Enable and start theme-sun timer
  ansible.builtin.systemd:
    name: theme-sun.timer
    enabled: true
    state: started
    scope: user
  become: false
```

- [ ] **Step 2: Delete the obsolete files**

Run:
```bash
git rm ansible/roles/gnome/tasks/darkman.yml private_dot_config/darkman/config.yaml
```
Expected: both files staged for deletion. (The `private_dot_config/darkman` directory becomes empty and is dropped by git.)

- [ ] **Step 3: Lint the playbook syntax**

Run: `ansible-playbook ansible/setup.yml --syntax-check`
Expected: `playbook: ansible/setup.yml` with no errors.

- [ ] **Step 4: Commit**

```bash
git add ansible/roles/gnome/tasks/main.yml
git commit -m "feat(gnome): replace darkman with theme-sun timer in ansible"
```

---

## Task 6: Deploy and verify on this machine

**Files:** none (deploy + verification only)

- [ ] **Step 1: Apply chezmoi**

Run: `chezmoi apply`
Then verify deploys:
```bash
test -x ~/.local/bin/theme-sun-toggle && echo script-ok
cat ~/.config/theme-sun/config
ls ~/.config/systemd/user/theme-sun.service ~/.config/systemd/user/theme-sun.timer
```
Expected: `script-ok`, the config contents, and both unit paths listed.

- [ ] **Step 2: Stop/disable the running darkman service**

Run:
```bash
systemctl --user disable --now darkman
systemctl --user daemon-reload
```
Expected: darkman removed from autostart; no error.

- [ ] **Step 3: Enable and start the timer**

Run:
```bash
systemctl --user enable --now theme-sun.timer
systemctl --user list-timers theme-sun.timer --no-pager
```
Expected: timer listed with a NEXT time within ~5 min.

- [ ] **Step 4: Run the toggle once and confirm it sets the right mode**

Run:
```bash
~/.local/bin/theme-sun-toggle
gsettings get org.gnome.desktop.interface color-scheme
cat ~/.local/state/theme-sun/last-mode
```
Expected: color-scheme matches the sun state for the current time (daytime → `'prefer-light'`), and the state file holds the same mode.

- [ ] **Step 5: Verify manual override holds**

Run:
```bash
# Flip opposite to current desired, then re-run the toggle.
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
~/.local/bin/theme-sun-toggle
gsettings get org.gnome.desktop.interface color-scheme
```
Expected: still `'prefer-dark'` — the toggle did NOT revert it, because `desired == last` (same sun period). Confirms manual override survives polls until the next sun event.

- [ ] **Step 6: Restore auto state and finish**

Run:
```bash
~/.local/bin/theme-sun-toggle   # no-op; leaves manual choice
```
Note: at the next sunrise/sunset the timer will resume auto-switching. No commit (verification only).
