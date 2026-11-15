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
## Stream burning: before the fill, every authored course is cut into the drainage surface (_build_courses and
## _burn_courses): each corner of a course is lower than the one before it, so the router follows the course downhill
## and the fill does not block it. A spine crossed on a course is allowed there and reported (see the crest lists).
class_name WorldWater
extends RefCounted

const NO_CORNER := Vector3i(-1, -1, -1)
const NO_EDGE := Vector4i(-1, -1, -1, -1)
## A lake at least this fraction of a hex wide is a whole water hex (decision D3); narrower lakes are ribbons on edges.
const LAKE_WHOLE_FRACTION := 0.6
## A ribbon lake's routed chain is clipped to its authored axis ends: no step may lie further than this many hex widths
## beyond an end of the axis (the lake ends where it ends; the routing corners are about a hex apart).
const LAKE_CLIP_HEX := 0.5
## A river may not climb more than this from one corner to the next (metres).
const DOWNHILL_TOLERANCE_M := 60.0
## Edge costs, in multiples of a hex's circumradius.
const CORRIDOR_FREE := 0.15  # a fraction of a hex width: nearer than this to the course costs nothing extra
const CORRIDOR_WEIGHT := 25.0
## A river city crossed two corners apart (the river bends inside the hex) costs this many hex radii more than straight.
const THROUGH_BEND_COST := 1.0
const LAKE_CORRIDOR_FREE := 0.6  # lakes: corners are about 16 km apart, so a wider free corridor follows the axis
const SEA_COST := 20.0
const CREST_COST := 100.0
const SPINE_COST := 3.0  # an edge beside a spine hex (crest height) costs more: rivers keep to the valley floor
const TURN_COST := 1.2  # a full turn (180 degrees) costs this many circumradii
const UPHILL_STEP_M := 50.0
## Generated streams are drawn where this many corners drain through an edge.
const STREAM_MIN_CORNERS := 4
## Hexes at this crest level or higher are spine hexes.
const SPINE_LEVEL := 5
## A crest crossing is named when a gorge of that river lies within this many hex widths of the step.
const GORGE_RADIUS_HEX := 1.2
## Stream burning: each corner of an authored course is this many metres lower than the corner before it.
const BURN_STEP_M := 1.0
## A river's mouth is a corner that touches the sea, a lagoon or a lake within this many hex widths of its last point.
const MOUTH_REACH_HEX := 1.5

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
var lagoon: Dictionary[Vector2i, bool] = {}  # sea hexes inside the region's lagoon ring (shallow: sea band lagoon)
var marsh_zone: Dictionary[Vector2i, bool] = {}  # hexes inside a region marsh zone (the cover step forces marsh on the low ones)
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
var _through_partners: Dictionary[Vector3i, Array] = {}  # a river city's corner -> the corners its river may leave by (3.6)
var _city_of_corner: Dictionary[Vector3i, String] = {}  # a river city's corner -> the city
var _current_river := ""  # the river being routed (a river city is crossed only by its own river)
var flow_height: Dictionary[Vector3i, float] = {}  # the drainage surface: corner heights with the sinks filled to their spill level
var filled_m: float = 0.0  # the largest amount a corner was raised to drain (reported)
var _flood_parent: Dictionary[Vector3i, Vector3i] = {}  # the fill-direction graph: each corner drains to its flood parent
var _flood_order: Array[Vector3i] = []  # corners in the order the flood finished them (parents before children)
var _burn: Dictionary[Vector3i, float] = {}  # corners cut down to their river's course before the fill (stream burning)
var _course_start: Dictionary[String, Vector3i] = {}  # river name -> the source corner its course starts from
var _course_chain: Dictionary[String, Array] = {}  # river name -> its course: the corridor chain on the raw surface
var _course_edge: Dictionary[Vector4i, bool] = {}  # edges on a burned course: a river may cross a spine there
var _course_mode := false  # routing a course (the pass before the fill): no uphill penalty, the course is burned later
var _routed_chain: Dictionary[String, Array] = {}  # river name -> its routed chain (a tributary joins the chain it names)
var burn_climbs: Array[String] = []  # burned steps that still climb (a tributary sitting above its trunk): none expected
var _lake_mode := false  # routing a lake: lakes cross the prealps at their gaps, so no crest cost
## The drawn curves (kilometres, with the pinned points) of each river and each ribbon lake: built by _build_drawn_lines.
var _river_curve: Array[PackedVector2Array] = []
var _river_pin: Array[Array] = []
var _lake_curve: Array[PackedVector2Array] = []
var _lake_pin: Array[Array] = []
## Each join: a tributary's end corner (or a river's start corner at a lake) that is a point of the curve it meets. Keys: corner,
## km, tributary (river index), host_kind ("river" or "lake") and host (its index). Checked by join_failures.
var join_anchors: Array[Dictionary] = []
## River ends that meet no other curve (the sea, a whole lake, the window edge): not joins, counted for the report.
var free_ends := 0


