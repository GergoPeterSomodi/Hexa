"""The event bus: how the rules tell the screens that something happened. Pygame-free, and never saved.

A system that changes something the player should notice calls ``world.bus.emit(kind, tag, pos, **data)``. The call
only appends an `Event` to a queue (and to a short history). Once a frame (and at the end of a season) the UI calls
``bus.drain()``, which hands every queued event to the handlers subscribed to its kind. Tests read ``bus.history``.

Two rules:
    handlers never change the world. Events are notifications: the AI and the season results stay deterministic
    (the behaviour oracle, tools/same_behaviour.py, would catch it). The one exception today is the "war declared
    on you" log line of the campaign app, which keeps the text and the place in the log it always had.
    the bus is never saved. ``CampaignWorld.save_state()`` leaves it out and ``_restore`` makes a fresh one.

The campaign's event kinds (``CAMPAIGN_KINDS``) and their fields. ``tag`` is the
country the event is about (the actor), ``pos`` the hex it happened on, and the rest goes to ``event.data``:

    message           text, shown, notice  a log line (shown: whether the player's log got it). ``notice`` names a line
                                         that has no event of its own (the action log shows those: see
                                         feed.NOTICES); pos is the hex it is about, if any
    province_captured tag=captor, pos    loser, by ("siege", "storm" or "peace")
    siege_progress    tag=besieger, pos  progress, need
    war_declared      tag=aggressor      target
    peace_made        tag, b             winner, moved (provinces that changed hands)
    unit_raised       tag, pos           what (the troop's name), id
    unit_lost         tag=owner, pos     what (the troop's name), why ("battle", "storm", "overrun", "disbanded",
                                         "deserted", "starved", "sunk", "evicted" or "surrendered")
    unit_deserted     tag                count, kinds ({name: n})
    debt_seized       tag                what ("castle at X")
    pass_closed       pos                name, id        (every pass, when winter begins)
    pass_opened       pos                name, id        (every pass, when winter ends)
    tech_researched   tag                key
    era_reached       tag                era
    colony_founded    tag, pos           what ("colony" or "trading post")
    building_done     tag, pos           what (a building key, "settlement" or "castle")
    investment_done   tag, pos           level (the works level now)
    season_ended      (GameManager)      turn
    money_spent       tag, pos           amount, reason ("raise", "build", "invest", "refit", "upgrade", "research")
    forage            tag, pos           (troops foraged in foreign land)
    native_raid       tag, pos           (natives raided a colony)
    unit_moved        tag=owner, pos=end ids (the stack's unit ids), path (every hex from start to end), naval, seen
                                         (per hex of the path: in the player's vision when the stack moved). The
                                         window replays these walks, see campaign/replay.py; the state is already final
    battle_started    tag=attacker, pos  defender, assault, name, year (a battle begins: both stacks stand on pos)
    battle_joined     tag=joiner, pos    side ("attacker" or "defender"), men (a stack joins its side's reserve)
    battle_fought     tag=attacker, pos  defender, days, morale {tag: share}, killed {tag: men}, wounded {tag: men};
                                         one per battle per season
    battle_ended      tag=attacker, pos  attacker, defender, winner, loser (tags; None for a draw: peace or gone score nothing),
                                         assault, how ("broke", "withdrew", "surrendered", "peace" or "gone"), seasons,
                                         name, year, killed {tag: men}, wounded {tag: men}, retreat (hex or None). Once per
                                         battle, after it has left world.battles. A contract: docs/design/war-goals-and-peace.md 3.4

``tech_researched`` carries the ``cost`` in research points; ``debt_seized`` the ``saving`` in ducats a season.

``bus.tap(handler)`` is the one other way to listen: a tap is called at once, inside ``emit``, with the event (the
campaign's ``resources`` tracker and ``feed`` use it, so they need no drain). A tap never changes the world either, and
an exception in one is caught (its traceback is logged once for each (tap, kind) with
``logging.getLogger("hexa").exception``; every failure is kept in ``bus.tap_errors``) so
that a bug in a screen's bookkeeping cannot stop a game; with the environment variable HEXA_DEBUG=1 it is raised
instead.
"""
import logging
import os
from collections import deque
from dataclasses import dataclass


