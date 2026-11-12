"""Province names: real places and historical regions on the Europe map, unique names on random worlds.

Europe 1480: every land hex gets a region (regions.py: the nearest anchor on the same landmass, an anchor of the
hex's own country counting as closer, the geo cities seeding the region around them) and, in the old world, the name
of a real town or village inside it (placenames.py, pruned from GeoNames, CC BY 4.0). Hexes with no place are named
for what they are: "<Region> (north-west woods)". The New World never gets modern town names, only the native
peoples' lands. Random worlds keep their generated names and only get made unique.
Names follow one rule: an English name where a well-known one exists (Constantinople, Danzig, Breslau, Pressburg,
Smyrna, Lemberg, Ragusa), otherwise the local name with its diacritics, except that Cyrillic, Arabic and Greek names
are written without them (the data holds them that way). Hungary's towns use Hungarian names, as in 1480.
Everything here is deterministic and free of pygame and of the game rules.
"""
import math

from ..hexgrid import within
from . import geo, placenames, regions

COMPASS = ("east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east")
OWN_WEIGHT = 0.7                     # a region of the hex's own country counts as this much closer
SEA_PENALTY = 10.0                   # an anchor on another landmass counts as this many times farther (squared)
_CELL = 4.0                          # degrees per bucket of the anchor grid

# The modern names in the data, as people wrote them in 1480.
EXONYMS = {
    "Istanbul": "Constantinople", "Gdańsk": "Danzig", "Wrocław": "Breslau", "Szczecin": "Stettin",
    "Klaipėda": "Memel", "Tallinn": "Reval", "Tartu": "Dorpat", "Lviv": "Lemberg", "Chernivtsi": "Cernăuți",
    "Kyiv": "Kiev", "Bratislava": "Pressburg", "Dubrovnik": "Ragusa", "İzmir": "Smyrna", "Gelibolu": "Gallipoli",
    "Antakya": "Antioch", "İskenderun": "Alexandretta", "Trabzon": "Trebizond", "Şanlıurfa": "Urfa", "Akko": "Acre",
    "Dumyat": "Damietta", "Rashid": "Rosetta", "Bejaia": "Bougie", "Plzeň": "Pilsen", "Donostia": "San Sebastián",
    "Nizhniy Novgorod": "Nizhny Novgorod", "Siwah": "Siwa", "Hrodna": "Grodno", "Homyel'": "Gomel", "Mahilyow": "Mogilev",
    # Hungary 1480: Hungarian names (Slovakia, Transylvania, the Banat and Vojvodina).
    "Cluj-Napoca": "Kolozsvár", "Brașov": "Brassó", "Brasov": "Brassó", "Sibiu": "Nagyszeben",
    "Timișoara": "Temesvár", "Oradea": "Nagyvárad", "Târgu Mureş": "Marosvásárhely", "Târgu Mureș": "Marosvásárhely",
    "Satu Mare": "Szatmárnémeti", "Baia Mare": "Nagybánya", "Alba Iulia": "Gyulafehérvár",
    "Sighişoara": "Segesvár", "Sighișoara": "Segesvár", "Bistriţa": "Beszterce", "Bistrița": "Beszterce",
    "Mediaş": "Medgyes", "Mediaș": "Medgyes", "Deva": "Déva", "Lugoj": "Lugos", "Miercurea Ciuc": "Csíkszereda",
    "Sfântu Gheorghe": "Sepsiszentgyörgy", "Odorheiu Secuiesc": "Székelyudvarhely", "Turda": "Torda", "Dej": "Dés",
    "Zalău": "Zilah", "Carei": "Nagykároly", "Hunedoara": "Vajdahunyad", "Făgăraş": "Fogaras", "Făgăraș": "Fogaras",
    "Sebeş": "Szászsebes", "Sebeș": "Szászsebes", "Orăştie": "Szászváros", "Orăștie": "Szászváros",
    "Aiud": "Nagyenyed", "Blaj": "Balázsfalva", "Košice": "Kassa", "Nitra": "Nyitra", "Prešov": "Eperjes",
    "Žilina": "Zsolna", "Banská Bystrica": "Besztercebánya", "Trnava": "Nagyszombat", "Trenčín": "Trencsén",
    "Martin": "Turócszentmárton", "Poprad": "Poprád", "Zvolen": "Zólyom", "Michalovce": "Nagymihály",
    "Komárno": "Komárom", "Levice": "Léva", "Bardejov": "Bártfa", "Liptovský Mikuláš": "Liptószentmiklós",
    "Piešťany": "Pöstyén", "Ružomberok": "Rózsahegy", "Lučenec": "Losonc", "Topoľčany": "Nagytapolcsány",
    "Trebišov": "Töketerebes", "Dunajská Streda": "Dunaszerdahely", "Stará Ľubovňa": "Ólubló", "Skalica": "Szakolca",
    "Kežmarok": "Késmárk", "Levoča": "Lőcse", "Rožňava": "Rozsnyó", "Banská Štiavnica": "Selmecbánya",
    "Púchov": "Puhó", "Spišská Nová Ves": "Igló", "Humenné": "Homonna", "Brezno": "Breznóbánya",
    "Senica": "Szenice", "Čadca": "Csaca", "Sabinov": "Kisszeben", "Novi Sad": "Újvidék", "Subotica": "Szabadka",
    "Sombor": "Zombor", "Kikinda": "Nagykikinda", "Vršac": "Versec", "Senta": "Zenta", "Bečej": "Óbecse",
    "Bela Crkva": "Fehértemplom", "Sremska Mitrovica": "Szávaszentdemeter",
}
SKIP = {"Petržalka", "Karlova Ves"}          # districts of a bigger town, not places


