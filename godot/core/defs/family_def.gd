## The works numbers of one family (docs/architecture/m3-build-spec.md sections 4.3, 5.1 and 7): how many seasons a work
## takes to reach each level, and how many a clearing takes. M4 adds costs, upkeep and output beside them.
## Stored one file per family in data/defs/families/<key>.tres and listed by GameDefs.
@tool
class_name FamilyDef
extends Resource

## Fewest and most seasons a work may take.
const MIN_SEASONS := 1
const MAX_SEASONS := 64

@export var id: int = 0
@export var key: StringName = &""
## Index = the level a work reaches; [0] is 0; size FamilyIds.TOP_LEVEL[id] + 1.
@export var work_seasons: PackedInt32Array = PackedInt32Array()
@export var clear_seasons: int = 1


## Problems found, empty when valid: id 1 to 14, key the one FamilyIds gives the id, work_seasons the size
## TOP_LEVEL[id] + 1 with [0] at 0 and each level 1 to 64, and clear_seasons 1 to 64.
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
	return errors


func _label() -> String:
	if key != &"":
		return "family %s" % String(key)
	return "family %d" % id
