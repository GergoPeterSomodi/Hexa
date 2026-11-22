## One lane or reserve cell of the battle dock (docs/architecture/m7-build-spec.md 6.5; M7 B22): a company's figure, name, men
## bar and morale bar, and its marks (routed, shaken, fires). An empty, closed or broken lane is drawn as an empty cell with
## its words. Built from one BattleView lane or reserve entry (`set_entry`); reads no game. The hover card of mockup 18 is
## B23's; until then the cell carries its words as a tooltip.
class_name RegimentTile
extends PanelContainer

const FIGURE_PX: float = 24.0
const MIN_W: float = 92.0
const MORALE_MAX: float = 1000.0
const MARK_PX: float = 16.0
const DASH: float = 5.0
const EMPTY_WORDS := {"empty": "Empty lane", "closed": "Closed lane", "broken": "Broken lane"}

var _figure: TextureRect = null
var _name: Label = null
var _men: Label = null
var _men_bar: ProgressBar = null
var _morale_bar: ProgressBar = null
var _marks: HFlowContainer = null
var _empty_label: Label = null
var _content: VBoxContainer = null
var _kind: String = ""
var _broken: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(MIN_W, 0.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", 2)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure = TextureRect.new()
	_figure.custom_minimum_size = Vector2(FIGURE_PX, FIGURE_PX)
	_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_figure)
	_name = _label(&"TableRow")
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name)
	_content.add_child(row)
	_men = _label(&"Hint")
	_content.add_child(_men)
	_men_bar = _bar()
	_content.add_child(_men_bar)
	_morale_bar = _bar()
	_content.add_child(_morale_bar)
	_marks = HFlowContainer.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_marks)
	_empty_label = _label(&"Hint")
	_empty_label.visible = false
	_content.add_child(_empty_label)


## Fills the cell from one view entry: {empty, closed, broken, name, figure, men, full, morale (permille), routed, shaken,
## fires}. A company shows its figure, men and morale; an empty lane shows its words and nothing else.
func set_entry(entry: Dictionary) -> void:
	var empty := bool(entry.get("empty", false))
	_figure.visible = not empty
	_name.visible = not empty
	_men.visible = not empty
	_men_bar.visible = not empty
	_morale_bar.visible = not empty
	_marks.visible = not empty
	_empty_label.visible = empty
	_broken = bool(entry.get("broken", false))
	_kind = "empty"
	if bool(entry.get("closed", false)):
		_kind = "closed"
	elif _broken:
		_kind = "broken"
	if empty:
		_empty_label.text = EMPTY_WORDS.get(_kind, "Empty lane")
		tooltip_text = _empty_label.text
		accessibility_name = _empty_label.text
		queue_redraw()
		return
	var men := int(entry.get("men", 0))
	var full := int(entry.get("full", 0))
	var morale := int(entry.get("morale", 0))
	_name.text = str(entry.get("name", ""))
	_figure.texture = _figure_of(StringName(str(entry.get("figure", ""))))
	_men.text = Words.men(men)
	_men_bar.max_value = float(maxi(maxi(full, men), 1))
	_men_bar.value = float(men)
	_morale_bar.max_value = MORALE_MAX
	_morale_bar.value = float(clampi(morale, 0, 1000))
	_fill_marks(entry)
	tooltip_text = "%s, %s, morale %d %%" % [_name.text, _men.text, roundi(morale / 10.0)]
	accessibility_name = tooltip_text
	queue_redraw()


## The empty kind last set ("empty", "closed", "broken") or "" for a company.
func kind() -> String:
	return "" if _figure.visible else _kind


## The mark texts shown under a company, in order (for the test and the dock's words).
func mark_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for child: Node in _marks.get_children():
		for part: Node in child.get_children():
			var lbl := part as Label
			if lbl != null:
				out.append(lbl.text)
	return out


func _fill_marks(entry: Dictionary) -> void:
	for child: Node in _marks.get_children():
		_marks.remove_child(child)
		child.queue_free()
	if bool(entry.get("routed", false)):
		_add_mark(&"routed", "Routed", Tokens.BAD)
	if bool(entry.get("shaken", false)):
		_add_mark(&"shaken", "Shaken", Tokens.WARN)
	if bool(entry.get("fires", false)):
		_add_mark(&"fires", "Fires", Tokens.GOLD)


func _add_mark(icon: StringName, text: String, colour: Color) -> void:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(MARK_PX, MARK_PX)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.texture = _icon_of(icon)
	box.add_child(tex)
	var lbl := _label(&"Hint")
	lbl.text = text
	lbl.add_theme_color_override(&"font_color", colour)
	box.add_child(lbl)
	_marks.add_child(box)


func _icon_of(name: StringName) -> Texture2D:
	return get_theme_icon(name, &"Kit") if has_theme_icon(name, &"Kit") else null


func _figure_of(name: StringName) -> Texture2D:
	if name == &"":
		return null
	return get_theme_icon(name, &"Kit") if has_theme_icon(name, &"Kit") else null


func _label(variation: StringName) -> Label:
	var lbl := PanelKit.label("", variation)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 5.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _draw() -> void:
	if not _figure.visible and _kind != "":
		var rect := Rect2(Vector2.ZERO, size).grow(-1.0)
		var colour := Tokens.BAD if _broken else Tokens.MUTED
		if _kind == "closed":
			draw_rect(rect, colour.lerp(Color.TRANSPARENT, 0.75), true)
		else:
			_dashed_rect(rect, colour)


func _dashed_rect(rect: Rect2, colour: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i: int in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		draw_dashed_line(a, b, colour, 1.0, DASH)
