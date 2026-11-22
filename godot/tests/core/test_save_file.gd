## SaveFile (docs/architecture/m3-build-spec.md 4.10, 5.4, 9, 10): the header, save-load-save byte-equal, the states of a
## slot, the write sequence and its leftovers, the autosave slot, and that no damaged file crashes a read.
extends GutTest

const INFO := {"build": "0.3.0", "name": "Alpha, Spring 1480", "saved_unix": 1700000000, "play_seconds": 61}

var _fx: Dictionary = {}
var _dirs: Array[String] = []
var _count := 0


func before_each() -> void:
	_fx = ScenarioFixture.build()


func after_each() -> void:
	for dir: String in _dirs:
		for file: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		for sub: String in DirAccess.get_directories_at(dir):
			DirAccess.remove_absolute(dir.path_join(sub))
		DirAccess.remove_absolute(dir)
	_dirs.clear()


func _dir() -> String:
	_count += 1
	var dir := "user://test_saves_%d_%d/" % [Time.get_ticks_usec(), _count]
	dir = dir.trim_suffix("/")
	_dirs.append(dir)
	return dir


func _game() -> Game:
	var g := Game.new_scenario(_fx["map"] as MapData, _fx["defs"] as GameDefs, _fx["scenario"] as ScenarioDef, 1480)
	g.improvement.clear(Vector2i(0, 2))
	g.act("choose_country", {"tag": &"AAA"})
	g.act("build", {"hex": Vector2i(0, 2), "family": ImproveRules.WHEAT, "tag": &"AAA"})
	for n: int in 3:
		Season.run(g)
	return g


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func _put(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _saved(slot: String = "1", dir: String = "") -> String:
	var d := dir if not dir.is_empty() else _dir()
	assert_eq(SaveFile.write(_game(), slot, INFO, {"look": "x"}, d), "")
	return d


# ----- header ---------------------------------------------------------------------------------------------------


func test_header_keys() -> void:
	var dir := _saved()
	var info := SaveFile.read_header("1", dir)
	assert_eq(info["state"], &"ok")
	var h := info["header"] as Dictionary
	for key: String in ["hexa", "format", "build", "slot", "name", "map_id", "map_digest", "scenario_id",
			"scenario_digest", "tag", "country", "turn", "date", "saved_unix", "play_seconds", "body_bytes", "body_size",
			"body_sha256", "digest"]:
		assert_true(h.has(key), key)
	assert_eq(h["hexa"], "save")
	assert_eq(h["format"], SaveFile.FORMAT)
	assert_eq(h["slot"], "1")
	assert_eq(h["tag"], "AAA")
	assert_eq(h["country"], "Republic of Alpha")
	assert_eq(h["turn"], 4)
	assert_eq(h["date"], "Winter 1480")
	assert_eq(h["map_id"], "scenario_fixture")
	assert_eq(h["scenario_id"], "fixture_scenario")
	assert_eq(h["saved_unix"], 1700000000)
	assert_eq(h["digest"], _game().digest())
	assert_lt(_bytes(SaveFile.path_of("1", dir)).find(10), SaveFile.HEADER_MAX, "the header is under 4 KB")


func test_header_of_a_sandbox_and_before_the_pick() -> void:
	var sandbox := Game.new_game(_fx["map"] as MapData, 3, _fx["defs"] as GameDefs)
	var h := SaveFile.header_of(sandbox, "quick", INFO)
	assert_eq(h["tag"], "")
	assert_eq(h["country"], "Sandbox")
	assert_eq(h["scenario_id"], "")
	var fresh := Game.new_scenario(_fx["map"] as MapData, _fx["defs"] as GameDefs, _fx["scenario"] as ScenarioDef, 1)
	assert_eq(SaveFile.header_of(fresh, "quick", INFO)["country"], "")


# ----- the round trip -------------------------------------------------------------------------------------------


func test_save_load_save_is_byte_equal() -> void:
	var dir_a := _saved("3")
	var read := SaveFile.read("3", dir_a)
	assert_eq(read["problem"], "")
	var r := Snapshot.restore(read["body"] as Dictionary, _fx["map"] as MapData, _fx["defs"] as GameDefs)
	assert_eq(r["problem"], "")
	var back := r["game"] as Game
	assert_eq(back.digest(), (read["header"] as Dictionary)["digest"], "the digest the header names")
	var dir_b := _dir()
	assert_eq(SaveFile.write(back, "3", INFO, r["ui"] as Dictionary, dir_b), "")
	assert_eq(_bytes(SaveFile.path_of("3", dir_a)), _bytes(SaveFile.path_of("3", dir_b)), "byte-equal files")


func test_json_too_writes_a_readable_copy() -> void:
	var dir := _dir()
	assert_eq(SaveFile.write(_game(), "2", INFO, {}, dir, true), "")
	assert_true(FileAccess.file_exists(dir.path_join("2.body.json")))
	assert_true(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("2.body.json"))) is Dictionary)


