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
	var injected_panel := (load("res://shell/panels/hex_panel.tscn") as PackedScene).instantiate() as HexPanelContract
	_scene.add_child(injected_panel)
	_scene.set_panel(injected_panel)
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


func test_main_scene_is_the_app_scene_and_autoloads_exist() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/run/main_scene")), "res://shell/app/app.tscn")
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
	assert_eq(_scene.view().season(), "spring", "turn 1 is Spring: the map opens in the calendar season")
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
	Bindings.ensure()
	var press := InputEventKey.new()
	press.keycode = KEY_N
	press.pressed = true
	_scene.map_input()._unhandled_input(press)
	assert_false(_scene.labels().visible, "key N via MapInput toggles the place names off")
	_scene.map_input()._unhandled_input(press)
	assert_true(_scene.labels().visible, "key N via MapInput toggles the place names on")


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
	assert_eq(Session.game.state.work_at(hex).family, family, "Build begins a work")
	assert_eq(Session.game.state.main_use[Session.game.map.index_of(hex)], use_before, "nothing stands yet")
	assert_eq(_hexes_changed, [] as Array[Vector2i], "no hex changed yet")
	_stand(hex)
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


## Ends seasons until the work on the hex has finished (a build, an upgrade or a clearing takes seasons since M3).
func _stand(hex: Vector2i) -> void:
	var n := 0
	while Session.game.state.work_at(hex) != null and n < 40:
		assert_true(bool(Session.end_season()["ok"]))
		n += 1
	assert_null(Session.game.state.work_at(hex), "the work has finished")


func _remember(hex: Vector2i) -> void:
	_hexes_changed.append(hex)


func test_upgrade_and_clear_go_through_session() -> void:
	var found := _buildable()
	var hex := found["hex"] as Vector2i
	assert_true(Session.act("build", {"hex": hex, "family": int(found["family"])})["ok"])
	_stand(hex)
	var level := Session.game.state.level[Session.game.map.index_of(hex)]
	_scene.selected = hex
	var verdict := _scene.upgrade_selected()
	if bool(verdict["ok"]):
		_stand(hex)
		assert_eq(Session.game.state.level[Session.game.map.index_of(hex)], level + 1)
	assert_true(Session.act("clear", {"hex": hex})["ok"])
	_stand(hex)
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


## A second scene on the running game (before_each's scene stays; both are freed with the test).
func _another_scene() -> MapScene:
	var packed := load("res://shell/map/map_scene.tscn") as PackedScene
	var scene := packed.instantiate() as MapScene
	scene.preload_next_season = false
	add_child_autofree(scene)
	scene.finish_loading()
	return scene


func test_the_map_opens_in_the_calendars_season() -> void:
	for turn: int in [1, 2, 3, 4, 7]:
		Session.game.turn = turn
		var scene := _another_scene()
		var want: String = TilesetBuilder.SEASONS[Calendar.season_of(turn)]
		assert_eq(scene.season, want, "turn %d" % turn)
		assert_eq(scene.view().season(), want)


func test_game_started_shows_the_calendars_season() -> void:
	assert_eq(_scene.season, "spring")
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	Session.game.turn = 4
	Events.game_started.emit()
	_scene.finish_swap()
	assert_eq(_scene.season, "winter")


func test_show_season_without_fade_swaps_at_once_and_the_fade_does_nothing_headless() -> void:
	watch_signals(_scene)
	_scene.show_season(2, false)
	assert_eq(_scene.season, "autumn")
	assert_signal_emitted_with_parameters(_scene, "season_changed", ["autumn"])
	_scene.show_season(3, true)  # headless: the fade is skipped, the swap is not
	assert_eq(_scene.season, "winter")
	assert_false(_scene.season_fade().is_fading())
	_scene.show_season(7, false)  # the index wraps
	assert_eq(_scene.season, "winter")


func test_the_fade_is_skipped_under_reduce_motion() -> void:
	var fade := _scene.season_fade()
	fade.run_headless = true
	fade.reduce_motion = true
	assert_true(fade.skipped())
	fade.reduce_motion = false
	assert_false(fade.skipped(), "a test switches the headless skip off")
	assert_eq(fade.layer, 9)
	assert_eq(SeasonFade.DURATION, 0.4)


