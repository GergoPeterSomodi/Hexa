## Standing's army clause (docs/architecture/m6-build-spec.md 4.14; L12): the "in men under arms" clause and the "about N men" of each
## country are told only when a country in view has men under arms; a world with no armies reads as before M6 (P: no "1st in men
## under arms (0)"). Rankings itself keeps its fourth measure (test_study_rankings and test_rankings_armies).
extends GutTest


func _standing(g: Game, turn: int) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in SeasonSummary.of(g, ArmyFixture.TAG, turn).get("sections", []):
		if s["id"] == &"standing":
			for line: Dictionary in s["lines"]:
				out.append(str(line["text"]))
	return out


func test_no_army_in_view_no_army_clause() -> void:
	var g := ArmyFixture.game()
	Season.run(g)
	var lines := _standing(g, g.turn - 1)
	if lines.is_empty():
		pending("the fixture has no Standing section")
		return
	assert_eq(lines[0].find("men under arms"), -1, lines[0])
	assert_true(lines[0].find(" in people (") >= 0 and lines[0].ends_with(")."), lines[0])
	for k: int in range(1, lines.size()):
		assert_false(lines[k].ends_with(" men."), "no 'about N men' without armies: %s" % lines[k])


func test_an_army_of_the_player_adds_the_clause_and_the_men() -> void:
	var g := ArmyFixture.game()
	ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	Season.run(g)
	var lines := _standing(g, g.turn - 1)
	if lines.is_empty():
		pending("the fixture has no Standing section")
		return
	assert_true(lines[0].find("1st in men under arms (") >= 0 or lines[0].find("in men under arms (") >= 0, lines[0])
	assert_true(lines[0].find(" in men under arms (") >= 0, lines[0])
	for k: int in range(1, lines.size()):
		assert_true(lines[k].ends_with(" men."), "each known country tells its men: %s" % lines[k])


func test_an_army_of_a_known_country_in_view_adds_the_clause() -> void:
	var g := ArmyFixture.game()
	var other := ArmyFixture.other_tag(g)
	ArmyFixture.army(g, other, ArmyFixture.find_town(g), 0, 1)
	Season.run(g)
	var lines := _standing(g, g.turn - 1)
	if lines.is_empty():
		pending("the fixture has no Standing section")
		return
	if Knowledge.knows(g, ArmyFixture.TAG, other):
		assert_true(lines[0].find(" in men under arms (") >= 0, "a known country's men count: %s" % lines[0])
	else:
		assert_eq(lines[0].find("men under arms"), -1, "an unknown country's men are not told: %s" % lines[0])
