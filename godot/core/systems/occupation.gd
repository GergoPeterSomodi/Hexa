## Occupation (docs/architecture/m7-build-spec.md 4.3, 4.4, 4.5 (the need and the storm cut), D18 and 5.3): the only writer of
## MapState.occupier, garrison and unsupported. It holds the fortresses and their garrisons, the castle areas (a derived list,
## WarCache), who controls each district, taking and retaking, the regrowth of a garrison, the freed land (D18), and the one
## controllers_changed a phase or action makes (flush). The rules take the game; the cache is game.war_cache and is dropped by
## Game.emit. Integer maths; no luck, no engine calls. WarCache builds through build_areas and controllers_map by reference.
class_name Occupation
extends RefCounted

@warning_ignore_start("integer_division")

const OWNS: Array[String] = ["occupier", "garrison", "unsupported"]
const DISTRICT_CAPTURED := "district_captured"
const CONTROLLERS_CHANGED := "controllers_changed"
## Country ids run 1 to 254 (the occupier and owner bytes); the control table has a slot for each byte value.
const BYTE_SLOTS := 256


# --- the fortresses and their garrisons (4.3) -----------------------------------------------------------------------


## The fortress level of a hex: FamilyDef.fortress of its piece (its family and level); 0 for no fortress, sea or off-map.
static func fortress_level(game: Game, hex: Vector2i) -> int:
	return _level_at(game, _index(game, hex))


## The men a fortress holds at full: its level times garrison_per_level; 0 when it is no fortress.
static func garrison_full(game: Game, hex: Vector2i) -> int:
	var war := _war(game)
	var lvl := fortress_level(game, hex)
	if war == null or lvl == 0:
		return 0
	return lvl * war.garrison_per_level


## The men in the garrison of a hex (0 elsewhere).
static func garrison_of(game: Game, hex: Vector2i) -> int:
	var i := _index(game, hex)
	return _at_int(game.state.garrison, i) if game != null and game.state != null else 0


## A new game: nobody occupies anything, nothing is unsupported, and every fortress holds its full garrison. The
## derived lists are dropped.
static func setup(game: Game) -> void:
	var n := game.map.hex_count()
	if game.state.occupier.size() != n:
		game.state.occupier.resize(n)
	if game.state.unsupported.size() != n:
		game.state.unsupported.resize(n)
	if game.state.garrison.size() != n:
		game.state.garrison.resize(n)
	game.state.occupier.fill(0)
	game.state.unsupported.fill(0)
	for i: int in n:
		game.state.garrison[i] = garrison_full(game, game.map.hex_of(i))
	game.war_cache.clear()


# --- who controls what (4.4) ---------------------------------------------------------------------------------------


## The country that controls a land hex: its occupier, else its owner; 0 at sea, off the map and on unowned land.
static func controller_id(game: Game, hex: Vector2i) -> int:
	return _controller_at(game, _index(game, hex))


## The tag of the country that controls a hex, or &"" when none.
static func controller_tag(game: Game, hex: Vector2i) -> StringName:
	return _tag_of_id(game, controller_id(game, hex))


## True when a land hex is held by someone other than its owner.
static func is_occupied(game: Game, hex: Vector2i) -> bool:
	var i := _index(game, hex)
	return i >= 0 and game.map.land[i] != 0 and _at_byte(game.state.occupier, i) != 0


## The long name of the country occupying a hex ("" when none): the words of the work and the hex refusals.
static func occupier_long_name(game: Game, hex: Vector2i) -> String:
	var i := _index(game, hex)
	var c := Countries.by_id(game, _at_byte(game.state.occupier, i)) if i >= 0 else null
	if c == null:
		return ""
	var cdef := Countries.def_of(game, c.tag)
	if cdef != null and not cdef.long_name.is_empty():
		return cdef.long_name
	return String(c.tag)


