## One good of the economy (docs/architecture/m4-build-spec.md sections 4.2 and 5.1): its key, kind, fixed price, need,
## weight, reserve and icon. Stored one file per good in data/defs/goods/<key>.tres and listed by GameDefs in id order.
@tool
class_name GoodDef
extends Resource

const KINDS: Array[StringName] = [&"food", &"staple", &"ware", &"material"]
## The 16 keys in id order (spec 4.2). Ids are the index of every per-good array (stock, flows, Stats.goods_ring);
## append-only. FamilyDef and GameDefs check goods against this table, as FamilyDef checks ids against FamilyIds.
const KEYS: Array[StringName] = [
	&"grain", &"fish", &"oil", &"wine", &"salt", &"hemp", &"silk", &"dyes",
	&"wool", &"cattle", &"horses", &"timber", &"stone", &"iron", &"copper", &"silver",
]
const COUNT := 16

@export var id: int = 0
@export var key: StringName = &""
@export var name: String = ""
## One of KINDS: food, staple, ware, material.
@export var kind: StringName = &""
## The fixed price, thousandths of a ducat (M10 makes prices react).
@export var price_milli: int = 0
## Staples: loads a season per 1,000 town people, in thousandths; food: 0 (GameDefs.food_need_milli).
@export var need_milli: int = 0
## Staples: permille of contentment; food: 0 (GameDefs.food_weight).
@export var need_weight: int = 0
## Food: the order it is eaten (fish 0, grain 1); -1 otherwise.
@export var food_order: int = -1
## Materials: loads always kept (timber 40, stone 40, iron 20); 0 otherwise.
@export var reserve_fixed: int = 0
## "vintage", "harvest", "catch", "olive harvest", "salt season"; "" for the rest.
@export var harvest_word: String = ""
## The Kit icon (spec 6.2), for example &"good_wine".
@export var icon: StringName = &""


## Problems found, empty when valid: id 0 to 15 with the key KEYS gives it, a known kind, a name, a price above 0,
## needs and reserves not negative, weights 0 to 1000, food with a food order and no need, the others with -1, and an icon.
func validate() -> Array[String]:
	var errors: Array[String] = []
	var label := _label()
	if id < 0 or id >= COUNT:
		errors.append("%s: id %d is outside 0 to %d" % [label, id, COUNT - 1])
		return errors
	if key != KEYS[id]:
		errors.append("%s: key '%s' should be '%s' for id %d" % [label, String(key), String(KEYS[id]), id])
	if not KINDS.has(kind):
		errors.append("%s: kind '%s' is not one of food, staple, ware, material" % [label, String(kind)])
	if name.strip_edges().is_empty():
		errors.append("%s: name is empty" % label)
	if price_milli <= 0:
		errors.append("%s: price_milli is %d, expected 1 or more" % [label, price_milli])
	if need_milli < 0:
		errors.append("%s: need_milli is %d, expected 0 or more" % [label, need_milli])
	if need_weight < 0 or need_weight > 1000:
		errors.append("%s: need_weight is %d, expected 0 to 1000" % [label, need_weight])
	if reserve_fixed < 0:
		errors.append("%s: reserve_fixed is %d, expected 0 or more" % [label, reserve_fixed])
	if reserve_fixed > 0 and kind != &"material":
		errors.append("%s: reserve_fixed is %d but only materials keep a fixed reserve" % [label, reserve_fixed])
	if kind == &"food":
		if food_order < 0:
			errors.append("%s: food has food_order %d, expected 0 or more" % [label, food_order])
		if need_milli != 0 or need_weight != 0:
			errors.append("%s: food has a need of its own; the need is GameDefs' food need" % label)
	elif food_order != -1:
		errors.append("%s: food_order is %d, expected -1 for a %s" % [label, food_order, String(kind)])
	if icon == &"":
		errors.append("%s: icon is empty" % label)
	return errors


func _label() -> String:
	if key != &"":
		return "good %s" % String(key)
	return "good %d" % id
