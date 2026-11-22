## Every number of the war in one inspector (docs/architecture/m7-build-spec.md sections 4.3 to 4.9 and 5.1). Stored in
## data/defs/war.tres and read by GameDefs.war. The unit numbers of the war are UnitDef's (attack, defence, fire, siege
## points), the ground's are TerrainDef's (defence, rough, narrow) and the fortress levels are FamilyDef's (fortress).
## Permille fields are shares or multipliers of 1,000 as the spec says; a count is a whole number of men, seasons,
## days or points. Sizes and ranges are checked by validate(); the spec's tables are checked by test_war_defs.gd.
@tool
class_name WarDef
extends Resource

const BRANCHES: Array[StringName] = [&"infantry", &"missile", &"cavalry", &"artillery"]
const STANCES: Array[StringName] = [&"attack", &"hold", &"withdraw"]
## The ground keys of odds_ground (4.6): the hex's key for the odds (open ground is the 1,000 base).
const ODDS_GROUNDS: Array[StringName] = [&"open", &"hills", &"woods", &"marsh", &"mountains", &"snow"]
const RELIEF_LEVELS := 7
const RANK_COUNT := 3
const FORTRESS_LEVELS := 4
const DICE_COUNT := 6
const FIGHT_COUNT := 3
const MAX_PERMILLE := 1000
const MAX_FIGHT := 4000
## The longest battle a record keeps: BattleRecord.MAX_DAYS (core/state/battle_record.gd). defs sit below state and cannot
## read it, so the value is written here and the test that checks it (test_war_defs.gd) reads both.
const MAX_BATTLE_DAYS := 8
## The ceiling of a count of men or of a large number in the war (the ranges below).
const MAX_COUNT := 100000

# The fight: the bases of a hit and the fight's shares (4.6).
@export var shock_permille := 80
@export var backline_permille := 40
@export var flank_permille := 1250
@export var pikes_vs_horse_permille := 1250
## branch -> [open, rough, assault] for attack and [open, rough, garrison] for defence.
@export var fight_attack: Dictionary[StringName, PackedInt32Array] = {}
@export var fight_defence: Dictionary[StringName, PackedInt32Array] = {}
## stance -> permille of a hit it deals and takes (attack, hold, withdraw).
@export var stance_dealt: Dictionary[StringName, int] = {}
@export var stance_taken: Dictionary[StringName, int] = {}
@export var dice_permille: PackedInt32Array = PackedInt32Array()
@export var hit_spread_permille := 500
# Morale and the days of a battle.
@export var morale_per_loss := 5
@export var front_drain := 20
@export var reserve_drain := 30
@export var hunger_drain := 30
@export var reserve_shaken_permille := 500
@export var flank_morale := 100
@export var centre_shock := 250
@export var flee_morale := 100
@export var flee_pursuit_permille := 150
@export var flee_morale_left := 150
@export var withdraw_day := 2
@export var withdraw_pursuit_permille := 50
@export var withdraw_pursuit_attacker_permille := 100
@export var withdraw_morale := 250
@export var battle_days := 8
@export var wounded_share_permille := 500
@export var wounded_return_permille := 500
@export var attack_morale := 500
@export var morale_recovery := 250
@export var retreat_range := 6
# The ground and the attacker's penalties.
@export var crossing_penalty_permille := 300
@export var uphill_penalty_permille := 50
@export var river_penalty_permille := 200
@export var relief_defence_add: PackedInt32Array = PackedInt32Array()
@export var relief_rough_from := 3
@export var relief_narrow_from := 5
@export var relief_elevation: PackedInt32Array = PackedInt32Array()
# Ranks and experience.
@export var rank_xp: PackedInt32Array = PackedInt32Array()
@export var rank_permille: PackedInt32Array = PackedInt32Array()
@export var rank_names: PackedStringArray = PackedStringArray()
@export var xp_win := 2
@export var xp_lose := 1
# Garrisons, sieges and occupation.
@export var garrison_attack := 3
@export var garrison_defence := 3
@export var garrison_defence_per_level := 2
@export var castle_defence_permille := 250
@export var garrison_per_level := 400
@export var garrison_regen_per_level := 100
@export var battle_records_kept := 60
@export var siege_base_need := 4
@export var siege_per_level := 3
@export var siege_min_seasons := 2
@export var siege_hunger := 2
@export var siege_rate_max := 6
@export var crowd_bands: PackedInt32Array = PackedInt32Array()
@export var storm_cut_permille := 500
@export var militia_men := 250
@export var area_reach: PackedInt32Array = PackedInt32Array()
@export var unsupported_seasons := 6
@export var support_range := 3
@export var occupied_output_permille := 500
@export var occupied_tax_permille := 500
@export var sack_permille := 150
# Peace, the score and the truce.
@export var peace_min_seasons := 4
@export var take_score := 3
@export var take_score_weak := 1
@export var white_score_min := -1
@export var capital_score := 3
@export var truce_seasons := 8
@export var war_timer_seasons := 40
@export var war_timer_warning := 32
# The odds card (D50): words by the lowest ratio, and the ground factors.
@export var odds_words: Array[Dictionary] = []
@export var odds_ground: Dictionary[StringName, int] = {}
@export var garrison_odds_permille := 3100
@export var garrison_odds_alone: PackedInt32Array = PackedInt32Array()


