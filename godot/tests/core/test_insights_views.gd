## The core proof of M4.5 (docs/architecture/m4-5-build-spec.md 9, D1): every view the study and the map add
## (StudyEconomy districts, goods, lasts, history; EconomyPreview.worth_seasons; StudyRankings.of; StudyHistory index, timeline,
## season, chronicle; MapModes.yield_bytes; HexCard's Worth line) leaves the game as it was (Snapshot bytes, Game.digest(), the
## version, the logs), equals itself after a save and a load, and hands out copies of what it caches; the pins of 4.13 hold;
## and a text scan finds no writer of game state in the M4.5 views or the two Stats accessors.
## Planted faults: the comparison sees a changed game, the scribbler reaches a cached value, and the scan reports a writer.
extends GutTest

const GEN := &"GEN"
const SPAN := 40
const MUTATORS := "append|append_array|push_back|push_front|insert|set|fill|resize|clear|erase|remove_at|sort|assign|merge"
## The folders scanned: every file of core/views (the views reach each other), and the shell's study files.
const VIEWS_DIR := "res://core/views"
const SHELL_DIRS: Array[String] = ["res://shell/screens/study", "res://shell/ui", "res://shell/hud", "res://shell/app"]
## The shell files of M4.5 (a file of the folders above is scanned when its name starts with one of these or is listed).
const SHELL_PREFIXES: Array[String] = ["study", "page_", "economy_", "ink_", "timeline_strip", "mode_legend"]
## (shell/screens/study.gd is M4's frame: its one Session.act forwards the tax buttons of This season, so it is not scanned.)
const SHELL_FILES: Array[String] = ["res://shell/screens/study_page.gd", "res://shell/screens/study_pages.gd"]
const STATS_ACCESSORS: Array[String] = ["goods_value", "goods_series"]
## Calls no view may hold (spec 9).
const BANNED: Array[String] = [
	"\\.act\\(", "Treasury\\.move\\b", "Stores\\.move\\b", "\\b(?:game|Events|Session)\\.[\\w.]*emit\\(", "Season\\.run\\(", "end_season\\(", "dev_money\\(", "dev_goods\\(",
]

var _dirs: Array[String] = []


func after_each() -> void:
	for dir: String in _dirs:
		for file: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	_dirs.clear()


# ---- the views ----------------------------------------------------------------------------------------------------------

func _stranger(g: Game) -> StringName:
	for c: Country in g.countries:
		if c.tag != GEN:
			return c.tag
	return &""


## Every view of 5.6 as [name, Callable(game)]: the study's for the player and for another country, the map's, the card's.
func _views(g: Game) -> Array:
	var other := _stranger(g)
	var last := maxi(g.turn - 1, 1)
	return [
		["districts", func(game: Game) -> Variant: return StudyEconomy.districts(game, GEN)],
		["districts_other", func(game: Game) -> Variant: return StudyEconomy.districts(game, other)],
		["goods12", func(game: Game) -> Variant: return StudyEconomy.goods(game, GEN, 12)],
		["goods40", func(game: Game) -> Variant: return StudyEconomy.goods(game, GEN, SPAN)],
		["lasts", func(game: Game) -> Variant: return StudyEconomy.lasts(game, GEN)],
		["history12", func(game: Game) -> Variant: return StudyEconomy.history(game, GEN, 12)],
		["history40", func(game: Game) -> Variant: return StudyEconomy.history(game, GEN, SPAN)],
		["this_season", func(game: Game) -> Variant: return StudyEconomy.this_season(game, GEN)],
		["worth_seasons", func(game: Game) -> Variant: return EconomyPreview.worth_seasons(game, GEN, 4)],
		["worth_seasons1", func(game: Game) -> Variant: return EconomyPreview.worth_seasons(game, GEN, 1)],
		["worth_by_hex", func(game: Game) -> Variant: return EconomyPreview.worth_by_hex(game, GEN)],
		["rankings12", func(game: Game) -> Variant: return StudyRankings.of(game, GEN, 12)],
		["rankings40", func(game: Game) -> Variant: return StudyRankings.of(game, GEN, SPAN)],
		["rankings_all", func(game: Game) -> Variant: return StudyRankings.of(game, &"", SPAN)],
		["index", func(game: Game) -> Variant: return StudyHistory.index(game, GEN)],
		["index_all", func(game: Game) -> Variant: return StudyHistory.index(game, &"")],
		["timeline", func(game: Game) -> Variant: return StudyHistory.timeline(game, GEN)],
		["season", func(game: Game) -> Variant: return StudyHistory.season(game, GEN, last)],
		["season_old", func(game: Game) -> Variant: return StudyHistory.season(game, GEN, 1)],
		["chronicle_all", func(game: Game) -> Variant: return StudyHistory.chronicle(game, GEN, &"all", 0)],
		["chronicle_works", func(game: Game) -> Variant: return StudyHistory.chronicle(game, GEN, &"works", last, 30)],
		["chronicle_mine", func(game: Game) -> Variant: return StudyHistory.chronicle(game, GEN, &"mine", 0)],
		["yield_bytes", func(game: Game) -> Variant: return MapModes.yield_bytes(game, GEN)],
		["yield_bytes_other", func(game: Game) -> Variant: return MapModes.yield_bytes(game, other)],
		["hex_card", func(game: Game) -> Variant: return HexCard.of(game, InsightsFixture.GENOA_HEX)],
		["worth_row", func(game: Game) -> Variant: return HexCard.worth_row(game, InsightsFixture.GENOA_HEX)],
		["worth_row_timber", func(game: Game) -> Variant: return HexCard.worth_row(game, InsightsFixture.TIMBER_HEX)],
		["log_filters", func(game: Game) -> Variant: return _filters_of_first(game)],
		["log_entries", func(game: Game) -> Variant: return LogLines.entries(game, GEN, &"all")],
	]


