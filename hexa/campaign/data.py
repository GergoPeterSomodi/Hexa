"""Age of Discovery game data: goods, terrain, buildings, units and balance numbers.

One turn is one season. Population is counted in thousands, money in ducats.
"""
from dataclasses import dataclass, field, fields

from .geo import SCALE          # the map is SCALE times finer than the original: distances grow, provinces shrink

AREA = SCALE * SCALE            # provinces per original province

START_YEAR = 1480
END_YEAR = 1650
SEASONS = ("Spring", "Summer", "Autumn", "Winter")


def date(turn):
    return f"{SEASONS[(turn - 1) % 4]} {START_YEAR + (turn - 1) // 4}"


# ----- goods -------------------------------------------------------------------------
@dataclass(frozen=True)
class Good:
    key: str
    name: str
    price: float          # base price in ducats
    color: tuple
    kind: str             # food, raw, made, luxury, money


GOODS = {g.key: g for g in (
    Good("grain", "Grain", 1.0, (225, 200, 90), "food"),
    Good("fish", "Fish", 1.0, (110, 170, 210), "food"),
    Good("salt", "Salt", 2.0, (235, 235, 235), "raw"),
    Good("wine", "Wine", 2.5, (150, 40, 90), "raw"),
    Good("wool", "Wool", 1.5, (230, 220, 200), "raw"),
    Good("cotton", "Cotton", 2.0, (250, 250, 240), "raw"),
    Good("timber", "Timber", 1.0, (120, 85, 50), "raw"),
    Good("iron", "Iron", 2.0, (120, 125, 135), "raw"),
    Good("cloth", "Cloth", 4.0, (180, 110, 200), "made"),
    Good("tools", "Tools", 5.0, (80, 90, 110), "made"),
    Good("weapons", "Weapons", 6.0, (170, 60, 60), "made"),
    Good("sugar", "Sugar", 4.0, (245, 240, 250), "luxury"),
    Good("tobacco", "Tobacco", 4.0, (140, 100, 50), "luxury"),
    Good("furs", "Furs", 4.0, (150, 110, 80), "luxury"),
    Good("ivory", "Ivory", 5.0, (240, 230, 200), "luxury"),
    Good("spices", "Spices", 9.0, (220, 120, 40), "luxury"),
    Good("silver", "Silver", 7.0, (200, 205, 215), "money"),
    Good("gold", "Gold", 10.0, (250, 210, 60), "money"),
    Good("horses", "Horses", 3.0, (150, 100, 60), "raw"),
    Good("cattle", "Cattle", 1.5, (120, 80, 60), "raw"),
    Good("stone", "Stone", 1.0, (185, 185, 180), "raw"),
    Good("copper", "Copper", 2.5, (205, 125, 70), "raw"),
    Good("hemp", "Hemp & flax", 1.2, (125, 165, 85), "raw"),
    Good("olives", "Olive oil", 2.5, (165, 170, 90), "luxury"),
    Good("silk", "Silk", 6.0, (240, 200, 225), "luxury"),
    Good("dyes", "Dyes", 5.0, (95, 75, 205), "luxury"),
    Good("cocoa", "Cocoa", 5.0, (115, 70, 40), "luxury"),
    Good("coffee", "Coffee", 5.0, (90, 55, 35), "luxury"),
    Good("rope", "Rope & sails", 3.5, (215, 195, 145), "made"),
    Good("glass", "Glass", 5.0, (165, 220, 235), "made"),
    Good("leather", "Leather", 3.5, (155, 105, 60), "made"),
    Good("gunpowder", "Gunpowder", 5.0, (75, 75, 80), "made"),
)}
FOODS = ("grain", "fish")

