## The Save and Load screen (docs/architecture/m3-build-spec.md section 6.10): a MODAL 860 x 580 with a Save | Load
## segmented control (Save only with a game running), one row per slot (SaveRows), a Name field on the Save tab, and a
## Confirm for every overwrite, load over unsaved actions and delete. Save and Load ask the App (ctx.request); the App
## saves or loads and emits ctx.saved, and this screen refreshes its rows on that signal. Keys: Up and Down choose a
## row, Enter saves or loads, Del deletes, Esc goes back (the stack pops it); the Name field keeps every key but Down.
class_name SaveLoad
extends Screen

const LIST_H := 360.0
const THUMBS_PER_FRAME := 2
const TAB_SAVE := &"save"
const TAB_LOAD := &"load"
const TABS: Array[Dictionary] = [{"id": TAB_SAVE, "label": "Save"}, {"id": TAB_LOAD, "label": "Load"}]
const RIBBONS: Dictionary[StringName, String] = {TAB_SAVE: "Save game", TAB_LOAD: "Load game"}
const HINT := "Up and Down choose a slot · Enter saves or loads · Del deletes · Esc goes back"
const NAME_LABEL := "Name"
const NAME_PLACEHOLDER := "Name this save"
const SAVE_HERE := "Save here"
const LOAD_HERE := "Load"
const DELETE_HERE := "Delete"
const UNSAVED_WARNING := "Unsaved changes are lost."
const DELETE_WARNING := "It cannot be undone."
const EMPTY_TOAST := "This slot is empty."

## The tab to open on: TAB_SAVE or TAB_LOAD; &"" means Save with a game running, Load without one.
@export var start_tab: StringName = &""

@onready var _frame: ModalFrame = $Center/Frame

var _tab: StringName = TAB_LOAD
var _segment: Segmented = null
var _name_box: VBoxContainer = null
var _name_edit: LineEdit = null
var _rows_box: VBoxContainer = null
var _hint: Label = null
var _rows: Array[Dictionary] = []
var _widgets: Dictionary[String, Dictionary] = {}
var _thumb_queue: Array[Dictionary] = []
var _index: int = 0
var _retired: Array[Node] = []
var _ui_built: bool = false


## Builds the screen with its opening tab (see start_tab); the App and the menus open it this way.
static func make(tab: StringName = &"") -> SaveLoad:
	var screen := ScreenIds.make(&"save_load") as SaveLoad
	if screen != null:
		screen.start_tab = tab
	return screen


func _ready() -> void:
	set_process(false)
	_ensure_ui()


func _exit_tree() -> void:
	_disconnect_saved()
	PanelKit.free_retired(_retired)


func on_enter() -> void:
	_ensure_ui()
	_connect_saved()
	var game_running := Session.game != null
	var tab := start_tab
	if tab == &"":
		tab = TAB_SAVE if game_running else TAB_LOAD
	if tab == TAB_SAVE and not game_running:
		tab = TAB_LOAD
	_name_edit.text = default_name()
	_set_tab(tab)


func on_exit() -> void:
	_disconnect_saved()
	_thumb_queue.clear()
	set_process(false)


func _process(_delta: float) -> void:
	step_thumbnails()


## Changes the tab (TAB_SAVE is refused with no game) and rebuilds the rows.
func set_tab(tab: StringName) -> void:
	_ensure_ui()
	_set_tab(tab)


func tab() -> StringName:
	return _tab


func segmented() -> Segmented:
	_ensure_ui()
	return _segment


func frame() -> ModalFrame:
	_ensure_ui()
	return _frame


func name_edit() -> LineEdit:
	_ensure_ui()
	return _name_edit


## The Name field's text, or the default name when it is blank.
func name_text() -> String:
	_ensure_ui()
	var typed := _name_edit.text.strip_edges()
	return typed if not typed.is_empty() else default_name()


func set_name_text(text: String) -> void:
	_ensure_ui()
	_name_edit.text = text


## The name a new save gets before anything is typed: "<country>, <date>" of the running game ("" with no game).
func default_name() -> String:
	var game := Session.game
	if game == null:
		return ""
	var header := SaveFile.header_of(game, "", {})
	return SaveRows.default_name(str(header.get("country", "")), str(header.get("date", "")))