## Problems found, empty when valid. Every entry is type-checked before it is used, so a bad value gives a message and never
## an exception: the fight tables (every branch, 3 entries 1 to 4,000), the stances, six rising dice, the days (1 to
## MAX_BATTLE_DAYS), the arrays' sizes and ranges, the odds words (dictionaries with text and whole numbers) and the six
## odds_ground keys, the orderings, and a range for every scalar (_check_ranges).
func validate() -> Array[String]:
	var errors: Array[String] = []
	_check_fight(errors, fight_attack, "fight_attack")
	_check_fight(errors, fight_defence, "fight_defence")
	_check_stances(errors)
	_check_dice(errors)
	_check_days(errors)
	_check_arrays(errors)
	_check_odds(errors)
	_check_ranges(errors)
	_check_orderings(errors)
	return errors


## Each branch has its three entries in both tables, every one 1 to 4,000.
func _check_fight(errors: Array[String], table: Dictionary[StringName, PackedInt32Array], field: String) -> void:
	if table.size() != BRANCHES.size():
		errors.append("war: %s has %d entries, expected %d (one per branch)" % [field, table.size(), BRANCHES.size()])
	for branch: StringName in BRANCHES:
		if not table.has(branch):
			errors.append("war: %s has no branch '%s'" % [field, String(branch)])
			continue
		var row: PackedInt32Array = table[branch]
		if row.size() != FIGHT_COUNT:
			errors.append("war: %s %s has %d entries, expected %d" % [field, String(branch), row.size(), FIGHT_COUNT])
			continue
		for index: int in row.size():
			_range(errors, "%s %s[%d]" % [field, String(branch), index], row[index], 1, MAX_FIGHT)


## The stance tables name attack, hold and withdraw, each 1 to 4,000.
func _check_stances(errors: Array[String]) -> void:
	var tables := {"stance_dealt": stance_dealt, "stance_taken": stance_taken}
	for field: String in tables:
		var table: Dictionary[StringName, int] = tables[field]
		if table.size() != STANCES.size():
			errors.append("war: %s has %d entries, expected %d" % [field, table.size(), STANCES.size()])
		for stance: StringName in STANCES:
			if not table.has(stance):
				errors.append("war: %s has no stance '%s'" % [field, String(stance)])
			else:
				_range(errors, "%s %s" % [field, String(stance)], table[stance], 1, MAX_FIGHT)


