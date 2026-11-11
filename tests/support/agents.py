"""Seeded random players that try every ``x_check`` / ``x`` pair, legal and illegal, and a judge that checks each try.

The contract (CLAUDE.md): a world exposes ``x_check(...) -> (ok, reason)`` next to ``x(...)``, which checks again
and then acts. So for every try:

- the check said no  ->  ``x`` returns something falsy (None or False), raises nothing, and the game state is
  exactly as before (same digest);
- the check said yes ->  ``x`` succeeds: it returns something truthy and raises nothing.

``move`` and ``attack`` have no ``_check``; their checks are ``reachable()`` and ``attack_options()``, which the
game itself uses to decide.

    Judge(world, digest)                      tries actions and keeps the disagreements (``digest=None``: only
                                              the return values are checked, for worlds too big to digest often)
    conquest_player(rng, judge)               a ``player(world)`` for games.play_conquest
    colony_player(rng, judge)                 a ``player(world)`` for games.play_colony
    campaign_player(rng, judge, tag)          plays one campaign country for a season (call before the AI)

Most tries use the player's own things; some use the enemy's (refused: not your turn / not yours) and some
target places nobody could reach. After its random tries the Conquest and Colonisation player lets the computer
finish its turn (``then_ai``), so games last and both sides build up instead of the random side just losing.
No pygame here.
"""
from collections import Counter

from hexa.hexgrid import within


class Judge:
    def __init__(self, world, digest=None):
        self.world, self.digest = world, digest
        self.steps = 0
        self.problems = []              # "step N: ..." for every disagreement, in order
        self.tried = Counter()          # (action name, allowed) -> tries
        self.crashed = False            # a check or an action raised (the problem is the last one)
        self._known = None              # digest of the world as it is now, if known

    def forget(self):
        """Something other than a judged action may have changed the world (the AI's turn): digest it again."""
        self._known = None

    def attempt(self, name, args, check, action):
        """Run ``check()`` and then ``action()`` and record any disagreement. An exception from either is
        recorded and raised again: the world can't be trusted after it."""
        self.steps += 1
        where = f"step {self.steps}: {name}({args})"
        try:
            verdict = check()
        except Exception as error:
            self.crashed = True
            self.problems.append(f"{where}: the check raised {type(error).__name__}: {error}")
            raise
        allowed = bool(verdict[0])
        self.tried[name, allowed] += 1
        before = None
        if not allowed and self.digest:
            before = self._known or self.digest(self.world)
        try:
            result = action()
        except Exception as error:
            self.crashed = True
            said = "allowed it" if allowed else f"refused it ({verdict[1]!r})"
            self.problems.append(f"{where} raised {type(error).__name__}: {error} although the check {said}")
            raise
        if allowed:
            self._known = None
            if not result:
                self.problems.append(f"{where} returned {result!r} although the check allowed it")
        else:
            if result:
                self.problems.append(f"{where} returned {result!r} although the check refused it ({verdict[1]!r})")
                self._known = None
            if before is not None:
                after = self.digest(self.world)
                self._known = after
                if after != before:
                    self.problems.append(f"{where} changed the game although the check refused it ({verdict[1]!r})")
        return result


def name_of(obj):
    """A short description of a unit, town, colony, province or village for failure messages."""
    kind = getattr(obj, "type", None) or getattr(obj, "kind", None)
    if hasattr(obj, "id") and kind is not None:
        return f"{obj.owner} {getattr(kind, 'key', kind)} #{obj.id} at {obj.pos}"
    if hasattr(obj, "tribe") and hasattr(obj, "burned"):
        return f"village of tribe {obj.tribe} at {obj.pos}"
    owner = getattr(obj, "owner", None)
    label = getattr(obj, "name", None) or type(obj).__name__.lower()
    return f"{owner} {label} at {getattr(obj, 'pos', '?')}"


def _pick(rng, mine, everything, own=0.85):
    """Usually one of `mine`, sometimes anything (most likely somebody else's)."""
    pool = mine if mine and rng.random() < own else everything
    return rng.choice(pool) if pool else None


