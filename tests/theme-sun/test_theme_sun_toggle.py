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

def _dt(h, m=0):
    return datetime.datetime(2026, 5, 26, h, m, tzinfo=MDT)

def test_desired_mode_daytime_is_light():
    assert tst.desired_mode(_dt(12), _dt(6), _dt(20)) == "light"

def test_desired_mode_before_sunrise_is_dark():
    assert tst.desired_mode(_dt(5), _dt(6), _dt(20)) == "dark"

def test_desired_mode_after_sunset_still_light_within_offset():
    # sunset 20:00, dark starts 20:30 — at 20:15 should still be light
    assert tst.desired_mode(_dt(20, 15), _dt(6), _dt(20)) == "light"

def test_desired_mode_after_offset_is_dark():
    # at 20:30 (sunset + 30 min) dark mode kicks in
    assert tst.desired_mode(_dt(20, 30), _dt(6), _dt(20)) == "dark"

def test_desired_mode_well_after_sunset_is_dark():
    assert tst.desired_mode(_dt(21), _dt(6), _dt(20)) == "dark"

def test_desired_mode_at_sunrise_boundary_is_light():
    assert tst.desired_mode(_dt(6), _dt(6), _dt(20)) == "light"

def test_decide_first_run_applies():
    assert tst.decide("dark", None) == ("apply", "dark")

def test_decide_boundary_crossed_applies():
    assert tst.decide("dark", "light") == ("apply", "dark")

def test_decide_same_period_skips():
    assert tst.decide("light", "light") == ("skip", "light")

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