## Builds the water from the relief, the heights (land heights, sea depths) and the region's river and lake courses.
static func build(p_grid: WorldGrid, p_relief: WorldRelief, p_heights: WorldHeights, p_region: WorldRegion) -> WorldWater:
	var out := WorldWater.new()
	out.grid = p_grid
	out.relief = p_relief
	out.heights = p_heights
	out.region = p_region
	out._build_corners()
	out._build_zones()
	out._build_cities()
	out._build_city_corners()
	out._build_courses()
	out._burn_courses()
	out._build_flow()
	out._route_lakes()
	out._route_rivers()
	out._assign_words()
	out._build_shores()
	out._build_sea_bands()
	out._build_streams()
	out._build_drawn_lines()
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


## The hexes inside the region's lagoon ring and marsh zones (by the centre of each hex, in longitude and latitude).
func _build_zones() -> void:
	for hex: Vector2i in relief.levels.keys():
		var ll := grid.lonlat_of(grid.centre_km(hex))
		if region.lagoon.size() >= 3 and _in_ring(ll, region.lagoon):
			lagoon[hex] = true
		for mz: Dictionary in region.marsh_zones:
			var ring: PackedVector2Array = mz["ring"]
			if _in_ring(ll, ring):
				marsh_zone[hex] = true


## True when a point lies inside a closed ring of points (even-odd rule).
static func _in_ring(p: Vector2, ring: PackedVector2Array) -> bool:
	var inside := false
	var j := ring.size() - 1
	for i: int in ring.size():
		var a := ring[i]
		var b := ring[j]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside


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
			var h0 := _base(key)
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
			var fo := maxf(_base(o), fc)
			if not flow_height.has(o) or fo < flow_height[o]:
				flow_height[o] = fo
				_flood_parent[o] = c
				_heap_push(heap, [fo, o])
	for key: Vector3i in corner_set.keys():
		if flow_height.has(key):
			filled_m = maxf(filled_m, flow_height[key] - _base(key))


func _is_outlet(key: Vector3i) -> bool:
	return _touches_water(key) or _is_border(key)


## The height water sees at a corner: the drainage surface (see _build_flow).
func flow(key: Vector3i) -> float:
	return float(flow_height.get(key, _base(key)))


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
		if _through_partners.has(c):
			var city: String = _city_of_corner[c]
			var came_from := pc_of_key(key)
			var entered_from_outside: bool = not (came_from != NO_CORNER and str(_city_of_corner.get(came_from, "")) == city)
			if entered_from_outside and city_river.get(city, "") == _current_river and not lake_route:
				var ps: Array = _through_partners[c]
				for idx: int in ps.size():
					var partner: Vector3i = ps[idx]
					var jump := _skey(partner, c)
					var jc := dc + 0.3 * grid.hex_r_km + (0.0 if idx == 0 else THROUGH_BEND_COST * grid.hex_r_km)
					if jc < float(dist.get(jump, INF)):
						dist[jump] = jc
						prev_state[jump] = key
						state_corner[jump] = partner
						_heap_push(heap, [jc, jump])
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
			if strict and not allow_spine and not is_lake and not _course_edge.has(e) and _edge_on_spine(e):
				continue
			var nd := dc + _edge_cost(e, line, lake_route)
			if climb > DOWNHILL_TOLERANCE_M and not is_lake and not _course_mode:
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


