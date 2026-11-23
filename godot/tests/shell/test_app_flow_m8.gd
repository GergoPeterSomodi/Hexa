## The M8 App flow (docs/architecture/m8-build-spec.md 6.1 to 6.6 and 9; K28; done-when 9): New game as Genoa with the AI on ->
## End season: the busy pill counts the computer's seats to 12 / 12, a click on the map toasts the block while panning stays
## free, the season ends. Smaller tests: the pill's slot at the top centre, view_hexes, `ai MLO`, `ai off`, the console's `watch`
## (the pick ends, the top bar says Watching) and the peace alert's reading of the chronicle. The App runs headless in a
## SubViewport on a temporary save folder; the seasons come from the rules.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const SCENARIO := "north_italy_1480"
const GENOA := &"GEN"

var _prev_game: Game = null
var _old_save_dir: String = ""
var _old_lock_path: String = ""


func before_each() -> void:
	Session.ai_enabled = true  # the AI on (M8): this file plays the computer's turns
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_flow_m8_saves"
	RunLock.path = "user://test_flow_m8_running.lock"


func after_each() -> void:
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Session.ai_enabled = true
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


func _wait_frames(frames: int = 3) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _wait_until(done: Callable, limit: int = 3000) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


func _key(vp: SubViewport, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		vp.push_input(ev)


func _click(vp: SubViewport, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.global_position = at
		ev.pressed = pressed
		vp.push_input(ev)


## An App in a SubViewport with the settings the flow tests use (instant season change, the report full, no autosave).
func _app_with(args: Array, movement: String = "instant") -> Dictionary:
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
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/season_report", "full")
	s.set_value("game/movement", movement)
	app.set_settings_override(s)
	vp.add_child(app)
	return {"vp": vp, "app": app}


## Genoa as the player, the AI on, the game up and settled.
func _genoa() -> Dictionary:
	var env := await _app_with(["--new-game", "--country=GEN", "--seed=1480"])
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()), "the game is up")
	await _wait_frames(3)
	return env


## The pill counts the computer's seats to 12 / 12 (Genoa is the player, so twelve seats play). While the countries move a click
## on the map toasts the block and a pan still moves the camera; the season then ends.
func test_the_pill_counts_the_seats_and_the_map_blocks_clicks_while_panning_is_free() -> void:
	var env := await _genoa()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var flow := app.requests().flow
	var totals: Array[int] = []
	var done_counts: Array[int] = []
	var record := func(done: int, total: int) -> void:
		done_counts.append(done)
		totals.append(total)
	flow.progressed.connect(record)
	var ends := [""]
	flow.phases_started.connect(func() -> void: ends[0] = app.hud().busy_pill().text())
	var pill_texts: Array[String] = []
	var camera_before := app.map_scene().camera().position
	await _wait_until(func() -> bool: return Time.get_ticks_msec() > flow.guard_until, 600)
	_key(vp, KEY_SPACE)
	var clicked := false
	var panned := false
	var frames := 0
	while flow.state() != SeasonFlow.State.IDLE and frames < 3000:
		await get_tree().process_frame
		if flow.state() == SeasonFlow.State.RUNNING:
			if app.hud().busy_pill().visible:
				pill_texts.append(app.hud().busy_pill().text())
			if not clicked:
				_click(vp, Vector2(640.0, 360.0))
				clicked = true
			if not panned:
				app.map_scene().camera_rig().pan_by(Vector2(40.0, 0.0))
				panned = true
		frames += 1
	flow.progressed.disconnect(record)
	assert_false(done_counts.is_empty(), "the flow reports progress")
	assert_eq(totals.back(), 12, "the pill counts twelve seats")
	assert_eq(done_counts.back(), 12, "the count reaches 12 / 12")
	assert_true(pill_texts.has("Countries are moving 12 / 12") or pill_texts.any(func(t: String) -> bool: return t.begins_with("Countries are moving")), "the pill shows the count")
	assert_true(AppFlowHelpers.has_toast(app, "Countries are moving"), "a click on the map toasts the block")
	assert_ne(app.map_scene().camera().position, camera_before, "panning works while the countries move")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport, 600), "the report opens")
	assert_eq(ends[0], "The season ends", "the pill says the season ends once the seats are done")
	assert_false(app.hud().busy_pill().visible, "the pill is hidden once the season is over")


