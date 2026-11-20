## Studiolo map layers popup card toggled from TopBar
## (docs/architecture/ui-and-controls-spec.md sections 3.3, 7; ui-style-and-feedback-plan.md U14).
class_name LayersPopover
extends PanelContainer

signal layer_toggled(layer_name: StringName, on: bool)
signal closed

const LAYER_GRID := &"map/grid"
const LAYER_NAMES := &"map/place_names"
const LAYER_RELIEF := &"graphics/relief_shading"
const LAYER_BORDERS := &"map/borders"
const LAYER_TINT := &"map/owner_tint"
const LAYER_MINIMAP := &"map/minimap"
const LAYER_KEYS: Array[String] = [
	"map/grid", "map/place_names", "graphics/relief_shading", "map/borders", "map/owner_tint", "map/minimap",
]

var anchor_button: BaseButton = null

@onready var _grid_cap: KeyCap = $VBox/GridRow/KeyCap
@onready var _grid_switch: KitSwitch = $VBox/GridRow/GridSwitch
@onready var _names_cap: KeyCap = $VBox/NamesRow/KeyCap
@onready var _names_switch: KitSwitch = $VBox/NamesRow/NamesSwitch
@onready var _relief_switch: KitSwitch = $VBox/ReliefRow/ReliefSwitch
@onready var _borders_switch: KitSwitch = $VBox/BordersRow/BordersSwitch
@onready var _tint_switch: KitSwitch = $VBox/TintRow/TintSwitch
@onready var _minimap_switch: KitSwitch = $VBox/MinimapRow/MinimapSwitch

var _settings: Settings = null
var _syncing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_grid_cap.action = &"view_grid"
	_names_cap.action = &"view_names"

	_grid_switch.focus_mode = Control.FOCUS_NONE
	_names_switch.focus_mode = Control.FOCUS_NONE
	_relief_switch.focus_mode = Control.FOCUS_NONE
	_borders_switch.focus_mode = Control.FOCUS_NONE
	_tint_switch.focus_mode = Control.FOCUS_NONE
	_minimap_switch.focus_mode = Control.FOCUS_NONE

	_grid_switch.toggled.connect(func(on: bool) -> void: _on_switch_toggled(LAYER_GRID, on))
	_names_switch.toggled.connect(func(on: bool) -> void: _on_switch_toggled(LAYER_NAMES, on))
	_relief_switch.toggled.connect(func(on: bool) -> void: _on_switch_toggled(LAYER_RELIEF, on))
	_borders_switch.toggled.connect(func(on: bool) -> void: _on_switch_toggled(LAYER_BORDERS, on))
	_tint_switch.toggled.connect(func(on: bool) -> void: _on_switch_toggled(LAYER_TINT, on))
	_minimap_switch.toggled.connect(func(on: bool) -> void: _on_switch_toggled(LAYER_MINIMAP, on))

	if _settings != null:
		_sync_from_settings()


func _exit_tree() -> void:
	_disconnect_settings()


func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			var is_back := (InputMap.has_action(&"app_back") and key.is_action(&"app_back")) or key.is_action(&"ui_cancel")
			if is_back:
				close()
				var vp := get_viewport()
				if vp != null:
					vp.set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			return
		if get_global_rect().has_point(mb.position):
			return
		if anchor_button != null and is_instance_valid(anchor_button) and anchor_button.get_global_rect().has_point(mb.position):
			return
		close()


func open() -> void:
	set_open(true)


func close() -> void:
	set_open(false)


func set_open(on: bool) -> void:
	if visible == on:
		return
	visible = on
	if not on:
		closed.emit()


func configure(settings: Settings) -> void:
	if settings == _settings:
		if settings != null and is_node_ready():
			_sync_from_settings()
		return
	_disconnect_settings()
	_settings = settings
	if _settings == null:
		return
	_settings.changed.connect(_on_setting_changed)
	if is_node_ready():
		_sync_from_settings()


func set_layer_state(layer_name: StringName, on: bool) -> void:
	if not is_node_ready():
		return
	_syncing = true
	match layer_name:
		LAYER_GRID, &"grid":
			_grid_switch.set_pressed_no_signal(on)
		LAYER_NAMES, &"place_names":
			_names_switch.set_pressed_no_signal(on)
		LAYER_RELIEF, &"relief_shading":
			_relief_switch.set_pressed_no_signal(on)
		LAYER_BORDERS, &"borders":
			_borders_switch.set_pressed_no_signal(on)
		LAYER_TINT, &"owner_tint":
			_tint_switch.set_pressed_no_signal(on)
		LAYER_MINIMAP, &"minimap":
			_minimap_switch.set_pressed_no_signal(on)
	_syncing = false


func refresh_hotkeys() -> void:
	if not is_node_ready():
		return
	_grid_cap.refresh_from_input_map()
	_names_cap.refresh_from_input_map()


func grid_switch() -> KitSwitch:
	return _grid_switch


func names_switch() -> KitSwitch:
	return _names_switch


func relief_switch() -> KitSwitch:
	return _relief_switch


func borders_switch() -> KitSwitch:
	return _borders_switch


func tint_switch() -> KitSwitch:
	return _tint_switch


func minimap_switch() -> KitSwitch:
	return _minimap_switch


func _on_switch_toggled(layer_key: StringName, on: bool) -> void:
	if _syncing:
		return
	if _settings != null:
		_syncing = true
		_settings.set_value(String(layer_key), on)
		_syncing = false
	layer_toggled.emit(layer_key, on)


func _sync_from_settings() -> void:
	if _settings == null or not is_node_ready():
		return
	_syncing = true
	_grid_switch.set_pressed_no_signal(bool(_settings.get_value(String(LAYER_GRID))))
	_names_switch.set_pressed_no_signal(bool(_settings.get_value(String(LAYER_NAMES))))
	_relief_switch.set_pressed_no_signal(bool(_settings.get_value(String(LAYER_RELIEF))))
	_borders_switch.set_pressed_no_signal(bool(_settings.get_value(String(LAYER_BORDERS))))
	_tint_switch.set_pressed_no_signal(bool(_settings.get_value(String(LAYER_TINT))))
	_minimap_switch.set_pressed_no_signal(bool(_settings.get_value(String(LAYER_MINIMAP))))
	_syncing = false


func _on_setting_changed(key: String, value: Variant) -> void:
	if _syncing:
		return
	if key in LAYER_KEYS:
		set_layer_state(StringName(key), bool(value))


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null
