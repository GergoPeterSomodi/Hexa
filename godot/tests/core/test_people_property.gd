## The people properties (docs/architecture/m5-build-spec.md 9, done-when 2 and 3; 5.0 A5): 40 seasons of the 1480 scenario with
## seeded random actions for EVERY country (works begun and cancelled, taxes set, money, `Game.dev_people`) and weather drawn.
## Every season, every country: the change of its people (hex by hex summed over its land) equals the sum of its closed flows;
## the world's change equals the sum over all countries; no hex is below zero; growth never takes a hex past its room; a level
## changes only with its event (or a work_finished); every town_grew was full and fed, every district_declined under its floor;
## the food eaten never exceeds the need; fed (1,000) exactly when the eaten food equals the need; the Stats food series equal
## the closed Stores flows and food_need. Determinism and save, load and continue (a save every ten seasons changes no digest).
## No transfer of hexes happens (dev_transfer stays out: the per-country sum is exact only in seasons without a transfer, A6).
extends GutTest

const SEASONS := 40
const SAVE_EVERY := 10
const SEED := 1480
const TRIES := 10

var _dir := ""
var _seen := {}


func before_each() -> void:
	_dir = "user://test_people_property_%d/" % Time.get_ticks_usec()
	_reset_seen()


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir + f)
		DirAccess.remove_absolute(_dir)


func _reset_seen() -> void:
	_seen = {"begun": 0, "cancelled": 0, "taxed": 0, "dev": 0, "grew": 0, "starved": 0, "left": 0, "raised_level": 0,
		"fell_level": 0, "hungry": 0, "work_finished": 0}


# ----- the random actions --------------------------------------------------------------------------------------------------


func _act(g: Game, c: Country, luck: Rng) -> void:
	# Two random army actions (raise, march, split, merge, disband, halt...): the people move with the men (M6, L13).
	for _k: int in 2:
		var pick: Dictionary = RandomPlayer.next(g, c.tag, luck)
		# Wars are not in the snapshot yet (B13 wires them): a declaration or a peace would make the saved run forget its wars
		# and diverge. The pick still draws from the stream, so the other picks do not move.
		if str(pick["action"]) in ["declare_war", "make_peace"]:
			continue
		if bool(g.act(str(pick["action"]), pick["args"])["ok"]):
			_seen["armies"] = int(_seen.get("armies", 0)) + 1
	if luck.randi_range(0, 3) == 0:
		g.dev_money(c.tag, luck.randi_range(50, 600))
	if luck.randi_range(0, 7) == 0:
		for good: int in [11, 12, 13]:
			g.dev_goods(c.tag, good, luck.randi_range(5, 40))
	var districts := Territory.districts(g, c.id)
	if districts.is_empty():
		return
	for _t: int in luck.randi_range(0, 2):
		for _try: int in TRIES:
			var hex := g.map.hex_of(districts[luck.randi_range(0, districts.size() - 1)])
			var options: Array[Dictionary] = []
			for o: Dictionary in g.improvement.build_options(hex):
				if bool(o["ok"]):
					options.append(o)
			if options.is_empty():
				continue
			var pick := options[luck.randi_range(0, options.size() - 1)]
			if bool(g.act("build", {"hex": hex, "family": int(pick["family_id"]), "tag": c.tag})["ok"]):
				_seen["begun"] += 1
				break
	for w: Work in g.state.works:
		if w.tag == c.tag and luck.randi_range(0, 11) == 0:
			if bool(g.act("cancel_work", {"hex": w.hex, "tag": c.tag})["ok"]):
				_seen["cancelled"] += 1
			break
	if luck.randi_range(0, 4) == 0 and bool(g.act("set_tax", {"level": luck.randi_range(0, 2), "tag": c.tag})["ok"]):
		_seen["taxed"] += 1
	if luck.randi_range(0, 2) == 0:
		_dev_people(g, luck, districts)


## A developer edit of one hex of the country: a random number up to twice its room, exactly its room (a full village grows
## when fed), just under the level's floor (a town falls), or nothing.
func _dev_people(g: Game, luck: Rng, districts: Array) -> void:
	var i := int(districts[luck.randi_range(0, districts.size() - 1)])
	var room := g.districts.room_of(g, i)
	var value := 0
	match luck.randi_range(0, 3):
		0:
			value = luck.randi_range(0, maxi(room * 2, 10))
		1:
			value = room
		2:
			var level := int(g.state.level[i])
			if g.state.main_use[i] == Economy.SETTLEMENTS and level >= 2:
				var fam := g.defs.family(Economy.SETTLEMENTS)
				value = maxi(int(fam.falls_below[level]) - 1, 0)
			else:
				value = luck.randi_range(0, maxi(room, 1))
		_:
			value = 0
	if g.dev_people(g.map.hex_of(i), value):
		_seen["dev"] += 1


# ----- the checks ----------------------------------------------------------------------------------------------------------


