## The order toasts of the map's armies (docs/architecture/m6-build-spec.md 6.10; L20; moves-build-spec.md R52): a march ordered,
## a hold, a march on (R), and the refusals and "no army" cases the spec and the armies give. Each action says its words once,
## on `said` (the App's toast; a march's and a Continue's words and tone are MoveWords', of the walk) or, for a refusal, on
## `refused` (warn); a refusal changes nothing.
extends GutTest

var _game: Game = null
var _scene: MapScene = null
var _said: Array = []
var _reasons: Array[String] = []


func before_each() -> void:
	_game = ArmyFixture.game()
	Session.start_game(_game)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_said.clear()
	_reasons.clear()
	_armies().said.connect(func(text: String, tone: StringName) -> void: _said.append([text, tone]))
	_scene.refused.connect(func(reason: String) -> void: _reasons.append(reason))


func after_each() -> void:
	Session.end_game()


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


func _army(hex: Vector2i) -> int:
	var a := ArmyFixture.army(_game, ArmyFixture.TAG, hex, 0, 2)
	_game.version += 1
	_armies().sync()
	return a.id


func _goal_where(origin: Vector2i, army_id: int, want: Callable) -> Vector2i:
	for dq: int in range(-4, 5):
		for dr: int in range(-4, 5):
			var h := origin + Vector2i(dq, dr)
			if h == origin or not _game.map.has(h):
				continue
			if bool(want.call(MovePreview.to(_game, ArmyFixture.TAG, army_id, h))):
				return h
	return ArmyFixture.NO_HEX


func _plain(p: Dictionary) -> bool:
	return bool(p["verdict"]["ok"]) and p["kind"] == &"go" and int(p["seasons"]) == 1


func _long(p: Dictionary) -> bool:
	return bool(p["verdict"]["ok"]) and int(p["seasons"]) > 1


func _refused(p: Dictionary) -> bool:
	return p["kind"] == &"refusal"


func _name_of(id: int) -> String:
	return str(ArmyView.panel(_game, ArmyFixture.TAG, id)["name"])


## moves in the month: the march walks in the order, so the toast says what the walk did (was "marches to ...: there in ...").
func test_a_march_ordered_says_once_where_it_walked_and_what_is_left() -> void:
	var origin := ArmyFixture.find_town(_game)
	var id := _army(origin)
	assert_true(_armies().select_army(id))
	var goal := _goal_where(origin, id, _plain)
	assert_ne(goal, ArmyFixture.NO_HEX, "a one-season goal exists")
	_armies().command(goal)
	var a := Armies.by_id(_game, id)
	assert_eq(a.hex, goal, "walked in the order")
	assert_eq(_said.size(), 1, "one toast for one order")
	assert_eq(_said[0][0], "The %s walks to %s: %d of %d move points left." % [_name_of(id), Words.place(_game, goal),
		a.points, Allowance.full(_game, a)], "the walk's words")
	assert_eq(_said[0][1], MovePreview.TONE_PLAIN, "a plain toast")
	assert_eq(_reasons.size(), 0, "and no refusal")


## moves in the month: a long march walks this season's leg and says the rest stands.
func test_a_long_march_says_it_walks_and_marches_on() -> void:
	var origin := ArmyFixture.find_town(_game)
	var id := _army(origin)
	assert_true(_armies().select_army(id))
	var goal := _goal_where(origin, id, _long)
	assert_ne(goal, ArmyFixture.NO_HEX, "a march of more than one season exists")
	_armies().command(goal)
	var a := Armies.by_id(_game, id)
	assert_ne(a.hex, origin, "the first leg walked in the order")
	assert_eq(_said.size(), 1)
	assert_eq(_said[0][0], "The %s walks to %s; it marches on to %s at End turn." % [_name_of(id),
		Words.place(_game, a.hex), Words.place(_game, goal)])


## moves in the month: with no move points left the order is kept, and the toast says when it sets out.
func test_a_march_with_no_points_left_says_it_sets_out() -> void:
	var origin := ArmyFixture.find_town(_game)
	var id := _army(origin)
	assert_true(_armies().select_army(id))
	var goal := _goal_where(origin, id, _plain)
	Armies.set_points(_game, Armies.by_id(_game, id), 0)
	_game.version += 1
	_armies().command(goal)
	assert_eq(Armies.by_id(_game, id).hex, origin, "nothing walked")
	assert_eq(_said.back()[0], "The %s sets out for %s at End turn." % [_name_of(id), Words.place(_game, goal)])


func test_a_hold_on_the_army_hex_says_it_holds_once() -> void:
	var origin := ArmyFixture.find_town(_game)
	var id := _army(origin)
	assert_true(_armies().select_army(id))
	_armies().command(origin)
	assert_eq(_said.size(), 1)
	assert_eq(_said[0][0], "The %s holds at %s." % [_name_of(id), Words.place(_game, origin)])


func test_a_refused_order_says_its_reason_once_and_no_toast() -> void:
	var origin := ArmyFixture.find_town(_game)
	var id := _army(origin)
	assert_true(_armies().select_army(id))
	var goal := _goal_where(origin, id, _refused)
	assert_ne(goal, ArmyFixture.NO_HEX, "a refused goal exists")
	var before := Session.unsaved_actions
	_armies().command(goal)
	assert_eq(_said.size(), 0, "no order toast")
	assert_eq(_reasons.size(), 1, "the refusal said once")
	assert_eq(_reasons[0], str((MovePreview.to(_game, ArmyFixture.TAG, id, goal)["verdict"] as Dictionary)["reason"]))
	assert_eq(Session.unsaved_actions, before, "and nothing changed")


## moves in the month: R on a halted march walks at once and says where (was "marches on to ...").
func test_r_on_a_halted_march_walks_at_once_and_says_so_once() -> void:
	var origin := ArmyFixture.find_town(_game)
	var id := _army(origin)
	assert_true(_armies().select_army(id))
	var goal := _goal_where(origin, id, _long)
	assert_ne(goal, ArmyFixture.NO_HEX, "a march of more than one season exists")
	assert_true(MovesFixture.standing(_game, Armies.by_id(_game, id), goal))
	assert_true(Session.act("halt", {"army": id}).get("ok", false), "the march is halted")
	_said.clear()
	assert_true(_armies().continue_march())
	var a := Armies.by_id(_game, id)
	assert_ne(a.hex, origin, "the march walks at once")
	assert_eq(_said.size(), 1, "one toast for R")
	assert_eq(_said[0][0], "The %s walks to %s; it marches on to %s at End turn." % [_name_of(id),
		Words.place(_game, a.hex), Words.place(_game, goal)])


func test_tab_with_no_army_and_r_without_one_are_said_and_change_nothing() -> void:
	assert_false(_armies().next_army())
	assert_eq(_reasons.back(), "You have no army.", "Tab with no army")
	assert_false(_armies().continue_march())
	assert_eq(_reasons.back(), "Select an army first.", "R with no army")
	assert_eq(_said.size(), 0, "no order toast for either")
