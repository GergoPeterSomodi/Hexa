## Code-drawn picture of a settlement or castle for the tile window's postcard header
## (docs/architecture/tilewin-build-spec.md R28, R29, D15; TW8).
##
## `recipe()` is pure: the same input gives the same recipe (no luck, no clock, no node state). `_draw()` only walks the
## recipe. The recipe is laid out in a logical 296 x 72 box and scaled to the Control's rect, so the picture stays sharp
## at scale 2. Flat two-tone faces (lit left, shaded right), ink outlines, and colours only from `Tokens`. The box is scaled by
## the Control's WIDTH, the same on both axes, and stands on the Control's foot: the whole scene shows, and the room above it is
## the sky (issue 436 round 3: the tile window's 434 x 150 picture is the 296 x 72 scene at about 1.5 times, with sky over it;
## a Control too short for that falls back to the height, centred). In a short wide banner (the owner's 540 banner design of
## 2026-11-26: 80 tall) the whole town shows at the height's scale and its backdrop (the sky, the far hills and the ground) is
## stretched to the Control's width under it, so the land runs on to both edges; a harbour's water runs on to the right edge.
## Three more kinds have no settlement: LAND (the bare land), SEA (open water) and FOG (a hatched terra incognita on a never
## discovered hex); they are landscapes, stretched to the whole Control.
class_name SettlementPicture
extends Control

const LOGICAL_SIZE := Vector2(296.0, 72.0)
const BASE_Y: float = 64.0
const LINE_WIDTH: float = 1.0
const STROKE_WIDTH: float = 1.5
const POLE_LENGTH: float = 10.0
const CASTLE_LEVELS: int = 3
const MAX_HARBOUR: int = 3
const HARBOUR_CENTRE: float = 96.0
const PLAIN_CENTRE: float = 148.0
const KINDS: Array[StringName] = [&"hamlet", &"village", &"town", &"walled_town", &"city", &"castle"]
## The kinds with no settlement (the tile window's picture of other tiles).
const LAND := &"land"
const SEA := &"sea"
const FOG := &"fog"
const PENNANT_PARTS: Array[StringName] = [&"tower", &"keep", &"spire", &"roof"]
## The parts of the backdrop, stretched to the Control's width (drawn first); the foot fade, stretched last.
const BACKDROP_PARTS: Array[StringName] = [&"sky", &"hill", &"ground"]
const FADE_PART := &"fade"
const SNOW_PARTS: Array[StringName] = [&"roof", &"spire"]
const TOKEN_NAMES: Array[StringName] = [
	&"OWNER", &"INK", &"SHADE",
	&"PIC_SKY", &"PIC_HILL", &"PIC_GROUND", &"PIC_WATER", &"PIC_WATER_LIGHT", &"PIC_QUAY",
	&"PIC_HOUSE", &"PIC_HOUSE_SHADE", &"PIC_ROOF", &"PIC_ROOF_SHADE", &"PIC_SNOW",
	&"PIC_STONE", &"PIC_STONE_SHADE", &"PIC_WALL", &"PIC_WINDOW", &"PIC_SAIL", &"TILE_FOG", &"TILE_SEP",
]

## House tables: [x, width, height] on the ground line.
const HAMLET_HOUSES: Array = [[30.0, 14.0, 10.0], [50.0, 12.0, 8.0], [66.0, 16.0, 12.0]]
const VILLAGE_HOUSES: Array = [[22.0, 14.0, 10.0], [40.0, 12.0, 8.0], [56.0, 16.0, 12.0], [78.0, 13.0, 9.0]]
const TOWN_HOUSES: Array = [
	[20.0, 14.0, 10.0], [37.0, 12.0, 8.0], [52.0, 15.0, 11.0], [70.0, 13.0, 9.0],
	[86.0, 16.0, 12.0], [105.0, 12.0, 8.0], [120.0, 14.0, 10.0],
]
const WALLED_HOUSES: Array = [
	[26.0, 12.0, 9.0], [42.0, 14.0, 11.0], [60.0, 12.0, 8.0], [76.0, 13.0, 10.0],
	[94.0, 12.0, 8.0], [110.0, 14.0, 11.0], [128.0, 12.0, 9.0],
]
const CITY_HOUSES: Array = [
	[26.0, 12.0, 9.0], [40.0, 11.0, 11.0], [54.0, 12.0, 8.0], [66.0, 10.0, 10.0],
	[138.0, 11.0, 9.0], [152.0, 12.0, 11.0], [166.0, 10.0, 8.0],
]