func test_the_fallback_fade_goes_through_the_background_colour_and_back() -> void:
	var fade := _scene.season_fade()
	fade.method = SeasonFade.Method.FALLBACK
	fade.run_headless = true
	_scene.show_season(1, true)
	await wait_seconds(0.1)
	assert_eq(_scene.season, "spring", "the swap waits for the world to be dark")
	assert_ne(_scene.modulate, Color.WHITE, "the world is fading")
	await wait_for_signal(fade.finished, 2.0)
	assert_eq(_scene.season, "summer")
	assert_eq(_scene.modulate, Color.WHITE, "the world is back")
	assert_false(fade.is_fading())


func test_a_preview_holds_until_the_season_ends() -> void:
	_scene.preview_season(3)
	assert_eq(_scene.season, "winter")
	_scene.show_season(1, false)
	assert_eq(_scene.season, "winter", "the calendar's change is ignored during a preview")
	assert_true(bool(Session.end_season()["ok"]))  # season_ended: the preview is over
	await wait_frames(2)
	_scene.finish_swap()
	assert_eq(_scene.season, "summer", "turn 2: the calendar's season is shown again")
	_scene.preview_season(0)
	assert_eq(_scene.season, "spring")
	_scene.preview_season(-1)
	assert_eq(_scene.season, "summer", "-1 goes back to the calendar")
	_scene.show_season(2, false)
	assert_eq(_scene.season, "autumn", "no preview is on any more")


func test_freeing_the_scene_mid_fade_is_harmless() -> void:
	var scene := _another_scene()
	var fade := scene.season_fade()
	fade.method = SeasonFade.Method.FALLBACK
	fade.run_headless = true
	scene.show_season(2, true)
	await wait_seconds(0.05)
	scene.free()
	await wait_seconds(0.3)
	assert_false(is_instance_valid(scene))


func test_a_show_season_that_came_before_the_season_ended_is_not_lost() -> void:
	_scene.preview_season(0)
	Session.game.turn = 2
	_scene.show_season(1, false)  # the App was first: ignored while the preview is on
	assert_eq(_scene.season, "spring")
	Events.season_ended.emit(1)
	await wait_frames(2)
	_scene.finish_swap()
	assert_eq(_scene.season, "summer", "the scene shows the calendar's season by itself")


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
	_stand(hex)
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


func test_configure_applies_settings_and_live_updates() -> void:
	var settings := Settings.new("macOS", false)
	assert_true(settings.set_value("map/grid", true))
	assert_true(settings.set_value("map/grid_opacity", 50))
	assert_true(settings.set_value("map/place_names", true))
	assert_true(settings.set_value("graphics/relief_shading", false))
	assert_true(settings.set_value("graphics/preload_next_season", false))
	assert_true(settings.set_value("dev/far_zoom", 0.55))
	assert_true(settings.set_value("dev/slice_ms", 12))

	_scene.configure(settings)
	_scene.finish_swap()
	_scene.frame_at(_scene.map_size() / 2.0, 1.0)
	assert_true(_scene.view().layer("grid").visible)
	assert_almost_eq(_scene.view().layer("grid").modulate.a, 0.5, 0.01)
	assert_true(_scene.labels().visible)
	assert_false(_scene.view().layer("shade").visible)
	assert_false(_scene.view().layer("light").visible)
	assert_false(_scene.preload_next_season)
	assert_eq(_scene.texture_quality, "half")
	assert_true(_scene.view().is_half())
	assert_almost_eq(_scene.far().zoom_off, 0.55, 0.001)
	assert_almost_eq(_scene.slice_ms, 12.0, 0.001)

	assert_true(settings.set_value("map/grid", false))
	assert_true(settings.set_value("graphics/relief_shading", true))
	assert_false(_scene.view().layer("grid").visible)
	assert_true(_scene.view().layer("shade").visible)
	assert_true(_scene.view().layer("light").visible)


func test_refused_signal_emits_on_refused_upgrade_and_key_u() -> void:
	Bindings.ensure()
	var reasons: Array[String] = []
	_scene.refused.connect(func(reason: String) -> void: reasons.append(reason))

	_scene.select_hex(MapScene.NO_HEX)
	var v1 := _scene.upgrade_selected()
	assert_false(bool(v1["ok"]))
	assert_eq(reasons.size(), 1)
	assert_eq(reasons[0], str(v1["reason"]))

	var wild := _buildable()["hex"] as Vector2i
	_scene.select_hex(wild)
	var press_u := InputEventKey.new()
	press_u.keycode = KEY_U
	press_u.pressed = true
	_scene.map_input()._unhandled_input(press_u)
	assert_eq(reasons.size(), 2, "refused U key action emits MapScene.refused")
	assert_ne(reasons[1], "")


