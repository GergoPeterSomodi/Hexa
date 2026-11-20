## Studiolo timeline strip for History (docs/architecture/m4-5-build-spec.md sections 4.7 and 6.2): one tick a season
## (4 px plus 3 px a witnessed line, at most 8 lines), one mark a season as its Kit icon tinted by tone, marks closer than
## 12 px merged into a slot that draws its highest mark, year labels thinned to fit, a keyboard cursor with the season's
## title above it, and a HoverCard. It takes plain dictionaries (StudyHistory.timeline) and never reads the game.
class_name TimelineStrip
extends Control

const HOVER_CARD_SCENE := preload("res://shell/ui/hover_card.tscn")
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
## Mark kinds in priority order (4.7): a merged slot draws its first mark in this order, the earliest season on a tie.
const MARK_PRIORITY: Array[String] = ["land", "finished", "stopped", "short", "begun", "tax", "chosen"]
const TICK_BASE: float = 4.0
const TICK_PER_LINE: float = 3.0
const TICK_MAX_LINES: int = 8
const MARK_SIZE: float = 16.0
const MERGE_PX: float = 12.0
const SPRING_LABEL_PX: float = 36.0
const YEAR_STEPS: Array[int] = [5, 10, 50]
const LABEL_GAP: float = 8.0
const PAD_X: float = 8.0
const TITLE_BASE: float = 14.0
const MARK_TOP: float = 22.0
const BASE_BOTTOM: float = 22.0
const LABEL_BASE_BOTTOM: float = 4.0
const MIN_HEIGHT: float = 96.0
const FONT_SIZE_DEFAULT: int = 13

signal season_hovered(turn: int)     # -1 when the pointer leaves
signal season_activated(turn: int)   # a click or Enter
signal cursor_moved(turn: int)       # the keyboard or a click moved the cursor

var _first_turn: int = 1
var _last_turn: int = 0
var _start_year: int = 0
var _counts: PackedInt32Array = PackedInt32Array()
var _marks: Array[Dictionary] = []
var _slots: Array[Dictionary] = []
var _cursor: int = -1
var _hover_turn: int = -1
var _redraw_count: int = 0


func _init() -> void:
	theme_type_variation = &"InkChart"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(160.0, MIN_HEIGHT)
	accessibility_name = "Timeline"


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild_slots()
		queue_redraw()
	elif what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_set_hover(-1)


## Sets the timeline from StudyHistory.timeline: {first_turn, last_turn, start_year, counts (by turn - 1),
## marks: [{turn, kind, tone, icon, text}]}. Missing keys read as empty. The cursor stays where it is when it still falls
## on a season; otherwise it clears.
func set_timeline(timeline: Dictionary) -> void:
	_first_turn = int(timeline.get("first_turn", 1))
	_last_turn = int(timeline.get("last_turn", 0))
	_start_year = int(timeline.get("start_year", 0))
	_counts = _int_array(timeline.get("counts", PackedInt32Array()))
	_marks.clear()
	var raw_marks: Variant = timeline.get("marks", [])
	if raw_marks is Array:
		for raw: Variant in raw_marks as Array:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var m := raw as Dictionary
			var turn := int(m.get("turn", 0))
			if turn < _first_turn or turn > _last_turn:
				continue
			_marks.append({
				"turn": turn,
				"order": _marks.size(),
				"kind": str(m.get("kind", "")),
				"tone": StringName(str(m.get("tone", "plain"))),
				"icon": StringName(str(m.get("icon", ""))),
				"text": str(m.get("text", "")),
			})
	_marks.sort_custom(_by_turn)
	if _cursor < _first_turn or _cursor > _last_turn:
		_cursor = -1
	if _hover_turn < _first_turn or _hover_turn > _last_turn:
		_hover_turn = -1
	_rebuild_slots()
	_sync_accessibility()
	queue_redraw()


