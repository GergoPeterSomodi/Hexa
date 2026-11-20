## What changes about a country during a game (docs/architecture/m2-build-spec.md section 5.2 and 5.9).
## The treasury and the stores (M4, schema country/2) are here; armies (M6) and techs (M11) join with their systems.
class_name Country
extends RefCounted

const SCHEMA := "hexa-godot/country/2"
const NO_HEX := Vector2i(-1, -1)
## The flows of a stock (Stores.FLOWS.size(); test_stores pins the two equal): the width of flows_open.
const FLOW_COUNT := 6

## Country id in MapState.owner (1 to 254).
var id: int = 0
var tag: StringName = &""
## Capital hex on the map, or NO_HEX when off the map (outside power).
var capital: Vector2i = NO_HEX
var alive: bool = true
## Ducats in the treasury; written only by Treasury (docs/architecture/m4-build-spec.md 5.2).
var treasury: int = 0
## The season's money lines, in first-added order: {why: StringName, hex: Vector2i, amount: int, count: int}; whether a
## line is spending is derived from Treasury.SPENDING and never stored; written only by Treasury.
var ledger_open: Array[Dictionary] = []
## The treasury when ledger_open was opened.
var ledger_from: int = 0
## The last closed season: {turn, opening, closing, lines}; {} before the first; written only by Treasury.
var ledger_closed: Dictionary = {}
## Tax level: 0 Low, 1 Normal, 2 High; written only by EconomySeason.
var tax: int = 1
## Loads per good id; written only by Stores.
var stock: PackedInt32Array = PackedInt32Array()
## The season's flows, signed, flow-major: [flow * goods + good]; written only by Stores.
var flows_open: PackedInt32Array = PackedInt32Array()
## Bit per EconomySeason.NEEDS entry not fully met in the last production; written only by EconomySeason.
var short_mask: int = 0
## The stock when flows_open was opened.
var stock_from: PackedInt32Array = PackedInt32Array()
## The last closed season: {turn, opening: PackedInt32Array, closing, flows}; {} before the first; written only by Stores.
var goods_closed: Dictionary = {}


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
		"treasury": treasury,
		"tax": tax,
		"short_mask": short_mask,
		"ledger_open": _lines_to_array(ledger_open),
		"ledger_from": ledger_from,
		"ledger_closed": _ledger_to_dict(ledger_closed),
		"stock": stock,
		"flows_open": flows_open,
		"flows_shape": [int(flows_open.size() / float(FLOW_COUNT)), FLOW_COUNT],
		"stock_from": stock_from,
		"goods_closed": _goods_to_dict(goods_closed),
	}


## Restores a Country saved by to_dict, or returns null when the schema is wrong (country/1 included) or a field is
## malformed. A key that is missing takes its default; a key of the wrong type is refused.
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
	return c if c._load_economy(d) else null


## Stable text line used in Game.digest(): "id|tag|col,row|alive|treasury|tax|short_mask|ledger_from|open lines|
## closed ledger|stock|flows_open|stock_from|closed goods". A line is "why:col,row:amount:count", lines are joined by ";",
## a list of numbers by ","; the closed ledger is "turn:opening:closing;" and its lines, the closed goods
## "turn:opening:closing:flows" with comma lists.
func digest_text() -> String:
	return "%d|%s|%d,%d|%s|%d|%d|%d|%d|%s|%s|%s|%s|%s|%s" % [
		id, String(tag), capital.x, capital.y, "true" if alive else "false",
		treasury, tax, short_mask, ledger_from, _lines_text(ledger_open), _ledger_text(ledger_closed),
		_list_text(stock), _list_text(flows_open), _list_text(stock_from), _goods_text(goods_closed),
	]


