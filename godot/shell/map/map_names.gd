## Names on the map, in the countries view only, as Python's v0.2.2 map view draws them for each zoom (mapview.py:
## _country_names, _town_labels and _pass_names). Hex radius 3, 5 or 8 (the far zooms): the country names, in serif caps,
## sized by the country's area, dropped when too wide for its land and when they would cover another name. Hex radius 13
## and up: the town names on a dark plate, the cities only below radius 20, each tried below its hex, then above, right
## and left, and left out when none fits. Hex radius 34: the pass names on a plate. The terrain view has no names (Python's
## terrain mode draws none). The placement is worked out once per integer hex radius (Python's zoom steps) and cached; a
## frame draws only the names whose whole box lies in the view, so none is cut at the edge.
class_name MapNames
extends Node2D

const BASE_RADIUS := 60.0  # the hex radius the world is drawn at: zoom = radius / 60, so one screen pixel = 60 / radius
const FAR_BAND_MAX := 8  # country names at radius 3, 5 and 8 (Python's surface zooms)
const TOWN_BAND_MIN := 13  # town names from radius 13 (Python's first tile zoom)
const CITY_ONLY_BELOW := 20  # below this radius only the cities are named
const PASS_BAND := 34  # pass names at the closest zoom only
const TOWN_PX := 12  # Python's 'small' font: 12 pixels, bold, on screen
const COUNTRY_MIN_PX := 10
const COUNTRY_MAX_PX := 30
const COUNTRY_INK := Color(30.0 / 255.0, 26.0 / 255.0, 22.0 / 255.0)  # Python's political ink
const TOWN_INK := Color(245.0 / 255.0, 245.0 / 255.0, 245.0 / 255.0)  # Python's town label ink
const PLATE := Color(0.0, 0.0, 0.0, 150.0 / 255.0)  # Python's shade behind a town label
const SPACING := 3.0  # screen pixels a name keeps from the others (Python's 3 px probe margin)

var map: MapData
var countries: Array[Dictionary] = []  # {"name", "at", "area", "span"} (Political.name_points)
var view_rect := Rect2()  # the visible part of the map in world pixels: a name is drawn only when its box lies in it
var _zoom := 1.0
var _band := -1
var _items: Array[Dictionary] = []  # {"text", "font", "px", "ink", "plate", "box" (world), "pos" (text origin)}
var _serif: SystemFont
var _sans: SystemFont


func _init() -> void:
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	_serif.font_weight = 700
	_sans = SystemFont.new()
	_sans.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
	_sans.font_weight = 700


## The zoom of the map view. The placement is rebuilt only when the hex radius (zoom times 60, rounded) changes.
func set_zoom(zoom: float) -> void:
	_zoom = zoom
	var band := int(round(zoom * BASE_RADIUS))
	if band != _band:
		_band = band
		_place()
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	for item: Dictionary in _items:
		var box: Rect2 = item["box"]
		if not view_rect.encloses(box):
			continue
		var plate: bool = item["plate"]
		if plate:
			draw_rect(box, PLATE)
		var face: Font = item["font"]
		var text: String = item["text"]
		var px: int = item["px"]
		var ink: Color = item["ink"]
		var origin: Vector2 = item["pos"]
		draw_string(face, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)


## Works out every name's size and place for the current radius, in world pixels (one screen pixel is `unit`).
func _place() -> void:
	_items.clear()
	if map == null or _band <= 0:
		return
	var unit := BASE_RADIUS / float(_band)
	if _band <= FAR_BAND_MAX:
		_place_countries(unit)
	elif _band >= TOWN_BAND_MIN:
		var grid := _Grid.new(64.0 * unit)
		_place_towns(unit, grid)
		if _band == PASS_BAND:
			_place_passes(unit, grid)


## Country names: Python's size (the square root of the body's hexes times the radius times 0.55, from 10 to 30 pixels),
## dropped when the name is wider than the body times 1.6 plus 30 pixels, and when its box would cover a name already placed.
func _place_countries(unit: float) -> void:
	var taken: Array[Rect2] = []
	var sorted := countries.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["area"]) > int(b["area"]))
	for item: Dictionary in sorted:
		var area: int = item["area"]
		var screen_px := clampi(int(sqrt(float(area)) * float(_band) * 0.55), COUNTRY_MIN_PX, COUNTRY_MAX_PX)
		var px := int(round(float(screen_px) * unit))
		var text: String = String(item["name"]).to_upper()  # Python's far names are the upper case of the name
		var font: Font = _serif
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var span_world := float(item["span"]) * MapGeometry.hex_width()
		if size.x > span_world * 1.6 + 30.0 * unit:
			continue
		var at := MapGeometry.centre(item["at"])
		var top_left := at - size * 0.5
		var box := Rect2(top_left, size)
		var clash := false
		for other: Rect2 in taken:
			if other.intersects(box.grow(SPACING * unit)):
				clash = true
				break
		if clash:
			continue
		taken.append(box.grow(SPACING * unit))
		_add(text, font, px, COUNTRY_INK, false, Vector2.ZERO, top_left, size)


