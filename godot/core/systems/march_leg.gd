## The walk engine (docs/architecture/moves-build-spec.md D2, R18; split out of MovementPhase by the MV1 refactor, no change in
## behaviour). One MarchLeg is one army's walk: its leg (the steps its stored route takes within its move points: re-plans, the
## closed-pass wait or detour, the wade rule, the zone of control), then its ticks (a step into contact is Battles' engage, a hex
## another country's army stood on is cut, a battle stops the walk), the stack limit (room) and the end (apply: Armies' setters,
## unit_moved, march_halted, the explored steps). MovementPhase walks many of them tick by tick, WalkNow walks one at once (MV4:
## the leg spends the points left, apply writes what is left, R18 to R27); the callers share these rules.
## MV7: the deep-fog step (FogStep, R36: a step onto a hex the country never explored, only fresh, spends fog_step_cost) is a rule
## of the leg; stop on sight (R32 to R35, D6 to D8) is a rule of the ticks: the leg keeps the enemy armies its country did not see
## when the walk began, and a step after which one stands within the army's sight ends the walk (halt sighted, points kept). The
## set depends on the country alone while the legs are made (a leg writes nothing), so the phase makes it once per country.
## MV20: fair warning (FairWarning, R73) is a rule of the ticks too: a step onto the land of a country the walker's country declared
## war on this season is not taken (&"warned": no halt, the points kept, the march stands and goes on next season). The End-turn
## leg (R22a) walks before the calendar, so a war declared this season shuts that land to it too.
## MV19: multi-leg marches (MarchVia, R65): the stops left (`via`) pass as the steps land on them; a walk arrives only on its goal
## with no stop left; a re-plan or a winter detour goes through the next stop, never straight to the goal; apply writes the stops
## left (Armies.set_order, the only writer of Army.via).
## The stack limit (room, and issue #466): room sends a walk back along its path, so a hex keeps a place for every army that
## started on it and walked off: a step onto a battle there counts them, a battle opening there first sends back the walks its
## holder has no room for, a walk sent back never stops on a battle hex it left, and one sent back to its start, where its
## country is now attacked, fights there.
## Luck: none. Integer maths. Armies are written only through Armies; the rules are Movement's and Battles'.
class_name MarchLeg
extends RefCounted

const OWNS: Array[String] = []
## Hexes per country key: index * KEY_STRIDE + country id (country ids are bytes).
const KEY_STRIDE := 256
## The words of a contact refused with no reason given.
const SHUT_TEXT := "the way there is shut"

## One army's walk: its legs, ticks and the room cut, then its end.
var army: Army
var tag: StringName = &""
var cid: int = 0
var start: int = -1
var goal: int = -1
var goal_hex: Vector2i = Vector2i(-1, -1)
var end: int = -1
## The hex indices stepped to this phase, in order (the start not among them).
var walked := PackedInt32Array()
## The tick of each step (1 for the first tick), parallel to walked.
var ticks := PackedInt32Array()
## The stored route after the walked steps (the next step first, the goal last).
var rem := PackedInt32Array()
var status: StringName = &""
var text := ""
var replans: int = 0
## True when the walk ended on a battle hex: Battles took the army in (its order and goal are Battles').
var engaged: bool = false
## Moves in the month (moves-build-spec.md R18, R19, R25): the points the leg could spend, the points spent after each step of
## the leg (parallel to the leg's walked; a cut walk keeps a prefix), the steps of the leg as planned, whether its last step
## stood beside an enemy (the zone of control ends the season), and whether it is an at-once walk (unit_moved's `now`).
var points_start: int = 0
var spent := PackedInt32Array()
var leg_size: int = 0
var zoc: bool = false
var now: bool = false
## Stop on sight (R32 to R34): the armies at war with the walker's country that it did not see when the walk began (the seen set S
## is every other army at war: Sight.sees at the leg's start, the phase's start for the phase), and the walking army's sight.
var unseen: Array[Army] = []
var sight: int = 1
## Multi-leg marches (R65): the stops not yet reached after the walked steps, the next first (Army.via at the start).
var stops_left := PackedInt32Array()
## The End-turn leg (R22a, MovementPhase.next_leg): its ticks count from tick_base + 1 (0 for every other walk).
var tick_base: int = 0


