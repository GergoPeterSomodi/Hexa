## Shell tests for ModeOverlay, shader uniforms, FarMap.texture, and the 10,000-point
## MapModes.hex_at_px vs TileMapLayer.local_to_map twin check
## (docs/architecture/m2-build-spec.md sections 6.1, 6.2, and 10).
extends GutTest

const EDGE_MARGIN_PX := 0.5
const PAVIA := Vector2i(10, 9)  # Milan's walled castle on seed 1480 (spec 4.3): a held area of seven hexes


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


# ----- Food (M5 P14, docs/architecture/m5-build-spec.md 6.5) ------------------------------------------------------------


func test_food_textures_exist_with_the_ramp_and_uniforms() -> void:
	var overlay := ModeOverlay.new()
	var map := _yield_fixture(overlay, 30, 20)
	assert_eq(overlay.food_texture().get_size(), Vector2(30, 20))
	assert_eq(overlay.food_ramp_texture().get_size(), Vector2(256, 1))
	assert_eq(overlay.food_texture().get_image().get_format(), Image.FORMAT_R8)
	assert_eq(overlay.food_ramp_texture().get_image().get_format(), Image.FORMAT_RGBA8)
	assert_eq(overlay.food_texture_bytes(), 30 * 20 + 256 * 4)
	assert_eq(overlay.food_bytes().size(), map.hex_count())
	assert_eq(overlay.food_bytes().count(0), map.hex_count(), "zeros before any update")
	var ramp := overlay.food_ramp_texture().get_image()
	var want := MapModes.food_ramp()
	for b: int in 10:
		assert_eq(ramp.get_pixel(b, 0).to_rgba32(), want[b].to_rgba32(), "ramp entry %d" % b)
	var mat := overlay.material as ShaderMaterial
	assert_same(mat.get_shader_parameter(&"food"), overlay.food_texture())
	assert_same(mat.get_shader_parameter(&"food_ramp"), overlay.food_ramp_texture())
	assert_almost_eq(float(mat.get_shader_parameter(&"food_alpha")), MapModes.FOOD_ALPHA, 0.0001)
	overlay.set_tint(false)
	overlay.set_mode(MapModes.Mode.FOOD)
	assert_true(overlay.visible, "Food stays visible with the Terrain tint off")
	assert_eq(int(mat.get_shader_parameter(&"mode")), 4)
	var mm := overlay.material_for_minimap()
	assert_same(mm.get_shader_parameter(&"food"), overlay.food_texture(), "the minimap shares the Food textures")


func test_update_food_writes_only_the_changed_texels_and_a_planted_one_texel_fault_is_seen() -> void:
	var overlay := ModeOverlay.new()
	var map := _yield_fixture(overlay)
	var bytes := PackedByteArray()
	bytes.resize(map.hex_count())
	assert_eq(overlay.update_food(bytes), 0, "all zeros: nothing differs")
	assert_eq(overlay.texture_updates, 0)
	bytes[map.index_of(Vector2i(3, 2))] = 7
	var writes := overlay.texel_writes
	assert_eq(overlay.update_food(bytes), 1, "one changed byte, one texel")
	assert_eq(overlay.texel_writes, writes + 1)
	assert_eq(overlay.texture_updates, 1, "one texture update")
	assert_eq(overlay.food_image().get_pixelv(Vector2i(3, 2)).r8, 7)
	assert_eq(overlay.food_bytes()[map.index_of(Vector2i(3, 2))], 7)
	assert_eq(overlay.update_food(bytes), 0, "the same bytes again write nothing")
	assert_eq(overlay.texture_updates, 1)
	assert_eq(overlay.update_food(PackedByteArray([1, 2, 3])), 0, "bytes of the wrong size are ignored")
	# The planted fault: one texel of the texture differs from what the read model says.
	overlay.food_image().set_pixelv(Vector2i(5, 5), Color(3.0 / 255.0, 0.0, 0.0, 1.0))
	var wrong: Array[Vector2i] = []
	var img := overlay.food_image()
	for idx: int in map.hex_count():
		var at := map.hex_of(idx)
		if img.get_pixelv(at).r8 != int(bytes[idx]):
			wrong.append(at)
	assert_eq(wrong, [Vector2i(5, 5)] as Array[Vector2i], "the one planted texel is the one that disagrees")


