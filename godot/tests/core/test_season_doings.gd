## SeasonSummary's M8 rules for what others did (docs/architecture/m8-build-spec.md 4.14, D38): "What befell" one line a
## country with its doings counted, six then more, a stranger's doings absent, "Your orders" only the viewer's, the watched
## lede, and equal after a save and load. Split from test_season_summary.gd to keep both under the size limit.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const WOODS := Vector2i(9, 11)
const GENOA := Vector2i(8, 13)
const SAVONA := Vector2i(7, 12)

var _g: Game
var _next_id := 90


func before_each() -> void:
	var defs := EconomyFixture.defs()
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": &"GEN"})["ok"]))
	_g.improvement.clear(SAVONA)


func _section(summary: Dictionary, id: StringName) -> Dictionary:
	for s: Dictionary in summary["sections"]:
		if s["id"] == id:
			return s
	return {}


func _texts(summary: Dictionary, id: StringName) -> Array[String]:
	var out: Array[String] = []
	for line: Dictionary in (_section(summary, id).get("lines", []) as Array):
		out.append(str(line["text"]))
	return out


# ----- M8 (m8-build-spec.md 4.14, D38): what befell, one line a country -----------------------------------------------

func _others() -> Array[StringName]:
	var out: Array[StringName] = []
	for tag: StringName in Knowledge.known(_g, &"GEN"):
		if tag != &"GEN":
			out.append(tag)
	return out


## A vineyard begun by `tag` at `hex`, witnessed by Genoa and the country itself (the producer's work_started shape).
func _begun_by(tag: StringName, hex: Vector2i) -> void:
	var w := Work.new()
	w.id = _next_id
	_next_id += 1
	w.tag = tag
	w.hex = hex
	w.action = Works.BUILD
	w.family = ImproveRules.VINEYARD
	w.level_to = 1
	w.started_turn = _g.turn
	w.seasons = 4
	w.seasons_left = 4
	_g.emit({"kind": "work_started", "tag": tag, "hex": hex, "work": w.to_dict(), "witnesses": ["GEN", String(tag)]})


func _starts_with(lines: Array[String], name: String) -> Array[String]:
	var out: Array[String] = []
	for text: String in lines:
		if text.begins_with(name + " "):
			out.append(text)
	return out


func test_what_befell_is_one_line_a_country_with_its_doings_counted() -> void:
	var others := _others()
	var a := others[0]
	var b := others[1]
	assert_true(bool(_g.act("set_tax", {"level": 0, "tag": a})["ok"]))
	_begun_by(a, WOODS)
	_begun_by(a, GENOA)
	assert_true(bool(_g.act("set_tax", {"level": 0, "tag": b})["ok"]))
	Season.run(_g)
	var befell := _texts(SeasonSummary.of(_g, &"GEN", 1), &"befell")
	var lines_a := _starts_with(befell, LogLines.short_name(_g, a))
	assert_eq(lines_a.size(), 1, "one line for the country, not one for each doing: %s" % str(befell))
	assert_eq(_starts_with(befell, LogLines.short_name(_g, b)).size(), 1, "one line for the other country too")
	assert_true(lines_a[0].contains("began 2 works"), "its two works are counted: %s" % lines_a[0])
	assert_true(lines_a[0].contains("set taxes to Low"), "its tax is in the same line: %s" % lines_a[0])
	assert_true(lines_a[0].ends_with("."), "a sentence")


func test_six_lines_show_and_the_rest_are_counted() -> void:
	# Eight other countries each do one thing Genoa is told of (the witnesses name it): more than the six lines.
	var doers: Array[StringName] = []
	for c: Country in _g.countries:
		if c.tag != &"GEN" and doers.size() < 8:
			doers.append(c.tag)
	assert_eq(doers.size(), 8, "the scenario has eight other countries")
	for tag: StringName in doers:
		_g.emit({"kind": "tax_set", "tag": tag, "level": 0, "from": 1, "witnesses": ["GEN", String(tag)]})
	Season.run(_g)
	var befell := _section(SeasonSummary.of(_g, &"GEN", 1), &"befell")
	assert_eq((befell["lines"] as Array).size(), SeasonSummary.SHOWN, "six lines show")
	assert_eq(int(befell["more"]), int(befell["count"]) - SeasonSummary.SHOWN, "the rest are in more")
	assert_true(int(befell["count"]) >= 8, "a line for each country that did something")


func test_my_orders_are_only_mine() -> void:
	var a := _others()[0]
	assert_true(bool(_g.act("set_tax", {"level": 0, "tag": a})["ok"]))
	Season.run(_g)
	var s := SeasonSummary.of(_g, &"GEN", 1)
	assert_false(_texts(s, &"orders").has("Set taxes to Low."), "P: another country's order is not in Your orders")
	assert_true(_texts(s, &"befell").any(func(t: String) -> bool: return t.begins_with(LogLines.short_name(_g, a))),
		"the other's doing is in What befell")


