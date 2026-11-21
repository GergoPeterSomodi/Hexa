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


# ----- M4: the weather and the economy fields (m4-build-spec.md 4.22) -------------------------------------------


## A scenario game whose weather is never calm, with the player chosen and a few seasons played.
func _stormy_game() -> Game:
	var d := (_fx["defs"] as GameDefs).duplicate() as GameDefs
	d.weather_odds = PackedInt32Array([0, 50, 50])
	var g := Game.new_scenario(_fx["map"] as MapData, d, _fx["scenario"] as ScenarioDef, 1480)
	g.act("choose_country", {"tag": &"AAA"})
	for n: int in 5:
		Season.run(g)
	return g


func test_the_weather_is_saved_and_a_loaded_game_plays_on_alike() -> void:
	var g := _stormy_game()
	assert_ne(g.weather, PackedByteArray([0, 0, 0]), "the weather is not calm")
	var body := _through_bytes(Snapshot.of(g))
	assert_eq((body["game"] as Dictionary)["weather"], g.weather)
	var r := Snapshot.restore(body, _fx["map"] as MapData, g.defs)
	assert_eq(r["problem"], "")
	var back := r["game"] as Game
	assert_eq(back.weather, g.weather)
	assert_eq(back.digest(), g.digest())
	Season.run(g)
	Season.run(back)
	assert_eq(back.weather, g.weather, "the next weather")
	assert_eq(back.digest(), g.digest(), "the first production after the load")
	assert_eq(back.countries[0].treasury, g.countries[0].treasury)


func test_a_save_without_weather_is_calm() -> void:
	var body := _body()
	(body["game"] as Dictionary).erase("weather")
	var r := _restore(body)
	assert_eq(r["problem"], "")
	assert_eq((r["game"] as Game).weather, PackedByteArray([0, 0, 0]))


func test_p_mistyped_weather() -> void:
	var bad: Array = [PackedByteArray([0, 0]), PackedByteArray([0, 3, 0]), PackedByteArray([0, 0, 0, 0]), "012", 5,
			[0, 1], [0, 1, 3], [0, 1, "2"], [0, -1, 0], {"a": 1}, PackedInt32Array([0, 1, 2])]
	for value: Variant in bad:
		var body := _body()
		(body["game"] as Dictionary)["weather"] = value
		_refused(body, "Cannot be read", "weather " + str(value))


func test_the_economy_fields_survive_the_body() -> void:
	var g := _played_game()
	var c := g.countries[0]
	assert_ne(c.ledger_closed, {}, "a closed ledger to keep")
	var back := _restore(_through_bytes(Snapshot.of(g)))["game"] as Game
	var d := back.countries[0]
	assert_eq(d.treasury, c.treasury)
	assert_eq(d.tax, c.tax)
	assert_eq(d.short_mask, c.short_mask)
	assert_eq(d.stock, c.stock)
	assert_eq(d.flows_open, c.flows_open)
	assert_eq(d.stock_from, c.stock_from)
	assert_eq(d.ledger_open, c.ledger_open)
	assert_eq(d.ledger_closed, c.ledger_closed)
	assert_eq(d.goods_closed, c.goods_closed)
	assert_eq(back.state.digest(), g.state.digest(), "works with paid_goods")
	assert_eq(back.stats.digest(), g.stats.digest())


func test_p_old_and_damaged_economy_fields() -> void:
	var old := _body()
	old["format"] = 1
	_refused(old, "Made by an older test build", "format 1")
	var one := _body()
	((one["countries"] as Array)[0] as Dictionary)["schema"] = "hexa-godot/country/1"
	_refused(one, "Cannot be read", "country/1")
	var cases: Array[Array] = [
		["treasury", "40"], ["treasury", [1]], ["treasury", 1.5], ["treasury", true], ["tax", 3], ["tax", "x"],
		["short_mask", -1], ["short_mask", {}], ["stock", "x"], ["stock", [1, "a"]], ["stock", PackedInt32Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36])],
		["stock_from", ["a"]], ["flows_open", [1, 2, 3]], ["flows_shape", "x"],
		["ledger_from", "x"], ["ledger_open", "x"], ["ledger_open", ["x"]],
		["ledger_open", [{"why": "tax", "hex": [1, 2], "amount": "ten", "count": 1}]],
		["ledger_open", [{"why": 5, "hex": [1, 2], "amount": 1, "count": 1}]],
		["ledger_open", [{"why": "tax", "hex": [1], "amount": 1, "count": 1}]],
		["ledger_closed", "x"], ["ledger_closed", {"turn": 1}], ["goods_closed", "x"], ["goods_closed", {"turn": "a"}],
	]
	for item: Array in cases:
		var body := _body()
		((body["countries"] as Array)[0] as Dictionary)[item[0]] = item[1]
		var r := _restore(body)
		assert_null(r["game"], str(item))
		assert_eq(r["problem"], "Cannot be read", str(item))



