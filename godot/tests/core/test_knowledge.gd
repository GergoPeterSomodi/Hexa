## Knowledge view tests (docs/architecture/m3-build-spec.md sections 4.7, 5.6 and 9): knows (self, neighbour, far, ""),
## known in id order, unknown_count, band, band_text, witnessed (party, others, listed, public and known, public and
## unknown, "" sees all). Cases marked P are the planted-fault checks of section 9.
@warning_ignore_start("integer_division")
extends GutTest

const AAA := &"AAA"
const BBB := &"BBB"
const OUT := &"OUT"


## The 9x7 fixture with its owners replaced: `owners` maps a hex to a country id (0 is unowned).
func _game_with(owners: Dictionary) -> Game:
	var g := ScenarioFixture.game()
	g.state.owner.fill(0)
	for hex: Vector2i in owners:
		g.state.owner[g.map.index_of(hex)] = int(owners[hex])
	# The owners changed after the game started: explored is made again as a new game makes it (Sight.setup, M6 4.11).
	Sight.setup(g)
	return g


## AAA (id 1) and BBB (id 2) share a border; OUT (id 3) is far from both.
func _border_game() -> Game:
	return _game_with({Vector2i(0, 0): 1, Vector2i(1, 0): 2, Vector2i(8, 0): 3})


## AAA sits between BBB and OUT on one row: it knows both; the hex order is the reverse of the id order.
func _between_game() -> Game:
	return _game_with({Vector2i(3, 2): 3, Vector2i(4, 2): 1, Vector2i(5, 2): 2})


func test_knows_self_neighbour_far_and_empty() -> void:
	var g := _border_game()
	assert_true(Knowledge.knows(g, AAA, AAA))
	assert_true(Knowledge.knows(g, AAA, BBB), "a neighbour is known")
	assert_true(Knowledge.knows(g, BBB, AAA), "the border is shared")
	assert_false(Knowledge.knows(g, AAA, OUT), "a far country is not known")
	assert_false(Knowledge.knows(g, OUT, AAA))
	assert_false(Knowledge.knows(g, OUT, BBB), "P: a far viewer does not know a far actor")
	assert_true(Knowledge.knows(g, &"", OUT), "the viewer \"\" sees all")
	assert_true(Knowledge.knows(g, AAA, &""), "the other \"\" is public")
	assert_true(Knowledge.knows(g, &"", &""))
	assert_false(Knowledge.knows(g, &"ZZZ", AAA), "a tag with no country knows nothing")


func test_known_in_id_order_viewer_excluded() -> void:
	var between := _between_game()
	assert_eq(Knowledge.known(between, AAA), [BBB, OUT], "id order, not hex order")
	assert_eq(Knowledge.known(between, BBB), [AAA], "BBB borders AAA only")
	assert_eq(Knowledge.known(between, OUT), [AAA])

	var border := _border_game()
	assert_eq(Knowledge.known(border, AAA), [BBB])
	assert_eq(Knowledge.known(border, OUT), [])
	assert_eq(Knowledge.known(border, &""), [AAA, BBB, OUT], "the viewer \"\" knows every country in id order")
	assert_eq(Knowledge.known(border, &"ZZZ"), [])


func test_unknown_count() -> void:
	var border := _border_game()
	assert_eq(Knowledge.unknown_count(border, AAA), 1, "OUT is unknown to AAA")
	assert_eq(Knowledge.unknown_count(border, OUT), 2, "OUT knows neither")
	assert_eq(Knowledge.unknown_count(border, &""), 0)
	assert_eq(Knowledge.unknown_count(_between_game(), AAA), 0)
	assert_eq(Knowledge.unknown_count(Game.new_game(ScenarioFixture.build()["map"] as MapData, 1), AAA), 0,
		"a map-only game has no countries")