CAMPAIGN_KINDS = (
    "message", "province_captured", "siege_progress", "war_declared", "peace_made", "unit_raised",
    "unit_lost", "unit_deserted", "debt_seized", "pass_closed", "pass_opened", "tech_researched", "era_reached",
    "colony_founded", "building_done", "investment_done", "season_ended", "money_spent", "forage", "native_raid",
    "unit_moved", "battle_started", "battle_joined", "battle_fought", "battle_ended",
)


@dataclass(frozen=True)
class Event:
    kind: str
    tag: object = None          # the country it is about
    pos: object = None          # the hex it happened on (floating text goes there)
    data: object = None         # a dict of the kind's other fields

    def get(self, name, default=None):
        return (self.data or {}).get(name, default)


class EventBus:
    """A queue of events, a bounded history and the handlers that get the queue when it is drained."""

    QUEUE = 5000        # events kept undrained; a headless game that never drains drops the oldest (see `dropped`)

    def __init__(self, history=500):
        self.queue = deque()
        self.history = deque(maxlen=history)
        self.dropped = 0
        self._handlers = {}         # kind (None: every kind) -> [handler]
        self._taps = []             # called at once on emit (see the module docstring)
        self.tap_errors = []        # the exceptions taps raised (kept few)
        self._reported = set()      # (tap, kind) whose traceback was logged already

    def emit(self, kind, tag=None, pos=None, **data):
        """Queue an event (and put it in the history). Returns it."""
        event = Event(kind, tag, pos, data)
        self.queue.append(event)
        self.history.append(event)
        while len(self.queue) > self.QUEUE:
            self.queue.popleft()
            self.dropped += 1
        for tap in self._taps:
            try:
                tap(event)
            except Exception as caught:         # a screen's bookkeeping must never stop the game
                if (tap, kind) not in self._reported:       # a tap that fails on every event logs once, not 5000 times
                    self._reported.add((tap, kind))
                    logging.getLogger("hexa").exception("an event tap failed on %r", kind)
                if os.environ.get("HEXA_DEBUG") == "1":         # developers want the crash, not a log line
                    raise
                self.tap_errors = (self.tap_errors + [caught])[-5:]
        return event

    def tap(self, handler):
        """Call ``handler(event)`` at once for every event emitted from now on. Returns handler."""
        self._taps.append(handler)
        return handler

    def untap(self, handler):
        if handler in self._taps:
            self._taps.remove(handler)

    def subscribe(self, kind, handler):
        """Call ``handler(event)`` for each drained event of this kind (kind None: every kind). Returns handler."""
        self._handlers.setdefault(kind, []).append(handler)
        return handler

    def unsubscribe(self, kind, handler):
        handlers = self._handlers.get(kind, [])
        if handler in handlers:
            handlers.remove(handler)

    def drain(self):
        """Hand the events queued so far to their handlers, oldest first. Returns them as a list.

        Events a handler emits wait for the next drain. If a handler raises, the events after that one stay
        queued."""
        done = []
        for _ in range(len(self.queue)):
            event = self.queue.popleft()
            done.append(event)
            for handler in list(self._handlers.get(event.kind, ())) + list(self._handlers.get(None, ())):
                handler(event)
        return done

    def of(self, kind):
        """The events of one kind in the history (a list, oldest first)."""
        return [e for e in self.history if e.kind == kind]

    def clear(self):
        self.queue.clear()
        self.history.clear()


def passes_changed(world, was_winter):
    """Emit ``pass_closed`` or ``pass_opened`` for every mountain pass if the season just changed to or from
    winter. Called by ``CampaignWorld.end_round`` right after the turn counter advances."""
    winter = world.winter()
    if winter == was_winter:
        return
    kind = "pass_closed" if winter else "pass_opened"
    for name, pid, edge, _closed in world.pass_edges():
        world.bus.emit(kind, None, min(edge), name=name, id=pid)
