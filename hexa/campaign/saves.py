"""Saved Age of Discovery games: eight named slots, a quicksave and an autosave.

A save file is one line of JSON (what the load screen shows) followed by the pickled world.
Files live in ~/.hexa/saves (or $HEXA_HOME/saves).
"""
import json
import os
import pickle
import time

from .world import CampaignWorld

VERSION = 1
SLOTS = tuple(str(i) for i in range(1, 9))
SPECIAL = ("quick", "auto")
NAMES = {"quick": "Quicksave", "auto": "Autosave"}


def home():
    return os.environ.get("HEXA_HOME") or os.path.join(os.path.expanduser("~"), ".hexa")


def folder():
    return os.path.join(home(), "saves")


def path(slot):
    return os.path.join(folder(), f"{slot}.sav")


def slot_name(slot):
    return NAMES.get(slot, f"Slot {slot}")


def save(world, slot):
    """Write the world to a slot. Returns the meta data written."""
    os.makedirs(folder(), exist_ok=True)
    country = world.countries.get(world.player)
    meta = {"version": VERSION, "slot": slot, "saved": time.time(), "date": world.date(), "turn": world.turn,
            "map": world.geo.name, "tag": world.player, "country": country.name if country else "",
            "treasury": round(country.treasury) if country else 0}
    data = pickle.dumps(world.save_state(), protocol=pickle.HIGHEST_PROTOCOL)
    tmp = path(slot) + ".tmp"
    with open(tmp, "wb") as f:
        f.write(json.dumps(meta).encode("utf-8") + b"\n")
        f.write(data)
    os.replace(tmp, path(slot))            # never leave a half-written save behind
    return meta


def meta(slot):
    """The header of a save, or None if the slot is empty or unreadable."""
    try:
        with open(path(slot), "rb") as f:
            info = json.loads(f.readline().decode("utf-8"))
    except (OSError, ValueError):
        return None
    return info if info.get("version") == VERSION else None


def load(slot):
    """The saved world, or None if there is nothing (readable) in the slot."""
    try:
        with open(path(slot), "rb") as f:
            info = json.loads(f.readline().decode("utf-8"))
            if info.get("version") != VERSION:
                return None
            state = pickle.loads(f.read())
    except (OSError, ValueError, pickle.UnpicklingError, EOFError, AttributeError, ImportError):
        return None
    return CampaignWorld.from_state(state)


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
