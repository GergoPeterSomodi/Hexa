## The war cache (docs/architecture/m7-build-spec.md 5.3): the derived lists of the occupation door, kept on game.war_cache,
## never saved and never in the digest. The fortresses and every hex's castle area, and the hexes each country controls;
## built on first ask by Occupation (through .call, so the two files need not parse each other). Game.emit drops them:
## owners_changed (areas and control), controllers_changed (control), and a hex_changed of a hex whose fortress level changed
## (areas). Occupation's own writes drop the control lists at once and keep the changed hexes for one controllers_changed.
class_name WarCache
extends RefCounted

var _areas_built := false
var _fortresses := PackedInt32Array()
var _levels := PackedByteArray()
var _area := PackedInt32Array()
var _steps := PackedInt32Array()
var _control_built := false
var _control: Dictionary = {}
## Hex index -> the controller id it had before the first change of this phase or action. Flushed by
## Occupation.flush into one controllers_changed; empty between phases.
var _pending: Dictionary = {}


## The fortress hex indices, ascending.
func fortresses(game: Game) -> PackedInt32Array:
	_build_areas(game)
	return _fortresses


## Per hex: the index of its fortress (its own index for a fortress), -1 for no area.
func area_index(game: Game) -> PackedInt32Array:
	_build_areas(game)
	return _area


## Per hex: the steps from its fortress (0 for a fortress).
func area_steps(game: Game) -> PackedInt32Array:
	_build_areas(game)
	return _steps


## The hex indices a country controls, ascending.
func controlled(game: Game, id: int) -> PackedInt32Array:
	if not _control_built:
		_control = Occupation.controllers_map.call(game)
		_control_built = true
	return _control.get(id, PackedInt32Array()) as PackedInt32Array


## Drops the castle areas and the fortress list (owners changed, a fortress's level changed).
func forget_areas() -> void:
	_areas_built = false
	_fortresses = PackedInt32Array()
	_levels = PackedByteArray()
	_area = PackedInt32Array()
	_steps = PackedInt32Array()


## Drops the control lists (a controller or an owner changed).
func forget_control() -> void:
	_control_built = false
	_control = {}


## Drops everything, the pending changes too (a new game, a setup).
func clear() -> void:
	forget_areas()
	forget_control()
	_pending = {}


## Game.emit's hook for a hex_changed: a change of the hex's fortress level drops the areas.
func on_hex_changed(game: Game, hex: Vector2i) -> void:
	if not _areas_built or game.map == null:
		return
	var i := game.map.index_of(hex)
	if i < 0 or i >= _levels.size():
		return
	var now: int = Occupation.fortress_level.call(game, hex)
	if now != int(_levels[i]):
		forget_areas()


## Records the controller a hex had before this batch's first change (kept only once per hex).
func note_pending(i: int, old_id: int) -> void:
	if not _pending.has(i):
		_pending[i] = old_id


## Returns the pending changes and empties them (Occupation.flush).
func take_pending() -> Dictionary:
	var out := _pending
	_pending = {}
	return out


func _build_areas(game: Game) -> void:
	if _areas_built:
		return
	var built: Dictionary = Occupation.build_areas.call(game)
	_fortresses = built["fortresses"]
	_levels = built["levels"]
	_area = built["area"]
	_steps = built["steps"]
	_areas_built = true
