## GUT tests for Session's sliced season (docs/architecture/m8-build-spec.md 5.6, D40): begin_season, step_orders,
## finish_season against end_season, a drain after each step, check and act refused in season, progress, passive seats, watch.
extends GutTest

const SCENARIO := "north_italy_1480"

var _prev_game: Game = null
var _prev_unsaved: int = 0
var _prev_defs: GameDefs = null
var _prev_origin: Dictionary = {}
var _prev_dir: String = ""
var _prev_ai: bool = true
var _dir: String = "user://test_saves_session_season"

## A hook of three steps that queues an event in each and notes how many events were waiting when the step began
## (a drain after every step leaves none).
class StepHook extends OrdersHook:
	var waiting: Array[int] = []
	var steps := 0

	func begin(_game: Game) -> void:
		steps = 0
		waiting = []

	func step(game: Game) -> bool:
		waiting.append(game.events.size())
		game.emit({"kind": "hex_changed", "hex": Vector2i(1, 1)})
		steps += 1
		return steps >= 3

	func seats() -> int:
		return 3

	func seats_done() -> int:
		return steps


func before_each() -> void:
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_prev_defs = Session._defs
	_prev_origin = Session._origin
	_prev_dir = Session.save_dir
	Session.save_dir = _dir
	_prev_ai = Session.ai_enabled
	Session.ai_enabled = false


func after_each() -> void:
	Session.ai_enabled = _prev_ai
	Session._passive = []
	Session._in_season = false
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Session._defs = _prev_defs
	Session._origin = _prev_origin
	Session.save_dir = _prev_dir
	DirAccess.remove_absolute(_dir.path_join("1.sav"))
	DirAccess.remove_absolute(_dir.path_join("1.bak"))
	DirAccess.remove_absolute(_dir)


func _player_build() -> Dictionary:
	var g := Session.game
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0:
			continue
		for option: Dictionary in Improve.build_options(g, hex):
			var args := {"hex": hex, "family": int(option["family_id"])}
			if bool(Session.check("build", args).get("ok", false)):
				return args
	return {}


func _whole(seed_value: int) -> Array:
	Session.new_scenario(SCENARIO, seed_value, &"GEN")
	Session.game.defs = EconomyFixture.defs()
	return [Session.end_season(), Session.game.digest(), JSON.stringify(Session.game.action_log)]


func test_begin_steps_and_finish_equal_end_season_with_the_ai_on() -> void:
	Session.ai_enabled = true
	var whole := _whole(5)
	assert_true(bool(whole[0]["ok"]))
	assert_not_null(Session.ai(), "a game with countries has the AI attached")
	assert_gt(Session.ai().seats_done(), 0, "the AI had seats")
	Session.new_scenario(SCENARIO, 5, &"GEN")
	Session.game.defs = EconomyFixture.defs()
	var ended: Array[int] = []
	var h := func(t: int) -> void: ended.append(t)
	Events.season_ended.connect(h)
	assert_true(bool(Session.begin_season()["ok"]))
	assert_true(Session.in_season())
	assert_eq(Session.orders_progress().x, 0)
	assert_gt(Session.orders_progress().y, 0)
	var guard := 0
	while not Session.step_orders(0.0) and guard < 100000:
		guard += 1
	assert_eq(Session.orders_progress().x, Session.orders_progress().y, "every seat done")
	assert_true(ended.is_empty(), "season_ended waits for finish")
	Session.finish_season()
	Events.season_ended.disconnect(h)
	assert_false(Session.in_season())
	assert_eq(ended, [1], "season_ended once")
	assert_eq(Session.game.digest(), whole[1], "the sliced season gives end_season's digest")
	assert_eq(JSON.stringify(Session.game.action_log), whole[2], "and its log")
	assert_gt(Session.ai_worst_step_ms, 0.0)
	assert_true(Session.last_phase_ms.has("ai_orders"))


func test_a_drain_follows_every_step() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var hook := StepHook.new()
	Session.game.orders = hook
	var seen: Array = []
	var h := func(hex: Vector2i) -> void: seen.append(hex)
	Events.hex_changed.connect(h)
	assert_true(bool(Session.begin_season()["ok"]))
	assert_false(Session.step_orders(0.0), "a zero budget runs one step")
	assert_eq(hook.steps, 1)
	assert_eq(seen.size(), 1, "its event was sent at once")
	assert_eq(Session.game.events.size(), 0)
	assert_true(Session.step_orders(INF), "the rest")
	Events.hex_changed.disconnect(h)
	assert_eq(hook.waiting, [0, 0, 0], "no event waited at the start of any step")
	assert_eq(Session.orders_progress(), Vector2i(3, 3))
	Session.finish_season()