func test_sync_food_only_computes_in_food_and_when_the_version_moved() -> void:
	var game := EconomyFixture.game(&"GEN")
	var overlay := ModeOverlay.new()
	add_child_autofree(overlay)
	overlay.setup(game)
	assert_eq(overlay.sync_food(game, true), 0, "not in Food: nothing is computed")
	assert_eq(overlay.food_bytes().count(0), game.map.hex_count())
	overlay.set_mode(MapModes.Mode.FOOD)
	var wrote := overlay.sync_food(game, true)
	assert_gt(wrote, 0, "Genoa's land is coloured")
	assert_eq(overlay.food_bytes(), MapModes.food_bytes(game, &"GEN"))
	assert_eq(overlay.sync_food(game), 0, "the same version: nothing")
	game.version += 1
	assert_eq(overlay.sync_food(game), 0, "a new version with the same food writes no texel")
	overlay.set_mode(MapModes.Mode.OWNER)
	var cached := overlay.food_bytes()
	game.version += 1
	assert_eq(overlay.sync_food(game), 0)
	assert_eq(overlay.food_bytes(), cached, "leaving Food keeps the texture and computes nothing")


# ----- Supply and the sight veil (M6 L17, docs/architecture/m6-build-spec.md 6.6) -----------------------------------------


func _supply_fixture(overlay: ModeOverlay, cols: int = 30, rows: int = 20) -> MapData:
	var map := _make_map(cols, rows)
	add_child_autofree(overlay)
	overlay.setup_from(map, _make_owner(map), _make_palette())
	return map


func test_supply_and_sight_textures_exist_with_the_ramp_and_uniforms() -> void:
	var overlay := ModeOverlay.new()
	var map := _supply_fixture(overlay)
	assert_eq(overlay.supply_texture().get_size(), Vector2(30, 20))
	assert_eq(overlay.supply_ramp_texture().get_size(), Vector2(256, 1))
	assert_eq(overlay.sight_texture().get_size(), Vector2(30, 20))
	assert_eq(overlay.supply_texture().get_image().get_format(), Image.FORMAT_R8)
	assert_eq(overlay.supply_ramp_texture().get_image().get_format(), Image.FORMAT_RGBA8)
	assert_eq(overlay.sight_texture().get_image().get_format(), Image.FORMAT_R8)
	assert_eq(overlay.supply_texture_bytes(), 2 * 30 * 20 + 256 * 4)
	assert_eq(overlay.supply_bytes().count(0), map.hex_count(), "zeros before any update")
	assert_eq(overlay.sight_bytes().count(1), map.hex_count(), "all seen before the first sync: no veil yet")
	var ramp := overlay.supply_ramp_texture().get_image()
	for b: int in range(1, 7):
		assert_true(ramp.get_pixel(b, 0).is_equal_approx(MapModes.SUPPLY_COLOURS[b - 1]), "ramp byte %d" % b)
	assert_eq(ramp.get_pixel(0, 0).a8, 0, "byte 0 is clear")
	assert_eq(ramp.get_pixel(7, 0).a8, 0, "bytes past the six are clear")
	var mat := overlay.material as ShaderMaterial
	assert_same(mat.get_shader_parameter(&"supply"), overlay.supply_texture())
	assert_same(mat.get_shader_parameter(&"supply_ramp"), overlay.supply_ramp_texture())
	assert_same(mat.get_shader_parameter(&"sight"), overlay.sight_texture())
	assert_almost_eq(float(mat.get_shader_parameter(&"supply_alpha")), MapModes.SUPPLY_ALPHA, 0.0001)
	assert_almost_eq(float(mat.get_shader_parameter(&"sight_alpha")), MapModes.SIGHT_VEIL_ALPHA, 0.0001)
	overlay.set_mode(MapModes.Mode.SUPPLY)
	assert_eq(int(mat.get_shader_parameter(&"mode")), 5)
	overlay.set_tint(false)
	assert_true(overlay.visible, "Supply stays visible with the Terrain tint off")
	var mm := overlay.material_for_minimap()
	assert_same(mm.get_shader_parameter(&"supply"), overlay.supply_texture(), "the minimap shares the Supply textures")
	assert_same(mm.get_shader_parameter(&"sight"), overlay.sight_texture(), "and the sight texture")


