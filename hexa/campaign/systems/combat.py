"""Combat: how strong a unit is in a fight, and how a battle's day is fought. Functions taking ``world``.

``attack_value`` and ``defense_value`` are the values today's one-shot battle (war.battle) uses, and the day rules
build on them: terrain, castles, ranks, drills, techs, ideas and the general's trait all come in here. ``general``
finds the general among some units.

A day (battle slice 1, spec section 3.4) is ``fight_day``: ``deploy`` fills the three lanes from the reserve; ``fire``,
``shock`` and ``flanks`` work out every fighter's damage from the state at the start of the phase and apply it all at
once; ``morale`` routs regiments and ``breaker`` names the army that breaks; ``pursuit`` finishes a broken army.
``army_morale`` is the battle's measure of a side. Nothing here is called by the game yet: the battle is wired in by
PR 3. A day writes only the battle object, unit ``hp`` and ``morale``, ``prov.garrison`` and the units it kills
(``world.kill``). Imports point down: never world.py, ui, render or pygame.
"""
from ..data import (BACKLINE_LOSS, BATTLE_LOG, BREAK, CASTLE_DEFENSE, CENTRE_SHOCK, CROSSING_PENALTY, DICE, FIGHT_ATTACK,
                    FIGHT_DEFENSE, FIRE_LOSS, FLANK_BONUS, FLANK_MORALE, FRONT_DRAIN, GARRISON_MEN, GENERAL, GENERAL_BONUS,
                    GENERAL_MORALE, HUNGER_DRAIN, MEN,
                    MORALE_PER_LOSS, NARROW_TERRAIN, OPEN_GROUND, PIKES_VS_HORSE, PURSUIT, PURSUIT_FOOT, RESERVE_DRAIN,
                    HIT_SPREAD, RESERVE_SHAKEN, SHOCK_LOSS, SHOT_LOSS, STANCE, TERRAIN, UPHILL_PENALTY, WOUNDED_SHARE)
from ..state import Garrison

# The day writes only the battle object, unit hp and morale, prov.garrison and the units it kills.
OWNS = ("battles", "units", "provinces")
CENTRE = 1
FILL_ORDER = (CENTRE, 0, 2)     # lanes in the order they are filled and aimed at: centre, left, right


def general(world, units):
    return next((u for u in units if u.kind is GENERAL), None)


def attack_value(world, unit, fight, general):
    tag, branch = unit.owner, unit.kind.branch
    flat = unit.kind.attack + unit.atk_up + world.bonus(tag, f"{branch}_attack")
    value = flat * FIGHT_ATTACK[branch][fight] * unit.rank[2] * (1 + world.bonus(tag, branch))
    if general and (general.trait == fight or (general.trait == "cavalry" and branch == "cavalry")):
        value *= 1 + GENERAL_BONUS
    return value


def defense_value(world, unit, fight, prov, castle, versus, general, ground=True):
    """How well a unit holds. ``ground`` says whether the hex's terrain defence counts: only for the side that held the
    hex when the battle began (the defender and its joiners, decision 2026-11-13). The attacker stood on the same ground
    and gets none. A castle's bonus in an assault is the garrison's, and stays as it is."""
    tag, branch = unit.owner, unit.kind.branch
    value = (unit.kind.defense + unit.def_up) * FIGHT_DEFENSE[branch][fight] * unit.rank[2]
    if fight == "garrison":
        value *= 1 + CASTLE_DEFENSE * castle
    elif ground:
        value *= 1 + TERRAIN[prov.terrain].defense
    if branch == "infantry" and versus == "cavalry":
        value *= PIKES_VS_HORSE * (1 + world.bonus(tag, "vs_horse"))
    value *= 1 + world.bonus(tag, branch)
    if general and general.trait in ("defense", fight):
        value *= 1 + GENERAL_BONUS
    return value


# ----- the battle's day (battle slice 1) -------------------------------------------------------------------

def lane_open(prov, lane):
    """The right lane is closed on narrow ground: only two lanes fight there, and no flank comes through it."""
    return not (lane == 2 and prov.terrain in NARROW_TERRAIN)


