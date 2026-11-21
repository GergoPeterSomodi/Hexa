## SeasonProfile (core/systems/season_profile.gd; docs/architecture/m4-build-spec.md 8 and 10, task N4): the profile of a
## country equals the per-hex passes to the unit, for every country, season, weather and tax; it follows a change of the map
## (the key is the hashes of owner, use and level) and its `live` part (people, a0 after staffing) follows the people (M5
## spec 5.0 R1) and the fields it reads are where Economy.BASE_FIELDS puts them.
extends GutTest

@warning_ignore_start("integer_division")


func _direct(game: Game, tag: StringName, season: int, weather: PackedByteArray, tax: int) -> Dictionary:
	# The old per-hex path: an explicit cache of its own.
	return EconomySeason.made_of(game, StateView.of(game.state), tag, season, weather, tax, DistrictCache.new())


func test_the_fields_are_where_the_profile_reads_them() -> void:
	assert_eq(Economy.BASE_FIELDS[Economy.F_RAW], "raw")
	assert_eq(Economy.BASE_FIELDS[Economy.F_LIFT], "lift")
	assert_eq(Economy.BASE_FIELDS[Economy.F_ROOM], "room")
	assert_eq(DistrictCache.FIELDS, Economy.BASE_FIELDS.size())
	assert_eq(DistrictCache.FIELDS, 14)


func test_the_profile_equals_the_per_hex_pass_for_every_country() -> void:
	var game := EconomyFixture.game(&"GEN", false, false)
	var weathers: Array[PackedByteArray] = [PackedByteArray([0, 0, 0]), PackedByteArray([1, 2, 0]), PackedByteArray([2, 1, 2])]
	for c: Country in game.countries:
		for season: int in 4:
			for weather: PackedByteArray in weathers:
				for tax: int in 3:
					var fast := EconomySeason.made_of(game, StateView.of(game.state), c.tag, season, weather, tax)
					assert_eq(fast, _direct(game, c.tag, season, weather, tax), "%s season %d tax %d %s" % [c.tag, season, tax, weather])


func test_the_profile_counts_the_people_and_the_upkeep() -> void:
	var game := EconomyFixture.game(&"GEN")
	var held := SeasonProfile.table(game)
	for c: Country in game.countries:
		var profile := SeasonProfile.of(game, held, c.id)
		var live := SeasonProfile.live(game, held, c.id)
		var view := StateView.of(game.state)
		assert_eq(live["town"], EconomySeason.town_people(game, view, c.tag), "%s town" % c.tag)
		assert_eq(live["rest"], EconomySeason.country_people(game, view, c.tag), "%s countryside" % c.tag)
		assert_false(profile.has("town"), "the people-free profile holds no people")
		var made := _direct(game, c.tag, 0, PackedByteArray([0, 0, 0]), 1)
		assert_eq(profile["upkeep"], made["upkeep"])
		assert_eq(profile["upkeep_count"], made["upkeep_count"])
		assert_eq(profile["walls"], made["walls"])


func test_the_table_is_kept_while_the_map_is_the_same_and_rebuilt_when_it_changes() -> void:
	var game := EconomyFixture.game(&"GEN")
	var a := SeasonProfile.table(game)
	SeasonProfile.of(game, a, Countries.by_tag(game, &"GEN").id)
	assert_true(SeasonProfile.table(game) == a, "the same dictionary while nothing changed")
	assert_eq(SeasonProfile.table(game).size(), 2, "one profile and the live part")
	var hex := Vector2i(10, 13)
	var i := game.map.index_of(hex)
	game.state.main_use[i] = ImproveRules.TIMBER
	game.state.level[i] = 2
	game.districts.touch(game, hex)
	var b := SeasonProfile.table(game)
	assert_eq(b.size(), 1, "a changed use starts a new table (only the live part is in it)")
	var weather := PackedByteArray([0, 0, 0])
	assert_eq(EconomySeason.made_of(game, StateView.of(game.state), &"GEN", 3, weather, 1), _direct(game, &"GEN", 3, weather, 1))
	var owner_before := SeasonProfile.table(game)
	game.dev_transfer([hex], 0)
	assert_ne(SeasonProfile.table(game), owner_before, "an owner change starts a new table too")
	assert_eq(EconomySeason.made_of(game, StateView.of(game.state), &"GEN", 3, weather, 1), _direct(game, &"GEN", 3, weather, 1))


func test_a_view_with_an_overlay_does_not_use_the_profile() -> void:
	var game := EconomyFixture.game(&"GEN")
	var weather := PackedByteArray([0, 0, 0])
	var i := game.map.index_of(Vector2i(8, 13))
	var view := StateView.of(game.state).with({i: Vector2i(1, 5)})
	var info := EconomySeason.made_of(game, view, &"GEN", 0, weather, 1)
	assert_eq(info["made"][1], 10, "the city's fish: the overlay was read")
	assert_eq(EconomySeason.made_of(game, StateView.of(game.state), &"GEN", 0, weather, 1)["made"][1], 6)


func test_the_live_part_follows_the_people_and_not_the_map() -> void:
	var game := EconomyFixture.game(&"GEN")
	var genoa := Countries.by_tag(game, &"GEN")
	var held := SeasonProfile.table(game)
	var before := SeasonProfile.live(game, held, genoa.id)
	assert_eq([before["town"], before["rest"]], [40000, 42700])
	assert_true(SeasonProfile.live(game, held, genoa.id) == before, "kept while the people are the same")
	var i := game.map.index_of(Vector2i(8, 13))
	game.state.people[i] += 100  # a direct edit: the next table sees the people's hash change
	var held2 := SeasonProfile.table(game)
	assert_true(held2 == held, "the profile itself is kept: use, level and owner did not change")
	var after := SeasonProfile.live(game, held2, genoa.id)
	assert_eq([after["town"], after["rest"]], [40100, 42700])
	assert_false(after["ready"], "the totals come at once, the a0 of the rows when a season needs them")
	var rows: PackedInt32Array = SeasonProfile.of(game, held2, genoa.id)["rows"]
	var a0s := SeasonProfile.a0_of(game, SeasonProfile.of(game, held2, genoa.id), after)
	assert_eq(a0s.size(), rows.size() / SeasonProfile.ROW, "one a0 for each row")
	assert_true(after["ready"])
	assert_true(SeasonProfile.live(game, held2, genoa.id)["a0"] == a0s, "kept")
	# A staffing change reaches a0: more hands beside a district give it more of its raw output.
	var weather := PackedByteArray([0, 0, 0])
	var warm := EconomySeason.made_of(game, StateView.of(game.state), &"GEN", 2, weather, 1)
	assert_eq(warm, _direct(game, &"GEN", 2, weather, 1), "the live part and the per-hex pass agree after a people change")
