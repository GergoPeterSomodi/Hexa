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
from ..data import (BATTLE_LOG, BREAK, CASTLE_DEFENSE, FIGHT_ATTACK, FIGHT_DEFENSE, FIRE_LOSS, FLANK_BONUS, FRONT_DRAIN,
                    GARRISON_MEN, GENERAL, GENERAL_BONUS, GENERAL_MORALE, HUNGER_DRAIN, MEN, MORALE_PER_LOSS,
                    NARROW_TERRAIN, OPEN_GROUND, PIKES_VS_HORSE, PURSUIT, PURSUIT_FOOT, RESERVE_DRAIN, SHOCK_LOSS,
                    SHOT_LOSS, STANCE, TERRAIN, WOUNDED_SHARE)
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


def defense_value(world, unit, fight, prov, castle, versus, general):
    tag, branch = unit.owner, unit.kind.branch
    value = (unit.kind.defense + unit.def_up) * FIGHT_DEFENSE[branch][fight] * unit.rank[2]
    value *= 1 + (CASTLE_DEFENSE * castle if fight == "garrison" else TERRAIN[prov.terrain].defense)
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


def army_morale(world, battle, tag):
    """A side's army morale, 0 to 1: the sum of morale times men over its war units and garrison (routed units
    count 0), over the men it went in with (``battle.men0``)."""
    base = battle.men0.get(tag, 0)
    if base <= 0:
        return 0.0
    total = sum(u.morale * u.men for u in _war_units(world, battle, tag) if u.id not in battle.routed)
    if tag == battle.defender and battle.assault:
        total += battle.garrison_morale * GARRISON_MEN * world.provinces[battle.pos].garrison
    return min(1.0, total / base)


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


class _Day:
    """One day's working state: who stands where at dawn, the fighters that are left, and the hp each has lost."""

    def __init__(self, world, battle):
        self.world, self.battle = world, battle
        prov = self.prov = world.provinces[battle.pos]
        self.fight = "assault" if battle.assault else ("open" if prov.terrain in OPEN_GROUND else "rough")
        fights = garrison_fights(world, battle)
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
        dfn = defense_value(world, target, t_fight, self.prov, self.castle, attacker.kind.branch, self.gen[st])
        dealt = STANCE.get(self.battle.stance.get(sa, "hold"), (1.0, 1.0))[0]
        taken = STANCE.get(self.battle.stance.get(st, "hold"), (1.0, 1.0))[1]
        strength = attacker.hp / max(1, attacker.kind.hp)
        return (base * target.kind.hp * att / max(dfn, 1e-9) * strength * dealt * taken * extra
                * world.rng.uniform(0.85, 1.15))

    def resolve(self, hits):
        """Apply a phase's hits, (target, hp, wounded share), then cull the dead. Whole hit points come off now; the
        rest waits in ``battle.carry``. The men lost are killed, or wounded for the share."""
        battle = self.battle
        for target, dmg, share in hits:
            if dmg <= 0:
                continue
            key = key_of(target)
            tag = self.side[key]
            men = dmg * men_per_hp(target)
            self.lost[key] = self.lost.get(key, 0.0) + dmg
            battle.killed[tag] = battle.killed.get(tag, 0.0) + men * (1 - share)
            battle.wounded[tag] = battle.wounded.get(tag, 0.0) + men * share
            if share:
                battle.wounded_hp[key] = battle.wounded_hp.get(key, 0.0) + dmg * share
            total = battle.carry.get(key, 0.0) + dmg
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


def breaker(day):
    """The side whose army breaks today, or None. An army under BREAK breaks; when both are, the lower one (the
    attacker on a tie)."""
    att, dfn = day.tags()
    world, battle = day.world, day.battle
    ma, md = army_morale(world, battle, att), army_morale(world, battle, dfn)
    under_a, under_d = ma < BREAK, md < BREAK
    if under_a and under_d:
        return att if ma <= md else dfn
    if under_a:
        return att
    return dfn if under_d else None


def pursuit(day, loser):
    """The broken side loses PURSUIT of its men when the winner still has a cavalry regiment, else PURSUIT_FOOT. All of
    it is killed; none is wounded."""
    battle = day.battle
    winner = battle.defender if loser == battle.attacker else battle.attacker
    mounted = any(f.kind.branch == "cavalry" for key, f in day.fighters.items()
                  if day.side[key] == winner and key not in battle.routed)
    share = PURSUIT if mounted else PURSUIT_FOOT
    hits = [(f, share * f.kind.hp, 0.0) for key, f in day.fighters.items() if day.side[key] == loser]
    day.resolve(hits)


def fight_day(world, battle):
    """One day of the battle: deploy, fire, shock, flanks, morale, then pursuit if an army breaks. Returns the day's
    report: {"broke": tag or None, "killed": {tag: men}, "wounded": {tag: men}, "morale": {tag: army morale}}. The
    battle's counters and its log move with the day."""
    deploy(world, battle)
    day = _Day(world, battle)
    att, dfn = day.tags()
    before = {tag: (battle.killed.get(tag, 0.0), battle.wounded.get(tag, 0.0)) for tag in (att, dfn)}
    fire(day)
    shock(day)
    flanks(day)
    morale(day)
    broke = breaker(day)
    if broke is not None:
        pursuit(day, broke)
    battle.days += 1
    report = {"broke": broke, "killed": {}, "wounded": {}, "morale": {}}
    for tag in (att, dfn):
        report["killed"][tag] = battle.killed.get(tag, 0.0) - before[tag][0]
        report["wounded"][tag] = battle.wounded.get(tag, 0.0) - before[tag][1]
        report["morale"][tag] = army_morale(world, battle, tag)
    text = (f"Day {battle.days}: {att} {report['killed'][att]:.0f} killed, {report['wounded'][att]:.0f} wounded; "
            f"{dfn} {report['killed'][dfn]:.0f} killed, {report['wounded'][dfn]:.0f} wounded")
    if broke is not None:
        text += f". {broke} broke"
    battle.log.append((world.turn, battle.days, text))
    del battle.log[:-BATTLE_LOG]
    return report
