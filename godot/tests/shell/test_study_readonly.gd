## The read-only proof of the M4.5 study, in the shell (docs/architecture/m4-5-build-spec.md 9 and D1; m4-5-build-plan.md
## done-when 4). On Genoa's game at Spring 1483 (4.11's setup played through the App, calm weather) EVERY page and tab of the
## study is opened and refreshed, every span and filter set, every table sorted and shown in full, every chart and the timeline
## walked and hovered, Older and Newest pressed, the chips' cards built, key 4 (Yields) and its legend on and off, the pointer
## over the map, the hover card made for every land hex, the log's older headers pressed and the warmer run; then Game.digest(),
## version, the Snapshot bytes, the Stats, the sizes of the action log and the chronicle and the Events seen are as before, and
## the game and a fresh fixture game give one digest after eight more seasons.
## The planted fault: tests/fixtures/study_page_bad.tscn is a page whose refresh calls Session.act("set_tax"); the same
## detection (a state taken before and after, and its differences) must see it. The detection is asserted on, not the suite.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const GENOA := Vector2i(8, 13)
const WOODS := Vector2i(10, 13)
const BAD_PAGE := "res://tests/fixtures/study_page_bad.tscn"

var _prev_game: Game = null
var _old_save_dir: String = ""
var _old_lock_path: String = ""
var _inputs: int = 0


func before_each() -> void:
	Session.ai_enabled = false  # M3 to M7 pin a passive world (M8 D47)
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_study_ro_saves"
	RunLock.path = "user://test_study_ro_running.lock"
	_inputs = 0


func after_each() -> void:
	_stop_events()
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


# ----- helpers: the inputs are counted ---------------------------------------------------------------------------------------


func _wait_frames(frames: int = 3) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _wait_until(done: Callable, limit: int = 3000) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


## A key of an action (its first event as the Bindings have it, Ctrl or Cmd included), pressed and released. One input.
func _press(vp: SubViewport, action: StringName) -> void:
	_inputs += 1
	var base := Bindings.events_for(action)[0] as InputEventKey
	for pressed: bool in [true, false]:
		var ev := base.duplicate() as InputEventKey
		ev.pressed = pressed
		vp.push_input(ev)


## A bare key that is not counted: the setup's Space and Enter, Esc to clear the screen.
func _key(vp: SubViewport, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		vp.push_input(ev)


## A click on a button. One input.
func _click(button: BaseButton) -> void:
	_inputs += 1
	button.pressed.emit()


## The tab button of a page's strip, pressed. One input.
func _click_tab(page: StudyPage, tab: StringName) -> void:
	_inputs += 1
	var strip := page.get_node("TabStrip") as Segmented
	strip.button_for(tab).button_pressed = true


func _scenario_app(args: Array = ["--new-game", "--country=GEN", "--seed=1480"]) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(args)
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	return {"vp": vp, "app": app}


## Genoa on seed 1480, no pick, the map ready, calm weather (a save carries the weather only from N5 on).
func _genoa_app() -> Dictionary:
	var env := await _scenario_app()
	var app := env["app"] as App
	app.settings().set_value("game/autosave", "off")
	app.settings().set_value("graphics/season_change", "instant")
	app.settings().set_value("game/season_report", "full")
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()), "the game is up")
	await _wait_frames(3)
	Session.game.defs = EconomyFixture.defs()
	return env


func _guard_over(app: App) -> bool:
	return Time.get_ticks_msec() > app.requests().flow.guard_until


## One season by the keys: Space, the report, Space.
func _play_season(vp: SubViewport, app: App) -> void:
	await _wait_until(func() -> bool: return _guard_over(app), 600)
	_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport), "the report opens")
	_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "the report closes")


## The plan's setup (section 4): timber on (10, 13); seven seasons; U and Enter on Genoa; five seasons: Spring 1483.
func _play_setup(vp: SubViewport, app: App) -> void:
	app.map_scene().select_hex(WOODS)
	await _wait_frames(3)
	var timber := AppFlowHelpers.row_button(app, "Build woodland")
	assert_not_null(timber, "the woods by the sea: a timber row")
	timber.pressed.emit()
	await _wait_frames(3)
	assert_eq(Session.game.state.works.size(), 1, "the timber works began")
	for _n: int in 7:
		await _play_season(vp, app)
	assert_eq(Session.game.date_text(), "Winter 1481", "seven seasons: Winter 1481")
	app.map_scene().select_hex(GENOA)
	await _wait_frames(3)
	_key(vp, KEY_U)
	await _wait_frames(3)
	assert_true(app.stack().top() is WorksPreview, "U opens the card of the walled town's upgrade (it is expensive)")
	_key(vp, KEY_ENTER)
	await _wait_frames(3)
	assert_true(AppFlowHelpers.has_toast(app, "1,000 ducats"), str(AppFlowHelpers.toasts(app)))
	for _n: int in 5:
		await _play_season(vp, app)
	assert_eq(Session.game.date_text(), "Spring 1483")
	assert_eq(app.stack().count(), 0, "the bare map")
	app.map_scene().select_hex(MapScene.NO_HEX)
	await _wait_frames(2)


