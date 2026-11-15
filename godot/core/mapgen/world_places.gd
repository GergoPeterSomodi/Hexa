## The settlements of the map prototype region (docs/design/map/03-settlements-and-roads.md sections 3, 5, 6 and 7): the
## authored places snapped to their hexes (the river cities keep their pinned hex, 04 section 3.6), levels 0 to 5 with the
## capital and the castles, a hospice on the saddle of each pass with a crest and at least 2000 metres, the standalone
## castle and the monastery, the ports with their quays, and the generated villages (the farmland budget, by site score and spacing).
## Pure: it reads the relief, the water and the cover; no files, no engine calls.
##
## Levels (03 section 5): 0 none, 1 hamlet, 2 village, 3 town, 4 city, 5 great city. Settlements are one per hex; a hex may
## also carry a landmark (hospice, monastery). Generated places are only villages (2): at the region zoom hamlets are not places
## (they become decoration later). Authored towns that crowd a bigger place are demoted or dropped (_demote_crowded).
class_name WorldPlaces
extends RefCounted

## A generated place is at least this many hexes from every settlement (03 section 6, spacing).
const SPACING := 2
## A generated village needs this site score (kept SPACING hexes from every settlement). Its pool is the farmland and grassland
## hexes of the plain and the hills (levels 1 to VILLAGE_MAX_LEVEL): one village for every VILLAGE_EVERY hexes of that pool,
## the best sites first (the owner's review, 2026-11-14: 6 to 8 land hexes per village, no more).
const VILLAGE_SCORE := 3.0
const VILLAGE_EVERY := 7
const VILLAGE_MAX_LEVEL := 3
## Passes with a crest saddle at or above this height (metres) carry a hospice.
const HOSPICE_MIN_METRES := 2000
## Authored settlement level by the region's kind (city, town, castle_town), and by name where the size says otherwise.
## Sizes come from godot/data/geography/cities.json (level from size, 03 section 5): Milan 100, Florence 70, Genoa 60,
## Bologna 40, Turin 15, Bern 5. Milan is the great city and the capital of the Duchy of Milan.
const LEVEL_BY_KIND := {"city": 4, "town": 3, "castle_town": 3}
const LEVEL_OVERRIDE := {"Milan": 5, "Venice": 5, "Turin": 3, "Bern": 2}
## Castle levels (0 to 3) of authored places (03 section 5: castles with towns and at chokepoints).
const CASTLE_OVERRIDE := {"Milan": 3, "Turin": 2, "Genoa": 2, "Pavia": 2, "Bellinzona": 3}
const CAPITAL := "Milan"
## A castle named in the region's places but not a town (the Bard fort) stands alone at level 1.
const STANDALONE_CASTLE := 1
const NO_HEX := Vector2i(-1, -1)
## A pass whose relief saddle is taken by a nearer pass gets the nearest free crest hex within this many hex widths.
const SADDLE_REACH_HEXES := 1.5
## A lake port needs its town within this many hex widths of a lake's axis (the water step's lake ribbons can run past
## the lake itself, so a lake edge alone does not make a port).
const LAKE_REACH_HEXES := 0.5

## Each place: name (String, "" for generated), hex, level, capital, castle, port, generated, river_city (bool).
var places: Array[Dictionary] = []
## Each landmark: kind ("hospice" or "monastery"), name, hex, and for a hospice the pass index.
var landmarks: Array[Dictionary] = []
## Quay of each port: the shore or lake edge the port's quay stands on, to its hex.
var quay_edges: Dictionary[Vector4i, Vector2i] = {}
## Site score of every land hex (03 section 6), before any place is put down.
var site_score: Dictionary[Vector2i, float] = {}
## Authored places that could not be snapped to a land hex (none expected).
var failures: Array[String] = []
## Authored places moved off their true hex, for the report: "Name (c, r) -> (c, r)".
var snapped: Array[String] = []
var grid: HexGrid
var _relief: WorldRelief
var _water: WorldWater
var _cover: WorldCover
var _index: Dictionary[Vector2i, int] = {}  # hex -> index in places (settlements, castles and river cities)
var _reserved: Dictionary[Vector2i, bool] = {}  # the pinned hexes of the river cities, before their places are added
var _landmark_hexes: Dictionary[Vector2i, bool] = {}
var _saddles: Dictionary[Vector2i, bool] = {}  # saddle hexes of the passes with a crest
## The saddle hex of each pass with a crest (pass index to hex), resolved so that no two passes share one.
var pass_saddles: Dictionary[int, Vector2i] = {}
## The crest edges of each resolved saddle (edge to pass index): the open pass edges that roads may cross.
var pass_edges: Dictionary[Vector4i, int] = {}
var _region: WorldRegion
## The farmland and grassland hexes that the village budget counts, and the villages the budget allows.
var village_pool := 0
var village_budget := 0
## Authored towns demoted to villages (their names stay on the map) and authored places dropped for crowding a bigger place.
var demoted: Array[String] = []
var dropped: Array[String] = []


