## The worked example of docs/architecture/m6-build-spec.md 4.13 on "Italy, 1480", seed 1480, as Savoy, calm weather, people
## growing (done-when 1 to 3; L13). (a) raising at Turin, (b) across the Po, (c) across the Little St Bernard, (d) out of
## supply to (4, 8), and (e) upkeep and the report's lines of Spring 1480. Numbers as the spec states them; a number the
## code does not give is a finding for the report, not a number to change here.
extends GutTest

const SAV := &"SAV"
const TURIN := Vector2i(5, 9)
const VERCELLI := Vector2i(6, 9)
const MONT_CENIS := Vector2i(3, 9)
const SADDLE := Vector2i(3, 7)
const AOSTA := Vector2i(3, 8)
const SNOW := Vector2i(4, 8)
const SPRING_1480 := 1
const SUMMER_1480 := 2
const AUTUMN_1480 := 3
const WINTER_1480 := 4
const SPRING_1481 := 5
const TURIN_PEOPLE := 10000
const TREASURY := 1500
const IRON := 20
const TURIN_REASON := "Turin (5, 9) has raised its 2 companies this season"

var _g: Game = null


## Savoy on the 1480 scenario: calm weather, Normal taxes, the treasury at 1,500 and iron at 20, Turin a town of 10,000.
func before_each() -> void:
	_g = EconomyFixture.game(SAV, false, true, EconomyFixture.SEED, false)
	Movement.clear_test_hostility()
	var c := Countries.by_tag(_g, SAV)
	assert_true(_g.dev_money(SAV, TREASURY - c.treasury), "the treasury is set to 1,500")
	var iron := _g.defs.good_id(&"iron")
	assert_true(_g.dev_goods(SAV, iron, IRON - c.stock[iron]), "iron 20 in store")
	ArmyFixture.people_at(_g, TURIN, TURIN_PEOPLE)
	_g.districts.clear()
	_g.version += 1


func after_each() -> void:
	Movement.clear_test_hostility()


func _iron() -> int:
	return _g.defs.good_id(&"iron")


func _raise_two() -> Army:
	var verdict := _g.act("raise", {"hex": TURIN, "kind": 0, "count": 2, "tag": SAV})
	assert_true(bool(verdict["ok"]), "two companies are raised at Turin: %s" % verdict["reason"])
	return Armies.at(_g, TURIN)[0]


func _moved(army_id: int) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == "unit_moved" and int(e.get("army", -1)) == army_id:
			out.append(e)
	return out


