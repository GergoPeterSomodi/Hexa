## SeasonSummary (docs/architecture/m3-build-spec.md 4.9, 5.6, 9; docs/architecture/m4-build-spec.md 4.15 b, 4.19, 9): a
## season's sections and lines, six then `more`, three `top`, the quiet state, an unwitnessed event absent, the toast and
## lede for Genoa and the sandbox, equal after a save and load. M4: 4.15 (b)'s sections on the fixture; the Treasury
## lines sum to the change and the Goods lines to each stock's change in every season of a 40-season run (real weather,
## every country, random works and taxes); standing through Knowledge; quiet; swing_permille; the toast.
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


## A game with money and stores that a season does not move by 2 %: the quiet state of M4's rule.
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


func _ids(summary: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Dictionary in summary["sections"]:
		out.append(s["id"] as StringName)
	return out


## Spring 1480 as Genoa: a vineyard begun and a timber begun then cancelled (orders), a finishing timber (finished), a
## town upgrade under way, Savoy finishes a wheat and takes three districts from Genoa.
## One season of Genoa's works; `heard` adds a finish on a hex beside Genoa that Genoa witnessed (4.11).
func _spring(heard: bool = false) -> Dictionary:
	assert_true(_act("build", SAVONA, ImproveRules.VINEYARD))
	assert_true(_act("build", WOODS, ImproveRules.TIMBER))
	assert_true(_act("cancel_work", WOODS))
	var finishing := _inject(Works.BUILD, ImproveRules.TIMBER, 1, WOODS, 4, 1)
	_inject(Works.UPGRADE, ImproveRules.SETTLEMENT, 5, GENOA, 8, 8)
	var other := Knowledge.known(_g, &"GEN")[0]
	_g.emit({"kind": "work_finished", "tag": other, "hex": Vector2i(11, 8), "work": finishing.to_dict()})
	_g.emit({"kind": "owners_changed", "hexes": [Vector2i(11, 8), Vector2i(11, 9), Vector2i(12, 9)], "tag": other,
		"others": [&"GEN"]})
	if heard:
		_g.emit({"kind": "work_finished", "tag": other, "hex": ImproveRules.neighbour(GENOA, 0), "work": finishing.to_dict(),
			"witnesses": [&"GEN"]})
	_g.version += 1
	Season.run(_g)
	return SeasonSummary.of(_g, &"GEN", 1)


func test_an_m3_season_of_genoa() -> void:
	var s := _spring()
	assert_eq([s["turn"], s["title"], s["next"]], [1, "Spring 1480", "Summer 1480"])
	assert_eq(s["lede"], "The Chancellor's report to the Doge of Genoa. Summer 1480 begins.")
	assert_eq([s["seal_letter"], s["quiet"], s["serious"], s["swing_permille"]], ["G", false, false, 77], "47 of 610")
	assert_eq(s["toast"], "Spring 1480 ended: %s. J: the report" % _change_text(), "the money, once the season has a ledger")
	assert_eq(_ids(s), [&"glance", &"before", &"treasury", &"goods", &"works", &"orders", &"befell", &"standing"] as Array[StringName],
		"fixed order, empty ones left out")
	var glance := _section(s, &"glance")
	assert_eq(glance["title"], "At a glance")
	var chips: Array[String] = []
	for chip: Dictionary in glance["lines"]:
		chips.append("%s: %s" % [chip["text"], chip["detail"]])
	assert_eq(chips, ["Treasury: 657", "Works: 1 finished, 2 under way", "Wine: 3", "Olive oil: 3", "Salt: 3"] as Array[String],
		"the treasury, the works, then the goods that moved most (no Land chip when the land is as it was)")
	assert_eq(((glance["lines"] as Array)[1] as Dictionary)["tone"], "good", "good when one finished")
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
	# R31 (M6 4.11): a land event is heard by every country that has discovered its hex; north Italy starts discovered, so
	# the other's finish at (11, 8) is What befell. Genoa's own woodland at (9, 11) is its own news (not in What befell).
	var other := Knowledge.known(_g, &"GEN")[0]
	assert_eq(_texts(s, &"befell"), ["%s finished 1 work." % LogLines.short_name(_g, other)] as Array[String],
		"the other's finish is told")
	# The positive case: the same season with a finish on a neighbour's hex that Genoa witnessed is What befell.
	before_each()
	var heard := _spring(true)
	assert_false(_section(heard, &"befell").is_empty(), "a witnessed finish beside Genoa is What befell")
	assert_true(not _texts(heard, &"befell").is_empty() and not _texts(heard, &"befell")[0].is_empty())


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
	assert_eq(top, [false, false, false, false, false] as Array[bool], "the money lines of the Treasury outrank them")
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
	_g = _rich_game()
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
	var ledger := Countries.by_tag(_g, &"GEN").ledger_closed
	assert_eq(line["text"], "The treasury grew by %s; nothing else of note." % Words.ducats(int(ledger["closing"]) - int(ledger["opening"])))
	assert_eq([line["action"], line["action_label"]], [[&"look_at", GENOA], "Show Genoa"])
	assert_eq(_texts(s, &"before"), [] as Array[String], "2 of 2 slots: nothing to remind")


func test_a_busy_treasury_is_not_quiet() -> void:
	Season.run(_g)
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 2)
	assert_false(s["quiet"], "Genoa's stores move by a quarter a season, its treasury by a seventh")
	assert_true(s["swing_permille"] >= SeasonSummary.QUIET_PERMILLE)


