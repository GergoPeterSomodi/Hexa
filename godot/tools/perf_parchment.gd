## The parchment map's speed rows (docs/architecture/map-overview-build-plan.md section 4, as amended 2026-11-28),
## measured by tools/perf_map.gd after its countries pass, on the same made-up Europe (60 countries) and on north Italy.
## The limits are tests/perf_budget.json's; nothing is asserted here. It builds its own games and nodes and hides what
## perf_map left on the screen, so the older rows are not touched. A row whose measurement did not do what it names (the
## parchment not solid, nothing laid out, no texel written) is given NOT_DONE, over every limit, and says why.
##
## Zooms: Terrain and Owner show the parchment only under ParchmentSwitch.PARCHMENT_UNDER_FIT times the fit zoom, down to
## ZoomModel.MIN_MARGIN times it, so their rows are measured at those two zooms ("switch" and "limit"), worked out from
## the constants for each map. Goods mode shows the parchment at every zoom and is measured at closer zooms too.
##
## The CPU rows run in `--dry-run` (headless) and windowed alike: windowed, the window's viewport is not rendered while
## they are timed, so "to the next frame" is the engine's work and never a software renderer's. The frame rows need a
## window (the nightly job) and render everything.
class_name PerfParchment
extends RefCounted

const FRAME := Vector2(1920.0, 1080.0)
const GAME_DEFS := "res://data/defs/game_defs.tres"
## A land hex in DISTRICT_EVERY holds a district that makes a good, and the places hold their towns: about the 12,500
## districts a new game's improvement search puts on this map (PerfFixture.europe_game; the search takes over two
## minutes here, so it is not run).
const DISTRICT_EVERY := 6
const SLICE_MS := 5.0  # MapScene.slice_ms: what a loading frame gives the geometry
const SWITCH_SHARE := 0.995  # just under the switch: the closest zoom that shows the parchment
const RETURN_SHARE := 1.005  # just past the zoom that gives the tiles back
## Goods mode shows the parchment at every zoom: the closer zooms its frames are timed at besides the switch and limit.
const GOODS_ZOOMS: Array[float] = [0.12, 0.28, 0.36, 1.0]
## The zoom of the labels row and the good switch: the town view (names, dots and icons), in Goods mode.
const TOWN_ZOOM := 0.30
const SWITCHES := 8
const CHANGES := 24
const VIEWS := 24
const COLD_RUNS := 3
const SETTLE := 20
const BAND_STEPS := 30  # frames a cross-fade is spread over
const MB := 1048576.0
const NOT_DONE := 1.0e9  # a row that was not measured as it says
## The rows of the budget this measures; the last three need a window.
const KEYS: Array[String] = [
	"parchment_build_ms", "parchment_build_ni_ms", "parchment_slice_worst_ms", "parchment_goods_bytes_ms",
	"parchment_good_switch_ms", "parchment_owner_change_ms", "parchment_labels_ms", "parchment_labels_ni_ms",
	"parchment_mem_mb", "parchment_frame_worst_ms", "parchment_frame_mean_ms", "parchment_band_frame_worst_ms",
]

## One map on show: its game, the parchment nodes and what a view needs.
class Sheet:
	extends RefCounted

	var game: Game = null
	var map_node: ParchmentMap = null
	var names: ParchmentLabels = null
	var size := Vector2.ZERO  # map px
	var fit := 1.0
	var good := 0  # the good with the most districts

	## The zoom just under the switch, and the zoom-out limit.
	func switch_zoom() -> float:
		return fit * ParchmentSwitch.PARCHMENT_UNDER_FIT * SWITCH_SHARE

	func limit_zoom() -> float:
		return fit * ZoomModel.MIN_MARGIN

	## The map-to-screen transform of a camera at `at` (map px).
	func xform(at: Vector2, zoom: float) -> Transform2D:
		return Transform2D(Vector2(zoom, 0.0), Vector2(0.0, zoom), FRAME * 0.5 - at * zoom)

	## Point `k` of `count` along the pan of the older rows.
	func pan(k: int, count: int) -> Vector2:
		var sweep := float(k) / float(count)
		return size * Vector2(0.3 + 0.4 * sweep, 0.4 + 0.2 * sin(sweep * TAU))


