## Works (docs/architecture/m3-build-spec.md 4.3, 5.2, 5.3, 9): every row of the two check tables with its words, the
## durations, the winter halt, the three worked examples, slots, the pending pair rule, lost and blocked works,
## cancelling, and the schema of Work.
extends GutTest

const DEFS_PATH := "res://data/defs/game_defs.tres"
const MAP_PATH := "res://data/maps/north_italy.tres"
const ALPHA := Vector2i(0, 2)
const ALPHA_2 := Vector2i(0, 3)
const ALPHA_3 := Vector2i(0, 4)
const BETA := Vector2i(4, 2)

var _italy: Game = null


func before_all() -> void:
	var defs := load(DEFS_PATH) as GameDefs
	var scenario: ScenarioDef = null
	for s: ScenarioDef in defs.scenarios:
		scenario = s
	_italy = Game.new_scenario(load(MAP_PATH) as MapData, defs, scenario, 1480)


## The fixture scenario with AAA chosen and the home hexes cleared of what the search put there.
func _game() -> Game:
	var g := ScenarioFixture.game()
	for hex: Vector2i in [ALPHA, ALPHA_2, ALPHA_3, BETA]:
		g.improvement.clear(hex)
	g.act("choose_country", {"tag": &"AAA"})
	g.events.clear()
	return g


func _build(game: Game, hex: Vector2i = ALPHA, tag: StringName = &"AAA", family: int = ImproveRules.WHEAT) -> Dictionary:
	return game.act("build", {"hex": hex, "family": family, "tag": tag})


func _run_until_done(game: Game, limit: int = 40) -> int:
	var n := 0
	while not game.state.works.is_empty() and n < limit:
		Season.run(game)
		n += 1
	return n


func _kinds(game: Game) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in game.events:
		out.append(str(event["kind"]))
	return out


# ----- check table: rows 1 to 8 ---------------------------------------------------------------------------------


func test_row_1_no_hex_or_no_piece() -> void:
	var g := _game()
	assert_eq(g.check("build", {})["reason"], "no hex given")
	assert_eq(g.check("build", {"hex": "x", "family": 3})["reason"], "no hex given")
	assert_eq(g.check("build", {"hex": ALPHA, "tag": &"AAA"})["reason"], "no piece given")
	assert_eq(g.check("build", {"hex": ALPHA, "family": "wheat"})["reason"], "no piece given")
	assert_eq(g.check("upgrade", {})["reason"], "no hex given")
	assert_eq(g.check("clear", {"hex": 5})["reason"], "no hex given")
	assert_eq(g.check("cancel_work", {})["reason"], "no hex given")
	var bare := Game.new_game(g.map, 1)  # row 1 comes before row 2
	assert_eq(bare.check("build", {})["reason"], "no hex given")


func test_row_2_no_definitions() -> void:
	var m := ImproveFixture.block(5, 5, {})
	var g := Game.new_game(m, 1)
	var reason := "no work data: this game has no definitions"
	assert_eq(g.check("build", {"hex": Vector2i(1, 1), "family": ImproveRules.WHEAT})["reason"], reason)
	assert_eq(g.check("upgrade", {"hex": Vector2i(1, 1)})["reason"], reason)
	assert_eq(g.check("clear", {"hex": Vector2i(1, 1)})["reason"], reason)
	var before := g.digest()
	assert_false(bool(g.act("build", {"hex": Vector2i(1, 1), "family": ImproveRules.WHEAT})["ok"]))
	assert_eq(g.digest(), before, "P: nothing changed")


func test_row_3_the_home_rule_comes_first() -> void:
	var g := _game()
	_build(g)
	assert_eq(g.check("build", {"hex": ALPHA, "family": ImproveRules.WHEAT})["reason"], "choose your country first")
	var foreign := g.check("upgrade", {"hex": ALPHA, "tag": &"BBB"})
	# R32: ALPHA is not discovered by BBB in this fixture, so the holder is not named.
	assert_eq(foreign["reason"], "not your land: another country holds it", "another country's work is never named")
	assert_eq(g.check("clear", {"hex": ScenarioFixture.UNOWNED_HEXES[0], "tag": &"AAA"})["reason"], "no one holds this land")


