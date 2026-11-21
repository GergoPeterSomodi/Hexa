## The M5 rows of tools/ui/perf_ui.gd (m5-build-spec.md section 8), split out like perf_ui_m45.gd. Run on the Genoa game the M4.5
## rows played (north Italy after 40 seasons), after them. A call is timed with one forced draw after it (RenderingServer.force_draw:
## the project runs in low-processor mode, so no frame is awaited). Rows (written into the result dictionary):
##   people_page_open_ms   the People page opened with the game's view cache cleared (cold), worst of 3, the call and one forced
##                         draw (the first build of its nodes is reported apart: people_page_first_build_ms)
##   food_mode_ms          key 5 to the first Food frame, the view cache cleared, worst of 3
## `chips_refresh_ms` (M4) is the existing row: Chips.refresh now rebuilds four chips and their cards. Everything of the shell is
## reached through call() and get(): perf_ui compiles before the autoloads. Headless the same calls run on the dummy renderer and
## the gpu rows are reported, not enforced.
extends RefCounted

const RUNS := 3

var _tree: SceneTree = null
var _r: Dictionary = {}


func _init(tree: SceneTree, result: Dictionary) -> void:
	_tree = tree
	_r = result


func _frames(n: int) -> void:
	for _i: int in range(n):
		await _tree.process_frame


func _key(vp: SubViewport, key: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = pressed
		vp.push_input(ev)


## The two rows, in the running Genoa game of `app` after the M4.5 rows.
func measure(app: Node, vp: SubViewport) -> void:
	var session := _tree.root.get_node("Session")
	var g: Game = session.get("game") as Game
	var ms := app.call("map_scene") as Node
	var works: Object = (app.call("requests") as Object).get("works")
	if g == null or ms == null or works == null or not g.has_countries() or g.player == &"":
		printerr("perf_ui: the M5 country game did not start")
		_r["people_page_open_ms"] = INF
		_r["food_mode_ms"] = INF
		return
	await _measure_page(works, g)
	await _measure_food(vp, ms, g)


func _measure_page(works: Object, g: Game) -> void:
	var open := func() -> void: works.call("open_study", &"people", {})
	var close := func() -> void: works.call("close_study")
	var t0 := Time.get_ticks_usec()
	open.call()
	RenderingServer.force_draw(false)
	_r["people_page_first_build_ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	close.call()
	await _frames(2)
	var worst := 0.0
	for _i: int in RUNS:
		g.view_cache.clear()
		var t1 := Time.get_ticks_usec()
		open.call()
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t1) / 1000.0)
		close.call()
		await _frames(2)
	_r["people_page_open_ms"] = worst


func _measure_food(vp: SubViewport, ms: Node, g: Game) -> void:
	var worst := 0.0
	var food := int(MapModes.Mode.FOOD)
	for _i: int in RUNS:
		g.view_cache.clear()
		var t0 := Time.get_ticks_usec()
		_key(vp, KEY_5)
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		if int(ms.call("mode")) != food:
			printerr("perf_ui: key 5 did not set Food")
			worst = INF
		_key(vp, KEY_1)
		await _frames(3)
	_r["food_mode_ms"] = worst
