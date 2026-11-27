## Tests for ZoomModel (docs/architecture/ui-and-controls-spec.md sections 4.3, 4.4 and 9).
extends GutTest

const VIEW_720 := Vector2(1280.0, 720.0)
# North Italy: 21 cols x 22 rows -> (21.5 * 104, 22 * 76.5 + 25.5) = (2236, 1708.5)
const NORTH_ITALY_SIZE := Vector2(2236.0, 1708.5)
# Fake Europe: 494 cols x 247 rows -> (494.5 * 104, 247 * 76.5 + 25.5) = (51428, 18921)
const EUROPE_SIZE := Vector2(51428.0, 18921.0)


func test_fit_and_min_zoom_for_north_italy_and_europe() -> void:
	assert_eq(ZoomModel.ZOOM_MAX, 2.0)
	var fit_italy := ZoomModel.fit_zoom(VIEW_720, NORTH_ITALY_SIZE)
	var min_italy := ZoomModel.min_zoom(VIEW_720, NORTH_ITALY_SIZE)
	assert_almost_eq(fit_italy, 0.4045, 0.01, "North Italy fit zoom at 1280x720 is ~0.40")
	assert_almost_eq(min_italy, fit_italy * 0.65, 0.001, "min_zoom is fit * 0.65 (~0.26)")
	assert_gt(min_italy, ZoomModel.ZOOM_FAR_OFF, "North Italy never reaches the far picture at 1280x720")

	var fit_europe := ZoomModel.fit_zoom(VIEW_720, EUROPE_SIZE)
	var min_europe := ZoomModel.min_zoom(VIEW_720, EUROPE_SIZE)
	assert_almost_eq(fit_europe, 0.0239, 0.002)
	assert_almost_eq(min_europe, 0.0155, 0.001, "Fake Europe min zoom is ~0.016")
	assert_lt(min_europe, ZoomModel.ZOOM_FAR_ON, "Fake Europe reaches the far picture")


func test_clamp_zoom_and_tiny_map_cap_at_zoom_max() -> void:
	var tiny_map := Vector2(200.0, 150.0)
	assert_eq(ZoomModel.fit_zoom(VIEW_720, tiny_map), ZoomModel.ZOOM_MAX)
	assert_eq(ZoomModel.min_zoom(VIEW_720, tiny_map), ZoomModel.ZOOM_MAX * ZoomModel.MIN_MARGIN)
	assert_eq(ZoomModel.clamp_zoom(5.0, VIEW_720, NORTH_ITALY_SIZE), ZoomModel.ZOOM_MAX)
	assert_eq(ZoomModel.clamp_zoom(0.01, VIEW_720, NORTH_ITALY_SIZE), ZoomModel.min_zoom(VIEW_720, NORTH_ITALY_SIZE))
	assert_eq(ZoomModel.fit_zoom(Vector2.ZERO, NORTH_ITALY_SIZE), 1.0)
	assert_eq(ZoomModel.fit_zoom(VIEW_720, Vector2.ZERO), 1.0)


func test_notch_factor_handles_zero_factor_and_speed_bounds() -> void:
	assert_almost_eq(ZoomModel.notch_factor(100.0, 1.0), 1.15, 1.0e-5)
	assert_almost_eq(ZoomModel.notch_factor(100.0, 0.0), 1.15, 1.0e-5, "event factor 0 is treated as 1")
	assert_almost_eq(ZoomModel.notch_factor(100.0, 2.0), 1.15 * 1.15, 1.0e-5)
	assert_almost_eq(ZoomModel.notch_factor(200.0, 1.0), 1.15 * 1.15, 1.0e-5)
	assert_almost_eq(ZoomModel.notch_factor(50.0, 1.0), sqrt(1.15), 1.0e-5)
	assert_almost_eq(ZoomModel.notch_factor(10.0, 1.0), sqrt(1.15), 1.0e-5, "clamped at 50%")
	assert_almost_eq(ZoomModel.notch_factor(500.0, 1.0), 1.15 * 1.15, 1.0e-5, "clamped at 200%")


