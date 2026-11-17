## The map scene (docs/architecture/m1-build-spec.md section 10): it opens on tiles, a click selects, the panel's Build
## button changes the state through Session.act and exactly the cells of MapCells.touched_by, a season swap writes no
## cell, and the far picture takes over when zoomed out.
extends GutTest

var _scene: MapScene = null
var _hexes_changed: Array[Vector2i] = []


func before_each() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	var packed := load("res://shell/map/map_scene.tscn") as PackedScene
	_scene = packed.instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_finish_fill()
	_hexes_changed.clear()


## The tile names the view asked for and the tileset lacks, minus the pieces' blank parts: the bake leaves out a
## back or shadow part that has nothing in it, and the view clears that cell.
func _unexplained_missing() -> Array[String]:
	var out: Array[String] = []
	for tile_name: String in _scene.view().missing_names():
		var blank_part := tile_name.begins_with("piece/") and (tile_name.ends_with("/back") or tile_name.ends_with("/shadow"))
		if not blank_part:
			out.append(tile_name)
	return out


func _finish_fill() -> void:
	_scene.finish_loading()


## {"layer:x,y": [source, column, row]} of every cell of every layer but the marks.
func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for layer_name: String in TileMapView.LAYERS:
		var layer := _scene.view().layer(layer_name)
		for cell: Vector2i in layer.get_used_cells():
			var at := layer.get_cell_atlas_coords(cell)
			out["%s:%d,%d" % [layer_name, cell.x, cell.y]] = [layer.get_cell_source_id(cell), at.x, at.y]
	return out


## A wild land hex with a build option the rules allow, and that option's family id.
func _buildable() -> Dictionary:
	var game := Session.game
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 0 or not Improve.piece_at(game, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(game, hex):
			if bool(option["ok"]):
				return {"hex": hex, "family": int(option["family_id"])}
	return {}


func test_main_scene_is_the_map_scene() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/run/main_scene")), "res://shell/map/map_scene.tscn")
	assert_true(ProjectSettings.has_setting("autoload/Session"), "Session is an autoload")
	assert_true(ProjectSettings.has_setting("autoload/Events"), "Events is an autoload")


func test_it_opens_on_tiles_of_the_whole_map() -> void:
	var map := Session.game.map
	assert_false(_scene.view().is_filling())
	assert_gt(_scene.view().cell_count(), map.cols * map.rows, "every hex has at least a tile")
	var crossings := 0
	for layer_name: String in Crossings.LAYERS:
		crossings += _scene.view().layer(layer_name).get_used_cells().size()
	assert_eq(crossings, Crossings.all_of(map).size(), "every crossing of the map is on a crossing layer")
	assert_eq(_unexplained_missing(), [] as Array[String], "every tile asked for is in the tileset or a blank piece part")
	assert_eq(_scene.view().season(), "summer")
	_scene.frame_at(_scene.map_size() / 2.0, 0.5)  # (a test window is 64 px square, so fit() would zoom far out)
	assert_true(_scene.view().visible and not _scene.far().visible, "the tiles show at the start zoom")


func test_place_names_are_off_by_default_and_toggle_shows_them() -> void:
	assert_not_null(_scene.labels())
	assert_eq((_scene.labels().get_parent() as CanvasLayer).layer, 5)
	assert_false(_scene.labels().visible, "place names are off by default")
	var map := Session.game.map
	var place_hex: Vector2i = map.places[0]["hex"]
	_scene.frame_at(_scene.view().centre_of(place_hex), 0.5)
	_scene.toggle_names()
	assert_true(_scene.labels().visible)
	_scene.labels()._process(0.0)
	var layout := MapLabels.layout(map, Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(640.0, 360.0) - _scene.view().centre_of(place_hex)),
		Rect2(0.0, 0.0, 1280.0, 720.0), ThemeDB.fallback_font, [])
	assert_gt(layout.size(), 0, "places near the camera are laid out on screen")
	var press := InputEventKey.new()
	press.keycode = KEY_N
	press.pressed = true
	_scene.labels()._unhandled_key_input(press)
	assert_false(_scene.labels().visible, "key N toggles the place names off")
	_scene.labels()._unhandled_key_input(press)
	assert_true(_scene.labels().visible, "key N toggles the place names on")


func test_a_click_selects_the_hex_under_it() -> void:
	var hex := _buildable()["hex"] as Vector2i
	_scene.frame_at(_scene.view().centre_of(hex), 1.0)
	_scene.camera().force_update_scroll()
	var input := _scene.get_node("Input") as MapInput
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = _scene.get_viewport_rect().size / 2.0
	event.pressed = true
	input._unhandled_input(event)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	input._unhandled_input(release)
	assert_eq(_scene.selected, hex, "the hex in the middle of the window is selected")
	assert_eq(_scene.panel().shown_hex(), hex, "the panel shows it")
	assert_eq(_scene.view().layer("marks").get_cell_source_id(hex) != -1, true, "the ring is on the marks layer")
	_scene.select_hex(MapScene.NO_HEX)
	assert_eq(_scene.selected, MapScene.NO_HEX)
	assert_false(_scene.panel().visible)
	assert_eq(_scene.view().layer("marks").get_used_cells().size(), 0, "the ring is gone")


func test_every_centre_finds_its_hex() -> void:
	var map := Session.game.map
	for i: int in map.hex_count():
		var hex := map.hex_of(i)
		assert_eq(_scene.view().hex_at(_scene.view().centre_of(hex)), hex)


