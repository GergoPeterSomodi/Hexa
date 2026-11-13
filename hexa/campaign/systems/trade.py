"""Trade: the markets, the routes between them, the merchants' orders, and the goods that move along a route each season.

Functions taking ``world``; ``CampaignWorld`` keeps a one-line facade for each one the UI, the AI and the tests call.
What stays on ``CampaignWorld`` are the two caches it owns, with their flags: ``take_markets_dirty`` (the "markets must
be rebuilt" flag that ``refresh_markets`` raises), ``sea_distances`` (the ocean walks, cached by start hex) and
``refresh_markets`` itself. This module reads them only through those public methods, and the economy module
(``economy.py``) calls the functions here. Imports point down: never world.py, ui, render or pygame.
"""
import heapq
from collections import deque

from ...hexgrid import distance, neighbors, within
from .. import geo
from ..data import (GOODS, MARKET_REACH, MARKETPLACE_CAPACITY, MERCHANT_CAPACITY, PORT_CAPACITY, ROUTE_BASE,
                    SEA_ROUTE_RANGE, SEA_STEP, ATLANTIC_RANGE)
from ..state import Market, Route
from . import worldgen

# What this module changes: the markets and which one each province trades in (province.market, .remote), the trade
# routes and the merchant orders on them (and each country's copy of its orders), the "markets dirty" flag (through
# take_markets_dirty), the ocean-distance cache (through sea_distances), the log (a merchant's message) and the map
# version (changed).
OWNS = ("markets", "routes", "provinces", "countries", "log", "_markets_dirty", "_sea_cache", "version")

INF = float("inf")


def build_markets(world):
    """The empty markets of the map source, with their starting prices (the first rebuild activates them)."""
    world.markets = []
    for name, lon, lat, colonial in world.geo.MARKETS:
        market = Market(name, (lon, lat), colonial)
        for g, good in GOODS.items():
            market.price[g] = good.price
            market.history[g] = []
        market.reset()
        world.markets.append(market)


def ensure_markets(world):
    """Rebuild the markets if something marked them dirty since the last time (at most once per change burst)."""
    if world.take_markets_dirty():
        rebuild_markets(world)


def sea_walk(world, start):
    """Ocean distances from the sea next to `start` (CampaignWorld.sea_distances caches them)."""
    dist = {}
    queue = deque()
    for n in within(start, 2):
        if world.is_sea(n):
            dist[n] = distance(n, start)
            queue.append(n)
    while queue:
        pos = queue.popleft()
        for n in neighbors(pos):
            if world.is_sea(n) and n not in dist:
                dist[n] = dist[pos] + 1
                queue.append(n)
    return dist


def rebuild_markets(world):
    """Activate colonial markets, assign provinces to markets and rebuild trade routes."""
    for market in world.markets:
        pos = geo.hex_of(*market.point)
        near = [world.provinces[p] for p in within(pos, 2) if p in world.provinces and world.provinces[p].owner]
        if market.colonial:
            market.active = bool(near)
            market.center = min(near, key=lambda p: (distance(p.pos, pos), p.pos)).pos if near else None
        else:
            market.center = worldgen.nearest_land(world, pos)
            market.active = world.provinces[market.center].owner is not None
    active = [m for m in world.markets if m.active]
    limits = [MARKET_REACH * (1 + world.bonus(market_owner(world, m), "market_reach")) for m in active]
    best = {}
    heap = []
    for i, market in enumerate(active):
        best[market.center] = (0, i)
        heapq.heappush(heap, (0, market.center, i))
    while heap:
        cost, pos, i = heapq.heappop(heap)
        if best.get(pos, (INF,))[0] < cost:
            continue
        for n in neighbors(pos):
            if n not in world.terrain:
                continue
            if world.is_sea(n):
                step = SEA_STEP if (world.is_sea(pos) or world.provinces.get(pos) and world.provinces[pos].coastal) else INF
            elif world.is_land(n):
                step = world.move_cost(pos, n) if not world.is_sea(pos) else 1
            else:
                continue
            new = cost + step
            if new <= limits[i] and new < best.get(n, (INF,))[0]:
                best[n] = (new, i)
                heapq.heappush(heap, (new, n, i))
    for market in world.markets:
        market.provinces = []
    capital_market = {}
    for prov in world.provinces.values():
        prov.market, prov.remote = None, False
        if prov.owner is None:
            continue
        if prov.pos in best:
            prov.market = active[best[prov.pos][1]]
    for country in world.countries.values():
        home = world.provinces[country.capital]
        capital_market[country.tag] = home.market if home.owner == country.tag else None
    for prov in world.provinces.values():
        if prov.owner and prov.market is None:
            prov.market, prov.remote = capital_market.get(prov.owner), True
        if prov.market:
            prov.market.provinces.append(prov)
    build_routes(world, active)
    world.changed()