func test_a_stranger_doing_is_not_in_what_befell() -> void:
	Season.run(_g)
	FogFixture.thin(_g, &"GEN", 0)  # Genoa knows its neighbours only
	var stranger := &""
	for c: Country in _g.countries:
		if c.tag != &"GEN" and not Knowledge.knows(_g, &"GEN", c.tag):
			stranger = c.tag
			break
	assert_ne(stranger, &"", "the thin Genoa does not know some country")
	_g.emit({"kind": "tax_set", "tag": stranger, "level": 0, "from": 1})
	_g.turn = 3
	_g.version += 1
	var befell := _texts(SeasonSummary.of(_g, &"GEN", 2), &"befell")
	assert_true(_starts_with(befell, LogLines.short_name(_g, stranger)).is_empty(), "P: an unknown country's doing is absent")


## A work of `tag` at `hex`, in the producer's payload shape (a finished or cancelled work).
func _work_at(tag: StringName, hex: Vector2i) -> Work:
	var w := Work.new()
	w.id = _next_id
	_next_id += 1
	w.tag = tag
	w.hex = hex
	w.action = Works.BUILD
	w.family = ImproveRules.VINEYARD
	w.level_to = 1
	w.started_turn = _g.turn
	w.seasons = 4
	w.seasons_left = 0
	return w


## R31: a land event is told to every country that has discovered its hex, whoever did it; the same event on a hex Genoa
## has not discovered is not told. The thin fixture (radius 1) makes both; the cancel is counted in the same line.
func test_a_land_event_is_told_by_discovery_not_by_the_actor() -> void:
	Season.run(_g)
	FogFixture.thin(_g, &"GEN", 1)
	var stranger := &""
	for c: Country in _g.countries:
		if c.tag != &"GEN" and not Knowledge.knows(_g, &"GEN", c.tag):
			stranger = c.tag
			break
	assert_ne(stranger, &"", "the thin Genoa does not know some country")
	var near := GENOA
	var far := Vector2i(2, 3)
	assert_true(Knowledge.discovered(_g, &"GEN", near), "Genoa's capital is discovered")
	assert_false(Knowledge.discovered(_g, &"GEN", far), "the far hex is undiscovered")
	_g.emit({"kind": "work_finished", "tag": stranger, "hex": far, "work": _work_at(stranger, far).to_dict()})
	_g.emit({"kind": "work_finished", "tag": stranger, "hex": near, "work": _work_at(stranger, near).to_dict()})
	_g.emit({"kind": "work_cancelled", "tag": stranger, "hex": near, "why": "", "work": _work_at(stranger, near).to_dict()})
	_g.turn = 3
	_g.version += 1
	var who := LogLines.short_name(_g, stranger)
	var told := _starts_with(_texts(SeasonSummary.of(_g, &"GEN", 2), &"befell"), who)
	assert_eq(told.size(), 1, "one line for the stranger, discovered land only: %s" % str(told))
	assert_true(told[0].contains("finished 1 work") and told[0].contains("cancelled 1 work"), told[0])
	var all := _starts_with(_texts(SeasonSummary.of(_g, &"", 2), &"befell"), who)
	assert_true(all[0].contains("finished 2 works"), "the viewer of everything is told of both: %s" % all[0])


func test_the_watched_lede_names_the_scenario() -> void:
	var defs := EconomyFixture.defs()
	var w := Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	w.ai_only = true
	w.version += 1
	var tag := w.countries[1].tag
	assert_true(bool(w.act("set_tax", {"level": 0, "tag": tag})["ok"]), "a country sets its tax in the watched game")
	Season.run(w)
	var s := SeasonSummary.of(w, &"", 1)
	assert_eq(str(s["lede"]), "A watched game of %s, 1480. %s begins." % [w.scenario.name, s["next"]], "the watched lede")


func test_what_befell_is_equal_after_a_save_and_load() -> void:
	var a := _others()[0]
	assert_true(bool(_g.act("set_tax", {"level": 0, "tag": a})["ok"]))
	_begun_by(a, WOODS)
	Season.run(_g)
	var before := SeasonSummary.of(_g, &"GEN", 1)
	var dir := "user://test_season_summary_%d/" % Time.get_ticks_usec()
	assert_eq(SaveFile.write(_g, "1", {"saved_unix": 1}, {}, dir), "")
	var read := SaveFile.read("1", dir)
	var back := Snapshot.restore(read["body"] as Dictionary, _g.map, _g.defs)["game"] as Game
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)
	assert_eq(SeasonSummary.of(back, &"GEN", 1), before, "the report, grouped befell included, is equal after a load")

