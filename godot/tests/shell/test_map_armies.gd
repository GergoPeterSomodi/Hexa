## The map's armies (docs/architecture/m6-build-spec.md 6.1 and 6.3; L16): selection by click (a second click on the same token
## takes the next army; Shift+click selects the hex, with or without an army selected), by Tab, the right click that orders a
## march through Session.act, R,
## the order cursor that clamps to the map, and the route and reach data the map draws.
extends GutTest

var _game: Game = null
var _scene: MapScene = null
var _reasons: Array[String] = []


func before_each() -> void:
	_game = ArmyFixture.game()
	Session.start_game(_game)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_reasons.clear()
	_scene.refused.connect(func(reason: String) -> void: _reasons.append(reason))


func after_each() -> void:
	Session.end_game()


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


## An army of the player's on `hex`, made through the fixture; the game's version moves so the view reads it (as an action does).
func _army(hex: Vector2i, count: int) -> Army:
	var a := ArmyFixture.army(_game, ArmyFixture.TAG, hex, 0, count)
	_game.version += 1
	return a


func _centre(hex: Vector2i) -> Vector2:
	return _scene.view().centre_of(hex)


## The viewport point of the centre of `hex`.
func _hex_screen(hex: Vector2i) -> Vector2:
	return _scene.view().get_global_transform_with_canvas() * _centre(hex)


## The viewport point on your army's token at `hex`: 25 px above its foot, in its click area.
func _token_screen(hex: Vector2i) -> Vector2:
	var token := _armies().tokens().token_at(hex, ArmyFixture.TAG)
	return token.get_global_transform_with_canvas() * Vector2(0.0, -25.0)


