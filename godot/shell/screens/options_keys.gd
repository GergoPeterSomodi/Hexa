## Keybindings sub-section helper for the Options Controls page: renders Bindings.DEFAULTS rows
## with live KeyCaps, key capture with conflict detection, and Reset keys
## (docs/architecture/ui-and-controls-spec.md sections 6.4 and 6.7).
class_name OptionsKeys
extends RefCounted

var _hint: Label = null
var _reset_btn: KitButton = null
var _action_caps: Dictionary[StringName, HBoxContainer] = {}
var _rebind_buttons: Dictionary[StringName, KitButton] = {}
var _capturing_action: StringName = &""
var _settings: Settings = null


func build(parent_vbox: VBoxContainer, settings: Settings) -> void:
	_settings = settings
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_vbox.add_child(sep)

	var head := Label.new()
	head.name = &"KeysSectionHead"
	head.theme_type_variation = &"SectionHead"
	head.text = "Keys"
	parent_vbox.add_child(head)

	var bar := HBoxContainer.new()
	bar.name = &"KeysToolbar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_vbox.add_child(bar)

	_hint = Label.new()
	_hint.name = &"KeysHint"
	_hint.theme_type_variation = &"Hint"
	_hint.text = "Click a key or Rebind, then press a new key. Esc cancels."
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_hint)

	_reset_btn = KitButton.new()
	_reset_btn.name = &"ResetKeysButton"
	_reset_btn.kind = KitButton.Kind.SMALL
	_reset_btn.text = "Reset keys"
	_reset_btn.pressed.connect(reset_all)
	bar.add_child(_reset_btn)

	if not InputMap.has_action(&"app_back"):
		Bindings.ensure()

	for group_name: String in Bindings.GROUPS:
		_add_group(parent_vbox, group_name)


func set_settings(settings: Settings) -> void:
	_settings = settings


func set_reduce_motion(reduce: bool) -> void:
	if _reset_btn != null:
		_reset_btn.reduce_motion = reduce
	for action: StringName in _rebind_buttons:
		var btn := _rebind_buttons[action]
		if btn != null:
			btn.reduce_motion = reduce


func capturing_action() -> StringName:
	return _capturing_action


func hint_label() -> Label:
	return _hint


func reset_button() -> KitButton:
	return _reset_btn


func rebind_button_for(action: StringName) -> KitButton:
	return _rebind_buttons.get(action, null) as KitButton


func key_caps_for(action: StringName) -> Array[KeyCap]:
	var box := _action_caps.get(action, null) as HBoxContainer
	var out: Array[KeyCap] = []
	if box == null:
		return out
	for child: Node in box.get_children():
		if child is KeyCap:
			out.append(child as KeyCap)
	return out


func begin_rebind(action: StringName) -> void:
	if not _action_caps.has(action):
		return
	if _capturing_action != &"":
		cancel_rebind()
	_capturing_action = action
	var caps := key_caps_for(action)
	if not caps.is_empty():
		caps[0].waiting = true
	if _hint != null:
		_hint.theme_type_variation = &"Hint"
		_hint.text = "Press a new key for %s (Esc cancels)..." % _label_for_action(action)


func cancel_rebind() -> void:
	if _capturing_action == &"":
		return
	var prev := _capturing_action
	_capturing_action = &""
	_rebuild_action_caps(prev)
	if _hint != null:
		_hint.theme_type_variation = &"Hint"
		_hint.text = "Click a key or Rebind, then press a new key. Esc cancels."


func handle_key_event(key_ev: InputEventKey) -> bool:
	if _capturing_action == &"" or key_ev == null or not key_ev.pressed or key_ev.is_echo():
		return false
	var code: Key = key_ev.keycode if key_ev.keycode != KEY_NONE else key_ev.physical_keycode
	if code == KEY_ESCAPE and not key_ev.ctrl_pressed and not key_ev.alt_pressed and not key_ev.shift_pressed and not key_ev.meta_pressed:
		cancel_rebind()
		return true
	if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK, KEY_NONE]:
		return true
	_commit_rebind(_capturing_action, key_ev)
	return true


func reset_all() -> void:
	cancel_rebind()
	Bindings.reset_defaults()
	if _settings != null:
		_settings.clear_key_overrides()
	refresh_all()
	if _hint != null:
		_hint.theme_type_variation = &"NumberGood"
		_hint.text = "Key bindings reset to defaults."


func refresh_all() -> void:
	for action: StringName in _action_caps:
		_rebuild_action_caps(action)


