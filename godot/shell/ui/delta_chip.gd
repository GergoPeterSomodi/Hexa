## Signed delta readout with Kit tone icon (arrow_up / arrow_down / dash), explicit sign
## (+ / U+2212 / 0), optional PanelSlot plate, vellum-ink variant, and invert mode for costs
## (docs/architecture/ui-style-and-feedback-spec.md section 5; game-feedback-screens.md A.2).
class_name DeltaChip
extends PanelContainer

const MINUS_SIGN := "\u2212"

@export var ink: bool = false:
	set(value):
		ink = value
		_apply_display()

@export var boxed: bool = false:
	set(value):
		boxed = value
		_sync_boxed()

@export var invert: bool = false:
	set(value):
		invert = value
		_apply_display()

var _amount: int = 0
var _unit: String = ""
var _label: String = ""
var _has_value: bool = false
var _icon_name: StringName = &"dash"

var _hbox: HBoxContainer = null
var _icon: TextureRect = null
var _text_label: Label = null


func _init() -> void:
	theme_type_variation = &"PanelSlot"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_boxed()

	_hbox = HBoxContainer.new()
	_hbox.name = &"HBox"
	_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_hbox)

	_icon = TextureRect.new()
	_icon.name = &"Icon"
	_icon.custom_minimum_size = Vector2(float(Tokens.S4), float(Tokens.S4))
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hbox.add_child(_icon)

	_text_label = Label.new()
	_text_label.name = &"Text"
	_text_label.theme_type_variation = &"Hint"
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hbox.add_child(_text_label)


func _ready() -> void:
	_sync_boxed()
	if _has_value:
		_apply_display()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_apply_display()


## Sets the signed integer delta, optional unit (e.g. "ducats"), and optional prefix label.
func set_delta(amount: int, unit: String = "", label: String = "") -> void:
	_amount = amount
	_unit = unit
	_label = label
	_has_value = true
	_apply_display()


## Returns the rendered text string (including sign, unit, and label if set).
func text() -> String:
	return _text_label.text if _text_label != null else ""


## Returns the active Kit theme icon name (`arrow_up`, `arrow_down`, or `dash`).
func icon_name() -> StringName:
	return _icon_name


## Returns the inner Label node displaying the signed delta text.
func label_node() -> Label:
	return _text_label


## Returns the inner TextureRect node displaying the direction icon.
func icon_node() -> TextureRect:
	return _icon


func _sync_boxed() -> void:
	self_modulate.a = 1.0 if boxed else 0.0


func _apply_display() -> void:
	if _text_label == null or _icon == null:
		return

	var sign_text := "0"
	var dir_word := "no change"
	if _amount > 0:
		sign_text = "+%d" % _amount
		_icon_name = &"arrow_up"
		dir_word = "up %d" % _amount
	elif _amount < 0:
		sign_text = "%s%d" % [MINUS_SIGN, absi(_amount)]
		_icon_name = &"arrow_down"
		dir_word = "down %d" % absi(_amount)
	else:
		_icon_name = &"dash"

	var display_text := sign_text if _unit.is_empty() else "%s %s" % [sign_text, _unit]
	if not _label.is_empty():
		display_text = "%s %s" % [_label, display_text]
	_text_label.text = display_text

	var a11y := dir_word
	if _amount != 0 and not _unit.is_empty():
		a11y = "%s %s" % [dir_word, _unit]
	if not _label.is_empty():
		a11y = "%s %s" % [_label, a11y]
	accessibility_name = a11y

	var variation := _tone_variation()
	_text_label.theme_type_variation = variation

	if has_theme_icon(_icon_name, &"Kit"):
		_icon.texture = get_theme_icon(_icon_name, &"Kit")
	else:
		_icon.texture = null

	if has_theme_color(&"font_color", variation):
		_icon.self_modulate = get_theme_color(&"font_color", variation)
	else:
		_icon.self_modulate = _fallback_tone_color()


func _tone_variation() -> StringName:
	if _amount == 0:
		return &"LabelInkMuted" if ink else &"Hint"
	var is_good := (_amount > 0) != invert
	if is_good:
		return &"NumberInkGood" if ink else &"NumberGood"
	return &"NumberInkBad" if ink else &"NumberBad"


func _fallback_tone_color() -> Color:
	if _amount == 0:
		return Tokens.VELLUM_MUTED if ink else Tokens.MUTED
	var is_good := (_amount > 0) != invert
	if is_good:
		return Tokens.GOOD_INK if ink else Tokens.GOOD
	return Tokens.BAD_INK if ink else Tokens.BAD
