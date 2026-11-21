## The M6 rows of tools/ui/perf_ui.gd (m6-build-spec.md section 8), split out like perf_ui_m5.gd. Run in the Genoa game the M5 rows
## played (north Italy after its seasons), after them: up to 100 companies on Genoa's land, one army a hex (raised through
## Session.act; the rig makes each hex a town first, as ArmyFixture.town does: the rig, not the rules), the first of them marching. A call is timed with one forced draw after it where the row
## is drawn (the project runs in low-processor mode, so no frame is awaited). Rows (written into the result dictionary):
##   army_panel_open_ms     an army selected and its panel shown, the view cache cleared, worst of 3 (the call and one forced draw)
##   tokens_refresh_ms      ArmyTokens.refresh for the player's armies (about 100 tokens), mean of 10
##   route_hover_ms         a hover change to another hex with an army selected (its route drawn), cold, worst of 3
##   replay_frame_ms        one frame of the movement replay with 40 walkers (the clock and the poses), mean of 30
##   supply_mode_ms         key 6 to the first Supply frame, the view cache cleared, worst of 3
##   military_page_open_ms  the Military page opened with the view cache cleared, the call and one forced draw, worst of 3
##   report_armies_ms       SeasonSummary.of for the player (its Armies section among the sections), mean of 5; not in the budget
## Everything of the shell is reached through call() and get(): perf_ui compiles before the autoloads. Headless the same calls run
## on the dummy renderer and the gpu rows are reported, not enforced (perf_ui_budget.json's classes).
extends RefCounted

const RUNS := 3
const TOKEN_RUNS := 10
const SUMMARY_RUNS := 5
const REPLAY_WALKERS := 40
const REPLAY_FRAMES := 30
const REPLAY_DT := 0.005
const RAISE_TARGET := 100
const RAISE_TRIES := 150
const TAG_RAISE_KIND := &"pikemen"

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


## The rows, in the running Genoa game of `app` after the M5 rows.
func measure(app: Node, vp: SubViewport) -> void:
	var session := _tree.root.get_node("Session")
	var g: Game = session.get("game") as Game
	var ms := app.call("map_scene") as Node
	var works: Object = (app.call("requests") as Object).get("works")
	var armies := ms.get_node_or_null("MapArmies") as Node if ms != null else null
	if g == null or ms == null or works == null or armies == null or not g.has_countries() or g.player == &"":
		printerr("perf_ui: the M6 country game did not start")
		for key: String in ["army_panel_open_ms", "tokens_refresh_ms", "route_hover_ms", "replay_frame_ms", "supply_mode_ms", "military_page_open_ms"]:
			_r[key] = INF
		return
	var raised := _raise_companies(session, g)
	_r["m6_companies"] = raised
	var ids: Array = []
	for army: Object in Armies.of_country(g, g.player):
		ids.append(army.get("id"))
	if ids.is_empty():
		printerr("perf_ui: no army raised for the M6 rows")
		return
	await _measure_panel(armies, g, int(ids[0]))
	_measure_tokens(armies, g)
	await _measure_route(armies, g, int(ids[0]))
	await _measure_supply(vp, ms, g)
	await _measure_military(works, g)
	_measure_summary(g)
	# The replay last: its walks end on their own if the clock runs long, and the flow would then hear of it.
	_measure_replay(app, armies, g)


## Raises one company a hex on the player's land, up to RAISE_TARGET companies (each raise through Session.act). Returns the count.
func _raise_companies(session: Node, g: Game) -> int:
	session.call("dev_money", g.player, 10000000)
	var kind := 0
	for unit: UnitDef in g.defs.units:
		if unit.key == TAG_RAISE_KIND:
			kind = unit.id
	var raised := 0
	var tries := 0
	for i: int in range(0, g.map.hex_count()):
		if raised >= RAISE_TARGET or tries >= RAISE_TRIES:
			break
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or Territory.owner_tag(g, hex) != g.player:
			continue
		tries += 1
		# The rig: a town of level 3 with 20,000 people (ArmyFixture.town's numbers), so the hex can raise companies.
		g.state.main_use[i] = Economy.SETTLEMENTS
		g.state.level[i] = 3
		g.state.people[i] = maxi(int(g.state.people[i]), 20000)
		g.districts.clear()
		g.version += 1
		var verdict := session.call("act", "raise", {"hex": hex, "kind": kind, "count": 1}) as Dictionary
		if bool(verdict.get("ok", false)):
			raised += 1
		elif tries <= 3:
			printerr("perf_ui: a raise refused: %s" % str(verdict.get("reason", "")))
	return raised


## An own land hex beside `hex`, or (-1, -1) when none.
static func _own_beside(g: Game, hex: Vector2i, skip: Vector2i) -> Vector2i:
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if beside != skip and g.map.has(beside) and g.map.is_land(beside) and Territory.owner_tag(g, beside) == g.player:
			return beside
	return Vector2i(-1, -1)


