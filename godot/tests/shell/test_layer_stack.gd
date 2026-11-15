## The layer stack of the map view (docs/architecture/m1-build-spec.md section 5): z order of the layers, the groups,
## the sort points of the tiles, climate slots, the season swap that touches no cell, the sliced fill and the chunk lines.
extends GutTest

var _view: TileMapView = null
var _tiles: TilesetBuilder = null


func before_each() -> void:
	_tiles = TilesetBuilder.load_season("summer")
	_view = TileMapView.new()
	_view.setup(_tiles)
	add_child_autofree(_view)


func _first(prefix: String) -> String:
	var found: Array[String] = []
	for tile_name: String in _tiles.names:
		if tile_name.begins_with(prefix):
			found.append(tile_name)
	found.sort()
	assert_gt(found.size(), 0, "a tile named %s..." % prefix)
	return "" if found.is_empty() else found[0]


## The sort point and the rank of a tile in a season's TileSet (slot 0).
func _data(tile_name: String) -> TileData:
	var at := _tiles.names[tile_name]
	var atlas := _tiles.tile_set.get_source(3 * at.x) as TileSetAtlasSource
	return atlas.get_tile_data(Vector2i(at.y, at.z), 0)


func test_layers_have_the_z_of_the_table() -> void:
	var want := {
		"ground": 0, "shade": 10, "light": 11, "sea": 20, "coast": 30, "piece_ground": 40, "addon_ground": 41,
		"grid": 45, "marks": 90,
	}
	for layer_name: String in want:
		assert_eq(_view.layer(layer_name).z_index, int(want[layer_name]), layer_name)
		assert_eq(_view.layer(layer_name).get_parent(), _view, "%s is a plain layer of the view" % layer_name)
	assert_eq((_view.layer("shade").material as CanvasItemMaterial).blend_mode, CanvasItemMaterial.BLEND_MODE_MUL)
	assert_eq((_view.layer("light").material as CanvasItemMaterial).blend_mode, CanvasItemMaterial.BLEND_MODE_ADD)


func test_lines_shadows_and_the_standing_group() -> void:
	var lines := _view.get_node("Lines") as Node2D
	var shadows := _view.get_node("Shadows") as CanvasGroup
	var standing := _view.get_node("Standing") as Node2D
	assert_eq(lines.z_index, 50)
	assert_eq(shadows.z_index, 60)
	assert_eq(standing.z_index, 70)
	assert_almost_eq(shadows.self_modulate.a, 0.18, 0.0001)
	assert_true(standing.y_sort_enabled)
	for layer_name: String in ["piece_shadow", "addon_shadow"]:
		assert_eq(_view.layer(layer_name).get_parent(), shadows, layer_name)
	var stand: Array[String] = ["relief", "trees0", "trees1", "trees2", "trees3", "trees4", "trees5", "piece_back",
		"piece_front", "addon"]
	for layer_name: String in stand:
		assert_eq(_view.layer(layer_name).get_parent(), standing, layer_name)
		assert_true(_view.layer(layer_name).y_sort_enabled, "%s is y-sorted" % layer_name)
		assert_eq(_view.layer(layer_name).z_index, 0, "%s takes the group's z" % layer_name)
	for layer_name: String in ["ground", "shade", "sea", "coast"]:
		assert_false(_view.layer(layer_name).y_sort_enabled, layer_name)
	# Every layer of the table is there, and the view's list is the table.
	assert_eq(TileMapView.LAYERS.size(), 20)


func test_sort_points_back_to_front_inside_a_hex() -> void:
	# Tree wedges 1 and 2 (-30), a back ridge (-14), a piece's back band (-12), wedges 0 and 3 (0), the front band
	# (+12), a full ridge (+20), wedges 4 and 5 (+30), a harbour on the south side (+34): all within 38 px.
	var wedge := {0: 0, 1: -30, 2: -30, 3: 0, 4: 30, 5: 30}
	for d: int in 6:
		assert_eq(_data("trees/broad/full/%d/0" % d).y_sort_origin, int(wedge[d]), "wedge %d" % d)
	assert_eq(_data(_first("relief/ridge_rock/full/")).y_sort_origin, 20)
	assert_eq(_data(_first("relief/hills_low/pass/")).y_sort_origin, 20)
	assert_eq(_data(_first("relief/hills_low/back/")).y_sort_origin, -14)
	var back := 0
	var front := 0
	var shadows := 0
	var addon_south := 0
	for tile_name: String in _tiles.names:
		if not tile_name.begins_with("piece/"):
			continue
		var y := _data(tile_name).y_sort_origin
		if tile_name.begins_with("piece/harbour_addon/"):
			if tile_name.ends_with("/front"):
				assert_eq(absi(y), 34, tile_name)
				addon_south += 1
		elif tile_name.ends_with("/back"):
			assert_eq(y, -12, tile_name)
			back += 1
		elif tile_name.ends_with("/front"):
			assert_eq(y, 12, tile_name)
			front += 1
		elif tile_name.ends_with("/shadow") or tile_name.ends_with("/ground"):
			shadows += 1
	assert_gt(back, 0)
	assert_gt(front, 0)
	assert_gt(shadows, 0)
	assert_gt(addon_south, 0)


