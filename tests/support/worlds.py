"""Campaign worlds for tests. Building the real map takes seconds, so most tests share one read-only copy.

    europe()             the shared 1480 world, built once per process. Read it, never change it.
    fresh(player)        a new Europe world you may change (cheap: restored from the world module's snapshot)
    random_world(seed)   a shared read-only random world, built once per seed. To change one, build your own
                         with ``CampaignWorld(seed, map="random")``.
    play_seasons(w, n)   let the AI play n seasons
    pristine(w)          a guard that notices if a shared world was changed; call ``.check()`` in tearDownModule

No pygame here.
"""
import hashlib
import pickle

from hexa.campaign import ai
from hexa.campaign.world import CampaignWorld

_EUROPE = None
_RANDOM = {}

# The game state a pristine guard compares. Lazy caches (_owned, _sea_cache, _known_world, ...) and the map
# source are left out on purpose: reading a world may fill them without changing the game.
_STATE = ("turn", "version", "player", "over", "provinces", "countries", "units", "wars", "routes", "markets",
          "log", "terrain", "visible")


def europe():
    """The shared Europe world (read-only). Use ``fresh()`` for a world a test changes."""
    global _EUROPE
    if _EUROPE is None:
        _EUROPE = CampaignWorld()
    return _EUROPE


def fresh(player="POR"):
    """A new Europe world a test may change."""
    return CampaignWorld(player=player)


def random_world(seed):
    """The shared random world for this seed (read-only), built on first use."""
    if seed not in _RANDOM:
        _RANDOM[seed] = CampaignWorld(seed, map="random")
    return _RANDOM[seed]


def play_seasons(world, n, player_ai=True):
    """Let the AI move every country for n seasons, ending each round. With ``player_ai=False`` the player's
    own country is left alone, as in a real game. Returns the world."""
    for _ in range(n):
        for tag in list(world.countries):
            if player_ai or tag != world.player:
                ai.run(world, tag)
        world.end_round()
    return world


def digest(world):
    """A hash of the world's game state (not its caches)."""
    state = {name: getattr(world, name) for name in _STATE if hasattr(world, name)}
    state["rng"] = world.rng.getstate()
    return hashlib.sha256(pickle.dumps(state, protocol=pickle.HIGHEST_PROTOCOL)).hexdigest()


class Pristine:
    """What a shared world looked like when it was taken (turn, version, digest). ``check()`` fails if it changed."""

    def __init__(self, world, name="the shared world"):
        self.world, self.name = world, name
        self.turn, self.version, self.digest = world.turn, world.version, digest(world)

    def check(self):
        w = self.world
        problems = []
        if w.turn != self.turn:
            problems.append(f"turn {self.turn} -> {w.turn}")
        if w.version != self.version:
            problems.append(f"version {self.version} -> {w.version}")
        if not problems and digest(w) != self.digest:
            problems.append("game state changed")
        if problems:
            raise AssertionError(f"{self.name} was modified by a test ({'; '.join(problems)}); "
                                 f"tests that change a world must use fresh() instead")


def pristine(world, name="the shared world"):
    return Pristine(world, name)
