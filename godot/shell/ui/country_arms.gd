## Procedural heraldic heater shield control (docs/architecture/m2-build-spec.md sections 4.7 and 7.2).
## Renders all 12 CountryDef.DIVISIONS at 48 x 56 (standard) or 20 x 24 (small) under the baked brass rim.
class_name CountryArms
extends Control

const SIZE_LARGE := Vector2(48.0, 56.0)
const SIZE_SMALL := Vector2(20.0, 24.0)
const CANONICAL_SIZE := Vector2(48.0, 56.0)
const FILL_INSET := 0.8
const BORDURE_INSET_LARGE := 6.0
const BORDURE_INSET_SMALL := 8.4
const DIVISION_LINE_WIDTH := 1.0
const DIAG_EXTEND := 16.0

## Heater shield outline at 48 x 56 logical pixels; tools/ui_bake/pieces_m2.py bakes shield_rim on these exact vertices.
const SHIELD: Array[Vector2] = [
	Vector2(0, 0),
	Vector2(48, 0),
	Vector2(48, 26),
	Vector2(47, 33),
	Vector2(45, 39),
	Vector2(41, 45),
	Vector2(36, 50),
	Vector2(30, 54),
	Vector2(24, 56),
	Vector2(18, 54),
	Vector2(12, 50),
	Vector2(7, 45),
	Vector2(3, 39),
	Vector2(1, 33),
	Vector2(0, 26),
]

static var _shield_packed: PackedVector2Array = PackedVector2Array(SHIELD)
static var _geom_cache: Dictionary[String, Dictionary] = {}
static var _default_tinctures: Dictionary[StringName, Color] = {}

## When true, renders the small 20 x 24 shield with `shield_rim_sm`; otherwise 48 x 56 with `shield_rim`.
@export var small: bool = false:
	set(value):
		if small == value:
			return
		small = value
		_apply_size()
		queue_redraw()

var _has_arms: bool = false
var _division: StringName = &""
var _field: Color = Tokens.SLOT
var _charge: Color = Tokens.GOLD


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


## Configures the shield from `CountryCard.of(game, tag)["arms"]` (`{division, field, charge}`).
## Passing an empty Dictionary clears the shield and draws nothing.
func set_country(card_arms: Dictionary) -> void:
	if card_arms.is_empty():
		_has_arms = false
		_division = &""
		queue_redraw()
		return
	var raw_div: Variant = card_arms.get("division", card_arms.get("arms_division", &"plain"))
	var div_name := StringName(str(raw_div))
	if not CountryDef.DIVISIONS.has(div_name):
		div_name = &"plain"
	var raw_field: Variant = card_arms.get("field", card_arms.get("arms_field", Tokens.SLOT))
	var raw_charge: Variant = card_arms.get("charge", card_arms.get("arms_charge", Tokens.GOLD))
	_field = _resolve_tincture(raw_field, Tokens.SLOT)
	_charge = _resolve_tincture(raw_charge, Tokens.GOLD)
	_division = div_name
	_has_arms = true
	queue_redraw()


## Returns true when arms have been configured and will be drawn.
func has_arms() -> bool:
	return _has_arms


## Returns the active normalized division (falls back to `&"plain"` on unknown inputs).
func division() -> StringName:
	return _division


## Returns the resolved field tincture colour.
func field_color() -> Color:
	return _field


## Returns the resolved charge tincture colour.
func charge_color() -> Color:
	return _charge