## The picture's recipe: an Array of shapes `{shape, points, fill_token, colour, ink, part}`.
## `shape` is &"rect" (points: top-left, bottom-right), &"poly" (points: the outline) or &"line" (two points);
## `colour` is the token's colour (OWNER takes `owner_colour`); `part` names what the shape is (house, roof, wall,
## tower, keep, spire, mast, pennant...) for the tests and the sheet.
static func recipe(
	kind: StringName, level: int, harbour: int, snow: bool, owner_colour: Color
) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if kind == FOG:
		_terra_incognita(items)
	elif kind == LAND or kind == SEA:
		_bare(items, kind == SEA)
	if kind == FOG or kind == LAND or kind == SEA:
		var bare: Array[Dictionary] = []
		for item: Dictionary in items:
			bare.append(_coloured(item, owner_colour))
		return bare
	var kind_id: StringName = kind if KINDS.has(kind) else &"hamlet"
	var hb := clampi(harbour, 0, MAX_HARBOUR)
	_land(items, hb)
	var settlement := _settlement_items(kind_id, clampi(level, 1, CASTLE_LEVELS), snow)
	var span := _span(settlement)
	_shift(settlement, (HARBOUR_CENTRE if hb > 0 else PLAIN_CENTRE) - (span.x + span.y) * 0.5)
	items.append_array(settlement)
	_pennant(items)
	if hb > 0:
		_harbour(items, hb)
	_fade(items)
	var out: Array[Dictionary] = []
	for item: Dictionary in items:
		out.append(_coloured(item, owner_colour))
	return out


## The colour of a recipe token; `OWNER` is the owner's colour. Unknown names fall back to INK.
static func token_colour(token: StringName, owner_colour: Color) -> Color:
	match token:
		&"OWNER":
			return owner_colour
		&"SHADE":
			return Tokens.SHADE
		&"PIC_SKY":
			return Tokens.PIC_SKY
		&"PIC_HILL":
			return Tokens.PIC_HILL
		&"PIC_GROUND":
			return Tokens.PIC_GROUND
		&"PIC_WATER":
			return Tokens.PIC_WATER
		&"PIC_WATER_LIGHT":
			return Tokens.PIC_WATER_LIGHT
		&"PIC_QUAY":
			return Tokens.PIC_QUAY
		&"PIC_HOUSE":
			return Tokens.PIC_HOUSE
		&"PIC_HOUSE_SHADE":
			return Tokens.PIC_HOUSE_SHADE
		&"PIC_ROOF":
			return Tokens.PIC_ROOF
		&"PIC_ROOF_SHADE":
			return Tokens.PIC_ROOF_SHADE
		&"PIC_SNOW":
			return Tokens.PIC_SNOW
		&"PIC_STONE":
			return Tokens.PIC_STONE
		&"PIC_STONE_SHADE":
			return Tokens.PIC_STONE_SHADE
		&"PIC_WALL":
			return Tokens.PIC_WALL
		&"PIC_WINDOW":
			return Tokens.PIC_WINDOW
		&"PIC_SAIL":
			return Tokens.PIC_SAIL
		&"TILE_FOG":
			return Tokens.TILE_FOG
		&"TILE_SEP":
			return Tokens.TILE_SEP
	return Tokens.INK


## The picture to show; `show_picture` builds the recipe once and redraws.
var _recipe: Array[Dictionary] = []
var _landscape := false


func _init() -> void:
	custom_minimum_size = LOGICAL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the picture of `kind` (hamlet, village, town, walled_town, city, castle); `level` 1 to 3 is the castle's
