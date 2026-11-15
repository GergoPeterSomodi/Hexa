## The fixed map (docs/architecture/m1-build-spec.md section 4 and 14): what is designed ahead and read-only in play.
## One file per map in data/maps/<id>.tres, built by tools/build_map.gd. Per-hex arrays are indexed row * cols + col;
## per-edge arrays by 3 * hex index + k, where k = 0 E, 1 NE, 2 NW (each hex owns three of its six edges, so an edge
## has one slot whichever side asks). What changes in play lives in MapState, never here.
class_name MapData
extends Resource

## Samples of the height raster per hex width.
const HEIGHT_GRID_STEP := 4
## Edge directions a hex owns (the other three belong to the neighbour).
const OWNED_EDGES := 3
const MAX_RELIEF := 6
const COVER_SEA := 255

@export var id: String = ""
@export var cols: int = 0
@export var rows: int = 0
@export var hex_w_km: float = 28.0
@export var lon_west: float = 0.0
@export var lat_north: float = 0.0
@export var ref_lat: float = 0.0
@export var deg_km: float = 111.2

# Per hex.
@export var land: PackedByteArray = PackedByteArray()
@export var height_m: PackedInt32Array = PackedInt32Array()
@export var relief: PackedByteArray = PackedByteArray()
@export var cover: PackedByteArray = PackedByteArray()
@export var depth: PackedByteArray = PackedByteArray()
@export var climate: PackedByteArray = PackedByteArray()
@export var fertility: PackedByteArray = PackedByteArray()
@export var ore: PackedByteArray = PackedByteArray()
@export var pass_id: PackedInt32Array = PackedInt32Array()
@export var place_id: PackedInt32Array = PackedInt32Array()

# Per edge.
@export var river: PackedByteArray = PackedByteArray()
@export var crest: PackedByteArray = PackedByteArray()
@export var pass_edge: PackedByteArray = PackedByteArray()
@export var road: PackedByteArray = PackedByteArray()
@export var crossing: PackedByteArray = PackedByteArray()

# Lists.
@export var places: Array[Dictionary] = []
@export var passes: Array[Dictionary] = []
@export var rivers: Array[Dictionary] = []

# For the later map look (section 14): the real coast lines in km, and the heights on a fine raster.
@export var shoreline: Array[PackedVector2Array] = []
@export var height_grid: PackedInt32Array = PackedInt32Array()
@export var height_grid_size: Vector2i = Vector2i.ZERO
@export var height_grid_origin_km: Vector2 = Vector2.ZERO

var _grid: HexGrid = null


## Sizes every array for a map of cols x rows hexes (sea, no rivers, no roads), dropping what was there.
func allocate(p_cols: int, p_rows: int) -> void:
	cols = p_cols
	rows = p_rows
	var n := cols * rows
	var e := OWNED_EDGES * n
	land = _bytes(n, 0)
	height_m = PackedInt32Array()
	height_m.resize(n)
	relief = _bytes(n, 0)
	cover = _bytes(n, COVER_SEA)
	depth = _bytes(n, 1)
	climate = _bytes(n, 2)
	fertility = _bytes(n, 0)
	ore = _bytes(n, 0)
	pass_id = PackedInt32Array()
	pass_id.resize(n)
	pass_id.fill(-1)
	place_id = PackedInt32Array()
	place_id.resize(n)
	place_id.fill(-1)
	river = _bytes(e, 0)
	crest = _bytes(e, 0)
	pass_edge = _bytes(e, 0)
	road = _bytes(e, 0)
	crossing = _bytes(e, 0)
	_grid = null


