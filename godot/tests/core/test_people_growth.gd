## Done-when 1 (docs/architecture/m5-build-spec.md 4.12): 40 seasons of "Italy, 1480", seed 1480, calm weather, Normal taxes,
## no works, Genoa's land. Fed: the people end between 105,000 and 112,000, the towns between 56,000 and 61,500, no season
## hungry. Starved (a copy of the definitions that makes no food): the people end between 55,000 and 62,000, the towns between
## 7,500 and 11,000, every season from Winter 1480 hungry. The worked values are printed in the test log.
extends GutTest

const SEASONS := 40


## {people, towns, countryside, hungry: Array of the turns whose towns were short, fed: the permille of each season}.
func _run(g: Game) -> Dictionary:
	var c := Countries.by_tag(g, &"GEN")
	var hungry: Array[int] = []
	var fed: Array[int] = []
	for _n: int in SEASONS:
		var turn := g.turn
		assert_true(bool(Season.run(g)["ok"]))
		fed.append(c.food_fed)
		if c.food_fed < 1000:
			hungry.append(turn)
	var people := 0
	var towns := 0
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) == c.id:
			people += g.state.people[i]
			if g.state.main_use[i] == Economy.SETTLEMENTS:
				towns += g.state.people[i]
	return {"people": people, "towns": towns, "countryside": people - towns, "hungry": hungry, "fed": fed}


func test_a_fed_region_grows_inside_its_range() -> void:
	var g := PeopleFixture.genoa()
	var r := _run(g)
	gut.p("fed, Winter 1489: people %d, towns %d, countryside %d, hungry seasons %s" % [r["people"], r["towns"], r["countryside"], str(r["hungry"])])
	assert_between(int(r["people"]), 105000, 112000, "Genoa's people after 40 seasons")
	assert_between(int(r["towns"]), 56000, 61500, "its towns")
	assert_eq((r["hungry"] as Array).size(), 0, "no season is hungry")
	assert_eq(g.turn, SEASONS + 1)


func test_a_starved_region_shrinks_inside_its_range() -> void:
	var g := PeopleFixture.genoa(PeopleFixture.no_food())
	var r := _run(g)
	gut.p("starved, Winter 1489: people %d, towns %d, countryside %d, first hungry turn %s" % [r["people"], r["towns"], r["countryside"],
		str((r["hungry"] as Array)[0]) if not (r["hungry"] as Array).is_empty() else "none"])
	assert_between(int(r["people"]), 55000, 62000, "Genoa's people after 40 seasons")
	assert_between(int(r["towns"]), 7500, 11000, "its towns")
	var expected: Array[int] = []
	for turn: int in range(4, SEASONS + 1):
		expected.append(turn)
	assert_eq(r["hungry"], expected, "every season from Winter 1480 (turn 4) is hungry")
	assert_eq((r["fed"] as Array)[3], 400, "Winter 1480: the grain in store fed 400 permille")
	assert_eq((r["fed"] as Array)[4], 0, "and no food at all after it")


func test_the_starved_run_makes_no_food_and_the_fed_run_does() -> void:
	var fed := PeopleFixture.genoa()
	var starved := PeopleFixture.genoa(PeopleFixture.no_food())
	Season.run(fed)
	Season.run(starved)
	var grain := fed.defs.good_id(&"grain")
	var fish := fed.defs.good_id(&"fish")
	var a := Countries.by_tag(fed, &"GEN")
	var b := Countries.by_tag(starved, &"GEN")
	assert_gt(Stores.flow(a, grain, &"made", true) + Stores.flow(a, fish, &"made", true), 0)
	assert_eq(Stores.flow(b, grain, &"made", true) + Stores.flow(b, fish, &"made", true), 0, "no food made")


func test_the_ranges_have_a_planted_fault_that_fails() -> void:
	# A copy that cuts growth to 0 must fall outside the fed range (the test would notice a rate change).
	var g := PeopleFixture.genoa(PeopleFixture.still())
	var r := _run(g)
	assert_lt(int(r["people"]), 105000, "still people stay at 82,700: the fed range catches a dead rate")