func _path(hexes: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h: Variant in hexes:
		out.append(h as Vector2i)
	return out


func _men(a: Army) -> int:
	return a.men()


# ----- (a) and (e): raising, the ledger, the people, the upkeep ----------------------------------------------------------


func test_a_raising_at_turin_costs_fifty_ducats_and_two_iron() -> void:
	var c := Countries.by_tag(_g, SAV)
	var treasury := c.treasury
	var iron := c.stock[_iron()]
	var a := _raise_two()
	assert_eq(c.treasury, treasury - 50, "two companies of pikemen cost 50 ducats")
	assert_eq(c.stock[_iron()], iron - 2, "and 2 iron")
	assert_eq(a.name, "Army of Turin")
	assert_eq(a.hex, TURIN)
	assert_eq(a.units.size(), 2)
	assert_eq(a.units[0].id, 1)
	assert_eq(a.units[1].id, 2)
	assert_eq(_men(a), 1000, "1,000 men: 500 a company")
	assert_eq(a.order, Army.ORDER_NONE)
	assert_eq(int(_g.state.people[_g.map.index_of(TURIN)]), TURIN_PEOPLE - 1000, "Turin 10,000 -> 9,000 people")
	assert_eq(c.people_flows[People.FLOWS.find(&"raised")], -1000, "the flow raised, 1,000")


func test_a_a_third_raise_at_turin_is_refused_this_season() -> void:
	_raise_two()
	var verdict := _g.act("raise", {"hex": TURIN, "kind": 0, "count": 1, "tag": SAV})
	assert_false(bool(verdict["ok"]))
	assert_eq(str(verdict["reason"]), TURIN_REASON)


func test_e_the_spring_income_pays_the_upkeep_of_one_army() -> void:
	var c := Countries.by_tag(_g, SAV)
	_raise_two()
	var before := c.treasury
	assert_true(bool(Season.run(_g)["ok"]))
	assert_eq(_g.stats.value(SAV, SPRING_1480, "upkeep_army"), 12, "Army upkeep, 1 army: -12")
	assert_eq(_g.stats.value(SAV, SPRING_1480, "army_raised"), 1000, "the men raised in spring")
	var lines := c.ledger_closed["lines"] as Array
	var raise_lines := 0
	for line: Dictionary in lines:
		if line["why"] == &"raise" and int(line["amount"]) == -50:
			raise_lines += 1
	assert_eq(raise_lines, 1, "one raise line of -50 in the closed ledger")
	assert_eq(c.ledger_closed["turn"], SPRING_1480)


# ----- (b): across the Po, on the wooden bridge -----------------------------------------------------------------------


func test_b_ordered_to_vercelli_it_musters_in_spring_and_walks_the_bridge_in_summer() -> void:
	var a := _raise_two()
	assert_true(bool(Movement.march(_g, {"army": a.id, "goal": VERCELLI, "tag": SAV}).ok))
	Season.run(_g)
	assert_eq(a.hex, TURIN, "it musters in spring")
	assert_eq(_men(a), 1000)
	Season.run(_g)  # summer
	assert_eq(a.hex, VERCELLI, "in summer it walks across the Po")
	var walk := _moved(a.id)
	assert_eq(walk.size(), 1)
	assert_eq(walk[0]["path"], _path([TURIN, VERCELLI]), "the route is the one step over the bridge")
	assert_eq(Array(walk[0]["ticks"]), [1])
	assert_true(bool(walk[0]["arrived"]))
	assert_eq(a.order, Army.ORDER_HOLD, "it holds at Vercelli from here")
	assert_eq(_men(a), 1000, "no hunger on the bridge: Vercelli is in supply")


# ----- (c): across the Little St Bernard, through Turin ---------------------------------------------------------------


func test_c_the_route_to_aosta_by_turin_costs_fifteen_and_waits_for_spring() -> void:
	_g.turn = AUTUMN_1480
	var a := ArmyFixture.army(_g, SAV, VERCELLI, 0, 2, SPRING_1480)
	var plan := Movement.plan(_g, a, AOSTA)
	assert_true(bool(plan["ok"]))
	assert_eq(int(plan["cost"]), 15, "the route by Turin costs 15 points")
	assert_true(bool(Movement.march(_g, {"army": a.id, "goal": AOSTA, "tag": SAV}).ok))
	Season.run(_g)  # autumn walks to the saddle
	assert_eq(a.hex, SADDLE, "ten points to the saddle; the step of five waits")
	Season.run(_g)  # winter: the pass edge is closed by snow
	assert_eq(a.hex, SADDLE)
	assert_eq(a.waiting, Movement.WHY_WINTER, "it waits for spring")
	Season.run(_g)  # spring 1481 crosses the pass edge
	assert_eq(a.hex, AOSTA)
	assert_eq(a.order, Army.ORDER_HOLD)


# ----- (d): out of supply on the snow at (4, 8) -----------------------------------------------------------------------


func test_d_out_of_supply_on_the_snow_the_army_starves_from_1000_to_648_and_walks_home() -> void:
	var a := _raise_two()
	assert_true(bool(Movement.march(_g, {"army": a.id, "goal": SNOW, "tag": SAV}).ok))
	Season.run(_g)  # spring: it musters at Turin
	assert_eq(a.hex, TURIN)
	assert_eq(_men(a), 1000)
	Season.run(_g)  # summer walks the 11 points and starves: a tenth of its men
	assert_eq(a.hex, SNOW, "eleven points: the snow at 3,169 m")
	assert_false(Supply.in_supply(_g, SAV, SNOW, false), "out of supply in summer")
	assert_eq(_men(a), 900, "summer: 100 men of 1,000 starve")
	Season.run(_g)  # autumn
	assert_eq(_men(a), 810, "autumn: 90 of 900")
	assert_eq(a.hex, SNOW)
	Season.run(_g)  # winter 1480: a fifth of its men (the snow winter), still on the snow
	assert_false(Supply.in_supply(_g, SAV, SNOW, true), "out of supply in winter")
	assert_eq(_men(a), 648, "winter: 162 of 810 (starve_permille 200 in the snow winter)")
	assert_eq(a.hex, SNOW, "the snow holds it through winter")
	# The order home is given in the planning of spring 1481 (see the report): the walk is spring 1481's, one season.
	assert_true(bool(Movement.march(_g, {"army": a.id, "goal": TURIN, "tag": SAV}).ok), "ordered back to Turin")
	Season.run(_g)  # spring 1481 walks back to Turin, in supply again
	assert_eq(a.hex, TURIN, "back at Turin in spring 1481")
	assert_true(Supply.in_supply(_g, SAV, TURIN, false), "in supply at Turin")
	# Not in the spec's list: back in supply, ready_units refills each pikeman company by 50 (pikemen.tres refill 50) from
	# Turin's people, so 648 becomes 748 (see the report).
	assert_eq(_men(a), 748, "no more hunger; the refill of ready_units adds 50 a company at Turin")
