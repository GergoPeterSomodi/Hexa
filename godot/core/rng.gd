## The only source of luck in core/ (B3). Wraps one seeded RandomNumberGenerator.
## Godot's global randi, randf, shuffle and pick_random are banned in core/ (tools/lint_godot.py).
class_name Rng
extends RefCounted

var _rng := RandomNumberGenerator.new()


func seed_with(value: int) -> void:
	_rng.seed = value


func randi_range(low: int, high: int) -> int:
	return _rng.randi_range(low, high)


func randf() -> float:
	return _rng.randf()


## The internal state, so that a save can hold it (B6).
func get_state() -> int:
	return _rng.state


func set_state(value: int) -> void:
	_rng.state = value
