## UI motion helpers (docs/architecture/ui-style-and-feedback-spec.md section 4.11; docs/design/ui/design.md section 7).
##
## Every UI tween is created here: bound to its node, running while the SceneTree is paused (`Tween.TWEEN_PAUSE_PROCESS`),
## and animating only `modulate`, `position`, `scale` or `rotation` (no shaders). When `reduce_motion` is true, each
## helper sets the final state at once and returns `null`.
class_name Motion
extends RefCounted

const HOVER_DURATION := 0.12
const ENTER_DURATION := 0.12
const ENTER_OFFSET_Y := 6.0
const CROSS_FADE_DURATION := 0.12
const SEAL_SCALE_DURATION := 0.18
const SEAL_ALPHA_DURATION := 0.06
const SEAL_START_SCALE := 1.15
const RING_TURN_DURATION := 2.0
const DRIFT_HALF_DURATION := 70.0
const DRIFT_SCALE := 1.06
const ROSE_TURN_DURATION := 120.0
const LOG_SLIDE_PX := 48.0
const LOG_SLIDE_DURATION := 0.16


## Slides the action log's card up from `LOG_SLIDE_PX` below its rest height `rest_y` while it fades in (opening), or down
## to it while it fades out (closing). When `reduce_motion` is true it sets the final state at once and returns `null`.
static func log_sheet(sheet: Control, rest_y: float, opening: bool, reduce_motion: bool = false) -> Tween:
	if reduce_motion or SimClock.fixed():
		sheet.position.y = rest_y
		sheet.modulate.a = 1.0 if opening else 0.0
		return null
	var from_y := rest_y + LOG_SLIDE_PX if opening else rest_y
	var to_y := rest_y if opening else rest_y + LOG_SLIDE_PX
	sheet.position.y = from_y
	sheet.modulate.a = 0.0 if opening else 1.0
	var tween := _make_tween(sheet)
	tween.set_parallel(true)
	tween.tween_property(sheet, "position:y", to_y, LOG_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sheet, "modulate:a", 1.0 if opening else 0.0, LOG_SLIDE_DURATION)
	return tween


## Fades a lazy `Glow` child in (1.0) on hover/focus or out (0.0) on exit over 120 ms.
static func hover_glow(glow_node: Control, hot: bool, reduce_motion: bool = false) -> Tween:
	var target_alpha := 1.0 if hot else 0.0
	if reduce_motion or SimClock.fixed():
		glow_node.modulate.a = target_alpha
		return null
	var tween := _make_tween(glow_node)
	tween.tween_property(glow_node, "modulate:a", target_alpha, HOVER_DURATION)
	return tween