## The hex indices a country controls, ascending (WarCache, built once until a control change).
static func controlled(game: Game, id: int) -> PackedInt32Array:
	return game.war_cache.controlled(game, id)


## Every country's controlled hexes: id -> ascending PackedInt32Array, in one pass over the map (WarCache builds it).
static func controllers_map(game: Game) -> Dictionary:
	var n := game.map.hex_count()
	var ids := PackedInt32Array()
	ids.resize(n)
	var sizes := PackedInt32Array()
	sizes.resize(BYTE_SLOTS)
	sizes.fill(0)
	for i: int in n:
		var c := _controller_at(game, i)
		ids[i] = c
		if c > 0:
			sizes[c] += 1
	var lists: Array[PackedInt32Array] = []
	var next := PackedInt32Array()
	next.resize(BYTE_SLOTS)
	next.fill(0)
	for c: int in BYTE_SLOTS:
		var list := PackedInt32Array()
		list.resize(sizes[c])
		lists.append(list)
	for i: int in n:
		var c := ids[i]
		if c > 0:
			lists[c][next[c]] = i
			next[c] += 1
	var out: Dictionary = {}
	for c: int in range(1, BYTE_SLOTS):
		if sizes[c] > 0:
			out[c] = lists[c]
	return out


## True when a siege of a hex is by a country at war with the hex's controller (the siege stands; 4.5).
static func besieged(game: Game, hex: Vector2i) -> bool:
	var s := siege_at(game, hex)
	if s == null:
		return false
	var holder := controller_tag(game, hex)
	return holder != &"" and War.live_between(game.wars, s.besieger, holder) != null


## The siege on a hex, or null.
static func siege_at(game: Game, hex: Vector2i) -> Siege:
	for s: Siege in game.sieges:
		if s.hex == hex:
			return s
	return null


## 4.5's need: siege_base_need + ceil(siege_per_level x level x garrison / full) + the relief's elevation; 0 off a fortress.
static func siege_need(game: Game, hex: Vector2i) -> int:
	var war := _war(game)
	var i := _index(game, hex)
	var lvl := fortress_level(game, hex)
	if war == null or i < 0 or lvl == 0:
		return 0
	var full := lvl * war.garrison_per_level
	var term := 0
	if full > 0:
		term = (war.siege_per_level * lvl * garrison_of(game, hex) + full - 1) / full
	var relief := int(game.map.relief[i])
	var elevation := war.relief_elevation[relief] if relief < war.relief_elevation.size() else 0
	return war.siege_base_need + term + elevation


## The garrison a storm by `tag` faces (D19): the garrison less storm_cut_permille x progress / need of the siege tag
## holds on the hex, rounded up; the whole garrison when tag besieges nothing there.
static func storm_garrison(game: Game, hex: Vector2i, tag: StringName) -> int:
	var men := garrison_of(game, hex)
	var war := _war(game)
	var s := siege_at(game, hex)
	if war == null or s == null or s.besieger != tag or men == 0:
		return men
	var need := siege_need(game, hex)
	if need <= 0:
		return men
	var cut := war.storm_cut_permille * clampi(s.progress, 0, need) / need
	return (men * (1000 - cut) + 999) / 1000


# --- castle areas (4.3) -------------------------------------------------------------------------------------------


## The fortress whose area holds a hex (the hex itself for a fortress), or Army.NO_HEX.
static func area_of(game: Game, hex: Vector2i) -> Vector2i:
	var i := _index(game, hex)
	var areas := game.war_cache.area_index(game)
	if i < 0 or i >= areas.size() or areas[i] < 0:
		return Army.NO_HEX
	return game.map.hex_of(areas[i])