## The leg: the steps the army takes this season by its own rules (no other army counted), a detour or a wait at a closed
## pass (D20), and a re-plan where the next step is blocked or no longer open. A zone of control beside an enemy ends it
## (D21, D40). A walk with no way ends halted (no_way). `points` are the move points the leg may spend (the army's points left);
## -1 is the army's full points. A wade step or a step costing more than the points left is taken only as the first step of a
## fresh army (points equal to its full, R18), and spends all its points. A fog step (FogStep: a hex the country never explored,
## R36) likewise only fresh, spending fog_step_cost; a leg that ends on one, or before one, ends with the status FogStep.WHY.
## `watch` false leaves out the seen set (the preview's legs: an army the viewer sees cannot be newly sighted). `sets` holds
## the seen sets by country (_watch): the caller who plans several legs with no army, sight or war changed between them passes
## one dictionary to all of them (MovementPhase); a leg alone makes its own.
static func leg(game: Game, steps: StepCosts, army: Army, winter: bool, points: int = -1, watch: bool = true,
		sets: Dictionary = {}) -> MarchLeg:
	var m := game.map
	var w := MarchLeg.new()
	w.army = army
	w.tag = army.tag
	w.cid = _cid(game, army.tag)
	w.start = m.index_of(army.hex)
	w.end = w.start
	w.goal_hex = army.goal
	w.goal = m.index_of(army.goal)
	w.rem = army.route.duplicate()
	w.stops_left = army.via.duplicate()
	var full := Movement.mp_of(game, army)
	var mp := points if points >= 0 else full
	w.points_start = mp
	var pts := mp
	var first := mp >= full and full > 0
	var mapped := FogStep.mapped(game, w.tag)
	if watch:
		_watch(game, w, sets)
	while mp > 0 and w.goal >= 0 and not w.arrived():
		var nxt := w.rem[0] if not w.rem.is_empty() else -1
		var d := Movement.direction(m, w.end, nxt) if nxt >= 0 else -1
		var c: int = steps.cost(w.end, d, winter) if d >= 0 else StepCosts.BLOCKED
		var open := c != StepCosts.BLOCKED and Movement.open_step(game, w.tag, m.hex_of(nxt), w.goal_hex)
		if not open:
			if not _reroute(game, w, full):
				return _sized(w)
			continue
		if c == StepCosts.CLOSED:
			var ww := MarchVia.winter_through(game, w.tag, m.hex_of(w.end), w.stops_left, w.goal_hex, full)
			if not bool(ww.ok):
				_no_way(game, w)
				return _sized(w)
			if bool(ww.waits):
				w.status = Movement.WHY_WINTER
				w.text = str(ww.pass_name)
				return _sized(w)
			w.rem = ww.detour as PackedInt32Array
			if not _count_replan(game, w):
				return _sized(w)
			continue
		var foggy := FogStep.is_fog(mapped, nxt)
		if foggy:
			if not first:
				w.status = FogStep.WHY
				break
			pts = FogStep.after(game.defs.fog_step_cost, pts)
		elif c == StepCosts.WADE or c > pts:
			if not first:
				break
			pts = 0
		else:
			pts -= c
		w.walked.append(nxt)
		w.spent.append(mp - pts)
		w.end = nxt
		w.rem = w.rem.slice(1)
		if not w.stops_left.is_empty() and nxt == w.stops_left[0]:
			w.stops_left = w.stops_left.slice(1)  # R65: the stop is passed, the walk goes on
		first = false
		if pts <= 0:
			if foggy:
				w.status = FogStep.WHY
			break
		# D21, D40: a zone of control ends the leg (no halt: the march goes on next season, M6's rule); R25: and the season.
		if not w.arrived() and Movement.zoc_halts(game, w.tag, m.hex_of(nxt)):
			w.zoc = true
			break
	return _sized(w)


## The seen set of a walk (R32): the armies of the countries at war with the walker's that its country does not see now are kept
## (`unseen`), with the walking army's sight (the largest sight of its kinds, as Sight's discs). The set is read from `sets`
## (country tag -> seen_set), made there on the country's first leg: the walks share the array and none of them writes it.
static func _watch(game: Game, w: MarchLeg, sets: Dictionary) -> void:
	if game.wars.is_empty():
		return
	if not sets.has(w.tag):
		sets[w.tag] = seen_set(game, w.tag)
	var found: Dictionary = sets[w.tag]
	if not bool(found.war):
		return
	w.sight = army_sight(game, w.army)
	w.unseen = found.unseen


