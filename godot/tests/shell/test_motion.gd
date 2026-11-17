## Tests for UI motion helpers (docs/architecture/ui-style-and-feedback-spec.md sections 4.11 and 11).
extends GutTest


func after_each() -> void:
	get_tree().paused = false


func _make_control(size := Vector2(64.0, 64.0)) -> Control:
	var node := Control.new()
	node.size = size
	add_child_autofree(node)
	return node


func test_hover_glow_animates_and_respects_reduce_motion() -> void:
	var glow := _make_control()
	glow.modulate.a = 0.0

	var reduced_in := Motion.hover_glow(glow, true, true)
	assert_null(reduced_in, "reduce_motion returns null")
	assert_almost_eq(glow.modulate.a, 1.0, 0.001, "hot sets alpha 1.0 immediately")

	var reduced_out := Motion.hover_glow(glow, false, true)
	assert_null(reduced_out, "reduce_motion returns null on exit")
	assert_almost_eq(glow.modulate.a, 0.0, 0.001, "cold sets alpha 0.0 immediately")

	var tween := Motion.hover_glow(glow, true, false)
	assert_not_null(tween, "normal motion returns a Tween")
	assert_true(tween.is_valid(), "tween is valid")
	tween.pause()
	tween.custom_step(0.20)
	assert_almost_eq(glow.modulate.a, 1.0, 0.001, "tween reaches 1.0 after 120 ms")
	tween.kill()


func test_press_seal_animates_from_overscale_and_respects_reduce_motion() -> void:
	var seal := _make_control(Vector2(72.0, 72.0))
	seal.scale = Vector2(2.0, 2.0)
	seal.modulate.a = 0.2

	var reduced := Motion.press_seal(seal, true)
	assert_null(reduced, "reduce_motion returns null")
	assert_eq(seal.pivot_offset, Vector2(36.0, 36.0), "pivot set to centre")
	assert_almost_eq(seal.scale.x, 1.0, 0.001, "scale set to 1.0 immediately")
	assert_almost_eq(seal.scale.y, 1.0, 0.001, "scale set to 1.0 immediately")
	assert_almost_eq(seal.modulate.a, 1.0, 0.001, "alpha set to 1.0 immediately")

	var tween := Motion.press_seal(seal, false)
	assert_not_null(tween, "normal motion returns a Tween")
	assert_eq(seal.pivot_offset, Vector2(36.0, 36.0), "pivot set to centre")
	assert_almost_eq(seal.scale.x, 1.15, 0.001, "starts at scale 1.15")
	assert_almost_eq(seal.modulate.a, 0.0, 0.001, "starts at alpha 0.0")
	tween.pause()
	tween.custom_step(0.06)
	assert_almost_eq(seal.modulate.a, 1.0, 0.01, "alpha reaches 1.0 at 60 ms")
	tween.custom_step(0.20)
	assert_almost_eq(seal.scale.x, 1.0, 0.001, "scale settles at 1.0 by 180 ms")
	tween.kill()


func test_enter_slides_and_fades_and_runs_while_paused() -> void:
	var frame := _make_control(Vector2(400.0, 300.0))
	frame.modulate.a = 0.0
	frame.position.y = 24.0

	var reduced := Motion.enter(frame, true)
	assert_null(reduced, "reduce_motion returns null")
	assert_almost_eq(frame.modulate.a, 1.0, 0.001, "alpha 1.0 immediately")
	assert_almost_eq(frame.position.y, 0.0, 0.001, "position.y 0.0 immediately")

	get_tree().paused = true
	var tween := Motion.enter(frame, false)
	assert_not_null(tween, "normal motion returns a Tween")
	assert_almost_eq(frame.modulate.a, 0.0, 0.001, "starts at alpha 0.0")
	assert_almost_eq(frame.position.y, 6.0, 0.001, "starts at +6.0 px offset")
	await get_tree().process_frame
	tween.pause()
	tween.custom_step(0.20)
	assert_almost_eq(frame.modulate.a, 1.0, 0.001, "alpha reaches 1.0 under pause")
	assert_almost_eq(frame.position.y, 0.0, 0.001, "position.y reaches 0.0 under pause")
	tween.kill()


