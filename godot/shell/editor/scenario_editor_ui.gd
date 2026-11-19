## Standalone runtime toolbar and inspector panel for ScenarioEditor (hidden when running inside the Godot editor).
class_name ScenarioEditorUi
extends CanvasLayer

const BRUSH_SPECS: Array[Array] = [
	[0, "Inspect"],
	[1, "Pin Country"],
	[2, "Pin No One"],
	[3, "Erase Pin"],
	[4, "Seed Town"],
	[5, "Seed Anchor"],
	[6, "Erase Seed"],
]

var _editor: Node = null
var _brush_buttons: Dictionary[int, Button] = {}
var _country_select: OptionButton = null
var _mode_select: OptionButton = null
var _cb_check: CheckBox = null
var _seeds_check: CheckBox = null
var _live_check: CheckBox = null
var _status_label: Label = null
var _hover_label: Label = null
var _facts_box: TextEdit = null
var _root_panel: Control = null


## Builds the runtime palette, mode controls, action buttons, and facts display bound to `editor`.
func setup(editor: Node) -> void:
	_editor = editor
	layer = 10
	_build_layout()
	sync_from_editor()


## Returns true when `screen_pos` lies over an interactive editor UI panel.
func covers_point(screen_pos: Vector2) -> bool:
	if not visible or _root_panel == null:
		return false
	for child: Node in _root_panel.get_children():
		if child is Control:
			var ctrl := child as Control
			if ctrl.visible and ctrl.get_global_rect().has_point(screen_pos):
				return true
	return false


## Updates hover readout in the top status strip.
func set_hover_text(text: String) -> void:
	if _hover_label != null:
		_hover_label.text = text


## Updates the validation status badge text and tone.
func set_status(text: String, ok: bool) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.modulate = Tokens.GOOD if ok else Tokens.BAD


## Synchronizes control states, country list, and facts text from the bound ScenarioEditor.
func sync_from_editor() -> void:
	if _editor == null:
		return
	var active_brush := int(_editor.get("active_brush"))
	for bid: int in _brush_buttons:
		_brush_buttons[bid].set_pressed_no_signal(bid == active_brush)
	_sync_countries()
	if _mode_select != null:
		_mode_select.select(int(_editor.get("mode")))
	if _cb_check != null:
		_cb_check.set_pressed_no_signal(bool(_editor.get("colour_blind")))
	if _seeds_check != null:
		_seeds_check.set_pressed_no_signal(bool(_editor.get("show_seeds")))
	if _live_check != null:
		_live_check.set_pressed_no_signal(bool(_editor.get("live_regrow")))
	if _facts_box != null:
		_facts_box.text = str(_editor.get("facts"))


func _build_layout() -> void:
	_root_panel = Control.new()
	_root_panel.name = "Root"
	_root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_panel)

	var top_bar := _make_panel()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = float(Tokens.S2)
	top_bar.offset_top = float(Tokens.S2)
	top_bar.offset_right = -float(Tokens.S2)
	top_bar.offset_bottom = 52.0
	_root_panel.add_child(top_bar)
	_build_top_bar(top_bar)

	var side := _make_panel()
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_top = 0.0
	side.anchor_bottom = 1.0
	side.offset_left = -336.0
	side.offset_right = -float(Tokens.S2)
	side.offset_top = 60.0
	side.offset_bottom = -float(Tokens.S2)
	_root_panel.add_child(side)
	_build_side_panel(side)


func _build_top_bar(container: PanelContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.S2)
	container.add_child(row)

	var title := Label.new()
	title.text = "Scenario Editor"
	title.modulate = Tokens.GOLD
	row.add_child(title)

	for spec: Array in BRUSH_SPECS:
		var bid := int(spec[0])
		var btn := Button.new()
		btn.text = str(spec[1])
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func() -> void:
			_editor.call("set_active_brush", bid)
			sync_from_editor())
		row.add_child(btn)
		_brush_buttons[bid] = btn

	_country_select = OptionButton.new()
	_country_select.focus_mode = Control.FOCUS_NONE
	_country_select.custom_minimum_size = Vector2(160.0, 0.0)
	_country_select.item_selected.connect(_on_country_selected)
	row.add_child(_country_select)

	_hover_label = Label.new()
	_hover_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hover_label.text = "Wheel: zoom  Right/Mid drag or WASD: pan"
	_hover_label.modulate = Tokens.MUTED
	row.add_child(_hover_label)


func _build_side_panel(container: PanelContainer) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.S2)
	container.add_child(col)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", Tokens.S2)
	col.add_child(mode_row)
	var mode_lbl := Label.new()
	mode_lbl.text = "Mode:"
	mode_row.add_child(mode_lbl)
	_mode_select = OptionButton.new()
	_mode_select.focus_mode = Control.FOCUS_NONE
	_mode_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_select.add_item("Terrain", MapModes.Mode.TERRAIN)
	_mode_select.add_item("Owner", MapModes.Mode.OWNER)
	_mode_select.add_item("Relief", MapModes.Mode.RELIEF)
	_mode_select.item_selected.connect(func(idx: int) -> void:
		_editor.set("mode", _mode_select.get_item_id(idx)))
	mode_row.add_child(_mode_select)

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", Tokens.S2)
	col.add_child(toggles)
	_cb_check = _make_toggle("CB", func(on: bool) -> void: _editor.set("colour_blind", on))
	_seeds_check = _make_toggle("Seeds", func(on: bool) -> void: _editor.set("show_seeds", on))
	_live_check = _make_toggle("Live", func(on: bool) -> void: _editor.set("live_regrow", on))
	toggles.add_child(_cb_check)
	toggles.add_child(_seeds_check)
	toggles.add_child(_live_check)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Tokens.S2)
	col.add_child(actions)
	actions.add_child(_make_action("Regrow", func() -> void: _editor.call("regrow")))
	actions.add_child(_make_action("Write", func() -> void: _editor.call("write")))
	actions.add_child(_make_action("Check", func() -> void: _editor.call("check")))
	actions.add_child(_make_action("Fit", func() -> void: _editor.call("fit_view")))

	_status_label = Label.new()
	_status_label.text = "Ready"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status_label)

	_facts_box = TextEdit.new()
	_facts_box.editable = false
	_facts_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_facts_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_facts_box)


func _sync_countries() -> void:
	if _country_select == null or _editor == null:
		return
	var scen := _editor.get("scenario") as ScenarioDef
	var defs := _editor.call("defs") as GameDefs
	_country_select.clear()
	if scen == null:
		return
	var active := StringName(_editor.get("active_country"))
	var select_idx := 0
	for i: int in scen.countries.size():
		var tag := scen.countries[i]
		var cdef := defs.country(tag) if defs != null else null
		var label := "%s — %s" % [String(tag), cdef.name] if cdef != null else String(tag)
		_country_select.add_item(label, i)
		_country_select.set_item_metadata(i, tag)
		if tag == active:
			select_idx = i
	if scen.countries.size() > 0:
		_country_select.select(select_idx)


func _on_country_selected(idx: int) -> void:
	if _country_select == null or _editor == null:
		return
	var tag := StringName(str(_country_select.get_item_metadata(idx)))
	_editor.call("set_active_country", tag)


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Tokens.PANEL_BG, 0.92)
	box.border_color = Tokens.LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(Tokens.S2)
	panel.add_theme_stylebox_override("panel", box)
	return panel


func _make_toggle(text: String, cb: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(cb)
	return box


func _make_action(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(cb)
	return btn