## What the walks of `tag` watch for now: {war (a country is at war with it), unseen (the armies of those countries on hexes it
## does not see, in the order of game.armies)}.
static func seen_set(game: Game, tag: StringName) -> Dictionary:
	var unseen: Array[Army] = []
	var foes := Wars.enemies(game, tag)
	if not foes.is_empty():
		for a: Army in game.armies:
			if a.hex != Army.NO_HEX and foes.has(a.tag) and not Sight.sees(game, tag, a.hex):
				unseen.append(a)
	return {"war": not foes.is_empty(), "unseen": unseen}


## The sight of an army: the largest sight of its kinds (1 when the defs do not say), the radius of its disc (SightCache.disc).
static func army_sight(game: Game, army: Army) -> int:
	var out := 1
	for u: Unit in army.units:
		var def: UnitDef = game.defs.unit_def(u.kind) if game.defs != null else null
		if def != null:
			out = maxi(out, def.sight)
	return out


static func _sized(w: MarchLeg) -> MarchLeg:
	w.leg_size = w.walked.size()
	return w


## The points the walk has left after the steps it kept (R19): what it could spend less what its kept steps cost.
func points_left() -> int:
	return points_start - (spent[walked.size() - 1] if not walked.is_empty() else 0)


## True when the walk stands on its goal with no stop left to pass (R65).
func arrived() -> bool:
	return goal >= 0 and end == goal and stops_left.is_empty()


## True when the walk's last kept step is the leg's step beside an enemy (R25): its season is over.
func zoc_ended() -> bool:
	return zoc and not walked.is_empty() and walked.size() == leg_size


## Re-plans a walk from its end toward its goal through the stops left (R65) with the season's rules; false (and halted, naming
## the point no leg reaches) when there is no way.
static func _reroute(game: Game, w: MarchLeg, mp: int) -> bool:
	if not _count_replan(game, w):
		return false
	var res := MarchVia.route_through(game, w.tag, game.map.hex_of(w.end), w.stops_left, w.goal_hex, mp)
	if not bool(res.ok):
		_no_way(game, w, res.to as Vector2i)
		return false
	w.rem = res.hexes as PackedInt32Array
	return true


## One more re-plan of a walk; false (and halted) past MAX_REPLANS.
static func _count_replan(game: Game, w: MarchLeg) -> bool:
	w.replans += 1
	if w.replans > Movement.MAX_REPLANS:
		_no_way(game, w)
		return false
	return true


static func _no_way(game: Game, w: MarchLeg, to: Vector2i = Army.NO_HEX) -> void:
	w.status = Movement.WHY_NO_WAY
	w.text = "no way to %s" % Military.hex_text(game, w.goal_hex if to == Army.NO_HEX else to)



## One walk's step k in this tick (see MovementPhase._ticks). A walk whose army is in a battle stops; a contact is Battles' (engage); else the
## step is taken, unless another country's army stood there this phase.
## Stop on sight (R32, R34): after a step taken that opened no battle, an army not in the seen set within the army's sight ends
## the walk there; in the phase the test also runs before the step (an army that walked into its sight in this tick or the last).
## Fair warning (R73) comes before the contact: a hex closed this season is not stepped onto, an enemy army on it or not.
## `walks` are the phase's walks, for the places a battle must leave free (none for a walk alone: no army can come back).
static func step(game: Game, w: MarchLeg, k: int, occ: Dictionary, walks: Array = []) -> void:
	if Battles.of_army(game, w.army.id) != null:
		_stop(game, w, k, Movement.WHY_FOUGHT, "the army is fought in its battle")
		return
	if not w.now and not w.unseen.is_empty():
		var before := spotted(game, w, w.army.hex)
		if before != null:
			_stop(game, w, k, Movement.WHY_SIGHTED, sighted_text(game, before))
			return
	var h: int = w.walked[k]
	var hex := game.map.hex_of(h)
	var closed := FairWarning.enemy_on(game, w.tag, hex)
	if closed != &"":
		_stop(game, w, k, FairWarning.WHY, FairWarning.STOP_TEXT % FairWarning.the_name(game, closed))
		return
	_clear_for_battle(game, w, hex, walks)
	if _contact(game, w, hex):
		var prev := game.map.hex_of(w.start if k == 0 else w.walked[k - 1])
		var full := _places_kept(game, w, hex, walks)
		if full == "" and _engage(game, w, k, prev, hex):
			occ[h] = w.cid
			return
		_refuse(game, w, k, hex, full)
		return
	var held := int(occ.get(h, w.cid))
	if held != w.cid:
		_cut(game, w, k, h, held)
		return
	occ[h] = w.cid
	w.ticks.append(w.tick_base + k + 1)
	var from := w.army.hex
	Armies.set_hex(game, w.army, hex, game.map.hex_of(w.start))
	Movement.index_move(game, w.army, from, hex)
	# R33: a step that arrives ends the walk as arrived (a goal passed with a stop still ahead is no arrival, R65), and a zone
	# of control on the leg's last step wins (points 0, D8).
	if w.unseen.is_empty() or _arrives_on(w, k) or (w.zoc and k == w.leg_size - 1):
		return
	var seen := spotted(game, w, hex)
	if seen != null:
		_sighted(game, w, k, sighted_text(game, seen))