func test_ctrl_or_cmd_r_gives_new_seed_and_plain_r_does_nothing() -> void:
	Bindings.ensure()
	var seed_before := Session.game.seed_value
	var plain_r := InputEventKey.new()
	plain_r.keycode = KEY_R
	plain_r.pressed = true
	_scene.map_input()._unhandled_input(plain_r)
	assert_eq(Session.game.seed_value, seed_before, "plain R does nothing")

	var chord_r := Bindings.events_for(&"dev_new_seed")[0].duplicate() as InputEventKey
	chord_r.pressed = true
	_scene.map_input()._unhandled_input(chord_r)
	assert_eq(Session.game.seed_value, seed_before + 1, "Ctrl/Cmd+R starts a new seed")
	_finish_fill()


func test_viewport_click_does_not_stick_camera_drag() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)

	var packed := load("res://shell/map/map_scene.tscn") as PackedScene
	var scene := packed.instantiate() as MapScene
	scene.preload_next_season = false
	vp.add_child(scene)
	scene.finish_loading()
	var hex := _buildable()["hex"] as Vector2i
	scene.frame_at(scene.view().centre_of(hex), 1.0)
	var cam_before := scene.camera().position

	var centre := Vector2(640.0, 360.0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = centre
	press.global_position = centre
	press.pressed = true
	vp.push_input(press)

	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	vp.push_input(release)
	assert_eq(scene.selected, hex, "viewport click selects the hex")

	var motion := InputEventMouseMotion.new()
	motion.position = centre + Vector2(80.0, 0.0)
	motion.global_position = motion.position
	motion.relative = Vector2(80.0, 0.0)
	vp.push_input(motion)
	assert_eq(scene.camera().position, cam_before, "CameraRig saw button release before MapInput consumed click")


func test_half_texture_quality_preserves_cell_alignment_and_live_swaps() -> void:
	var settings := Settings.new("Windows", false)
	assert_true(settings.set_value("graphics/preload_next_season", false))
	assert_true(settings.set_value("graphics/texture_quality", "half"))
	var writes := _scene.view().cell_writes
	var before := _snapshot()

	_scene.configure(settings)
	_scene.finish_swap()
	assert_true(_scene.view().is_half())
	assert_eq(_scene.view().cell_writes, writes, "quality swap writes no cell")
	assert_eq(_snapshot(), before, "cell coordinates and tile ids preserved")
	assert_eq(_scene.view().layer("ground").scale, Vector2(2.0, 2.0))
	assert_eq(_scene.view().layer("piece_front").scale, Vector2(2.0, 2.0))
	assert_eq(_scene.view().layer("grid").scale, Vector2.ONE)
	assert_eq(_scene.view().layer("marks").scale, Vector2.ONE)
	assert_eq(_scene.view().layer("ground").tile_set.tile_size, Vector2i(52, 51))

	var map := Session.game.map
	for i: int in map.hex_count():
		var hex := map.hex_of(i)
		var c := _scene.view().centre_of(hex)
		assert_lt(c.distance_to(MapTiles.cell_centre(hex)), 0.01)
		assert_eq(_scene.view().hex_at(c), hex)

	assert_true(settings.set_value("graphics/texture_quality", "full"))
	_scene.finish_swap()
	assert_false(_scene.view().is_half())
	assert_eq(_scene.view().layer("ground").scale, Vector2.ONE)
	assert_eq(_scene.view().layer("ground").tile_set.tile_size, Vector2i(104, 102))


func _key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev


func _click_world_hex(hex: Vector2i) -> void:
	_scene.frame_at(_scene.view().centre_of(hex), 1.0)
	_scene.camera().force_update_scroll()
	var input := _scene.map_input()
	var pos := _scene.get_viewport_rect().size / 2.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = pos
	press.pressed = true
	input._unhandled_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	input._unhandled_input(release)


func _multi_chunk_scenario_game() -> Game:
	var map := FakeMap.build(40, 40, 1480)
	var defs := GameDefs.new()
	defs.tinctures = GameDefs.default_tinctures()
	defs.cb_palette = GameDefs.default_cb_palette()
	defs.countries = [
		ScenarioFixture.make_country(&"AAA", "Alpha", "Republic of Alpha", "Alphan", Color("#b3261e")),
		ScenarioFixture.make_country(&"BBB", "Beta", "Duchy of Beta", "Betan", Color("#2b5aa8")),
	]
	var scen := ScenarioDef.new()
	scen.id = "multi_chunk_fixture"
	scen.name = "Multi Chunk"
	scen.map_id = map.id
	scen.map_digest = map.digest()
	scen.countries = [&"AAA", &"BBB"]
	scen.capitals = [Vector2i(4, 4), Vector2i(36, 36)]
	scen.cb_colours = PackedByteArray([0, 4])
	scen.owner.resize(map.hex_count())
	for r: int in map.rows:
		for c: int in map.cols:
			var idx := r * map.cols + c
			if map.land[idx] == 0:
				scen.owner[idx] = 0
			elif c < 20:
				scen.owner[idx] = 1
			else:
				scen.owner[idx] = 2
	defs.scenarios = [scen]
	return Game.new_scenario(map, defs, scen, 1480)


func test_map_only_game_has_no_borders_pennants_or_owner_mode() -> void:
	Bindings.ensure()
	assert_false(_scene.picking())
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN))
	assert_true(_scene.view().border_chunks().is_empty(), "map-only game has no border chunks")
	assert_eq(_scene.capital_marks().pennant_count(), 0)
	assert_false(_scene.capital_marks().visible)
	assert_true(_scene.country_labels().entries().is_empty())

	var reasons: Array[String] = []
	_scene.refused.connect(func(r: String) -> void: reasons.append(r))
	_scene.map_input()._unhandled_input(_key_event(KEY_2))
	_scene.map_input()._unhandled_input(_key_event(KEY_C))
	assert_eq(reasons, ["No countries on this map", "No countries on this map"])
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN), "Owner mode refused in map-only game")

	_scene.map_input()._unhandled_input(_key_event(KEY_3))
	assert_eq(_scene.mode(), int(MapModes.Mode.RELIEF), "Relief mode works in map-only game")