func test_the_quiet_state_with_no_works_and_a_free_slot() -> void:
	_g = _rich_game()
	Season.run(_g)
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 2)
	assert_true(_texts(s, &"glance")[0].begins_with("The treasury grew by "))
	assert_eq(_section(s, &"before")["title"], "Before Autumn")
	var before := (_section(s, &"before")["lines"] as Array)[0] as Dictionary
	assert_eq(before["text"], "A work slot is free: 0 of 2 in use.")
	assert_eq([before["tone"], before["action_label"]], ["warn", "Show Genoa"])
	assert_false(s["serious"])


func test_winter_comes_is_a_serious_notice_before_autumn() -> void:
	_g = _rich_game()
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
	assert_eq(s["toast"], "Summer 1480 ended: %s. J: the report" % _change_text())
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
	assert_eq(s["toast"], "Summer 1480 ended: %s. J: the report" % _change_text())
	assert_eq(_texts(s, &"befell"), [] as Array[String])
	# Only others' news: a known country finishes a work, Genoa's land and works unchanged.
	var w := _inject(Works.BUILD, ImproveRules.WHEAT, 1, Vector2i(2, 3), 4, 4)
	_g.state.works.erase(w)
	_g.emit({"kind": "work_finished", "tag": other, "hex": Vector2i(2, 3), "work": w.to_dict()})
	_g.emit({"kind": "work_finished", "tag": other, "hex": Vector2i(2, 3), "work": w.to_dict()})
	Season.run(_g)
	assert_eq(SeasonSummary.of(_g, &"GEN", 3)["toast"], "Autumn 1480 ended: %s. J: the report" % _change_text())


func test_orders_with_nothing_else_say_so() -> void:
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 1)
	assert_eq(_texts(s, &"orders"), ["Took the rule of the Republic of Genoa."] as Array[String])
	assert_eq(s["toast"], "Spring 1480 ended: %s. J: the report" % _change_text())


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
	var count := (s["sections"] as Array).size()
	(s["sections"] as Array).clear()
	s["title"] = "changed"
	var again := SeasonSummary.of(_g, &"GEN", 1)
	assert_eq(again["title"], title)
	assert_eq((again["sections"] as Array).size(), count)


## The Standing reads another country's land and people as the viewer has discovered them (Knowledge.land_seen, as Rankings do),
## so the two agree on a thin start. Planted fault: the Stats' whole land would show, and at least one known country differs.
func test_standing_reads_other_lands_as_discovered_like_rankings() -> void:
	_fixture_report()
	FogFixture.thin(_g, &"GEN", 1)
	var standing := _section(SeasonSummary.of(_g, &"GEN", 1), &"standing")
	assert_false(standing.is_empty(), "a standing for Genoa")
	var checked := 0
	var differs := false
	for other: StringName in Knowledge.known(_g, &"GEN"):
		var seen := Knowledge.land_seen(_g, &"GEN", other)
		if int(seen["districts"]) != _g.stats.value(other, 1, "land"):
			differs = true
		var name := LogLines.short_name(_g, other)
		for line: Dictionary in standing["lines"]:
			var text := str(line["text"])
			if text.begins_with(name + ":"):
				checked += 1
				assert_true(text.begins_with("%s: %d districts," % [name, int(seen["districts"])]), "land as discovered: %s" % text)
				assert_true(text.contains("%s people." % Words.number(int(seen["people"]))), "people as discovered: %s" % text)
	assert_gt(checked, 0, "a known country is in the standing")
	assert_true(differs, "P: on the thin start a known country's land differs from the Stats' whole land")