func test_row_4_a_work_is_under_way() -> void:
	var g := _game()
	assert_true(bool(_build(g)["ok"]))
	var words := "a work is under way here: wheat, first stage, ready Spring 1481"
	assert_eq(g.check("build", {"hex": ALPHA, "family": ImproveRules.WHEAT, "tag": &"AAA"})["reason"], words)
	assert_eq(g.check("upgrade", {"hex": ALPHA, "tag": &"AAA"})["reason"], words,
		"an upgrade asked on a hex whose build is under way hears it, not 'nothing is built here'")
	assert_eq(g.check("clear", {"hex": ALPHA, "tag": &"AAA"})["reason"], words)
	Season.run(g)
	assert_eq(g.check("clear", {"hex": ALPHA, "tag": &"AAA"})["reason"], words, "the date holds as seasons pass")


func test_row_5_the_pieces_own_rules_unchanged() -> void:
	var g := _game()
	assert_eq(g.check("build", {"hex": ScenarioFixture.ALPHA_CAPITAL, "family": ImproveRules.WHEAT, "tag": &"AAA"})["reason"],
		"something already stands here")
	assert_eq(g.check("upgrade", {"hex": ALPHA, "tag": &"AAA"})["reason"], "nothing is built here: build something first")
	assert_eq(g.check("clear", {"hex": ALPHA, "tag": &"AAA"})["reason"], "nothing is built here")
	assert_eq(g.check("clear", {"hex": ScenarioFixture.ALPHA_CAPITAL, "tag": &"AAA"})["reason"],
		"a place of the map is never pulled down")
	assert_eq(g.check("build", {"hex": ALPHA, "family": 99, "tag": &"AAA"})["reason"], "no such piece")
	assert_eq(g.check("build", {"hex": ScenarioFixture.SEA_HEX, "family": ImproveRules.WHEAT})["reason"], "not a land hex")


func _town_game() -> Game:
	var m := ImproveFixture.block(7, 5, {}, {Vector2i(3, 2): {"place": ImproveFixture.place(3)}})
	var g := Game.new_game(m, 1, load(DEFS_PATH) as GameDefs)
	for hex: Vector2i in g.improvement.hexes:
		g.improvement.clear(hex)
	g.improvement.build_on(Vector2i(2, 2), ImproveRules.WHEAT)
	g.improvement.upgrade(Vector2i(2, 2))
	g.improvement.build_on(Vector2i(2, 3), ImproveRules.WHEAT)
	g.improvement.upgrade(Vector2i(2, 3))
	return g


func test_row_6_the_pending_pair_rule() -> void:
	var g := _town_game()
	var first := g.act("upgrade", {"hex": Vector2i(2, 2)})
	assert_true(bool(first["ok"]), str(first["reason"]))
	var second := g.check("upgrade", {"hex": Vector2i(2, 3)})
	assert_false(bool(second["ok"]), "P: two level 3 goods works side by side")
	assert_eq(second["reason"], "a work under way at (2, 2) would break it: the top stage stays rare: two level 3 districts never touch")
	var before := g.digest()
	assert_false(bool(g.act("upgrade", {"hex": Vector2i(2, 3)})["ok"]))
	assert_eq(g.digest(), before)
	# A clear work has no target and never clashes; a work two hexes away from a one-hex rule does not clash either.
	assert_eq(Works.pending_conflict(g, Vector2i(2, 3), 0, 0), "")
	assert_eq(Works.pending_conflict(g, Vector2i(5, 4), ImproveRules.WHEAT, 3), "")
	assert_eq(Works.pending_conflict(g, Vector2i(2, 2), ImproveRules.WHEAT, 3), "", "the hex's own work is not a clash")
	assert_true(bool(g.act("clear", {"hex": Vector2i(2, 3)})["ok"]), "a clearing beside it is fine")
	assert_eq(g.state.works[1].action, &"clear")


