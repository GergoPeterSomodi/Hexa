"""What a country has and how it changed this season: the data behind the top bar's resource chips. Pygame-free.

``snapshot(world, tag)`` gives ``{name: (value, delta, lines)}`` for the names in ``NAMES``:

    ducats provinces regiments merchants merchants_total prestige research  and the home-market price of each of
    ``KEY_GOODS`` (named by the good's key: "horses", "gunpowder")

    value   the number now (merchants: busy merchants, merchants_total: all of them; prestige: the ledger score;
            provinces: owned; regiments: war units; a price is the capital's market price)
    delta   value now minus value at the season baseline
    lines   the hover card: ``Line(group, label, amount, pos)`` tuples. group is "income" or "spending" (ducats: the
            season's treasury breakdown) or "oneoff" (what happened since the baseline: raising, building, battles,
            seizures, desertions...); ``pos`` is a hex to jump to, or None. For ducats the lines add up to the delta:
            what the breakdown and the one-offs do not explain is one "Other" line.

THE BASELINE ("season start") is the moment the player ends the turn, not the moment the next one begins:
``GameManager.end_season`` calls ``Tracker.begin_season()`` before the AI moves and the world ends the round, then
``Tracker.round_done()`` after it. So a chip shows what the season that was just played did to a resource, followed by
what the player has done since: "3,548 (+45)" is income less the one-offs. At the start of a game (before the first
season is played) the baseline is the starting values and the income lines are empty (nothing was collected yet).
``expected(world, tag)`` is the other number: next season's expected change (balance, research rate).

HOW IT LEARNS ABOUT ONE-OFFS. The tracker is a tap on ``world.bus`` (hexa/events.py): it hears each event the moment it
is emitted, so it needs no drain, and it never changes the world. Money spent goes through ``spend`` below, which
emits ``money_spent``. Raised and lost units, captures, colonies, seizures and finished techs come from their own events.

NOT SAVED. The baseline, the 12-season history and the ledger live in the Tracker only (one per world, made on first
use, found again by ``of(world)``). A loaded game starts a new baseline at the moment of loading: the chips read +0
until the next season is played. Saving them would add public state that the behaviour oracle hashes and a save
format to keep compatible, for numbers of no rules value.
"""
import weakref
from collections import deque, namedtuple

from . import tech
from .data import UNIT_KINDS

KEY_GOODS = ("horses", "gunpowder")
NAMES = ("ducats", "provinces", "regiments", "merchants", "merchants_total", "prestige", "research") + KEY_GOODS
HISTORY = 12            # seasons of values kept for each resource
LEDGER = 80             # one-off items kept for each country (a season of the busiest war is far fewer)

Reading = namedtuple("Reading", "value delta lines")
Line = namedtuple("Line", "group label amount pos")
Item = namedtuple("Item", "resource key amount pos detail")     # one thing that happened: see TITLES for the key

INCOME_LABELS = {"production": "Production", "taxes": "Taxes", "buildings": "Manufactories", "trade": "Trade",
                 "upkeep": "Building upkeep", "military": "Army upkeep", "colonies": "Colonies",
                 "interest": "Interest"}
TITLES = {
    # ducats
    "raise": "Raising troops", "build": "Building", "invest": "Investing", "refit": "Refitting troops",
    "upgrade": "Drilling troops", "research": "Funding research", "seized": "Creditors seized",
    # regiments
    "raised": "Raised", "battle": "Lost in battle", "storm": "Lost in a storm", "overrun": "Overrun",
    "disbanded": "Disbanded", "deserted": "Deserted", "starved": "Starved", "sunk": "Sunk", "evicted": "Evicted",
    # provinces
    "took": "Gained in peace", "lost": "Lost in peace", "occupied": "Occupied", "occupied_lost": "Lost to occupation",
    "founded": "Founded",
    # research
    "tech": "Finished",
}


def spend(world, tag, amount, reason, pos=None):
    """Take `amount` ducats from the treasury of `tag` and tell the bus (``money_spent``). Every purchase of the
    rules goes through here: reason is "raise", "build", "invest", "refit", "upgrade" or "research"."""
    world.countries[tag].treasury -= amount
    world.bus.emit("money_spent", tag, pos, amount=amount, reason=reason)


def values(world, tag):
    """The current value of every name in NAMES, for one country."""
    country = world.countries[tag]
    market = world.provinces[country.capital].market if country.capital in world.provinces else None
    out = {"ducats": country.treasury, "provinces": len(world.provinces_of(tag)),
           "regiments": sum(1 for u in world.units if u.owner == tag and u.kind.war),
           "merchants": len(country.orders), "merchants_total": world.merchants(tag),
           "prestige": world.score(tag), "research": country.research}
    for good in KEY_GOODS:
        out[good] = round(market.price[good], 2) if market and good in market.price else 0.0
    return out


def of(world):
    """The world's tracker (made, and tapped into its bus, on first use)."""
    found = _TRACKERS.get(world)
    if found is None:
        found = _TRACKERS[world] = Tracker(world)
    return found


def snapshot(world, tag):
    """``{name: (value, delta, lines)}`` for one country: see the module docstring."""
    return of(world).snapshot(tag)


def expected(world, tag):
    """What the next season should change: {"ducats": balance, "research": points a season}."""
    return {"ducats": world.countries[tag].balance, "research": world.research_rate(tag)[0]}


