## The barracks (docs/design/recruitment-queue.md section 4, decisions 14 and 20): a building of a settlement where
## companies are queued. Its numbers: the ducats and loads it costs, the seasons its work takes, its upkeep and the
## smallest settlement it is built in. Stored in data/defs/buildings/barracks.tres and listed by GameDefs.
@tool
class_name BarracksDef
extends Resource

## Ducats to build one.
@export var cost: int = 0
## Good key -> loads to build one.
@export var cost_goods: Dictionary[String, int] = {}
## Seasons its work takes.
@export var seasons: int = 1
## Ducats a season.
@export var upkeep: int = 0
## The smallest settlement level it is built in (a barracks of the start may stand lower: decision 17).
@export var min_level: int = 1


## Problems found, empty when valid: cost and upkeep 0 or more, seasons 1 to 64 (as a work's), min_level a settlement
## level (1 to 5), cost_goods naming known goods with loads above 0.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if cost < 0:
		errors.append("barracks: cost is %d, expected 0 or more" % cost)
	if upkeep < 0:
		errors.append("barracks: upkeep is %d, expected 0 or more" % upkeep)
	if seasons < FamilyDef.MIN_SEASONS or seasons > FamilyDef.MAX_SEASONS:
		errors.append("barracks: seasons is %d, expected %d to %d" % [seasons, FamilyDef.MIN_SEASONS, FamilyDef.MAX_SEASONS])
	var top := FamilyIds.TOP_LEVEL[1]
	if min_level < 1 or min_level > top:
		errors.append("barracks: min_level is %d, expected 1 to %d" % [min_level, top])
	for good_key: String in cost_goods:
		if not GoodDef.KEYS.has(StringName(good_key)):
			errors.append("barracks: cost_goods names unknown good '%s'" % good_key)
		elif cost_goods[good_key] < 1:
			errors.append("barracks: cost_goods %s is %d, expected 1 or more" % [good_key, cost_goods[good_key]])
	return errors
