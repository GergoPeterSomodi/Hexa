## One building of the Buildings tab as an icon tile on its wooden strip (tile-window spec R19, R34; the owner's mockup v4, after
## EU4 and EU5): the family's Kit icon on a square tile whose rim says the state. Built: the wood tile with a gold rim and the
## level (I, II, III) at its corner. Building: a green rim and a thin progress bar. Can build: a dark tile with a green rim, the
## whole tile is the hammer. Short of ducats or goods: a red rim. Refused or locked: a dark tile with the lock. The words (name,
## state line, gain, upkeep, cost, the reason) are not drawn: they are the row's data, kept for the tab, the tests and the hover
## card (BuildingCard through the tab's row_hovered), and the hammer's tooltip carries the verdict.
## The row is given its data (one row of TileBuildings.of, with the tab's `expensive` flag and, for a built row, `level`) and
## shows it; it never reads the game. The gain and upkeep come later, through set_numbers.
##   hovered(data)        the pointer entered the tile (the tab shows the hover card)
##   unhovered()          the pointer left the tile
##   hammer_pressed(data) the tile was pressed (only while its hammer is enabled: the tab applies the works rule)
class_name BuildingRow
extends PanelContainer

signal hovered(data: Dictionary)
signal unhovered
signal hammer_pressed(data: Dictionary)

## The tile's side and its icon's, in logical pixels (mockup v4: 48 and 28).
const TILE := Vector2(48, 48)
const ICON := Vector2(28, 28)
const BAR_H := 4
const LOCK_ICON := &"lock"
const BUSY_TIP := "a work is under way here"
const ROMAN: Array[String] = ["", "I", "II", "III", "IV", "V", "VI"]
## The Kit icon of each improvement family (FamilyIds.NAMES); a family missing here shows no icon.
const FAMILY_ICONS: Dictionary = {
	"settlements": &"settlement", "castles": &"castle", "wheat": &"good_grain", "hemp": &"good_hemp", "silk": &"good_silk",
	"dyes": &"good_dyes", "vineyard": &"good_wine", "olives": &"good_oil", "grazing": &"good_cattle",
	"timber": &"good_timber", "mines": &"jobs", "quarry": &"good_stone", "salt": &"good_salt", "harbour": &"port_dues",
}
## The tile's look by row state.
const STATE_VARIATIONS := {&"built": &"PanelTileTile", &"building": &"PanelTileTileWork", &"ready": &"PanelTileTileFree",
	&"short": &"PanelTileTileShort", &"locked": &"PanelTileTileLock", &"refused": &"PanelTileTileLock"}

var _data: Dictionary = {}
var _base_state := ""
var _built := false
var _icon: TextureRect
var _level: Label
var _name: Label
var _state: Label
var _bar: ProgressBar
var _gain: Label
var _hammer: KitButton


## Builds the tile's controls for `data`: {name, icon, state, state_text, tone, progress, upkeep, option, hammer, reason,
## expensive, gate, level}. Call once, before the tile is added to the tree's visible part.
func setup(data: Dictionary) -> void:
	_data = data.duplicate()
	_base_state = str(data.get("state_text", ""))
	var state := StringName(str(data.get("state", "")))
	_built = state == &"built"
	theme_type_variation = STATE_VARIATIONS.get(state, &"PanelTileTileLock")
	custom_minimum_size = TILE
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_entered.connect(func() -> void: hovered.emit(_data))
	mouse_exited.connect(func() -> void: unhovered.emit())
	_build_children()
	_fill_texts()


func _ready() -> void:
	var state := StringName(str(_data.get("state", "")))
	var locked := state == &"locked" or state == &"refused"
	var family := StringName(FAMILY_ICONS.get(str(_data.get("icon", "")), &""))
	_icon.texture = _kit_icon(LOCK_ICON if locked else family)
	_icon.modulate.a = 0.55 if locked else 1.0
	# The tile window's clear hit button over the tile; set here, after the KitButton's own _ready set its kind's variation.
	_hammer.theme_type_variation = &"ButtonTileHit"
	_hammer.icon = null


## The row's data as given (the tab and the tests read it).
func data() -> Dictionary:
	return _data.duplicate()


## Keeps the gain and the upkeep of the row (for the tab's summary, the tests and the card): the gain as one signed number, the
## upkeep added to a built or a buildable row's state line ("working · upkeep 6", "cost 120 · upkeep 8"). Null shows nothing.
func set_numbers(gain: Variant, upkeep: Variant) -> void:
	_gain.text = "" if gain == null else Words.signed(int(gain))
	var state := StringName(str(_data.get("state", "")))
	if upkeep != null and (state == &"built" or state == &"ready"):
		_state.text = "%s · upkeep %d" % [_base_state, int(upkeep)]
	_tip()