def market_owner(world, market):
    prov = world.provinces.get(market.center)
    return prov.owner if prov else None

def build_routes(world, active):
    old = {(r.a.name, r.b.name): r for r in world.routes}
    routes = []
    adjacent = set()
    for prov in world.provinces.values():
        if not prov.market:
            continue
        for n in neighbors(prov.pos):
            other = world.provinces.get(n)
            if other and other.market and other.market is not prov.market:
                adjacent.add(frozenset((prov.market.name, other.market.name)))
    for i, a in enumerate(active):
        for b in active[i + 1:]:
            land = frozenset((a.name, b.name)) in adjacent
            sea_d = INF
            if world.provinces[a.center].coastal or any(world.is_sea(n) for n in within(a.center, 1)):
                seas = world.sea_distances(a.center)
                near_b = [seas[n] for n in within(b.center, 2) if n in seas]
                sea_d = min(near_b) if near_b else INF
            atlantic = (a.colonial != b.colonial) and min(a.point[0], b.point[0]) < -20 and \
                max(a.point[0], b.point[0]) < 12
            both_colonial = a.colonial and b.colonial
            owners = (market_owner(world, a), market_owner(world, b))
            sea_range = SEA_ROUTE_RANGE * (1 + max(world.bonus(o, "sea_range") for o in owners))
            flag_ok = any(world.has(o, "atlantic") for o in owners)
            if land:
                route = (distance(a.center, b.center), False)
            elif sea_d <= sea_range or (sea_d <= ATLANTIC_RANGE and flag_ok and (atlantic or both_colonial)):
                route = (sea_d, True)
            else:
                continue
            key = (a.name, b.name)
            kept = old.get(key)
            r = Route(len(routes), a, b, route[0], route[1])
            if kept:
                r.orders = kept.orders
            routes.append(r)
    world.routes = routes
    for country in world.countries.values():
        country.orders = [(r.id, good, src) for r in routes for tag, good, src in r.orders if tag == country.tag]

def routes_of(world, market):
    return [r for r in world.routes if r.a is market or r.b is market]

def route_capacity(world, route):
    """Goods the background trade moves along a route each season (merchants come on top)."""
    cap = ROUTE_BASE
    for market in (route.a, route.b):
        prov = world.provinces.get(market.center)
        if prov:
            cap += MARKETPLACE_CAPACITY * prov.level("marketplace")
            if route.sea:
                cap += PORT_CAPACITY * prov.level("port")
    return cap

def route_cost(world, route):
    """Cost per unit on a trade route: a colonial market's owner may make colonial routes cheaper."""
    cuts = [world.bonus(market_owner(world, m), "colonial_route_cost") for m in (route.a, route.b) if m.colonial]
    return route.cost * (1 + min(cuts, default=0))

