## Castle-area lines, the area tint and the held-area read model (docs/architecture/m7-build-spec.md 4.3, 5.6, 6.3, 6.8).
## Pure core/views/ code: no nodes, no engine calls, never writes.
## A hex is in a held area when its fortress stands (its owner holds the fortress, no occupier), the hex is its owner's
## land and no occupier holds the hex. Only the areas of countries at war with the viewer are drawn or tinted; a fallen
## area (its fortress occupied) keeps no line and no tint. Occupation is public (4.15), so nothing here is fogged.
class_name AreaLines
extends RefCounted

const DASH := 6.0
const GAP := 4.0
const WIDTH := 1.6


## One byte per hex: 1 on each held-area hex of a country at war with the viewer (the fortress included). 0 everywhere
## for the viewer "", a game without countries, or no war. Cached in the view cache by [&"area", version, viewer].
static func area_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	if game == null or game.map == null or game.state == null:
		return PackedByteArray()
	var key: Array = [&"area", game.version, viewer]
	return game.view_cache.get_or_make(key, func() -> PackedByteArray: return _make_area_bytes(game, viewer)) as PackedByteArray


static func _make_area_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	var n := game.map.hex_count()
	var out := PackedByteArray()
	out.resize(n)
	out.fill(0)
	if viewer == &"" or not game.has_countries():
		return out
	var areas := game.war_cache.area_index(game)
	var enemies := _enemy_ids(game, viewer)
	if areas.size() != n or enemies.is_empty():
		return out
	var standing := Occupation.standing(game)
	for i: int in n:
		var f := areas[i]
		if f < 0 or standing[f] != 1 or game.state.occupier[i] != 0:
			continue
		if game.map.land[i] == 0 or not enemies.has(int(game.state.owner[i])):
			continue
		out[i] = 1
	return out


## The ids of the countries at war with viewer, as a set (id -> true).
static func _enemy_ids(game: Game, viewer: StringName) -> Dictionary:
	var out: Dictionary = {}
	for tag: StringName in Wars.enemies(game, viewer):
		var c := Countries.by_tag(game, tag)
		if c != null:
			out[c.id] = true
	return out


## The dashed lines of one chunk (EdgeLines.CHUNK cells a side): {kind "area", points [corner, corner] (map px),
## colour_id (the owner's country id), dashed true, dash, gap, width} on every edge of a held-area hex of this chunk whose
## other side is outside that area (the map's edge has none). An edge between two held areas is drawn once, from the lower
## hex index, in that hex's owner's colour; the other hex skips it. So every edge appears exactly once over all chunks.
static func for_chunk(game: Game, viewer: StringName, chunk: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or game.map == null or game.state == null:
		return out
	var map := game.map
	var bytes := area_bytes(game, viewer)
	if bytes.size() != map.hex_count():
		return out
	var areas := game.war_cache.area_index(game)
	var x0 := maxi(chunk.x * EdgeLines.CHUNK, 0)
	var x1 := mini((chunk.x + 1) * EdgeLines.CHUNK, map.cols)
	var y0 := maxi(chunk.y * EdgeLines.CHUNK, 0)
	var y1 := mini((chunk.y + 1) * EdgeLines.CHUNK, map.rows)
	for row: int in range(y0, y1):
		for col: int in range(x0, x1):
			var i := row * map.cols + col
			if bytes[i] == 0:
				continue
			var hex := map.hex_of(i)
			var corners := BorderLines.hex_corners(hex)
			for d: int in 6:
				var other := map.index_of(map.neighbour(hex, d))
				if other < 0:
					continue
				if bytes[other] != 0:
					if areas[other] == areas[i]:
						continue
					if other < i:  # a shared edge of two areas is drawn from its lower index only
						continue
				var pair := HexGrid.EDGE_CORNERS[d]
				out.append({
					"kind": "area",
					"points": PackedVector2Array([corners[pair.x], corners[pair.y]]),
					"colour_id": int(game.state.owner[i]),
					"dashed": true,
					"dash": DASH,
					"gap": GAP,
					"width": WIDTH,
				})
	return out


## The chunks to rebuild when the areas change on `hexes`: each hex's chunk and its neighbours' (BorderLines' rule).
static func chunks_touched(game: Game, hexes: Array[Vector2i]) -> Array[Vector2i]:
	if game == null or game.map == null:
		return []
	return BorderLines.chunks_touched(game.map, hexes)


## What a land hex is in its castle area, for the hex card and the panels: {state (Occupation.area_state: castle, held,
## fallen, open), fortress (Vector2i, Army.NO_HEX for none), name ("the castle of Pavia", "" for none), distance (hex
## steps to the fortress, -1 for none), fallen (bool: the hex's fortress is occupied), members (the area's hex count)}.
static func held_by(game: Game, hex: Vector2i) -> Dictionary:
	var out := {"state": &"open", "fortress": Army.NO_HEX, "name": "", "distance": -1, "fallen": false, "members": 0}
	if game == null or game.map == null or game.state == null or not game.map.has(hex):
		return out
	var standing := Occupation.standing(game)
	out["state"] = Occupation.area_state(game, hex, standing)
	var fortress := Occupation.area_of(game, hex)
	if fortress == Army.NO_HEX:
		return out
	var f := game.map.index_of(fortress)
	out["fortress"] = fortress
	out["name"] = _castle_name(game, fortress)
	out["distance"] = _hex_distance(hex, fortress)
	out["fallen"] = f >= 0 and f < standing.size() and standing[f] == 0
	out["members"] = Occupation.members(game, fortress).size()
	return out


## "the castle of Pavia": the fortress's place name, or the coordinates when it has none.
static func _castle_name(game: Game, fortress: Vector2i) -> String:
	var place_name := str(Improve.place_of(game.map, fortress).get("name", ""))
	if place_name.is_empty():
		return "the castle at (%d, %d)" % [fortress.x, fortress.y]
	return "the castle of " + place_name


## Steps between two hexes of the odd-r grid (cube distance).
static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ca := _cube(a)
	var cb := _cube(b)
	return maxi(maxi(absi(ca.x - cb.x), absi(ca.y - cb.y)), absi(ca.z - cb.z))


static func _cube(h: Vector2i) -> Vector3i:
	var x := h.x - ((h.y - (h.y & 1)) >> 1)
	return Vector3i(x, -x - h.y, h.y)
