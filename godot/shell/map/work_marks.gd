## The work marks on the map (docs/architecture/m3-build-spec.md 6.9; z 87, between the pennants at 86 and the marks at 90):
## on each hex with a work the kit's hourglass and under it "done/total" seasons, the same count as the hex panel's
## "2 of 4 seasons". A halted work is drawn FAINT. Drawn at zoom 0.45 and above. Redrawn on the three work signals and
## season_ended; MapScene calls setup() when a game starts and set_zoom() as the camera moves.
class_name WorkMarks
extends Node2D

const LAYER_Z := 87
## Below this zoom nothing is drawn.
const MIN_ZOOM := 0.45
## Tuning of the look (map pixels): the icon's side, how far above the hex's middle its centre sits, the gap under it,
## the text size, the text's outline width.
const ICON_SIZE := 24.0
const ICON_OFFSET_Y := -30.0
const TEXT_GAP := 3.0
const FONT_SIZE := 15
const OUTLINE := 2

var _game: Game = null
var _zoom := 1.0
var _marks: Array[Dictionary] = []  # {hex, text, halted}
var _fallback_theme: Theme = null


func _init() -> void:
	z_index = LAYER_Z


func _enter_tree() -> void:
	Events.work_started.connect(_on_work)
	Events.work_finished.connect(_on_work)
	Events.work_cancelled.connect(_on_cancelled)
	Events.season_ended.connect(_on_season_ended)


func _exit_tree() -> void:
	Events.work_started.disconnect(_on_work)
	Events.work_finished.disconnect(_on_work)
	Events.work_cancelled.disconnect(_on_cancelled)
	Events.season_ended.disconnect(_on_season_ended)


## The game whose works are drawn (null: none).
func setup(game: Game) -> void:
	_game = game
	refresh()


## Reads the works again and redraws.
func refresh() -> void:
	_marks.clear()
	if _game != null and _game.state != null:
		for work: Work in _game.state.works:
			var done := clampi(work.seasons - work.seasons_left + 1, 1, maxi(work.seasons, 1))
			_marks.append({
				"hex": work.hex,
				"text": "%d/%d" % [done, work.seasons],
				"halted": Works.halted(_game, work, _game.turn),
			})
	queue_redraw()


## The camera's zoom; the marks are drawn from MIN_ZOOM up.
func set_zoom(value: float) -> void:
	var was := shown()
	_zoom = value
	if shown() != was:
		queue_redraw()


## Whether the marks are drawn at the present zoom.
func shown() -> bool:
	return _zoom >= MIN_ZOOM


func mark_count() -> int:
	return _marks.size()


## {hex, text, halted} of the mark on `hex`; {} when none.
func mark_at(hex: Vector2i) -> Dictionary:
	for mark: Dictionary in _marks:
		if mark["hex"] == hex:
			return mark
	return {}


func _draw() -> void:
	if not shown() or _marks.is_empty():
		return
	var icon := _kit_icon(&"hourglass")
	var theme := _theme()
	var font: Font = theme.get_font(&"font", &"Label") if theme != null else null
	if font == null:
		font = ThemeDB.fallback_font
	for mark: Dictionary in _marks:
		var halted := bool(mark["halted"])
		var tint := Tokens.FAINT if halted else Color.WHITE
		var icon_centre := MapTiles.cell_centre(mark["hex"] as Vector2i) + Vector2(0.0, ICON_OFFSET_Y)
		if icon != null:
			draw_texture_rect(icon, Rect2(icon_centre - Vector2.ONE * ICON_SIZE / 2.0, Vector2.ONE * ICON_SIZE), false, tint)
		var text := str(mark["text"])
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var base := Vector2(icon_centre.x - width / 2.0, icon_centre.y + ICON_SIZE / 2.0 + TEXT_GAP + FONT_SIZE * 0.8)
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE, Tokens.INK)
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Tokens.FAINT if halted else Tokens.TEXT)


func _on_work(_tag: StringName, _hex: Vector2i, _work: Dictionary) -> void:
	refresh()


func _on_cancelled(_tag: StringName, _hex: Vector2i, _work: Dictionary, _why: StringName) -> void:
	refresh()


func _on_season_ended(_turn: int) -> void:
	refresh()


func _theme() -> Theme:
	if is_inside_tree():
		var win := get_window()
		if win != null and win.theme != null:
			return win.theme
	var proj := ThemeDB.get_project_theme()
	if proj != null:
		return proj
	if _fallback_theme == null and ResourceLoader.exists(KitTheme.THEME_PATH):
		_fallback_theme = load(KitTheme.THEME_PATH) as Theme
	return _fallback_theme


func _kit_icon(icon_name: StringName) -> Texture2D:
	var theme := _theme()
	if theme != null and theme.has_icon(icon_name, &"Kit"):
		return theme.get_icon(icon_name, &"Kit")
	return null
