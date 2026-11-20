## Custom-drawn Studiolo chart supporting 5 chart kinds (LINE, LINE_BARS, PAIRED_BARS, STACKED_BAR, SPARK),
## VELLUM/SLOT Theme grounds, non-colour second cues (dash patterns and markers), marks, keyboard cursor,
## HoverCard tooltips, and zero idle redraws
## (docs/architecture/ui-style-and-feedback-spec.md sections 4.2, 5 and 11; game-feedback-screens.md C.4).
class_name InkChart
extends Control

enum Kind {
	LINE,
	LINE_BARS,
	PAIRED_BARS,
	STACKED_BAR,
	SPARK,
}

enum Ground {
	VELLUM,
	SLOT,
}

const HOVER_CARD_SCENE := preload("res://shell/ui/hover_card.tscn")
const PAD_LEFT: float = 40.0
const PAD_RIGHT: float = 12.0
const PAD_TOP: float = 16.0
const PAD_BOTTOM: float = 22.0
const SPARK_PAD: float = 4.0

@export var kind: Kind = Kind.LINE:
	set(value):
		kind = value
		queue_redraw()

@export var ground: Ground = Ground.VELLUM:
	set(value):
		ground = value
		queue_redraw()

@export var x_labels: PackedStringArray = PackedStringArray():
	set(value):
		x_labels = value
		queue_redraw()

@export var y_ticks: PackedInt32Array = PackedInt32Array():
	set(value):
		y_ticks = value
		queue_redraw()

@export var caption: String = "":
	set(value):
		caption = value
		accessibility_name = caption
		_sync_accessibility()
		queue_redraw()

signal point_hovered(index: int)
signal point_activated(index: int)

var _series: Array[Dictionary] = []
var _marks: Array[Dictionary] = []
var _cursor: int = -1
var _hover_index: int = -1
var _redraw_count: int = 0


