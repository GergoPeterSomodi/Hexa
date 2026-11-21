## StudyEconomy.this_season (docs/architecture/m4-build-spec.md 5.6, 6.7): equal to the closed ledger and to
## EconomyPreview.expected to the unit, Genoa on seed 1480 (Spring 1480: 610 ducats, expected +86), has_season false
## before any season ended, spending, the tax levels, the chart, and a view that changes nothing.
extends GutTest

const GEN := &"GEN"


func _sum(entries: Array) -> int:
	var total := 0
	for entry: Dictionary in entries:
		total += int(entry["amount"])
	return total


func test_before_any_season() -> void:
	var g := EconomyFixture.game(GEN)
	var s := StudyEconomy.this_season(g, GEN)
	assert_false(bool(s["has_season"]))
	assert_eq(s["date"], "Spring 1480")
	assert_eq(s["closed_date"], "")
	assert_eq(int(s["change"]), 0)
	assert_eq((s["money_in"]["lines"] as Array).size(), 0)
	assert_eq((s["money_out"]["lines"] as Array).size(), 0)
	assert_eq(int(s["left_over"]), 0)
	assert_eq(int(s["expected"]["net"]), 86)
	assert_eq(int(s["expected"]["net"]), int(EconomyPreview.expected(g, GEN)["net"]))
	assert_eq(int(s["expected"]["realm"]), int(EconomyPreview.expected(g, GEN)["realm"]))
	assert_eq(Countries.by_tag(g, GEN).treasury, 610)
	assert_eq((s["chart"]["labels"] as Array).size(), 0)
	assert_gt((s["earns_most"] as Array).size(), 0)
	assert_eq(_sum(s["expected"]["lines"] as Array), 86)


func test_equals_the_closed_ledger() -> void:
	var g := EconomyFixture.game(GEN)
	var c := Countries.by_tag(g, GEN)
	assert_true(bool(Season.run(g)["ok"]))
	var s := StudyEconomy.this_season(g, GEN)
	assert_true(bool(s["has_season"]))
	assert_eq(s["date"], "Summer 1480")
	assert_eq(s["closed_date"], "Spring 1480")
	assert_eq(int(s["money_in"]["total"]), 65 + 7 + 30)
	assert_eq(int(s["money_out"]["total"]), -16)
	assert_eq(int(s["left_over"]), 86)
	assert_eq(int(s["change"]), c.treasury - 610)
	assert_eq(int(s["change"]), 86)
	assert_eq(int(s["left_over"]), Treasury.left_over(c.ledger_closed["lines"] as Array[Dictionary]))
	assert_eq(int(s["spending"]["total"]), 0)
	var shown := (s["money_in"]["lines"] as Array).size() + (s["money_out"]["lines"] as Array).size()
	assert_eq(shown, (c.ledger_closed["lines"] as Array).size())
	assert_eq(int(s["expected"]["net"]), 91)
	assert_eq(int(s["expected"]["net"]), int(EconomyPreview.expected(g, GEN)["net"]))
	assert_eq(_sum(s["expected"]["lines"] as Array), 91)


func test_spending_is_apart() -> void:
	var g := EconomyFixture.game(GEN, true)
	var verdict := g.act("build", {"hex": EconomyFixture.VINEYARD_HEX, "family": ImproveRules.VINEYARD, "tag": GEN})
	assert_true(bool(verdict["ok"]), str(verdict))
	assert_true(bool(Season.run(g)["ok"]))
	var s := StudyEconomy.this_season(g, GEN)
	assert_eq(int(s["spending"]["total"]), -40)
	var line: Dictionary = (s["spending"]["lines"] as Array)[0]
	assert_eq(line["hex"], EconomyFixture.VINEYARD_HEX)
	assert_true(str(line["label"]).contains("(7, 12)"), str(line["label"]))
	var c := Countries.by_tag(g, GEN)
	assert_eq(int(s["change"]), int(s["left_over"]) - 40)
	assert_eq(int(s["change"]), int(c.ledger_closed["closing"]) - int(c.ledger_closed["opening"]))


