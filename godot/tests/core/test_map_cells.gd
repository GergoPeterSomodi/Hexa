## MapCells and the chunk lines of EdgeLines (docs/architecture/m1-build-spec.md sections 5 and 6): the tile of every
## layer of a hex from MapData and MapState, and the lines of a chunk cut as the whole map's lines are cut.
## The fixture tests/fixtures/trial_cells.json is written by tools/mapview/dump_trial_cells.gd: the trial scene's north
## Italy facts as map arrays, one seed's improvement as state arrays, and the names the trial scene puts on its layers.
extends GutTest

const FIXTURE := "res://tests/fixtures/trial_cells.json"
const TRIAL_INDEX := "res://assets/tiles/trial/index.json"
const TRIAL_GRID_TILE := "grid/line"

var _fixture: Dictionary = {}
var _seed := 12345


func before_all() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_fixture = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## The trial's facts as a MapData.
func _map() -> MapData:
	var m := MapData.new()
	m.id = "trial"
	m.hex_w_km = 28.0
	m.ref_lat = 45.0
	m.allocate(int(_fixture["cols"]), int(_fixture["rows"]))
	for i: int in m.hex_count():
		m.land[i] = int(_fixture["land"][i])
		m.height_m[i] = int(_fixture["height"][i])
		m.relief[i] = int(_fixture["relief"][i])
		m.cover[i] = int(_fixture["cover"][i])
		m.depth[i] = int(_fixture["depth"][i])
		m.place_id[i] = int(_fixture["place_id"][i])
	for p: Dictionary in _fixture["places"]:
		var at: Array = p["hex"]
		var place := p.duplicate()
		place["hex"] = Vector2i(int(at[0]), int(at[1]))
		m.places.append(place)
	for e: Array in _fixture["river"]:
		m.river[m.edge_index(Vector2i(int(e[0]), int(e[1])), int(e[2]))] = int(e[3])
	for e: Array in _fixture["crest"]:
		m.crest[m.edge_index(Vector2i(int(e[0]), int(e[1])), int(e[2]))] = 1
	for e: Array in _fixture["road"]:
		m.road[m.edge_index(Vector2i(int(e[0]), int(e[1])), int(e[2]))] = int(e[3])
	return m


func _state(m: MapData) -> MapState:
	var s := MapState.create(m)
	for i: int in m.hex_count():
		s.main_use[i] = int(_fixture["main_use"][i])
		s.level[i] = int(_fixture["level"][i])
	return s


func _next(n: int) -> int:
	_seed = (_seed * 1103515245 + 12345) & 0x7fffffff
	return (_seed >> 8) % n


func test_of_hex_gives_the_names_the_trial_scene_gives() -> void:
	var m := _map()
	var s := _state(m)
	var have := _trial_names()
	var window: Array = _fixture["window"]
	var expected: Dictionary = _fixture["expected"]
	var wrong := 0
	var built := 0
	var named := 0
	for entry: Variant in window:
		var at: Array = entry
		var hex := Vector2i(int(at[0]), int(at[1]))
		var want: Dictionary = expected["%d,%d" % [hex.x, hex.y]]
		var got := MapCells.of_hex(m, s, hex)
		if got["grid"] == MapCells.GRID_TILE:
			got["grid"] = TRIAL_GRID_TILE  # the trial tileset's name for the grid line
		for layer_name: String in MapCells.LAYERS:  # the trial view clears a cell whose tile the trial bake lacks
			if not have.has(str(got[layer_name])):
				got[layer_name] = ""
		built += 1 if got["piece_ground"] != "" else 0
		for layer_name: String in MapCells.LAYERS:
			var w := str(want.get(layer_name, ""))
			named += 1 if w != "" else 0
			if str(got[layer_name]) != w:
				wrong += 1
				if wrong <= 10:
					gut.p("hex %s layer %s: want '%s', got '%s'" % [hex, layer_name, w, got[layer_name]])
	assert_eq(window.size(), 148)
	assert_gt(built, 10, "the fixture has built hexes")
	assert_gt(named, 800)
	assert_eq(wrong, 0, "layers that differ from the trial scene")


## The tile names of the trial tileset (assets/tiles/trial/index.json) as a set, with "" in it.
func _trial_names() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRIAL_INDEX))
	var index: Dictionary = parsed
	var have: Dictionary = {"": true}
	for source: Dictionary in index["sources"]:
		for tile: Dictionary in source["tiles"]:
			have[str(tile["name"])] = true
	return have


