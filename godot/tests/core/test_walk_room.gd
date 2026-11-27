## The stack limit when the movement phase opens battles (issue #466; moves-build-spec.md D12, R6 b). Room sends a walk back
## along its path, so a hex a country's army walked out of must keep room for it: an army that comes onto it in the phase
## counts it (MarchLeg's step), a battle opening on a hex first sends back the walks its holder has no room for, and an army
## sent back onto its start, where its country now fights, takes its place in that battle. After the phase every country's
## companies fit every hex, every army of a battle stands on its hex, and every army of a side on a battle hex is in it.
## North Italy, Savoy and Milan at war; the orders are stored with their routes and the phase walks them (id order).
extends GutTest

const SAV := MovesFixture.SAVOY
const MLO := MovesFixture.MILAN
const SIGHT := 6

var _g: Game
## The hex fought over; the Milanese side hex beside it and the hex beyond that one; three hexes beside the first that do not
## touch the Milanese side hex.
var _hex := Army.NO_HEX
var _foe_side := Army.NO_HEX
var _foe_far := Army.NO_HEX
var _away: Array[Vector2i] = []


func before_each() -> void:
	Movement.clear_test_hostility()
	_g = ArmyFixture.game()
	# Long sight for the pikemen (this game's own copy): both sides see the whole scene from the start, so no walk stops on
	# sight and room alone is tested.
	_g.defs.units[0].sight = SIGHT
	WarFixture.at_war(_g, SAV, MLO)
	assert_true(_find_ground(), "ground for the scene")


func after_each() -> void:
	Movement.clear_test_hostility()


## True when both countries may walk on `hex` and it has no walls.
func _free_ground(hex: Vector2i) -> bool:
	return _g.map.index_of(hex) >= 0 and _g.map.is_land(hex) and Occupation.fortress_level(_g, hex) == 0 \
		and Movement.open_to(_g, SAV, hex) and Movement.open_to(_g, MLO, hex)


## True when the step between the two neighbours costs at most `most` points either way (no wade, ridge or closed pass).
func _plain(a: Vector2i, b: Vector2i, most: int = 5) -> bool:
	var m := _g.map
	var steps := StepCosts.of(m, _g.defs)
	for pair: Array in [[a, b], [b, a]]:
		var from: Vector2i = pair[0]
		var to: Vector2i = pair[1]
		var c := steps.cost(m.index_of(from), Movement.direction(m, m.index_of(from), m.index_of(to)), false)
		if c < 1 or c > most:
			return false
	return true


## Finds the five hexes of the header (see the vars) and sets them; false when the map has none.
func _find_ground() -> bool:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if not _free_ground(hex) or Territory.owner_tag(_g, hex) != SAV:
			continue
		for d: int in 6:
			if _fits(hex, d):
				return true
	return false


func _fits(hex: Vector2i, d: int) -> bool:
	var side := _g.map.neighbour(hex, d)
	if not _free_ground(side) or not _plain(hex, side):
		return false
	var away: Array[Vector2i] = []
	for turn: int in [2, 3, 4]:
		var n := _g.map.neighbour(hex, (d + turn) % 6)
		if not _free_ground(n) or not _plain(hex, n) or ImproveRules.hex_distance(n, side) < 2:
			return false
		away.append(n)
	# No fortress holds a walk beside the two hexes (the Milanese walk of two steps goes through the side hex).
	if Movement.zoc_halts(_g, MLO, side) or Movement.zoc_halts(_g, SAV, hex):
		return false
	for e: int in 6:
		var far := _g.map.neighbour(side, e)
		if _free_ground(far) and ImproveRules.hex_distance(far, hex) == 2 and _plain(side, far):
			_hex = hex
			_foe_side = side
			_foe_far = far
			_away = away
			return true
	return false


func _army(tag: StringName, hex: Vector2i, companies: int) -> Army:
	return ArmyFixture.army(_g, tag, hex, 0, companies)


## A march stored with the route given (the goal last); nothing walks.
func _march(a: Army, route: Array[Vector2i]) -> void:
	var path := PackedInt32Array()
	for h: Vector2i in route:
		path.append(_g.map.index_of(h))
	Armies.set_order(_g, a, Army.ORDER_MARCH, route.back(), path)


func _walk() -> void:
	Sight.refresh(_g)
	MovementPhase.season(_g)


## Every hex holds at most the stack limit of one country.
func _assert_room(when: String) -> void:
	for a: Army in _g.armies:
		var n := Armies.units_at(_g, a.tag, a.hex)
		assert_lte(n, Military.stack_limit(_g, a.tag), "%s: %d companies of %s on %s" % [when, n, a.tag, str(a.hex)])


## The battles hold the armies on their hexes: each army of a battle stands there, and each army of a side there is in it.
func _assert_battles() -> void:
	for b: Battle in _g.battles:
		var inside := {}
		for a: Army in Battles.armies_of(_g, b):
			inside[a.id] = true
			assert_eq(a.hex, b.hex, "army %d (%s) of the battle stands on its hex" % [a.id, a.tag])
		for a: Army in Armies.at(_g, b.hex):
			assert_true(inside.has(a.id), "army %d (%s) on the battle hex is in the battle" % [a.id, a.tag])


