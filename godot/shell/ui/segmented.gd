## Segmented toggle group inside a PanelSlot container
## (docs/architecture/ui-and-controls-spec.md section 3.5; ui-style-and-feedback-spec.md section 5).
class_name Segmented
extends PanelContainer

signal changed(id: Variant)

@export var hud_mode: bool = false:
	set(value):
		hud_mode = value
		_sync_focus_mode()

var _hbox: HBoxContainer = null
var _group: ButtonGroup = ButtonGroup.new()
var _entries: Array[Dictionary] = []
var _selected_id: Variant = null
var _suppress_signal: bool = false


func _init() -> void:
	theme_type_variation = &"PanelSlot"
	_hbox = HBoxContainer.new()
	_hbox.name = &"Buttons"
	_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_hbox)


## Replaces the toggle options with `items`, each `{id: Variant, label: String, tooltip?: String}`.
func set_options(items: Array) -> void:
	_clear_options()
	for raw_item: Variant in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item := raw_item as Dictionary
		var item_id: Variant = item.get("id", null)
		var btn := Button.new()
		btn.text = str(item.get("label", ""))
		btn.tooltip_text = str(item.get("tooltip", ""))
		btn.theme_type_variation = &"ButtonTab"
		btn.toggle_mode = true
		btn.button_group = _group
		btn.custom_minimum_size.y = float(maxi(Tokens.BUTTON_H, Tokens.TARGET_MIN))
		btn.focus_mode = Control.FOCUS_NONE if hud_mode else Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggled.connect(_on_button_toggled.bind(item_id))
		_hbox.add_child(btn)
		_entries.append({"id": item_id, "button": btn})


## Selects the button matching `id`. Emits `changed(id)` only when `emit` is true.
func select(id: Variant, emit: bool = false) -> void:
	var btn := button_for(id)
	if btn == null:
		return
	_suppress_signal = true
	btn.button_pressed = true
	_suppress_signal = false
	_selected_id = id
	if emit:
		changed.emit(id)


## Returns the currently selected option id, or `null` if none is pressed.
func selected_id() -> Variant:
	var pressed := _group.get_pressed_button()
	if pressed == null:
		return null
	for entry: Dictionary in _entries:
		if entry["button"] == pressed:
			return entry["id"]
	return _selected_id


## Returns the Button corresponding to `id`, or `null` if not found.
func button_for(id: Variant) -> Button:
	for entry: Dictionary in _entries:
		var entry_id: Variant = entry["id"]
		if typeof(entry_id) == typeof(id) and entry_id == id:
			return entry["button"] as Button
	return null


func _clear_options() -> void:
	_selected_id = null
	_entries.clear()
	for child: Node in _hbox.get_children():
		_hbox.remove_child(child)
		child.queue_free()


func _sync_focus_mode() -> void:
	var mode := Control.FOCUS_NONE if hud_mode else Control.FOCUS_ALL
	for entry: Dictionary in _entries:
		var btn := entry["button"] as Button
		if btn != null:
			btn.focus_mode = mode


func _on_button_toggled(toggled_on: bool, id: Variant) -> void:
	if not toggled_on:
		return
	_selected_id = id
	if not _suppress_signal:
		changed.emit(id)