func _study(app: App) -> Study:
	return app.stack().top() as Study


## The words on a study's page: every label and button, and each table's row names.
func _words(node: Node) -> String:
	var parts := AppFlowHelpers.labels_under(node)
	for table: Node in node.find_children("*", "StudyTable", true, false):
		for id: Variant in (table as StudyTable).sorted_ids():
			parts.append((table as StudyTable).row_name(int(id)))
	return " | ".join(parts)


# ----- what must not change, and the detection ----------------------------------------------------------------------------------


var _events: Dictionary = {}
var _links: Array[Array] = []


## The game's state as the proof reads it: the digest, the version, the bytes of its snapshot, the Stats, the logs' sizes.
func _state(g: Game) -> Dictionary:
	return {
		"digest": g.digest(), "version": g.version, "body": var_to_bytes(Snapshot.of(g, {})), "stats": g.stats.digest(),
		"action_log": g.action_log.size(), "chronicle": g.chronicle.entries.size(), "turn": g.turn,
		"events": _events.duplicate(),
	}


## The names of what differs between two states: empty when the first is the second.
func _differences(before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in before:
		if before[key] != after[key]:
			out.append(key)
	return out


## Counts every signal of the bus (each one is a change of the game): the study reads, so none may fire.
func _count_events() -> void:
	_events.clear()
	for info: Dictionary in Events.get_signal_list():
		var sig_name := str(info["name"])
		var arity := (info["args"] as Array).size()
		var unbound := Callable(self, "_seen").bind(sig_name)
		if arity > 0:
			unbound = unbound.unbind(arity)
		Events.connect(sig_name, unbound)
		_links.append([sig_name, unbound])
		_events[sig_name] = 0


func _stop_events() -> void:
	for link: Array in _links:
		if Events.is_connected(link[0], link[1]):
			Events.disconnect(link[0], link[1])
	_links.clear()


func _seen(sig_name: String) -> void:
	_events[sig_name] = int(_events.get(sig_name, 0)) + 1


## The names of what `act` changed in the game: empty when the game is as it was.
func _changes_by(g: Game, act: Callable) -> Array[String]:
	var before := _state(g)
	act.call()
	return _differences(before, _state(g))


# ----- the walk ------------------------------------------------------------------------------------------------------------------


func _visible(root: Node, class_label: String) -> Array[Control]:
	var out: Array[Control] = []
	for node: Node in root.find_children("*", class_label, true, false):
		var ctrl := node as Control
		if ctrl != null and ctrl.is_visible_in_tree():
			out.append(ctrl)
	return out


func _move(vp: SubViewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)


## Everything a hand can do on the page in view: spans, filters, headings, rows, show more, chart cursors and hovers, the
## timeline, Older and Newest. Counts what it touched in `touched`.
func _poke(vp: SubViewport, page: StudyPage, touched: Dictionary) -> void:
	for seg: Control in _visible(page, "Segmented"):
		if seg.name == &"TaxLevels":
			continue  # the tax levels are the one control of the study that is an action
		for button: Node in seg.find_children("*", "Button", true, false):
			(button as Button).button_pressed = true
			touched["segments"] = int(touched["segments"]) + 1
		await _wait_frames(1)
	for ctrl: Control in _visible(page, "StudyTable"):
		var table := ctrl as StudyTable
		var tree := table.tree()
		for column: int in tree.columns:
			for _twice: int in 2:
				tree.column_title_clicked.emit(column, MOUSE_BUTTON_LEFT)
				touched["sorts"] = int(touched["sorts"]) + 1
		if table.total_count() > table.shown_count():
			table.show_more()
		var ids := table.sorted_ids()
		for k: int in mini(ids.size(), 4):
			table.select_id(int(ids[k]))
			touched["rows"] = int(touched["rows"]) + 1
		tree.grab_focus()
		for key: Key in [KEY_HOME, KEY_END, KEY_UP, KEY_DOWN]:
			_key(vp, key)
		await _wait_frames(1)
	for ctrl: Control in _visible(page, "InkChart"):
		var chart := ctrl as InkChart
		for k: int in range(0, 41, 4):
			chart.set_cursor(k)
		for fx: float in [0.1, 0.5, 0.9]:
			var rect := chart.get_global_rect()
			_move(vp, rect.position + Vector2(rect.size.x * fx, rect.size.y * 0.5))
			touched["hovers"] = int(touched["hovers"]) + 1
			await _wait_frames(1)
		_move(vp, Vector2(3.0, 3.0))
	for ctrl: Control in _visible(page, "TimelineStrip"):
		var strip := ctrl as TimelineStrip
		for turn: int in range(Calendar.FIRST_TURN, Session.game.turn, 3):
			strip.set_cursor(turn)
			strip.season_hovered.emit(turn)
			touched["hovers"] = int(touched["hovers"]) + 1
		_move(vp, strip.get_global_rect().position + Vector2(strip.season_x(Calendar.FIRST_TURN + 4), 20.0))
		await _wait_frames(1)
		_move(vp, Vector2(3.0, 3.0))
	var history := page as PageHistory
	if history != null:
		history.older_button().pressed.emit()
		history.newest_button().pressed.emit()
		touched["older"] = int(touched["older"]) + 1
	page.refresh(Session.game, &"season_ended")
	await _wait_frames(1)


## Every page, every tab, each refreshed and poked.
func _walk_study(vp: SubViewport, app: App, touched: Dictionary) -> void:
	_press(vp, &"game_ledger")
	await _wait_frames(3)
	var study := _study(app)
	assert_not_null(study, "L opens the study")
	if study == null:
		return
	for entry: Dictionary in StudyPages.shown(Bindings.SHELL_MILESTONE):
		study.open_page(StringName(str(entry["id"])))
		await _wait_frames(2)
		var page := study.current_page()
		touched["pages"] = int(touched["pages"]) + 1
		page.refresh(Session.game, &"open")
		if page.shown_tabs().is_empty():
			await _poke(vp, page, touched)
		for tab: Dictionary in page.shown_tabs():
			page.select_tab(StringName(str(tab["id"])))
			touched["tabs"] = int(touched["tabs"]) + 1
			await _wait_frames(2)
			page.refresh(Session.game, &"open")
			await _poke(vp, page, touched)
	_key(vp, KEY_ESCAPE)
	await _wait_frames(2)


## The chips' two hover cards, built as a pointer on a chip builds them; a click on a chip opens the study.
func _walk_chips(app: App, touched: Dictionary) -> void:
	for chip: ResourceChip in [app.hud().chips().ducats_chip(), app.hud().chips().stores_chip()]:
		if not chip.is_visible_in_tree():
			continue
		var card := chip.call("_make_custom_tooltip", chip.call("_get_tooltip", Vector2.ZERO)) as HoverCard
		if card != null:
			app.add_child(card)
			await _wait_frames(2)
			card.queue_free()
			touched["cards"] = int(touched["cards"]) + 1
		chip.pressed.emit()
		await _wait_frames(2)
		_key(app.get_viewport() as SubViewport, KEY_ESCAPE)
		await _wait_frames(2)


## Yields on and off, the pointer over the map, the card of every land hex, the hex panel's rows hovered.
func _walk_map(vp: SubViewport, app: App, touched: Dictionary) -> void:
	_key(vp, KEY_4)
	await _wait_frames(3)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.YIELDS), "key 4 is Yields")
	assert_true(app.hud().mode_legend().visible, "the legend shows in Yields")
	for fx: float in [0.3, 0.5, 0.7]:
		_move(vp, Vector2(1280.0 * fx, 360.0))
		await _wait_frames(2)
	var game := Session.game
	for i: int in game.map.hex_count():
		if game.map.land[i] == 1:
			HexCard.of(game, game.map.hex_of(i))
			touched["cards"] = int(touched["cards"]) + 1
	for hex: Vector2i in [GENOA, WOODS, Vector2i(6, 13), Vector2i(7, 12)]:
		app.map_scene().select_hex(hex)
		await _wait_frames(2)
		for row: Button in app.hud().tile_window().action_buttons():
			AppFlowHelpers.hover_card(app, hex, row)
			await _wait_frames(1)
			AppFlowHelpers.hover_out(row)
			await _wait_frames(1)
	app.map_scene().select_hex(MapScene.NO_HEX)
	_key(vp, KEY_1)
	await _wait_frames(3)
	assert_false(app.hud().mode_legend().visible, "key 1: the legend is gone")
	_key(vp, KEY_4)
	await _wait_frames(2)
	_key(vp, KEY_1)
	await _wait_frames(2)