## The six corners of each river city's hex, and the corners its river may leave by. A straight city (through) is crossed
## to the opposite corner (k + 3, preferred), or two apart (k + 2 or k + 4: the river bends inside the hex, the city still on
## both banks). A loop city is crossed two apart only (k + 2). A search that reaches a city corner from outside may cross
## the hex to a partner at no extra cost for the opposite corner (see THROUGH_BEND_COST).
func _build_city_corners() -> void:
	for city: String in city_hex.keys():
		var offsets: Array[int] = [3, 2, 4]
		if city_form[city] != "straight":
			offsets = [2]
		for k: int in 6:
			var a := _hex_corner(city_hex[city], k)
			if a == NO_CORNER:
				continue
			var partners: Array = []
			for off: int in offsets:
				var b := _hex_corner(city_hex[city], (k + off) % 6)
				if b != NO_CORNER:
					partners.append(b)
			if partners.is_empty():
				continue
			_city_of_corner[a] = city
			_through_partners[a] = partners


## True when a river may cross a river city's hex from corner a to corner b (a and b are partners).
func _is_through(a: Vector3i, b: Vector3i) -> bool:
	var ps: Array = _through_partners.get(a, [])
	return ps.has(b)


func _city_at(river_name: String, km: Vector2) -> String:
	var hex := grid.hex_of_km(km)
	for city: String in city_hex.keys():
		if city_river[city] == river_name and city_hex[city] == hex:
			return city
	return ""


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
			# Lecco gap cross the prealps). The chain is then clipped to the axis ends (LAKE_CLIP_HEX).
			_lake_mode = true
			var path := _clip_to_axis(_without_loops(_route(_nearest_corner(km[0], false),
				_nearest_corner(km[km.size() - 1], false), km, false, false)), km)
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


## The chain with its steps beyond the axis ends taken off: while the first (or last) step's midpoint lies more than
## LAKE_CLIP_HEX hex widths beyond the axis end, that corner goes. A chain keeps at least two corners.
func _clip_to_axis(path: Array[Vector3i], km: PackedVector2Array) -> Array[Vector3i]:
	var out := path.duplicate()
	var limit := LAKE_CLIP_HEX * grid.hex_w_km
	while out.size() > 2 and _beyond_axis(_corner_mid(out[0], out[1]), km, limit, true):
		out.remove_at(0)
	while out.size() > 2 and _beyond_axis(_corner_mid(out[out.size() - 2], out[out.size() - 1]), km, limit, false):
		out.remove_at(out.size() - 1)
	return out


## The midpoint of the edge between two corners that share one (the midpoint of their corner points when they do not).
func _corner_mid(a: Vector3i, b: Vector3i) -> Vector2:
	var e := _shared_edge(a, b)
	if e != NO_EDGE:
		return edge_mid_km(e)
	return (corner_pos(a) + corner_pos(b)) / 2.0


## True when a point lies beyond an end of the axis by more than limit: along the first segment before its start (at_start),
## or along the last segment past its end.
static func _beyond_axis(p: Vector2, km: PackedVector2Array, limit: float, at_start: bool) -> bool:
	var n := km.size()
	if n < 2:
		return false
	if at_start:
		var dir := (km[1] - km[0]).normalized()
		return (p - km[0]).dot(dir) < -limit
	var last := (km[n - 1] - km[n - 2]).normalized()
	return (p - km[n - 1]).dot(last) > limit


func _route_rivers() -> void:
	for rv: Dictionary in _rivers_in_order():
		_route_river(rv)


## The rivers in routing order: the largest class first, so the trunks are routed before the tributaries that join them.
func _rivers_in_order() -> Array[Dictionary]:
	var order: Array[Dictionary] = []
	for rv: Dictionary in region.rivers:
		order.append(rv)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["class"]) > int(b["class"]))
	return order


func _km_line(line: PackedVector2Array) -> PackedVector2Array:
	var km := PackedVector2Array()
	for p: Vector2 in line:
		km.append(grid.km_of(p.x, p.y))
	return km


## The height a corner has on the drainage surface before the fill: its burned height on a course, else its height.
func _base(key: Vector3i) -> float:
	if _burn.has(key):
		return _burn[key]
	return corner_height(key)


