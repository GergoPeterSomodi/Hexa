## Calendar tests (docs/architecture/m3-build-spec.md 4.1, 9; m4-build-spec.md 4.6: the weather).
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
	assert_eq(Calendar.OWNS, ["turn", "weather"])
	var before := g.digest()
	Calendar.season(g)
	assert_eq(g.turn, 2)
	assert_ne(g.digest(), before)


# ----- the weather (m4-build-spec.md 4.6) --------------------------------------------------------------------------


func _italy(odds: Array[int]) -> Game:
	var defs := EconomyFixture.defs(false)
	defs.weather_odds = PackedInt32Array(odds)
	return Game.new_scenario(EconomyFixture.map(), defs, defs.scenarios[defs.scenarios.size() - 1], 1480)


func test_a_new_game_starts_calm_and_the_sandbox_stays_calm() -> void:
	var g := _italy([60, 20, 20])
	assert_eq(g.weather, PackedByteArray([0, 0, 0]))
	var sandbox := Game.new_game(EconomyFixture.map(), 1, EconomyFixture.committed())
	var state_before := sandbox.luck.digest_text()
	Calendar.season(sandbox)
	assert_eq(sandbox.weather, PackedByteArray([0, 0, 0]))
	assert_eq(sandbox.luck.digest_text(), state_before, "a map-only game draws nothing")


func test_the_season_draws_luck_once_a_climate_in_the_order_snow_frost_mild() -> void:
	var g := _italy([60, 20, 20])
	var twin := Rng.new()
	twin.set_state(g.luck.world.get_state())
	var rolls: Array[int] = [twin.randi_range(1, 100), twin.randi_range(1, 100), twin.randi_range(1, 100)]
	var ai_before := g.luck.ai.get_state()
	Calendar.season(g)
	assert_eq(g.luck.world.get_state(), twin.get_state(), "exactly three draws of luck.world, no more")
	assert_eq(g.luck.ai.get_state(), ai_before, "the other streams are not touched")
	for climate: int in 3:
		var want := 0 if rolls[climate] <= 60 else (1 if rolls[climate] <= 80 else 2)
		assert_eq(int(g.weather[climate]), want, "climate %d from roll %d" % [climate, rolls[climate]])


func test_the_odds_decide() -> void:
	var always_good := _italy([0, 100, 0])
	Calendar.season(always_good)
	assert_eq(always_good.weather, PackedByteArray([1, 1, 1]))
	var always_poor := _italy([0, 0, 100])
	Calendar.season(always_poor)
	assert_eq(always_poor.weather, PackedByteArray([2, 2, 2]))
	var calm := _italy([100, 0, 0])
	Calendar.season(calm)
	assert_eq(calm.weather, PackedByteArray([0, 0, 0]))
	var mixed := _italy([60, 20, 20])
	var seen := {}
	for n: int in 60:
		Calendar.season(mixed)
		for climate: int in 3:
			seen[int(mixed.weather[climate])] = true
	assert_eq(seen.keys().size(), 3, "calm, good and poor all turn up over 60 seasons")


func test_weather_is_in_the_digest_and_the_same_seed_gives_the_same_weather() -> void:
	var a := _italy([60, 20, 20])
	var b := _italy([60, 20, 20])
	for n: int in 12:
		Calendar.season(a)
		Calendar.season(b)
		assert_eq(a.weather, b.weather)
	var before := a.digest()
	a.weather[0] = (int(a.weather[0]) + 1) % 3
	assert_ne(a.digest(), before, "the weather is part of the digest")


func test_weather_text_names_the_places_and_the_effects() -> void:
	var g := _italy([100, 0, 0])
	g.turn = 2
	assert_eq(Calendar.weather_text(g, &"GEN"), "", "all calm")
	g.weather = PackedByteArray([2, 0, 1])
	assert_eq(Calendar.weather_text(g, &"GEN"), "Summer: good on the coast, poor in the high valleys (crops +20 %, −25 %).")
	assert_eq(Calendar.weather_text(g, &"ZZZ"), "")
	g.weather = PackedByteArray([0, 2, 0])
	var text := Calendar.weather_text(g, &"GEN")
	assert_true(text.is_empty() or text.contains("poor inland"), text)
