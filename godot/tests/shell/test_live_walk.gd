## The live walk (docs/architecture/moves-build-spec.md R49, D19, R50): the walk of the player's own act is one batch that
## MoveReplay plays from the next frame on its own plan, lands on the hexes the core holds, never changes the game and is
## ended by its clock or skip_live(); instant plays nothing; the camera follows the walker; the player's live walks are not in
## the season's replay; no order is refused because a live walk runs. The clock is MoveReplay._process called with a set delta.
extends GutTest

var _game: Game = null
var _scene: MapScene = null
var _replay: MoveReplay = null
var _army: Army = null
var _hex := Vector2i.ZERO
var _goal := Vector2i.ZERO
var _finished: Array[int] = []
var _followed: Array[Vector2i] = []


func before_each() -> void:
	_finished = []
	_followed = []
	Session.start_game(ArmyFixture.game())
	_game = Session.game
	_hex = ArmyFixture.find_town(_game)
	_goal = _game.map.neighbour(_hex, 0)
	_army = ArmyFixture.army(_game, ArmyFixture.TAG, _hex, 0, 2, _game.turn - 1)
	_game.version += 1
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_replay = MoveReplay.new()
	add_child_autofree(_replay)
	_replay.bind(_armies().tokens(), func(hex: Vector2i) -> void: _followed.append(hex))
	_replay.live_finished.connect(func(record: int) -> void: _finished.append(record))


func after_each() -> void:
	Session.end_game()


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


func _tokens() -> ArmyTokens:
	return _armies().tokens()


## The player's order: the army marches to the goal and walks at once in the act (the drain brings the walk to MoveReplay).
func _march() -> void:
	var verdict := Session.act("march", {"army": _army.id, "goal": _goal})
	assert_true(bool(verdict.get("ok", false)), "the march is ordered: %s" % str(verdict.get("reason", "")))
	_armies().sync()


func test_the_walk_of_an_order_plays_live_from_the_next_frame_and_lands_on_the_core_hex() -> void:
	_march()
	assert_eq(_army.hex, _goal, "the game holds the end the moment the order is given")
	assert_true(_replay.live_active(), "the batch waits for its first frame")
	assert_false(_replay.active(), "a live walk is not the season replay")
	assert_eq(_tokens().walker_count(), 0, "nothing is drawn before the frame")
	_replay._process(0.0)
	assert_eq(_replay.poses().size(), 1, "the walk is on its plan")
	_replay._process(0.1)
	var pose := _replay.poses()[0]
	assert_eq(pose["from"], _hex)
	assert_eq(pose["to"], _goal)
	assert_almost_eq(float(pose["t"]), 0.5, 0.01, "halfway along the step")
	assert_eq(_tokens().walker_count(), 1, "one walker stands in for the army")
	assert_true(_replay.live_active())
	_replay._process(1.0)
	assert_false(_replay.live_active(), "the clock ran out")
	assert_eq(_finished, [-1], "live_finished once, with no battle record")
	assert_eq(_tokens().walker_count(), 0)
	assert_true(_tokens().token_at(_goal, ArmyFixture.TAG).visible, "the token stands on the goal again")
	assert_eq(_army.hex, _goal)


func test_a_live_walk_never_changes_the_digest_or_the_version() -> void:
	_march()
	var digest := _game.digest()
	var version := _game.version
	for i: int in 12:
		_replay._process(0.05)
		assert_eq(_game.digest(), digest, "P: a frame of the live walk changed the game")
		assert_eq(_game.version, version, "P: a frame of the live walk changed the version")
	assert_true(_replay.skip_live() or not _replay.live_active())
	assert_eq(_game.digest(), digest, "P: the skip changed the game")
	assert_eq(_game.version, version)


func test_skip_lands_the_tokens_and_ends_the_walk_once() -> void:
	_march()
	_replay._process(0.0)
	assert_true(_replay.skip_live(), "skip ends the running live walk")
	assert_eq(_finished, [-1], "live_finished once, by the skip")
	assert_false(_replay.live_active())
	assert_eq(_tokens().walker_count(), 0)
	assert_eq(_army.hex, _goal)
	assert_false(_replay.skip_live(), "a second skip finds nothing")
	assert_eq(_finished.size(), 1)


func test_a_batch_skipped_before_its_first_frame_is_dropped_and_finishes() -> void:
	_march()
	assert_true(_replay.live_active())
	assert_true(_replay.skip_live(), "a batch that has not begun is skipped too")
	assert_eq(_finished, [-1])
	_replay._process(0.1)
	assert_eq(_tokens().walker_count(), 0, "nothing plays after the skip")
	assert_false(_replay.live_active())


