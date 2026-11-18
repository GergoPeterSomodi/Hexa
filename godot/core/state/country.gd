## What changes about a country during a game (docs/architecture/m2-build-spec.md section 5.2 and 5.9).
## Treasury (M4), armies (M6) and techs (M11) join it with their systems.
class_name Country
extends RefCounted

const SCHEMA := "hexa-godot/country/1"
const NO_HEX := Vector2i(-1, -1)

## Country id in MapState.owner (1 to 254).
var id: int = 0
var tag: StringName = &""
## Capital hex on the map, or NO_HEX when off the map (outside power).
var capital: Vector2i = NO_HEX
var alive: bool = true


static func create(
	p_id: int,
	p_tag: StringName,
	p_capital: Vector2i = NO_HEX,
	p_alive: bool = true,
) -> Country:
	var c := Country.new()
	c.id = p_id
	c.tag = p_tag
	c.capital = p_capital
	c.alive = p_alive
	return c


## JSON-safe dictionary for save games.
func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"id": id,
		"tag": String(tag),
		"capital": [capital.x, capital.y],
		"alive": alive,
	}


## Restores a Country saved by to_dict, or returns null when the schema is wrong or fields are malformed.
static func from_dict(d: Dictionary) -> Country:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var c := Country.new()
	c.id = int(d.get("id", 0))
	c.tag = StringName(str(d.get("tag", "")))
	var cap_val: Variant = d.get("capital", null)
	if cap_val is Array:
		var arr: Array = cap_val
		if arr.size() != 2:
			return null
		c.capital = Vector2i(int(arr[0]), int(arr[1]))
	elif cap_val is Vector2i:
		c.capital = cap_val
	elif cap_val != null:
		return null
	c.alive = bool(d.get("alive", true))
	return c


## Stable text line used in Game.digest(): "id|tag|col,row|alive".
func digest_text() -> String:
	return "%d|%s|%d,%d|%s" % [id, String(tag), capital.x, capital.y, "true" if alive else "false"]
