## The improvement system's public face (docs/architecture/m1-build-spec.md section 8): build, upgrade and clear as
## check/action pairs over a Game, the facts of a hex read from MapData, and the one place that turns a hex's
## (family, level) into what the map draws. The search (WorldImprove, ImproveSolver) and the rules (ImproveRules) stay
## behind it. The system writes main_use and level of the game's MapState, and nothing else; each change queues one
## {kind: "hex_changed", hex} event on the game.
class_name Improve
extends RefCounted

## The state attributes this system writes (tests/core/test_improve_actions.gd checks that nothing else changes).
const OWNS: Array[String] = ["main_use", "level"]
const CLIMATES: Array[String] = ["snow", "frost", "mild"]  # MapData.climate 0, 1, 2


## What the rules read of a land hex, from the fixed map: cover (a WorldCover number), height_m, coast (the hex
## touches the sea), climate ("snow", "frost" or "mild"), river (a river or stream edge), road (a road of quality 2 or
## 3 leaves the hex), pass, place_level (0: no place), port, port_mode, landmark. The distances to places (place_distance,
## town_distance, city_distance, port_near) are added by WorldImprove, since they change as settlements grow.
static func facts_of(map: MapData, hex: Vector2i) -> Dictionary:
	var i := map.index_of(hex)
	var facts: Dictionary = {
		"cover": 0, "height_m": 0.0, "coast": false, "climate": "frost", "river": false, "road": false,
		"pass": false, "place_level": 0, "port": false, "port_mode": "", "landmark": "",
	}
	if i < 0:
		return facts
	facts["cover"] = int(map.cover[i])
	facts["height_m"] = float(map.height_m[i])
	facts["coast"] = map.coast_mask(hex) != 0
	facts["climate"] = CLIMATES[clampi(int(map.climate[i]), 0, 2)]
	facts["pass"] = map.pass_id[i] >= 0
	var wet := false
	var paved := false
	for d: int in 6:
		wet = wet or map.river_on(hex, d) > 0
		paved = paved or map.road_on(hex, d) >= 2
	facts["river"] = wet
	facts["road"] = paved
	var place := place_of(map, hex)
	if not place.is_empty() and int(place.get("level", 0)) >= 1:
		facts["place_level"] = clampi(int(place["level"]), 1, ImproveRules.TOP_LEVEL[ImproveRules.SETTLEMENT])
		facts["port"] = bool(place.get("port", false))
		facts["port_mode"] = _port_mode(place) if bool(facts["port"]) else ""
		facts["landmark"] = _landmark(place)
	return facts


## The place on a hex (an entry of MapData.places), or {}.
static func place_of(map: MapData, hex: Vector2i) -> Dictionary:
	var i := map.index_of(hex)
	if i < 0:
		return {}
	var p := map.place_id[i]
	if p < 0 or p >= map.places.size():
		return {}
	return map.places[p]


static func _port_mode(place: Dictionary) -> String:
	var mode := str(place.get("port_mode", ""))
	return mode if mode != "" else "seaside"


static func _landmark(place: Dictionary) -> String:
	var value: Variant = place.get("landmark", "")
	return str(value) if typeof(value) == TYPE_STRING else ""


## What stands on a hex: {} for a wild hex, else family (the piece module's name), family_id, level, variant, mirror,
## extra ("-", an animal, an ore or a landmark's name), addon (the harbour add-on's level, 0 for none) and addon_mode
## ("carved", "seaside" or "" when there is no add-on). The picture comes from the hex and the family alone (pick), so
## an upgrade never makes it jump. The harbour's sea side is left to the caller (it comes from the coast mask).
static func piece_of(map: MapData, state: MapState, hex: Vector2i) -> Dictionary:
	var i := map.index_of(hex)
	if i < 0 or map.land[i] == 0 or i >= state.main_use.size():
		return {}
	var f := int(state.main_use[i])
	if f <= ImproveRules.NONE or f >= ImproveRules.FAMILIES:
		return {}
	var lv := int(state.level[i])
	var chosen := ImproveRules.pick(hex, ImproveRules.VARIANTS[f])
	var place := place_of(map, hex)
	var port := bool(place.get("port", false)) and int(place.get("level", 0)) >= 1
	var extra := "-"
	var h := _hash(hex)
	if f == ImproveRules.GRAZING:
		# Cattle on the low meadows, horses on some of them, sheep on the hills and the high pastures.
		var metres := float(map.height_m[i])
		if metres < 300.0:
			extra = ImproveRules.ANIMALS[2] if h % 3 == 0 else ImproveRules.ANIMALS[1]
		else:
			extra = ImproveRules.ANIMALS[1] if (metres < 700.0 and h % 4 == 0) else ImproveRules.ANIMALS[0]
	elif f == ImproveRules.MINES:
		extra = ImproveRules.ORES[0] if h % 10 < 5 else (ImproveRules.ORES[1] if h % 10 < 8 else ImproveRules.ORES[2])
	elif f == ImproveRules.SETTLEMENT and _landmark(place) != "":
		extra = _landmark(place)
	var addon := 0
	if f == ImproveRules.SETTLEMENT and port and map.coast_mask(hex) != 0:
		addon = ImproveRules.ADDON_LEVEL[clampi(lv, 0, 5)]  # a port whose hex has no shore shows no harbour
	return {
		"family": ImproveRules.NAMES[f],
		"family_id": f,
		"level": lv,
		"variant": chosen.x,
		"mirror": chosen.y == 1,
		"extra": extra,
		"addon": addon,
		"addon_mode": _port_mode(place) if addon > 0 else "",
	}


