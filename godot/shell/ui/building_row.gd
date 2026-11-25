## One compact row of the Buildings tab (tile-window spec R19, R34; build plan TW11): an icon box, the name, a small state line
## (with a progress bar while a building is under way), the yearly gain as one signed number, and the hammer (a built row
## has a check instead; a locked row a lock). The row is given its data (one row of TileBuildings.of, with the tab's
## `expensive` flag added) and shows it; it never reads the game. The gain and upkeep come later, through set_numbers.
##   hovered(data)        the pointer entered the row (the tab shows the hover card)
##   unhovered()          the pointer left the row
##   hammer_pressed(data) the hammer was pressed (only while it is enabled: the tab applies the works rule)
class_name BuildingRow
extends PanelContainer

signal hovered(data: Dictionary)
signal unhovered
signal hammer_pressed(data: Dictionary)

const ICON_SIZE := 28
const HAMMER_W := 76
const BUILT_TEXT := "Built"
const LOCKED_TEXT := "Locked"
const BUSY_TIP := "a work is under way here"

var _data: Dictionary = {}
var _base_state := ""
var _icon_letter: Label
var _name: Label
var _state: Label
var _bar: ProgressBar
var _gain: Label
var _tick: Label
var _hammer: KitButton
var _lock: Label


## Builds the row's controls for `data`: {name, icon, state, state_text, tone, progress, upkeep, option, hammer, reason,
## expensive, gate}. Call once, before the row is added to the tree's visible part.
func setup(data: Dictionary) -> void:
	_data = data.duplicate()
	_base_state = str(data.get("state_text", ""))
	var built := StringName(str(data.get("state", ""))) == &"built"
	theme_type_variation = &"PanelSlot" if built else &"PanelCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered.emit(_data))
	mouse_exited.connect(func() -> void: unhovered.emit())
	_build_children()
	_fill_texts()


## The row's data as given (the tab and the tests read it).
func data() -> Dictionary:
	return _data.duplicate()


## Shows the gain and the upkeep of the row: the gain as one signed number, the upkeep added to a built or a buildable row's
## state line ("working · upkeep 6", "cost 120 · upkeep 8"). A null gain or upkeep shows nothing.
func set_numbers(gain: Variant, upkeep: Variant) -> void:
	_gain.text = "" if gain == null else Words.signed(int(gain))
	_gain.theme_type_variation = _gain_variation(gain)
	var state := StringName(str(_data.get("state", "")))
	if upkeep != null and (state == &"built" or state == &"ready"):
		_state.text = "%s · upkeep %d" % [_base_state, int(upkeep)]


## The gain text (tests read it) and the state line text.
func gain_text() -> String:
	return _gain.text


func state_text() -> String:
	return _state.text


func name_text() -> String:
	return _name.text


## The hammer button, or null on a built or a locked row.
func hammer() -> KitButton:
	return _hammer


## Whether the row shows the built check (a built row) and the lock (a locked row).
func shows_check() -> bool:
	return _tick != null and _tick.visible


func shows_lock() -> bool:
	return _lock != null and _lock.visible


## Whether the progress bar shows (a building row), and its value 0..100.
func shows_bar() -> bool:
	return _bar != null and _bar.visible


func bar_value() -> float:
	return _bar.value if _bar != null else 0.0


## Presses the hammer as a user would: emits hammer_pressed when it is enabled. Tests use it; the tab connects to the signal.
func press_hammer() -> void:
	if _hammer != null and not _hammer.disabled:
		hammer_pressed.emit(_data)


## The Studiolo variation of a gain number: good above zero, bad below, plain at zero or unknown.
static func _gain_variation(gain: Variant) -> StringName:
	if gain == null:
		return &"Number"
	if int(gain) > 0:
		return &"NumberGood"
	if int(gain) < 0:
		return &"NumberBad"
	return &"Number"


static func _tone_variation(tone: StringName) -> StringName:
	return &"Reason" if tone == &"bad" else &"Hint"


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


func _build_children() -> void:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", Tokens.S2)
	add_child(line)
	var icon := PanelContainer.new()
	icon.theme_type_variation = &"PanelSlot"
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	_icon_letter = PanelKit.label("", &"Number")
	_icon_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(_icon_letter)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(text)
	_name = PanelKit.label("", &"LabelInk")
	_name.clip_text = true
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_name)
	_state = PanelKit.label("", &"Hint")
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_state)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.custom_minimum_size.y = 6.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_bar)
	_gain = PanelKit.label("", &"Number")
	_gain.custom_minimum_size.x = float(Tokens.S5 * 2)
	_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_gain)
	_tick = PanelKit.label(BUILT_TEXT, &"Hint")
	_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_tick)
	_lock = PanelKit.label(LOCKED_TEXT, &"Hint")
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_lock)
	var kind := KitButton.Kind.DANGER if _action() == str(Works.CLEAR) else KitButton.Kind.SECONDARY
	_hammer = BuildRows.new_button(_verb_of(_action()), kind)
	_hammer.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hammer.custom_minimum_size.x = float(HAMMER_W)
	_hammer.pressed.connect(func() -> void: hammer_pressed.emit(_data))
	line.add_child(_hammer)
	if _action() == str(Works.UPGRADE):
		_hammer.hotkey_action = &"game_upgrade"


func _fill_texts() -> void:
	var built := StringName(str(_data.get("state", ""))) == &"built"
	var name_text := str(_data.get("name", ""))
	_name.text = name_text
	var icon_name := str(_data.get("icon", ""))
	_icon_letter.text = icon_name.substr(0, 1).to_upper()
	_state.text = _base_state
	_state.theme_type_variation = _tone_variation(StringName(str(_data.get("tone", "plain"))))
	var state := StringName(str(_data.get("state", "")))
	_bar.visible = state == &"building"
	_bar.value = float(_data.get("progress", 0.0)) * 100.0
	_tick.visible = built
	_lock.visible = state == &"locked"
	_hammer.visible = not built
	_hammer.disabled = not bool(_data.get("hammer", false))
	if state == &"locked" or state == &"building":
		_hammer.disabled = true
	var reason := str(_data.get("reason", ""))
	var busy := state == &"building" or reason.begins_with("one job at a time")
	_hammer.tooltip_text = "%s %s" % [_verb_of(_action()), name_text]
	# The button's tooltip is its verdict's reason while it is refused: a busy hex says so in one line.
	_hammer.set_verdict({"ok": not _hammer.disabled, "reason": BUSY_TIP if busy else reason})
	_gain.text = ""