## The course of each authored river on the raw surface: the corridor chain nearest its line, with no downhill rule and
## spines allowed (a river crosses a spine only where its line does). The source is kept for the routing.
func _build_courses() -> void:
	_course_mode = true
	for rv: Dictionary in _rivers_in_order():
		var name := str(rv["name"])
		var line: PackedVector2Array = rv["line"]
		var km := _km_line(line)
		var start := _source_corner(km[0])
		_current_river = name
		var goals := _river_goals(start, km[km.size() - 1], _joined_corners(rv, true), _has_join(rv), _leaves(rv))
		var chain := _route_to_any(start, goals, km, false, false, true)
		_current_river = ""
		if chain.is_empty():
			continue  # no course: the routing reports the river
		_course_start[name] = start
		_course_chain[name] = chain
	_course_mode = false


## Stream burning (before the fill): along each course a corner gets the lowest height met so far on the course, minus
## BURN_STEP_M for each step from the source, so the course is always downhill. A corner that a larger river has already
## cut keeps its height (a confluence); the corners of this course above it are raised where they must be, so the course
## still runs down into it. The burned steps that still climb are reported (burn_climbs).
func _burn_courses() -> void:
	for rv: Dictionary in _rivers_in_order():
		var name := str(rv["name"])
		if not _course_chain.has(name):
			continue
		var chain: Array[Vector3i] = _course_chain[name]
		var n := chain.size()
		var fixed: Array[bool] = []
		var value: Array[float] = []
		var run := INF
		for i: int in n:
			var c := chain[i]
			if _burn.has(c):
				run = minf(run, _burn[c])
				fixed.append(true)
				value.append(_burn[c])
			else:
				run = minf(run, corner_height(c))
				fixed.append(false)
				value.append(run - BURN_STEP_M * i)
		for i: int in range(n - 2, -1, -1):
			if not fixed[i]:
				value[i] = maxf(value[i], value[i + 1] + BURN_STEP_M)
		for i: int in n:
			if not fixed[i]:
				_burn[chain[i]] = value[i]
		for i: int in n - 1:
			var e := _shared_edge(chain[i], chain[i + 1])
			if e != NO_EDGE:
				_course_edge[e] = true
	for rv: Dictionary in _rivers_in_order():
		var name := str(rv["name"])
		if not _course_chain.has(name):
			continue
		var chain: Array[Vector3i] = _course_chain[name]
		for i: int in chain.size() - 1:
			var climb := _base(chain[i + 1]) - _base(chain[i])
			if climb > 0.001:
				burn_climbs.append("%s step %d: %.0f m up" % [name, i, climb])


## The corners a river's route may end on. A river that leaves the window ends on the window's edge. A tributary (an authored
## join, `joins` in the region) ends on a corner of the river it names, within two hex widths of its last point (else the
## nearest corner of that river). Every other river has its own mouth: a corner touching the sea, a lagoon or a lake within
## MOUTH_REACH_HEX hex widths of its last point (else the nearest such corner). So no river joins another one by accident.
## River city corners are never an end.
func _river_goals(cur: Vector3i, last_p: Vector2, joinable: Dictionary[Vector3i, bool], has_join: bool,
		leaves: bool) -> Dictionary[Vector3i, bool]:
	var goals: Dictionary[Vector3i, bool] = {}
	if leaves or not relief.levels.has(grid.hex_of_km(last_p)):
		for key: Vector3i in corner_set.keys():
			if _is_border(key) and corner_pos(key).distance_to(last_p) <= 2.0 * grid.hex_w_km:
				goals[key] = true
		var edge_corner := _nearest_border_corner(last_p, cur)
		if edge_corner != NO_CORNER:
			goals[edge_corner] = true
	elif has_join:
		for key: Vector3i in joinable.keys():
			if key != cur and corner_pos(key).distance_to(last_p) <= 2.0 * grid.hex_w_km:
				goals[key] = true
		if goals.is_empty():
			var near := _nearest_of(joinable.keys(), last_p, cur)
			if near != NO_CORNER:
				goals[near] = true
	else:
		var reach := MOUTH_REACH_HEX * grid.hex_w_km
		var sea_keys: Array = []
		for key: Vector3i in corner_set.keys():
			if key == cur or _city_of_corner.has(key) or not _touches_water(key):
				continue
			sea_keys.append(key)
			if corner_pos(key).distance_to(last_p) <= reach:
				goals[key] = true
		if goals.is_empty():
			var mouth := _nearest_of(sea_keys, last_p, cur)
			if mouth != NO_CORNER:
				goals[mouth] = true
	return goals