def merchants(world, tag):
    levels = sum(p.level("marketplace") for p in world.provinces_of(tag))
    owns_market = any(m.active and market_owner(world, m) == tag for m in world.markets)
    return min(6, 1 + owns_market + levels // 3) + int(world.bonus(tag, "merchants"))

def merchant_markets(world, tag):
    return {p.market for p in world.provinces_of(tag) if p.market}

def market_named(world, name):
    return next(m for m in world.markets if m.name == name)

def merchant_options(world, tag, route):
    """What a merchant could do on this route: [(good, source, destination, profit per unit, amount)]."""
    mine = merchant_markets(world, tag)
    options = []
    for g, good in GOODS.items():
        if good.kind == "money":
            continue
        for src, dst in ((route.a, route.b), (route.b, route.a)):
            if src not in mine and dst not in mine:
                continue
            spare = max(0.0, src.supply[g] - src.demand[g] * 0.5)
            amount = min(MERCHANT_CAPACITY, spare)
            if amount < 0.5:
                continue
            margin = dst.price[g] - src.price[g] - route_cost(world, route)
            options.append((g, src, dst, margin, amount))
    options.sort(key=lambda o: -o[3] * o[4])
    return options

def send_merchant_check(world, tag, route):
    country = world.countries[tag]
    if len(country.orders) >= merchants(world, tag):
        return False, "All your merchants are busy (recall one first)"
    if route.a not in merchant_markets(world, tag) and route.b not in merchant_markets(world, tag):
        return False, "Merchants work routes from markets where you own land"
    return True, ""

def send_merchant(world, tag, route, good=None, src=None):
    """Give a merchant an order: carry `good` from market `src` along the route."""
    if not send_merchant_check(world, tag, route)[0]:
        return False
    if good is None:
        options = merchant_options(world, tag, route)
        if not options:
            return False
        good, src = options[0][0], options[0][1]
    name = src.name if hasattr(src, "name") else src
    route.orders.append((tag, good, name))
    world.countries[tag].orders.append((route.id, good, name))
    other = route.b.name if name == route.a.name else route.a.name
    world.message(f"A merchant now carries {GOODS[good].name.lower()} from {name} to {other}.", tag, "merchant")
    return True

def recall_merchant(world, tag, route, order=None):
    mine = [o for o in route.orders if o[0] == tag and (order is None or o[1:] == tuple(order[-2:]))]
    if not mine:
        return False
    route.orders.remove(mine[-1])
    world.countries[tag].orders.remove((route.id,) + mine[-1][1:])
    return True

def merchants_trade(world, route):
    """Each merchant carries the good it was ordered to, profit or loss."""
    route.results = []
    for tag, g, src_name in route.orders:
        src = route.a if route.a.name == src_name else route.b
        dst = route.other(src)
        amount = min(MERCHANT_CAPACITY, max(0.0, src.supply[g] - src.demand[g] * 0.5))
        margin = dst.price[g] - src.price[g] - route_cost(world, route)
        if amount > 0:
            src.supply[g] -= amount
            src.exports[g] += amount
            dst.supply[g] += amount
            dst.imports[g] += amount
        route.results.append((tag, g, amount, amount * margin))

def trade_route(world, route):
    capacity = route_capacity(world, route)
    cost = route_cost(world, route)
    offers = []
    for g, good in GOODS.items():
        if good.kind == "money":
            continue
        for src, dst in ((route.a, route.b), (route.b, route.a)):
            margin = dst.price[g] - src.price[g] - cost
            if margin > 0:
                offers.append((margin, g, src, dst))
    offers.sort(key=lambda o: -o[0])
    route.flows, route.profit = [], 0.0
    left = capacity
    for margin, g, src, dst in offers:
        if left <= 0.05:
            break
        amount = min(left, max(0.0, src.supply[g] - src.demand[g] * 0.7),
                     max(0.0, dst.demand[g] - dst.supply[g] * 0.7))
        if amount < 0.05:
            continue
        src.supply[g] -= amount
        src.exports[g] += amount
        dst.supply[g] += amount
        dst.imports[g] += amount
        route.flows.append((g, amount, src, dst))
        route.profit += amount * margin
        left -= amount
