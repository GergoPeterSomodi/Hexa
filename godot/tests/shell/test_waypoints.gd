## Ordering a path in the shell (docs/architecture/moves-build-spec.md R58 to R62, R68, D32 to D34; MV19; owner 2026-11-27: path
## ordering, no staging): Shift+right click and V order at once, a march when no path is under way, else a point added to the
## path's end or its final point taken off (the only one: a halt); a plain right click and O replace the path; with no army
## Shift+right is a plain right click; Shift+left selects the hex; Ctrl+right click storms; a refusal changes nothing and says
## why; a risky path is asked about with its points named; Shift held previews the extended path on the map and the card.
## North Italy's 1480 game with Savoy chosen (the hexes of test_march_via.gd); the App tests push real events. Every case names
## its planted fault (P).
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const SAV := &"SAV"
const TURIN := Vector2i(5, 9)
const SUSA := Vector2i(4, 9)
const PINEROLO := Vector2i(4, 10)
const SOUTH := Vector2i(5, 10)
## Twenty move points east of Turin: a point that a fresh army cannot reach in one season.
const FAR_EAST := Vector2i(9, 10)
const SUMMER_1480 := 2

var _game: Game = null
var _scene: MapScene = null
var _hover: MapHover = null
var _said: Array[String] = []
var _reasons: Array[String] = []
var _prev_game: Game = null
var _old_save_dir := ""
var _old_lock_path := ""


func before_each() -> void:
	_said = []
	_reasons = []
	_scene = null
	_hover = null
	Session.ai_enabled = false
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_waypoints_saves"
	RunLock.path = "user://test_waypoints_running.lock"


func after_each() -> void:
	Session.end_game()
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


# ----- the scene -----------------------------------------------------------------------------------------------------------


func _savoy() -> Game:
	var d := ArmyFixture.defs()
	var g := Game.new_scenario(EconomyFixture.map(), d, d.scenarios[d.scenarios.size() - 1], EconomyFixture.SEED)
	g.act("choose_country", {"tag": SAV})
	g.turn = SUMMER_1480
	return g


## Starts `g` on a map scene with a hover layer, and keeps what is said and refused.
func _open(g: Game) -> void:
	_game = g
	Session.start_game(g)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_hover = MapHover.new()
	add_child_autofree(_hover)
	_armies().said.connect(func(text: String, _tone: StringName) -> void: _said.append(text))
	_scene.refused.connect(func(reason: String) -> void: _reasons.append(reason))


## A fresh army of Savoy on `hex`, selected.
func _selected(hex: Vector2i = TURIN) -> Army:
	var a := ArmyFixture.army(_game, SAV, hex, 0, 2)
	_game.version += 1
	_armies().sync()
	assert_true(_armies().select_army(a.id))
	return a


## A selected army with the path FAR_EAST, PINEROLO under way (its season's points spent on the first part).
func _on_a_path() -> Army:
	var a := _selected()
	_click(FAR_EAST)
	_click(PINEROLO)
	assert_eq(_path_of(a), [FAR_EAST, PINEROLO] as Array[Vector2i], "the path under way: %s" % str(_reasons))
	return a


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


func _map_input() -> MapInput:
	return _scene.map_input()


func _card() -> MoveCard:
	return _hover.move_card()


## The points of a march order: the ones ahead, then the goal; empty for any other order.
func _path_of(a: Army) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if a.order != Army.ORDER_MARCH:
		return out
	out.assign(MarchVia.hexes_of(_game, a.via))
	out.append(a.goal)
	return out


