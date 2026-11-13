"""Research: techs, idea cards, ages, and a country's start techs.

Functions taking ``world``; ``CampaignWorld`` keeps a one-line facade for each one the UI, the AI and the tests call.
What stays on ``CampaignWorld`` is the effects cache: ``has`` and ``bonus`` (called thousands of times a season, so
they stay plain methods), their ``_effects`` and ``tech_changed``, which owns the cache that a gained tech drops. This
module reads ``world.bonus`` and calls ``world.tech_changed`` after it changes a country's techs or ideas. Imports
point down: never world.py, ui, render or pygame.
"""
from ...hexgrid import within
from .. import geo, resources, tech
from ..data import BRANCHES, ERAS, RESEARCH_BASE, RESEARCH_FUND, SCALE, troop

BIG_EMPIRE = 300                                        # provinces that start a country with drill yards
ROUTE_KEYS = ("market_reach", "sea_range", "atlantic")  # effects that change the trade routes

# What this module changes: the country's techs, ideas, research points, queue and national tech, its explored
# tiles (cartography), the treasury (through resources.spend), the log, and the markets (refresh_markets).
OWNS = ("countries", "log")


def route_effects(effects):
    return any(key in ROUTE_KEYS for key in effects)


def find_idea(key):
    if key in tech.IDEAS:
        return tech.IDEAS[key]
    return next((i for lst in tech.NATIONAL_IDEAS.values() for i in lst if i.key == key), None)


def grant_tech(world, tag, key):
    """Add a tech to what a country knows. Cartography explores its trade coasts; route effects redraw markets."""
    country = world.countries[tag]
    if key in country.techs:
        return
    country.techs.add(key)
    world.tech_changed(tag)
    if key == "cartography":
        cartography(world, tag)
    t = tech.tech(key)
    if t is not None and route_effects(t.effects):
        world.refresh_markets()


def pick_idea(world, tag, idea_key):
    """Adopt one of the idea cards offered at the last age. The other cards are dropped."""
    country = world.countries[tag]
    idea = find_idea(idea_key)
    if idea is None or idea_key not in country.pending_ideas:
        return False
    country.ideas.add(idea_key)
    country.pending_ideas = []
    world.tech_changed(tag)
    if route_effects(idea.effects):
        world.refresh_markets()
    world.message(f"Idea adopted: {idea.name}. {idea.text}", tag, "idea")
    return True


def fund_check(world, tag):
    """Funding is allowed once a year (every 4 seasons) and costs RESEARCH_FUND[0] ducats."""
    country = world.countries[tag]
    last = country.memory.get("funded_turn")
    if last is not None and world.turn - last < 4:
        return False, f"Funded already: again in {4 - (world.turn - last)} season(s)"
    if country.treasury < RESEARCH_FUND[0]:
        return False, f"Costs {RESEARCH_FUND[0]} ducats"
    return True, ""


def fund_research(world, tag):
    """60 ducats buy 15 research points (more with the Fund effect) for the current tech, once a year."""
    gold, points = RESEARCH_FUND
    country = world.countries[tag]
    if not fund_check(world, tag)[0]:
        return False
    country.memory["funded_turn"] = world.turn
    resources.spend(world, tag, gold, "research")
    country.research += points * (1 + world.bonus(tag, "fund"))
    return True


def next_era(world, tag):
    """(era, year it opens, era techs needed) for the next age, or None at the last one."""
    country = world.countries[tag]
    if country.era >= 3:
        return None
    era = country.era + 1
    return era, tech.ERA_YEARS[era], tech.ERA_GATE_TECHS


def research_rate(world, tag):
    """Research points this season as (total, parts). The parts add up to the total."""
    country = world.countries[tag]
    mult = 1 + world.bonus(tag, "research")
    owned = world.provinces_of(tag)
    burghers = sum(p.burghers for p in owned)
    universities = sum(1 for p in owned if p.level("university"))
    capital = world.provinces.get(country.capital)
    coffee = world.bonus(tag, "coffee_research")
    share = capital.market.satisfaction("coffee") if coffee and capital and capital.market else 0.0
    total = tech.research_points(RESEARCH_BASE, burghers, universities, share,
                                 {"research": world.bonus(tag, "research"), "coffee_research": coffee})
    parts = {"base": RESEARCH_BASE * mult, "burghers": burghers / 40 * mult, "universities": universities * mult,
             "coffee": share * burghers / 40 * 0.25 * coffee * mult, "funding": 0.0}
    return total, parts


def tech_cost(world, tag, key):
    """Research points a tech costs this country. Each neighbour on its markets that knows it makes it cheaper."""
    if key not in tech.TECHS:
        return 0
    bonuses = {"diffusion_cap": world.bonus(tag, "diffusion_cap"), "nav_cost": world.bonus(tag, "nav_cost")}
    return tech.cost(key, know_nearby(world, tag, key), bonuses)


def know_nearby(world, tag, key):
    """Living countries owning provinces on the markets this country trades in, that know `key`."""
    owners = {p.owner for m in world.merchant_markets(tag) for p in m.provinces}
    owners.discard(None)
    owners.discard(tag)
    return sum(1 for o in owners if world.countries[o].alive and key in world.countries[o].techs)


