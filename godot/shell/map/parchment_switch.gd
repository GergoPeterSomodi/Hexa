## The parchment's switch by the zoom (docs/architecture/map-overview-build-spec.md D2, amended 2026-11-27 after the
## owner's playtest): the parchment shows only well past the whole-map view; the whole-map view (the fit zoom), one
## default wheel notch past it and everything closer show the tiles, never both at rest. Zooming out, the parchment comes
## under PARCHMENT_UNDER_FIT times the fit zoom; zooming in, the tiles take over at TILES_FROM_FIT times it, so a zoom
## resting between the two keeps what it shows. Only the camera's zooming chooses: when the free map area changes (the
## HUD hidden or shown, the window resized), which moves the fit zoom and may push the zoom up to the new zoom-out limit,
## what shows is kept until the next zoom. A crossing cross-fades over FADE_SEC seconds, which step() spends. Everything
## else switches at once: until SETTLE_STEPS steps have passed after settle() (a load: the camera is still being put in
## its place, and the zoom alone says what shows), while the zoom does not decide what shows, and under reduce motion. It
## holds numbers only; ParchmentMap draws them.
class_name ParchmentSwitch
extends RefCounted

## THE SWITCH POINT, as shares of the fit zoom, for every map (the pair to tune). At the default zoom speed a notch out
## from the whole-map view is 0.87 of it (tiles), two are 0.756 (parchment) and the third reaches 0.66, next to the
## zoom-out limit (ZoomModel.MIN_MARGIN, 0.65). Both must stay between that limit and 1, the second above the first.
const PARCHMENT_UNDER_FIT := 0.80
const TILES_FROM_FIT := 0.84
const FADE_SEC := 0.25
const SETTLE_STEPS := 2

## Reduce motion: every crossing switches at once.
var instant := false

var _parchment := false  # the side of the switch the zoom is on
var _blend := 0.0  # how much of the parchment shows: 0 or 1 at rest
var _settling := SETTLE_STEPS
var _zoom := 0.0  # of the last follow(); 0 before the first
var _fit := 0.0


## Whether a zoom shows the parchment, for the fit zoom of the window; `on_parchment` is what shows now.
static func parchment_at(zoom: float, fit: float, on_parchment: bool) -> bool:
	return zoom < fit * (TILES_FROM_FIT if on_parchment else PARCHMENT_UNDER_FIT)


## A load: until the steps have passed again, what the zoom says shows at once (and from the tiles' side).
func settle() -> void:
	_settling = SETTLE_STEPS


## The camera is at `zoom`. With `decides` false the zoom's choice is kept for later and shows without a fade.
func follow(zoom: float, fit: float, decides: bool) -> void:
	if _settling > 0 or _zoomed(zoom, fit):
		_parchment = parchment_at(zoom, fit, _parchment and _settling == 0)
	_zoom = zoom
	_fit = fit
	if not decides or _settling > 0 or instant:
		snap()


## Whether the camera zoomed since the last follow(). A zoom that stayed did not; nor one that, with another fit zoom,
## is only what CameraRig's clamp makes of the last one in the new free area.
func _zoomed(zoom: float, fit: float) -> bool:
	if zoom == _zoom:
		return false
	var lowest := minf(fit * ZoomModel.MIN_MARGIN, ZoomModel.ZOOM_MAX)
	return is_equal_approx(fit, _fit) or not is_equal_approx(zoom, clampf(_zoom, lowest, ZoomModel.ZOOM_MAX))


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
