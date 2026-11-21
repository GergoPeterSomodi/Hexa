## The M4.5 rows of tools/ui/perf_ui.gd (m4-5-build-spec.md section 8, 4.12), split out to keep that script under the lint's 800
## lines. A call is timed with one forced draw after it (RenderingServer.force_draw: the project runs in low-processor mode, so
## no frame is awaited, never frame_post_draw), as the M3 and M4 rows are. Rows (written into the result dictionary):
##   study_open_cold_ms     the worst of the five pages and tabs (Districts, Goods, History tab, Rankings, History) opened with
##                          the game's view cache cleared, north Italy after 40 seasons (the first build of each page's nodes
##                          is reported apart: study_first_build_ms)
##   study_open_europe_ms   the same five on the made-up Europe as its largest country after the warmer ran; skipped headless
##                          (the game takes minutes to build; --europe-seasons=N measures a smaller one)
##   study_tab_switch_ms    Ctrl+] between two tabs already built
##   yields_mode_ms         key 4 to the first Yields frame (the view cache cleared first)
##   yields_update_ms       a work begun in Yields: yield_bytes warm plus update_yields of one changed byte (CPU, mean of 30)
##   study_table_rows_ms    StudyTable.set_rows with 100 rows of 7 columns, two custom-drawn (CPU, worst of 5)
##   timeline_draw_ms       TimelineStrip._draw with 680 seasons and 200 marks (CPU, worst of 5)
##   legend_show_ms         ModeLegend.show_mode for Yields (CPU, mean of 30)
## Everything of the shell is reached through call() and get(): perf_ui compiles before the autoloads. Headless the same calls
## run on the dummy renderer and the gpu rows are reported, not enforced.
extends RefCounted

const SEASONS := 40
const OPEN_RUNS := 3
const SWITCH_RUNS := 6
const CPU_RUNS := 30
const TABLE_RUNS := 5
const TABLE_ROWS := 100
const TIMELINE_SEASONS := 680
const TIMELINE_MARKS := 200
const TAG := &"GEN"
const MILESTONE := "4.5"
const PAGES: Array[Dictionary] = [
	{"name": "districts", "page": &"economy", "focus": {"tab": &"districts"}},
	{"name": "goods", "page": &"economy", "focus": {"tab": &"goods"}},
	{"name": "history_tab", "page": &"economy", "focus": {"tab": &"history"}},
	{"name": "rankings", "page": &"rankings", "focus": {}},
	{"name": "history", "page": &"history", "focus": {}},
]

var _tree: SceneTree = null
var _r: Dictionary = {}


func _init(tree: SceneTree, result: Dictionary) -> void:
	_tree = tree
	_r = result


func _frames(n: int) -> void:
	for _i: int in range(n):
		await _tree.process_frame


## One call, in ms, then one forced draw; `close` runs after and two frames pass.
func _push_ms(open: Callable, close: Callable) -> float:
	var t0 := Time.get_ticks_usec()
	open.call()
	RenderingServer.force_draw(false)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	close.call()
	await _frames(2)
	return ms


func _key(vp: SubViewport, key: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = pressed
		vp.push_input(ev)


## Starts one work on each of `count` hexes the player owns, nearest to `near` first (the rows' 40 seasons of play).
func _begin_works(session: Node, g: Game, count: int, near: Vector2i) -> void:
	var found: Array[Dictionary] = []
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or Territory.owner_tag(g, hex) != g.player or not Improve.piece_at(g, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(g, hex):
			var args := {"hex": hex, "family": int(option["family_id"])}
			if bool(option["ok"]) and bool((session.call("check", "build", args) as Dictionary)["ok"]):
				found.append({"args": args, "d": (hex - near).length_squared()})
				break
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["d"]) < int(b["d"]))
	for k: int in mini(count, found.size()):
		session.call("act", "build", found[k]["args"])


## All the rows, in the running Genoa game of `app` (a SubViewport `vp` of 1920 x 1080). `europe_seasons` < 0: 40, and none
## headless; 0: none; N: the made-up Europe played N seasons.
func measure(app: Node, vp: SubViewport, headless: bool, europe_seasons: int) -> void:
	var session := _tree.root.get_node("Session")
	var g: Game = session.get("game") as Game
	var ms := app.call("map_scene") as Node
	var hud_node := app.call("hud") as Node
	var works: Object = (app.call("requests") as Object).get("works")
	if g == null or ms == null or hud_node == null or works == null or not g.has_countries() or g.player != TAG:
		printerr("perf_ui: the M4.5 country game did not start")
		for key: String in ["study_open_cold_ms", "study_open_europe_ms", "study_tab_switch_ms", "yields_mode_ms", "yields_update_ms",
				"study_table_rows_ms", "timeline_draw_ms", "legend_show_ms"]:
			_r[key] = INF
		return
	var focus := CountryCard.of(g, g.player)["focus"] as Vector2i
	for _n: int in SEASONS:
		_begin_works(session, g, 2, focus)
		session.call("end_season")
	await _frames(3)
	_r["m45_turn"] = g.turn
	await _measure_pages(app, works, g)
	await _measure_tab_switch(app, works)
	await _measure_yields(app, vp, ms, hud_node, g)
	await _measure_table(vp)
	await _measure_timeline(vp)
	if europe_seasons < 0:
		europe_seasons = 0 if headless else SEASONS
	if europe_seasons == 0:
		_r["study_open_europe_ms"] = 0.0
		_r["study_open_europe_skipped"] = true
	else:
		await _measure_europe(vp, europe_seasons)