func test_row_7_no_free_slot() -> void:
	var g := _game()
	assert_eq(Works.slots(g, &"AAA"), 1)
	assert_true(bool(_build(g)["ok"]))
	var full := g.check("build", {"hex": ALPHA_2, "family": ImproveRules.WHEAT, "tag": &"AAA"})
	assert_eq(full["reason"], "no free work slot: 1 of 1 in use")
	assert_eq(Works.in_use(g, &"AAA"), 1)
	var before := g.digest()
	assert_false(bool(_build(g, ALPHA_2)["ok"]))
	assert_eq(g.digest(), before, "P: a refusal changes nothing")
	assert_true(bool(g.act("cancel_work", {"hex": ALPHA, "tag": &"AAA"})["ok"]), "a cancelled work frees the slot")
	assert_true(bool(_build(g, ALPHA_2)["ok"]))


func test_row_8_ok_and_no_limit_in_a_map_only_game() -> void:
	var m := ImproveFixture.block(9, 9, {})
	var g := Game.new_game(m, 1, load(DEFS_PATH) as GameDefs)
	for hex: Vector2i in g.improvement.hexes:
		g.improvement.clear(hex)
	assert_eq(Works.slots(g, &""), -1, "no limit")
	var begun := 0
	for c: int in [0, 2, 4, 6, 8]:
		for r: int in [0, 2, 4, 6, 8]:
			if bool(g.act("build", {"hex": Vector2i(c, r), "family": ImproveRules.WHEAT})["ok"]):
				begun += 1
	assert_eq(begun, 25, "more works than any slot count")
	assert_eq(Works.in_use(g, &""), 25)


# ----- cancel_work -----------------------------------------------------------------------------------------------


func test_cancel_work_check_rows() -> void:
	var g := _game()
	assert_eq(g.check("cancel_work", {})["reason"], "no hex given")
	assert_eq(g.check("cancel_work", {"hex": ALPHA, "tag": &"AAA"})["reason"], "no work is under way here")
	_build(g)
	# R32: ALPHA is not discovered by BBB or by the empty tag, so the orderer is not named.
	assert_eq(g.check("cancel_work", {"hex": ALPHA, "tag": &"BBB"})["reason"], "not your work: another country ordered it")
	assert_eq(g.check("cancel_work", {"hex": ALPHA})["reason"], "not your work: another country ordered it")
	assert_true(bool(g.check("cancel_work", {"hex": ALPHA, "tag": &"AAA"})["ok"]))
	assert_eq(g.state.works.size(), 1, "a check changes nothing")


func test_cancel_in_its_first_season_and_later() -> void:
	var g := _game()
	var treasury := Countries.by_tag(g, &"AAA").treasury
	_build(g)
	assert_eq(Countries.by_tag(g, &"AAA").treasury, treasury - 40)
	g.events.clear()
	assert_true(bool(g.act("cancel_work", {"hex": ALPHA, "tag": &"AAA"})["ok"]))
	assert_true(g.state.works.is_empty())
	assert_eq(_kinds(g), ["work_cancelled"])
	var event := g.events[0]
	assert_eq(event["why"], &"order")
	assert_eq(event["refund"], 40, "the wheat's 40 ducats, cancelled in its first season")
	assert_eq(Countries.by_tag(g, &"AAA").treasury, treasury, "and back in the treasury")
	assert_eq(event["tag"], &"AAA")
	assert_eq(event["hex"], ALPHA)
	assert_eq(int((event["work"] as Dictionary)["id"]), 1)
	assert_eq(g.state.main_use[g.map.index_of(ALPHA)], 0, "nothing was put")
	_build(g)
	Season.run(g)
	g.events.clear()
	assert_true(bool(g.act("cancel_work", {"hex": ALPHA, "tag": &"AAA"})["ok"]))
	assert_eq(g.events[0]["refund"], 0, "nothing back after the first season")
	assert_eq(g.chronicle.entries.size() > 0, true, "the cancelling is chronicled")
	assert_eq(str(g.chronicle.entries[g.chronicle.entries.size() - 1]["kind"]), "work_cancelled")


# ----- beginning, finishing, halting, durations -------------------------------------------------------------------


