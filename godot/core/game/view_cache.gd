## A small cache of derived views, keyed by an array that includes game.version (docs/architecture/m3-build-spec.md
## 5.4). Holds SIZE entries; the oldest goes first. Not saved, not in the digest.
class_name ViewCache
extends RefCounted

const SIZE := 64

var _values: Dictionary = {}
var _order: Array = []


func get_or_make(key: Array, make: Callable) -> Variant:
	if _values.has(key):
		return _values[key]
	var value: Variant = make.call()
	_values[key] = value
	_order.append(key)
	while _order.size() > SIZE:
		_values.erase(_order.pop_front())
	return value


func size() -> int:
	return _values.size()


func clear() -> void:
	_values.clear()
	_order.clear()
