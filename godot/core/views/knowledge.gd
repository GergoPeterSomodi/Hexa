## Who knows whom, and what a viewer is told (docs/architecture/m3-build-spec.md sections 4.7 and 5.6; style spec 6.5).
## `knows` is a shared border (Territory.neighbours) or an explored hex the other holds (M6, 4.11, through Sight). The
## viewer "" sees all.
## Pure core/views/ code: no nodes, no engine calls, no luck.
@warning_ignore_start("integer_division")
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


## True when `viewer` has discovered `hex` (D1, R1): the viewer "" sees all; else the hex is in the viewer's explored set (a walk,
## the start, the vision phase, a district it took) or the viewer sees it now. One test for the player, the views and the AI.
static func discovered(game: Game, viewer: StringName, hex: Vector2i) -> bool:
	if viewer == &"":
		return true
	if game == null:
		return false
	return Sight.explored(game, viewer, hex) or Sight.sees(game, viewer, hex)


## What `viewer` has seen of the land of `other` (R26, D9): its districts and their people, over the hexes the viewer has
## discovered. The viewer "" gets all of them; a viewer that has discovered every district gets the whole land. Cached per
## game.version in the view cache. Every writer of explored (Sight.setup, see_path, season, the R9 and R10 marks) must bump
## game.version, or this cache goes stale. {districts, people}.
static func land_seen(game: Game, viewer: StringName, other: StringName) -> Dictionary:
	if game == null or game.view_cache == null or game.state == null or game.map == null:
		return {"districts": 0, "people": 0}
	var c := Countries.by_tag(game, other)
	if c == null:
		return {"districts": 0, "people": 0}
	var key: Array = [&"land_seen", game.version, viewer, other]
	var id := c.id
	return (game.view_cache.get_or_make(key, func() -> Dictionary: return _make_land_seen(game, viewer, id)) as Dictionary).duplicate()


static func _make_land_seen(game: Game, viewer: StringName, id: int) -> Dictionary:
	var out := {"districts": 0, "people": 0}
	if game.state.people.size() != game.map.hex_count():
		return out
	for i: int in Territory.districts(game, id):
		if discovered(game, viewer, game.map.hex_of(i)):
			out["districts"] = int(out["districts"]) + 1
			out["people"] = int(out["people"]) + int(game.state.people[i])
	return out


## The men under arms of `other` as `viewer` may read them (M8, from the Stats of the last closed season): exact for every
## country the viewer knows (R24, D7: no band); -1 for one it does not know (or one with no country, or a game with no
## statistics). Pure.
static func men_of(game: Game, viewer: StringName, other: StringName) -> int:
	if game == null or game.stats == null:
		return -1
	if viewer != &"" and other != viewer and not knows(game, viewer, other):
		return -1
	if Countries.by_tag(game, other) == null:
		return -1
	return game.stats.value(other, game.stats.last_turn, "army_men")


## What `viewer` may read of a fortress's garrison (R19, D6): {men, access}. A discovered fortress, for any viewer and any
## holder (own, other, or occupied by a third): the real garrison, &"exact" (no rounding, no assumed value). An undiscovered
## one: -1 and &"hidden" (its garrison is never read). A hex with no fortress: 0 and &"none".
static func garrison_known(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
	if game == null or Occupation.fortress_level(game, hex) <= 0:
		return {"men": 0, "access": &"none"}
	if not discovered(game, viewer, hex):
		return {"men": -1, "access": &"hidden"}
	return {"men": Occupation.garrison_of(game, hex), "access": &"exact"}


## The armies in the viewer's sight that are not its own, in id order: {army, tag, hex, men}. The viewer "" gets every
## army; men are exact (R25).
static func armies_seen(game: Game, viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null:
		return out
	for army: Army in game.armies:
		if army == null:
			continue
		if viewer != &"" and (army.tag == viewer or not Sight.sees(game, viewer, army.hex)):
			continue
		out.append({"army": army, "tag": army.tag, "hex": army.hex, "men": army.men()})
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
## tells exactly the tags it holds; an event with no witness list is public, seen by whoever knows its actor. A land event
## (`land: true`, D12) is told to a viewer that has discovered its hex, and to no one else on the list (R29).
static func witnessed(game: Game, event: Dictionary, viewer: StringName) -> bool:
	if viewer == &"":
		return true
	var tag := StringName(str(event.get("tag", "")))
	if tag == viewer or _names(event.get("others", [])).has(viewer):
		return true
	if bool(event.get("land", false)):
		return not land_hexes(game, viewer, event).is_empty()
	var witnesses := _names(event.get("witnesses", []))
	if not witnesses.is_empty():
		return witnesses.has(viewer)
	return knows(game, viewer, tag)


## What a viewer may see of a battle record (4.15, M7): &"exact" for the viewer "" and for a side of the battle (the
## attacker or the defender: the numbers of both sides); &"seen" when the viewer witnessed it (its tag is in the record's
## witnesses: the men rounded, the morale rounded, no stances and no ids); else &"hidden". Pure.
static func battle_access(_game: Game, viewer: StringName, record: BattleRecord) -> StringName:
	if record == null:
		return &"hidden"
	if viewer == &"" or viewer == record.attacker or viewer == record.defender:
		return &"exact"
	if record.witnesses.has(String(viewer)):
		return &"seen"
	return &"hidden"


## What a viewer may see of the siege of a hex (4.5, 4.15, M7): &"hidden" when no siege stands there or the besieger and
## the hex's controller are not at war (a siege between countries at peace is shown as none, for every viewer); &"exact"
## for the viewer "", the besieger and the controller; &"seen" while the viewer sees the hex (Sight); &"land" while it has only
## discovered the hex (R21); else &"hidden".
static func siege_access(game: Game, viewer: StringName, hex: Vector2i) -> StringName:
	var s := Occupation.siege_at(game, hex)
	if s == null:
		return &"hidden"
	var holder := Occupation.controller_tag(game, hex)
	if holder == &"" or not Wars.at_war(game, s.besieger, holder):
		return &"hidden"
	if viewer == &"" or viewer == s.besieger or viewer == holder:
		return &"exact"
	if sees(game, viewer, hex):
		return &"seen"
	if discovered(game, viewer, hex):
		return &"land"
	return &"hidden"


## The hexes of a land event (`hex`, or the `hexes` list of an owners_changed) that `viewer` has discovered, in the event's
## order; the viewer "" gets all of them. A land event is told to a viewer with at least one of them (R29, R30).
static func land_hexes(game: Game, viewer: StringName, event: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var candidates: Array = []
	var at: Variant = event.get("hex", null)
	if at is Vector2i:
		candidates.append(at)
	var listed: Variant = event.get("hexes", [])
	if typeof(listed) == TYPE_ARRAY:
		candidates.append_array(listed as Array)
	for hex: Variant in candidates:
		if hex is Vector2i and discovered(game, viewer, hex as Vector2i):
			out.append(hex as Vector2i)
	return out


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
