## The relief of the map prototype region on the 28 km grid (step 2): the level of every hex from its height, the crest
## edges where a range's spine runs between two hexes that are both at crest height, and the saddle of each named
## pass (docs/design/map/01-terrain-and-relief.md sections 3.2 and 2.1; 04-wfc-model.md section 3).
##
## Crest edge: the spine of a range crosses the edge (the segment between the two hex centres crosses an odd number of
## spine segments, the same test as the Python ridge walls), and both hexes are at or above the range's crest level.
## A spine crossing an edge whose hex is lower is a gap, reported and not drawn as a crest.
## Pass: the crest hex nearest to the pass is its saddle; the crest edges of the saddle carry the pass. A pass with no
## crest hex near it (a low pass such as Giovi) gets the nearest land hex and no pass edges.
## Pure: no files, no engine calls.
class_name WorldRelief
extends RefCounted

## A pass whose nearest crest hex is farther than this many hex widths gets no crest saddle.
const PASS_CREST_RANGE_HEXES := 1.0

var grid: WorldGrid
var levels: Dictionary[Vector2i, int] = {}  # every hex of the heights file: 0 sea, 1 to 6 land
var crest_edges: Dictionary[Vector4i, int] = {}  # edge key -> index of the range in region.ranges
var pass_edges: Dictionary[Vector4i, int] = {}  # edge key -> index of the pass in region.passes (a subset of crest_edges)
var pass_hex: Dictionary[int, Vector2i] = {}  # pass index -> its saddle hex (or the nearest land hex)
var pass_km: Dictionary[int, float] = {}  # pass index -> distance in km from the pass to its saddle hex centre
var pass_has_crest: Dictionary[int, bool] = {}  # pass index -> its saddle hex carries crest edges
var gaps: Array[String] = []  # spine crossings on edges with a hex below the range's crest level
var dangling_corners: Array[String] = []  # corners where exactly one crest edge meets: ends of a crest chain


## The relief of the whole region, from the grid, the heights and the region's ranges and passes.
static func build(grid: WorldGrid, heights: WorldHeights, region: WorldRegion) -> WorldRelief:
	var out := WorldRelief.new()
	out.grid = grid
	for hex: Vector2i in heights.land.keys():
		if heights.is_land(hex):
			out.levels[hex] = ReliefLevels.level_of(heights.height_m[hex])
		else:
			out.levels[hex] = ReliefLevels.SEA
	out._find_crests(region)
	out._find_passes(region)
	out._find_dangling_corners()
	return out


func level_at(hex: Vector2i) -> int:
	return int(levels.get(hex, ReliefLevels.SEA))


## Counts for the report: hexes per level (index 0 is sea), crest edges, pass edges, passes with a crest saddle, gaps.
func summary(pass_count: int) -> Dictionary:
	var hist: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for hex: Vector2i in levels.keys():
		hist[level_at(hex)] += 1
	var with_crest := 0
	for p: int in pass_has_crest.keys():
		if pass_has_crest[p]:
			with_crest += 1
	return {
		"hexes": levels.size(),
		"levels": hist,
		"crest_edges": crest_edges.size(),
		"pass_edges": pass_edges.size(),
		"passes": pass_count,
		"passes_with_crest": with_crest,
		"gaps": gaps.size(),
		"dangling_corners": dangling_corners.size(),
	}


