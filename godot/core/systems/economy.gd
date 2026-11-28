## The pure rules of one hex and the prices (docs/architecture/m4-build-spec.md 4.3 to 4.5 and 5.3): who lives on a hex,
## how many hands it has, how well its district is staffed, what the ring of six lends it, and what it gives in a season.
## Writes nothing. Every amount is an int; every division has non-negative operands (5.0 R4), or goes through floor_div.
class_name Economy
extends RefCounted

@warning_ignore_start("integer_division")

const OWNS: Array[String] = []
## The weather of a climate in a season: calm, good, poor (4.6).
const CALM := 0
const GOOD := 1
const POOR := 2
const NO_MARKET := -1
## The goods ids that rules name (spec 4.2; ids are append-only).
const GRAIN := 0
const FISH := 1
## The settlements family id (FamilyIds).
const SETTLEMENTS := 1
## The people-free ints of district_base, in the order DistrictCache keeps them; "weather_bound" is a bool, the rest
## ints. `raw` is the base times the extra, in thousandths, before staffing and lift. district_base adds the live part:
## people, staffing and a0 (5.0 R1 of the M5 spec).
const BASE_FIELDS: Array[String] = [
	"family", "level", "good", "raw", "keep", "cover", "wild_good", "weather_bound", "port_level", "upkeep", "walls",
	"jobs", "room", "lift",
]


## The index of each field of BASE_FIELDS (DistrictCache keeps them in this order).
const F_FAMILY := 0
const F_GOOD := 2
const F_RAW := 3
const F_KEEP := 4
const F_COVER := 5
const F_WILD_GOOD := 6
const F_BOUND := 7
const F_PORT := 8
const F_UPKEEP := 9
const F_WALLS := 10
const F_JOBS := 11
const F_ROOM := 12
const F_LIFT := 13


## Floor division for a signed quotient (a later milestone's); b must be positive.
static func floor_div(a: int, b: int) -> int:
	var q := a / b
	if a % b != 0 and (a < 0) != (b < 0):
		q -= 1
	return q


## 0 to 2 for spring, summer and autumn; in winter 3 + the climate of the hex (3 snow, 4 frost, 5 mild).
static func slot_for(climate: int, season: int) -> int:
	return season if season < 3 else 3 + clampi(climate, 0, 2)


static func slot_of(map: MapData, hex: Vector2i, season: int) -> int:
	var i := map.index_of(hex)
	return slot_for(int(map.climate[i]) if i >= 0 else 0, season)


## People living on a hex: the view's own number, else MapState.people (M5 spec 4.7); the sea none.
static func people_at(game: Game, view: StateView, hex: Vector2i) -> int:
	var i := game.map.index_of(hex)
	return people_i(game.map, view, i)


## Hands of a hex (4.7): the people of the hex and of the six neighbours held by the hex's owner, times hands_permille;
## on unowned land the hex alone.
static func hands_at(game: Game, view: StateView, hex: Vector2i) -> int:
	var i := game.map.index_of(hex)
	if i < 0:
		return 0
	return _hands_i(game, view, i, ring_of(game.map, i))


## The jobs of the goods districts on the hex and the six neighbours held by the hex's owner (4.5, 4.7).
static func jobs_near(game: Game, view: StateView, hex: Vector2i) -> int:
	var i := game.map.index_of(hex)
	if i < 0:
		return 0
	return _jobs_near_i(game, view, i, ring_of(game.map, i))


## Permille of its jobs a goods district can staff (4.5); 1,000 for a hex that is not a goods district.
static func staffing(game: Game, view: StateView, hex: Vector2i) -> int:
	var i := game.map.index_of(hex)
	if i < 0 or not _is_goods(game.defs.family(view.main_use_at(i)), view.level_at(i)):
		return 1000
	return _staffing_i(game, view, i, ring_of(game.map, i))


## Permille the settlements among the six neighbours lend (4.5): the largest ring_lift, whoever owns them.
static func lift_at(game: Game, view: StateView, hex: Vector2i) -> int:
	var i := game.map.index_of(hex)
	if i < 0:
		return 0
	return _lift_i(game, view, ring_of(game.map, i), game.defs.family(SETTLEMENTS))


## The district's good id, -1 for none (a wild hex, a settlement, a castle).
static func good_of(game: Game, view: StateView, hex: Vector2i) -> int:
	var i := game.map.index_of(hex)
	if i < 0 or game.map.land[i] == 0:
		return -1
	return int(district_base(game, view, hex)["good"])


