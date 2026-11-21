## Treasury (docs/architecture/m4-build-spec.md 4.9, 4.12, 5.3 and 9): the one door of money, its ledger and the start
## amounts. Planted faults: an unknown why and an unknown tag change nothing and return false.
extends GutTest

const HEX_A := Vector2i(2, 2)
const HEX_B := Vector2i(3, 2)


## The fixture game with Treasury.setup run (Game calls it from M4's N4 on).
func _game() -> Game:
	var g := ScenarioFixture.game()
	Treasury.setup(g)
	return g


func _country(g: Game, tag: StringName) -> Country:
	return Countries.by_tag(g, tag)


func test_owns_and_why_table() -> void:
	assert_eq(Treasury.OWNS, ["treasury", "ledger_open", "ledger_from", "ledger_closed"])
	assert_eq(Treasury.WHY.size(), 8)
	assert_eq(Treasury.WHY[0], &"tax_people")
	assert_eq(Treasury.SPENDING, [&"work", &"refund"] as Array[StringName])
	assert_eq(Treasury.NO_HEX, Vector2i(-1, -1))


func test_move_merges_by_why_and_hex_in_first_added_order() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	var start := c.treasury
	assert_true(Treasury.move(g, &"AAA", 10, &"port_dues", HEX_A))
	assert_true(Treasury.move(g, &"AAA", 7, &"tax_people"))
	assert_true(Treasury.move(g, &"AAA", 5, &"port_dues", HEX_A))
	assert_true(Treasury.move(g, &"AAA", 4, &"port_dues", HEX_B))
	assert_eq(c.treasury, start + 26)
	assert_eq(c.ledger_open.size(), 3)
	assert_eq(c.ledger_open[0]["why"], &"port_dues")
	assert_eq(c.ledger_open[0]["hex"], HEX_A)
	assert_eq(c.ledger_open[0]["amount"], 15)
	assert_eq(c.ledger_open[0]["count"], 2)
	assert_eq(c.ledger_open[1]["why"], &"tax_people")
	assert_eq(c.ledger_open[1]["hex"], Treasury.NO_HEX)
	assert_eq(c.ledger_open[2]["hex"], HEX_B)
	assert_eq(c.ledger_open[0].keys(), ["why", "hex", "amount", "count"], "no stored spending flag")


func test_count_is_added_and_spending_is_marked() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	Treasury.move(g, &"AAA", 30, &"upkeep_districts", Treasury.NO_HEX, 6)
	Treasury.move(g, &"AAA", -12, &"upkeep_districts", Treasury.NO_HEX, 3)
	assert_eq(c.ledger_open.size(), 1)
	assert_eq(c.ledger_open[0]["amount"], 18)
	assert_eq(c.ledger_open[0]["count"], 9)
	Treasury.move(g, &"AAA", -50, &"work", HEX_A)
	assert_true(Treasury.SPENDING.has(c.ledger_open[1]["why"]))
	assert_false(Treasury.SPENDING.has(c.ledger_open[0]["why"]))


func test_amount_zero_adds_no_line() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	var start := c.treasury
	assert_true(Treasury.move(g, &"AAA", 0, &"tax_people"))
	assert_eq(c.ledger_open.size(), 0)
	assert_eq(c.treasury, start)


func test_planted_unknown_why_and_unknown_tag_change_nothing() -> void:
	var g := _game()
	var before := g.digest()
	assert_false(Treasury.move(g, &"AAA", 10, &"bribe"), "a why outside WHY is refused")
	assert_false(Treasury.move(g, &"ZZZ", 10, &"dev"), "an unknown tag is refused")
	assert_false(Treasury.move(g, &"", 10, &"dev"), "no tag is refused")
	assert_eq(g.digest(), before)
	assert_eq(_country(g, &"AAA").ledger_open.size(), 0)


func test_the_treasury_may_fall_below_zero() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	assert_true(Treasury.move(g, &"AAA", -(c.treasury + 40), &"upkeep_walls", HEX_A))
	assert_eq(c.treasury, -40)
	assert_false(Treasury.can_pay(g, &"AAA", 1))


func test_close_ledger_moves_the_lines_and_the_opening() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	var opening := c.treasury
	Treasury.move(g, &"AAA", 40, &"tax_people")
	Treasury.move(g, &"AAA", -15, &"work", HEX_A)
	g.turn = 5
	Treasury.close_ledger(g)
	assert_eq(c.ledger_closed["turn"], 5)
	assert_eq(c.ledger_closed["opening"], opening)
	assert_eq(c.ledger_closed["closing"], opening + 25)
	var lines: Array = c.ledger_closed["lines"]
	assert_eq(lines.size(), 2)
	var sum := 0
	for line: Dictionary in lines:
		sum += int(line["amount"])
	assert_eq(int(c.ledger_closed["closing"]) - int(c.ledger_closed["opening"]), sum, "closing - opening = the lines")
	assert_eq(c.ledger_open.size(), 0)
	assert_eq(c.ledger_from, opening + 25)
	var other := _country(g, &"BBB")
	assert_eq(other.ledger_closed["turn"], 5, "every country closes, quiet ones too")
	assert_eq((other.ledger_closed["lines"] as Array).size(), 0)
	# A new season starts from the closed one, and the closed copy is not touched by it.
	Treasury.move(g, &"AAA", 9, &"tax_people")
	assert_eq((c.ledger_closed["lines"] as Array).size(), 2)
	assert_eq(int(lines[0]["amount"]), 40)