## The places of the region: authored places first (river cities pinned), then hospices, then generated places.
static func build(p_grid: HexGrid, p_relief: WorldRelief, p_water: WorldWater, p_cover: WorldCover,
		region: WorldRegion) -> WorldPlaces:
	var out := WorldPlaces.new()
	out.grid = p_grid
	out._relief = p_relief
	out._water = p_water
	out._cover = p_cover
	out._region = region
	out._adopt_saddles()
	out._score_all()
	out._reserve_river_cities()
	out._place_authored(region)
	out._demote_crowded()
	out._place_hospices(region)
	out._place_generated()
	out._find_ports()
	return out


## The settlement level of a hex (0 when there is none; a standalone castle is level 0).
func level_at(hex: Vector2i) -> int:
	if not _index.has(hex):
		return 0
	return int(places[_index[hex]]["level"])


## The place on a hex (settlement, castle or river city), or an empty dictionary.
func place_at(hex: Vector2i) -> Dictionary:
	if not _index.has(hex):
		return {}
	return places[_index[hex]]


## The place with this name, or an empty dictionary.
func find(place_name: String) -> Dictionary:
	for pl: Dictionary in places:
		if pl["name"] == place_name:
			return pl
	return {}


## True when a settlement (level 1 or more) lies less than radius hexes from the hex: the spacing test of the generator.
func settled_within(hex: Vector2i, radius: int) -> bool:
	for pl: Dictionary in places:
		if int(pl["level"]) < 1:
			continue
		if hex_distance(hex, pl["hex"]) < radius:
			return true
	return false


## Hex distance on the odd-row grid (odd rows shifted right, as HexGrid): the number of steps between two hexes.
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var qa := a.x - ((a.y - (a.y & 1)) >> 1)
	var qb := b.x - ((b.y - (b.y & 1)) >> 1)
	var dq := qa - qb
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) >> 1


## Counts for the report and the tests: places per level, castles, capitals, ports, quays, landmarks, generated places.
func summary() -> Dictionary:
	var levels: Array[int] = [0, 0, 0, 0, 0, 0]
	var castles := 0
	var capitals := 0
	var ports := 0
	var generated := 0
	var river_cities := 0
	for pl: Dictionary in places:
		levels[int(pl["level"])] += 1
		castles += int(pl["castle"] > 0)
		capitals += int(pl["capital"])
		ports += int(pl["port"])
		generated += int(pl["generated"])
		river_cities += int(pl["river_city"])
	var hospices := 0
	var monasteries := 0
	for lm: Dictionary in landmarks:
		hospices += int(lm["kind"] == "hospice")
		monasteries += int(lm["kind"] == "monastery")
	return {
		"places": places.size(),
		"levels": levels,
		"generated": generated,
		"castles": castles,
		"capitals": capitals,
		"ports": ports,
		"quays": quay_edges.size(),
		"river_cities": river_cities,
		"hospices": hospices,
		"monasteries": monasteries,
		"failures": failures.size(),
		"demoted": demoted.size(),
		"dropped": dropped.size(),
		"village_pool": village_pool,
		"village_budget": village_budget,
	}


# ----- the site score (03 section 6) -------------------------------------------------------------------------------


## The saddles and the pass edges come from the relief (world_relief: one saddle per pass with a crest, no two passes share one;
## a second pass takes the nearest free crest hex of its range). The crest edges of each saddle are open for roads.
func _adopt_saddles() -> void:
	for p: int in _relief.pass_saddles.keys():
		var s: Vector2i = _relief.pass_saddles[p]
		pass_saddles[p] = s
		_saddles[s] = true
	for e: Vector4i in _relief.pass_edges.keys():
		pass_edges[e] = int(_relief.pass_edges[e])
	failures.append_array(_relief.saddle_failures)


func _score_all() -> void:
	for hex: Vector2i in _relief.levels.keys():
		if _is_land(hex):
			site_score[hex] = _score(hex)


