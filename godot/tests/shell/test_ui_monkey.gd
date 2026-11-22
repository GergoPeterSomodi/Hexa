## Seeded deterministic UI & map monkey test (3 seeds x 600 synthetic events):
## exercises bound keys, viewport/HUD/screen clicks, mouse wheel with factors, trackpad
## pan/magnify gestures, drags, screen stack push/pop, Esc ladder, layers/seasons, and
## checks stack/shade/focus/zoom/bounds/digest invariants and zero leaked orphan nodes
## M4.5 adds Ctrl+[ and Ctrl+] (the study's tabs), key 4 (it was in the key pool already) and clicks on the tab strip and every
## button of the three pages; its invariant: the legend shows exactly in Yields or Food, with that mode's title (M5 adds key 5 and monkey_m5.gd: the chips, the People page, the console's `people`; seeds 1492 to 1494). The M4.5 seeds (1489 to 1491) add
## monkey_m45.gd's actions: tables, the timeline, the log's headers, chart hovers, Show on the map and Yields, with the digest,
## the version and the Stats unchanged by every study action.
## M4 (m4-build-spec.md section 9): the economy monkey adds I, L, [ and ], U, clicks on the chips, hex panel rows (hover and
## click), the works card (Begin, pin, Esc) and the study's tax buttons.
## (docs/architecture/ui-and-controls-spec.md section 9; ui-style-and-feedback-spec.md section 11).
## M6 (monkey_m6.gd): the armies, key 6 (Supply), the army panel, the Raise tab and the console's raise, the hex menu, the Military
## page, End season with its replay (skipped by Space, Esc or a click) and F5 and F9; seeds 1495 to 1497, each with the replay on.
## M7 (monkey_m7.gd): the war's inputs (Shift+right click, Shift+O, B, the badges, the battle dock, the hex menu's war items, the
## console's war commands, the country panel's declare and peace, the Castle areas switch, the standing orders) and its invariants
## (no leak of what the player was not told, the dock and the stack, no stuck Confirm); seeds 1498 to 1500, each playing Savoy.
extends MonkeyM7

const APP_SCENE := preload("res://shell/app/app.tscn")
const SEEDS: Array[int] = [1480, 1481, 1482]
## M3 (m3-build-spec.md section 9): country games with the season, save, load, bookmark and log keys.
const M3_SEEDS: Array[int] = [1483, 1484, 1485]
## M4: country games with the study, the chips, the rows and the works card.
const M4_SEEDS: Array[int] = [1486, 1487, 1488]
## M4.5: the same, with the M4.5 study's tables, timeline, log headers, charts, Show on the map and Yields.
const M45_SEEDS: Array[int] = [1489, 1490, 1491]
## M5: the same, with key 5 (Food), the People and Food chips, the People page and the console's `people`.
const M5_SEEDS: Array[int] = [1492, 1493, 1494]
## M6: the M5 monkey with the armies (monkey_m6.gd); the replay is on for every M6 seed (movement "normal").
const M6_SEEDS: Array[int] = [1495, 1496, 1497]
## M7: the M6 monkey with the war (monkey_m7.gd); every M7 seed plays Savoy.
const M7_SEEDS: Array[int] = [1498, 1499, 1500]
## A forced action runs from this step on when its counter is still 0 (so the invariants cannot pass empty).
const FORCE_SEASON_STEP := 30
const FORCE_SAVE_STEP := 120
const COUNTER_KEYS: Array[String] = [
	"picks", "works_begun", "works_cancelled", "seasons", "saves", "loads", "new_games", "games",
	"reports", "report_links", "log_opens", "log_lines", "save_screens", "slot_keys", "bookmarks_set", "bookmarks_go",
	"undos", "spaces", "double_spaces", "refused_spaces", "console_opens", "m3_keys", "view_checks", "roundtrips",
	"studies", "study_i", "study_l", "study_page_keys", "study_clicks", "tax_clicks", "tax_changes", "u_keys", "u_cards",
	"chip_clicks", "chip_cards", "row_hovers", "row_refused_hovers", "row_clicks", "card_begins", "card_pins", "card_escs",
	"orphan_cycles", "m4_checks", "study_tab_keys", "legend_checks",
	"m45_opens", "m45_tab_clicks", "m45_nav_clicks", "m45_head_clicks", "m45_row_clicks", "m45_row_keys", "m45_timeline",
	"m45_log_headers", "m45_chart_hovers", "m45_show_map", "m45_yields_keys", "m45_checks",
	"m5_food_keys", "m5_chip_clicks", "m5_chip_cards", "m5_people_page", "m5_page_actions", "m5_console", "m5_checks",
	"m6_supply_keys", "m6_selects", "m6_orders", "m6_panel_actions", "m6_raises", "m6_hex_menus", "m6_military_pages",
	"m6_replays", "m6_replay_blocked", "m6_file_keys", "m6_checks",
	"m7_storms", "m7_b_keys", "m7_badges", "m7_docks", "m7_hex_menus", "m7_console", "m7_declares", "m7_peaces", "m7_castle",
	"m7_standing", "m7_checks",
]
const EVENTS_PER_SEED := 600

## Documented non-fatal quirks (empty when clean; matches ui-and-controls-spec.md section 9).
const KNOWN_ISSUES: Array[Dictionary] = []

const SAFE_KEYS: Array[Key] = [
	KEY_ESCAPE,
	KEY_M,
	KEY_F1,
	KEY_F3,
	KEY_1,
	KEY_2,
	KEY_3,
	KEY_4,
	KEY_5,
	KEY_G,
	KEY_N,
	KEY_H,
	KEY_U,
	KEY_I,
	KEY_L,
	KEY_BRACKETLEFT,
	KEY_BRACKETRIGHT,
	KEY_F,
	KEY_EQUAL,
	KEY_MINUS,
	KEY_W,
	KEY_A,
	KEY_S,
	KEY_D,
	KEY_TAB,
	KEY_C,
	KEY_ENTER,
	KEY_UP,
	KEY_DOWN,
]