func test_left_over_leaves_out_spending_and_dev() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	Treasury.move(g, &"AAA", 100, &"tax_people")
	Treasury.move(g, &"AAA", 20, &"tax_goods")
	Treasury.move(g, &"AAA", -30, &"upkeep_districts", Treasury.NO_HEX, 3)
	Treasury.move(g, &"AAA", -60, &"work", HEX_A)
	Treasury.move(g, &"AAA", 60, &"refund", HEX_A)
	Treasury.move(g, &"AAA", 999, &"dev")
	assert_eq(Treasury.left_over(c.ledger_open), 90)
	assert_eq(Treasury.left_over([] as Array[Dictionary]), 0)


func test_can_pay() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	assert_true(Treasury.can_pay(g, &"AAA", c.treasury))
	assert_false(Treasury.can_pay(g, &"AAA", c.treasury + 1))
	assert_true(Treasury.can_pay(g, &"AAA", 0))
	assert_false(Treasury.can_pay(g, &"ZZZ", 0), "an unknown country pays nothing")


## The people of a country counted again from the state, independent of Stores.
func _people(g: Game, c: Country) -> int:
	var total := 0
	var settlements := g.defs.family(1)
	for i: int in g.map.hex_count():
		if g.state.owner[i] != c.id or g.map.land[i] == 0:
			continue
		if g.state.main_use[i] == 1:
			total += settlements.people[g.state.level[i]]
		else:
			total += g.defs.country_people[g.map.cover[i]]
	return total


func test_setup_gives_the_start_amount() -> void:
	var g := ScenarioFixture.game()
	for c: Country in g.countries:
		c.treasury = 77
		c.ledger_closed = {"turn": 1}
		c.ledger_open = [{"why": &"dev", "hex": Treasury.NO_HEX, "amount": 1, "count": 1, "spending": false}]
	Treasury.setup(g)
	for c: Country in g.countries:
		var people := _people(g, c)
		var want := 200 + 5 * int(people / 1000.0)
		assert_eq(c.treasury, want, "%s" % c.tag)
		assert_eq(Treasury.start_amount(g, c.tag), want)
		assert_eq(c.ledger_from, want)
		assert_eq(c.ledger_open.size(), 0)
		assert_true(c.ledger_closed.is_empty())
		assert_eq(c.tax, 1, "every country starts at Normal")
	assert_eq(Treasury.start_amount(g, &"ZZZ"), 0)


func test_start_amount_follows_the_people() -> void:
	var g := ScenarioFixture.game()
	var c := _country(g, &"AAA")
	# Plant a known land: no works, one 10,000 town, the rest farmland and the like by cover.
	for i: int in g.map.hex_count():
		if g.state.owner[i] == c.id:
			g.state.main_use[i] = 0
			g.state.level[i] = 0
	var cap := g.map.index_of(ScenarioFixture.ALPHA_CAPITAL)
	g.state.main_use[cap] = 1
	g.state.level[cap] = 3
	People.setup(g)   # people are the state's (M5): the planted land starts with its table
	var country_people := 0
	for i: int in g.map.hex_count():
		if g.state.owner[i] == c.id and i != cap and g.map.land[i] != 0:
			country_people += g.defs.country_people[g.map.cover[i]]
	var want := 200 + 5 * int((10000 + country_people) / 1000.0)
	assert_eq(Treasury.start_amount(g, &"AAA"), want)
	assert_eq(Stores.start_people(g, &"AAA"), Vector2i(10000, country_people))


func test_map_only_game_has_nothing() -> void:
	var g := Game.new_game(ScenarioFixture.build()["map"] as MapData, 3)
	Treasury.setup(g)
	assert_eq(g.countries.size(), 0)
	assert_false(Treasury.move(g, &"", 5, &"dev"))


func test_planted_overflow_is_refused() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	var before := g.digest()
	assert_false(Treasury.move(g, &"AAA", 3000000000, &"dev"), "3,000,000,000 is refused")
	assert_false(Treasury.move(g, &"AAA", -3000000000, &"dev"))
	assert_eq(g.digest(), before)
	c.treasury = 1900000000
	assert_false(Treasury.move(g, &"AAA", 200000000, &"dev"), "the sum would pass the limit")
	assert_eq(c.treasury, 1900000000)
	assert_eq(c.ledger_open.size(), 0)
	assert_true(Treasury.move(g, &"AAA", 100000000, &"dev"), "exactly at the limit is fine")
	assert_false(Treasury.move(g, &"AAA", 1, &"dev"))
	c.treasury = 0
	c.ledger_open[0]["amount"] = 2000000000
	assert_false(Treasury.move(g, &"AAA", 1, &"dev"), "a line that would pass the limit is refused too")
	assert_eq(c.treasury, 0)
	assert_true(Treasury.move(g, &"AAA", -2000000000, &"dev"))
	assert_eq(c.treasury, -2000000000)