## True when the walk's step k arrives: onto the goal, with every stop passed by then (R65).
static func _arrives_on(w: MarchLeg, k: int) -> bool:
	return w.walked[k] == w.goal and MarchVia.left(w.army.via, w.walked.slice(0, k + 1)).is_empty()


## The first army of the walk's unseen set that stands within its sight of `here` now (in the order the set was made), or null.
## The hex distance is the disc's (SightCache.disc), read from the armies' hexes as they stand at this tick.
static func spotted(game: Game, w: MarchLeg, here: Vector2i) -> Army:
	for a: Army in w.unseen:
		if a.hex != Army.NO_HEX and ImproveRules.hex_distance(a.hex, here) <= w.sight and Armies.by_id(game, a.id) != null:
			return a
	return null


## The words of a halt on sight (R32): the army is in the walker's sight, so its country and its place may be named.
static func sighted_text(game: Game, foe: Army) -> String:
	return "an army of %s came into sight at %s" % [Movement.country_name(game, foe.tag), Military.hex_text(game, foe.hex)]


## The walk ends after its step k (taken): the steps after it go back to the route, halt sighted with `text`.
static func _sighted(game: Game, w: MarchLeg, k: int, text: String) -> void:
	_stop(game, w, k + 1, Movement.WHY_SIGHTED, text)


## True when a step onto hex meets Battles: a battle on it, an army of a country at war with the walk's, or (a storm's walk) the
## hostile garrisoned fortress it goes to.
static func _contact(game: Game, w: MarchLeg, hex: Vector2i) -> bool:
	if Battles.at(game, hex) != null or Movement.enemy_army_at(game, w.tag, hex):
		return true
	return w.army.order == Army.ORDER_STORM and Movement.closed_fortress(game, w.tag, hex)


## Battles' engage for the step k from prev onto hex (the army stands on prev now). True when the army took the step: the walk
## ends on the battle hex, its remaining route kept; false (nothing changed) when Battles refuses it.
static func _engage(game: Game, w: MarchLeg, k: int, prev: Vector2i, hex: Vector2i) -> bool:
	var m := game.map
	var d := Movement.direction(m, m.index_of(prev), m.index_of(hex))
	var edge := m.edge_index(prev, d)
	var from := w.army.hex
	if not Battles.engage(game, w.army, hex, w.tick_base + k + 1, edge):
		return false
	Movement.index_move(game, w.army, from, w.army.hex)
	var back := w.walked.slice(k + 1)
	back.append_array(w.rem)
	w.rem = back
	w.walked = w.walked.slice(0, k + 1)
	w.ticks.append(w.tick_base + k + 1)
	w.end = m.index_of(hex)
	w.engaged = true
	w.status = &""
	w.text = ""
	return true


