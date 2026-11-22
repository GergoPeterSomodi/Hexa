## A text scan of core/ and shell/ (docs/architecture/m4-build-spec.md 5.3, 9; m5-build-spec.md 2 D22 and 9): the treasury, the
## stores and the people have one writer each. No assignment to .treasury, .stock, .flows_open, .ledger_open (nor a mutating
## call on them) outside treasury.gd and stores.gd; country.gd's from_dict reads a save into them and is the one other place.
## No assignment to .people, .people_start, .people_end, .people_flows, .people_closed, .food_need or .food_fed outside
## people.gd and the state classes (map_state.gd for the arrays, country.gd for the flows: create, duplicate_state, from_dict).
## Planted fault: a file in user:// with a writer is caught.
## M7 (review of B2): a field whose name is generic (morale, xp, standing, garrison, progress, tick...) is matched only on
## the receivers that hold it (a Unit, an Army, a MapState, a War, a Siege, a Battle), so a UI tile.morale is not flagged.
## Brackets are stripped first (nested ones too), so `wars[game.k[0]].end_turn = 1` is seen. Mutators: append, insert,
## set, fill, resize, clear, erase, remove_at, sort, sort_custom, assign, pop_back, pop_front, reverse, shuffle, merge.
extends GutTest

const FIELDS: Array[String] = ["treasury", "stock", "flows_open", "ledger_open", "stock_from", "ledger_from",
		"ledger_closed", "goods_closed"]
const ALLOWED: Array[String] = ["res://core/systems/treasury.gd", "res://core/systems/stores.gd", "res://core/state/country.gd"]
const PEOPLE_FIELDS: Array[String] = ["people", "people_start", "people_end", "people_flows", "people_closed", "food_need",
		"food_fed"]
const PEOPLE_ALLOWED: Array[String] = ["res://core/systems/people.gd", "res://core/state/map_state.gd",
		"res://core/state/country.gd"]
const MUTATORS := "append|append_array|push_back|push_front|insert|set|fill|resize|clear|erase|remove_at|sort|sort_custom|assign|pop_back|pop_front|reverse|shuffle|merge"
## M6 (L4): the armies' door. game.armies, next_army_id and next_unit_id are written only by armies.gd (and game.gd's
## declarations and the snapshot's restore, which assign the whole list through Armies.from_dict); the unit and army fields
## are written only by the state classes and armies.gd.
const ARMY_FIELDS: Array[String] = ["armies", "next_army_id", "next_unit_id", "moved_from", "lost_last", "halt_why",
		"halt_text", "raised_turn", "created_turn"]
## Battle.armies (M7 5.2) is the battle's own groups, written only by battle.gd's from_dict: a state class, not game.armies.
const ARMY_ALLOWED: Array[String] = ["res://core/systems/armies.gd", "res://core/state/army.gd", "res://core/state/unit.gd",
		"res://core/state/battle.gd"]
const ROOTS: Array[String] = ["res://core", "res://shell"]
## M6 (4.11, 5.0 R4): the explored bitset has three writers, all in vision.gd (setup, see_path, season); country.gd reads
## a save into it.
const EXPLORED_FIELDS: Array[String] = ["explored"]
const EXPLORED_ALLOWED: Array[String] = ["res://core/systems/sight.gd", "res://core/state/country.gd"]
## M7 (5.2, 5.3 OWNS): one door per field. The doors named here are the files that will write them (B5 Wars, B6 Occupation,
## B8 Battles and BattleEnd, B9 Sieges, M6's Armies); a file not yet in the tree is simply not scanned. The state classes
## build their fields from a dict and never write the game's. BattleEnd writes through Armies, so it is no morale door.
const WAR_FIELDS: Array[String] = ["wars", "next_war_id"]
const WAR_ALLOWED: Array[String] = ["res://core/systems/wars.gd", "res://core/state/war.gd"]
const WAR_VALUE_FIELDS: Array[String] = ["start_turn", "end_turn", "terms", "won_a", "won_b", "lost_a", "lost_b", "moved"]
const BATTLE_FIELDS: Array[String] = ["battles", "battle_records", "next_record_id", "battle_names"]
const BATTLE_ALLOWED: Array[String] = ["res://core/systems/battles.gd", "res://core/state/battle.gd",
		"res://core/state/battle_record.gd"]
const BATTLE_VALUE_FIELDS: Array[String] = ["attacker", "defender", "start_turn", "tick", "assault", "storm_from",
		"storm_cut", "crossing", "uphill", "river"]
