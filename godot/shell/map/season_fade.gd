## The fade between two seasons of the map (docs/architecture/m3-build-spec.md 6.9 and 10): a CanvasLayer at layer 9, under
## the HUD's 10. The PRIMARY method captures the viewport before the swap, shows it over the new season at alpha 1 and
## tweens it away in 0.4 s. The FALLBACK (spec 10, for a driver that cannot read the screen) takes the world's modulate to
## Tokens.BG and back, 0.2 s each way. METHOD picks one; the planner flips it if the capture probe fails on a real window.
## Headless, or under reduce motion, nothing happens at all.
class_name SeasonFade
extends CanvasLayer

signal finished

enum Method { PRIMARY, FALLBACK }

## The method in use; flip to Method.FALLBACK if the viewport capture is empty or slow on a driver.
const METHOD := Method.PRIMARY
const LAYER_INDEX := 9
const DURATION := 0.4
## A capture (the forced draw, the read of the picture, the texture) that takes longer than this many ms freezes the game at
## every season end: the fade then uses the FALLBACK from the next season on (tools/ui/perf_ui.gd measures the capture).
const SLOW_CAPTURE_MS := 60.0

## The method this fade uses (a test may change it).
var method: Method = METHOD
## True under reduce motion: no fade (the scene sets it from the setting).
var reduce_motion := false
## A test may switch the headless skip off (the fallback then runs; the capture finds no image and does nothing).
var run_headless := false
## The node the fallback modulates (the map scene).
var world: CanvasItem = null

## The cost of the last capture in ms (0 before the first, or when none was taken).
var last_capture_ms := 0.0

var _rect: TextureRect = null
var _tween: Tween = null


func _init() -> void:
	layer = LAYER_INDEX
	_rect = TextureRect.new()
	_rect.name = "Capture"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.visible = false
	add_child(_rect)


## True when no fade is done: headless, or reduce motion.
func skipped() -> bool:
	return reduce_motion or (DisplayServer.get_name() == "headless" and not run_headless)


## Call before the swap. PRIMARY: the viewport's picture covers the screen. FALLBACK: the world fades to the background.
func capture() -> void:
	_stop()
	if skipped():
		return
	if method == Method.FALLBACK:
		if world != null:
			_tween = create_tween()
			_tween.tween_property(world, "modulate", Tokens.BG, DURATION / 2.0)
			await _tween.finished
		return
	var started := SimClock.usec()
	RenderingServer.force_draw(false)  # not `await frame_post_draw`: low-processor mode draws no idle frames
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	_rect.texture = ImageTexture.create_from_image(image)
	_rect.modulate.a = 1.0
	_rect.visible = true
	note_capture_cost(float(SimClock.usec() - started) / 1000.0)


## Records a capture's cost; a capture over SLOW_CAPTURE_MS makes the fade use the FALLBACK from then on.
func note_capture_cost(ms: float) -> void:
	last_capture_ms = ms
	if ms > SLOW_CAPTURE_MS and method == Method.PRIMARY:
		method = Method.FALLBACK


## Call after the swap has begun: the picture fades away (or the world comes back) and `finished` is emitted.
func fade_out() -> void:
	if skipped():
		finished.emit()
		return
	_tween = create_tween()
	if method == Method.FALLBACK:
		if world != null:
			_tween.tween_property(world, "modulate", Color.WHITE, DURATION / 2.0)
	elif _rect.visible:
		_tween.tween_property(_rect, "modulate:a", 0.0, DURATION)
		_tween.tween_callback(_rect.hide)
	_tween.tween_callback(finished.emit)


## True while a picture covers the screen or a tween runs.
func is_fading() -> bool:
	return _rect.visible or (_tween != null and _tween.is_running())


func _stop() -> void:
	if _tween != null:
		_tween.kill()
	_rect.visible = false
	if world != null:
		world.modulate = Color.WHITE
