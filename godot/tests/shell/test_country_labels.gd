## Shell tests for CountryLabels and game-derived capitals in MapLabels
## (docs/architecture/m2-build-spec.md sections 6.1, 6.4, and 10).
extends GutTest


func _scenario_game() -> Game:
	var defs := load(Session.DEFS) as GameDefs
	var scen := defs.scenario("north_italy_1480")
	var map := load("res://data/maps/north_italy.tres") as MapData
	return Game.new_scenario(map, defs, scen, 1480)


func test_font_size_formula_clamping_and_hiding_under_13_px() -> void:
	# round(0.6 * 520 * 0.5 / (0.62 * 5)) = round(156 / 3.1) = 50 -> clamped to 40
	assert_eq(CountryLabels.font_size_for(520.0, 0.5, 5), 40)
	# round(0.6 * 208 * 0.45 / (0.62 * 6)) = round(56.16 / 3.72) = 15
	assert_eq(CountryLabels.font_size_for(208.0, 0.45, 6), 15)
	# round(0.6 * 208 * 0.30 / (0.62 * 6)) = round(37.44 / 3.72) = 10 -> hidden (0)
	assert_eq(CountryLabels.raw_font_size(208.0, 0.30, 6), 10)
	assert_eq(CountryLabels.font_size_for(208.0, 0.30, 6), 0)

	var game := _scenario_game()
	var labels := CountryLabels.new()
	add_child_autofree(labels)
	labels.setup(game)
	labels.set_mode(MapModes.Mode.OWNER)

	# At tiny zoom (0.04), all regions drop under 13 px and are hidden.
	labels.set_view(Transform2D.IDENTITY, 0.04, Vector2(1280.0, 720.0))
	assert_true(labels.placed().is_empty(), "all labels under 13 px are hidden")
	assert_false(labels.visible)

	# At zoom 0.45, larger regions show while Mantua (3 hexes, span ~208) stays >= 13 px.
	labels.set_view(Transform2D.IDENTITY, 0.45, Vector2(1280.0, 720.0))
	assert_gt(labels.placed().size(), 0)
	for item: Dictionary in labels.placed():
		assert_gte(int(item["font_size"]), 13)
		assert_lte(int(item["font_size"]), 40)
		assert_eq(str(item["text"]), str(item["text"]).to_upper(), "country names are upper-cased")


func test_visibility_by_mode_zoom_and_picking() -> void:
	var game := _scenario_game()
	var labels := CountryLabels.new()
	add_child_autofree(labels)
	labels.setup(game)

	# Terrain: visible below zoom 0.9, hidden at and above zoom 0.9.
	labels.set_mode(MapModes.Mode.TERRAIN)
	labels.set_view(Transform2D.IDENTITY, 0.89, Vector2(1280.0, 720.0))
	assert_gt(labels.placed().size(), 0, "Terrain < 0.9 shows country labels")
	labels.set_view(Transform2D.IDENTITY, 0.90, Vector2(1280.0, 720.0))
	assert_true(labels.placed().is_empty(), "Terrain >= 0.9 hides country labels")

	# Owner mode at zoom 2: still shown.
	labels.set_mode(MapModes.Mode.OWNER)
	labels.set_view(Transform2D.IDENTITY, 2.0, Vector2(1280.0, 720.0))
	assert_gt(labels.placed().size(), 0, "Owner mode at zoom 2 keeps country labels visible")

	# Relief mode hides labels unless picking.
	labels.set_mode(MapModes.Mode.RELIEF)
	assert_true(labels.placed().is_empty(), "Relief mode hides country labels")
	labels.set_picking(true)
	assert_gt(labels.placed().size(), 0, "Picking shows country labels in any mode")

	# Calling set_view with identical parameters does not re-layout.
	var count_before := labels.layout_count
	labels.set_view(Transform2D.IDENTITY, 2.0, Vector2(1280.0, 720.0))
	assert_eq(labels.layout_count, count_before, "identical view does not trigger relayout")


func test_incremental_owners_changed_updates_only_changed_countries() -> void:
	var game := _scenario_game()
	var labels := CountryLabels.new()
	add_child_autofree(labels)
	labels.setup(game)

	var gen_id := game.scenario.id_of(&"GEN")
	var mlo_id := game.scenario.id_of(&"MLO")
	var transfer_hex := Vector2i(8, 12)  # Genoa hex bordering Milan
	assert_eq(Territory.owner_id(game, transfer_hex), gen_id)
	assert_gt(Territory.transfer(game, [transfer_hex], mlo_id), 0)

	labels.on_owners_changed([transfer_hex])
	assert_eq(labels.last_recomputed_ids, PackedInt32Array([mini(gen_id, mlo_id), maxi(gen_id, mlo_id)]))
	assert_eq(labels.entries(), CountryNames.places(game), "incremental entries match full recompute")


func test_capitals_from_game_in_map_labels_for_1480() -> void:
	var game := _scenario_game()
	var caps := MapLabels.capitals_from(game)
	assert_eq(caps.size(), 10, "north_italy_1480 has 10 playable capitals")
	assert_true(caps.has(Vector2i(8, 13)), "Genoa is a game capital")
	assert_true(caps.has(Vector2i(18, 7)), "Venice is a game capital")
	assert_true(caps.has(Vector2i(12, 15)), "Lucca is a game capital")

	# Even though MapData.places only marks Milan as capital, MapLabels with game capitals styles Genoa as capital.
	var genoa_px := MapTiles.cell_centre(Vector2i(8, 13))
	var xform := Transform2D(0.0, Vector2(640.0, 360.0) - genoa_px)
	var screen := Rect2(0.0, 0.0, 1280.0, 720.0)
	var legacy := MapLabels.layout(game.map, xform, screen, ThemeDB.fallback_font, [])
	var from_game := MapLabels.layout(game.map, xform, screen, ThemeDB.fallback_font, [], caps)
	var genoa_legacy := _find_placed(legacy, "Genoa")
	var genoa_game := _find_placed(from_game, "Genoa")
	assert_false(genoa_legacy.is_empty())
	assert_false(genoa_game.is_empty())
	assert_false(bool(genoa_legacy["capital"]), "MapData.places does not mark Genoa as capital")
	assert_true(bool(genoa_game["capital"]), "Game capitals mark Genoa as capital in MapLabels")


func _find_placed(items: Array[Dictionary], place_name: String) -> Dictionary:
	for item: Dictionary in items:
		if str(item["name"]) == place_name:
			return item
	return {}
