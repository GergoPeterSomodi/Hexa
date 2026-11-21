## The map scene's Food mode and people (docs/architecture/m5-build-spec.md 6.5, 6.8, 6.9): key 5, the texture following the
## game only while in Food, the restored mode, a grown town repainting exactly MapCells.touched_by and the plates, and the
## season's ribbons through add_ribbon.
extends GutTest

var _scene: MapScene = null


func before_each() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()


func _key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev


func _finish_fill() -> void:
	_scene.finish_loading()


func _choose_genoa() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	_finish_fill()
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))


## {"layer:x,y": [source, column, row]} of every cell of every layer but the marks.
func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for layer_name: String in TileMapView.LAYERS:
		var layer := _scene.view().layer(layer_name)
		for cell: Vector2i in layer.get_used_cells():
			var at := layer.get_cell_atlas_coords(cell)
			out["%s:%d,%d" % [layer_name, cell.x, cell.y]] = [layer.get_cell_source_id(cell), at.x, at.y]
	return out


# ----- Food and the people (M5 P14, docs/architecture/m5-build-spec.md 6.5, 6.8, 6.9) -----------------------------------


func test_key_5_shows_food_writes_the_setting_and_follows_the_game_only_in_food() -> void:
	Bindings.ensure()
	_choose_genoa()
	var overlay := _scene.overlay()
	var settings := Settings.new("macOS", false)
	_scene.configure(settings)
	var writes := overlay.texel_writes
	Events.tax_set.emit(&"GEN", 2)
	Events.season_ended.emit(1)
	assert_eq(overlay.texel_writes, writes, "nothing is computed or written in Terrain")
	_scene.map_input()._unhandled_input(_key_event(KEY_5))
	assert_eq(_scene.mode(), int(MapModes.Mode.FOOD))
	assert_eq(str(settings.get_value("state/map_mode")), "food", "the switch writes state/map_mode")
	assert_eq(overlay.food_bytes(), MapModes.food_bytes(Session.game, &"GEN"), "the switch brings the texture up to date")
	assert_gt(overlay.food_bytes().count(0), 0)
	var hex := Vector2i(7, 13)  # land changes hands: its texel is veiled
	Session.game.version += 1
	Session.game.state.owner[Session.game.map.index_of(hex)] = 0
	Events.owners_changed.emit([hex] as Array[Vector2i])
	assert_eq(overlay.food_bytes(), MapModes.food_bytes(Session.game, &"GEN"))
	_scene.set_mode(MapModes.Mode.OWNER)
	var kept := overlay.food_bytes()
	var before := overlay.texel_writes
	Session.game.version += 1
	Events.season_ended.emit(2)
	assert_eq(overlay.texel_writes, before, "leaving Food: nothing is written")
	assert_eq(overlay.food_bytes(), kept)


func test_key_5_is_refused_in_a_sandbox() -> void:
	Bindings.ensure()
	var refused_modes: Array[int] = []
	_scene.map_mode_refused.connect(func(m: int) -> void: refused_modes.append(m))
	_scene.map_input()._unhandled_input(_key_event(KEY_5))
	assert_eq(refused_modes, [4])
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN))


func test_a_saved_food_mode_comes_back_and_falls_back_to_terrain() -> void:
	var settings := Settings.new("macOS", false)
	settings.set_value("state/map_mode", "food")
	_scene.configure(settings)
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN), "a sandbox does not offer Food")
	assert_eq(str(settings.get_value("state/map_mode")), "food", "and the saved value is kept")
	_choose_genoa()
	_scene.configure(settings)
	assert_eq(_scene.mode(), int(MapModes.Mode.FOOD), "restored once the game offers it")
	assert_eq(_scene.overlay().food_bytes(), MapModes.food_bytes(Session.game, &"GEN"))


func test_a_town_grew_repaints_exactly_the_touched_cells_and_the_labels() -> void:
	_choose_genoa()
	var game := Session.game
	var map := game.map
	var hex := Vector2i(6, 13)  # Savoy-side village the labels know as a place
	var i := map.index_of(hex)
	var touched := MapCells.touched_by(map, hex)
	var far := Vector2i(0, 0)
	for candidate: Vector2i in [Vector2i(20, 2), Vector2i(2, 2), Vector2i(20, 20), Vector2i(0, 0)]:
		if map.has(candidate):
			far = candidate
			break
	var full := _snapshot()
	for cell: Vector2i in touched + [far] as Array[Vector2i]:
		for layer_name: String in TileMapView.LAYERS:
			_scene.view().set_tile(layer_name, cell, "")
	var blank := _snapshot()
	assert_lt(blank.size(), full.size(), "the planted blanks are visible")
	game.state.level[i] = 3
	Events.town_grew.emit(&"GEN", hex, 3)
	var after := _snapshot()
	var touched_set := {}
	for cell: Vector2i in touched:
		touched_set[cell] = true
	for key: String in full:
		var xy := (key.split(":")[1] as String).split(",")
		var cell := Vector2i(int(xy[0]), int(xy[1]))
		if touched_set.has(cell):
			assert_eq(after.get(key), full[key], "%s is named again" % key)
		elif cell == far:
			assert_false(after.has(key), "%s, far away, is left alone" % key)
	assert_eq(int(_scene.labels()._levels.get(hex, -1)), 3, "the plate takes the new level")


func test_the_season_adds_the_peoples_ribbons_through_add_ribbon() -> void:
	_choose_genoa()
	var floaters := _scene.get_node("Names/Floaters") as Floaters
	floaters.setup(Session.game)
	floaters.set_view(Rect2(0, 0, 100000, 100000))
	floaters.set_xform(Transform2D.IDENTITY)
	var hex := Vector2i(8, 13)
	var i := Session.game.map.index_of(hex)
	Session.game.state.people_start[i] = 1000
	Session.game.state.people_end[i] = 1300
	Session.game.state.people[i] = 1300
	var want := PeopleView.ribbons(Session.game, &"GEN")
	assert_gt(want.size(), 0, "the fixture has a ribbon")
	var before := floaters.live_count()
	Events.season_ended.emit(1)
	assert_eq(floaters.live_count(), before + want.size())
	assert_gt(floaters.count_at(hex), 0)
