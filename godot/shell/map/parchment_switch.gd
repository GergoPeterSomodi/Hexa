## The parchment's switch by the zoom (docs/architecture/map-overview-build-spec.md D2, amended 2026-11-27): the
## parchment or the tiles, never both at rest. Zooming in, the tiles take over at LEAVE_RATIO times max(fit,
## SOLID_MIN_ZOOM); zooming out, the parchment comes back under RETURN_RATIO times it, so a zoom resting between the two
## keeps what it shows. A crossing cross-fades over FADE_SEC seconds, which step() spends. Everything else switches at
## once: until SETTLE_STEPS steps have passed after settle() (a load: the camera is still being put in its place), while
## the zoom does not decide what shows, and under reduce motion. It holds numbers only; ParchmentMap draws them.
class_name ParchmentSwitch
extends RefCounted

## Under this fit zoom (a large map) the parchment goes by this zoom instead of the fit's.
const SOLID_MIN_ZOOM := 0.28
## Of that base: one wheel notch in (1.15) keeps the parchment, two (1.3225) show the tiles.
const LEAVE_RATIO := 1.24
const RETURN_RATIO := 1.2
const FADE_SEC := 0.25
const SETTLE_STEPS := 2

## Reduce motion: every crossing switches at once.
var instant := false

var _parchment := true  # the side of the switch the zoom is on
var _blend := 1.0  # how much of the parchment shows: 0 or 1 at rest
var _settling := SETTLE_STEPS


## Whether a zoom shows the parchment, for the fit zoom of the window; `on_parchment` is what shows now.
static func parchment_at(zoom: float, fit: float, on_parchment: bool) -> bool:
	return zoom < maxf(fit, SOLID_MIN_ZOOM) * (LEAVE_RATIO if on_parchment else RETURN_RATIO)


## A load: until the steps have passed again, what the zoom says shows at once (and from the parchment's side).
func settle() -> void:
	_settling = SETTLE_STEPS


## The camera is at `zoom`. With `decides` false the zoom's choice is kept for later and shows without a fade.
func follow(zoom: float, fit: float, decides: bool) -> void:
	_parchment = parchment_at(zoom, fit, _parchment or _settling > 0)
	if not decides or _settling > 0 or instant:
		snap()


## Ends a fade: the side the zoom is on shows whole.
func snap() -> void:
	_blend = float(_parchment)


## Spends `delta` seconds of a fade (and one of the settling steps); true when the blend moved.
func step(delta: float) -> bool:
	_settling = maxi(_settling - 1, 0)
	var target := float(_parchment)
	if _blend == target:
		return false
	_blend = move_toward(_blend, target, maxf(delta, 0.0) / FADE_SEC)
	return true


## How much of the parchment shows now, 0 (tiles) to 1.
func blend() -> float:
	return _blend
