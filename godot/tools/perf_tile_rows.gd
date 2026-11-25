## The tile window's Buildings rows (tile window spec 8, TW5): TileBuildings.of on the hex with the most build options of
## the largest country, uncached (the game version bumped each run), in two forms: the light rows (tile_buildings_ms) and
## the full rows with every gain and the summary (tile_buildings_gains_ms). Called by tools/perf_core.gd after the
## previews; it writes its numbers and the row count into the results it is given. Headless, no GUT.
class_name PerfTileRows
extends RefCounted

const RUNS := 20
const COLS := 494
const ROWS := 247
const SEED := 1480
const COUNTRIES := 60
const PER_COUNTRY := 10
const GAME_DEFS := "res://data/defs/game_defs.tres"
const KEYS: Array[String] = ["tile_buildings_ms", "tile_buildings_gains_ms"]


static func measure(game: Game, tag: StringName, results: Dictionary) -> void:
	var hex := _most_options(game, tag)
	if hex == Vector2i(-1, -1):
		results["tile_buildings_ms"] = 0.0
		results["tile_buildings_gains_ms"] = 0.0
		results["tile_buildings_rows"] = 0
		return
	results["tile_buildings_rows"] = _row_count(TileBuildings.of(game, tag, hex, true))
	results["tile_buildings_ms"] = _worst_ms(game, tag, hex, false)
	results["tile_buildings_gains_ms"] = _worst_ms(game, tag, hex, true)


static func _worst_ms(game: Game, tag: StringName, hex: Vector2i, full: bool) -> float:
	var total := 0
	for n: int in RUNS:
		game.version += 1
		var t := Time.get_ticks_usec()
		TileBuildings.of(game, tag, hex, full)
		total += Time.get_ticks_usec() - t
	return float(total) / 1000.0 / float(RUNS)


static func _row_count(tile: Dictionary) -> int:
	var n := 0
	for group: Dictionary in tile.get("groups", []):
		n += (group["rows"] as Array).size()
	return n


static func _most_options(game: Game, tag: StringName) -> Vector2i:
	var c := Countries.by_tag(game, tag)
	var hex := Vector2i(-1, -1)
	var most := 0
	if c == null:
		return hex
	for i: int in Territory.districts(game, c.id):
		var n := Improve.build_options(game, game.map.hex_of(i)).size()
		if n > most:
			most = n
			hex = game.map.hex_of(i)
	return hex


## perf_core --only=tile: the two rows alone, on the fake world of perf_core's _measure (no works begun, no later rows), against
## their limits in the budget (times the cpu scale). Prints each row and returns 0 within the limits, else 1.
static func only(cpu_scale: float, budget_path: String) -> int:
	var map := FakeMap.build(COLS, ROWS, SEED)
	var built := FakeScenario.build(map, COUNTRIES, SEED)
	var defs := built["defs"] as GameDefs
	var real := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if real == null or real.families.size() != FamilyIds.COUNT - 1:
		printerr("perf_tile_rows: cannot load the families of %s" % GAME_DEFS)
		return 1
	defs.families = real.families
	defs.goods = real.goods
	defs.work_slots_base = PER_COUNTRY
	var game := Game.new_scenario(map, defs, built["scenario"] as ScenarioDef, SEED)
	var tag := _largest(game)
	var results := {}
	measure(game, tag, results)
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(budget_path))
	var limits: Dictionary = parsed.get("limits", {})
	var failed := 0
	for key: String in KEYS:
		var limit := float((limits[key] as Dictionary)["limit"]) * cpu_scale
		var value := float(results[key])
		var verdict := "ok" if value <= limit else "FAIL"
		if value > limit:
			failed += 1
		print("%s %.3f ms (limit %.2f): %s" % [key, value, limit, verdict])
	print("tile_buildings_rows %d, largest %s, hexes %d" % [int(results["tile_buildings_rows"]), tag, map.hex_count()])
	return 0 if failed == 0 else 1


static func _largest(game: Game) -> StringName:
	var best := &""
	var most := -1
	for c: Country in game.countries:
		var n := Territory.districts(game, c.id).size()
		if n > most:
			most = n
			best = c.tag
	return best
