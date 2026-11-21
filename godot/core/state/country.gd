## What changes about a country during a game (docs/architecture/m2-build-spec.md section 5.2 and 5.9).
## The treasury and the stores (M4), the people's flows (M5) and what was ever seen (M6, schema country/4) are here; techs (M11) join with their system.
class_name Country
extends RefCounted

const SCHEMA := "hexa-godot/country/4"
const NO_HEX := Vector2i(-1, -1)
## The flows of a stock (Stores.FLOWS.size(); test_stores pins the two equal): the width of flows_open.
const FLOW_COUNT := 6
## The people's flows (People.FLOWS.size()): the width of people_flows.
const PEOPLE_FLOW_COUNT := 6

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
## The open season's people flows, signed, by People.FLOWS; written only by People.
var people_flows: PackedInt32Array = PackedInt32Array()
## The last season ended: {turn, flows: PackedInt32Array}; {} before the first; written only by People.
var people_closed: Dictionary = {}
## The towns' food need of the season; written only by People (in the people phase).
var food_need: int = 0
## Food eaten x 1000 / need of the season (1000 when fed); written only by People.
var food_fed: int = 1000
## Bit i (byte i >> 3, bit i & 7) is set when hex i was ever seen by this country; empty in a map-only game. Written only by
## Vision (setup, see_path, season); never by refresh.
var explored: PackedByteArray = PackedByteArray()


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
		"people_flows": people_flows.duplicate(),
		"people_closed": _people_to_dict(people_closed),
		"food_need": food_need,
		"food_fed": food_fed,
		"explored": explored.duplicate(),
	}


## Restores a Country saved by to_dict, or returns null when the schema is wrong (country/1 to country/3 included: D40)
## or a field is malformed. A key that is missing takes its default; a key of the wrong type is refused.
static func from_dict(d: Dictionary) -> Country:
	var schema := str(d.get("schema", ""))
	if schema != SCHEMA:
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
	if not c._load_economy(d):
		return null
	if not c._load_people(d):
		return null
	var seen: Variant = d.get("explored", PackedByteArray())
	if not (seen is PackedByteArray):
		return null
	c.explored = (seen as PackedByteArray).duplicate()
	return c


## Stable text line used in Game.digest(): "id|tag|col,row|alive|treasury|tax|short_mask|ledger_from|open lines|
## closed ledger|stock|flows_open|stock_from|closed goods|people_flows|people_closed|food_need|food_fed|sha256 of explored (hex)".
## A line is "why:col,row:amount:count", lines are joined by ";", a list of numbers by ","; the closed ledger is "turn:opening:closing;" and its lines, the closed goods
## "turn:opening:closing:flows" with comma lists, the closed people "turn:flows".
func digest_text() -> String:
	return "%d|%s|%d,%d|%s|%d|%d|%d|%d|%s|%s|%s|%s|%s|%s|%s|%s|%d|%d|%s" % [
		id, String(tag), capital.x, capital.y, "true" if alive else "false",
		treasury, tax, short_mask, ledger_from, _lines_text(ledger_open), _ledger_text(ledger_closed),
		_list_text(stock), _list_text(flows_open), _list_text(stock_from), _goods_text(goods_closed),
		_list_text(people_flows), _people_text(people_closed), food_need, food_fed,
		_explored_hash(),
	]


## SHA-256 (hex) of explored, as Stats and Chronicle hash (HashingContext).
func _explored_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if not explored.is_empty():  # update() refuses no bytes; finish() alone gives the hash of nothing
		ctx.update(explored)
	return ctx.finish().hex_encode()


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


## Reads the M5 fields of `d` into this country; false (nothing read) when one is malformed. A key that is missing
## takes its default; a flows list of fewer than PEOPLE_FLOW_COUNT entries is padded with zeros, a longer one is refused.
func _load_people(d: Dictionary) -> bool:
	var flows: Variant = _ints_from(d.get("people_flows", []))
	var closed: Variant = _people_from(d.get("people_closed", {}))
	var need: Variant = _whole(d.get("food_need", 0))
	var fed: Variant = _whole(d.get("food_fed", 1000))
	if flows == null or closed == null or need == null or fed == null:
		return false
	if (flows as PackedInt32Array).size() > PEOPLE_FLOW_COUNT or int(need) < 0 or int(fed) < 0 or int(fed) > 1000:
		return false
	people_flows = _flows_padded(flows)
	people_closed = closed as Dictionary
	food_need = int(need)
	food_fed = int(fed)
	return true


## A people flows list padded with zeros to PEOPLE_FLOW_COUNT; empty stays empty.
static func _flows_padded(values: PackedInt32Array) -> PackedInt32Array:
	var out := values.duplicate()
	if not out.is_empty() and out.size() < PEOPLE_FLOW_COUNT:
		out.resize(PEOPLE_FLOW_COUNT)
	return out


static func _people_to_dict(closed: Dictionary) -> Dictionary:
	if closed.is_empty():
		return {}
	return {"turn": int(closed["turn"]), "flows": (closed["flows"] as PackedInt32Array).duplicate()}


## The closed people as saved, or null when it is neither {} nor {turn: number, flows: up to PEOPLE_FLOW_COUNT numbers}.
static func _people_from(value: Variant) -> Variant:
	if not (value is Dictionary):
		return null
	var raw := value as Dictionary
	if raw.is_empty():
		return {}
	var turn: Variant = _whole(raw.get("turn", null))
	var flows: Variant = _ints_from(raw.get("flows", null))
	if turn == null or int(turn) < 0 or flows == null or (flows as PackedInt32Array).size() > PEOPLE_FLOW_COUNT:
		return null
	return {"turn": int(turn), "flows": _flows_padded(flows)}


static func _people_text(closed: Dictionary) -> String:
	if closed.is_empty():
		return ""
	return "%d:%s" % [int(closed["turn"]), _list_text(closed["flows"])]


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
