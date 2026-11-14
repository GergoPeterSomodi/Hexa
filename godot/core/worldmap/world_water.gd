## The water of the map prototype region: the rivers and lakes as chains of hex edges that follow the authored courses,
## the shores, the sea depth bands, the river cities, and the generated streams. Pure: no files, no engine.
##
## The model (docs/design/map/04-wfc-model.md sections 3.1 to 3.3, 3.6): a river runs along hex EDGES from CORNER to
## CORNER. A corner is the meeting point of three hexes, named by those three hexes. Each river step is one edge. A
## river city (3.6) is crossed through its hex: the river enters at one corner of the city hex and leaves at another
## (straight: three corners round; loop: two corners round), and none of the six edges of the city hex carries water.
## Corner words (3.3): source (0 in, 1 out), run (1, 1), join (2, 1), mouth (1, 0: only at the sea, a lake or the edge of
## the map), city_in and city_out (the two corners of a river city's hex).
##
## Routing: the cheapest chain of corners, where the distance from the authored course dominates, a turn costs more the
## sharper it is, no chain visits a corner twice, and a river steps downhill (corner heights are the lowest of their
## three hexes). Where no downhill chain exists the router falls back to a plain chain, and the step is reported.
class_name WorldWater
extends RefCounted

const NO_CORNER := Vector3i(-1, -1, -1)
const NO_EDGE := Vector4i(-1, -1, -1, -1)
## A lake at least this fraction of a hex wide is a whole water hex (decision D3); narrower lakes are ribbons on edges.
const LAKE_WHOLE_FRACTION := 0.6
## A river may not climb more than this from one corner to the next (metres).
const DOWNHILL_TOLERANCE_M := 60.0
## Edge costs, in multiples of a hex's circumradius.
const CORRIDOR_FREE := 0.15  # a fraction of a hex width: nearer than this to the course costs nothing extra
const CORRIDOR_WEIGHT := 25.0
const LAKE_CORRIDOR_FREE := 0.6  # lakes: corners are about 16 km apart, so a wider free corridor follows the axis
const SEA_COST := 20.0
const CREST_COST := 100.0
const SPINE_COST := 3.0  # an edge beside a spine hex (crest height) costs more: rivers keep to the valley floor
const TURN_COST := 1.2  # a full turn (180 degrees) costs this many circumradii
const UPHILL_STEP_M := 50.0
## Generated streams are drawn where this many corners drain through an edge.
const STREAM_MIN_CORNERS := 6
## Hexes at this crest level or higher are spine hexes.
const SPINE_LEVEL := 5
## A crest crossing is named when a gorge of that river lies within this many hex widths of the step.
const GORGE_RADIUS_HEX := 1.2

var grid: WorldGrid
var relief: WorldRelief
var heights: WorldHeights
var region: WorldRegion
var corner_set: Dictionary[Vector3i, bool] = {}  # every corner whose three hexes are in the grid
var corner_word: Dictionary[Vector3i, String] = {}  # corners of a river or lake
var network: Dictionary[Vector3i, bool] = {}  # corners that any river or lake passes
var rivers: Array[Dictionary] = []  # name, class, corners, steps (Array[Vector4i], NO_EDGE for a river city), throughs
var lakes: Array[Dictionary] = []  # name, width, whole, corners, steps, hexes
var river_edge: Dictionary[Vector4i, int] = {}  # edge -> index of the river that uses it
var lake_edge: Dictionary[Vector4i, bool] = {}
var lake_hex: Dictionary[Vector2i, bool] = {}  # whole water hexes of big lakes (drawn like the sea)
var shore_edge: Dictionary[Vector4i, String] = {}
var stream_edge: Dictionary[Vector4i, int] = {}
var sea_band: Dictionary[Vector2i, String] = {}
var city_hex: Dictionary[String, Vector2i] = {}
var city_river: Dictionary[String, String] = {}
var city_form: Dictionary[String, String] = {}
var downhill_violations: Array[String] = []  # river steps that climb more than the tolerance (none expected)
var fallback_steps: Array[String] = []  # steps routed without the downhill rule because no downhill chain existed
var unresolved_ends: Array[String] = []
var route_failures: Array[String] = []
var named_crest_steps: Array[String] = []  # river steps on a crest edge that a named gorge (or a river head) explains
var unnamed_crest_steps: Array[String] = []  # river steps on a crest edge with no gorge or head: none expected
var stream_sinks: int = 0
var _blocked: Dictionary[Vector4i, bool] = {}  # edges no river may use (the six edges of each river city hex)
var _gorge_hex: Dictionary[Vector2i, bool] = {}  # hexes within a gorge's radius: a river may cross a spine here
var _through_partner: Dictionary[Vector3i, Vector3i] = {}  # a river city's corner -> the corner its river leaves by
var _city_of_corner: Dictionary[Vector3i, String] = {}  # a river city's corner -> the city
var _current_river := ""  # the river being routed (a river city is crossed only by its own river)
var flow_height: Dictionary[Vector3i, float] = {}  # the drainage surface: corner heights with the sinks filled to their spill level
var filled_m: float = 0.0  # the largest amount a corner was raised to drain (reported)
var _flood_parent: Dictionary[Vector3i, Vector3i] = {}  # the fill-direction graph: each corner drains to its flood parent
var _flood_order: Array[Vector3i] = []  # corners in the order the flood finished them (parents before children)
var _lake_mode := false  # routing a lake: lakes cross the prealps at their gaps, so no crest cost