func test_begin_adds_a_work_and_changes_nothing_else() -> void:
	var g := _game()
	var use_before := g.state.main_use.duplicate()
	var level_before := g.state.level.duplicate()
	assert_true(bool(_build(g)["ok"]))
	assert_eq(g.state.main_use, use_before)
	assert_eq(g.state.level, level_before)
	assert_eq(_kinds(g), ["work_started"])
	var w := g.state.works[0]
	assert_eq([w.id, w.tag, w.hex, w.action, w.family, w.level_to], [1, &"AAA", ALPHA, &"build", ImproveRules.WHEAT, 1])
	assert_eq([w.started_turn, w.seasons, w.seasons_left, w.paid], [1, 4, 4, 40])
	assert_eq(w.paid_goods, {})
	assert_eq(g.state.next_work_id, 2)
	assert_eq(g.events[0]["work"], w.to_dict())
	assert_eq(str(g.chronicle.entries[g.chronicle.entries.size() - 1]["kind"]), "work_started")
	assert_eq(g.chronicle.entries[g.chronicle.entries.size() - 1]["tag"], "AAA", "the chronicle holds plain values")


func test_a_work_begun_in_spring_with_four_seasons_stands_from_spring_next_year() -> void:
	var g := _game()
	_build(g)
	var i := g.map.index_of(ALPHA)
	for n: int in 3:
		Season.run(g)
		assert_eq(g.state.main_use[i], 0)
	g.events.clear()
	Season.run(g)
	assert_eq(g.turn, 5)
	assert_eq(g.date_text(), "Spring 1481")
	assert_eq(g.state.main_use[i], ImproveRules.WHEAT)
	assert_eq(_kinds(g), ["hex_changed", "work_finished"])
	assert_eq(g.events[1]["turn"], 4, "finished in the works phase of the fourth season")
	assert_true(g.state.works.is_empty())


func test_durations_per_family_and_level() -> void:
	var g := _game()
	for f: int in range(1, FamilyIds.COUNT):
		var top := FamilyIds.TOP_LEVEL[f]
		var expected: Array[int] = [4, 8, 16]
		if f == ImproveRules.SETTLEMENT:
			expected = [4, 4, 8, 8, 8]
		for level: int in range(1, top + 1):
			assert_eq(Works.seasons_for(g, &"build" if level == 1 else &"upgrade", f, level), expected[level - 1],
				"%s to level %d" % [FamilyIds.NAMES[f], level])
		assert_eq(Works.seasons_for(g, &"clear", f, 0), 1, "a clearing takes one season")
	assert_eq(Works.seasons_for(g, &"build", 99, 1), 1, "an unknown family")


func _snow_game() -> Game:
	var g := _game()
	g.map.climate[g.map.index_of(ALPHA)] = 0
	return g


func test_the_winter_halt() -> void:
	var g := _snow_game()
	_build(g)
	var w := g.state.works[0]
	assert_false(Works.halted(g, w, 3))
	assert_true(Works.halted(g, w, 4), "Winter and snow")
	assert_false(Works.halted(g, w, 5))
	assert_eq(Works.ready_turn(g, w), 6, "the winter waits: stands from turn 6, not 5")
	for n: int in 4:
		Season.run(g)
	assert_eq(w.seasons_left, 1, "turn 4 was halted")
	assert_eq(g.state.main_use[g.map.index_of(ALPHA)], 0)
	Season.run(g)
	assert_eq(g.turn, 6)
	assert_eq(g.state.main_use[g.map.index_of(ALPHA)], ImproveRules.WHEAT)
	# The rule off, or a frost hex: no halt.
	var off := _snow_game()
	off.defs.works_halt_in_snow_winter = false
	_build(off)
	assert_false(Works.halted(off, off.state.works[0], 4))
	assert_eq(Works.ready_turn(off, off.state.works[0]), 5)
	var frost := _game()
	frost.map.climate[frost.map.index_of(ALPHA)] = 1
	_build(frost)
	assert_eq(Works.ready_turn(frost, frost.state.works[0]), 5)