## Sets the cursor season; -1 clears it, and a turn off the timeline is clamped onto it.
func set_cursor(turn: int) -> void:
	var next := -1
	if turn >= 0 and _season_count() > 0:
		next = clampi(turn, _first_turn, _last_turn)
	if next == _cursor:
		return
	_cursor = next
	queue_redraw()


## The cursor's turn, or -1 when there is none.
func cursor() -> int:
	return _cursor


## One sentence for the accessibility description, e.g. "1480 to 1482: 12 seasons; marks in Winter 1480 (finished),
## Spring 1481 (short)." or "No seasons yet".
func summary() -> String:
	var n := _season_count()
	if n <= 0:
		return "No seasons yet"
	var head := "%d to %d: %d %s" % [_year_of(_first_turn), _year_of(_last_turn), n, "season" if n == 1 else "seasons"]
	if _marks.is_empty():
		return head + "; no marks."
	var parts: PackedStringArray = []
	for m: Dictionary in _marks:
		parts.append("%s (%s)" % [season_title(int(m["turn"])), str(m["kind"])])
	return "%s; marks in %s." % [head, ", ".join(parts)]


## Returns the number of times `_draw()` has executed on this strip.
func redraw_count() -> int:
	return _redraw_count


## The x of a season's centre in local pixels (its tick and its mark sit here).
func season_x(turn: int) -> float:
	return PAD_X + (float(turn - _first_turn) + 0.5) * _season_width()


## The title of a season, e.g. "Winter 1480".
func season_title(turn: int) -> String:
	var offset := turn - _first_turn
	return "%s %d" % [SEASON_NAMES[posmod(offset, 4)], _year_of(turn)]


## A tick's height in pixels: 4 px plus 3 px a witnessed line, at most 8 lines (4.7).
func tick_height(turn: int) -> float:
	return TICK_BASE + TICK_PER_LINE * float(mini(_count_at(turn), TICK_MAX_LINES))


## The turns that carry a year label (4.7): each Spring when four seasons span 36 px or more, else the Springs of
## every 5th, 10th or 50th year, the first step whose spacing fits its label (50 when none does).
func label_turns() -> PackedInt32Array:
	var out := PackedInt32Array()
	var n := _season_count()
	var sw := _season_width()
	if n <= 0 or sw <= 0.0:
		return out
	var step := 1
	if sw * 4.0 < SPRING_LABEL_PX:
		var font := _font()
		var label_w := font.get_string_size("0000", HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x if font != null else 40.0
		step = 50
		for candidate: int in YEAR_STEPS:
			if float(candidate) * 4.0 * sw >= label_w + LABEL_GAP:
				step = candidate
				break
	for k: int in ceili(float(n) / 4.0):
		if (_start_year + k) % step == 0:
			out.append(_first_turn + k * 4)
	return out


## The merged slots as drawn: {marks: Array, drawn: Dictionary, x, first_x, last_x}. Read-only for tests and the page.
func slots() -> Array:
	return _slots.duplicate()


## How many slots the marks make at this width (marks closer than 12 px share one).
func slot_count() -> int:
	return _slots.size()


func _draw() -> void:
	_redraw_count += 1
	var font := _font()
	var font_size := _font_size()
	var axis := _colour(&"axis", Tokens.VELLUM_INK)
	if _season_count() <= 0 or _season_width() <= 0.0:
		if font != null:
			var msg := "No seasons yet"
			var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2((size.x - w) * 0.5, size.y * 0.5 + float(font_size) * 0.35), msg,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, axis)
		return
	_draw_ticks()
	_draw_marks()
	_draw_years(font, font_size, axis)
	_draw_cursor(font, font_size)


func _draw_ticks() -> void:
	var col := _colour(&"ink_0", Tokens.CHART_IRON)
	var w := clampf(_season_width() * 0.5, 1.0, 3.0)
	var base := size.y - BASE_BOTTOM
	for turn: int in range(_first_turn, _last_turn + 1):
		var h := tick_height(turn)
		draw_rect(Rect2(season_x(turn) - w * 0.5, base - h, w, h), col)


