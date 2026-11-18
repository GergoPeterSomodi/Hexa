## Studiolo vellum letter sheet with overhanging Ribbon and wax Seal, optional ink NavList,
## focusable/keyboard-scrollable body sections, and sticky footer
## (docs/architecture/ui-style-and-feedback-spec.md sections 4.11 and 5).
class_name VellumSheet
extends PanelContainer

signal section_shown(id: StringName)

const SCROLL_STEP_PX: int = 40

@export var title: String = "":
	set(value):
		title = value
		_sync_header()

@export var lede: String = "":
	set(value):
		lede = value
		_sync_header()

@export var seal_letter: String = "":
	set(value):
		seal_letter = value
		_sync_seal()

@export var seal_tone: StringName = &"vermilion":
	set(value):
		seal_tone = value
		_sync_seal()

@export var show_nav: bool = true:
	set(value):
		show_nav = value
		_sync_nav_visibility()

@export var show_seal: bool = true:
	set(value):
		show_seal = value
		_sync_seal()
		_sync_header()

var _seal_text_override: String = ""
var _sections: Array[Dictionary] = []

var _head: HBoxContainer = null
var _seal_gap: Control = null
var _lede_label: Label = null
var _head_rule: HSeparator = null
var _nav: NavList = null
var _nav_rule: VSeparator = null
var _body_scroll: ScrollContainer = null
var _body: VBoxContainer = null
var _foot: HBoxContainer = null
var _ribbon: Ribbon = null
var _seal: Control = null
var _seal_icon: TextureRect = null
var _seal_label: Label = null
var _refs_bound: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_refs()
	_sync_header()
	_sync_seal()
	_sync_nav_visibility()
	_sync_footer_visibility()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _refs_bound:
		_sync_seal()


## Adds a titled section to the vellum body and registers it in the ink NavList.
## Returns the section's content VBoxContainer.
func add_section(id: StringName, section_title: String) -> VBoxContainer:
	_ensure_refs()
	var section_box := VBoxContainer.new()
	section_box.name = String(id) if id != &"" else "Section%d" % _sections.size()
	section_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var heading := Label.new()
	heading.name = &"Heading"
	heading.text = section_title
	heading.theme_type_variation = &"LabelInkHead"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section_box.add_child(heading)

	var rule := HSeparator.new()
	rule.name = &"Rule"
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section_box.add_child(rule)

	var content := VBoxContainer.new()
	content.name = &"Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section_box.add_child(content)

	_body.add_child(section_box)
	_sections.append({
		"id": id,
		"title": section_title,
		"count": -1,
		"box": section_box,
		"content": content,
	})
	_rebuild_nav()
	return content


## Scrolls BodyScroll to section `id`, updates NavList selection, and emits `section_shown(id)`.
func scroll_to(id: StringName) -> void:
	_ensure_refs()
	var box := _find_section_box(id)
	if box == null:
		return
	var target_y := maxi(0, int(box.position.y))
	_set_scroll_y(target_y)
	_nav.select(id, false)
	section_shown.emit(id)


## Animates the wax seal press via Motion.press_seal(), returning the Tween (or null under reduce_motion).
func press_seal(reduce_motion: bool = false) -> Tween:
	_ensure_refs()
	return Motion.press_seal(_seal, reduce_motion)


## Sets explicit text inside the wax seal (e.g. a countdown number), or pass "" to revert to `seal_letter`.
func set_seal_text(text: String) -> void:
	_seal_text_override = text
	_sync_seal()


## Returns the text currently displayed inside the wax seal.
func seal_text() -> String:
	_ensure_refs()
	return _seal_label.text


## Updates the count badge for section `id` in the ink NavList.
func set_count(id: StringName, n: int) -> void:
	_ensure_refs()
	for entry: Dictionary in _sections:
		if (entry["id"] as StringName) == id:
			entry["count"] = n
			break
	_nav.set_count(id, n)


## Returns the scrolling body VBoxContainer.
func body() -> VBoxContainer:
	_ensure_refs()
	return _body


## Returns the focusable ScrollContainer wrapping `body()`.
func body_scroll() -> ScrollContainer:
	_ensure_refs()
	return _body_scroll


## Returns the ink NavList on the left.
func nav() -> NavList:
	_ensure_refs()
	return _nav


## Returns the sticky footer HBoxContainer.
func footer() -> HBoxContainer:
	_ensure_refs()
	return _foot


## Returns the overhanging Ribbon banner.
func ribbon() -> Ribbon:
	_ensure_refs()
	return _ribbon


## Returns the overhanging wax Seal Control.
func seal_node() -> Control:
	_ensure_refs()
	return _seal


## Returns the content VBoxContainer for section `id`, or `null` if not found.
func section_box(id: StringName) -> VBoxContainer:
	for entry: Dictionary in _sections:
		if (entry["id"] as StringName) == id:
			return entry["content"] as VBoxContainer
	return null


