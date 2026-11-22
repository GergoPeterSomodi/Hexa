## The computer's turn (docs/architecture/m8-build-spec.md 4.2, 4.12, 5.5): the OrdersHook of the ai_orders phase. begin makes the
## seats; step runs one bounded step of the current seat's queue (brief, peace, war, works scan x2, works cards, works act, forces,
## one step an army, tax, done); a step may append steps for the same seat (push_step, army_retry). Nothing but the AI's own
## acts changes the game while the turn runs, every step is a pure function of the game and its AI luck, and the queue's
## order is fixed, so the turn is the same stepped one at a time or all at once.
## The hook is not state: not saved, not in the digest. Pure core/ai/ code.
class_name AiTurn
extends "res://core/game/orders_hook.gd"

const BRIEF := &"brief"
const PEACE := &"peace"
const WAR := &"war"
const WORKS_SCAN := &"works_scan"
const WORKS_CARD := &"works_card"
const WORKS_ACT := &"works_act"
const FORCES := &"forces"
const ARMY := &"army"
const TAX := &"tax"
const DONE := &"done"

var enabled := true
## Seats the AI leaves alone (the console's passive countries, the tests').
var passive: Array[StringName] = []
## (tag, action, args, verdict, result) -> void: told of every act (the tests and the soak).
var judge: Callable = Callable()

var _seats: Array[StringName] = []
var _at := 0
var _queue: Array[Dictionary] = []
var _cursor := 0
var _pushed := 0
var _briefs: Dictionary = {}
var _tries: Dictionary = {}
var _steps := 0
var _refusals := 0
var _trace := AiTrace.new()


## The seats of the turn: every living country in id order from index (turn - 1) mod count, except the player and the
## passive tags (every country in an AI-only game); none when the AI is off. A country with no temperament is no seat.
func begin(game: Game) -> void:
	clear()
	if not enabled:
		return
	var alive := AiKnow.living(game)
	if alive.is_empty():
		return
	var start := posmod(AiKnow.turn(game) - 1, alive.size())
	for k: int in alive.size():
		var tag := alive[(start + k) % alive.size()]
		if (game.ai_only or tag != game.player) and not passive.has(tag) and AiPlayers.temper_of(game, tag) != null:
			_seats.append(tag)


## One step of the current seat; true when the turn is over (no seat left).
func step(game: Game) -> bool:
	if _at >= _seats.size():
		return true
	var tag := _seats[_at]
	if _queue.is_empty():
		_queue = _plan(game)
		_cursor = 0
	var current := _queue[_cursor]
	_cursor += 1
	_steps += 1
	_run(game, tag, current["name"] as StringName, int(current["arg"]))
	if current["name"] == DONE or _cursor >= _queue.size():
		_at += 1
		_queue = []
		_cursor = 0
	return _at >= _seats.size()


func seats() -> int:
	return _seats.size()


func seats_done() -> int:
	return _at


func steps_done() -> int:
	return _steps


## Refused checks this turn.
func refusals() -> int:
	return _refusals


## AiKnow.act tells of a refused check.
func refused(tag: StringName, action: String, args: Dictionary, verdict: Dictionary) -> void:
	_refusals += 1
	_trace.line(tag, "refused %s %s: %s" % [action, _text(args), str(verdict.get("reason", ""))])


## AiKnow.act tells of an act done.
func judged(tag: StringName, action: String, args: Dictionary, verdict: Dictionary, result: Dictionary) -> void:
	_trace.line(tag, "did %s %s" % [action, _text(args)])
	if judge.is_valid():
		judge.call(tag, action, args, verdict, result)


## A step's trace line (what it chose and the numbers it chose by).
func note(tag: StringName, text: String) -> void:
	_trace.line(tag, text)


func brief_of(tag: StringName) -> AiBrief:
	return _briefs.get(tag) as AiBrief


func trace_of(tag: StringName) -> PackedStringArray:
	return _trace.of(tag)


## Drops the turn.
func clear() -> void:
	_seats = []
	_at = 0
	_queue = []
	_cursor = 0
	_pushed = 0
	_briefs = {}
	_tries = {}
	_steps = 0
	_refusals = 0
	_trace.clear()


## Appends a step for the current seat right after the running one (several pushed by one step keep their order).
func push_step(step_name: StringName, arg: int) -> void:
	_queue.insert(mini(_cursor + _pushed, _queue.size()), {"name": step_name, "arg": arg})
	_pushed += 1


## An army's refused march: one more army step for it, until it has had the game's order_tries a season. True when appended.
func army_retry(game: Game, tag: StringName, army_id: int) -> bool:
	if int(_tries.get(_key(tag, army_id), 0)) >= game.defs.ai.order_tries:
		return false
	push_step(ARMY, army_id)
	return true


func _key(tag: StringName, army_id: int) -> String:
	return "%s:%d" % [tag, army_id]


func _plan(game: Game) -> Array[Dictionary]:
	var out: Array[Dictionary] = [_row(BRIEF, 0), _row(PEACE, 0), _row(WAR, 0), _row(WORKS_SCAN, 0), _row(WORKS_SCAN, 1)]
	for k: int in game.defs.ai.works_cards:
		out.append(_row(WORKS_CARD, k))
	out.append_array([_row(WORKS_ACT, 0), _row(FORCES, 0), _row(TAX, 0), _row(DONE, 0)])
	return out


func _row(step_name: StringName, arg: int) -> Dictionary:
	return {"name": step_name, "arg": arg}


func _run(game: Game, tag: StringName, step_name: StringName, arg: int) -> void:
	_pushed = 0
	if step_name != ARMY:
		_trace.line(tag, "%s %d" % [step_name, arg])
	if step_name == BRIEF:
		_briefs[tag] = AiBrief.make(game, tag)
		return
	var brief := _briefs.get(tag) as AiBrief
	if brief == null or step_name == DONE:
		return
	# The hook as a Variant: tools/check_scripts.gd parses a copy without its class_name, whose self is not an AiTurn.
	var hook: Variant = self
	match step_name:
		PEACE:
			AiPeace.peace(hook, game, brief, arg)
		WAR:
			AiWar.war(hook, game, brief, arg)
		WORKS_SCAN:
			AiEconomy.works_scan(hook, game, brief, arg)
		WORKS_CARD:
			AiEconomy.works_card(hook, game, brief, arg)
		WORKS_ACT:
			AiEconomy.works_act(hook, game, brief, arg)
		FORCES:
			AiForces.forces(hook, game, brief, arg)
		TAX:
			AiEconomy.tax(hook, game, brief, arg)
		ARMY:
			_tries[_key(tag, arg)] = int(_tries.get(_key(tag, arg), 0)) + 1
			var at_war := not AiKnow.enemies(game, tag).is_empty()
			_trace.line(tag, "army %d %s" % [arg, "war" if at_war else "peace"])
			if not at_war:
				AiForces.peace_army(hook, game, brief, arg)
			else:
				AiWar.war_army(hook, game, brief, arg)


static func _text(args: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: Variant in args:
		if str(key) != "tag":
			parts.append("%s=%s" % [key, args[key]])
	return " ".join(parts)
