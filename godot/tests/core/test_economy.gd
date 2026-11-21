## The rules of one hex (core/systems/economy.gd; docs/architecture/m4-build-spec.md 4.3 to 4.5, 4.15 (a) and 5.3):
## every family, level and slot of the table of 4.4, wild yield and keep, staffing and the ring, lift, port fish and dues,
## weather, the tax's output, slot_of, people_at, the prices, floor_div, and district_output on north Italy.
extends GutTest

@warning_ignore_start("integer_division")

const DEFS_PATH := "res://data/defs/game_defs.tres"
const MAP_PATH := "res://data/maps/north_italy.tres"
const SCEN_PATH := "res://data/scenarios/north_italy_1480.tres"

## Table 4.4: id, base per level, season percents, weather-bound, keep wild per level, the frost year per level (at full
## staffing, Normal, calm; frost = the winter slot 4).
const FAMILIES: Array = [
	[3, [10, 20, 32], [20, 100, 40, 0, 0, 10], true, [0, 0, 0], [16, 32, 50]],
	[4, [10, 20, 32], [0, 50, 100, 0, 0, 0], true, [50, 25, 0], [15, 30, 48]],
	[5, [3, 6, 10], [100, 50, 0, 0, 0, 0], true, [50, 25, 0], [4, 9, 15]],
	[6, [2, 4, 7], [50, 100, 50, 0, 0, 0], true, [50, 25, 0], [4, 8, 13]],
	[7, [12, 24, 40], [0, 0, 100, 0, 0, 0], true, [50, 25, 0], [12, 24, 40]],
	[9, [8, 16, 26], [100, 120, 60, 0, 30, 30], true, [0, 0, 0], [23, 48, 79]],
	[10, [6, 12, 20], [50, 50, 50, 0, 150, 150], false, [0, 0, 0], [18, 36, 60]],
	[11, [4, 8, 14], [100, 100, 100, 0, 70, 100], false, [0, 0, 0], [14, 29, 51]],
	[12, [6, 12, 20], [100, 100, 100, 0, 70, 100], false, [0, 0, 0], [22, 44, 74]],
	[13, [4, 8, 14], [50, 150, 100, 0, 0, 20], true, [0, 0, 0], [12, 24, 42]],
	[14, [4, 8, 14], [100, 100, 100, 30, 50, 70], false, [0, 0, 0], [14, 28, 49]],
]
## The grazing and mining extras: family id, extra, good key, permille, the frost year per level.
const EXTRAS: Array = [
	[9, "sheep", &"wool", 1000, [23, 48, 79]],
	[9, "cattle", &"cattle", 750, [17, 36, 58]],
	[9, "horses", &"horses", 375, [7, 17, 27]],
	[11, "iron", &"iron", 1000, [14, 29, 51]],
	[11, "copper", &"copper", 750, [11, 22, 37]],
	[11, "silver", &"silver", 250, [3, 7, 11]],
]
## Genoa's land, spring to winter (4.15 a): hex -> [goods by key per season], dues per season.
const GENOA: Dictionary = {
	Vector2i(8, 11): [{}, {}, {&"timber": 1}, {&"timber": 1}],
	Vector2i(9, 11): [{}, {}, {&"timber": 1}, {}],
	Vector2i(7, 12): [{}, {}, {&"wine": 24}, {}],
	Vector2i(8, 12): [{}, {}, {&"timber": 1}, {&"timber": 1}],
	Vector2i(9, 12): [{}, {}, {&"timber": 1}, {&"timber": 1}],
	Vector2i(10, 12): [{}, {}, {&"timber": 1}, {}],
	Vector2i(6, 13): [{&"grain": 1}, {&"grain": 3}, {&"grain": 2}, {}],
	Vector2i(7, 13): [{&"grain": 1}, {&"grain": 3}, {&"grain": 2}, {&"grain": 1}],
	Vector2i(8, 13): [{&"fish": 6}, {&"fish": 6}, {&"fish": 6}, {&"fish": 4}],
	Vector2i(9, 13): [{&"timber": 6}, {&"timber": 6}, {&"timber": 6}, {&"timber": 19}],
	Vector2i(10, 13): [{}, {}, {&"timber": 1}, {&"timber": 1}],
	Vector2i(6, 14): [{}, {}, {}, {}],
	Vector2i(7, 14): [{}, {}, {&"oil": 14}, {&"oil": 28}],
	Vector2i(5, 15): [{}, {}, {}, {}],
}
const GENOA_DUES: Array = [30, 33, 30, 21]

