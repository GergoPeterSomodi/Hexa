"""The economy: the season's prices, production, trade flows and incomes, tax previews, collecting the money, and growth.

Functions taking ``world``; ``CampaignWorld`` keeps a one-line facade for each one the UI, the AI and the tests call.
``economy`` runs once per season (after everybody moved), ``collect`` banks the balance and ``grow`` grows the
population and finishes the queues, calling ``colonies`` where the colonial part of the loop sits. The tax preview
(``preview_tax``) projects the economy without using it up; the saved state it puts back (``settled_state``) stays
on the world as ``_settled``, which ``CampaignWorld.set_tax``, ``settle_preview`` and ``economy`` own. The markets and
routes come from trade.py. Imports point down: never world.py, ui, render or pygame.
"""
from ..data import (BASE_GROWTH, BUILDINGS, BURGHER_TAX, CASTLE_UPKEEP, CASTLES, COLONY_DONE, COLONY_UPKEEP, DEBT_INTEREST,
                    ELASTICITY, FARM_GOODS, FOOD_PER_TROOP, GARRISON_HP, GOODS, MANUFACTORIES, MANUFACTORY_TAX, MINE_GOODS,
                    NEEDS, OUTPUT, PEASANT_TAX, PRICE_CAP, PRICE_FLOOR, PRODUCTION_TAX, REMOTE_PENALTY, SETTLEMENT_TAX,
                    SETTLEMENT_UPKEEP, SETTLEMENTS, SUBSISTENCE, TAX_GROWTH, TAX_LEVELS, TOLL_SHARE, TRADING_POST_SHARE,
                    WORKS_BONUS, WORKS_UPKEEP)
from . import colonies
from .trade import ensure_markets, market_owner, merchants_trade, trade_route

# What this module changes: the provinces' output, value, food, population, queues, buildings and castles, the
# markets' supply, demand, prices and history, the routes' flows, the countries' income and treasury, the log, and
# (through world methods) the map version, the markets-dirty flag and the castle list.
OWNS = ("provinces", "countries", "markets", "routes", "log", "version", "_markets_dirty", "_castle_list")

CLASSES = ("peasants", "burghers", "nobles")


def economy(world, preview=False):
    """Work out prices, trade and incomes. preview=True projects them without using up the pending purchases
    or adding a point to the price history."""
    ensure_markets(world)
    held = trade_state(world) if preview else None
    for market in world.markets:
        market.reset(keep_pending=preview)
    for prov in world.provinces.values():
        prov.output = prov.value = 0.0
        market = prov.market
        if not prov.owner or not market:
            continue
        if prov.controller == prov.owner:
            food = SUBSISTENCE * prov.peasants
            market.supply["grain"] += food
            market.produced["grain"] += food
        if prov.good and prov.controller == prov.owner:
            out = OUTPUT[prov.good] * workers(world, prov) * works_factor(world, prov) * output_mult(world, prov)
            if prov.remote:
                out *= REMOTE_PENALTY
            if prov.foraged and prov.foraged[1] >= world.turn - 1:
                out *= 0.5
            prov.output = out
            market.supply[prov.good] += out
            market.produced[prov.good] += out
        for cls in CLASSES:
            people = getattr(prov, cls)
            for need, amount in NEEDS[cls].items():
                market.demand[need if need != "food" else "grain"] += amount * people
        for key in MANUFACTORIES:
            level = prov.level(key)
            if level:
                staff = staffing(prov, key)
                for g, n in goods_in(prov, key).items():
                    market.demand[g] += n * level * staff
    for unit in world.units:
        if unit.kind.war and unit.carrier is None:
            market = food_market(world, unit)
            if market:
                market.demand["grain"] += FOOD_PER_TROOP
    for market in world.markets:
        split_food(market)
        set_prices(market)
    # Workshops make their goods first, so merchants and trade routes can carry them.
    profits = {}
    for prov in world.provinces.values():
        if not prov.owner or not prov.market or prov.controller != prov.owner:
            continue
        for key in MANUFACTORIES:
            level = prov.level(key)
            if not level:
                continue
            market, staff = prov.market, staffing(prov, key)
            inputs = goods_in(prov, key)
            share = min((market.satisfaction(g) for g in inputs), default=1.0) * staff * level
            made = 0.0
            for g, n in BUILDINGS[key].outputs.items():
                market.supply[g] += n * share
                market.produced[g] += n * share
                made += n * share * market.price[g]
            cost = sum(n * share * market.price[g] for g, n in inputs.items())
            profits[prov.owner] = profits.get(prov.owner, 0) + max(0.0, made - cost) * MANUFACTORY_TAX
    for market in world.markets:
        set_prices(market)
    for route in world.routes:
        merchants_trade(world, route)
    for route in world.routes:
        trade_route(world, route)
    for market in world.markets:
        set_prices(market)
        if preview:
            continue
        for g in GOODS:
            market.history[g].append(round(market.price[g], 2))
            del market.history[g][:-40]
    incomes(world, profits)
    if held is not None:
        restore_trade_state(held)

