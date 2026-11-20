## Genoa's first year and the report's numbers through the real phases (docs/architecture/m4-build-spec.md 4.15 a and b):
## seed 1480, Normal taxes, calm weather. (a) four seasons without works, to the ducat, the stores and the ledger lines;
## salt runs out and Spring 1481 raises goods_short; (b) the fixture (7, 12) wild and the first vineyard begun in Spring.
extends GutTest

const GRAIN := 0
const FISH := 1
const OIL := 2
const WINE := 3
const SALT := 4
const TIMBER := 11
const STONE := 12
const IRON := 13


func _stock(g: Game) -> Dictionary:
	var c := Countries.by_tag(g, &"GEN")
	var out := {}
	for i: int in c.stock.size():
		if c.stock[i] != 0:
			out[i] = c.stock[i]
	return out


func _flows(g: Game, why: StringName, sign_of: int) -> Dictionary:
	var c := Countries.by_tag(g, &"GEN")
	var out := {}
	for i: int in c.stock.size():
		var n := Stores.flow(c, i, why, true)
		if n != 0:
			out[i] = n * sign_of
	return out


func test_genoas_first_year_to_the_ducat() -> void:
	var g := EconomyFixture.game(&"GEN")
	var c := Countries.by_tag(g, &"GEN")
	assert_eq(c.treasury, 610)
	assert_eq(_stock(g), {GRAIN: 16, OIL: 4, WINE: 4, SALT: 4, TIMBER: 40, STONE: 40, IRON: 20})
	var used := {FISH: 4, OIL: 1, WINE: 1, SALT: 1}
	# per season: made, sold, [people, goods, dues, upkeep, walls], net, treasury after.
	var years: Array = [
		[{GRAIN: 2, FISH: 6, TIMBER: 6}, {GRAIN: 2, FISH: 2, TIMBER: 6}, [65, 7, 30, -12, -4], 86, 696],
		[{GRAIN: 6, FISH: 6, TIMBER: 6}, {GRAIN: 6, FISH: 2, TIMBER: 6}, [65, 9, 33, -12, -4], 91, 787],
		[{GRAIN: 4, FISH: 6, OIL: 14, WINE: 24, TIMBER: 12}, {GRAIN: 4, FISH: 2, OIL: 11, WINE: 21, TIMBER: 12},
			[65, 68, 30, -12, -4], 147, 934],
		[{GRAIN: 1, FISH: 4, OIL: 28, TIMBER: 23}, {GRAIN: 1, OIL: 27, TIMBER: 23}, [65, 64, 21, -12, -4], 134, 1068],
	]
	for n: int in 4:
		var row: Array = years[n]
		var before := c.treasury
		assert_true(bool(Season.run(g)["ok"]))
		var label := "season %d" % (n + 1)
		assert_eq(_flows(g, &"made", 1), row[0], "made, " + label)
		assert_eq(_flows(g, &"used", -1), used, "used, " + label)
		assert_eq(_flows(g, &"sold", -1), row[1], "sold, " + label)
		var totals := EconomyFixture.totals(c.ledger_closed["lines"] as Array)
		var lines: Array = row[2]
		assert_eq(int(totals["tax_people"]), lines[0], "taxes on people, " + label)
		assert_eq(int(totals["tax_goods"]), lines[1], "taxes on goods, " + label)
		assert_eq(int(totals["port_dues"]), lines[2], "port dues, " + label)
		assert_eq(int(totals["upkeep_districts"]), lines[3], "district upkeep, " + label)
		assert_eq(int(totals["upkeep_walls"]), lines[4], "walls, " + label)
		assert_eq(c.treasury - before, row[3], "net, " + label)
		assert_eq(c.treasury, row[4], "treasury, " + label)
		assert_eq(int(c.ledger_closed["opening"]), before)
		assert_eq(int(c.ledger_closed["closing"]), row[4])
		assert_eq(int(c.ledger_closed["turn"]), n + 1)
	assert_eq(c.stock[SALT], 0, "salt ran out in Winter 1480")
	assert_eq(c.stock[WINE], 3, "4 + 24 made - 21 sold - 4 drunk")
	assert_eq(c.stock[OIL], 4 + 14 + 28 - 11 - 27 - 4 + 0, "oil: the reserve of 4 kept")


func test_salt_runs_short_in_spring_1481_and_taxes_fall_to_64() -> void:
	var g := EconomyFixture.game(&"GEN")
	for n: int in 4:
		Season.run(g)
	var c := Countries.by_tag(g, &"GEN")
	assert_eq(c.short_mask, 0, "winter's salt was met")
	g.events.clear()
	Season.run(g)
	var shorts: Array[Dictionary] = []
	for e: Dictionary in g.events:
		if str(e["kind"]) == "goods_short" and e["tag"] == &"GEN":
			shorts.append(e)
	assert_eq(shorts.size(), 1, "one notice, for salt")
	assert_eq(shorts[0]["good"], &"salt")
	assert_eq(shorts[0]["need"], 1)
	assert_eq(shorts[0]["taken"], 0)
	assert_eq(shorts[0]["witnesses"], [&"GEN"])
	assert_eq(c.short_mask, 1 << 2)
	assert_eq(int(EconomyFixture.totals(c.ledger_closed["lines"] as Array)["tax_people"]), 64, "content 900, factor 975")
	g.events.clear()
	Season.run(g)
	for e: Dictionary in g.events:
		assert_false(str(e["kind"]) == "goods_short" and e["tag"] == &"GEN", "a need that stays short is said once")


func test_the_report_of_spring_1480_on_the_fixture_4_15_b() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var c := Countries.by_tag(g, &"GEN")
	assert_eq(c.treasury, 610)
	var verdict := g.act("build", {"hex": EconomyFixture.VINEYARD_HEX, "family": ImproveRules.VINEYARD, "tag": &"GEN"})
	assert_true(bool(verdict["ok"]), str(verdict))
	assert_eq(c.treasury, 570, "40 ducats for the first stage")
	assert_eq(c.stock[TIMBER], 40, "no goods for a first stage")
	Season.run(g)
	assert_eq(c.treasury, 658)
	var lines := c.ledger_closed["lines"] as Array
	var totals := EconomyFixture.totals(lines)
	assert_eq(totals["tax_people"], 65)
	assert_eq(totals["tax_goods"], 7)
	assert_eq(totals["port_dues"], 30)
	assert_eq(totals["upkeep_districts"], -10)
	assert_eq(totals["upkeep_walls"], -4)
	assert_eq(totals["work"], -40)
	var typed: Array[Dictionary] = []
	typed.assign(lines)
	assert_eq(Treasury.left_over(typed), 88, "left over each season")
	assert_eq(int(c.ledger_closed["closing"]) - int(c.ledger_closed["opening"]), 48)
	assert_eq(c.stock[GRAIN], 16, "grain 16 (made 3, sold 3)")
	assert_eq(Stores.flow(c, GRAIN, &"made", true), 3)
	assert_eq(c.stock[WINE], 3)
	assert_eq(c.stock[OIL], 3)
	assert_eq(c.stock[SALT], 3)
	assert_eq(c.stock[TIMBER], 40)
	assert_eq(Stores.flow(c, FISH, &"made", true), 6)
	assert_eq(Stores.flow(c, FISH, &"used", true), -4)
	assert_eq(Stores.flow(c, FISH, &"sold", true), -2)
	assert_eq(g.state.works.size(), 1)
	assert_eq(Works.ready_turn(g, g.state.works[0]), 5, "ready Spring 1481")
