## The chronicle: the notable events of a game, oldest first, the newest KEEP kept (docs/architecture/m3-build-spec.md
## 4.4, 5.2). Written only by Game.emit. Entries are plain values, so they survive a round trip through bytes.
class_name Chronicle
extends RefCounted

const SCHEMA := "hexa-godot/chronicle/1"
const KEEP := 3000
const NOTABLE: Array[String] = ["work_started", "work_finished", "work_cancelled", "owners_changed", "country_chosen",
	"goods_short", "tax_set", "town_grew", "district_declined", "army_raised", "army_disbanded", "march_halted",
	"army_starved", "unit_lost"]

var entries: Array[Dictionary] = []


## A deep copy of an event: StringName becomes String, an array of tags becomes a PackedStringArray.
static func plain(event: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in event:
		out[_plain_value(key)] = _plain_value(event[key])
	return out


static func _plain_value(value: Variant) -> Variant:
	if value is StringName:
		return String(value)
	if value is Dictionary:
		return plain(value as Dictionary)
	if value is Array:
		var items := value as Array
		var all_tags := not items.is_empty()
		for item: Variant in items:
			if not (item is String or item is StringName):
				all_tags = false
				break
		if all_tags:
			var tags := PackedStringArray()
			for item: Variant in items:
				tags.append(String(item))
			return tags
		var copy: Array = []
		for item: Variant in items:
			copy.append(_plain_value(item))
		return copy
	return value


## Appends the plain form of the event; drops the oldest past KEEP.
func add(event: Dictionary) -> void:
	entries.append(plain(event))
	if entries.size() > KEEP:
		entries = entries.slice(entries.size() - KEEP)


## The entries of one turn, oldest first.
func of_turn(turn: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i := entries.size() - 1
	while i >= 0:
		var t := int(entries[i].get("turn", -1))
		if t == turn:
			out.push_front(entries[i])
		elif t < turn:
			break
		i -= 1
	return out


func to_dict() -> Dictionary:
	return {"schema": SCHEMA, "entries": entries.duplicate(true)}


## Null on a wrong schema or a mistyped entry.
static func from_dict(d: Dictionary) -> Chronicle:
	if str(d.get("schema", "")) != SCHEMA or not (d.get("entries") is Array):
		return null
	var out := Chronicle.new()
	for item: Variant in d["entries"] as Array:
		if not (item is Dictionary):
			return null
		out.entries.append(item as Dictionary)
	return out


func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(entries))
	return ctx.finish().hex_encode()
