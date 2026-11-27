## The move card (docs/architecture/m6-build-spec.md 6.7; L20, issue #210): a hover card with the words of a march to the hex
## under the pointer (or at the order cursor), while an army of yours is selected. MapHover shows it in place of the hex card
## and calls show_move with MovePreview.to's preview: the title (the place), its lines in their tones, and the way out of a
## refusal. The lines keep the preview's order (the war line, this season's walk and its risks, the arrival, the crossings, the
## supply; moves-build-spec.md R47); a line the preview says twice (a risk that is also the supply line) shows once, in its
## first place and in the stronger tone. It only shows: it ignores the mouse and never takes the focus. Ordering is
## MapArmies' right click and O. While stops are staged (R62) it is pinned by the last stop instead of following the pointer,
## and a row of two buttons on its top, the only part that takes the mouse, says "March" and "Clear stops" (MapHover gives them
## to MapArmies).
class_name MoveCard
extends PanelContainer

signal march_pressed
signal clear_pressed

const MARCH_LABEL := "March"
const CLEAR_LABEL := "Clear stops"
const CARD_W: float = 300.0
## The width the words wrap to: the card less its frame's margins. A label's height is measured at this width, so the card
## is as tall as its words and no taller (a label measured at width 0 wraps one letter a line).
const WRAP_W: float = 264.0
## The meta key of a label's words before it is wrapped.
const RAW := &"words"
## The tones from the weakest to the strongest: a line said twice keeps the stronger.
const TONE_RANK: Array[StringName] = [&"muted", &"plain", &"good", &"warn", &"bad"]
const TONE_VARIATIONS: Dictionary[StringName, StringName] = {
	&"good": &"NumberGood",
	&"bad": &"NumberBad",
	&"warn": &"NumberWarn",
	&"muted": &"Hint",
	&"plain": &"Label",
}

@onready var _title: Label = $VBox/Title
@onready var _rows: VBoxContainer = $VBox/Rows
@onready var _way: Label = $VBox/Way

var _open: bool = false
var _anchor: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()
var _settle_queued: bool = false
## True while the card is pinned by a staged stop (pin) and not following an anchor (place).
var _pinned: bool = false
## The staged march's row of buttons, made on first use.
var _buttons: HBoxContainer = null
var _march: KitButton = null
var _clear: KitButton = null


func _ready() -> void:
	custom_minimum_size.x = CARD_W
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF  # the words are wrapped by _wrap, not by the label
	_way.autowrap_mode = TextServer.AUTOWRAP_OFF
	focus_mode = Control.FOCUS_NONE
	hide_card()


## Shows the words of `preview` (MovePreview.to): the title, one label a line in its tone, and the way out of a refusal.
func show_move(preview: Dictionary) -> void:
	_fill(preview)
	_open = true
	visible = true


## Places the card by `anchor` (the pointer, or the order cursor's hex centre), kept inside `bounds` (MapHover's clamp).
func place(anchor: Vector2, bounds: Rect2) -> void:
	_pinned = false
	_anchor = anchor
	_bounds = bounds
	_fit()
	_reposition()


## Pins the card by `anchor` (the last staged stop on the screen): its place does not hang on its height, so the buttons stay
## put while the words change (MapHover.pinned_card_position).
func pin(anchor: Vector2, bounds: Rect2) -> void:
	_pinned = true
	_anchor = anchor
	_bounds = bounds
	_fit()
	_reposition()


## Shows or hides the staged march's buttons.
func set_staged(on: bool) -> void:
	if on and _buttons == null:
		_make_buttons()
	if _buttons != null:
		_buttons.visible = on


func is_staged() -> bool:
	return _buttons != null and _buttons.visible


## The "March" and "Clear stops" buttons (null until a staged march was shown).
func march_button() -> KitButton:
	return _march


func clear_button() -> KitButton:
	return _clear


func _reposition() -> void:
	if _pinned:
		position = MapHover.pinned_card_position(_anchor, _bounds)
		return
	position = MapHover.clamp_card_position(_anchor, size, _bounds)


func _make_buttons() -> void:
	_buttons = HBoxContainer.new()
	_buttons.name = &"Buttons"
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_march = _button(MARCH_LABEL, &"map_command_key", march_pressed)
	_clear = _button(CLEAR_LABEL, &"app_back", clear_pressed)
	var box := _title.get_parent()
	box.add_child(_buttons)
	box.move_child(_buttons, 0)