func test_types_survive_the_bytes() -> void:
	var typed: Array[Dictionary] = [{"k": &"v"}]
	var value := {
		"sn": &"name", "v": Vector2i(3, 4), "typed": typed, "p32": PackedInt32Array([1, -2, 3]),
		"ps": PackedStringArray(["a", "b"]), "pb": PackedByteArray([1, 2, 3]), "nest": {"l": [&"q", Vector2i(1, 1)]},
		"big": 9007199254740993,
	}
	var bytes := var_to_bytes(value)
	var back: Dictionary = bytes_to_var(bytes.compress(FileAccess.COMPRESSION_ZSTD).decompress(bytes.size(),
		FileAccess.COMPRESSION_ZSTD))
	assert_eq(typeof(back["sn"]), TYPE_STRING_NAME)
	assert_eq(typeof(back["v"]), TYPE_VECTOR2I)
	assert_true(back["p32"] is PackedInt32Array)
	assert_true(back["ps"] is PackedStringArray)
	assert_eq(typeof((back["nest"] as Dictionary)["l"][0]), TYPE_STRING_NAME)
	assert_eq(back["big"], 9007199254740993)
	assert_eq(var_to_bytes(back), bytes, "the same bytes again")


# ----- the states of a slot -------------------------------------------------------------------------------------


func _with_header(dir: String, slot: String, change: Callable) -> void:
	var path := SaveFile.path_of(slot, dir)
	var bytes := _bytes(path)
	var end := bytes.find(10)
	var header: Dictionary = JSON.parse_string(bytes.slice(0, end).get_string_from_utf8())
	for key: String in header:
		if header[key] is float:
			header[key] = int(header[key])  # JSON gives floats; the writer writes whole numbers
	change.call(header)
	var line := (JSON.stringify(header) + "\n").to_utf8_buffer()
	line.append_array(bytes.slice(end + 1))
	_put(path, line)


func test_read_header_states() -> void:
	var dir := _dir()
	assert_eq(SaveFile.read_header("quick", dir)["state"], &"empty")
	assert_eq(SaveFile.read("quick", dir)["problem"], "Empty slot")
	_saved("quick", dir)
	assert_eq(SaveFile.read_header("quick", dir)["state"], &"ok")
	_with_header(dir, "quick", func(h: Dictionary) -> void: h["format"] = SaveFile.FORMAT + 1)
	assert_eq(SaveFile.read_header("quick", dir)["state"], &"newer")
	assert_eq(SaveFile.read("quick", dir)["problem"], "Made by a newer Hexa")
	_with_header(dir, "quick", func(h: Dictionary) -> void: h["format"] = SaveFile.OLDEST_FORMAT - 1)
	assert_eq(SaveFile.read_header("quick", dir)["state"], &"older")
	assert_eq(SaveFile.read("quick", dir)["problem"], "Made by an older test build")
	_put(SaveFile.path_of("quick", dir), "not a save\nat all".to_utf8_buffer())
	assert_eq(SaveFile.read_header("quick", dir)["state"], &"broken")
	assert_eq(SaveFile.read("quick", dir)["problem"], "Cannot be read")


func test_p_a_flipped_body_byte_is_broken() -> void:
	var dir := _saved("4")
	var path := SaveFile.path_of("4", dir)
	var bytes := _bytes(path)
	bytes[bytes.size() - 5] = bytes[bytes.size() - 5] ^ 0x40
	_put(path, bytes)
	assert_eq(SaveFile.read("4", dir)["problem"], "Cannot be read")