## Presses a wax seal into the sheet: pivot at the centre, scale 1.15 -> 1.0 in 180 ms (cubic out),
## and alpha 0.0 -> 1.0 in the first 60 ms.
static func press_seal(seal_node: Control, reduce_motion: bool = false) -> Tween:
	seal_node.pivot_offset = seal_node.size * 0.5
	if reduce_motion or SimClock.fixed():
		seal_node.scale = Vector2.ONE
		seal_node.modulate.a = 1.0
		return null
	seal_node.scale = Vector2(SEAL_START_SCALE, SEAL_START_SCALE)
	seal_node.modulate.a = 0.0
	var tween := _make_tween(seal_node)
	tween.set_parallel(true)
	tween.tween_property(seal_node, "scale", Vector2.ONE, SEAL_SCALE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(seal_node, "modulate:a", 1.0, SEAL_ALPHA_DURATION)
	return tween


## Enters a modal or panel frame: alpha 0.0 -> 1.0 and `position.y` +6.0 -> 0.0 over 120 ms.
static func enter(frame_node: Control, reduce_motion: bool = false) -> Tween:
	if reduce_motion or SimClock.fixed():
		frame_node.modulate.a = 1.0
		frame_node.position.y = 0.0
		return null
	frame_node.modulate.a = 0.0
	frame_node.position.y = ENTER_OFFSET_Y
	var tween := _make_tween(frame_node)
	tween.set_parallel(true)
	tween.tween_property(frame_node, "modulate:a", 1.0, ENTER_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(frame_node, "position:y", 0.0, ENTER_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	return tween


## Cross-fades two pages sharing a plain parent `Control` over 120 ms, then hides `out_node`. `keep_visible` (optional, a
## Callable taking a node) names a node the end of the fade must not hide: a later switch may have brought it back into view.
static func cross_fade(out_node: CanvasItem, in_node: CanvasItem, reduce_motion: bool = false, keep_visible: Callable = Callable()) -> Tween:
	if reduce_motion or SimClock.fixed():
		if out_node != null and out_node != in_node:
			out_node.modulate.a = 0.0
			out_node.visible = false
		if in_node != null:
			in_node.visible = true
			in_node.modulate.a = 1.0
		return null
	if in_node != null:
		in_node.visible = true
		in_node.modulate.a = 0.0
	if out_node != null and out_node != in_node:
		out_node.visible = true
		out_node.modulate.a = 1.0
	var host: Node = in_node if in_node != null else out_node
	if host == null:
		return null
	var tween := _make_tween(host)
	tween.set_parallel(true)
	if out_node != null and out_node != in_node:
		tween.tween_property(out_node, "modulate:a", 0.0, CROSS_FADE_DURATION)
	if in_node != null:
		tween.tween_property(in_node, "modulate:a", 1.0, CROSS_FADE_DURATION)
	if out_node != null and out_node != in_node:
		tween.chain().tween_callback(_hide_unless.bind(out_node, keep_visible))
	return tween


## Spins the End-season medallion ring once every 2.0 s while busy.
static func spin_ring(ring_node: Control, reduce_motion: bool = false) -> Tween:
	ring_node.pivot_offset = ring_node.size * 0.5
	ring_node.rotation = 0.0
	if reduce_motion or SimClock.fixed():
		return null
	var tween := _make_tween(ring_node)
	tween.set_loops()
	tween.tween_property(ring_node, "rotation", TAU, RING_TURN_DURATION).from(0.0)
	return tween


## Drifts the main-menu map backdrop between scale 1.0 and 1.06 over 70 s each way.
static func drift_map(bg_node: Control, reduce_motion: bool = false) -> Tween:
	bg_node.pivot_offset = bg_node.size * 0.5
	bg_node.scale = Vector2.ONE
	if reduce_motion or SimClock.fixed():
		return null
	var tween := _make_tween(bg_node)
	tween.set_loops()
	tween.tween_property(bg_node, "scale", Vector2(DRIFT_SCALE, DRIFT_SCALE), DRIFT_HALF_DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(bg_node, "scale", Vector2.ONE, DRIFT_HALF_DURATION).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	return tween


## Gently oscillates the main-menu compass rose +/-3.5 deg around true North.
static func wiggle_rose(rose_node: Control, reduce_motion: bool = false) -> Tween:
	rose_node.pivot_offset = rose_node.size * 0.5
	rose_node.rotation = 0.0
	if reduce_motion or SimClock.fixed():
		return null
	var amp := deg_to_rad(3.5)
	var tween := _make_tween(rose_node)
	tween.set_loops()
	tween.tween_property(rose_node, "rotation", amp, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(rose_node, "rotation", -amp * 0.7, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(rose_node, "rotation", 0.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## Slowly rotates the main-menu wind rose once every 120 s.
static func spin_rose(rose_node: Control, reduce_motion: bool = false) -> Tween:
	rose_node.pivot_offset = rose_node.size * 0.5
	rose_node.rotation = 0.0
	if reduce_motion or SimClock.fixed():
		return null
	var tween := _make_tween(rose_node)
	tween.set_loops()
	tween.tween_property(rose_node, "rotation", TAU, ROSE_TURN_DURATION).from(0.0)
	return tween


## The end of a fade: hides `node` unless `keep` says it is the one in view now.
static func _hide_unless(node: CanvasItem, keep: Callable) -> void:
	if node == null or not is_instance_valid(node):
		return
	if keep.is_valid() and bool(keep.call(node)):
		return
	node.hide()


static func _make_tween(node: Node) -> Tween:
	var tween: Tween = null
	if node.is_inside_tree():
		tween = node.create_tween()
	else:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tween = tree.create_tween()
			tween.bind_node(node)
	if tween != null:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween
