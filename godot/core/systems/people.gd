## The people rules (docs/architecture/m5-build-spec.md 4.1 to 4.5, 4.20, 5.0 and 5.3): where people live (their start and
## their room), the one door that changes them (`move`), what a season does to one hex (`change_at`: growth, hunger,
## crowding), when a settlement grows or falls a level (`grow_check`, `decline_check`), the people phase (`season`), the
## season's close (`close`) and the seam M6's recruits use (`available`, `levy_check`, `levy`, `give_back`). The rules take
## a StateView so the phase (on the game's own state) and the preview (on its what-if view) run the same functions.
## Integer maths with non-negative operands; no luck, no engine calls.
class_name People
extends RefCounted

@warning_ignore_start("integer_division")

const OWNS: Array[String] = ["people", "people_start", "people_end", "people_flows", "people_closed", "food_need",
	"food_fed"]
## The reasons people change, append-only. The index is the flow in Country.people_flows.
const FLOWS: Array[StringName] = [&"grew", &"starved", &"left", &"raised", &"returned", &"dev", &"foraged"]
const GREW := 0
const STARVED := 1
const LEFT := 2
const NO_HEX := Vector2i(-1, -1)
## A hex holds at most this many people: it keeps the int32 arrays and the country sums safe (A2).
const PEOPLE_MAX := 1000000
## The settlements family id.
const SETTLEMENTS := Economy.SETTLEMENTS

## The twelve offsets of the hexes two away, by row parity, row-major (the order WorldImprove walks them in).
static var _ring2: Array = []


# --- where people live -----------------------------------------------------------------------------------------------


## The people a hex starts with (4.2, M4's table): a settlement its level's, other land its cover's countryside; 0 at sea,
## off the map and without definitions.
static func start_people(game: Game, hex: Vector2i) -> int:
	var i := game.map.index_of(hex)
	if i < 0 or game.defs == null or game.map.land[i] == 0:
		return 0
	return _start_i(game, i)


static func _start_i(game: Game, i: int) -> int:
	var defs := game.defs
	if int(game.state.main_use[i]) == SETTLEMENTS:
		var fam := defs.family(SETTLEMENTS)
		return _at(fam.people, int(game.state.level[i]), 0) if fam != null else 0
	return _at(defs.country_people, int(game.map.cover[i]), 0)


## The most people a hex holds on the view (4.2): a settlement its level's room; other land its cover's countryside
## people plus the jobs of the district on it (a castle none); 0 at sea and off the map.
static func room_at(game: Game, view: StateView, hex: Vector2i) -> int:
	var i := game.map.index_of(hex)
	if i < 0 or game.defs == null or game.map.land[i] == 0:
		return 0
	return _room_i(game, view, i)


static func _room_i(game: Game, view: StateView, i: int) -> int:
	var defs := game.defs
	if view.main_use_at(i) == SETTLEMENTS:
		var fam := defs.family(SETTLEMENTS)
		return _at(fam.room, view.level_at(i), 0) if fam != null else 0
	return _at(defs.country_people, int(game.map.cover[i]), 0) + Economy.jobs_i(game, view, i)


## Game start: every land hex holds its start people (and so does its last season's start and end); every country's
## flows are zero. Needs the definitions; a sandbox gets its people here too and never changes them.
static func setup(game: Game) -> void:
	if game == null or game.state == null or game.map == null or game.defs == null:
		return
	var n := game.map.hex_count()
	var people := PackedInt32Array()
	people.resize(n)
	for i: int in n:
		if game.map.land[i] == 1:
			people[i] = _start_i(game, i)
	game.state.people = people
	game.state.people_start = people.duplicate()
	game.state.people_end = people.duplicate()
	game.districts.reset_open()
	for c: Country in game.countries:
		c.people_flows = PackedInt32Array()
		c.people_flows.resize(FLOWS.size())
		c.people_closed = {}
		c.food_need = 0
		c.food_fed = 1000


# --- the door --------------------------------------------------------------------------------------------------------


