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
## marches, each with the move points it has left this season (an army with none waits for the next season).
class_name MovementPhase
extends RefCounted

const OWNS: Array[String] = []


## Walks one season of every marching or storming army (4.4). Called by the movement phase (PHASES) and by the tests.
static func season(game: Game) -> void:
	if game == null or game.map == null or game.defs == null or not game.has_countries():
		return
	if game.armies.is_empty():
		return
	var steps := StepCosts.of(game.map, game.defs)
	var winter := Movement.winter_now(game)
	var occ := _occupancy(game)
	Movement.begin_index(game)
	var walks: Array = []
	var by_id: Dictionary = {}
	for army: Army in game.armies:
		if not _walks(army) or army.mustering(game.turn) or army.points <= 0:
			continue
		var w := MarchLeg.leg(game, steps, army, winter, army.points)
		walks.append(w)
		by_id[army.id] = w
	_ticks(game, walks, occ)
	Movement.end_index()
	MarchLeg.room(game, walks, by_id)
	MarchLeg.apply(game, walks, {})
	Sight.refresh(game)


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
