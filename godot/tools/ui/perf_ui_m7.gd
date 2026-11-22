## The M7 rows of tools/ui/perf_ui.gd (m7-build-spec.md section 8), split out like perf_ui_m6.gd. Run in the Genoa game the M6 rows
## played (north Italy after its seasons and about 100 companies), after them: Genoa declares war on a neighbour (through Session.act)
## and the battles are planted as the monkey plants one (written into the game: the rig, not the rules): one record of 8 companies
## against 8 on a Genoese hex (the seed with the most days of the first 40, at most 8) and 60 more on the land hexes of the map,
## last season's, which Genoa read in full (they are the 60 marks). A call is timed with one forced draw after it where the row is
## drawn (the project runs in low-processor mode, so no frame is awaited). Rows (written into the result dictionary):
##   battle_dock_open_ms    the dock opened on the 8-day record, the view cache cleared, worst of 3 (the call and one forced draw)
##   dock_day_step_ms       one step of the dock's stepper (and the draw), worst of the 7 steps through the record
##   war_marks_refresh_ms   WarMarks.refresh with the 60 battle marks and the sieges, the view cache cleared, mean of 10
##   odds_hover_ms          the order cursor over an enemy army with an army selected (the odds card drawn), cold, worst of 3
##   hex_menu_war_ms        the hex menu of a hex with a battle site opened (its war items made), worst of 3
##   area_show_ms           an army selected with a war on: the gate opens, the first slice of the castle-area lines is built and
##                          drawn, worst of 3
## Everything of the shell is reached through call() and get(): perf_ui compiles before the autoloads. Headless the same calls run
## on the dummy renderer and the gpu rows are reported, not enforced (perf_ui_budget.json's classes).
extends RefCounted

const RUNS := 3
const MARK_RUNS := 10
const MARKS := 60
const SEED_TRIES := 40
const SIDE := 8
const ROWS: Array[String] = ["battle_dock_open_ms", "dock_day_step_ms", "war_marks_refresh_ms", "odds_hover_ms", "hex_menu_war_ms",
	"area_show_ms"]

var _tree: SceneTree = null
var _r: Dictionary = {}


func _init(tree: SceneTree, result: Dictionary) -> void:
	_tree = tree
	_r = result


func _frames(n: int) -> void:
	for _i: int in range(n):
		await _tree.process_frame


## The rows, in the running Genoa game of `app` after the M6 rows.
func measure(app: Node) -> void:
	var session := _tree.root.get_node("Session")
	var g: Game = session.get("game") as Game
	var ms := app.call("map_scene") as Node
	var armies := ms.get_node_or_null("MapArmies") as Node if ms != null else null
	var marks := ms.get_node_or_null("WarMarks") as Node if ms != null else null
	var wars := ms.get_node_or_null("MapWars") as Node if ms != null else null
	var war: Object = (app.call("requests") as Object).get("war") as Object
	var foe := _foe_of(g) if g != null and g.has_countries() else &""
	if g == null or armies == null or marks == null or wars == null or war == null or foe == &"":
		printerr("perf_ui: the M7 country game did not start (marks %s, wars %s, war requests %s, foe %s)" % [str(marks != null), str(wars != null), str(war != null), str(foe)])
		for key: String in ROWS:
			_r[key] = INF
		return
	var declared := session.call("act", "declare_war", {"target": foe}) as Dictionary
	if not bool(declared.get("ok", false)):
		printerr("perf_ui: the war on %s was refused: %s" % [foe, str(declared.get("reason", ""))])
		for key: String in ROWS:
			_r[key] = INF
		return
	var record := _plant(g)
	_r["m7_record_days"] = record.frames.size()
	_r["m7_marks"] = _plant_marks(g, record)
	await _frames(2)
	await _measure_dock(app, war, g, record.id)
	_measure_marks(marks, g)
	await _measure_odds(app, session, armies, g, foe)
	await _measure_menu(armies, g, record.hex)
	await _measure_areas(armies, wars, g)


