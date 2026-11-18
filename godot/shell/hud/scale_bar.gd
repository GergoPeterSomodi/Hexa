## Custom-drawn Studiolo map scale bar picking clean rounded km lengths from pixels_per_hex
## (docs/architecture/ui-and-controls-spec.md section 7).
class_name ScaleBar
extends Control

const STEPS_KM: Array[int] = [5, 10, 20, 25, 50, 100, 200, 250, 500, 1000]
const DEFAULT_MAX_PX: float = 120.0
const DEFAULT_MIN_PX: float = 24.0
const DEFAULT_HEX_W_KM: float = 28.0
const TICK_H: float = 6.0
const BAR_THICKNESS: float = 2.0
const TOTAL_HEIGHT: float = 28.0

var max_width_px: float = DEFAULT_MAX_PX:
	set(value):
		max_width_px = maxf(value, DEFAULT_MIN_PX)
		_recompute()

var hex_w_km: float = DEFAULT_HEX_W_KM:
	set(value):
		hex_w_km = maxf(value, 0.1)
		_recompute()

var _pixels_per_hex: float = float(MapTiles.CELL.x)
var _picked_km: int = STEPS_KM[0]
var _bar_px: float = 0.0
var _label_text: String = "5 km"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(DEFAULT_MAX_PX + float(Tokens.S2), TOTAL_HEIGHT)
	_recompute()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


## Pure step picker: returns the longest step in STEPS_KM that fits within `max_px` at `km_per_px`.
## Returns `{km: int, px: float, label: String}`.
static func pick(km_per_px: float, max_px: float = DEFAULT_MAX_PX) -> Dictionary:
	if km_per_px <= 0.0 or max_px <= 0.0:
		var fallback := STEPS_KM[0]
		return {"km": fallback, "px": 0.0, "label": "%d km" % fallback}
	var chosen := STEPS_KM[0]
	for step_km: int in STEPS_KM:
		if float(step_km) / km_per_px <= max_px:
			chosen = step_km
		else:
			break
	var width_px := minf(float(chosen) / km_per_px, max_px)
	return {
		"km": chosen,
		"px": width_px,
		"label": "%d km" % chosen,
	}


## Pure step picker given `pixels_per_hex` (`MapTiles.CELL.x * zoom`) and `p_hex_w_km`.
static func pick_for_pixels_per_hex(
	px_per_hex: float,
	p_hex_w_km: float = DEFAULT_HEX_W_KM,
	max_px: float = DEFAULT_MAX_PX
) -> Dictionary:
	if px_per_hex <= 0.0 or p_hex_w_km <= 0.0:
		return pick(0.0, max_px)
	return pick(p_hex_w_km / px_per_hex, max_px)


## Updates the scale bar from camera zoom (`pixels_per_hex = MapTiles.CELL.x * zoom`).
func set_zoom(zoom: float, p_hex_w_km: float = -1.0) -> void:
	if p_hex_w_km > 0.0:
		hex_w_km = p_hex_w_km
	_pixels_per_hex = maxf(float(MapTiles.CELL.x) * zoom, 1.0e-5)
	_recompute()


## Updates the scale bar directly from `CameraRig.pixels_per_hex()`.
func set_pixels_per_hex(px_per_hex: float, p_hex_w_km: float = -1.0) -> void:
	if p_hex_w_km > 0.0:
		hex_w_km = p_hex_w_km
	_pixels_per_hex = maxf(px_per_hex, 1.0e-5)
	_recompute()


func current_km() -> int:
	return _picked_km


func current_px() -> float:
	return _bar_px


func current_label() -> String:
	return _label_text


func _recompute() -> void:
	var result := pick_for_pixels_per_hex(_pixels_per_hex, hex_w_km, max_width_px)
	_picked_km = int(result["km"])
	_bar_px = float(result["px"])
	_label_text = str(result["label"])
	custom_minimum_size = Vector2(maxf(_bar_px + float(Tokens.S2), max_width_px + float(Tokens.S2)), TOTAL_HEIGHT)
	accessibility_name = _label_text
	queue_redraw()


func _draw() -> void:
	if _bar_px <= 0.0:
		return
	var font := get_theme_font(&"font", &"Label")
	var font_size := get_theme_font_size(&"font_size", &"Label")
	if font == null:
		font = ThemeDB.fallback_font
	if font_size <= 0:
		font_size = 13

	var bar_w := roundf(_bar_px)
	var right_x := size.x - float(Tokens.S1)
	var left_x := maxf(float(Tokens.S1), right_x - bar_w)
	var base_y := size.y - float(Tokens.S1)
	var top_tick_y := base_y - TICK_H

	# Draw dark ink shadow outline behind the scale bracket for legibility over bright terrain.
	draw_rect(Rect2(left_x - 1.0, top_tick_y - 1.0, BAR_THICKNESS + 2.0, TICK_H + 2.0), Tokens.INK)
	draw_rect(Rect2(right_x - BAR_THICKNESS - 1.0, top_tick_y - 1.0, BAR_THICKNESS + 2.0, TICK_H + 2.0), Tokens.INK)
	draw_rect(Rect2(left_x - 1.0, base_y - BAR_THICKNESS - 1.0, bar_w + 2.0, BAR_THICKNESS + 2.0), Tokens.INK)

	draw_rect(Rect2(left_x, top_tick_y, BAR_THICKNESS, TICK_H), Tokens.TEXT)
	draw_rect(Rect2(right_x - BAR_THICKNESS, top_tick_y, BAR_THICKNESS, TICK_H), Tokens.TEXT)
	draw_rect(Rect2(left_x, base_y - BAR_THICKNESS, bar_w, BAR_THICKNESS), Tokens.TEXT)

	var text_pos := Vector2(left_x, top_tick_y - 4.0)
	draw_string(font, text_pos + Vector2(1.0, 1.0), _label_text, HORIZONTAL_ALIGNMENT_RIGHT, bar_w, font_size, Tokens.INK)
	draw_string(font, text_pos, _label_text, HORIZONTAL_ALIGNMENT_RIGHT, bar_w, font_size, Tokens.TEXT)
