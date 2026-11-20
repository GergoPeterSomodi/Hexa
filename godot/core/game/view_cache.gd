## A small cache of derived views, keyed by an array that includes game.version (docs/architecture/m3-build-spec.md
## 5.4). Holds SIZE entries; the oldest goes first. Not saved, not in the digest.
class_name ViewCache
extends RefCounted

const SIZE := 64

var _values: Dictionary = {}
var _order: Array = []
var _pins: Dictionary = {}


func get_or_make(key: Array, make: Callable) -> Variant:
	if _values.has(key):
		return _values[key]
	var value: Variant = make.call()
	_values[key] = value
	_order.append(key)
	while _order.size() > SIZE:
		_values.erase(_order.pop_front())
	return value


## A value kept in its own named slot, outside the 64: `make` runs again only when `key` differs from the key the slot
## was made with. For a big index that must outlive the ordinary entries (the owner index of Territory). Not counted by
## `size()`; forgotten by `clear()`.
func pinned(slot: StringName, key: Variant, make: Callable) -> Variant:
	var held: Variant = _pins.get(slot)
	if held != null and (held as Array)[0] == key:
		return (held as Array)[1]
	var value: Variant = make.call()
	_pins[slot] = [key, value]
	return value


func size() -> int:
	return _values.size()


func clear() -> void:
	_values.clear()
	_order.clear()
	_pins.clear()
