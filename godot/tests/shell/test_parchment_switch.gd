## The parchment's switch between itself and the tiles (docs/architecture/map-overview-build-spec.md D2, amended
## 2026-11-27 after the owner's playtest): which zooms show it (only well past the whole-map view), what a change of the
## free map area keeps, the cross-fade over time, and what switches at once. Each planted case (P) feeds a check the fault it
## is there for. The same through the camera: test_parchment_zoom.gd.
extends GutTest

## [zoom, fit, parchment when it shows now, parchment when the tiles show now]: fit 0.65 (north Italy, limit 0.4225) goes
## to the tiles at 0.546 and comes back under 0.52 (0.5652 is one default notch past the whole map); fit 0.04 (a large
## map, limit 0.026): at 0.0336 and under 0.032.
const SWITCHES: Array[Array] = [
	[0.04, 0.65, true, true], [0.4225, 0.65, true, true], [0.5199, 0.65, true, true], [0.521, 0.65, true, false],
	[0.545, 0.65, true, false], [0.547, 0.65, false, false], [0.5652, 0.65, false, false], [0.65, 0.65, false, false],
	[2.0, 0.65, false, false], [0.026, 0.04, true, true], [0.0319, 0.04, true, true], [0.0321, 0.04, true, false],
	[0.0335, 0.04, true, false], [0.0337, 0.04, false, false], [0.04, 0.04, false, false], [0.27, 0.04, false, false],
	[2.0, 0.04, false, false],
]
## The wheel notches that bring the other side, at each zoom speed (%): out from the whole map to the parchment, and back
## in from the zoom-out limit to the tiles.
const NOTCHES: Dictionary[int, Vector2i] = {50: Vector2i(4, 4), 100: Vector2i(2, 2), 200: Vector2i(1, 1)}
## The made-up large map's fit zoom (about), north Italy's at several windows, and the largest a fit can be.
const FITS: Array[float] = [0.04, 0.3, 0.431, 0.6647, 0.8, 1.2, ZoomModel.ZOOM_MAX]
## The fit zooms of a 1280 x 720 window with the HUD shown and hidden (the free area is 664 or 720 px high).
const SHOWN := 0.43099
const HIDDEN := 0.43099 * 720.0 / 664.0


## The planted fault of a free area change: a switch that chooses again whenever it is asked.
class AlwaysChooses:
	extends ParchmentSwitch

	func _zoomed(_zoom_now: float, _fit_now: float) -> bool:
		return true


## A north Italy node with its geometry built.
func _node() -> ParchmentMap:
	var node := ParchmentMap.new()
	add_child_autofree(node)
	node.begin(EconomyFixture.game(&"GEN"))
	node.step(1.0e9)
	return node


## What is wrong with how a node shows `alpha`: only the picture fades, as one, and it is a group only in between 0
## and 1. (Headless cannot read the canvas group's mode back: is_fading is the node's own account of it.)
func _fade_problems(node: ParchmentMap, alpha: float) -> int:
	var between := alpha > 0.0 and alpha < 1.0
	var out := int(node.is_fading() != between)
	out += int(not is_equal_approx(node.picture().self_modulate.a, alpha if between else 1.0))
	return out + int(node.visible != (alpha > 0.0))


## The cases of SWITCHES a switch rule gets wrong.
func _switch_problems(parchment: Callable) -> int:
	var out := 0
	for row: Array in SWITCHES:
		out += int(bool(parchment.call(row[0], row[1], true)) != bool(row[2]))
		out += int(bool(parchment.call(row[0], row[1], false)) != bool(row[3]))
	return out


## Two steps of no time: a load has settled, and the next zoom crossing cross-fades.
func _settle(node: ParchmentMap) -> void:
	node.step_fade(0.0)
	node.step_fade(0.0)


## The wheel notches from `from` (each `step` times the zoom, held between the limit and the fit) until the side is no
## longer `parchment`; 0 when it never changes.
func _notches_until_changed(from: float, step: float, fit: float, parchment: bool) -> int:
	var zoom := from
	for k: int in range(1, 20):
		zoom = clampf(zoom * step, fit * ZoomModel.MIN_MARGIN, fit)
		if ParchmentSwitch.parchment_at(zoom, fit, parchment) != parchment:
			return k
	return 0


