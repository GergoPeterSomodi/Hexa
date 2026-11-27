## Non-pausing Studiolo help overlay listing every Bindings.DEFAULTS action with live bone KeyCaps
## in three columns plus platform gesture lines and the line that army moves are final (moves-build-spec.md R54), and marking
## state/help_seen on enter
## (docs/architecture/ui-and-controls-spec.md section 4.6;
## docs/architecture/ui-style-and-feedback-spec.md section 2).
class_name HelpOverlay
extends Screen

const COLUMN_GROUPS: Array[Array] = [
	["Camera"],
	["Map", "View", "Developer"],
	["Game", "App"],
]

@export var platform_override: String = ""

@onready var _frame: ModalFrame = $Center/Frame

var _columns: Array[VBoxContainer] = []
var _action_caps: Dictionary[StringName, HBoxContainer] = {}
var _action_labels: Dictionary[StringName, Label] = {}
var _gestures_box: VBoxContainer = null
var _moves_note: Label = null
var _close_btn: KitButton = null
var _connected_settings: Settings = null
var _ui_built: bool = false
var _just_refreshed: bool = false


## Returns true when first-run help has not yet been shown (`state/help_seen == false`).
static func should_auto_open(settings: Settings) -> bool:
	if settings == null:
		return false
	return not bool(settings.get_value("state/help_seen"))


## Pushes HelpOverlay onto `context.stack` once if `state/help_seen` is false, returning it or null.
static func open_if_unseen(context: ShellContext) -> HelpOverlay:
	if context == null or not should_auto_open(context.settings):
		return null
	if context.stack == null or not context.stack.has_method(&"push"):
		return null
	var overlay := ScreenIds.make(&"help") as HelpOverlay
	if overlay == null:
		return null
	context.stack.call(&"push", overlay)
	return overlay


func _ready() -> void:
	_ensure_ui()
	refresh_bindings()
	_just_refreshed = true


func _exit_tree() -> void:
	_disconnect_settings()


func on_enter() -> void:
	_ensure_ui()
	_close_btn.reduce_motion = _reduce_motion()
	# _ready has just drawn every key cap; a second pass on the same frame would only repeat it.
	if not _just_refreshed:
		refresh_bindings()
	_just_refreshed = false
	_connect_settings()
	if ctx != null and ctx.settings != null:
		ctx.settings.set_value("state/help_seen", true)


func on_exit() -> void:
	_disconnect_settings()


func back() -> bool:
	return false


func frame() -> ModalFrame:
	_ensure_ui()
	return _frame


func close_button() -> KitButton:
	_ensure_ui()
	return _close_btn


func column_count() -> int:
	_ensure_ui()
	return _columns.size()


func columns() -> Array[VBoxContainer]:
	_ensure_ui()
	return _columns


func key_caps_for_action(action: StringName) -> Array[KeyCap]:
	_ensure_ui()
	var box := _action_caps.get(action, null) as HBoxContainer
	var out: Array[KeyCap] = []
	if box == null:
		return out
	for child: Node in box.get_children():
		if child is KeyCap:
			out.append(child as KeyCap)
	return out


func gesture_lines() -> Array[String]:
	_ensure_ui()
	var out: Array[String] = []
	if _gestures_box == null:
		return out
	for child: Node in _gestures_box.get_children():
		if child is Label:
			out.append((child as Label).text)
	return out


## The line about army moves (R54).
func moves_note() -> String:
	_ensure_ui()
	return _moves_note.text if _moves_note != null else ""


## Refreshes every action's KeyCap badges from the live InputMap and platform gesture lines.
func refresh_bindings(p_platform: String = "") -> void:
	_ensure_ui()
	if not InputMap.has_action(&"app_back"):
		Bindings.ensure()
	var plat := _resolve_platform(p_platform)
	for action: StringName in _action_caps:
		_rebuild_action_caps(action, _action_caps[action], plat)
	_rebuild_gestures(plat)


