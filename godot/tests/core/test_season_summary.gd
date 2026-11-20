## SeasonSummary (docs/architecture/m3-build-spec.md 4.9, 5.6, 9): an M3 season's sections and lines, six then `more`,
## three `top`, the quiet state, an unwitnessed event absent, the toast and lede for Genoa and the sandbox, equal after a
## save and load.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const SAVONA := Vector2i(7, 12)
const WOODS := Vector2i(9, 11)
const GENOA := Vector2i(8, 13)

var _g: Game
var _next_id := 90


func before_each() -> void:
	var defs := EconomyFixture.defs()  # calm weather: a save does not carry the weather until Snapshot does (N5)
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": &"GEN"})["ok"]))
	_g.improvement.clear(SAVONA)


func _act(action: String, hex: Vector2i, family: int = 0) -> bool:
	var args := {"hex": hex, "tag": &"GEN"}
	if family > 0:
		args["family"] = family
	return bool(_g.act(action, args)["ok"])


## A work put straight into the state (the slots are not asked).
func _inject(action: StringName, family: int, level_to: int, hex: Vector2i, seasons: int, left: int,
		started: int = 0) -> Work:
	var w := Work.new()
	w.id = _next_id
	_next_id += 1
	w.tag = &"GEN"
	w.hex = hex
	w.action = action
	w.family = family
	w.level_to = level_to
	w.started_turn = started
	w.seasons = seasons
	w.seasons_left = left
	_g.state.works.append(w)
	_g.state.next_work_id = maxi(_g.state.next_work_id, w.id + 1)
	_g.version += 1
	return w


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