## Six dice, each 1 to 4,000, rising from the first to the last.
func _check_dice(errors: Array[String]) -> void:
	if dice_permille.size() != DICE_COUNT:
		errors.append("war: dice_permille has %d entries, expected %d" % [dice_permille.size(), DICE_COUNT])
		return
	for index: int in dice_permille.size():
		_range(errors, "dice_permille[%d]" % index, dice_permille[index], 1, MAX_FIGHT)
	_ascending(errors, "dice_permille", dice_permille)


## A battle lasts 1 to MAX_BATTLE_DAYS days (BattleRecord keeps that many); the withdraw day is a day before the last.
func _check_days(errors: Array[String]) -> void:
	_range(errors, "battle_days", battle_days, 1, MAX_BATTLE_DAYS)
	_range(errors, "withdraw_day", withdraw_day, 1, MAX_BATTLE_DAYS)
	if withdraw_day >= battle_days:
		errors.append("war: withdraw_day %d should be under battle_days %d" % [withdraw_day, battle_days])


## The per-level and per-rank arrays: their sizes, then their ranges. Each range is checked only once its size is right, so
## a short array gives its size message and never an index error.
func _check_arrays(errors: Array[String]) -> void:
	_size(errors, "relief_defence_add", relief_defence_add.size(), RELIEF_LEVELS)
	_size(errors, "relief_elevation", relief_elevation.size(), RELIEF_LEVELS)
	_size(errors, "rank_xp", rank_xp.size(), RANK_COUNT)
	_size(errors, "rank_permille", rank_permille.size(), RANK_COUNT)
	_size(errors, "rank_names", rank_names.size(), RANK_COUNT)
	_size(errors, "crowd_bands", crowd_bands.size(), 2)
	_size(errors, "area_reach", area_reach.size(), FORTRESS_LEVELS)
	_size(errors, "garrison_odds_alone", garrison_odds_alone.size(), FORTRESS_LEVELS)
	if relief_defence_add.size() == RELIEF_LEVELS:
		for index: int in RELIEF_LEVELS:
			_range(errors, "relief_defence_add[%d]" % index, relief_defence_add[index], 0, MAX_PERMILLE)
	if relief_elevation.size() == RELIEF_LEVELS:
		for index: int in RELIEF_LEVELS:
			_range(errors, "relief_elevation[%d]" % index, relief_elevation[index], 0, 2)
	if rank_xp.size() == RANK_COUNT:
		_ascending(errors, "rank_xp", rank_xp)
		if rank_xp[0] != 0:
			errors.append("war: rank_xp[0] is %d, expected 0 (the first rank needs no experience)" % rank_xp[0])
		for index: int in RANK_COUNT:
			_range(errors, "rank_xp[%d]" % index, rank_xp[index], 0, MAX_COUNT)
	if rank_permille.size() == RANK_COUNT:
		for index: int in RANK_COUNT:
			_range(errors, "rank_permille[%d]" % index, rank_permille[index], 1000, 2000)
	if crowd_bands.size() == 2:
		_ascending(errors, "crowd_bands", crowd_bands)
		for index: int in 2:
			_range(errors, "crowd_bands[%d]" % index, crowd_bands[index], 1, MAX_PERMILLE * 10)
	if area_reach.size() == FORTRESS_LEVELS:
		_ascending(errors, "area_reach", area_reach)
		for index: int in FORTRESS_LEVELS:
			_range(errors, "area_reach[%d]" % index, area_reach[index], 0, 10)
	if garrison_odds_alone.size() == FORTRESS_LEVELS:
		for index: int in FORTRESS_LEVELS:
			_range(errors, "garrison_odds_alone[%d]" % index, garrison_odds_alone[index], 0, 10000)
		# A garrison that stands alone divides the odds at levels 1 to 3, so each of them needs a weight.
		for index: int in range(1, FORTRESS_LEVELS):
			_range(errors, "garrison_odds_alone[%d]" % index, garrison_odds_alone[index], 1, 10000)


