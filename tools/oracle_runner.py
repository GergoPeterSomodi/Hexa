"""Plays one suite of the behaviour oracle (tools/same_behaviour.py) and prints a digest after every step.

    python tools/oracle_runner.py <checkout> <suite> [<seed> [<steps>]]

Self-contained on purpose: it imports nothing from tests/ or tools/ and uses only the public API of the
checkout's own hexa package (World, ColonyWorld, CampaignWorld, ai.take_turn, ai.run, end_turn, end_round, the
x_check/x actions). The digest code below is a trimmed copy of tests/support/digests.py. So the base checkout of
a refactor needs nothing but its hexa/ folder, and a refactor of tests/support (a new game manager, say) cannot
change what the oracle plays.

Each output line is "<step> <turn> <sha256>". For the campaign the per-step digest covers the game state
(every public attribute of the world, no caches); the generated map (STATIC) is hashed on its own, once at
step 0 and once more at the last step, and folded into those two lines.

Suites: campaign (Europe), random (a random map), colony, conquest, and the prepared campaign states
"midgame" (turn 160, techs for the next age, forced wars, peace, refits, upgrades, disbanding) and "debt"
(countries far over their debt limit: desertion, disbanding, seizure).
"""
import hashlib
import itertools
import os
import random
import sys
import types

# The generated map: hashed at the start and the end, not at every step.
STATIC = ("roads", "road_paths", "rivers", "river_at", "cities", "landmass", "sea_body", "colonial",
          "cols", "rows", "map", "seed")
_PLAIN = (type(None), bool, int, float, str, bytes)


class _Encoder:
    def __init__(self, sink):
        self.sink, self.memo, self.keep = sink, {}, []

    def ref(self, obj):
        n = self.memo.get(id(obj))
        if n is not None:
            self.sink.append(f"@{n}")
            return True
        self.memo[id(obj)] = len(self.memo)
        self.keep.append(obj)
        return False

    def encode(self, obj):
        out, t = self.sink, type(obj)
        if t in _PLAIN:
            out.append(repr(obj))
        elif t is tuple:
            if all(type(e) in _PLAIN for e in obj):
                out.append(repr(obj))
                return
            out.append("(")
            for e in obj:
                self.encode(e)
            out.append(")")
        elif t is list:
            if not self.ref(obj):
                out.append("[")
                for e in obj:
                    self.encode(e)
                out.append("]")
        elif t is dict:
            if not self.ref(obj):
                out.append("{")
                for k, v in obj.items():
                    self.encode(k)
                    self.encode(v)
                out.append("}")
        elif t is set or t is frozenset:
            if t is frozenset or not self.ref(obj):
                out.append("s{" if t is set else "f{")
                out.extend(sorted(_element(e) for e in obj))
                out.append("}")
        elif t is random.Random:
            if not self.ref(obj):
                out.append("Random")
                self.encode(obj.getstate())
        elif t is itertools.count:
            out.append(repr(obj))
        elif t is types.ModuleType or t is types.FunctionType or t is type:
            out.append(f"<{t.__name__} {getattr(obj, '__module__', '')}.{obj.__name__}>")
        elif hasattr(obj, "__dict__"):
            if not self.ref(obj):
                out.append(f"<{t.__module__}.{t.__qualname__}")
                attrs = vars(obj)
                for name in sorted(attrs):
                    out.append(name)
                    self.encode(attrs[name])
                out.append(">")
        else:
            raise TypeError(f"digest: don't know how to write a {t.__module__}.{t.__qualname__}")


def _element(obj):
    if type(obj) in _PLAIN or (type(obj) is tuple and all(type(e) in _PLAIN for e in obj)):
        return repr(obj)
    tokens = []
    _Encoder(tokens).encode(obj)
    return "\x1e".join(tokens)


def canonical(obj):
    tokens = []
    _Encoder(tokens).encode(obj)
    h = hashlib.sha256()
    for i in range(0, len(tokens), 4096):
        h.update("\x1f".join(tokens[i:i + 4096]).encode("utf-8", "surrogatepass"))
        h.update(b"\x1f")
    return h.hexdigest()


def static_digest(world):
    return canonical({name: getattr(world, name, None) for name in STATIC})


def state(world):
    """The game state of a world: everything public (and the unit id counter), minus the generated map, the
    map source and every private cache."""
    skip = set(STATIC) | {"geo", "bus"}
    return {k: v for k, v in vars(world).items() if k not in skip and (not k.startswith("_") or k == "_ids")}


class Printer:
    def __init__(self, world, campaign):
        self.world, self.campaign, self.n = world, campaign, 0

    def show(self, last=False):
        world = self.world
        if self.campaign:
            digest = canonical(state(world))
            if self.n == 0 or last:
                digest = canonical([digest, static_digest(world)])
        else:
            digest = canonical(dict(vars(world)))
        print(self.n, world.turn, digest, flush=True)
        self.n += 1


