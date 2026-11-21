## Stores (docs/architecture/m4-build-spec.md 4.2, 4.8, 4.12, 5.3 and 9): the one door of goods, the flows of a season,
## `close`, `short_of` and the start stores. Planted faults: a move below zero, an unknown flow and an unknown good.
extends GutTest

const GRAIN := 0
const FISH := 1
const OIL := 2
const WINE := 3
const SALT := 4
const TIMBER := 11
const STONE := 12
const IRON := 13


func _game() -> Game:
	var g := ScenarioFixture.game()
	Stores.setup(g)
	return g


func _country(g: Game, tag: StringName) -> Country:
	return Countries.by_tag(g, tag)


func test_owns_and_flows_table() -> void:
	assert_eq(Stores.OWNS, ["stock", "flows_open", "stock_from", "goods_closed"])
	assert_eq(Stores.FLOWS, [&"made", &"used", &"sold", &"work", &"refund", &"dev", &"army", &"raise"] as Array[StringName])
	assert_eq(Country.FLOW_COUNT, Stores.FLOWS.size(), "Country lays out as many flows as Stores has")


func test_setup_stores_at_the_reserve_for_a_planted_town() -> void:
	var g := ScenarioFixture.game()
	var c := _country(g, &"AAA")
	for i: int in g.map.hex_count():
		if g.state.owner[i] == c.id:
			g.state.main_use[i] = 0
			g.state.level[i] = 0
	var cap := g.map.index_of(ScenarioFixture.ALPHA_CAPITAL)
	g.state.main_use[cap] = 1
	g.state.level[cap] = 4   # a walled town: 30,000 people
	People.setup(g)   # people are the state's (M5): the planted land starts with its table
	c.stock = PackedInt32Array([9])
	Stores.setup(g)
	assert_eq(c.stock.size(), 16)
	assert_eq(c.stock[GRAIN], 4 * 3, "four seasons of food: 30,000 x 100 / 1,000,000 = 3 a season")
	assert_eq(c.stock[FISH], 0)
	assert_eq(c.stock[WINE], 4 * 1, "wine need 30,000 x 20 / 1,000,000 = 0.6, rounded up to 1")
	assert_eq(c.stock[OIL], 4 * 1)
	assert_eq(c.stock[SALT], 4 * 1)
	assert_eq(c.stock[TIMBER], 40)
	assert_eq(c.stock[STONE], 40)
	assert_eq(c.stock[IRON], 20)
	# M6 (spec 5.1): horses and copper keep a fixed reserve of 10 and 5; the other wares keep none.
	assert_eq(c.stock[10], 10, "horses keep 10")
	assert_eq(c.stock[14], 5, "copper keeps 5")
	for good: int in [5, 6, 7, 8, 9, 15]:
		assert_eq(c.stock[good], 0, "a ware has no reserve")
	assert_eq(c.stock_from, c.stock)
	assert_eq(c.flows_open.size(), 16 * Stores.FLOWS.size())
	assert_eq(c.flows_open.count(0), c.flows_open.size())
	assert_true(c.goods_closed.is_empty())


func test_need_is_rounded_up_and_zero_people_need_nothing() -> void:
	assert_eq(Stores.need_of(129000, 100), 13)
	assert_eq(Stores.need_of(129000, 20), 3)
	assert_eq(Stores.need_of(129000, 10), 2)
	assert_eq(Stores.need_of(0, 100), 0)
	assert_eq(Stores.need_of(1000, 100), 1)


func test_move_changes_stock_and_flows_by_reason() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	var start := c.stock[WINE]
	assert_true(Stores.move(g, &"AAA", WINE, 20, &"made"))
	assert_true(Stores.move(g, &"AAA", WINE, -6, &"used"))
	assert_true(Stores.move(g, &"AAA", WINE, -4, &"sold"))
	assert_true(Stores.move(g, &"AAA", WINE, 3, &"made"))
	assert_eq(c.stock[WINE], start + 13)
	assert_eq(Stores.flow(c, WINE, &"made"), 23)
	assert_eq(Stores.flow(c, WINE, &"used"), -6)
	assert_eq(Stores.flow(c, WINE, &"sold"), -4)
	assert_eq(Stores.flow(c, WINE, &"work"), 0)
	assert_eq(Stores.flow(c, OIL, &"made"), 0, "another good is untouched")
	assert_eq(Stores.flow(c, WINE, &"nonsense"), 0)
	assert_eq(c.flows_open[0 * 16 + WINE], 23, "flow-major: flow * goods + good")
	assert_eq(c.flows_open[1 * 16 + WINE], -6)
	assert_eq(c.flows_open[2 * 16 + WINE], -4)
	assert_eq(Stores.flow(null, WINE, &"made"), 0)
	assert_eq(c.stock_from[WINE], start, "stock_from waits for close")


func test_planted_faults_are_refused_and_change_nothing() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	var before := g.digest()
	assert_false(Stores.move(g, &"AAA", WINE, -(c.stock[WINE] + 1), &"used"), "below zero")
	assert_false(Stores.move(g, &"AAA", WINE, 5, &"gift"), "an unknown flow")
	assert_false(Stores.move(g, &"AAA", 16, 5, &"made"), "an unknown good")
	assert_false(Stores.move(g, &"AAA", -1, 5, &"made"), "a negative good")
	assert_false(Stores.move(g, &"ZZZ", WINE, 5, &"made"), "an unknown tag")
	assert_eq(g.digest(), before)
	assert_true(Stores.move(g, &"AAA", WINE, -c.stock[WINE], &"used"), "down to exactly zero is fine")
	assert_eq(c.stock[WINE], 0)


