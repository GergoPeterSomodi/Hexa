"""Game data: sides, terrain, resources, buildings and unit types. Tweak numbers here to rebalance."""
from dataclasses import dataclass, field

PLAYER = "player"
AI = "ai"
DRAW = "draw"
SIDE_NAMES = {PLAYER: "You", AI: "Enemy"}


def other(side):
    return AI if side == PLAYER else PLAYER


# ----- terrain -------------------------------------------------------------------
@dataclass(frozen=True)
class Terrain:
    key: str
    name: str
    sprites: tuple          # paths under hexagon-pack/PNG/Tiles/; one is picked per hex
    move_cost: int | None   # None = impassable
    defense: int            # damage reduction for a unit standing here

    @property
    def passable(self):
        return self.move_cost is not None


TERRAIN = {t.key: t for t in (
    Terrain("grass", "Grassland", ("Terrain/Grass/grass_05.png", "Terrain/Grass/grass_19.png"), 1, 0),
    Terrain("dirt", "Dirt", ("Terrain/Dirt/dirt_06.png", "Terrain/Dirt/dirt_19.png"), 1, 0),
    Terrain("forest", "Forest", ("Terrain/Grass/grass_12.png", "Terrain/Grass/grass_13.png"), 2, 1),
    Terrain("hills", "Hills", ("Terrain/Grass/grass_15.png",), 2, 2),
    Terrain("mountain", "Mountain", ("Terrain/Grass/grass_14.png",), None, 0),
    Terrain("water", "Lake", ("Terrain/Grass/lake.png",), None, 0),
)}

# ----- resources and buildings ---------------------------------------------------
RESOURCES = ("food", "wood", "stone")
START_STOCK = {"food": 4, "wood": 4, "stone": 2}


@dataclass(frozen=True)
class Improvement:
    key: str
    name: str
    sprite: str
    terrains: tuple          # terrain keys it can be built on
    yields: dict = field(default_factory=dict)
    cost: dict = field(default_factory=dict)


IMPROVEMENTS = {i.key: i for i in (
    Improvement("farm", "Farm", "Medieval/medieval_farm.png", ("grass", "dirt"), {"food": 2}, {"wood": 2}),
    Improvement("lumber", "Lumber camp", "Medieval/medieval_lumber.png", ("forest",), {"wood": 2}, {"food": 2}),
    Improvement("mine", "Mine", "Medieval/medieval_mine.png", ("hills",), {"stone": 2}, {"wood": 3}),
)}
IMPROVEMENT_FOR_TERRAIN = {t: i for i in IMPROVEMENTS.values() for t in i.terrains}

CASTLE_SPRITE = "Medieval/medieval_largeCastle.png"
TOWN_SPRITE = "Medieval/medieval_house.png"
CASTLE_INCOME = {"food": 2, "wood": 1, "stone": 1}
TOWN_INCOME = {"food": 1, "wood": 1}
TERRITORY_RADIUS = 2     # hexes this close to a town belong to it
MIN_TOWN_SPACING = 3     # new towns must be at least this far from any other town

TOWN_DEFENSE = 1         # extra damage reduction for a unit in its own town or castle
TOWN_SIGHT = 2
TOWN_HEAL = 2            # HP regained per turn by a resting unit in its own town
REST_HEAL = 1            # HP regained per turn by a unit that neither moved nor fought
TURN_LIMIT = 40          # after this many turns the higher score wins
TOWN_SCORE = 10          # score per town, on top of the total HP of your units


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
    cost: dict
    can_capture: bool = False   # may take enemy towns and castles
    upkeep: int = 0             # food eaten per turn
    hotkey: str = ""


SCOUT = UnitType("scout", "Scout", max_hp=6, attack=2, defense=0, moves=4, sight=3,
                 cost={"food": 2, "wood": 1}, hotkey="1")
SOLDIER = UnitType("soldier", "Soldier", max_hp=10, attack=5, defense=1, moves=2, sight=2,
                   cost={"food": 2, "wood": 2, "stone": 1}, can_capture=True, upkeep=1, hotkey="2")
WORKER = UnitType("worker", "Worker", max_hp=4, attack=0, defense=0, moves=2, sight=1,
                  cost={"food": 3, "wood": 1}, hotkey="3")
SETTLER = UnitType("settler", "Settler", max_hp=4, attack=0, defense=0, moves=2, sight=1,
                   cost={"food": 5, "wood": 3}, hotkey="4")
UNIT_TYPES = {u.key: u for u in (SCOUT, SOLDIER, WORKER, SETTLER)}


def cost_text(cost):
    short = {"food": "F", "wood": "W", "stone": "S"}
    return " ".join(f"{n}{short[r]}" for r, n in cost.items())
