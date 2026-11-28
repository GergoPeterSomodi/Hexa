## The army lines of "Your orders" (docs/architecture/m6-build-spec.md 4.14; L12, SummaryArmies.orders): the wording, word for word, of
## a raise, a disband with its refund, a march, a hold, a continue, a split and a join; the join's fallback when the army it came
## from is gone; and no army line in a season without an army order (P: each wording is compared exactly, so a changed word fails).
extends GutTest

const NAME := "Army of test"


func _rich_town_game() -> Game:
	var g := ArmyFixture.game()
	ArmyFixture.rich(g)
	ArmyFixture.town(g, ArmyFixture.find_town(g))
	return g


## Ends the season and returns the texts of Your orders of the season that ended.
func _orders_after_season(g: Game) -> Array[String]:
	var turn := g.turn
	Season.run(g)
	var out: Array[String] = []
	for s: Dictionary in SeasonSummary.of(g, ArmyFixture.TAG, turn).get("sections", []):
		if s["id"] == &"orders":
			for line: Dictionary in s["lines"]:
				out.append(str(line["text"]))
	return out


## A land hex of the player next to its town (a march goal the player may enter).
func _goal_of(g: Game) -> Vector2i:
	return ImproveRules.neighbour(ArmyFixture.find_town(g), 0)


func test_a_season_without_army_orders_has_no_army_line() -> void:
	var g := ArmyFixture.game()
	for text: String in _orders_after_season(g):
		for word: String in ["Raised", "Disbanded", "Ordered to", "Split", "Joined"]:
			assert_eq(text.find(word), -1, "no army order in a season without one: %s" % text)


func test_raise_wording() -> void:
	var g := _rich_town_game()
	var hex := ArmyFixture.find_town(g)
	assert_true(bool(g.act("raise", {"hex": hex, "kind": 0, "count": 2, "tag": ArmyFixture.TAG})["ok"]))
	var cost := int(Military.cost_of(g, 0, 2)["ducats"])
	var want := "Raised %s %s (▼ %s%s)." % [Words.units(2, g.defs.unit_def(0)), Words.at(g, hex), Words.MINUS, Words.number(cost)]
	var texts := _orders_after_season(g)
	assert_true(texts.has(want), "the raise reads %s in %s" % [want, str(texts)])


func test_disband_wording_with_the_refund_of_the_same_season() -> void:
	var g := _rich_town_game()
	var hex := ArmyFixture.find_town(g)
	assert_true(bool(ArmyFixture.raise_now(g, {"hex": hex, "kind": 0, "count": 2, "tag": ArmyFixture.TAG})["ok"]))
	var a := Armies.at(g, hex)[0]
	var paid := int(Military.cost_of(g, 0, 2)["ducats"])
	assert_true(bool(g.act("disband", {"army": a.id, "unit": -1, "tag": ArmyFixture.TAG})["ok"]))
	var want := "Disbanded %s of the %s (+%s back)." % [Words.units(2, g.defs.unit_def(0)), a.name, Words.ducats(paid)]
	var texts := _orders_after_season(g)
	assert_true(texts.has(want), "the disband reads %s in %s" % [want, str(texts)])


func test_march_wording() -> void:
	var g := ArmyFixture.game()
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	var goal := _goal_of(g)
	assert_true(bool(g.act("march", {"army": a.id, "goal": goal, "tag": ArmyFixture.TAG})["ok"]), "the march is accepted")
	var want := "Ordered to march: the %s %s." % [NAME, Words.at(g, goal, "to")]
	assert_true(_orders_after_season(g).has(want), want)


func test_hold_wording() -> void:
	var g := ArmyFixture.game()
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	assert_true(bool(g.act("halt", {"army": a.id, "tag": ArmyFixture.TAG})["ok"]))
	assert_true(_orders_after_season(g).has("Ordered to hold: the %s." % NAME))


func test_continue_wording() -> void:
	var g := ArmyFixture.game()
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	var goal := _goal_of(g)
	Armies.set_order(g, a, Army.ORDER_HOLD, goal, PackedInt32Array())  # a held march keeps its goal
	g.version += 1
	assert_true(bool(g.act("continue_march", {"army": a.id, "tag": ArmyFixture.TAG})["ok"]), "the held march continues")
	assert_true(_orders_after_season(g).has("Ordered to march on: the %s." % NAME))


func test_split_wording() -> void:
	var g := ArmyFixture.game()
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	var ids := Armies.add_units(g, a, 0, 1, g.turn - 1, a.hex, 0, {})
	assert_eq(a.units.size(), 2, "two companies to split")
	assert_true(bool(g.act("split_army", {"army": a.id, "units": [ids[0]], "tag": ArmyFixture.TAG})["ok"]))
	assert_true(_orders_after_season(g).has("Split the %s." % NAME))


func test_join_wording_and_its_fallback() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	var into := ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 1)
	var from := ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 1)
	assert_true(bool(g.act("merge_armies", {"army": from.id, "into": into.id, "tag": ArmyFixture.TAG})["ok"]))
	# The army joined from is gone when the report reads the log: its name is not kept, so the line says "an army".
	var texts := _orders_after_season(g)
	assert_true(texts.has("Joined an army to the %s." % NAME), str(texts))
	assert_false(texts.has("Joined the %s to the %s." % [NAME, NAME]), "no name is invented for the one that is gone")
