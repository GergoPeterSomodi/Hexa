## Map mode colours, height ramp, palette packing, and pixel-to-hex lookup
## (docs/architecture/m2-build-spec.md sections 4.6 and 5.7).
## Pure core/views/ code: no nodes, no engine calls; mirrors mode_overlay.gdshader.
class_name MapModes
extends RefCounted

enum Mode { TERRAIN, OWNER, RELIEF, YIELDS, FOOD, SUPPLY }  # keys 1 to 6
## The values of the setting state/map_mode, by Mode.
const MODE_KEYS: Array[StringName] = [&"terrain", &"owner", &"relief", &"yields", &"food", &"supply"]

## The Supply mode (docs/architecture/m6-build-spec.md 6.6, SupplyView's bytes): bytes 1 to 6 in SUPPLY_COLOURS, 0 the veil.
const SUPPLY_ALPHA := 0.70
## The sight veil over the land nobody of the viewer's sees (A13), laid over every mode when the setting is on.
const SIGHT_VEIL_ALPHA := 0.25
const SUPPLY_COLOURS: Array[Color] = [Color("#a8321a"), Color("#c8664c"), Color("#e2b97a"), Color("#9cb3d6"),
	Color("#4f79b8"), Color("#1f3f7a")]
## The legend's words for bytes 2 to 6 (index byte - 2).
const SUPPLY_WORDS: Array[String] = ["Out of supply, the land feeds a few", "Out of supply, the land feeds an army",
	"In supply until winter", "In supply", "A depot (a village or larger, a port)"]
const SUPPLY_TITLE := "Supply: where your armies are fed"
const SUPPLY_STARVING := "Out of supply, starving"

const TINT_ALPHA := 0.14
const OWNER_ALPHA := 0.55
const RELIEF_ALPHA := 0.65
const HOT_ALPHA := 0.20
const HOT_LIGHTEN := 0.15
const PALETTE_SIZE := 256
const HEIGHT_STEP_M := 16
const HEIGHT_STEP_SHIFT := 4  # HEIGHT_STEP_M is 1 << 4
const RELIEF_STOPS: Array[Array] = [
	[0, Color("#4f8a4a")],
	[150, Color("#79a557")],
	[400, Color("#b7b56a")],
	[800, Color("#c49a5c")],
	[1300, Color("#a2744c")],
	[1900, Color("#8e7f74")],
	[2500, Color("#c9c7c4")],
	[3200, Color("#f4f5f8")],
]

## The Yields mode (docs/architecture/m4-5-build-spec.md 4.8): your land in nine bands of its worth a year.
const YIELD_ALPHA := 0.70
const VEIL := Color("#1c140d")
const VEIL_ALPHA := 0.45
## The deep fog (R36, D17): one flat opaque fill over every hex the viewer has not discovered, in every mode. A placeholder:
## the final art comes with the map track. Owners, sea, marks and the veil are not drawn under it.
const DEEP_FOG_COLOUR := Color("#3d362d")
const STRIPE_PX := 6.0

## The occupied land (M7, 6.3): diagonal bands of the occupier's colour, OCCUPIED_STRIPE_PX wide along x + y, alternating
## with the owner's; the shader draws the bands (stripe_is_occupier says which band a pixel is in). AREA_ALPHA is the tint of
## a castle area of an enemy (AreaLines), in the owner's colour.
const OCCUPIED_STRIPE_PX := 8.0
const AREA_ALPHA := 0.12
## The worth a year that starts bytes 3 to 9.
const YIELD_FLOORS: PackedInt32Array = [1, 10, 25, 50, 100, 200, 400]
## Bytes 1 (a loss, madder) to 9.
const YIELD_COLOURS: Array[Color] = [Color("#a8321a"), Color("#efe3c4"), Color("#d9d3a0"), Color("#b5c98a"),
	Color("#86b37a"), Color("#4f9a6e"), Color("#2a7d63"), Color("#12605a"), Color("#0b3f3c")]
