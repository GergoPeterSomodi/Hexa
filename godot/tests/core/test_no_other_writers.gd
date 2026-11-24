## A text scan of core/ and shell/ (docs/architecture/m4-build-spec.md 5.3, 9; m5-build-spec.md 2 D22 and 9; m6 5.2; m7 5.2, 5.3
## OWNS): each guarded field has a door, the files that may write it. A write to `.field` outside its door is a violation,
## whatever the receiver is called (f.morale, war_b.lost_a, Sieges.at(g, h).progress, a.units.back().xp, wars[0].end_turn).
## A write is an assignment, an operator assignment, an index write, a mutator call (append, fill, pop_back, sort, merge...) or
## set("field", value). Brackets are stripped first (any depth), so the receiver's index never hides the write.
## A local that takes a container field (a packed array, a dictionary, an array: stock, garrison, people, explored...) is an
## alias of it: packed arrays share their storage in this engine, so `var gar := game.state.garrison` and `gar[3] = 0` is a write.
## The allowlist (ALLOW) names the files that set a guarded field name on an object that is not game state, with the reason.
## Reads are never flagged: `var m := tile.morale` and `if u.xp > 3:` are fine. Planted faults in user:// are caught.
extends GutTest

const FIELDS: Array[String] = ["treasury", "stock", "flows_open", "ledger_open", "stock_from", "ledger_from",
		"ledger_closed", "goods_closed"]
const ALLOWED: Array[String] = ["res://core/systems/treasury.gd", "res://core/systems/stores.gd", "res://core/state/country.gd"]
const PEOPLE_FIELDS: Array[String] = ["people", "people_start", "people_end", "people_flows", "people_closed", "food_need",
		"food_fed"]
const PEOPLE_ALLOWED: Array[String] = ["res://core/systems/people.gd", "res://core/state/map_state.gd",
		"res://core/state/country.gd"]
const MUTATORS := "append|append_array|push_back|push_front|insert|set|fill|resize|clear|erase|remove_at|sort|sort_custom|assign|pop_back|pop_front|reverse|shuffle|merge"
## Containers: a local that holds one of these is an alias of it (the storage is shared).
const CONTAINERS: Array[String] = ["stock", "flows_open", "ledger_open", "goods_closed", "ledger_closed", "people",
		"people_start", "people_end", "people_flows", "people_closed", "explored", "garrison", "occupier", "unsupported",
		"armies", "wars", "battles", "battle_records", "sieges", "battle_names", "siege_names"]
## M6 (L4): the armies' door. game.armies, next_army_id and next_unit_id are written only by armies.gd (and game.gd's
## declarations and the snapshot's restore, which assign the whole list through Armies.from_dict); the unit and army fields
## are written only by the state classes and armies.gd.
const ARMY_FIELDS: Array[String] = ["armies", "next_army_id", "next_unit_id", "moved_from", "lost_last", "halt_why",
		"halt_text", "raised_turn", "created_turn"]
const ROOTS: Array[String] = ["res://core", "res://shell"]
## M6 (4.11, 5.0 R4): the explored bitset has three writers, all in vision.gd (setup, see_path, season); country.gd reads
## a save into it.
const EXPLORED_FIELDS: Array[String] = ["explored"]
const EXPLORED_ALLOWED: Array[String] = ["res://core/systems/sight.gd", "res://core/state/country.gd"]
## M7 (5.2, 5.3 OWNS): the war's fields and their doors.
const WAR_FIELDS: Array[String] = ["wars", "next_war_id"]
const WAR_VALUE_FIELDS: Array[String] = ["end_turn", "terms", "won_a", "won_b", "lost_a", "lost_b", "moved"]
const START_TURN_FIELDS: Array[String] = ["start_turn"]
const BATTLE_FIELDS: Array[String] = ["battles", "battle_records", "next_record_id", "battle_names"]
const BATTLE_VALUE_FIELDS: Array[String] = ["tick", "assault", "storm_from", "storm_cut", "crossing", "uphill", "river"]
const BATTLE_RECORD_FIELDS: Array[String] = ["attacker", "defender"]
const SIEGE_FIELDS: Array[String] = ["sieges", "siege_names"]
const SIEGE_VALUE_FIELDS: Array[String] = ["progress", "besieger"]
const OCCUPATION_FIELDS: Array[String] = ["occupier", "garrison", "unsupported"]
const MORALE_FIELDS: Array[String] = ["morale", "xp"]
const STANDING_FIELDS: Array[String] = ["standing"]
## Works (M6) and sieges both have a start and a season count; each door writes its own.
const WORK_FIELDS: Array[String] = ["seasons", "started_turn"]


## The doors of a field: the systems and state files named by their base names.
func _door(sys: String, st: String) -> Array[String]:
	var out: Array[String] = []
	for name: String in sys.split(" ", false):
		out.append("res://core/systems/%s.gd" % name)
	for name: String in st.split(" ", false):
		out.append("res://core/state/%s.gd" % name)
	return out