func test_cross_fade_hides_outgoing_page_and_respects_reduce_motion() -> void:
	var out_page := _make_control()
	var in_page := _make_control()
	out_page.visible = true
	in_page.visible = false

	var reduced := Motion.cross_fade(out_page, in_page, true)
	assert_null(reduced, "reduce_motion returns null")
	assert_false(out_page.visible, "out_node hidden immediately under reduce_motion")
	assert_almost_eq(out_page.modulate.a, 0.0, 0.001, "out_node alpha 0.0")
	assert_true(in_page.visible, "in_node visible immediately")
	assert_almost_eq(in_page.modulate.a, 1.0, 0.001, "in_node alpha 1.0")

	out_page.visible = true
	out_page.modulate.a = 1.0
	in_page.visible = false
	var tween := Motion.cross_fade(out_page, in_page, false)
	assert_not_null(tween, "normal motion returns a Tween")
	assert_true(in_page.visible, "in_node shown at start of cross-fade")
	assert_almost_eq(in_page.modulate.a, 0.0, 0.001, "in_node starts at alpha 0.0")
	assert_almost_eq(out_page.modulate.a, 1.0, 0.001, "out_node starts at alpha 1.0")
	tween.pause()
	tween.custom_step(0.20)
	assert_almost_eq(in_page.modulate.a, 1.0, 0.001, "in_node reaches alpha 1.0")
	assert_almost_eq(out_page.modulate.a, 0.0, 0.001, "out_node reaches alpha 0.0")
	assert_false(out_page.visible, "out_node hidden after cross-fade")
	tween.kill()


func test_looping_helpers_spin_ring_drift_map_and_spin_rose() -> void:
	var ring := _make_control(Vector2(64.0, 64.0))
	ring.rotation = 1.2
	assert_null(Motion.spin_ring(ring, true), "spin_ring reduce_motion returns null")
	assert_almost_eq(ring.rotation, 0.0, 0.001, "spin_ring resets rotation to 0.0")

	var ring_tween := Motion.spin_ring(ring, false)
	assert_not_null(ring_tween, "spin_ring returns a Tween")
	ring_tween.pause()
	ring_tween.custom_step(1.0)
	assert_almost_eq(ring.rotation, PI, 0.05, "spin_ring turns half a circle in 1.0 s")
	ring_tween.kill()

	var bg := _make_control(Vector2(1920.0, 1080.0))
	bg.scale = Vector2(1.2, 1.2)
	assert_null(Motion.drift_map(bg, true), "drift_map reduce_motion returns null")
	assert_eq(bg.scale, Vector2.ONE, "drift_map resets scale to 1.0")

	var bg_tween := Motion.drift_map(bg, false)
	assert_not_null(bg_tween, "drift_map returns a Tween")
	bg_tween.pause()
	bg_tween.custom_step(70.0)
	assert_almost_eq(bg.scale.x, 1.06, 0.01, "drift_map reaches 1.06 at 70 s")
	bg_tween.kill()

	var rose := _make_control(Vector2(512.0, 512.0))
	rose.rotation = 0.8
	assert_null(Motion.spin_rose(rose, true), "spin_rose reduce_motion returns null")
	assert_almost_eq(rose.rotation, 0.0, 0.001, "spin_rose resets rotation to 0.0")

	var rose_tween := Motion.spin_rose(rose, false)
	assert_not_null(rose_tween, "spin_rose returns a Tween")
	rose_tween.pause()
	rose_tween.custom_step(60.0)
	assert_almost_eq(rose.rotation, PI, 0.05, "spin_rose turns half a circle in 60 s")
	rose_tween.kill()
