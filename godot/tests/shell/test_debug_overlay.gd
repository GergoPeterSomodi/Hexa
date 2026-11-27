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
	Session.last_phase_ms = {"works": 0.4, "stats": 0.2, "calendar": 0.0}  # any names: the line prints what it is given
	_overlay.record_save_ms(32.4)
	assert_eq(_overlay.m3_text(), "turn 1 · Spring 1480 · works 0 · phases works 0.4, stats 0.2, calendar 0.0 ms · save 32 ms")
	Session.end_season()
	_overlay.refresh_metrics()
	assert_true(_overlay.m3_text().begins_with("turn 2 · Summer 1480"), _overlay.m3_text())
	assert_true(_overlay.m3_text().contains("phases ai_orders "), "the last season's phase times")
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


func test_the_m4_line_shows_the_phase_times_the_cached_districts_and_the_weather() -> void:
	Session.new_scenario("north_italy_1480", 5, &"GEN")
	_overlay.set_open(true)
	assert_eq(_overlay.m4_text(), "production none yet · income none yet · districts cached %d · weather calm, calm, calm" % Session.game.districts.size())
	Session.last_phase_ms = {"production": 3.14, "income": 0.42, "works": 0.1}
	Session.game.weather = PackedByteArray([0, 1, 2])
	_overlay.refresh_metrics()
	assert_true(_overlay.m4_text().begins_with("production 3.1 ms · income 0.4 ms · districts cached "), _overlay.m4_text())
	assert_true(_overlay.m4_text().ends_with(" · weather calm, good, poor"), _overlay.m4_text())
	Session.end_season()
	_overlay.refresh_metrics()
	assert_false(_overlay.m4_text().contains("none yet"), "a played season has timed both phases: " + _overlay.m4_text())
	assert_gt(Session.game.districts.size(), 0, "the cache is filled by the production phase")
	assert_true(_overlay.m4_text().contains("districts cached %d" % Session.game.districts.size()))
	Session.game = null
	_overlay.refresh_metrics()
	assert_eq(_overlay.m4_text(), "no game")


## M5 spec 6.10: "people 1.8 ms · grew 2 · declined 0 · hungry countries 1".
func test_the_people_line_shows_the_phase_time_the_level_changes_and_the_hungry_countries() -> void:
	assert_eq(_overlay.people_text(), "no game" if Session.game == null else _overlay.people_text())
	Session.new_scenario("north_italy_1480", 5, &"GEN")
	_overlay.set_open(true)
	assert_eq(_overlay.people_text(), "people none yet · grew 0 · declined 0 · hungry countries 0")
	Session.last_phase_ms = {"people": 1.84}
	Events.town_grew.emit(&"GEN", Vector2i(1, 1), 3)
	Events.town_grew.emit(&"GEN", Vector2i(2, 1), 3)
	Events.district_declined.emit(&"GEN", Vector2i(3, 1), 2, &"hunger")
	Events.season_ended.emit(1)
	Session.game.countries[0].food_fed = 400
	_overlay.refresh_metrics()
	assert_eq(_overlay.people_text(), "people 1.8 ms · grew 2 · declined 1 · hungry countries 1")
	Events.season_ended.emit(2)
	assert_eq(_overlay.people_text(), "people 1.8 ms · grew 0 · declined 0 · hungry countries 1", "the count starts again each season")
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_overlay.refresh_metrics()
	assert_eq(_overlay.people_text(), "no people in a map-only game")
	Session.game = null
	_overlay.refresh_metrics()
	assert_eq(_overlay.people_text(), "no game")


## M4.5 spec 6.9: the study line names the page and tab last built, its time and the warm queue; before a first open it says so.
## M6 (L24): the armies line counts the armies and units and shows the phase times of the last season (none before one).
func test_the_m6_line_counts_armies_and_units_and_the_last_phase_times() -> void:
	_overlay.refresh_metrics()
	assert_true(_overlay.m6_text().begins_with("armies 0 · units 0 · movement none yet · supply none yet · vision none yet"), _overlay.m6_text())
	assert_true(_overlay.m6_text().ends_with("steps filled 0"), "no army, no step table")
	Session.last_phase_ms = {"movement": 0.6, "supply": 0.4, "vision": 0.2}
	_overlay.refresh_metrics()
	assert_true(_overlay.m6_text().contains("movement 0.6 ms · supply 0.4 ms · vision 0.2 ms"), _overlay.m6_text())
	Session.last_phase_ms = {}


