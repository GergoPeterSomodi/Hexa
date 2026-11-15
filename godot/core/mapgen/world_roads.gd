## The roads of the map prototype region (docs/design/map/03-settlements-and-roads.md section 8; 04-wfc-model.md section 3.1):
## the link graph (the capital to the cities of its reach, each city to its nearest cities, every fixed place of level 2 and
## up to the network, each pass to a settlement on each side, the ports along the coast), routed by the cheapest path on the
## relief and water cost field. Then the sparse rules of the owner's review (2026-11-14): a link that runs parallel to a road
## already kept (within one hex for more than PARALLEL_RUN hexes in a row) is dropped, and a village that no road reaches gets
## a track (the only villages with tracks). Each road edge gets a quality 0 to 3 (3 only on the capital's links) and, where
## it crosses a river, a stream, a lake or a pass, a crossing kind (ford, bridge_wood, bridge_stone, ferry, pass).
##
## Routing: valley floors are cheap, crests are closed except at the pass edges, sea and lakes are closed, a river or a
## stream costs more to cross unless a settlement can bridge it, and an edge that already carries a road is nearly free
## (so trunks form). A road runs from hex centre to hex centre and crosses an edge at its middle. Pure: no files, no engine.
class_name WorldRoads
extends RefCounted

const NO_EDGE := Vector4i(-1, -1, -1, -1)
const CROSSING_KINDS: Array[String] = ["none", "ford", "bridge_wood", "bridge_stone", "ferry", "pass"]
## Step costs of entering a hex (03 section 8 table; starting values, tuned later by the systems designer).
const PLAIN_COST := 1.0
const HILLS_COST := 1.8
const HIGHLAND_COST := 2.6
const MOUNTAIN_COST := 3.6
const PEAK_COST := 8.0
const VALLEY_COST := 1.6
const SADDLE_COST := 3.0
## Entering an edge that already carries a road is multiplied by this (routes share roads).
const REUSE_FACTOR := 0.35
const STREAM_COST := 0.4
const LAKE_FERRY_COST := 4.0
const MINOR_RIVER_COST := 0.6
const RIVER_BESIDE_COST := 0.6  # a class 2 river beside a settlement of level 2 or more
const RIVER_OPEN_COST := 2.0
const GREAT_BESIDE_COST := 1.0  # the Po beside a town (level 3 or more)
const GREAT_OPEN_COST := 4.0
## An edge used by this many links is one step better (03 section 8, quality).
const TRAFFIC_UP := 4
## The capital links to every city (level 4 or more) within this many hexes.
const CAPITAL_RANGE := 16
const RANK_CAPITAL := 3
## A main road (quality 2): the city links, joins between towns of level 3+, the coast links and the links over a pass with
## a hospice. Only the spurs to cut-off villages, and joins of smaller places, stay tracks (quality 1).
const RANK_CITY := 2
const RANK_OTHER := 1
## Quality caps: the mountains (levels 5 and 6) take at most a road of quality 2; a pass is a track in 1480.
const MOUNTAIN_CAP := 2
const PASS_QUALITY := 1
## A link is parallel to a kept road when more than this many of its hexes in a row lie within one hex of that road (and off it).
const PARALLEL_RUN := 2
## A pass carries at most this many branches (one per side of the crest; owner's review, 2026-11-14).
const PASS_SIDES := 2

