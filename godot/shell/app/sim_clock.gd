## The shell's clock (issue 457). Every timer, budget, guard and animation step reads time through here: the real clock,
## unless a test sets `step_s`. The UI monkey sets it to 1/60 s and calls tick() once per frame it waits, so every
## timer is then a pure function of the frames run and a seed plays the same way on every machine. The game never sets it.
class_name SimClock
extends RefCounted

## Test-only: the fixed clock's seconds per frame. Negative (the game's value) is the real clock.
static var step_s := -1.0
## Fixed clock only: virtual microseconds since reset().
static var _now_us := 0
## Fixed clock only: virtual microseconds each read adds, so a loop that polls the clock until a budget ends still ends.
const READ_US := 50


## True while the fixed clock runs (a test set step_s).
static func fixed() -> bool:
	return step_s >= 0.0


## Restarts the fixed clock at 0 (the monkey does it per seed, so a seed does not depend on the seeds before it).
static func reset() -> void:
	_now_us = 0


## Advances the fixed clock by one frame. The UI monkey calls it once per frame it waits; a no-op on the real clock.
static func tick() -> void:
	if fixed():
		_now_us += int(round(step_s * 1000000.0))


## A frame's delta: the fixed step while the fixed clock runs, the real delta otherwise.
static func delta(real_delta: float) -> float:
	return step_s if fixed() else real_delta


## Milliseconds since the start of the run (the real clock's Time.get_ticks_msec in the game).
static func msec() -> int:
	return int(float(usec()) / 1000.0)


## Microseconds since the start of the run (the real clock's Time.get_ticks_usec in the game).
static func usec() -> int:
	if not fixed():
		return Time.get_ticks_usec()
	_now_us += READ_US
	return _now_us