func _idx(hexes: Array[Vector2i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for h: Vector2i in hexes:
		out.append(_game.map.index_of(h))
	return out


## What a refusal and a preview may never change.
func _state() -> Array:
	var armies: Array = []
	for a: Army in _game.armies:
		armies.append([a.id, a.hex, a.points, a.order, a.goal, Array(a.via)])
	return [_game.digest(), _game.version, Session.unsaved_actions, armies]


func _screen_of(hex: Vector2i) -> Vector2:
	return _scene.view().get_global_transform_with_canvas() * _scene.view().centre_of(hex)


## A click of the scene's MapInput on `hex`: Shift+right unless said otherwise.
func _click(hex: Vector2i, button: MouseButton = MOUSE_BUTTON_RIGHT, shift: bool = true) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.position = _screen_of(hex)
		ev.pressed = pressed
		ev.shift_pressed = shift
		_map_input()._unhandled_input(ev)


## The key of an action, through the scene's MapInput.
func _chord(action: StringName) -> void:
	var ev := Bindings.events_for(action)[0].duplicate() as InputEventKey
	ev.pressed = true
	_map_input()._unhandled_input(ev)


func _shift_event(down: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SHIFT
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = down
	ev.shift_pressed = down
	return ev


## The pointer rests on `hex`, for the map's layer and the card.
func _point_at(hex: Vector2i) -> void:
	_map_input().hover_changed.emit(hex)
	_hover.on_hover_changed(hex, Vector2(300, 300))


func _pins_of(hexes: Array[Vector2i]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for h: Vector2i in hexes:
		out.append(_scene.view().centre_of(h))
	return out


func _sea() -> Vector2i:
	for i: int in _game.map.hex_count():
		if _game.map.land[i] != 1:
			return _game.map.hex_of(i)
	return Army.NO_HEX


func _distinct(preview: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for line: Array in MoveCard.distinct_lines(preview.lines as Array):
		out.append(str(line[0]))
	return out


# ----- R58: the order ------------------------------------------------------------------------------------------------------


func test_shift_right_with_no_path_marches_at_once() -> void:
	_open(_savoy())
	var a := _selected()
	var before := Session.unsaved_actions
	_click(FAR_EAST)
	assert_eq(Session.unsaved_actions, before + 1, "P: a click that only holds the point back")
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i])
	assert_ne(a.hex, TURIN, "the army walks in the click")
	assert_eq(_scene.selected, MapScene.NO_HEX, "the click does not select the hex")
	assert_eq(_armies().selected_army(), a.id)
	assert_false(_said.is_empty(), "the order's toast")
	assert_true(_reasons.is_empty(), str(_reasons))


func test_shift_right_adds_to_the_end_of_the_path_under_way() -> void:
	_open(_savoy())
	var a := _selected()
	_click(FAR_EAST)
	var before := Session.unsaved_actions
	_click(PINEROLO)
	assert_eq(Session.unsaved_actions, before + 1, "one action a click")
	assert_eq([a.goal, a.via], [PINEROLO, _idx([FAR_EAST])], "P: a point that replaces the path")
	_click(SUSA)
	assert_eq(_path_of(a), [FAR_EAST, PINEROLO, SUSA] as Array[Vector2i], "in the order clicked")


func test_shift_right_on_the_final_point_takes_it_off_and_the_only_one_halts() -> void:
	_open(_savoy())
	var a := _on_a_path()
	_click(SUSA)
	_click(SUSA)
	assert_eq(_path_of(a), [FAR_EAST, PINEROLO] as Array[Vector2i], "P: a final point clicked again that is added")
	_click(PINEROLO)
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i], "the point before it is the goal")
	_click(FAR_EAST)
	assert_eq([a.order, a.goal, a.via], [Army.ORDER_NONE, FAR_EAST, PackedInt32Array()], "the only point: the halt rule")
	assert_true(str(_said.back()).contains("holds at"), str(_said.back()))
	_click(FAR_EAST)
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i], "a halted march is no path under way: ordered anew")
	assert_true(_reasons.is_empty(), str(_reasons))


func test_a_point_that_is_not_the_final_one_may_come_again() -> void:
	_open(_savoy())
	var a := _on_a_path()
	_click(FAR_EAST)
	assert_eq(_path_of(a), [FAR_EAST, PINEROLO, FAR_EAST] as Array[Vector2i])


