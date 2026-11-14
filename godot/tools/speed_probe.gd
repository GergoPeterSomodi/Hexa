## Speed probe (0.3.0 item 7): the map builder's stages, its road search and territory against Godot's built-in path
## finder (AStar2D) on the same searches, and the map file's load. Headless, typed GDScript; best of REPEATS runs for the
## searches and the load. The stages are timed once (one build), as the shell runs them.
## Writes the rows to docs/reports/0.3.0-speed.json; tools/map_report.gd prints them in the map check report.
## Run: godot --headless --path godot -s res://tools/speed_probe.gd -- --out=<absolute path of the .json>
## The searches run on the state after the terrain and the countries' seeds (before the roads are laid), the same
## state for both path finders; the costs of the two are compared pair by pair.
extends SceneTree

const REPEATS := 3
const DEFAULT_OUT := "res://../docs/reports/0.3.0-speed.json"


func _init() -> void:
	var out := _argument("--out=", ProjectSettings.globalize_path(DEFAULT_OUT).simplify_path())
	var rows: Array = []
	var data := EuropeData.load_europe()

	# 1. One build, every stage timed (the shell's stages).
	var steps := MapBuildSteps.new(data)
	var total_ms := 0.0
	var stage_rows: Array = []
	while not steps.is_done():
		var label := steps.next_label()
		var started := Time.get_ticks_usec()
		steps.run_next()
		var ms := float(Time.get_ticks_usec() - started) / 1000.0
		total_ms += ms
		stage_rows.append([label, ms])
	for item: Array in stage_rows:
		rows.append(["builder: %s" % item[0], _ms(float(item[1])), "one run"])
	rows.append(["builder: total", _ms(total_ms), "all nine stages, one build (the shell's progress bar)"])

	# 2. The state before the roads: the stages 0 to 6 on a map of its own.
	var before := MapBuildSteps.new(data)
	for i in 7:
		before.run_next()
	var map := before.map
	var geo := Geo.new(float(data.projection["lon0"]), float(data.projection["col_deg"]),
			float(data.projection["row_deg"]), float(data.projection["y_top"]),
			int(data.projection["cols"]), int(data.projection["rows"]))
	var seeds: Array[CountryBuilder.SeedPoint] = CountryBuilder._countries(map, data, geo)
	var territory_ms := _best(func() -> void: CountryBuilder._owners(map, data, seeds))
	rows.append(["territory (nearest seed for every land hex)", _ms(territory_ms), "GDScript, best of %d" % REPEATS])

	# 3. Road search: each town and its capital, GDScript (RoadBuilder._connect) against AStar2D.
	var pairs := _town_pairs(map)
	var gd_ms := _best(func() -> void: _gdscript_searches(map, data, pairs))
	var astar_ms := _best(func() -> void: _astar_searches(map, data, pairs))
	var agree := _costs_agree(map, data, pairs)
	rows.append(["road search, GDScript (%d town pairs)" % pairs.size(), _ms(gd_ms),
			"RoadBuilder._connect, best of %d" % REPEATS])
	rows.append(["road search, AStar2D (same pairs)", _ms(astar_ms),
			"Godot's built-in path finder, best of %d" % REPEATS])
	rows.append(["ratio GDScript / AStar2D", "%.1f" % (gd_ms / maxf(astar_ms, 0.001)), "above 1: AStar2D is faster"])
	rows.append(["path costs equal (AStar2D against GDScript)", "%d of %d" % [agree, pairs.size()],
			"the same cost is the same route to the same goal"])
	rows.append(["road search as built (stage 7)", _ms(float(stage_rows[7][1])), "the whole roads stage, one run"])

	# 4. The map file: read and parse, best of REPEATS.
	var text_ref: Array = [""]
	var read_ms := _best(func() -> void: text_ref[0] = FileAccess.get_file_as_string(MapFile.PATH))
	var text: String = text_ref[0]
	var parse_ms := _best(func() -> void: MapFile.from_text(text))
	rows.append(["map file: read", _ms(read_ms), "%d bytes" % text.to_utf8_buffer().size()])
	rows.append(["map file: parse to MapData", _ms(parse_ms), "best of %d" % REPEATS])
	rows.append(["map file: load (read and parse)", _ms(read_ms + parse_ms), "the game's start, before the view"])

	var result := {
		"machine": "%s, %s" % [OS.get_processor_name(), OS.get_name()],
		"note": "Godot 4.7.2 headless (the builder runs as a tool). Times are wall-clock milliseconds.",
		"rows": rows,
	}
	for row: Array in rows:
		print("%-50s %-14s %s" % [row[0], row[1], row[2]])
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		printerr("speed probe: cannot write %s" % out)
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	print("speed probe: wrote %s" % out)
	quit(0)


