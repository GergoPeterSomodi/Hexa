## End-to-end M1.5 App flow test:
## Boot to MainMenu -> Sandbox -> first-run HelpOverlay -> Esc ladder (Help -> Selection clear -> PauseMenu)
## -> Options -> Back -> Build (unsaved_actions > 0) -> MainMenu Confirm -> Sandbox again, with zero orphans
## (docs/architecture/ui-and-controls-spec.md section 9; ui-and-controls-plan.md U15).
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")

var _prev_game: Game = null
var _prev_unsaved: int = 0
var _old_max_fps: int = 0
var _old_low_proc: bool = false
var _old_tooltip_delay: float = 0.5


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_old_max_fps = Engine.max_fps
	_old_low_proc = OS.low_processor_usage_mode
	_old_tooltip_delay = float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))


func after_each() -> void:
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Bindings.reset_defaults()
	Engine.max_fps = _old_max_fps
	OS.low_processor_usage_mode = _old_low_proc
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", _old_tooltip_delay)
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


func _wait_frames(frames: int = 2) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _send_key(vp: SubViewport, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	vp.push_input(press)

	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	vp.push_input(release)


func _first_buildable_hex() -> Vector2i:
	var g := Session.game
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or not Improve.piece_at(g, hex).is_empty():
			continue
		for opt: Dictionary in Improve.build_options(g, hex):
			if bool(opt["ok"]):
				return hex
	return MapScene.NO_HEX


func test_full_m1_5_app_flow_and_esc_ladder() -> void:
	await _wait_frames(2)
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child(vp)

	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	var s := Settings.new("macOS", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	await _wait_frames(2)

	await _verify_boot_and_sandbox_launch(app, s, "1492", true)
	await _verify_esc_ladder_and_options(vp, app)
	await _verify_build_confirm_menu_and_relaunch(vp, app)

	remove_child(vp)
	vp.queue_free()
	await _wait_frames(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_eq(orphans_after, orphans_before, "full flow teardown leaves zero orphan nodes")


func _verify_boot_and_sandbox_launch(app: App, s: Settings, seed_str: String, expect_help: bool) -> void:
	var main_menu := app.stack().top() as MainMenu
	assert_not_null(main_menu, "on MainMenu")
	assert_true(app.hides_world())
	assert_true(app.wants_pause())
	assert_null(app.map_scene())

	main_menu.sandbox_button().pressed.emit()
	await _wait_frames(2)
	var sandbox := app.stack().top() as Sandbox
	assert_not_null(sandbox, "Sandbox screen opened")
	sandbox.seed_input().text = seed_str
	sandbox.start_button().pressed.emit()
	await _wait_frames(5)

	assert_not_null(Session.game)
	assert_eq(Session.game.seed_value, seed_str.to_int())
	assert_not_null(app.map_scene(), "MapScene created inside World")
	assert_eq(app.world_host().get_child_count(), 1)
	assert_false(app.hides_world())
	assert_false(app.wants_pause())
	assert_true(app.hud().visible)
	if expect_help:
		assert_not_null(app.stack().top(), "HelpOverlay auto-opens on first sandbox entry")
		assert_eq(app.stack().top().screen_id, &"help")
		assert_true(bool(s.get_value("state/help_seen")))
	else:
		assert_eq(app.stack().count(), 0, "HelpOverlay does not re-open when state/help_seen is true")


func _verify_esc_ladder_and_options(vp: SubViewport, app: App) -> void:
	var map_scene := app.map_scene()

	# Esc ladder step 1: Esc closes HelpOverlay
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "first Esc closes HelpOverlay")
	assert_false(app.wants_pause())

	# Esc ladder step 2: select hex -> HexPanel opens -> Esc clears selection
	var hex := _first_buildable_hex()
	assert_ne(hex, MapScene.NO_HEX)
	map_scene.select_hex(hex)
	await _wait_frames(2)
	assert_eq(map_scene.selected, hex)
	assert_true(app.hud().hex_panel().visible)
	assert_true(app.hud().is_dock_open())

	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(map_scene.selected, MapScene.NO_HEX, "second Esc clears hex selection")
	assert_false(app.hud().hex_panel().visible)
	assert_eq(app.stack().count(), 0)

	# Esc ladder step 3: Esc with no selection opens PauseMenu -> Options -> Back
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	var pause := app.stack().top() as PauseMenu
	assert_not_null(pause, "third Esc opens PauseMenu")
	assert_true(app.wants_pause())

	pause.options_button().pressed.emit()
	await _wait_frames(2)
	var options := app.stack().top() as Options
	assert_not_null(options, "Options pushed onto stack")
	options.select_page(&"map")
	await _wait_frames(1)
	var grid_sw := options.option_row("map/grid").control() as KitSwitch
	grid_sw.button_pressed = true
	assert_true(map_scene.view().layer("grid").visible, "Map grid option updates MapScene live")

	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(app.stack().top(), pause, "Esc returns from Options to PauseMenu")


func _verify_build_confirm_menu_and_relaunch(vp: SubViewport, app: App) -> void:
	var map_scene := app.map_scene()
	var hex := _first_buildable_hex()

	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0)
	map_scene.select_hex(hex)
	await _wait_frames(1)
	var build_btn: Button = null
	for b: Button in app.hud().hex_panel().action_buttons():
		if not b.disabled and b.text.begins_with("Build"):
			build_btn = b
			break
	assert_not_null(build_btn, "HexPanel has enabled Build button")
	build_btn.pressed.emit()
	await _wait_frames(1)
	assert_eq(Session.unsaved_actions, 1, "HexPanel build increments Session.unsaved_actions")

	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(1)
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	var pause := app.stack().top() as PauseMenu
	assert_not_null(pause)

	pause.main_menu_button().pressed.emit()
	await _wait_frames(2)
	var confirm := app.stack().top() as Confirm
	assert_not_null(confirm, "Main menu asks Confirm when unsaved_actions > 0")
	confirm.button_for(&"confirm").pressed.emit()
	await _wait_frames(3)

	assert_null(Session.game, "Session.end_game cleared game")
	assert_eq(Session.unsaved_actions, 0)
	assert_null(app.map_scene(), "World freed cleanly")
	assert_eq(app.world_host().get_child_count(), 0)
	assert_false(app.hud().visible)
	assert_true(app.hides_world())

	await _verify_boot_and_sandbox_launch(app, app.settings(), "1500", false)


# ----- M2: new game, the pick, Play as, the country panel (docs/architecture/m2-build-spec.md sections 7.11 and 10) -----


func _scenario_app(cli_args: PackedStringArray = PackedStringArray()) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = cli_args
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	return {"vp": vp, "app": app}


## Waits until `done` is true, at most `limit` frames; returns whether it became true.
func _wait_until(done: Callable, limit: int = 3000) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


func test_new_game_pick_play_as_genoa_panel_and_pause() -> void:
	var env := await _scenario_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	await _wait_frames(2)

	var menu := app.stack().top() as MainMenu
	assert_not_null(menu)
	assert_true(menu.new_game_button().visible)
	menu.new_game_button().pressed.emit()
	await _wait_frames(2)
	var new_game := app.stack().top() as NewGame
	assert_not_null(new_game, "New game opens")
	new_game.seed_input().text = "1480"
	new_game.begin_button().pressed.emit()

	assert_true(await _wait_until(func() -> bool: return app.stack().top() is CountryPick), "the pick opens")
	assert_eq(Session.game.seed_value, 1480)
	assert_true(Session.game.has_countries())
	assert_eq(Session.player_tag(), &"", "nobody is chosen yet")
	assert_true(app.map_scene().picking())
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.OWNER), "the pick shows the map in Owner mode")
	assert_false(app.hides_world())

	var pick := app.stack().top() as CountryPick
	pick.row_button(&"GEN").pressed.emit()
	await _wait_frames(2)
	assert_eq(app.hud().country_panel().shown_tag(), &"GEN", "a row shows its panel in the dock")
	assert_eq(app.stack().top(), pick, "showing does not end the pick")
	pick.row_button(&"GEN").pressed.emit()
	await _wait_frames(3)

	assert_eq(Session.player_tag(), &"GEN")
	assert_eq(app.stack().count(), 0, "the pick ends once a country is chosen")
	assert_eq(Session.unsaved_actions, 0, "choosing a country is not unsaved work")
	assert_eq(app.hud().top_bar().country_button().text, "Republic of Genoa")
	assert_false(app.hud().country_panel().visible)
	assert_false(app.map_scene().picking())

	_send_key(vp, KEY_C)
	await _wait_frames(2)
	assert_eq(app.hud().country_panel().shown_tag(), &"GEN", "C opens your country's panel")
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_false(app.hud().country_panel().visible, "Esc closes the panel")
	assert_eq(app.stack().count(), 0)
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	var pause := app.stack().top() as PauseMenu
	assert_not_null(pause, "the next Esc pauses")
	assert_eq(pause.subtitle_label().text, "Republic of Genoa · Spring 1480", "the subtitle names the country and the date")