## The odds words: a non-empty list of dictionaries, each with a text "word" and a whole "from" (no floats, no text), the
## first at 0 and each above the one before. Every type is checked before the value is used.
func _check_odds(errors: Array[String]) -> void:
	if odds_words.is_empty():
		errors.append("war: odds_words is empty")
	var last := -1
	for index: int in odds_words.size():
		var entry: Variant = odds_words[index]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("war: odds_words[%d] is not a dictionary" % index)
			continue
		var dict: Dictionary = entry
		var word: Variant = dict.get("word", null)
		if typeof(word) != TYPE_STRING:
			errors.append("war: odds_words[%d] has no word of text" % index)
		elif String(word).strip_edges().is_empty():
			errors.append("war: odds_words[%d] has an empty word" % index)
		var from: Variant = dict.get("from", null)
		if typeof(from) != TYPE_INT:
			errors.append("war: odds_words[%d] has no whole number 'from'" % index)
			continue
		var value: int = int(from)
		_range(errors, "odds_words[%d] from" % index, value, 0, MAX_COUNT)
		if index == 0 and value != 0:
			errors.append("war: odds_words[0] starts at %d, expected 0" % value)
		if index > 0 and value <= last:
			errors.append("war: odds_words[%d] starts at %d, not above %d" % [index, value, last])
		last = value
	for ground: StringName in ODDS_GROUNDS:
		if not odds_ground.has(ground):
			errors.append("war: odds_ground has no key '%s'" % String(ground))
		else:
			_range(errors, "odds_ground %s" % String(ground), odds_ground[ground], 1, 10000)
	if odds_ground.size() != ODDS_GROUNDS.size():
		errors.append("war: odds_ground has %d keys, expected the six grounds" % odds_ground.size())
	_range(errors, "garrison_odds_permille", garrison_odds_permille, 1, 10000)


