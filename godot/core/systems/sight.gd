## Sight, the explored land and the witnesses (docs/architecture/m6-build-spec.md 4.11, 5.0 R4, 5.3; fog spec R6 to R17, R30).
## A country sees the hexes it CONTROLS and every hex within the land sight of them (fog spec R13: the controller bytes, the
## occupier where one stands, else the owner), and the hexes its armies see; it has explored what it has ever seen.
## Game calls this by reference (`.call`): a typed call from core/game into a system would make the two scripts need each
## other to parse. A map-only game (no countries) does nothing here.
## `explored` is written by five entry points only (fog spec R11, pinned by test_no_other_writers.gd): setup (the start: the
## land sight OR the scenario's regions, R6), see_path and season (the walks and the vision phase), and on_emit for
## district_captured (R9) and for the two ownership events (R10). Season is self-healing: it explores each country's
## current land sight from the state, so nothing waits in memory between a change and the vision phase, except the land
## made at once by the events.
class_name Sight
extends RefCounted

const OWNS: Array[String] = ["explored"]
## The land kinds (fog spec D12, R30): facts of a hex, told to whoever has discovered it. They carry `land: true` and no
## witness list.
const LAND_KINDS: Array[String] = ["work_started", "work_finished", "work_cancelled", "town_grew", "district_declined",
	"district_captured"]
## The other event kinds that carry witnesses when they have a hex (4.11).
const SIGHTED: Array[String] = ["army_raised", "army_disbanded", "army_starved", "unit_lost", "battle_started",
	"battle_joined", "battle_fought", "battle_ended", "siege_started", "siege_progress", "siege_lifted"]


## Explored = the start (new_scenario only; R11): each country's land sight OR the hexes of its scenario regions (R6).
## Called by reference from Game.new_scenario.
static func setup(game: Game) -> void:
	if not _ready(game):
		return
	for c: Country in game.countries:
		if c != null:
			game.sight.forget_land(c.id)  # the land of the start, never a land cached before it
			var bits := game.sight.land_of(game, c.id).duplicate()
			var start := _start_of(game, c)
			for k: int in mini(start.size(), bits.size()):
				bits[k] = bits[k] | start[k]
			c.explored = bits
			game.sight.grew(c.id)


## The scenario's start discovery of `c` (R6) as an explored bitset: empty when the game has no scenario regions. The
## scenario gives one byte a hex (ScenarioDef.discovery_of, FG1), read here into bits.
static func _start_of(game: Game, c: Country) -> PackedByteArray:
	var n := game.map.hex_count()
	var bits := PackedByteArray()
	bits.resize((n + 7) >> 3)
	bits.fill(0)
	if game.scenario == null:
		return bits
	var flags := game.scenario.discovery_of(c.tag)
	for i: int in mini(flags.size(), n):
		if flags[i] != 0:
			bits[i >> 3] = bits[i >> 3] | (1 << (i & 7))
	return bits


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


## True when `tag` sees `hex` now: it controls the hex or a hex within the land sight of it (R13), or an army of its sees it.
static func sees(game: Game, tag: StringName, hex: Vector2i) -> bool:
	if not _ready(game) or tag == &"":
		return false
	var c := Countries.by_tag(game, tag)
	var i := game.map.index_of(hex)
	if c == null or i < 0:
		return false
	if SightCache.bit_is(game.sight.armies_of(c.id), i):
		return true
	for j: int in SightCache.disc(game.map, i, _land_sight(game)):
		if _controller_at(game, j) == c.id:
			return true
	return false


