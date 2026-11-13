"""World generation: everything that is only run while a world is being built, as functions taking ``world``.

``CampaignWorld.__init__`` calls them in order: build_map (land and sea, rivers, terrain by wave function collapse,
cities, provinces and their goods, the ridge edges), build_countries (borders, names, people, starting buildings),
the start techs (research system), build_roads, the markets (trade system), starting_units. The finished world is
then pickled into world._SNAPSHOTS, so each (map, seed) is built once per process. The ridge crest functions
(crest_edges, build_edges, join_pockets) also run again when a save was made under another PASS_RULE.

Imports point down: this module imports the data, the geography and the state classes, never world.py, ui, render
or pygame. It changes the world only through the attributes listed in OWNS, plus the units add_unit appends.
"""
import heapq
import random
from collections import deque

from ...hexgrid import distance, neighbors, to_cube, within
from .. import geo, naming, wfc
from ..data import (AREA, CARAVEL, GARRISON_HP, GENERAL, SETTLEMENT_POP, TERRAIN, TERRITORY_RADIUS, WORKS, troop)
from ..specialgoods import special_good
from ..state import Country, Province

# World attributes this module sets while building (a later system may change them, none but this one makes them).
OWNS = ("terrain", "rivers", "river_at", "sea_body", "cities", "provinces", "landmass", "countries", "colonial",
        "roads", "road_paths")

INF = float("inf")
SCALE = geo.SCALE
# Terrain that may not touch (wave function collapse rules): mountains rise through hills, deserts
# fade through steppe and savanna, snow sits next to tundra, taiga and mountains...
FORBIDDEN = [("mountains", t) for t in ("plains", "marsh", "beach", "steppe")] + \
    [("desert", t) for t in ("jungle", "marsh", "taiga", "snow", "forest", "tundra")] + \
    [("snow", t) for t in ("plains", "jungle", "savanna", "beach", "desert", "steppe", "marsh")] + \
    [("jungle", t) for t in ("taiga", "tundra", "steppe")] + \
    [("taiga", t) for t in ("savanna", "beach")] + [("tundra", t) for t in ("jungle", "savanna")] + \
    [("marsh", "savanna")]


def build_map(world):
    g = world.geo
    land, lakes = g.land_cells(world.cols, world.rows)
    world.terrain = {}
    for r in range(world.rows):
        for c in range(world.cols):
            world.terrain[(c, r)] = "lake" if (c, r) in lakes else "ocean"
    for lon, lat in list(g.FORCE_LAND) + [(x[1], x[2]) for x in g.CITIES]:
        pos = geo.hex_of(lon, lat)
        if pos in world.terrain:
            land.add(pos)
            lakes.discard(pos)
    land -= lakes
    for lon, lat in getattr(g, "FORCE_SEA", ()):
        land.discard(geo.hex_of(lon, lat))

    # Rivers, traced onto the hexes they flow through.
    world.rivers, world.river_at = {}, {}
    for name, line in g.RIVERS:
        path = [p for p in trace(world, line) if p in land]
        if len(path) >= 3:
            world.rivers[name] = path
            for pos in path:
                world.river_at.setdefault(pos, name)

    # Terrain by wave function collapse: each hex gets odds from its geography, and
    # neighbouring hexes must fit together.
    coastal = {p for p in land if any(n in world.terrain and n not in land for n in neighbors(p))}
    prior = {p: terrain_prior(world, p, p in coastal, p in world.river_at) for p in land}
    tiles = wfc.collapse(sorted(land), prior, FORBIDDEN, neighbors, random.Random(world.seed), affinity=1.6)
    for pos, tile in tiles.items():
        world.terrain[pos] = tile
    rng = random.Random(1480)

    world.sea_body = {}
    body = 0
    for pos in world.terrain:
        if world.terrain[pos] != "ocean" or pos in world.sea_body:
            continue
        body += 1
        queue = deque([pos])
        world.sea_body[pos] = body
        while queue:
            cur = queue.popleft()
            for n in neighbors(cur):
                if world.terrain.get(n) == "ocean" and n not in world.sea_body:
                    world.sea_body[n] = body
                    queue.append(n)
    world.cities = {}
    for name, lon, lat, size in g.CITIES:
        pos = geo.hex_of(lon, lat)
        if world.is_land(pos):
            world.cities[pos] = (name, size)
    world.provinces = {}
    for pos in sorted(p for p, t in world.terrain.items() if TERRAIN[t].move is not None):
        coastal = any(world.terrain.get(n) == "ocean" for n in neighbors(pos))
        world.provinces[pos] = Province(pos, world.terrain[pos], None, coastal, "", city=pos in world.cities)
    for prov in world.provinces.values():
        prov.good = good_for(world, prov, rng)
    world.passes()                   # ridge edges and passes, kept in the snapshot