## The legend's words for bytes 2 to 9.
const YIELD_WORDS: Array[String] = ["Nothing", "1 to 9", "10 to 24", "25 to 49", "50 to 99", "100 to 199", "200 to 399",
	"400 and more"]

## The Food mode (docs/architecture/m5-build-spec.md 5.6, 6.5): your land in eight bands of the food it makes less the food
## its people eat a year.
const FOOD_ALPHA := 0.70
## The net food a year that starts bytes 4 to 8.
const FOOD_FLOORS: PackedInt32Array = [1, 5, 10, 20, 40]
## At or under this net food a year: byte 1.
const FOOD_DEFICIT := -10
## Bytes 1 (short by 10 or more, madder) to 8.
const FOOD_COLOURS: Array[Color] = [Color("#8e2a17"), Color("#c8664c"), Color("#efe3c4"), Color("#ead68f"),
	Color("#d4bc4e"), Color("#a7a03a"), Color("#6b8b4a"), Color("#35665e")]
## The legend's words for bytes 3 to 8.
const FOOD_WORDS: Array[String] = ["Nothing", "1 to 4", "5 to 9", "10 to 19", "20 to 39", "40 and more"]
const FOOD_SEASONS := 4

const DEFAULT_UNOWNED :=Color("#d8ccb0")
## The works card's tint (Tokens.GOOD and Tokens.BAD, whose values these are: a view does not read the shell).
const DELTA_GOOD := Color("#7fc98a")
const DELTA_BAD := Color("#f0806a")
const DELTA_ALPHA := 0.35

static var _cached_ramp := PackedColorArray()
static var _cached_yield_ramp := PackedColorArray()
static var _cached_food_ramp := PackedColorArray()
static var _cached_supply_ramp := PackedColorArray()


## The Mode of a state/map_mode value; -1 when unknown.
static func mode_of(key: StringName) -> int:
	return MODE_KEYS.find(key)


## The band (byte 1 to 9) of a worth a year: 1 under 0, 2 for 0, 3 to 9 from YIELD_FLOORS.
static func yield_band(year: int) -> int:
	if year < 0:
		return 1
	var band := 2
	for floor_value: int in YIELD_FLOORS:
		if year >= floor_value:
			band += 1
	return band


## One byte a hex (index = row * cols + col): the band of your land hex's worth over the next four seasons; 0 on every
## other hex (sea, unowned, another country's: their worth is theirs to know). All 0 for no viewer or an unknown one.
## Cached in the game's view cache by [&"yields", version, viewer].
static func yield_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	if game == null or game.map == null:
		return PackedByteArray()
	var key: Array = [&"yields", game.version, viewer]
	return game.view_cache.get_or_make(key, func() -> PackedByteArray: return _make_yield_bytes(game, viewer)) as PackedByteArray


static func _make_yield_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(game.map.hex_count())  # zero
	if viewer == &"" or not game.has_countries():
		return out
	var worth := EconomyPreview.worth_seasons_shared(game, viewer, 4)
	var hexes: PackedInt32Array = worth["hexes"]
	var values: PackedInt32Array = worth["worth"]
	var seasons := int(worth["seasons"])
	for h: int in hexes.size():
		var year := 0
		for k: int in seasons:
			year += values[h * seasons + k]
		out[hexes[h]] = yield_band(year)
	return out


## The food (made, eaten) a year on the viewer's land hex: the grain and fish EconomyPreview.worth_seasons_shared works out
## for it over four seasons; eaten = its people now x food_need_milli x 4 / 1,000,000 (floored) for a settlement, else 0.
## (0, 0) on any other hex (sea, another country's, off the map), for no viewer or a game without countries.
static func food_year(game: Game, viewer: StringName, hex: Vector2i) -> Vector2i:
	if game == null or game.map == null or viewer == &"" or not game.has_countries():
		return Vector2i.ZERO
	var i := game.map.index_of(hex)
	if i < 0:
		return Vector2i.ZERO
	var worth := EconomyPreview.worth_seasons_shared(game, viewer, FOOD_SEASONS)
	var hexes: PackedInt32Array = worth["hexes"]
	var h := hexes.bsearch(i)
	if h >= hexes.size() or hexes[h] != i:
		return Vector2i.ZERO
	return _food_of(game, worth, h, i)


