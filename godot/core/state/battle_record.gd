## What a battle was, kept for the dock, the report and the replay test (docs/architecture/m7-build-spec.md 5.2, 4.6). Pure
## state: written only by Battles (B8, through the record of a fought battle) and read back by from_dict.
## Plain form: the saved dict has text keys for every map keyed by unit id, army id or input key (JSON has no int keys),
## packed arrays as lists, StringName as text, Vector2i as a pair, the luck state as canonical int64 text. Every map of the
## saved form is written with its keys sorted, because a JSON round trip returns keys sorted and digest() reads bytes.
## from_dict reads a record back to the same in-memory form, so digest() of a loaded record equals the one saved.
class_name BattleRecord
extends RefCounted

const SCHEMA := "hexa-godot/battle-record/1"
const FRAME_KEYS: Array[String] = ["day", "rolls", "lanes", "men", "morale", "routed", "shaken", "killed", "wounded",
		"front", "broke", "cause", "withdrew"]
const END_KEYS: Array[String] = ["how", "cause", "winner", "loser", "days", "men", "morale", "wounded", "killed",
		"wounded_total", "lost_whole", "garrison", "retreat", "surrendered", "returned", "stormed", "sacked"]
## The longest battle (battle_days, 4.6): one frame a day, so a record has exactly as many frames as days.
const MAX_DAYS := 8
const LANE_EMPTY := -2
const LANE_GARRISON := -1
## The largest whole number a JSON float holds exactly (2^53).
const EXACT_MAX := 9007199254740992.0

var id: int = 0
var turn: int = 0
var hex: Vector2i = Vector2i(-1, -1)
var name: String = ""
var year: int = 0
var attacker: StringName = &""
var defender: StringName = &""
## Combat.fight's input in the plain form (string keys, see the header).
var input: Dictionary = {}
## The game's luck state before the battle's first day (64 bits: saved as text).
var luck_before: int = 0
## One a day, in the fixed key set of FRAME_KEYS; as many as the end's days.
var frames: Array[Dictionary] = []
## Combat's end in the key set of END_KEYS.
var end: Dictionary = {}
## The viewers who witnessed it (tags, or &"" for the player's country's own log in tests); not in the digest.
var witnesses: PackedStringArray = PackedStringArray()


## The plain form of a value: sorted text keys, text for StringName, lists for packed arrays, pairs for hexes, whole
## floats as ints.
static func plain(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value as Dictionary:
			out[str(key)] = plain((value as Dictionary)[key])
		return _sorted(out)
	if value is PackedInt32Array or value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(plain(item))
		return items
	if value is StringName:
		return String(value)
	if value is Vector2i:
		var cell: Vector2i = value
		return [cell.x, cell.y]
	if typeof(value) == TYPE_FLOAT:
		var f: float = value
		if f == roundf(f) and absf(f) <= EXACT_MAX:
			return int(f)
	return value


func to_dict() -> Dictionary:
	var frame_dicts: Array = []
	for f: Dictionary in frames:
		frame_dicts.append(_frame_to_dict(f))
	var marks: Array = []
	for w: String in witnesses:
		marks.append(w)
	return {
		"schema": SCHEMA, "id": id, "turn": turn, "hex": [hex.x, hex.y], "name": name, "year": year,
		"attacker": String(attacker), "defender": String(defender), "input": plain(input),
		"luck_before": str(luck_before), "frames": frame_dicts, "end": _end_to_dict(end), "witnesses": marks,
	}


## Null on a wrong schema, a damaged frame or end, or a missing or mistyped field. The frames must be as many as the
## end's days (1 to 8), in day order; the loser must be one of the two sides; every count is an int32.
static func from_dict(d: Dictionary) -> BattleRecord:
	refusal = ""
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var r := BattleRecord.new()
	var nums := {}
	for key: String in ["id", "turn", "year"]:
		var value: Variant = Unit.int32(d.get(key, null))
		if value == null:
			return null
		nums[key] = int(value)
	if nums["id"] < 1 or nums["turn"] < 1 or nums["year"] < 0:
		return null
	var luck: Variant = _luck_from(d.get("luck_before", null))
	var cell: Variant = Unit.hex_from(d.get("hex", null))
	if luck == null or cell == null:
		return null
	var texts := {}
	for key: String in ["name", "attacker", "defender"]:
		var value: Variant = d.get(key, null)
		if not (value is String or value is StringName):
			return null
		texts[key] = str(value)
	if not Unit.name_ok(texts["name"]) or not Unit.tag_ok(texts["attacker"]) or not Unit.tag_ok(texts["defender"]):
		return null
	if texts["attacker"] == texts["defender"]:
		return null
	var input_plain: Variant = _plain_read(d.get("input", null))
	if not (input_plain is Dictionary):
		return null
	var end_value: Variant = _end_from(d.get("end", null), texts["attacker"], texts["defender"])
	if end_value == null:
		return null
	var frame_list: Variant = _frames_from(d.get("frames", null), int((end_value as Dictionary)["days"]))
	var marks: Variant = _witnesses_from(d.get("witnesses", null))
	if frame_list == null or marks == null:
		return null
	r.id = nums["id"]
	r.turn = nums["turn"]
	r.hex = cell
	r.name = texts["name"]
	r.year = nums["year"]
	r.attacker = StringName(texts["attacker"])
	r.defender = StringName(texts["defender"])
	r.input = input_plain
	r.luck_before = int(luck)
	r.frames.assign(frame_list)
	r.end = end_value
	r.witnesses = marks
	return r


## sha-256 (hex text) of the saved dict less the witnesses (who saw it does not change what happened).
func digest() -> String:
	var d := to_dict()
	d.erase("witnesses")
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(d))
	return ctx.finish().hex_encode()


