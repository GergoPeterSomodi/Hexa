## EconomyPreview (docs/architecture/m4-build-spec.md 4.17, 5.6, 9): `with(game, tag, {}, 8)` equals eight played seasons for
## every country of the 1480 scenario (calm weather), works under way stand from their ready turns, a tax change, `expected`,
## `worth_by_hex`, both measures, and a preview never changes the game.
extends GutTest

@warning_ignore_start("integer_division")

const VINEYARD := ImproveRules.VINEYARD
const WINE := 3


func _lines_of(lines: Array) -> Dictionary:
	var out := {}
	for line: Dictionary in lines:
		if Treasury.SPENDING.has(line["why"]) or line["why"] == &"dev":
			continue  # the player's choices and the console, not the season's income
		var key := "%s|%d,%d" % [line["why"], (line["hex"] as Vector2i).x, (line["hex"] as Vector2i).y]
		out[key] = int(line["amount"])
	return out


func _flow(c: Country, why: StringName, sign_of: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for g: int in c.stock.size():
		out.append(Stores.flow(c, g, why, true) * sign_of)
	return out


## Plays `count` seasons and checks every country's preview (made before the game moves) against what happened.
func _check_against_play(g: Game, count: int, label: String) -> void:
	var previews := {}
	for c: Country in g.countries:
		previews[c.tag] = EconomyPreview.with(g, c.tag, {}, count)
	for k: int in count:
		assert_true(bool(Season.run(g)["ok"]))
		for c: Country in g.countries:
			var p: Dictionary = (previews[c.tag]["seasons"] as Array)[k]
			var where := "%s %s season %d" % [label, String(c.tag), k + 1]
			assert_eq(int(p["turn"]), g.turn - 1, where + " turn")
			assert_eq(_flow(c, &"made", 1), p["made"], where + " made")
			assert_eq(_flow(c, &"used", -1), p["used"], where + " used")
			assert_eq(_flow(c, &"sold", -1), p["sold"], where + " sold")
			assert_eq(c.stock, p["stock"], where + " stock")
			assert_eq(_lines_of(c.ledger_closed["lines"] as Array), _lines_of(p["lines"] as Array), where + " money lines")
			var closed: Array[Dictionary] = []
			closed.assign(c.ledger_closed["lines"] as Array)
			assert_eq(Treasury.left_over(closed), int(p["net"]), where + " net")


## The people of the season just played, from the game itself: the country's total, its settlements', the closed flows, the food.
func _people_of(g: Game, c: Country) -> Dictionary:
	var total := 0
	var towns := 0
	for i: int in Territory.districts(g, c.id):
		total += g.state.people[i]
		if g.state.main_use[i] == Economy.SETTLEMENTS:
			towns += g.state.people[i]
	var flows: PackedInt32Array = (c.people_closed["flows"] as PackedInt32Array) if c.people_closed.has("flows") else PackedInt32Array([0, 0, 0])
	return {"people": total, "towns": towns, "fed": c.food_fed, "grew": flows[People.GREW], "starved": -flows[People.STARVED],
		"left": -flows[People.LEFT]}


## Plays `count` seasons (the people phase between works and stats) and checks the previews, people included.
func _check_people_against_play(g: Game, count: int, label: String) -> int:
	var previews := {}
	for c: Country in g.countries:
		previews[c.tag] = EconomyPreview.with(g, c.tag, {}, count)
	var moved := 0
	var levels := 0
	for k: int in count:
		PeopleFixture.season(g)
		for c: Country in g.countries:
			var p: Dictionary = (previews[c.tag]["seasons"] as Array)[k]
			var where := "%s %s season %d" % [label, String(c.tag), k + 1]
			var real := _people_of(g, c)
			for key: String in real:
				assert_eq(int(p[key]), int(real[key]), where + " " + key)
			assert_eq(_flow(c, &"made", 1), p["made"], where + " made")
			assert_eq(_flow(c, &"used", -1), p["used"], where + " used")
			assert_eq(c.stock, p["stock"], where + " stock")
			assert_eq(_lines_of(c.ledger_closed["lines"] as Array), _lines_of(p["lines"] as Array), where + " money lines")
			moved += int(p["grew"]) + int(p["starved"]) + int(p["left"])
			levels += (p["levels"] as Array).size()
	return moved * 1000 + levels


func test_eight_seasons_equal_play_for_every_country_with_people_growing() -> void:
	var g := EconomyFixture.game(&"GEN", false, true, EconomyFixture.SEED, false)
	var score := _check_people_against_play(g, 8, "growing")
	assert_gt(score / 1000, 1000, "people moved")


func test_a_village_that_fills_its_room_in_the_window_levels_up_when_it_does_in_play() -> void:
	# The village near Turin (6, 11) fills 4,000 at turn 34 (4.11 d): from turn 28 the window of eight seasons holds it.
	var d := PeopleFixture.always_fed(EconomyFixture.committed())
	var g := PeopleFixture.genoa(d)
	PeopleFixture.play(g, 27)
	var levels := _check_people_against_play(g, 8, "village")
	assert_gt(levels % 1000, 0, "a level change happened in the window")


func test_eight_seasons_equal_play_with_works_under_way_and_people_growing() -> void:
	var g := EconomyFixture.game(&"GEN", true, true, EconomyFixture.SEED, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 78
	for c: Country in g.countries:
		g.dev_money(c.tag, 5000)
		for n: int in 6:
			var districts := Territory.districts(g, c.id)
			if districts.is_empty():
				break
			var hex := g.map.hex_of(districts[rng.randi_range(0, districts.size() - 1)])
			for row: Dictionary in ImprovePreview.options_of(g, c.tag, hex):
				if bool(row["verdict"]["ok"]):
					g.act(String(row["action"]), {"hex": hex, "family": row["family"], "tag": c.tag})
					break
	assert_gt(g.state.works.size(), 3)
	_check_people_against_play(g, 8, "works+people")


func test_eight_seasons_equal_play_when_the_towns_go_hungry() -> void:
	var d := PeopleFixture.no_food(EconomyFixture.committed())
	var g := PeopleFixture.genoa(d)
	var score := _check_people_against_play(g, 8, "hungry")
	assert_gt(score / 1000, 100)
	var starved := 0
	for p: Dictionary in EconomyPreview.with(PeopleFixture.genoa(d), &"GEN", {}, 8)["seasons"]:
		starved += int(p["starved"])
	assert_gt(starved, 0, "the towns starve in the window")


func test_the_stepped_hexes_are_the_settlements_and_the_hexes_not_full() -> void:
	var g := EconomyFixture.game(&"GEN", false, true, EconomyFixture.SEED, false)
	var c := Countries.by_tag(g, &"GEN")
	var active := People.active(g, StateView.of(g.state), c.id)
	var want := 0
	for i: int in Territory.districts(g, c.id):
		var room := People.room_i(g, StateView.of(g.state), i)
		if g.state.main_use[i] == Economy.SETTLEMENTS or g.state.people[i] != room:
			want += 1
	assert_eq(active.size(), want)
	var rec: Dictionary = EconomyPreview.baseline(g, &"GEN", 2, 1)[0]
	assert_gt((rec["steps"] as Dictionary).size(), 3, "the settlements and the districts that fill up move")
	for i: Variant in rec["steps"]:
		assert_true(active.has(int(i)), "only stepped hexes move")


func test_eight_seasons_equal_play_for_every_country() -> void:
	var g := EconomyFixture.game(&"GEN")
	assert_gt(g.countries.size(), 10)
	_check_against_play(g, 8, "plain")


func test_eight_seasons_with_works_under_way_and_a_tax() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var begun := 0
	for c: Country in g.countries:
		g.dev_money(c.tag, 5000)
		for n: int in 6:
			var districts := Territory.districts(g, c.id)
			if districts.is_empty():
				break
			var hex := g.map.hex_of(districts[rng.randi_range(0, districts.size() - 1)])
			for row: Dictionary in ImprovePreview.options_of(g, c.tag, hex):
				if bool(row["verdict"]["ok"]):
					g.act(String(row["action"]), {"hex": hex, "family": row["family"], "tag": c.tag})
					begun += 1
					break
		if c.tag == &"GEN":
			g.act("set_tax", {"level": 2, "tag": c.tag})
	assert_gt(begun, 5, "works were begun")
	assert_gt(g.state.works.size(), 3)
	_check_against_play(g, 8, "works")


func test_a_work_stands_from_its_ready_turn() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var verdict := g.act("build", {"hex": EconomyFixture.VINEYARD_HEX, "family": VINEYARD, "tag": &"GEN"})
	assert_true(bool(verdict["ok"]))
	var seasons: Array = EconomyPreview.with(g, &"GEN", {}, 8)["seasons"]
	assert_eq((seasons[2]["made"] as PackedInt32Array)[WINE], 0, "autumn 1480: the vineyard is not there yet")
	assert_eq((seasons[6]["made"] as PackedInt32Array)[WINE], 12, "autumn 1481: the first vintage")
	var upkeep_before: int = _lines_of(seasons[3]["lines"] as Array)["upkeep_districts|-1,-1"]
	var upkeep_after: int = _lines_of(seasons[4]["lines"] as Array)["upkeep_districts|-1,-1"]
	assert_eq(upkeep_after - upkeep_before, -1, "upkeep from Spring 1481")


func test_a_change_stands_from_the_first_season_and_both_measures_come() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var i := g.map.index_of(EconomyFixture.VINEYARD_HEX)
	var base := EconomyPreview.with(g, &"GEN", {}, 4)
	var after := EconomyPreview.with(g, &"GEN", {"hexes": {i: Vector2i(VINEYARD, 1)}}, 4)
	assert_eq(int(after["year"]["realm"]) - int(base["year"]["realm"]), 22)
	assert_eq(int(after["year"]["net"]) - int(base["year"]["net"]), 10)
	assert_eq(int(base["year"]["realm"]), 507)
	for k: int in 4:
		assert_true((after["seasons"][k] as Dictionary).has("net"))
		assert_true((after["seasons"][k] as Dictionary).has("realm"))


func test_a_tax_change_equals_the_real_one() -> void:
	var g := EconomyFixture.game(&"GEN")
	var preview := EconomyPreview.with(g, &"GEN", {"tax": 2}, 4)
	var real := EconomyFixture.game(&"GEN")
	assert_true(bool(real.act("set_tax", {"level": 2, "tag": &"GEN"})["ok"]))
	var c := Countries.by_tag(real, &"GEN")
	for k: int in 4:
		Season.run(real)
		assert_eq(_lines_of(c.ledger_closed["lines"] as Array), _lines_of((preview["seasons"][k] as Dictionary)["lines"] as Array), "season %d" % k)
	assert_ne(int(EconomyPreview.with(g, &"GEN", {}, 4)["year"]["net"]), int(preview["year"]["net"]))
	assert_eq(Countries.by_tag(g, &"GEN").tax, 1, "the game's tax stays")


func test_expected_is_the_first_season() -> void:
	var g := EconomyFixture.game(&"GEN")
	var first := EconomyPreview.expected(g, &"GEN")
	assert_eq(first, (EconomyPreview.with(g, &"GEN", {}, 1)["seasons"] as Array)[0])
	assert_eq(int(first["net"]), 85)
	assert_eq(EconomyPreview.expected(g, &"NOPE"), {})
	assert_eq((EconomyPreview.with(g, &"NOPE", {}, 4)["seasons"] as Array).size(), 0)


func test_a_preview_never_changes_the_game() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var digest := g.digest()
	var version := g.version
	var turn := g.turn
	var i := g.map.index_of(EconomyFixture.VINEYARD_HEX)
	EconomyPreview.with(g, &"GEN", {"hexes": {i: Vector2i(VINEYARD, 1)}, "tax": 0, "detail": true}, 8)
	EconomyPreview.worth_by_hex(g, &"GEN")
	assert_eq(g.digest(), digest)
	assert_eq(g.version, version)
	assert_eq(g.turn, turn)
	assert_eq(Countries.by_tag(g, &"GEN").stock[WINE], 4)


func test_a_map_only_game_has_nothing() -> void:
	var d := EconomyFixture.defs()
	var g := Game.new_game(EconomyFixture.map(), 5, d)
	assert_eq((EconomyPreview.with(g, &"GEN", {}, 4)["seasons"] as Array).size(), 0)


func test_the_baseline_is_cached_by_version() -> void:
	var g := EconomyFixture.game(&"GEN")
	var a := EconomyPreview.baseline(g, &"GEN", 4, 1)
	assert_true(is_same(a, EconomyPreview.baseline(g, &"GEN", 4, 1)), "the same array")
	g.version += 1
	assert_false(is_same(a, EconomyPreview.baseline(g, &"GEN", 4, 1)), "a new version makes it again")


func test_worth_by_hex_follows_4_17() -> void:
	var g := EconomyFixture.game(&"GEN")
	var rows := EconomyPreview.worth_by_hex(g, &"GEN")
	assert_true(is_same(rows, EconomyPreview.worth_by_hex(g, &"GEN")), "cached")
	var genoa := {}
	for row: Dictionary in rows:
		if row["hex"] == Vector2i(8, 13):
			genoa = row
	assert_false(genoa.is_empty())
	# fish 6 at 1.0, dues 30, people 30,000 x 1,000 x 1,000 / 1,000 x 1,000 / 10^9 = 30, less upkeep 3 (the barracks' 1 in it) and walls 4.
	var fish_price := g.defs.goods[Economy.FISH].price_milli
	assert_eq(int(genoa["worth"]), 6 * fish_price / 1000 + 30 + 30 - 7)
	assert_eq(int(genoa["upkeep"]), 7)
	assert_eq(genoa["label"], "Genoa (8, 13)")
	var total := 0
	for row: Dictionary in rows:
		total += int(row["worth"])
	assert_gt(total, 0)


func test_worth_of_equals_the_list_entry_for_every_district_of_genoa() -> void:
	var g := EconomyFixture.game(&"GEN")
	var rows := {}
	for row: Dictionary in EconomyPreview.worth_by_hex(g, &"GEN"):
		rows[row["hex"]] = row
	var c := Countries.by_tag(g, &"GEN")
	var checked := 0
	for i: int in Territory.districts(g, c.id):
		var hex := g.map.hex_of(i)
		assert_eq(EconomyPreview.worth_of(g, &"GEN", hex), rows.get(hex, {}), "hex %s" % str(hex))
		checked += 1
	assert_gt(checked, 10)
	assert_eq(EconomyPreview.worth_of(g, &"GEN", Vector2i(0, 0)), {}, "a hex of nobody's")
	assert_eq(EconomyPreview.worth_of(g, &"NOPE", Vector2i(8, 13)), {})


func test_a_short_and_a_long_ask_share_the_baseline_and_agree() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	g.dev_money(&"GEN", 2000)
	assert_true(bool(g.act("build", {"hex": EconomyFixture.VINEYARD_HEX, "family": VINEYARD, "tag": &"GEN"})["ok"]))
	var short := EconomyPreview.with(g, &"GEN", {}, 1)
	var long := EconomyPreview.with(g, &"GEN", {}, 8)
	var again := EconomyPreview.with(g, &"GEN", {}, 1)
	assert_eq(short["seasons"], again["seasons"])
	assert_eq((long["seasons"] as Array)[0], (short["seasons"] as Array)[0])
	var fresh := EconomyFixture.game(&"GEN", true)
	fresh.dev_money(&"GEN", 2000)
	fresh.act("build", {"hex": EconomyFixture.VINEYARD_HEX, "family": VINEYARD, "tag": &"GEN"})
	assert_eq(EconomyPreview.with(fresh, &"GEN", {}, 8)["seasons"], long["seasons"], "the long ask first gives the same")
	assert_true(is_same(EconomyPreview.baseline(g, &"GEN", 1, 1), EconomyPreview.baseline(g, &"GEN", 8, 1)), "one array for every horizon")



# --- worth_seasons (docs/architecture/m4-5-build-spec.md 4.10, 5.6) -------------------------------------------------


func _hex_row(ws: Dictionary, g: Game, hex: Vector2i) -> int:
	return (ws["hexes"] as PackedInt32Array).find(g.map.index_of(hex))


func _worths(ws: Dictionary, h: int) -> Array:
	var n := int(ws["seasons"])
	return Array((ws["worth"] as PackedInt32Array).slice(h * n, h * n + n))


func test_worth_seasons_at_turn_1_equals_the_districts_of_4_10() -> void:
	var g := EconomyFixture.game(&"GEN")
	var ws := EconomyPreview.worth_seasons(g, &"GEN", 4)
	assert_eq(int(ws["turn"]), 1)
	assert_eq(int(ws["seasons"]), 4)
	assert_eq((ws["hexes"] as PackedInt32Array).size(), 14)
	var want := {Vector2i(8, 13): [59, 62, 59, 48], Vector2i(7, 14): [0, 0, 35, 70], Vector2i(7, 12): [2, 2, 62, 2],
		Vector2i(6, 13): [9, 11, 10, 8], Vector2i(9, 13): [5, 5, 5, 18]}
	for hex: Vector2i in want:
		assert_eq(_worths(ws, _hex_row(ws, g, hex)), want[hex], str(hex))
	var genoa := _hex_row(ws, g, Vector2i(8, 13))
	var dues := (ws["dues"] as PackedInt32Array).slice(genoa * 4, genoa * 4 + 4)
	assert_eq(dues, PackedInt32Array([30, 33, 30, 21]))
	var upkeep := (ws["upkeep"] as PackedInt32Array).slice(genoa * 4, genoa * 4 + 4)
	assert_eq(upkeep, PackedInt32Array([7, 7, 7, 7]))
	var fish := 0
	for k: int in 4:
		fish += (ws["goods"] as PackedInt32Array)[(genoa * 4 + k) * g.defs.goods.size() + Economy.FISH]
	assert_eq(fish, 22)
	var total := 0
	for v: int in ws["worth"] as PackedInt32Array:
		total += v
	assert_eq(total, 529, "all the land, each place rounded down")


func test_worth_by_hex_is_the_first_season_hex_by_hex() -> void:
	var g := EconomyFixture.game(&"GEN")
	var ws := EconomyPreview.worth_seasons(g, &"GEN", 4)
	var one := EconomyPreview.worth_seasons(g, &"GEN", 1)
	var listed := 0
	for row: Dictionary in EconomyPreview.worth_by_hex(g, &"GEN"):
		var h := _hex_row(ws, g, row["hex"])
		assert_gte(h, 0)
		assert_eq((ws["worth"] as PackedInt32Array)[h * 4], int(row["worth"]), str(row["hex"]))
		assert_eq((ws["upkeep"] as PackedInt32Array)[h * 4], int(row["upkeep"]), str(row["hex"]))
		assert_eq((one["worth"] as PackedInt32Array)[h], int(row["worth"]), "one season asked")
		listed += 1
	assert_gt(listed, 5)
	for h: int in (ws["hexes"] as PackedInt32Array).size():  # a hex worth_by_hex leaves out gives and costs nothing
		var hex := g.map.hex_of((ws["hexes"] as PackedInt32Array)[h])
		if EconomyPreview.worth_of(g, &"GEN", hex).is_empty():
			assert_eq((ws["worth"] as PackedInt32Array)[h * 4], 0)
			assert_eq((ws["upkeep"] as PackedInt32Array)[h * 4], 0)


func test_a_work_under_way_stands_from_its_ready_turn_in_the_window() -> void:
	var g := InsightsFixture.genoa_1483()
	var genoa := Vector2i(8, 13)
	var work := g.state.work_at(genoa)
	assert_not_null(work, "the city is still being built at Spring 1483")
	var ready := Works.ready_turn(g, work)
	assert_gt(ready, g.turn)
	assert_lt(ready, g.turn + 4, "it lands inside the window")
	var ws := EconomyPreview.worth_seasons(g, &"GEN", 4)
	var h := _hex_row(ws, g, genoa)
	var seasons := _worths(ws, h)
	var landed := ready - g.turn
	var upkeep := (ws["upkeep"] as PackedInt32Array)
	assert_eq(upkeep[h * 4 + landed - 1], upkeep[h * 4], "the walled town until then")
	assert_gt(upkeep[h * 4 + landed], upkeep[h * 4 + landed - 1], "the city costs more from the ready turn")
	assert_ne(seasons[landed], seasons[0])
	var plain := EconomyPreview.with(g, &"GEN", {}, 4)
	assert_eq(int(plain["seasons"][landed]["turn"]), ready)


func test_worth_seasons_is_cached_by_version_and_changes_nothing() -> void:
	var g := EconomyFixture.game(&"GEN")
	var digest := g.digest()
	var version := g.version
	var a := EconomyPreview.worth_seasons_shared(g, &"GEN", 4)
	assert_true(is_same(EconomyPreview.worth_seasons_shared(g, &"GEN", 4), EconomyPreview.worth_seasons_shared(g, &"GEN", 4)), "cached")
	assert_false(is_same(a, EconomyPreview.worth_seasons_shared(g, &"GEN", 2)), "the seasons are in the key")
	assert_eq(g.digest(), digest)
	assert_eq(g.version, version)
	g.dev_money(&"GEN", 100)
	var after := EconomyPreview.worth_seasons_shared(g, &"GEN", 4)
	assert_false(is_same(after, a), "a cached result is not served after an action")
	assert_true((EconomyPreview.worth_seasons(g, &"NOPE", 4)["hexes"] as PackedInt32Array).is_empty())
	var map_only := Game.new_game(EconomyFixture.map(), 5, EconomyFixture.defs())
	assert_true((EconomyPreview.worth_seasons(map_only, &"GEN", 4)["hexes"] as PackedInt32Array).is_empty())


func test_worth_seasons_top_and_total_name_the_makers() -> void:
	var g := EconomyFixture.game(&"GEN")
	var ws := EconomyPreview.worth_seasons(g, &"GEN", 4)
	var wine := 3
	assert_eq((ws["total"] as PackedInt32Array)[wine], 24)
	assert_eq(g.map.hex_of((ws["top"] as PackedInt32Array)[wine]), Vector2i(7, 12))
	assert_eq((ws["total"] as PackedInt32Array)[4], 0, "no salt")
	assert_eq((ws["top"] as PackedInt32Array)[4], -1)


func test_worth_seasons_equals_the_worth_worked_out_by_hand_under_works() -> void:
	# every hex of every season: the one pass equals the worth of each season worked out from a base per view
	var g := EconomyFixture.game(&"GEN", true)
	g.dev_money(&"GEN", 5000)
	for hex: Vector2i in [Vector2i(8, 13), Vector2i(7, 14), EconomyFixture.VINEYARD_HEX]:
		for row: Dictionary in ImprovePreview.options_of(g, &"GEN", hex):
			if bool(row["verdict"]["ok"]):
				g.act(String(row["action"]), {"hex": hex, "family": row["family"], "tag": &"GEN"})
				break
	assert_gt(g.state.works.size(), 0)
	var ws := EconomyPreview.worth_seasons(g, &"GEN", 8)
	var records := EconomyPreview.baseline(g, &"GEN", 8, 1)
	var run: Array = EconomyPreview.with(g, &"GEN", {}, 8)["seasons"]
	var c := Countries.by_tag(g, &"GEN")
	var prices := Economy.market_prices(g, null, 0, c.stock)
	for h: int in (ws["hexes"] as PackedInt32Array).size():
		var i: int = (ws["hexes"] as PackedInt32Array)[h]
		for k: int in 8:
			var rec: Dictionary = records[k]
			var base := Economy.district_base(g, rec["view"] as StateView, g.map.hex_of(i))
			var goods := PackedInt32Array()
			goods.resize(g.defs.goods.size())
			var out := Economy.add_output(base, Economy.slot_for(int(g.map.climate[i]), int(rec["season"])), Economy.CALM, c.tax, g.defs, goods)
			var milli := 0
			for n: int in goods.size():
				milli += goods[n] * prices[n]
			var factor := EconomySeason.factor_of(g, int(run[k]["content"]))
			var rate: int = g.defs.town_tax_milli * factor / 1000 if int(base["family"]) == Economy.SETTLEMENTS else g.defs.country_tax_milli
			var taxes: int = int(base["people"]) * rate * g.defs.tax_permille[c.tax] / 1000000000
			var want: int = milli / 1000 + int(out["ducats"]) + taxes - int(out["upkeep"]) - int(out["walls"])
			assert_eq((ws["worth"] as PackedInt32Array)[h * 8 + k], want, "hex %s season %d" % [str(g.map.hex_of(i)), k])


# --- the armies (M6 R9): the preview's supply, food, upkeep and refill equal the played seasons -------------------------

## A land hex of TAG out of supply (its armies forage there), or NO_HEX.
func _out_of_supply(g: Game) -> Vector2i:
	for i: int in Territory.districts(g, Countries.by_tag(g, ArmyFixture.TAG).id):
		var hex := g.map.hex_of(i)
		if not Supply.in_supply(g, ArmyFixture.TAG, hex, false):
			return hex
	return ArmyFixture.NO_HEX


## Genoa with a town, two pikemen raised in it (in supply, a little short of men: a refill is due), and two pikemen out of
## supply on the land beside it (they forage, and starve where the land feeds no one).
func _armed() -> Game:
	var g := ArmyFixture.game()
	g.defs.supply_reach = 1  # a copy the game owns: most of Genoa's land is then out of supply
	var town := ArmyFixture.find_town(g)
	ArmyFixture.town(g, town)
	ArmyFixture.rich(g)
	assert_true(bool(ArmyFixture.raise_now(g, {"hex": town, "kind": 0, "count": 2, "tag": ArmyFixture.TAG})["ok"]))
	var lost := Armies.lose_men(g, Armies.at(g, town)[0], 300, &"test")
	assert_true(lost > 0, "the town's army lost men for the refill to make up")
	var away := _out_of_supply(g)
	assert_true(away != ArmyFixture.NO_HEX, "a land hex of TAG out of supply")
	ArmyFixture.army(g, ArmyFixture.TAG, away, 0, 2)
	return g


func _upkeep_line(lines: Array) -> int:
	for line: Dictionary in lines:
		if line["why"] == &"upkeep_army":
			return int(line["amount"])
	return 0


## Checks the first `count` seasons of the preview of `preview_game` (with `change` laid over it) against the seasons of
## `g` played now, one by one.
func _check_armed_against_play(g: Game, count: int, change: Dictionary, label: String, preview_game: Game = null) -> void:
	var source := g if preview_game == null else preview_game
	var seasons: Array = EconomyPreview.with(source, ArmyFixture.TAG, change, count)["seasons"]
	var c := Countries.by_tag(g, ArmyFixture.TAG)
	var armies_seen := 0
	for k: int in count:
		assert_true(bool(Season.run(g)["ok"]))
		var p: Dictionary = seasons[k]
		var where := "%s season %d" % [label, k + 1]
		armies_seen += Armies.of_country(g, ArmyFixture.TAG).size()
		assert_eq(_flow(c, &"made", 1), p["made"], where + " made")
		assert_eq(_flow(c, &"used", -1), p["used"], where + " used")
		assert_eq(_flow(c, &"sold", -1), p["sold"], where + " sold")
		assert_eq(c.stock, p["stock"], where + " stock")
		assert_eq(c.food_fed, int(p["fed"]), where + " fed")
		var closed: Array[Dictionary] = []
		closed.assign(c.ledger_closed["lines"] as Array)
		assert_eq(_upkeep_line(closed), _upkeep_line(p["lines"] as Array), where + " upkeep_army")
		assert_eq(Treasury.left_over(closed), int(p["net"]), where + " net")
		var total := 0
		var towns := 0
		for i: int in Territory.districts(g, c.id):
			total += g.state.people[i]
			if g.state.main_use[i] == Economy.SETTLEMENTS:
				towns += g.state.people[i]
		assert_eq(total, int(p["people"]), where + " people")
		assert_eq(towns, int(p["towns"]), where + " towns")
	assert_true(armies_seen > 0, "the armies stood through the seasons")


func test_eight_seasons_with_armies_equal_play() -> void:
	var g := _armed()
	_check_armed_against_play(g, 4, {}, "armies")


func test_a_what_if_settlement_that_adds_a_depot_equals_play_with_armies() -> void:
	var g := _armed()
	var away := _out_of_supply(g)
	var depot := away  # a settlement on the army's own hex: the depot is in reach of the army at once
	var i := g.map.index_of(depot)
	var pair := Vector2i(Economy.SETTLEMENTS, g.defs.depot_min_level)
	var before := Supply.in_supply(g, ArmyFixture.TAG, away, false)
	var real := _armed()
	var j := real.map.index_of(depot)
	real.state.main_use[j] = Economy.SETTLEMENTS
	real.state.level[j] = g.defs.depot_min_level
	real.districts.clear()
	real.version += 1
	assert_false(before, "the army starts out of supply, so the new depot is what brings it in")
	assert_true(Supply.in_supply(real, ArmyFixture.TAG, away, false), "the depot puts the army in supply")
	_check_armed_against_play(real, 4, {"hexes": {i: pair}}, "depot", g)


## An army of TAG on land another country holds: it forages that land (the other country's people), and none of them is in
## TAG's people or towns (play and preview agree for six seasons).
func test_an_army_on_foreign_land_forages_the_foreign_people_not_ours() -> void:
	var g := _armed()
	var id := ArmyFixture.id_of(g, ArmyFixture.TAG)
	var foreign := ArmyFixture.NO_HEX
	for i: int in g.map.hex_count():
		if g.map.is_land(g.map.hex_of(i)) and int(g.state.owner[i]) > 0 and int(g.state.owner[i]) != id:
			foreign = g.map.hex_of(i)
			break
	assert_true(foreign != ArmyFixture.NO_HEX, "a land hex another country holds")
	ArmyFixture.army(g, ArmyFixture.TAG, foreign, 0, 2)
	_check_armed_against_play(g, 6, {}, "foreign")
