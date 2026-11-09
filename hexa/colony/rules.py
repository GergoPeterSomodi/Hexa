"""Colonisation mode data: sides, seasons, terrain, buildings, units, natives and the homeland.

Every balance number of the colonisation mode lives here.
"""
from dataclasses import dataclass, field

from ..rules import Terrain

# ----- sides ---------------------------------------------------------------------
PLAYER = "player"
CRIMSON = "crimson"
GOLDEN = "golden"
NATIVES = "natives"
CROWN = "crown"
DRAW = "draw"
COLONISERS = (PLAYER, CRIMSON, GOLDEN)
RIVALS = (CRIMSON, GOLDEN)
TURN_ORDER = (PLAYER, CRIMSON, GOLDEN, NATIVES, CROWN)
SIDE_NAMES = {PLAYER: "Your", CRIMSON: "Crimson Company", GOLDEN: "Golden Company",
              NATIVES: "Native", CROWN: "Royal"}

# ----- game setup ----------------------------------------------------------------
START_SEA = "sea"        # arrive by ship and pick where to land
START_LAND = "land"      # start with a small colony already on the coast
GOAL_SURVIVE = "survive"            # best colony after SURVIVE_TURNS wins
GOAL_INDEPENDENCE = "independence"  # declare independence and beat the royal army
GOAL_ENDLESS = "endless"            # no end; just grow
GOAL_NAMES = {GOAL_SURVIVE: "Survive 10 years", GOAL_INDEPENDENCE: "Independence", GOAL_ENDLESS: "Endless"}
START_NAMES = {START_SEA: "Arrive by sea", START_LAND: "Settled coast"}

MAP_COLS, MAP_ROWS = 32, 20

# ----- time ----------------------------------------------------------------------
SEASONS = ("Spring", "Summer", "Autumn", "Winter")
START_YEAR = 1610
SURVIVE_TURNS = 40       # 10 years of 4 seasons


def season(turn):
    return SEASONS[(turn - 1) % 4]


def year(turn):
    return START_YEAR + (turn - 1) // 4


# ----- terrain -------------------------------------------------------------------
TERRAIN = {t.key: t for t in (
    Terrain("grass", "Grassland", ("Terrain/Grass/grass_05.png", "Terrain/Grass/grass_19.png"), 1, 0),
    Terrain("dirt", "Plains", ("Terrain/Dirt/dirt_06.png", "Terrain/Dirt/dirt_19.png"), 1, 0),
    Terrain("forest", "Forest", ("Terrain/Grass/grass_12.png", "Terrain/Grass/grass_13.png"), 2, 1),
    Terrain("hills", "Hills", ("Terrain/Grass/grass_15.png",), 2, 2),
    Terrain("mountain", "Mountain", ("Terrain/Grass/grass_14.png",), None, 0),
    Terrain("water", "Lake", ("Terrain/Grass/lake.png",), None, 0),
    Terrain("beach", "Beach", ("Terrain/Sand/sand_05.png", "Terrain/Sand/sand_19.png"), 1, 0),
    Terrain("ocean", "Ocean", ("(drawn)",), None, 0),     # the renderer draws open sea itself
)}

# ----- resources and buildings ---------------------------------------------------
RESOURCES = ("food", "wood", "furs", "gold")
SHORT = {"food": "F", "wood": "W", "furs": "Fur", "gold": "G"}
START_STOCK = {"food": 12, "wood": 6, "furs": 0, "gold": 6}


def cost_text(cost):
    return " ".join(f"{n}{SHORT[r]}" for r, n in cost.items()) or "free"


@dataclass(frozen=True)
class Improvement:
    key: str
    name: str
    sprite: str
    terrains: tuple
    yields: dict
    cost: dict
    winter: dict | None = None     # yields in winter, if different


IMPROVEMENTS = {i.key: i for i in (
    Improvement("farm", "Farm", "Medieval/medieval_farm.png", ("grass", "dirt"),
                {"food": 3}, {"wood": 2}, winter={}),
    Improvement("fishery", "Fishery", "Mill/mill_warehouse.png", ("beach",), {"food": 2}, {"wood": 2}),
    Improvement("trapper", "Trapper camp", "Medieval/medieval_lumber.png", ("forest",),
                {"wood": 2, "furs": 1}, {"food": 2}, winter={"wood": 1, "furs": 2}),
    Improvement("mine", "Silver mine", "Medieval/medieval_mine.png", ("hills",), {"gold": 2}, {"wood": 3}),
)}
IMPROVEMENT_FOR_TERRAIN = {t: i for i in IMPROVEMENTS.values() for t in i.terrains}

# ----- colonies ------------------------------------------------------------------
COLONY_SPRITES = ((3, "Medieval/medieval_cabin.png"), (5, "Medieval/medieval_house.png"),
                  (99, "Medieval/medieval_openCastle.png"))   # (pop below, sprite)
