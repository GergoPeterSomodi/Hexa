## Viewport-capture probe (docs/architecture/m3-build-spec.md section 10; M3 task Y8).
## Run WINDOWED on the owner's Mac (Compatibility driver) and Windows, from the repository root:
##   godot --path godot -s res://tools/ui/probe_capture.gd
## It draws four coloured blocks, forces a draw (RenderingServer.force_draw: low-processor mode draws no idle frame, so frame_post_draw would never come), copies the viewport and checks: the image is
## not empty, has the window's size, each block's centre pixel has its colour; it times the capture (5 runs) and runs
## Thumbnail.take once (a CanvasLayer hidden during the copy must be absent from it). Prints PASS or FAIL per check and
## "probe_capture: RESULT PASS|FAIL"; exits 0 on PASS, 1 on FAIL. Headless it prints SKIP and exits 0.
## On a FAIL set Thumbnail.MODE to Thumbnail.TEXTURE (the fallback of section 10) and report the failing lines.
extends SceneTree

const BLOCKS: Array[Color] = [Color(0.9, 0.1, 0.1), Color(0.1, 0.8, 0.1), Color(0.1, 0.2, 0.9), Color(0.95, 0.9, 0.1)]
const TOLERANCE := 0.06
## A capture slower than this is reported as a FAIL: a save would stall.
const SLOW_MS := 250.0

var _fails := 0


## A stage that never finishes (a frame that is never drawn) is itself a FAIL: the watchdog says which one.
const WATCHDOG_SEC := 20.0

var _stage := "start"


func _initialize() -> void:
	create_timer(WATCHDOG_SEC).timeout.connect(_on_watchdog)
	_run()


func _on_watchdog() -> void:
	print("probe_capture: FAIL stuck at stage '%s' after %.0f s (the frame never came)" % [_stage, WATCHDOG_SEC])
	print("probe_capture: RESULT FAIL")
	quit(1)


func _run() -> void:
	await process_frame
	var driver := RenderingServer.get_current_rendering_driver_name()
	print("probe_capture: platform=%s driver=%s display=%s" % [OS.get_name(), driver, DisplayServer.get_name()])
	if DisplayServer.get_name() == "headless":
		print("probe_capture: SKIP (headless has no screen to read; run windowed)")
		quit(0)
		return
	_stage = "build blocks"
	var holder := Node2D.new()
	root.add_child(holder)
	var size := root.size
	var half := Vector2(size) / 2.0
	var centres: Array[Vector2i] = []
	for i: int in 4:
		var block := ColorRect.new()
		block.color = BLOCKS[i]
		block.size = half
		block.position = Vector2(half.x * float(i % 2), half.y * float(floori(float(i) / 2.0)))
		holder.add_child(block)
		centres.append(Vector2i(block.position + half / 2.0))
	var layer := CanvasLayer.new()
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.size = Vector2(size)
	layer.add_child(cover)
	root.add_child(layer)
	layer.visible = false
	_stage = "process_frame after the blocks"
	await process_frame
	_stage = "force_draw and read"

	var times: Array[float] = []
	var image: Image = null
	for run: int in 5:
		var started := Time.get_ticks_usec()
		RenderingServer.force_draw(false)  # the project is in low-processor mode: no idle frames, no frame_post_draw
		image = root.get_texture().get_image()
		times.append(float(Time.get_ticks_usec() - started) / 1000.0)
	_check(image != null and not image.is_empty(), "capture is not empty")
	if image != null and not image.is_empty():
		print("probe_capture: capture size %s, window %s" % [str(image.get_size()), str(size)])
		var scale_x := float(image.get_width()) / float(size.x)
		var scale_y := float(image.get_height()) / float(size.y)
		for i: int in 4:
			var px := image.get_pixel(int(float(centres[i].x) * scale_x), int(float(centres[i].y) * scale_y))
			_check(_near(px, BLOCKS[i]), "block %d pixel %s is %s" % [i, str(px), str(BLOCKS[i])])
	var worst := 0.0
	var total := 0.0
	for t: float in times:
		worst = maxf(worst, t)
		total += t
	print("probe_capture: capture time mean %.1f ms, worst %.1f ms" % [total / float(times.size()), worst])
	_check(worst < SLOW_MS, "capture worst %.1f ms under %.0f ms" % [worst, SLOW_MS])

	# Thumbnail.take with a covering layer that must be hidden for the copy.
	layer.visible = true
	var hide: Array[CanvasLayer] = [layer]
	var started := Time.get_ticks_usec()
	_stage = "Thumbnail.take"
	var thumb: Image = await Thumbnail.take(root, hide)
	print("probe_capture: Thumbnail.take %.1f ms" % (float(Time.get_ticks_usec() - started) / 1000.0))
	_check(thumb != null and thumb.get_size() == SaveFile.THUMB, "thumbnail is 192 x 108")
	_check(layer.visible, "hidden layer is shown again")
	if thumb != null:
		_check(not _near(thumb.get_pixel(thumb.get_width() >> 1, thumb.get_height() >> 1), Color.BLACK),
				"the hidden layer is not in the thumbnail")
		_check(_near(thumb.get_pixel(thumb.get_width() >> 2, thumb.get_height() >> 2), BLOCKS[0]),
				"thumbnail top-left block is red")
	print("probe_capture: RESULT %s" % ("PASS" if _fails == 0 else "FAIL"))
	quit(0 if _fails == 0 else 1)


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < TOLERANCE and absf(a.g - b.g) < TOLERANCE and absf(a.b - b.b) < TOLERANCE


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("probe_capture: %s %s" % ["PASS" if ok else "FAIL", label])