func test_band_two_significant_figures() -> void:
	assert_eq(Knowledge.band(87), 87)
	assert_eq(Knowledge.band(1234), 1200)
	assert_eq(Knowledge.band(1250), 1300, "half rounds away from zero")
	assert_eq(Knowledge.band(-1234), -1200)
	assert_eq(Knowledge.band(-1250), -1300)
	assert_eq(Knowledge.band(0), 0)
	assert_eq(Knowledge.band(99960), 100000)
	assert_eq(Knowledge.band(-5), -5)


func test_band_text() -> void:
	assert_eq(Knowledge.band_text(1234, "ducats"), "about 1,200 ducats")
	assert_eq(Knowledge.band_text(87, ""), "about 87")
	assert_eq(Knowledge.band_text(99960, "ducats"), "about 100,000 ducats")
	assert_eq(Knowledge.band_text(1250, ""), "about 1,300")
	assert_eq(Knowledge.band_text(-1234, "ducats"), "about " + Knowledge.MINUS + "1,200 ducats")
	assert_eq(Knowledge.band_text(0, ""), "about 0")


func test_witnessed_party_and_others() -> void:
	var g := _border_game()
	# The actor always sees its own event, even when the world does not know it (OUT is far from AAA and BBB).
	assert_true(Knowledge.witnessed(g, {"tag": OUT}, OUT), "party: the actor sees it")
	assert_true(Knowledge.witnessed(g, {"tag": OUT, "witnesses": [BBB]}, OUT), "party with a witness list")
	# A listed other sees it: OUT is in `others` and does not know AAA.
	assert_true(Knowledge.witnessed(g, {"tag": AAA, "others": [OUT]}, OUT), "others: a listed other sees it")
	assert_true(Knowledge.witnessed(g, {"tag": AAA, "others": [OUT]}, AAA), "others: the actor sees it")


func test_witnessed_listed() -> void:
	var g := _border_game()
	assert_true(Knowledge.witnessed(g, {"tag": AAA, "witnesses": [OUT]}, OUT), "listed: a far witness sees it")
	# P: a non-empty witness list tells exactly the tags it holds, even a neighbour that knows the actor.
	assert_false(Knowledge.witnessed(g, {"tag": AAA, "witnesses": [OUT]}, BBB), "P: a neighbour not listed does not see it")


func test_witnessed_public() -> void:
	var g := _border_game()
	assert_true(Knowledge.witnessed(g, {"tag": AAA}, BBB), "public and known: a neighbour sees it")
	assert_true(Knowledge.witnessed(g, {"tag": "AAA"}, BBB), "a String tag is read the same")
	assert_false(Knowledge.witnessed(g, {"tag": AAA}, OUT), "P: public and unknown is false")
	assert_false(Knowledge.witnessed(g, {"tag": AAA, "witnesses": []}, OUT), "P: an empty witness list is public")
	assert_false(Knowledge.witnessed(g, {"tag": AAA, "others": []}, OUT), "P: empty others do not tell a far viewer")


func test_witnessed_empty_viewer_sees_all() -> void:
	var g := _border_game()
	assert_true(Knowledge.witnessed(g, {"tag": AAA}, &""))
	assert_true(Knowledge.witnessed(g, {"tag": OUT, "witnesses": [BBB]}, &""), "the viewer \"\" sees all")
	assert_true(Knowledge.witnessed(g, {}, &""))


func test_witnessed_reads_the_chronicle_packed_lists() -> void:
	# The Chronicle stores tag lists as PackedStringArray: LogLines and SeasonSummary hand those entries in.
	var g := _border_game()
	var packed := {"tag": AAA, "others": PackedStringArray([String(OUT)])}
	assert_true(Knowledge.witnessed(g, packed, OUT), "a packed others list tells the loser")
	var listed := {"tag": AAA, "witnesses": PackedStringArray([String(OUT)])}
	assert_true(Knowledge.witnessed(g, listed, OUT), "a packed witness list tells a listed far viewer")
	assert_false(Knowledge.witnessed(g, listed, BBB), "and not a neighbour it does not list")


