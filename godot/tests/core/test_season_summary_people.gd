## The People section of the season report (docs/architecture/m5-build-spec.md 4.11 (b), 4.15, 9; SummaryPeople): 4.11 (b)
## exactly on the fixture, the glance chip and Standing with people, the food line in its three forms, the level lines, the
## quiet rule, an older report's total, the sandbox, equal after a save and load, and the done-when 4 run: the people lines
## sum to the total every season of 40 for every country and the food line's numbers are the closed flows and food_need.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const SAVONA := Vector2i(7, 12)
const GENOA := Vector2i(8, 13)

var _g: Game


func _rich_game() -> Game:
	var defs := EconomyFixture.defs()
	defs.start_treasury_base = 1000000
	defs.reserve_seasons = 10000
	var g := Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(g.act("choose_country", {"tag": &"GEN"})["ok"]))
	g.improvement.clear(SAVONA)
	return g


## "▲ +48 ducats": the change of Genoa's last closed season, as the toast says it.
func _change_text() -> String:
	var ledger := Countries.by_tag(_g, &"GEN").ledger_closed
	var change := int(ledger["closing"]) - int(ledger["opening"])
	return "%s %s" % ["▲" if change > 0 else "▼", Words.signed_ducats(change)]


func _section(summary: Dictionary, id: StringName) -> Dictionary:
	for s: Dictionary in summary["sections"]:
		if s["id"] == id:
			return s
	return {}


func _texts(summary: Dictionary, id: StringName) -> Array[String]:
	var out: Array[String] = []
	for line: Dictionary in (_section(summary, id).get("lines", []) as Array):
		out.append(str(line["text"]))
	return out


func _line_with(summary: Dictionary, id: StringName, start: String) -> Dictionary:
	for line: Dictionary in (_section(summary, id).get("lines", []) as Array):
		if str(line["text"]).begins_with(start):
			return line
	return {}


func _rows(summary: Dictionary, id: StringName) -> Array[String]:
	var out: Array[String] = []
	for line: Dictionary in (_section(summary, id).get("lines", []) as Array):
		var amount := int(line["amount"])
		var text := str(line["text"])
		if amount != 0:
			text += " %s %s" % ["▲" if amount > 0 else "▼", Words.signed(amount)]
		if str(line["detail"]) != "":
			text += " " + str(line["detail"])
		out.append(text)
	return out


func _sum_of_lines(section: Dictionary) -> int:
	var sum := 0
	for line: Dictionary in section["lines"]:
		if not bool(line["sub"]):
			sum += int(line["amount"])
	return sum


## The signed loads of a goods line's "(made 3, sold 2)".
func _detail_sum(detail: String) -> int:
	var sum := 0
	for part: String in detail.trim_prefix("(").trim_suffix(")").split(", ", false):
		var cut := part.rfind(" ")
		var word := part.left(cut)
		var n := int(part.substr(cut + 1).replace(",", "").replace("+", "").replace("−", "-"))
		sum += n if ["made", "caught", "back from works", "by the developer"].has(word) else -n
	return sum


func _random_works(g: Game, c: Country, luck: Rng) -> void:
	var districts := Territory.districts(g, c.id)
	if districts.is_empty():
		return
	for t: int in 4:
		if luck.randi_range(0, 2) != 0:
			continue
		var hex := g.map.hex_of(districts[luck.randi_range(0, districts.size() - 1)])
		var args := {"hex": hex, "tag": c.tag}
		var action := "build"
		var kind := luck.randi_range(0, 5)
		if kind == 0:
			action = "upgrade"
		elif kind == 1:
			action = "clear"
		else:
			var options: Array[Dictionary] = []
			for o: Dictionary in g.improvement.build_options(hex):
				if bool(o["ok"]):
					options.append(o)
			if options.is_empty():
				continue
			args["family"] = int((options[luck.randi_range(0, options.size() - 1)])["family_id"])
		g.act(action, args)
	if luck.randi_range(0, 4) == 0:
		g.act("set_tax", {"level": luck.randi_range(0, 2), "tag": c.tag})
	if luck.randi_range(0, 3) == 0:
		g.dev_money(c.tag, luck.randi_range(-200, 500))
	if luck.randi_range(0, 7) == 0:
		g.dev_goods(c.tag, luck.randi_range(0, 15), luck.randi_range(-10, 40))
	var mine: Array[Work] = []
	for w: Work in g.state.works:
		if w.tag == c.tag:
			mine.append(w)
	if not mine.is_empty() and luck.randi_range(0, 3) == 0:
		g.act("cancel_work", {"hex": mine[luck.randi_range(0, mine.size() - 1)].hex, "tag": c.tag})


