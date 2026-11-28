## The queued company's entry as state (docs/design/recruitment-queue.md sections 5 and 6; task RQ5): saved and loaded
## byte-equal, in the digest field by field, a game with none as before, and each damaged body refused. No rule makes or
## reads an entry yet, so the entries here are planted: each on a settlement of its tag with a barracks.
extends GutTest

const INFO := {"build": "0.3.0", "name": "Muster", "saved_unix": 1700000000, "play_seconds": 5}
const TURIN := Vector2i(5, 9)
const GENOA := Vector2i(8, 13)
const BERN := Vector2i(5, 0)
## Above Bern, off the map; Bern is beside it.
const NORTH_OF_BERN := Vector2i(5, -1)
const PIKE := 0
const CROSSBOW := 1
const KNIGHTS := 2

var _dirs: Array[String] = []


func after_each() -> void:
	for dir: String in _dirs:
		for file: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	_dirs.clear()


func _dir() -> String:
	var dir := "user://test_muster_%d_%d" % [Time.get_ticks_usec(), _dirs.size()]
	_dirs.append(dir)
	return dir


## The `n`th hex beside `hex` that is land (or sea) and on the map.
func _beside(g: Game, hex: Vector2i, land: bool, n: int = 0) -> Vector2i:
	var left := n
	for d: int in 6:
		var spot := ImproveRules.neighbour(hex, d)
		if g.map.has(spot) and g.map.is_land(spot) == land:
			if left == 0:
				return spot
			left -= 1
	fail_test("no such hex beside %s" % hex)
	return ScenarioDef.NO_HEX


func _men(g: Game, kind: int) -> int:
	return g.defs.unit_def(kind).men


func _entry(id: int, tag: StringName, hex: Vector2i, kind: int, queued: int, left: int, paid: int, goods: Dictionary,
		levy: Array) -> Muster:
	var m := Muster.new()
	m.id = id
	m.tag = tag
	m.hex = hex
	m.kind = kind
	m.queued_turn = queued
	m.seasons_left = left
	m.paid = paid
	m.paid_goods = goods
	m.levy.assign(levy)
	return m


## The 1480 game two seasons on, with three queued companies (ids 2, 3 and 5: the others were withdrawn) and 7 next.
func _planted() -> Game:
	var g := EconomyFixture.game(&"GEN")
	Season.run(g)
	Season.run(g)
	g.musters.assign([
		_entry(2, &"SAV", TURIN, PIKE, 2, 1, 25, {"iron": 1},
			[[TURIN, _men(g, PIKE) - 200], [_beside(g, TURIN, true), 200]]),
		_entry(3, &"SAV", TURIN, CROSSBOW, 2, 1, 30, {"iron": 1, "timber": 1},
			[[_beside(g, TURIN, true, 1), _men(g, CROSSBOW)]]),
		_entry(5, &"GEN", GENOA, KNIGHTS, g.turn, 0, 50, {}, [[GENOA, _men(g, KNIGHTS)]]),
	])
	g.next_muster_id = 7
	return g


func _body(g: Game) -> Dictionary:
	return bytes_to_var(var_to_bytes(Snapshot.of(g))) as Dictionary


func _restore(g: Game, body: Dictionary) -> Dictionary:
	return Snapshot.restore(body, g.map, g.defs)


## Every field of every entry, as plain values.
func _fields(g: Game) -> Array:
	var out: Array = []
	for m: Muster in g.musters:
		out.append([m.id, m.tag, m.hex, m.kind, m.queued_turn, m.seasons_left, m.paid, m.paid_goods, m.levy])
	return out


## Writes the game, reads it back, writes the loaded one: [the loaded game, the header, whether the files are equal].
func _through_a_file(g: Game) -> Array:
	var first := _dir()
	assert_eq(SaveFile.write(g, "2", INFO, {}, first), "")
	var read := SaveFile.read("2", first)
	assert_eq(read["problem"], "")
	var r := _restore(g, read["body"] as Dictionary)
	assert_eq(r["problem"], "")
	var back := r["game"] as Game
	if back == null:
		return [null, read["header"], false]
	var second := _dir()
	assert_eq(SaveFile.write(back, "2", INFO, {}, second), "")
	var equal := FileAccess.get_file_as_bytes(SaveFile.path_of("2", first)) \
		== FileAccess.get_file_as_bytes(SaveFile.path_of("2", second))
	return [back, read["header"], equal]


