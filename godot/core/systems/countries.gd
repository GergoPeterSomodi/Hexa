## Countries system (docs/architecture/m2-build-spec.md section 5.3):
## owns Game.countries and Game.player, handles country lookup, playability, and choose_country.
class_name Countries
extends RefCounted

const OWNS: Array[String] = ["countries", "player"]


## Populates `game.countries` in scenario id order and resets `game.player`.
static func setup(game: Game, scenario: ScenarioDef) -> void:
	if game == null:
		return
	game.countries.clear()
	game.player = &""
	if scenario == null:
		return
	for i: int in scenario.countries.size():
		var tag: StringName = scenario.countries[i]
		var cap: Vector2i = scenario.capitals[i] if i < scenario.capitals.size() else Country.NO_HEX
		game.countries.append(Country.create(i + 1, tag, cap, true))


## Returns the Country with `tag`, or null when not present.
static func by_tag(game: Game, tag: StringName) -> Country:
	if game == null or tag == &"":
		return null
	for c: Country in game.countries:
		if c != null and c.tag == tag:
			return c
	return null


## Returns the Country for 1-based `id`, or null for 0 or out of range.
static func by_id(game: Game, id: int) -> Country:
	if game == null or id <= 0 or id > game.countries.size():
		return null
	return game.countries[id - 1]


## Returns the CountryDef for `tag` from `game.defs`, or null when missing.
static func def_of(game: Game, tag: StringName) -> CountryDef:
	if game == null or game.defs == null or tag == &"":
		return null
	return game.defs.country(tag)


## True when `tag` exists, is alive, and has an on-map capital.
static func playable(game: Game, tag: StringName) -> bool:
	var c := by_tag(game, tag)
	if c == null or not c.alive:
		return false
	return c.capital != Country.NO_HEX


## Verdict `{ok, reason}` for `choose_country {tag}`.
static func choose_check(game: Game, args: Dictionary) -> Dictionary:
	if game == null or not game.has_countries():
		return _refusal("this map has no countries")
	if game.ai_only:
		return _refusal("this game is watched: every country is played by the computer")
	if game.player != &"":
		return _refusal("a country is chosen already: %s" % _country_name(game, game.player))
	var tag := _tag_arg(args)
	var c := by_tag(game, tag)
	if c == null:
		return _refusal("no country %s" % String(tag))
	if c.capital == Country.NO_HEX:
		var cdef := def_of(game, tag)
		var cname := _country_name(game, tag)
		var cap_name := cdef.capital_name if cdef != null and not cdef.capital_name.is_empty() else "off-map"
		return _refusal("%s cannot be played here: its capital, %s, is off this map" % [cname, cap_name])
	if not c.alive:
		return _refusal("%s is no more" % _country_name(game, tag))
	return {"ok": true, "reason": ""}


## Chooses the human player's country (after checking again) and queues `country_chosen`.
static func choose(game: Game, args: Dictionary) -> Dictionary:
	var verdict := choose_check(game, args)
	if bool(verdict["ok"]):
		var tag := _tag_arg(args)
		game.player = tag
		game.emit({"kind": "country_chosen", "tag": tag})
	return verdict


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _tag_arg(args: Dictionary) -> StringName:
	var raw: Variant = args.get("tag", &"")
	if raw is StringName:
		return raw
	if raw is String:
		return StringName(raw as String)
	return &""


static func _country_name(game: Game, tag: StringName) -> String:
	var cdef := def_of(game, tag)
	if cdef != null and not cdef.name.is_empty():
		return cdef.name
	return String(tag)