## True when a river names the river it flows into (its authored join).
static func _has_join(rv: Dictionary) -> bool:
	return str(rv.get("joins", "")) != ""


## True when a river leaves the window by an edge (its authored `leaves`): it ends on the window's edge.
static func _leaves(rv: Dictionary) -> bool:
	return str(rv.get("leaves", "")) != ""


## The corners of the river a tributary joins: its course on the raw surface (courses true) or its routed chain.
func _joined_corners(rv: Dictionary, courses: bool) -> Dictionary[Vector3i, bool]:
	var out: Dictionary[Vector3i, bool] = {}
	var target := str(rv.get("joins", ""))
	if target == "":
		return out
	var chain: Array = _course_chain.get(target, []) if courses else _routed_chain.get(target, [])
	for c: Vector3i in chain:
		out[c] = true
	return out


## The corner of a list nearest a point, other than exclude (NO_CORNER for an empty list).
func _nearest_of(keys: Array, p: Vector2, exclude: Vector3i) -> Vector3i:
	var best := NO_CORNER
	var best_d := INF
	for key: Vector3i in keys:
		if key == exclude:
			continue
		var d := corner_pos(key).distance_to(p)
		if d < best_d:
			best_d = d
			best = key
	return best


func _route_river(rv: Dictionary) -> void:
	var name := str(rv["name"])
	var line: PackedVector2Array = rv["line"]
	var km := _km_line(line)
	var n := km.size()
	var chain: Array[Vector3i] = []
	_current_river = name
	# The source is the corner the course was burned from (_build_courses). The routing runs down the burned surface to the
	# river's end; river cities are crossed inside the search (see _build_city_corners).
	var cur: Vector3i = _course_start[name] if _course_start.has(name) else _source_corner(km[0])
	chain.append(cur)
	var goals := _river_goals(cur, km[n - 1], _joined_corners(rv, false), _has_join(rv), _leaves(rv))
	var tail := _leg(cur, goals, km, name)
	if tail.is_empty():
		route_failures.append("%s: no route to its end" % name)
	else:
		for c: Vector3i in tail.slice(1):
			chain.append(c)
	chain = _without_loops(chain)
	_routed_chain[name] = chain
	# Throughs that survive the loop cut are consecutive pairs of the chain.
	var throughs: Array[Vector2i] = []
	for i: int in chain.size() - 1:
		if _is_through(chain[i], chain[i + 1]):
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
		if lagoon.has(hex):
			sea_band[hex] = "lagoon"
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
		if network.has(c) or _touches_water(c) or _touches_city(c) or _touches_city(p):
			continue
		var e := _shared_edge(c, p)
		if e == NO_EDGE or river_edge.has(e) or lake_edge.has(e) or relief.crest_edges.has(e):
			continue
		if int(acc[c]) >= STREAM_MIN_CORNERS:
			stream_edge[e] = int(acc[c])
	stream_sinks = 0


## True when a corner touches a river city's hex. No stream starts there or runs along the city's six edges (04 section 3.6:
## none of them carries water, and the city's bridge is inside the hex).
func _touches_city(key: Vector3i) -> bool:
	for h: Vector2i in corner_hexes_of(key):
		for city: String in city_hex.keys():
			if city_hex[city] == h:
				return true
	return false


func _touches_water(key: Vector3i) -> bool:
	for h: Vector2i in corner_hexes_of(key):
		if _is_sea(h):
			return true
	return false


# ----- what the viewer and the tests read --------------------------------------------------------------------------


## Smoothing rounds of every drawn curve (rivers, lakes): the viewer and the join check use the same curve.
const DRAW_ROUNDS := 3


## The points a river is drawn through, in kilometres: the source, the midpoint of each step's edge, the centre of a
## river city's hex where the river crosses it, the joins of its tributaries and the mouth. river_pins says which are fixed.
func river_points_km(index: int) -> PackedVector2Array:
	return _river_curve[index]


## Which points of river_points_km are fixed: the two ends, each river city crossing and each join.
func river_pins(index: int) -> Array[bool]:
	var out: Array[bool] = []
	out.assign(_river_pin[index])
	return out


## The points of a ribbon lake's drawn curve, in kilometres (its edge midpoints and the joins of the rivers that meet it).
func lake_points_km(index: int) -> PackedVector2Array:
	return _lake_curve[index]


