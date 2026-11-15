"""The list of families, in one place, for the pages that show them all (overview.py, winters.py, crowding.py).

Not a family and not part of the kit: a table. A row is (title, module name, ground, the levels shown as low /
middle / top, draw keywords).
"""
import importlib

FAMILIES = [
    ("Settlements", "settlements", "grass", (2, 3, 5), {}),
    ("Castles", "castles", "grass", (1, 2, 3), {}),
    ("Wheat", "wheat", "farm", (1, 2, 3), {}),
    ("Vineyard", "vineyard", "grass", (1, 2, 3), {}),
    ("Olives", "olives", "grass", (1, 2, 3), {}),
    ("Grazing", "grazing", "grass", (1, 2, 3), {}),
    ("Salt pans", "salt", "sand", (1, 2, 3), {}),
    ("Mines", "mines", "rock", (1, 2, 3), {}),
    ("Timber", "timber", "wood", (1, 2, 3), {}),
    ("Harbour", "harbour", "grass", (1, 2, 3), {}),
    ("Quarry", "quarry", "rock", (1, 2, 3), {}),
    ("Dye works", "dyes", "grass", (1, 2, 3), {}),
    ("Hemp", "hemp", "farm", (1, 2, 3), {}),
    ("Cotton", "cotton", "farm", (1, 2, 3), {}),
    ("Silk", "silk", "grass", (1, 2, 3), {}),
    ("Furs", "furs", "wood", (1, 2, 3), {}),
]
OLD = FAMILIES[:10]                # the ten families of rounds 1 to 3
NEW = FAMILIES[10:]                # the six of round 4
ORES = (None, "iron", "silver", "copper", "gold")
WILD_GROUND = {"Settlements": ("grass", 3), "Castles": ("grass", 3)}        # families without a level 0: kit.wild(ground, seed)


def mod(name):
    return importlib.import_module(name)


def site_names():
    return mod("sites").SITES


def landmark_names():
    return mod("landmarks").NAMES