static func _food_of(game: Game, worth: Dictionary, h: int, i: int) -> Vector2i:
	var goods: PackedInt32Array = worth["goods"]
	var seasons := int(worth["seasons"])
	var goods_n := game.defs.goods.size()
	var made := 0
	for k: int in seasons:
		var o := (h * seasons + k) * goods_n
		made += goods[o + Economy.GRAIN] + goods[o + Economy.FISH]
	var eaten := 0
	if game.state.main_use[i] == Economy.SETTLEMENTS:
		@warning_ignore("integer_division")
		eaten = game.state.people[i] * game.defs.food_need_milli * FOOD_SEASONS / 1000000
	return Vector2i(made, eaten)


## The band (byte 1 to 8) of a net food a year: 1 at or under FOOD_DEFICIT, 2 below 0, 3 for 0, 4 to 8 from FOOD_FLOORS.
static func food_band(net: int) -> int:
	if net <= FOOD_DEFICIT:
		return 1
	if net < 0:
		return 2
	var band := 3
	for floor_value: int in FOOD_FLOORS:
		if net >= floor_value:
			band += 1
	return band


## One byte a hex (index = row * cols + col): food_band of made less eaten on your land; 0 on every other hex. All 0 for
## no viewer or an unknown one. Cached in the game's view cache by [&"food", version, viewer].
static func food_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	if game == null or game.map == null:
		return PackedByteArray()
	var key: Array = [&"food", game.version, viewer]
	return game.view_cache.get_or_make(key, func() -> PackedByteArray: return _make_food_bytes(game, viewer)) as PackedByteArray


static func _make_food_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(game.map.hex_count())  # zero
	if viewer == &"" or not game.has_countries():
		return out
	var worth := EconomyPreview.worth_seasons_shared(game, viewer, FOOD_SEASONS)
	var hexes: PackedInt32Array = worth["hexes"]
	for h: int in hexes.size():
		var food := _food_of(game, worth, h, hexes[h])
		out[hexes[h]] = food_band(food.x - food.y)
	return out


## 256-entry colours by Food byte: [0] clear, [1..8] FOOD_COLOURS, the rest clear.
static func food_ramp() -> PackedColorArray:
	if _cached_food_ramp.size() != PALETTE_SIZE:
		_cached_food_ramp.resize(PALETTE_SIZE)
		_cached_food_ramp.fill(Color(0.0, 0.0, 0.0, 0.0))
		for b: int in FOOD_COLOURS.size():
			_cached_food_ramp[b + 1] = FOOD_COLOURS[b]
	return _cached_food_ramp.duplicate()


## One byte a hex of the viewer's Supply mode (SupplyView.bytes, 6.6). Pinned in the view cache (R3 d): a whole-map array is
## not kept under the version. Keyed by the season, the owners, the settlements, the levels and the people.
static func supply_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	if game == null or game.map == null or game.state == null:
		return PackedByteArray()
	var key: Array = [&"supply", viewer, game.turn, hash(game.state.owner), hash(game.state.main_use),
		hash(game.state.level), hash(game.state.people), game.map.hex_count()]
	return game.view_cache.pinned(&"supply_bytes", key, func() -> PackedByteArray: return SupplyView.bytes(game, viewer)) as PackedByteArray


## One byte a hex: 1 where the viewer sees it, 0 where not (land only matters to the veil). Pinned by the sight revision
## (R3 d). Everything is seen for the viewer "" and for a game without countries; nothing for a country with no sight.
static func sight_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	if game == null or game.map == null or game.state == null:
		return PackedByteArray()
	var key: Array = [&"sight", viewer, game.sight.revision(), hash(game.state.owner), game.map.hex_count()]
	return game.view_cache.pinned(&"sight_bytes", key, func() -> PackedByteArray: return _make_sight_bytes(game, viewer)) as PackedByteArray


