## The Goods mode's card (docs/architecture/map-overview-build-spec.md R20, R25, D10): a kit frame, bottom left of the map
## area, with one toggle button a good (ParchmentView.goods_list, Kit icons, COLUMNS a row), each with the count of the
## districts you know that make it as its tooltip, and the greyed "soon" rows under them. The chosen good is the button
## held down, filled with the kit's gold plate and its thick border (ButtonChoice), with a tick on it. Picking writes the
## setting state/map_good and sends good_changed. While the settings do not know that key, or there are no settings, the
## card remembers the choice itself. The buttons take the keyboard focus (focus_selected; arrows move in the grid, Enter
## or Space picks, Esc gives the focus back to the map); any release of the mouse on a button, and any mouse press on the
## map, lets the focus go, so Space ends the turn again. The Hud shows it (set_active), covers it (set_covered), places it
## and picks its layout (HudLayout, set_layout). It reads Session and Events and changes no game.
class_name GoodsCard
extends PanelFrame

## The chosen good changed (a pick here, or the setting changed elsewhere).
signal good_changed(good_id: int)
## The goods and their counts were read again.
signal refreshed

const GOOD_SETTING := "state/map_good"
const DEFAULT_GOOD := &"grain"
const COLUMNS := 6
const BUTTON_SIDE := 40.0
## The chosen good's button wears the kit's filled choice; the others the kit's toggle.
const CHOSEN_STYLE := &"ButtonChoice"
const OTHER_STYLE := &"ButtonToggle"
## The tick on the chosen good: its side, in px.
const TICK_SIDE := 14.0
## The map modes the card promises (R20): greyed, with the SoonTag.
const SOON_ROWS: Array[String] = ["Population", "Unrest"]
const TIP_FORMAT := "%s: %s"
## The mouse buttons whose press on the map takes the keyboard back (the wheel only zooms).
const MAP_BUTTONS: Array[MouseButton] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]

var _settings: Settings = null
var _chosen: StringName = DEFAULT_GOOD
var _active := false
var _covered := false
var _refresh_queued := false
## set_layout's buttons a row, soon rows (1 or 0) and rows of buttons shown (0: all).
var _layout := Vector3i(COLUMNS, 1, 0)
var _grid: GridContainer = null
var _buttons: Dictionary[StringName, KitButton] = {}
var _retired: Array[Node] = []


## The entry of `goods` (ParchmentView.goods_list) with `key`; the first one for an unknown key; {} when there are none.
static func resolve(goods: Array[Dictionary], key: StringName) -> Dictionary:
	for good: Dictionary in goods:
		if good["key"] == key:
			return good
	return goods[0] if not goods.is_empty() else {}


func _ready() -> void:
	super()
	cartouche_title = MapModes.GOODS_TITLE
	show_close = false
	body_scroll().vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # the card is as tall as what it holds
	body_scroll().follow_focus = true  # where it does scroll, the keyboard's button comes into view
	_grid = GridContainer.new()
	_grid.name = &"Grid"
	_grid.columns = _layout.x
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_theme_constant_override(&"h_separation", Tokens.S1)
	_grid.add_theme_constant_override(&"v_separation", Tokens.S1)
	body().add_child(_grid)
	for title_text: String in SOON_ROWS:
		body().add_child(_soon_row(title_text))
	for sig: Signal in _world_signals():
		sig.connect(_on_world_changed)
	_sync_visible()


func _exit_tree() -> void:
	for sig: Signal in _world_signals():
		if sig.is_connected(_on_world_changed):
			sig.disconnect(_on_world_changed)
	_disconnect_settings()
	PanelKit.free_retired(_retired)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_sync_selection()


## Esc with the focus in the card gives it back to the map, and does nothing else (not the pause menu).
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or not _has_focus_inside():
		return
	if (InputMap.has_action(&"app_back") and key.is_action(&"app_back")) or key.is_action(&"ui_cancel"):
		get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()


## A mouse press that no Control took is a press on the map: the keyboard goes back there.
func _unhandled_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and MAP_BUTTONS.has(mouse.button_index) and _has_focus_inside():
		get_viewport().gui_release_focus()


## A button takes Enter and Space but lets the event go on: the card keeps it from the map, where it ends the turn (a
## held key's repeats too).
func _shortcut_input(event: InputEvent) -> void:
	if event.is_action(&"ui_accept") and _has_focus_inside():
		get_viewport().set_input_as_handled()


func configure(settings: Settings) -> void:
	if settings != _settings:
		_disconnect_settings()
		_settings = settings
		if _settings != null:
			_settings.changed.connect(_on_setting_changed)
	if _settings != null:
		var value: Variant = _settings.get_value(GOOD_SETTING)
		if value is String:
			_choose(StringName(value as String))


