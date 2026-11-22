## The movement phase (docs/architecture/m6-build-spec.md sections 4.4, 5.0 R1, R3, R6, D22 and 5.3; m7-build-spec 4.7, 4.8). Every
## marching army and every storming army (in id order; a mustering one waits) walks one season of its stored route within its move
## points: its leg. Then the walks run tick by tick in army id order. A step into a hex another country's army stood on or passed
## through this phase is not taken (blocked). A step into contact (an army of a country at war with the walk's, a battle on the hex,
## or the fortress of a storm) is Battles' engage: taken, the walk ends on the battle hex; refused, the walk stops before it (shaken,
## battle or blocked). A taken step moves the army at once, so the armies' hexes are true for the later ticks. A walk that would leave
## more than the stack limit of one country on a hex steps back, the last army in id order first, until every hex fits. Then the
## steps are applied through Armies (set_hex, the orders, the halts), each walk emits unit_moved, the halts emit march_halted, the
## explored hexes grow along the walks and the sight is refreshed. Luck: none. Integer maths. Armies are written only through
## Armies; the rules are Movement's and Battles'.
class_name MovementPhase
extends RefCounted

const OWNS: Array[String] = []
## Hexes per country key: index * KEY_STRIDE + country id (country ids are bytes).
const KEY_STRIDE := 256


## One army's walk in this phase: its legs, ticks and the room cut, then its end.
class Walk extends RefCounted:
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


## Walks one season of every marching or storming army (4.4). Called by the movement phase (PHASES) and by the tests.
static func season(game: Game) -> void:
	if game == null or game.map == null or game.defs == null or not game.has_countries():
		return
	Armies.clear_moved(game)
	if game.armies.is_empty():
		return
	var steps := StepCosts.of(game.map, game.defs)
	var winter := Movement.winter_now(game)
	var occ := _occupancy(game)
	Movement.begin_index(game)
	var walks: Array = []
	var by_id: Dictionary = {}
	for army: Army in game.armies:
		if not _walks(army) or army.mustering(game.turn):
			continue
		var w := _leg(game, steps, army, winter)
		walks.append(w)
		by_id[army.id] = w
	_ticks(game, walks, occ)
	Movement.end_index()
	_room(game, walks, by_id)
	_apply(game, walks, {})
	Sight.refresh(game)


## True for the orders that walk: a march, and a storm (it walks to its fortress).
static func _walks(army: Army) -> bool:
	return army.order == Army.ORDER_MARCH or army.order == Army.ORDER_STORM


## The country holding each army's hex at the phase's start (occupancy, R6 a).
static func _occupancy(game: Game) -> Dictionary:
	var occ := {}
	for army: Army in game.armies:
		var i := game.map.index_of(army.hex)
		var c := Countries.by_tag(game, army.tag)
		if i >= 0 and c != null:
			occ[i] = c.id
	return occ


## The leg: the steps the army takes this season by its own rules (no other army counted), a detour or a wait at a closed
## pass (D20), and a re-plan where the next step is blocked or no longer open. A zone of control beside an enemy ends it
## (D21, D40). A walk with no way ends halted (no_way).
static func _leg(game: Game, steps: StepCosts, army: Army, winter: bool) -> Walk:
	var m := game.map
	var w := Walk.new()
	w.army = army
	w.tag = army.tag
	w.cid = _cid(game, army.tag)
	w.start = m.index_of(army.hex)
	w.end = w.start
	w.goal_hex = army.goal
	w.goal = m.index_of(army.goal)
	w.rem = army.route.duplicate()
	var mp := Movement.mp_of(game, army)
	var pts := mp
	var first := true
	while mp > 0 and w.goal >= 0 and w.end != w.goal:
		var nxt := w.rem[0] if not w.rem.is_empty() else -1
		var d := Movement.direction(m, w.end, nxt) if nxt >= 0 else -1
		var c: int = steps.cost(w.end, d, winter) if d >= 0 else StepCosts.BLOCKED
		var open := c != StepCosts.BLOCKED and Movement.open_step(game, w.tag, m.hex_of(nxt), w.goal_hex)
		if not open:
			if not _reroute(game, w, mp):
				return w
			continue
		if c == StepCosts.CLOSED:
			var ww := Movement.winter_at(game, w.tag, m.hex_of(w.end), w.goal_hex, mp)
			if not bool(ww.ok):
				_no_way(game, w)
				return w
			if bool(ww.waits):
				w.status = Movement.WHY_WINTER
				w.text = str(ww.pass_name)
				return w
			w.rem = ww.detour as PackedInt32Array
			if not _count_replan(game, w):
				return w
			continue
		if c == StepCosts.WADE or c > pts:
			if not first:
				break
			pts = 0
		else:
			pts -= c
		w.walked.append(nxt)
		w.end = nxt
		w.rem = w.rem.slice(1)
		first = false
		if pts <= 0:
			break
		# D21, D40: a zone of control ends the leg (no halt: the march goes on next season, M6's rule).
		if nxt != w.goal and Movement.zoc_halts(game, w.tag, m.hex_of(nxt)):
			break
	return w