COLONY_BASE = {"food": 2, "wood": 1}   # the colony's own hex
POP_FOOD = 1             # food each colonist living in a colony eats per turn
FIREWOOD = 1             # wood each colony burns per winter turn
TERRITORY_RADIUS = 2
MIN_COLONY_SPACING = 3
MIN_VILLAGE_SPACING = 2  # colonies may not be founded this close to a native village
MAX_POP = 8
GROW_COST = {"food": 6}  # +1 population
COLONIST_FOOD = 2        # turning 1 population into a colonist unit also packs this much food
STOCKADE_COST = {"wood": 5}
COLONY_DEFENSE = 1       # extra defense for a unit in its own colony
STOCKADE_DEFENSE = 2     # extra on top of that once a stockade is built
COLONY_SIGHT = 2
COLONY_HEAL = 2
REST_HEAL = 1
FEVER_CHANCE = 0.12      # each summer, a colony of 3+ may lose 1 population to fever
COLD_DAMAGE = 1          # winter: land units outside your own land lose this much HP
COLONY_SCORE, POP_SCORE, BUILDING_SCORE = 10, 5, 2

COLONY_NAMES = ("New Haven", "Fort Hope", "Port Royal", "Greenfield", "Stonebrook", "Ashford", "Millbay",
                "Elmwood", "Redcliff", "Saltmarsh", "Oakridge", "Fairwind", "Kingsport", "Westmoor",
                "Harrowgate", "Brightwater", "Pinecrest", "Northwatch", "Cedarholm", "Lowmere")


# ----- units ---------------------------------------------------------------------
@dataclass(frozen=True)
class UnitType:
    key: str
    name: str
    max_hp: int
    attack: int
    defense: int
    moves: int
    sight: int
    cost: dict | None = None    # trained in a colony for this, if not None
    price: int = 0              # bought in the homeland for this much gold, if > 0
    can_capture: bool = False   # may take colonies
    upkeep: int = 0             # food eaten per turn
    naval: bool = False
    capacity: int = 0           # land units a ship can carry
    raider: bool = False        # raids undefended colonies instead of capturing them


SHIP = UnitType("ship", "Ship", 12, 0, 1, 5, 2, naval=True, capacity=4)
COLONIST = UnitType("colonist", "Colonist", 4, 0, 0, 2, 1, price=6)
PIONEER = UnitType("pioneer", "Pioneer", 4, 0, 0, 2, 1, cost={"food": 3, "wood": 1}, price=5)
SCOUT = UnitType("scout", "Scout", 6, 2, 0, 4, 3, cost={"food": 2, "wood": 1}, price=4)
SOLDIER = UnitType("soldier", "Soldier", 10, 5, 1, 2, 2, cost={"food": 2, "wood": 2, "gold": 2},
                   price=8, can_capture=True, upkeep=1)
BRAVE = UnitType("brave", "Brave", 8, 4, 1, 3, 2, raider=True)
REGULAR = UnitType("regular", "Regular", 12, 6, 2, 2, 2, can_capture=True)
UNIT_TYPES = {u.key: u for u in (SHIP, COLONIST, PIONEER, SCOUT, SOLDIER, BRAVE, REGULAR)}
TRAINABLE = (SCOUT, PIONEER, SOLDIER)
BUYABLE = (COLONIST, PIONEER, SOLDIER)

# ----- the homeland (reached by sailing a ship to the east edge of the map) -------
FUR_PRICE = 2            # gold per fur
WOOD_LOT, WOOD_LOT_PRICE = 4, 2     # sell 4 wood for 2 gold
FOOD_LOT, FOOD_LOT_PRICE = 6, 3     # buy 6 food for 3 gold
FAVOUR_FOR_COLONIST = 8  # furs sold earn the Crown's favour; each spring it sends a free colonist

# ----- natives -------------------------------------------------------------------
TRIBE_NAMES = ("River People", "Hill People", "Forest People")
VILLAGE_SPRITE = "Western/western_indians.png"
RUINS_SPRITE = "Medieval/medieval_ruins.png"
VILLAGE_COUNT = 9
VILLAGE_LAND = 1         # hexes around a village that belong to it
TENSION_WAR = 100        # a tribe goes to war with a side at this tension
TENSION_PEACE = 40       # ... and makes peace again below this
TENSION_DECAY = 2        # per turn
TENSION_COLONY = 30      # founding a colony within 4 hexes of one of its villages
TENSION_BUILD = 10       # building within 2 hexes of one of its villages
TENSION_BURN = 30        # burning a village angers the other tribes too
GIFT_COST = {"gold": 3}
GIFT_CALM = 35
TRADE_GIVE = {"wood": 2}
TRADE_GET = {"furs": 3}
TRADE_CALM = 5
VILLAGE_REACH = 4        # gift or trade with a village that has your unit next to it or your colony this close
BRAVE_EVERY = 3          # a village at war sends out a brave this often
BRAVES_PER_VILLAGE = 2
RAID_FOOD = 3            # food stolen by a raid
BURN_LOOT = {"gold": 6}

# ----- independence --------------------------------------------------------------
INDEPENDENCE_POP = 12    # total population needed to declare
INDEPENDENCE_SOLDIERS = 3
ROYAL_WAVES = 4          # the Crown lands this many waves...
ROYAL_WAVE_SIZE = 2      # ... of this many regulars...
ROYAL_WAVE_EVERY = 2     # ... this many turns apart
INDEPENDENCE_TURNS = 12  # hold out this long after declaring (or destroy the whole army) to win