## The log's headers: each opens History (older seasons) or the report (the newest); the screens are closed again.
func _walk_log(app: App, touched: Dictionary) -> void:
	var action_log := app.hud().action_log()
	action_log.open()
	await _wait_frames(3)
	var count := action_log.header_buttons().size()
	for k: int in count:
		var headers := action_log.header_buttons()
		if k >= headers.size():
			break
		headers[k].pressed.emit()
		await _wait_frames(3)
		touched["headers"] = int(touched["headers"]) + 1
		while app.stack().count() > 0:
			if not app.stack().back():
				app.stack().pop()
			await _wait_frames(1)
		action_log.open()
		await _wait_frames(2)
	action_log.close()
	await _wait_frames(2)


# ----- the proof -------------------------------------------------------------------------------------------------------------------


func test_opening_sorting_hovering_every_page_leaves_the_game_as_it_was() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	await _play_setup(vp, app)
	var game := Session.game
	assert_eq(game.digest(), InsightsFixture.genoa_1483().digest(), "the keys played what the fixture plays")
	_count_events()
	var before := _state(game)
	var touched := {"pages": 0, "tabs": 0, "segments": 0, "sorts": 0, "rows": 0, "hovers": 0, "older": 0, "cards": 0, "headers": 0}
	await _walk_study(vp, app, touched)
	await _walk_chips(app, touched)
	await _walk_map(vp, app, touched)
	await _walk_log(app, touched)
	app.requests().warm.queue_views()
	app.requests().warm.warm_now()
	await _wait_frames(3)
	print("study read-only walk touched: ", touched)
	assert_gte(int(touched["pages"]), 3, "every page was opened")
	assert_gte(int(touched["tabs"]), 4, "every tab of Economy was opened")
	assert_gt(int(touched["sorts"]), 10, "tables were sorted")
	assert_gt(int(touched["hovers"]), 10, "charts and the timeline were hovered")
	assert_gt(int(touched["headers"]), 0, "the log's headers were pressed")
	assert_gt(int(touched["cards"]), 100, "the hover card was made for every land hex")
	var after := _state(Session.game)
	assert_eq(_differences(before, after), [] as Array[String], "the walk left the game as it was")
	assert_eq(after["digest"], before["digest"])
	assert_eq(after["version"], before["version"])
	assert_true(after["body"] == before["body"], "the Snapshot bytes are as they were")
	assert_eq(after["stats"], before["stats"], "the Stats are as they were")
	for sig: String in after["events"]:
		assert_eq(int(after["events"][sig]), 0, "no %s was emitted" % sig)
	# The twin: that game and a fresh one play eight more seasons to one digest (the reading left no trace in the play).
	var twin := InsightsFixture.genoa_1483()
	for _n: int in 8:
		Season.run(game)
		Season.run(twin)
	assert_eq(game.digest(), twin.digest(), "the read game and a fresh game agree after eight more seasons")