## Re-plans a walk from its end toward its goal with the season's rules; false (and halted) when there is no way.
static func _reroute(game: Game, w: Walk, mp: int) -> bool:
	if not _count_replan(game, w):
		return false
	var res := Movement.replan(game, w.tag, game.map.hex_of(w.end), w.goal_hex, mp)
	if not bool(res.ok):
		_no_way(game, w)
		return false
	w.rem = res.hexes as PackedInt32Array
	return true


## One more re-plan of a walk; false (and halted) past MAX_REPLANS.
static func _count_replan(game: Game, w: Walk) -> bool:
	w.replans += 1
	if w.replans > Movement.MAX_REPLANS:
		_no_way(game, w)
		return false
	return true


static func _no_way(game: Game, w: Walk) -> void:
	w.status = Movement.WHY_NO_WAY
	w.text = "no way to %s" % Military.hex_text(game, w.goal_hex)


## Tick by tick, in army id order (4.8): a step into a hex another country holds is not taken, the walk is cut there and its
## remaining steps go back on its route (blocked). Taken steps mark the hex for their country (R6 b).
static func _ticks(game: Game, walks: Array, occ: Dictionary) -> void:
	var longest := 0
	for w: Walk in walks:
		longest = maxi(longest, w.walked.size())
	for k: int in longest:
		for w: Walk in walks:
			if w.walked.size() > k:
				_tick(game, w, k, occ)


## One walk's step k in this tick (see _ticks). A walk whose army is in a battle stops; a contact is Battles' (engage); else the
## step is taken, unless another country's army stood there this phase.
static func _tick(game: Game, w: Walk, k: int, occ: Dictionary) -> void:
	if Battles.of_army(game, w.army.id) != null:
		_stop(game, w, k, Movement.WHY_FOUGHT, "the army is fought in its battle")
		return
	var h: int = w.walked[k]
	var hex := game.map.hex_of(h)
	if _contact(game, w, hex):
		var prev := game.map.hex_of(w.start if k == 0 else w.walked[k - 1])
		if _engage(game, w, k, prev, hex):
			occ[h] = w.cid
			return
		_refuse(game, w, k, hex)
		return
	var held := int(occ.get(h, w.cid))
	if held != w.cid:
		_cut(game, w, k, h, held)
		return
	occ[h] = w.cid
	w.ticks.append(k + 1)
	var from := w.army.hex
	Armies.set_hex(game, w.army, hex, game.map.hex_of(w.start))
	Movement.index_move(game, w.army, from, hex)


## True when a step onto hex meets Battles: a battle on it, an army of a country at war with the walk's, or (a storm's walk) the
## hostile garrisoned fortress it goes to.
static func _contact(game: Game, w: Walk, hex: Vector2i) -> bool:
	if Battles.at(game, hex) != null or Movement.enemy_army_at(game, w.tag, hex):
		return true
	return w.army.order == Army.ORDER_STORM and Movement.closed_fortress(game, w.tag, hex)