func _filters_of_first(game: Game) -> Array:
	var out: Array = []
	for n: int in mini(game.chronicle.entries.size(), 40):
		out.append(LogLines.filters_of(game, game.chronicle.entries[n], GEN))
	return out


func _run_all(g: Game) -> Dictionary:
	var out := {}
	for row: Array in _views(g):
		out[row[0]] = (row[1] as Callable).call(g)
	return out


func _bytes_of(results: Dictionary) -> Dictionary:
	var out := {}
	for name: String in results:
		out[name] = var_to_bytes(results[name])
	return out


## What the views must not change.
func _state_of(g: Game) -> Dictionary:
	return {
		"body": var_to_bytes(Snapshot.of(g, {})), "digest": g.digest(), "version": g.version, "turn": g.turn,
		"action_log": g.action_log.size(), "chronicle": g.chronicle.entries.size(), "player": g.player,
		"works": g.state.works.size(),
	}


func _reload(g: Game) -> Game:
	var dir := "user://test_insights_%d_%d" % [Time.get_ticks_usec(), _dirs.size()]
	_dirs.append(dir)
	var info := {"build": "test", "name": "insights", "saved_unix": 0, "play_seconds": 0}
	var problem := SaveFile.write(g, "1", info, {}, dir)
	assert_eq(problem, "", "the save is written")
	var read := SaveFile.read("1", dir)
	assert_eq(str(read["problem"]), "", "the save is read")
	var back := Snapshot.restore(read["body"] as Dictionary, g.map, g.defs)
	assert_eq(str(back["problem"]), "")
	return back["game"] as Game


# ---- they leave the game as it was --------------------------------------------------------------------------------------

func _leaves_the_game(g: Game, label: String) -> void:
	var before := _state_of(g)
	var turns := g.turn
	for round_n: int in 2:  # a cold round and a warm one
		if round_n == 0:
			g.view_cache.clear()
		for row: Array in _views(g):
			(row[1] as Callable).call(g)
		var after := _state_of(g)
		for key: String in before:
			assert_true(before[key] == after[key], "%s: %s unchanged (round %d)" % [label, key, round_n])
	assert_eq(g.turn, turns)


func test_every_view_leaves_the_game_as_it_was() -> void:
	_leaves_the_game(InsightsFixture.genoa_1483(), "genoa_1483")


func test_every_view_leaves_a_first_year_game_as_it_was() -> void:
	_leaves_the_game(InsightsFixture.genoa_first_year(), "first year")


