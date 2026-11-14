## Town and pass names on the map. Drawn from NAME_ZOOM on, at a size that stays about the same on screen.
class_name MapNames
extends Node2D

const SCREEN_SIZE := 17.0  # the town name's size on screen, in pixels
const TOWN_INK := Color(1.0, 0.97, 0.88)
const PASS_INK := Color(0.96, 0.86, 0.6)
const OUTLINE := Color(0.05, 0.04, 0.03, 0.92)

var map: MapData
var zoom: float = 1.0


func _draw() -> void:
	if map == null or zoom <= 0.0:
		return
	var font := ThemeDB.fallback_font
	var base := SCREEN_SIZE / zoom
	var outline := maxi(2, int(round(3.0 / zoom)))
	for pos: Vector2i in map.city_names.keys():
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
		middles[name] = middles.get(name, Vector2.ZERO) + (a + b) * 0.5
		counts[name] = counts.get(name, 0) + 1
	for pass_text: String in middles.keys():
		var at: Vector2 = middles[pass_text] / float(counts[pass_text]) + Vector2(0.0, -40.0)
		draw_string_outline(font, at, pass_text, HORIZONTAL_ALIGNMENT_CENTER, -1, pass_px, outline, OUTLINE)
		draw_string(font, at, pass_text, HORIZONTAL_ALIGNMENT_CENTER, -1, pass_px, PASS_INK)
