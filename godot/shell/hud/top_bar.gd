## Studiolo walnut top bar (PanelBar): brand, the player's country (arms and long name, or the pick's title in a
## scenario game) or the map info of a map-only game, the mode switch (Terrain, Owner, Relief), the season preview,
## Layers, Help and Pause menu (docs/architecture/m2-build-spec.md section 7.3; ui-and-controls-spec.md section 7).
## It reads Session and Events and sends intents only. The name hides before the mode switch when the window narrows.
class_name TopBar
extends PanelContainer

signal season_preview_requested(index: int)
signal layers_toggled(open: bool)
signal help_requested
signal menu_requested
signal mode_requested(mode: int)
signal country_requested(tag: StringName)

const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const SEASON_LABELS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const MODE_LABELS: Array[String] = ["Terrain", "Owner", "Relief"]
const MODE_KEYS: Array[String] = ["1", "2", "3"]
const PICK_TAIL := ": choose your country"

@onready var _brand_label: Label = $HBox/Brand
@onready var _map_info_label: Label = $HBox/MapInfo
@onready var _country_box: HBoxContainer = $HBox/CountryBox
@onready var _arms: CountryArms = $HBox/CountryBox/Arms
@onready var _country_btn: KitButton = $HBox/CountryBox/CountryButton
@onready var _mode_seg: Segmented = $HBox/ModeSeg
@onready var _season_seg: Segmented = $HBox/SeasonSeg
@onready var _layers_btn: KitButton = $HBox/LayersButton
@onready var _help_btn: KitButton = $HBox/HelpButton
@onready var _menu_btn: KitButton = $HBox/MenuButton

var _season_index: int = 1
var _mode_index: int = 0
var _name_wanted: bool = false
var _country_tag: StringName = &""
var _scenario_title: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = float(Tokens.BAR_H)
	_brand_label.text = "HEXA"

	_mode_seg.hud_mode = true
	_mode_seg.changed.connect(_on_mode_changed)

	_season_seg.hud_mode = true
	var items: Array[Dictionary] = []
	for i: int in SEASON_LABELS.size():
		items.append({"id": i, "label": SEASON_LABELS[i], "tooltip": "%s preview [%d]" % [SEASON_LABELS[i], i + 1]})
	_season_seg.set_options(items)
	_season_seg.select(_season_index, false)
	_season_seg.changed.connect(_on_season_changed)

	_country_btn.focus_mode = Control.FOCUS_NONE
	_country_btn.pressed.connect(func() -> void: country_requested.emit(_country_tag))

	_layers_btn.focus_mode = Control.FOCUS_NONE
	_layers_btn.toggled.connect(func(on: bool) -> void: layers_toggled.emit(on))

	_help_btn.focus_mode = Control.FOCUS_NONE
	_help_btn.hotkey_action = &"app_help"
	_help_btn.pressed.connect(func() -> void: help_requested.emit())

	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.hotkey_action = &"app_menu"
	_menu_btn.pressed.connect(func() -> void: menu_requested.emit())

	resized.connect(func() -> void: fit_width(size.x))
	Events.game_started.connect(refresh_game)
	Events.country_chosen.connect(_on_country_chosen)
	refresh_game()


func _exit_tree() -> void:
	if Events.game_started.is_connected(refresh_game):
		Events.game_started.disconnect(refresh_game)
	if Events.country_chosen.is_connected(_on_country_chosen):
		Events.country_chosen.disconnect(_on_country_chosen)


## Reads the game: a scenario game shows the player's arms and long name (or the pick's title until a country is
## chosen) and offers Owner; a map-only game shows its map info and no Owner mode.
func refresh_game() -> void:
	if not is_node_ready():
		return
	var game := Session.game
	var has_countries := game != null and game.has_countries()
	_country_tag = Session.player_tag() if has_countries else &""
	_scenario_title = game.scenario.name if has_countries else ""
	_name_wanted = has_countries
	_country_box.visible = has_countries
	_map_info_label.visible = not has_countries
	_refresh_name()
	_set_mode_options(has_countries)
	fit_width(size.x)


func set_map_info(map_title: String, seed_value: int, mode_label: String = "Sandbox") -> void:
	if not is_node_ready():
		return
	var clean_title := map_title if not map_title.is_empty() else "North Italy"
	_map_info_label.text = "%s · %s, seed %d" % [clean_title, mode_label, seed_value]


## Shows `mode` (0 Terrain, 1 Owner, 2 Relief) as the selected mode, without a signal.
func set_mode(mode: int) -> void:
	_mode_index = clampi(mode, 0, MODE_LABELS.size() - 1)
	if is_node_ready():
		_mode_seg.select(_mode_index, false)


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


## Hides the country name when the bar is `width` px wide and too narrow for it; the arms, brand, switches and buttons
## stay. Called on every resize and by refresh_game.
func fit_width(width: float) -> void:
	if not is_node_ready():
		return
	_country_btn.visible = _name_wanted
	if _name_wanted and width > 0.0 and get_combined_minimum_size().x > width:
		_country_btn.visible = false


func refresh_hotkeys() -> void:
	if not is_node_ready():
		return
	_help_btn.refresh_hotkey()
	_menu_btn.refresh_hotkey()


## Whether the country name button is shown (false when narrowed away or when there is no country to name).
func name_shown() -> bool:
	return _country_btn.visible


func brand_label() -> Label:
	return _brand_label


func map_info_label() -> Label:
	return _map_info_label


func country_button() -> KitButton:
	return _country_btn


func arms() -> CountryArms:
	return _arms


func mode_segmented() -> Segmented:
	return _mode_seg


func season_segmented() -> Segmented:
	return _season_seg


func layers_button() -> KitButton:
	return _layers_btn


func help_button() -> KitButton:
	return _help_btn


func menu_button() -> KitButton:
	return _menu_btn


func _refresh_name() -> void:
	if not _name_wanted:
		_arms.visible = false
		_country_btn.visible = false
		return
	if _country_tag == &"":
		_arms.set_country({})
		_arms.visible = false
		_country_btn.text = (_scenario_title + PICK_TAIL) if _scenario_title != "" else "Choose your country"
		_country_btn.tooltip_text = "Choose your country"
		return
	var card := CountryCard.of(Session.game, _country_tag)
	_arms.visible = not card.is_empty()
	_arms.set_country(card.get("arms", {}) as Dictionary)
	_country_btn.text = str(card.get("long_name", String(_country_tag)))
	_country_btn.tooltip_text = "Your country (C)"


func _set_mode_options(has_owner: bool) -> void:
	if not has_owner and _mode_index == int(MapModes.Mode.OWNER):
		_mode_index = int(MapModes.Mode.TERRAIN)
	var items: Array[Dictionary] = []
	for i: int in MODE_LABELS.size():
		if i == int(MapModes.Mode.OWNER) and not has_owner:
			continue
		items.append({"id": i, "label": MODE_LABELS[i], "tooltip": "%s [%s]" % [MODE_LABELS[i], MODE_KEYS[i]]})
	_mode_seg.set_options(items)
	_mode_seg.select(_mode_index, false)


func _on_mode_changed(id: Variant) -> void:
	_mode_index = clampi(int(id), 0, MODE_LABELS.size() - 1)
	mode_requested.emit(_mode_index)


func _on_country_chosen(_tag: StringName) -> void:
	refresh_game()


func _on_season_changed(id: Variant) -> void:
	var idx := clampi(int(id), 0, SEASONS.size() - 1)
	_season_index = idx
	season_preview_requested.emit(idx)
