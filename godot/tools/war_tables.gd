## Prints the three M7 war tables from data/defs/game_defs.tres (docs/architecture/m7-build-spec.md sections 4.3, 4.5 and 4.6):
## the fortresses and their garrisons, the siege's need and crowds, and the fight tables with the kinds of company. The row
## builders are static so tests/core/test_war_defs.gd can check them against the spec.
## Run: godot --headless --path godot -s res://tools/war_tables.gd   (exit 1 when the defs do not validate)
extends SceneTree

const DEFS_PATH := "res://data/defs/game_defs.tres"


func _initialize() -> void:  # not _init: the classes are known to the parser only from here on
	var defs := ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if defs == null:
		printerr("war_tables: cannot load " + DEFS_PATH)
		quit(1)
		return
	for line: String in tables(defs):
		print(line)
	var errors := defs.validate()
	for err: String in errors:
		printerr("war_tables: " + err)
	quit(1 if not errors.is_empty() else 0)


## The three tables in print order.
static func tables(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(fortress_rows(defs))
	lines.append_array(siege_rows(defs))
	lines.append_array(fight_rows(defs))
	return lines


## Table 4.3: one row per fortress level of each family (settlements and castles), with its garrison, reach and regrowth.
static func fortress_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["fortresses (family level -> fortress level; full garrison; holds within; regrows a season)"]
	var war := defs.war
	for f: FamilyDef in defs.families:
		if f == null or f.fortress.is_empty():
			continue
		for level: int in f.fortress.size():
			var fort: int = f.fortress[level]
			if fort <= 0 or war == null:
				continue
			lines.append("%-10s level %d fortress %d garrison %5d holds %d regrows %3d" % [
				String(f.key), level, fort, war.garrison_per_level * fort,
				war.area_reach[fort], war.garrison_regen_per_level * fort,
			])
	return lines


## Table 4.5: the need of each fortress level on plain ground with a full garrison, the crowd bands, the rate cap and the
## stores (the need of hills and highland is added later, by relief).
static func siege_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["sieges (fortress level; need on plain ground, full garrison; stores; rate cap; crowd bands)"]
	var war := defs.war
	if war == null:
		return lines
	for fort: int in range(1, WarDef.FORTRESS_LEVELS):
		lines.append("fortress %d need %d stores %d seasons rate max %d hunger %d crowd bands %s" % [
			fort, war.siege_base_need + war.siege_per_level * fort, 1 + fort, war.siege_rate_max, war.siege_hunger,
			str(Array(war.crowd_bands)),
		])
	return lines


## Table 4.6: the fight tables by branch (attack open, rough, assault; defence open, rough, garrison), the stances, the
## dice, and the kinds of company's attack, defence, fire and siege points.
static func fight_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["fight (branch: attack open rough assault | defence open rough garrison)"]
	var war := defs.war
	if war != null:
		for branch: StringName in WarDef.BRANCHES:
			lines.append("%-9s attack %s | defence %s" % [
				String(branch), str(Array(war.fight_attack.get(branch, PackedInt32Array()))),
				str(Array(war.fight_defence.get(branch, PackedInt32Array()))),
			])
		lines.append("dice %s stance dealt %s taken %s" % [
			str(Array(war.dice_permille)), str(war.stance_dealt), str(war.stance_taken),
		])
	for u: UnitDef in defs.units:
		if u == null:
			continue
		lines.append("%-11s men %3d attack %2d defence %d fire %3d siege %d" % [
			String(u.key), u.men, u.attack, u.defence, u.fire_permille, u.siege_points,
		])
	return lines