func _ids(summary: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Dictionary in summary["sections"]:
		out.append(s["id"] as StringName)
	return out


## Spring 1480 as Genoa: a vineyard begun and a timber begun then cancelled (orders), a finishing timber (finished), a
## town upgrade under way, Savoy finishes a wheat and takes three districts from Genoa.
func _spring() -> Dictionary:
	assert_true(_act("build", SAVONA, ImproveRules.VINEYARD))
	assert_true(_act("build", WOODS, ImproveRules.TIMBER))
	assert_true(_act("cancel_work", WOODS))
	var finishing := _inject(Works.BUILD, ImproveRules.TIMBER, 1, WOODS, 4, 1)
	_inject(Works.UPGRADE, ImproveRules.SETTLEMENT, 5, GENOA, 8, 8)
	var other := Knowledge.known(_g, &"GEN")[0]
	_g.emit({"kind": "work_finished", "tag": other, "hex": Vector2i(11, 8), "work": finishing.to_dict()})
	_g.emit({"kind": "owners_changed", "hexes": [Vector2i(11, 8), Vector2i(11, 9), Vector2i(12, 9)], "tag": other,
		"others": [&"GEN"]})
	_g.version += 1
	Season.run(_g)
	return SeasonSummary.of(_g, &"GEN", 1)


func test_an_m3_season_of_genoa() -> void:
	var s := _spring()
	assert_eq([s["turn"], s["title"], s["next"]], [1, "Spring 1480", "Summer 1480"])
	assert_eq(s["lede"], "The Chancellor's report to the Doge of Genoa. Summer 1480 begins.")
	assert_eq([s["seal_letter"], s["quiet"], s["serious"], s["swing_permille"]], ["G", false, false, 0])
	assert_eq(s["toast"], "Spring 1480 ended: 1 work finished, 2 works begun, 1 work cancelled. J: the report")
	assert_eq(_ids(s), [&"glance", &"works", &"orders", &"befell"] as Array[StringName], "fixed order, empty ones left out")
	var glance := _section(s, &"glance")
	assert_eq(glance["title"], "At a glance")
	var chips: Array[String] = []
	for chip: Dictionary in glance["lines"]:
		chips.append("%s: %s" % [chip["text"], chip["detail"]])
	assert_eq(chips, ["Works: 1 finished, 2 under way", "Work slots: 2 of 2 in use", "Land: 14 districts"] as Array[String])
	assert_eq(((glance["lines"] as Array)[0] as Dictionary)["tone"], "good", "good when one finished")
	var place := Words.place(_g, WOODS)
	var works := _texts(s, &"works")
	assert_eq(works, [
		"Under way: walled town to city, Genoa (8, 13): 2 of 8 seasons. Ready Spring 1482.",
		"Begun: vineyard, first stage, near Savona (7, 12). Ready Spring 1481. (−40 ducats)",
		"Begun: timber, first stage, %s. Ready Summer 1481. (−40 ducats)" % place,
		"Cancelled: timber, first stage, %s. (+40 ducats back)" % place,
		"Finished: timber, first stage, %s." % place,
	] as Array[String])
	assert_eq(_texts(s, &"orders"), [
		"Ordered to build: vineyard near Savona (7, 12) and woodland %s." % place,
		"Cancelled: woodland %s." % place,
		"Took the rule of the Republic of Genoa.",
	] as Array[String])
	var befell := _section(s, &"befell")
	assert_eq(befell["title"], "What befell Genoa")
	assert_eq(_texts(s, &"befell"), ["%s finished a woodland at (9, 11)." % LogLines.short_name(_g, Knowledge.known(_g, &"GEN")[0])]
		as Array[String], "the land Genoa lost is not an event that befell it: the Land chip says it")


func test_orders_are_grouped_by_kind_with_their_links() -> void:
	var s := _spring()
	var orders := _section(s, &"orders")["lines"] as Array
	assert_eq((orders[0] as Dictionary)["hex"], SAVONA, "the first hex of the kind")
	assert_eq((orders[2] as Dictionary)["hex"], Countries.by_tag(_g, &"GEN").capital)
	for line: Dictionary in orders:
		assert_eq(line["rank"], 0)


func test_works_lines_are_ranked_and_three_are_top() -> void:
	var s := _spring()
	var ranks: Array[int] = []
	var top: Array[bool] = []
	for line: Dictionary in _section(s, &"works")["lines"]:
		ranks.append(int(line["rank"]))
		top.append(bool(line["top"]))
	assert_eq(ranks, [8, 4, 4, 4, 4] as Array[int], "the work's seasons, largest first, ties in the order of the season")
	assert_eq(top, [true, true, true, false, false] as Array[bool])
	var tops := 0
	for sec: Dictionary in s["sections"]:
		for line: Dictionary in sec["lines"]:
			tops += 1 if line["top"] else 0
	assert_eq(tops, SeasonSummary.TOP)


func test_six_lines_show_and_more_counts_the_rest() -> void:
	_g.turn = 2
	for n: int in 8:
		_inject(Works.BUILD, ImproveRules.WHEAT, 1, Vector2i(n, 3), 4 + n, 4)
	var s := SeasonSummary.of(_g, &"GEN", 1)
	var works := _section(s, &"works")
	assert_eq((works["lines"] as Array).size(), SeasonSummary.SHOWN)
	assert_eq([works["count"], works["more"]], [8, 2])
	assert_eq(((works["lines"] as Array)[0] as Dictionary)["rank"], 11, "the longest first")
	assert_false(s["quiet"], "works begun earlier but under way are news")


func test_the_quiet_state() -> void:
	Season.run(_g)  # the choice of country is an order of Spring: Summer is the first quiet one
	_inject(Works.UPGRADE, ImproveRules.SETTLEMENT, 5, GENOA, 8, 8)
	_inject(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 8, 8)
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 2)
	assert_true(s["quiet"])
	assert_eq(s["lede"], "A quiet season.")
	assert_eq(s["toast"], "Summer 1480 ended: a quiet season. J: the report")
	assert_eq(_ids(s), [&"glance"] as Array[StringName], "no notice: the slots are full")
	var line := (_section(s, &"glance")["lines"] as Array)[0] as Dictionary
	assert_eq(line["text"], "2 works under way; nothing else of note.")
	assert_eq([line["action"], line["action_label"]], [[&"look_at", GENOA], "Show Genoa"])
	assert_eq(_texts(s, &"before"), [] as Array[String], "2 of 2 slots: nothing to remind")


func test_the_quiet_state_with_no_works_and_a_free_slot() -> void:
	Season.run(_g)
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 2)
	assert_eq(_texts(s, &"glance"), ["No works under way."] as Array[String])
	assert_eq(_section(s, &"before")["title"], "Before Autumn")
	var before := (_section(s, &"before")["lines"] as Array)[0] as Dictionary
	assert_eq(before["text"], "A work slot is free: 0 of 2 in use.")
	assert_eq([before["tone"], before["action_label"]], ["warn", "Show Genoa"])
	assert_false(s["serious"])


func test_winter_comes_is_a_serious_notice_before_autumn() -> void:
	assert_true(_act("build", WOODS, ImproveRules.TIMBER))
	Season.run(_g)
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 2)
	assert_eq(s["title"], "Summer 1480")
	assert_true(s["serious"])
	var before := _section(s, &"before")
	assert_eq(before["title"], "Before Autumn")
	assert_eq(_texts(s, &"before"), [
		"Winter comes: 1 work in the snow stops until spring: timber, first stage, %s." % Words.place(_g, WOODS),
		"A work slot is free: 1 of 2 in use.",
	] as Array[String])
	var first := (before["lines"] as Array)[0] as Dictionary
	assert_eq([first["tone"], first["action"], first["action_label"]], ["bad", [&"look_at", WOODS], "Go to (9, 11)"])