func _init() -> void:
	theme_type_variation = &"InkChart"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(120.0, 64.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var count := _point_count()
	if count <= 0:
		return

	var key_ev := event as InputEventKey
	if key_ev != null and key_ev.pressed:
		if _handle_key(key_ev.keycode, count):
			accept_event()
		return

	var motion := event as InputEventMouseMotion
	if motion != null:
		var idx := _index_at_x(motion.position.x, count)
		if idx != _hover_index:
			_hover_index = idx
			_cursor = idx
			point_hovered.emit(idx)
			queue_redraw()
		return

	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var idx := _index_at_x(mb.position.x, count)
		if idx >= 0:
			_cursor = idx
			_hover_index = idx
			point_activated.emit(idx)
			queue_redraw()
			accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var count := _point_count()
	if count <= 0:
		return ""
	var idx := _index_at_x(at_position.x, count)
	if idx < 0:
		return ""
	return "point:%d" % idx


func _make_custom_tooltip(for_text: String) -> Object:
	var count := _point_count()
	if count <= 0:
		return null
	var idx := _cursor if (_cursor >= 0 and _cursor < count) else (_hover_index if (_hover_index >= 0 and _hover_index < count) else count - 1)
	if for_text.begins_with("point:"):
		var parsed := for_text.substr(6).to_int()
		if parsed >= 0 and parsed < count:
			idx = parsed

	var card := HOVER_CARD_SCENE.instantiate() as HoverCard
	var title_text := x_labels[idx] if idx < x_labels.size() else "Point %d" % (idx + 1)
	var lines: Array = []
	for s_idx: int in _series.size():
		var s := _series[s_idx]
		var vals: PackedInt32Array = s["values"]
		if idx >= vals.size():
			continue
		var v := vals[idx]
		var tone := &"good" if v > 0 else (&"bad" if v < 0 else &"plain")
		lines.append([str(s["name"]), tone, str(v)])

	for m: Dictionary in _marks:
		if int(m.get("index", -1)) == idx:
			var m_tone := StringName(str(m.get("tone", &"warn")))
			lines.append([str(m.get("text", "")), m_tone, ""])

	card.show_card({
		"title": title_text,
		"subtitle": caption,
		"lines": lines,
	})
	return card


## Sets chart series: `[{name: String, values: PackedInt32Array, ink?: int, role?: String}]`.
func set_series(series: Array) -> void:
	_series.clear()
	for idx: int in series.size():
		if typeof(series[idx]) != TYPE_DICTIONARY:
			continue
		var raw := series[idx] as Dictionary
		var raw_vals: Variant = raw.get("values", PackedInt32Array())
		var vals := PackedInt32Array()
		if raw_vals is PackedInt32Array:
			vals = raw_vals as PackedInt32Array
		elif raw_vals is Array:
			for v: Variant in (raw_vals as Array):
				vals.append(int(v))
		_series.append({
			"name": str(raw.get("name", "Series %d" % (idx + 1))),
			"values": vals,
			"ink": int(raw.get("ink", idx)),
			"role": str(raw.get("role", "")),
		})

	var count := _point_count()
	if count <= 0:
		_cursor = -1
		_hover_index = -1
	else:
		if _cursor >= count:
			_cursor = count - 1
		if _hover_index >= count:
			_hover_index = count - 1
	_sync_accessibility()
	queue_redraw()


## Sets timeline marks: `[{index: int, text: String, tone?: StringName}]`.
func set_marks(marks: Array) -> void:
	_marks.clear()
	for m_var: Variant in marks:
		if typeof(m_var) == TYPE_DICTIONARY:
			_marks.append((m_var as Dictionary).duplicate())
	_sync_accessibility()
	queue_redraw()


## Returns an accessible readable text summary of caption, point count, and per-series bounds.
func summary() -> String:
	var count := _point_count()
	if count <= 0:
		return "No data yet" if caption.is_empty() else "%s: No data yet" % caption
	var parts: PackedStringArray = []
	if not caption.is_empty():
		parts.append(caption)
	parts.append("%d points" % count)
	for s: Dictionary in _series:
		var vals: PackedInt32Array = s["values"]
		if vals.is_empty():
			continue
		var lo := vals[0]
		var hi := vals[0]
		for v: int in vals:
			lo = mini(lo, v)
			hi = maxi(hi, v)
		parts.append("%s: min %d, max %d, latest %d" % [str(s["name"]), lo, hi, vals[vals.size() - 1]])
	return "; ".join(parts)


## Returns the number of times `_draw()` has executed on this chart.
func redraw_count() -> int:
	return _redraw_count


## Returns the active keyboard/hover point index, or -1 if none.
func cursor_index() -> int:
	return _cursor


func _draw() -> void:
	_redraw_count += 1
	var count := _point_count()
	var font := _chart_font()
	var font_size := _chart_font_size()
	var axis_col := _chart_color(&"axis")

	if count <= 0:
		_draw_empty_state(font, font_size, axis_col)
		return

	var plot := _plot_rect()
	if plot.size.x <= 4.0 or plot.size.y <= 4.0:
		return

	var bounds := _compute_bounds(count)
	var y_min := float(bounds.x)
	var y_max := float(bounds.y)

	if kind != Kind.SPARK:
		_draw_axes_and_grid(plot, y_min, y_max, count, font, font_size, axis_col)

	match kind:
		Kind.LINE:
			_draw_line_kind(plot, y_min, y_max, count, false)
		Kind.SPARK:
			_draw_line_kind(plot, y_min, y_max, count, true)
		Kind.LINE_BARS:
			_draw_line_bars_kind(plot, y_min, y_max, count)
		Kind.PAIRED_BARS:
			_draw_paired_bars_kind(plot, y_min, y_max, count)
		Kind.STACKED_BAR:
			_draw_stacked_bar_kind(plot, y_min, y_max, count)

	if kind != Kind.SPARK:
		_draw_marks(plot, count, font, font_size, axis_col)

	if _cursor >= 0 and _cursor < count:
		var cx := _x_for_index(plot, _cursor, count)
		draw_line(Vector2(cx, plot.position.y), Vector2(cx, plot.end.y), axis_col, 1.0)


func _draw_empty_state(font: Font, font_size: int, axis_col: Color) -> void:
	if font == null:
		return
	var msg := "No data yet"
	var text_sz := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2((size.x - text_sz.x) * 0.5, (size.y + text_sz.y * 0.5) * 0.5)
	draw_string(font, pos, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, axis_col)


func _draw_axes_and_grid(plot: Rect2, y_min: float, y_max: float, count: int, font: Font, font_size: int, axis_col: Color) -> void:
	var grid_col := _chart_color(&"grid")
	var ticks := _resolve_y_ticks(y_min, y_max)
	for tick_val: float in ticks:
		var ty := _y_for_value(plot, tick_val, y_min, y_max)
		draw_line(Vector2(plot.position.x, ty), Vector2(plot.end.x, ty), grid_col, 1.0)
		if font != null:
			var label := str(roundi(tick_val))
			draw_string(font, Vector2(2.0, ty + float(font_size) * 0.35), label, HORIZONTAL_ALIGNMENT_RIGHT, PAD_LEFT - 6.0, font_size, axis_col)

	draw_line(Vector2(plot.position.x, plot.position.y), Vector2(plot.position.x, plot.end.y), axis_col, 1.5)
	draw_line(Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.end.y), axis_col, 1.5)

	if font != null and not x_labels.is_empty():
		var max_labels := maxi(1, int(plot.size.x / 48.0))
		var step := maxi(1, ceili(float(count) / float(max_labels)))
		var labels := _fitted_x_labels(font, font_size, 40.0)
		for i: int in range(0, mini(count, labels.size()), step):
			var lx := _x_for_index(plot, i, count)
			draw_string(font, Vector2(lx - 20.0, plot.end.y + float(font_size) + 2.0), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 40.0, font_size, axis_col)


