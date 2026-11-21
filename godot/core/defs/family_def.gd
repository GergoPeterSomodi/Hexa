## The works numbers of one family (docs/architecture/m3-build-spec.md sections 4.3, 5.1 and 7; m4-build-spec.md sections
## 4.4 and 5.1): how many seasons a work takes to reach each level, how many a clearing takes, and from M4 the costs,
## upkeep, output and settlement numbers beside them. Stored one file per family in data/defs/families/<key>.tres and
## listed by GameDefs.
@tool
class_name FamilyDef
extends Resource

## Fewest and most seasons a work may take.
const MIN_SEASONS := 1
const MAX_SEASONS := 64
## The extras of grazing and mines districts (spec 4.4): ImproveRules.ANIMALS and ImproveRules.ORES. The defs layer
## cannot read the systems layer, so the lists are kept here; the tests check that they equal ImproveRules'.
const ANIMAL_EXTRAS: Array[String] = ["sheep", "cattle", "horses"]
const ORE_EXTRAS: Array[String] = ["iron", "copper", "silver"]
## Six slots: spring, summer, autumn, winter snow, winter frost, winter mild (spec 4.1).
const SLOTS := 6
const SEASON_PERCENT_MAX := 400

@export var id: int = 0
@export var key: StringName = &""
## Index = the level a work reaches; [0] is 0; size FamilyIds.TOP_LEVEL[id] + 1.
@export var work_seasons: PackedInt32Array = PackedInt32Array()
@export var clear_seasons: int = 1
## The good it makes; &"" for settlements, castles, grazing and mines (those make by_extra).
@export var good: StringName = &""
## Grazing {sheep: wool, cattle: cattle, horses: horses}; mines {iron: iron, copper: copper, silver: silver}:
## Improve.piece_of's extra -> good.
@export var by_extra: Dictionary[String, StringName] = {}
## Grazing {sheep 1000, cattle 750, horses 375}; mines {iron 1000, copper 750, silver 250}.
@export var extra_permille: Dictionary[String, int] = {}
## Goods families: loads a season at 100 % per level, [0] = 0.
@export var base: PackedInt32Array = PackedInt32Array()
## Goods families: percent per slot (SLOTS entries).
@export var season_percent: PackedInt32Array = PackedInt32Array()
@export var weather_bound := false
## Per level: percent of the hex's wild yield kept.
@export var keep_wild: PackedInt32Array = PackedInt32Array()
## Per level: people needed at full output.
@export var jobs: PackedInt32Array = PackedInt32Array()
## Per level: ducats a season.
@export var upkeep: PackedInt32Array = PackedInt32Array()
## Per level: ducats a season (settlements 4 and 5, castles).
@export var walls: PackedInt32Array = PackedInt32Array()
## Per level reached: ducats ([0] and settlements' [1] are 0).
@export var cost: PackedInt32Array = PackedInt32Array()
## Per level reached: {good key: loads}.
@export var cost_goods: Array[Dictionary] = []
## The card's ground line (4.4); "" for settlements and castles.
@export var ground_text: String = ""
## Settlements: people per level.
@export var people: PackedInt32Array = PackedInt32Array()
## Settlements: ring lift per level, permille.
@export var ring_lift: PackedInt32Array = PackedInt32Array()
## Settlements: port fish per level, loads a season at 100 %.
@export var port_fish: PackedInt32Array = PackedInt32Array()
## Settlements: port dues per level, ducats a season at 100 %.
@export var port_dues: PackedInt32Array = PackedInt32Array()
## Settlements: per level, the most people it holds (M5 spec 4.2, 4.5); empty on other families.
@export var room: PackedInt32Array = PackedInt32Array()
## Settlements: per level, the people under which it falls a level (4.5); 0 never. Empty on other families.
@export var falls_below: PackedInt32Array = PackedInt32Array()
## Settlements: per level, the companies a season it may raise (M6 spec 5.1; 0, 1, 1, 2, 3, 4); empty on other families.
@export var raise_cap: PackedInt32Array = PackedInt32Array()