func test_update_supply_writes_only_the_changed_texels() -> void:
	var overlay := ModeOverlay.new()
	var map := _supply_fixture(overlay)
	var bytes := PackedByteArray()
	bytes.resize(map.hex_count())
	var writes := overlay.texel_writes
	var updates := overlay.texture_updates
	assert_eq(overlay.update_supply(bytes), 0, "all zeros: nothing differs")
	assert_eq(overlay.texture_updates, updates, "and no upload")
	bytes[map.index_of(Vector2i(3, 2))] = 5
	assert_eq(overlay.update_supply(bytes), 1, "one changed byte, one texel")
	assert_eq(overlay.texel_writes - writes, 1)
	assert_eq(overlay.texture_updates - updates, 1, "one upload")
	assert_eq(overlay.supply_image().get_pixelv(Vector2i(3, 2)).r8, 5)
	assert_eq(overlay.supply_bytes()[map.index_of(Vector2i(3, 2))], 5)
	assert_eq(overlay.update_supply(bytes), 0, "the same bytes again write nothing")
	assert_eq(overlay.update_supply(PackedByteArray([1, 2, 3])), 0, "bytes of the wrong size are ignored")
	assert_eq(overlay.texture_updates - updates, 1)


func test_update_sight_writes_only_the_changed_texels() -> void:
	var overlay := ModeOverlay.new()
	var map := _supply_fixture(overlay)
	var bytes := PackedByteArray()
	bytes.resize(map.hex_count())
	bytes.fill(1)
	var writes := overlay.texel_writes
	var updates := overlay.texture_updates
	assert_eq(overlay.update_sight(bytes), 0, "all seen: nothing differs from the start")
	assert_eq(overlay.texture_updates, updates)
	bytes[map.index_of(Vector2i(4, 4))] = 0
	assert_eq(overlay.update_sight(bytes), 1, "one unseen hex, one texel")
	assert_eq(overlay.texel_writes - writes, 1)
	assert_eq(overlay.texture_updates - updates, 1)
	assert_eq(overlay.sight_image().get_pixelv(Vector2i(4, 4)).r8, 0)
	assert_eq(overlay.sight_bytes()[map.index_of(Vector2i(4, 4))], 0)
	assert_eq(overlay.update_sight(bytes), 0, "the same bytes again write nothing")


func test_supply_and_sight_textures_hold_what_map_modes_says_at_every_hex() -> void:
	var game := EconomyFixture.game(&"GEN")
	var overlay := ModeOverlay.new()
	add_child_autofree(overlay)
	overlay.setup(game)
	overlay.set_mode(MapModes.Mode.SUPPLY)
	assert_gt(overlay.sync_supply(game, true), 0, "Genoa's land is coloured")
	assert_eq(overlay.supply_bytes(), MapModes.supply_bytes(game, &"GEN"), "the supply texture holds MapModes' bytes")
	overlay.sync_sight(game, true)
	assert_eq(overlay.sight_bytes(), MapModes.sight_bytes(game, &"GEN"), "the sight texture holds MapModes' sight")
	var heights := MapModes.height_bytes(game.map)
	var pal := MapModes.palette(game, false)
	var checked := 0
	for idx: int in game.map.hex_count():
		if heights[idx] == 0:
			continue
		var hex := game.map.hex_of(idx)
		var sb := int(overlay.supply_bytes()[idx])
		var want := MapModes.colour_at(game, MapModes.Mode.SUPPLY, hex, pal, true, 0, false)
		if sb >= 1 and sb <= 6:
			var ramp_colour := overlay.supply_ramp_texture().get_image().get_pixel(sb, 0)
			assert_true(want.is_equal_approx(Color(ramp_colour.r, ramp_colour.g, ramp_colour.b, MapModes.SUPPLY_ALPHA)), "hex %s byte %d" % [hex, sb])
		else:
			assert_true(want.is_equal_approx(Color(MapModes.VEIL.r, MapModes.VEIL.g, MapModes.VEIL.b, MapModes.VEIL_ALPHA)), "hex %s byte 0" % hex)
		checked += 1
	assert_gt(checked, 0, "Genoa's land was checked")