## The x labels as drawn: all of them whole when each fits `width`, else all cut to three letters (Spr, Sum, Aut, Win),
## so the axis never mixes long and short names or clips one ("Summe").
func _fitted_x_labels(font: Font, font_size: int, width: float) -> PackedStringArray:
	for lab: String in x_labels:
		if font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			var short := PackedStringArray()
			for l2: String in x_labels:
				short.append(l2.substr(0, 3))
			return short
	return x_labels


func _draw_line_kind(plot: Rect2, y_min: float, y_max: float, count: int, compact: bool) -> void:
	for s_idx: int in _series.size():
		var s := _series[s_idx]
		var vals: PackedInt32Array = s["values"]
		if vals.is_empty():
			continue
		var ink_idx := posmod(int(s["ink"]), 5)
		var col := _chart_color(StringName("ink_%d" % ink_idx))
		var cue: Dictionary = Tokens.CHART_CUES[ink_idx]
		var dash_kind := str(cue["dash"])
		var marker_kind := str(cue["marker"])

		var pts := PackedVector2Array()
		for i: int in vals.size():
			pts.append(Vector2(_x_for_index(plot, i, count), _y_for_value(plot, float(vals[i]), y_min, y_max)))

		if pts.size() >= 2:
			_draw_styled_polyline(pts, col, dash_kind, 1.8 if compact else 2.2)

		if compact:
			_draw_marker(pts[pts.size() - 1], marker_kind, col, 2.5)
		else:
			var m_step := 1 if pts.size() <= 20 else 2
			for i: int in range(0, pts.size(), m_step):
				_draw_marker(pts[i], marker_kind, col, 3.2)


