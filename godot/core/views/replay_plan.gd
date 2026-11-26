## The movement replay's timeline (docs/architecture/m6-build-spec.md 6.4 and 5.6; task L15): the walks of one season (the
## `unit_moved` records: tag, army, path, seen, ticks) laid on one clock, so the armies walk together tick by tick. Pure: it
## reads the records it is given and the time it is advanced by, never the game. A step the viewer did not see takes no
## time (it is instant); a shown step takes the speed's seconds, shortened so the whole replay stays within MAX_SECONDS and
## never below MIN_STEP a step. A focus (set_focus, D37): a seen step with neither hex in view is instant too.
## Battle marks (M7 5.6, B20): record_battle gives a battle at a hex and the movement tick it began at; its mark shows from
## that tick (marks()). A retreat walk (a walk that starts on a battle hex after the battle's tick) is laid after the last
## movement tick, so the beaten army walks off once the armies have stopped.
## The chain (R50, moves-build-spec.md): the walks of at-once orders (`now`) all count ticks from 1, so chain() lays them one
## after another, then the phase's walks after the last; a chained walk is `fixed` and setup() leaves its ticks as they are.
class_name ReplayPlan
extends RefCounted

## Seconds a shown step takes at each speed (`game/movement`). `instant` is not a plan: MoveReplay refuses it.
const STEP_SECONDS := {&"normal": 0.2, &"slow": 0.5}
## The longest a replay runs, in seconds, however many ticks it has.
const MAX_SECONDS := 6.0
## The shortest a shown step gets, in seconds.
const MIN_STEP := 0.04

## One walk per record: {army, tag, path, seen, ticks, fixed, starts, ends}; starts and ends are PackedFloat64Array, one a step.
var _walks: Array[Dictionary] = []
## One battle per record_battle: {hex, tick, shown, start} (start: the clock second its tick begins, set by setup).
var _battles: Array[Dictionary] = []
var _duration := 0.0
var _time := 0.0
## The hexes in view at the replay's start (set_focus); an empty rect times every seen step (M6).
var _focus := Rect2i()


## A battle at `hex` that began at movement `tick` (the step that ends on the hex). `shown` is what the viewer may see of it.
## Call before setup: setup lays the retreats from these hexes after the movement.
func record_battle(hex: Vector2i, tick: int, shown: bool = true) -> void:
	if tick < 1:
		return
	_battles.append({"hex": hex, "tick": tick, "shown": shown, "start": 0.0})


## The hexes in view (D37): a seen step is timed only when one of its hexes lies in `focus`, else it is instant. An empty
## rect (the default) times every seen step. Call before setup.
func set_focus(focus: Rect2i) -> void:
	_focus = focus