func test_the_sight_veil_follows_the_setting_and_the_unseen_land() -> void:
	var game := EconomyFixture.game(&"GEN")
	var overlay := ModeOverlay.new()
	add_child_autofree(overlay)
	overlay.setup(game)
	var mat := overlay.material as ShaderMaterial
	assert_false(overlay.is_sight_veil_on(), "off until MapScene applies map/sight_veil")
	overlay.set_mode(MapModes.Mode.TERRAIN)
	overlay.set_tint(false)
	assert_false(overlay.visible, "Terrain with the tint off and no veil: hidden")
	overlay.set_sight_veil(true)
	assert_true(overlay.is_sight_veil_on())
	assert_true(bool(mat.get_shader_parameter(&"sight_veil_on")))
	assert_true(overlay.visible, "with the veil on, Terrain shows over the unseen land")
	overlay.set_sight_veil(false)
	assert_false(bool(mat.get_shader_parameter(&"sight_veil_on")))
	assert_false(overlay.visible)
	overlay.sync_sight(game, true)
	var pal := MapModes.palette(game, false)
	var heights := MapModes.height_bytes(game.map)
	var unseen: Array[Vector2i] = []
	var seen_hex := Vector2i(-1, -1)
	for idx: int in game.map.hex_count():
		if heights[idx] == 0:
			continue
		if overlay.sight_bytes()[idx] == 0:
			unseen.append(game.map.hex_of(idx))
		elif seen_hex.x < 0:
			seen_hex = game.map.hex_of(idx)
	assert_gt(unseen.size(), 0, "Genoa has land nobody of hers sees")
	assert_true(seen_hex.x >= 0, "and Genoa sees some land")
	var hex: Vector2i = unseen[0]
	assert_eq(overlay.sight_image().get_pixelv(hex).r8, 0, "the texture marks it unseen")
	var off := MapModes.colour_at(game, MapModes.Mode.TERRAIN, hex, pal, true, 0, false)
	var on := MapModes.colour_at(game, MapModes.Mode.TERRAIN, hex, pal, true, 0, true)
	assert_false(on.is_equal_approx(off), "the veil changes the colour of an unseen hex")
	assert_true(MapModes.colour_at(game, MapModes.Mode.TERRAIN, seen_hex, pal, true, 0, true).is_equal_approx(
		MapModes.colour_at(game, MapModes.Mode.TERRAIN, seen_hex, pal, true, 0, false)), "a seen hex is not veiled")


func test_supply_is_offered_with_a_player_and_its_setting_word_is_supply() -> void:
	var game := EconomyFixture.game(&"GEN")
	assert_true(MapModes.modes(game).has(MapModes.Mode.SUPPLY), "Supply is in the cycle with a player")
	assert_eq(MapModes.mode_of(&"supply"), int(MapModes.Mode.SUPPLY), "the setting word is supply")
	assert_true(Settings.SCHEMA["state/map_mode"]["choices"].has("supply"), "and the setting accepts it")
	assert_eq(MapModes.legend_title(MapModes.Mode.SUPPLY), MapModes.SUPPLY_TITLE)


# --- M7: the occupied stripes and the castle-area tint (spec 6.3) ---------------------------------------------------


func _war_overlay(game: Game) -> ModeOverlay:
	var overlay := ModeOverlay.new()
	add_child_autofree(overlay)
	overlay.setup(game)
	return overlay


## The stripe band the shader computes (floor of (floor x + floor y) over the stripe width; the even bands are the occupier's),
## written out here so it can be checked against MapModes.stripe_is_occupier.
static func _shader_band_is_occupier(x: float, y: float) -> bool:
	var band := floorf((floorf(x) + floorf(y)) / MapModes.OCCUPIED_STRIPE_PX)
	return fposmod(band, 2.0) < 0.5


func test_occupier_and_area_textures_exist_with_the_uniforms() -> void:
	var overlay := ModeOverlay.new()
	var map := _supply_fixture(overlay)
	assert_eq(overlay.occupier_texture().get_size(), Vector2(30, 20))
	assert_eq(overlay.area_texture().get_size(), Vector2(30, 20))
	assert_eq(overlay.occupier_texture().get_image().get_format(), Image.FORMAT_R8)
	assert_eq(overlay.area_texture().get_image().get_format(), Image.FORMAT_R8)
	assert_eq(overlay.war_texture_bytes(), 2 * 30 * 20, "two R8 textures and no ramp")
	assert_eq(overlay.occupier_bytes().count(0), map.hex_count(), "no occupied land before the first sync")
	assert_eq(overlay.area_bytes().count(0), map.hex_count(), "no castle area before the first sync")
	assert_false(overlay.is_areas_on(), "the castle areas are off until the scene turns them on")
	var mat := overlay.material as ShaderMaterial
	assert_same(mat.get_shader_parameter(&"occupiers"), overlay.occupier_texture())
	assert_same(mat.get_shader_parameter(&"areas"), overlay.area_texture())
	assert_almost_eq(float(mat.get_shader_parameter(&"occupied_px")), MapModes.OCCUPIED_STRIPE_PX, 0.0001)
	assert_almost_eq(float(mat.get_shader_parameter(&"area_alpha")), MapModes.AREA_ALPHA, 0.0001)
	assert_false(bool(mat.get_shader_parameter(&"area_on")))


