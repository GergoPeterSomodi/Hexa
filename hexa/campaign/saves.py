"""Saved Age of Discovery games: eight named slots, a quicksave and an autosave.

A save file is one line of JSON (what the load screen shows) followed by the pickled world.
Files live in ~/.hexa/saves (or $HEXA_HOME/saves).
"""
import json
import os
import pickle
import sys
import time

from .. import settings
from .world import CampaignWorld

# The save format. Bump it only for changes the migration in CampaignWorld._migrate cannot handle:
# saves from older versions still load (missing fields get defaults), newer ones are refused.
VERSION = 1
SLOTS = tuple(str(i) for i in range(1, 9))
SPECIAL = ("quick", "auto")
NAMES = {"quick": "Quicksave", "auto": "Autosave"}


def folder():
    return os.path.join(settings.home(), "saves")


def path(slot):
    return os.path.join(folder(), f"{slot}.sav")


def slot_name(slot):
    return NAMES.get(slot, f"Slot {slot}")


# What a failed save raises: OSError when the folder can't be written (read-only, disk full, ~/.hexa is a file);
# PicklingError, TypeError or (before Python 3.14) AttributeError when something in the world can't be pickled.
SAVE_ERRORS = (OSError, pickle.PicklingError, TypeError, AttributeError)


def save(world, slot):
    """Write the world to a slot. Returns the meta data written.

    Raises one of SAVE_ERRORS if it can't; the slot then keeps its old save and no .tmp file is left behind."""
    os.makedirs(folder(), exist_ok=True)
    country = world.countries.get(world.player)
    meta = {"version": VERSION, "slot": slot, "saved": time.time(), "date": world.date(), "turn": world.turn,
            "map": world.geo.name, "tag": world.player, "country": country.name if country else "",
            "treasury": round(country.treasury) if country else 0}
    data = pickle.dumps(world.save_state(), protocol=pickle.HIGHEST_PROTOCOL)
    tmp = path(slot) + ".tmp"
    try:
        with open(tmp, "wb") as f:
            f.write(json.dumps(meta).encode("utf-8") + b"\n")
            f.write(data)
        os.replace(tmp, path(slot))        # never leave a half-written save behind
    except OSError:
        try:
            os.remove(tmp)
        except OSError:
            pass
        raise
    return meta


def failure(error):
    """Why a save failed, short enough for a toast: "permission denied", "no space left on device"...
    The full error goes to stderr, as for a save that can't be loaded."""
    print(f"Could not save: {type(error).__name__}: {error}", file=sys.stderr)
    if isinstance(error, OSError) and error.strerror:
        return error.strerror.lower()
    return "the game could not be written"


def meta(slot):
    """The header of a save, or None if the slot is empty or unreadable."""
    try:
        with open(path(slot), "rb") as f:
            info = json.loads(f.readline().decode("utf-8"))
    except (OSError, ValueError):
        return None
    return info if _readable(info) else None


def _readable(info):
    version = info.get("version") if isinstance(info, dict) else None
    return isinstance(version, int) and 1 <= version <= VERSION


class LoadError(Exception):
    """A save that was asked for could not be loaded."""


def load(slot):
    """The saved world, or None if there is nothing (readable) in the slot.

    Any failure (a missing file, a broken pickle, a unit kind or class the game no longer has...)
    means "can't load", never a crash."""
    try:
        with open(path(slot), "rb") as f:
            info = json.loads(f.readline().decode("utf-8"))
            if not _readable(info):
                return None
            state = pickle.loads(f.read())
        return CampaignWorld.from_state(state)
    except FileNotFoundError:
        return None
    except Exception as error:      # noqa: BLE001 - an unreadable save must not take the game down
        print(f"Could not load save {slot!r}: {type(error).__name__}: {error}", file=sys.stderr)
        return None


def listing():
    """[(slot, meta or None)] for every slot, quicksave and autosave first."""
    return [(slot, meta(slot)) for slot in SPECIAL + SLOTS]


def latest():
    """The slot saved most recently, or None."""
    found = [(m["saved"], slot) for slot, m in listing() if m]
    return max(found)[1] if found else None


def describe(info):
    when = time.strftime("%d %b %H:%M", time.localtime(info["saved"]))
    who = info["country"] or "no country"
    return f"{who}, {info['date']}  -  {info['map']}  -  saved {when}"
