## The place names (shell/mapview/map_labels.gd): off by default, N toggles them, names for the places on screen only, dark
## plates sized by level that never overlap each other or the blocked boxes, and a layout that follows the camera.
extends GutTest

const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)


func _map() -> MapData:
	var map := MapData.new()
	map.allocate(8, 6)
	var names: Array[String] = ["Milano", "Como", "Lodi", "Monza", "Pavia", "Varese"]
	var hexes: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(7, 5), Vector2i(0, 0)]
	var levels: Array[int] = [5, 2, 1, 3, 2, 1]
	for i: int in names.size():
		map.places.append({"name": names[i], "hex": hexes[i], "level": levels[i], "capital": i == 0, "landmark": ""})
		map.place_id[map.index_of(hexes[i])] = i
	return map


func _shift(offset: Vector2, zoom: float = 1.0) -> Transform2D:
	return Transform2D(Vector2(zoom, 0.0), Vector2(0.0, zoom), offset)


func _layout(map: MapData, xform: Transform2D, blocked: Array[Rect2] = []) -> Array[Dictionary]:
	return MapLabels.layout(map, xform, SCREEN, ThemeDB.fallback_font, blocked)


func _overlaps(placed: Array[Dictionary]) -> int:
	var n := 0
	for i: int in placed.size():
		for j: int in range(i + 1, placed.size()):
			if (placed[i]["box"] as Rect2).intersects(placed[j]["box"] as Rect2):
				n += 1
	return n


func test_off_by_default_and_set_visible() -> void:
	var labels := MapLabels.new()
	add_child_autofree(labels)
	assert_false(labels.visible, "no plates on the normal map")
	labels.set_visible(true)
	assert_true(labels.visible)
	labels.set_visible(false)
	assert_false(labels.visible)


func test_set_visible_emits_toggled_and_has_no_own_key_handler() -> void:
	var labels := MapLabels.new()
	add_child_autofree(labels)
	assert_false(labels.has_method("_unhandled_key_input"), "key N handling moved to MapInput")
	var heard: Array[bool] = []
	labels.toggled.connect(func(on: bool) -> void: heard.append(on))
	labels.set_visible(true)
	assert_true(labels.visible)
	labels.set_visible(false)
	assert_false(labels.visible)
	assert_eq(heard, [true, false])


func test_names_for_the_places_on_screen_without_overlaps() -> void:
	var map := _map()
	var placed := _layout(map, _shift(Vector2(300.0, 200.0)))
	assert_gt(placed.size(), 3)
	assert_eq(_overlaps(placed), 0)
	assert_eq(str(placed[0]["name"]), "Milano", "the great place is placed first")
	for item: Dictionary in placed:
		assert_true(SCREEN.encloses(item["box"] as Rect2), "inside the screen")


func test_crowded_names_lose_the_smaller_place() -> void:
	var map := _map()
	# zoomed far out: the places lie within a few px of each other, so not all names fit; nothing overlaps
	var placed := _layout(map, _shift(Vector2(600.0, 300.0), 0.04))
	assert_lt(placed.size(), 6)
	assert_eq(_overlaps(placed), 0)
	assert_eq(str(placed[0]["name"]), "Milano")


func test_only_places_on_screen_are_named() -> void:
	var map := _map()
	assert_eq(_layout(map, _shift(Vector2(-5000.0, -5000.0))).size(), 0)
	var centre := MapTiles.cell_centre(Vector2i(2, 2))
	var here := _layout(map, _shift(SCREEN.size / 2.0 - centre))
	var found := false
	for item: Dictionary in here:
		found = found or str(item["name"]) == "Milano"
	assert_true(found)


func test_a_blocked_box_is_kept_clear_and_moving_the_camera_moves_the_plates() -> void:
	var map := _map()
	var centre := MapTiles.cell_centre(Vector2i(2, 2))
	var free := _layout(map, _shift(SCREEN.size / 2.0 - centre))
	var blocked: Array[Rect2] = [(free[0]["box"] as Rect2)]
	var kept := _layout(map, _shift(SCREEN.size / 2.0 - centre), blocked)
	for item: Dictionary in kept:
		assert_false((item["box"] as Rect2).intersects(blocked[0]), "%s keeps off the panel" % str(item["name"]))
	var panned := _layout(map, _shift(SCREEN.size / 2.0 - centre + Vector2(40.0, 0.0)))
	assert_almost_eq((panned[0]["box"] as Rect2).position.x, (free[0]["box"] as Rect2).position.x + 40.0, 0.001)


func test_bigger_places_have_bigger_type() -> void:
	assert_gt(MapLabels.font_size(5), MapLabels.font_size(3))
	assert_gt(MapLabels.font_size(3), MapLabels.font_size(1))