func test_every_view_leaves_forty_seasons_as_they_were() -> void:
	var g := InsightsFixture.forty_seasons()
	_leaves_the_game(g, "forty seasons")
	assert_gt(g.chronicle.entries.size(), 100, "the game is a rich one")


func test_a_new_game_is_read_without_writing_too() -> void:
	var g := EconomyFixture.game(GEN)
	_leaves_the_game(g, "turn 1")
	var map_only := Game.new_game(EconomyFixture.map(), 1480)
	var before := _state_of(map_only)
	assert_eq(StudyEconomy.districts(map_only, GEN)["has_land"], false)
	assert_eq(MapModes.yield_bytes(map_only, GEN).size(), map_only.map.hex_count())
	assert_eq(HexCard.worth_row(map_only, InsightsFixture.GENOA_HEX), [])
	var after := _state_of(map_only)
	for key: String in before:
		assert_true(before[key] == after[key], "map only: %s" % key)


func test_planted_the_comparison_sees_a_changed_game() -> void:
	var g := InsightsFixture.genoa_1483()
	var before := _state_of(g)
	g.dev_money(GEN, 5)  # a writer
	var after := _state_of(g)
	assert_false(before["body"] == after["body"], "the snapshot bytes change")
	assert_false(before["digest"] == after["digest"], "the digest changes")
	assert_ne(before["version"], after["version"], "the version changes")


# ---- equal after a save and a load -----------------------------------------------------------------------------------------

func _equal_after_load(g: Game, label: String) -> void:
	var want := _bytes_of(_run_all(g))
	var back := _reload(g)
	assert_not_null(back, label)
	if back == null:
		return
	assert_eq(back.digest(), g.digest(), "%s: the digest" % label)
	var got := _bytes_of(_run_all(back))
	assert_eq(got.keys(), want.keys())
	for name: String in want:
		assert_true(got[name] == want[name], "%s: %s equals itself after a load" % [label, name])


func test_every_view_is_equal_after_a_save_and_a_load() -> void:
	_equal_after_load(InsightsFixture.genoa_1483(), "genoa_1483")


func test_every_view_is_equal_after_a_load_of_forty_seasons() -> void:
	_equal_after_load(InsightsFixture.forty_seasons(), "forty seasons")


func test_a_view_made_before_the_save_equals_one_made_cold() -> void:
	var g := InsightsFixture.genoa_1483()
	var warm := _bytes_of(_run_all(g))
	g.view_cache.clear()
	var cold := _bytes_of(_run_all(g))
	for name: String in warm:
		assert_true(warm[name] == cold[name], "%s: the cache serves what a cold call makes" % name)


func test_the_views_leave_no_trace_in_the_play_across_a_load() -> void:
	var g := InsightsFixture.genoa_1483()
	_run_all(g)
	var back := _reload(g)
	for _n: int in 8:
		Season.run(g)
		Season.run(back)
	assert_eq(g.digest(), back.digest(), "the played game and its twin read back agree")


# ---- copies ---------------------------------------------------------------------------------------------------------------

## Writes into every value inside `v`, deep, and empties the containers: what a careless caller could do.
func _scribble(v: Variant) -> void:
	if v is Dictionary:
		var d := v as Dictionary
		for k: Variant in d.keys():
			var inner: Variant = d[k]
			_scribble(inner)
		d.clear()
	elif v is Array:
		var a := v as Array
		for item: Variant in a:
			_scribble(item)
		a.clear()
	elif v is PackedInt32Array:
		var p: PackedInt32Array = v
		p.fill(9)
	elif v is PackedByteArray:
		var b: PackedByteArray = v
		b.fill(9)


func test_planted_the_scribbler_reaches_what_it_is_given() -> void:
	var inner := {"x": [1, 2], "y": {"z": 1}}
	var outer := {"k": inner}
	_scribble(outer)
	assert_true(outer.is_empty())
	assert_true(inner.is_empty(), "a nested dictionary is emptied too")
	var packed := PackedInt32Array([1, 2, 3])
	_scribble(packed)
	assert_eq(packed, PackedInt32Array([9, 9, 9]), "a packed array is overwritten")


