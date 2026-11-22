## The three war reminders (docs/architecture/m7-build-spec.md 4.18; M7 plan B19) on the Savoy game of test_war_savoy: `besieged`
## (a fortress of the player besieged: severity 2, the words, the action), `occupied` (an enemy holds districts of the player:
## severity 1, one line per enemy) and `war_timer` (a war of the player from the warning's season: 32 seasons; 31 seasons give
## nothing; the words name the seasons left to the timer). Their place in Reminders' order is the spec's list.
extends GutTest

const SAV := &"SAV"
const MLO := &"MLO"
const PAVIA := Vector2i(10, 9)

var _g: Game = null


func before_each() -> void:
	_g = EconomyFixture.game(SAV, false, true, EconomyFixture.SEED, false)
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func test_the_war_timer_waits_for_the_warning_season() -> void:
	var w := WarFixture.at_war(_g, SAV, MLO)
	_g.turn = w.start_turn + 31
	assert_true(RemindersWar.war_timer(_g, SAV).is_empty(), "a war of 31 seasons makes no war_timer")
	_g.turn = w.start_turn + 32
	var lines := RemindersWar.war_timer(_g, SAV)
	assert_eq(lines.size(), 1, "a war of 32 seasons makes one line")
	var line := lines[0]
	assert_eq(int(line["severity"]), 1, "the timer is severity 1")
	assert_eq(str(line["text"]), "The war with the Duchy of Milan ends in a white peace in 8 seasons.", "the words")
	assert_eq(line["action"], [&"country", MLO], "the action shows the enemy")


func test_a_war_that_ended_gives_no_timer() -> void:
	var w := WarFixture.at_war(_g, SAV, MLO)
	w.end_turn = w.start_turn + 5
	w.terms = &"white"
	_g.turn = w.start_turn + 40
	assert_true(RemindersWar.war_timer(_g, SAV).is_empty(), "an ended war has no timer line")


func test_an_occupied_district_of_the_player_is_one_line_per_enemy() -> void:
	WarFixture.at_war(_g, SAV, MLO)
	var district := Territory.districts(_g, Countries.by_tag(_g, SAV).id)[0]
	var hex := _g.map.hex_of(district)
	WarFixture.set_occupier(_g, hex, MLO)
	var lines := RemindersWar.occupied(_g, SAV)
	assert_eq(lines.size(), 1, "one enemy holds land: one line")
	assert_eq(int(lines[0]["severity"]), 1, "severity 1")
	assert_true(str(lines[0]["text"]).begins_with("The Duchy of Milan holds 1 of your district: "), "the words: %s" % str(lines[0]["text"]))
	assert_eq(lines[0]["hex"], hex, "the line points at the district")


func test_a_fortress_of_the_player_besieged_is_serious() -> void:
	# The siege comes from the real producer: a war, four companies on Pavia, one season (Sieges.season names it).
	assert_true(bool(_g.act("declare_war", {"target": MLO, "tag": SAV})["ok"]), "Savoy declares war on Milan")
	WarFixture.army_at(_g, SAV, PAVIA, 4)
	assert_true(bool(Season.run(_g)["ok"]), "the season ends")
	assert_eq(_g.sieges.size(), 1, "the siege stands")
	assert_eq(Occupation.controller_tag(_g, PAVIA), MLO, "Milan holds Pavia")
	var line := RemindersWar.besieged(_g, MLO)
	assert_false(line.is_empty(), "a besieged fortress of Milan gives a line")
	assert_eq(int(line["severity"]), 2, "a siege is serious")
	assert_true(str(line["text"]).begins_with("Pavia (10, 9) is besieged by Savoy: "), "the words: %s" % str(line["text"]))
	assert_eq(line["action"], [&"look_at", PAVIA], "the action looks at the fortress")
	assert_eq(str(line["action_label"]), "Go to Pavia", "the label names the place, not the siege")


func test_the_war_rules_are_in_the_spec_order() -> void:
	var rules := Reminders.RULES
	assert_eq(rules.size(), 14, "fourteen rules")
	assert_eq(rules.find(&"besieged"), 4, "besieged after army_stores")
	assert_eq(rules.find(&"occupied"), 8, "occupied after winter_passes")
	assert_eq(rules.find(&"war_timer"), 9, "war_timer after occupied")
