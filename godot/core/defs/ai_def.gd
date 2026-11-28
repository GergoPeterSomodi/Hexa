## The numbers every temperament shares (docs/architecture/m8-build-spec.md 4.4 and 5.1). Stored in data/defs/ai.tres and
## read by GameDefs.ai. Permille fields are shares or ratios of 1,000; the rest are hexes, men, seasons or counts. Ranges
## are checked by validate(); the spec's table is checked by test_ai_defs.gd.
@tool
class_name AiDef
extends Resource

@export var think_every := 4
@export var min_upkeep := 10
@export var min_army_men := 500
@export var min_war_men := 1000
@export var threat_permille := 1500
@export var threat_range := 3
@export var prize_range := 3
@export var attack_range := 6
@export var relief_range := 8
@export var target_range := 12
@export var relief_last := 600
@export var rest_morale := 600
@export var switch_permille := 1300
@export var scan_hexes := 48
@export var scan_per_step := 24
@export var works_cards := 4
@export var works_per_season := 2
@export var raises_peace := 2
@export var raises_war := 4
## The companies of the war goal of men that one barracks is wanted for (docs/design/recruitment-queue.md section 7).
@export var companies_per_barracks := 4
@export var merges_per_season := 4
@export var order_tries := 2
@export var food_priority := 3000
@export var walls_priority := 2000
@export var fortify_priority := 2000
@export var jitter_permille := 50
@export var disband_surplus := 2000
@export var peace_order_every := 1
@export var yield_ratio := 2000


## Problems found, empty when valid (spec 5.1): think_every 1 to 20, peace_order_every 1 to 4, the ranges 1 to 40,
## scan_per_step 1 to scan_hexes, the counts 0 to 20 (companies_per_barracks is a divisor: 1 to 20), the permilles 0 to
## 10,000 (a priority is a divisor: 1 or more),
## rest_morale 0 to 1,000, jitter 0 to 500.
func validate() -> Array[String]:
	var errors: Array[String] = []
	_range(errors, "think_every", think_every, 1, 20)
	_range(errors, "peace_order_every", peace_order_every, 1, 4)
	_range(errors, "min_upkeep", min_upkeep, 0, 10000)
	_range(errors, "min_army_men", min_army_men, 0, 100000)
	_range(errors, "min_war_men", min_war_men, 0, 100000)
	for field: String in ["threat_range", "prize_range", "attack_range", "relief_range", "target_range"]:
		_range(errors, field, int(get(field)), 1, 40)
	_range(errors, "scan_hexes", scan_hexes, 1, 10000)
	_range(errors, "scan_per_step", scan_per_step, 1, maxi(scan_hexes, 1))
	for field: String in ["works_cards", "works_per_season", "raises_peace", "raises_war", "merges_per_season", "order_tries"]:
		_range(errors, field, int(get(field)), 0, 20)
	_range(errors, "companies_per_barracks", companies_per_barracks, 1, 20)
	for field: String in ["threat_permille", "relief_last", "switch_permille", "disband_surplus", "yield_ratio"]:
		_range(errors, field, int(get(field)), 0, 10000)
	for field: String in ["food_priority", "walls_priority", "fortify_priority"]:
		_range(errors, field, int(get(field)), 1, 10000)
	_range(errors, "rest_morale", rest_morale, 0, 1000)
	_range(errors, "jitter_permille", jitter_permille, 0, 500)
	return errors


func _range(errors: Array[String], field: String, value: int, low: int, high: int) -> void:
	if value < low or value > high:
		errors.append("ai: %s is %d, expected %d to %d" % [field, value, low, high])