func test_update_occupiers_writes_only_the_changed_texels() -> void:
	var overlay := ModeOverlay.new()
	var map := _supply_fixture(overlay)
	var bytes := PackedByteArray()
	bytes.resize(map.hex_count())
	var writes := overlay.texel_writes
	var updates := overlay.texture_updates
	assert_eq(overlay.update_occupier_bytes(bytes), 0, "all zeros: nothing differs")
	assert_eq(overlay.texture_updates, updates, "and no upload")
	var hex := Vector2i(3, 2)
	bytes[map.index_of(hex)] = 2
	assert_eq(overlay.update_occupier_bytes(bytes), 1, "one occupied hex, one texel")
	assert_eq(overlay.texel_writes - writes, 1)
	assert_eq(overlay.texture_updates - updates, 1, "one upload")
	assert_eq(overlay.occupier_image().get_pixelv(hex).r8, 2)
	assert_eq(overlay.occupier_bytes()[map.index_of(hex)], 2)
	assert_eq(overlay.update_occupier_bytes(bytes), 0, "the same bytes again write nothing")
	assert_eq(overlay.update_occupier_bytes(PackedByteArray([1, 2, 3])), 0, "bytes of the wrong size are ignored")
	var changed: Array[Vector2i] = [hex]
	assert_eq(overlay.update_occupiers(changed, bytes), 0, "a hex already holding its byte writes nothing")
	bytes[map.index_of(hex)] = 0
	assert_eq(overlay.update_occupiers(changed, bytes), 1, "the hexes given write their changed texel")
	assert_eq(overlay.occupier_bytes()[map.index_of(hex)], 0)
	assert_eq(overlay.update_occupiers(changed, PackedByteArray([1, 2, 3])), 0, "no game and wrong-size bytes: nothing")


func test_occupier_and_area_textures_hold_what_map_modes_says_at_every_land_hex() -> void:
	var game := WarFixture.game()
	var me := ArmyFixture.TAG
	WarFixture.at_war(game, me, &"MLO")
	var member := game.map.hex_of(Occupation.members(game, PAVIA)[1])
	WarFixture.set_occupier(game, member, me)
	game.version += 1
	var overlay := _war_overlay(game)
	overlay.set_mode(MapModes.Mode.OWNER)
	overlay.sync_occupiers(game, true)
	overlay.set_areas_on(true)
	assert_eq(overlay.occupier_bytes(), MapModes.occupier_bytes(game), "the occupier texture holds MapModes' bytes")
	assert_eq(overlay.area_bytes(), MapModes.area_bytes(game, me), "the area texture holds the viewer's castle areas")
	assert_gt(overlay.area_bytes().count(1), 0, "Pavia's area is held")
	assert_eq(int(overlay.occupier_bytes()[game.map.index_of(member)]), Countries.by_tag(game, me).id,
		"the occupied hex holds its occupier")
	var pal := MapModes.palette(game, false)
	var heights := MapModes.height_bytes(game.map)
	var checked := 0
	for idx: int in game.map.hex_count():
		if heights[idx] == 0:
			continue
		var hex := game.map.hex_of(idx)
		var from_textures := MapModes.colour_of(MapModes.Mode.OWNER, Territory.owner_id(game, hex), int(heights[idx]), pal,
			true, 0, 0, 0, 0, 1, false, int(overlay.occupier_bytes()[idx]), int(overlay.area_bytes()[idx]))
		assert_true(from_textures.is_equal_approx(MapModes.colour_at(game, MapModes.Mode.OWNER, hex, pal, true, 0)),
			"hex %s" % str(hex))
		checked += 1
	assert_gt(checked, 0, "the land was checked")