var _defs: GameDefs
var _game: Game


func before_all() -> void:
	_defs = ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	var map := ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var scen := ResourceLoader.load(SCEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef
	_game = Game.new_scenario(map, _defs, scen, 1480)


## A 9 x 9 all-land map of one cover and climate (frost), the game over a wild state, every hex held by one owner (hands and
## jobs count the owner's hexes only: M5 spec 4.7). `held` false leaves the land unowned.
func _flat_game(cover: int, climate: int = 1, held: bool = true) -> Game:
	var m := MapData.new()
	m.id = "economy_flat"
	m.hex_w_km = 28.0
	m.ref_lat = 45.0
	m.allocate(9, 9)
	for i: int in m.hex_count():
		m.land[i] = 1
		m.cover[i] = cover
		m.climate[i] = climate
		m.depth[i] = 0
	var state := MapState.create(m)
	if held:
		state.owner.fill(1)
	return Game.with_state(m, state, 1, _defs)


func _put(g: Game, hex: Vector2i, family: int, level: int) -> int:
	var i := g.map.index_of(hex)
	g.state.main_use[i] = family
	g.state.level[i] = level
	return i


func _view(g: Game) -> StateView:
	return StateView.of(g.state)


## A base with only the family's numbers: a0 at full staffing, no wild yield, no lift.
func _bare_base(id: int, level: int, good: StringName, permille: int, bound: bool) -> Dictionary:
	var fam := _defs.family(id)
	var base := Economy.empty_base()
	base["family"] = id
	base["level"] = level
	base["good"] = _defs.good_id(good)
	base["raw"] = fam.base[level] * permille
	base["a0"] = fam.base[level] * permille
	base["weather_bound"] = bound
	return base


func _year(base: Dictionary, climate: int, weather: int = 0, tax: int = 1) -> int:
	var total := 0
	var good := int(base["good"])
	for season: int in 4:
		total += int(Economy.season_output(base, climate, season, weather, tax, _defs)["goods"][good])
	return total


func test_every_family_level_and_slot_equals_table_4_4() -> void:
	assert_eq(_defs.validate(), [] as Array[String])
	for row: Array in FAMILIES:
		var fam := _defs.family(row[0])
		for level: int in range(1, 4):
			assert_eq(fam.base[level], row[1][level - 1], "%s base %d" % [fam.key, level])
			assert_eq(fam.keep_wild[level], row[4][level - 1], "%s keep %d" % [fam.key, level])
		assert_eq(Array(fam.season_percent), row[2], "%s percents" % fam.key)
		assert_eq(fam.weather_bound, row[3], "%s weather" % fam.key)
		if fam.good == &"":
			continue
		for level: int in range(1, 4):
			var base := _bare_base(fam.id, level, fam.good, 1000, fam.weather_bound)
			assert_eq(_year(base, 1), row[5][level - 1], "%s frost year %d" % [fam.key, level])
	for row: Array in EXTRAS:
		var fam := _defs.family(row[0])
		assert_eq(int(fam.extra_permille[row[1]]), row[3])
		assert_eq(fam.by_extra[row[1]], row[2])
		for level: int in range(1, 4):
			var base := _bare_base(fam.id, level, row[2], row[3], fam.weather_bound)
			assert_eq(_year(base, 1), row[4][level - 1], "%s %s frost year %d" % [fam.key, row[1], level])


func test_the_other_years_of_table_4_4() -> void:
	var wheat := _defs.family(3)
	var olives := _defs.family(8)
	var timber := _defs.family(10)
	assert_eq(Array(olives.base), [0, 8, 16, 28])
	assert_eq(Array(olives.season_percent), [0, 0, 50, 0, 0, 100])
	assert_eq(Array(olives.keep_wild), [0, 50, 25, 0])
	for level: int in range(1, 4):
		var mild := [[17, 34, 53], [12, 24, 42]]
		assert_eq(_year(_bare_base(3, level, &"grain", 1000, true), 2), mild[0][level - 1])
		assert_eq(_year(_bare_base(8, level, &"oil", 1000, true), 2), mild[1][level - 1])
		assert_eq(_year(_bare_base(10, level, &"timber", 1000, false), 0), [9, 18, 30][level - 1], "timber snow year")
	assert_eq(wheat.good, &"grain")
	assert_eq(timber.good, &"timber")


func test_family_costs_jobs_and_upkeep_equal_the_tables() -> void:
	var plain := [3, 4, 5, 6, 7, 8, 9, 10, 12, 13]
	for id: int in plain:
		var fam := _defs.family(id)
		assert_eq(Array(fam.jobs), [0, 1000, 2000, 4000], "%s jobs" % fam.key)
		assert_eq(Array(fam.upkeep), [0, 1, 2, 4])
		assert_eq(Array(fam.cost), [0, 40, 100, 250])
		assert_eq(fam.cost_goods, [{}, {}, {"timber": 10}, {"timber": 20, "stone": 20}] as Array[Dictionary])
	for id: int in [11, 14]:
		var fam := _defs.family(id)
		assert_eq(Array(fam.upkeep), [0, 2, 3, 5])
		assert_eq(Array(fam.cost), [0, 60, 150, 350])
		assert_eq(fam.cost_goods, [{}, {"timber": 10}, {"timber": 20}, {"timber": 30, "stone": 20}] as Array[Dictionary])
	assert_eq(Array(_defs.family(11).jobs), [0, 1000, 2000, 4000])
	assert_eq(Array(_defs.family(14).jobs), [0, 500, 1000, 2000])
	var s := _defs.family(1)
	assert_eq(Array(s.people), [0, 1000, 3000, 10000, 30000, 60000])
	assert_eq(Array(s.keep_wild), [0, 100, 100, 100, 75, 50])
	assert_eq(Array(s.upkeep), [0, 0, 1, 2, 2, 5])
	assert_eq(Array(s.walls), [0, 0, 0, 0, 4, 6])
	assert_eq(Array(s.ring_lift), [0, 0, 0, 0, 100, 200])
	assert_eq(Array(s.port_fish), [0, 1, 2, 4, 6, 10])
	assert_eq(Array(s.port_dues), [0, 2, 5, 12, 30, 45])
	assert_eq(Array(s.cost), [0, 0, 60, 200, 700, 1000])
	var c := _defs.family(2)
	assert_eq(Array(c.walls), [0, 2, 4, 8])
	assert_eq(Array(c.keep_wild), [0, 100, 100, 100])
	assert_eq(Array(c.upkeep), [0, 0, 0, 0])
	assert_eq(Array(c.cost), [0, 60, 200, 500])


func test_wild_yield_and_keep() -> void:
	var g := _flat_game(0)  # farmland, frost
	var hex := Vector2i(4, 4)
	var spring := Economy.district_output(g, _view(g), hex, 0)
	var summer := Economy.district_output(g, _view(g), hex, 1)
	assert_eq(spring["goods"][0], 1, "wild farmland, spring: grain 1")
	assert_eq(summer["goods"][0], 3)
	assert_eq(spring["wild"], 1)
	assert_eq(Economy.district_output(g, _view(g), hex, 3)["goods"][0], 0, "frost winter: nothing grows")
	# A hemp district keeps 50 % of 3 grain: 1; a second stage keeps 25 %: 0; a wheat district none.
	_put(g, hex, 4, 1)
	assert_eq(Economy.district_output(g, _view(g), hex, 1)["wild"], 1)
	_put(g, hex, 4, 2)
	assert_eq(Economy.district_output(g, _view(g), hex, 1)["wild"], 0)
	_put(g, hex, 3, 1)
	assert_eq(Economy.district_output(g, _view(g), hex, 1)["wild"], 0)
	var woods := _flat_game(2)
	assert_eq(Economy.district_output(woods, _view(woods), hex, 2)["goods"][11], 1, "wild woods: timber in autumn")
	assert_eq(Economy.district_output(woods, _view(woods), hex, 0)["goods"][11], 0)
	var marsh := _flat_game(3)
	assert_eq(Economy.district_output(marsh, _view(marsh), hex, 2)["wild"], 0)


func test_staffing_below_full_and_ring_competition() -> void:
	var g := _flat_game(4)  # rock: 600 people a hex
	var hex := Vector2i(4, 4)
	_put(g, hex, 11, 3)
	assert_eq(Economy.people_at(g, _view(g), hex), 600)
	assert_eq(Economy.hands_at(g, _view(g), hex), 1260, "7 x 600 x 30 %")
	assert_eq(Economy.jobs_near(g, _view(g), hex), 4000)
	assert_eq(Economy.staffing(g, _view(g), hex), 315)
	var base := Economy.district_base(g, _view(g), hex)
	assert_eq(base["staffing"], 315)
	assert_eq(base["a0"], 14 * int(_defs.family(11).extra_permille.get(
		str(Improve.piece_for(g.map, hex, 11, 3)["extra"]), 1000)) * 315 / 1000)
	# A quarry beside it: both districts now share the same hands.
	var next := g.map.neighbour(hex, 0)
	_put(g, next, 12, 1)
	var both := 1260 * 1000 / 5000
	assert_eq(Economy.staffing(g, _view(g), hex), both)
	assert_eq(Economy.staffing(g, _view(g), next), both)
	assert_lt(both, 315)
	# Only the district and its six neighbours change: a hex two away keeps its staffing.
	var far := g.map.neighbour(g.map.neighbour(hex, 3), 3)
	assert_eq(Economy.jobs_near(g, _view(g), far), 0)
	assert_eq(Economy.staffing(g, _view(g), far), 1000)


func test_lift_beside_a_walled_town_and_a_city_the_best_counting() -> void:
	var g := _flat_game(0)
	var hex := Vector2i(4, 4)
	_put(g, hex, 10, 1)
	assert_eq(Economy.lift_at(g, _view(g), hex), 0)
	var a0 := int(Economy.district_base(g, _view(g), hex)["a0"])
	_put(g, g.map.neighbour(hex, 0), 1, 3)
	assert_eq(Economy.lift_at(g, _view(g), hex), 0, "a town lends nothing")
	_put(g, g.map.neighbour(hex, 0), 1, 4)
	assert_eq(Economy.lift_at(g, _view(g), hex), 100)
	_put(g, g.map.neighbour(hex, 3), 1, 5)
	assert_eq(Economy.lift_at(g, _view(g), hex), 200, "the best counts")
	var base := Economy.district_base(g, _view(g), hex)
	assert_eq(base["lift"], 200)
	assert_eq(base["a0"], a0 * 1200 / 1000)
	assert_true(base["staffing"] <= 1000)


func test_weather_only_on_bound_families_and_wild_grain() -> void:
	var timber := _bare_base(10, 1, &"timber", 1000, false)
	var wheat := _bare_base(3, 1, &"grain", 1000, true)
	var flat := _defs.weather_permille
	assert_eq(Array(flat), [1000, 1200, 750])
	var t_calm := int(Economy.season_output(timber, 1, 1, Economy.CALM, 1, _defs)["goods"][11])
	assert_eq(int(Economy.season_output(timber, 1, 1, Economy.POOR, 1, _defs)["goods"][11]), t_calm)
	assert_eq(int(Economy.season_output(wheat, 1, 1, Economy.CALM, 1, _defs)["goods"][0]), 10)
	assert_eq(int(Economy.season_output(wheat, 1, 1, Economy.GOOD, 1, _defs)["goods"][0]), 12)
	assert_eq(int(Economy.season_output(wheat, 1, 1, Economy.POOR, 1, _defs)["goods"][0]), 7)
	# Wild grain: 3 loads in summer on farmland; 3 x 1,200 / 1,000 = 3; 6 would be 7 (checked through the base).
	var wild := Economy.empty_base()
	wild["wild_good"] = 0
	wild["cover"] = 0
	wild["keep"] = 100
	assert_eq(Economy.wild_loads(wild, 1, Economy.GOOD, _defs), 3)
	assert_eq(Economy.wild_loads(wild, 1, Economy.POOR, _defs), 2)
	wild["wild_good"] = 11  # timber on woods ignores the weather
	wild["cover"] = 2
	assert_eq(Economy.wild_loads(wild, 2, Economy.POOR, _defs), 1)


func test_tax_level_changes_output() -> void:
	var base := _bare_base(7, 3, &"wine", 1000, false)  # 40 loads in autumn at Normal
	assert_eq(int(Economy.season_output(base, 1, 2, 0, 0, _defs)["goods"][3]), 42, "Low: x 1.05")
	assert_eq(int(Economy.season_output(base, 1, 2, 0, 1, _defs)["goods"][3]), 40)
	assert_eq(int(Economy.season_output(base, 1, 2, 0, 2, _defs)["goods"][3]), 36, "High: x 0.9")


func test_slot_of_people_at_prices_and_floor_div() -> void:
	var g := _flat_game(0, 2)
	g.map.climate[g.map.index_of(Vector2i(1, 1))] = 0
	assert_eq(Economy.slot_of(g.map, Vector2i(4, 4), 0), 0)
	assert_eq(Economy.slot_of(g.map, Vector2i(4, 4), 2), 2)
	assert_eq(Economy.slot_of(g.map, Vector2i(4, 4), 3), 5, "mild winter")
	assert_eq(Economy.slot_of(g.map, Vector2i(1, 1), 3), 3, "snow winter")
	var covers := [8000, 5000, 2500, 1500, 600, 0, 0, 1500]
	for cover: int in 8:
		var flat := _flat_game(cover)
		assert_eq(Economy.people_at(flat, _view(flat), Vector2i(4, 4)), covers[cover])
	var town := _flat_game(0)
	var levels := [1000, 3000, 10000, 30000, 60000]
	var had := 8000
	for level: int in range(1, 6):
		var at := _put(town, Vector2i(4, 4), 1, level)
		# People are the state's now (M5): the start table is People.start_people, what the view reads is MapState.people.
		assert_eq(People.start_people(town, Vector2i(4, 4)), levels[level - 1])
		assert_eq(Economy.people_at(town, _view(town), Vector2i(4, 4)), had, "the hex keeps the people it had")
		had = levels[level - 1]
		town.state.people[at] = had
		assert_eq(Economy.people_at(town, _view(town), Vector2i(4, 4)), levels[level - 1])
		assert_eq(Economy.people_at(town, _view(town).with_people({at: 7}), Vector2i(4, 4)), 7, "the view's own number")
	assert_eq(Economy.people_at(town, _view(town), Vector2i(-1, 0)), 0)
	# The prices are the table's, whatever the supply (P: a changed supply array leaves them).
	var supply := PackedInt32Array()
	supply.resize(16)
	var calm := Economy.market_prices(town, _view(town), 1, supply)
	supply.fill(9999)
	var busy := Economy.market_prices(town, _view(town), 2, supply)
	assert_eq(calm, busy)
	assert_eq(calm.size(), 16)
	assert_eq(calm[3], 2500)
	assert_eq(calm[15], 7000)
	assert_eq(Economy.market_of(_game, &"GEN"), 7)
	assert_eq(Economy.market_of(_game, &""), Economy.NO_MARKET)
	assert_eq(Economy.floor_div(7, 2), 3)
	assert_eq(Economy.floor_div(-7, 2), -4)
	assert_eq(Economy.floor_div(-6, 3), -2)
	assert_eq(Economy.floor_div(0, 5), 0)


func test_genoa_hex_by_hex_equals_4_15_a() -> void:
	var view := _view(_game)
	var genoa := Countries.by_tag(_game, &"GEN")
	var owned := 0
	for i: int in _game.map.hex_count():
		if _game.state.owner[i] == genoa.id and _game.map.land[i] == 1:
			owned += 1
	assert_eq(owned, GENOA.size(), "Genoa holds 14 districts")
	for hex: Vector2i in GENOA:
		assert_eq(_game.state.owner[_game.map.index_of(hex)], genoa.id, "Genoa owns %s" % hex)
		for season: int in 4:
			var out := Economy.district_output(_game, view, hex, season)
			var goods: Dictionary = {}
			for g: int in 16:
				if out["goods"][g] != 0:
					goods[_defs.good(g).key] = out["goods"][g]
			assert_eq(goods, GENOA[hex][season], "%s season %d" % [hex, season])
			assert_eq(out["ducats"], GENOA_DUES[season] if hex == Vector2i(8, 13) else 0, "dues %s %d" % [hex, season])
	var walled := Economy.district_output(_game, view, Vector2i(8, 13), 0)
	assert_eq([walled["upkeep"], walled["walls"]], [2, 4])
	assert_eq(Economy.district_output(_game, view, Vector2i(7, 14), 0)["upkeep"], 4)


func test_genoa_as_a_city_4_15_d() -> void:
	# M5: an upgrade brings room, not people (spec 4.11 c replaces M4's people jump): the city's dues, fish and lift hold.
	var i := _game.map.index_of(Vector2i(8, 13))
	var view := _view(_game).with({i: Vector2i(1, 5)})
	var spring := Economy.district_output(_game, view, Vector2i(8, 13), 0)
	assert_eq(spring["ducats"], 45)
	assert_eq(spring["goods"][1], 10, "fish")
	assert_eq([spring["upkeep"], spring["walls"]], [5, 6])
	var ring := Economy.district_output(_game, view, Vector2i(9, 13), 0)
	assert_eq(ring["goods"][11], 7, "timber near a city: +1 a season")
	assert_eq(Economy.district_output(_game, view, Vector2i(9, 13), 3)["goods"][11], 21, "+2 in winter")
	assert_eq(Economy.people_at(_game, view, Vector2i(8, 13)), 30000, "the people are the same")
	assert_eq(int(Economy.district_base(_game, view, Vector2i(8, 13))["room"]), 100000, "the room is the city's")


func test_district_output_equals_season_output_of_the_base_on_every_land_hex() -> void:
	var view := _view(_game)
	var map := _game.map
	var checked := 0
	for i: int in map.hex_count():
		if map.land[i] == 0:
			continue
		var hex := map.hex_of(i)
		var base := Economy.district_base(_game, view, hex)
		for season: int in 4:
			for tax: int in 3:
				var out := Economy.district_output(_game, view, hex, season, Economy.CALM, tax)
				var plain := Economy.season_output(base, int(map.climate[i]), season, Economy.CALM, tax, _defs)
				for key: String in ["goods", "ducats", "upkeep", "walls"]:
					assert_eq(out[key], plain[key], "%s %s s%d t%d" % [hex, key, season, tax])
				assert_eq(out["good"], base["good"])
				assert_eq(out["staffing"], base["staffing"])
		checked += 1
	assert_gt(checked, 300)


func test_district_output_uses_the_owners_tax_and_normal_when_unowned() -> void:
	var g := Game.new_scenario(_game.map, _defs, _game.scenario, 1480)
	var hex := Vector2i(7, 12)  # a vineyard of Genoa
	var normal: int = Economy.district_output(g, _view(g), hex, 2)["goods"][3]
	assert_eq(normal, 24)
	Countries.by_tag(g, &"GEN").tax = 2
	assert_eq(Economy.district_output(g, _view(g), hex, 2)["goods"][3], 21, "Genoa's High tax: 24 x 0.9")
	assert_eq(Economy.district_output(g, _view(g), hex, 2, Economy.CALM, 1)["goods"][3], 24)
	g.state.owner[g.map.index_of(hex)] = 0
	assert_eq(Economy.district_output(g, _view(g), hex, 2)["goods"][3], 24, "unowned land counts Normal")


func test_a_defs_without_goods_never_reads_out_of_bounds() -> void:
	var bare := _defs.duplicate() as GameDefs
	bare.goods = [] as Array[GoodDef]
	var g := Game.with_state(_game.map, _game.state, 1, bare)
	var view := StateView.of(g.state)
	for hex: Vector2i in GENOA:
		for season: int in 4:
			var out := Economy.district_output(g, view, hex, season)
			assert_eq((out["goods"] as PackedInt32Array).size(), 0)
			assert_eq(out["ducats"], GENOA_DUES[season] if hex == Vector2i(8, 13) else 0, "dues still counted")
	# A target array shorter than the goods gives less, never an error.
	var base := Economy.district_base(_game, _view(_game), Vector2i(8, 13))
	var short := PackedInt32Array([0])
	var rest := Economy.add_output(base, 0, 0, 1, _defs, short)
	assert_eq(rest["ducats"], 30)
	assert_eq(short, PackedInt32Array([0]))
	var tiny := PackedInt32Array()
	assert_eq(Economy.add_output(_bare_base(3, 1, &"grain", 1000, true), 1, 0, 1, _defs, tiny)["upkeep"], 0)


# ----- M5: people live, hands and jobs of the owner's land, the new base keys (spec 4.7, 5.0 R1, 5.3) -----------------------


func test_people_at_reads_the_view_and_zero_at_sea_and_off_the_map() -> void:
	var g := _flat_game(0)
	var hex := Vector2i(4, 4)
	var i := g.map.index_of(hex)
	assert_eq(Economy.people_at(g, _view(g), hex), 8000)
	assert_eq(Economy.people_at(g, _view(g).with_people({i: 123}), hex), 123, "a what-if number")
	assert_eq(g.state.people[i], 8000, "the base is untouched")
	g.state.people[i] = 4321
	assert_eq(Economy.people_at(g, _view(g), hex), 4321, "the state's own")
	assert_eq(Economy.people_at(g, _view(g), Vector2i(-1, 0)), 0)
	g.map.land[g.map.index_of(Vector2i(0, 0))] = 0
	assert_eq(Economy.people_at(g, _view(g), Vector2i(0, 0)), 0, "the sea has none")


func test_hands_and_jobs_count_the_owners_hexes_only() -> void:
	var g := _flat_game(4)  # rock: 600 people a hex, all held by owner 1
	var hex := Vector2i(4, 4)
	_put(g, hex, 11, 3)
	assert_eq(Economy.hands_at(g, _view(g), hex), 1260)
	var next := g.map.neighbour(hex, 0)
	_put(g, next, 12, 1)
	assert_eq(Economy.jobs_near(g, _view(g), hex), 5000)
	# A foreign neighbour's people and jobs do not count (P: a hands_at that counts every neighbour is caught).
	g.state.owner[g.map.index_of(next)] = 2
	assert_eq(Economy.hands_at(g, _view(g), hex), 6 * 600 * 300 / 1000, "six neighbours of the owner left: 5 x 600 + 600")
	assert_eq(Economy.jobs_near(g, _view(g), hex), 4000, "the foreign quarry's jobs do not count")
	g.state.people[g.map.index_of(next)] = 99999
	assert_eq(Economy.hands_at(g, _view(g), hex), 6 * 600 * 300 / 1000, "a foreign neighbour's people do not count either")
	assert_eq(Economy.hands_at(g, _view(g), next), 99999 * 300 / 1000, "the quarry's owner holds nothing beside it: its own hex alone")
	# Unowned land: the hex alone.
	var lone := _flat_game(4, 1, false)
	_put(lone, hex, 11, 3)
	assert_eq(Economy.hands_at(lone, _view(lone), hex), 180, "600 x 30 %: the hex alone")
	assert_eq(Economy.jobs_near(lone, _view(lone), hex), 4000)
	assert_eq(Economy.staffing(lone, _view(lone), hex), 45)


func test_district_base_has_the_new_keys_and_room() -> void:
	var base := Economy.district_base(_game, _view(_game), Vector2i(7, 12))  # Genoa's vineyard
	for key: String in Economy.BASE_FIELDS + ["people", "staffing", "a0"] as Array[String]:
		assert_true(base.has(key), key)
	assert_eq(base["people"], 8000)
	assert_eq(base["room"], 10000, "farmland 8,000 and the second stage's 2,000 jobs")
	assert_eq(base["raw"], 24 * 1000, "the base times the extra: 24 loads, no extra")
	assert_eq(base["staffing"], 1000)
	assert_eq(base["a0"], 24000)
	var genoa := Economy.district_base(_game, _view(_game), Vector2i(8, 13))
	assert_eq([genoa["people"], genoa["room"], genoa["raw"], genoa["a0"]], [30000, 45000, 0, 0])
	var sea_i := 0
	while _game.map.land[sea_i] == 1:
		sea_i += 1
	var sea := Economy.district_base(_game, _view(_game), _game.map.hex_of(sea_i))
	assert_eq([sea["people"], sea["room"], sea["staffing"], sea["a0"]], [0, 0, 1000, 0])
	var scenery := _flat_game(4)
	_put(scenery, Vector2i(4, 4), 11, 3)
	var mine := Economy.district_base(scenery, _view(scenery), Vector2i(4, 4))
	assert_eq(mine["staffing"], 315)
	assert_eq(mine["a0"], int(mine["raw"]) * 315 / 1000)
	assert_eq(mine["room"], 600 + 4000, "the cover's countryside people and the district's jobs")


func test_staffed_is_the_one_live_step() -> void:
	var g := _flat_game(4)
	var hex := Vector2i(4, 4)
	var i := _put(g, hex, 11, 3)
	var live := Economy.staffed(g, _view(g), i, 14000, 200)
	assert_eq(live.x, 315)
	assert_eq(live.y, 14000 * 315 / 1000 * 1200 / 1000, "floored in that order: staffing, then lift")
	# People follow without a touch: a view with more people at the hex and its ring gives more hands.
	var view := _view(g).with_people({i: 5000})
	assert_gt(Economy.staffed(g, view, i, 14000, 0).x, 315)
	assert_eq(Economy.staffed(g, _view(g), i, 0, 0), Vector2i(315, 0), "no raw: no output")


func test_room_follows_the_district_and_the_level() -> void:
	var g := _flat_game(0)
	var hex := Vector2i(4, 4)
	assert_eq(People.room_at(g, _view(g), hex), 8000)
	var i := _put(g, hex, 7, 2)
	assert_eq(People.room_at(g, _view(g), hex), 10000)
	_put(g, hex, 7, 3)
	assert_eq(People.room_at(g, _view(g), hex), 12000)
	_put(g, hex, 2, 1)
	assert_eq(People.room_at(g, _view(g), hex), 8000, "a castle has no jobs")
	_put(g, hex, 1, 3)
	assert_eq(People.room_at(g, _view(g), hex), 20000)
	assert_eq(People.room_at(g, _view(g).with({i: Vector2i(1, 5)}), hex), 100000, "the view's level")


func test_district_output_equals_season_output_of_the_base_after_ten_seasons_of_people() -> void:
	# M5 spec 9: the same equality on every land hex with the people grown (the games's people phase is the fixture's).
	var g := PeopleFixture.genoa()
	PeopleFixture.play(g, 10)
	var view := _view(g)
	var moved := 0
	for i: int in g.map.hex_count():
		if g.map.land[i] == 0:
			continue
		if g.state.people[i] != g.state.people_start[i]:
			moved += 1
		var hex := g.map.hex_of(i)
		var base := Economy.district_base(g, view, hex)
		assert_eq(base["people"], g.state.people[i], "%s the base reads the live people" % str(hex))
		for season: int in 4:
			for tax: int in 3:
				var out := Economy.district_output(g, view, hex, season, Economy.CALM, tax)
				var plain := Economy.season_output(base, int(g.map.climate[i]), season, Economy.CALM, tax, g.defs)
				for key: String in ["goods", "ducats", "upkeep", "walls"]:
					assert_eq(out[key], plain[key], "%s %s s%d t%d" % [hex, key, season, tax])
	assert_gt(moved, 0, "the people moved in the ten seasons")


func test_staffing_follows_the_people_hex_by_hex() -> void:
	# A district short of hands is staffed by its owner's people: more people beside it, more of its jobs staffed.
	var g := _flat_game(4)  # rock: 600 a hex
	var hex := Vector2i(4, 4)
	var i := _put(g, hex, 11, 3)  # a mine of 4,000 jobs
	var before := Economy.district_base(g, _view(g), hex)
	assert_eq(before["staffing"], 315)
	g.state.people[g.map.index_of(g.map.neighbour(hex, 0))] += 5000
	var after := Economy.district_base(g, _view(g), hex)
	assert_gt(int(after["staffing"]), 315)
	assert_gt(int(after["a0"]), int(before["a0"]))
	assert_eq(after["raw"], before["raw"], "the people-free part is the same")
	assert_eq(Economy.staffed(g, _view(g), i, int(after["raw"]), int(after["lift"])), Vector2i(after["staffing"], after["a0"]))


func test_the_ring_by_arithmetic_equals_the_maps_neighbours() -> void:
	# Economy._ring is arithmetic on the index (the hot path of staffing); it must agree with the map's own neighbours.
	for g: Game in [_game, _flat_game(0)]:
		var map := g.map
		for i: int in map.hex_count():
			var want := PackedInt32Array()
			var hex := map.hex_of(i)
			for d: int in 6:
				want.append(map.index_of(map.neighbour(hex, d)))
			assert_eq(Economy.ring_of(map, i), want, "%s" % str(hex))