func _put_work(game: Game, hex: Vector2i, family: int, action: StringName, level_to: int, seasons: int) -> Work:
	var w := Work.new()
	w.id = game.state.next_work_id
	game.state.next_work_id += 1
	w.tag = Territory.owner_tag(game, hex)
	w.hex = hex
	w.action = action
	w.family = family
	w.level_to = level_to
	w.started_turn = game.turn
	w.seasons = seasons
	w.seasons_left = seasons
	game.state.works.append(w)
	return w


## A game over a copy of the scenario game's state: no new improvement search.
func _copy_italy() -> Game:
	var g := Game.with_state(_italy.map, _italy.state.duplicate_state(), _italy.seed_value, _italy.defs)
	g.scenario = _italy.scenario
	g.start_year = _italy.start_year
	for c: Country in _italy.countries:
		g.countries.append(Country.from_dict(c.to_dict()))
	return g


## Plays a work of the north Italy scenario until it leaves the list; the turn then is the season it stands from.
func _stands_from(hex: Vector2i, family: int, action: StringName, level_to: int, seasons: int, start_turn: int) -> int:
	var g := _copy_italy()
	g.turn = start_turn
	g.act("choose_country", {"tag": &"GEN"})
	var w := _put_work(g, hex, family, action, level_to, seasons)
	var predicted := Works.ready_turn(g, w)
	var n := 0
	while not g.state.works.is_empty() and n < 40:
		Season.run(g)
		n += 1
	assert_eq(g.turn, predicted, "ready_turn says when it stands")
	return g.turn


func test_the_three_worked_examples() -> void:
	var map := _italy.map
	assert_eq(int(map.climate[map.index_of(Vector2i(7, 12))]), 1, "Savona is frost")
	assert_eq(int(map.climate[map.index_of(Vector2i(9, 11))]), 0, "the Genoese woods are snow")
	assert_eq(int(map.climate[map.index_of(Vector2i(8, 13))]), 2, "Genoa is mild")
	assert_eq(_stands_from(Vector2i(7, 12), ImproveRules.VINEYARD, &"build", 1, 4, 1), 5, "Spring 1481")
	assert_eq(_stands_from(Vector2i(9, 11), ImproveRules.TIMBER, &"build", 1, 4, 2), 7, "Autumn 1481, not Summer 1481")
	assert_eq(_stands_from(Vector2i(8, 13), ImproveRules.SETTLEMENT, &"upgrade", 4, 8, 1), 9, "Spring 1482")
	assert_eq(Calendar.date_text(7, 1480), "Autumn 1481")


# ----- slots -----------------------------------------------------------------------------------------------------


func test_slots_on_the_1480_scenario() -> void:
	var expected := {
		&"SAV": 2, &"MLO": 3, &"VEN": 5, &"GEN": 2, &"TUS": 3, &"SWI": 1, &"MAN": 1, &"FER": 2, &"SIE": 1, &"LUC": 1,
		&"PAP": 2, &"FRA": 1, &"AUS": 1,
	}
	for tag: StringName in expected:
		assert_eq(Works.slots(_italy, tag), int(expected[tag]), "slots of %s" % String(tag))
	assert_eq(Works.in_use(_italy, &"GEN"), 0)


func test_no_slot_limit_in_a_map_only_game() -> void:
	var g := Game.new_game(ImproveFixture.block(3, 3, {}), 1, load(DEFS_PATH) as GameDefs)
	assert_eq(Works.slots(g, &""), -1)
	assert_eq(Works.slots(g, &"AAA"), -1)


# ----- lost and blocked ------------------------------------------------------------------------------------------


func test_a_work_on_land_transferred_away_is_cancelled_lost() -> void:
	var g := _game()
	_build(g)
	Territory.transfer(g, [ALPHA], 2)
	g.events.clear()
	Season.run(g)
	assert_true(g.state.works.is_empty())
	assert_eq(_kinds(g), ["work_cancelled"])
	assert_eq(g.events[0]["why"], &"lost")
	assert_eq(g.events[0]["reason"], "not your land: the Duchy of Beta holds it")
	assert_eq(g.events[0]["refund"], 0)
	assert_eq(g.state.main_use[g.map.index_of(ALPHA)], 0)