## Reads the M4 fields of `d` into this country; false (nothing read) when one is malformed.
func _load_economy(d: Dictionary) -> bool:
	var ints := {"treasury": 0, "tax": 1, "short_mask": 0, "ledger_from": 0}
	for key: String in ints:
		var value: Variant = _whole(d.get(key, ints[key]))
		if value == null:
			return false
		ints[key] = int(value)
	var lines: Variant = _lines_from(d.get("ledger_open", []))
	var closed: Variant = _ledger_from(d.get("ledger_closed", {}))
	var goods: Variant = _goods_from(d.get("goods_closed", {}))
	var packs: Array = []
	for key: String in ["stock", "flows_open", "stock_from"]:
		packs.append(_ints_from(d.get(key, [])))
	if lines == null or closed == null or goods == null or packs.has(null):
		return false
	var flows: Variant = _relaid(packs[1], d.get("flows_shape", null))
	if flows == null or ints["tax"] < 0 or ints["tax"] > 2 or ints["short_mask"] < 0:
		return false
	var held: PackedInt32Array = _padded(packs[0])
	if held.size() > GoodDef.COUNT or _padded(packs[2]).size() != held.size():
		return false
	for key: String in ["opening", "closing"]:
		if not (goods as Dictionary).is_empty() and (goods[key] as PackedInt32Array).size() > GoodDef.COUNT:
			return false
	treasury = ints["treasury"]
	tax = ints["tax"]
	short_mask = ints["short_mask"]
	ledger_from = ints["ledger_from"]
	ledger_open.assign(lines as Array)
	ledger_closed = closed as Dictionary
	goods_closed = goods as Dictionary
	stock = _padded(packs[0])
	flows_open = flows
	stock_from = _padded(packs[2])
	return true


## A stock list of fewer than GoodDef.COUNT goods padded with 0 (a save from before a good was added); empty stays empty.
static func _padded(values: PackedInt32Array) -> PackedInt32Array:
	var out := values.duplicate()
	if not out.is_empty() and out.size() < GoodDef.COUNT:
		out.resize(GoodDef.COUNT)
	return out


## Flows saved with `shape` [goods, flows] laid out flow-major, re-laid into GoodDef.COUNT goods x FLOW_COUNT flows (a
## missing cell is 0). Null when the shape does not match the list; empty stays empty; no shape means the current one.
static func _relaid(values: PackedInt32Array, shape: Variant) -> Variant:
	if values.is_empty():
		return values
	var goods := GoodDef.COUNT
	var flows := FLOW_COUNT
	if shape != null:
		if not (shape is Array) or (shape as Array).size() != 2:
			return null
		var g: Variant = _whole((shape as Array)[0])
		var f: Variant = _whole((shape as Array)[1])
		if g == null or f == null or int(g) < 0 or int(f) < 0:
			return null
		goods = int(g)
		flows = int(f)
	if goods * flows != values.size():
		return null
	if goods == GoodDef.COUNT and flows == FLOW_COUNT:
		return values
	var out := PackedInt32Array()
	out.resize(GoodDef.COUNT * FLOW_COUNT)
	for flow: int in mini(flows, FLOW_COUNT):
		for good: int in mini(goods, GoodDef.COUNT):
			out[flow * GoodDef.COUNT + good] = values[flow * goods + good]
	return out


## A whole number from an int or a whole float (JSON gives floats); null for anything else, a bool and a string too.
static func _whole(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))):
		return int(value)
	return null


## A PackedInt32Array from a packed array or a list of whole numbers; null for anything else.
static func _ints_from(value: Variant) -> Variant:
	if value is PackedInt32Array:
		return (value as PackedInt32Array).duplicate()
	if not (value is Array):
		return null
	var out := PackedInt32Array()
	for item: Variant in value as Array:
		var n: Variant = _whole(item)
		if n == null:
			return null
		out.append(int(n))
	return out


static func _lines_to_array(lines: Array) -> Array:
	var out: Array = []
	for line: Dictionary in lines:
		var hex: Vector2i = line.get("hex", NO_HEX)
		out.append({
			"why": String(line.get("why", &"")), "hex": [hex.x, hex.y], "amount": int(line.get("amount", 0)),
			"count": int(line.get("count", 0)),
		})
	return out


