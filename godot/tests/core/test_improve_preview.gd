## ImprovePreview (docs/architecture/m4-build-spec.md 4.15 c, d and e, 4.17, 5.6, 9): the property of M4's done-when 4 (200
## seeded cases: the card equals what four calm seasons then do, to the unit), the worked examples, `blocked_by` for each
## refusal, the words of the 13 pair rules, payback, expensive, a map-only game, the digest and the view cache.
extends GutTest

@warning_ignore_start("integer_division")

const VINEYARD := ImproveRules.VINEYARD
const CASES := 200
const GAMES := 8


func _lines_of(lines: Array) -> Dictionary:
	var out := {}
	for line: Dictionary in lines:
		if Treasury.SPENDING.has(line["why"]) or line["why"] == &"dev":
			continue
		var at := line["hex"] as Vector2i
		out["%s|%d,%d" % [line["why"], at.x, at.y]] = int(line["amount"])
	return out


func _flow(c: Country, why: StringName, sign_of: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for g: int in c.stock.size():
		out.append(Stores.flow(c, g, why, true) * sign_of)
	return out


# ----- the property ---------------------------------------------------------------------------------------------------


## A game with works begun by random countries, taxes set and some seasons played (so the cases start in every season).
func _base_game(rng: RandomNumberGenerator, n: int) -> Game:
	var g := EconomyFixture.game(&"GEN", n % 2 == 0)
	for c: Country in g.countries:
		g.dev_money(c.tag, 3000)
		g.dev_goods(c.tag, 11, 100)
		g.dev_goods(c.tag, 12, 100)
		if rng.randi_range(0, 3) == 0:
			g.act("set_tax", {"level": rng.randi_range(0, 2), "tag": c.tag})
		for k: int in 3:
			var districts := Territory.districts(g, c.id)
			if districts.is_empty():
				break
			var hex := g.map.hex_of(districts[rng.randi_range(0, districts.size() - 1)])
			var rows := ImprovePreview.options_of(g, c.tag, hex)
			if not rows.is_empty():
				var row: Dictionary = rows[rng.randi_range(0, rows.size() - 1)]
				g.act(String(row["action"]), {"hex": hex, "family": row["family"], "tag": c.tag})
	for k: int in n % 6:
		Season.run(g)
	return g


## A random option the rules allow (any refusal but a rule's) on a random hex of a random country.
func _pick(g: Game, rng: RandomNumberGenerator) -> Dictionary:
	for attempt: int in 200:
		var c: Country = g.countries[rng.randi_range(0, g.countries.size() - 1)]
		var districts := Territory.districts(g, c.id)
		if districts.is_empty():
			continue
		var hex := g.map.hex_of(districts[rng.randi_range(0, districts.size() - 1)])
		var rows := ImprovePreview.options_of(g, c.tag, hex)
		if rows.is_empty():
			continue
		var row: Dictionary = rows[rng.randi_range(0, rows.size() - 1)]
		var card := ImprovePreview.of(g, c.tag, hex, row)
		if card["blocked_by"] != &"rule":
			return {"tag": c.tag, "hex": hex, "option": {"action": row["action"], "family": row["family"]}, "card": card}
	return {}


func _finish_at_once(copy: Game, hex: Vector2i, option: Dictionary) -> void:
	var done: Dictionary
	match option["action"]:
		Works.BUILD:
			done = Improve.build_here(copy, hex, int(option["family"]))
		Works.UPGRADE:
			done = Improve.upgrade_here(copy, hex)
		_:
			done = Improve.clear_here(copy, hex)
	assert_true(bool(done["ok"]), "the piece goes in: %s" % str(done))


func _check_case(g: Game, found: Dictionary, label: String) -> void:
	var tag: StringName = found["tag"]
	var hex: Vector2i = found["hex"]
	var option: Dictionary = found["option"]
	var card: Dictionary = found["card"]
	var i := g.map.index_of(hex)
	var target := ImprovePreview._target(g, hex, option["action"], int(option["family"]))
	var preview := EconomyPreview.with(g, tag, {"hexes": {i: target["pair"]}, "detail": true}, 4)
	var restored := Snapshot.restore(Snapshot.of(g), g.map, g.defs)
	var copy: Game = restored["game"]
	assert_not_null(copy, label + ": the copy")
	if copy == null:
		return
	_finish_at_once(copy, hex, option)
	var c := Countries.by_tag(copy, tag)
	for k: int in 4:
		var p: Dictionary = (preview["seasons"] as Array)[k]
		var where := "%s season %d" % [label, k + 1]
		var season := Calendar.season_of(copy.turn)
		for entry: Dictionary in p["hexes"]:
			if int(entry["i"]) != i:
				continue
			var out := Economy.district_output(copy, StateView.of(copy.state), hex, season, Economy.CALM, c.tax if int(entry["owner"]) == c.id else -1)
			assert_eq(out["goods"], entry["to_goods"], where + " the hex's district output")
			assert_eq(int(out["ducats"]), int(entry["to_dues"]), where + " dues of the hex")
		var cell: Dictionary = (card["by_season"] as Array)[season]
		assert_eq(int(cell["after_realm"]), int(p["realm"]), where + " the card's country measure")
		assert_eq(int(cell["after_treasury"]), int(p["net"]), where + " the card's treasury measure")
		assert_true(bool(Season.run(copy)["ok"]))
		assert_eq(_flow(c, &"made", 1), p["made"], where + " made")
		assert_eq(_flow(c, &"used", -1), p["used"], where + " used")
		assert_eq(_flow(c, &"sold", -1), p["sold"], where + " sold")
		assert_eq(_lines_of(c.ledger_closed["lines"] as Array), _lines_of(p["lines"] as Array), where + " money lines")
		var closed: Array[Dictionary] = []
		closed.assign(c.ledger_closed["lines"] as Array)
		assert_eq(Treasury.left_over(closed), int(p["net"]), where + " net")
	assert_eq(int((card["year"] as Dictionary).get("after_treasury", -1)), int(preview["year"]["net"]), label + " the year")


func test_the_preview_equals_four_calm_seasons_in_200_cases() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	var done := 0
	var kinds := {}
	var blocked := {}
	var rings := 0
	for n: int in GAMES:
		var g := _base_game(rng, n)
		var digest := g.digest()
		for case_number: int in CASES / GAMES:
			var found := _pick(g, rng)
			if found.is_empty():
				continue
			_check_case(g, found, "game %d case %d (%s %s %s)" % [n, case_number, found["tag"], found["hex"], found["option"]])
			done += 1
			var card: Dictionary = found["card"]
			var option: Dictionary = found["option"]
			kinds[option["action"]] = int(kinds.get(option["action"], 0)) + 1
			blocked[card["blocked_by"]] = int(blocked.get(card["blocked_by"], 0)) + 1
			var first: Dictionary = ((card["lands"] as Dictionary)["ring"] as Array)[0]
			if first.has("hex"):
				rings += 1
		assert_eq(g.digest(), digest, "game %d: the previews changed nothing" % n)
	assert_eq(done, CASES, "every case found an option")
	for action: StringName in [Works.BUILD, Works.UPGRADE, Works.CLEAR]:
		assert_gt(int(kinds.get(action, 0)), 5, "cases of %s: %s" % [action, str(kinds)])
	gut.p("cases by action %s, by refusal %s, with ring lines %d" % [str(kinds), str(blocked), rings])


func test_the_comparison_has_teeth() -> void:
	# A preview of nothing against a copy with the vineyard standing differs: the property would catch a missing change.
	var g := EconomyFixture.game(&"GEN", true)
	var none := EconomyPreview.with(g, &"GEN", {}, 4)
	var copy: Game = Snapshot.restore(Snapshot.of(g), g.map, g.defs)["game"]
	_finish_at_once(copy, EconomyFixture.VINEYARD_HEX, {"action": Works.BUILD, "family": VINEYARD})
	for k: int in 3:
		Season.run(copy)
	var c := Countries.by_tag(copy, &"GEN")
	assert_ne(_flow(c, &"made", 1), (none["seasons"][2] as Dictionary)["made"], "autumn's wine is not in the empty preview")


# ----- the worked examples (4.15 c, d, e) ------------------------------------------------------------------------------


func _same_keys(card: Dictionary, sample: Dictionary, where: String) -> void:
	for key: Variant in sample:
		assert_true(card.has(key), "%s: the card has '%s'" % [where, key])


func test_4_15_c_the_vineyard_card() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var card := ImprovePreview.of(g, &"GEN", Vector2i(7, 12), {"action": Works.BUILD, "family": VINEYARD})
	_same_keys(card, PreviewSample.vineyard(), "vineyard")
	assert_eq(card["verdict"], {"ok": true, "reason": ""})
	assert_eq(card["blocked_by"], &"")
	assert_eq(card["title"], "Vineyard, first stage")
	assert_eq(card["subtitle"], "near Savona (7, 12) · farmland, 665 m · frost winter · a river on the W edge")
	assert_eq(card["brings"], PreviewSample.vineyard()["brings"])
	var cells: Array = card["by_season"]
	var sample: Array = PreviewSample.vineyard()["by_season"]
	for s: int in 4:
		var cell: Dictionary = cells[s]
		var want: Dictionary = sample[s]
		assert_eq(cell["season"], want["season"])
		assert_eq(cell["now"], want["now"])
		assert_eq(cell["note"], want["note"] if s == 3 else "", "season %d note" % s)
		assert_eq([cell["before"], cell["after"], cell["gain"], cell["gain_realm"], cell["gain_treasury"]],
			[want["before"], want["after"], want["gain"], want["gain_realm"], want["gain_treasury"]], "season %d numbers" % s)
		if s < 3:
			assert_eq(cell["goods"], want["goods"], "season %d goods" % s)
	assert_eq((cells[2] as Dictionary)["goods"], [{"name": "wine", "before": 0, "after": 12}, {"name": "grain", "before": 2, "after": 1}])
	var before_t: Array[int] = []
	var after_t: Array[int] = []
	for cell: Dictionary in cells:
		before_t.append(int(cell["before_treasury"]))
		after_t.append(int(cell["after_treasury"]))
	assert_eq(before_t, [88, 95, 114, 136])
	assert_eq(after_t, [87, 93, 128, 135])
	var year: Dictionary = card["year"]
	assert_eq([year["before"], year["after"], year["gain"], year["gain_realm"], year["gain_treasury"]], [511, 533, 22, 22, 10])
	var lands: Dictionary = card["lands"]
	assert_eq(lands["district"], {"before": 6, "after": 32})
	assert_eq(lands["upkeep"], 4)
	assert_eq(lands["ring"], [{"text": "Ring of six: nothing changes"}])
	assert_eq([(lands["country"] as Dictionary)["before"], (lands["country"] as Dictionary)["after"]], [511, 533])
	var cost: Dictionary = card["cost"]
	assert_eq(cost["text"], "40 ducats · 4 seasons · ready Spring 1481 · first vintage Autumn 1481")
	assert_eq([cost["ducats"], cost["seasons"], cost["ready_turn"], cost["first_yield_turn"]], [40, 4, 5, 7])
	assert_eq(card["requirements"], PreviewSample.vineyard()["requirements"])
	var pay: Dictionary = card["payback"]
	assert_eq(pay["text"], "Pays back in Autumn 1482, 10 seasons from now (at today's prices).")
	assert_eq([pay["seasons"], pay["turn"], pay["prestige"]], [10, 11, false])
	assert_eq(pay["text_treasury"], "Autumn 1484, 18 seasons from now.")
	assert_eq(pay["seasons_treasury"], 18)
	assert_eq(card["next_stages"], [
		{"level": 2, "ok": true, "text": "Stage 2 possible (Savona (6, 13) 1 hex away)."},
		{"level": 3, "ok": true, "text": "Stage 3 possible (a town within two hexes, under 1,200 m)."}])
	assert_false(card["expensive"])
	var chips: Array = card["chips"]
	assert_eq((chips[0] as Dictionary)["text"], "wine +12 a year")
	assert_eq((chips[1] as Dictionary)["text_realm"], "+22 a year")
	assert_eq((chips[1] as Dictionary)["text_treasury"], "+10 a year")
	assert_eq((card["map_marks"] as Dictionary)[Vector2i(7, 12)], {"delta": 22, "label": "+12 wine"})
	var ghost: Dictionary = card["ghost"]
	assert_eq(ghost["hex"], Vector2i(7, 12))
	assert_eq(ghost["tiles"], MapCells.piece_cells(g.map, Improve.piece_for(g.map, Vector2i(7, 12), VINEYARD, 1), Vector2i(7, 12)))


func test_4_15_d_genoa_to_city_refused_for_money() -> void:
	# M5 spec 4.11 (c) replaces M4's 4.15 (d): an upgrade brings room, not people (D17), so the card says "Room 45,000 ->
	# 100,000" and the gains are the dues, fish, lift and upkeep alone (+15, +16, +15, +10 a season, +56 a year). The people
	# never change in this game (no people phase runs here), so the realm's year is M4's 557 plus 56.
	var g := EconomyFixture.game(&"GEN")
	var card := ImprovePreview.of(g, &"GEN", Vector2i(8, 13), {"action": Works.UPGRADE, "family": 0})
	_same_keys(card, PreviewSample.genoa_city_refused(), "genoa")
	assert_eq(card["blocked_by"], &"ducats")
	assert_false(bool(card["verdict"]["ok"]))
	assert_eq(card["reason_words"], "Not enough ducats: 1,000 needed, 610 in the treasury.")
	assert_eq(card["title"], "Genoa, walled town to city")
	assert_eq(card["brings"], PreviewSample.genoa_city_refused()["brings"])
	assert_eq((card["brings"] as Array)[0], {"field": &"room", "label": "Room", "before": 45000, "after": 100000, "per": &""})
	var chip_kinds: Array[StringName] = []
	for chip: Dictionary in card["chips"]:
		chip_kinds.append(chip["kind"])
	assert_eq(chip_kinds, [&"gain", &"room"] as Array[StringName])
	assert_eq((card["chips"][1] as Dictionary)["text"], "room +55,000")
	var gains: Array[int] = []
	var treasury: Array[int] = []
	for cell: Dictionary in card["by_season"]:
		gains.append(int(cell["gain_realm"]))
		treasury.append(int(cell["gain_treasury"]))
	assert_eq(gains, [15, 16, 15, 10])
	assert_eq(treasury, [13, 15, 14, 8])
	assert_eq((card["by_season"][3] as Dictionary)["note"], "port dues 30 % lower")
	var year: Dictionary = card["year"]
	assert_eq([year["before"], year["after"], year["gain_realm"], year["gain_treasury"]], [557, 613, 56, 50])
	var ring: Array = (card["lands"] as Dictionary)["ring"]
	assert_eq((ring[0] as Dictionary)["text"], "timber near Genoa (9, 13): +1 a season, +2 in winter (the city's market)")
	assert_eq(card["cost"]["text"], "1,000 ducats · 20 timber · 40 stone · 8 seasons · ready Spring 1482 if begun now")
	assert_eq(card["requirements"], [
		{"text": "no other town beside it", "ok": true}, {"text": "no castle against a town's wall", "ok": true},
		{"text": "a free work slot: 0 of 2 in use", "ok": true}, {"text": "1,000 of 610 ducats", "ok": false},
		{"text": "20 of 40 timber", "ok": true}, {"text": "40 of 40 stone", "ok": true}])
	var pay: Dictionary = card["payback"]
	assert_eq([pay["seasons"], pay["text"]], [83, "Pays back in Winter 1500, 83 seasons from now (at today's prices)."])
	assert_eq([pay["seasons_treasury"], pay["text_treasury"]], [92, "Spring 1503, 92 seasons from now."])
	assert_eq(card["next_stages"], [{"level": 5, "ok": false, "text": "None: Genoa is at its top level."}])
	assert_true(card["expensive"])


func test_4_15_e_savona_refused_by_a_rule() -> void:
	var g := EconomyFixture.game(&"GEN")
	var card := ImprovePreview.of(g, &"GEN", Vector2i(6, 13), {"action": Works.UPGRADE, "family": 0})
	assert_eq(card["blocked_by"], &"rule")
	assert_eq(card["reason_words"], "Cuneo (5, 13) is a town beside Savona: two towns may not stand side by side.")
	assert_eq(card["by_season"], [])
	assert_eq(card["requirements"], [])
	assert_eq(card["cost"], {"text": ""})
	assert_eq(card["year"], {})
	assert_eq(card["map_marks"], {})
	_same_keys(card, PreviewSample.savona_walls_refused(), "savona")


# ----- blocked_by, words, payback, expensive ------------------------------------------------------------------------------


func test_blocked_by_for_each_refusal_kind() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var city := {"action": Works.UPGRADE, "family": 0}
	g.dev_money(&"GEN", 3000)
	var ok := ImprovePreview.of(g, &"GEN", Vector2i(8, 13), city)
	assert_eq(ok["blocked_by"], &"")
	assert_eq(ok["reason_words"], "")
	assert_eq(ok["cost"]["text"], "1,000 ducats · 20 timber · 40 stone · 8 seasons · ready Spring 1482")
	g.dev_goods(&"GEN", 12, -30)
	var short := ImprovePreview.of(g, &"GEN", Vector2i(8, 13), city)
	assert_eq(short["blocked_by"], &"goods")
	assert_eq(short["reason_words"], "Not enough stone: 40 needed, 10 in store.")
	assert_false((short["by_season"] as Array).is_empty(), "money refusals show everything")
	g.dev_money(&"GEN", -2800)
	assert_eq(ImprovePreview.of(g, &"GEN", Vector2i(8, 13), city)["blocked_by"], &"ducats", "ducats are checked first")
	# the slots: two works fill Genoa's two.
	var g2 := EconomyFixture.game(&"GEN", true)
	var id := Countries.by_tag(g2, &"GEN").id
	var begun := 0
	for i: int in Territory.districts(g2, id):
		var hex := g2.map.hex_of(i)
		for row: Dictionary in ImprovePreview.options_of(g2, &"GEN", hex):
			if row["action"] == Works.BUILD and bool(row["verdict"]["ok"]) and begun < 2:
				g2.act("build", {"hex": hex, "family": row["family"], "tag": &"GEN"})
				begun += 1
				break
	assert_eq(begun, 2)
	var found := false
	for i: int in Territory.districts(g2, id):
		var hex := g2.map.hex_of(i)
		for row: Dictionary in ImprovePreview.options_of(g2, &"GEN", hex):
			if not found and row["action"] == Works.BUILD:
				var card := ImprovePreview.of(g2, &"GEN", hex, row)
				if card["blocked_by"] == &"slot":
					found = true
					assert_eq(card["reason_words"], "No free work slot: 2 of 2 in use.")
					var failed := 0
					for line: Dictionary in card["requirements"]:
						if str(line["text"]).begins_with("a free work slot") and not bool(line["ok"]):
							failed += 1
					assert_eq(failed, 1)
	assert_true(found)


## [rule, family A, level A, family B, level B, radius]: A is the option, B stands.
const PAIRS: Array[Array] = [
	[0, ImproveRules.SETTLEMENT, 3, ImproveRules.SETTLEMENT, 3, 1], [1, ImproveRules.CASTLE, 1, ImproveRules.CASTLE, 1, 2],
	[2, ImproveRules.WHEAT, 3, ImproveRules.HEMP, 3, 1], [3, ImproveRules.MINES, 1, ImproveRules.MINES, 1, 1],
	[4, ImproveRules.QUARRY, 1, ImproveRules.QUARRY, 1, 1], [5, ImproveRules.MINES, 1, ImproveRules.QUARRY, 1, 1],
	[6, ImproveRules.SALT, 1, ImproveRules.SALT, 1, 1], [7, ImproveRules.HARBOUR, 1, ImproveRules.HARBOUR, 1, 1],
	[8, ImproveRules.DYES, 1, ImproveRules.DYES, 1, 2], [9, ImproveRules.DYES, 1, ImproveRules.SALT, 1, 1],
	[10, ImproveRules.SILK, 1, ImproveRules.OLIVES, 1, 1], [11, ImproveRules.SILK, 2, ImproveRules.SILK, 2, 1],
	[12, ImproveRules.CASTLE, 1, ImproveRules.SETTLEMENT, 4, 1],
]


## A wild hex A with nothing within two hexes and a land hex B at `radius` from it.
func _site(g: Game, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in g.map.hex_count():
		if g.map.land[i] == 0 or g.state.main_use[i] != 0 or Improve.place_of(g.map, g.map.hex_of(i)).has("name"):
			continue
		var a := g.map.hex_of(i)
		var clear := true
		var far: Array[Vector2i] = []
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				var at := Vector2i(a.x + dx, a.y + dy)
				var d := ImproveRules.hex_distance(a, at)
				var j := g.map.index_of(at)
				if d == 0 or d > 2 or j < 0:
					continue
				if g.map.land[j] == 0 or g.state.main_use[j] != 0:
					clear = false
				elif d == radius:
					far.append(at)
		if clear and not far.is_empty():
			out.append(a)
			out.append(far[0])
			return out
	return out


func test_reason_words_for_each_of_the_13_pair_rules() -> void:
	assert_eq(PAIRS.size(), ImproveRules.PAIR_RULES.size())
	for entry: Array in PAIRS:
		var r := int(entry[0])
		var g := EconomyFixture.game(&"GEN")
		var site := _site(g, int(entry[5]))
		assert_eq(site.size(), 2, "a site for rule %d" % r)
		var a := site[0]
		var b := site[1]
		var action := Works.BUILD
		if int(entry[2]) > 1:
			g.improvement.put_piece(a, int(entry[1]), int(entry[2]) - 1)
			action = Works.UPGRADE
		g.improvement.put_piece(b, int(entry[3]), int(entry[4]))
		var clash := g.improvement.conflict(a, int(entry[1]), int(entry[2]))
		assert_eq(int(clash.get("rule", -1)), r, "rule %d is the first broken" % r)
		var verdict := {"ok": false, "reason": "%s (x)" % ImproveRules.PAIR_RULES[r][5]}
		var words := ImprovePreview.reason_words(g, a, {"action": action, "family": int(entry[1])}, verdict)
		assert_eq(words, ImproveRules.PAIR_WORDS[r] % [Words.place(g, b), "this district"], "rule %d" % r)
		assert_true(words.ends_with("."))
	# row 6: a work under way near is the other place.
	var g2 := EconomyFixture.game(&"GEN")
	var site := _site(g2, 1)
	var w := Work.new()
	w.id = 99
	w.tag = &"GEN"
	w.hex = site[1]
	w.action = Works.BUILD
	w.family = ImproveRules.MINES
	w.level_to = 1
	w.seasons = 4
	w.seasons_left = 4
	g2.state.works.append(w)
	var why := Works.pending_conflict(g2, site[0], ImproveRules.MINES, 1)
	assert_ne(why, "")
	var pending := {"ok": false, "reason": "a work under way at (%d, %d) would break it: %s" % [site[1].x, site[1].y, why]}
	var mines := {"action": Works.BUILD, "family": ImproveRules.MINES}
	assert_eq(ImprovePreview.reason_words(g2, site[0], mines, pending), ImproveRules.PAIR_WORDS[3] % [Words.place(g2, site[1]), "this district"])
	assert_eq(ImprovePreview.reason_words(g2, site[0], mines, {"ok": false, "reason": "something else"}), "Something else.")
	assert_eq(ImprovePreview.reason_words(g2, site[0], mines, {"ok": true, "reason": ""}), "")


func test_the_requirements_name_each_pair_rule_that_concerns_the_option() -> void:
	var g := EconomyFixture.game(&"GEN")
	var site := _site(g, 1)
	g.improvement.put_piece(site[1], ImproveRules.MINES, 1)
	var lines := ImproveCardParts.pair_lines(g, site[0], ImproveRules.MINES, 1)
	var texts: Array[String] = []
	for line: Dictionary in lines:
		texts.append(str(line["text"]) + ("" if bool(line["ok"]) else " (x)"))
	assert_eq(texts, ["no other mine beside it (x)", "no mine or quarry beside it"])
	assert_eq(ImproveCardParts.pair_lines(g, site[0], VINEYARD, 1), [] as Array[Dictionary], "a first-stage vineyard meets no pair rule")


func test_payback() -> void:
	var gains: Array[int] = [-2, -3, 28, -1]
	assert_eq(ImprovePreview.payback(gains, 40, 5, 1480, 1), {"turn": 11, "seasons": 10, "date": "Autumn 1482", "prestige": false})
	var down: Array[int] = [-1, -1, -1, -1]
	assert_eq(ImprovePreview.payback(down, 100, 5, 1480, 1), {"turn": 0, "seasons": -1, "date": "", "prestige": true})
	var slow: Array[int] = [1, 0, 0, 0]
	assert_true(bool(ImprovePreview.payback(slow, 1000, 5, 1480, 1)["prestige"]), "past 400 seasons is never")


func test_a_castle_on_a_pass_never_pays_back() -> void:
	var g := EconomyFixture.game(&"GEN")
	var seen := false
	for c: Country in g.countries:
		for i: int in Territory.districts(g, c.id):
			var hex := g.map.hex_of(i)
			for row: Dictionary in ImprovePreview.options_of(g, c.tag, hex):
				if row["action"] == Works.BUILD and int(row["family"]) == ImproveRules.CASTLE and not seen:
					var card := ImprovePreview.of(g, c.tag, hex, row)
					if card["blocked_by"] == &"rule":
						continue
					seen = true
					assert_true(card["payback"]["prestige"], "a castle is a prestige work")
					assert_eq(card["payback"]["seasons"], -1)
					assert_eq(card["payback"]["text"], "Never pays back: a prestige work.")
					var brings: Array = card["brings"]
					assert_eq((brings[0] as Dictionary)["field"], &"walls")
					assert_eq((brings[1] as Dictionary)["label"], "Its worth shows in war.")
	assert_true(seen, "a pass of a country holds a wild hex")


func test_expensive() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var vineyard := {"action": Works.BUILD, "family": VINEYARD}
	assert_false(ImprovePreview.of(g, &"GEN", Vector2i(7, 12), vineyard)["expensive"], "40 of 610, 4 seasons")
	g.dev_money(&"GEN", -540)
	assert_true(ImprovePreview.of(g, &"GEN", Vector2i(7, 12), vineyard)["expensive"], "40 of 70 is over a quarter")
	var rich := EconomyFixture.game(&"GEN")
	rich.dev_money(&"GEN", 100000)
	assert_true(ImprovePreview.of(rich, &"GEN", Vector2i(8, 13), {"action": Works.UPGRADE, "family": 0})["expensive"], "eight seasons")


# ----- a map-only game, the digest, the cache, the rows -------------------------------------------------------------------


func test_a_map_only_game_has_no_money() -> void:
	var g := Game.new_game(EconomyFixture.map(), 5, EconomyFixture.defs())
	var tested := false
	for i: int in g.map.hex_count():
		if g.map.land[i] == 0 or g.state.main_use[i] != 0 or tested:
			continue
		var rows := ImprovePreview.options_of(g, &"", g.map.hex_of(i))
		if rows.is_empty():
			continue
		tested = true
		var card := ImprovePreview.of(g, &"", g.map.hex_of(i), rows[0])
		assert_eq(card["cost"]["text"], "4 seasons")
		assert_eq(card["year"], {})
		assert_eq(card["lands"], {})
		assert_eq(card["payback"], {})
		assert_false(card["expensive"])
		assert_eq((card["by_season"] as Array).size(), 4)
		assert_eq(String((rows[0] as Dictionary)["cost_text"]), "4 seasons")
	assert_true(tested)


func test_a_preview_leaves_the_digest_and_the_cache_keys_on_version() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var digest := g.digest()
	var option := {"action": Works.BUILD, "family": VINEYARD}
	var a := ImprovePreview.of(g, &"GEN", Vector2i(7, 12), option)
	ImprovePreview.options_of(g, &"GEN", Vector2i(7, 12))
	ImprovePreview.options_of(g, &"GEN", Vector2i(8, 13))
	assert_eq(g.digest(), digest, "previews change nothing")
	assert_true(is_same(a, ImprovePreview.of(g, &"GEN", Vector2i(7, 12), option)), "the same card for the same version")
	assert_false(is_same(a, ImprovePreview.of(g, &"GEN", Vector2i(7, 12), {"action": Works.BUILD, "family": ImproveRules.OLIVES})))
	g.dev_money(&"GEN", 100)
	var b := ImprovePreview.of(g, &"GEN", Vector2i(7, 12), option)
	assert_false(is_same(a, b), "a new version makes a new card")
	assert_eq((a["requirements"] as Array)[2]["text"], "40 of 610 ducats")
	assert_eq((b["requirements"] as Array)[2]["text"], "40 of 710 ducats")


func test_the_hex_panel_rows() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var rows := ImprovePreview.options_of(g, &"GEN", Vector2i(7, 12))
	var vineyard := {}
	for row: Dictionary in rows:
		assert_eq(row["action"], Works.BUILD)
		if int(row["family"]) == VINEYARD:
			vineyard = row
	assert_false(vineyard.is_empty(), "a vineyard is offered")
	assert_eq(vineyard["label"], "Build vineyard")
	assert_eq(vineyard["cost_text"], "40 · 4 seasons")
	assert_true(vineyard["verdict"]["ok"])
	assert_false(vineyard["expensive"])
	assert_eq((vineyard["chips"][0] as Dictionary)["text"], "wine +12 a year")
	var town := ImprovePreview.options_of(g, &"GEN", Vector2i(8, 13))
	assert_eq((town[0] as Dictionary)["label"], "Upgrade to city")
	assert_eq((town[0] as Dictionary)["cost_text"], "1,000 · 20 timber · 40 stone · 8 seasons")
	assert_true((town[0] as Dictionary)["expensive"])
	assert_eq((town[town.size() - 1] as Dictionary)["action"], Works.CLEAR)
	for i: int in g.map.hex_count():
		if g.map.land[i] == 0:
			assert_eq(ImprovePreview.options_of(g, &"GEN", g.map.hex_of(i)), [] as Array[Dictionary], "sea gives no rows")
			break


func test_a_light_row_gives_the_cards_goods_and_people_chips_and_full_gives_the_gain_too() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	for hex: Vector2i in [Vector2i(7, 12), Vector2i(8, 13), Vector2i(9, 13)]:
		var light := ImprovePreview.options_of(g, &"GEN", hex)
		var full := ImprovePreview.options_of(g, &"GEN", hex, true)
		assert_eq(light.size(), full.size())
		for n: int in light.size():
			var l: Dictionary = light[n]
			var f: Dictionary = full[n]
			assert_eq([l["action"], l["family"], l["label"], l["verdict"], l["cost_text"], l["expensive"]],
				[f["action"], f["family"], f["label"], f["verdict"], f["cost_text"], f["expensive"]], "%s row %d" % [str(hex), n])
			var kept: Array[Dictionary] = []
			for chip: Dictionary in f["chips"]:
				if chip["kind"] != &"gain":
					kept.append(chip)
			assert_eq(l["chips"], kept, "%s row %d: the light chips are the card's others" % [str(hex), n])
			var card := ImprovePreview.of(g, &"GEN", hex, {"action": l["action"], "family": l["family"]})
			assert_eq(f["chips"], card["chips"])
