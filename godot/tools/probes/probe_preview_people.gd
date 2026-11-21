## Times the previews with people on the made-up Europe (docs/architecture/m5-build-spec.md 4.10, 5.0 R5, 8; task P7):
## EconomyPreview.expected (uncached: the baseline of one season with its people step), Reminders.unfinished (uncached: the
## eight-season run), one ImprovePreview card with the country's baseline warm and the option cold (preview_ms), and the same
## with everything cold, for the largest country, after some seasons played with the people phase between works and stats.
## Headless, no window, no GUT. A probe: it prints a table and fails on nothing.
##
##   godot --headless --path godot -s res://tools/probes/probe_preview_people.gd -- [--seasons=4] [--cols=494 --rows=247 --countries=60]
## A smaller world (say --cols=247 --rows=124 --countries=15) builds in a minute.
extends SceneTree

const GAME_DEFS := "res://data/defs/game_defs.tres"
const SEED := 1480
const RUNS := 5

var _seasons := 4
var _cols := 494
var _rows := 247
var _countries := 60


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seasons="):
			_seasons = maxi(int(arg.substr(10)), 0)
		elif arg.begins_with("--cols="):
			_cols = maxi(int(arg.substr(7)), 20)
		elif arg.begins_with("--rows="):
			_rows = maxi(int(arg.substr(7)), 20)
		elif arg.begins_with("--countries="):
			_countries = maxi(int(arg.substr(12)), 2)
	quit(_run())


func _ms(from_usec: int) -> float:
	return float(Time.get_ticks_usec() - from_usec) / 1000.0


func _run() -> int:
	var map := FakeMap.build(_cols, _rows, SEED)
	var built := FakeScenario.build(map, _countries, SEED)
	var defs := built["defs"] as GameDefs
	var real := ResourceLoader.load(GAME_DEFS, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if real == null:
		printerr("probe_preview_people: cannot load %s" % GAME_DEFS)
		return 1
	defs.families = real.families
	defs.goods = real.goods
	var game := Game.new_scenario(map, defs, built["scenario"] as ScenarioDef, SEED)
	game.act("choose_country", {"tag": game.countries[0].tag})
	for _n: int in _seasons:
		Season.run(game)
	var best := game.countries[0]
	for c: Country in game.countries:
		if Territory.count(game, c.id) > Territory.count(game, best.id):
			best = c
	var tag := best.tag
	var active := People.active(game, StateView.of(game.state), best.id).size()
	print("fake Europe %d x %d, %d countries, %d seasons played; largest country %s: %d hexes, %d active for the people step" % [
		_cols, _rows, game.countries.size(), _seasons, tag, Territory.count(game, best.id), active])

	var total := 0.0
	for n: int in RUNS:
		game.version += 1
		var t := Time.get_ticks_usec()
		EconomyPreview.expected(game, tag)
		total += _ms(t)
	print("expected_ms (budget 2), uncached, the country's land summed once:      %.2f" % (total / RUNS))
	total = 0.0
	for n: int in RUNS:
		game.version += 1
		var t := Time.get_ticks_usec()
		Reminders.unfinished(game, tag)
		total += _ms(t)
	print("reminders_ms (budget 6), uncached (eight seasons of the baseline):     %.2f" % (total / RUNS))

	var hex := Vector2i(-1, -1)
	var most := 0
	for i: int in Territory.districts(game, best.id):
		var n := Improve.build_options(game, game.map.hex_of(i)).size()
		if n > most:
			most = n
			hex = game.map.hex_of(i)
	if hex.x < 0:
		printerr("probe_preview_people: no hex with build options")
		return 1
	var rows := ImprovePreview.options_of(game, tag, hex)
	var option := {"action": rows[0]["action"], "family": rows[0]["family"]}
	game.version += 1
	ImprovePreview.of(game, tag, hex, option)  # the baseline of this version
	var t := Time.get_ticks_usec()
	for n: int in RUNS:
		ImprovePreview._make(game, tag, hex, option["action"], int(option["family"]))
	print("preview_ms (budget 1), baseline warm, the option cold (%s):  %.2f" % [str(option), _ms(t) / RUNS])
	total = 0.0
	for n: int in RUNS:
		game.version += 1
		t = Time.get_ticks_usec()
		ImprovePreview._make(game, tag, hex, option["action"], int(option["family"]))
		total += _ms(t)
	print("one card with the baseline cold too (version changed):                 %.2f" % (total / RUNS))
	# An upgrade of the largest town (a settlement: its room, its people, the level step).
	for i: int in Territory.districts(game, best.id):
		if int(game.state.main_use[i]) == Economy.SETTLEMENTS and int(game.state.level[i]) < 3:
			var town := game.map.hex_of(i)
			game.version += 1
			ImprovePreview.of(game, tag, town, {"action": Works.UPGRADE, "family": 0})
			t = Time.get_ticks_usec()
			for n: int in RUNS:
				ImprovePreview._make(game, tag, town, Works.UPGRADE, 0)
			print("a settlement upgrade card, baseline warm:                              %.2f" % (_ms(t) / RUNS))
			break
	_parts(game, tag)
	return 0


## Where the baseline's time goes (a diagnostic).
func _parts(game: Game, tag: StringName) -> void:
	var c := Countries.by_tag(game, tag)
	game.version += 1
	var t := Time.get_ticks_usec()
	var own := StateView.of(game.state)
	var act := People.active(game, own, c.id)
	print("  People.active %.2f ms (%d)" % [_ms(t), act.size()])
	t = Time.get_ticks_usec()
	var holder := EconomyPreview._new_holder(game, tag)
	print("  _new_holder (incl. active, profile, standing) %.2f ms" % _ms(t))
	t = Time.get_ticks_usec()
	var rec := EconomyPreview._record(game, holder, 1, 0)
	(holder["records"] as Array).append(rec)
	print("  _record 0 %.2f ms" % _ms(t))
	t = Time.get_ticks_usec()
	EconomyPreview._step_record(game, holder, 1)
	print("  _step_record 0 %.2f ms" % _ms(t))
	t = Time.get_ticks_usec()
	var rec1 := EconomyPreview._record(game, holder, 1, 1)
	print("  _record 1 %.2f ms" % _ms(t))
	(holder["records"] as Array).append(rec1)
	t = Time.get_ticks_usec()
	EconomyPreview._step_record(game, holder, 1)
	print("  _step_record 1 %.2f ms" % _ms(t))