# ----- M5: 4.11 (b), 4.15: the People section -------------------------------------------------------------------------


## The first-year game with (7, 12) wild, people growing, one season played: the report of Spring 1480 (4.11 b).
func _growing_report() -> Dictionary:
	_g = PeopleFixture.genoa(null, true)
	Season.run(_g)
	return SeasonSummary.of(_g, &"GEN", 1)


func _total_text(s: Dictionary) -> String:
	return str((_section(s, &"people")["total"] as Dictionary)["text"])


func test_4_11_b_the_people_section_on_the_fixture() -> void:
	var s := _growing_report()
	var people := _section(s, &"people")
	assert_eq(people["title"], "People")
	var total := people["total"] as Dictionary
	assert_eq([total["text"], total["from"], total["to"], total["amount"]], ["82,700 → 83,205", 82700, 83205, 505])
	assert_eq(_rows(s, &"people"), [
		"Genoa (8, 13) 30,300 ▲ +300", "Savona (6, 13) 10,100 ▲ +100", "The countryside, 12 places, 42,805 ▲ +105",
		"Food: 9 made for 4 eaten. Fed, 5 to spare.",
	] as Array[String])
	var lines := people["lines"] as Array
	assert_eq([(lines[0] as Dictionary)["hex"], (lines[1] as Dictionary)["hex"]], [GENOA, Vector2i(6, 13)], "a place line is a link")
	assert_eq([(lines[2] as Dictionary)["sub"], (lines[3] as Dictionary)["sub"]], [false, true])
	assert_eq(people["count"], 3, "the sub lines are not counted")
	assert_eq(_sum_of_lines(people), 505, "300 + 100 + 105")


func test_4_11_b_the_glance_chip_and_standing() -> void:
	var s := _growing_report()
	var chips: Array[String] = []
	for chip: Dictionary in _section(s, &"glance")["lines"]:
		chips.append(str(chip["text"]))
	assert_eq(chips.slice(0, 2), ["Treasury", "People"] as Array[String], "People follows the Treasury")
	var chip := _line_with(s, &"glance", "People")
	assert_eq([chip["detail"], chip["amount"], chip["value"], chip["tone"]], ["83,205", 505, 83205, "good"])
	var standing := _texts(s, &"standing")
	assert_string_contains(standing[0], "7th in people (83,205).")
	assert_true(standing[0].begins_with("Among the 13 countries you know, you are 8th in land (14 districts), "))
	var known := Knowledge.known(_g, &"GEN")
	assert_eq(int(_section(s, &"standing")["count"]), known.size() + 1, "Genoa and every known country are counted")
	for other: StringName in known:
		var short := LogLines.short_name(_g, other)
		var want := ", %s people." % Words.number(_g.stats.value(other, 1, "people"))
		for text: String in standing:
			if text.begins_with(short + ":"):
				assert_true(text.ends_with(want), "%s: the exact people: %s" % [short, text])
	var sample := ReportSample.genoa_spring()
	assert_eq(_rows(sample, &"people"), _rows(s, &"people"), "the fixture's People section is the real one")
	assert_eq(_total_text(sample), _total_text(s))
	assert_eq(str(_line_with(sample, &"glance", "People")["detail"]), str(chip["detail"]))
	assert_string_contains(_texts(sample, &"standing")[0], "3rd in people (83,205).")