# What 1,000 people of each class want per season.
NEEDS = {
    "peasants": {"food": 0.25, "salt": 0.02, "cloth": 0.02, "wine": 0.01, "olives": 0.005},
    "burghers": {"food": 0.25, "salt": 0.03, "cloth": 0.08, "wine": 0.05, "tools": 0.03, "sugar": 0.03,
                 "tobacco": 0.02, "spices": 0.01, "olives": 0.02, "glass": 0.02, "leather": 0.02, "coffee": 0.01,
                 "dyes": 0.005},
    "nobles": {"food": 0.25, "cloth": 0.15, "wine": 0.12, "sugar": 0.08, "spices": 0.06, "furs": 0.06,
               "tobacco": 0.04, "ivory": 0.03, "weapons": 0.03, "silk": 0.05, "cocoa": 0.03, "glass": 0.03,
               "dyes": 0.02, "horses": 0.02, "coffee": 0.02, "olives": 0.02},
}
# Raw output per 1,000 peasants per season.
OUTPUT = {"grain": 0.42, "fish": 0.4, "salt": 0.2, "wine": 0.2, "wool": 0.25, "cotton": 0.25, "timber": 0.3,
          "iron": 0.2, "sugar": 0.22, "tobacco": 0.22, "furs": 0.12, "ivory": 0.08, "spices": 0.06,
          "silver": 0.06, "gold": 0.04, "horses": 0.12, "cattle": 0.25, "stone": 0.3, "copper": 0.15, "hemp": 0.25,
          "olives": 0.2, "silk": 0.06, "dyes": 0.08, "cocoa": 0.1, "coffee": 0.1}
PRICE_FLOOR, PRICE_CAP = 0.3, 3.5      # prices stay between these multiples of the base price
ELASTICITY = 0.6

# ----- terrain -----------------------------------------------------------------------
@dataclass(frozen=True)
class Terrain:
    key: str
    name: str
    color: tuple
    move: int | None      # land movement cost; None = not walkable
    defense: float        # bonus for defending armies
    density: float        # people per hex (thousands) in 1480 Europe


def _terrain(key, name, color, move, defense, density):
    return Terrain(key, name, color, move, defense, density / AREA)


TERRAIN = {t.key: t for t in (
    _terrain("plains", "Farmland", (150, 180, 95), 1, 0.0, 55),
    _terrain("steppe", "Steppe", (190, 190, 120), 1, 0.0, 18),
    _terrain("forest", "Forest", (70, 125, 70), 2, 0.25, 22),
    _terrain("hills", "Hills", (160, 150, 105), 2, 0.25, 35),
    _terrain("mountains", "Mountains", (130, 120, 115), 3, 0.5, 12),
    _terrain("desert", "Desert", (225, 205, 150), 2, 0.0, 2),
    _terrain("jungle", "Jungle", (40, 110, 60), 3, 0.25, 15),
    _terrain("tundra", "Tundra", (175, 185, 180), 2, 0.0, 2),
    _terrain("marsh", "Marsh", (95, 140, 110), 3, 0.15, 14),
    _terrain("taiga", "Taiga", (90, 120, 100), 2, 0.25, 6),
    _terrain("savanna", "Savanna", (200, 180, 95), 1, 0.0, 14),
    _terrain("beach", "Coast", (230, 215, 160), 1, 0.0, 30),
    _terrain("snow", "Snowfield", (232, 238, 244), 3, 0.25, 1),
    _terrain("lake", "Lake", (90, 150, 200), None, 0.0, 0),
    _terrain("ocean", "Sea", (40, 85, 150), None, 0.0, 0),
)}
ROUGH = ("forest", "hills", "mountains", "jungle", "marsh", "taiga", "snow")
# Kenney tiles used when zoomed in (paths under hexagon-pack/PNG/Tiles/).
TERRAIN_SPRITES = {
    "plains": ("Terrain/Grass/grass_05.png", "Terrain/Grass/grass_19.png"),
    "steppe": ("Terrain/Dirt/dirt_06.png", "Terrain/Dirt/dirt_19.png"),
    "forest": ("Terrain/Grass/grass_12.png", "Terrain/Grass/grass_13.png"),
    "hills": ("Terrain/Grass/grass_15.png",),
    "mountains": ("Terrain/Grass/grass_14.png",),
    "desert": ("Terrain/Sand/sand_07.png", "Terrain/Sand/sand_19.png"),
    "jungle": ("Terrain/Grass/grass_13.png", "Terrain/Grass/grass_12.png"),
    "tundra": ("Terrain/Stone/stone_05.png", "Terrain/Stone/stone_12.png"),
    "marsh": ("art:marsh:0", "art:marsh:1"),
    "taiga": ("art:taiga:0", "art:taiga:1"),
    "snow": ("art:snow:0", "art:snow:1"),
    "savanna": ("art:savanna:0", "art:savanna:1"),
    "beach": ("art:beach:0", "art:beach:1"),
    "lake": ("Terrain/Grass/lake.png",),
}
# Farmland growing these goods gets its own look (until works are built on it).
GOOD_SPRITES = {"wine": ("art:vineyard:0", "art:vineyard:1"), "wool": ("art:pasture:0", "art:pasture:1"),
                "sugar": ("art:plantation:0", "art:plantation:1"), "tobacco": ("art:plantation:0", "art:plantation:1"),
                "cotton": ("art:plantation:0", "art:plantation:1")}
