## An army selected on the map that leaves the game with no event of its own (a battle or a merge in the computer's turn) is
## deselected on the next frame, not at the next army event (map_armies.gd _process). Split from test_map_armies.gd.
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


func test_a_selected_army_that_leaves_the_game_without_an_event_is_deselected_on_the_next_frame() -> void:
	var hex := ArmyFixture.find_town(_game)
	var army := ArmyFixture.army(_game, ArmyFixture.TAG, hex, 0, 2)
	_game.version += 1
	_armies().sync()
	assert_true(_armies().select_army(army.id), "the player's army can be selected")
	assert_eq(_armies().selected_army(), army.id, "the army is selected")

	# No event: the army is removed straight from the game's list (a battle or a merge of the computer's turn).
	_game.armies.erase(army)
	_game.version += 1
	# process_frame fires before the nodes' _process of the same frame: the map's clear runs in the second frame.
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_armies().selected_army(), -1, "a selection whose army is gone is cleared on the next frame")
	assert_null(Armies.by_id(_game, army.id), "the army is gone from the game")
