## The End season battle prompt (docs/architecture/moves-build-spec.md R74, D40): a Confirm that asks "Fight your N battles
## automatically?" before the season runs, with Yes, No and the box "Don't ask again". The box ticked keeps the answer as the
## setting game/battles_at_end (auto for Yes, board for No). Esc backs out: no season runs and nothing is kept. SeasonFlow
## pushes it only when wanted() says so, which needs a battle to ask about (BattlesAtEnd.count, 0 until the battle board).
## The prompt writes a setting and nothing else: no game state, no action log, no luck.
class_name AutoBattlesAsk
extends Confirm

## The player's answer, after the box has been kept: YES (fight them automatically), NO (play them) or CANCEL (Esc).
signal answered(choice: StringName)

const SETTING := "game/battles_at_end"
## The setting's three values.
const ASK := "ask"
const AUTO := "auto"
const BOARD := "board"
const YES := &"yes"
const NO := &"no"
const CANCEL := &"cancel"
const YES_LABEL := "Yes, fight automatically"
const NO_LABEL := "No, I will play them"
const BOX_TEXT := "Don't ask again"

var _kept_in: Settings = null
var _box: CheckBox = null


func _init() -> void:
	chose.connect(_on_chose)


## Whether the prompt is shown: there is a battle to ask about, the board's own "Your battles" is not Auto, and the setting
## still says ask. With no settings there is nothing that answered before, so it asks.
static func wanted(settings: Settings, battles: int, board_on_auto: bool = false) -> bool:
	if battles <= 0 or board_on_auto:
		return false
	return settings == null or str(settings.get_value(SETTING)) == ASK


static func question(battles: int) -> String:
	if battles == 1:
		return "Fight your battle automatically?"
	return "Fight your %d battles automatically?" % battles


## The prompt for `battles` battles; a ticked box keeps the answer in `settings`. Null when the scene cannot be had.
static func make_for(battles: int, settings: Settings) -> AutoBattlesAsk:
	var screen := ScreenIds.make(&"auto_battles_ask") as AutoBattlesAsk
	if screen != null:
		screen.set_question(battles, settings)
	return screen


## Sets the title, the two answers and the box. No has the focus: a repeated key press never fights battles by itself.
func set_question(battles: int, settings: Settings) -> void:
	_kept_in = settings
	configure({
		"title": question(battles),
		"choices": [
			{"id": YES, "label": YES_LABEL, "kind": "primary", "safe": false},
			{"id": NO, "label": NO_LABEL, "kind": "secondary", "safe": true},
		],
		"safe_choice": CANCEL,
		"seal_letter": "?",
	})
	_ensure_box()


func on_enter() -> void:
	super.on_enter()
	_ensure_box()
	_ink_box()


## The "Don't ask again" box.
func box() -> CheckBox:
	_ensure_box()
	return _box


func _ensure_box() -> void:
	if _box != null or sheet() == null:
		return
	_box = CheckBox.new()
	_box.name = &"DontAskBox"
	_box.text = BOX_TEXT
	_box.focus_mode = Control.FOCUS_ALL
	_box.custom_minimum_size.y = float(Tokens.TARGET_MIN)
	_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sheet().body().add_child(_box)


## The box in the sheet's ink, with no button plate behind it (the theme's buttons are drawn for the dark panels).
func _ink_box() -> void:
	if _box == null:
		return
	var ink := _box.get_theme_color(&"font_color", &"LabelInk")
	for colour: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_focus_color", &"icon_normal_color", &"icon_hover_color", &"icon_pressed_color",
			&"icon_hover_pressed_color", &"icon_focus_color", &"checkbox_checked_color", &"checkbox_unchecked_color"]:
		_box.add_theme_color_override(colour, ink)
	var bare := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		_box.add_theme_stylebox_override(state, bare)


func _on_chose(choice: StringName) -> void:
	if choice != CANCEL and _kept_in != null and _box != null and _box.button_pressed:
		_kept_in.set_value(SETTING, AUTO if choice == YES else BOARD)
	answered.emit(choice)
