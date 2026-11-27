## Pure camera zoom, smoothing, anchor and bounds model (docs/architecture/ui-and-controls-spec.md sections 4.3 and 4.4).
class_name ZoomModel
extends RefCounted

const ZOOM_MAX := 2.0
const FIT_MARGIN := 0.96
## The zoom-out limit as a share of the fit zoom: about three wheel notches past the whole-map view (1.15^-3 = 0.66).
const MIN_MARGIN := 0.65
const BASE_NOTCH := 1.15
const SMOOTH_TAU := 0.07
const SNAP_EPS := 0.001
const GLIDE_TIME := 0.35
const PAN_BASE_PX_PER_SEC := 900.0
const PAN_FAST_MULT := 2.5
const ZOOM_FAR_OFF := 0.25
const ZOOM_FAR_ON := 0.20
const GRID_FADE_START := 0.45
const GRID_FADE_END := 0.30


## Whole-map fit zoom: `min(free_w / map_w, free_h / map_h) * 0.96`, clamped to `<= ZOOM_MAX`.
static func fit_zoom(free_size: Vector2, map_size: Vector2) -> float:
	if free_size.x <= 0.0 or free_size.y <= 0.0 or map_size.x <= 0.0 or map_size.y <= 0.0:
		return 1.0
	var fit := minf(free_size.x / map_size.x, free_size.y / map_size.y) * FIT_MARGIN
	return clampf(fit, 1.0e-5, ZOOM_MAX)


## Minimum allowed zoom: `fit_zoom * MIN_MARGIN`, clamped to `<= ZOOM_MAX`.
static func min_zoom(free_size: Vector2, map_size: Vector2) -> float:
	if free_size.x <= 0.0 or free_size.y <= 0.0 or map_size.x <= 0.0 or map_size.y <= 0.0:
		return 1.0
	return minf(fit_zoom(free_size, map_size) * MIN_MARGIN, ZOOM_MAX)


## Clamps `zoom` between `min_zoom(free_size, map_size)` and `max_z`.
static func clamp_zoom(zoom: float, free_size: Vector2, map_size: Vector2, max_z: float = ZOOM_MAX) -> float:
	var lo := min_zoom(free_size, map_size)
	return clampf(zoom, minf(lo, max_z), max_z)


## Multiplier for one wheel notch at `zoom_speed_pct` (50%..200%) and `event_factor` (0 treated as 1).
static func notch_factor(zoom_speed_pct: float = 100.0, event_factor: float = 1.0) -> float:
	var speed := clampf(zoom_speed_pct, 50.0, 200.0) / 100.0
	var factor := 1.0 if is_zero_approx(event_factor) else event_factor
	return pow(pow(BASE_NOTCH, speed), factor)


## New camera centre in map pixels so the map point under `anchor_offset_screen_px`
## (offset from viewport centre in screen pixels) stays fixed when zoom changes.
static func zoom_about(centre: Vector2, current_zoom: float, target_zoom: float, anchor_offset_screen_px: Vector2) -> Vector2:
	if current_zoom <= 0.0 or target_zoom <= 0.0:
		return centre
	var map_point := centre + anchor_offset_screen_px / current_zoom
	return map_point - anchor_offset_screen_px / target_zoom


## Exponential easing towards `target_zoom` with time constant `SMOOTH_TAU` (70 ms),
## snapping when relative difference `<= SNAP_EPS` or when `reduce_motion` / `not smoothing_on`.
static func step_smooth(current_zoom: float, target_zoom: float, dt: float, reduce_motion: bool = false, smoothing_on: bool = true) -> float:
	if reduce_motion or not smoothing_on:
		return target_zoom
	var denom := maxf(absf(target_zoom), 1.0e-6)
	if absf(target_zoom - current_zoom) / denom <= SNAP_EPS:
		return target_zoom
	if dt <= 0.0:
		return current_zoom
	var alpha := clampf(1.0 - exp(-dt / SMOOTH_TAU), 0.0, 1.0)
	var next := lerpf(current_zoom, target_zoom, alpha)
	if absf(target_zoom - next) / denom <= SNAP_EPS:
		return target_zoom
	return next


## Keeps the camera centre inside `Rect2(Vector2.ZERO, map_size)`.
static func clamp_centre(centre: Vector2, map_size: Vector2) -> Vector2:
	var x := clampf(centre.x, 0.0, map_size.x) if map_size.x > 0.0 else 0.0
	var y := clampf(centre.y, 0.0, map_size.y) if map_size.y > 0.0 else 0.0
	return Vector2(x, y)


## Clamps camera centre for the view: on any axis where `map_size * zoom <= free_size`,
## centres on `map_size / 2.0`; otherwise keeps `centre` inside `[0, map_size]`.
static func clamp_centre_for_view(centre: Vector2, zoom: float, free_size: Vector2, map_size: Vector2) -> Vector2:
	var x := 0.0
	if map_size.x > 0.0:
		if zoom > 0.0 and free_size.x > 0.0 and map_size.x * zoom <= free_size.x:
			x = map_size.x * 0.5
		else:
			x = clampf(centre.x, 0.0, map_size.x)
	var y := 0.0
	if map_size.y > 0.0:
		if zoom > 0.0 and free_size.y > 0.0 and map_size.y * zoom <= free_size.y:
			y = map_size.y * 0.5
		else:
			y = clampf(centre.y, 0.0, map_size.y)
	return Vector2(x, y)


## Adjusts zoom for a UI scale change (`zoom * (old_scale / new_scale)`).
static func scale_for_ui_change(zoom: float, old_scale: float, new_scale: float) -> float:
	if old_scale <= 0.0 or new_scale <= 0.0:
		return zoom
	return zoom * (old_scale / new_scale)


## Grid layer alpha: `base_opacity` at and above `GRID_FADE_START` (0.45), `0.0` at and below `GRID_FADE_END` (0.30).
static func grid_alpha(zoom: float, base_opacity: float = 1.0) -> float:
	var opacity := clampf(base_opacity, 0.0, 1.0)
	if zoom <= GRID_FADE_END:
		return 0.0
	if zoom >= GRID_FADE_START:
		return opacity
	var t := (zoom - GRID_FADE_END) / (GRID_FADE_START - GRID_FADE_END)
	return opacity * clampf(t, 0.0, 1.0)
