## Reminders (docs/architecture/m3-build-spec.md 4.8, 5.6, 9; docs/architecture/m4-build-spec.md 4.18, 9): `free_slot` (0 of
## 2: a line; 2 of 2: none; map-only: none), `winter_halt` only in Autumn with snow works, worst first, the cache, equal
## after a save and load. M4: `treasury_empty` (-1 gives it, 0 does not), `goods_running_out` (a stock that just covers the
## eight seasons gives no line; food at k = 2 is serious, k = 3 is not), `treasury_falling`, and the order of all five.
## The games of the M3 cases are rich (money and stores no season moves) so that the M4 rules stay quiet in them.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const WOODS := Vector2i(9, 11)
const SAVONA := Vector2i(7, 12)
const AUTUMN := 3

var _g: Game


func before_each() -> void:
	var defs := EconomyFixture.defs()
	defs.start_treasury_base = 1000000
	defs.reserve_seasons = 10000
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": &"GEN"})["ok"]))
	_g.improvement.clear(SAVONA)


func _build(hex: Vector2i, family: int) -> bool:
	return bool(_g.act("build", {"hex": hex, "family": family, "tag": &"GEN"})["ok"])


## A Genoese wild hex of snow climate other than WOODS where a timber work may begin.
func _second_snow_hex() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if hex != WOODS and int(_g.map.climate[i]) == 0 and Territory.owner_tag(_g, hex) == &"GEN" \
				and bool(_g.check("build", {"hex": hex, "family": ImproveRules.TIMBER, "tag": &"GEN"})["ok"]):
			return hex
	return WorksView.NO_HEX


func test_a_free_slot() -> void:
	var line := Reminders.free_slot(_g, &"GEN")
	assert_eq(line["text"], "A work slot is free: 0 of 2 in use.")
	assert_eq([line["kind"], line["severity"], line["hint"]], [&"free_slot", 1, ""])
	assert_eq(line["action"], [&"look_at", Countries.by_tag(_g, &"GEN").capital])
	assert_eq(line["action_label"], "Show Genoa")
	assert_true(_build(SAVONA, ImproveRules.VINEYARD))
	assert_eq(Reminders.free_slot(_g, &"GEN")["text"], "A work slot is free: 1 of 2 in use.")
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	assert_eq(Reminders.free_slot(_g, &"GEN"), {}, "2 of 2: no line")


func test_no_free_slot_in_a_map_only_game_or_for_no_country() -> void:
	var sandbox := Game.new_game(_g.map, 1, _g.defs)
	assert_eq(Reminders.free_slot(sandbox, &""), {})
	assert_eq(Reminders.unfinished(sandbox, &""), [] as Array[Dictionary])
	assert_eq(Reminders.free_slot(_g, &"ZZZ"), {}, "no such country")
	assert_eq(Reminders.free_slot(_g, &""), {})


func test_winter_halt_only_in_autumn_with_snow_works() -> void:
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	assert_true(_build(SAVONA, ImproveRules.VINEYARD))
	assert_eq(Reminders.winter_halt(_g, &"GEN"), {}, "Spring")
	for turn: int in [2, 4, 5]:
		_g.turn = turn
		assert_eq(Reminders.winter_halt(_g, &"GEN"), {}, "turn %d is not Autumn" % turn)
	_g.turn = AUTUMN
	var line := Reminders.winter_halt(_g, &"GEN")
	assert_eq(line["text"], "Winter comes: 1 work in the snow stops until spring: timber, first stage, %s." % Words.place(_g, WOODS),
		"the vineyard on frost land is not named")
	assert_eq([line["kind"], line["severity"], line["hint"]], [&"winter_halt", 2, ""])
	assert_eq(line["action"], [&"look_at", WOODS])
	assert_eq(line["action_label"], "Go to (9, 11)")
	assert_eq(line["hex"], WOODS)
	assert_eq(Reminders.winter_halt(_g, &"BBB"), {}, "another country's works are not named")


func test_two_works_in_the_snow_are_listed() -> void:
	var other := _second_snow_hex()
	assert_ne(other, WorksView.NO_HEX, "Genoa has a second snow hex to work")
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	assert_true(_build(other, ImproveRules.TIMBER))
	_g.turn = AUTUMN
	var both := "timber, first stage, %s and timber, first stage, %s" % [Words.place(_g, WOODS), Words.place(_g, other)]
	assert_eq(Reminders.winter_halt(_g, &"GEN")["text"], "Winter comes: 2 works in the snow stop until spring: %s." % both)
	assert_eq(Reminders.winter_halt(_g, &"GEN")["hex"], WOODS, "the first work's hex")