## Builds the water from the relief, the heights (land heights, sea depths) and the region's river and lake courses.
static func build(p_grid: WorldGrid, p_relief: WorldRelief, p_heights: WorldHeights, p_region: WorldRegion) -> WorldWater:
	var out := WorldWater.new()
	out.grid = p_grid
	out.relief = p_relief
	out.heights = p_heights
	out.region = p_region
	out._build_corners()
	out._build_flow()
	out._build_cities()
	out._build_city_corners()
	out._route_lakes()
	out._route_rivers()
	out._assign_words()
	out._build_shores()
	out._build_sea_bands()
	out._build_streams()
	return out


# ----- corners ------------------------------------------------------------------------------------------------------


static func corner_key(a: Vector2i, b: Vector2i, c: Vector2i) -> Vector3i:
	var codes: Array[int] = [_code(a), _code(b), _code(c)]
	codes.sort()
	return Vector3i(codes[0], codes[1], codes[2])


static func _code(h: Vector2i) -> int:
	return (h.y + 1000) * 4000 + (h.x + 1000)


static func _corner_less(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z


func _build_corners() -> void:
	for hex: Vector2i in relief.levels.keys():
		for k: int in 6:
			var key := _hex_corner(hex, k)
			if key != NO_CORNER:
				corner_set[key] = true
	for g: Dictionary in region.gorges:
		var pos: Vector2 = g["pos"]
		var centre := grid.km_of(pos.x, pos.y)
		for hex: Vector2i in relief.levels.keys():
			if grid.centre_km(hex).distance_to(centre) <= GORGE_RADIUS_HEX * grid.hex_w_km:
				_gorge_hex[hex] = true


## The corner k (0 at the top, then anticlockwise) of a hex, or NO_CORNER when a neighbour is outside the grid.
func _hex_corner(hex: Vector2i, k: int) -> Vector3i:
	var dirs: Array[int] = []
	for e: int in 6:
		var pair := WorldGrid.EDGE_CORNERS[e]
		if pair.x == k or pair.y == k:
			dirs.append(e)
	var n1 := grid.neighbour(hex, dirs[0])
	var n2 := grid.neighbour(hex, dirs[1])
	if not (relief.levels.has(hex) and relief.levels.has(n1) and relief.levels.has(n2)):
		return NO_CORNER
	return corner_key(hex, n1, n2)


## The three hexes of a corner.
static func corner_hexes_of(key: Vector3i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for code: int in [key.x, key.y, key.z]:
		var y := floori(float(code) / 4000.0) - 1000
		out.append(Vector2i(code - (y + 1000) * 4000 - 1000, y))
	return out


func corner_pos(key: Vector3i) -> Vector2:
	var sum := Vector2.ZERO
	for h: Vector2i in corner_hexes_of(key):
		sum += grid.centre_km(h)
	return sum / 3.0


## The drainage surface (priority flood): every land corner drains downhill to the sea, a lake or the map edge. A basin
## with no way out is filled up to its spill level; the amount filled is reported. Rivers and streams flow on this surface.
func _build_flow() -> void:
	var heap: Array = []
	var done: Dictionary[Vector3i, bool] = {}
	for key: Vector3i in corner_set.keys():
		if _is_outlet(key):
			var h0 := corner_height(key)
			flow_height[key] = h0
			_heap_push(heap, [h0, key])
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var c: Vector3i = top[1]
		if done.has(c):
			continue
		done[c] = true
		_flood_order.append(c)
		var fc: float = top[0]
		for e: Vector4i in _corner_edges(c):
			var o := _other_corner(e, c)
			if o == NO_CORNER or done.has(o):
				continue
			var fo := maxf(corner_height(o), fc)
			if not flow_height.has(o) or fo < flow_height[o]:
				flow_height[o] = fo
				_flood_parent[o] = c
				_heap_push(heap, [fo, o])
	for key: Vector3i in corner_set.keys():
		if flow_height.has(key):
			filled_m = maxf(filled_m, flow_height[key] - corner_height(key))


func _is_outlet(key: Vector3i) -> bool:
	return _touches_water(key) or _is_border(key)


## The height water sees at a corner: the drainage surface (see _build_flow).
func flow(key: Vector3i) -> float:
	return float(flow_height.get(key, corner_height(key)))


## The height a river sees at a corner: the lowest of its three hexes (water flows at the low side of a corner).
## Sea and lake hexes count as 0.
func corner_height(key: Vector3i) -> float:
	var low := INF
	for h: Vector2i in corner_hexes_of(key):
		var v := 0.0
		if relief.level_at(h) != ReliefLevels.SEA and not lake_hex.has(h):
			v = float(heights.height_m.get(h, 0.0))
		low = minf(low, v)
	return low


## The corners at the two ends of an edge (one when the far side is outside the grid).
func _edge_corners(edge: Vector4i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var a := Vector2i(edge.x, edge.y)
	var b := Vector2i(edge.z, edge.w)
	for n: Vector2i in grid.neighbours(a):
		if n == b or grid.direction_of(b, n) < 0:
			continue
		var key := corner_key(a, b, n)
		if corner_set.has(key):
			out.append(key)
	return out


func _corner_edges(key: Vector3i) -> Array[Vector4i]:
	var h := corner_hexes_of(key)
	return [WorldGrid.edge_key(h[0], h[1]), WorldGrid.edge_key(h[1], h[2]), WorldGrid.edge_key(h[0], h[2])]


func _other_corner(edge: Vector4i, key: Vector3i) -> Vector3i:
	for c: Vector3i in _edge_corners(edge):
		if c != key:
			return c
	return NO_CORNER


func _shared_edge(c1: Vector3i, c2: Vector3i) -> Vector4i:
	var common: Array[Vector2i] = []
	var h2 := corner_hexes_of(c2)
	for h: Vector2i in corner_hexes_of(c1):
		if h2.has(h):
			common.append(h)
	if common.size() != 2:
		return NO_EDGE
	return WorldGrid.edge_key(common[0], common[1])


func _nearest_corner(km: Vector2, only_network: bool, exclude: Vector3i = NO_CORNER) -> Vector3i:
	var best := NO_CORNER
	var best_d := INF
	for key: Vector3i in corner_set.keys():
		if only_network and not network.has(key):
			continue
		if key == exclude:
			continue
		var d := corner_pos(key).distance_to(km)
		if d < best_d:
			best_d = d
			best = key
	return best


## The nearest corner on the edge of the map (a corner with a hex beside it outside the grid), other than exclude.
func _nearest_border_corner(km: Vector2, exclude: Vector3i) -> Vector3i:
	var best := NO_CORNER
	var best_d := INF
	for key: Vector3i in corner_set.keys():
		if key == exclude or not _is_border(key):
			continue
		var d := corner_pos(key).distance_to(km)
		if d < best_d:
			best_d = d
			best = key
	return best


func _is_border(key: Vector3i) -> bool:
	for h: Vector2i in corner_hexes_of(key):
		for n: Vector2i in grid.neighbours(h):
			if not relief.levels.has(n):
				return true
	return false


# ----- routing ------------------------------------------------------------------------------------------------------


func _is_sea(h: Vector2i) -> bool:
	return relief.level_at(h) == ReliefLevels.SEA or lake_hex.has(h)


func _edge_cost(edge: Vector4i, line: PackedVector2Array, lake_discount: bool) -> float:
	var a := Vector2i(edge.x, edge.y)
	var b := Vector2i(edge.z, edge.w)
	var base := grid.hex_r_km
	if lake_discount and lake_edge.has(edge):
		return base * 0.5
	var mid := (grid.centre_km(a) + grid.centre_km(b)) / 2.0
	var off := _distance_to_line(mid, line)
	var free := (LAKE_CORRIDOR_FREE if _lake_mode else CORRIDOR_FREE) * grid.hex_w_km
	var cost := base * (1.0 + CORRIDOR_WEIGHT * maxf(0.0, off - free) / grid.hex_w_km)
	if relief.crest_edges.has(edge) and not _lake_mode:
		cost += CREST_COST * base
	if _is_sea(a) or _is_sea(b):
		cost += SEA_COST * base
	if relief.crest_levels.get(a, 0) >= SPINE_LEVEL or relief.crest_levels.get(b, 0) >= SPINE_LEVEL:
		cost += SPINE_COST * base
	return cost


static func _distance_to_line(p: Vector2, line: PackedVector2Array) -> float:
	if line.size() == 1:
		return p.distance_to(line[0])
	var best := INF
	for i: int in line.size() - 1:
		var a := line[i]
		var ab := line[i + 1] - a
		var len2 := ab.length_squared()
		var t := 0.0 if len2 == 0.0 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		best = minf(best, (p - (a + ab * t)).length())
	return best


static func _skey(c: Vector3i, prev: Vector3i) -> String:
	return "%d,%d,%d|%d,%d,%d" % [c.x, c.y, c.z, prev.x, prev.y, prev.z]


## The cheapest chain of corners from start to goal (both included), or an empty array when there is none. A state is a
## corner and the corner before it, so a turn can cost more than going straight. Strict routes take only downhill
## steps (lake edges excepted); the lake routes ignore the downhill rule and give lake edges a discount.
var _last_cost := 0.0  # the cost of the last route found by _route


func _route(start: Vector3i, goal: Vector3i, line: PackedVector2Array, strict: bool, lake_route: bool,
		allow_spine: bool = false) -> Array[Vector3i]:
	var goals: Dictionary[Vector3i, bool] = {goal: true}
	return _route_to_any(start, goals, line, strict, lake_route, allow_spine)


## The cheapest chain from start to the first of the goals reached (both ends included); empty when there is none.
func _route_to_any(start: Vector3i, goals: Dictionary[Vector3i, bool], line: PackedVector2Array, strict: bool,
		lake_route: bool, allow_spine: bool) -> Array[Vector3i]:
	var dist: Dictionary[String, float] = {}
	var prev_state: Dictionary[String, String] = {}
	var state_corner: Dictionary[String, Vector3i] = {}
	var start_key := _skey(start, NO_CORNER)
	dist[start_key] = 0.0
	state_corner[start_key] = start
	var heap: Array = []
	_heap_push(heap, [0.0, start_key])
	var found := ""
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var key: String = top[1]
		var dc: float = top[0]
		if dc > float(dist.get(key, INF)):
			continue
		var c: Vector3i = state_corner[key]
		if _through_partner.has(c):
			var city: String = _city_of_corner[c]
			var came_from := pc_of_key(key)
			var entered_from_outside: bool = not (came_from != NO_CORNER and str(_city_of_corner.get(came_from, "")) == city)
			if entered_from_outside and city_river.get(city, "") == _current_river and not lake_route:
				var partner: Vector3i = _through_partner[c]
				var jump := _skey(partner, c)
				if dc + 0.3 * grid.hex_r_km < float(dist.get(jump, INF)):
					dist[jump] = dc + 0.3 * grid.hex_r_km
					prev_state[jump] = key
					state_corner[jump] = partner
					_heap_push(heap, [dist[jump], jump])
		if goals.has(c):
			found = key
			_last_cost = dc
			break
		var pc := _state_prev(key)
		var pos_c := corner_pos(c)
		var hc := flow(c)
		for e: Vector4i in _corner_edges(c):
			if _blocked.has(e):
				continue
			var other := _other_corner(e, c)
			if other == NO_CORNER:
				continue
			var climb := flow(other) - hc
			var is_lake := lake_edge.has(e)
			if strict and not is_lake and climb > 0.5:
				continue
			if strict and not allow_spine and not is_lake and _edge_on_spine(e):
				continue
			var nd := dc + _edge_cost(e, line, lake_route)
			if climb > DOWNHILL_TOLERANCE_M and not is_lake:
				nd += grid.hex_r_km * climb / UPHILL_STEP_M
			if pc != NO_CORNER:
				var turn := absf((pos_c - corner_pos(pc)).angle_to(corner_pos(other) - pos_c))
				nd += grid.hex_r_km * TURN_COST * turn / PI
			var nk := _skey(other, c)
			if nd < float(dist.get(nk, INF)):
				dist[nk] = nd
				prev_state[nk] = key
				state_corner[nk] = other
				_heap_push(heap, [nd, nk])
	var path: Array[Vector3i] = []
	if found == "":
		return path
	var cur := found
	path.append(state_corner[cur])
	while cur != start_key:
		cur = prev_state[cur]
		path.push_front(state_corner[cur])
	return path


## True when an edge has a spine hex on either side, except at a gorge (a river may cross a spine there).
func _edge_on_spine(e: Vector4i) -> bool:
	for h: Vector2i in WorldGrid.edge_hexes(e):
		if relief.crest_levels.get(h, 0) >= SPINE_LEVEL and not _gorge_hex.has(h):
			return true
	return false


## The corner before a state, from its key.
static func pc_of_key(key: String) -> Vector3i:
	return _state_prev(key)


## The previous corner of a state key (the second part of the key).
static func _state_prev(key: String) -> Vector3i:
	var parts := key.split("|")
	var p := parts[1].split(",")
	if int(p[0]) == -1:
		return NO_CORNER
	return Vector3i(int(p[0]), int(p[1]), int(p[2]))


## The chain with its loops taken out: when a corner comes back, the chain is cut back to its first visit.
static func _without_loops(chain: Array[Vector3i]) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var index: Dictionary[Vector3i, int] = {}
	for c: Vector3i in chain:
		if index.has(c):
			var j: int = index[c]
			for k: int in range(j + 1, out.size()):
				index.erase(out[k])
			out.resize(j + 1)
		else:
			index[c] = out.size()
			out.append(c)
	return out


static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if float(heap[parent][0]) <= float(item[0]):
			break
		heap[i] = heap[parent]
		i = parent
	heap[i] = item


static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	var i := 0
	var n := heap.size()
	while true:
		var l := 2 * i + 1
		var r := l + 1
		var m := i
		var mc := float(last[0])
		if l < n and float(heap[l][0]) < mc:
			m = l
			mc = float(heap[l][0])
		if r < n and float(heap[r][0]) < mc:
			m = r
		if m == i:
			break
		heap[i] = heap[m]
		i = m
	heap[i] = last
	return top


# ----- cities, lakes, rivers ----------------------------------------------------------------------------------------


func _build_cities() -> void:
	for rc: Dictionary in region.river_cities:
		var city := str(rc["name"])
		var pl := region.find_place(city)
		if pl.is_empty():
			continue
		var pos: Vector2 = pl["pos"]
		var hex := grid.hex_of(pos.x, pos.y)
		city_hex[city] = hex
		city_river[city] = str(rc["river"])
		city_form[city] = str(rc["form"])
		for e: int in 6:
			_blocked[WorldGrid.edge_key(hex, grid.neighbour(hex, e))] = true


## The six corners of each river city's hex, with the corner the river leaves by: straight across (3 round) or in a loop
## (2 round). A search that reaches a city corner from outside may cross the hex to its partner at no cost.
func _build_city_corners() -> void:
	for city: String in city_hex.keys():
		var far := 3 if city_form[city] == "straight" else 2
		for k: int in 6:
			var a := _hex_corner(city_hex[city], k)
			var b := _hex_corner(city_hex[city], (k + far) % 6)
			if a == NO_CORNER or b == NO_CORNER:
				continue
			_city_of_corner[a] = city
			_through_partner[a] = b


func _city_at(river_name: String, km: Vector2) -> String:
	var hex := grid.hex_of_km(km)
	for city: String in city_hex.keys():
		if city_river[city] == river_name and city_hex[city] == hex:
			return city
	return ""


## The two corners a river uses to cross a river city's hex, from corner k: straight across (k + 3) or in a loop (k + 2).
func _through_corners(city: String, k: int) -> Array[Vector3i]:
	var far := 3 if city_form[city] == "straight" else 2
	return [_hex_corner(city_hex[city], k), _hex_corner(city_hex[city], (k + far) % 6)]


func _route_lakes() -> void:
	for lk: Dictionary in region.lakes:
		var axis: PackedVector2Array = lk["axis"]
		var km := PackedVector2Array()
		for p: Vector2 in axis:
			km.append(grid.km_of(p.x, p.y))
		var width_km := float(lk["width_km"])
		var whole := width_km >= LAKE_WHOLE_FRACTION * grid.hex_w_km
		var hexes: Array[Vector2i] = []
		var corners: Array[Vector3i] = []
		var steps: Array[Vector4i] = []
		if whole:
			for hex: Vector2i in relief.levels.keys():
				if _distance_to_line(grid.centre_km(hex), km) <= width_km / 2.0:
					lake_hex[hex] = true
					hexes.append(hex)
		else:
			# The lake is routed along its own axis (no downhill rule: a lake is flat water; no crest cost: the Adda and the
			# Lecco gap cross the prealps).
			_lake_mode = true
			var path := _without_loops(_route(_nearest_corner(km[0], false), _nearest_corner(km[km.size() - 1], false),
				km, false, false))
			_lake_mode = false
			if path.is_empty():
				route_failures.append("lake %s" % lk["name"])
			else:
				for i: int in path.size() - 1:
					var e := _shared_edge(path[i], path[i + 1])
					if e != NO_EDGE:
						steps.append(e)
						lake_edge[e] = true
						network[path[i]] = true
				network[path[path.size() - 1]] = true
				corners = path
		lakes.append({"name": str(lk["name"]), "width": str(lk["width"]), "whole": whole,
			"corners": corners, "steps": steps, "hexes": hexes})


func _route_rivers() -> void:
	var order: Array[Dictionary] = []
	for rv: Dictionary in region.rivers:
		order.append(rv)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["class"]) > int(b["class"]))
	for rv: Dictionary in order:
		_route_river(rv)


func _route_river(rv: Dictionary) -> void:
	var name := str(rv["name"])
	var line: PackedVector2Array = rv["line"]
	var km := PackedVector2Array()
	for p: Vector2 in line:
		km.append(grid.km_of(p.x, p.y))
	var is_trunk := int(rv["class"]) >= 3
	var n := km.size()
	var chain: Array[Vector3i] = []
	_current_river = name
	var cur := _source_corner(km[0])
	chain.append(cur)
	# The last leg: to the map edge when the river leaves the map, else to the mouth or, for a tributary, to the nearest
	# corner of a river already routed. River cities are crossed inside the search (see _build_city_corners).
	var last_p := km[n - 1]
	var goals: Dictionary[Vector3i, bool] = {}
	if not relief.levels.has(grid.hex_of_km(last_p)):
		for key: Vector3i in corner_set.keys():
			if _is_border(key) and corner_pos(key).distance_to(last_p) <= 2.0 * grid.hex_w_km:
				goals[key] = true
		var edge_corner := _nearest_border_corner(last_p, cur)
		if edge_corner != NO_CORNER:
			goals[edge_corner] = true
	elif not is_trunk:
		# A tributary ends where it joins a river already routed (the nearest such corner within two hex widths).
		for key: Vector3i in network.keys():
			if key != cur and corner_pos(key).distance_to(last_p) <= 2.0 * grid.hex_w_km:
				goals[key] = true
		if goals.is_empty():
			goals[_nearest_corner(last_p, false, cur)] = true
	else:
		# The mouth is an ordinary corner: a river city's own corners are never the end of a river.
		var mouth := NO_CORNER
		var mouth_d := INF
		for key: Vector3i in corner_set.keys():
			if key == cur or _city_of_corner.has(key):
				continue
			var d := corner_pos(key).distance_to(last_p)
			if d < mouth_d:
				mouth_d = d
				mouth = key
		goals[mouth] = true
		if not is_trunk or _touches_water(mouth):
			pass
		# A river that ends at the sea may end on any corner touching the sea within two hex widths.
		for key: Vector3i in corner_set.keys():
			if _touches_water(key) and not _city_of_corner.has(key) and corner_pos(key).distance_to(last_p) <= 2.0 * grid.hex_w_km:
				goals[key] = true
	var tail := _leg(cur, goals, km, name)
	if tail.is_empty():
		route_failures.append("%s: no route to its end" % name)
	else:
		for c: Vector3i in tail.slice(1):
			chain.append(c)
	chain = _without_loops(chain)
	# Throughs that survive the loop cut are consecutive pairs of the chain.
	var throughs: Array[Vector2i] = []
	for i: int in chain.size() - 1:
		if _through_partner.get(chain[i], NO_CORNER) == chain[i + 1]:
			throughs.append(Vector2i(i, i + 1))
	var through_step: Dictionary[int, bool] = {}
	for t: Vector2i in throughs:
		through_step[t.x] = true
	var steps: Array[Vector4i] = []
	for i: int in chain.size() - 1:
		if through_step.has(i):
			steps.append(NO_EDGE)
			continue
		var e := _shared_edge(chain[i], chain[i + 1])
		if e == NO_EDGE:
			route_failures.append("%s: corners %d and %d do not share an edge" % [name, i, i + 1])
		steps.append(e)
	var index := rivers.size()
	for i: int in steps.size():
		var e := steps[i]
		if e == NO_EDGE or river_edge.has(e):
			continue
		river_edge[e] = index
		if relief.crest_edges.has(e):
			var mid := (grid.centre_km(Vector2i(e.x, e.y)) + grid.centre_km(Vector2i(e.z, e.w))) / 2.0
			if i <= 1 or _gorge_near(name, mid):
				named_crest_steps.append("%s step %d" % [name, i])
			else:
				unnamed_crest_steps.append("%s step %d at %s-%s" % [name, i, Vector2i(e.x, e.y), Vector2i(e.z, e.w)])
	for c: Vector3i in chain:
		network[c] = true
	for i: int in steps.size():
		if steps[i] == NO_EDGE or lake_edge.has(steps[i]):
			continue
		var climb := flow(chain[i + 1]) - flow(chain[i])
		if climb > 0.5:
			downhill_violations.append("%s step %d: %.0f m up" % [name, i, climb])
	rivers.append({"name": name, "class": int(rv["class"]), "corners": chain, "steps": steps, "throughs": throughs})


## One leg of a river: downhill only and off the spines (the strict routes); when that fails, the leg is routed downhill
## across the spines, then plainly, and the leg is reported.
func _leg(start: Vector3i, goals: Dictionary[Vector3i, bool], km: PackedVector2Array, river_name: String) -> Array[Vector3i]:
	var path := _route_to_any(start, goals, km, true, false, false)
	if not path.is_empty():
		return path
	path = _route_to_any(start, goals, km, true, false, true)
	if not path.is_empty():
		fallback_steps.append("%s (leg across a spine)" % river_name)
		return path
	path = _route_to_any(start, goals, km, false, false, true)
	if not path.is_empty():
		fallback_steps.append("%s (leg not downhill)" % river_name)
	return path


## A river rises on the highest corner within one hex width of its first point (the nearest corner when none is higher).
## A river's source is never a river city's corner (the river would start inside the city and lose its upper course).
func _source_corner(km: Vector2) -> Vector3i:
	var best := NO_CORNER
	var best_d := INF
	for key: Vector3i in corner_set.keys():
		if _city_of_corner.has(key):
			continue
		var d := corner_pos(key).distance_to(km)
		if d <= 0.5 * grid.hex_w_km and (best == NO_CORNER or flow(key) > flow(best) + 0.5):
			best = key
		elif best == NO_CORNER and d < best_d:
			best_d = d
	if best == NO_CORNER:
		best = _nearest_corner(km, false)
	return best


func _gorge_near(river_name: String, km: Vector2) -> bool:
	for g: Dictionary in region.gorges:
		if g["river"] != river_name:
			continue
		var pos: Vector2 = g["pos"]
		if grid.km_of(pos.x, pos.y).distance_to(km) <= GORGE_RADIUS_HEX * grid.hex_w_km:
			return true
	return false


# ----- words, shores, depths, streams -------------------------------------------------------------------------------


func _assign_words() -> void:
	var ins: Dictionary[Vector3i, int] = {}
	var outs: Dictionary[Vector3i, int] = {}
	for rv: Dictionary in rivers:
		var chain: Array[Vector3i] = rv["corners"]
		var steps: Array[Vector4i] = rv["steps"]
		var throughs: Array[Vector2i] = rv["throughs"]
		var through_step: Dictionary[int, bool] = {}
		for t: Vector2i in throughs:
			through_step[t.x] = true
		for i: int in steps.size():
			if through_step.has(i):
				continue
			outs[chain[i]] = int(outs.get(chain[i], 0)) + 1
			ins[chain[i + 1]] = int(ins.get(chain[i + 1], 0)) + 1
		for t: Vector2i in throughs:
			corner_word[chain[t.x]] = "city_in"
			corner_word[chain[t.y]] = "city_out"
	for key: Vector3i in network.keys():
		if corner_word.has(key):
			continue
		var i := int(ins.get(key, 0))
		var o := int(outs.get(key, 0))
		var word := "run"
		if i == 0 and o == 0:
			word = "lake"
		elif i == 0 and o == 1:
			word = "source"
		elif i == 1 and o == 1:
			word = "run"
		elif i == 2 and o == 1:
			word = "join"
		elif i == 1 and o == 0:
			word = "mouth"
		elif i == 1 and o == 2:
			word = "split"
		else:
			word = "join" if i > o else "source"
		corner_word[key] = word
	for rv: Dictionary in rivers:
		var chain: Array[Vector3i] = rv["corners"]
		var last := chain[chain.size() - 1]
		if corner_word.get(last, "") == "mouth" and not is_mouth(last):
			unresolved_ends.append(str(rv["name"]))


## A mouth corner touches the sea, a lake or the edge of the grid.
func is_mouth(key: Vector3i) -> bool:
	for h: Vector2i in corner_hexes_of(key):
		if _is_sea(h):
			return true
	return _is_border(key)


func _build_shores() -> void:
	for hex: Vector2i in relief.levels.keys():
		for d: int in 3:
			var nb := grid.neighbour(hex, d)
			if not relief.levels.has(nb):
				continue
			var a_water := _is_sea(hex)
			var b_water := _is_sea(nb)
			if a_water == b_water:
				continue
			var land := nb if a_water else hex
			var water := hex if a_water else nb
			var kind := "beach"
			if lake_hex.has(water):
				kind = "lake"
			elif relief.level_at(land) >= 3:
				kind = "cliff"
			shore_edge[WorldGrid.edge_key(hex, nb)] = kind


## Sea hexes with a depth get shelf, sea or deep. A sea hex with no ETOPO sea cell (depth 0) takes the band of the
## nearest sea hex that has one (breadth-first over the neighbours), so every sea hex has a band.
func _build_sea_bands() -> void:
	var without: Array[Vector2i] = []
	for hex: Vector2i in relief.levels.keys():
		if relief.level_at(hex) != ReliefLevels.SEA or lake_hex.has(hex):
			continue
		var depth := float(heights.depth_m.get(hex, 0.0))
		if depth == 0.0:
			without.append(hex)
			continue
		sea_band[hex] = "shelf" if depth >= -200.0 else ("sea" if depth >= -2000.0 else "deep")
	for hex: Vector2i in without:
		sea_band[hex] = _nearest_band(hex)


func _nearest_band(start: Vector2i) -> String:
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for h: Vector2i in frontier:
			for n: Vector2i in grid.neighbours(h):
				if seen.has(n) or not relief.levels.has(n):
					continue
				seen[n] = true
				if sea_band.has(n):
					return sea_band[n]
				next.append(n)
		frontier = next
	return "sea"


## Generated streams: every land corner that is not on a river or lake drains along the fill-direction graph (its flood
## parent). The corners that drain through a corner are counted (flow accumulation); an edge carries a stream when at least
## STREAM_MIN_CORNERS corners drain across it. Streams never use a river, lake or crest edge.
func _build_streams() -> void:
	var acc: Dictionary[Vector3i, int] = {}
	for key: Vector3i in corner_set.keys():
		acc[key] = 1
	for i: int in range(_flood_order.size() - 1, -1, -1):
		var c := _flood_order[i]
		if not _flood_parent.has(c):
			continue
		var p := _flood_parent[c]
		acc[p] = int(acc.get(p, 1)) + int(acc[c])
		if network.has(c) or _touches_water(c):
			continue
		var e := _shared_edge(c, p)
		if e == NO_EDGE or river_edge.has(e) or lake_edge.has(e) or relief.crest_edges.has(e):
			continue
		if int(acc[c]) >= STREAM_MIN_CORNERS:
			stream_edge[e] = int(acc[c])
	stream_sinks = 0


func _touches_water(key: Vector3i) -> bool:
	for h: Vector2i in corner_hexes_of(key):
		if _is_sea(h):
			return true
	return false


# ----- what the viewer and the tests read --------------------------------------------------------------------------


## The points a river is drawn through, in kilometres: the source, the midpoint of each step's edge, the centre of a
## river city's hex where the river crosses it, and the mouth. river_pins says which are fixed.
func river_points_km(index: int) -> PackedVector2Array:
	var rv: Dictionary = rivers[index]
	var steps: Array[Vector4i] = rv["steps"]
	var chain: Array[Vector3i] = rv["corners"]
	var out := PackedVector2Array()
	out.append(corner_pos(chain[0]))
	for i: int in steps.size():
		var e := steps[i]
		if e == NO_EDGE:
			out.append(grid.centre_km(_city_hex_of_link(chain[i], chain[i + 1])))
		else:
			out.append(edge_mid_km(e))
	out.append(corner_pos(chain[chain.size() - 1]))
	return out


## Which points of river_points_km are fixed: the two ends and each river city crossing.
func river_pins(index: int) -> Array[bool]:
	var rv: Dictionary = rivers[index]
	var steps: Array[Vector4i] = rv["steps"]
	var pins: Array[bool] = [true]
	for e: Vector4i in steps:
		pins.append(e == NO_EDGE)
	pins.append(true)
	return pins


## The points of a lake's routed chain (its edge midpoints), in kilometres.
func lake_points_km(index: int) -> PackedVector2Array:
	var lk: Dictionary = lakes[index]
	var steps: Array[Vector4i] = lk["steps"]
	var out := PackedVector2Array()
	for e: Vector4i in steps:
		out.append(edge_mid_km(e))
	return out


## The midpoint of an edge in kilometres.
func edge_mid_km(e: Vector4i) -> Vector2:
	return (grid.centre_km(Vector2i(e.x, e.y)) + grid.centre_km(Vector2i(e.z, e.w))) / 2.0


func _city_hex_of_link(a: Vector3i, b: Vector3i) -> Vector2i:
	var hb := corner_hexes_of(b)
	for h: Vector2i in corner_hexes_of(a):
		if hb.has(h):
			return h
	return Vector2i.ZERO


## Counts for the report and the tests.
func summary() -> Dictionary:
	var words: Dictionary[String, int] = {}
	for key: Vector3i in corner_word.keys():
		words[corner_word[key]] = int(words.get(corner_word[key], 0)) + 1
	var bands: Dictionary[String, int] = {}
	for hex: Vector2i in sea_band.keys():
		bands[sea_band[hex]] = int(bands.get(sea_band[hex], 0)) + 1
	var shores: Dictionary[String, int] = {}
	for e: Vector4i in shore_edge.keys():
		shores[shore_edge[e]] = int(shores.get(shore_edge[e], 0)) + 1
	return {
		"rivers": rivers.size(),
		"river_steps": river_edge.size(),
		"river_cities": city_hex.size(),
		"lakes": lakes.size(),
		"lake_edges": lake_edge.size(),
		"whole_lake_hexes": lake_hex.size(),
		"words": words,
		"shores": shores,
		"sea_bands": bands,
		"stream_edges": stream_edge.size(),
		"stream_sinks": stream_sinks,
		"downhill_violations": downhill_violations.size(),
		"fallback_steps": fallback_steps.size(),
		"unresolved_ends": unresolved_ends.size(),
		"route_failures": route_failures.size(),
		"named_crest_steps": named_crest_steps.size(),
		"unnamed_crest_steps": unnamed_crest_steps.size(),
	}