def _somewhere(rng, pos, radius=5):
    """Any hex near pos, on the map or not."""
    return rng.choice(sorted(within(pos, radius)))


def _dest(rng, world, unit, legal=0.75, reach=None):
    reach = world.reachable(unit) if reach is None else reach
    if rng.random() < legal and len(reach) > 1:
        return rng.choice([p for p in reach if p != unit.pos])
    return _somewhere(rng, unit.pos)


# ----- Conquest -------------------------------------------------------------------------------------------------
def conquest_player(rng, judge, steps=8, then_ai=True):
    from hexa import ai

    def play(world):
        judge.forget()
        for _ in range(steps):
            if world.winner:
                return
            _conquest_step(world, rng, judge)
        if then_ai and not world.winner:
            for _ in ai.take_turn(world, world.current):
                pass
    return play


_CONQUEST_MOVES = ("move",) * 5 + ("attack",) * 2 + ("train",) * 2 + ("build",) * 2 + ("found",)


def _conquest_step(w, rng, judge):
    from hexa.rules import SETTLER, UNIT_TYPES, WORKER
    side = w.current
    kind = rng.choice(_CONQUEST_MOVES)
    if kind == "train":
        town = _pick(rng, w.towns_of(side), w.towns)
        unit_type = rng.choice(list(UNIT_TYPES.values()))
        judge.attempt("train", f"{name_of(town)}, {unit_type.key}", lambda: w.train_check(town, unit_type),
                      lambda: w.train(town, unit_type))
        return
    if not w.units:
        return
    favourite = {"build": WORKER, "found": SETTLER}.get(kind)
    mine = [u for u in w.units_of(side) if favourite is None or u.type is favourite] or w.units_of(side)
    unit = _pick(rng, mine, w.units)
    if kind == "build":
        judge.attempt("build", name_of(unit), lambda: w.build_check(unit), lambda: w.build(unit))
    elif kind == "found":
        judge.attempt("found_town", name_of(unit), lambda: w.found_check(unit), lambda: w.found_town(unit))
    elif kind == "move":
        dest = _dest(rng, w, unit)
        judge.attempt("move", f"{name_of(unit)}, {dest}",
                      lambda: (not w.winner and unit.owner == w.current and dest in w.reachable(unit), ""),
                      lambda: w.move(unit, dest))
    else:
        options = w.attack_options(unit)
        if options and rng.random() < 0.7:
            target = w.unit_at(rng.choice(list(options)))
        else:
            target = rng.choice(w.units)
        judge.attempt("attack", f"{name_of(unit)}, {name_of(target)}",
                      lambda: (target.pos in w.attack_options(unit), ""), lambda: w.attack(unit, target))


# ----- Colonisation ---------------------------------------------------------------------------------------------
def colony_player(rng, judge, steps=10, then_ai=True):
    from hexa.colony import ai

    def play(world):
        judge.forget()
        for _ in range(steps):
            if world.winner:
                return
            _colony_step(world, rng, judge)
        if then_ai and not world.winner:
            for _ in ai.take_turn(world, world.current):
                pass
    return play


_COLONY_MOVES = (("move",) * 6 + ("attack",) * 2 + ("train", "colonist", "grow", "stockade", "join", "gift", "trade",
                 "independence") + ("build",) * 2 + ("found",) * 2 + ("market",) * 2)
_MARKET = (("sell_furs",), ("sell_wood",), ("buy_food",))


