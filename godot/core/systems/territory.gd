## Territory ownership system (docs/architecture/m2-build-spec.md section 5.3):
## owns MapState.owner, enforces the home rule for land actions, and transfers hex ownership.
class_name Territory
extends RefCounted

const OWNS: Array[String] = ["owner"]


## Copies the scenario's grown owner bytes into `game.state.owner`.
static func setup(game: Game, scenario: ScenarioDef) -> void:
	if game == null or game.state == null:
		return
	var n := game.map.hex_count() if game.map != null else 0
	if scenario == null:
		game.state.owner.resize(n)
		game.state.owner.fill(0)
		return
	if n == 0 or scenario.owner.size() == n:
		game.state.owner = scenario.owner.duplicate()
	else:
		game.state.owner.resize(n)
		game.state.owner.fill(0)
		for i: int in mini(n, scenario.owner.size()):
			game.state.owner[i] = scenario.owner[i]


## Country id owning `hex` (1..254), or 0 for unowned land, sea, or off-map.
static func owner_id(game: Game, hex: Vector2i) -> int:
	if game == null or game.map == null or game.state == null:
		return 0
	var idx := game.map.index_of(hex)
	if idx < 0 or game.map.land[idx] == 0 or idx >= game.state.owner.size():
		return 0
	return int(game.state.owner[idx])


## Country tag owning `hex`, or &"" when unowned, sea, or off-map.
static func owner_tag(game: Game, hex: Vector2i) -> StringName:
	var oid := owner_id(game, hex)
	if oid <= 0 or game == null:
		return &""
	var c := Countries.by_id(game, oid)
	return c.tag if c != null else &""


## Home rule verdict `{ok, reason}` for `tag` acting on `hex`.
static func at_home_check(game: Game, tag: StringName, hex: Vector2i) -> Dictionary:
	if game == null or not game.has_countries():
		return {"ok": true, "reason": ""}
	if game.map == null or not game.map.is_land(hex):
		return {"ok": true, "reason": ""}
	if tag == &"":
		return _refusal("choose your country first")
	var actor := Countries.by_tag(game, tag)
	if actor == null:
		return _refusal("no country %s" % String(tag))
	if not actor.alive:
		return _refusal("%s is no more" % _country_name(game, tag))
	var oid := owner_id(game, hex)
	if oid == 0:
		return _refusal("no one holds this land")
	if oid != actor.id:
		return _refusal("not your land: the %s holds it" % _holder_long_name(game, oid))
	return {"ok": true, "reason": ""}


## Transfers `hexes` to `to_id` (0 frees land), skipping sea, off-map, and already-owned hexes.
## Emits one `{kind: "owners_changed", hexes, tag, others}` event when any hex changes; returns the count changed.
static func transfer(game: Game, hexes: Array[Vector2i], to_id: int) -> int:
	if game == null or game.map == null or game.state == null:
		return 0
	if to_id < 0 or to_id > game.countries.size():
		return 0
	var changed: Array[Vector2i] = []
	var old_ids: Array[int] = []
	for hex: Vector2i in hexes:
		var idx := game.map.index_of(hex)
		if idx < 0 or game.map.land[idx] == 0 or idx >= game.state.owner.size():
			continue
		if int(game.state.owner[idx]) == to_id:
			continue
		var old_id := int(game.state.owner[idx])
		if old_id > 0 and not old_ids.has(old_id):
			old_ids.append(old_id)
		game.state.owner[idx] = to_id
		changed.append(hex)
	if not changed.is_empty():
		old_ids.sort()
		var others: Array[StringName] = []
		for old_id: int in old_ids:
			var old_country := Countries.by_id(game, old_id)
			if old_country != null:
				others.append(old_country.tag)
		var new_country := Countries.by_id(game, to_id)
		var new_tag: StringName = new_country.tag if new_country != null else &""
		game.emit({"kind": "owners_changed", "hexes": changed, "tag": new_tag, "others": others})
	return changed.size()


## Hex indices owned by `id`, in ascending index order.
static func districts(game: Game, id: int) -> PackedInt32Array:
	if game == null or game.map == null or game.state == null or id <= 0:
		return PackedInt32Array()
	var held: Variant = _by_owner(game).get(id)
	return held as PackedInt32Array if held != null else PackedInt32Array()


## Every country's hex indices (id -> ascending PackedInt32Array), made in one pass over the map and kept in the game's
## view cache (a pinned slot) while the owner bytes are the same: the key is their hash, so any change of an owner,
## by an action or a direct edit, makes the next call build it again.
static func _by_owner(game: Game) -> Dictionary:
	var key: Array = [hash(game.state.owner), game.state.owner.size(), game.map.hex_count()]
	return game.view_cache.pinned(&"districts", key, func() -> Dictionary: return _index_of(game)) as Dictionary


static func _index_of(game: Game) -> Dictionary:
	var n := mini(game.map.hex_count(), game.state.owner.size())
	var sizes := PackedInt32Array()
	sizes.resize(256)
	sizes.fill(0)
	for i: int in n:
		var id := int(game.state.owner[i])
		if id > 0 and game.map.land[i] != 0:
			sizes[id] += 1
	var lists: Array[PackedInt32Array] = []
	var next := PackedInt32Array()
	next.resize(256)
	next.fill(0)
	for id: int in 256:
		var list := PackedInt32Array()
		list.resize(sizes[id])
		lists.append(list)
	for i: int in n:
		var id := int(game.state.owner[i])
		if id > 0 and game.map.land[i] != 0:
			lists[id][next[id]] = i
			next[id] += 1
	var out: Dictionary = {}
	for id: int in range(1, 256):
		if sizes[id] > 0:
			out[id] = lists[id]
	return out


## Number of land hexes owned by `id`.
static func count(game: Game, id: int) -> int:
	if game == null or game.map == null or game.state == null or id <= 0:
		return 0
	return districts(game, id).size()


## Country ids sharing a land-to-land edge with `id`, ascending, with 0 excluded.
static func neighbours(game: Game, id: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if game == null or game.map == null or game.state == null or id <= 0:
		return out
	var n := mini(game.map.hex_count(), game.state.owner.size())
	var cols := game.map.cols
	var rows := game.map.rows
	var grid := game.map.grid()
	var seen: Dictionary = {}
	for i: int in n:
		if game.map.land[i] == 0 or int(game.state.owner[i]) != id:
			continue
		var hex := game.map.hex_of(i)
		for d: int in 6:
			var nb := grid.neighbour(hex, d)
			if nb.x < 0 or nb.y < 0 or nb.x >= cols or nb.y >= rows:
				continue
			var nb_idx := nb.y * cols + nb.x
			if nb_idx >= game.state.owner.size() or game.map.land[nb_idx] == 0:
				continue
			var other := int(game.state.owner[nb_idx])
			if other > 0 and other != id:
				seen[other] = true
	var ids: Array = seen.keys()
	ids.sort()
	for v: Variant in ids:
		out.append(int(v))
	return out


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _country_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef != null and not cdef.name.is_empty():
		return cdef.name
	return String(tag)


static func _holder_long_name(game: Game, oid: int) -> String:
	var holder := Countries.by_id(game, oid)
	if holder == null:
		return str(oid)
	var cdef := Countries.def_of(game, holder.tag)
	if cdef != null and not cdef.long_name.is_empty():
		return cdef.long_name
	return String(holder.tag)
