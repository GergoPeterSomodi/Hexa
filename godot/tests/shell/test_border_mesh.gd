## Shell tests for border rendering in EdgeLineLayer and TileMapView
## (docs/architecture/m2-build-spec.md sections 6.1, 6.3, and 10).
extends GutTest


func _make_map(cols: int, rows: int) -> MapData:
	var map := MapData.new()
	map.id = "border_mesh_fixture"
	map.allocate(cols, rows)
	map.land.fill(1)
	map.cover.fill(0)
	return map


func _palette() -> PackedColorArray:
	return PackedColorArray([
		Color("#d8ccb0"),
		Color("#be3c6e"),
		Color("#3460b2"),
	])


func test_edge_line_layer_draws_bands_before_ink_with_given_vertex_colours() -> void:
	var layer := EdgeLineLayer.new()
	add_child_autofree(layer)
	var edge_col := Color(0.8, 0.2, 0.3, 0.85)
	var inner_col := Color(0.8, 0.2, 0.3, 0.0)
	var ink_col := Color(0.11, 0.08, 0.05, 0.85)
	# Pass border before border_band to verify EdgeLineLayer orders bands before ink.
	var lines: Array[Dictionary] = [
		{
			"kind": "border",
			"points": PackedVector2Array([Vector2(104.0, 25.5), Vector2(104.0, 76.5)]),
			"width": BorderLines.INK_WIDTH,
			"colour": ink_col,
		},
		{
			"kind": "border_band",
			"polygon": PackedVector2Array([
				Vector2(104.0, 25.5), Vector2(104.0, 76.5),
				Vector2(98.0, 73.0), Vector2(98.0, 29.0),
			]),
			"colours": PackedColorArray([edge_col, edge_col, inner_col, inner_col]),
		},
	]
	layer.set_lines(lines)
	assert_eq(layer.surface_count(), 1)
	var verts := layer.vertices()
	var cols := layer.colours()
	var idx := layer.indices()
	assert_eq(verts.size(), 8, "4 band vertices + 4 border stroke vertices")
	assert_eq(idx.size(), 12, "2 band triangles + 2 border stroke triangles")
	# First 6 indices belong to the band (vertices 0..3).
	for k: int in 6:
		assert_lt(idx[k], 4, "band indices are emitted before ink")
	# Next 6 indices belong to the ink stroke (vertices 4..7).
	for k: int in range(6, 12):
		assert_gte(idx[k], 4, "ink indices follow bands")
	assert_eq(cols[0], edge_col)
	assert_eq(cols[1], edge_col)
	assert_eq(cols[2], inner_col)
	assert_eq(cols[3], inner_col)
	for v: int in range(4, 8):
		assert_eq(cols[v], ink_col)


func test_tile_map_view_borders_layer_and_free_on_empty_chunk() -> void:
	var tiles := TilesetBuilder.load_season("summer")
	var view := TileMapView.new()
	view.setup(tiles)
	add_child_autofree(view)

	var borders := view.get_node_or_null("Borders") as Node2D
	assert_not_null(borders)
	assert_eq(borders.z_index, TileMapView.BORDERS_Z)
	assert_eq(TileMapView.BORDERS_Z, 85)
	assert_eq(borders.scale, Vector2.ONE)

	var map := _make_map(4, 4)
	var owner := PackedByteArray()
	owner.resize(map.hex_count())
	owner[0] = 1
	owner[1] = 2
	var lines := BorderLines.for_chunk(map, owner, Vector2i.ZERO, _palette())
	assert_gt(lines.size(), 0)

	view.set_chunk_borders(Vector2i.ZERO, lines)
	assert_eq(view.border_chunks(), [Vector2i.ZERO] as Array[Vector2i])
	assert_eq(borders.get_child_count(), 1)
	var node := borders.get_child(0) as EdgeLineLayer
	assert_not_null(node)
	assert_eq(node.surface_count(), 1)

	view.set_chunk_borders(Vector2i.ZERO, [] as Array[Dictionary])
	assert_eq(view.border_chunks(), [] as Array[Vector2i])
	assert_eq(borders.get_child_count(), 0)
	assert_true(node.is_queued_for_deletion())
	await get_tree().process_frame
	assert_false(is_instance_valid(node), "set_chunk_borders([]) frees the node")