class Tracker:
    def __init__(self, world):
        self._world = weakref.ref(world)
        self.start = {}         # tag -> values at the baseline
        self.history = {}       # tag -> {name: deque of the values at the last HISTORY baselines}
        self.ledger = {}        # tag -> deque of Item since the baseline
        self.collected = {}     # tag -> the income dict of the season just played (None before the first)
        self.season = world.turn
        self._kinds = {k.name: k for k in UNIT_KINDS.values()}
        world.bus.tap(self.on_event)
        self.begin_season()

    @property
    def world(self):
        return self._world()

    # ----- the baseline ------------------------------------------------------------------
    def begin_season(self):
        """Take the baseline: every living country's values now, and an empty ledger. Called by
        ``GameManager.end_season`` just before the season is played."""
        world = self.world
        self.season = world.turn
        for tag, country in world.countries.items():
            if not country.alive:
                continue
            now = values(world, tag)
            self.start[tag] = now
            series = self.history.setdefault(tag, {})
            for name, value in now.items():
                series.setdefault(name, deque(maxlen=HISTORY)).append(value)
            self.ledger[tag] = deque(maxlen=LEDGER)
            self.collected[tag] = None

    def round_done(self):
        """Remember the incomes the season just played collected. Called right after ``world.end_round``."""
        for tag, country in self.world.countries.items():
            if country.alive:
                self.collected[tag] = dict(country.income)

    def series(self, tag, name):
        """The last HISTORY values of one resource, oldest first, ending with the value now."""
        past = list(self.history.get(tag, {}).get(name, ()))
        now = values(self.world, tag)[name]
        return (past[:-1] + [now])[-HISTORY:] if past else [now]

    # ----- the ledger --------------------------------------------------------------------
    def _add(self, tag, resource, key, amount, pos=None, detail=""):
        if tag in self.ledger:
            self.ledger[tag].append(Item(resource, key, amount, pos, detail))

    def _place(self, pos):
        prov = self.world.provinces.get(pos)
        return self.world.place(prov) if prov else ""

    def on_event(self, event):
        """The bus tap: file what happened under the resource it changed."""
        kind, tag, pos = event.kind, event.tag, event.pos
        if kind == "money_spent":
            self._add(tag, "ducats", event.get("reason"), -event.get("amount", 0), pos, self._place(pos))
        elif kind == "unit_raised" and self._war(event):
            self._add(tag, "regiments", "raised", 1, pos, event.get("what"))
        elif kind == "unit_lost" and self._war(event):
            self._add(tag, "regiments", event.get("why", "battle"), -1, pos, event.get("what"))
        elif kind == "debt_seized":
            self._add(tag, "ducats", "seized", 0.0, None, event.get("what"))
        elif kind == "province_captured":
            peace = event.get("by") == "peace"
            self._add(tag, "provinces", "took" if peace else "occupied", int(peace), pos, self._place(pos))
            loser = event.get("loser")
            if loser:
                self._add(loser, "provinces", "lost" if peace else "occupied_lost", -int(peace), pos, self._place(pos))
        elif kind == "colony_founded":
            self._add(tag, "provinces", "founded", 1, pos, self._place(pos))
        elif kind == "tech_researched":
            self._add(tag, "research", "tech", -event.get("cost", 0), None, self._tech_name(event.get("key")))

    def _war(self, event):
        found = self._kinds.get(event.get("what"))
        return bool(found and found.war)

    @staticmethod
    def _tech_name(key):
        found = tech.TECHS.get(key)
        return found.name if found else str(key)

    def oneoffs(self, tag, resource):
        """The ledger lines of one resource: items with the same key are one line (with a count, or the place if
        there is one)."""
        groups = {}
        for item in self.ledger.get(tag, ()):
            if item.resource == resource:
                groups.setdefault(item.key, []).append(item)
        lines = []
        for key, items in groups.items():
            title, total = TITLES.get(key, str(key).title()), sum(i.amount for i in items)
            last = items[-1]
            label = f"{title}: {last.detail}" if len(items) == 1 and last.detail else \
                f"{title} x{len(items)}" if len(items) > 1 else title
            lines.append(Line("oneoff", label, total, last.pos))
        return lines

    # ----- the numbers -------------------------------------------------------------------
    def snapshot(self, tag):
        world = self.world
        now = values(world, tag)
        start = self.start.get(tag) or now
        out = {}
        for name, value in now.items():
            delta = value - start.get(name, value)
            if isinstance(delta, float):
                delta = round(delta, 2)
            out[name] = Reading(value, delta, self._lines(tag, name, delta))
        return out

    def _lines(self, tag, name, delta):
        if name == "ducats":
            return self._ducat_lines(tag, delta)
        if name == "research":
            ones = self.oneoffs(tag, "research")
            gained = round(delta - sum(line.amount for line in ones), 2)
            return ([Line("income", "Research points", gained, None)] if gained else []) + ones
        if name in ("provinces", "regiments"):
            return self.oneoffs(tag, name)
        return []

    def _ducat_lines(self, tag, delta):
        lines = []
        income = self.collected.get(tag)
        for key, amount in sorted((income or {}).items(), key=lambda kv: -abs(kv[1])):
            if abs(amount) >= 0.05:
                lines.append(Line("income" if amount > 0 else "spending",
                                  INCOME_LABELS.get(key, key.title()), amount, None))
        lines += self.oneoffs(tag, "ducats")
        other = round(delta - sum(line.amount for line in lines), 2)
        if abs(other) >= 0.5:
            lines.append(Line("oneoff", "Other", other, None))
        return lines


_TRACKERS = weakref.WeakKeyDictionary()