## The state after the walk, and after the battles are fought: one country a hex and the stack limit.
func _assert_sound() -> void:
	_assert_room("after the walk")
	_assert_battles()
	Battles.season(_g)
	_assert_room("after the battles")
	var holder := {}
	for a: Army in _g.armies:
		assert_eq(holder.get(a.hex, a.tag), a.tag, "one country on %s" % str(a.hex))
		holder[a.hex] = a.tag


## Soak seed 54: an army walks out of a hex that is then attacked; another comes from the full hex it walks to and would join
## the battle; the first has no room at its end and comes back. The one that would join is refused (the places of the army that
## left are kept), and the army that comes back fights.
func test_an_army_sent_back_finds_its_place_kept_on_a_battle_hex() -> void:
	var out := _army(SAV, _hex, 6)
	var holder := _army(SAV, _hex, 2)
	_army(SAV, _away[0], 3)
	var foe := _army(MLO, _foe_side, 1)
	var joiner := _army(SAV, _away[0], 2)
	_march(out, [_away[0]])
	_march(foe, [_hex])
	_march(joiner, [_hex])
	_walk()
	var b := Battles.at(_g, _hex)
	assert_not_null(b, "Milan attacks the hex")
	if b == null:
		return
	assert_eq(out.hex, _hex, "no room at its end: back to its start")
	assert_eq(Battles.of_army(_g, out.id), b, "and it fights there")
	assert_eq(out.order, Army.ORDER_MARCH, "its march stands, as room leaves it")
	assert_eq(Array(out.route), [_g.map.index_of(_away[0])], "with the step on its route")
	assert_eq(Battles.of_army(_g, holder.id), b)
	assert_eq(joiner.hex, _away[0], "the joiner is refused: the places are taken")
	assert_eq(joiner.halt_why, Movement.WHY_ENEMY)
	assert_string_contains(joiner.halt_text, "no room")
	_assert_sound()


## The same with no joiner: the army sent back is not left on the battle hex outside the battle.
func test_an_army_sent_back_onto_its_attacked_start_joins_the_battle() -> void:
	var out := _army(SAV, _hex, 6)
	_army(SAV, _hex, 2)
	_army(SAV, _away[0], 3)
	var foe := _army(MLO, _foe_side, 1)
	_march(out, [_away[0]])
	_march(foe, [_hex])
	_walk()
	var b := Battles.at(_g, _hex)
	assert_not_null(b)
	if b == null:
		return
	assert_eq(out.hex, _hex)
	assert_eq(Battles.of_army(_g, out.id), b, "it takes its place on its side")
	var joined := 0
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == "battle_joined" and int(e["army"]) == out.id:
			joined += 1
	assert_eq(joined, 1, "battle_joined once")
	_assert_sound()


## An army passing onto a full hex is caught there by an attack: it goes back before the battle opens, and is not in it.
func test_a_walk_over_the_room_goes_back_before_a_battle_opens() -> void:
	var passer := _army(SAV, _away[0], 3)
	var holder := _army(SAV, _hex, 6)
	var foe := _army(MLO, _foe_side, 1)
	_march(passer, [_hex, _away[1]])
	_march(foe, [_hex])
	_walk()
	var b := Battles.at(_g, _hex)
	assert_not_null(b)
	if b == null:
		return
	assert_eq(passer.hex, _away[0], "sent back to its start")
	assert_null(Battles.of_army(_g, passer.id), "and not in the battle")
	assert_eq(passer.order, Army.ORDER_MARCH)
	assert_eq(passer.halt_why, &"", "no halt: it goes on next season")
	assert_eq(Array(passer.route), [_g.map.index_of(_hex), _g.map.index_of(_away[1])])
	assert_eq(Battles.of_army(_g, holder.id), b)
	assert_eq(Battles.of_army(_g, foe.id), b)
	_assert_sound()


## A hex walked through is attacked after the army left it: sent back, it goes past the battle to the hex before.
func test_a_walk_sent_back_goes_past_a_battle_opened_behind_it() -> void:
	var through := _army(SAV, _away[0], 6)
	var held := _army(SAV, _away[1], 2)
	_army(SAV, _away[2], 3)
	var foe := _army(MLO, _foe_far, 1)
	_march(through, [_hex, _away[2]])
	_march(held, [_hex])
	_march(foe, [_foe_side, _hex])
	_walk()
	var b := Battles.at(_g, _hex)
	assert_not_null(b, "Milan attacks the hex the second army walked onto")
	if b == null:
		return
	assert_eq(Battles.of_army(_g, held.id), b)
	assert_eq(through.hex, _away[0], "past the battle, to its start")
	assert_null(Battles.of_army(_g, through.id))
	assert_eq(Array(through.route), [_g.map.index_of(_hex), _g.map.index_of(_away[2])])
	_assert_sound()
