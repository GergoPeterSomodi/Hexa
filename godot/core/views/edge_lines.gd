## Rivers, streams and roads as plain lines for the map view (docs/architecture/m1-build-spec.md, section 6): the
## data says which edges carry what; this turns it into smooth point lists in map px. No nodes, no luck: the same
## data gives the same lines.
##
## A line is a Dictionary: {kind ("river", "stream", "road", "track"), points (PackedVector2Array, map px), width (px),
## rank (the river's class or the road's quality)}. A piece cut out by `cut` may also have `before` and `after`.
class_name EdgeLines
extends RefCounted

const RIVER_WIDTH: Array[float] = [0.0, 3.4, 4.6, 6.5]  # by class 1 to 3 (the style frame's)
const STREAM_WIDTH := 2.0
const ROAD_WIDTH: Array[float] = [0.0, 1.3, 2.5, 3.4]  # by quality 1 to 3; quality 1 is a track
const ROAD_SWING := 2.2  # px a road wanders either side of its straight run
const RIVER_STEP := 4.4  # px between a river's points after smoothing
const MEANDER := 2.4  # px a river swings either side of its edge
const CHUNK := 32  # cells a side of one chunk of lines (one mesh each)


## The chunk (32 x 32 cells) a hex belongs to.
static func chunk_of(hex: Vector2i) -> Vector2i:
	return Vector2i(floori(float(hex.x) / CHUNK), floori(float(hex.y) / CHUNK))


## The hex whose middle is nearest to a point of the map (the hex under it).
static func hex_of_point(px: Vector2) -> Vector2i:
	var row0 := roundi((px.y - float(MapTiles.CELL.y) / 2.0) / MapTiles.ROW)
	var best := Vector2i.ZERO
	var best_d := INF
	for row: int in range(row0 - 1, row0 + 2):
		var shift := 0.5 * float(row & 1)
		var col0 := floori(px.x / MapTiles.CELL.x - 0.5 - shift)
		for col: int in range(col0, col0 + 2):
			var d := px.distance_squared_to(MapTiles.cell_centre(Vector2i(col, row)))
			if d < best_d:
				best_d = d
				best = Vector2i(col, row)
	return best


static func chunk_of_point(px: Vector2) -> Vector2i:
	return chunk_of(hex_of_point(px))


## Cuts lines where they leave a chunk. Returns {chunk: Array of lines}. A piece belongs to the chunk of the hex its
## first point lies in, and runs on to the first point of the next chunk, so neighbouring pieces share that point. Each
## piece also carries `before` and `after` (the points either side of it, when there are some): the drawer sets the
## stroke square to the run through the shared point from both sides, so the pieces meet without a gap or a seam.
static func cut(lines: Array[Dictionary]) -> Dictionary[Vector2i, Array]:
	var out: Dictionary[Vector2i, Array] = {}
	for line: Dictionary in lines:
		var points: PackedVector2Array = line["points"]
		var count := points.size()
		if count < 2:
			continue
		var start := 0
		var here := chunk_of_point(points[0])
		for i: int in range(1, count):
			var there := chunk_of_point(points[i])
			if there != here:
				_emit_piece(out, here, line, start, i)
				start = i
				here = there
		_emit_piece(out, here, line, start, count - 1)
	return out


static func _emit_piece(out: Dictionary[Vector2i, Array], chunk: Vector2i, line: Dictionary, first: int, last: int) -> void:
	var points: PackedVector2Array = line["points"]
	var piece := line.duplicate()
	piece["points"] = points.slice(first, last + 1)
	if first > 0:
		piece["before"] = points[first - 1]
	if last < points.size() - 1:
		piece["after"] = points[last + 1]
	if not out.has(chunk):
		out[chunk] = []
	out[chunk].append(piece)


## Corner cutting (Chaikin): each round replaces every corner by two points a quarter along its sides.
static func smooth(points: PackedVector2Array, rounds: int) -> PackedVector2Array:
	var pts := points
	for _i: int in rounds:
		if pts.size() < 3:
			break
		var out := PackedVector2Array([pts[0]])
		for i: int in pts.size() - 1:
			out.append(pts[i].lerp(pts[i + 1], 0.25))
			out.append(pts[i].lerp(pts[i + 1], 0.75))
		out.append(pts[pts.size() - 1])
		pts = out
	return pts