## THE ONLY WRITER OF PEOPLE after setup. False and nothing changes for: a hex off the map or at sea; a `why` not in
## FLOWS; a result below 0 or above PEOPLE_MAX; in a game with countries, a hex no country holds; a map-only game. An
## amount of 0 changes nothing and returns true. Else people[i] += amount and the owner's flow of `why` gains amount.
static func move(game: Game, hex: Vector2i, amount: int, why: StringName) -> bool:
	if game == null or game.map == null or game.state == null or not game.has_countries():
		return false
	var i := game.map.index_of(hex)
	var flow := FLOWS.find(why)
	if i < 0 or flow < 0 or game.map.land[i] == 0 or i >= game.state.people.size():
		return false
	var c := Countries.by_id(game, int(game.state.owner[i]))
	if c == null:
		return false
	var result := game.state.people[i] + amount
	if result < 0 or result > PEOPLE_MAX:
		return false
	if amount == 0:
		return true
	_apply(game, c, i, amount, flow)
	return true


## The write of `move`, its checks done: the people of hex index `i` and the owner's flow.
static func _apply(game: Game, c: Country, i: int, amount: int, flow: int) -> void:
	while c.people_flows.size() < FLOWS.size():
		c.people_flows.append(0)
	game.state.people[i] += amount
	c.people_flows[flow] += amount
	game.districts.note_people(game, i)


# --- food ------------------------------------------------------------------------------------------------------------


## The towns' food need of a country on the view (EconomySeason.needs_of).
static func food_need_of(game: Game, view: StateView, tag: StringName) -> int:
	return int(EconomySeason.needs_of(game, view, tag)["food"])


## How much of its need the towns ate this season, permille: min(1000, (grain used + fish used, from the open flows, as
## positive amounts) x 1000 / need); 1,000 when the need is 0 (A1).
static func fed_of(game: Game, tag: StringName, need: int) -> int:
	if need <= 0:
		return 1000
	var c := Countries.by_tag(game, tag)
	if c == null or game.defs == null:
		return 1000
	var eaten := 0
	for key: StringName in [&"grain", &"fish"]:
		var g := game.defs.good_id(key)
		if g >= 0:
			eaten += maxi(-Stores.flow(c, g, &"used"), 0)
	return mini(1000, eaten * 1000 / need)


# --- growth, hunger, crowding ----------------------------------------------------------------------------------------


## What one season does to one hex (4.4): x the signed amount, y the index in FLOWS (grew, starved or left); (0, 0) when
## nothing changes. `season` is 0 to 3, `tax` the owner's level, `fed` the towns' permille.
static func change_at(game: Game, view: StateView, hex: Vector2i, season: int, tax: int, fed: int) -> Vector2i:
	var i := game.map.index_of(hex)
	if i < 0 or game.defs == null or game.map.land[i] == 0:
		return Vector2i.ZERO
	return _change_i(game, view, i, season, tax, fed, _room_i(game, view, i))


static func _change_i(game: Game, view: StateView, i: int, season: int, tax: int, fed: int, room: int) -> Vector2i:
	var rates := _rates(game.defs, Economy.slot_for(int(game.map.climate[i]), season), tax)
	return _rule(game.defs, view.people_at(i), room, view.main_use_at(i) == SETTLEMENTS, rates, fed)


## The two rates of a slot at a tax level: x growth (basis points x the slot's percent), y the hunger (the same).
static func _rates(defs: GameDefs, slot: int, tax: int) -> Vector2i:
	return Vector2i(_at(defs.growth_bp, clampi(tax, 0, 2), 0) * _at(defs.growth_percent, slot, 0),
		defs.hunger_bp * _at(defs.hunger_percent, slot, 100))


## The arithmetic of 4.4 on plain numbers: `p` people on a hex with `room`, `settlement` or not, at the rates of its slot
## and tax (_rates), the towns `fed`. x the signed amount, y the flow; (0, 0) when nothing changes.
static func _rule(defs: GameDefs, p: int, room: int, settlement: bool, rates: Vector2i, fed: int) -> Vector2i:
	if room == 0 and p == 0:
		return Vector2i.ZERO
	if fed < 1000 and settlement:
		var loss := mini((p * rates.y * (1000 - fed) + 999999999) / 1000000000, maxi(0, p - defs.town_floor))
		return Vector2i(-loss, STARVED) if loss > 0 else Vector2i.ZERO
	if p > room:
		return Vector2i(-mini(p - room, (p * defs.left_bp + 9999) / 10000), LEFT)
	var grown := mini(p * rates.x / 1000000, room - p)
	return Vector2i(grown, GREW) if grown > 0 else Vector2i.ZERO