static func _make_sight_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	var n := game.map.hex_count()
	var out := PackedByteArray()
	out.resize(n)
	if viewer == &"" or not game.has_countries():
		out.fill(1)
		return out
	out.fill(0)
	var c := Countries.by_tag(game, viewer)
	if c == null:
		return out
	var land: PackedByteArray = game.sight.land_of(game, c.id)
	var armies: PackedByteArray = game.sight.armies_of(c.id)
	for i: int in n:
		if SightCache.bit_is(land, i) or SightCache.bit_is(armies, i):
			out[i] = 1
	return out


## One byte a hex: 1 where the viewer has discovered it (R36, D1: explored, or in sight now), 0 under deep fog. All 1 for the
## viewer "" and for a game without countries. Pinned by discovered_key (the viewer's explored revision and the sight revision).
static func discovered_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	if game == null or game.map == null or game.state == null:
		return PackedByteArray()
	return game.view_cache.pinned(&"discovered_bytes", discovered_key(game, viewer),
		func() -> PackedByteArray: return _make_discovered_bytes(game, viewer)) as PackedByteArray


## The key of discovered_bytes, which the overlay's deep-fog texture compares too: it moves when the viewer's explored set
## grows or its sight moves.
static func discovered_key(game: Game, viewer: StringName) -> Array:
	var rev := -1
	if viewer != &"" and game.has_countries():
		var c := Countries.by_tag(game, viewer)
		if c != null:
			rev = game.sight.explored_revision(c.id)
	return [&"discovered", viewer, rev, game.sight.revision(), game.map.hex_count()]


static func _make_discovered_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	var n := game.map.hex_count()
	var out := PackedByteArray()
	out.resize(n)
	if viewer == &"" or not game.has_countries():
		out.fill(1)
		return out
	out.fill(0)
	var c := Countries.by_tag(game, viewer)
	if c == null:
		return out
	var bits: PackedByteArray = game.sight.discovered_of(game, c.id)
	for i: int in n:
		out[i] = (bits[i >> 3] >> (i & 7)) & 1
	return out


## 256-entry colours by Supply byte: [0] clear, [1..6] SUPPLY_COLOURS, the rest clear.
static func supply_ramp() -> PackedColorArray:
	if _cached_supply_ramp.size() != PALETTE_SIZE:
		_cached_supply_ramp.resize(PALETTE_SIZE)
		_cached_supply_ramp.fill(Color(0.0, 0.0, 0.0, 0.0))
		for b: int in SUPPLY_COLOURS.size():
			_cached_supply_ramp[b + 1] = SUPPLY_COLOURS[b]
	return _cached_supply_ramp.duplicate()


## 256-entry colours by Yields byte: [0] clear, [1..9] YIELD_COLOURS, the rest clear.
static func yield_ramp() -> PackedColorArray:
	if _cached_yield_ramp.size() != PALETTE_SIZE:
		_cached_yield_ramp.resize(PALETTE_SIZE)
		_cached_yield_ramp.fill(Color(0.0, 0.0, 0.0, 0.0))
		for b: int in YIELD_COLOURS.size():
			_cached_yield_ramp[b + 1] = YIELD_COLOURS[b]
	return _cached_yield_ramp.duplicate()


## The legend's title of a mode; "" for the modes without a legend.
static func legend_title(mode: int) -> String:
	match mode:
		Mode.YIELDS:
			return "Yields: worth a year"
		Mode.FOOD:
			return "Food: made less eaten, a year"
		Mode.SUPPLY:
			return SUPPLY_TITLE
	return ""