## level (watchtower, castle, fortress); `harbour` 0 to 3 adds the port; `snow` puts snow on the roofs.
func show_picture(kind: StringName, level: int, harbour: int, snow: bool, owner_colour: Color) -> void:
	_recipe = recipe(kind, level, harbour, snow, owner_colour)
	_landscape = kind == LAND or kind == SEA or kind == FOG
	queue_redraw()


## The recipe currently shown (empty before `show_picture`).
func current_recipe() -> Array[Dictionary]:
	return _recipe


func _draw() -> void:
	if _recipe.is_empty():
		return
	var k := scene_scale(size)
	var origin := Vector2((size.x - LOGICAL_SIZE.x * k.x) * 0.5, size.y - LOGICAL_SIZE.y * k.y)
	# The backdrop stretched to the whole width (the landscape of a bare kind: all of it), the sky above it.
	var wide := Vector2(size.x / LOGICAL_SIZE.x, k.y)
	if _landscape:
		wide = size / LOGICAL_SIZE if _recipe[0]["part"] == &"parchment" else Vector2(size.x / LOGICAL_SIZE.x, k.y)
	var low := Vector2(0.0, size.y - LOGICAL_SIZE.y * wide.y)
	if low.y > 0.0:
		draw_rect(Rect2(0.0, 0.0, size.x, low.y + 1.0), _recipe[0]["colour"] as Color)
	draw_set_transform(low)
	for shape: Dictionary in _recipe:
		if _landscape or BACKDROP_PARTS.has(shape["part"]):
			_paint(shape, wide)
	draw_set_transform(Vector2.ZERO)
	if not _landscape:
		draw_set_transform(origin)
		var water_right := -1.0
		for shape: Dictionary in _recipe:
			if not BACKDROP_PARTS.has(shape["part"]) and shape["part"] != FADE_PART:
				_paint(shape, k)
				if shape["part"] == &"water":
					water_right = LOGICAL_SIZE.x * k.x
		draw_set_transform(Vector2.ZERO)
		if water_right > 0.0 and origin.x + water_right < size.x:
			# The harbour's water runs on to the right edge (its foot band, under the boats).
			var top := origin.y + 66.0 * k.y
			draw_rect(Rect2(origin.x + water_right - 1.0, top, size.x - origin.x - water_right + 1.0, size.y - top), Tokens.PIC_WATER)
		draw_set_transform(low)
		for shape: Dictionary in _recipe:
			if shape["part"] == FADE_PART:
				_paint(shape, wide)
		draw_set_transform(Vector2.ZERO)


## The scale of the 296 x 72 scene in a Control of `area`: by the width, unless the scene would then be taller than the Control
## (then by the height). The same on both axes.
static func scene_scale(area: Vector2) -> Vector2:
	var s := minf(area.x / LOGICAL_SIZE.x, area.y / LOGICAL_SIZE.y)
	return Vector2(s, s)


func _paint(shape: Dictionary, k: Vector2) -> void:
	var pts := _scaled(shape["points"], k)
	var col: Color = shape["colour"]
	var kind: StringName = shape["shape"]
	if kind == &"line":
		if pts.size() >= 2:
			_paint_line(pts[0], pts[1], col)
		return
	var poly := _rect_corners(pts) if kind == &"rect" else pts
	_paint_polygon(poly, col)
	_paint_outline(poly, Tokens.INK if shape["ink"] else col)


func _paint_polygon(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)


## Antialiased outline; the fill itself is not antialiased by the engine, so the edge is drawn twice.
func _paint_outline(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 2:
		draw_polyline(pts + PackedVector2Array([pts[0]]), col, LINE_WIDTH, true)


func _paint_line(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, b, col, STROKE_WIDTH, true)


static func _scaled(pts: PackedVector2Array, k: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(Vector2(p.x * k.x, p.y * k.y))
	return out


static func _rect_corners(pts: PackedVector2Array) -> PackedVector2Array:
	var a := pts[0]
	var b := pts[1]
	return PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])