## The season-free part of a hex's output (4.4): {family, level, good, raw (the base times the extra, thousandths of a load
## a season at 100 %), keep, cover, wild_good, weather_bound, port_level (0 none), upkeep, walls, jobs, room (the most
## people the hex holds, People.room_at), lift} and the live part from the view's people: {people, staffing, a0 (raw after
## staffing and lift)}. A sea hex gives all zeros (good and wild_good -1). DistrictCache keeps the first fourteen.
static func district_base(game: Game, view: StateView, hex: Vector2i) -> Dictionary:
	var map := game.map
	var defs := game.defs
	var out := empty_base()
	var i := map.index_of(hex)
	if i < 0:
		return out
	out["cover"] = int(map.cover[i])
	if map.land[i] == 0:
		return out
	var f := view.main_use_at(i)
	var level := view.level_at(i)
	var fam: FamilyDef = defs.family(f) if f > 0 and level >= 1 else null
	var cover := int(map.cover[i])
	if cover < defs.wild_good.size() and defs.wild_good[cover] != &"":
		out["wild_good"] = defs.good_id(defs.wild_good[cover])
	out["keep"] = 100
	out["room"] = People.room_at(game, view, hex)
	out["people"] = view.people_at(i)
	if fam == null:
		return out
	out["family"] = f
	out["level"] = level
	out["keep"] = _at(fam.keep_wild, level, 100)
	out["upkeep"] = _at(fam.upkeep, level, 0)
	if f == SETTLEMENTS:  # a barracks is paid with the settlement's own upkeep
		out["upkeep"] = int(out["upkeep"]) + Recruiting.upkeep_at(defs, view, i)
	out["walls"] = _at(fam.walls, level, 0)
	var place := Improve.place_of(map, hex)
	if f == SETTLEMENTS and bool(place.get("port", false)) and int(place.get("level", 0)) >= 1 \
			and map.coast_mask(hex) != 0:
		out["port_level"] = level
	if _is_goods(fam, level):
		_goods_base(game, view, hex, i, fam, out)
		live_into(game, view, i, out)
	return out


## The live part of a base `out` (its family, level, raw and lift filled): people from the view, then staffing and a0 for
## a goods district (R1: Economy.staffed is the one staffing step). Other hexes keep staffing 1,000 and a0 0.
static func live_into(game: Game, view: StateView, i: int, out: Dictionary) -> void:
	out["people"] = view.people_at(i)
	var family := int(out["family"])
	var level := int(out["level"])
	var fam: FamilyDef = game.defs.family(family) if family > 0 and level >= 1 else null
	if not _is_goods(fam, level):
		out["staffing"] = 1000
		out["a0"] = 0
		return
	var live := staffed(game, view, i, int(out["raw"]), int(out["lift"]))
	out["staffing"] = live.x
	out["a0"] = live.y


## The one live staffing step (5.0 R1): x the staffing permille of hex index `i` (its owner's hands over the owner's jobs
## near it, at most 1,000), y the a0 of `raw`: raw x staffing / 1000 x (1000 + lift) / 1000, floored in that order.
static func staffed(game: Game, view: StateView, i: int, raw: int, lift: int) -> Vector2i:
	var permille := _staffing_i(game, view, i, ring_of(game.map, i))
	return Vector2i(permille, raw * permille / 1000 * (1000 + lift) / 1000)


## The base of a hex that gives nothing: every int 0, the goods -1.
static func empty_base() -> Dictionary:
	var out: Dictionary = {}
	for key: String in BASE_FIELDS:
		out[key] = 0
	out["good"] = -1
	out["wild_good"] = -1
	out["weather_bound"] = false
	out["staffing"] = 1000
	out["people"] = 0
	out["a0"] = 0
	out["keep"] = 100
	return out


## A goods district's good, raw, jobs and lift (4.4, 4.5) into `out`; live_into adds its staffing and a0.
static func _goods_base(game: Game, view: StateView, hex: Vector2i, i: int, fam: FamilyDef, out: Dictionary) -> void:
	var level := int(out["level"])
	var permille := 1000
	if fam.good != &"":
		out["good"] = game.defs.good_id(fam.good)
	else:
		var extra := str(Improve.piece_for(game.map, hex, fam.id, level).get("extra", "-"))
		if fam.by_extra.has(extra):
			out["good"] = game.defs.good_id(fam.by_extra[extra])
			permille = int(fam.extra_permille.get(extra, 1000))
	out["weather_bound"] = fam.weather_bound
	out["jobs"] = _at(fam.jobs, level, 0)
	out["lift"] = _lift_i(game, view, ring_of(game.map, i), game.defs.family(SETTLEMENTS))
	out["raw"] = _at(fam.base, level, 0) * permille


