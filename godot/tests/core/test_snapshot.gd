## Snapshot (docs/architecture/m3-build-spec.md 4.10, 5.4, 9): of and restore keep the digest for a sandbox, a scenario
## before the pick and a scenario after 12 seasons with works; every key of 4.10; the M2 5.9 fields; the planted faults.
extends GutTest

const KEYS: Array[String] = ["format", "game", "map_state", "countries", "stats", "chronicle", "luck", "action_log", "ui"]

var _fx: Dictionary = {}


func before_each() -> void:
	_fx = ScenarioFixture.build()


func _scenario_game() -> Game:
	return Game.new_scenario(_fx["map"] as MapData, _fx["defs"] as GameDefs, _fx["scenario"] as ScenarioDef, 1480)


func _sandbox_game() -> Game:
	return Game.new_game(_fx["map"] as MapData, 7, _fx["defs"] as GameDefs)


## The body through the bytes, as a file would carry it.
func _through_bytes(body: Dictionary) -> Dictionary:
	return bytes_to_var(var_to_bytes(body)) as Dictionary


func _restore(body: Dictionary) -> Dictionary:
	return Snapshot.restore(body, _fx["map"] as MapData, _fx["defs"] as GameDefs)


func _played_game() -> Game:
	var g := _scenario_game()
	for hex: Vector2i in [Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)]:
		g.improvement.clear(hex)
	assert_true(bool(g.act("choose_country", {"tag": &"AAA"})["ok"]))
	var built := 0
	for n: int in 12:
		if built < 3:
			var hex := Vector2i(0, 2 + built)
			if bool(g.act("build", {"hex": hex, "family": ImproveRules.WHEAT, "tag": &"AAA"})["ok"]):
				built += 1
		Season.run(g)
	assert_gt(built, 0, "some work was begun")
	assert_gt(g.chronicle.entries.size(), 0)
	assert_gt(g.action_log.size(), 12)
	return g


func test_every_key_of_the_body_is_there() -> void:
	var body := Snapshot.of(_scenario_game(), {"camera": {"zoom": 1.5}})
	for key: String in KEYS:
		assert_true(body.has(key), key)
	assert_eq(body.size(), KEYS.size())
	assert_eq(body["format"], SaveFile.FORMAT)
	var meta := body["game"] as Dictionary
	for key: String in ["map_id", "scenario_id", "seed", "start_year", "turn", "player"]:
		assert_true(meta.has(key), key)
	assert_eq((body["ui"] as Dictionary)["camera"], {"zoom": 1.5})


func test_sandbox_keeps_the_digest() -> void:
	var g := _sandbox_game()
	Season.run(g)
	var r := _restore(_through_bytes(Snapshot.of(g)))
	assert_eq(r["problem"], "")
	var back := r["game"] as Game
	assert_eq(back.digest(), g.digest())
	assert_null(back.scenario)
	assert_eq(back.countries.size(), 0)


func test_scenario_before_the_pick_keeps_the_digest() -> void:
	var g := _scenario_game()
	var back := _restore(_through_bytes(Snapshot.of(g)))["game"] as Game
	assert_eq(back.digest(), g.digest())
	assert_eq(back.player, &"")
	assert_eq(back.scenario, g.scenario)


func test_twelve_seasons_with_works_keep_the_digest_and_each_field() -> void:
	var g := _played_game()
	var r := _restore(_through_bytes(Snapshot.of(g, {"look": "season"})))
	assert_eq(r["problem"], "")
	var back := r["game"] as Game
	assert_eq(back.digest(), g.digest())
	# The M2 5.9 fields.
	assert_eq(back.player, &"AAA")
	assert_eq(back.state.owner, g.state.owner)
	assert_eq(back.countries.size(), g.countries.size())
	for i: int in g.countries.size():
		assert_eq(back.countries[i].digest_text(), g.countries[i].digest_text())
	assert_eq(back.turn, g.turn)
	assert_eq(back.start_year, g.start_year)
	assert_eq(back.action_log, g.action_log)
	assert_eq(back.chronicle.entries, g.chronicle.entries)
	assert_eq(back.stats.digest(), g.stats.digest())
	assert_eq(back.luck.digest_text(), g.luck.digest_text())
	assert_eq(back.state.works.size(), g.state.works.size())
	assert_eq(r["ui"], {"look": "season"})
	# The restored game plays on like the original.
	Season.run(g)
	Season.run(back)
	assert_eq(back.digest(), g.digest(), "play on")


