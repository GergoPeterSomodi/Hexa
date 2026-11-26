## The movement replay on the map (docs/architecture/m6-build-spec.md 6.4; task L15): a season's walks are recorded from
## Events.unit_moved, played on a fake clock (MoveReplay._process called with a set delta) and end on the core's hexes; the
## instant setting applies at once; skip lands on the final state; a new game cancels; the core is never changed; an unseen
## walk is not recorded. Walkers and tokens are checked on the real map scene.
extends GutTest

var _game: Game = null
var _scene: MapScene = null
var _replay: MoveReplay = null
var _army: Army = null
var _hex := Vector2i.ZERO
var _goal := Vector2i.ZERO
var _finished := 0


func before_each() -> void:
	_finished = 0
	Session.start_game(ArmyFixture.game())
	_game = Session.game
	_hex = ArmyFixture.find_town(_game)
	_goal = _game.map.neighbour(_hex, 0)
	_army = ArmyFixture.army(_game, ArmyFixture.TAG, _hex, 0, 2, _game.turn - 1)
	# A standing march (the movement phase walks it: MV8 plays the walks of an act live, so a march ordered through the door
	# would not be in the season's replay).
	Armies.set_order(_game, _army, Army.ORDER_MARCH, _goal, PackedInt32Array([_game.map.index_of(_goal)]))
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_replay = MoveReplay.new()
	add_child_autofree(_replay)
	_replay.bind(_armies().tokens(), Callable())
	_replay.finished.connect(_on_finished)


func after_each() -> void:
	Session.end_game()


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


func _tokens() -> ArmyTokens:
	return _armies().tokens()


func _on_finished() -> void:
	_finished += 1


## Ends the season through Session (the walks reach MoveReplay through Events.unit_moved) and syncs the map.
func _season() -> void:
	assert_eq(Session.end_season().get("ok", false), true, "the season ends")
	_armies().sync()


func test_a_normal_replay_walks_the_army_and_lands_on_the_core_hex() -> void:
	_season()
	assert_eq(_army.hex, _goal, "the core has the army on the goal after the season")
	assert_true(_replay.start(&"normal"), "the walk is shown")
	assert_true(_replay.active())
	_replay._process(0.1)
	var pose := _replay.poses()[0]
	assert_eq(pose["from"], _hex, "the walker starts on the hex it marched from")
	assert_eq(pose["to"], _goal)
	assert_almost_eq(float(pose["t"]), 0.5, 0.01, "halfway along the step on the fake clock")
	assert_eq(_tokens().walker_count(), 1, "one walker stands in for the army")
	assert_false(_tokens().token_at(_goal, ArmyFixture.TAG).visible, "its token is hidden while it walks")
	_replay._process(1.0)
	assert_false(_replay.active(), "the clock ran out")
	assert_eq(_finished, 1, "finished is emitted once")
	assert_eq(_tokens().walker_count(), 0, "the walker is gone")
	assert_true(_tokens().token_at(_goal, ArmyFixture.TAG).visible, "the token stands on the goal again")
	assert_eq(_army.hex, _goal, "the army is where the core put it")


func test_the_replay_never_changes_the_core() -> void:
	_season()
	var before := _game.digest()
	assert_true(_replay.start(&"slow"))
	for i: int in 20:
		_replay._process(0.1)
	assert_eq(_game.digest(), before, "every frame of the replay leaves the game's digest as it was")


func test_skip_lands_on_the_final_state_once() -> void:
	_season()
	assert_true(_replay.start(&"normal"))
	assert_true(_replay.skip(), "skip ends the running replay")
	assert_eq(_finished, 1, "finished once, by the skip")
	assert_false(_replay.active())
	assert_eq(_tokens().walker_count(), 0)
	assert_eq(_army.hex, _goal)
	assert_false(_replay.skip(), "a second skip finds nothing to skip")
	assert_eq(_finished, 1)


func test_instant_applies_the_result_at_once() -> void:
	_season()
	assert_false(_replay.start(&"instant"), "instant plays nothing")
	assert_false(_replay.active())
	assert_eq(_finished, 0)
	assert_true(_tokens().token_at(_goal, ArmyFixture.TAG).visible, "the token is on the goal at once")