## Returns the scaled 15-vertex heater outline for `is_small` at `origin`.
static func scaled_shield(is_small: bool, origin: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var target := SIZE_SMALL if is_small else SIZE_LARGE
	return _scale_points(_shield_packed, target.x / CANONICAL_SIZE.x, target.y / CANONICAL_SIZE.y, origin)


## Computes the polygons and antialiased division lines for the current arms and size.
## Returns `{polygons: Array[{points, color}], lines: Array[{points, color, width}]}`.
func build_draw_commands() -> Dictionary:
	var polys: Array[Dictionary] = []
	var lines: Array[Dictionary] = []
	if not _has_arms:
		return {"polygons": polys, "lines": lines}

	var target := SIZE_SMALL if small else SIZE_LARGE
	var origin := _draw_origin(target)
	var sx := target.x / CANONICAL_SIZE.x
	var sy := target.y / CANONICAL_SIZE.y
	var geom := _division_geometry(_division, small)

	for poly_spec: Dictionary in geom["polygons"] as Array:
		var role: StringName = poly_spec["role"]
		var col := _charge if role == &"charge" else _field
		var pts := _scale_points(poly_spec["points"] as PackedVector2Array, sx, sy, origin)
		polys.append({"points": pts, "color": col})

	for line_pts: PackedVector2Array in geom["lines"] as Array:
		var pts := _scale_points(line_pts, sx, sy, origin)
		lines.append({"points": pts, "color": Tokens.INK_LINE, "width": DIVISION_LINE_WIDTH})

	return {"polygons": polys, "lines": lines}


func _draw() -> void:
	if not _has_arms:
		return
	var target := SIZE_SMALL if small else SIZE_LARGE
	var origin := _draw_origin(target)
	var cmds := build_draw_commands()

	for poly_cmd: Dictionary in cmds["polygons"] as Array:
		_paint_polygon(poly_cmd["points"] as PackedVector2Array, poly_cmd["color"] as Color)

	for line_cmd: Dictionary in cmds["lines"] as Array:
		_paint_polyline(
			line_cmd["points"] as PackedVector2Array,
			line_cmd["color"] as Color,
			float(line_cmd["width"])
		)

	_paint_rim(Rect2(origin, target), small)


func _paint_polygon(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)


func _paint_polyline(pts: PackedVector2Array, col: Color, width: float) -> void:
	if pts.size() >= 2:
		draw_polyline(pts, col, width, true)


func _paint_rim(rect: Rect2, is_small: bool) -> void:
	var icon_key := &"shield_rim_sm" if is_small else &"shield_rim"
	if has_theme_icon(icon_key, &"Kit"):
		var rim_tex := get_theme_icon(icon_key, &"Kit")
		if rim_tex != null:
			draw_texture_rect(rim_tex, rect, false)
			return
	var closed := _closed_polyline(scaled_shield(is_small, rect.position))
	var rim_col := get_theme_color(&"font_color", &"TitlePanel") if has_theme_color(&"font_color", &"TitlePanel") else Tokens.BRASS
	var rim_w := 2.0 if is_small else 3.0
	draw_polyline(closed, rim_col, rim_w, true)
	draw_polyline(closed, Tokens.INK, 1.0, true)


func _apply_size() -> void:
	custom_minimum_size = SIZE_SMALL if small else SIZE_LARGE


func _draw_origin(target: Vector2) -> Vector2:
	if size.x > target.x + 0.5 and size.y > target.y + 0.5:
		return (size - target) * 0.5
	return Vector2.ZERO


static func _resolve_tincture(raw_val: Variant, fallback: Color) -> Color:
	if typeof(raw_val) == TYPE_COLOR:
		return raw_val as Color
	if typeof(raw_val) == TYPE_STRING_NAME or typeof(raw_val) == TYPE_STRING:
		if _default_tinctures.is_empty():
			_default_tinctures = GameDefs.default_tinctures()
		var key := StringName(str(raw_val).strip_edges().to_lower())
		if _default_tinctures.has(key):
			return _default_tinctures[key]
	return fallback


static func _division_geometry(div_name: StringName, is_small: bool) -> Dictionary:
	var cache_key := "%s|%s" % [String(div_name), "sm" if is_small else "lg"]
	if _geom_cache.has(cache_key):
		return _geom_cache[cache_key]

	var fill_shield := _inset_shield(FILL_INSET)
	var polys: Array[Dictionary] = []
	var raw_lines: Array[PackedVector2Array] = []

	if div_name == &"bordure":
		var bordure_inset := BORDURE_INSET_SMALL if is_small else BORDURE_INSET_LARGE
		var inner_shield := _inset_shield(bordure_inset)
		polys.append({"points": fill_shield, "role": &"charge"})
		polys.append({"points": inner_shield, "role": &"field"})
		raw_lines.append(_closed_polyline(inner_shield))
	else:
		polys.append({"points": fill_shield, "role": &"field"})
		var charge_shapes := _raw_charge_polygons(div_name, raw_lines)
		for shape: PackedVector2Array in charge_shapes:
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(shape, fill_shield):
				if clipped.size() >= 3 and not Geometry2D.is_polygon_clockwise(clipped):
					polys.append({"points": clipped, "role": &"charge"})

	var clipped_lines: Array[PackedVector2Array] = []
	for raw_line: PackedVector2Array in raw_lines:
		for seg: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(raw_line, fill_shield):
			if seg.size() >= 2:
				clipped_lines.append(seg)

	var result := {"polygons": polys, "lines": clipped_lines}
	_geom_cache[cache_key] = result
	return result


static func _raw_charge_polygons(div_name: StringName, raw_lines: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	match div_name:
		&"plain":
			pass
		&"per_pale":
			shapes.append(_rect_poly(24.0, 0.0, 48.0, 56.0))
			raw_lines.append(PackedVector2Array([Vector2(24.0, 0.0), Vector2(24.0, 56.0)]))
		&"per_fess":
			shapes.append(_rect_poly(0.0, 26.0, 48.0, 56.0))
			raw_lines.append(PackedVector2Array([Vector2(0.0, 26.0), Vector2(48.0, 26.0)]))
		&"per_bend":
			shapes.append(PackedVector2Array([Vector2(0.0, 0.0), Vector2(48.0, 56.0), Vector2(0.0, 56.0)]))
			raw_lines.append(PackedVector2Array([Vector2(0.0, 0.0), Vector2(48.0, 56.0)]))
		&"quarterly":
			shapes.append(_rect_poly(24.0, 0.0, 48.0, 26.0))
			shapes.append(_rect_poly(0.0, 26.0, 24.0, 56.0))
			raw_lines.append(PackedVector2Array([Vector2(24.0, 0.0), Vector2(24.0, 56.0)]))
			raw_lines.append(PackedVector2Array([Vector2(0.0, 26.0), Vector2(48.0, 26.0)]))
		&"cross":
			var v_bar := _rect_poly(19.0, 0.0, 29.0, 56.0)
			var h_bar := _rect_poly(0.0, 17.0, 48.0, 27.0)
			for merged: PackedVector2Array in Geometry2D.merge_polygons(v_bar, h_bar):
				if merged.size() >= 3:
					shapes.append(merged)
					raw_lines.append(_closed_polyline(merged))
		&"saltire":
			var d1 := _band_poly(Vector2(0.0, 0.0), Vector2(48.0, 56.0), 4.5)
			var d2 := _band_poly(Vector2(48.0, 0.0), Vector2(0.0, 56.0), 4.5)
			for merged: PackedVector2Array in Geometry2D.merge_polygons(d1, d2):
				if merged.size() >= 3:
					shapes.append(merged)
					raw_lines.append(_closed_polyline(merged))
		&"chief":
			shapes.append(_rect_poly(0.0, 0.0, 48.0, 16.0))
			raw_lines.append(PackedVector2Array([Vector2(0.0, 16.0), Vector2(48.0, 16.0)]))
		&"fess":
			shapes.append(_rect_poly(0.0, 20.0, 48.0, 34.0))
			raw_lines.append(PackedVector2Array([Vector2(0.0, 20.0), Vector2(48.0, 20.0)]))
			raw_lines.append(PackedVector2Array([Vector2(0.0, 34.0), Vector2(48.0, 34.0)]))
		&"pale":
			shapes.append(_rect_poly(17.0, 0.0, 31.0, 56.0))
			raw_lines.append(PackedVector2Array([Vector2(17.0, 0.0), Vector2(17.0, 56.0)]))
			raw_lines.append(PackedVector2Array([Vector2(31.0, 0.0), Vector2(31.0, 56.0)]))
		&"bend":
			var band := _band_poly(Vector2(0.0, 0.0), Vector2(48.0, 56.0), 5.0)
			shapes.append(band)
			raw_lines.append(PackedVector2Array([band[0], band[1]]))
			raw_lines.append(PackedVector2Array([band[2], band[3]]))
	return shapes


static func _inset_shield(inset: float) -> PackedVector2Array:
	var offset := Geometry2D.offset_polygon(_shield_packed, -inset)
	if not offset.is_empty() and offset[0].size() >= 3:
		return offset[0]
	return _shield_packed


static func _rect_poly(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1),
	])


static func _band_poly(a: Vector2, b: Vector2, half_width: float) -> PackedVector2Array:
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x) * half_width
	var p0 := a - dir * DIAG_EXTEND
	var p1 := b + dir * DIAG_EXTEND
	return PackedVector2Array([
		p0 + nrm,
		p1 + nrm,
		p1 - nrm,
		p0 - nrm,
	])


static func _closed_polyline(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	if not out.is_empty():
		out.append(out[0])
	return out


static func _scale_points(pts: PackedVector2Array, sx: float, sy: float, origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i: int in pts.size():
		var p := pts[i]
		out[i] = Vector2(origin.x + p.x * sx, origin.y + p.y * sy)
	return out