func test_tax_levels() -> void:
	var g := EconomyFixture.game(GEN)
	var s := StudyEconomy.this_season(g, GEN)
	assert_eq(int(s["tax"]["level"]), 1)
	var options: Array = s["tax"]["options"]
	assert_eq(options.size(), 3)
	assert_eq((options[1] as Dictionary)["note"], "Normal: as now; people grow 0 % a season.", "the still people of M4's numbers")
	assert_eq(int((options[1] as Dictionary)["change"]), 0)
	for l: int in [0, 2]:
		var want := int(EconomyPreview.with(g, GEN, {"tax": l}, 1)["seasons"][0]["net"]) - 86
		assert_eq(int((options[l] as Dictionary)["change"]), want)
	assert_gt(int((options[2] as Dictionary)["change"]), 0)
	assert_lt(int((options[0] as Dictionary)["change"]), 0)
	assert_true(str((options[2] as Dictionary)["note"]).begins_with("High: +"))


func test_chart_and_top_lists() -> void:
	var g := EconomyFixture.game(GEN)
	Season.run(g)
	Season.run(g)
	var s := StudyEconomy.this_season(g, GEN)
	assert_eq(s["chart"]["treasury"], PackedInt32Array([696, 787]))
	assert_eq(s["chart"]["change"], PackedInt32Array([86, 91]))
	assert_eq(s["chart"]["labels"], ["Spring 1480", "Summer 1480"] as Array[String])
	var earns: Array = s["earns_most"]
	assert_lte(earns.size(), 3)
	assert_eq((earns[0] as Dictionary)["hex"], Vector2i(7, 12))  # the vineyard's wine, 62
	assert_eq((earns[1] as Dictionary)["hex"], Vector2i(8, 13))  # Genoa, 60
	assert_eq(int((earns[1] as Dictionary)["amount"]), 60)
	for k: int in range(1, earns.size()):
		assert_gte(int((earns[k - 1] as Dictionary)["amount"]), int((earns[k] as Dictionary)["amount"]))
	var costs: Array = s["costs_most"]
	assert_gt(costs.size(), 0)
	assert_eq((costs[0] as Dictionary)["hex"], Vector2i(8, 13))


func test_unknown_country_and_no_writes() -> void:
	var g := EconomyFixture.game(GEN)
	var before := g.digest()
	var none := StudyEconomy.this_season(g, &"XXX")
	assert_false(bool(none["has_season"]))
	assert_eq((none["tax"]["options"] as Array).size(), 0)
	StudyEconomy.this_season(g, GEN)
	assert_eq(g.digest(), before)
	assert_eq(Countries.by_tag(g, GEN).treasury, 610)


func test_this_season_gives_a_copy_of_the_cache() -> void:
	var g := EconomyFixture.game(&"GEN")
	var a := StudyEconomy.this_season(g, &"GEN")
	var value := int((a["expected"] as Dictionary)["net"])
	(a["expected"] as Dictionary)["net"] = -999
	assert_eq(int((StudyEconomy.this_season(g, &"GEN")["expected"] as Dictionary)["net"]), value, "a caller's change never reaches the cache")


# --- Districts, Goods, History (docs/architecture/m4-5-build-spec.md 4.3 to 4.5, 4.10, D5 to D8) -------------------------


func _row_at(rows: Array, hex: Vector2i) -> Dictionary:
	for row: Dictionary in rows:
		if row["hex"] == hex:
			return row
	return {}