## A contact refused (by Battles, or for the places kept: `full`, _places_kept's words): the walk stops before the hex. Why:
## battle (a battle of the other side is fought there), shaken (too shaken to attack, 4.7 row 3) or enemy (the enemy holds the
## hex and the attack is refused: room, more than one enemy), with the check's words.
static func _refuse(game: Game, w: MarchLeg, k: int, hex: Vector2i, full: String = "") -> void:
	var check := Battles.engage_check(game, {"army": w.army.id, "hex": hex, "tag": w.tag})
	var text := full if full != "" else str(check.reason)
	if text == "":
		text = SHUT_TEXT
	_stop(game, w, k, refusal_why(game, w.army, hex), text)


## The halt word of a contact refused for `army` on `hex` (R28): battle (a battle of the other side is fought there), shaken (too
## shaken to attack) or enemy (any other refusal). The walk and the preview's leg (FogVerdict.contact) share it.
static func refusal_why(game: Game, army: Army, hex: Vector2i) -> StringName:
	var b := Battles.at(game, hex)
	if b != null and b.attacker != army.tag and b.defender != army.tag:
		return Movement.WHY_BATTLE
	if Armies.morale_of(army) < game.defs.war.attack_morale:
		return Movement.WHY_SHAKEN
	return Movement.WHY_ENEMY


## The walk stops before its step k (into hex h, held by country `held`): blocked, with the words of blocked_text.
static func _cut(game: Game, w: MarchLeg, k: int, h: int, held: int) -> void:
	_stop(game, w, k, Movement.WHY_BLOCKED, blocked_text(game, w.tag, game.map.hex_of(h), held))


## The words of a step not taken onto `hex`, where an army of the country `held` (an id) stands (R24, fog-safe): the holder is
## named only when `tag` sees the hex ("an army of the Duchy of Milan is at Novara (8, 9)"); else "another country's army stands
## at Novara (8, 9)" (Battles.engage_check's words), and the place only when `tag` has discovered it.
static func blocked_text(game: Game, tag: StringName, hex: Vector2i, held: int) -> String:
	var holder := Countries.by_id(game, held)
	if holder != null and Sight.sees(game, tag, hex):
		return "an army of %s is at %s" % [Movement.country_name(game, holder.tag), Military.hex_text(game, hex)]
	var known := Sight.explored(game, tag, hex) or Sight.sees(game, tag, hex)
	return "another country's army stands at %s" % (Military.hex_text(game, hex) if known else "a place you cannot see")


## The walk stops before its step k with why and text: the steps from k on go back to the route, and the army stands on the
## hex of step k - 1 (or its start).
static func _stop(game: Game, w: MarchLeg, k: int, why: StringName, text: String) -> void:
	var back := w.walked.slice(k)
	back.append_array(w.rem)
	w.rem = back
	w.walked = w.walked.slice(0, k)
	w.end = w.walked[k - 1] if k > 0 else w.start
	w.status = why
	w.text = text


## The companies of country `cid` that started on hex index `h` in this phase, walked off it and may be sent back there
## (an army in a battle cannot be); `but` is left out.
static func _left(game: Game, walks: Array, cid: int, h: int, but: MarchLeg = null) -> int:
	var n := 0
	for o: MarchLeg in walks:
		if o != but and o.cid == cid and o.start == h and game.map.index_of(o.army.hex) != h \
				and Battles.of_army(game, o.army.id) == null:
			n += o.army.units.size()
	return n


## "" when the places kept on `hex` for the walk's country leave the army room to fight there, or Battles refuses it anyway;
## else the words of the refusal: the companies there and those that may come back fill the limit.
static func _places_kept(game: Game, w: MarchLeg, hex: Vector2i, walks: Array) -> String:
	var kept := _left(game, walks, w.cid, game.map.index_of(hex), w)
	if kept == 0 or not bool(Battles.engage_check(game, {"army": w.army.id, "hex": hex, "tag": w.tag}).ok):
		return ""
	var limit := Military.stack_limit(game, &"")
	var taken := Armies.units_at(game, w.tag, hex, PackedInt32Array([w.army.id])) + kept
	if taken + w.army.units.size() <= limit:
		return ""
	return "no room: %d of %d companies of yours stand there or may come back" % [taken, limit]


