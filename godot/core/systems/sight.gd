## Sight, the explored land and the witnesses (docs/architecture/m6-build-spec.md 4.11, 5.0 R4, 5.3). A country sees the
## hexes it holds and every hex within the land sight of them (the owner bytes), and the hexes its armies see; it has
## explored what it has ever seen. Game calls this by reference (`.call`): a typed call from core/game into a system
## would make the two scripts need each other to parse. A map-only game (no countries) does nothing here.
## `explored` is written only by setup, see_path and season (R4). Season is self-healing: it explores each country's
## current land sight from the state, so nothing waits in memory between a change and the vision phase.
class_name Sight
extends RefCounted

const OWNS: Array[String] = ["explored"]
## The event kinds that carry witnesses when they have a hex (4.11).
const SIGHTED: Array[String] = ["work_started", "work_finished", "work_cancelled", "town_grew", "district_declined",
	"army_raised", "army_disbanded", "army_starved", "unit_lost"]


## Explored = the land sight at the start (new_scenario only; R11). Called by reference from Game.new_scenario.
static func setup(game: Game) -> void:
	if not _ready(game):
		return
	for c: Country in game.countries:
		if c != null:
			game.sight.forget_land(c.id)  # the land of the start, never a land cached before it
			c.explored = game.sight.land_of(game, c.id).duplicate()


## Rebuilds the army part of game.sight: per country a bitset of the hexes its armies see, and the watchers of each hex.
## Never writes explored (R4). Armies are read, never written, here.
static func refresh(game: Game) -> void:
	if not _ready(game):
		return
	var n := game.map.hex_count()
	var bits_by_tag: Dictionary = {}
	var watch: Dictionary = {}
	for army: Army in game.armies:
		if army == null or army.hex == Army.NO_HEX:
			continue
		var c := Countries.by_tag(game, army.tag)
		if c == null:
			continue
		if not bits_by_tag.has(c.id):
			var empty := PackedByteArray()
			empty.resize((n + 7) >> 3)
			empty.fill(0)
			bits_by_tag[c.id] = empty
		var bits: PackedByteArray = bits_by_tag[c.id]
		var i := game.map.index_of(army.hex)
		if i < 0:
			continue
		for j: int in SightCache.disc(game.map, i, _army_sight(game, army)):
			bits[j >> 3] = bits[j >> 3] | (1 << (j & 7))
			var names: PackedStringArray = watch.get(j, PackedStringArray())
			if not names.has(String(army.tag)):
				names.append(String(army.tag))
			watch[j] = names
		bits_by_tag[c.id] = bits
	game.sight.set_army_part(bits_by_tag, watch)


## True when `tag` sees `hex` now: it holds the hex or a hex within the land sight of it, or an army of its sees it.
static func sees(game: Game, tag: StringName, hex: Vector2i) -> bool:
	if not _ready(game) or tag == &"":
		return false
	var c := Countries.by_tag(game, tag)
	var i := game.map.index_of(hex)
	if c == null or i < 0:
		return false
	if SightCache.bit_is(game.sight.armies_of(c.id), i):
		return true
	var owner: PackedByteArray = game.state.owner
	for j: int in SightCache.disc(game.map, i, _land_sight(game)):
		if j < owner.size() and int(owner[j]) == c.id:
			return true
	return false