## M7 (4.15): what a viewer may see of a battle record and of a siege. A witness sees a battle seen; a side sees it exact;
## an unwitnessed battle is hidden (P). A siege between countries at peace is hidden for everyone (P).
func test_battle_access_by_side_and_witness() -> void:
	var g := ArmyFixture.game()
	var r := BattleRecord.new()
	r.attacker = &"SAV"
	r.defender = &"MLO"
	r.witnesses = PackedStringArray(["GEN"])
	assert_eq(Knowledge.battle_access(g, &"", r), &"exact")
	assert_eq(Knowledge.battle_access(g, &"SAV", r), &"exact")
	assert_eq(Knowledge.battle_access(g, &"GEN", r), &"seen", "a witness")
	assert_eq(Knowledge.battle_access(g, &"FRA", r), &"hidden", "P: an unwitnessed battle is hidden")
	assert_eq(Knowledge.battle_access(g, &"GEN", null), &"hidden")


func test_siege_access_hides_a_siege_at_peace() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	var holder := Occupation.controller_tag(g, hex)
	var s := Siege.new()
	s.hex = hex
	s.besieger = &"FRA"
	s.name = "Siege of Test, 1480"
	g.sieges.append(s)
	assert_eq(Knowledge.siege_access(g, &"", hex), &"hidden", "P: no war, no siege")
	WarFixture.at_war(g, &"FRA", holder)
	assert_eq(Knowledge.siege_access(g, &"", hex), &"exact", "at war, the viewer \"\" sees it exact")
	assert_eq(Knowledge.siege_access(g, &"FRA", hex), &"exact", "the besieger")


# --- M8 K13: men_of and garrison_estimate (D49) ----------------------------------------------------------------------------


## A hostile fortress (held by a country at war with Genoa), garrisoned, on the north Italy game: {g, hex, holder}.
func _fortress_game(watched: bool) -> Dictionary:
	var g := ArmyFixture.game()
	var enemy := WarFixture.neighbour_of(g, ArmyFixture.TAG)
	WarFixture.at_war(g, enemy, ArmyFixture.TAG)
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Occupation.fortress_level(g, hex) <= 0 or Occupation.controller_tag(g, hex) != enemy or Occupation.garrison_of(g, hex) <= 0:
			continue
		if watched:
			var mine := ArmyFixture.id_of(g, ArmyFixture.TAG)
			var at := hex
			for d: int in 6:
				var beside := ImproveRules.neighbour(hex, d)
				if g.map.is_land(beside) and Territory.owner_id(g, beside) == mine:
					at = beside
					break
			ArmyFixture.army(g, ArmyFixture.TAG, at, 0, 2)
			Sight.refresh(g)
			if Knowledge.sees(g, ArmyFixture.TAG, hex):
				return {"g": g, "hex": hex, "holder": enemy}
		elif not Knowledge.sees(g, ArmyFixture.TAG, hex):
			return {"g": g, "hex": hex, "holder": enemy}
	return {}


func test_garrison_estimate_own_is_exact() -> void:
	var f := _fortress_game(false)
	assert_false(f.is_empty(), "a hostile garrisoned fortress exists")
	var g: Game = f.g
	Occupation.set_garrison(g, f.hex, Occupation.garrison_full(g, f.hex) - 13)
	var whole := Occupation.garrison_of(g, f.hex)
	var own := Knowledge.garrison_estimate(g, f.holder, f.hex)
	assert_eq(int(own.men), whole, "the holder reads its own garrison exact")
	assert_eq(own.access, &"exact")
	var open := Knowledge.garrison_estimate(g, &"", f.hex)
	assert_eq(int(open.men), whole, "the viewer \"\" reads it exact")
	assert_eq(open.access, &"exact")


