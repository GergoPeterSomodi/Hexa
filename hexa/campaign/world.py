"""Age of Discovery game state: the map, countries, pops, markets, trade, colonies and wars.

Every land hex is a province. Nothing in here uses pygame.
"""
import heapq
import itertools
import pickle
import random

from ..events import EventBus, passes_changed
from ..hexgrid import distance, neighbors, within
from . import geo, naming, state, tech
from .state import Garrison, Unit, War, fill_defaults
from .systems import building, colonies, debt, economy, military, research, terrain, trade, worldgen
from .data import (COUNTER, FIGHT_ATTACK, FIGHT_DEFENSE, FRONT, GARRISON_HP, GARRISON_REGEN, GENERAL, GENERAL_BONUS,
                   GENERAL_TRAITS, OPEN_GROUND, PIKES_VS_HORSE, SCOUT, SUPPORT_BONUS, SUPPORT_MAX, UPGRADE_MAX,
                   ATTRITION, FARM_GOODS, FOREIGN_SUPPLY, FORAGE_LOSS, MANPOWER, SUPPLY_BASE, SUPPLY_PER_FARM,
                   SUPPLY_PER_PEOPLE, SUPPLY_RANGE, WAGON, WAGON_SEASONS, BUILDINGS, END_YEAR, PIONEER, CASTLE_DEFENSE,
                   CASTLE_SIEGE, SIEGE_BASE, START_YEAR, TERRAIN, WAR_LENGTH_AI, MANUFACTORIES, date)

INF = float("inf")
SCALE = geo.SCALE
_RANDOM_GEOS = {}         # seed -> random geography (only the last few kept)
_SNAPSHOTS = {}           # (map, seed) -> pickled freshly built world: building the map takes seconds
RANDOM_KEPT = 2           # random worlds kept in those caches (the Europe snapshot always stays)
PASS_RULE = 4             # the shape of the ridge edges and passes; a save with another number rebuilds them
# World attributes a save from an older version may lack, with their defaults (callables build fresh ones).
WORLD_DEFAULTS = {"log": list, "units": list, "wars": list, "routes": list, "visible": set, "over": False,
                  "version": 0, "player": None, "_owned": None, "_castle_list": None, "_sea_cache": dict,
                  "_markets_dirty": True, "_known_world": None, "_neighbour_cache": None, "_bonus_cache": dict,
                  "_settled": None, "_pass_cache": None}
# World attributes no save can do without (from_state refuses a state that lacks one). Every other attribute
# has a default above, is rebuilt on load (geo, _ids) or is added when first needed (_explored_from).
WORLD_REQUIRED = ("cols", "rows", "turn", "rng", "terrain", "provinces", "countries", "markets", "cities", "landmass",
                  "sea_body", "rivers", "river_at", "roads", "road_paths", "colonial")
LAND_TILES = ("plains", "steppe", "forest", "hills", "mountains", "desert", "jungle", "tundra", "marsh", "taiga",
              "savanna", "beach", "snow")
FORBIDDEN = worldgen.FORBIDDEN        # the terrain pairs that may not touch (wave function collapse)
Province, Country, Market, Route = state.Province, state.Country, state.Market, state.Route   # saves pickle every state class as hexa.campaign.world.<Name>


def _europe_region(lon, lat):
    """The real map's regions: the Old World, the colonial land in between, and the Americas (new) past 30 west."""
    if lon < -30:
        return "new"
    if lon < -20 or (lat < 15 and lon < 20):
        return "colonial"
    return "old"


def _europe_colonisable(lon, lat):
    """Where the AI never picks a colony: the Old World core (east of 12 west and north of 20), and all land east of 20."""
    return not (lon > -12 and lat > 20) and lon <= 20