func test_the_switch_goes_by_the_fit_zoom_with_a_little_hysteresis() -> void:
	assert_eq(_switch_problems(ParchmentSwitch.parchment_at), 0)
	assert_true(ZoomModel.MIN_MARGIN < ParchmentSwitch.PARCHMENT_UNDER_FIT, "the parchment is within reach")
	assert_true(ParchmentSwitch.PARCHMENT_UNDER_FIT < ParchmentSwitch.TILES_FROM_FIT, "a little hysteresis")
	assert_true(ParchmentSwitch.TILES_FROM_FIT < 1.0, "the whole map is the tiles'")
	assert_almost_eq(pow(ZoomModel.BASE_NOTCH, -3.0), ZoomModel.MIN_MARGIN, 0.01, "the limit: about three notches past")
	for speed: int in NOTCHES:
		var notch := ZoomModel.notch_factor(float(speed))
		for fit: float in FITS:
			var what := "fit %s at %s %%" % [fit, speed]
			var limit := fit * ZoomModel.MIN_MARGIN
			assert_false(ParchmentSwitch.parchment_at(fit, fit, true), "the whole map: tiles, %s" % what)
			assert_false(ParchmentSwitch.parchment_at(fit, fit, false), "and they stay, %s" % what)
			assert_true(ParchmentSwitch.parchment_at(limit, fit, false), "the limit, %s" % what)
			assert_eq(_notches_until_changed(fit, 1.0 / notch, fit, false), NOTCHES[speed].x, "out, %s" % what)
			assert_eq(_notches_until_changed(limit, notch, fit, true), NOTCHES[speed].y, "in, %s" % what)


func test_p_a_switch_with_no_hysteresis_is_reported() -> void:
	var fault := func(zoom: float, fit: float, _on: bool) -> bool:
		return ParchmentSwitch.parchment_at(zoom, fit, true)
	assert_gt(_switch_problems(fault), 0, "P: one threshold both ways")


func test_p_a_floor_under_the_fit_is_reported() -> void:
	var fault := func(zoom: float, fit: float, on: bool) -> bool:
		return ParchmentSwitch.parchment_at(zoom, maxf(fit, 0.28), on)
	assert_gt(_switch_problems(fault), 0, "P: a large map's whole view would be parchment")


## What a switch shows after the camera is at `zoom` with the fit `fit` and any fade has ended.
func _shows(switch: ParchmentSwitch, zoom: float, fit: float) -> bool:
	switch.follow(zoom, fit, true)
	switch.step(1.0)
	return switch.blend() == 1.0


## What goes wrong when only the free area changes, as CameraRig does it: the fit moves, and the zoom stays or is pushed
## up to the new limit. Each step: [zoom, fit, parchment wanted, what happened].
func _area_problems(switch: ParchmentSwitch) -> Array[String]:
	var near := SHOWN * 0.85  # tiles, but 0.78 of the fit with the HUD hidden
	var low := SHOWN * ZoomModel.MIN_MARGIN
	var pushed := HIDDEN * ZoomModel.MIN_MARGIN
	var far := HIDDEN * 0.79  # parchment, but 0.86 of the fit with the HUD shown
	var steps: Array[Array] = [
		[SHOWN, SHOWN, false, "the whole map"],
		[near, SHOWN, false, "resting a little past one notch"],
		[near, HIDDEN, false, "HUD hidden there (0.78 of the new fit)"],
		[near, HIDDEN, false, "and the next frame"],
		[near, SHOWN, false, "HUD shown again"],
		[HIDDEN, SHOWN, false, "zoomed in"],
		[low, SHOWN, true, "zoomed out to the limit"],
		[pushed, HIDDEN, true, "HUD hidden at the limit: pushed up"],
		[far, HIDDEN, true, "zoomed in a little"],
		[far, SHOWN, true, "HUD shown there (0.86 of the new fit)"],
		[far, SHOWN, true, "and the frame after"],
		[SHOWN, SHOWN, false, "the next zoom chooses again: the whole map"],
		[low, SHOWN, true, "the limit"],
		[HIDDEN, HIDDEN, false, "Fit in the same frame as an area change chooses"],
		[SHOWN * 0.75, SHOWN, true, "and a saved zoom with another fit chooses"],
		[SHOWN, SHOWN, false, "back on the whole map"],
		[low * 1.6, SHOWN * 1.6, false, "an area so much larger that the whole map is pushed to its limit"],
	]
	var out: Array[String] = []
	switch.step(0.0)
	switch.step(0.0)
	for row: Array in steps:
		if _shows(switch, row[0], row[1]) != bool(row[2]):
			out.append(str(row[3]))
	return out


func test_a_change_of_the_free_area_keeps_what_shows_until_the_next_zoom() -> void:
	assert_eq(_area_problems(ParchmentSwitch.new()), [] as Array[String])


