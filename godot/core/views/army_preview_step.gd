## The armies in the economy preview (docs/architecture/m6-build-spec.md R9, D48): one country's supply phase, the losses of
## its armies, the food and upkeep they cost, and the ready_units refill, worked out season by season on a what-if view with
## the arithmetic of Supply.country_step, Armies.lose_men, Supply.army_food, Military.upkeep_of and Military.refill. The
## depots come from the view (a what-if settlement that adds a depot changes the supply field here, as it would in play).
## Pure: it reads the game and the view and writes nothing; the army copies live in a track made by `track` for one run
## (EconomyPreview.with), and the caller lays the people it moves into its run. No luck; integer maths.
class_name ArmyPreviewStep
extends RefCounted

@warning_ignore_start("integer_division")


## The country's armies as copies a run may change: {tag, armies: [{id, hex, supply, units: [{id, kind, men}]}] in id order,
## fields: the supply fields a run has made (by winter and depot list)}. Nothing here is the game's own object.
static func track(game: Game, tag: StringName) -> Dictionary:
	var list: Array[Dictionary] = []
	for a: Army in Armies.of_country(game, tag):
		var units: Array[Dictionary] = []
		for u: Unit in a.units:
			units.append({"id": u.id, "kind": u.kind, "men": u.men})
		list.append({"id": a.id, "hex": a.hex, "supply": a.supply, "units": units})
	return {"tag": tag, "armies": list, "fields": {}, "foreign": {}}