## The panel is shown by the selection (GameRequests hears army_selected): the row is the selection's call and its draw.
func _measure_panel(armies: Node, g: Game, army_id: int) -> void:
	var worst := 0.0
	for _i: int in RUNS:
		armies.call("clear_army")
		g.view_cache.clear()
		var t0 := Time.get_ticks_usec()
		armies.call("select_army", army_id)
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		await _frames(2)
	armies.call("clear_army")
	_r["army_panel_open_ms"] = worst


func _measure_tokens(armies: Node, g: Game) -> void:
	var tokens: Object = armies.call("tokens") as Object
	var total := 0.0
	for _i: int in TOKEN_RUNS:
		var t0 := Time.get_ticks_usec()
		tokens.call("refresh", g, g.player, false)
		total += float(Time.get_ticks_usec() - t0) / 1000.0
	_r["tokens_refresh_ms"] = total / float(TOKEN_RUNS)
	_r["m6_tokens"] = int(tokens.call("token_count"))


func _measure_route(armies: Node, g: Game, army_id: int) -> void:
	var army: Object = Armies.by_id(g, army_id)
	var here: Vector2i = army.get("hex") as Vector2i
	var first := _own_beside(g, here, Vector2i(-1, -1))
	var second := _own_beside(g, first, here) if first.x >= 0 else Vector2i(-1, -1)
	if first.x < 0 or second.x < 0:
		_r["route_hover_ms"] = INF
		return
	armies.call("select_army", army_id)
	var worst := 0.0
	for run: int in RUNS:
		for hex: Vector2i in [first, second]:
			g.view_cache.clear()
			var t0 := Time.get_ticks_usec()
			armies.call("_on_hover", hex)
			RenderingServer.force_draw(false)
			worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		await _frames(1)
	armies.call("clear_army")
	_r["route_hover_ms"] = worst


func _measure_supply(vp: SubViewport, ms: Node, g: Game) -> void:
	var worst := 0.0
	for _i: int in RUNS:
		g.view_cache.clear()
		var t0 := Time.get_ticks_usec()
		_key(vp, KEY_6)
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		if int(ms.call("mode")) != int(MapModes.Mode.SUPPLY):
			printerr("perf_ui: key 6 did not set Supply")
			worst = INF
		_key(vp, KEY_1)
		await _frames(3)
	_r["supply_mode_ms"] = worst


func _measure_military(works: Object, g: Game) -> void:
	var open := func() -> void: works.call("open_study", &"military", {})
	var close := func() -> void: works.call("close_study")
	var worst := 0.0
	for _i: int in RUNS:
		g.view_cache.clear()
		var t0 := Time.get_ticks_usec()
		open.call()
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		close.call()
		await _frames(2)
	_r["military_page_open_ms"] = worst


func _measure_summary(g: Game) -> void:
	var total := 0.0
	for _i: int in SUMMARY_RUNS:
		var t0 := Time.get_ticks_usec()
		SeasonSummary.of(g, g.player, g.turn - 1)
		total += float(Time.get_ticks_usec() - t0) / 1000.0
	_r["report_armies_ms"] = total / float(SUMMARY_RUNS)


## Forty walks of two steps each on the player's land, started through MoveReplay as a season's walks; then REPLAY_FRAMES frames
## of the clock with the walkers' poses. The replay is cancelled at the end (no `finished`, so the flow hears nothing).
func _measure_replay(app: Node, armies: Node, g: Game) -> void:
	var replay: Object = (app.call("requests") as Object).get("replay") as Object
	if replay == null:
		_r["replay_frame_ms"] = INF
		return
	replay.call("cancel")
	var made := 0
	for army: Object in Armies.of_country(g, g.player):
		if made >= REPLAY_WALKERS:
			break
		var here: Vector2i = army.get("hex") as Vector2i
		var one := _own_beside(g, here, Vector2i(-1, -1))
		var two := _own_beside(g, one, here) if one.x >= 0 else Vector2i(-1, -1)
		if one.x < 0 or two.x < 0:
			continue
		var path: Array[Vector2i] = [here, one, two]
		var seen := PackedByteArray([1, 1, 1])
		var ticks := PackedInt32Array([1, 2])
		replay.call("record", g.player, int(army.get("id")), path, seen, ticks)
		made += 1
	replay.call("_on_season_ended", g.turn)  # the walks of a season that ended: they become the ones start() plays
	if made == 0 or not bool(replay.call("start", &"normal")):
		_r["replay_frame_ms"] = INF
		replay.call("cancel")
		return
	var total := 0.0
	for _i: int in REPLAY_FRAMES:
		var t0 := Time.get_ticks_usec()
		replay.call("_process", REPLAY_DT)
		total += float(Time.get_ticks_usec() - t0) / 1000.0
	replay.call("cancel")
	armies.call("sync")
	_r["replay_frame_ms"] = total / float(REPLAY_FRAMES)
	_r["m6_walkers"] = made