func test_the_study_line_shows_the_last_page_built_and_the_warm_queue() -> void:
	_overlay.set_open(true)
	assert_eq(_overlay.study_text(), "study not opened yet · warm queue 0", "no source: nothing opened yet")
	var holder := {"info": {"page": &"economy", "tab": &"districts", "ms": 3.44, "warm": 2}}
	_overlay.study_info_func = func() -> Dictionary: return holder["info"]
	_overlay.refresh_metrics()
	assert_eq(_overlay.study_text(), "study economy/districts built in 3.4 ms · warm queue 2")
	holder["info"] = {"page": &"rankings", "tab": &"", "ms": 0.0, "warm": 0}
	_overlay.refresh_metrics()
	assert_eq(_overlay.study_text(), "study rankings built in 0.0 ms · warm queue 0", "a page without tabs shows its name only")
	holder["info"] = {"warm": 5}
	_overlay.refresh_metrics()
	assert_eq(_overlay.study_text(), "study not opened yet · warm queue 5")
	Session.game = null
	_overlay.refresh_metrics()
	assert_eq(_overlay.study_text(), "no game")


func test_the_f3_mode_word_names_yields() -> void:
	assert_eq(DebugOverlay.MODE_WORDS[int(MapModes.Mode.YIELDS)], "Yields")
	assert_eq(DebugOverlay.MODE_WORDS[int(MapModes.Mode.FOOD)], "Food", "F3 names the Food mode, not Yields")
	assert_eq(DebugOverlay.MODE_WORDS[int(MapModes.Mode.GOODS)], "Goods", "and the seventh, Goods")
	assert_eq(DebugOverlay.MODE_WORDS.size(), MapModes.MODE_KEYS.size(), "a word for every mode")


## M7 (B28, spec 6.11): the war line counts the live wars, the kept battles, the sieges and the occupied hexes, with the last
## season's phase times.
func test_the_m7_line_counts_wars_sieges_and_occupied_hexes() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480, &"SAV"), "", "a scenario game")
	_overlay.refresh_metrics()
	assert_eq(_overlay.m7_text(), "wars 0 · battles 0 · sieges 0 · occupied 0 · battles none yet · sieges none yet · war none yet · areas 0", _overlay.m7_text())
	assert_true(bool(Session.act("declare_war", {"target": &"MLO"}).get("ok", false)), "Savoy declares on Milan")
	Session.last_phase_ms = {"battles": 0.8, "sieges": 0.3, "war": 0.0}
	_overlay.refresh_metrics()
	assert_true(_overlay.m7_text().begins_with("wars 1 · battles 0 · sieges 0 · occupied 0 · battles 0.8 ms · sieges 0.3 ms · war 0.0 ms"), _overlay.m7_text())
	Session.last_phase_ms = {}
	Session.game = null
	_overlay.refresh_metrics()
	assert_eq(_overlay.m7_text(), "no game")


## K27 (spec 6.5): the F3 AI line says no AI without countries, and counts the seats, the time and the passive seats.
func test_the_ai_line_says_no_ai_without_countries_and_shows_the_turn() -> void:
	_overlay.refresh_metrics()
	assert_eq(_overlay.ai_text(), "no AI in this game", _overlay.ai_text())
	assert_eq(Session.new_scenario("north_italy_1480", 1480, &"SAV"), "", "a scenario game")
	_overlay.refresh_metrics()
	assert_true(_overlay.ai_text().begins_with("ai "), _overlay.ai_text())
	assert_true(_overlay.ai_text().contains("none yet"), _overlay.ai_text())
	assert_true(_overlay.ai_text().ends_with("passive 0"), _overlay.ai_text())
	Session.set_seat_passive(&"MLO", true)
	_overlay.refresh_metrics()
	assert_true(_overlay.ai_text().ends_with("passive 1"), _overlay.ai_text())
	Session.set_seat_passive(&"MLO", false)
	Session.last_phase_ms = {"ai_orders": 61.2}
	Session.ai_worst_step_ms = 2.1
	_overlay.refresh_metrics()
	assert_true(_overlay.ai_text().contains("· 61.2 ms · worst step 2.1 ms"), _overlay.ai_text())
	Session.last_phase_ms = {}
	Session.ai_worst_step_ms = 0.0
	Session.game = null
	_overlay.refresh_metrics()
	assert_eq(_overlay.ai_text(), "no game")