func test_a_second_start_is_refused_while_one_runs() -> void:
	_season()
	assert_true(_replay.start(&"normal"))
	# A walk of a further season is kept and ready, but the running replay refuses to be replaced.
	var path: Array[Vector2i] = [_hex, _goal]
	_replay.record(ArmyFixture.TAG, 99, path, PackedByteArray([1, 1]), PackedInt32Array([1]))
	Events.season_ended.emit(2)
	assert_false(_replay.start(&"normal"), "a replay runs: no second one")
	assert_true(_replay.active())


func test_a_walk_the_viewer_never_saw_is_not_recorded() -> void:
	var path: Array[Vector2i] = [_hex, _goal]
	_replay.record(&"AUS", 7, path, PackedByteArray([0, 0]), PackedInt32Array([1]))
	Events.season_ended.emit(1)
	assert_false(_replay.start(&"normal"), "nothing was kept: nothing to show")
	assert_false(_replay.active())


func test_a_new_game_cancels_a_running_replay_without_finishing_it() -> void:
	_season()
	assert_true(_replay.start(&"normal"))
	Session.start_game(ArmyFixture.game())
	assert_false(_replay.active(), "the new game cancels the replay")
	assert_eq(_finished, 0, "cancel does not emit finished")
	assert_eq(_tokens().walker_count(), 0)


func test_a_cancelled_season_leaves_nothing_to_start() -> void:
	_season()
	Session.start_game(ArmyFixture.game())
	assert_false(_replay.start(&"normal"), "the walks of the old game are dropped with it")


func test_a_token_with_a_standing_army_shows_only_that_army_while_another_walks() -> void:
	var standing := ArmyFixture.army(_game, ArmyFixture.TAG, _goal, 0, 1, _game.turn - 1)
	_game.version += 1
	_season()
	var token := _tokens().token_at(_goal, ArmyFixture.TAG)
	assert_eq(token.armies.size(), 2, "the goal's token lists both armies once the walk has ended")
	assert_true(_replay.start(&"normal"))
	_replay._process(0.1)
	assert_true(token.visible, "the standing army keeps its token")
	assert_eq(Array(token.armies), [standing.id], "the walking army is not drawn twice")
	assert_eq(_tokens().walker_count(), 1)
	_replay._process(1.0)
	assert_eq(token.armies.size(), 2, "back to both armies when the walk ends")
	assert_eq(_tokens().walker_count(), 0)


func test_the_camera_follows_only_to_hexes_the_viewer_sees() -> void:
	var followed: Array[Vector2i] = []
	var replay := MoveReplay.new()
	add_child_autofree(replay)
	replay.bind(null, func(hex: Vector2i) -> void: followed.append(hex))
	# The walk ends on a hex the viewer does not see (far): its last step is instant and hidden, the camera never goes there.
	var far := Vector2i(40, 40)
	var path: Array[Vector2i] = [_hex, _goal, far]
	replay.record(ArmyFixture.TAG, 77, path, PackedByteArray([1, 1, 0]), PackedInt32Array([1, 2]))
	Events.season_ended.emit(3)
	assert_true(replay.start(&"normal"))
	for step: int in range(0, 50):
		replay._process(0.01)
	# The lead walker's seen end hex is the only one the camera goes to: the step into the unseen far hex is never followed.
	assert_eq(followed.size(), 1, "the camera follows the one seen end hex")
	assert_eq(followed[0], _goal)
	assert_false(followed.has(far), "P: no glide to the unseen hex")


func test_a_walk_into_an_unseen_hex_is_not_followed_there() -> void:
	var followed: Array[Vector2i] = []
	var replay := MoveReplay.new()
	add_child_autofree(replay)
	replay.bind(null, func(hex: Vector2i) -> void: followed.append(hex))
	var path: Array[Vector2i] = [_hex, _goal]
	replay.record(ArmyFixture.TAG, 78, path, PackedByteArray([0, 0]), PackedInt32Array([1]))
	Events.season_ended.emit(4)
	assert_false(replay.start(&"normal"), "P: nothing seen at either end: nothing to show, no follow")
	assert_true(followed.is_empty())