func test_an_undiscovered_land_event_is_absent() -> void:
	Season.run(_g)
	FogFixture.thin(_g, &"GEN", 1)  # Genoa has discovered its land and a ring; the far hex is undiscovered
	var stranger := &""
	for c: Country in _g.countries:
		if c.tag != &"GEN" and not Knowledge.knows(_g, &"GEN", c.tag):
			stranger = c.tag
			break
	assert_ne(stranger, &"")
	var far := Vector2i(2, 3)
	assert_false(Knowledge.discovered(_g, &"GEN", far), "the far hex is undiscovered by Genoa")
	assert_true(Knowledge.discovered(_g, &"GEN", GENOA), "Genoa's capital is discovered")
	var w := _inject(Works.BUILD, ImproveRules.WHEAT, 1, far, 4, 4)
	_g.state.works.erase(w)
	_g.emit({"kind": "work_finished", "tag": stranger, "hex": far, "work": w.to_dict()})
	_g.turn = 3
	_g.version += 1
	assert_eq(_section(SeasonSummary.of(_g, &"GEN", 2), &"befell"), {}, "P: Genoa does not hear of a land event on an undiscovered hex")
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
	assert_eq(SeasonSummary.SECTIONS.size(), 11, "M6 adds the armies section; M7 the war section")


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


# ----- M4: 4.15 (b) and 4.19 ------------------------------------------------------------------------------------------


## 4.15 (b): the fixture (7, 12 wild), the vineyard begun in Spring 1480.
func _fixture_report() -> Dictionary:
	var g := EconomyFixture.game(&"GEN", true)
	assert_true(bool(g.act("build", {"hex": SAVONA, "family": ImproveRules.VINEYARD, "tag": &"GEN"})["ok"]))
	Season.run(g)
	_g = g
	return SeasonSummary.of(g, &"GEN", 1)


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


func test_4_15_b_the_glance_and_before() -> void:
	var s := _fixture_report()
	var chips: Array[String] = []
	for chip: Dictionary in _section(s, &"glance")["lines"]:
		chips.append("%s %s %s" % [chip["text"], chip["detail"], Words.signed(int(chip["amount"]))])
	assert_eq(chips, ["Treasury 657 +47", "Works 1 under way 0", "Wine 3 −1", "Olive oil 3 −1", "Salt 3 −1"] as Array[String])
	assert_eq(_section(s, &"before")["title"], "Before Summer")
	assert_eq(_texts(s, &"before"), [
		"Wine runs out in 4 seasons; the first vintage is Autumn 1481.",
		"Salt runs out in 4 seasons; none of your land makes it.",
		"A work slot is free: 1 of 2 in use.",
	] as Array[String])
	var before := _section(s, &"before")["lines"] as Array
	assert_eq([(before[0] as Dictionary)["action_label"], (before[0] as Dictionary)["action"]], ["Go to (7, 12)", [&"look_at", SAVONA]])
	assert_eq((before[1] as Dictionary)["action_label"], "Show Genoa")
	assert_eq((before[2] as Dictionary)["action_label"], "Show Genoa")


