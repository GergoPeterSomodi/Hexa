## The developer console at the foot of the F3 panel (docs/architecture/m3-build-spec.md section 6.13): a LineEdit and the
## last 8 output lines. Enter runs the line, Up and Down walk a history of 20, Esc leaves the field.
class_name DevConsole
extends VBoxContainer

const OUTPUT_LINES := 8
const HISTORY_MAX := 20

@onready var _output: Label = $Output
@onready var _line: LineEdit = $Line

var _ctx: ShellContext = null
var _lines: PackedStringArray = PackedStringArray()
var _history: PackedStringArray = PackedStringArray()
var _cursor: int = 0
var _draft: String = ""


func _ready() -> void:
	_line.focus_mode = Control.FOCUS_ALL
	_line.text_submitted.connect(submit)
	_line.gui_input.connect(_on_line_input)
	_render()


func setup(ctx: ShellContext) -> void:
	_ctx = ctx


## F2: puts the cursor in the field.
func focus_line() -> void:
	if is_node_ready():
		_line.grab_focus()


func release_focus_line() -> void:
	if is_node_ready():
		_line.release_focus()


func has_line_focus() -> bool:
	return is_node_ready() and _line.has_focus()


func line_edit() -> LineEdit:
	return _line


func output_lines() -> PackedStringArray:
	return _lines


func history() -> PackedStringArray:
	return _history


## Runs a line (as Enter does): echoes it, keeps it in the history, prints the answer.
func submit(text: String) -> void:
	var line := text.strip_edges()
	if is_node_ready():
		_line.clear()
	_cursor = _history.size()
	_draft = ""
	if line.is_empty():
		return
	if _history.is_empty() or _history[_history.size() - 1] != line:
		_history.append(line)
		while _history.size() > HISTORY_MAX:
			_history.remove_at(0)
	_cursor = _history.size()
	_print("> " + line)
	var ctx := _ctx if _ctx != null else ShellContext.new()
	for answer: String in DevCommands.run(line, ctx).split("\n"):
		_print(answer)


## Up (-1) or Down (+1) through the history; past the newest line the unsent draft returns.
func walk(step: int) -> void:
	if _history.is_empty():
		return
	if _cursor >= _history.size() and step < 0:
		_draft = _line.text
	_cursor = clampi(_cursor + step, 0, _history.size())
	_line.text = _draft if _cursor >= _history.size() else _history[_cursor]
	_line.caret_column = _line.text.length()


func _print(words: String) -> void:
	_lines.append(words)
	while _lines.size() > OUTPUT_LINES:
		_lines.remove_at(0)
	_render()


func _render() -> void:
	if is_node_ready():
		_output.text = "\n".join(_lines)


func _on_line_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	match key.keycode:
		KEY_UP:
			walk(-1)
		KEY_DOWN:
			walk(1)
		KEY_ESCAPE:
			_line.release_focus()
		_:
			return
	_line.accept_event()
