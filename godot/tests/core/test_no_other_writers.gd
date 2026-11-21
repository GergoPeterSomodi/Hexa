## A text scan of core/ and shell/ (docs/architecture/m4-build-spec.md 5.3, 9; m5-build-spec.md 2 D22 and 9): the treasury, the
## stores and the people have one writer each. No assignment to .treasury, .stock, .flows_open, .ledger_open (nor a mutating
## call on them) outside treasury.gd and stores.gd; country.gd's from_dict reads a save into them and is the one other place.
## No assignment to .people, .people_start, .people_end, .people_flows, .people_closed, .food_need or .food_fed outside
## people.gd and the state classes (map_state.gd for the arrays, country.gd for the flows: create, duplicate_state, from_dict).
## Planted fault: a file in user:// with a writer is caught.
extends GutTest

const FIELDS: Array[String] = ["treasury", "stock", "flows_open", "ledger_open", "stock_from", "ledger_from",
		"ledger_closed", "goods_closed"]
const ALLOWED: Array[String] = ["res://core/systems/treasury.gd", "res://core/systems/stores.gd", "res://core/state/country.gd"]
const PEOPLE_FIELDS: Array[String] = ["people", "people_start", "people_end", "people_flows", "people_closed", "food_need",
		"food_fed"]
const PEOPLE_ALLOWED: Array[String] = ["res://core/systems/people.gd", "res://core/state/map_state.gd",
		"res://core/state/country.gd"]
const MUTATORS := "append|append_array|push_back|push_front|insert|set|fill|resize|clear|erase|remove_at|sort|assign"
## M6 (L4): the armies' door. game.armies, next_army_id and next_unit_id are written only by armies.gd (and game.gd's
## declarations and the snapshot's restore, which assign the whole list through Armies.from_dict); the unit and army fields
## are written only by the state classes and armies.gd.
const ARMY_FIELDS: Array[String] = ["armies", "next_army_id", "next_unit_id", "moved_from", "lost_last", "halt_why",
		"halt_text", "raised_turn", "created_turn"]
const ARMY_ALLOWED: Array[String] = ["res://core/systems/armies.gd", "res://core/state/army.gd", "res://core/state/unit.gd"]
const ROOTS: Array[String] = ["res://core", "res://shell"]
## M6 (4.11, 5.0 R4): the explored bitset has three writers, all in vision.gd (setup, see_path, season); country.gd reads
## a save into it.
const EXPLORED_FIELDS: Array[String] = ["explored"]
const EXPLORED_ALLOWED: Array[String] = ["res://core/systems/sight.gd", "res://core/state/country.gd"]


func _pattern(fields: Array[String] = FIELDS) -> RegEx:
	var re := RegEx.new()
	var names := "|".join(fields)
	# .field = / += / -= ... (not ==), .field[..] = ..., and .field.mutator(
	re.compile("\\.(%s)\\b(\\s*\\[[^\\]]*\\])?\\s*(=(?!=)|[-+*/%%|&]=|\\.(%s)\\()" % [names, MUTATORS])
	return re


## A local that holds a guarded field itself (not a copy): `var x := c.ledger_open`, `x = c.goods_closed["flows"]`.
func _alias_pattern(fields: Array[String] = FIELDS) -> RegEx:
	var re := RegEx.new()
	re.compile("^(?:var\\s+)?(\\w+)\\s*(?::\\s*[\\w\\[\\]]+\\s*)?:?=\\s*[\\w\\.]*\\.(%s)(\\[[^\\]]*\\])*\\s*(#.*)?$" % "|".join(fields))
	return re


## The lines of `text` that write a guarded field, or a local that aliases one; comments are dropped first.
func _writers(text: String, fields: Array[String] = FIELDS) -> Array[String]:
	var re := _pattern(fields)
	var alias_re := _alias_pattern(fields)
	var lines: Array[String] = []
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		var hash_at := line.find(" #")
		if hash_at >= 0:
			line = line.substr(0, hash_at)
		lines.append(line)
	var aliases: Dictionary = {}   # name -> the line where it took the field; only later lines are checked
	for n: int in lines.size():
		var m := alias_re.search(lines[n])
		if m != null and not aliases.has(m.get_string(1)):
			aliases[m.get_string(1)] = n
	var out: Array[String] = []
	for n: int in lines.size():
		var line := lines[n]
		if re.search(line) != null:
			out.append(line)
			continue
		for alias: String in aliases:
			if n <= int(aliases[alias]):
				continue
			var alias_write := RegEx.new()
			alias_write.compile("(?<![\\w.])%s\\b(\\s*\\[[^\\]]*\\])*\\s*(=(?!=)|[-+*/%%|&]=|\\.(%s)\\()" % [alias, MUTATORS])
			if alias_write.search(line) != null:
				out.append(line)
				break
	return out


