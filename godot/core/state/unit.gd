## A company of one kind in an army (docs/architecture/m6-build-spec.md 5.2). Pure state: written only by Armies
## (5.0 R2); the saved form is JSON-safe, the digest text is stable.
class_name Unit
extends RefCounted

const SCHEMA := "hexa-godot/unit/2"
const MAX_MORALE := 1000
## The largest and smallest int32: every count, id and hex coordinate in the saved state fits one (Armies._raw_ok uses it too).
const INT32_MAX := 2147483647
const INT32_MIN := -2147483648

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
## Morale, 0 to 1000 (a unit raised starts at 1000; 4.12).
var morale: int = 1000
## Experience, 0 and up; rank comes from WarDef.rank_xp (4.6).
var xp: int = 0


func to_dict() -> Dictionary:
	var goods: Dictionary = {}
	for key: Variant in paid_goods:
		goods[String(key)] = int(paid_goods[key])
	return {
		"schema": SCHEMA, "id": id, "kind": kind, "men": men, "home": [home.x, home.y], "raised_turn": raised_turn,
		"paid": paid, "paid_goods": goods, "morale": morale, "xp": xp,
	}


## Null on a wrong schema, a missing or mistyped field, a negative number or an unknown good.
static func from_dict(d: Dictionary) -> Unit:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var u := Unit.new()
	var ints := {}
	for key: String in ["id", "kind", "men", "raised_turn", "paid", "xp", "morale"]:
		var value: Variant = int32(d.get(key, null))
		if value == null or int(value) < 0:
			return null
		ints[key] = int(value)
	if int(ints["morale"]) > MAX_MORALE:
		return null
	var cell: Variant = hex_from(d.get("home", null))
	var goods: Variant = d.get("paid_goods", null)
	if cell == null or not (goods is Dictionary):
		return null
	for key: Variant in goods as Dictionary:
		var loads: Variant = int32((goods as Dictionary)[key])
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
	u.xp = ints["xp"]
	u.morale = ints["morale"]
	u.home = cell
	return u


## "id|kind|men|c,r|raised_turn|paid|good:n,..." with the goods in good id order.
func digest_text() -> String:
	var parts := PackedStringArray()
	for key: StringName in GoodDef.KEYS:
		if paid_goods.has(String(key)):
			parts.append("%s:%d" % [String(key), int(paid_goods[String(key)])])
	return "%d|%d|%d|%d,%d|%d|%d|%s|%d|%d" % [id, kind, men, home.x, home.y, raised_turn, paid, ",".join(parts),
		morale, xp]


## A whole number from an int or an exactly whole float (JSON gives floats); null for anything else, a bool and a string too.
## A float must equal its own rounding (3.0000001 is refused), and past 2^53 it is refused: it is no longer exact.
static func whole(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var f := float(value)
		if absf(f) > 9007199254740992.0:
			return null
		if f == roundf(f):
			return int(f)
	return null


## A whole number that fits an int32 (the saved counts, ids and coordinates); null otherwise.
static func int32(value: Variant) -> Variant:
	var n: Variant = whole(value)
	if n == null or int(n) < INT32_MIN or int(n) > INT32_MAX:
		return null
	return n


## A country tag as saved: 1 to 16 characters with none of the digest's separators (| ; , : and a newline).
static func tag_ok(text: String) -> bool:
	if text.is_empty() or text.length() > 16:
		return false
	for mark: String in ["|", ";", ",", ":", "\n"]:
		if text.contains(mark):
			return false
	return true


## A place name as saved: up to 200 characters, without the digest's separators | and ; and without a newline.
static func name_ok(text: String) -> bool:
	if text.length() > 200:
		return false
	return not (text.contains("|") or text.contains(";") or text.contains("\n"))


## A hex from a Vector2i or a pair of int32 numbers; null for anything else.
static func hex_from(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if value is Array and (value as Array).size() == 2:
		var col: Variant = int32((value as Array)[0])
		var row: Variant = int32((value as Array)[1])
		if col != null and row != null:
			return Vector2i(int(col), int(row))
	return null
