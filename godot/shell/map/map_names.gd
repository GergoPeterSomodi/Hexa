## Names on the map: the countries (small serif caps in Python's ink, from COUNTRY_ZOOM down, in both views), and the towns
## and passes (from NAME_ZOOM on). The placement is worked out once per zoom band (an integer hex radius, as Python's
## zoom steps) and cached: the frame only draws the names inside the view. Towns and passes are placed first; a country
## name is dropped where it would cover one, or another country name, so no names overlap.
class_name MapNames
extends Node2D

const NAME_ZOOM := 0.3  # towns and passes from here on
const COUNTRY_ZOOM := 0.45  # country names up to here
const TOWN_SCREEN := 17.0  # the town name's size on screen, in pixels
const COUNTRY_INK := Color(30.0 / 255.0, 26.0 / 255.0, 22.0 / 255.0)  # Python's political ink
const TOWN_INK := Color(1.0, 0.97, 0.88)
const PASS_INK := Color(0.96, 0.86, 0.6)
const OUTLINE := Color(0.05, 0.04, 0.03, 0.92)

var map: MapData
var countries: Array[Dictionary] = []  # {"name", "at", "area", "span"} (Political.name_points)
var view_rect := Rect2()  # the visible part of the map in world pixels: names outside it are not drawn
var _zoom := 1.0
var _band := -1
var _items: Array[Dictionary] = []  # {"text", "at", "px", "ink", "outline", "serif"}, placed for the current band
var _serif: SystemFont


func _init() -> void:
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	_serif.font_weight = 700


## The zoom of the map view. The placement is rebuilt only when the hex radius (zoom times 60, rounded) changes.
func set_zoom(zoom: float) -> void:
	_zoom = zoom
	var band := int(round(zoom * 60.0))
	if band != _band:
		_band = band
		_place()
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var font := ThemeDB.fallback_font
	for item: Dictionary in _items:
		var at: Vector2 = item["at"]
		if not view_rect.has_point(at):
			continue
		var text: String = item["text"]
		var px: int = item["px"]
		var face: Font = _serif if item["serif"] else font
		var outline: int = item["outline"]
		if outline > 0:
			draw_string_outline(face, at, text, HORIZONTAL_ALIGNMENT_CENTER, -1, px, outline, OUTLINE)
		draw_string(face, at, text, HORIZONTAL_ALIGNMENT_CENTER, -1, px, item["ink"])


## Works out every name's size and place for the current zoom: towns, then passes, then countries (largest first).
func _place() -> void:
	_items.clear()
	if map == null:
		return
	var font := ThemeDB.fallback_font
	var taken: Array[Rect2] = []
	var base := TOWN_SCREEN / _zoom
	if _zoom >= NAME_ZOOM:
		for pos: Vector2i in map.city_names.keys():
			var size: int = map.city_sizes.get(pos, 1)
			var px := int(round(base * (1.3 if size >= 40 else 1.0)))
			var text: String = map.city_names[pos]
			var at := MapGeometry.centre(pos) + Vector2(0.0, 74.0)
			_add(text, at, px, TOWN_INK, 3, false, font, taken)
		# A pass can have several crest edges: its name is drawn once, at the middle of all of them.
		var middles: Dictionary = {}
		var counts: Dictionary = {}
		for key: Vector4i in map.pass_names.keys():
			var a := MapGeometry.centre(Vector2i(key.x, key.y))
			var b := MapGeometry.centre(Vector2i(key.z, key.w))
			var name: String = map.pass_names[key]
			middles[name] = middles.get(name, Vector2.ZERO) + (a + b) * 0.5
			counts[name] = counts.get(name, 0) + 1
		for pass_text: String in middles.keys():
			var at: Vector2 = middles[pass_text] / float(counts[pass_text]) + Vector2(0.0, -40.0)
			_add(pass_text, at, int(round(base * 0.8)), PASS_INK, 3, false, font, taken)
	if _zoom < COUNTRY_ZOOM:
		_place_countries(taken)


## Country names: Python's size (the square root of the body's hexes times the radius times 0.55, from 10 to 30 pixels),
## dropped when the name is wider than the body times 1.6 plus 30 pixels, and when it would cover a name already placed.
func _place_countries(taken: Array[Rect2]) -> void:
	var r := _zoom * 60.0
	var sorted := countries.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["area"] > b["area"])
	for item: Dictionary in sorted:
		var area: int = item["area"]
		var screen_px := clampf(sqrt(float(area)) * r * 0.55, 10.0, 30.0)
		var px := int(round(screen_px / _zoom))
		var text: String = item["name"]
		var width := _serif.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, px).x * _zoom
		var span_screen := float(item["span"]) * MapGeometry.hex_width() * _zoom
		if width > span_screen * 1.6 + 30.0:
			continue
		var at := MapGeometry.centre(item["at"]) + Vector2(0.0, -20.0)
		_add(text, at, px, COUNTRY_INK, 0, true, _serif, taken)


## Adds a name unless (for a country name) its box covers one already placed. Every name's box is kept for the later ones.
func _add(text: String, at: Vector2, px: int, ink: Color, outline: int, serif: bool, face: Font,
		taken: Array[Rect2]) -> void:
	var size := face.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, px)
	var box := Rect2(at.x - size.x * 0.5, at.y - size.y * 0.8, size.x, size.y)
	if serif:
		for other: Rect2 in taken:
			if other.intersects(box):
				return
	taken.append(box)
	_items.append({"text": text, "at": at, "px": px, "ink": ink, "outline": outline, "serif": serif})