def key_of(fighter):
    """A fighter's key in its battle: the unit id, or "garrison" for a castle's garrison."""
    return "garrison" if isinstance(fighter, Garrison) else fighter.id


def men_per_hp(fighter):
    """The men one hit point of a fighter stands for."""
    return GARRISON_MEN if isinstance(fighter, Garrison) else MEN / max(1, fighter.kind.hp)


def garrison_fights(world, battle):
    """The garrison holds the defender's centre: an assault, and the castle still has men and morale."""
    prov = world.provinces[battle.pos]
    return battle.assault and prov.castle > 0 and prov.garrison > 0 and battle.garrison_morale > 0


def _war_units(world, battle, tag):
    """A side's live war units on the hex, by id."""
    return sorted((u for u in world.units_at(battle.pos) if u.kind.war and u.owner == tag and u.hp > 0),
                  key=lambda u: u.id)


def _side_men(world, battle, tag):
    """The men of a side on the hex: its live war units and, for the defender in an assault, the garrison."""
    men = sum(u.men for u in _war_units(world, battle, tag))
    if tag == battle.defender and battle.assault:
        men += GARRISON_MEN * world.provinces[battle.pos].garrison
    return men


def battle_strength(world, battle, tag):
    """A side's strength in a battle: its men at the start times its strength morale (every regiment on the hex, the
    reserve included). The one measure the AI (ai.py) and the stats tool (tools/battle_stats.py) compare sides by."""
    return strength_morale(world, battle, tag) * battle.men0.get(tag, 0)


def strength_morale(world, battle, tag):
    """A side's morale over every regiment it has on the hex, 0 to 1: the sum of morale times men over its war units and
    garrison (routed ones counting 0), over the men it went in with (``battle.men0``). Reserves count here at full weight."""
    base = battle.men0.get(tag, 0)
    if base <= 0:
        return 0.0
    total = sum(u.morale * u.men for u in _war_units(world, battle, tag) if u.id not in battle.routed)
    if tag == battle.defender and battle.assault:
        total += battle.garrison_morale * GARRISON_MEN * world.provinces[battle.pos].garrison
    return min(1.0, total / base)


def _front(world, battle, tag):
    """(morale, men) of the regiments in a side's lanes, and of the garrison when it holds the centre."""
    by_id = {u.id: u for u in _war_units(world, battle, tag)}
    out = []
    for key in battle.lanes.get(tag, (None, None, None)):
        if key is None:
            continue
        if key == "garrison":
            out.append((battle.garrison_morale, GARRISON_MEN * world.provinces[battle.pos].garrison))
        elif key in by_id and key not in battle.routed:
            out.append((by_id[key].morale, by_id[key].men))
    return out


def army_morale(world, battle, tag):
    """A side's army morale for the break test, 0 to 1: the men-weighted average morale of the regiments in its lanes (the
    front line, owner's refinement 2026-11-13). Reserves are left out: an army breaks when its front breaks. 0 when no
    regiment is in a lane."""
    front = _front(world, battle, tag)
    total = sum(men for _, men in front)
    if total <= 0:
        return 0.0
    return min(1.0, sum(morale * men for morale, men in front) / total)


def record(world, battle, kind, **fields):
    """Append one structured log record to the battle (kind plus numbers and tags; the text is made when it is shown,
    see battlelog.py). The log keeps its last BATTLE_LOG records."""
    battle.log.append({"kind": kind, "turn": world.turn, "day": battle.days, **fields})
    del battle.log[:-BATTLE_LOG]


def _shock(world, battle, tag):
    """A broken centre shakes every regiment of its side once (CENTRE_SHOCK). One that reaches 0 routs."""
    for unit in _war_units(world, battle, tag):
        if unit.id in battle.routed:
            continue
        unit.morale = max(0.0, unit.morale - CENTRE_SHOCK)
        if unit.morale <= 0:
            _rout(battle, tag, unit.id)


