"""Age of Discovery game state: the map, countries, pops, markets, trade, colonies and wars.

Every land hex is a province. Nothing in here uses pygame.
"""
import itertools
import pickle
import random

from ..events import EventBus
from ..hexgrid import distance, neighbors, within
from . import geo, naming, state, tech
from .state import Unit, fill_defaults
from .systems import (building, colonies, debt, economy, military, movement, research, season, supply, terrain, trade,
                      war, worldgen)
from .systems import battle as battlesys
from .data import (GENERAL, GENERAL_TRAITS, UPGRADE_MAX, MANPOWER, SUPPLY_RANGE, WAGON_SEASONS, BUILDINGS, PIONEER,
                   START_YEAR, TERRAIN, MANUFACTORIES, date)

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
                  "_settled": None, "_pass_cache": None, "battles": list, "battle_names": dict}
# World attributes no save can do without (from_state refuses a state that lacks one). Every other attribute
# has a default above, is rebuilt on load (geo, _ids) or is added when first needed (_explored_from).
WORLD_REQUIRED = ("cols", "rows", "turn", "rng", "terrain", "provinces", "countries", "markets", "cities", "landmass",
                  "sea_body", "rivers", "river_at", "roads", "road_paths", "colonial")
LAND_TILES = ("plains", "steppe", "forest", "hills", "mountains", "desert", "jungle", "tundra", "marsh", "taiga",
              "savanna", "beach", "snow")
FORBIDDEN = worldgen.FORBIDDEN        # the terrain pairs that may not touch (wave function collapse)
# saves pickle every state class as hexa.campaign.world.<Name>
Province, Country, Market, Route, War, Garrison = (state.Province, state.Country, state.Market, state.Route, state.War,
                                                   state.Garrison)
Battle = state.Battle                 # one fight on a hex (battle slice 1)


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
        self.battles = []
        self.battle_names = {}           # battles named so far, by place (battle.py); a repeat is "Second Battle of X"
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
            self.explore_home(country)
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
                  self.units, getattr(self, "markets", ()), self.routes, self.wars, self.battles)
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

    def known_world(self):
        """The hexes of the world every country knows at the start (the map's KNOWN_WORLD), worked out once. Lazy, so
        a save from before it existed still loads; the cache is `_known_world` (in WORLD_DEFAULTS)."""
        if getattr(self, "_known_world", None) is None:
            self._known_world = {p for p in self.terrain if self.geo.KNOWN_WORLD(*geo.lonlat(p))}
        return self._known_world

    def aboard(self):
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

    # ----- supply (systems/supply.py) and movement (systems/movement.py) -----------------------
    # Plain class attributes, so a call costs what the old method did (the AI's hot path).
    supply_limit = supply.supply_limit
    is_depot = supply.is_depot
    in_supply = supply.in_supply
    supply_state = supply.supply_state
    forage_check = supply.forage_check
    forage = supply.forage
    logistics = supply.logistics
    may_enter = movement.may_enter
    zoc = movement.zoc
    stuck_reason = movement.stuck_reason
    reachable = movement.reachable
    reachable_group = movement.reachable_group
    plan = movement.plan
    next_season_reach = movement.next_season_reach
    path_to = movement.path_to
    move = movement.move
    move_toward = movement.move_toward
    move_toward_group = movement.move_toward_group
    group_plan = movement.group_plan
    move_group = movement.move_group
    route = movement.route
    cost_field = movement.cost_field
    step_toward = movement.step_toward
    step_toward_group = movement.step_toward_group
    field_in = movement.field_in
    pass_wait = movement.pass_wait

    def castles(self):
        if self._castle_list is None:
            self._castle_list = [p for p in self.provinces.values() if p.castle and p.owner]
        return self._castle_list

    # ----- colonies -------------------------------------------------------------------
    def found_check(self, unit, trading_post=False):
        return colonies.found_check(self, unit, trading_post)

    def found(self, unit, trading_post=False):
        return colonies.found(self, unit, trading_post)

    # ----- war (systems/war.py) -------------------------------------------------------------
    at_war = war.at_war
    enemies = war.enemies
    war_check = war.war_check
    declare_war = war.declare_war
    war_score = war.war_score
    peace = war.peace
    free_spot_near = war.free_spot_near
    peace_offer = war.peace_offer
    attack_options = war.attack_options
    attack = war.attack
    targets = war.targets
    attack_options_group = war.attack_options_group
    attack_group = war.attack_group
    general = war.general
    attack_value = war.attack_value
    defense_value = war.defense_value
    lose = war.lose
    kill = _kill = war.kill              # kill is the public name the debt module uses; _kill the old one (tests)
    sieges = war.sieges
    check_alive = war.check_alive

    # ----- battles (state.Battle; the rules come in systems/battle.py, battle slice 1) -----------------
    def battle_at(self, pos):
        """The battle fought on this hex, or None. A linear scan: there are rarely more than a few."""
        return next((b for b in self.battles if b.pos == pos), None)

    # the battle's life (systems/battle.py): a stack attacks or joins, the orders, the retreat, the end of battles
    engage = battlesys.engage
    engage_check = battlesys.engage_check
    battle_order_check = battlesys.battle_order_check
    battle_order = battlesys.battle_order
    end_battles = battlesys.end_battles
    retreat_spot = battlesys.retreat_spot
    army_morale = battlesys.army_morale

    def forget_castles(self):
        """Drop the cached list of fortified provinces (castles()), after a castle was lost or built."""
        self._castle_list = None

    # ----- the season (systems/season.py): the phases, the turn's units, sight and scores --------------
    end_round = season.end_round
    start_units = season.start_units
    explore_home = _explore_home = season.explore_home      # the old private name: tests/test_town_labels.py
    see_from = season.see_from
    update_visibility = season.update_visibility
    score = season.score
    ranking = season.ranking
