## A made-up map for the speed budget and the tests (docs/architecture/m1-build-spec.md section 9): noise heights, land above
## a level chosen so that LAND_SHARE of the hexes are land, covers in patches, woods on WOODS_SHARE of the land, a place on
## one land hex in PLACE_ONE_IN, rivers down to the sea on RIVER_SHARE of the edges, roads between near places. It only has
## to be Europe-shaped in numbers; it is not a picture. Same seed, same map (luck only through Rng; the noise is seeded from it).
##
## Rivers run along hex edges from corner to corner. Every corner of land gets its distance (in edges) to the nearest coast
## edge by a breadth-first search; a river starts on a high corner and steps to the neighbour corner one nearer to the sea
## (the lower of two), so it always arrives, and rivers that meet share their lower course. Corners sit on a lattice:
## corner k of hex (c, r) is at X = 2c + 1 + (r & 1) + CORNER_DX[k], Y = 3r + CORNER_DY[k] (units of half a hex width and
## of half a corner radius), the same corners MapData.validate() joins by their kilometres.
class_name FakeMap
extends RefCounted

const HEX_W_KM := 28.0
const LAND_SHARE := 0.60
## Of the land hexes.
const WOODS_SHARE := 0.15
## Of all edges (3 a hex).
const RIVER_SHARE := 0.05
const PLACE_ONE_IN := 40
const ROAD_REACH := 14
const MOUNTAIN_RELIEF := 5
const HEIGHT_TOP_M := 3300.0
const WOODS_MAX_M := 1600
const ROCK_MIN_M := 1800
const SNOW_MIN_M := 2800
const MARSH_MAX_M := 25
const NOISE_SCALE := 0.012
const CORNER_DX: Array[int] = [0, 1, 1, 0, -1, -1]
const CORNER_DY: Array[int] = [0, 1, 3, 4, 3, 1]
const DIRS_EVEN: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const DIRS_ODD: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]
const COVER_FARMLAND := 0
const COVER_GRASSLAND := 1
const COVER_WOODS := 2
const COVER_MARSH := 3
const COVER_ROCK := 4
const COVER_SNOW := 5
const COVER_SAND := 7

var _map: MapData = null
var _rng: Rng = null
var _cols := 0
var _rows := 0
var _field := PackedFloat32Array()
var _coastal := PackedByteArray()
var _land_hexes := PackedInt32Array()
# The corner lattice.
var _w2 := 0
var _dist := PackedInt32Array()
var _adj := PackedInt32Array()
var _sink_edge := PackedInt32Array()
var _csum := PackedFloat32Array()
var _ccnt := PackedByteArray()
var _flow := PackedInt32Array()


## A map of cols x rows hexes, the same for the same seed.
static func build(cols: int, rows: int, seed_value: int) -> MapData:
	var maker := FakeMap.new()
	return maker._make(cols, rows, seed_value)


func _make(cols: int, rows: int, seed_value: int) -> MapData:
	_cols = cols
	_rows = rows
	_rng = Rng.new()
	_rng.seed_with(seed_value)
	_map = MapData.new()
	_map.id = "fake_%d_%d_%d" % [cols, rows, seed_value]
	_map.hex_w_km = HEX_W_KM
	_map.ref_lat = 55.0
	_map.lat_north = 71.0
	_map.allocate(cols, rows)
	_shape()
	_covers()
	_edges_and_corners()
	_rivers()
	_places()
	_roads()
	_climate()
	return _map


static func _dirs(row: int) -> Array[Vector2i]:
	return DIRS_ODD if (row & 1) == 1 else DIRS_EVEN


func _noise(frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi_range(1, 1 << 30)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.frequency = frequency
	return noise


func _sample(noise: FastNoiseLite) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_cols * _rows)
	for r: int in _rows:
		for c: int in _cols:
			out[r * _cols + c] = noise.get_noise_2d(float(c) + 0.5 * float(r & 1), float(r) * 0.866)
	return out


## The value below which `share` of the samples lie.
static func _quantile(values: PackedFloat32Array, share: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(share * float(sorted.size())), 0, sorted.size() - 1)]


