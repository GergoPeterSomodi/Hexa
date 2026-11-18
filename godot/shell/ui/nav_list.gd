## Vertical navigation list of toggle items in a ButtonGroup, with optional right-aligned count badges
## and leather/vellum ink variants (docs/architecture/ui-style-and-feedback-spec.md section 5).
class_name NavList
extends VBoxContainer

signal selected(id: StringName)

@export var ink: bool = false:
	set(value):
		ink = value
		_sync_variations()

var _group: ButtonGroup = ButtonGroup.new()
var _entries: Array[Dictionary] = []
var _selected_id: StringName = &""
var _suppress_signal: bool = false


## Replaces all navigation items; each dictionary is `{id: StringName, text: String, count?: int}`.
func set_items(items: Array) -> void:
	_clear_items()
	var btn_var := _button_variation()
	var count_var := _count_variation()
	for raw_item: Variant in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item := raw_item as Dictionary
		var item_id := StringName(str(item.get("id", "")))
		var item_text := str(item.get("text", ""))
		var idx := _entries.size()

		var btn := Button.new()
		btn.name = String(item_id) if item_id != &"" else "Item%d" % idx
		btn.text = item_text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.theme_type_variation = btn_var
		btn.toggle_mode = true
		btn.button_group = _group
		btn.focus_mode = Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = float(maxi(Tokens.BUTTON_H, Tokens.TARGET_MIN))
		btn.accessibility_name = item_text
		btn.toggled.connect(_on_button_toggled.bind(item_id))
		btn.gui_input.connect(_on_button_gui_input.bind(idx))

		var count_lbl := Label.new()
		count_lbl.name = &"Count"
		count_lbl.theme_type_variation = count_var
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_lbl.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		count_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count_lbl.offset_right = -float(Tokens.S2)
		count_lbl.offset_left = -float(Tokens.S2)
		var count_val := -1
		if item.has("count") and item["count"] != null:
			count_val = int(item["count"])
		if count_val >= 0:
			count_lbl.text = str(count_val)
			count_lbl.visible = true
		else:
			count_lbl.visible = false
		btn.add_child(count_lbl)
		add_child(btn)
		_entries.append({
			"id": item_id,
			"button": btn,
			"count_label": count_lbl,
		})


## Selects the item matching `id`. Emits `selected(id)` only when `emit` is true.
func select(id: StringName, emit: bool = false) -> void:
	var btn := button_for(id)
	if btn == null:
		return
	_suppress_signal = true
	btn.button_pressed = true
	_suppress_signal = false
	_selected_id = id
	if emit:
		selected.emit(id)


## Returns the currently selected item id, or `&""` when none is pressed.
func selected_id() -> StringName:
	var pressed := _group.get_pressed_button()
	if pressed == null:
		return &""
	for entry: Dictionary in _entries:
		if entry["button"] == pressed:
			return entry["id"] as StringName
	return _selected_id


## Updates the right-aligned count badge for `id` (negative count hides the badge).
func set_count(id: StringName, count: int) -> void:
	for entry: Dictionary in _entries:
		if (entry["id"] as StringName) == id:
			var count_lbl := entry["count_label"] as Label
			if count_lbl == null:
				return
			if count < 0:
				count_lbl.text = ""
				count_lbl.visible = false
			else:
				count_lbl.text = str(count)
				count_lbl.visible = true
			return


## Returns the Button corresponding to `id`, or `null` if not found.
func button_for(id: StringName) -> Button:
	for entry: Dictionary in _entries:
		if (entry["id"] as StringName) == id:
			return entry["button"] as Button
	return null


func _button_variation() -> StringName:
	return &"ButtonNavInk" if ink else &"ButtonNav"


func _count_variation() -> StringName:
	return &"LabelInkMuted" if ink else &"Hint"


func _sync_variations() -> void:
	var btn_var := _button_variation()
	var count_var := _count_variation()
	for entry: Dictionary in _entries:
		var btn := entry["button"] as Button
		if btn != null:
			btn.theme_type_variation = btn_var
		var count_lbl := entry["count_label"] as Label
		if count_lbl != null:
			count_lbl.theme_type_variation = count_var


func _clear_items() -> void:
	_selected_id = &""
	_entries.clear()
	for child: Node in get_children():
		if child is BaseButton:
			(child as BaseButton).button_group = null
		remove_child(child)
		child.queue_free()


func _find_target_index(current_idx: int, keycode: Key) -> int:
	if _entries.is_empty():
		return -1
	match keycode:
		KEY_UP:
			return _find_enabled(current_idx - 1, -1)
		KEY_DOWN:
			return _find_enabled(current_idx + 1, 1)
		KEY_HOME:
			return _find_enabled(0, 1)
		KEY_END:
			return _find_enabled(_entries.size() - 1, -1)
	return -1


func _find_enabled(start_idx: int, step: int) -> int:
	var idx := start_idx
	while idx >= 0 and idx < _entries.size():
		var btn := _entries[idx]["button"] as Button
		if btn != null and not btn.disabled:
			return idx
		idx += step
	return -1


func _on_button_toggled(toggled_on: bool, id: StringName) -> void:
	if not toggled_on:
		return
	_selected_id = id
	if not _suppress_signal:
		selected.emit(id)


func _on_button_gui_input(event: InputEvent, idx: int) -> void:
	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed:
		return
	var next_idx := _find_target_index(idx, key_ev.keycode)
	if next_idx < 0:
		return
	var current_btn := _entries[idx]["button"] as Button
	var target_btn := _entries[next_idx]["button"] as Button
	var target_id := _entries[next_idx]["id"] as StringName
	if target_btn != null:
		target_btn.grab_focus()
	if target_id != _selected_id:
		select(target_id, true)
	if current_btn != null:
		current_btn.accept_event()
