"""Player options, kept in ~/.hexa/settings.json (or $HEXA_HOME/settings.json)."""
import json
import os

WINDOWS = ("1280x720", "1600x900", "1920x1080")
AUTOSAVE = ("off", "year", "5 years")
AUTOSAVE_TURNS = {"off": 0, "year": 4, "5 years": 20}
SCROLL = {"slow": 10, "normal": 18, "fast": 30}
DEFAULTS = {"fullscreen": False, "window": "1280x720", "autosave": "year", "scroll": "normal"}
CHOICES = {"fullscreen": (False, True), "window": WINDOWS, "autosave": AUTOSAVE, "scroll": tuple(SCROLL)}


def _path():
    home = os.environ.get("HEXA_HOME") or os.path.join(os.path.expanduser("~"), ".hexa")
    return os.path.join(home, "settings.json")


def load():
    settings = dict(DEFAULTS)
    try:
        with open(_path(), encoding="utf-8") as f:
            stored = json.load(f)
    except (OSError, ValueError):
        return settings
    if not isinstance(stored, dict):            # valid JSON, but not an object: same as a missing file
        return settings
    for key, value in stored.items():
        if key in CHOICES and value in CHOICES[key]:
            settings[key] = value
    return settings


def save(settings):
    os.makedirs(os.path.dirname(_path()), exist_ok=True)
    with open(_path(), "w", encoding="utf-8") as f:
        json.dump({k: settings[k] for k in DEFAULTS}, f, indent=2)


def cycle(settings, key):
    """Step an option to its next choice."""
    options = CHOICES[key]
    settings[key] = options[(options.index(settings[key]) + 1) % len(options)]
    return settings[key]


def window_size(settings):
    w, h = settings["window"].split("x")
    return int(w), int(h)