## Land and sea, heights, relief, depth, coast flags.
func _shape() -> void:
	var n := _cols * _rows
	_field = _sample(_noise(NOISE_SCALE, 5))
	var sea_level := _quantile(_field, 1.0 - LAND_SHARE)
	var deep_level := _quantile(_field, 0.2)
	var top := _field[0]
	for v: float in _field:
		top = maxf(top, v)
	var span := maxf(top - sea_level, 0.0001)
	_coastal = MapData._bytes(n, 0)
	for i: int in n:
		if _field[i] > sea_level:
			_map.land[i] = 1
			_land_hexes.append(i)
			var t := (_field[i] - sea_level) / span
			_map.height_m[i] = 1 + int(pow(t, 1.5) * HEIGHT_TOP_M)
			_map.relief[i] = ReliefLevels.level_of(float(_map.height_m[i]))
			_map.depth[i] = 0
	for r: int in _rows:
		var dirs := _dirs(r)
		for c: int in _cols:
			var i := r * _cols + c
			var has_sea := false
			var has_land := false
			for d: Vector2i in dirs:
				var nc := c + d.x
				var nr := r + d.y
				if nc < 0 or nr < 0 or nc >= _cols or nr >= _rows:
					continue
				if _map.land[nr * _cols + nc] == 1:
					has_land = true
				else:
					has_sea = true
			if _map.land[i] == 1:
				_coastal[i] = 1 if has_sea else 0
			elif has_land:
				_map.depth[i] = 0
			else:
				_map.depth[i] = 2 if _field[i] < deep_level else 1
	for i: int in n:
		if _map.land[i] == 0 and _map.depth[i] == 1 and _field[i] < deep_level:
			_map.depth[i] = 2


## Cover by height and patches; woods on the top WOODS_SHARE of the land by a second noise.
func _covers() -> void:
	var woods_noise := _sample(_noise(0.04, 3))
	var patch_noise := _sample(_noise(0.03, 2))
	var eligible := PackedFloat32Array()
	var eligible_hexes := PackedInt32Array()
	for i: int in _land_hexes:
		var h := _map.height_m[i]
		var cover := COVER_FARMLAND if patch_noise[i] > 0.0 else COVER_GRASSLAND
		if h >= SNOW_MIN_M:
			cover = COVER_SNOW
		elif h >= ROCK_MIN_M:
			cover = COVER_ROCK
		elif _coastal[i] == 1 and h <= MARSH_MAX_M:
			cover = COVER_SAND if woods_noise[i] > 0.0 else COVER_MARSH
		elif h < WOODS_MAX_M:
			eligible.append(woods_noise[i])
			eligible_hexes.append(i)
		_map.cover[i] = cover
	if eligible.is_empty():
		return
	var wanted := float(_land_hexes.size()) * WOODS_SHARE
	var cut := _quantile(eligible, 1.0 - minf(1.0, wanted / float(eligible.size())))
	for k: int in eligible_hexes.size():
		if eligible[k] > cut:
			_map.cover[eligible_hexes[k]] = COVER_WOODS


func _corner(edge: int, end: int) -> int:
	var k := edge % 3
	var i := floori(float(edge - k) / 3.0)
	var c := i % _cols
	var r := floori(float(i - c) / float(_cols))
	var corner: int = HexGrid.EDGE_CORNERS[k][end]
	return (3 * r + CORNER_DY[corner]) * _w2 + 2 * c + 1 + (r & 1) + CORNER_DX[corner]


func _add_adj(corner: int, edge: int) -> void:
	for s: int in 3:
		if _adj[3 * corner + s] < 0:
			_adj[3 * corner + s] = edge
			return


## Crest edges, the corner lattice (land|land edges link corners; coast edges are where rivers end), the distance of every
## land corner to the coast, and the mean height of each corner.
func _edges_and_corners() -> void:
	_w2 = 2 * _cols + 2
	var lattice := _w2 * (3 * _rows + 2)
	_dist = PackedInt32Array()
	_dist.resize(lattice)
	_dist.fill(-1)
	_adj = PackedInt32Array()
	_adj.resize(lattice * 3)
	_adj.fill(-1)
	_sink_edge = PackedInt32Array()
	_sink_edge.resize(lattice)
	_sink_edge.fill(-1)
	_csum = PackedFloat32Array()
	_csum.resize(lattice)
	_ccnt = MapData._bytes(lattice, 0)
	_flow = PackedInt32Array()
	_flow.resize(_map.edge_count())
	var queue := PackedInt32Array()
	for r: int in _rows:
		var dirs := _dirs(r)
		for c: int in _cols:
			var i := r * _cols + c
			var land_i := _map.land[i]
			if land_i == 1:
				for k: int in 6:
					var cid := (3 * r + CORNER_DY[k]) * _w2 + 2 * c + 1 + (r & 1) + CORNER_DX[k]
					_csum[cid] += float(_map.height_m[i])
					_ccnt[cid] += 1
			for k: int in 3:
				var nc := c + dirs[k].x
				var nr := r + dirs[k].y
				var j := -1 if (nc < 0 or nr < 0 or nc >= _cols or nr >= _rows) else nr * _cols + nc
				var land_j := -1 if j < 0 else int(_map.land[j])
				var e := 3 * i + k
				if land_i == 1 and land_j == 1:
					_add_adj(_corner(e, 0), e)
					_add_adj(_corner(e, 1), e)
					if _map.relief[i] >= MOUNTAIN_RELIEF and _map.relief[j] >= MOUNTAIN_RELIEF:
						_map.crest[e] = 1
				elif (land_i == 1 and land_j <= 0) or (land_i == 0 and land_j == 1):
					for end: int in 2:
						var cid := _corner(e, end)
						if _dist[cid] < 0:
							_dist[cid] = 0
							queue.append(cid)
						if _sink_edge[cid] < 0:
							_sink_edge[cid] = e
	_flood(queue)


