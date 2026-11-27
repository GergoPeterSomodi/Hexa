## The walk at once (docs/architecture/moves-build-spec.md R1, R5, R17 to R30, D1, D4, D5, D10 to D13). An accepted march, Continue
## or storm calls walk() after its order is set, inside the same Game.act: the army walks one MarchLeg of its stored route with the
## move points it has left, under the movement phase's rules (MarchLeg: the leg, the steps with the contact and the other-country
## cut, the room cut, the end through Armies with unit_moved `now`, march_halted and the explored steps), then the sight is
## refreshed. A step onto an enemy army (or a storm's fortress) opens the battle, which is fought at once (Battles.fight_now): every
## army of both sides that fought ends its season (R27). An order that cannot walk now (mustering, no points left, a winter wait at
## the first step) is kept as a standing march, which the movement phase walks (R20, R22). Luck: only the fight's, through
## game.luck.world in act order (D23). Integer maths. Armies are written only through Armies.
class_name WalkNow
extends RefCounted

const OWNS: Array[String] = []
## The reasons a walk stops (`stopped`): "" arrived; points: the season's points are spent, the rest of the route stands; room:
## the hex ahead is full of the country's companies, the rest stands; mustering, no_points: nothing walked, the order stands;
## winter: it waits at a closed pass; zoc: it stands beside an enemy and its season is over; battle: a battle was fought (`battle`
## the record id) or, with `battle` -1, a battle of others is fought on the hex ahead; fog: a deep-fog step took the season's
## points, or the next step is one and the army has walked (R36: the rest stands); the halt words of Movement (no_way, blocked,
## shaken, enemy, sighted: an enemy army it did not see when the walk began came into sight, the points kept, R32): the march
## halted; warned: the next hex is land of a country declared war on this season (FairWarning, R73): the points kept, the march
## stands. The seen set of the walk is MarchLeg.leg's (Sight.sees at the act's start), so Continue after a sighted halt walks
## with a new one that holds the army seen (R35).
const ARRIVED := &""
const POINTS := &"points"
const ROOM := &"room"
const MUSTERING := &"mustering"
const NO_POINTS := &"no_points"
const ZOC := &"zoc"
const FOUGHT := &"battle"
const FOG := FogStep.WHY
const SIGHTED := Movement.WHY_SIGHTED


## Walks the army's order now. {steps (taken), from, to (where the army stands after the act; its last hex when it is gone),
## stopped (see above), text (the halt's or the stop's words), points (left), full, standing (a march or storm order is left),
## battle (the record id of a battle fought, -1)}.
static func walk(game: Game, army: Army) -> Dictionary:
	var out := {"steps": 0, "from": army.hex, "to": army.hex, "stopped": ARRIVED, "text": "", "points": army.points,
		"full": Allowance.full(game, army), "standing": _standing(army), "battle": -1}
	if army.mustering(game.turn):
		out["stopped"] = MUSTERING
		return out
	if army.points <= 0:
		out["stopped"] = NO_POINTS
		return out
	if army.order == Army.ORDER_STORM and army.hex == army.goal:
		return _storm_here(game, army, out)
	var w := MarchLeg.leg(game, StepCosts.of(game.map, game.defs), army, Movement.winter_now(game), army.points)
	w.now = true
	var occ := MarchLeg.occupancy(game)
	var k := 0
	while k < w.walked.size():
		MarchLeg.step(game, w, k, occ)
		k += 1
	MarchLeg.room_one(game, w)
	MarchLeg.apply(game, [w], {})
	var battle := Battles.of_army(game, army.id) if w.engaged else null
	if battle != null:
		out["battle"] = Battles.fight_now(game, battle)
	else:
		Sight.refresh(game)
	out["steps"] = w.walked.size()
	out["stopped"] = _why(w)
	out["text"] = _text(game, w)
	return _ended(game, army, out, game.map.hex_of(w.end))


## A storm standing on its fortress with points left: the assault opens and is fought now (R29).
static func _storm_here(game: Game, army: Army, out: Dictionary) -> Dictionary:
	if not Battles.engage(game, army, army.hex, 0, -1):
		out["stopped"] = Movement.WHY_ENEMY
		out["text"] = "the way there is shut"
		return out
	out["battle"] = Battles.fight_now(game, Battles.at(game, army.hex))
	out["stopped"] = FOUGHT
	return _ended(game, army, out, army.hex)


## The walk's stop word (see the header).
static func _why(w: MarchLeg) -> StringName:
	if w.engaged:
		return FOUGHT
	if Movement.HALT_WHYS.has(w.status) or w.status == Movement.WHY_WINTER or w.status == FairWarning.WHY:
		return w.status
	if w.zoc_ended():
		return ZOC
	if w.end == w.goal:
		return ARRIVED
	if w.status == FogStep.WHY:
		return FOG
	if w.walked.size() < w.leg_size:
		return ROOM
	return POINTS


## The words of the stop: the halt's text, the pass of a winter wait, the zone of control's words.
static func _text(game: Game, w: MarchLeg) -> String:
	if w.zoc_ended() and not w.engaged:
		return Movement.zoc_text(game, w.tag, game.map.hex_of(w.end))
	return w.text if not w.engaged else ""


## Fills where the army stands, its points and whether its order stands after the act (a beaten or a lost army included).
static func _ended(game: Game, army: Army, out: Dictionary, last: Vector2i) -> Dictionary:
	var alive := Armies.by_id(game, army.id)
	out["to"] = alive.hex if alive != null else last
	out["points"] = alive.points if alive != null else 0
	out["standing"] = _standing(alive) if alive != null else false
	return out


static func _standing(army: Army) -> bool:
	return army.order == Army.ORDER_MARCH or army.order == Army.ORDER_STORM