var _prev_game: Game = null
var _prev_unsaved: int = 0
var _old_max_fps: int = 0
var _old_low_proc: bool = false
var _old_tooltip_delay: float = 0.5
var _old_save_dir: String = ""
var _old_lock_path: String = ""
## The player seen after the pick, and the game it belongs to.
var _player_seen: StringName = &""
var _player_game: Game = null
## M3: the monkey's counters (every action it does and every effect it sees), the app under test and the clock reading
## of the last season (-1 after a new or loaded game: the flow and its guard were reset).
var _m3_app: App = null
## The turn, the season count and the slot at the start of the step (the digest check's diagnostic on failure).
var _step_turn: int = -1
var _step_seasons: int = 0
var _step_slot: String = ""
var _last_season_msec: int = -1


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_old_max_fps = Engine.max_fps
	_old_low_proc = OS.low_processor_usage_mode
	_old_tooltip_delay = float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))
	# Enter now ends seasons and autosaves: never the real user://saves (R11 rewrites the monkey for M3).
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	var apart := OS.get_environment("HEXA_MONKEY_APART")  # a name: this run keeps its own saves and lock, so seeds can run side by side
	Session.save_dir = "user://test_monkey_saves" + apart
	RunLock.path = "user://test_monkey_running%s.lock" % apart
	_clean_disk()


