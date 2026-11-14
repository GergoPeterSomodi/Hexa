## The water of the map prototype region (step 3): the rivers as chains of hex edges snapped from the authored courses,
## the lakes, the shores, the sea depth bands, the river cities, and the generated streams. Pure: no files, no engine.
##
## The model (docs/design/map/04-wfc-model.md sections 3.1 to 3.3, 3.6): a river runs along hex EDGES from CORNER to
## CORNER. A corner is the meeting point of three hexes, named by those three hexes. Each river step is one edge. A
## river city (3.6) is crossed through its hex: the river enters at one corner of the city hex and leaves at another
## (straight: three corners round; loop: two corners round), and none of the six edges of the city hex carries water.
## Corner words (3.3): source (0 in, 1 out), run (1, 1), join (2, 1), mouth (1, 0: only at the sea, a lake or the edge of
## the map), city_in and city_out (the two corners of a river city's hex).
class_name WorldWater
extends RefCounted

const NO_CORNER := Vector3i(-1, -1, -1)
const NO_EDGE := Vector4i(-1, -1, -1, -1)
## A lake at least this fraction of a hex wide is a whole water hex (decision D3); narrower lakes are ribbons on edges.
const LAKE_WHOLE_FRACTION := 0.6
## A river may not climb more than this from one corner to the next (metres). Checked and reported, not forced.
const DOWNHILL_TOLERANCE_M := 60.0
## Edge costs, in multiples of a hex's circumradius. Crests are walls: a river crosses one only at great cost.
const SEA_COST := 20.0
const CREST_COST := 100.0
## Climbing along a river costs extra: one hex circumradius per UPHILL_STEP_M climbed beyond the tolerance.
const UPHILL_STEP_M := 50.0
## Generated streams are drawn where this many corners drain through an edge.
const STREAM_MIN_CORNERS := 6

var grid: WorldGrid
var relief: WorldRelief
var heights: WorldHeights
var region: WorldRegion
var corner_set: Dictionary[Vector3i, bool] = {}  # every corner whose three hexes are in the grid
var corner_word: Dictionary[Vector3i, String] = {}  # corners of a river or lake: source, run, join, mouth, city_in, city_out
var network: Dictionary[Vector3i, bool] = {}  # corners that any river or lake passes
var rivers: Array[Dictionary] = []  # name, class, corners (Array[Vector3i]), steps (Array[Vector4i]), throughs (Array[Vector2i])
var lakes: Array[Dictionary] = []  # name, width, whole (bool), corners, steps, hexes (whole water hexes)
var river_edge: Dictionary[Vector4i, int] = {}  # edge -> index of the river that uses it
var lake_edge: Dictionary[Vector4i, bool] = {}
var lake_hex: Dictionary[Vector2i, bool] = {}  # whole water hexes of big lakes (drawn like the sea)
var shore_edge: Dictionary[Vector4i, String] = {}  # land against sea or water: cliff (level 3 or higher), beach or lake
var stream_edge: Dictionary[Vector4i, int] = {}  # generated streams: edge -> corners draining through it
var sea_band: Dictionary[Vector2i, String] = {}  # sea hex -> shelf, sea, deep ("" when ETOPO has no sea cell there)
var city_hex: Dictionary[String, Vector2i] = {}  # river city -> its hex
var city_river: Dictionary[String, String] = {}  # river city -> the river through it
var city_form: Dictionary[String, String] = {}  # river city -> straight or loop
var downhill_violations: Array[String] = []  # river steps that climb more than the tolerance
var unresolved_ends: Array[String] = []  # river ends that are not a mouth (sea, lake, map edge)
var route_failures: Array[String] = []  # authored river or lake vertices the router could not reach
var crest_steps: Array[String] = []  # river steps on a crest edge (none is named as a gorge in the region data)
var stream_sinks: int = 0  # generated stream sources with no lower corner: basins
var _blocked: Dictionary[Vector4i, bool] = {}  # edges no river may use (the six edges of each river city hex)


## Builds the water from the relief, the heights (land heights, sea depths) and the region's river and lake courses.
static func build(p_grid: WorldGrid, p_relief: WorldRelief, p_heights: WorldHeights, p_region: WorldRegion) -> WorldWater:
	var out := WorldWater.new()
	out.grid = p_grid
	out.relief = p_relief
	out.heights = p_heights
	out.region = p_region
	out._build_corners()
	out._build_cities()
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