## Road edges: quality 1 to 3 (after _finish). Edges without a road are absent.
var quality: Dictionary[Vector4i, int] = {}
## Road edges: the crossing kind (none, ford, bridge_wood, bridge_stone, ferry or pass).
var crossing: Dictionary[Vector4i, String] = {}
## Hexes that carry at least one road edge.
var network: Dictionary[Vector2i, bool] = {}
## Each link: kind (capital, city, join, spur, pass, coast), from, to (hexes), rank, path (Array[Vector2i]), via (pass name).
var links: Array[Dictionary] = []
## Links that could not be routed (none expected: the checks in the tests fail on any).
var link_failures: Array[String] = []
var grid: HexGrid
var relief: WorldRelief
var water: WorldWater
var places: WorldPlaces
var region: WorldRegion
var _rank: Dictionary[Vector4i, int] = {}  # edge -> the highest rank of the links that use it
var _traffic: Dictionary[Vector4i, int] = {}  # edge -> the number of links that use it
var _saddles: Dictionary[Vector2i, int] = {}  # saddle hex -> pass index (passes with a crest)
var _city_edge: Dictionary[Vector4i, bool] = {}  # the six edges of each river city's hex
var _valley: Dictionary[Vector2i, bool] = {}  # hexes of level 3 to 5 beside a river or stream: the valley floor
var _pairs: Dictionary[String, bool] = {}  # city pairs already linked
var pruned_links := 0  # links dropped as parallel to a kept road (the owner's rule)
var rejoined := 0  # towns joined again to the network after the prune


## The roads of the region, from the relief, the water and the places.
static func build(p_grid: HexGrid, p_relief: WorldRelief, p_water: WorldWater, p_places: WorldPlaces,
		p_region: WorldRegion) -> WorldRoads:
	var out := WorldRoads.new()
	out.grid = p_grid
	out.relief = p_relief
	out.water = p_water
	out.places = p_places
	out.region = p_region
	out._prepare()
	out._link_capital()
	out._link_city_pairs()
	out._link_fixed_places()
	out._link_passes()
	out._link_ports()
	out._prune_parallel()
	out._link_villages()
	out._finish()
	out._cross_all()
	return out


## The quality of a road edge (0 when it carries no road).
func quality_of(e: Vector4i) -> int:
	return int(quality.get(e, 0))


## The crossing kind of a road edge ("none" for a road that meets no water or pass, and for an edge without a road).
func crossing_of(e: Vector4i) -> String:
	return str(crossing.get(e, "none"))


## The number of road edges on the pass with this index (its pass edges that carry a road).
func road_edges_of_pass(p: int) -> int:
	var n := 0
	for e: Vector4i in pass_branch_edges(p):
		if quality.has(e):
			n += 1
	return n


## The open crest edges beside the saddle of pass p: the branches a road over that pass may leave by. A saddle shared with
## another pass (or an edge shared by two saddles) keeps all its open edges for both.
func pass_branch_edges(p: int) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	if not places.pass_saddles.has(p):
		return out
	var saddle: Vector2i = places.pass_saddles[p]
	for d: int in 6:
		var e := HexGrid.edge_key(saddle, grid.neighbour(saddle, d))
		if relief.crest_edges.has(e):
			out.append(e)
	return out


## Road edges that lie on a crest without being a pass edge (must be none).
func crest_violations() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	for e: Vector4i in quality.keys():
		if relief.crest_edges.has(e) and not places.pass_edges.has(e):
			out.append(e)
	return out


## Crossings that do not fit their edge (must be none): a crossing on a dry edge, a river or stream edge with a road and no
## crossing, and any crossing on the six edges of a river city.
func crossing_violations() -> Array[String]:
	var out: Array[String] = []
	for e: Vector4i in quality.keys():
		var kind := crossing_of(e)
		var wet := water.river_edge.has(e) or _is_stream(e) or water.lake_edge.has(e) or places.pass_edges.has(e)
		if kind != "none" and not wet:
			out.append("%s: crossing %s on a dry edge" % [str(e), kind])
		if wet and kind == "none":
			out.append("%s: a road over water or a pass with no crossing" % str(e))
	for city: String in water.city_hex.keys():
		var hex: Vector2i = water.city_hex[city]
		for d: int in 6:
			var e := HexGrid.edge_key(hex, grid.neighbour(hex, d))
			if quality.has(e) and crossing_of(e) != "none":
				out.append("%s: a crossing on an edge of the river city %s" % [str(e), city])
	return out


