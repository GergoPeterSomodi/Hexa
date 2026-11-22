## The money property (docs/architecture/m4-build-spec.md 9, the M4 done-when 2): 40 seasons of the 1480 scenario with
## seeded random actions for EVERY country (works begun, upgraded, cleared and cancelled, taxes set, money and goods from
## the console). Every season, for every country: the treasury's change equals the sum of its ledger lines; each line's
## reason is in Treasury.WHY; each good's stock change equals the sum of its flows; a refund never exceeds what the work
## paid, and comes only in the work's first season; no stock below zero; the DistrictCache equals Economy.district_base
## on every land hex (5.0 A5); the Country digest is equal after to_dict/from_dict, and after a save and a load every 10
## seasons (the whole game's digest too). Determinism and save round trip (spec 9).
extends GutTest

const SEASONS := 40
const SEED := 1480
const SAVE_EVERY := 10
const TRIES := 10
const TIMBER := 11
const STONE := 12
const IRON := 13

var _dir := ""
## What the run exercised, so the property is not vacuous.
var _seen := {}


func before_each() -> void:
	_dir = "user://test_money_property_%d/" % Time.get_ticks_usec()
	_reset_seen()


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir + f)
		DirAccess.remove_absolute(_dir)


func _reset_seen() -> void:
	_seen = {"begun": 0, "cancelled": 0, "refunded": 0, "taxed": 0, "refused_money": 0, "work_lines": 0}


## Money and goods now and then, and not always enough (the refusals of 4.11 rows 8 and 9 happen too).
func _fund(g: Game, c: Country, luck: Rng, n: int) -> void:
	if luck.randi_range(0, 3) == 0:
		assert_true(g.dev_money(c.tag, luck.randi_range(50, 600)), "dev_money")
	if luck.randi_range(0, 7) == 0:
		for good: int in [TIMBER, STONE, IRON]:
			assert_true(g.dev_goods(c.tag, good, luck.randi_range(5, 40)), "dev_goods")
	if n % 11 == 5 and luck.randi_range(0, 1) == 0:
		assert_true(g.dev_money(c.tag, -int(c.treasury / 2.0)), "a console debit")


## Cancels one work of the country now and then: the refund is what it paid, in its first season only, never more.
func _cancel_one(g: Game, c: Country, luck: Rng) -> void:
	var mine: Array[Work] = []
	for w: Work in g.state.works:
		if w.tag == c.tag:
			mine.append(w)
	if mine.is_empty() or luck.randi_range(0, 2) != 0:
		return
	var work := mine[luck.randi_range(0, mine.size() - 1)]
	var label := "%s cancelling at %s on turn %d" % [c.tag, work.hex, g.turn]
	var first_season := work.started_turn == g.turn
	var treasury := c.treasury
	var stock := c.stock.duplicate()
	var paid_goods := work.paid_goods.duplicate()
	var paid := work.paid
	g.events.clear()
	assert_true(bool(g.act("cancel_work", {"hex": work.hex, "tag": c.tag})["ok"]), label)
	var refund := int(g.events[g.events.size() - 1]["refund"])
	_seen["cancelled"] += 1
	assert_eq(c.treasury - treasury, refund, "the treasury got exactly the refund, " + label)
	assert_lte(refund, paid, "a refund never exceeds what the work paid, " + label)
	for good: int in stock.size():
		var gained := c.stock[good] - stock[good]
		var key := String(g.defs.good(good).key)
		assert_gte(gained, 0, "a cancel takes no goods, " + label)
		assert_lte(gained, int(paid_goods.get(key, 0)), "goods back never exceed goods paid (%s), %s" % [key, label])
		if not first_season:
			assert_eq(gained, 0, "no goods back after the first season, " + label)
	if not first_season:
		assert_eq(refund, 0, "and no ducats back after the first season, " + label)
	elif refund > 0:
		_seen["refunded"] += 1