func test_districts_at_turn_1_equal_4_10() -> void:
	var g := EconomyFixture.game(GEN)
	var d := StudyEconomy.districts(g, GEN)
	assert_true(bool(d["has_land"]))
	assert_eq(d["date"], "Spring 1480")
	var rows: Array = d["rows"]
	assert_eq(rows.size(), 5)
	var hexes: Array = []
	for row: Dictionary in rows:
		hexes.append(row["hex"])
	assert_eq(hexes, [Vector2i(8, 13), Vector2i(7, 14), Vector2i(7, 12), Vector2i(6, 13), Vector2i(9, 13)], "A year, highest first")
	var years: Array = []
	var upkeeps: Array = []
	for row: Dictionary in rows:
		years.append(int(row["year"]))
		upkeeps.append(int(row["upkeep"]))
	assert_eq(years, [232, 105, 68, 38, 33])
	assert_eq(upkeeps, [-24, -16, -8, -8, -8])
	var want := [
		["Genoa (8, 13)", "walled town, port", "22 fish · dues 114", [60, 63, 60, 49]],
		["near Savona (7, 14)", "olives, third stage", "42 olive oil", [0, 0, 35, 70]],
		["near Savona (7, 12)", "vineyard, second stage", "24 wine", [2, 2, 62, 2]],
		["Savona (6, 13)", "town", "6 grain", [9, 11, 10, 8]],
		["near Genoa (9, 13)", "timber, second stage", "37 timber", [5, 5, 5, 18]],
	]
	for n: int in 5:
		var row: Dictionary = rows[n]
		assert_eq(row["place"], want[n][0])
		assert_eq(row["what"], want[n][1])
		assert_eq(row["gives"], want[n][2])
		assert_eq(Array(row["seasons"] as PackedInt32Array), want[n][3])
		assert_eq(int(row["season"]), int((want[n][3] as Array)[0]))
		assert_eq(int(row["id"]), g.map.index_of(row["hex"]))
		assert_true((row["work"] as Dictionary).is_empty())
	assert_eq(int(d["wild"]["count"]), 9)
	assert_eq(d["wild"]["gives"], "7 grain · 10 timber")
	assert_eq(int(d["wild"]["year"]), 57)
	assert_eq(int(d["total_year"]), 533)


func test_districts_hold_only_your_land() -> void:
	var g := EconomyFixture.game(GEN)
	var d := StudyEconomy.districts(g, GEN)
	var mine := Countries.by_tag(g, GEN).id
	for row: Dictionary in d["rows"]:
		assert_eq(int(g.state.owner[int(row["id"])]), mine, "a hex of another country is never a row")
	var milan := StudyEconomy.districts(g, &"MIL")
	assert_false(bool(milan["has_land"]), "Milan's land is not shown, however it is asked")
	assert_eq((milan["rows"] as Array).size(), 0)
	var none := StudyEconomy.districts(g, &"NOPE")
	assert_false(bool(none["has_land"]))
	assert_eq((none["rows"] as Array).size(), 0)


func test_districts_name_a_work_under_way() -> void:
	var g := InsightsFixture.genoa_1483()
	var row := _row_at(StudyEconomy.districts(g, GEN)["rows"], Vector2i(8, 13))
	assert_false((row["work"] as Dictionary).is_empty())
	assert_true(str(row["what"]).begins_with("walled town, port · under way: to city, ready "), str(row["what"]))
	assert_eq(str(row["what"]), "walled town, port · under way: to city, ready %s" % (row["work"] as Dictionary)["ready"])


func test_districts_give_a_copy_and_change_nothing() -> void:
	var g := EconomyFixture.game(GEN)
	var digest := g.digest()
	var version := g.version
	var a := StudyEconomy.districts(g, GEN)
	(a["rows"] as Array).clear()
	assert_eq((StudyEconomy.districts(g, GEN)["rows"] as Array).size(), 5)
	StudyEconomy.goods(g, GEN, 12)
	StudyEconomy.history(g, GEN, 12)
	StudyEconomy.lasts(g, GEN)
	assert_eq(g.digest(), digest)
	assert_eq(g.version, version)


func test_piece_words() -> void:
	var g := EconomyFixture.game(GEN)
	assert_eq(StudyEconomy.piece_words(g, Vector2i(8, 13)), "walled town, port")
	assert_eq(StudyEconomy.piece_words(g, Vector2i(6, 13)), "town")
	assert_eq(StudyEconomy.piece_words(g, Vector2i(7, 12)), "vineyard, second stage")
	assert_eq(StudyEconomy.piece_words(g, Vector2i(5, 5)), "", "no piece")
	assert_eq(StudyEconomy.piece_words(g, Vector2i(-4, -4)), "", "off the map")


