## Times the works card's views on the made-up Europe (494 x 247, 60 countries, the real families, 10 work slots), headless:
##   godot --headless --path godot -s res://tools/probes/probe_preview_perf.gd
## The world takes minutes to build. Rows (spec 8): options_of on a hex with the most build options, cold (a new game
## version each time, so the country's land is summed up again: the first hover after a season) and warm (cached);
## one ImprovePreview card with the country's base warm and the option cold; EconomyPreview.expected, cold.
extends SceneTree

const GAME_DEFS := "res://data/defs/game_defs.tres"
const RUNS := 20


func _avg(label: String, f: Callable) -> void:
	var t := Time.get_ticks_usec()
	for n: int in RUNS:
		f.call()
	print("%-52s %.3f ms" % [label, (Time.get_ticks_usec() - t) / 1000.0 / RUNS])


func _initialize() -> void:
	var map := FakeMap.build(494, 247, 1480)
	var built := FakeScenario.build(map, 60, 1480)
	var defs := built["defs"] as GameDefs
	var real := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	defs.families = real.families
	defs.work_slots_base = 10
	var game := Game.new_scenario(map, defs, built["scenario"] as ScenarioDef, 1480)
	var best := game.countries[0]
	for c: Country in game.countries:
		if Territory.count(game, c.id) > Territory.count(game, best.id):
			best = c
	var tag := best.tag
	game.act("choose_country", {"tag": tag})
	Season.run(game)
	Season.run(game)
	var hex := Vector2i(-1, -1)
	var most := 0
	for i: int in Territory.districts(game, best.id):
		var n := Improve.build_options(game, game.map.hex_of(i)).size()
		if n > most:
			most = n
			hex = game.map.hex_of(i)
	var rows := ImprovePreview.options_of(game, tag, hex)
	print("country %s with %d hexes; hex %s with %d rows" % [tag, Territory.count(game, best.id), hex, rows.size()])
	var option := {"action": rows[0]["action"], "family": rows[0]["family"]}
	_avg("options_of, cold (a new version each time)", func() -> void:
		game.version += 1
		ImprovePreview.options_of(game, tag, hex))
	_avg("options_of, warm", func() -> void: ImprovePreview.options_of(game, tag, hex))
	_avg("options_of with full chips, cold", func() -> void:
		game.version += 1
		ImprovePreview.options_of(game, tag, hex, true))
	game.version += 1
	ImprovePreview.of(game, tag, hex, option)  # the country's land summed up for this version
	_avg("one card, the country's base warm", func() -> void:
		ImprovePreview._make(game, tag, hex, option["action"], int(option["family"])))
	_avg("EconomyPreview.expected, cold", func() -> void:
		game.version += 1
		EconomyPreview.expected(game, tag))
	quit()