## The same line with a point every `step` px (the two ends kept).
static func resample(points: PackedVector2Array, step: float) -> PackedVector2Array:
	if points.size() < 2:
		return points
	var out := PackedVector2Array([points[0]])
	var carried := 0.0
	for i: int in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var d := a.distance_to(b)
		if d <= 0.0:
			continue
		var t := step - carried
		while t <= d:
			out.append(a.lerp(b, t / d))
			t += step
		carried = fmod(carried + d, step)
	if out[out.size() - 1].distance_to(points[points.size() - 1]) > step * 0.3:
		out.append(points[points.size() - 1])
	return out


## A river: its edge line smoothed, with a slow meander that is the same every time for the same `phase`.
static func river(edge_points: PackedVector2Array, river_class: int, phase: float) -> Dictionary:
	var pts := resample(smooth(edge_points, 3), RIVER_STEP)
	var out := PackedVector2Array()
	for i: int in pts.size():
		if i == 0 or i == pts.size() - 1:
			out.append(pts[i])
			continue
		var along := (pts[i + 1] - pts[i - 1]).normalized()
		var side := Vector2(-along.y, along.x)
		var swing := sin(float(i) * 0.55 + phase) * 0.54 + sin(float(i) * 0.21 + phase * 2.0) * 0.46
		out.append(pts[i] + side * swing * MEANDER)
	return {"kind": "river", "points": out, "width": RIVER_WIDTH[clampi(river_class, 1, 3)], "rank": river_class}


## A stream on one edge: from corner to corner, bowed a little.
static func stream(corner_a: Vector2, corner_b: Vector2) -> Dictionary:
	var mid := (corner_a + corner_b) / 2.0 + Vector2(4.0, 0.0)
	var pts := resample(smooth(PackedVector2Array([corner_a, mid, corner_b]), 3), RIVER_STEP)
	return {"kind": "stream", "points": pts, "width": STREAM_WIDTH, "rank": 0}


## Roads: `steps` are the road's hex-to-hex steps as [from, to, quality] (each edge once), `centres` gives the middle
## of a hex in map px. Steps are joined into runs of one quality between junctions, drawn through the middles of the
## hexes and smoothed, so a road bends through a hex instead of turning on a point.
static func roads(steps: Array[Array], centres: Callable) -> Array[Dictionary]:
	var links: Dictionary[Vector2i, Array] = {}
	for n: int in steps.size():
		var step: Array = steps[n]
		for end: int in 2:
			var hex: Vector2i = step[end]
			if not links.has(hex):
				links[hex] = []
			links[hex].append(n)
	var used := PackedByteArray()
	used.resize(steps.size())
	var out: Array[Dictionary] = []
	for n: int in steps.size():
		if used[n] == 1:
			continue
		var first: Array = steps[n]
		var quality: int = first[2]
		used[n] = 1
		var chain: Array[Vector2i] = [first[0], first[1]]
		for side: int in 2:
			while true:
				var tip: Vector2i = chain[chain.size() - 1] if side == 0 else chain[0]
				var next := _only_way_on(tip, links[tip], steps, used, quality)
				if next < 0:
					break
				used[next] = 1
				var step: Array = steps[next]
				var other: Vector2i = step[1] if step[0] == tip else step[0]
				if side == 0:
					chain.append(other)
				else:
					chain.insert(0, other)
		out.append(road_line(chain, quality, centres))
	return out


## One road run: the hexes it passes in order, drawn through their middles and smoothed (see `roads`).
static func road_line(chain: Array[Vector2i], quality: int, centres: Callable) -> Dictionary:
	var pts := PackedVector2Array()
	for hex: Vector2i in chain:
		var at: Vector2 = centres.call(hex)
		pts.append(at)
	var line := resample(smooth(pts, 3), 3.0)
	var phase := float(posmod(chain[0].x * 7 + chain[0].y * 13, 17))
	for i: int in range(1, line.size() - 1):
		var along := (line[i + 1] - line[i - 1]).normalized()
		var ease := minf(1.0, float(mini(i, line.size() - 1 - i)) / 8.0)  # the two ends stay on their hexes
		line[i] += Vector2(-along.y, along.x) * sin(float(i) * 0.19 + phase) * ROAD_SWING * ease
	return {"kind": "road" if quality >= 2 else "track", "points": line,
		"width": ROAD_WIDTH[clampi(quality, 1, 3)], "rank": quality}