## Every guarded group: [fields, the files that may write them].
func _guards() -> Array:
	return [
		[FIELDS, _door("treasury stores", "country")],
		[PEOPLE_FIELDS, _door("people", "map_state country")],
		[EXPLORED_FIELDS, _door("sight", "country")],
		[ARMY_FIELDS, _door("armies", "army unit battle")],
		[WAR_FIELDS, _door("wars", "war")],
		[WAR_VALUE_FIELDS, _door("wars", "war")],
		[START_TURN_FIELDS, _door("wars battles", "war battle")],
		[BATTLE_FIELDS, _door("battles", "battle battle_record")],
		[BATTLE_VALUE_FIELDS, _door("battles", "battle")],
		[BATTLE_RECORD_FIELDS, _door("battles", "battle battle_record")],
		[SIEGE_FIELDS, _door("sieges", "siege")],
		[SIEGE_VALUE_FIELDS, _door("sieges", "siege")],
		[OCCUPATION_FIELDS, _door("occupation", "map_state")],
		[MORALE_FIELDS, _door("armies", "unit")],
		[STANDING_FIELDS, _door("armies", "army")],
		[WORK_FIELDS, _door("sieges works", "siege work")],
	]


## Known writes of a guarded name on an object that is not game state, with the reason. Each entry is a file, the fields it
## may set, and why. Keep it short: a new entry needs a reason that holds today.
func _allow() -> Array:
	return [
		["res://core/mapgen/fake_map.gd", ["crossing", "river"],
			"a map tool's own arrays (its _map.crossing and _map.river are MapData-like bytes, not a battle)"],
		["res://core/systems/battle_end.gd", ["attacker", "defender"],
			"BattleEnd.apply builds the BattleRecord it returns: a new object, booked by Battles, not game state yet"],
		["res://core/systems/combat_input.gd", ["assault", "crossing", "uphill", "river"],
			"CombatState fields set from the fight's input: a new object built by Combat, not a Battle"],
	]


func _allowed(path: String, field: String) -> bool:
	for entry: Array in _allow():
		if entry[0] == path and (entry[1] as Array).has(field):
			return true
	return false


func _pattern(fields: Array[String]) -> RegEx:
	var re := RegEx.new()
	var names := "|".join(fields)
	# .field = / += / -= ... (not ==), .field[..] = ..., and .field.mutator(
	re.compile("\\.(%s)\\b(\\s*\\[[^\\]]*\\])?\\s*(=(?!=)|[-+*/%%|&]=|\\.(%s)\\()" % [names, MUTATORS])
	return re


## The line with every bracket group replaced by [] (any depth: the outermost group is kept, its contents are dropped).
func _strip_brackets(line: String) -> String:
	var out := ""
	var depth := 0
	for i: int in line.length():
		var ch := line[i]
		if ch == "[":
			if depth == 0:
				out += "["
			depth += 1
		elif ch == "]" and depth > 0:
			depth -= 1
			if depth == 0:
				out += "]"
		elif depth == 0:
			out += ch
	return out


## The code lines of `text`: comments dropped, brackets stripped.
func _code_lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		var hash_at := line.find(" #")
		if hash_at >= 0:
			line = line.substr(0, hash_at)
		lines.append(_strip_brackets(line))
	return lines


## The writes of the guarded `fields` in `text`: [field, line] for each line that writes one. A container alias is a write
## of its field when it is written through; set("field", ...) names the field.
func _scan(text: String, fields: Array[String]) -> Array:
	var re := _pattern(fields)
	var dyn := RegEx.new()
	dyn.compile("\\bset\\(\\s*\"(%s)\"" % "|".join(fields))
	var containers: Array[String] = []
	for name: String in fields:
		if CONTAINERS.has(name):
			containers.append(name)
	var lines := _code_lines(text)
	var aliases: Dictionary = {}   # local name -> [the line it took the field on, the field]
	if not containers.is_empty():
		var alias_re := RegEx.new()
		alias_re.compile("^(?:var\\s+)?(\\w+)\\s*(?::\\s*[\\w\\[\\]]+\\s*)?:?=\\s*[\\w\\.]*\\.(%s)(\\[[^\\]]*\\])*\\s*(#.*)?$" % "|".join(containers))
		for n: int in lines.size():
			var m := alias_re.search(lines[n])
			if m != null and not aliases.has(m.get_string(1)):
				aliases[m.get_string(1)] = [n, m.get_string(2)]
	var out: Array = []
	for n: int in lines.size():
		var line := lines[n]
		var m := re.search(line)
		if m != null:
			out.append([m.get_string(1), line])
			continue
		var d := dyn.search(line)
		if d != null:
			out.append([d.get_string(1), line])
			continue
		for alias: String in aliases:
			var held: Array = aliases[alias]
			if n <= int(held[0]):
				continue
			var alias_write := RegEx.new()
			alias_write.compile("(?<![\\w.])%s\\b(\\s*\\[[^\\]]*\\])*\\s*(=(?!=)|[-+*/%%|&]=|\\.(%s)\\()" % [alias, MUTATORS])
			if alias_write.search(line) != null:
				out.append([String(held[1]), line])
				break
	return out


