## The reads the walks and the battles share (issue 473, speed): the seen sets the movement phase makes once per country
## (MarchLeg.seen_set, MovementPhase), a side's one retreat walk (BattleRetreat.reach_of, has_spot, retreat_path) and
## Battles.of_army. Each is held against a from-scratch reading written here, in a made-up war on north Italy, again after
## armies move, die and the land changes hands. North Italy, the 1480 game (ArmyFixture).
extends GutTest

const SEED := 473
## The wars of the made-up game: Savoy and Genoa against Milan, Milan against Venice.
const PAIRS: Array[Array] = [[&"SAV", &"MLO"], [&"GEN", &"MLO"], [&"MLO", &"VEN"]]
const SIDES: Array[StringName] = [&"SAV", &"GEN", &"MLO", &"VEN", &"MAN"]
const ARMIES_EACH := 7
const RETREAT_HEXES := 40

var _g: Game
var _luck: Rng


func before_each() -> void:
	Movement.clear_test_hostility()
	_g = _game()


func after_each() -> void:
	Movement.clear_test_hostility()


## The war game: ARMIES_EACH armies for each of SIDES on its own land and on the land next to it, every army of a country at
## war given a march toward an enemy.
func _game() -> Game:
	var g := ArmyFixture.game()
	g.turn = 3
	for pair: Array in PAIRS:
		WarFixture.at_war(g, pair[0], pair[1])
	_luck = Rng.new()
	_luck.seed_with(SEED)
	for tag: StringName in SIDES:
		var land := Territory.districts(g, ArmyFixture.id_of(g, tag))
		assert_false(land.is_empty(), "%s holds land" % tag)
		for _n: int in ARMIES_EACH:
			for _try: int in 40:
				var hex := g.map.hex_of(land[_luck.randi_range(0, land.size() - 1)])
				if g.map.is_land(hex) and not Armies.held_by_other(g, tag, hex):
					ArmyFixture.army(g, tag, hex, 0, _luck.randi_range(1, 3))
					break
	Sight.refresh(g)
	_order(g)
	return g


## Every army of a country at war that holds no march gets one toward the first enemy army it can plan to.
func _order(g: Game) -> void:
	for a: Army in g.armies:
		if a.order == Army.ORDER_MARCH or Battles.of_army(g, a.id) != null:
			continue
		for e: Army in g.armies:
			if Wars.at_war(g, a.tag, e.tag) and e.hex != a.hex and MovesFixture.standing(g, a, e.hex):
				break


## The seen set of `army`'s country read from scratch: the armies of every country at war with it, on hexes it does not see,
## in the order of game.armies.
func _unseen_from_scratch(g: Game, army: Army) -> PackedInt32Array:
	var out := PackedInt32Array()
	for other: Army in g.armies:
		var foe := false
		for w: War in g.wars:
			if w.live() and ((w.a == army.tag and w.b == other.tag) or (w.b == army.tag and w.a == other.tag)):
				foe = true
		if foe and other.hex != Army.NO_HEX and not Sight.sees(g, army.tag, other.hex):
			out.append(other.id)
	return out


