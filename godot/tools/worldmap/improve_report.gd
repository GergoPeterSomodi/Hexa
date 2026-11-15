## The improvement step on a map file (MapData), in numbers: per seed the search time, the backtracks, the pieces by family
## and level, the rule breaks (none expected), and a small map of letters. Headless:
##   godot --headless --path godot -s res://tools/worldmap/improve_report.gd -- [--map=<path of a MapData file>] [--window=x,y,w,h] [--seeds=1,2,3]
extends SceneTree

const MAP := "res://data/maps/north_italy.tres"
const LETTERS: Array[String] = [".", "#", "C", "w", "h", "s", "d", "v", "o", "g", "t", "m", "q", "S", "H"]


func _init() -> void:
	var path := _argument("--map=", MAP)
	var map := load(path) as MapData
	if map == null:
		printerr("improve report: %s does not load" % path)
		quit(1)
		return
	var region: Dictionary = {}
	var window := _argument("--window=", "")
	if window != "":
		var parts := window.split(",")
		if parts.size() == 4:
			region = WorldImprove.window(Rect2i(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])))
	var seeds: Array[int] = []
	for text: String in _argument("--seeds=", "1480,1481,1482,1483,1484,1485").split(","):
		seeds.append(int(text))
	var total_ms := 0.0
	var bad := 0
	for s: int in seeds:
		var start := Time.get_ticks_usec()
		var imp := WorldImprove.build(map, s, null, region)
		var ms := float(Time.get_ticks_usec() - start) / 1000.0
		total_ms += ms
		var breaks := imp.violations()
		bad += breaks.size()
		var summary := imp.summary()
		var goods := int(summary["pieces"]) - imp.count_of(ImproveRules.SETTLEMENT) - imp.count_of(ImproveRules.CASTLE)
		print("seed %d: %.1f ms, %d land hexes, %d settlements, %d castles, %d goods, %d wild; backtracks %d, restarts %d, rule breaks %d, fixed place pairs %d" % [
			s, ms, imp.hexes.size(), imp.count_of(ImproveRules.SETTLEMENT), imp.count_of(ImproveRules.CASTLE), goods,
			int(summary["wild"]), imp.backtracks, imp.restarts, breaks.size(), imp.fixed_conflicts.size()])
		var line := "   "
		var levels: Dictionary = summary["by_level"]
		for f: int in range(ImproveRules.CASTLE, ImproveRules.FAMILIES):
			if imp.count_of(f) > 0:
				line += "%s %s  " % [ImproveRules.NAMES[f], str(levels[ImproveRules.NAMES[f]])]
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
			if not imp.map.is_land(hex):
				line += "~ "
			elif imp.family_at(hex) == ImproveRules.NONE:
				line += ". "
			else:
				line += LETTERS[imp.family_at(hex)] + str(imp.level_at(hex))
		print(line)


func _argument(prefix: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
