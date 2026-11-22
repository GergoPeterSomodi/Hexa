## A battle between its start (movement) and its fight (battles), docs/architecture/m7-build-spec.md 5.2. Pure state: written
## only by Battles (B8) and read back by from_dict. Never saved at idle: game.battles is empty between seasons.
class_name Battle
extends RefCounted

const SCHEMA := "hexa-godot/battle/1"

var hex: Vector2i = Vector2i(-1, -1)
var attacker: StringName = &""
var defender: StringName = &""
var start_turn: int = 0
var assault: bool = false
## Tag (String) -> PackedInt32Array of army ids, in the order they came.
var armies: Dictionary = {}
## The movement tick it started at.
var tick: int = 0
var name: String = ""
var crossing: bool = false
var uphill: bool = false
var river: bool = false
## A storm's garrison men before the cut (0: no cut).
var storm_from: int = 0
## The garrison men the storm faces.
var storm_cut: int = 0


func to_dict() -> Dictionary:
	var groups: Dictionary = {}
	for tag: Variant in armies:
		groups[String(tag)] = _ids_of(armies[tag])
	return {
		"schema": SCHEMA, "hex": [hex.x, hex.y], "attacker": String(attacker), "defender": String(defender),
		"start_turn": start_turn, "assault": assault, "armies": groups, "tick": tick, "name": name,
		"crossing": crossing, "uphill": uphill, "river": river, "storm_from": storm_from, "storm_cut": storm_cut,
	}


## Null on a wrong schema, a missing or mistyped field, a negative number, two equal sides, an army id below 1, or a
## storm cut above the garrison it cuts.
static func from_dict(d: Dictionary) -> Battle:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var b := Battle.new()
	var cell: Variant = Unit.hex_from(d.get("hex", null))
	if cell == null:
		return null
	var nums := {}
	for key: String in ["start_turn", "tick", "storm_from", "storm_cut"]:
		var value: Variant = Unit.int32(d.get(key, null))
		if value == null or int(value) < 0:
			return null
		nums[key] = int(value)
	var texts := {}
	for key: String in ["attacker", "defender", "name"]:
		var value: Variant = d.get(key, null)
		if not (value is String or value is StringName):
			return null
		texts[key] = str(value)
	var flags := {}
	for key: String in ["assault", "crossing", "uphill", "river"]:
		if typeof(d.get(key, null)) != TYPE_BOOL:
			return null
		flags[key] = bool(d[key])
	if texts["attacker"] == texts["defender"] or not Unit.tag_ok(texts["attacker"]) or not Unit.tag_ok(texts["defender"]):
		return null
	if not Unit.name_ok(texts["name"]):
		return null
	var groups: Variant = _groups_from(d.get("armies", null), texts["attacker"], texts["defender"])
	if groups == null:
		return null
	if nums["storm_cut"] > nums["storm_from"] or nums["start_turn"] < 1:
		return null
	# A storm cut is only a storm: it needs an assault (4.6).
	if nums["storm_cut"] > 0 and not flags["assault"]:
		return null
	b.hex = cell
	b.attacker = StringName(texts["attacker"])
	b.defender = StringName(texts["defender"])
	b.start_turn = nums["start_turn"]
	b.assault = flags["assault"]
	b.armies = groups
	b.tick = nums["tick"]
	b.name = texts["name"]
	b.crossing = flags["crossing"]
	b.uphill = flags["uphill"]
	b.river = flags["river"]
	b.storm_from = nums["storm_from"]
	b.storm_cut = nums["storm_cut"]
	return b


## "c,r|attacker|defender|start|assault|tick|name|crossing|uphill|river|storm_from|storm_cut|tag:ids;..." with the tags sorted.
func digest_text() -> String:
	var tags: Array = armies.keys()
	tags.sort()
	var groups := PackedStringArray()
	for tag: Variant in tags:
		groups.append("%s:%s" % [str(tag), ",".join(_ids_text(armies[tag]))])
	return "%d,%d|%s|%s|%d|%d|%d|%s|%d|%d|%d|%d|%d|%s" % [hex.x, hex.y, String(attacker), String(defender), start_turn,
		1 if assault else 0, tick, name, 1 if crossing else 0, 1 if uphill else 0, 1 if river else 0, storm_from, storm_cut,
		";".join(groups)]


static func _ids_of(value: Variant) -> Array:
	var out: Array = []
	for item: Variant in value:
		out.append(int(item))
	return out


static func _ids_text(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	for item: Variant in value:
		out.append(str(int(item)))
	return out


## Tag -> PackedInt32Array of army ids >= 1 (a JSON list is read back as one); null for anything else.
## Only the two sides may hold armies, each side at least one, and no army id may sit in two places (or twice).
static func _groups_from(value: Variant, attacker: String, defender: String) -> Variant:
	if not (value is Dictionary) or (value as Dictionary).is_empty():
		return null
	var out := {}
	var seen := {}
	for key: Variant in value as Dictionary:
		if not (key is String or key is StringName) or (String(key) != attacker and String(key) != defender):
			return null
		var raw: Variant = (value as Dictionary)[key]
		var count := 0
		if raw is Array:
			count = (raw as Array).size()
		elif raw is PackedInt32Array:
			count = (raw as PackedInt32Array).size()
		if count == 0:
			return null
		var ids := PackedInt32Array()
		for item: Variant in raw:
			var n: Variant = Unit.int32(item)
			if n == null or int(n) < 1 or seen.has(int(n)):
				return null
			seen[int(n)] = true
			ids.append(int(n))
		out[String(key)] = ids
	return out
