## The improvement step on a baked hex table, in numbers: per seed the search time, the backtracks, the pieces by family
## and level, the rule breaks (none expected), and a small map of letters. Headless:
##   godot --headless --path godot -s res://tools/worldmap/improve_report.gd -- [--meta=<path of meta.json>] [--seeds=1,2,3]
extends SceneTree

const META := "res://assets/worldmap/north_italy/meta.json"
const LETTERS: Array[String] = [".", "#", "C", "w", "h", "s", "d", "v", "o", "g", "t", "m", "q", "S", "H"]


func _init() -> void:
	var path := _argument("--meta=", META)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("improve report: %s does not read" % path)
		quit(1)
		return
	var meta: Dictionary = parsed
	var table: Array = meta.get("hexes", [])
	var seeds: Array[int] = []
	for text: String in _argument("--seeds=", "1480,1481,1482,1483,1484,1485").split(","):
		seeds.append(int(text))
	var total_ms := 0.0
	var bad := 0
	for s: int in seeds:
		var start := Time.get_ticks_usec()
		var imp := WorldImprove.build(table, s)
		var ms := float(Time.get_ticks_usec() - start) / 1000.0
		total_ms += ms
		var breaks := imp.violations()
		bad += breaks.size()
		var summary := imp.summary()
		var goods := int(summary["pieces"]) - imp.count_of(WorldImprove.SETTLEMENT) - imp.count_of(WorldImprove.CASTLE)
		print("seed %d: %.1f ms, %d land hexes, %d settlements, %d castles, %d goods, %d wild; backtracks %d, restarts %d, rule breaks %d, fixed place pairs %d" % [
			s, ms, imp.hexes.size(), imp.count_of(WorldImprove.SETTLEMENT), imp.count_of(WorldImprove.CASTLE), goods,
			int(summary["wild"]), imp.backtracks, imp.restarts, breaks.size(), imp.fixed_conflicts.size()])
		var line := "   "
		var levels: Dictionary = summary["by_level"]
		for f: int in range(WorldImprove.CASTLE, WorldImprove.FAMILIES):
			if imp.count_of(f) > 0:
				line += "%s %s  " % [WorldImprove.NAMES[f], str(levels[WorldImprove.NAMES[f]])]
		print(line)
		for text: String in breaks:
			print("   BREAK ", text)
		if s == seeds[0]:
			_print_map(imp)
	print("mean search time %.1f ms over %d seeds; rule breaks %d" % [total_ms / float(seeds.size()), seeds.size(), bad])
	quit(1 if bad > 0 else 0)


## The map as letters and levels: . wild, # settlement, C castle, then the goods by their first letter (S salt, H harbour).
func _print_map(imp: WorldImprove) -> void:
	var low := Vector2i(999, 999)
	var high := Vector2i(-999, -999)
	for hex: Vector2i in imp.hexes:
		low = Vector2i(mini(low.x, hex.x), mini(low.y, hex.y))
		high = Vector2i(maxi(high.x, hex.x), maxi(high.y, hex.y))
	for r: int in range(low.y, high.y + 1):
		var line := "   " + (" " if (r & 1) == 1 else "")
		for c: int in range(low.x, high.x + 1):
			var hex := Vector2i(c, r)
			if not imp.family.has(hex):
				line += "~ "
			elif imp.family_at(hex) == WorldImprove.NONE:
				line += ". "
			else:
				line += LETTERS[imp.family_at(hex)] + str(imp.level_at(hex))
		print(line)


func _argument(prefix: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
