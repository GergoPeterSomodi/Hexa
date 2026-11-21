## The start of a game, 13 countries (docs/architecture/m4-build-spec.md 4.12's table): on "Italy, 1480", seed 1480, Normal
## taxes and calm weather, every country's people (town and countryside), start treasury, what the towns need a season
## (food, wine, salt, oil), the grain reserve and the first year's net (no works begun; Spring, Summer, Autumn, Winter).
## People and treasuries do not depend on the seed; the nets are pinned for seed 1480 only. M5 (spec 4.7, D18): hands and
## jobs count the owner's own hexes only, so two districts of Venice and of the Papal States that drew hands from a
## neighbour's land are staffed a little less: their nets are 1 to 2 ducats lower than M4's table in three seasons. The
## people never change in this test (no people phase runs): every other number is M4's.
## M6 (spec 5.1, 9): horses and copper keep a fixed reserve of 10 and 5. Every country starts with its stock at its
## reserve (Stores.setup), so it starts holding exactly 10 horses and 5 copper and sells neither (sales are only the stock
## above the reserve, and no country makes either good in its first year without works). The nets below are re-derived
## with the two reserves and none moves; test_the_two_reserves_are_held_and_sell_nothing pins why.
extends GutTest

const GRAIN := 0
const HORSES := 10
const COPPER := 14
## tag: [town, countryside, treasury, [food, wine, salt, oil], grain reserve, [Sp, Su, Au, Wi nets]]
const TABLE := {
	&"SAV": [129000, 131400, 1500, [13, 3, 2, 2], 52, [240, 307, 281, 167]],
	&"MLO": [249000, 92700, 1905, [25, 5, 3, 3], 100, [261, 314, 309, 263]],
	&"VEN": [175000, 128200, 1715, [18, 4, 2, 2], 72, [287, 422, 334, 234]],
	&"GEN": [40000, 42700, 610, [4, 1, 1, 1], 16, [86, 91, 147, 134]],
	&"TUS": [63000, 40500, 715, [7, 2, 1, 1], 28, [133, 144, 146, 180]],
	&"SWI": [66000, 56600, 810, [7, 2, 1, 1], 28, [82, 82, 89, 80]],
	&"MAN": [10000, 13000, 315, [1, 1, 1, 1], 4, [15, 19, 17, 15]],
	&"FER": [40000, 30200, 550, [4, 1, 1, 1], 16, [51, 55, 55, 56]],
	&"SIE": [3000, 15000, 290, [1, 1, 1, 1], 4, [12, 12, 16, 20]],
	&"LUC": [3000, 2500, 225, [1, 1, 1, 1], 4, [8, 8, 9, 6]],
	&"PAP": [39000, 78100, 785, [4, 1, 1, 1], 16, [99, 118, 111, 122]],
	&"FRA": [9000, 53400, 510, [1, 1, 1, 1], 4, [46, 52, 55, 51]],
	&"AUS": [23000, 30800, 465, [3, 1, 1, 1], 12, [32, 32, 111, 32]],
}
## The year's sums printed in the table's last column.
const YEAR := {
	&"SAV": 995, &"MLO": 1147, &"VEN": 1277, &"GEN": 458, &"TUS": 603, &"SWI": 333, &"MAN": 66, &"FER": 217,
	&"SIE": 60, &"LUC": 31, &"PAP": 450, &"FRA": 204, &"AUS": 207,
}


func test_the_table_covers_all_thirteen_countries() -> void:
	var g := EconomyFixture.game(&"GEN")
	assert_eq(g.countries.size(), 13)
	assert_eq(TABLE.size(), 13)
	for c: Country in g.countries:
		assert_true(TABLE.has(c.tag), "a row for %s" % c.tag)
	for tag: StringName in TABLE:
		var sum := 0
		for n: int in (TABLE[tag] as Array)[5]:
			sum += n
		assert_eq(sum, int(YEAR[tag]), "%s: the year's sum" % tag)


func test_people_treasury_needs_and_reserve_at_the_start() -> void:
	var g := EconomyFixture.game(&"GEN")
	var view := StateView.of(g.state)
	for tag: StringName in TABLE:
		var row: Array = TABLE[tag]
		var c := Countries.by_tag(g, tag)
		assert_not_null(c, str(tag))
		if c == null:
			continue
		var label := String(tag)
		assert_eq(EconomySeason.town_people(g, view, tag), row[0], label + ": town people")
		assert_eq(EconomySeason.country_people(g, view, tag), row[1], label + ": countryside people")
		assert_eq(c.treasury, row[2], label + ": start treasury")
		var needs := EconomySeason.needs_of(g, view, tag)
		var want: Array = row[3]
		assert_eq([needs["food"], needs["wine"], needs["salt"], needs["oil"]], want, label + ": needs a season")
		assert_eq(c.stock[GRAIN], row[4], label + ": grain reserve")
		assert_eq(c.tax, 1, label + ": Normal taxes")
		assert_eq(c.ledger_from, c.treasury, label + ": the ledger starts at the treasury")


func test_the_two_reserves_are_held_and_sell_nothing() -> void:
	var g := EconomyFixture.game(&"GEN")
	var view := StateView.of(g.state)
	for tag: StringName in TABLE:
		var c := Countries.by_tag(g, tag)
		var reserve := EconomySeason.reserve_of(g, view, tag)
		assert_eq(reserve[HORSES], 10, "%s: horses reserve" % tag)
		assert_eq(reserve[COPPER], 5, "%s: copper reserve" % tag)
		assert_eq(c.stock[HORSES], 10, "%s: starts holding 10 horses" % tag)
		assert_eq(c.stock[COPPER], 5, "%s: starts holding 5 copper" % tag)
	for season: int in 4:
		assert_true(bool(Season.run(g)["ok"]))
		for c: Country in g.countries:
			assert_eq(c.stock[HORSES], 10, "%s: horses kept after season %d" % [c.tag, season + 1])
			assert_eq(c.stock[COPPER], 5, "%s: copper kept after season %d" % [c.tag, season + 1])


func test_the_first_year_on_seed_1480() -> void:
	var g := EconomyFixture.game(&"GEN")
	var nets := {}
	for tag: StringName in TABLE:
		nets[tag] = []
	for season: int in 4:
		var before := {}
		for c: Country in g.countries:
			before[c.tag] = c.treasury
		assert_true(bool(Season.run(g)["ok"]))
		for c: Country in g.countries:
			(nets[c.tag] as Array).append(c.treasury - int(before[c.tag]))
	for tag: StringName in TABLE:
		assert_eq(nets[tag], (TABLE[tag] as Array)[5], "%s: net of Spring, Summer, Autumn, Winter" % tag)
