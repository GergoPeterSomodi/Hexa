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
	# The fog test world: each country has explored only its own hexes, so a far country is unknown. The 9x7 fixture is too small
	# for a land sight of radius 2 to leave one out (FogFixture.thin would reach every hex here). The real north Italy start is
	# the other way round (see test_north_italy_every_country_knows_every_other).
	for c: Country in g.countries:
		if c != null and c.tag != &"":
			c.explored = _own_bits(g, c.id)
	g.sight.clear()
	Sight.refresh(g)
	g.version += 1
	return g


## The explored bits of the hexes `id` owns (a test's world state, as WarFixture writes its own).
func _own_bits(g: Game, id: int) -> PackedByteArray:
	var bits := PackedByteArray()
	bits.resize((g.map.hex_count() + 7) >> 3)
	bits.fill(0)
	for i: int in g.map.hex_count():
		if int(g.state.owner[i]) == id:
			bits[i >> 3] = bits[i >> 3] | (1 << (i & 7))
	return bits


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


# --- FG5: discovered, land_seen, garrison_known, men_of exact, siege_access land, the land witness rule (R1, R19, R21, R24 to
# R26, R29). Discovery is made by the real writers: Sight.see_path (a walk) and the army part (Sight.refresh).


## The ArmyFixture world thinned (FG3): each country explores only its land sight, so undiscovered hexes exist.
func _fog_game() -> Game:
	var g := ArmyFixture.game()
	_thin_all(g)
	return g


## Every country of `g` thin at radius 0: its explored set is its land sight.
func _thin_all(g: Game) -> void:
	for c: Country in g.countries:
		if c != null and c.tag != &"":
			FogFixture.thin(g, c.tag, 0)


## A land hex next to `hex` (NO_HEX when none).
func _land_beside(g: Game, hex: Vector2i) -> Vector2i:
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if g.map.is_land(beside):
			return beside
	return Army.NO_HEX


## The first land hex of the map for which `want` is true (NO_HEX when none).
func _first_hex(g: Game, want: Callable) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and bool(want.call(hex)):
			return hex
	return Army.NO_HEX


## The first unoccupied fortress whose discovery by `tag` is `discovered_now` (NO_HEX when none).
func _fortress(g: Game, tag: StringName, discovered_now: bool) -> Vector2i:
	return _first_hex(g, func(h: Vector2i) -> bool:
		return Occupation.fortress_level(g, h) > 0 and not Occupation.is_occupied(g, h) and Knowledge.discovered(g, tag, h) == discovered_now)