func test_partial_chunk_rebuild_and_visibility() -> void:
	var tiles := TilesetBuilder.load_season("summer")
	var view := TileMapView.new()
	view.setup(tiles)
	add_child_autofree(view)

	var map := _make_map(40, 40)
	var owner := PackedByteArray()
	owner.resize(map.hex_count())
	owner.fill(2)
	for r: int in 10:
		for c: int in 10:
			owner[r * 40 + c] = 1
	for r: int in 10:
		owner[r * 40 + 32] = 1  # border inside chunk (1, 0) away from chunk (0, 0)

	var palette := _palette()
	view.set_borders(map, owner, palette)
	assert_true(view.border_chunks().has(Vector2i(0, 0)))
	assert_true(view.border_chunks().has(Vector2i(1, 0)))
	assert_false(view.border_chunks().has(Vector2i(1, 1)), "uniform chunk creates no node")

	var borders := view.get_node("Borders") as Node2D
	var chunk00 := borders.get_node("Borders_0_0") as EdgeLineLayer
	var chunk10 := borders.get_node("Borders_1_0") as EdgeLineLayer
	assert_not_null(chunk00)
	assert_not_null(chunk10)

	# Change a hex deep inside chunk (0, 0): only chunk (0, 0) is rebuilt.
	var inner_hex := Vector2i(5, 5)
	owner[map.index_of(inner_hex)] = 2
	view.rebuild_borders(map, owner, palette, [inner_hex])
	assert_ne(borders.get_node("Borders_0_0"), chunk00, "touched chunk (0, 0) was rebuilt")
	assert_same(borders.get_node("Borders_1_0"), chunk10, "untouched chunk (1, 0) kept its node")

	# Visibility toggle preserves chunks.
	view.set_borders_visible(false)
	assert_false(borders.visible)
	assert_eq(view.border_chunks().size(), 2)
	view.set_borders_visible(true)
	assert_true(borders.visible)
	await get_tree().process_frame


func test_borders_stay_aligned_in_half_resolution_mode() -> void:
	var tiles := TilesetBuilder.load_season("summer", true)
	var view := TileMapView.new()
	view.setup(tiles)
	add_child_autofree(view)
	assert_true(view.is_half())
	assert_eq(view.layer("ground").scale, Vector2(2.0, 2.0))

	var map := _make_map(4, 4)
	var owner := PackedByteArray()
	owner.resize(map.hex_count())
	owner.fill(1)
	owner[map.index_of(Vector2i(1, 1))] = 2
	view.set_borders(map, owner, _palette())

	var borders := view.get_node("Borders") as Node2D
	assert_eq(borders.scale, Vector2.ONE, "Borders node stays at world-pixel scale 1 in half mode")
	var chunk_node := borders.get_node("Borders_0_0") as EdgeLineLayer
	assert_eq(chunk_node.scale, Vector2.ONE)
	var centre := view.centre_of(Vector2i(1, 1))
	assert_lt(centre.distance_to(MapTiles.cell_centre(Vector2i(1, 1))), 0.01)
	var corners := BorderLines.hex_corners(Vector2i(1, 1))
	var verts := chunk_node.vertices()
	var found_corner := false
	for v: Vector2 in verts:
		if v.distance_to(corners[0]) < 0.01:
			found_corner = true
			break
	assert_true(found_corner, "border mesh vertices align with world-pixel hex corners in half mode")


## The castle-area lines are dashed (M7 B25): a 60 px line of 6 px dashes and 4 px gaps is 6 dashes, each a quad of 4 vertices
## in the owner's colour; a line of the kind is drawn only as dashes, never as a solid stroke.
func test_area_lines_are_dashes_in_their_colour() -> void:
	var layer := EdgeLineLayer.new()
	add_child_autofree(layer)
	var ink := Color(0.2, 0.4, 0.8, 0.9)
	var line := {"kind": "area", "points": PackedVector2Array([Vector2(0, 0), Vector2(60, 0)]), "colour": ink,
		"dash": 6.0, "gap": 4.0, "width": 1.6}
	layer.set_lines([line] as Array[Dictionary])
	assert_eq(layer.vertices().size(), 6 * 4, "six dashes of four vertices")
	for c: Color in layer.colours():
		assert_eq(c, ink, "every dash is the owner's colour")