## Counts for the report and the tests.
func summary() -> Dictionary:
	var qualities: Array[int] = [0, 0, 0, 0]
	var kinds: Dictionary[String, int] = {}
	for e: Vector4i in quality.keys():
		qualities[quality[e]] += 1
		var kind := crossing_of(e)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	var by_link: Dictionary[String, int] = {}
	for ln: Dictionary in links:
		var lk := str(ln["kind"])
		by_link[lk] = int(by_link.get(lk, 0)) + 1
	return {
		"edges": quality.size(),
		"qualities": qualities,
		"crossings": kinds,
		"links": links.size(),
		"links_by_kind": by_link,
		"link_failures": link_failures.size(),
		"network_hexes": network.size(),
		"pruned_links": pruned_links,
		"rejoined": rejoined,
	}


# ----- the cost field -----------------------------------------------------------------------------------------------------


func _prepare() -> void:
	for p: int in places.pass_saddles.keys():
		_saddles[places.pass_saddles[p]] = p
	for city: String in water.city_hex.keys():
		var city_hex: Vector2i = water.city_hex[city]
		for d: int in 6:
			_city_edge[HexGrid.edge_key(city_hex, grid.neighbour(city_hex, d))] = true
	for h: Vector2i in relief.levels.keys():
		var level := relief.level_at(h)
		if level < 3 or level > 5:
			continue
		for d: int in 6:
			var e := HexGrid.edge_key(h, grid.neighbour(h, d))
			if water.river_edge.has(e) or water.stream_edge.has(e):
				_valley[h] = true
				break


## A generated stream on an edge of a river city is not drawn as a crossing: the city's bridge is inside its hex (04 3.6).
func _is_stream(e: Vector4i) -> bool:
	return water.stream_edge.has(e) and not _city_edge.has(e)


func _is_land(h: Vector2i) -> bool:
	return relief.level_at(h) != ReliefLevels.SEA and not water.lake_hex.has(h)


func _enter_cost(h: Vector2i) -> float:
	if _saddles.has(h):
		return SADDLE_COST
	if _valley.has(h):
		return VALLEY_COST
	match relief.level_at(h):
		1, 2:
			return PLAIN_COST
		3:
			return HILLS_COST
		4:
			return HIGHLAND_COST
		5:
			return MOUNTAIN_COST
		_:
			return PEAK_COST


## The extra cost of crossing a river edge: the class of its river and whether a settlement can bridge it.
func _river_cost(e: Vector4i) -> float:
	var idx := int(water.river_edge[e])
	var klass := int(water.rivers[idx]["class"])
	var pair := HexGrid.edge_hexes(e)
	if klass >= 3:
		return GREAT_BESIDE_COST if _beside(pair, 3) else GREAT_OPEN_COST
	if klass == 2:
		return RIVER_BESIDE_COST if _beside(pair, 2) else RIVER_OPEN_COST
	return MINOR_RIVER_COST


## True when a settlement of at least min_level stands on one of the two hexes of an edge or beside them.
func _beside(pair: Array[Vector2i], min_level: int) -> bool:
	for h: Vector2i in pair:
		if places.level_at(h) >= min_level:
			return true
		for nb: Vector2i in grid.neighbours(h):
			if places.level_at(nb) >= min_level:
				return true
	return false


## The cost of stepping from a to its neighbour b across edge e, or -1 when the step is closed.
func _step_cost(a: Vector2i, b: Vector2i, e: Vector4i) -> float:
	if not _is_land(a) or not _is_land(b):
		return -1.0
	if relief.crest_edges.has(e) and not places.pass_edges.has(e):
		return -1.0
	if water.shore_edge.has(e):
		return -1.0
	var c := _enter_cost(b)
	if _rank.has(e):
		c *= REUSE_FACTOR
	if water.river_edge.has(e):
		c += _river_cost(e)
	elif water.stream_edge.has(e) and not _city_edge.has(e):
		c += STREAM_COST
	if water.lake_edge.has(e):
		c += LAKE_FERRY_COST
	return c


# ----- routing ----------------------------------------------------------------------------------------------------------------