def set_research(world, tag, key):
    """Research `key` next: its unknown prerequisites first, then it. The rest of that path becomes the queue."""
    country = world.countries[tag]
    t = tech.TECHS.get(key)
    if t is None or key in country.techs or t.era > country.era:
        return False
    path = tech.path_to(key, country.techs)
    if not path:
        return False
    country.researching = path[0]
    country.queue = path[1:]
    return True


def unqueue(world, tag, key):
    """Take a tech out of the queue, with the queued techs that need it (they cannot come before it)."""
    queue = world.countries[tag].queue
    if key not in queue:
        return False
    drop = {key, *tech.dependants(key, queue)}
    queue[:] = [k for k in queue if k not in drop]
    return True


def research_season(world):
    for tag, country in world.countries.items():
        if not country.alive:
            continue
        rate = research_rate(world, tag)[0]
        country.research += rate
        finish_research(world, tag)
        if not country.researching:            # nothing chosen: points don't pile up for later
            country.research = min(country.research, 2 * rate)
        if tech.era_ready(country.era, world.year(), country.techs):
            new_age(world, tag)


def finish_research(world, tag):
    """Spend the research points on the current tech, then the next in the queue, while they last."""
    country = world.countries[tag]
    if country.researching in country.techs:
        country.researching = ""
    if not country.researching and not advance(world, tag):
        return
    while country.researching:
        key = country.researching
        cost = tech_cost(world, tag, key)
        if country.research < cost:
            return
        country.research -= cost
        grant_tech(world, tag, key)
        t = tech.TECHS[key]
        world.message(f"Researched {t.name}: {t.text}", tag)
        world.bus.emit("tech_researched", tag, key=key, cost=cost)
        if not advance(world, tag) and tag == world.player:
            world.message("Pick new research (T).", tag, "research")


def advance(world, tag):
    """Start the next queued tech that is still to learn. False when nothing is left in the queue."""
    country = world.countries[tag]
    country.researching = ""
    while country.queue:
        key = country.queue.pop(0)
        t = tech.TECHS.get(key)
        if (t is not None and key not in country.techs and t.era <= country.era
                and all(n in country.techs for n in t.needs)):
            country.researching = key
            return True
    return False


def new_age(world, tag):
    """The country reaches the next age: its troops change, and it is offered three idea cards."""
    country = world.countries[tag]
    country.era += 1
    world.bus.emit("era_reached", tag, era=country.era)
    names = ", ".join(troop(b, country.era).name.lower() for b in BRANCHES)
    world.message(f"{ERAS[country.era][0]}: you can now raise {names}. Refit old troops in your towns.", tag)
    counts = {b: sum(1 for k in country.techs if k in tech.TECHS and tech.TECHS[k].branch == b)
              for b in tech.BRANCHES}
    country.pending_ideas = [i.key for i in tech.draw_ideas(tag, counts, set(country.ideas), world.rng)]


def cheapest_available(world, tag):
    country = world.countries[tag]
    options = tech.available(country.techs, country.era)
    return min(options, key=lambda k: (tech.TECHS[k].cost, k), default="")


def know_region(world, tag):
    """The regional default tech's region, from the capital's position. Random worlds use 'default'."""
    if world.map == "random":
        return "default"
    lon, lat = geo.lonlat(world.countries[tag].capital)
    if 6 < lon < 19 and 37 < lat < 47.5:
        return "italian"
    if 5 < lon < 17 and 47 <= lat < 55:
        return "german"
    if lat < 37.5 and lon < 33 and lat > 20:
        return "north_african"
    return "default"


def start_techs(world):
    """Each country's national tech, its starting techs and its first research (build spec, start of game)."""
    big = BIG_EMPIRE
    for tag, country in world.countries.items():
        nat = tech.national_tech(tag, know_region(world, tag))
        owned = world.provinces_of(tag)
        known = {nat.key, *nat.also_knows}
        if world.colonial.get(tag, 999) <= 0:
            known.update(("portolan", "astrolabe"))
        if any(p.coastal for p in owned):
            known.add("portolan")
        if len(owned) >= big:
            known.add("drill_yards")
        country.national = nat.key
        country.techs = known
        world.tech_changed(tag)
        country.researching = cheapest_available(world, tag)


def legacy_techs(world, country):
    """An old save's country: its national tech, and the cheapest gate techs of each age below its own."""
    nat = tech.national_tech(country.tag, know_region(world, country.tag))
    country.national = nat.key
    known = {nat.key, *nat.also_knows}
    for era in range(1, country.era):
        gate = sorted((t for t in tech.TECHS.values() if t.era == era), key=lambda t: (t.cost, t.key))
        for t in gate[:tech.ERA_GATE_TECHS]:
            known.update(tech.path_to(t.key, known))
    country.techs = known
    world.tech_changed(country.tag)
    country.researching = cheapest_available(world, country.tag)


def cartography(world, tag):
    """Explore the coast and sea around every market this country trades through."""
    world.ensure_markets()
    mine = world.merchant_markets(tag)
    centres = set()
    for route in world.routes:
        if route.a in mine or route.b in mine:
            centres.update((route.a.center, route.b.center))
    centres.discard(None)
    explored = world.countries[tag].explored
    for centre in centres:
        for pos in within(centre, SCALE):
            prov = world.provinces.get(pos)
            if pos in world.terrain and (world.is_sea(pos) or (prov and prov.coastal)):
                explored.add(pos)
    if tag == world.player:
        world.changed()
        world.update_visibility()
