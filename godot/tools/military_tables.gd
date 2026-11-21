## Prints the two M6 tables from data/defs/game_defs.tres (docs/architecture/m6-build-spec.md sections 4.2 and 4.3): the
## kinds of company and the ground, and then the step, supply and sight numbers beside them. The row builders are static so
## tests/core/test_unit_defs.gd and test_terrain_defs.gd can check them against the spec.
## Run: godot --headless --path godot -s res://tools/military_tables.gd   (exit 1 when the defs do not validate)
extends SceneTree

const DEFS_PATH := "res://data/defs/game_defs.tres"


func _initialize() -> void:  # not _init: the classes are known to the parser only from here on
	var defs := ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if defs == null:
		printerr("military_tables: cannot load " + DEFS_PATH)
		quit(1)
		return
	for line: String in tables(defs):
		print(line)
	var errors := defs.validate()
	for err: String in errors:
		printerr("military_tables: " + err)
	quit(1 if not errors.is_empty() else 0)


## Both tables and the numbers, in print order.
static func tables(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(unit_rows(defs))
	lines.append_array(terrain_rows(defs))
	lines.append_array(number_rows(defs))
	return lines


## The header, then one row per kind in id order: id, key, name, one, many, branch, men, raise cost, goods, upkeep, move
## points, sight, the level that raises it, refill.
static func unit_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["units (id key name; one, many; branch men raise goods upkeep mp sight from-level refill)"]
	for u: UnitDef in defs.units:
		if u == null:
			lines.append("(null unit)")
			continue
		var goods: Array[String] = []
		for good_key: String in u.cost_goods:
			goods.append("%d %s" % [int(u.cost_goods[good_key]), good_key])
		lines.append("%d %-11s %-11s %s, %s | %-9s men %3d raise %2d goods %-14s upkeep %2d mp %2d sight %d level %d refill %2d" % [
			u.id, String(u.key), u.name, u.one, u.many, String(u.branch), u.men, u.cost, ", ".join(goods), u.upkeep,
			u.mp, u.sight, u.min_level, u.refill,
		])
	return lines


## The header, then one row per cover in cover order: id, key, move points to enter, forage permille.
static func terrain_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["ground (cover key move forage)"]
	for t: TerrainDef in defs.terrains:
		if t == null:
			lines.append("(null terrain)")
			continue
		lines.append("%d %-9s move %d forage %3d" % [t.id, String(t.key), t.move, t.forage_permille])
	return lines


## The step cost, supply, forage and sight numbers of GameDefs, one line each.
static func number_rows(defs: GameDefs) -> Array[String]:
	return [
		"step relief_add %s highway %d road %d track_div %d winter_snow %d pass_closing %d" % [
			str(Array(defs.relief_move_add)), defs.highway_cap, defs.road_cap, defs.track_divisor,
			defs.winter_snow_percent, defs.pass_closing_climate],
		"rivers stream %d river %d ford %d ferry %d wade_class %d wall_class %d wade_plan %d" % [
			defs.stream_cost, defs.river_cost, defs.ford_cost, defs.ferry_cost, defs.river_wade_class,
			defs.river_wall_class, defs.wade_plan_cost],
		"supply reach %d wade %d depot_level %d army_food_milli %d forage %s loss %d starve %s" % [
			defs.supply_reach, defs.supply_wade_cost, defs.depot_min_level, defs.army_food_milli,
			str(Array(defs.forage_percent)), defs.forage_loss_permille, str(Array(defs.starve_permille))],
		"armies stack %d march_max %d wait_ratio %d wait_extra %d land_sight %d" % [
			defs.stack_limit, defs.march_seasons_max, defs.wait_ratio_percent, defs.wait_extra_seasons, defs.land_sight],
	]