## Which points of lake_points_km are fixed: the two ends and each join.
func lake_pins(index: int) -> Array[bool]:
	var out: Array[bool] = []
	out.assign(_lake_pin[index])
	return out


## Chaikin corner cutting, a few rounds, for an open line. A point flagged in pins keeps its place (the ends, the river city
## crossings and the joins), so the curve passes through the points that are pinned. The viewer draws every curve with it.
static func smooth_line(points: PackedVector2Array, pins: Array[bool], rounds: int) -> PackedVector2Array:
	var pts := points
	var flags: Array[bool] = pins.duplicate()
	for r: int in rounds:
		var out := PackedVector2Array()
		var out_flags: Array[bool] = []
		var n := pts.size()
		if n < 3:
			break
		for i: int in n - 1:
			var a := pts[i]
			var b := pts[i + 1]
			if flags[i]:
				out.append(a)
				out_flags.append(true)
			else:
				out.append(a * 0.75 + b * 0.25)
				out_flags.append(false)
			if not flags[i + 1]:
				out.append(a * 0.25 + b * 0.75)
				out_flags.append(false)
		out.append(pts[n - 1])
		out_flags.append(true)
		pts = out
		flags = out_flags
	return pts


## Builds the drawn curves. A river is a polyline through its steps (edge midpoints, river city centres) from its source to
## its mouth. A ribbon lake is a polyline through its steps. Then each join is pinned into the curve it meets: a tributary's
## end corner becomes a point of the main river's curve (inserted at that corner), and a river that starts or ends on a
## lake's chain becomes a point of the lake's curve. So the tributary's line ends exactly on the main line, and the river
## meets the lake shore exactly: the corner is a vertex of both curves, so both pass through it.
func _build_drawn_lines() -> void:
	var r_pts: Array[Array] = []
	var r_pin: Array[Array] = []
	var r_cor: Array[Array] = []
	for i: int in rivers.size():
		var chain: Array[Vector3i] = rivers[i]["corners"]
		var steps: Array[Vector4i] = rivers[i]["steps"]
		var pts: Array[Vector2] = [corner_pos(chain[0])]
		var pin: Array[bool] = [true]
		var cor: Array[Vector3i] = [chain[0]]
		for j: int in steps.size():
			var e := steps[j]
			if e == NO_EDGE:
				pts.append(grid.centre_km(_city_hex_of_link(chain[j], chain[j + 1])))
				pin.append(true)
			else:
				pts.append(edge_mid_km(e))
				pin.append(false)
			cor.append(NO_CORNER)
		pts.append(corner_pos(chain[chain.size() - 1]))
		pin.append(true)
		cor.append(chain[chain.size() - 1])
		r_pts.append(pts)
		r_pin.append(pin)
		r_cor.append(cor)
	var l_pts: Array[Array] = []
	var l_pin: Array[Array] = []
	var l_cor: Array[Array] = []
	for i: int in lakes.size():
		var steps: Array[Vector4i] = lakes[i]["steps"]
		var pts: Array[Vector2] = []
		var pin: Array[bool] = []
		var cor: Array[Vector3i] = []
		for e: Vector4i in steps:
			pts.append(edge_mid_km(e))
			pin.append(false)
			cor.append(NO_CORNER)
		if not pin.is_empty():
			pin[0] = true
			pin[pin.size() - 1] = true
		l_pts.append(pts)
		l_pin.append(pin)
		l_cor.append(cor)
	# The joins: each end corner of a river that is a corner of another curve (a river, or a ribbon lake's chain).
	var inserts: Array[Dictionary] = []
	join_anchors.clear()
	free_ends = 0
	for t: int in rivers.size():
		var chain: Array[Vector3i] = rivers[t]["corners"]
		for c: Vector3i in [chain[0], chain[chain.size() - 1]]:
			var host := _host_of(c, t)
			if host.is_empty():
				free_ends += 1
				continue
			var kind := str(host["kind"])
			var idx := int(host["index"])
			var at := int(host["at"])
			join_anchors.append({"corner": c, "km": corner_pos(c), "tributary": t, "host_kind": kind, "host": idx})
			var host_size := (rivers[idx]["corners"] as Array).size() if kind == "river" else (lakes[idx]["corners"] as Array).size()
			# A river's own curve already starts and ends on its corners; a lake's curve starts on its first step's midpoint,
			# so a lake corner at either end is pinned too.
			if kind == "lake" or (at > 0 and at < host_size - 1):
				inserts.append({"kind": kind, "index": idx, "at": at, "corner": c})
	# Largest corner index first within a curve, so the earlier positions stay valid while inserting.
	inserts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a["kind"]) != str(b["kind"]):
			return str(a["kind"]) > str(b["kind"])
		if int(a["index"]) != int(b["index"]):
			return int(a["index"]) < int(b["index"])
		return int(a["at"]) > int(b["at"]))
	for ins: Dictionary in inserts:
		var idx := int(ins["index"])
		var at := int(ins["at"])
		var c: Vector3i = ins["corner"]
		var at_km := corner_pos(c)
		if str(ins["kind"]) == "river":
			# Entries are [source, step 0, ..., step N-1, mouth]: corner k sits between step k-1 and step k.
			(r_pts[idx] as Array).insert(at + 1, at_km)
			(r_pin[idx] as Array).insert(at + 1, true)
			(r_cor[idx] as Array).insert(at + 1, c)
		else:
			# Entries are the steps only: corner k sits before step k.
			(l_pts[idx] as Array).insert(at, at_km)
			(l_pin[idx] as Array).insert(at, true)
			(l_cor[idx] as Array).insert(at, c)
	_river_curve.clear()
	_river_pin.clear()
	_lake_curve.clear()
	_lake_pin.clear()
	for i: int in rivers.size():
		_river_curve.append(PackedVector2Array(r_pts[i]))
		_river_pin.append(r_pin[i])
	for i: int in lakes.size():
		_lake_curve.append(PackedVector2Array(l_pts[i]))
		_lake_pin.append(l_pin[i])