func _scripts(dir_path: String, out: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_scripts(dir_path.path_join(sub), out)
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))


func _all_scripts() -> Array[String]:
	var files: Array[String] = []
	for root: String in ROOTS:
		_scripts(root, files)
	return files


func test_nothing_else_writes_the_purse_or_the_stores() -> void:
	var files := _all_scripts()
	assert_gt(files.size(), 100, "the scan found the scripts")
	var found: Array[String] = []
	for path: String in files:
		if ALLOWED.has(path):
			continue
		for line: String in _writers(FileAccess.get_file_as_string(path)):
			found.append("%s: %s" % [path, line])
	assert_eq(found, [] as Array[String], "writers outside treasury.gd and stores.gd")


func test_nothing_else_writes_the_people() -> void:
	var found: Array[String] = []
	for path: String in _all_scripts():
		if PEOPLE_ALLOWED.has(path):
			continue
		for line: String in _writers(FileAccess.get_file_as_string(path), PEOPLE_FIELDS):
			found.append("%s: %s" % [path, line])
	assert_eq(found, [] as Array[String], "writers of people, their flows and the food numbers outside people.gd and the state classes")


func test_nothing_else_writes_the_explored() -> void:
	var found: Array[String] = []
	for path: String in _all_scripts():
		if EXPLORED_ALLOWED.has(path):
			continue
		for line: String in _writers(FileAccess.get_file_as_string(path), EXPLORED_FIELDS):
			found.append("%s: %s" % [path, line])
	assert_eq(found, [] as Array[String], "writers of explored outside vision.gd and country.gd")


func test_the_explored_door_does_write() -> void:
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/systems/sight.gd"), EXPLORED_FIELDS).size(), 0)


func test_the_scan_sees_each_kind_of_explored_writer() -> void:
	var bad: Array[String] = ["c.explored = seen", "c.explored[3] = 1", "c.explored[i] |= 4", "c.explored.fill(0)",
		"c.explored.resize(9)"]
	for line: String in bad:
		assert_eq(_writers(line, EXPLORED_FIELDS).size(), 1, line)
	var fine: Array[String] = ["var e := c.explored", "if c.explored.size() == 0:", "foo(c.explored)", "# c.explored = x",
		"var copy := c.explored.duplicate()"]
	for line: String in fine:
		assert_eq(_writers(line, EXPLORED_FIELDS).size(), 0, line)


func test_nothing_else_writes_the_armies() -> void:
	var found: Array[String] = []
	for path: String in _all_scripts():
		if ARMY_ALLOWED.has(path):
			continue
		for line: String in _writers(FileAccess.get_file_as_string(path), ARMY_FIELDS):
			found.append("%s: %s" % [path, line])
	assert_eq(found, [] as Array[String], "writers of the armies and their fields outside armies.gd and the state classes")


func test_the_scan_sees_each_kind_of_army_writer() -> void:
	var bad: Array[String] = [
		"game.armies = []", "g.next_army_id += 1", "game.next_unit_id = 5", "game.armies.append(a)", "a.moved_from = Vector2i(1, 1)",
		"u.raised_turn = 3", "army.halt_why = &\"blocked\"", "army.lost_last -= 3",
	]
	for line: String in bad:
		assert_eq(_writers(line, ARMY_FIELDS).size(), 1, line)
	var fine: Array[String] = ["var n := g.next_army_id", "if a.raised_turn == turn:", "# a.waiting = &\"winter\""]
	for line: String in fine:
		assert_eq(_writers(line, ARMY_FIELDS).size(), 0, line)


func test_the_two_doors_do_write() -> void:
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/systems/treasury.gd")).size(), 0)
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/systems/stores.gd")).size(), 0)


func test_the_people_door_does_write() -> void:
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/systems/people.gd"), PEOPLE_FIELDS).size(), 0)
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/state/map_state.gd"), PEOPLE_FIELDS).size(), 0)


func test_the_scan_sees_each_kind_of_writer() -> void:
	var bad: Array[String] = [
		"c.treasury = 5", "c.treasury += 5", "country.treasury -= cost", "c.stock[3] = 1", "c.stock[g] += 2",
		"c.stock = PackedInt32Array()", "c.flows_open.fill(0)", "c.ledger_open.append(line)", "c.ledger_open = []",
		"c.stock.resize(16)",
	]
	for line: String in bad:
		assert_eq(_writers(line).size(), 1, line)
	var fine: Array[String] = [
		"var t := c.treasury", "if c.treasury == 5:", "x = c.stock[3]", "# c.treasury = 5", "foo(c.stock)",
		"c.stock.size()", "var tag := c.stock_name", "c.treasury_view = 1",
	]
	for line: String in fine:
		assert_eq(_writers(line).size(), 0, line)