## A neighbour of the player's country (its tag); "" when none.
static func _foe_of(g: Game) -> StringName:
	var own := Countries.by_tag(g, g.player)
	if own == null:
		return &""
	for id: int in Territory.neighbours(g, own.id):
		var other := Countries.by_id(g, id)
		if other != null and other.tag != g.player:
			return other.tag
	return &""


## The record of 8 companies against 8 with the most days of the first SEED_TRIES luck seeds, on a Genoese hex, kept in the game.
func _plant(g: Game) -> BattleRecord:
	var war := CombatFixture.war()
	var fighters: Array = []
	for i: int in SIDE:
		fighters.append(CombatFixture.pikemen(1 + i, 0))
		fighters.append(CombatFixture.pikemen(11 + i, 1))
	for f: Dictionary in fighters:
		for ud: UnitDef in g.defs.units:
			if String(ud.branch) == str(f["branch"]):
				f["kind"] = ud.id
				break
		f["army"] = 1 if int(f["side"]) == 0 else 2
	var input := CombatFixture.input_of(war, fighters)
	input["attacker"] = String(g.player)
	input["defender"] = String(_foe_of(g))
	var best: BattleRecord = null
	for seed_value: int in range(1, SEED_TRIES + 1):
		var rec := CombatFixture.record_of(war, input, seed_value)
		if best == null or rec.frames.size() > best.frames.size():
			best = rec
	return _keep(g, best, _own_hex(g, 0), "Battle of Perf, 1480")


## A land hex of the player's, the `skip`-th found from the map's start.
static func _own_hex(g: Game, skip: int) -> Vector2i:
	var seen := 0
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 1 and Territory.owner_tag(g, hex) == g.player:
			if seen == skip:
				return hex
			seen += 1
	return Vector2i(-1, -1)


## The record in its place in the game: the next id, last season, the player a witness; appended.
func _keep(g: Game, rec: BattleRecord, hex: Vector2i, name: String) -> BattleRecord:
	var mine := BattleRecord.new()
	mine.id = g.next_record_id
	g.next_record_id += 1
	mine.turn = g.turn - 1
	mine.hex = hex
	mine.name = name
	mine.year = g.start_year
	mine.attacker = rec.attacker
	mine.defender = rec.defender
	mine.input = rec.input.duplicate(true)
	mine.luck_before = rec.luck_before
	mine.frames.assign(rec.frames)
	mine.end = rec.end
	mine.witnesses = PackedStringArray([String(g.player)])
	g.battle_records.append(mine)
	g.version += 1
	return mine


## MARKS records more (copies of `rec`'s fight) on land hexes spread over the map; returns the count.
func _plant_marks(g: Game, rec: BattleRecord) -> int:
	var made := 0
	var step := maxi(floori(float(g.map.hex_count()) / float(MARKS * 3)), 1)
	for i: int in range(0, g.map.hex_count(), step):
		if made >= MARKS:
			break
		if g.map.land[i] == 0:
			continue
		_keep(g, rec, g.map.hex_of(i), "Battle of Perf %d, 1480" % made)
		made += 1
	return made


func _measure_dock(app: Node, war: Object, g: Game, record_id: int) -> void:
	var stack := app.call("stack") as Control
	var worst := 0.0
	for _i: int in RUNS:
		g.view_cache.clear()
		var t0 := Time.get_ticks_usec()
		war.call("open_battle", record_id)
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		stack.call("back")
		await _frames(2)
	_r["battle_dock_open_ms"] = worst
	war.call("open_battle", record_id)
	await _frames(2)
	var dock := war.call("dock") as Object
	var step_worst := 0.0
	if dock == null:
		step_worst = INF
	else:
		dock.call("go_to_day", 1)
		await _frames(2)
		var days := int(dock.call("day_count"))
		for _d: int in maxi(days - 1, 1):
			g.view_cache.clear()
			var t1 := Time.get_ticks_usec()
			dock.call("step_day", 1)
			RenderingServer.force_draw(false)
			step_worst = maxf(step_worst, float(Time.get_ticks_usec() - t1) / 1000.0)
	_r["dock_day_step_ms"] = step_worst
	stack.call("back")
	await _frames(2)