# --- saving -------------------------------------------------------------------------------------------------------------


static func _frame_to_dict(f: Dictionary) -> Dictionary:
	var lanes_out: Array = []
	for lane: Variant in f.get("lanes", []):
		lanes_out.append(_ints(lane))
	return {
		"day": int(f.get("day", 0)), "rolls": _ints(f.get("rolls", [])), "lanes": lanes_out,
		"men": _int_map_text(f.get("men", {})), "morale": _int_map_text(f.get("morale", {})),
		"routed": _ints(f.get("routed", [])), "shaken": _ints(f.get("shaken", [])),
		"killed": _ints(f.get("killed", [])), "wounded": _ints(f.get("wounded", [])),
		"front": _ints(f.get("front", [])), "broke": int(f.get("broke", 0)),
		"cause": String(f.get("cause", "")), "withdrew": int(f.get("withdrew", 0)),
	}


static func _end_to_dict(e: Dictionary) -> Dictionary:
	return {
		"how": String(e.get("how", "")), "cause": String(e.get("cause", "")), "winner": int(e.get("winner", 0)),
		"loser": String(e.get("loser", "")), "days": int(e.get("days", 0)),
		"men": _int_map_text(e.get("men", {})), "morale": _int_map_text(e.get("morale", {})),
		"wounded": _int_map_text(e.get("wounded", {})), "killed": _ints(e.get("killed", [])),
		"wounded_total": _ints(e.get("wounded_total", [])), "lost_whole": _ints(e.get("lost_whole", [])),
		"garrison": _int_map_text(e.get("garrison", {})), "retreat": _retreat_text(e.get("retreat", {})),
		"surrendered": _ints(e.get("surrendered", [])), "returned": _int_map_text(e.get("returned", {})),
		"stormed": bool(e.get("stormed", false)), "sacked": int(e.get("sacked", 0)),
	}


