## A seat's trace of its turn (docs/architecture/m8-build-spec.md 5.5): one line a step and an act, for the console's `ai TAG` and
## F3. Kept for the turn only; not state, not saved. Bounded: a seat's lines stop at MAX_LINES.
class_name AiTrace
extends RefCounted

const MAX_LINES := 400

var _lines: Dictionary = {}


func line(tag: StringName, text: String) -> void:
	var list: PackedStringArray = _lines.get(tag, PackedStringArray())
	if list.size() < MAX_LINES:
		list.append(text)
		_lines[tag] = list


func of(tag: StringName) -> PackedStringArray:
	return (_lines.get(tag, PackedStringArray()) as PackedStringArray).duplicate()


func clear() -> void:
	_lines.clear()