## The lines as saved, or null when one is not {why: text, hex: two numbers, amount, count: numbers}.
static func _lines_from(value: Variant) -> Variant:
	if not (value is Array):
		return null
	var out: Array[Dictionary] = []
	for item: Variant in value as Array:
		if not (item is Dictionary):
			return null
		var raw := item as Dictionary
		var hex: Variant = raw.get("hex", null)
		var amount: Variant = _whole(raw.get("amount", null))
		var count: Variant = _whole(raw.get("count", null))
		var why_type := typeof(raw.get("why", null))
		if (why_type != TYPE_STRING and why_type != TYPE_STRING_NAME) or amount == null or count == null:
			return null
		var cell := NO_HEX
		if hex is Vector2i:
			cell = hex
		elif hex is Array and (hex as Array).size() == 2:
			var col: Variant = _whole((hex as Array)[0])
			var row: Variant = _whole((hex as Array)[1])
			if col == null or row == null:
				return null
			cell = Vector2i(int(col), int(row))
		else:
			return null
		out.append({"why": StringName(str(raw["why"])), "hex": cell, "amount": int(amount), "count": int(count)})
	return out


static func _ledger_to_dict(ledger: Dictionary) -> Dictionary:
	if ledger.is_empty():
		return {}
	return {"turn": int(ledger["turn"]), "opening": int(ledger["opening"]), "closing": int(ledger["closing"]),
			"lines": _lines_to_array(ledger.get("lines", []))}


static func _ledger_from(value: Variant) -> Variant:
	if not (value is Dictionary):
		return null
	var raw := value as Dictionary
	if raw.is_empty():
		return {}
	var turn: Variant = _whole(raw.get("turn", null))
	var opening: Variant = _whole(raw.get("opening", null))
	var closing: Variant = _whole(raw.get("closing", null))
	var lines: Variant = _lines_from(raw.get("lines", null))
	if turn == null or opening == null or closing == null or lines == null:
		return null
	return {"turn": int(turn), "opening": int(opening), "closing": int(closing), "lines": lines}


static func _goods_to_dict(closed: Dictionary) -> Dictionary:
	if closed.is_empty():
		return {}
	var flows: PackedInt32Array = closed["flows"]
	return {"turn": int(closed["turn"]), "opening": closed["opening"], "closing": closed["closing"],
			"flows": flows, "flows_shape": [int(flows.size() / float(FLOW_COUNT)), FLOW_COUNT]}


static func _goods_from(value: Variant) -> Variant:
	if not (value is Dictionary):
		return null
	var raw := value as Dictionary
	if raw.is_empty():
		return {}
	var turn: Variant = _whole(raw.get("turn", null))
	var opening: Variant = _ints_from(raw.get("opening", null))
	var closing: Variant = _ints_from(raw.get("closing", null))
	var flows: Variant = _ints_from(raw.get("flows", null))
	var laid: Variant = _relaid(flows, raw.get("flows_shape", null)) if flows != null else null
	if turn == null or opening == null or closing == null or laid == null:
		return null
	return {"turn": int(turn), "opening": _padded(opening), "closing": _padded(closing), "flows": laid}


static func _lines_text(lines: Array) -> String:
	var parts := PackedStringArray()
	for line: Dictionary in lines:
		var hex: Vector2i = line.get("hex", NO_HEX)
		parts.append("%s:%d,%d:%d:%d" % [String(line.get("why", &"")), hex.x, hex.y, int(line.get("amount", 0)),
				int(line.get("count", 0))])
	return ";".join(parts)


static func _list_text(values: PackedInt32Array) -> String:
	var parts := PackedStringArray()
	for v: int in values:
		parts.append(str(v))
	return ",".join(parts)


static func _ledger_text(ledger: Dictionary) -> String:
	if ledger.is_empty():
		return ""
	return "%d:%d:%d;%s" % [int(ledger["turn"]), int(ledger["opening"]), int(ledger["closing"]),
			_lines_text(ledger.get("lines", []))]


static func _goods_text(closed: Dictionary) -> String:
	if closed.is_empty():
		return ""
	return "%d:%s:%s:%s" % [int(closed["turn"]), _list_text(closed["opening"]), _list_text(closed["closing"]),
			_list_text(closed["flows"])]