## The tags of the countries of `g` (id order) that are not in `skip`.
func _others(g: Game, skip: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Country in g.countries:
		if c != null and c.tag != &"" and not skip.has(c.tag):
			out.append(c.tag)
	return out


## A walk of `tag` over `hex` alone (Sight.see_path, the real writer of explored); the version moves on as a walk does.
func _walk(g: Game, tag: StringName, hex: Vector2i) -> void:
	var path: Array[Vector2i] = [hex]
	Sight.see_path(g, tag, path, 0)
	g.version += 1


func test_discovered_three_states() -> void:
	var g := _fog_game()
	var tag := ArmyFixture.TAG
	var hex := _first_hex(g, func(h: Vector2i) -> bool:
		return not Knowledge.discovered(g, tag, h) and _land_beside(g, h) != Army.NO_HEX)
	assert_ne(hex, Army.NO_HEX, "an undiscovered land hex exists")
	assert_false(Knowledge.discovered(g, tag, hex), "state 1, undiscovered: nothing of it is known")
	assert_false(Knowledge.sees(g, tag, hex))
	_walk(g, tag, hex)
	assert_true(Knowledge.discovered(g, tag, hex), "state 2, discovered: the walk explored it")
	assert_false(Knowledge.sees(g, tag, hex), "state 2, not in sight")
	ArmyFixture.army(g, tag, _land_beside(g, hex), 0, 2)
	Sight.refresh(g)
	assert_true(Knowledge.sees(g, tag, hex), "state 3, in sight: an army stands beside it")
	assert_true(Knowledge.discovered(g, tag, hex))
	assert_true(Knowledge.discovered(g, &"", hex), "the viewer \"\" discovers every hex")


func test_discovered_counts_an_army_ring_before_the_explored_bit() -> void:
	var g := _fog_game()
	var tag := ArmyFixture.TAG
	var hex := _first_hex(g, func(h: Vector2i) -> bool:
		return not Knowledge.discovered(g, tag, h) and _land_beside(g, h) != Army.NO_HEX)
	assert_ne(hex, Army.NO_HEX, "an undiscovered land hex exists")
	ArmyFixture.army(g, tag, _land_beside(g, hex), 0, 2)
	Sight.refresh(g)
	assert_false(Sight.explored(g, tag, hex), "no walk and no season: the explored bit is not written")
	assert_true(Knowledge.sees(g, tag, hex))
	assert_true(Knowledge.discovered(g, tag, hex), "P: an army's new ring is discovered before the vision phase")


func test_land_seen_whole_and_partial() -> void:
	var g := _fog_game()
	var tag := ArmyFixture.TAG
	var other := WarFixture.neighbour_of(g, tag)
	assert_ne(other, &"", "a neighbour exists")
	var c := Countries.by_tag(g, other)
	var whole := Knowledge.land_seen(g, &"", other)
	assert_eq(int(whole["districts"]), Territory.districts(g, c.id).size(), "the viewer \"\" sees every district")
	assert_eq(int(whole["people"]), int(PeopleView.totals(g, other)["people"]), "and every person of them")
	var expect_d := 0
	var expect_p := 0
	for i: int in Territory.districts(g, c.id):
		if Knowledge.discovered(g, tag, g.map.hex_of(i)):
			expect_d += 1
			expect_p += int(g.state.people[i])
	var part := Knowledge.land_seen(g, tag, other)
	assert_eq(int(part["districts"]), expect_d, "partial: only the districts the viewer has discovered")
	assert_eq(int(part["people"]), expect_p, "P: no undiscovered district is counted")
	assert_lte(int(part["districts"]), int(whole["districts"]))
	var hidden := _first_hex(g, func(h: Vector2i) -> bool:
		return int(g.state.owner[g.map.index_of(h)]) == c.id and not Knowledge.discovered(g, tag, h))
	assert_ne(hidden, Army.NO_HEX, "an undiscovered district of the other country exists")
	_walk(g, tag, hidden)
	var after := Knowledge.land_seen(g, tag, other)
	assert_eq(int(after["districts"]), int(part["districts"]) + 1, "a walk into a district counts it at once (the cache follows the version)")


func test_garrison_known_is_exact_on_a_discovered_fortress() -> void:
	var g := _fog_game()
	var tag := ArmyFixture.TAG
	var hex := _fortress(g, tag, false)
	assert_ne(hex, Army.NO_HEX, "an undiscovered fortress exists")
	_walk(g, tag, hex)
	assert_false(Knowledge.sees(g, tag, hex), "discovered, not in sight")
	Occupation.set_garrison(g, hex, Occupation.garrison_full(g, hex) - 13)
	g.version += 1
	var whole := Occupation.garrison_of(g, hex)
	assert_ne(whole % 100, 0, "the planted garrison is not a round hundred")
	var known := Knowledge.garrison_known(g, tag, hex)
	assert_eq(int(known["men"]), whole, "P: a discovered fortress reads its real garrison, never a rounded one")
	assert_eq(known["access"], &"exact")
	assert_eq(Knowledge.garrison_known(g, &"", hex), known, "the viewer \"\" reads the same")


func test_garrison_known_is_hidden_on_an_undiscovered_fortress() -> void:
	var g := _fog_game()
	var tag := ArmyFixture.TAG
	var hex := _fortress(g, tag, false)
	assert_ne(hex, Army.NO_HEX, "an undiscovered fortress exists")
	var full := Occupation.garrison_full(g, hex)
	Occupation.set_garrison(g, hex, maxi(1, full / 4))
	g.version += 1
	var hidden := Knowledge.garrison_known(g, tag, hex)
	assert_eq(hidden["access"], &"hidden")
	assert_eq(int(hidden["men"]), -1, "nothing of its garrison is read")
	assert_ne(int(hidden["men"]), full, "P: an undiscovered fortress never reports its full garrison")
	Occupation.set_garrison(g, hex, full)
	g.version += 1
	assert_eq(Knowledge.garrison_known(g, tag, hex), hidden, "P: the real garrison of an undiscovered fortress is never read")


func test_garrison_known_is_none_without_a_fortress() -> void:
	var g := _fog_game()
	var plain := _first_hex(g, func(h: Vector2i) -> bool:
		return Occupation.fortress_level(g, h) == 0)
	assert_ne(plain, Army.NO_HEX, "a land hex with no fortress exists")
	var none := Knowledge.garrison_known(g, ArmyFixture.TAG, plain)
	assert_eq(int(none["men"]), 0)
	assert_eq(none["access"], &"none")
	assert_eq(Knowledge.garrison_known(g, &"", plain)["access"], &"none")


func test_garrison_known_is_exact_for_a_fortress_occupied_by_a_third() -> void:
	var g := _fog_game()
	var tag := ArmyFixture.TAG
	var hex := _fortress(g, tag, false)
	assert_ne(hex, Army.NO_HEX, "an undiscovered fortress exists")
	var third := WarFixture.stranger_of(g, tag)
	assert_ne(third, &"", "a country that is no neighbour exists")
	WarFixture.set_occupier(g, hex, third)
	_walk(g, tag, hex)
	assert_true(Occupation.is_occupied(g, hex), "the fortress is occupied")
	var known := Knowledge.garrison_known(g, tag, hex)
	assert_eq(known["access"], &"exact", "an occupied fortress is exact on a discovered hex (R19)")
	assert_eq(int(known["men"]), Occupation.garrison_of(g, hex))


func test_men_of_is_exact_for_a_known_country() -> void:
	var g := _fog_game()
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
	assert_eq(Knowledge.men_of(g, ArmyFixture.TAG, enemy), 1250, "P: a known country is exact, not banded to 1,300")
	if not Knowledge.knows(g, ArmyFixture.TAG, stranger):
		assert_eq(Knowledge.men_of(g, ArmyFixture.TAG, stranger), -1, "an unknown country is -1")
	assert_eq(Knowledge.men_of(g, ArmyFixture.TAG, &"ZZZ"), -1, "a tag with no country is -1")


func test_siege_access_four_levels() -> void:
	var g := _fog_game()
	var tag := ArmyFixture.TAG
	var hex := ArmyFixture.find_town(g)
	assert_ne(hex, Army.NO_HEX, "a town of TAG exists")
	var holder := Occupation.controller_tag(g, hex)
	var besieger := WarFixture.neighbour_of(g, holder)
	assert_ne(besieger, &"", "a neighbour of the holder exists")
	WarFixture.at_war(g, besieger, holder)
	var s := Siege.new()
	s.hex = hex
	s.besieger = besieger
	s.name = "Siege of Test, 1480"
	g.sieges.append(s)
	var skip: Array[StringName] = [besieger, holder]
	var others := _others(g, skip)
	assert_gte(others.size(), 3, "three other countries exist")
	var seer := others[0]
	var distant := others[1]
	var blind := others[2]
	assert_eq(Knowledge.siege_access(g, &"", hex), &"exact", "the viewer \"\" sees it exact")
	assert_eq(Knowledge.siege_access(g, besieger, hex), &"exact", "the besieger")
	assert_eq(Knowledge.siege_access(g, holder, hex), &"exact", "the holder")
	ArmyFixture.army(g, seer, _land_beside(g, hex), 0, 2)
	Sight.refresh(g)
	_walk(g, distant, hex)
	assert_true(Knowledge.sees(g, seer, hex), "precondition: an army of the seer sees the hex")
	assert_false(Knowledge.sees(g, distant, hex), "precondition: distant does not see the hex")
	assert_true(Knowledge.discovered(g, distant, hex), "precondition: distant has discovered it")
	assert_false(Knowledge.discovered(g, blind, hex), "precondition: blind has not discovered it")
	assert_eq(Knowledge.siege_access(g, seer, hex), &"seen", "in sight: the siege is seen")
	assert_eq(Knowledge.siege_access(g, distant, hex), &"land", "P: discovered, not in sight, is land, never seen")
	assert_eq(Knowledge.siege_access(g, blind, hex), &"hidden", "undiscovered: hidden")


func test_witnessed_land_event_follows_discovery() -> void:
	var g := _border_game()
	var far := Vector2i(8, 0)
	assert_true(Knowledge.witnessed(g, {"tag": AAA, "land": true, "hex": far}, OUT), "a viewer that discovered the hex is told (D12)")
	assert_false(Knowledge.witnessed(g, {"tag": AAA, "land": true, "hex": far, "witnesses": [BBB]}, BBB),
		"P: a land event on an undiscovered hex is not told to a listed witness that has not discovered it")
	assert_true(Knowledge.witnessed(g, {"tag": AAA, "land": true, "hex": far, "witnesses": [BBB]}, OUT),
		"P: a discovering viewer the witness list leaves out is told")
	assert_false(Knowledge.witnessed(g, {"tag": AAA, "land": true}, OUT), "a land event with no hex is not told to a far viewer")


## The real north Italy start (FG1): one region, `europe`, over every hex, so every country has discovered the whole map and knows
## every other country. A fact of the scenario, pinned here.
func test_north_italy_every_country_knows_every_other() -> void:
	var defs := ResourceLoader.load("res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	var map := ResourceLoader.load("res://data/maps/north_italy.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var scen := ResourceLoader.load("res://data/scenarios/north_italy_1480.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef
	var g := Game.new_scenario(map, defs, scen, 1480)
	var tags: Array[StringName] = []
	for c: Country in g.countries:
		if c != null and c.tag != &"":
			tags.append(c.tag)
	assert_eq(tags.size(), 13, "north Italy has thirteen countries")
	for tag: StringName in tags:
		assert_eq(Knowledge.known(g, tag).size(), tags.size() - 1, "%s knows the other twelve (the whole map is discovered)" % tag)
		assert_eq(Knowledge.unknown_count(g, tag), 0, "%s knows no country as unknown" % tag)