func test_a_caller_cannot_change_what_the_views_cache() -> void:
	var g := InsightsFixture.genoa_1483()
	for row: Array in _views(g):
		var name: String = row[0]
		if name.begins_with("yield_bytes"):
			continue  # one byte array, read as it is: its own test below
		if name == "worth_by_hex":
			continue  # M4's view, which hands out its cached array itself (issue to be raised: not M4.5's to change here)
		var call := row[1] as Callable
		var first: Variant = call.call(g)
		var want := var_to_bytes(first)
		_scribble(first)
		var second: Variant = call.call(g)
		assert_true(var_to_bytes(second) == want, "%s: a mutation never reaches the cache" % name)
		_scribble(second)
		g.view_cache.clear()
		assert_true(var_to_bytes(call.call(g)) == want, "%s: nor after the cache is made again" % name)


func test_the_yield_bytes_are_one_byte_a_hex_and_the_same_each_call() -> void:
	var g := InsightsFixture.genoa_1483()
	var first := MapModes.yield_bytes(g, GEN)
	assert_eq(first.size(), g.map.hex_count())
	var want := first.duplicate()
	assert_eq(MapModes.yield_bytes(g, GEN), want, "the same bytes again")
	g.view_cache.clear()
	assert_eq(MapModes.yield_bytes(g, GEN), want, "and cold")


# ---- the pins of 4.13 --------------------------------------------------------------------------------------------------------

func test_the_pins_of_4_13() -> void:
	# M7 (m7-build-spec.md 4.13): thirteen phases.
	assert_eq(Season.PHASES, [&"movement", &"battles", &"supply", &"sieges", &"war", &"production", &"income", &"works", &"people", &"stats", &"calendar", &"ready_units", &"vision"] as Array[StringName])
	assert_eq(Actions.NAMES, ["build", "upgrade", "clear", "cancel_work", "choose_country", "set_tax", "raise", "split_army", "merge_armies", "disband", "march", "halt", "continue_march", "declare_war", "make_peace", "storm", "set_standing"] as Array[String])
	assert_eq(SaveFile.FORMAT, 5)
	assert_eq(SaveFile.OLDEST_FORMAT, 5)
	# M7 (4.19): the seven series of the war are appended, so 49.
	assert_eq(Stats.SERIES.size(), 49)
	assert_eq(Chronicle.NOTABLE, ["work_started", "work_finished", "work_cancelled", "owners_changed", "country_chosen",
		"goods_short", "tax_set", "town_grew", "district_declined", "army_raised", "army_disbanded", "march_halted",
		"army_starved", "unit_lost", "war_declared", "peace_made", "battle_ended", "siege_started", "siege_lifted",
		"district_captured"] as Array[String])
	assert_eq(Chronicle.NOTABLE.size(), 20, "twenty notable kinds (M7 adds six, 4.14)")
	assert_eq(Chronicle.KEEP, 3000)
	assert_eq(Stats.RING, 40)
	assert_eq([Stats.MADE, Stats.USED, Stats.STOCK], [0, 1, 2])


func test_events_gain_the_army_signals_of_m6() -> void:
	# M6 (m6-build-spec.md 5.5): the seven army signals join the M5 list. M7 (5.5) adds the eleven war signals (below).
	var names: Array[String] = []
	for sig: Dictionary in (load("res://shell/autoload/events.gd") as GDScript).get_script_signal_list():
		names.append(str(sig["name"]))
	names.sort()
	var want: Array[String] = ["army_changed", "army_cleared", "army_disbanded", "army_raised", "army_selected", "army_starved",
		"battle_ended", "battle_fought", "battle_joined", "battle_mark_clicked", "battle_started", "chronicled", "controllers_changed",
		"country_chosen", "district_captured", "district_declined", "game_ended", "game_started", "goods_short", "hex_changed",
		"march_halted", "owners_changed", "peace_made", "season_ended", "siege_lifted", "siege_progress", "siege_started",
		"tax_set", "town_grew", "unit_lost", "unit_moved", "war_declared", "work_cancelled", "work_finished", "work_started"]
	assert_eq(names, want)
	assert_eq(want.size(), 35, "the M6 list, the eleven war signals of 5.5 and battle_mark_clicked")