func _flood(queue: PackedInt32Array) -> void:
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for s: int in 3:
			var e := _adj[3 * cur + s]
			if e < 0:
				break
			var other := _corner(e, 0) + _corner(e, 1) - cur
			if _dist[other] < 0:
				_dist[other] = _dist[cur] + 1
				queue.append(other)


func _corner_height(cid: int) -> float:
	return _csum[cid] / float(maxi(1, _ccnt[cid]))


func _corner_km(cid: int) -> Vector2:
	@warning_ignore("integer_division")
	var y := cid / _w2
	var x := cid - y * _w2
	var radius := _map.grid().hex_r_km
	return Vector2(float(x) * HEX_W_KM * 0.5, float(y) * radius * 0.5)


func _rivers() -> void:
	if _land_hexes.is_empty():
		return
	var heights := PackedFloat32Array()
	for i: int in _land_hexes:
		heights.append(float(_map.height_m[i]))
	var source_min := _quantile(heights, 0.4)
	var target := int(RIVER_SHARE * float(_map.edge_count()))
	var made := 0
	var chains: Array[Dictionary] = []
	var visited: Dictionary = {}
	var attempts := 0
	while made < target and attempts < 40 * target + 1000:
		attempts += 1
		var i := _land_hexes[_rng.randi_range(0, _land_hexes.size() - 1)]
		if float(_map.height_m[i]) < source_min:
			continue
		@warning_ignore("integer_division")
		var r := i / _cols
		var c := i - r * _cols
		var k := _rng.randi_range(0, 5)
		var cid := (3 * r + CORNER_DY[k]) * _w2 + 2 * c + 1 + (r & 1) + CORNER_DX[k]
		if _dist[cid] < 3:
			continue
		made += _run_river(cid, chains, visited)
	for chain: Dictionary in chains:
		chain["class"] = _class_of(_flow[int(chain["last_edge"])])
		chain.erase("last_edge")
	for e: int in _map.edge_count():
		if _flow[e] > 0:
			_map.river[e] = _class_of(_flow[e])
	for chain: Dictionary in chains:
		_map.rivers.append(chain)


## 4 a stream, 1 to 3 the classes by the number of sources that drain through the edge.
static func _class_of(flow: int) -> int:
	if flow <= 2:
		return 4
	if flow <= 8:
		return 1
	if flow <= 30:
		return 2
	return 3


## Walks from a corner to the sea; returns the new edges. A chain records only the part no earlier river drew.
func _run_river(start: int, chains: Array[Dictionary], visited: Dictionary) -> int:
	var made := 0
	var cur := start
	var points := PackedVector2Array()
	var recording := not visited.has(start)
	var last_edge := -1
	if recording:
		points.append(_corner_km(start))
		visited[start] = true
	while true:
		var edge := -1
		if _dist[cur] == 0:
			edge = _sink_edge[cur]
		else:
			var best := INF
			for s: int in 3:
				var e := _adj[3 * cur + s]
				if e < 0:
					break
				var other := _corner(e, 0) + _corner(e, 1) - cur
				if _dist[other] == _dist[cur] - 1 and _corner_height(other) < best:
					best = _corner_height(other)
					edge = e
		if edge < 0:
			break
		if _flow[edge] == 0:
			made += 1
		_flow[edge] += 1
		var next := _corner(edge, 0) + _corner(edge, 1) - cur
		if recording:
			points.append(_corner_km(next))
			last_edge = edge
			if visited.has(next) or _dist[cur] == 0:
				recording = false
			visited[next] = true
		if _dist[cur] == 0:
			break
		cur = next
	if points.size() >= 2:
		chains.append({"name": "River %d" % (chains.size() + 1), "class": 4, "corners": points, "last_edge": last_edge})
	return made


