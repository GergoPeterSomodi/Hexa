## StudyHistory (docs/architecture/m4-5-build-spec.md 4.7, 4.9, 5.6, 9): the index holds exactly the entries the viewer is told
## of, the timeline's counts and marks (4.11's game: turn 1 begun, 4 finished, 5 short, 8 begun) and their priority, a
## season's numbers (kept as season, year or none), the chronicle's pages of whole seasons and each filter, the filters of a
## milestone, and the views leave the game as it was.
extends GutTest

const GEN := &"GEN"

var _g: Game


func _stranger(g: Game) -> StringName:
	for c: Country in g.countries:
		if c.tag != GEN and not Knowledge.knows(g, GEN, c.tag):
			return c.tag
	return &""


func _mark_of(marks: Array, turn: int) -> Dictionary:
	for m: Dictionary in marks:
		if int(m["turn"]) == turn:
			return m
	return {}


func test_the_index_holds_the_witnessed_entries_only() -> void:
	var g := InsightsFixture.genoa_1483()
	var stranger := _stranger(g)
	g.chronicle.add({"kind": "tax_set", "turn": 3, "tag": stranger, "level": 2})
	var idx := StudyHistory.index(g, GEN)
	var entries: PackedInt32Array = idx["entries"]
	var all := g.chronicle.entries
	assert_false(entries.has(all.size() - 1), "an entry of an unknown country is absent")
	var memo := {}
	var want := PackedInt32Array()
	for i: int in all.size():
		if not LogLines.filters_of(g, all[i], GEN, memo).is_empty():
			want.append(i)
	assert_eq(entries, want)
	assert_gt(entries.size(), 3)
	assert_eq((idx["turns"] as PackedInt32Array).size(), entries.size())
	assert_eq((idx["filters"] as PackedInt32Array).size(), entries.size())
	for n: int in entries.size():
		assert_eq((idx["turns"] as PackedInt32Array)[n], int(all[entries[n]]["turn"]))
	var everything := StudyHistory.index(g, &"")
	assert_true((everything["entries"] as PackedInt32Array).has(all.size() - 1), "the viewer with no name is told everything")


func test_the_index_bits_are_the_log_filters() -> void:
	var g := InsightsFixture.genoa_1483()
	var idx := StudyHistory.index(g, GEN)
	var bits: PackedInt32Array = idx["filters"]
	for n: int in bits.size():
		var filters := LogLines.filters_of(g, g.chronicle.entries[(idx["entries"] as PackedInt32Array)[n]], GEN)
		for i: int in LogLines.FILTERS.size():
			assert_eq((bits[n] & (1 << i)) != 0, filters.has(LogLines.FILTERS[i]["id"] as StringName))


func test_the_timeline_of_4_11s_game() -> void:
	var g := InsightsFixture.genoa_1483()
	var t := StudyHistory.timeline(g, GEN)
	assert_eq(t["first_turn"], 1)
	assert_eq(t["last_turn"], 12)
	assert_eq(t["start_year"], 1480)
	assert_eq((t["counts"] as PackedInt32Array).size(), 12)
	var marks: Array = t["marks"]
	assert_eq(_mark_of(marks, 1)["kind"], &"begun", "turn 1: the timber is begun")
	assert_eq(_mark_of(marks, 1)["icon"], &"spending")
	assert_eq(_mark_of(marks, 4)["kind"], &"finished", "turn 4: the timber is finished")
	assert_eq(_mark_of(marks, 4)["tone"], &"good")
	assert_eq(_mark_of(marks, 4)["icon"], &"district")
	assert_eq(_mark_of(marks, 5)["kind"], &"short", "turn 5: the salt runs short")
	assert_eq(_mark_of(marks, 5)["tone"], &"bad")
	assert_eq(_mark_of(marks, 5)["icon"], &"warning")
	assert_eq(_mark_of(marks, 8)["kind"], &"begun", "turn 8: the upgrade is begun")
	var turns: Array[int] = []
	for m: Dictionary in marks:
		turns.append(int(m["turn"]))
	var sorted := turns.duplicate()
	sorted.sort()
	assert_eq(turns, sorted, "marks in turn order, one a season")
	for turn: int in turns:
		assert_eq(turns.count(turn), 1)
	assert_true(String(_mark_of(marks, 1)["text"]).begins_with("Begun: "))


