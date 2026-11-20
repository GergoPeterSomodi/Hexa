## Studiolo walnut top bar (PanelBar): brand, the player's country (arms and long name, or the pick's title in a
## scenario game) or the map info of a map-only game, the mode switch (Terrain, Owner, Relief), the date and End turn (DateEnd, right of the middle),
## Layers, Help and Pause menu (docs/architecture/m2-build-spec.md section 7.3; ui-and-controls-spec.md section 7).
## M4 (spec 6.3): the resource chips (Ducats, Stores) sit right after the mode switch with the study button; both show only for
## the player of a game with countries. When the bar is tight the gap goes first, then the Stores chip shrinks to its medal and value,
## then the country name, the Ducats chip's name and change and the brand go, then the Stores chip itself; the Ducats medal and value and the study button stay down to about 800 px (the
## smallest window is 1024), and only below that, where nothing else is left, the chips and the study button hide (I, L and
## the country panel still open the study).
## It reads Session and Events and sends intents only. The name hides before the mode switch when the window narrows.
class_name TopBar
extends PanelContainer

signal layers_toggled(open: bool)
signal help_requested
signal menu_requested
signal mode_requested(mode: int)
signal country_requested(tag: StringName)
## A chip or the study button was pressed: the study opens at `page` (&"economy" for a chip, &"" its last page).
signal study_requested(page: StringName)

const MODE_LABELS: Array[String] = ["Terrain", "Owner", "Relief"]
const MODE_KEYS: Array[String] = ["1", "2", "3"]
const PICK_TAIL := ": choose your country"
const MAX_FITS_PER_FRAME := 3

@onready var _brand_label: Label = $HBox/Brand
@onready var _sep: VSeparator = $HBox/Sep
@onready var _map_info_label: Label = $HBox/MapInfo
@onready var _country_box: HBoxContainer = $HBox/CountryBox
@onready var _arms: CountryArms = $HBox/CountryBox/Arms
@onready var _country_btn: KitButton = $HBox/CountryBox/CountryButton
@onready var _mode_seg: Segmented = $HBox/ModeSeg
@onready var _chips: Chips = $HBox/Chips
@onready var _study_btn: Button = $HBox/StudyButton
@onready var _date_end: DateEnd = $HBox/DateEnd
@onready var _gap: Control = $HBox/Gap
@onready var _layers_btn: KitButton = $HBox/LayersButton
@onready var _help_btn: KitButton = $HBox/HelpButton
@onready var _menu_btn: KitButton = $HBox/MenuButton

var _mode_index: int = 0
var _name_wanted: bool = false
var _country_tag: StringName = &""
var _scenario_title: String = ""
var _info_wanted: bool = true
## A game with countries and a chosen player: the chips and the study button are wanted (the fit may still hide them).
var _economy_wanted: bool = false
var _fit_queued: bool = false
var _fitting: bool = false
## A fit shows and hides parts, which tells the bar to fit again; the fits queued in one frame are capped so it settles.
var _fit_frame: int = -1
var _fits_in_frame: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = float(Tokens.BAR_H)
	_brand_label.text = "HEXA"

	_mode_seg.hud_mode = true
	_mode_seg.add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # no dark box round the three mode buttons
	_mode_seg.changed.connect(_on_mode_changed)

	_country_btn.focus_mode = Control.FOCUS_NONE
	_country_btn.pressed.connect(func() -> void: country_requested.emit(_country_tag))

	_layers_btn.focus_mode = Control.FOCUS_NONE
	_layers_btn.toggled.connect(func(on: bool) -> void: layers_toggled.emit(on))

	_help_btn.focus_mode = Control.FOCUS_NONE
	_help_btn.hotkey_action = &"app_help"
	_help_btn.pressed.connect(func() -> void: help_requested.emit())

	_study_btn.focus_mode = Control.FOCUS_NONE
	_study_btn.tooltip_text = "The Statesman's Study"  # set here: the scene's value comes before the script and the hotkey tag
	(_study_btn as KitButton).hotkey_action = &"game_study"
	_study_btn.pressed.connect(func() -> void: study_requested.emit(&""))
	_chips.study_requested.connect(func() -> void: study_requested.emit(&"economy"))
	_chips.minimum_size_changed.connect(_queue_fit)
	_chips.refreshed.connect(_queue_fit)  # a refresh shows the chips again; the bar's fit wins

	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.hotkey_action = &"app_menu"
	_menu_btn.pressed.connect(func() -> void: menu_requested.emit())

	resized.connect(_queue_fit)
	get_viewport().size_changed.connect(_queue_fit)
	var verdict := _date_end.verdict_label()
	verdict.clip_text = true
	verdict.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	verdict.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_date_end.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_date_end.minimum_size_changed.connect(_queue_fit)
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
	_info_wanted = not has_countries
	_map_info_label.visible = _info_wanted
	_economy_wanted = has_countries and _country_tag != &""
	_study_btn.visible = _economy_wanted
	_chips.refresh()
	_refresh_name()
	_set_mode_options(has_countries)
	fit_width(available_width())


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