## The tags that see `hex` (country id order), `actor` among them whether or not it sees it. Read from the hex's disc
## alone (the controllers of its hexes within the land sight, the armies' watchers there, the actor): the same tags `sees`
## gives for every country, without a loop over the countries (at most seven controllers and a few watchers).
static func witnesses_of(game: Game, hex: Vector2i, actor: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	if not _ready(game):
		return out
	var ids: Array[int] = []
	var i := game.map.index_of(hex)
	if i >= 0:
		for j: int in SightCache.disc(game.map, i, _land_sight(game)):
			var ctl := _controller_at(game, j)
			if ctl > 0 and not ids.has(ctl):
				ids.append(ctl)
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


## Called by Game.emit for every event, before it is queued. A land kind is marked `land` and gets no witness list (R30).
## district_captured explores the taker's land at once (R9); owners_changed and controllers_changed explore the new holders'
## land at once and forget the land sight of every country they name (R10, R16, R17). A sighted kind with a hex gets its
## witnesses unless it has some.
static func on_emit(game: Game, event: Dictionary) -> void:
	if not _ready(game):
		return
	var kind := str(event.get("kind", ""))
	if LAND_KINDS.has(kind):
		event["land"] = true
	if kind == "district_captured":
		_captured(game, event)
	elif kind == "owners_changed":
		_owners_changed(game, event)
	elif kind == "controllers_changed":
		_controllers_changed(game, event)
	elif SIGHTED.has(kind) and event.get("hex") is Vector2i and not event.has("witnesses"):
		var actor := StringName(str(event.get("tag", "")))
		event["witnesses"] = _with_others(witnesses_of(game, event["hex"] as Vector2i, actor), event)


## The witnesses of a sighted event: those who see its hex, then the event's `others` (M7 4.14: the actor and the others
## always witness, even when they do not see the hex).
static func _with_others(seen: PackedStringArray, event: Dictionary) -> PackedStringArray:
	var out := seen
	var others: Variant = event.get("others", [])
	if others is Array or others is PackedStringArray:
		for item: Variant in others:
			var tag := str(item)
			if tag != "" and not out.has(tag):
				out.append(tag)
	return out


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


## R9: a district captured is explored by its taker, the hex and its ring, before the event is queued; the land sights of
## the taker and of the countries named are forgotten (their control changed).
static func _captured(game: Game, event: Dictionary) -> void:
	_forget_named(game, event)
	var hex: Variant = event.get("hex")
	if hex is Vector2i:
		_mark_rings(game, StringName(str(event.get("tag", ""))), [hex as Vector2i])


## Owners changed: forget the land sight of the countries named (the gain is explored at once, here, and read from the state
## at the next season), and explore each changed hex and its ring for the new owner (R10).
static func _owners_changed(game: Game, event: Dictionary) -> void:
	_forget_named(game, event)
	_mark_rings(game, StringName(str(event.get("tag", ""))), event.get("hexes", []) as Array)


## Controllers changed (a release at peace, the flush of a phase; R10, R16, R17): forget the land sight of the countries
## named, then explore each changed hex and its ring for the country that controls it now.
static func _controllers_changed(game: Game, event: Dictionary) -> void:
	_forget_named(game, event)
	for hex: Variant in event.get("hexes", []):
		var holder := Countries.by_id(game, Occupation.controller_id(game, hex as Vector2i))
		if holder != null:
			_mark_rings(game, holder.tag, [hex as Vector2i])


## Explores the hex and its land-sight ring of `hexes` for the country `tag` (the R9 and R10 door; through _mark).
static func _mark_rings(game: Game, tag: StringName, hexes: Array) -> void:
	var c := Countries.by_tag(game, tag)
	if c == null:
		return
	var indices := PackedInt32Array()
	for hex: Variant in hexes:
		var i := game.map.index_of(hex as Vector2i)
		if i >= 0:
			indices.append(i)
	_mark(game, c, indices, _land_sight(game))


## Forgets the land sight of the tag and the others an event names (R16).
static func _forget_named(game: Game, event: Dictionary) -> void:
	var names: Array = [str(event.get("tag", ""))]
	for other: Variant in event.get("others", []):
		names.append(str(other))
	for name: Variant in names:
		var c := Countries.by_tag(game, StringName(str(name)))
		if c != null:
			game.sight.forget_land(c.id)


## Sets the explored bits of `c` for each index and its disc of `radius`; the bitset is copied once, then changed in place.
## A set that grew bumps its explored revision and tells the known sets of the bits' controllers (learned).
static func _mark(game: Game, c: Country, indices: PackedInt32Array, radius: int) -> void:
	if c == null or indices.is_empty():
		return
	var bits := _bits_of(game, c)
	var grew := false
	for i: int in indices:
		for j: int in SightCache.disc(game.map, i, radius):
			if ((bits[j >> 3] >> (j & 7)) & 1) == 0:
				bits[j >> 3] = bits[j >> 3] | (1 << (j & 7))
				grew = true
				var ctl := _controller_at(game, j)
				if ctl > 0 and ctl != c.id:
					game.sight.learned(c.id, ctl)
	c.explored = bits
	if grew:
		game.sight.grew(c.id)


## ORs country `c`'s land sight (its cached bitset) into its explored set, when that land sight was made since it was last
## ORed (SightCache.take_fresh: a land that did not change needs no sweep of its bytes). A set that grew drops its known set.
static func _or_land(game: Game, c: Country) -> void:
	var land: PackedByteArray = game.sight.land_of(game, c.id)
	if not game.sight.take_fresh(c.id):
		return
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
		game.sight.grew(c.id)


## The explored bitset of `c`, made empty when its size is not the map's (an in-memory game that never set it up).
static func _bits_of(game: Game, c: Country) -> PackedByteArray:
	var n := (game.map.hex_count() + 7) >> 3
	if c.explored.size() == n:
		return c.explored
	var bits := PackedByteArray()
	bits.resize(n)
	bits.fill(0)
	return bits


## The controller byte of hex index j (fog spec R13): its occupier where one stands, else its owner; 0 at sea and off the map.
static func _controller_at(game: Game, j: int) -> int:
	if j < 0 or j >= game.map.land.size() or game.map.land[j] == 0:
		return 0
	var occ: PackedByteArray = game.state.occupier
	if j < occ.size() and occ[j] != 0:
		return int(occ[j])
	var owner: PackedByteArray = game.state.owner
	return int(owner[j]) if j < owner.size() else 0


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
