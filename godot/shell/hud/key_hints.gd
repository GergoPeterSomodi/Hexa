## Studiolo bottom contextual bone KeyCap hint strip reflecting live InputMap bindings
## (docs/architecture/ui-style-and-feedback-spec.md section 2; ui-style-and-feedback-plan.md U14). While an army of yours is selected
## it starts with the line that army moves are final (moves-build-spec.md R54), then the key that adds a stop to its march (R62).
class_name KeyHints
extends HBoxContainer

const IDLE_ITEMS: Array[Array] = [
	[&"app_menu", "menu"],
	[&"app_help", "keys"],
	[&"view_grid", "grid"],
	[&"view_names", "names"],
	[&"view_hud", "hide HUD"],
	[&"app_fullscreen", "window"],
]

const COMPACT_IDLE_ITEMS: Array[Array] = [
	[&"app_menu", "menu"],
	[&"app_help", "keys"],
	[&"app_fullscreen", "window"],
	[&"app_screenshot", "screenshot"],
]

const SELECTED_ITEMS: Array[Array] = [
	[&"game_upgrade", "upgrade"],
	[&"app_back", "clear"],
	[&"app_help", "keys"],
	[&"view_hud", "hide HUD"],
]

## Before the other items while an army of yours is selected.
const ARMY_ITEMS: Array[Array] = [
	[&"map_waypoint_key", "stop"],
]

## The line of R54, here and in the help overlay.
const MOVES_NOTE := "Army moves are final: an army walks when you give the order."

var hints_enabled: bool = true:
	set(value):
		hints_enabled = value
		visible = hints_enabled

var _has_selection: bool = false
var _army_selected: bool = false
var _note: Label = null
var _compact: bool = false
var _platform: String = OS.get_name()
var _caps: Array[KeyCap] = []
var _actions: Array[StringName] = []
var _retired: Array[Node] = []
var _settings: Settings = null
var _fit_w: float = INF


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.army_selected.connect(_on_army_selected)
	Events.army_cleared.connect(_on_army_cleared)
	Events.game_ended.connect(_on_army_cleared)
	_rebuild()


func _exit_tree() -> void:
	if Events.army_selected.is_connected(_on_army_selected):
		Events.army_selected.disconnect(_on_army_selected)
		Events.army_cleared.disconnect(_on_army_cleared)
		Events.game_ended.disconnect(_on_army_cleared)
	_disconnect_settings()
	PanelKit.free_retired(_retired)


func configure(settings: Settings) -> void:
	if settings == _settings:
		if settings != null:
			_apply_settings(settings)
		return
	_disconnect_settings()
	_settings = settings
	if _settings == null:
		return
	_settings.changed.connect(_on_setting_changed)
	_apply_settings(_settings)


func set_hints_enabled(on: bool) -> void:
	hints_enabled = on


func set_context(has_selection: bool, compact: bool = false) -> void:
	if _has_selection == has_selection and _compact == compact and not _actions.is_empty():
		return
	_has_selection = has_selection
	_compact = compact
	_rebuild()


func refresh_bindings(platform: String = OS.get_name()) -> void:
	_platform = platform
	if _caps.is_empty():
		_rebuild()
		return
	for cap: KeyCap in _caps:
		if is_instance_valid(cap):
			cap.refresh_from_input_map(_platform)


## Hides the trailing hints that would run past `max_w` px (the scale bar's edge); the rest stay in order.
func fit_width(max_w: float) -> void:
	_fit_w = max_w
	var used := 0.0
	var gap := float(get_theme_constant(&"separation"))
	for child: Node in get_children():
		var item := child as Control
		if item == null or item.is_queued_for_deletion():
			continue
		used += item.get_combined_minimum_size().x
		item.visible = used <= max_w
		used += gap


func hint_actions() -> Array[StringName]:
	return _actions.duplicate()


## The line about army moves, "" while no army is selected.
func note_text() -> String:
	return _note.text if _note != null else ""


## The line's label, or null while no army is selected (for the tests and the layout).
func note_label() -> Label:
	return _note


func _on_army_selected(_army_id: int) -> void:
	_set_army(true)


func _on_army_cleared() -> void:
	_set_army(false)


func _set_army(on: bool) -> void:
	if _army_selected == on:
		return
	_army_selected = on
	_rebuild()


func _rebuild() -> void:
	if not InputMap.has_action(&"app_back"):
		Bindings.ensure()
	PanelKit.clear_children(self, _retired)
	_caps.clear()
	_actions.clear()
	_note = null
	if _army_selected:
		_note = Label.new()
		_note.name = &"MovesNote"
		_note.text = MOVES_NOTE
		_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_note)

	var items: Array[Array] = []
	if _army_selected:
		items.append_array(ARMY_ITEMS)
	items.append_array(SELECTED_ITEMS if _has_selection else (COMPACT_IDLE_ITEMS if _compact else IDLE_ITEMS))
	for entry: Array in items:
		var action := entry[0] as StringName
		var desc := str(entry[1])
		_actions.append(action)

		var item := HBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var cap := KeyCap.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.action = action
		cap.refresh_from_input_map(_platform)
		item.add_child(cap)
		_caps.append(cap)

		var lbl := Label.new()
		lbl.text = desc
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(lbl)

		add_child(item)
	if _fit_w < INF:
		fit_width(_fit_w)


func _apply_settings(settings: Settings) -> void:
	if Settings.SCHEMA.has("ui/hud_hints"):
		hints_enabled = bool(settings.get_value("ui/hud_hints"))


func _on_setting_changed(key: String, _value: Variant) -> void:
	if _settings != null and key == "ui/hud_hints":
		_apply_settings(_settings)


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null