## The preview's doors to the rules (the phase uses the privates on its own cached numbers): the room of hex index `i` on
## the view, the two rates of a slot at a tax level, the rule of 4.4 on plain numbers, and whether the settlement of index
## `i` on the view can grow or fall at all (what the phase's walk asks before it runs the checks).
static func room_i(game: Game, view: StateView, i: int) -> int:
	return _room_i(game, view, i)


static func rates_of(defs: GameDefs, slot: int, tax: int) -> Vector2i:
	return _rates(defs, slot, tax)


static func rule_of(defs: GameDefs, p: int, room: int, settlement: bool, rates: Vector2i, fed: int) -> Vector2i:
	return _rule(defs, p, room, settlement, rates, fed)


static func can_change_level(game: Game, view: StateView, i: int) -> bool:
	var level := view.level_at(i)
	var people := view.people_at(i)
	var defs := game.defs
	if level < defs.people_top_level and people >= _room_i(game, view, i):
		return true
	if level >= 2 and level <= defs.people_top_level:
		var fam := defs.family(SETTLEMENTS)
		return fam != null and people < _at(fam.falls_below, level, 0)
	return false


## The hexes of country `id` whose people can change on the view (R2): its settlements and the hexes whose people differ
## from their room, ascending. The room comes from DistrictCache's column (the view's own room for a hex the view has
## changed).
static func active(game: Game, view: StateView, id: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if game == null or game.defs == null or game.state == null:
		return out
	if view.state == game.state and view.changed().is_empty() and view.people_changed().is_empty():
		# The game's own state: the running set, filtered to the country (index order).
		var keys := game.districts.open_hexes(game).keys()
		keys.sort()
		for i: int in keys:
			if int(game.state.owner[i]) == id and id > 0:
				out.append(i)
		return out
	# A what-if view: the country's hexes, the room of a hex the view has changed worked out on the view.
	var over: Dictionary = {}
	for i: int in view.changed():
		over[i] = true
	var cache := game.districts
	for i: int in Territory.districts(game, id):
		if view.main_use_at(i) == SETTLEMENTS:
			out.append(i)
			continue
		var room := _room_i(game, view, i) if over.has(i) else cache.ints_of(game, i)[i * DistrictCache.FIELDS + Economy.F_ROOM]
		if view.people_at(i) != room:
			out.append(i)
	return out


# --- the levels ------------------------------------------------------------------------------------------------------


## Whether the settlement on a hex of the view may grow a level by its people (4.5), the first refusal as the verdict:
## {ok, reason, rule (the index in ImproveRules.PAIR_RULES of a pair rule that forbids it, -1 for none), other (the hex of
## the piece it breaks it against, NO_HEX for none)}.
## `gone` (the preview's, 5.0 R4) is a set of works (Work -> true) to treat as finished: they no longer block (rows 3 and 7).
static func grow_check(game: Game, view: StateView, hex: Vector2i, fed: int, gone: Dictionary = {}) -> Dictionary:
	var verdict := _verdict(true, "")
	verdict["rule"] = -1
	var i := game.map.index_of(hex)
	if i < 0 or game.defs == null or game.map.land[i] == 0 or view.main_use_at(i) != SETTLEMENTS:
		return _refused(verdict, "not a settlement")
	var level := view.level_at(i)
	if level >= game.defs.people_top_level:
		return _refused(verdict, "the people raise villages and towns; walls are the crown's work")
	var under_way := game.state.work_at(hex)
	if under_way != null and not gone.has(under_way):
		return _refused(verdict, "a work is under way here")
	var room := _room_i(game, view, i)
	var people := view.people_at(i)
	if people < room:
		return _refused(verdict, "not full: %s of %s people" % [_grouped(people), _grouped(room)])
	if fed < 1000:
		return _refused(verdict, "your towns are not fed")
	var found := conflict(game, view, hex, SETTLEMENTS, level + 1)
	if not found.is_empty():
		var other: Vector2i = found["hex"]
		verdict["rule"] = int(found["rule"])
		verdict["other"] = other
		return _refused(verdict, "%s (%s %d at %d, %d)" % [ImproveRules.PAIR_RULES[int(found["rule"])][5],
			ImproveRules.NAMES[int(found["family"])], int(found["level"]), other.x, other.y])
	var pending := Works.pending_conflict(game, hex, SETTLEMENTS, level + 1, gone)
	if pending != "":
		return _refused(verdict, pending)
	return verdict


## Whether the settlement on a hex of the view falls a level (4.5): {ok, reason, other (the goods piece that needs it, NO_HEX
## for none)}.
## `gone` as in grow_check.
static func decline_check(game: Game, view: StateView, hex: Vector2i, gone: Dictionary = {}) -> Dictionary:
	var i := game.map.index_of(hex)
	if i < 0 or game.defs == null or game.map.land[i] == 0 or view.main_use_at(i) != SETTLEMENTS:
		return _verdict(false, "not a settlement")
	var level := view.level_at(i)
	if level <= 1:
		return _verdict(false, "a hamlet falls no further")
	if level > game.defs.people_top_level:
		return _verdict(false, "walls do not fall to hunger")
	var under_way := game.state.work_at(hex)
	if under_way != null and not gone.has(under_way):
		return _verdict(false, "a work is under way here")
	var fam := game.defs.family(SETTLEMENTS)
	var below := _at(fam.falls_below, level, 0) if fam != null else 0
	if view.people_at(i) >= below:
		return _verdict(false, "not under %s people" % _grouped(below))
	if level == 3:
		var need := _needed_by(game, view, hex)
		if not need.is_empty():
			var piece: Vector2i = need["hex"]
			var out := _verdict(false, "the %s at (%d, %d) needs this town" % [ImproveRules.NAMES[int(need["family"])], piece.x,
				piece.y])
			out["other"] = piece
			return out
	return _verdict(true, "")


## {} or {rule, hex, family, level}: the first pair rule the option (family, level) on `hex` breaks against the pieces of the
## view within two hexes, in the order WorldImprove's own check walks them (the six neighbours, then the twelve hexes two
## away in row order).
static func conflict(game: Game, view: StateView, hex: Vector2i, family: int, level: int) -> Dictionary:
	for d: int in 6:
		var near := ImproveRules.neighbour(hex, d)
		var found := _pair_against(game, view, near, family, level, 1)
		if not found.is_empty():
			return found
	for delta: Vector2i in _ring2_of(hex):
		var found := _pair_against(game, view, hex + delta, family, level, 2)
		if not found.is_empty():
			return found
	return {}


static func _pair_against(game: Game, view: StateView, at: Vector2i, family: int, level: int, radius: int) -> Dictionary:
	var i := game.map.index_of(at)
	if i < 0 or game.map.land[i] == 0:
		return {}
	var other := view.main_use_at(i)
	if other == ImproveRules.NONE:
		return {}
	var rule := ImproveRules.pair_rule(family, level, other, view.level_at(i), radius)
	if rule < 0:
		return {}
	return {"rule": rule, "hex": at, "family": other, "level": view.level_at(i)}


## The goods piece of the view within two hexes that this town (as a village) would leave without the town its cell rule
## needs: a stage-3 district or a silk district within two hexes of its town, a dye works within one. {} when none.
static func _needed_by(game: Game, view: StateView, hex: Vector2i) -> Dictionary:
	for d: int in 6:
		var found := _needs_town(game, view, hex, ImproveRules.neighbour(hex, d))
		if not found.is_empty():
			return found
	for delta: Vector2i in _ring2_of(hex):
		var found := _needs_town(game, view, hex, hex + delta)
		if not found.is_empty():
			return found
	return {}


static func _needs_town(game: Game, view: StateView, town: Vector2i, piece: Vector2i) -> Dictionary:
	var i := game.map.index_of(piece)
	if i < 0 or game.map.land[i] == 0:
		return {}
	var family := view.main_use_at(i)
	var level := view.level_at(i)
	if family == ImproveRules.NONE or family == ImproveRules.SETTLEMENT or family == ImproveRules.CASTLE:
		return {}
	var reach := 0
	if family == ImproveRules.DYES:
		reach = 1
	elif family == ImproveRules.SILK or level == 3:
		reach = 2
	if reach == 0 or ImproveRules.hex_distance(town, piece) > reach:
		return {}
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach - 1, reach + 2):
			var at := piece + Vector2i(dx, dy)
			if at == town or ImproveRules.hex_distance(at, piece) > reach:
				continue
			var j := game.map.index_of(at)
			if j >= 0 and game.map.land[j] == 1 and view.main_use_at(j) == SETTLEMENTS and view.level_at(j) >= 3:
				return {}
	return {"hex": piece, "family": family, "level": level}