func test_p_a_switch_that_chooses_at_every_area_change_is_reported() -> void:
	var found := _area_problems(AlwaysChooses.new())
	assert_has(found, "HUD hidden there (0.78 of the new fit)", "P")
	assert_has(found, "HUD shown there (0.86 of the new fit)", "P")
	assert_has(found, "an area so much larger that the whole map is pushed to its limit", "P")


func test_a_zoom_crossing_cross_fades_over_a_quarter_second_and_rests_whole() -> void:
	var node := _node()
	assert_eq(node.apply_zoom(0.45, 0.65), 1.0)
	_settle(node)
	assert_eq(node.apply_zoom(1.0, 0.65), 1.0, "no time has passed")
	assert_eq(_fade_problems(node, 1.0), 0)
	node.step_fade(0.05)
	assert_almost_eq(node.apply_zoom(1.0, 0.65), 0.8, 0.0001)
	assert_eq(_fade_problems(node, 0.8), 0, "one picture while it fades")
	node.step_fade(0.075)
	assert_almost_eq(node.apply_zoom(1.0, 0.65), 0.5, 0.0001, "half the time, half way: whatever the zoom does")
	assert_almost_eq(node.apply_zoom(1.5, 0.65), 0.5, 0.0001)
	node.step_fade(0.125)
	assert_eq(node.apply_zoom(1.0, 0.65), 0.0, "at rest: exactly the tiles")
	assert_eq(_fade_problems(node, 0.0), 0)
	assert_eq(node.apply_zoom(0.53, 0.65), 0.0, "between the two thresholds the tiles stay")
	node.step_fade(1.0)
	assert_eq(node.apply_zoom(0.45, 0.65), 0.0)
	node.step_fade(0.1)
	assert_almost_eq(node.apply_zoom(0.45, 0.65), 0.4, 0.0001, "and back")
	assert_almost_eq(node.apply_zoom(1.0, 0.65), 0.4, 0.0001, "turned round half way")
	node.step_fade(0.05)
	assert_almost_eq(node.apply_zoom(1.0, 0.65), 0.2, 0.0001)
	node.step_fade(1.0)
	node.apply_zoom(0.45, 0.65)
	node.step_fade(1.0)
	assert_eq(node.apply_zoom(0.53, 0.65), 1.0, "between the two thresholds the parchment stays")
	assert_false(node.is_fading())


func test_loads_modes_settings_and_reduce_motion_switch_at_once() -> void:
	var node := _node()
	node.apply_zoom(1.0, 0.65)
	node.step_fade(0.01)
	assert_eq(node.apply_zoom(0.45, 0.65), 1.0, "a load: the camera is still being put in its place")
	node.step_fade(0.01)
	node.apply_zoom(1.0, 0.65)
	node.step_fade(0.1)
	assert_true(node.is_fading(), "settled: it fades")
	node.set_mode(MapModes.Mode.GOODS)
	assert_eq(_fade_problems(node, 1.0), 0, "Goods is solid at once, before the next apply_zoom: no group")
	node.set_mode(MapModes.Mode.TERRAIN)
	assert_eq(_fade_problems(node, 0.0), 0, "another mode shows at once what the zoom says")
	assert_eq(node.apply_zoom(0.45, 0.65), 0.0)
	node.step_fade(0.1)
	node.set_mode(MapModes.Mode.RELIEF)
	assert_false(node.is_fading() or node.visible, "hidden at once: no group")
	node.apply_zoom(1.0, 0.65)
	node.set_mode(MapModes.Mode.TERRAIN)
	assert_eq(node.apply_zoom(1.0, 0.65), 0.0, "a zoom in a data mode is not faded later")
	node.set_options(true, true, false, false, false)
	node.apply_zoom(0.45, 0.65)
	node.set_options(true, true, false, false, true)
	assert_eq(node.apply_zoom(0.45, 0.65), 1.0, "switched on: at once")
	node.set_instant(true)
	assert_eq(node.apply_zoom(1.0, 0.65), 0.0, "reduce motion")
	assert_eq(node.apply_zoom(0.45, 0.65), 1.0)
	node.set_instant(false)
	node.begin(EconomyFixture.game(&"GEN"))
	assert_eq(node.apply_zoom(1.0, 0.65), 0.0, "a new game: at once")
	node.apply_zoom(0.45, 0.65)
	node.begin(EconomyFixture.game(&"GEN"))
	assert_eq(node.apply_zoom(0.53, 0.65), 0.0, "a load between the thresholds starts from the tiles' side")