def _hold(battle, tag, lanes):
    """Remember the lanes that have held a regiment. A lane that never had one (a side with fewer regiments than lanes) is
    open ground, not a broken lane: the enemy wheels round it (flanks), but it does not break the army."""
    held = battle.held.setdefault(tag, [])
    for lane, key in enumerate(lanes):
        if key is not None and lane not in held:
            held.append(lane)


def _lane_breaks(world, battle, tag, lanes, prov, units):
    """After the day's fill (battle day > 0): the open lanes that have held a regiment and are still empty have no reserve to
    fill them, so they are broken. A lane that breaks now is logged ("lane_broken", owner's refinement 2026-11-13). A newly
    broken centre shocks the side once. Each day a flank stays broken, its centre regiment loses FLANK_MORALE."""
    now = [lane for lane in battle.held.get(tag, []) if lane_open(prov, lane) and lanes[lane] is None]
    before = battle.broken.get(tag, [])
    battle.broken[tag] = now
    for lane in now:
        if lane not in before:
            record(world, battle, "lane_broken", side=tag, lane=lane)
            if lane == CENTRE:
                _shock(world, battle, tag)
    if any(lane != CENTRE for lane in now):
        centre = lanes[CENTRE]
        if centre == "garrison":
            battle.garrison_morale = max(0.0, battle.garrison_morale - FLANK_MORALE)
        elif centre is not None and centre not in battle.routed:
            unit = next((u for u in units if u.id == centre), None)
            if unit is not None:
                unit.morale = max(0.0, unit.morale - FLANK_MORALE)
                if unit.morale <= 0:
                    _rout(battle, tag, centre)


def _lane_rank(world, unit, lane, prov, general_here):
    """Sort key for filling a lane: infantry first in the centre and cavalry on the flanks, artillery last, then the
    best defence, then the lowest id."""
    branch = unit.kind.branch
    if branch == "artillery":
        tier = 2
    elif branch == ("infantry" if lane == CENTRE else "cavalry"):
        tier = 0
    else:
        tier = 1
    fight = "open" if prov.terrain in OPEN_GROUND else "rough"
    return (tier, -defense_value(world, unit, fight, prov, 0, None, general_here), unit.id)


def deploy(world, battle):
    """Fill every open lane that is empty from its side's reserve, centre first. A dead or routed regiment leaves its
    lane first. The defender's centre is the garrison while it stands in an assault, so its field units take the
    flanks. The side's men at the start (``men0``) are set the first time."""
    prov = world.provinces[battle.pos]
    fights = garrison_fights(world, battle)
    moved = set()
    for tag in (battle.attacker, battle.defender):
        battle.men0.setdefault(tag, _side_men(world, battle, tag))
        lanes = battle.lanes.setdefault(tag, [None, None, None])
        if tag == battle.defender:
            if fights:
                lanes[CENTRE] = "garrison"
            elif lanes[CENTRE] == "garrison":
                lanes[CENTRE] = None
        units = _war_units(world, battle, tag)
        alive = {u.id for u in units}
        for lane in range(3):
            uid = lanes[lane]
            if uid is not None and uid != "garrison" and (uid not in alive or uid in battle.routed):
                lanes[lane] = None
            if not lane_open(prov, lane):
                lanes[lane] = None
        slots = (0, 2) if fights and tag == battle.defender else FILL_ORDER
        general_here = general(world, [u for u in world.units_at(battle.pos) if u.owner == tag])
        reserve = [u for u in units if u.id not in lanes and u.id not in battle.routed]
        for lane in slots:
            if lanes[lane] is None and lane_open(prov, lane) and reserve:
                pick = min(reserve, key=lambda u: _lane_rank(world, u, lane, prov, general_here))
                reserve.remove(pick)
                lanes[lane] = pick.id
                if battle.days > 0:             # a reserve that moves up into a broken lane arrives shaken (decision 2026-11-13)
                    moved.add(pick.id)
        _hold(battle, tag, lanes)
        if battle.days > 0:
            _lane_breaks(world, battle, tag, lanes, prov, units)
    return moved