func test_after_the_army_arrives_the_next_click_is_a_plain_march() -> void:
	_open(_savoy())
	var a := _selected()
	_click(SUSA)
	assert_eq(a.hex, SUSA, "arrived in the click")
	assert_false(MarchPath.under_way(a))
	_click(PINEROLO)
	assert_eq([a.hex, a.via], [PINEROLO, PackedInt32Array()], "P: a path that keeps a point already reached")


func test_a_halted_march_is_replaced() -> void:
	_open(_savoy())
	var a := _on_a_path()
	assert_true(_armies().command(a.hex), "halted by a right click on the army")
	assert_eq(a.order, Army.ORDER_NONE)
	_click(SUSA)
	assert_eq([a.hex, a.via], [SUSA, PackedInt32Array()], "P: a halted path that is extended: straight there, with points left")


func test_with_no_army_shift_right_is_a_plain_right_click() -> void:
	_open(_savoy())
	_scene.select_hex(SUSA)
	assert_true(HexMenu.own_hex(_game, SAV, SUSA), "a hex of Savoy")
	_click(SUSA)
	assert_true(_armies().hex_menu().visible, "P: Shift+right with no army that opens no hex menu")
	assert_eq(_scene.selected, MapScene.NO_HEX, "and deselects, as a right click does")
	_armies().hex_menu().hide()
	assert_false(_armies().extend_path(SUSA))
	assert_eq(_reasons.back(), "Select an army first.", "V with no army says so")


func test_shift_left_with_an_army_selected_selects_the_hex() -> void:
	_open(_savoy())
	_selected()
	var before := _state()
	_click(SUSA, MOUSE_BUTTON_LEFT)
	assert_eq(_armies().selected_army(), -1, "the select lets the army go")
	assert_eq(_scene.selected, SUSA)
	assert_eq(_state(), before, "P: Shift+left that orders")
	assert_true(_reasons.is_empty())


# ----- R59, R62: refusals, the full path, V --------------------------------------------------------------------------------


func test_a_refused_extension_says_why_and_changes_nothing() -> void:
	_open(_savoy())
	var a := _on_a_path()
	var before := _state()
	var sea := _sea()
	var preview := MovePreview.via(_game, SAV, a.id, [FAR_EAST, PINEROLO] as Array[Vector2i], sea)
	_click(sea)
	assert_eq(_reasons.back() if not _reasons.is_empty() else "", str(preview.verdict.reason), "the card's reason, fog-safe")
	assert_true(str(_reasons.back()).begins_with("The goal: "), str(_reasons.back()))
	_click(a.hex)
	assert_eq(_reasons.back(), "The goal: " + MarchVia.SAME_AS_ARMY_TEXT)
	assert_false(_armies().extend_path(Vector2i(-4, -4)), "off the map")
	assert_eq(_state(), before, "P: a refused extension that changes the game")


func test_a_refused_first_point_changes_nothing() -> void:
	_open(_savoy())
	_selected()
	var before := _state()
	_click(_sea())
	assert_false(_reasons.is_empty())
	assert_eq(_state(), before)


func test_the_path_is_full_at_the_most_points() -> void:
	_open(_savoy())
	var a := _on_a_path()
	_game.defs.max_stops = 1
	var before := _state()
	var full := MarchVia.TOO_MANY_TEXT % 1
	assert_true(full.begins_with("path is full"))
	_click(SUSA)
	assert_eq(_reasons.back() if not _reasons.is_empty() else "", full, "P: more points than the defs allow")
	assert_eq(_state(), before)
	var wet := MovePreview.via(_game, SAV, a.id, [FAR_EAST, PINEROLO] as Array[Vector2i], _sea())
	assert_eq(str(wet.verdict.reason), full, "the same words wherever the point lies")
	_click(PINEROLO)
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i], "a full path can still be shortened")