## What the season must do, checked against `pre` (the people before the actions) and `mid` (after them, before the season).
func _check_season(g: Game, ended: int, pre: PackedInt32Array, mid: PackedInt32Array, mid_level: PackedByteArray,
		mid_use: PackedByteArray, open_before: Dictionary, open_after: Dictionary) -> void:
	var state := g.state
	var sums := {}
	var world_change := 0
	var world_flows := 0
	for i: int in g.map.hex_count():
		var label := "hex %d, season %d" % [i, ended]
		if g.map.land[i] == 0:
			assert_eq(state.people[i], 0, "sea holds nobody, " + label)
			continue
		assert_gte(state.people[i], 0, "no hex below zero, " + label)
		var owner_id := int(state.owner[i])
		var delta: int = state.people[i] - pre[i]
		world_change += delta
		if owner_id == 0:
			assert_eq(delta, 0, "unowned land never changes, " + label)
		else:
			sums[owner_id] = int(sums.get(owner_id, 0)) + delta
		assert_lte(state.people[i], maxi(mid[i], g.districts.room_of(g, i)), "growth never passes the room, " + label)
		var changed_level: bool = int(state.level[i]) != int(mid_level[i]) or int(state.main_use[i]) != int(mid_use[i])
		if changed_level:
			var hex := g.map.hex_of(i)
			var explained := false
			for e: Dictionary in g.events:
				if e.get("hex") == hex and str(e.get("kind", "")) in ["town_grew", "district_declined", "work_finished"]:
					explained = true
			assert_true(explained, "a level changes only with its event, " + label)
	for c: Country in g.countries:
		var label := "%s, season %d" % [c.tag, ended]
		var closed := c.people_closed["flows"] as PackedInt32Array
		assert_eq(int(c.people_closed["turn"]), ended, "the closed flows are of this season, " + label)
		# The season's window: closed at its stats phase, less what was open before its actions, plus what is open after
		# it (the refill and the vision of ready_units run after the close: they close with the next season, M6 R1).
		var flows := PackedInt32Array()
		var before: PackedInt32Array = open_before[c.tag]
		var after: PackedInt32Array = open_after[c.tag]
		for f: int in closed.size():
			flows.append(closed[f] - before[f] + after[f])
		var flow_sum := 0
		for f: int in flows:
			flow_sum += f
		world_flows += flow_sum
		assert_eq(int(sums.get(c.id, 0)), flow_sum, "the change of the people equals the flows' sum, " + label)
		assert_gte(flows[People.GREW], 0, "grew, " + label)
		assert_lte(flows[People.STARVED], 0, "starved, " + label)
		assert_lte(flows[People.LEFT], 0, "left, " + label)
		_seen["grew"] += 1 if flows[People.GREW] > 0 else 0
		_seen["starved"] += 1 if flows[People.STARVED] < 0 else 0
		_seen["left"] += 1 if flows[People.LEFT] < 0 else 0
		_check_food(g, c, ended, label)
	assert_eq(world_change, world_flows, "the world's change equals the sum over all countries, season %d" % ended)
	for e: Dictionary in g.events:
		_check_event(g, e, ended)


## Each country's open people flows now: {tag: PackedInt32Array}.
func _open_flows(g: Game) -> Dictionary:
	var out := {}
	for c: Country in g.countries:
		out[c.tag] = c.people_flows.duplicate()
	return out


func _check_food(g: Game, c: Country, ended: int, label: String) -> void:
	var grain := g.defs.good_id(&"grain")
	var fish := g.defs.good_id(&"fish")
	var eaten := -(Stores.flow(c, grain, &"used", true) + Stores.flow(c, fish, &"used", true))
	var made := maxi(Stores.flow(c, grain, &"made", true), 0) + maxi(Stores.flow(c, fish, &"made", true), 0)
	assert_gte(eaten, 0, "food eaten is a take, " + label)
	assert_lte(eaten, c.food_need, "the food eaten never exceeds the need, " + label)
	assert_eq(c.food_fed == 1000, eaten == c.food_need, "fed exactly when the eaten food equals the need, " + label)
	if c.food_fed < 1000:
		_seen["hungry"] += 1
	assert_eq(g.stats.value(c.tag, ended, "food_made"), made, "Stats food_made is the closed flows, " + label)
	assert_eq(g.stats.value(c.tag, ended, "food_eaten"), eaten, "Stats food_eaten, " + label)
	assert_eq(g.stats.value(c.tag, ended, "food_need"), c.food_need, "Stats food_need, " + label)


func _check_event(g: Game, e: Dictionary, ended: int) -> void:
	var kind := str(e.get("kind", ""))
	if kind == "work_finished":
		_seen["work_finished"] += 1
		return
	if kind != "town_grew" and kind != "district_declined":
		return
	var c := Countries.by_tag(g, e["tag"])
	var label := "%s at %s, season %d" % [kind, e["hex"], ended]
	var fam := g.defs.family(Economy.SETTLEMENTS)
	if kind == "town_grew":
		_seen["raised_level"] += 1
		assert_eq(c.food_fed, 1000, "a town grew only when fed, " + label)
		assert_eq(int(e["level"]), int(e["from"]) + 1, "one level, " + label)
		assert_lt(int(e["from"]), g.defs.people_top_level, "never past the people's top level, " + label)
		assert_gte(int(e["people"]), int(fam.room[int(e["from"])]), "it was full, " + label)
		assert_eq(int(g.state.level[g.map.index_of(e["hex"])]), int(e["level"]), "the map holds the level, " + label)
	else:
		_seen["fell_level"] += 1
		assert_eq(int(e["level"]), int(e["from"]) - 1, "one level, " + label)
		assert_lt(int(e["people"]), int(fam.falls_below[int(e["from"])]), "under its floor, " + label)
		assert_eq(str(e["why"]), "hunger" if c.food_fed < 1000 else "people", "the cause, " + label)