func test_a_season_with_two_events_shows_the_one_of_the_highest_priority() -> void:
	var g := InsightsFixture.genoa_1483()
	var hex := Vector2i(7, 12)
	var work := Work.new()
	work.id = 99
	work.tag = GEN
	work.hex = hex
	work.action = Works.BUILD
	work.family = ImproveRules.VINEYARD
	work.level_to = 1
	work.started_turn = 3
	work.seasons = 4
	work.seasons_left = 4
	# turn 3 held, say, only taxes; add a begun work and a land gain: land outranks begun and tax
	g.chronicle.add({"kind": "tax_set", "turn": 3, "tag": GEN, "level": 2})
	g.chronicle.add({"kind": "work_started", "turn": 3, "tag": GEN, "hex": hex, "work": work.to_dict()})
	g.chronicle.add({"kind": "owners_changed", "turn": 3, "tag": GEN, "others": [], "hexes": [hex]})
	var mark := _mark_of(StudyHistory.timeline(g, GEN)["marks"], 3)
	assert_eq(mark["kind"], &"land")
	assert_eq(mark["tone"], &"good")
	assert_eq(mark["icon"], &"settlement")
	assert_eq(mark["more"], 2)
	# lost land is bad
	g.chronicle.add({"kind": "owners_changed", "turn": 2, "tag": _stranger(g), "others": [GEN], "hexes": [hex]})
	assert_eq(_mark_of(StudyHistory.timeline(g, GEN)["marks"], 2)["tone"], &"bad")
	assert_eq(StudyHistory.MARK_KINDS, [&"land", &"declined", &"grew", &"finished", &"stopped", &"short", &"begun", &"tax", &"chosen"] as Array[StringName])


func test_other_countries_lines_raise_the_tick_but_are_no_mark() -> void:
	var g := InsightsFixture.genoa_1483()
	var known := Knowledge.known(g, GEN)[0]
	var before := StudyHistory.timeline(g, GEN)
	g.chronicle.add({"kind": "tax_set", "turn": 6, "tag": known, "level": 2})
	var after := StudyHistory.timeline(g, GEN)
	assert_eq((after["counts"] as PackedInt32Array)[5], (before["counts"] as PackedInt32Array)[5] + 1)
	assert_eq((after["marks"] as Array).size(), (before["marks"] as Array).size())
	g.chronicle.add({"kind": "tax_set", "turn": 6, "tag": _stranger(g), "level": 2})
	assert_eq((StudyHistory.timeline(g, GEN)["counts"] as PackedInt32Array)[5], (after["counts"] as PackedInt32Array)[5], "unknown: unseen")


func test_the_season_line_for_a_ring_row() -> void:
	var g := InsightsFixture.genoa_first_year()
	var s := StudyHistory.season(g, GEN, 5 - 1)
	assert_eq(s["kept"], &"season")
	assert_eq(s["title"], "Winter 1480")
	assert_eq(s["opening"], 934)
	assert_eq(s["closing"], 1068)
	assert_eq(s["change"], 134)
	assert_eq(s["land"], 14)
	assert_eq(s["income"], 134)
	assert_eq(s["people"], g.stats.value(GEN, 4, "people"))
	assert_gt(int(s["people"]), 0)
	assert_eq(s["text"], "Treasury 934 → 1,068 ▲ +134 · land 14 · income ▲ +134 · people %s" % Words.number(int(s["people"])))
	var first := StudyHistory.season(g, GEN, 1)
	assert_eq(first["opening"], 610, "the opening of the oldest row: the closing less its lines (D7)")
	assert_eq(first["closing"], 696)


func test_the_kept_numbers_of_a_forty_eight_season_run() -> void:
	var g := EconomyFixture.game(GEN)
	for _n: int in 48:
		Season.run(g)
	assert_eq(StudyHistory.season(g, GEN, 20)["kept"], &"season")
	assert_eq(StudyHistory.season(g, GEN, 9)["kept"], &"season", "the oldest row of the ring")
	var summer := StudyHistory.season(g, GEN, 6)
	assert_eq(summer["kept"], &"none")
	assert_eq(summer["text"], "Numbers are kept for the last 40 seasons and each winter.")
	var winter := StudyHistory.season(g, GEN, 8)
	assert_eq(winter["kept"], &"year")
	var row := g.stats.year_row(GEN, 1)
	assert_eq(winter["closing"], row[Stats.column("treasury")])
	assert_eq(winter["land"], row[Stats.column("land")])
	assert_eq(winter["text"], "At the year's end: treasury %s · land %d · people %s" % [
		Words.number(winter["closing"]), winter["land"], Words.number(winter["people"])])
	assert_eq(StudyHistory.season(g, GEN, 0)["kept"], &"none")
	assert_eq(StudyHistory.season(g, GEN, 99)["kept"], &"none")
	assert_eq(StudyHistory.season(g, &"", 20)["kept"], &"none")