func test_goods_at_turn_1() -> void:
	var g := EconomyFixture.game(GEN)
	var d := StudyEconomy.goods(g, GEN, 12)
	assert_false(bool(d["has_data"]))
	var rows: Array = d["rows"]
	var salt: Dictionary = rows[0]
	assert_eq(salt["name"], "Salt", "the first to run out")
	assert_eq(int(salt["stock"]), 4)
	assert_eq(int(salt["lasts"]), 5)
	assert_eq(salt["lasts_text"], "in 5 seasons")
	assert_eq(int(salt["need"]), 1)
	assert_false(bool(salt["makes_here"]))
	assert_eq(salt["note"], "Your towns need 1 salt a season; none of your land makes it.")
	assert_eq((salt["made_series"] as PackedInt32Array).size(), 0)


func test_goods_at_turn_5_equal_4_10() -> void:
	var g := InsightsFixture.genoa_first_year()
	var d := StudyEconomy.goods(g, GEN, 12)
	assert_true(bool(d["has_data"]))
	assert_eq((d["labels"] as Array).size(), 4)
	assert_eq((d["labels"] as Array)[0], "Spring 1480")
	var by_name := {}
	for row: Dictionary in d["rows"]:
		by_name[row["name"]] = row
	var want := {
		"Salt": [0, -1, 0, 4, "none left"], "Wine": [3, -1, 24, 4, "over 8 seasons"],
		"Olive oil": [4, 0, 42, 4, "over 8 seasons"], "Fish": [0, 0, 22, 16, "over 8 seasons"],
		"Grain": [16, 0, 13, 0, "over 8 seasons"], "Timber": [40, 0, 47, 0, "—"],
		"Stone": [40, 0, 0, 0, "—"], "Iron": [20, 0, 0, 0, "—"],
	}
	assert_eq(by_name.size(), want.size(), str(by_name.keys()))
	for name: String in want:
		var row: Dictionary = by_name[name]
		var w: Array = want[name]
		assert_eq([int(row["stock"]), int(row["change"]), int(row["made_year"]), int(row["used_year"]), row["lasts_text"]], w, name)
	assert_eq((d["rows"] as Array)[0]["name"], "Salt")
	assert_eq(int(by_name["Salt"]["lasts"]), StudyEconomy.LASTS_NONE_LEFT)
	assert_eq(int(by_name["Wine"]["lasts"]), StudyEconomy.LASTS_OVER)
	assert_eq(int(by_name["Timber"]["lasts"]), StudyEconomy.LASTS_NOT_NEEDED)
	assert_eq(by_name["Salt"]["note"], "Your towns need 1 salt a season; none of your land makes it.")
	assert_true(str(by_name["Fish"]["note"]).begins_with("Your towns eat 4 food a season, fish first, then grain; "), str(by_name["Fish"]["note"]))
	assert_true(bool(by_name["Wine"]["makes_here"]))
	assert_true(str(by_name["Wine"]["note"]).ends_with("most of it from near Savona (7, 12)."), str(by_name["Wine"]["note"]))
	assert_eq((by_name["Salt"]["stock_series"] as PackedInt32Array), PackedInt32Array([3, 2, 1, 0]))
	assert_eq((by_name["Wine"]["made_series"] as PackedInt32Array).size(), 4)
	# after Spring 1480 salt lasts in 4 seasons: the number M4's report names
	var early := EconomyFixture.game(GEN)
	Season.run(early)
	assert_eq(StudyEconomy.lasts(early, GEN)[4]["text"], "in 4 seasons")


func test_goods_span_is_cut_to_the_seasons_played() -> void:
	var g := InsightsFixture.genoa_first_year()
	assert_eq((StudyEconomy.goods(g, GEN, 40)["labels"] as Array).size(), 4)
	assert_eq((StudyEconomy.goods(g, GEN, 2)["labels"] as Array).size(), 2)


func _reminder_k(game: Game, need: StringName) -> int:
	var name := "Food" if need == &"food" else game.defs.goods[game.defs.good_id(need)].name
	for line: Dictionary in Reminders.goods_running_out(game, GEN):
		var text := str(line["text"])
		if text.begins_with(name + " runs out"):
			return 1 if text.begins_with(name + " runs out next season") else text.trim_prefix(name + " runs out in ").split(" ")[0].to_int()
	return 0