func test_p_a_truncated_file_is_broken() -> void:
	var dir := _saved("4")
	var path := SaveFile.path_of("4", dir)
	var bytes := _bytes(path)
	_put(path, bytes.slice(0, bytes.size() - 20))
	assert_eq(SaveFile.read_header("4", dir)["state"], &"broken")
	assert_eq(SaveFile.read("4", dir)["problem"], "Cannot be read")
	_put(path, bytes.slice(0, 30))
	assert_eq(SaveFile.read_header("4", dir)["state"], &"broken", "cut inside the header")


func test_bak_is_used_when_sav_is_missing_or_broken() -> void:
	var dir := _saved("5")
	var sav := SaveFile.path_of("5", dir)
	var digest := str((SaveFile.read_header("5", dir)["header"] as Dictionary)["digest"])
	DirAccess.rename_absolute(sav, sav + ".bak")
	assert_eq(SaveFile.read_header("5", dir)["state"], &"ok", "only a .bak")
	assert_eq(SaveFile.read("5", dir)["problem"], "")
	_put(sav, "garbage".to_utf8_buffer())
	assert_eq(SaveFile.read_header("5", dir)["state"], &"ok", "a broken .sav, a good .bak")
	var read := SaveFile.read("5", dir)
	assert_eq(read["problem"], "")
	assert_eq((read["header"] as Dictionary)["digest"], digest)


func test_a_left_tmp_is_ignored() -> void:
	var dir := _dir()
	DirAccess.make_dir_recursive_absolute(dir)
	_put(SaveFile.path_of("6", dir) + ".tmp", "half".to_utf8_buffer())
	assert_eq(SaveFile.read_header("6", dir)["state"], &"empty")
	_saved("6", dir)
	assert_eq(SaveFile.read("6", dir)["problem"], "")


# ----- the write sequence ---------------------------------------------------------------------------------------


func test_writing_over_a_save_leaves_no_tmp_or_bak() -> void:
	var dir := _saved("7")
	var first := _bytes(SaveFile.path_of("7", dir))
	assert_eq(SaveFile.write(_game(), "7", INFO, {"look": "x"}, dir), "")
	assert_eq(_bytes(SaveFile.path_of("7", dir)), first)
	var files := DirAccess.get_files_at(dir)
	assert_eq(files.size(), 1, str(files))
	assert_eq(files[0], "7.sav")


func test_leftovers_of_a_crash_at_each_step_do_not_stop_a_write() -> void:
	# A stale .bak and a stale .tmp (a crash after steps 1 and 2): the next write succeeds and cleans up.
	var dir := _saved("8")
	var sav := SaveFile.path_of("8", dir)
	_put(sav + ".tmp", "half".to_utf8_buffer())
	_put(sav + ".bak", "old".to_utf8_buffer())
	assert_eq(SaveFile.write(_game(), "8", INFO, {}, dir), "")
	assert_eq(DirAccess.get_files_at(dir).size(), 1)
	assert_eq(SaveFile.read("8", dir)["problem"], "")


func test_p_a_failed_write_keeps_the_old_save_and_reports() -> void:
	var dir := _saved("1")
	var sav := SaveFile.path_of("1", dir)
	var before := _bytes(sav)
	DirAccess.make_dir_absolute(sav + ".tmp")  # the temp file cannot be made
	var problem := SaveFile.write(_game(), "1", INFO, {}, dir)
	assert_ne(problem, "", "the problem is returned")
	assert_eq(_bytes(sav), before, "the old save is untouched")
	DirAccess.remove_absolute(sav + ".tmp")


func test_remove_deletes_every_file_of_a_slot() -> void:
	var dir := _saved("2")
	_put(dir.path_join("2.png"), PackedByteArray([1]))
	_put(SaveFile.path_of("2", dir) + ".bak", PackedByteArray([1]))
	assert_true(SaveFile.remove("2", dir))
	assert_eq(DirAccess.get_files_at(dir).size(), 0)
	assert_true(SaveFile.remove("2", dir), "an empty slot is fine")


# ----- autosave slot --------------------------------------------------------------------------------------------