func test_scenario_game_borders_modes_labels_pennants_and_settings() -> void:
	Bindings.ensure()
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	_finish_fill()

	assert_true(_scene.picking(), "scenario without player opens in picking state")
	assert_eq(_scene.mode(), int(MapModes.Mode.OWNER), "picking opens in Owner mode")
	assert_gt(_scene.view().border_chunks().size(), 0, "scenario game builds border chunks")
	assert_eq(_scene.capital_marks().pennant_count(), 10, "10 playable capital pennants")
	assert_true(_scene.capital_marks().visible, "pennants visible while picking")
	assert_gt(_scene.country_labels().placed().size(), 0, "country names shown while picking")

	# Keys 1, 2, 3 switch Terrain, Owner, Relief.
	_scene.map_input()._unhandled_input(_key_event(KEY_1))
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN))
	_scene.map_input()._unhandled_input(_key_event(KEY_3))
	assert_eq(_scene.mode(), int(MapModes.Mode.RELIEF))
	_scene.map_input()._unhandled_input(_key_event(KEY_2))
	assert_eq(_scene.mode(), int(MapModes.Mode.OWNER))

	# Colour-blind setting updates overlay palette, pennant tint, and rebuilds borders.
	var gen_std := _scene.capital_marks().cloth_colour_of(&"GEN")
	var rebuilds_before := _scene.border_chunk_rebuilds
	var settings := Settings.new("macOS", false)
	_scene.configure(settings); settings.set_value("map/sight_veil", false)  # the veil (on by default) keeps Terrain up: test_sight_veil_setting
	assert_true(settings.set_value("accessibility/country_colours", "colour_blind"))
	assert_gt(_scene.border_chunk_rebuilds, rebuilds_before, "palette switch rebuilds borders")
	var gen_cb := _scene.capital_marks().cloth_colour_of(&"GEN")
	assert_ne(gen_cb, gen_std, "pennant cloth reflects colour-blind palette")
	assert_eq(_scene.overlay().palette_image().get_pixel(7, 0).to_html(), gen_cb.to_html())

	# Borders and tint settings toggle visibility without rebuilding chunks.
	var borders_node := _scene.view().get_node("Borders") as Node2D
	assert_true(borders_node.visible)
	assert_true(settings.set_value("map/borders", false))
	assert_false(borders_node.visible)
	assert_true(settings.set_value("map/borders", true))
	assert_true(borders_node.visible)

	_scene.set_mode(MapModes.Mode.TERRAIN)
	assert_true(_scene.overlay().visible)
	assert_true(settings.set_value("map/owner_tint", false))
	assert_false(_scene.overlay().visible)
	assert_true(settings.set_value("map/owner_tint", true))
	assert_true(_scene.overlay().visible)

	# Below far zoom, TileMapView hides while ModeOverlay and CapitalMarks remain visible.
	_scene.set_mode(MapModes.Mode.OWNER)
	_scene.frame_at(_scene.map_size() / 2.0, 0.1)
	assert_false(_scene.view().visible)
	assert_true(_scene.far().visible)
	assert_true(_scene.overlay().visible, "ModeOverlay stays visible over FarMap")
	assert_true(_scene.capital_marks().visible, "CapitalMarks stay visible over FarMap")


