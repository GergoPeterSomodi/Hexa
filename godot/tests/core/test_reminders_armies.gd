## The four army reminders (docs/architecture/m6-build-spec.md 4.15 and 9; L12): army_idle (an army with no order; P: a holding
## army makes no line), army_hungry (out of supply and losing men; P: an army in supply with no losses makes none), army_stores
## (the grain and fish under the armies' food; P: a full store makes none), and the order of the lines (severity, then RULES).
extends GutTest


func _kinds(g: Game) -> Array[StringName]:
	var out: Array[StringName] = []
	for line: Dictionary in Reminders.unfinished(g, ArmyFixture.TAG):
		out.append(line["kind"])
	return out


func _line(g: Game, kind: StringName) -> Dictionary:
	for line: Dictionary in Reminders.unfinished(g, ArmyFixture.TAG):
		if line["kind"] == kind:
			return line
	return {}


## A land hex that the supply field of the viewer does not reach in summer, or NO_HEX.
func _out_of_supply_hex(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and not Supply.in_supply(g, ArmyFixture.TAG, hex, false):
			return hex
	return ArmyFixture.NO_HEX


func test_a_new_army_awaits_orders() -> void:
	var g := ArmyFixture.game()
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	var line := _line(g, &"army_idle")
	assert_false(line.is_empty(), "a new army with no order is named")
	assert_eq(int(line["severity"]), 1)
	assert_true(str(line["text"]).begins_with("1 army awaits orders: the %s at " % a.name), str(line["text"]))
	assert_eq(line["action"], [&"select_army", a.id])


func test_a_holding_army_makes_no_idle_line() -> void:
	var g := ArmyFixture.game()
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	assert_true(bool(g.act("halt", {"army": a.id, "tag": ArmyFixture.TAG})["ok"]))
	assert_false(_kinds(g).has(&"army_idle"), "a held army has its order")


func test_an_army_out_of_supply_that_loses_men_is_hungry() -> void:
	var g := ArmyFixture.game()
	var hex := _out_of_supply_hex(g)
	assert_ne(hex, ArmyFixture.NO_HEX)
	var a := ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 1)
	Armies.set_supply(g, a, Supply.HUNGRY, 100)
	g.version += 1
	var line := _line(g, &"army_hungry")
	assert_false(line.is_empty(), "an army that lost men out of supply is named")
	assert_eq(int(line["severity"]), 2)
	assert_true(str(line["text"]).find("lost 100 men") >= 0, str(line["text"]))
	assert_eq(line["hex"], hex)


func test_an_army_in_supply_with_no_losses_is_not_hungry() -> void:
	var g := ArmyFixture.game()
	ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	assert_false(_kinds(g).has(&"army_hungry"), "a fed army in supply is no reminder")


func test_stores_under_the_armies_food_name_it() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 2)
	var c := Countries.by_tag(g, ArmyFixture.TAG)
	for key: StringName in [&"grain", &"fish"]:
		var gid := g.defs.good_id(key)
		if gid >= 0 and gid < c.stock.size():
			c.stock[gid] = 0
	g.version += 1
	assert_true(Supply.army_food(g, ArmyFixture.TAG) > 0, "the army eats from the stores")
	var line := _line(g, &"army_stores")
	assert_false(line.is_empty(), "empty stores under the army's food are named")
	assert_eq(int(line["severity"]), 2)
	assert_eq(line["action"], [&"study", &"military"])


func test_full_stores_make_no_stores_line() -> void:
	var g := ArmyFixture.game()
	ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 2)
	ArmyFixture.rich(g)
	g.version += 1
	assert_false(_kinds(g).has(&"army_stores"), "stores that feed the army are no reminder")


func test_lines_are_worst_first() -> void:
	var g := ArmyFixture.game()
	var hex := _out_of_supply_hex(g)
	var a := ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 1)
	Armies.set_supply(g, a, Supply.HUNGRY, 50)
	ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	g.version += 1
	var last := 99
	for line: Dictionary in Reminders.unfinished(g, ArmyFixture.TAG):
		assert_true(int(line["severity"]) <= last, "severity descends")
		last = int(line["severity"])
