## The door's derived cache of sight (docs/architecture/m6-build-spec.md 5.0 R3, R4, 5.3): per country the land sight (a
## bitset, made lazily), the army part (a bitset per country and the watchers of each hex), and what each viewer has
## learned (256 bytes by country id). Not saved, not in the digest; a load starts with an empty cache. Written only by
## Sight (through Game's emit and the vision phase).
## Bit order: hex i is bit (i & 7) of byte (i >> 3).
class_name SightCache
extends RefCounted

## Tag id -> PackedByteArray: the land sight of a country (held hexes and their rings).
var _land: Dictionary = {}
## Tag id -> PackedByteArray: the hexes the country's armies see.
var _armies: Dictionary = {}
## Hex index -> PackedStringArray: the tags whose armies see it (in no order; witnesses sort by country id).
var watchers: Dictionary = {}
## Viewer id -> PackedByteArray(256): 1 for each country the viewer has explored land of.
var _known: Dictionary = {}
var _revision := 0
## Tag id -> true while a land sight made by land_of has not been ORed into explored yet (take_fresh reads and clears it).
var _fresh: Dictionary = {}
## Offsets of a disc by radius and row parity, made once (a derived table, never saved).
static var _tables: Dictionary = {}


## Grows on every refresh of the army part and every forgotten land.
func revision() -> int:
	return _revision


## The land sight of country `tag_id` as a bitset: its held hexes and every hex within the land sight of them. Made on
## the first ask and kept until its land changes (forget_land). Nothing is made for a country that asks for nothing.
func land_of(game: Game, tag_id: int) -> PackedByteArray:
	if _land.has(tag_id):
		return _land[tag_id]
	var n := game.map.hex_count()
	var bits := PackedByteArray()
	bits.resize((n + 7) >> 3)
	bits.fill(0)
	var radius := _land_sight(game)
	for i: int in Territory.districts(game, tag_id):
		for j: int in disc(game.map, i, radius):
			bits[j >> 3] = bits[j >> 3] | (1 << (j & 7))
	_land[tag_id] = bits
	_fresh[tag_id] = true
	return bits


## True once for each land sight made since its last take: the vision phase ORs only those into explored (5.0 R4). A land
## that did not change was ORed when it was made, so its bits are never ORed again; a loaded game has none made yet, so
## its first vision phase ORs every country's land (explored holds the land sight of every save).
func take_fresh(tag_id: int) -> bool:
	var was: bool = _fresh.get(tag_id, false)
	_fresh.erase(tag_id)
	return was


## The army part of country `tag_id`: a bitset, or an empty array when no army of it stands anywhere.
func armies_of(tag_id: int) -> PackedByteArray:
	return _armies.get(tag_id, PackedByteArray())


## Replaces the army part (Sight.refresh): one bitset per country and the watchers of each hex.
func set_army_part(bits_by_tag: Dictionary, watch: Dictionary) -> void:
	_armies = bits_by_tag
	watchers = watch
	_revision += 1


## Drops the land sight of a country and every viewer's known set (any owner may have changed).
func forget_land(tag_id: int) -> void:
	_land.erase(tag_id)
	_known.clear()
	_revision += 1


## Drops the known set of one viewer (its explored bits grew by a season's sweep; it is made again on the next ask).
func forget_known(viewer_id: int) -> void:
	_known.erase(viewer_id)


## Drops everything (a new game or a replaced state).
func clear() -> void:
	_land.clear()
	_fresh.clear()
	_armies.clear()
	watchers.clear()
	_known.clear()
	_revision += 1


## The 256 bytes of what `viewer_id` has explored: 1 for each country that holds a hex the viewer explored. Made on the
## first ask after a change of land; SightCache.learned keeps it up to date as the explored bits grow.
func known_of(game: Game, viewer_id: int) -> PackedByteArray:
	if _known.has(viewer_id):
		return _known[viewer_id]
	var out := PackedByteArray()
	out.resize(256)
	out.fill(0)
	var viewer := Countries.by_id(game, viewer_id)
	var n := game.map.hex_count()
	if viewer != null and viewer.explored.size() == (n + 7) >> 3:
		var seen: PackedByteArray = viewer.explored
		for id: int in range(1, game.countries.size() + 1):
			for i: int in Territory.districts(game, id):
				if ((seen[i >> 3] >> (i & 7)) & 1) == 1:
					out[id] = 1
					break
	_known[viewer_id] = out
	return out


## Notes that `viewer_id` explored a hex that `owner_id` holds, when its known set is made.
func learned(viewer_id: int, owner_id: int) -> void:
	if not _known.has(viewer_id) or owner_id <= 0 or owner_id > 255:
		return
	var out: PackedByteArray = _known[viewer_id]
	out[owner_id] = 1
	_known[viewer_id] = out


## The hexes within `radius` of hex `index` on `map` (the map's own edge cut off), in no particular order.
static func disc(map: MapData, index: int, radius: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var hex := map.hex_of(index)
	var table := _table(radius, hex.y & 1)
	for d: Vector2i in table:
		var cell := hex + d
		if cell.x >= 0 and cell.y >= 0 and cell.x < map.cols and cell.y < map.rows:
			out.append(cell.y * map.cols + cell.x)
	return out


## The offsets within `radius` of an origin in a row of this parity: the hex distance of ImproveRules (odd rows shifted).
static func _table(radius: int, parity: int) -> Array[Vector2i]:
	var key := radius * 2 + parity
	if _tables.has(key):
		return _tables[key]
	var origin := Vector2i(0, parity)
	var out: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius - 2, radius + 3):
			var offset := Vector2i(dx, dy)
			if ImproveRules.hex_distance(origin, origin + offset) <= radius:
				out.append(offset)
	_tables[key] = out
	return out


## The land sight radius of the game's rules (1 when it has no definitions).
static func _land_sight(game: Game) -> int:
	return game.defs.land_sight if game.defs != null else 1


## True when bit `i` of `bits` is set; false past the end.
static func bit_is(bits: PackedByteArray, i: int) -> bool:
	return (i >> 3) < bits.size() and ((bits[i >> 3] >> (i & 7)) & 1) == 1
