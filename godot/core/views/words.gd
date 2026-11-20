## Shared word helpers for the read models: numbers, plurals, places, lists, countries, seasons
## (docs/architecture/m3-build-spec.md 5.6). Pure core/views/ code: no nodes, no engine calls, no luck.
class_name Words
extends RefCounted

const MINUS := "−"
## A named place counts as "near" within this many hexes.
const NEAR := 2


## "1,240"; a negative number takes the true minus sign: "−1,240".
static func number(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var count := 0
	for i: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return (MINUS + out) if n < 0 else out


## "+86", "−6", "0".
static func signed(n: int) -> String:
	if n > 0:
		return "+" + number(n)
	return number(n)


## "1 work", "2 works": the count and the matching word.
static func plural(n: int, one: String, many: String) -> String:
	return "%s %s" % [number(n), one if n == 1 else many]


## "1 season", "4 seasons".
static func seasons(n: int) -> String:
	return plural(n, "season", "seasons")


## "Savona (6, 13)" for the hex of a named place; "near Savona (7, 12)" for a hex within 2 hexes of one (the nearest,
## ties by place order); "(7, 12)" otherwise.
static func place(game: Game, hex: Vector2i) -> String:
	var coords := "(%d, %d)" % [hex.x, hex.y]
	if game == null or game.map == null:
		return coords
	var best_name := ""
	var best_distance := NEAR + 1
	for entry: Dictionary in game.map.places:
		var place_name := str(entry.get("name", ""))
		var at: Variant = entry.get("hex", null)
		if place_name == "" or typeof(at) != TYPE_VECTOR2I:
			continue
		var distance := ImproveRules.hex_distance(hex, at as Vector2i)
		if distance == 0:
			return "%s %s" % [place_name, coords]
		if distance < best_distance:
			best_distance = distance
			best_name = place_name
	if best_name == "":
		return coords
	return "near %s %s" % [best_name, coords]


## "a, b and 2 more": the first `shown` items, then how many are left. Up to `shown` items are all named.
static func list(items: Array[String], shown: int = 2) -> String:
	var keep := maxi(shown, 1)
	if items.size() <= keep:
		if items.size() <= 1:
			return items[0] if items.size() == 1 else ""
		return "%s and %s" % [", ".join(PackedStringArray(items.slice(0, items.size() - 1))), items[items.size() - 1]]
	return "%s and %d more" % [", ".join(PackedStringArray(items.slice(0, keep))), items.size() - keep]


## "the Republic of Genoa"; "" for no tag. Falls back to the short name, then the tag.
static func country_the(game: Game, tag: StringName) -> String:
	if tag == &"":
		return ""
	var def := Countries.def_of(game, tag)
	var label := String(tag)
	if def != null:
		if not def.long_name.is_empty():
			label = def.long_name
		elif not def.name.is_empty():
			label = def.name
	return "the " + label