func test_a_work_halted_by_the_winter_is_warned() -> void:
	assert_true(_act("build", WOODS, ImproveRules.TIMBER))
	for n: int in 3:
		Season.run(_g)
	assert_true(_act("build", SAVONA, ImproveRules.VINEYARD))
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 4)
	assert_eq(s["title"], "Winter 1480")
	var line := _line_with(s, &"works", "Under way")
	assert_eq(line["text"], "Under way: timber, first stage, %s: stopped for the winter. Ready Summer 1481." % Words.place(_g, WOODS))
	assert_eq(line["tone"], "warn")


func test_land_gained_shows_in_the_chip_and_the_befell_section() -> void:
	Season.run(_g)
	var other := Knowledge.known(_g, &"GEN")[0]
	var hex := Vector2i(-1, -1)
	for i: int in _g.map.hex_count():
		if _g.map.land[i] != 0 and Territory.owner_tag(_g, _g.map.hex_of(i)) == other:
			hex = _g.map.hex_of(i)
			break
	assert_eq(_g.dev_transfer([hex] as Array[Vector2i], Countries.by_tag(_g, &"GEN").id), 1)
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 2)
	assert_false(s["quiet"], "the land changed")
	var land := _line_with(s, &"glance", "Land")
	assert_eq([land["text"], land["detail"], land["amount"]], ["Land", "15 districts", 1])
	assert_eq(_texts(s, &"befell"), [] as Array[String], "the player's own gain is not in What befell")
	assert_eq(s["toast"], "Summer 1480 ended: 1 district gained. J: the report")
	var chip := _line_with(s, &"glance", "Works")
	assert_eq(chip["detail"], "no works")


func test_land_lost_and_others_news_in_the_toast() -> void:
	Season.run(_g)
	var other := Knowledge.known(_g, &"GEN")[0]
	var hex := Vector2i(-1, -1)
	for i: int in _g.map.hex_count():
		if _g.map.land[i] != 0 and Territory.owner_tag(_g, _g.map.hex_of(i)) == &"GEN" and _g.map.hex_of(i) != GENOA:
			hex = _g.map.hex_of(i)
			break
	assert_eq(_g.dev_transfer([hex] as Array[Vector2i], Countries.by_tag(_g, other).id), 1)
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 2)
	assert_eq(s["toast"], "Summer 1480 ended: 1 district lost. J: the report")
	assert_eq(_texts(s, &"befell"), [] as Array[String])
	# Only others' news: a known country finishes a work, Genoa's land and works unchanged.
	var w := _inject(Works.BUILD, ImproveRules.WHEAT, 1, Vector2i(2, 3), 4, 4)
	_g.state.works.erase(w)
	_g.emit({"kind": "work_finished", "tag": other, "hex": Vector2i(2, 3), "work": w.to_dict()})
	_g.emit({"kind": "work_finished", "tag": other, "hex": Vector2i(2, 3), "work": w.to_dict()})
	Season.run(_g)
	assert_eq(SeasonSummary.of(_g, &"GEN", 3)["toast"], "Autumn 1480 ended: news from abroad. J: the report")


func test_orders_with_nothing_else_say_so() -> void:
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 1)
	assert_eq(_texts(s, &"orders"), ["Took the rule of the Republic of Genoa."] as Array[String])
	assert_eq(s["toast"], "Spring 1480 ended: orders given. J: the report")


func test_an_upgrade_order_has_a_comma_before_the_place() -> void:
	_g.dev_money(&"GEN", 1000)  # the city costs 1,000 ducats
	assert_true(_act("upgrade", GENOA), "Genoa may be raised")
	Season.run(_g)
	var work := _g.state.work_at(GENOA)
	assert_not_null(work)
	assert_eq(_texts(SeasonSummary.of(_g, &"GEN", 1), &"orders")[0], "Ordered to upgrade: %s." % WorksView.line(_g, work))
	assert_string_contains(_texts(SeasonSummary.of(_g, &"GEN", 1), &"orders")[0], "city, Genoa (8, 13)")


