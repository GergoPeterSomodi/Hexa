@warning_ignore_start("integer_division")
## Calibration sweep for the battle's starting bands (docs/architecture/m7-build-spec.md 4.6): for each candidate of data values,
## the attacker's win % of each starting pair on farmland and in woods over a fixed seed list, the share of battles that reach the
## day cap, and the average days. Candidates change copies of WarDef only (never the committed war). Prints a table per candidate.
## Run: godot --headless --path godot -s res://tools/probes/probe_calibrate.gd
extends SceneTree

const SEEDS := 500
const PAIRS: Array = [[3, 3], [4, 3], [5, 3], [6, 3]]


func _initialize() -> void:  # not _init: the classes are known to the parser only from here on
	var candidates: Array = [
		{"name": "woods 350 seeds 500", "set": {}, "woods": 350},
	]
	for c: Dictionary in candidates:
		_report(c)
	quit(0)


func _report(candidate: Dictionary) -> void:
	var war := CombatFixture.war()
	var set_values: Dictionary = candidate["set"]
	for field: String in set_values:
		if field.contains("."):
			var parts := field.split(".")
			var table: Dictionary = (war.get(parts[0]) as Dictionary).duplicate()
			table[StringName(parts[1])] = set_values[field]
			war.set(parts[0], table)
		else:
			if set_values[field] is String:
				war.set(field, PackedInt32Array([1000, 1000, 1000, 1000, 1000, 1000]))
			else:
				war.set(field, set_values[field])
	print("candidate %s  woods %d" % [str(candidate["name"]), int(candidate["woods"])])
	var line := ""
	for pair: Array in PAIRS:
		var farm: Array = _measure(war, int(pair[0]), int(pair[1]), 0, false)
		var woods: Array = _measure(war, int(pair[0]), int(pair[1]), int(candidate["woods"]), true)
		line += "  %dv%d farm %3d%% woods %3d%% cap %2d%% days %.1f\n" % [int(pair[0]), int(pair[1]), int(farm[0]),
				int(woods[0]), int(farm[1]), float(farm[2])]
	print(line)


## [attacker win %, day-cap %, average days] over the fixed seeds.
func _measure(war: WarDef, attackers: int, defenders: int, cover: int, rough: bool) -> Array:
	var fighters: Array = []
	for i: int in attackers:
		fighters.append(CombatFixture.pikemen(1 + i, 0))
	for i: int in defenders:
		fighters.append(CombatFixture.pikemen(10 + i, 1))
	var input := CombatFixture.input_of(war, fighters, cover, rough)
	var wins: int = 0
	var capped: int = 0
	var days_sum: int = 0
	for seed_value: int in range(1, SEEDS + 1):
		var rng := Rng.new()
		rng.seed_with(seed_value)
		var end: Dictionary = Combat.fight(war, input, rng)["end"]
		if int(end["winner"]) == 0:
			wins += 1
		if int(end["days"]) >= war.battle_days:
			capped += 1
		days_sum += int(end["days"])
	return [wins * 100 / SEEDS, capped * 100 / SEEDS, float(days_sum) / SEEDS]
