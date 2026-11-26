## The wording after a halt (docs/architecture/m6-build-spec.md 4.14 and 6.5; L12 review item 7): a halted march keeps its goal and reads
## "Halted, can march on" in the Army panel, the hex card and the report ("Halted: the Army ..., which can march on."); a second halt
## holds the army and clears the goal ("Holding", "Ordered to hold"). A new army with no goal still reads "Holding". Also the report's
## lost line places the army with Words.at (P: no "at near").
extends GutTest

const NAME := "Army of test"


func _orders_after_season(g: Game) -> Array[String]:
	var turn := g.turn
	Season.run(g)
	var out: Array[String] = []
	for s: Dictionary in SeasonSummary.of(g, ArmyFixture.TAG, turn).get("sections", []):
		if s["id"] == &"orders":
			for line: Dictionary in s["lines"]:
				out.append(str(line["text"]))
	return out


func _panel_order(g: Game, a: Army) -> String:
	return str((ArmyView.panel(g, ArmyFixture.TAG, a.id)["order"] as Dictionary)["text"])


## A march of a new army of the player toward a neighbour of its town; returns the army.
## Moves in the month (moves-build-spec.md 8.2, MV4; R5, R20): a march walks in the act, so the army has spent its points first
## and the order is stored unwalked, as a march that waits for the next season.
func _marching(g: Game) -> Army:
	var town := ArmyFixture.find_town(g)
	var a := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 1)
	ArmyFixture.spent(g, a, 0)
	assert_true(bool(g.act("march", {"army": a.id, "goal": ImproveRules.neighbour(town, 0), "tag": ArmyFixture.TAG})["ok"]))
	return a


func test_a_halted_march_reads_halted_and_can_march_on() -> void:
	var g := ArmyFixture.game()
	var a := _marching(g)
	var goal := a.goal
	assert_true(bool(g.act("halt", {"army": a.id, "tag": ArmyFixture.TAG})["ok"]))
	assert_eq(a.order, Army.ORDER_NONE, "a halted march holds no order")
	assert_eq(a.goal, goal, "and keeps its goal")
	assert_eq(_panel_order(g, a), "Halted, can march on")
	assert_true(ArmyView.hex_text(g, ArmyFixture.TAG, a.hex).find("halted, can march on") >= 0,
		ArmyView.hex_text(g, ArmyFixture.TAG, a.hex))
	var texts := _orders_after_season(g)
	assert_true(texts.has("Halted: the %s, which can march on." % NAME), str(texts))


func test_a_second_halt_holds_and_clears_the_goal() -> void:
	var g := ArmyFixture.game()
	var a := _marching(g)
	assert_true(bool(g.act("halt", {"army": a.id, "tag": ArmyFixture.TAG})["ok"]))
	assert_true(bool(g.act("halt", {"army": a.id, "tag": ArmyFixture.TAG})["ok"]), "a halt on a halted army is accepted")
	assert_eq(a.order, Army.ORDER_HOLD)
	assert_eq(a.goal, Army.NO_HEX, "the second halt clears the goal")
	assert_eq(_panel_order(g, a), "Holding")
	assert_true(_orders_after_season(g).has("Ordered to hold: the %s." % NAME))


func test_a_new_army_with_no_goal_still_reads_holding() -> void:
	var g := ArmyFixture.game()
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	assert_eq(_panel_order(g, a), "Holding", "no order and no goal is a new army, not a halt")


func test_the_lost_line_places_the_army_with_at() -> void:
	var g := ArmyFixture.game()
	var town := ArmyFixture.find_town(g)
	var a := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 2)
	Season.run(g)
	Armies.set_supply(g, a, Supply.HUNGRY, 50)
	g.version += 1
	var section := SummaryArmies.of(g, ArmyFixture.TAG, g.turn - 1)["section"] as Dictionary
	var lost := ""
	for line: Dictionary in section.get("lines", []):
		if str(line["text"]).find("▼") >= 0:
			lost = str(line["text"])
	assert_true(lost != "", "a lost line is written")
	assert_true(lost.find("%s %s:" % [a.name, Words.at(g, town)]) >= 0, lost)
	assert_eq(lost.find("at near"), -1, lost)