static func _item(
	items: Array[Dictionary], shape: StringName, pts: PackedVector2Array, token: StringName, ink: bool, part: StringName
) -> void:
	items.append({"shape": shape, "points": pts, "fill_token": token, "ink": ink, "part": part})


static func _box(
	items: Array[Dictionary], x: float, y: float, w: float, h: float, token: StringName, part: StringName, ink: bool = true
) -> void:
	_item(items, &"rect", PackedVector2Array([Vector2(x, y), Vector2(x + w, y + h)]), token, ink, part)


## A lit left half and a shaded right half, both outlined: the flat two-tone face of the Kenney style.
static func _twotone(
	items: Array[Dictionary], x: float, y: float, w: float, h: float, lit: StringName, dark: StringName, part: StringName
) -> void:
	_box(items, x, y, w * 0.5, h, lit, part)
	_box(items, x + w * 0.5, y, w * 0.5, h, dark, part)


static func _span(items: Array[Dictionary]) -> Vector2:
	var lo := INF
	var hi := -INF
	for item: Dictionary in items:
		var pts: PackedVector2Array = item["points"]
		for p: Vector2 in pts:
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
	if lo == INF:
		return Vector2(0.0, 0.0)
	return Vector2(lo, hi)


static func _shift(items: Array[Dictionary], dx: float) -> void:
	for item: Dictionary in items:
		var pts: PackedVector2Array = item["points"]
		for i: int in pts.size():
			pts[i] = pts[i] + Vector2(dx, 0.0)
		item["points"] = pts


static func _coloured(item: Dictionary, owner_colour: Color) -> Dictionary:
	var token: StringName = item["fill_token"]
	return {
		"shape": item["shape"],
		"points": item["points"],
		"fill_token": token,
		"colour": token_colour(token, owner_colour),
		"ink": item["ink"],
		"part": item["part"],
	}


## A picture with no settlement: the land's sky, hills and ground, or the sky over open water with its waves; the foot fade.
static func _bare(items: Array[Dictionary], sea: bool) -> void:
	if not sea:
		_land(items, 0)
	else:
		_box(items, 0.0, 0.0, LOGICAL_SIZE.x, LOGICAL_SIZE.y, &"PIC_SKY", &"sky", false)
		_box(items, 0.0, 34.0, LOGICAL_SIZE.x, LOGICAL_SIZE.y - 34.0, &"PIC_WATER", &"water", false)
		for wave: Array in [[30.0, 44.0, 56.0], [120.0, 50.0, 150.0], [210.0, 42.0, 236.0], [70.0, 60.0, 98.0], [180.0, 64.0, 206.0]]:
			_item(items, &"line", PackedVector2Array([Vector2(wave[0], wave[1]), Vector2(wave[2], wave[1])]), &"PIC_WATER_LIGHT",
				false, &"wave")
	_fade(items)


## Sky, far hills, the ground line; on a harbour town the water band and its waves.
static func _land(items: Array[Dictionary], hb: int) -> void:
	_box(items, 0.0, 0.0, LOGICAL_SIZE.x, LOGICAL_SIZE.y, &"PIC_SKY", &"sky", false)
	_item(items, &"poly", PackedVector2Array([
		Vector2(0.0, 40.0), Vector2(40.0, 30.0), Vector2(90.0, 38.0), Vector2(150.0, 28.0),
		Vector2(210.0, 36.0), Vector2(260.0, 30.0), Vector2(296.0, 36.0), Vector2(296.0, BASE_Y), Vector2(0.0, BASE_Y),
	]), &"PIC_HILL", false, &"hill")
	_item(items, &"poly", PackedVector2Array([
		Vector2(160.0, 33.0), Vector2(210.0, 36.0), Vector2(260.0, 30.0), Vector2(296.0, 36.0),
		Vector2(296.0, BASE_Y), Vector2(160.0, BASE_Y),
	]), &"PIC_HILL", false, &"hill")
	_box(items, 0.0, BASE_Y, LOGICAL_SIZE.x, LOGICAL_SIZE.y - BASE_Y, &"PIC_GROUND", &"ground", false)
	if hb > 0:
		_item(items, &"poly", PackedVector2Array([
			Vector2(200.0, 66.0), Vector2(222.0, 65.0), Vector2(248.0, 67.0), Vector2(274.0, 65.0),
			Vector2(296.0, 66.0), Vector2(296.0, LOGICAL_SIZE.y), Vector2(200.0, LOGICAL_SIZE.y),
		]), &"PIC_WATER", false, &"water")
		_item(items, &"line", PackedVector2Array([Vector2(210.0, 69.0), Vector2(224.0, 69.0)]), &"PIC_WATER_LIGHT", false, &"wave")
		_item(items, &"line", PackedVector2Array([Vector2(236.0, 71.0), Vector2(256.0, 71.0)]), &"PIC_WATER_LIGHT", false, &"wave")
		_item(items, &"line", PackedVector2Array([Vector2(266.0, 68.0), Vector2(284.0, 68.0)]), &"PIC_WATER_LIGHT", false, &"wave")