func test_garrison_estimate_seen_is_rounded_to_a_hundred() -> void:
	var f := _fortress_game(true)
	assert_false(f.is_empty(), "a hostile fortress the player sees exists")
	var g: Game = f.g
	Occupation.set_garrison(g, f.hex, Occupation.garrison_full(g, f.hex) - 13)
	var whole := Occupation.garrison_of(g, f.hex)
	assert_ne(whole % 100, 0, "the planted garrison is not a round hundred")
	var seen := Knowledge.garrison_estimate(g, ArmyFixture.TAG, f.hex)
	assert_eq(seen.access, &"seen")
	assert_eq(int(seen.men), ((whole + 50) / 100) * 100, "rounded to 100")
	assert_ne(int(seen.men), whole, "P: a seen garrison is never exact")


func test_garrison_estimate_unseen_is_the_full_garrison_whatever_the_real_one() -> void:
	var f := _fortress_game(false)
	assert_false(f.is_empty(), "a hostile fortress the player does not see exists")
	var g: Game = f.g
	var full := Occupation.garrison_full(g, f.hex)
	var before := Knowledge.garrison_estimate(g, ArmyFixture.TAG, f.hex)
	assert_eq(before.access, &"assumed")
	assert_eq(int(before.men), full, "the full garrison of its level")
	Occupation.set_garrison(g, f.hex, maxi(1, full / 4))
	var after := Knowledge.garrison_estimate(g, ArmyFixture.TAG, f.hex)
	assert_eq(after, before, "P: a reduced unseen garrison does not change the estimate")


func test_garrison_estimate_none_for_no_fortress_and_an_occupied_one() -> void:
	var f := _fortress_game(false)
	var g: Game = f.g
	var plain := Vector2i(-1, -1)
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and Occupation.fortress_level(g, hex) == 0:
			plain = hex
			break
	var none := Knowledge.garrison_estimate(g, ArmyFixture.TAG, plain)
	assert_eq(int(none.men), 0)
	assert_eq(none.access, &"none")
	WarFixture.set_occupier(g, f.hex, ArmyFixture.TAG)
	if Occupation.is_occupied(g, f.hex):
		assert_eq(Knowledge.garrison_estimate(g, ArmyFixture.TAG, f.hex).access, &"none", "an occupied fortress holds no garrison")


func test_men_of_exact_banded_and_unknown() -> void:
	var g := ArmyFixture.game()
	var enemy := WarFixture.neighbour_of(g, ArmyFixture.TAG)
	var stranger := WarFixture.stranger_of(g, ArmyFixture.TAG)
	var col := Stats.column("army_men")
	var ids := {ArmyFixture.TAG: 1234, enemy: 1250, stranger: 777}
	for tag: StringName in ids:
		var row := PackedInt32Array()
		row.resize(Stats.SERIES.size())
		row[col] = int(ids[tag])
		g.stats.set_row(g.stats.index_of(tag), 1, row)
	g.stats.commit(1)
	assert_eq(Knowledge.men_of(g, ArmyFixture.TAG, ArmyFixture.TAG), 1234, "its own men exact")
	assert_eq(Knowledge.men_of(g, &"", enemy), 1250, "the viewer \"\" reads exact")
	assert_true(Knowledge.knows(g, ArmyFixture.TAG, enemy), "a neighbour is known")
	assert_eq(Knowledge.men_of(g, ArmyFixture.TAG, enemy), 1300, "a known country is banded to two figures")
	assert_ne(Knowledge.men_of(g, ArmyFixture.TAG, enemy), 1250, "P: a known country is never exact")
	if not Knowledge.knows(g, ArmyFixture.TAG, stranger):
		assert_eq(Knowledge.men_of(g, ArmyFixture.TAG, stranger), -1, "an unknown country is -1")
	assert_eq(Knowledge.men_of(g, ArmyFixture.TAG, &"ZZZ"), -1, "a tag with no country is -1")