## The hex indices of the track's armies (each once, in army order).
static func hexes_of(game: Game, track_data: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for a: Dictionary in track_data["armies"]:
		var i := game.map.index_of(a["hex"])
		if i >= 0 and not out.has(i):
			out.append(i)
	return out


## `stock` less the loads the armies ate (both per good id).
static func after_eating(stock: PackedInt32Array, eaten: PackedInt32Array) -> PackedInt32Array:
	var out := stock.duplicate()
	for g: int in out.size():
		out[g] -= eaten[g]
	return out


## The supply phase of the country on `view` in the season at `turn` (Supply.country_step's arithmetic and Supply.season's
## losses): the supplied armies eat from `stock` (grain, then fish), the others forage the land under them on `view`, the
## unfed men are lost as Supply.starve_loss says, and an army left empty leaves the track. Returns {eaten: loads per good
## id, foraged: {hex index: people taken}, food: the loads the armies in supply eat in production (Supply.army_food, after
## the losses), upkeep: the income phase's upkeep_army (Military.upkeep_country), count: the armies left}.
static func supply(game: Game, view: StateView, track_data: Dictionary, stock: PackedInt32Array, turn: int) -> Dictionary:
	var fld := field(game, view, track_data, Calendar.is_winter(turn))
	var eaten := PackedInt32Array()
	eaten.resize(stock.size())
	eaten.fill(0)
	var supplied: Array[Dictionary] = []
	var land: Array[Dictionary] = []
	for a: Dictionary in track_data["armies"]:
		var i := game.map.index_of(a["hex"])
		if i >= 0 and i < fld.size() and fld[i] == 1:
			supplied.append(a)
		else:
			land.append(a)
	var states := {}
	var losses := {}
	var foraged := {}
	_eat(game, stock, supplied, eaten, turn, states, losses)
	# Land another country holds: the people the armies there forage are the preview's own estimate (the owner's people
	# step is not run here), taken from the season's start and lowered by each season's foraging.
	var foreign: Dictionary = track_data["foreign"]
	for a: Dictionary in land:
		var i := game.map.index_of(a["hex"])
		if i >= 0 and int(game.state.owner[i]) != _owner_of(game, track_data) and not foreign.has(i):
			foreign[i] = view.people_at(i)
	var fview := view.with_people(foreign) if not foreign.is_empty() else view
	_forage(game, fview, land, turn, states, losses, foraged)
	for i: int in foraged:
		if foreign.has(i):
			foreign[i] = fview.people_at(i) - int(foraged[i])
	var kept: Array[Dictionary] = []
	for a: Dictionary in track_data["armies"]:
		var id: int = a["id"]
		a["supply"] = int(states.get(id, Supply.FED))
		var lost := int(losses.get(id, 0))
		if lost > 0:
			_lose(a, lost)
		if not (a["units"] as Array).is_empty():
			kept.append(a)
	track_data["armies"] = kept
	var food_men := 0
	var upkeep := 0
	for a: Dictionary in kept:
		upkeep += _upkeep_of(game, a)
		var i := game.map.index_of(a["hex"])
		if i >= 0 and i < fld.size() and fld[i] == 1:
			food_men += men_of(a)
	return {"eaten": eaten, "foraged": foraged, "food": Supply.food_need(game, food_men), "upkeep": upkeep,
		"count": kept.size()}


## The ready_units phase on the track (Military.refill's arithmetic): every army in order with supply 0 on land its country
## holds refills each company by at most its refill, from the people left on its hex. `ends` (hex index -> people at the
## season's end, for every army hex) is lowered as men are raised. Returns {hex index: men raised}.
static func refill(game: Game, track_data: Dictionary, ends: Dictionary) -> Dictionary:
	var out := {}
	var tag: StringName = track_data["tag"]
	for a: Dictionary in track_data["armies"]:
		var hex: Vector2i = a["hex"]
		if int(a["supply"]) != Supply.FED or Territory.owner_tag(game, hex) != tag or not game.map.is_land(hex):
			continue
		if not bool(Territory.at_home_check(game, tag, hex)["ok"]):
			continue
		var i := game.map.index_of(hex)
		for u: Dictionary in a["units"]:
			var ud := game.defs.unit_def(int(u["kind"]))
			if ud == null:
				continue
			var want := mini(ud.men - int(u["men"]), ud.refill)
			want = mini(want, int(ends.get(i, 0)) * game.defs.levy_permille / 1000)
			if want <= 0:
				continue
			ends[i] = int(ends[i]) - want
			out[i] = int(out.get(i, 0)) + want
			u["men"] = int(u["men"]) + want
	return out


## The supply field of the track's country on `view` (Supply.field's cells, one byte a hex). The game's own field when the
## view changes no piece; otherwise the field of the depots the view makes, kept in the track by winter and depot list.
static func field(game: Game, view: StateView, track_data: Dictionary, winter: bool) -> PackedByteArray:
	var tag: StringName = track_data["tag"]
	if view.changed().is_empty():
		return Supply.field(game, tag, winter)
	var n := game.map.hex_count()
	var out := PackedByteArray()
	out.resize(n)
	out.fill(0)
	var c := Countries.by_tag(game, tag)
	if c == null:
		return out
	var land := Territory.districts(game, c.id)
	var depots := PackedInt32Array()
	for i: int in land:
		if _depot_on(game, view, i):
			depots.append(i)
	if depots.is_empty():
		return out
	var fields: Dictionary = track_data["fields"]
	var key := "%s:%s" % [winter, str(depots)]
	if fields.has(key):
		return fields[key]
	var mask := PackedByteArray()
	mask.resize(n)
	mask.fill(0)
	for i: int in land:
		mask[i] = 1
	var reach := game.defs.supply_reach
	var cost := PathSearch.field(game.map, StepCosts.of(game.map, game.defs), mask, depots, reach, winter, true)
	for i: int in n:
		if cost[i] <= reach:
			out[i] = 1
	fields[key] = out
	return out


# --- helpers -----------------------------------------------------------------------------------------------------------


## The id of the track's country (-1 when it has none).
static func _owner_of(game: Game, track_data: Dictionary) -> int:
	var c := Countries.by_tag(game, track_data["tag"])
	return c.id if c != null else -1


static func men_of(a: Dictionary) -> int:
	var total := 0
	for u: Dictionary in a["units"]:
		total += int(u["men"])
	return total


## Supply._eat: the supplied armies share one need; grain, then fish, fill it from the stock; each army is fed the same
## permille of its men.
static func _eat(game: Game, stock: PackedInt32Array, supplied: Array[Dictionary], eaten: PackedInt32Array, turn: int,
		states: Dictionary, losses: Dictionary) -> void:
	var men := 0
	for a: Dictionary in supplied:
		men += men_of(a)
	var need := Supply.food_need(game, men)
	var taken := 0
	for key: StringName in Supply.FOOD_KEYS:
		var g := game.defs.good_id(key)
		if taken >= need or g < 0 or g >= stock.size():
			continue
		var take := mini(need - taken, stock[g])
		if take > 0:
			taken += take
			eaten[g] += take
	var permille := 1000 if need == 0 else taken * 1000 / need
	for a: Dictionary in supplied:
		var total := men_of(a)
		var fed := total * permille / 1000
		var unfed := total - fed
		states[a["id"]] = Supply.FED if unfed == 0 else Supply.HUNGRY
		losses[a["id"]] = mini(total, Supply.starve_loss(game, a["hex"], turn, unfed))


## Supply._forage: the armies out of supply share each hex's cap in army order; a hex that fed anyone loses people.
static func _forage(game: Game, view: StateView, land: Array[Dictionary], turn: int, states: Dictionary, losses: Dictionary,
		foraged: Dictionary) -> void:
	var by_hex := {}
	for a: Dictionary in land:
		var i := game.map.index_of(a["hex"])
		var group: Array = by_hex.get(i, [])
		group.append(a)
		by_hex[i] = group
	for i: int in by_hex:
		var hex := game.map.hex_of(i)
		var rem := Supply.forage_cap(game, view, hex, turn)
		var fed_any := false
		for a: Dictionary in by_hex[i]:
			var total := men_of(a)
			var fed := mini(total, rem)
			rem -= fed
			fed_any = fed_any or fed > 0
			states[a["id"]] = Supply.FORAGED if fed == total else Supply.HUNGRY
			losses[a["id"]] = mini(total, Supply.starve_loss(game, hex, turn, total - fed))
		var loss := (view.people_at(i) * game.defs.forage_loss_permille + 999) / 1000
		if fed_any and loss > 0 and int(game.state.owner[i]) > 0:
			foraged[i] = loss


## Armies.lose_men on a track copy: the men lost are shared by the companies in proportion, the rest one by one in order;
## a company left with no men leaves.
static func _lose(a: Dictionary, lost: int) -> void:
	var units: Array = a["units"]
	var total := men_of(a)
	lost = clampi(lost, 0, total)
	if lost == 0:
		return
	var taken: Array[int] = []
	var rest := lost
	for u: Dictionary in units:
		var share := lost * int(u["men"]) / total
		taken.append(share)
		rest -= share
	while rest > 0:
		for k: int in units.size():
			if rest > 0 and int(units[k]["men"]) - taken[k] > 0:
				taken[k] += 1
				rest -= 1
	for k: int in units.size():
		units[k]["men"] = int(units[k]["men"]) - taken[k]
	var kept: Array[Dictionary] = []
	for u: Dictionary in units:
		if int(u["men"]) > 0:
			kept.append(u)
	a["units"] = kept


## Military.upkeep_of on a track copy.
static func _upkeep_of(game: Game, a: Dictionary) -> int:
	var total := 0
	for u: Dictionary in a["units"]:
		var ud := game.defs.unit_def(int(u["kind"]))
		if ud != null and ud.men > 0:
			total += (ud.upkeep * int(u["men"]) + ud.men - 1) / ud.men
	return total


## Economy.depot rule of Supply._depot_at, read from the view: a settlement of depot_min_level or more, or a settlement of
## level 1 or more with a port on the coast.
static func _depot_on(game: Game, view: StateView, i: int) -> bool:
	if view.main_use_at(i) != Economy.SETTLEMENTS:
		return false
	var level := view.level_at(i)
	if level >= game.defs.depot_min_level:
		return true
	if level < 1:
		return false
	var hex := game.map.hex_of(i)
	var place := Improve.place_of(game.map, hex)
	return bool(place.get("port", false)) and int(place.get("level", 0)) >= 1 and game.map.coast_mask(hex) != 0