def _colony_step(w, rng, judge):
    from hexa.colony.rules import BUYABLE, COLONISERS, COLONIST, PIONEER, SHIP, TRAINABLE
    side = w.current
    kind = rng.choice(_COLONY_MOVES)
    if kind == "independence":
        judge.attempt("declare_independence", "", w.independence_check, w.declare_independence)
        return
    if kind in ("gift", "trade"):
        villages = [v for v in w.villages if not v.burned]
        if not villages:
            return
        who = side if side in COLONISERS and rng.random() < 0.85 else rng.choice(COLONISERS)
        near = [v for v in villages if w.in_contact(who, v)]
        village = rng.choice(near if near and rng.random() < 0.7 else villages)
        check, action = (w.gift_check, w.gift) if kind == "gift" else (w.trade_check, w.trade)
        judge.attempt(kind, f"{who}, {name_of(village)}", lambda: check(who, village), lambda: action(who, village))
        return
    if kind in ("train", "colonist", "grow", "stockade"):
        colony = _pick(rng, w.colonies_of(side), w.colonies)
        if colony is None:
            return
        if kind == "train":
            unit_type = rng.choice(TRAINABLE)
            judge.attempt("train", f"{name_of(colony)}, {unit_type.key}", lambda: w.train_check(colony, unit_type),
                          lambda: w.train(colony, unit_type))
        else:
            check, action = {"colonist": (w.colonist_check, w.make_colonist), "grow": (w.grow_check, w.grow),
                             "stockade": (w.stockade_check, w.build_stockade)}[kind]
            judge.attempt(action.__name__, name_of(colony), lambda: check(colony), lambda: action(colony))
        return
    if not w.units:
        return
    favourite = {"build": PIONEER, "found": COLONIST, "join": COLONIST, "market": SHIP}.get(kind)
    mine = [u for u in w.units_of(side) if favourite is None or u.type is favourite] or w.units_of(side)
    unit = _pick(rng, mine, w.units)
    if kind == "build":
        judge.attempt("build", name_of(unit), lambda: w.build_check(unit), lambda: w.build(unit))
    elif kind == "found":
        judge.attempt("found_colony", name_of(unit), lambda: w.found_check(unit), lambda: w.found_colony(unit))
    elif kind == "join":
        judge.attempt("join", name_of(unit), lambda: w.join_check(unit), lambda: w.join(unit))
    elif kind == "market":
        deal = rng.choice(_MARKET + tuple(("buy", t) for t in BUYABLE))
        text = deal[0] + (f" {deal[1].key}" if len(deal) > 1 else "")
        judge.attempt("market", f"{name_of(unit)}, {text}", lambda: w.market_check(unit, deal),
                      lambda: w.market(unit, deal))
    elif kind == "move":
        reach = w.reachable(unit)
        if unit.type.naval and rng.random() < 0.4:
            dest = max(reach, key=lambda p: (p[0], p))           # sail east, towards the homeland
        else:
            dest = _dest(rng, w, unit, reach=reach)
        judge.attempt("move", f"{name_of(unit)}, {dest}",
                      lambda: (not w.winner and unit.owner == w.current and dest in w.reachable(unit), ""),
                      lambda: w.move(unit, dest))
    else:
        options = w.attack_options(unit)
        if options and rng.random() < 0.7:
            target = rng.choice(list(options))
        else:
            target = rng.choice([u.pos for u in w.units] + [c.pos for c in w.colonies] + [v.pos for v in w.villages])
        judge.attempt("attack", f"{name_of(unit)}, {target}", lambda: (target in w.attack_options(unit), ""),
                      lambda: w.attack(unit, target))


# ----- Age of Discovery -----------------------------------------------------------------------------------------
_CAMPAIGN_MOVES = (("move",) * 4 + ("improve", "recruit", "recruit", "build", "build", "found", "forage", "forage",
                   "war", "refit", "upgrade", "merchant"))
_BUILD_KEYS = None


def campaign_player(rng, judge, tag, steps=10):
    """A ``player(world)`` that tries `steps` random actions for country `tag` (and a few for others)."""
    def play(world):
        judge.forget()
        for _ in range(steps):
            if world.over or not world.countries[tag].alive:
                return
            _campaign_step(world, rng, judge, tag)
    return play


def _stacks(w):
    """{(pos, owner): [units]} of the units standing on the map."""
    found = {}
    for u in w.units:
        if u.carrier is None:
            found.setdefault((u.pos, u.owner), []).append(u)
    return found


