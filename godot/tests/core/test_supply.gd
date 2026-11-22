## The supply line (docs/architecture/m6-build-spec.md sections 4.8, 5.0 R5 and R8 (b), 5.3, 9; task L7): depots, the field on
## the 1480 map (Genoa, as ArmyFixture plays it), the food from grain then fish, foraging with the cap shared in id order,
## hunger by season and climate, the events, army_food, the pure country_step equal to the phase on seeded states, and the
## field's refresh when a settlement appears. Planted faults: a foreign hex or an unowned hex never feeds an army.
## Test edits to the state (a settlement's level, a hex's owner, the people of a hex) are the tests' own numbers, not rules.
extends GutTest

const SPRING := 1
const SUMMER := 2
const WINTER := 4
## Genoa's hexes of the fixture map (ArmyFixture.game): snow (9, 11) and (10, 12) lie out of supply in winter; (8, 11) is
## frost, (8, 13) is Genoa itself (mild, a port), (7, 12) farmland.
const SNOW_HEX := Vector2i(9, 11)
const FROST_HEX := Vector2i(8, 11)
const MILD_HEX := Vector2i(8, 13)
const FARM_HEX := Vector2i(7, 12)

var _g: Game
var _c: Country
var _town: Vector2i


func before_each() -> void:
	_fresh()


## A new game of Genoa with its own depot town (a level 3 settlement of 20,000 people).
func _fresh() -> void:
	_g = ArmyFixture.game()
	_c = Countries.by_tag(_g, ArmyFixture.TAG)
	_town = ArmyFixture.find_town(_g)
	ArmyFixture.town(_g, _town, 3, 20000)


func _i(hex: Vector2i) -> int:
	return _g.map.index_of(hex)


func _good(key: StringName) -> int:
	return _g.defs.good_id(key)


func _set_stock(key: StringName, loads: int) -> void:
	_c.stock[_good(key)] = loads


func _stock(key: StringName) -> int:
	return _c.stock[_good(key)]


## Every land hex of Genoa, in index order.
func _genoa_land() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in _g.map.hex_count():
		if _g.map.land[i] == 1 and int(_g.state.owner[i]) == _c.id:
			out.append(_g.map.hex_of(i))
	return out


## Makes every settlement of Genoa wild (a test's state): the country holds no depot afterwards.
func _no_depots() -> void:
	for i: int in _g.map.hex_count():
		if _g.map.land[i] == 1 and int(_g.state.owner[i]) == _c.id and _g.state.main_use[i] == Economy.SETTLEMENTS:
			_g.state.main_use[i] = 0
			_g.state.level[i] = 0
	_g.version += 1


## An army of Genoa of `count` companies of pikemen (500 men each) on `hex`, through the door.
func _army(hex: Vector2i, count: int = 2) -> Army:
	return ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, count)


func _men_of(army_id: int) -> int:
	var a := Armies.by_id(_g, army_id)
	return a.men() if a != null else 0


func _starved_events() -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if e.get("kind", "") == "army_starved":
			out.append(e)
	return out


## The armies of Genoa as the phase reads them: [{id, hex, men}] in id order.
func _armies_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Army in Armies.of_country(_g, ArmyFixture.TAG):
		out.append({"id": a.id, "hex": a.hex, "men": a.men()})
	return out