func test_v_orders_at_the_hovered_hex_and_at_the_cursor_after_alt_arrows() -> void:
	_open(_savoy())
	var a := _selected()
	_point_at(FAR_EAST)
	_chord(&"map_waypoint_key")
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i], "the hovered hex")
	_point_at(PINEROLO)
	_chord(&"map_waypoint_key")
	assert_eq(_path_of(a), [FAR_EAST, PINEROLO] as Array[Vector2i], "added")
	_chord(&"map_waypoint_key")
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i], "V on the final point takes it off")
	_armies().move_cursor(MapInput.CURSOR_LEFT)
	var cursor := _armies().cursor_hex()
	assert_ne(cursor, PINEROLO)
	_chord(&"map_waypoint_key")
	assert_eq(_path_of(a), [FAR_EAST, cursor] as Array[Vector2i], "P: V that ignores the order cursor (%s)" % str(_reasons))


func test_nothing_is_ordered_while_the_replay_runs_or_the_countries_move() -> void:
	_open(_savoy())
	_selected()
	var before := _state()
	var blocked: Array[Vector2] = []
	_map_input().blocked_click.connect(func(px: Vector2) -> void: blocked.append(px))
	_map_input().orders_blocked = func() -> bool: return true
	_armies().orders_blocked = func() -> bool: return true
	_click(SUSA)
	assert_eq(blocked.size(), 1, "a blocked click, as any order")
	_chord(&"map_waypoint_key")
	assert_eq(_said.back(), MapArmies.REPLAY_BLOCKED)
	_map_input().orders_blocked = Callable()
	_armies().orders_blocked = Callable()
	_map_input().block_orders("Countries are moving")
	_click(SUSA)
	_map_input().hover_changed.emit(SUSA)
	_chord(&"map_waypoint_key")
	assert_eq(_state(), before, "P: an order during the replay or the countries' turn")


# ----- R60: the plain click, O, the storm ----------------------------------------------------------------------------------


func test_a_plain_right_click_replaces_the_path() -> void:
	_open(_savoy())
	var a := _on_a_path()
	assert_gt(a.points, 0, "points left, enough to reach Susa")
	_click(SUSA, MOUSE_BUTTON_RIGHT, false)
	assert_eq([a.hex, a.via], [SUSA, PackedInt32Array()], "P: a plain click that extends the path")


func test_o_replaces_the_path_at_the_cursor() -> void:
	_open(_savoy())
	var a := _on_a_path()
	_armies().move_cursor(MapInput.CURSOR_LEFT)
	var cursor := _armies().cursor_hex()
	_chord(&"map_command_key")
	assert_eq([a.goal, a.via], [cursor, PackedInt32Array()])


func test_a_storm_on_a_path_is_judged_by_its_own_check() -> void:
	_open(_savoy())
	var a := _on_a_path()
	var before := _state()
	assert_false(_armies().storm(a.id, SOUTH))
	assert_eq(_reasons.back(), str(Session.check("storm", {"army": a.id, "goal": SOUTH}).reason), "P: a path that bars a storm")
	assert_eq(_state(), before)


# ----- the question --------------------------------------------------------------------------------------------------------


## Savoy at war with Milan since last season (MovesFixture.duel): the standing march's goal lies in Milan's land, the point added
## in Savoy's, so only the whole path carries the risk.
func test_the_question_reads_and_names_the_whole_path() -> void:
	var g := MovesFixture.duel()
	g.wars[0].start_turn = g.turn - 1
	var a := MovesFixture.named(g, MovesFixture.NAME_HOME)
	var point := Vector2i(6, 6)
	var goal := a.hex + Vector2i(0, 1)
	assert_true(MovesFixture.standing(g, a, point))
	_open(g)
	assert_true(_armies().select_army(a.id))
	assert_eq(Territory.owner_tag(g, point), MovesFixture.MILAN)
	var asked: Array[Confirm] = []
	_armies().orders().ask = func(screen: Screen) -> void:
		add_child_autofree(screen)
		asked.append(screen as Confirm)
	assert_true(MoveOrders.march_risks(g, SAV, a.id, goal).is_empty(), "the plain march has no risk")
	var via: Array[Vector2i] = [point]
	assert_false(MoveOrders.march_risks(g, SAV, a.id, goal, via).is_empty(), "the path through the point has one")
	var before := _state()
	_click(goal)
	assert_eq(asked.size(), 1, "P: a risky path ordered with no question (%s)" % str(_reasons))
	if asked.size() != 1:
		return
	assert_eq(_state(), before, "nothing before the answer")
	var line := MoveOrders.PATH_LINE % MoveOrders.PATH_JOIN.join(PackedStringArray([Words.place(g, point), Words.place(g, goal)]))
	var words := " ".join(PackedStringArray(AppFlowHelpers.labels_under(asked[0])))
	assert_true(words.contains(line), "'%s' in: %s" % [line, words])
	asked[0].button_for(&"cancel").pressed.emit()
	await get_tree().process_frame
	assert_eq(_state(), before, "Cancel changes nothing")
	_click(goal)
	asked[1].button_for(&"confirm").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(Session.unsaved_actions, int(before[2]) + 1, "Move orders it")
	assert_eq([a.hex, a.via], [goal, PackedInt32Array()], "at the goal, so by way of the point (R65)")