func test_the_food_line_in_its_three_forms() -> void:
	var fed := _growing_report()
	assert_eq(_texts(fed, &"people")[3], "Food: 9 made for 4 eaten. Fed, 5 to spare.")
	# made < eaten, fed from the stores: no food made, the stores hold some grain
	_g = PeopleFixture.genoa(PeopleFixture.no_food(), true)
	Season.run(_g)
	var food := _texts(SeasonSummary.of(_g, &"GEN", 1), &"people").back() as String
	assert_true(food.begins_with("Food: 0 made for "), food)
	assert_true(food.contains(" eaten. Fed from the stores: "), food)
	assert_true(food.ends_with(" left."), food)
	# hungry: no food and no stores
	_g = PeopleFixture.genoa(PeopleFixture.no_food(), true)
	var c := Countries.by_tag(_g, &"GEN")
	for key: StringName in [&"grain", &"fish"]:
		assert_true(_g.dev_goods(&"GEN", _g.defs.good_id(key), -100000))
	Season.run(_g)
	var hungry := SeasonSummary.of(_g, &"GEN", 1)
	var starved := -int((c.people_closed["flows"] as PackedInt32Array)[People.STARVED])
	assert_gt(starved, 0)
	assert_eq(_texts(hungry, &"people").back(), "Food: 0 made for %d needed. %d short: your towns lost %s to hunger." % [
		c.food_need, c.food_need, Words.people(starved)])
	var last := (_section(hungry, &"people")["lines"] as Array).back() as Dictionary
	assert_eq([last["sub"], last["tone"]], [true, "bad"])
	assert_lt(int((_section(hungry, &"people")["total"] as Dictionary)["amount"]), int((_section(fed, &"people")["total"] as Dictionary)["amount"]))


func test_a_town_that_grew_is_a_sub_line_and_never_quiet() -> void:
	_g = PeopleFixture.genoa(null, true)
	Season.run(_g)
	assert_false(bool(SummaryPeople.of(_g, &"GEN", 1)["levels"]))
	_g.chronicle.add({"kind": "town_grew", "turn": 1, "tag": &"GEN", "hex": Vector2i(6, 13), "level": 3, "from": 2, "people": 4000})
	_g.version += 1
	var again := SummaryPeople.of(_g, &"GEN", 1)
	assert_true(bool(again["levels"]), "a level line is in the season")
	assert_false(bool(again["quiet"]), "P: a level line is never quiet")
	var texts := _texts(SeasonSummary.of(_g, &"GEN", 1), &"people")
	assert_true(texts.has("Savona (6, 13) grew into a town."), str(texts))
	var line := _line_with(SeasonSummary.of(_g, &"GEN", 1), &"people", "Savona (6, 13) grew")
	assert_eq([line["sub"], line["tone"]], [true, "good"])
	_g.chronicle.add({"kind": "district_declined", "turn": 1, "tag": &"GEN", "hex": Vector2i(6, 13), "family": 1, "level": 2,
		"from": 3, "people": 1900, "why": "hunger"})
	_g.version += 1
	assert_true(_texts(SeasonSummary.of(_g, &"GEN", 1), &"people").has("Savona (6, 13) fell to a village: hunger."))


func test_the_quiet_rule_counts_the_people() -> void:
	_g = _rich_game()  # still people
	Season.run(_g)
	assert_true(bool(SummaryPeople.of(_g, &"GEN", 1)["quiet"]), "no change is quiet")
	assert_true(_g.dev_people(GENOA, 60000))  # 2 % of 82,700 is 1,654: this is 30,000 more
	Season.run(_g)
	var big := SummaryPeople.of(_g, &"GEN", 2)
	assert_gt(int(big["change"]) * 100, 2 * int(big["from"]))
	assert_false(bool(big["quiet"]), "P: over 2 % of the people is not quiet")
	assert_false(SeasonSummary.of(_g, &"GEN", 2)["quiet"])
	assert_false(_section(SeasonSummary.of(_g, &"GEN", 2), &"people").is_empty())


