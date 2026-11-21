## SupplyView (docs/architecture/m6-build-spec.md sections 4.8, 5.6 and 6.6, L11): one hex's supply for the viewer, and the Supply
## mode's bytes by 6.6's table. North Italy, Genoa (GEN) the player. Planted fault: a foreign land hex is byte 0 and not shown.
extends GutTest

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()


func _foreign_land() -> Vector2i:
	var mine := ArmyFixture.id_of(_g, ArmyFixture.TAG)
	for i: int in _g.map.hex_count():
		var owner := int(_g.state.owner[i])
		if _g.map.land[i] == 1 and owner > 0 and owner != mine:
			return _g.map.hex_of(i)
	return ArmyFixture.NO_HEX


func test_a_foreign_or_sea_hex_is_not_shown() -> void:
	var foreign := SupplyView.at(_g, ArmyFixture.TAG, _foreign_land())
	assert_false(bool(foreign.shown), "P: another country's land has no supply line for the player")
	assert_false(bool(SupplyView.at(_g, &"", ArmyFixture.find_town(_g)).shown), "the viewer \"\" has no land to show")


func test_a_depot_is_a_depot() -> void:
	var hex := ArmyFixture.find_town(_g)
	ArmyFixture.town(_g, hex, 3, 20000)
	var s := SupplyView.at(_g, ArmyFixture.TAG, hex)
	assert_true(bool(s.shown))
	assert_eq(s.state, &"depot")
	assert_eq(s.text, SupplyView.DEPOT_TEXT)
	assert_eq(SupplyView.bytes(_g, ArmyFixture.TAG)[_g.map.index_of(hex)], SupplyView.BYTE_DEPOT)


func test_each_owned_hex_matches_the_supply_field_of_its_season() -> void:
	var winter := Calendar.is_winter(_g.turn)
	var bytes := SupplyView.bytes(_g, ArmyFixture.TAG)
	assert_eq(bytes.size(), _g.map.hex_count())
	var checked := 0
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		var mine := _g.map.land[i] == 1 and int(_g.state.owner[i]) == ArmyFixture.id_of(_g, ArmyFixture.TAG)
		if not mine:
			assert_eq(int(bytes[i]), 0, "P: a hex the player does not hold is byte 0")
			continue
		checked += 1
		var b := int(bytes[i])
		assert_true(b >= 1 and b <= 6, "owned land is byte 1 to 6")
		if b == SupplyView.BYTE_IN or b == SupplyView.BYTE_WINTER_CUT:
			assert_true(Supply.in_supply(_g, ArmyFixture.TAG, hex, winter), "in-supply bytes are in the field now")
		if b == SupplyView.BYTE_WINTER_CUT:
			assert_false(winter)
			assert_false(Supply.in_supply(_g, ArmyFixture.TAG, hex, true))
	assert_true(checked > 0)


func test_at_agrees_with_the_byte_of_the_same_hex() -> void:
	var hex := ArmyFixture.find_town(_g)
	var s := SupplyView.at(_g, ArmyFixture.TAG, hex)
	assert_eq(int(SupplyView.bytes(_g, ArmyFixture.TAG)[_g.map.index_of(hex)]) == SupplyView.BYTE_DEPOT, s.state == &"depot")


func test_map_modes_supply_bytes_is_the_same_array() -> void:
	var bytes := MapModes.supply_bytes(_g, ArmyFixture.TAG)
	assert_eq(bytes, SupplyView.bytes(_g, ArmyFixture.TAG))
	assert_eq(MapModes.supply_bytes(_g, ArmyFixture.TAG), bytes, "a second ask is the pinned array")