func test_lasts_equal_the_season_the_money_reminder_names_every_season() -> void:
	var failures: Array[String] = []
	var checked := [0]
	var each := func(game: Game, ended: int) -> void:
		var lasts := StudyEconomy.lasts(game, GEN)
		for need: StringName in EconomySeason.NEEDS:
			var k := _reminder_k(game, need)
			var good := Economy.GRAIN if need == &"food" else game.defs.good_id(need)
			var value := int((lasts[good] as Dictionary)["value"])
			var ok := (value in [0, 1]) if k == 1 else (value == k if k > 1 else (value == StudyEconomy.LASTS_OVER or value == StudyEconomy.LASTS_NOT_NEEDED))
			if not ok:
				failures.append("turn %d %s: reminder %d, lasts %d" % [ended, need, k, value])
			checked[0] += 1
	InsightsFixture.forty_seasons(each)
	assert_eq(failures, [] as Array[String])
	assert_eq(checked[0], 40 * 4)


func _reserve_game(seasons: int) -> Game:
	var d := EconomyFixture.defs()
	d.reserve_seasons = seasons  # the stores start at their reserve: `seasons` seasons of each need
	var g := Game.new_scenario(EconomyFixture.map(), d, d.scenarios[d.scenarios.size() - 1], EconomyFixture.SEED)
	g.act("choose_country", {"tag": GEN})
	return g


func test_a_stock_exactly_covering_eight_seasons_is_over_eight_not_in_eight() -> void:
	var g := _reserve_game(8)
	var salt := g.defs.good_id(&"salt")
	assert_eq(Countries.by_tag(g, GEN).stock[salt], 8)
	assert_eq(int(StudyEconomy.lasts(g, GEN)[salt]["value"]), StudyEconomy.LASTS_OVER)
	assert_eq(StudyEconomy.lasts(g, GEN)[salt]["text"], "over 8 seasons")
	var short := _reserve_game(7)
	assert_eq(Countries.by_tag(short, GEN).stock[salt], 7)
	assert_eq(StudyEconomy.lasts(short, GEN)[salt]["text"], "in 8 seasons")


func test_history_after_the_first_year_equals_4_10() -> void:
	var g := InsightsFixture.genoa_first_year()
	var h := StudyEconomy.history(g, GEN, 12)
	assert_true(bool(h["has_data"]))
	var seasons: Array = h["seasons"]
	assert_eq(seasons.size(), 4)
	var titles: Array = []
	var goods: Array = []
	var dues: Array = []
	var change: Array = []
	var closing: Array = []
	for s: Dictionary in seasons:
		titles.append(s["title"])
		goods.append(int(s["goods"]))
		dues.append(int(s["dues"]))
		change.append(int(s["change"]))
		closing.append(int(s["closing"]))
		assert_eq(int(s["people"]), 65)
		assert_eq(int(s["upkeep"]), 12)
		assert_eq(int(s["walls"]), 4)
		assert_eq(int(s["spending"]), 0)
		assert_eq(int(s["other"]), 0)
		assert_eq(int(s["trade"]) + int(s["army"]), 0)
	assert_eq(titles, ["Spring 1480", "Summer 1480", "Autumn 1480", "Winter 1480"])
	assert_eq(goods, [7, 9, 68, 64])
	assert_eq(dues, [30, 33, 30, 21])
	assert_eq(change, [86, 91, 147, 134])
	assert_eq(closing, [696, 787, 934, 1068])
	assert_eq(int(seasons[0]["opening"]), 610, "D7: the closing less the lines, turn 1")
	assert_eq(int(seasons[2]["opening"]), 787)
	var years: Array = h["years"]
	assert_eq(years.size(), 1)
	assert_eq(years[0], {"year": 1480, "closing": 1068, "land": 14})
	var two := StudyEconomy.history(g, GEN, 2)
	assert_eq((two["seasons"] as Array).size(), 2)
	assert_eq(int((two["seasons"] as Array)[0]["opening"]), 787, "the row before it is in the ring")


