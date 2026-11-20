## MapCells and the chunk lines of EdgeLines (docs/architecture/m1-build-spec.md sections 5, 6 and 10): the tile of every
## layer of a hex from MapData and MapState, every tile existing in assets/tiles/summer/index.json on north Italy and on a
## 60 x 40 fake map (wild and after 500 random builds), crossings on crossing0..2, and the lines of a chunk cut as the
## whole map's lines are cut.
extends GutTest

const NORTH_ITALY := "res://data/maps/north_italy.tres"
const SUMMER_INDEX := "res://assets/tiles/summer/index.json"

var _north_italy: MapData = null
var _north_italy_state: MapState = null
var _summer: Dictionary = {}
var _seed := 12345


func before_all() -> void:
	_north_italy = load(NORTH_ITALY) as MapData
	_north_italy_state = Game.new_game(_north_italy, 1480).state
	_summer = _summer_names()


func _map() -> MapData:
	return _north_italy


func _state(_m: MapData) -> MapState:
	return _north_italy_state.duplicate_state()


func _next(n: int) -> int:
	_seed = (_seed * 1103515245 + 12345) & 0x7fffffff
	return (_seed >> 8) % n


## The tile names of the summer tileset (assets/tiles/summer/index.json) as a set, with "" in it.
func _summer_names() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SUMMER_INDEX))
	var index: Dictionary = parsed
	var have: Dictionary = {"": true}
	for source: Dictionary in index["sources"]:
		for tile: Dictionary in source["tiles"]:
			have[str(tile["name"])] = true
	return have


## A piece's back or shadow part is omitted from the bake when nothing stands in that band (the view clears the cell).
func _in_tileset(tile_name: String) -> bool:
	if _summer.has(tile_name):
		return true
	return tile_name.begins_with("piece/") and (tile_name.ends_with("/back") or tile_name.ends_with("/shadow"))


func _missing_on_map(m: MapData, s: MapState) -> Array[String]:
	var missing: Dictionary = {}
	for i: int in m.hex_count():
		var cells := MapCells.of_hex(m, s, m.hex_of(i))
		for layer_name: String in cells:
			var tile_name := str(cells[layer_name])
			if not _in_tileset(tile_name):
				missing[tile_name] = true
	var out: Array[String] = []
	out.assign(missing.keys())
	out.sort()
	return out


func test_north_italy_wild_and_built_names_are_in_the_summer_tileset() -> void:
	var m := _map()
	var wild := MapState.create(m)
	var built := _state(m)
	assert_eq(_missing_on_map(m, wild), [] as Array[String], "wild north Italy has no missing tile")
	assert_eq(_missing_on_map(m, built), [] as Array[String], "built north Italy has no missing tile")
	var built_hexes := 0
	var crossings := 0
	for i: int in m.hex_count():
		var hex := m.hex_of(i)
		var got := MapCells.of_hex(m, built, hex)
		built_hexes += 1 if got["piece_ground"] != "" else 0
		var want_crossings := Crossings.of_hex(m, hex)
		for layer_name: String in Crossings.LAYERS:
			assert_eq(got[layer_name], want_crossings[layer_name], "hex %s %s" % [hex, layer_name])
			if str(got[layer_name]) != "":
				assert_true(_summer.has(str(got[layer_name])), str(got[layer_name]))
				crossings += 1
	assert_gt(built_hexes, 50, "north Italy has built hexes")
	assert_eq(crossings, Crossings.all_of(m).size(), "every crossing of north Italy is on crossing0..2")


func test_fake_map_wild_and_after_500_random_builds_has_no_missing_tile() -> void:
	var m := FakeMap.build(60, 40, 1480)
	var s := MapState.create(m)
	assert_eq(_missing_on_map(m, s), [] as Array[String], "wild 60x40 fake map has no missing tile")
	var game := Game.with_state(m, s)
	var land_hexes: Array[Vector2i] = []
	for i: int in m.hex_count():
		if m.land[i] == 1:
			land_hexes.append(m.hex_of(i))
	var builds := 0
	var attempts := 0
	while builds < 500 and attempts < 4000:
		attempts += 1
		var hex := land_hexes[_next(land_hexes.size())]
		var idx := m.index_of(hex)
		if game.state.main_use[idx] == ImproveRules.NONE:
			var options := Improve.build_options(game, hex)
			var allowed: Array[int] = []
			for opt: Dictionary in options:
				if bool(opt["ok"]):
					allowed.append(int(opt["family_id"]))
			if not allowed.is_empty():
				var fam := allowed[_next(allowed.size())]
				game.state.main_use[idx] = fam
				game.state.level[idx] = 1 + _next(ImproveRules.TOP_LEVEL[fam])
				builds += 1
		else:
			game.state.main_use[idx] = ImproveRules.NONE
			game.state.level[idx] = 0
			builds += 1
	assert_eq(builds, 500, "500 random builds completed")
	assert_eq(_missing_on_map(m, game.state), [] as Array[String], "60x40 fake map after 500 random builds has no missing tile")


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


## The lines of the whole map built in one pass, for the reference.
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


func test_piece_cells_equal_the_piece_layers_of_of_hex_for_every_piece_of_north_italy() -> void:
	var map := _map()
	var state := _state(map)
	var improved := WorldImprove.build(map, 7)
	for hex: Vector2i in improved.hexes:
		var f := improved.family_at(hex)
		if f != ImproveRules.NONE:
			state.main_use[map.index_of(hex)] = f
			state.level[map.index_of(hex)] = improved.level_at(hex)
	var pieces := 0
	for hex: Vector2i in improved.hexes:
		var piece := Improve.piece_of(map, state, hex)
		if piece.is_empty():
			assert_true(MapCells.piece_cells(map, piece, hex).is_empty())
			continue
		pieces += 1
		var again := Improve.piece_for(map, hex, int(piece["family_id"]), int(piece["level"]))
		assert_eq(again, piece, "piece_for is piece_of's answer at %s" % hex)
		var cells := MapCells.piece_cells(map, again, hex)
		var all := MapCells.of_hex(map, state, hex)
		for layer: String in MapCells.LAYERS.slice(MapCells.AT_PIECE, MapCells.AT_ADDON + 1):
			assert_eq(str(cells.get(layer, "")), str(all[layer]), "%s on %s" % [layer, hex])
	assert_gt(pieces, 100, "north Italy has pieces")
	assert_true(Improve.piece_for(map, Vector2i(2, 2), ImproveRules.NONE, 0).is_empty())