func test_ranks_of_the_ground_covers() -> void:
	# sand 0, farmland 1, grassland 2, marsh 3, tundra 4, woods 5, rock 6, snow 7
	var rank := {"sand": 0, "farmland": 1, "grassland": 2, "marsh": 3, "tundra": 4, "woods": 5, "rock": 6, "snow": 7}
	for cover: String in rank:
		assert_eq(_data(_first("ground/%s/" % cover)).z_index, int(rank[cover]), cover)
	assert_eq(_data(_first("sea/shelf/")).z_index, 0)
	assert_eq(_data(_first("sea/deep/")).z_index, 2)


func test_set_tile_uses_the_slot_of_the_hexs_climate() -> void:
	var climate := PackedByteArray([0, 1, 2, 2])
	_view.set_climates(2, climate)
	var ground := _first("ground/")
	var at := _tiles.names[ground]
	for i: int in 4:
		var cell := Vector2i(i % 2, int(i / 2.0))
		_view.set_tile("ground", cell, ground)
		assert_eq(_view.layer("ground").get_cell_source_id(cell), 3 * at.x + climate[i], "hex %s" % [cell])
		assert_eq(_view.layer("ground").get_cell_atlas_coords(cell), Vector2i(at.y, at.z))
	# Off the climate table: snow's slot.
	_view.set_tile("ground", Vector2i(9, 9), ground)
	assert_eq(_view.layer("ground").get_cell_source_id(Vector2i(9, 9)), 3 * at.x)


func test_a_cell_that_shows_the_tile_is_not_written_again() -> void:
	var ground := _first("ground/")
	_view.set_tile("ground", Vector2i(2, 2), ground)
	var writes := _view.cell_writes
	_view.set_tile("ground", Vector2i(2, 2), ground)
	_view.set_tile("trees0", Vector2i(2, 2), "")
	assert_eq(_view.cell_writes, writes)
	_view.set_tile("ground", Vector2i(2, 2), "")
	assert_eq(_view.cell_writes, writes + 1)
	assert_eq(_view.layer("ground").get_cell_source_id(Vector2i(2, 2)), -1)
	_view.set_tile("ground", Vector2i(2, 2), "no/such/tile")
	assert_eq(_view.missing_names(), ["no/such/tile"] as Array[String])


## A made-up hex: names for several layers, the same rule everywhere.
func _provider(hex: Vector2i) -> Dictionary:
	var out := {"ground": _first("ground/"), "grid": "mark/grid"}
	if (hex.x + hex.y) % 3 == 0:
		out["trees2"] = "trees/broad/full/2/0"
		out["relief"] = _first("relief/hills_low/full/")
	if hex.x % 5 == 0:
		out["coast"] = _first("coast/beach/")
	return out


func test_set_cells_and_set_hex() -> void:
	_view.set_cells({"ground": {Vector2i(0, 0): _first("ground/"), Vector2i(1, 0): _first("ground/")}})
	assert_eq(_view.layer("ground").get_used_cells().size(), 2)
	_view.set_hex(Vector2i(3, 3), _provider(Vector2i(3, 3)))
	assert_ne(_view.layer("grid").get_cell_source_id(Vector2i(3, 3)), -1)
	assert_eq(_view.missing_names().size(), 0)