func _draw_line_bars_kind(plot: Rect2, y_min: float, y_max: float, count: int) -> void:
	var bar_series: Array[Dictionary] = []
	var line_series: Array[Dictionary] = []
	for s_idx: int in _series.size():
		var s := _series[s_idx]
		var role := str(s["role"])
		if role == "bar" or (role.is_empty() and s_idx > 0):
			bar_series.append(s)
		else:
			line_series.append(s)

	var zero_y := _y_for_value(plot, 0.0, y_min, y_max)
	var slot_w := plot.size.x / float(maxi(1, count))
	var bar_w := clampf(slot_w * 0.55, 2.0, 22.0)
	var good_col := _chart_color(&"good")
	var bad_col := _chart_color(&"bad")

	for s: Dictionary in bar_series:
		var vals: PackedInt32Array = s["values"]
		for i: int in vals.size():
			var v := float(vals[i])
			var cx := _x_for_index(plot, i, count)
			var vy := _y_for_value(plot, v, y_min, y_max)
			var top := minf(vy, zero_y)
			var h := maxf(1.0, absf(vy - zero_y))
			draw_rect(Rect2(cx - bar_w * 0.5, top, bar_w, h), good_col if v >= 0.0 else bad_col)

	for s: Dictionary in line_series:
		var vals: PackedInt32Array = s["values"]
		if vals.is_empty():
			continue
		var ink_idx := posmod(int(s["ink"]), 5)
		var col := _chart_color(StringName("ink_%d" % ink_idx))
		var cue: Dictionary = Tokens.CHART_CUES[ink_idx]
		var pts := PackedVector2Array()
		for i: int in vals.size():
			pts.append(Vector2(_x_for_index(plot, i, count), _y_for_value(plot, float(vals[i]), y_min, y_max)))
		if pts.size() >= 2:
			_draw_styled_polyline(pts, col, str(cue["dash"]), 2.2)
		for p: Vector2 in pts:
			_draw_marker(p, str(cue["marker"]), col, 3.0)


## Whether series `s_idx` is drawn hollow: in PAIRED_BARS the ink 0 series (the "before") is hollow, an outline with the
## same ink; the rest are solid (style spec 6.5).
func is_hollow(s_idx: int) -> bool:
	if kind != Kind.PAIRED_BARS or s_idx < 0 or s_idx >= _series.size():
		return false
	return posmod(int(_series[s_idx]["ink"]), 5) == 0


func _draw_paired_bars_kind(plot: Rect2, y_min: float, y_max: float, count: int) -> void:
	var n_series := maxi(1, _series.size())
	var zero_y := _y_for_value(plot, 0.0, y_min, y_max)
	var slot_w := plot.size.x / float(maxi(1, count))
	var group_w := slot_w * 0.78
	var bar_w := clampf(group_w / float(n_series), 2.0, 18.0)
	var total_w := bar_w * float(n_series)

	for s_idx: int in _series.size():
		var s := _series[s_idx]
		var vals: PackedInt32Array = s["values"]
		var ink_idx := posmod(int(s["ink"]), 5)
		var col := _chart_color(StringName("ink_%d" % ink_idx))
		var cue: Dictionary = Tokens.CHART_CUES[ink_idx]
		var marker_kind := str(cue["marker"])
		for i: int in vals.size():
			var cx := _x_for_index(plot, i, count)
			var bx := cx - total_w * 0.5 + float(s_idx) * bar_w
			var vy := _y_for_value(plot, float(vals[i]), y_min, y_max)
			var top := minf(vy, zero_y)
			var h := maxf(1.0, absf(vy - zero_y))
			var rect := Rect2(bx, top, maxf(1.5, bar_w - 1.0), h)
			if is_hollow(s_idx):
				draw_rect(rect, col, false, 1.5)
			else:
				draw_rect(rect, col)
			if count <= 12:
				_draw_marker(Vector2(bx + bar_w * 0.5, top - 4.0), marker_kind, col, 2.0)


func _draw_stacked_bar_kind(plot: Rect2, y_min: float, y_max: float, count: int) -> void:
	var slot_w := plot.size.x / float(maxi(1, count))
	var bar_w := clampf(slot_w * 0.62, 2.0, 26.0)
	for i: int in count:
		var pos_acc := 0.0
		var neg_acc := 0.0
		var cx := _x_for_index(plot, i, count)
		for s: Dictionary in _series:
			var vals: PackedInt32Array = s["values"]
			if i >= vals.size():
				continue
			var v := float(vals[i])
			var ink_idx := posmod(int(s["ink"]), 5)
			var col := _chart_color(StringName("ink_%d" % ink_idx))
			if v >= 0.0:
				var y0 := _y_for_value(plot, pos_acc, y_min, y_max)
				pos_acc += v
				var y1 := _y_for_value(plot, pos_acc, y_min, y_max)
				draw_rect(Rect2(cx - bar_w * 0.5, y1, bar_w, maxf(1.0, y0 - y1)), col)
			else:
				var y0 := _y_for_value(plot, neg_acc, y_min, y_max)
				neg_acc += v
				var y1 := _y_for_value(plot, neg_acc, y_min, y_max)
				draw_rect(Rect2(cx - bar_w * 0.5, y0, bar_w, maxf(1.0, y1 - y0)), col)


