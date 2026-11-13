"""Player options, kept in ~/.hexa/settings.json (or $HEXA_HOME/settings.json)."""
import json
import os
import sys

WINDOWS = ("1280x720", "1600x900", "1920x1080")
AUTOSAVE = ("off", "year", "5 years")
AUTOSAVE_TURNS = {"off": 0, "year": 4, "5 years": 20}
SCROLL = {"slow": 10, "normal": 18, "fast": 30}
MOVEMENT = ("off", "normal", "slow")          # how fast the moves you can see are replayed (campaign/replay.py)
BATTLE_TIMING = ("clash", "full")             # battle days: day 1 in the attack's season, or all days at once (systems/battle.py)
DEFAULTS = {"fullscreen": False, "window": "1280x720", "autosave": "year", "scroll": "normal", "grid": True,
            "pass_names": False, "movement": "normal", "reminders": True, "battle_timing": "clash"}
CHOICES = {"fullscreen": (False, True), "window": WINDOWS, "autosave": AUTOSAVE, "scroll": tuple(SCROLL),
           "grid": (False, True), "pass_names": (False, True), "movement": MOVEMENT, "reminders": (False, True),
           "battle_timing": BATTLE_TIMING}


def home():
    """The folder for player data (options and saves): $HEXA_HOME, else ~/.hexa. The one place that decides it."""
    return os.environ.get("HEXA_HOME") or os.path.join(os.path.expanduser("~"), ".hexa")


def _path():
    return os.path.join(home(), "settings.json")


def load():
    settings = dict(DEFAULTS)
    try:
        with open(_path(), encoding="utf-8") as f:
            stored = json.load(f)
    except (OSError, ValueError, RecursionError):   # RecursionError: nested deeper than Python allows
        return settings
    if not isinstance(stored, dict):            # valid JSON, but not an object: same as a missing file
        return settings
    for key, value in stored.items():
        if key in CHOICES and value in CHOICES[key]:
            settings[key] = next(c for c in CHOICES[key] if c == value)    # 0 / 1.0 become False / True
    return settings


def save(settings):
    """Write the options for next time. Returns False if that fails (read-only folder, full disk...):
    the options then last until the game closes, and the old file is left as it was."""
    path = _path()
    tmp = path + ".tmp"
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({k: settings[k] for k in DEFAULTS}, f, indent=2)
        os.replace(tmp, path)               # never leave a half-written settings.json behind
    except OSError as error:
        print(f"Could not save options to {path}: {error}", file=sys.stderr)
        try:
            os.remove(tmp)
        except OSError:
            pass
        return False
    return True


def cycle(settings, key):
    """Step an option to its next choice."""
    options = CHOICES[key]
    settings[key] = options[(options.index(settings[key]) + 1) % len(options)]
    return settings[key]


def window_size(settings):
    w, h = settings["window"].split("x")
    return int(w), int(h)
