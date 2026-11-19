## Calendar tests (docs/architecture/m3-build-spec.md 4.1, 9).
extends GutTest


func test_turns_one_to_nine_forty_and_681() -> void:
	var texts: Array[String] = ["Spring 1480", "Summer 1480", "Autumn 1480", "Winter 1480", "Spring 1481",
		"Summer 1481", "Autumn 1481", "Winter 1481", "Spring 1482"]
	for i: int in texts.size():
		assert_eq(Calendar.date_text(i + 1, 1480), texts[i], "turn %d" % (i + 1))
		assert_eq(Calendar.season_of(i + 1), i % 4)
	assert_eq(Calendar.date_text(40, 1480), "Winter 1489")
	assert_eq(Calendar.date_text(681, 1480), "Spring 1650")
	assert_eq(Calendar.season_name(4), "Winter")
	assert_eq(Calendar.year_of(5, 1480), 1481)


func test_turn_of_inverts_for_680_turns() -> void:
	for turn: int in range(1, 681):
		var s := Calendar.season_of(turn)
		var y := Calendar.year_of(turn, 1480)
		assert_eq(Calendar.turn_of(s, y, 1480), turn)


func test_is_winter() -> void:
	for turn: int in range(1, 9):
		assert_eq(Calendar.is_winter(turn), turn % 4 == 0, "turn %d" % turn)


func test_phase_adds_exactly_one() -> void:
	var g := ScenarioFixture.game()
	assert_eq(Calendar.OWNS, ["turn"])
	var before := g.digest()
	Calendar.season(g)
	assert_eq(g.turn, 2)
	assert_ne(g.digest(), before)
