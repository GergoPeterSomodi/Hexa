## Schema-driven option row binding a Settings key to an OptionButton, KitSwitch, or KitSlider
## with bidirectional sync and disabled-reason feedback
## (docs/architecture/ui-and-controls-spec.md section 3.5; ui-style-and-feedback-spec.md section 2).
class_name OptionRow
extends VBoxContainer

signal value_applied(key: String, value: Variant)

var _settings: Settings = null
var _key: String = ""
var _platform: String = OS.get_name()
var _control: Control = null
var _choices: Array = []
var _is_int_slider: bool = false
var _syncing: bool = false
var _updating_from_ui: bool = false


func _enter_tree() -> void:
	if _settings != null and not _key.is_empty():
		_connect_settings()
		_sync_control_value(_settings.get_value(_key))


func _exit_tree() -> void:
	_disconnect_settings()


## Binds this row to `key` in `settings`, building the appropriate Theme control from `Settings.SCHEMA`.
func bind(
	settings: Settings,
	key: String,
	platform: String = OS.get_name(),
	choices_override: Array = []
) -> void:
	_disconnect_settings()
	_clear_slot()
	_settings = settings
	_key = key
	_platform = platform
	_choices.clear()
	_is_int_slider = false
	set_disabled_reason(false, "")

	if _settings == null or not Settings.SCHEMA.has(key):
		return

	var entry: Dictionary = Settings.SCHEMA[key]
	var row_label := str(entry.get("label", key))
	var label_node := _label()
	if label_node != null:
		label_node.text = row_label

	var current: Variant = _settings.get_value(key)
	if entry.has("choices") or not choices_override.is_empty():
		_build_choice_control(key, row_label, current, choices_override)
	elif int(entry.get("type", TYPE_NIL)) == TYPE_BOOL:
		_build_switch_control(row_label, bool(current))
	elif entry.has("range") and (int(entry.get("type", TYPE_NIL)) == TYPE_INT or int(entry.get("type", TYPE_NIL)) == TYPE_FLOAT):
		_build_slider_control(key, row_label, entry, current)

	_connect_settings()


## Disables or enables the bound control and displays/hides the reason line and tooltip.
func set_disabled_reason(is_disabled: bool, reason: String = "") -> void:
	if _control != null:
		if _control is BaseButton:
			(_control as BaseButton).disabled = is_disabled
		elif _control is KitSlider:
			(_control as KitSlider).disabled = is_disabled
		_control.tooltip_text = reason if is_disabled else ""
	tooltip_text = reason if is_disabled else ""
	var reason_lbl := _reason_label()
	if reason_lbl != null:
		reason_lbl.text = reason
		reason_lbl.visible = is_disabled and not reason.is_empty()


## Returns the generated input Control inside the slot, or `null` if unbound.
func control() -> Control:
	return _control


## Returns the bound `Settings` key.
func key() -> String:
	return _key


func _build_choice_control(
	setting_key: String,
	row_label: String,
	current: Variant,
	choices_override: Array
) -> void:
	_choices = _resolve_choices(_settings, setting_key, _platform, choices_override)
	var opt := OptionButton.new()
	opt.name = &"ChoiceButton"
	opt.custom_minimum_size.y = float(maxi(Tokens.BUTTON_H, Tokens.TARGET_MIN))
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.accessibility_name = row_label
	for choice: Variant in _choices:
		opt.add_item(_format_choice_label(setting_key, choice))
	_slot().add_child(opt)
	_control = opt
	_sync_choice_selection(opt, current)
	opt.item_selected.connect(_on_option_selected)


func _build_switch_control(row_label: String, current: bool) -> void:
	var sw := KitSwitch.new()
	sw.name = &"Switch"
	sw.text = ""
	sw.accessibility_name = row_label
	sw.size_flags_horizontal = Control.SIZE_SHRINK_END
	sw.set_pressed_no_signal(current)
	_slot().add_child(sw)
	_control = sw
	sw.toggled.connect(_on_switch_toggled)