## The legend rows of a mode: for YIELDS [{colour, text, stripes}], the top byte first, then "A loss" and "Not your land";
## for FOOD the bands top first, the two shortfalls striped, then "Not your land"; [] for the other modes.
static func legend(mode: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if mode == Mode.SUPPLY:
		for b: int in range(6, 1, -1):
			out.append({"colour": SUPPLY_COLOURS[b - 1], "text": SUPPLY_WORDS[b - 2], "stripes": false})
		out.append({"colour": SUPPLY_COLOURS[0], "text": SUPPLY_STARVING, "stripes": true})
		out.append({"colour": VEIL, "text": "Not your land", "stripes": false})
		return out
	if mode == Mode.FOOD:
		for b: int in range(8, 2, -1):
			out.append({"colour": FOOD_COLOURS[b - 1], "text": FOOD_WORDS[b - 3], "stripes": false})
		out.append({"colour": FOOD_COLOURS[1], "text": "Short by 1 to 9", "stripes": true})
		out.append({"colour": FOOD_COLOURS[0], "text": "Short by 10 or more", "stripes": true})
		out.append({"colour": VEIL, "text": "Not your land", "stripes": false})
		return out
	if mode != Mode.YIELDS:
		return out
	for b: int in range(9, 1, -1):
		out.append({"colour": YIELD_COLOURS[b - 1], "text": YIELD_WORDS[b - 2], "stripes": false})
	out.append({"colour": YIELD_COLOURS[0], "text": "A loss", "stripes": true})
	out.append({"colour": VEIL, "text": "Not your land", "stripes": false})
	return out


## The card's tint of a change in ducats a year: DELTA_GOOD at a gain, DELTA_BAD at a loss, alpha 0.35; no tint (clear)
## for no change.
static func delta_colour(delta: int) -> Color:
	if delta == 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var base := DELTA_GOOD if delta > 0 else DELTA_BAD
	return Color(base.r, base.g, base.b, DELTA_ALPHA)


## The cell under a map pixel, matching TileMapLayer.local_to_map and mode_overlay.gdshader.
static func hex_at_px(px: Vector2) -> Vector2i:
	var half_w := float(MapTiles.CELL.x) * 0.5
	var half_h := float(MapTiles.CELL.y) * 0.5
	var ux := px.x - half_w
	var uy := px.y - half_h
	var r := uy / MapTiles.ROW
	var q := ux / float(MapTiles.CELL.x) - 0.5 * r
	var s := -q - r
	var rq := floorf(q + 0.5)
	var rr := floorf(r + 0.5)
	var rs := floorf(s + 0.5)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	var row := int(rr)
	var col := int(rq) + ((row - (row & 1)) >> 1)
	return Vector2i(col, row)


## Encodes each hex's elevation as 1 byte (0 = sea, 1..255 = 1 + clampi(height_m / 16, 0, 254)).
static func height_bytes(map: MapData) -> PackedByteArray:
	if map == null:
		return PackedByteArray()
	var n := map.hex_count()
	var out := PackedByteArray()
	out.resize(n)  # zero: sea
	var land := map.land
	var heights := map.height_m
	for i: int in n:  # (a shift floors a negative height as floori does)
		if land[i] != 0:
			out[i] = 1 + clampi(heights[i] >> HEIGHT_STEP_SHIFT, 0, 254)
	return out


## 256-entry colour ramp indexed by height byte (0 = transparent sea, 1..255 = elevation stops).
static func relief_ramp() -> PackedColorArray:
	return _ramp().duplicate()


## Packs a 256-entry palette: index 0 is unowned, index id (1..255) is colours[id - 1].
static func palette_from(colours: PackedColorArray, unowned: Color) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(PALETTE_SIZE)
	out.fill(Color(0.0, 0.0, 0.0, 0.0))
	out[0] = unowned
	var count := mini(colours.size(), PALETTE_SIZE - 1)
	for i: int in count:
		out[i + 1] = colours[i]
	return out


## Fragment colour for one (owner_id, height_byte) pair; matches mode_overlay.gdshader.
## The sight veil (A13): with `veil_on` and `seen` 0 on land, the veil goes over the mode's colour by source-over, unless the
## mode already drew its own veil (byte 0 of Yields, Food or Supply).
## The occupier (M7): `occupier_id` > 0 and not the owner paints the occupier's palette colour over the owner's in Owner mode
## and the Terrain tint (the band choice is the shader's, stripe_is_occupier). `area_byte` 1 tints the owner's colour over
## the hex at AREA_ALPHA (a held castle area of an enemy) in the land modes. Both default to none.
static func colour_of(mode: int, owner_id: int, height_byte: int, palette: PackedColorArray,
		tint_on: bool, hot_id: int, yield_byte: int = 0, food_byte: int = 0, supply_byte: int = 0,
		seen: int = 1, veil_on: bool = false, occupier_id: int = 0, area_byte: int = 0, discovered: int = 1) -> Color:
	if discovered <= 0:  # R36: under deep fog, whatever the rest says
		return DEEP_FOG_COLOUR
	if height_byte <= 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var c := _mode_colour(mode, owner_id, height_byte, palette, tint_on, hot_id, yield_byte, food_byte, supply_byte)
	c = _occupied_colour(c, mode, owner_id, palette, tint_on, occupier_id)
	c = _area_tint(c, mode, owner_id, palette, area_byte)
	if veil_on and seen == 0 and not _veil_by_mode(mode, yield_byte, food_byte, supply_byte):
		return _veiled(c)
	return c


## The occupier's colour in place of the owner's (alpha kept) in Owner mode and the Terrain tint; `c` otherwise.
static func _occupied_colour(c: Color, mode: int, owner_id: int, palette: PackedColorArray, tint_on: bool,
		occupier_id: int) -> Color:
	if occupier_id <= 0 or occupier_id == owner_id or occupier_id >= palette.size():
		return c
	if mode == Mode.OWNER or (mode == Mode.TERRAIN and tint_on):
		var oc := palette[occupier_id]
		return Color(oc.r, oc.g, oc.b, c.a)
	return c


## The castle-area tint: the owner's colour at AREA_ALPHA over `c` in the land modes (Yields, Food and Supply keep their own).
static func _area_tint(c: Color, mode: int, owner_id: int, palette: PackedColorArray, area_byte: int) -> Color:
	if area_byte <= 0 or owner_id <= 0 or owner_id >= palette.size():
		return c
	if mode == Mode.YIELDS or mode == Mode.FOOD or mode == Mode.SUPPLY:
		return c
	var oc := palette[owner_id]
	return _over(Color(oc.r, oc.g, oc.b, AREA_ALPHA), c)


## True when a pixel (x, y) is in an occupier band of the occupied stripes (the bands alternate every OCCUPIED_STRIPE_PX
## along x + y, the occupier's on the even bands).
static func stripe_is_occupier(px: int, py: int) -> bool:
	return posmod(floori(float(px + py) / OCCUPIED_STRIPE_PX), 2) == 0


## One byte a hex: the occupier's country id from MapState.occupier (0 for none). Public (4.15): the map shows it to all.
static func occupier_bytes(game: Game) -> PackedByteArray:
	if game == null or game.state == null:
		return PackedByteArray()
	return game.state.occupier


## The castle-area bytes of `viewer` (AreaLines.area_bytes): 1 on the held-area hexes of the viewer's enemies.
static func area_bytes(game: Game, viewer: StringName) -> PackedByteArray:
	return AreaLines.area_bytes(game, viewer)


## The legend rows of the occupied land and the castle areas, for Owner and Terrain: [{text, stripes, area}]. The stripe row
## has no colour of its own (the occupier's colour is the country's); the area row is the dashed line.
static func occupied_legend() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"text": "Held by another country: stripes in its colour", "stripes": true, "area": false})
	out.append({"text": "Castle area of an enemy: dashed line, tinted", "stripes": false, "area": true})
	return out