## The lines of `text` that write one of `fields` (a write through an alias included). Kept for the purse and people tests.
func _writers(text: String, fields: Array[String] = FIELDS) -> Array[String]:
	var out: Array[String] = []
	for hit: Array in _scan(text, fields):
		out.append(String(hit[1]))
	return out


## The violations of one file: each write of a guarded field in a file outside that field's doors and not allowed.
func _violations(text: String, path: String) -> Array[String]:
	var out: Array[String] = []
	for group: Array in _guards():
		var doors: Array[String] = []
		doors.assign(group[1])
		if doors.has(path):
			continue
		var fields: Array[String] = []
		fields.assign(group[0])
		for hit: Array in _scan(text, fields):
			if _allowed(path, String(hit[0])):
				continue
			out.append("%s: %s" % [path, String(hit[1])])
	return out


## Every write of a guarded field in one line or text, whatever file it is in: [field, line] hits across all groups.
func _all_hits(text: String) -> Array:
	var out: Array = []
	for group: Array in _guards():
		var fields: Array[String] = []
		fields.assign(group[0])
		out.append_array(_scan(text, fields))
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


## FG4 (fog spec R11): the explored set has five entry points, all in sight.gd: setup, see_path, season, and on_emit for
## district_captured (R9) and for the ownership events (R10). Pinned here by the functions that write it and the ones
## that call the door: _mark (and _or_land, from season) write; see_path and season call _mark; the three on_emit
## handlers reach it through _mark_rings. A sixth entry point makes one of these lists longer and fails.
func test_sight_has_its_five_explored_entry_points_and_no_more() -> void:
	var text := FileAccess.get_file_as_string("res://core/systems/sight.gd")
	assert_eq(_functions_with(text, EXPLORED_FIELDS), ["_mark", "_or_land", "setup"] as Array[String],
		"the functions that write explored")
	assert_eq(_callers(text, "_mark("), ["_mark_rings", "season", "see_path"] as Array[String],
		"the callers of the door _mark")
	assert_eq(_callers(text, "_mark_rings("), ["_captured", "_controllers_changed", "_owners_changed"] as Array[String],
		"the on_emit handlers that mark a ring")
	assert_eq(_callers(text, "_or_land("), ["season"] as Array[String], "the callers of the vision phase's sweep")