func _ensure_refs() -> void:
	if _refs_bound:
		return
	_head = get_node("VBox/Head") as HBoxContainer
	_seal_gap = get_node("VBox/Head/SealGap") as Control
	_lede_label = get_node("VBox/Head/Lede") as Label
	_head_rule = get_node("VBox/HeadRule") as HSeparator
	_nav = get_node("VBox/Main/Nav") as NavList
	_nav_rule = get_node("VBox/Main/NavRule") as VSeparator
	_body_scroll = get_node("VBox/Main/BodyScroll") as ScrollContainer
	_body = get_node("VBox/Main/BodyScroll/Body") as VBoxContainer
	_foot = get_node("VBox/Foot") as HBoxContainer
	_ribbon = get_node("Overhang/Ribbon") as Ribbon
	_seal = get_node("Overhang/Seal") as Control
	_seal_icon = get_node("Overhang/Seal/SealIcon") as TextureRect
	_seal_label = get_node("Overhang/Seal/SealLetter") as Label

	_nav.selected.connect(_on_nav_selected)
	_body_scroll.gui_input.connect(_on_body_scroll_gui_input)
	_foot.child_order_changed.connect(_sync_footer_visibility)
	_refs_bound = true


func _sync_header() -> void:
	if not _refs_bound:
		return
	_ribbon.text = title
	_ribbon.visible = not title.is_empty()

	_lede_label.text = lede
	_lede_label.visible = not lede.is_empty()

	_seal_gap.visible = show_seal
	_head.visible = _lede_label.visible or show_seal
	_head_rule.visible = _head.visible


func _sync_seal() -> void:
	if not _refs_bound:
		return
	_seal.visible = show_seal
	var display_text := _seal_text_override if not _seal_text_override.is_empty() else seal_letter.to_upper()
	_seal_label.text = display_text
	_seal.accessibility_name = display_text

	var specific_icon := StringName("seal_" + String(seal_tone))
	if seal_tone != &"vermilion" and has_theme_icon(specific_icon, &"Kit"):
		_seal_icon.texture = get_theme_icon(specific_icon, &"Kit")
		_seal_icon.self_modulate = Color.WHITE
	elif has_theme_icon(&"seal", &"Kit"):
		_seal_icon.texture = get_theme_icon(&"seal", &"Kit")
		match seal_tone:
			&"good":
				_seal_icon.self_modulate = get_theme_color(&"font_color", &"NumberGood")
			&"plain":
				_seal_icon.self_modulate = get_theme_color(&"font_color", &"Hint")
			&"cracked":
				_seal_icon.self_modulate = get_theme_color(&"font_color", &"NumberWarn")
			_:
				_seal_icon.self_modulate = Color.WHITE
	else:
		_seal_icon.texture = null


func _sync_nav_visibility() -> void:
	if not _refs_bound:
		return
	_nav.visible = show_nav
	_nav_rule.visible = show_nav


func _rebuild_nav() -> void:
	var current_id := _nav.selected_id()
	var items: Array = []
	for entry: Dictionary in _sections:
		var d := {
			"id": entry["id"],
			"text": entry["title"],
		}
		var cnt := int(entry["count"])
		if cnt >= 0:
			d["count"] = cnt
		items.append(d)
	_nav.set_items(items)
	if current_id != &"":
		_nav.select(current_id, false)
	elif not _sections.is_empty():
		_nav.select(_sections[0]["id"] as StringName, false)


func _find_section_box(id: StringName) -> VBoxContainer:
	for entry: Dictionary in _sections:
		if (entry["id"] as StringName) == id:
			return entry["box"] as VBoxContainer
	return null


func _max_scroll_y() -> int:
	var vbar := _body_scroll.get_v_scroll_bar()
	if vbar != null:
		return maxi(0, int(ceilf(vbar.max_value - vbar.page)))
	return maxi(0, int(ceilf(_body.size.y - _body_scroll.size.y)))


func _set_scroll_y(y: int) -> void:
	var max_y := _max_scroll_y()
	_body_scroll.scroll_vertical = clampi(y, 0, max_y) if max_y > 0 else maxi(0, y)


func _sync_footer_visibility() -> void:
	if not _refs_bound:
		return
	var remaining := 0
	for child: Node in _foot.get_children():
		if not child.is_queued_for_deletion():
			remaining += 1
	_foot.visible = remaining > 0


func _on_nav_selected(id: StringName) -> void:
	scroll_to(id)


func _on_body_scroll_gui_input(event: InputEvent) -> void:
	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed:
		return
	var page_step := maxi(SCROLL_STEP_PX, int(_body_scroll.size.y * 0.85))
	match key_ev.keycode:
		KEY_UP:
			_set_scroll_y(_body_scroll.scroll_vertical - SCROLL_STEP_PX)
		KEY_DOWN:
			_set_scroll_y(_body_scroll.scroll_vertical + SCROLL_STEP_PX)
		KEY_PAGEUP:
			_set_scroll_y(_body_scroll.scroll_vertical - page_step)
		KEY_PAGEDOWN:
			_set_scroll_y(_body_scroll.scroll_vertical + page_step)
		KEY_HOME:
			_set_scroll_y(0)
		KEY_END:
			_set_scroll_y(_max_scroll_y())
		_:
			return
	_body_scroll.accept_event()