## True when the mode draws the veil itself at this byte (Yields, Food or Supply at 0 or past its colours).
static func _veil_by_mode(mode: int, yield_byte: int, food_byte: int, supply_byte: int) -> bool:
	match mode:
		Mode.YIELDS:
			return yield_byte <= 0 or yield_byte > YIELD_COLOURS.size()
		Mode.FOOD:
			return food_byte <= 0 or food_byte > FOOD_COLOURS.size()
		Mode.SUPPLY:
			return supply_byte <= 0 or supply_byte > SUPPLY_COLOURS.size()
	return false


## The sight veil laid over `c` by source-over: a = av + am (1 - av), rgb = (VEIL av + c am (1 - av)) / a.
static func _veiled(c: Color) -> Color:
	return _over(Color(VEIL.r, VEIL.g, VEIL.b, SIGHT_VEIL_ALPHA), c)


## `top` laid over `bottom` by source-over (straight alpha); clear when both are clear.
static func _over(top: Color, bottom: Color) -> Color:
	var a := top.a + bottom.a * (1.0 - top.a)
	if a <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var r := (top.r * top.a + bottom.r * bottom.a * (1.0 - top.a)) / a
	var g := (top.g * top.a + bottom.g * bottom.a * (1.0 - top.a)) / a
	var b := (top.b * top.a + bottom.b * bottom.a * (1.0 - top.a)) / a
	return Color(r, g, b, a)