static func _ids(armies: Array[Army]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for a: Army in armies:
		out.append(a.id)
	return out


## One dictionary for the legs of every army, as the phase makes them: each leg's set and sight equal the from-scratch ones and
## those of a leg made alone, and a country's walks share one set. Returns the ids of every set, for the caller to see change.
func _check_sets(g: Game, when: String) -> Array:
	var steps := StepCosts.of(g.map, g.defs)
	var winter := Movement.winter_now(g)
	var sets: Dictionary = {}
	var by_tag: Dictionary = {}
	var all: Array = []
	var unseen := 0
	var seen_foes := 0
	for a: Army in g.armies:
		var shared := MarchLeg.leg(g, steps, a, winter, a.points, true, sets)
		var alone := MarchLeg.leg(g, steps, a, winter, a.points)
		var want := _unseen_from_scratch(g, a)
		assert_eq(_ids(shared.unseen), want, "%s: army %d of %s" % [when, a.id, a.tag])
		assert_eq(_ids(alone.unseen), want, "%s: alone, army %d" % [when, a.id])
		assert_eq(shared.sight, alone.sight, "%s: the sight of army %d" % [when, a.id])
		assert_eq(shared.walked, alone.walked, "%s: the steps of army %d" % [when, a.id])
		if by_tag.has(a.tag):
			assert_true(is_same(shared.unseen, by_tag[a.tag]) or want.is_empty(), "%s: %s makes its set once" % [when, a.tag])
		elif not want.is_empty():
			by_tag[a.tag] = shared.unseen
		unseen += want.size()
		for e: Army in g.armies:
			if Wars.at_war(g, a.tag, e.tag) and not want.has(e.id):
				seen_foes += 1
		all.append([a.id, want])
	assert_gt(unseen, 0, "%s: some enemy is out of sight" % when)
	assert_gt(seen_foes, 0, "%s: some enemy is in sight" % when)
	return all


## Moves the armies of the odd ids onto land hexes drawn anew.
func _move_some(g: Game) -> void:
	for a: Army in g.armies:
		if a.id % 2 == 0 or Battles.of_army(g, a.id) != null:
			continue
		for _try: int in 200:
			var hex := g.map.hex_of(_luck.randi_range(0, g.map.hex_count() - 1))
			if g.map.is_land(hex) and not Armies.held_by_other(g, a.tag, hex):
				Armies.set_hex(g, a, hex, a.hex)
				Armies.set_order(g, a, Army.ORDER_NONE, Army.NO_HEX, PackedInt32Array())
				break
	Sight.refresh(g)
	g.version += 1


## Removes every third army.
func _kill_some(g: Game) -> void:
	var gone: Array[Army] = []
	for a: Army in g.armies:
		if a.id % 3 == 0:
			gone.append(a)
	assert_false(gone.is_empty(), "armies die")
	for a: Army in gone:
		Armies.remove(g, a)
	Sight.refresh(g)
	g.version += 1


## Gives half of Milan's land to Savoy through the developer's transfer (owners_changed: the land sight is made again).
func _change_owners(g: Game) -> void:
	var land := Territory.districts(g, ArmyFixture.id_of(g, &"MLO"))
	var hexes: Array[Vector2i] = []
	for k: int in range(0, land.size(), 2):
		hexes.append(g.map.hex_of(land[k]))
	assert_gt(g.dev_transfer(hexes, ArmyFixture.id_of(g, &"SAV")), 0, "land changes hands")
	Sight.refresh(g)
	g.version += 1


func test_the_phases_seen_sets_equal_a_reading_from_scratch_after_moves_deaths_and_new_owners() -> void:
	var start := _check_sets(_g, "at the start")
	_move_some(_g)
	var moved := _check_sets(_g, "after moves")
	assert_ne(str(moved), str(start), "the moves change the sets")
	_kill_some(_g)
	var thinned := _check_sets(_g, "after deaths")
	assert_ne(str(thinned), str(moved), "the deaths change the sets")
	_change_owners(_g)
	var owned := _check_sets(_g, "after new owners")
	assert_ne(str(owned), str(thinned), "the new owners change the sets")
	WarFixture.at_war(_g, &"SAV", &"VEN")
	_g.version += 1
	_check_sets(_g, "after a new war")


func test_a_country_at_peace_watches_nothing() -> void:
	var steps := StepCosts.of(_g.map, _g.defs)
	var sets: Dictionary = {}
	for a: Army in _g.armies:
		if a.tag == &"MAN":
			var w := MarchLeg.leg(_g, steps, a, false, a.points, true, sets)
			assert_true(w.unseen.is_empty())
			assert_eq(w.sight, 1, "no war, no sight read")
	assert_false(bool((sets[&"MAN"] as Dictionary).war))


## The movement phase against the same season walked leg by leg with a set of its own for each (no shared dictionary).
func _by_hand(g: Game) -> void:
	var steps := StepCosts.of(g.map, g.defs)
	var winter := Movement.winter_now(g)
	var occ := MarchLeg.occupancy(g)
	Movement.begin_index(g)
	var walks: Array = []
	var by_id: Dictionary = {}
	for a: Army in g.armies:
		if (a.order != Army.ORDER_MARCH and a.order != Army.ORDER_STORM) or a.mustering(g.turn) or a.points <= 0:
			continue
		var w := MarchLeg.leg(g, steps, a, winter, a.points)
		walks.append(w)
		by_id[a.id] = w
	var longest := 0
	for w: MarchLeg in walks:
		longest = maxi(longest, w.walked.size())
	for k: int in longest:
		for w: MarchLeg in walks:
			if w.walked.size() > k:
				MarchLeg.step(g, w, k, occ, walks)
	Movement.end_index()
	MarchLeg.room(g, walks, by_id)
	MarchLeg.apply(g, walks, {})
	Sight.refresh(g)


func test_the_movement_phase_walks_as_legs_with_sets_of_their_own() -> void:
	var twin := _game()
	assert_eq(twin.digest(), _g.digest(), "two equal games")
	var fought := 0
	for season: int in 4:
		for g: Game in [_g, twin]:
			Allowance.refill(g)
			_order(g)
		MovementPhase.season(_g)
		_by_hand(twin)
		assert_eq(twin.digest(), _g.digest(), "season %d: the same state" % season)
		assert_eq(var_to_str(twin.events), var_to_str(_g.events), "season %d: the same events" % season)
		fought += _g.battles.size()
		_check_battles(_g, "season %d" % season)
		for g: Game in [_g, twin]:
			Battles.season(g)
			g.events.clear()
			g.turn += 1
			g.version += 1
	assert_gt(fought, 0, "battles were opened on the way")


## Battles.of_army for every army (and an id no army has) against the battles read one by one, and each battle's two sides.
func _check_battles(g: Game, when: String) -> void:
	var ids: Array[int] = [999999]
	for a: Army in g.armies:
		ids.append(a.id)
	for id: int in ids:
		var want: Battle = null
		for b: Battle in g.battles:
			for key: Variant in b.armies:
				for held: int in b.armies[key]:
					if held == id and want == null:
						want = b
		assert_eq(Battles.of_army(g, id), want, "%s: the battle of army %d" % [when, id])
	for b: Battle in g.battles:
		for tag: StringName in [b.attacker, b.defender]:
			var armies: Array[Army] = []
			for a: Army in Armies.at(g, b.hex):
				if a.tag == tag:
					armies.append(a)
			_check_retreat(g, tag, armies, b.hex, "%s: %s at %s" % [when, tag, b.hex])


## The retreat spot read from scratch: of the hexes the walk reaches, those the side may stop on, the best by controlled land,
## steps, distance from the nearest enemy army and index (retreat_path's words).
func _spot_from_scratch(g: Game, tag: StringName, armies: Array[Army], hex: Vector2i, own_only: bool) -> Vector2i:
	var reach := BattleRetreat.reach_of(g, tag, armies, hex)
	if reach.is_empty():
		return Army.NO_HEX
	var total := 0
	for a: Army in armies:
		total += a.units.size()
	var best := Army.NO_HEX
	var best_rank: Array = []
	for i: int in reach.steps:
		var spot := g.map.hex_of(i)
		var step := int(reach.steps[i])
		var holder := Occupation.controller_tag(g, spot)
		var owner := Territory.owner_tag(g, spot)
		var ok := step >= 1
		var nearest := -1
		for a: Army in g.armies:
			var foe := a.tag != tag and Wars.at_war(g, tag, a.tag)
			if a.hex == spot and a.tag != tag:
				ok = false
			if foe:
				var d := ImproveRules.hex_distance(spot, a.hex)
				nearest = d if nearest < 0 else mini(nearest, d)
		if holder != tag and holder != &"" and Wars.at_war(g, tag, holder) and Occupation.garrison_of(g, spot) > 0 \
				and Occupation.fortress_level(g, spot) > 0:
			ok = false
		if own_only:
			ok = ok and holder == tag
		else:
			ok = ok and (owner == tag or owner == &"" or Wars.at_war(g, tag, owner))
		if not ok or Armies.units_at(g, tag, spot, _ids(armies)) + total > g.defs.stack_limit:
			continue
		var rank: Array = [0 if own_only or holder == tag else 1, step, -maxi(nearest, 0), i]
		if best == Army.NO_HEX or rank < best_rank:
			best = spot
			best_rank = rank
	return best


## retreat_path and has_spot against the from-scratch spot, both kinds of retreat; the walk holds no step onto an enemy army.
func _check_retreat(g: Game, tag: StringName, armies: Array[Army], hex: Vector2i, when: String) -> int:
	var found := 0
	var reach := BattleRetreat.reach_of(g, tag, armies, hex)
	for own: bool in [false, true]:
		var want := _spot_from_scratch(g, tag, armies, hex, own)
		var path := BattleRetreat.retreat_path(g, tag, armies, hex, own)
		var spot: Vector2i = path.back() if not path.is_empty() else Army.NO_HEX
		assert_eq(spot, want, "%s own %s: the spot" % [when, own])
		assert_eq(BattleRetreat.has_spot(g, tag, armies, reach, own), want != Army.NO_HEX, "%s own %s: a spot" % [when, own])
		for h: Vector2i in path:
			for a: Army in Armies.at(g, h):
				assert_false(a.tag != tag and Wars.at_war(g, tag, a.tag), "%s: the walk passes no enemy army" % when)
		if want != Army.NO_HEX:
			found += 1
	return found


## _check_retreat for RETREAT_HEXES armies, each asking for the retreat from its own hex.
func _check_retreats(g: Game, when: String) -> void:
	var found := 0
	for k: int in mini(RETREAT_HEXES, g.armies.size()):
		var a := g.armies[k]
		var armies: Array[Army] = [a]
		found += _check_retreat(g, a.tag, armies, a.hex, "%s: army %d" % [when, a.id])
	assert_gt(found, 0, "%s: some side has a spot" % when)


func test_retreats_equal_a_reading_from_scratch_after_moves_deaths_and_new_owners() -> void:
	_check_retreats(_g, "at the start")
	_move_some(_g)
	_check_retreats(_g, "after moves")
	_kill_some(_g)
	_check_retreats(_g, "after deaths")
	_change_owners(_g)
	_check_retreats(_g, "after new owners")


func test_no_walk_means_no_spot() -> void:
	var none: Array[Army] = []
	var reach := BattleRetreat.reach_of(_g, &"SAV", none, _g.armies[0].hex)
	assert_true(reach.is_empty())
	assert_false(BattleRetreat.has_spot(_g, &"SAV", none, reach, false))
	assert_true(BattleRetreat.retreat_path(_g, &"SAV", none, _g.armies[0].hex, false).is_empty())