func test_only_pieces_are_missing_from_the_trial_tileset() -> void:
	var have := _trial_names()
	var m := _map()
	var s := _state(m)
	var missing: Dictionary = {}
	for entry: Variant in _fixture["window"]:
		var at: Array = entry
		var cells := MapCells.of_hex(m, s, Vector2i(int(at[0]), int(at[1])))
		for layer_name: String in cells:
			var n := str(cells[layer_name])
			if not have.has(n) and not n.begins_with("piece/") and n != MapCells.GRID_TILE:
				missing[n] = true
	# (The trial bake drew only the pieces of its own improvement, so some piece tiles are not in it.)
	assert_eq(missing.size(), 0, "tiles that are not pieces and not in the trial tileset: %s" % [missing.keys()])


func test_layers_are_the_views_layers() -> void:
	var view_layers: Array = TileMapView.LAYERS.keys()
	var ours: Array = MapCells.LAYERS.duplicate()
	view_layers.sort()
	ours.sort()
	assert_eq(ours, view_layers)


func test_off_the_map_and_sea() -> void:
	var m := _map()
	var s := _state(m)
	var off := MapCells.of_hex(m, s, Vector2i(-1, 3))
	assert_eq(off.size(), MapCells.LAYERS.size())
	for layer_name: String in off:
		assert_eq(off[layer_name], "")
	var sea_hex := Vector2i(-1, -1)
	for i: int in m.hex_count():
		if m.land[i] == 0 and m.has(m.hex_of(i)):
			sea_hex = m.hex_of(i)
			break
	var cells := MapCells.of_hex(m, s, sea_hex)
	assert_true(str(cells["sea"]).begins_with("sea/"))
	assert_eq(cells["ground"], "")
	assert_eq(cells["piece_ground"], "")


func test_touched_by() -> void:
	var m := _map()
	var inside := MapCells.touched_by(m, Vector2i(5, 5))
	assert_eq(inside.size(), 7)
	assert_eq(inside[0], Vector2i(5, 5))
	for d: int in 6:
		assert_true(inside.has(m.neighbour(Vector2i(5, 5), d)))
	assert_eq(MapCells.touched_by(m, Vector2i(0, 0)).size(), 3, "a corner: the hex and the neighbours on the map")
	assert_eq(MapCells.touched_by(m, Vector2i(-5, -5)).size(), 0)


func test_a_build_changes_only_the_cells_touched_by_it() -> void:
	var m := _map()
	var s := _state(m)
	var before: Dictionary = {}
	for i: int in m.hex_count():
		before[m.hex_of(i)] = MapCells.of_hex(m, s, m.hex_of(i))
	for _n: int in 150:
		var hex := m.hex_of(_next(m.hex_count()))
		if not m.is_land(hex):
			continue
		var i := m.index_of(hex)
		var changed := s.duplicate_state()
		changed.main_use[i] = _next(ImproveRules.FAMILIES)
		changed.level[i] = 1 + _next(3)
		var touched := MapCells.touched_by(m, hex)
		for j: int in m.hex_count():
			var other := m.hex_of(j)
			var now := MapCells.of_hex(m, changed, other)
			if not touched.has(other):
				assert_eq(now, before[other], "hex %s changed by a build at %s" % [other, hex])
		var here := MapCells.of_hex(m, changed, hex)
		for layer_name: String in MapCells.LAYERS:
			assert_true(typeof(here[layer_name]) == TYPE_STRING)


func test_every_family_and_level_names_pieces() -> void:
	var m := _map()
	var s := _state(m)
	var hex := Vector2i(-1, -1)
	for i: int in m.hex_count():
		if m.land[i] == 1 and m.place_id[i] < 0:
			hex = m.hex_of(i)
			break
	var i := m.index_of(hex)
	for family: int in range(1, ImproveRules.FAMILIES):
		for lv: int in range(1, ImproveRules.TOP_LEVEL[family] + 1):
			s.main_use[i] = family
			s.level[i] = lv
			var cells := MapCells.of_hex(m, s, hex)
			var prefix := "piece/%s/%d/" % [ImproveRules.NAMES[family], lv]
			for part: String in MapCells.PIECE_PARTS:
				assert_true(str(cells["piece_" + part]).begins_with(prefix), "%s %s" % [prefix, part])
				assert_true(str(cells["piece_" + part]).ends_with("/" + part))
	s.main_use[i] = 0
	assert_eq(MapCells.of_hex(m, s, hex)["piece_front"], "", "wild again: the piece is gone")


# ---- chunk lines ----


