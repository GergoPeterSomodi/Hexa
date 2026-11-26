## An army: its units, its hex, its order and what the last phases did to it (docs/architecture/m6-build-spec.md 5.2).
## Pure state: written only by Armies (5.0 R2); the saved form is JSON-safe (names as text, the route packed).
class_name Army
extends RefCounted

const SCHEMA := "hexa-godot/army/3"
const NO_HEX := Vector2i(-1, -1)
const ORDER_NONE := &""
const ORDER_HOLD := &"hold"
const ORDER_MARCH := &"march"
const ORDER_STORM := &"storm"
## The standing order (4.7): what the army does when attacked. Apart from ORDER_HOLD (a word, not a field).
const STANDING_HOLD := &"hold"
const STANDING_WITHDRAW := &"withdraw"

var id: int = 0
var tag: StringName = &""
var name: String = ""
var hex: Vector2i = NO_HEX
## In unit id order.
var units: Array[Unit] = []
var order: StringName = ORDER_NONE
var goal: Vector2i = NO_HEX
## Hex indices, the next step first, the goal last.
var route: PackedInt32Array = PackedInt32Array()
## &"winter" while it waits for spring.
var waiting: StringName = &""
## &"blocked" or &"no_way" after a halt (order none, goal kept).
var halt_why: StringName = &""
var halt_text: String = ""
## Its hex before the last movement phase; NO_HEX when it did not move.
var moved_from: Vector2i = NO_HEX
## The last supply phase: 0 fed from the stores, 1 fed by the land, 2 hungry.
var supply: int = 0
## Men lost in the last supply phase.
var lost_last: int = 0
var created_turn: int = 0
## STANDING_HOLD or STANDING_WITHDRAW (4.7); written only by Armies.
var standing: StringName = STANDING_HOLD
## The move points left this season, 0 to the army's full (moves-build-spec.md R12); written only by Armies.set_points.
var points: int = 0
## The hex it stood on when it first moved this season; NO_HEX when it has not moved (R40).
var season_from: Vector2i = NO_HEX


func men() -> int:
	var total := 0
	for u: Unit in units:
		total += u.men
	return total


## True when a unit was raised in `turn` (always asked with game.turn).
func mustering(turn: int) -> bool:
	for u: Unit in units:
		if u.raised_turn == turn:
			return true
	return false


## The unit with this id, or null when it is not in the army.
func unit(unit_id: int) -> Unit:
	for u: Unit in units:
		if u.id == unit_id:
			return u
	return null


## Plain: names as text, hexes as pairs, the route packed, the units as unit/2 in id order.
func to_dict() -> Dictionary:
	var list: Array = []
	for u: Unit in units:
		list.append(u.to_dict())
	return {
		"schema": SCHEMA, "id": id, "tag": String(tag), "name": name, "hex": [hex.x, hex.y], "units": list,
		"order": String(order), "goal": [goal.x, goal.y], "route": route.duplicate(), "waiting": String(waiting),
		"halt_why": String(halt_why), "halt_text": halt_text, "moved_from": [moved_from.x, moved_from.y],
		"supply": supply, "lost_last": lost_last, "created_turn": created_turn, "standing": String(standing),
		"points": points, "season_from": [season_from.x, season_from.y],
	}


## Null on a wrong schema, a bad unit (a duplicate or unsorted id too) or a missing or mistyped field. What the game
## knows (tag, hex on the map, unit kind and men) is Armies.from_dict's to check.
static func from_dict(d: Dictionary) -> Army:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var a := Army.new()
	var ints := {}
	for key: String in ["id", "supply", "lost_last", "created_turn", "points"]:
		var value: Variant = Unit.int32(d.get(key, null))
		if value == null or int(value) < 0:
			return null
		ints[key] = int(value)
	var texts := {}
	for key: String in ["tag", "name", "order", "waiting", "halt_why", "halt_text", "standing"]:
		var value: Variant = d.get(key, null)
		if not (value is String or value is StringName):
			return null
		texts[key] = str(value)
	var cells := {}
	for key: String in ["hex", "goal", "moved_from", "season_from"]:
		var value: Variant = Unit.hex_from(d.get(key, null))
		if value == null:
			return null
		cells[key] = value
	var path: Variant = _route_from(d.get("route", null))
	var raw_units: Variant = d.get("units", null)
	if path == null or not (raw_units is Array) or ints["supply"] > 2:
		return null
	if not [ORDER_NONE, ORDER_HOLD, ORDER_MARCH, ORDER_STORM].has(StringName(texts["order"])):
		return null
	if not [STANDING_HOLD, STANDING_WITHDRAW].has(StringName(texts["standing"])):
		return null
	for item: Variant in raw_units as Array:
		if not (item is Dictionary):
			return null
		var u := Unit.from_dict(item as Dictionary)
		if u == null or (not a.units.is_empty() and u.id <= a.units[-1].id):
			return null
		a.units.append(u)
	a.id = ints["id"]
	a.supply = ints["supply"]
	a.lost_last = ints["lost_last"]
	a.created_turn = ints["created_turn"]
	a.standing = StringName(texts["standing"])
	a.points = ints["points"]
	a.tag = StringName(texts["tag"])
	a.name = texts["name"]
	a.order = StringName(texts["order"])
	a.waiting = StringName(texts["waiting"])
	a.halt_why = StringName(texts["halt_why"])
	a.halt_text = texts["halt_text"]
	a.hex = cells["hex"]
	a.goal = cells["goal"]
	a.moved_from = cells["moved_from"]
	a.season_from = cells["season_from"]
	a.route = path
	return a


## "id|tag|name|c,r|created_turn|order|goal|route|waiting|halt_why|halt_text|moved_from|supply|lost_last|" and the units'
## digest texts in id order, joined by ";", then "|standing|points|season_from". The goal, moved_from and season_from are "c,r", the
## route comma-separated indices.
func digest_text() -> String:
	var parts := PackedStringArray()
	for u: Unit in units:
		parts.append(u.digest_text())
	var path := PackedStringArray()
	for index: int in route:
		path.append(str(index))
	return "%d|%s|%s|%d,%d|%d|%s|%d,%d|%s|%s|%s|%s|%d,%d|%d|%d|%s|%s|%d|%d,%d" % [
		id, String(tag), name, hex.x, hex.y, created_turn, String(order), goal.x, goal.y, ",".join(path),
		String(waiting), String(halt_why), halt_text, moved_from.x, moved_from.y, supply, lost_last, ";".join(parts), String(standing),
		points, season_from.x, season_from.y,
	]


## A route from a packed array or a list of whole numbers; null for anything else.
static func _route_from(value: Variant) -> Variant:
	if value is PackedInt32Array:
		return (value as PackedInt32Array).duplicate()
	if not (value is Array):
		return null
	var out := PackedInt32Array()
	for item: Variant in value as Array:
		var n: Variant = Unit.whole(item)
		if n == null:
			return null
		out.append(int(n))
	return out
