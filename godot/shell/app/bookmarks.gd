## Nine camera bookmarks for one game (spec 6.12): a centre and a zoom per slot, kept in the save's ui block.
class_name Bookmarks
extends RefCounted

const COUNT := 9

var _slots: Dictionary = {}  # int index (1 to COUNT) -> {"centre": Vector2, "zoom": float}


## Stores the view in slot index (1 to COUNT). Anything outside the range or a zoom that is not a positive finite
## number is ignored.
func set_at(index: int, centre: Vector2, zoom: float) -> void:
	if index < 1 or index > COUNT:
		return
	if not _is_finite_positive(zoom) or not _is_finite_vec(centre):
		return
	_slots[index] = {"centre": centre, "zoom": zoom}


## Returns {"centre": Vector2, "zoom": float} for a set slot, or {} for an empty or out-of-range one.
func get_at(index: int) -> Dictionary:
	if not _slots.has(index):
		return {}
	var slot: Dictionary = _slots[index]
	return {"centre": slot["centre"], "zoom": slot["zoom"]}


## JSON-safe form: slot number as a string key, centre as [x, y].
func to_dict() -> Dictionary:
	var out := {}
	for index: int in _slots.keys():
		var slot: Dictionary = _slots[index]
		var c: Vector2 = slot["centre"]
		out[str(index)] = {"centre": [c.x, c.y], "zoom": slot["zoom"]}
	return out


## Builds bookmarks from a saved dictionary. Bad entries are dropped: a key that is not a slot number from 1 to
## COUNT, a value that is not a dictionary, a centre that is not two finite numbers, a zoom that is not a positive
## finite number.
static func from_dict(d: Dictionary) -> Bookmarks:
	var result := Bookmarks.new()
	for key: Variant in d.keys():
		var text := str(key)
		if not text.is_valid_int():
			continue
		var index := text.to_int()
		if index < 1 or index > COUNT:
			continue
		var entry: Variant = d[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_dict: Dictionary = entry
		var centre: Variant = _vec_from_variant(entry_dict.get("centre"))
		var zoom: Variant = entry_dict.get("zoom")
		if centre == null or not _is_number(zoom) or not _is_finite_positive(float(zoom)):
			continue
		result._slots[index] = {"centre": centre, "zoom": float(zoom)}
	return result


static func _vec_from_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_VECTOR2:
		var v: Vector2 = value
		return v if _is_finite_vec(v) else null
	if typeof(value) != TYPE_ARRAY:
		return null
	var arr: Array = value
	if arr.size() != 2 or not _is_number(arr[0]) or not _is_number(arr[1]):
		return null
	var out := Vector2(float(arr[0]), float(arr[1]))
	return out if _is_finite_vec(out) else null


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_finite_positive(value: float) -> bool:
	return is_finite(value) and value > 0.0


static func _is_finite_vec(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)
