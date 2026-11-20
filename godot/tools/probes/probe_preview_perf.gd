## Times the works card's views on the made-up Europe (494 x 247, 60 countries, the real families, 10 work slots), headless:
##   godot --headless --path godot -s res://tools/probes/probe_preview_perf.gd
## The world takes minutes to build. Rows (spec 8): options_of on a hex with the most build options, cold (a new game
## version each time, so the country's land is summed up again: the first hover after a season) and warm (cached);
## one ImprovePreview card with the country's base warm and the option cold; EconomyPreview.expected, cold.
extends SceneTree

const RUNS := 20


func _avg(label: String, f: Callable) -> void:
	var t := Time.get_ticks_usec()
	for n: int in RUNS:
		f.call()
	print("%-52s %.3f ms" % [label, (Time.get_ticks_usec() - t) / 1000.0 / RUNS])


func _initialize() -> void:
	var game := PerfFixture.europe_game(2)  # the made-up Europe, two seasons played (works at random options)
	if game == null:
		quit(1)
		return
	var tag := PerfFixture.largest_tag(game)
	var best := Countries.by_tag(game, tag)
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
	game.version += 1
	EconomyPreview.worth_of(game, tag, hex)
	_avg("worth_of, warm (content cached)", func() -> void: EconomyPreview.worth_of(game, tag, hex))
	var t := Time.get_ticks_usec()
	game.version += 1
	EconomyPreview.worth_by_hex(game, tag)
	print("%-52s %.3f ms" % ["worth_by_hex, cold (once per version)", (Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	game.view_cache.clear()
	Territory.neighbours(game, best.id)
	print("%-52s %.3f ms" % ["Territory.neighbours, cold (once per owner change)", (Time.get_ticks_usec() - t) / 1000.0])
	_avg("Territory.neighbours / Knowledge.known, warm", func() -> void: Knowledge.known(game, tag))
	game.version += 1
	EconomyPreview.expected(game, tag)
	t = Time.get_ticks_usec()
	EconomyPreview.with(game, tag, {}, 8)
	print("%-52s %.3f ms" % ["with(8) after expected (reminders), same version", (Time.get_ticks_usec() - t) / 1000.0])
	quit()
