## The economy in war (docs/architecture/m7-build-spec.md 4.10, D21, D22): a district counts for its controller; the land an
## occupier holds pays it its output and tax at the WarDef permille (500); nobody pays upkeep or walls on occupied land;
## a besieged hex gives and takes nothing; the towns' needs are the full count, the tax the weighted one. Every case starts
## from a fresh game (WarFixture.game) and plants its occupation or siege on it; nothing shared is changed.
extends GutTest

@warning_ignore_start("integer_division")

const SAVOY := &"SAV"


func _made(g: Game, id: int) -> Dictionary:
	var held := SeasonProfile.table(g)
	var c := Countries.by_id(g, id)
	return SeasonProfile.made(g, SeasonProfile.of(g, held, id), SeasonProfile.live(g, held, id), Calendar.season_of(g.turn),
		g.weather, c.tax)


## A settlement of `tag` with people, goods and upkeep (the upkeep case needs all three); -1 when none.
func _settlement(g: Game, tag: StringName) -> int:
	var c := Countries.by_tag(g, tag)
	var view := StateView.of(g.state)
	for i: int in Territory.districts(g, c.id):
		if g.state.main_use[i] != Economy.SETTLEMENTS or g.state.people[i] <= 0:
			continue
		var climate := int(g.map.climate[i])
		var w := int(g.weather[climate]) if climate < g.weather.size() else Economy.CALM
		var got := Economy.district_output(g, view, g.map.hex_of(i), Calendar.season_of(g.turn), w)
		if int(got["ducats"]) > 0 and int(got["upkeep"]) > 0:
			return i
	return -1


## Occupies hex index `i` for `by` and drops the control cache (the test writes the state directly; a capture flushes it).
func _occupy(g: Game, i: int, by: StringName) -> void:
	WarFixture.set_occupier(g, g.map.hex_of(i), by)
	g.war_cache.forget_control()


func _goods_at(g: Game, i: int) -> PackedInt32Array:
	var climate := int(g.map.climate[i])
	var w := int(g.weather[climate]) if climate < g.weather.size() else Economy.CALM
	return Economy.district_output(g, StateView.of(g.state), g.map.hex_of(i), Calendar.season_of(g.turn), w)["goods"]


func _upkeep_at(g: Game, i: int) -> int:
	var climate := int(g.map.climate[i])
	var w := int(g.weather[climate]) if climate < g.weather.size() else Economy.CALM
	return int(Economy.district_output(g, StateView.of(g.state), g.map.hex_of(i), Calendar.season_of(g.turn), w)["upkeep"])


func test_no_war_counts_are_the_owned_land() -> void:
	var g := WarFixture.game()
	var view := StateView.of(g.state)
	for c: Country in g.countries:
		var town := 0
		var rest := 0
		for i: int in Territory.districts(g, c.id):
			if view.main_use_at(i) == Economy.SETTLEMENTS:
				town += Economy.people_i(g.map, view, i)
			else:
				rest += Economy.people_i(g.map, view, i)
		var counts := EconomySeason.counts(g, view, c.tag)
		assert_eq([counts["town"], counts["rest"], counts["town_tax"], counts["rest_tax"]], [town, rest, town, rest],
			"%s: with no war the full and tax counts are the owned land" % c.tag)


func test_occupied_town_moves_its_people_and_its_tax_to_the_occupier() -> void:
	var g := WarFixture.game()
	var owner := SAVOY
	var occupier := WarFixture.neighbour_of(g, owner)
	var i := _settlement(g, owner)
	assert_true(i >= 0 and occupier != &"", "precondition: a settlement with people, goods and upkeep, and a neighbour")
	if i < 0 or occupier == &"":
		return
	WarFixture.at_war(g, owner, occupier)
	var view := StateView.of(g.state)
	var before_owner := EconomySeason.counts(g, view, owner)
	var before_occ := EconomySeason.counts(g, view, occupier)
	var people := Economy.people_i(g.map, view, i)
	_occupy(g, i, occupier)
	var after_owner := EconomySeason.counts(g, StateView.of(g.state), owner)
	var after_occ := EconomySeason.counts(g, StateView.of(g.state), occupier)
	assert_eq(int(after_owner["town"]), int(before_owner["town"]) - people, "the owner's full towns lose the held town")
	assert_eq(int(after_occ["town"]), int(before_occ["town"]) + people, "the occupier's full towns need the held town in full")
	assert_eq(int(after_owner["town_tax"]), int(before_owner["town_tax"]) - people, "the owner's tax loses it in full")
	assert_eq(int(after_occ["town_tax"]), int(before_occ["town_tax"]) + people * g.defs.war.occupied_tax_permille / 1000,
		"the occupier's tax gains it at the occupied tax permille")


