## The barracks as data and state (docs/design/recruitment-queue.md sections 3, 4.1, 5.2 and 6; task RQ1): the numbers of
## decision 20, the 13 barracks of 1480, a scenario that lists none, the developer's barracks, its replay, save and load
## byte-equal and damaged bodies refused.
extends GutTest

## Section 3, in the countries' order: [tag, settlement, hex, the settlement's level at the start].
const START: Array = [
	[&"FRA", "Fréjus", Vector2i(1, 17), 2],
	[&"AUS", "Bolzano", Vector2i(15, 3), 3],
	[&"SWI", "Bern", Vector2i(5, 0), 2],
	[&"SAV", "Turin", Vector2i(5, 9), 3],
	[&"MLO", "Milan", Vector2i(9, 9), 5],
	[&"VEN", "Venice", Vector2i(18, 7), 5],
	[&"GEN", "Genoa", Vector2i(8, 13), 4],
	[&"TUS", "Florence", Vector2i(15, 15), 4],
	[&"PAP", "Bologna", Vector2i(16, 12), 4],
	[&"MAN", "Mantua", Vector2i(14, 10), 3],
	[&"FER", "Ferrara", Vector2i(16, 10), 4],
	[&"SIE", "Siena", Vector2i(16, 16), 2],
	[&"LUC", "Lucca", Vector2i(12, 15), 2],
]
const INFO := {"build": "0.3.0", "name": "Barracks", "saved_unix": 1700000000, "play_seconds": 5}

var _dirs: Array[String] = []


func after_each() -> void:
	for dir: String in _dirs:
		for file: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	_dirs.clear()


func _dir() -> String:
	var dir := "user://test_barracks_%d_%d" % [Time.get_ticks_usec(), _dirs.size()]
	_dirs.append(dir)
	return dir


## The hexes with a barracks, in hex index order.
func _held(game: Game) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in game.map.hex_count():
		if game.state.barracks[i] != 0:
			out.append(game.map.hex_of(i))
	return out


## The settlements with no barracks, in hex index order.
func _free_settlements(game: Game) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in game.map.hex_count():
		if int(game.state.main_use[i]) == ImproveRules.SETTLEMENT and game.state.barracks[i] == 0:
			out.append(game.map.hex_of(i))
	return out


## The first hex that is land (or sea) and holds no settlement.
func _bare_hex(game: Game, land: bool) -> Vector2i:
	for i: int in game.map.hex_count():
		if (game.map.land[i] != 0) == land and int(game.state.main_use[i]) != ImproveRules.SETTLEMENT:
			return game.map.hex_of(i)
	return ScenarioDef.NO_HEX


func _in_index_order(game: Game, hexes: Array[Vector2i]) -> Array[Vector2i]:
	var out := hexes.duplicate()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return game.map.index_of(a) < game.map.index_of(b))
	return out


func _start_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for row: Array in START:
		out.append(row[2] as Vector2i)
	return out


# ----- the numbers ----------------------------------------------------------------------------------------------------


func test_the_committed_numbers_are_those_of_decision_20() -> void:
	var defs := EconomyFixture.committed()
	var b := defs.barracks
	assert_not_null(b)
	assert_eq([b.cost, b.seasons, b.upkeep, b.min_level], [150, 4, 1, 3])
	assert_eq(b.cost_goods, {"timber": 10, "stone": 10} as Dictionary[String, int])
	assert_eq(b.validate(), [] as Array[String])
	assert_eq(defs.validate(), [] as Array[String])


func test_p_a_missing_or_damaged_barracks_def_is_refused() -> void:
	var defs := ScenarioFixture.build()["defs"] as GameDefs
	assert_eq(defs.validate(), [] as Array[String], "the fixture's defs hold a copy of the barracks")
	defs.barracks = null
	assert_eq(defs.validate(), ["barracks is not set"] as Array[String])
	var bad := BarracksDef.new()
	bad.cost = -1
	bad.upkeep = -2
	bad.seasons = 0
	bad.min_level = 6
	bad.cost_goods = {"timber": 0, "gold": 3}
	defs.barracks = bad
	assert_eq(defs.validate(), [
		"barracks: cost is -1, expected 0 or more",
		"barracks: upkeep is -2, expected 0 or more",
		"barracks: seasons is 0, expected 1 to 64",
		"barracks: min_level is 6, expected 1 to 5",
		"barracks: cost_goods timber is 0, expected 1 or more",
		"barracks: cost_goods names unknown good 'gold'",
	] as Array[String])


