"""The task flag's lines: what the player has left unfinished. Pygame-free, read-only.

``unfinished(world, tag)`` returns the `Reminder` lines, most pressing first, or [] when nothing is left. The window
(hud/tasks.py, the flag under End season) lists them and each line's ``action`` is a tuple the window's ``press()``
already understands, so a click goes to the thing the line names. Every rule is a function of its own that
returns one `Reminder` or None:

    idea_pending      an idea card offered at a new age and not picked yet
    research_missing  nothing is being researched while the grid has techs to pick (the picked tech, not the queue)
    research_unfunded the tech being researched and "Fund research" can be bought now (it is allowed once a year and
                      costs ``RESEARCH_FUND`` ducats), whatever the tech's points
    idle_merchants    merchants without an order while a route of one of the player's markets has something to
                      carry
    nothing_built     no province has anything under construction while the treasury pays for at least one building
                      (``build_check`` says yes, so the line only shows what could really be started)
    battles_on        one line for each battle the player is a side of that is still on (send more troops before the season ends);
                      its action opens the battle panel
    idle_armies       land stacks of war units that did nothing this season: not moved, attacked or foraged, no
                      march order, not sieging (standing in a province held against its owner or an enemy) and not
                      garrisoning one of the player's own castles. The game has no fortify order, so a castle
                      garrison is what "fortifying" means today.

Nothing here changes the world. The flag asks for the lines again after every action and season (hud/tasks.py).
"""
from typing import NamedTuple

from . import tech
from .battleview import battle_view
from .data import BUILDINGS, CASTLE_COST, RESEARCH_FUND, SETTLEMENT_COST


class Reminder(NamedTuple):
    kind: str           # "idea", "research", "fund", "merchant", "build", "army" or "battle"
    text: str           # the line: "2 merchants have no orders"
    hint: str           # what a click does: "Open the market"
    action: tuple       # for CampaignApp.press: ("tech",), ("market", market), ("province", prov), ("log", "goto", hex), ("battle", hex)


def _plural(n, one, many):
    return f"{n} {one if n == 1 else many}"


# ----- the rules ---------------------------------------------------------------------------------------
def idea_pending(world, tag):
    country = world.countries[tag]
    if not country.pending_ideas:
        return None
    return Reminder("idea", "An idea card is waiting for your pick", "Open the cards", ("tech",))


def research_missing(world, tag):
    country = world.countries[tag]
    if country.researching or not tech.available(country.techs, country.era):
        return None
    return Reminder("research", "No technology is being researched", "Open the technology screen", ("tech",))


def research_unfunded(world, tag):
    """Fund research can be bought now (fund_check: once a year, and the ducats are there) for the tech being researched,
    whatever its points so far."""
    country = world.countries[tag]
    if not country.researching or not world.fund_check(tag)[0]:
        return None
    points = RESEARCH_FUND[1] * (1 + world.bonus(tag, "fund"))
    return Reminder("fund", f"Fund research is ready: +{points:g} points for {RESEARCH_FUND[0]} ducats (once a year)",
                    "Open the technology screen", ("tech",))


def idle_merchants(world, tag):
    free = world.merchants(tag) - len(world.countries[tag].orders)
    if free <= 0:
        return None
    mine = world.merchant_markets(tag)
    for route in world.routes:
        if (route.a in mine or route.b in mine) and any(o[3] > 0 for o in world.merchant_options(tag, route)):
            market = route.a if route.a in mine else route.b
            return Reminder("merchant", f"{_plural(free, 'merchant has', 'merchants have')} no orders",
                            "Open the market", ("market", market))
    return None


# the cheapest base price of anything that can be started: below it the treasury pays for nothing, skip the search
CHEAPEST = min([b.cost for b in BUILDINGS.values()] + [SETTLEMENT_COST[1], CASTLE_COST[1]])


def nothing_built(world, tag):
    country = world.countries[tag]
    owned = world.provinces_of(tag)
    if country.treasury < CHEAPEST or any(prov.queue for prov in owned):
        return None
    for prov in owned:
        for key in (*BUILDINGS, "settlement", "castle"):
            if world.build_check(tag, prov, key)[0]:
                return Reminder("build", "Nothing is being built, and you can pay for it",
                                f"Open {world.place(prov)}", ("province", prov))
    return None


def _sieging(world, tag, unit):
    prov = world.provinces.get(unit.pos)
    return bool(prov and prov.owner and prov.controller != tag and (prov.owner == tag or world.at_war(tag, prov.controller)))


def _garrisoning(world, tag, unit):
    prov = world.provinces.get(unit.pos)
    return bool(prov and prov.owner == tag and prov.castle)


def _holding(world, tag, unit):
    """Standing in one of the player's own towns or cities, or in an enemy province it occupies in a war."""
    prov = world.provinces.get(unit.pos)
    if not prov:
        return False
    if prov.owner == tag:
        return prov.settlement >= 2
    return prov.controller == tag and prov.owner is not None and world.at_war(tag, prov.owner)


def idle_armies(world, tag):
    stacks = {}
    for unit in world.units_of(tag):
        if (unit.kind.war and not unit.naval and unit.carrier is None and unit.moves_left > 0 and unit.goal is None
                and not (unit.acted or unit.attacked or unit.foraged_turn == world.turn)
                and not _sieging(world, tag, unit) and not _garrisoning(world, tag, unit) and not _holding(world, tag, unit)):
            stacks.setdefault(unit.pos, []).append(unit)
    if not stacks:
        return None
    first = min(stacks, key=lambda pos: (pos[1], pos[0]))
    return Reminder("army", f"{_plural(len(stacks), 'army has', 'armies have')} not moved", "Go to the army",
                    ("log", "goto", first))


def battles_on(world, tag):
    """One line per battle the player is a side of that is still on: a battle started this turn, which the battles phase
    settles at the end of the season (0.2.1). A list (the rule can give several lines), empty when there is none."""
    lines = []
    for battle in world.battles:
        if tag not in (battle.attacker, battle.defender):
            continue
        view = battle_view(world, battle, tag)
        name = view["name"] if view is not None else "The battle"
        lines.append(Reminder("battle", f"{name} is on: send more troops before the season ends", "Open the battle",
                              ("battle", battle.pos)))
    return lines


RULES = (battles_on, idea_pending, research_missing, research_unfunded, idle_merchants, nothing_built, idle_armies)


def unfinished(world, tag):
    """The reminders for country `tag`, most pressing first (the order of RULES); [] when it has finished everything."""
    if tag is None or tag not in world.countries or world.over:
        return []
    out = []
    for rule in RULES:
        found = rule(world, tag)
        if isinstance(found, list):
            out += found
        elif found is not None:
            out.append(found)
    return out
