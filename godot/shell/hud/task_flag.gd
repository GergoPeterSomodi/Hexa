## The task flag (docs/architecture/m3-build-spec.md 6.7): a card under End season saying "N things to do", from
## Reminders.unfinished for the player. It is hidden at 0, with the Task flag option off (`settings`, game/task_flag), and
## while a screen covers the map (set_covered). A click on the card opens a list of the lines (540 px wide, one 44 px row
## a line: a tone dot by severity, the text, the action's label); a click on a row emits go_requested(hex) and closes the
## list. A click elsewhere closes it; the host closes it on Esc (close_list). It reads Session and Events and sends intents
## only; the App's TopRight column places it (Y18).
class_name TaskFlag
extends PanelContainer

## A row was chosen: the App looks at the hex and selects it. The list is already closed.
signal go_requested(hex: Vector2i)
## An army row (an army reminder) was chosen: the App selects that army and glides to it. The list is already closed.
signal army_requested(army: int, hex: Vector2i)
## A row whose action is [&"study", page] was chosen: the App opens the study at `page` (spec 6.9). The list is already closed.
signal study_requested(page: StringName)
## A war row whose action is [&"country", tag] (war_timer) was chosen: the App opens that country's panel. The list is already closed.
signal country_requested(tag: StringName)
signal list_toggled(open: bool)

const LIST_WIDTH: int = 540
const ROW_HEIGHT: int = 44
const SEVERITY_TONES: Array[StringName] = [&"muted", &"plain", &"warn"]

## The Settings object that holds game/task_flag; null reads the shipped default (on). Replacing it rebinds the
## `changed` link, and a change of game/task_flag refreshes the card.
var settings: Settings = null:
	set(value):
		if settings == value:
			return
		_unbind_settings()
		settings = value
		if is_inside_tree():
			_bind_settings()
		refresh()

var _lines: Array[Dictionary] = []
var _covered: bool = false
var _open: bool = false

@onready var _number: Label = $Pill/Number
@onready var _noun: Label = $Pill/Noun
@onready var _list: PanelContainer = $List
@onready var _head: Label = $List/VBox/Head
@onready var _rows: VBoxContainer = $List/VBox/Rows


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_list.custom_minimum_size.x = float(LIST_WIDTH)
	_list.visible = false
	_head.theme_type_variation = &"SectionHead"
	_head.text = "Things to do"
	refresh()


func _enter_tree() -> void:
	for pair: Array in _bus_links():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if not sig.is_connected(handler):
			sig.connect(handler)
	_bind_settings()


func _exit_tree() -> void:
	for pair: Array in _bus_links():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)
	_unbind_settings()


func _bind_settings() -> void:
	if settings != null and not settings.changed.is_connected(_on_setting_changed):
		settings.changed.connect(_on_setting_changed)


func _unbind_settings() -> void:
	if settings != null and settings.changed.is_connected(_on_setting_changed):
		settings.changed.disconnect(_on_setting_changed)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "game/task_flag":
		refresh()


func _bus_links() -> Array:
	return [
		[Events.season_ended, _on_season_ended],
		[Events.work_started, _on_work_started],
		[Events.work_finished, _on_work_finished],
		[Events.work_cancelled, _on_work_cancelled],
		[Events.country_chosen, _on_country_chosen],
		[Events.army_raised, _on_army_event],
		[Events.army_disbanded, _on_army_event],
		[Events.army_changed, _on_army_event],
		[Events.march_halted, _on_army_event],
		[Events.army_starved, _on_army_event],
		[Events.unit_lost, _on_army_event],
		[Events.game_started, _on_game_changed],
		[Events.game_ended, _on_game_changed],
		[Events.war_declared, _on_war_event],
		[Events.peace_made, _on_war_event],
		[Events.battle_ended, _on_war_event],
		[Events.siege_started, _on_war_event],
		[Events.siege_progress, _on_war_event],
		[Events.siege_lifted, _on_war_event],
		[Events.district_captured, _on_war_event],
		[Events.controllers_changed, _on_war_event],
	]


## Reads the game for the player's lines and shows the count. Cheap: Reminders caches by game.version.
func refresh() -> void:
	if not is_node_ready():
		return
	var lines: Array[Dictionary] = []
	var game := Session.game
	if game != null and _option_on():
		lines = Reminders.unfinished(game, Session.player_tag())
	_lines = lines
	var count := _lines.size()
	_number.text = str(count)
	_noun.text = " thing to do" if count == 1 else " things to do"
	if _open and _lines.is_empty():
		close_list()
	elif _open:
		_rebuild_rows()
	_sync_visible()


## The lines the flag shows, as copies (text, kind, severity, hint, action, action_label, hex).
func lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Dictionary in _lines:
		out.append(line.duplicate(true))
	return out


func line_count() -> int:
	return _lines.size()


## A screen covers the map (true) or has closed (false). The card and its list hide while covered.
func set_covered(covered: bool) -> void:
	_covered = covered
	if covered:
		close_list()
	_sync_visible()


func is_covered() -> bool:
	return _covered


