## A siege of a fortress hex (docs/architecture/m7-build-spec.md 5.2, 4.5). Pure state: written only by Sieges (B9) and read
## back by from_dict. One siege per hex, in hex index order in game.sieges.
class_name Siege
extends RefCounted

const SCHEMA := "hexa-godot/siege/1"

var hex: Vector2i = Vector2i(-1, -1)
var besieger: StringName = &""
## Progress towards the fall (4.5's need).
var progress: int = 0
## Seasons the siege has run.
var seasons: int = 0
var name: String = ""
var started_turn: int = 0


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA, "hex": [hex.x, hex.y], "besieger": String(besieger), "progress": progress,
		"seasons": seasons, "name": name, "started_turn": started_turn,
	}


## Null on a wrong schema, a missing or mistyped field, a negative count or an empty besieger.
static func from_dict(d: Dictionary) -> Siege:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var s := Siege.new()
	var cell: Variant = Unit.hex_from(d.get("hex", null))
	if cell == null:
		return null
	var nums := {}
	for key: String in ["progress", "seasons", "started_turn"]:
		var value: Variant = Unit.int32(d.get(key, null))
		if value == null or int(value) < 0:
			return null
		nums[key] = int(value)
	var texts := {}
	for key: String in ["besieger", "name"]:
		var value: Variant = d.get(key, null)
		if not (value is String or value is StringName):
			return null
		texts[key] = str(value)
	if not Unit.tag_ok(texts["besieger"]) or not Unit.name_ok(texts["name"]):
		return null
	s.hex = cell
	s.besieger = StringName(texts["besieger"])
	s.progress = nums["progress"]
	s.seasons = nums["seasons"]
	s.name = texts["name"]
	s.started_turn = nums["started_turn"]
	return s


## "c,r|besieger|progress|seasons|name|started".
func digest_text() -> String:
	return "%d,%d|%s|%d|%d|%s|%d" % [hex.x, hex.y, String(besieger), progress, seasons, name, started_turn]