func _ensure_ui() -> void:
	if _ui_built:
		return
	if _frame == null:
		_frame = get_node_or_null("Center/Frame") as ModalFrame
	if _frame == null:
		return
	_ui_built = true
	_frame.closed.connect(_on_close_pressed)

	var body := _frame.body()
	var cols_row := HBoxContainer.new()
	cols_row.name = &"Columns"
	cols_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(cols_row)

	_columns.clear()
	for idx: int in 3:
		var col := VBoxContainer.new()
		col.name = "Col%d" % idx
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cols_row.add_child(col)
		_columns.append(col)

	for col_idx: int in COLUMN_GROUPS.size():
		var col := _columns[col_idx]
		var group_names: Array = COLUMN_GROUPS[col_idx]
		for group_name: String in group_names:
			_add_group_section(col, group_name)

	var gesture_head := _make_section_head("Pointer & Gestures")
	_columns[2].add_child(gesture_head)
	_columns[2].add_child(_make_rule())
	_gestures_box = VBoxContainer.new()
	_gestures_box.name = &"Gestures"
	_gestures_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gestures_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_columns[2].add_child(_gestures_box)

	_moves_note = Label.new()
	_moves_note.name = &"MovesNote"
	_moves_note.theme_type_variation = &"Hint"
	_moves_note.text = KeyHints.MOVES_NOTE
	_moves_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_moves_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns[2].add_child(_moves_note)

	var foot := _frame.footer()
	var note := Label.new()
	note.theme_type_variation = &"Hint"
	note.text = "Press Esc or F1 to return to the map."
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(note)

	_close_btn = KitButton.new()
	_close_btn.name = &"CloseButton"
	_close_btn.kind = KitButton.Kind.PRIMARY
	_close_btn.text = "Close"
	_close_btn.hotkey_action = &"app_back"
	_close_btn.pressed.connect(_on_close_pressed)
	foot.add_child(_close_btn)
	default_focus = get_path_to(_close_btn)


func _add_group_section(parent_col: VBoxContainer, group_name: String) -> void:
	parent_col.add_child(_make_section_head(group_name))
	parent_col.add_child(_make_rule())
	for entry: Dictionary in Bindings.DEFAULTS:
		if str(entry["group"]) != group_name:
			continue
		var action: StringName = entry["action"]
		var label_text := str(entry["label"])
		var row := HBoxContainer.new()
		row.name = String(action)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lbl := Label.new()
		lbl.name = &"Label"
		lbl.theme_type_variation = &"TableRow"
		lbl.text = label_text
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		row.add_child(lbl)
		_action_labels[action] = lbl

		var caps_box := HBoxContainer.new()
		caps_box.name = &"Caps"
		caps_box.alignment = BoxContainer.ALIGNMENT_END
		caps_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(caps_box)
		_action_caps[action] = caps_box

		parent_col.add_child(row)


func _make_section_head(title_text: String) -> Label:
	var head := Label.new()
	head.theme_type_variation = &"SectionHead"
	head.text = title_text
	return head


func _make_rule() -> HSeparator:
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep


func _rebuild_action_caps(action: StringName, caps_box: HBoxContainer, platform: String) -> void:
	for child: Node in caps_box.get_children():
		caps_box.remove_child(child)
		child.queue_free()
	var caps := Bindings.key_caps_for(action, platform)
	if caps.is_empty():
		var empty_cap := KeyCap.new()
		empty_cap.action = action
		caps_box.add_child(empty_cap)
		return
	for idx: int in caps.size():
		var cap := KeyCap.new()
		if idx == 0 and platform == OS.get_name():
			cap.action = action
		else:
			cap.key_text = caps[idx]
			cap.accessibility_name = "%s: %s" % [String(action), caps[idx]]
		caps_box.add_child(cap)


func _rebuild_gestures(platform: String) -> void:
	if _gestures_box == null:
		return
	for child: Node in _gestures_box.get_children():
		_gestures_box.remove_child(child)
		child.queue_free()
	for line: String in Bindings.gestures_for(platform):
		var lbl := Label.new()
		lbl.theme_type_variation = &"Hint"
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_gestures_box.add_child(lbl)


func _resolve_platform(p_platform: String) -> String:
	if not p_platform.is_empty():
		return p_platform
	if not platform_override.is_empty():
		return platform_override
	if ctx != null and ctx.settings != null:
		return ctx.settings.platform
	return OS.get_name()


func _connect_settings() -> void:
	if ctx == null or ctx.settings == null:
		return
	if _connected_settings == ctx.settings:
		return
	_disconnect_settings()
	_connected_settings = ctx.settings
	_connected_settings.changed.connect(_on_setting_changed)


func _disconnect_settings() -> void:
	if _connected_settings != null and _connected_settings.changed.is_connected(_on_setting_changed):
		_connected_settings.changed.disconnect(_on_setting_changed)
	_connected_settings = null


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key.begins_with("keys/"):
		refresh_bindings()


func _on_close_pressed() -> void:
	finished.emit(&"close")


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false