## What a base gives in one slot of the year (the slot's percent, the tax's output, the weather) added into `into` (the
## goods by id, in place) and returned as {ducats (port dues), upkeep, walls}. The shared step of district_output and of
## EconomySeason.made_of (5.0 A7): it makes no array.
static func add_output(base: Dictionary, slot: int, weather: int, tax: int, defs: GameDefs, into: PackedInt32Array) -> Dictionary:
	var dues := accumulate(
		defs.family(int(base["family"])), defs.family(SETTLEMENTS), int(base["good"]), int(base["a0"]),
		bool(base["weather_bound"]), int(base["wild_good"]), int(base["cover"]), int(base["keep"]),
		int(base["port_level"]), slot, weather, tax, defs, into)
	return {"ducats": dues, "upkeep": int(base["upkeep"]), "walls": int(base["walls"])}


## The arithmetic under add_output on plain ints (DistrictCache's fields go straight in): the district's good, the wild
## yield and the port's fish into `into`, returning the port dues. Every index is checked against `into`, so a defs with
## fewer goods, a missing family or a short array gives less and never an error.
static func accumulate(fam: FamilyDef, settle: FamilyDef, good: int, a0: int, bound: bool, wild_good: int, cover: int,
		keep: int, port_level: int, slot: int, weather: int, tax: int, defs: GameDefs, into: PackedInt32Array) -> int:
	var t := clampi(tax, 0, 2)
	var w := clampi(weather, 0, 2)
	var count := into.size()
	if good >= 0 and good < count and a0 > 0 and fam != null and slot < fam.season_percent.size():
		var a: int = a0 * fam.season_percent[slot] / 100
		a = a * defs.output_permille[t] / 1000
		if bound:
			a = a * defs.weather_permille[w] / 1000
		into[good] += a / 1000
	if wild_good >= 0 and wild_good < count:
		into[wild_good] += _wild(wild_good, cover, keep, slot, w, defs)
	var dues := 0
	if port_level > 0 and settle != null and port_level < settle.port_fish.size():
		if FISH < count and slot < defs.fishing_percent.size():
			var fish: int = settle.port_fish[port_level] * 1000 * defs.fishing_percent[slot] / 100
			into[FISH] += fish * defs.output_permille[t] / 1000 / 1000
		if slot < defs.port_dues_percent.size():
			dues = settle.port_dues[port_level] * defs.port_dues_percent[slot] / 100
	return dues


## The loads of its cover's good a hex's wild land gives in a slot (4.4), the weather only on grain; 0 for none.
static func wild_loads(base: Dictionary, slot: int, weather: int, defs: GameDefs) -> int:
	var wild_good := int(base["wild_good"])
	if wild_good < 0:
		return 0
	return _wild(wild_good, int(base["cover"]), int(base["keep"]), slot, weather, defs)


static func _wild(wild_good: int, cover: int, keep: int, slot: int, weather: int, defs: GameDefs) -> int:
	var at := cover * FamilyDef.SLOTS + slot
	if at >= defs.wild_yield.size():
		return 0
	var n: int = defs.wild_yield[at] * 1000 * keep / 100
	if wild_good == GRAIN:
		n = n * defs.weather_permille[clampi(weather, 0, 2)] / 1000
	return n / 1000


## A base turned into the loads of one season: {goods: PackedInt32Array (a load count per good id), ducats, upkeep,
## walls}.
static func season_output(base: Dictionary, map_climate: int, season: int, weather: int, tax: int, defs: GameDefs) -> Dictionary:
	var goods := PackedInt32Array()
	goods.resize(defs.goods.size())
	var rest := add_output(base, slot_for(map_climate, season), weather, tax, defs, goods)
	return {"goods": goods, "ducats": rest["ducats"], "upkeep": rest["upkeep"], "walls": rest["walls"]}


## The one function of 4.4: season_output of district_base, merged with the base's facts: {goods, ducats, upkeep, walls,
## jobs, room, staffing, lift, good, wild}. A tax of -1 is the owner's level (Normal on unowned land).
static func district_output(game: Game, view: StateView, hex: Vector2i, season: int, weather: int = CALM, tax: int = -1) -> Dictionary:
	var base := district_base(game, view, hex)
	var i := game.map.index_of(hex)
	var climate := int(game.map.climate[i]) if i >= 0 else 0
	var level := tax if tax >= 0 else _owner_tax(game, i)
	var out := season_output(base, climate, season, weather, level, game.defs)
	for key: String in ["jobs", "room", "staffing", "lift", "good"]:
		out[key] = base[key]
	out["wild"] = wild_loads(base, slot_for(climate, season), weather, game.defs)
	return out


## The country's id, the market it trades in (M4: one a country); NO_MARKET for no tag.
static func market_of(game: Game, tag: StringName) -> int:
	var c := Countries.by_tag(game, tag)
	return c.id if c != null else NO_MARKET