func _build_slider_control(
	setting_key: String,
	row_label: String,
	entry: Dictionary,
	current: Variant
) -> void:
	var bounds: Array = entry["range"]
	_is_int_slider = int(entry.get("type", TYPE_INT)) == TYPE_INT
	var step_val := 1.0 if _is_int_slider else 0.01
	var sl := KitSlider.new()
	sl.name = &"Slider"
	sl.format_int = _is_int_slider
	sl.suffix = _slider_suffix(setting_key)
	sl.set_bounds(float(bounds[0]), float(bounds[1]), step_val)
	sl.set_slider_value(float(current), false)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.slider().accessibility_name = row_label
	_slot().add_child(sl)
	_control = sl
	sl.value_changed.connect(_on_slider_changed)


func _resolve_choices(
	settings: Settings,
	setting_key: String,
	platform: String,
	choices_override: Array
) -> Array:
	if not choices_override.is_empty():
		return choices_override.duplicate()
	var list := settings.choices_for(setting_key)
	if setting_key == "display/window_mode" and platform != "Windows":
		list.erase("exclusive")
	return list


func _format_choice_label(setting_key: String, choice: Variant) -> String:
	if typeof(choice) == TYPE_INT:
		var num := int(choice)
		if setting_key == "display/fps_cap" and num == 0:
			return "Unlimited"
		if setting_key == "display/background_fps" and num == 0:
			return "Paused"
		return str(num)
	var s := str(choice)
	if setting_key == "display/ui_scale" and s != "auto":
		return "%s%%" % s
	if s in ["1x", "2x"]:
		return s
	if s.contains("x") and s.length() > 0 and s.substr(0, 1).is_valid_int():
		return s
	var words := s.replace("_", " ")
	if words.is_empty():
		return words
	return words.substr(0, 1).to_upper() + words.substr(1)


func _slider_suffix(setting_key: String) -> String:
	if setting_key in [
		"controls/pan_speed",
		"controls/zoom_speed",
		"controls/edge_pan_speed",
		"map/grid_opacity",
		"accessibility/text_size",
	] or setting_key.begins_with("audio/"):
		return "%"
	if setting_key == "dev/slice_ms":
		return " ms"
	return ""


func _sync_control_value(value: Variant) -> void:
	if _control == null:
		return
	_syncing = true
	if _control is OptionButton:
		_sync_choice_selection(_control as OptionButton, value)
	elif _control is KitSwitch:
		(_control as KitSwitch).set_pressed_no_signal(bool(value))
	elif _control is KitSlider:
		(_control as KitSlider).set_slider_value(float(value), false)
	_syncing = false


func _sync_choice_selection(opt: OptionButton, value: Variant) -> void:
	for i: int in range(_choices.size()):
		var choice: Variant = _choices[i]
		if typeof(choice) == typeof(value) and choice == value:
			opt.select(i)
			return


func _connect_settings() -> void:
	if _settings != null and not _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.connect(_on_settings_changed)


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)


func _clear_slot() -> void:
	_control = null
	var slot := _slot()
	if slot == null:
		return
	for child: Node in slot.get_children():
		slot.remove_child(child)
		child.queue_free()


func _label() -> Label:
	return get_node_or_null("MainRow/Label") as Label


func _slot() -> HBoxContainer:
	return get_node_or_null("MainRow/Slot") as HBoxContainer


func _reason_label() -> Label:
	return get_node_or_null("Reason") as Label


func _on_option_selected(idx: int) -> void:
	if _syncing or _settings == null or idx < 0 or idx >= _choices.size():
		return
	var chosen: Variant = _choices[idx]
	_apply_to_settings(chosen)


func _on_switch_toggled(pressed: bool) -> void:
	if _syncing or _settings == null:
		return
	_apply_to_settings(pressed)


func _on_slider_changed(new_value: float) -> void:
	if _syncing or _settings == null:
		return
	var typed_val: Variant = roundi(new_value) if _is_int_slider else new_value
	_apply_to_settings(typed_val)


func _apply_to_settings(value: Variant) -> void:
	_updating_from_ui = true
	var applied := _settings.set_value(_key, value)
	_updating_from_ui = false
	if applied:
		value_applied.emit(_key, value)


func _on_settings_changed(changed_key: String, new_value: Variant) -> void:
	if _updating_from_ui or changed_key != _key:
		return
	_sync_control_value(new_value)