## The five pages: the first open of each (its nodes are built), then cold (the view cache cleared) and warm opens.
func _measure_pages(app: Node, works: Object, g: Game) -> void:
	var first_worst := 0.0
	var cold_worst := 0.0
	var warm_worst := 0.0
	var per_page := {}
	var close := func() -> void: works.call("close_study")
	for entry: Dictionary in PAGES:
		var open := func() -> void: works.call("open_study", entry["page"], entry["focus"])
		first_worst = maxf(first_worst, await _push_ms(open, close))
		var cold := 0.0
		for _i: int in OPEN_RUNS:
			g.view_cache.clear()
			cold = maxf(cold, await _push_ms(open, close))
		var warm := 0.0
		for _i: int in OPEN_RUNS:
			warm = maxf(warm, await _push_ms(open, close))
		per_page[str(entry["name"])] = {"cold_ms": cold, "warm_ms": warm}
		cold_worst = maxf(cold_worst, cold)
		warm_worst = maxf(warm_worst, warm)
	_r["study_first_build_ms"] = first_worst
	_r["study_open_cold_ms"] = cold_worst
	_r["study_open_warm_ms"] = warm_worst
	_r["study_pages_ms"] = per_page


## Ctrl+] between Districts and Goods, both built: the page's step_tab and one forced draw.
func _measure_tab_switch(app: Node, works: Object) -> void:
	works.call("open_study", &"economy", {"tab": &"districts"})
	await _frames(3)
	var study := (app.call("stack") as Control).call("top") as Node
	var page: Node = study.call("current_page") if study != null else null
	if page == null:
		_r["study_tab_switch_ms"] = INF
		return
	page.call("select_tab", &"goods")  # both tabs built before the rows
	await _frames(3)
	page.call("select_tab", &"districts")
	await _frames(3)
	var worst := 0.0
	for k: int in SWITCH_RUNS:
		var delta := 1 if k % 2 == 0 else -1
		var t0 := Time.get_ticks_usec()
		page.call("step_tab", delta)
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		await _frames(2)
	_r["study_tab_switch_ms"] = worst
	works.call("close_study")
	await _frames(2)


## Key 4 to the first Yields frame, the update of one changed byte, the legend's show.
func _measure_yields(app: Node, vp: SubViewport, ms: Node, hud_node: Node, g: Game) -> void:
	var worst := 0.0
	var yields := int(MapModes.Mode.YIELDS)
	for _i: int in OPEN_RUNS:
		g.view_cache.clear()
		var t0 := Time.get_ticks_usec()
		_key(vp, KEY_4)
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		if int(ms.call("mode")) != yields:
			printerr("perf_ui: key 4 did not set Yields")
			worst = INF
		_key(vp, KEY_1)
		await _frames(3)
	_r["yields_mode_ms"] = worst
	_key(vp, KEY_4)
	await _frames(3)
	var overlay := ms.call("overlay") as Object
	var bytes := MapModes.yield_bytes(g, TAG)
	overlay.call("update_yields", bytes)
	var changed := bytes.duplicate()
	var at := 0
	for i: int in changed.size():
		if changed[i] > 1:
			at = i
			break
	var total := 0.0
	for k: int in CPU_RUNS:
		changed[at] = 2 + (k % 8)
		var t1 := Time.get_ticks_usec()
		var warm := MapModes.yield_bytes(g, TAG)
		overlay.call("update_yields", changed)
		total += float(Time.get_ticks_usec() - t1) / 1000.0
		overlay.call("update_yields", warm)
	_r["yields_update_ms"] = total / float(CPU_RUNS)
	var legend := hud_node.call("mode_legend") as Object
	total = 0.0
	for _i: int in CPU_RUNS:
		var t2 := Time.get_ticks_usec()
		legend.call("show_mode", yields)
		total += float(Time.get_ticks_usec() - t2) / 1000.0
	_r["legend_show_ms"] = total / float(CPU_RUNS)
	_key(vp, KEY_1)
	await _frames(3)