## The SaveRows of the rows on screen, in order.
func rows() -> Array[Dictionary]:
	return _rows.duplicate()


func row_slots() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in _rows:
		out.append(str(row["slot"]))
	return out


func row_count() -> int:
	return _rows.size()


## The selected row's index (Up and Down move it).
func index() -> int:
	return _index


func set_index(at: int) -> void:
	_ensure_ui()
	if _rows.is_empty():
		return
	_index = clampi(at, 0, _rows.size() - 1)
	_focus_row(_index)


func action_button(slot: String) -> KitButton:
	return _widget(slot, "action") as KitButton


func delete_button(slot: String) -> KitButton:
	return _widget(slot, "delete") as KitButton


func title_label(slot: String) -> Label:
	return _widget(slot, "title") as Label


func detail_label(slot: String) -> Label:
	return _widget(slot, "detail") as Label


func state_label(slot: String) -> Label:
	return _widget(slot, "state") as Label


func thumb_rect(slot: String) -> TextureRect:
	return _widget(slot, "thumb") as TextureRect


## Loads the thumbnails of up to THUMBS_PER_FRAME rows still waiting. Returns how many it loaded (the screen calls it
## every frame while rows wait).
func step_thumbnails() -> int:
	var loaded := 0
	while loaded < THUMBS_PER_FRAME and not _thumb_queue.is_empty():
		var job: Dictionary = _thumb_queue.pop_front()
		_show_thumb(str(job["slot"]), str(job["path"]))
		loaded += 1
	set_process(not _thumb_queue.is_empty())
	return loaded


func pending_thumbnails() -> int:
	return _thumb_queue.size()


func _ensure_ui() -> void:
	if _ui_built:
		return
	if _frame == null:
		_frame = get_node_or_null("Center/Frame") as ModalFrame
	if _frame == null:
		return
	_ui_built = true
	_frame.closed.connect(_on_closed)
	var body := _frame.body()

	_segment = Segmented.new()
	_segment.name = &"Tabs"
	_segment.set_options(TABS)
	_segment.changed.connect(_on_tab_changed)
	body.add_child(_segment)

	_name_box = VBoxContainer.new()
	_name_box.name = &"NameBox"
	_name_box.add_child(PanelKit.label(NAME_LABEL, &"Hint"))
	_name_edit = LineEdit.new()
	_name_edit.name = &"NameEdit"
	_name_edit.placeholder_text = NAME_PLACEHOLDER
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_box.add_child(_name_edit)
	body.add_child(_name_box)

	var scroll := ScrollContainer.new()
	scroll.name = &"ListScroll"
	scroll.custom_minimum_size = Vector2(0.0, LIST_H)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.name = &"Rows"
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override(&"separation", Tokens.S2)
	scroll.add_child(_rows_box)

	_hint = PanelKit.label(HINT, &"Hint")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.footer().add_child(_hint)


func _set_tab(tab: StringName) -> void:
	_tab = tab if (tab == TAB_LOAD or Session.game != null) else TAB_LOAD
	_segment.select(_tab, false)
	_segment.visible = Session.game != null
	_frame.ribbon_title = RIBBONS[_tab]
	_name_box.visible = _tab == TAB_SAVE
	_index = 0
	refresh()


## Rebuilds the rows from Session.list_saves() for the current tab.
func refresh() -> void:
	_ensure_ui()
	PanelKit.clear_children(_rows_box, _retired)
	_widgets.clear()
	_thumb_queue.clear()
	_rows = SaveRows.of(Session.list_saves(), _tab, int(Time.get_unix_time_from_system()))
	for at: int in _rows.size():
		_rows_box.add_child(_build_row(_rows[at], at))
	_index = clampi(_index, 0, maxi(_rows.size() - 1, 0))
	_sync_default_focus()
	set_process(not _thumb_queue.is_empty())