## The cheapest path from one of the starts to a goal hex (both included), or an empty array. first_edge, when not NO_EDGE,
## is the only edge the first start may leave by (a pass branch). hop_limit, when above 0, stops the search after that many
## steps.
func _search(starts: Array[Vector2i], goals: Dictionary[Vector2i, bool], first_edge: Vector4i,
		hop_limit: int) -> Array[Vector2i]:
	var dist: Dictionary[Vector2i, float] = {}
	var prev: Dictionary[Vector2i, Vector2i] = {}
	var hops: Dictionary[Vector2i, int] = {}
	var heap: Array[Array] = []
	for s: Vector2i in starts:
		dist[s] = 0.0
		hops[s] = 0
		_push(heap, 0.0, s)
	while not heap.is_empty():
		var top: Array = _pop(heap)
		var c: float = top[0]
		var h: Vector2i = top[1]
		if c > float(dist[h]):
			continue
		if goals.has(h):
			return _path_to(prev, h)
		if hop_limit > 0 and int(hops[h]) >= hop_limit:
			continue
		for d: int in 6:
			var nb := grid.neighbour(h, d)
			var e := HexGrid.edge_key(h, nb)
			if first_edge != NO_EDGE and h == starts[0] and e != first_edge:
				continue
			var step := _step_cost(h, nb, e)
			if step < 0.0:
				continue
			var nc := c + step
			if nc < float(dist.get(nb, INF)):
				dist[nb] = nc
				prev[nb] = h
				hops[nb] = int(hops[h]) + 1
				_push(heap, nc, nb)
	return []


static func _path_to(prev: Dictionary[Vector2i, Vector2i], end: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [end]
	var cur := end
	while prev.has(cur):
		cur = prev[cur]
		out.push_front(cur)
	return out


## Routes a link from one hex to another and records it.
func _connect(a: Vector2i, b: Vector2i, rank: int, kind: String) -> void:
	var goals: Dictionary[Vector2i, bool] = {b: true}
	var path := _search([a], goals, NO_EDGE, 0)
	if path.is_empty():
		link_failures.append("%s: %s to %s has no route" % [kind, str(a), str(b)])
		return
	_add_path(path, rank, kind, "")


func _add_path(path: Array[Vector2i], rank: int, kind: String, via: String) -> void:
	if path.size() < 2:
		return
	links.append({"kind": kind, "from": path[0], "to": path[path.size() - 1], "rank": rank, "path": path, "via": via})
	for i: int in path.size() - 1:
		var e := HexGrid.edge_key(path[i], path[i + 1])
		_rank[e] = maxi(int(_rank.get(e, 0)), rank)
		_traffic[e] = int(_traffic.get(e, 0)) + 1
		network[path[i]] = true
		network[path[i + 1]] = true


func _network_goals() -> Dictionary[Vector2i, bool]:
	var goals: Dictionary[Vector2i, bool] = {}
	for h: Vector2i in network.keys():
		goals[h] = true
	return goals


## The goals of a join (rule 3): the towns and cities already on the network (a town joins a town or a city).
func _town_goals() -> Dictionary[Vector2i, bool]:
	var goals: Dictionary[Vector2i, bool] = {}
	for pl: Dictionary in places.places:
		var hex: Vector2i = pl["hex"]
		if int(pl["level"]) >= 3 and network.has(hex):
			goals[hex] = true
	return goals


func _network_distance(h: Vector2i) -> int:
	var best := 1 << 30
	for n: Vector2i in network.keys():
		best = mini(best, WorldPlaces.hex_distance(h, n))
	return best


# ----- the link graph (03 section 8, rules 1 to 6) ----------------------------------------------------------------------


## Rule 1: the capital to every city (level 4 or more) within CAPITAL_RANGE hexes.
func _link_capital() -> void:
	var capital: Dictionary = places.find(WorldPlaces.CAPITAL)
	if capital.is_empty():
		link_failures.append("no capital")
		return
	var cap_hex: Vector2i = capital["hex"]
	network[cap_hex] = true
	for pl: Dictionary in places.places:
		if int(pl["level"]) < 4 or pl["name"] == WorldPlaces.CAPITAL:
			continue
		var hex: Vector2i = pl["hex"]
		if WorldPlaces.hex_distance(cap_hex, hex) > CAPITAL_RANGE:
			continue
		_pairs[_pair_key(WorldPlaces.CAPITAL, str(pl["name"]))] = true
		_connect(cap_hex, hex, RANK_CAPITAL, "capital")


## Rule 2: each city (level 4 or more) to its nearest two other cities.
func _link_city_pairs() -> void:
	var cities: Array[Dictionary] = []
	for pl: Dictionary in places.places:
		if int(pl["level"]) >= 4:
			cities.append(pl)
	for a: Dictionary in cities:
		var others: Array[Dictionary] = []
		for b: Dictionary in cities:
			if b["name"] != a["name"]:
				others.append(b)
		var ah: Vector2i = a["hex"]
		others.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
			var ph: Vector2i = p["hex"]
			var qh: Vector2i = q["hex"]
			return WorldPlaces.hex_distance(ah, ph) < WorldPlaces.hex_distance(ah, qh))
		for i: int in mini(2, others.size()):
			var b: Dictionary = others[i]
			var key := _pair_key(str(a["name"]), str(b["name"]))
			if _pairs.has(key):
				continue
			_pairs[key] = true
			_connect(ah, b["hex"], RANK_CITY, "city")