## The tags that see `hex` (country id order), `actor` among them whether or not it sees it. Read from the hex's disc
## alone (the owners of its hexes within the land sight, the armies' watchers there, the actor): the same tags `sees`
## gives for every country, without a loop over the countries (at most seven owners and a few watchers).
static func witnesses_of(game: Game, hex: Vector2i, actor: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	if not _ready(game):
		return out
	var ids: Array[int] = []
	var i := game.map.index_of(hex)
	if i >= 0:
		var owner: PackedByteArray = game.state.owner
		for j: int in SightCache.disc(game.map, i, _land_sight(game)):
			if j < owner.size() and owner[j] > 0 and not ids.has(int(owner[j])):
				ids.append(int(owner[j]))
		var watchers: PackedStringArray = game.sight.watchers.get(i, PackedStringArray())
		for watcher: String in watchers:
			var held := Countries.by_tag(game, StringName(watcher))
			if held != null and not ids.has(held.id):
				ids.append(held.id)
	var actor_country := Countries.by_tag(game, actor)
	if actor_country != null and not ids.has(actor_country.id):
		ids.append(actor_country.id)
	ids.sort()
	for id: int in ids:
		var c := Countries.by_id(game, id)
		if c != null and c.tag != &"":
			out.append(String(c.tag))
	return out


## Called by Game.emit for every event, before it is queued: owners_changed forgets the land sight of the countries it
## names; a sighted kind with a hex gets its witnesses unless it has some.
static func on_emit(game: Game, event: Dictionary) -> void:
	if not _ready(game):
		return
	var kind := str(event.get("kind", ""))
	if kind == "owners_changed":
		_owners_changed(game, event)
	elif SIGHTED.has(kind) and event.get("hex") is Vector2i and not event.has("witnesses"):
		var actor := StringName(str(event.get("tag", "")))
		event["witnesses"] = witnesses_of(game, event["hex"] as Vector2i, actor)


## True when `tag` has explored `hex` (the bit of its explored set).
static func explored(game: Game, tag: StringName, hex: Vector2i) -> bool:
	var c := Countries.by_tag(game, tag)
	return c != null and game != null and game.map != null and SightCache.bit_is(c.explored, game.map.index_of(hex))


## True when `viewer` has explored a hex that `other` holds (the knowledge clause of 4.11).
static func explored_any(game: Game, viewer: StringName, other: StringName) -> bool:
	if not _ready(game):
		return false
	var v := Countries.by_tag(game, viewer)
	var o := Countries.by_tag(game, other)
	if v == null or o == null or v.id == o.id:
		return false
	var known: PackedByteArray = game.sight.known_of(game, v.id)
	return o.id < known.size() and known[o.id] == 1


## Explored along a walk: each hex of `hexes` and the hexes within `radius` of it (0: the hexes alone). Movement calls it.
static func see_path(game: Game, tag: StringName, hexes: Array[Vector2i], radius: int) -> void:
	if not _ready(game):
		return
	var c := Countries.by_tag(game, tag)
	if c == null:
		return
	var indices := PackedInt32Array()
	for hex: Vector2i in hexes:
		var i := game.map.index_of(hex)
		if i >= 0:
			indices.append(i)
	_mark(game, c, indices, radius)


## The vision phase: the army part is rebuilt; then explored takes each country's current land sight (from the state, so
## a loaded game and a live one agree) and the hexes its armies see.
static func season(game: Game) -> void:
	if not _ready(game):
		return
	refresh(game)
	for c: Country in game.countries:
		if c != null:
			_or_land(game, c)
	var lists: Dictionary = {}
	for index: Variant in game.sight.watchers:
		for tag: String in game.sight.watchers[index]:
			var c := Countries.by_tag(game, StringName(tag))
			if c != null:
				if not lists.has(c.id):
					lists[c.id] = PackedInt32Array()
				var held: PackedInt32Array = lists[c.id]
				held.append(int(index))
				lists[c.id] = held
	for id: Variant in lists:
		_mark(game, Countries.by_id(game, int(id)), lists[id], 0)


## Sets the explored bits of `c` for each index and its disc of `radius`; the bitset is copied once, then changed in place.
static func _mark(game: Game, c: Country, indices: PackedInt32Array, radius: int) -> void:
	if c == null or indices.is_empty():
		return
	var bits := _bits_of(game, c)
	var owner: PackedByteArray = game.state.owner
	for i: int in indices:
		for j: int in SightCache.disc(game.map, i, radius):
			if ((bits[j >> 3] >> (j & 7)) & 1) == 0:
				bits[j >> 3] = bits[j >> 3] | (1 << (j & 7))
				if j < owner.size() and int(owner[j]) > 0 and int(owner[j]) != c.id:
					game.sight.learned(c.id, int(owner[j]))
	c.explored = bits


## ORs country `c`'s land sight (its cached bitset) into its explored set. A set that grew drops its known set.
static func _or_land(game: Game, c: Country) -> void:
	var land: PackedByteArray = game.sight.land_of(game, c.id)
	var bits := _bits_of(game, c)
	var grew := false
	for k: int in land.size():
		var old: int = bits[k]
		var both: int = old | land[k]
		if both != old:
			bits[k] = both
			grew = true
	c.explored = bits
	if grew:
		game.sight.forget_known(c.id)


## The explored bitset of `c`, made empty when its size is not the map's (an in-memory game that never set it up).
static func _bits_of(game: Game, c: Country) -> PackedByteArray:
	var n := (game.map.hex_count() + 7) >> 3
	if c.explored.size() == n:
		return c.explored
	var bits := PackedByteArray()
	bits.resize(n)
	bits.fill(0)
	return bits


## Owners changed: forget the land sight of the countries named (the gain is explored at the next season, from the state).
static func _owners_changed(game: Game, event: Dictionary) -> void:
	var names: Array = [str(event.get("tag", ""))]
	for other: Variant in event.get("others", []):
		names.append(str(other))
	for name: Variant in names:
		var c := Countries.by_tag(game, StringName(str(name)))
		if c != null:
			game.sight.forget_land(c.id)


## The army sight of an army: the largest sight of its kinds (1 when the defs do not say).
static func _army_sight(game: Game, army: Army) -> int:
	var out := 1
	for u: Unit in army.units:
		var def: UnitDef = game.defs.unit_def(u.kind) if game.defs != null else null
		if def != null:
			out = maxi(out, def.sight)
	return out


static func _land_sight(game: Game) -> int:
	return game.defs.land_sight if game.defs != null else 1


## True when the game has countries and a map and state to read.
static func _ready(game: Game) -> bool:
	return game != null and game.map != null and game.state != null and game.has_countries()
