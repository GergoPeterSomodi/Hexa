## GUT tests for App root: boot routes, CLI --sandbox/--seed/--plain-ui, theme loading/hot-swap,
## HUD/screen input isolation, close request / quit confirmation, focus FPS throttling, and zero orphans
## (docs/architecture/ui-and-controls-spec.md sections 3.1, 3.6, 5.3, 6.1, 6.2, 9;
## docs/architecture/ui-style-and-feedback-spec.md section 4.8).
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


func _spawn_app(
	cli_args: PackedStringArray = PackedStringArray(),
	help_seen: bool = true,
	custom_settings: Settings = null
) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)

	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.skip_loading_frames = true
	app.cli_args_override = cli_args
	var s := custom_settings if custom_settings != null else Settings.new("macOS", true)
	if help_seen:
		s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	return {"vp": vp, "app": app, "settings": s}


func _wait_frames(frames: int = 2) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _send_click(vp: SubViewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = pos
	press.global_position = pos
	press.pressed = true
	vp.push_input(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = pos
	release.global_position = pos
	release.pressed = false
	vp.push_input(release)


func _send_wheel(vp: SubViewport, pos: Vector2, button: MouseButton = MOUSE_BUTTON_WHEEL_UP) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.position = pos
	ev.global_position = pos
	ev.pressed = true
	ev.factor = 1.0
	vp.push_input(ev)


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


func _first_land_hex() -> Vector2i:
	var g := Session.game
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1:
			return g.map.hex_of(i)
	return Vector2i.ZERO


func test_boot_opens_main_menu_and_hides_world_and_hud() -> void:
	var env := _spawn_app()
	var app := env["app"] as App
	await _wait_frames(2)

	assert_not_null(app.stack().top())
	assert_eq(app.stack().top().screen_id, &"main_menu")
	assert_true(app.hides_world(), "MainMenu is OPAQUE and hides world")
	assert_true(app.wants_pause(), "MainMenu wants pause")
	assert_null(app.map_scene(), "World has no MapScene on MainMenu")
	assert_false(app.hud().visible, "Hud hidden on MainMenu")


func test_cli_sandbox_and_seed_boots_directly_into_game() -> void:
	var env := _spawn_app(PackedStringArray(["--sandbox", "--seed=42"]), true)
	var app := env["app"] as App
	await _wait_frames(2)

	assert_not_null(Session.game)
	assert_eq(Session.game.seed_value, 42, "--seed=42 applied")
	assert_not_null(app.map_scene(), "MapScene created in World")
	assert_eq(app.map_scene().panel(), app.hud().tile_window(), "TileWindow injected into MapScene")
	assert_true(app.hud().visible, "Hud visible in sandbox")
	assert_false(app.hides_world())
	assert_false(app.wants_pause())
	assert_eq(app.stack().count(), 0)
	assert_true(app.hud().top_bar().map_info_label().text.contains("42"))


func test_cli_sandbox_without_seed_uses_valid_random_seed() -> void:
	var env := _spawn_app(PackedStringArray(["--sandbox"]), true)
	var app := env["app"] as App
	await _wait_frames(2)

	assert_not_null(Session.game)
	assert_not_null(app.map_scene())
	assert_gte(Session.game.seed_value, Sandbox.RANDOM_SEED_MIN)
	assert_lte(Session.game.seed_value, Sandbox.RANDOM_SEED_MAX)


func test_theme_plain_ui_flag_and_hot_swap_on_scale_and_high_contrast() -> void:
	var env_plain := _spawn_app(PackedStringArray(["--plain-ui"]))
	var app_plain := env_plain["app"] as App
	await _wait_frames(2)

	var plain_sb := app_plain.current_theme().get_stylebox(&"panel", &"PanelContainer")
	assert_true(plain_sb is StyleBoxFlat, "--plain-ui loads flat theme")
	assert_eq(app_plain.stack().theme, app_plain.current_theme())

	var env := _spawn_app()
	var app := env["app"] as App
	var s := env["settings"] as Settings
	await _wait_frames(2)

	var normal_sb := app.current_theme().get_stylebox(&"panel", &"PanelContainer") as StyleBoxTexture
	assert_not_null(normal_sb, "default boot loads Studiolo StyleBoxTexture theme")

	var reloads := [0]
	app.theme_reloaded.connect(func(_t: Theme) -> void: reloads[0] += 1)

	# Hot-swap to 200% scale -> 2x ImageTexture
	s.set_value("display/ui_scale", "200")
	assert_eq(reloads[0], 1)
	var sb_2x := app.current_theme().get_stylebox(&"panel", &"PanelContainer") as StyleBoxTexture
	assert_not_null(sb_2x)
	assert_true(sb_2x.texture is ImageTexture, "200% scale hot-swaps 2x ImageTexture")
	assert_eq(app.hud().root().theme, app.current_theme())
	assert_eq(app.stack().theme, app.current_theme())

	# Hot-swap to high_contrast -> StyleBoxFlat
	s.set_value("accessibility/high_contrast", true)
	assert_eq(reloads[0], 2)
	assert_true(app.current_theme().get_stylebox(&"panel", &"PanelContainer") is StyleBoxFlat)


func test_ui_covers_map_clicks_and_scroll_over_modal_does_not_zoom() -> void:
	var env := _spawn_app(PackedStringArray(["--sandbox", "--seed=1480"]), true)
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	await _wait_frames(2)

	var map_scene := app.map_scene()
	map_scene.frame_at(map_scene.map_size() * 0.5, 1.0)
	await _wait_frames(1)

	# Clicking TopBar must not select any hex on MapScene
	_send_click(vp, app.hud().top_bar().get_global_rect().get_center())
	await _wait_frames(1)
	assert_eq(map_scene.selected, MapScene.NO_HEX, "TopBar click does not reach MapScene")

	# Selecting a hex opens the TileWindow; clicking the TileWindow does not change selection
	var land_hex := _first_land_hex()
	map_scene.select_hex(land_hex)
	await _wait_frames(1)
	assert_true(app.hud().tile_window().visible)
	_send_click(vp, app.hud().tile_window().get_global_rect().get_center())
	await _wait_frames(1)
	assert_eq(map_scene.selected, land_hex, "TileWindow click does not hit map underneath")

	# Opening Options modal pauses map and wheel over Options does not zoom map
	var zoom_before := map_scene.zoom()
	app.context().request(&"open_screen", {"id": &"options"})
	await _wait_frames(2)
	assert_true(app.wants_pause())
	_send_wheel(vp, Vector2(640.0, 360.0), MOUSE_BUTTON_WHEEL_UP)
	await _wait_frames(2)
	assert_almost_eq(map_scene.zoom(), zoom_before, 0.0001, "wheel over modal Options does not zoom map")


func test_close_request_and_quit_intent_respect_unsaved_actions() -> void:
	# MainMenu quit intent quits immediately without Confirm
	var env_menu := _spawn_app()
	var app_menu := env_menu["app"] as App
	await _wait_frames(2)
	app_menu.context().request(&"quit")
	assert_eq(app_menu.quit_count(), 1, "MainMenu quit performs quit directly")

	# Sandbox with 0 unsaved_actions -> WM_CLOSE_REQUEST quits directly
	var env := _spawn_app(PackedStringArray(["--sandbox", "--seed=1480"]), true)
	var app := env["app"] as App
	await _wait_frames(2)
	assert_eq(Session.unsaved_actions, 0)
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(app.quit_count(), 1, "WM_CLOSE_REQUEST quits directly when unsaved_actions == 0")
	assert_eq(app.stack().count(), 0)

	# With unsaved_actions > 0 -> WM_CLOSE_REQUEST pushes Confirm; Cancel aborts, Confirm quits
	Session.unsaved_actions = 1
	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await _wait_frames(1)
	assert_eq(app.quit_count(), 1, "WM_CLOSE_REQUEST does not quit immediately when unsaved > 0")
	assert_eq(app.stack().top().screen_id, &"confirm")
	var confirm := app.stack().top() as Confirm
	confirm.button_for(&"cancel").pressed.emit()
	await _wait_frames(1)
	assert_eq(app.stack().count(), 0)
	assert_eq(app.quit_count(), 1)

	app.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await _wait_frames(1)
	var confirm2 := app.stack().top() as Confirm
	confirm2.button_for(&"confirm").pressed.emit()
	await _wait_frames(1)
	assert_eq(app.quit_count(), 2, "Confirming quit dialog performs quit")


func test_focus_out_and_in_throttles_and_restores_fps_cap() -> void:
	var s := Settings.new("macOS", true)
	s.set_value("display/fps_cap", 60)
	s.set_value("display/background_fps", 10)
	var env := _spawn_app(PackedStringArray(), true, s)
	var app := env["app"] as App
	await _wait_frames(1)

	assert_eq(Engine.max_fps, 60)
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(Engine.max_fps, 10, "background_fps caps Engine.max_fps on focus out")
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(Engine.max_fps, 60, "fg fps_cap restored on focus in")


func test_app_shortcuts_and_map_hud_wiring() -> void:
	var env := _spawn_app(PackedStringArray(["--sandbox", "--seed=1480"]), true)
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var s := env["settings"] as Settings
	await _wait_frames(2)

	# F1 toggles HelpOverlay
	_send_key(vp, KEY_F1)
	await _wait_frames(2)
	assert_eq(app.stack().top().screen_id, &"help", "F1 opens HelpOverlay")
	_send_key(vp, KEY_F1)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "F1 closes HelpOverlay")

	# F3 toggles DebugOverlay
	_send_key(vp, KEY_F3)
	await _wait_frames(1)
	assert_true(app.hud().is_debug_open(), "F3 opens DebugOverlay")
	_send_key(vp, KEY_F3)
	await _wait_frames(1)
	assert_false(app.hud().is_debug_open(), "F3 closes DebugOverlay")

	# M toggles PauseMenu
	_send_key(vp, KEY_M)
	await _wait_frames(2)
	assert_eq(app.stack().top().screen_id, &"pause_menu", "M opens PauseMenu")
	_send_key(vp, KEY_M)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "M closes PauseMenu")

	# H toggles photo mode (HUD visibility)
	_send_key(vp, KEY_H)
	await _wait_frames(1)
	assert_false(app.hud().is_hud_visible(), "H hides HUD")
	_send_key(vp, KEY_H)
	await _wait_frames(1)
	assert_true(app.hud().is_hud_visible(), "H restores HUD")

	# 3 and 1 switch map modes (Relief / Terrain); F3 Look previews a season
	_send_key(vp, KEY_3)
	await _wait_frames(1)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.RELIEF))
	_send_key(vp, KEY_1)
	await _wait_frames(1)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.TERRAIN))
	app.hud().debug_overlay().season_segmented().select(2, true)
	await _wait_frames(1)
	assert_eq(app.map_scene().season, "autumn", "F3's Look previews a season")
	app.hud().debug_overlay().season_segmented().select(-1, true)
	await _wait_frames(1)
	assert_eq(app.map_scene().season, "spring", "Look: Calendar goes back to the calendar's season")

	# U with no hex selected toasts refusal reason
	_send_key(vp, KEY_U)
	await _wait_frames(1)
	assert_eq(app.hud().toast_host().active_count(), 1, "refused upgrade shows toast")

	# F11 toggles window_mode between windowed and fullscreen
	assert_eq(s.get_value("display/window_mode"), "windowed")
	_send_key(vp, KEY_F11)
	await _wait_frames(1)
	assert_eq(s.get_value("display/window_mode"), "fullscreen")
	_send_key(vp, KEY_F11)
	await _wait_frames(1)
	assert_eq(s.get_value("display/window_mode"), "windowed")


func test_freeing_app_leaves_zero_orphans() -> void:
	await _wait_frames(2)
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child(vp)

	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.skip_loading_frames = true
	app.cli_args_override = PackedStringArray(["--sandbox", "--seed=1480"])
	var s := Settings.new("macOS", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	await _wait_frames(2)

	app.map_scene().select_hex(_first_land_hex())
	app.context().request(&"open_screen", {"id": &"pause_menu"})
	await _wait_frames(1)

	remove_child(vp)
	vp.queue_free()
	await _wait_frames(4)

	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_eq(orphans_after, orphans_before, "destroying App + World + Hud + Screens leaves zero orphans")