func _draw_marks(plot: Rect2, count: int, font: Font, font_size: int, axis_col: Color) -> void:
	for m: Dictionary in _marks:
		var idx := int(m.get("index", -1))
		if idx < 0 or idx >= count:
			continue
		var mx := _x_for_index(plot, idx, count)
		var tone := StringName(str(m.get("tone", &"")))
		var col := _chart_color(tone) if (tone == &"good" or tone == &"bad") else axis_col
		draw_dashed_line(Vector2(mx, plot.position.y), Vector2(mx, plot.end.y), col, 1.0, 3.0)
		var txt := str(m.get("short", m.get("text", "")))
		if font != null and not txt.is_empty():
			draw_string(font, Vector2(mx + 3.0, plot.position.y + float(font_size)), txt, HORIZONTAL_ALIGNMENT_LEFT, maxf(24.0, minf(80.0, plot.end.x - mx - 3.0)), font_size, col)


func _draw_styled_polyline(pts: PackedVector2Array, col: Color, dash_kind: String, width: float) -> void:
	if dash_kind == "solid":
		draw_polyline(pts, col, width, true)
		return
	var dash_len := 6.0
	if dash_kind == "dotted":
		dash_len = 2.0
	elif dash_kind == "long_dash":
		dash_len = 11.0
	elif dash_kind == "dash_dot":
		dash_len = 8.0
	for i: int in range(pts.size() - 1):
		draw_dashed_line(pts[i], pts[i + 1], col, width, dash_len, true, true)


func _draw_marker(pos: Vector2, marker_kind: String, col: Color, r: float) -> void:
	match marker_kind:
		"square":
			draw_rect(Rect2(pos - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), col)
		"triangle":
			var tri := PackedVector2Array([
				pos + Vector2(0.0, -r * 1.15),
				pos + Vector2(r, r * 0.9),
				pos + Vector2(-r, r * 0.9),
			])
			draw_colored_polygon(tri, col)
		"diamond":
			var dia := PackedVector2Array([
				pos + Vector2(0.0, -r * 1.15),
				pos + Vector2(r * 1.15, 0.0),
				pos + Vector2(0.0, r * 1.15),
				pos + Vector2(-r * 1.15, 0.0),
			])
			draw_colored_polygon(dia, col)
		"cross":
			draw_line(pos + Vector2(-r, -r), pos + Vector2(r, r), col, 1.6, true)
			draw_line(pos + Vector2(-r, r), pos + Vector2(r, -r), col, 1.6, true)
		_:
			draw_circle(pos, r, col)


func _plot_rect() -> Rect2:
	if kind == Kind.SPARK:
		return Rect2(SPARK_PAD, SPARK_PAD, maxf(0.0, size.x - SPARK_PAD * 2.0), maxf(0.0, size.y - SPARK_PAD * 2.0))
	return Rect2(PAD_LEFT, PAD_TOP, maxf(0.0, size.x - PAD_LEFT - PAD_RIGHT), maxf(0.0, size.y - PAD_TOP - PAD_BOTTOM))


func _point_count() -> int:
	var best := 0
	for s: Dictionary in _series:
		var vals: PackedInt32Array = s["values"]
		best = maxi(best, vals.size())
	return best