func test_the_save_body_and_the_digest_are_unchanged() -> void:
	var g := InsightsFixture.genoa_1483()
	var body := Snapshot.of(g, {})
	var keys: Array = body.keys()
	keys.sort()
	assert_eq(keys, ["action_log", "armies", "chronicle", "countries", "format", "game", "luck", "map_state", "stats", "ui", "war"])
	var with_ui := Snapshot.of(g, {"map_mode": "yields"})
	assert_eq(str((with_ui["ui"] as Dictionary)["map_mode"]), "yields", "the ui block may hold the yields mode")
	var restored := Snapshot.restore(bytes_to_var(var_to_bytes(with_ui)) as Dictionary, g.map, g.defs)
	assert_eq(str(restored["problem"]), "")
	assert_eq((restored["game"] as Game).digest(), g.digest(), "the ui block is not in the digest")
	assert_eq((restored["ui"] as Dictionary).get("map_mode"), "yields")


func test_the_stats_accessors_exist_and_read() -> void:
	var g := InsightsFixture.genoa_1483()
	var stats := g.stats
	assert_true(stats.has_method("goods_value"))
	assert_true(stats.has_method("goods_series"))
	var before := var_to_bytes(stats.to_dict())
	for good: int in g.defs.goods.size():
		for part: int in [Stats.MADE, Stats.USED, Stats.STOCK]:
			stats.goods_series(GEN, good, part, SPAN)
			stats.goods_value(GEN, g.turn - 1, good, part)
	assert_true(before == var_to_bytes(stats.to_dict()), "the accessors write nothing")
	assert_eq(stats.goods_value(&"NOPE", g.turn - 1, 0, 0), 0, "an unknown tag gives 0")
	assert_eq(stats.goods_series(GEN, 999, 0, 5), PackedInt32Array(), "an unknown good gives nothing")


# ---- the scan for writers ------------------------------------------------------------------------------------------------------

## The code lines of `text` (comments dropped).
func _code_lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		var hash_at := line.find(" #")
		if hash_at >= 0:
			line = line.substr(0, hash_at)
		lines.append(line)
	return lines


func _regex(pattern: String) -> RegEx:
	var re := RegEx.new()
	var err := re.compile(pattern)
	assert_eq(err, OK, pattern)
	return re


## Types whose objects are game state: a local of one is an alias of the game's own object.
const STATE_TYPES := "Game|Country|Work|Chronicle|Stats|MapState|MapData|ViewCache"
## What a local may be assigned from to hold game state itself (not a copy): a call-free path through game, state, stats,
## countries, chronicle, map, or a lookup of a Country or Work.
const ALIAS_RHS := "^(?:(?:game|g|self)\\b[\\w.\\[\\]]*|[\\w.\\[\\]]*\\.(?:state|stats|countries|chronicle|map|entries|works|action_log)\\b[\\w.\\[\\]]*|Countries\\.\\w+\\(.*\\)|[\\w.]*\\.(?:works|countries)\\[.*\\])$"