func _draw_marks() -> void:
	for slot: Dictionary in _slots:
		var m := slot["drawn"] as Dictionary
		var x := float(slot["x"])
		var col := _tone_colour(m["tone"] as StringName)
		var icon := _icon_texture(m["icon"] as StringName)
		if icon != null:
			draw_texture_rect(icon, Rect2(x - MARK_SIZE * 0.5, MARK_TOP, MARK_SIZE, MARK_SIZE), false, col)
		else:
			draw_circle(Vector2(x, MARK_TOP + MARK_SIZE * 0.5), 4.0, col)


func _draw_years(font: Font, font_size: int, col: Color) -> void:
	if font == null:
		return
	for turn: int in label_turns():
		var text := str(_year_of(turn))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := clampf(season_x(turn) - w * 0.5, PAD_X, size.x - PAD_X - w)
		draw_string(font, Vector2(x, size.y - LABEL_BASE_BOTTOM), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _draw_cursor(font: Font, font_size: int) -> void:
	if _cursor < _first_turn or _cursor > _last_turn:
		return
	var x := season_x(_cursor)
	draw_line(Vector2(x, TITLE_BASE + 4.0), Vector2(x, size.y - BASE_BOTTOM), _colour(&"ink_4", Tokens.GOLD_INK), 2.0)
	if font == null:
		return
	var title := season_title(_cursor)
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var tx := clampf(x - w * 0.5, PAD_X, size.x - PAD_X - w)
	draw_string(font, Vector2(tx, TITLE_BASE), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _colour(&"axis", Tokens.VELLUM_INK))


func _gui_input(event: InputEvent) -> void:
	if _season_count() <= 0:
		return
	var key_ev := event as InputEventKey
	if key_ev != null:
		if key_ev.pressed and _handle_key(key_ev.keycode, key_ev.shift_pressed):
			accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_set_hover(_turn_at_x(motion.position.x))
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var turn := _turn_at_x(mb.position.x)
		if turn >= 0:
			_move_cursor(turn)
			season_activated.emit(turn)
			accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var turn := _turn_at_x(at_position.x)
	if turn < 0:
		return ""
	return "turn:%d" % turn


func _make_custom_tooltip(for_text: String) -> Object:
	var turn := _cursor
	if for_text.begins_with("turn:"):
		turn = for_text.substr(5).to_int()
	if turn < _first_turn or turn > _last_turn:
		return null
	var lines: Array = []
	var count := _count_at(turn)
	lines.append(["%d %s" % [count, "line" if count == 1 else "lines"], &"plain", ""])
	var slot := _slot_at_x(season_x(turn))
	if not slot.is_empty():
		for m: Dictionary in slot["marks"] as Array:
			var text := str(m["text"])
			if text.is_empty():
				text = str(m["kind"])
			lines.append([text, m["tone"], ""])
	var card := HOVER_CARD_SCENE.instantiate() as HoverCard
	card.show_card({
		"title": season_title(turn),
		"subtitle": "",
		"lines": lines,
	})
	return card


func _handle_key(keycode: Key, shift: bool) -> bool:
	var step := 4 if shift else 1
	match keycode:
		KEY_LEFT:
			_move_cursor(_last_turn if _cursor < 0 else maxi(_first_turn, _cursor - step))
		KEY_RIGHT:
			_move_cursor(_first_turn if _cursor < 0 else mini(_last_turn, _cursor + step))
		KEY_HOME:
			_move_cursor(_first_turn)
		KEY_END:
			_move_cursor(_last_turn)
		KEY_ENTER, KEY_KP_ENTER:
			if _cursor >= 0:
				season_activated.emit(_cursor)
		_:
			return false
	return true


func _move_cursor(turn: int) -> void:
	if turn == _cursor:
		return
	_cursor = turn
	cursor_moved.emit(turn)
	queue_redraw()


func _set_hover(turn: int) -> void:
	if turn == _hover_turn:
		return
	_hover_turn = turn
	season_hovered.emit(turn)
	queue_redraw()


func _rebuild_slots() -> void:
	_slots.clear()
	for m: Dictionary in _marks:
		var x := season_x(int(m["turn"]))
		# Anchored at the slot's first mark: a mark joins while it is under MERGE_PX from that anchor, so the slot never
		# chains on past 12 px (4.7).
		if _slots.is_empty() or x - float(_slots[_slots.size() - 1]["first_x"]) >= MERGE_PX:
			_slots.append({"marks": [], "first_x": x, "last_x": x, "x": x, "drawn": m})
		var slot: Dictionary = _slots[_slots.size() - 1]
		(slot["marks"] as Array).append(m)
		slot["last_x"] = x
	for slot: Dictionary in _slots:
		var drawn := _pick_drawn(slot["marks"] as Array)
		slot["drawn"] = drawn
		slot["x"] = season_x(int(drawn["turn"]))


func _slot_at_x(px: float) -> Dictionary:
	for slot: Dictionary in _slots:
		if px >= float(slot["first_x"]) - MARK_SIZE * 0.5 and px <= float(slot["last_x"]) + MARK_SIZE * 0.5:
			return slot
	return {}


func _turn_at_x(px: float) -> int:
	var n := _season_count()
	var sw := _season_width()
	if n <= 0 or sw <= 0.0 or px < PAD_X or px > size.x - PAD_X:
		return -1
	return _first_turn + clampi(floori((px - PAD_X) / sw), 0, n - 1)


func _season_count() -> int:
	return maxi(0, _last_turn - _first_turn + 1)


func _season_width() -> float:
	var n := _season_count()
	if n <= 0:
		return 0.0
	return maxf(0.0, size.x - PAD_X * 2.0) / float(n)


func _count_at(turn: int) -> int:
	var idx := turn - 1
	if idx < 0 or idx >= _counts.size():
		return 0
	return maxi(0, _counts[idx])


func _year_of(turn: int) -> int:
	return _start_year + floori(float(turn - _first_turn) / 4.0)


func _sync_accessibility() -> void:
	accessibility_description = summary()


func _colour(key: StringName, fallback: Color) -> Color:
	if has_theme_color(key, &"InkChart"):
		return get_theme_color(key, &"InkChart")
	return fallback


func _tone_colour(tone: StringName) -> Color:
	match tone:
		&"good":
			return _colour(&"good", Tokens.GOOD_INK)
		&"bad":
			return _colour(&"bad", Tokens.BAD_INK)
	return _colour(&"axis", Tokens.VELLUM_INK)


func _icon_texture(icon_name: StringName) -> Texture2D:
	if icon_name == &"" or not has_theme_icon(icon_name, &"Kit"):
		return null
	return get_theme_icon(icon_name, &"Kit")


func _font() -> Font:
	if has_theme_font(&"font", &"Hint"):
		return get_theme_font(&"font", &"Hint")
	return get_theme_default_font()


func _font_size() -> int:
	if has_theme_font_size(&"font_size", &"Hint"):
		return get_theme_font_size(&"font_size", &"Hint")
	return FONT_SIZE_DEFAULT


static func _int_array(raw: Variant) -> PackedInt32Array:
	if raw is PackedInt32Array:
		return (raw as PackedInt32Array).duplicate()
	var out := PackedInt32Array()
	if raw is Array:
		for v: Variant in raw as Array:
			out.append(int(v))
	return out


static func _by_turn(a: Dictionary, b: Dictionary) -> bool:
	if int(a["turn"]) != int(b["turn"]):
		return int(a["turn"]) < int(b["turn"])
	return int(a["order"]) < int(b["order"])


static func _pick_drawn(marks: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_rank := 1 << 20
	for m_var: Variant in marks:
		var m := m_var as Dictionary
		var rank := MARK_PRIORITY.find(str(m["kind"]))
		if rank < 0:
			rank = MARK_PRIORITY.size()
		if best.is_empty() or rank < best_rank:
			best = m
			best_rank = rank
	return best
