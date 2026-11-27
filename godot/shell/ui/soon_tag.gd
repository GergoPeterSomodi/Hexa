## The small dashed "soon" tag of a placeholder in the tile window (the owner's 540 banner design of 2026-11-26): the word in the
## window's muted secondary text inside a dashed rim, with the placeholder's tooltip. A placeholder box or row shows example values
## of a mechanic the game does not have yet; the tag says so where it stands, and its hover says it in words.
class_name SoonTag
extends PanelContainer

const WORD := "soon"
## The tooltip of every placeholder (its box, its rows, its tag and its greyed buttons).
const EXAMPLE_TIP := "Example only: not in the game yet"
const DASH := 3.0
const PAD_X := 5.0


func _init() -> void:
	name = &"Soon"
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = EXAMPLE_TIP
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_END
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = PAD_X
	pad.content_margin_right = PAD_X
	add_theme_stylebox_override(&"panel", pad)
	var word := PanelKit.label(WORD, &"TileHint")
	word.name = &"Word"
	add_child(word)


func _draw() -> void:
	var r := Rect2(Vector2(0.5, 0.5), size - Vector2.ONE)
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i: int in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], Tokens.TILE_DIM, 1.0, DASH)