## Goods mode is on (true) or off.
func set_active(on: bool) -> void:
	_active = on
	_sync_visible()
	if visible:
		refresh()


## A screen that hides the world is up (true) or closed (false).
func set_covered(covered: bool) -> void:
	var was := visible
	_covered = covered
	_sync_visible()
	if visible and not was:
		refresh()


## The chosen good's key (an unknown one reads as the first good); &"" without goods.
func good_key() -> StringName:
	return resolve(ParchmentView.goods_list(Session.game), _chosen).get("key", &"") as StringName


## The chosen good's id; -1 without goods.
func good_id() -> int:
	return int(resolve(ParchmentView.goods_list(Session.game), _chosen).get("id", -1))


## Chooses the good `key` and writes it to the setting.
func pick(key: StringName) -> void:
	_choose(key)
	if _settings != null:
		_settings.set_value(GOOD_SETTING, String(key))


## The button of the good `key`, or null.
func button_for(key: StringName) -> KitButton:
	return _buttons.get(key) as KitButton


## The goods' buttons in grid order.
func buttons() -> Array[KitButton]:
	var out: Array[KitButton] = []
	out.assign(_buttons.values())
	return out


## The keyboard's way into the card (R25): puts the focus on the chosen good's button. False, and nothing happens, while
## the card is hidden. Esc leads back to the map.
func focus_selected() -> bool:
	var button := button_for(good_key())
	if button == null or not button.is_visible_in_tree():
		return false
	button.grab_focus()
	return true


## Picks the good `by` places on in the goods' order, round from the last to the first ([ and ], R25). The keyboard, when
## it is in the card, goes with the choice.
func step(by: int) -> void:
	var goods := ParchmentView.goods_list(Session.game)
	var key := good_key()
	for i: int in goods.size():
		if goods[i]["key"] != key:
			continue
		var focused := is_inside_tree() and _has_focus_inside()
		pick(goods[posmod(i + by, goods.size())]["key"])
		if focused:
			focus_selected()
		return


## The card's size in the layout `layout`: x buttons a row, the soon rows (y 1) or not (0), and z rows of buttons shown
## (0: all of them; fewer than there are scroll).
func size_for(layout: Vector3i) -> Vector2:
	var list := buttons()
	var cell := Vector2(BUTTON_SIDE, BUTTON_SIDE) if list.is_empty() else list[0].get_combined_minimum_size()
	var gap := float(Tokens.S1)
	var all_rows := ceili(float(list.size()) / layout.x)
	var shown := all_rows if layout.z <= 0 else mini(layout.z, all_rows)
	var inner := Vector2(layout.x * cell.x + (layout.x - 1) * gap, shown * cell.y + maxi(shown - 1, 0) * gap)
	if shown < all_rows:
		inner.x += body_scroll().get_v_scroll_bar().get_combined_minimum_size().x
	if layout.y == 1:
		for title_text: String in SOON_ROWS:
			var line := (body().get_node(title_text) as Control).get_combined_minimum_size()
			inner = Vector2(maxf(inner.x, line.x), inner.y + body().get_theme_constant(&"separation") + line.y)
	var column := get_node("VBox") as VBoxContainer
	var head := (column.get_node("Head") as Control).get_combined_minimum_size()
	inner = Vector2(maxf(inner.x, head.x), inner.y + head.y + column.get_theme_constant(&"separation"))
	var frame := get_theme_stylebox(&"panel").get_minimum_size()
	return inner + frame + body_scroll().get_theme_stylebox(&"panel").get_minimum_size()


## Takes the layout `layout` (as size_for); the card's rect is the HudLayout's to set.
func set_layout(layout: Vector3i) -> void:
	if layout == _layout or not is_node_ready():
		return
	_layout = layout
	_grid.columns = layout.x
	for title_text: String in SOON_ROWS:
		(body().get_node(title_text) as Control).visible = layout.y == 1
	var scrolls := layout.z > 0 and layout.z * layout.x < _buttons.size()
	var mode := ScrollContainer.SCROLL_MODE_AUTO if scrolls else ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll().vertical_scroll_mode = mode
	_link_focus(buttons())


## The layout the card is in (as size_for).
func layout() -> Vector3i:
	return _layout