# ----- regions -----------------------------------------------------------------------------------------------
def _anchors(provinces, landmass):
    """[(name, lon, lat, tag, landmass)] for every anchor: the regions, and the geo cities that name a region."""
    tags = {}
    for name, _, _, tag in regions.REGIONS:
        tags.setdefault(name, tag)
    found = [(name, x, y, tag) for name, x, y, tag in regions.REGIONS]
    for city, x, y, _ in geo.CITIES:
        region = regions.CITY_REGION.get(city)
        if region:
            found.append((region, x, y, tags.get(region)))
    out = []
    for name, x, y, tag in found:
        pos = geo.hex_of(x, y)
        mass = landmass.get(pos)
        if mass is None:
            mass = next((landmass[p] for p in sorted(within(pos, 2), key=lambda q: (q != pos, q)) if p in landmass), None)
        out.append((name, x, y, tag, mass))
    return out


def _grid(anchors):
    grid = {}
    for anchor in anchors:
        grid.setdefault((int(anchor[1] // _CELL), int(anchor[2] // _CELL)), []).append(anchor)
    return grid


def region_of(grid, lon, lat, owner=None, mass=None):
    """The name of the region a point belongs to: the nearest anchor, owner's anchors counted as closer and
    anchors on another landmass as farther."""
    kx = max(0.2, math.cos(math.radians(lat)))
    cx, cy = int(lon // _CELL), int(lat // _CELL)
    best, best_d = None, None
    for ring in range(0, 40):
        if best is not None and (ring - 1) * _CELL * kx * OWN_WEIGHT >= best_d ** 0.5:
            break
        for gx in range(cx - ring, cx + ring + 1):
            for gy in range(cy - ring, cy + ring + 1):
                if max(abs(gx - cx), abs(gy - cy)) != ring:
                    continue
                for name, x, y, tag, amass in grid.get((gx, gy), ()):
                    d = ((lon - x) * kx) ** 2 + (lat - y) ** 2
                    if mass is not None and amass != mass:
                        d *= SEA_PENALTY
                    if owner is not None and tag == owner:
                        d *= OWN_WEIGHT * OWN_WEIGHT
                    if best is None or d < best_d or (d == best_d and name < best):
                        best, best_d = name, d
    return best


def assign_regions(provinces, landmass=None, cities=None):
    """Set every province's region (deterministic: nothing here depends on order or hashing). A geo city's hex
    takes its city's region."""
    landmass = landmass or {}
    grid = _grid(_anchors(provinces, landmass))
    for pos in sorted(provinces):
        prov = provinces[pos]
        lon, lat = geo.lonlat(pos)
        prov.region = region_of(grid, lon, lat, prov.owner, landmass.get(pos)) or ""
    for pos, (city, _) in (cities or {}).items():
        if pos in provinces and city in regions.CITY_REGION:
            provinces[pos].region = regions.CITY_REGION[city]


# ----- unique names -------------------------------------------------------------------------------------------
LAND_WORDS = {
    "plains": ("plains", "lowlands", "meadows", "fields"), "steppe": ("steppe", "grasslands", "prairie", "range"),
    "forest": ("forest", "woods", "woodland", "weald"), "hills": ("hills", "uplands", "heights", "downs"),
    "mountains": ("mountains", "highlands", "peaks", "ranges"), "desert": ("desert", "dunes", "wastes", "sands"),
    "jungle": ("jungle", "rainforest", "thickets", "canopy"), "tundra": ("tundra", "barrens", "moors", "fells"),
    "marsh": ("marshes", "fens", "wetlands", "bogs"), "taiga": ("taiga", "pinewoods", "northwoods", "pine forest"),
    "snow": ("snowfields", "icefields", "glaciers", "frozen waste"), "savanna": ("savanna", "bushland", "scrub", "veld"),
    "beach": ("shore", "strand", "sands", "dunes"),
}
COAST_WORDS = ("coast", "shore", "bay", "cape")
RIVER_WORDS = ("valley", "banks", "vale", "river lands")


def is_wild(name):
    """A name of the old scheme (or a placeholder) that the real-place naming replaces."""
    return (not name) or name.startswith("near ") or " lands" in name or name.endswith("countryside")


def compass(dx, dy):
    return COMPASS[int(round(math.atan2(dy, dx) / (math.pi / 4))) % 8]


def _descriptions(prov, river):
    """What a hex is like, most telling first: [word, ...] (a river's name comes with its valley)."""
    words = []
    if river:
        words += [f"{river} {w}" for w in RIVER_WORDS]
    if prov.coastal:
        words += list(COAST_WORDS)
    words += list(LAND_WORDS.get(prov.terrain, (prov.terrain,)))
    return words


def label_groups(groups, taken, provinces, rivers=None):
    """Name the hexes of each group "<base> (<what it is like>)": "(forest)", then with the direction from the
    middle of the group ("north-west woods"), then with inner or outer, and only then with a number.
    groups: {base: [pos]}. Returns {pos: name}; every name is added to taken."""
    rivers = rivers or {}
    out = {}
    for base in sorted(groups):
        members = sorted(groups[base])
        points = {pos: geo.lonlat(pos) for pos in members}
        mx = sum(p[0] for p in points.values()) / len(points)
        my = sum(p[1] for p in points.values()) / len(points)
        dist = {pos: math.hypot((points[pos][0] - mx) * math.cos(math.radians(my)), points[pos][1] - my)
                for pos in members}
        far = sorted(dist.values())[len(members) // 2]
        for pos in members:
            words = _descriptions(provinces[pos], rivers.get(pos))
            way = compass(points[pos][0] - mx, points[pos][1] - my)
            ring = "outer" if dist[pos] > far else "inner"
            turn = (pos[0] * 7 + pos[1] * 13) % 4
            # every word is a variant, starting at a different one per hex
            ordered = words[turn:] + words[:turn] if len(words) > 1 else words
            tries = [f"{base} ({w})" for w in ordered]
            tries += [f"{base} ({way} {w})" for w in ordered]
            tries += [f"{base} ({ring} {way} {w})" for w in ordered]
            name = next((t for t in tries if t not in taken), None)
            n = 2
            while name is None:
                cand = f"{base} ({ring} {way} {ordered[0]} {n})"
                if cand not in taken:
                    name = cand
                n += 1
            taken.add(name)
            out[pos] = name
    return out


def make_unique(provinces):
    """Random worlds: keep the generated names, and describe the hexes of a name that more than one hex has.
    A city keeps its name; the other hexes of the same name are labelled."""
    by_name = {}
    for pos, prov in provinces.items():
        by_name.setdefault(prov.name, []).append(pos)
    taken = {name for name, poss in by_name.items() if len(poss) == 1}
    groups = {}
    for name, poss in by_name.items():
        if len(poss) == 1:
            continue
        cities = sorted(p for p in poss if provinces[p].city)
        if cities:
            taken.add(name)
            rest = [p for p in poss if p != cities[0]]
        else:
            rest = poss
        if rest:
            groups[name] = rest
    for pos, name in label_groups(groups, taken, provinces).items():
        provinces[pos].name = name


# ----- the Europe map -------------------------------------------------------------------------------------------
def _places_by_hex():
    by_hex, order = {}, []
    for line in placenames.PLACES.strip().splitlines():
        lon, lat, name = line.split("|")
        pos = geo.hex_of(float(lon), float(lat))
        if pos not in by_hex:
            by_hex[pos] = []
            order.append(pos)
        by_hex[pos].append(name)
    return by_hex, order


def name_europe(world):
    """Give every province without a real name a region and a place (or a description of the land). Provinces that
    already have a good name (cities, colonies) keep it; their names are taken first, so nothing repeats."""
    provs = world.provinces
    assign_regions(provs, getattr(world, "landmass", None), world.cities)
    used = {p.name for p in provs.values() if p.name and not is_wild(p.name)}
    cities = {v[0] for v in world.cities.values()}
    todo = {pos for pos, p in provs.items() if not p.city and is_wild(p.name)}
    by_hex, order = _places_by_hex()
    for pos in order:
        if pos not in todo:
            continue
        for raw in by_hex[pos]:
            name = EXONYMS.get(raw, raw)
            if raw in SKIP or name in used or name in cities:
                continue
            provs[pos].name = name
            used.add(name)
            todo.discard(pos)
            break
    groups = {}
    for pos in todo:
        groups.setdefault(provs[pos].region or "Wilderness", []).append(pos)
    for pos, name in label_groups(groups, used, provs, getattr(world, "river_at", None)).items():
        provs[pos].name = name


def place(prov):
    """The name with the region where that helps: "Braga (Minho)". Messages use this."""
    region = prov.region
    if not region or prov.name == region or prov.name.startswith(region + " (") or region.endswith(" lands"):
        return prov.name
    return f"{prov.name} ({region})"


def colony_name(world, prov):
    """The name a native province takes when it is settled: "New Lucayan" (and "New Lucayan 2" if that is taken)."""
    base = "New " + (prov.region.removesuffix(" lands") if prov.region else prov.tribe)
    taken = {p.name for p in world.provinces.values()}
    name, n = base, 1
    while name in taken:
        n += 1
        name = f"{base} {n}"
    return name
