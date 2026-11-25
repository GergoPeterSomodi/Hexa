## The tile window rows of tools/ui/perf_ui.gd (tile-window spec section 8, TW18), split out like perf_ui_m7.gd. Run in the game the
## M7 rows played (north Italy as Genoa, after its seasons), on Genoa's own city (the own hex with the most build options) and on
## Savona (an own port: the Ships tab). A call is timed with one forced draw after it (the project runs in low-processor mode, so no
## frame is awaited by the call itself). Rows (written into the result dictionary):
##   tile_window_open_ms    the window shown on the city, the view cache cleared, worst of RUNS (the call and one forced draw)
##   tile_tab_switch_ms     every live tab of Savona shown in turn (the call and one forced draw), worst
##   gain_fill_frame_ms     the worst frame of the Buildings tab's one-row-a-frame gain fill, on the city (frames until pending is 0)
##   raise_screen_open_ms   the RaiseScreen pushed and opened for the city, the call and one forced draw, worst of RUNS
## The shell is reached through call() and get(): perf_ui compiles before the autoloads. Headless the gpu rows are reported, not
## enforced (perf_ui_budget.json's classes).
extends RefCounted

const RUNS := 3
const FILL_GUARD := 400
const ROWS: Array[String] = ["tile_window_open_ms", "tile_tab_switch_ms", "gain_fill_frame_ms", "raise_screen_open_ms"]

var _tree: SceneTree = null
var _r: Dictionary = {}


func _init(tree: SceneTree, result: Dictionary) -> void:
	_tree = tree
	_r = result


func _frames(n: int) -> void:
	for _i: int in n:
		await _tree.process_frame


## Measures the tile rows in the running game. `screen_ids` is the shell's ScreenIds script (its make(id) gives a screen).
func measure(app: Node, screen_ids: GDScript) -> void:
	var session := _tree.root.get_node("Session")
	var g: Game = session.get("game") as Game
	var hud := app.call("hud") as Object
	var stack := app.call("stack") as Object
	if g == null or hud == null or stack == null or not g.has_countries() or g.player == &"":
		printerr("perf_ui: the tile rows need a country game (game %s, hud %s)" % [str(g != null), str(hud != null)])
		for key: String in ROWS:
			_r[key] = INF
		return
	var panel := hud.call("tile_window") as Object
	var city := PerfTileRows._most_options(g, g.player)
	var port := _port_hex(g)
	if city == Vector2i(-1, -1) or port == Vector2i(-1, -1):
		printerr("perf_ui: no own city or port for the tile rows (city %s, port %s)" % [str(city), str(port)])
		for key: String in ROWS:
			_r[key] = INF
		return
	_r["tile_window_open_ms"] = await _open_ms(g, panel, city)
	_r["tile_tab_switch_ms"] = await _tab_switch_ms(g, panel, port)
	_r["gain_fill_frame_ms"] = await _gain_fill_ms(g, panel, city)
	_r["raise_screen_open_ms"] = await _raise_ms(g, stack, screen_ids, city)
	panel.call("clear")
	await _frames(1)


## The own hex of the player with the port flag (TileView's own_port), or (-1, -1).
func _port_hex(g: Game) -> Vector2i:
	var c := Countries.by_tag(g, g.player)
	if c == null:
		return Vector2i(-1, -1)
	for i: int in Territory.districts(g, c.id):
		var hex := g.map.hex_of(i)
		if bool(TileView.of(g, g.player, hex).get("own_port", false)):
			return hex
	return Vector2i(-1, -1)


## The window shown on `hex` with the view cache cleared: the worst of RUNS, in ms.
func _open_ms(g: Game, panel: Object, hex: Vector2i) -> float:
	var worst := 0.0
	for _n: int in RUNS:
		panel.call("clear")
		g.version += 1
		var t0 := Time.get_ticks_usec()
		panel.call("show_hex", hex)
		await _tree.process_frame
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
	return worst


## Each live tab of the port shown in turn (cold each time), the worst call and draw, in ms.
func _tab_switch_ms(g: Game, panel: Object, hex: Vector2i) -> float:
	panel.call("clear")
	g.version += 1
	panel.call("show_hex", hex)
	await _tree.process_frame
	var worst := 0.0
	for id: StringName in panel.call("live_tab_ids") as Array:
		g.version += 1
		var t0 := Time.get_ticks_usec()
		panel.call("show_tab", id)
		await _tree.process_frame
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
	return worst


## The Buildings tab on the city: the worst frame until its gains are all filled (one row a frame), in ms.
func _gain_fill_ms(g: Game, panel: Object, hex: Vector2i) -> float:
	panel.call("clear")
	g.version += 1
	panel.call("show_hex", hex)
	panel.call("show_tab", &"town")
	var tab := panel.call("tab_node") as Object
	if tab == null:
		return INF
	var worst := 0.0
	var guard := 0
	while int(tab.call("pending")) > 0 and guard < FILL_GUARD:
		var t0 := Time.get_ticks_usec()
		await _tree.process_frame
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		guard += 1
	return worst


## The RaiseScreen for the city: pushed, opened for the hex and drawn once; worst of RUNS, in ms.
func _raise_ms(g: Game, stack: Object, screen_ids: GDScript, hex: Vector2i) -> float:
	var worst := 0.0
	for _n: int in RUNS:
		stack.call("clear")
		await _frames(1)
		g.version += 1
		var t0 := Time.get_ticks_usec()
		var screen := screen_ids.call("make", &"raise_screen") as Node
		stack.call("push", screen)
		screen.call("open_for", hex)
		await _tree.process_frame
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
	stack.call("clear")
	await _frames(1)
	return worst