## The one unused step of the same quality that goes on from a hex, or -1 at a junction, an end or a change of
## quality (a run stops there).
static func _only_way_on(_hex: Vector2i, here: Array, steps: Array[Array], used: PackedByteArray, quality: int) -> int:
	if here.size() != 2:
		return -1
	for entry: Variant in here:
		var n: int = entry
		var step: Array = steps[n]
		var q: int = step[2]
		if used[n] == 0 and q == quality:
			return n
	return -1


# ---- The lines of a chunk, read from MapData (docs/architecture/m1-build-spec.md section 6) ----


## The lines of one chunk (32 x 32 cells): the pieces `cut` gives that chunk when the whole map's lines are cut, built
## without building the whole map. A river is the drawn course in MapData.rivers (phase from its index), a stream is
## one edge, a road is a run of road edges of one quality between junctions, built from the edge facts of the map as
## `roads` would build it from the list of all steps (every edge once, in edge-index order). Only the runs that come
## within a hex of the chunk are built, whole, then cut. `_state` is for the living roads of M3; M1 draws the
## starting network of the map. A road change can reach other chunks than the changed hex's: rebuild the chunks
## `chunks_of_run` names.
static func for_chunk(map: MapData, _state: MapState, chunk: Vector2i) -> Array[Dictionary]:
	var low := chunk * CHUNK - Vector2i.ONE
	var high := (chunk + Vector2i.ONE) * CHUNK
	var lines: Array[Dictionary] = []
	lines.append_array(_rivers_near(map, chunk))
	lines.append_array(_streams_between(map, low, high))
	for run: Dictionary in _road_runs_between(map, low, high):
		var chain: Array[Vector2i] = []
		chain.assign(run["chain"])
		lines.append(road_line(chain, int(run["quality"]), MapTiles.cell_centre))
	var pieces: Array[Dictionary] = []
	pieces.assign(cut(lines).get(chunk, []))
	return pieces


## The chunks to rebuild when a road is laid or taken up on an edge of `hex`: every chunk the road run through the hex
## has a hex in, each with its eight neighbours (a piece of a line can lie in a chunk its hexes are not in).
static func chunks_of_run(map: MapData, hex: Vector2i) -> Array[Vector2i]:
	var seen: Dictionary[Vector2i, bool] = {chunk_of(hex): true}
	for d: int in 6:
		var edge := map.edge_index(hex, d)
		if edge >= 0 and map.road[edge] > 0:
			var chain: Array[Vector2i] = []
			chain.assign(_road_run(map, edge)["chain"])
			for h: Vector2i in chain:
				seen[chunk_of(h)] = true
	var out: Array[Vector2i] = []
	for c: Vector2i in seen:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var near := c + Vector2i(dx, dy)
				if not out.has(near):
					out.append(near)
	return out