func test_the_defs_switch_turns_the_winter_rule_off() -> void:
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	_g.turn = AUTUMN
	_g.defs.works_halt_in_snow_winter = false
	assert_eq(Reminders.winter_halt(_g, &"GEN"), {})
	_g.defs.works_halt_in_snow_winter = true


func test_worst_first_and_the_cache() -> void:
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	_g.turn = AUTUMN
	_g.version += 1
	var lines := Reminders.unfinished(_g, &"GEN")
	assert_eq(lines.size(), 2)
	assert_eq([lines[0]["kind"], lines[1]["kind"]], [&"winter_halt", &"free_slot"], "severity 2 before 1")
	assert_eq(lines, Reminders.unfinished(_g, &"GEN"), "the cached answer is the same")
	var cached := _g.view_cache.size()
	assert_eq(Reminders.unfinished(_g, &"GEN"), lines)
	assert_eq(_g.view_cache.size(), cached, "the second ask is served from the cache")
	assert_true(_build(SAVONA, ImproveRules.VINEYARD))
	var after := Reminders.unfinished(_g, &"GEN")
	assert_eq(after.size(), 1, "the slots are full: the version moved, the cache did not serve the old answer")
	assert_eq(after[0]["kind"], &"winter_halt")
	_g.turn = 2
	_g.version += 1
	assert_eq(Reminders.unfinished(_g, &"GEN"), [] as Array[Dictionary], "Summer, no slot free")


func test_cached_lines_are_copies() -> void:
	_g.turn = AUTUMN
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	var first := Reminders.unfinished(_g, &"GEN")
	var text := str(first[0]["text"])
	first[0]["text"] = "changed"
	(first[0]["action"] as Array).clear()
	first.clear()
	var again := Reminders.unfinished(_g, &"GEN")
	assert_eq(again.size(), 2)
	assert_eq(again[0]["text"], text)
	assert_eq((again[0]["action"] as Array).size(), 2)


func test_a_free_slot_alone_is_not_serious() -> void:
	var lines := Reminders.unfinished(_g, &"GEN")
	assert_eq(lines.size(), 1)
	assert_eq(lines[0]["severity"], 1)
	assert_eq(Reminders.RULES, [&"treasury_empty", &"hunger", &"goods_running_out", &"winter_halt", &"treasury_falling", &"town_full", &"free_slot"] as Array[StringName])


func test_reminders_are_equal_after_a_save_and_load() -> void:
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	_g.turn = AUTUMN
	var before := Reminders.unfinished(_g, &"GEN")
	var dir := "user://test_reminders_%d/" % Time.get_ticks_usec()
	assert_eq(SaveFile.write(_g, "1", {"saved_unix": 1}, {}, dir), "")
	var read := SaveFile.read("1", dir)
	var back := Snapshot.restore(read["body"] as Dictionary, _g.map, _g.defs)["game"] as Game
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)
	assert_not_null(back)
	assert_eq(Reminders.unfinished(back, &"GEN"), before)


# ----- M4 ---------------------------------------------------------------------------------------------------------


func test_treasury_empty() -> void:
	var c := Countries.by_tag(_g, &"GEN")
	assert_true(_g.dev_money(&"GEN", -c.treasury - 120))
	var line := Reminders.treasury_empty(_g, &"GEN")
	assert_eq(line["text"], "The treasury is empty: 120 ducats owed. Upkeep is still paid; no work can begin.")
	assert_eq([line["kind"], line["severity"], line["action"], line["action_label"]], [&"treasury_empty", 2, [&"study", &"economy"], "Open the study"])
	_g.version += 1
	assert_eq(Reminders.unfinished(_g, &"GEN")[0]["kind"], &"treasury_empty", "severity 2 and first")
	assert_true(_g.dev_money(&"GEN", 119))
	assert_eq(Reminders.treasury_empty(_g, &"GEN")["text"], "The treasury is empty: 1 ducat owed. Upkeep is still paid; no work can begin.", "P: -1 is empty")
	assert_true(_g.dev_money(&"GEN", 1))
	assert_eq(Reminders.treasury_empty(_g, &"GEN"), {}, "0 is not")
	assert_eq(Reminders.treasury_empty(_g, &"ZZZ"), {})


