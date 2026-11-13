"""Age of Discovery state objects: the dataclasses a saved world pickles (Province, Market, Route, Country, Unit,
Garrison, War, Battle) and fill_defaults, which gives an object from an older save the fields it lacks.

Nothing in here uses pygame or imports the world. Saves pickle these classes by module and name, so every one of them
reports its module as ``hexa.campaign.world`` (decision D5 of docs/architecture/review-2026-11-12.md): a save made
now opens in a build from before this module existed, and an old save opens here. ``world.py`` re-exports the names.
"""
from dataclasses import MISSING, dataclass, field, fields, is_dataclass

from .data import (GARRISON_ATTACK, GARRISON_DEFENSE, GARRISON_HP, GARRISON_MEN, GENERAL, GENERAL_TRAITS,
                   GOODS, MEN, TRADING_POST_SHARE, VETERAN_RANKS, UnitKind)
from .geo import SCALE


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
    region: str = ""          # the historical region (Europe map): "Minho" for Braga

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

    def reset(self, keep_pending=False):
        """Clear the season's books. The pending purchases count as demand; they are used up unless keep_pending."""
        for d in (self.supply, self.demand, self.imports, self.exports, self.produced):
            for g in GOODS:
                d[g] = 0.0
        for g, n in self.pending.items():
            self.demand[g] += n
        if not keep_pending:
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
    foraged_turn: int = -1     # the turn this unit's stack last foraged (see stuck_reason)
    morale: float = 1.0        # 0 to 1: a beaten regiment routs (battle slice 1); recovers outside battle

    @property
    def men(self):
        """The regiment's strength in men. hp is the rule; men is what the player sees (battle slice 1). Only war units
        have men: generals, wagons, pioneers and the other civilians have none."""
        return round(MEN * self.hp / self.kind.hp) if self.kind.war and self.kind.hp else 0

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

    @property
    def men(self):
        return round(GARRISON_MEN * self.hp)


@dataclass(eq=False)
class War:
    a: str
    b: str
    start: int


@dataclass(eq=False)
class Battle:
    """The fight on one hex, while both sides' stacks stand there (battle slice 1).

    Units are kept by id: a unit that died, deserted or left is missing, and the battle skips it.
    The battle keeps no unit objects, no bus events and no pygame objects."""
    pos: tuple                    # the hex; one battle per hex
    attacker: str                 # country tag
    defender: str                 # country tag
    start: int                    # world.turn it began
    assault: bool = False         # the defender held a castle with a garrison when it began
    days: int = 0                 # days fought so far
    stance: dict = field(default_factory=dict)     # tag -> "attack" | "hold" | "withdraw"
    lanes: dict = field(default_factory=dict)      # tag -> [unit id | "garrison" | None] * 3 (left, centre, right)
    routed: set = field(default_factory=set)       # unit ids out of the fight (they stay on the hex)
    carry: dict = field(default_factory=dict)      # unit id or "garrison" -> damage not yet taken (hp, < 1)
    wounded_hp: dict = field(default_factory=dict) # unit id -> hp lost as wounded (float)
    men0: dict = field(default_factory=dict)       # tag -> men that have joined the fight (start + joiners)
    killed: dict = field(default_factory=dict)     # tag -> men killed
    wounded: dict = field(default_factory=dict)    # tag -> men wounded
    garrison_morale: float = 1.0
    log: list = field(default_factory=list)        # (turn, day, text); the last BATTLE_LOG lines
    members: set = field(default_factory=set)      # unit ids that have fought in it (start and joiners); each counts once
    name: str = ""                # "Battle of X, 1525", set when it starts (decision 5); "" for a battle made before names


def fill_defaults(obj):
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


# D5: saves refer to these classes as hexa.campaign.world.<Name>
for _cls in [c for c in globals().values() if isinstance(c, type) and c.__module__ == __name__]:
    _cls.__module__ = "hexa.campaign.world"