# ----- the start ------------------------------------------------------------------------------------------------------


func test_a_new_1480_game_has_13_barracks_at_the_hexes_of_section_3() -> void:
	var g := EconomyFixture.game()
	assert_eq(g.scenario.barracks, _start_hexes(), "the scenario lists them, in the countries' order")
	assert_eq(g.scenario.validate(g.map, g.defs, false), [] as Array[String])
	assert_eq(_held(g), _in_index_order(g, _start_hexes()), "13 barracks and no other")
	var got: Array = []
	var want: Array = []
	for row: Array in START:
		var hex: Vector2i = row[2]
		var i := g.map.index_of(hex)
		got.append([Territory.owner_tag(g, hex), int(g.state.main_use[i]), int(g.state.level[i]),
			Recruiting.has_barracks(g, hex)])
		want.append([row[0], ImproveRules.SETTLEMENT, row[3], true])
	assert_eq(got, want, "one a country, on its own settlement; villages too (decisions 17 and 18)")
	assert_eq(_free_settlements(g).size(), 71 - 13, "the other settlements have none")


func test_another_seed_has_the_same_barracks() -> void:
	var g := EconomyFixture.game(&"", false, true, 7)
	assert_eq(_held(g), _in_index_order(g, _start_hexes()))


func test_a_scenario_that_lists_none_gives_each_capital_on_the_map_one() -> void:
	var g := ScenarioFixture.game()
	assert_true(g.scenario.barracks.is_empty())
	assert_eq(_held(g), [ScenarioFixture.ALPHA_CAPITAL, ScenarioFixture.BETA_CAPITAL] as Array[Vector2i],
		"the third country's capital is off the map")


func test_a_listed_barracks_replaces_the_capitals() -> void:
	var f := ScenarioFixture.build()
	var scen := f["scenario"] as ScenarioDef
	scen.barracks = [ScenarioFixture.BETA_CAPITAL] as Array[Vector2i]
	var g := Game.new_scenario(f["map"] as MapData, f["defs"] as GameDefs, scen, 1480)
	assert_eq(_held(g), [ScenarioFixture.BETA_CAPITAL] as Array[Vector2i])


func test_a_map_only_game_has_none() -> void:
	var f := ScenarioFixture.build()
	var g := Game.new_game(f["map"] as MapData, 7, f["defs"] as GameDefs)
	assert_eq(g.state.barracks.size(), g.map.hex_count())
	assert_eq(_held(g), [] as Array[Vector2i])


func test_p_the_scenario_refuses_a_wrong_barracks_list() -> void:
	var f := ScenarioFixture.build()
	var m := f["map"] as MapData
	var defs := f["defs"] as GameDefs
	var s := f["scenario"] as ScenarioDef
	var base := s.digest()
	var alpha := ScenarioFixture.ALPHA_CAPITAL
	s.barracks = [alpha] as Array[Vector2i]
	assert_eq(s.validate(m, defs, false), [] as Array[String])
	assert_ne(s.digest(), base, "barracks are in the digest")
	s.barracks = [ScenarioFixture.SEA_HEX, Vector2i(3, 3), ScenarioDef.NO_HEX, alpha, alpha] as Array[Vector2i]
	assert_eq(s.validate(m, defs, false), [
		"barracks[0]: hex (2, 6) holds no settlement",
		"barracks[1]: hex (3, 3) holds no settlement",
		"barracks[2]: hex (-1, -1) holds no settlement",
		"barracks[4]: hex (1, 2) listed twice",
	] as Array[String])
	s.barracks = [alpha] as Array[Vector2i]
	s.owner[m.index_of(alpha)] = 0
	assert_has(s.validate(m, defs, false), "barracks[0]: hex (1, 2) is owned by no one")