# ----- the planted fault ------------------------------------------------------------------------------------------------------------


## The page of tests/fixtures/study_page_bad.tscn changes the tax in its refresh: the detection must name the changes. The
## real Economy page, through the same detection, changes nothing.
func test_planted_a_page_that_writes_is_seen_by_the_detection() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	await _play_setup(vp, app)
	var game := Session.game
	_count_events()
	var real := _study_with(StudyPages.shown(Bindings.SHELL_MILESTONE))
	var quiet := _changes_by(game, func() -> void: real.open_page(&"economy"))
	assert_eq(quiet, [] as Array[String], "the real Economy page changes nothing")
	var bad := _study_with([{id = &"bad", title = "Bad", scene = BAD_PAGE, since = "4.5"}] as Array[Dictionary])
	var changed := _changes_by(game, func() -> void: bad.open_page(&"bad"))
	assert_true(changed.has("digest"), "the detection sees the digest change: %s" % str(changed))
	assert_true(changed.has("version"), "and the version: %s" % str(changed))
	assert_true(changed.has("body"), "and the snapshot bytes")
	assert_true(changed.has("events"), "and the event the act emitted")
	var page := bad.current_page()
	var again := _changes_by(game, func() -> void: page.refresh(game, &"season_ended"))
	assert_true(again.has("digest"), "a refresh of the bad page is caught: %s" % str(again))


func _study_with(entries: Array[Dictionary]) -> Study:
	var study := (load("res://shell/screens/study.tscn") as PackedScene).instantiate() as Study
	study.configure(entries, Bindings.SHELL_MILESTONE)
	add_child_autofree(study)
	return study
