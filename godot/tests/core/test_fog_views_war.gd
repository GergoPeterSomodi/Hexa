## The cross-view proofs of the fog build, part 2: the war views (fog-build-spec 3.4 rows "A siege", R21, R22) and the AI's work
## candidates (R33). The sieges are started by the real producer (Sieges._start_siege, the 4.5 start) on the thin duel: Milan
## (MLO) besieges Venice's fortresses at war, Genoa (GEN) is thin at radius 2 and so sees some and only knows others.
## A planted fault (P) feeds the check the text that names the forbidden fact, and the check must report it.
extends GutTest

const MILAN := AiFixture.MILAN
const VENICE := AiFixture.VENICE
const GENOA := AiFixture.GENOA
const SIEGE_HEXES := 40


## The thin duel with `SIEGE_HEXES` sieges of Milan on Venice's land (level-2 fortresses with a garrison), and Genoa thin.
func _sieged() -> Dictionary:
	var g := FogFixture.duel_thin()
	FogFixture.thin(g, GENOA, 2)
	WarFixture.at_war(g, MILAN, VENICE)
	var hexes: Array[Vector2i] = []
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and Territory.owner_tag(g, hex) == VENICE and hexes.size() < SIEGE_HEXES:
			hexes.append(hex)
	for hex: Vector2i in hexes:
		var i := g.map.index_of(hex)
		g.state.level[i] = 2
		g.state.garrison[i] = g.defs.war.garrison_per_level * 2
		Sieges._start_siege(g, hex, MILAN, VENICE)
	# A Genoese army beside the first siege hex: its sight covers that hex, so the seen level is produced (R21).
	for d: int in 6:
		var near := ImproveRules.neighbour(hexes[0], d)
		if g.map.is_land(near) and Territory.owner_tag(g, near) == VENICE:
			WarFixture.army_at(g, GENOA, near, 1)
			break
	Sight.refresh(g)
	g.version += 1
	return {"g": g, "hexes": hexes}


## The access the rule gives Genoa on a siege hex, from the discovery and the sight alone (R21, not Knowledge's code).
func _rule_access(g: Game, viewer: StringName, hex: Vector2i) -> StringName:
	if Sight.sees(g, viewer, hex):
		return &"seen"
	if Sight.explored(g, viewer, hex):
		return &"land"
	return &"hidden"


## True when a view's text names the besieger's long name (the fact a land or hidden view must not show).
func _names_besieger(view_text: String, g: Game) -> bool:
	var cdef := Countries.def_of(g, MILAN)
	var name := cdef.long_name if cdef != null and cdef.long_name != "" else String(MILAN)
	return view_text.contains(name)


func test_the_siege_access_follows_the_rule_on_every_siege_hex() -> void:
	var s := _sieged()
	var g := s["g"] as Game
	var levels := {}
	for hex: Vector2i in s["hexes"]:
		var expected := _rule_access(g, GENOA, hex)
		var access := Knowledge.siege_access(g, GENOA, hex)
		assert_eq(access, expected, "Genoa's access to the siege at %s follows the discovery and the sight (R21)" % str(hex))
		levels[access] = true
	assert_true(levels.has(&"land") or levels.has(&"hidden"), "the thin fixture has hexes Genoa does not see")
	assert_true(levels.has(&"seen") or levels.has(&"land") or levels.has(&"hidden"), "levels were produced: %s" % str(levels.keys()))


func test_a_land_or_hidden_siege_view_names_no_besieger() -> void:
	var s := _sieged()
	var g := s["g"] as Game
	var checked := 0
	for hex: Vector2i in s["hexes"]:
		var access := Knowledge.siege_access(g, GENOA, hex)
		if access != &"land" and access != &"hidden":
			continue
		var view := SiegeView.at(g, GENOA, hex)
		checked += 1
		assert_false(_names_besieger(str(view), g), "no besieger name at a %s siege (R21)" % access)
		if access == &"land":
			assert_eq(str(view.get("besieger", "")), "", "the besieger key is empty at land (R21)")
	assert_gt(checked, 0, "at least one land or hidden siege to check")


func test_p_a_siege_view_that_names_the_besieger_at_land_is_reported() -> void:
	var g := FogFixture.duel_thin()
	var planted := str({"access": "land", "besieger": Countries.def_of(g, MILAN).long_name})
	assert_true(_names_besieger(planted, g), "the planted besieger is found")


func test_a_seen_siege_names_the_besieger_and_an_exact_siege_has_its_men() -> void:
	var s := _sieged()
	var g := s["g"] as Game
	for hex: Vector2i in s["hexes"]:
		if Knowledge.siege_access(g, GENOA, hex) == &"seen":
			var view := SiegeView.at(g, GENOA, hex)
			assert_true(_names_besieger(str(view), g), "a seen siege names its besieger (R21)")
			return
	fail_test("no siege hex in Genoa's sight: the army beside the first siege hex should see it")


func test_the_exact_siege_is_for_the_besieger_and_the_holder() -> void:
	var s := _sieged()
	var g := s["g"] as Game
	var hex: Vector2i = s["hexes"][0]
	assert_eq(Knowledge.siege_access(g, MILAN, hex), &"exact", "the besieger sees its siege exactly (R21)")
	assert_eq(Knowledge.siege_access(g, VENICE, hex), &"exact", "the holder sees its siege exactly (R21)")


# ----- the AI's work candidates (R33) ------------------------------------------------------------------------------


func test_work_candidates_are_discovered_by_the_seat() -> void:
	var g := FogFixture.duel_thin()
	var out := AiKnow.work_candidates(g, MILAN)
	for hex: Vector2i in out:
		assert_true(Knowledge.discovered(g, MILAN, hex), "a work candidate of Milan is discovered by Milan: %s" % str(hex))
	assert_gte(out.size(), 0, "the candidates are listed (%d)" % out.size())