static func _mode_colour(mode: int, owner_id: int, height_byte: int, palette: PackedColorArray,
		tint_on: bool, hot_id: int, yield_byte: int, food_byte: int, supply_byte: int) -> Color:
	if mode == Mode.SUPPLY:  # no hover highlight: the colour says the supply
		if supply_byte <= 0 or supply_byte > SUPPLY_COLOURS.size():
			return Color(VEIL.r, VEIL.g, VEIL.b, VEIL_ALPHA)
		var sc := SUPPLY_COLOURS[supply_byte - 1]
		return Color(sc.r, sc.g, sc.b, SUPPLY_ALPHA)
	if mode == Mode.YIELDS:  # no hover highlight: the colour says the worth
		if yield_byte <= 0 or yield_byte > YIELD_COLOURS.size():
			return Color(VEIL.r, VEIL.g, VEIL.b, VEIL_ALPHA)
		var c := YIELD_COLOURS[yield_byte - 1]
		return Color(c.r, c.g, c.b, YIELD_ALPHA)
	if mode == Mode.FOOD:  # likewise
		if food_byte <= 0 or food_byte > FOOD_COLOURS.size():
			return Color(VEIL.r, VEIL.g, VEIL.b, VEIL_ALPHA)
		var fc := FOOD_COLOURS[food_byte - 1]
		return Color(fc.r, fc.g, fc.b, FOOD_ALPHA)
	var base := Color(0.0, 0.0, 0.0, 0.0)
	var alpha := 0.0
	match mode:
		Mode.TERRAIN:
			if not tint_on or owner_id <= 0 or owner_id >= palette.size():
				return Color(0.0, 0.0, 0.0, 0.0)
			base = palette[owner_id]
			alpha = TINT_ALPHA
		Mode.OWNER:
			if owner_id < 0 or owner_id >= palette.size():
				return Color(0.0, 0.0, 0.0, 0.0)
			base = palette[owner_id]
			alpha = OWNER_ALPHA
		Mode.RELIEF:
			var ramp := _ramp()
			base = ramp[clampi(height_byte, 0, PALETTE_SIZE - 1)]
			alpha = RELIEF_ALPHA
		_:
			return Color(0.0, 0.0, 0.0, 0.0)
	if hot_id > 0 and owner_id == hot_id:
		base = base.lerp(Color.WHITE, HOT_LIGHTEN)
		alpha += HOT_ALPHA
	return Color(base.r, base.g, base.b, alpha)


## Available map modes for `game`: `[TERRAIN, OWNER, RELIEF]`, omitting `OWNER` in a map-only game, and adding `YIELDS`, `FOOD`
## and `SUPPLY` when the game has countries and a chosen player.
static func modes(game: Game) -> Array[int]:
	if game != null and game.has_countries():
		if game.player != &"":
			return [Mode.TERRAIN, Mode.OWNER, Mode.RELIEF, Mode.YIELDS, Mode.FOOD, Mode.SUPPLY]
		return [Mode.TERRAIN, Mode.OWNER, Mode.RELIEF]
	return [Mode.TERRAIN, Mode.RELIEF]


