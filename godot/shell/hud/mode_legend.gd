## The Yields legend (docs/architecture/m4-5-build-spec.md 6.7): a small card top left of the map area, one row a band (an
## ink swatch and its words) from MapModes.legend(mode). Hidden for every other mode, while a screen covers the world
## (set_covered, as Notifications) and in photo mode (set_hidden_by_hud: the H hide-HUD state, called by the App). It
## ignores the mouse and takes no focus. Reads MapModes and Tokens only; sends no intents.
class_name ModeLegend
extends PanelContainer

const TITLE := "Yields: worth a year"
const WIDTH := 220.0
## A compact card: rows 20 px tall in a 13 px font, so it ends above the action log's bar at 1280 x 720.
const ROW_H := 20.0
const ROW_FONT := 13
const ROW_GAP := 0

var _mode: int = -1
var _rows: Array[Dictionary] = []  # {colour, text, stripes}, from MapModes.legend
var _covered: bool = false
var _hidden_by_hud: bool = false
var _retired: Array[Node] = []

@onready var _column: VBoxContainer = $Column


## One band's ink swatch: InkMarks.fill_rect in the band's colour, the hatch (madder stripes) for a loss.
class Swatch extends Control:
	const SIZE := Vector2(16.0, 12.0)

	var colour: Color = Color.WHITE
	var stripes: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = SIZE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		resized.connect(queue_redraw)

	func _draw() -> void:
		var cue := InkMarks.FILLS.find(&"hatch") if stripes else InkMarks.FILLS.find(&"solid")
		InkMarks.fill_rect(self, Rect2(Vector2.ZERO, size), colour, cue, Tokens.INK)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size.x = WIDTH
	_rebuild()


## Entering the tree again (a reparent) does not run _ready: the rows are rebuilt here, from the same state, so a moved
## card keeps its rows and a card moved twice does not stack them.
func _enter_tree() -> void:
	_rebuild()


## Leaving the tree keeps the rows (they are children of this card); only the detached nodes are freed here.
func _exit_tree() -> void:
	PanelKit.free_retired(_retired)


## Shows the legend of `mode` (a MapModes.Mode): one row a band from MapModes.legend(mode). A mode with no legend (every
## mode but Yields) hides it.
func show_mode(mode: int) -> void:
	_mode = mode
	_rows = MapModes.legend(mode)
	_rebuild()


## Hides the legend until the next show_mode.
func hide_legend() -> void:
	show_mode(-1)


## The rows shown (copies): {colour, text, stripes}, top band first; [] when hidden.
func rows() -> Array[Dictionary]:
	return _rows.duplicate()


## The mode the legend was last given (-1 for none).
func mode() -> int:
	return _mode


## A screen that hides the world is up (true) or closed (false). The legend waits, hidden, and shows again when it closes.
func set_covered(covered: bool) -> void:
	_covered = covered
	_sync_visible()


func is_covered() -> bool:
	return _covered


## Photo mode (the H hide-HUD state): true hides the legend, false shows it again.
func set_hidden_by_hud(hidden: bool) -> void:
	_hidden_by_hud = hidden
	_sync_visible()


func is_hidden_by_hud() -> bool:
	return _hidden_by_hud


func _rebuild() -> void:
	if not is_node_ready():
		return
	PanelKit.clear_children(_column, _retired)
	_column.add_theme_constant_override("separation", ROW_GAP)
	if _rows.is_empty():
		accessibility_description = ""
	else:
		_column.add_child(PanelKit.label(TITLE, &"SectionHead"))
		for row: Dictionary in _rows:
			_column.add_child(_row_node(row))
		accessibility_description = _describe()
	_sync_visible()


func _row_node(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", Tokens.S2)
	line.custom_minimum_size.y = ROW_H
	var swatch := Swatch.new()
	swatch.colour = row["colour"] as Color
	swatch.stripes = bool(row["stripes"])
	line.add_child(swatch)
	var words := PanelKit.label(str(row["text"]), &"TableRow")
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.add_theme_font_size_override(&"font_size", ROW_FONT)
	line.add_child(words)
	return line


## The title and every row's words, for a screen reader.
func _describe() -> String:
	var words := PackedStringArray()
	for row: Dictionary in _rows:
		words.append(str(row["text"]))
	return "%s: %s" % [TITLE, ", ".join(words)]


func _sync_visible() -> void:
	visible = not _rows.is_empty() and not _covered and not _hidden_by_hud
