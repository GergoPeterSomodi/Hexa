## TugBar (docs/architecture/m7-build-spec.md 6.5; M7 B22): the flee ticks sit at FLEE_PERMILLE in from each outer edge, and the
## fronts are clamped to 0 to 1000.
extends GutTest


func test_flee_ticks_sit_in_from_each_outer_edge() -> void:
	var expected := 200.0 * float(TugBar.FLEE_PERMILLE) / float(TugBar.FULL) * 0.5
	assert_almost_eq(TugBar.flee_x(200.0, true), 100.0 - expected, 0.01, "the attacker's tick, in from the left edge")
	assert_almost_eq(TugBar.flee_x(200.0, false), 100.0 + expected, 0.01, "the defender's tick, in from the right edge")


func test_fronts_are_clamped() -> void:
	var bar := TugBar.new()
	add_child_autofree(bar)
	bar.set_values(-50, 1700, Tokens.GOOD, Tokens.BAD)
	assert_eq(bar.attacker_permille, 0)
	assert_eq(bar.defender_permille, TugBar.FULL)