func set_layers_open(open: bool) -> void:
	if is_node_ready():
		_layers_btn.set_pressed_no_signal(open)


## Fits the bar into `width` px: the gap goes first, then the Stores chip shrinks to its medal and value, then the country
## name (or the map info of a sandbox), then the Ducats chip's name and change, then the brand, then the Stores chip, and last of all the chips and the study button; the arms,
## the switches, the date and End turn and the buttons stay, and the refusal line of the pick is clipped with an ellipsis
## (its label has no minimum width). Called on every resize and by refresh_game.
func fit_width(width: float) -> void:
	if not is_node_ready() or _fitting:
		return
	_fitting = true
	_fit(width)
	_fitting = false


func _fit(width: float) -> void:
	_country_btn.visible = _name_wanted
	_map_info_label.visible = _info_wanted
	_brand_label.visible = true
	_sep.visible = true
	_gap.visible = true
	_chips.visible = _economy_wanted
	_study_btn.visible = _economy_wanted
	var stores := _chips.stores_chip()
	var ducats := _chips.ducats_chip()
	stores.visible = true
	stores.set_name_shown(true)
	stores.set_change_shown(true)
	ducats.set_name_shown(true)
	ducats.set_change_shown(true)
	_resize_chip(stores)
	_resize_chip(ducats)
	if width <= 0.0:
		return
	if get_combined_minimum_size().x > width:
		_gap.visible = false  # the space between End turn and Layers goes first
	if get_combined_minimum_size().x > width:
		stores.set_name_shown(false)  # the Stores chip shrinks to its medal and value; it stays
		stores.set_change_shown(false)
		_resize_chip(stores)
	if get_combined_minimum_size().x > width:
		_country_btn.visible = false
		_map_info_label.visible = false
	if get_combined_minimum_size().x > width:
		ducats.set_name_shown(false)
		ducats.set_change_shown(false)
		_resize_chip(ducats)
	if get_combined_minimum_size().x > width:
		_brand_label.visible = false
		_sep.visible = false
	if get_combined_minimum_size().x > width:
		stores.visible = false
	if get_combined_minimum_size().x > width:
		_chips.visible = false  # below any real window: the keys and the country panel still open the study
		_study_btn.visible = false


func refresh_hotkeys() -> void:
	if not is_node_ready():
		return
	_help_btn.refresh_hotkey()
	_menu_btn.refresh_hotkey()
	_date_end.refresh_hotkeys()


## Whether the country name button is shown (false when narrowed away or when there is no country to name).
func name_shown() -> bool:
	return _country_btn.visible


func chips() -> Chips:
	return _chips


func study_button() -> Button:
	return _study_btn


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


func date_end() -> DateEnd:
	return _date_end


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


## The chips changed their width (a refresh, a new value): the bar is fitted again once, after the frame's layout.
func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	_run_fit.call_deferred()


## A chip takes its plate's minimum size one frame after a part hides; the fit needs it now.
func _resize_chip(chip: ResourceChip) -> void:
	var plate := chip.get_node_or_null("Plate") as Control
	if plate != null:
		chip.custom_minimum_size = plate.get_combined_minimum_size()


func _run_fit() -> void:
	_fit_queued = false
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var frame := Engine.get_process_frames()
	_fits_in_frame = _fits_in_frame + 1 if frame == _fit_frame else 1
	_fit_frame = frame
	if _fits_in_frame <= MAX_FITS_PER_FRAME:
		fit_width(available_width())


## The room the bar has: the window's width. (A bar cannot be narrower than its minimum, so its own width would only
## echo the minimum and the fit would think everything fits.)
func available_width() -> float:
	var vp := get_viewport()
	return vp.get_visible_rect().size.x if vp != null else size.x