const SIEGE_FIELDS: Array[String] = ["sieges", "siege_names"]
const SIEGE_ALLOWED: Array[String] = ["res://core/systems/sieges.gd", "res://core/state/siege.gd"]
const SIEGE_VALUE_FIELDS: Array[String] = ["progress", "seasons", "besieger", "started_turn"]
const OCCUPATION_FIELDS: Array[String] = ["occupier", "unsupported"]
const GARRISON_FIELDS: Array[String] = ["garrison"]
const OCCUPATION_ALLOWED: Array[String] = ["res://core/systems/occupation.gd", "res://core/state/map_state.gd"]
const MORALE_FIELDS: Array[String] = ["morale", "xp"]
const MORALE_ALLOWED: Array[String] = ["res://core/systems/armies.gd", "res://core/state/unit.gd"]
const STANDING_FIELDS: Array[String] = ["standing"]
const STANDING_ALLOWED: Array[String] = ["res://core/systems/armies.gd", "res://core/state/army.gd"]
## The receivers that hold each generic field (a name of the code, after brackets are stripped: units[] is a list element).
const MORALE_RECEIVERS: Array[String] = ["u", "uu", "ua", "ub", "unit", "unit_a", "unit_b", "units\\[\\]"]
const STANDING_RECEIVERS: Array[String] = ["a", "aa", "ar", "army", "army_a", "army_b", "armies\\[\\]"]
const GARRISON_RECEIVERS: Array[String] = ["state", "s", "st", "ms", "map_state", "new_state", "copy"]
const WAR_RECEIVERS: Array[String] = ["w", "war", "wars\\[\\]", "live", "ended"]
const SIEGE_RECEIVERS: Array[String] = ["s", "sg", "siege", "sieges\\[\\]"]
const BATTLE_RECEIVERS: Array[String] = ["b", "bt", "battle", "battles\\[\\]"]


func _pattern(fields: Array[String] = FIELDS, scope: Array[String] = []) -> RegEx:
	var re := RegEx.new()
	var names := "|".join(fields)
	if scope.is_empty():
		# .field = / += / -= ... (not ==), .field[..] = ..., and .field.mutator(
		re.compile("\\.(%s)\\b(\\s*\\[[^\\]]*\\])?\\s*(=(?!=)|[-+*/%%|&]=|\\.(%s)\\()" % [names, MUTATORS])
	else:
		# receiver.field = ..., receiver.field[..] = ..., receiver.field.mutator(; the receiver is a whole name
		re.compile("(?<!\\w)(?:%s)\\.(%s)\\b(\\s*\\[[^\\]]*\\])?\\s*(=(?!=)|[-+*/%%|&]=|\\.(%s)\\()" % ["|".join(scope), names, MUTATORS])
	return re


## A local that holds a guarded field itself (not a copy): `var x := c.ledger_open`, `x = c.goods_closed["flows"]`.
func _alias_pattern(fields: Array[String] = FIELDS) -> RegEx:
	var re := RegEx.new()
	re.compile("^(?:var\\s+)?(\\w+)\\s*(?::\\s*[\\w\\[\\]]+\\s*)?:?=\\s*[\\w\\.]*\\.(%s)(\\[[^\\]]*\\])*\\s*(#.*)?$" % "|".join(fields))
	return re


## The line with every bracket group replaced by [] (innermost first, so nested brackets go too).
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


## The lines of `text` that write a guarded field, or a local that aliases one; comments are dropped first. A scoped
## field (a scalar) is matched on its receivers only and has no alias (an int cannot be changed through a copy of it).
func _writers(text: String, fields: Array[String] = FIELDS, scope: Array[String] = []) -> Array[String]:
	var re := _pattern(fields, scope)
	var alias_re := _alias_pattern(fields)
	var lines: Array[String] = []
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		var hash_at := line.find(" #")
		if hash_at >= 0:
			line = line.substr(0, hash_at)
		lines.append(_strip_brackets(line))
	var aliases: Dictionary = {}   # name -> the line where it took the field; only later lines are checked
	if scope.is_empty():
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


