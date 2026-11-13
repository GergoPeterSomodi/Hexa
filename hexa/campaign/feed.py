"""The feed: what the bus says, turned into floating text and the action log. Pygame-free.

``of(world)`` is the world's feed (made, and tapped into ``world.bus``, on first use). Each event the player should
hear about becomes one ``FeedItem``:

    kind         the event kind ("battle_ended", "unit_raised", ...)
    colour_kind  one of COLOUR_KINDS, the colour of the ribbon (the UI maps them to RGB):
                     war     red     battles, war declared, a province taken by storm or siege
                     siege   amber   a siege going on
                     gain    gold    what the player wins: a province, a tech, an age, a finished building
                     own     green   what the player did on purpose: recruited, built, foraged, founded
                     loss    rose    what the player loses: units, provinces, debt seizures, raids
                     other   white   what other countries do in the player's sight
    text         the short floating text ("Captured!", "Recruited", "Foraged", "Deserted", "Siege 2/5")
    pos          the hex it happened on (floating text goes there; a click on the log line jumps there), or None
    tag          the country it is about
    season       the turn it happened in (the log groups by it)
    sentence     the log line, a full sentence with ``world.place(prov)`` names
    mine         the player is one of the parties (the "Mine" filter)
    floating     the UI should float `text` over `pos`
    log          the line belongs in the action log

WHO HEARS WHAT (decided here, not in the screens). An item exists only if the player is a party to it (its country,
the other side of a battle, the owner or besieger of a province) or its hex is in the player's vision
(``world.visible``, as it is when the event happens). Under fog nothing is told. Other countries' recruiting, building
and research are never told (the AI does them all the time and the player cannot see them). Without a player
(``world.player`` is None) every event with a place is told.
A hex the player sees but has scrolled away from still gets its log line; the screen decides whether to float it.

THE LOG is bounded: PER_SEASON items for each of the last KEEP_SEASONS seasons, newest kept. It is TRANSIENT, not
saved: the saved ``world.log`` (the last 80 message lines) stays the long record, a saved action log would need a new
world attribute and a save format (with the behaviour oracle hashing it), and a loaded game starting with an empty log
loses nothing the player cannot read in ``world.log``. Floating text waits in a short queue (FLOATING) that the screen
empties each frame with ``take_floating()``.

``entries(filter)`` gives the log for the screen, newest season first, with FILTERS "all", "war", "money" and "mine".
``unread`` counts the log lines since ``mark_read()`` (the collapsed log's "+8 new" badge).
"""
import time
import weakref
from collections import deque
from typing import NamedTuple, Optional

from .data import BUILDINGS, ERAS, date
from .tech import TECHS

COLOUR_KINDS = ("war", "siege", "gain", "own", "loss", "other")
FILTERS = ("all", "war", "money", "mine")
PER_SEASON = 60         # log items kept for each season
KEEP_SEASONS = 8        # seasons of log kept (two years)
FLOATING = 40           # floating items waiting for the screen
MONEY_KINDS = ("money_spent", "unit_raised", "building_done", "investment_done", "debt_seized", "treasury", "credit",
               "merchant")
# Lines the rules write with ``world.message(text, tag, notice=name)`` because they have no event of their own:
# name -> (colour kind, keyword). They are log lines only (no floating text); the "Money" filter takes the kinds
# in MONEY_KINDS.
NOTICES = {
    "start": ("other", "Start"), "lead": ("other", "Start"), "treasury": ("other", "Treasury"),
    "credit": ("loss", "Credit"), "merchant": ("own", "Trade"), "idea": ("gain", "Idea"),
    "growth": ("gain", "Grown"), "supply": ("loss", "Supply"), "extinct": ("war", "Gone"),
    "march": ("own", "March"), "research": ("other", "Research"),
}
LOSS_TEXT = {"battle": "Lost", "storm": "Lost", "overrun": "Overrun", "deserted": "Deserted", "starved": "Starved",
             "sunk": "Sunk", "evicted": "Evicted", "disbanded": "Disbanded"}