func test_the_panel_build_button_changes_the_state_and_only_the_touched_cells() -> void:
	var found := _buildable()
	assert_false(found.is_empty(), "something can be built on north Italy")
	var hex := found["hex"] as Vector2i
	var family := int(found["family"])
	_scene.select_hex(hex)
	var button: Button = null
	for b: Button in _scene.panel().action_buttons():
		if not b.disabled and b.text.begins_with("Build"):
			button = b
			break
	assert_not_null(button, "the panel has an enabled Build button")
	var before := _snapshot()
	var writes := _scene.view().cell_writes
	var use_before := Session.game.state.main_use[Session.game.map.index_of(hex)]
	Events.hex_changed.connect(_remember)
	button.pressed.emit()
	Events.hex_changed.disconnect(_remember)
	assert_ne(Session.game.state.main_use[Session.game.map.index_of(hex)], use_before, "the state has a piece now")
	assert_eq(_hexes_changed, [hex] as Array[Vector2i], "exactly one hex_changed")
	assert_gt(_scene.view().cell_writes, writes, "tiles were written")
	var allowed: Dictionary = {}
	for n: Vector2i in MapCells.touched_by(Session.game.map, hex):
		allowed[n] = true
	var after := _snapshot()
	var stray := 0
	var keys: Dictionary = before.duplicate()
	keys.merge(after)
	for key: String in keys:
		if before.get(key, null) != after.get(key, null):
			var at := key.split(":")[1].split(",")
			if not allowed.has(Vector2i(int(at[0]), int(at[1]))):
				stray += 1
	assert_eq(stray, 0, "cells outside the hex and its neighbours that changed")
	assert_eq(_unexplained_missing(), [] as Array[String])
	assert_false(_scene.panel().action_buttons().is_empty(), "the panel shows Upgrade and Clear now")
	assert_true(Session.check("clear", {"hex": hex})["ok"])
	assert_true(family > 0)


func _remember(hex: Vector2i) -> void:
	_hexes_changed.append(hex)


func test_upgrade_and_clear_go_through_session() -> void:
	var found := _buildable()
	var hex := found["hex"] as Vector2i
	assert_true(Session.act("build", {"hex": hex, "family": int(found["family"])})["ok"])
	var level := Session.game.state.level[Session.game.map.index_of(hex)]
	_scene.selected = hex
	var verdict := _scene.upgrade_selected()
	if bool(verdict["ok"]):
		assert_eq(Session.game.state.level[Session.game.map.index_of(hex)], level + 1)
	assert_true(Session.act("clear", {"hex": hex})["ok"])
	assert_eq(Improve.piece_at(Session.game, hex), {})
	assert_eq(_scene.view().layer("piece_ground").get_cell_source_id(hex), -1, "the piece's tile is gone")


func test_a_season_swap_writes_no_cell() -> void:
	var writes := _scene.view().cell_writes
	var before := _snapshot()
	var set_before := _scene.view().layer("ground").tile_set
	_scene.set_season("winter")
	_scene.finish_swap()
	assert_eq(_scene.season, "winter")
	assert_eq(_scene.view().season(), "winter")
	assert_eq(_scene.view().cell_writes, writes, "no cell was written")
	assert_ne(_scene.view().layer("ground").tile_set, set_before, "the tile set is the winter one")
	assert_eq(_snapshot(), before, "every cell is the same")
	_scene.set_season("summer")
	_scene.finish_swap()
	assert_eq(_scene.view().cell_writes, writes)


func test_far_zoom_replaces_the_tiles() -> void:
	var centre := _scene.map_size() / 2.0
	_scene.frame_at(centre, 1.0)
	_scene._process(0.0)
	assert_true(_scene.view().visible)
	assert_false(_scene.far().visible)
	_scene.frame_at(centre, 0.22)
	assert_true(_scene.view().visible and _scene.far().visible, "both show while they cross-fade")
	assert_between(_scene.far().modulate.a, 0.01, 0.99)
	_scene.frame_at(centre, 0.1)
	assert_false(_scene.view().visible, "the tiles are hidden when zoomed out")
	assert_true(_scene.far().visible)
	assert_eq(_scene.far().modulate.a, 1.0)


func test_the_far_picture_follows_a_build() -> void:
	var found := _buildable()
	var hex := found["hex"] as Vector2i
	var before := _scene.far().pixel_of(hex)
	Session.act("build", {"hex": hex, "family": int(found["family"])})
	assert_ne(_scene.far().pixel_of(hex), before, "a built hex is warmer on the far picture")


func test_new_seed_starts_a_new_game_and_clears_the_selection() -> void:
	var hex := _buildable()["hex"] as Vector2i
	_scene.select_hex(hex)
	var seed_before := Session.game.seed_value
	_scene.new_seed()
	assert_eq(Session.game.seed_value, seed_before + 1)
	assert_eq(_scene.selected, MapScene.NO_HEX)
	_finish_fill()
	assert_eq(_unexplained_missing(), [] as Array[String])


func test_a_big_map_loads_a_slice_a_frame() -> void:
	var map := FakeMap.build(80, 60, 3)  # 4,800 hexes: over MapScene.SYNC_LOAD_HEXES
	Session.start_game(Game.with_state(map, MapState.create(map)))
	assert_true(_scene.is_loading(), "the load is not done at once")
	var steps := 0
	while _scene.is_loading() and steps < 10000:
		_scene._load_step(2.0)
		steps += 1
	assert_gt(steps, 1, "it took several slices")
	assert_false(_scene.is_loading())
	assert_gt(_scene.view().cell_count(), map.cols * map.rows)
	assert_gt(_scene.view().line_chunks().size(), 0, "the chunks have lines")
	_scene.frame_at(_scene.map_size() / 2.0, 0.1)
	assert_true(_scene.far().visible)
	assert_ne(_scene.far().pixel_of(Vector2i(5, 5)), Color.BLACK)