func test_a_plain_march_asks_with_no_path_line() -> void:
	assert_eq(MoveOrders.path_line(_savoy(), [] as Array[Vector2i], SUSA), "")


## Planted fault: Continue's question reading the straight march to the goal and not the kept points.
func test_continue_reads_the_risks_through_the_kept_points() -> void:
	var g := MovesFixture.duel()
	g.wars[0].start_turn = g.turn - 1
	var a := MovesFixture.named(g, MovesFixture.NAME_HOME)
	var goal := a.hex + Vector2i(0, 1)
	var point := Vector2i(6, 6)
	Armies.set_order(g, a, Army.ORDER_NONE, goal, PackedInt32Array(), PackedInt32Array([g.map.index_of(point)]))
	g.version += 1
	var via: Array[Vector2i] = [point]
	var risks := MoveOrders.continue_risks(g, SAV, a.id)
	assert_eq(risks, MoveOrders.march_risks(g, SAV, a.id, goal, via))
	assert_ne(risks, MoveOrders.march_risks(g, SAV, a.id, goal))


# ----- R59, R68: the preview and the path ----------------------------------------------------------------------------------


func test_shift_held_previews_the_extended_path_on_the_map_and_the_card() -> void:
	_open(_savoy())
	var a := _selected()
	_click(FAR_EAST)
	var before := _state()
	_point_at(PINEROLO)
	var marks := _armies().route_marks()
	assert_true(marks.pins().is_empty(), "without Shift: the plain march")
	assert_eq(_card().line_texts(), _distinct(MovePreview.to(_game, SAV, a.id, PINEROLO)))
	_map_input()._unhandled_input(_shift_event(true))
	var via: Array[Vector2i] = [FAR_EAST]
	var extended := MovePreview.via(_game, SAV, a.id, via, PINEROLO)
	assert_eq(marks.pins(), _pins_of(via), "P: a held Shift that draws the plain march")
	assert_true(marks.points().has(_scene.view().centre_of(FAR_EAST)), "the path runs by its point")
	assert_eq(marks.points().back(), _scene.view().centre_of(PINEROLO))
	assert_eq(_card().line_texts(), _distinct(extended), "the card too")
	assert_true(str(_card().line_texts().back()).begins_with("Whole route: 2 legs"))
	_point_at(_sea())
	assert_eq(marks.pins(), _pins_of(via), "a refused point keeps the pins")
	assert_true(marks.points().is_empty(), "no route to a refused hex")
	_point_at(PINEROLO)
	_map_input()._unhandled_input(_shift_event(false))
	assert_true(marks.pins().is_empty(), "Shift up: the plain march again")
	assert_eq(_card().line_texts(), _distinct(MovePreview.to(_game, SAV, a.id, PINEROLO)))
	assert_eq(_state(), before, "P: a preview that changes the game")


