## A country's land summed up for the season's phases (docs/architecture/m4-build-spec.md 8 and 10; task N4): its upkeep and
## walls, the wild land counted by cover and climate (every wild hex of one cover and climate gives the same loads, so a count
## stands for them all, exactly), and the hexes that stand for something (a district, a settlement, a castle) one by one,
## with their `raw` output. Built from the game's DistrictCache in one pass over the country's hexes, kept in the game's view
## cache until an owner, a use or a level changes (the key is their hashes, so a direct edit in a test makes the next call
## build it again). That part holds no people (M5 spec 5.0 R1): `live` adds them, the towns' and the countryside's people
## and each row's a0 after staffing, kept by the people's hash too (a season builds it once for production and income,
## once more for stats after the people phase). Read by `production`, `income` and `stats` in place of a pass over every
## hex. The answers equal EconomySeason's per-hex passes to the unit; test_season_profile checks it.
class_name SeasonProfile
extends RefCounted

@warning_ignore_start("integer_division")

## The ints a special hex keeps in `rows`: family, good, raw, weather_bound, wild_good, cover, keep, port_level, climate, hex
## index, lift.
const ROW := 11
const CLIMATES := 3
## The key of `table`'s dictionary under which the live part is kept (an int no country id equals).
const LIVE := -1


## Every country's profile held so far, id -> profile: a dictionary that fills as profiles are asked for and is dropped
## when an owner, a use or a level changes. Fetch it once a phase and pass it to `of`.
static func table(game: Game) -> Dictionary:
	var key: Array = [hash(game.state.owner), hash(game.state.main_use), hash(game.state.level), game.map.hex_count(),
		game.defs.get_instance_id(), hash(game.state.occupier), EconomySeason.sieges_key(game), EconomySeason.wars_key(game)]
	var held := game.view_cache.pinned(&"season_profiles", key, func() -> Dictionary: return {}) as Dictionary
	# The live part follows the people: a new table of it when their hash is not the one it was made with.
	var people := hash(game.state.people)
	var live_held: Dictionary = held.get(LIVE, {})
	if live_held.is_empty() or int(live_held["people"]) != people:
		held[LIVE] = {"people": people, "by_id": {}}
	return held


## The profile of country `id` in `held` (table's result), built when it is not there yet.
static func of(game: Game, held: Dictionary, id: int) -> Dictionary:
	if not held.has(id):
		held[id] = _build(game, id)
	return held[id]


## The people-dependent part of country `id`'s profile on the game's own people: {town, rest (the people of its settlement
## hexes and of the rest of its land), a0 (PackedInt32Array, one for each row of the profile: the row's raw after staffing
## and lift, Economy.staffed), ready (a0 is filled)}. Kept in `held` until the people's hash changes (table sees it). The
## totals come at once (the stats phase reads only those); the a0 of the rows are filled by the first `made` that needs
## them (production, next season), which is where the staffing is worked out: a stats phase after the people phase does not
## pay for it.
static func live(game: Game, held: Dictionary, id: int) -> Dictionary:
	var kept: Dictionary = held.get(LIVE, {})
	if kept.is_empty():
		kept = {"people": hash(game.state.people), "by_id": {}}
		held[LIVE] = kept
	var by_id: Dictionary = kept["by_id"]
	if not by_id.has(id):
		by_id[id] = _live_of(game, of(game, held, id), id)
	return by_id[id]


## What the land makes in one season, in the shape of EconomySeason.made_of: {made, dues, upkeep, upkeep_count, walls}.
## `live_part` is the live part of the same country (see live).
static func made(game: Game, profile: Dictionary, live_part: Dictionary, season: int, weather: PackedByteArray, tax: int) -> Dictionary:
	var defs := game.defs
	var made_loads := PackedInt32Array()
	made_loads.resize(defs.goods.size())
	var dues_list: Array[Dictionary] = []
	var settle := defs.family(Economy.SETTLEMENTS)
	var wild: PackedInt32Array = profile["wild"]
	var wild_good: PackedInt32Array = profile["wild_good"]
	var scratch := PackedInt32Array()
	scratch.resize(defs.goods.size())
	for cover: int in wild_good.size():
		var good := wild_good[cover]
		if good < 0 or good >= made_loads.size():
			continue
		for climate: int in CLIMATES:
			var n := wild[cover * CLIMATES + climate]
			if n == 0:
				continue
			scratch[good] = 0
			var w := int(weather[climate]) if climate < weather.size() else Economy.CALM
			Economy.accumulate(null, settle, -1, 0, false, good, cover, 100, 0, Economy.slot_for(climate, season), w, tax,
				defs, scratch)
			made_loads[good] += scratch[good] * n
	var rows: PackedInt32Array = profile["rows"]
	var a0s := a0_of(game, profile, live_part)
	var fams: Array[FamilyDef] = []
	for id: int in FamilyIds.COUNT:
		fams.append(defs.family(id))
	var map := game.map
	for o: int in range(0, rows.size(), ROW):
		var climate := rows[o + 8]
		var w := int(weather[climate]) if climate < weather.size() else Economy.CALM
		var dues := Economy.accumulate(fams[rows[o]], settle, rows[o + 1], a0s[o / ROW], rows[o + 3] != 0, rows[o + 4],
			rows[o + 5], rows[o + 6], rows[o + 7], Economy.slot_for(climate, season), w, tax, defs, made_loads)
		if dues > 0:
			dues_list.append({"hex": map.hex_of(rows[o + 9]), "amount": dues})
	# The land held for an occupier (4.10): its goods and dues per hex, the hex's own district_output, at the output permille.
	var share := EconomySeason.occupied_permille(game, &"output")
	var state_view := StateView.of(game.state)
	for i: int in profile["half"]:
		var climate := int(map.climate[i])
		var w := int(weather[climate]) if climate < weather.size() else Economy.CALM
		var got := Economy.district_output(game, state_view, map.hex_of(i), season, w)
		var goods: PackedInt32Array = got["goods"]
		for g: int in made_loads.size():
			made_loads[g] += goods[g] * share / 1000
		var amount := int(got["ducats"]) * share / 1000
		if amount > 0:
			dues_list.append({"hex": map.hex_of(i), "amount": amount})
	var walls: Array[Dictionary] = []
	for wall: Dictionary in profile["walls"]:
		walls.append(wall.duplicate())
	return {"made": made_loads, "dues": dues_list, "upkeep": profile["upkeep"], "upkeep_count": profile["upkeep_count"],
		"walls": walls}