## Battles' engage for the step k from prev onto hex (the army stands on prev now). True when the army took the step: the walk
## ends on the battle hex, its remaining route kept; false (nothing changed) when Battles refuses it.
static func _engage(game: Game, w: Walk, k: int, prev: Vector2i, hex: Vector2i) -> bool:
	var m := game.map
	var d := Movement.direction(m, m.index_of(prev), m.index_of(hex))
	var edge := m.edge_index(prev, d)
	var from := w.army.hex
	if not Battles.engage(game, w.army, hex, k + 1, edge):
		return false
	Movement.index_move(game, w.army, from, w.army.hex)
	var back := w.walked.slice(k + 1)
	back.append_array(w.rem)
	w.rem = back
	w.walked = w.walked.slice(0, k + 1)
	w.ticks.append(k + 1)
	w.end = m.index_of(hex)
	w.engaged = true
	w.status = &""
	w.text = ""
	return true


## A contact Battles refused: the walk stops before the hex. Why: battle (a battle of the other side is fought there), shaken
## (too shaken to attack, 4.7 row 3) or enemy (the enemy holds the hex and the attack is refused: room, more than one enemy),
## with the check's words.
static func _refuse(game: Game, w: Walk, k: int, hex: Vector2i) -> void:
	var b := Battles.at(game, hex)
	var why := Movement.WHY_ENEMY
	if b != null and b.attacker != w.tag and b.defender != w.tag:
		why = Movement.WHY_BATTLE
	elif Armies.morale_of(w.army) < game.defs.war.attack_morale:
		why = Movement.WHY_SHAKEN
	var check := Battles.engage_check(game, {"army": w.army.id, "hex": hex, "tag": w.tag})
	var text := str(check.reason)
	if text == "":
		text = "the way there is shut"
	_stop(game, w, k, why, text)


## The walk stops before its step k (into hex h, held by country `held`): blocked, the words of the holder.
static func _cut(game: Game, w: Walk, k: int, h: int, held: int) -> void:
	var holder := Countries.by_id(game, held)
	var who := Movement.country_name(game, holder.tag) if holder != null else "another country"
	_stop(game, w, k, Movement.WHY_BLOCKED, "an army of %s is at %s" % [who, Military.hex_text(game, game.map.hex_of(h))])


## The walk stops before its step k with why and text: the steps from k on go back to the route, and the army stands on the
## hex of step k - 1 (or its start).
static func _stop(game: Game, w: Walk, k: int, why: StringName, text: String) -> void:
	var back := w.walked.slice(k)
	back.append_array(w.rem)
	w.rem = back
	w.walked = w.walked.slice(0, k)
	w.end = w.walked[k - 1] if k > 0 else w.start
	w.status = why
	w.text = text


## The stack limit at the phase's end (D12, R6 b): while the companies of one country on a hex exceed the limit, the last
## walk in id order ending there steps back one hex along its walk (its route keeps the step). Each step back moves one army
## toward its start, so it ends. An engaged walk stays on its battle hex.
static func _room(game: Game, walks: Array, by_id: Dictionary) -> void:
	var limit := Military.stack_limit(game, &"")
	var counts := _counts(game, by_id)
	while true:
		var over := -1
		for w: Walk in walks:
			if _can_step_back(w) and int(counts.get(_key(w.end, w.cid), 0)) > limit:
				over = _key(w.end, w.cid)
				break
		if over < 0:
			break
		var pick: Walk = null
		for k: int in range(walks.size() - 1, -1, -1):
			var w: Walk = walks[k]
			if _can_step_back(w) and _key(w.end, w.cid) == over:
				pick = w
				break
		if pick == null:
			break
		_step_back(game, pick, counts)


static func _can_step_back(w: Walk) -> bool:
	return not w.walked.is_empty() and not w.engaged