func test_shift_held_on_the_final_point_says_what_comes_off() -> void:
	_open(_savoy())
	var a := _on_a_path()
	_map_input()._unhandled_input(_shift_event(true))
	_point_at(PINEROLO)
	assert_eq(_card().title_text(), Words.place(_game, PINEROLO))
	assert_eq(str(_card().line_texts()[0]), MarchPath.SHORTEN_TEXT, "P: a preview that adds the final point again")
	assert_eq(_armies().route_marks().points().back(), _scene.view().centre_of(FAR_EAST), "the shorter path")
	_click(PINEROLO)
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i])
	_point_at(SOUTH)
	_point_at(FAR_EAST)
	assert_eq(_card().line_texts(), [MarchPath.HALT_TEXT] as Array[String])
	assert_true(_armies().route_marks().points().is_empty())


func test_with_no_path_shift_held_shows_the_plain_march() -> void:
	_open(_savoy())
	var a := _selected()
	_map_input()._unhandled_input(_shift_event(true))
	_point_at(PINEROLO)
	assert_eq(_card().line_texts(), _distinct(MovePreview.to(_game, SAV, a.id, PINEROLO)))
	assert_true(MarchPath.preview(_game, SAV, a.id, PINEROLO).is_empty())


func test_the_stored_route_pins_the_points_still_ahead() -> void:
	_open(_savoy())
	var a := _on_a_path()
	_point_at(PINEROLO)
	var stored := _armies().stored_marks()
	assert_true(stored.is_thin())
	assert_eq(stored.pins(), _pins_of([FAR_EAST]), "P: a stored route hidden under the pointer on its goal")
	for _s: int in 6:
		if a.via.is_empty():
			break
		assert_true(bool(Session.end_season().ok))
		_armies().select_army(a.id)
		_armies().sync()
	assert_true(a.via.is_empty(), "the point is passed")
	assert_true(stored.pins().is_empty(), "P: a marker for a point already passed")


# ----- the App: real events ------------------------------------------------------------------------------------------------


func _app() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(["--new-game", "--country=SAV", "--seed=1480"])
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("game/autosave", "off")
	s.set_value("game/movement", "instant")
	app.set_settings_override(s)
	vp.add_child(app)
	var up := func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()
	assert_true(await _wait_until(up), "the game is up")
	await _frames(3)
	_game = Session.game
	_scene = app.map_scene()
	_hover = app.hud().map_hover()
	_scene.refused.connect(func(reason: String) -> void: _reasons.append(reason))
	var army := ArmyFixture.army(_game, SAV, TURIN, 0, 2)
	_game.version += 1
	_armies().sync()
	assert_true(_armies().show_army(army.id))
	await _frame_on(TURIN)
	return {"vp": vp, "app": app, "army": army}


func _frames(count: int) -> void:
	for _i: int in count:
		await get_tree().process_frame


## The camera frames `hex`: it lands in the middle of the viewport, clear of the panels.
func _frame_on(hex: Vector2i) -> void:
	_scene.frame_at(_scene.view().centre_of(hex), 1.0)
	await _frames(40)


func _wait_until(done: Callable, limit: int = 3000) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


func _push_key(vp: SubViewport, action: StringName) -> void:
	var base := Bindings.events_for(action)[0] as InputEventKey
	for pressed: bool in [true, false]:
		var ev := base.duplicate() as InputEventKey
		ev.pressed = pressed
		vp.push_input(ev)


func _push_motion(vp: SubViewport, at: Vector2, shift: bool = false) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.shift_pressed = shift
	vp.push_input(ev)


## A real right click on `hex` (framed first), with Shift or Ctrl held.
func _push_right(vp: SubViewport, hex: Vector2i, shift: bool, ctrl: bool = false) -> void:
	await _frame_on(hex)
	_push_motion(vp, _screen_of(hex), shift)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_RIGHT
		ev.position = _screen_of(hex)
		ev.global_position = ev.position
		ev.shift_pressed = shift
		ev.ctrl_pressed = ctrl
		ev.pressed = pressed
		vp.push_input(ev)
	await _frames(3)


