## Thread 1's seven relief levels by metres (core/state/relief_levels.gd): the bounds of each level, and the names.
extends GutTest


func test_bounds_of_each_level() -> void:
	assert_eq(ReliefLevels.level_of(0.0), 1, "0 m is lowland (sea is never read from the height)")
	assert_eq(ReliefLevels.level_of(99.9), 1, "just under 100 m is lowland")
	assert_eq(ReliefLevels.level_of(100.0), 2, "100 m starts the plain")
	assert_eq(ReliefLevels.level_of(399.9), 2, "just under 400 m is plain")
	assert_eq(ReliefLevels.level_of(400.0), 3, "400 m starts the hills")
	assert_eq(ReliefLevels.level_of(899.9), 3, "just under 900 m is hills")
	assert_eq(ReliefLevels.level_of(900.0), 4, "900 m starts the highland")
	assert_eq(ReliefLevels.level_of(1699.9), 4, "just under 1700 m is highland")
	assert_eq(ReliefLevels.level_of(1700.0), 5, "1700 m starts the mountains")
	assert_eq(ReliefLevels.level_of(2799.9), 5, "just under 2800 m is mountains")
	assert_eq(ReliefLevels.level_of(2800.0), 6, "2800 m starts the high peaks")
	assert_eq(ReliefLevels.level_of(4808.0), 6, "the highest peaks stay at level 6")


func test_names_and_the_sea_level() -> void:
	assert_eq(ReliefLevels.SEA, 0, "sea is level 0")
	assert_eq(ReliefLevels.name_of(0), "Sea", "level 0 is sea")
	assert_eq(ReliefLevels.name_of(2), "Plain", "level 2 is plain")
	assert_eq(ReliefLevels.name_of(6), "High peaks", "level 6 is high peaks")
	assert_eq(ReliefLevels.name_of(99), "High peaks", "a level above 6 is clamped to the last name")
	assert_eq(ReliefLevels.NAMES.size(), 7, "seven names")
