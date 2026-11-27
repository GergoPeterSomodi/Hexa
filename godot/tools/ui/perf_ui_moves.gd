## The moves rows of tools/ui/perf_ui.gd (moves-build-spec.md section 9, MV16), split out like perf_ui_m6.gd. Run in the same
## Genoa game after the tile window's rows, with the armies the M6 rows raised. Rows (written into the result dictionary):
##   live_walk_frame_ms    one frame of a live walk (MoveReplay's clock and the walkers' poses) of two armies of the player: a
##                         march of two steps into a battle (its mark) and the retreat after it, REPLAY_FRAMES frames spread over
##                         the whole plan, the mean
##   move_confirm_push_ms  the question about a risky move (three risk lines) made, pushed through the armies' own ask and drawn
##                         (one forced draw), worst of RUNS (the first is the cold one, also written as move_confirm_cold_ms)
## Everything of the shell is reached through call(), get() and load(): perf_ui compiles before the autoloads. Headless the same
## calls run on the dummy renderer and the gpu row is reported, not enforced (perf_ui_budget.json's classes).
extends RefCounted

const RUNS := 3
const REPLAY_FRAMES := 30
const MOVE_ORDERS_PATH := "res://shell/map/move_orders.gd"
const RISKS: Array[Dictionary] = [
	{"kind": &"battle", "text": "This opens a battle at Novara (8, 9)."},
	{"kind": &"enemy_land", "text": "Enters land held by the Duchy of Milan, a country at war with you."},
	{"kind": &"out_of_supply", "text": "Out of supply: the land feeds 200 men a season; 40 men lost a season."},
]

var _tree: SceneTree = null
var _r: Dictionary = {}


func _init(tree: SceneTree, result: Dictionary) -> void:
	_tree = tree
	_r = result


func _frames(n: int) -> void:
	for _i: int in range(n):
		await _tree.process_frame


## The two rows, in the running Genoa game of `app`.
func measure(app: Node) -> void:
	var session := _tree.root.get_node("Session")
	var g: Game = session.get("game") as Game
	var ms := app.call("map_scene") as Node
	var armies := ms.get_node_or_null("MapArmies") as Node if ms != null else null
	var replay: Object = (app.call("requests") as Object).get("replay") as Object
	if g == null or armies == null or replay == null or not g.has_countries() or g.player == &"":
		printerr("perf_ui: the moves rows' game did not start")
		_r["live_walk_frame_ms"] = INF
		_r["move_confirm_push_ms"] = INF
		return
	(app.call("stack") as Control).call("clear")
	armies.call("clear_army")
	await _frames(2)
	_measure_live_walk(armies, replay, g)
	await _measure_confirm(app, armies)


## An own land hex beside `hex` other than `skip`, or (-1, -1).
static func _own_beside(g: Game, hex: Vector2i, skip: Vector2i) -> Vector2i:
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if beside != skip and g.map.has(beside) and g.map.is_land(beside) and Territory.owner_tag(g, beside) == g.player:
			return beside
	return Vector2i(-1, -1)


## The act's events as the Session's drain sends them while no season runs: an attacker's walk of two steps, the battle it
## opens at its end, and the walk of the beaten army back one step. The batch begins on the first frame; the frames after it
## are timed. The speed is set to normal (the rig runs with reduce motion, which plays no live walk) and put back after.
func _measure_live_walk(armies: Node, replay: Object, g: Game) -> void:
	var walkers: Array[int] = []
	var path: Array[Vector2i] = []
	for army: Object in Armies.of_country(g, g.player):
		var here: Vector2i = army.get("hex") as Vector2i
		if path.is_empty():
			var one := _own_beside(g, here, Vector2i(-1, -1))
			var two := _own_beside(g, one, here) if one.x >= 0 else Vector2i(-1, -1)
			if one.x < 0 or two.x < 0:
				continue
			path = [here, one, two]
		walkers.append(int(army.get("id")))
		if walkers.size() == 2:
			break
	if walkers.size() < 2:
		printerr("perf_ui: two armies with a walk were not found")
		_r["live_walk_frame_ms"] = INF
		return
	replay.call("cancel")
	var speed: Callable = replay.get("live_speed")
	replay.set("live_speed", func() -> StringName: return &"normal")
	var seen := PackedByteArray([1, 1, 1])
	replay.call("_on_unit_moved", g.player, walkers[0], path, seen, PackedInt32Array([1, 2]), true)
	replay.call("_on_battle_started", path[2], g.player, g.player)
	var back: Array[Vector2i] = [path[2], path[1]]
	replay.call("_on_unit_moved", g.player, walkers[1], back, PackedByteArray([1, 1]), PackedInt32Array([3]), true)
	replay.call("_on_battle_ended", path[2], -1, g.player)
	replay.call("_process", 0.0)
	var plan: Object = replay.get("_plan") as Object
	if plan == null:
		printerr("perf_ui: the live walk did not begin")
		_r["live_walk_frame_ms"] = INF
		replay.set("live_speed", speed)
		replay.call("cancel")
		return
	var length := float(plan.call("duration"))
	var dt := length / float(REPLAY_FRAMES + 2)
	var total := 0.0
	var marked := 0
	var played := 0
	for _i: int in REPLAY_FRAMES:
		var t0 := Time.get_ticks_usec()
		replay.call("_process", dt)
		total += float(Time.get_ticks_usec() - t0) / 1000.0
		if bool(replay.call("live_active")):
			played += 1
		if not (replay.call("marks") as Array).is_empty():
			marked += 1
	replay.call("cancel")
	replay.set("live_speed", speed)
	armies.call("sync")
	_r["live_walk_frame_ms"] = total / float(REPLAY_FRAMES)
	_r["live_walk_seconds"] = length
	_r["live_walk_frames_playing"] = played
	_r["live_walk_frames_with_mark"] = marked


## The question made as MoveOrders makes it, put up through the armies' ask (the App's push) and drawn once.
func _measure_confirm(app: Node, armies: Node) -> void:
	var orders: Object = armies.call("orders") as Object
	var ask: Callable = orders.get("ask")
	var script := load(MOVE_ORDERS_PATH) as GDScript
	var stack := app.call("stack") as Control
	if not ask.is_valid() or script == null:
		printerr("perf_ui: the move question cannot be asked")
		_r["move_confirm_push_ms"] = INF
		return
	var worst := 0.0
	for run: int in RUNS:
		var t0 := Time.get_ticks_usec()
		var screen: Object = script.call("question", "Army of Genoa", RISKS, func() -> void: pass) as Object
		ask.call(screen)
		RenderingServer.force_draw(false)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		if run == 0:
			_r["move_confirm_cold_ms"] = ms
		worst = maxf(worst, ms)
		if stack.call("top") != screen:
			printerr("perf_ui: the move question is not on the stack")
			worst = INF
		stack.call("clear")
		await _frames(2)
	_r["move_confirm_push_ms"] = worst
