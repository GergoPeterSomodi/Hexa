## Genoa's first year with people growing (docs/architecture/m5-build-spec.md 4.11 (a)): seed 1480, Normal taxes, calm weather,
## no works. Four seasons to the person and the ducat: the people at the start and end of each season and what grew, the towns'
## people and food need, fed, taxes on people and goods, port dues, upkeep, walls, net and treasury (1,067 at the year's end).
extends GutTest

const GENOA := Vector2i(8, 13)
const SAVONA := Vector2i(6, 13)


func _people_of(g: Game, id: int) -> int:
	var total := 0
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) == id:
			total += g.state.people[i]
	return total


func _towns_of(g: Game, id: int) -> int:
	var total := 0
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) == id and g.state.main_use[i] == Economy.SETTLEMENTS:
			total += g.state.people[i]
	return total


func test_genoas_first_year_with_people_growing() -> void:
	var g := PeopleFixture.genoa()
	var c := Countries.by_tag(g, &"GEN")
	assert_eq(c.treasury, 610)
	assert_eq(_people_of(g, c.id), 82700, "the start people")
	# per season: people at the start, at the end, towns at the start, need, [people, goods, dues, upkeep, walls], net, treasury.
	var years: Array = [
		[82700, 83285, 40000, 4, [65, 7, 30, -12, -4], 86, 696],
		[83285, 83874, 40400, 5, [66, 6, 33, -12, -4], 89, 785],
		[83874, 84469, 40804, 5, [66, 67, 30, -12, -4], 147, 932],
		[84469, 84977, 41212, 5, [67, 63, 21, -12, -4], 135, 1067],
	]
	for n: int in 4:
		var row: Array = years[n]
		var label := "season %d" % (n + 1)
		var before := c.treasury
		assert_eq(_people_of(g, c.id), row[0], "people at the start, " + label)
		assert_eq(_towns_of(g, c.id), row[2], "towns at the start, " + label)
		assert_true(bool(Season.run(g)["ok"]))
		assert_eq(_people_of(g, c.id), row[1], "people at the end, " + label)
		assert_eq(c.food_need, row[3], "food need, " + label)
		assert_eq(c.food_fed, 1000, "fed, " + label)
		var grew := int((c.people_closed["flows"] as PackedInt32Array)[People.GREW])
		assert_eq(grew, int(row[1]) - int(row[0]), "the season's growth is the flow, " + label)
		var totals := EconomyFixture.totals(c.ledger_closed["lines"] as Array)
		var lines: Array = row[4]
		assert_eq(int(totals["tax_people"]), lines[0], "taxes on people, " + label)
		assert_eq(int(totals["tax_goods"]), lines[1], "taxes on goods, " + label)
		assert_eq(int(totals["port_dues"]), lines[2], "port dues, " + label)
		assert_eq(int(totals["upkeep_districts"]), lines[3], "district upkeep, " + label)
		assert_eq(int(totals["upkeep_walls"]), lines[4], "walls, " + label)
		assert_eq(c.treasury - before, row[5], "net, " + label)
		assert_eq(c.treasury, row[6], "treasury, " + label)
	assert_eq(c.treasury, 1067, "the year's treasury (M4's still year: 1,068)")


func test_springs_growth_is_genoa_savona_and_three_countryside_hexes() -> void:
	var g := PeopleFixture.genoa()
	var before := g.state.people.duplicate()
	Season.run(g)
	assert_eq(g.state.people[g.map.index_of(GENOA)] - before[g.map.index_of(GENOA)], 300, "Genoa 30,000 x 1 %")
	assert_eq(g.state.people[g.map.index_of(SAVONA)] - before[g.map.index_of(SAVONA)], 100, "Savona 10,000 x 1 %")
	var c := Countries.by_tag(g, &"GEN")
	var grew := 0
	var risen: Array[int] = []
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) == c.id and g.state.people[i] != before[i]:
			grew += 1
			risen.append(g.state.people[i] - before[i])
	risen.sort()
	assert_eq(risen, [25, 80, 80, 100, 300], "the vineyard, the olives, the timber camp, Savona, Genoa: five hexes grow")
	assert_eq(grew, 5)