# ----- save and load --------------------------------------------------------------------------------------------------


func test_save_load_save_is_byte_equal_with_queued_companies() -> void:
	var g := _planted()
	var got := _through_a_file(g)
	var back := got[0] as Game
	assert_not_null(back)
	assert_eq((got[1] as Dictionary)["format"], 9)
	assert_eq(_fields(back), _fields(g))
	assert_eq(back.next_muster_id, 7)
	assert_eq(back.digest(), g.digest())
	assert_eq((got[1] as Dictionary)["digest"], g.digest(), "the digest the header names")
	assert_true(bool(got[2]), "byte-equal files")


func test_goods_held_as_a_rule_may_hold_them_save_byte_equal() -> void:
	var g := _planted()
	var typed: Dictionary[StringName, int] = {&"iron": 1}
	g.musters[0].paid_goods = typed
	var got := _through_a_file(g)
	assert_not_null(got[0] as Game)
	assert_true(bool(got[2]), "byte-equal files: the saved goods are plain, whatever the entry holds")


func test_the_saved_form_is_the_designs_and_reads_from_json() -> void:
	var g := _planted()
	var saved := Recruiting.to_dict(g)
	var beside := _beside(g, TURIN, true)
	assert_eq((saved["list"] as Array)[0], {"schema": "hexa-godot/muster/1", "id": 2, "tag": "SAV", "hex": [5, 9],
		"kind": PIKE, "queued_turn": 2, "seasons_left": 1, "paid": 25, "paid_goods": {"iron": 1},
		"levy": [[[5, 9], _men(g, PIKE) - 200], [[beside.x, beside.y], 200]]})
	assert_eq([saved["schema"], saved["next_muster_id"], (saved["list"] as Array).size()], ["hexa-godot/musters/1", 7, 3])
	var other := EconomyFixture.game(&"GEN")
	other.turn = g.turn
	assert_eq(Recruiting.from_dict(JSON.parse_string(JSON.stringify(saved)) as Dictionary, other), "",
		"a JSON copy, with its floats")
	assert_eq(_fields(other), _fields(g))
	assert_eq(Recruiting.digest(other), Recruiting.digest(g))


func test_the_saved_form_shares_nothing_with_the_game() -> void:
	var g := _planted()
	var before := g.digest()
	var saved := Recruiting.to_dict(g)
	var first := (saved["list"] as Array)[0] as Dictionary
	(first["paid_goods"] as Dictionary)["iron"] = 99
	((first["levy"] as Array)[0] as Array)[1] = 99
	assert_eq(g.digest(), before)


func test_the_sound_bounds_load() -> void:
	var g := _planted()
	var ring: Array = [[TURIN, _men(g, PIKE)]]
	for d: int in 6:
		var spot := ImproveRules.neighbour(TURIN, d)
		if g.map.is_land(spot):
			(ring[0] as Array)[1] -= 1
			ring.append([spot, 1])
	assert_gt(ring.size(), 4, "a levy from many sources")
	g.musters.assign([
		_entry(1, &"SAV", TURIN, PIKE, Calendar.FIRST_TURN, 0, 0, {"iron": 0}, ring),
		_entry(6, &"SWI", BERN, PIKE, g.turn, Muster.SEASONS_MAX, Muster.PAID_MAX, {"iron": Muster.PAID_MAX},
			[[BERN, _men(g, PIKE)]]),
	])
	var r := _restore(g, _body(g))
	assert_eq(r["problem"], "")
	assert_eq(_fields(r["game"] as Game), _fields(g))


# ----- the digest -----------------------------------------------------------------------------------------------------