## Problems found, empty when valid: id 1 to 14, key the one FamilyIds gives the id, work_seasons the size
## TOP_LEVEL[id] + 1 with [0] at 0 and each level 1 to 64, clear_seasons 1 to 64, and the M4 numbers (_check_levels,
## _check_goods, _check_settlement, _check_people).
func validate() -> Array[String]:
	var errors: Array[String] = []
	var label := _label()
	if id < 1 or id >= FamilyIds.COUNT:
		errors.append("%s: id %d is outside 1 to %d" % [label, id, FamilyIds.COUNT - 1])
		return errors
	if String(key) != FamilyIds.NAMES[id]:
		errors.append("%s: key '%s' should be '%s' for id %d" % [label, String(key), FamilyIds.NAMES[id], id])
	var top := FamilyIds.TOP_LEVEL[id]
	if work_seasons.size() != top + 1:
		errors.append("%s: work_seasons has %d entries, expected %d" % [label, work_seasons.size(), top + 1])
	else:
		if work_seasons[0] != 0:
			errors.append("%s: work_seasons[0] is %d, expected 0" % [label, work_seasons[0]])
		for level: int in range(1, work_seasons.size()):
			if work_seasons[level] < MIN_SEASONS or work_seasons[level] > MAX_SEASONS:
				errors.append("%s: work_seasons[%d] is %d, expected %d to %d"
					% [label, level, work_seasons[level], MIN_SEASONS, MAX_SEASONS])
	if clear_seasons < MIN_SEASONS or clear_seasons > MAX_SEASONS:
		errors.append("%s: clear_seasons is %d, expected %d to %d" % [label, clear_seasons, MIN_SEASONS, MAX_SEASONS])
	_check_levels(errors, label, top)
	_check_goods(errors, label, top)
	_check_settlement(errors, label, top)
	_check_people(errors, label, top)
	_check_raise_cap(errors, label, top)
	return errors


## raise_cap is on settlements only: top + 1 entries, [0] is 0, each 0 to 20 and none falling as the level rises.
func _check_raise_cap(errors: Array[String], label: String, top: int) -> void:
	if id != 1:
		if not raise_cap.is_empty():
			errors.append("%s: raise_cap is for settlements only" % label)
		return
	if raise_cap.size() != top + 1:
		errors.append("%s: raise_cap has %d entries, expected %d" % [label, raise_cap.size(), top + 1])
		return
	if raise_cap[0] != 0:
		errors.append("%s: raise_cap[0] is %d, expected 0" % [label, raise_cap[0]])
	for level: int in range(1, raise_cap.size()):
		if raise_cap[level] < 0 or raise_cap[level] > 20:
			errors.append("%s: raise_cap[%d] is %d, expected 0 to 20" % [label, level, raise_cap[level]])
		elif level > 1 and raise_cap[level] < raise_cap[level - 1]:
			errors.append("%s: raise_cap[%d] is %d, under raise_cap[%d] %d"
				% [label, level, raise_cap[level], level - 1, raise_cap[level - 1]])


## Every per-level array has top + 1 entries, [0] is 0 and no entry is negative; keep_wild is 0 to 100;
## cost_goods names only known goods with amounts above 0.
func _check_levels(errors: Array[String], label: String, top: int) -> void:
	var per_level := {"keep_wild": keep_wild, "jobs": jobs, "upkeep": upkeep, "walls": walls, "cost": cost}
	for field: String in per_level:
		var values: PackedInt32Array = per_level[field]
		if values.size() != top + 1:
			errors.append("%s: %s has %d entries, expected %d" % [label, field, values.size(), top + 1])
			continue
		if values[0] != 0:
			errors.append("%s: %s[0] is %d, expected 0" % [label, field, values[0]])
		for level: int in range(1, values.size()):
			if values[level] < 0:
				errors.append("%s: %s[%d] is %d, expected 0 or more" % [label, field, level, values[level]])
			if field == "keep_wild" and values[level] > 100:
				errors.append("%s: keep_wild[%d] is %d, expected 0 to 100" % [label, level, values[level]])
	if cost_goods.size() != top + 1:
		errors.append("%s: cost_goods has %d entries, expected %d" % [label, cost_goods.size(), top + 1])
		return
	if not cost_goods[0].is_empty():
		errors.append("%s: cost_goods[0] should be empty" % label)
	for level: int in cost_goods.size():
		for good_key: Variant in cost_goods[level]:
			var text := String(good_key)
			if not GoodDef.KEYS.has(StringName(text)):
				errors.append("%s: cost_goods[%d] names unknown good '%s'" % [label, level, text])
			elif int(cost_goods[level][good_key]) < 1:
				errors.append("%s: cost_goods[%d] %s is %d, expected 1 or more"
					% [label, level, text, int(cost_goods[level][good_key])])