func test_an_older_report_has_only_the_peoples_total() -> void:
	_g = PeopleFixture.genoa(null, true)
	Season.run(_g)
	assert_true(_g.dev_people(GENOA, 60000))  # over 2 % of the people: not a quiet season
	Season.run(_g)
	Season.run(_g)
	var people := _section(SeasonSummary.of(_g, &"GEN", 2), &"people")
	assert_false(people.is_empty())
	assert_eq((people["lines"] as Array).size(), 0, "only the total")
	var total := people["total"] as Dictionary
	assert_eq([total["from"], total["to"]], [_g.stats.value(&"GEN", 1, "people"), _g.stats.value(&"GEN", 2, "people")])
	assert_eq(total["amount"], int(total["to"]) - int(total["from"]))


func test_the_sandbox_has_no_people_section() -> void:
	var g := Game.new_game(EconomyFixture.map(), 1, EconomyFixture.defs())
	Season.run(g)
	assert_eq(_section(SeasonSummary.of(g, &"", 1), &"people"), {})


func test_the_peoples_report_is_equal_after_a_save_and_load() -> void:
	var s := _growing_report()
	var dir := "user://test_summary_people_%d/" % Time.get_ticks_usec()
	assert_eq(SaveFile.write(_g, "1", {"saved_unix": 1}, {}, dir), "")
	var read := SaveFile.read("1", dir)
	var restored := Snapshot.restore(read["body"] as Dictionary, _g.map, _g.defs)
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)
	var back := restored["game"] as Game
	assert_not_null(back)
	assert_eq(SeasonSummary.of(back, &"GEN", 1), s)


# ----- M5: done-when 4 and 3's report part: forty seasons -------------------------------------------------------------


func _people_of(g: Game, c: Country) -> int:
	var sum := 0
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) == c.id:
			sum += g.state.people[i]
	return sum


func test_the_people_lines_sum_in_forty_seasons_for_every_country() -> void:
	var g := EconomyFixture.game(&"GEN", false, false, EconomyFixture.SEED, false)  # real weather, people grow
	var luck := Rng.new()
	luck.seed_with(1480)
	var before := {}
	for c: Country in g.countries:
		before[c.tag] = _people_of(g, c)
	var seen := {"sections": 0, "food": 0, "hungry": 0}
	for n: int in 40:
		for c: Country in g.countries:
			_random_works(g, c, luck)
			var districts := Territory.districts(g, c.id)
			if luck.randi_range(0, 5) == 0 and not districts.is_empty():
				var hex := g.map.hex_of(districts[luck.randi_range(0, districts.size() - 1)])
				g.dev_people(hex, luck.randi_range(0, maxi(People.room_at(g, StateView.of(g.state), hex), 50)))
		var ended := g.turn
		assert_true(bool(Season.run(g)["ok"]))
		for c: Country in g.countries:
			_check_people(g, c, ended, before, seen)
	assert_gt(seen["sections"], 100, "People sections were checked")
	assert_gt(seen["food"], 100, "food lines were checked")