func _score(hex: Vector2i) -> float:
	var s := 0.0
	var level := _relief.level_at(hex)
	var river := false
	var lake := false
	var sea_sides := 0
	var higher := false
	var ridge := false
	var pass_foot := false
	for d: int in 6:
		var nb := grid.neighbour(hex, d)
		var e := HexGrid.edge_key(hex, nb)
		if _water.river_edge.has(e) or _water.stream_edge.has(e):
			river = true
		if _water.lake_edge.has(e) or _water.lake_hex.has(nb):
			lake = true
		if _relief.level_at(nb) == ReliefLevels.SEA and not _water.lake_hex.has(nb):
			sea_sides += 1
		if _relief.level_at(nb) > level and level > ReliefLevels.SEA:
			higher = true
		if _relief.crest_edges.has(e) and not pass_edges.has(e):
			ridge = true
		if _saddles.has(nb):
			pass_foot = true
	if river:
		s += 3.0  # a crossing saves a detour
	if lake:
		s += 2.0  # a lake shore harbour
	if sea_sides >= 2:
		s += 4.0  # a bay: sea on two or more sides
	if river and higher and level <= 2:
		s += 3.0  # a valley mouth opens on the plain
	if pass_foot:
		s += 3.0  # the last flat hex before a pass
	for k: int in 6:
		var corner := _water._hex_corner(hex, k)
		if corner != WorldWater.NO_CORNER and str(_water.corner_word.get(corner, "")) == "join":
			s += 4.0  # a confluence
			break
	var c := _cover.cover_at(hex)
	if level <= 2 and (c == WorldCover.FARMLAND or c == WorldCover.GRASSLAND):
		s += 1.0  # arable plain
	if c == WorldCover.MARSH:
		s -= 3.0
	if level == 6:
		s -= 6.0  # high peaks
	if ridge:
		s -= 2.0
	return s


# ----- authored and generated places ----------------------------------------------------------------------------------


## A river city keeps the hex its river is routed through (04 section 3.6): it is reserved so no other place snaps onto it.
func _reserve_river_cities() -> void:
	for city: String in _water.city_hex.keys():
		_reserved[_water.city_hex[city]] = true


func _place_authored(region: WorldRegion) -> void:
	for raw: Dictionary in region.places:
		var pname: String = raw["name"]
		var kind: String = raw["kind"]
		var pos: Vector2 = raw["pos"]
		var at := grid.hex_of(pos.x, pos.y)
		if kind == "hospice":
			continue  # the pass rule places every hospice on its saddle (_place_hospices)
		if kind == "landmark":
			var lm_hex := _snap(at, pname)
			if lm_hex != NO_HEX:
				landmarks.append({"kind": "monastery", "name": pname, "hex": lm_hex})
				_landmark_hexes[lm_hex] = true
			continue
		if kind == "castle":
			var castle_hex := _snap(at, pname)
			if castle_hex != NO_HEX:
				_add(pname, castle_hex, 0, false, STANDALONE_CASTLE, false, false)
			continue
		var level := int(LEVEL_OVERRIDE.get(pname, LEVEL_BY_KIND.get(kind, 3)))
		var castle := int(CASTLE_OVERRIDE.get(pname, 0))
		var river_city := _water.city_hex.has(pname)
		var hex := NO_HEX
		if river_city:
			hex = _water.city_hex[pname]
		else:
			hex = _snap(at, pname)
		if hex == NO_HEX:
			continue
		_add(pname, hex, level, pname == CAPITAL, castle, river_city, false)


## A hospice on the saddle hex of every pass with a crest saddle at or above HOSPICE_MIN_METRES.
func _place_hospices(region: WorldRegion) -> void:
	for p: int in pass_saddles.keys():
		var ps: Dictionary = region.passes[p]
		if int(ps["metres"]) < HOSPICE_MIN_METRES:
			continue
		var saddle: Vector2i = pass_saddles[p]
		landmarks.append({"kind": "hospice", "name": "Hospice " + str(ps["name"]), "hex": saddle, "pass": p})
		_landmark_hexes[saddle] = true


## Villages: the farmland and grassland hexes of the plain and the hills are the pool, and one village is put down for every
## VILLAGE_EVERY of them, best site score first, each kept SPACING hexes from every settlement. No hamlets: at the region zoom
## they are decoration, not places.
func _place_generated() -> void:
	var cands: Array[Vector2i] = []
	village_pool = 0
	for hex: Vector2i in site_score.keys():
		if not _farmland_or_grass(hex):
			continue
		village_pool += 1
		if _index.has(hex) or _landmark_hexes.has(hex):
			continue
		if site_score[hex] >= VILLAGE_SCORE:
			cands.append(hex)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var sa: float = site_score[a]
		var sb: float = site_score[b]
		if sa != sb:
			return sa > sb
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	village_budget = floori(float(village_pool) / float(VILLAGE_EVERY))
	var villages := 0
	for hex: Vector2i in cands:
		if villages >= village_budget:
			break
		if settled_within(hex, SPACING):
			continue
		_add("", hex, 2, false, 0, false, true)
		villages += 1


## True for a land hex of the plain or the hills (levels 1 to VILLAGE_MAX_LEVEL) with farmland or grassland on it.
func _farmland_or_grass(hex: Vector2i) -> bool:
	if not _is_land(hex) or _relief.level_at(hex) > VILLAGE_MAX_LEVEL:
		return false
	var c := _cover.cover_at(hex)
	return c == WorldCover.FARMLAND or c == WorldCover.GRASSLAND