func test_transfer_through_session_rebuilds_only_touched_chunks_and_texels() -> void:
	var game := _multi_chunk_scenario_game()
	Session.start_game(game)
	_finish_fill()
	assert_eq(_scene.view().border_chunks().size(), 2, "chunks (0, 0) and (0, 1) hold the col 19/20 border")

	var transfer_hex := Vector2i(5, 5)  # deep inside chunk (0, 0)
	if game.map.land[game.map.index_of(transfer_hex)] == 0:
		for r: int in 10:
			for c: int in 10:
				var cand := Vector2i(c, r)
				if game.map.is_land(cand):
					transfer_hex = cand
					break
			if game.map.is_land(transfer_hex):
				break
	var expected_chunks := BorderLines.chunks_touched(game.map, [transfer_hex])
	assert_eq(expected_chunks, [Vector2i(0, 0)] as Array[Vector2i], "only chunk (0, 0) is touched")

	var rebuilds_before := _scene.border_chunk_rebuilds
	var writes_before := _scene.overlay().texel_writes
	var updates_before := _scene.overlay().texture_updates
	var untouched_node := _scene.view().get_node("Borders/Borders_0_1")

	assert_eq(Territory.transfer(game, [transfer_hex], 2), 1)
	Session.drain()

	assert_eq(_scene.border_chunk_rebuilds - rebuilds_before, expected_chunks.size(),
		"rebuilds exactly chunks_touched count")
	assert_eq(_scene.last_rebuilt_border_chunks, expected_chunks)
	assert_same(_scene.view().get_node("Borders/Borders_0_1"), untouched_node,
		"untouched border chunk node is preserved")
	assert_eq(_scene.overlay().texel_writes - writes_before, 1, "writes exactly 1 overlay texel")
	assert_eq(_scene.overlay().texture_updates - updates_before, 1, "performs 1 GPU texture update")
	assert_eq(_scene.overlay().owner_image().get_pixelv(transfer_hex).r8, 2)


func test_picking_signals_hover_and_country_chosen() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	_finish_fill()

	var settings := Settings.new("macOS", false)
	_scene.configure(settings)
	assert_eq(_scene.mode(), int(MapModes.Mode.OWNER))
	assert_eq(str(settings.get_value("state/map_mode")), "terrain", "picking does not overwrite state/map_mode")

	var clicked: Array[StringName] = []
	var hovered: Array[StringName] = []
	_scene.country_clicked.connect(func(tag: StringName) -> void: clicked.append(tag))
	_scene.country_hovered.connect(func(tag: StringName) -> void: hovered.append(tag))

	# Clicking Milan while picking emits country_clicked(&"MLO") and does not select hex.
	_click_world_hex(Vector2i(9, 9))
	assert_eq(clicked, [&"MLO"] as Array[StringName])
	assert_eq(_scene.selected, MapScene.NO_HEX)

	# Clicking sea while picking emits nothing and does not select hex.
	_click_world_hex(Vector2i(19, 10))
	assert_eq(clicked, [&"MLO"] as Array[StringName])
	assert_eq(_scene.selected, MapScene.NO_HEX)

	# Hovering Genoa sets hot_id and emits country_hovered(&"GEN"); hovering sea clears both.
	_scene.map_input().hover_changed.emit(Vector2i(8, 13))
	assert_eq(_scene.overlay().hot_id(), Session.game.scenario.id_of(&"GEN"))
	_scene.map_input().hover_changed.emit(Vector2i(19, 10))
	assert_eq(_scene.overlay().hot_id(), 0)
	assert_eq(hovered, [&"GEN", &""] as Array[StringName])

	# Choosing a country ends picking, hides pennants, and restores state/map_mode (Terrain).
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	assert_false(_scene.picking())
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN))
	assert_false(_scene.capital_marks().visible)
	assert_eq(_scene.overlay().hot_id(), 0)

	# After choosing, clicking a hex selects it normally.
	_click_world_hex(Vector2i(8, 13))
	assert_eq(_scene.selected, Vector2i(8, 13))