## A left click (press and release at `screen`) given to MapInput as the viewport gives it.
func _click(screen: Vector2, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = screen
		ev.global_position = screen
		ev.pressed = pressed
		ev.shift_pressed = shift
		_scene.map_input()._unhandled_input(ev)


## A neighbour of `hex` the army can march to now (MovePreview's verdict is ok), NO_HEX when none.
func _goal_near(hex: Vector2i, army_id: int) -> Vector2i:
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if not _game.map.has(beside) or not _game.map.is_land(beside):
			continue
		var verdict := MovePreview.to(_game, ArmyFixture.TAG, army_id, beside)["verdict"] as Dictionary
		if bool(verdict["ok"]):
			return beside
	return ArmyFixture.NO_HEX


func test_a_click_on_your_token_selects_its_army_and_a_second_click_takes_the_next() -> void:
	var hex := ArmyFixture.find_town(_game)
	var first := _army(hex, 2).id
	var second := _army(hex, 3).id
	_armies().sync()
	var picked: Array[int] = []
	_armies().army_selected.connect(func(id: int) -> void: picked.append(id))
	_click(_token_screen(hex))
	assert_eq(_armies().selected_army(), first, "the first click selects the first army there")
	_click(_token_screen(hex))
	assert_eq(_armies().selected_army(), second, "a second click on the same token takes the next army")
	_click(_token_screen(hex))
	assert_eq(_armies().selected_army(), first, "and the next click comes back round")
	assert_eq(picked, [first, second, first], "army_selected said each pick")
	assert_eq(_scene.selected, MapScene.NO_HEX, "an army selection leaves the hex selection empty")


func test_shift_click_selects_the_hex_and_a_click_elsewhere_clears_the_army() -> void:
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	_armies().sync()
	_click(_token_screen(hex), true)
	assert_eq(_armies().selected_army(), -1, "Shift+click on the token does not pick the army")
	assert_eq(_scene.selected, hex, "and selects the hex")
	assert_true(_armies().select_army(id))
	# with an army selected too (the path is Shift+right click's, moves-build-spec.md R58)
	_click(_token_screen(hex), true)
	assert_eq(_armies().selected_army(), -1, "the select lets the army go")
	assert_eq(_scene.selected, hex, "and selects the hex")
	assert_true(_reasons.is_empty())
	assert_true(_armies().select_army(id))
	var beside := ImproveRules.neighbour(hex, 0)
	_click(_hex_screen(beside))
	assert_eq(_armies().selected_army(), -1, "a click on a hex with none of your tokens clears the army")
	assert_eq(_scene.selected, beside, "and selects that hex")


func test_tab_cycles_the_armies_that_need_orders_and_says_when_there_are_none() -> void:
	assert_false(_armies().next_army(), "no army of yours yet")
	assert_eq(_reasons, ["You have no army."])
	var hex := ArmyFixture.find_town(_game)
	var first := _army(hex, 2).id
	var second := _army(hex, 2).id
	_armies().sync()
	assert_true(_armies().next_army())
	assert_eq(_armies().selected_army(), first, "Tab selects the first")
	assert_true(_armies().next_army())
	assert_eq(_armies().selected_army(), second, "then the next")
	assert_true(_armies().next_army())
	assert_eq(_armies().selected_army(), first, "and wraps round")


func test_r_without_an_army_is_refused_and_a_refused_continue_is_said() -> void:
	assert_false(_armies().continue_march())
	assert_eq(_reasons.back(), "Select an army first.")
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	_armies().sync()
	assert_true(_armies().select_army(id))
	var before := Session.unsaved_actions
	assert_false(_armies().continue_march(), "a holding army has no halted march to continue")
	assert_ne(str(_reasons.back()), "", "the refusal is said")
	assert_eq(Session.unsaved_actions, before, "a refusal changes nothing")


func test_a_right_click_with_an_army_selected_orders_a_march_through_session() -> void:
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	# moves in the month: with no move points left the march is stored as a standing march instead of walking at once.
	Armies.set_points(_game, Armies.by_id(_game, id), 0)
	_game.version += 1
	_armies().sync()
	assert_true(_armies().select_army(id))
	var goal := _goal_near(hex, id)
	assert_ne(goal, ArmyFixture.NO_HEX, "a neighbour the army can march to")
	var before := Session.unsaved_actions
	_scene._on_command_requested(_centre(goal))
	assert_eq(Session.unsaved_actions, before + 1, "the order went through Session.act")
	var order := ArmyView.panel(_game, ArmyFixture.TAG, id)["order"] as Dictionary
	assert_eq(order["kind"], Army.ORDER_MARCH, "the army now marches")
	assert_eq(order["goal"], goal, "to the hex that was clicked")


func test_a_right_click_without_an_army_deselects_the_hex_as_before() -> void:
	var hex := ArmyFixture.find_town(_game)
	_scene.select_hex(hex)
	_scene._on_command_requested(_centre(hex))
	assert_eq(_scene.selected, MapScene.NO_HEX)


func test_the_order_cursor_clamps_to_the_map() -> void:
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	_armies().sync()
	assert_true(_armies().select_army(id))
	for i: int in 300:
		_armies().move_cursor(MapInput.CURSOR_LEFT)
	var edge := _armies().cursor_hex()
	assert_true(_game.map.has(edge), "the cursor is on the map")
	assert_eq(edge.x, 0, "it stops at the west edge")
	_armies().move_cursor(MapInput.CURSOR_LEFT)
	assert_eq(_armies().cursor_hex(), edge, "one more step changes nothing")


func test_without_an_army_the_selection_moves_and_clamps() -> void:
	_scene.select_hex(ArmyFixture.find_town(_game))
	var start := _scene.selected
	_armies().move_cursor(MapInput.CURSOR_RIGHT)
	assert_eq(_scene.selected, start + Vector2i(1, 0), "the selected hex moves east")
	for i: int in 300:
		_armies().move_cursor(MapInput.CURSOR_UP)
	assert_true(_game.map.has(_scene.selected), "the selection stays on the map")


func test_the_route_and_the_reach_are_drawn_from_the_preview() -> void:
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	_armies().sync()
	assert_true(_armies().select_army(id))
	var reach := MovePreview.reach(_game, ArmyFixture.TAG, id)
	assert_eq(_armies().reach_count(MapArmies.REACH_LAYER), (reach["season"] as PackedInt32Array).size(), "the reach of this season")
	assert_eq(_armies().reach_count(MapArmies.REACH_NEXT_LAYER), (reach["next"] as PackedInt32Array).size(), "and of the next")
	assert_ne(_scene.view().layer(MapArmies.REACH_NEXT_LAYER).get_cell_source_id(hex), -1, "the army's own hex is in reach")
	assert_eq(_scene.view().layer(MapArmies.REACH_LAYER).modulate, Tokens.MAP_REACH)

	var goal := _goal_near(hex, id)
	assert_ne(goal, ArmyFixture.NO_HEX)
	_scene.map_input().hover_changed.emit(goal)
	var preview := MovePreview.to(_game, ArmyFixture.TAG, id, goal)
	var route := _armies().route_marks()
	assert_eq(route.points().size(), (preview["hexes"] as Array).size() + 1, "the route has a point a hex and the army's own hex")
	assert_eq(route.points()[0], _centre(hex), "the line starts on the army's own hex (issue 434: the first segment was missing)")
	assert_eq(route.points().back(), _centre(goal), "and ends on the goal's centre")
	assert_eq(route.stop_count(), (preview["stops"] as Array).size(), "one stop a season end")
	assert_eq(route.crossing_count(), (preview["crossings"] as Array).size(), "one mark a crossing")
	_scene.map_input().hover_changed.emit(ArmyFixture.NO_HEX)
	assert_eq(_armies().route_marks().points().size(), 0, "off the map the route is the cursor's: the army's own hex has no march")


func test_clearing_the_army_empties_its_reach_and_cursor_and_says_so() -> void:
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	_armies().sync()
	assert_true(_armies().select_army(id))
	var army_cleared: Array[bool] = []
	_armies().army_cleared.connect(func() -> void: army_cleared.append(true))
	_armies().clear_army()
	assert_eq(_armies().reach_count(MapArmies.REACH_LAYER), 0, "the reach goes with the selection")
	assert_eq(_armies().reach_count(MapArmies.REACH_NEXT_LAYER), 0)
	assert_eq(army_cleared.size(), 1, "army_cleared said")
	assert_eq(_armies().cursor_hex(), MapScene.NO_HEX, "no cursor without an army")


func test_a_march_in_progress_keeps_its_stored_route_as_a_thin_line() -> void:
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	# moves in the month: with no move points left the march is stored as a standing march instead of walking at once.
	Armies.set_points(_game, Armies.by_id(_game, id), 0)
	_game.version += 1
	_armies().sync()
	assert_true(_armies().select_army(id))
	var goal := _goal_near(hex, id)
	assert_ne(goal, ArmyFixture.NO_HEX)
	_scene._on_command_requested(_centre(goal))
	assert_eq((ArmyView.panel(_game, ArmyFixture.TAG, id)["order"] as Dictionary)["kind"], Army.ORDER_MARCH)
	_armies().move_cursor(MapInput.CURSOR_LEFT)
	var stored := MovePreview.stored(_game, ArmyFixture.TAG, id)
	var hexes := stored["hexes"] as Array
	assert_gt(hexes.size(), 0, "the march's route is stored")
	assert_eq(hexes.back(), goal, "the stored route ends at the goal")
	assert_eq(_armies().stored_marks().points().size(), hexes.size() + 1, "the thin line has a point a hex and the army's own hex")
	assert_eq(_armies().stored_marks().points()[0], _centre(hex), "and starts on the army's own hex")
	assert_eq(_armies().stored_marks().points().back(), _centre(goal), "and ends on the goal's centre")
	_armies().move_cursor(MapInput.CURSOR_RIGHT)
	assert_eq(_armies().stored_marks().points().size(), 0, "back on the goal the stored line is not drawn twice")


func test_the_stored_route_is_empty_for_an_army_that_is_not_marching() -> void:
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	assert_eq((MovePreview.stored(_game, ArmyFixture.TAG, id)["hexes"] as Array).size(), 0)


func test_the_selection_is_announced_on_the_events_bus() -> void:
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	_armies().sync()
	var selected: Array[int] = []
	var cleared: Array[int] = []
	var on_selected := func(army_id: int) -> void: selected.append(army_id)
	var on_cleared := func() -> void: cleared.append(1)
	Events.army_selected.connect(on_selected)
	Events.army_cleared.connect(on_cleared)
	assert_true(_armies().select_army(id))
	assert_eq(selected, [id], "Events.army_selected carries the army's id")
	_armies().clear_army()
	assert_eq(cleared.size(), 1, "Events.army_cleared once the army is cleared")
	_armies().clear_army()
	assert_eq(cleared.size(), 1, "and not again when nothing is selected")
	Events.army_selected.disconnect(on_selected)
	Events.army_cleared.disconnect(on_cleared)


func test_an_army_event_refreshes_the_sight_texture() -> void:
	var far := ArmyFixture.NO_HEX
	for i: int in _game.map.hex_count():
		var h := _game.map.hex_of(i)
		if _game.map.is_land(h) and not Knowledge.sees(_game, ArmyFixture.TAG, h):
			far = h
			break
	assert_ne(far, ArmyFixture.NO_HEX, "a land hex in the fog")
	var before := _scene.overlay().sight_bytes().duplicate()
	var a := ArmyFixture.army(_game, ArmyFixture.TAG, far, 0, 2)
	_game.version += 1
	Sight.refresh(_game)
	Events.army_raised.emit(ArmyFixture.TAG, far, a.id)
	await get_tree().process_frame
	assert_eq(_scene.overlay().sight_bytes(), MapModes.sight_bytes(_game, ArmyFixture.TAG), "the sight texture follows the army")
	assert_ne(_scene.overlay().sight_bytes(), before, "the army's sight changed the texture")


func test_the_game_ending_clears_the_army_selection() -> void:
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	_armies().sync()
	assert_true(_armies().select_army(id))
	Session.end_game()
	await get_tree().process_frame
	assert_eq(_armies().selected_army(), -1, "no army is selected with no game")
	assert_eq(_armies().tokens().token_count(), 0, "and no token stands")


func test_a_hex_selected_on_the_army_cursor_takes_the_selection_ring_and_the_army_lets_go() -> void:
	var hex := ArmyFixture.find_town(_game)
	var id := _army(hex, 2).id
	_armies().sync()
	assert_true(_armies().select_army(id))
	# Another path selects the same hex the cursor stands on (a search, a bookmark): the ring is the selection's.
	_scene.select_hex(hex)
	assert_eq(_armies().selected_army(), -1, "selecting a hex lets the army go")
	assert_ne(_scene.view().layer("marks").get_cell_source_id(hex), -1, "the selection ring stays on the hex")
	# And the other way: the cursor's old hex is cleared when a hex elsewhere is selected.
	var other := ArmyFixture.NO_HEX
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if _game.map.has(beside):
			other = beside
			break
	assert_true(_armies().select_army(id))
	_scene.select_hex(other)
	assert_eq(_armies().selected_army(), -1)
	assert_eq(_scene.view().layer("marks").get_cell_source_id(hex), -1, "the old cursor mark is gone")
	assert_ne(_scene.view().layer("marks").get_cell_source_id(other), -1, "the new selection ring is up")