func _measure_marks(marks: Node, g: Game) -> void:
	var palette := MapModes.palette(g, false)
	var total := 0.0
	for _i: int in MARK_RUNS:
		g.view_cache.clear()
		var t0 := Time.get_ticks_usec()
		marks.call("refresh", g, g.player, palette, [])
		total += float(Time.get_ticks_usec() - t0) / 1000.0
	_r["war_marks_refresh_ms"] = total / float(MARK_RUNS)
	_r["m7_mark_nodes"] = int(marks.call("mark_count"))


## An army of the player's beside an army of the foe's, on the player's land and the foe's (the rig of the odds' kind: attack).
func _measure_odds(app: Node, session: Node, armies: Node, g: Game, foe: StringName) -> void:
	var pair := _pair(g, foe)
	if pair.is_empty():
		printerr("perf_ui: no hex of Genoa borders the foe's land (the odds row)")
		_r["odds_hover_ms"] = INF
		return
	var here := Armies.at(g, pair["mine"] as Vector2i)  # the M6 rows left an army on most of the player's hexes
	var mine: Army = here[0] if not here.is_empty() else ArmyFixture.army(g, g.player, pair["mine"] as Vector2i, 0, SIDE)
	ArmyFixture.army(g, foe, pair["theirs"] as Vector2i, 0, SIDE)
	Sight.refresh(g)  # the rig's armies see their surroundings (the vision phase has not run)
	g.version += 1
	var hover := ((app.call("hud") as Object).call("map_hover") as Object)
	var hex: Vector2i = pair["theirs"]
	var at := Vector2(640.0, 360.0)
	armies.call("select_army", mine.id)
	await _frames(2)
	_r["m7_odds_kind"] = str(OddsView.of(g, g.player, mine.id, hex).get("kind", ""))
	var worst := 0.0
	for _i: int in RUNS:
		g.view_cache.clear()
		var t0 := Time.get_ticks_usec()
		hover.call("order_cursor_moved", hex, at)
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		hover.call("order_cursor_moved", pair["mine"], at)
		await _frames(1)
	armies.call("clear_army")
	_r["odds_hover_ms"] = worst


## {mine, theirs}: a land hex of the player's with a land neighbour of the foe's that holds no army; {} when none.
static func _pair(g: Game, foe: StringName) -> Dictionary:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or Territory.owner_tag(g, hex) != g.player:
			continue
		for d: int in 6:
			var beside := g.map.neighbour(hex, d)
			if g.map.has(beside) and g.map.is_land(beside) and Territory.owner_tag(g, beside) == foe and Armies.at(g, beside).is_empty():
				return {"mine": hex, "theirs": beside}
	return {}


func _measure_menu(armies: Node, g: Game, hex: Vector2i) -> void:
	armies.call("clear_army")
	var found := armies.find_children("*", "HexMenu", false, false)
	if found.is_empty() or hex.x < 0:
		_r["hex_menu_war_ms"] = INF
		return
	var menu := found[0] as Object
	var worst := 0.0
	for _i: int in RUNS:
		g.view_cache.clear()
		var t0 := Time.get_ticks_usec()
		var opened := bool(menu.call("open_for", hex, Vector2(360.0, 260.0)))
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		if not opened:
			worst = INF
		menu.call("hide")
		await _frames(2)
	_r["hex_menu_war_ms"] = worst


func _measure_areas(armies: Node, wars: Node, g: Game) -> void:
	var mine: Array = Armies.of_country(g, g.player)
	if mine.is_empty():
		_r["area_show_ms"] = INF
		return
	var army_id: int = int((mine[0] as Object).get("id"))
	var worst := 0.0
	for _i: int in RUNS:
		armies.call("clear_army")
		await _frames(2)
		g.view_cache.clear()
		var t0 := Time.get_ticks_usec()
		armies.call("select_army", army_id)
		wars.call("_build_areas")
		RenderingServer.force_draw(false)
		worst = maxf(worst, float(Time.get_ticks_usec() - t0) / 1000.0)
		if not bool(wars.call("areas_on")):
			printerr("perf_ui: the castle areas did not open")
			worst = INF
		await _frames(2)
	armies.call("clear_army")
	_r["area_show_ms"] = worst