NATIVE_VILLAGE_SPRITE = "Western/western_indians.png"

# ----- buildings --------------------------------------------------------------------
@dataclass(frozen=True)
class Building:
    key: str
    name: str
    cost: int              # ducats per level
    max_level: int
    upkeep: float          # per level per season
    hint: str
    needs_coast: bool = False
    needs_burghers: float = 0   # thousand burghers per level
    inputs: dict = field(default_factory=dict)    # per level per season
    outputs: dict = field(default_factory=dict)


BUILDINGS = {b.key: b for b in (
    Building("weaver", "Weaver", 280, 3, 0.3, "Turns wool or cotton into cloth", needs_burghers=2,
             inputs={"wool": 3.0}, outputs={"cloth": 2.0}),
    Building("toolmaker", "Toolmaker", 320, 3, 0.3, "Turns iron into tools", needs_burghers=2,
             inputs={"iron": 2.5}, outputs={"tools": 1.6}),
    Building("armoury", "Armoury", 360, 3, 0.3, "Turns iron and tools into weapons", needs_burghers=2,
             inputs={"iron": 1.5, "tools": 0.5}, outputs={"weapons": 1.5}),
    Building("marketplace", "Marketplace", 200, 3, 0.2, "+trade capacity, +burgher taxes and growth"),
    Building("port", "Port", 150, 1, 0.3, "Builds ships; +sea trade capacity", needs_coast=True),
    Building("shipyard", "Shipyard", 250, 1, 0.3, "Needed for carracks; ships cost less timber", needs_coast=True),
    Building("barracks", "Barracks", 220, 1, 0.4, "Drill infantry and cavalry here for +attack or +defense"),
    Building("foundry", "Foundry", 260, 1, 0.4, "Cast cannons here; improve cannons for +attack or +defense"),
    Building("ropewalk", "Ropewalk", 260, 3, 0.3, "Twists hemp into rope and sails for ships", needs_burghers=2,
             inputs={"hemp": 2.5}, outputs={"rope": 2.0}),
    Building("glassworks", "Glassworks", 300, 3, 0.3, "Melts stone (sand) with timber into glass", needs_burghers=2,
             inputs={"stone": 1.5, "timber": 1.0}, outputs={"glass": 1.2}),
    Building("tannery", "Tannery", 240, 3, 0.3, "Tans cattle hides into leather", needs_burghers=2,
             inputs={"cattle": 2.5}, outputs={"leather": 2.0}),
    Building("powder_mill", "Powder mill", 320, 3, 0.3, "Grinds saltpetre and charcoal into gunpowder",
             needs_burghers=2, inputs={"salt": 1.5, "timber": 1.0}, outputs={"gunpowder": 1.2}),
    Building("university", "University", 300, 1, 0.5, "Scholars: +1 research a season", needs_burghers=3),
)}
MANUFACTORIES = ("weaver", "toolmaker", "armoury", "ropewalk", "glassworks", "tannery", "powder_mill")
PLANTATION_GOODS = ("sugar", "tobacco", "cotton", "spices")   # investment levels 3+ need the Plantations tech
MINE_GOODS = ("iron", "silver", "gold", "salt", "copper")     # the Mines tech raises their output
BUILD_TURNS = 4

# ----- province investment: five levels per goods tile ------------------------------------------
# Bought in the province panel (no builder units): ducats plus goods bought on the local market.
# Higher levels unlock with the eras. Each level adds output and changes how the tile looks.
WORKS_LEVELS = 5
WORKS_BONUS = 0.3                  # extra output per level
WORKS_COST = tuple(round(c / AREA) for c in (100, 180, 300, 450, 650))   # ducats for levels 1..5
WORKS_GOODS = ({"timber": 1.0}, {"timber": 1.5, "tools": 0.5}, {"tools": 1.0, "stone": 1.0},
               {"tools": 1.5, "iron": 1.0, "stone": 1.5}, {"tools": 2.0, "iron": 1.5, "stone": 2.0})
