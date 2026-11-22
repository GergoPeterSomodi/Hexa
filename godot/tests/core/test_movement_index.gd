## The movement index (M7 B12, the performance fix): the armies by hex that MovementPhase keeps for one phase. A seeded war game
## played with the index and with the plain scans of game.armies gives the same digest after every season (the index changes
## how the phase reads the armies, never what it decides); an index not kept with a move gives a wrong answer (the planted
## fault: a move that skips index_move is seen by no read of that hex).
extends GutTest

const SEASONS := 8
const SEEDS: Array[int] = [1480, 7]
const GEN := &"GEN"


func before_each() -> void:
	Movement.use_index = true


func after_each() -> void:
	Movement.use_index = true
	Movement.end_index()


## Genoa with two armies on its town, and a war declared on a neighbour through the door.
func _game(seed_value: int) -> Game:
	var g := EconomyFixture.game(GEN, false, false, seed_value, false)
	var town := ArmyFixture.find_town(g)
	ArmyFixture.town(g, town)
	ArmyFixture.army(g, GEN, town, 0, 3)
	ArmyFixture.army(g, GEN, town, 0, 2)
	var neighbour := WarFixture.neighbour_of(g, GEN)
	assert_true(bool(g.act("declare_war", {"target": neighbour, "tag": GEN})["ok"]), "the war is declared")
	return g


## Plays SEASONS seasons of random picks for every country; the digest after each season.
func _run(seed_value: int, index_on: bool) -> Array[String]:
	Movement.use_index = index_on
	var g := _game(seed_value)
	var luck := Rng.new()
	luck.seed_with(seed_value)
	var out: Array[String] = []
	for _n: int in SEASONS:
		for c: Country in g.countries:
			for _t: int in 6:
				var pick: Dictionary = RandomPlayer.next(g, c.tag, luck)
				g.act(str(pick["action"]), pick["args"])
		Season.run(g)
		out.append(g.digest())
	return out


func test_the_index_and_the_plain_scans_play_the_same_war_game() -> void:
	for seed_value: int in SEEDS:
		var with_index := _run(seed_value, true)
		var plain := _run(seed_value, false)
		assert_eq(with_index.size(), SEASONS)
		assert_eq(with_index, plain, "every season's digest is equal with the index (seed %d)" % seed_value)


func test_the_index_is_read_for_the_armies_of_a_hex() -> void:
	var g := _game(SEEDS[0])
	var town := ArmyFixture.find_town(g)
	var mine := ArmyFixture.army(g, GEN, town, 0, 2)
	var to := Movement.NO_HEX
	for d: int in 6:
		var n := g.map.neighbour(town, d)
		if g.map.is_land(n):
			to = n
			break
	assert_ne(to, Movement.NO_HEX)
	Movement.begin_index(g)
	assert_true(Movement.armies_on(g, town).has(mine), "the army stands on its town in the index")
	var from := mine.hex
	Armies.set_hex(g, mine, to, from)
	Movement.index_move(g, mine, from, to)
	assert_true(Movement.armies_on(g, to).has(mine), "a move kept in the index is read at its new hex")
	assert_false(Movement.armies_on(g, from).has(mine), "and gone from the old one")
	Movement.end_index()


func test_planted_fault_a_move_not_kept_in_the_index_is_missed() -> void:
	var g := _game(SEEDS[0])
	var town := ArmyFixture.find_town(g)
	var mine := ArmyFixture.army(g, GEN, town, 0, 2)
	var to := Movement.NO_HEX
	for d: int in 6:
		var n := g.map.neighbour(town, d)
		if g.map.is_land(n):
			to = n
			break
	Movement.begin_index(g)
	var from := mine.hex
	Armies.set_hex(g, mine, to, from)
	# No index_move: the index still has the army on its old hex, so the read of the new hex misses it.
	assert_false(Movement.armies_on(g, to).has(mine), "the planted fault is seen")
	Movement.end_index()
