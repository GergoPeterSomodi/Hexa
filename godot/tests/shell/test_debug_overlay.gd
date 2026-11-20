## GUT tests for Studiolo F3 DebugOverlay metrics, developer gating, and diagnostic intents
## (docs/architecture/ui-and-controls-spec.md section 7; ui-style-and-feedback-plan.md U14).
extends GutTest

const DEBUG_SCENE := preload("res://shell/hud/debug_overlay.tscn")

var _harness: UIHarness = null
var _overlay: DebugOverlay = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_harness = UIHarness.new()
	_harness.mount(self)
	_overlay = DEBUG_SCENE.instantiate() as DebugOverlay
	_overlay.theme = KitTheme.load_for(1.0)
	_overlay.configure(_harness.settings)
	_harness.viewport.add_child(_overlay)


func after_each() -> void:
	_overlay = null
	_harness = null
	Session.game = _prev_game
	Bindings.reset_defaults()


func test_f3_toggle_developer_gating_and_metrics_population() -> void:
	assert_false(_overlay.visible, "hidden by default")
	assert_eq(_overlay.mouse_filter, Control.MOUSE_FILTER_STOP)

	# Simulate F3 toggle via Bindings dev_debug
	var f3_ev := Bindings.events_for(&"dev_debug")[0] as InputEventKey
	assert_not_null(f3_ev)
	assert_true(f3_ev.is_action(&"dev_debug"))

	_overlay.toggle()
	assert_true(_overlay.visible, "opens when developer_tools is on")

	_overlay.set_snapshot({
		"zoom": 1.25,
		"camera_pos": Vector2(640.0, 480.0),
		"visible_rect": Rect2(128.0, 96.0, 1024.0, 576.0),
		"hovered_hex": Vector2i(7, 9),
		"season": "autumn",
		"seed": 1480,
		"chunks": 4,
		"layers": 23,
		"cells": 4200,
		"line_chunks": 4,
		"hexes_on_screen": 180,
		"fill_progress": 1.0,
		"swapping": false,
		"slice_ms": 8,
		"digest": "abcd1234",
	})
	var txt := _overlay.metrics_text()
	assert_true(txt.contains("FPS:"), "includes FPS")
	assert_true(txt.contains("worst:"), "includes worst frame ms")
	assert_true(txt.contains("proc:"), "includes TIME_PROCESS ms")
	assert_true(txt.contains("Draw calls:"), "includes draw calls")
	assert_true(txt.contains("Objects:"), "includes objects")
	assert_true(txt.contains("Mem static:"), "includes static mem")
	assert_true(txt.contains("video:"), "includes video mem")
	assert_true(txt.contains("tex:"), "includes texture mem")
	assert_true(txt.contains("Camera zoom: 1.25"), "includes zoom")
	assert_true(txt.contains("pos: (640, 480)"), "includes camera position")
	assert_true(txt.contains("Visible rect: (128, 96, 1024 x 576)"), "includes visible rect")
	assert_true(txt.contains("Hex: (7, 9)"), "includes hovered hex")
	assert_true(txt.contains("Season: autumn"), "includes season")
	assert_true(txt.contains("Seed: 1480"), "includes seed")
	assert_true(txt.contains("slice: 8 ms"), "includes slice_ms")
	assert_true(txt.contains("Digest: abcd1234"), "includes digest")
	assert_true(txt.contains("Renderer:"), "includes renderer")

	_harness.settings.set_value("dev/developer_tools", false)
	assert_false(_overlay.visible, "closes when developer_tools turns off")
	_overlay.set_open(true)
	assert_false(_overlay.visible, "cannot open while developer_tools is off")