def _europe_tropical(lon, lat):
    """Where a colony may found a trading post: Africa, south of 17 north and east of 20 west."""
    return lat < 17 and lon > -20


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
        self.bus = EventBus()            # events for the screens; never saved
        self._ids = itertools.count(1)
        self._owned = None
        self._castle_list = None
        self._bonus_cache = {}
        self.visible = set()
        self.over = False
        worldgen.build_map(self)
        worldgen.build_countries(self)
        research.start_techs(self)
        worldgen.build_roads(self)
        self._build_markets()
        worldgen.starting_units(self)
        for country in self.countries.values():
            self._explore_home(country)
        self.economy()                   # first prices and incomes
        self.message(f"{date(1)}. The age of discovery begins.", notice="start")
        _remember_snapshot(key, pickle.dumps(self.save_state(), protocol=pickle.HIGHEST_PROTOCOL))
        self._set_player(player)
        self.bus.clear()                 # a new world starts with no events, built or restored

    def _set_player(self, player):
        if player is not None and player not in self.countries:
            raise ValueError(f"no country {player!r} on {self.geo.name} (find_country() takes names and any case)")
        self.player = player
        self.update_visibility()

    # ----- saving --------------------------------------------------------------------
    def save_state(self):
        """Everything needed to rebuild this world (picklable; the map source is rebuilt from map + seed)."""
        state = {k: v for k, v in self.__dict__.items() if k not in ("geo", "_ids", "_bonus_cache", "bus")}
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
        self.bus = EventBus()
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
                fill_defaults(obj)
        self.units = [u for u in self.units if u.kind is not PIONEER]      # provinces invest from the panel now
        self._bonus_cache = {}
        self.__dict__.pop("_pass_hexes", None)               # the old one-hex passes (see _pass_data)
        for country in getattr(self, "countries", {}).values():
            if not country.techs:
                research.legacy_techs(self, country)
        provinces = getattr(self, "provinces", None)
        if self.map == "europe" and provinces and not any(p.region for p in provinces.values()):
            naming.name_europe(self)          # an older save: the old "near Porto" names become real places

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

    # ----- the map is built by systems/worldgen.py; the movement cost is systems/terrain.py -----
    step_cost = terrain.step_cost
    move_cost = terrain.move_cost

    def add_unit(self, kind, owner, pos, moves=0):
        unit = Unit(next(self._ids), kind, owner, pos, hp=kind.hp, moves_left=moves)
        if kind is GENERAL:
            unit.trait = self.rng.choice(sorted(GENERAL_TRAITS))
        self.units.append(unit)
        return unit

    _add_unit = add_unit                 # the old private name: the tests and this class still use it

    # ----- lookups -----------------------------------------------------------------
    def is_land(self, pos):
        return pos in self.terrain and TERRAIN[self.terrain[pos]].move is not None

    def is_sea(self, pos):
        return self.terrain.get(pos) == "ocean"

    # the ridge geometry (systems/worldgen.py) that tests/test_passes.py probes
    _cross = staticmethod(worldgen.cross)
    _unit_point = staticmethod(worldgen.unit_point)
    _unit_centre = staticmethod(worldgen.unit_centre)

    # ----- ridge crests, winter and mountain passes (systems/terrain.py) ---------------
    winter = terrain.is_winter
    walls = _walls = terrain.step_walls
    ridge_edges = terrain.ridge_edges
    pass_edges = terrain.pass_edges
    edge_blocked = terrain.edge_blocked
    passes = terrain.passes
    pass_name = terrain.pass_name
    pass_closed = terrain.pass_closed
    move_check = terrain.move_check
    pass_blocks = terrain.pass_blocks
    pass_edges_at = terrain.pass_edges_at
    within_reach = _within_reach = terrain.within_reach

    def pass_data(self):
        """(rule, ridge, passes, hexes, summer, winter), kept with the world (terrain.pass_tables builds it). A save
        made under another PASS_RULE (or before ridges had edges) is rebuilt here."""
        cached = self.__dict__.get("_pass_cache")
        key = (PASS_RULE, terrain.geo_key(self))
        if cached is None or cached[0] != key:
            self.__dict__.pop("_pass_hexes", None)
            cached = self._pass_cache = terrain.pass_tables(self, key)
        return cached

    _pass_data = pass_data               # the old private name (tests)

    def _field_in(self, goal, winter, until):
        """cost_field(goal) as it would be in winter (or not), whatever season it is now."""
        turn = self.turn
        self.turn = 4 if winter else 2
        try:
            return self.cost_field(goal, until=until)
        finally:
            self.turn = turn

    def pass_wait(self, group, goal):
        """The name of the closed pass a land stack should wait for spring at, or "". In winter, if the way to goal that
        the summer route takes through a pass has become much longer (more than twice as far, or 2+ seasons of moves
        more) or gone, the stack waits for the pass to open instead of walking off on a long detour and back."""
        if not group or group[0].naval or goal is None or not self.winter() or group[0].pos == goal:
            return ""
        here = group[0].pos
        summer = self._field_in(goal, False, [here])
        near = summer.get(here)
        if near is None:
            return ""
        far = self._field_in(goal, True, [here]).get(here)
        speed = max(1, min(self.unit_moves(u) for u in group))
        if far is not None and far <= 2 * near and far - near < 2 * speed:
            return ""
        passes, pos = self.pass_data()[2], here
        while pos != goal:                              # follow the summer route to the pass it goes through
            nxt = min((n for n in neighbors(pos) if summer.get(n, INF) < summer[pos]), key=lambda n: (summer[n], n),
                      default=None)
            if nxt is None:
                break
            edge = passes.get(frozenset((pos, nxt)))
            if edge:
                return edge[0]
            pos = nxt
        return ""

    # ----- provinces and countries ------------------------------------------------------
    def province(self, pos):
        return self.provinces.get(pos)

    def place(self, prov):
        """The province's name with its region, for messages: "Braga (Minho)"."""
        return naming.place(prov)

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

    def message(self, text, tag=None, notice=None, pos=None):
        """A line for the message log. `notice` names a line that has no bus event of its own (feed.NOTICES): the
        action log shows it; `pos` is the hex it is about."""
        shown = tag is None or tag == self.player
        if shown:
            self.log.append(text)
            del self.log[:-80]
        self.bus.emit("message", tag, pos, text=text, shown=shown, notice=notice)

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

    # The map's own geography decides these three (randomgeo defines them; Europe uses the defaults above).
    def region(self, pos):
        """'old' (the known Old World), 'new' (across the ocean) or 'colonial' (colonisable land in between)."""
        return getattr(self.geo, "REGION", _europe_region)(*geo.lonlat(pos))

    def in_old_world(self, pos):
        """Whether a hex belongs to the known Old World (not a colony region)."""
        return self.region(pos) == "old"

    def colonisable(self, pos):
        """Whether the AI may settle a colony on this land hex (the map's own rule; trade and terrain come on top)."""
        return getattr(self.geo, "COLONISABLE", _europe_colonisable)(*geo.lonlat(pos))

    def tropical(self, pos):
        """Whether a trading post may be founded here (the tropics: Africa on Europe's map)."""
        return getattr(self.geo, "TROPICAL", _europe_tropical)(*geo.lonlat(pos))

    def units_of(self, tag):
        return [u for u in self.units if u.owner == tag]

    def cargo(self, ship):
        return [u for u in self.units if u.carrier is ship]

    def _aboard(self):
        """{ship id: [units aboard]} in one pass over the units (what cargo() gives, for every ship at once)."""
        found = {}
        for u in self.units:
            if u.carrier is not None:
                found.setdefault(u.carrier.id, []).append(u)
        return found

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

    # ----- markets and trade routes (systems/trade.py) ------------------------------
    def _build_markets(self):
        trade.build_markets(self)
        self._sea_cache = {}
        self._markets_dirty = True
        self.ensure_markets()

    def refresh_markets(self):
        """Mark markets for rebuilding (done lazily, at most once per change burst)."""
        self._markets_dirty = True
        self.version += 1

    def take_markets_dirty(self):
        """Whether the markets are stale; asking clears the flag (trade.ensure_markets then rebuilds them)."""
        dirty, self._markets_dirty = self._markets_dirty, False
        return dirty

    def sea_distances(self, start):
        """Ocean distances from the sea next to `start` (cached)."""
        if start not in self._sea_cache:
            self._sea_cache[start] = trade.sea_walk(self, start)
        return self._sea_cache[start]

    def ensure_markets(self):
        return trade.ensure_markets(self)

    def market_owner(self, market):
        return trade.market_owner(self, market)

    def routes_of(self, market):
        return trade.routes_of(self, market)

    def route_capacity(self, route):
        return trade.route_capacity(self, route)

    def route_cost(self, route):
        return trade.route_cost(self, route)

    def merchants(self, tag):
        return trade.merchants(self, tag)

    def merchant_markets(self, tag):
        return trade.merchant_markets(self, tag)

    def market_named(self, name):
        return trade.market_named(self, name)

    def merchant_options(self, tag, route):
        return trade.merchant_options(self, tag, route)

    def send_merchant_check(self, tag, route):
        return trade.send_merchant_check(self, tag, route)

    def send_merchant(self, tag, route, good=None, src=None):
        return trade.send_merchant(self, tag, route, good, src)

    def recall_merchant(self, tag, route, order=None):
        return trade.recall_merchant(self, tag, route, order)

    # ----- the economy (systems/economy.py; it runs once per season, after everybody moved) --------------
    def set_tax(self, tag, level):
        """Change a country's tax level and show the projected economy (a preview, see economy.preview_tax)."""
        if self.__dict__.get("_settled") is None:
            self._settled = economy.settled_state(self)
        economy.preview_tax(self, tag, level)

    def settle_preview(self):
        """Put back the incomes and outputs of the last real season, so the AI decides as it would have without
        a tax preview. The preview's projections stay on show until the season's own economy runs."""
        saved = self.__dict__.get("_settled")
        if saved is None:
            return
        economy.restore_settled(self, saved)
        self._settled = None

    def economy(self, preview=False):
        """Work out prices, trade and incomes. preview=True projects them without using up the pending purchases
        or adding a point to the price history."""
        if not preview:
            self._settled = None
        economy.economy(self, preview)

    # ----- what the techs and ideas change (keys in tech.EFFECT_KEYS) ------------------------------
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

    def food_market(self, unit):
        return economy.food_market(self, unit)

    def collect(self):
        return economy.collect(self)

    def debt_limit(self, tag):
        return debt.debt_limit(self, tag)

    def disband(self, tag, need, why="disbanded"):
        return debt.disband(self, tag, need, why)

    def _unpaid(self):
        return debt.unpaid(self)

    def grow(self):
        """Population growth, colonies, native raids, building queues."""
        return economy.grow(self)

    # ----- building -----------------------------------------------------------------
    def building_name(self, prov, key):
        return building.building_name(self, prov, key)

    def works_name(self, prov, level=None):
        return building.works_name(self, prov, level)

    def slots_used(self, prov):
        return building.slots_used(self, prov)

    def build_goods(self, prov, key):
        return building.build_goods(self, prov, key)

    def build_cost(self, prov, key):
        return building.build_cost(self, prov, key)

    def build_check(self, tag, prov, key):
        return building.build_check(self, tag, prov, key)

    def build(self, tag, prov, key):
        return building.build(self, tag, prov, key)

    # ----- province investment: raise a goods tile one level, from the province panel ------------
    def invest_goods(self, prov):
        return building.invest_goods(self, prov)

    def invest_cost(self, prov):
        return building.invest_cost(self, prov)

    def invest_check(self, tag, prov):
        return building.invest_check(self, tag, prov)

    def invest(self, tag, prov):
        return building.invest(self, tag, prov)

    # ----- units --------------------------------------------------------------------
    def unit_cost(self, prov, kind):
        return military.unit_cost(self, prov, kind)

    def raise_options(self, tag):
        return military.raise_options(self, tag)

    def stack_limit(self, tag, units=()):
        return military.stack_limit(self, tag, units)

    def can_stand(self, group, pos, others=None):
        return military.can_stand(self, group, pos, others)

    def recruit_check(self, tag, prov, kind):
        return military.recruit_check(self, tag, prov, kind)

    def recruit(self, tag, prov, kind):
        return military.recruit(self, tag, prov, kind)

    land_spot = terrain.land_spot

    _land_spot = land_spot               # the old private name

    # ----- refits, drill and research ---------------------------------------------------
    def refit_check(self, unit):
        return military.refit_check(self, unit)

    def refit(self, unit):
        return military.refit(self, unit)

    def upgrade_cost(self, unit, stat):
        return military.upgrade_cost(self, unit, stat)

    def upgrade_check(self, unit, stat):
        return military.upgrade_check(self, unit, stat)

    def upgrade(self, unit, stat):
        return military.upgrade(self, unit, stat)

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

    tech_changed = _tech_changed         # the public name the research module uses

    @staticmethod
    def _idea(key):
        return research.find_idea(key)

    def grant_tech(self, tag, key):
        return research.grant_tech(self, tag, key)

    def pick_idea(self, tag, idea_key):
        return research.pick_idea(self, tag, idea_key)

    def fund_check(self, tag):
        return research.fund_check(self, tag)

    def fund_research(self, tag):
        return research.fund_research(self, tag)

    def next_era(self, tag):
        return research.next_era(self, tag)

    def research_rate(self, tag):
        return research.research_rate(self, tag)

    def tech_cost(self, tag, key):
        return research.tech_cost(self, tag, key)

    def set_research(self, tag, key):
        return research.set_research(self, tag, key)

    def unqueue(self, tag, key):
        return research.unqueue(self, tag, key)

    def _research(self):
        return research.research_season(self)

    def _finish_research(self, tag):
        return research.finish_research(self, tag)

    def _advance(self, tag):
        return research.advance(self, tag)

    def _new_age(self, tag):
        return research.new_age(self, tag)

    def _know_region(self, tag):
        return research.know_region(self, tag)

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
        walls = self.walls()
        seen, frontier = {pos}, [pos]
        for _ in range(self.supply_reach(tag) + 1):
            nxt = []
            for p in frontier:
                if self.is_depot(tag, p):
                    return True
                for n in neighbors(p):
                    prov = self.provinces.get(n)
                    if n in seen or not prov or prov.controller != tag or n in blocked or (p, n) in walls:
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
        for unit in troops:
            unit.foraged_turn = self.turn
            if not end_of_round:
                unit.moves_left = 0
        self.message(f"Troops foraged around {self.place(prov)}: they eat, the province suffers.", troops[0].owner)
        self.bus.emit("forage", troops[0].owner, prov.pos)
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
                        self._kill(unit, "starved")
            if hurt and tag == self.player and pos not in reported:
                reported.add(pos)
                why = "cut off from supply" if not fed else f"too many troops for the land ({count}/{limit})"
                where = self.place(prov) if prov else "the field"
                self.message(f"Your troops at {where} are {why}: they lose strength.", None, "supply", pos)

    # ----- movement ------------------------------------------------------------------
    def may_enter(self, unit, pos, frm=None):
        """Whether the unit may step onto `pos` (ignoring other units), from `frm` (default: where it stands, when
        that is next to pos): a ridge crest or a pass shut by snow between the two hexes stops it."""
        if unit.naval:
            return self.is_sea(pos)
        if frm is None and distance(unit.pos, pos) == 1:
            frm = unit.pos
        if frm is not None and (frm, pos) in self.walls():
            return False
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
        found, walls = set(), self.walls()
        for prov in self.castles():
            if prov.controller in enemies and prov.garrison > 0:
                found.update(n for n in neighbors(prov.pos) if (prov.pos, n) not in walls)
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
        if any(getattr(u, "foraged_turn", -1) == self.turn for u in group):
            return "They foraged this season and have no moves left."
        fresh = [u for u in group if u.moves_left <= 0 and not u.acted and u.kind.moves > 0]
        if not fresh:
            return "They have already moved this season."
        counts = {}
        for u in fresh:
            counts[u.kind.name] = counts.get(u.kind.name, 0) + 1
        names = " and ".join(f"{n} {kind}" if n > 1 else kind for kind, n in sorted(counts.items()))
        if len(fresh) == 1:
            return f"{names} raised this season and can't move yet. Untick it to move the rest."
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
            aboard = self._aboard()
            for ship in self.units_of(lead.owner):
                if ship.naval and len(aboard.get(ship.id, ())) + len(group) <= ship.kind.capacity:
                    via = [costs[n] for n in neighbors(ship.pos) if n in costs]
                    if via and min(via) + 1 <= moves:
                        reach[ship.pos] = min(via) + 1
        return reach

    def plan(self, group, budget):
        """{pos: (cost, previous pos)} for this stack over `budget` move points, same rules as moving."""
        lead = group[0]
        naval = lead.naval
        zoc = set() if naval else self.zoc(lead.owner)
        walls = frozenset() if naval else self.walls()
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
                if n not in self.terrain or (pos, n) in walls or not all(self.may_enter(u, n, pos) for u in group):
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

    def move_toward(self, unit, goal):
        """move(unit, step_toward(unit, goal)): one step of a march, with one path search."""
        return self.move_toward_group([unit], goal)

    def move_toward_group(self, group, goal):
        """move_group(group, step_toward_group(group, goal)) with one path search, not two: the plan is shared."""
        if self.pass_wait(group, goal):                  # behind a pass shut by snow: wait for spring
            return False
        best = self._group_plan(group)
        dest = self.step_toward_group(group, goal, best=best)
        return self.move_group(group, dest, best=best)

    def _group_plan(self, group):
        """plan() for the stack over its moves this season. None for units aboard a ship (they only step off)."""
        if group[0].carrier:
            return None
        return self.plan(group, min(u.moves_left for u in group))

    def move_group(self, group, dest, best=None):
        """Walk a stack to dest this season. `best` is the stack's plan() if the caller already has one."""
        group = [u for u in group if u in self.units]
        if self.over or not group:
            return False
        lead = group[0]
        if dest == lead.pos:
            return True
        if not self.move_check(group, dest)[0]:
            return False
        if best is None:
            best = self._group_plan(group)
        reach = self.reachable_group(group, best)
        if dest not in reach:
            return False
        aboard = self._aboard()                  # looked up once: nobody gets on or off during the walk
        ship = None
        if not lead.naval:
            ship = next((u for u in self.units_at(dest) if u.naval and u.owner == lead.owner
                         and len(aboard.get(u.id, ())) + len(group) <= u.kind.capacity), None)
        # Walk the route hex by hex, looking around on the way (so fog clears along it, not just at the end).
        path = self.route(group, dest, best)
        self.last_move = ([u.id for u in group], path)
        explored_before = len(self.countries[lead.owner].explored)  # counted before the walk reveals anything (#26)
        scout = max(group, key=lambda u: self.unit_sight(u))      # the stack sees as far as its best eyes
        for step in path[1:-1]:
            for unit in group:
                unit.pos = step
                for passenger in aboard.get(unit.id, ()):
                    passenger.pos = step
            self.see_from(scout, refresh=False)
        for unit in group:
            unit.pos = path[0]
            for passenger in aboard.get(unit.id, ()):
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
                for passenger in aboard.get(unit.id, ()):
                    passenger.pos = dest
            unit.acted = True
        if not lead.naval and not ship and dest in self.zoc(lead.owner):
            for unit in group:
                unit.moves_left = 0
        country = self.countries[lead.owner]
        for unit in group:
            self.see_from(unit, refresh=False)
        if lead.owner == self.player:
            if len(country.explored) != explored_before:
                self.changed()
            self.update_visibility()
        seen = [lead.owner == self.player or p in self.visible for p in path]
        self.bus.emit("unit_moved", lead.owner, dest, ids=[u.id for u in group], path=tuple(path), naval=lead.naval,
                      seen=tuple(seen))
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

    def cost_field(self, goal, naval=False, tag=None, until=None, unit=None):
        """Move costs to `goal` from everywhere (or until every hex in `until` is settled).
        With `unit` (a land unit), routes only run through hexes it may enter (may_enter): land it may not
        cross, such as a neighbour's, is no shortcut. Such hexes still get a cost as places to start from."""
        field = {goal: 0}
        heap = [(0, goal)]
        walls = frozenset() if naval else self.walls()
        left = set(until) if until else None
        while heap:
            cost, pos = heapq.heappop(heap)
            if cost > field.get(pos, INF):
                continue
            if left is not None:
                left.discard(pos)
                if not left:
                    break
            if unit is not None and pos != goal and not self.may_enter(unit, pos):
                continue                       # a unit can start here but not walk on through it
            for n in neighbors(pos):
                if naval:
                    ok, step = self.is_sea(n), 1
                else:
                    ok = self.is_land(n) and (n, pos) not in walls
                    step = self.move_cost(n, pos) if ok and self.is_land(pos) else \
                        TERRAIN[self.terrain[n]].move if ok else 0
                if ok and cost + step < field.get(n, INF):
                    field[n] = cost + step
                    heapq.heappush(heap, (cost + step, n))
        return field

    def step_toward(self, unit, goal, field=None):
        return self.step_toward_group([unit], goal, field)

    def step_toward_group(self, group, goal, field=None, best=None):
        """The hex of the next stop on the way to goal. `best` is the stack's plan() if the caller has one at hand."""
        lead = group[0]
        if best is None:
            best = self._group_plan(group)
        reach = self.reachable_group(group, best)
        if field is None:
            # Only wait for hexes this field can settle: a land field never reaches the sea hex of a
            # friendly ship in `reach`, and waiting for it would search the whole map.
            settles = self.is_sea if lead.naval else self.is_land
            until = [p for p in reach if settles(p)] or [goal]
            field = self.cost_field(goal, lead.naval, until=until, unit=None if lead.naval else lead)
        options = [p for p in reach if p == lead.pos or not any(u.naval for u in self.units_at(p)) or lead.naval]
        return min(options, key=lambda p: (field.get(p, distance(p, goal) * 4 + 1000), reach[p]))

    # ----- colonies -------------------------------------------------------------------
    def found_check(self, unit, trading_post=False):
        return colonies.found_check(self, unit, trading_post)

    def found(self, unit, trading_post=False):
        return colonies.found(self, unit, trading_post)

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
        self.bus.emit("war_declared", a, target=b)
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
                    self.bus.emit("province_captured", gainer, prov.pos, loser=prov.owner, by="peace")
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
                        self._lose([unit], "evicted")
        self.changed(ownership=True)
        self.refresh_markets()
        self.bus.emit("peace_made", a, b=b, winner=winner, moved=moved)
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
        walls = self.walls()
        for pos in targets:
            near = [p for p in neighbors(pos) if p in stands and (p, pos) not in walls]
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
            self._lose(here, "overrun")
            self.message(f"{names[0]} overran {len(here)} unarmed unit{'s' * (len(here) != 1)} at {self.place(prov)}.", shown)
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
        text = (f"{'Bombardment' if ranged else 'Battle'} at {self.place(prov)}: {names[0]} lost {hp_a} strength"
                f"{dead(len(lost_a))}, {names[1]} lost {hp_d}{dead(len(lost_d))}")
        if castle and prov.garrison <= 0 and not [u for u in self.units_at(pos) if u.kind.war]:
            if ranged:
                text += "; the castle walls are breached"
            else:
                self.bus.emit("province_captured", att_tag, pos, loser=prov.controller, by="storm")
                prov.controller, prov.siege = att_tag, 0
                self._lose(self.units_at(pos), "storm")
                text += f"; {names[0]} stormed the castle"
        elif not survivors_d and not ranged:
            self._lose([u for u in self.units_at(pos) if u.owner == def_tag], "storm")
        self.bus.emit("battle", att_tag, pos, defender=def_tag, ranged=ranged, lost=(len(lost_a), len(lost_d)),
                      hurt=(hp_a, hp_d))
        self.message(text + ".", shown)

    def _lose(self, units, why):         # off the map, with a unit_lost event each (why: see hexa/events.py)
        for unit in list(units):
            self.units.remove(unit)
            self.bus.emit("unit_lost", unit.owner, unit.pos, what=unit.kind.name, why=why)

    def _kill(self, unit, why="battle"):
        self._lose(self.cargo(unit), "sunk")
        if unit in self.units:
            self._lose([unit], why)

    def kill(self, unit, why="battle"): return self._kill(unit, why)   # public name for the debt module

    def forget_castles(self):
        """Drop the cached list of fortified provinces (castles()), after a castle was lost or built."""
        self._castle_list = None

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
                        u.kind.war and u.owner == prov.controller and self.within_reach(u.pos, prov.pos)
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
                self.bus.emit("siege_progress", tag, prov.pos, progress=prov.siege, need=need)
                if prov.siege >= need:
                    self.bus.emit("province_captured", tag, prov.pos, loser=prov.controller, by="siege")
                    prov.controller, prov.siege = tag, 0
                    prov.garrison = 0 if tag != prov.owner else prov.garrison
                    self.message(f"{self.countries[tag].name} took control of {self.place(prov)}.",
                                 None if self.player in (tag, prov.owner) else "nobody")
                    self.changed()

    def _check_alive(self):
        for tag, country in self.countries.items():
            if country.alive and not self.provinces_of(tag):
                country.alive = False
                self.units = [u for u in self.units if u.owner != tag]
                self.wars = [w for w in self.wars if tag not in (w.a, w.b)]
                self.message(f"{country.name} has disappeared from the map.", None, "extinct")
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
        self._unpaid()
        self.grow()
        self._research()
        self._check_alive()
        was_winter = self.winter()
        self.turn += 1
        passes_changed(self, was_winter)
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
            self.message(f"{self.date()}. Treasury {c.treasury:.0f} ducats ({c.balance:+.1f} per season).", None,
                         "treasury")

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