func _build_row(row: Dictionary, at: int) -> PanelContainer:
	var slot := str(row["slot"])
	var panel := PanelContainer.new()
	panel.name = "Row_" + slot
	panel.theme_type_variation = &"PanelCard"
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", Tokens.S3)
	panel.add_child(line)

	var picture := PanelContainer.new()
	picture.name = &"Picture"
	picture.custom_minimum_size = Vector2(SaveFile.THUMB)
	picture.theme_type_variation = &"PanelSlot"
	line.add_child(picture)
	var placeholder := PanelKit.label("No picture", &"Hint")
	placeholder.name = &"NoPicture"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	picture.add_child(placeholder)
	var thumb := TextureRect.new()
	thumb.name = &"Thumb"
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.custom_minimum_size = Vector2(SaveFile.THUMB)
	thumb.visible = false
	picture.add_child(thumb)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var name_label := PanelKit.label(str(row["name"]), &"Hint")
	name_label.visible = not str(row["name"]).is_empty()
	text.add_child(name_label)
	var title := PanelKit.label(str(row["title"]), &"Body")
	text.add_child(title)
	var detail := PanelKit.reason(str(row["detail"]))
	detail.theme_type_variation = &"Hint"
	detail.visible = not str(row["detail"]).is_empty()
	text.add_child(detail)
	var state := PanelKit.reason(str(row["state_text"]))
	state.visible = not str(row["state_text"]).is_empty()
	text.add_child(state)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(buttons)
	var action := KitButton.new()
	action.name = &"Action"
	action.kind = KitButton.Kind.SECONDARY
	action.text = SAVE_HERE if _tab == TAB_SAVE else LOAD_HERE
	action.disabled = not bool(row["can_act"])
	action.pressed.connect(_activate.bind(at))
	action.focus_entered.connect(_on_row_focused.bind(at))
	buttons.add_child(action)
	var delete := KitButton.new()
	delete.name = &"Delete"
	delete.kind = KitButton.Kind.SMALL
	delete.text = DELETE_HERE
	delete.visible = bool(row["can_delete"])
	delete.pressed.connect(_ask_delete.bind(at))
	delete.focus_entered.connect(_on_row_focused.bind(at))
	buttons.add_child(delete)

	_widgets[slot] = {"panel": panel, "thumb": thumb, "placeholder": placeholder, "title": title,
		"detail": detail, "state": state, "action": action, "delete": delete}
	var path := str(row["thumbnail"])
	if not path.is_empty():
		_thumb_queue.append({"slot": slot, "path": path})
	return panel


func _show_thumb(slot: String, path: String) -> void:
	var widget := _widgets.get(slot, {}) as Dictionary
	if widget.is_empty():
		return
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return
	var thumb := widget["thumb"] as TextureRect
	thumb.texture = ImageTexture.create_from_image(image)
	thumb.visible = true
	(widget["placeholder"] as Label).visible = false


func _widget(slot: String, part: String) -> Object:
	_ensure_ui()
	var widget := _widgets.get(slot, {}) as Dictionary
	return widget.get(part, null) as Object


func _connect_saved() -> void:
	if ctx != null and not ctx.saved.is_connected(_on_saved):
		ctx.saved.connect(_on_saved)


func _disconnect_saved() -> void:
	if ctx != null and ctx.saved.is_connected(_on_saved):
		ctx.saved.disconnect(_on_saved)


func _on_saved(slot: String, problem: String) -> void:
	if not problem.is_empty() and ctx != null:
		ctx.toast(problem, &"bad")
	refresh()
	var at := _slot_index(slot)
	if at >= 0:
		_index = at
	_focus_row(_index)


func _on_tab_changed(id: Variant) -> void:
	_set_tab(StringName(str(id)))


func _on_closed() -> void:
	finished.emit(&"close")


func _on_name_submitted(_text: String) -> void:
	_focus_row(_index)


func _on_row_focused(at: int) -> void:
	_index = at


func _slot_index(slot: String) -> int:
	return row_slots().find(slot)


## Activates the row at `at`: Save or Load on a usable row, a toast with the reason on a greyed one.
func _activate(at: int) -> void:
	if at < 0 or at >= _rows.size():
		return
	_index = at
	var row := _rows[at]
	if not bool(row["can_act"]):
		if ctx != null:
			var reason := str(row["state_text"])
			ctx.toast(reason if not reason.is_empty() else EMPTY_TOAST, &"warn")
		return
	if _tab == TAB_SAVE:
		_ask_save(row)
	else:
		_ask_load(row)