func test_the_chronicle_pages_are_whole_seasons_newest_first() -> void:
	var g := InsightsFixture.forty_seasons()
	var idx := StudyHistory.index(g, GEN)
	var page := StudyHistory.chronicle(g, GEN, &"all", 0, 120)
	assert_eq(page["total"], (idx["entries"] as PackedInt32Array).size())
	var rows: Array = page["rows"]
	assert_gt(rows.size(), 0)
	assert_true(rows.size() <= 120 or _seasons_of(rows) == 1)
	var prev := 1000000
	var seasons := {}
	for row: Dictionary in rows:
		assert_true(int(row["turn"]) <= prev, "newest season first")
		prev = int(row["turn"])
		seasons[prev] = int(seasons.get(prev, 0)) + 1
		assert_true(String(row["text"]).length() > 0)
	# whole seasons: every witnessed line of each shown season is in the page
	for turn: int in seasons:
		var n := 0
		for i: int in (idx["entries"] as PackedInt32Array).size():
			if (idx["turns"] as PackedInt32Array)[i] == turn:
				n += 1
		assert_eq(seasons[turn], n, "season %d whole" % turn)
	# within a season, the chronicle's order
	var ids: Array[int] = []
	for row: Dictionary in rows:
		if int(row["turn"]) == prev + 0:
			ids.append(int(row["id"]))
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	assert_eq(ids, sorted_ids)
	assert_eq(page["from_turn"], prev)
	if int(page["older_turn"]) > 0:
		assert_lt(int(page["older_turn"]), prev)
		var older := StudyHistory.chronicle(g, GEN, &"all", int(page["older_turn"]), 120)
		assert_eq(older["rows"][0]["turn"], page["older_turn"], "Older starts at that season")
	else:
		assert_eq(rows.size(), int(page["total"]))


func _seasons_of(rows: Array) -> int:
	var seen := {}
	for row: Dictionary in rows:
		seen[row["turn"]] = true
	return seen.size()


func test_a_small_limit_gives_the_newest_season_whole_and_an_older_turn() -> void:
	var g := InsightsFixture.forty_seasons()
	var page := StudyHistory.chronicle(g, GEN, &"all", 0, 1)
	assert_eq(_seasons_of(page["rows"]), 1)
	assert_gt(int(page["older_turn"]), 0)
	assert_lt(int(page["older_turn"]), int(page["from_turn"]))


func test_each_filter() -> void:
	var g := InsightsFixture.genoa_1483()
	var all := StudyHistory.chronicle(g, GEN, &"all", 0)
	for filter: StringName in [&"works", &"mine", &"money"]:
		var page := StudyHistory.chronicle(g, GEN, filter, 0)
		assert_lte(int(page["total"]), int(all["total"]))
		for row: Dictionary in page["rows"]:
			var line := LogLines.line_of(g, g.chronicle.entries[int(row["id"])], GEN)
			assert_true((line["filters"] as Array).has(filter), "%s: %s" % [filter, row["text"]])
		var n := 0
		for entry: Dictionary in g.chronicle.entries:
			if (LogLines.filters_of(g, entry, GEN) as Array).has(filter):
				n += 1
		assert_eq(page["total"], n, String(filter))
	assert_eq(StudyHistory.chronicle(g, GEN, &"war", 0)["total"], 0, "war arrives with M7")
	assert_gt(int(StudyHistory.chronicle(g, GEN, &"money", 0)["total"]), 0, "works paid and a shortage")
	var mine := StudyHistory.chronicle(g, GEN, &"mine", 0)
	for row: Dictionary in mine["rows"]:
		assert_true(bool(row["mine"]))


func test_an_unknown_filter_is_read_as_all() -> void:
	var g := InsightsFixture.genoa_1483()
	var a := StudyHistory.chronicle(g, GEN, &"nonsense", 0)
	var b := StudyHistory.chronicle(g, GEN, &"all", 0)
	assert_eq(a["rows"], b["rows"])
	assert_eq(a["total"], b["total"])


func test_upto_a_season_shows_that_season_and_older() -> void:
	var g := InsightsFixture.genoa_1483()
	var page := StudyHistory.chronicle(g, GEN, &"all", 4)
	for row: Dictionary in page["rows"]:
		assert_lte(int(row["turn"]), 4)
	assert_eq(page["rows"][0]["turn"], 4)


func test_the_filters_of_a_milestone() -> void:
	assert_eq(StudyHistory.filters("4.5"), [&"all", &"money", &"works", &"mine"] as Array[StringName])
	assert_eq(StudyHistory.filters("7"), [&"all", &"war", &"money", &"works", &"mine"] as Array[StringName])
	assert_eq(StudyHistory.filters("3"), [&"all", &"works", &"mine"] as Array[StringName])
	assert_eq(StudyHistory.filters("4"), [&"all", &"money", &"works", &"mine"] as Array[StringName])


