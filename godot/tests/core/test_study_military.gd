## StudyMilitary (docs/architecture/m6-build-spec.md 5.6, 6.9 and 9; L12): the head of the page, the table of the viewer's armies
## (men descending, ties by id), the foreign armies in sight (banded, no ids; P: an unseen army absent), the series equal to Stats
## after seasons, the empty page for another country, and the view leaves the game as it was.
extends GutTest


## A land hex that the viewer does not see, or NO_HEX.
func _unseen_hex(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and not Knowledge.sees(g, ArmyFixture.TAG, hex):
			return hex
	return ArmyFixture.NO_HEX


func _rows(page: Dictionary) -> Array:
	return page["rows"] as Array


func test_no_data_before_a_season_and_empty_for_another_country() -> void:
	var g := ArmyFixture.game()
	var page := StudyMilitary.of(g, ArmyFixture.TAG, 12)
	assert_false(bool(page["has_data"]), "no season has ended")
	assert_eq(_rows(page).size(), 0)
	var other := ArmyFixture.other_tag(g)
	var foreign := StudyMilitary.of(g, other, 12)
	assert_false(bool(foreign["has_data"]), "another country's tag gives the empty page")
	assert_eq(_rows(foreign).size(), 0)


func test_head_and_row_of_one_army() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	assert_ne(hex, ArmyFixture.NO_HEX)
	var a := ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 2)
	var page := StudyMilitary.of(g, ArmyFixture.TAG, 12)
	var head := page["head"] as Dictionary
	assert_eq(int(head["men"]), a.men(), "men under arms are the army's men")
	assert_eq(int(head["armies"]), 1)
	assert_eq(int(head["units"]), a.units.size())
	assert_eq(int(head["upkeep"]), Military.upkeep_country(g, ArmyFixture.TAG))
	assert_eq(_rows(page).size(), 1)
	var row := _rows(page)[0] as Dictionary
	assert_eq(int(row["id"]), a.id)
	assert_eq(int(row["men"]), a.men())
	assert_eq(str(row["name"]), a.name)
	assert_eq(str(row["order_text"]), "Holding", "an army with no order holds")


func test_rows_are_men_descending_then_id() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	var small := ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 1)
	var big := ArmyFixture.army(g, ArmyFixture.TAG, ImproveRules.neighbour(hex, 0), 0, 3)
	var rows := _rows(StudyMilitary.of(g, ArmyFixture.TAG, 12))
	assert_eq(rows.size(), 2)
	assert_eq(int((rows[0] as Dictionary)["id"]), big.id, "the larger army first")
	assert_eq(int((rows[1] as Dictionary)["id"]), small.id)


func test_series_equal_stats_after_seasons() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 2)
	Season.run(g)
	Season.run(g)
	var page := StudyMilitary.of(g, ArmyFixture.TAG, 12)
	assert_true(bool(page["has_data"]))
	var labels := page["labels"] as Array
	var series := page["series"] as Dictionary
	assert_eq((series["army_men"] as PackedInt32Array).size(), labels.size())
	assert_eq((series["income"] as PackedInt32Array).size(), labels.size())
	var men := series["army_men"] as PackedInt32Array
	assert_eq(men[men.size() - 1], g.stats.value(ArmyFixture.TAG, g.stats.last_turn, "army_men"),
		"the last point is the Stats row of the season that ended")


func test_foreign_army_out_of_sight_is_absent() -> void:
	var g := ArmyFixture.game()
	var other := ArmyFixture.other_tag(g)
	var hex := _unseen_hex(g)
	assert_ne(hex, ArmyFixture.NO_HEX, "the fixture map has land the viewer does not see")
	ArmyFixture.army(g, other, hex, 0, 2)
	Season.run(g)
	for s: Dictionary in StudyMilitary.of(g, ArmyFixture.TAG, 12)["seen"]:
		assert_ne(s["hex"], hex, "an army out of sight is not listed")


func test_foreign_army_in_sight_has_exact_men_and_carries_no_id() -> void:
	var g := ArmyFixture.game()
	var other := ArmyFixture.other_tag(g)
	var hex := ArmyFixture.find_town(g)
	var foreign := ArmyFixture.army(g, other, hex, 0, 2)
	var page := StudyMilitary.of(g, ArmyFixture.TAG, 12)
	var found := false
	for s: Dictionary in page["seen"]:
		if s["hex"] == hex:
			found = true
			assert_false(s.has("army"), "a foreign army has no id")
			assert_false(s.has("id"), "a foreign army has no id")
			assert_eq(s["men_text"], Words.men(foreign.men()), "its men are exact")
	# A country the viewer knows is listed; an unknown one is not (4.12).
	assert_eq(found, Knowledge.knows(g, ArmyFixture.TAG, other) and foreign.men() > 0)


func test_the_view_leaves_the_game_as_it_was() -> void:
	var g := ArmyFixture.game()
	ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 2)
	var before := g.digest()
	StudyMilitary.of(g, ArmyFixture.TAG, 12)
	assert_eq(g.digest(), before)