## The a0 of each row of `profile` on the people of `live_part` (filled once, on first use, into the dictionary itself).
static func a0_of(game: Game, profile: Dictionary, live_part: Dictionary) -> PackedInt32Array:
	if bool(live_part["ready"]):
		return live_part["a0"]
	var rows: PackedInt32Array = profile["rows"]
	var cache := game.districts
	var a0s := PackedInt32Array()
	a0s.resize(rows.size() / ROW)
	for o: int in range(0, rows.size(), ROW):
		if rows[o + 2] > 0:
			a0s[o / ROW] = cache.staffed_of(game, rows[o + 9], rows[o + 2], rows[o + 10]).y
	live_part["a0"] = a0s
	live_part["ready"] = true
	return a0s


static func _live_of(game: Game, profile: Dictionary, id: int) -> Dictionary:
	# The people by the war rules (4.10), the one count EconomySeason keeps: full for the needs, weighted for the tax.
	var counts := EconomySeason.counts_of(game, StateView.of(game.state), id)
	return {"town": counts["town"], "rest": counts["rest"], "town_tax": counts["town_tax"], "rest_tax": counts["rest_tax"],
		"a0": PackedInt32Array(), "ready": false}


static func _build(game: Game, id: int) -> Dictionary:
	var map := game.map
	var defs := game.defs
	var cache := game.districts
	var covers := defs.wild_yield.size() / FamilyDef.SLOTS
	var wild := PackedInt32Array()
	wild.resize(covers * CLIMATES)
	var wild_good := PackedInt32Array()
	wild_good.resize(covers)
	wild_good.fill(-1)
	var rows := PackedInt32Array()
	var walls: Array[Dictionary] = []
	var upkeep := 0
	var upkeep_count := 0
	# The land the country controls (4.4): its own unoccupied land, the land it holds for an occupier's sake (`half`, at the
	# occupier's output and tax permille, nothing paid as upkeep), and no besieged hex (its output, upkeep and people are nothing).
	var besieged := EconomySeason.besieged_set(game)
	var half := PackedInt32Array()
	for i: int in Occupation.controlled(game, id):
		if besieged.has(i):
			continue
		if int(game.state.owner[i]) != id:
			half.append(i)
			continue
		var ints := cache.ints_of(game, i)
		var o := i * DistrictCache.FIELDS
		var family := ints[o + Economy.F_FAMILY]
		var cover := ints[o + Economy.F_COVER]
		var climate := int(map.climate[i])
		if family == 0 and cover >= 0 and cover < covers and climate >= 0 and climate < CLIMATES:
			wild[cover * CLIMATES + climate] += 1
			wild_good[cover] = ints[o + Economy.F_WILD_GOOD]
			continue
		rows.append(family)
		rows.append(ints[o + Economy.F_GOOD])
		rows.append(ints[o + Economy.F_RAW])
		rows.append(ints[o + Economy.F_BOUND])
		rows.append(ints[o + Economy.F_WILD_GOOD])
		rows.append(cover)
		rows.append(ints[o + Economy.F_KEEP])
		rows.append(ints[o + Economy.F_PORT])
		rows.append(climate)
		rows.append(i)
		rows.append(ints[o + Economy.F_LIFT])
		var up := ints[o + Economy.F_UPKEEP]
		if up > 0:
			upkeep += up
			upkeep_count += 1
		var wall := ints[o + Economy.F_WALLS]
		if wall > 0:
			walls.append({"hex": map.hex_of(i), "amount": wall})
	return {"upkeep": upkeep, "upkeep_count": upkeep_count, "walls": walls, "wild": wild,
		"wild_good": wild_good, "rows": rows, "half": half, "besieged": besieged}