def _pike(attacker, target):
    """Infantry striking cavalry gets the pike bonus (infantry defending against horse is in defense_value)."""
    return PIKES_VS_HORSE if attacker.kind.branch == "infantry" and target.kind.branch == "cavalry" else 1.0


def _rout(battle, tag, key):
    """A fighter leaves its lane. A regiment stays on the hex in ``battle.routed``; a garrison just stops holding."""
    lanes = battle.lanes[tag]
    for lane, held in enumerate(lanes):
        if held == key:
            lanes[lane] = None
    if key != "garrison":
        battle.routed.add(key)


def day_multiplier(world, battle, tag, roll):
    """The share of its damage a side deals today, from its d6 roll (owner decision 2026-11-13). The one place that makes
    it: generals and cards may add +1 or a re-roll here later."""
    return DICE[roll]


class _Day:
    """One day's working state: who stands where at dawn, the fighters that are left, and the hp each has lost."""

    def __init__(self, world, battle, shaken=(), rolls=None):
        self.world, self.battle = world, battle
        self.shaken = set(shaken)          # the regiments that moved up into a lane today (RESERVE_SHAKEN, this day only)
        self.mult = {tag: day_multiplier(world, battle, tag, roll) for tag, roll in (rolls or {}).items()}
        prov = self.prov = world.provinces[battle.pos]
        fights = garrison_fights(world, battle)     # the assault is fought only while the garrison holds (item 7)
        self.fight = "assault" if fights else ("open" if prov.terrain in OPEN_GROUND else "rough")
        self.castle = prov.castle if fights else 0
        self.dfight = "garrison" if fights else ("open" if self.fight == "open" else "rough")
        self.counter = "rough" if self.fight == "rough" else "open"   # what the defender strikes in
        self.back = "open" if self.fight == "open" else "rough"        # how the attacker is struck in
        self.fighters, self.side, self.gen = {}, {}, {}
        for tag in self.tags():
            for unit in _war_units(world, battle, tag):
                self.fighters[unit.id] = unit
                self.side[unit.id] = tag
            self.gen[tag] = general(world, [u for u in world.units_at(battle.pos) if u.owner == tag])
        if battle.assault and prov.garrison > 0:
            self.fighters["garrison"] = Garrison(prov, world.bonus(battle.defender, "garrison_defense"))
            self.side["garrison"] = battle.defender
        self.dawn = {key: f.hp for key, f in self.fighters.items()}
        self.lost = {}

    def tags(self):
        return (self.battle.attacker, self.battle.defender)

    def pairs(self):
        """(striker side, struck side) for the attacker, then the defender."""
        att, dfn = self.tags()
        return ((att, dfn), (dfn, att))

    def ground(self, tag):
        """The share of its damage a side keeps from the ground it attacks from (spec 3.4): an attacker that came up from
        lower ground deals UPHILL_PENALTY less all battle, and one that came across a pass CROSSING_PENALTY less on the
        first day (battle.days is 0 then). Defenders are never penalised."""
        battle = self.battle
        if tag != battle.attacker:
            return 1.0
        share = 1.0
        if battle.uphill:
            share *= 1 - UPHILL_PENALTY
        if battle.crossing and battle.days == 0:
            share *= 1 - CROSSING_PENALTY
        return share

    def fight_of(self, tag):
        """The fight a side strikes in."""
        return self.fight if tag == self.battle.attacker else self.counter

    def defence_fight(self, tag):
        """The fight a side is struck in."""
        return self.back if tag == self.battle.attacker else self.dfight

    def fighter_at(self, tag, lane):
        key = self.battle.lanes[tag][lane]
        return None if key is None else self.fighters.get(key)

    def target(self, tag, lane):
        """What a gun aims at: the lane, or the first filled lane (centre, left, right) when that one is empty."""
        for pick in (lane,) + FILL_ORDER:
            fighter = self.fighter_at(tag, pick)
            if fighter is not None:
                return fighter
        return None

    def reserve(self, tag):
        """A side's regiments on the hex that are in neither a lane nor routed: the reserve and the back line."""
        lanes = self.battle.lanes[tag]
        return [f for key, f in self.fighters.items()
                if self.side[key] == tag and key != "garrison" and key not in lanes and key not in self.battle.routed]

    def hit(self, attacker, target, base, a_fight, t_fight, extra=1.0):
        """The hp that attacker takes off target in one phase. Worked out, not applied: a phase's hits are all worked
        out from the state at its start, then applied together."""
        world = self.world
        sa, st = self.side[key_of(attacker)], self.side[key_of(target)]
        att = attack_value(world, attacker, a_fight, self.gen[sa])
        on_ground = st == self.battle.defender
        dfn = defense_value(world, target, t_fight, self.prov, self.castle, attacker.kind.branch, self.gen[st],
                            on_ground)
        dealt = STANCE.get(self.battle.stance.get(sa, "hold"), (1.0, 1.0))[0] * self.ground(sa) * self.mult.get(sa, 1.0)
        if key_of(attacker) in self.shaken:
            dealt *= RESERVE_SHAKEN
        taken = STANCE.get(self.battle.stance.get(st, "hold"), (1.0, 1.0))[1]
        strength = attacker.hp / max(1, attacker.kind.hp)
        return (base * target.kind.hp * att / max(dfn, 1e-9) * strength * dealt * taken * extra
                * world.rng.uniform(1 - HIT_SPREAD, 1 + HIT_SPREAD))

    def resolve(self, hits):
        """Apply a phase's hits, (target, hp, wounded share), then cull the dead. Whole hit points come off now; the
        rest waits in ``battle.carry``. The men lost are killed, or wounded for the share."""
        battle = self.battle
        for target, dmg, share in hits:
            key = key_of(target)
            tag = self.side[key]
            # a hit never takes more than the fighter has left, carry included, so booked men never exceed men lost
            dmg = min(dmg, max(0.0, target.hp - battle.carry.get(key, 0.0)))
            if dmg <= 0:
                continue
            men = dmg * men_per_hp(target)
            self.lost[key] = self.lost.get(key, 0.0) + dmg
            battle.killed[tag] = battle.killed.get(tag, 0.0) + men * (1 - share)
            battle.wounded[tag] = battle.wounded.get(tag, 0.0) + men * share
            if share:
                battle.wounded_hp[key] = battle.wounded_hp.get(key, 0.0) + dmg * share
            total = round(battle.carry.get(key, 0.0) + dmg, 9)
            whole = int(total)
            battle.carry[key] = total - whole
            target.hp = max(0, target.hp - whole)
        self.cull()

    def cull(self):
        """Dead fighters leave the fight and the world. The garrison's men are the castle's; a lane holds only a
        fighter that is still here."""
        battle = self.battle
        for key, fighter in list(self.fighters.items()):
            if fighter.hp > 0:
                continue
            del self.fighters[key]
            if key == "garrison":
                self.prov.garrison = 0
            else:
                battle.routed.discard(key)
                self.world.kill(fighter, "battle")
        if "garrison" in self.fighters:
            self.prov.garrison = self.fighters["garrison"].hp
        for tag in self.tags():
            lanes = battle.lanes[tag]
            for lane, key in enumerate(lanes):
                if key is not None and key not in self.fighters:
                    lanes[lane] = None


