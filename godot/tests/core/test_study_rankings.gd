## StudyRankings (docs/architecture/m4-5-build-spec.md 4.6, 4.9, 4.10, 9): land and income from Stats, the same numbers as the
## report's Standing every season of a forty-season game, only the viewer and the countries it knows in the lists (the others'
## values banded), the unknown only counted, ranks with ties by id, the line and its marks, the viewer `&""`, and the views
## leave the game as it was.
extends GutTest

const GEN := &"GEN"

var _standing_checked := 0


func _of(g: Game, span: int = 12) -> Dictionary:
	return StudyRankings.of(g, GEN, span)


func _measure(r: Dictionary, id: StringName) -> Dictionary:
	for m: Dictionary in r["measures"]:
		if m["id"] == id:
			return m
	return {}


func _texts(m: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in m["rows"]:
		out.append("%s %s" % [row["short"], row["text"]])
	return out


func _set_ring(g: Game, tag: StringName, turn: int, series: String, value: int) -> void:
	var at := (g.stats.index_of(tag) * Stats.RING + posmod(turn, Stats.RING)) * Stats.SERIES.size() + Stats.column(series)
	g.stats.ring[at] = value
	g.version += 1


func test_before_a_season_has_ended() -> void:
	var g := EconomyFixture.game(GEN)
	var r := _of(g)
	assert_false(bool(r["has_data"]))
	assert_eq(r["head"], "No season has ended yet.")
	assert_eq((r["measures"] as Array).size(), 0)


func test_turn_two_lists_of_the_worked_example() -> void:
	var g := EconomyFixture.game(GEN)
	Season.run(g)
	var r := _of(g)
	assert_true(bool(r["has_data"]))
	assert_eq(r["turn"], 1)
	assert_eq(r["known"], 3, "Genoa and the 2 it knows")
	assert_eq(r["unknown"], 10, "13 countries, you, and the 2 you know")
	assert_eq(r["head"], "The 3 countries you know, you among them. 10 countries unknown. Their numbers are rounded.")
	var land := _measure(r, &"land")
	assert_eq(_texts(land), ["Savoy about 58", "Milan about 52", "Genoa 14"] as Array[String])
	assert_eq(land["rank"], 3)
	assert_eq(land["total"], 3)
	assert_eq(land["you_text"], "You are 3rd of 3.")
	assert_eq((land["rows"] as Array)[2]["name"], "Genoa (you)")
	var income := _measure(r, &"income")
	assert_eq(_texts(income), ["Milan about +260", "Savoy about +240", "Genoa +86"] as Array[String])
	assert_eq(income["rank"], 3)
	assert_eq(income["you_text"], "You are 3rd of 3.")


func test_values_come_from_stats_and_income_is_the_closed_ledger() -> void:
	var g := InsightsFixture.genoa_first_year()
	var c := Countries.by_tag(g, GEN)
	var lines: Array[Dictionary] = []
	for line: Variant in c.ledger_closed.get("lines", []) as Array:
		lines.append(line as Dictionary)
	var t := g.stats.last_turn
	assert_eq(StudyRankings.income_of(g.stats, GEN, t), Treasury.left_over(lines))
	assert_eq(StudyRankings.value_of(g.stats, &"land", GEN, t), g.stats.value(GEN, t, "land"))
	assert_eq(StudyRankings.value_of(g.stats, &"income", GEN, t), StudyRankings.income_of(g.stats, GEN, t))
	assert_eq(StudyRankings.value_of(g.stats, &"nonsense", GEN, t), 0)
	assert_eq(StudyRankings.income_of(g.stats, &"XXX", t), 0)
	assert_eq(StudyRankings.income_of(g.stats, GEN, t + 50), 0)


func test_rank_text_and_ordinals() -> void:
	assert_eq(StudyRankings.rank_text(3, 3), "3rd of 3")
	assert_eq(StudyRankings.rank_text(1, 4), "1st of 4")
	assert_eq(StudyRankings.rank_text(2, 4), "2nd of 4")
	assert_eq(StudyRankings.ordinal(11), "11th")
	assert_eq(StudyRankings.ordinal(12), "12th")
	assert_eq(StudyRankings.ordinal(13), "13th")
	assert_eq(StudyRankings.ordinal(21), "21st")
	assert_eq(StudyRankings.ordinal(112), "112th")


func test_only_the_viewer_and_the_known_are_listed() -> void:
	var g := InsightsFixture.genoa_first_year()
	var known := Knowledge.known(g, GEN)
	var r := _of(g)
	for m: Dictionary in r["measures"]:
		var tags: Array[StringName] = []
		for row: Dictionary in m["rows"]:
			tags.append(row["tag"])
		assert_eq(tags.size(), known.size() + 1)
		assert_true(tags.has(GEN))
		for tag: StringName in known:
			assert_true(tags.has(tag))
		for c: Country in g.countries:
			if c.tag != GEN and not known.has(c.tag):
				assert_false(tags.has(c.tag), "an unknown country is never in the rows: " + String(c.tag))
	assert_eq(r["unknown"], Knowledge.unknown_count(g, GEN))


func test_a_known_others_value_is_banded_and_yours_exact() -> void:
	var g := InsightsFixture.genoa_first_year()
	var r := _of(g)
	var t := int(r["turn"])
	for m: Dictionary in r["measures"]:
		for row: Dictionary in m["rows"]:
			var exact := StudyRankings.value_of(g.stats, m["id"], row["tag"], t)
			if bool(row["mine"]):
				assert_eq(row["value"], exact)
				assert_false(String(row["text"]).begins_with("about"))
			else:
				assert_eq(row["value"], Knowledge.band(exact), "banded: %s" % row["tag"])
				assert_true(String(row["text"]).begins_with("about "))


func test_ties_share_the_rank_and_sit_in_id_order() -> void:
	var g := InsightsFixture.genoa_first_year()
	var known := Knowledge.known(g, GEN)
	_set_ring(g, known[0], g.stats.last_turn, "land", g.stats.value(GEN, g.stats.last_turn, "land"))
	var m := _measure(_of(g), &"land")
	var rank_of := {}
	var pair: Array[int] = []
	for row: Dictionary in m["rows"]:
		rank_of[row["tag"]] = row["rank"]
		if row["tag"] == GEN or row["tag"] == known[0]:
			pair.append(int(row["id"]))
	assert_eq(rank_of[GEN], rank_of[known[0]], "a tie shares the better rank, as Standing's")
	var sorted_pair := pair.duplicate()
	sorted_pair.sort()
	assert_eq(pair, sorted_pair, "the rows of a tie are in country id order")


func test_the_viewer_with_no_name_sees_every_country_exact() -> void:
	var g := InsightsFixture.genoa_first_year()
	var r := StudyRankings.of(g, &"", 12)
	assert_true(bool(r["has_data"]))
	assert_eq(r["unknown"], 0)
	for m: Dictionary in r["measures"]:
		assert_eq((m["rows"] as Array).size(), g.countries.size())
		assert_eq(m["rank"], 0)
		assert_eq(m["you_text"], "")
		for row: Dictionary in m["rows"]:
			assert_false(bool(row["mine"]))
			assert_false(String(row["text"]).begins_with("about"))
			assert_eq(row["value"], StudyRankings.value_of(g.stats, m["id"], row["tag"], int(r["turn"])))
		assert_eq((m["line"]["marks"] as Array).size(), 0)


func test_a_viewer_that_is_no_country_has_no_data() -> void:
	var g := InsightsFixture.genoa_first_year()
	assert_false(bool(StudyRankings.of(g, &"XXX", 12)["has_data"]))


func test_bars_are_permille_of_the_largest_and_a_loss_has_none() -> void:
	var g := InsightsFixture.genoa_first_year()
	var known := Knowledge.known(g, GEN)
	var m := _measure(_of(g), &"land")
	var largest := 0
	for row: Dictionary in m["rows"]:
		largest = maxi(largest, int(row["value"]))
	for row: Dictionary in m["rows"]:
		assert_eq(row["bar"], floori(float(int(row["value"]) * 1000) / float(largest)))
	assert_eq((m["rows"] as Array)[0]["bar"], 1000)
	_set_ring(g, known[0], g.stats.last_turn, "upkeep_districts", 5000)
	var income := _measure(_of(g), &"income")
	for row: Dictionary in income["rows"]:
		if row["tag"] == known[0]:
			assert_lt(int(row["value"]), 0)
			assert_eq(row["bar"], 0, "a negative income draws no bar")


func test_the_line_spans() -> void:
	var g := InsightsFixture.forty_seasons()
	var r := _of(g, 12)
	for m: Dictionary in r["measures"]:
		var line: Dictionary = m["line"]
		assert_eq((line["you"] as PackedInt32Array).size(), 12)
		assert_eq((line["labels"] as Array).size(), 12)
		assert_eq((line["best"] as PackedInt32Array).size(), 12)
		assert_eq((line["you"] as PackedInt32Array)[11], StudyRankings.value_of(g.stats, m["id"], GEN, g.stats.last_turn))
		assert_eq(line["caption"], "Your %s, the last 12 seasons" % ("land" if m["id"] == &"land" else "income"))
		for mark: Dictionary in line["marks"]:
			assert_true(int(mark["index"]) >= 1 and int(mark["index"]) < 12)
			assert_true(String(mark["text"]).begins_with("rose to ") or String(mark["text"]).begins_with("fell to "))
			assert_eq(mark["tone"], "good" if String(mark["text"]).begins_with("rose") else "bad")
	assert_eq(((_of(g, 40)["measures"] as Array)[0]["line"]["you"] as PackedInt32Array).size(), 40)
	assert_eq(((_of(g, 99)["measures"] as Array)[0]["line"]["you"] as PackedInt32Array).size(), 40, "never past the ring")


func test_a_mark_where_the_rank_changed() -> void:
	var g := InsightsFixture.genoa_first_year()
	var known := Knowledge.known(g, GEN)
	var turn := g.stats.last_turn
	var mine_now := g.stats.value(GEN, turn, "land")
	# the neighbour led Genoa the season before and is behind it now
	_set_ring(g, known[0], turn - 1, "land", mine_now + 50)
	_set_ring(g, known[0], turn, "land", maxi(mine_now - 5, 0))
	var marks: Array = _measure(_of(g), &"land")["line"]["marks"]
	var found := false
	for mark: Dictionary in marks:
		if int(mark["turn"]) == turn and String(mark["text"]).begins_with("rose to "):
			found = true
			assert_eq(mark["tone"], "good")
	assert_true(found, "Genoa rose past it: %s" % [marks])


func test_the_view_is_cached_and_a_copy() -> void:
	var g := InsightsFixture.genoa_first_year()
	var a := _of(g)
	(a["measures"] as Array).clear()
	assert_eq((_of(g)["measures"] as Array).size(), 2)
	var before := g.view_cache.size()
	_of(g)
	assert_eq(g.view_cache.size(), before, "a second call makes no new entry")
	g.version += 1
	_of(g)
	assert_eq(g.view_cache.size(), before + 1, "a new version is a new key")


func test_the_view_changes_nothing() -> void:
	var g := InsightsFixture.genoa_first_year()
	var digest := g.digest()
	var version := g.version
	var bytes := var_to_bytes(Snapshot.of(g))
	_of(g)
	StudyRankings.of(g, &"", 40)
	assert_eq(g.digest(), digest)
	assert_eq(g.version, version)
	assert_eq(var_to_bytes(Snapshot.of(g)), bytes)


## Called after each season of the forty-season game: the Standing section of the season's report, line for line.
func _compare_standing(g: Game, ended: int) -> void:
	var section: Dictionary = {}
	for s: Dictionary in SeasonSummary.of(g, GEN, ended).get("sections", []):
		if s["id"] == &"standing":
			section = s
	if section.is_empty():
		return
	var r := _of(g)
	assert_eq(r["turn"], ended)
	var land := _measure(r, &"land")
	var income := _measure(r, &"income")
	var lines: Array = section["lines"]
	var mine_land := 0
	var mine_income := 0
	var income_text := {}
	for row: Dictionary in land["rows"]:
		if bool(row["mine"]):
			mine_land = int(row["value"])
	for row: Dictionary in income["rows"]:
		income_text[row["tag"]] = row["text"]
		if bool(row["mine"]):
			mine_income = int(row["value"])
	var head := "Among the %d countries you know, you are %s in land (%s) and %s in income (%s a season)." % [
		int(r["known"]), StudyRankings.ordinal(int(land["rank"])), Words.plural(mine_land, "district", "districts"),
		StudyRankings.ordinal(int(income["rank"])), Words.signed(mine_income)]
	assert_eq(lines[0]["text"], head, "turn %d" % ended)
	var want: Array[String] = [head]
	for row: Dictionary in land["rows"]:
		if not bool(row["mine"]):
			want.append("%s: %s districts, %s." % [row["short"], row["text"], income_text[row["tag"]]])
	var got: Array[String] = []
	for line: Dictionary in lines:
		got.append(String(line["text"]))
	assert_eq(got, want, "turn %d" % ended)
	_standing_checked += 1


func test_equal_to_the_reports_standing_every_season() -> void:
	_standing_checked = 0
	InsightsFixture.forty_seasons(_compare_standing)
	assert_gt(_standing_checked, 10, "the Standing section was present and compared in %d seasons" % _standing_checked)