## Before the walk's step opens a battle on `hex`: while the holder's companies there and those that may come back exceed the
## limit, the last of its walks in id order that walked onto the hex goes back (room's rule, at once), so no battle holds
## more than a hex does. Nothing where a battle is fought already, or where the attack is refused.
static func _clear_for_battle(game: Game, w: MarchLeg, hex: Vector2i, walks: Array) -> void:
	if walks.is_empty() or Battles.at(game, hex) != null or not Movement.enemy_army_at(game, w.tag, hex) \
			or not bool(Battles.engage_check(game, {"army": w.army.id, "hex": hex, "tag": w.tag}).ok):
		return
	var holder: StringName = &""
	for a: Army in Movement.armies_on(game, hex):
		if a.tag != w.tag and Wars.at_war(game, w.tag, a.tag):
			holder = a.tag
	var cid := _cid(game, holder)
	var h := game.map.index_of(hex)
	var limit := Military.stack_limit(game, &"")
	while Armies.units_at(game, holder, hex) + _left(game, walks, cid, h) > limit:
		var pick: MarchLeg = null
		for k: int in range(walks.size() - 1, -1, -1):
			var o: MarchLeg = walks[k]
			if o.cid == cid and o.start != h and game.map.index_of(o.army.hex) == h and Battles.of_army(game, o.army.id) == null:
				pick = o
				break
		if pick == null:
			return
		_back_in_the_ticks(game, pick)


## A walk sent back while the ticks run: the steps it has not taken go back on its route, then the taken ones as room sends
## them, and the army (and the phase's index) is moved at once.
static func _back_in_the_ticks(game: Game, w: MarchLeg) -> void:
	var from := w.army.hex
	_stop(game, w, w.ticks.size(), &"", "")
	_send_back(game, w)
	var came := game.map.hex_of(w.start) if not w.walked.is_empty() else Army.NO_HEX
	if w.army.hex != game.map.hex_of(w.end):
		Armies.set_hex(game, w.army, game.map.hex_of(w.end), came)
	Movement.index_move(game, w.army, from, w.army.hex)


## The stack limit at the phase's end (D12, R6 b): while the companies of one country on a hex exceed the limit, the last
## walk in id order ending there steps back along its walk (its route keeps the steps; _send_back). Each step back moves one
## army toward its start, so it ends. An army in a battle stays on its battle hex.
static func room(game: Game, walks: Array, by_id: Dictionary) -> void:
	var limit := Military.stack_limit(game, &"")
	var counts := _counts(game, by_id)
	while true:
		var over := -1
		for w: MarchLeg in walks:
			# The count first: _can_step_back looks through every battle, and few hexes are over (both only read).
			if int(counts.get(_key(w.end, w.cid), 0)) > limit and _can_step_back(game, w):
				over = _key(w.end, w.cid)
				break
		if over < 0:
			break
		var pick: MarchLeg = null
		for k: int in range(walks.size() - 1, -1, -1):
			var w: MarchLeg = walks[k]
			if _key(w.end, w.cid) == over and _can_step_back(game, w):
				pick = w
				break
		if pick == null:
			break
		var units := pick.army.units.size()
		counts[over] = int(counts[over]) - units
		_send_back(game, pick)
		var now_at := _key(pick.end, pick.cid)
		counts[now_at] = int(counts.get(now_at, 0)) + units


## The room cut of a walk alone (WalkNow, R23): the walk's steps kept by room's rule, then the army fallen back into a battle at
## its start when it is sent all the way back (as _send_back). The same as room() with one walk; the preview reads room_kept.
static func room_one(game: Game, w: MarchLeg) -> void:
	if not _can_step_back(game, w):
		return
	var keep := room_kept(game, w.army, w.walked)
	if keep == w.walked.size():
		return
	while w.walked.size() > keep:
		_step_back(w)
	if w.walked.is_empty():
		Battles.fall_back_in(game, w.army, game.map.hex_of(w.start))


## The steps (hex indices, in order) of `army`'s lone walk that the stack limit keeps (room, R23): back from the end while the
## country's companies on the end hex (the army's own counted there, not where it stands) exceed the limit, and on past every hex
## where a battle is fought. Reads the country's own armies (and the battles); the walk (room_one) and MovePreview's leg share it.
static func room_kept(game: Game, army: Army, walked: PackedInt32Array) -> int:
	var limit := Military.stack_limit(game, &"")
	var units := army.units.size()
	var but := PackedInt32Array([army.id])
	var n := walked.size()
	while n > 0 and Armies.units_at(game, army.tag, game.map.hex_of(walked[n - 1]), but) + units > limit:
		n -= 1
		while n > 0 and Battles.at(game, game.map.hex_of(walked[n - 1])) != null:
			n -= 1
	return n