## Removes every file of the temporary save folder and the temporary lock (never the real ones).
func _clean_disk() -> void:
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	var dir := DirAccess.open(Session.save_dir)
	if dir != null:
		for file: String in dir.get_files():
			DirAccess.remove_absolute(Session.save_dir.path_join(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()


func after_each() -> void:
	_clean_disk()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Bindings.reset_defaults()
	Engine.max_fps = _old_max_fps
	OS.low_processor_usage_mode = _old_low_proc
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", _old_tooltip_delay)
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


func test_ui_monkey_seed_1480() -> void:
	await _run_monkey_seed(SEEDS[0])


func test_ui_monkey_seed_1481() -> void:
	await _run_monkey_seed(SEEDS[1])


func test_ui_monkey_seed_1482() -> void:
	await _run_monkey_seed(SEEDS[2])


## M2: the same monkey on a New game (the country pick first, then Play as and the country game).
func test_ui_monkey_m2_seed_1480() -> void:
	await _run_monkey_seed(SEEDS[0], true)


func test_ui_monkey_m2_seed_1481() -> void:
	await _run_monkey_seed(SEEDS[1], true)


func test_ui_monkey_m2_seed_1482() -> void:
	await _run_monkey_seed(SEEDS[2], true)


## M3: the same monkey on a country game with the report, the log, Save and Load, bookmarks and the quick keys.
func test_ui_monkey_m3_seed_1483() -> void:
	await _run_monkey_seed(M3_SEEDS[0], true, true)


func test_ui_monkey_m3_seed_1484() -> void:
	await _run_monkey_seed(M3_SEEDS[1], true, true)


func test_ui_monkey_m3_seed_1485() -> void:
	await _run_monkey_seed(M3_SEEDS[2], true, true)


## M4: the same monkey with the economy's keys, chips, rows and works card (every M3 action stays).
func test_ui_monkey_m4_seed_1486() -> void:
	await _run_monkey_seed(M4_SEEDS[0], true, true, true)


func test_ui_monkey_m4_seed_1487() -> void:
	await _run_monkey_seed(M4_SEEDS[1], true, true, true)


func test_ui_monkey_m4_seed_1488() -> void:
	await _run_monkey_seed(M4_SEEDS[2], true, true, true)


## M4.5: the M4 monkey with the study's pages, tabs, tables, timeline, log headers, charts, Show on the map and Yields.
func test_ui_monkey_m45_seed_1489() -> void:
	await _run_monkey_seed(M45_SEEDS[0], true, true, true, true)


func test_ui_monkey_m45_seed_1490() -> void:
	await _run_monkey_seed(M45_SEEDS[1], true, true, true, true)


func test_ui_monkey_m45_seed_1491() -> void:
	await _run_monkey_seed(M45_SEEDS[2], true, true, true, true)


## M5: the M4.5 monkey with key 5, the People and Food chips, the People page and the console's `people`.
func test_ui_monkey_m5_seed_1492() -> void:
	await _run_monkey_seed(M5_SEEDS[0], true, true, true, true, true)


func test_ui_monkey_m5_seed_1493() -> void:
	await _run_monkey_seed(M5_SEEDS[1], true, true, true, true, true)


func test_ui_monkey_m5_seed_1494() -> void:
	await _run_monkey_seed(M5_SEEDS[2], true, true, true, true, true)


## M6: the M5 monkey with the armies, key 6, the army panel, the Raise tab, the hex menu, the Military page and the replay.
func test_ui_monkey_m6_seed_1495() -> void:
	await _run_monkey_seed(M6_SEEDS[0], true, true, true, true, true, true)


func test_ui_monkey_m6_seed_1496() -> void:
	await _run_monkey_seed(M6_SEEDS[1], true, true, true, true, true, true)


func test_ui_monkey_m6_seed_1497() -> void:
	await _run_monkey_seed(M6_SEEDS[2], true, true, true, true, true, true)


## M7: the M6 monkey with the war as Savoy: Storm, B, the badges, the dock, the hex menu's war items, the console's war lines,
## a declaration and a peace through the country panel, the Castle areas switch and the standing orders.
func test_ui_monkey_m7_seed_1498() -> void:
	await _run_monkey_seed(M7_SEEDS[0], true, true, true, true, true, true, true)


func test_ui_monkey_m7_seed_1499() -> void:
	await _run_monkey_seed(M7_SEEDS[1], true, true, true, true, true, true, true)


func test_ui_monkey_m7_seed_1500() -> void:
	await _run_monkey_seed(M7_SEEDS[2], true, true, true, true, true, true, true)


## A real bug the M4 monkey found, kept as a minimal failing test (it fails until the card is fixed): with Confirm works on Always
## a mouse click on a hex panel row opens the card, the card takes the focus for Begin, the row's focus_exited reads as the
## pointer leaving, and the card closes at once (WorksPreview.leave); then WorksFlow.show_card draws the ghost and the marks for
## a card that is gone, and they stay on the map.
func test_a_mouse_click_on_a_row_keeps_its_card_and_leaves_no_marks_without_it() -> void:
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
	app.cli_args_override = PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"])
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("game/autosave", "off")
	s.set_value("game/confirm_works", "always")
	app.set_settings_override(s)
	vp.add_child(app)
	await _m3_wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting(), 900)
	await _wait_frames(3)
	app.map_scene().select_hex(Vector2i(10, 13))  # wild woods by the sea east of Genoa
	await _wait_frames(3)
	var row := AppFlowHelpers.row_button(app, "Build olive")
	assert_not_null(row, "the woods offer an olive grove")
	if row != null:
		_send_click(vp, row.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		await _wait_frames(3)
		assert_true(app.stack().top() is WorksPreview, "the card stays up after the click")
		assert_eq(app.map_scene().preview_marks().shown(), app.stack().has_screen(&"works_preview"),
			"the ghost and marks are on the map exactly while the card is up")
	Session.end_game()
	await _wait_frames(2)


## A hex an action changed. Those the season's own phases change (a work finishing, a village growing: any country's land)
## are not recorded: while a season runs, the log's last record is its end_season of the game's current turn (Season.begin
## writes it, the calendar phase moves the turn on).
func _on_hex_changed(hex: Vector2i) -> void:
	var game := Session.game
	if game != null and not game.action_log.is_empty():
		var last: Dictionary = game.action_log.back()
		# The season's own record is the log's last for the season's phases; since M8 the ai_orders phase follows it with its mark
		# (LogOrders.MARK), so that is the last record for the rest of the season.
		var done := str(last.get("action", ""))
		if (done == "end_season" or done == LogOrders.MARK) and int(last.get("turn", -1)) == game.turn:
			return
		# An action done for another country (the console's `as TAG`) is not a works action of the player's.
		var who := str((last.get("args", {}) as Dictionary).get("tag", ""))
		if who != "" and StringName(who) != game.player:
			return
	_changed_hexes.append(hex)


func _run_monkey_seed(seed_value: int, new_game: bool = false, m3: bool = false, m4: bool = false, m45: bool = false, m5: bool = false, m6: bool = false, m7: bool = false) -> void:
	await _wait_frames(2)
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_player_seen = &""
	_player_game = null
	_set_milestones(m4, m45, m5, m6, m7)
	Events.hex_changed.connect(_on_hex_changed)

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child(vp)

	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.skip_loading_frames = true
	if new_game:
		app.cli_args_override = PackedStringArray(["--new-game", "--seed=%d" % seed_value])
	else:
		app.cli_args_override = PackedStringArray(["--sandbox", "--seed=%d" % seed_value])
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("display/background_fps", 0)  # the headless window counts as unfocused: its 10 fps cap would make a seed take an hour
	if m3:
		s.set_value("game/season_report", "full")
		s.set_value("graphics/season_change", "instant")
	if m6 or m7:
		# The replay is on: the M6 monkey skips it, watches it and refuses orders in it. (Settings.new(.., true) makes reduce
		# motion the default, and reduce motion plays every walk instant.)
		s.set_value("game/movement", "normal")
		s.set_value("accessibility/reduce_motion", false)
	app.set_settings_override(s)
	vp.add_child(app)
	await _wait_frames(2)

	var waited := 0
	while app.is_starting() and waited < 240:
		await _wait_frames(1)
		waited += 1
	if m3:
		_m3_begin(app)

	var rng := Rng.new()
	rng.seed_with(seed_value)
	var land_hexes := _collect_land_hexes()

	var events := int(OS.get_environment("HEXA_MONKEY_EVENTS")) if OS.has_environment("HEXA_MONKEY_EVENTS") else EVENTS_PER_SEED  # a shorter run to look at
	for step: int in range(events):
		_step_no = step
		_dev_changed = false
		if m3:
			await _m3_before_step(rng, app, step)
		var prev_game := Session.game
		var prev_digest := prev_game.digest() if (prev_game != null and prev_game.map != null and prev_game.state != null) else ""
		var prev_unsaved := Session.unsaved_actions
		var prev_player := Session.player_tag()
		_changed_hexes.clear()
		_tag = "seed %d step %d" % [seed_value, step]
		_step_turn = prev_game.turn if prev_game != null else -1
		_step_seasons = int(_n.get("seasons", 0))
		_step_slot = Session.current_slot

		if m3 and rng.randi_range(0, 99) < (70 if m4 else 45):
			await _m3_step(rng, vp, app)
		else:
			_perform_monkey_step(rng, vp, app, land_hexes, step)
		await _wait_frames(1)

		_assert_invariants(vp, app, prev_game, prev_digest, prev_unsaved, prev_player, seed_value, step)
		if m3:
			_m3_assert_invariants(app, "seed %d step %d" % [seed_value, step])
		if m4:
			_m4_assert_invariants(app, "seed %d step %d" % [seed_value, step])
		if m5:
			_m5_assert_invariants(app, "seed %d step %d" % [seed_value, step])
		if m6:
			_m6_assert_invariants(app, "seed %d step %d" % [seed_value, step])
		if m7:
			_m7_assert_invariants(app, "seed %d step %d" % [seed_value, step])

	if m3:
		_m3_end(seed_value)
	_set_milestones(false, false, false, false, false)
	Events.hex_changed.disconnect(_on_hex_changed)
	Session.end_game()
	remove_child(vp)
	vp.queue_free()
	await _wait_frames(4)

	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_eq(orphans_after, orphans_before, "seed %d teardown must leave zero orphan nodes" % seed_value)


## Which milestones' actions the seed plays (each includes the ones before it).
func _set_milestones(m4: bool, m45: bool, m5: bool, m6: bool, m7: bool) -> void:
	_m4 = m4
	_m45 = m45
	_m5 = m5
	_m6 = m6
	_m7 = m7


func _perform_monkey_step(
	rng: Rng,
	vp: SubViewport,
	app: App,
	land_hexes: Array[Vector2i],
	step: int
) -> void:
	var roll := rng.randi_range(0, 99)
	if roll < 28:
		_send_random_key(rng, vp)
	elif roll < 48:
		_click_visible_control(rng, vp, app)
	elif roll < 64:
		_send_random_viewport_click(rng, vp)
	elif roll < 76:
		_send_random_wheel(rng, vp)
	elif roll < 86:
		_send_random_gesture(rng, vp)
	elif roll < 93:
		_send_random_drag(rng, vp)
	else:
		_exercise_screen_or_hud_flow(rng, app, land_hexes, step)


func _send_random_key(rng: Rng, vp: SubViewport) -> void:
	var key := SAFE_KEYS[rng.randi_range(0, SAFE_KEYS.size() - 1)]
	# Ctrl+F (place search) is F with Ctrl; plain F is Fit whole map.
	var ctrl := key == KEY_F and rng.randi_range(0, 2) == 0
	var press := InputEventKey.new()
	press.keycode = key
	press.physical_keycode = key
	press.pressed = true
	press.ctrl_pressed = ctrl
	vp.push_input(press)

	var release := InputEventKey.new()
	release.keycode = key
	release.physical_keycode = key
	release.pressed = false
	release.ctrl_pressed = ctrl
	vp.push_input(release)


func _click_visible_control(rng: Rng, vp: SubViewport, app: App) -> void:
	var stack := app.stack()
	var root_ctrl: Node = stack.top() if stack.count() > 0 else app.hud().root()
	# With a screen up (the pick), the HUD's dock still gets clicks: Play as, the country panel.
	if stack.count() > 0 and app.hud() != null and rng.randi_range(0, 2) == 0:
		root_ctrl = app.hud().root()
	if root_ctrl == null:
		return
	var buttons := _collect_clickable_buttons(root_ctrl)
	if buttons.is_empty():
		return
	var btn := buttons[rng.randi_range(0, buttons.size() - 1)]
	var rect := btn.get_global_rect()
	if rect.has_area() and Rect2(Vector2.ZERO, Vector2(vp.size)).intersects(rect):
		_send_click(vp, rect.get_center(), MOUSE_BUTTON_LEFT)
	else:
		btn.pressed.emit()


func _send_random_viewport_click(rng: Rng, vp: SubViewport) -> void:
	var pos := Vector2(
		float(rng.randi_range(12, vp.size.x - 12)),
		float(rng.randi_range(8, vp.size.y - 12))
	)
	var button := MOUSE_BUTTON_LEFT if rng.randi_range(0, 3) != 0 else MOUSE_BUTTON_RIGHT
	_send_click(vp, pos, button)


func _send_random_wheel(rng: Rng, vp: SubViewport) -> void:
	var pos := Vector2(
		float(rng.randi_range(60, vp.size.x - 60)),
		float(rng.randi_range(60, vp.size.y - 60))
	)
	var wheel_buttons: Array[MouseButton] = [
		MOUSE_BUTTON_WHEEL_UP,
		MOUSE_BUTTON_WHEEL_DOWN,
		MOUSE_BUTTON_WHEEL_LEFT,
		MOUSE_BUTTON_WHEEL_RIGHT,
	]
	var factors: Array[float] = [0.5, 1.0, 2.0]
	var ev := InputEventMouseButton.new()
	ev.button_index = wheel_buttons[rng.randi_range(0, wheel_buttons.size() - 1)]
	ev.factor = factors[rng.randi_range(0, factors.size() - 1)]
	ev.position = pos
	ev.global_position = pos
	ev.pressed = true
	ev.ctrl_pressed = rng.randi_range(0, 5) == 0
	ev.shift_pressed = rng.randi_range(0, 5) == 0
	vp.push_input(ev)
	# A wheel tick is a press and a release (as the window sends it): left pressed, it would hold the viewport's mouse grab and
	# every later click would go to the control under the wheel.
	var release := ev.duplicate() as InputEventMouseButton
	release.pressed = false
	vp.push_input(release)


func _send_random_gesture(rng: Rng, vp: SubViewport) -> void:
	var pos := Vector2(
		float(rng.randi_range(100, vp.size.x - 100)),
		float(rng.randi_range(80, vp.size.y - 80))
	)
	if rng.randi_range(0, 1) == 0:
		var pan := InputEventPanGesture.new()
		pan.position = pos
		pan.delta = Vector2(float(rng.randi_range(-8, 8)), float(rng.randi_range(-8, 8)))
		vp.push_input(pan)
	else:
		var mag := InputEventMagnifyGesture.new()
		mag.position = pos
		mag.factor = 0.85 if rng.randi_range(0, 1) == 0 else 1.15
		vp.push_input(mag)


func _send_random_drag(rng: Rng, vp: SubViewport) -> void:
	var start := Vector2(
		float(rng.randi_range(120, vp.size.x - 120)),
		float(rng.randi_range(100, vp.size.y - 100))
	)
	var delta := Vector2(float(rng.randi_range(-90, 90)), float(rng.randi_range(-70, 70)))
	var mid := start + delta * 0.5
	var end := start + delta

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start
	press.global_position = start
	press.pressed = true
	vp.push_input(press)

	for pt: Vector2 in [mid, end]:
		var motion := InputEventMouseMotion.new()
		motion.position = pt
		motion.global_position = pt
		motion.relative = pt - start
		vp.push_input(motion)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = end
	release.global_position = end
	release.pressed = false
	vp.push_input(release)


func _exercise_screen_or_hud_flow(
	rng: Rng,
	app: App,
	land_hexes: Array[Vector2i],
	step: int
) -> void:
	var top := app.stack().top()
	if top != null:
		if top.screen_id == &"country_pick":
			# The pick: a row opens its country; Play as (or Enter on it) chooses it.
			var pick := top as CountryPick
			var tags := pick.row_tags()
			if not tags.is_empty():
				var tag := _m7_choose(tags, rng.randi_range(0, tags.size() - 1))
				if rng.randi_range(0, 2) == 0:
					pick.play(tag)
				else:
					var row := pick.row_button(tag)
					if row != null:
						row.pressed.emit()
			return
		if top.screen_id == &"options":
			var opt := top as Options
			var page_idx := rng.randi_range(0, Options.PAGES.size() - 1)
			opt.select_page(Options.PAGES[page_idx]["id"] as StringName)
			return
		if top.screen_id == &"main_menu":
			var menu := top as MainMenu
			var pick := rng.randi_range(0, 2)
			if pick == 0 and menu.sandbox_button().visible:
				menu.sandbox_button().pressed.emit()
			elif pick == 1:
				menu.options_button().pressed.emit()
			else:
				menu.credits_button().pressed.emit()
			return
		if top.screen_id == &"sandbox":
			var sb := top as Sandbox
			sb.roll_random_seed()
			sb.start_button().pressed.emit()
			return
		app.stack().back()
		return

	var choice := rng.randi_range(0, 4)
	if choice == 0:
		var screen_pool: Array[StringName] = [&"pause_menu", &"options", &"help", &"about", &"credits"]
		var sid := screen_pool[rng.randi_range(0, screen_pool.size() - 1)]
		app.context().request(&"open_screen", {"id": sid})
	elif choice == 1 and app.map_scene() != null and not land_hexes.is_empty():
		var hex := land_hexes[rng.randi_range(0, land_hexes.size() - 1)]
		app.map_scene().select_hex(hex)
	elif choice == 2:
		app.hud().set_layers_open(not app.hud().is_layers_open())
	elif choice == 3 and app.map_scene() != null:
		var season_idx := (step + rng.randi_range(0, 3)) % TilesetBuilder.SEASONS.size()
		app.map_scene().set_season(TilesetBuilder.SEASONS[season_idx])
	elif app.map_scene() != null:
		app.map_scene().fit()


func _assert_invariants(
	vp: SubViewport,
	app: App,
	prev_game: Game,
	prev_digest: String,
	prev_unsaved: int,
	prev_player: StringName,
	seed_value: int,
	step: int
) -> void:
	var stack := app.stack()
	var tag := "seed %d step %d" % [seed_value, step]

	# 1. ScreenStack + ModalShade consistency
	var shade_count := 0
	var shade_node: ColorRect = null
	var top_modal_idx := -1
	for idx: int in stack.get_child_count():
		var child := stack.get_child(idx)
		if child.name == &"ModalShade" and child is ColorRect:
			shade_count += 1
			shade_node = child as ColorRect
		elif child is Screen and (child as Screen).kind == Screen.Kind.MODAL:
			top_modal_idx = idx
	assert_eq(shade_count, 1, "%s: ScreenStack must maintain exactly one ModalShade node" % tag)
	if shade_node != null:
		if top_modal_idx >= 0:
			assert_true(shade_node.visible, "%s: ModalShade visible when modal is open" % tag)
			assert_lt(shade_node.get_index(), top_modal_idx, "%s: ModalShade sits beneath top modal" % tag)
		else:
			assert_false(shade_node.visible, "%s: ModalShade hidden when no modal is open" % tag)

	# 2. Pause & World/HUD visibility match stack state
	assert_eq(app.wants_pause(), stack.wants_pause(), "%s: App.wants_pause matches stack" % tag)
	assert_eq(app.hides_world(), stack.hides_world(), "%s: App.hides_world matches stack" % tag)
	assert_eq(app.world_host().visible, not stack.hides_world(), "%s: World visibility matches !hides_world" % tag)
	assert_eq(app.hud().visible, not stack.hides_world(), "%s: Hud visibility matches !hides_world" % tag)

	var top := stack.top()
	if top != null and top.kind == Screen.Kind.MODAL:
		var focus_owner := vp.gui_get_focus_owner()
		var has_live_focus := focus_owner != null and is_instance_valid(focus_owner) and top.is_ancestor_of(focus_owner)
		var has_default_target := not top.default_focus.is_empty() and top.get_node_or_null(top.default_focus) != null
		assert_true(has_live_focus or has_default_target, "%s: top modal (%s) must have valid focus target" % [tag, String(top.screen_id)])

	# 3. Camera zoom & bounds invariants when MapScene is active
	var map_scene := app.map_scene()
	if map_scene != null and is_instance_valid(map_scene):
		assert_eq(map_scene.map_input().enabled, not stack.wants_pause(), "%s: MapInput enabled iff not paused" % tag)
		assert_eq(map_scene.camera_rig().enabled, not stack.wants_pause(), "%s: CameraRig enabled iff not paused" % tag)
		if not stack.hides_world():
			var rig := map_scene.camera_rig()
			var z := rig.zoom()
			assert_gte(z, rig.min_zoom() - 0.001, "%s: zoom >= min_zoom" % tag)
			assert_lte(z, ZoomModel.ZOOM_MAX + 0.001, "%s: zoom <= ZOOM_MAX" % tag)
			var cam_pos := map_scene.camera().position
			var ms := map_scene.map_size()
			if ms.x > 0.0 and ms.y > 0.0:
				assert_gte(cam_pos.x, -0.5, "%s: camera x >= 0" % tag)
				assert_lte(cam_pos.x, ms.x + 0.5, "%s: camera x <= map_size.x" % tag)
				assert_gte(cam_pos.y, -0.5, "%s: camera y >= 0" % tag)
				assert_lte(cam_pos.y, ms.y + 0.5, "%s: camera y <= map_size.y" % tag)

	# 4. Digest invariant: same Game digest only changes on a successful action
	if Session.game != null and Session.game == prev_game and not prev_digest.is_empty():
		var cur_digest := Session.game.digest()
		if cur_digest != prev_digest:
			# The pick is an accepted action too; choosing a country resets unsaved_actions to 0 (AppRoutes).
			var picked := prev_player == &"" and Session.player_tag() != &""
			# A season (Enter) is an accepted action too; an autosave after it then leaves nothing unsaved.
			var autosaved := Session.unsaved_actions == 0 and Session.current_slot.begins_with("auto")
			# Seasons that ended during this step are accepted actions that finished by themselves (a run of several, or the
			# frames of a slow machine): an autosave between two of them leaves unsaved at 1, not 0 (found under load: turn 12 -> 14,
			# unsaved 4 -> 1, slot auto1). The season_ended events counted by the monkey say so; nothing else explains a change.
			var seasons_ended := int(_n.get("seasons", 0)) > _step_seasons
			if not picked and not autosaved and not seasons_ended and not _dev_changed:
				if Session.unsaved_actions <= prev_unsaved:
					gut.p("DIGEST DIAGNOSTIC %s: turn %d -> %d, seasons ended this step %d, unsaved %d -> %d, slot '%s' -> '%s', digest %s -> %s" % [
						tag, _step_turn, Session.game.turn, int(_n.get("seasons", 0)) - _step_seasons, prev_unsaved, Session.unsaved_actions,
						_step_slot, Session.current_slot, prev_digest.substr(0, 12), cur_digest.substr(0, 12)])
				assert_gt(Session.unsaved_actions, prev_unsaved, "%s: game digest changed without an accepted action" % tag)

	# 5. M2: the player is fixed by the pick; an accepted works action (build, upgrade, clear) is on the player's land
	var game := Session.game
	if game != null and game.has_countries():
		if game.player != &"":
			if _player_game != game:
				_player_game = game
				_player_seen = game.player
			assert_eq(game.player, _player_seen, "%s: the player never changes after the pick" % tag)
		# _changed_hexes holds the changes of works actions only (a season's phases are left out in _on_hex_changed: a village
		# of another country grows in the people phase), so an action accepted on foreign land is caught even in a step that
		# also ended a season.
		for hex: Vector2i in _changed_hexes:
			assert_eq(Territory.owner_tag(game, hex), game.player,
				"%s: an accepted works action on %s is on the player's land" % [tag, str(hex)])


func _collect_land_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if Session.game == null or Session.game.map == null:
		return out
	var m := Session.game.map
	for i: int in range(0, m.hex_count(), 17):
		if m.land[i] == 1:
			out.append(m.hex_of(i))
	return out


# ----- M3: the season, report, log, Save and Load, bookmarks and quick keys -------------------------------------------------
# Invariants (m3-build-spec.md section 9): at most one season per guard window; the world is paused exactly while the
# report is up; the digest is unchanged by opening the report, the log or Save and Load; save then load keeps the digest;
# every action is counted and a seed that does no picks, seasons or saves fails.


func _m3_begin(app: App) -> void:
	_m3_app = app
	_n.clear()
	for key: String in COUNTER_KEYS:
		_n[key] = 0
	_last_season_msec = -1
	Events.season_ended.connect(_on_season_counted)
	Events.work_started.connect(_on_work_started_counted)
	Events.work_cancelled.connect(_on_work_cancelled_counted)
	Events.country_chosen.connect(_on_country_counted)
	Events.game_started.connect(_on_game_counted)
	app.context().saved.connect(_on_saved_counted)


func _m3_end(seed_value: int) -> void:
	Events.season_ended.disconnect(_on_season_counted)
	Events.work_started.disconnect(_on_work_started_counted)
	Events.work_cancelled.disconnect(_on_work_cancelled_counted)
	Events.country_chosen.disconnect(_on_country_counted)
	Events.game_started.disconnect(_on_game_counted)
	if _m3_app != null and is_instance_valid(_m3_app) and _m3_app.context().saved.is_connected(_on_saved_counted):
		_m3_app.context().saved.disconnect(_on_saved_counted)
	_n["loads"] = maxi(int(_n["games"]) - 1 - int(_n["new_games"]), 0)
	_m3_app = null
	gut.p("monkey m3 seed %d counters: %s" % [seed_value, JSON.stringify(_n)])
	assert_gt(int(_n["picks"]), 0, "seed %d: the monkey picked a country" % seed_value)
	assert_gt(int(_n["seasons"]), 0, "seed %d: the monkey played a season" % seed_value)
	assert_gt(int(_n["saves"]), 0, "seed %d: the monkey saved" % seed_value)
	assert_gt(int(_n["roundtrips"]), 0, "seed %d: a save then load kept the digest at least once" % seed_value)
	if _m4:
		for key: String in M4_REQUIRED:
			assert_gt(int(_n[key]), 0, "seed %d: the monkey did %s" % [seed_value, key])
	if _m45:
		for key: String in M45_REQUIRED:
			assert_gt(int(_n[key]), 0, "seed %d: the monkey did %s" % [seed_value, key])
	if _m5:
		for key: String in M5_REQUIRED:
			assert_gt(int(_n[key]), 0, "seed %d: the monkey did %s" % [seed_value, key])
	if _m6:
		for key: String in M6_REQUIRED:
			assert_gt(int(_n[key]), 0, "seed %d: the monkey did %s" % [seed_value, key])
	if _m7:
		for key: String in M7_REQUIRED:
			assert_gt(int(_n[key]), 0, "seed %d: the monkey did %s" % [seed_value, key])


func _on_season_counted(_turn: int) -> void:
	_n["seasons"] = int(_n["seasons"]) + 1
	var now := Time.get_ticks_msec()
	if _last_season_msec >= 0:
		assert_gte(now - _last_season_msec, SeasonFlow.GUARD_MS,
			"at most one season per %d ms guard window" % SeasonFlow.GUARD_MS)
	_last_season_msec = now
	if _m3_app != null and is_instance_valid(_m3_app):
		assert_false(_m3_app.stack().has_screen(&"season_report"), "no season runs while the report is up")


func _on_work_started_counted(_tag: StringName, _hex: Vector2i, _work: Dictionary) -> void:
	_n["works_begun"] = int(_n["works_begun"]) + 1


func _on_work_cancelled_counted(_tag: StringName, _hex: Vector2i, _work: Dictionary, _why: StringName) -> void:
	_n["works_cancelled"] = int(_n["works_cancelled"]) + 1


func _on_country_counted(_tag: StringName) -> void:
	_n["picks"] = int(_n["picks"]) + 1


func _on_game_counted() -> void:
	_n["games"] = int(_n["games"]) + 1
	_last_season_msec = -1  # a new or loaded game resets the flow and its guard


func _on_saved_counted(_slot: String, problem: String) -> void:
	if problem.is_empty():
		_n["saves"] = int(_n["saves"]) + 1


## Before every step: waits out a load, starts a game when none is left, chooses a country at the pick, and forces the
## actions a seed must do (a season, a save then load) when its counters are still 0 late enough.
func _m3_before_step(rng: Rng, app: App, step: int) -> void:
	var vp := app.get_viewport() as SubViewport
	await _m3_wait_until(func() -> bool: return not app.is_starting(), 900)
	if Session.game == null:
		var top := app.stack().top()
		if top != null and top.screen_id == &"main_menu" and (top as MainMenu).continue_button().visible and rng.randi_range(0, 1) == 0:
			(top as MainMenu).continue_button().pressed.emit()
		else:
			_bump("new_games")
			app.context().request(&"new_game", {"scenario": "north_italy_1480", "seed": 1480 + step})
		await _wait_frames(3)
		await _m3_wait_until(func() -> bool: return not app.is_starting(), 900)
	var pick := app.stack().top() as CountryPick
	if pick != null and Session.player_tag() == &"":
		var tags := pick.row_tags()
		if not tags.is_empty() and (step >= 2 or rng.randi_range(0, 3) == 0):
			pick.play(_m7_choose(tags, rng.randi_range(0, tags.size() - 1)))
			await _wait_frames(2)
		return
	if vp == null:
		return
	if step >= FORCE_SEASON_STEP and int(_n["seasons"]) == 0:
		await _m3_clear_screens(app)
		await _m3_season_and_close(vp, app)
	if step >= FORCE_SAVE_STEP and int(_n["roundtrips"]) == 0:
		await _m3_clear_screens(app)
		await _m3_save_then_load(vp, app)
	if _m4 and step >= FORCE_M4_STEP:
		await _m4_force(rng, vp, app)
	if _m45 and step >= FORCE_M45_STEP and not _m4_coverage_due():
		await _m45_force(rng, vp, app)
	if _m5 and step >= FORCE_M5_STEP and not _m4_coverage_due():
		await _m5_force(rng, vp, app)
	if _m6 and step >= FORCE_M6_STEP and not _m4_coverage_due():
		await _m6_force(rng, vp, app)
	if _m7 and step >= FORCE_M7_STEP and not _m4_coverage_due():
		await _m7_force(rng, vp, app)


func _m3_clear_screens(app: App) -> void:
	var guard := 0
	while app.stack().count() > 0 and guard < 8:
		if not app.stack().back():
			app.stack().pop()
		guard += 1
		await _wait_frames(1)


func _m3_wait_until(done: Callable, limit: int) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await _wait_frames(1)
		frames += 1
	return bool(done.call())


func _m3_wait_guard(app: App) -> void:
	await _m3_wait_until(func() -> bool: return Time.get_ticks_msec() >= app.requests().flow.guard_until, 600)


func _m3_report_up(app: App) -> bool:
	return app.stack().top() is SeasonReport


## One season by the keys: Space, the report, Space closes it.
func _m3_season_and_close(vp: SubViewport, app: App) -> void:
	if not _m3_calm(app):
		return
	await _m3_wait_guard(app)
	_bump("spaces")
	_send_chord(vp, KEY_SPACE)
	await _m3_wait_until(func() -> bool: return _m3_report_up(app) or app.requests().flow.state() == SeasonFlow.State.IDLE, 240)
	if _m3_report_up(app):
		_bump("reports")
		_send_chord(vp, KEY_SPACE)
		await _m3_wait_until(func() -> bool: return app.stack().count() == 0, 60)


## Double Space: the season and the report, the second Space closes the report, a third inside the guard plays nothing.
func _m3_double_space(vp: SubViewport, app: App) -> void:
	if not _m3_calm(app):
		return
	await _m3_season_and_close(vp, app)
	if app.stack().count() != 0 or app.requests().flow.state() != SeasonFlow.State.IDLE or Session.game == null:
		return
	var before := int(_n["seasons"])
	_send_chord(vp, KEY_SPACE)
	var inside := Time.get_ticks_msec() < app.requests().flow.guard_until
	await _wait_frames(2)
	_bump("double_spaces")
	if inside:
		_bump("refused_spaces")
		assert_eq(int(_n["seasons"]), before, "a Space inside the guard plays nothing")


## F5, then F9: the saved digest comes back.
func _m3_save_then_load(vp: SubViewport, app: App) -> void:
	if not _m3_calm(app):
		return
	var saves_before := int(_n["saves"])
	var games_before := int(_n["games"])
	_send_chord(vp, KEY_F5)
	await _m3_wait_until(func() -> bool: return int(_n["saves"]) > saves_before, 300)
	if int(_n["saves"]) == saves_before or Session.game == null:
		return
	await _wait_frames(2)
	if Session.unsaved_actions != 0:
		return
	var digest := Session.game.digest()
	_send_chord(vp, KEY_F9)
	await _m3_wait_until(func() -> bool: return int(_n["games"]) > games_before and not app.is_starting(), 900)
	if int(_n["games"]) == games_before:
		return
	await _wait_frames(2)
	assert_not_null(Session.game, "the quickload gives a game")
	if Session.game != null:
		assert_eq(Session.game.digest(), digest, "save then load keeps the digest")
		_bump("roundtrips")


## Opens the report (J), the log or Save and Load; the digest must not move; then closes it again.
func _m3_open_view(rng: Rng, vp: SubViewport, app: App) -> void:
	if not _m3_calm(app):
		return
	var digest := Session.game.digest()
	var version := Session.game.version
	var which := rng.randi_range(0, 3)
	match which:
		0:
			_send_chord(vp, KEY_J)
			_bump("reports")
		1:
			app.hud().action_log().toggle()
			_bump("log_opens")
		_:
			var screen := SaveLoad.make(SaveLoad.TAB_SAVE if which == 2 else SaveLoad.TAB_LOAD)
			if screen != null:
				app.stack().push(screen)
				_bump("save_screens")
	await _wait_frames(2)
	assert_eq(Session.game.digest(), digest, "opening the report, the log or Save and Load leaves the digest")
	assert_eq(Session.game.version, version, "opening a view is not an action")
	_bump("view_checks")
	if which >= 2 and app.stack().top() is SaveLoad:
		await _m3_slot_keys(rng, vp, app)
	if which == 1 and app.hud().action_log().is_open() and rng.randi_range(0, 1) == 0:
		await _m3_click_log_line(rng, vp, app)
	if app.hud().action_log().is_open():
		app.hud().action_log().close()
	await _m3_clear_screens(app)


## In Save and Load: Down, Del (asks to delete a save), Enter (saves, loads or asks); Esc backs out of a question.
func _m3_slot_keys(rng: Rng, vp: SubViewport, app: App) -> void:
	var keys: Array[Key] = [KEY_DOWN, KEY_DELETE, KEY_ENTER, KEY_UP]
	for _i: int in range(rng.randi_range(1, 3)):
		if not (app.stack().top() is SaveLoad):
			break
		_send_chord(vp, keys[rng.randi_range(0, keys.size() - 1)])
		_bump("slot_keys")
		await _wait_frames(2)
		if app.stack().top() is Confirm and rng.randi_range(0, 2) != 0:
			_send_chord(vp, KEY_ESCAPE)
			await _wait_frames(1)


## Clicks a line of the open log (it asks the App to look at the hex).
func _m3_click_log_line(rng: Rng, vp: SubViewport, app: App) -> void:
	var lines: Array[Label] = []
	_collect_log_lines(app.hud().action_log(), lines)
	if lines.is_empty():
		return
	var label := lines[rng.randi_range(0, lines.size() - 1)]
	var rect := label.get_global_rect()
	if rect.has_area() and Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(rect.get_center()):
		_send_click(vp, rect.get_center(), MOUSE_BUTTON_LEFT)
		_bump("log_lines")
		await _wait_frames(2)


func _collect_log_lines(node: Node, out: Array[Label]) -> void:
	for child: Node in node.get_children():
		var label := child as Label
		if label != null and label.is_visible_in_tree() and label.tooltip_text == ActionLog.ACTIVATE_TIP:
			out.append(label)
		_collect_log_lines(child, out)


## Clicks a link or action of the report: it closes and the map looks at the hex.
func _m3_click_report_link(rng: Rng, vp: SubViewport, app: App) -> void:
	var report := app.stack().top() as SeasonReport
	if report == null:
		if not _m3_calm(app):
			return
		_send_chord(vp, KEY_J)
		_bump("reports")
		await _wait_frames(2)
		report = app.stack().top() as SeasonReport
		if report == null:
			return
	var links := report.link_buttons()
	if not links.is_empty():
		var btn := links[rng.randi_range(0, links.size() - 1)]
		var rect := btn.get_global_rect()
		if btn.is_visible_in_tree() and not btn.disabled and rect.has_area() and Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(rect.get_center()):
			_send_click(vp, rect.get_center(), MOUSE_BUTTON_LEFT)
		else:
			btn.pressed.emit()
		_bump("report_links")
		await _wait_frames(2)
	if app.stack().top() is SeasonReport:
		_send_chord(vp, KEY_ESCAPE)
		await _wait_frames(2)


## A work the player can begin now; {} when none.
func _m3_buildable() -> Dictionary:
	var game := Session.game
	if game == null or Session.player_tag() == &"":
		return {}
	for i: int in range(0, game.map.hex_count(), 3):
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 0 or Territory.owner_tag(game, hex) != game.player or not Improve.piece_at(game, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(game, hex):
			if bool(option["ok"]) and bool(Session.check("build", {"hex": hex, "family": int(option["family_id"])})["ok"]):
				return {"hex": hex, "family": int(option["family_id"])}
	return {}


func _m3_step(rng: Rng, vp: SubViewport, app: App) -> void:
	var due := _m4_coverage_due()  # late and an M4 counter still 0: the coverage steps go first
	if _m7 and _step_no >= FORCE_M6_STEP and not due and rng.randi_range(0, 99) < 35:  # after the older milestones' coverage steps
		await _m7_step(rng, vp, app)
		return
	if _m6 and not due and rng.randi_range(0, 99) < 30:
		await _m6_step(rng, vp, app)
		return
	if _m5 and not due and rng.randi_range(0, 99) < 25:
		await _m5_step(rng, vp, app)
		return
	if _m45 and not due and rng.randi_range(0, 99) < 45:
		await _m45_step(rng, vp, app)
		return
	if _m4 and rng.randi_range(0, 99) < 60:
		await _m4_step(rng, vp, app)
		return
	var calm := _m3_calm(app)
	match rng.randi_range(0, 13):
		0, 1:
			await _m3_season_and_close(vp, app)
		2:
			await _m3_double_space(vp, app)
		3:
			_bump("m3_keys")
			_send_chord(vp, KEY_J)
		4:
			_bump("m3_keys")
			_send_chord(vp, KEY_F5)
		5:
			await _m3_save_then_load(vp, app)
		6:
			_bump("m3_keys")
			_send_chord(vp, KEY_F9)
		7:
			var index := rng.randi_range(1, 9)
			var set_it := rng.randi_range(0, 1) == 0
			_bump("bookmarks_set" if set_it else "bookmarks_go")
			_send_chord(vp, (KEY_1 + index - 1) as Key, true, set_it)
		8:
			if calm and not Session.game.state.works.is_empty():
				_bump("undos")
			_send_chord(vp, KEY_Z, true)
		9:
			_bump("console_opens")
			_send_chord(vp, KEY_F2)
			await _wait_frames(1)
			_send_chord(vp, KEY_ESCAPE)
		10, 11:
			await _m3_open_view(rng, vp, app)
		12:
			await _m3_click_report_link(rng, vp, app)
		_:
			if calm:
				var found := _m3_buildable()
				if not found.is_empty():
					Session.act("build", {"hex": found["hex"], "family": found["family"]})


## After every step: the report is up exactly while the flow is in its REPORT state, and the world pauses with it.
func _m3_assert_invariants(app: App, tag: String) -> void:
	var report_up := app.stack().has_screen(&"season_report")
	var reporting := app.requests().flow.state() == SeasonFlow.State.REPORT
	if Session.game != null:
		assert_eq(reporting, report_up, "%s: the flow is in REPORT exactly while the report is up" % tag)
	if report_up:
		assert_true(app.wants_pause(), "%s: the world is paused while the report is up" % tag)