func test_4_15_b_the_treasury() -> void:
	var s := _fixture_report()
	var treasury := _section(s, &"treasury")
	var total := treasury["total"] as Dictionary
	assert_eq([total["text"], total["from"], total["to"], total["amount"]], ["610 → 657", 610, 657, 47])
	assert_eq(_rows(s, &"treasury"), [
		"Taxes on people ▲ +65", "Taxes on goods ▲ +7", "Port dues, Genoa ▲ +30", "District upkeep, 4 districts ▼ −11",
		"Walls of Genoa ▼ −4", "Work begun: vineyard, first stage, near Savona (7, 12) ▼ −40",
		"Left over each season ▲ +87", "With your spending ▲ +47",
	] as Array[String])
	var lines := treasury["lines"] as Array
	assert_eq([(lines[6] as Dictionary)["sub"], (lines[7] as Dictionary)["sub"], (lines[5] as Dictionary)["sub"]], [true, true, false])
	assert_eq(treasury["count"], 6, "the sub lines are not counted")
	assert_eq((lines[5] as Dictionary)["hex"], SAVONA)
	assert_eq(_sum_of_lines(treasury), 47, "65 + 7 + 30 - 11 - 4 - 40 = 657 - 610")


func test_4_15_b_the_goods_works_orders_and_standing() -> void:
	var s := _fixture_report()
	var goods: Array[String] = _rows(s, &"goods")
	goods.sort()
	assert_eq(goods, [
		"Fish 0 (caught 6, eaten 4, sold 2)", "Grain 16 (made 3, sold 3)", "Olive oil 3 ▼ −1 (used 1)", "Salt 3 ▼ −1 (used 1)",
		"Timber 40 (made 6, sold 6)", "Wine 3 ▼ −1 (drunk 1)",
	] as Array[String])
	assert_eq(_section(s, &"goods")["unchanged"], "Unchanged: horses, stone, iron, copper")  # M6: held at their reserves, 10 and 5
	assert_eq(_texts(s, &"works"), ["Begun: vineyard, first stage, near Savona (7, 12). Ready Spring 1481. (−40 ducats)"] as Array[String])
	assert_eq(_texts(s, &"orders")[0], "Ordered to build: vineyard near Savona (7, 12).")
	var standing := _texts(s, &"standing")
	var people := _g.stats.value(&"GEN", 1, "people")
	assert_true(standing[0].begins_with("Among the 13 countries you know, you are 8th in land (14 districts), 6th in income (+87 a season) and "), standing[0])
	assert_true(standing[0].ends_with(" in people (%s)." % Words.number(people)), standing[0])
	assert_eq(standing[1], "Savoy: 58 districts, +239, %s people." % Words.number(_g.stats.value(&"SAV", 1, "people")))
	assert_eq(standing[2], "Milan: 52 districts, +260, %s people." % Words.number(_g.stats.value(&"MLO", 1, "people")))
	assert_eq(_section(s, &"people"), {}, "M4's numbers on still people: no change, no People section, no chip")
	assert_eq([s["toast"], s["swing_permille"]], ["Spring 1480 ended: ▲ +47 ducats. J: the report", 77])


func test_standing_names_only_the_countries_known() -> void:
	_fixture_report()
	FogFixture.thin(_g, &"GEN", 1)  # Genoa keeps its neighbours and a ring; the rest of the map is undiscovered
	var known := Knowledge.known(_g, &"GEN")
	var standing := _section(SeasonSummary.of(_g, &"GEN", 1), &"standing")
	assert_true(known.size() < 12, "a thin Genoa knows fewer than the twelve others")
	assert_lte(int(standing["count"]), known.size() + 1, "the Standing counts Genoa and the known countries, no more")
	for c: Country in _g.countries:
		if c.tag != &"GEN" and not known.has(c.tag):
			for line: Dictionary in standing["lines"]:
				assert_false(str(line["text"]).begins_with(LogLines.short_name(_g, c.tag) + ":"), "P: %s is not known" % c.tag)
	assert_eq(_section(SeasonSummary.of(_g, &"", 1), &"standing"), {}, "no country, no standing")


func test_a_finished_work_says_what_it_brings() -> void:
	_g = EconomyFixture.game(&"GEN", true)
	_inject(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4, 1)
	Season.run(_g)
	var line := _line_with(SeasonSummary.of(_g, &"GEN", 1), &"works", "Finished")
	assert_eq(line["detail"], "Brings wine 12 a year; upkeep 1 a season.")


func test_a_tax_order_and_the_news_of_a_known_other() -> void:
	_g = EconomyFixture.game(&"GEN", true)
	assert_true(bool(_g.act("set_tax", {"level": 2, "tag": &"GEN"})["ok"]))
	var other := Knowledge.known(_g, &"GEN")[0]
	assert_true(bool(_g.act("set_tax", {"level": 0, "tag": other})["ok"]))
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 1)
	assert_true(_texts(s, &"orders").has("Set taxes to High."))
	assert_eq(_texts(s, &"befell"), ["%s set taxes to Low." % LogLines.short_name(_g, other)] as Array[String])
	assert_true(SeasonSummary.COVERED.has("goods_short"))


