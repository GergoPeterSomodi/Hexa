## MilitaryCards (docs/architecture/m6-build-spec.md sections 6.10 and 5.6, L11): the Army chip's hover card for the player's
## country, and the army field of the country card and of the hex card (M6, 4.11, 4.12). Genoa (GEN) is the player.
extends GutTest

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()


func test_no_armies_gives_the_no_armies_line_and_zero() -> void:
	var c := MilitaryCards.army(_g, ArmyFixture.TAG)
	assert_eq(int(c.value), 0)
	assert_eq(c.title, "Men under arms")
	assert_eq(c.lines[0][0], "No armies")
	assert_eq(c.hint, MilitaryCards.HINT)


func test_an_army_gives_its_men_its_count_and_upkeep() -> void:
	var hex := ArmyFixture.find_town(_g)
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 2)
	var c := MilitaryCards.army(_g, ArmyFixture.TAG)
	assert_eq(int(c.value), a.men())
	assert_eq(c.lines[0][0], "1 army, 2 companies")
	var upkeep := Military.upkeep_country(_g, ArmyFixture.TAG)
	if upkeep > 0:
		assert_eq(c.lines[1][0], "Upkeep a season")
		assert_eq(int(c.lines[1][2]), upkeep)


func test_lost_last_season_is_a_line_when_men_were_lost() -> void:
	var hex := ArmyFixture.find_town(_g)
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	a.lost_last = 40
	var found := false
	for line: Array in MilitaryCards.army(_g, ArmyFixture.TAG).lines:
		if str(line[0]) == "Lost last season":
			found = true
			assert_eq(int(line[2]), 40)
	assert_true(found, "P: a loss shows its line; no loss shows none")
	a.lost_last = 0
	for line: Array in MilitaryCards.army(_g, ArmyFixture.TAG).lines:
		assert_ne(str(line[0]), "Lost last season")


func test_country_card_army_is_exact_for_the_player_and_banded_for_a_known_country() -> void:
	var hex := ArmyFixture.find_town(_g)
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 2)
	var own: Dictionary = CountryCard.of(_g, ArmyFixture.TAG).army
	assert_true(bool(own.shown))
	assert_false(bool(own.banded))
	assert_eq(int(own.value), a.men())
	var other := ArmyFixture.other_tag(_g)
	var card: Dictionary = CountryCard.of(_g, other).army
	if Knowledge.knows(_g, ArmyFixture.TAG, other):
		assert_true(bool(card.banded), "a known country's men are banded")
		assert_eq(int(card.value), Knowledge.band(Armies.men_of_country(_g, other)))
	else:
		assert_false(bool(card.shown), "an unknown country shows no army row")


func test_hex_card_has_the_armies_and_supply_lines_on_own_land() -> void:
	var hex := ArmyFixture.find_town(_g)
	ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	var labels: Array = []
	for line: Array in HexCard.of(_g, hex).lines:
		labels.append(str(line[0]))
	assert_true(labels.has("Armies"), "the Armies line is there")
	assert_true(labels.has("Supply"), "the Supply line is there on the player's land")


func test_map_modes_has_the_supply_mode_and_its_legend() -> void:
	assert_true(MapModes.modes(_g).has(MapModes.Mode.SUPPLY))
	assert_eq(MapModes.mode_of(&"supply"), MapModes.Mode.SUPPLY)
	assert_eq(MapModes.MODE_KEYS.size(), 6)
	var rows := MapModes.legend(MapModes.Mode.SUPPLY)
	assert_eq(rows.size(), 7, "five bands (2 to 6), starving, not your land")
	assert_eq(rows[0].text, "A depot (a village or larger, a port)")
	assert_eq(rows[-1].text, "Not your land")
	assert_eq(MapModes.legend_title(MapModes.Mode.SUPPLY), "Supply: where your armies are fed")
	assert_eq(MapModes.modes(_g).back(), MapModes.Mode.SUPPLY, "the mode follows Food")


func test_sight_veil_lays_over_unseen_land_and_leaves_seen_land_alone() -> void:
	var pal := PackedColorArray()
	pal.resize(256)
	pal.fill(Color.WHITE)
	var plain := MapModes.colour_of(MapModes.Mode.TERRAIN, 1, 5, pal, false, 0)
	var seen := MapModes.colour_of(MapModes.Mode.TERRAIN, 1, 5, pal, false, 0, 0, 0, 0, 1, true)
	var unseen := MapModes.colour_of(MapModes.Mode.TERRAIN, 1, 5, pal, false, 0, 0, 0, 0, 0, true)
	assert_eq(seen, plain, "seen land keeps its colour")
	assert_true(unseen.a > plain.a, "P: unseen land under the veil is darker: the veil adds alpha")
	assert_true(MapModes.colour_of(MapModes.Mode.SUPPLY, 1, 5, pal, false, 0, 0, 0, 0, 0, true) \
		== MapModes.colour_of(MapModes.Mode.SUPPLY, 1, 5, pal, false, 0, 0, 0, 0, 0, false),
		"a supply byte 0 is already the veil: no second veil")