## A stable number for a hex (picks the animal or the ore).
static func _hash(hex: Vector2i) -> int:
	var h := ((hex.x * 73856093) ^ (hex.y * 19349663)) & 0xffffffff
	h = ((h ^ (h >> 13)) * 0x5bd1e995) & 0xffffffff
	return (h >> 7) & 0xffff


static func piece_at(game: Game, hex: Vector2i) -> Dictionary:
	return piece_of(game.map, game.state, hex)


## The pieces a wild hex may take, each {family, family_id, level (1), ok, reason}; see WorldImprove.build_options.
static func build_options(game: Game, hex: Vector2i) -> Array[Dictionary]:
	return game.improvement.build_options(hex)


# ----- the actions: args build {hex, family, tag}, upgrade {hex, tag}, clear {hex, tag} ---------------------------


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


## The hex of the arguments, or null when it is missing or not a hex.
static func _hex_arg(args: Dictionary) -> Variant:
	var hex: Variant = args.get("hex", null)
	return hex if typeof(hex) == TYPE_VECTOR2I else null


static func _tag_arg(args: Dictionary) -> StringName:
	var raw: Variant = args.get("tag", &"")
	if raw is StringName:
		return raw
	if raw is String:
		return StringName(raw as String)
	return &""


static func _hex_and_home(game: Game, args: Dictionary) -> Dictionary:
	var hex: Variant = _hex_arg(args)
	if hex == null:
		return _refusal("no hex given")
	return Territory.at_home_check(game, _tag_arg(args), hex as Vector2i)


static func build_check(game: Game, args: Dictionary) -> Dictionary:
	var home := _hex_and_home(game, args)
	if not bool(home["ok"]):
		return home
	var family: Variant = args.get("family", null)
	if typeof(family) != TYPE_INT:
		return _refusal("no piece given")
	return game.improvement.build_check(args["hex"] as Vector2i, int(family))


## Builds level 1 of a family on a wild hex (after checking again), and queues hex_changed.
static func build(game: Game, args: Dictionary) -> Dictionary:
	var verdict := build_check(game, args)
	if bool(verdict["ok"]):
		var hex: Vector2i = args["hex"]
		game.improvement.build_on(hex, int(args["family"]))
		_changed(game, hex)
	return verdict


static func upgrade_check(game: Game, args: Dictionary) -> Dictionary:
	var home := _hex_and_home(game, args)
	if not bool(home["ok"]):
		return home
	return game.improvement.upgrade_check(args["hex"] as Vector2i)


static func upgrade(game: Game, args: Dictionary) -> Dictionary:
	var verdict := upgrade_check(game, args)
	if bool(verdict["ok"]):
		var hex: Vector2i = args["hex"]
		game.improvement.upgrade(hex)
		_changed(game, hex)
	return verdict


static func clear_check(game: Game, args: Dictionary) -> Dictionary:
	var home := _hex_and_home(game, args)
	if not bool(home["ok"]):
		return home
	return game.improvement.clear_check(args["hex"] as Vector2i)


static func clear(game: Game, args: Dictionary) -> Dictionary:
	var verdict := clear_check(game, args)
	if bool(verdict["ok"]):
		var hex: Vector2i = args["hex"]
		game.improvement.clear(hex)
		_changed(game, hex)
	return verdict


static func _changed(game: Game, hex: Vector2i) -> void:
	game.events.append({"kind": "hex_changed", "hex": hex})