func test_only_the_last_closed_season_has_money_sections() -> void:
	_fixture_report()
	Season.run(_g)
	var old := SeasonSummary.of(_g, &"GEN", 1)
	assert_eq(_section(old, &"treasury"), {})
	assert_eq(_section(old, &"goods"), {})
	assert_eq(old["swing_permille"], 0)
	assert_false(_section(SeasonSummary.of(_g, &"GEN", 2), &"treasury").is_empty())


## The amounts of the lines of a section that are not `sub`.
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


func test_every_ducat_and_load_sums_in_forty_seasons_for_every_country() -> void:
	var g := EconomyFixture.game(&"GEN", false, false)  # the real weather odds
	var luck := Rng.new()
	luck.seed_with(1480)
	var seen := {"treasury": 0, "goods": 0, "work": 0, "dev": 0}
	for n: int in 40:
		for c: Country in g.countries:
			_random_works(g, c, luck)
		var ended := g.turn
		assert_true(bool(Season.run(g)["ok"]))
		for c: Country in g.countries:
			_check_sums(g, c, ended, seen)
	assert_gt(seen["treasury"], 100, "treasury sections were checked")
	assert_gt(seen["goods"], 100, "goods sections were checked")
	assert_gt(seen["work"], 0, "work lines were seen")
	assert_gt(seen["dev"], 0, "developer lines were seen")


func _check_sums(g: Game, c: Country, ended: int, seen: Dictionary) -> void:
	var label := "%s, season %d" % [c.tag, ended]
	var s := SeasonSummary.of(g, c.tag, ended)
	var ledger := c.ledger_closed
	var change := int(ledger["closing"]) - int(ledger["opening"])
	var treasury := _section(s, &"treasury")
	if treasury.is_empty() and not s["quiet"]:
		assert_eq(change, 0, "no Treasury section means no change, " + label)
	elif not treasury.is_empty():
		var total := treasury["total"] as Dictionary
		assert_eq([total["from"], total["to"], total["amount"]], [int(ledger["opening"]), int(ledger["closing"]), change], label)
		assert_eq(_sum_of_lines(treasury), change, "the lines add up to the change, " + label)
		assert_eq(treasury["more"], 0)
		seen["treasury"] += 1
		for line: Dictionary in treasury["lines"]:
			seen["work"] += 1 if str(line["text"]).begins_with("Work begun") else 0
			seen["dev"] += 1 if line["text"] == "Developer" else 0
	var goods := c.goods_closed
	var lines: Dictionary = {}
	for line: Dictionary in (_section(s, &"goods").get("lines", []) as Array):
		lines[str(line["text"])] = line
	if s["quiet"]:
		return
	for good: int in (goods["closing"] as PackedInt32Array).size():
		var stock := (goods["closing"] as PackedInt32Array)[good]
		var moved := stock - (goods["opening"] as PackedInt32Array)[good]
		var key := "%s %s" % [g.defs.good(good).name, Words.number(stock)]
		if lines.has(key):
			var line: Dictionary = lines[key]
			assert_eq([line["amount"], line["value"]], [moved, stock], "%s, %s" % [key, label])
			assert_eq(_detail_sum(str(line["detail"])), moved, "the flows add up to the change, %s, %s" % [key, label])
			seen["goods"] += 1
		else:
			assert_eq(moved, 0, "a stock that moved has its line, %s, %s" % [key, label])