static func _ring2_of(hex: Vector2i) -> Array:
	if _ring2.is_empty():
		for parity: int in 2:
			var origin := Vector2i(10, 10 + parity)
			var found: Array[Vector2i] = []
			for dy: int in range(-2, 3):
				for dx: int in range(-3, 4):
					var delta := Vector2i(dx, dy)
					if ImproveRules.hex_distance(origin, origin + delta) == 2:
						found.append(delta)
			_ring2.append(found)
	return _ring2[1 if (hex.y & 1) == 1 else 0]


# --- the people phase ------------------------------------------------------------------------------------------------


## The people phase (4.1, 4.4, 4.5), per living country in id order: its food need and what share of it the towns ate (the
## flows of this season), then each hex of People.active in index order through change_at and move, then each settlement
## in index order: it grows (Improve.upgrade, town_grew) or falls (Improve.lower, district_declined) when the checks say so.
## A level change earlier in the visit is seen by the later ones. Nothing in a map-only game.
## The phase writes through `_apply`, the write `move` makes once its checks are done, not through `move` itself (the spec says
## move): the phase already holds the owner, the hex index and the flow, and its steps pass the checks by construction (land,
## owned, 0 <= result <= room or the hex's own people), so the per-hex lookups would be the phase's whole cost.
static func season(game: Game) -> void:
	if game == null or not game.has_countries() or game.defs == null or game.defs.goods.is_empty():
		return
	var view := StateView.of(game.state)
	var season_of := Calendar.season_of(game.turn)
	var held := SeasonProfile.table(game)
	var walks := _open_by_owner(game)
	var open := game.districts.open_hexes(game)
	var state := game.state
	var climates := game.map.climate
	for c: Country in game.countries:
		if not c.alive or c.stock.size() != game.defs.goods.size():
			continue
		c.food_need = int(EconomySeason.needs_for(game, int(SeasonProfile.live(game, held, c.id)["town"]))["food"])
		c.food_fed = fed_of(game, c.tag, c.food_need)
		var rates: Array[Vector2i] = []
		for climate: int in 3:
			rates.append(_rates(game.defs, Economy.slot_for(climate, season_of), c.tax))
		var walk: Array = walks.get(c.id, [])
		var towns := PackedInt32Array()
		for i: int in walk:
			var settlement := state.main_use[i] == SETTLEMENTS
			var step := _rule(game.defs, state.people[i], open[i], settlement, rates[mini(climates[i], 2)], c.food_fed)
			if step.x != 0:
				_apply(game, c, i, step.x, step.y)
			if settlement:
				towns.append(i)
		for i: int in towns:
			_level_step(game, view, c, i)


