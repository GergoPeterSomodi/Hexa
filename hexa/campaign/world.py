"""Age of Discovery game state: the map, countries, pops, markets, trade, colonies and wars.

Every land hex is a province. Nothing in here uses pygame.
"""
import heapq
import itertools
import pickle
import random
from collections import deque
from dataclasses import MISSING, dataclass, field, fields, is_dataclass

from ..hexgrid import distance, neighbors, to_cube, within
from . import geo, tech, wfc
from .data import (AREA, BRANCHES, CIVILIAN_LIMIT, COUNTER, ERAS, FIGHT_ATTACK, FIGHT_DEFENSE, FRONT, GARRISON_ATTACK,
                   GARRISON_DEFENSE, GARRISON_HP, GARRISON_REGEN, GENERAL, GENERAL_BONUS, GENERAL_STACK,
                   GENERAL_TRAITS, OPEN_GROUND, PIKES_VS_HORSE, RESEARCH_BASE, RESEARCH_FUND, SCOUT, STACK_BASE,
                   SUPPORT_BONUS, SUPPORT_MAX, UPGRADE_COST, UPGRADE_MAX, VETERAN_RANKS, UnitKind, troop,
                   BUILD_TURNS, ATTRITION, FARM_GOODS, FOOD_PER_TROOP, FOREIGN_SUPPLY, FORAGE_LOSS, MANPOWER,
                   SUPPLY_BASE, SUPPLY_PER_FARM, SUPPLY_PER_PEOPLE, SUPPLY_RANGE, WAGON, WAGON_SEASONS, BUILDINGS, BURGHER_TAX, CARAVEL, CARRACK, COLONIST, COLONIST_PEOPLE,
                   COLONY_DONE, COLONY_GROWTH, COLONY_UPKEEP, ELASTICITY, END_YEAR, PIONEER, WORKS, WORKS_BONUS,
                   WORKS_COST, WORKS_UPKEEP, SETTLEMENTS, SETTLEMENT_COST, SETTLEMENT_POP, SETTLEMENT_SLOTS,
                   SETTLEMENT_TAX, SETTLEMENT_UPKEEP, CASTLES, CASTLE_COST, CASTLE_UPKEEP, CASTLE_DEFENSE,
                   CASTLE_SIEGE,
                   FOODS, GOODS, MARKET_REACH, MARKETPLACE_CAPACITY, MERCHANT_CAPACITY, NATIVE_RAID_CHANCE, NEEDS,
                   OUTPUT, PEASANT_TAX, PORT_CAPACITY, PRICE_CAP, PRICE_FLOOR, PRODUCTION_TAX, REMOTE_PENALTY,
                   ROUTE_BASE, SEA_ROUTE_RANGE, SEA_STEP, SIEGE_BASE, START_YEAR, TAX_GROWTH, TAX_LEVELS, TERRAIN,
                   TERRITORY_RADIUS, TRADING_POST_SHARE, UNIT_KINDS, WAR_LENGTH_AI, ATLANTIC_RANGE, BASE_GROWTH,
                   date, SUBSISTENCE, MANUFACTORY_TAX, TOLL_SHARE, MERCHANT_SHARE)

INF = float("inf")
SCALE = geo.SCALE
_RANDOM_GEOS = {}         # seed -> random geography (only the last few kept)
_SNAPSHOTS = {}           # (map, seed) -> pickled freshly built world: building the map takes seconds
RANDOM_KEPT = 2           # random worlds kept in those caches (the Europe snapshot always stays)
# World attributes a save from an older version may lack, with their defaults (callables build fresh ones).
WORLD_DEFAULTS = {"log": list, "units": list, "wars": list, "routes": list, "visible": set, "over": False,
                  "version": 0, "player": None, "_owned": None, "_castle_list": None, "_sea_cache": dict,
                  "_markets_dirty": True, "_known_world": None, "_neighbour_cache": None, "_bonus_cache": dict}
# World attributes no save can do without (from_state refuses a state that lacks one). Every other attribute
# has a default above, is rebuilt on load (geo, _ids) or is added when first needed (_explored_from).
WORLD_REQUIRED = ("cols", "rows", "turn", "rng", "terrain", "provinces", "countries", "markets", "cities", "landmass",
                  "sea_body", "rivers", "river_at", "roads", "road_paths", "colonial")
LAND_TILES = ("plains", "steppe", "forest", "hills", "mountains", "desert", "jungle", "tundra", "marsh", "taiga",
              "savanna", "beach", "snow")
# Terrain that may not touch (wave function collapse rules): mountains rise through hills, deserts
# fade through steppe and savanna, snow sits next to tundra, taiga and mountains...
FORBIDDEN = [("mountains", t) for t in ("plains", "marsh", "beach", "steppe")] + \
    [("desert", t) for t in ("jungle", "marsh", "taiga", "snow", "forest", "tundra")] + \
    [("snow", t) for t in ("plains", "jungle", "savanna", "beach", "desert", "steppe", "marsh")] + \
    [("jungle", t) for t in ("taiga", "tundra", "steppe")] + \
    [("taiga", t) for t in ("savanna", "beach")] + [("tundra", t) for t in ("jungle", "savanna")] + \
    [("marsh", "savanna")]
CLASSES = ("peasants", "burghers", "nobles")
BIG_EMPIRE = 300                                        # provinces that start a country with drill yards
ROUTE_KEYS = ("market_reach", "sea_range", "atlantic")  # effects that change the trade routes
BUILDING_TECH = {"ropewalk": ("ropewalk", "ropewalk"), "powder_mill": ("powder_mill", "corned_powder"),
                 "glassworks": ("glass_leather", "glass_leather"), "tannery": ("glass_leather", "glass_leather"),
                 "university": ("university", "universities")}   # building -> (flag, tech key)
from .data import (CASTLE_GOODS, ERAS as _ERAS, GALLEON, MANUFACTORIES, MINE_GOODS, PLANTATION_GOODS,
                   SETTLEMENT_GOODS, WORKS_ERA, WORKS_GOODS, WORKS_LEVELS)


# ----- state objects --------------------------------------------------------------------
@dataclass(eq=False)
class Province:
    pos: tuple
    terrain: str
    good: str | None
    coastal: bool
    name: str
    city: bool = False
    owner: str | None = None
    controller: str | None = None
    peasants: float = 0.0
    burghers: float = 0.0
    nobles: float = 0.0
    natives: float = 0.0
    tribe: str = ""
    buildings: dict = field(default_factory=dict)
    queue: list = field(default_factory=list)       # [building key, turns left]
    market: object = None
    remote: bool = False
    colony: bool = False
    trading_post: bool = False
    siege: int = 0
    output: float = 0.0
    value: float = 0.0
    food: float = 1.0
    works: int = 0           # field / mine / lumber camp level on the tile
    settlement: int = 0      # 1 village, 2 town, 3 city
    castle: int = 0          # 1 tower, 2 small castle, 3 large castle
    busy: bool = False       # already did its one job this season
    garrison: int = 0        # hit points of the castle's own defenders
    foraged: tuple = ()      # (country, turn) when an army last foraged here

    @property
    def pop(self):
        return self.peasants + self.burghers + self.nobles

    def level(self, key):
        return self.buildings.get(key, 0)

    @property
    def workers(self):
        return self.peasants + (self.natives * TRADING_POST_SHARE if self.trading_post else 0)


@dataclass(eq=False)
class Market:
    name: str
    point: tuple
    colonial: bool
    center: tuple = None
    active: bool = False
    supply: dict = field(default_factory=dict)
    demand: dict = field(default_factory=dict)
    price: dict = field(default_factory=dict)
    imports: dict = field(default_factory=dict)
    exports: dict = field(default_factory=dict)
    produced: dict = field(default_factory=dict)
    pending: dict = field(default_factory=dict)     # state purchases waiting for the next season
    history: dict = field(default_factory=dict)
    provinces: list = field(default_factory=list)

    def reset(self):
        for d in (self.supply, self.demand, self.imports, self.exports, self.produced):
            for g in GOODS:
                d[g] = 0.0
        for g, n in self.pending.items():
            self.demand[g] += n
        self.pending = {}

    def satisfaction(self, good):
        d = self.demand.get(good, 0)
        return 1.0 if d <= 0 else min(1.0, self.supply.get(good, 0) / d)

    def food_satisfaction(self):
        d = self.demand["grain"] + self.demand["fish"]
        return 1.0 if d <= 0 else min(1.0, (self.supply["grain"] + self.supply["fish"]) / d)


@dataclass(eq=False)
class Route:
    id: int
    a: Market
    b: Market
    distance: float
    sea: bool
    orders: list = field(default_factory=list)      # merchants: (tag, good, source market name)
    results: list = field(default_factory=list)     # last season: (tag, good, amount, profit)
    flows: list = field(default_factory=list)       # (good, amount, from market, to market)
    profit: float = 0.0

    @property
    def cost(self):
        return 0.15 + 0.02 / SCALE * self.distance * (1 if self.sea else 2)

    def other(self, market):
        return self.b if market is self.a else self.a


@dataclass(eq=False)
class Country:
    tag: str
    name: str
    color: tuple
    capital: tuple
    treasury: float = 100.0
    tax: str = "normal"
    orders: list = field(default_factory=list)      # (route id, good, source market name), one per merchant
    income: dict = field(default_factory=dict)
    alive: bool = True
    era: int = 1
    research: float = 0.0
    explored: set = field(default_factory=set)
    memory: dict = field(default_factory=dict)
    techs: set = field(default_factory=set)              # tech keys known (grid, national, regional)
    researching: str = ""                               # the tech being researched (progress is `research`)
    queue: list = field(default_factory=list)            # techs to research after it
    ideas: set = field(default_factory=set)              # idea card keys adopted
    national: str = ""                                  # the national (or regional default) tech key
    pending_ideas: list = field(default_factory=list)    # idea keys offered at the last age, not yet picked

    @property
    def balance(self):
        return sum(self.income.values())


@dataclass(eq=False)
class Unit:
    id: int
    kind: object
    owner: str
    pos: tuple
    hp: int = 1
    moves_left: int = 0
    carrier: object = None
    acted: bool = False
    attacked: bool = False
    goal: object = None
    xp: int = 0
    atk_up: int = 0
    def_up: int = 0
    trait: str = ""            # a general's speciality
    upgraded: bool = False     # drilled or refitted this season
    supplied: bool = True      # fed last season (only fed troops heal)
    supplies: int = 0          # seasons of food left, for wagons

    @property
    def naval(self):
        return self.kind.naval

    @property
    def rank(self):
        return max((r for r in VETERAN_RANKS if self.xp >= r[0]), key=lambda r: r[0])

    @property
    def label(self):
        name = self.kind.name
        if self.kind.war:
            rank = self.rank[1]
            ups = f" +{self.atk_up}/+{self.def_up}" if self.atk_up or self.def_up else ""
            return f"{rank + ' ' if rank else ''}{name}{ups}"
        if self.kind is GENERAL and self.trait:
            return f"General ({GENERAL_TRAITS[self.trait].split(' (')[0]})"
        return name


class Garrison:
    """A castle's own defenders, fighting like a unit of infantry."""

    def __init__(self, prov, extra_defense=0):
        self.prov = prov
        self.owner = prov.controller
        self.kind = UnitKind("garrison", "Garrison", 0, 0, branch="infantry", hp=prov.castle * GARRISON_HP,
                             attack=GARRISON_ATTACK, defense=GARRISON_DEFENSE + 2 * prov.castle + extra_defense)
        self.hp = prov.garrison
        self.xp = self.atk_up = self.def_up = 0

    @property
    def rank(self):
        return VETERAN_RANKS[0]


@dataclass(eq=False)
class War:
    a: str
    b: str
    start: int


def map_source(map, seed):
    """The geography a world is built from: the real 1480 map, or a random world for this seed."""
    if map == "random":
        from . import randomgeo
        if seed not in _RANDOM_GEOS:
            _RANDOM_GEOS[seed] = randomgeo.generate(seed)
        _RANDOM_GEOS[seed] = _RANDOM_GEOS.pop(seed)          # most recently used last
        while len(_RANDOM_GEOS) > RANDOM_KEPT:
            _RANDOM_GEOS.pop(next(iter(_RANDOM_GEOS)))
        return _RANDOM_GEOS[seed]
    return geo


def _remember_snapshot(key, data):
    """Keep the Europe snapshot plus the last RANDOM_KEPT random ones (each holds a whole world)."""
    _SNAPSHOTS.pop(key, None)
    _SNAPSHOTS[key] = data
    randoms = [k for k in _SNAPSHOTS if k[0] == "random"]
    for old in randoms[:-RANDOM_KEPT]:
        del _SNAPSHOTS[old]


def _with_article(name):
    """'a weaver', 'an armoury': the indefinite article for a level or building name."""
    name = name.lower()
    return ("an " if name[:1] in "aeiou" else "a ") + name


def _fill_defaults(obj):
    """Give a dataclass object loaded from an older save the fields it is missing."""
    if not is_dataclass(obj):
        return
    have = vars(obj)
    for f in fields(obj):
        if f.name in have:
            continue
        if f.default is not MISSING:
            setattr(obj, f.name, f.default)
        elif f.default_factory is not MISSING:
            setattr(obj, f.name, f.default_factory())