func test_zoom_about_keeps_map_point_under_pointer_fixed() -> void:
	var centre := Vector2(1100.0, 850.0)
	var offset := Vector2(240.0, -135.0)
	var z0 := 0.65
	var z1 := 1.45
	var before_map_pt := centre + offset / z0
	var new_centre := ZoomModel.zoom_about(centre, z0, z1, offset)
	var after_map_pt := new_centre + offset / z1
	assert_almost_eq(after_map_pt.x, before_map_pt.x, 1.0e-4, "map X under pointer stays fixed")
	assert_almost_eq(after_map_pt.y, before_map_pt.y, 1.0e-4, "map Y under pointer stays fixed")
	assert_eq(ZoomModel.zoom_about(centre, z0, z1, Vector2.ZERO), centre, "screen centre anchor keeps centre")


func test_step_smooth_converges_and_snaps_on_reduce_motion() -> void:
	assert_eq(ZoomModel.step_smooth(0.5, 1.5, 0.016, true, true), 1.5, "reduce_motion snaps immediately")
	assert_eq(ZoomModel.step_smooth(0.5, 1.5, 0.016, false, false), 1.5, "smoothing off snaps immediately")
	assert_eq(ZoomModel.step_smooth(1.0, 1.0005, 0.016, false, true), 1.0005, "within SNAP_EPS snaps immediately")

	var z := 0.5
	var target := 1.5
	var anchor := Vector2(180.0, -90.0)
	var centre := Vector2(1000.0, 800.0)
	var map_pt_initial := centre + anchor / z
	var frames := 0
	while z != target and frames < 120:
		var next_z := ZoomModel.step_smooth(z, target, 1.0 / 60.0, false, true)
		centre = ZoomModel.zoom_about(centre, z, next_z, anchor)
		z = next_z
		frames += 1
	assert_eq(z, target, "converges and snaps to exact target")
	assert_lt(frames, 60, "converges within a second at 60 fps")
	var map_pt_final := centre + anchor / z
	assert_almost_eq(map_pt_final.x, map_pt_initial.x, 1.0e-3, "anchor point held across smooth steps")
	assert_almost_eq(map_pt_final.y, map_pt_initial.y, 1.0e-3, "anchor point held across smooth steps")


func test_clamp_centre_and_clamp_centre_for_view() -> void:
	assert_eq(ZoomModel.clamp_centre(Vector2(-50.0, 2000.0), NORTH_ITALY_SIZE), Vector2(0.0, NORTH_ITALY_SIZE.y))
	assert_eq(ZoomModel.clamp_centre(Vector2(500.0, 600.0), NORTH_ITALY_SIZE), Vector2(500.0, 600.0))
	assert_eq(ZoomModel.clamp_centre(Vector2(100.0, 100.0), Vector2.ZERO), Vector2.ZERO)

	# When zoomed out so map * zoom <= free_size on both axes, centres on map_size / 2
	var small_zoom := 0.4
	assert_eq(
		ZoomModel.clamp_centre_for_view(Vector2(100.0, 100.0), small_zoom, VIEW_720, NORTH_ITALY_SIZE),
		NORTH_ITALY_SIZE * 0.5
	)
	# When zoomed in so map * zoom > free_size, clamps inside [0, map_size]
	assert_eq(
		ZoomModel.clamp_centre_for_view(Vector2(100.0, 100.0), 1.0, VIEW_720, NORTH_ITALY_SIZE),
		Vector2(100.0, 100.0)
	)
	assert_eq(
		ZoomModel.clamp_centre_for_view(Vector2(-20.0, 5000.0), 1.0, VIEW_720, NORTH_ITALY_SIZE),
		Vector2(0.0, NORTH_ITALY_SIZE.y)
	)


func test_grid_alpha_and_scale_for_ui_change() -> void:
	assert_eq(ZoomModel.grid_alpha(0.50, 0.8), 0.8)
	assert_eq(ZoomModel.grid_alpha(0.45, 0.8), 0.8)
	assert_eq(ZoomModel.grid_alpha(0.30, 0.8), 0.0)
	assert_eq(ZoomModel.grid_alpha(0.20, 0.8), 0.0)
	assert_almost_eq(ZoomModel.grid_alpha(0.375, 0.8), 0.4, 1.0e-5)

	assert_almost_eq(ZoomModel.scale_for_ui_change(1.0, 1.0, 2.0), 0.5, 1.0e-5)
	assert_almost_eq(ZoomModel.scale_for_ui_change(0.5, 2.0, 1.0), 1.0, 1.0e-5)
	assert_eq(ZoomModel.scale_for_ui_change(1.0, 0.0, 2.0), 1.0)