## What a hex is in its castle area (4.3): &"castle" a fortress; &"open" no area, or occupied; &"held" its owner holds
## it and its fortress stands; &"fallen" its owner holds it and its fortress is occupied. `standing` (the byte array of
## standing(), by hex index) is read when given, else the fortress's occupier is read now.
static func area_state(game: Game, hex: Vector2i, standing_bytes: PackedByteArray = PackedByteArray()) -> StringName:
	var i := _index(game, hex)
	if i < 0 or game.map.land[i] == 0:
		return &"open"
	if fortress_level(game, hex) > 0:
		return &"castle"
	var fortress := area_of(game, hex)
	if fortress == Army.NO_HEX or is_occupied(game, hex):
		return &"open"
	var f := game.map.index_of(fortress)
	var stands := _at_byte(standing_bytes, f) == 1 if f < standing_bytes.size() else _at_byte(game.state.occupier, f) == 0
	return &"held" if stands else &"fallen"


## The hexes of a fortress's area, nearest first, then by hex index; the fortress itself first.
static func members(game: Game, fortress: Vector2i) -> PackedInt32Array:
	var f := _index(game, fortress)
	var out := PackedInt32Array()
	if f < 0:
		return out
	var areas := game.war_cache.area_index(game)
	var steps := game.war_cache.area_steps(game)
	var rows: Array = []
	for i: int in areas.size():
		if areas[i] == f:
			rows.append([steps[i], i])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for row: Array in rows:
		out.append(int(row[1]))
	return out


## One byte per hex: 1 on every fortress its owner holds (not occupied, with an owner). Read by area_state.
static func standing(game: Game) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(game.map.hex_count())
	out.fill(0)
	for f: int in game.war_cache.fortresses(game):
		if _at_byte(game.state.occupier, f) == 0 and _at_byte(game.state.owner, f) != 0:
			out[f] = 1
	return out


# --- taking, releasing, flushing (4.4) -----------------------------------------------------------------------------


## Makes `tag` the controller of a hex (its occupier, or 0 when tag is the owner): the garrison's men are lost (returned
## in the event as `garrison_lost`), unsupported is reset, and one district_captured is emitted with `info` added (name,
## seasons, opened). The change joins the pending flush. Nothing happens when tag already controls the hex.
static func capture(game: Game, hex: Vector2i, tag: StringName, by: StringName, info: Dictionary) -> void:
	var i := _index(game, hex)
	var taker := _id_of(game, tag)
	if i < 0 or game.map.land[i] == 0 or taker <= 0:
		return
	var owner_id := _at_byte(game.state.owner, i)
	var old := _controller_at(game, i)
	if taker == old:
		return
	var lost := _at_int(game.state.garrison, i)
	game.state.garrison[i] = 0
	game.state.unsupported[i] = 0
	game.state.occupier[i] = 0 if taker == owner_id else taker
	game.war_cache.note_pending(i, old)
	game.war_cache.forget_control()
	var others: Array[StringName] = []
	var old_tag := _tag_of_id(game, old)
	if old_tag != &"":
		others.append(old_tag)
	var event := {"kind": DISTRICT_CAPTURED, "hex": hex, "tag": tag, "others": others,
		"owner": _tag_of_id(game, owner_id), "by": by, "garrison_lost": lost}
	for key: Variant in info:
		event[key] = info[key]
	game.emit(event)


## Gives back the hexes to their owners (a peace, a developer transfer): occupier 0 and unsupported 0 where somebody
## occupies them; the change joins the pending flush.
static func release(game: Game, hexes: Array[Vector2i]) -> void:
	var changed := false
	for hex: Vector2i in hexes:
		var i := _index(game, hex)
		if i < 0 or game.map.land[i] == 0 or _at_byte(game.state.occupier, i) == 0:
			continue
		game.war_cache.note_pending(i, _at_byte(game.state.occupier, i))
		game.state.occupier[i] = 0
		game.state.unsupported[i] = 0
		changed = true
	if changed:
		game.war_cache.forget_control()