## Up to a few random works actions (begin, upgrade, clear); a refused one must leave the treasury and the stores alone.
func _begin_works(g: Game, c: Country, luck: Rng) -> void:
	var districts := Territory.districts(g, c.id)
	if districts.is_empty():
		return
	var want := luck.randi_range(0, 3)
	var got := 0
	for t: int in TRIES:
		if got >= want:
			break
		var hex := g.map.hex_of(districts[luck.randi_range(0, districts.size() - 1)])
		var args := {"hex": hex, "tag": c.tag}
		var action := "build"
		var kind := luck.randi_range(0, 5)
		if kind == 0:
			action = "upgrade"
		elif kind == 1:
			action = "clear"
		else:
			var options: Array[Dictionary] = []
			for o: Dictionary in g.improvement.build_options(hex):
				if bool(o["ok"]):
					options.append(o)
			if options.is_empty():
				continue
			args["family"] = int((options[luck.randi_range(0, options.size() - 1)])["family_id"])
		var treasury := c.treasury
		var stock := c.stock.duplicate()
		var verdict := g.act(action, args)
		if bool(verdict["ok"]):
			got += 1
			_seen["begun"] += 1
			var work := g.state.work_at(hex)
			assert_not_null(work, "an accepted works action adds a work")
			if work != null:
				assert_eq(treasury - c.treasury, work.paid, "%s: the treasury paid what the work paid" % c.tag)
		else:
			if str(verdict["reason"]).begins_with("not enough"):
				_seen["refused_money"] += 1
			assert_eq(c.treasury, treasury, "a refused action leaves the treasury, %s: %s" % [c.tag, verdict["reason"]])
			assert_eq(c.stock, stock, "and the stores, %s" % c.tag)


## Two random army actions a country (raise, march, split, merge, disband, halt...): ducats go through Treasury.move, the
## raise and the refund of a disband in their lines (M6 L13). A refund of an army is not a work's refund.
func _armies(g: Game, c: Country, luck: Rng) -> void:
	for _k: int in 2:
		var pick: Dictionary = RandomPlayer.next(g, c.tag, luck)
		var treasury := c.treasury
		var verdict: Dictionary = g.act(str(pick["action"]), pick["args"])
		if bool(verdict["ok"]):
			_seen["armies"] = int(_seen.get("armies", 0)) + 1
		else:
			assert_eq(c.treasury, treasury, "a refused army action leaves the treasury alone: %s" % verdict["reason"])


func _tax(g: Game, c: Country, luck: Rng) -> void:
	if luck.randi_range(0, 4) != 0:
		return
	var verdict := g.act("set_tax", {"level": luck.randi_range(0, 2), "tag": c.tag})
	if bool(verdict["ok"]):
		_seen["taxed"] += 1


## Every season, every country: the ledger and flow sums, the reasons, the refunds, the digest, the cache.
func _check_season(g: Game, ended: int, closings: Dictionary) -> void:
	for c: Country in g.countries:
		var closed := c.ledger_closed
		var label := "%s, season %d" % [c.tag, ended]
		assert_eq(int(closed["turn"]), ended, "the ledger is of this season, " + label)
		var sum := 0
		var paid := 0
		var refunds := 0
		var army_refunds := 0
		for e: Dictionary in g.events:
			if str(e.get("kind", "")) == "army_disbanded" and int(e.get("turn", -1)) == ended:
				army_refunds += int(e["refund"])
		for line: Dictionary in closed["lines"] as Array:
			assert_true(Treasury.WHY.has(line["why"]), "a known reason (%s), %s" % [line["why"], label])
			sum += int(line["amount"])
			if line["why"] == &"work":
				paid -= int(line["amount"])
				_seen["work_lines"] += 1
			elif line["why"] == &"refund":
				refunds += int(line["amount"])
		assert_eq(int(closed["closing"]) - int(closed["opening"]), sum, "the treasury's change is the lines' sum, " + label)
		assert_eq(int(closed["closing"]), c.treasury, "closing is the treasury, " + label)
		assert_lte(refunds - army_refunds, paid, "refunds never exceed what the works paid, " + label)
		if closings.has(c.tag):
			assert_eq(int(closed["opening"]), int(closings[c.tag]), "no change of the treasury between seasons, " + label)
		closings[c.tag] = int(closed["closing"])
		assert_true(c.ledger_open.is_empty(), "the lines start again, " + label)
		var goods := c.goods_closed
		var opening := goods["opening"] as PackedInt32Array
		var closing := goods["closing"] as PackedInt32Array
		var flows := goods["flows"] as PackedInt32Array
		var count := closing.size()
		for good: int in count:
			var net := 0
			for flow: int in Stores.FLOWS.size():
				net += flows[flow * count + good]
			assert_eq(closing[good] - opening[good], net, "stock change is the flows' sum, good %d, %s" % [good, label])
			assert_gte(closing[good], 0, "no stock below zero, good %d, %s" % [good, label])
		assert_eq(closing, c.stock, "closing is the stock, " + label)
		var back := Country.from_dict(c.to_dict())
		assert_not_null(back, "the country reads back, " + label)
		if back != null:
			assert_eq(back.digest_text(), c.digest_text(), "the Country digest after to_dict and from_dict, " + label)
	_check_cache(g, ended)