## Town names (Python's _town_labels): the towns and castles of the provinces, the capitals first, then the bigger
## towns. Each name tries the spot below its hex, then above, right and left; a name that fits in none is left out.
func _place_towns(unit: float, grid: _Grid) -> void:
	var cap_set: Dictionary = {}
	for capital: Vector2i in Political.capitals(map):
		cap_set[capital] = true
	var cands: Array[Dictionary] = []
	for pos: Vector2i in map.provinces.keys():
		var prov: Province = map.provinces[pos]
		if prov.settlement < 2 and prov.castle == 0:
			continue
		var name := prov.name
		if name.begins_with("near ") or name.begins_with("New ") or name.contains("countryside") or name.contains(" lands"):
			continue
		if _band < CITY_ONLY_BELOW and not prov.city:
			continue
		var rank := 0 if cap_set.has(pos) else (1 if prov.city or prov.settlement >= 3 else 2)
		cands.append({"pos": pos, "name": name, "rank": rank, "pop": prov.pop()})
	cands.sort_custom(_town_before)
	var font: Font = _sans
	var px := int(round(float(TOWN_PX) * unit))
	var pad_text := Vector2(4.0 * unit, 1.0 * unit)
	var hw := BASE_RADIUS * sqrt(3.0) * 0.5
	for cand: Dictionary in cands:
		var text: String = cand["name"]
		var pos: Vector2i = cand["pos"]
		var c := MapGeometry.centre(pos)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var size := text_size + pad_text * 2.0
		var h := size.y
		var w := size.x
		var spots: Array[Vector2] = [
			Vector2(c.x - w * 0.5, c.y + BASE_RADIUS * 0.72),
			Vector2(c.x - w * 0.5, c.y - BASE_RADIUS * 0.72 - h),
			Vector2(c.x + hw + 2.0 * unit, c.y - h * 0.5),
			Vector2(c.x - hw - 2.0 * unit - w, c.y - h * 0.5),
		]
		for spot: Vector2 in spots:
			var box := Rect2(spot, size)
			if grid.clear(box, SPACING * unit):
				grid.add(box, SPACING * unit)
				_add(text, font, px, TOWN_INK, true, pad_text, spot, size)
				break


## Pass names (Python's _pass_names): a plate at the middle of each pass, moved up or down when it would cover a town.
func _place_passes(unit: float, grid: _Grid) -> void:
	var middles: Dictionary = {}
	var counts: Dictionary = {}
	for key: Vector4i in map.pass_names.keys():
		var a := MapGeometry.centre(Vector2i(key.x, key.y))
		var b := MapGeometry.centre(Vector2i(key.z, key.w))
		var name: String = map.pass_names[key]
		var sum: Vector2 = middles.get(name, Vector2.ZERO)
		middles[name] = sum + (a + b) * 0.5
		counts[name] = int(counts.get(name, 0)) + 1
	var font: Font = _sans
	var px := int(round(float(TOWN_PX) * unit))
	var pad_text := Vector2(4.0 * unit, 1.0 * unit)
	for name: String in middles.keys():
		var total: Vector2 = middles[name]
		var at := total / float(counts[name])
		var size := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px) + pad_text * 2.0
		var h := size.y
		for dy: float in [0.0, -h - 4.0 * unit, h + 4.0 * unit, -2.0 * h - 8.0 * unit]:
			var top_left := Vector2(at.x - size.x * 0.5, at.y - size.y * 0.5 + dy)
			var box := Rect2(top_left, size)
			if grid.clear(box, SPACING * unit):
				grid.add(box, SPACING * unit)
				_add(name, font, px, TOWN_INK, true, pad_text, top_left, size)
				break


func _add(text: String, font: Font, px: int, ink: Color, plate: bool, pad: Vector2, top_left: Vector2,
		size: Vector2) -> void:
	_items.append({"text": text, "font": font, "px": px, "ink": ink, "plate": plate,
			"box": Rect2(top_left, size),
			"pos": top_left + pad + Vector2(0.0, font.get_ascent(px))})


## Python's order of the towns: the capitals (rank 0), then the cities and the great towns, then the rest; bigger first.
static func _town_before(a: Dictionary, b: Dictionary) -> bool:
	var ra: int = a["rank"]
	var rb: int = b["rank"]
	if ra != rb:
		return ra < rb
	var pa: float = a["pop"]
	var pb: float = b["pop"]
	if pa != pb:
		return pa > pb
	return HexGrid.lex_less(a["pos"], b["pos"])


## Boxes already placed, in square cells of a fixed size (world pixels), so a new name is checked against its neighbours only.
class _Grid extends RefCounted:
	var _cell: float
	var _cells: Dictionary = {}  # Vector2i -> Array of Rect2

	func _init(cell: float) -> void:
		_cell = cell

	## True when no placed box comes within `margin` of `box`.
	func clear(box: Rect2, margin: float) -> bool:
		var probe := box.grow(margin)
		for key: Vector2i in _keys(probe):
			var here: Array = _cells.get(key, [])
			for other: Rect2 in here:
				if probe.intersects(other):
					return false
		return true

	func add(box: Rect2, margin: float) -> void:
		var grown := box.grow(margin)
		for key: Vector2i in _keys(grown):
			var here: Array = _cells.get(key, [])
			here.append(box)
			_cells[key] = here

	func _keys(rect: Rect2) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		var x0 := int(floor(rect.position.x / _cell))
		var x1 := int(floor(rect.end.x / _cell))
		var y0 := int(floor(rect.position.y / _cell))
		var y1 := int(floor(rect.end.y / _cell))
		for gx in range(x0, x1 + 1):
			for gy in range(y0, y1 + 1):
				out.append(Vector2i(gx, gy))
		return out