func test_check_and_act_are_refused_in_season_and_change_nothing() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	var hook := StepHook.new()
	Session.game.orders = hook
	var args := _player_build()
	assert_false(args.is_empty(), "the player can build somewhere")
	assert_true(bool(Session.check("build", args)["ok"]), "fine before")
	Session.begin_season()
	Session.step_orders(0.0)
	var digest := Session.game.digest()
	var log_size := Session.game.action_log.size()
	var unsaved := Session.unsaved_actions
	var verdict := Session.act("build", args)  # planted: an act between two steps
	assert_false(bool(verdict["ok"]))
	assert_eq(verdict["reason"], "wait for the season to end")
	assert_false(bool(Session.check("build", args)["ok"]))
	assert_eq(Session.game.digest(), digest, "nothing changed")
	assert_eq(Session.game.action_log.size(), log_size)
	assert_eq(Session.unsaved_actions, unsaved)
	assert_false(bool(Session.begin_season()["ok"]), "a second begin is refused")
	Session.step_orders(INF)
	Session.finish_season()
	assert_true(bool(Session.act("build", args)["ok"]), "allowed again")


func test_begin_refused_changes_nothing_and_a_new_game_ends_the_season() -> void:
	Session.new_scenario(SCENARIO, 5)
	var digest := Session.game.digest()
	var verdict := Session.begin_season()
	assert_false(bool(verdict["ok"]), "choose your country first")
	assert_false(Session.in_season())
	assert_eq(Session.game.digest(), digest)
	Session.new_scenario(SCENARIO, 5, &"GEN")
	Session.begin_season()
	assert_true(Session.in_season())
	Session.new_scenario(SCENARIO, 5, &"GEN")
	assert_false(Session.in_season(), "start_game clears it")
	assert_true(Session.step_orders(1.0), "no season: nothing to step")


func test_ai_off_has_no_seat_and_load_attaches_the_ai() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	assert_false(Session.ai().enabled, "ai_enabled false: every seat passive")
	Session.begin_season()
	assert_eq(Session.orders_progress(), Vector2i.ZERO, "no seat")
	Session.finish_season()
	Session.ai_enabled = true
	assert_true(Session.ai().enabled, "the switch reaches the hook of the game in hand")
	assert_eq(Session.save_game("1"), "")
	assert_eq(Session.load_game("1"), "")
	assert_not_null(Session.ai(), "the loaded game has the AI")
	assert_true(Session.ai().enabled)
	Session.begin_season()
	assert_gt(Session.orders_progress().y, 0, "seats")
	Session.step_orders(INF)
	Session.finish_season()


func test_passive_seats_are_kept_and_watch_only_in_the_pick() -> void:
	Session.ai_enabled = true
	Session.new_scenario(SCENARIO, 5, &"GEN")
	Session.begin_season()
	var all := Session.orders_progress().y
	Session.step_orders(INF)
	Session.finish_season()
	Session.set_seat_passive(&"MLO", true)
	Session.begin_season()
	assert_eq(Session.orders_progress().y, all - 1, "Milan is passive")
	Session.step_orders(INF)
	Session.finish_season()
	Session.new_scenario(SCENARIO, 5, &"GEN")
	Session.begin_season()
	assert_eq(Session.orders_progress().y, all - 1, "kept for the next game")
	Session.step_orders(INF)
	Session.finish_season()
	Session.set_seat_passive(&"MLO", false)
	assert_false(Session.ai().passive.has(&"MLO"))
	assert_false(Session.watch(), "refused after a choice")
	assert_false(Session.game.ai_only)
	Session.new_scenario(SCENARIO, 5)
	assert_true(Session.watch(), "allowed in the pick")
	assert_true(Session.game.ai_only)
	assert_false(Session.watch(), "once")
	Session.begin_season()
	assert_eq(Session.orders_progress().y, all + 1, "every country is a seat in a watched game")
	Session.step_orders(INF)
	Session.finish_season()


## Issue 441: the season's end in steps (finish_step, one a frame in the flow) is the calls of finish_season in the same
## order: the orders' end, each phase from movement on, then the finish, which emits season_ended once, on the last step.
func test_the_end_in_steps_emits_season_ended_only_on_the_last() -> void:
	Session.new_scenario(SCENARIO, 5, &"GEN")
	Session.game.orders = StepHook.new()
	assert_true(bool(Session.begin_season()["ok"]))
	assert_true(Session.step_orders(INF))
	var ended: Array = []
	var h := func(turn: int) -> void: ended.append(turn)
	Events.season_ended.connect(h)
	var steps := 0
	while not Session.finish_step():
		steps += 1
		assert_true(ended.is_empty(), "no season_ended before the last step")
		assert_true(Session.in_season(), "the season is still running between steps")
	Events.season_ended.disconnect(h)
	assert_eq(steps, Season.PHASES.size(), "orders' end, the phases from movement on, then the finish: one step each")
	assert_eq(ended.size(), 1, "season_ended once")
	assert_false(Session.in_season())
	assert_true(Session.finish_step(), "a step outside the season is done at once")