## The pill sits in the top centre of the map (M8 6.1): the TopCentre slot, hidden at idle, takes no mouse.
func test_the_pill_is_in_the_top_centre_slot() -> void:
	var env := await _genoa()
	var app := env["app"] as App
	var pill := app.hud().busy_pill()
	assert_eq(pill.get_parent().name, "TopCentre", "the pill is in the TopCentre slot")
	assert_false(pill.visible, "hidden at idle")
	assert_eq(pill.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the pill takes no mouse")
	var area := app.hud().get_node("Root/Column/Main/MapArea") as Control
	assert_almost_eq(pill.get_global_rect().get_center().x, area.get_global_rect().get_center().x, 2.0, "the pill is centred over the map")


## view_hexes holds the camera's centre hex; the replay's focus is that view grown by two (M8 6.3).
func test_view_hexes_holds_the_camera_centre_and_the_focus_grows_it() -> void:
	var env := await _genoa()
	var app := env["app"] as App
	var scene := app.map_scene()
	var view := scene.view_hexes()
	assert_gt(view.size.x, 0, "a view has columns")
	assert_gt(view.size.y, 0, "a view has rows")
	var centre_hex := scene.view().hex_at(scene.camera().position)
	assert_true(view.has_point(centre_hex), "the centre hex is in view")
	assert_eq(app.requests().ai_turn.replay_focus(), view.grow(2), "the replay focus is the view grown by two")


## `ai MLO` prints that seat's trace; `ai off` makes every seat passive, so no computer turn runs (M8 6.5).
func test_console_ai_trace_and_ai_off() -> void:
	var env := await _genoa()
	var app := env["app"] as App
	var trace := DevCommands.run("ai MLO", app.context())
	assert_false(trace.is_empty(), "ai MLO prints a trace")
	assert_false(trace.begins_with("Refused"), "ai MLO is not refused")
	assert_eq(DevCommands.run("ai off", app.context()), "Done: the AI is off.", "ai off is done")
	assert_false(Session.ai_enabled, "the AI is off")
	assert_eq(Session.orders_progress(), Vector2i.ZERO, "no seat plays while the AI is off")
	DevCommands.run("ai on", app.context())
	assert_true(Session.ai_enabled, "the AI is back on")


## `watch` during the pick: the pick's screen goes, the game is watched, and the top bar's arms give way to the sandbox seal with
## "Watching" (M8 6.5, 6.6).
func test_watch_ends_the_pick_and_the_top_bar_says_watching() -> void:
	var env := await _app_with(["--new-game", "--scenario=" + SCENARIO, "--seed=1480"])
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() > 0 and not app.is_starting()), "the pick is up")
	await _wait_frames(3)
	assert_true(app.stack().has_screen(&"country_pick"), "the pick is on the stack before watch")
	var reply := DevCommands.run("watch", app.context())
	assert_false(reply.begins_with("Refused"), "watch is accepted during the pick: " + reply)
	await _wait_frames(3)
	assert_false(app.stack().has_screen(&"country_pick"), "the pick's screen is gone")
	assert_true(Session.game.ai_only, "the game is watched")
	var top := app.hud().top_bar()
	assert_false(top.arms().visible, "the arms give way in a watched game")
	assert_eq(top.country_button().text, "Watching", "the top bar says Watching")


## The peace alert's reading (M8 6.4): with no peace this turn the chronicle gives {} and no alert is queued; a chronicle entry of
## a peace with the player becomes the alert, and a peace the player made is none. (The event's own producer is the rules'
## peace; this file does not write the chronicle by hand.)
func test_the_peace_alert_reads_the_chronicle_without_changing_it() -> void:
	var env := await _genoa()
	var app := env["app"] as App
	var game := Session.game
	var player := Session.player_tag()
	assert_true(WarRequests._latest_peace(game).is_empty(), "no peace this turn: nothing to read")
	var with_player := {"kind": "peace_made", "tag": &"MLO", "target": player, "terms": &"take", "moved": [], "turn": game.turn}
	assert_false(DecisionQueue.peace_decision(with_player, player).is_empty(), "a peace with the player is an alert")
	var own := {"kind": "peace_made", "tag": player, "target": &"MLO", "terms": &"take", "moved": [], "turn": game.turn}
	assert_true(DecisionQueue.peace_decision(own, player).is_empty(), "a peace the player made is no alert")
	assert_true(app.requests().war.enabled(), "the war UI is on at milestone 8")


## A real peace (M8 6.4): the rules' Wars.end_war emits peace_made, drain delivers Events.peace_made, and the App's handler
## shows the alert at once, the flow being idle.
func test_a_real_peace_shows_the_alert_at_once_when_idle() -> void:
	var env := await _genoa()
	var app := env["app"] as App
	var g := Session.game
	var nb := WarFixture.neighbour_of(g, GENOA)
	assert_ne(nb, &"", "Genoa has a neighbour")
	var war := WarFixture.at_war(g, GENOA, nb)
	g.version += 1
	Wars.end_war(g, war, &"white", nb)
	Session.drain()
	assert_eq(app.requests().flow.state(), SeasonFlow.State.IDLE, "the flow is idle")
	assert_true(app.stack().top() is Confirm, "the peace alert is on the stack at once")
	assert_eq(str(app.stack().top().get("_title")), "Peace", "the alert is the peace's")
	assert_eq(app.requests().decisions.count(), 0, "the alert left the queue")
	app.stack().pop().queue_free()  # the alert is the test's own screen: free it, do not orphan it
	await _wait_frames(2)  # queue_free runs at the frame's end
