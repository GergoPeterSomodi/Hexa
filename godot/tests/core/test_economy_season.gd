## A country's season, the pure part (core/systems/economy_season.gd; docs/architecture/m4-build-spec.md 4.7 to 4.9, 4.15 (a)
## and (d), 5.3): people, needs (ceil), reserve, goods_step (fish first, satisfactions, sales down to the reserve, never
## below zero), content and factor, money_lines against 4.9 by hand, Genoa's first year, debt_limit and the stubs.
extends GutTest

@warning_ignore_start("integer_division")

const DEFS_PATH := "res://data/defs/game_defs.tres"
const MAP_PATH := "res://data/maps/north_italy.tres"
const SCEN_PATH := "res://data/scenarios/north_italy_1480.tres"
const CALM := [0, 0, 0]
const GRAIN := 0
const FISH := 1
const OIL := 2
const WINE := 3
const SALT := 4
const TIMBER := 11

var _defs: GameDefs
var _game: Game


func before_all() -> void:
	_defs = ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	var map := ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var scen := ResourceLoader.load(SCEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef
	_game = Game.new_scenario(map, _defs, scen, 1480)


func _view() -> StateView:
	return StateView.of(_game.state)


func _arr(values: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(16)
	for g: int in values:
		out[g] = values[g]
	return out


func _prices() -> PackedInt32Array:
	return Economy.market_prices(_game, _view(), 7, PackedInt32Array())


func _needs(food: int, wine: int, salt: int, oil: int) -> Dictionary:
	return {"food": food, "wine": wine, "salt": salt, "oil": oil}


func test_people_needs_and_reserve_of_genoa() -> void:
	assert_eq(EconomySeason.town_people(_game, _view(), &"GEN"), 40000)
	assert_eq(EconomySeason.country_people(_game, _view(), &"GEN"), 42700)
	assert_eq(EconomySeason.town_people(_game, _view(), &"ZZZ"), 0)
	var needs := EconomySeason.needs_of(_game, _view(), &"GEN")
	assert_eq(needs, _needs(4, 1, 1, 1), "ceil: 40,000 people need 0.4 loads of oil")
	var reserve := EconomySeason.reserve_of(_game, _view(), &"GEN")
	assert_eq(reserve, _arr({GRAIN: 16, OIL: 4, WINE: 4, SALT: 4, TIMBER: 40, 12: 40, 13: 20}))


func test_need_loads_rounds_up_and_nothing_for_no_people() -> void:
	assert_eq(EconomySeason.need_loads(0, 100), 0)
	assert_eq(EconomySeason.need_loads(1, 10), 1)
	assert_eq(EconomySeason.need_loads(10000, 100), 1)
	assert_eq(EconomySeason.need_loads(10001, 100), 2)
	assert_eq(EconomySeason.need_loads(30000, 20), 1)


func test_goods_step_eats_fish_first_then_grain() -> void:
	var needs := _needs(4, 0, 0, 0)
	var reserve := _arr({GRAIN: 16})
	var step := EconomySeason.goods_step(_game, needs, reserve, _arr({GRAIN: 16}), _arr({GRAIN: 2, FISH: 6}), _prices())
	assert_eq(step["used"][FISH], 4)
	assert_eq(step["used"][GRAIN], 0)
	assert_eq(step["sold"][FISH], 2, "the fish left over is sold: no reserve")
	assert_eq(step["sold"][GRAIN], 2)
	assert_eq(step["sales_milli"], 4000)
	var short := EconomySeason.goods_step(_game, needs, reserve, _arr({GRAIN: 16}), _arr({FISH: 1}), _prices())
	assert_eq(short["used"][FISH], 1)
	assert_eq(short["used"][GRAIN], 3, "grain makes up the rest")
	assert_eq(short["stock"][GRAIN], 13)
	assert_eq(short["taken"]["food"], 4)
	assert_eq(short["satisfaction"]["food"], 1000)


func test_goods_step_satisfaction_content_and_never_below_zero() -> void:
	var needs := _needs(4, 2, 1, 1)
	var step := EconomySeason.goods_step(_game, needs, _arr({}), _arr({GRAIN: 1, WINE: 1, OIL: 5}), _arr({}), _prices())
	assert_eq(step["taken"], {"food": 1, "wine": 1, "salt": 0, "oil": 1})
	assert_eq(step["satisfaction"], {"food": 250, "wine": 500, "salt": 0, "oil": 1000})
	# (700 x 250 + 100 x 500 + 100 x 0 + 100 x 1000) / 1000 = 325
	assert_eq(step["content"], 325)
	for g: int in 16:
		assert_true(step["stock"][g] >= 0, "good %d" % g)
	assert_eq(step["stock"][OIL], 0, "no reserve: the rest of the oil is sold")
	assert_eq(step["sold"][OIL], 4)
	assert_eq(step["sales_milli"], 4 * 2500)
	assert_eq(EconomySeason.content_of(_game, needs, step["used"]), 325)
	# A need of 0 is fully met.
	var calm := EconomySeason.goods_step(_game, _needs(0, 0, 0, 0), _arr({}), _arr({}), _arr({}), _prices())
	assert_eq(calm["content"], 1000)
	assert_eq(calm["satisfaction"]["salt"], 1000)


func test_stock_below_the_reserve_sells_nothing() -> void:
	var step := EconomySeason.goods_step(_game, _needs(0, 0, 0, 0), _arr({WINE: 4}), _arr({WINE: 3}), _arr({WINE: 1}), _prices())
	assert_eq(step["sold"][WINE], 0)
	assert_eq(step["stock"][WINE], 4)
	var more := EconomySeason.goods_step(_game, _needs(0, 0, 0, 0), _arr({WINE: 4}), _arr({WINE: 3}), _arr({WINE: 5}), _prices())
	assert_eq(more["sold"][WINE], 4)
	assert_eq(more["stock"][WINE], 4)


func test_factor_from_content() -> void:
	assert_eq(EconomySeason.factor_of(_game, 1000), 1000)
	assert_eq(EconomySeason.factor_of(_game, 0), 750)
	assert_eq(EconomySeason.factor_of(_game, 900), 975)


func test_money_lines_by_hand() -> void:
	var made := {
		"dues": [{"hex": Vector2i(8, 13), "amount": 30}], "upkeep": 12, "upkeep_count": 5,
		"walls": [{"hex": Vector2i(8, 13), "amount": 4}],
	}
	var lines := EconomySeason.money_lines(_game, _view(), &"GEN", 1, 1000, 10000, made)
	var why: Array[StringName] = []
	var sum := 0
	for line: Dictionary in lines:
		why.append(line["why"])
		sum += int(line["amount"])
	assert_eq(why, [&"tax_people", &"tax_goods", &"port_dues", &"upkeep_districts", &"upkeep_walls"] as Array[StringName])
	assert_eq(lines[0], {"why": &"tax_people", "hex": Treasury.NO_HEX, "amount": 65, "count": 1})
	assert_eq(lines[1]["amount"], 7)
	assert_eq(lines[2], {"why": &"port_dues", "hex": Vector2i(8, 13), "amount": 30, "count": 1})
	assert_eq(lines[3], {"why": &"upkeep_districts", "hex": Treasury.NO_HEX, "amount": -12, "count": 5})
	assert_eq(lines[4]["amount"], -4)
	assert_eq(sum, 86)
	# The tax level scales the people's and the goods' taxes, never the dues.
	var low := EconomySeason.money_lines(_game, _view(), &"GEN", 0, 1000, 10000, made)
	assert_eq(low[0]["amount"], 45)  # 65,620,000 x 700 / 10^9
	assert_eq(low[1]["amount"], 5)
	assert_eq(low[2]["amount"], 30)
	var high := EconomySeason.money_lines(_game, _view(), &"GEN", 2, 1000, 10000, made)
	assert_eq(high[0]["amount"], 91)
	assert_eq(high[1]["amount"], 9)
	# Zero lines are left out.
	var none := EconomySeason.money_lines(_game, _view(), &"ZZZ", 1, 1000, 0, {})
	assert_eq(none.size(), 0)


func test_genoas_first_year_equals_4_15_a() -> void:
	var weather := PackedByteArray(CALM)
	var reserve := EconomySeason.reserve_of(_game, _view(), &"GEN")
	var needs := EconomySeason.needs_of(_game, _view(), &"GEN")
	var prices := _prices()
	var stock := reserve.duplicate()
	var treasury := 610
	# made, sold, the lines (people, goods, dues, upkeep, walls), the net and the treasury after, per season.
	var years: Array = [
		[{GRAIN: 2, FISH: 6, TIMBER: 6}, {GRAIN: 2, FISH: 2, TIMBER: 6}, [65, 7, 30, -12, -4], 86, 696],
		[{GRAIN: 6, FISH: 6, TIMBER: 6}, {GRAIN: 6, FISH: 2, TIMBER: 6}, [65, 9, 33, -12, -4], 91, 787],
		[{GRAIN: 4, FISH: 6, OIL: 14, WINE: 24, TIMBER: 12}, {GRAIN: 4, FISH: 2, OIL: 11, WINE: 21, TIMBER: 12},
			[65, 68, 30, -12, -4], 147, 934],
		[{GRAIN: 1, FISH: 4, OIL: 28, TIMBER: 23}, {GRAIN: 1, OIL: 27, TIMBER: 23}, [65, 64, 21, -12, -4], 134, 1068],
	]
	for season: int in 4:
		var info := EconomySeason.made_of(_game, _view(), &"GEN", season, weather, 1)
		var row: Array = years[season]
		assert_eq(info["made"], _arr(row[0]), "made, season %d" % season)
		var step := EconomySeason.goods_step(_game, needs, reserve, stock, info["made"], prices)
		assert_eq(step["used"], _arr({FISH: 4, OIL: 1, WINE: 1, SALT: 1}), "used, season %d" % season)
		assert_eq(step["sold"], _arr(row[1]), "sold, season %d" % season)
		assert_eq(step["content"], 1000)
		var lines := EconomySeason.money_lines(_game, _view(), &"GEN", 1, step["content"], step["sales_milli"], info)
		var amounts: Array[int] = []
		var net := 0
		for line: Dictionary in lines:
			amounts.append(line["amount"])
			net += int(line["amount"])
		assert_eq(amounts, row[2], "lines, season %d" % season)
		assert_eq(net, row[3])
		treasury += net
		assert_eq(treasury, row[4])
		stock = step["stock"]
		assert_eq(info["upkeep"], 12)
		assert_eq(info["upkeep_count"], 5)
	# Salt ran out in Winter 1480: salt's satisfaction is 0 from Spring 1481, contentment 900, the factor 975.
	assert_eq(stock[SALT], 0)
	var info := EconomySeason.made_of(_game, _view(), &"GEN", 0, PackedByteArray(CALM), 1)
	var step := EconomySeason.goods_step(_game, needs, reserve, stock, info["made"], prices)
	assert_eq(step["satisfaction"]["salt"], 0)
	assert_eq(step["content"], 900)
	var lines := EconomySeason.money_lines(_game, _view(), &"GEN", 1, step["content"], step["sales_milli"], info)
	assert_eq(lines[0]["amount"], 64)


func test_genoa_as_a_city_taxes_and_needs_4_15_d() -> void:
	# M5: an upgrade brings room, not people, so the view says that Genoa's people stand at the city's 60,000 (M4's table).
	var i := _game.map.index_of(Vector2i(8, 13))
	var view := _view().with({i: Vector2i(1, 5)}).with_people({i: 60000})
	assert_eq(EconomySeason.town_people(_game, view, &"GEN"), 70000)
	assert_eq(EconomySeason.needs_of(_game, view, &"GEN")["food"], 7)
	var info := EconomySeason.made_of(_game, view, &"GEN", 0, PackedByteArray(CALM), 1)
	assert_eq(info["upkeep"], 15, "the country's upkeep: Genoa's 2 becomes 5")
	assert_eq(info["walls"][0]["amount"], 6, "Genoa's upkeep and walls 6 -> 11")
	assert_eq(info["dues"][0]["amount"], 45)
	assert_eq(info["made"][FISH], 10)
	var lines := EconomySeason.money_lines(_game, view, &"GEN", 1, 1000, 0, info)
	assert_eq(lines[0]["amount"], 95, "taxes on people 65 -> 95")


func test_made_of_equals_the_sum_of_district_output_and_ignores_other_countries() -> void:
	var map := _game.map
	var genoa := Countries.by_tag(_game, &"GEN")
	var made := PackedInt32Array()
	made.resize(16)
	for season: int in 4:
		made.fill(0)
		for i: int in map.hex_count():
			if _game.state.owner[i] != genoa.id or map.land[i] == 0:
				continue
			var out := Economy.district_output(_game, _view(), map.hex_of(i), season)
			for g: int in 16:
				made[g] += out["goods"][g]
		var info := EconomySeason.made_of(_game, _view(), &"GEN", season, PackedByteArray(CALM), 1)
		assert_eq(info["made"], made, "season %d" % season)
	var none := EconomySeason.made_of(_game, _view(), &"", 0, PackedByteArray(CALM), 1)
	assert_eq(none["upkeep"], 0)
	assert_eq(none["made"], _arr({}))


func test_made_of_weather_follows_the_hexs_climate() -> void:
	# Wild grain on frost farmland at (6, 13) is 3 loads in summer; poor frost weather makes it 2; snow weather changes nothing.
	var calm: PackedInt32Array = EconomySeason.made_of(_game, _view(), &"GEN", 1, PackedByteArray(CALM), 1)["made"]
	var poor_frost: PackedInt32Array = EconomySeason.made_of(_game, _view(), &"GEN", 1, PackedByteArray([0, 2, 0]), 1)["made"]
	var poor_snow: PackedInt32Array = EconomySeason.made_of(_game, _view(), &"GEN", 1, PackedByteArray([2, 0, 0]), 1)["made"]
	assert_eq(calm[GRAIN], 6)
	assert_eq(poor_frost[GRAIN], 5, "(6, 13) frost: 3 -> 2")
	assert_eq(poor_snow[GRAIN], 6)


func test_debt_limit_and_the_constants() -> void:
	assert_eq(EconomySeason.debt_limit(_game, &"GEN"), 0)
	assert_eq(EconomySeason.OWNS, ["tax", "short_mask"])
	assert_eq(Economy.OWNS, [])
	assert_eq(EconomySeason.NEEDS, [&"food", &"wine", &"salt", &"oil"] as Array[StringName])


# ----- the phases and the tax pair (task N4; m4-build-spec.md 4.7 to 4.10) ------------------------------------------------


func _fresh() -> Game:
	return EconomyFixture.game(&"GEN")


func test_set_tax_check_rows_in_order() -> void:
	var g := _fresh()
	var sandbox := Game.new_game(EconomyFixture.map(), 1, EconomyFixture.committed())
	assert_eq(EconomySeason.set_tax_check(sandbox, {"level": 2, "tag": &"GEN"})["reason"], "this map has no countries")
	assert_eq(EconomySeason.set_tax_check(g, {"level": 2})["reason"], "choose your country first")
	assert_eq(EconomySeason.set_tax_check(g, {"level": 2, "tag": &"ZZZ"})["reason"], "no country ZZZ")
	Countries.by_tag(g, &"FRA").alive = false
	assert_string_contains(str(EconomySeason.set_tax_check(g, {"level": 2, "tag": &"FRA"})["reason"]), "is no more")
	for bad: Variant in [3, -1, "high", null, 1.0]:
		assert_eq(EconomySeason.set_tax_check(g, {"level": bad, "tag": &"GEN"})["reason"], "no such tax level", str(bad))
	assert_eq(EconomySeason.set_tax_check(g, {"level": 1, "tag": &"GEN"})["reason"], "taxes are already Normal")
	assert_eq(EconomySeason.set_tax_check(g, {"level": 2, "tag": "GEN"}), {"ok": true, "reason": ""}, "a String tag too")


func test_set_tax_writes_the_level_emits_and_changes_back_for_nothing() -> void:
	var g := _fresh()
	var c := Countries.by_tag(g, &"GEN")
	g.events.clear()
	var treasury := c.treasury
	assert_true(bool(g.act("set_tax", {"level": 2, "tag": &"GEN"})["ok"]))
	assert_eq(c.tax, 2)
	assert_eq(g.events.size(), 1)
	assert_eq([g.events[0]["kind"], g.events[0]["tag"], g.events[0]["level"], g.events[0]["from"]], ["tax_set", &"GEN", 2, 1])
	assert_false(bool(g.act("set_tax", {"level": 2, "tag": &"GEN"})["ok"]), "taxes are already High")
	assert_true(bool(g.act("set_tax", {"level": 1, "tag": &"GEN"})["ok"]))
	assert_eq(c.treasury, treasury, "a change and a change back cost nothing")
	assert_eq(g.action_log.size(), 3, "choose_country and the two changes are logged, the refusal is not")


func test_the_tax_level_moves_taxes_and_not_port_dues() -> void:
	var results := {}
	for level: int in 3:
		var g := _fresh()
		if level != 1:
			g.act("set_tax", {"level": level, "tag": &"GEN"})
		Season.run(g)
		var c := Countries.by_tag(g, &"GEN")
		results[level] = EconomyFixture.totals(c.ledger_closed["lines"] as Array)
	assert_eq(int(results[1]["tax_people"]), 65)
	assert_eq(int(results[0]["tax_people"]), 45, "(40,000 x 1,000 + 42,700 x 600) x 700 / 10^9 = 45.9")
	assert_eq(int(results[2]["tax_people"]), 91, "x 1,400: 91.8")
	assert_eq(int(results[0]["port_dues"]), 30, "port dues are customs: the tax level does not change them")
	assert_eq(int(results[2]["port_dues"]), 30)


func test_production_moves_every_good_through_stores_with_the_three_flows() -> void:
	var g := _fresh()
	var c := Countries.by_tag(g, &"GEN")
	Season.begin(g)
	Season.run_phase(g, &"production")
	assert_eq(Stores.flow(c, 0, &"made"), 2)
	assert_eq(Stores.flow(c, 1, &"made"), 6)
	assert_eq(Stores.flow(c, 1, &"used"), -4)
	assert_eq(Stores.flow(c, 1, &"sold"), -2)
	assert_eq(Stores.flow(c, 11, &"sold"), -6, "timber made 6 and sold down to the reserve of 40")
	assert_eq(c.stock[11], 40)
	assert_eq(c.treasury, 610, "production touches no money")
	assert_true(c.ledger_open.is_empty())
	Season.run_phase(g, &"income")
	assert_eq(c.treasury, 696)
	assert_eq(c.stock[11], 40, "income touches no goods")


func test_a_country_that_is_no_more_has_no_season() -> void:
	var dead := _fresh()
	var france := Countries.by_tag(dead, &"FRA")
	france.alive = false
	var before := france.treasury
	Season.begin(dead)
	Season.run_phase(dead, &"production")
	Season.run_phase(dead, &"income")
	assert_eq(france.treasury, before)
	assert_true(france.ledger_open.is_empty())


func test_every_country_runs_both_phases() -> void:
	var g := _fresh()
	var before: Array[int] = []
	for c: Country in g.countries:
		before.append(c.treasury)
	Season.run(g)
	for n: int in g.countries.size():
		assert_ne(g.countries[n].treasury, before[n], "%s earned something" % g.countries[n].tag)
		assert_eq(int(g.countries[n].ledger_closed["turn"]), 1)


func _shorts(g: Game) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in g.events:
		if str(e["kind"]) == "goods_short" and e["tag"] == &"GEN":
			out.append(e)
	return out


func _finish_season(g: Game) -> void:
	for phase: StringName in [&"income", &"works", &"stats", &"calendar"]:
		Season.run_phase(g, phase)


func test_goods_short_fires_once_a_run_of_shortage_and_again_after_a_meal() -> void:
	var g := _fresh()
	var c := Countries.by_tag(g, &"GEN")
	assert_true(g.dev_goods(&"GEN", 4, -4), "the salt is taken from the stores")
	g.events.clear()
	Season.begin(g)
	Season.run_phase(g, &"production")
	var shorts := _shorts(g)
	assert_eq(shorts.size(), 1)
	assert_eq([shorts[0]["good"], shorts[0]["need"], shorts[0]["taken"]], [&"salt", 1, 0])
	assert_eq(c.short_mask, 1 << 2)
	_finish_season(g)
	g.events.clear()
	Season.run_phase(g, &"production")
	assert_eq(_shorts(g).size(), 0, "still short: said once")
	_finish_season(g)
	assert_true(g.dev_goods(&"GEN", 4, 2))
	Season.run_phase(g, &"production")
	assert_eq(c.short_mask, 0, "met again: the bit is clear")
	_finish_season(g)
	assert_true(g.dev_goods(&"GEN", 4, -c.stock[4]))
	g.events.clear()
	Season.run_phase(g, &"production")
	assert_eq(_shorts(g).size(), 1, "short again: said again")


func test_a_map_only_game_runs_the_phases_for_nothing() -> void:
	var sandbox := Game.new_game(EconomyFixture.map(), 1, EconomyFixture.committed())
	var before := sandbox.digest()
	EconomySeason.production(sandbox)
	EconomySeason.income(sandbox)
	assert_eq(sandbox.digest(), before)
	assert_true(sandbox.events.is_empty())
