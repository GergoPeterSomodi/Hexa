## MoveReplay's battle marks (docs/architecture/m7-build-spec.md 6.5, B20): a battle heard during the season (battle_started, from
## the walk that ends on its hex) gets its tick at start() and a mark while the replay runs; a battle with no walk on its hex is
## left out; a cancel drops the battles heard. The viewer sees the battle through no battle site here, so its mark is hidden.
## The walks are a real season's (ArmyFixture), as in test_move_replay.
extends GutTest

var _game: Game = null
var _scene: MapScene = null
var _replay: MoveReplay = null
var _army: Army = null
var _hex := Vector2i.ZERO
var _goal := Vector2i.ZERO


func before_each() -> void:
	Session.start_game(ArmyFixture.game())
	_game = Session.game
	_hex = ArmyFixture.find_town(_game)
	_goal = _game.map.neighbour(_hex, 0)
	_army = ArmyFixture.army(_game, ArmyFixture.TAG, _hex, 0, 2, _game.turn - 1)
	assert_true(bool(Movement.march(_game, {"army": _army.id, "goal": _goal, "tag": ArmyFixture.TAG}).ok), "the march is ordered")
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_replay = MoveReplay.new()
	add_child_autofree(_replay)
	_replay.bind((_scene.get_node("MapArmies") as MapArmies).tokens(), Callable())


func after_each() -> void:
	Session.end_game()


## Ends the season through Session (the walks and the battle events reach MoveReplay through Events).
func _season() -> void:
	assert_eq(Session.end_season().get("ok", false), true, "the season ends")


## Plays the replay in small steps until a mark shows, at most 40 steps; returns the marks it found.
func _play_until_mark() -> Array[Dictionary]:
	for i: int in 40:
		_replay._process(0.05)
		var marks := _replay.marks()
		if not marks.is_empty():
			return marks
	return []


func test_a_battle_on_the_walks_goal_is_marked_during_the_replay() -> void:
	Events.battle_started.emit(_goal, ArmyFixture.TAG, &"SAV")
	_season()
	assert_true(_replay.start(&"normal"), "the replay runs")
	var marks := _play_until_mark()
	assert_eq(marks.size(), 1, "one battle mark once its tick begins")
	assert_eq(marks[0]["hex"], _goal, "the mark is on the battle hex")
	assert_false(bool(marks[0]["shown"]), "no battle site for the viewer: the mark stays hidden")


func test_a_battle_with_no_walk_on_its_hex_is_not_marked() -> void:
	var far := _game.map.neighbour(_goal, 3)
	Events.battle_started.emit(far, ArmyFixture.TAG, &"SAV")
	_season()
	assert_true(_replay.start(&"normal"))
	assert_eq(_play_until_mark().size(), 0, "no walk ends there: no tick, no mark")


func test_a_cancel_drops_the_battles_heard() -> void:
	Events.battle_started.emit(_goal, ArmyFixture.TAG, &"SAV")
	_replay.cancel()
	_season()
	assert_true(_replay.start(&"normal"))
	assert_eq(_play_until_mark().size(), 0, "the battle heard before the cancel is gone")


func test_marks_are_empty_with_no_replay() -> void:
	assert_eq(_replay.marks().size(), 0, "nothing runs, nothing is marked")