## Sets a fortress's garrison to `men`, between 0 and its full garrison. The caller books any men lost.
static func set_garrison(game: Game, hex: Vector2i, men: int) -> void:
	var i := _index(game, hex)
	if i < 0:
		return
	game.state.garrison[i] = clampi(men, 0, garrison_full(game, hex))


## The sieges phase's regrowth of one fortress (4.3). A fortress its owner holds, with no siege and no hostile army on it,
## takes garrison_regen_per_level x level men a season, levied from its hex and then its ring (in direction order, owner's
## land the owner holds), as People flow `garrisoned`. A garrison above full (a fortress whose level fell) gives its excess
## back as `returned`. Returns the men levied.
static func regrow(game: Game, hex: Vector2i) -> int:
	var i := _index(game, hex)
	var war := _war(game)
	if i < 0 or war == null:
		return 0
	var lvl := fortress_level(game, hex)
	var full := lvl * war.garrison_per_level
	var have := _at_int(game.state.garrison, i)
	if have > full:
		# A fortress that fell (level 0 too) gives its excess back; only the men People places leave the garrison.
		var placed := int(People.give_back.call(game, hex, have - full))
		game.state.garrison[i] = have - placed
		return 0
	if lvl == 0:
		return 0
	var owner_id := _at_byte(game.state.owner, i)
	if owner_id == 0 or is_occupied(game, hex) or siege_at(game, hex) != null or _hostile_on(game, hex, owner_id):
		return 0
	var want := mini(war.garrison_regen_per_level * lvl, full - have)
	if want <= 0:
		return 0
	var tag := _tag_of_id(game, owner_id)
	var levied := _levy(game, tag, hex, want)
	var grid := game.map.grid()
	for d: int in 6:
		if levied >= want:
			break
		var nb := grid.neighbour(hex, d)
		var j := game.map.index_of(nb)
		if j < 0 or game.map.land[j] == 0 or _at_byte(game.state.owner, j) != owner_id or _at_byte(game.state.occupier, j) != 0:
			continue
		levied += _levy(game, tag, nb, want - levied)
	game.state.garrison[i] = have + levied
	return levied


## regrow on every fortress (an empty one too) and every hex that holds men in a garrison (a fortress that fell to level 0 is
## off the fortress list), each once, in hex index order. Returns the men levied.
static func regrow_all(game: Game) -> int:
	var visit: Dictionary = {}
	for f: int in game.war_cache.fortresses(game):
		visit[f] = true
	for i: int in game.map.hex_count():
		if _at_int(game.state.garrison, i) > 0:
			visit[i] = true
	var order: Array = visit.keys()
	order.sort()
	var total := 0
	for i: Variant in order:
		total += regrow(game, game.map.hex_of(int(i)))
	return total