func test_goods_running_out_with_a_vineyard_coming() -> void:
	var g := EconomyFixture.game(&"GEN", true)  # the stores of 1480: 4 seasons of each need
	assert_true(bool(g.act("build", {"hex": SAVONA, "family": ImproveRules.VINEYARD, "tag": &"GEN"})["ok"]))
	Season.run(g)
	var lines := Reminders.goods_running_out(g, &"GEN")
	assert_eq(lines.size(), 2, "wine and salt; the olives of (7, 14) keep the oil")
	assert_eq(lines[0]["text"], "Wine runs out in 4 seasons; the first vintage is Autumn 1481.")
	assert_eq([lines[0]["action"], lines[0]["action_label"], lines[0]["severity"]], [[&"look_at", SAVONA], "Go to (7, 12)", 1])
	assert_eq(lines[1]["text"], "Salt runs out in 4 seasons; none of your land makes it.")
	assert_eq([lines[1]["action_label"], lines[1]["hex"]], ["Show Genoa", Countries.by_tag(g, &"GEN").capital])


func test_a_stock_that_covers_the_eight_seasons_gives_no_line() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	g.defs.reserve_seasons = 8  # the stores keep 8 seasons of a need, so none of the stock is sold
	assert_true(g.dev_goods(&"GEN", g.defs.good_id(&"wine"), 4))  # 4 + 4 = 8 loads at 1 a season
	assert_true(g.dev_goods(&"GEN", g.defs.good_id(&"salt"), 4))  # 8: exactly the window
	assert_eq(Reminders.goods_running_out(g, &"GEN"), [] as Array[Dictionary], "P: 8 seasons of salt is not running out")
	assert_true(g.dev_goods(&"GEN", g.defs.good_id(&"salt"), -1))
	g.version += 1
	var lines := Reminders.goods_running_out(g, &"GEN")
	assert_eq(lines.size(), 1)
	assert_eq(lines[0]["text"], "Salt runs out in 8 seasons; none of your land makes it.")


func _hungry(milli: int) -> Game:
	var g := EconomyFixture.game(&"GEN", true)
	g.defs.food_need_milli = milli
	g.version += 1
	return g


func test_food_in_two_seasons_is_serious_and_in_three_is_not() -> void:
	var two := Reminders.goods_running_out(_hungry(550), &"GEN")
	assert_eq([two[0]["text"], two[0]["severity"]], ["Food runs out in 2 seasons.", 2])
	var three := Reminders.goods_running_out(_hungry(500), &"GEN")
	assert_eq([three[0]["text"], three[0]["severity"]], ["Food runs out in 3 seasons.", 1])
	var one := Reminders.goods_running_out(_hungry(700), &"GEN")
	assert_eq([one[0]["text"], one[0]["severity"]], ["Food runs out next season.", 2])
	assert_eq(Reminders.unfinished(_hungry(550), &"GEN")[0]["kind"], &"goods_running_out", "serious first")


func test_treasury_falling() -> void:
	var g := EconomyFixture.game(&"", true)
	g.defs.country_tax_milli = 0
	g.defs.town_tax_milli = 0
	g.version += 1
	var net := int(EconomyPreview.expected(g, &"MLO")["net"])
	assert_lt(net, 0, "Milan earns nothing from its people here and still pays its upkeep")
	var line := Reminders.treasury_falling(g, &"MLO")
	assert_eq(line["text"], "The treasury will fall by %s this season." % Words.ducats(-net))
	assert_eq([line["kind"], line["severity"], line["action"], line["action_label"]], [&"treasury_falling", 1, [&"study", &"economy"], "Open the study"])
	assert_eq(Reminders.treasury_falling(g, &"GEN"), {}, "Genoa still earns more than it pays")
	assert_true(g.dev_money(&"MLO", -Countries.by_tag(g, &"MLO").treasury - 1))
	assert_eq(Reminders.treasury_falling(g, &"MLO"), {}, "an empty treasury has its own rule")