func test_the_digest_moves_with_every_field_of_an_entry_and_with_the_next_id() -> void:
	var g := _planted()
	var beside := _beside(g, TURIN, true)
	var other := _beside(g, TURIN, true, 2)
	var changes: Dictionary = {
		"id": func(x: Game) -> void: x.musters[0].id = 1,
		"tag": func(x: Game) -> void: x.musters[0].tag = &"GEN",
		"hex column": func(x: Game) -> void: x.musters[0].hex = TURIN + Vector2i(1, 0),
		"hex row": func(x: Game) -> void: x.musters[0].hex = TURIN + Vector2i(0, 1),
		"kind": func(x: Game) -> void: x.musters[0].kind = CROSSBOW,
		"queued_turn": func(x: Game) -> void: x.musters[0].queued_turn = 1,
		"seasons_left": func(x: Game) -> void: x.musters[0].seasons_left = 0,
		"paid": func(x: Game) -> void: x.musters[0].paid = 26,
		"goods loads": func(x: Game) -> void: x.musters[0].paid_goods["iron"] = 2,
		"goods key": func(x: Game) -> void: x.musters[0].paid_goods = {"copper": 1},
		"goods gone": func(x: Game) -> void: x.musters[0].paid_goods = {},
		"levy hex": func(x: Game) -> void: x.musters[0].levy[1][0] = other,
		"levy men": func(x: Game) -> void: x.musters[0].levy[1][1] = 201,
		"levy order": func(x: Game) -> void: x.musters[0].levy.assign([x.musters[0].levy[1], x.musters[0].levy[0]]),
		"levy source gone": func(x: Game) -> void: x.musters[0].levy.assign([[beside, 200]]),
		"entry gone": func(x: Game) -> void: x.musters.remove_at(2),
		"all gone": func(x: Game) -> void: x.musters.clear(),
		"next id": func(x: Game) -> void: x.next_muster_id = 8,
	}
	var digests := {g.digest(): "unchanged"}
	var same: Array[String] = []
	for label: String in changes:
		var x := _restore(g, _body(g))["game"] as Game
		(changes[label] as Callable).call(x)
		var digest := x.digest()
		if digests.has(digest):
			same.append("%s as %s" % [label, digests[digest]])
		digests[digest] = label
	assert_eq(same, [] as Array[String], "changes the digest does not see")
	assert_eq(digests.size(), changes.size() + 1)


func test_an_entry_has_these_fields_and_no_other() -> void:
	# A new field must be saved, digested and checked: add it to the tests above and the faults below.
	var names: Array[String] = []
	for p: Dictionary in Muster.new().get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(str(p["name"]))
	assert_eq(names, ["id", "tag", "hex", "kind", "queued_turn", "seasons_left", "paid", "paid_goods", "levy"] as Array[String])


# ----- a game with no entries -----------------------------------------------------------------------------------------


func test_a_game_with_no_entries_saves_loads_and_plays_on() -> void:
	var g := EconomyFixture.game(&"GEN")
	var empty := {"schema": "hexa-godot/musters/1", "next_muster_id": 1, "list": []}
	assert_eq(Snapshot.of(g)["musters"], empty)
	Season.run(g)
	assert_eq(Snapshot.of(g)["musters"], empty, "a season queues nothing")
	var got := _through_a_file(g)
	var back := got[0] as Game
	assert_not_null(back)
	assert_true(bool(got[2]), "byte-equal files")
	assert_eq(back.digest(), g.digest())
	Season.run(g)
	Season.run(back)
	assert_eq(back.digest(), g.digest(), "play on")


func test_a_sandbox_keeps_an_empty_queue_and_refuses_an_entry() -> void:
	var played := _planted()
	var g := Game.new_game(played.map, 7, played.defs)
	var r := _restore(g, _body(g))
	assert_eq(r["problem"], "")
	assert_eq((r["game"] as Game).digest(), g.digest())
	var body := _body(g)
	body["musters"] = _body(played)["musters"]
	assert_eq(_restore(g, body)["problem"], Snapshot.PROBLEM_UNREADABLE, "no country to queue it")