func test_the_body_of_a_restored_game_is_the_same_body() -> void:
	var g := _played_game()
	var body := Snapshot.of(g)
	var back := _restore(_through_bytes(body))["game"] as Game
	assert_eq(var_to_bytes(Snapshot.of(back)), var_to_bytes(body), "bytes equal")


# ----- planted faults -------------------------------------------------------------------------------------------


func _body() -> Dictionary:
	return _through_bytes(Snapshot.of(_played_game()))


func _refused(body: Dictionary, words: String, label: String) -> void:
	var r := _restore(body)
	assert_null(r["game"], label)
	assert_eq(r["problem"], words, label)


func test_p_wrong_format() -> void:
	var newer := _body()
	newer["format"] = SaveFile.FORMAT + 1
	_refused(newer, "Made by a newer Hexa", "newer")
	var older := _body()
	older["format"] = SaveFile.OLDEST_FORMAT - 1
	_refused(older, "Made by an older test build", "older")
	var odd := _body()
	odd["format"] = "1"
	_refused(odd, "Cannot be read", "a string")


func test_p_missing_pieces() -> void:
	for key: String in KEYS:
		if key == "format":
			continue
		var body := _body()
		body.erase(key)
		_refused(body, "Cannot be read", "no " + key)


func test_p_wrong_map_size() -> void:
	var body := _body()
	var other := ImproveFixture.block(4, 4, {})
	var r := Snapshot.restore(body, other, _fx["defs"] as GameDefs)
	assert_null(r["game"])
	assert_eq(r["problem"], "Made for another map")
	other.id = "scenario_fixture"
	r = Snapshot.restore(body, other, _fx["defs"] as GameDefs)
	assert_null(r["game"])
	assert_eq(r["problem"], "Made for another map", "same id, other size")


func test_p_unknown_scenario_and_changed_scenario() -> void:
	var body := _body()
	(body["game"] as Dictionary)["scenario_id"] = "no_such_scenario"
	_refused(body, "Made by another build", "unknown")
	var changed := _body()
	(changed["game"] as Dictionary)["scenario_digest"] = "0000"
	_refused(changed, "Made by another build", "digest differs")
	var defs := _fx["defs"] as GameDefs
	var scenario := defs.scenarios[0]
	var good := _body()
	scenario.year += 1
	assert_null(Snapshot.restore(good, _fx["map"] as MapData, defs)["game"], "the scenario changed under the save")


func test_p_mistyped_values() -> void:
	var cases: Array[Array] = [
		["game", "turn", "9"], ["game", "seed", 1.5], ["game", "player", 5], ["game", "map_id", 3],
		["game", "start_year", "1480"], ["game", "turn", 0],
	]
	for item: Array in cases:
		var body := _body()
		(body[item[0]] as Dictionary)[item[1]] = item[2]
		_refused(body, "Cannot be read", str(item))
	var strings: Array[String] = ["map_state", "chronicle", "luck", "stats", "ui"]
	for key: String in strings:
		var body := _body()
		body[key] = "text"
		_refused(body, "Cannot be read", key)
	var arrays := _body()
	arrays["countries"] = {}
	_refused(arrays, "Cannot be read", "countries")
	var log := _body()
	(log["action_log"] as Array)[0] = {"turn": "1", "action": "build", "args": {}}
	_refused(log, "Cannot be read", "log record")
	var luck := _body()
	(luck["luck"] as Dictionary)["ai"] = "x"
	_refused(luck, "Cannot be read", "luck")
	var stats := _body()
	(stats["stats"] as Dictionary)["ring"] = [1, 2]
	_refused(stats, "Cannot be read", "stats")
	var player := _body()
	(player["game"] as Dictionary)["player"] = "ZZZ"
	_refused(player, "Cannot be read", "a player who is no country")
	var count := _body()
	(count["countries"] as Array).pop_back()
	_refused(count, "Cannot be read", "a country missing")
	var work := _body()
	var state := work["map_state"] as Dictionary
	state["works"] = [{"schema": Work.SCHEMA, "seasons_left": "x"}]
	_refused(work, "Cannot be read", "a damaged work")