static func _settlement_items(kind: StringName, level: int, snow: bool) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	match kind:
		&"hamlet":
			_houses(items, HAMLET_HOUSES, snow)
		&"village":
			_houses(items, VILLAGE_HOUSES, snow)
			_chapel(items, 98.0, snow)
		&"town":
			_houses(items, TOWN_HOUSES, snow)
			_church(items, 138.0, 30.0, snow)
		&"walled_town":
			_houses(items, WALLED_HOUSES, snow)
			_church(items, 144.0, 26.0, snow)
			_wall(items, 14.0, 166.0, 10.0)
			_box(items, 90.0, BASE_Y - 9.0, 10.0, 9.0, &"PIC_WINDOW", &"gate", false)
			_tower(items, 8.0, 22.0, 14.0)
			_tower(items, 180.0, 22.0, 14.0)
		&"city":
			_houses(items, CITY_HOUSES, snow)
			_twotone(items, 90.0, BASE_Y - 22.0, 38.0, 22.0, &"PIC_STONE", &"PIC_STONE_SHADE", &"cathedral")
			_box(items, 106.0, BASE_Y - 16.0, 6.0, 6.0, &"PIC_WINDOW", &"window", false)
			_twotone(items, 100.0, BASE_Y - 38.0, 16.0, 16.0, &"PIC_STONE", &"PIC_STONE_SHADE", &"tower")
			_spire(items, 108.0, BASE_Y - 38.0, 14.0, 8.0, snow)
			_wall(items, 12.0, 170.0, 12.0)
			_tower(items, 8.0, 22.0, 12.0)
			_tower(items, 66.0, 22.0, 12.0)
			_tower(items, 134.0, 22.0, 12.0)
			_tower(items, 172.0, 22.0, 12.0)
		&"castle":
			match level:
				1:
					_tower(items, 98.0, 40.0, 24.0)
				2:
					_wall(items, 46.0, 104.0, 14.0)
					_tower(items, 40.0, 26.0, 14.0)
					_tower(items, 146.0, 26.0, 14.0)
					_keep(items, 96.0, 40.0, 26.0)
				_:
					_wall(items, 30.0, 134.0, 16.0)
					_item(items, &"poly", PackedVector2Array([
						Vector2(18.0, BASE_Y), Vector2(24.0, BASE_Y - 6.0), Vector2(34.0, BASE_Y - 6.0), Vector2(40.0, BASE_Y),
					]), &"PIC_STONE", true, &"bastion")
					_item(items, &"poly", PackedVector2Array([
						Vector2(146.0, BASE_Y), Vector2(152.0, BASE_Y - 6.0), Vector2(162.0, BASE_Y - 6.0), Vector2(168.0, BASE_Y),
					]), &"PIC_STONE", true, &"bastion")
					_tower(items, 22.0, 30.0, 14.0)
					_tower(items, 150.0, 30.0, 14.0)
					_tower(items, 60.0, 30.0, 12.0)
					_tower(items, 124.0, 30.0, 12.0)
					_keep(items, 92.0, 44.0, 28.0)
	return items