func test_replay_of_a_played_game_stays_equal() -> void:
	var g := EconomyFixture.game(&"GEN")
	assert_true(bool(g.act("raise", {"hex": GENOA, "kind": PIKE, "count": 1, "tag": &"GEN"})["ok"]))
	Season.run(g)
	assert_true(g.dev_money(&"GEN", 500))
	Season.run(g)
	var again := Replay.run(g.map, g.defs, g.scenario.id, g.seed_value, g.action_log)
	assert_not_null(again)
	assert_eq(again.digest(), g.digest())
	assert_eq([_fields(again), again.next_muster_id], [_fields(g), g.next_muster_id])


# ----- damaged bodies -------------------------------------------------------------------------------------------------


## The bodies made by `cases` (label -> a change of the planted game's body) that load or give other words than "Cannot be
## read", and the game in hand left as it was.
func _assert_all_refused(g: Game, cases: Dictionary) -> void:
	var live := g.digest()
	var bytes := var_to_bytes(Snapshot.of(g))
	assert_eq(_restore(g, bytes_to_var(bytes) as Dictionary)["problem"], "", "the sound body loads")
	var wrong: Array[String] = []
	for label: String in cases:
		var body := bytes_to_var(bytes) as Dictionary
		(cases[label] as Callable).call(body)
		var r := _restore(g, body)
		if r["game"] != null or r["problem"] != Snapshot.PROBLEM_UNREADABLE:
			wrong.append("%s: '%s'" % [label, r["problem"]])
	assert_eq(wrong, [] as Array[String], "damaged queues that are not refused")
	assert_eq(g.digest(), live)


func _queue(body: Dictionary) -> Dictionary:
	return body["musters"] as Dictionary


func _list(body: Dictionary) -> Array:
	return _queue(body)["list"] as Array


## A change that sets keys of the `n`th saved entry.
func _with(n: int, values: Dictionary) -> Callable:
	return func(body: Dictionary) -> void:
		(_list(body)[n] as Dictionary).merge(values, true)


## A change that drops a key of the first saved entry.
func _without(key: String) -> Callable:
	return func(body: Dictionary) -> void:
		(_list(body)[0] as Dictionary).erase(key)


func test_p_a_damaged_queue_is_refused() -> void:
	_assert_all_refused(_planted(), {
		"no musters": func(b: Dictionary) -> void: b.erase("musters"),
		"musters a number": func(b: Dictionary) -> void: b["musters"] = 3,
		"another schema": func(b: Dictionary) -> void: _queue(b)["schema"] = "hexa-godot/musters/2",
		"no next id": func(b: Dictionary) -> void: _queue(b).erase("next_muster_id"),
		"next id text": func(b: Dictionary) -> void: _queue(b)["next_muster_id"] = "7",
		"next id a fraction": func(b: Dictionary) -> void: _queue(b)["next_muster_id"] = 7.5,
		"next id past int32": func(b: Dictionary) -> void: _queue(b)["next_muster_id"] = 1 << 40,
		"next id 0 with no entry": func(b: Dictionary) -> void:
			_queue(b)["next_muster_id"] = 0
			_queue(b)["list"] = [],
		"no list": func(b: Dictionary) -> void: _queue(b).erase("list"),
		"list a number": func(b: Dictionary) -> void: _queue(b)["list"] = 3,
		"an entry a number": func(b: Dictionary) -> void: _list(b).append(3),
		"another entry schema": _with(0, {"schema": "hexa-godot/muster/2"}),
		"id 0": _with(0, {"id": 0}),
		"id twice": _with(1, {"id": 2}),
		"ids out of order": func(b: Dictionary) -> void: _list(b).reverse(),
		"id at the next id": _with(2, {"id": 7}),
	})


