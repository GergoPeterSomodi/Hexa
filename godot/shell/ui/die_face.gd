## The die face of the battle dock (docs/architecture/m7-build-spec.md 6.5; M7 B22): the bone die (`die_face` from the Kit)
## with its pips drawn in VELLUM_INK, and the day's multiplier under it ("×1.1", in its tone). A pure drawing: it reads no
## game; the dock sets the value from BattleView's roll and mult_text.
class_name DieFace
extends Control

const FACE_PX: float = 28.0
const LABEL_GAP: float = 2.0
const PIP_RADIUS: float = 2.6
const LOW: float = 0.27
const MID: float = 0.5
const HIGH: float = 0.73
## Pip positions per face value, as fractions of the face (x, y).
const PIPS: Array[Array] = [
	[],
	[[MID, MID]],
	[[LOW, LOW], [HIGH, HIGH]],
	[[LOW, LOW], [MID, MID], [HIGH, HIGH]],
	[[LOW, LOW], [HIGH, LOW], [LOW, HIGH], [HIGH, HIGH]],
	[[LOW, LOW], [HIGH, LOW], [MID, MID], [LOW, HIGH], [HIGH, HIGH]],
	[[LOW, LOW], [HIGH, LOW], [LOW, MID], [HIGH, MID], [LOW, HIGH], [HIGH, HIGH]],
]

var value: int = 1
var mult_text: String = ""
var tone: Color = Tokens.TEXT


func _init() -> void:
	custom_minimum_size = Vector2(FACE_PX, FACE_PX)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Sets the face (1 to 6; anything else is clamped), the multiplier under it and its colour, and redraws.
func set_face(face: int, multiplier: String, colour: Color = Tokens.TEXT) -> void:
	value = clampi(face, 1, 6)
	mult_text = multiplier
	tone = colour
	_sync_size()
	queue_redraw()


## The pips shown: the value's count (0 when the die is unset).
func pip_count() -> int:
	return PIPS[value].size()


func _sync_size() -> void:
	var width := FACE_PX
	var height := FACE_PX
	if not mult_text.is_empty():
		var font := get_theme_default_font()
		var size := get_theme_default_font_size()
		width = maxf(width, font.get_string_size(mult_text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x)
		height += LABEL_GAP + font.get_height(size)
	custom_minimum_size = Vector2(width, height)


func _draw() -> void:
	var face_x := (size.x - FACE_PX) * 0.5
	var tex: Texture2D = get_theme_icon(&"die_face", &"Kit") if has_theme_icon(&"die_face", &"Kit") else null
	if tex != null:
		draw_texture_rect(tex, Rect2(face_x, 0.0, FACE_PX, FACE_PX), false)
	else:
		draw_rect(Rect2(face_x, 0.0, FACE_PX, FACE_PX), Tokens.TEXT, false, 1.0)
	for pip: Array in PIPS[value]:
		var at := Vector2(face_x + float(pip[0]) * FACE_PX, float(pip[1]) * FACE_PX)
		draw_circle(at, PIP_RADIUS, Tokens.VELLUM_INK)
	if not mult_text.is_empty():
		var font := get_theme_default_font()
		var font_size := get_theme_default_font_size()
		var y := FACE_PX + LABEL_GAP + font.get_ascent(font_size)
		draw_string(font, Vector2(0.0, y), mult_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, tone)
