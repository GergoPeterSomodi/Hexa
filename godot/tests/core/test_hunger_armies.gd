## The hunger reminder and the idle line of the armies (docs/architecture/m6-build-spec.md 4.15; L12 review items 4 to 6). An army out
## of supply is named only when it lost men in the last supply phase or when the end hex of this season's walk is out of supply
## (P: a walk that ends in supply, no losses, is no line; P: a walk that ends out of supply is named "will lose about"). An army in
## supply that lost men is named "lost N men to hunger" (no "will lose"). The hex of a line reads with "at" (Words.at), never "at near".
extends GutTest


## A land hex out of supply in spring with a neighbour the planner takes an army to, the neighbour's supply being `goal_in_supply`.
## Returns [army, goal], or [] when the fixture has no such pair. Armies tried and refused are removed again.
func _pair(g: Game, goal_in_supply: bool) -> Array:
	for i: int in g.map.hex_count():
		var from := g.map.hex_of(i)
		if not g.map.is_land(from) or Supply.in_supply(g, ArmyFixture.TAG, from, false):
			continue
		var a := ArmyFixture.army(g, ArmyFixture.TAG, from, 0, 1)
		for d: int in 6:
			var goal := ImproveRules.neighbour(from, d)
			if not g.map.is_land(goal) or Supply.in_supply(g, ArmyFixture.TAG, goal, false) != goal_in_supply:
				continue
			if Movement.march_check(g, {"army": a.id, "goal": goal, "tag": ArmyFixture.TAG})["ok"]:
				return [a, goal]
		Armies.remove(g, a)
	return []


func _hungry(g: Game) -> Array[Dictionary]:
	return Reminders.army_hungry(g, ArmyFixture.TAG)


func test_out_of_supply_whose_walk_ends_in_supply_with_no_losses_is_not_named() -> void:
	var g := ArmyFixture.game()
	var pair := _pair(g, true)
	if pair.is_empty():
		pending("the fixture has no out-of-supply hex beside a supplied one")
		return
	var a := pair[0] as Army
	var goal := pair[1] as Vector2i
	assert_true(bool(g.act("march", {"army": a.id, "goal": goal, "tag": ArmyFixture.TAG})["ok"]))
	assert_eq(Reminders.season_end(g, a), goal, "this season's walk ends on the supplied goal")
	assert_true(Supply.in_supply(g, ArmyFixture.TAG, goal, false))
	assert_true(_hungry(g).is_empty(), "the walk ends in supply and no men are lost: nothing to warn of")


func test_out_of_supply_that_stays_out_of_supply_is_named_will_lose() -> void:
	# No march: the season's end is the army's own hex, out of supply, so the walk ends out of supply.
	var g := ArmyFixture.game()
	var out_hex := ArmyFixture.NO_HEX
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and not Supply.in_supply(g, ArmyFixture.TAG, hex, false):
			out_hex = hex
			break
	if out_hex == ArmyFixture.NO_HEX:
		pending("the fixture has no land out of supply")
		return
	var a := ArmyFixture.army(g, ArmyFixture.TAG, out_hex, 0, 1)
	assert_eq(Reminders.season_end(g, a), out_hex, "an army that does not march ends where it stands")
	var lines := _hungry(g)
	assert_eq(lines.size(), 1, "the season ends out of supply: named")
	assert_true(str(lines[0]["text"]).find("will lose about") >= 0, str(lines[0]["text"]))
	assert_eq(lines[0]["hex"], out_hex)


func test_an_army_in_supply_that_lost_men_is_named_as_hunger_at_its_hex() -> void:
	var g := ArmyFixture.game()
	var town := ArmyFixture.find_town(g)
	var a := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 1)
	Armies.set_supply(g, a, Supply.HUNGRY, 100)
	g.version += 1
	assert_true(Supply.in_supply(g, ArmyFixture.TAG, town, false), "the army stands in supply")
	var lines := _hungry(g)
	assert_eq(lines.size(), 1, "losing men in supply is named")
	var text := str(lines[0]["text"])
	assert_true(text.find("lost 100 men to hunger") >= 0, text)
	assert_true(text.find("the stores are empty") >= 0, text)
	assert_eq(text.find("will lose"), -1, "no 'will lose' for an army in supply: %s" % text)
	assert_eq(lines[0]["action"], [&"select_army", a.id])


func test_idle_line_places_the_army_with_at_not_at_near() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	var a := ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 1)
	var text := ""
	for line: Dictionary in Reminders.unfinished(g, ArmyFixture.TAG):
		if line["kind"] == &"army_idle":
			text = str(line["text"])
	assert_true(text.find("the %s %s." % [a.name, Words.at(g, hex)]) >= 0, text)
	assert_eq(text.find("at near"), -1, "no 'at near': %s" % text)