var _tree: SceneTree = null
var _r: Dictionary = {}
var _dry := false
var _timed := 240
var _camera: Camera2D = null
var _europe: Sheet = null
var _italy: Sheet = null
var _info: Array[String] = []  # table lines beside the rows
var _frames: Array[Dictionary] = []
var _broken: Dictionary[String, bool] = {}  # the rows given NOT_DONE


## Measures every row into `r` (KEYS) and leaves the table in r["parchment_table"]. `map` is the made-up Europe.
static func measure(tree: SceneTree, r: Dictionary, map: MapData, countries: int, seed_value: int, timed: int,
		dry: bool) -> void:
	var run := PerfParchment.new()
	run._tree = tree
	run._r = r
	run._dry = dry
	run._timed = timed
	await run._run(map, countries, seed_value)


func _run(map: MapData, countries: int, seed_value: int) -> void:
	var hidden := _hide_others()
	var europe := _europe_game(map, countries, seed_value)
	var italy := PerfFixture.north_italy_game(0)
	if europe == null or italy == null:
		printerr("perf_parchment: a game cannot be built")
		for key: String in KEYS:
			_r[key] = NOT_DONE
		_show(hidden)
		return
	_camera = Camera2D.new()
	_tree.root.add_child(_camera)
	_camera.make_current()
	_render(false)
	_goods_bytes_row(europe)
	_europe = _sheet(europe)
	await _build_rows()
	_italy_build_row(italy)
	_italy = _sheet(italy)
	_italy.map_node.begin(italy)
	_italy.map_node.step(1.0e9)
	_italy.map_node.visible = false
	_italy.names.visible = false
	_labels_rows()
	await _good_switch_row()
	await _owner_change_row()
	_render(true)
	if not _dry:
		await _frame_rows()
		await _band_row()
	for key: String in _broken:
		_r[key] = NOT_DONE
	_r["parchment_table"] = _table()
	for sheet: Sheet in [_europe, _italy]:
		sheet.map_node.free()
		sheet.names.free()
	_camera.free()
	_show(hidden)


# ----- the games and the nodes ---------------------------------------------------------------------------------------


## The made-up Europe with its countries and the real goods, districts on every DISTRICT_EVERY-th land hex, towns on its
## places, and the largest country as a player who has discovered all of it (the most there is to draw and to name).
static func _europe_game(map: MapData, countries: int, seed_value: int) -> Game:
	var built := FakeScenario.build(map, countries, seed_value)
	var defs := built["defs"] as GameDefs
	var real := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if real == null:
		return null
	defs.families = real.families
	defs.goods = real.goods
	var makers := PackedInt32Array()
	for fam: FamilyDef in defs.families:
		if fam.good != &"" or not fam.by_extra.is_empty():
			makers.append(fam.id)
	var state := MapState.create(map)
	var land := 0
	for i: int in map.hex_count():
		if map.land[i] == 0:
			continue
		if land % DISTRICT_EVERY == 0:
			@warning_ignore("integer_division")
			var nth := land / DISTRICT_EVERY
			state.main_use[i] = makers[nth % makers.size()]
			state.level[i] = 1 + nth % ParchmentView.MAX_STAGE
		land += 1
	for place: Dictionary in map.places:
		var hex: Vector2i = place.get("hex", Country.NO_HEX)
		if map.is_land(hex):
			state.main_use[map.index_of(hex)] = ImproveRules.SETTLEMENT
			state.level[map.index_of(hex)] = clampi(int(place.get("level", 1)), 1, 5)
	var game := Game.with_state(map, state, seed_value, defs)
	game.scenario = built["scenario"] as ScenarioDef
	Countries.setup(game, game.scenario)
	Territory.setup(game, game.scenario)
	game.player = PerfFixture.largest_tag(game)
	var all := PackedByteArray()
	all.resize((map.hex_count() + 7) >> 3)
	all.fill(255)
	Countries.by_tag(game, game.player).explored = all
	game.sight.clear()
	Sight.refresh(game)
	game.version += 1
	return game


