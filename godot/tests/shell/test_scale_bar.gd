## GUT tests for ScaleBar step selection and custom rendering
## (docs/architecture/ui-and-controls-spec.md section 7; ui-style-and-feedback-plan.md U14).
extends GutTest


func test_pick_selects_nice_steps_across_zoom_range_and_bounds() -> void:
	var zooms: Array[float] = [0.022, 0.05, 0.1, 0.25, 0.4, 0.75, 1.0, 1.5, 2.0]
	for z: float in zooms:
		var km_per_px := 28.0 / (float(MapTiles.CELL.x) * z)
		var picked := ScaleBar.pick(km_per_px, ScaleBar.DEFAULT_MAX_PX)
		var km := int(picked["km"])
		var px := float(picked["px"])
		var label := str(picked["label"])
		assert_true(ScaleBar.STEPS_KM.has(km), "step %d is in STEPS_KM at zoom %.3f" % [km, z])
		assert_gt(px, 0.0, "non-zero width at zoom %.3f" % z)
		assert_lte(px, ScaleBar.DEFAULT_MAX_PX + 0.01, "fits within max_px at zoom %.3f" % z)
		assert_eq(label, "%d km" % km, "clean km label at zoom %.3f" % z)

	# Specific expected picks for 28 km per 104 px cell with 120 px max width:
	# zoom 1.0 -> km_per_px = 28/104 = 0.2692 -> 25 km = 92.86 px (50 km = 185.7 px > 120)
	var at_one := ScaleBar.pick_for_pixels_per_hex(float(MapTiles.CELL.x) * 1.0)
	assert_eq(at_one["km"], 25)
	assert_eq(at_one["label"], "25 km")

	# zoom 2.0 -> km_per_px = 0.1346 -> 10 km = 74.29 px (20 km = 148.57 px > 120)
	var at_two := ScaleBar.pick_for_pixels_per_hex(float(MapTiles.CELL.x) * 2.0)
	assert_eq(at_two["km"], 10)
	assert_eq(at_two["label"], "10 km")

	# zoom 0.40 (North Italy fit) -> km_per_px = 0.673 -> 50 km = 74.29 px (100 km = 148.57 > 120)
	var at_fit := ScaleBar.pick_for_pixels_per_hex(float(MapTiles.CELL.x) * 0.40)
	assert_eq(at_fit["km"], 50)
	assert_eq(at_fit["label"], "50 km")

	# Edge cases
	var zero_km := ScaleBar.pick(0.0, 120.0)
	assert_eq(zero_km["km"], ScaleBar.STEPS_KM[0])
	assert_eq(zero_km["px"], 0.0)
	var zero_max := ScaleBar.pick(0.5, 0.0)
	assert_eq(zero_max["px"], 0.0)


func test_scale_bar_node_updates_and_draws_without_blocking_mouse() -> void:
	var harness := UIHarness.new()
	harness.mount(self)
	var bar := ScaleBar.new()
	bar.theme = KitTheme.load_for(1.0)
	bar.set_zoom(1.0)
	harness.viewport.add_child(bar)
	await harness.wait_frames(self, 2)

	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(bar.current_km(), 25)
	assert_eq(bar.current_label(), "25 km")
	assert_gt(bar.current_px(), 0.0)
	assert_lte(bar.current_px(), ScaleBar.DEFAULT_MAX_PX)

	bar.set_pixels_per_hex(float(MapTiles.CELL.x) * 0.40)
	assert_eq(bar.current_km(), 50)
	assert_eq(bar.current_label(), "50 km")