func test_capitals_come_from_game_countries_and_avoid_obstacles() -> void:
	var f := ScenarioFixture.build()
	var map := f["map"] as MapData
	var game := Game.new_scenario(map, f["defs"] as GameDefs, f["scenario"] as ScenarioDef, 1480)
	# Fixture places have capital=false in MapData; game countries mark ALPHA_CAPITAL and BETA_CAPITAL.
	var caps := MapLabels.capitals_from(game)
	assert_eq(caps, [ScenarioFixture.ALPHA_CAPITAL, ScenarioFixture.BETA_CAPITAL] as Array[Vector2i])

	var xform := _shift(Vector2(200.0, 200.0))
	var placed := MapLabels.layout(map, xform, SCREEN, ThemeDB.fallback_font, [], caps)
	assert_eq(placed.size(), 2)
	for item: Dictionary in placed:
		assert_true(bool(item["capital"]), "%s styled as a game capital" % str(item["name"]))

	# An obstacle covering Alpha's preferred box forces Alpha onto an unblocked spot (or hides it if none free).
	var blocked: Array[Rect2] = [placed[0]["box"] as Rect2]
	var labels := MapLabels.new()
	add_child_autofree(labels)
	labels.setup(map, caps)
	labels.set_obstacles(blocked)
	var after := MapLabels.layout(map, xform, SCREEN, ThemeDB.fallback_font, labels.obstacles, labels.capitals())
	for item: Dictionary in after:
		assert_false((item["box"] as Rect2).intersects(blocked[0]), "plate avoids CountryLabels obstacle")


func test_a_settlement_takes_its_level_from_the_state() -> void:
	var map := _map()
	var state := MapState.create(map)
	var como := map.index_of(Vector2i(3, 2))
	state.main_use[como] = ImproveRules.SETTLEMENT
	state.level[como] = 4
	var levels := MapLabels.levels_of(map, state)
	assert_eq(levels, {Vector2i(3, 2): 4}, "only the settlement hex is read from the state")
	var xform := _shift(Vector2(300.0, 200.0))
	var with_state := MapLabels.layout(map, xform, SCREEN, ThemeDB.fallback_font, [], null, levels)
	var without := MapLabels.layout(map, xform, SCREEN, ThemeDB.fallback_font, [], null, {})
	var grown := _item(with_state, "Como")
	var data := _item(without, "Como")
	assert_eq(int(grown["level"]), 4, "Como takes the state's level")
	assert_eq(int(data["level"]), 2, "without the state, the data's level")
	assert_gt((grown["box"] as Rect2).size.y, (data["box"] as Rect2).size.y, "a bigger font, a bigger plate")
	assert_eq(_overlaps(with_state), 0)


func test_a_place_off_a_settlement_keeps_the_data_level() -> void:
	var map := _map()
	var state := MapState.create(map)
	var lodi := map.index_of(Vector2i(2, 3))
	state.level[lodi] = 5  # wild land: its level is not a settlement's
	assert_eq(MapLabels.levels_of(map, state), {}, "no settlement, no state level")
	var placed := MapLabels.layout(map, _shift(Vector2(300.0, 200.0)), SCREEN, ThemeDB.fallback_font, [], null,
		MapLabels.levels_of(map, state))
	assert_eq(int(_item(placed, "Lodi")["level"]), 1, "Lodi keeps its data level")


func test_no_map_or_no_state_gives_no_levels() -> void:
	assert_eq(MapLabels.levels_of(null, MapState.create(_map())), {})
	assert_eq(MapLabels.levels_of(_map(), null), {})


func test_set_state_refreshes_only_when_a_label_level_changed() -> void:
	var map := _map()
	var labels := MapLabels.new()
	add_child_autofree(labels)
	labels.setup(map)
	labels._dirty = false
	var state := MapState.create(map)
	labels.set_state(state)
	assert_false(labels._dirty, "no settlement, no change: nothing to relay")
	var como := map.index_of(Vector2i(3, 2))
	state.main_use[como] = ImproveRules.SETTLEMENT
	state.level[como] = 3
	labels.set_state(state)
	assert_true(labels._dirty, "Como grew: its plate is relaid")
	assert_eq(labels._levels, {Vector2i(3, 2): 3})
	labels._dirty = false
	labels.set_state(state)
	assert_false(labels._dirty, "the same levels again: no relay")
	labels.set_state(null)
	assert_true(labels._dirty, "null goes back to the data's levels")
	assert_eq(labels._levels, {})


func _item(placed: Array[Dictionary], name: String) -> Dictionary:
	for item: Dictionary in placed:
		if str(item["name"]) == name:
			return item
	return {}