# ----- the run -------------------------------------------------------------------------------------------------------------


func _through_a_file(g: Game) -> Game:
	assert_eq(SaveFile.write(g, "1", {"saved_unix": 1}, {}, _dir), "")
	var read := SaveFile.read("1", _dir)
	assert_eq(read["problem"], "")
	var restored := Snapshot.restore(read["body"] as Dictionary, g.map, g.defs)
	assert_eq(restored["problem"], "")
	var back := restored["game"] as Game
	assert_not_null(back)
	assert_eq(back.digest(), g.digest(), "the game's digest after a load")
	for i: int in g.countries.size():
		assert_eq(back.countries[i].digest_text(), g.countries[i].digest_text(), "the Country digest after a load, %s" % g.countries[i].tag)
	return back


func _play(seed_value: int, save: bool, calm: bool, check: bool) -> Dictionary:
	var g := EconomyFixture.game(&"GEN", false, calm, seed_value, false)  # the real people rules
	var luck := Rng.new()
	luck.seed_with(seed_value)
	var digests: Array[String] = []
	for n: int in SEASONS:
		var pre := g.state.people.duplicate()
		var open_before := _open_flows(g)
		for c: Country in g.countries:
			_act(g, c, luck)
		var mid := g.state.people.duplicate()
		var mid_level := g.state.level.duplicate()
		var mid_use := g.state.main_use.duplicate()
		g.events.clear()
		var ended := g.turn
		assert_true(bool(Season.run(g)["ok"]), "the season ends")
		assert_eq(g.turn, ended + 1)
		if check:
			_check_season(g, ended, pre, mid, mid_level, mid_use, open_before, _open_flows(g))
		if save and (n + 1) % SAVE_EVERY == 0:
			g = _through_a_file(g)
		digests.append(g.digest())
	return {"game": g, "digests": digests}


func _exercised() -> void:
	gut.p("seen: %s" % str(_seen))
	assert_gt(int(_seen["begun"]), 50, "works were begun")
	assert_gt(int(_seen["dev"]), 50, "dev_people was used")
	assert_gt(int(_seen["grew"]), 100, "people grew")
	assert_gt(int(_seen["left"]), 0, "crowded hexes lost people")
	assert_gt(int(_seen["raised_level"]), 0, "a settlement grew a level")
	assert_gt(int(_seen["fell_level"]), 0, "a settlement fell a level")
	assert_gt(int(_seen["hungry"]), 0, "some country went hungry")
	assert_gt(int(_seen.get("armies", 0)), 20, "army actions were accepted")


func test_forty_seasons_real_weather_every_country_conserve_their_people() -> void:
	var run := _play(SEED, false, false, true)
	assert_eq((run["game"] as Game).turn, SEASONS + 1)
	_exercised()


func test_forty_seasons_calm_with_a_save_and_load_every_ten() -> void:
	var plain := _play(SEED + 1, false, true, true)
	var plain_seen := _seen.duplicate()
	_reset_seen()
	var saved := _play(SEED + 1, true, true, false)
	assert_eq(saved["digests"], plain["digests"], "a save and a load every ten seasons changes no season's digest")
	_seen = plain_seen
	_exercised()


func test_the_same_seed_gives_the_same_digests() -> void:
	var a := _play(SEED + 2, false, false, false)
	var b := _play(SEED + 2, false, false, false)
	assert_eq(a["digests"], b["digests"])
	var other := _play(SEED + 3, false, false, false)
	assert_ne(other["digests"][SEASONS - 1], a["digests"][SEASONS - 1], "another seed ends elsewhere")


func test_a_planted_person_breaks_the_conservation() -> void:
	# P: a person added behind People's back makes the change differ from the flows' sum (the check's own proof).
	var g := EconomyFixture.game(&"GEN", false, true, SEED, false)
	var pre := g.state.people.duplicate()
	Season.run(g)
	var c := Countries.by_tag(g, &"GEN")
	var flows := c.people_closed["flows"] as PackedInt32Array
	var total := 0
	for f: int in flows:
		total += f
	assert_eq(_change_of(g, c, pre), total, "the honest season conserves")
	g.state.people[g.map.index_of(Vector2i(8, 13))] += 1
	assert_ne(_change_of(g, c, pre), total, "one person from nowhere is seen")


func _change_of(g: Game, c: Country, pre: PackedInt32Array) -> int:
	var change := 0
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) == c.id:
			change += g.state.people[i] - pre[i]
	return change
