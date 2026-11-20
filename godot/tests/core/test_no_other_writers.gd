## A text scan of core/ and shell/ (docs/architecture/m4-build-spec.md 5.3, 9): the treasury and the stores have one
## writer each. No assignment to .treasury, .stock, .flows_open, .ledger_open (nor a mutating call on them) outside
## treasury.gd and stores.gd; country.gd's from_dict reads a save into them and is the one other place.
## Planted fault: a file in user:// with a writer is caught.
extends GutTest

const FIELDS: Array[String] = ["treasury", "stock", "flows_open", "ledger_open", "stock_from", "ledger_from",
		"ledger_closed", "goods_closed"]
const ALLOWED: Array[String] = ["res://core/systems/treasury.gd", "res://core/systems/stores.gd", "res://core/state/country.gd"]
const MUTATORS := "append|append_array|push_back|push_front|insert|set|fill|resize|clear|erase|remove_at|sort|assign"
const ROOTS: Array[String] = ["res://core", "res://shell"]


func _pattern() -> RegEx:
	var re := RegEx.new()
	var names := "|".join(FIELDS)
	# .field = / += / -= ... (not ==), .field[..] = ..., and .field.mutator(
	re.compile("\\.(%s)\\b(\\s*\\[[^\\]]*\\])?\\s*(=(?!=)|[-+*/%%|&]=|\\.(%s)\\()" % [names, MUTATORS])
	return re


## A local that holds a guarded field itself (not a copy): `var x := c.ledger_open`, `x = c.goods_closed["flows"]`.
func _alias_pattern() -> RegEx:
	var re := RegEx.new()
	re.compile("^(?:var\\s+)?(\\w+)\\s*(?::\\s*[\\w\\[\\]]+\\s*)?:?=\\s*[\\w\\.]*\\.(%s)(\\[[^\\]]*\\])*\\s*(#.*)?$" % "|".join(FIELDS))
	return re


## The lines of `text` that write a guarded field, or a local that aliases one; comments are dropped first.
func _writers(text: String) -> Array[String]:
	var re := _pattern()
	var alias_re := _alias_pattern()
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


func test_nothing_else_writes_the_purse_or_the_stores() -> void:
	var files: Array[String] = []
	for root: String in ROOTS:
		_scripts(root, files)
	assert_gt(files.size(), 100, "the scan found the scripts")
	var found: Array[String] = []
	for path: String in files:
		if ALLOWED.has(path):
			continue
		for line: String in _writers(FileAccess.get_file_as_string(path)):
			found.append("%s: %s" % [path, line])
	assert_eq(found, [] as Array[String], "writers outside treasury.gd and stores.gd")


func test_the_two_doors_do_write() -> void:
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/systems/treasury.gd")).size(), 0)
	assert_gt(_writers(FileAccess.get_file_as_string("res://core/systems/stores.gd")).size(), 0)


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
