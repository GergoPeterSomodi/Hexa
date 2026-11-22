## The M7 view rows of tools/perf_core.gd (m7-build-spec.md 8), uncached: the game's view cache is cleared before each call.
##   odds_ms         OddsView.of of an army of 8 companies against the army beside it, mean of RUNS
##   battle_view_ms  BattleView.of of the longest record kept (8 days when one went so long), mean of RUNS
##   siege_view_ms   SiegeView.at of a standing siege, mean of RUNS
##   area_lines_ms   AreaLines.for_chunk over every chunk of the map for the viewer with the most held-area hexes of its enemies,
##                   the area bytes cold (the slices' total), worst of COLD_RUNS
## Also written: odds_kind (the card's kind: attack when the rig works), area_hexes (the hexes the lines draw round) and
## area_lines (their count), so a row that measures nothing shows. A row that cannot be measured is -1.
class_name PerfWarViews
extends RefCounted

const RUNS := 50
const COLD_RUNS := 3


## Writes the rows into `r`. `siege` is a siege standing now (null when none).
static func measure(game: Game, siege: Siege, r: Dictionary) -> void:
	var pair := PerfFixture.odds_pair(game)
	r["odds_ms"] = -1.0
	if not pair.is_empty():
		var viewer := StringName(pair["viewer"])
		var army := int(pair["army"])
		var hex := pair["hex"] as Vector2i
		r["odds_ms"] = _cold_mean(game, func() -> void: OddsView.of(game, viewer, army, hex))
		r["odds_kind"] = str(OddsView.of(game, viewer, army, hex).get("kind", ""))
	var longest: BattleRecord = null
	for rec: BattleRecord in game.battle_records:
		if longest == null or rec.frames.size() > longest.frames.size():
			longest = rec
	r["battle_view_ms"] = -1.0
	if longest != null:
		var seer := longest.attacker
		var id := longest.id
		r["battle_view_ms"] = _cold_mean(game, func() -> void: BattleView.of(game, seer, id))
	r["siege_view_ms"] = -1.0
	if siege != null:
		var besieger := siege.besieger
		var at := siege.hex
		r["siege_view_ms"] = _cold_mean(game, func() -> void: SiegeView.at(game, besieger, at))
	_area_lines(game, r)


static func _area_lines(game: Game, r: Dictionary) -> void:
	var viewer := &""
	var most := 0
	for w: War in game.wars:
		if not w.live():
			continue
		for tag: StringName in [w.a, w.b]:
			game.view_cache.clear()
			var held := 0
			for b: int in AreaLines.area_bytes(game, tag):
				held += b
			if held > most:
				most = held
				viewer = tag
	r["area_hexes"] = most
	var chunks := Vector2i(ceili(float(game.map.cols) / EdgeLines.CHUNK), ceili(float(game.map.rows) / EdgeLines.CHUNK))
	var worst := 0.0
	var lines := 0
	for _n: int in COLD_RUNS:
		game.view_cache.clear()
		var t := Time.get_ticks_usec()
		lines = 0
		for cy: int in chunks.y:
			for cx: int in chunks.x:
				lines += AreaLines.for_chunk(game, viewer, Vector2i(cx, cy)).size()
		worst = maxf(worst, float(Time.get_ticks_usec() - t) / 1000.0)
	r["area_lines"] = lines
	r["area_lines_ms"] = worst


static func _cold_mean(game: Game, call: Callable) -> float:
	var total := 0.0
	for _n: int in RUNS:
		game.view_cache.clear()
		var t := Time.get_ticks_usec()
		call.call()
		total += float(Time.get_ticks_usec() - t) / 1000.0
	return total / float(RUNS)