func test_the_views_change_nothing_and_are_copies() -> void:
	var g := InsightsFixture.genoa_1483()
	var digest := g.digest()
	var version := g.version
	var bytes := var_to_bytes(Snapshot.of(g))
	StudyHistory.index(g, GEN)
	StudyHistory.timeline(g, GEN)
	StudyHistory.season(g, GEN, 5)
	var page := StudyHistory.chronicle(g, GEN, &"all", 0)
	(page["rows"] as Array).clear()
	assert_gt((StudyHistory.chronicle(g, GEN, &"all", 0)["rows"] as Array).size(), 0, "the cache hands out copies")
	assert_eq(g.digest(), digest)
	assert_eq(g.version, version)
	assert_eq(var_to_bytes(Snapshot.of(g)), bytes)


func test_the_views_are_equal_after_a_save_and_load() -> void:
	var g := InsightsFixture.genoa_1483()
	var dir := "user://test_study_history_%d/" % Time.get_ticks_usec()
	assert_eq(SaveFile.write(g, "1", {"saved_unix": 1}, {}, dir), "")
	var read := SaveFile.read("1", dir)
	assert_eq(read["problem"], "")
	var back := Snapshot.restore(read["body"] as Dictionary, g.map, g.defs)["game"] as Game
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)
	assert_not_null(back)
	assert_eq(StudyHistory.index(back, GEN), StudyHistory.index(g, GEN))
	assert_eq(StudyHistory.timeline(back, GEN), StudyHistory.timeline(g, GEN))
	assert_eq(StudyHistory.chronicle(back, GEN, &"all", 0), StudyHistory.chronicle(g, GEN, &"all", 0))
	assert_eq(StudyHistory.season(back, GEN, 12), StudyHistory.season(g, GEN, 12))


# ----- M5: the two marks and the season line --------------------------------------------------------------------------


func _town_entry(kind: String, turn: int, tag: StringName, hex: Vector2i) -> Dictionary:
	var entry := {"kind": kind, "turn": turn, "tag": tag, "hex": hex, "level": 3 if kind == "town_grew" else 2,
		"from": 2 if kind == "town_grew" else 3, "people": 4000}
	if kind == "district_declined":
		entry["family"] = 1
		entry["why"] = "hunger"
	return entry


func test_the_grew_and_declined_marks_and_their_priority() -> void:
	var g := InsightsFixture.genoa_1483()
	var savona := Vector2i(6, 13)
	g.chronicle.add(_town_entry("town_grew", 3, GEN, savona))
	var mark := _mark_of(StudyHistory.timeline(g, GEN)["marks"], 3)
	assert_eq([mark["kind"], mark["tone"], mark["icon"], mark["hex"]], [&"grew", &"good", &"settlement", savona])
	assert_eq(mark["text"], "Savona (6, 13) grew into a town.")
	g.chronicle.add(_town_entry("district_declined", 6, GEN, savona))
	mark = _mark_of(StudyHistory.timeline(g, GEN)["marks"], 6)
	assert_eq([mark["kind"], mark["tone"], mark["icon"]], [&"declined", &"bad", &"settlement"])
	assert_eq(mark["text"], "Savona (6, 13) fell to a village: hunger.")
	# the priority: land, declined, grew, finished, ... (turn 4 has a finished timber from the fixture)
	g.chronicle.add(_town_entry("town_grew", 4, GEN, savona))
	assert_eq(_mark_of(StudyHistory.timeline(g, GEN)["marks"], 4)["kind"], &"grew", "grew outranks finished")
	g.chronicle.add(_town_entry("district_declined", 4, GEN, savona))
	assert_eq(_mark_of(StudyHistory.timeline(g, GEN)["marks"], 4)["kind"], &"declined", "declined outranks grew")
	g.chronicle.add({"kind": "owners_changed", "turn": 4, "tag": GEN, "others": [], "hexes": [savona]})
	assert_eq(_mark_of(StudyHistory.timeline(g, GEN)["marks"], 4)["kind"], &"land", "land outranks declined")


func test_another_countrys_town_is_no_mark() -> void:
	var g := InsightsFixture.genoa_1483()
	var before := (StudyHistory.timeline(g, GEN)["marks"] as Array).size()
	g.chronicle.add(_town_entry("town_grew", 9, Knowledge.known(g, GEN)[0], Vector2i(6, 11)))
	assert_eq((StudyHistory.timeline(g, GEN)["marks"] as Array).size(), before, "P: a known other's town is a line, not a mark")


func test_the_season_line_names_the_people_of_a_growing_country() -> void:
	var g := EconomyFixture.game(GEN, true, true, EconomyFixture.SEED, false)
	Season.run(g)
	var s := StudyHistory.season(g, GEN, 1)
	assert_eq(s["people"], g.stats.value(GEN, 1, "people"))
	assert_true(String(s["text"]).ends_with(" · people " + Words.number(int(s["people"]))), String(s["text"]))
	assert_eq(StudyHistory.season(g, &"", 1)["people"], 0)