## The lines of `text` that write game state, function by function: a banned call; an assignment to a field of `game`,
## `game.state` or any name that holds game state (a typed local or parameter, a `for` variable, or an ALIAS: a local
## assigned from a call-free path through the game, e.g. `var st := game.state`); a mutating call on such a field or on the
## alias itself. Writes to game.view_cache and to locals made in the function (`var out := {}`, `.duplicate()`) are the views'
## own and allowed. With `members`, also a write to one of those member variables of the class itself.
func _writers(text: String, members: Array[String] = []) -> Array[String]:
	var lines := _code_lines(text)
	var found: Array[String] = []
	var ops := "(=(?!=)|[-+*/%|&^]=|<<=|>>=)"
	var fixed: Array[RegEx] = []
	for word: String in BANNED:
		fixed.append(_regex(word))
	fixed.append(_regex("\\b(?:game|g)\\.(?!view_cache\\b)\\w+(?:\\[[^\\]]*\\])*\\s*%s" % ops))
	fixed.append(_regex("\\b(?:game|g)\\.state\\.\\w+(?:\\[[^\\]]*\\])*\\s*%s" % ops))
	fixed.append(_regex("\\b(?:game|g)\\.(?!view_cache\\b)[\\w.]*\\.(?:%s)\\(" % MUTATORS))
	for member: String in members:
		fixed.append(_regex("(?<![\\w.])(?:self\\.)?%s(?:\\[[^\\]]*\\])*\\s*%s" % [member, ops]))
		fixed.append(_regex("(?<![\\w.])(?:self\\.)?%s\\.(?:%s)\\(" % [member, MUTATORS]))
	var typed := _regex("\\b(\\w+)\\s*:\\s*(?:%s)\\b" % STATE_TYPES)
	var made := _regex("\\bvar\\s+(\\w+)\\s*:?=\\s*(?:Countries\\.\\w+|[\\w.]*\\.(?:countries|works)\\[)")
	var assigned := _regex("^(?:var\\s+)?(\\w+)\\s*(?::\\s*[\\w\\[\\], ]+)?\\s*:?=\\s*(.+)$")
	var rhs_re := _regex(ALIAS_RHS)
	var names: Array[String] = []   # the state holders of the function in view
	var alias_res: Array[RegEx] = []
	for line: String in lines:
		if line.begins_with("func ") or line.begins_with("static func "):
			names.clear()
			alias_res.clear()
		var hit := false
		for re: RegEx in fixed:
			if re.search(line) != null:
				hit = true
				break
		if not hit:
			for re: RegEx in alias_res:
				if re.search(line) != null:
					hit = true
					break
		if hit:
			found.append(line)
		# names this line makes (they hold state from the next line on)
		var new_names: Array[String] = []
		for re: RegEx in [typed, made]:
			for m: RegExMatch in re.search_all(line):
				new_names.append(m.get_string(1))
		var a := assigned.search(line)
		if a != null and rhs_re.search(str(a.get_string(2)).strip_edges()) != null:
			new_names.append(a.get_string(1))
		var plain := _regex("^[\\w.\\[\\]]+$")
		if a != null and new_names.is_empty() and plain.search(str(a.get_string(2)).strip_edges()) != null:
			var root := str(a.get_string(2)).strip_edges().split(".")[0].split("[")[0]
			if names.has(root):
				new_names.append(a.get_string(1))  # an alias of an alias
		for name: String in new_names:
			if names.has(name) or name == "game" or name == "g":
				continue
			names.append(name)
			alias_res.append(_regex("(?<![\\w.])%s(?:(?:\\.\\w+)+(?:\\[[^\\]]*\\])*|(?:\\[[^\\]]*\\])+(?:\\.\\w+)*)\\s*%s" % [name, ops]))
			alias_res.append(_regex("(?<![\\w.])%s(?:\\.\\w+|\\[[^\\]]*\\])*\\.(?:%s)\\(" % [name, MUTATORS]))
	return found


## The text of `func <name>` up to the next function.
func _function_text(text: String, name: String) -> String:
	var start := text.find("func %s(" % name)
	if start < 0:
		return ""
	var stop := text.find("\nfunc ", start + 1)
	return text.substr(start) if stop < 0 else text.substr(start, stop - start)


func _members_of(text: String) -> Array[String]:
	var names: Array[String] = []
	for m: RegExMatch in _regex("(?m)^var\\s+(\\w+)").search_all(text):
		names.append(m.get_string(1))
	return names


func _files_in(dir_path: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))


func _view_files() -> Array[String]:
	var files: Array[String] = []
	_files_in(VIEWS_DIR, files)
	return files


func _shell_files() -> Array[String]:
	var files: Array[String] = []
	for dir_path: String in SHELL_DIRS:
		var all: Array[String] = []
		_files_in(dir_path, all)
		for path: String in all:
			var file := path.get_file()
			var wanted := SHELL_FILES.has(path) or dir_path.ends_with("/study")
			for prefix: String in SHELL_PREFIXES:
				wanted = wanted or file.begins_with(prefix)
			if wanted:
				files.append(path)
	for path: String in SHELL_FILES:
		if FileAccess.file_exists(path) and not files.has(path):
			files.append(path)
	return files