## A list of whole numbers as a packed array (in-memory values; a JSON list or a packed array alike).
static func _ints(value: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	if value is PackedInt32Array or value is Array:
		for item: Variant in value:
			out.append(int(item))
	return out


## A map keyed by unit id (or -1 for the garrison) as text keys, values as ints, keys sorted.
static func _int_map_text(value: Variant) -> Dictionary:
	var out := {}
	if value is Dictionary:
		for key: Variant in value as Dictionary:
			out[str(key)] = int((value as Dictionary)[key])
	return _sorted(out)


static func _retreat_text(value: Variant) -> Dictionary:
	var out := {}
	if value is Dictionary:
		for key: Variant in value as Dictionary:
			var spot: Vector2i = (value as Dictionary)[key]
			out[str(key)] = [spot.x, spot.y]
	return _sorted(out)


## The same pairs with their keys (text) in sorted order: the saved form is sorted, so bytes do not depend on how it was built.
static func _sorted(d: Dictionary) -> Dictionary:
	var keys: Array = d.keys()
	keys.sort()
	var out := {}
	for key: Variant in keys:
		out[key] = d[key]
	return out


# --- reading ------------------------------------------------------------------------------------------------------------


## The luck state from canonical int64 text only ("5", "-9223372036854775808"); "+5", leading zeros, anything out of
## int64 range and a bare number are refused, so a state never changes by a read.
static func _luck_from(value: Variant) -> Variant:
	if not (value is String or value is StringName):
		return null
	return _canonical_int(str(value))


## The int64 a canonical text names ("0", "-7", "9223372036854775807"); null for anything else: a plus sign, a leading zero,
## "-0", a digit that is not 0 to 9, or a value outside int64. Checked before any conversion, so no engine error is printed.
static func _canonical_int(text: String) -> Variant:
	var neg := text.begins_with("-")
	var digits := text.substr(1) if neg else text
	if digits.is_empty() or digits.length() > 19:
		return null
	for i: int in digits.length():
		var c := digits.unicode_at(i)
		if c < 48 or c > 57:
			return null
	if digits.length() > 1 and digits.begins_with("0"):
		return null
	if neg and digits == "0":
		return null
	if digits.length() == 19:
		var limit := "9223372036854775808" if neg else "9223372036854775807"
		if digits > limit:
			return null
		if neg and digits == "9223372036854775808":
			return -9223372036854775807 - 1
	return text.to_int()


## One frame in the in-memory form, or null for a damaged one.
static func _frame_from(d: Dictionary) -> Variant:
	for key: Variant in d:
		if not FRAME_KEYS.has(str(key)):
			return null
	for key: String in FRAME_KEYS:
		if not d.has(key):
			return null
	var day: Variant = Unit.int32(d["day"])
	var broke: Variant = Unit.int32(d["broke"])
	var withdrew: Variant = Unit.int32(d["withdrew"])
	if day == null or int(day) < 0 or int(day) > MAX_DAYS or broke == null or absi(int(broke)) > 1:
		return null
	if withdrew == null or int(withdrew) < 0 or not (d["cause"] is String or d["cause"] is StringName):
		return null
	var rolls: Variant = _side_pair(d["rolls"], "frame.rolls")
	var killed: Variant = _side_pair(d["killed"], "frame.killed")
	var wounded: Variant = _side_pair(d["wounded"], "frame.wounded")
	var front: Variant = _side_pair(d["front"], "frame.front")
	var routed: Variant = _ints_checked(d["routed"], -1, -1)
	var shaken: Variant = _ints_checked(d["shaken"], -1, -1)
	if rolls == null or killed == null or wounded == null or front == null or routed == null or shaken == null:
		return null
	var men: Variant = _int_map(d["men"], -1, 0, -1)
	var morale: Variant = _int_map(d["morale"], -1, 0, Unit.MAX_MORALE)
	var lanes: Variant = _lanes_from(d["lanes"])
	if men == null or morale == null or lanes == null:
		return null
	return {
		"day": int(day), "rolls": rolls, "lanes": lanes, "men": men, "morale": morale, "routed": routed,
		"shaken": shaken, "killed": killed, "wounded": wounded, "front": front, "broke": int(broke),
		"cause": str(d["cause"]), "withdrew": int(withdrew),
	}


## The frames of a record: a list of exactly `days` frames, in strictly rising day order.
static func _frames_from(value: Variant, days: int) -> Variant:
	if not (value is Array) or (value as Array).size() != days:
		return null
	var out: Array[Dictionary] = []
	var last_day := -1
	for item: Variant in value as Array:
		if not (item is Dictionary):
			return null
		var f: Variant = _frame_from(item as Dictionary)
		if f == null or int((f as Dictionary)["day"]) <= last_day:
			return null
		last_day = int((f as Dictionary)["day"])
		out.append(f as Dictionary)
	return out


## Two lanes of three keys each: unit ids (0 and up), LANE_GARRISON or LANE_EMPTY.
static func _lanes_from(value: Variant) -> Variant:
	if not (value is Array) or (value as Array).size() != 2:
		return null
	var out: Array = []
	for item: Variant in value as Array:
		var lane: Variant = _ints_checked(item, 3, LANE_EMPTY)
		if lane == null:
			return null
		out.append(lane)
	return out


## Combat's end in the in-memory form, or null for a damaged one: every key present and no other, the loser one of the
## two sides, the winner -1, 0 or 1, the days 1 to 8, every count an int32 in range.
static func _end_from(value: Variant, attacker: String, defender: String) -> Variant:
	if not (value is Dictionary):
		return null
	var raw := value as Dictionary
	for key: Variant in raw:
		if not END_KEYS.has(str(key)):
			return null
	for key: String in END_KEYS:
		if not raw.has(key):
			return null
	for key: String in ["how", "cause", "loser"]:
		if not (raw[key] is String or raw[key] is StringName):
			return null
	var loser := str(raw["loser"])
	if loser != attacker and loser != defender:
		return null
	var winner: Variant = Unit.int32(raw["winner"])
	var days: Variant = Unit.int32(raw["days"])
	var sacked: Variant = Unit.int32(raw["sacked"])
	if winner == null or absi(int(winner)) > 1 or days == null or int(days) < 1 or int(days) > MAX_DAYS:
		return null
	if sacked == null or int(sacked) < 0 or typeof(raw["stormed"]) != TYPE_BOOL:
		return null
	var men: Variant = _int_map(raw["men"], -1, 0, -1)
	var morale: Variant = _int_map(raw["morale"], -1, 0, Unit.MAX_MORALE)
	var wounded: Variant = _int_map(raw["wounded"], -1, 0, -1)
	var returned: Variant = _int_map(raw["returned"], -1, 0, -1)
	var garrison: Variant = _garrison_from(raw["garrison"])
	var retreat: Variant = _retreat_from(raw["retreat"])
	if men == null or morale == null or wounded == null or returned == null or garrison == null or retreat == null:
		return null
	# killed and wounded_total are per side (attacker, defender): exactly two counts each (Stats reads index 0 and 1).
	var killed: Variant = _side_pair(raw["killed"], "end.killed")
	var wounded_total: Variant = _side_pair(raw["wounded_total"], "end.wounded_total")
	if killed == null or wounded_total == null:
		return null
	var lost_whole: Variant = _ints_checked(raw["lost_whole"], -1, 0)
	var surrendered: Variant = _ints_checked(raw["surrendered"], -1, 0)
	if lost_whole == null or surrendered == null:
		return _refuse("end.lost_whole and end.surrendered must be lists of whole numbers 0 and up")
	return {
		"how": str(raw["how"]), "cause": str(raw["cause"]), "winner": int(winner), "loser": loser,
		"days": int(days), "men": men, "morale": morale, "wounded": wounded, "killed": killed,
		"wounded_total": wounded_total, "lost_whole": lost_whole, "garrison": garrison, "retreat": retreat,
		"surrendered": surrendered, "returned": returned, "stormed": bool(raw["stormed"]), "sacked": int(sacked),
	}


## {} or {men, morale}: the garrison's men (an int32) and its morale (0 to MAX_MORALE).
static func _garrison_from(value: Variant) -> Variant:
	if not (value is Dictionary):
		return null
	var raw := value as Dictionary
	if raw.is_empty():
		return {}
	if raw.size() != 2 or not raw.has("men") or not raw.has("morale"):
		return null
	var men: Variant = Unit.int32(raw["men"])
	var morale: Variant = Unit.int32(raw["morale"])
	if men == null or int(men) < 0 or morale == null or int(morale) < 0 or int(morale) > Unit.MAX_MORALE:
		return null
	return {"men": int(men), "morale": int(morale)}


## Army id (1 and up) -> the spot it retreated to (a pair of int32).
static func _retreat_from(value: Variant) -> Variant:
	if not (value is Dictionary):
		return null
	var out := {}
	for key: Variant in value as Dictionary:
		var army: Variant = _key_of(key)
		var spot: Variant = Unit.hex_from((value as Dictionary)[key])
		if army == null or int(army) < 1 or spot == null or out.has(int(army)):
			return null
		out[int(army)] = spot
	return out


## A map keyed by unit id (from key_low, -1 for the garrison) with int32 values from val_low to val_high (-1: no top);
## keys are canonical int text or ints, and no two keys may name the same int. Null for anything else.
static func _int_map(value: Variant, key_low: int, val_low: int, val_high: int) -> Variant:
	if not (value is Dictionary):
		return null
	var out := {}
	for key: Variant in value as Dictionary:
		var k: Variant = _key_of(key)
		var n: Variant = Unit.int32((value as Dictionary)[key])
		if k == null or int(k) < key_low or n == null or int(n) < val_low or (val_high >= 0 and int(n) > val_high):
			return null
		if out.has(int(k)):
			return null
		out[int(k)] = int(n)
	return out


## A key as an int: an int, or canonical int text ("7", "-1"; not "+7", "07" or "-0"); null otherwise.
static func _key_of(key: Variant) -> Variant:
	if typeof(key) == TYPE_INT:
		return key
	if key is String or key is StringName:
		var found: Variant = _canonical_int(str(key))
		if found != null and int(found) >= Unit.INT32_MIN and int(found) <= Unit.INT32_MAX:
			return found
	return null


## Why the last record was refused (for the save's report and the tests); "" when none was refused for a stated reason.
static var refusal: String = ""


static func _refuse(reason: String) -> Variant:
	refusal = reason
	return null


## A per-side pair (attacker, defender): a list of exactly two int32 counts, each 0 and up. Null with a reason otherwise.
static func _side_pair(value: Variant, what: String) -> Variant:
	if not (value is Array or value is PackedInt32Array):
		return _refuse("%s is not a list" % what)
	var count := 0
	if value is Array:
		count = (value as Array).size()
	else:
		count = (value as PackedInt32Array).size()
	if count != 2:
		return _refuse("%s must have two counts (attacker, defender), not %d" % [what, count])
	var out: Variant = _ints_checked(value, 2, 0)
	if out == null:
		return _refuse("%s has a count that is not a whole number from 0 to 2147483647" % what)
	return out


## A PackedInt32Array of `size` int32 numbers at least `low` (size -1: any count); from a packed array or a list.
static func _ints_checked(value: Variant, size: int, low: int) -> Variant:
	if not (value is Array or value is PackedInt32Array):
		return null
	var out := PackedInt32Array()
	for item: Variant in value:
		var n: Variant = Unit.int32(item)
		if n == null or int(n) < low:
			return null
		out.append(int(n))
	if size >= 0 and out.size() != size:
		return null
	return out


## Plain input read back: text keys (sorted), whole numbers as ints, finite floats, lists, strings, bools; null otherwise.
static func _plain_read(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value as Dictionary:
			if not (key is String or key is StringName):
				return null
			var item: Variant = _plain_read((value as Dictionary)[key])
			if item == null:
				return null
			out[String(key)] = item
		return _sorted(out)
	if value is Array:
		var items: Array = []
		for item: Variant in value as Array:
			var got: Variant = _plain_read(item)
			if got == null:
				return null
			items.append(got)
		return items
	if typeof(value) == TYPE_BOOL or typeof(value) == TYPE_INT or value is String:
		return value
	if typeof(value) == TYPE_FLOAT:
		var f: float = value
		if is_nan(f) or is_inf(f):
			return null
		if f == roundf(f) and absf(f) <= EXACT_MAX:
			return int(f)
		return f
	return null


static func _witnesses_from(value: Variant) -> Variant:
	if not (value is Array or value is PackedStringArray):
		return null
	var out := PackedStringArray()
	for item: Variant in value:
		if not (item is String or item is StringName):
			return null
		out.append(str(item))
	return out