def settled_state(world):
    """The incomes and outputs the last real season left (the AI decides on these, not on a preview)."""
    return ({t: dict(c.income) for t, c in world.countries.items()},
            {p.pos: (p.output, p.value) for p in world.provinces.values()})

def trade_state(world):
    """The prices and the route trade as the season left them. A preview puts them back, because the next
    real economy reads last season's prices (the staffing of workshops) before it sets new ones."""
    return ([(m, dict(m.price)) for m in world.markets],
            [(r, r.flows, r.results, r.profit) for r in world.routes])

def restore_trade_state(state):
    prices, routes = state
    for market, price in prices:
        market.price.clear()
        market.price.update(price)
    for route, flows, results, profit in routes:
        route.flows, route.results, route.profit = flows, results, profit

def workers(world, prov):
    if not prov.trading_post:
        return prov.peasants
    return prov.peasants + prov.natives * TRADING_POST_SHARE * (1 + world.bonus(prov.owner, "trading_post_share"))

def works_factor(world, prov):
    extra = world.bonus(prov.owner, "farm_works") if prov.good in FARM_GOODS else 0
    return 1 + (WORKS_BONUS + extra) * prov.works

def output_mult(world, prov):
    if prov.good in MINE_GOODS:
        return 1 + world.bonus(prov.owner, "mines")
    if prov.good == "wool":
        return 1 + world.bonus(prov.owner, "wool")
    return 1

def tax_growth(world, tag):
    growth = TAX_GROWTH[world.countries[tag].tax]
    if growth < 0:
        return growth * max(0.0, 1 - world.bonus(tag, "tax_relief"))
    return growth

def staffing(prov, key):
    need = BUILDINGS[key].needs_burghers * prov.level(key)
    return 1.0 if need <= 0 else min(1.0, prov.burghers / need)

def goods_in(prov, key):
    inputs = dict(BUILDINGS[key].inputs)
    if key == "weaver" and prov.market and prov.market.price["cotton"] < prov.market.price["wool"] * 1.2 \
            and prov.market.supply.get("cotton", 0) > prov.market.supply.get("wool", 0):
        inputs = {"cotton": inputs.pop("wool")}
    return inputs

def split_food(market):
    want = market.demand["grain"]          # all food demand was booked as grain
    grain, fish = market.supply["grain"], market.supply["fish"]
    if grain + fish > 0:
        market.demand["fish"] = want * fish / (grain + fish)
        market.demand["grain"] = want - market.demand["fish"]

def set_prices(market):
    for g, good in GOODS.items():
        if good.kind == "money":
            market.price[g] = good.price
            continue
        ratio = (market.demand[g] + 0.5) / (market.supply[g] + 0.5)
        market.price[g] = good.price * max(PRICE_FLOOR, min(PRICE_CAP, ratio ** ELASTICITY))

def food_market(world, unit):
    """Where a troop buys its food: the market of the province it stands in, else its capital's."""
    prov = world.provinces.get(unit.pos)
    if prov and prov.market and prov.controller == unit.owner:
        return prov.market
    capital = world.provinces.get(world.countries[unit.owner].capital)
    return capital.market if capital else None