static func _step_back(game: Game, w: Walk, counts: Dictionary) -> void:
	# A walk stepped back for the stack limit gets no halt and no winter wait (its leg stopped where it no longer stands):
	# its order stays and it resumes next season on its route (spec 4.4, room).
	w.status = &""
	w.text = ""
	var units := w.army.units.size()
	counts[_key(w.end, w.cid)] = int(counts[_key(w.end, w.cid)]) - units
	var last := w.walked.size() - 1
	var back := w.walked[last]
	w.walked = w.walked.slice(0, last)
	w.ticks = w.ticks.slice(0, last)
	var rem := PackedInt32Array([back])
	rem.append_array(w.rem)
	w.rem = rem
	w.end = w.walked[last - 1] if last > 0 else w.start
	var nk := _key(w.end, w.cid)
	counts[nk] = int(counts.get(nk, 0)) + units


## The companies of each country per hex at the phase's end: a walk counts at its end, an army that did not walk at its hex.
static func _counts(game: Game, by_id: Dictionary) -> Dictionary:
	var counts := {}
	for army: Army in game.armies:
		var end := game.map.index_of(army.hex)
		if by_id.has(army.id):
			end = (by_id[army.id] as Walk).end
		var k := _key(end, _cid(game, army.tag))
		counts[k] = int(counts.get(k, 0)) + army.units.size()
	return counts


## Applies the walks in id order: the army's hex (its moved_from), its order and halt, its route, the waiting at a pass;
## then the events of each walk (unit_moved, march_halted) and the explored steps of it. An engaged walk keeps the order that
## Battles set. `memo` holds what the player saw of a hex and the countries that witness it: both read the sight at the phase's
## start, so each hex is read once.
static func _apply(game: Game, walks: Array, memo: Dictionary) -> void:
	for w: Walk in walks:
		var army := w.army
		var moved := not w.walked.is_empty()
		var arrived := w.end == w.goal
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
		if moved:
			_emit_moved(game, w, arrived, memo)
			# R10: the steps alone are explored here; the rings of the armies come with the vision phase (Sight.season).
			Sight.see_path(game, w.tag, _hexes(game, w.walked), 0)
		if not w.engaged:
			_emit_halts(game, w, waiting_before)


## The order, halt, route and waiting of a walk that did not end in a battle.
static func _apply_orders(game: Game, w: Walk, arrived: bool) -> void:
	var army := w.army
	if arrived:
		Armies.set_order(game, army, Army.ORDER_HOLD, Movement.NO_HEX, PackedInt32Array())
		Armies.set_halt(game, army, &"", "")
		Armies.set_waiting(game, army, &"")
	elif Movement.HALT_WHYS.has(w.status):
		Armies.set_order(game, army, Army.ORDER_NONE, army.goal, PackedInt32Array())
		Armies.set_halt(game, army, w.status, w.text)
		Armies.set_waiting(game, army, &"")
	elif w.status == Movement.WHY_WINTER:
		Armies.set_route(game, army, w.rem)
		Armies.set_waiting(game, army, Movement.WHY_WINTER)
	else:
		Armies.set_route(game, army, w.rem)
		if not w.walked.is_empty():
			Armies.set_halt(game, army, &"", "")
			Armies.set_waiting(game, army, &"")


## march_halted for a walk that halted, or for a winter wait that began this season.
static func _emit_halts(game: Game, w: Walk, waiting_before: StringName) -> void:
	if Movement.HALT_WHYS.has(w.status):
		_emit_halt(game, w, false)
	elif w.status == Movement.WHY_WINTER and waiting_before != Movement.WHY_WINTER:
		_emit_halt(game, w, true)


## unit_moved: the path (the start first), the tick of each step, what the player saw of each hex (1 where seen; all 1 for
## the player's own army or with no player) and the countries that witnessed it (4.11), in country id order.
static func _emit_moved(game: Game, w: Walk, arrived: bool, memo: Dictionary) -> void:
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
		"witnesses": _ordered(game, tags), "arrived": arrived, "why": "march"})


## march_halted: why (no_way, blocked, winter, shaken, battle, enemy), the reason text (a pass's name at a winter wait), whether
## it waits, and the witness of the halt (its own country).
static func _emit_halt(game: Game, w: Walk, waits: bool) -> void:
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
