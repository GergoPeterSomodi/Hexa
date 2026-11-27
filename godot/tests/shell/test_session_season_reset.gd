## A season's end runs one step a frame (Session.finish_step), and the game may end or change between two of them (the pause
## menu's Main menu, a test's or the monkey's end of a run). The next game's first season runs whole all the same: no step of
## the season left half done is skipped in it. Before the fix of seed 1512's order dependence, the step counter outlived its
## game, so that first season skipped the orders' mark and every phase already run in the other game (with all of them run,
## even the calendar). P: a step counter carried from one game into another.
extends GutTest

const SAV := &"SAV"
const SCENARIO := "north_italy_1480"
const SEED := 1512

var _prev_game: Game = null
var _prev_unsaved := 0
var _prev_origin: Dictionary = {}
var _prev_ai := true


func before_each() -> void:
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_prev_origin = Session._origin
	_prev_ai = Session.ai_enabled
	Session.ai_enabled = false


func after_each() -> void:
	Session.end_game()
	Session.ai_enabled = _prev_ai
	Session._passive = []
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Session._origin = _prev_origin


func _new() -> Game:
	assert_eq(Session.new_scenario(SCENARIO, SEED, SAV), "")
	return Session.game


## A season of a new game run `steps` steps into its end, which is not its last.
func _half_end(steps: int) -> void:
	_new()
	assert_true(bool(Session.begin_season().ok))
	while not Session.step_orders(1000.0):
		pass
	for _i: int in steps:
		assert_false(Session.finish_step(), "the season is not over after %d steps" % steps)


## One whole season of the game in place: what it leaves behind.
func _season() -> Array:
	var game := Session.game
	var turn := game.turn
	assert_true(bool(Session.end_season().ok))
	assert_eq(game.turn, turn + 1, "the calendar phase ran")
	var marks := 0
	for record: Dictionary in game.action_log:
		marks += 1 if str(record["action"]) == LogOrders.MARK else 0
	return [game.turn, marks, game.digest()]


func test_a_game_started_after_one_left_in_the_middle_of_its_season_end_plays_a_whole_season() -> void:
	_new()
	var clean := _season()
	assert_eq(clean[1], 1, "one orders mark a season")
	# The orders' mark, then each phase but the computer's orders: the finish is the one step left after them all.
	for steps: int in range(1, Season.PHASES.size() + 1):
		for left_by_end_game: bool in [true, false]:
			_half_end(steps)
			if left_by_end_game:
				Session.end_game()
			_new()
			assert_eq(_season(), clean, "left after %d steps, %s" % [steps,
					"by end_game" if left_by_end_game else "by the next game's start"])
			if is_failing():
				return