## The curve that a river end corner meets, other than river t itself: the river holding the corner (the highest class
## first), else a ribbon lake whose chain holds it. "at" is the corner's index in that chain (0 and the last index are the
## curve's own ends). Empty when no other curve holds the corner.
func _host_of(c: Vector3i, t: int) -> Dictionary:
	var best := {}
	var best_class := -1
	for r: int in rivers.size():
		if r == t:
			continue
		var chain: Array[Vector3i] = rivers[r]["corners"]
		var at := chain.find(c)
		if at >= 0 and int(rivers[r]["class"]) > best_class:
			best_class = int(rivers[r]["class"])
			best = {"kind": "river", "index": r, "at": at}
	if not best.is_empty():
		return best
	for k: int in lakes.size():
		var corners: Array[Vector3i] = lakes[k]["corners"]
		var at := corners.find(c)
		if at >= 0:
			return {"kind": "lake", "index": k, "at": at}
	return best


## The join check (the renderer's proof, kept in core so the tests run it): every join point is on the smoothed drawn curve of
## the tributary and on the smoothed curve of the river or lake it meets, within 0.01 km. Returns one line per failure.
func join_failures() -> Array[String]:
	var out: Array[String] = []
	for a: Dictionary in join_anchors:
		var km: Vector2 = a["km"]
		var t: int = a["tributary"]
		var host_kind := str(a["host_kind"])
		var host: int = a["host"]
		var mine := smooth_line(river_points_km(t), river_pins(t), DRAW_ROUNDS)
		var theirs: PackedVector2Array
		if host_kind == "river":
			theirs = smooth_line(river_points_km(host), river_pins(host), DRAW_ROUNDS)
		else:
			theirs = smooth_line(lake_points_km(host), lake_pins(host), DRAW_ROUNDS)
		if _distance_to_curve(km, mine) > 0.01:
			out.append("%s: the join at %s is off the tributary's line" % [rivers[t]["name"], str(a["corner"])])
		if _distance_to_curve(km, theirs) > 0.01:
			out.append("%s: the join at %s is off the line it meets" % [rivers[t]["name"], str(a["corner"])])
	return out


static func _distance_to_curve(p: Vector2, curve: PackedVector2Array) -> float:
	var best := INF
	for i: int in curve.size():
		best = minf(best, p.distance_to(curve[i]))
	return best


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
		"burned_corners": _burn.size(),
		"burn_climbs": burn_climbs.size(),
		"joins": join_anchors.size(),
		"join_failures": join_failures().size(),
		"free_ends": free_ends,
	}