static func _houses(items: Array[Dictionary], houses: Array, snow: bool) -> void:
	for h: Array in houses:
		_house(items, float(h[0]), float(h[1]), float(h[2]), snow)


static func _house(items: Array[Dictionary], x: float, w: float, h: float, snow: bool) -> void:
	var top := BASE_Y - h
	var mid := x + w * 0.5
	var apex := Vector2(mid, top - maxf(5.0, w * 0.6))
	var eave_l := Vector2(x - 2.0, top)
	var eave_r := Vector2(x + w + 2.0, top)
	var foot := Vector2(mid, top)
	_twotone(items, x, top, w, h, &"PIC_HOUSE", &"PIC_HOUSE_SHADE", &"house")
	_item(items, &"poly", PackedVector2Array([eave_l, apex, foot]), &"PIC_ROOF", true, &"roof")
	_item(items, &"poly", PackedVector2Array([apex, eave_r, foot]), &"PIC_ROOF_SHADE", true, &"roof")
	if snow:
		_snow_cap(items, apex, eave_l, eave_r)
	if w >= 12.0:
		_box(items, mid - 1.5, top + h * 0.45, 3.0, 4.0, &"PIC_WINDOW", &"window", false)


static func _snow_cap(items: Array[Dictionary], apex: Vector2, left: Vector2, right: Vector2) -> void:
	var l := apex.lerp(left, 0.45)
	var r := apex.lerp(right, 0.45)
	_item(items, &"poly", PackedVector2Array([apex, l, r]), &"PIC_SNOW", false, &"snow")


static func _spire(items: Array[Dictionary], cx: float, base_y: float, height: float, half: float, snow: bool) -> void:
	var tip := Vector2(cx, base_y - height)
	var left := Vector2(cx - half, base_y)
	var right := Vector2(cx + half, base_y)
	_item(items, &"poly", PackedVector2Array([left, tip, right]), &"PIC_ROOF", true, &"spire")
	if snow:
		_snow_cap(items, tip, left, right)


static func _chapel(items: Array[Dictionary], x: float, snow: bool) -> void:
	_twotone(items, x, BASE_Y - 12.0, 16.0, 12.0, &"PIC_STONE", &"PIC_STONE_SHADE", &"chapel")
	_box(items, x + 6.5, BASE_Y - 8.0, 3.0, 4.0, &"PIC_WINDOW", &"window", false)
	_spire(items, x + 8.0, BASE_Y - 12.0, 20.0, 6.0, snow)


static func _church(items: Array[Dictionary], x: float, body_h: float, snow: bool) -> void:
	_twotone(items, x, BASE_Y - body_h, 16.0, body_h, &"PIC_STONE", &"PIC_STONE_SHADE", &"tower")
	_box(items, x + 6.0, BASE_Y - body_h + 6.0, 4.0, 6.0, &"PIC_WINDOW", &"window", false)
	_spire(items, x + 8.0, BASE_Y - body_h, 18.0, 9.0, snow)


static func _tower(items: Array[Dictionary], x: float, h: float, w: float) -> void:
	_twotone(items, x, BASE_Y - h, w, h, &"PIC_STONE", &"PIC_STONE_SHADE", &"tower")
	_crenels(items, x, w, BASE_Y - h)
	_box(items, x + w * 0.5 - 1.5, BASE_Y - h + 7.0, 3.0, 5.0, &"PIC_WINDOW", &"window", false)


static func _keep(items: Array[Dictionary], x: float, h: float, w: float) -> void:
	_twotone(items, x, BASE_Y - h, w, h, &"PIC_STONE", &"PIC_STONE_SHADE", &"keep")
	_crenels(items, x, w, BASE_Y - h)
	_box(items, x + w * 0.5 - 2.0, BASE_Y - h + 8.0, 4.0, 7.0, &"PIC_WINDOW", &"window", false)


static func _wall(items: Array[Dictionary], x: float, w: float, h: float) -> void:
	_twotone(items, x, BASE_Y - h, w, h, &"PIC_WALL", &"PIC_STONE_SHADE", &"wall")
	_crenels(items, x, w, BASE_Y - h)