func test_debug_controls_emit_intents_and_take_no_focus() -> void:
	_overlay.set_open(true)
	await _harness.wait_frames(self, 1)

	assert_eq(_overlay.new_seed_button().focus_mode, Control.FOCUS_NONE)
	assert_eq(_overlay.far_zoom_slider().slider().focus_mode, Control.FOCUS_NONE)
	assert_eq(_overlay.slice_ms_slider().slider().focus_mode, Control.FOCUS_NONE)

	var seasons: Array[int] = []
	var new_seeds := [0]
	var layers: Array[Array] = []
	var far_zooms: Array[float] = []
	var slices: Array[int] = []

	_overlay.season_preview_requested.connect(func(i: int) -> void: seasons.append(i))
	_overlay.new_seed_requested.connect(func() -> void: new_seeds[0] += 1)
	_overlay.debug_layer_toggled.connect(func(l: StringName, on: bool) -> void: layers.append([l, on]))
	_overlay.far_zoom_changed.connect(func(v: float) -> void: far_zooms.append(v))
	_overlay.slice_ms_changed.connect(func(ms: int) -> void: slices.append(ms))

	_overlay.season_segmented().button_for(3).pressed.emit()
	_overlay.season_segmented().select(3, true)
	assert_true(seasons.has(3), "season segmented emits season_preview_requested")

	_overlay.new_seed_button().pressed.emit()
	assert_eq(new_seeds[0], 1, "new seed emits new_seed_requested")

	var sw_trees := _overlay.layer_switch(&"trees")
	assert_not_null(sw_trees)
	assert_eq(sw_trees.focus_mode, Control.FOCUS_NONE)
	sw_trees.button_pressed = false
	assert_true(layers.has([&"trees", false]), "layer switch emits debug_layer_toggled")

	var sw_far := _overlay.layer_switch(&"far_locked")
	assert_not_null(sw_far)
	sw_far.button_pressed = true
	assert_true(layers.has([&"far_locked", true]), "far_locked switch emits debug_layer_toggled")

	_overlay.far_zoom_slider().set_slider_value(0.35, true)
	assert_eq(far_zooms.size(), 1)
	assert_almost_eq(far_zooms[0], 0.35, 0.001)
	assert_almost_eq(float(_harness.settings.get_value("dev/far_zoom")), 0.35, 0.001)

	_overlay.slice_ms_slider().set_slider_value(10.0, true)
	assert_eq(slices, [10])
	assert_eq(int(_harness.settings.get_value("dev/slice_ms")), 10)


func test_the_m3_line_shows_turn_date_works_phases_and_save() -> void:
	Session.new_scenario("north_italy_1480", 5, &"GEN")
	_overlay.set_open(true)
	assert_true(_overlay.m3_text().begins_with("turn 1 · Spring 1480 · works 0 · phases none yet · save none yet"), _overlay.m3_text())
	Session.last_phase_ms = {"works": 0.4, "stats": 0.2, "calendar": 0.0}
	_overlay.record_save_ms(32.4)
	assert_eq(_overlay.m3_text(), "turn 1 · Spring 1480 · works 0 · phases works 0.4, stats 0.2, calendar 0.0 ms · save 32 ms")
	Session.end_season()
	_overlay.refresh_metrics()
	assert_true(_overlay.m3_text().begins_with("turn 2 · Summer 1480"), _overlay.m3_text())
	assert_true(_overlay.m3_text().contains("phases works "), "the last season's phase times")
	Session.game = null
	_overlay.refresh_metrics()
	assert_eq(_overlay.m3_text(), "no game")


func test_look_control_offers_calendar_and_four_seasons_with_minus_one_for_calendar() -> void:
	var seg := _overlay.season_segmented()
	for id: int in [-1, 0, 1, 2, 3]:
		assert_not_null(seg.button_for(id), "Look has option %d" % id)
	assert_eq(seg.button_for(-1).text, "Calendar")
	assert_eq(seg.selected_id(), -1, "starts on the calendar")
	var seen: Array[int] = []
	_overlay.season_preview_requested.connect(func(i: int) -> void: seen.append(i))
	seg.select(2, true)
	seg.select(-1, true)
	assert_eq(seen, [2, -1])
	_overlay.set_season(-1)
	assert_eq(seg.selected_id(), -1)
	_overlay.set_season(9)
	assert_eq(seg.selected_id(), 3, "clamped to Winter")


func test_focus_console_opens_the_panel_and_hosts_the_console() -> void:
	assert_not_null(_overlay.console())
	assert_true(_overlay.focus_console())
	assert_true(_overlay.visible)
	_harness.settings.set_value("dev/developer_tools", false)
	assert_false(_overlay.focus_console(), "no console with developer tools off")
