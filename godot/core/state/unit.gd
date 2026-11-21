## A company of one kind in an army (docs/architecture/m6-build-spec.md 5.2). Pure state: written only by Armies
## (5.0 R2); the saved form is JSON-safe, the digest text is stable.
class_name Unit
extends RefCounted

const SCHEMA := "hexa-godot/unit/1"

var id: int = 0
## UnitDef id.
var kind: int = 0
var men: int = 0
## The hex it was raised on.
var home: Vector2i = Vector2i(-1, -1)
var raised_turn: int = 0
## Ducats paid (its refund in its raising season).
var paid: int = 0
## Good key (String) -> loads paid.
var paid_goods: Dictionary = {}


func to_dict() -> Dictionary:
	var goods: Dictionary = {}
	for key: Variant in paid_goods:
		goods[String(key)] = int(paid_goods[key])
	return {
		"schema": SCHEMA, "id": id, "kind": kind, "men": men, "home": [home.x, home.y], "raised_turn": raised_turn,
		"paid": paid, "paid_goods": goods,
	}


## Null on a wrong schema, a missing or mistyped field, a negative number or an unknown good.
static func from_dict(d: Dictionary) -> Unit:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var u := Unit.new()
	var ints := {}
	for key: String in ["id", "kind", "men", "raised_turn", "paid"]:
		var value: Variant = whole(d.get(key, null))
		if value == null or int(value) < 0:
			return null
		ints[key] = int(value)
	var cell: Variant = hex_from(d.get("home", null))
	var goods: Variant = d.get("paid_goods", null)
	if cell == null or not (goods is Dictionary):
		return null
	for key: Variant in goods as Dictionary:
		var loads: Variant = whole((goods as Dictionary)[key])
		if not (key is String or key is StringName) or not GoodDef.KEYS.has(StringName(key)):
			return null
		if loads == null or int(loads) < 0:
			return null
		u.paid_goods[String(key)] = int(loads)
	u.id = ints["id"]
	u.kind = ints["kind"]
	u.men = ints["men"]
	u.raised_turn = ints["raised_turn"]
	u.paid = ints["paid"]
	u.home = cell
	return u


## "id|kind|men|c,r|raised_turn|paid|good:n,..." with the goods in good id order.
func digest_text() -> String:
	var parts := PackedStringArray()
	for key: StringName in GoodDef.KEYS:
		if paid_goods.has(String(key)):
			parts.append("%s:%d" % [String(key), int(paid_goods[String(key)])])
	return "%d|%d|%d|%d,%d|%d|%d|%s" % [id, kind, men, home.x, home.y, raised_turn, paid, ",".join(parts)]


## A whole number from an int or a whole float (JSON gives floats); null for anything else, a bool and a string too.
static func whole(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))):
		return int(value)
	return null


## A hex from a Vector2i or a pair of whole numbers; null for anything else.
static func hex_from(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if value is Array and (value as Array).size() == 2:
		var col: Variant = whole((value as Array)[0])
		var row: Variant = whole((value as Array)[1])
		if col != null and row != null:
			return Vector2i(int(col), int(row))
	return null
