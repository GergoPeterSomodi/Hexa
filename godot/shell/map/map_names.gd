## Names on the map: the countries (from COUNTRY_ZOOM down to the far maps, in both views), and the towns and passes
## (from NAME_ZOOM on). Sizes stay about the same on screen.
class_name MapNames
extends Node2D

const NAME_ZOOM := 0.3  # towns and passes from here on
const COUNTRY_ZOOM := 0.4  # country names up to here
const SCREEN_SIZE := 17.0  # the town name's size on screen, in pixels
const COUNTRY_SCREEN_SIZE := 24.0  # the country name's size on screen, in pixels
const TOWN_INK := Color(1.0, 0.97, 0.88)
const PASS_INK := Color(0.96, 0.86, 0.6)
const COUNTRY_INK := Color(1.0, 1.0, 0.95, 0.95)
const OUTLINE := Color(0.05, 0.04, 0.03, 0.92)

var map: MapData
var zoom: float = 1.0
var countries: Array[Dictionary] = []  # {"name": String, "at": Vector2i} (Political.name_points)
var view_rect := Rect2()  # the visible part of the map in world pixels: names outside it are not drawn


func _draw() -> void:
	if map == null or zoom <= 0.0:
		return
	var font := ThemeDB.fallback_font
	if zoom < COUNTRY_ZOOM:
		_country_names(font)
	if zoom < NAME_ZOOM:
		return
	var base := SCREEN_SIZE / zoom
	var outline := maxi(2, int(round(3.0 / zoom)))
	for pos: Vector2i in map.city_names.keys():
		if not view_rect.has_point(MapGeometry.centre(pos)):
			continue
		var size: int = map.city_sizes.get(pos, 1)
		var px := int(round(base * (1.3 if size >= 40 else 1.0)))
		var at := MapGeometry.centre(pos) + Vector2(0.0, 74.0)
		var text: String = map.city_names[pos]
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, -1, px, outline, OUTLINE)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, -1, px, TOWN_INK)
	# A pass can have several crest edges: its name is drawn once, at the middle of all of them.
	var pass_px := int(round(base * 0.8))
	var middles: Dictionary = {}
	var counts: Dictionary = {}
	for key: Vector4i in map.pass_names.keys():
		var a := MapGeometry.centre(Vector2i(key.x, key.y))
		var b := MapGeometry.centre(Vector2i(key.z, key.w))
		var name: String = map.pass_names[key]
		if not view_rect.has_point((a + b) * 0.5):
			continue
		middles[name] = middles.get(name, Vector2.ZERO) + (a + b) * 0.5
		counts[name] = counts.get(name, 0) + 1
	for pass_text: String in middles.keys():
		var at: Vector2 = middles[pass_text] / float(counts[pass_text]) + Vector2(0.0, -40.0)
		draw_string_outline(font, at, pass_text, HORIZONTAL_ALIGNMENT_CENTER, -1, pass_px, outline, OUTLINE)
		draw_string(font, at, pass_text, HORIZONTAL_ALIGNMENT_CENTER, -1, pass_px, PASS_INK)


func _country_names(font: Font) -> void:
	var px := int(round(COUNTRY_SCREEN_SIZE / zoom))
	var outline := maxi(3, int(round(4.0 / zoom)))
	for item: Dictionary in countries:
		var pos: Vector2i = item["at"]
		var text: String = item["name"]
		var at := MapGeometry.centre(pos) + Vector2(0.0, -20.0)
		if not view_rect.has_point(at):
			continue
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, -1, px, outline, OUTLINE)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, -1, px, COUNTRY_INK)