## The gain text, the state line text and the name (tests and the tab read them; the tile does not draw them).
func gain_text() -> String:
	return _gain.text


func state_text() -> String:
	return _state.text


func name_text() -> String:
	return _name.text


## The hammer: the clear button over the tile; hidden on a built tile.
func hammer() -> KitButton:
	return _hammer


## Whether the tile is a built one (its gold rim and level; the old row's check) and whether it shows the lock.
func shows_check() -> bool:
	return _built


func shows_lock() -> bool:
	var state := StringName(str(_data.get("state", "")))
	return _hammer != null and _hammer.disabled and (state == &"locked" or state == &"refused")


## Whether the progress bar shows (a building tile), and its value 0..100.
func shows_bar() -> bool:
	return _bar != null and _bar.visible


func bar_value() -> float:
	return _bar.value if _bar != null else 0.0


## The level shown at the tile's corner ("" when none).
func level_text() -> String:
	return _level.text if _level != null else ""


## Presses the hammer as a user would: emits hammer_pressed when it is enabled. Tests use it; the tab connects to the signal.
func press_hammer() -> void:
	if _hammer != null and not _hammer.disabled:
		hammer_pressed.emit(_data)


## The action of the row's option ("build", "upgrade", "clear"); "" for a built or a work row.
func _action() -> String:
	var option: Dictionary = _data.get("option", {})
	return str(option.get("action", ""))


static func _verb_of(action: String) -> String:
	match action:
		"upgrade":
			return "Upgrade"
		"clear":
			return "Clear"
	return "Build"


func _kit_icon(icon_name: StringName) -> Texture2D:
	if icon_name == &"" or not has_theme_icon(icon_name, &"Kit"):
		return null
	return get_theme_icon(icon_name, &"Kit")


func _build_children() -> void:
	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_level = PanelKit.label("", &"TileLevel")
	_level.size_flags_horizontal = Control.SIZE_SHRINK_END
	_level.size_flags_vertical = Control.SIZE_SHRINK_END
	_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.custom_minimum_size = Vector2(TILE.x - 8.0, float(BAR_H))
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	# The words: kept, not drawn (the hover card says them).
	_name = PanelKit.label("", &"TileName")
	_state = PanelKit.label("", &"Hint")
	_gain = PanelKit.label("", &"TileValue")
	for hidden: Label in [_name, _state, _gain]:
		hidden.visible = false
		add_child(hidden)
	_hammer = KitButton.new()
	_hammer.kind = KitButton.Kind.ICON
	_hammer.focus_mode = Control.FOCUS_ALL
	_hammer.mouse_filter = Control.MOUSE_FILTER_PASS
	_hammer.custom_minimum_size = TILE
	_hammer.mouse_entered.connect(func() -> void: hovered.emit(_data))
	_hammer.pressed.connect(func() -> void: hammer_pressed.emit(_data))
	add_child(_hammer)
	if _action() == str(Works.UPGRADE):
		_hammer.hotkey_action = &"game_upgrade"


func _fill_texts() -> void:
	var name_text := str(_data.get("name", ""))
	_name.text = name_text
	_state.text = _base_state
	var state := StringName(str(_data.get("state", "")))
	_bar.visible = state == &"building"
	_bar.value = float(_data.get("progress", 0.0)) * 100.0
	var level := int(_data.get("level", 0))
	_level.text = ROMAN[level] if _built and level > 0 and level < ROMAN.size() else ""
	_hammer.visible = not _built
	_hammer.disabled = not bool(_data.get("hammer", false))
	if state == &"locked" or state == &"building":
		_hammer.disabled = true
	var reason := str(_data.get("reason", ""))
	var busy := state == &"building" or reason.begins_with("one job at a time")
	var verb := "%s %s" % [_verb_of(_action()), name_text]
	_hammer.tooltip_text = verb
	_hammer.accessibility_name = verb
	# The button's tooltip is its verdict's reason while it is refused: a busy hex says so in one line.
	_hammer.set_verdict({"ok": not _hammer.disabled, "reason": BUSY_TIP if busy else reason})
	_gain.text = ""
	_tip()


## The tile's own tooltip, under the hover card: its name (and level), its state line, and its gain once known.
func _tip() -> void:
	var title := _name.text + (" (level %s)" % _level.text if _level.text != "" else "")
	var lines: Array[String] = [title]
	if _state.text != "":
		lines.append(_state.text)
	if _gain.text != "":
		lines.append("%s ducats a year" % _gain.text)
	tooltip_text = "
".join(lines)