## One settlement's level step: grow, else fall, with the event of the change that Improve accepted.
static func _level_step(game: Game, view: StateView, c: Country, i: int) -> void:
	var level := int(game.state.level[i])
	if not _may_change_level(game, i, level):
		return
	var hex := game.map.hex_of(i)
	if bool(grow_check(game, view, hex, c.food_fed)["ok"]):
		if bool(Improve.upgrade(game, {"hex": hex, "tag": c.tag})["ok"]):
			game.emit({"kind": "town_grew", "tag": c.tag, "hex": hex, "level": level + 1, "from": level,
				"people": game.state.people[i]})
	elif bool(decline_check(game, view, hex)["ok"]):
		if bool(Improve.lower(game, {"hex": hex, "tag": c.tag})["ok"]):
			game.emit({"kind": "district_declined", "tag": c.tag, "hex": hex, "family": SETTLEMENTS, "level": level - 1,
				"from": level, "people": game.state.people[i], "why": &"hunger" if c.food_fed < 1000 else &"people"})


## Whether the settlement of hex index `i` at `level` can grow or fall at all: grow_check needs it full and decline_check
## under its floor, so a settlement between the two (nearly all of them, nearly always) skips both checks and their walk
## over the works and the pieces round it.
static func _may_change_level(game: Game, i: int, level: int) -> bool:
	var people: int = game.state.people[i]
	var defs := game.defs
	if level < defs.people_top_level and people >= game.districts.room_of(game, i):
		return true
	if level >= 2 and level <= defs.people_top_level:
		var fam := defs.family(SETTLEMENTS)
		return fam != null and people < _at(fam.falls_below, level, 0)
	return false


