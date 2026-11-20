## Shell tests for ModeOverlay, shader uniforms, FarMap.texture, and the 10,000-point
## MapModes.hex_at_px vs TileMapLayer.local_to_map twin check
## (docs/architecture/m2-build-spec.md sections 6.1, 6.2, and 10).
extends GutTest

const EDGE_MARGIN_PX := 0.5


func _make_map(cols: int, rows: int) -> MapData:
	var map := MapData.new()
	map.id = "overlay_fixture"
	map.allocate(cols, rows)
	for r: int in rows:
		for c: int in cols:
			var idx := r * cols + c
			var is_sea := (r == rows - 1 and c >= cols - 3)
			map.land[idx] = 0 if is_sea else 1
			map.cover[idx] = MapData.COVER_SEA if is_sea else 0
			map.height_m[idx] = (c * 120 + r * 80) if not is_sea else 0
	return map


func _make_owner(map: MapData) -> PackedByteArray:
	var owner := PackedByteArray()
	owner.resize(map.hex_count())
	for r: int in map.rows:
		for c: int in map.cols:
			var idx := r * map.cols + c
			if map.land[idx] == 0:
				owner[idx] = 0
			elif c * 2 < map.cols:
				owner[idx] = 1
			else:
				owner[idx] = 2
	return owner


func _make_palette() -> PackedColorArray:
	return MapModes.palette_from(PackedColorArray([
		Color("#be3c6e"),
		Color("#3460b2"),
		Color("#1ea08c"),
	]), Color("#d8ccb0"))


func _distance_to_hex_edge(px: Vector2, hex: Vector2i) -> float:
	var corners := BorderLines.hex_corners(hex)
	var best := INF
	for k: int in 6:
		var a := corners[k]
		var b := corners[(k + 1) % 6]
		var closest := Geometry2D.get_closest_point_to_segment(px, a, b)
		best = minf(best, px.distance_to(closest))
	return best


func test_hex_at_px_matches_tile_map_layer_on_10000_points() -> void:
	var tiles := TileSet.new()
	tiles.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tiles.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tiles.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tiles.tile_size = MapTiles.CELL
	var layer := TileMapLayer.new()
	layer.tile_set = tiles
	add_child_autofree(layer)

	var max_x := 30.5 * float(MapTiles.CELL.x)
	var max_y := 20.0 * MapTiles.ROW + float(MapTiles.CELL.y) - MapTiles.ROW
	var rng := Rng.new()
	rng.seed_with(1480)
	var edge_diffs: Array[String] = []
	var interior_diffs := 0
	for _i: int in 10000:
		var px := Vector2(rng.randf() * max_x, rng.randf() * max_y)
		var got := MapModes.hex_at_px(px)
		var want := layer.local_to_map(px)
		if got != want:
			var edge_dist := minf(_distance_to_hex_edge(px, want), _distance_to_hex_edge(px, got))
			if edge_dist <= EDGE_MARGIN_PX:
				edge_diffs.append("px=%s got=%s want=%s dist=%.4f" % [px, got, want, edge_dist])
			else:
				interior_diffs += 1
	if not edge_diffs.is_empty():
		gut.p("near-edge rounding diffs (<= %.1f px): %d" % [EDGE_MARGIN_PX, edge_diffs.size()])
	assert_eq(interior_diffs, 0, "MapModes.hex_at_px matches TileMapLayer.local_to_map on all interior points")