func test_instant_plays_nothing() -> void:
	_replay.live_speed = func() -> StringName: return MoveReplay.INSTANT
	_march()
	assert_false(_replay.live_active(), "P: instant (and reduce motion) plays no live walk")
	_replay._process(0.1)
	assert_eq(_tokens().walker_count(), 0)
	assert_true(_finished.is_empty(), "a walk that was never played does not finish")
	assert_true(_tokens().token_at(_goal, ArmyFixture.TAG).visible, "the token is on the goal at once")


func test_the_slow_speed_is_the_live_walks_speed() -> void:
	_replay.live_speed = func() -> StringName: return &"slow"
	_march()
	_replay._process(0.0)
	_replay._process(0.1)
	assert_almost_eq(float(_replay.poses()[0]["t"]), 0.2, 0.01, "slow: 0.5 s a step")


func test_the_camera_follows_the_live_walker() -> void:
	_march()
	_replay._process(0.0)
	assert_eq(_followed, [_goal], "the camera is asked to follow the walker's hex")


func test_no_order_is_refused_because_a_live_walk_runs() -> void:
	_march()
	_replay._process(0.0)
	assert_true(_replay.live_active())
	var verdict := Session.act("halt", {"army": _army.id})
	assert_true(bool(verdict.get("ok", false)) or str(verdict.get("reason", "")) != Session.WAIT_TEXT,
		"P: an order refused during a live walk")
	assert_false(Session.in_season())


func test_an_army_order_while_a_walk_plays_lands_it() -> void:
	_march()
	_replay._process(0.0)
	assert_true(_replay.live_active())
	Events.army_changed.emit(ArmyFixture.TAG, _army.id)  # what a panel's order (halt, refill, split) drains
	assert_false(_replay.live_active(), "the order from a panel ends the walk")
	assert_eq(_finished, [-1])
	assert_eq(_tokens().walker_count(), 0)


func test_the_army_changed_of_the_walks_own_act_leaves_the_batch_waiting() -> void:
	_march()  # the act drains unit_moved and then army_changed (R19)
	assert_true(_replay.live_active(), "the batch is still waiting for its frame")
	assert_true(_finished.is_empty())


func test_a_second_act_lands_the_first_walk_and_plays_its_own() -> void:
	_march()
	_replay._process(0.0)
	var back := _hex
	var verdict := Session.act("march", {"army": _army.id, "goal": back})
	assert_true(bool(verdict.get("ok", false)), "a second march is ordered during the first walk: %s" % str(verdict.get("reason", "")))
	assert_eq(_finished, [-1], "the first walk landed when the second act came")
	assert_true(_replay.live_active(), "the second walk is waiting for its frame")
	_replay._process(0.0)
	assert_eq(_replay.poses().size(), 1)


func test_the_players_live_walk_is_not_in_the_season_replay() -> void:
	_march()
	_replay._process(0.0)
	_replay.skip_live()
	assert_true(bool(Session.end_season().get("ok", false)), "the season ends")
	assert_false(_replay.start(&"normal"), "P: a player's walk played twice (the season replay has nothing of it)")
	assert_false(_replay.active())


func test_a_live_walk_pending_when_the_season_ends_is_not_in_it_either() -> void:
	_march()
	assert_true(bool(Session.end_season().get("ok", false)), "the season ends over the waiting batch")
	assert_false(_replay.start(&"normal"), "P: the batch is the act's, not the season's")


func test_a_new_game_cancels_a_live_walk_without_finishing_it() -> void:
	_march()
	_replay._process(0.0)
	Session.start_game(ArmyFixture.game())
	assert_false(_replay.live_active())
	assert_true(_finished.is_empty(), "cancel does not emit live_finished")
	assert_eq(_tokens().walker_count(), 0)


func test_a_walk_the_viewer_never_saw_is_not_played() -> void:
	var path: Array[Vector2i] = [_hex, _goal]
	Events.unit_moved.emit(&"SAV", 90, path, PackedByteArray([0, 0]), PackedInt32Array([1]), true)
	assert_false(_replay.live_active(), "nothing seen: nothing kept")


func test_a_walk_during_a_season_goes_to_the_season_not_to_the_live_batch() -> void:
	assert_true(bool(Session.begin_season().get("ok", false)))
	var path: Array[Vector2i] = [_hex, _goal]
	Events.unit_moved.emit(&"SAV", 91, path, PackedByteArray([1, 1]), PackedInt32Array([1]), true)
	assert_false(_replay.live_active(), "a walk that arrives while the season runs is not live")
	Session.step_orders(INF)
	Session.finish_season()
	assert_true(_replay.start(&"normal"), "it is the season replay's")
	assert_true(_replay.active())
	assert_false(_replay.skip_live(), "skip_live leaves a season replay alone")
	assert_true(_replay.active())