## A goods family names one good or by_extra (not both); its base and season percents have their sizes and ranges,
## and it has a ground line. Any other family has none of them.
func _check_goods(errors: Array[String], label: String, top: int) -> void:
	if good != &"" and not by_extra.is_empty():
		errors.append("%s: names a good and by_extra; a family has one or the other" % label)
	if good != &"" and not GoodDef.KEYS.has(good):
		errors.append("%s: good '%s' is not a known good" % [label, String(good)])
	for extra_key: Variant in by_extra:
		var extra := String(extra_key)
		if not ANIMAL_EXTRAS.has(extra) and not ORE_EXTRAS.has(extra):
			errors.append("%s: extra '%s' is not an animal or an ore" % [label, extra])
		if not GoodDef.KEYS.has(by_extra[extra_key]):
			errors.append("%s: extra '%s' names unknown good '%s'" % [label, extra, String(by_extra[extra_key])])
		if not extra_permille.has(extra_key):
			errors.append("%s: extra '%s' has no extra_permille" % [label, extra])
		elif int(extra_permille[extra_key]) < 1 or int(extra_permille[extra_key]) > 1000:
			errors.append("%s: extra_permille of '%s' is %d, expected 1 to 1000"
				% [label, extra, int(extra_permille[extra_key])])
	if extra_permille.size() != by_extra.size():
		errors.append("%s: extra_permille has %d entries, by_extra %d" % [label, extra_permille.size(), by_extra.size()])
	var goods_family := good != &"" or not by_extra.is_empty()
	if not goods_family:
		if not base.is_empty() or not season_percent.is_empty() or not extra_permille.is_empty():
			errors.append("%s: base, season_percent and extra_permille are for goods families" % label)
		if ground_text != "":
			errors.append("%s: ground_text is for goods families" % label)
		return
	if base.size() != top + 1:
		errors.append("%s: base has %d entries, expected %d" % [label, base.size(), top + 1])
	else:
		if base[0] != 0:
			errors.append("%s: base[0] is %d, expected 0" % [label, base[0]])
		for level: int in range(1, base.size()):
			if base[level] < 1:
				errors.append("%s: base[%d] is %d, expected 1 or more" % [label, level, base[level]])
	if season_percent.size() != SLOTS:
		errors.append("%s: season_percent has %d entries, expected %d" % [label, season_percent.size(), SLOTS])
	else:
		for slot: int in SLOTS:
			if season_percent[slot] < 0 or season_percent[slot] > SEASON_PERCENT_MAX:
				errors.append("%s: season_percent[%d] is %d, expected 0 to %d"
					% [label, slot, season_percent[slot], SEASON_PERCENT_MAX])
	if ground_text.strip_edges().is_empty():
		errors.append("%s: ground_text is empty" % label)


## Settlement arrays are on settlements only, with top + 1 entries; a settlement's cost of level 1 is 0.
func _check_settlement(errors: Array[String], label: String, top: int) -> void:
	var per_level := {"people": people, "ring_lift": ring_lift, "port_fish": port_fish, "port_dues": port_dues}
	for field: String in per_level:
		var values: PackedInt32Array = per_level[field]
		if id != 1:
			if not values.is_empty():
				errors.append("%s: %s is for settlements only" % [label, field])
			continue
		if values.size() != top + 1:
			errors.append("%s: %s has %d entries, expected %d" % [label, field, values.size(), top + 1])
			continue
		if values[0] != 0:
			errors.append("%s: %s[0] is %d, expected 0" % [label, field, values[0]])
		for level: int in range(1, values.size()):
			if values[level] < 0:
				errors.append("%s: %s[%d] is %d, expected 0 or more" % [label, field, level, values[level]])
	if id == 1 and cost.size() > 1 and cost[1] != 0:
		errors.append("%s: cost[1] is %d, expected 0 (a hamlet is never begun)" % [label, cost[1]])


## The M5 people numbers of a settlement (spec 4.2, 4.5, 5.1): room and falls_below have top + 1 entries; room[0] is 0
## and rises with the level; the start people of a level are under its room; falls_below[1] is 0 and no entry is
## negative; a falls_below of level 2 or more is under the room of the level below (0 is never). Other families have
## neither.
func _check_people(errors: Array[String], label: String, top: int) -> void:
	if id != 1:
		if not room.is_empty() or not falls_below.is_empty():
			errors.append("%s: room and falls_below are for settlements only" % label)
		return
	if room.size() != top + 1 or falls_below.size() != top + 1:
		errors.append("%s: room has %d entries and falls_below %d, expected %d"
			% [label, room.size(), falls_below.size(), top + 1])
		return
	if room[0] != 0:
		errors.append("%s: room[0] is %d, expected 0" % [label, room[0]])
	for level: int in range(1, top + 1):
		if room[level] <= room[level - 1]:
			errors.append("%s: room[%d] is %d, expected more than room[%d] %d"
				% [label, level, room[level], level - 1, room[level - 1]])
		if people.size() == top + 1 and people[level] > room[level]:
			errors.append("%s: people[%d] is %d, over room %d" % [label, level, people[level], room[level]])
		if falls_below[level] < 0:
			errors.append("%s: falls_below[%d] is %d, expected 0 or more" % [label, level, falls_below[level]])
	if falls_below[1] != 0:
		errors.append("%s: falls_below[1] is %d, expected 0 (a hamlet falls no further)" % [label, falls_below[1]])
	for level: int in range(2, top + 1):
		if falls_below[level] > 0 and falls_below[level] >= room[level - 1]:
			errors.append("%s: falls_below[%d] is %d, expected under room[%d] %d"
				% [label, level, falls_below[level], level - 1, room[level - 1]])


func _label() -> String:
	if key != &"":
		return "family %s" % String(key)
	return "family %d" % id