func test_overlay_textures_sizes_and_bytes() -> void:
	var map := _make_map(30, 20)
	var owner := _make_owner(map)
	var pal := _make_palette()
	var overlay := ModeOverlay.new()
	add_child_autofree(overlay)

	assert_eq(overlay.z_index, 80)
	assert_eq(overlay.texture_bytes(), 0)

	overlay.setup_from(map, owner, pal)

	assert_eq(overlay.owner_texture().get_size(), Vector2(30, 20))
	assert_eq(overlay.heights_texture().get_size(), Vector2(30, 20))
	assert_eq(overlay.palette_texture().get_size(), Vector2(256, 1))
	assert_eq(overlay.ramp_texture().get_size(), Vector2(256, 1))
	assert_eq(overlay.owner_texture().get_image().get_format(), Image.FORMAT_R8)
	assert_eq(overlay.heights_texture().get_image().get_format(), Image.FORMAT_R8)
	assert_eq(overlay.palette_texture().get_image().get_format(), Image.FORMAT_RGBA8)
	assert_eq(overlay.ramp_texture().get_image().get_format(), Image.FORMAT_RGBA8)
	assert_eq(overlay.texture_bytes(), 2 * 30 * 20 + 2 * 256 * 4)

	var owner_img := overlay.owner_texture().get_image()
	var h_img := overlay.heights_texture().get_image()
	var expected_h := MapModes.height_bytes(map)
	for hex: Vector2i in [Vector2i(0, 0), Vector2i(14, 10), Vector2i(29, 19)]:
		var idx := map.index_of(hex)
		assert_eq(owner_img.get_pixelv(hex).r8, int(owner[idx]))
		assert_eq(h_img.get_pixelv(hex).r8, int(expected_h[idx]))


func test_set_mode_and_tint_change_only_uniforms_and_visibility() -> void:
	var map := _make_map(10, 8)
	var overlay := ModeOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_from(map, _make_owner(map), _make_palette())

	var writes_before := overlay.texel_writes
	var updates_before := overlay.texture_updates
	var mat := overlay.material as ShaderMaterial
	assert_not_null(mat)

	overlay.set_mode(MapModes.Mode.OWNER)
	assert_eq(int(mat.get_shader_parameter(&"mode")), int(MapModes.Mode.OWNER))
	assert_true(overlay.visible)

	overlay.set_mode(MapModes.Mode.RELIEF)
	assert_eq(int(mat.get_shader_parameter(&"mode")), int(MapModes.Mode.RELIEF))
	assert_true(overlay.visible)

	overlay.set_mode(MapModes.Mode.TERRAIN)
	assert_eq(int(mat.get_shader_parameter(&"mode")), int(MapModes.Mode.TERRAIN))
	assert_true(overlay.visible)

	overlay.set_tint(false)
	assert_false(bool(mat.get_shader_parameter(&"tint_on")))
	assert_false(overlay.visible, "Terrain mode with tint off hides ModeOverlay")

	overlay.set_mode(MapModes.Mode.OWNER)
	assert_true(overlay.visible, "Owner mode remains visible even when Terrain tint is off")

	overlay.set_mode(MapModes.Mode.TERRAIN)
	assert_false(overlay.visible)
	overlay.set_tint(true)
	assert_true(overlay.visible)

	overlay.set_hot(2)
	assert_eq(int(mat.get_shader_parameter(&"hot_id")), 2)

	assert_eq(overlay.texel_writes, writes_before, "mode, tint, and hot switches write zero texels")
	assert_eq(overlay.texture_updates, updates_before, "mode, tint, and hot switches do zero GPU uploads")


func test_update_hexes_rewrites_only_requested_texels() -> void:
	var map := _make_map(12, 10)
	var owner := _make_owner(map)
	var overlay := ModeOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_from(map, owner, _make_palette())

	var changed: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 3), Vector2i(11, 0)]
	for hex: Vector2i in changed:
		owner[map.index_of(hex)] = 3
	var with_oob := changed.duplicate()
	with_oob.append(Vector2i(-1, 0))
	with_oob.append(Vector2i(12, 0))

	var writes_before := overlay.texel_writes
	var updates_before := overlay.texture_updates
	overlay.update_hexes(with_oob, owner)

	assert_eq(overlay.texel_writes - writes_before, 3, "only valid on-map hexes are counted")
	assert_eq(overlay.texture_updates - updates_before, 1, "one batch triggers one GPU texture update")
	var img := overlay.owner_image()
	for hex: Vector2i in changed:
		assert_eq(img.get_pixelv(hex).r8, 3)
	assert_eq(img.get_pixel(0, 0).r8, 1, "untouched hex keeps its owner")


