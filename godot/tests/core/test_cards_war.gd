## WarCards (docs/architecture/m7-build-spec.md 5.6, 6.3; M7 B23): the hover cards of a battle site and a siege dial. Genoa (GEN)
## is the player. Planted faults (P): a battle no one witnessed has no card; a siege's rate and forecast show to its besieger
## and defender only, never to a country that does not see the hex.
extends GutTest

const SAV := &"SAV"
const MLO := &"MLO"

var _g: Game
var _hex: Vector2i


func before_each() -> void:
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)


## A kept record of Savoy's pikemen against Milan's, fought with a fixed luck stream and the witnesses given.
func _battle(witnesses: PackedStringArray) -> BattleRecord:
	var war := CombatFixture.war()
	var fighters := [CombatFixture.pikemen(101, 0), CombatFixture.pikemen(102, 0), CombatFixture.pikemen(201, 1),
		CombatFixture.knights(202, 1)]
	var input := CombatFixture.input_of(war, fighters, 0, false, false)
	input["attacker"] = String(SAV)
	input["defender"] = String(MLO)
	var rng := Rng.new()
	rng.seed_with(1480)
	var before: int = rng.get_state()
	var out: Dictionary = Combat.fight(war, input, rng)
	var r := BattleRecord.new()
	r.id = _g.next_record_id
	_g.next_record_id += 1
	r.turn = _g.turn
	r.hex = _hex
	r.name = "Battle of Test, 1480"
	r.year = 1480
	r.attacker = SAV
	r.defender = MLO
	r.input = input.duplicate(true)
	r.luck_before = before
	r.frames.assign(out["frames"])
	r.end = out["end"]
	r.witnesses = witnesses
	_g.battle_records.append(r)
	return r


## A siege of hex by besieger, made as the sieges phase would leave it.
func _siege(hex: Vector2i, by: StringName) -> void:
	var s := Siege.new()
	s.hex = hex
	s.besieger = by
	s.progress = 2
	s.seasons = 1
	s.name = "Siege of Test, 1480"
	s.started_turn = _g.turn
	_g.sieges.append(s)


## A fortress that a country at war with Genoa holds: {hex, holder}; {} when none.
func _enemy_fortress() -> Dictionary:
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if Occupation.fortress_level(_g, hex) > 0 and Occupation.controller_tag(_g, hex) == enemy:
			return {"hex": hex, "holder": enemy}
	return {}


func test_site_card_of_a_witnessed_battle_has_its_result_and_totals() -> void:
	var r := _battle(PackedStringArray([String(ArmyFixture.TAG)]))
	var card := WarCards.site(_g, ArmyFixture.TAG, r.id)
	assert_false(card.is_empty(), "the witness reads the battle")
	assert_eq(card.title, "Battle of Test, 1480")
	assert_eq(card.hint, "Click: the battle")
	assert_eq(str((card.lines as Array)[0][0]), str(BattleView.of(_g, ArmyFixture.TAG, r.id).result.text))
	assert_eq((card.lines as Array).size(), 3, "the result and each side's killed and wounded")


func test_planted_unwitnessed_battle_has_no_card() -> void:
	var r := _battle(PackedStringArray())
	assert_true(WarCards.site(_g, &"NOBODY", r.id).is_empty(), "P: a battle no one witnessed has no card")
	assert_false(WarCards.site(_g, SAV, r.id).is_empty(), "a side always reads its battle")


func test_siege_card_shows_rate_and_forecast_to_the_besieger_only() -> void:
	var f := _enemy_fortress()
	assert_false(f.is_empty(), "a fortress of a country at war with Genoa exists")
	_siege(f.hex, ArmyFixture.TAG)
	var card := WarCards.siege(_g, ArmyFixture.TAG, f.hex)
	assert_true(str(card.title).begins_with("Siege of "), str(card.title))
	assert_true(str(card.title).ends_with(": 2 of %d" % Occupation.siege_need(_g, f.hex)), str(card.title))
	assert_eq(str((card.lines as Array)[0][0]), "Each season +%d" % int(SiegeView.at(_g, ArmyFixture.TAG, f.hex).rate))
	var defender := WarCards.siege(_g, f.holder, f.hex)
	assert_true(str((defender.lines as Array)[0][0]).begins_with("Each season +"), "the defender reads the rate too")


func test_planted_siege_is_hidden_from_a_country_that_has_not_discovered_it() -> void:
	var f := _enemy_fortress()
	_siege(f.hex, ArmyFixture.TAG)
	var third := &""
	for c: Country in _g.countries:
		if c.tag == &"" or c.tag == ArmyFixture.TAG or c.tag == f.holder:
			continue
		FogFixture.thin(_g, c.tag, 0)
		if not Knowledge.discovered(_g, c.tag, f.hex):
			third = c.tag
			break
	assert_ne(third, &"", "a country that has not discovered the fortress exists")
	assert_true(WarCards.siege(_g, third, f.hex).is_empty(), "P: an undiscovered siege has no card for a third country")


func test_light_fog_siege_card_names_no_besieger() -> void:
	var f := _enemy_fortress()
	_siege(f.hex, ArmyFixture.TAG)
	var third := &""
	for c: Country in _g.countries:
		if c.tag != &"" and c.tag != ArmyFixture.TAG and c.tag != f.holder and not Knowledge.sees(_g, c.tag, f.hex) \
				and Knowledge.discovered(_g, c.tag, f.hex):
			third = c.tag
			break
	assert_ne(third, &"", "a country that has discovered the fortress but does not see it")
	var card := WarCards.siege(_g, third, f.hex)
	assert_false(card.is_empty(), "a light-fog siege has a card")
	assert_eq(str((card.lines as Array)[0][0]), "Besieged", "P: a light-fog siege card says only Besieged")
	assert_false(str(card.lines).contains(String(ArmyFixture.TAG)), "P: no besieger tag on the light-fog card")