WORKS_GOODS = tuple({g: n / SCALE for g, n in level.items()} for level in WORKS_GOODS)
WORKS_ERA = (1, 1, 2, 2, 3)        # era needed for levels 1..5
WORKS_UPKEEP = 0.2 / AREA          # per level per season
# The name of every level, per good (the tile art in goodsart.py draws the same places).
WORKS = {
    "grain": ('Wheat strips', 'Open fields', 'Grange barn', 'Windmill farm', 'Manor estate'),
    "wine": ('Hillside vines', 'Terraced vineyard', 'Press house', 'Wine cellars', 'Chateau'),
    "wool": ('Upland grazing', 'Walled pastures', "Shepherd's hut", 'Sheepfolds', 'Wool barn'),
    "cotton": ('Cotton patch', 'Cotton fields', 'Drying sheds', 'Cotton farm', 'Gin house'),
    "sugar": ('Cane patch', 'Cane fields', 'Boiling house', 'Sugar works', 'Sugar mill'),
    "tobacco": ('Tobacco patch', 'Tobacco fields', 'Curing barn', 'Tobacco farm', 'Tobacco warehouse'),
    "timber": ("Woodcutters' clearing", 'Logging camp', 'Sawpit', 'Sawmill', 'Timber yard'),
    "iron": ('Iron diggings', 'Iron mine', 'Ore tramway', 'Bloomery', 'Ironworks'),
    "silver": ('Silver vein', 'Silver mine', 'Deep workings', 'Stamp mill', 'Royal mint'),
    "gold": ('Gold panning', 'Placer claim', 'Sluice works', 'Gold diggings', 'Fortified gold mine'),
    "salt": ('Salt pans', 'Salt marsh works', 'Salt mounds', 'Saltern', 'Salt house'),
    "fish": ('Fishing beach', 'Fishing jetty', 'Fishing village', 'Fishing pier', 'Fishing harbour'),
    "furs": ('Trapline', "Trapper's lodge", 'Trapping camp', 'Fur post', 'Fur trading fort'),
    "ivory": ('Elephant grounds', 'Hunting camp', 'Trading hut', 'Ivory market', 'Ivory fort'),
    "spices": ('Spice garden', 'Spice grove', 'Drying yard', 'Spice plantation', 'Spice warehouse'),
    "horses": ('Horse corral', 'Round paddock', 'Stables', 'Stud farm', 'Royal stud'),
    "cattle": ('Grazing meadow', 'Cattle pasture', 'Cattle barn', 'Cattle ranch', 'Cattle estate'),
    "stone": ('Stone cutting', 'Quarry', 'Crane quarry', 'Deep quarry', 'Marble works'),
    "copper": ('Copper outcrop', 'Copper diggings', 'Copper mine', 'Roasting yard', 'Copper smelter'),
    "hemp": ('Hemp & flax plot', 'Hemp fields', 'Retting ponds', 'Rope yard', 'Ropewalk'),
    "olives": ('Olive trees', 'Olive terraces', 'Olive farm', 'Oil jars', 'Olive press'),
    "silk": ('Mulberry hedges', 'Mulberry orchard', 'Silkworm sheds', 'Silk farm', 'Silk caravanserai'),
    "dyes": ('Dye vats', 'Dye yard', 'Dye works', 'Cloth dyers', 'Dye house'),
    "cocoa": ('Cocoa grove', 'Cocoa clearing', 'Drying mats', 'Cocoa plantation', 'Cocoa hacienda'),
    "coffee": ('Coffee shrubs', 'Coffee terraces', 'Drying patios', 'Coffee estate', 'Coffee tower house'),
}

# Settlements: village -> town -> city. More slots for buildings, more taxes, more burghers.
SETTLEMENTS = ("", "Village", "Town", "City")
SETTLEMENT_SPRITES = ("", "Medieval/medieval_house.png", "Medieval/medieval_church.png", "Medieval/medieval_openCastle.png")
SETTLEMENT_COST = (0, 120, 400, 900)
SETTLEMENT_GOODS = ({}, {"timber": 2.0}, {"stone": 3.0, "timber": 2.0}, {"stone": 6.0, "glass": 1.0})
SETTLEMENT_POP = (0, 6, 20, 45)         # thousand people needed to grow to this level
SETTLEMENT_SLOTS = (0, 1, 3, 5)         # buildings (weaver, port, marketplace...) allowed
SETTLEMENT_TAX = (0.0, 0.05, 0.15, 0.3)
SETTLEMENT_UPKEEP = (0.0, 0.2, 0.5, 1.0)

