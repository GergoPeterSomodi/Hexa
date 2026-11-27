## The soak (docs/architecture/m8-build-spec.md 4.17, D41; M8 plan K22): all-AI games (and the passive seat's) for many seeds, the
## invariants of tests/core/invariants.gd after every season, the expected ranges, a JSON report and a Markdown summary. A failed game
## ends with the lines of its broken invariants and the line that replays it; the exit code is 1 on a broken game, an engine or script
## error, or a judged range out of range. Headless, no GUT. Suites: ai (seeds 1-100, 80 seasons), passive (1-20, 80), europe (1-4, 40).
##
##   godot --headless --path godot -s res://tools/soak.gd -- --suite=ai --seeds=1-25 --seasons=80 --out=soak.json --summary=FILE
##   godot --headless --path godot -s res://tools/soak.gd -- --quick                  # every suite, short
##   godot --headless --path godot -s res://tools/soak.gd -- --suite=ai --seed=17     # replay one game (a failure prints this)
##   godot --headless --path godot -s res://tools/soak.gd -- --suite=ai --seed=17 --digest
##   godot --headless --path godot -s res://tools/soak.gd -- --merge=a.json,b.json    # the ranges over the merged games of one suite
##   ... --plant=money    (tests only: a treasury is edited mid-game, the `money` invariant must break it)
##   ... --plant=fog      (tests only: an explored hex is cleared mid-game, the `explored` invariant must break it)
##   ... --plant=moves    (tests only: an army gets its move points back mid-season, `grown` and `spent` must break it)
extends SceneTree

const SUITES := {
	"ai": {"from": 1, "to": 100, "seasons": 80, "quick_to": 3, "quick_seasons": 12},
	"passive": {"from": 1, "to": 20, "seasons": 80, "quick_to": 2, "quick_seasons": 12},
	"europe": {"from": 1, "to": 4, "seasons": 40, "quick_to": 1, "quick_seasons": 2},
}

var _suite := "ai"
var _all := false
var _from := -1
var _to := -1
var _seasons := -1
var _quick := false
var _digest := false
var _out := ""
var _summary := ""
var _merge := ""
var _plant := ""


func _initialize() -> void:  # not _init: the classes are known to the parser only from here on
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			_suite = arg.substr(8)
		elif arg.begins_with("--seeds="):
			var parts := arg.substr(8).split("-")
			_from = int(parts[0])
			_to = int(parts[parts.size() - 1])
		elif arg.begins_with("--seed="):
			_from = int(arg.substr(7))
			_to = _from
		elif arg.begins_with("--seasons="):
			_seasons = maxi(int(arg.substr(10)), 1)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--summary="):
			_summary = arg.substr(10)
		elif arg.begins_with("--merge="):
			_merge = arg.substr(8)
		elif arg.begins_with("--plant="):
			_plant = arg.substr(8)
		elif arg == "--quick":
			_quick = true
		elif arg == "--digest":
			_digest = true
	if not _merge.is_empty():
		quit(_run_merge())
		return
	if _quick:
		quit(_run_quick())
		return
	if not SUITES.has(_suite):
		printerr("soak: no suite '%s' (ai, passive, europe)" % _suite)
		quit(2)
		return
	var spec: Dictionary = SUITES[_suite]
	var from := _from if _from > 0 else int(spec["from"])
	var to := _to if _to > 0 else int(spec["to"])
	quit(_run_suite(_suite, from, to, _seasons if _seasons > 0 else int(spec["seasons"])))


func _run_quick() -> int:
	var status := 0
	for suite: String in SUITES:
		var spec: Dictionary = SUITES[suite]
		status = maxi(status, _run_suite(suite, 1, int(spec["quick_to"]), int(spec["quick_seasons"]), suite != "ai"))
	return status


## Plays seeds from to to of a suite; prints, writes and returns the exit code. `append` keeps an earlier --out and --summary.
func _run_suite(suite: String, from: int, to: int, seasons: int, append: bool = false) -> int:
	var logger := SoakGame.SoakLogger.new()
	OS.add_logger(logger)
	var games: Array = []
	for s: int in range(from, to + 1):
		print("soak: %s seed %d, %d seasons" % [suite, s, seasons])
		Invariants.planted = _plant  # the fog and moves plants are read by the invariants (tests only); cleared after the suite
		var rec := SoakGame.play(suite, s, seasons, logger, _plant)
		rec["replay"] = _replay_line(suite, s, seasons)
		games.append(rec)
		var failure: Array = rec["failure"]
		if not failure.is_empty():
			print("BROKEN soak game %s seed %d after %d seasons:" % [suite, s, int(rec["played"])])
			for line: Variant in failure:
				print("  " + str(line))
			print("replay: " + str(rec["replay"]))
		if _digest:
			print("digest %s seed %d: %s" % [suite, s, str(rec.get("digest", ""))])
	OS.remove_logger(logger)
	Invariants.planted = ""
	return _report(suite, games, append)


func _replay_line(suite: String, seed_value: int, seasons: int) -> String:
	var line := "\"$GODOT\" --headless --path godot -s res://tools/soak.gd -- --suite=%s --seed=%d --seasons=%d" % [suite, seed_value, seasons]
	return line + (" --plant=" + _plant if not _plant.is_empty() else "")


func _run_merge() -> int:
	var games: Array = []
	var suite := ""
	for path: String in _merge.split(","):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			printerr("soak: cannot read %s" % path)
			return 2
		var body: Variant = JSON.parse_string(f.get_as_text())
		if not (body is Dictionary):
			printerr("soak: %s is not a soak report" % path)
			return 2
		suite = str((body as Dictionary).get("suite", suite))
		games.append_array((body as Dictionary).get("games", []) as Array)
	return _report(suite, games, false)


## The tables, the JSON and the summary; the exit code.
func _report(suite: String, games: Array, append: bool) -> int:
	var table := SoakRanges.rows(suite, games)
	var text := SoakRanges.markdown(suite, games, table)
	print(text)
	var broken := games.filter(func(r: Dictionary) -> bool: return not (r["failure"] as Array).is_empty())
	var out_of_range := SoakRanges.failed(table)
	if not broken.is_empty():
		print("soak %s: %d game(s) BROKEN" % [suite, broken.size()])
	if out_of_range:
		print("soak %s: a range is OUT OF RANGE" % suite)
	if not _out.is_empty():
		var path := _out
		if append:
			path = _out.get_basename() + "_" + suite + "." + _out.get_extension()
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"suite": suite, "games": games, "table": table, "broken": broken.size()}))
	if not _summary.is_empty():
		var f := FileAccess.open(_summary, FileAccess.READ_WRITE if FileAccess.file_exists(_summary) else FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_string(text + "\n")
	return 1 if (not broken.is_empty() or out_of_range) else 0