func _button(text: String, hotkey: StringName, sends: Signal) -> KitButton:
	var button := KitButton.new()
	button.kind = KitButton.Kind.SMALL
	button.text = text
	button.hotkey_action = hotkey
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: sends.emit())
	_buttons.add_child(button)
	return button


func hide_card() -> void:
	set_staged(false)
	_open = false
	visible = false


func is_open() -> bool:
	return _open


func title_text() -> String:
	return str(_title.get_meta(RAW, ""))


func way_text() -> String:
	return str(_way.get_meta(RAW, "")) if _way.visible else ""


## The texts of the line labels, in order (the preview's lines).
func line_texts() -> Array[String]:
	var out: Array[String] = []
	for child: Node in _rows.get_children():
		out.append(str((child as Label).get_meta(RAW, "")))
	return out


func _fill(preview: Dictionary) -> void:
	_set_words(_title, str(preview.get("title", "")))
	_title.visible = not str(_title.get_meta(RAW, "")).is_empty()
	_clear_rows()
	for line: Array in distinct_lines(preview.get("lines", []) as Array):
		_rows.add_child(_line_label(str(line[0]), StringName(str(line[1]))))
	var way := str(preview.get("way_out", ""))
	_set_words(_way, way)
	_way.visible = not way.is_empty()
	_fit()


## The [text, tone] lines as the card shows them: in order, each text once, with the stronger of the tones it was given.
static func distinct_lines(lines: Array) -> Array[Array]:
	var out: Array[Array] = []
	var at: Dictionary[String, int] = {}
	for raw: Variant in lines:
		var line := raw as Array
		if line.size() < 2:
			continue
		var text := str(line[0])
		var tone := StringName(str(line[1]))
		if not at.has(text):
			at[text] = out.size()
			out.append([text, tone])
		elif TONE_RANK.find(tone) > TONE_RANK.find(out[at[text]][1] as StringName):
			out[at[text]][1] = tone
	return out


## Sizes the card to its words: each label is wrapped at WRAP_W by its font and set to that height, then the card takes the
## height of its children (no label wraps itself: a Label's own minimum height is measured one word wide, far too tall).
func _fit() -> void:
	var labels: Array[Label] = [_title, _way]
	for child: Node in _rows.get_children():
		labels.append(child as Label)
	for label: Label in labels:
		var wrapped := _wrap(label)
		label.text = wrapped[0]
		label.custom_minimum_size = Vector2(WRAP_W, wrapped[1])
	size = Vector2(CARD_W, 0.0)
	reset_size()
	if not _settle_queued and is_inside_tree():
		# The theme (fonts, sizes) of the labels is resolved on the next frame: measure again then and place the card again.
		_settle_queued = true
		_settle.call_deferred()


func _settle() -> void:
	_settle_queued = false
	if not _open:
		return
	var labels: Array[Label] = [_title, _way]
	for child: Node in _rows.get_children():
		labels.append(child as Label)
	for label: Label in labels:
		var wrapped := _wrap(label)
		label.text = wrapped[0]
		label.custom_minimum_size = Vector2(WRAP_W, wrapped[1])
	size = Vector2(CARD_W, 0.0)
	reset_size()
	_reposition()


## The label's words wrapped at WRAP_W with its own font: the text (lines joined by newlines) and its height.
func _wrap(label: Label) -> Array:
	var raw := str(label.get_meta(RAW, ""))
	if raw.is_empty():
		return ["", 0.0]
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var lines := PackedStringArray()
	for paragraph: String in raw.split("
"):
		var line := ""
		for word: String in paragraph.split(" ", false):
			var trial := word if line.is_empty() else line + " " + word
			if line.is_empty() or font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= WRAP_W:
				line = trial
			else:
				lines.append(line)
				line = word
		lines.append(line)
	return ["
".join(lines), ceilf(float(lines.size()) * font.get_height(font_size))]


func _set_words(label: Label, words: String) -> void:
	label.set_meta(RAW, words)
	label.text = words


func _line_label(text: String, tone: StringName) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_set_words(label, text)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.theme_type_variation = TONE_VARIATIONS.get(tone, &"Label")
	return label


func _clear_rows() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.free()  # not in the tree any more: freed now, so no line label outlives its card