func test_the_scenario_builder_keeps_the_barracks_list() -> void:
	var f := ScenarioFixture.build()
	var s := f["scenario"] as ScenarioDef
	s.barracks = [ScenarioFixture.BETA_CAPITAL] as Array[Vector2i]
	var builder := load("res://tools/build_scenario.gd") as GDScript
	builder.call("rebuild_scenario", s, f["map"] as MapData)
	assert_eq(s.barracks, [ScenarioFixture.BETA_CAPITAL] as Array[Vector2i])


# ----- the state ------------------------------------------------------------------------------------------------------


func test_the_map_state_copies_digests_and_reads_the_barracks() -> void:
	var g := ScenarioFixture.game()
	var s := g.state
	var d := s.to_dict()
	assert_eq(d["schema"], "hexa-godot/map-state/6")
	var back := MapState.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary, g.map)
	assert_not_null(back)
	assert_eq(back.barracks, s.barracks)
	assert_eq(back.digest(), s.digest())
	var copy := s.duplicate_state()
	assert_eq(copy.barracks, s.barracks)
	copy.barracks[g.map.index_of(ScenarioFixture.ALPHA_CAPITAL)] = 0
	assert_ne(copy.digest(), s.digest(), "the digest moves with one barracks")
	assert_true(Recruiting.has_barracks(g, ScenarioFixture.ALPHA_CAPITAL), "a copy is independent")
	var v5 := d.duplicate(true)
	v5["schema"] = MapState.SCHEMA_V5
	v5.erase("barracks")
	var old := MapState.from_dict(v5, g.map)
	assert_not_null(old, "schema 5 is still read")
	assert_eq(old.barracks.size(), g.map.hex_count())
	assert_eq(old.barracks.count(0), g.map.hex_count(), "with no barracks")
	assert_eq(old.to_dict()["schema"], MapState.SCHEMA)


func test_p_the_map_state_refuses_damaged_barracks() -> void:
	var g := ScenarioFixture.game()
	var m := g.map
	var wrong: Array[String] = []
	var cases := {"missing": null, "a number": 3, "the wrong size": Marshalls.raw_to_base64(PackedByteArray([1, 0, 1])),
		"a 2": _with_byte(g, ScenarioFixture.ALPHA_CAPITAL, 2), "at sea": _with_byte(g, ScenarioFixture.SEA_HEX, 1)}
	for label: String in cases:
		var d := g.state.to_dict()
		if cases[label] == null:
			d.erase("barracks")
		else:
			d["barracks"] = cases[label]
		if MapState.from_dict(d, m) != null:
			wrong.append(label)
	assert_eq(wrong, [] as Array[String], "damaged barracks that load")


## The barracks text of a state with one byte changed.
func _with_byte(game: Game, hex: Vector2i, value: int) -> String:
	var bytes := game.state.barracks.duplicate()
	bytes[game.map.index_of(hex)] = value
	return Marshalls.raw_to_base64(bytes)


# ----- dev_barracks ---------------------------------------------------------------------------------------------------


func test_dev_barracks_puts_one_logs_it_and_moves_the_digest() -> void:
	var g := EconomyFixture.game(&"GEN")
	var village := _free_settlements(g)[0]
	var before := g.digest()
	var version := g.version
	assert_true(g.dev_barracks(village))
	assert_true(Recruiting.has_barracks(g, village))
	assert_eq(_held(g).size(), 14)
	assert_eq(g.action_log.back(), {"turn": g.turn, "action": "dev_barracks", "args": {"hex": village}})
	assert_eq(g.version, version + 1)
	assert_ne(g.digest(), before)


func test_dev_barracks_changes_nothing_when_refused() -> void:
	var g := EconomyFixture.game(&"GEN")
	var before := g.digest()
	var records := g.action_log.size()
	var version := g.version
	var accepted: Array[Vector2i] = []
	for hex: Vector2i in [_start_hexes()[0], _bare_hex(g, true), _bare_hex(g, false), ScenarioDef.NO_HEX,
			Vector2i(999, 999)]:
		if g.dev_barracks(hex):
			accepted.append(hex)
	assert_eq(accepted, [] as Array[Vector2i], "one there already, bare land, sea, off the map")
	assert_eq([g.digest(), g.action_log.size(), g.version], [before, records, version])
	var sandbox := Game.new_game(g.map, 7, g.defs)
	var settlement := _free_settlements(sandbox)[0]
	assert_false(sandbox.dev_barracks(settlement), "a map-only game")
	assert_true(sandbox.action_log.is_empty())
	assert_eq(_held(sandbox), [] as Array[Vector2i])


