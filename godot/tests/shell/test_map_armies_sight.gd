## The map's army tokens follow the player's sight, not only the army events (fog-build-spec 3.4, R23; FG18 leak): a foreign army that
## leaves the player's sight with no army event of its own (the vision phase refreshes the sight after its move) loses its token on
## the next frame, and one that comes into sight gets one. A token never stands on a hex the viewer cannot see.
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


## The first land hex the player does not see (no army of the player's, no land of the player's around it); NO_HEX when none.
func _unseen_land_hex() -> Vector2i:
	for i: int in _game.map.hex_count():
		var hex := _game.map.hex_of(i)
		if _game.map.is_land(hex) and not Knowledge.sees(_game, ArmyFixture.TAG, hex):
			return hex
	return ArmyFixture.NO_HEX


## The first land hex of another country that the player sees; NO_HEX when none.
func _seen_foreign_hex() -> Vector2i:
	for i: int in _game.map.hex_count():
		var hex := _game.map.hex_of(i)
		if _game.map.is_land(hex) and Knowledge.sees(_game, ArmyFixture.TAG, hex) and Territory.owner_tag(_game, hex) != ArmyFixture.TAG:
			return hex
	return ArmyFixture.NO_HEX


func test_a_foreign_army_that_leaves_sight_loses_its_token_with_no_army_event() -> void:
	var own := _seen_foreign_hex()
	var foreign := ArmyFixture.other_tag(_game)
	assert_ne(own, ArmyFixture.NO_HEX, "a hex of another country the player sees")
	var army := ArmyFixture.army(_game, foreign, own, 0, 2, -1)
	Sight.refresh(_game)  # the vision phase sees the army (no army event in a fixture)
	_game.version += 1
	_armies()._process(0.0)  # one frame of the map (its sync reads the sight)
	assert_not_null(_armies().tokens().token_at(own, foreign), "a foreign army in the player's sight has a token")
	var away := _unseen_land_hex()
	assert_ne(away, ArmyFixture.NO_HEX, "a hex the player does not see")
	army.hex = away
	Sight.refresh(_game)  # the vision phase's refresh after the move: the army's own event is not emitted here
	_game.version += 1
	_armies()._process(0.0)  # one frame of the map (its sync reads the sight)
	assert_null(_armies().tokens().token_at(own, foreign), "its token goes when it leaves sight, with no army event")
	assert_null(_armies().tokens().token_at(away, foreign), "and no token shows where it went out of sight")


func test_a_token_is_not_listed_for_a_hex_the_viewer_cannot_see_after_a_sight_refresh() -> void:
	var foreign := ArmyFixture.other_tag(_game)
	var away := _unseen_land_hex()
	assert_ne(away, ArmyFixture.NO_HEX, "a hex the player does not see")
	ArmyFixture.army(_game, foreign, away, 0, 2, -1)
	Sight.refresh(_game)
	_game.version += 1
	_armies()._process(0.0)  # one frame of the map (its sync reads the sight)
	assert_null(_armies().tokens().token_at(away, foreign), "an army out of sight has no token (R23)")


func test_a_foreign_walk_that_ends_out_of_sight_keeps_no_token() -> void:
	# The replay walk-end case (FG19): a foreign army in sight starts walking, and its walk ends on a hex out of sight with no
	# army event of its own. The frames of the walk, and the frame after, leave no token at the start or at the end.
	var start := _seen_foreign_hex()
	var foreign := ArmyFixture.other_tag(_game)
	assert_ne(start, ArmyFixture.NO_HEX, "a hex of another country the player sees")
	var army := ArmyFixture.army(_game, foreign, start, 0, 2, -1)
	Sight.refresh(_game)
	_game.version += 1
	_armies()._process(0.0)
	assert_not_null(_armies().tokens().token_at(start, foreign), "the army starts in sight with a token")
	var end := _unseen_land_hex()
	assert_ne(end, ArmyFixture.NO_HEX, "a hex the player does not see")
	army.hex = end
	Sight.refresh(_game)
	_game.version += 1
	for _i: int in 3:
		_armies()._process(0.1)  # the walk's frames
	assert_null(_armies().tokens().token_at(end, foreign), "a walk that ends out of sight leaves no token at its end")
	assert_null(_armies().tokens().token_at(start, foreign), "and none where it started")


## The lag is one frame at most: a foreign army that leaves sight loses its token at the next frame of the map (one _process), so a
## check made two frames after a change reads the map as it is (a lag of a frame is not a leak; FG18 issue 457 round).
func test_a_token_is_gone_within_one_frame_of_a_sight_change() -> void:
	var own := _seen_foreign_hex()
	assert_ne(own, ArmyFixture.NO_HEX, "a hex of another country the player sees")
	var foreign := ArmyFixture.other_tag(_game)
	var army := ArmyFixture.army(_game, foreign, own, 0, 2, -1)
	Sight.refresh(_game)
	_game.version += 1
	_armies()._process(0.0)
	assert_not_null(_armies().tokens().token_at(own, foreign), "the token is there while the army is in sight")
	army.hex = _unseen_land_hex()
	Sight.refresh(_game)
	_game.version += 1
	_armies()._process(0.0)
	assert_null(_armies().tokens().token_at(own, foreign), "gone after one frame of the map, not later")