# ----- crafted bodies (the sha passes, the values are hostile) -------------------------------------------------


## Edits one of the map state's byte arrays through its base64 text.
func _edit_bytes(body: Dictionary, key: String, change: Callable) -> void:
	var state := body["map_state"] as Dictionary
	var raw := Marshalls.base64_to_raw(str(state[key]))
	change.call(raw)
	state[key] = Marshalls.raw_to_base64(raw)


func test_p_crafted_map_state_arrays() -> void:
	for key: String in ["main_use", "level", "owner"]:
		for bad: Variant in [5, [1], {"a": 1}, "!!!!", "AA=A", "ab", Marshalls.raw_to_base64(PackedByteArray([1, 2, 3])).left(3)]:
			var body := _body()
			(body["map_state"] as Dictionary)[key] = bad
			_refused(body, "Cannot be read", "%s = %s" % [key, str(bad)])
		var short := _body()
		(short["map_state"] as Dictionary)[key] = Marshalls.raw_to_base64(PackedByteArray([1, 2, 3]))
		_refused(short, "Made for another map", key + " of the wrong size")
	var size := _body()
	(size["map_state"] as Dictionary)["size"] = {"x": 1}
	_refused(size, "Cannot be read", "size is a dictionary")


func test_p_crafted_countries() -> void:
	var cases: Array[Array] = [
		["id", [1]], ["id", "1"], ["alive", {"a": 1}], ["alive", 1], ["capital", [Vector2i(1, 1), 2]],
		["capital", [[1], 2]], ["capital", Vector2i(1, 2)], ["capital", [1, 2, 3]], ["capital", "x"], ["tag", 4],
		["tag", ["AAA"]],
	]
	for item: Array in cases:
		var body := _body()
		((body["countries"] as Array)[0] as Dictionary)[item[0]] = item[1]
		_refused(body, "Cannot be read", str(item))


func _set_hex(body: Dictionary, key: String, hex: Vector2i, value: int) -> void:
	var i := (_fx["map"] as MapData).index_of(hex)
	_edit_bytes(body, key, func(raw: PackedByteArray) -> void: raw[i] = value)


func test_p_crafted_ranges() -> void:
	var land := Vector2i(0, 2)
	var sea := ScenarioFixture.SEA_HEX
	var cases: Array[Array] = [
		["a family past the last", "main_use", land, FamilyIds.COUNT],
		["a level past the top", "level", land, 6],
		["an owner past the countries", "owner", land, 4],
		["a use on the sea", "main_use", sea, ImproveRules.WHEAT],
		["a level on the sea", "level", sea, 1],
		["an owner on the sea", "owner", sea, 1],
	]
	for item: Array in cases:
		var body := _body()
		_set_hex(body, item[1] as String, item[2] as Vector2i, int(item[3]))
		_refused(body, "Cannot be read", item[0] as String)
	var wild := _body()
	_set_hex(wild, "main_use", land, 0)
	_set_hex(wild, "level", land, 1)
	_refused(wild, "Cannot be read", "a level over a wild hex")
	var top := _body()
	_set_hex(top, "main_use", land, ImproveRules.WHEAT)
	_set_hex(top, "level", land, 4)
	_refused(top, "Cannot be read", "wheat has three levels")
