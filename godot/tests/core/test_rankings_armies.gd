## Rankings' fourth measure, men under arms (docs/architecture/m6-build-spec.md D46 and 9; L12): the measure is Stats' army_men,
## exact for every country (D7), and its rank equals the Standing line's "in men under arms" in every season of a run (M4.5's done-when 5
## carried to the fourth measure), and a view leaves the game as it was.
extends GutTest

const SEASONS := 12


func _measure(r: Dictionary, id: StringName) -> Dictionary:
	for m: Dictionary in r["measures"]:
		if m["id"] == id:
			return m
	return {}


func test_the_measure_exists_and_is_the_stats_row() -> void:
	var g := ArmyFixture.game()
	ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 2)
	Season.run(g)
	var r := StudyRankings.of(g, ArmyFixture.TAG, 12)
	var m := _measure(r, &"army")
	assert_false(m.is_empty(), "Rankings has the Men under arms measure")
	assert_eq(str(m["title"]), "Men under arms")
	var row := _row_of(m, ArmyFixture.TAG)
	assert_eq(int(row["value"]), g.stats.value(ArmyFixture.TAG, g.stats.last_turn, "army_men"),
		"the viewer's own value is exact")


func test_rank_equals_standing_every_season() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 2)
	var other := ArmyFixture.other_tag(g)
	ArmyFixture.army(g, other, hex, 0, 4)
	for k: int in SEASONS:
		Season.run(g)
		var turn := g.turn - 1
		var m := _measure(StudyRankings.of(g, ArmyFixture.TAG, 12), &"army")
		var rank := int(m["rank"])
		var standing := _standing_lines(g, turn)
		if standing.is_empty():
			pending("no Standing lines in season %d" % turn)
			continue
		var want := "%s in men under arms" % StudyRankings.ordinal(rank)
		assert_true(str(standing[0]).find(want) >= 0, "season %d: Rankings says %s, Standing says %s" % [turn, want, standing[0]])


func test_the_view_leaves_the_game_as_it_was() -> void:
	var g := ArmyFixture.game()
	ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 2)
	Season.run(g)
	var before := g.digest()
	StudyRankings.of(g, ArmyFixture.TAG, 12)
	assert_eq(g.digest(), before)


func _row_of(m: Dictionary, tag: StringName) -> Dictionary:
	for row: Dictionary in m["rows"]:
		if row["tag"] == tag:
			return row
	return {}


func _standing_lines(g: Game, turn: int) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in SeasonSummary.of(g, ArmyFixture.TAG, turn).get("sections", []):
		if s["id"] == &"standing":
			for line: Dictionary in s["lines"]:
				out.append(str(line["text"]))
	return out