## The sorted names of the functions of `text` whose body writes one of `fields` (a write as _writers reads it).
func _functions_with(text: String, fields: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var current := ""
	for line: String in text.split("\n"):
		if line.begins_with("static func ") or line.begins_with("func "):
			current = line.split("(")[0].trim_prefix("static func ").trim_prefix("func ")
		elif not _writers(line, fields).is_empty() and not out.has(current):
			out.append(current)
	out.sort()
	return out


## The sorted names of the functions of `text` (other than the one defined on the line) whose body calls `needle`.
func _callers(text: String, needle: String) -> Array[String]:
	var out: Array[String] = []
	var current := ""
	for line: String in text.split("\n"):
		if line.begins_with("static func ") or line.begins_with("func "):
			current = line.split("(")[0].trim_prefix("static func ").trim_prefix("func ")
		elif line.strip_edges().begins_with("#"):
			continue
		elif line.contains(needle) and not out.has(current):
			out.append(current)
	out.sort()
	return out


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
		if ["res://core/systems/armies.gd", "res://core/state/army.gd", "res://core/state/unit.gd",
				"res://core/state/battle.gd"].has(path):
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


## The real tree: no write of a guarded field outside its doors and the allowlist.
func test_the_real_tree_has_no_write_outside_its_doors() -> void:
	var found: Array[String] = []
	var scripts := _all_scripts()
	assert_gt(scripts.size(), 100, "the scan found the scripts")
	for path: String in scripts:
		found.append_array(_violations(FileAccess.get_file_as_string(path), path))
	assert_eq(found, [] as Array[String], "writers of guarded fields outside their doors")


func test_each_allowlist_entry_is_needed_and_names_a_real_file() -> void:
	for entry: Array in _allow():
		assert_true(FileAccess.file_exists(String(entry[0])), "the allowlisted file exists: %s" % entry[0])
		assert_false(String(entry[2]).is_empty(), "a reason is given")
		var text := FileAccess.get_file_as_string(String(entry[0]))
		var needed := false
		for field: Variant in entry[1]:
			var one: Array[String] = [String(field)]
			if _scan(text, one).size() > 0:
				needed = true
		assert_true(needed, "the entry is still needed: %s" % entry[0])


func test_an_allowlisted_write_is_allowed_only_in_its_file_and_for_its_fields() -> void:
	assert_eq(_violations("_map.river[e] = 1", "res://core/mapgen/fake_map.gd"), [] as Array[String], "allowed here")
	assert_eq(_violations("_map.river[e] = 1", "res://core/systems/other.gd").size(), 1, "not allowed in another file")
	assert_eq(_violations("rec.attacker = battle.attacker", "res://core/systems/battle_end.gd"), [] as Array[String])
	assert_eq(_violations("rec.attacker = battle.attacker", "res://core/systems/other.gd").size(), 1)
	assert_eq(_violations("_map.morale[e] = 1", "res://core/mapgen/fake_map.gd").size(), 1,
		"morale is not allowed in fake_map: the entry names two fields only")


## Each planted line of the review: the field it writes is found.
func test_each_planted_write_is_caught() -> void:
	var planted: Array = [
		["for f in us: f.morale = 0", "morale"],
		["u2.morale -= 1", "morale"],
		["army.units[0].xp += 1", "xp"],
		["a.units.back().xp = 3", "xp"],
		["ar2.standing = &\"hold\"", "standing"],
		["Armies.by_id(g, 1).standing = &\"hold\"", "standing"],
		["game.state.garrison[3] = 0", "garrison"],
		["gs.garrison[3] = 0", "garrison"],
		["var gar := game.state.garrison\ngar[3] = 0", "garrison"],
		["var o := game.state.occupier\no[1] = 2", "occupier"],
		["w.lost_a += 5", "lost_a"],
		["x.lost_a = 0", "lost_a"],
		["War.live_between(g.wars, a, b).lost_a = 0", "lost_a"],
		["s2.progress = 99", "progress"],
		["Sieges.at(g, h).progress = 99", "progress"],
		["Battles.at(g, h).storm_cut = 0", "storm_cut"],
		["bb.assault = true", "assault"],
		["g.wars[0].end_turn = 9", "end_turn"],
		["g.set(\"end_turn\", 9)", "end_turn"],
		["game.battles.append(b)", "battles"],
		["game.battle_names[k] = 1", "battle_names"],
		["work.seasons = 4", "seasons"],
	]
	for case: Array in planted:
		var names: Array[String] = []
		for hit: Array in _all_hits(String(case[0])):
			names.append(String(hit[0]))
		assert_true(names.has(String(case[1])), "caught: %s (found %s)" % [case[0], str(names)])


## The earlier positive list: each line is one write, found once.
func test_the_scan_sees_each_kind_of_m7_writer() -> void:
	var bad: Array[String] = [
		"game.wars.append(w)", "g.next_war_id += 1", "game.battles = []", "g.battle_records[0] = r", "g.next_record_id = 9",
		"game.battle_names[\"Pavia\"] = 1", "g.sieges.clear()", "g.siege_names.erase(\"x\")", "s.occupier[3] = 1",
		"state.garrison[4] -= 2", "s.unsupported.fill(0)", "u.morale = 1000", "unit.xp += 5", "a.standing = &\"withdraw\"",
	]
	for line: String in bad:
		assert_eq(_all_hits(line).size(), 1, line)


## Reads and the names that are not writes are not flagged.
func test_reads_and_other_receivers_of_plain_names_are_not_flagged() -> void:
	var fine: Array[String] = ["var m := tile.morale", "if u.xp > 3:", "print(a.standing)", "var t := War.live_between(g.wars, a, b).lost_a",
		"var n := g.next_war_id", "# g.sieges = []", "var s := g.sieges.size()", "foo(g.battles)",
		"var gar2 := game.state.garrison.duplicate()", "gar2[3] = 0", "var w := g.wars[0]", "var k := game.state.garrison[3]"]
	for line: String in fine:
		assert_eq(_all_hits(line).size(), 0, line)


func test_the_doors_that_exist_do_write() -> void:
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/state/map_state.gd"), OCCUPATION_FIELDS).size(), 0)
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/state/unit.gd"), MORALE_FIELDS).size(), 0)
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/state/army.gd"), STANDING_FIELDS).size(), 0)


func test_planted_m7_writer_in_user_dir_is_caught() -> void:
	var path := "user://planted_m7_writer_test.gd"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("extends RefCounted\nfunc cheat(g: Game) -> void:\n\tg.wars.append(null)\n\tg.sieges[0].progress = 9\n"
		+ "\tg.state.occupier[0] = 3\n")
	f.close()
	var hits := 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		hits += _all_hits(line).size()
	DirAccess.remove_absolute(path)
	assert_eq(hits, 3, "a war append, a siege's progress and an occupier write")
