## The report's Armies part (docs/architecture/m6-build-spec.md 4.14 and 9; L12, SummaryArmies): the armies section of a season
## with a raise, the raise in "Your orders", the section absent in a season with no army, the foreign armies in sight in What
## befell (P: an army out of sight absent), and the Standing line's men under arms.
extends GutTest


func _rich_town_game() -> Game:
	var g := ArmyFixture.game()
	ArmyFixture.rich(g)
	var hex := ArmyFixture.find_town(g)
	ArmyFixture.town(g, hex)
	return g


func _section(summary: Dictionary, id: StringName) -> Dictionary:
	for s: Dictionary in summary.get("sections", []):
		if s["id"] == id:
			return s
	return {}


func _texts(section: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for line: Dictionary in section.get("lines", []):
		out.append(str(line["text"]))
	return out


func test_a_raise_shows_in_orders_and_the_armies_section() -> void:
	var g := _rich_town_game()
	var hex := ArmyFixture.find_town(g)
	assert_true(bool(g.act("raise", {"hex": hex, "kind": 0, "count": 2, "tag": ArmyFixture.TAG})["ok"]))
	Season.run(g)
	var turn := g.turn - 1
	var summary := SeasonSummary.of(g, ArmyFixture.TAG, turn)
	var orders := _texts(_section(summary, &"orders"))
	var raised := false
	for text: String in orders:
		raised = raised or text.begins_with("Raised 2 companies of")
	assert_true(raised, "the raise is in Your orders: %s" % str(orders))
	var armies := _section(summary, &"armies")
	assert_false(armies.is_empty(), "a season with an army has the Armies section")
	var total := armies["total"] as Dictionary
	assert_true(str(total["text"]).begins_with("Men under arms 0 → "), "the total runs from none: %s" % str(total["text"]))
	assert_eq(int(total["to"]), g.stats.value(ArmyFixture.TAG, turn, "army_men"), "the total is the Stats row")
	assert_eq(int(total["to"]), Armies.men_of_country(g, ArmyFixture.TAG), "and the men at the season's end")


func test_a_season_without_armies_has_no_armies_section() -> void:
	var g := ArmyFixture.game()
	Season.run(g)
	var summary := SeasonSummary.of(g, ArmyFixture.TAG, g.turn - 1)
	assert_true(_section(summary, &"armies").is_empty(), "no army, no section")


func test_standing_names_the_men_under_arms() -> void:
	var g := _rich_town_game()
	var hex := ArmyFixture.find_town(g)
	ArmyFixture.raise_now(g, {"hex": hex, "kind": 0, "count": 1, "tag": ArmyFixture.TAG})
	Season.run(g)
	var standing := _section(SeasonSummary.of(g, ArmyFixture.TAG, g.turn - 1), &"standing")
	if standing.is_empty():
		pending("no known country with a closed ledger in this fixture")
		return
	assert_true(str((standing["lines"] as Array)[0]["text"]).find("in men under arms") >= 0,
		"the Standing line counts the men under arms")


func test_foreign_army_in_sight_is_in_what_befell_and_one_out_of_sight_is_not() -> void:
	var g := ArmyFixture.game()
	var other := ArmyFixture.other_tag(g)
	var seen_hex := ArmyFixture.find_town(g)
	var unseen_hex := ArmyFixture.NO_HEX
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and not Knowledge.sees(g, ArmyFixture.TAG, hex):
			unseen_hex = hex
			break
	ArmyFixture.army(g, other, seen_hex, 0, 2)
	ArmyFixture.army(g, other, unseen_hex, 0, 2)
	Season.run(g)
	var befell := _section(SeasonSummary.of(g, ArmyFixture.TAG, g.turn - 1), &"befell")
	var in_sight := false
	for line: Dictionary in befell.get("lines", []):
		if line["hex"] == unseen_hex:
			fail_test("an army out of sight is in What befell")
		if str(line["text"]).find(" stands at ") >= 0 and line["hex"] == seen_hex:
			in_sight = true
	# The sight line names a country the viewer knows only (4.12); an unknown one reads "An army" (a witnessed hunger line
	# at the same hex is not a sight line).
	if Knowledge.knows(g, ArmyFixture.TAG, other):
		assert_true(in_sight, "a known country's army in sight is listed")
	else:
		assert_false(in_sight, "an unknown country's army is not listed: %s" % str(_texts(befell)))