## Genoa's own land hexes of one cover, in index order.
func _with_cover(cover: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for hex: Vector2i in _genoa_land():
		if int(_g.map.cover[_i(hex)]) == cover:
			out.append(hex)
	return out


# --- depots and the field ---------------------------------------------------------------------------------------------


func test_depots_are_held_settlements_of_level_two_or_a_coastal_port() -> void:
	assert_true(Supply.is_depot(_g, ArmyFixture.TAG, _town), "a level 3 town of the country is a depot")
	assert_false(Supply.is_depot(_g, ArmyFixture.other_tag(_g), _town), "not a depot of another country")
	var wild := _genoa_land()[0]
	for hex: Vector2i in _genoa_land():
		if Improve.place_of(_g.map, hex).is_empty() and hex != _town:
			wild = hex
			break
	ArmyFixture.town(_g, wild, 1, 1000)
	assert_false(Supply.is_depot(_g, ArmyFixture.TAG, wild), "a level 1 hamlet with no port is no depot")
	ArmyFixture.town(_g, wild, 2, 1000)
	assert_true(Supply.is_depot(_g, ArmyFixture.TAG, wild), "a village (level 2) is a depot")
	var genoa := Vector2i(8, 13)
	ArmyFixture.town(_g, genoa, 1, 1000)
	assert_true(Supply.is_depot(_g, ArmyFixture.TAG, genoa), "a port on the coast at level 1 is a depot")


func test_field_holds_only_own_land_and_the_depots_themselves() -> void:
	var f := Supply.field(_g, ArmyFixture.TAG, false)
	assert_eq(f.size(), _g.map.hex_count(), "one byte a hex")
	assert_eq(f[_i(_town)], 1, "a depot is in its own supply")
	var inside := 0
	for i: int in f.size():
		if f[i] == 1:
			inside += 1
			assert_eq(_g.map.land[i], 1, "no sea in supply")
			assert_eq(int(_g.state.owner[i]), _c.id, "supply stays on the country's own land")
	assert_gt(inside, 0)


func test_out_of_supply_counts_of_every_country_on_the_1480_map() -> void:
	# Pinned from the rules as written (the spec's page, corrected 2026-11-21, lists the same): tag -> [land hexes,
	# out of supply in summer, out of supply in winter]. A country with no depot is all out of supply.
	var pinned := {
		"FRA": [34, 12, 20], "AUS": [37, 21, 25], "SWI": [45, 5, 15], "SAV": [58, 6, 16], "MLO": [52, 1, 5],
		"VEN": [42, 2, 6], "GEN": [14, 0, 2], "TUS": [14, 1, 2], "PAP": [20, 0, 2], "MAN": [3, 1, 1],
		"FER": [12, 2, 3], "SIE": [7, 1, 1], "LUC": [2, 0, 0],
	}
	# M7 (4.12): owned, controlled fortresses with no siege are depots too; FRA and SWI moved with the castles they hold.
	for c: Country in _g.countries:
		if c == null:
			continue
		var land: Array[Vector2i] = []
		var summer_out := 0
		var winter_out := 0
		for i: int in _g.map.hex_count():
			if _g.map.land[i] == 0 or int(_g.state.owner[i]) != c.id:
				continue
			var hex := _g.map.hex_of(i)
			land.append(hex)
			if not Supply.in_supply(_g, c.tag, hex, false):
				summer_out += 1
			if not Supply.in_supply(_g, c.tag, hex, true):
				winter_out += 1
		var want: Array = pinned[String(c.tag)]
		assert_eq([land.size(), summer_out, winter_out], want, "%s: land, summer out, winter out" % String(c.tag))


func test_genoa_winter_out_of_supply_hexes_are_the_snow_heights() -> void:
	var winter_out: Array[Vector2i] = []
	for hex: Vector2i in _genoa_land():
		if not Supply.in_supply(_g, ArmyFixture.TAG, hex, true):
			winter_out.append(hex)
	assert_eq(winter_out, [Vector2i(9, 11), Vector2i(10, 12)])


func test_field_refreshes_when_a_settlement_appears() -> void:
	_no_depots()
	assert_eq(Supply.field(_g, ArmyFixture.TAG, false).count(1), 0, "no depot, nothing in supply")
	ArmyFixture.town(_g, FARM_HEX, 2, 3000)
	var f := Supply.field(_g, ArmyFixture.TAG, false)
	assert_eq(f[_i(FARM_HEX)], 1, "the new village is in supply at once")
	assert_eq(Supply.is_depot(_g, ArmyFixture.TAG, FARM_HEX), true)


func test_planted_zero_reach_leaves_only_the_depots_in_supply() -> void:
	# A planted fault on this game's own copy of the defs (ArmyFixture.defs is a copy): the reach is 0, so the field
	# keeps the depot hexes and nothing else; the cache follows the number.
	var before := Supply.field(_g, ArmyFixture.TAG, false).count(1)
	_g.defs.supply_reach = 0
	var f := Supply.field(_g, ArmyFixture.TAG, false)
	assert_lt(f.count(1), before, "a reach of 0 shrinks the field")
	var depots := 0
	for hex: Vector2i in _genoa_land():
		if Supply.is_depot(_g, ArmyFixture.TAG, hex):
			depots += 1
	assert_eq(f.count(1), depots, "the depots of Genoa and nothing else")
	assert_eq(f[_i(_town)], 1)


func test_field_follows_the_owner_bytes() -> void:
	# A planted fault: a hex that changes hands leaves the field of its old owner at once.
	var f := Supply.field(_g, ArmyFixture.TAG, false)
	var edge := -1
	for hex: Vector2i in _genoa_land():
		if f[_i(hex)] == 1 and hex != _town:
			edge = _i(hex)
			break
	assert_gt(edge, -1)
	_g.state.owner[edge] = 0
	_g.version += 1
	assert_eq(Supply.field(_g, ArmyFixture.TAG, false)[edge], 0, "a hex no one holds is not in supply")


# --- the numbers of the rules ----------------------------------------------------------------------------------------


func test_food_need_rounds_up_per_thousand_men() -> void:
	assert_eq(Supply.food_need(_g, 0), 0)
	assert_eq(Supply.food_need(_g, 1), 1)
	assert_eq(Supply.food_need(_g, 5000), 1, "a load feeds 5,000 soldiers at army_food_milli 200")
	assert_eq(Supply.food_need(_g, 5001), 2)
	assert_eq(Supply.food_need(_g, 10001), 3)


func test_starve_loss_is_a_tenth_a_fifth_in_snow_and_15_percent_in_frost() -> void:
	assert_eq(Supply.starve_loss(_g, SNOW_HEX, SPRING, 1000), 100, "spring: a tenth")
	assert_eq(Supply.starve_loss(_g, SNOW_HEX, WINTER, 1000), 200, "snow winter: a fifth")
	assert_eq(Supply.starve_loss(_g, FROST_HEX, WINTER, 1000), 150, "frost winter: 15 %")
	assert_eq(Supply.starve_loss(_g, MILD_HEX, WINTER, 1000), 100, "mild winter: a tenth")
	assert_eq(Supply.starve_loss(_g, SNOW_HEX, SPRING, 1), 1, "rounded up")
	assert_eq(Supply.starve_loss(_g, SNOW_HEX, SPRING, 0), 0, "nothing unfed, nothing lost")


func test_forage_cap_follows_cover_people_and_the_season_slot() -> void:
	_g.state.people[_i(FARM_HEX)] = 4000
	_g.state.people[_i(FROST_HEX)] = 4000
	_g.state.people[_i(SNOW_HEX)] = 4000
	var view := StateView.of(_g.state)
	assert_eq(Supply.forage_cap(_g, view, FARM_HEX, SPRING), 1000, "farmland 250 permille, all of it in spring")
	assert_eq(Supply.forage_cap(_g, view, FROST_HEX, WINTER), 400, "woods 200 permille, half in frost")
	assert_eq(Supply.forage_cap(_g, view, SNOW_HEX, WINTER), 0, "no forage in snow")
	assert_eq(Supply.forage_cap(_g, view, SNOW_HEX, SUMMER), 800, "woods in summer, whatever the climate")


# --- the phase -------------------------------------------------------------------------------------------------------


func test_a_supplied_army_eats_grain_before_fish() -> void:
	var a := _army(_town)
	_set_stock(&"grain", 1)
	_set_stock(&"fish", 1000)
	Supply.season(_g)
	assert_eq(Stores.flow(_c, _good(&"grain"), &"army"), -1, "its one load comes from the grain")
	assert_eq(Stores.flow(_c, _good(&"fish"), &"army"), 0, "the fish is not touched")
	assert_eq(a.supply, Supply.FED)
	assert_eq(a.men(), 1000)
	assert_eq(a.lost_last, 0)


func test_no_food_leaves_a_supplied_army_hungry_and_starved() -> void:
	var a := _army(_town)
	_set_stock(&"grain", 0)
	_set_stock(&"fish", 0)
	Supply.season(_g)
	assert_eq(a.supply, Supply.HUNGRY)
	assert_eq(a.lost_last, 100, "spring: a tenth of 1,000 men")
	assert_eq(a.men(), 900)
	var ev := _starved_events()
	assert_eq(ev.size(), 1)
	if ev.size() == 1:
		assert_eq(ev[0]["lost"], 100)
		assert_eq(ev[0]["why"], &"stores_empty")
		assert_eq(ev[0]["tag"], ArmyFixture.TAG)


func test_winter_hunger_in_the_snow_loses_a_fifth_out_of_supply() -> void:
	_g.turn = WINTER
	var people_before := _g.state.people[_i(SNOW_HEX)]
	var a := _army(SNOW_HEX)
	Supply.season(_g)
	assert_eq(a.supply, Supply.HUNGRY)
	assert_eq(a.lost_last, 200)
	assert_eq(a.men(), 800)
	assert_eq(_g.state.people[_i(SNOW_HEX)], people_before, "snow feeds no one: nobody is taken")
	var ev := _starved_events()
	if ev.size() == 1:
		assert_eq(ev[0]["why"], &"out_of_supply")


func test_an_army_out_of_supply_forages_its_hex_and_the_hex_loses_people() -> void:
	_no_depots()
	var hex := _with_cover(0)[0]
	_g.state.people[_i(hex)] = 4000
	var grain_before := _stock(&"grain")
	var a := _army(hex)
	Supply.season(_g)
	assert_eq(a.supply, Supply.FORAGED, "the land feeds all 1,000 men")
	assert_eq(a.men(), 1000)
	assert_eq(_stock(&"grain"), grain_before, "foraging eats nothing from the stores")
	assert_eq(_g.state.people[_i(hex)], 4000 - 80, "2 % of the hex's people go foraging")


func test_forage_is_shared_by_the_armies_of_a_hex_in_id_order() -> void:
	_no_depots()
	var hex := _with_cover(0)[0]
	_g.state.people[_i(hex)] = 2000
	var first := _army(hex)
	var second := _army(hex)
	Supply.season(_g)
	# The cap is 2,000 x 250 / 1,000 = 500 men: the first army (id order) takes all 500 and goes 500 men short.
	assert_eq(first.supply, Supply.HUNGRY, "500 of its 1,000 men are fed")
	assert_eq(first.lost_last, 50, "its 500 unfed men lose a tenth")
	assert_eq(second.supply, Supply.HUNGRY, "nothing is left for the second army")
	assert_eq(second.lost_last, 100, "its 1,000 unfed men lose a tenth")
	assert_eq(_g.state.people[_i(hex)], 2000 - 40, "2 % of the people go foraging once for the hex")


func test_unowned_land_feeds_its_army_but_takes_no_people() -> void:
	_no_depots()
	var hex := _with_cover(0)[0]
	_g.state.owner[_i(hex)] = 0
	_g.state.people[_i(hex)] = 4000
	_g.version += 1
	var a := _army(hex)
	var res := Supply.country_step(_g, StateView.of(_g.state), ArmyFixture.TAG, _g.turn, _c.stock,
		_armies_list())
	var foraged: Dictionary = res["foraged"]
	assert_false(foraged.has(_i(hex)), "unowned land refuses the foraging: nobody's people go")
	Supply.season(_g)
	assert_eq(_g.state.people[_i(hex)], 4000, "the people of the hex are unchanged")
	assert_eq(a.men(), 1000, "the land feeds the men all the same")


func test_country_step_writes_nothing_and_the_phase_applies_it() -> void:
	var town_army := _army(_town)
	var farm := _with_cover(0)[0]
	_no_depots()
	_g.state.people[_i(farm)] = 3000
	var far := _army(farm)
	var digest_before := Armies.digest(_g)
	var stock_before := _c.stock.duplicate()
	var people_before := _g.state.people.duplicate()
	var list := _armies_list()
	var res := Supply.country_step(_g, StateView.of(_g.state), ArmyFixture.TAG, _g.turn, _c.stock, list)
	assert_eq(Armies.digest(_g), digest_before, "country_step changes no army")
	assert_eq(_c.stock, stock_before, "nor the stores")
	assert_eq(_g.state.people, people_before, "nor the people")
	Supply.season(_g)
	var losses: Dictionary = res["losses"]
	var states: Dictionary = res["states"]
	assert_eq(_men_of(town_army.id), 1000 - int(losses.get(town_army.id, 0)))
	assert_eq(_men_of(far.id), 1000 - int(losses.get(far.id, 0)))
	assert_eq(far.supply, int(states.get(far.id, -1)), "the phase writes the state country_step gave")
	assert_eq(town_army.supply, int(states.get(town_army.id, -1)))


func test_seeded_states_match_the_phase() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1480
	for case_i: int in 20:
		_fresh()
		_g.turn = rng.randi_range(1, 12)
		var land := _genoa_land()
		for k: int in 3:
			var hex := land[rng.randi_range(0, land.size() - 1)]
			_g.state.people[_i(hex)] = rng.randi_range(0, 6000)
			_army(hex, rng.randi_range(1, 4))
		_set_stock(&"grain", rng.randi_range(0, 3))
		_set_stock(&"fish", rng.randi_range(0, 3))
		var list := _armies_list()
		var stock := _c.stock.duplicate()
		var res := Supply.country_step(_g, StateView.of(_g.state), ArmyFixture.TAG, _g.turn, stock, list)
		var people_before := _g.state.people.duplicate()
		var stock_before := _c.stock.duplicate()
		Supply.season(_g)
		var losses: Dictionary = res["losses"]
		var food: Dictionary = res["food_taken"]
		var foraged: Dictionary = res["foraged"]
		for row: Dictionary in list:
			var id: int = row["id"]
			assert_eq(_men_of(id), int(row["men"]) - int(losses.get(id, 0)), "case %d: men of army %d" % [case_i, id])
		assert_eq(_stock(&"grain"), stock_before[_good(&"grain")] - int(food.get("grain", 0)), "case %d: grain" % case_i)
		assert_eq(_stock(&"fish"), stock_before[_good(&"fish")] - int(food.get("fish", 0)), "case %d: fish" % case_i)
		for i: int in foraged:
			assert_eq(_g.state.people[i], people_before[i] - int(foraged[i]), "case %d: people of hex %d" % [case_i, i])


func test_army_food_counts_only_the_men_in_supply() -> void:
	_army(_town, 10)
	assert_eq(Supply.army_food(_g, ArmyFixture.TAG), 1, "5,000 men in supply eat one load")
	_no_depots()
	assert_eq(Supply.army_food(_g, ArmyFixture.TAG), 0, "with no depot nothing is in supply, nothing is eaten")


func test_a_country_with_no_armies_is_never_asked_for_a_field() -> void:
	# The season's loop touches only countries with armies: no stores move, no army changes.
	var stock_before := _c.stock.duplicate()
	Supply.season(_g)
	assert_eq(_c.stock, stock_before)
	assert_eq(Armies.of_country(_g, ArmyFixture.TAG).size(), 0)


## M7 (4.12): a hostile army cuts its hex out of the field, and occupied land is never supply of its owner.
func test_a_hostile_army_and_occupied_land_are_not_supply() -> void:
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	assert_ne(enemy, &"", "Genoa has a neighbour")
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	var before := Supply.field(_g, ArmyFixture.TAG, false)
	var found: Array[int] = []
	for i: int in before.size():
		if before[i] == 1 and _g.map.index_of(_town) != i and found.size() < 2:
			found.append(i)
	assert_eq(found.size(), 2, "Genoa has two field hexes besides its depot")
	ArmyFixture.army(_g, enemy, _g.map.hex_of(found[0]), _g.defs.units[0].id, 1)
	assert_false(Supply.in_supply(_g, ArmyFixture.TAG, _g.map.hex_of(found[0]), false),
		"a hex with a hostile army is out of supply")
	Occupation.capture(_g, _g.map.hex_of(found[1]), enemy, &"walk", {})
	assert_false(Supply.in_supply(_g, ArmyFixture.TAG, _g.map.hex_of(found[1]), false),
		"land the enemy occupies is out of supply")


## M7 review: a captured town is a depot for its occupier (it controls it); a captured fortress is not (only the owner who also
## controls it has the depot).
func test_a_captured_town_is_a_depot_for_its_occupier_and_a_captured_fortress_is_not() -> void:
	var g := EconomyFixture.game(&"SAV", false, true, 1480, true)
	Occupation.setup(g)
	var sav := Countries.by_tag(g, &"SAV")
	var nb := WarFixture.neighbour_of(g, &"SAV")
	WarFixture.at_war(g, &"SAV", nb)
	var town := Army.NO_HEX
	var fort := Army.NO_HEX
	for i: int in g.map.hex_count():
		var h := g.map.hex_of(i)
		if g.map.land[i] != 1 or int(g.state.owner[i]) != sav.id:
			continue
		if town == Army.NO_HEX and g.state.main_use[i] == Economy.SETTLEMENTS and Occupation.fortress_level(g, h) == 0 \
				and int(g.state.level[i]) >= g.defs.depot_min_level:
			town = h
		if fort == Army.NO_HEX and Occupation.fortress_level(g, h) > 0:
			fort = h
	assert_true(town != Army.NO_HEX and fort != Army.NO_HEX, "SAV has a depot town and a fortress")
	assert_true(Supply.is_depot(g, &"SAV", town) and Supply.is_depot(g, &"SAV", fort), "both are SAV's depots before the war")
	Occupation.capture(g, town, nb, &"walk", {})
	Occupation.capture(g, fort, nb, &"walk", {})
	Occupation.flush(g)
	assert_true(Supply.is_depot(g, nb, town), "the occupier's captured town is its depot")
	assert_false(Supply.is_depot(g, nb, fort), "the occupier's captured fortress is no depot")
	assert_false(Supply.is_depot(g, &"SAV", town), "the owner's lost town is no depot for the owner")


## M7 review (perf): with no war the depot key does not scan the armies (a counter, no timing); a live war makes it scan.
func test_no_war_key_does_not_scan_the_armies() -> void:
	var g := EconomyFixture.game(&"SAV", false, true, 1480, true)
	Occupation.setup(g)
	var sav := Countries.by_tag(g, &"SAV")
	var nb := WarFixture.neighbour_of(g, &"SAV")
	var placed := 0
	for i: int in g.map.hex_count():
		if placed < 20 and g.map.land[i] == 1 and int(g.state.owner[i]) == sav.id:
			WarFixture.army_at(g, &"SAV", g.map.hex_of(i), 1)
			placed += 1
	var hex: Vector2i = g.armies[0].hex
	var before := Supply.army_key_scans
	for k: int in 5:
		Supply.field(g, &"SAV", false)
		Supply.in_supply(g, &"SAV", hex, k % 2 == 0)
	assert_eq(Supply.army_key_scans, before, "no war: the key never scans the armies")
	WarFixture.at_war(g, &"SAV", nb)
	Supply.field(g, &"SAV", false)
	assert_gt(Supply.army_key_scans, before, "a live war: the key scans the armies")