func _typed(list: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(list)
	return out


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


## Every M7 group: [fields, allowed doors, receivers (empty: the field name alone)]. A scoped group matches only on its
## receivers; an unscoped one on any `.field`.
func _m7_groups() -> Array:
	return [
		[WAR_FIELDS, WAR_ALLOWED, []], [WAR_VALUE_FIELDS, WAR_ALLOWED, WAR_RECEIVERS],
		[BATTLE_FIELDS, BATTLE_ALLOWED, []], [BATTLE_VALUE_FIELDS, BATTLE_ALLOWED, BATTLE_RECEIVERS],
		[SIEGE_FIELDS, SIEGE_ALLOWED, []], [SIEGE_VALUE_FIELDS, SIEGE_ALLOWED, SIEGE_RECEIVERS],
		[OCCUPATION_FIELDS, OCCUPATION_ALLOWED, []], [GARRISON_FIELDS, OCCUPATION_ALLOWED, GARRISON_RECEIVERS],
		[MORALE_FIELDS, MORALE_ALLOWED, MORALE_RECEIVERS], [STANDING_FIELDS, STANDING_ALLOWED, STANDING_RECEIVERS],
	]


## The M7 writers in one line: the number of groups' hits (a planted line must give at least one).
func _m7_hits(line: String) -> int:
	var hits := 0
	for group: Array in _m7_groups():
		hits += _writers(line, _typed(group[0]), _typed(group[2])).size()
	return hits


func test_nothing_else_writes_the_m7_fields() -> void:
	var found: Array[String] = []
	for group: Array in _m7_groups():
		var allowed := _typed(group[1])
		for path: String in _all_scripts():
			if allowed.has(path):
				continue
			for line: String in _writers(FileAccess.get_file_as_string(path), _typed(group[0]), _typed(group[2])):
				found.append("%s: %s" % [path, line])
	assert_eq(found, [] as Array[String], "writers of the M7 fields outside their doors")


func test_the_scan_sees_each_kind_of_m7_writer() -> void:
	var bad: Array[String] = [
		"game.wars.append(w)", "g.next_war_id += 1", "game.battles = []", "g.battle_records[0] = r", "g.next_record_id = 9",
		"game.battle_names[\"Pavia\"] = 1", "g.sieges.clear()", "g.siege_names.erase(\"x\")", "s.occupier[3] = 1",
		"state.garrison[4] -= 2", "s.unsupported.fill(0)", "u.morale = 1000", "unit.xp += 5", "a.standing = &\"withdraw\"",
	]
	for line: String in bad:
		assert_eq(_m7_hits(line), 1, line)
	var fine: Array[String] = ["var w := g.wars[0]", "if u.morale > 100:", "var n := g.next_war_id", "# g.sieges = []",
		"var s := g.sieges.size()", "foo(g.battles)", "var m := unit.xp"]
	for line: String in fine:
		assert_eq(_m7_hits(line), 0, line)


## The review's planted lines (p4): every writer is caught, and the four generic reads on other receivers are not.
func test_the_review_planted_lines_are_caught_and_the_false_positives_are_not() -> void:
	var writers: Array[String] = [
		"s.occupier[hexes[i]] = 3", "s.garrison[idx[0]] -= 5", "s.occupier[i] = 3", "g.state.occupier.set(i, 2)",
		"g.wars[0].end_turn = 9", "g.sieges[0].progress += 1", "g.battles[0].tick = 3", "w.won_a += 1",
		"var o := g.state.occupier\no[3] = 1", "g.state.unsupported.fill(0)",
		"g.state.occupier = PackedByteArray()", "g.state.occupier.sort()", "g.wars.pop_back()", "g.wars.reverse()",
		"g.wars.shuffle()", "g.battle_names.merge(x)", "g.siege_names.merge(x)", "g.battle_records.remove_at(0)",
		"g.sieges.pop_front()", "g.wars.append_array(x)", "game.wars += [w]", "game.wars.sort_custom(f)",
		"g.battle_names.assign(x)",
	]
	for line: String in writers:
		assert_gt(_m7_hits(line), 0, "caught: " + line)
	var fine: Array[String] = ["tile.morale = 500", "row.xp = 3", "chip.standing = &\"hold\"", "view.garrison = 10"]
	for line: String in fine:
		assert_eq(_m7_hits(line), 0, "not a writer of these fields: " + line)


func test_the_m7_doors_that_exist_do_write() -> void:
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/state/map_state.gd"), OCCUPATION_FIELDS).size(), 0)
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/state/map_state.gd"), GARRISON_FIELDS, GARRISON_RECEIVERS).size(), 0)
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/state/unit.gd"), MORALE_FIELDS, MORALE_RECEIVERS).size(), 0)
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/state/army.gd"), STANDING_FIELDS, STANDING_RECEIVERS).size(), 0)


func test_planted_m7_writer_in_user_dir_is_caught() -> void:
	var path := "user://planted_m7_writer_test.gd"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("extends RefCounted\nfunc cheat(g: Game) -> void:\n\tg.wars.append(null)\n\tg.sieges[0].progress = 9\n"
		+ "\tg.state.occupier[0] = 3\n")
	f.close()
	var hits := 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		hits += _m7_hits(line)
	DirAccess.remove_absolute(path)
	assert_eq(hits, 3, "a war append, a siege's progress and an occupier write")