# ----- the world ------------------------------------------------------------------------
class CampaignWorld:
    mode = "campaign"

    def __init__(self, seed=1480, player=None, map="europe"):
        source = map_source(map, seed)
        key = (map, seed)
        if key in _SNAPSHOTS:
            _remember_snapshot(key, _SNAPSHOTS[key])
            self._restore(pickle.loads(_SNAPSHOTS[key]))
            self._set_player(player)
            return
        self.geo = source
        self.map = map
        self.seed = seed
        self.rng = random.Random(seed)
        self.cols, self.rows = geo.COLS, geo.ROWS
        self.turn = 1
        self.player = None
        self.log = []
        self.units = []
        self.wars = []
        self.routes = []
        self.version = 0                 # bumps whenever the map needs redrawing
        self._ids = itertools.count(1)
        self._owned = None
        self._castle_list = None
        self._bonus_cache = {}
        self.visible = set()
        self.over = False
        self._build_map()
        self._build_countries()
        self._build_markets()
        self._starting_units()
        for country in self.countries.values():
            self._explore_home(country)
        self.economy()                   # first prices and incomes
        self.message(f"{date(1)}. The age of discovery begins.")
        _remember_snapshot(key, pickle.dumps(self.save_state(), protocol=pickle.HIGHEST_PROTOCOL))
        self._set_player(player)

    def _set_player(self, player):
        if player is not None and player not in self.countries:
            raise ValueError(f"no country {player!r} on {self.geo.name} (find_country() takes names and any case)")
        self.player = player
        self.update_visibility()

    # ----- saving --------------------------------------------------------------------
    def save_state(self):
        """Everything needed to rebuild this world (picklable; the map source is rebuilt from map + seed)."""
        state = {k: v for k, v in self.__dict__.items() if k not in ("geo", "_ids", "_bonus_cache")}
        state["_next_id"] = next(self._ids)
        self._ids = itertools.count(state["_next_id"])
        return state

    def _restore(self, state):
        self.__dict__.update(state)
        self.map = self.__dict__.get("map", "europe")
        self.seed = self.__dict__.get("seed", 1480)
        next_id = self.__dict__.pop("_next_id", None)
        if next_id is None:
            next_id = max((u.id for u in self.__dict__.get("units", ())), default=0) + 1
        self._ids = itertools.count(next_id)
        self.geo = map_source(self.map, self.seed)
        self._migrate()

    def _migrate(self):
        """Fill in what a save from an older version lacks: world attributes and dataclass fields."""
        for name, default in WORLD_DEFAULTS.items():
            if name not in self.__dict__:
                setattr(self, name, default() if callable(default) else default)
        groups = (getattr(self, "provinces", {}).values(), getattr(self, "countries", {}).values(),
                  self.units, getattr(self, "markets", ()), self.routes, self.wars)
        for group in groups:
            for obj in group:
                _fill_defaults(obj)
        self.units = [u for u in self.units if u.kind is not PIONEER]      # provinces invest from the panel now
        self._bonus_cache = {}
        for country in getattr(self, "countries", {}).values():
            if not country.techs:
                self._legacy_techs(country)

    @classmethod
    def from_state(cls, state):
        """The world a save holds. Raises ValueError if the state is not a whole world (saves.load reports it)."""
        if not isinstance(state, dict):
            raise ValueError(f"a saved world is a dict, not {type(state).__name__}")
        missing = [name for name in WORLD_REQUIRED if name not in state]
        if missing:
            raise ValueError(f"the saved world has no {', '.join(missing)}")
        world = cls.__new__(cls)
        world._restore(state)
        if world.player is not None and world.player not in world.countries:
            raise ValueError(f"the saved world has no country {world.player!r} to play")
        world.update_visibility()
        return world

    # ----- map ---------------------------------------------------------------------
    def _build_map(self):
        g = self.geo
        land, lakes = g.land_cells(self.cols, self.rows)
        self.terrain = {}
        for r in range(self.rows):
            for c in range(self.cols):
                self.terrain[(c, r)] = "lake" if (c, r) in lakes else "ocean"
        for lon, lat in list(g.FORCE_LAND) + [(x[1], x[2]) for x in g.CITIES]:
            pos = geo.hex_of(lon, lat)
            if pos in self.terrain:
                land.add(pos)
                lakes.discard(pos)
        land -= lakes
        for lon, lat in getattr(g, "FORCE_SEA", ()):
            land.discard(geo.hex_of(lon, lat))

        # Rivers, traced onto the hexes they flow through.
        self.rivers, self.river_at = {}, {}
        for name, line in g.RIVERS:
            path = [p for p in self._trace(line) if p in land]
            if len(path) >= 3:
                self.rivers[name] = path
                for pos in path:
                    self.river_at.setdefault(pos, name)

        # Terrain by wave function collapse: each hex gets odds from its geography, and
        # neighbouring hexes must fit together.
        coastal = {p for p in land if any(n in self.terrain and n not in land for n in neighbors(p))}
        prior = {p: self._prior(p, p in coastal, p in self.river_at) for p in land}
        tiles = wfc.collapse(sorted(land), prior, FORBIDDEN, neighbors, random.Random(self.seed), affinity=1.6)
        for pos, tile in tiles.items():
            self.terrain[pos] = tile
        rng = random.Random(1480)

        self.sea_body = {}
        body = 0
        for pos in self.terrain:
            if self.terrain[pos] != "ocean" or pos in self.sea_body:
                continue
            body += 1
            queue = deque([pos])
            self.sea_body[pos] = body
            while queue:
                cur = queue.popleft()
                for n in neighbors(cur):
                    if self.terrain.get(n) == "ocean" and n not in self.sea_body:
                        self.sea_body[n] = body
                        queue.append(n)
        self.cities = {}
        for name, lon, lat, size in g.CITIES:
            pos = geo.hex_of(lon, lat)
            if self.is_land(pos):
                self.cities[pos] = (name, size)
        self.provinces = {}
        for pos in sorted(p for p, t in self.terrain.items() if TERRAIN[t].move is not None):
            coastal = any(self.terrain.get(n) == "ocean" for n in neighbors(pos))
            self.provinces[pos] = Province(pos, self.terrain[pos], None, coastal, "", city=pos in self.cities)
        for prov in self.provinces.values():
            prov.good = self._good_for(prov, rng)

    def _trace(self, line):
        """The hexes a (lon, lat) polyline passes through, in order, without loops."""
        out = []
        for (x0, y0), (x1, y1) in zip(line, line[1:]):
            steps = max(1, int(max(abs(x1 - x0), abs(y1 - y0)) / geo.COL_DEG * 4))
            for i in range(steps + 1):
                t = i / steps
                pos = geo.hex_of(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
                if pos not in self.terrain or (out and out[-1] == pos):
                    continue
                if pos in out:
                    del out[out.index(pos) + 1:]
                    continue
                if out and distance(out[-1], pos) > 1:       # fill a skipped corner
                    between = [n for n in neighbors(out[-1]) if distance(n, pos) == 1]
                    if between:
                        out.append(min(between))
                out.append(pos)
        return out

    @staticmethod
    def _near_line(point, lines, limit):
        """Distance in degrees to the nearest line, or `limit` if none is closer."""
        best = limit
        lon, lat = point
        for line in lines:
            for (ax, ay), (bx, by) in zip(line, line[1:]):
                if min(ax, bx) - limit > lon or max(ax, bx) + limit < lon or \
                        min(ay, by) - limit > lat or max(ay, by) + limit < lat:
                    continue
                best = min(best, geo.seg_distance(point, (ax, ay), (bx, by)))
        return best

    def _prior(self, pos, coastal, river):
        """Odds for each kind of terrain on a land hex, from what is known about the place."""
        g = self.geo
        point = geo.lonlat(pos)
        lon, lat = point
        mount = self._near_line(point, g.MOUNTAINS, 2.0)
        if mount < 0.8:
            return {"mountains": 1.0, "snow": 0.35 if lat > 45.5 or (lon < -30 and lat > 50) else 0.0,
                    "hills": 0.15}
        hills = mount < 1.6 or self._near_line(point, g.HILLS, 1.0) < 1.0
        desert = g.desert_at(point)
        marsh = g.marsh_at(point)
        americas = lon < -30
        if river:
            if desert:
                return {"plains": 1.0, "marsh": 0.08 + marsh}
            return {"plains": 1.0, "marsh": 0.15 + marsh, "forest": 0.15, "hills": 0.05}
        if desert:
            return {"desert": 1.0, "steppe": 0.06, "hills": 0.04 if hills else 0.0}
        if hills:
            w = {"hills": 0.7, "forest": 0.25, "mountains": 0.08 if mount < 1.2 else 0.0}
            if lat > 57:
                w["taiga"] = 0.3
            if lat < 17:
                w["jungle" if lat < 8 else "savanna"] = 0.2
            return w
        if americas:
            if lat >= 59:
                return {"tundra": 1.0, "snow": 0.35, "taiga": 0.1}
            if lat >= 55:
                return {"tundra": 0.6, "taiga": 0.6, "marsh": 0.05}
            if lat >= 47:
                return {"taiga": 0.5, "forest": 0.4, "plains": 0.12, "marsh": 0.06 + marsh}
            if lat < 21.5:
                if lon < -95 and lat > 16.5:
                    return {"plains": 0.6, "hills": 0.3, "savanna": 0.1}
                w = {"jungle": 0.6, "plains": 0.15, "savanna": 0.3 if 2 < lat < 12 and lon > -72 else 0.1,
                     "marsh": 0.04 + marsh}
                if coastal:
                    w["beach"] = 0.3
                return w
            w = {"forest": 0.75 if lat > 40 else 0.5, "plains": 0.3 if lat > 40 else 0.45, "marsh": 0.04 + marsh}
            if coastal and lat < 36:
                w["beach"] = 0.25
            return w
        if lat < 17:                                    # Africa south of the Sahara
            if lat < 8:
                w = {"jungle": 0.7, "plains": 0.12, "savanna": 0.18, "marsh": 0.04 + marsh}
            else:
                w = {"savanna": 0.65, "plains": 0.3, "steppe": 0.05}
            if coastal:
                w["beach"] = 0.2
            return w
        if g.steppe_at(point):
            return {"steppe": 1.0, "plains": 0.12, "marsh": marsh}
        if lat >= 58 or (lon > 24 and lat >= 55):
            w = {"taiga": 0.5, "forest": 0.25, "plains": 0.2, "marsh": 0.06 + marsh}
        elif lat >= 53:
            w = {"forest": 0.45, "plains": 0.45, "hills": 0.08, "marsh": 0.05 + marsh}
        else:
            w = {"plains": 0.64, "forest": 0.22, "hills": 0.1, "marsh": 0.02 + marsh}
        if coastal and lat < 41:
            w["beach"] = 0.18
        return w

    def _good_for(self, prov, rng):
        lon, lat = geo.lonlat(prov.pos)
        t, roll = prov.terrain, rng.random()
        americas, africa = lon < -30, lat < 17 and lon > -20
        near = lambda x, y, r=2.5: abs(lon - x) < r and abs(lat - y) < r
        special = self._special_good(prov, lon, lat, t, rng.random(), americas, near)
        if special:
            return special
        if t == "desert":
            return ("salt" if roll < 0.5 else "fish") if prov.coastal else None
        if t == "marsh":
            return "fish" if prov.coastal and roll < 0.5 else "wool" if roll < 0.75 else "grain"
        if t == "taiga":
            return "furs" if roll < 0.5 else "timber"
        if t == "snow":
            return "furs" if roll < 0.6 else None
        if t == "savanna":
            if americas:
                return "cotton" if roll < 0.4 else "grain" if roll < 0.8 else "tobacco"
            return "ivory" if roll < 0.35 else "grain" if roll < 0.75 else "cotton"
        if t == "beach":
            if prov.coastal and roll < 0.45:
                return "fish"
            if americas or africa:
                return "sugar" if roll < 0.75 else "cotton"
            return "salt" if roll < 0.6 else "wine" if lat < 44 else "grain"
        if t == "tundra":
            return "fish" if prov.coastal and roll < 0.4 else "furs"
        if t == "mountains" or (t == "hills" and roll < 0.3):
            if americas and lon < -95:
                return "silver"
            if near(13.0, 50.5) or near(11.5, 47.3, 1.5):
                return "silver"
            if near(18.9, 48.7, 1.5) or near(-11, 13.5, 3) or near(-1.5, 6.5, 3):
                return "gold"
            if t == "hills" and americas:
                return "furs" if lat > 42 else "timber"
            return "iron" if roll < 0.8 or t == "hills" else "salt"
        if t == "jungle":
            if americas:
                return "sugar" if prov.coastal and roll < 0.6 else "tobacco" if roll < 0.75 else "timber"
            if near(-1.5, 6.5, 3.5):
                return "gold" if roll < 0.5 else "ivory"
            return "ivory" if roll < 0.6 else "timber"
        if t == "forest":
            if (americas and lat > 42) or (lon > 22 and lat > 57):
                return "furs" if roll < 0.55 else "timber"
            if prov.coastal and lat > 48 and roll < 0.25:
                return "fish"
            return "timber"
        if t == "steppe":
            return "grain" if roll < 0.55 else "wool"
        if prov.coastal and (lat > 48 or (americas and lat > 40)) and roll < (0.6 if americas else 0.3):
            return "fish"
        if americas:
            if lat < 25:
                if lon < -95:
                    return "grain" if roll < 0.6 else "cotton"
                return "sugar" if roll < 0.5 else "tobacco" if roll < 0.75 else "cotton"
            if 33 <= lat <= 39.5:
                return "tobacco" if roll < 0.6 else "grain"
            return "grain"
        if africa:
            return "grain" if roll < 0.5 else "ivory" if roll < 0.75 else "cotton"
        if lat < 37.5 and lon > 29 and prov.coastal and roll < 0.45:
            return "spices"
        if lat < 44.5 and -10 < lon < 40:
            if lon > 26 and roll < 0.25:
                return "cotton"
            return "grain" if roll < 0.55 else "wine" if roll < 0.9 else "wool"
        if near(20.0, 50.0, 1) or near(10.4, 53.25, 1) or near(13.0, 47.8, 1):
            return "salt"
        wool = 0.35 if (lon < 2 and lat > 50) or (-7 < lon < -1 and 39 < lat < 43) else 0.15
        return "wool" if roll < wool else "grain"

    @staticmethod
    def _special_good(prov, lon, lat, t, r, americas, near):
        """Horses, cattle, stone, copper, hemp, olives, silk, dyes, cocoa and coffee, where they belonged in 1480."""
        if t in ("mountains", "hills") and (near(15.5, 60.5, 3) or near(19.0, 48.7, 2) or near(13.0, 50.5, 1.5)
                                           or near(33.0, 35.0, 1.5) or (americas and lon < -95)) and r < 0.35:
            return "copper"
        if t in ("hills", "mountains") and not americas and lat > 35 and r < (0.3 if near(10.5, 44.0, 3) else 0.16):
            return "stone"
        if t == "steppe" and r < 0.35:
            return "horses"
        if t in ("plains", "savanna") and (near(19.5, 47.0, 3) or near(-5.5, 37.5, 2)) and r < 0.3:
            return "horses"
        if t in ("plains", "marsh", "steppe") and not americas and 44 < lat < 56 and r < 0.12:
            return "cattle"
        if t == "savanna" and not americas and r < 0.15:
            return "cattle"
        if t in ("plains", "marsh") and not americas and lat > 50 and -6 < lon < 45 and r < 0.18:
            return "hemp"
        if t in ("plains", "hills") and (near(29.0, 40.0, 2.5) or near(10.5, 45.2, 1.8) or near(-3.6, 37.2, 1.0)) \
                and r < 0.35:
            return "silk"
        if t in ("plains", "hills", "beach") and not americas and 30 < lat < 43.8 and -10 < lon < 37 and r < 0.3:
            return "olives"
        if americas and t in ("jungle", "savanna", "plains") and lat < 22 and lon > -98:
            if r < 0.16:
                return "cocoa" if lon < -75 else "dyes"
            if r < 0.24:
                return "dyes"
        if t in ("hills", "mountains", "plains", "savanna") and lon > 36 and 8 < lat < 18 and r < 0.4:
            return "coffee"
        return None

    # ----- countries and people ----------------------------------------------------
    def _build_countries(self):
        land = list(self.provinces)
        landmass, comp = {}, 0
        for pos in land:
            if pos in landmass:
                continue
            comp += 1
            queue = deque([pos])
            landmass[pos] = comp
            while queue:
                cur = queue.popleft()
                for n in neighbors(cur):
                    if n in self.provinces and n not in landmass:
                        landmass[n] = comp
                        queue.append(n)
        self.landmass = landmass

        self.countries = {}
        seeds = []
        for tag, (name, color, points) in self.geo.COUNTRIES.items():
            capital = self._nearest_land(geo.hex_of(*points[0]))
            self.countries[tag] = Country(tag, name, color, capital)
            for lon, lat in points:
                pos = self._nearest_land(geo.hex_of(lon, lat))
                seeds.append((tag, pos, to_cube(pos), landmass[pos]))
        reach = TERRITORY_RADIUS * (1.7 if self.map == "random" else 1)
        for prov in self.provinces.values():
            q, r, s = to_cube(prov.pos)
            best = None
            for tag, pos, (sq, sr, ss), mass in seeds:
                d = max(abs(q - sq), abs(r - sr), abs(s - ss))
                limit = reach if mass == landmass[prov.pos] else 1
                if d <= limit and (best is None or d < best[0]):
                    best = (d, tag)
            if best and not (prov.terrain == "desert" and best[0] > 2 * SCALE):
                prov.owner = prov.controller = best[1]
        for tag, country in self.countries.items():
            self.provinces[country.capital].owner = self.provinces[country.capital].controller = tag

        # Names, natives and population.
        rng = random.Random(7)
        named = list(self.cities.items())
        for prov in self.provinces.values():
            lon, lat = geo.lonlat(prov.pos)
            if prov.pos in self.cities:
                prov.name = self.cities[prov.pos][0]
            else:
                near = min(named, key=lambda kv: distance(kv[0], prov.pos))
                if distance(near[0], prov.pos) <= 4 * SCALE:
                    prov.name = f"near {near[1][0]}"
            if prov.owner is None:
                prov.tribe = min(self.geo.TRIBES, key=lambda t: (t[1] - lon) ** 2 + (t[2] - lat) ** 2)[0]
                if not prov.name:
                    prov.name = f"{prov.tribe} lands"
            elif not prov.name:
                prov.name = f"{self.countries[prov.owner].name} countryside"
            density = TERRAIN[prov.terrain].density * rng.uniform(0.75, 1.25)
            if prov.owner:
                factor = 1.0
                if (-5 < lon < 17 and 40 < lat < 46) or (2 < lon < 7 and 50 < lat < 53):
                    factor = 1.35
                elif lon > 30 and lat > 50:
                    factor = 0.45
                elif lat > 58:
                    factor = 0.4
                elif lat < 37.5 and lon < 28:
                    factor = 0.7
                if self.geo.FERTILE_RIVERS and geo.line_distance((lon, lat), self.geo.FERTILE_RIVERS[0]) < 1:
                    factor = 2.2
                elif prov.pos in self.river_at:
                    factor *= 1.3
                prov.peasants = density * factor * 0.94
                prov.burghers = density * factor * 0.03
                prov.nobles = density * factor * 0.03
                if prov.pos in self.cities:
                    extra = self.cities[prov.pos][1]
                    prov.peasants += extra * 0.4
                    prov.burghers += extra * 0.55
                    prov.nobles += extra * 0.05
            else:
                factor = 0.35 if lon < -30 else 0.6 if lat < 17 else 0.5
                if prov.tribe in ("Mexica",):
                    factor = 1.6
                elif prov.tribe in ("Maya", "Muisca", "Benin", "Akan", "Yoruba", "Hausa"):
                    factor = 0.9
                prov.natives = density * factor
                if prov.pos in self.cities:
                    prov.natives += self.cities[prov.pos][1] * 0.5

        # Starting towns, castles, works and buildings.
        for prov in self.provinces.values():
            if not prov.owner:
                continue
            capital = self.countries[prov.owner].capital == prov.pos
            if prov.city:
                prov.settlement = 3 if self.cities[prov.pos][1] >= 40 else 2
            elif prov.pop >= SETTLEMENT_POP[1] * 2.5:
                prov.settlement = 1
            if capital:
                prov.settlement = max(prov.settlement, 2)
                prov.castle = 3 if self.cities.get(prov.pos, ("", 0))[1] >= 100 else 2
            elif prov.settlement >= 2 and rng.random() < 0.3:
                prov.castle = 1
            if prov.coastal and (capital or (prov.city and self.cities[prov.pos][1] >= 25)):
                prov.buildings["port"] = 1
            if prov.burghers >= 14:
                prov.buildings["weaver"] = 1
            if prov.city and prov.burghers >= 8:            # the old trades of the big towns
                h = (prov.pos[0] * 31 + prov.pos[1] * 17) % 7
                if prov.level("port") or (prov.coastal and h < 3):
                    prov.buildings["ropewalk"] = 1
                if capital or h == 1:
                    prov.buildings["powder_mill"] = 1
                if h in (2, 5):
                    prov.buildings["tannery"] = 1
                if h == 4 or prov.name in ("Venice", "Genoa", "Antwerp", "Nuremberg", "Constantinople"):
                    prov.buildings["glassworks"] = 1
            if prov.burghers >= 30:
                prov.buildings["marketplace"] = 1
            if prov.good and prov.good in WORKS and rng.random() < 0.25:
                prov.works = 2 if prov.pop > 20 and rng.random() < 0.4 else 1
        for country in self.countries.values():
            mine = self.provinces_of(country.tag)
            coast = [p for p in mine if p.coastal]
            if coast and not any(p.level("port") for p in mine):
                max(coast, key=lambda p: (p.pop, p.pos)).buildings["port"] = 1
            country.treasury = 150 + 4 / AREA * len(self.provinces_of(country.tag))
        self.colonial = dict(getattr(self.geo, "COLONIAL", {}))
        self._start_techs()
        self._build_roads()

    def _build_roads(self):
        """Roads join each country's towns to the nearest town already on its network, and capitals to
        neighbouring capitals. Armies march along them at one move per hex."""
        self.roads, self.road_paths = set(), []

        def connect(start, goals, limit, owner=None):
            best = {start: (0, None)}
            heap = [(0, start)]
            while heap:
                cost, pos = heapq.heappop(heap)
                if cost > best[pos][0]:
                    continue
                if pos in goals and pos != start:
                    path = []
                    while pos is not None:
                        path.append(pos)
                        pos = best[pos][1]
                    return path[::-1]
                for n in neighbors(pos):
                    prov = self.provinces.get(n)
                    if prov is None or (owner and prov.owner != owner):
                        continue
                    step = 0.5 if n in self.roads else TERRAIN[prov.terrain].move
                    if cost + step <= limit and cost + step < best.get(n, (INF,))[0]:
                        best[n] = (cost + step, pos)
                        heapq.heappush(heap, (cost + step, n))
            return None

        for tag, country in self.countries.items():
            towns = [p.pos for p in self.provinces_of(tag) if p.settlement >= 2 or p.city]
            network = {country.capital}
            for pos in sorted(towns, key=lambda q: distance(q, country.capital)):
                if pos in network:
                    continue
                path = connect(pos, network, 14 * SCALE, owner=tag)
                if path:
                    self.road_paths.append(path)
                    self.roads.update(path)
                network.add(pos)
        capitals = [c.capital for c in self.countries.values()]
        for i, a in enumerate(capitals):
            for b in capitals[i + 1:]:
                if self.landmass.get(a) == self.landmass.get(b) and distance(a, b) <= 9 * SCALE:
                    path = connect(a, {b}, 16 * SCALE)
                    if path:
                        self.road_paths.append(path)
                        self.roads.update(path)

    def step_cost(self, frm, to):
        """Move points to walk from one land hex into the next: roads and rivers make it cheaper."""
        move = TERRAIN[self.terrain[to]].move
        if to in self.roads and frm in self.roads:
            return 1
        river = self.river_at.get(to)
        if river and self.river_at.get(frm) == river:
            return max(1, move - 1)
        return move

    def _starting_units(self):
        for prov in self.provinces.values():
            prov.garrison = prov.castle * GARRISON_HP
        for tag, country in self.countries.items():
            pop = self.total_pop(tag)
            kinds = ([troop("infantry", 1)] * max(1, round(pop / 450)) + [troop("cavalry", 1)] * round(pop / 1000)
                     + [troop("artillery", 1)] * (1 if pop > 900 else 0))
            if pop > 1500:
                kinds.append(GENERAL)
            for kind in kinds:
                spot = self._land_spot(tag, self.provinces[country.capital], kind)
                if spot:
                    self._add_unit(kind, tag, spot, moves=kind.moves)
            if self.colonial.get(tag, 999) <= 40:
                ports = [p for p in self.provinces_of(tag) if p.level("port")]
                ports.sort(key=lambda p: (geo.lonlat(p.pos)[0], -p.pop))
                for prov in ports:
                    sea = [n for n in neighbors(prov.pos) if self.is_sea(n) and not self.units_at(n)]
                    if sea:
                        self._add_unit(CARAVEL, tag, sea[0], moves=CARAVEL.moves)
                        break

    def _add_unit(self, kind, owner, pos, moves=0):
        unit = Unit(next(self._ids), kind, owner, pos, hp=kind.hp, moves_left=moves)
        if kind is GENERAL:
            unit.trait = self.rng.choice(sorted(GENERAL_TRAITS))
        self.units.append(unit)
        return unit

    def _nearest_land(self, pos):
        if pos in self.provinces:
            return pos
        return min(self.provinces, key=lambda p: (distance(p, pos), p))

    # ----- lookups -----------------------------------------------------------------
    def is_land(self, pos):
        return pos in self.terrain and TERRAIN[self.terrain[pos]].move is not None

    def is_sea(self, pos):
        return self.terrain.get(pos) == "ocean"

    def province(self, pos):
        return self.provinces.get(pos)

    def find_country(self, name):
        """The tag of a country given by tag or name in any case ('por', 'Portugal'), or None."""
        key = (name or "").strip().casefold()
        if not key:
            return None
        for tag in self.countries:
            if tag.casefold() == key:
                return tag
        for tag, country in self.countries.items():
            if country.name.casefold() == key:
                return tag
        return None

    def message(self, text, tag=None):
        if tag is None or tag == self.player:
            self.log.append(text)
            del self.log[:-80]

    def provinces_of(self, tag):
        if self._owned is None:
            self._owned = {}
            for prov in self.provinces.values():
                if prov.owner:
                    self._owned.setdefault(prov.owner, []).append(prov)
        return self._owned.get(tag, [])

    def changed(self, ownership=False):
        self.version += 1
        if ownership:
            self._owned = None
            self._castle_list = None

    def unit_at(self, pos):
        """The unit on top of the stack at pos (a war unit if there is one)."""
        here = self.units_at(pos)
        return next((u for u in here if u.kind.war), here[0] if here else None)

    def units_at(self, pos):
        return [u for u in self.units if u.pos == pos and u.carrier is None]

    def owners_at(self):
        """{pos: set of owners} of every unit standing on the map (one pass, for path searches)."""
        found = {}
        for u in self.units:
            if u.carrier is None:
                found.setdefault(u.pos, set()).add(u.owner)
        return found

    def in_old_world(self, pos):
        """Whether a hex belongs to the known Old World (not a colony region)."""
        if self.map == "random":
            return pos in self._known_world
        lon, lat = geo.lonlat(pos)
        return not (lon < -20 or (lat < 15 and lon < 20))

    def units_of(self, tag):
        return [u for u in self.units if u.owner == tag]

    def cargo(self, ship):
        return [u for u in self.units if u.carrier is ship]

    def date(self):
        return date(self.turn)

    def year(self):
        return START_YEAR + (self.turn - 1) // 4

    def neighbours_of(self, tag):
        """Countries that share a land border (or a narrow sea) with `tag`."""
        owned = self.provinces_of(tag)
        cache = getattr(self, "_neighbour_cache", None)
        if cache is None or cache[0] is not self._owned:
            cache = self._neighbour_cache = (self._owned, {})
        if tag in cache[1]:
            return set(cache[1][tag])
        found = set()
        for prov in owned:
            for pos in (within(prov.pos, 2 * SCALE) if prov.coastal else neighbors(prov.pos)):
                other = self.provinces.get(pos)
                if other and other.owner and other.owner != tag and \
                        (prov.coastal and other.coastal or distance(pos, prov.pos) == 1):
                    found.add(other.owner)
        cache[1][tag] = frozenset(found)
        return found

    def power(self, unit):
        """Rough fighting value of one unit (about 5 for a fresh pikeman)."""
        if not unit.kind.war:
            return 0.0
        base = (unit.kind.attack + unit.kind.defense + unit.atk_up + unit.def_up) / 2
        return base * unit.hp / unit.kind.hp * unit.rank[2]

    def stack_power(self, units):
        return sum(self.power(u) for u in units)

    def army_strength(self, tag):
        return round(sum(self.power(u) for u in self.units if u.owner == tag) / 5, 1)

    def total_pop(self, tag):
        return sum(p.pop for p in self.provinces_of(tag))

    def colonies_of(self, tag):
        return [p for p in self.provinces_of(tag) if p.colony or p.trading_post or not self.in_old_world(p.pos)]

    # ----- markets and trade routes -------------------------------------------------
    def _build_markets(self):
        self.markets = []
        for name, lon, lat, colonial in self.geo.MARKETS:
            market = Market(name, (lon, lat), colonial)
            for g, good in GOODS.items():
                market.price[g] = good.price
                market.history[g] = []
            market.reset()
            self.markets.append(market)
        self._sea_cache = {}
        self._markets_dirty = True
        self.ensure_markets()

    def refresh_markets(self):
        """Mark markets for rebuilding (done lazily, at most once per change burst)."""
        self._markets_dirty = True
        self.version += 1

    def ensure_markets(self):
        if self._markets_dirty:
            self._markets_dirty = False
            self._rebuild_markets()

    def _rebuild_markets(self):
        """Activate colonial markets, assign provinces to markets and rebuild trade routes."""
        for market in self.markets:
            pos = geo.hex_of(*market.point)
            near = [self.provinces[p] for p in within(pos, 2) if p in self.provinces and self.provinces[p].owner]
            if market.colonial:
                market.active = bool(near)
                market.center = min(near, key=lambda p: (distance(p.pos, pos), p.pos)).pos if near else None
            else:
                market.center = self._nearest_land(pos)
                market.active = self.provinces[market.center].owner is not None
        active = [m for m in self.markets if m.active]
        limits = [MARKET_REACH * (1 + self.bonus(self.market_owner(m), "market_reach")) for m in active]
        best = {}
        heap = []
        for i, market in enumerate(active):
            best[market.center] = (0, i)
            heapq.heappush(heap, (0, market.center, i))
        while heap:
            cost, pos, i = heapq.heappop(heap)
            if best.get(pos, (INF,))[0] < cost:
                continue
            for n in neighbors(pos):
                if n not in self.terrain:
                    continue
                if self.is_sea(n):
                    step = SEA_STEP if (self.is_sea(pos) or self.provinces.get(pos) and self.provinces[pos].coastal) else INF
                elif self.is_land(n):
                    step = self.step_cost(pos, n) if not self.is_sea(pos) else 1
                else:
                    continue
                new = cost + step
                if new <= limits[i] and new < best.get(n, (INF,))[0]:
                    best[n] = (new, i)
                    heapq.heappush(heap, (new, n, i))
        for market in self.markets:
            market.provinces = []
        capital_market = {}
        for prov in self.provinces.values():
            prov.market, prov.remote = None, False
            if prov.owner is None:
                continue
            if prov.pos in best:
                prov.market = active[best[prov.pos][1]]
        for country in self.countries.values():
            home = self.provinces[country.capital]
            capital_market[country.tag] = home.market if home.owner == country.tag else None
        for prov in self.provinces.values():
            if prov.owner and prov.market is None:
                prov.market, prov.remote = capital_market.get(prov.owner), True
            if prov.market:
                prov.market.provinces.append(prov)
        self._build_routes(active)
        self.changed()

    def market_owner(self, market):
        prov = self.provinces.get(market.center)
        return prov.owner if prov else None

    def _sea_distances(self, start):
        """Ocean distances from the sea next to `start` (cached)."""
        if start in self._sea_cache:
            return self._sea_cache[start]
        dist = {}
        queue = deque()
        for n in within(start, 2):
            if self.is_sea(n):
                dist[n] = distance(n, start)
                queue.append(n)
        while queue:
            pos = queue.popleft()
            for n in neighbors(pos):
                if self.is_sea(n) and n not in dist:
                    dist[n] = dist[pos] + 1
                    queue.append(n)
        self._sea_cache[start] = dist
        return dist

    def _build_routes(self, active):
        old = {(r.a.name, r.b.name): r for r in self.routes}
        routes = []
        adjacent = set()
        for prov in self.provinces.values():
            if not prov.market:
                continue
            for n in neighbors(prov.pos):
                other = self.provinces.get(n)
                if other and other.market and other.market is not prov.market:
                    adjacent.add(frozenset((prov.market.name, other.market.name)))
        for i, a in enumerate(active):
            for b in active[i + 1:]:
                land = frozenset((a.name, b.name)) in adjacent
                sea_d = INF
                if self.provinces[a.center].coastal or any(self.is_sea(n) for n in within(a.center, 1)):
                    seas = self._sea_distances(a.center)
                    near_b = [seas[n] for n in within(b.center, 2) if n in seas]
                    sea_d = min(near_b) if near_b else INF
                atlantic = (a.colonial != b.colonial) and min(a.point[0], b.point[0]) < -20 and \
                    max(a.point[0], b.point[0]) < 12
                both_colonial = a.colonial and b.colonial
                owners = (self.market_owner(a), self.market_owner(b))
                sea_range = SEA_ROUTE_RANGE * (1 + max(self.bonus(o, "sea_range") for o in owners))
                flag_ok = any(self.has(o, "atlantic") for o in owners)
                if land:
                    route = (distance(a.center, b.center), False)
                elif sea_d <= sea_range or (sea_d <= ATLANTIC_RANGE and flag_ok and (atlantic or both_colonial)):
                    route = (sea_d, True)
                else:
                    continue
                key = (a.name, b.name)
                kept = old.get(key)
                r = Route(len(routes), a, b, route[0], route[1])
                if kept:
                    r.orders = kept.orders
                routes.append(r)
        self.routes = routes
        for country in self.countries.values():
            country.orders = [(r.id, good, src) for r in routes for tag, good, src in r.orders if tag == country.tag]

    def routes_of(self, market):
        return [r for r in self.routes if r.a is market or r.b is market]

    def route_capacity(self, route):
        """Goods the background trade moves along a route each season (merchants come on top)."""
        cap = ROUTE_BASE
        for market in (route.a, route.b):
            prov = self.provinces.get(market.center)
            if prov:
                cap += MARKETPLACE_CAPACITY * prov.level("marketplace")
                if route.sea:
                    cap += PORT_CAPACITY * prov.level("port")
        return cap

    def merchants(self, tag):
        levels = sum(p.level("marketplace") for p in self.provinces_of(tag))
        owns_market = any(m.active and self.market_owner(m) == tag for m in self.markets)
        return min(6, 1 + owns_market + levels // 3) + int(self.bonus(tag, "merchants"))

    def merchant_markets(self, tag):
        return {p.market for p in self.provinces_of(tag) if p.market}

    def market_named(self, name):
        return next(m for m in self.markets if m.name == name)

    def merchant_options(self, tag, route):
        """What a merchant could do on this route: [(good, source, destination, profit per unit, amount)]."""
        mine = self.merchant_markets(tag)
        options = []
        for g, good in GOODS.items():
            if good.kind == "money":
                continue
            for src, dst in ((route.a, route.b), (route.b, route.a)):
                if src not in mine and dst not in mine:
                    continue
                spare = max(0.0, src.supply[g] - src.demand[g] * 0.5)
                amount = min(MERCHANT_CAPACITY, spare)
                if amount < 0.5:
                    continue
                margin = dst.price[g] - src.price[g] - self.route_cost(route)
                options.append((g, src, dst, margin, amount))
        options.sort(key=lambda o: -o[3] * o[4])
        return options

    def send_merchant_check(self, tag, route):
        country = self.countries[tag]
        if len(country.orders) >= self.merchants(tag):
            return False, "All your merchants are busy (recall one first)"
        if route.a not in self.merchant_markets(tag) and route.b not in self.merchant_markets(tag):
            return False, "Merchants work routes from markets where you own land"
        return True, ""

    def send_merchant(self, tag, route, good=None, src=None):
        """Give a merchant an order: carry `good` from market `src` along the route."""
        if not self.send_merchant_check(tag, route)[0]:
            return False
        if good is None:
            options = self.merchant_options(tag, route)
            if not options:
                return False
            good, src = options[0][0], options[0][1]
        name = src.name if hasattr(src, "name") else src
        route.orders.append((tag, good, name))
        self.countries[tag].orders.append((route.id, good, name))
        other = route.b.name if name == route.a.name else route.a.name
        self.message(f"A merchant now carries {GOODS[good].name.lower()} from {name} to {other}.", tag)
        return True

    def recall_merchant(self, tag, route, order=None):
        mine = [o for o in route.orders if o[0] == tag and (order is None or o[1:] == tuple(order[-2:]))]
        if not mine:
            return False
        route.orders.remove(mine[-1])
        self.countries[tag].orders.remove((route.id,) + mine[-1][1:])
        return True

    # ----- the economy (runs once per season, after everybody moved) --------------
    def economy(self):
        self.ensure_markets()
        for market in self.markets:
            market.reset()
        for prov in self.provinces.values():
            prov.output = prov.value = 0.0
            market = prov.market
            if not prov.owner or not market:
                continue
            if prov.controller == prov.owner:
                food = SUBSISTENCE * prov.peasants
                market.supply["grain"] += food
                market.produced["grain"] += food
            if prov.good and prov.controller == prov.owner:
                out = OUTPUT[prov.good] * self._workers(prov) * self._works_factor(prov) * self._output_mult(prov)
                if prov.remote:
                    out *= REMOTE_PENALTY
                if prov.foraged and prov.foraged[1] >= self.turn - 1:
                    out *= 0.5
                prov.output = out
                market.supply[prov.good] += out
                market.produced[prov.good] += out
            for cls in CLASSES:
                people = getattr(prov, cls)
                for need, amount in NEEDS[cls].items():
                    market.demand[need if need != "food" else "grain"] += amount * people
            for key in MANUFACTORIES:
                level = prov.level(key)
                if level:
                    staff = self._staffing(prov, key)
                    for g, n in self._inputs(prov, key).items():
                        market.demand[g] += n * level * staff
        for unit in self.units:
            if unit.kind.war and unit.carrier is None:
                market = self.food_market(unit)
                if market:
                    market.demand["grain"] += FOOD_PER_TROOP
        for market in self.markets:
            self._split_food(market)
            self._set_prices(market)
        # Workshops make their goods first, so merchants and trade routes can carry them.
        profits = {}
        for prov in self.provinces.values():
            if not prov.owner or not prov.market or prov.controller != prov.owner:
                continue
            for key in MANUFACTORIES:
                level = prov.level(key)
                if not level:
                    continue
                market, staff = prov.market, self._staffing(prov, key)
                inputs = self._inputs(prov, key)
                share = min((market.satisfaction(g) for g in inputs), default=1.0) * staff * level
                made = 0.0
                for g, n in BUILDINGS[key].outputs.items():
                    market.supply[g] += n * share
                    market.produced[g] += n * share
                    made += n * share * market.price[g]
                cost = sum(n * share * market.price[g] for g, n in inputs.items())
                profits[prov.owner] = profits.get(prov.owner, 0) + max(0.0, made - cost) * MANUFACTORY_TAX
        for market in self.markets:
            self._set_prices(market)
        for route in self.routes:
            self._merchants_trade(route)
        for route in self.routes:
            self._trade(route)
        for market in self.markets:
            self._set_prices(market)
            for g in GOODS:
                market.history[g].append(round(market.price[g], 2))
                del market.history[g][:-40]
        self._incomes(profits)

    # ----- what the techs and ideas change (keys in tech.EFFECT_KEYS) ------------------------------
    def route_cost(self, route):
        """Cost per unit on a trade route: a colonial market's owner may make colonial routes cheaper."""
        cuts = [self.bonus(self.market_owner(m), "colonial_route_cost") for m in (route.a, route.b) if m.colonial]
        return route.cost * (1 + min(cuts, default=0))

    def men_per_troop(self, tag):
        return MANPOWER / (1 + self.bonus(tag, "manpower"))

    def drill_max(self, tag):
        return UPGRADE_MAX + int(self.bonus(tag, "upgrade_max"))

    def wagon_seasons(self, tag):
        return WAGON_SEASONS + int(self.bonus(tag, "wagon_seasons"))

    def building_max(self, tag, key):
        if key in MANUFACTORIES:
            return min(3, 2 + int(self.bonus(tag, "manufactory_max")))
        return BUILDINGS[key].max_level

    def castle_top(self, tag):
        """The highest castle level this country can build (2 small castle, 3 large castle)."""
        return min(3, 2 + int(self.bonus(tag, "castle_max")))

    def supply_reach(self, tag):
        return SUPPLY_RANGE + round(self.bonus(tag, "supply_range") * SCALE)

    def unit_moves(self, unit):
        if unit.naval:
            return unit.kind.moves + round(self.bonus(unit.owner, "ship_moves") * SCALE)
        return unit.kind.moves

    def unit_sight(self, unit):
        if unit.naval:
            return unit.kind.sight + round(self.bonus(unit.owner, "ship_sight") * SCALE)
        return unit.kind.sight

    def _workers(self, prov):
        if not prov.trading_post:
            return prov.peasants
        return prov.peasants + prov.natives * TRADING_POST_SHARE * (1 + self.bonus(prov.owner, "trading_post_share"))

    def _works_factor(self, prov):
        extra = self.bonus(prov.owner, "farm_works") if prov.good in FARM_GOODS else 0
        return 1 + (WORKS_BONUS + extra) * prov.works

    def _output_mult(self, prov):
        if prov.good in MINE_GOODS:
            return 1 + self.bonus(prov.owner, "mines")
        if prov.good == "wool":
            return 1 + self.bonus(prov.owner, "wool")
        return 1

    def _tax_growth(self, tag):
        growth = TAX_GROWTH[self.countries[tag].tax]
        if growth < 0:
            return growth * max(0.0, 1 - self.bonus(tag, "tax_relief"))
        return growth

    @staticmethod
    def _staffing(prov, key):
        need = BUILDINGS[key].needs_burghers * prov.level(key)
        return 1.0 if need <= 0 else min(1.0, prov.burghers / need)

    @staticmethod
    def _inputs(prov, key):
        inputs = dict(BUILDINGS[key].inputs)
        if key == "weaver" and prov.market and prov.market.price["cotton"] < prov.market.price["wool"] * 1.2 \
                and prov.market.supply.get("cotton", 0) > prov.market.supply.get("wool", 0):
            inputs = {"cotton": inputs.pop("wool")}
        return inputs

    @staticmethod
    def _split_food(market):
        want = market.demand["grain"]          # all food demand was booked as grain
        grain, fish = market.supply["grain"], market.supply["fish"]
        if grain + fish > 0:
            market.demand["fish"] = want * fish / (grain + fish)
            market.demand["grain"] = want - market.demand["fish"]

    @staticmethod
    def _set_prices(market):
        for g, good in GOODS.items():
            if good.kind == "money":
                market.price[g] = good.price
                continue
            ratio = (market.demand[g] + 0.5) / (market.supply[g] + 0.5)
            market.price[g] = good.price * max(PRICE_FLOOR, min(PRICE_CAP, ratio ** ELASTICITY))

    def food_market(self, unit):
        """Where a troop buys its food: the market of the province it stands in, else its capital's."""
        prov = self.provinces.get(unit.pos)
        if prov and prov.market and prov.controller == unit.owner:
            return prov.market
        capital = self.provinces.get(self.countries[unit.owner].capital)
        return capital.market if capital else None

    def _merchants_trade(self, route):
        """Each merchant carries the good it was ordered to, profit or loss."""
        route.results = []
        for tag, g, src_name in route.orders:
            src = route.a if route.a.name == src_name else route.b
            dst = route.other(src)
            amount = min(MERCHANT_CAPACITY, max(0.0, src.supply[g] - src.demand[g] * 0.5))
            margin = dst.price[g] - src.price[g] - self.route_cost(route)
            if amount > 0:
                src.supply[g] -= amount
                src.exports[g] += amount
                dst.supply[g] += amount
                dst.imports[g] += amount
            route.results.append((tag, g, amount, amount * margin))

    def _trade(self, route):
        capacity = self.route_capacity(route)
        cost = self.route_cost(route)
        offers = []
        for g, good in GOODS.items():
            if good.kind == "money":
                continue
            for src, dst in ((route.a, route.b), (route.b, route.a)):
                margin = dst.price[g] - src.price[g] - cost
                if margin > 0:
                    offers.append((margin, g, src, dst))
        offers.sort(key=lambda o: -o[0])
        route.flows, route.profit = [], 0.0
        left = capacity
        for margin, g, src, dst in offers:
            if left <= 0.05:
                break
            amount = min(left, max(0.0, src.supply[g] - src.demand[g] * 0.7),
                         max(0.0, dst.demand[g] - dst.supply[g] * 0.7))
            if amount < 0.05:
                continue
            src.supply[g] -= amount
            src.exports[g] += amount
            dst.supply[g] += amount
            dst.imports[g] += amount
            route.flows.append((g, amount, src, dst))
            route.profit += amount * margin
            left -= amount

    def _incomes(self, profits):
        trade = {}
        for route in self.routes:
            for tag, g, amount, profit in route.results:
                trade[tag] = trade.get(tag, 0) + profit
            if route.profit <= 0:
                continue
            for market in (route.a, route.b):
                owner = self.market_owner(market)
                if owner:
                    trade[owner] = trade.get(owner, 0) + route.profit * TOLL_SHARE * (1 + self.bonus(owner, "tolls"))
        food = {}
        for unit in self.units:
            if unit.kind.war and unit.carrier is None:
                market = self.food_market(unit)
                price = market.price["grain"] if market else 1.5
                food[unit.owner] = food.get(unit.owner, 0) + FOOD_PER_TROOP * price
        for tag, country in self.countries.items():
            if not country.alive:
                continue
            rate = TAX_LEVELS[country.tax] + (self.bonus(tag, "high_tax") if country.tax == "high" else 0)
            production = pop_tax = upkeep = colonies = 0.0
            for prov in self.provinces_of(tag):
                if prov.controller != tag:
                    continue
                market = prov.market
                if market and prov.good:
                    money = 1 + self.bonus(tag, "money_value") if GOODS[prov.good].kind == "money" else 1
                    prov.value = prov.output * market.price[prov.good] * money
                    production += prov.value * (PRODUCTION_TAX + self.bonus(tag, "production_tax")) * rate
                everyday = market.satisfaction("cloth") if market else 0.5
                pop_tax += rate * (prov.peasants * PEASANT_TAX + prov.burghers * BURGHER_TAX * (1 + self.bonus(tag, "burgher_tax")) *
                                   (0.5 + 0.5 * everyday) * (1 + 0.15 * prov.level("marketplace"))) * \
                    (1 + SETTLEMENT_TAX[prov.settlement])
                for key, level in prov.buildings.items():
                    upkeep += BUILDINGS[key].upkeep * level
                upkeep += WORKS_UPKEEP * prov.works + SETTLEMENT_UPKEEP[prov.settlement] + CASTLE_UPKEEP[prov.castle]
                if prov.colony:
                    colonies += COLONY_UPKEEP * (1 + self.bonus(tag, "colony_upkeep"))
            units = sum(u.kind.upkeep for u in self.units_of(tag)) + food.get(tag, 0.0)
            country.income = {"production": production, "taxes": pop_tax, "buildings": profits.get(tag, 0.0),
                              "trade": trade.get(tag, 0.0), "upkeep": -upkeep, "military": -units,
                              "colonies": -colonies}
            if country.treasury < 0:
                country.income["interest"] = country.treasury * 0.02

    def collect(self):
        for country in self.countries.values():
            if country.alive:
                country.treasury += country.balance

    def grow(self):
        """Population growth, colonies, native raids, building queues."""
        for prov in self.provinces.values():
            if prov.owner is None:
                prov.natives *= 1.0005
                continue
            food = prov.market.food_satisfaction() if prov.market else 0.8
            prov.food = food
            rate = BASE_GROWTH + self._tax_growth(prov.owner) + min(0.0, food - 0.9) * 0.05
            if prov.colony:
                rate += COLONY_GROWTH * (1 + self.bonus(prov.owner, "colony_growth"))
                prov.peasants += 0.04       # settlers keep arriving from home
            prov.peasants *= 1 + rate
            prov.nobles *= 1 + rate * 0.5
            jobs = sum(BUILDINGS[k].needs_burghers * prov.level(k) for k in MANUFACTORIES) + \
                3 * prov.level("marketplace")
            if prov.burghers < jobs and prov.peasants > 2:
                moving = min(prov.peasants * 0.006, jobs - prov.burghers)
                prov.peasants -= moving
                prov.burghers += moving
            prov.burghers *= 1 + rate * (1 + self.bonus(prov.owner, "burgher_growth"))
            if prov.natives > 0:
                if prov.colony or prov.trading_post:
                    settled = prov.natives * 0.01
                    prov.natives -= settled
                    prov.peasants += settled * 0.5
                if prov.colony and prov.natives > prov.peasants * 2 and self.rng.random() < NATIVE_RAID_CHANCE:
                    prov.peasants *= 0.8
                    self.message(f"Natives raided the colony at {prov.name}!", prov.owner)
            if prov.colony and prov.pop >= COLONY_DONE:
                prov.colony = False
                self.message(f"{prov.name} has grown into a full province.", prov.owner)
            for item in list(prov.queue):
                item[1] -= 1
                if item[1] <= 0:
                    prov.queue.remove(item)
                    if item[0] == "settlement":
                        prov.settlement += 1
                        self.message(f"{prov.name} has grown into a {SETTLEMENTS[prov.settlement].lower()}.", prov.owner)
                    elif item[0] == "castle":
                        prov.castle += 1
                        prov.garrison = prov.castle * GARRISON_HP
                        self._castle_list = None
                        self.message(f"{prov.name}: the {CASTLES[prov.castle].lower()} is finished.", prov.owner)
                    else:
                        prov.buildings[item[0]] = prov.level(item[0]) + 1
                        self.message(f"{prov.name}: {self.building_name(prov, item[0])} finished.", prov.owner)
                    self.changed()
                    if item[0] == "marketplace":
                        self.refresh_markets()

    # ----- building -----------------------------------------------------------------
    def building_name(self, prov, key):
        if key == "settlement":
            return SETTLEMENTS[min(3, prov.settlement + 1)]
        if key == "castle":
            return CASTLES[min(3, prov.castle + 1)]
        return BUILDINGS[key].name

    def works_name(self, prov, level=None):
        level = prov.works if level is None else level
        if not prov.good or prov.good not in WORKS or level <= 0:
            return ""
        return WORKS[prov.good][level - 1]

    def slots_used(self, prov):
        built = sum(1 for v in prov.buildings.values() if v)
        return built + sum(1 for item in prov.queue if item[0] in BUILDINGS and not prov.level(item[0]))

    def goods_price(self, prov, goods):
        """What these goods cost on the province's market (ducats)."""
        market = prov.market
        return sum(n * (market.price[g] if market else GOODS[g].price * 1.5) for g, n in goods.items())

    @staticmethod
    def _buy(prov, goods):
        """Book the goods as a purchase on the local market (it shows up in next season's demand)."""
        if prov.market:
            for g, n in goods.items():
                prov.market.pending[g] = prov.market.pending.get(g, 0) + n

    def build_goods(self, prov, key):
        if key == "settlement":
            return SETTLEMENT_GOODS[min(3, prov.settlement + 1)]
        if key == "castle":
            return CASTLE_GOODS[min(3, prov.castle + 1)]
        return {}

    def build_cost(self, prov, key):
        if key == "settlement":
            base = SETTLEMENT_COST[min(3, prov.settlement + 1)]
        elif key == "castle":
            base = CASTLE_COST[min(3, prov.castle + 1)] * (1 + self.bonus(prov.owner, "castle_cost"))
        else:
            return BUILDINGS[key].cost * (prov.level(key) + 1)
        return round(base + self.goods_price(prov, self.build_goods(prov, key)))

    def _job_check(self, tag, prov):
        if prov.owner != tag:
            return False, "Not your province"
        if prov.controller != tag:
            return False, "The province is occupied"
        if prov.busy:
            return False, "This province already did its job this season"
        return True, ""

    def build_check(self, tag, prov, key):
        ok, reason = self._job_check(tag, prov)
        if not ok:
            return ok, reason
        if prov.queue:
            return False, "Something is already under construction here"
        if key == "settlement":
            nxt = prov.settlement + 1
            if nxt > 3:
                return False, "Already a city"
            if prov.pop < SETTLEMENT_POP[nxt]:
                return False, f"A {SETTLEMENTS[nxt].lower()} needs {SETTLEMENT_POP[nxt]}k people (has {prov.pop:.0f}k)"
        elif key == "castle":
            if prov.castle >= 3:
                return False, "Already a large castle"
            if prov.castle >= self.castle_top(tag):
                return False, "A large castle needs the Trace italienne tech"
            if prov.colony and prov.castle >= 1:
                return False, "Young colonies can only build a tower"
        else:
            b = BUILDINGS[key]
            level = prov.level(key)
            if level >= self.building_max(tag, key):
                return False, "Already at the highest level"
            if key in BUILDING_TECH and not self.has(tag, BUILDING_TECH[key][0]):
                return False, f"Needs the {tech.tech(BUILDING_TECH[key][1]).name} tech"
            if key == "university" and prov.settlement < 3:
                return False, "Universities need a city"
            if b.needs_coast and not prov.coastal:
                return False, "Needs a coastal province"
            if key == "shipyard" and not prov.level("port"):
                return False, "Build a port first"
            if not level and self.slots_used(prov) >= SETTLEMENT_SLOTS[prov.settlement]:
                if not prov.settlement:
                    return False, "Needs a village (or bigger) first"
                return False, (f"No free building slots ({SETTLEMENT_SLOTS[prov.settlement]} in a "
                               f"{SETTLEMENTS[prov.settlement].lower()})")
            if b.needs_burghers and prov.burghers < b.needs_burghers * (level + 1) * 0.5:
                return False, f"Needs about {b.needs_burghers * (level + 1):.0f}k burghers to staff it"
            if prov.colony and key not in ("port", "marketplace"):
                return False, "Colonies can only build ports and marketplaces"
        cost = self.build_cost(prov, key)
        if self.countries[tag].treasury < cost:
            return False, f"Costs {cost} ducats"
        return True, ""

    def build(self, tag, prov, key):
        if not self.build_check(tag, prov, key)[0]:
            return False
        self.countries[tag].treasury -= self.build_cost(prov, key)
        self._buy(prov, self.build_goods(prov, key))
        prov.queue.append([key, BUILD_TURNS])
        prov.busy = True
        self.message(f"{prov.name}: started {_with_article(self.building_name(prov, key))} "
                     f"(ready in {BUILD_TURNS} seasons).", tag)
        return True

    # ----- province investment: raise a goods tile one level, from the province panel ------------
    def invest_goods(self, prov):
        return dict(WORKS_GOODS[prov.works]) if prov.works < WORKS_LEVELS else {}

    def invest_cost(self, prov):
        """Ducats for the next level: a fee plus the goods it needs, at local prices."""
        if prov.works >= WORKS_LEVELS:
            return 0
        cost = WORKS_COST[prov.works] + self.goods_price(prov, self.invest_goods(prov))
        if prov.good in FARM_GOODS:
            cost *= 1 + self.bonus(prov.owner, "farm_invest")
        return round(cost)

    def invest_check(self, tag, prov):
        ok, reason = self._job_check(tag, prov)
        if not ok:
            return ok, reason
        if not prov.good or prov.good not in WORKS:
            return False, "Nothing to develop here"
        if prov.works >= WORKS_LEVELS:
            return False, f"Fully developed ({self.works_name(prov)})"
        era = WORKS_ERA[prov.works]
        if self.countries[tag].era < era:
            return False, f"The next level needs the {_ERAS[era][0]}"
        if prov.good in PLANTATION_GOODS and prov.works >= 2 and not self.has(tag, "plantations"):
            return False, "Plantation levels 3 and up need the Plantations tech"
        if prov.colony and prov.works >= 2:
            return False, "Young colonies can only reach level 2"
        cost = self.invest_cost(prov)
        if self.countries[tag].treasury < cost:
            return False, f"Costs {cost} ducats"
        return True, ""

    def invest(self, tag, prov):
        if not self.invest_check(tag, prov)[0]:
            return False
        self.countries[tag].treasury -= self.invest_cost(prov)
        self._buy(prov, self.invest_goods(prov))
        prov.works += 1
        prov.busy = True
        self.message(f"{prov.name}: upgraded to {self.works_name(prov).lower()} "
                     f"(+{WORKS_BONUS * prov.works * 100:.0f}% {GOODS[prov.good].name.lower()}).", tag)
        self.changed()
        return True

    # ----- units --------------------------------------------------------------------
    def unit_cost(self, prov, kind):
        market = prov.market
        goods = dict(kind.goods)
        if kind.naval and prov.level("shipyard") and "timber" in goods:
            goods["timber"] *= 0.7
        price = sum(n * (market.price[g] if market else GOODS[g].price * 1.5) for g, n in goods.items())
        gold = kind.gold * (1 + self.bonus(prov.owner, "cavalry_cost")) if kind.branch == "cavalry" else kind.gold
        return round(gold + price)

    def raise_options(self, tag):
        era = self.countries[tag].era
        return [troop(b, era) for b in BRANCHES] + [GENERAL, WAGON, SCOUT, COLONIST, CARAVEL, CARRACK, GALLEON]

    def stack_limit(self, tag, units=()):
        limit = STACK_BASE + self.bonus(tag, "stack")
        if any(u.kind is GENERAL for u in units):
            limit += GENERAL_STACK + self.bonus(tag, "general_stack")
        return int(limit)

    def can_stand(self, group, pos, others=None):
        """Whether these units (all of one owner) may end their move together on pos."""
        owner = group[0].owner
        if others is None:
            others = [u for u in self.units_at(pos) if u not in group]
        if any(u.owner != owner for u in others):
            return False
        if group[0].naval:
            return True
        everyone = others + list(group)
        war = sum(1 for u in everyone if u.kind.war)
        generals = sum(1 for u in everyone if u.kind is GENERAL)
        civilians = len(everyone) - war - generals
        return war <= self.stack_limit(owner, everyone) and civilians <= CIVILIAN_LIMIT and generals <= 1

    def recruit_check(self, tag, prov, kind):
        ok, reason = self._job_check(tag, prov)
        if not ok:
            return ok, reason
        country = self.countries[tag]
        if kind.war and kind.era != country.era:
            return False, "Your armies have moved on to newer troops"
        if kind.needs == "town" and prov.settlement < 2 and not prov.level("foundry"):
            return False, "Cannons are cast in towns and cities (or anywhere with a foundry)"
        if kind is GENERAL:
            if prov.pos != country.capital:
                return False, "Generals are appointed in your capital"
            generals = sum(1 for u in self.units_of(tag) if u.kind is GENERAL)
            if generals >= 1 + len(self.provinces_of(tag)) // 20:
                return False, "Your country cannot support more generals"
        cost = self.unit_cost(prov, kind)
        if country.treasury < cost:
            return False, f"Costs {cost} ducats"
        if kind.naval:
            if kind is CARRACK and not self.has(tag, "carrack"):
                return False, "Carracks need the Carrack tech"
            if kind is GALLEON and not self.has(tag, "galleon"):
                return False, "Galleons need the Galleon tech"
            if not prov.level("port"):
                return False, "Needs a port"
            if kind in (CARRACK, GALLEON) and not prov.level("shipyard"):
                return False, f"{kind.name}s need a shipyard"
            if not any(self.is_sea(n) and all(u.owner == tag for u in self.units_at(n)) for n in neighbors(prov.pos)):
                return False, "No free sea next to the port"
        elif self._land_spot(tag, prov, kind) is None:
            return False, "No room here or next door (stacks are full)"
        if kind is COLONIST and prov.peasants < 3:
            return False, "Needs at least 3k peasants to send settlers"
        if kind.war and prov.peasants < self.men_per_troop(tag) + 2:
            return False, "Not enough men left here (each troop takes 1,000 peasants)"
        return True, ""

    def recruit(self, tag, prov, kind):
        if not self.recruit_check(tag, prov, kind)[0]:
            return None
        cost = self.unit_cost(prov, kind)
        self.countries[tag].treasury -= cost
        prov.busy = True
        if prov.market:
            for g, n in kind.goods.items():
                prov.market.pending[g] = prov.market.pending.get(g, 0) + n
        if kind is COLONIST:
            prov.peasants -= COLONIST_PEOPLE
        if kind.war:
            prov.peasants -= self.men_per_troop(tag)
        if kind.naval:
            pos = next(n for n in neighbors(prov.pos) if self.is_sea(n) and all(u.owner == tag for u in self.units_at(n)))
        else:
            pos = self._land_spot(tag, prov, kind)
        unit = self._add_unit(kind, tag, pos)
        if kind is WAGON:
            unit.supplies = self.wagon_seasons(tag)
        self.message(f"{prov.name}: raised {kind.name.lower()} for {cost} ducats.", tag)
        self.see_from(unit)
        return unit

    def _land_spot(self, tag, prov, kind):
        """Where a new land unit appears: the province itself, or a province of ours next to it with room."""
        probe = Unit(0, kind, tag, prov.pos, hp=kind.hp)
        for pos in [prov.pos] + sorted(neighbors(prov.pos)):
            other = self.provinces.get(pos)
            if other and other.owner == tag and self.can_stand([probe], pos):
                return pos
        return None

    # ----- refits, drill and research ---------------------------------------------------
    def refit_check(self, unit):
        country = self.countries[unit.owner]
        if not unit.kind.war or unit.kind.era >= country.era:
            return False, "Already the newest kind"
        prov = self.provinces.get(unit.pos)
        if unit.carrier or not prov or prov.owner != unit.owner or (prov.settlement < 2 and not prov.level("barracks")
                                                                      and not prov.level("foundry")):
            return False, "Refit in one of your towns or cities"
        if unit.moves_left <= 0 or unit.upgraded:
            return False, "No time left this season"
        new = troop(unit.kind.branch, country.era)
        cost = self.unit_cost(prov, new) // 2
        if country.treasury < cost:
            return False, f"Costs {cost} ducats"
        return True, ""

    def refit(self, unit):
        if not self.refit_check(unit)[0]:
            return False
        country = self.countries[unit.owner]
        prov = self.provinces[unit.pos]
        new = troop(unit.kind.branch, country.era)
        country.treasury -= self.unit_cost(prov, new) // 2
        unit.kind, unit.hp = new, new.hp
        unit.moves_left, unit.upgraded = 0, True
        self.message(f"{prov.name}: refitted as {new.name.lower()}.", unit.owner)
        return True

    def upgrade_cost(self, unit, stat):
        gold, goods = UPGRADE_COST[stat]
        prov = self.provinces.get(unit.pos)
        market = prov.market if prov else None
        if unit.kind.branch == "artillery":
            goods = {"tools": 1.0} if stat == "attack" else {"iron": 2.5}
        return round(gold * (1 + (unit.atk_up if stat == "attack" else unit.def_up)) +
                     sum(n * (market.price[g] if market else GOODS[g].price) for g, n in goods.items()))

    def upgrade_check(self, unit, stat):
        if not unit.kind.war:
            return False, "Only troops can be drilled"
        prov = self.provinces.get(unit.pos)
        need = "foundry" if unit.kind.branch == "artillery" else "barracks"
        if unit.carrier or not prov or prov.owner != unit.owner or not prov.level(need):
            return False, f"Needs to stand in your province with a {need}"
        if (unit.atk_up if stat == "attack" else unit.def_up) >= self.drill_max(unit.owner):
            return False, f"{stat.title()} is fully drilled"
        if unit.moves_left <= 0 or unit.upgraded:
            return False, "No time left this season"
        cost = self.upgrade_cost(unit, stat)
        if self.countries[unit.owner].treasury < cost:
            return False, f"Costs {cost} ducats"
        return True, ""

    def upgrade(self, unit, stat):
        if not self.upgrade_check(unit, stat)[0]:
            return False
        self.countries[unit.owner].treasury -= self.upgrade_cost(unit, stat)
        if stat == "attack":
            unit.atk_up += 1
        else:
            unit.def_up += 1
        unit.moves_left, unit.upgraded = 0, True
        return True

    # ----- technology: research, ideas and the effects they give ---------------------------
    def has(self, tag, flag):
        """Whether a country has an unlock flag (a tech or idea whose effect is 1)."""
        return bool(self.bonus(tag, flag))

    def bonus(self, tag, key):
        """A country's summed effect for `key` (see tech.EFFECT_KEYS). 0 when it has none."""
        return self._effects(tag).get(key, 0)

    def _effects(self, tag):
        cache = self._bonus_cache
        if tag not in cache:
            country = getattr(self, "countries", {}).get(tag)
            if country is None:
                return {}
            cache[tag] = tech.effects(country.techs - {country.national}, country.ideas, country.national)
        return cache[tag]

    def _tech_changed(self, tag):
        self._bonus_cache.pop(tag, None)

    @staticmethod
    def _route_effects(effects):
        return any(key in ROUTE_KEYS for key in effects)

    @staticmethod
    def _idea(key):
        if key in tech.IDEAS:
            return tech.IDEAS[key]
        return next((i for lst in tech.NATIONAL_IDEAS.values() for i in lst if i.key == key), None)

    def grant_tech(self, tag, key):
        """Add a tech to what a country knows. Cartography explores its trade coasts; route effects redraw markets."""
        country = self.countries[tag]
        if key in country.techs:
            return
        country.techs.add(key)
        self._tech_changed(tag)
        if key == "cartography":
            self._cartography(tag)
        t = tech.tech(key)
        if t is not None and self._route_effects(t.effects):
            self.refresh_markets()

    def pick_idea(self, tag, idea_key):
        """Adopt one of the idea cards offered at the last age. The other cards are dropped."""
        country = self.countries[tag]
        idea = self._idea(idea_key)
        if idea is None or idea_key not in country.pending_ideas:
            return False
        country.ideas.add(idea_key)
        country.pending_ideas = []
        self._tech_changed(tag)
        if self._route_effects(idea.effects):
            self.refresh_markets()
        self.message(f"Idea adopted: {idea.name}. {idea.text}", tag)
        return True

    def fund_check(self, tag):
        """Funding is allowed once a year (every 4 seasons) and costs RESEARCH_FUND[0] ducats."""
        country = self.countries[tag]
        last = country.memory.get("funded_turn")
        if last is not None and self.turn - last < 4:
            return False, f"Funded already: again in {4 - (self.turn - last)} season(s)"
        if country.treasury < RESEARCH_FUND[0]:
            return False, f"Costs {RESEARCH_FUND[0]} ducats"
        return True, ""

    def fund_research(self, tag):
        """60 ducats buy 15 research points (more with the Fund effect) for the current tech, once a year."""
        gold, points = RESEARCH_FUND
        country = self.countries[tag]
        if not self.fund_check(tag)[0]:
            return False
        country.memory["funded_turn"] = self.turn
        country.treasury -= gold
        country.research += points * (1 + self.bonus(tag, "fund"))
        return True

    def next_era(self, tag):
        """(era, year it opens, era techs needed) for the next age, or None at the last one."""
        country = self.countries[tag]
        if country.era >= 3:
            return None
        era = country.era + 1
        return era, tech.ERA_YEARS[era], tech.ERA_GATE_TECHS

    def research_rate(self, tag):
        """Research points this season as (total, parts). The parts add up to the total."""
        country = self.countries[tag]
        mult = 1 + self.bonus(tag, "research")
        owned = self.provinces_of(tag)
        burghers = sum(p.burghers for p in owned)
        universities = sum(1 for p in owned if p.level("university"))
        capital = self.provinces.get(country.capital)
        coffee = self.bonus(tag, "coffee_research")
        share = capital.market.satisfaction("coffee") if coffee and capital and capital.market else 0.0
        total = tech.research_points(RESEARCH_BASE, burghers, universities, share,
                                     {"research": self.bonus(tag, "research"), "coffee_research": coffee})
        parts = {"base": RESEARCH_BASE * mult, "burghers": burghers / 40 * mult, "universities": universities * mult,
                 "coffee": share * burghers / 40 * 0.25 * coffee * mult, "funding": 0.0}
        return total, parts

    def tech_cost(self, tag, key):
        """Research points a tech costs this country. Each neighbour on its markets that knows it makes it cheaper."""
        if key not in tech.TECHS:
            return 0
        bonuses = {"diffusion_cap": self.bonus(tag, "diffusion_cap"), "nav_cost": self.bonus(tag, "nav_cost")}
        return tech.cost(key, self._know_nearby(tag, key), bonuses)

    def _know_nearby(self, tag, key):
        """Living countries owning provinces on the markets this country trades in, that know `key`."""
        owners = {p.owner for m in self.merchant_markets(tag) for p in m.provinces}
        owners.discard(None)
        owners.discard(tag)
        return sum(1 for o in owners if self.countries[o].alive and key in self.countries[o].techs)

    def set_research(self, tag, key):
        """Research `key` next: its unknown prerequisites first, then it. The rest of that path becomes the queue."""
        country = self.countries[tag]
        t = tech.TECHS.get(key)
        if t is None or key in country.techs or t.era > country.era:
            return False
        path = tech.path_to(key, country.techs)
        if not path:
            return False
        country.researching = path[0]
        country.queue = path[1:]
        return True

    def unqueue(self, tag, key):
        queue = self.countries[tag].queue
        if key not in queue:
            return False
        queue.remove(key)
        return True

    def _research(self):
        for tag, country in self.countries.items():
            if not country.alive:
                continue
            rate = self.research_rate(tag)[0]
            country.research += rate
            self._finish_research(tag)
            if not country.researching:            # nothing chosen: points don't pile up for later
                country.research = min(country.research, 2 * rate)
            if tech.era_ready(country.era, self.year(), country.techs):
                self._new_age(tag)

    def _finish_research(self, tag):
        """Spend the research points on the current tech, then the next in the queue, while they last."""
        country = self.countries[tag]
        if country.researching in country.techs:
            country.researching = ""
        if not country.researching and not self._advance(tag):
            return
        while country.researching:
            key = country.researching
            cost = self.tech_cost(tag, key)
            if country.research < cost:
                return
            country.research -= cost
            self.grant_tech(tag, key)
            t = tech.TECHS[key]
            self.message(f"Researched {t.name}: {t.text}", tag)
            if not self._advance(tag) and tag == self.player:
                self.message("Pick new research (T).", tag)

    def _advance(self, tag):
        """Start the next queued tech that is still to learn. False when nothing is left in the queue."""
        country = self.countries[tag]
        country.researching = ""
        while country.queue:
            key = country.queue.pop(0)
            t = tech.TECHS.get(key)
            if t is not None and key not in country.techs and t.era <= country.era:
                country.researching = key
                return True
        return False

    def _new_age(self, tag):
        """The country reaches the next age: its troops change, and it is offered three idea cards."""
        country = self.countries[tag]
        country.era += 1
        names = ", ".join(troop(b, country.era).name.lower() for b in BRANCHES)
        self.message(f"{ERAS[country.era][0]}: you can now raise {names}. Refit old troops in your towns.", tag)
        counts = {b: sum(1 for k in country.techs if k in tech.TECHS and tech.TECHS[k].branch == b)
                  for b in tech.BRANCHES}
        country.pending_ideas = [i.key for i in tech.draw_ideas(tag, counts, set(country.ideas), self.rng)]

    def _cheapest_available(self, tag):
        country = self.countries[tag]
        options = tech.available(country.techs, country.era)
        return min(options, key=lambda k: (tech.TECHS[k].cost, k), default="")

    def _know_region(self, tag):
        """The regional default tech's region, from the capital's position. Random worlds use 'default'."""
        if self.map == "random":
            return "default"
        lon, lat = geo.lonlat(self.countries[tag].capital)
        if 6 < lon < 19 and 37 < lat < 47.5:
            return "italian"
        if 5 < lon < 17 and 47 <= lat < 55:
            return "german"
        if lat < 37.5 and lon < 33 and lat > 20:
            return "north_african"
        return "default"

    def _start_techs(self):
        """Each country's national tech, its starting techs and its first research (build spec, start of game)."""
        big = BIG_EMPIRE
        for tag, country in self.countries.items():
            nat = tech.national_tech(tag, self._know_region(tag))
            owned = self.provinces_of(tag)
            known = {nat.key, *nat.also_knows}
            if self.colonial.get(tag, 999) <= 0:
                known.update(("portolan", "astrolabe"))
            if any(p.coastal for p in owned):
                known.add("portolan")
            if len(owned) >= big:
                known.add("drill_yards")
            country.national = nat.key
            country.techs = known
            self._tech_changed(tag)
            country.researching = self._cheapest_available(tag)

    def _legacy_techs(self, country):
        """An old save's country: its national tech, and the cheapest gate techs of each age below its own."""
        nat = tech.national_tech(country.tag, self._know_region(country.tag))
        country.national = nat.key
        known = {nat.key, *nat.also_knows}
        for era in range(1, country.era):
            gate = sorted((t for t in tech.TECHS.values() if t.era == era), key=lambda t: (t.cost, t.key))
            for t in gate[:tech.ERA_GATE_TECHS]:
                known.update(tech.path_to(t.key, known))
        country.techs = known
        self._tech_changed(country.tag)
        country.researching = self._cheapest_available(country.tag)

    def _cartography(self, tag):
        """Explore the coast and sea around every market this country trades through."""
        self.ensure_markets()
        mine = self.merchant_markets(tag)
        centres = set()
        for route in self.routes:
            if route.a in mine or route.b in mine:
                centres.update((route.a.center, route.b.center))
        centres.discard(None)
        explored = self.countries[tag].explored
        for centre in centres:
            for pos in within(centre, SCALE):
                prov = self.provinces.get(pos)
                if pos in self.terrain and (self.is_sea(pos) or (prov and prov.coastal)):
                    explored.add(pos)
        if tag == self.player:
            self.changed()
            self.update_visibility()

    # ----- supply ------------------------------------------------------------------
    def supply_limit(self, tag, pos):
        prov = self.provinces.get(pos)
        if not prov:
            return 0
        limit = SUPPLY_BASE + prov.pop / SUPPLY_PER_PEOPLE + \
            (prov.works * SUPPLY_PER_FARM if prov.good in FARM_GOODS else 0) + (prov.natives / 20)
        if self.is_depot(tag, pos):
            limit += self.bonus(tag, "depot_supply")
        if prov.owner != tag:
            limit *= FOREIGN_SUPPLY
        return max(1, int(limit))

    def is_depot(self, tag, pos):
        prov = self.provinces.get(pos)
        return bool(prov and prov.owner == tag and prov.controller == tag and
                    (prov.settlement >= 2 or prov.castle or prov.level("port")))

    def in_supply(self, tag, pos):
        """Within SUPPLY_RANGE hexes of a depot, through land we control and no enemy armies."""
        enemies = self.enemies(tag)
        blocked = {u.pos for u in self.units if u.owner in enemies and u.kind.war and u.carrier is None}
        seen, frontier = {pos}, [pos]
        for _ in range(self.supply_reach(tag) + 1):
            nxt = []
            for p in frontier:
                if self.is_depot(tag, p):
                    return True
                for n in neighbors(p):
                    prov = self.provinces.get(n)
                    if n in seen or not prov or prov.controller != tag or n in blocked:
                        continue
                    seen.add(n)
                    nxt.append(n)
            frontier = nxt
        return False

    def supply_state(self, group):
        """('supplied' | 'wagon' | 'foraging' | 'cut off', troops, limit) for a stack."""
        lead = group[0]
        troops = [u for u in group if u.kind.war]
        limit = self.supply_limit(lead.owner, lead.pos)
        prov = self.provinces.get(lead.pos)
        if self.in_supply(lead.owner, lead.pos):
            state = "supplied"
        elif any(u.kind is WAGON and u.supplies > 0 for u in group):
            state = "wagon"
        elif prov and prov.foraged == (lead.owner, self.turn):
            state = "foraging"
        else:
            state = "cut off"
        return state, len(troops), limit

    def forage_check(self, group, tag=None, end_of_round=False):
        troops = [u for u in group if u.kind.war]
        if tag is not None and any(u.owner != tag for u in troops):
            return False, "Only your own troops can forage"
        if not troops:
            return False, "Only troops forage"
        lead = troops[0]
        prov = self.provinces.get(lead.pos)
        if not prov or prov.owner == lead.owner:
            return False, "Armies only forage in foreign land"
        if prov.foraged == (lead.owner, self.turn):
            return False, "Already foraged here this season"
        if not end_of_round and min(u.moves_left for u in troops) <= 0:
            return False, "No time left this season"
        return True, ""

    def forage(self, group, tag=None, end_of_round=False):
        if not self.forage_check(group, tag, end_of_round)[0]:
            return False
        troops = [u for u in group if u.kind.war]
        prov = self.provinces[troops[0].pos]
        prov.foraged = (troops[0].owner, self.turn)
        prov.peasants *= 1 - FORAGE_LOSS
        prov.natives *= 1 - FORAGE_LOSS
        if not end_of_round:
            for unit in troops:
                unit.moves_left = 0
        self.message(f"Troops foraged around {prov.name}: they eat, the province suffers.", troops[0].owner)
        return True

    def logistics(self):
        """Once per season: feed every stack, or make it suffer attrition."""
        stacks = {}
        for unit in self.units:
            if unit.carrier is None and not unit.naval:
                stacks.setdefault((unit.pos, unit.owner), []).append(unit)
        reported = set()
        for (pos, tag), group in stacks.items():
            troops = [u for u in group if u.kind.war]
            if not troops:
                continue
            prov = self.provinces.get(pos)
            if tag != self.player and prov and prov.owner != tag and not self.in_supply(tag, pos) and \
                    not any(u.kind is WAGON and u.supplies > 0 for u in group):
                self.forage(group, end_of_round=True)   # computer armies forage when they must, moves or not
            state, count, limit = self.supply_state(group)
            for wagon in [u for u in group if u.kind is WAGON]:
                if state == "supplied":
                    wagon.supplies = self.wagon_seasons(tag)
                elif state == "wagon" and wagon.supplies > 0:
                    wagon.supplies -= 1
                    break
            fed = state != "cut off"
            hurt = 0
            for unit in troops:
                unit.supplied = fed
                loss = (0 if fed else ATTRITION) + (ATTRITION if count > limit else 0)
                if loss:
                    unit.hp -= loss
                    hurt += 1
                    if unit.hp <= 0:
                        self._kill(unit)
            if hurt and tag == self.player and pos not in reported:
                reported.add(pos)
                why = "cut off from supply" if not fed else f"too many troops for the land ({count}/{limit})"
                where = prov.name if prov else "the field"
                self.message(f"Your troops at {where} are {why}: they lose strength.")

    # ----- movement ------------------------------------------------------------------
    def may_enter(self, unit, pos):
        """Whether the unit may stand on `pos` (ignoring other units)."""
        if unit.naval:
            return self.is_sea(pos)
        prov = self.provinces.get(pos)
        if not prov:
            return False
        owner = prov.owner
        if owner in (None, unit.owner):
            return True
        return (unit.kind.war or unit.kind in (GENERAL, SCOUT)) and self.at_war(unit.owner, owner)

    def zoc(self, tag):
        """Hexes next to enemy castles: armies must stop when they walk into them."""
        enemies = self.enemies(tag)
        if not enemies:
            return set()
        found = set()
        for prov in self.castles():
            if prov.controller in enemies and prov.garrison > 0:
                found.update(neighbors(prov.pos))
        return found

    def castles(self):
        if self._castle_list is None:
            self._castle_list = [p for p in self.provinces.values() if p.castle and p.owner]
        return self._castle_list

    def stuck_reason(self, group):
        """Why a stack ordered to move cannot move this season, or "" if nothing in particular is in the way.
        A stack moves at its slowest unit's pace, so one unit with no moves left holds the whole stack back."""
        if min(u.moves_left for u in group) > 0:
            return ""
        lead = group[0]
        prov = self.provinces.get(lead.pos)
        if prov and prov.foraged == (lead.owner, self.turn):
            return "They foraged this season and have no moves left."
        fresh = [u for u in group if u.moves_left <= 0 and not u.acted and u.kind.moves > 0]
        if not fresh:
            return "They have already moved this season."
        names = " and ".join(sorted({u.kind.name for u in fresh}))
        if len(fresh) == 1:
            return f"{names} was raised this season and can't move yet. Untick it to move the rest."
        return f"{names} were raised this season and can't move yet. Untick them to move the rest."

    def reachable(self, unit):
        return self.reachable_group([unit])

    def reachable_group(self, group, best=None):
        """{pos: move cost} the stack can reach this season. `best` is a plan() over its moves, if one is at hand."""
        lead = group[0]
        moves = min(u.moves_left for u in group)
        if any(u.carrier for u in group):
            ship = lead.carrier
            if moves <= 0 or any(u.carrier is not ship for u in group):
                return {lead.pos: 0}
            reach = {lead.pos: 0}
            for n in neighbors(lead.pos):
                if all(self.may_enter(u, n) for u in group) and self.can_stand(group, n):
                    reach[n] = 1
            return reach
        naval = lead.naval
        occupied = self.owners_at()
        if best is None:
            best = self.plan(group, moves)
        costs = {p: c for p, (c, _) in best.items()}
        alone = self.can_stand(group, None, others=[])
        reach = {p: c for p, c in costs.items()
                 if p == lead.pos or (alone if p not in occupied else self.can_stand(group, p))}
        if not naval:
            for ship in self.units_of(lead.owner):
                if ship.naval and len(self.cargo(ship)) + len(group) <= ship.kind.capacity:
                    via = [costs[n] for n in neighbors(ship.pos) if n in costs]
                    if via and min(via) + 1 <= moves:
                        reach[ship.pos] = min(via) + 1
        return reach

    def plan(self, group, budget):
        """{pos: (cost, previous pos)} for this stack over `budget` move points, same rules as moving."""
        lead = group[0]
        naval = lead.naval
        zoc = set() if naval else self.zoc(lead.owner)
        occupied, mine = self.owners_at(), {lead.owner}
        best = {lead.pos: (0, None)}
        heap = [(0, lead.pos)]
        while heap:
            cost, pos = heapq.heappop(heap)
            if cost > best[pos][0]:
                continue
            if pos != lead.pos and pos in zoc:
                continue
            for n in neighbors(pos):
                if n not in self.terrain or not all(self.may_enter(u, n) for u in group):
                    continue
                if occupied.get(n, mine) != mine:
                    continue
                new = cost + (1 if naval else self.step_cost(pos, n))
                if new <= budget and new < best.get(n, (INF,))[0]:
                    best[n] = (new, pos)
                    heapq.heappush(heap, (new, n))
        return best

    def next_season_reach(self, group):
        """Hexes the stack could reach by the end of next season (but not this one)."""
        if any(u.carrier for u in group):
            return {}
        speed = min(self.unit_moves(u) for u in group)
        budget = min(u.moves_left for u in group) + speed
        occupied = self.owners_at()
        alone = self.can_stand(group, None, others=[])
        return {p: c for p, (c, _) in self.plan(group, budget).items()
                if (alone if p not in occupied else self.can_stand(group, p))}

    def path_to(self, group, goal, seasons=4):
        """[(pos, move cost so far)] from the stack to goal, or [] if it is too far or blocked."""
        speed = min(self.unit_moves(u) for u in group)
        best = self.plan(group, min(u.moves_left for u in group) + speed * (seasons - 1))
        if goal not in best:
            return []
        path = []
        pos = goal
        while pos is not None:
            path.append((pos, best[pos][0]))
            pos = best[pos][1]
        return path[::-1]

    def move(self, unit, dest):
        return self.move_group([unit], dest)

    def move_group(self, group, dest):
        group = [u for u in group if u in self.units]
        if self.over or not group:
            return False
        lead = group[0]
        if dest == lead.pos:
            return True
        best = None if any(u.carrier for u in group) else self.plan(group, min(u.moves_left for u in group))
        reach = self.reachable_group(group, best)
        if dest not in reach:
            return False
        ship = None
        if not lead.naval:
            ship = next((u for u in self.units_at(dest) if u.naval and u.owner == lead.owner
                         and len(self.cargo(u)) + len(group) <= u.kind.capacity), None)
        # Walk the route hex by hex, looking around on the way (so fog clears along it, not just at the end).
        path = self.route(group, dest, best)
        self.last_move = ([u.id for u in group], path)
        scout = max(group, key=lambda u: self.unit_sight(u))      # the stack sees as far as its best eyes
        for step in path[1:-1]:
            for unit in group:
                unit.pos = step
                for passenger in self.cargo(unit):
                    passenger.pos = step
            self.see_from(scout, refresh=False)
        for unit in group:
            unit.pos = path[0]
            for passenger in self.cargo(unit):
                passenger.pos = path[0]
        for unit in group:
            if ship:
                unit.carrier, unit.pos, unit.moves_left = ship, dest, 0
            elif unit.carrier:
                unit.carrier, unit.pos = None, dest
                unit.moves_left -= 1
            else:
                unit.moves_left -= reach[dest]
                unit.pos = dest
                for passenger in self.cargo(unit):
                    passenger.pos = dest
            unit.acted = True
        if not lead.naval and not ship and dest in self.zoc(lead.owner):
            for unit in group:
                unit.moves_left = 0
        country = self.countries[lead.owner]
        before = len(country.explored)
        for unit in group:
            self.see_from(unit, refresh=False)
        if lead.owner == self.player:
            if len(country.explored) != before:
                self.changed()
            self.update_visibility()
        return True

    def route(self, group, dest, best=None):
        """The hexes the stack walks through to reach dest this season, start and end included."""
        lead = group[0]
        if lead.carrier or distance(lead.pos, dest) <= 1:
            return [lead.pos, dest]
        if best is None:
            best = self.plan(group, min(u.moves_left for u in group))
        if dest not in best:                     # boarding a ship: walk to the shore next to it
            shore = [n for n in neighbors(dest) if n in best]
            if not shore:
                return [lead.pos, dest]
            last = min(shore, key=lambda n: best[n][0])
            return self.route(group, last, best) + [dest] if last != lead.pos else [lead.pos, dest]
        path, pos = [], dest
        while pos is not None:
            path.append(pos)
            pos = best[pos][1]
        return path[::-1]

    def cost_field(self, goal, naval=False, tag=None, until=None):
        """Move costs to `goal` from everywhere (or until every hex in `until` is settled)."""
        field = {goal: 0}
        heap = [(0, goal)]
        left = set(until) if until else None
        while heap:
            cost, pos = heapq.heappop(heap)
            if cost > field.get(pos, INF):
                continue
            if left is not None:
                left.discard(pos)
                if not left:
                    break
            for n in neighbors(pos):
                if naval:
                    ok, step = self.is_sea(n), 1
                else:
                    ok = self.is_land(n)
                    step = self.step_cost(n, pos) if ok and self.is_land(pos) else \
                        TERRAIN[self.terrain[n]].move if ok else 0
                if ok and cost + step < field.get(n, INF):
                    field[n] = cost + step
                    heapq.heappush(heap, (cost + step, n))
        return field

    def step_toward(self, unit, goal, field=None):
        return self.step_toward_group([unit], goal, field)

    def step_toward_group(self, group, goal, field=None):
        lead = group[0]
        reach = self.reachable_group(group)
        if field is None:
            # Only wait for hexes this field can settle: a land field never reaches the sea hex of a
            # friendly ship in `reach`, and waiting for it would search the whole map.
            settles = self.is_sea if lead.naval else self.is_land
            until = [p for p in reach if settles(p)] or [goal]
            field = self.cost_field(goal, lead.naval, until=until)
        options = [p for p in reach if p == lead.pos or not any(u.naval for u in self.units_at(p)) or lead.naval]
        return min(options, key=lambda p: (field.get(p, distance(p, goal) * 4 + 1000), reach[p]))

    # ----- colonies -------------------------------------------------------------------
    def found_check(self, unit, trading_post=False):
        if unit.kind is not COLONIST:
            return False, "Only colonists can found colonies"
        if unit.carrier:
            return False, "Land first"
        if unit.moves_left <= 0:
            return False, "No moves left this season"
        prov = self.provinces.get(unit.pos)
        if not prov or prov.owner is not None:
            return False, "Colonies need land nobody owns"
        if prov.terrain == "desert" and not prov.coastal:
            return False, "Nobody can live in the open desert"
        if not self.in_old_world(prov.pos) and not self.has(unit.owner, "atlantic"):
            return False, "Crossing the Atlantic needs the Astrolabe tech"
        if trading_post:
            if not prov.coastal:
                return False, "Trading posts must be on the coast"
            if prov.natives < 1.0:
                return False, "Trading posts need a native population to trade with"
        return True, ""

    def found(self, unit, trading_post=False):
        if not self.found_check(unit, trading_post)[0]:
            return None
        prov = self.provinces[unit.pos]
        prov.owner = prov.controller = unit.owner
        if trading_post:
            prov.trading_post = True
            prov.peasants = 0.2
            what = "trading post"
        else:
            prov.colony = True
            prov.peasants = COLONIST_PEOPLE
            prov.settlement = 1
            what = "colony"
        if prov.name.endswith(" lands") or prov.name.startswith("near "):
            prov.name = f"{('New ' + prov.tribe) if prov.tribe else prov.name}" if not prov.city else prov.name
        self.units.remove(unit)
        self.changed(ownership=True)
        self.refresh_markets()
        country = self.countries[unit.owner]
        self.message(f"{country.name} founded a {what} at {prov.name}.",
                     None if unit.owner == self.player or geo.lonlat(prov.pos)[0] < -20 else unit.owner)
        self.see_from(unit, radius=2 * SCALE)
        return prov

    # ----- war -----------------------------------------------------------------------------
    def at_war(self, a, b):
        return any({w.a, w.b} == {a, b} for w in self.wars)

    def enemies(self, tag):
        return {w.b if w.a == tag else w.a for w in self.wars if tag in (w.a, w.b)}

    def war_check(self, a, b):
        if a == b or not self.countries[b].alive:
            return False, "Not possible"
        if self.at_war(a, b):
            return False, "Already at war"
        if b not in self.neighbours_of(a):
            return False, "Only neighbours can go to war"
        return True, ""

    def declare_war(self, a, b):
        if not self.war_check(a, b)[0]:
            return False
        self.wars.append(War(a, b, self.turn))
        self.message(f"{self.countries[a].name} declared war on {self.countries[b].name}!",
                     None if self.player in (a, b) else "nobody")
        if self.player in (a, b):
            self.message(f"War: {self.countries[a].name} against {self.countries[b].name}.")
        return True

    def war_score(self, tag, enemy):
        taken = sum(1 for p in self.provinces_of(enemy) if p.controller == tag)
        lost = sum(1 for p in self.provinces_of(tag) if p.controller == enemy)
        capital = self.provinces[self.countries[enemy].capital].controller == tag
        return taken - lost + (3 if capital else 0)

    def peace(self, a, b, winner=None):
        """End the war. Each side keeps what it occupies if `winner` is None; otherwise only the winner gains."""
        self.wars = [w for w in self.wars if {w.a, w.b} != {a, b}]
        moved = 0
        for prov in list(self.provinces_of(a)) + list(self.provinces_of(b)):
            if prov.controller != prov.owner and prov.controller in (a, b):
                gainer = prov.controller
                if winner is None or gainer == winner:
                    if self.countries[prov.owner].capital == prov.pos:
                        prov.controller = prov.owner      # capitals return
                        continue
                    prov.owner = gainer
                    moved += 1
                prov.controller = prov.owner
                prov.siege = 0
        for unit in list(self.units):
            if unit.carrier is None and not unit.naval and unit.owner in (a, b):
                prov = self.provinces.get(unit.pos)
                if prov and prov.owner in (a, b) and prov.owner != unit.owner:
                    home = self.countries[unit.owner].capital
                    spot = self._free_spot_near(unit, home)
                    if spot:
                        unit.pos = spot
                    else:
                        self.units.remove(unit)
        self.changed(ownership=True)
        self.refresh_markets()
        names = f"{self.countries[a].name} and {self.countries[b].name}"
        self.message(f"Peace between {names}" + (f": {moved} provinces changed hands." if moved else "."),
                     None if self.player in (a, b) else "nobody")
        self._check_alive()

    def _free_spot_near(self, unit, pos):
        for r in range(8):
            for p in sorted(within(pos, r)):
                prov = self.provinces.get(p)
                if prov and prov.owner == unit.owner and self.can_stand([unit], p):
                    return p
        return None

    def peace_offer(self, tag, enemy, terms):
        """The player proposes peace. terms: 'take' (keep what you occupy), 'white' or 'yield'."""
        if not self.at_war(tag, enemy):
            return False, "Not at war"
        war = next(w for w in self.wars if {w.a, w.b} == {tag, enemy})
        score = self.war_score(tag, enemy)
        length = self.turn - war.start
        if terms == "yield":
            self.peace(tag, enemy, winner=enemy)
            return True, "They accept your surrender."
        if terms == "white":
            if score >= -1 and length >= 4:
                self.peace(tag, enemy, winner="nobody")
                return True, "White peace signed."
            return False, "They refuse: they are winning, or the war has only just started"
        if score >= 3 or (score >= 1 and self.army_strength(enemy) <= self.army_strength(tag)):
            self.peace(tag, enemy, winner=tag)
            return True, "They accept and give up the provinces you occupy."
        return False, "They refuse: occupy more of their land or beat their army first"

    def attack_options(self, unit):
        return self.attack_options_group([unit])

    def attack(self, unit, target_pos):
        return self.attack_group([unit], target_pos)

    def _targets(self, tag):
        enemies = self.enemies(tag)
        if not enemies:
            return set()
        found = {u.pos for u in self.units if u.carrier is None and not u.naval and u.owner in enemies}
        for prov in self.castles():
            if prov.controller in enemies and prov.garrison > 0:
                found.add(prov.pos)
        ours = self.owners_at()
        return {pos for pos in found if tag not in ours.get(pos, ())}      # never attack the hex we stand on

    def attack_options_group(self, group):
        """{target hex: hex to attack from, or "bombard" for cannons firing from where they stand}."""
        fighters = [u for u in group if u.kind.war and u.moves_left > 0 and not u.attacked]
        if not fighters or any(u.carrier for u in group):
            return {}
        lead = group[0]
        targets = self._targets(lead.owner)
        if not targets:
            return {}
        moves = min(u.moves_left for u in group)
        reach = self.reachable_group(group)
        stands = {p: c for p, c in reach.items() if c < moves and not any(u.naval for u in self.units_at(p))}
        options = {}
        for pos in targets:
            near = [p for p in neighbors(pos) if p in stands]
            if near:
                options[pos] = min(near, key=lambda p: stands[p])
        if any(u.kind.branch == "artillery" for u in fighters):
            for pos in targets:
                if distance(pos, lead.pos) <= 2 and (pos not in options or
                                                     all(u.kind.branch == "artillery" for u in fighters)):
                    options[pos] = "bombard"
        return options

    def attack_group(self, group, target):
        options = self.attack_options_group(group)
        if target not in options:
            return False
        stand = options[target]
        if stand == "bombard":
            shooters = [u for u in group if u.kind.branch == "artillery" and u.moves_left > 0 and not u.attacked]
            self._battle(shooters, target, ranged=True)
            for unit in shooters:
                unit.moves_left, unit.attacked, unit.acted = 0, True, True
        else:
            if stand != group[0].pos:
                self.move_group(group, stand)
            attackers = [u for u in group if u in self.units and u.kind.war]
            if attackers:
                self._battle(attackers, target)
            for unit in group:
                if unit in self.units:
                    unit.moves_left, unit.attacked, unit.acted = 0, True, True
        self.changed()
        return True

    def _general(self, units):
        return next((u for u in units if u.kind is GENERAL), None)

    def _attack_value(self, unit, fight, general):
        tag, branch = unit.owner, unit.kind.branch
        flat = unit.kind.attack + unit.atk_up + self.bonus(tag, f"{branch}_attack")
        value = flat * FIGHT_ATTACK[branch][fight] * unit.rank[2] * (1 + self.bonus(tag, branch))
        if general and (general.trait == fight or (general.trait == "cavalry" and branch == "cavalry")):
            value *= 1 + GENERAL_BONUS
        return value

    def _defense_value(self, unit, fight, prov, castle, versus, general):
        tag, branch = unit.owner, unit.kind.branch
        value = (unit.kind.defense + unit.def_up) * FIGHT_DEFENSE[branch][fight] * unit.rank[2]
        value *= 1 + (CASTLE_DEFENSE * castle if fight == "garrison" else TERRAIN[prov.terrain].defense)
        if branch == "infantry" and versus == "cavalry":
            value *= PIKES_VS_HORSE * (1 + self.bonus(tag, "vs_horse"))
        value *= 1 + self.bonus(tag, branch)
        if general and general.trait in ("defense", fight):
            value *= 1 + GENERAL_BONUS
        return value

    def _battle(self, attackers, pos, ranged=False):
        """Front line + support: the best 3 of each side fight, the rest support them."""
        prov = self.provinces[pos]
        here = self.units_at(pos)
        att_tag = attackers[0].owner
        def_tag = here[0].owner if here else prov.controller
        if def_tag == att_tag:
            return                                  # a country never fights itself
        castle = prov.castle if prov.controller == def_tag and prov.garrison > 0 else 0
        fight = "assault" if castle else ("open" if prov.terrain in OPEN_GROUND else "rough")
        dfight = "garrison" if castle else ("open" if fight == "open" else "rough")
        gen_a = self._general(self.units_at(attackers[0].pos))
        gen_d = self._general(here)
        defenders = [u for u in here if u.kind.war]
        if castle:
            defenders.append(Garrison(prov, self.bonus(def_tag, "garrison_defense")))
        names = (self.countries[att_tag].name, self.countries[def_tag].name if def_tag else "the natives")
        shown = None if self.player in (att_tag, def_tag) else "nobody"
        if not defenders:
            for unit in here:
                self.units.remove(unit)
            self.message(f"{names[0]} overran {len(here)} unarmed unit{'s' * (len(here) != 1)} at {prov.name}.", shown)
            return
        att_front = sorted(attackers, key=lambda u: -self._attack_value(u, fight, gen_a))[:FRONT]
        att_back = [u for u in attackers if u not in att_front]
        def_front = sorted(defenders, key=lambda u: -self._defense_value(u, dfight, prov, castle, None, gen_d))[:FRONT]
        def_back = [u for u in defenders if u not in def_front]
        att_support = min(SUPPORT_MAX, SUPPORT_BONUS * len(att_back))
        def_support = min(SUPPORT_MAX, SUPPORT_BONUS * len(def_back))
        before = {id(u): u.hp for u in attackers + defenders}      # HP going in, to report what this fight cost
        rng = self.rng

        def strike(attacker, target, factor, support, gen_att, gen_def, att_fight, def_fight):
            hit = self._attack_value(attacker, att_fight, gen_att) * rng.uniform(0.8, 1.25) * (1 + support) * factor
            block = self._defense_value(target, def_fight, prov, castle, attacker.kind.branch, gen_def) * 0.5
            target.hp -= max(1, round(hit - block))

        alive = lambda units: [u for u in units if u.hp > 0]
        if ranged:
            for gun in attackers:
                if alive(def_front):
                    strike(gun, rng.choice(alive(def_front)), 1.0, 0, gen_a, gen_d, fight, dfight)
        else:
            for gun in [u for u in att_back if u.kind.branch == "artillery"]:
                if alive(def_front):
                    strike(gun, rng.choice(alive(def_front)), 0.6, 0, gen_a, gen_d, fight, dfight)
            for unit in att_front:
                if alive(def_front):
                    strike(unit, rng.choice(alive(def_front)), 1.0, att_support, gen_a, gen_d, fight, dfight)
            counter_fight = "open" if fight == "assault" else fight
            for unit in alive(def_front):
                if alive(att_front):
                    factor = COUNTER * (0.5 if unit.kind.branch == "artillery" else 1.0)
                    strike(unit, rng.choice(alive(att_front)), factor, def_support, gen_d, gen_a, counter_fight,
                           "open" if fight == "open" else "rough")
        hp_a = sum(before[id(u)] - max(0, u.hp) for u in attackers)
        hp_d = sum(before[id(u)] - max(0, u.hp) for u in defenders)
        lost_a = [u for u in attackers if u.hp <= 0]
        lost_d = [u for u in defenders if u.hp <= 0 and not isinstance(u, Garrison)]
        for unit in lost_a + lost_d:
            if unit in self.units:
                self._kill(unit)
        for unit in defenders:
            if isinstance(unit, Garrison):
                prov.garrison = max(0, unit.hp)
        survivors_d = [u for u in defenders if u.hp > 0]
        for unit in attackers + defenders:
            if unit.hp > 0 and not isinstance(unit, Garrison):
                unit.xp += 1 + (0 if survivors_d or unit not in attackers else 1)
        dead = lambda n: f" ({n} unit{'s' * (n != 1)} destroyed)" if n else ""
        text = (f"{'Bombardment' if ranged else 'Battle'} at {prov.name}: {names[0]} lost {hp_a} strength"
                f"{dead(len(lost_a))}, {names[1]} lost {hp_d}{dead(len(lost_d))}")
        if castle and prov.garrison <= 0 and not [u for u in self.units_at(pos) if u.kind.war]:
            if ranged:
                text += "; the castle walls are breached"
            else:
                prov.controller, prov.siege = att_tag, 0
                for unit in list(self.units_at(pos)):
                    self.units.remove(unit)
                text += f"; {names[0]} stormed the castle"
        elif not survivors_d and not ranged:
            for unit in list(self.units_at(pos)):
                if unit.owner == def_tag:
                    self.units.remove(unit)
        self.message(text + ".", shown)

    def _kill(self, unit):
        for passenger in self.cargo(unit):
            self.units.remove(passenger)
        if unit in self.units:
            self.units.remove(unit)

    def sieges(self):
        """Troops standing in enemy (or lost) provinces take control of them; castles hold out longer."""
        for prov in self.provinces.values():
            if prov.owner is None:
                continue
            here = [u for u in self.units_at(prov.pos) if u.kind.war]
            cap = prov.castle * GARRISON_HP
            if not here:
                if prov.castle and prov.controller == prov.owner and prov.garrison < cap:
                    prov.garrison = min(cap, prov.garrison + GARRISON_REGEN)
                if prov.controller != prov.owner and not any(
                        u.kind.war and u.owner == prov.controller and distance(u.pos, prov.pos) <= 2
                        for u in self.units if u.carrier is None):
                    prov.siege += 1
                    if prov.siege >= 6:           # the people drive out a garrison nobody supports
                        prov.controller, prov.siege = prov.owner, 0
                        self.changed()
                elif prov.controller == prov.owner:
                    prov.siege = 0
                continue
            if len({u.owner for u in here}) > 1:
                continue            # two armies on one hex: the battle decides it, no siege progress either way
            tag = here[0].owner
            if tag == prov.controller:
                prov.siege = 0
                continue
            if tag == prov.owner or self.at_war(tag, prov.controller):
                general = self._general(self.units_at(prov.pos))
                cannons = sum(u.kind.siege + (self.bonus(tag, "siege") if u.kind.branch == "artillery" else 0)
                              for u in here)
                prov.siege += 1 + cannons + (1 if general and general.trait == "assault" else 0)
                defended = prov.controller == prov.owner
                need = SIEGE_BASE + (prov.castle * (CASTLE_SIEGE + self.bonus(prov.owner, "siege_points"))
                                     if defended else 0)
                if prov.siege >= need:
                    prov.controller, prov.siege = tag, 0
                    prov.garrison = 0 if tag != prov.owner else prov.garrison
                    self.message(f"{self.countries[tag].name} took control of {prov.name}.",
                                 None if self.player in (tag, prov.owner) else "nobody")
                    self.changed()

    def _check_alive(self):
        for tag, country in self.countries.items():
            if country.alive and not self.provinces_of(tag):
                country.alive = False
                self.units = [u for u in self.units if u.owner != tag]
                self.wars = [w for w in self.wars if tag not in (w.a, w.b)]
                self.message(f"{country.name} has disappeared from the map.")
            elif country.alive and self.provinces[country.capital].owner != tag:
                country.capital = max(self.provinces_of(tag), key=lambda p: p.pop).pos

    # ----- turns --------------------------------------------------------------------------
    def start_units(self, tag):
        for unit in self.units_of(tag):
            unit.moves_left = self.unit_moves(unit)
            unit.acted = unit.attacked = unit.upgraded = False
            if unit.kind.war and unit.hp < unit.kind.hp and not unit.carrier and unit.supplied:
                prov = self.provinces.get(unit.pos)
                if prov and prov.owner == tag and prov.controller == tag:
                    unit.hp = min(unit.kind.hp, unit.hp + (3 if prov.settlement >= 2 else 1))

    def end_round(self):
        """Everything that happens between seasons, after every country has moved."""
        self.logistics()
        self.sieges()
        for war in list(self.wars):
            if self.player in (war.a, war.b):
                limit = WAR_LENGTH_AI * 2
            else:
                limit = WAR_LENGTH_AI
            score = self.war_score(war.a, war.b)
            if self.turn - war.start >= limit or (self.player not in (war.a, war.b) and abs(score) >= 5):
                winner = war.a if score > 0 else war.b if score < 0 else "nobody"
                self.peace(war.a, war.b, winner=winner if self.player not in (war.a, war.b) else None)
        self.economy()
        self.collect()
        self.grow()
        self._research()
        self._check_alive()
        self.turn += 1
        if self.year() > END_YEAR:
            self.over = True
        for tag in self.countries:
            self.start_units(tag)
        for prov in self.provinces.values():
            prov.busy = False
        for country in self.countries.values():
            self._explore_home(country)
        self.update_visibility()
        self.changed()
        if self.player:
            c = self.countries[self.player]
            self.message(f"{self.date()}. Treasury {c.treasury:.0f} ducats ({c.balance:+.1f} per season).")

    # ----- knowledge and sight ---------------------------------------------------------
    def _explore_home(self, country):
        if not country.explored:
            if getattr(self, "_known_world", None) is None:
                self._known_world = {p for p in self.terrain if self.geo.KNOWN_WORLD(*geo.lonlat(p))}
            country.explored |= self._known_world
            limit = self.geo.COASTAL_KNOWLEDGE.get(country.tag)
            if limit is not None:
                for pos in self.terrain:
                    lon, lat = geo.lonlat(pos)
                    if lat >= limit and lon > -19.5 and (
                            self.is_sea(pos) or self.provinces.get(pos) and self.provinces[pos].coastal):
                        country.explored.add(pos)
        done = self.__dict__.setdefault("_explored_from", {}).setdefault(country.tag, set())
        for prov in self.provinces_of(country.tag):
            if prov.pos in done:
                continue
            done.add(prov.pos)
            for p in within(prov.pos, SCALE):
                if p in self.terrain:
                    country.explored.add(p)

    def see_from(self, unit, radius=None, refresh=True):
        country = self.countries[unit.owner]
        before = len(country.explored)
        for p in within(unit.pos, radius or self.unit_sight(unit)):
            if p in self.terrain:
                country.explored.add(p)
        if unit.owner == self.player and refresh:
            if len(country.explored) != before:
                self.changed()
            self.update_visibility()

    def update_visibility(self):
        if not self.player:
            self.visible = set(self.terrain)
            return
        seen = set()
        for prov in self.provinces_of(self.player):
            seen.update(within(prov.pos, 1))
        for unit in self.units_of(self.player):
            if unit.carrier is None:
                seen.update(within(unit.pos, self.unit_sight(unit)))
        new = {p for p in seen if p in self.terrain}
        if new != self.visible:
            self.visible = new
            self.version += 1

    # ----- scores ------------------------------------------------------------------------
    def score(self, tag):
        country = self.countries[tag]
        if not country.alive:
            return 0
        pop = self.total_pop(tag)
        colonial = sum(p.pop for p in self.colonies_of(tag))
        return round(pop / 20 + max(0.0, country.balance) * 3 + colonial * 2 + max(0.0, country.treasury) / 50)

    def ranking(self):
        alive = [c for c in self.countries.values() if c.alive]
        return sorted(alive, key=lambda c: -self.score(c.tag))