func test_the_scan_sees_each_kind_of_people_writer() -> void:
	var bad: Array[String] = [
		"game.state.people[i] = 5", "game.state.people[i] += 5", "state.people = PackedInt32Array()", "s.people.fill(0)",
		"s.people_start = s.people_end", "s.people_end[3] -= 1", "c.people_flows[2] += amount", "c.people_flows.fill(0)",
		"c.people_closed = {}", "c.people_closed[\"turn\"] = 3", "c.food_need = 4", "c.food_fed -= 1", "c.food_fed = 1000",
		"game.state.people.resize(n)",
	]
	for line: String in bad:
		assert_eq(_writers(line, PEOPLE_FIELDS).size(), 1, line)
	var fine: Array[String] = [
		"var p := state.people[i]", "if state.people[i] == 0:", "x = c.people_flows[3]", "# c.food_need = 5", "foo(state.people)",
		"state.people.size()", "c.food_need_milli = 5", "defs.food_need_milli = 0", "var a := c.people_closed.get(\"turn\", 0)",
		"v._people_over[i] = 3", "state.people_end.duplicate()", "if c.food_fed < 1000:",
	]
	for line: String in fine:
		assert_eq(_writers(line, PEOPLE_FIELDS).size(), 0, line)
	var text := "func f(s: MapState) -> void:\n\tvar p := s.people\n\tp[3] = 9\n"
	assert_eq(_writers(text, PEOPLE_FIELDS).size(), 1, "a mutation through an alias of the people array")
	var copy := "func f(s: MapState) -> void:\n\tvar p := s.people.duplicate()\n\tp[3] = 9\n"
	assert_eq(_writers(copy, PEOPLE_FIELDS).size(), 0, "a copy may be changed")
	var read := "func f(s: MapState) -> void:\n\tvar p := s.people\n\tprint(p[3])\n"
	assert_eq(_writers(read, PEOPLE_FIELDS).size(), 0, "reading through an alias is fine")


func test_the_scan_sees_aliases_and_the_closed_fields() -> void:
	var text := "func f(c: Country) -> void:\n\tvar open := c.ledger_open\n\topen.append({})\n"
	assert_eq(_writers(text).size(), 1, "a mutation through an alias")
	var text2 := "func f(c: Country) -> void:\n\tvar flows: PackedInt32Array = c.goods_closed[\"flows\"]\n\tflows[0] = 5\n"
	assert_eq(_writers(text2).size(), 1)
	var text3 := "func f(c: Country) -> void:\n\tvar open := c.ledger_open.duplicate()\n\topen.append({})\n"
	assert_eq(_writers(text3).size(), 0, "a copy may be changed")
	var text4 := "func f(c: Country) -> void:\n\tvar open := c.ledger_open\n\tprint(open.size())\n"
	assert_eq(_writers(text4).size(), 0, "reading through an alias is fine")
	assert_eq(_writers("c.ledger_closed = {}").size(), 1)
	assert_eq(_writers("c.goods_closed[\"turn\"] = 3").size(), 1)
	assert_eq(_writers("c.goods_closed.clear()").size(), 1)


func test_planted_writer_in_user_dir_is_caught() -> void:
	var path := "user://planted_writer_test.gd"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("extends RefCounted\nfunc cheat(c: Country) -> void:\n\tc.treasury += 1000000\n")
	f.close()
	var hits := _writers(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	assert_eq(hits.size(), 1)


func test_planted_explored_writer_in_user_dir_is_caught() -> void:
	var path := "user://planted_explored_writer_test.gd"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("extends RefCounted\nfunc cheat(c: Country) -> void:\n\tc.explored[0] = 255\n")
	f.close()
	var hits := _writers(FileAccess.get_file_as_string(path), EXPLORED_FIELDS)
	DirAccess.remove_absolute(path)
	assert_eq(hits.size(), 1)


func test_planted_people_writer_in_user_dir_is_caught() -> void:
	var path := "user://planted_people_writer_test.gd"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("extends RefCounted\nfunc cheat(g: Game) -> void:\n\tg.state.people[0] += 1000000\n")
	f.close()
	var hits := _writers(FileAccess.get_file_as_string(path), PEOPLE_FIELDS)
	DirAccess.remove_absolute(path)
	assert_eq(hits.size(), 1)