def fire(day):
    """The guns of the back line fire at the enemy centre. Era 2 and 3 infantry in a lane shoot the enemy in the same
    lane."""
    hits = []
    for tag, enemy in day.pairs():
        for gun in day.reserve(tag):
            target = day.target(enemy, CENTRE) if gun.kind.branch == "artillery" else None
            if target is not None:
                dmg = day.hit(gun, target, FIRE_LOSS, day.fight_of(tag), day.defence_fight(enemy))
                hits.append((target, dmg, WOUNDED_SHARE))
        for lane in range(3):
            shooter, target = day.fighter_at(tag, lane), day.fighter_at(enemy, lane)
            if shooter is None or target is None or shooter.kind.branch != "infantry" or shooter.kind.era < 2:
                continue
            dmg = day.hit(shooter, target, SHOT_LOSS, day.fight_of(tag), day.defence_fight(enemy))
            hits.append((target, dmg, WOUNDED_SHARE))
    day.resolve(hits)


def backline(day):
    """A side whose centre is empty (its lane broke and no reserve filled it) exposes its back line: the enemy's reserve,
    guns included, hits its reserve at BACKLINE_LOSS. This is the gun stopgap of the arms matrix (spec 5.5)."""
    hits = []
    for tag, enemy in day.pairs():
        if day.battle.lanes[enemy][CENTRE] is not None:
            continue
        targets = day.reserve(enemy)
        for i, striker in enumerate(day.reserve(tag) if targets else ()):
            target = targets[i % len(targets)]
            dmg = day.hit(striker, target, BACKLINE_LOSS, day.fight_of(tag), day.defence_fight(enemy))
            hits.append((target, dmg, WOUNDED_SHARE))
    day.resolve(hits)