def incomes(world, profits):
    trade = {}
    for route in world.routes:
        for tag, g, amount, profit in route.results:
            trade[tag] = trade.get(tag, 0) + profit
        if route.profit <= 0:
            continue
        for market in (route.a, route.b):
            owner = market_owner(world, market)
            if owner:
                trade[owner] = trade.get(owner, 0) + route.profit * TOLL_SHARE * (1 + world.bonus(owner, "tolls"))
    food = {}
    for unit in world.units:
        if unit.kind.war and unit.carrier is None:
            market = food_market(world, unit)
            price = market.price["grain"] if market else 1.5
            food[unit.owner] = food.get(unit.owner, 0) + FOOD_PER_TROOP * price
    for tag, country in world.countries.items():
        if not country.alive:
            continue
        rate = TAX_LEVELS[country.tax] + (world.bonus(tag, "high_tax") if country.tax == "high" else 0)
        production = pop_tax = upkeep = colonies = 0.0
        for prov in world.provinces_of(tag):
            if prov.controller != tag:
                continue
            market = prov.market
            if market and prov.good:
                money = 1 + world.bonus(tag, "money_value") if GOODS[prov.good].kind == "money" else 1
                prov.value = prov.output * market.price[prov.good] * money
                production += prov.value * (PRODUCTION_TAX + world.bonus(tag, "production_tax")) * rate
            everyday = market.satisfaction("cloth") if market else 0.5
            pop_tax += rate * (prov.peasants * PEASANT_TAX + prov.burghers * BURGHER_TAX * (1 + world.bonus(tag, "burgher_tax")) *
                               (0.5 + 0.5 * everyday) * (1 + 0.15 * prov.level("marketplace"))) * \
                (1 + SETTLEMENT_TAX[prov.settlement])
            for key, level in prov.buildings.items():
                upkeep += BUILDINGS[key].upkeep * level
            upkeep += WORKS_UPKEEP * prov.works + SETTLEMENT_UPKEEP[prov.settlement] + CASTLE_UPKEEP[prov.castle]
            if prov.colony:
                colonies += COLONY_UPKEEP * (1 + world.bonus(tag, "colony_upkeep"))
        units = sum(u.kind.upkeep for u in world.units_of(tag)) + food.get(tag, 0.0)
        country.income = {"production": production, "taxes": pop_tax, "buildings": profits.get(tag, 0.0),
                          "trade": trade.get(tag, 0.0), "upkeep": -upkeep, "military": -units,
                          "colonies": -colonies}
        if country.treasury < 0:
            country.income["interest"] = max(country.treasury, -world.debt_limit(tag)) * DEBT_INTEREST

def collect(world):
    for country in world.countries.values():
        if country.alive:
            country.treasury += country.balance

def grow(world):
    """Population growth, colonies, native raids, building queues."""
    for prov in world.provinces.values():
        if prov.owner is None:
            prov.natives *= 1.0005
            continue
        food = prov.market.food_satisfaction() if prov.market else 0.8
        prov.food = food
        rate = BASE_GROWTH + tax_growth(world, prov.owner) + min(0.0, food - 0.9) * 0.05
        if prov.colony:
            rate = colonies.settlers(world, prov, rate)
        prov.peasants *= 1 + rate
        prov.nobles *= 1 + rate * 0.5
        jobs = sum(BUILDINGS[k].needs_burghers * prov.level(k) for k in MANUFACTORIES) + \
            3 * prov.level("marketplace")
        if prov.burghers < jobs and prov.peasants > 2:
            moving = min(prov.peasants * 0.006, jobs - prov.burghers)
            prov.peasants -= moving
            prov.burghers += moving
        prov.burghers *= 1 + rate * (1 + world.bonus(prov.owner, "burgher_growth"))
        if prov.natives > 0:
            colonies.natives(world, prov)
        if prov.colony and prov.pop >= COLONY_DONE:
            colonies.graduate(world, prov)
        for item in list(prov.queue):
            item[1] -= 1
            if item[1] <= 0:
                prov.queue.remove(item)
                if item[0] == "settlement":
                    prov.settlement += 1
                    world.message(f"{world.place(prov)} has grown into a {SETTLEMENTS[prov.settlement].lower()}.", prov.owner)
                elif item[0] == "castle":
                    prov.castle += 1
                    prov.garrison = prov.castle * GARRISON_HP
                    world.forget_castles()
                    world.message(f"{world.place(prov)}: the {CASTLES[prov.castle].lower()} is finished.", prov.owner)
                else:
                    prov.buildings[item[0]] = prov.level(item[0]) + 1
                    world.message(f"{world.place(prov)}: {world.building_name(prov, item[0])} finished.", prov.owner)
                world.bus.emit("building_done", prov.owner, prov.pos, what=item[0])
                world.changed()
                if item[0] == "marketplace":
                    world.refresh_markets()


def restore_settled(world, saved):
    """Put back the incomes and outputs settled_state saved (the last real season's)."""
    incomes, outputs = saved
    for tag, income in incomes.items():
        world.countries[tag].income = income
    for pos, (output, value) in outputs.items():
        world.provinces[pos].output, world.provinces[pos].value = output, value


def preview_tax(world, tag, level):
    """Change a country's tax level and show the projected economy. This is only a preview: the pending
    purchases and the price history are left alone, so the season's own economy still runs once, as it would
    have without the change."""
    world.countries[tag].tax = level
    economy(world, preview=True)
