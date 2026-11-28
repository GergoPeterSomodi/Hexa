## Prints the two tables of the AI's numbers (docs/architecture/m8-build-spec.md 4.4) as Markdown from
## data/defs/game_defs.tres: the temperaments, one column each, and the numbers they share. The row builders are static so
## tests/core/test_ai_defs.gd can check them against the spec.
## Run: godot --headless --path godot -s res://tools/ai_tables.gd   (exit 1 when the defs do not validate)
extends SceneTree

const DEFS_PATH := "res://data/defs/game_defs.tres"
## The temperament fields in the order of the spec's table.
const TEMPER_FIELDS: Array[String] = [
	"reserve_seasons", "payback_max", "works_at_war", "army_permille", "war_army_permille", "army_upkeep_share", "mix",
	"max_wars", "rest_seasons", "war_chest_seasons", "declare_ratio", "busy_bonus", "declare_chance", "attack_ratio",
	"siege_max", "storm_share", "storm_ratio", "relief_ratio", "withdraw_ratio", "take_score", "tired_seasons",
	"sue_ratio", "yield_after", "fortify",
]
const SHARED_FIELDS: Array[String] = [
	"think_every", "min_upkeep", "min_army_men", "min_war_men", "threat_permille", "threat_range", "prize_range",
	"attack_range", "relief_range", "target_range", "relief_last", "rest_morale", "switch_permille", "scan_hexes",
	"scan_per_step", "works_cards", "works_per_season", "raises_peace", "raises_war", "companies_per_barracks",
	"merges_per_season", "order_tries", "food_priority", "walls_priority", "fortify_priority", "jitter_permille",
	"disband_surplus", "peace_order_every", "yield_ratio",
]


func _initialize() -> void:  # not _init: the classes are known to the parser only from here on
	var defs := ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if defs == null:
		printerr("ai_tables: cannot load " + DEFS_PATH)
		quit(1)
		return
	for line: String in tables(defs):
		print(line)
	var errors := defs.validate()
	for err: String in errors:
		printerr("ai_tables: " + err)
	quit(1 if not errors.is_empty() else 0)


## Both tables in print order, with a blank line between.
static func tables(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(temper_rows(defs))
	lines.append("")
	lines.append_array(shared_rows(defs))
	return lines


## Table 4.4's temperament grid: a header, a rule and one row a field, one column a temperament.
static func temper_rows(defs: GameDefs) -> Array[String]:
	var head := "| Field |"
	var rule := "|---|"
	for t: AiTemperDef in defs.tempers:
		head += " %s |" % String(t.key)
		rule += "---|"
	var lines: Array[String] = [head, rule]
	for field: String in TEMPER_FIELDS:
		var row := "| `%s` |" % field
		for t: AiTemperDef in defs.tempers:
			row += " %s |" % _text(t.get(field))
		lines.append(row)
	return lines


## The shared numbers: a header, a rule and one row a field.
static func shared_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["| Field | Value |", "|---|---|"]
	if defs.ai == null:
		return lines
	for field: String in SHARED_FIELDS:
		lines.append("| `%s` | %s |" % [field, _text(defs.ai.get(field))])
	return lines


static func _text(value: Variant) -> String:
	if value is bool:
		return "yes" if value else "no"
	if value is PackedInt32Array:
		var parts: PackedStringArray = []
		for n: int in value:
			parts.append(str(n))
		return ", ".join(parts)
	return str(value)