## Milliseconds of a run, best of REPEATS.
func _best(run: Callable) -> float:
	var best := INF
	for i in REPEATS:
		var started := Time.get_ticks_usec()
		run.call()
		best = minf(best, float(Time.get_ticks_usec() - started) / 1000.0)
	return best


static func _ms(ms: float) -> String:
	return "%.1f ms" % ms


func _argument(prefix: String, default_value: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return default_value


## Each town (size 2 or more, or a city) and its country's capital, in the builder's order.
func _town_pairs(map: MapData) -> Array:
	var pairs: Array = []
	for tag: String in map.country_order:
		var cap: Vector2i = map.countries[tag].capital
		for prov: Province in map.provinces_of(tag):
			if (prov.settlement >= 2 or prov.city) and prov.pos != cap:
				pairs.append([prov.pos, cap])
	return pairs


func _gdscript_searches(map: MapData, data: EuropeData, pairs: Array) -> void:
	for pair: Array in pairs:
		var goals: Dictionary = {pair[1]: true}
		RoadBuilder._connect(map, data, pair[0], goals, 1 << 30, "")


func _astar_searches(map: MapData, data: EuropeData, pairs: Array) -> void:
	var graph := _graph(map, data)
	for pair: Array in pairs:
		graph.get_id_path(_id(map, pair[0]), _id(map, pair[1]))


static func _id(map: MapData, pos: Vector2i) -> int:
	return pos.y * map.cols + pos.x


static func _pos(map: MapData, id: int) -> Vector2i:
	return Vector2i(id % map.cols, floori(float(id) / float(map.cols)))


## The land of the map as an AStar2D graph: a point per land hex at its centre, with the step cost of entering it (half
## steps, as RoadBuilder) as its weight, and no edge across a crest. Roads are not in it (the state has none yet).
func _graph(map: MapData, data: EuropeData) -> AStar2D:
	var graph := AStar2D.new()
	for pos: Vector2i in map.provinces.keys():
		graph.add_point(_id(map, pos), HexGrid.hex_center(pos), float(_step(map, data, pos)))
	for pos: Vector2i in map.provinces.keys():
		for n: Vector2i in HexGrid.neighbours(pos):
			if map.provinces.has(n) and not map.is_ridge_step(pos, n):
				graph.connect_points(_id(map, pos), _id(map, n), false)
	return graph


static func _step(map: MapData, data: EuropeData, pos: Vector2i) -> int:
	var prov: Province = map.provinces[pos]
	return maxi(1, int(round(float(data.terrain_move[prov.terrain]) * 2.0)))


## How many pairs AStar2D routes at the same cost as RoadBuilder (both routes priced in half steps).
func _costs_agree(map: MapData, data: EuropeData, pairs: Array) -> int:
	var graph := _graph(map, data)
	var same := 0
	for pair: Array in pairs:
		var goals: Dictionary = {pair[1]: true}
		var ours: Array[Vector2i] = RoadBuilder._connect(map, data, pair[0], goals, 1 << 30, "")
		var theirs := graph.get_id_path(_id(map, pair[0]), _id(map, pair[1]))
		if ours.is_empty() or theirs.is_empty():
			continue
		var cost_ours := 0
		for i in range(1, ours.size()):
			cost_ours += _step(map, data, ours[i])
		var cost_theirs := 0
		for i in range(1, theirs.size()):
			cost_theirs += _step(map, data, _pos(map, theirs[i]))
		if cost_ours == cost_theirs:
			same += 1
	return same