func test_held_land_output_goes_to_the_occupier_at_half_and_the_owner_loses_it() -> void:
	var g := WarFixture.game()
	var owner := SAVOY
	var occupier := WarFixture.neighbour_of(g, owner)
	var i := _settlement(g, owner)
	if i < 0 or occupier == &"":
		assert_true(false, "precondition: a settlement and a neighbour")
		return
	WarFixture.at_war(g, owner, occupier)
	var owner_id := Countries.by_tag(g, owner).id
	var occ_id := Countries.by_tag(g, occupier).id
	var before_owner := _made(g, owner_id)
	var before_occ := _made(g, occ_id)
	var goods := _goods_at(g, i)
	_occupy(g, i, occupier)
	var after_owner := _made(g, owner_id)
	var after_occ := _made(g, occ_id)
	var share := g.defs.war.occupied_output_permille
	for k: int in goods.size():
		assert_eq(int(after_owner["made"][k]), int(before_owner["made"][k]) - goods[k],
			"the owner loses the held hex's good %d" % k)
		assert_eq(int(after_occ["made"][k]), int(before_occ["made"][k]) + goods[k] * share / 1000,
			"the occupier makes the good %d at the occupied output permille" % k)


func test_held_land_pays_no_upkeep_to_anyone() -> void:
	var g := WarFixture.game()
	var owner := SAVOY
	var occupier := WarFixture.neighbour_of(g, owner)
	var i := _settlement(g, owner)
	if i < 0 or occupier == &"":
		assert_true(false, "precondition: a settlement with upkeep and a neighbour")
		return
	WarFixture.at_war(g, owner, occupier)
	var owner_id := Countries.by_tag(g, owner).id
	var occ_id := Countries.by_tag(g, occupier).id
	var upkeep := _upkeep_at(g, i)
	var before_owner := int(_made(g, owner_id)["upkeep"])
	var before_occ := int(_made(g, occ_id)["upkeep"])
	_occupy(g, i, occupier)
	assert_eq(int(_made(g, owner_id)["upkeep"]), before_owner - upkeep, "the owner stops paying the held hex's upkeep")
	assert_eq(int(_made(g, occ_id)["upkeep"]), before_occ, "the occupier pays none of it")


func test_besieged_hex_gives_and_takes_nothing() -> void:
	var g := WarFixture.game()
	var owner := SAVOY
	var besieger := WarFixture.neighbour_of(g, owner)
	var i := _settlement(g, owner)
	if i < 0 or besieger == &"":
		assert_true(false, "precondition: a settlement with upkeep and a neighbour")
		return
	WarFixture.at_war(g, owner, besieger)
	var owner_id := Countries.by_tag(g, owner).id
	var before := _made(g, owner_id)
	var view := StateView.of(g.state)
	var people := Economy.people_i(g.map, view, i)
	var goods := _goods_at(g, i)
	var upkeep := _upkeep_at(g, i)
	var town_before := int(EconomySeason.counts(g, view, owner)["town"])
	var siege := Siege.new()
	siege.hex = g.map.hex_of(i)
	siege.besieger = besieger
	g.sieges.append(siege)
	assert_true(EconomySeason.besieged_set(g).has(i), "the siege holds the hex")
	var after := _made(g, owner_id)
	for k: int in goods.size():
		assert_eq(int(after["made"][k]), int(before["made"][k]) - goods[k], "a besieged hex makes nothing (good %d)" % k)
	assert_eq(int(after["upkeep"]), int(before["upkeep"]) - upkeep, "nobody pays the upkeep of a besieged hex")
	assert_eq(int(EconomySeason.counts(g, StateView.of(g.state), owner)["town"]), town_before - people,
		"its people count for nothing and need nothing")


func test_the_occupied_hex_is_in_the_occupiers_profile_only() -> void:
	var g := WarFixture.game()
	var owner := SAVOY
	var occupier := WarFixture.neighbour_of(g, owner)
	var i := _settlement(g, owner)
	if i < 0 or occupier == &"":
		assert_true(false, "precondition: a settlement and a neighbour")
		return
	WarFixture.at_war(g, owner, occupier)
	_occupy(g, i, occupier)
	var occ_id := Countries.by_tag(g, occupier).id
	var owner_id := Countries.by_tag(g, owner).id
	assert_true(Occupation.controlled(g, occ_id).has(i), "the occupier controls the hex")
	assert_false(Occupation.controlled(g, owner_id).has(i), "the owner no longer controls it")