## Rule 3: every fixed place of level 2 or more to the network, nearest first (a minimum spanning tree).
func _link_fixed_places() -> void:
	if network.is_empty():
		return
	var todo: Array[Dictionary] = []
	for pl: Dictionary in places.places:
		if bool(pl["generated"]) or int(pl["level"]) < 2:
			continue
		var hex: Vector2i = pl["hex"]
		if not network.has(hex):
			todo.append(pl)
	while not todo.is_empty():
		var best_i := 0
		var best_d := 1 << 30
		for i: int in todo.size():
			var hex: Vector2i = todo[i]["hex"]
			var d := _network_distance(hex)
			if d < best_d:
				best_d = d
				best_i = i
		var pl: Dictionary = todo[best_i]
		todo.remove_at(best_i)
		var at: Vector2i = pl["hex"]
		if network.has(at):
			continue
		_join_place(pl)


## One fixed place to the network: a town joins a town or a city (the nearest), else the nearest road. A join between two
## towns of level 3 or more is a road; any other join is a track.
func _join_place(pl: Dictionary) -> void:
	var at: Vector2i = pl["hex"]
	var path := _search([at], _town_goals(), NO_EDGE, 0)
	if path.is_empty():
		path = _search([at], _network_goals(), NO_EDGE, 0)
	if path.is_empty():
		link_failures.append("join: %s has no route to the network" % str(pl["name"]))
		return
	var target: Vector2i = path[path.size() - 1]
	var rank := RANK_CITY if (int(pl["level"]) >= 3 and places.level_at(target) >= 3) else RANK_OTHER
	_add_path(path, rank, "join", "")


## Rule 4 (thinned, owner's review 2026-11-14): a village that no road reaches gets a track to the nearest road, however far;
## a village on a road needs nothing. Hamlets are not places at this zoom.
func _link_villages() -> void:
	for pl: Dictionary in places.places:
		if not bool(pl["generated"]):
			continue
		var at: Vector2i = pl["hex"]
		if network.has(at):
			continue
		var path := _search([at], _network_goals(), NO_EDGE, 0)
		if path.size() >= 2:
			_add_path(path, RANK_OTHER, "spur", "")