# Castles: tower -> small castle -> large castle. Defensive objects.
CASTLES = ("", "Tower", "Small castle", "Large castle")
CASTLE_SPRITES = ("", "Medieval/medieval_tower.png", "Medieval/medieval_smallCastle.png",
                  "Medieval/medieval_largeCastle.png")
CASTLE_COST = (0, 150, 400, 800)
CASTLE_GOODS = ({}, {"timber": 2.0, "stone": 1.0}, {"stone": 5.0}, {"stone": 10.0, "gunpowder": 2.0})
CASTLE_UPKEEP = (0.0, 0.4, 1.0, 2.0)
CASTLE_DEFENSE = 0.25                   # extra defense per level for the owner's armies
CASTLE_SIEGE = 3                        # extra siege points needed per level (cannons add points)

# ----- units ------------------------------------------------------------------------
@dataclass(frozen=True)
class UnitKind:
    key: str
    name: str
    moves: int
    sight: int
    naval: bool = False
    capacity: int = 0
    gold: int = 0                                  # ducats
    goods: dict = field(default_factory=dict)      # bought on the province's market
    upkeep: float = 0.0
    branch: str = ""            # infantry, cavalry, artillery for war units
    era: int = 0
    hp: int = 6
    attack: int = 0
    defense: int = 0
    range: int = 1              # artillery can fire 2 hexes away
    siege: int = 0              # extra siege progress per season
    needs: str = ""             # building the province needs to raise it

    @property
    def war(self):
        return bool(self.branch)

    def __reduce__(self):
        # The game compares kinds by identity (unit.kind is GENERAL), so copies must stay the same object.
        if UNIT_KINDS.get(self.key) is self:
            return (unit_kind, (self.key,))
        return (UnitKind, tuple(getattr(self, f.name) for f in fields(self)))


def unit_kind(key):
    return UNIT_KINDS[key]


def _troop(key, name, branch, era, hp, attack, defense, moves, gold, goods, upkeep, **kw):
    return UnitKind(key, name, moves * SCALE, (2 if branch == "cavalry" else 1) * SCALE, gold=gold, goods=goods,
                    upkeep=upkeep,
                    branch=branch, era=era, hp=hp, attack=attack, defense=defense, **kw)


TROOPS = (
    _troop("pikemen", "Pikemen", "infantry", 1, 10, 4, 5, 3, 25, {"weapons": 1.0, "grain": 1.0}, 0.5),
    _troop("arquebusiers", "Arquebusiers", "infantry", 2, 10, 5, 6, 3, 30,
           {"weapons": 1.5, "grain": 1.0, "gunpowder": 0.5}, 0.6),
    _troop("musketeers", "Musketeers", "infantry", 3, 11, 7, 7, 3, 36,
           {"weapons": 2.0, "grain": 1.0, "gunpowder": 0.8}, 0.7),
    _troop("knights", "Knights", "cavalry", 1, 10, 6, 3, 5, 45,
           {"weapons": 1.0, "grain": 2.0, "horses": 1.0, "leather": 0.5}, 0.9),
    _troop("lancers", "Lancers", "cavalry", 2, 10, 7, 3, 5, 50,
           {"weapons": 1.5, "grain": 2.0, "horses": 1.0, "leather": 0.5}, 0.9),
    _troop("cuirassiers", "Cuirassiers", "cavalry", 3, 11, 8, 4, 5, 58,
           {"weapons": 2.0, "grain": 2.0, "horses": 1.0, "leather": 1.0}, 1.0),
    _troop("bombards", "Bombards", "artillery", 1, 8, 6, 1, 2, 60,
           {"iron": 2.0, "tools": 1.0, "copper": 1.5, "gunpowder": 1.0}, 1.0, range=2, siege=1, needs="town"),
    _troop("culverins", "Culverins", "artillery", 2, 8, 7, 1, 2, 66,
           {"iron": 2.0, "tools": 1.5, "copper": 2.0, "gunpowder": 1.0}, 1.0, range=2, siege=2, needs="town"),
    _troop("field_guns", "Field guns", "artillery", 3, 9, 9, 2, 3, 72,
           {"iron": 2.0, "tools": 2.0, "copper": 2.5, "gunpowder": 1.5}, 1.1, range=2, siege=2, needs="town"),
)
BRANCHES = ("infantry", "cavalry", "artillery")
BRANCH_NAMES = {"infantry": "Infantry", "cavalry": "Cavalry", "artillery": "Cannons"}