static func _can_step_back(game: Game, w: MarchLeg) -> bool:
	return not w.walked.is_empty() and not w.engaged and Battles.of_army(game, w.army.id) == null


## Sends a walk back one hex, and on past every hex where a battle is fought now (it left before the battle began). Back at
## its start, where its country is attacked, the army takes its place in that battle (Battles.fall_back_in moves it there).
static func _send_back(game: Game, w: MarchLeg) -> void:
	_step_back(w)
	while not w.walked.is_empty() and Battles.at(game, game.map.hex_of(w.end)) != null:
		_step_back(w)
	if w.walked.is_empty():
		Battles.fall_back_in(game, w.army, game.map.hex_of(w.start))


static func _step_back(w: MarchLeg) -> void:
	# A walk stepped back for the stack limit gets no halt and no winter wait (its leg stopped where it no longer stands):
	# its order stays and it resumes next season on its route (spec 4.4, room).
	w.status = &""
	w.text = ""
	var last := w.walked.size() - 1
	var back := w.walked[last]
	w.walked = w.walked.slice(0, last)
	w.ticks = w.ticks.slice(0, last)
	var rem := PackedInt32Array([back])
	rem.append_array(w.rem)
	w.rem = rem
	w.end = w.walked[last - 1] if last > 0 else w.start


## The companies of each country per hex at the phase's end: a walk counts at its end, an army that did not walk at its hex.
static func _counts(game: Game, by_id: Dictionary) -> Dictionary:
	var counts := {}
	for army: Army in game.armies:
		var end := game.map.index_of(army.hex)
		if by_id.has(army.id):
			end = (by_id[army.id] as MarchLeg).end
		var k := _key(end, _cid(game, army.tag))
		counts[k] = int(counts.get(k, 0)) + army.units.size()
	return counts


## Applies the walks in id order: the army's hex (its moved_from), its order and halt, its route, the waiting at a pass;
## then the events of each walk (unit_moved, march_halted) and the explored steps of it. An engaged walk keeps the order that
## Battles set. `memo` holds what the player saw of a hex and the countries that witness it: both read the sight at the phase's
## start, so each hex is read once.
static func apply(game: Game, walks: Array, memo: Dictionary) -> void:
	for w: MarchLeg in walks:
		var army := w.army
		var moved := not w.walked.is_empty()
		w.stops_left = MarchVia.left(army.via, w.walked)  # the steps kept after the ticks and the room cut (R65)
		var arrived := w.arrived()
		var waiting_before := army.waiting
		if moved:
			Armies.set_hex(game, army, game.map.hex_of(w.end), game.map.hex_of(w.start))
		elif army.hex != game.map.hex_of(w.start):
			# The taken steps moved it during the ticks and the room stepped it all the way back: it stands where it started.
			Armies.set_hex(game, army, game.map.hex_of(w.start), Army.NO_HEX)
		if w.engaged:
			Armies.set_route(game, army, w.rem)
		else:
			_apply_orders(game, w, arrived)
		if army.via != w.stops_left and army.goal != Movement.NO_HEX:
			Armies.set_order(game, army, army.order, army.goal, army.route, w.stops_left)  # R65: the stops passed are popped
		# R19, R25, R27: the points its kept steps left; none after a step beside an enemy or into a battle.
		Armies.set_points(game, army, 0 if w.engaged or w.zoc_ended() else w.points_left())
		if moved:
			_emit_moved(game, w, arrived, memo)
			# R10: the steps alone are explored here; the rings of the armies come with the vision phase (Sight.season).
			Sight.see_path(game, w.tag, _hexes(game, w.walked), 0)
		if not w.engaged:
			_emit_halts(game, w, waiting_before)