## A 70 x 40 land map with a long road that crosses chunk borders (a branch, a track, a loop), a river and a stream.
func _lined_map() -> MapData:
	var m := MapData.new()
	m.id = "lines"
	m.hex_w_km = 28.0
	m.ref_lat = 45.0
	m.allocate(70, 40)
	for i: int in m.hex_count():
		m.land[i] = 1
		m.cover[i] = 0
		m.depth[i] = 0
		m.height_m[i] = 100
	for c: int in range(3, 66):
		m.road[m.edge_index(Vector2i(c, 10), 0)] = 2
	var h := Vector2i(33, 10)
	for _n: int in 22:  # a highway branch running south from the middle of the road
		m.road[m.edge_index(h, 5)] = 3
		h = m.neighbour(h, 5)
	for c: int in range(36, 60):  # a track along row 25
		m.road[m.edge_index(Vector2i(c, 25), 0)] = 1
	for d: int in 6:  # a loop of road round (50, 32)
		var a := m.neighbour(Vector2i(50, 32), d)
		m.road[m.edge_index(a, (d + 2) % 6)] = 2
	m.river[m.edge_index(Vector2i(40, 20), 1)] = 4
	m.river[m.edge_index(Vector2i(10, 30), 2)] = 4
	m.rivers = [{"name": "A", "class": 2, "corners": PackedVector2Array([
		Vector2(20, 20), Vector2(300, 100), Vector2(560, 180), Vector2(900, 330), Vector2(1500, 500), Vector2(1900, 800)])},
		{"name": "B", "class": 3, "corners": PackedVector2Array([Vector2(100, 900), Vector2(400, 700), Vector2(800, 800)])}]
	return m


## The lines of the whole map as the trial scene builds them, for the reference.
func _all_lines(m: MapData) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var scale := Vector2(float(MapTiles.CELL.x) / m.hex_w_km, MapTiles.ROW / m.grid().hex_h_km)
	for n: int in m.rivers.size():
		var pts := PackedVector2Array()
		for p: Vector2 in m.rivers[n]["corners"]:
			pts.append(p * scale)
		lines.append(EdgeLines.river(pts, int(m.rivers[n]["class"]), float(n) * 1.7))
	var steps: Array[Array] = []
	for e: int in m.edge_count():
		var a := m.hex_of(floori(float(e) / 3.0))
		var b := m.neighbour(a, e % 3)
		if m.river[e] == 4:
			var mid := (MapTiles.cell_centre(a) + MapTiles.cell_centre(b)) / 2.0
			var across := MapTiles.cell_centre(b) - MapTiles.cell_centre(a)
			var along := Vector2(-across.y / 0.85, across.x).normalized() * 30.0
			along.y *= 0.85
			lines.append(EdgeLines.stream(mid - along, mid + along))
		if m.road[e] > 0:
			steps.append([a, b, int(m.road[e])])
	lines.append_array(EdgeLines.roads(steps, MapTiles.cell_centre))
	return lines


static func _keys(pieces: Array) -> Array[String]:
	var out: Array[String] = []
	for entry: Variant in pieces:
		var piece: Dictionary = entry
		var pts: PackedVector2Array = piece["points"]
		out.append("%s %d %d %s %s" % [piece["kind"], pts.size(), hash(pts), str(piece.get("before", "")), str(piece.get("after", ""))])
	out.sort()
	return out


func test_for_chunk_is_the_cut_of_the_whole_maps_lines() -> void:
	var m := _lined_map()
	var s := MapState.create(m)
	var cut := EdgeLines.cut(_all_lines(m))
	assert_gt(cut.size(), 3, "the lines run over several chunks")
	var total := 0
	var kinds: Dictionary = {}
	for cy: int in range(-1, 3):
		for cx: int in range(-1, 4):
			var chunk := Vector2i(cx, cy)
			var want: Array = cut.get(chunk, [])
			var got := EdgeLines.for_chunk(m, s, chunk)
			assert_eq(_keys(got), _keys(want), "chunk %s" % chunk)
			total += got.size()
			for piece: Dictionary in got:
				kinds[str(piece["kind"])] = true
	assert_gt(total, 8)
	for kind: String in ["river", "stream", "road", "track"]:
		assert_true(kinds.has(kind), "a %s was drawn" % kind)


func test_pieces_of_one_line_join_at_chunk_borders() -> void:
	var m := _lined_map()
	var s := MapState.create(m)
	var west := EdgeLines.for_chunk(m, s, Vector2i(0, 0))
	var east := EdgeLines.for_chunk(m, s, Vector2i(1, 0))
	var joined := false
	for a: Dictionary in west:
		var pa: PackedVector2Array = a["points"]
		for b: Dictionary in east:
			var pb: PackedVector2Array = b["points"]
			if a["kind"] == b["kind"] and pa[pa.size() - 1] == pb[0]:
				joined = true
	assert_true(joined, "a piece of the west chunk ends where one of the east chunk starts")


func test_chunks_of_run_names_the_chunks_along_the_road() -> void:
	var m := _lined_map()
	var along := EdgeLines.chunks_of_run(m, Vector2i(40, 10))
	for cx: int in 3:
		assert_true(along.has(Vector2i(cx, 0)), "chunk %d,0 lies along the road" % cx)
	var none := EdgeLines.chunks_of_run(m, Vector2i(5, 35))
	assert_true(none.has(EdgeLines.chunk_of(Vector2i(5, 35))))
	assert_lt(none.size(), along.size())