## The parchment nodes of a game in the world, not yet begun.
func _sheet(game: Game) -> Sheet:
	var out := Sheet.new()
	out.game = game
	out.size = Vector2((game.map.cols + 0.5) * MapTiles.CELL.x,
		(game.map.rows - 1) * MapTiles.ROW + MapTiles.CELL.y)
	out.fit = ZoomModel.fit_zoom(FRAME, out.size)
	var most := -1
	for good: Dictionary in ParchmentView.goods_list(game):
		var n := ParchmentView.count_of(game, game.player, good["id"])
		if n > most:
			most = n
			out.good = good["id"]
	out.map_node = ParchmentMap.new()
	_tree.root.add_child(out.map_node)
	out.map_node.set_options(true, true, false, false, true)
	out.names = ParchmentLabels.new()
	_tree.root.add_child(out.names)
	return out


## Puts the sheet at a mode and a zoom with the parchment solid there, for the row `key` (broken when it is not).
func _solid(sheet: Sheet, mode: int, zoom: float, key: String) -> void:
	_camera.position = sheet.size * 0.5
	_camera.zoom = Vector2(zoom, zoom)
	sheet.map_node.set_mode(mode)
	sheet.map_node.set_good(sheet.good)
	sheet.map_node.settle()
	for _n: int in ParchmentSwitch.SETTLE_STEPS + 1:
		sheet.map_node.apply_zoom(zoom, sheet.fit)
		sheet.map_node.step_fade(1.0)
	var alpha := sheet.map_node.apply_zoom(zoom, sheet.fit)
	sheet.names.set_mode(mode)
	sheet.names.set_good(sheet.good)
	sheet.names.set_alpha(alpha)
	sheet.names.relayout(sheet.xform(_camera.position, zoom), zoom, FRAME)
	if alpha < 1.0:
		_problem(key, "the parchment is not solid at zoom %.4f in mode %d" % [zoom, mode])


## The row `key` was not measured as it says.
func _problem(key: String, text: String) -> void:
	_broken[key] = true
	printerr("perf_parchment: %s: %s" % [key, text])
	_info.append("PROBLEM (%s): %s" % [key, text])


## Hides what stands in the world and the canvas layers; returns what was shown.
func _hide_others() -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in _tree.root.get_children():
		if (child is CanvasItem or child is CanvasLayer) and bool(child.get("visible")):
			child.set("visible", false)
			out.append(child)
	return out


func _show(nodes: Array[Node]) -> void:
	for node: Node in nodes:
		node.set("visible", true)


## Windowed: whether the window's viewport is rendered (off while the CPU rows are timed).
func _render(on: bool) -> void:
	if _dry:
		return
	RenderingServer.viewport_set_update_mode(_tree.root.get_viewport_rid(),
		RenderingServer.VIEWPORT_UPDATE_WHEN_VISIBLE if on else RenderingServer.VIEWPORT_UPDATE_DISABLED)