func test_the_autosave_slot_is_the_empty_or_the_oldest() -> void:
	var dir := _dir()
	assert_eq(SaveFile.auto_slot(dir), "auto1")
	var stamps := {"auto1": 300, "auto2": 100, "auto3": 200}
	assert_eq(SaveFile.write(_game(), "auto1", {"saved_unix": 300}, {}, dir), "")
	assert_eq(SaveFile.auto_slot(dir), "auto2", "the first empty")
	assert_eq(SaveFile.write(_game(), "auto2", {"saved_unix": 100}, {}, dir), "")
	assert_eq(SaveFile.auto_slot(dir), "auto3")
	assert_eq(SaveFile.write(_game(), "auto3", {"saved_unix": int(stamps["auto3"])}, {}, dir), "")
	assert_eq(SaveFile.auto_slot(dir), "auto2", "all full: the oldest")


# ----- random files ---------------------------------------------------------------------------------------------


func test_p_two_hundred_random_files_read_as_broken() -> void:
	var dir := _dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for n: int in 200:
		var bytes := PackedByteArray()
		bytes.resize(rng.randi_range(0, 600))
		for i: int in bytes.size():
			bytes[i] = rng.randi_range(0, 255)
		if n % 4 == 0 and bytes.size() > 20:
			bytes = ("{\"hexa\":\"save\",\"format\":2}\n").to_utf8_buffer() + bytes
		_put(SaveFile.path_of("1", dir), bytes)
		assert_eq(SaveFile.read_header("1", dir)["state"], &"broken", "file %d" % n)
		assert_eq(SaveFile.read("1", dir)["problem"], "Cannot be read", "file %d" % n)


# ----- hardening ------------------------------------------------------------------------------------------------


func test_p_utf8_validation() -> void:
	var good: Array[PackedByteArray] = [
		PackedByteArray([0x41]), PackedByteArray([0xC3, 0xA9]), PackedByteArray([0xE2, 0x82, 0xAC]),
		PackedByteArray([0xF0, 0x9F, 0x98, 0x80]), PackedByteArray([0xF4, 0x8F, 0xBF, 0xBF]),
		PackedByteArray([0xED, 0x9F, 0xBF]), PackedByteArray([0xE0, 0xA0, 0x80]), PackedByteArray([0xF0, 0x90, 0x80, 0x80]),
	]
	for bytes: PackedByteArray in good:
		assert_true(SaveFile._utf8_ok(bytes), str(bytes))
	var bad: Array[PackedByteArray] = [
		PackedByteArray([0xC0, 0x80]), PackedByteArray([0xC1, 0xBF]), PackedByteArray([0xE0, 0x80, 0x80]),
		PackedByteArray([0xE0, 0x9F, 0xBF]), PackedByteArray([0xF0, 0x80, 0x80, 0x80]),
		PackedByteArray([0xF0, 0x8F, 0xBF, 0xBF]), PackedByteArray([0xED, 0xA0, 0x80]),
		PackedByteArray([0xED, 0xBF, 0xBF]), PackedByteArray([0xF4, 0x90, 0x80, 0x80]),
		PackedByteArray([0xF5, 0x80, 0x80, 0x80]), PackedByteArray([0xF8, 0x88, 0x80, 0x80, 0x80]),
		PackedByteArray([0x80]), PackedByteArray([0xE2, 0x82]), PackedByteArray([0xC3]),
	]
	for bytes: PackedByteArray in bad:
		assert_false(SaveFile._utf8_ok(bytes), str(bytes))


## The file with its header line rewritten as text (the body stays), for numbers JSON.stringify would not write.
func _with_line(dir: String, slot: String, change: Callable) -> void:
	var path := SaveFile.path_of(slot, dir)
	var bytes := _bytes(path)
	var end := bytes.find(10)
	var line := str(change.call(bytes.slice(0, end).get_string_from_utf8()))
	var out := (line + "\n").to_utf8_buffer()
	out.append_array(bytes.slice(end + 1))
	_put(path, out)


