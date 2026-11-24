## Chancellor's report: the season that ended, drawn on a Studiolo VellumSheet (docs/architecture/m3-build-spec.md 6.4;
## ui-style-and-feedback-spec.md 6.8). Input is one SeasonSummary.of dictionary (or tests/fixtures/report_sample.gd).
## A link or an action button closes the report and asks the App to glide to the hex; "Open the study" (a KeyCap of I, and a
## line's action [&"study", page]) closes it and asks the App for the study (spec 6.8); Space, Enter, Esc and the primary
## button close it. The Full, Brief, Off setting is written to `game/season_report`.
## show_summary() fills the sheet once per instance: the sheet keeps its sections, so a report is a fresh screen each time.
class_name SeasonReport
extends Screen

signal link_chosen(hex: Vector2i, action: Array)
signal closed(reason: StringName)

const NO_HEX := Vector2i(-1, -1)
const CHIP_LIMIT: int = 5
const LOOK_ACTIONS: Array[StringName] = [&"look_at", &"select"]
const STUDY_ACTION := &"study"
const STUDY_PAGE := &"economy"
const STUDY_LABEL := "Open the study"
const ARMY_ACTION := &"select_army"
## M7 (spec 6.10): a battle line of the War section asks [&"battle", record]; the App opens the battle dock at that record.
const BATTLE_ACTION := &"battle"
const CLOSE_KEYS: Array[Key] = [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
const SHEET_MAX_W: float = 900.0
const SHEET_MAX_H: float = 800.0
const SIDE_MARGIN: float = 24.0
const FALLBACK_VIEW: Vector2 = Vector2(1280.0, 720.0)
## The ribbon overhangs the sheet's top edge by 46 px and the seal by 54 px: the sheet starts this far below the inset.
const TOP_CLEAR: float = 60.0
const BOTTOM_MARGIN: float = 16.0
const SETTING_KEY: String = "game/season_report"
const SETTING_CHOICES: Array[Dictionary] = [
	{"id": "full", "label": "Full"},
	{"id": "brief", "label": "Brief"},
	{"id": "off", "label": "Off"},
]

var _sheet: VellumSheet = null
var _seg: Segmented = null
var _begin_btn: KitButton = null
var _study_btn: KitButton = null
var _summary: Dictionary = {}
var _reopened: bool = false
var _body_filled: bool = false
var _closed: bool = false
var _ui_built: bool = false
var _serial: int = 0
var _insets: Array[MarginContainer] = []  # the "What befell" label insets, set to the theme's link inset (_apply_insets)


## Builds the frame and footer once; safe before the screen enters the tree.
func _ensure_ui() -> void:
	if _ui_built:
		return
	if _sheet == null:
		_sheet = get_node_or_null("Center/Sheet") as VellumSheet
	if _sheet == null:
		return
	_ui_built = true
	_sheet.show_nav = true
	_build_footer()
	resized.connect(_apply_layout)
	_apply_layout()


## Places the sheet under the top bar's real bottom edge (ShellContext.top_inset) with room for the overhang, and fills
## the height left above the bottom margin, so the footer stays on screen at 1280 x 720.
func _apply_layout() -> void:
	var center := get_node_or_null("Center") as CenterContainer
	if center == null or _sheet == null:
		return
	var inset := ctx.top_inset() if ctx != null else float(Tokens.BAR_H + Tokens.S2)
	center.offset_top = inset + TOP_CLEAR
	center.offset_bottom = -BOTTOM_MARGIN
	center.offset_left = SIDE_MARGIN
	center.offset_right = -SIDE_MARGIN
	# Before the screen is in the tree there is no viewport: on_enter lays out again once it is.
	var view := get_viewport_rect().size if is_inside_tree() else FALLBACK_VIEW
	var avail_w := view.x - 2.0 * SIDE_MARGIN
	var avail_h := view.y - inset - TOP_CLEAR - BOTTOM_MARGIN
	_sheet.custom_minimum_size = Vector2(
		clampf(avail_w, 0.0, SHEET_MAX_W),
		clampf(avail_h, 0.0, SHEET_MAX_H)
	)


func _ready() -> void:
	_ensure_ui()
	_apply_insets()


## Fills the sheet from a SeasonSummary.of dictionary. `reopened` true when J or the log reopened an older report
## (the primary button then says "Back to the map").
func show_summary(summary: Dictionary, reopened: bool = false) -> void:
	_ensure_ui()
	if _sheet == null:
		return
	_summary = summary.duplicate(true)
	_reopened = reopened
	_apply_layout()
	_sheet.title = str(_summary.get("title", ""))
	_sheet.lede = str(_summary.get("lede", ""))
	_sheet.seal_letter = str(_summary.get("seal_letter", ""))
	_sheet.seal_tone = &"plain" if bool(_summary.get("quiet", false)) else &"vermilion"
	_begin_btn.text = _begin_text()
	if _body_filled:
		push_error("SeasonReport.show_summary: the sheet is filled once per instance")
		return
	_body_filled = true
	_fill_sections()


func on_enter() -> void:
	_ensure_ui()
	_apply_layout()
	_apply_insets()
	if ctx != null and not ctx.top_inset_changed.is_connected(_apply_layout):
		ctx.top_inset_changed.connect(_apply_layout)
	var reduce := _reduce_motion()
	_begin_btn.reduce_motion = reduce
	_seg.select(_current_setting(), false)
	_sheet.press_seal(reduce)
	if is_inside_tree():
		default_focus = get_path_to(_begin_btn)


func on_exit() -> void:
	if ctx != null and ctx.top_inset_changed.is_connected(_apply_layout):
		ctx.top_inset_changed.disconnect(_apply_layout)
	if not _closed:
		_closed = true
		closed.emit(&"back")
	if ctx != null:
		ctx.request(&"report_closed")


## Esc: the stack pops the report (on_exit closes it).
func back() -> bool:
	return false


func sheet() -> VellumSheet:
	_ensure_ui()
	return _sheet


func begin_button() -> KitButton:
	_ensure_ui()
	return _begin_btn


func segmented() -> Segmented:
	_ensure_ui()
	return _seg


## Every link and action button of the body (names "Link…" and "Action…"), in order.
func link_buttons() -> Array[Button]:
	var out: Array[Button] = []
	if _sheet == null:
		return out
	_collect_buttons(_sheet.body(), out)
	return out


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	for child: Node in node.get_children():
		var btn := child as Button
		if btn != null and (btn.name.begins_with("Link") or btn.name.begins_with("Action")):
			out.append(btn)
		_collect_buttons(child, out)


# ----- footer ----------------------------------------------------------------------------------------------------------


func _build_footer() -> void:
	var foot := _sheet.footer()
	var label := PanelKit.label("Show", &"Hint")
	foot.add_child(label)

	_seg = Segmented.new()
	_seg.name = &"ReportSetting"
	_seg.set_options(SETTING_CHOICES)
	_seg.changed.connect(_on_setting_changed)
	foot.add_child(_seg)

	_study_btn = KitButton.new()
	_study_btn.name = &"StudyButton"
	_study_btn.kind = KitButton.Kind.SECONDARY
	_study_btn.text = STUDY_LABEL
	_study_btn.hotkey_action = &"game_study"
	_study_btn.show_key_cap = true
	_study_btn.visible = Session.game == null or Session.game.has_countries()
	_study_btn.pressed.connect(_open_study.bind(STUDY_PAGE))
	foot.add_child(_study_btn)

	_begin_btn = KitButton.new()
	_begin_btn.name = &"BeginButton"
	_begin_btn.kind = KitButton.Kind.MENU_PRIMARY
	_begin_btn.hotkey_action = &"game_end_season"
	_begin_btn.show_key_cap = true
	_begin_btn.pressed.connect(_on_begin_pressed)
	foot.add_child(_begin_btn)


func _begin_text() -> String:
	if _reopened:
		return "Back to the map"
	var next := str(_summary.get("next", ""))
	var season := next.get_slice(" ", 0) if not next.is_empty() else ""
	return "Begin %s" % season if not season.is_empty() else "Back to the map"


func _current_setting() -> String:
	if ctx != null and ctx.settings != null:
		return str(ctx.settings.get_value(SETTING_KEY))
	return "full"


func _on_setting_changed(id: Variant) -> void:
	if ctx != null and ctx.settings != null:
		ctx.settings.set_value(SETTING_KEY, str(id))


func _on_begin_pressed() -> void:
	_close(&"begin")


# ----- body ------------------------------------------------------------------------------------------------------------


func _fill_sections() -> void:
	var quiet := bool(_summary.get("quiet", false))
	var sections: Array = _summary.get("sections", [])
	for section: Dictionary in sections:
		var id := StringName(str(section.get("id", "")))
		var content := _sheet.add_section(id, str(section.get("title", "")))
		var total: Dictionary = section.get("total", {})
		if not total.is_empty():
			content.add_child(_line_row(total))
		var lines: Array = section.get("lines", [])
		if id == &"glance" and not quiet:
			_fill_chips(content, lines)
		else:
			for line: Dictionary in lines:
				content.add_child(_line_row(line))
		_add_notes(content, section)
		_sheet.set_count(id, -1 if id == &"glance" else int(section.get("count", 0)))


func _add_notes(content: VBoxContainer, section: Dictionary) -> void:
	var more := int(section.get("more", 0))
	if more > 0:
		content.add_child(PanelKit.label("and %d more" % more, &"Hint"))
	var unchanged := str(section.get("unchanged", ""))
	if not unchanged.is_empty():
		content.add_child(PanelKit.label(unchanged, &"Hint"))


## The glance section of a season with work: up to five boxed chips, a label, the value and a DeltaChip in ink.
func _fill_chips(content: VBoxContainer, lines: Array) -> void:
	var flow := HFlowContainer.new()
	flow.name = &"Chips"
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(flow)
	for i: int in mini(lines.size(), CHIP_LIMIT):
		flow.add_child(_chip(lines[i] as Dictionary))


func _chip(line: Dictionary) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.name = "Chip%d" % _next_serial()
	slot.theme_type_variation = &"PanelSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(box)
	var label := PanelKit.label(str(line.get("text", "")), &"Hint")
	label.add_theme_color_override(&"font_color", Tokens.TEXT)
	box.add_child(label)
	var value := PanelKit.label(str(line.get("detail", "")), &"LabelInk")
	value.add_theme_color_override(&"font_color", Tokens.TEXT)
	box.add_child(value)
	var amount := int(line.get("amount", 0))
	if amount != 0:
		box.add_child(_delta(line))
	return slot


# ----- lines -----------------------------------------------------------------------------------------------------------


func _line_row(line: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row%d" % _next_serial()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", Tokens.S2)
	row.add_child(_gilt_bar(bool(line.get("top", false))))
	if bool(line.get("sub", false)):
		var indent := Control.new()
		indent.custom_minimum_size = Vector2(float(Tokens.S4), 0.0)
		indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(indent)
	row.add_child(_text_column(line))
	if int(line.get("amount", 0)) != 0:
		row.add_child(_delta(line))
	var action_btn := _action_button(line)
	if action_btn != null:
		row.add_child(action_btn)
	return row


func _gilt_bar(on: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = &"GiltBar"
	bar.custom_minimum_size = Vector2(3.0, 0.0)
	bar.color = Tokens.BRASS
	bar.visible = on
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _text_column(line: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tone := str(line.get("tone", "plain"))
	var target := _target_of(line)
	if target.is_empty():
		# A line with no place is a label; a line with one is a flat button, whose text sits in from the column's edge. The label
		# takes the same inset, so the lines of one list start in one column.
		var label := PanelKit.label(str(line.get("text", "")), &"LabelInk")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tint(label, tone)
		var inset := MarginContainer.new()
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_theme_constant_override(&"margin_left", _link_inset())
		_insets.append(inset)
		inset.add_child(label)
		col.add_child(inset)
	else:
		col.add_child(_link_button(line, tone, target))
	var detail := str(line.get("detail", ""))
	if not detail.is_empty():
		var hint := PanelKit.label(detail, &"LabelInkMuted")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(hint)
	return col


## A line's target: {hex, action} when it names a hex (its own or a look_at action's), else {}.
func _target_of(line: Dictionary) -> Dictionary:
	var hex := _hex_of(line.get("hex", NO_HEX))
	var action: Array = line.get("action", [])
	if action.size() >= 2 and LOOK_ACTIONS.has(StringName(str(action[0]))):
		hex = _hex_of(action[1])
	if _army_of(action) >= 0:
		return {"hex": hex, "action": action}
	if hex == NO_HEX:
		return {}
	return {"hex": hex, "action": action if not action.is_empty() else [&"look_at", hex]}


func _hex_of(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	return NO_HEX


## The army of a [&"select_army", id] action; -1 for any other action.
func _army_of(action: Array) -> int:
	if action.size() >= 2 and StringName(str(action[0])) == ARMY_ACTION:
		return int(action[1])
	return -1


## The battle record of a [&"battle", record] action; -1 for any other action.
func _record_of(action: Array) -> int:
	if action.size() >= 2 and StringName(str(action[0])) == BATTLE_ACTION:
		return int(action[1])
	return -1


## The left inset of a flat button's text (its normal style's content margin): the same inset a label takes beside a link.
## Read from this screen's own theme chain (the stack's Studiolo theme), not from a probe button on the default theme, so
## a label and a link line up in every theme (issue 443). The sheet is filled before the screen is in the tree, so the
## insets are set again when it is (_ready, on_enter) by _apply_insets.
func _link_inset() -> int:
	var box := get_theme_stylebox(&"normal", &"Button")
	return int(box.get_content_margin(SIDE_LEFT)) if box != null else 0


## Sets every "What befell" label's inset to the screen's theme value (see _link_inset).
func _apply_insets() -> void:
	var inset_px := _link_inset()
	for inset: MarginContainer in _insets:
		if is_instance_valid(inset):
			inset.add_theme_constant_override(&"margin_left", inset_px)


func _link_button(line: Dictionary, tone: String, target: Dictionary) -> Button:
	var btn := Button.new()
	btn.name = "Link%d" % _next_serial()
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = str(line.get("text", ""))
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.focus_mode = Control.FOCUS_ALL
	btn.tooltip_text = "Open the battle" if _record_of(target["action"] as Array) >= 0 else "Show on the map"
	btn.accessibility_name = btn.text
	var ink := _ink_for(tone)
	btn.add_theme_color_override(&"font_color", ink)
	btn.add_theme_color_override(&"font_hover_color", Tokens.GOLD_INK)
	btn.add_theme_color_override(&"font_focus_color", Tokens.GOLD_INK)
	btn.add_theme_color_override(&"font_pressed_color", Tokens.GOLD_INK)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_pick.bind(target["hex"] as Vector2i, target["action"] as Array))
	return btn


func _action_button(line: Dictionary) -> KitButton:
	var action: Array = line.get("action", [])
	var label := str(line.get("action_label", ""))
	if action.is_empty() or label.is_empty():
		return null
	var btn := KitButton.new()
	btn.name = "Action%d" % _next_serial()
	btn.kind = KitButton.Kind.SMALL
	btn.text = label
	btn.reduce_motion = _reduce_motion()
	var hex := _hex_of(action[1]) if action.size() >= 2 else NO_HEX
	btn.pressed.connect(_pick.bind(hex, action))
	return btn


func _delta(line: Dictionary) -> DeltaChip:
	var chip := DeltaChip.new()
	chip.name = &"Delta"
	chip.ink = true
	chip.set_delta(int(line.get("amount", 0)), str(line.get("unit", "")))
	return chip


func _tint(label: Label, tone: String) -> void:
	if tone != "plain":
		label.add_theme_color_override(&"font_color", _ink_for(tone))


func _ink_for(tone: String) -> Color:
	match tone:
		"good":
			return Tokens.GOOD_INK
		"bad":
			return Tokens.BAD_INK
		"warn":
			return Tokens.WARN_INK
		_:
			return Tokens.VELLUM_INK


## The study asked for at `page`: the report closes first, then the App pushes the study.
func _open_study(page: StringName) -> void:
	if _closed:
		return
	_close(&"study")
	if ctx != null:
		ctx.request(STUDY_ACTION, {"page": page})


## A link or action: the report closes, then the App glides to the hex and selects it; a [&"study", page] action opens the study.
func _pick(hex: Vector2i, action: Array) -> void:
	if _closed:
		return
	link_chosen.emit(hex, action)
	if action.size() >= 2 and StringName(str(action[0])) == STUDY_ACTION:
		_open_study(StringName(str(action[1])))
		return
	if _army_of(action) >= 0:
		if ctx != null:
			ctx.request(ARMY_ACTION, {"army": _army_of(action), "hex": hex})
		_close(&"look")
		return
	if _record_of(action) >= 0:
		if ctx != null:
			ctx.request(BATTLE_ACTION, {"record": _record_of(action)})
		_close(&"look")
		return
	if hex != NO_HEX and ctx != null:
		ctx.request(&"look_at", {"hex": hex, "select": true})
	_close(&"look")


## Ends the report once: the signal, then the stack pops it (on_exit sends report_closed).
func _close(reason: StringName) -> void:
	if _closed:
		return
	_closed = true
	closed.emit(reason)
	finished.emit(reason)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _closed or key == null or not key.pressed or key.echo:
		return
	if InputMap.has_action(&"game_study") and event.is_action_pressed(&"game_study", false, true) and _study_btn != null and _study_btn.visible:
		accept_event()
		_open_study(STUDY_PAGE)
		return
	if CLOSE_KEYS.has(key.keycode):
		accept_event()
		_close(&"begin")


func _next_serial() -> int:
	_serial += 1
	return _serial


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false
