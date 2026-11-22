## Two countries' armies never share a hex outside a battle (docs/architecture/m7-build-spec.md 4.14, the `armies` invariant; K24b).
## A battle settles in the battles phase, so at idle a hex holds one country's armies. Every placement that is not a battle's
## walk must refuse or move elsewhere when another country's army stands on the hex: a raise (Military.raise_check), a peace's
## homing of closed land (Wars.end_war) and a beaten side's retreat spot (Battles.retreat_spot). Each case drives the real
## producer; the planted twin is the same case with the other army taken away.
extends GutTest

const SAV := &"SAV"
const MLO := &"MLO"
const TUS := &"TUS"

var _g: Game


func before_each() -> void:
	_g = WarFixture.game()
	Occupation.setup(_g)
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func _id(tag: StringName) -> int:
	return Countries.by_tag(_g, tag).id


## The first land hex of `tag` (owner byte) where `wanted` holds, or NO_HEX.
func _hex_owned_by(tag: StringName, wanted: Callable) -> Vector2i:
	var owner := _id(tag)
	for i: int in _g.map.hex_count():
		if _g.map.land[i] == 1 and int(_g.state.owner[i]) == owner and wanted.call(i):
			return _g.map.hex_of(i)
	return Movement.NO_HEX


## Two different countries' armies on one hex (the armies invariant's test, for the given tags only).
func _shares_involving(tags: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for a: Army in _g.armies:
		if not tags.has(a.tag):
			continue
		for b: Army in _g.armies:
			if b.id != a.id and b.hex == a.hex and b.tag != a.tag:
				out.append("%s and %s share %s" % [a.tag, b.tag, str(a.hex)])
	return out


# --- a raise onto an enemy army --------------------------------------------------------------------------------------------


func test_raise_is_refused_on_a_hex_where_an_enemy_army_stands() -> void:
	var home := _hex_owned_by(SAV, func(i: int) -> bool: return int(_g.state.main_use[i]) == Economy.SETTLEMENTS \
		and int(_g.state.level[i]) >= 1)
	assert_ne(home, Movement.NO_HEX, "Savoy owns a settlement")
	if home == Movement.NO_HEX:
		return
	WarFixture.at_war(_g, SAV, MLO)
	ArmyFixture.army(_g, MLO, home, 0, 1, 0)
	var verdict := Military.raise_check(_g, {"hex": home, "kind": 0, "count": 1, "tag": SAV})
	assert_false(bool(verdict.ok), "a company raised beside an enemy army would share its hex without a battle")
	assert_eq(str(verdict.reason), "another country's army stands at %s" % Military.hex_text(_g, home))


func test_planted_twin_raise_on_the_same_hex_without_the_enemy_is_not_refused_for_it() -> void:
	var home := _hex_owned_by(SAV, func(i: int) -> bool: return int(_g.state.main_use[i]) == Economy.SETTLEMENTS \
		and int(_g.state.level[i]) >= 1)
	if home == Movement.NO_HEX:
		pending("Savoy owns no settlement")
		return
	WarFixture.at_war(_g, SAV, MLO)
	var verdict := Military.raise_check(_g, {"hex": home, "kind": 0, "count": 1, "tag": SAV})
	assert_false(str(verdict.reason).contains("another country's army"), "no enemy army: not refused for that")


# --- a raise never mints men (the men identity, K24b) ------------------------------------------------------------------------


## A settlement of Savoy whose own hex has no people, and whose ring holds one Savoy hex with people that is occupied by Milan
## (at war). The men of that ring hex cannot be levied, so a raise of 500 men there must be refused or fully levied.
func test_a_raise_does_not_count_men_on_an_occupied_ring_hex() -> void:
	var home := _hex_owned_by(SAV, func(i: int) -> bool: return int(_g.state.main_use[i]) == Economy.SETTLEMENTS \
		and int(_g.state.level[i]) >= 1)
	if home == Movement.NO_HEX:
		pending("Savoy owns no settlement")
		return
	var occupied := Movement.NO_HEX
	for d: int in 6:
		var beside := ImproveRules.neighbour(home, d)
		if _g.map.is_land(beside) and Territory.owner_tag(_g, beside) == SAV:
			occupied = beside
			break
	if occupied == Movement.NO_HEX:
		pending("no Savoy ring hex")
		return
	for d: int in 6:
		var beside := ImproveRules.neighbour(home, d)
		if _g.map.is_land(beside):
			_g.state.people[_g.map.index_of(beside)] = 0
	_g.state.people[_g.map.index_of(home)] = 0
	_g.state.people[_g.map.index_of(occupied)] = 200000
	WarFixture.at_war(_g, SAV, MLO)
	WarFixture.set_occupier(_g, occupied, MLO)
	var c := Countries.by_tag(_g, SAV)
	c.treasury = 1000000
	for g: int in c.stock.size():
		c.stock[g] = 1000
	var people_before := _savoy_people()
	var verdict := Military.raise_check(_g, {"hex": home, "kind": 0, "count": 1, "tag": SAV})
	if bool(verdict.ok):
		assert_true(bool(Military.raise(_g, {"hex": home, "kind": 0, "count": 1, "tag": SAV}).ok))
		assert_eq(people_before - _savoy_people(), 500, "a raise takes exactly the men it books: none minted")
	else:
		assert_string_contains(str(verdict.reason), "only", "refused: the hex cannot give 500 men")


func _savoy_people() -> int:
	var total := 0
	var owner := _id(SAV)
	for i: int in _g.map.hex_count():
		if _g.map.land[i] == 1 and int(_g.state.owner[i]) == owner:
			total += int(_g.state.people[i])
	return total


# --- a peace sends closed-land armies home ---------------------------------------------------------------------------------


func test_a_peace_never_sends_an_army_onto_a_hex_of_another_countrys_army() -> void:
	# Savoy's army stands on Milan's land; the war ends in a white peace, so the land is closed to it and it must go home.
	# Every Savoy hex holds a Tuscan army (at war with Savoy), so no own hex is free of another country's army.
	var milan_hex := _hex_owned_by(MLO, func(_i: int) -> bool: return true)
	assert_ne(milan_hex, Movement.NO_HEX, "Milan owns land")
	if milan_hex == Movement.NO_HEX:
		return
	var war := WarFixture.at_war(_g, SAV, MLO)
	ArmyFixture.army(_g, SAV, milan_hex, 0, 2, 0)
	WarFixture.at_war(_g, SAV, TUS)
	for i: int in _g.map.hex_count():
		if _g.map.land[i] == 1 and int(_g.state.owner[i]) == _id(SAV):
			ArmyFixture.army(_g, TUS, _g.map.hex_of(i), 0, 1, 0)
	Wars.end_war(_g, war, &"white", SAV)
	assert_eq(_shares_involving([SAV, MLO] as Array[StringName]), [] as Array[String],
		"no army of Savoy or Milan shares a hex after the peace")


# --- a beaten side's retreat spot -------------------------------------------------------------------------------------------


func test_a_retreat_spot_is_never_a_hex_of_another_countrys_army() -> void:
	var here := _hex_owned_by(SAV, func(i: int) -> bool: return true)
	assert_ne(here, Movement.NO_HEX, "Savoy owns land")
	if here == Movement.NO_HEX:
		return
	var a := ArmyFixture.army(_g, SAV, here, 0, 1, 0)
	var armies: Array[Army] = [a]
	var first := Battles.retreat_spot(_g, SAV, armies, here, false)
	if first == Army.NO_HEX:
		pending("no retreat spot from this hex")
		return
	# A third country at peace with Savoy stands on that spot now (its land is unowned or Savoy's).
	ArmyFixture.army(_g, MLO, first, 0, 1, 0)
	var second := Battles.retreat_spot(_g, SAV, armies, here, false)
	assert_ne(second, first, "a retreat never ends on a hex holding another country's army")
	if second != Army.NO_HEX:
		assert_eq(Armies.at(_g, second).filter(func(x: Army) -> bool: return x.tag != SAV).size(), 0)
