## Place search (docs/architecture/m2-build-spec.md section 7.9): an OVERLAY card under the top bar with a LineEdit and up
## to 8 results from PlaceSearch.find. Up and Down move the highlight, Enter or a click chooses: a place or a pass
## sends look_at (select), a country sends country. The screen ends after a choice; Esc and Ctrl/Cmd+F close it.
## A focused LineEdit eats its keys, so no map key fires while typing.
class_name FindPlace
extends Screen

const CARD_W := 420
const EMPTY_NOTE := "Type a name: towns, passes and countries."
const NONE_NOTE := "Nothing on this map has that name."

@onready var _card: PanelContainer = $Card
@onready var _query: LineEdit = $Card/Body/Query
@onready var _rows_box: VBoxContainer = $Card/Body/Rows
@onready var _note: Label = $Card/Body/Note

var _results: Array[Dictionary] = []
var _cursor: int = -1
var _row_buttons: Array[Button] = []
var _ui_built: bool = false


func _ready() -> void:
	_ensure_ui()


func on_enter() -> void:
	_ensure_ui()
	_apply_top_inset()
	if ctx != null and not ctx.top_inset_changed.is_connected(_apply_top_inset):
		ctx.top_inset_changed.connect(_apply_top_inset)
	_query.text = ""
	_refresh()
	default_focus = get_path_to(_query)


## Esc closes the card (ScreenStack pops it).
func back() -> bool:
	return false


## Ctrl/Cmd+F closes the card. Handled before the GUI step, so it also works while the field has focus, and only
## when this card is the top screen.
func _shortcut_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.is_echo():
		return
	if not InputMap.has_action(&"ui_find_place") or not key.is_action_pressed(&"ui_find_place", false, true):
		return
	if not _is_top():
		return
	get_viewport().set_input_as_handled()
	finished.emit(&"close")


func query() -> LineEdit:
	_ensure_ui()
	return _query


func results() -> Array[Dictionary]:
	return _results.duplicate()


func cursor() -> int:
	return _cursor


func row_buttons() -> Array[Button]:
	return _row_buttons.duplicate()


func note_label() -> Label:
	_ensure_ui()
	return _note


## Sets the typed text and refreshes the results, as typing does.
func set_query(text: String) -> void:
	_ensure_ui()
	_query.text = text
	_refresh()


## Moves the highlight by `step`, clamped to the results.
func move_cursor(step: int) -> void:
	if _results.is_empty():
		_cursor = -1
		return
	_cursor = clampi(_cursor + step, 0, _results.size() - 1)
	_paint_cursor()


## Chooses result `index`: a place or pass glides to it and selects it, a country shows its panel. False when none.
func choose(index: int) -> bool:
	if index < 0 or index >= _results.size():
		return false
	var hit := _results[index]
	var kind := StringName(str(hit.get("kind", "")))
	finished.emit(&"chosen")
	if ctx == null:
		return true
	if kind == &"country":
		ctx.request(&"country", {"tag": StringName(str(hit.get("tag", "")))})
	else:
		ctx.request(&"look_at", {"hex": hit.get("hex", Vector2i.ZERO), "select": true})
	return true


## The card starts under the top bar's real bottom edge.
func _apply_top_inset() -> void:
	if _card != null:
		_card.offset_top = ctx.top_inset() if ctx != null else float(Tokens.BAR_H + Tokens.S2)


func on_exit() -> void:
	if ctx != null and ctx.top_inset_changed.is_connected(_apply_top_inset):
		ctx.top_inset_changed.disconnect(_apply_top_inset)


func _ensure_ui() -> void:
	if _ui_built or _card == null:
		return
	_ui_built = true
	_card.custom_minimum_size.x = float(CARD_W)
	_query.text_changed.connect(_on_text_changed)
	_query.text_submitted.connect(_on_text_submitted)
	_query.gui_input.connect(_on_query_gui_input)


func _refresh() -> void:
	_results = PlaceSearch.find(Session.game, _query.text)
	_cursor = 0 if not _results.is_empty() else -1
	_rebuild_rows()
	var typed := not _query.text.strip_edges().is_empty()
	_note.text = NONE_NOTE if typed else EMPTY_NOTE
	_note.visible = _results.is_empty()


func _rebuild_rows() -> void:
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_row_buttons.clear()
	for i: int in _results.size():
		var btn := _make_row(i, _results[i])
		_rows_box.add_child(btn)
		_row_buttons.append(btn)
	_paint_cursor()


func _make_row(index: int, hit: Dictionary) -> Button:
	var btn := Button.new()
	btn.name = "Row%d" % index
	btn.theme_type_variation = &"ButtonNav"
	btn.text = str(hit.get("name", ""))
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = float(maxi(Tokens.BUTTON_H, Tokens.TARGET_MIN))
	var detail := Label.new()
	detail.name = &"Detail"
	detail.theme_type_variation = &"Hint"
	detail.text = str(hit.get("detail", ""))
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	detail.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	detail.offset_right = -float(Tokens.S2)
	detail.offset_left = -float(Tokens.S2)
	btn.add_child(detail)
	btn.pressed.connect(choose.bind(index))
	btn.mouse_entered.connect(_set_cursor.bind(index))
	return btn


func _set_cursor(index: int) -> void:
	_cursor = index
	_paint_cursor()


func _paint_cursor() -> void:
	for i: int in _row_buttons.size():
		_row_buttons[i].set_pressed_no_signal(i == _cursor)


func _is_top() -> bool:
	if ctx == null:
		return true
	var stack := ctx.stack as ScreenStack
	return stack == null or stack.top() == self


func _on_text_changed(_text: String) -> void:
	_refresh()


func _on_text_submitted(_text: String) -> void:
	if _cursor >= 0:
		choose(_cursor)


func _on_query_gui_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.is_echo():
		return
	if key.keycode == KEY_DOWN:
		move_cursor(1)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_UP:
		move_cursor(-1)
		get_viewport().set_input_as_handled()