func test_mode_overlay_setup_from_game_and_single_arg_update_hexes() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	var overlay := ModeOverlay.new()
	add_child_autofree(overlay)
	overlay.setup(Session.game, false)
	var gen_hex := Vector2i(8, 13)
	var mlo_id := Session.game.scenario.id_of(&"MLO")
	assert_eq(overlay.owner_image().get_pixelv(gen_hex).r8, Session.game.scenario.id_of(&"GEN"))

	overlay.set_palette(true)
	var cb_pal := MapModes.palette(Session.game, true)
	assert_true(overlay.palette_image().get_pixel(mlo_id, 0).is_equal_approx(cb_pal[mlo_id]))

	Territory.transfer(Session.game, [gen_hex], mlo_id)
	Session.game.events.clear()
	overlay.update_hexes([gen_hex])
	assert_eq(overlay.owner_image().get_pixelv(gen_hex).r8, mlo_id)


func _choose_genoa() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	_finish_fill()
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))


func test_key_4_is_refused_in_a_sandbox_and_while_picking_and_the_mode_ignored() -> void:
	Bindings.ensure()
	var reasons: Array[String] = []
	var refused_modes: Array[int] = []
	_scene.refused.connect(func(r: String) -> void: reasons.append(r))
	_scene.map_mode_refused.connect(func(m: int) -> void: refused_modes.append(m))
	_scene.map_input()._unhandled_input(_key_event(KEY_4))
	assert_eq(reasons, ["No countries on this map"])
	_scene.set_mode(MapModes.Mode.YIELDS)
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN), "a mode the game does not offer is ignored")
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	_finish_fill()
	_scene.map_input()._unhandled_input(_key_event(KEY_4))
	assert_eq(refused_modes, [3, 3], "refused while picking too")
	assert_eq(_scene.mode(), int(MapModes.Mode.OWNER), "picking keeps Owner")


func test_yields_follows_the_game_only_while_in_yields() -> void:
	Bindings.ensure()
	_choose_genoa()
	var overlay := _scene.overlay()
	var writes := overlay.texel_writes
	Events.tax_set.emit(&"GEN", 2)
	Events.season_ended.emit(1)
	assert_eq(overlay.texel_writes, writes, "nothing is computed or written in Terrain")
	var settings := Settings.new("macOS", false)
	_scene.configure(settings)
	_scene.map_input()._unhandled_input(_key_event(KEY_4))
	assert_eq(_scene.mode(), int(MapModes.Mode.YIELDS))
	assert_eq(str(settings.get_value("state/map_mode")), "yields", "the switch writes state/map_mode")
	var want := MapModes.yield_bytes(Session.game, &"GEN")
	assert_eq(overlay.yields_bytes(), want)
	var hex := Vector2i(7, 13)  # land changes hands: its texel is veiled
	Session.game.version += 1
	Session.game.state.owner[Session.game.map.index_of(hex)] = 0
	Events.owners_changed.emit([hex] as Array[Vector2i])
	assert_eq(overlay.yields_bytes(), MapModes.yield_bytes(Session.game, &"GEN"))


func test_a_saved_yields_mode_comes_back_and_falls_back_to_terrain() -> void:
	var settings := Settings.new("macOS", false)
	settings.set_value("state/map_mode", "yields")
	_scene.configure(settings)
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN), "a sandbox does not offer Yields")
	assert_eq(str(settings.get_value("state/map_mode")), "yields", "and the saved value is kept")
	_choose_genoa()
	_scene.configure(settings)
	assert_eq(_scene.mode(), int(MapModes.Mode.YIELDS), "restored once the game offers it")
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	assert_eq(_scene.mode(), int(MapModes.Mode.TERRAIN), "a new sandbox falls back")