def trace(world, line):
    """The hexes a (lon, lat) polyline passes through, in order, without loops."""
    out = []
    for (x0, y0), (x1, y1) in zip(line, line[1:]):
        steps = max(1, int(max(abs(x1 - x0), abs(y1 - y0)) / geo.COL_DEG * 4))
        for i in range(steps + 1):
            t = i / steps
            pos = geo.hex_of(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
            if pos not in world.terrain or (out and out[-1] == pos):
                continue
            if pos in out:
                del out[out.index(pos) + 1:]
                continue
            if out and distance(out[-1], pos) > 1:       # fill a skipped corner
                between = [n for n in neighbors(out[-1]) if distance(n, pos) == 1]
                if between:
                    out.append(min(between))
            out.append(pos)
    return out


def near_line(point, lines, limit):
    """Distance in degrees to the nearest line, or `limit` if none is closer."""
    best = limit
    lon, lat = point
    for line in lines:
        for (ax, ay), (bx, by) in zip(line, line[1:]):
            if min(ax, bx) - limit > lon or max(ax, bx) + limit < lon or \
                    min(ay, by) - limit > lat or max(ay, by) + limit < lat:
                continue
            best = min(best, geo.seg_distance(point, (ax, ay), (bx, by)))
    return best


def terrain_prior(world, pos, coastal, river):
    """Odds for each kind of terrain on a land hex, from what is known about the place."""
    g = world.geo
    point = geo.lonlat(pos)
    lon, lat = point
    mount = near_line(point, g.MOUNTAINS, 2.0)
    if mount < 0.8:
        return {"mountains": 1.0, "snow": 0.35 if lat > 45.5 or (lon < -30 and lat > 50) else 0.0,
                "hills": 0.15}
    hills = mount < 1.6 or near_line(point, g.HILLS, 1.0) < 1.0
    desert = g.desert_at(point)
    marsh = g.marsh_at(point)
    americas = lon < -30
    maghreb = getattr(g, "maghreb_at", None)
    north_africa = bool(maghreb and maghreb(point))     # Morocco to Egypt: steppe and desert, not forest
    if river:
        if desert:
            return {"plains": 1.0, "marsh": 0.08 + marsh}
        return {"plains": 1.0, "marsh": 0.15 + marsh, "forest": 0.15, "hills": 0.05}
    if desert:
        if -20 < lon < 40 and 12 < lat < 18.5:         # the Sahel: the desert fades into steppe and savanna
            return {"desert": 0.55, "steppe": 0.3, "savanna": 0.3, "hills": 0.04 if hills else 0.0}
        if north_africa and lat > 28.5:                # the northern edge of the Sahara
            return {"desert": 1.0, "steppe": 0.22, "hills": 0.04 if hills else 0.0}
        return {"desert": 1.0, "steppe": 0.06, "hills": 0.04 if hills else 0.0}
    if hills:
        if north_africa:
            return {"hills": 0.7, "steppe": 0.25, "forest": 0.03, "mountains": 0.08 if mount < 1.2 else 0.0}
        w = {"hills": 0.7, "forest": 0.25, "mountains": 0.08 if mount < 1.2 else 0.0}
        if lat > 57:
            w["taiga"] = 0.3
        if lat < 17:
            w["jungle" if lat < 8 else "savanna"] = 0.2
        return w
    if americas:
        if lat >= 59:
            return {"tundra": 1.0, "snow": 0.35, "taiga": 0.1}
        if lat >= 55:
            return {"tundra": 0.6, "taiga": 0.6, "marsh": 0.05}
        if lat >= 47:
            return {"taiga": 0.5, "forest": 0.4, "plains": 0.12, "marsh": 0.06 + marsh}
        if lat < 21.5:
            if lon < -95 and lat > 16.5:
                return {"plains": 0.6, "hills": 0.3, "savanna": 0.1}
            w = {"jungle": 0.6 if lat < 14 else 0.35, "plains": 0.15 if lat < 14 else 0.3,
                 "savanna": 0.3 if 2 < lat < 12 and lon > -72 else 0.1, "marsh": 0.04 + marsh}
            if coastal:
                w["beach"] = 0.3
            return w
        w = {"forest": 0.75 if lat > 40 else 0.5, "plains": 0.3 if lat > 40 else 0.45, "marsh": 0.04 + marsh}
        if coastal and lat < 36:
            w["beach"] = 0.25
        return w
    if lat < 17:                                    # Africa south of the Sahara
        if lat < 5.5:                               # the Guinea coast and the Congo: rainforest
            w = {"jungle": 0.7, "plains": 0.1, "savanna": 0.15, "marsh": 0.04 + marsh}
        elif lat < 8:                               # jungle thins into savanna
            w = {"jungle": 0.45, "savanna": 0.45, "plains": 0.1, "marsh": 0.03 + marsh}
        elif lat < 12.5:                            # savanna, with grassland
            w = {"savanna": 0.65, "plains": 0.2, "steppe": 0.15}
        else:                                       # the Sahel: dry savanna and steppe
            w = {"savanna": 0.55, "steppe": 0.35, "plains": 0.1}
        if coastal:
            w["beach"] = 0.2
        return w
    if g.steppe_at(point):
        return {"steppe": 1.0, "plains": 0.12, "marsh": marsh}
    if north_africa:                                # the Maghreb: dry steppe and scrub, desert, a little woodland
        w = {"steppe": 0.5, "plains": 0.3, "desert": 0.3 if lat < 34 else 0.1, "forest": 0.03}
        if coastal:
            w["beach"] = 0.18
        return w
    if lat >= 58 or (lon > 24 and lat >= 55):
        w = {"taiga": 0.5, "forest": 0.25, "plains": 0.2, "marsh": 0.06 + marsh}
    elif lat >= 53:
        w = {"forest": 0.45, "plains": 0.45, "hills": 0.08, "marsh": 0.05 + marsh}
    else:
        w = {"plains": 0.64, "forest": 0.22, "hills": 0.1, "marsh": 0.02 + marsh}
    if coastal and lat < 41:
        w["beach"] = 0.18
    return w


def good_for(world, prov, rng):
    lon, lat = geo.lonlat(prov.pos)
    t, roll = prov.terrain, rng.random()
    americas, africa = lon < -30, lat < 17 and lon > -20
    near = lambda x, y, r=2.5: abs(lon - x) < r and abs(lat - y) < r
    special = special_good(prov, lon, lat, t, rng.random(), americas, near)
    if special:
        return special
    if t == "desert":
        return ("salt" if roll < 0.5 else "fish") if prov.coastal else None
    if t == "marsh":
        return "fish" if prov.coastal and roll < 0.5 else "wool" if roll < 0.75 else "grain"
    if t == "taiga":
        return "furs" if roll < 0.5 else "timber"
    if t == "snow":
        return "furs" if roll < 0.6 else None
    if t == "savanna":
        if americas:
            return "cotton" if roll < 0.4 else "grain" if roll < 0.8 else "tobacco"
        return "ivory" if roll < 0.35 else "grain" if roll < 0.75 else "cotton"
    if t == "beach":
        if prov.coastal and roll < 0.45:
            return "fish"
        if americas or africa:
            return "sugar" if roll < 0.75 else "cotton"
        return "salt" if roll < 0.6 else "wine" if lat < 44 else "grain"
    if t == "tundra":
        return "fish" if prov.coastal and roll < 0.4 else "furs"
    if t == "mountains" or (t == "hills" and roll < 0.3):
        if americas and lon < -95:
            return "silver"
        if near(13.0, 50.5) or near(11.5, 47.3, 1.5):
            return "silver"
        if near(18.9, 48.7, 1.5) or near(-11, 13.5, 3) or near(-1.5, 6.5, 3):
            return "gold"
        if t == "hills" and americas:
            return "furs" if lat > 42 else "timber"
        return "iron" if roll < 0.8 or t == "hills" else "salt"
    if t == "jungle":
        if americas:
            return "sugar" if prov.coastal and roll < 0.6 else "tobacco" if roll < 0.75 else "timber"
        if near(-1.5, 6.5, 3.5):
            return "gold" if roll < 0.5 else "ivory"
        return "ivory" if roll < 0.6 else "timber"
    if t == "forest":
        if (americas and lat > 42) or (lon > 22 and lat > 57):
            return "furs" if roll < 0.55 else "timber"
        if prov.coastal and lat > 48 and roll < 0.25:
            return "fish"
        return "timber"
    if t == "steppe":
        return "grain" if roll < 0.55 else "wool"
    if prov.coastal and (lat > 48 or (americas and lat > 40)) and roll < (0.6 if americas else 0.3):
        return "fish"
    if americas:
        if lat < 25:
            if lon < -95:
                return "grain" if roll < 0.6 else "cotton"
            return "sugar" if roll < 0.5 else "tobacco" if roll < 0.75 else "cotton"
        if 33 <= lat <= 39.5:
            return "tobacco" if roll < 0.6 else "grain"
        return "grain"
    if africa:
        return "grain" if roll < 0.5 else "ivory" if roll < 0.75 else "cotton"
    if lat < 37.5 and lon > 29 and prov.coastal and roll < 0.45:
        return "spices"
    if lat < 44.5 and -10 < lon < 40:
        if lon > 26 and roll < 0.25:
            return "cotton"
        return "grain" if roll < 0.55 else "wine" if roll < 0.9 else "wool"
    if near(20.0, 50.0, 1) or near(10.4, 53.25, 1) or near(13.0, 47.8, 1):
        return "salt"
    wool = 0.35 if (lon < 2 and lat > 50) or (-7 < lon < -1 and 39 < lat < 43) else 0.15
    return "wool" if roll < wool else "grain"


def build_countries(world):
    land = list(world.provinces)
    landmass, comp = {}, 0
    for pos in land:
        if pos in landmass:
            continue
        comp += 1
        queue = deque([pos])
        landmass[pos] = comp
        while queue:
            cur = queue.popleft()
            for n in neighbors(cur):
                if n in world.provinces and n not in landmass:
                    landmass[n] = comp
                    queue.append(n)
    world.landmass = landmass

    world.countries = {}
    seeds = []
    for tag, (name, color, points) in world.geo.COUNTRIES.items():
        capital = nearest_land(world, geo.hex_of(*points[0]))
        world.countries[tag] = Country(tag, name, color, capital)
        for lon, lat in points:
            pos = nearest_land(world, geo.hex_of(lon, lat))
            seeds.append((tag, pos, to_cube(pos), landmass[pos]))
    reach = TERRITORY_RADIUS * (1.7 if world.map == "random" else 1)
    for prov in world.provinces.values():
        q, r, s = to_cube(prov.pos)
        best = None
        for tag, pos, (sq, sr, ss), mass in seeds:
            d = max(abs(q - sq), abs(r - sr), abs(s - ss))
            limit = reach if mass == landmass[prov.pos] else 1
            if d <= limit and (best is None or d < best[0]):
                best = (d, tag)
        if best and not (prov.terrain == "desert" and best[0] > 2 * SCALE):
            prov.owner = prov.controller = best[1]
    for tag, country in world.countries.items():
        world.provinces[country.capital].owner = world.provinces[country.capital].controller = tag

    # Names, natives and population.
    rng = random.Random(7)
    named = list(world.cities.items())
    for prov in world.provinces.values():
        lon, lat = geo.lonlat(prov.pos)
        if prov.pos in world.cities:
            prov.name = world.cities[prov.pos][0]
        elif world.map != "europe":
            near = min(named, key=lambda kv: distance(kv[0], prov.pos))
            if distance(near[0], prov.pos) <= 4 * SCALE:
                prov.name = f"near {near[1][0]}"
        if prov.owner is None:
            prov.tribe = min(world.geo.TRIBES, key=lambda t: (t[1] - lon) ** 2 + (t[2] - lat) ** 2)[0]
            if not prov.name and world.map != "europe":
                prov.name = f"{prov.tribe} lands"
        elif not prov.name and world.map != "europe":
            prov.name = f"{world.countries[prov.owner].name} countryside"
        density = TERRAIN[prov.terrain].density * rng.uniform(0.75, 1.25)
        if prov.owner:
            factor = 1.0
            if (-5 < lon < 17 and 40 < lat < 46) or (2 < lon < 7 and 50 < lat < 53):
                factor = 1.35
            elif lon > 30 and lat > 50:
                factor = 0.45
            elif lat > 58:
                factor = 0.4
            elif lat < 37.5 and lon < 28:
                factor = 0.7
            if world.geo.FERTILE_RIVERS and geo.line_distance((lon, lat), world.geo.FERTILE_RIVERS[0]) < 1:
                factor = 2.2
            elif prov.pos in world.river_at:
                factor *= 1.3
            prov.peasants = density * factor * 0.94
            prov.burghers = density * factor * 0.03
            prov.nobles = density * factor * 0.03
            if prov.pos in world.cities:
                extra = world.cities[prov.pos][1]
                prov.peasants += extra * 0.4
                prov.burghers += extra * 0.55
                prov.nobles += extra * 0.05
        else:
            factor = 0.35 if lon < -30 else 0.6 if lat < 17 else 0.5
            if prov.tribe in ("Mexica",):
                factor = 1.6
            elif prov.tribe in ("Maya", "Muisca", "Benin", "Akan", "Yoruba", "Hausa"):
                factor = 0.9
            prov.natives = density * factor
            if prov.pos in world.cities:
                prov.natives += world.cities[prov.pos][1] * 0.5

    if world.map == "europe":
        naming.name_europe(world)          # real regions and places (naming.py)
    else:
        naming.make_unique(world.provinces)

    # Starting towns, castles, works and buildings.
    for prov in world.provinces.values():
        if not prov.owner:
            continue
        capital = world.countries[prov.owner].capital == prov.pos
        if prov.city:
            prov.settlement = 3 if world.cities[prov.pos][1] >= 40 else 2
        elif prov.pop >= SETTLEMENT_POP[1] * 2.5:
            prov.settlement = 1
        if capital:
            prov.settlement = max(prov.settlement, 2)
            prov.castle = 3 if world.cities.get(prov.pos, ("", 0))[1] >= 100 else 2
        elif prov.settlement >= 2 and rng.random() < 0.3:
            prov.castle = 1
        if prov.coastal and (capital or (prov.city and world.cities[prov.pos][1] >= 25)):
            prov.buildings["port"] = 1
        if prov.burghers >= 14:
            prov.buildings["weaver"] = 1
        if prov.city and prov.burghers >= 8:            # the old trades of the big towns
            h = (prov.pos[0] * 31 + prov.pos[1] * 17) % 7
            if prov.level("port") or (prov.coastal and h < 3):
                prov.buildings["ropewalk"] = 1
            if capital or h == 1:
                prov.buildings["powder_mill"] = 1
            if h in (2, 5):
                prov.buildings["tannery"] = 1
            if h == 4 or prov.name in ("Venice", "Genoa", "Antwerp", "Nuremberg", "Constantinople"):
                prov.buildings["glassworks"] = 1
        if prov.burghers >= 30:
            prov.buildings["marketplace"] = 1
        if prov.good and prov.good in WORKS and rng.random() < 0.25:
            prov.works = 2 if prov.pop > 20 and rng.random() < 0.4 else 1
    for country in world.countries.values():
        mine = world.provinces_of(country.tag)
        coast = [p for p in mine if p.coastal]
        if coast and not any(p.level("port") for p in mine):
            max(coast, key=lambda p: (p.pop, p.pos)).buildings["port"] = 1
        country.treasury = 150 + 4 / AREA * len(world.provinces_of(country.tag))
    world.colonial = dict(getattr(world.geo, "COLONIAL", {}))


def build_roads(world):
    """Roads join each country's towns to the nearest town already on its network, and capitals to
    neighbouring capitals. Armies march along them at one move per hex."""
    world.roads, world.road_paths = set(), []
    summer_walls = frozenset(pair for e in world.ridge_edges() for a, b in (sorted(e),) for pair in ((a, b), (b, a)))

    def connect(start, goals, limit, owner=None):
        best = {start: (0, None)}
        heap = [(0, start)]
        while heap:
            cost, pos = heapq.heappop(heap)
            if cost > best[pos][0]:
                continue
            if pos in goals and pos != start:
                path = []
                while pos is not None:
                    path.append(pos)
                    pos = best[pos][1]
                return path[::-1]
            for n in neighbors(pos):
                prov = world.provinces.get(n)
                if prov is None or (owner and prov.owner != owner) or (pos, n) in summer_walls:
                    continue
                step = 0.5 if n in world.roads else TERRAIN[prov.terrain].move
                if cost + step <= limit and cost + step < best.get(n, (INF,))[0]:
                    best[n] = (cost + step, pos)
                    heapq.heappush(heap, (cost + step, n))
        return None

    for tag, country in world.countries.items():
        towns = [p.pos for p in world.provinces_of(tag) if p.settlement >= 2 or p.city]
        network = {country.capital}
        for pos in sorted(towns, key=lambda q: distance(q, country.capital)):
            if pos in network:
                continue
            path = connect(pos, network, 14 * SCALE, owner=tag)
            if path:
                world.road_paths.append(path)
                world.roads.update(path)
            network.add(pos)
    capitals = [c.capital for c in world.countries.values()]
    for i, a in enumerate(capitals):
        for b in capitals[i + 1:]:
            if world.landmass.get(a) == world.landmass.get(b) and distance(a, b) <= 9 * SCALE:
                path = connect(a, {b}, 16 * SCALE)
                if path:
                    world.road_paths.append(path)
                    world.roads.update(path)


def starting_units(world):
    for prov in world.provinces.values():
        prov.garrison = prov.castle * GARRISON_HP
    for tag, country in world.countries.items():
        pop = world.total_pop(tag)
        kinds = ([troop("infantry", 1)] * max(1, round(pop / 450)) + [troop("cavalry", 1)] * round(pop / 1000)
                 + [troop("artillery", 1)] * (1 if pop > 900 else 0))
        if pop > 1500:
            kinds.append(GENERAL)
        for kind in kinds:
            spot = world.land_spot(tag, world.provinces[country.capital], kind)
            if spot:
                world.add_unit(kind, tag, spot, moves=kind.moves)
        if world.colonial.get(tag, 999) <= 40:
            ports = [p for p in world.provinces_of(tag) if p.level("port")]
            ports.sort(key=lambda p: (geo.lonlat(p.pos)[0], -p.pop))
            for prov in ports:
                sea = [n for n in neighbors(prov.pos) if world.is_sea(n) and not world.units_at(n)]
                if sea:
                    world.add_unit(CARAVEL, tag, sea[0], moves=CARAVEL.moves)
                    break


def nearest_land(world, pos):
    if pos in world.provinces:
        return pos
    return min(world.provinces, key=lambda p: (distance(p, pos), p))


def unit_point(lon, lat):
    """A (lon, lat) in hex-grid units: hex centres are 1 apart along a row, 0.866 between rows."""
    return (lon - geo.LON0) / geo.COL_DEG, (geo.Y_TOP - geo.merc(lat)) / geo.COL_DEG


def unit_centre(pos):
    col, row = pos
    return col + 0.5 * (row & 1) + 0.5, (row + 0.5) * 0.8660254


def crest_edges(world, land):
    """Every edge between two neighbouring land hexes that a ridge polyline of the geography crosses, i.e. the
    polyline (in hex-grid units) cuts the segment joining the two hex centres an odd number of times. A curve that
    crosses the grid of hex centres cannot slip between two blocked edges, so a ridge is a continuous wall."""
    found = set()
    shift = (1.3e-6, 2.1e-6)                       # keeps a vertex off an exact crossing, deterministically
    for line in world.geo.MOUNTAINS:
        crossings = {}
        pts = [unit_point(lon, lat) for lon, lat in line]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            x0, y0, x1, y1 = x0 + shift[0], y0 + shift[1], x1 + shift[0], y1 + shift[1]
            steps = max(1, int(max(abs(x1 - x0), abs(y1 - y0)) / 0.4) + 1)
            near = set()
            for i in range(steps + 1):
                t = i / steps
                x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                pos = geo.hex_of(geo.LON0 + x * geo.COL_DEG, geo.inv_merc(geo.Y_TOP - y * geo.COL_DEG))
                near.update(within(pos, 1))
            for a in near:
                if a not in land:
                    continue
                ax, ay = unit_centre(a)
                for b in neighbors(a):
                    if b not in land or b < a:
                        continue
                    bx, by = unit_centre(b)
                    if cross(x0, y0, x1, y1, ax, ay, bx, by):
                        edge = frozenset((a, b))
                        crossings[edge] = crossings.get(edge, 0) + 1
        # a ridge that bends round an edge crosses it twice and does not separate its two hexes: only an odd
        # number of crossings makes the edge part of the crest
        found.update(e for e, n in crossings.items() if n % 2)
    return found


def cross(x0, y0, x1, y1, ax, ay, bx, by):
    """Whether the segments (x0, y0)-(x1, y1) and (a)-(b) cross."""
    d1x, d1y, d2x, d2y = x1 - x0, y1 - y0, bx - ax, by - ay
    den = d1x * d2y - d1y * d2x
    if abs(den) < 1e-12:
        return False
    t = ((ax - x0) * d2y - (ay - y0) * d2x) / den
    u = ((ax - x0) * d1y - (ay - y0) * d1x) / den
    return 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0


def build_edges(world):
    """(ridge, passes): the crest edges of the geography, and the ones left open as passes (see _pass_data)."""
    land = {p for p, t in world.terrain.items() if TERRAIN[t].move is not None}
    crest = crest_edges(world, land)
    passes = {}
    for k, (name, lon, lat) in enumerate(getattr(world.geo, "PASSES", ()), 1):
        px, py = unit_point(lon, lat)

        def gap(edge):
            (ax, ay), (bx, by) = (unit_centre(p) for p in sorted(edge))
            return ((px - (ax + bx) / 2) ** 2 + (py - (ay + by) / 2) ** 2) ** 0.5, sorted(edge)
        ranked = sorted((e for e in crest if e not in passes), key=gap)[:2]
        if not ranked or gap(ranked[0])[0] > 2.5:
            continue
        passes[ranked[0]] = (name, k)
        if len(ranked) > 1 and gap(ranked[1])[0] <= 1.0:
            passes[ranked[1]] = (name, k)
    join_pockets(world, land, crest, passes)
    return frozenset(e for e in crest if e not in passes), passes


def join_pockets(world, land, crest, passes):
    """Open one more pass edge wherever the ridges (with their passes) would cut a landmass in two: the pieces
    of a landmass are joined by the shortest chain of crest edges, one new pass per link, named after the
    nearest city."""
    shut = {e for e in crest if e not in passes}

    def label(blocked):
        ids, count = {}, 0
        for p in sorted(land):
            if p in ids:
                continue
            count += 1
            ids[p] = count
            queue = deque([p])
            while queue:
                cur = queue.popleft()
                for n in neighbors(cur):
                    if n in land and n not in ids and frozenset((cur, n)) not in blocked:
                        ids[n] = count
                        queue.append(n)
        return ids

    flat = label(shut)
    links = {}
    for e in sorted(shut, key=sorted):
        a, b = sorted(e)
        if flat[a] != flat[b]:
            links.setdefault(tuple(sorted((flat[a], flat[b]))), []).append(e)
    parent = {}

    def find(i):
        parent.setdefault(i, i)
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    size = {}
    for i in flat.values():
        size[i] = size.get(i, 0) + 1
    number = max((pid for _, pid in passes.values()), default=0)
    for pair in sorted(links, key=lambda p: (-min(size[p[0]], size[p[1]]), p)):
        i, j = pair
        if find(i) == find(j):
            continue
        edge = links[pair][0]
        number += 1
        passes[edge] = (pass_name_near(world, sorted(edge)[0], {n for n, _ in passes.values()}), number)
        parent[find(i)] = find(j)


def pass_name_near(world, pos, taken):
    """A name for a new pass: the nearest city's, with II, III... added when that name is already a pass."""
    base = world.cities[min((distance(c, pos), c) for c in world.cities)[1]][0] if world.cities else "Mountain"
    name, n = base, 1
    while name in taken:
        n += 1
        name = f"{base} {'I' * n if n < 4 else 'IV' if n == 4 else str(n)}"
    return name
