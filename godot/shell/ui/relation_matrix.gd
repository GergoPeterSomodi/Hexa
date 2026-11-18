## Custom-drawn diplomacy relation matrix (64 x 34 cells per country pair) rendering both
## a Kit icon/glyph and a short state word (War, Ally, Truce, Peace, Self), with arrow-key
## cursor navigation and cell activation
## (docs/architecture/ui-style-and-feedback-spec.md section 5; game-feedback-screens.md C.4).
class_name RelationMatrix
extends Control

const CELL_W: float = 64.0
const CELL_H: float = 34.0
const HEADER_W: float = 96.0
const HEADER_H: float = 28.0
const HOVER_CARD_SCENE := preload("res://shell/ui/hover_card.tscn")

const _STATE_WORDS: Dictionary[StringName, String] = {
	&"war": "War",
	&"ally": "Ally",
	&"truce": "Truce",
	&"peace": "Peace",
	&"self": "Self",
}

const _STATE_ICONS: Dictionary[StringName, StringName] = {
	&"war": &"cross",
	&"ally": &"tick",
	&"truce": &"lock",
	&"peace": &"dash",
	&"self": &"dash",
}

signal cell_activated(a: StringName, b: StringName)

var _tags: Array[StringName] = []
var _names: Array[String] = []
var _cells: Array[Array] = []
var _cursor: Vector2i = Vector2i(-1, -1)


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var n := _tags.size()
	if n <= 0:
		return

	var key_ev := event as InputEventKey
	if key_ev != null and key_ev.pressed:
		if _handle_key(key_ev.keycode, n):
			accept_event()
		return

	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var pos := mb.position - Vector2(HEADER_W, HEADER_H)
		if pos.x >= 0.0 and pos.y >= 0.0:
			var col := clampi(int(floorf(pos.x / CELL_W)), 0, n - 1)
			var row := clampi(int(floorf(pos.y / CELL_H)), 0, n - 1)
			_cursor = Vector2i(col, row)
			queue_redraw()
			cell_activated.emit(_tags[row], _tags[col])
			accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var n := _tags.size()
	if n <= 0:
		return ""
	var pos := at_position - Vector2(HEADER_W, HEADER_H)
	if pos.x < 0.0 or pos.y < 0.0:
		return ""
	var col := int(floorf(pos.x / CELL_W))
	var row := int(floorf(pos.y / CELL_H))
	if col < 0 or col >= n or row < 0 or row >= n:
		return ""
	return "%d:%d" % [row, col]


func _make_custom_tooltip(for_text: String) -> Object:
	var parts := for_text.split(":")
	if parts.size() != 2:
		return null
	var row := parts[0].to_int()
	var col := parts[1].to_int()
	var n := _tags.size()
	if row < 0 or row >= n or col < 0 or col >= n:
		return null
	var c := cell_at(row, col)
	var state := StringName(str(c.get("state", &"peace")))
	var lines: Array = [
		["State", _tone_name_for(state), cell_word_for(state)],
	]
	if state == &"truce" and int(c.get("seasons_left", 0)) > 0:
		lines.append(["Seasons left", &"warn", str(int(c.get("seasons_left", 0)))])
	if state != &"self":
		var op := int(c.get("opinion", 0))
		lines.append(["Opinion", &"good" if op > 0 else (&"bad" if op < 0 else &"plain"), str(op)])
	var card := HOVER_CARD_SCENE.instantiate() as HoverCard
	card.show_card({
		"title": "%s — %s" % [_names[row], _names[col]],
		"subtitle": "",
		"lines": lines,
	})
	return card


## Populates the N x N matrix from `tags`, `names`, and `cells` (2D or flat N*N array of `{state, seasons_left, opinion}`).
func set_matrix(tags: Array, names: Array, cells: Array) -> void:
	_tags.clear()
	_names.clear()
	_cells.clear()
	for i: int in tags.size():
		_tags.append(StringName(str(tags[i])))
		_names.append(str(names[i]) if i < names.size() else str(tags[i]))

	var n := _tags.size()
	var is_2d := (not cells.is_empty() and cells[0] is Array)
	for r: int in n:
		var row_arr: Array[Dictionary] = []
		for c: int in n:
			var entry := {"state": &"self" if r == c else &"peace", "seasons_left": 0, "opinion": 0}
			if is_2d and r < cells.size():
				var row_src := cells[r] as Array
				if c < row_src.size() and row_src[c] is Dictionary:
					entry = (row_src[c] as Dictionary).duplicate()
			else:
				var flat_idx := r * n + c
				if flat_idx < cells.size() and cells[flat_idx] is Dictionary:
					entry = (cells[flat_idx] as Dictionary).duplicate()
			row_arr.append(entry)
		_cells.append(row_arr)

	custom_minimum_size = Vector2(HEADER_W + float(n) * CELL_W, HEADER_H + float(n) * CELL_H)
	_cursor = Vector2i(0, 0) if n > 0 else Vector2i(-1, -1)
	accessibility_name = "Relations matrix (%d countries)" % n
	queue_redraw()


## Returns the active keyboard/mouse cursor cell `(col, row)`, or `Vector2i(-1, -1)` when empty.
func cursor() -> Vector2i:
	return _cursor