func test_minimap_material_shares_textures_and_sets_from_uv() -> void:
	var map := _make_map(8, 6)
	var overlay := ModeOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_from(map, _make_owner(map), _make_palette())

	var mm := overlay.material_for_minimap()
	assert_not_null(mm)
	var main_mat := overlay.material as ShaderMaterial
	assert_ne(mm, main_mat)
	assert_true(bool(mm.get_shader_parameter(&"from_uv")))
	assert_false(bool(main_mat.get_shader_parameter(&"from_uv")))
	assert_same(mm.get_shader_parameter(&"owner_ids"), overlay.owner_texture())
	assert_same(mm.get_shader_parameter(&"heights"), overlay.heights_texture())
	assert_same(mm.get_shader_parameter(&"palette"), overlay.palette_texture())
	assert_same(mm.get_shader_parameter(&"ramp"), overlay.ramp_texture())

	# Live palette update updates the shared palette ImageTexture in-place (same RID/reference).
	var pal_tex_before := overlay.palette_texture()
	var new_pal := MapModes.palette_from(PackedColorArray([Color("#ff0000"), Color("#00ff00")]), Color("#d8ccb0"))
	overlay.set_palette_colours(new_pal)
	assert_same(mm.get_shader_parameter(&"palette"), pal_tex_before)
	assert_true(overlay.palette_image().get_pixel(1, 0).is_equal_approx(Color("#ff0000")))


func test_far_map_texture_returns_null_before_build_and_image_texture_after() -> void:
	var far := FarMap.new()
	add_child_autofree(far)
	assert_null(far.texture(), "FarMap.texture() is null before setup")

	var map := _make_map(6, 5)
	var state := MapState.create(map)
	far.setup(map, state)
	var tex := far.texture()
	assert_not_null(tex)
	assert_eq(tex.get_size(), Vector2(FarPicture.size_of(map)))


# ----- Yields (M4.5 I4b, docs/architecture/m4-5-build-spec.md 6.7) ------------------------------------------------------


func _yield_fixture(overlay: ModeOverlay, cols: int = 12, rows: int = 10) -> MapData:
	var map := _make_map(cols, rows)
	add_child_autofree(overlay)
	overlay.setup_from(map, _make_owner(map), _make_palette())
	return map


func test_yield_textures_exist_with_the_ramp_and_uniforms() -> void:
	var overlay := ModeOverlay.new()
	var map := _yield_fixture(overlay, 30, 20)
	assert_eq(overlay.yields_texture().get_size(), Vector2(30, 20))
	assert_eq(overlay.yield_ramp_texture().get_size(), Vector2(256, 1))
	assert_eq(overlay.yields_texture().get_image().get_format(), Image.FORMAT_R8)
	assert_eq(overlay.yield_ramp_texture().get_image().get_format(), Image.FORMAT_RGBA8)
	assert_eq(overlay.yields_texture_bytes(), 30 * 20 + 256 * 4)
	assert_eq(overlay.yields_bytes().size(), map.hex_count())
	assert_eq(overlay.yields_bytes().count(0), map.hex_count(), "zeros before any update")
	var ramp := overlay.yield_ramp_texture().get_image()
	for b: int in range(1, 10):
		assert_true(ramp.get_pixel(b, 0).is_equal_approx(MapModes.YIELD_COLOURS[b - 1]), "ramp byte %d" % b)
	assert_eq(ramp.get_pixel(0, 0).a8, 0, "byte 0 is clear")
	var mat := overlay.material as ShaderMaterial
	assert_same(mat.get_shader_parameter(&"yields"), overlay.yields_texture())
	assert_same(mat.get_shader_parameter(&"yield_ramp"), overlay.yield_ramp_texture())
	assert_almost_eq(float(mat.get_shader_parameter(&"yield_alpha")), MapModes.YIELD_ALPHA, 0.0001)
	assert_almost_eq(float(mat.get_shader_parameter(&"veil_alpha")), MapModes.VEIL_ALPHA, 0.0001)
	assert_almost_eq(float(mat.get_shader_parameter(&"stripe_px")), MapModes.STRIPE_PX, 0.0001)
	overlay.set_mode(MapModes.Mode.YIELDS)
	assert_eq(int(mat.get_shader_parameter(&"mode")), 3)
	assert_true(overlay.visible)
	overlay.set_tint(false)
	assert_true(overlay.visible, "Yields stays visible with the Terrain tint off")


