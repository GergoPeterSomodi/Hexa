## Builds Europe 1480 from the godot/data inputs with the fixed map seed, prints the counts beside the Python reference
## (godot/data/map_reference.json) and the build time. Only the land layers so far (step 1 of the map builder).
## Run: godot --headless --path godot -s res://tools/build_map.gd   (exit status 1 when an equal count differs)
extends SceneTree

const REFERENCE := "res://data/map_reference.json"


func _init() -> void:
	var started := Time.get_ticks_msec()
	var data := EuropeData.load_europe()
	var map := MapBuilder.build_europe(data)
	var elapsed := Time.get_ticks_msec() - started
	var failed := _report(map, elapsed)
	quit(1 if failed > 0 else 0)


func _report(map: MapData, elapsed_ms: int) -> int:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE))
	var equal: Dictionary = reference["equal"]
	var grid_ref: Array = _ref_value(equal, "grid")
	var class_ref: Dictionary = _ref_value(equal, "hex_classes")
	var city_ref: Array = _ref_value(equal, "cities")
	var classes := map.class_counts()
	var rows: Array[Array] = [
		["grid", "%dx%d" % [map.cols, map.rows], "%dx%d" % [int(grid_ref[0]), int(grid_ref[1])]],
		["land", str(classes["land"]), str(class_ref["land"])],
		["ocean", str(classes["ocean"]), str(class_ref["ocean"])],
		["lake", str(classes["lake"]), str(class_ref["lake"])],
		["coastal land", str(map.coastal_land().size()), str(_ref_value(equal, "coastal_provinces"))],
		["cities", str(map.city_names.size()), str(city_ref.size())],
		["rivers", str(map.rivers.size()), str(_ref_value(equal, "rivers"))],
		["river hexes", str(map.river_at.size()), str(_ref_value(equal, "river_hexes"))],
		["ridge edges", str(map.ridge_edges.size()), str(_ref_value(equal, "ridge_edges"))],
		["pass edges", str(map.pass_names.size()), str(_ref_value(equal, "pass_edges"))],
		["passes (hexes)", str(map.pass_hexes.size()), str(_ref_value(equal, "passes"))],
	]
	var failed := 0
	print("%-16s %10s %10s" % ["fact", "godot", "python"])
	for row: Array in rows:
		var godot_text: String = str(row[1])
		var python_text: String = str(row[2])
		var ok: bool = godot_text == python_text or (godot_text.is_valid_float() and python_text.is_valid_float()
				and is_equal_approx(godot_text.to_float(), python_text.to_float()))
		if not ok:
			failed += 1
		print("%-16s %10s %10s %s" % [row[0], row[1], row[2], "" if ok else "DIFFERS"])
	print("terrain mix (land hexes): godot, python median")
	var mix := map.terrain_counts()
	var close: Dictionary = reference["close"]["terrain_mix"]
	var kinds: Array[String] = []
	for kind: String in mix.keys():
		kinds.append(kind)
	kinds.sort()
	for kind: String in kinds:
		var median_fact: Dictionary = close[kind]
		print("  %-10s %6d  %8.1f" % [kind, int(mix[kind]), float(median_fact["median"])])
	print("build time: %d ms (headless, one build, map seed %d)" % [elapsed_ms, map.map_seed])
	print("step 1 check: %d fact(s) differ" % failed)
	return failed


static func _ref_value(equal: Dictionary, key: String) -> Variant:
	var fact: Dictionary = equal[key]
	return fact["value"]
