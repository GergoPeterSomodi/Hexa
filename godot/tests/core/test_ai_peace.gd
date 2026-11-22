## The AI's peace (docs/architecture/m8-build-spec.md 4.11, D27, 9): each terms' rule with M7's check, one terms a war a turn, and
## a refusal ends that war's step. Every game has its own definitions (AiFixture.duel); a planted number is set on a duplicate of
## the temperament or of the AI's numbers, never on the shared one. Milan (MLO) is the seat; wars are planted with WarFixture.
extends GutTest

const NOW := 20


## A duel at turn NOW with a war of Milan against its `index`th neighbour begun `age` seasons ago; the brief carries copies of
## the temperament and the AI's numbers with the table's inputs planted.
func _war(age: int, index: int = 0) -> Dictionary:
	var g := AiFixture.duel()
	g.turn = NOW
	var e := AiKnow.neighbours(g, AiFixture.MILAN)[index]
	var w := WarFixture.at_war(g, AiFixture.MILAN, e)
	w.start_turn = NOW - age
	var brief := AiBrief.make(g, AiFixture.MILAN)
	brief.temper = brief.temper.duplicate() as AiTemperDef
	brief.ai = brief.ai.duplicate() as AiDef
	brief.temper.take_score = 3
	brief.temper.tired_seasons = 8
	brief.temper.sue_ratio = 1300
	brief.temper.yield_after = 8
	brief.ai.yield_ratio = 2000
	brief.men = 1000
	brief.treasury = 100
	return {"g": g, "e": e, "brief": brief, "hook": AiTurn.new(), "age": age}


## Sets the score of Milan against `e` to `s` (districts held by one side, the capitals left alone).
func _score(c: Dictionary, s: int) -> void:
	var g := c["g"] as Game
	var winner: StringName = AiFixture.MILAN if s > 0 else c["e"] as StringName
	var loser: StringName = c["e"] if s > 0 else AiFixture.MILAN
	var left := absi(s)
	var home := Countries.by_tag(g, loser).capital
	for i: int in AiKnow.land_of(g, loser):
		var hex := g.map.hex_of(i)
		if left > 0 and hex != home and g.map.is_land(hex):
			WarFixture.set_occupier(g, hex, winner)
			left -= 1
	assert_eq(left, 0, "districts enough to plant the score")
	assert_eq(AiKnow.score(g, AiFixture.MILAN, c["e"] as StringName), s, "the planted score")


## The enemy's banded men as Milan reads them.
func _enemy_men(c: Dictionary, n: int) -> void:
	var g := c["g"] as Game
	var row := PackedInt32Array()
	row.resize(Stats.SERIES.size())
	row[Stats.column("army_men")] = n
	var turn := g.stats.last_turn if g.stats.count > 0 else 1
	g.stats.set_row(g.stats.index_of(c["e"] as StringName), turn, row)
	if g.stats.count == 0:
		g.stats.commit(turn)
	assert_eq(AiKnow.men_of(g, AiFixture.MILAN, c["e"] as StringName), n, "the planted men")


func _terms(c: Dictionary) -> StringName:
	return AiPeace.terms_for(c["g"] as Game, c["brief"] as AiBrief, c["e"] as StringName, NOW - int(c["age"]))


## Runs the step; the acts it did.
func _peace(c: Dictionary) -> Array[Dictionary]:
	var acts: Array[Dictionary] = []
	var hook := c["hook"] as AiTurn
	hook.judge = func(_t: StringName, action: String, args: Dictionary, _v: Dictionary, _r: Dictionary) -> void:
		acts.append({"action": action, "args": args})
	AiPeace.peace(hook, c["g"] as Game, c["brief"] as AiBrief, 0)
	return acts


func _live(c: Dictionary) -> bool:
	return Wars.at_war(c["g"] as Game, AiFixture.MILAN, c["e"] as StringName)


func _refusals(c: Dictionary) -> int:
	return (c["hook"] as AiTurn).refusals()


# ----- take ----------------------------------------------------------------------------------------------------------------


func test_take_when_the_score_reaches_the_temperaments_and_the_check_allows() -> void:
	var c := _war(1)
	_score(c, 3)
	assert_eq(_terms(c), &"take")
	var acts := _peace(c)
	assert_eq(acts.size(), 1)
	assert_eq(acts[0]["args"]["terms"], &"take")
	assert_false(_live(c), "the peace was made")


func test_p_take_below_the_score_is_not_asked() -> void:
	var c := _war(1)
	_score(c, 2)
	assert_eq(_terms(c), &"", "2 < take_score 3")
	assert_eq(_peace(c).size(), 0)
	assert_eq(_refusals(c), 0, "nothing was asked")
	assert_true(_live(c))