def shock(day):
    """Each lane fights the same lane of the enemy, both ways at once."""
    hits = []
    att, dfn = day.tags()
    for lane in range(3):
        a, d = day.fighter_at(att, lane), day.fighter_at(dfn, lane)
        if a is None or d is None:
            continue
        dmg_d = day.hit(a, d, SHOCK_LOSS, day.fight_of(att), day.defence_fight(dfn), _pike(a, d))
        dmg_a = day.hit(d, a, SHOCK_LOSS, day.fight_of(dfn), day.defence_fight(att), _pike(d, a))
        hits.append((d, dmg_d, WOUNDED_SHARE))
        hits.append((a, dmg_a, WOUNDED_SHARE))
    day.resolve(hits)


def flanks(day):
    """An empty flank lane is open ground for the enemy regiment in the same lane, which has nobody to fight. It comes
    round with FLANK_BONUS to the centre, or to the nearest filled lane when the centre is empty too."""
    hits = []
    for tag, enemy in day.pairs():
        for lane in (0, 2):
            runner = day.fighter_at(enemy, lane)
            if runner is None or day.fighter_at(tag, lane) is not None:
                continue
            filled = [i for i in range(3) if day.fighter_at(tag, i) is not None]
            if not filled:
                continue
            where = min(filled, key=lambda i: (i != CENTRE, abs(i - lane), i))
            target = day.fighter_at(tag, where)
            dmg = day.hit(runner, target, SHOCK_LOSS, day.fight_of(enemy), day.defence_fight(tag), FLANK_BONUS)
            hits.append((target, dmg, WOUNDED_SHARE))
    day.resolve(hits)


def morale(day):
    """Each regiment loses morale for the hp it lost today (a share of its hp at dawn), for its place (lane or reserve)
    and, unfed, for hunger. A general on its side cuts the loss and rank divides it. At 0 it routs: it leaves its lane
    and stays on the hex, out of the fight. The garrison's morale is the battle's."""
    battle = day.battle
    for tag in day.tags():
        cut = 1 - GENERAL_MORALE if day.gen[tag] else 1.0
        lanes = battle.lanes[tag]
        for key, fighter in list(day.fighters.items()):
            if day.side[key] != tag or key in battle.routed or (key == "garrison" and battle.garrison_morale <= 0):
                continue
            garrison = key == "garrison"
            loss = MORALE_PER_LOSS * day.lost.get(key, 0.0) / max(day.dawn[key], 1e-9)
            loss += FRONT_DRAIN if key in lanes else RESERVE_DRAIN
            if not garrison and not fighter.supplied:
                loss += HUNGER_DRAIN
            loss = loss * cut / fighter.rank[2]
            left = max(0.0, (battle.garrison_morale if garrison else fighter.morale) - loss)
            if garrison:
                battle.garrison_morale = left
            else:
                fighter.morale = left
            if left <= 0:
                _rout(battle, tag, key)