## 256-entry palette for `game` using standard country colours or colour-blind safe colours.
static func palette(game: Game, colour_blind: bool) -> PackedColorArray:
	if game == null or game.defs == null:
		return palette_from(PackedColorArray(), DEFAULT_UNOWNED)
	if not game.has_countries() or game.scenario == null:
		return palette_from(PackedColorArray(), game.defs.unowned_colour)
	return palette_from(game.scenario.colours(game.defs, colour_blind), game.defs.unowned_colour)


## Overlay colour for `hex` in `game`, matching `colour_of` and `mode_overlay.gdshader`.
static func colour_at(game: Game, mode: int, hex: Vector2i, pal: PackedColorArray,
		tint_on: bool, hot_id: int, veil_on: bool = false) -> Color:
	if game == null or game.map == null or not game.map.has(hex):
		return Color(0.0, 0.0, 0.0, 0.0)
	var idx := game.map.index_of(hex)
	var height_byte := _height_byte_at(game.map, idx)
	var oid := Territory.owner_id(game, hex)
	var yield_byte := 0
	if mode == Mode.YIELDS and height_byte > 0:
		var bytes := yield_bytes(game, game.player)
		yield_byte = int(bytes[idx]) if idx < bytes.size() else 0
	var food_byte := 0
	if mode == Mode.FOOD and height_byte > 0:
		var fbytes := food_bytes(game, game.player)
		food_byte = int(fbytes[idx]) if idx < fbytes.size() else 0
	var supply_byte := 0
	if mode == Mode.SUPPLY and height_byte > 0:
		var sbytes := supply_bytes(game, game.player)
		supply_byte = int(sbytes[idx]) if idx < sbytes.size() else 0
	var seen := 1
	if veil_on and height_byte > 0:
		var seen_bytes := sight_bytes(game, game.player)
		seen = int(seen_bytes[idx]) if idx < seen_bytes.size() else 0
	var occupier_id := 0
	var area_byte := 0
	if height_byte > 0:
		occupier_id = int(game.state.occupier[idx]) if idx < game.state.occupier.size() else 0
		var abytes := area_bytes(game, game.player)
		area_byte = int(abytes[idx]) if idx < abytes.size() else 0
	var discovered := 1
	var dbytes := discovered_bytes(game, game.player)
	if idx < dbytes.size():
		discovered = int(dbytes[idx])
	return colour_of(mode, oid, height_byte, pal, tint_on, hot_id, yield_byte, food_byte, supply_byte, seen, veil_on,
		occupier_id, area_byte, discovered)


static func _height_byte_at(map: MapData, idx: int) -> int:
	if map.land[idx] == 0:
		return 0
	return 1 + clampi(floori(float(map.height_m[idx]) / float(HEIGHT_STEP_M)), 0, 254)


static func _ramp() -> PackedColorArray:
	if _cached_ramp.size() == PALETTE_SIZE:
		return _cached_ramp
	_cached_ramp.resize(PALETTE_SIZE)
	_cached_ramp[0] = Color(0.0, 0.0, 0.0, 0.0)
	for b: int in range(1, PALETTE_SIZE):
		_cached_ramp[b] = _colour_at_metres((b - 1) * HEIGHT_STEP_M)
	return _cached_ramp


static func _colour_at_metres(metres: int) -> Color:
	var last_idx := RELIEF_STOPS.size() - 1
	if metres <= int(RELIEF_STOPS[0][0]):
		return RELIEF_STOPS[0][1] as Color
	for i: int in range(1, RELIEF_STOPS.size()):
		var hi_m := int(RELIEF_STOPS[i][0])
		if metres <= hi_m:
			var lo_m := int(RELIEF_STOPS[i - 1][0])
			var lo_c := RELIEF_STOPS[i - 1][1] as Color
			var hi_c := RELIEF_STOPS[i][1] as Color
			var t := float(metres - lo_m) / float(hi_m - lo_m)
			return lo_c.lerp(hi_c, t)
	return RELIEF_STOPS[last_idx][1] as Color