static func _bytes(n: int, value: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(n)
	out.fill(value)
	return out


func hex_count() -> int:
	return cols * rows


func edge_count() -> int:
	return OWNED_EDGES * cols * rows


## The index of a hex in the per-hex arrays, or -1 off the map.
func index_of(hex: Vector2i) -> int:
	if hex.x < 0 or hex.y < 0 or hex.x >= cols or hex.y >= rows:
		return -1
	return hex.y * cols + hex.x


func hex_of(index: int) -> Vector2i:
	return Vector2i(index % cols, floori(float(index) / float(cols)))


func has(hex: Vector2i) -> bool:
	return index_of(hex) >= 0


## True for a land hex; false for sea and for anything off the map.
func is_land(hex: Vector2i) -> bool:
	var i := index_of(hex)
	return i >= 0 and land[i] == 1


func neighbour(hex: Vector2i, direction: int) -> Vector2i:
	return grid().neighbour(hex, direction)


## The slot of the edge of `hex` in direction `direction` (0 E ... 5 SE), the same number from both sides.
## -1 when the hex is off the map, or when the edge belongs to a neighbour that is off the map (directions 3 to 5).
func edge_index(hex: Vector2i, direction: int) -> int:
	var i := index_of(hex)
	if i < 0 or direction < 0 or direction > 5:
		return -1
	if direction < OWNED_EDGES:
		return OWNED_EDGES * i + direction
	var other := index_of(grid().neighbour(hex, direction))
	if other < 0:
		return -1
	return OWNED_EDGES * other + (direction - OWNED_EDGES)


## The river class on an edge: 0 none, 1 to 3 a river, 4 a stream.
func river_on(hex: Vector2i, direction: int) -> int:
	var e := edge_index(hex, direction)
	return 0 if e < 0 else river[e]


## The starting road on an edge: 0 none, 1 track, 2 road, 3 highway.
func road_on(hex: Vector2i, direction: int) -> int:
	var e := edge_index(hex, direction)
	return 0 if e < 0 else road[e]


## Bit d is set when the neighbour in direction d is sea. Off the map counts as land.
func coast_mask(hex: Vector2i) -> int:
	var mask := 0
	for d: int in 6:
		var i := index_of(grid().neighbour(hex, d))
		if i >= 0 and land[i] == 0:
			mask |= 1 << d
	return mask


## The HexGrid of this map (made once, from the stored window).
func grid() -> HexGrid:
	if _grid == null:
		_grid = HexGrid.new(hex_w_km, deg_km, ref_lat, lon_west, lat_north)
	return _grid


## Problems found, empty when the map is sound: sizes, value ranges, lists, rivers reach the sea, roads reach a
## place, the shoreline agrees with the land, the height raster covers the map.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if cols <= 0 or rows <= 0:
		errors.append("size %d x %d is empty" % [cols, rows])
		return errors
	var n := cols * rows
	var e := OWNED_EDGES * n
	var hex_sizes: Dictionary = {
		"land": land.size(), "height_m": height_m.size(), "relief": relief.size(), "cover": cover.size(),
		"depth": depth.size(), "climate": climate.size(), "fertility": fertility.size(), "ore": ore.size(),
		"pass_id": pass_id.size(), "place_id": place_id.size(),
	}
	var edge_sizes: Dictionary = {
		"river": river.size(), "crest": crest.size(), "pass_edge": pass_edge.size(), "road": road.size(),
		"crossing": crossing.size(),
	}
	for key: String in hex_sizes:
		if int(hex_sizes[key]) != n:
			errors.append("%s has %d entries, expected %d" % [key, int(hex_sizes[key]), n])
	for key: String in edge_sizes:
		if int(edge_sizes[key]) != e:
			errors.append("%s has %d entries, expected %d" % [key, int(edge_sizes[key]), e])
	if not errors.is_empty():
		return errors
	_check_hexes(errors, n)
	_check_edges(errors, e)
	_check_lists(errors)
	if errors.is_empty():
		_check_rivers(errors)
		_check_roads(errors)
		_check_shoreline(errors)
		_check_height_grid(errors)
	return errors


func _check_hexes(errors: Array[String], n: int) -> void:
	for i: int in n:
		if land[i] > 1:
			errors.append("hex %s: land is %d" % [hex_of(i), land[i]])
		if relief[i] > MAX_RELIEF:
			errors.append("hex %s: relief is %d" % [hex_of(i), relief[i]])
		if land[i] == 1 and cover[i] == COVER_SEA:
			errors.append("hex %s: land without cover" % [hex_of(i)])
		if land[i] == 0 and cover[i] != COVER_SEA:
			errors.append("hex %s: sea with cover %d" % [hex_of(i), cover[i]])
		if depth[i] > 2:
			errors.append("hex %s: depth is %d" % [hex_of(i), depth[i]])
		if climate[i] > 2:
			errors.append("hex %s: climate is %d" % [hex_of(i), climate[i]])
		if pass_id[i] >= passes.size() or pass_id[i] < -1:
			errors.append("hex %s: pass_id %d is not in passes" % [hex_of(i), pass_id[i]])
		if place_id[i] >= places.size() or place_id[i] < -1:
			errors.append("hex %s: place_id %d is not in places" % [hex_of(i), place_id[i]])
		if errors.size() > 50:
			errors.append("(more problems not listed)")
			return


func _check_edges(errors: Array[String], e: int) -> void:
	for i: int in e:
		var where := "edge %d (hex %s, direction %d)" % [i, hex_of(floori(float(i) / float(OWNED_EDGES))), i % OWNED_EDGES]
		if river[i] > 4:
			errors.append("%s: river is %d" % [where, river[i]])
		if crest[i] > 1 or pass_edge[i] > 1:
			errors.append("%s: crest or pass flag is not 0 or 1" % where)
		if road[i] > 3:
			errors.append("%s: road is %d" % [where, road[i]])
		if crossing[i] > 5:
			errors.append("%s: crossing is %d" % [where, crossing[i]])
		if errors.size() > 50:
			errors.append("(more problems not listed)")
			return


func _check_lists(errors: Array[String]) -> void:
	for p: Dictionary in places:
		var hex: Vector2i = _hex_in(p)
		if not has(hex):
			errors.append("place %s is off the map at %s" % [str(p.get("name", "?")), hex])
		elif not is_land(hex):
			errors.append("place %s is in the sea at %s" % [str(p.get("name", "?")), hex])
	for p: Dictionary in passes:
		var hex: Vector2i = _hex_in(p)
		if not has(hex):
			errors.append("pass %s is off the map at %s" % [str(p.get("name", "?")), hex])
	for r: Dictionary in rivers:
		var corners: Variant = r.get("corners", null)
		if not (corners is PackedVector2Array) or (corners as PackedVector2Array).size() < 2:
			errors.append("river %s has no drawn course" % str(r.get("name", "?")))


static func _hex_in(entry: Dictionary) -> Vector2i:
	var h: Variant = entry.get("hex", Vector2i(-1, -1))
	if h is Vector2i:
		return h
	return Vector2i(-1, -1)


## The key of corner `k` of `hex`, rounded to 10 m so two hexes name a shared corner alike.
func _corner_key(hex: Vector2i, k: int) -> Vector2i:
	var p := grid().corners_km(hex)[k]
	return Vector2i(roundi(p.x * 100.0), roundi(p.y * 100.0))


## Every connected river (edges that share a corner) must touch the sea or leave the map.
func _check_rivers(errors: Array[String]) -> void:
	var parent: Dictionary = {}
	var ends: Dictionary = {}  # corner key -> true when the corner touches the sea or the map edge
	var edges: Array[Vector2i] = []  # (hex index, owned direction)
	for i: int in hex_count():
		var hex := hex_of(i)
		for k: int in OWNED_EDGES:
			if river[OWNED_EDGES * i + k] == 0:
				continue
			var pair: Vector2i = HexGrid.EDGE_CORNERS[k]
			var a := _corner_key(hex, pair.x)
			var b := _corner_key(hex, pair.y)
			_union(parent, a, b)
			edges.append(Vector2i(i, k))
			var nb := grid().neighbour(hex, k)
			if not has(nb) or not is_land(nb) or not is_land(hex):
				ends[a] = true
				ends[b] = true
	var ok_roots: Dictionary = {}
	for c: Vector2i in ends:
		ok_roots[_find(parent, c)] = true
	var reported: Dictionary = {}
	for t: Vector2i in edges:
		var hex := hex_of(t.x)
		var pair: Vector2i = HexGrid.EDGE_CORNERS[t.y]
		var root: Variant = _find(parent, _corner_key(hex, pair.x))
		if not ok_roots.has(root) and not reported.has(root):
			reported[root] = true
			errors.append("a river near hex %s never reaches the sea or the map edge" % [hex])


## Every connected road (hexes joined by road edges) must hold a place.
func _check_roads(errors: Array[String]) -> void:
	var parent: Dictionary = {}
	var on_road: Dictionary = {}
	for i: int in hex_count():
		for k: int in OWNED_EDGES:
			if road[OWNED_EDGES * i + k] == 0:
				continue
			var j := index_of(grid().neighbour(hex_of(i), k))
			on_road[i] = true
			if j >= 0:
				on_road[j] = true
				_union(parent, i, j)
	var with_place: Dictionary = {}
	for i: int in on_road:
		if place_id[i] >= 0:
			with_place[_find(parent, i)] = true
	var reported: Dictionary = {}
	for i: int in on_road:
		var root: Variant = _find(parent, i)
		if not with_place.has(root) and not reported.has(root):
			reported[root] = true
			errors.append("a road through hex %s reaches no place" % [hex_of(i)])


## Along every coast edge (a land and a sea hex side by side) the shoreline must cross the line between the two
## centres. Skipped while the map stores no shoreline.
func _check_shoreline(errors: Array[String]) -> void:
	if shoreline.is_empty():
		return
	var cell := hex_w_km
	var buckets: Dictionary = {}  # Vector2i cell -> Array of [a, b] segments
	for line: PackedVector2Array in shoreline:
		for s: int in line.size() - 1:
			var a := line[s]
			var b := line[s + 1]
			var lo := Vector2i(floori(minf(a.x, b.x) / cell), floori(minf(a.y, b.y) / cell))
			var hi := Vector2i(floori(maxf(a.x, b.x) / cell), floori(maxf(a.y, b.y) / cell))
			for cy: int in range(lo.y, hi.y + 1):
				for cx: int in range(lo.x, hi.x + 1):
					var key := Vector2i(cx, cy)
					if not buckets.has(key):
						buckets[key] = []
					(buckets[key] as Array).append([a, b])
	var g := grid()
	for i: int in hex_count():
		var hex := hex_of(i)
		for k: int in OWNED_EDGES:
			var nb := g.neighbour(hex, k)
			var j := index_of(nb)
			if j < 0 or land[i] == land[j]:
				continue
			if not _crosses(buckets, cell, g.centre_km(hex), g.centre_km(nb)):
				errors.append("no shoreline between land and sea hexes %s and %s" % [hex, nb])
				if errors.size() > 50:
					return


static func _crosses(buckets: Dictionary, cell: float, p: Vector2, q: Vector2) -> bool:
	var lo := Vector2i(floori(minf(p.x, q.x) / cell), floori(minf(p.y, q.y) / cell))
	var hi := Vector2i(floori(maxf(p.x, q.x) / cell), floori(maxf(p.y, q.y) / cell))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			var segs: Variant = buckets.get(Vector2i(cx, cy), null)
			if segs == null:
				continue
			for seg: Array in (segs as Array):
				var a: Vector2 = seg[0]
				var b: Vector2 = seg[1]
				if Geometry2D.segment_intersects_segment(p, q, a, b) != null:
					return true
	return false


## The height raster, when there is one, must hold width x height samples and reach past the map's far corners.
func _check_height_grid(errors: Array[String]) -> void:
	if height_grid.is_empty() and height_grid_size == Vector2i.ZERO:
		return
	if height_grid_size.x <= 0 or height_grid_size.y <= 0:
		errors.append("height_grid_size %s is empty" % [height_grid_size])
		return
	if height_grid.size() != height_grid_size.x * height_grid_size.y:
		errors.append("height_grid has %d samples, expected %d" % [height_grid.size(),
			height_grid_size.x * height_grid_size.y])
		return
	var g := grid()
	var step := hex_w_km / float(HEIGHT_GRID_STEP)
	var far := Vector2(hex_w_km * (float(cols) + 0.5), g.hex_r_km * 2.0 + g.hex_h_km * float(rows - 1))
	var last := height_grid_origin_km + Vector2(
		float(height_grid_size.x - 1), float(height_grid_size.y - 1)) * step
	if height_grid_origin_km.x > 0.0 or height_grid_origin_km.y > 0.0 or last.x < far.x or last.y < far.y:
		errors.append("height_grid does not cover the map (origin %s, last sample %s, map ends at %s)" % [
			height_grid_origin_km, last, far])


## SHA-256 (hex text) of every field in a fixed order.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	_feed(ctx, id.to_utf8_buffer())
	_feed(ctx, PackedInt32Array([cols, rows]).to_byte_array())
	_feed(ctx, PackedFloat64Array([hex_w_km, lon_west, lat_north, ref_lat, deg_km]).to_byte_array())
	for a: PackedByteArray in [land, relief, cover, depth, climate, fertility, ore, river, crest, pass_edge, road,
			crossing]:
		_feed(ctx, PackedInt32Array([a.size()]).to_byte_array())
		_feed(ctx, a)
	for a: PackedInt32Array in [height_m, pass_id, place_id, height_grid]:
		_feed(ctx, PackedInt32Array([a.size()]).to_byte_array())
		_feed(ctx, a.to_byte_array())
	for list: Array[Dictionary] in [places, passes, rivers]:
		_feed(ctx, PackedInt32Array([list.size()]).to_byte_array())
		for d: Dictionary in list:
			_feed(ctx, _dict_bytes(d))
	_feed(ctx, PackedInt32Array([shoreline.size()]).to_byte_array())
	for line: PackedVector2Array in shoreline:
		_feed(ctx, PackedInt32Array([line.size()]).to_byte_array())
		_feed(ctx, line.to_byte_array())
	_feed(ctx, PackedInt32Array([height_grid_size.x, height_grid_size.y]).to_byte_array())
	_feed(ctx, PackedFloat32Array([height_grid_origin_km.x, height_grid_origin_km.y]).to_byte_array())
	return ctx.finish().hex_encode()


## HashingContext refuses an empty chunk.
static func _feed(ctx: HashingContext, bytes: PackedByteArray) -> void:
	if not bytes.is_empty():
		ctx.update(bytes)


static func _dict_bytes(d: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	var keys: Array = d.keys()
	keys.sort()
	for key: Variant in keys:
		out.append_array(str(key).to_utf8_buffer())
		out.append(0)
		var v: Variant = d[key]
		if v is PackedVector2Array:
			out.append_array((v as PackedVector2Array).to_byte_array())
		else:
			out.append_array((type_string(typeof(v)) + ":" + str(v)).to_utf8_buffer())
		out.append(0)
	return out


static func _find(parent: Dictionary, x: Variant) -> Variant:
	var root: Variant = x
	while parent.has(root) and parent[root] != root:
		root = parent[root]
	var cur: Variant = x
	while parent.has(cur) and parent[cur] != root:
		var nxt: Variant = parent[cur]
		parent[cur] = root
		cur = nxt
	return root


static func _union(parent: Dictionary, a: Variant, b: Variant) -> void:
	if not parent.has(a):
		parent[a] = a
	if not parent.has(b):
		parent[b] = b
	var ra: Variant = _find(parent, a)
	var rb: Variant = _find(parent, b)
	if ra != rb:
		parent[ra] = rb