## Authored towns that crowd a bigger place (03 section 5, the owner's review of 2026-11-14): a town (level 3) within one hex of a
## bigger place becomes a village (its name stays on the map, smaller); a village within one hex of a bigger place is dropped.
## Both are judged on the levels before any change. River cities and castles are never demoted or dropped.
func _demote_crowded() -> void:
	var to_demote: Array[Dictionary] = []
	var to_drop: Dictionary[Vector2i, bool] = {}
	for pl: Dictionary in places:
		if bool(pl["generated"]) or bool(pl["river_city"]):
			continue
		var level := int(pl["level"])
		if level < 2 or level > 3:
			continue
		var hex: Vector2i = pl["hex"]
		var bigger := false
		for other: Dictionary in places:
			var oh: Vector2i = other["hex"]
			if oh != hex and int(other["level"]) > level and hex_distance(hex, oh) <= 1:
				bigger = true
				break
		if not bigger:
			continue
		if level == 3:
			to_demote.append(pl)
		else:
			to_drop[hex] = true
	for pl: Dictionary in to_demote:
		pl["level"] = 2
		demoted.append(str(pl["name"]))
	if to_drop.is_empty():
		return
	var kept: Array[Dictionary] = []
	for pl: Dictionary in places:
		var hex: Vector2i = pl["hex"]
		if to_drop.has(hex):
			dropped.append(str(pl["name"]))
		else:
			kept.append(pl)
	places = kept
	_index.clear()
	for i: int in places.size():
		var ih: Vector2i = places[i]["hex"]
		_index[ih] = i


## Snaps an authored place to the best land hex within one hex of its true position (03 section 6). The true hex is kept on
## a tie; a hex already holding a place, or a landmark, is not taken.
func _snap(at: Vector2i, pname: String) -> Vector2i:
	var best := NO_HEX
	var best_score := -INF
	var options: Array[Vector2i] = [at]
	for nb: Vector2i in grid.neighbours(at):
		options.append(nb)
	for hex: Vector2i in options:
		if not site_score.has(hex) or _index.has(hex) or _reserved.has(hex) or _landmark_hexes.has(hex):
			continue
		var s: float = site_score[hex]
		if s > best_score:
			best_score = s
			best = hex
	if best == NO_HEX:
		failures.append("%s: no free land hex within one hex of its place" % pname)
	elif best != at:
		snapped.append("%s (%d, %d) -> (%d, %d)" % [pname, at.x, at.y, best.x, best.y])
	return best


func _add(pname: String, hex: Vector2i, level: int, capital: bool, castle: int, river_city: bool,
		generated: bool) -> void:
	_index[hex] = places.size()
	places.append({
		"name": pname,
		"hex": hex,
		"level": level,
		"capital": capital,
		"castle": castle,
		"port": false,
		"sea": false,
		"generated": generated,
		"river_city": river_city,
	})


## True when the hex lies within LAKE_REACH_HEXES hex widths of the axis of one of the region's lakes.
func _beside_lake(hex: Vector2i) -> bool:
	var c := grid.centre_km(hex)
	for lk: Dictionary in _region.lakes:
		var axis: PackedVector2Array = lk["axis"]
		for i: int in axis.size() - 1:
			var a := grid.km_of(axis[i].x, axis[i].y)
			var b := grid.km_of(axis[i + 1].x, axis[i + 1].y)
			if _segment_distance(c, a, b) <= LAKE_REACH_HEXES * grid.hex_w_km:
				return true
	return false


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	var t := 0.0 if len2 == 0.0 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _is_land(hex: Vector2i) -> bool:
	return _relief.level_at(hex) != ReliefLevels.SEA and not _water.lake_hex.has(hex)


## A port is a settlement with a sea edge (the first one is its quay) or, at level 2 and up, a lake edge.
func _find_ports() -> void:
	for i: int in places.size():
		var pl: Dictionary = places[i]
		var level := int(pl["level"])
		if level < 1:
			continue
		var hex: Vector2i = pl["hex"]
		var quay_set := false
		var sea_port := false
		for d: int in 6:
			var nb := grid.neighbour(hex, d)
			var e := HexGrid.edge_key(hex, nb)
			if not quay_set and _relief.level_at(nb) == ReliefLevels.SEA and not _water.lake_hex.has(nb) \
					and _water.shore_edge.has(e):
				quay_edges[e] = hex
				quay_set = true
				sea_port = true
			elif not quay_set and level >= 2 and _water.lake_edge.has(e) and _beside_lake(hex):
				quay_edges[e] = hex
				quay_set = true
		pl["port"] = quay_set
		pl["sea"] = sea_port