static func _ms_since(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


# ----- the CPU rows --------------------------------------------------------------------------------------------------


## goods_bytes of the whole map from cold (the view cache cleared and the version moved), worst of COLD_RUNS. The
## sight's own cache of the land seen is filled first: it is not the parchment's (perf_core's land_seen_ms).
func _goods_bytes_row(game: Game) -> void:
	MapModes.discovered_bytes(game, game.player)
	var worst := 0.0
	for _n: int in COLD_RUNS:
		game.view_cache.clear()
		game.version += 1
		var t := Time.get_ticks_usec()
		ParchmentView.goods_bytes(game, game.player)
		worst = maxf(worst, _ms_since(t))
	var made := 0
	for good: Dictionary in ParchmentView.goods_list(game):
		made += ParchmentView.count_of(game, game.player, good["id"])
	_r["parchment_goods_bytes_ms"] = worst
	_info.append("made-up Europe: %d districts make a good, %d countries" % [made, game.countries.size()])


## The made-up Europe built as the map scene does it: SLICE_MS a frame. The CPU of the slices, and the worst frame from
## one to the next (begin(), on the loading path, is outside both).
func _build_rows() -> void:
	var node := _europe.map_node
	var t := Time.get_ticks_usec()
	node.begin(_europe.game)
	var begin_ms := _ms_since(t)
	node.apply_zoom(_europe.limit_zoom(), _europe.fit)
	await _tree.process_frame
	var cpu := 0.0
	var slices := 0
	var slice_worst := 0.0
	var frame_worst := 0.0
	var last := Time.get_ticks_usec()
	while node.is_building():
		var s := Time.get_ticks_usec()
		node.step(SLICE_MS)
		var one := _ms_since(s)
		cpu += one
		slice_worst = maxf(slice_worst, one)
		slices += 1
		await _tree.process_frame
		var now := Time.get_ticks_usec()
		frame_worst = maxf(frame_worst, float(now - last) / 1000.0)
		last = now
	_r["parchment_build_ms"] = cpu
	_r["parchment_slice_worst_ms"] = frame_worst
	_r["parchment_mem_mb"] = float(node.memory_bytes()) / MB
	_info.append("made-up Europe build: begin %.1f ms, %d slices, worst slice %.2f ms, worst frame %.2f ms" % [begin_ms,
		slices, slice_worst, frame_worst])
	node.visible = false
	_europe.names.setup(_europe.game)
	_europe.names.visible = false


## North Italy's geometry at once, worst of COLD_RUNS fresh nodes.
func _italy_build_row(game: Game) -> void:
	var worst := 0.0
	for _n: int in COLD_RUNS:
		var node := ParchmentMap.new()
		_tree.root.add_child(node)
		node.begin(game)
		var t := Time.get_ticks_usec()
		node.step(1.0e9)
		worst = maxf(worst, _ms_since(t))
		node.free()
	_r["parchment_build_ni_ms"] = worst


## ParchmentLabels.relayout for one view change (a pan with a small zoom step), worst of VIEWS at each view.
func _labels_rows() -> void:
	_italy.names.setup(_italy.game)
	var europe := _labels_worst(_europe, "parchment_labels_ms", [
		["Terrain, switch", MapModes.Mode.TERRAIN, _europe.switch_zoom()],
		["Terrain, limit", MapModes.Mode.TERRAIN, _europe.limit_zoom()],
		["Goods, zoom %.2f" % TOWN_ZOOM, MapModes.Mode.GOODS, TOWN_ZOOM],
	])
	var italy := _labels_worst(_italy, "parchment_labels_ni_ms", [
		["Terrain, switch", MapModes.Mode.TERRAIN, _italy.switch_zoom()],
		["Terrain, limit", MapModes.Mode.TERRAIN, _italy.limit_zoom()],
		["Goods, fit", MapModes.Mode.GOODS, _italy.fit],
	])
	_r["parchment_labels_ms"] = europe
	_r["parchment_labels_ni_ms"] = italy


## The worst relayout over the views [label, mode, zoom] of a sheet, for the row `key`.
func _labels_worst(sheet: Sheet, key: String, views: Array) -> float:
	var out := 0.0
	var names := sheet.names
	names.set_good(sheet.good)
	for view: Array in views:
		var zoom: float = view[2]
		names.set_mode(view[1])
		names.set_alpha(1.0)
		var worst := 0.0
		var placed := 0
		for k: int in VIEWS:
			var z := zoom * (1.0 - 0.002 * float(k % 5))
			var at := sheet.pan(k, VIEWS)
			var count := names.layout_count
			var t := Time.get_ticks_usec()
			names.relayout(sheet.xform(at, z), z, FRAME)
			worst = maxf(worst, _ms_since(t))
			placed = maxi(placed, names.placed().size())
			if names.layout_count == count:
				_problem(key, "a view change laid nothing out (%s)" % view[0])
		if placed == 0:
			_problem(key, "nothing placed (%s)" % view[0])
		_info.append("labels, %s, %s (zoom %.4f): worst %.2f ms, up to %d placed" % [
			"made-up Europe" if sheet == _europe else "north Italy", view[0], zoom, worst, placed])
		out = maxf(out, worst)
	names.visible = false
	return out


## A good picked in Goods mode on the made-up Europe: the uniform, the legend and the icons' layout, to the next frame;
## worst of SWITCHES goods in the town view.
func _good_switch_row() -> void:
	var sheet := _europe
	var goods: Array[int] = []
	for good: Dictionary in ParchmentView.goods_list(sheet.game):
		if goods.size() < SWITCHES and ParchmentView.count_of(sheet.game, sheet.game.player, good["id"]) > 0:
			goods.append(good["id"])
	sheet.good = goods[goods.size() - 1]  # the first switch moves off it
	_solid(sheet, MapModes.Mode.GOODS, TOWN_ZOOM, "parchment_good_switch_ms")
	await _tree.process_frame
	var worst := 0.0
	var icons := 0
	for good: int in goods:
		var t := Time.get_ticks_usec()
		sheet.map_node.set_good(good)
		sheet.names.set_good(good)
		var rows := ParchmentView.legend(sheet.game, sheet.game.player, good)
		await _tree.process_frame
		worst = maxf(worst, _ms_since(t))
		if rows.is_empty():
			_problem("parchment_good_switch_ms", "no legend for good %d" % good)
		for item: Dictionary in sheet.names.placed():
			icons += int(item["kind"] == ParchmentLabels.KIND_ICON)
	if icons == 0 or goods.size() < SWITCHES:
		_problem("parchment_good_switch_ms", "%d goods switched, %d icons" % [goods.size(), icons])
	_r["parchment_good_switch_ms"] = worst
	_info.append("good switch: %d goods at zoom %.2f, %d icons placed in all" % [goods.size(), TOWN_ZOOM, icons])


## One-hex transfers on borders with the parchment solid in Owner mode at the zoom-out limit (every country named): the
## transfer, the texels (owner_bytes), the names read and laid out again, to the next frame; worst of CHANGES.
func _owner_change_row() -> void:
	var sheet := _europe
	var game := sheet.game
	_solid(sheet, MapModes.Mode.OWNER, sheet.limit_zoom(), "parchment_owner_change_ms")
	await _tree.process_frame
	var worst := 0.0
	var done := 0
	var writes := sheet.map_node.texel_writes
	var reads := sheet.names.fact_reads
	for pick: Dictionary in _border_picks(game):
		var hexes: Array[Vector2i] = [pick["hex"] as Vector2i]
		var t := Time.get_ticks_usec()
		Territory.transfer(game, hexes, int(pick["to"]))
		game.version += 1
		game.events.clear()
		sheet.map_node.owners_changed(hexes)
		sheet.names.refresh()
		await _tree.process_frame
		worst = maxf(worst, _ms_since(t))
		done += 1
	if done < CHANGES or sheet.map_node.texel_writes - writes < done or sheet.names.fact_reads - reads < done:
		_problem("parchment_owner_change_ms", "%d transfers, %d texels, %d readings of the names" % [done,
			sheet.map_node.texel_writes - writes, sheet.names.fact_reads - reads])
	_r["parchment_owner_change_ms"] = worst
	_info.append("owner change: %d one-hex transfers, %d names and dots placed" % [done, sheet.names.placed().size()])


## Up to CHANGES land hexes of one country that touch another's land, spread over the map, with the owner to give them
## to (as perf_map picks them).
static func _border_picks(game: Game) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := 0
	var map := game.map
	var owned := game.state.owner
	for idx: int in map.hex_count():
		if map.land[idx] == 0 or owned[idx] == 0:
			continue
		var hex := map.hex_of(idx)
		for d: int in 6:
			var other := map.index_of(map.neighbour(hex, d))
			if other < 0 or map.land[other] == 0 or owned[other] == 0 or owned[other] == owned[idx]:
				continue
			seen += 1
			if seen % 50 == 0:
				out.append({"hex": hex, "to": int(owned[other])})
			break
		if out.size() >= CHANGES:
			break
	return out


# ----- the frame rows (windowed) -------------------------------------------------------------------------------------


## The made-up Europe panning with the parchment solid: Terrain and Owner at the switch and the limit zoom, Goods at
## those and at GOODS_ZOOMS.
func _frame_rows() -> void:
	var sheet := _europe
	var views: Array[Array] = []
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.GOODS]:
		views.append([mode, sheet.switch_zoom()])
		views.append([mode, sheet.limit_zoom()])
	for zoom: float in GOODS_ZOOMS:
		views.append([int(MapModes.Mode.GOODS), zoom])
	var worst := 0.0
	var mean := 0.0
	for view: Array in views:
		var mode: int = view[0]
		var zoom: float = view[1]
		_solid(sheet, mode, zoom, "parchment_frame_worst_ms")
		if sheet.map_node.apply_zoom(zoom, sheet.fit) < 1.0:
			_problem("parchment_frame_mean_ms", "not solid at zoom %.4f" % zoom)
		var row := await _pan(sheet, zoom)
		row["what"] = "made-up Europe, %s" % MapModes.MODE_KEYS[mode]
		_frames.append(row)
		worst = maxf(worst, float(row["worst_ms"]))
		mean = maxf(mean, float(row["mean_ms"]))
	_r["parchment_frame_worst_ms"] = worst
	_r["parchment_frame_mean_ms"] = mean
	sheet.map_node.visible = false
	sheet.names.visible = false


