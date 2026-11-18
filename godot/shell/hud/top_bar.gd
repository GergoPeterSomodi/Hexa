## Studiolo walnut top bar (PanelBar) showing brand, map/seed info, season preview switcher,
## Layers popover toggle, Help, and Pause menu buttons (docs/architecture/ui-and-controls-spec.md section 7;
## ui-style-and-feedback-spec.md section 2; ui-style-and-feedback-plan.md U14).
class_name TopBar
extends PanelContainer

signal season_preview_requested(index: int)
signal layers_toggled(open: bool)
signal help_requested
signal menu_requested

const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const SEASON_LABELS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]

@onready var _brand_label: Label = $HBox/Brand
@onready var _map_info_label: Label = $HBox/MapInfo
@onready var _season_seg: Segmented = $HBox/SeasonSeg
@onready var _layers_btn: KitButton = $HBox/LayersButton
@onready var _help_btn: KitButton = $HBox/HelpButton
@onready var _menu_btn: KitButton = $HBox/MenuButton

var _season_index: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = float(Tokens.BAR_H)
	_brand_label.text = "HEXA"

	_season_seg.hud_mode = true
	var items: Array[Dictionary] = []
	for i: int in SEASON_LABELS.size():
		items.append({"id": i, "label": SEASON_LABELS[i], "tooltip": "%s preview [%d]" % [SEASON_LABELS[i], i + 1]})
	_season_seg.set_options(items)
	_season_seg.select(_season_index, false)
	_season_seg.changed.connect(_on_season_changed)

	_layers_btn.focus_mode = Control.FOCUS_NONE
	_layers_btn.toggled.connect(func(on: bool) -> void: layers_toggled.emit(on))

	_help_btn.focus_mode = Control.FOCUS_NONE
	_help_btn.hotkey_action = &"app_help"
	_help_btn.pressed.connect(func() -> void: help_requested.emit())

	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.hotkey_action = &"app_menu"
	_menu_btn.pressed.connect(func() -> void: menu_requested.emit())


func set_map_info(map_title: String, seed_value: int, mode_label: String = "Sandbox") -> void:
	if not is_node_ready():
		return
	var clean_title := map_title if not map_title.is_empty() else "North Italy"
	_map_info_label.text = "%s · %s, seed %d" % [clean_title, mode_label, seed_value]


func set_season(index: int) -> void:
	_season_index = clampi(index, 0, SEASONS.size() - 1)
	if is_node_ready():
		_season_seg.select(_season_index, false)


func set_season_name(season_name: String) -> void:
	var idx := SEASONS.find(season_name.to_lower())
	if idx >= 0:
		set_season(idx)


func set_layers_open(open: bool) -> void:
	if is_node_ready():
		_layers_btn.set_pressed_no_signal(open)


func refresh_hotkeys() -> void:
	if not is_node_ready():
		return
	_help_btn.refresh_hotkey()
	_menu_btn.refresh_hotkey()


func brand_label() -> Label:
	return _brand_label


func map_info_label() -> Label:
	return _map_info_label


func season_segmented() -> Segmented:
	return _season_seg


func layers_button() -> KitButton:
	return _layers_btn


func help_button() -> KitButton:
	return _help_btn


func menu_button() -> KitButton:
	return _menu_btn


func _on_season_changed(id: Variant) -> void:
	var idx := clampi(int(id), 0, SEASONS.size() - 1)
	_season_index = idx
	season_preview_requested.emit(idx)