## Rule 5 (thinned, owner's review 2026-11-14): every pass with a crest saddle joins a settlement on each side. From the saddle,
## a branch is routed through each open pass edge that no road uses yet, to the nearest settlement of level 2 or more or to a road
## already laid. Of the branches, at most PASS_SIDES are kept: the shortest, then the shortest whose first hex is not beside the
## first (the other side of the pass). The rest would only run beside a kept branch.
func _link_passes() -> void:
	for p: int in places.pass_saddles.keys():
		var saddle: Vector2i = places.pass_saddles[p]
		var pass_name: String = region.passes[p]["name"]
		var goals: Dictionary[Vector2i, bool] = {}
		for pl: Dictionary in places.places:
			var hex: Vector2i = pl["hex"]
			if int(pl["level"]) >= 2 and hex != saddle:
				goals[hex] = true
		# A branch may also end on a road already laid (shared with the valley roads).
		for h: Vector2i in network.keys():
			if h != saddle:
				goals[h] = true
		var hospice: bool = int(region.passes[p]["metres"]) >= WorldPlaces.HOSPICE_MIN_METRES
		var branches: Array[Array] = []
		for e: Vector4i in pass_branch_edges(p):
			# An edge already carrying a road is still a branch: the search then ends at once on the road beside it, and the
			# pass keeps its road even when the link that carried the edge is pruned.
			var path := _search([saddle], goals, e, 0)
			if path.size() >= 2:
				branches.append(path)
		branches.sort_custom(func(a: Array, b: Array) -> bool: return a.size() < b.size())
		var kept_paths: Array[Array] = []
		for path: Array in branches:
			if kept_paths.size() >= PASS_SIDES:
				break
			if not _diverges(path, kept_paths):
				continue
			kept_paths.append(path)
			var kept: Array[Vector2i] = []
			for item: Variant in path:
				kept.append(item)
			_add_path(kept, RANK_CITY if hospice else RANK_OTHER, "pass", pass_name)


## True when a branch of a pass leaves on its own side: it shares no hex with a kept branch, and past its first hex it never runs
## beside one. Two branches that run side by side from the saddle are the same side of the pass.
static func _diverges(path: Array, kept_paths: Array[Array]) -> bool:
	for k: Array in kept_paths:
		for i: int in range(1, path.size()):
			for j: int in range(1, k.size()):
				var a: Vector2i = path[i]
				var b: Vector2i = k[j]
				if a == b:
					return false
				if i >= 2 and j >= 2 and WorldPlaces.hex_distance(a, b) <= 1:
					return false
	return true


## Rule 6: the sea ports, from west to east, each to the next along the coast.
func _link_ports() -> void:
	var ports: Array[Dictionary] = []
	for pl: Dictionary in places.places:
		if bool(pl["sea"]):
			ports.append(pl)
	ports.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		var ph: Vector2i = p["hex"]
		var qh: Vector2i = q["hex"]
		return ph.x < qh.x)
	for i: int in range(ports.size() - 1):
		var a: Vector2i = ports[i]["hex"]
		var b: Vector2i = ports[i + 1]["hex"]
		_connect(a, b, RANK_CITY, "coast")


static func _pair_key(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)


# ----- the sparse network (owner's review, 2026-11-14) -----------------------------------------------------------------


## Drops the parallel links: links are taken in order of rank (highest first) and then shorter first, and a link that runs
## within one hex of a road already kept for more than PARALLEL_RUN hexes in a row is dropped. The towns that lost their road
## are joined again to the kept network (the rejoin), so every town stays on a road.
func _prune_parallel() -> void:
	var order: Array[int] = []
	for i: int in links.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var la: Dictionary = links[a]
		var lb: Dictionary = links[b]
		if int(la["rank"]) != int(lb["rank"]):
			return int(la["rank"]) > int(lb["rank"])
		var pa: Array = la["path"]
		var pb: Array = lb["path"]
		if pa.size() != pb.size():
			return pa.size() < pb.size()
		return a < b)
	var kept_hex: Dictionary[Vector2i, bool] = {}
	var keep: Dictionary[int, bool] = {}
	for i: int in order:
		var path: Array = links[i]["path"]
		var run := 0
		var best := 0
		for item: Variant in path:
			var h: Vector2i = item
			if kept_hex.has(h):
				run = 0
			elif _beside_kept(h, kept_hex):
				run += 1
				best = maxi(best, run)
			else:
				run = 0
		# A pass branch is never pruned: every pass with a saddle keeps its road (the owner's check).
		if best > PARALLEL_RUN and str(links[i]["kind"]) != "pass":
			pruned_links += 1
			continue
		keep[i] = true
		for item: Variant in path:
			var h: Vector2i = item
			kept_hex[h] = true
	var kept: Array[Dictionary] = []
	for i: int in links.size():
		if keep.has(i):
			kept.append(links[i])
	links = kept
	_rebuild_network()
	for pl: Dictionary in places.places:
		if bool(pl["generated"]) or int(pl["level"]) < 2:
			continue
		var at: Vector2i = pl["hex"]
		if not network.has(at):
			_join_place(pl)
			rejoined += 1