def _lane_cause(day, tag):
    """Why a side's army breaks through its lanes, after the day's morale, or None. Only a lane with no reserve to fill it
    counts. An empty centre breaks the army. On open ground two empty lanes do; on narrow ground (two lanes) either does."""
    battle, prov = day.battle, day.prov
    if day.reserve(tag):
        return None
    lanes = battle.lanes[tag]
    open_lanes = [lane for lane in range(3) if lane_open(prov, lane)]
    held = battle.held.get(tag, [])
    empty = [lane for lane in open_lanes if lanes[lane] is None and lane in held]
    if not empty:
        return None
    if CENTRE in empty:
        return "centre"
    if len(open_lanes) == 2 or len(empty) >= 2:
        return "lanes"
    return None


def breaker(day):
    """The side whose army breaks today and why: (tag, cause) with cause "centre", "lanes" or "morale", or (None, None).
    A side breaks when its centre is empty with no reserve, when two lanes are (either one on narrow ground), or when its
    front-line morale (army_morale) is under BREAK. When both break, the one with the lower front morale (the attacker on
    a tie)."""
    att, dfn = day.tags()
    world, battle = day.world, day.battle
    ma, md = army_morale(world, battle, att), army_morale(world, battle, dfn)
    cause = {}
    for tag, morale in ((att, ma), (dfn, md)):
        cause[tag] = _lane_cause(day, tag) or ("morale" if morale < BREAK else None)
    broken = [tag for tag in (att, dfn) if cause[tag] is not None]
    if not broken:
        return None, None
    tag = (att if ma <= md else dfn) if len(broken) == 2 else broken[0]
    return tag, cause[tag]


def pursuit(day, loser):
    """The broken side loses PURSUIT of its men when the winner still has a cavalry regiment, else PURSUIT_FOOT. All of
    it is killed; none is wounded."""
    battle = day.battle
    winner = battle.defender if loser == battle.attacker else battle.attacker
    mounted = any(f.kind.branch == "cavalry" for key, f in day.fighters.items()
                  if day.side[key] == winner and key not in battle.routed)
    share = PURSUIT if mounted else PURSUIT_FOOT
    hits = [(f, share * f.hp, 0.0) for key, f in day.fighters.items() if day.side[key] == loser]
    day.resolve(hits)


def fight_day(world, battle):
    """One day of the battle: deploy, each side's d6 roll, fire, back line, shock, flanks, morale, then pursuit if an army
    breaks. Returns the day's report: {"broke": tag or None, "cause": "centre" | "lanes" | "morale" | None, "rolls":
    {tag: d6}, "killed": {tag: men}, "wounded": {tag: men}, "morale": {tag: army morale}}. The battle's counters and its
    log (one "day" record, structured) move with the day."""
    shaken = deploy(world, battle)
    att, dfn = battle.attacker, battle.defender
    rolls = {tag: world.rng.randint(1, 6) for tag in (att, dfn)}
    day = _Day(world, battle, shaken, rolls)
    before = {tag: (battle.killed.get(tag, 0.0), battle.wounded.get(tag, 0.0)) for tag in (att, dfn)}
    fire(day)
    backline(day)
    shock(day)
    flanks(day)
    morale(day)
    broke, cause = breaker(day)
    if broke is not None:
        pursuit(day, broke)
    battle.days += 1
    report = {"broke": broke, "cause": cause, "rolls": rolls, "killed": {}, "wounded": {}, "morale": {}}
    for tag in (att, dfn):
        report["killed"][tag] = battle.killed.get(tag, 0.0) - before[tag][0]
        report["wounded"][tag] = battle.wounded.get(tag, 0.0) - before[tag][1]
        report["morale"][tag] = army_morale(world, battle, tag)
    record(world, battle, "day", killed={tag: round(report["killed"][tag], 1) for tag in (att, dfn)},
           wounded={tag: round(report["wounded"][tag], 1) for tag in (att, dfn)}, rolls=dict(rolls), broke=broke,
           cause=cause)
    return report