## Every scalar with its range (the spec's ranges; the counts that divide or loop start at 1). A value outside it gives a
## message. The fight tables, stances, dice, arrays and odds have their own checks above.
func _check_ranges(errors: Array[String]) -> void:
	var rows := [
		["shock_permille", shock_permille, 1, MAX_PERMILLE],
		["backline_permille", backline_permille, 0, MAX_PERMILLE],
		["flank_permille", flank_permille, MAX_PERMILLE, MAX_FIGHT],
		["pikes_vs_horse_permille", pikes_vs_horse_permille, MAX_PERMILLE, MAX_FIGHT],
		["hit_spread_permille", hit_spread_permille, 1, MAX_PERMILLE],
		["morale_per_loss", morale_per_loss, 0, 100],
		["front_drain", front_drain, 0, MAX_PERMILLE],
		["reserve_drain", reserve_drain, 0, MAX_PERMILLE],
		["hunger_drain", hunger_drain, 0, MAX_PERMILLE],
		["reserve_shaken_permille", reserve_shaken_permille, 0, MAX_PERMILLE],
		["flank_morale", flank_morale, 0, MAX_PERMILLE],
		["centre_shock", centre_shock, 0, MAX_PERMILLE],
		["flee_morale", flee_morale, 0, MAX_PERMILLE],
		["flee_pursuit_permille", flee_pursuit_permille, 0, MAX_PERMILLE],
		["flee_morale_left", flee_morale_left, 0, MAX_PERMILLE],
		["withdraw_pursuit_permille", withdraw_pursuit_permille, 0, MAX_PERMILLE],
		["withdraw_pursuit_attacker_permille", withdraw_pursuit_attacker_permille, 0, MAX_PERMILLE],
		["withdraw_morale", withdraw_morale, 0, MAX_PERMILLE],
		["wounded_share_permille", wounded_share_permille, 0, MAX_PERMILLE],
		["wounded_return_permille", wounded_return_permille, 0, MAX_PERMILLE],
		["attack_morale", attack_morale, 0, MAX_PERMILLE],
		["morale_recovery", morale_recovery, 0, MAX_PERMILLE],
		["retreat_range", retreat_range, 1, 20],
		["crossing_penalty_permille", crossing_penalty_permille, 0, MAX_PERMILLE],
		["uphill_penalty_permille", uphill_penalty_permille, 0, MAX_PERMILLE],
		["river_penalty_permille", river_penalty_permille, 0, MAX_PERMILLE],
		["relief_rough_from", relief_rough_from, 0, RELIEF_LEVELS - 1],
		["relief_narrow_from", relief_narrow_from, 0, RELIEF_LEVELS - 1],
		["xp_win", xp_win, 0, 100],
		["xp_lose", xp_lose, 0, 100],
		["garrison_attack", garrison_attack, 1, 20],
		["garrison_defence", garrison_defence, 1, 20],
		["garrison_defence_per_level", garrison_defence_per_level, 0, 20],
		["castle_defence_permille", castle_defence_permille, 0, MAX_PERMILLE],
		["garrison_per_level", garrison_per_level, 1, MAX_COUNT],
		["garrison_regen_per_level", garrison_regen_per_level, 0, MAX_COUNT],
		["battle_records_kept", battle_records_kept, 1, 1000],
		["siege_base_need", siege_base_need, 1, 100],
		["siege_per_level", siege_per_level, 1, 100],
		["siege_min_seasons", siege_min_seasons, 1, 100],
		["siege_hunger", siege_hunger, 0, 100],
		["siege_rate_max", siege_rate_max, 1, 100],
		["storm_cut_permille", storm_cut_permille, 0, MAX_PERMILLE],
		["militia_men", militia_men, 0, MAX_COUNT],
		["occupied_output_permille", occupied_output_permille, 0, MAX_PERMILLE],
		["occupied_tax_permille", occupied_tax_permille, 0, MAX_PERMILLE],
		["sack_permille", sack_permille, 0, MAX_PERMILLE],
		["unsupported_seasons", unsupported_seasons, 1, 100],
		["support_range", support_range, 0, 10],
		["peace_min_seasons", peace_min_seasons, 0, 100],
		["take_score", take_score, 0, 100],
		["take_score_weak", take_score_weak, 0, 100],
		["white_score_min", white_score_min, -100, 100],
		["capital_score", capital_score, 0, 100],
		["truce_seasons", truce_seasons, 0, 100],
		["war_timer_seasons", war_timer_seasons, 1, 1000],
		["war_timer_warning", war_timer_warning, 0, 1000],
	]
	for row: Array in rows:
		_range(errors, String(row[0]), int(row[1]), int(row[2]), int(row[3]))


## The orderings the rules need: the warning comes no later than the timer, and the weak take score no higher than the take
## score.
func _check_orderings(errors: Array[String]) -> void:
	if war_timer_warning > war_timer_seasons:
		errors.append("war: war_timer_warning %d should not be over war_timer_seasons %d" % [war_timer_warning, war_timer_seasons])
	if take_score_weak > take_score:
		errors.append("war: take_score_weak %d should not be over take_score %d" % [take_score_weak, take_score])


func _range(errors: Array[String], field: String, value: int, low: int, high: int) -> void:
	if value < low or value > high:
		errors.append("war: %s is %d, expected %d to %d" % [field, value, low, high])


func _size(errors: Array[String], field: String, count: int, expected: int) -> void:
	if count != expected:
		errors.append("war: %s has %d entries, expected %d" % [field, count, expected])


## Strictly rising: each entry above the one before it.
func _ascending(errors: Array[String], field: String, values: PackedInt32Array) -> void:
	for index: int in range(1, values.size()):
		if values[index] <= values[index - 1]:
			errors.append("war: %s[%d] is %d, not above %d" % [field, index, values[index], values[index - 1]])