func is_list_open() -> bool:
	return _open


func open_list() -> void:
	if _open or _lines.is_empty() or not visible:
		return
	_open = true
	_rebuild_rows()
	_list.visible = true
	_place_list()
	list_toggled.emit(true)


func close_list() -> void:
	if not _open:
		return
	_open = false
	_list.visible = false
	list_toggled.emit(false)


## Chooses row `index`: closes the list and emits go_requested with that line's hex, or study_requested for a study action
## (a row with neither does nothing).
func choose_row(index: int) -> bool:
	if index < 0 or index >= _lines.size():
		return false
	var army := _army_of(_lines[index])
	var hex: Vector2i = _lines[index].get("hex", WorksView.NO_HEX)
	var page := _study_page(_lines[index])
	var country := _country_of(_lines[index])
	close_list()
	if army >= 0:
		army_requested.emit(army, hex)
		return true
	if country != &"":
		country_requested.emit(country)
		return true
	if hex == WorksView.NO_HEX:
		if page == &"":
			return false
		study_requested.emit(page)
		return true
	go_requested.emit(hex)
	return true


## The page of a line whose action is [&"study", page], else &"".
static func _study_page(line: Dictionary) -> StringName:
	var action: Array = line.get("action", [])
	if action.size() >= 2 and StringName(str(action[0])) == &"study":
		return StringName(str(action[1]))
	return &""


## The country of a [&"country", tag] line (a war reminder), else &"".
static func _country_of(line: Dictionary) -> StringName:
	var action: Array = line.get("action", [])
	if action.size() >= 2 and StringName(str(action[0])) == &"country":
		return StringName(str(action[1]))
	return &""


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT and visible:
		if _open:
			close_list()
		else:
			open_list()
		accept_event()


## A press outside the card and its list closes the list (the press still reaches what it hit).
func _input(event: InputEvent) -> void:
	if not _open:
		return
	var press := event as InputEventMouseButton
	if press == null or not press.pressed:
		return
	var at := press.global_position
	if get_global_rect().has_point(at) or _list.get_global_rect().has_point(at):
		return
	close_list()


## The army of a [&"select_army", id] line, else -1.
static func _army_of(line: Dictionary) -> int:
	var action: Array = line.get("action", [])
	if action.size() >= 2 and StringName(str(action[0])) == &"select_army":
		return int(action[1])
	return -1


## An army changed, was raised, disbanded, halted or lost men: the army reminders are read again (the order clears them).
func _on_army_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	refresh()


## A war event (a declaration, a peace, a battle, a siege or a capture): the war reminders are read again.
func _on_war_event(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	refresh()


func _on_season_ended(_turn: int) -> void:
	refresh()


func _on_work_started(_tag: StringName, _hex: Vector2i, _work: Dictionary) -> void:
	refresh()


func _on_work_finished(_tag: StringName, _hex: Vector2i, _work: Dictionary) -> void:
	refresh()


func _on_work_cancelled(_tag: StringName, _hex: Vector2i, _work: Dictionary, _why: StringName) -> void:
	refresh()


func _on_country_chosen(_tag: StringName) -> void:
	refresh()


func _on_game_changed() -> void:
	close_list()
	refresh()


func _option_on() -> bool:
	if settings == null:
		return true
	return bool(settings.get_value("game/task_flag"))


func _sync_visible() -> void:
	var game_on := Session.game != null and _option_on()
	visible = game_on and not _covered and not _lines.is_empty()
	if not visible:
		close_list()


func _rebuild_rows() -> void:
	PanelKit.clear_children(_rows)
	for i: int in _lines.size():
		_rows.add_child(_build_row(i, _lines[i]))


func _build_row(index: int, line: Dictionary) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.disabled = (line.get("hex", WorksView.NO_HEX) as Vector2i) == WorksView.NO_HEX and _study_page(line) == &"" \
			and _army_of(line) < 0 and _country_of(line) == &""
	row.tooltip_text = str(line.get("action_label", ""))
	row.accessibility_name = str(line.get("text", ""))
	row.pressed.connect(func() -> void: choose_row(index))
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var dot := TextureRect.new()
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(dot)
	Notifications.apply_tone(dot, _tone_of(int(line.get("severity", 0))))
	var text := PanelKit.label(str(line.get("text", "")), &"Body")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.max_lines_visible = 2
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text)
	var hint_text := str(line.get("action_label", ""))
	if not hint_text.is_empty():
		var hint := PanelKit.label(hint_text, &"Hint")
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(hint)
	return row


static func _tone_of(severity: int) -> StringName:
	return SEVERITY_TONES[clampi(severity, 0, SEVERITY_TONES.size() - 1)]


## Puts the list under the card, its right edge on the card's, kept inside the window.
func _place_list() -> void:
	var view := get_viewport_rect().size
	var x := global_position.x + size.x - float(LIST_WIDTH)
	x = clampf(x, 0.0, maxf(0.0, view.x - float(LIST_WIDTH)))
	_list.global_position = Vector2(x, global_position.y + size.y + 4.0)