## Whole thousandths of a ducat per good id. M4: GoodDef.price_milli, reading neither the market nor the supply (the seam
## M10 fills).
static func market_prices(game: Game, _view: StateView, _market: int, _supply: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for g: GoodDef in game.defs.goods:
		out.append(g.price_milli)
	return out


# --- internals, by hex index ---------------------------------------------------------------------------------------

static func _at(values: PackedInt32Array, level: int, fallback: int) -> int:
	return values[level] if level >= 0 and level < values.size() else fallback


## A family that makes goods: a good or extras, and a level of 1 or more.
static func _is_goods(fam: FamilyDef, level: int) -> bool:
	return fam != null and level >= 1 and (fam.good != &"" or not fam.by_extra.is_empty())


static func _owner_tax(game: Game, i: int) -> int:
	if i < 0 or i >= game.state.owner.size() or game.state.owner[i] == 0:
		return 1
	var c := Countries.by_id(game, game.state.owner[i])
	return c.tax if c != null else 1


## The six neighbours' indices in direction order (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE), -1 off the map: arithmetic on the
## index, the odd rows shifted half a hex right as MapData.neighbour (test_economy checks the two agree on every hex).
static func ring_of(map: MapData, i: int) -> PackedInt32Array:
	var cols := map.cols
	var x := i % cols
	var y := i / cols
	var odd := (y & 1) == 1
	var west := x > 0
	var east := x + 1 < cols
	var up := y > 0
	var down := y + 1 < map.rows
	var out := PackedInt32Array()
	out.resize(6)
	out[0] = i + 1 if east else -1
	if up:
		out[1] = (i - cols + 1 if east else -1) if odd else i - cols
		out[2] = i - cols if odd else (i - cols - 1 if west else -1)
	else:
		out[1] = -1
		out[2] = -1
	out[3] = i - 1 if west else -1
	if down:
		out[4] = i + cols if odd else (i + cols - 1 if west else -1)
		out[5] = (i + cols + 1 if east else -1) if odd else i + cols
	else:
		out[4] = -1
		out[5] = -1
	return out


## The people of hex index `i` on the view: 0 off the map and at sea.
static func people_i(map: MapData, view: StateView, i: int) -> int:
	if i < 0 or map.land[i] == 0:
		return 0
	return view.people_at(i)


static func _hands_i(game: Game, view: StateView, i: int, ring: PackedInt32Array) -> int:
	return _hands_and_jobs(game, view, i, ring).x * game.defs.hands_permille / 1000


## The jobs of the goods district on hex index `i` (0 for anything else, the sea and off the map).
static func jobs_i(game: Game, view: StateView, i: int) -> int:
	if i < 0:
		return 0
	var use := view.main_use_at(i)
	if use == 0 or game.map.land[i] == 0:
		return 0
	var level := view.level_at(i)
	var fam := _family(game.defs, use)
	return _at(fam.jobs, level, 0) if _is_goods(fam, level) else 0


## The family of an id: the entry `id - 1` of the definitions when it is the one (they are listed by id), else a search.
static func _family(defs: GameDefs, id: int) -> FamilyDef:
	var at := id - 1
	if at >= 0 and at < defs.families.size():
		var fam := defs.families[at]
		if fam != null and fam.id == id:
			return fam
	return defs.family(id)


static func _jobs_near_i(game: Game, view: StateView, i: int, ring: PackedInt32Array) -> int:
	return _hands_and_jobs(game, view, i, ring).y


## x the people and y the jobs of hex index `i` and the neighbours of `ring` that its owner holds (4.7): on unowned land (or
## in a map-only game) the hex alone. One pass, as the people and the jobs count the same hexes.
static func _hands_and_jobs(game: Game, view: StateView, i: int, ring: PackedInt32Array) -> Vector2i:
	var owner_bytes := view.state.owner
	var owner_id := int(owner_bytes[i])
	var map := game.map
	var people := people_i(map, view, i)
	var jobs := jobs_i(game, view, i)
	if owner_id != 0:
		for j: int in ring:
			if j >= 0 and owner_bytes[j] == owner_id:
				people += people_i(map, view, j)
				jobs += jobs_i(game, view, j)
	return Vector2i(people, jobs)


static func _staffing_i(game: Game, view: StateView, i: int, ring: PackedInt32Array) -> int:
	var both := _hands_and_jobs(game, view, i, ring)
	if both.y == 0:
		return 1000
	return mini(1000, both.x * game.defs.hands_permille / 1000 * 1000 / both.y)


static func _lift_i(game: Game, view: StateView, ring: PackedInt32Array, settle: FamilyDef) -> int:
	var best := 0
	for j: int in ring:
		if j >= 0 and game.map.land[j] == 1 and view.main_use_at(j) == SETTLEMENTS and settle != null:
			best = maxi(best, _at(settle.ring_lift, view.level_at(j), 0))
	return best