## True when a hex lies within one hex of a kept road hex (the hex itself is not counted).
func _beside_kept(h: Vector2i, kept_hex: Dictionary[Vector2i, bool]) -> bool:
	for nb: Vector2i in grid.neighbours(h):
		if kept_hex.has(nb):
			return true
	return false


## The road edges, hexes and traffic of the kept links, from scratch.
func _rebuild_network() -> void:
	network.clear()
	_rank.clear()
	_traffic.clear()
	for ln: Dictionary in links:
		var path: Array = ln["path"]
		var rank := int(ln["rank"])
		for i: int in path.size() - 1:
			var a: Vector2i = path[i]
			var b: Vector2i = path[i + 1]
			var e := HexGrid.edge_key(a, b)
			_rank[e] = maxi(int(_rank.get(e, 0)), rank)
			_traffic[e] = int(_traffic.get(e, 0)) + 1
		for item: Variant in path:
			var h: Vector2i = item
			network[h] = true


# ----- quality and crossings (03 section 8, quality and bridges) --------------------------------------------------------


func _finish() -> void:
	for e: Vector4i in _rank.keys():
		var pair := HexGrid.edge_hexes(e)
		var rank := int(_rank[e])
		var q := rank
		if int(_traffic.get(e, 0)) >= TRAFFIC_UP:
			q += 1
		if rank < RANK_CAPITAL:
			q = mini(q, RANK_CITY)  # only the capital's links are highways (owner's review: sparse network)
		q = mini(q, 3)
		if relief.level_at(pair[0]) >= 5 or relief.level_at(pair[1]) >= 5:
			q = mini(q, MOUNTAIN_CAP)
		if places.pass_edges.has(e):
			q = mini(q, PASS_QUALITY)
		quality[e] = maxi(q, 1)
	network.clear()
	for e: Vector4i in quality.keys():
		var pair := HexGrid.edge_hexes(e)
		network[pair[0]] = true
		network[pair[1]] = true


func _cross_all() -> void:
	for e: Vector4i in quality.keys():
		crossing[e] = _crossing_of(e, quality[e])


## The crossing a road of quality q needs on edge e (03 section 8, the bridges table). A ferry on a lake, a pass on a pass
## edge, a bridge where a settlement can build one, a ford where it cannot.
func _crossing_of(e: Vector4i, q: int) -> String:
	if places.pass_edges.has(e):
		return "pass"
	if water.lake_edge.has(e):
		return "ferry"
	var pair := HexGrid.edge_hexes(e)
	if water.river_edge.has(e):
		var klass := int(water.rivers[int(water.river_edge[e])]["class"])
		if klass >= 3:
			return "bridge_wood" if (q >= 2 and _beside(pair, 3)) else "ferry"
		if klass == 2:
			if q <= 1:
				return "bridge_wood" if _beside(pair, 3) else "ford"
			if q == 3 and _beside(pair, 4):
				return "bridge_stone"
			return "bridge_wood"
		return "ford" if q <= 1 else "bridge_wood"
	if water.stream_edge.has(e) and not _city_edge.has(e):
		return "ford" if q <= 1 else "bridge_wood"
	return "none"


# ----- a binary heap of [cost, hex] pairs ----------------------------------------------------------------------------------


static func _push(heap: Array[Array], cost: float, hex: Vector2i) -> void:
	heap.append([cost, hex])
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		var up: Array = heap[parent]
		var here: Array = heap[i]
		if float(up[0]) <= float(here[0]):
			break
		heap[parent] = here
		heap[i] = up
		i = parent


static func _pop(heap: Array[Array]) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	var n := heap.size()
	while true:
		var left := 2 * i + 1
		var right := left + 1
		var m := i
		if left < n and float(heap[left][0]) < float(heap[m][0]):
			m = left
		if right < n and float(heap[right][0]) < float(heap[m][0]):
			m = right
		if m == i:
			break
		var tmp: Array = heap[i]
		heap[i] = heap[m]
		heap[m] = tmp
		i = m
	return top