## Merlons along a top edge: 3 px blocks every 6 px.
static func _crenels(items: Array[Dictionary], x: float, w: float, top: float) -> void:
	var n := int(floor((w - 3.0) / 6.0)) + 1
	for i: int in n:
		_box(items, x + 1.0 + 6.0 * float(i), top - 3.0, 3.0, 3.0, &"PIC_STONE", &"battlement")


## The tallest tower (smallest top y among tower, keep, spire and roof parts) flies the owner's pennant.
static func _pennant(items: Array[Dictionary]) -> void:
	var best_top := INF
	var best_cx := 0.0
	var found := false
	for item: Dictionary in items:
		if not PENNANT_PARTS.has(item["part"]):
			continue
		var pts: PackedVector2Array = item["points"]
		var top := INF
		var lo := INF
		var hi := -INF
		for p: Vector2 in pts:
			top = minf(top, p.y)
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
		if top < best_top:
			best_top = top
			best_cx = (lo + hi) * 0.5
			found = true
	if not found:
		return
	var tip_y := best_top - POLE_LENGTH
	_item(items, &"line", PackedVector2Array([Vector2(best_cx, best_top), Vector2(best_cx, tip_y)]), &"INK", false, &"pole")
	_item(items, &"poly", PackedVector2Array([
		Vector2(best_cx, tip_y), Vector2(best_cx + 9.0, tip_y + 3.0), Vector2(best_cx, tip_y + 6.0),
	]), &"OWNER", true, &"pennant")


## The quay and one moored ship a harbour level: a hull, a mast and a square sail (issue 436 round 3, L5: the old triangle sail
## read as a video's play button).
static func _harbour(items: Array[Dictionary], hb: int) -> void:
	_box(items, 196.0, 60.0, 100.0, 6.0, &"PIC_QUAY", &"quay")
	for i: int in hb:
		var mx := 226.0 + 26.0 * float(i)
		_item(items, &"line", PackedVector2Array([Vector2(mx, 63.0), Vector2(mx, 36.0)]), &"INK", false, &"mast")
		_box(items, mx - 7.0, 40.0, 14.0, 13.0, &"PIC_SAIL", &"sail")
		_item(items, &"poly", PackedVector2Array([
			Vector2(mx - 11.0, 63.0), Vector2(mx + 11.0, 63.0), Vector2(mx + 8.0, 69.0), Vector2(mx - 8.0, 69.0),
		]), &"PIC_ROOF_SHADE", true, &"hull")


## A never discovered hex: dark parchment under diagonal hatching and a dotted coast that leads nowhere (terra incognita).
static func _terra_incognita(items: Array[Dictionary]) -> void:
	_box(items, 0.0, 0.0, LOGICAL_SIZE.x, LOGICAL_SIZE.y, &"TILE_FOG", &"parchment", false)
	var x := -LOGICAL_SIZE.y
	while x < LOGICAL_SIZE.x:
		_item(items, &"line", PackedVector2Array([Vector2(x, LOGICAL_SIZE.y), Vector2(x + LOGICAL_SIZE.y, 0.0)]), &"TILE_SEP", false,
			&"hatch")
		_item(items, &"line", PackedVector2Array([Vector2(x + 1.0, LOGICAL_SIZE.y), Vector2(x + 1.0 + LOGICAL_SIZE.y, 0.0)]),
			&"PIC_STONE_SHADE", false, &"hatch")
		x += 9.0
	for k: int in 14:
		var px := 40.0 + 16.0 * float(k)
		var py := 40.0 + 9.0 * sin(float(k) * 0.9)
		_box(items, px, py, 3.0, 3.0, &"PIC_STONE", &"coast", false)


## The dark fade at the foot, under the name, kind and owner that the window lays over the picture.
static func _fade(items: Array[Dictionary]) -> void:
	_box(items, 0.0, 56.0, LOGICAL_SIZE.x, LOGICAL_SIZE.y - 56.0, &"SHADE", &"fade", false)