func test_take_asked_when_tired_with_any_lead_and_refused_by_the_check_ends_the_war_step() -> void:
	var c := _war(8)
	_score(c, 1)
	assert_eq(_terms(c), &"take", "tired and ahead by 1")
	assert_eq(_peace(c).size(), 0)
	# M7: a score of 1 takes only when the target's men do not exceed the seat's (the duel's neighbours field 4 companies).
	assert_eq(_refusals(c), 1, "one check, one refusal, no second terms")
	assert_true(_live(c))


func test_p_take_not_tired_one_season_short() -> void:
	var c := _war(7)
	_score(c, 1)
	assert_eq(_terms(c), &"")


# ----- white ---------------------------------------------------------------------------------------------------------------


func test_white_when_tired_and_not_ahead() -> void:
	var c := _war(8)
	assert_eq(_terms(c), &"white")
	var acts := _peace(c)
	assert_eq(acts.size(), 1)
	assert_eq(acts[0]["args"]["terms"], &"white")
	assert_false(_live(c))


func test_white_when_outnumbered_and_p_not_when_the_enemy_is_under_the_ratio() -> void:
	var c := _war(5)
	_enemy_men(c, 5000)
	assert_eq(_terms(c), &"white", "5,000 x 1000 > 1,000 x 1300")
	assert_eq(_peace(c).size(), 1)
	var f := _war(5)
	_enemy_men(f, 1000)
	assert_eq(_terms(f), &"", "1,000 x 1000 is not over 1,000 x 1300")


func test_white_when_broke_and_p_not_when_solvent() -> void:
	var c := _war(5)
	(c["brief"] as AiBrief).treasury = -1
	assert_eq(_terms(c), &"white")
	assert_eq(_peace(c).size(), 1)
	var f := _war(5)
	(f["brief"] as AiBrief).treasury = 0
	assert_eq(_terms(f), &"")


func test_p_white_not_when_ahead() -> void:
	var c := _war(8)
	(c["brief"] as AiBrief).treasury = -1
	_score(c, 1)
	assert_ne(_terms(c), &"white", "a lead of 1 is not a white peace's score")


func test_white_too_young_for_the_check_is_refused_once() -> void:
	var c := _war(3)
	(c["brief"] as AiBrief).treasury = -1
	assert_eq(_terms(c), &"white", "the rule picks it")
	assert_eq(_peace(c).size(), 0)
	assert_eq(_refusals(c), 1, "M7 wants 4 seasons of war")
	assert_true(_live(c))


# ----- yield ---------------------------------------------------------------------------------------------------------------


## A war far behind: the score -3, the white rule off (not tired, the sue ratio out of reach, solvent).
func _behind(age: int, s: int = -3) -> Dictionary:
	var c := _war(age)
	var brief := c["brief"] as AiBrief
	brief.temper.tired_seasons = 30
	brief.temper.sue_ratio = 9000
	_score(c, s)
	_enemy_men(c, 5000)
	return c


func test_yield_when_far_behind_for_long_and_heavily_outnumbered() -> void:
	var c := _behind(8)
	assert_eq(_terms(c), &"yield", "5,000 x 1000 > 1,000 x 2000")
	var acts := _peace(c)
	assert_eq(acts.size(), 1)
	assert_eq(acts[0]["args"]["terms"], &"yield")
	assert_false(_live(c), "a yield always passes")


func test_p_yield_is_held_back_by_each_condition() -> void:
	assert_eq(_terms(_behind(7)), &"", "before yield_after")
	var strong := _behind(8)
	(strong["brief"] as AiBrief).ai.yield_ratio = 9000
	assert_eq(_terms(strong), &"", "not outnumbered enough")
	assert_eq(_terms(_behind(8, -2)), &"", "-2 is not far enough behind")


# ----- one terms a war a turn ------------------------------------------------------------------------------------------------


func test_two_wars_are_two_asks_and_a_war_that_asks_nothing_does_not_stop_the_other() -> void:
	var c := _war(1, 0)
	var g := c["g"] as Game
	var second := AiKnow.neighbours(g, AiFixture.MILAN)[1]
	var w := WarFixture.at_war(g, AiFixture.MILAN, second)
	w.start_turn = NOW - 1
	_score(c, 2)
	var other := {"g": g, "e": second, "brief": c["brief"], "hook": c["hook"], "age": 1}
	_score(other, 3)
	var acts := _peace(c)
	assert_eq(acts.size(), 1, "the second war's take was made")
	assert_eq(acts[0]["args"]["target"], second)
	assert_eq(_refusals(c), 0, "2 < take_score: the first war asked nothing")
	assert_true(_live(c))
	assert_false(Wars.at_war(g, AiFixture.MILAN, second))


func test_no_live_war_no_ask() -> void:
	var c := _war(8)
	var g := c["g"] as Game
	var war := War.live_between(g.wars, AiFixture.MILAN, c["e"] as StringName)
	war.end_turn = NOW
	assert_eq(_peace(c).size(), 0)
	assert_eq(_refusals(c), 0)