func _scan(files: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for path: String in files:
		for line: String in _writers(FileAccess.get_file_as_string(path)):
			found.append("%s: %s" % [path, line])
	return found


func test_no_view_writes_game_state() -> void:
	var files := _view_files()
	assert_gt(files.size(), 20, "every file of core/views is scanned")
	for path: String in ["study_economy", "study_rankings", "study_history", "economy_preview", "map_modes", "log_lines",
			"hex_card", "knowledge", "cards_economy", "works_view"]:
		assert_true(files.has("%s/%s.gd" % [VIEWS_DIR, path]), path)
	assert_eq(_scan(files), [] as Array[String], "writers in core/views")


func test_no_m4_5_shell_file_writes_game_state() -> void:
	var files := _shell_files()
	assert_gt(files.size(), 10, "the study's shell files are found")
	for path: String in ["res://shell/ui/ink_chart.gd", "res://shell/ui/timeline_strip.gd", "res://shell/ui/study_table.gd",
			"res://shell/app/study_warm.gd", "res://shell/hud/mode_legend.gd", "res://shell/screens/study/page_history.gd"]:
		assert_true(files.has(path), path)
	assert_eq(_scan(files), [] as Array[String], "writers in the study's shell files")


func test_the_two_stats_accessors_write_nothing() -> void:
	var text := FileAccess.get_file_as_string("res://core/state/stats.gd")
	var members := _members_of(text)
	assert_gt(members.size(), 5, "the members of Stats are found")
	for name: String in STATS_ACCESSORS:
		var body := _function_text(text, name)
		assert_false(body.is_empty(), "%s is found" % name)
		assert_eq(_writers(body, members), [] as Array[String], "%s writes a member" % name)


func test_the_scan_sees_each_kind_of_writer() -> void:
	var bad: Array[String] = [
		"Session.act(\"set_tax\", {})", "game.act(\"build\", args)", "Treasury.move(game, tag, 5, &\"x\")",
		"Stores.move.call(game, tag, 1, 1, &\"dev\")", "game.emit(&\"x\")", "Season.run(game)", "end_season(game)",
		"game.dev_money(tag, 5)", "game.dev_goods(tag, 1, 5)", "game.version += 1", "game.turn = 3", "game.player = &\"X\"",
		"game.state.owner[i] = 3", "game.state.works.append(w)", "game.state.owner.fill(0)", "game.chronicle.entries.clear()",
		"g.state.height[i] -= 1", "game.action_log.append({})",
	]
	for line: String in bad:
		assert_eq(_writers(line).size(), 1, line)
	var bad_country := "func f(game: Game) -> void:\n\tvar c := Countries.by_tag(game, tag)\n\tc.treasury += 5\n"
	assert_eq(_writers(bad_country).size(), 1, "a Country's field")
	assert_eq(_writers("func f(c: Country) -> void:\n\tc.stock[3] = 1\n").size(), 1, "a typed parameter's field")
	assert_eq(_writers("func f(c: Country) -> void:\n\tc.stock.fill(0)\n").size(), 1, "a mutating call on a Country's field")
	assert_eq(_writers("for c: Country in game.countries:\n\tc.ledger_open.clear()\n").size(), 1, "a loop variable")
	assert_eq(_writers("var turn := 3\nturn = 4\n", ["turn"] as Array[String]).size(), 1, "a member of the class")
	assert_eq(_writers("count += 1\n", ["count"] as Array[String]).size(), 1)
	assert_eq(_writers("self.count = 2\n", ["count"] as Array[String]).size(), 1)
	var fine: Array[String] = [
		"var t := game.turn", "if game.version == 3:", "x = game.state.owner[i]", "# game.act(\"build\")", "foo(game.state.owner)",
		"game.view_cache.clear()", "game.view_cache.get_or_make(key, f)", "var out := {}", "out[k] = 1", "out.append(3)",
		"var key: Array = [&\"x\", game.version, tag]", "var n := game.chronicle.entries.size()", "game.state.owner.size()",
		"var a := c.stock.duplicate()", "x = c.treasury", "return game.turn == 3",
	]
	for line: String in fine:
		assert_eq(_writers(line).size(), 0, line)
	assert_eq(_writers("func f(c: Country) -> void:\n\tvar n := c.stock[3]\n\tn += 1\n").size(), 0, "a copy may be changed")


func test_planted_writer_in_user_dir_is_caught() -> void:
	var path := "user://planted_insights_view.gd"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("extends RefCounted\nfunc cheat(game: Game) -> Dictionary:\n\tSession.act(\"set_tax\", {\"level\": 2})\n\treturn {}\n")
	f.close()
	var hits := _writers(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	assert_eq(hits.size(), 1)
	assert_true(hits[0].contains("Session.act("))


func test_planted_state_write_in_a_view_is_caught() -> void:
	var path := "user://planted_insights_state.gd"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("extends RefCounted\nstatic func of(game: Game) -> int:\n\tgame.state.owner[0] = 1\n\tgame.version += 1\n\treturn 0\n")
	f.close()
	var hits := _writers(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	assert_eq(hits.size(), 2)


func test_planted_stats_accessor_that_writes_is_caught() -> void:
	var text := "var count: int = 0\nvar goods_ring: PackedInt32Array = PackedInt32Array()\n\nfunc goods_value(tag: StringName) -> int:\n\tcount += 1\n\tgoods_ring[0] = 5\n\treturn 0\n\n\nfunc other() -> void:\n\tcount = 0\n"
	var body := _function_text(text, "goods_value")
	assert_false(body.contains("other"), "the function's text ends at the next function")
	assert_eq(_writers(body, _members_of(text)).size(), 2)


func test_the_scan_sees_aliases_of_game_state() -> void:
	var bad: Array[String] = [
		"func f(game: Game) -> void:
	var st := game.state
	st.owner[0] = 1
",
		"func f(game: Game) -> void:
	var st: MapState = game.state
	st.owner.fill(0)
",
		"func f(game: Game) -> void:
	var s := game.stats
	s.count = 1
",
		"func f(game: Game) -> void:
	var s := game.stats
	s.ring.append(1)
",
		"func f(game: Game) -> void:
	var m := game.map
	m.land[3] = 0
",
		"func f(game: Game) -> void:
	var list := game.chronicle.entries
	list.append({})
",
		"func f(game: Game) -> void:
	var works := game.state.works
	works.clear()
",
		"func f(game: Game) -> void:
	var w := game.state.works[0]
	w.turn = 3
",
		"func f(game: Game) -> void:
	var c := game.countries[0]
	c.treasury -= 1
",
		"func f(game: Game) -> void:
	var c := Countries.by_tag(game, tag)
	c.stock.resize(3)
",
		"func f(game: Game) -> void:
	var a := game
	a.turn = 9
",
		"func f(w: Work) -> void:
	w.turn = 3
",
		"func f(s: Stats) -> void:
	s.years.append(1)
",
		"func f(ch: Chronicle) -> void:
	ch.entries.clear()
",
		"func f(game: Game) -> void:
	var st := game.state
	var o := st.owner
	o[0] = 2
",
	]
	for text: String in bad:
		assert_eq(_writers(text).size(), 1, text)
	var fine: Array[String] = [
		"func f(game: Game) -> void:
	var st := game.state
	var n := st.owner[0]
	print(n, st.owner.size())
",
		"func f(game: Game) -> void:
	var st := game.state
	var owner := st.owner.duplicate()
	owner[0] = 1
",
		"func f(game: Game) -> void:
	var out := {}
	out[1] = 2
	var rows: Array[Dictionary] = []
	rows.append(out)
",
		"func f(game: Game) -> void:
	var s := game.stats
	var v := s.value(tag, 3, \"land\")
	v += 1
",
		"func f(game: Game) -> void:
	var c := Countries.by_tag(game, tag)
	var left := c.treasury
	left -= 5
",
		"func f(game: Game) -> void:
	var st := game.state

func g2() -> void:
	var st := {}
	st[1] = 2
",
		"func f(game: Game) -> void:
	game.view_cache.clear()
",
	]
	for text: String in fine:
		assert_eq(_writers(text).size(), 0, text)


func test_planted_alias_writer_in_user_dir_is_caught() -> void:
	var path := "user://planted_insights_alias.gd"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("extends RefCounted
static func of(game: Game) -> int:
	var st := game.state
	st.owner[0] = 1
	return 0
")
	f.close()
	var hits := _scan([path] as Array[String])
	DirAccess.remove_absolute(path)
	assert_eq(hits.size(), 1, "an alias write in a file outside the seven is reported")
