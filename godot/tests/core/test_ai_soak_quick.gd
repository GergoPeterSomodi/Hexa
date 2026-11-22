## The quick soak on every pull request (docs/architecture/m8-build-spec.md 4.17, 9): two AI-only games of 12 seasons on north Italy,
## the invariants after every season and the counting judge: no problem, no engine error. The whole soak is tools/soak.gd.
extends GutTest

const SEASONS := 12
const SEEDS: Array[int] = [1, 2]


func test_two_ai_games_of_twelve_seasons_break_no_invariant() -> void:
	var logger := SoakGame.SoakLogger.new()
	OS.add_logger(logger)
	for s: int in SEEDS:
		var rec := SoakGame.play("ai", s, SEASONS, logger)
		assert_eq(int(rec["played"]), SEASONS, "seed %d plays every season" % s)
		assert_eq((rec["failure"] as Array).size(), 0, "seed %d: %s" % [s, str(rec["failure"])])
		assert_gt(int(rec["wars"]) + int(rec["battles"]) + int(rec["rows"]["MLO"]["works"]), 0, "the AI did something")
	OS.remove_logger(logger)


func test_a_planted_money_fault_ends_the_game_with_its_line() -> void:
	var logger := SoakGame.SoakLogger.new()
	OS.add_logger(logger)
	var rec := SoakGame.play("ai", 1, SEASONS, logger, "money")
	OS.remove_logger(logger)
	var failure: Array = rec["failure"]
	assert_gt(failure.size(), 0, "the planted treasury is found")
	if not failure.is_empty():
		assert_true(str(failure[0]).begins_with("money:"), str(failure[0]))
		assert_lt(int(rec["played"]), SEASONS, "the game ended at the break")
