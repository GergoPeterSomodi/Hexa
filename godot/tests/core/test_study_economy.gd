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
	assert_eq((options[1] as Dictionary)["note"], "Normal: as now")
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