func test_show_on_the_map_switches_to_owner_mode() -> void:
	var env := await _scenario_app(PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and not app.map_scene().is_loading()))
	await _wait_until(func() -> bool: return app.stack().count() == 0)
	app.map_scene().set_mode(int(MapModes.Mode.TERRAIN))
	app.hud().country_look_at_requested.emit(Vector2i(10, 10))
	await _wait_frames(1)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.OWNER))


func test_command_line_new_game_with_a_country_skips_the_pick() -> void:
	var env := await _scenario_app(PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and not app.map_scene().is_loading()))
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "no pick, no loading")
	assert_eq(Session.player_tag(), &"GEN")
	assert_eq(Session.game.seed_value, 1480)
	assert_eq(Session.unsaved_actions, 0)
	assert_false(app.map_scene().picking())
	assert_false(app.hides_world())
	assert_eq(app.hud().top_bar().country_button().text, "Republic of Genoa")


func test_command_line_new_game_without_a_country_opens_the_pick() -> void:
	var env := await _scenario_app(PackedStringArray(["--new-game", "--seed=7"]))
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is CountryPick))
	assert_eq(Session.player_tag(), &"")


func test_a_scenario_the_rules_refuse_toasts_and_returns_to_the_main_menu() -> void:
	var env := await _scenario_app()
	var app := env["app"] as App
	await _wait_frames(2)
	var toasts: Array = []
	app.context().toast_requested.connect(func(text: String, tone: StringName) -> void: toasts.append([text, tone]))
	app.context().request(&"new_game", {"scenario": "no_such_scenario", "seed": 5})
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu, 60))
	assert_eq(toasts.size(), 1)
	assert_eq((toasts[0] as Array)[1], &"bad")
	assert_null(app.map_scene())
	assert_true(app.hides_world())
