## The movement replay's timeline (docs/architecture/m6-build-spec.md 6.4 and 5.6; task L15): the walks of one season (the
## `unit_moved` records: tag, army, path, seen, ticks) laid on one clock, so the armies walk together tick by tick. Pure: it
## reads the records it is given and the time it is advanced by, never the game. A step the viewer did not see takes no
## time (it is instant); a shown step takes the speed's seconds, shortened so the whole replay stays within MAX_SECONDS and
## never below MIN_STEP a step.
class_name ReplayPlan
extends RefCounted

## Seconds a shown step takes at each speed (`game/movement`). `instant` is not a plan: MoveReplay refuses it.
const STEP_SECONDS := {&"normal": 0.2, &"slow": 0.5}
## The longest a replay runs, in seconds, however many ticks it has.
const MAX_SECONDS := 6.0
## The shortest a shown step gets, in seconds.
const MIN_STEP := 0.04

## One walk per record: {army, tag, path, seen, ticks, starts, ends}; starts and ends are PackedFloat64Array, one a step.
var _walks: Array[Dictionary] = []
var _duration := 0.0
var _time := 0.0


## Lays the records on the clock at `speed` (an unknown speed takes "normal"). A record whose path has under two hexes, or
## whose seen and ticks do not fit its path, is left out.
func setup(records: Array[Dictionary], speed: StringName) -> void:
	_walks = []
	_duration = 0.0
	_time = 0.0
	var last_tick := 0
	for r: Dictionary in records:
		var path: Array[Vector2i] = []
		path.assign(r["path"] as Array)
		var seen := r["seen"] as PackedByteArray
		var ticks := r["ticks"] as PackedInt32Array
		if path.size() < 2 or seen.size() != path.size() or ticks.size() != path.size() - 1:
			continue
		_walks.append({"army": int(r["army"]), "tag": StringName(r["tag"]), "path": path, "seen": seen, "ticks": ticks,
			"starts": PackedFloat64Array(), "ends": PackedFloat64Array()})
		for tick: int in ticks:
			last_tick = maxi(last_tick, tick)
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


## Which ticks carry a shown step of some walk (index = tick number, 0 unused).
func _shown_ticks(last_tick: int) -> PackedByteArray:
	var shown := PackedByteArray()
	shown.resize(last_tick + 2)
	shown.fill(0)
	for w: Dictionary in _walks:
		var ticks := w["ticks"] as PackedInt32Array
		var seen := w["seen"] as PackedByteArray
		for i: int in ticks.size():
			if _shown_step(seen, i):
				shown[ticks[i]] = 1
	return shown


## Each step's start and end on the clock: a shown step takes `step` seconds from its tick's start, an unseen one none.
static func _lay_steps(w: Dictionary, tick_start: PackedFloat64Array, step: float) -> void:
	var ticks := w["ticks"] as PackedInt32Array
	var seen := w["seen"] as PackedByteArray
	var starts := PackedFloat64Array()
	var ends := PackedFloat64Array()
	for i: int in ticks.size():
		var start := tick_start[ticks[i]]
		starts.append(start)
		ends.append(start + (step if _shown_step(seen, i) else 0.0))
	w["starts"] = starts
	w["ends"] = ends


## A step is shown only when the viewer sees its END hex (strict fog: a walker is never drawn onto a hex the viewer cannot
## see, and the camera never follows to one). A walk that leaves the viewer's sight shows nothing of that step.
static func _shown_step(seen: PackedByteArray, i: int) -> bool:
	return seen[i + 1] == 1


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