## Rivers whose course comes near the chunk, as `river` lines (phase = the river's index, class from the list).
static func _rivers_near(map: MapData, chunk: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var scale := Vector2(float(MapTiles.CELL.x) / map.hex_w_km, MapTiles.ROW / map.grid().hex_h_km)
	var low := MapTiles.cell_centre(chunk * CHUNK) - Vector2(MapTiles.CELL) * 2.0
	var high := MapTiles.cell_centre((chunk + Vector2i.ONE) * CHUNK) + Vector2(MapTiles.CELL) * 2.0
	for n: int in map.rivers.size():
		var corners: PackedVector2Array = map.rivers[n]["corners"]
		var pts := PackedVector2Array()
		var near := false
		for p: Vector2 in corners:
			var q := p * scale
			pts.append(q)
			near = near or (q.x >= low.x and q.x <= high.x and q.y >= low.y and q.y <= high.y)
		if near:
			out.append(river(pts, int(map.rivers[n]["class"]), float(n) * 1.7))
	return out


## Streams (river class 4) on the edges that the hexes low..high (inclusive) own, in edge-index order.
static func _streams_between(map: MapData, low: Vector2i, high: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: int in _owned_edges_between(map, low, high):
		if map.river[e] != 4:
			continue
		var ends := _ends_of(map, e)
		var mid := (MapTiles.cell_centre(ends[0]) + MapTiles.cell_centre(ends[1])) / 2.0
		var across := MapTiles.cell_centre(ends[1]) - MapTiles.cell_centre(ends[0])
		# The edge runs square to the line between the two middles on the untilted ground: 30 px either way.
		var along := Vector2(-across.y / 0.85, across.x).normalized() * 30.0
		along.y *= 0.85
		out.append(stream(mid - along, mid + along))
	return out


## The edges (indices) owned by the hexes low..high (inclusive, clipped to the map), in edge-index order.
static func _owned_edges_between(map: MapData, low: Vector2i, high: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for row: int in range(maxi(low.y, 0), mini(high.y, map.rows - 1) + 1):
		for col: int in range(maxi(low.x, 0), mini(high.x, map.cols - 1) + 1):
			var base := MapData.OWNED_EDGES * map.index_of(Vector2i(col, row))
			for k: int in MapData.OWNED_EDGES:
				out.append(base + k)
	return out


## The road runs that have an edge owned by a hex low..high, each once, in the order of their first edge seen.
## Each is {chain: hexes in drawing order, quality, edges}.
static func _road_runs_between(map: MapData, low: Vector2i, high: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary[int, bool] = {}
	for e: int in _owned_edges_between(map, low, high):
		if map.road[e] == 0 or seen.has(e):
			continue
		var run := _road_run(map, e)
		var members: Array = run["edges"]
		for member: Variant in members:
			seen[int(member)] = true
		out.append(run)
	return out


## The two hexes of an edge (the owner first).
static func _ends_of(map: MapData, edge: int) -> Array[Vector2i]:
	var a := map.hex_of(floori(float(edge) / float(MapData.OWNED_EDGES)))
	return [a, map.neighbour(a, edge % MapData.OWNED_EDGES)]


## The road edges that touch a hex (edge indices).
static func _road_edges_at(map: MapData, hex: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for d: int in 6:
		var e := map.edge_index(hex, d)
		if e >= 0 and map.road[e] > 0:
			out.append(e)
	return out


## The run of road edges `edge` belongs to, as `roads` builds it: a run goes on through a hex that has exactly two
## road edges when the other has the same quality, and starts from its lowest edge index (the first step of the
## list of all steps). {chain, quality, edges}.
static func _road_run(map: MapData, edge: int) -> Dictionary:
	var quality := int(map.road[edge])
	var members: Dictionary[int, bool] = {edge: true}
	var first_ends := _ends_of(map, edge)
	for end: int in 2:
		var tip := first_ends[end]
		while true:
			var next := _run_on(map, tip, members, quality)
			if next < 0:
				break
			members[next] = true
			var pair := _ends_of(map, next)
			tip = pair[1] if pair[0] == tip else pair[0]
	var first := edge
	for member: int in members:
		first = mini(first, member)
	var used: Dictionary[int, bool] = {first: true}
	var ends := _ends_of(map, first)
	var chain: Array[Vector2i] = [ends[0], ends[1]]
	for side: int in 2:
		while true:
			var tip := chain[chain.size() - 1] if side == 0 else chain[0]
			var next := _run_on(map, tip, used, quality)
			if next < 0:
				break
			used[next] = true
			var pair := _ends_of(map, next)
			var other := pair[1] if pair[0] == tip else pair[0]
			if side == 0:
				chain.append(other)
			else:
				chain.insert(0, other)
	var edges: Array[int] = []
	edges.assign(members.keys())
	return {"chain": chain, "quality": quality, "edges": edges}


## The one edge not in `used` that goes on from a hex, or -1 at a junction, an end or a change of quality.
static func _run_on(map: MapData, hex: Vector2i, used: Dictionary[int, bool], quality: int) -> int:
	var here := _road_edges_at(map, hex)
	if here.size() != 2:
		return -1
	for e: int in here:
		if not used.has(e) and map.road[e] == quality:
			return e
	return -1
