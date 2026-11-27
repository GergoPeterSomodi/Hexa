## Multi-leg marches in the shell (docs/architecture/moves-build-spec.md R58 to R62, R68, D32 to D34; MV19): Shift+left click and
## V stage stops for the selected army and take the last one off; with no army Shift+left selects; nothing is acted, logged or
## changed before the commit; a right click, O and the move card's "March" order the march through the stops (the question of a
## risky route first); a refused order keeps them; a storm is refused while they stand; Esc, another selection, the army gone,
## End season and a new or loaded game clear them; the path marks a pin on each stop and the card stays up, pinned, with its
## buttons. North Italy's 1480 game with Savoy chosen (the hexes of test_march_via.gd); the App tests push real events.
## Every case names its planted fault (P).
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const SAV := &"SAV"
const TURIN := Vector2i(5, 9)
const SUSA := Vector2i(4, 9)
const PINEROLO := Vector2i(4, 10)
const SOUTH := Vector2i(5, 10)
const NORTH := Vector2i(3, 7)
const FAR_SOUTH := Vector2i(5, 12)
## Twenty move points east of Turin: a stop that a fresh army cannot reach in one season.
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


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


func _map_input() -> MapInput:
	return _scene.map_input()


func _card() -> MoveCard:
	return _hover.move_card()


## What staging may never change.
func _state() -> Array:
	return [_game.digest(), _game.version, Session.unsaved_actions]


func _screen_of(hex: Vector2i) -> Vector2:
	return _scene.view().get_global_transform_with_canvas() * _scene.view().centre_of(hex)


## A click of the scene's MapInput on `hex`.
func _click(hex: Vector2i, button: MouseButton = MOUSE_BUTTON_LEFT, shift: bool = true) -> void:
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


## The pointer rests on `hex` (NO_HEX: off the map or over the UI).
func _point_at(hex: Vector2i) -> void:
	_map_input().hover_changed.emit(hex)


func _stage(hexes: Array[Vector2i]) -> void:
	for h: Vector2i in hexes:
		assert_true(_armies().toggle_stop(h), "a stop at %s: %s" % [h, str(_reasons)])


