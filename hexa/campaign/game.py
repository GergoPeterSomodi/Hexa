"""The game manager: one game of Age of Discovery without a window. Pygame-free.

It owns the world (and through it the event bus) and the things that happen to a whole game: starting a new one,
loading and saving, the autosave policy, and the end of a season. The app (campaign/app.py) draws and takes
input, and calls this for everything else; tests and tools play seasons through it too.

``end_season()`` runs one season in this fixed order:

    1. ``world.settle_preview()``   put back the incomes of the last real season (a tax preview may be on show)
       ``tracker.begin_season()``   the resource baseline (campaign/resources.py): the chips' deltas count from here
    2. ``ai.run`` for every country except the player's (``player_ai=True``: for the player's too)
    3. ``world.end_round()``        logistics, sieges, war timeouts, economy, debt, growth, research, turn counter
       ``tracker.round_done()``     keep the incomes that season collected (the ducats hover card's lines)
    4. ``orders()``                 the caller's end-of-season orders hook (the app's march reminders)
    5. the autosave                 if one is due
    6. ``world.ensure_markets()``   rebuild the markets the season changed (the screens no longer do it in draw())
    7. ``season_ended`` is emitted on the bus

The app drains the bus afterwards (``world.bus.drain()``) so its subscribers see this season's events.
"""
from typing import NamedTuple, Optional

from . import ai, feed, resources, saves
from .world import CampaignWorld


class SeasonResult(NamedTuple):
    saved: bool                         # an autosave was written
    error: Optional[Exception]          # why the autosave failed (one of saves.SAVE_ERRORS), if it did


class GameManager:
    def __init__(self, world, autosave_every=0):
        self.world = world
        self.autosave_every = autosave_every        # seasons between autosaves; 0 is off (see settings.AUTOSAVE_TURNS)
        self.tracker = resources.of(world)          # the top bar's numbers (never saved)
        self.feed = feed.of(world)                  # floating text and the action log (never saved)

    @classmethod
    def new(cls, seed=1480, map="europe", player=None, autosave_every=0):
        return cls(CampaignWorld(seed, player=player, map=map), autosave_every)

    @classmethod
    def load(cls, slot, autosave_every=0):
        """The game saved in a slot, or None if it is empty or cannot be loaded (saves.load says so on stderr)."""
        world = saves.load(slot)
        return cls(world, autosave_every) if world is not None else None

    @property
    def bus(self):
        return self.world.bus

    def save(self, slot):
        """Write the game to a slot. Raises one of ``saves.SAVE_ERRORS`` if it cannot."""
        return saves.save(self.world, slot)

    def autosave(self):
        """Write the autosave if one is due (every `autosave_every` seasons, with a country chosen, while the game
        is on). Returns whether it wrote one; raises one of ``saves.SAVE_ERRORS`` if it could not."""
        world, every = self.world, self.autosave_every
        if not (every and world.player and world.turn % every == 1 and not world.over):
            return False
        saves.save(world, "auto")
        return True

    def end_season(self, player_ai=False, orders=None):
        """Play the end of a season in the order of the module docstring. Returns a `SeasonResult`."""
        world = self.world
        world.settle_preview()
        self.tracker.begin_season()
        for tag in list(world.countries):
            if player_ai or tag != world.player:
                ai.run(world, tag)
        world.end_round()
        self.tracker.round_done()
        if orders:
            orders()
        saved, error = False, None
        try:
            saved = self.autosave()
        except saves.SAVE_ERRORS as caught:
            error = caught
        world.ensure_markets()
        world.bus.emit("season_ended", world.player, turn=world.turn)
        return SeasonResult(saved, error)
