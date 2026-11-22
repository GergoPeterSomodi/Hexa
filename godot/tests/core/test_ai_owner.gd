## The owner loses a war (docs/architecture/m8-build-spec.md 9, done-when 5 and 6, the duel): Milan's AI alone against a passive Genoa
## (the player's stand-in, every other country standing still; Genoa's own army taken off, as the spec's duel has it) declares on
## Genoa, takes at least one Genoese district and makes a take peace that moves at least one, within 40 seasons. The seasons the
## build gives are pinned: a changed pin means the AI's war changed on purpose (read the table, then move the pin).
extends GutTest

const M := AiFixture.MILAN
const GEN := AiFixture.GENOA
## The war's start_turn, the first season after which Milan holds a Genoese district, the peace's turn and the districts it moved.
const DECLARED := 3
const FIRST_TAKEN := 7
const PEACE_TURN := 15
const MOVED := 1


func _duel() -> Game:
	var g := AiFixture.duel()
	for a: Army in Armies.of_country(g, GEN):
		Armies.remove(g, a)
	return g


## Milan's controlled districts that Genoa owns.
func _held(g: Game) -> int:
	var total := 0
	for i: int in AiKnow.land_of(g, GEN):
		if AiKnow.controller_of(g, g.map.hex_of(i)) == M:
			total += 1
	return total


func _war(g: Game) -> War:
	for w: War in g.wars:
		if (w.a == M and w.b == GEN) or (w.b == M and w.a == GEN):
			return w
	return null


func test_milan_declares_takes_land_and_makes_a_take_peace_within_forty_seasons() -> void:
	var g := _duel()
	var judge := AiJudge.new(g, false)
	judge.attach(g.orders as AiTurn)
	var start := AiKnow.land_of(g, GEN).size()
	var first_taken := 0
	for n: int in 40:
		Season.run(g)
		if first_taken == 0 and _held(g) > 0:
			first_taken = g.turn - 1
	var war := _war(g)
	assert_not_null(war, "Milan declared on Genoa")
	assert_eq(judge.problems, [] as Array[String])
	assert_eq(war.start_turn, DECLARED, "the declaration")
	assert_gt(first_taken, 0, "a Genoese district was taken")
	assert_eq(first_taken, FIRST_TAKEN, "the first district taken")
	assert_false(war.live(), "the war ended")
	assert_eq(war.terms, &"take", "a take peace")
	assert_eq(war.end_turn, PEACE_TURN, "the peace")
	assert_eq(start - AiKnow.land_of(g, GEN).size(), MOVED, "districts the peace moved")
	var kept := 0
	for i: int in AiKnow.land_of(g, M):
		if AiKnow.owner_of(g, g.map.hex_of(i)) == M:
			kept += 1
	assert_gt(kept, 0)


func test_the_duel_is_the_same_twice() -> void:
	var a := _duel()
	var b := _duel()
	for n: int in 16:
		Season.run(a)
		Season.run(b)
	assert_eq(b.digest(), a.digest())