func test_the_stripe_band_of_the_shader_is_the_one_map_modes_names() -> void:
	var wrong := 0
	for y: int in range(-40, 41):
		for x: int in range(-40, 41):
			for frac: float in [0.0, 0.5, 0.99]:
				var fx := float(x) + frac
				var fy := float(y) + frac * 0.5
				if _shader_band_is_occupier(fx, fy) != MapModes.stripe_is_occupier(floori(fx), floori(fy)):
					wrong += 1
	assert_eq(wrong, 0, "the shader's bands and stripe_is_occupier agree on every pixel tested")
	assert_true(MapModes.stripe_is_occupier(0, 0))
	assert_false(MapModes.stripe_is_occupier(8, 0), "the band after eight pixels is the owner's")
	assert_true(_shader_band_is_occupier(-9.0, 0.0), "the bands run on below zero too")
	assert_eq(_shader_band_is_occupier(-9.0, 0.0), MapModes.stripe_is_occupier(-9, 0))


func test_the_castle_area_tint_toggles_the_uniform_the_visibility_and_the_minimap_copy() -> void:
	var overlay := ModeOverlay.new()
	_supply_fixture(overlay)
	var mat := overlay.material as ShaderMaterial
	overlay.set_mode(MapModes.Mode.TERRAIN)
	overlay.set_tint(false)
	assert_false(overlay.visible, "Terrain with the tint off, no veil and no castle areas: hidden")
	overlay.set_areas_on(true)
	assert_true(overlay.is_areas_on())
	assert_true(bool(mat.get_shader_parameter(&"area_on")), "the uniform follows")
	assert_true(overlay.visible, "the castle-area tint shows in Terrain with the tint off")
	var mm := overlay.material_for_minimap()
	assert_true(bool(mm.get_shader_parameter(&"area_on")), "the minimap copy takes the state it was made with")
	assert_same(mm.get_shader_parameter(&"areas"), overlay.area_texture(), "and shares the area texture")
	assert_same(mm.get_shader_parameter(&"occupiers"), overlay.occupier_texture(), "and the occupier texture")
	overlay.set_areas_on(false)
	assert_false(bool(mat.get_shader_parameter(&"area_on")))
	assert_false(overlay.visible)
	assert_false(bool(overlay.material_for_minimap().get_shader_parameter(&"area_on")), "a new copy follows")


func test_sync_areas_computes_only_while_the_tint_is_on() -> void:
	var game := WarFixture.game()
	WarFixture.at_war(game, ArmyFixture.TAG, &"MLO")
	game.version += 1
	var overlay := _war_overlay(game)
	assert_eq(overlay.sync_areas(game), 0, "off: nothing is computed")
	assert_eq(overlay.area_bytes().count(1), 0, "and the texture holds no area")
	overlay.set_areas_on(true)
	assert_gt(overlay.area_bytes().count(1), 0, "on: the held area is brought up at once")
	assert_eq(overlay.sync_areas(game), 0, "the same version writes nothing")
	game.version += 1
	assert_eq(overlay.sync_areas(game), 0, "a new version with the same areas writes nothing")
	overlay.set_areas_on(false)
	assert_eq(overlay.sync_areas(game), 0, "off again: nothing is computed")


func test_sync_occupiers_follows_the_version_and_writes_the_changed_texel() -> void:
	var game := WarFixture.game()
	var overlay := _war_overlay(game)
	assert_eq(overlay.sync_occupiers(game), 0, "no occupied land: nothing to write")
	var member := game.map.hex_of(Occupation.members(game, PAVIA)[2])
	WarFixture.set_occupier(game, member, ArmyFixture.TAG)
	game.version += 1
	assert_eq(overlay.sync_occupiers(game), 1, "one occupied hex, one texel")
	assert_eq(overlay.sync_occupiers(game), 0, "the same version writes nothing")
	assert_eq(overlay.occupier_bytes(), MapModes.occupier_bytes(game))


func test_the_shader_declares_the_m7_uniforms_and_textures() -> void:
	# A failed compile leaves the list empty; the GPU compile itself is the windowed probe's job.
	var shader := load(ModeOverlay.SHADER_PATH) as Shader
	var names: Array[String] = []
	for uniform: Dictionary in shader.get_shader_uniform_list():
		names.append(str(uniform["name"]))
	for want: String in ["occupiers", "areas", "occupied_px", "area_alpha", "area_on", "sight", "owner_ids"]:
		assert_true(names.has(want), "the shader declares %s" % want)
