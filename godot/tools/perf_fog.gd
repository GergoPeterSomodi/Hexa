## The fog rows of the fog build (docs/architecture/fog-build-spec.md 8, FG18), measured by tools/perf_core.gd after the M5 rows
## (split out of perf_core.gd for its size):
##   discovered_bytes_ms  MapModes.discovered_bytes for one viewer, cold (the view cache cleared and the version moved before each
##                        run), worst of `runs`, on the made-up Europe (its largest country, the viewer) and on north Italy
##                        (Genoa); the row is the worse of the two. Europe and north Italy are kept apart in the table.
##   land_seen_ms         Knowledge.land_seen for every viewer of every country, cold, worst of `runs`: 60 x 60 on the made-up
##                        Europe and 13 x 13 on north Italy; the row is the worse of the two.
## Nothing is asserted here: the budget (tests/perf_core_budget.json) decides, in perf_core.gd.
class_name PerfFog
extends RefCounted


## Fills `out` with the fog rows. `europe` is the made-up Europe with `europe_tag` as its viewer; `ni` is north Italy (null: skipped).
static func measure(europe: Game, europe_tag: StringName, ni: Game, runs: int, out: Dictionary) -> void:
	var eu_bytes := _cold_worst(europe, func() -> void: MapModes.discovered_bytes(europe, europe_tag), runs)
	var ni_bytes := 0.0
	var ni_seen := 0.0
	if ni != null:
		ni_bytes = _cold_worst(ni, func() -> void: MapModes.discovered_bytes(ni, ni.player), runs)
		ni_seen = _land_seen_all(ni, runs)
	var eu_seen := _land_seen_all(europe, runs)
	out["discovered_bytes_eu_ms"] = eu_bytes
	out["discovered_bytes_ni_ms"] = ni_bytes
	out["discovered_bytes_ms"] = maxf(eu_bytes, ni_bytes)
	out["land_seen_eu_ms"] = eu_seen
	out["land_seen_ni_ms"] = ni_seen
	out["land_seen_ms"] = maxf(eu_seen, ni_seen)


## The worst of `runs` calls of `call` with the view cache cleared and the version moved first (the views from cold).
static func _cold_worst(game: Game, call: Callable, runs: int) -> float:
	var worst := 0.0
	for _n: int in runs:
		game.view_cache.clear()
		game.version += 1
		var t := Time.get_ticks_usec()
		call.call()
		worst = maxf(worst, float(Time.get_ticks_usec() - t) / 1000.0)
	return worst


## Knowledge.land_seen of every country as viewer, of every country: the pairs, cold, worst of `runs` runs (ms).
static func _land_seen_all(game: Game, runs: int) -> float:
	var tags: Array[StringName] = []
	for c: Country in game.countries:
		tags.append(c.tag)
	var worst := 0.0
	for _n: int in runs:
		game.view_cache.clear()
		game.version += 1
		var t := Time.get_ticks_usec()
		for viewer: StringName in tags:
			for other: StringName in tags:
				Knowledge.land_seen(game, viewer, other)
		worst = maxf(worst, float(Time.get_ticks_usec() - t) / 1000.0)
	return worst
