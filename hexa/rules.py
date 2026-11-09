"""Game data: sides, terrain types and unit types. Tweak numbers here to rebalance."""
from dataclasses import dataclass

PLAYER = "player"
AI = "ai"
DRAW = "draw"
SIDE_NAMES = {PLAYER: "You", AI: "Enemy"}


def other(side):
    return AI if side == PLAYER else PLAYER


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

CASTLE_SPRITE = "Medieval/medieval_largeCastle.png"
CASTLE_DEFENSE = 1      # extra damage reduction for a unit in its own castle
CASTLE_SIGHT = 2
CASTLE_HEAL = 2         # HP regained per turn by a resting unit in its own castle
REST_HEAL = 1           # HP regained per turn by a unit that neither moved nor fought
TURN_LIMIT = 40         # after this many turns the stronger army wins
SPAWN_EVERY = 3         # each castle trains a new soldier every N turns


@dataclass(frozen=True)
class UnitType:
    key: str
    name: str
    max_hp: int
    attack: int
    defense: int
    moves: int
    sight: int
    can_capture: bool   # may take enemy castles


SCOUT = UnitType("scout", "Scout", max_hp=6, attack=2, defense=0, moves=4, sight=3, can_capture=False)
SOLDIER = UnitType("soldier", "Soldier", max_hp=10, attack=5, defense=1, moves=2, sight=2, can_capture=True)
UNIT_TYPES = {u.key: u for u in (SCOUT, SOLDIER)}
