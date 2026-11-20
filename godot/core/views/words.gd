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
	var names := _place_names(game)
	var seen: Dictionary = {hex: true}
	var ring: Array[Vector2i] = [hex]
	for distance: int in NEAR + 1:
		var best_name := ""
		var best_order := 1 << 30
		for at: Vector2i in ring:
			var held: Variant = names.get(at)
			if held != null and int((held as Array)[1]) < best_order:
				best_order = int((held as Array)[1])
				best_name = str((held as Array)[0])
		if best_name != "":
			return "%s %s" % [best_name, coords] if distance == 0 else "near %s %s" % [best_name, coords]
		var next: Array[Vector2i] = []
		for at: Vector2i in ring:
			for d: int in 6:
				var beside := ImproveRules.neighbour(at, d)
				if not seen.has(beside):
					seen[beside] = true
					next.append(beside)
		ring = next
	return coords


## hex -> [name, place order] for the named places of the map (the first of two on one hex), made once for a game and
## kept in its view cache: the scan of every place per call was the cost of a works line.
static func _place_names(game: Game) -> Dictionary:
	var key: Array = [game.map.id, game.map.places.size()]
	return game.view_cache.pinned(&"place_names", key, func() -> Dictionary:
		var out: Dictionary = {}
		for order: int in game.map.places.size():
			var entry: Dictionary = game.map.places[order]
			var place_name := str(entry.get("name", ""))
			var at: Variant = entry.get("hex", null)
			if place_name != "" and typeof(at) == TYPE_VECTOR2I and not out.has(at):
				out[at] = [place_name, order]
		return out) as Dictionary


## "a, b and 2 more": the first `shown` items, then how many are left. Up to `shown` items are all named.
## `separator` joins the named items before the last one ("; " when the items hold commas themselves).
static func list(items: Array[String], shown: int = 2, separator: String = ", ") -> String:
	var keep := maxi(shown, 1)
	if items.size() <= keep:
		if items.size() <= 1:
			return items[0] if items.size() == 1 else ""
		return "%s and %s" % [separator.join(PackedStringArray(items.slice(0, items.size() - 1))), items[items.size() - 1]]
	return "%s and %d more" % [separator.join(PackedStringArray(items.slice(0, keep))), items.size() - keep]


## The one singular noun of each family, for a sentence about the piece itself ("clearing the pasture"). The level
## families (settlements, castles, harbour) have level words as well (HexCard.LEVEL_WORDS).
const PIECE_NOUNS := {
	"settlements": "settlement", "castles": "castle", "wheat": "wheat field", "hemp": "hemp field",
	"silk": "mulberry grove", "dyes": "dye field", "vineyard": "vineyard", "olives": "olive grove",
	"grazing": "pasture", "timber": "woodland", "mines": "mine", "quarry": "quarry", "salt": "salt pans",
	"harbour": "harbour",
}
## Nouns that take no article ("salt pans" is plural).
const NO_ARTICLE: Array[String] = ["salt pans"]


## The singular noun of a family name ("olives" -> "olive grove"); the name itself when unknown.
static func piece_noun(family_name: String) -> String:
	return str(PIECE_NOUNS.get(family_name, family_name))


## "a vineyard", "an olive grove", "salt pans".
static func with_article(noun: String) -> String:
	if noun == "" or NO_ARTICLE.has(noun):
		return noun
	return ("an " if "aeiou".contains(noun.left(1)) else "a ") + noun


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