func test_p_a_damaged_field_of_an_entry_is_refused() -> void:
	var g := _planted()
	var cases := {}
	for key: String in ["id", "tag", "hex", "kind", "queued_turn", "seasons_left", "paid", "paid_goods", "levy"]:
		cases["no " + key] = _without(key)
	for key: String in ["id", "kind", "queued_turn", "seasons_left", "paid"]:
		cases[key + " text"] = _with(0, {key: "1"})
		cases[key + " a fraction"] = _with(0, {key: 1.5})
	cases.merge({
		"tag a number": _with(0, {"tag": 3}),
		# A node path reads as the same word: only its type is wrong.
		"tag a node path": _with(0, {"tag": NodePath("SAV")}),
		"good a node path": _with(0, {"paid_goods": {NodePath("iron"): 1}}),
		"tag of no country": _with(0, {"tag": "XXX"}),
		"hex of one number": _with(0, {"hex": [5]}),
		"hex of text": _with(0, {"hex": ["5", "9"]}),
		# The levy of these two is sound (a source beside the hex, the full men): only the hex is wrong.
		"hex off the map": _with(0, {"hex": [NORTH_OF_BERN.x, NORTH_OF_BERN.y],
			"levy": [[[BERN.x, BERN.y], _men(g, PIKE)]]}),
		"hex at sea": _with(2, {"hex": _pair(_beside(g, GENOA, false))}),
		"kind unknown": _with(0, {"kind": 99}),
		"queued before the first season": _with(0, {"queued_turn": 0}),
		"queued after this season": _with(0, {"queued_turn": g.turn + 1}),
		"seasons_left below 0": _with(0, {"seasons_left": -1}),
		"seasons_left past its bound": _with(0, {"seasons_left": Muster.SEASONS_MAX + 1}),
		"paid below 0": _with(0, {"paid": -1}),
		"paid past its bound": _with(0, {"paid": Muster.PAID_MAX + 1}),
		"goods a list": _with(0, {"paid_goods": [1]}),
		"good a number": _with(0, {"paid_goods": {5: 1}}),
		"good unknown": _with(0, {"paid_goods": {"gold": 1}}),
		"loads text": _with(0, {"paid_goods": {"iron": "1"}}),
		"loads a fraction": _with(0, {"paid_goods": {"iron": 1.5}}),
		"loads below 0": _with(0, {"paid_goods": {"iron": -1}}),
		"loads past their bound": _with(0, {"paid_goods": {"iron": Muster.PAID_MAX + 1}}),
	})
	_assert_all_refused(g, cases)


func _pair(hex: Vector2i) -> Array:
	return [hex.x, hex.y]


func test_p_a_damaged_levy_is_refused() -> void:
	var g := _planted()
	var men := _men(g, PIKE)
	var here := _pair(TURIN)
	var near := _pair(_beside(g, TURIN, true))
	var levies := {
		"a number": 3,
		"empty": [],
		"a source a number": [3],
		"a source of one": [[here]],
		"a source of three": [[here, men, 1]],
		"a source hex of one number": [[[5], men]],
		"men text": [[here, str(men)]],
		"men a fraction": [[here, float(men) + 0.5]],
		# The sum is right in the next two: only the source's own men are wrong.
		"no man from a source": [[here, men], [near, 0]],
		"men below 0": [[here, men + 100], [near, -100]],
		"a source beyond the ring": [[_pair(GENOA), men]],
		"a source twice": [[here, men - 200], [here, 200]],
		"a man short": [[here, men - 1]],
		"a man over": [[here, men], [near, 1]],
	}
	var cases := {}
	for label: String in levies:
		cases[label] = _with(0, {"levy": levies[label]})
	# A source beside the hex that is no land: the sea beside Genoa, and the row above Bern, off the map.
	cases["a source at sea"] = _with(2, {"levy": [[_pair(_beside(g, GENOA, false)), _men(g, KNIGHTS)]]})
	cases["a source off the map"] = _with(0, {"tag": "SWI", "hex": _pair(BERN), "levy": [[_pair(NORTH_OF_BERN), men]]})
	_assert_all_refused(g, cases)


func test_p_a_refused_queue_changes_nothing() -> void:
	var g := _planted()
	var before := g.digest()
	var saved := Recruiting.to_dict(g)
	((saved["list"] as Array)[2] as Dictionary)["kind"] = 99  # the first two entries are sound
	saved["next_muster_id"] = 50
	assert_eq(Recruiting.from_dict(saved, g), Recruiting.PROBLEM_BODY)
	assert_eq([g.musters.size(), g.next_muster_id], [3, 7])
	assert_eq(g.digest(), before)
