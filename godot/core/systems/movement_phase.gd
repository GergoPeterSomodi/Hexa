## The movement phase (docs/architecture/m6-build-spec.md sections 4.4, 5.0 R1, R3, R6, D22 and 5.3; m7-build-spec 4.7, 4.8). Every
## marching army and every storming army (in id order; a mustering one waits) walks one season of its stored route within its move
## points: its leg. Then the walks run tick by tick in army id order. A step into a hex another country's army stood on or passed
## through this phase is not taken (blocked). A step into contact (an army of a country at war with the walk's, a battle on the hex,
## or the fortress of a storm) is Battles' engage: taken, the walk ends on the battle hex; refused, the walk stops before it (shaken,
## battle or blocked). A taken step moves the army at once, so the armies' hexes are true for the later ticks. A walk that would leave
## more than the stack limit of one country on a hex steps back, the last army in id order first, until every hex fits (a
## battle keeps room for the armies that may come back: MarchLeg). Then the
## steps are applied through Armies (set_hex, the orders, the halts), each walk emits unit_moved, the halts emit march_halted, the
## explored hexes grow along the walks and the sight is refreshed. Luck: none. Integer maths. Armies are written only through
## Armies; the rules are Movement's and Battles'. The walk engine itself is MarchLeg (march_leg.gd); this phase plans every leg, runs
## the ticks in id order and keeps the occupancy and the movement index.
## Moves in the month (moves-build-spec.md R5, R22): an order walks its first leg at once (WalkNow); this phase walks the standing
## marches, each with the move points it has left this season (an army with none waits for the End-turn leg).
## The End-turn leg (R22a, GitHub issue 474, owner playtest 2026-11-27): every End turn moves a marching army one leg. The march_on
## phase (after people, before stats: the season's supply, sieges and economy are settled) walks, with next_leg, every standing
## march or storm that took no step in this End turn's movement phase (an army that spent its points at once, a stored order, a
## mustering army that may set out next season) one leg of the NEXT season: its full points, the next season's winter, its
## mustering. The same leg, ticks, room and apply; its battles are fought there and then (Battles.fight_all). The armies it walked
## and those its battles ended are marked &"next" in game.leg_marks, so ready_units keeps their points (Allowance.refill): the
## player redirects them only with what is left. An army that walked its unspent points in the movement phase is marked &"phase"
## and keeps the next season's points whole: one leg each End turn, never two legs of one season. The leg's ticks count from
## NEXT_LEG_TICK (the replay lays it after the phase's walks and retreats: ReplayPlan). It walks in this season, so the report,
## the battle records, the chronicle and the stats show it with this End turn, and fair warning shuts the land of a war declared
## this season to it.
class_name MovementPhase
extends RefCounted

const OWNS: Array[String] = []
## The ticks of the End-turn leg count from here (unit_moved's ticks and the battles' ticks): far past any leg of the movement
## phase and its retreats, so ReplayPlan tells the two apart. An empty tick takes no time in the replay.
const NEXT_LEG_TICK := 1000
## The marks of game.leg_marks (see the header).
const MARK_PHASE := &"phase"
const MARK_NEXT := &"next"


## Walks one season of every marching or storming army (4.4). Called by the movement phase (PHASES) and by the tests. Marks the
## armies whose walk took a step MARK_PHASE (next_leg leaves them alone).
static func season(game: Game) -> void:
	if game == null:
		return
	game.leg_marks = {}
	var walks := _walk(game, func(army: Army) -> bool: return army.points > 0 and not army.mustering(game.turn),
		false, Movement.winter_now(game), 0)
	for w: MarchLeg in walks:
		if not w.walked.is_empty():
			game.leg_marks[w.army.id] = MARK_PHASE


## The End-turn leg (R22a): the march_on phase. Every march or storm order that is not mustering next season, has full points
## above 0 and took no step in this End turn's movement phase walks one leg with the next season's full points and winter; a storm
## standing on its fortress waits for the battles phase (R29). The battles its walks open are fought now. The armies it walked
## and every army of those battles are marked MARK_NEXT (ready_units keeps their points); the MARK_PHASE marks are dropped.
static func next_leg(game: Game) -> void:
	if game == null:
		return
	var done := game.leg_marks
	game.leg_marks = {}
	var next_turn := game.turn + 1
	var pick := func(army: Army) -> bool:
		return not done.has(army.id) and not army.mustering(next_turn) and Allowance.full(game, army) > 0 \
			and not (army.order == Army.ORDER_STORM and army.hex == army.goal)
	Movement.set_ahead(true)
	var walks := _walk(game, pick, true, Movement.winter_now(game), NEXT_LEG_TICK)
	Movement.set_ahead(false)
	for w: MarchLeg in walks:
		game.leg_marks[w.army.id] = MARK_NEXT
	if game.battles.is_empty():
		return
	for b: Battle in game.battles:
		for a: Army in Battles.armies_of(game, b):
			game.leg_marks[a.id] = MARK_NEXT  # R27: the battle ends their next season too
	Battles.fight_all(game)


## Plans the leg of every army with a march or storm order that `pick` takes, with the points it has left (`full` false) or its
## full points (`full`, a fresh army: the next season's), in the `winter` rules; runs the ticks, the room and the apply (which
## writes the points the legs leave), refreshes the sight; returns the walks. `base` is the walks' first tick less one.
static func _walk(game: Game, pick: Callable, full: bool, winter: bool, base: int) -> Array:
	var walks: Array = []
	if game.map == null or game.defs == null or not game.has_countries() or game.armies.is_empty():
		return walks
	var steps := StepCosts.of(game.map, game.defs)
	var occ := _occupancy(game)
	Movement.begin_index(game)
	var by_id: Dictionary = {}
	var seen_sets: Dictionary = {}  # R32: each country's, made once; nothing the sets read changes before the ticks
	for army: Army in game.armies:
		if not _walks(army) or not bool(pick.call(army)):
			continue
		var w := MarchLeg.leg(game, steps, army, winter, Allowance.full(game, army) if full else army.points, true, seen_sets)
		w.tick_base = base
		walks.append(w)
		by_id[army.id] = w
	_ticks(game, walks, occ)
	Movement.end_index()
	MarchLeg.room(game, walks, by_id)
	MarchLeg.apply(game, walks, {})
	Sight.refresh(game)
	return walks


## True for the orders that walk: a march, and a storm (it walks to its fortress).
static func _walks(army: Army) -> bool:
	return army.order == Army.ORDER_MARCH or army.order == Army.ORDER_STORM


## The country holding each army's hex at the phase's start (occupancy, R6 a; MarchLeg.occupancy).
static func _occupancy(game: Game) -> Dictionary:
	return MarchLeg.occupancy(game)


## Tick by tick, in army id order (4.8): a step into a hex another country holds is not taken, the walk is cut there and its
## remaining steps go back on its route (blocked). Taken steps mark the hex for their country (R6 b).
static func _ticks(game: Game, walks: Array, occ: Dictionary) -> void:
	var longest := 0
	for w: MarchLeg in walks:
		longest = maxi(longest, w.walked.size())
	for k: int in longest:
		for w: MarchLeg in walks:
			if w.walked.size() > k:
				MarchLeg.step(game, w, k, occ, walks)
