## A country's land summed up for the season's phases (docs/architecture/m4-build-spec.md 8 and 10; task N4): the people of
## its towns and countryside, its upkeep and walls, the wild land counted by cover and climate (every wild hex of one cover
## and climate gives the same loads, so a count stands for them all, exactly), and the hexes that stand for something
## (a district, a settlement, a castle) one by one. Built from the game's DistrictCache in one pass over the country's hexes,
## kept in the game's view cache until an owner, a use or a level changes (the key is their hashes, so a direct edit in a
## test makes the next call build it again), and read by `production`, `income` and `stats` in place of a pass over every hex.
## The answers equal EconomySeason's per-hex passes to the unit; test_season_profile checks it.
class_name SeasonProfile
extends RefCounted

@warning_ignore_start("integer_division")

## The ints a special hex keeps in `rows`: family, good, a0, weather_bound, wild_good, cover, keep, port_level, climate, hex index.
const ROW := 10
## The place of `room` (the hex's people) among DistrictCache's ints; test_season_profile pins it to Economy.BASE_FIELDS.
const F_ROOM := 12
const CLIMATES := 3


## Every country's profile held so far, id -> profile: a dictionary that fills as profiles are asked for and is dropped
## when an owner, a use or a level changes. Fetch it once a phase and pass it to `of`.
static func table(game: Game) -> Dictionary:
	var key: Array = [hash(game.state.owner), hash(game.state.main_use), hash(game.state.level), game.map.hex_count(),
		game.defs.get_instance_id()]
	return game.view_cache.pinned(&"season_profiles", key, func() -> Dictionary: return {}) as Dictionary


## The profile of country `id` in `held` (table's result), built when it is not there yet.
static func of(game: Game, held: Dictionary, id: int) -> Dictionary:
	if not held.has(id):
		held[id] = _build(game, id)
	return held[id]


## What the land makes in one season, in the shape of EconomySeason.made_of: {made, dues, upkeep, upkeep_count, walls}.
static func made(game: Game, profile: Dictionary, season: int, weather: PackedByteArray, tax: int) -> Dictionary:
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
	var fams: Array[FamilyDef] = []
	for id: int in FamilyIds.COUNT:
		fams.append(defs.family(id))
	var map := game.map
	for o: int in range(0, rows.size(), ROW):
		var climate := rows[o + 8]
		var w := int(weather[climate]) if climate < weather.size() else Economy.CALM
		var dues := Economy.accumulate(fams[rows[o]], settle, rows[o + 1], rows[o + 2], rows[o + 3] != 0, rows[o + 4],
			rows[o + 5], rows[o + 6], rows[o + 7], Economy.slot_for(climate, season), w, tax, defs, made_loads)
		if dues > 0:
			dues_list.append({"hex": map.hex_of(rows[o + 9]), "amount": dues})
	var walls: Array[Dictionary] = []
	for wall: Dictionary in profile["walls"]:
		walls.append(wall.duplicate())
	return {"made": made_loads, "dues": dues_list, "upkeep": profile["upkeep"], "upkeep_count": profile["upkeep_count"],
		"walls": walls}


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
	var town := 0
	var rest := 0
	var upkeep := 0
	var upkeep_count := 0
	for i: int in Territory.districts(game, id):
		var ints := cache.ints_of(game, i)
		var o := i * DistrictCache.FIELDS
		var family := ints[o + Economy.F_FAMILY]
		var room := ints[o + F_ROOM]
		if family == Economy.SETTLEMENTS:
			town += room
		else:
			rest += room
		var cover := ints[o + Economy.F_COVER]
		var climate := int(map.climate[i])
		if family == 0 and cover >= 0 and cover < covers and climate >= 0 and climate < CLIMATES:
			wild[cover * CLIMATES + climate] += 1
			wild_good[cover] = ints[o + Economy.F_WILD_GOOD]
			continue
		rows.append(family)
		rows.append(ints[o + Economy.F_GOOD])
		rows.append(ints[o + Economy.F_A0])
		rows.append(ints[o + Economy.F_BOUND])
		rows.append(ints[o + Economy.F_WILD_GOOD])
		rows.append(cover)
		rows.append(ints[o + Economy.F_KEEP])
		rows.append(ints[o + Economy.F_PORT])
		rows.append(climate)
		rows.append(i)
		var up := ints[o + Economy.F_UPKEEP]
		if up > 0:
			upkeep += up
			upkeep_count += 1
		var wall := ints[o + Economy.F_WALLS]
		if wall > 0:
			walls.append({"hex": map.hex_of(i), "amount": wall})
	return {"town": town, "rest": rest, "upkeep": upkeep, "upkeep_count": upkeep_count, "walls": walls, "wild": wild,
		"wild_good": wild_good, "rows": rows}
