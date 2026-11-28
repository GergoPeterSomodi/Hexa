## One queued company: the muster entry (docs/design/recruitment-queue.md sections 5 and 6; task RQ5). It is in no army:
## its men are in neither the people nor an army. Pure state: written only by Recruiting; saved in the body's `musters`
## and covered by Game.digest(). game.musters is in id order, the order the entries were queued in, so a settlement's
## training order is its entries in list order: the first is the company in training.
class_name Muster
extends RefCounted

const SCHEMA := "hexa-godot/muster/1"
## The most seasons an entry may have left: the limit of a work's seasons, not the kind's training time (a bound for a
## saved body; the countdown's rule is Recruiting's).
const SEASONS_MAX := FamilyDef.MAX_SEASONS
## The most ducats, and the most loads of one good, an entry may hold: a UnitDef's largest cost.
const PAID_MAX := UnitDef.MONEY_MAX

var id: int = 0
var tag: StringName = &""
## The settlement it is queued at.
var hex: Vector2i = Vector2i(-1, -1)
## UnitDef id.
var kind: int = 0
var queued_turn: int = 0
## The seasons of training still to run; 0 is a ready company that waits.
var seasons_left: int = 0
## Ducats paid when queued: what a withdrawal gives back.
var paid: int = 0
## Good key (String) -> loads paid.
var paid_goods: Dictionary = {}
## Where its men were levied, each [hex: Vector2i, men: int], in the order they were taken.
var levy: Array[Array] = []


## Plain: the tag as String, every hex as [col, row].
func to_dict() -> Dictionary:
	var sources: Array = []
	for source: Array in levy:
		var spot: Vector2i = source[0]
		sources.append([[spot.x, spot.y], int(source[1])])
	var goods: Dictionary = {}
	for key: Variant in paid_goods:
		goods[String(key)] = int(paid_goods[key])
	return {
		"schema": SCHEMA, "id": id, "tag": String(tag), "hex": [hex.x, hex.y], "kind": kind, "queued_turn": queued_turn,
		"seasons_left": seasons_left, "paid": paid, "paid_goods": goods, "levy": sources,
	}


## Null on a wrong schema, a missing or mistyped field, a number below 0 or past its bound, an unknown good, or a levy
## source that is not [hex, 1 man or more]. What the game knows (the id's place, the tag, the hex and the sources on the
## map, the kind and its men, the turn) is Recruiting.from_dict's to check.
static func from_dict(d: Dictionary) -> Muster:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var ints := {}
	for key: String in ["id", "kind", "queued_turn", "seasons_left", "paid"]:
		var value: Variant = Unit.int32(d.get(key, null))
		if value == null or int(value) < 0:
			return null
		ints[key] = int(value)
	if int(ints["seasons_left"]) > SEASONS_MAX or int(ints["paid"]) > PAID_MAX:
		return null
	var tag_value: Variant = d.get("tag", null)
	var cell: Variant = Unit.hex_from(d.get("hex", null))
	var goods: Variant = _goods_from(d.get("paid_goods", null))
	var sources: Variant = _levy_from(d.get("levy", null))
	if not (tag_value is String or tag_value is StringName) or cell == null or goods == null or sources == null:
		return null
	var m := Muster.new()
	m.id = ints["id"]
	m.tag = StringName(str(tag_value))
	m.hex = cell
	m.kind = ints["kind"]
	m.queued_turn = ints["queued_turn"]
	m.seasons_left = ints["seasons_left"]
	m.paid = ints["paid"]
	m.paid_goods = goods
	m.levy.assign(sources as Array)
	return m


## "id|tag|c,r|kind|queued_turn|seasons_left|paid|good:n,...|c,r:men,..." with the goods in good id order and the levy
## sources in their order.
func digest_text() -> String:
	var goods := PackedStringArray()
	for key: StringName in GoodDef.KEYS:
		if paid_goods.has(String(key)):
			goods.append("%s:%d" % [String(key), int(paid_goods[String(key)])])
	var sources := PackedStringArray()
	for source: Array in levy:
		var spot: Vector2i = source[0]
		sources.append("%d,%d:%d" % [spot.x, spot.y, int(source[1])])
	return "%d|%s|%d,%d|%d|%d|%d|%d|%s|%s" % [id, String(tag), hex.x, hex.y, kind, queued_turn, seasons_left, paid,
		",".join(goods), ",".join(sources)]


## {good key (String): loads} with known goods and loads 0 to PAID_MAX; null for anything else.
static func _goods_from(value: Variant) -> Variant:
	if not (value is Dictionary):
		return null
	var out := {}
	for key: Variant in value as Dictionary:
		var loads: Variant = Unit.int32((value as Dictionary)[key])
		if not (key is String or key is StringName) or not GoodDef.KEYS.has(StringName(str(key))):
			return null
		if loads == null or int(loads) < 0 or int(loads) > PAID_MAX:
			return null
		out[str(key)] = int(loads)
	return out


## [[hex, men], ...] with every source a pair of a hex and 1 man or more; null for anything else.
static func _levy_from(value: Variant) -> Variant:
	if not (value is Array):
		return null
	var out: Array = []
	for item: Variant in value as Array:
		if not (item is Array) or (item as Array).size() != 2:
			return null
		var spot: Variant = Unit.hex_from((item as Array)[0])
		var men: Variant = Unit.int32((item as Array)[1])
		if spot == null or men == null or int(men) < 1:
			return null
		out.append([spot, int(men)])
	return out
