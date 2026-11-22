## The read-only siege view (docs/architecture/m7-build-spec.md 4.5, 4.15, 5.6, M7 B14): a siege of a fortress hex as the viewer
## may see it. Fog (Knowledge.siege_access): exact for the viewer "", the besieger and the controller (the meter, the men, the
## rate, the forecast season and the defender's relief); seen while the viewer sees the hex (the meter exact, the men banded,
## no rate, no forecast, no relief); hidden otherwise, and a siege between countries at peace is none for everyone.
## The garrison: exact for its owner, banded while the viewer sees the hex, "a garrison" otherwise. Pure core/views/ code.
@warning_ignore_start("integer_division")
class_name SiegeView
extends RefCounted

const RELIEF_SEASONS := 4
const RELIEF_LIMIT := 3
const TONE_GOOD := &"good"
const TONE_BAD := &"bad"
const TONE_PLAIN := &"plain"
const UNKNOWN_NAME := "a country"


## The siege of a hex as the viewer sees it; {} when none stands, or it is hidden. Keys: access, hex, name, place, besieger,
## defender (tags), besieger_name, defender_name, progress, need, seasons, stores_left, starving, hunger, garrison_text,
## men_text, rate and falls_in (-1 unless exact), relief ([] unless the viewer is the defender or ""). Cached by
## [&"siege_view", version, viewer, hex].
static func at(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
	var key: Array = [&"siege_view", game.version, viewer, hex]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make_at(game, viewer, hex)) as Dictionary


## The dials of every siege the viewer may see, in hex index order: {hex, progress, need, tone} (tone good for the
## besieger, bad for the defender, plain for a viewer who is neither). Cached by [&"sieges", version, viewer].
static func all(game: Game, viewer: StringName) -> Array[Dictionary]:
	var key: Array = [&"sieges", game.version, viewer]
	return game.view_cache.get_or_make(key, func() -> Array[Dictionary]: return _make_all(game, viewer)) as Array[Dictionary]


static func _make_at(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
	var s := Occupation.siege_at(game, hex)
	if s == null:
		return {}
	var acc := Knowledge.siege_access(game, viewer, hex)
	if acc == &"hidden":
		return {}
	var holder := Occupation.controller_tag(game, hex)
	var exact := acc == &"exact"
	var war := game.defs.war
	var level := Occupation.fortress_level(game, hex)
	var out := {
		"access": acc, "hex": hex, "name": s.name, "place": Words.place(game, hex),
		"besieger": _key(game, viewer, s.besieger, exact, "besieger"), "defender": _key(game, viewer, holder, exact, "defender"),
		"besieger_name": _name_seen(game, viewer, s.besieger, exact), "defender_name": _name_seen(game, viewer, holder, exact),
		"progress": s.progress, "need": Occupation.siege_need(game, hex), "seasons": s.seasons,
		"stores_left": maxi(0, 1 + level - s.seasons), "starving": Sieges.starving(game, hex),
		"hunger": 0, "garrison_text": _garrison_text(game, viewer, hex, holder),
		"rate": -1, "falls_in": -1, "relief": [], "men_text": "", "men": 0,
	}
	if bool(out["starving"]):
		out["hunger"] = war.siege_hunger
	var men := Sieges.terms(game, hex, s.besieger)
	if exact:
		out["men"] = int(men["men"])
		out["men_text"] = Words.men(int(men["men"]))
		out["rate"] = int(men["rate"])
		out["falls_in"] = Sieges.forecast(game, hex, s.besieger, int(men["men"]), int(men["guns"]), s.progress, s.seasons)
		if viewer == &"" or viewer == holder:
			out["relief"] = _relief(game, holder, hex)
	else:
		out["men_text"] = Knowledge.band_text(int(men["men"]), "men")
	return out


static func _make_all(game: Game, viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Siege in game.sieges:
		var acc := Knowledge.siege_access(game, viewer, s.hex)
		if acc == &"hidden":
			continue
		var holder := Occupation.controller_tag(game, s.hex)
		var tone := TONE_PLAIN
		if viewer != &"" and viewer == s.besieger:
			tone = TONE_GOOD
		elif viewer != &"" and viewer == holder:
			tone = TONE_BAD
		out.append({"hex": s.hex, "progress": s.progress, "need": Occupation.siege_need(game, s.hex), "tone": tone})
	return out


## The garrison as the viewer reads it: exact for its owner (and the viewer ""), banded while the viewer sees the hex, else
## "a garrison".
static func _garrison_text(game: Game, viewer: StringName, hex: Vector2i, holder: StringName) -> String:
	var full := Occupation.garrison_full(game, hex)
	var men := Occupation.garrison_of(game, hex)
	if viewer == &"" or viewer == holder:
		return "garrison %s of %s" % [Words.number(men), Words.number(full)]
	if Knowledge.sees(game, viewer, hex):
		return "garrison about %s of %s" % [Words.number(Knowledge.band(men)), Words.number(full)]
	return "a garrison"


## The defender's armies that can reach the besieged hex within RELIEF_SEASONS seasons: nearest first (ties by army id),
## at most RELIEF_LIMIT: {army (id), hex, men_text, seasons}. Walks as PathSearch.reach gives them with four seasons of move
## points (an approximation: the seasons are the walk's cost over the move points, rounded up).
static func _relief(game: Game, holder: StringName, hex: Vector2i) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var target := game.map.index_of(hex)
	var steps := StepCosts.of(game.map, game.defs)
	var allowed := Movement.open_mask(game, holder)
	var winter := Calendar.is_winter(game.turn)
	for a: Army in Armies.of_country(game, holder):
		var mp := Movement.mp_of(game, a)
		if mp <= 0 or a.hex == hex:
			continue
		var reach := PathSearch.reach(game.map, steps, allowed, a.hex, RELIEF_SEASONS * mp, winter)
		if not reach.has(target):
			continue
		var cost := int(reach[target])
		var seasons := maxi(1, (cost + mp - 1) / mp)
		if seasons > RELIEF_SEASONS:
			continue
		found.append({"army": a.id, "hex": a.hex, "men_text": Words.men(a.men()), "seasons": seasons})
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return x["seasons"] < y["seasons"] or (x["seasons"] == y["seasons"] and x["army"] < y["army"]))
	var nearest: Array[Dictionary] = []
	for i: int in mini(RELIEF_LIMIT, found.size()):
		nearest.append(found[i])
	return nearest


## A country's name as the viewer reads it: the real one for an exact view or a country the viewer knows; "a country" otherwise.
static func _name_seen(game: Game, viewer: StringName, tag: StringName, exact: bool) -> String:
	if _named(game, viewer, tag, exact):
		return _country_name(game, tag)
	return UNKNOWN_NAME


## Whether the viewer may read a country of the siege (its name, its tag): an exact view, the country itself, or a country the
## viewer knows (Knowledge.knows). Any other country is shown by its role only (4.15, as the battle view).
static func _named(game: Game, viewer: StringName, tag: StringName, exact: bool) -> bool:
	return exact or viewer == tag or Knowledge.knows(game, viewer, tag)


## The key of a country in the view: its tag when the viewer may read it, else its role word.
static func _key(game: Game, viewer: StringName, tag: StringName, exact: bool, role: String) -> String:
	return String(tag) if _named(game, viewer, tag, exact) else role


static func _country_name(game: Game, tag: StringName) -> String:
	if tag == &"":
		return ""
	var cdef := Countries.def_of(game, tag)
	if cdef != null:
		if not cdef.long_name.is_empty():
			return cdef.long_name
		if not cdef.name.is_empty():
			return cdef.name
	return String(tag)