func _add_group(vbox: VBoxContainer, group_name: String) -> void:
	var group_hdr := Label.new()
	group_hdr.theme_type_variation = &"TableHeader"
	group_hdr.text = group_name
	vbox.add_child(group_hdr)

	for entry: Dictionary in Bindings.DEFAULTS:
		if str(entry["group"]) != group_name:
			continue
		var action: StringName = entry["action"]
		var row := HBoxContainer.new()
		row.name = "KeyRow_" + String(action)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.theme_type_variation = &"TableRow"
		lbl.text = str(entry["label"])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		row.add_child(lbl)

		var caps_box := HBoxContainer.new()
		caps_box.name = &"Caps"
		caps_box.alignment = BoxContainer.ALIGNMENT_END
		caps_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(caps_box)
		_action_caps[action] = caps_box

		var is_mouse := _is_mouse_only(entry)
		var rebind_btn := KitButton.new()
		rebind_btn.name = &"RebindButton"
		rebind_btn.kind = KitButton.Kind.SMALL
		rebind_btn.text = "Rebind"
		rebind_btn.accessibility_name = "Rebind %s" % str(entry["label"])
		if is_mouse:
			rebind_btn.set_verdict({"ok": false, "reason": "Mouse binding"})
		else:
			rebind_btn.pressed.connect(begin_rebind.bind(action))
		row.add_child(rebind_btn)
		_rebind_buttons[action] = rebind_btn
		_rebuild_action_caps(action)


func _commit_rebind(action: StringName, key_ev: InputEventKey) -> void:
	var normalized := InputEventKey.new()
	normalized.pressed = true
	var entry := _entry_for_action(action)
	var code: Key = key_ev.keycode if key_ev.keycode != KEY_NONE else key_ev.physical_keycode
	if bool(entry.get("physical", false)):
		normalized.physical_keycode = code
	else:
		normalized.keycode = code
	normalized.shift_pressed = key_ev.shift_pressed
	normalized.alt_pressed = key_ev.alt_pressed
	if key_ev.ctrl_pressed and not key_ev.meta_pressed:
		normalized.command_or_control_autoremap = true
	else:
		normalized.ctrl_pressed = key_ev.ctrl_pressed
		normalized.meta_pressed = key_ev.meta_pressed

	var serialized := Bindings.serialize_event(normalized)
	var res := Bindings.apply_overrides({String(action): serialized})
	_capturing_action = &""
	_rebuild_action_caps(action)

	if not bool(res.get("ok", false)):
		var conflicts: Dictionary = res.get("conflicts", {})
		var clash_id := StringName(str(conflicts.get(action, &"")))
		var clash_label := _label_for_action(clash_id) if clash_id != &"" else "another action"
		if _hint != null:
			_hint.theme_type_variation = &"NumberBad"
			_hint.text = "Key %s conflicts with %s." % [Bindings.event_text(normalized), clash_label]
		return

	if _settings != null:
		_settings.set_key_override(String(action), serialized)
	if _hint != null:
		_hint.theme_type_variation = &"NumberGood"
		_hint.text = "Bound %s to %s." % [_label_for_action(action), Bindings.event_text(normalized)]


func _rebuild_action_caps(action: StringName) -> void:
	var box := _action_caps.get(action, null) as HBoxContainer
	if box == null:
		return
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var plat := _settings.platform if _settings != null else OS.get_name()
	var caps := Bindings.key_caps_for(action, plat)
	var is_mouse := _is_mouse_only(_entry_for_action(action))
	if caps.is_empty():
		var empty_cap := KeyCap.new()
		empty_cap.action = action
		box.add_child(empty_cap)
		return
	for i: int in caps.size():
		var cap := KeyCap.new()
		if i == 0 and plat == OS.get_name():
			cap.action = action
		else:
			cap.key_text = caps[i]
		if not is_mouse and i == 0:
			cap.gui_input.connect(_on_key_cap_gui_input.bind(action))
		box.add_child(cap)


func _on_key_cap_gui_input(event: InputEvent, action: StringName) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		begin_rebind(action)


func _is_mouse_only(entry: Dictionary) -> bool:
	for ev: Variant in (entry.get("events", []) as Array):
		if str(ev).begins_with("Mouse"):
			return true
	return false


func _entry_for_action(action: StringName) -> Dictionary:
	for entry: Dictionary in Bindings.DEFAULTS:
		if (entry["action"] as StringName) == action:
			return entry
	return {}


func _label_for_action(action: StringName) -> String:
	var entry := _entry_for_action(action)
	if entry.is_empty():
		return String(action)
	return str(entry.get("label", String(action)))