func test_the_report_fixture_is_the_summary_of_4_15_b() -> void:
	var real := _fixture_report()
	var sample := ReportSample.genoa_spring()
	for id: StringName in [&"glance", &"before", &"treasury", &"works"]:
		var want := _rows(sample, id)
		if id == &"glance":
			want.remove_at(1)  # the People chip is of 4.11 (b)'s growing game: its own test
			want.append("Salt ▼ −1 3")  # and the sample's five chips are then four: M4's fifth is the one it lost
		assert_eq(want, _rows(real, id), "section %s" % id)
	assert_eq(_section(sample, &"treasury")["total"]["text"], _section(real, &"treasury")["total"]["text"])
	# M6 (spec 5.1): the real game also holds horses and copper at their reserves; the mockup sample has only stone and iron.
	assert_eq(_section(sample, &"goods")["unchanged"], "Unchanged: stone, iron")
	assert_eq(_section(real, &"goods")["unchanged"], "Unchanged: horses, stone, iron, copper")
	var a := _rows(sample, &"goods")
	var b := _rows(real, &"goods")
	a.sort()
	b.sort()
	assert_eq(a, b, "the goods, whatever their order")
	assert_eq([sample["toast"], sample["swing_permille"]], [real["toast"], real["swing_permille"]])


func test_an_older_report_does_not_carry_todays_reminders() -> void:
	_fixture_report()
	Season.run(_g)
	assert_true(_g.dev_money(&"GEN", -Countries.by_tag(_g, &"GEN").treasury - 500))
	_g.version += 1
	var old := SeasonSummary.of(_g, &"GEN", 1)
	assert_eq(_section(old, &"before"), {}, "P: the report of Spring has no list of today's tasks")
	assert_false(old["serious"])
	var latest := SeasonSummary.of(_g, &"GEN", 2)
	assert_true(_texts(latest, &"before")[0].begins_with("The treasury is empty: 500 ducats owed"))
	assert_true(latest["serious"])


func test_two_works_on_one_hex_in_a_season_have_a_neutral_label() -> void:
	_g = EconomyFixture.game(&"GEN", true)
	assert_true(_act("build", SAVONA, ImproveRules.VINEYARD))
	assert_true(_act("cancel_work", SAVONA))
	assert_true(_act("build", SAVONA, ImproveRules.VINEYARD))
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 1)
	var treasury := _section(s, &"treasury")
	assert_eq(_sum_of_lines(treasury), int(treasury["total"]["amount"]), "the sums hold")
	assert_ne(_line_with(s, &"treasury", "Works begun: ").get("text", ""), "")
	assert_string_contains(str(_line_with(s, &"treasury", "Works begun: ")["text"]), "(2)")


func test_a_raise_is_a_treasury_line_and_the_lines_sum_to_the_change() -> void:
	assert_true(bool(_g.act("raise", {"hex": GENOA, "kind": 0, "count": 2, "tag": &"GEN"})["ok"]))
	var turn := _g.turn
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", turn)
	var treasury := _section(s, &"treasury")
	var main_sum := 0
	var spending := 0
	var raised := ""
	for line: Dictionary in treasury["lines"]:
		if bool(line.get("sub", false)):
			continue
		main_sum += int(line["amount"])
		var text := str(line["text"])
		if text.begins_with("Raised") or text.begins_with("Work") or text.begins_with("Refund"):
			spending += int(line["amount"])
		if text.begins_with("Raised"):
			raised = text
	assert_eq(main_sum, int(treasury["total"]["amount"]), "the Treasury lines add up to the ledger's change")
	assert_eq(raised, "Raised: 2 companies at %s" % Words.place(_g, GENOA))
	var subs := {}
	for line: Dictionary in treasury["lines"]:
		if bool(line.get("sub", false)):
			subs[str(line["text"])] = int(line["amount"])
	var left := Treasury.left_over(_closed_lines())
	assert_eq(subs["Left over each season"], left)
	assert_eq(subs["With your spending"], left + spending, "the spending counts the raising")
	var goods := SeasonSummary._goods_rows(_g, Countries.by_tag(_g, &"GEN").goods_closed)
	var iron := -1
	for row: Dictionary in goods:
		if row["name"] == _g.defs.good(_g.defs.good_id(&"iron")).name:
			iron = int(row["stock"])
			assert_true((row["parts"] as Array).has("for raising 2"), "the stores' flow says what it was for")
	assert_gt(iron, -1)
	assert_eq(SeasonSummary._flow_word(_g.defs.good(0), Stores.FLOWS.find(&"army")), "eaten by the army")


## The closed ledger lines of Genoa as typed dictionaries.
func _closed_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Variant in Countries.by_tag(_g, &"GEN").ledger_closed["lines"] as Array:
		out.append(line as Dictionary)
	return out