func test_history_before_a_season_has_ended() -> void:
	var h := StudyEconomy.history(EconomyFixture.game(GEN), GEN, 12)
	assert_false(bool(h["has_data"]))
	assert_eq((h["seasons"] as Array).size(), 0)
	assert_eq((h["years"] as Array).size(), 0)
	assert_false(bool(StudyEconomy.history(EconomyFixture.game(GEN), &"NOPE", 12)["has_data"]))


func test_history_names_the_works_and_adds_up_in_4_11() -> void:
	var g := InsightsFixture.genoa_1483()
	var h := StudyEconomy.history(g, GEN, 40)
	var seasons: Array = h["seasons"]
	assert_eq(seasons.size(), 12)
	var winter: Dictionary = seasons[7]
	assert_eq(winter["title"], "Winter 1481")
	assert_eq(int(winter["spending"]), 1000)
	var works: Array = winter["works"]
	assert_eq(works.size(), 1)
	assert_eq(works[0]["text"], "Begun: walled town to city, Genoa (8, 13)")
	assert_eq(int(works[0]["amount"]), -1000)
	assert_eq(works[0]["hex"], Vector2i(8, 13))
	assert_false(bool(winter["works_missing"]))
	var first: Dictionary = seasons[0]
	assert_eq(int(first["spending"]), 40)
	assert_true(str((first["works"] as Array)[0]["text"]).begins_with("Begun: timber, first stage"))
	assert_eq(int((first["works"] as Array)[0]["amount"]), -40)
	assert_eq((h["years"] as Array).size(), 3)
	assert_eq(int((h["years"] as Array)[2]["year"]), 1482)
	for s: Dictionary in seasons:
		_assert_adds_up(s)


func _assert_adds_up(s: Dictionary) -> void:
	var lines := int(s["people"]) + int(s["goods"]) + int(s["dues"]) + int(s["trade"]) - int(s["upkeep"]) - int(s["walls"]) \
		- int(s["army"]) - int(s["spending"]) + int(s["other"])
	assert_eq(lines, int(s["change"]), "%s: the lines add up to the change" % s["title"])
	assert_eq(int(s["closing"]) - int(s["opening"]), int(s["change"]))


func test_a_developer_gift_shows_as_other() -> void:
	var g := EconomyFixture.game(GEN)
	Season.run(g)
	g.dev_money(GEN, 500)
	Season.run(g)
	var s: Dictionary = (StudyEconomy.history(g, GEN, 12)["seasons"] as Array)[1]
	assert_eq(int(s["other"]), 500)
	assert_eq(int(s["change"]), 591)
	_assert_adds_up(s)


func test_every_season_of_forty_seasons_adds_up_and_its_works_add_to_the_spending() -> void:
	var seen := [0, 0]
	var each := func(game: Game, _ended: int) -> void:
		var h := StudyEconomy.history(game, GEN, 40)
		for s: Dictionary in h["seasons"]:
			_assert_adds_up(s)
			if not bool(s["works_missing"]):
				var listed := 0
				for w: Dictionary in s["works"]:
					listed += int(w["amount"])
				assert_eq(listed, -int(s["spending"]), "%s: the works add up to the spending" % s["title"])
		seen[0] += 1
		seen[1] += int((h["seasons"] as Array).size())
	var g := InsightsFixture.forty_seasons(each)
	assert_eq(seen[0], 40)
	assert_eq(g.stats.count, 40)
	var last: Array = StudyEconomy.history(g, GEN, 40)["seasons"]
	assert_eq(last.size(), 40)
	var c := Countries.by_tag(g, GEN)
	assert_eq(int(last[39]["closing"]), c.treasury)
	assert_eq(int(last[39]["change"]), int(c.ledger_closed["closing"]) - int(c.ledger_closed["opening"]))


