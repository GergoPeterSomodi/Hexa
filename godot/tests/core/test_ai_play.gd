## Every country plays (docs/architecture/m8-build-spec.md 9, done-when 1): on "Italy, 1480" in an AI-only game, every one of the 13
## countries raises a company by the end of Summer 1480, and each of the 10 countries with 12 districts or more (all but Mantua, Siena
## and Lucca) begins a work by the end of Winter 1481. Read from the action log: every act of a seat carries its tag.
extends GutTest

const SMALL: Array[StringName] = [&"MAN", &"SIE", &"LUC"]


## The tags that did `actions` in the seasons up to and including `last_turn`.
func _who(g: Game, actions: Array[String], last_turn: int) -> Dictionary:
	var out := {}
	for r: Dictionary in g.action_log:
		if actions.has(str(r["action"])) and int(r["turn"]) <= last_turn:
			out[StringName(str((r["args"] as Dictionary).get("tag", "")))] = true
	return out


func test_every_country_raises_by_the_end_of_summer_1480_and_builds_by_the_end_of_winter_1481() -> void:
	var g := AiFixture.watch(null, 1480)
	assert_eq(g.countries.size(), 13)
	var big := 0
	for c: Country in g.countries:
		if Territory.districts(g, c.id).size() >= 12:
			big += 1
			assert_false(SMALL.has(c.tag), "%s has 12 districts" % c.tag)
		else:
			assert_true(SMALL.has(c.tag), "%s has fewer than 12 districts" % c.tag)
	assert_eq(big, 10)
	var summer := -1
	var winter := -1
	for n: int in 8:
		Season.run(g)
		if g.turn == 3:
			summer = g.turn - 1
			var raised := _who(g, ["raise"], summer)
			for c: Country in g.countries:
				assert_true(raised.has(c.tag), "%s raised a company by the end of Summer 1480" % c.tag)
	winter = g.turn - 1
	assert_eq(Calendar.date_text(summer, g.start_year), "Summer 1480")
	assert_eq(Calendar.date_text(winter, g.start_year), "Winter 1481")
	assert_eq(summer, 2)
	assert_eq(winter, 8)
	var began := _who(g, ["build", "upgrade"], winter)
	for c: Country in g.countries:
		if not SMALL.has(c.tag):
			assert_true(began.has(c.tag), "%s began a work by the end of Winter 1481" % c.tag)
