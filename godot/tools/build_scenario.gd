## Rebuilds or validates ScenarioDef resources (docs/architecture/m2-build-spec.md sections 4.2, 8.2, and 8.3).
## Run (from the repository root, GODOT set):
##   "$GODOT" --headless --path godot -s res://tools/build_scenario.gd [-- --scenario=north_italy_1480]
##   "$GODOT" --headless --path godot -s res://tools/build_scenario.gd -- --check
## Options: --defs=<path> --maps-dir=<path> --scenarios-dir=<path> --out=<path>
extends SceneTree

const DEFAULT_DEFS := "res://data/defs/game_defs.tres"
const DEFAULT_MAPS_DIR := "res://data/maps"
const DEFAULT_SCENARIOS_DIR := "res://data/scenarios"
## The region source (fog spec section 4): scenarios whose every hex lies in one region, by scenario id. Every hex, sea
## too, takes that region's byte (its index in `regions` + 1). A scenario not listed keeps its `region` as it is; the
## Europe map (later) rasterises its regions from lon/lat polygons instead.
const ALL_HEXES_IN := {"north_italy_1480": &"europe"}


func _initialize() -> void:
	var opts := _parse_args(OS.get_cmdline_user_args())
	var check := bool(opts["check"])
	var defs_path := str(opts["defs"])
	var maps_dir := str(opts["maps_dir"])
	var scenarios_dir := str(opts["scenarios_dir"])
	var scenario_filter := str(opts["scenario"])
	var out_path := str(opts["out"])

	if check and not _has_resource(defs_path):
		var found := _list_tres(scenarios_dir)
		if found.is_empty():
			print("build_scenario: no scenarios yet in %s (skipping check)" % scenarios_dir)
			quit(0)
			return
		printerr("build_scenario: scenarios exist in %s but %s is missing" % [scenarios_dir, defs_path])
		quit(1)
		return

	var defs := ResourceLoader.load(defs_path, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if defs == null:
		printerr("build_scenario: cannot load GameDefs from %s" % defs_path)
		quit(1)
		return
	var defs_errors := defs.validate()
	if not defs_errors.is_empty():
		for err: String in defs_errors:
			printerr("build_scenario: %s: %s" % [defs_path, err])
		quit(1)
		return

	var targets := _select_scenarios(defs, scenario_filter)
	if targets.is_empty():
		if check and scenario_filter == "" and _list_tres(scenarios_dir).is_empty():
			print("build_scenario: no scenarios listed in %s (skipping check)" % defs_path)
			quit(0)
			return
		printerr("build_scenario: no matching scenarios found" + (
			"" if scenario_filter == "" else " for --scenario=%s" % scenario_filter))
		quit(1)
		return
	if out_path != "" and targets.size() != 1:
		printerr("build_scenario: --out requires a single --scenario")
		quit(1)
		return

	var exit_code := _run_targets(targets, defs, maps_dir, scenarios_dir, out_path, check)
	quit(exit_code)


func _run_targets(targets: Array[ScenarioDef], defs: GameDefs, maps_dir: String, scenarios_dir: String,
		out_path: String, check: bool) -> int:
	for scenario: ScenarioDef in targets:
		var map_path := maps_dir.path_join("%s.tres" % scenario.map_id)
		var map := ResourceLoader.load(map_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
		if map == null:
			printerr("build_scenario: cannot load MapData %s for scenario %s" % [map_path, scenario.id])
			return 1
		if ALL_HEXES_IN.has(scenario.id) and scenario.regions.find(StringName(ALL_HEXES_IN[scenario.id])) < 0:
			printerr("build_scenario: %s: regions do not name the region source '%s'" % [
				scenario.id, str(ALL_HEXES_IN[scenario.id])])
			return 1
		if not check:
			rebuild_scenario(scenario, map)
		var errors := scenario.validate(map, defs, true)
		if not errors.is_empty():
			for err: String in errors:
				printerr("build_scenario: %s: %s" % [scenario.id, err])
			return 1
		if check:
			var source := region_source(scenario, map)
			if not source.is_empty() and source != scenario.region:
				printerr("build_scenario: %s: region differs from the region source (run build_scenario.gd)" % scenario.id)
				return 1
			print("build_scenario: %s is current (digest %s)" % [scenario.id, scenario.digest()])
			continue
		var save_path := out_path if out_path != "" else (
			scenario.resource_path if scenario.resource_path != "" else scenarios_dir.path_join("%s.tres" % scenario.id))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
		var err := ResourceSaver.save(scenario, save_path)
		if err != OK:
			printerr("build_scenario: cannot save %s (error %d)" % [save_path, err])
			return 1
		print("build_scenario: wrote %s (digest %s)" % [save_path, scenario.digest()])
		_print_summary_table(map, defs, scenario)
	return 0


## Regrows `scenario.owner`, stamps `scenario.map_digest` and writes `scenario.region` from the region source. `regions`,
## `discovery`, `tempers` and `start_armies` (M8 spec 4.4, 7; fog spec R5) are written by hand and kept as they are;
## validate() checks them.
static func rebuild_scenario(scenario: ScenarioDef, map: MapData) -> void:
	scenario.owner = ScenarioGrowth.grow(map, scenario)
	scenario.map_digest = map.digest()
	var source := region_source(scenario, map)
	if not source.is_empty():
		scenario.region = source


## The `region` bytes the source gives `scenario` on `map` (ALL_HEXES_IN), or empty when the source names none for it.
static func region_source(scenario: ScenarioDef, map: MapData) -> PackedByteArray:
	var out := PackedByteArray()
	if not ALL_HEXES_IN.has(scenario.id):
		return out
	var k := scenario.regions.find(StringName(ALL_HEXES_IN[scenario.id]))
	if k < 0:
		return out
	out.resize(map.hex_count())
	for i: int in map.hex_count():
		out[i] = k + 1
	return out


## Computes per-country district and town counts (section 4.2 table).
static func summary_rows(map: MapData, defs: GameDefs, scenario: ScenarioDef) -> Array[Dictionary]:
	var count := scenario.countries.size()
	var districts := PackedInt32Array()
	districts.resize(count + 1)
	var towns := PackedInt32Array()
	towns.resize(count + 1)
	var cities := PackedInt32Array()
	cities.resize(count + 1)
	var n := mini(map.hex_count(), scenario.owner.size())
	for i: int in n:
		if map.land[i] == 1:
			var oid := int(scenario.owner[i])
			if oid >= 0 and oid <= count:
				districts[oid] += 1
	for pl: Dictionary in map.places:
		var lv := int(pl.get("level", 0))
		if lv < 1:
			continue
		var hv: Variant = pl.get("hex", ScenarioDef.NO_HEX)
		if not (hv is Vector2i):
			continue
		var idx := map.index_of(hv as Vector2i)
		if idx < 0 or idx >= scenario.owner.size():
			continue
		var oid := int(scenario.owner[idx])
		if oid >= 0 and oid <= count:
			towns[oid] += 1
			if lv >= 4:
				cities[oid] += 1
	var rows: Array[Dictionary] = []
	for i: int in count:
		var cid := i + 1
		var tag := scenario.countries[i]
		var cdef := defs.country(tag) if defs != null else null
		var cap := scenario.capitals[i] if i < scenario.capitals.size() else ScenarioDef.NO_HEX
		rows.append({
			"id": cid,
			"tag": String(tag),
			"name": cdef.name if cdef != null else String(tag),
			"long_name": cdef.long_name if cdef != null else "",
			"capital": "%d,%d" % [cap.x, cap.y] if cap != ScenarioDef.NO_HEX else (
				(cdef.capital_name + " (off-map)") if cdef != null else "off-map"),
			"districts": districts[cid],
			"towns": towns[cid],
			"cities": cities[cid],
		})
	return rows


static func _print_summary_table(map: MapData, defs: GameDefs, scenario: ScenarioDef) -> void:
	print("Id | Tag | Name | Long name | Capital | Districts | Towns (level 4+)")
	var total_owned := 0
	for row: Dictionary in summary_rows(map, defs, scenario):
		total_owned += int(row["districts"])
		print("%d | %s | %s | %s | %s | %d | %d (%d)" % [
			int(row["id"]), str(row["tag"]), str(row["name"]), str(row["long_name"]),
			str(row["capital"]), int(row["districts"]), int(row["towns"]), int(row["cities"]),
		])
	var land_total := 0
	for i: int in map.hex_count():
		if map.land[i] == 1:
			land_total += 1
	print("Totals: %d owned / %d land hexes (%d unowned)" % [total_owned, land_total, land_total - total_owned])


static func _parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {
		"check": false,
		"defs": DEFAULT_DEFS,
		"maps_dir": DEFAULT_MAPS_DIR,
		"scenarios_dir": DEFAULT_SCENARIOS_DIR,
		"scenario": "",
		"out": "",
	}
	for arg: String in args:
		if arg == "--check":
			out["check"] = true
		elif arg.begins_with("--defs="):
			out["defs"] = arg.substr(7)
		elif arg.begins_with("--maps-dir="):
			out["maps_dir"] = arg.substr(11)
		elif arg.begins_with("--scenarios-dir="):
			out["scenarios_dir"] = arg.substr(16)
		elif arg.begins_with("--scenario="):
			out["scenario"] = arg.substr(11)
		elif arg.begins_with("--out="):
			out["out"] = arg.substr(6)
	return out


static func _select_scenarios(defs: GameDefs, filter_id: String) -> Array[ScenarioDef]:
	if filter_id == "":
		return defs.scenarios
	var found := defs.scenario(filter_id)
	if found == null:
		return []
	return [found]


static func _has_resource(res_path: String) -> bool:
	if ResourceLoader.exists(res_path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(res_path))


static func _list_tres(res_dir: String) -> Array[String]:
	var found: Array[String] = []
	var abs_dir := ProjectSettings.globalize_path(res_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return found
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			found.append(res_dir.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found