LOSS_LOGGED = ("overrun", "starved", "sunk", "evicted", "disbanded")     # the others are told by their own items
SPENT = {"build": ("Building", "Started building at {}"), "refit": ("Refitted", "Refitted troops at {}"),
         "upgrade": ("Drilled", "Drilled troops at {}")}


class FeedItem(NamedTuple):
    kind: str
    colour_kind: str
    text: str
    pos: Optional[tuple]
    tag: Optional[str]
    season: int
    sentence: str = ""
    mine: bool = False
    floating: bool = False
    log: bool = True


def of(world):
    """The world's feed (made on first use)."""
    found = _FEEDS.get(world)
    if found is None:
        found = _FEEDS[world] = Feed(world)
    return found


def ducats(amount):
    return f"{amount:,.0f} ducats"


def units(n):
    return f"{n} unit{'s' * (n != 1)}"


class Feed:
    def __init__(self, world):
        self._world = weakref.ref(world)
        self.groups = {}                    # season -> deque of FeedItem
        self.unread = 0
        self._floating = deque(maxlen=FLOATING)     # (time.monotonic() when told, FeedItem)
        self._costs = {}                    # (tag, pos, reason) -> ducats, to put in the next matching sentence
        self._once = set()                  # (kind, season) told once a season
        world.bus.tap(self.on_event)
        if world.turn == 1:                         # the line the world wrote before there was a feed to hear it
            for text in world.log:
                self._notice(None, "start", text)

    @property
    def world(self):
        return self._world()

    # ----- taking events in --------------------------------------------------------------
    def on_event(self, event):
        handler = getattr(self, "_" + event.kind, None)
        if handler is None:
            return
        item = handler(event)
        if item is None:
            return
        if item.floating:
            self._floating.append((time.monotonic(), item))
        if item.log:
            group = self.groups.get(item.season)
            if group is None:
                group = self.groups[item.season] = deque(maxlen=PER_SEASON)
                for old in sorted(self.groups)[:-KEEP_SEASONS]:
                    del self.groups[old]
            group.append(item)
            self.unread += 1

    def take_floating(self, max_age=None):
        """The floating items since the last call, oldest first. With `max_age` (seconds), those told longer ago are
        left out: the screen was not showing the map and the moment has passed."""
        now = time.monotonic()
        out = [item for told, item in self._floating if max_age is None or now - told <= max_age]
        self._floating.clear()
        return out

    def mark_read(self):
        self.unread = 0

    def clear(self):
        self.groups.clear()
        self._floating.clear()
        self.unread = 0

    def entries(self, filter="all"):
        """The log for the screen: ``[(season, "Spring 1480", [FeedItem, ...])]``, newest season first, newest line
        first in each. filter: "all", "war" (war and siege ribbons), "money" or "mine"."""
        out = []
        for season in sorted(self.groups, reverse=True):
            items = [i for i in reversed(self.groups[season]) if self._passes(i, filter)]
            if items:
                out.append((season, date(season), items))
        return out

    @staticmethod
    def _passes(item, filter):
        if filter == "war":
            return item.colour_kind in ("war", "siege")
        if filter == "money":
            return item.kind in MONEY_KINDS
        return item.mine if filter == "mine" else True

    # ----- helpers -----------------------------------------------------------------------
    def _name(self, tag):
        country = self.world.countries.get(tag)
        return country.name if country else "The natives"

    def _place(self, pos):
        prov = self.world.provinces.get(pos)
        return self.world.place(prov) if prov else "the sea"

    def _seen(self, pos):
        world = self.world
        return world.player is None or pos in world.visible

    def _party(self, *tags):
        player = self.world.player
        return player is not None and player in tags

    def _item(self, event, colour, text, sentence, mine=False, floating=True, log=True, pos=True):
        """Make an item for the event. Floating text needs a place, and is floated only if the player is a party
        to the event or can see the place."""
        place = event.pos if pos else None
        return FeedItem(event.kind, colour, text, place, event.tag, self.world.turn, sentence, mine,
                        floating and place is not None and (mine or self._seen(place)), log)

    def _notice(self, event, name, text):
        """Put a line that has no event into the log (the world's own start line, at the first turn)."""
        colour, keyword = NOTICES[name]
        item = FeedItem(name, colour, keyword, None, None, self.world.turn, text, True, False, True)
        self.groups.setdefault(item.season, deque(maxlen=PER_SEASON)).append(item)

    # ----- one handler per event kind: each returns a FeedItem or None --------------------
    def _message(self, event):
        """A ``world.message`` that names a notice and was shown to the player: a log line of its own."""
        spec = NOTICES.get(event.get("notice"))
        if spec is None or not event.get("shown"):
            return None
        item = self._item(event, spec[0], spec[1], event.get("text"), True, floating=False)
        return item._replace(kind=event.get("notice"))

    def _battle_started(self, event):
        att, dfn = event.tag, event.get("defender")
        mine = self._party(att, dfn)
        if not (mine or self._seen(event.pos)):
            return None
        sentence = f"{event.get('name') or 'Battle'}: {self._name(att)} attacked {self._name(dfn)}."
        return self._item(event, "war", "Battle!", sentence, mine)

    def _battle_ended(self, event):
        att, dfn = event.tag, event.get("defender")
        mine = self._party(att, dfn)
        if not (mine or self._seen(event.pos)):
            return None
        killed = event.get("killed", {})
        if event.get("winner"):
            verdict = f"{self._name(event.get('winner'))} beat {self._name(event.get('loser'))}"
        else:
            verdict = "no side won"
        sentence = (f"{event.get('name') or 'Battle'} ({event.get('seasons', 1)} seasons): {verdict}. "
                    f"{self._name(att)} lost {killed.get(att, 0):,} men, {self._name(dfn)} lost {killed.get(dfn, 0):,} men.")
        return self._item(event, "war", "Battle over", sentence, mine)

    def _province_captured(self, event):
        captor, loser, how = event.tag, event.get("loser"), event.get("by")
        mine = self._party(captor, loser)
        if not (mine or self._seen(event.pos)):
            return None
        verb = {"storm": "stormed", "siege": "took", "peace": "gained"}.get(how, "took")
        sentence = f"{self._name(captor)} {verb} {self._place(event.pos)} from {self._name(loser)}" + \
            (" in the peace." if how == "peace" else ".")
        if self._party(captor):
            return self._item(event, "gain", "Gained!" if how == "peace" else "Captured!", sentence, True)
        if self._party(loser):
            return self._item(event, "loss", "Lost!", sentence, True)
        return self._item(event, "other" if how == "peace" else "war", "Captured", sentence)

    def _siege_progress(self, event):
        prov = self.world.provinces.get(event.pos)
        mine = self._party(event.tag, prov.owner if prov else None, prov.controller if prov else None)
        if not (mine or self._seen(event.pos)):
            return None
        progress, need = event.get("progress", 0), event.get("need", 0)
        sentence = f"{self._name(event.tag)} besieges {self._place(event.pos)}: {progress} of {need}."
        return self._item(event, "siege", f"Siege {progress}/{need}", sentence, mine, log=mine)

    def _war_declared(self, event):
        target = event.get("target")
        mine = self._party(event.tag, target)
        if not mine and self.world.player is not None:
            return None
        return self._item(event, "war", "War!", f"{self._name(event.tag)} declared war on {self._name(target)}!",
                          mine, floating=False, pos=False)

    def _peace_made(self, event):
        other = event.get("b")
        mine = self._party(event.tag, other)
        if not mine and self.world.player is not None:
            return None
        moved = event.get("moved", 0)
        sentence = f"Peace between {self._name(event.tag)} and {self._name(other)}" + \
            (f": {moved} province{'s' * (moved != 1)} changed hands." if moved else ".")
        return self._item(event, "other", "Peace", sentence, mine, floating=False, pos=False)

    def _unit_raised(self, event):
        if not self._party(event.tag):
            return None
        cost = self._costs.pop((event.tag, event.pos, "raise"), None)
        sentence = f"Raised {event.get('what', 'troops').lower()} at {self._place(event.pos)}" + \
            (f" for {ducats(cost)}." if cost else ".")
        return self._item(event, "own", "Recruited", sentence, True)

    def _money_spent(self, event):
        if not self._party(event.tag):
            return None
        reason, amount = event.get("reason"), event.get("amount", 0)
        if reason in ("raise", "invest"):              # told by unit_raised and investment_done, with the cost
            self._costs[(event.tag, event.pos, reason)] = amount
            return None
        if reason == "research":
            return self._item(event, "own", "Funded", f"Funded research for {ducats(amount)}.", True,
                              floating=False, pos=False)
        text, template = SPENT[reason]
        return self._item(event, "own", text, template.format(self._place(event.pos)) + f" for {ducats(amount)}.",
                          True)

    def _forage(self, event):
        place = self._place(event.pos)
        if self._party(event.tag):
            return self._item(event, "own", "Foraged", f"Your troops foraged around {place}.", True)
        if not self._seen(event.pos):
            return None
        return self._item(event, "other", "Foraged", f"{self._name(event.tag)}'s troops foraged around {place}.")

    def _unit_lost(self, event):
        if not self._party(event.tag):
            return None
        why, what, place = event.get("why", "battle"), event.get("what", "unit").lower(), self._place(event.pos)
        if why == "disbanded":
            return self._item(event, "own", "Disbanded", f"Disbanded {what} at {place}.", True)
        return self._item(event, "loss", LOSS_TEXT.get(why, "Lost"), f"Lost {what} at {place} ({why}).", True,
                          log=why in LOSS_LOGGED)

    def _unit_deserted(self, event):
        if not self._party(event.tag):
            return None
        names = ", ".join(f"{n} {k.lower()}" for k, n in sorted(event.get("kinds", {}).items()))
        return self._item(event, "loss", "Deserted", f"Unpaid troops deserted: {names}.", True, floating=False,
                          pos=False)

    def _debt_seized(self, event):
        if not self._party(event.tag):
            return None
        return self._item(event, "loss", "Seized", f"Creditors seized the {event.get('what')}.", True, floating=False,
                          pos=False)

    def _tech_researched(self, event):
        if not self._party(event.tag):
            return None
        found = TECHS.get(event.get("key"))
        return self._item(event, "gain", "Researched", f"Researched {found.name if found else event.get('key')}.",
                          True, floating=False, pos=False)

    def _era_reached(self, event):
        if not self._party(event.tag):
            return None
        return self._item(event, "gain", "New age!", f"A new age: {ERAS[event.get('era')][0]}.", True, floating=False,
                          pos=False)

    def _colony_founded(self, event):
        what, place = event.get("what", "colony"), self._place(event.pos)
        if self._party(event.tag):
            return self._item(event, "own", "Founded", f"Founded a {what} at {place}.", True)
        if not self._seen(event.pos):
            return None
        return self._item(event, "other", "Colony", f"{self._name(event.tag)} founded a {what} at {place}.")

    def _building_done(self, event):
        if not self._party(event.tag):
            return None
        key = event.get("what")
        name = BUILDINGS[key].name if key in BUILDINGS else str(key).capitalize()
        return self._item(event, "gain", "Built", f"{name} finished at {self._place(event.pos)}.", True)

    def _investment_done(self, event):
        if not self._party(event.tag):
            return None
        cost = self._costs.pop((event.tag, event.pos, "invest"), None)
        sentence = f"{self._place(event.pos)}: works raised to level {event.get('level')}" + \
            (f" for {ducats(cost)}." if cost else ".")
        return self._item(event, "own", "Upgraded", sentence, True)

    def _native_raid(self, event):
        if not self._party(event.tag):
            return None
        return self._item(event, "loss", "Raided!", f"Natives raided the colony at {self._place(event.pos)}.", True)

    def _pass_closed(self, event):
        return self._pass(event, "Winter closes the mountain passes.")

    def _pass_opened(self, event):
        return self._pass(event, "The mountain passes reopen.")

    def _pass(self, event, sentence):
        """Told once a season, wherever the passes are."""
        key = (event.kind, self.world.turn)
        if key in self._once:
            return None
        self._once = {k for k in self._once if k[1] >= self.world.turn} | {key}
        return self._item(event, "other", "", sentence, False, floating=False, pos=False)


_FEEDS = weakref.WeakKeyDictionary()