def troop(branch, era):
    return next(t for t in TROOPS if t.branch == branch and t.era == era)


SCOUT = UnitKind("scout", "Scouts", 5 * SCALE, 3 * SCALE, gold=15, goods={"grain": 0.5}, upkeep=0.2, hp=6)
GENERAL = UnitKind("general", "General", 4 * SCALE, 2 * SCALE, gold=120, upkeep=1.0, hp=1)
WAGON = UnitKind("wagon", "Supply wagon", 3 * SCALE, SCALE, gold=20, goods={"grain": 3.0, "horses": 0.5},
                 upkeep=0.2, hp=4)
# Pioneers are retired (provinces invest from the panel now); the kind stays so old saves load.
PIONEER = UnitKind("pioneer", "Pioneers", 3 * SCALE, SCALE, gold=30, goods={"tools": 1.5}, upkeep=0.2)
COLONIST = UnitKind("colonist", "Colonists", 3 * SCALE, SCALE, gold=40, goods={"tools": 1.0, "grain": 3.0})
CARAVEL = UnitKind("caravel", "Caravel", 10 * SCALE, 3 * SCALE, naval=True, capacity=4, gold=40,
                   goods={"timber": 8.0, "rope": 2.0}, upkeep=0.4)
CARRACK = UnitKind("carrack", "Carrack", 8 * SCALE, 2 * SCALE, naval=True, capacity=8, gold=70,
                   goods={"timber": 14.0, "rope": 4.0, "iron": 2.0}, upkeep=0.8)
GALLEON = UnitKind("galleon", "Galleon", 9 * SCALE, 3 * SCALE, naval=True, capacity=10, gold=90,
                   goods={"timber": 14.0, "rope": 6.0, "iron": 4.0}, upkeep=1.0)
UNIT_KINDS = {k.key: k for k in (SCOUT, GENERAL, WAGON, PIONEER, COLONIST, CARAVEL, CARRACK, GALLEON) + TROOPS}
COLONIST_PEOPLE = 1.0       # thousand peasants who leave home with each colonist unit

# ----- war -----------------------------------------------------------------------------
ERAS = {1: ("Age of Pikes", 1480, 0), 2: ("Age of Arquebus", 1520, 160), 3: ("Age of Musket", 1575, 420)}
STACK_BASE = 6                            # war units per hex before techs and ideas (world.stack_limit)
STACK_LIMIT = {1: 6, 2: 7, 3: 8}          # war units per hex, the old era rule (kept for old tests)
GENERAL_STACK = 2                          # a general lets the stack hold this many more
CIVILIAN_LIMIT = 3                         # pioneers, colonists and scouts that may share a hex
FRONT = 3                                  # units fighting in the front line
SUPPORT_BONUS, SUPPORT_MAX = 0.05, 0.25    # each unit behind the front line adds this much
COUNTER = 0.6                              # defenders strike back this hard
OPEN_GROUND = ("plains", "steppe", "desert", "tundra", "savanna", "beach")
# How hard each branch hits in each kind of fight (attack) and how well it holds (defense).
FIGHT_ATTACK = {"infantry": {"open": 1.0, "rough": 1.0, "assault": 1.0},
                "cavalry": {"open": 1.4, "rough": 0.7, "assault": 0.5},
                "artillery": {"open": 1.0, "rough": 0.6, "assault": 2.0}}
FIGHT_DEFENSE = {"infantry": {"open": 1.0, "rough": 1.1, "garrison": 1.3},
                 "cavalry": {"open": 1.0, "rough": 0.8, "garrison": 0.8},
                 "artillery": {"open": 0.5, "rough": 0.5, "garrison": 0.8}}