## Reads the goods and what you know of them again: the buttons and their tooltips.
func refresh() -> void:
	_refresh_queued = false
	if not is_node_ready():
		return
	var game := Session.game
	var viewer := Session.player_tag()
	var goods := ParchmentView.goods_list(game)
	var keys: Array = goods.map(func(good: Dictionary) -> StringName: return good["key"])
	if keys != _buttons.keys():
		_build_grid(goods)
	for good: Dictionary in goods:
		var words := ParchmentView.count_words(ParchmentView.count_of(game, viewer, int(good["id"])))
		_buttons[good["key"]].tooltip_text = TIP_FORMAT % [good["name"], words]
	_sync_selection()
	refreshed.emit()


func _choose(key: StringName) -> void:
	var changed := key != _chosen
	_chosen = key
	if is_node_ready():
		_sync_selection()
	if changed:
		good_changed.emit(good_id())


func _build_grid(goods: Array[Dictionary]) -> void:
	PanelKit.clear_children(_grid, _retired)
	_buttons.clear()
	for good: Dictionary in goods:
		var button := _good_button(good)
		_grid.add_child(button)
		_buttons[good["key"]] = button
	_link_focus(buttons())


func _good_button(good: Dictionary) -> KitButton:
	var key: StringName = good["key"]
	var button := KitButton.new()
	button.name = String(key).to_pascal_case()
	button.kind = KitButton.Kind.TOGGLE
	button.icon_name = good["icon"]
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(BUTTON_SIDE, BUTTON_SIDE)
	button.focus_mode = Control.FOCUS_ALL
	button.add_to_group(CameraRig.ARROW_FOCUS_GROUP)  # the arrows move in the grid and pan nothing
	button.accessibility_name = str(good["name"])
	var tick := TextureRect.new()
	tick.name = &"Tick"
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tick.self_modulate = Tokens.PRIMARY_INK  # dark on the choice's gold
	tick.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tick.offset_left = -TICK_SIDE - 1.0
	tick.offset_right = -1.0
	tick.offset_top = 1.0
	tick.offset_bottom = TICK_SIDE + 1.0
	button.add_child(tick)
	button.gui_input.connect(_on_button_input.bind(button))
	button.pressed.connect(pick.bind(key))
	return button


## The arrows stay in the grid: each button's neighbours are the buttons beside it, itself at an edge; down from above a
## short last row goes to its last button.
func _link_focus(list: Array[KitButton]) -> void:
	var n := list.size()
	var columns := _layout.x
	for i: int in n:
		var button := list[i]
		var column := i % columns
		var left := list[i - 1] if column > 0 else button
		var right := list[i + 1] if column < columns - 1 and i + 1 < n else button
		var up := list[i - columns] if i >= columns else button
		@warning_ignore("integer_division")
		var has_row_below := i / columns < (n - 1) / columns
		var down := list[mini(i + columns, n - 1)] if has_row_below else button
		button.focus_neighbor_left = button.get_path_to(left)
		button.focus_neighbor_right = button.get_path_to(right)
		button.focus_neighbor_top = button.get_path_to(up)
		button.focus_neighbor_bottom = button.get_path_to(down)


## The chosen button is held down, filled and carries the tick: its shape says so, not only its colour.
func _sync_selection() -> void:
	var chosen := good_key()
	var tick_icon: Texture2D = get_theme_icon(&"tick", &"Kit") if has_theme_icon(&"tick", &"Kit") else null
	for key: StringName in _buttons:
		var button := _buttons[key]
		button.set_pressed_no_signal(key == chosen)
		button.theme_type_variation = CHOSEN_STYLE if key == chosen else OTHER_STYLE
		var tick := button.get_node("Tick") as TextureRect
		tick.texture = tick_icon
		tick.visible = key == chosen


func _soon_row(title_text: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = title_text
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.tooltip_text = SoonTag.EXAMPLE_TIP
	var words := PanelKit.label(title_text, &"Hint")
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	line.add_child(SoonTag.new())
	return line


func _world_signals() -> Array[Signal]:
	return [Events.game_started, Events.country_chosen, Events.season_ended, Events.hex_changed, Events.owners_changed,
		Events.work_finished, Events.army_changed]


## Something that may change a count happened: read again once, after this frame's events, while the card is up.
func _on_world_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	if visible and not _refresh_queued:
		_refresh_queued = true
		refresh.call_deferred()


## A release of the mouse, on the button or dragged off it, gives the focus back. Deferred: a button that loses the
## focus before it has seen the release drops its press.
func _on_button_input(event: InputEvent, button: KitButton) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and not mouse.pressed:
		button.release_focus.call_deferred()


func _has_focus_inside() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and is_ancestor_of(focused)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == GOOD_SETTING:
		_choose(StringName(str(value)))


func _sync_visible() -> void:
	visible = _active and not _covered


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