func test_app_shift_right_clicks_order_a_path_and_shorten_it() -> void:
	var env := await _app()
	var vp := env.vp as SubViewport
	var a := env.army as Army
	await _push_right(vp, FAR_EAST, true)
	await _push_right(vp, PINEROLO, true)
	assert_eq(_path_of(a), [FAR_EAST, PINEROLO] as Array[Vector2i], "real Shift+right clicks order the path %s" % str(_reasons))
	await _push_right(vp, PINEROLO, true)
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i])
	assert_eq(_armies().selected_army(), a.id)


func test_app_a_held_shift_previews_the_extended_path() -> void:
	var env := await _app()
	var vp := env.vp as SubViewport
	await _push_right(vp, FAR_EAST, true)
	await _frame_on(PINEROLO)
	vp.push_input(_shift_event(true))
	_push_motion(vp, _screen_of(PINEROLO) + Vector2(4.0, 0.0), true)
	_push_motion(vp, _screen_of(PINEROLO), true)
	var told := func() -> bool:
		return _card().is_open() and not _card().line_texts().is_empty() \
				and str(_card().line_texts().back()).begins_with("Whole route: 2 legs")
	assert_true(await _wait_until(told, 300), str(_card().line_texts()))
	vp.push_input(_shift_event(false))
	await _frames(3)
	var plain := _card().line_texts()
	assert_false(not plain.is_empty() and str(plain.back()).begins_with("Whole route"), "P: a preview that stays")


func test_app_a_ctrl_right_click_storms_and_a_refusal_keeps_the_path() -> void:
	var env := await _app()
	var vp := env.vp as SubViewport
	var a := env.army as Army
	await _push_right(vp, FAR_EAST, true)
	var path := _path_of(a)
	var why := str(Session.check("storm", {"army": a.id, "goal": PINEROLO}).reason)
	_reasons.clear()
	await _push_right(vp, PINEROLO, false, true)
	assert_eq(_reasons.back() if not _reasons.is_empty() else "", why, "P: a Ctrl+right click that does not storm")
	assert_eq(_path_of(a), path, "and orders no march")


func test_app_esc_clears_the_army_and_keeps_its_path() -> void:
	var env := await _app()
	var vp := env.vp as SubViewport
	var a := env.army as Army
	await _push_right(vp, FAR_EAST, true)
	_push_key(vp, &"app_back")
	await _frames(2)
	assert_eq(_armies().selected_army(), -1, "P: Esc that needs a second press")
	assert_eq((env.app as App).stack().count(), 0)
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i], "the order stays")


func test_app_f5_and_f9_keep_the_path() -> void:
	var env := await _app()
	var vp := env.vp as SubViewport
	var a := env.army as Army
	await _push_right(vp, FAR_EAST, true)
	await _push_right(vp, PINEROLO, true)
	var id := a.id
	_push_key(vp, &"game_quicksave")
	await _frames(3)
	await _push_right(vp, PINEROLO, true)
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i], "changed after the save")
	_push_key(vp, &"game_quickload")
	await _frames(3)
	var app := env.app as App
	if app.stack().top() is Confirm:
		(app.stack().top() as Confirm).button_for(&"confirm").pressed.emit()
	assert_true(await _wait_until(func() -> bool: return Session.game != _game and Session.game != null), "loaded")
	await _frames(5)
	_game = Session.game
	assert_eq(_path_of(Armies.by_id(_game, id)), [FAR_EAST, PINEROLO] as Array[Vector2i], "P: a path lost in the save")


func test_app_a_storm_by_key_is_judged_by_its_own_check() -> void:
	var env := await _app()
	var vp := env.vp as SubViewport
	var a := env.army as Army
	await _push_right(vp, FAR_EAST, true)
	_reasons.clear()
	_push_key(vp, &"map_command_storm")
	await _frames(2)
	assert_eq(_reasons.size(), 1, "one refusal")
	assert_eq(_path_of(a), [FAR_EAST] as Array[Vector2i])