PIKES_VS_HORSE = 1.25                      # infantry defending against cavalry
VETERAN_RANKS = ((0, "", 1.0), (3, "Veteran", 1.1), (7, "Elite", 1.2))   # (xp needed, name, bonus)
UPGRADE_MAX = 2                            # +attack and +defense levels bought at barracks / foundry
UPGRADE_COST = {"attack": (30, {"weapons": 1.0}), "defense": (30, {"iron": 2.0})}
GENERAL_TRAITS = {"open": "Field marshal (+20% in open battle)", "rough": "Ranger (+20% in forests and hills)",
                  "assault": "Siege master (+20% storming castles, faster sieges)",
                  "defense": "Defender (+20% when defending)", "cavalry": "Cavalier (+20% for cavalry)"}
GENERAL_BONUS = 0.2
GARRISON_HP = 6                            # per castle level
GARRISON_ATTACK, GARRISON_DEFENSE = 3, 3   # +2 defense per castle level
GARRISON_REGEN = 2
RESEARCH_BASE = 0.6                        # research points per season, plus burghers / 40
RESEARCH_FUND = (60, 15)                   # ducats -> research points

# ----- feeding armies ---------------------------------------------------------------------
MANPOWER = 1.0             # thousand peasants each new troop takes from its province
FOOD_PER_TROOP = 0.5       # grain each troop eats per season, bought on the local market
SUPPLY_BASE = 2            # troops any province can feed...
SUPPLY_PER_PEOPLE = 4      # ... plus one per this many thousand people...
SUPPLY_PER_FARM = 1        # ... plus this per level of farm works
FOREIGN_SUPPLY = 0.5       # in land that is not yours
ATTRITION = 1              # HP each troop loses per season over the supply limit or cut off
SUPPLY_RANGE = 3 * SCALE   # hexes from a depot (town, castle or port) through your land
WAGON_SEASONS = 4          # seasons a full wagon keeps its stack fed
FORAGE_LOSS = 0.04         # share of a province's people lost to foraging
FARM_GOODS = ("grain", "wine", "wool", "cotton", "sugar", "tobacco")

# ----- taxes, growth, trade ---------------------------------------------------------
TAX_LEVELS = {"low": 0.7, "normal": 1.0, "high": 1.4}
TAX_GROWTH = {"low": 0.0015, "normal": 0.0, "high": -0.002}
PRODUCTION_TAX = 0.12            # share of the value of a province's goods the crown takes
PEASANT_TAX, BURGHER_TAX = 0.02, 0.15   # ducats per thousand per season
BASE_GROWTH = 0.0025             # per season
COLONY_GROWTH = 0.035
COLONY_DONE = 5.0 / SCALE                # a colony with this many thousand people becomes a full province
COLONY_UPKEEP = 0.5
TRADING_POST_SHARE = 0.4         # natives working for a trading post produce at this rate
NATIVE_RAID_CHANCE = 0.04
ROUTE_BASE = 6.0                 # units of goods a trade route moves per season without merchants
MERCHANT_CAPACITY = 12.0
MARKETPLACE_CAPACITY = 4.0
PORT_CAPACITY = 3.0
MARKET_REACH = 14 * SCALE                # provinces further than this from any market sell at home, at a loss
REMOTE_PENALTY = 0.7
SEA_STEP = 0.5
SUBSISTENCE = 0.15               # food every 1,000 peasants grow for themselves each season
MANUFACTORY_TAX = 0.35           # share of manufactory profits that reaches the treasury
TOLL_SHARE = 0.1                 # share of a route's profit each market owner takes as tolls
# Debt: a country that owes more than its debt limit (DEBT_FLOOR, or DEBT_SEASONS seasons of its running
# costs, whichever is more) loses unpaid troops to desertion, then buildings to its creditors.
DEBT_FLOOR = 300                # ducats of debt tolerated before anything is lost
DEBT_SEASONS = 6                # seasons of running costs (upkeep, army, colonies) tolerated as debt
DEBT_INTEREST = 0.02            # interest a season on debt, on at most the debt limit
MERCHANT_SHARE = 0.8             # (unused) kept for old saves
SIEGE_BASE = 1
WAR_LENGTH_AI = 16               # AI wars end after about this many turns
SEA_ROUTE_RANGE = 18 * SCALE
ATLANTIC_RANGE = 90 * SCALE
TERRITORY_RADIUS = 4 * SCALE             # starting countries own land this close to one of their seeds
