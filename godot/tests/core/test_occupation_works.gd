## Works and the occupation door (m7-build-spec 4.4, 5.3 row 3b, 5.4): a work halts on occupied or besieged land, no work
## begins there (the words of row 3b), and dev_transfer releases occupation first. Each test takes a fresh 1480 game.
extends GutTest


func _fresh() -> Game:
	var g := EconomyFixture.game()
	Occupation.setup(g)
	return g


func _open_mlo(g: Game) -> Vector2i:
	var mlo := Countries.by_tag(g, &"MLO").id
	for i: int in Territory.districts(g, mlo):
		var hex := g.map.hex_of(i)
		if Occupation.area_of(g, hex) == Army.NO_HEX and not Occupation.is_occupied(g, hex):
			return hex
	return Army.NO_HEX


func test_a_work_halts_on_occupied_land() -> void:
	var g := _fresh()
	var hex := _open_mlo(g)
	var work := Work.new()
	work.hex = hex
	assert_false(Works.halted(g, work, g.turn))
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	assert_true(Works.halted(g, work, g.turn), "occupied land halts the work")


func test_a_work_halts_under_siege() -> void:
	var g := _fresh()
	var hex := _open_mlo(g)
	var work := Work.new()
	work.hex = hex
	var s := Siege.new()
	s.hex = hex
	s.besieger = &"SAV"
	g.sieges.append(s)
	var w := War.new()
	w.id = 1
	w.a = &"SAV"
	w.b = &"MLO"
	w.start_turn = 1
	g.wars.append(w)
	assert_true(Works.halted(g, work, g.turn), "a siege by a country at war halts the work")


func test_no_work_begins_on_occupied_land_and_the_words_name_the_occupier() -> void:
	var g := _fresh()
	var hex := _open_mlo(g)
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	var savoy := Countries.def_of(g, &"SAV").long_name
	var verdict := Works.build_check(g, {"hex": hex, "family": ImproveRules.WHEAT, "tag": &"MLO"})
	assert_eq(verdict["reason"], "held by the %s: no work can begin on occupied land" % savoy)
	assert_eq(Works.clear_check(g, {"hex": hex, "tag": &"MLO"})["reason"],
		"held by the %s: no work can begin on occupied land" % savoy, "a clear is refused too")


func test_no_work_begins_under_siege() -> void:
	var g := _fresh()
	var hex := _open_mlo(g)
	var s := Siege.new()
	s.hex = hex
	s.besieger = &"SAV"
	g.sieges.append(s)
	var w := War.new()
	w.id = 1
	w.a = &"SAV"
	w.b = &"MLO"
	w.start_turn = 1
	g.wars.append(w)
	var verdict := Works.build_check(g, {"hex": hex, "family": ImproveRules.WHEAT, "tag": &"MLO"})
	assert_eq(verdict["reason"], "under siege: no work can begin")


func test_the_door_has_the_war_cache_field() -> void:
	assert_true(Game.DOOR_FIELDS.has("war_cache"))


func test_dev_transfer_releases_the_occupation_first() -> void:
	var g := _fresh()
	var hex := _open_mlo(g)
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	Occupation.flush(g)
	var mlo := Countries.by_tag(g, &"MLO").id
	var ven := Countries.by_tag(g, &"VEN").id
	g.dev_transfer([hex] as Array[Vector2i], ven)
	assert_false(Occupation.is_occupied(g, hex), "the land given away is released")
	assert_eq(Territory.owner_id(g, hex), ven)
	assert_eq(Occupation.controller_tag(g, hex), &"VEN")
	assert_ne(Territory.owner_id(g, hex), mlo)


## A refused or no-op dev_transfer leaves the occupation intact (review 6): a bad to_id or the owner's own id releases nothing.
func test_a_refused_dev_transfer_leaves_the_occupation_intact() -> void:
	var g := _fresh()
	var hex := _open_mlo(g)
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	Occupation.flush(g)
	assert_eq(g.dev_transfer([hex] as Array[Vector2i], 250), 0, "a bad id is refused")
	assert_true(Occupation.is_occupied(g, hex), "the occupation stays")
	assert_eq(g.dev_transfer([hex] as Array[Vector2i], Countries.by_tag(g, &"MLO").id), 0, "the owner already holds it: no owner changes")
	assert_eq(g.dev_transfer([hex] as Array[Vector2i], Territory.owner_id(g, hex)), 0, "the same owner is a no-op")
	assert_true(Occupation.is_occupied(g, hex), "still occupied")


## A work on occupied land has no date: ready_turn says NO_DATE at once, and the words say "halted by war" (review 7).
func test_a_work_halted_by_occupation_has_no_date_and_says_so() -> void:
	var g := _fresh()
	var hex := _open_mlo(g)
	var work := Work.new()
	work.hex = hex
	work.seasons_left = 3
	Occupation.capture(g, hex, &"SAV", &"walk", {})
	assert_eq(Works.ready_turn(g, work), Works.NO_DATE)
	assert_eq(Works.ready_words(g, work), "halted by war")
	var words: String = str(Works.build_check(g, {"hex": hex, "family": ImproveRules.WHEAT, "tag": &"MLO"})["reason"])
	assert_true(words.begins_with("held by the "), "the refusal names the occupier before any date")


func test_a_work_under_siege_has_no_date() -> void:
	var g := _fresh()
	var hex := _open_mlo(g)
	var work := Work.new()
	work.hex = hex
	work.seasons_left = 2
	var s := Siege.new()
	s.hex = hex
	s.besieger = &"SAV"
	g.sieges.append(s)
	var w := War.new()
	w.id = 1
	w.a = &"SAV"
	w.b = &"MLO"
	w.start_turn = 1
	g.wars.append(w)
	assert_eq(Works.ready_turn(g, work), Works.NO_DATE)
	assert_eq(Works.ready_words(g, work), "halted by war")
