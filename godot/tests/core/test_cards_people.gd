## PeopleCards (docs/architecture/m5-build-spec.md 5.6, 6.3): the People card's lines sum to the chip's change and the
## Food card is consistent with the closed flows, on Genoa's first year.
extends GutTest

const GEN := &"GEN"


func _number(text: String) -> int:
	return int(text.replace("▲", "").replace("▼", "").replace("+", "").replace("−", "-").replace(",", "").strip_edges())


func _rule_at(lines: Array) -> int:
	for k: int in lines.size():
		if (lines[k] as Array)[1] == &"rule":
			return k
	return -1


func _changes_sum(lines: Array) -> int:
	var total := 0
	for k: int in range(_rule_at(lines) + 1, lines.size() - 1):
		total += _number(str((lines[k] as Array)[2]))
	return total


func test_people_card_at_the_start() -> void:
	var g := PeopleFixture.genoa()
	var card := PeopleCards.people(g, GEN)
	assert_eq(card["title"], "People")
	assert_eq(int(card["value"]), 82700)
	assert_eq(int(card["change"]), 0)
	assert_eq(card["hint"], "Click: the People page")
	var lines: Array = card["lines"]
	assert_eq((lines[0] as Array)[0], "Towns")
	assert_eq((lines[0] as Array)[2], "40,000")
	assert_eq((lines[1] as Array)[2], "42,700")
	var last: Array = lines[lines.size() - 1]
	assert_eq(last[0], "Room for %s more" % Words.number(int(PeopleView.totals(g, GEN)["room_left"])))


func test_people_card_lines_sum_to_the_change_every_season() -> void:
	var g := PeopleFixture.genoa()
	for n: int in 4:
		assert_true(bool(Season.run(g)["ok"]))
		var card := PeopleCards.people(g, GEN)
		var lines: Array = card["lines"]
		assert_eq(_rule_at(lines), 2)
		assert_eq(_number(str((lines[0] as Array)[2])) + _number(str((lines[1] as Array)[2])), int(card["value"]),
			"towns and countryside make the value")
		assert_eq(_changes_sum(lines), int(card["change"]), "season %d" % (n + 1))
	var c := Countries.by_tag(g, GEN)
	assert_eq(int(PeopleCards.people(g, GEN)["change"]), 84977 - 84469)
	assert_eq(int(PeopleCards.people(g, GEN)["change"]), int((c.people_closed["flows"] as PackedInt32Array)[People.GREW]))


func test_people_card_shows_starved_and_left_only_when_not_zero() -> void:
	var g := PeopleFixture.genoa()
	Season.run(g)
	var texts: Array[String] = []
	for row: Variant in PeopleCards.people(g, GEN)["lines"]:
		texts.append(str((row as Array)[0]))
	assert_true(texts.has("Grew"))
	assert_false(texts.has("Starved"))
	assert_false(texts.has("Left"))
	var c := Countries.by_tag(g, GEN)
	var flows := c.people_closed["flows"] as PackedInt32Array
	flows[People.STARVED] = -50
	flows[People.LEFT] = -7
	c.people_closed["flows"] = flows
	var card := PeopleCards.people(g, GEN)
	texts.clear()
	for row: Variant in card["lines"]:
		texts.append(str((row as Array)[0]))
	assert_true(texts.has("Starved"))
	assert_true(texts.has("Left"))
	assert_true(texts.has("Other"), "what the flows do not explain is a line of its own, so the lines still sum")
	assert_eq(_changes_sum(card["lines"]), int(card["change"]))


func test_cards_of_an_unknown_or_foreign_country_are_empty() -> void:
	var g := PeopleFixture.genoa()
	assert_eq(PeopleCards.people(g, &"MLO"), {})
	assert_eq(PeopleCards.food(g, &"MLO"), {})
	assert_eq(PeopleCards.people(g, &"ZZZ"), {})
	assert_eq(PeopleCards.people(null, GEN), {})


func test_food_card() -> void:
	var g := PeopleFixture.genoa()
	var c := Countries.by_tag(g, GEN)
	var grain := g.defs.good_id(&"grain")
	var fish := g.defs.good_id(&"fish")
	var card := PeopleCards.food(g, GEN)
	assert_eq(card["title"], "Food")
	assert_eq(card["tone"], &"plain")
	assert_eq(int(card["change"]), 0)
	assert_eq(int(card["value"]), c.stock[grain] + c.stock[fish])
	assert_eq((card["lines"] as Array)[0][0], "No season has ended yet.")
	Season.run(g)
	card = PeopleCards.food(g, GEN)
	assert_eq(int(card["value"]), c.stock[grain] + c.stock[fish])
	var closing := c.goods_closed["closing"] as PackedInt32Array
	var opening := c.goods_closed["opening"] as PackedInt32Array
	assert_eq(int(card["change"]), closing[grain] - opening[grain] + closing[fish] - opening[fish])
	var lines: Array = card["lines"]
	var made := Stores.flow(c, grain, &"made", true) + Stores.flow(c, fish, &"made", true)
	var eaten := -Stores.flow(c, grain, &"used", true) - Stores.flow(c, fish, &"used", true)
	assert_true(str((lines[0] as Array)[0]).begins_with("Made %d · Eaten %d · Sold " % [made, eaten]), (lines[0] as Array)[0])
	assert_eq((lines[1] as Array)[0], "Your towns need 5 a season")
	assert_eq((lines[2] as Array)[0], "Lasts over 8 seasons")


func test_food_card_is_bad_when_hungry() -> void:
	var g := PeopleFixture.genoa()
	Countries.by_tag(g, GEN).food_fed = 400
	assert_eq(PeopleCards.food(g, GEN)["tone"], &"bad")