static func _hex_less(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


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


## The three hexes of a corner, in the order of their codes.
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


func corner_height(key: Vector3i) -> float:
	var total := 0.0
	for h: Vector2i in corner_hexes_of(key):
		if relief.level_at(h) != ReliefLevels.SEA and not lake_hex.has(h):
			total += float(heights.height_m.get(h, 0.0))
	return total / 3.0


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


# ----- routing ------------------------------------------------------------------------------------------------------


func _edge_cost(edge: Vector4i, line: PackedVector2Array) -> float:
	var a := Vector2i(edge.x, edge.y)
	var b := Vector2i(edge.z, edge.w)
	var base := grid.hex_r_km
	if lake_edge.has(edge):
		return base * 0.5
	var mid := (grid.centre_km(a) + grid.centre_km(b)) / 2.0
	var off := _distance_to_line(mid, line)
	var cost := base * (1.0 + 8.0 * maxf(0.0, off - 0.35 * grid.hex_w_km) / grid.hex_w_km)
	if relief.crest_edges.has(edge):
		cost += CREST_COST * base
	if _is_sea(a) or _is_sea(b):
		cost += SEA_COST * base
	return cost


func _is_sea(h: Vector2i) -> bool:
	return relief.level_at(h) == ReliefLevels.SEA or lake_hex.has(h)


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


## The cheapest chain of corners from start to goal (both included), or an empty array when there is none.
func _route(start: Vector3i, goal: Vector3i, line: PackedVector2Array) -> Array[Vector3i]:
	var dist: Dictionary[Vector3i, float] = {start: 0.0}
	var prev: Dictionary[Vector3i, Vector3i] = {}
	var heap: Array = []
	_heap_push(heap, [0.0, start])
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var c: Vector3i = top[1]
		var dc: float = top[0]
		if dc > float(dist.get(c, INF)):
			continue
		if c == goal:
			break
		for e: Vector4i in _corner_edges(c):
			if _blocked.has(e):
				continue
			var other := _other_corner(e, c)
			if other == NO_CORNER:
				continue
			var nd := dc + _edge_cost(e, line)
			var climb := corner_height(other) - corner_height(c)
			if climb > DOWNHILL_TOLERANCE_M:
				nd += grid.hex_r_km * climb / UPHILL_STEP_M
			if nd < float(dist.get(other, INF)):
				dist[other] = nd
				prev[other] = c
				_heap_push(heap, [nd, other])
	var path: Array[Vector3i] = []
	if not dist.has(goal):
		return path
	path.append(goal)
	var cur := goal
	while cur != start:
		cur = prev[cur]
		path.push_front(cur)
	return path


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


func _city_at(river_name: String, km: Vector2) -> String:
	var hex := grid.hex_of_km(km)
	for city: String in city_hex.keys():
		if city_river[city] == river_name and city_hex[city] == hex:
			return city
	return ""


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


## The two corners a river uses to cross a river city's hex, from corner k: straight across (k + 3) or in a loop (k + 2).
func _through_corners(city: String, k: int) -> Array[Vector3i]:
	var far := 3 if city_form[city] == "straight" else 2
	var a := _hex_corner(city_hex[city], k)
	var b := _hex_corner(city_hex[city], (k + far) % 6)
	return [a, b]


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
			var path := _route(_nearest_corner(km[0], false), _nearest_corner(km[km.size() - 1], false), km)
			if path.is_empty():
				route_failures.append("lake %s" % lk["name"])
			for i: int in path.size() - 1:
				var e := _shared_edge(path[i], path[i + 1])
				steps.append(e)
				lake_edge[e] = true
				network[path[i]] = true
			if not path.is_empty():
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
	var chain: Array[Vector3i] = []
	var throughs: Array[Vector2i] = []
	var cur := _nearest_corner(km[0], false)
	chain.append(cur)
	for i: int in range(1, km.size()):
		var p := km[i]
		var last := i == km.size() - 1
		if not relief.levels.has(grid.hex_of_km(p)):
			# The river leaves the map: it runs to the nearest corner on the map edge, which is its mouth, and stops.
			var edge_goal := _nearest_border_corner(p, cur)
			if edge_goal != NO_CORNER:
				var out_path := _route(cur, edge_goal, km)
				for c: Vector3i in out_path.slice(1):
					chain.append(c)
			break
		var city := _city_at(name, p)
		if city != "" and not last:
			var best_cost := INF
			var best: Array[Vector3i] = []
			var best_b := NO_CORNER
			for k: int in 6:
				var pair := _through_corners(city, k)
				if pair[0] == NO_CORNER or pair[1] == NO_CORNER:
					continue
				var path := _route(cur, pair[0], km)
				if path.is_empty():
					continue
				var cost := float(path.size()) + corner_pos(pair[1]).distance_to(km[i + 1]) / grid.hex_r_km
				if cost < best_cost:
					best_cost = cost
					best = path
					best_b = pair[1]
			if best.is_empty():
				route_failures.append("%s at %s (river city)" % [name, city])
				continue
			for c: Vector3i in best.slice(1):
				chain.append(c)
			throughs.append(Vector2i(chain.size() - 1, chain.size()))
			chain.append(best_b)
			cur = best_b
			continue
		var goal := _nearest_corner(p, false, cur if last else NO_CORNER)
		if last and not is_trunk:
			var on_network := _nearest_corner(p, true, cur)
			if on_network != NO_CORNER and corner_pos(on_network).distance_to(p) <= grid.hex_w_km:
				goal = on_network
		var seg := _route(cur, goal, km)
		if seg.is_empty():
			route_failures.append("%s at vertex %d" % [name, i])
			continue
		for c: Vector3i in seg.slice(1):
			chain.append(c)
		cur = goal
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
			crest_steps.append("%s at %s-%s" % [name, Vector2i(e.x, e.y), Vector2i(e.z, e.w)])
	for c: Vector3i in chain:
		network[c] = true
	for i: int in steps.size():
		if steps[i] == NO_EDGE:
			continue
		var climb := corner_height(chain[i + 1]) - corner_height(chain[i])
		if climb > DOWNHILL_TOLERANCE_M:
			downhill_violations.append("%s step %d: %.0f m up" % [name, i, climb])
	rivers.append({"name": name, "class": int(rv["class"]), "corners": chain, "steps": steps, "throughs": throughs})


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
		if corner_word.get(last, "") == "mouth" and not _is_mouth(last):
			unresolved_ends.append(str(rv["name"]))


## A mouth corner touches the sea, a lake or the edge of the grid.
func _is_mouth(key: Vector3i) -> bool:
	for h: Vector2i in corner_hexes_of(key):
		if _is_sea(h):
			return true
		for n: Vector2i in grid.neighbours(h):
			if not relief.levels.has(n):
				return true
	return false


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


func _build_sea_bands() -> void:
	for hex: Vector2i in relief.levels.keys():
		if relief.level_at(hex) != ReliefLevels.SEA or lake_hex.has(hex):
			continue
		var depth := float(heights.depth_m.get(hex, 0.0))
		var band := "deep"
		if depth == 0.0:
			band = ""
		elif depth >= -200.0:
			band = "shelf"
		elif depth >= -2000.0:
			band = "sea"
		sea_band[hex] = band


func _build_streams() -> void:
	var height_of: Dictionary[Vector3i, float] = {}
	var sources: Array[Vector3i] = []
	for key: Vector3i in corner_set.keys():
		height_of[key] = corner_height(key)
		if network.has(key) or _touches_water(key):
			continue
		sources.append(key)
	sources.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if height_of[a] != height_of[b]:
			return height_of[a] > height_of[b]
		return _corner_less(a, b))
	var acc: Dictionary[Vector3i, int] = {}
	for key: Vector3i in sources:
		acc[key] = int(acc.get(key, 0)) + 1
		var best := NO_CORNER
		var best_edge := NO_EDGE
		var best_h: float = height_of[key]
		for e: Vector4i in _corner_edges(key):
			if relief.crest_edges.has(e) or river_edge.has(e) or lake_edge.has(e):
				continue
			var other := _other_corner(e, key)
			if other == NO_CORNER:
				continue
			if height_of[other] < best_h:
				best_h = height_of[other]
				best = other
				best_edge = e
		if best == NO_CORNER:
			stream_sinks += 1
			continue
		acc[best] = int(acc.get(best, 0)) + int(acc[key])
		if int(acc[key]) >= STREAM_MIN_CORNERS:
			stream_edge[best_edge] = int(acc[key])


func _touches_water(key: Vector3i) -> bool:
	for h: Vector2i in corner_hexes_of(key):
		if _is_sea(h):
			return true
	return false


# ----- what the viewer and the tests read --------------------------------------------------------------------------


## The points a river is drawn through, in kilometres: the corners' centre and the midpoints of its edges, and the
## centre of a river city's hex where the river crosses it.
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


func _city_hex_of_link(a: Vector3i, b: Vector3i) -> Vector2i:
	var hb := corner_hexes_of(b)
	for h: Vector2i in corner_hexes_of(a):
		if hb.has(h):
			return h
	return Vector2i.ZERO


## The midpoint of an edge in kilometres.
func edge_mid_km(e: Vector4i) -> Vector2:
	return (grid.centre_km(Vector2i(e.x, e.y)) + grid.centre_km(Vector2i(e.z, e.w))) / 2.0


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
		"unresolved_ends": unresolved_ends.size(),
		"route_failures": route_failures.size(),
		"crest_steps": crest_steps.size(),
	}
