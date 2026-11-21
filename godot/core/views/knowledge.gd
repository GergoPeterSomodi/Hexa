## Who knows whom, and what a viewer is told (docs/architecture/m3-build-spec.md sections 4.7 and 5.6; style spec 6.5).
## `knows` is a shared border (Territory.neighbours) or an explored hex the other holds (M6, 4.11, through Sight). The
## viewer "" sees all.
## Pure core/views/ code: no nodes, no engine calls, no luck.
class_name Knowledge
extends RefCounted

const MINUS := "−"


## True when `viewer` knows `other`: the same tag, a neighbour by a shared land border, or either tag is "" (the sandbox
## viewer and a public party). A tag with no country knows only itself.
static func knows(game: Game, viewer: StringName, other: StringName) -> bool:
	if viewer == &"" or other == &"" or viewer == other:
		return true
	var viewer_country := Countries.by_tag(game, viewer)
	var other_country := Countries.by_tag(game, other)
	if viewer_country == null or other_country == null:
		return false
	return Territory.neighbours(game, viewer_country.id).has(other_country.id) or Sight.explored_any(game, viewer, other)


## The tags `viewer` knows, in country id order, the viewer excluded. The viewer "" knows every country.
static func known(game: Game, viewer: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if game == null:
		return out
	if viewer == &"":
		for c: Country in game.countries:
			if c != null and c.tag != &"":
				out.append(c.tag)
		return out
	var viewer_country := Countries.by_tag(game, viewer)
	if viewer_country == null:
		return out
	# The same clause as knows: the shared border, or the explored set (Sight.known_of), read once per call.
	var border := Territory.neighbours(game, viewer_country.id)
	var learned: PackedByteArray = game.sight.known_of(game, viewer_country.id)
	for c: Country in game.countries:
		if c != null and c.tag != &"" and c.tag != viewer and (border.has(c.id) or (c.id < learned.size() and learned[c.id] == 1)):
			out.append(c.tag)
	return out


## How many countries (the viewer excluded) `viewer` does not know.
static func unknown_count(game: Game, viewer: StringName) -> int:
	if game == null:
		return 0
	var total := 0
	for c: Country in game.countries:
		if c != null and c.tag != &"" and c.tag != viewer:
			total += 1
	return total - known(game, viewer).size()


## True when the viewer sees `hex` now (the viewer "" sees all). Sight does the work (4.11).
static func sees(game: Game, viewer: StringName, hex: Vector2i) -> bool:
	return viewer == &"" or Sight.sees(game, viewer, hex)


## The armies in the viewer's sight that are not its own, in id order: {army, tag, hex, men_banded}. The viewer "" gets
## every army; men_banded is `band` of the men (the exact count is army.men(), which the viewer "" may read).
static func armies_seen(game: Game, viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null:
		return out
	for army: Army in game.armies:
		if army == null:
			continue
		if viewer != &"" and (army.tag == viewer or not Sight.sees(game, viewer, army.hex)):
			continue
		out.append({"army": army, "tag": army.tag, "hex": army.hex, "men_banded": band(army.men())})
	return out


## Two significant figures, half away from zero, sign kept: 87 -> 87, 1,234 -> 1,200, 1,250 -> 1,300,
## -1,234 -> -1,200, 99,960 -> 100,000.
static func band(n: int) -> int:
	if n == 0:
		return 0
	var a := absi(n)
	var scale := 1
	while a >= 100 * scale:
		scale *= 10
	var q := floori(float(a) / float(scale))
	if (a % scale) * 2 >= scale:
		q += 1
	return (-1 if n < 0 else 1) * q * scale


## "about 1,200 ducats"; "about 87" when `unit` is "".
static func band_text(n: int, unit: String) -> String:
	var text := "about " + _grouped(band(n))
	if unit != "":
		text += " " + unit
	return text


## True when the viewer is told of `event` (a chronicle entry: tag, others, witnesses; style spec 6.5):
## the viewer "" is told everything; the actor (`tag`) and each of `others` are told; a non-empty `witnesses` list
## tells exactly the tags it holds; an event with no witness list is public, seen by whoever knows its actor.
static func witnessed(game: Game, event: Dictionary, viewer: StringName) -> bool:
	if viewer == &"":
		return true
	var tag := StringName(str(event.get("tag", "")))
	if tag == viewer or _names(event.get("others", [])).has(viewer):
		return true
	var witnesses := _names(event.get("witnesses", []))
	if not witnesses.is_empty():
		return witnesses.has(viewer)
	return knows(game, viewer, tag)


## The tags of a Variant list (an Array of StringName or String, or the PackedStringArray the Chronicle stores);
## [] for anything else.
static func _names(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return out
	for item: Variant in value:
		out.append(StringName(str(item)))
	return out


## "1,234" with a comma every three digits; a minus sign (MINUS) for a negative number.
static func _grouped(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var count := 0
	for i: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits.substr(i, 1) + out
		count += 1
	if n < 0:
		out = MINUS + out
	return out