func test_the_selection_ring_stays_on_the_walker() -> void:
	_season()
	_tokens().set_selected(_army.id)
	assert_true(_replay.start(&"normal"))
	_replay._process(0.1)
	var walker := _tokens().walker(_army.id)
	assert_true(walker != null and walker.ringed(), "the selected army's walker is ringed")
	_tokens().set_selected(-1)
	assert_false(walker.ringed(), "the ring goes when the selection does")
	_replay._process(1.0)
	assert_null(_tokens().walker(_army.id), "the walker is gone at the end")


func test_show_poses_draws_an_army_the_tokens_do_not_list_and_clears() -> void:
	var poses: Array[Dictionary] = [{"army": 999, "tag": &"AUS", "from": _hex, "to": _goal, "t": 0.5, "shown": false}]
	_tokens().show_poses(poses)
	assert_eq(_tokens().walker_count(), 1, "a walker is made from the pose alone")
	_tokens().show_poses([])
	assert_eq(_tokens().walker_count(), 0, "an empty list takes the walkers away")


## D37: the focus (the hexes on screen at the start) times a seen step only when one of its hexes is in it.
func test_a_seen_step_outside_the_focus_plays_instantly() -> void:
	_season()
	var away := Rect2i(Vector2i(900, 900), Vector2i(2, 2))
	assert_false(_replay.start(&"normal", away), "the one seen step is out of view: instant, nothing to play")
	assert_false(_replay.active(), "no replay runs")
	assert_eq(_finished, 0, "no replay, so no finished")
	assert_eq(_army.hex, _goal, "the core is where the season put the army")


func test_a_seen_step_inside_the_focus_is_timed() -> void:
	_season()
	var near := Rect2i(_hex, Vector2i(1, 1))
	assert_true(_replay.start(&"normal", near), "the step starts from a hex in view: it is timed")
	_replay._process(0.1)
	assert_eq(_replay.poses().size(), 1, "the walker is on the clock")


## R50: two at-once walks of the season (the computer's orders) are played one after another, not on the same ticks.
func test_two_at_once_walks_of_a_season_play_one_after_another() -> void:
	var far := _game.map.neighbour(_goal, 0)
	var first: Array[Vector2i] = [_hex, _goal]
	var second: Array[Vector2i] = [far, _goal]
	Session.begin_season()
	_replay.record(&"SAV", 81, first, PackedByteArray([1, 1]), PackedInt32Array([1]), true)
	_replay.record(&"MIL", 82, second, PackedByteArray([1, 1]), PackedInt32Array([1]), true)
	Session.step_orders(INF)
	Session.finish_season()
	_replay._pending = _replay._pending.filter(func(r: Dictionary) -> bool: return int(r["army"]) >= 81)
	assert_true(_replay.start(&"normal"))
	_replay._process(0.1)
	var poses := _replay.poses()
	var by_army := {}
	for pose: Dictionary in poses:
		by_army[int(pose["army"])] = pose
	assert_almost_eq(float(by_army[81]["t"]), 0.5, 0.01, "the first walk is half way")
	assert_eq(by_army[82]["from"], by_army[82]["to"], "P: the second walk waits for the first (not on the same ticks)")
	_replay._process(0.2)
	assert_almost_eq(float((_replay.poses()[0] as Dictionary)["t"]), 0.5, 0.01, "then the second walks")
	_replay._process(1.0)
	assert_false(_replay.active())


## R49: a live walk and the season replay are separate: a live walk is no season replay, and skip() leaves it alone.
func test_a_live_walk_is_not_the_season_replay_and_skip_leaves_it_alone() -> void:
	var other := ArmyFixture.army(_game, ArmyFixture.TAG, _goal, 0, 1, _game.turn - 1)
	_game.version += 1
	var back := _game.map.neighbour(_hex, 1)
	var verdict := Session.act("march", {"army": other.id, "goal": back})
	assert_true(bool(verdict.get("ok", false)), "the live march is ordered: %s" % str(verdict.get("reason", "")))
	_replay._process(0.0)
	assert_true(_replay.live_active())
	assert_false(_replay.active(), "a live walk does not refuse orders: it is not the season replay")
	assert_false(_replay.skip(), "skip() is the season replay's")
	assert_true(_replay.live_active())
	assert_true(_replay.skip_live())
