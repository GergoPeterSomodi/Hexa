## The people-free part of district_output for every land hex (docs/architecture/m4-build-spec.md 5.4; m5-build-spec.md
## 5.3), kept as ints (FIELDS a hex) and built on first use. The live part (people, staffing, a0) is worked out on each
## read from the people of the view asked, never kept. Game holds one (`districts`) and forgets a hex and its ring when it changes
## (`touch`, from Game.emit's hex_changed); a new game, a load and every replaced MapState call clear().
class_name DistrictCache
extends RefCounted

@warning_ignore_start("integer_division")

## The people-free ints of district_base a hex, in Economy.BASE_FIELDS order.
const FIELDS := 14
const _BOOL_FIELD := "weather_bound"

var _ints: PackedInt32Array = PackedInt32Array()
## One byte a hex: 1 when its ints are fresh.
var _fresh: PackedByteArray = PackedByteArray()
var _held: int = 0
## The hexes whose people can change (the running set of the M5 spec's 10 and 5.0 R2): settlements and the hexes whose
## people differ from their room, as hex index -> its room. Built by one walk over the land on first use, then kept by
## People.move (note_people) and by touch (a hex with another use or level has another room). A test that edits
## MapState.people or a use directly calls reset_open (a new game, a load and clear() do).
var _open: Dictionary = {}
var _open_ready: bool = false


## Economy.district_base of hex index `i`: the cached ints (computed on first use from the game's own state) plus the live
## people, staffing and a0 from `view`'s people (the game's own state when no view is given).
func base_of(game: Game, i: int, view: StateView = null) -> Dictionary:
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
		if view == null:
			return base
	var out: Dictionary = {}
	for k: int in FIELDS:
		var key := Economy.BASE_FIELDS[k]
		var value := _ints[i * FIELDS + k]
		out[key] = value != 0 if key == _BOOL_FIELD else value
	Economy.live_into(game, view if view != null else StateView.of(game.state), i, out)
	return out


## Economy.staffed on the game's own state, worked out on the cache's own ints (no view and no dictionary): x the staffing
## of hex index `i`, y the a0 of `raw` and `lift`. The hot path of SeasonProfile.live; the tests hold it equal to
## Economy.staffed (the one live step) on every hex.
func staffed_of(game: Game, i: int, raw: int, lift: int) -> Vector2i:
	var state := game.state
	var people_by_hex := state.people
	var owner_bytes := state.owner
	var owner_id := int(owner_bytes[i])
	var people := people_by_hex[i]
	var jobs := _jobs_of(game, i)
	if owner_id != 0:
		for j: int in Economy.ring_of(game.map, i):
			if j >= 0 and owner_bytes[j] == owner_id:
				people += people_by_hex[j]
				jobs += _jobs_of(game, j)
	var permille := 1000
	if jobs > 0:
		permille = mini(1000, people * game.defs.hands_permille / 1000 * 1000 / jobs)
	return Vector2i(permille, raw * permille / 1000 * (1000 + lift) / 1000)


## The jobs of hex index `i`'s own district, from the ints (0 for anything that is not a goods district).
func _jobs_of(game: Game, i: int) -> int:
	if _fresh.size() != game.map.hex_count() or _fresh[i] == 0:
		base_of(game, i)
	return _ints[i * FIELDS + Economy.F_JOBS]


## The cache's ints with hex index `i` fresh: field k of the hex is at [i * FIELDS + k] (Economy.F_*). The hot path of
## EconomySeason.made_of reads this and builds no dictionary.
func ints_of(game: Game, i: int) -> PackedInt32Array:
	if _fresh.size() != game.map.hex_count() or _fresh[i] == 0:
		base_of(game, i)
	return _ints


## The hexes that can change, hex index -> room, built on first use. Read-only for the caller.
func open_hexes(game: Game) -> Dictionary:
	if not _open_ready:
		_open.clear()
		var found: Dictionary = {}
		for i: int in game.map.hex_count():
			if game.map.land[i] == 1:
				var room := room_of(game, i)
				if game.state.main_use[i] == Economy.SETTLEMENTS or game.state.people[i] != room:
					found[i] = room
		_open = found
		_open_ready = true
	return _open


## People.move changed the people of hex index `i`: it may have become full or stopped being so. A hex of the set has its
## room there already.
func note_people(game: Game, i: int) -> void:
	if not _open_ready:
		return
	var room: int = _open.get(i, -1)
	if room < 0:
		_note(game, i)
	elif game.state.main_use[i] == Economy.SETTLEMENTS or game.state.people[i] != room:
		return
	else:
		_open.erase(i)


## Forgets the running set: the next open_hexes walks the land again.
func reset_open() -> void:
	_open.clear()
	_open_ready = false


## The room of hex index `i` (People.room_at on the game's own state), from the ints.
func room_of(game: Game, i: int) -> int:
	if _fresh.size() != game.map.hex_count() or _fresh[i] == 0:
		base_of(game, i)
	return _ints[i * FIELDS + Economy.F_ROOM]


## Re-evaluates hex index `i` (its use or level changed, or it left the set before): in the set with its room, or out.
func _note(game: Game, i: int) -> void:
	if i < 0 or i >= game.map.hex_count() or game.map.land[i] == 0:
		return
	var room := room_of(game, i)
	if game.state.main_use[i] == Economy.SETTLEMENTS or game.state.people[i] != room:
		_open[i] = room
	else:
		_open.erase(i)


## Forgets the hex and its six neighbours (a change on a hex changes its district and its ring's, nowhere else).
func touch(game: Game, hex: Vector2i) -> void:
	var map := game.map
	_forget(map.index_of(hex))
	if _open_ready:
		_note(game, map.index_of(hex))
	for d: int in 6:
		_forget(map.index_of(map.neighbour(hex, d)))


func clear() -> void:
	_ints = PackedInt32Array()
	_fresh = PackedByteArray()
	_held = 0
	reset_open()


## Hexes held.
func size() -> int:
	return _held


func _forget(i: int) -> void:
	if i >= 0 and i < _fresh.size() and _fresh[i] == 1:
		_fresh[i] = 0
		_held -= 1