func _ask_save(row: Dictionary) -> void:
	var slot := str(row["slot"])
	var save_name := name_text()
	if row["state"] == &"empty":
		_request_save(slot, save_name)
		return
	var confirm := Confirm.ask(
		"Save over %s?" % str(row["label"]),
		str(row["summary"]) if not str(row["summary"]).is_empty() else str(row["state_text"]),
		[],
		{"confirm_label": "Save", "cancel_label": "Cancel"}
	)
	confirm.chose.connect(_on_save_chosen.bind(slot, save_name))
	_push(confirm)


func _on_save_chosen(choice: StringName, slot: String, save_name: String) -> void:
	if choice == &"confirm":
		_request_save(slot, save_name)


func _request_save(slot: String, save_name: String) -> void:
	if ctx != null:
		ctx.request(&"save", {"slot": slot, "name": save_name})


func _ask_load(row: Dictionary) -> void:
	var slot := str(row["slot"])
	if Session.unsaved_actions <= 0:
		_request_load(slot)
		return
	var confirm := Confirm.ask(
		"Load %s?" % str(row["label"]),
		UNSAVED_WARNING,
		[],
		{"confirm_label": "Load", "cancel_label": "Cancel"}
	)
	confirm.chose.connect(_on_load_chosen.bind(slot))
	_push(confirm)


func _on_load_chosen(choice: StringName, slot: String) -> void:
	if choice == &"confirm":
		_request_load(slot)


func _request_load(slot: String) -> void:
	if ctx != null:
		ctx.request(&"load", {"slot": slot})


func _ask_delete(at: int) -> void:
	if at < 0 or at >= _rows.size() or not bool(_rows[at]["can_delete"]):
		return
	_index = at
	var row := _rows[at]
	var confirm := Confirm.ask(
		"Delete %s?" % str(row["label"]),
		DELETE_WARNING,
		[],
		{"confirm_label": "Delete", "cancel_label": "Cancel", "danger": true}
	)
	confirm.chose.connect(_on_delete_chosen.bind(str(row["slot"])))
	_push(confirm)


func _on_delete_chosen(choice: StringName, slot: String) -> void:
	if choice != &"confirm":
		return
	Session.delete_save(slot)
	refresh()


func _push(screen: Screen) -> void:
	if ctx != null and ctx.stack != null and ctx.stack.has_method(&"push"):
		ctx.stack.call(&"push", screen)


func _move(step: int) -> void:
	if _rows.is_empty():
		return
	_index = clampi(_index + step, 0, _rows.size() - 1)
	_focus_row(_index)


## Focuses the row's Save/Load button, else its Delete button; a greyed row only moves the selection.
func _focus_row(at: int) -> void:
	if at < 0 or at >= _rows.size() or not is_inside_tree():
		return
	var slot := str(_rows[at]["slot"])
	var action := action_button(slot)
	var delete := delete_button(slot)
	if action != null and not action.disabled:
		action.grab_focus()
	elif delete != null and delete.visible:
		delete.grab_focus()


func _sync_default_focus() -> void:
	if not is_inside_tree():
		return
	if _rows.is_empty():
		default_focus = get_path_to(_segment)
		return
	var action := action_button(str(_rows[_index]["slot"]))
	if action != null:
		default_focus = get_path_to(action)


func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree() or _rows.is_empty():
		return
	if ctx == null or ctx.stack == null or not ctx.stack.has_method(&"top"):
		return
	if ctx.stack.call(&"top") != self:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var in_name := _name_edit.has_focus()
	var handled := false
	match key.keycode:
		KEY_DOWN:
			_move(1)
			handled = true
		KEY_UP:
			if not in_name:
				_move(-1)
				handled = true
		KEY_ENTER, KEY_KP_ENTER:
			if not in_name and not key.echo:
				_activate(_index)
				handled = true
		KEY_DELETE:
			if not in_name and not key.echo:
				_ask_delete(_index)
				handled = true
	if handled:
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
