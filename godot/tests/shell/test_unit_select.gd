## Units are clickable apart from their hex (issue #433; ui-and-controls-spec section 4): a click on a unit's token selects
## the unit before the hex under it, a click on the hex selects the hex (a unit on it or not), a stack takes its next army on
## each click, only the viewer's own visible tokens are units (no unseen one leaks through the hit test), the ring goes with
## the army, and the token's click area follows the zoom.
extends GutTest

var _game: Game = null
var _scene: MapScene = null


func before_each() -> void:
	_game = ArmyFixture.game()
	Session.start_game(_game)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()


func after_each() -> void:
	Session.end_game()


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


## An army of the player's on `hex`; the game's version moves so the view reads it (as an action does).
func _army(hex: Vector2i, count: int) -> Army:
	var a := ArmyFixture.army(_game, ArmyFixture.TAG, hex, 0, count)
	_game.version += 1
	return a


func _token(hex: Vector2i) -> ArmyToken:
	return _armies().tokens().token_at(hex, ArmyFixture.TAG)


func _hex_screen(hex: Vector2i) -> Vector2:
	return _scene.view().get_global_transform_with_canvas() * _scene.view().centre_of(hex)


## A point on the token's click area, 25 px above its foot.
func _token_screen(hex: Vector2i) -> Vector2:
	return _token(hex).get_global_transform_with_canvas() * Vector2(0.0, -25.0)


## The same point on the token of `tag` (a foreign army in sight has a token too: the fog build makes one for it).
func _tag_token_screen(hex: Vector2i, tag: StringName) -> Vector2:
	return _armies().tokens().token_at(hex, tag).get_global_transform_with_canvas() * Vector2(0.0, -25.0)


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


## A land neighbour of `hex` (the first one that is land), NO_HEX when none.
func _land_beside(hex: Vector2i) -> Vector2i:
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if _game.map.has(beside) and _game.map.is_land(beside):
			return beside
	return ArmyFixture.NO_HEX


func test_the_token_is_hit_before_the_hex_it_stands_on() -> void:
	var hex := ArmyFixture.find_town(_game)
	var army := _army(hex, 2)
	_armies().sync()
	var on_token := _token_screen(hex)
	assert_true(_token(hex).hit_screen(on_token), "the point is in the token's click area")
	assert_eq(_armies().tokens().own_token_at(on_token), _token(hex), "and the token is the unit there")
	_click(on_token)
	assert_eq(_armies().selected_army(), army.id, "a click on the token selects the unit")
	assert_eq(_scene.selected, MapScene.NO_HEX, "and not the hex under it")


func test_a_click_on_the_hex_selects_the_hex_even_with_a_unit_on_it() -> void:
	var hex := ArmyFixture.find_town(_game)
	_army(hex, 2)
	_armies().sync()
	assert_false(_token(hex).hit_screen(_hex_screen(hex)), "the hex's centre is below the token's click area")
	_click(_hex_screen(hex))
	assert_eq(_scene.selected, hex, "the click selects the hex")
	assert_eq(_armies().selected_army(), -1, "and no unit")
	var beside := _land_beside(hex)
	_click(_hex_screen(beside))
	assert_eq(_scene.selected, beside, "a click on a hex beside it selects that hex")


func test_a_stack_takes_its_next_army_on_each_click_and_its_ring_is_on_the_stack() -> void:
	var hex := ArmyFixture.find_town(_game)
	var ids: Array[int] = [_army(hex, 2).id, _army(hex, 2).id, _army(hex, 2).id]
	_armies().sync()
	var stack := _token(hex)
	assert_eq(stack.armies.size(), 3, "three armies make one stack token")
	var picked: Array[int] = []
	_armies().army_selected.connect(func(id: int) -> void: picked.append(id))
	for i: int in 4:
		_click(_token_screen(hex))
	assert_eq(picked, [ids[0], ids[1], ids[2], ids[0]], "each click takes the next army of the stack, round and round")
	assert_true(stack.ringed(), "the stack's ring is up while one of its armies is selected")
	_click(_hex_screen(hex))
	assert_eq(_armies().selected_army(), -1, "a click on the hex lets the army go")
	assert_false(stack.ringed(), "and the ring with it")


func test_an_unseen_foreign_unit_is_no_unit_and_a_seen_one_is_not_selected() -> void:
	var hex := _land_beside(ArmyFixture.find_town(_game))
	var other := ArmyFixture.other_tag(_game)
	var foreign := ArmyFixture.army(_game, other, hex, 0, 300)
	_game.version += 1
	_armies().sync()
	var seen := ArmyView.visible(_game, ArmyFixture.TAG, foreign)
	var token := _armies().tokens().token_at(hex, other)
	assert_eq(token != null, seen, "a token exists exactly when the viewer sees the army")
	# A seen foreign army has its token on the hex: the click goes to that token's area, which must still not pick it.
	var point := _tag_token_screen(hex, other) if token != null else _hex_screen(hex)
	assert_null(_armies().tokens().own_token_at(point), "a foreign token is never a unit to pick")
	_click(point)
	assert_eq(_armies().selected_army(), -1, "a click there does not select the foreign army")
	assert_eq(_scene.selected, hex, "it selects the hex")
	assert_false(_armies().select_army(foreign.id), "and the army cannot be selected as one of yours")


func test_the_ring_follows_the_unit_when_it_moves() -> void:
	var hex := ArmyFixture.find_town(_game)
	var army := _army(hex, 2)
	_armies().sync()
	_click(_token_screen(hex))
	assert_true(_token(hex).ringed(), "the ring is on the selected unit's token")
	var beside := _land_beside(hex)
	army.hex = beside
	_game.version += 1
	_armies().sync()
	assert_null(_token(hex), "the token left the old hex")
	assert_true(_token(beside).ringed(), "the ring moved with the unit")
	assert_eq(_armies().selected_army(), army.id, "the unit stays selected")


func test_the_click_area_follows_the_zoom() -> void:
	var hex := ArmyFixture.find_town(_game)
	_army(hex, 2)
	_armies().sync()
	for z: float in [0.3, 1.0, 2.0]:
		_scene.frame_at(_scene.view().centre_of(hex), z)
		var token := _token(hex)
		var on := token.get_global_transform_with_canvas() * Vector2(0.0, -25.0)
		var below := token.get_global_transform_with_canvas() * Vector2(0.0, 5.0)
		assert_true(token.hit_screen(on), "the click area is on the token at zoom %s" % z)
		assert_false(token.hit_screen(below), "and not below its foot at zoom %s" % z)
		_click(on)
		assert_ne(_armies().selected_army(), -1, "a click on the token selects its unit at zoom %s" % z)
		_armies().clear_army()


func test_a_unit_click_is_refused_during_a_replay_and_selects_nothing() -> void:
	var hex := ArmyFixture.find_town(_game)
	_army(hex, 2)
	_armies().sync()
	_scene.map_input().orders_blocked = func() -> bool: return true
	var blocked: Array[Vector2] = []
	_scene.map_input().blocked_click.connect(func(px: Vector2) -> void: blocked.append(px))
	_click(_token_screen(hex))
	assert_eq(_armies().selected_army(), -1, "no unit is picked while the moves play")
	assert_eq(blocked.size(), 1, "the click is said to be blocked")
	_scene.map_input().orders_blocked = Callable()