func test_the_rules_come_worst_first() -> void:
	var g := _hungry(550)
	assert_true(g.dev_money(&"GEN", -Countries.by_tag(g, &"GEN").treasury - 5))
	g.version += 1
	var kinds: Array[StringName] = []
	for line: Dictionary in Reminders.unfinished(g, &"GEN"):
		kinds.append(line["kind"] as StringName)
	assert_eq(kinds.slice(0, 2), [&"treasury_empty", &"goods_running_out"] as Array[StringName], "severity 2 in the order of RULES")
	assert_eq(kinds[kinds.size() - 1], &"free_slot", "severity 1 last, the slot after the others")
	assert_true(kinds.has(&"goods_running_out"))


# ----- M5: 4.14, `hunger` and `town_full` ---------------------------------------------------------------------------


const GENOA := Vector2i(8, 13)
const SAVONA_TOWN := Vector2i(6, 13)


func test_hunger_names_what_was_eaten_and_what_was_needed() -> void:
	var c := Countries.by_tag(_g, &"GEN")
	assert_eq(Reminders.hunger(_g, &"GEN"), {}, "fed at the start: no line")
	c.food_need = 9
	c.food_fed = 999
	assert_eq(Reminders.hunger(_g, &"GEN")["text"], "Your towns went hungry: 8 of 9 food. They lose people each season until they are fed.")
	var line := Reminders.hunger(_g, &"GEN")
	assert_eq([line["kind"], line["severity"], line["action"], line["action_label"]], [&"hunger", 2, [&"study", &"people"], "Open People"])
	c.food_fed = 1000
	assert_eq(Reminders.hunger(_g, &"GEN"), {}, "P: fed (1,000) is not hungry")
	assert_eq(Reminders.hunger(_g, &"ZZZ"), {})


func test_hunger_reads_the_closed_flows_of_the_last_season() -> void:
	var g := PeopleFixture.genoa(PeopleFixture.no_food(), true)
	for key: StringName in [&"grain", &"fish"]:
		assert_true(g.dev_goods(&"GEN", g.defs.good_id(key), -100000))
	PeopleFixture.season(g)
	var c := Countries.by_tag(g, &"GEN")
	assert_lt(c.food_fed, 1000, "no food made: the towns are hungry")
	var line := Reminders.hunger(g, &"GEN")
	assert_false(line.is_empty())
	@warning_ignore("integer_division")
	var eaten := int(c.food_need) * c.food_fed / 1000
	assert_lte(int(str(line["text"]).split(" ")[4]), eaten + 1, "the eaten number is the stores' flow, about food_fed of the need")
	assert_string_contains(str(line["text"]), "of %d food." % c.food_need)
	assert_eq(Reminders.unfinished(g, &"GEN")[0]["kind"], &"hunger", "severity 2 and first of RULES after the empty treasury")


func _full(hex: Vector2i, people: int) -> void:
	assert_true(_g.dev_people(hex, people))
	_g.version += 1


func test_town_full_names_the_work_that_would_give_room() -> void:
	assert_eq(Reminders.town_full(_g, &"GEN"), {}, "nothing is full at the start")
	_full(GENOA, 45000)
	var line := Reminders.town_full(_g, &"GEN")
	assert_eq(line["text"], "Genoa (8, 13) is full at 45,000 people: a city would give it room.")
	assert_eq([line["kind"], line["severity"], line["action"], line["action_label"]], [&"town_full", 1, [&"look_at", GENOA], "Go to Genoa"])
	_full(SAVONA_TOWN, 20000)
	line = Reminders.town_full(_g, &"GEN")
	assert_eq(line["text"], "2 towns are full: Savona (6, 13) and Genoa (8, 13).")
	assert_eq(line["action"], [&"look_at", SAVONA_TOWN], "the first")
	assert_eq(line["action_label"], "Go to Savona")
	_full(GENOA, 44999)
	assert_eq(Reminders.town_full(_g, &"GEN")["text"], "Savona (6, 13) is full at 20,000 people: walls would give it room.")


