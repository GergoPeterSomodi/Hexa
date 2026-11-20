## A MapState plus a what-if overlay (docs/architecture/m4-build-spec.md 5.2; ui-style-and-feedback-spec.md 7.2).
## Reads of a hex in the overlay give the overlay's main use and level; every other read falls through to the base.
## The base is never written, by the view or by with(). A view holds its base by reference, so it shows later changes
## to the base for hexes outside the overlay: build one per calculation.
class_name StateView
extends RefCounted

## The base state; read-only by contract (other fields such as owner and works are read from it directly).
var state: MapState = null
## Hex index -> Vector2i(main_use, level); never shared with another view.
var _over: Dictionary = {}


## A view with no overlay: it reads exactly what the state holds.
static func of(base: MapState) -> StateView:
	var v := StateView.new()
	v.state = base
	return v


## A new view with these changes laid over this one's overlay (a later change to a hex wins); this view and the base
## stay untouched. Indices outside the state's hexes are dropped.
func with(changes: Dictionary) -> StateView:
	var v := StateView.new()
	v.state = state
	v._over = _over.duplicate()
	var n := state.main_use.size()
	for key: Variant in changes:
		var i := int(key)
		if i < 0 or i >= n:
			continue
		var pair: Vector2i = changes[key]
		v._over[i] = pair
	return v


func main_use_at(i: int) -> int:
	if _over.has(i):
		return (_over[i] as Vector2i).x
	return state.main_use[i]


func level_at(i: int) -> int:
	if _over.has(i):
		return (_over[i] as Vector2i).y
	return state.level[i]


## The overlay's hex indices, ascending.
func changed() -> PackedInt32Array:
	var out := PackedInt32Array()
	for key: Variant in _over:
		out.append(int(key))
	out.sort()
	return out