func _places() -> void:
	for i: int in _land_hexes:
		if _map.relief[i] >= MOUNTAIN_RELIEF or _rng.randi_range(0, PLACE_ONE_IN - 1) != 0:
			continue
		var roll := _rng.randi_range(0, 99)
		var level := 1 if roll < 60 else (2 if roll < 85 else (3 if roll < 96 else 4))
		var port := _coastal[i] == 1
		_map.place_id[i] = _map.places.size()
		_map.places.append({
			"name": "Place %d" % (_map.places.size() + 1), "hex": _map.hex_of(i), "level": level, "port": port,
			"port_mode": "seaside" if port else "", "capital": false, "landmark": "",
		})


static func _cube(hex: Vector2i) -> Vector3i:
	var x := hex.x - ((hex.y - (hex.y & 1)) >> 1)
	return Vector3i(x, -x - hex.y, hex.y)


static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var d := _cube(a) - _cube(b)
	return maxi(maxi(absi(d.x), absi(d.y)), absi(d.z))


## The hexes of the straight line from a to b, both ends included.
static func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var steps := _hex_distance(a, b)
	var ca := _cube(a)
	var cb := _cube(b)
	for s: int in steps + 1:
		var t := float(s) / float(maxi(steps, 1))
		var fx := lerpf(float(ca.x), float(cb.x), t) + 1e-4
		var fy := lerpf(float(ca.y), float(cb.y), t) + 2e-4
		var fz := lerpf(float(ca.z), float(cb.z), t) - 3e-4
		var rx := roundf(fx)
		var ry := roundf(fy)
		var rz := roundf(fz)
		var dx := absf(rx - fx)
		var dy := absf(ry - fy)
		var dz := absf(rz - fz)
		if dx > dy and dx > dz:
			rx = -ry - rz
		elif dy > dz:
			ry = -rx - rz
		else:
			rz = -rx - ry
		var z := int(rz)
		out.append(Vector2i(int(rx) + ((z - (z & 1)) >> 1), z))
	return out


func _clear(path: Array[Vector2i]) -> bool:
	for h: Vector2i in path:
		var i := _map.index_of(h)
		if i < 0 or _map.land[i] == 0 or _map.relief[i] >= MOUNTAIN_RELIEF:
			return false
	return true


## Links every place to its nearest two within ROAD_REACH when the straight line between them is open land.
func _roads() -> void:
	var buckets: Dictionary = {}
	for p: int in _map.places.size():
		var hex: Vector2i = _map.places[p]["hex"]
		var key := Vector2i(hex.x >> 4, hex.y >> 4)
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(p)
	var done: Dictionary = {}
	for p: int in _map.places.size():
		var hex: Vector2i = _map.places[p]["hex"]
		var near: Array[Vector2i] = []  # (distance, place)
		for by: int in range((hex.y >> 4) - 1, (hex.y >> 4) + 2):
			for bx: int in range((hex.x >> 4) - 1, (hex.x >> 4) + 2):
				for q: int in (buckets.get(Vector2i(bx, by), []) as Array):
					var dist := _hex_distance(hex, _map.places[q]["hex"])
					if q != p and dist <= ROAD_REACH:
						near.append(Vector2i(dist, q))
		near.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
		for t: int in mini(2, near.size()):
			var q := near[t].y
			var pair := mini(p, q) * _map.places.size() + maxi(p, q)
			if done.has(pair):
				continue
			done[pair] = true
			var path := _line(hex, _map.places[q]["hex"])
			if _clear(path):
				var quality := 2 if maxi(int(_map.places[p]["level"]), int(_map.places[q]["level"])) >= 3 else 1
				_lay_road(path, quality)


func _lay_road(path: Array[Vector2i], quality: int) -> void:
	for s: int in path.size() - 1:
		var d := _map.grid().direction_of(path[s], path[s + 1])
		var e := _map.edge_index(path[s], d)
		if d < 0 or e < 0:
			continue
		_map.road[e] = maxi(_map.road[e], quality)
		var river := _map.river[e]
		if river == 4:
			_map.crossing[e] = 1
		elif river == 3:
			_map.crossing[e] = 3
		elif river > 0:
			_map.crossing[e] = 2


## Cold in the north and on the heights.
func _climate() -> void:
	for r: int in _rows:
		var north := float(r) / float(maxi(_rows, 1))
		for c: int in _cols:
			var i := r * _cols + c
			var h := _map.height_m[i]
			if north < 0.04 or h >= SNOW_MIN_M:
				_map.climate[i] = 0
			elif north < 0.1 or h >= ROCK_MIN_M:
				_map.climate[i] = 1
			else:
				_map.climate[i] = 2