## One frame of the scene's work for the parchment at a view.
func _parchment_frame(sheet: Sheet, at: Vector2, zoom: float, delta: float) -> float:
	_camera.position = at
	_camera.zoom = Vector2(zoom, zoom)
	sheet.map_node.step_fade(delta)
	sheet.map_node.sync(sheet.game)
	var alpha := sheet.map_node.apply_zoom(zoom, sheet.fit)
	sheet.names.set_alpha(alpha)
	sheet.names.relayout(sheet.xform(at, zoom), zoom, FRAME)
	return alpha


func _pan(sheet: Sheet, zoom: float) -> Dictionary:
	for _n: int in SETTLE:
		_parchment_frame(sheet, sheet.pan(0, _timed), zoom, 0.0)
		await _tree.process_frame
	var last := Time.get_ticks_usec()
	var start := last
	var worst := 0
	for k: int in _timed:
		_parchment_frame(sheet, sheet.pan(k, _timed), zoom, 1.0 / 60.0)
		await _tree.process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
	return {
		"zoom": zoom, "mean_ms": float(last - start) / 1000.0 / float(_timed), "worst_ms": float(worst) / 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
	}


## The frames of the cross-fade, while both pictures are drawn: on the made-up Europe the far picture under the parchment
## (what the scene shows at its fit), on north Italy the tile view with its lines fading.
func _band_row() -> void:
	var far := FarMap.new()
	_tree.root.add_child(far)
	_tree.root.move_child(far, _europe.map_node.get_index())
	far.setup(_europe.game.map, _europe.game.state)
	var europe := await _fades(_europe, func(zoom: float, alpha: float) -> void: far.apply_zoom(zoom, alpha >= 1.0),
		"made-up Europe, far picture under the parchment")
	far.free()
	var tiles := TilesetBuilder.load_season("summer")
	if tiles.tile_set == null:
		_problem("parchment_band_frame_worst_ms", tiles.error)
		return
	var view := _tile_view(_italy.game, tiles)
	_tree.root.move_child(view, _italy.map_node.get_index())
	while view.is_filling():
		view.fill_for(1000.0)
		await _tree.process_frame
	var under := func(_zoom: float, alpha: float) -> void:
		view.set_ground_shown(alpha < 1.0)
		view.set_lines_alpha(1.0 - alpha)
	var italy := await _fades(_italy, under, "north Italy, tiles under the parchment")
	view.free()
	_r["parchment_band_frame_worst_ms"] = maxf(europe, italy)