func _pins_of(hexes: Array[Vector2i]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for h: Vector2i in hexes:
		out.append(_scene.view().centre_of(h))
	return out


func _idx(hexes: Array[Vector2i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for h: Vector2i in hexes:
		out.append(_game.map.index_of(h))
	return out


func _sea() -> Vector2i:
	for i: int in _game.map.hex_count():
		if _game.map.land[i] != 1:
			return _game.map.hex_of(i)
	return Army.NO_HEX


# ----- R58: staging --------------------------------------------------------------------------------------------------------


func test_shift_left_stages_and_on_the_last_stop_removes_it_changing_nothing() -> void:
	_open(_savoy())
	_selected()
	var before := _state()
	_click(SUSA)
	assert_eq(_armies().stops(), [SUSA] as Array[Vector2i])
	_click(PINEROLO)
	assert_eq(_armies().stops(), [SUSA, PINEROLO] as Array[Vector2i], "in the order clicked")
	assert_eq(_scene.selected, MapScene.NO_HEX, "the click does not select the hex")
	_click(PINEROLO)
	assert_eq(_armies().stops(), [SUSA] as Array[Vector2i], "again on the last stop: removed")
	_click(SUSA)
	assert_false(_armies().has_stops())
	assert_eq(_state(), before, "P: a staging that changes the digest, the version or the actions")
	assert_true(_reasons.is_empty())


func test_with_no_army_shift_left_selects_the_hex() -> void:
	_open(_savoy())
	_click(SUSA)
	assert_eq(_scene.selected, SUSA, "P: Shift+left with no army that no longer selects")
	assert_false(_armies().has_stops())
	assert_false(_armies().toggle_stop(SUSA))
	assert_eq(_reasons.back(), "Select an army first.", "V with no army says so")


func test_a_plain_left_click_with_an_army_selected_stages_nothing() -> void:
	_open(_savoy())
	_selected()
	_click(SUSA, MOUSE_BUTTON_LEFT, false)
	assert_false(_armies().has_stops(), "P: a plain click that stages")


func test_staging_is_refused_while_the_replay_runs_or_the_countries_move() -> void:
	_open(_savoy())
	_selected()
	var blocked: Array[Vector2] = []
	_map_input().blocked_click.connect(func(px: Vector2) -> void: blocked.append(px))
	_map_input().orders_blocked = func() -> bool: return true
	_armies().orders_blocked = func() -> bool: return true
	_click(SUSA)
	assert_eq(blocked.size(), 1, "a blocked click, as any order")
	_chord(&"map_waypoint_key")
	assert_eq(_said.back(), MapArmies.REPLAY_BLOCKED)
	assert_false(_armies().has_stops(), "P: a stop staged during the replay")
	_map_input().orders_blocked = Callable()
	_armies().orders_blocked = Callable()
	_map_input().block_orders("Countries are moving")
	_click(SUSA)
	_point_at(SUSA)
	_chord(&"map_waypoint_key")
	assert_false(_armies().has_stops(), "nor while the countries move")


func test_a_refused_stop_says_why_and_appends_nothing() -> void:
	_open(_savoy())
	var a := _selected()
	assert_false(_armies().toggle_stop(TURIN))
	assert_eq(_reasons.back(), MarchVia.SAME_AS_ARMY_TEXT)
	var sea := _sea()
	assert_false(_armies().toggle_stop(sea))
	var why := str(Movement.goal_verdict(_game, a, SAV, sea).reason)
	assert_eq(_reasons.back(), str(MovePreview.refused(_game, SAV, sea, why).verdict.reason), "water, in fog-safe words")
	assert_false(_armies().toggle_stop(Vector2i(-4, -4)))
	assert_eq(_reasons.back(), MarchStops.OFF_MAP_TEXT)
	assert_false(_armies().has_stops(), "P: a refused stop appended")
	_game.defs.max_stops = 2
	_stage([SUSA, PINEROLO])
	assert_false(_armies().toggle_stop(SOUTH))
	assert_eq(_reasons.back(), MarchVia.TOO_MANY_TEXT % 2, "P: more stops than the defs allow")
	assert_eq(_armies().stops(), [SUSA, PINEROLO] as Array[Vector2i])
	assert_true(_armies().toggle_stop(PINEROLO), "the last can still come off at the limit")


func test_a_leg_is_judged_from_the_stop_before_it() -> void:
	_open(_savoy())
	_selected()
	_stage([SUSA])
	assert_true(_armies().toggle_stop(PINEROLO))
	assert_true(_armies().toggle_stop(SUSA), "a stop met again later is a new stop, not the one before it")
	assert_eq(_armies().stops(), [SUSA, PINEROLO, SUSA] as Array[Vector2i])


# ----- R62: V --------------------------------------------------------------------------------------------------------------


func test_v_stages_at_the_hovered_hex_and_at_the_cursor_after_alt_arrows() -> void:
	_open(_savoy())
	_selected()
	_point_at(PINEROLO)
	_chord(&"map_waypoint_key")
	assert_eq(_armies().stops(), [PINEROLO] as Array[Vector2i], "the hovered hex")
	_chord(&"map_waypoint_key")
	assert_false(_armies().has_stops(), "V on the last stop removes it")
	_armies().move_cursor(MapInput.CURSOR_LEFT)
	assert_eq(_armies().cursor_hex(), SUSA)
	_chord(&"map_waypoint_key")
	assert_eq(_armies().stops(), [SUSA] as Array[Vector2i], "P: V that ignores the order cursor")
	_point_at(SOUTH)
	_chord(&"map_waypoint_key")
	assert_eq(_armies().stops(), [SUSA, SOUTH] as Array[Vector2i], "the pointer takes over again once it moves")


# ----- R60: the commit -----------------------------------------------------------------------------------------------------


func test_a_right_click_orders_the_march_through_the_staged_stops() -> void:
	_open(_savoy())
	var a := _selected()
	_stage([FAR_EAST])
	var before := Session.unsaved_actions
	_point_at(PINEROLO)
	_click(PINEROLO, MOUSE_BUTTON_RIGHT, false)
	assert_eq(Session.unsaved_actions, before + 1, "one action")
	assert_eq([a.order, a.goal, a.via], [Army.ORDER_MARCH, PINEROLO, _idx([FAR_EAST])], "P: a commit that drops a stop")
	assert_false(_armies().has_stops(), "the staged list is emptied")
	assert_false(_said.is_empty(), "the order's toast")


func test_a_commit_on_the_last_stop_makes_it_the_goal() -> void:
	_open(_savoy())
	var a := _selected()
	_stage([FAR_EAST, PINEROLO])
	assert_true(_armies().command(PINEROLO))
	assert_eq([a.goal, a.via], [PINEROLO, _idx([FAR_EAST])], "P: a goal given twice")


func test_a_single_stop_committed_on_itself_is_a_plain_march() -> void:
	_open(_savoy())
	var a := _selected()
	_stage([SUSA])
	assert_true(_armies().command(SUSA))
	assert_eq([a.hex, a.via], [SUSA, PackedInt32Array()])
	assert_false(_armies().has_stops())


func test_o_orders_at_the_cursor_through_the_stops() -> void:
	_open(_savoy())
	var a := _selected()
	_stage([FAR_EAST])
	_armies().move_cursor(MapInput.CURSOR_LEFT)
	_chord(&"map_command_key")
	assert_eq([a.goal, a.via], [SUSA, _idx([FAR_EAST])])
	assert_false(_armies().has_stops())


func test_a_refused_order_keeps_the_stops_and_says_why() -> void:
	_open(_savoy())
	_selected()
	_stage([SUSA, PINEROLO])
	var before := _state()
	var sea := _sea()
	var preview := MovePreview.via(_game, SAV, _armies().selected_army(), [SUSA, PINEROLO] as Array[Vector2i], sea)
	assert_true(_armies().command(sea))
	assert_eq(_reasons.back(), str(preview.verdict.reason), "the toast gives the card's reason")
	assert_eq(_armies().stops(), [SUSA, PINEROLO] as Array[Vector2i], "P: a refusal that drops the stops")
	assert_eq(_state(), before)


func test_a_right_click_on_the_army_halts_and_drops_the_stops() -> void:
	_open(_savoy())
	var a := _selected()
	assert_true(_armies().command(FAR_EAST))
	assert_eq(a.order, Army.ORDER_MARCH)
	_stage([SUSA])
	assert_true(_armies().command(a.hex))
	assert_eq([a.order, a.goal], [Army.ORDER_NONE, FAR_EAST], "halted")
	assert_false(_armies().has_stops(), "P: stops that outlive the halt")


func test_a_storm_is_refused_while_stops_are_staged() -> void:
	_open(_savoy())
	var a := _selected()
	_stage([SUSA])
	var before := _state()
	assert_false(_armies().storm(a.id, PINEROLO))
	assert_eq(_reasons.back(), "A storm takes no stops: clear them first (Esc)", "P: a storm that drops the stops silently")
	assert_eq(_armies().stops(), [SUSA] as Array[Vector2i])
	assert_eq(_state(), before)
	_armies().clear_stops()
	assert_false(_armies().storm(a.id, PINEROLO))
	assert_ne(_reasons.back(), MarchStops.STORM_TEXT, "without stops the storm's own check speaks")


## Savoy at war with Milan since last season (MovesFixture.duel): the stop lies in Milan's land, the goal in Savoy's, so only
## the route through the stop carries the risk.
func test_the_question_reads_the_whole_route_and_move_orders_through_the_stops() -> void:
	var g := MovesFixture.duel()
	g.wars[0].start_turn = g.turn - 1
	g.version += 1
	_open(g)
	var a := MovesFixture.named(g, MovesFixture.NAME_HOME)
	assert_true(_armies().select_army(a.id))
	var stop := Vector2i(6, 6)
	var goal := a.hex + Vector2i(0, 1)
	assert_eq(Territory.owner_tag(g, stop), MovesFixture.MILAN)
	var asked: Array[Confirm] = []
	_armies().orders().ask = func(screen: Screen) -> void:
		add_child_autofree(screen)
		asked.append(screen as Confirm)
	assert_true(MoveOrders.march_risks(g, SAV, a.id, goal).is_empty(), "the plain march has no risk")
	var via: Array[Vector2i] = [stop]
	var risks := MoveOrders.march_risks(g, SAV, a.id, goal, via)
	assert_false(risks.is_empty(), "the route through the stop has one")
	_stage(via)
	var before := _state()
	assert_true(_armies().command(goal))
	assert_eq(asked.size(), 1, "P: a risky route ordered with no question")
	assert_eq(_state(), before, "nothing before the answer")
	asked[0].button_for(&"cancel").pressed.emit()
	await get_tree().process_frame
	assert_eq(_armies().stops(), via, "Cancel keeps the stops")
	assert_true(_armies().command(goal))
	asked[1].button_for(&"confirm").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(Session.unsaved_actions, int(before[2]) + 1, "Move orders it")
	assert_eq([a.hex, a.via], [goal, PackedInt32Array()], "at the goal, so by way of the stop (R65)")
	assert_false(_armies().has_stops())


## Planted fault: Continue's question reading the straight march to the goal and not the kept stops.
func test_continue_reads_the_risks_through_the_kept_stops() -> void:
	var g := MovesFixture.duel()
	g.wars[0].start_turn = g.turn - 1
	var a := MovesFixture.named(g, MovesFixture.NAME_HOME)
	var goal := a.hex + Vector2i(0, 1)
	var stop := Vector2i(6, 6)
	Armies.set_order(g, a, Army.ORDER_NONE, goal, PackedInt32Array(), PackedInt32Array([g.map.index_of(stop)]))
	g.version += 1
	var via: Array[Vector2i] = [stop]
	var risks := MoveOrders.continue_risks(g, SAV, a.id)
	assert_eq(risks, MoveOrders.march_risks(g, SAV, a.id, goal, via))
	assert_ne(risks, MoveOrders.march_risks(g, SAV, a.id, goal))


# ----- R61: the clears -----------------------------------------------------------------------------------------------------


func test_a_new_selection_and_a_gone_army_clear_the_stops() -> void:
	_open(_savoy())
	var first := _selected()
	var other := ArmyFixture.army(_game, SAV, NORTH, 0, 2)
	_game.version += 1
	_armies().sync()
	_stage([SUSA])
	_armies().select_army(first.id)
	assert_true(_armies().has_stops(), "the same army selected again keeps them")
	_armies().select_army(other.id)
	assert_false(_armies().has_stops(), "P: stops that outlive their army's selection")
	_stage([SUSA])
	_armies().clear_army()
	assert_false(_armies().has_stops())
	_armies().select_army(first.id)
	_stage([SUSA])
	_scene.select_hex(NORTH)
	assert_false(_armies().has_stops(), "a hex selection releases the army and its stops")
	_armies().select_army(other.id)
	_stage([SUSA])
	Armies.remove(_game, other)
	_game.version += 1
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_armies().has_stops(), "P: stops of an army that is gone")


func test_end_season_clears_the_stops() -> void:
	_open(_savoy())
	_selected()
	_stage([SUSA])
	assert_true(bool(Session.begin_season().ok))
	await get_tree().process_frame
	assert_false(_armies().has_stops(), "P: stops staged while the season runs")
	Session.step_orders(INF)
	Session.finish_season()
	await get_tree().process_frame
	_armies().select_army(_game.armies.filter(func(x: Army) -> bool: return x.tag == SAV)[0].id)
	_point_at(MapInput.NO_HEX)
	assert_true(_armies().toggle_stop(SOUTH) or _armies().toggle_stop(PINEROLO), str(_reasons))
	assert_true(bool(Session.end_season().ok))
	assert_false(_armies().has_stops(), "a season run at once clears them too")


func test_a_new_or_loaded_game_clears_the_stops() -> void:
	_open(_savoy())
	_selected()
	_stage([SUSA])
	var other := _savoy()
	Session.start_game(other)
	assert_false(_armies().has_stops(), "P: stops carried into another game")


# ----- R59, R68: the path --------------------------------------------------------------------------------------------------


func test_the_path_runs_through_the_stops_with_a_pin_on_each() -> void:
	_open(_savoy())
	var a := _selected()
	_stage([SUSA, PINEROLO])
	_point_at(SOUTH)
	var marks := _armies().route_marks()
	assert_eq(marks.pins(), _pins_of([SUSA, PINEROLO]))
	var via: Array[Vector2i] = [SUSA, PINEROLO]
	var hexes := MovePreview.via(_game, SAV, a.id, via, SOUTH).hexes as Array
	assert_eq(marks.points().size(), hexes.size() + 1, "the whole route, from the army")
	assert_true(marks.points().has(_scene.view().centre_of(SUSA)), "P: a path that skips a stop")
	_point_at(_sea())
	assert_eq(marks.pins(), _pins_of([SUSA, PINEROLO]), "P: a refused hover that loses the pins")
	assert_true(marks.points().is_empty(), "no route to a refused hex")
	_point_at(MapInput.NO_HEX)
	assert_eq(_armies().staged_target(), PINEROLO, "off the map: the staged route to its last stop")
	assert_eq(marks.points().back(), _scene.view().centre_of(PINEROLO))
	_armies().clear_stops()
	assert_true(marks.pins().is_empty(), "cleared stops leave no pin")


func test_the_stored_route_pins_the_stops_still_ahead() -> void:
	_open(_savoy())
	var a := _selected()
	_stage([FAR_EAST])
	_point_at(PINEROLO)
	assert_true(_armies().command(PINEROLO))
	var stored := _armies().stored_marks()
	assert_true(stored.is_thin())
	assert_eq(stored.pins(), _pins_of([FAR_EAST]), "P: a stored route hidden under the pointer on its goal")
	for _s: int in 6:
		if a.via.is_empty():
			break
		assert_true(bool(Session.end_season().ok))
		_armies().select_army(a.id)
		_armies().sync()
	assert_true(a.via.is_empty(), "the stop is passed")
	assert_true(stored.pins().is_empty(), "P: a marker for a stop already passed")


# ----- R59, R62: the move card ---------------------------------------------------------------------------------------------


func test_the_card_stays_pinned_with_its_buttons_while_stops_are_staged() -> void:
	_open(_savoy())
	var a := _selected()
	_stage([SUSA, PINEROLO])
	assert_true(_card().is_open(), "the card shows at once")
	assert_true(_card().is_staged())
	assert_eq(_card().march_button().text, "March")
	assert_eq(_card().clear_button().text, "Clear stops")
	_point_at(SOUTH)
	_hover.on_hover_changed(SOUTH, Vector2(300, 300))
	var via: Array[Vector2i] = [SUSA, PINEROLO]
	assert_eq(_card().line_texts(), _distinct(MovePreview.via(_game, SAV, a.id, via, SOUTH)), "the staged route to the pointer")
	assert_true(str(_card().line_texts().back()).begins_with("Whole route: 3 legs"))
	var at := _card().position
	_point_at(MapInput.NO_HEX)
	_hover.on_hover_changed(MapInput.NO_HEX)
	assert_true(_card().is_open(), "P: a card that goes when the pointer is on its button")
	assert_eq(_card().position, at, "P: a card that moves from under the pointer")
	assert_true(str(_card().line_texts().back()).begins_with("Whole route: 2 legs"), "to the last stop")
	assert_eq(_card().march_button().focus_mode, Control.FOCUS_NONE)
	assert_eq(_card().mouse_filter, Control.MOUSE_FILTER_IGNORE, "only the buttons take the mouse")


func _distinct(preview: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for line: Array in MoveCard.distinct_lines(preview.lines as Array):
		out.append(str(line[0]))
	return out


func test_the_pinned_place_does_not_hang_on_the_card_height_and_stays_inside() -> void:
	var bounds := Rect2(0.0, 0.0, 1280.0, 720.0)
	var at := MapHover.pinned_card_position(Vector2(400.0, 100.0), bounds)
	assert_eq(at, Vector2(400.0, 100.0) + MapHover.CURSOR_OFFSET, "beside the stop")
	var low := MapHover.pinned_card_position(Vector2(1270.0, 710.0), bounds)
	assert_lte(low.x + MoveCard.CARD_W, 1280.0, "left of a stop at the right edge")
	assert_eq(low.y, 720.0 * MapHover.PINNED_LOWEST, "never so low that its lines leave the map")
	var off := MapHover.pinned_card_position(Vector2(-900.0, -900.0), bounds)
	assert_true(bounds.has_point(off), "a stop off the screen")


func test_the_march_button_orders_to_the_last_stop_and_the_card_unpins() -> void:
	_open(_savoy())
	var a := _selected()
	_stage([FAR_EAST, PINEROLO])
	_point_at(MapInput.NO_HEX)
	_card().march_button().pressed.emit()
	assert_eq([a.goal, a.via], [PINEROLO, _idx([FAR_EAST])])
	assert_false(_armies().has_stops())
	assert_false(_card().is_open() and _card().is_staged(), "P: buttons that stay after the order")


func test_the_march_button_after_alt_arrows_orders_to_the_cursor() -> void:
	_open(_savoy())
	var a := _selected()
	_stage([FAR_EAST])
	_armies().move_cursor(MapInput.CURSOR_LEFT)
	_card().march_button().pressed.emit()
	assert_eq([a.goal, a.via], [SUSA, _idx([FAR_EAST])])


func test_the_clear_button_drops_the_stops_and_the_plain_card_returns() -> void:
	_open(_savoy())
	_selected()
	_stage([SUSA])
	var before := _state()
	_card().clear_button().pressed.emit()
	assert_false(_armies().has_stops())
	assert_false(_card().is_staged())
	_point_at(SOUTH)
	_hover.on_hover_changed(SOUTH, Vector2(300, 300))
	assert_true(_card().is_open())
	assert_false(_card().is_staged(), "P: buttons on a plain march")
	assert_eq(_state(), before)


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
	_scene.camera().position = _scene.view().centre_of(TURIN)
	await _frames(40)
	return {"vp": vp, "app": app, "army": army}


func _frames(count: int) -> void:
	for _i: int in count:
		await get_tree().process_frame


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


func _push_motion(vp: SubViewport, at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	vp.push_input(ev)


func _push_click(vp: SubViewport, at: Vector2, shift: bool = false) -> void:
	_push_motion(vp, at)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.global_position = at
		ev.pressed = pressed
		ev.shift_pressed = shift
		vp.push_input(ev)


func test_app_a_shift_click_stages_and_the_march_button_is_clicked_with_the_mouse() -> void:
	var env := await _app()
	var vp := env.vp as SubViewport
	var a := env.army as Army
	_push_click(vp, _screen_of(SUSA), true)
	await _frames(2)
	_push_click(vp, _screen_of(PINEROLO), true)
	await _frames(2)
	assert_eq(_armies().stops(), [SUSA, PINEROLO] as Array[Vector2i], "real Shift+clicks stage")
	assert_true(_card().is_open() and _card().is_staged())
	var button := _card().march_button()
	var at := button.get_global_transform_with_canvas() * (button.size * 0.5)
	_push_motion(vp, at)
	await _frames(3)
	assert_eq(vp.gui_get_hovered_control(), button, "the pointer reaches the button")
	assert_eq(button.get_global_transform_with_canvas() * (button.size * 0.5), at, "P: a button that flees the pointer")
	_push_click(vp, at)
	await _frames(3)
	assert_eq([a.hex, a.via], [PINEROLO, PackedInt32Array()], "the march went by its stop")
	assert_false(_armies().has_stops())
	assert_eq(_armies().selected_army(), a.id, "the click on the button selected nothing")


func test_app_esc_clears_the_stops_first_then_the_army() -> void:
	var env := await _app()
	var vp := env.vp as SubViewport
	var a := env.army as Army
	_stage([SUSA, PINEROLO])
	var before := _state()
	_push_key(vp, &"app_back")
	await _frames(2)
	assert_false(_armies().has_stops(), "P: Esc that leaves stops staged")
	assert_eq(_armies().selected_army(), a.id, "one step at a time: the army stays")
	assert_eq((env.app as App).stack().count(), 0)
	_push_key(vp, &"app_back")
	await _frames(2)
	assert_eq(_armies().selected_army(), -1)
	assert_eq(_state(), before)


func test_app_f5_keeps_the_stops_and_f9_clears_them() -> void:
	var env := await _app()
	var vp := env.vp as SubViewport
	_stage([SUSA])
	_push_key(vp, &"game_quicksave")
	await _frames(3)
	assert_true(_armies().has_stops(), "F5 saves without them and leaves them staged")
	_push_key(vp, &"game_quickload")
	assert_true(await _wait_until(func() -> bool: return Session.game != _game and Session.game != null), "loaded")
	await _frames(5)
	_scene = (env.app as App).map_scene()
	assert_false(MapArmies.stops_in(env.app as App), "P: staged stops after a load")


func test_app_a_storm_by_key_is_refused_with_stops_staged() -> void:
	var env := await _app()
	_stage([SUSA])
	_push_key(env.vp as SubViewport, &"map_command_storm")
	await _frames(2)
	assert_eq(_reasons.back(), MarchStops.STORM_TEXT)
	assert_true(_armies().has_stops())