func test_p_hostile_header_numbers_read_as_broken() -> void:
	var cases: Array[Array] = [
		["\"format\":5,", "\"format\":1e999,"], ["\"format\":5,", "\"format\":-1e999,"],
		["\"format\":5,", "\"format\":1e300,"], ["\"turn\":4}", "\"turn\":1e30}"],
		["\"saved_unix\":1700000000,", "\"saved_unix\":1e19,"], ["\"play_seconds\":61,", "\"play_seconds\":9007199254740994,"],
		["\"format\":5,", "\"format\":1.5,"], ["\"turn\":4}", "\"turn\":%s}" % "9".repeat(400)], ["\"turn\":4}", "\"turn\":-4}"],
	]
	for item: Array in cases:
		var dir := _saved("1")
		_with_line(dir, "1", func(line: String) -> String:
			assert_true(line.contains(item[0] as String), item[0])
			return line.replace(item[0] as String, item[1] as String))
		assert_eq(SaveFile.read_header("1", dir)["state"], &"broken", str(item))
		assert_eq(SaveFile.read("1", dir)["problem"], "Cannot be read", str(item))


func test_p_the_plain_size_must_be_at_least_one_and_at_most_the_max() -> void:
	var dir := _saved("1")
	var size := int((SaveFile.read_header("1", dir)["header"] as Dictionary)["body_size"])
	for bad: int in [0, SaveFile.BODY_MAX + 1]:
		_with_line(dir, "1", func(line: String) -> String:
			return line.replace("\"body_size\":%d" % size, "\"body_size\":%d" % bad))
		assert_eq(SaveFile.read_header("1", dir)["state"], &"broken", str(bad))
		size = bad


func test_p_invalid_utf8_in_the_header_is_broken_without_an_error() -> void:
	var dir := _saved("1")
	var path := SaveFile.path_of("1", dir)
	var bytes := _bytes(path)
	var at := bytes.find(0x41)  # an "A" of the header text
	assert_lt(at, bytes.find(10))
	bytes.remove_at(at)
	for pair: Array in [[0xC0, 0x80], [0xE0, 0x80], [0xED, 0xA0], [0xF4, 0x90], [0xF5, 0x80]]:
		var edited := bytes.duplicate()
		edited.insert(at, int(pair[0]))
		edited.insert(at + 1, int(pair[1]))
		edited.insert(at + 2, 0x80)
		edited.insert(at + 3, 0x80)
		_put(path, edited)
		assert_eq(SaveFile.read_header("1", dir)["state"], &"broken", str(pair))


class CountingMap extends MapData:
	var calls := 0

	func digest() -> String:
		calls += 1
		return "counted"


class CountingScenario extends ScenarioDef:
	var calls := 0

	func digest() -> String:
		calls += 1
		return "counted"


func test_p_header_of_does_not_hash_what_the_caller_knows() -> void:
	var g := _game()
	var map := CountingMap.new()
	map.id = g.map.id
	var scenario := CountingScenario.new()
	scenario.id = g.scenario.id
	g.map = map
	g.scenario = scenario
	var h := SaveFile.header_of(g, "1", {"map_digest": "m", "scenario_digest": "s"})
	assert_eq(h["map_digest"], "m")
	assert_eq(h["scenario_digest"], "s")
	assert_eq(map.calls, 0, "the map was not hashed")
	assert_eq(scenario.calls, 0, "the scenario was not hashed")
	h = SaveFile.header_of(g, "1", {})
	assert_eq(h["map_digest"], "counted")
	assert_eq(map.calls, 1)
	assert_eq(scenario.calls, 1)


func test_a_write_after_a_crash_between_the_two_renames_leaves_no_bak() -> void:
	# The crash left .tmp and .bak and no .sav.
	var dir := _saved("3")
	var sav := SaveFile.path_of("3", dir)
	DirAccess.rename_absolute(sav, sav + ".bak")
	_put(sav + ".tmp", "half".to_utf8_buffer())
	assert_eq(SaveFile.write(_game(), "3", INFO, {}, dir), "")
	var files := DirAccess.get_files_at(dir)
	assert_eq(files.size(), 1, str(files))
	assert_eq(files[0], "3.sav")
	assert_eq(SaveFile.read("3", dir)["problem"], "")


# ----- M4: format 2, the economy and the weather (m4-build-spec.md 4.22) ----------------------------------------