func test_a_work_made_unfinishable_by_a_state_edit_is_cancelled_blocked() -> void:
	var g := _game()
	_build(g)
	g.state.main_use[g.map.index_of(ALPHA)] = ImproveRules.HEMP  # a direct edit under the work's feet
	g.state.level[g.map.index_of(ALPHA)] = 1
	g.events.clear()
	for n: int in 4:
		Season.run(g)
	assert_true(g.state.works.is_empty())
	var cancelled: Array[Dictionary] = []
	for event: Dictionary in g.events:
		if str(event["kind"]) == "work_cancelled":
			cancelled.append(event)
	assert_eq(cancelled.size(), 1)
	assert_eq(cancelled[0]["why"], &"blocked")
	assert_eq(cancelled[0]["reason"], "something already stands here")
	assert_false(_kinds(g).has("work_finished"))


func test_works_keep_id_order() -> void:
	var g := Game.new_game(ImproveFixture.block(9, 9, {}), 1, load(DEFS_PATH) as GameDefs)
	for hex: Vector2i in g.improvement.hexes:
		g.improvement.clear(hex)
	for hex: Vector2i in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(8, 0), Vector2i(0, 4)]:
		assert_true(bool(g.act("build", {"hex": hex, "family": ImproveRules.WHEAT})["ok"]))
	g.act("cancel_work", {"hex": Vector2i(4, 0)})
	g.act("build", {"hex": Vector2i(4, 4), "family": ImproveRules.WHEAT})
	var ids: Array[int] = []
	for w: Work in g.state.works:
		ids.append(w.id)
	assert_eq(ids, [1, 3, 4, 5] as Array[int], "in id order, ids never reused")
	assert_eq(g.state.next_work_id, 6)
	Season.run(g)
	ids.clear()
	for event: Dictionary in g.events:
		if str(event["kind"]) == "work_finished":
			ids.append(int((event["work"] as Dictionary)["id"]))
	assert_eq(ids, [] as Array[int], "none finished yet")
	_run_until_done(g)
	ids.clear()
	for entry: Dictionary in g.chronicle.entries:
		if entry["kind"] == "work_finished":
			ids.append(int((entry["work"] as Dictionary)["id"]))
	assert_eq(ids, [1, 3, 4, 5] as Array[int], "finished in id order")


func test_the_works_phase_writes_only_its_fields() -> void:
	assert_eq(Works.OWNS, ["works", "next_work_id"])
	var g := _game()
	_build(g)
	var owner_before := g.state.owner.duplicate()
	var turn_before := g.turn
	Works.season(g)
	assert_eq(g.state.owner, owner_before)
	assert_eq(g.turn, turn_before, "the phase never moves the calendar")


# ----- Work and MapState schema 3 -----------------------------------------------------------------------------------