func _check_people(g: Game, c: Country, ended: int, before: Dictionary, seen: Dictionary) -> void:
	var label := "%s, season %d" % [c.tag, ended]
	var from := int(before[c.tag])
	var to := _people_of(g, c)
	before[c.tag] = to
	assert_eq(g.stats.value(c.tag, ended, "people"), to, "Stats people is the people held, " + label)
	var report := SeasonSummary.of(g, c.tag, ended)
	var people := SummaryPeople.of(g, c.tag, ended)["section"] as Dictionary  # a quiet report leaves the section out
	if people.is_empty():
		assert_eq(from, to, "no People section means the people did not change, " + label)
		assert_eq(_section(report, &"people"), {})
		return
	if not report["quiet"]:
		var carried := _section(report, &"people")
		assert_eq(_rows(report, &"people"), _rows({"sections": [people]}, &"people"), "the report carries it, " + label)
		assert_eq(carried["total"], people["total"], label)
	var total := people["total"] as Dictionary
	assert_eq([total["from"], total["to"], total["amount"]], [from, to, to - from], label)
	assert_eq(people["more"], maxi(_places_changed(g, c) - 6, 0), "place lines are capped at SHOWN, the rest is one line")
	assert_eq(_sum_of_lines(people), to - from, "the lines add up to the change, " + label)
	seen["sections"] += 1
	for line: Dictionary in people["lines"]:
		if bool(line["sub"]) and str(line["text"]).begins_with("Food: "):
			_check_food_line(g, c, ended, str(line["text"]), label)
			seen["food"] += 1
			seen["hungry"] += 1 if c.food_fed < 1000 else 0


## The food line's numbers are the closed flows of grain and fish and food_need.
func _check_food_line(g: Game, c: Country, ended: int, text: String, label: String) -> void:
	var closed := c.goods_closed
	assert_eq(int(closed["turn"]), ended, label)
	var count := (closed["closing"] as PackedInt32Array).size()
	var flows := closed["flows"] as PackedInt32Array
	var made := 0
	var eaten := 0
	for key: StringName in [&"grain", &"fish"]:
		var good := g.defs.good_id(key)
		made += maxi(flows[Stores.FLOWS.find(&"made") * count + good], 0)
		eaten += absi(flows[Stores.FLOWS.find(&"used") * count + good])
	assert_lte(eaten, c.food_need, "food eaten never passes the need, " + label)
	if c.food_fed < 1000:
		assert_true(text.begins_with("Food: %d made for %d needed. " % [made, c.food_need]), "%s: %s" % [label, text])
	elif made >= eaten:
		assert_eq(text, "Food: %d made for %d eaten. Fed, %d to spare." % [made, eaten, made - eaten], label)
	else:
		assert_true(text.begins_with("Food: %d made for %d eaten. Fed from the stores: " % [made, eaten]), "%s: %s" % [label, text])


## The settlements of `c` whose people changed in the season that ended.
func _places_changed(g: Game, c: Country) -> int:
	var n := 0
	for i: int in Territory.districts(g, c.id):
		if int(g.state.main_use[i]) == People.SETTLEMENTS and g.state.people_end[i] != g.state.people_start[i]:
			n += 1
	return n


func test_more_than_six_place_lines_are_capped_and_still_add_up() -> void:
	_g = PeopleFixture.genoa(null, true)
	var c := Countries.by_tag(_g, &"GEN")
	Season.run(_g)
	# make eight settlements of Genoa change by hand in the closed season: the state holds one season's start and end
	var towns: Array[int] = []
	for i: int in Territory.districts(_g, c.id):
		if int(_g.state.main_use[i]) == People.SETTLEMENTS:
			towns.append(i)
	assert_gte(towns.size(), 2)
	var extra := 8 - towns.size()
	for i: int in Territory.districts(_g, c.id):
		if extra > 0 and int(_g.state.main_use[i]) != People.SETTLEMENTS:
			_g.state.main_use[i] = People.SETTLEMENTS
			towns.append(i)
			extra -= 1
	for k: int in towns.size():
		_g.state.people_start[towns[k]] = 1000
		_g.state.people_end[towns[k]] = 1000 + 10 * (k + 1)
	_g.version += 1
	var section := SummaryPeople.of(_g, &"GEN", 1)["section"] as Dictionary
	var lines := section["lines"] as Array
	assert_eq(section["more"], 2)
	var texts: Array[String] = []
	for line: Dictionary in lines:
		texts.append(str(line["text"]))
	assert_true(texts.has("2 more places"), str(texts))
	assert_eq(_sum_of_lines(section), int((section["total"] as Dictionary)["amount"]), "P: the hidden places' change is in the more line")