## The records with the at-once walks laid one after another (R50): pure, in a new list. A record with `now` set is an at-once
## walk; its ticks count from 1, so each walk's ticks move after the last tick of the walks before it, in arrival order. A
## retreat of the same fight (its ticks start after 1: the battle's tick and one) keeps its walk's offset, so it comes right
## after its battle. The records without `now` (the phase's) then move after the last tick of all of those, keeping their own
## spacing and order. Each at-once record gets `fixed` true. With no `now` record the ticks are unchanged.
static func chain(records: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var offset := 0
	var end := 0
	for r: Dictionary in records:
		if not bool(r.get("now", false)):
			continue
		var ticks := r.get("ticks", PackedInt32Array()) as PackedInt32Array
		if ticks.is_empty():
			continue
		if ticks[0] <= 1:
			offset = end
		var moved := r.duplicate()
		moved["ticks"] = _shifted(ticks, offset)
		moved["fixed"] = true
		end = maxi(end, _last_tick(moved["ticks"] as PackedInt32Array))
		out.append(moved)
	for r: Dictionary in records:
		if bool(r.get("now", false)):
			continue
		var moved := r.duplicate()
		if end > 0 and r.get("ticks") is PackedInt32Array:
			moved["ticks"] = _shifted(r["ticks"] as PackedInt32Array, end)
		out.append(moved)
	return out


## Lays the records on the clock at `speed` (an unknown speed takes "normal"). A record whose path has under two hexes, or
## whose seen and ticks do not fit its path, is left out. A retreat walk is moved after the last movement tick.
func setup(records: Array[Dictionary], speed: StringName) -> void:
	_walks = []
	_duration = 0.0
	_time = 0.0
	var kept: Array[Dictionary] = []
	for r: Dictionary in records:
		var path: Array[Vector2i] = []
		path.assign(r["path"] as Array)
		var seen := r["seen"] as PackedByteArray
		var ticks := r["ticks"] as PackedInt32Array
		if path.size() < 2 or seen.size() != path.size() or ticks.size() != path.size() - 1:
			continue
		kept.append({"army": int(r["army"]), "tag": StringName(r["tag"]), "path": path, "seen": seen, "ticks": ticks,
			"fixed": bool(r.get("fixed", false)), "timed": _timed_flags(path, seen), "starts": PackedFloat64Array(), "ends": PackedFloat64Array()})
	var retreat := PackedByteArray()
	var move_last := 0
	var fixed_end := 0
	for w: Dictionary in kept:
		if bool(w["fixed"]):
			fixed_end = maxi(fixed_end, _last_tick(w["ticks"] as PackedInt32Array))
	for w: Dictionary in kept:
		var back := _is_retreat(w, fixed_end)
		retreat.append(1 if back else 0)
		if not back:
			move_last = maxi(move_last, _last_tick(w["ticks"] as PackedInt32Array))
	for b: Dictionary in _battles:
		move_last = maxi(move_last, int(b["tick"]))
	for i: int in kept.size():
		if retreat[i] == 1:
			kept[i]["ticks"] = _after(kept[i]["ticks"] as PackedInt32Array, move_last)
	_walks.assign(kept)
	var last_tick := move_last
	for w: Dictionary in _walks:
		last_tick = maxi(last_tick, _last_tick(w["ticks"] as PackedInt32Array))
	var shown_tick := _shown_ticks(last_tick)
	var shown_count := 0
	for t: int in range(1, last_tick + 1):
		shown_count += shown_tick[t]
	var base := float(STEP_SECONDS.get(speed, STEP_SECONDS[&"normal"]))
	var step := base
	if shown_count > 0:
		step = minf(base, maxf(MIN_STEP, MAX_SECONDS / float(shown_count)))
	var tick_start := PackedFloat64Array()
	tick_start.resize(last_tick + 2)
	tick_start.fill(0.0)
	for t: int in range(1, last_tick + 1):
		tick_start[t + 1] = tick_start[t] + (step if shown_tick[t] == 1 else 0.0)
	for w: Dictionary in _walks:
		_lay_steps(w, tick_start, step)
	for b: Dictionary in _battles:
		b["start"] = tick_start[int(b["tick"])]
	_duration = maxf(0.0, tick_start[last_tick + 1]) if last_tick > 0 else 0.0


## The seconds the whole replay takes (0 for nothing to show).
func duration() -> float:
	return _duration


## Moves the clock on by `delta` seconds; it stops at the duration.
func advance(delta: float) -> void:
	_time = minf(_time + maxf(delta, 0.0), _duration)


func time() -> float:
	return _time


## True once the clock has reached the end (also for an empty plan).
func finished() -> bool:
	return _time >= _duration


## Ends the replay at once: the clock is at the duration, every walk is at its last hex.
func skip() -> void:
	_time = _duration


## Where each walk is now, one Dictionary a walk not yet finished, in record order: {army, tag, from, to, t, shown}. A walk
## that waits (before its first step, or between two steps) is at `from` with `to` the same hex and t 0. `shown` is false
## for a step the viewer did not see. A finished walk is left out: its army is then drawn where the core put it.
func poses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in _walks:
		var pose := _pose(w)
		if not pose.is_empty():
			out.append(pose)
	return out


## The battle marks that have begun by now, in record order: {hex, shown}. `shown` is false for a battle the viewer may not
## see (the shell does not show it).
func marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in _battles:
		if float(b["start"]) <= _time:
			out.append({"hex": b["hex"], "shown": b["shown"]})
	return out


static func _last_tick(ticks: PackedInt32Array) -> int:
	return ticks[ticks.size() - 1] if ticks.size() > 0 else 0


static func _shifted(ticks: PackedInt32Array, by: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for tick: int in ticks:
		out.append(tick + by)
	return out


## A walk that starts on a battle hex after that battle's tick is a retreat (no army walks out of a battle in the movement).
## A chained (fixed) walk is never laid again, and a battle of the chained walks (tick up to `fixed_end`) has its retreats there.
func _is_retreat(w: Dictionary, fixed_end: int = 0) -> bool:
	if bool(w["fixed"]):
		return false
	var path := w["path"] as Array[Vector2i]
	var ticks := w["ticks"] as PackedInt32Array
	for b: Dictionary in _battles:
		if int(b["tick"]) > fixed_end and b["hex"] == path[0] and int(b["tick"]) < ticks[0]:
			return true
	return false


## The same walk's ticks moved to start one tick after `after`, keeping their spacing.
static func _after(ticks: PackedInt32Array, after: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for tick: int in ticks:
		out.append(after + tick - ticks[0] + 1)
	return out


## Which ticks carry a shown step of some walk (index = tick number, 0 unused).
func _shown_ticks(last_tick: int) -> PackedByteArray:
	var shown := PackedByteArray()
	shown.resize(last_tick + 2)
	shown.fill(0)
	for w: Dictionary in _walks:
		var ticks := w["ticks"] as PackedInt32Array
		var timed := w["timed"] as PackedByteArray
		for i: int in ticks.size():
			if timed[i] == 1:
				shown[ticks[i]] = 1
	return shown


## Each step's start and end on the clock: a timed step takes `step` seconds from its tick's start, any other none.
static func _lay_steps(w: Dictionary, tick_start: PackedFloat64Array, step: float) -> void:
	var ticks := w["ticks"] as PackedInt32Array
	var timed := w["timed"] as PackedByteArray
	var starts := PackedFloat64Array()
	var ends := PackedFloat64Array()
	for i: int in ticks.size():
		var start := tick_start[ticks[i]]
		starts.append(start)
		ends.append(start + (step if timed[i] == 1 else 0.0))
	w["starts"] = starts
	w["ends"] = ends


## A step is shown only when the viewer sees its END hex (strict fog: a walker is never drawn onto a hex the viewer cannot
## see, and the camera never follows to one). A walk that leaves the viewer's sight shows nothing of that step.
static func _shown_step(seen: PackedByteArray, i: int) -> bool:
	return seen[i + 1] == 1


## The timed flag of each step of one walk: 1 for a step the viewer sees at its end and, with a focus, that has one of its
## two hexes in it (D37); 0 for the rest, which are instant.
func _timed_flags(path: Array[Vector2i], seen: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	for i: int in path.size() - 1:
		var in_view := not _focus.has_area() or _focus.has_point(path[i]) or _focus.has_point(path[i + 1])
		out.append(1 if _shown_step(seen, i) and in_view else 0)
	return out


func _pose(w: Dictionary) -> Dictionary:
	var path := w["path"] as Array[Vector2i]
	var seen := w["seen"] as PackedByteArray
	var starts := w["starts"] as PackedFloat64Array
	var ends := w["ends"] as PackedFloat64Array
	for i: int in starts.size():
		if _time >= ends[i]:
			continue
		var army := int(w["army"])
		var tag := StringName(w["tag"])
		if _time < starts[i]:
			return {"army": army, "tag": tag, "from": path[i], "to": path[i], "t": 0.0, "shown": seen[i] == 1}
		var span := ends[i] - starts[i]
		return {"army": army, "tag": tag, "from": path[i], "to": path[i + 1],
			"t": clampf((_time - starts[i]) / span, 0.0, 1.0), "shown": _shown_step(seen, i)}
	return {}