## A tile view of a game with its fill begun and its lines and borders in.
func _tile_view(game: Game, tiles: TilesetBuilder) -> TileMapView:
	var map := game.map
	var state := game.state
	var view := TileMapView.new()
	_tree.root.add_child(view)
	view.setup(tiles)
	view.set_climates(map.cols, map.climate)
	var provider := func(hex: Vector2i, names: PackedStringArray) -> void: MapCells.fill_hex(map, state, hex, names)
	view.begin_fill(map.cols, map.rows, provider, Vector2i(map.cols >> 1, map.rows >> 1), MapCells.LAYERS)
	var palette := MapModes.palette(game, false)
	for cy: int in ceili(float(map.rows) / EdgeLines.CHUNK):
		for cx: int in ceili(float(map.cols) / EdgeLines.CHUNK):
			var chunk := Vector2i(cx, cy)
			view.set_chunk_lines(chunk, EdgeLines.for_chunk(map, state, chunk))
			view.set_chunk_borders(chunk, BorderLines.for_chunk(map, state.owner, chunk, palette))
	return view


## Cross-fades in and out, panning, until `_timed` frames with both pictures drawn are timed; `under` puts the picture
## below as the scene does. Returns the worst of those frames (ms).
func _fades(sheet: Sheet, under: Callable, what: String) -> float:
	var out_zoom := sheet.switch_zoom()
	var in_zoom := sheet.fit * ParchmentSwitch.TILES_FROM_FIT * RETURN_SHARE
	_solid(sheet, MapModes.Mode.TERRAIN, out_zoom, "parchment_band_frame_worst_ms")
	# From the tiles' side: the settled switch at the zoom that gives the tiles.
	sheet.map_node.settle()
	for _n: int in ParchmentSwitch.SETTLE_STEPS + 1:
		sheet.map_node.apply_zoom(in_zoom, sheet.fit)
		sheet.map_node.step_fade(1.0)
	var zoom := out_zoom
	var delta := ParchmentSwitch.FADE_SEC / float(BAND_STEPS)
	var middle := sheet.size * 0.5
	for _n: int in SETTLE:
		under.call(in_zoom, _parchment_frame(sheet, middle, in_zoom, 0.0))
		await _tree.process_frame
	var last := Time.get_ticks_usec()
	var timed := 0
	var total := 0
	var worst := 0
	for k: int in _timed * 4:
		if timed >= _timed:
			break
		var at := middle + sheet.size * Vector2(0.1 * sin(float(k) * 0.05), 0.05 * cos(float(k) * 0.05))
		var alpha := _parchment_frame(sheet, at, zoom, delta)
		under.call(zoom, alpha)
		var fading := sheet.map_node.is_fading()
		await _tree.process_frame
		var now := Time.get_ticks_usec()
		if fading:
			timed += 1
			total += now - last
			worst = maxi(worst, now - last)
		last = now
		if alpha >= 1.0:
			zoom = in_zoom
		elif alpha <= 0.0:
			zoom = out_zoom
	sheet.map_node.visible = false
	sheet.names.visible = false
	if timed < _timed:
		_problem("parchment_band_frame_worst_ms", "%s: only %d frames of the cross-fade" % [what, timed])
		if timed == 0:
			return NOT_DONE
	_frames.append({"what": "cross-fade, %s" % what, "zoom": out_zoom, "mean_ms": float(total) / 1000.0 / float(timed),
		"worst_ms": float(worst) / 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))})
	return float(worst) / 1000.0


# ----- the table -----------------------------------------------------------------------------------------------------


func _table() -> String:
	var s := "\n| Parchment map | value |\n|---|---|\n"
	s += "| fit zoom, switch, limit | made-up Europe %.4f, %.4f, %.4f; north Italy %.4f, %.4f, %.4f |\n" % [_europe.fit,
		_europe.switch_zoom(), _europe.limit_zoom(), _italy.fit, _italy.switch_zoom(), _italy.limit_zoom()]
	for line: String in _info:
		s += "| | %s |\n" % line
	if not _frames.is_empty():
		s += "\n| Parchment (panning) | zoom | mean ms | worst ms | draw calls | objects |\n|---|---|---|---|---|---|\n"
		for row: Dictionary in _frames:
			s += "| %s | %.4f | %.2f | %.2f | %d | %d |\n" % [row["what"], row["zoom"], row["mean_ms"], row["worst_ms"],
				row["draw_calls"], row["objects"]]
	return s
