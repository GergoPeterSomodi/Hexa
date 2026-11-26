## The cross-view proofs of the fog build (docs/architecture/fog-build-spec.md 3.4, 5, 7; R3, R18, R23, R29, R36). On the thin
## fixture (FogFixture.duel_thin: Milan, MLO, thin at radius 2, the player) an undiscovered hex gives no land fact through a
## view, a light-fog hex gives its land facts and no army, and an army out of sight is in no view. Each planted case (P) feeds
## the check a text that names the forbidden fact, and the check must report it.
extends GutTest

const VIEWER := AiFixture.MILAN
const VENICE := AiFixture.VENICE
## The views of section 5 that must follow Knowledge and never read the sight directly (R3). map_modes.gd keeps the discovered
## bitset of FG13 (R36): its test below proves it equals Knowledge.discovered, so it is not in the list.
const VIEW_ROOT := "res://core/views"
const SIGHT_READS: Array[String] = ["Sight.explored", "Sight.sees", "Sight.known_of", "Sight.explored_any", ".explored"]
const SIGHT_ALLOWED: Array[String] = ["knowledge.gd", "map_modes.gd"]


func _game() -> Game:
	var g := FogFixture.duel_thin()
	g.player = VIEWER
	return g


## The first land hex the viewer has not discovered whose owner is another country; Army.NO_HEX when none.
func _undiscovered_owned(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and not Knowledge.discovered(g, VIEWER, hex) and Territory.owner_tag(g, hex) != &"":
			return hex
	return Army.NO_HEX


## The first land hex in light fog (discovered, not in sight) owned by another country; Army.NO_HEX when none.
func _light_owned(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		var owner := Territory.owner_tag(g, hex)
		if g.map.is_land(hex) and Knowledge.discovered(g, VIEWER, hex) and not Knowledge.sees(g, VIEWER, hex) \
				and owner != &"" and owner != VIEWER:
			return hex
	return Army.NO_HEX


## The long name of the hex's owner: the words a leak would show.
func _owner_name(g: Game, hex: Vector2i) -> String:
	var tag := Territory.owner_tag(g, hex)
	var cdef := Countries.def_of(g, tag)
	return cdef.long_name if cdef != null and cdef.long_name != "" else String(tag)


## True when a view's text (its str()) names the fact: the one test every view below makes.
func _leaks(view_text: String, fact: String) -> bool:
	return fact != "" and view_text.contains(fact)


# ----- the land of a hex -------------------------------------------------------------------------------------------------


func test_thin_fixture_has_both_an_undiscovered_and_a_light_fog_owned_hex() -> void:
	var g := _game()
	assert_ne(_undiscovered_owned(g), Army.NO_HEX, "an undiscovered hex with an owner")
	assert_ne(_light_owned(g), Army.NO_HEX, "a light-fog hex with an owner")


func test_hex_card_of_an_undiscovered_hex_names_no_owner() -> void:
	var g := _game()
	var hex := _undiscovered_owned(g)
	var card := HexCard.of(g, hex)
	assert_eq(str(card["title"]), "Unexplored", "the card of an undiscovered hex is Unexplored (D18)")
	assert_false(_leaks(str(card), _owner_name(g, hex)), "no owner of an undiscovered hex in its card")


func test_p_a_hex_card_that_names_an_undiscovered_owner_is_reported() -> void:
	var g := _game()
	var hex := _undiscovered_owned(g)
	var planted := str({"title": "Venice", "owner": _owner_name(g, hex)})
	assert_true(_leaks(planted, _owner_name(g, hex)), "the planted owner is found")


func test_hex_card_of_a_light_fog_hex_shows_its_owner() -> void:
	var g := _game()
	var hex := _light_owned(g)
	assert_ne(hex, Army.NO_HEX, "a light-fog hex to read")
	var card := HexCard.of(g, hex)
	assert_true(_leaks(str(card), _owner_name(g, hex)), "light fog shows the owner (R18): %s" % _owner_name(g, hex))


func test_people_view_hides_an_undiscovered_hex_and_shows_a_light_one() -> void:
	var g := _game()
	var hidden := PeopleView.at(g, VIEWER, _undiscovered_owned(g))
	assert_false(bool(hidden.get("shown", true)), "an undiscovered hex has no people shown")
	var light := PeopleView.at(g, VIEWER, _light_owned(g))
	assert_true(bool(light.get("shown", false)), "a light-fog hex has its people (R18)")
	assert_true(bool(light.get("exact", false)), "and they are exact")


# ----- the armies -------------------------------------------------------------------------------------------------


func test_a_foreign_army_out_of_sight_is_in_no_view_and_one_in_sight_is() -> void:
	var g := _game()
	var out_of_sight := 0
	var in_sight := 0
	for army: Army in g.armies:
		if army.tag == VIEWER:
			continue
		if Knowledge.sees(g, VIEWER, army.hex):
			in_sight += 1
			assert_true(ArmyView.visible(g, VIEWER, army), "an army in sight is shown")
		else:
			out_of_sight += 1
			assert_false(ArmyView.visible(g, VIEWER, army), "an army out of sight is not shown (R23)")
	assert_gt(out_of_sight + in_sight, 0, "the thin duel has foreign armies (Venice's neighbours)")


func test_armies_seen_are_exactly_the_foreign_armies_in_sight() -> void:
	var g := _game()
	for seen: Dictionary in Knowledge.armies_seen(g, VIEWER):
		assert_true(Knowledge.sees(g, VIEWER, seen["hex"] as Vector2i), "every army seen is in sight (R25)")
		assert_eq(seen["men"], (seen["army"] as Army).men(), "its men are exact")


func test_p_an_army_out_of_sight_in_a_listing_is_reported() -> void:
	var g := _game()
	var hidden: Army = null
	for army: Army in g.armies:
		if army.tag != VIEWER and not Knowledge.sees(g, VIEWER, army.hex):
			hidden = army
			break
	assert_not_null(hidden, "an army out of sight to plant")
	# A listing that includes the hidden army is the leak: the check reports it.
	assert_false(Knowledge.armies_seen(g, VIEWER).any(func(e: Dictionary) -> bool: return (e["army"] as Army) == hidden),
		"the hidden army is not in the listing")


# ----- the log and the map -----------------------------------------------------------------------------------------------


func test_a_land_event_is_told_only_where_the_hex_is_discovered() -> void:
	var g := _game()
	var hidden := _undiscovered_owned(g)
	var event := {"kind": "owners_changed", "tag": VENICE, "others": [], "land": true, "hex": hidden}
	assert_false(Knowledge.witnessed(g, event, VIEWER), "an undiscovered land event is not told (R29)")
	# P: a sight list that names the viewer does not make an undiscovered land event told.
	var listed := event.duplicate()
	listed["witnesses"] = [String(VIEWER)]
	assert_false(Knowledge.witnessed(g, listed, VIEWER), "P: a land event told by the sight list is refused")
	var light := {"kind": "owners_changed", "tag": VENICE, "others": [], "land": true, "hex": _light_owned(g)}
	assert_true(Knowledge.witnessed(g, light, VIEWER), "a light-fog land event is told")


func test_map_modes_discovered_bytes_are_the_discovered_set() -> void:
	var g := _game()
	var bytes := MapModes.discovered_bytes(g, VIEWER)
	var disagree := 0
	for i: int in g.map.hex_count():
		var on := bytes[i] == 1
		if on != Knowledge.discovered(g, VIEWER, g.map.hex_of(i)):
			disagree += 1
	assert_eq(disagree, 0, "the deep-fog fill is the discovered set (R36)")


func test_country_land_seen_counts_only_discovered_districts() -> void:
	var g := _game()
	var ven := Countries.by_tag(g, VENICE)
	var expected := 0
	for i: int in Territory.districts(g, ven.id):
		if Knowledge.discovered(g, VIEWER, g.map.hex_of(i)):
			expected += 1
	var seen := Knowledge.land_seen(g, VIEWER, VENICE)
	assert_eq(int(seen["districts"]), expected, "Venice's land seen by Milan is its discovered districts (R26)")
	assert_lt(expected, Territory.districts(g, ven.id).size(), "the thin fixture leaves some of Venice undiscovered")


# ----- the scan (R3): no section-5 view reads the sight itself -----------------------------------------------------


func _view_problems(text: String, file: String) -> Array[String]:
	var out: Array[String] = []
	if SIGHT_ALLOWED.has(file):
		return out
	for read: String in SIGHT_READS:
		if text.contains(read):
			out.append("%s: %s" % [file, read])
	return out


func test_no_view_reads_the_sight_directly() -> void:
	var dir := DirAccess.open(VIEW_ROOT)
	var files := dir.get_files()
	var seen := 0
	for name: String in files:
		if not name.ends_with(".gd"):
			continue
		seen += 1
		assert_eq(_view_problems(FileAccess.get_file_as_string("%s/%s" % [VIEW_ROOT, name]), name), [] as Array[String], name)
	assert_gt(seen, 30, "the scan reads the views")


func test_p_a_view_that_reads_the_sight_is_reported() -> void:
	assert_eq(_view_problems("var x := Sight.sees(g, t, h)", "hex_card.gd").size(), 1)
	assert_eq(_view_problems("var x := g.sight.explored(t, h)", "odds_view.gd").size(), 1, "the sight's bitset read is reported too")
	assert_eq(_view_problems("var x := Sight.sees(g, t, h)", "knowledge.gd").size(), 0, "knowledge.gd is the gate")


# ----- FG17: a walk that discovers hexes refreshes the cached views (the version rule, D15 / Knowledge.land_seen) -----------


func test_a_walk_that_discovers_hexes_refreshes_the_cached_land_seen_without_a_hand_bump() -> void:
	# A real march on north Italy: the army walks (MovementPhase.season, the season's walk) into the other country's land,
	# which Milan's country has not discovered. land_seen is read before the walk (it is cached per game.version) and again
	# after it with no hand bump of the version: the cached value must equal a fresh count.
	var g := ArmyFixture.game()
	var tag := ArmyFixture.TAG
	var other := ArmyFixture.other_tag(g)
	g.player = tag
	FogFixture.thin(g, tag, 0)
	# The army starts on the other country's land (a land hex of `other`), so the walk stays in its land and reaches the
	# undiscovered hexes beside it; the march is ordered against the war that lets it in.
	var start := AiFixture.land_hex(g, other)
	assert_ne(start, Army.NO_HEX, "a land hex of the other country")
	var army := ArmyFixture.army(g, tag, start, 0, 2)
	WarFixture.at_war(g, tag, other)  # a march into another country's land needs a war (peace refuses it)
	var goal := _nearest_walkable(g, army, other)
	assert_ne(goal, Army.NO_HEX, "an undiscovered hex of the other country to walk to")
	# Moves in the month (moves-build-spec.md 8.2, MV4): an act would walk the march at once, so the fixture gives the standing
	# march the season's walk takes (the check still says yes); its version bump is the act's.
	var ordered := g.check("march", {"army": army.id, "tag": tag, "goal": goal})
	assert_true(bool(ordered.get("ok", false)), "the march is ordered: " + str(ordered.get("reason", "")))
	assert_true(MovesFixture.standing(g, army, goal))
	# Read after the order (its act bumped the version): the cache now holds the value of the version the walk runs under.
	var before := Knowledge.land_seen(g, tag, other)
	assert_eq(int(before["districts"]), _seen_count(g, tag, other), "the cache is right before the walk")
	var walks := 0
	while not Knowledge.discovered(g, tag, goal) and walks < 40:
		MovementPhase.season(g)
		Allowance.refill(g)  # moves in the month: ready_units refills the points each season
		walks += 1
	assert_true(Knowledge.discovered(g, tag, goal), "the walk discovers the goal hex in %d seasons" % walks)
	var fresh := _seen_count(g, tag, other)
	assert_gt(fresh, int(before["districts"]), "the walk discovered a hex of the other country's land")
	assert_eq(int(Knowledge.land_seen(g, tag, other)["districts"]), fresh,
		"land_seen after the walk, with no hand bump, equals a fresh count (a stale cache is the bug)")


## The districts of `other` that `tag` has discovered, counted from the rule itself (not the cache).
func _seen_count(g: Game, tag: StringName, other: StringName) -> int:
	var n := 0
	for i: int in Territory.districts(g, Countries.by_tag(g, other).id):
		if Knowledge.discovered(g, tag, g.map.hex_of(i)):
			n += 1
	return n


## The undiscovered hex of `other` nearest to the army that a march of the army's can reach (the nearest 80 are tried);
## Army.NO_HEX when none.
func _nearest_walkable(g: Game, army: Army, other: StringName) -> Vector2i:
	var open: Array[Vector2i] = []
	for i: int in Territory.districts(g, Countries.by_tag(g, other).id):
		var hex := g.map.hex_of(i)
		if not Knowledge.discovered(g, army.tag, hex):
			open.append(hex)
	open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return AiKnow.hex_distance(a, army.hex) < AiKnow.hex_distance(b, army.hex))
	for k: int in mini(open.size(), 80):
		if bool(Movement.march_check(g, {"army": army.id, "tag": army.tag, "goal": open[k]}).get("ok", false)):
			return open[k]
	return Army.NO_HEX


# ----- FG17: the AI's steps read no undiscovered hex (R33): a planted change under deep fog leaves Milan's acts unchanged -----


## The first land hex Milan has not discovered that another country owns and that is not beside Milan's own land; NO_HEX.
func _deep_owned_away_from_milan(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if not g.map.is_land(hex) or Knowledge.discovered(g, VIEWER, hex) or Territory.owner_tag(g, hex) in [&"", VIEWER]:
			continue
		var beside := false
		for n: Vector2i in AiKnow.land_neighbours(g, hex):
			if Territory.owner_tag(g, n) == VIEWER:
				beside = true
		if not beside:
			return hex
	return Army.NO_HEX


## Plants a change of a hex: its owner, its use and its fortress level (the state the AI reads).
func _plant(g: Game, hex: Vector2i) -> void:
	var i := g.map.index_of(hex)
	g.state.owner[i] = Countries.by_tag(g, AiFixture.GENOA).id
	g.state.main_use[i] = 0
	g.state.level[i] = 3
	Sight.refresh(g)
	g.version += 1


func test_a_planted_change_under_deep_fog_leaves_the_ai_acts_unchanged() -> void:
	var base := FogFixture.duel_thin()
	var hex := _deep_owned_away_from_milan(base)
	assert_ne(hex, Army.NO_HEX, "an undiscovered hex of another country, away from Milan's land, to plant")
	var acts_base := str(AiFixture.seat(base, VIEWER))
	var planted := FogFixture.duel_thin()
	_plant(planted, hex)
	assert_eq(AiKnow.owner_of(planted, hex), AiFixture.GENOA, "the plant took effect on the hex (not a no-op)")
	var acts_planted := str(AiFixture.seat(planted, VIEWER))
	assert_eq(acts_planted, acts_base, "an undiscovered hex's owner, use and fortress change no act of Milan (R33)")