## The hexes of `hexes` that Territory.transfer would change to `to_id`, by the same checks in the same order (the map, the
## range of to_id, the land, the index, not already to_id). Nothing is written.
static func changing_hexes(game: Game, hexes: Array[Vector2i], to_id: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if game == null or game.map == null or game.state == null or to_id < 0 or to_id > game.countries.size():
		return out
	for hex: Vector2i in hexes:
		var i := game.map.index_of(hex)
		if i < 0 or game.map.land[i] == 0 or i >= game.state.owner.size() or int(game.state.owner[i]) == to_id:
			continue
		out.append(hex)
	return out


## Emits the one controllers_changed of this phase or action for the hexes whose controller changed since the last flush
## (hex index order): tag is the country that gained the most of them (ties to the lower id), others the other countries
## involved. Nothing is emitted when no control changed.
static func flush(game: Game) -> void:
	var pending: Dictionary = game.war_cache.take_pending()
	if pending.is_empty():
		return
	var keys: Array = pending.keys()
	keys.sort()
	var hexes: Array[Vector2i] = []
	var gained: Dictionary = {}
	var involved: Dictionary = {}
	for key: Variant in keys:
		var i := int(key)
		var old := int(pending[key])
		var now := _controller_at(game, i)
		if now == old:
			continue
		hexes.append(game.map.hex_of(i))
		gained[now] = int(gained.get(now, 0)) + 1
		for id: int in [old, now]:
			if id > 0:
				involved[id] = true
	if hexes.is_empty():
		return
	var lead := 0
	var best := 0
	var ids: Array = involved.keys()
	ids.sort()
	for id: Variant in ids:
		var count := int(gained.get(int(id), 0))
		if count > best:
			best = count
			lead = int(id)
	var others: Array[StringName] = []
	for id: Variant in ids:
		if int(id) != lead and _tag_of_id(game, int(id)) != &"":
			others.append(_tag_of_id(game, int(id)))
	game.emit({"kind": CONTROLLERS_CHANGED, "hexes": hexes, "tag": _tag_of_id(game, lead), "others": others})


## D18 (the sieges phase): every occupied land hex with no army of its occupier within support_range hexes is unsupported
## for one more season (none while it has a garrison); an army in range resets it. At unsupported_seasons the hex goes
## back to its owner (district_captured {by: freed}). Changes join the pending flush.
static func support_season(game: Game) -> void:
	var war := _war(game)
	if war == null:
		return
	var armies_of: Dictionary = {}
	for a: Army in game.armies:
		var id := _id_of(game, a.tag)
		if id > 0:
			var list: Array = armies_of.get(id, [])
			list.append(a.hex)
			armies_of[id] = list
	for i: int in game.map.hex_count():
		var occ := _at_byte(game.state.occupier, i)
		if occ == 0 or game.map.land[i] == 0:
			continue
		var hex := game.map.hex_of(i)
		if _supported(hex, armies_of.get(occ, []), war.support_range):
			game.state.unsupported[i] = 0
			continue
		if _at_int(game.state.garrison, i) > 0:
			continue
		game.state.unsupported[i] = mini(_at_byte(game.state.unsupported, i) + 1, 255)
		if _at_byte(game.state.unsupported, i) >= war.unsupported_seasons:
			capture(game, hex, _tag_of_id(game, _at_byte(game.state.owner, i)), &"freed", {})


# --- the derived lists (WarCache builds them by reference) ----------------------------------------------------------


## The fortress lists of WarCache: the fortresses (hex indices ascending), each hex's level at the time, each hex's
## fortress (its own index for a fortress, -1 for no area) and its steps. A fortress walks its owner's land up to
## area_reach[level] steps, never across a crest without a pass; a hex belongs to the nearest fortress, ties to the higher
## level, then the lower index.
static func build_areas(game: Game) -> Dictionary:
	var n := game.map.hex_count()
	var levels := PackedByteArray()
	levels.resize(n)
	levels.fill(0)
	var fortresses := PackedInt32Array()
	for i: int in n:
		var lvl := _level_at(game, i)
		levels[i] = lvl
		if lvl > 0:
			fortresses.append(i)
	var area := PackedInt32Array()
	area.resize(n)
	area.fill(-1)
	var steps := PackedInt32Array()
	steps.resize(n)
	steps.fill(0)
	for f: int in fortresses:
		area[f] = f
	for f: int in fortresses:
		var reach := _reach_of(game, levels[f])
		var seen := _walk(game, f, reach)
		for key: Variant in seen:
			var j := int(key)
			var s := int(seen[key])
			if area[j] < 0 or s < steps[j] or (s == steps[j] and levels[f] > levels[area[j]]):
				area[j] = f
				steps[j] = s
	return {"fortresses": fortresses, "levels": levels, "area": area, "steps": steps}


## The hexes a fortress's walk reaches over its owner's land, as hex index -> steps (the fortress at 0).
static func _walk(game: Game, f: int, reach: int) -> Dictionary:
	var seen: Dictionary = {f: 0}
	var owner_id := _at_byte(game.state.owner, f)
	if reach <= 0 or owner_id == 0:
		return seen
	var frontier := PackedInt32Array([f])
	for s: int in range(1, reach + 1):
		var next := PackedInt32Array()
		for h: int in frontier:
			for d: int in 6:
				var j := StepCosts.neighbour_index(game.map.cols, game.map.rows, h, d)
				if j < 0 or game.map.land[j] == 0 or seen.has(j) or _at_byte(game.state.owner, j) != owner_id:
					continue
				if _crest_blocked(game.map, h, d, j):
					continue
				seen[j] = s
				next.append(j)
		frontier = next
	return seen


## True when the edge from hex i in direction d to j is a crest with no pass (the walk's wall; M6's StepCosts).
static func _crest_blocked(map: MapData, i: int, d: int, j: int) -> bool:
	var e := StepCosts.edge_slot(i, d, j)
	return e < map.crest.size() and map.crest[e] == 1 and (e >= map.pass_edge.size() or map.pass_edge[e] == 0)


static func _reach_of(game: Game, lvl: int) -> int:
	var war := _war(game)
	return war.area_reach[lvl] if war != null and lvl < war.area_reach.size() else 0


# --- helpers --------------------------------------------------------------------------------------------------------


static func _war(game: Game) -> WarDef:
	return game.defs.war if game != null and game.defs != null else null


static func _index(game: Game, hex: Vector2i) -> int:
	if game == null or game.map == null or game.state == null:
		return -1
	return game.map.index_of(hex)


## The fortress level of hex index i (0 when i is off the map, no piece, or no family data).
static func _level_at(game: Game, i: int) -> int:
	if i < 0 or game.defs == null or i >= game.state.main_use.size() or i >= game.state.level.size():
		return 0
	var family := int(game.state.main_use[i])
	var fam := game.defs.family(family) if family > 0 else null
	if fam == null:
		return 0
	var level := int(game.state.level[i])
	return fam.fortress[level] if level >= 0 and level < fam.fortress.size() else 0


## The controller of hex index i: its occupier, else its owner; 0 at sea and off the map.
static func _controller_at(game: Game, i: int) -> int:
	if i < 0 or i >= game.map.land.size() or game.map.land[i] == 0:
		return 0
	var occ := _at_byte(game.state.occupier, i)
	return occ if occ != 0 else _at_byte(game.state.owner, i)


static func _at_byte(values: PackedByteArray, i: int) -> int:
	return int(values[i]) if i >= 0 and i < values.size() else 0


static func _at_int(values: PackedInt32Array, i: int) -> int:
	return int(values[i]) if i >= 0 and i < values.size() else 0


static func _id_of(game: Game, tag: StringName) -> int:
	var c := Countries.by_tag(game, tag) if tag != &"" else null
	return c.id if c != null else 0


static func _tag_of_id(game: Game, id: int) -> StringName:
	var c := Countries.by_id(game, id) if id > 0 else null
	return c.tag if c != null else &""


## True when an army of the list's hexes stands within `range_hexes` of the hex.
static func _supported(hex: Vector2i, army_hexes: Array, range_hexes: int) -> bool:
	for h: Vector2i in army_hexes:
		if ImproveRules.hex_distance(hex, h) <= range_hexes:
			return true
	return false


## True when an army at war with the owner stands on the hex.
static func _hostile_on(game: Game, hex: Vector2i, owner_id: int) -> bool:
	var owner_tag := _tag_of_id(game, owner_id)
	for a: Army in Armies.at(game, hex):
		if a.tag != owner_tag and War.live_between(game.wars, a.tag, owner_tag) != null:
			return true
	return false


## Levies up to `want` men (the People door's own limit applies); returns the men taken.
static func _levy(game: Game, tag: StringName, hex: Vector2i, want: int) -> int:
	var most := int(People.available.call(game, hex))
	var men := mini(want, most)
	if men <= 0:
		return 0
	return int(People.levy.call(game, tag, hex, men, &"garrisoned"))