func _find_crests(region: WorldRegion) -> void:
	var segs: Array[Array] = []  # each: [start km, end km, range index]
	for i: int in region.ranges.size():
		var line: PackedVector2Array = region.ranges[i]["line"]
		for k: int in line.size() - 1:
			segs.append([grid.km_of(line[k].x, line[k].y), grid.km_of(line[k + 1].x, line[k + 1].y), i])
	var range_count := region.ranges.size()
	var done: Dictionary[Vector4i, bool] = {}
	for hex: Vector2i in levels.keys():
		# Each edge is seen from exactly one of its two hexes when only directions 0, 1 and 2 are walked.
		for d: int in 3:
			var nb := grid.neighbour(hex, d)
			if not levels.has(nb):
				continue
			var key := WorldGrid.edge_key(hex, nb)
			if done.has(key):
				continue
			done[key] = true
			var pa := grid.centre_km(hex)
			var pb := grid.centre_km(nb)
			var counts := PackedInt32Array()
			counts.resize(range_count)
			counts.fill(0)
			for s: Array in segs:
				if _crosses(pa, pb, s[0], s[1]):
					counts[int(s[2])] += 1
			for i: int in range_count:
				if counts[i] % 2 == 0:
					continue
				var crest_level: int = region.ranges[i]["crest_level"]
				var lower: int = mini(level_at(hex), level_at(nb))
				if lower >= crest_level:
					if not crest_edges.has(key):
						crest_edges[key] = i
				else:
					gaps.append("%s at %s-%s (level %d below crest %d)" % [
						region.ranges[i]["name"], hex, nb, lower, crest_level])
				break


func _find_passes(region: WorldRegion) -> void:
	var crest_hexes: Dictionary[Vector2i, bool] = {}
	for key: Vector4i in crest_edges.keys():
		for h: Vector2i in WorldGrid.edge_hexes(key):
			crest_hexes[h] = true
	var limit := PASS_CREST_RANGE_HEXES * grid.hex_w_km
	for p: int in region.passes.size():
		var lonlat: Vector2 = region.passes[p]["pos"]
		var pos := grid.km_of(lonlat.x, lonlat.y)
		var best := Vector2i.ZERO
		var best_km := INF
		for h: Vector2i in crest_hexes.keys():
			var dist := grid.centre_km(h).distance_to(pos)
			if dist < best_km:
				best_km = dist
				best = h
		var crest := best_km <= limit
		if not crest:
			best_km = INF
			for h: Vector2i in levels.keys():
				if level_at(h) == ReliefLevels.SEA:
					continue
				var dist := grid.centre_km(h).distance_to(pos)
				if dist < best_km:
					best_km = dist
					best = h
		pass_hex[p] = best
		pass_km[p] = best_km
		pass_has_crest[p] = crest
		if crest:
			for d: int in 6:
				var key := WorldGrid.edge_key(best, grid.neighbour(best, d))
				if crest_edges.has(key):
					pass_edges[key] = p


func _find_dangling_corners() -> void:
	var seen: Dictionary[String, bool] = {}
	for key: Vector4i in crest_edges.keys():
		var pair := WorldGrid.edge_hexes(key)
		var a := pair[0]
		var b := pair[1]
		var b_nb := grid.neighbours(b)
		for c: Vector2i in grid.neighbours(a):
			if c == b or not b_nb.has(c) or not levels.has(c):
				continue
			var trio_key := _trio_key(a, b, c)
			if seen.has(trio_key):
				continue
			seen[trio_key] = true
			var count := 0
			for e: Vector4i in [WorldGrid.edge_key(a, b), WorldGrid.edge_key(a, c), WorldGrid.edge_key(b, c)]:
				if crest_edges.has(e):
					count += 1
			if count == 1:
				dangling_corners.append(trio_key)


static func _trio_key(a: Vector2i, b: Vector2i, c: Vector2i) -> String:
	var hexes: Array[Vector2i] = [a, b, c]
	hexes.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		return p.y < q.y or (p.y == q.y and p.x < q.x))
	return "%d,%d|%d,%d|%d,%d" % [hexes[0].x, hexes[0].y, hexes[1].x, hexes[1].y, hexes[2].x, hexes[2].y]


## True when segment a-b properly crosses segment c-d.
static func _crosses(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var d1 := _cross(b - a, c - a)
	var d2 := _cross(b - a, d - a)
	var d3 := _cross(d - c, a - c)
	var d4 := _cross(d - c, b - c)
	return d1 * d2 < 0.0 and d3 * d4 < 0.0


static func _cross(u: Vector2, v: Vector2) -> float:
	return u.x * v.y - u.y * v.x