## Returns the cell dictionary at `(row, col)` (or empty Dictionary if out of range).
func cell_at(row: int, col: int) -> Dictionary:
	if row < 0 or row >= _cells.size():
		return {}
	var r_arr: Array = _cells[row]
	if col < 0 or col >= r_arr.size():
		return {}
	return r_arr[col] as Dictionary


## Returns the short visible word rendered for a diplomatic state (`War`, `Ally`, `Truce`, `Peace`, `Self`).
static func cell_word_for(state: StringName) -> String:
	return _STATE_WORDS.get(state, "Peace")


## Returns the Kit icon name paired with a diplomatic state.
static func cell_icon_for(state: StringName) -> StringName:
	return _STATE_ICONS.get(state, &"dash")


func _draw() -> void:
	var n := _tags.size()
	if n <= 0:
		return

	var font := get_theme_font(&"font", &"TableRow")
	var font_size := get_theme_font_size(&"font_size", &"TableRow")
	var head_font := get_theme_font(&"font", &"TableHeader")
	var head_size := get_theme_font_size(&"font_size", &"TableHeader")
	var head_col := get_theme_color(&"font_color", &"TableHeader") if has_theme_color(&"font_color", &"TableHeader") else Tokens.GOLD
	var text_col := get_theme_color(&"font_color", &"TableRow") if has_theme_color(&"font_color", &"TableRow") else Tokens.TEXT

	for i: int in n:
		var col_x := HEADER_W + float(i) * CELL_W
		if head_font != null:
			draw_string(head_font, Vector2(col_x + 4.0, HEADER_H - 8.0), _names[i], HORIZONTAL_ALIGNMENT_CENTER, CELL_W - 8.0, head_size, head_col)
		var row_y := HEADER_H + float(i) * CELL_H
		if head_font != null:
			draw_string(head_font, Vector2(4.0, row_y + CELL_H * 0.62), _names[i], HORIZONTAL_ALIGNMENT_LEFT, HEADER_W - 8.0, head_size, head_col)

	for r: int in n:
		for c: int in n:
			var rect := Rect2(HEADER_W + float(c) * CELL_W, HEADER_H + float(r) * CELL_H, CELL_W, CELL_H)
			var cell := cell_at(r, c)
			var state := StringName(str(cell.get("state", &"self" if r == c else &"peace")))
			var bg := Tokens.PANEL_BG if state == &"self" else Tokens.SLOT
			draw_rect(rect, bg, true)
			draw_rect(rect, Tokens.RULE, false, 1.0)

			var tone_col := _color_for_state(state, text_col)
			var icon_key := cell_icon_for(state)
			var icon_rect := Rect2(rect.position + Vector2(6.0, (CELL_H - 12.0) * 0.5), Vector2(12.0, 12.0))
			if has_theme_icon(icon_key, &"Kit"):
				draw_texture_rect(get_theme_icon(icon_key, &"Kit"), icon_rect, false, tone_col)
			else:
				draw_circle(icon_rect.get_center(), 3.0, tone_col)

			var word := cell_word_for(state)
			if font != null:
				draw_string(font, Vector2(rect.position.x + 21.0, rect.position.y + CELL_H * 0.65), word, HORIZONTAL_ALIGNMENT_LEFT, CELL_W - 23.0, font_size, tone_col)

			if _cursor == Vector2i(c, r):
				draw_rect(rect.grow(-1.0), Tokens.GOLD, false, 2.0)


func _handle_key(keycode: Key, n: int) -> bool:
	if _cursor.x < 0 or _cursor.y < 0:
		_cursor = Vector2i(0, 0)
	match keycode:
		KEY_LEFT:
			_cursor.x = maxi(0, _cursor.x - 1)
			queue_redraw()
			return true
		KEY_RIGHT:
			_cursor.x = mini(n - 1, _cursor.x + 1)
			queue_redraw()
			return true
		KEY_UP:
			_cursor.y = maxi(0, _cursor.y - 1)
			queue_redraw()
			return true
		KEY_DOWN:
			_cursor.y = mini(n - 1, _cursor.y + 1)
			queue_redraw()
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _cursor.y >= 0 and _cursor.y < n and _cursor.x >= 0 and _cursor.x < n:
				cell_activated.emit(_tags[_cursor.y], _tags[_cursor.x])
			return true
	return false


func _color_for_state(state: StringName, fallback: Color) -> Color:
	match state:
		&"war":
			return get_theme_color(&"font_color", &"NumberBad") if has_theme_color(&"font_color", &"NumberBad") else Tokens.BAD
		&"ally":
			return get_theme_color(&"font_color", &"NumberGood") if has_theme_color(&"font_color", &"NumberGood") else Tokens.GOOD
		&"truce":
			return get_theme_color(&"font_color", &"NumberWarn") if has_theme_color(&"font_color", &"NumberWarn") else Tokens.WARN
		&"self":
			return Tokens.FAINT
		_:
			return get_theme_color(&"font_color", &"Hint") if has_theme_color(&"font_color", &"Hint") else fallback


func _tone_name_for(state: StringName) -> StringName:
	match state:
		&"war":
			return &"bad"
		&"ally":
			return &"good"
		&"truce":
			return &"warn"
		&"self":
			return &"muted"
		_:
			return &"plain"
