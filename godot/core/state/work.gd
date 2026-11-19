## One work under way: a build, an upgrade or a clearing that takes seasons (docs/architecture/m3-build-spec.md 4.3, 5.2).
## A plain value, written only by Works. Saved inside MapState.
class_name Work
extends RefCounted

const SCHEMA := "hexa-godot/work/1"
const ACTIONS: Array[String] = ["build", "upgrade", "clear"]

var id: int = 0
## The actor; &"" in a map-only game.
var tag: StringName = &""
var hex: Vector2i = Vector2i.ZERO
## &"build", &"upgrade" or &"clear".
var action: StringName = &"build"
## build: the family; upgrade, clear: the hex's family when begun.
var family: int = 0
## build 1; upgrade level + 1; clear 0.
var level_to: int = 0
var started_turn: int = 0
var seasons: int = 0
var seasons_left: int = 0
## Ducats paid; 0 until M4.
var paid: int = 0


## Plain: tag and action as String, the hex as [col, row].
func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"id": id,
		"tag": String(tag),
		"hex": [hex.x, hex.y],
		"action": String(action),
		"family": family,
		"level_to": level_to,
		"started_turn": started_turn,
		"seasons": seasons,
		"seasons_left": seasons_left,
		"paid": paid,
	}


## The work saved by to_dict; null on a wrong schema, a missing or mistyped field.
static func from_dict(d: Dictionary) -> Work:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var w := Work.new()
	for key: String in ["id", "family", "level_to", "started_turn", "seasons", "seasons_left", "paid"]:
		var value: Variant = whole(d.get(key, null))
		if value == null:
			return null
		w.set(key, int(value))
	var tag_value: Variant = d.get("tag", null)
	var action_value: Variant = d.get("action", null)
	if not (tag_value is String or tag_value is StringName) or not (action_value is String or action_value is StringName):
		return null
	w.tag = StringName(String(tag_value))
	w.action = StringName(String(action_value))
	if not ACTIONS.has(String(w.action)):
		return null
	var hex_value: Variant = d.get("hex", null)
	if hex_value is Vector2i:
		w.hex = hex_value
	elif hex_value is Array and (hex_value as Array).size() == 2:
		var parts: Array = hex_value
		var col: Variant = whole(parts[0])
		var row: Variant = whole(parts[1])
		if col == null or row == null:
			return null
		w.hex = Vector2i(int(col), int(row))
	else:
		return null
	return w


## A whole number from an int or a whole float (JSON gives floats); null for anything else.
static func whole(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))):
		return int(value)
	return null


func duplicate_work() -> Work:
	var w := Work.new()
	w.id = id
	w.tag = tag
	w.hex = hex
	w.action = action
	w.family = family
	w.level_to = level_to
	w.started_turn = started_turn
	w.seasons = seasons
	w.seasons_left = seasons_left
	w.paid = paid
	return w


## "id|tag|c,r|action|family|level_to|started_turn|seasons|seasons_left|paid".
func digest_text() -> String:
	return "%d|%s|%d,%d|%s|%d|%d|%d|%d|%d|%d" % [id, String(tag), hex.x, hex.y, String(action), family, level_to,
		started_turn, seasons, seasons_left, paid]