## 5.0 A5: the cache equals Economy.district_base on every land hex (what the season's changes touched is forgotten and
## computed again, the rest is held).
func _check_cache(g: Game, ended: int) -> void:
	var view := StateView.of(g.state)
	var stale := 0
	var first := -1
	for i: int in g.map.hex_count():
		if g.map.land[i] == 0:
			continue
		if g.districts.base_of(g, i) != Economy.district_base(g, view, g.map.hex_of(i)):
			stale += 1
			if first < 0:
				first = i
	assert_eq(stale, 0, "the DistrictCache equals district_base on every land hex, season %d (first stale %d)" % [ended, first])


## Saves, loads and returns the loaded game; every country's digest is equal on both sides.
func _through_a_file(g: Game) -> Game:
	assert_eq(SaveFile.write(g, "1", {"saved_unix": 1}, {}, _dir), "")
	var read := SaveFile.read("1", _dir)
	assert_eq(read["problem"], "")
	var restored := Snapshot.restore(read["body"] as Dictionary, g.map, g.defs)
	assert_eq(restored["problem"], "")
	var back := restored["game"] as Game
	assert_not_null(back)
	assert_eq(back.countries.size(), g.countries.size())
	for i: int in g.countries.size():
		assert_eq(back.countries[i].digest_text(), g.countries[i].digest_text(),
			"the Country digest after a load, %s" % g.countries[i].tag)
	assert_eq(back.digest(), g.digest(), "the game's digest after a load")
	return back


## Plays SEASONS seasons; with `save` a save and a load every SAVE_EVERY seasons. Returns the final game and the digests.
func _play(seed_value: int, save: bool, calm: bool) -> Dictionary:
	var g := EconomyFixture.game(&"GEN", false, calm, seed_value)
	var luck := Rng.new()
	luck.seed_with(seed_value)
	var digests: Array[String] = []
	var closings := {}
	for n: int in SEASONS:
		for c: Country in g.countries:
			_fund(g, c, luck, n)
			_begin_works(g, c, luck)
			_cancel_one(g, c, luck)  # after the begins: some cancels are in the work's first season
			_tax(g, c, luck)
			_armies(g, c, luck)
		var ended := g.turn
		assert_true(bool(Season.run(g)["ok"]), "the season ends")
		assert_eq(g.turn, ended + 1)
		_check_season(g, ended, closings)
		if save and (n + 1) % SAVE_EVERY == 0:
			g = _through_a_file(g)
		digests.append(g.digest())
	return {"game": g, "digests": digests}


func _exercised() -> void:
	assert_gt(int(_seen["begun"]), 100, "works were begun")
	assert_gt(int(_seen["cancelled"]), 20, "works were cancelled")
	assert_gt(int(_seen["refunded"]), 5, "refunds were paid")
	assert_gt(int(_seen["taxed"]), 20, "taxes were set")
	assert_gt(int(_seen["refused_money"]), 0, "some works were refused for money or goods")
	assert_gt(int(_seen["work_lines"]), 100, "works were paid in the ledgers")
	assert_gt(int(_seen.get("armies", 0)), 20, "army actions were accepted")


func test_forty_seasons_real_weather_every_country() -> void:
	var run := _play(SEED, false, false)
	assert_eq((run["game"] as Game).turn, SEASONS + 1)
	_exercised()


func test_forty_seasons_calm_with_a_save_and_load_every_ten() -> void:
	var plain := _play(SEED + 1, false, true)
	var plain_seen := _seen.duplicate()
	_reset_seen()
	var saved := _play(SEED + 1, true, true)
	assert_eq(_seen, plain_seen, "the same actions in both runs")
	assert_eq(saved["digests"], plain["digests"], "a save and a load every ten seasons changes no season's digest")
	_exercised()