## The order, halt, route and waiting of a walk that did not end in a battle.
static func _apply_orders(game: Game, w: MarchLeg, arrived: bool) -> void:
	var army := w.army
	if arrived:
		Armies.set_order(game, army, Army.ORDER_HOLD, Movement.NO_HEX, PackedInt32Array())
		Armies.set_halt(game, army, &"", "")
		Armies.set_waiting(game, army, &"")
	elif Movement.HALT_WHYS.has(w.status):
		Armies.set_order(game, army, Army.ORDER_NONE, army.goal, PackedInt32Array(), w.stops_left)  # R65: a halt keeps the stops left
		Armies.set_halt(game, army, w.status, w.text)
		Armies.set_waiting(game, army, &"")
	elif w.status == Movement.WHY_WINTER:
		Armies.set_route(game, army, w.rem)
		Armies.set_waiting(game, army, Movement.WHY_WINTER)
	else:
		Armies.set_route(game, army, w.rem)
		if not w.walked.is_empty() or w.status == FairWarning.WHY:
			Armies.set_halt(game, army, &"", "")
			Armies.set_waiting(game, army, &"")


## march_halted for a walk that halted, or for a winter wait that began this season.
static func _emit_halts(game: Game, w: MarchLeg, waiting_before: StringName) -> void:
	if Movement.HALT_WHYS.has(w.status):
		_emit_halt(game, w, false)
	elif w.status == Movement.WHY_WINTER and waiting_before != Movement.WHY_WINTER:
		_emit_halt(game, w, true)


## unit_moved: the path (the start first), the tick of each step, what the player saw of each hex (1 where seen; all 1 for
## the player's own army or with no player) and the countries that witnessed it (4.11), in country id order.
static func _emit_moved(game: Game, w: MarchLeg, arrived: bool, memo: Dictionary) -> void:
	var path: Array[Vector2i] = [game.map.hex_of(w.start)]
	path.append_array(_hexes(game, w.walked))
	var seen := PackedByteArray()
	var tags := {w.tag: true}
	for h: Vector2i in path:
		var key := game.map.index_of(h)
		if not memo.has(key):
			memo[key] = _read_hex(game, h)
		var read: Array = memo[key]
		seen.append(1 if w.tag == game.player else int(read[0]))
		for t: String in read[1]:
			tags[t] = true
	game.emit({"kind": "unit_moved", "tag": w.tag, "army": w.army.id, "path": path, "ticks": w.ticks, "seen": seen,
		"witnesses": _ordered(game, tags), "arrived": arrived, "why": "march", "now": w.now})


## march_halted: why (no_way, blocked, winter, shaken, battle, enemy), the reason text (a pass's name at a winter wait), whether
## it waits, and the witness of the halt (its own country).
static func _emit_halt(game: Game, w: MarchLeg, waits: bool) -> void:
	game.emit({"kind": "march_halted", "tag": w.tag, "army": w.army.id, "hex": game.map.hex_of(w.end),
		"why": String(w.status), "reason": w.text, "waits": waits, "witnesses": PackedStringArray([String(w.tag)]),
		"name": w.army.name})


## What the player saw of a hex (1 or 0) and the countries whose sight holds it (the actor not among them), at the phase's start.
static func _read_hex(game: Game, h: Vector2i) -> Array:
	var player := game.player
	var mine := 1 if (player == &"" or Sight.sees(game, player, h)) else 0
	return [mine, Sight.witnesses_of(game, h, &"")]


## The tags of a set, in country id order.
static func _ordered(game: Game, tags: Dictionary) -> PackedStringArray:
	var ids: Array[int] = []
	for t: Variant in tags:
		var c := Countries.by_tag(game, StringName(str(t)))
		if c != null:
			ids.append(c.id)
	ids.sort()
	var out := PackedStringArray()
	for id: int in ids:
		out.append(String(Countries.by_id(game, id).tag))
	return out


## The country id holding each army's hex now (occupancy, m6-build-spec R6 a): the phase's start, or an at-once walk's.
static func occupancy(game: Game) -> Dictionary:
	var occ := {}
	for army: Army in game.armies:
		var i := game.map.index_of(army.hex)
		var c := Countries.by_tag(game, army.tag)
		if i >= 0 and c != null:
			occ[i] = c.id
	return occ


static func _hexes(game: Game, indices: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in indices:
		out.append(game.map.hex_of(i))
	return out


static func _cid(game: Game, tag: StringName) -> int:
	var c := Countries.by_tag(game, tag)
	return c.id if c != null else 0


static func _key(index: int, cid: int) -> int:
	return index * KEY_STRIDE + cid