func test_a_full_village_and_a_town_with_a_work_make_no_line() -> void:
	var i := _g.map.index_of(SAVONA_TOWN)
	_g.state.level[i] = 2  # a village: it grows into a town by itself, no work gives that
	_full(SAVONA_TOWN, 4000)
	assert_eq(Reminders.town_full(_g, &"GEN"), {}, "P: a full village makes no town_full line")
	_g.state.level[i] = 3
	_g.districts.clear()
	_full(SAVONA_TOWN, 20000)
	assert_eq(Reminders.town_full(_g, &"GEN")["text"], "Savona (6, 13) is full at 20,000 people: walls would give it room.")
	var work := Work.new()  # walls under way on Savona
	work.id = 90
	work.tag = &"GEN"
	work.hex = SAVONA_TOWN
	work.action = Works.UPGRADE
	work.family = ImproveRules.SETTLEMENT
	work.level_to = 4
	work.seasons = 4
	work.seasons_left = 4
	_g.state.works.append(work)
	_g.state.next_work_id = 91
	_g.version += 1
	assert_eq(Reminders.town_full(_g, &"GEN"), {}, "walls are under way: the work is the answer")
	assert_eq(Reminders.town_full(_g, &"MLO"), {}, "another country's town is not yours")


func test_the_order_of_the_seven_rules() -> void:
	assert_eq(Reminders.RULES, [&"treasury_empty", &"hunger", &"goods_running_out", &"winter_halt", &"treasury_falling",
		&"town_full", &"free_slot"] as Array[StringName])
	var c := Countries.by_tag(_g, &"GEN")
	c.food_need = 9
	c.food_fed = 800
	_full(GENOA, 45000)
	var kinds: Array[StringName] = []
	for line: Dictionary in Reminders.unfinished(_g, &"GEN"):
		kinds.append(line["kind"] as StringName)
	assert_eq(kinds, [&"hunger", &"town_full", &"free_slot"] as Array[StringName], "severity 2, then 1 in the order of RULES")


func test_three_full_towns_are_joined_with_semicolons() -> void:
	_full(GENOA, 45000)
	_full(SAVONA_TOWN, 20000)
	var third := Vector2i(-1, -1)
	for i: int in Territory.districts(_g, Countries.by_tag(_g, &"GEN").id):
		var hex := _g.map.hex_of(i)
		if third == Vector2i(-1, -1) and hex != GENOA and hex != SAVONA_TOWN and _g.state.main_use[i] != People.SETTLEMENTS:
			third = hex
	_g.state.main_use[_g.map.index_of(third)] = People.SETTLEMENTS
	_g.state.level[_g.map.index_of(third)] = 3
	_g.districts.clear()
	_full(third, 20000)
	var text := str(Reminders.town_full(_g, &"GEN")["text"])
	assert_true(text.begins_with("3 towns are full: "), text)
	assert_true(text.contains("; "), "P: names with commas are not joined with commas: " + text)
	assert_true(text.contains(" and "), text)


# --- the armies (M6 R9): the season in play the reminders read equals the season played --------------------------------

## Genoa with a town, two pikemen raised in it and two out of supply beside it: the rig of test_economy_preview.
func _armed_for_reminders() -> Game:
	var g := ArmyFixture.game()
	g.defs.supply_reach = 1
	var town := ArmyFixture.find_town(g)
	ArmyFixture.town(g, town)
	ArmyFixture.rich(g)
	assert_true(bool(g.act("raise", {"hex": town, "kind": 0, "count": 2, "tag": ArmyFixture.TAG})["ok"]))
	for i: int in Territory.districts(g, ArmyFixture.id_of(g, ArmyFixture.TAG)):
		if not Supply.in_supply(g, ArmyFixture.TAG, g.map.hex_of(i), false):
			ArmyFixture.army(g, ArmyFixture.TAG, g.map.hex_of(i), 0, 2)
			break
	return g


func test_the_season_in_play_with_armies_is_the_season_played() -> void:
	var g := _armed_for_reminders()
	var expected := EconomyPreview.expected(g, ArmyFixture.TAG)
	assert_false(expected.is_empty(), "the season in play has a preview")
	var c := Countries.by_tag(g, ArmyFixture.TAG)
	var upkeep := 0
	for line: Dictionary in expected["lines"] as Array:
		if line["why"] == &"upkeep_army":
			upkeep = int(line["amount"])
	assert_true(upkeep < 0, "the armies' upkeep is in the season in play")
	assert_true(bool(Season.run(g)["ok"]))
	var closed: Array[Dictionary] = []
	closed.assign(c.ledger_closed["lines"] as Array)
	assert_eq(Treasury.left_over(closed), int(expected["net"]), "the net the reminders read is the net played")
	assert_eq(c.stock, expected["stock"], "the stores the reminders read are the stores played")