func test_income_lines_add_up_to_the_ledger_with_occupation() -> void:
	var g := WarFixture.game()
	var owner := SAVOY
	var occupier := WarFixture.neighbour_of(g, owner)
	var i := _settlement(g, owner)
	if i < 0 or occupier == &"":
		assert_true(false, "precondition: a settlement and a neighbour")
		return
	WarFixture.at_war(g, owner, occupier)
	_occupy(g, i, occupier)
	var occ := Countries.by_tag(g, occupier)
	var before := occ.treasury
	var opening := occ.ledger_from
	EconomySeason.income(g)
	var total := 0
	for line: Dictionary in occ.ledger_open:
		total += int(line["amount"])
	assert_eq(occ.treasury - before, total, "the occupier's income lines sum to its treasury change")
	assert_eq(occ.ledger_from, opening, "the ledger's opening is untouched by the income phase")


func test_a_war_end_rekeys_the_profile_table_and_lifts_the_siege() -> void:
	var g := WarFixture.game()
	var owner := SAVOY
	var besieger := WarFixture.neighbour_of(g, owner)
	var i := _settlement(g, owner)
	if i < 0 or besieger == &"":
		assert_true(false, "precondition: a settlement and a neighbour")
		return
	var war := WarFixture.at_war(g, owner, besieger)
	var siege := Siege.new()
	siege.hex = g.map.hex_of(i)
	siege.besieger = besieger
	g.sieges.append(siege)
	var before := SeasonProfile.table(g)
	assert_true(EconomySeason.besieged_set(g).has(i), "besieged while the war is live")
	war.end_turn = maxi(1, g.turn)
	assert_false(EconomySeason.besieged_set(g).has(i), "a war end lifts the hold of the siege")
	assert_false(is_same(before, SeasonProfile.table(g)), "the profile table is re-keyed by the war's end")


func test_preview_equals_play_with_an_occupied_district_for_owner_and_occupier() -> void:
	var g := EconomyFixture.game(SAVOY)
	var owner := SAVOY
	var occupier := WarFixture.neighbour_of(g, owner)
	var i := _settlement(g, owner)
	if i < 0 or occupier == &"":
		assert_true(false, "precondition: a settlement and a neighbour")
		return
	WarFixture.at_war(g, owner, occupier)
	_occupy(g, i, occupier)
	for tag: StringName in [owner, occupier]:
		var ahead: Array = EconomyPreview.with(g, tag, {}, 3)["seasons"]
		var played: Array = []
		for k: int in 3:
			Season.run(g)
			played.append(Countries.by_tag(g, tag).ledger_closed.get("lines", []))
		for k: int in 3:
			assert_eq(EconomyFixture.totals(ahead[k]["lines"]), EconomyFixture.totals(played[k]),
				"%s, season %d: the preview's money lines are the played ones" % [tag, k])


## M7 (4.11): an occupier's held town walks under the occupier, in play and in the preview: it grows over eight seasons, and the
## occupier's people total is the same in the preview as in the played seasons (the real people rules; the owner's walk skips it).
func test_an_occupiers_held_town_grows_in_play_and_in_the_preview() -> void:
	var g := EconomyFixture.game(SAVOY, false, true, EconomyFixture.SEED, false)
	var owner := SAVOY
	var occupier := WarFixture.neighbour_of(g, owner)
	var i := _settlement(g, owner)
	if i < 0 or occupier == &"":
		assert_true(false, "precondition: a settlement with people, goods and upkeep, and a neighbour")
		return
	var hex := g.map.hex_of(i)
	assert_true(g.dev_people(hex, maxi(g.districts.room_of(g, i) / 2, 1)), "the town starts half full")
	WarFixture.at_war(g, owner, occupier)
	_occupy(g, i, occupier)
	var start := int(g.state.people[i])
	var ahead: Array = EconomyPreview.with(g, occupier, {}, 8)["seasons"]
	var occ := Countries.by_tag(g, occupier)
	var played: Array[int] = []
	for k: int in 8:
		Season.run(g)
		var total := 0
		for h: int in Occupation.controlled(g, occ.id):
			total += int(g.state.people[h])
		played.append(total)
	assert_gt(int(g.state.people[i]), start, "the held town grows in play")
	for k: int in mini(8, ahead.size()):
		assert_eq(int(ahead[k]["people"]), played[k], "the occupier's people in season %d: the preview is the played one" % k)
