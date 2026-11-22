## One temperament of the computer's countries (docs/architecture/m8-build-spec.md 4.4 and 5.1), one file each under
## data/defs/tempers/. Ratios and shares are permille, spans are seasons. The temperament a country has is the scenario's
## `tempers` list. Ranges are checked by validate(); the spec's table is checked by test_ai_defs.gd.
@tool
class_name AiTemperDef
extends Resource

@export var key: StringName = &""
@export var name: String = ""
@export var reserve_seasons := 6
@export var payback_max := 40
@export var works_at_war := true
@export var army_permille := 3
@export var war_army_permille := 8
@export var army_upkeep_share := 200
## The companies it wants, permille, by UnitDef id (pikemen, crossbowmen, knights, bombards); sums to 1,000.
@export var mix: PackedInt32Array = PackedInt32Array()
@export var max_wars := 1
@export var rest_seasons := 16
@export var war_chest_seasons := 12
@export var declare_ratio := 2500
@export var busy_bonus := 0
@export var declare_chance := 100
@export var attack_ratio := 1500
@export var siege_max := 4
@export var storm_share := 600
@export var storm_ratio := 1300
@export var relief_ratio := 900
@export var withdraw_ratio := 1100
@export var take_score := 2
@export var tired_seasons := 8
@export var sue_ratio := 1300
@export var yield_after := 8
@export var fortify := false


## Problems found, empty when valid (spec 5.1; `kinds` is GameDefs.units.size(), passed so defs need not name GameDefs: a cycle): the key a lower-case word, a name, a mix of one entry a kind of company
## each 0 to 1,000 summing to 1,000, and a range for every number.
func validate(kinds: int = 4) -> Array[String]:
	var errors: Array[String] = []
	var label := String(key)
	if key == &"" or not _is_key(label):
		errors.append("temper '%s': key is not a lower-case word" % label)
	if name.strip_edges().is_empty():
		errors.append("temper '%s': name is empty" % label)
	if mix.size() != kinds:
		errors.append("temper '%s': mix has %d entries, expected %d" % [label, mix.size(), kinds])
	else:
		var total := 0
		for i: int in mix.size():
			_range(errors, label, "mix[%d]" % i, mix[i], 0, 1000)
			total += mix[i]
		if total != 1000:
			errors.append("temper '%s': mix sums to %d, expected 1000" % [label, total])
	_range(errors, label, "reserve_seasons", reserve_seasons, 0, 40)
	_range(errors, label, "payback_max", payback_max, 1, 400)
	_range(errors, label, "army_permille", army_permille, 0, 100)
	_range(errors, label, "war_army_permille", war_army_permille, 0, 100)
	if war_army_permille < army_permille:
		errors.append("temper '%s': war_army_permille %d should not be under army_permille %d" % [
			label, war_army_permille, army_permille])
	_range(errors, label, "army_upkeep_share", army_upkeep_share, 0, 1000)
	_range(errors, label, "storm_share", storm_share, 0, 1000)
	_range(errors, label, "max_wars", max_wars, 0, 5)
	for field: String in ["rest_seasons", "war_chest_seasons", "tired_seasons", "yield_after"]:
		_range(errors, label, field, int(get(field)), 0, 80)
	for field: String in ["declare_ratio", "attack_ratio", "storm_ratio", "relief_ratio", "withdraw_ratio", "sue_ratio"]:
		_range(errors, label, field, int(get(field)), 100, 10000)
	_range(errors, label, "declare_chance", declare_chance, 0, 1000)
	_range(errors, label, "busy_bonus", busy_bonus, 0, maxi(declare_ratio, 0))
	_range(errors, label, "siege_max", siege_max, 1, 20)
	_range(errors, label, "take_score", take_score, 1, 20)
	return errors


static func _is_key(text: String) -> bool:
	for i: int in text.length():
		var c := text.unicode_at(i)
		var letter := c >= 97 and c <= 122
		if not (letter or (i > 0 and (c == 95 or (c >= 48 and c <= 57)))):
			return false
	return true


func _range(errors: Array[String], label: String, field: String, value: int, low: int, high: int) -> void:
	if value < low or value > high:
		errors.append("temper '%s': %s is %d, expected %d to %d" % [label, field, value, low, high])