def campaign_world(mode, seed):
    from hexa.campaign.world import CampaignWorld
    world = CampaignWorld(seed, map="random") if mode == "random" else CampaignWorld(seed)
    world.player = None
    return world


def season(world):
    from hexa.campaign import ai
    for tag in list(world.countries):
        ai.run(world, tag)
    world.end_round()


def play_campaign(mode, seed, steps):
    world = campaign_world(mode, seed)
    out = Printer(world, True)
    out.show()
    for n in range(steps):
        season(world)
        out.show(last=n == steps - 1)


def play_midgame(seed, steps):
    """Turn 160 with every country holding the techs of its age (so the next age comes at once), forced wars,
    peace on every kind of terms, refits, upgrades and disbanding."""
    from hexa.campaign import tech
    world = campaign_world("campaign", seed)
    out = Printer(world, True)
    world.turn = 160
    for tag in sorted(world.countries):
        country = world.countries[tag]
        country.treasury += 4000
        for key in sorted(tech.TECHS):
            if tech.TECHS[key].era <= country.era:
                world.grant_tech(tag, key)
        world.grant_tech(tag, "cartography")
        world.provinces[country.capital].buildings["barracks"] = 1       # so that troops can be drilled
    out.show()
    for tag in sorted(world.countries):
        for other in sorted(world.neighbours_of(tag))[:2]:
            world.declare_war(tag, other)
    out.show()
    for _ in range(4):
        season(world)
        out.show()
    terms = ("take", "white", "yield")
    for i, war in enumerate(list(world.wars)):
        if i % 4 == 3:
            world.peace(war.a, war.b, winner=war.a)
        else:
            world.peace_offer(war.a, war.b, terms[i % 3])
    out.show()
    for tag in sorted(world.countries):
        for unit in list(world.units_of(tag))[:6]:
            for stat in ("attack", "defense"):
                if world.upgrade_check(unit, stat)[0]:
                    world.upgrade(unit, stat)
            if world.refit_check(unit)[0]:
                world.refit(unit)
    out.show()
    for tag in sorted(world.countries)[:6]:
        world.disband(tag, 6.0)
    out.show()
    for n in range(steps):
        season(world)
        out.show(last=n == steps - 1)


def play_debt(seed, steps):
    """Armies built by three AI seasons, then half the countries lose their troops and all fall far below their
    debt limit: desertion, disbanding and the creditors seizing buildings."""
    world = campaign_world("campaign", seed)
    out = Printer(world, True)
    out.show()
    for _ in range(3):
        season(world)
    out.show()
    for i, tag in enumerate(sorted(world.countries)):
        country = world.countries[tag]
        if i % 2:
            world.disband(tag, 1e9)
            for prov in world.provinces_of(tag):        # costly castles and towns for the creditors to take
                prov.castle, prov.settlement = 3, max(prov.settlement, 2)
        country.treasury = -200000.0
    out.show()
    for n in range(steps):
        season(world)
        out.show(last=n == steps - 1)


def play_conquest(seed):
    from hexa import ai
    from hexa.world import World
    world = World(seed)
    out = Printer(world, False)
    while not world.winner:
        for _ in ai.take_turn(world, world.current):
            pass
        world.end_turn()
        out.show()


def play_colony(seed, rounds):
    from hexa.colony import ai
    from hexa.colony.world import ColonyWorld
    world = ColonyWorld(seed)
    out = Printer(world, False)
    while not world.winner and world.turn <= rounds:
        for _ in ai.take_turn(world, world.current):
            pass
        world.end_turn()
        out.show()


def main(argv):
    checkout, suite = argv[0], argv[1]
    seed = int(argv[2]) if len(argv) > 2 else 0
    steps = int(argv[3]) if len(argv) > 3 else 0
    sys.path[:] = [p for p in sys.path if os.path.normcase(os.path.abspath(p or ".")) !=
                   os.path.normcase(os.path.dirname(os.path.abspath(__file__)))]
    sys.path.insert(0, checkout)
    import hexa
    if os.path.normcase(os.path.realpath(os.path.dirname(hexa.__file__))) != \
            os.path.normcase(os.path.realpath(os.path.join(checkout, "hexa"))):
        print("wrong hexa: " + hexa.__file__, file=sys.stderr)
        return 3
    if suite in ("campaign", "random"):
        play_campaign(suite, seed, steps)
    elif suite == "midgame":
        play_midgame(seed, steps)
    elif suite == "debt":
        play_debt(seed, steps)
    elif suite == "colony":
        play_colony(seed, steps)
    elif suite == "conquest":
        play_conquest(seed)
    else:
        print("unknown suite " + suite, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