def _campaign_step(w, rng, judge, tag):
    global _BUILD_KEYS
    from hexa.campaign.data import BUILDINGS, COLONIST, troop
    if _BUILD_KEYS is None:
        _BUILD_KEYS = ("settlement", "castle") + tuple(BUILDINGS)
    kind = rng.choice(_CAMPAIGN_MOVES)
    who = tag if rng.random() < 0.85 else rng.choice(sorted(w.countries))
    if kind in ("improve", "recruit", "build"):
        own = w.provinces_of(who)
        prov = rng.choice(own) if own and rng.random() < 0.9 else w.provinces[rng.choice(sorted(w.provinces))]
        if kind == "improve":
            judge.attempt("invest", f"{who}, {name_of(prov)}", lambda: w.invest_check(who, prov),
                          lambda: w.invest(who, prov))
        elif kind == "build":
            key = rng.choice(_BUILD_KEYS)
            judge.attempt("build", f"{who}, {name_of(prov)}, {key}", lambda: w.build_check(who, prov, key),
                          lambda: w.build(who, prov, key))
        else:
            options = w.raise_options(who)
            unit_kind = rng.choice(options) if rng.random() < 0.9 else troop("infantry", rng.choice((1, 2, 3)))
            judge.attempt("recruit", f"{who}, {name_of(prov)}, {unit_kind.key}",
                          lambda: w.recruit_check(who, prov, unit_kind), lambda: w.recruit(who, prov, unit_kind))
        return
    if kind == "war":
        others = sorted(w.neighbours_of(who)) if rng.random() < 0.6 else sorted(w.countries)
        if not others:
            return
        enemy = rng.choice(others)
        judge.attempt("declare_war", f"{who}, {enemy}", lambda: w.war_check(who, enemy),
                      lambda: w.declare_war(who, enemy))
        return
    if kind == "merchant":
        if not w.routes:
            return
        route = rng.choice(w.routes)
        options = w.merchant_options(who, route)
        if options:
            good, src = options[0][0], options[0][1]
        else:       # none of our markets on the route (the check must say no) or nothing worth carrying on it
            from hexa.campaign.data import GOODS
            good, src = rng.choice(sorted(g for g, info in GOODS.items() if info.kind != "money")), route.a
        judge.attempt("send_merchant", f"{who}, route {route.id}, {good}", lambda: w.send_merchant_check(who, route),
                      lambda: w.send_merchant(who, route, good, src))
        return
    stacks = _stacks(w)
    if not stacks:
        return
    mine = [k for k in stacks if k[1] == who]
    key = _pick(rng, mine, sorted(stacks), own=0.9)
    group = stacks[key]
    if kind == "found":
        colonists = [u for u in w.units_of(who) if u.kind is COLONIST]
        unit = rng.choice(colonists) if colonists and rng.random() < 0.8 else rng.choice(group)
        post = rng.random() < 0.3
        judge.attempt("found", f"{name_of(unit)}, trading_post={post}", lambda: w.found_check(unit, post),
                      lambda: w.found(unit, post))
    elif kind == "forage":
        judge.attempt("forage", f"stack of {len(group)} at {key[0]} ({key[1]})", lambda: w.forage_check(group),
                      lambda: w.forage(group))
    elif kind in ("refit", "upgrade"):
        unit = rng.choice(group)
        if kind == "refit":
            judge.attempt("refit", name_of(unit), lambda: w.refit_check(unit), lambda: w.refit(unit))
        else:
            stat = rng.choice(("attack", "defense"))
            judge.attempt("upgrade", f"{name_of(unit)}, {stat}", lambda: w.upgrade_check(unit, stat),
                          lambda: w.upgrade(unit, stat))
    else:
        reach = w.reachable_group(group)
        if rng.random() < 0.8 and len(reach) > 1:
            dest = rng.choice([p for p in reach if p != key[0]])
        else:
            dest = _somewhere(rng, key[0], 8)
        judge.attempt("move_group", f"stack of {len(group)} at {key[0]} ({key[1]}), {dest}",
                      lambda: (not w.over and dest in w.reachable_group(group), ""),
                      lambda: w.move_group(group, dest))