# ----- replay, save and load ------------------------------------------------------------------------------------------


## Genoa's game with two developer barracks, a season apart.
func _played() -> Game:
	var g := EconomyFixture.game(&"GEN")
	var free := _free_settlements(g)
	assert_true(g.dev_barracks(free[0]))
	Season.run(g)
	assert_true(g.dev_barracks(free[1]))
	Season.run(g)
	return g


func test_replay_gives_the_same_barracks_and_digest() -> void:
	var g := _played()
	var again := Replay.run(g.map, g.defs, g.scenario.id, g.seed_value, g.action_log)
	assert_not_null(again)
	assert_eq(_held(again), _held(g))
	assert_eq(again.digest(), g.digest())


func test_p_a_changed_dev_barracks_record_gives_another_digest() -> void:
	var g := _played()
	var other := _free_settlements(g)[0]
	var log: Array[Dictionary] = []
	var changed := false
	for r: Dictionary in g.action_log:
		var record := r.duplicate(true)
		if not changed and record["action"] == "dev_barracks":
			(record["args"] as Dictionary)["hex"] = other
			changed = true
		log.append(record)
	assert_true(changed)
	var again := Replay.run(g.map, g.defs, g.scenario.id, g.seed_value, log)
	assert_ne(again.digest(), g.digest())


func test_save_load_save_is_byte_equal_with_barracks() -> void:
	var g := _played()
	var dir_a := _dir()
	assert_eq(SaveFile.write(g, "2", INFO, {}, dir_a), "")
	var read := SaveFile.read("2", dir_a)
	assert_eq(read["problem"], "")
	assert_eq((read["header"] as Dictionary)["format"], 9)
	var r := Snapshot.restore(read["body"] as Dictionary, g.map, g.defs)
	assert_eq(r["problem"], "")
	var back := r["game"] as Game
	assert_eq(_held(back), _held(g))
	assert_eq(_held(back).size(), 15)
	assert_eq(back.digest(), g.digest())
	var dir_b := _dir()
	assert_eq(SaveFile.write(back, "2", INFO, {}, dir_b), "")
	assert_true(FileAccess.get_file_as_bytes(SaveFile.path_of("2", dir_a))
		== FileAccess.get_file_as_bytes(SaveFile.path_of("2", dir_b)), "byte-equal files")


func test_p_a_damaged_barracks_body_is_refused_and_the_game_in_hand_is_untouched() -> void:
	var g := EconomyFixture.game(&"GEN")
	var live := g.digest()
	var bytes := var_to_bytes(Snapshot.of(g))
	assert_eq(Snapshot.restore(bytes_to_var(bytes) as Dictionary, g.map, g.defs)["problem"], "", "the sound body loads")
	var cases := {"missing": null, "a number": 3, "not base64": "!!!!", "empty": "",
		"the wrong size": Marshalls.raw_to_base64(PackedByteArray([1, 0, 1])),
		"a 2": _with_byte(g, _start_hexes()[0], 2), "at sea": _with_byte(g, _bare_hex(g, false), 1),
		"on land with no settlement": _with_byte(g, _bare_hex(g, true), 1)}
	var wrong: Array[String] = []
	for label: String in cases:
		var body := bytes_to_var(bytes) as Dictionary
		var state := body["map_state"] as Dictionary
		if cases[label] == null:
			state.erase("barracks")
		else:
			state["barracks"] = cases[label]
		var r := Snapshot.restore(body, g.map, g.defs)
		if r["game"] != null or r["problem"] != Snapshot.PROBLEM_UNREADABLE:
			wrong.append("%s: '%s'" % [label, r["problem"]])
	assert_eq(wrong, [] as Array[String], "damaged barracks bodies that are not refused")
	assert_eq(g.digest(), live)