func test_the_oldest_row_of_the_ring_has_its_opening_derived() -> void:
	var g := InsightsFixture.forty_seasons()
	for _n: int in 4:
		Season.run(g)  # turns 41 to 44: the ring now starts at turn 5
	var seasons: Array = StudyEconomy.history(g, GEN, 40)["seasons"]
	assert_eq(seasons.size(), 40)
	assert_eq(int(seasons[0]["turn"]), 5)
	assert_eq(int(seasons[0]["other"]), 0, "D7: the closing less the lines, so nothing is left over")
	assert_eq(int(seasons[0]["opening"]), int(seasons[0]["closing"]) - int(seasons[0]["change"]))
	assert_eq(int(seasons[1]["opening"]), int(seasons[0]["closing"]))
	assert_eq((StudyEconomy.history(g, GEN, 40)["years"] as Array).size(), 11, "every year row is kept")


func test_a_foreign_tag_gives_no_exact_figures() -> void:
	var g := InsightsFixture.genoa_first_year()
	var d := StudyEconomy.districts(g, &"MIL")
	assert_false(bool(d["has_land"]))
	assert_eq(int(d["total_year"]), 0)
	assert_eq(int(d["wild"]["count"]), 0)
	var goods := StudyEconomy.goods(g, &"SAV", 12)
	assert_false(bool(goods["has_data"]))
	assert_eq((goods["rows"] as Array).size(), 0)
	var h := StudyEconomy.history(g, &"MIL", 12)
	assert_false(bool(h["has_data"]))
	assert_eq((h["seasons"] as Array).size(), 0)
	assert_eq((h["years"] as Array).size(), 0)


func test_a_caller_cannot_change_what_worth_seasons_gives_next() -> void:
	var g := EconomyFixture.game(GEN)
	var a := EconomyPreview.worth_seasons(g, GEN, 4)
	var before := (a["worth"] as PackedInt32Array)[0]
	(a["worth"] as PackedInt32Array)[0] = before + 777
	(a["goods"] as PackedInt32Array)[0] = 99
	(a["hexes"] as PackedInt32Array).clear()
	var b := EconomyPreview.worth_seasons(g, GEN, 4)
	assert_eq((b["worth"] as PackedInt32Array)[0], before)
	assert_eq((b["hexes"] as PackedInt32Array).size(), 14)
	assert_eq(int(StudyEconomy.districts(g, GEN)["total_year"]), 533, "the views read the cache, not the caller's copy")


# ----- M5: the tax notes name the people's growth (6.7) ---------------------------------------------------------------


func test_the_tax_notes_name_the_peoples_growth_at_each_level() -> void:
	var g := EconomyFixture.game(GEN, false, true, EconomyFixture.SEED, false)  # growth_bp 125, 100, 50
	var s := StudyEconomy.this_season(g, GEN)
	var options: Array = s["tax"]["options"]
	assert_eq((options[1] as Dictionary)["note"], "Normal: as now; people grow 1 % a season.")
	assert_true(str((options[2] as Dictionary)["note"]).ends_with("; people grow 0.5 % a season, not 1 %."), str((options[2] as Dictionary)["note"]))
	assert_true(str((options[0] as Dictionary)["note"]).ends_with("; people grow 1.25 % a season, not 1 %."), str((options[0] as Dictionary)["note"]))
	assert_true(str((options[2] as Dictionary)["note"]).begins_with("High: +"), "the money part is M4's")
	# the player moves to High: the notes follow the level now
	assert_true(bool(g.act("set_tax", {"level": 2, "tag": GEN})["ok"]))
	options = StudyEconomy.this_season(g, GEN)["tax"]["options"]
	assert_eq((options[2] as Dictionary)["note"], "High: as now; people grow 0.5 % a season.")
	assert_true(str((options[0] as Dictionary)["note"]).ends_with("people grow 1.25 % a season, not 0.5 %."), str((options[0] as Dictionary)["note"]))
	g.defs.growth_bp = PackedInt32Array([100, 75, 5])  # P: the numbers come from the definitions
	g.version += 1
	options = StudyEconomy.this_season(g, GEN)["tax"]["options"]
	assert_string_contains(str((options[0] as Dictionary)["note"]), "people grow 1 % a season, not 0.05 %.")