func test_work_round_trip_and_planted_faults() -> void:
	var w := Work.new()
	w.id = 7
	w.tag = &"GEN"
	w.hex = Vector2i(8, 13)
	w.action = &"upgrade"
	w.family = 1
	w.level_to = 4
	w.started_turn = 3
	w.seasons = 8
	w.seasons_left = 5
	var d := w.to_dict()
	assert_eq(d["tag"], "GEN")
	assert_eq(d["action"], "upgrade")
	var back := Work.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary)
	assert_not_null(back)
	assert_eq(back.digest_text(), w.digest_text())
	assert_eq(w.digest_text(), "7|GEN|8,13|upgrade|1|4|3|8|5|0|")
	w.paid = 1000
	w.paid_goods = {"timber": 20, "stone": 40}
	assert_eq(w.digest_text(), "7|GEN|8,13|upgrade|1|4|3|8|5|1000|stone:40,timber:20")
	d = w.to_dict()
	assert_eq(d["schema"], "hexa-godot/work/2")
	back = Work.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary)
	assert_eq(back.paid_goods, {"timber": 20, "stone": 40})
	assert_eq(back.digest_text(), w.digest_text(), "the same after the file")
	assert_eq(w.duplicate_work().paid_goods, w.paid_goods)
	var old := d.duplicate()
	old["schema"] = "hexa-godot/work/1"
	old.erase("paid_goods")
	assert_eq(Work.from_dict(old).paid_goods, {}, "work/1 loads with no goods paid")
	var bad_goods := d.duplicate()
	bad_goods["paid_goods"] = {"stone": "x"}
	assert_null(Work.from_dict(bad_goods), "P: a mistyped paid_goods")
	bad_goods["paid_goods"] = 5
	assert_null(Work.from_dict(bad_goods), "P: paid_goods that is no dictionary")
	bad_goods = d.duplicate()
	bad_goods.erase("paid_goods")
	assert_null(Work.from_dict(bad_goods), "P: work/2 without paid_goods")
	w.paid = 0
	w.paid_goods = {}
	d = w.to_dict()
	var bad := d.duplicate()
	bad["seasons_left"] = "5"
	assert_null(Work.from_dict(bad), "P: a string for seasons_left")
	bad = d.duplicate()
	bad.erase("id")
	assert_null(Work.from_dict(bad), "P: a missing field")
	bad = d.duplicate()
	bad["schema"] = "nope"
	assert_null(Work.from_dict(bad), "P: a wrong schema")
	bad = d.duplicate()
	bad["action"] = "teleport"
	assert_null(Work.from_dict(bad), "P: an unknown action")
	bad = d.duplicate()
	bad["hex"] = [1]
	assert_null(Work.from_dict(bad), "P: a bad hex")
	bad = d.duplicate()
	bad["tag"] = 5
	assert_null(Work.from_dict(bad), "P: a tag that is no text")


# ----- paying: costs, rows 8 and 9, refunds (m4-build-spec.md 4.11) ----------------------------------------------------


func _genoa() -> Game:
	return EconomyFixture.game(&"GEN")


func test_cost_of_reads_the_family_tables() -> void:
	var g := _genoa()
	assert_eq(Works.cost_of(g, &"build", ImproveRules.VINEYARD, 1), {"ducats": 40, "goods": {}})
	var city := g.defs.family(ImproveRules.SETTLEMENT)
	assert_eq(Works.cost_of(g, &"upgrade", ImproveRules.SETTLEMENT, 5)["ducats"], 1000)
	assert_eq(city.cost[5], 1000)
	assert_eq(Works.cost_of(g, &"upgrade", ImproveRules.SETTLEMENT, 5)["goods"], {"timber": 20, "stone": 40})
	assert_eq(Works.cost_of(g, &"clear", ImproveRules.VINEYARD, 0), {"ducats": 0, "goods": {}}, "a clearing is free")
	var sandbox := Game.new_game(EconomyFixture.map(), 1, EconomyFixture.committed())
	assert_eq(Works.cost_of(sandbox, &"build", ImproveRules.VINEYARD, 1), {"ducats": 0, "goods": {}}, "a map-only game pays nothing")


func test_row_8_money_and_row_9_goods() -> void:
	var g := _genoa()
	var genoa := Vector2i(8, 13)
	var verdict := g.check("upgrade", {"hex": genoa, "tag": &"GEN"})
	assert_eq(verdict["reason"], "not enough ducats: 1000 needed, 610 in the treasury")
	assert_true(g.dev_money(&"GEN", 390))
	assert_true(bool(g.check("upgrade", {"hex": genoa, "tag": &"GEN"})["ok"]), "1,000 of 1,000 is enough")
	assert_true(g.dev_goods(&"GEN", 12, -35))
	assert_eq(g.check("upgrade", {"hex": genoa, "tag": &"GEN"})["reason"], "not enough stone: 40 needed, 5 in store")
	assert_true(g.dev_goods(&"GEN", 11, -30))
	assert_eq(g.check("upgrade", {"hex": genoa, "tag": &"GEN"})["reason"], "not enough timber: 20 needed, 10 in store",
		"the first short good in id order")
	assert_true(g.dev_money(&"GEN", -1))
	assert_eq(g.check("upgrade", {"hex": genoa, "tag": &"GEN"})["reason"], "not enough ducats: 1000 needed, 999 in the treasury",
		"the ducats row comes first")
	var treasury := Countries.by_tag(g, &"GEN").treasury
	var stock := Countries.by_tag(g, &"GEN").stock.duplicate()
	assert_false(bool(g.act("upgrade", {"hex": genoa, "tag": &"GEN"})["ok"]))
	assert_eq(Countries.by_tag(g, &"GEN").treasury, treasury, "a refusal pays nothing")
	assert_eq(Countries.by_tag(g, &"GEN").stock, stock)