func test_update_yields_writes_only_the_changed_texels() -> void:
	var overlay := ModeOverlay.new()
	var map := _yield_fixture(overlay)
	var bytes := PackedByteArray()
	bytes.resize(map.hex_count())
	var writes := overlay.texel_writes
	var updates := overlay.texture_updates
	assert_eq(overlay.update_yields(bytes), 0, "all zeros: nothing differs")
	assert_eq(overlay.texel_writes, writes)
	assert_eq(overlay.texture_updates, updates, "and no upload")

	bytes[map.index_of(Vector2i(3, 2))] = 7
	assert_eq(overlay.update_yields(bytes), 1, "one changed byte, one texel")
	assert_eq(overlay.texel_writes - writes, 1)
	assert_eq(overlay.texture_updates - updates, 1, "one upload")
	assert_eq(overlay.yields_image().get_pixelv(Vector2i(3, 2)).r8, 7)
	assert_eq(overlay.yields_bytes()[map.index_of(Vector2i(3, 2))], 7)

	assert_eq(overlay.update_yields(bytes), 0, "the same bytes again write nothing")
	assert_eq(overlay.texel_writes - writes, 1)
	assert_eq(overlay.texture_updates - updates, 1)

	bytes[map.index_of(Vector2i(3, 2))] = 0
	bytes[map.index_of(Vector2i(0, 0))] = 1
	bytes[map.index_of(Vector2i(11, 9))] = 9
	assert_eq(overlay.update_yields(bytes), 3)
	assert_eq(overlay.texture_updates - updates, 2, "one upload a batch")
	assert_eq(overlay.yields_image().get_pixelv(Vector2i(3, 2)).r8, 0)
	assert_eq(overlay.yields_image().get_pixelv(Vector2i(11, 9)).r8, 9)

	assert_eq(overlay.update_yields(PackedByteArray([1, 2, 3])), 0, "bytes of the wrong size are ignored")
	assert_eq(overlay.texture_updates - updates, 2)
	assert_eq(overlay.update_yields(bytes), 0)


func test_the_minimap_material_shares_the_yield_textures() -> void:
	var overlay := ModeOverlay.new()
	_yield_fixture(overlay, 8, 6)
	overlay.set_mode(MapModes.Mode.YIELDS)
	var mm := overlay.material_for_minimap()
	assert_same(mm.get_shader_parameter(&"yields"), overlay.yields_texture())
	assert_same(mm.get_shader_parameter(&"yield_ramp"), overlay.yield_ramp_texture())
	assert_eq(int(mm.get_shader_parameter(&"mode")), 3, "the minimap shows Yields too")


func test_sync_yields_only_computes_in_yields_and_when_the_version_moved() -> void:
	var game := EconomyFixture.game(&"GEN")
	var overlay := ModeOverlay.new()
	add_child_autofree(overlay)
	overlay.setup(game)
	assert_eq(overlay.sync_yields(game, true), 0, "not in Yields: nothing is computed")
	assert_eq(overlay.yields_bytes().count(0), game.map.hex_count())
	overlay.set_mode(MapModes.Mode.YIELDS)
	var wrote := overlay.sync_yields(game, true)
	assert_gt(wrote, 0, "Genoa's land is coloured")
	assert_eq(overlay.yields_bytes(), MapModes.yield_bytes(game, &"GEN"))
	assert_eq(int(overlay.yields_bytes()[game.map.index_of(Vector2i(8, 13))]), 8)
	assert_eq(overlay.sync_yields(game), 0, "the same version: nothing")
	game.version += 1
	assert_eq(overlay.sync_yields(game), 0, "a new version with the same worth writes no texel")
	overlay.set_mode(MapModes.Mode.OWNER)
	var cached := overlay.yields_bytes()
	game.version += 1
	assert_eq(overlay.sync_yields(game), 0)
	assert_eq(overlay.yields_bytes(), cached, "leaving Yields keeps the texture and computes nothing")
