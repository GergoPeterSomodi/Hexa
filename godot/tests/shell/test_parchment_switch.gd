## The parchment's switch between itself and the tiles (docs/architecture/map-overview-build-spec.md D2, amended
## 2026-11-27): which zooms show it, the cross-fade over time, and what switches at once. Each planted case (P) feeds a
## check the fault it is there for.
extends GutTest

## [zoom, fit, parchment when it shows now, parchment when the tiles show now]: fit 0.65 (north Italy) goes to the tiles
## at 0.806 and comes back under 0.78; fit 0.04 (a large map) goes by 0.28: at 0.3472 and 0.336.
const SWITCHES: Array[Array] = [
	[0.04, 0.65, true, true], [0.65, 0.65, true, true], [0.7475, 0.65, true, true], [0.79, 0.65, true, false],
	[0.805, 0.65, true, false], [0.807, 0.65, false, false], [0.86, 0.65, false, false], [2.0, 0.65, false, false],
	[0.04, 0.04, true, true], [0.322, 0.04, true, true], [0.34, 0.04, true, false], [0.348, 0.04, false, false],
	[2.0, 0.04, false, false],
]


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


func test_the_switch_goes_by_the_fit_zoom_with_a_little_hysteresis() -> void:
	assert_eq(_switch_problems(ParchmentSwitch.parchment_at), 0)
	var notch := ZoomModel.notch_factor()
	for fit: float in [0.3, 0.5, 0.6647, 0.8, 1.2]:
		assert_true(ParchmentSwitch.parchment_at(fit, fit, false), "the whole map, fit %s" % fit)
		assert_true(ParchmentSwitch.parchment_at(fit * notch, fit, true), "one notch in stays, fit %s" % fit)
		assert_false(ParchmentSwitch.parchment_at(fit * notch * notch, fit, true), "two notches in: tiles, %s" % fit)
		assert_true(ParchmentSwitch.parchment_at(fit * notch, fit, false), "one notch back out: parchment, %s" % fit)


func test_p_a_switch_with_no_hysteresis_is_reported() -> void:
	var fault := func(zoom: float, fit: float, _on: bool) -> bool:
		return ParchmentSwitch.parchment_at(zoom, fit, true)
	assert_gt(_switch_problems(fault), 0, "P: one threshold both ways")


func test_a_zoom_crossing_cross_fades_over_a_quarter_second_and_rests_whole() -> void:
	var node := _node()
	assert_eq(node.apply_zoom(0.65, 0.65), 1.0)
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
	assert_eq(node.apply_zoom(0.79, 0.65), 0.0, "between the two thresholds the tiles stay")
	node.step_fade(1.0)
	assert_eq(node.apply_zoom(0.65, 0.65), 0.0)
	node.step_fade(0.1)
	assert_almost_eq(node.apply_zoom(0.65, 0.65), 0.4, 0.0001, "and back")
	assert_almost_eq(node.apply_zoom(1.0, 0.65), 0.4, 0.0001, "turned round half way")
	node.step_fade(0.05)
	assert_almost_eq(node.apply_zoom(1.0, 0.65), 0.2, 0.0001)
	node.step_fade(1.0)
	node.apply_zoom(0.65, 0.65)
	node.step_fade(1.0)
	assert_eq(node.apply_zoom(0.79, 0.65), 1.0, "between the two thresholds the parchment stays")
	assert_false(node.is_fading())


func test_loads_modes_settings_and_reduce_motion_switch_at_once() -> void:
	var node := _node()
	node.apply_zoom(1.0, 0.65)
	node.step_fade(0.01)
	assert_eq(node.apply_zoom(0.65, 0.65), 1.0, "a load: the camera is still being put in its place")
	node.step_fade(0.01)
	node.apply_zoom(1.0, 0.65)
	node.step_fade(0.1)
	assert_true(node.is_fading(), "settled: it fades")
	node.set_mode(MapModes.Mode.GOODS)
	assert_eq(_fade_problems(node, 1.0), 0, "Goods is solid at once, before the next apply_zoom: no group")
	node.set_mode(MapModes.Mode.TERRAIN)
	assert_eq(_fade_problems(node, 0.0), 0, "another mode shows at once what the zoom says")
	assert_eq(node.apply_zoom(0.65, 0.65), 0.0)
	node.step_fade(0.1)
	node.set_mode(MapModes.Mode.RELIEF)
	assert_false(node.is_fading() or node.visible, "hidden at once: no group")
	node.apply_zoom(1.0, 0.65)
	node.set_mode(MapModes.Mode.TERRAIN)
	assert_eq(node.apply_zoom(1.0, 0.65), 0.0, "a zoom in a data mode is not faded later")
	node.set_options(true, true, false, false, false)
	node.apply_zoom(0.65, 0.65)
	node.set_options(true, true, false, false, true)
	assert_eq(node.apply_zoom(0.65, 0.65), 1.0, "switched on: at once")
	node.set_instant(true)
	assert_eq(node.apply_zoom(1.0, 0.65), 0.0, "reduce motion")
	assert_eq(node.apply_zoom(0.65, 0.65), 1.0)
	node.set_instant(false)
	node.begin(EconomyFixture.game(&"GEN"))
	assert_eq(node.apply_zoom(1.0, 0.65), 0.0, "a new game: at once")
