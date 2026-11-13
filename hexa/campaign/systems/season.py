"""The season: the ordered phases between one turn and the next, and what keeps time, sight and score.

``PHASES`` is the one place that says what ``end_round`` does and in what order: (name, function) pairs, each function
taking ``world``. ``end_round`` walks the table, ``GameManager.end_season`` calls it after the countries have moved
(tests/test_season.py pins the names in order). A change to the season's order is a change to this table and nowhere
else. The functions named in it live in their own systems (supply, war, economy, debt, research); the three small steps
that have no system of their own are here: ``war_timeouts`` (old wars end), ``advance_turn`` (the turn counter and the
winter passes) and ``ready_units`` (every unit gets its moves and rests back to strength).

Vision and scores are here too: ``start_units`` (a country's units at the start of its turn), ``explore_home``,
``see_from`` and ``update_visibility`` (what each country has explored and what the player sees now: the fog) and
``score``/``ranking``. ``CampaignWorld`` binds them as plain class attributes; ``see_from`` and ``update_visibility`` are
called for every step of a march. Imports point down: never world.py, ui, render or pygame.
"""
from ...events import passes_changed
from ...hexgrid import within
from .. import geo
from ..data import END_YEAR, WAR_LENGTH_AI
from . import debt, economy, research, supply, war

SCALE = geo.SCALE

# What this module changes on the world: the turn counter and the end of the game, every unit's moves and strength,
# the provinces' busy flag, what each country has explored, what the player sees, the log and the redraw counter.
OWNS = ("turn", "over", "units", "provinces", "countries", "visible", "version", "log", "_explored_from")


def end_round(world):
    """Everything that happens between seasons, after every country has moved: the PHASES, in order."""
    for _, phase in PHASES:
        phase(world)


def war_timeouts(world):
    """Wars end when they have lasted long enough (twice as long when the player is in them), or, between two AI
    countries, when one side is clearly winning."""
    for conflict in list(world.wars):
        if world.player in (conflict.a, conflict.b):
            limit = WAR_LENGTH_AI * 2
        else:
            limit = WAR_LENGTH_AI
        score = world.war_score(conflict.a, conflict.b)
        if world.turn - conflict.start >= limit or (world.player not in (conflict.a, conflict.b) and abs(score) >= 5):
            winner = conflict.a if score > 0 else conflict.b if score < 0 else "nobody"
            world.peace(conflict.a, conflict.b,
                        winner=winner if world.player not in (conflict.a, conflict.b) else None)


def run_economy(world):
    """The season's prices, production, trade and incomes (CampaignWorld.economy owns the tax preview's state)."""
    world.economy()


def advance_turn(world):
    """The next season: turn + 1, the mountain passes open or shut with the winter, and the game ends after END_YEAR."""
    was_winter = world.winter()
    world.turn += 1
    passes_changed(world, was_winter)
    if world.year() > END_YEAR:
        world.over = True


def ready_units(world):
    """Every unit gets its moves back (and heals if it is fed and at home); no province is busy any more."""
    for tag in world.countries:
        world.start_units(tag)
    for prov in world.provinces.values():
        prov.busy = False


def explore_all(world):
    """Each country learns the land around its provinces (and, the first time, the known world)."""
    for country in world.countries.values():
        world.explore_home(country)


def redraw(world):
    """Tell the map that the season changed what it draws."""
    world.changed()


def treasury_line(world):
    """The player's season report: the date, the treasury and the balance."""
    if world.player:
        c = world.countries[world.player]
        world.message(f"{world.date()}. Treasury {c.treasury:.0f} ducats ({c.balance:+.1f} per season).", None,
                      "treasury")


def start_units(world, tag):
    for unit in world.units_of(tag):
        unit.moves_left = world.unit_moves(unit)
        unit.acted = unit.attacked = unit.upgraded = False
        if unit.kind.war and unit.hp < unit.kind.hp and not unit.carrier and unit.supplied:
            prov = world.provinces.get(unit.pos)
            if prov and prov.owner == tag and prov.controller == tag:
                unit.hp = min(unit.kind.hp, unit.hp + (3 if prov.settlement >= 2 else 1))


def explore_home(world, country):
    if not country.explored:
        country.explored |= world.known_world()
        limit = world.geo.COASTAL_KNOWLEDGE.get(country.tag)
        if limit is not None:
            for pos in world.terrain:
                lon, lat = geo.lonlat(pos)
                if lat >= limit and lon > -19.5 and (
                        world.is_sea(pos) or world.provinces.get(pos) and world.provinces[pos].coastal):
                    country.explored.add(pos)
    done = world.__dict__.setdefault("_explored_from", {}).setdefault(country.tag, set())
    for prov in world.provinces_of(country.tag):
        if prov.pos in done:
            continue
        done.add(prov.pos)
        for p in within(prov.pos, SCALE):
            if p in world.terrain:
                country.explored.add(p)


def see_from(world, unit, radius=None, refresh=True):
    country = world.countries[unit.owner]
    before = len(country.explored)
    for p in within(unit.pos, radius or world.unit_sight(unit)):
        if p in world.terrain:
            country.explored.add(p)
    if unit.owner == world.player and refresh:
        if len(country.explored) != before:
            world.changed()
        world.update_visibility()


def update_visibility(world):
    if not world.player:
        world.visible = set(world.terrain)
        return
    seen = set()
    for prov in world.provinces_of(world.player):
        seen.update(within(prov.pos, 1))
    for unit in world.units_of(world.player):
        if unit.carrier is None:
            seen.update(within(unit.pos, world.unit_sight(unit)))
    new = {p for p in seen if p in world.terrain}
    if new != world.visible:
        world.visible = new
        world.version += 1


def score(world, tag):
    country = world.countries[tag]
    if not country.alive:
        return 0
    pop = world.total_pop(tag)
    colonial = sum(p.pop for p in world.colonies_of(tag))
    return round(pop / 20 + max(0.0, country.balance) * 3 + colonial * 2 + max(0.0, country.treasury) / 50)


def ranking(world):
    alive = [c for c in world.countries.values() if c.alive]
    return sorted(alive, key=lambda c: -world.score(c.tag))


# The season's order. Names are what tests/test_season.py pins; add, move or remove a phase here and nowhere else.
PHASES = (
    ("logistics", supply.logistics),          # feed every stack or starve it
    ("sieges", war.sieges),                   # troops in enemy provinces take them
    ("war_timeouts", war_timeouts),           # old wars end
    ("economy", run_economy),                 # prices, production, trade, incomes
    ("collect", economy.collect),             # the incomes are paid
    ("debt", debt.unpaid),                    # desertion, seizures, the credit cap
    ("growth", economy.grow),                 # population, colonies, building queues
    ("research", research.research_season),   # techs, ideas, ages
    ("extinction", war.check_alive),          # countries without provinces disappear
    ("turn", advance_turn),                   # turn + 1, passes, the end of the game
    ("units", ready_units),                   # moves, healing
    ("exploration", explore_all),             # what each country knows
    ("vision", update_visibility),           # what the player sees
    ("redraw", redraw),                       # the map's version
    ("report", treasury_line),                # the player's line in the log
)
