## The season-free part of district_output for every land hex (docs/architecture/m4-build-spec.md 5.4), kept as ints
## (FIELDS a hex) and built on first use. Game holds one (`districts`) and forgets a hex and its ring when it changes
## (`touch`, from Game.emit's hex_changed); a new game, a load and every replaced MapState call clear().
class_name DistrictCache
extends RefCounted

## The ints of district_base a hex, in Economy.BASE_FIELDS order.
const FIELDS := 15
const _BOOL_FIELD := "weather_bound"

var _ints: PackedInt32Array = PackedInt32Array()
## One byte a hex: 1 when its ints are fresh.
var _fresh: PackedByteArray = PackedByteArray()
var _held: int = 0


## Economy.district_base of hex index `i` on the game's own state, computed on first use.
func base_of(game: Game, i: int) -> Dictionary:
	var n := game.map.hex_count()
	if i < 0 or i >= n:
		return Economy.empty_base()
	if _fresh.size() != n:
		clear()
		_ints.resize(n * FIELDS)
		_fresh.resize(n)
	if _fresh[i] == 0:
		var base := Economy.district_base(game, StateView.of(game.state), game.map.hex_of(i))
		for k: int in FIELDS:
			var key := Economy.BASE_FIELDS[k]
			_ints[i * FIELDS + k] = int(bool(base[key])) if key == _BOOL_FIELD else int(base[key])
		_fresh[i] = 1
		_held += 1
		return base
	var out: Dictionary = {}
	for k: int in FIELDS:
		var key := Economy.BASE_FIELDS[k]
		var value := _ints[i * FIELDS + k]
		out[key] = value != 0 if key == _BOOL_FIELD else value
	return out


## The cache's ints with hex index `i` fresh: field k of the hex is at [i * FIELDS + k] (Economy.F_*). The hot path of
## EconomySeason.made_of reads this and builds no dictionary.
func ints_of(game: Game, i: int) -> PackedInt32Array:
	if _fresh.size() != game.map.hex_count() or _fresh[i] == 0:
		base_of(game, i)
	return _ints


## Forgets the hex and its six neighbours (a change on a hex changes its district and its ring's, nowhere else).
func touch(game: Game, hex: Vector2i) -> void:
	var map := game.map
	_forget(map.index_of(hex))
	for d: int in 6:
		_forget(map.index_of(map.neighbour(hex, d)))


func clear() -> void:
	_ints = PackedInt32Array()
	_fresh = PackedByteArray()
	_held = 0


## Hexes held.
func size() -> int:
	return _held


func _forget(i: int) -> void:
	if i >= 0 and i < _fresh.size() and _fresh[i] == 1:
		_fresh[i] = 0
		_held -= 1