func test_a_work_pays_ducats_and_goods_and_a_cancel_gives_them_back_once() -> void:
	var g := _genoa()
	var c := Countries.by_tag(g, &"GEN")
	var genoa := Vector2i(8, 13)
	g.dev_money(&"GEN", 1000)
	var before_ducats := c.treasury
	var before_stock := c.stock.duplicate()
	assert_true(bool(g.act("upgrade", {"hex": genoa, "tag": &"GEN"})["ok"]))
	var work := g.state.work_at(genoa)
	assert_eq(work.paid, 1000)
	assert_eq(work.paid_goods, {"timber": 20, "stone": 40})
	assert_eq(c.treasury, before_ducats - 1000)
	assert_eq(c.stock[11], before_stock[11] - 20)
	assert_eq(c.stock[12], before_stock[12] - 40)
	assert_eq(Stores.flow(c, 12, &"work"), -40)
	var line := c.ledger_open[c.ledger_open.size() - 1]
	assert_eq([line["why"], line["hex"], line["amount"]], [&"work", genoa, -1000])
	assert_eq(Works.refund(g, work), 1000)
	assert_eq(Works.refund_goods(g, work), {"timber": 20, "stone": 40})
	g.events.clear()
	assert_true(bool(g.act("cancel_work", {"hex": genoa, "tag": &"GEN"})["ok"]))
	assert_eq(c.treasury, before_ducats)
	assert_eq(c.stock, before_stock)
	assert_eq(g.events[0]["refund"], 1000)
	assert_eq(Stores.flow(c, 12, &"refund"), 40)
	# Cancelled in a later season: nothing comes back, and a lost or blocked work gives nothing.
	assert_true(bool(g.act("upgrade", {"hex": genoa, "tag": &"GEN"})["ok"]))
	var paid_ducats := c.treasury
	Season.run(g)
	var later := g.state.work_at(genoa)
	assert_eq(Works.refund(g, later), 0)
	assert_eq(Works.refund_goods(g, later), {})
	var after_season := c.treasury
	g.act("cancel_work", {"hex": genoa, "tag": &"GEN"})
	assert_eq(c.treasury, after_season, "nothing back in a later season")
	assert_lt(paid_ducats, before_ducats)


func test_a_lost_work_gives_nothing_back() -> void:
	var g := _genoa()
	var c := Countries.by_tag(g, &"GEN")
	var hex := Vector2i(10, 13)
	assert_true(bool(g.act("build", {"hex": hex, "family": ImproveRules.TIMBER, "tag": &"GEN"})["ok"]), "timber camp")
	var after := c.treasury
	g.dev_transfer([hex], 0)
	g.events.clear()
	Works.season(g)
	assert_eq(g.events[0]["why"], &"lost")
	assert_eq(g.events[0]["refund"], 0)
	assert_eq(c.treasury, after, "M3 D13: nothing back")


func test_a_free_clearing_needs_no_money_at_a_negative_treasury() -> void:
	var g := _genoa()
	var c := Countries.by_tag(g, &"GEN")
	assert_true(g.dev_money(&"GEN", -2000))
	assert_lt(c.treasury, 0)
	var olives := Vector2i(7, 14)
	assert_true(bool(g.check("clear", {"hex": olives, "tag": &"GEN"})["ok"]), "0 ducats: no can_pay check")
	assert_true(bool(g.act("clear", {"hex": olives, "tag": &"GEN"})["ok"]))
	assert_false(bool(g.check("build", {"hex": Vector2i(10, 13), "family": ImproveRules.TIMBER, "tag": &"GEN"})["ok"]))