# ----- M5: the people (m5-build-spec.md 4.18, 5.0 A4) ---------------------------------------------------------------------


## A game whose people really changed: growth for a few seasons and a developer change in the log.
func _people_game() -> Game:
	var g := PeopleFixture.genoa()
	assert_true(g.dev_people(Vector2i(6, 13), 2100))
	for _n: int in 3:
		Season.run(g)
	return g


func _people_body() -> Dictionary:
	var g := _people_game()
	_people_map = g.map
	_people_defs = g.defs
	return _through_bytes(Snapshot.of(g))


var _people_map: MapData = null
var _people_defs: GameDefs = null


func _people_refused(body: Dictionary, label: String) -> void:
	var r := Snapshot.restore(body, _people_map, _people_defs)
	assert_null(r["game"], label)
	assert_eq(r["problem"], "Cannot be read", label)


func test_the_people_fields_round_trip() -> void:
	var g := _people_game()
	var back := Snapshot.restore(_through_bytes(Snapshot.of(g)), g.map, g.defs)
	assert_eq(back["problem"], "")
	var h := back["game"] as Game
	assert_eq(h.digest(), g.digest())
	assert_eq(h.state.people, g.state.people)
	assert_eq(h.state.people_start, g.state.people_start)
	assert_eq(h.state.people_end, g.state.people_end)
	assert_ne(h.state.people_end, h.state.people_start, "the people moved")
	var gen := Countries.by_tag(g, &"GEN")
	var hen := Countries.by_tag(h, &"GEN")
	assert_eq(hen.people_closed, gen.people_closed)
	assert_eq(hen.food_need, gen.food_need)
	assert_eq(hen.food_fed, gen.food_fed)
	assert_eq(var_to_bytes(Snapshot.of(h)), var_to_bytes(Snapshot.of(g)), "the same body")
	Season.run(g)
	Season.run(h)
	assert_eq(h.digest(), g.digest(), "play on")


func test_p_damaged_people_fields_are_refused() -> void:
	var state_cases: Array[Array] = [
		["people", "text"], ["people", PackedInt32Array([1, 2, 3])], ["people_start", [1, 2]],
		["people_end", PackedByteArray([1, 2])], ["people", null],
	]
	for item: Array in state_cases:
		var body := _people_body()
		(body["map_state"] as Dictionary)[item[0]] = item[1]
		_people_refused(body, str(item))
	var country_cases: Array[Array] = [
		["food_need", "4"], ["food_need", 1.5], ["food_fed", "x"], ["food_fed", 1001], ["people_flows", "x"],
		["people_flows", [1, 2]], ["people_closed", "x"], ["people_closed", {"turn": 1, "flows": "x"}],
	]
	for item: Array in country_cases:
		var body := _people_body()
		((body["countries"] as Array)[0] as Dictionary)[item[0]] = item[1]
		_people_refused(body, str(item))


## The body with one value of a people array of the map state changed (a packed array is a value: it is put back).
func _poked(key: String, at: int, value: int) -> Dictionary:
	var body := _people_body()
	var ints := (body["map_state"] as Dictionary)[key] as PackedInt32Array
	ints[at] = value
	(body["map_state"] as Dictionary)[key] = ints
	return body


func test_p_people_out_of_range_or_at_sea_are_refused() -> void:
	var sea := -1
	var land := -1
	var g := _people_game()
	for i: int in g.map.hex_count():
		if g.map.land[i] == 0 and sea < 0:
			sea = i
		elif g.map.land[i] == 1 and land < 0:
			land = i
	for key: String in ["people", "people_start", "people_end"]:
		_people_refused(_poked(key, sea, 1), key + " at sea")
		_people_refused(_poked(key, land, People.PEOPLE_MAX + 1), key + " over the maximum")
		_people_refused(_poked(key, land, -1), key + " below zero")