func test_the_summary_is_a_copy_of_the_cache() -> void:
	var s := _spring()
	var title := str(s["title"])
	(s["sections"] as Array).clear()
	s["title"] = "changed"
	var again := SeasonSummary.of(_g, &"GEN", 1)
	assert_eq(again["title"], title)
	assert_eq((again["sections"] as Array).size(), 4)


func test_an_unwitnessed_event_is_absent() -> void:
	Season.run(_g)
	var stranger := &""
	for c: Country in _g.countries:
		if c.tag != &"GEN" and not Knowledge.knows(_g, &"GEN", c.tag):
			stranger = c.tag
			break
	assert_ne(stranger, &"")
	var w := _inject(Works.BUILD, ImproveRules.WHEAT, 1, Vector2i(2, 3), 4, 4)
	_g.state.works.erase(w)
	_g.emit({"kind": "work_finished", "tag": stranger, "hex": Vector2i(2, 3), "work": w.to_dict()})
	_g.turn = 3
	_g.version += 1
	assert_eq(_section(SeasonSummary.of(_g, &"GEN", 2), &"befell"), {}, "P: Genoa does not hear of a stranger's work")
	assert_eq(_texts(SeasonSummary.of(_g, &"", 2), &"befell").size(), 1, "the viewer of everything does")


func test_the_sandbox() -> void:
	var sandbox := Game.new_game(_g.map, 1480, _g.defs)
	sandbox.improvement.clear(SAVONA)
	assert_true(bool(sandbox.act("build", {"hex": SAVONA, "family": ImproveRules.VINEYARD})["ok"]))
	Season.run(sandbox)
	var s := SeasonSummary.of(sandbox, &"", 1)
	assert_eq(s["lede"], "The sandbox of North Italy, seed 1480. Summer 1480 begins.")
	assert_eq(s["seal_letter"], "S")
	assert_eq(s["toast"], "Spring 1480 ended: 1 work begun. J: the report")
	assert_eq(_ids(s), [&"glance", &"works", &"orders"] as Array[StringName])
	assert_eq((_section(s, &"glance")["lines"] as Array).size(), 1, "no slots and no land chip without countries")
	assert_eq(_texts(s, &"orders"), ["Ordered to build: vineyard near Savona (7, 12)."] as Array[String])
	Season.run(sandbox)
	Season.run(sandbox)
	assert_eq(SeasonSummary.of(sandbox, &"", 3)["quiet"], true)
	assert_eq(_texts(SeasonSummary.of(sandbox, &"", 3), &"glance"), ["1 work under way; nothing else of note."] as Array[String])


func test_no_summary_before_a_season_ended() -> void:
	assert_eq(SeasonSummary.of(_g, &"GEN", 1), {}, "turn 1 has not ended")
	assert_eq(SeasonSummary.of(_g, &"GEN", 0), {})
	Season.run(_g)
	assert_eq(SeasonSummary.of(_g, &"GEN", 2), {}, "the season under way")
	assert_false(SeasonSummary.of(_g, &"GEN", 1).is_empty())
	assert_eq(SeasonSummary.SECTIONS.size(), 9)


func test_the_summary_is_cached_by_version() -> void:
	var s := _spring()
	assert_eq(SeasonSummary.of(_g, &"GEN", 1), s)
	var size := _g.view_cache.size()
	SeasonSummary.of(_g, &"GEN", 1)
	assert_eq(_g.view_cache.size(), size, "the same key is served from the cache")
	_g.version += 1
	assert_eq(SeasonSummary.of(_g, &"GEN", 1), s)


func test_the_summary_is_equal_after_a_save_and_load() -> void:
	var s := _spring()
	var dir := "user://test_season_summary_%d/" % Time.get_ticks_usec()
	assert_eq(SaveFile.write(_g, "1", {"saved_unix": 1}, {}, dir), "")
	var read := SaveFile.read("1", dir)
	assert_eq(read["problem"], "")
	var restored := Snapshot.restore(read["body"] as Dictionary, _g.map, _g.defs)
	assert_eq(restored["problem"], "")
	var back := restored["game"] as Game
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)
	assert_not_null(back)
	assert_eq(back.digest(), _g.digest())
	assert_eq(SeasonSummary.of(back, &"GEN", 1), s)
	assert_eq(LogLines.entries(back, &"GEN", &"all"), LogLines.entries(_g, &"GEN", &"all"))


func test_the_summary_is_quick() -> void:
	_spring()
	_g.version += 1
	var start := Time.get_ticks_usec()
	SeasonSummary.of(_g, &"GEN", 1)
	gut.p("SeasonSummary.of: %.2f ms (Y17 measures)" % ((Time.get_ticks_usec() - start) / 1000.0))
	assert_true(true)