## The running set grouped by country: id -> an Array of the hex indices of the set it holds, ascending.
static func _open_by_owner(game: Game) -> Dictionary:
	var keys := game.districts.open_hexes(game).keys()
	keys.sort()
	var out: Dictionary = {}
	for i: int in keys:
		var id := int(game.state.owner[i])
		if id > 0:
			if not out.has(id):
				out[id] = []
			(out[id] as Array).append(i)
	return out


## The season's close (the stats phase): every country's flows become its people_closed {turn, flows} and start again from
## zero; the people at the start of the last season are the ones at its end before, the end the people now.
static func close(game: Game) -> void:
	if game == null or game.state == null:
		return
	for c: Country in game.countries:
		c.people_closed = {"turn": game.turn, "flows": c.people_flows.duplicate()}
		c.people_flows.fill(0)
	game.state.people_start = game.state.people_end.duplicate()
	game.state.people_end = game.state.people.duplicate()


# --- the seam M6's recruits use (4.20) -------------------------------------------------------------------------------


## The men one levy may take on a hex now: its people x levy_permille / 1000, floored; 0 at sea, off the map and on
## unowned land.
static func available(game: Game, hex: Vector2i) -> int:
	if game == null or game.map == null or game.state == null or game.defs == null:
		return 0
	var i := game.map.index_of(hex)
	if i < 0 or game.map.land[i] == 0 or int(game.state.owner[i]) == 0 or i >= game.state.people.size():
		return 0
	return game.state.people[i] * game.defs.levy_permille / 1000


## {ok, reason}: "not a land hex"; M2's home rule; "no men asked"; "only N men can be raised here: ..."; else ok.
static func levy_check(game: Game, tag: StringName, hex: Vector2i, men: int) -> Dictionary:
	if game == null or game.map == null or not game.map.is_land(hex):
		return _verdict(false, "not a land hex")
	var home := Territory.at_home_check(game, tag, hex)
	if not bool(home["ok"]):
		return _verdict(false, str(home["reason"]))
	if men < 1:
		return _verdict(false, "no men asked")
	var most := available(game, hex)
	if men > most:
		return _verdict(false, "only %d men can be raised here: (%d, %d) holds %d people" % [most, hex.x, hex.y,
			game.state.people[game.map.index_of(hex)]])
	return _verdict(true, "")


## Takes `men` from the hex's people (after checking again) as the flow `raised`; returns the men taken, 0 when refused.
static func levy(game: Game, tag: StringName, hex: Vector2i, men: int) -> int:
	if not bool(levy_check(game, tag, hex, men)["ok"]):
		return 0
	return men if move(game, hex, -men, &"raised") else 0


## Disbanded men come home: the flow `returned`; over the room they leave as any crowd does. Returns the men placed (0 at
## sea, off the map, on unowned land, for fewer than 1, or when the door refuses).
static func give_back(game: Game, hex: Vector2i, men: int) -> int:
	if men < 1 or game == null or game.map == null or not game.map.is_land(hex):
		return 0
	return men if move(game, hex, men, &"returned") else 0


# --- helpers ---------------------------------------------------------------------------------------------------------


static func _verdict(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": "" if ok else reason, "other": NO_HEX}


static func _refused(verdict: Dictionary, reason: String) -> Dictionary:
	verdict["ok"] = false
	verdict["reason"] = reason
	return verdict


static func _at(values: PackedInt32Array, at: int, fallback: int) -> int:
	return values[at] if at >= 0 and at < values.size() else fallback


## 1234567 as "1,234,567".
static func _grouped(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	for k: int in digits.length():
		if k > 0 and (digits.length() - k) % 3 == 0:
			out += ","
		out += digits[k]
	return ("-" if n < 0 else "") + out
