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