## StudyTable.set_rows with 100 rows of 7 columns, two custom-drawn (a bar and a spark): the call alone, in a table in the tree.
func _measure_table(vp: SubViewport) -> void:
	var table := (load("res://shell/ui/study_table.gd") as GDScript).new() as Control
	table.custom_minimum_size = Vector2(900.0, 400.0)
	vp.add_child(table)
	await _frames(2)
	table.call("set_columns", [
		{"id": &"place", "title": "Place", "kind": &"text"},
		{"id": &"what", "title": "What", "kind": &"text"},
		{"id": &"season", "title": "A season", "kind": &"number"},
		{"id": &"year", "title": "A year", "kind": &"delta"},
		{"id": &"upkeep", "title": "Upkeep", "kind": &"number"},
		{"id": &"share", "title": "Share", "kind": &"bar", "ink": 1},
		{"id": &"trend", "title": "Trend", "kind": &"spark", "ink": 0},
	])
	var rows: Array = []
	for i: int in TABLE_ROWS:
		rows.append({"id": i, "cells": {
			&"place": "Place %d" % i, &"what": "walled town", &"season": 10 + i, &"year": 40 * i - 1000, &"upkeep": 8 + i % 5,
			&"share": (i * 37) % 1000, &"trend": [3, 5, 4, 8, 9, 7, 12, 14 + i % 6],
		}})
	var worst := 0.0
	for _i: int in TABLE_RUNS:
		var t0 := Time.get_ticks_usec()
		table.call("set_rows", rows)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		await _frames(1)
	_r["study_table_rows_ms"] = worst
	vp.remove_child(table)
	table.queue_free()
	await _frames(2)


## TimelineStrip._draw with 680 seasons and 200 marks, called inside the strip's own draw (its `draw` signal, after one forced
## draw has made the strip's first pass): only the strip's work is timed, not the frame.
func _measure_timeline(vp: SubViewport) -> void:
	var strip := (load("res://shell/ui/timeline_strip.gd") as GDScript).new() as Control
	strip.custom_minimum_size = Vector2(1200.0, 120.0)
	vp.add_child(strip)
	var counts := PackedInt32Array()
	counts.resize(TIMELINE_SEASONS)
	for i: int in TIMELINE_SEASONS:
		counts[i] = i % 5
	var marks: Array = []
	var kinds: Array[String] = ["finished", "begun", "short", "tax", "land"]
	for i: int in TIMELINE_MARKS:
		marks.append({"turn": 1 + (i * 3) % TIMELINE_SEASONS, "kind": kinds[i % kinds.size()], "tone": &"plain", "icon": &"", "text": "Mark %d" % i})
	strip.call("set_timeline", {"first_turn": 1, "last_turn": TIMELINE_SEASONS, "start_year": 1480, "counts": counts, "marks": marks})
	strip.size = Vector2(1200.0, 120.0)
	await _frames(2)
	var timing := {"ms": 0.0}
	strip.draw.connect(func() -> void:
		var t0 := Time.get_ticks_usec()
		strip.call("_draw")
		timing["ms"] = maxf(float(timing["ms"]), float(Time.get_ticks_usec() - t0) / 1000.0))
	for _i: int in TABLE_RUNS:
		strip.queue_redraw()
		RenderingServer.force_draw(false)
		await _frames(1)
	_r["timeline_draw_ms"] = float(timing["ms"])
	vp.remove_child(strip)
	strip.queue_free()
	await _frames(2)


## The five pages on the made-up Europe as its largest country, after the warmer ran (spec 4.12): a Study of its own in the
## viewport, the game swapped into Session for the rows and put back after.
func _measure_europe(vp: SubViewport, seasons: int) -> void:
	var game := PerfFixture.europe_game(seasons)
	if game == null:
		_r["study_open_europe_ms"] = INF
		return
	var session := _tree.root.get_node("Session")
	var old: Variant = session.get("game")
	session.set("game", game)
	var warm := (load("res://shell/app/study_warm.gd") as GDScript).new() as Node
	warm.call("queue_views")
	warm.call("warm_now")
	var study := (load("res://shell/screens/study.tscn") as PackedScene).instantiate() as Control
	study.call("configure", (load("res://shell/screens/study_pages.gd") as GDScript).call("shown", MILESTONE), MILESTONE)
	vp.add_child(study)
	await _frames(3)
	var worst := 0.0
	for entry: Dictionary in PAGES:
		var open := func() -> void: study.call("open_page", entry["page"], entry["focus"])
		var close := func() -> void: pass
		await _push_ms(open, close)  # the first build of the nodes
		for _i: int in OPEN_RUNS:
			worst = maxf(worst, await _push_ms(open, close))
	_r["study_open_europe_ms"] = worst
	_r["europe_seasons"] = seasons
	vp.remove_child(study)
	study.queue_free()
	warm.free()
	session.set("game", old)
	await _frames(2)