func test_a_season_swap_touches_no_cell() -> void:
	var cols := 40
	var rows := 30
	var climate := PackedByteArray()
	climate.resize(cols * rows)
	for i: int in climate.size():
		climate[i] = int(i / 7.0) % 3  # patches of climate
	_view.set_climates(cols, climate)
	_view.begin_fill(cols, rows, _provider, Vector2i(20, 15))
	while _view.fill_step(500):
		pass
	assert_false(_view.is_filling())
	var cells := _view.cell_count()
	assert_gt(cells, cols * rows)
	var writes := _view.cell_writes
	var before := _snapshot()
	_view.set_season(TilesetBuilder.load_season("winter"))
	assert_eq(_view.season(), "winter")
	assert_eq(_view.layer("ground").tile_set, _view.layer("trees2").tile_set, "every layer shares the TileSet")
	assert_eq(_view.cell_writes, writes, "no cell was written")
	assert_eq(_snapshot(), before, "every cell holds what it held")
	assert_eq(_view.cell_count(), cells)
	_view.set_season(TilesetBuilder.load_season("autumn"))
	assert_eq(_view.cell_writes, writes)
	assert_eq(_snapshot(), before)
	assert_eq(_view.missing_names().size(), 0)


## (layer, cell) -> source and atlas place, for a few layers.
func _snapshot() -> Dictionary:
	var out := {}
	for layer_name: String in ["ground", "trees2", "relief", "coast", "grid"]:
		var layer := _view.layer(layer_name)
		for cell: Vector2i in layer.get_used_cells():
			out["%s %s" % [layer_name, cell]] = [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell)]
	return out


func test_the_fill_is_sliced_and_nearest_first() -> void:
	var cols := 100
	var rows := 60
	_view.begin_fill(cols, rows, _provider, Vector2i(90, 50))
	assert_true(_view.is_filling())
	assert_eq(_view.cell_count(), 0)
	watch_signals(_view)
	# One block of 16 x 16 hexes first: the one that holds the camera.
	_view.fill_step(256)
	assert_ne(_view.layer("ground").get_cell_source_id(Vector2i(90, 50)), -1, "the hex under the camera is there")
	assert_eq(_view.layer("ground").get_cell_source_id(Vector2i(2, 2)), -1, "the far corner is not yet")
	assert_almost_eq(_view.fill_progress(), 256.0 / 6000.0, 0.001)
	assert_signal_not_emitted(_view, "fill_finished")
	var steps := 0
	while _view.fill_step(TileMapView.FILL_PER_FRAME):
		steps += 1
	assert_lte(steps, 1, "6,000 hexes are two frames at 4,000 a frame")
	assert_signal_emitted(_view, "fill_finished")
	assert_eq(_view.layer("ground").get_used_cells().size(), cols * rows)
	assert_eq(_view.fill_progress(), 1.0)
	# A map that is not a multiple of the block: no hex outside it.
	_view.begin_fill(21, 19, _provider, Vector2i(0, 0))
	while _view.fill_step(100):
		pass
	assert_eq(_view.layer("ground").get_used_cells().size(), 21 * 19)


func test_chunk_lines_make_one_node_a_chunk() -> void:
	var line := {"kind": "road", "points": PackedVector2Array([Vector2(10, 10), Vector2(300, 40), Vector2(600, 20)]),
		"width": 3.4, "rank": 0}
	var lines: Array[Dictionary] = [line]
	_view.set_chunk_lines(Vector2i(0, 0), lines)
	assert_eq(_view.line_chunks(), [Vector2i(0, 0)] as Array[Vector2i])
	var node := _view.get_node("Lines").get_child(0) as EdgeLineLayer
	assert_eq(node.surface_count(), 1)
	# Replaced when the chunk's lines change; no lines frees it.
	_view.set_chunk_lines(Vector2i(0, 0), lines)
	assert_eq(_view.line_chunks().size(), 1)
	_view.set_chunk_lines(Vector2i(0, 0), [] as Array[Dictionary])
	assert_eq(_view.line_chunks().size(), 0)
	# A line over a chunk border is cut: one node in each chunk.
	var long := {"kind": "river", "points": PackedVector2Array([Vector2(3000, 50), Vector2(3300, 60), Vector2(3600, 70)]),
		"width": 4.6, "rank": 0}
	var all: Array[Dictionary] = [long]
	_view.set_lines(all)
	assert_eq(_view.line_chunks().size(), 2)


func test_the_hex_under_a_point_is_the_rules_hex() -> void:
	for hex: Vector2i in [Vector2i(0, 0), Vector2i(5, 3), Vector2i(7, 8)]:
		assert_eq(_view.hex_at(_view.centre_of(hex)), hex)
		assert_eq(_view.centre_of(hex), MapTiles.cell_centre(hex))
