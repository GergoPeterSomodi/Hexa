## The people phase in the real season (docs/architecture/m5-build-spec.md 4.11 (d) and (e), 9): villages grow into towns at the
## turns the spec works out, a village stays a village beside a town, a town falls to hunger with its event unless a dye works
## needs it, a walled town does not fall, a village under 1,000 becomes a hamlet and grows back, a starved town stops at its
## floor, and the season table runs the people phase between the works and the stats.
extends GutTest

const ALBA := Vector2i(6, 11)
const MOUTIERS := Vector2i(2, 8)
const CESENA := Vector2i(18, 14)
const LUCCA := Vector2i(12, 15)
const PISA := Vector2i(13, 16)
const SAVONA := Vector2i(6, 13)
const GENOA := Vector2i(8, 13)
const DYE_HEX := Vector2i(7, 12)


func _events(g: Game, kind: String, hex: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in g.events:
		if str(e.get("kind", "")) == kind and e.get("hex") == hex:
			out.append(e)
	return out


func _level(g: Game, hex: Vector2i) -> int:
	return int(g.state.level[g.map.index_of(hex)])


func _people(g: Game, hex: Vector2i) -> int:
	return g.state.people[g.map.index_of(hex)]


# ----- the season table --------------------------------------------------------------------------------------------------


func test_the_season_runs_the_people_phase_between_works_and_stats() -> void:
	assert_eq(Season.PHASES.find(&"people"), Season.PHASES.find(&"works") + 1)
	# moves-build-spec.md R22a: the End-turn leg (march_on) walks between the people and the stats.
	assert_eq(Season.PHASES.find(&"march_on"), Season.PHASES.find(&"people") + 1)
	assert_eq(Season.PHASES.find(&"stats"), Season.PHASES.find(&"march_on") + 1)
	var g := PeopleFixture.genoa()
	var before := _people(g, GENOA)
	Season.begin(g)
	for phase: StringName in [&"production", &"income", &"works", &"people"]:
		Season.run_phase(g, phase)  # the towns eat in production: the phase reads what they ate
	assert_eq(g.turn, 1, "the phase does not end the season")
	assert_eq(_people(g, GENOA), before + 300, "Genoa grows 1 % in the phase (4.11 a)")
	var played := PeopleFixture.genoa()
	Season.run(played)
	assert_eq(_people(played, GENOA), before + 300)
	var country := Countries.by_tag(played, &"GEN")
	assert_eq(int(country.people_closed["turn"]), 1, "People.close ran inside the stats phase")
	assert_eq((country.people_flows as PackedInt32Array).count(0), People.FLOWS.size(), "and the open flows are zero again")


func test_a_season_equals_the_fixtures_loop() -> void:
	var a := PeopleFixture.genoa()
	var b := PeopleFixture.genoa()
	for _n: int in 6:
		Season.run(a)
		PeopleFixture.season(b)
	assert_eq(a.digest(), b.digest())


# ----- 4.11 (d): a village grows into a town -------------------------------------------------------------------------------


func test_villages_grow_into_towns_at_the_turns_of_4_11_d() -> void:
	var g := PeopleFixture.genoa(PeopleFixture.always_fed())
	var due := {ALBA: 34, MOUTIERS: 34, CESENA: 30}
	var seen: Dictionary = {}
	for _n: int in 35:
		var ended := g.turn
		Season.run(g)
		for hex: Vector2i in due:
			if _level(g, hex) == 3 and not seen.has(hex):
				seen[hex] = ended
	for hex: Vector2i in due:
		assert_eq(int(seen.get(hex, -1)), int(due[hex]), "%s grew at turn %d, not before" % [hex, int(due[hex])])
		var grew := _events(g, "town_grew", hex)
		assert_eq(grew.size(), 1, "one town_grew at %s" % hex)
		assert_eq(int(grew[0]["turn"]), int(due[hex]))
		assert_eq(int(grew[0]["level"]), 3)
		assert_eq(int(grew[0]["from"]), 2)
		assert_eq(int(grew[0]["people"]), 4000)
		var that_turn := 0
		for e: Dictionary in _events(g, "hex_changed", hex):
			if int(e["turn"]) == int(due[hex]):
				that_turn += 1
		assert_eq(that_turn, 1, "one hex_changed at %s in the season it grew" % hex)
	assert_eq(str(_events(g, "town_grew", ALBA)[0]["tag"]), "SAV")
	var cells := MapCells.of_hex(g.map, g.state, ALBA)
	var found := false
	for tile: Variant in cells.values():
		found = found or str(tile).begins_with("piece/settlements/3/")
	assert_true(found, "the piece cells of (6, 11) are level 3: %s" % str(cells.values()))


func test_a_village_does_not_grow_before_it_is_full() -> void:
	var g := PeopleFixture.genoa(PeopleFixture.always_fed())
	for _n: int in 33:
		Season.run(g)
	assert_eq(_level(g, ALBA), 2, "still a village at the start of turn 34")
	assert_eq(_events(g, "town_grew", ALBA).size(), 0)
	assert_lt(_people(g, ALBA), 4000)


func test_lucca_fills_its_room_and_stays_a_village_beside_pisa() -> void:
	var g := PeopleFixture.genoa(PeopleFixture.always_fed())
	for _n: int in 30:
		Season.run(g)
	assert_eq(_people(g, LUCCA), 4000, "full in Summer 1487 (turn 30)")
	for _n: int in 10:
		Season.run(g)
	assert_eq(_level(g, LUCCA), 2)
	assert_eq(_events(g, "town_grew", LUCCA).size(), 0)
	var verdict := People.grow_check(g, StateView.of(g.state), LUCCA, 1000)
	assert_false(bool(verdict["ok"]))
	assert_eq(verdict["other"], PISA, "Pisa is the town beside it")
	assert_gte(int(verdict["rule"]), 0)
	assert_true(str(verdict["reason"]).contains("13, 16"), str(verdict["reason"]))


# ----- 4.11 (e): a town falls to a village ---------------------------------------------------------------------------------


func _hungry_genoa() -> Game:
	var g := PeopleFixture.genoa(PeopleFixture.no_food())
	assert_true(g.dev_people(SAVONA, 2100))
	var grain := g.defs.good_id(&"grain")
	assert_true(g.dev_goods(&"GEN", grain, -Countries.by_tag(g, &"GEN").stock[grain]))
	return g


func test_savona_falls_to_a_village_in_summer_1480() -> void:
	var g := _hungry_genoa()
	Season.run(g)
	assert_eq(_people(g, SAVONA), 2016, "Spring: 84 starve")
	assert_eq(Countries.by_tag(g, &"GEN").food_fed, 0)
	assert_eq(_level(g, SAVONA), 3, "still a town")
	assert_eq(_events(g, "district_declined", SAVONA).size(), 0)
	Season.run(g)
	assert_eq(_people(g, SAVONA), 1935, "Summer: 81 starve")
	assert_eq(_level(g, SAVONA), 2)
	var fell := _events(g, "district_declined", SAVONA)
	assert_eq(fell.size(), 1)
	var e := fell[0]
	assert_eq(int(e["turn"]), 2)
	assert_eq(str(e["tag"]), "GEN")
	assert_eq(int(e["family"]), 1)
	assert_eq(int(e["level"]), 2)
	assert_eq(int(e["from"]), 3)
	assert_eq(int(e["people"]), 1935)
	assert_eq(str(e["why"]), "hunger")
	assert_eq(_events(g, "hex_changed", SAVONA).size(), 1)


func test_a_dye_works_that_needs_the_town_keeps_savona_a_town() -> void:
	var g := _hungry_genoa()
	var i := g.map.index_of(DYE_HEX)
	g.state.main_use[i] = ImproveRules.DYES
	g.state.level[i] = 1
	g.districts.clear()  # a direct state edit: the cache and the running set start again
	g.districts.reset_open()
	g.version += 1
	Season.run(g)
	Season.run(g)
	assert_eq(_level(g, SAVONA), 3, "its only town within one hex is Savona")
	assert_eq(_events(g, "district_declined", SAVONA).size(), 0, "and no event")
	assert_lt(_people(g, SAVONA), 2000)


func test_a_walled_town_at_200_people_stays_walled() -> void:
	var g := PeopleFixture.genoa(PeopleFixture.no_food())
	assert_true(g.dev_people(GENOA, 200))
	for _n: int in 3:
		Season.run(g)
	assert_eq(_level(g, GENOA), 4, "walls do not fall to hunger")
	assert_eq(_events(g, "district_declined", GENOA).size(), 0)
	assert_gte(_people(g, GENOA), g.defs.town_floor)


func test_a_village_under_1000_becomes_a_hamlet_and_grows_back_at_2000() -> void:
	var g := PeopleFixture.genoa(PeopleFixture.always_fed())
	assert_true(g.dev_people(ALBA, 900))
	Season.run(g)
	assert_eq(_level(g, ALBA), 1, "a hamlet")
	var fell := _events(g, "district_declined", ALBA)
	assert_eq(fell.size(), 1)
	assert_eq(str(fell[0]["why"]), "people", "fed, so it is too few people")
	assert_true(g.dev_people(ALBA, 2000))
	Season.run(g)
	assert_eq(_level(g, ALBA), 2, "a village again")
	assert_eq(_events(g, "town_grew", ALBA).size(), 1)


func test_the_starved_town_never_goes_under_its_floor() -> void:
	var g := PeopleFixture.genoa(PeopleFixture.no_food())
	assert_true(g.dev_people(SAVONA, 300))
	for _n: int in 60:
		Season.run(g)
		assert_gte(_people(g, SAVONA), g.defs.town_floor)
	assert_eq(_people(g, SAVONA), g.defs.town_floor)