func test_close_moves_the_flows_and_the_property_holds() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	var opening := c.stock.duplicate()
	Stores.move(g, &"AAA", GRAIN, 30, &"made")
	Stores.move(g, &"AAA", GRAIN, -5, &"used")
	Stores.move(g, &"AAA", STONE, -12, &"work")
	Stores.move(g, &"AAA", STONE, 12, &"refund")
	Stores.move(g, &"AAA", IRON, 4, &"dev")
	g.turn = 7
	Stores.close(g)
	assert_eq(c.goods_closed["turn"], 7)
	assert_eq(c.goods_closed["opening"], opening)
	assert_eq(c.goods_closed["closing"], c.stock)
	var flows: PackedInt32Array = c.goods_closed["flows"]
	for good: int in 16:
		var sum := 0
		for f: int in Stores.FLOWS.size():
			sum += flows[f * 16 + good]
		assert_eq(c.stock[good] - opening[good], sum, "closing - opening = flows, good %d" % good)
	assert_eq(Stores.flow(c, GRAIN, &"made", true), 30)
	assert_eq(Stores.flow(c, GRAIN, &"made"), 0, "the open season starts again")
	assert_eq(c.flows_open.count(0), c.flows_open.size())
	assert_eq(c.stock_from, c.stock)
	var other := _country(g, &"BBB")
	assert_eq(other.goods_closed["turn"], 7)
	# The next season does not touch the closed copy.
	Stores.move(g, &"AAA", GRAIN, 1, &"made")
	assert_eq(Stores.flow(c, GRAIN, &"made", true), 30)
	assert_eq(Stores.flow(_country(g, &"BBB"), GRAIN, &"made", true), 0)


func test_short_of_words() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	assert_eq(Stores.short_of(g, &"AAA", {}), "")
	assert_eq(Stores.short_of(g, &"AAA", {"stone": 40}), "", "exactly what is in store")
	assert_eq(Stores.short_of(g, &"AAA", {"stone": 41}), "not enough stone: 41 needed, 40 in store")
	assert_eq(Stores.short_of(g, &"AAA", {&"iron": 21}), "not enough iron: 21 needed, 20 in store", "StringName keys too")
	# The first short good in good id order: wine (3) comes before stone (12).
	var want := "not enough wine: %d needed, %d in store" % [c.stock[WINE] + 1, c.stock[WINE]]
	assert_eq(Stores.short_of(g, &"AAA", {"stone": 99, "wine": c.stock[WINE] + 1}), want)
	assert_eq(Stores.short_of(g, &"ZZZ", {"stone": 1}), "not enough stone: 1 needed, 0 in store")
	assert_eq(Stores.short_of(g, &"ZZZ", {}), "")


func test_a_game_without_goods_has_empty_stores() -> void:
	var f := ScenarioFixture.build()
	var defs := f["defs"] as GameDefs
	defs.goods = []
	var g := Game.new_scenario(f["map"] as MapData, defs, f["scenario"] as ScenarioDef, 1)
	Stores.setup(g)
	assert_eq(_country(g, &"AAA").stock.size(), 0)
	assert_false(Stores.move(g, &"AAA", 0, 1, &"made"))
	assert_eq(Stores.short_of(g, &"AAA", {"stone": 1}), "")


func test_planted_overflow_is_refused() -> void:
	var g := _game()
	var c := _country(g, &"AAA")
	var before := g.digest()
	assert_false(Stores.move(g, &"AAA", WINE, 3000000000, &"dev"), "a dev_goods of 3,000,000,000 is refused")
	assert_eq(g.digest(), before)
	assert_gt(c.stock[WINE], -1)
	c.stock[WINE] = 1999999999
	assert_false(Stores.move(g, &"AAA", WINE, 2, &"made"), "the stock would pass the limit")
	assert_eq(c.stock[WINE], 1999999999)
	assert_true(Stores.move(g, &"AAA", WINE, 1, &"made"))
	assert_eq(c.stock[WINE], Stores.LIMIT)
	# A flow cell that would pass the limit is refused even when the stock is fine.
	c.stock[WINE] = 0
	c.flows_open[0 * 16 + WINE] = 1999999999
	assert_false(Stores.move(g, &"AAA", WINE, 5, &"made"))
	assert_eq(c.flows_open[0 * 16 + WINE], 1999999999)
	assert_eq(c.stock[WINE], 0)


func test_start_stores_and_people_come_from_economy_season() -> void:
	var g := _game()
	var view := StateView.of(g.state)
	for c: Country in g.countries:
		assert_eq(c.stock, EconomySeason.reserve_of(g, view, c.tag), "%s" % c.tag)
		assert_eq(Stores.start_people(g, c.tag),
			Vector2i(EconomySeason.town_people(g, view, c.tag), EconomySeason.country_people(g, view, c.tag)))