func test_the_format_is_5_and_a_format_4_save_is_older() -> void:
	# M7 (4.20, D55): the war body; an M6 (format 4) save reads older and is refused quietly.
	assert_eq(SaveFile.FORMAT, 5)
	assert_eq(SaveFile.OLDEST_FORMAT, 5)
	var old := _saved("2")
	_with_header(old, "2", func(h: Dictionary) -> void: h["format"] = 4)
	assert_eq(SaveFile.read_header("2", old)["state"], &"older", "a format-4 header reads older")
	assert_eq(SaveFile.read("2", old)["problem"], "Made by an older test build", "refused quietly")
	var three := _saved("3")
	_with_header(three, "3", func(h: Dictionary) -> void: h["format"] = 3)
	assert_eq(SaveFile.read_header("3", three)["state"], &"older", "a format-3 header reads older too")
	var dir := _saved("1")
	_with_header(dir, "1", func(h: Dictionary) -> void: h["format"] = 1)
	assert_eq(SaveFile.read_header("1", dir)["state"], &"older")
	assert_eq(SaveFile.read("1", dir)["problem"], "Made by an older test build")


func test_save_load_save_is_byte_equal_with_the_economy_and_a_stormy_weather() -> void:
	var d := (_fx["defs"] as GameDefs).duplicate() as GameDefs
	d.weather_odds = PackedInt32Array([0, 50, 50])
	var g := Game.new_scenario(_fx["map"] as MapData, d, _fx["scenario"] as ScenarioDef, 1480)
	g.improvement.clear(Vector2i(0, 2))
	g.act("choose_country", {"tag": &"AAA"})
	g.act("build", {"hex": Vector2i(0, 2), "family": ImproveRules.WHEAT, "tag": &"AAA"})
	for n: int in 5:
		Season.run(g)
	assert_ne(g.weather, PackedByteArray([0, 0, 0]), "not calm")
	var c := g.countries[0]
	assert_ne(c.ledger_closed, {}, "a closed ledger")
	assert_false(c.stock.is_empty(), "a stock")
	assert_false(c.flows_open.is_empty(), "flows")
	var dir_a := _dir()
	assert_eq(SaveFile.write(g, "2", INFO, {}, dir_a), "")
	var read := SaveFile.read("2", dir_a)
	assert_eq(read["problem"], "")
	var r := Snapshot.restore(read["body"] as Dictionary, _fx["map"] as MapData, d)
	assert_eq(r["problem"], "", "a save in non-calm weather loads")
	var back := r["game"] as Game
	assert_eq(back.digest(), g.digest())
	var dir_b := _dir()
	assert_eq(SaveFile.write(back, "2", INFO, {}, dir_b), "")
	assert_eq(_bytes(SaveFile.path_of("2", dir_a)), _bytes(SaveFile.path_of("2", dir_b)), "byte-equal files")


# ----- M5: the people (m5-build-spec.md 4.18) ------------------------------------------------------------------------


func test_save_load_save_is_byte_equal_with_the_people() -> void:
	var g := PeopleFixture.genoa()
	g.dev_people(Vector2i(6, 13), 2100)
	for n: int in 4:
		Season.run(g)
	assert_ne(g.state.people_start, g.state.people_end, "the people moved over the last season")
	assert_false(Countries.by_tag(g, &"GEN").people_closed.is_empty())
	var dir_a := _dir()
	assert_eq(SaveFile.write(g, "2", INFO, {}, dir_a), "")
	var read := SaveFile.read("2", dir_a)
	assert_eq(read["problem"], "")
	var r := Snapshot.restore(read["body"] as Dictionary, g.map, g.defs)
	assert_eq(r["problem"], "")
	var back := r["game"] as Game
	assert_eq(back.digest(), g.digest())
	var dir_b := _dir()
	assert_eq(SaveFile.write(back, "2", INFO, {}, dir_b), "")
	assert_eq(_bytes(SaveFile.path_of("2", dir_a)), _bytes(SaveFile.path_of("2", dir_b)), "byte-equal files")


func test_a_failed_load_keeps_the_running_game() -> void:
	var g := PeopleFixture.genoa()
	Season.run(g)
	var before := g.digest()
	var dir := _dir()
	assert_eq(SaveFile.write(g, "1", INFO, {}, dir), "")
	var body := SaveFile.read("1", dir)["body"] as Dictionary
	((body["countries"] as Array)[0] as Dictionary)["food_need"] = "many"
	var r := Snapshot.restore(body, g.map, g.defs)
	assert_null(r["game"])
	assert_eq(r["problem"], "Cannot be read")
	assert_eq(g.digest(), before, "the game in hand is untouched")
