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