func _compute_bounds(count: int) -> Vector2:
	var lo := 0.0
	var hi := 0.0
	var has_any := false
	var is_bar := (kind == Kind.LINE_BARS or kind == Kind.PAIRED_BARS or kind == Kind.STACKED_BAR)
	if is_bar:
		has_any = true

	if kind == Kind.STACKED_BAR:
		for i: int in count:
			var pos_sum := 0.0
			var neg_sum := 0.0
			for s: Dictionary in _series:
				var vals: PackedInt32Array = s["values"]
				if i < vals.size():
					var v := float(vals[i])
					if v >= 0.0:
						pos_sum += v
					else:
						neg_sum += v
			lo = minf(lo, neg_sum)
			hi = maxf(hi, pos_sum)
	else:
		for s: Dictionary in _series:
			var vals: PackedInt32Array = s["values"]
			for v_i: int in vals:
				var v := float(v_i)
				if not has_any:
					lo = v
					hi = v
					has_any = true
				else:
					lo = minf(lo, v)
					hi = maxf(hi, v)

	for yt: int in y_ticks:
		lo = minf(lo, float(yt))
		hi = maxf(hi, float(yt))

	if is_equal_approx(lo, hi):
		lo -= 1.0
		hi += 1.0
	return Vector2(lo, hi)


func _resolve_y_ticks(y_min: float, y_max: float) -> Array[float]:
	var out: Array[float] = []
	if not y_ticks.is_empty():
		for t: int in y_ticks:
			out.append(float(t))
		return out
	out.append(y_min)
	out.append((y_min + y_max) * 0.5)
	out.append(y_max)
	return out


func _x_for_index(plot: Rect2, index: int, count: int) -> float:
	var is_bar := (kind == Kind.LINE_BARS or kind == Kind.PAIRED_BARS or kind == Kind.STACKED_BAR)
	if count <= 1:
		return plot.position.x + plot.size.x * 0.5
	if is_bar:
		var slot_w := plot.size.x / float(count)
		return plot.position.x + (float(index) + 0.5) * slot_w
	return plot.position.x + (float(index) / float(count - 1)) * plot.size.x


func _y_for_value(plot: Rect2, val: float, y_min: float, y_max: float) -> float:
	var t := (val - y_min) / (y_max - y_min)
	return plot.end.y - clampf(t, 0.0, 1.0) * plot.size.y


func _index_at_x(px: float, count: int) -> int:
	if count <= 0:
		return -1
	if count == 1:
		return 0
	var plot := _plot_rect()
	if plot.size.x <= 0.0:
		return 0
	var norm := clampf((px - plot.position.x) / plot.size.x, 0.0, 1.0)
	var is_bar := (kind == Kind.LINE_BARS or kind == Kind.PAIRED_BARS or kind == Kind.STACKED_BAR)
	if is_bar:
		return clampi(int(floorf(norm * float(count))), 0, count - 1)
	return clampi(roundi(norm * float(count - 1)), 0, count - 1)


func _handle_key(keycode: Key, count: int) -> bool:
	match keycode:
		KEY_LEFT:
			_cursor = count - 1 if _cursor < 0 else maxi(0, _cursor - 1)
			point_hovered.emit(_cursor)
			queue_redraw()
			return true
		KEY_RIGHT:
			_cursor = 0 if _cursor < 0 else mini(count - 1, _cursor + 1)
			point_hovered.emit(_cursor)
			queue_redraw()
			return true
		KEY_HOME:
			_cursor = 0
			point_hovered.emit(_cursor)
			queue_redraw()
			return true
		KEY_END:
			_cursor = count - 1
			point_hovered.emit(_cursor)
			queue_redraw()
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _cursor >= 0 and _cursor < count:
				point_activated.emit(_cursor)
			return true
	return false


func _chart_color(key: StringName) -> Color:
	var lookup := StringName("%s_slot" % String(key)) if ground == Ground.SLOT else key
	if has_theme_color(lookup, &"InkChart"):
		return get_theme_color(lookup, &"InkChart")
	if has_theme_color(key, &"InkChart"):
		return get_theme_color(key, &"InkChart")
	return Tokens.TEXT if ground == Ground.SLOT else Tokens.VELLUM_INK


func _chart_font() -> Font:
	if has_theme_font(&"font", &"InkChart"):
		return get_theme_font(&"font", &"InkChart")
	return get_theme_default_font()


func _chart_font_size() -> int:
	if has_theme_font_size(&"font_size", &"InkChart"):
		return get_theme_font_size(&"font_size", &"InkChart")
	return 13


func _sync_accessibility() -> void:
	accessibility_description = summary()
