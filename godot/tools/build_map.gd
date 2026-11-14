## Builds Europe 1480 from the godot/data inputs with the fixed map seed and prints every count beside the Python
## reference (godot/data/map_reference.json): the equal facts, the ranges of the close counts, the owners and the build
## time. Steps 1 and 2 of the map builder (land, then provinces, countries, towns, castles, roads and starting units).
## Run: godot --headless --path godot -s res://tools/build_map.gd   (exit status 1 when a checked count is out of range)
extends SceneTree

const REFERENCE := "res://data/map_reference.json"


func _init() -> void:
	var started := Time.get_ticks_msec()
	var data := EuropeData.load_europe()
	var seed := _seed_argument()
	if seed >= 0:
		data.map_seed = seed  # another seed for the contact sheet (run with: -- --seed=N)
	var map := MapBuilder.build_europe(data)
	var elapsed := Time.get_ticks_msec() - started
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE))
	var counts := MapCounts.new(map, reference)
	var rows := counts.run()
	_print_table(rows)
	print("build time: %d ms (headless, one build, map seed %d)" % [elapsed, map.map_seed])
	var failed := MapCounts.failures(rows)
	print("map check: %d count(s) out of range of %d checked" % [failed, _checked(rows)])
	quit(1 if failed > 0 else 0)


## The seed given with --seed=N after the user arguments (the constants.json map seed when none is given).
func _seed_argument() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.substr(7))
	return -1


func _print_table(rows: Array[MapCounts.Row]) -> void:
	print("%-30s %-34s %-44s %s" % ["count", "godot", "python (reference)", ""])
	var group := ""
	for row: MapCounts.Row in rows:
		if row.group != group:
			group = row.group
			print("-- %s" % _group_title(group))
		var status := "info"
		if row.group != MapCounts.GROUP_INFO:
			status = "OK" if row.ok else "OUT"
		print("%-30s %-34s %-44s %s" % [row.label, row.godot, row.reference, status])


func _checked(rows: Array[MapCounts.Row]) -> int:
	var n := 0
	for row: MapCounts.Row in rows:
		if row.group != MapCounts.GROUP_INFO:
			n += 1
	return n


static func _group_title(group: String) -> String:
	if group == MapCounts.GROUP_EQUAL:
		return "must be equal"
	if group == MapCounts.GROUP_CLOSE:
		return "must be close (luck moves them in Python too)"
	return "for information"
