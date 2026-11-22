## The decision queue (docs/architecture/m7-build-spec.md 6.6, B20; m8 spec 4.14, 6.4): what the player must decide before the
## report. A war declared on the player (D44) and a peace that ends a war with the player (M8): one Confirm each, shown in
## DECISIONS (SeasonFlow.decisions_start) or at once when the declaration came while the flow was idle. A war alert is shown
## before a peace alert; otherwise the order pushed. `emptied` follows the last answer, and SeasonFlow then goes on to the
## report. It holds no game state: it reads names through Words and pushes Confirm screens.
class_name DecisionQueue
extends RefCounted

## Emitted after the last queued decision was answered (the flow's decisions_done is connected to it).
signal emptied

const KIND_WAR := &"war_declared"
const KIND_PEACE := &"peace_made"
## The kinds the queue shows; any other kind is dropped when the queue is read.
const KINDS: Array[StringName] = [&"war_declared", &"peace_made"]
const CHOICE_SHOW := &"show"
const CHOICE_REPORT := &"report"
const TITLE := "War!"
const PEACE_TITLE := "Peace"
const RULES_LINE := "Their armies may now enter your land, and yours theirs. Your armies' standing orders decide what they do when attacked."

var _items: Array[Dictionary] = []


## Adds a decision to the back of the queue: {kind, tag (the attacker), target (the player), turn}.
func push(decision: Dictionary) -> void:
	_items.append(decision.duplicate())


## The decision of a chronicle `peace_made` entry (Chronicle.plain form) for the player: {kind, tag (the country that made the
## peace), target (the player), terms, moved (the hexes that change hands), turn}. {} for any other entry, or a peace the
## player made or one that did not end a war with the player.
static func peace_decision(entry: Dictionary, player: StringName) -> Dictionary:
	if str(entry.get("kind", "")) != "peace_made" or player == &"":
		return {}
	var tag := StringName(str(entry.get("tag", "")))
	var target := StringName(str(entry.get("target", "")))
	if target != player or tag == &"" or tag == player:
		return {}
	var moved: Array[Vector2i] = []
	for hex: Variant in entry.get("moved", []) as Array:
		moved.append(hex as Vector2i)
	return {"kind": KIND_PEACE, "tag": tag, "target": target, "terms": StringName(str(entry.get("terms", ""))),
		"moved": moved, "turn": int(entry.get("turn", 0))}


func count() -> int:
	return _items.size()


func clear() -> void:
	_items = []


## Pushes the first queued decision's Confirm onto ctx's stack; false when none is left (or none can be shown). `idle` is
## true when no season is running: the last choice then reads "To the map" (spec 6.6).
func next(ctx: ShellContext, idle: bool = false) -> bool:
	if ctx == null or not (ctx.stack is ScreenStack):
		return false
	_drop_unknown()
	while not _items.is_empty():
		var decision: Dictionary = _items.pop_at(_next_index())
		var confirm := _confirm(decision, idle)
		if confirm == null:
			continue
		confirm.finished.connect(_answered.bind(ctx, idle, StringName(decision.get("tag", &""))))
		(ctx.stack as ScreenStack).push(confirm)
		return true
	return false


## The index of the decision shown next: the first war alert, else the first peace alert, else the first queued (spec 4.14).
func _next_index() -> int:
	for kind: StringName in [KIND_WAR, KIND_PEACE]:
		for i: int in _items.size():
			if StringName(_items[i].get("kind", &"")) == kind:
				return i
	return 0


func _drop_unknown() -> void:
	var kept: Array[Dictionary] = []
	for decision: Dictionary in _items:
		if KINDS.has(StringName(decision.get("kind", &""))):
			kept.append(decision)
	_items = kept


## A choice of a decision's Confirm: Show asks the country panel for the attacker; then the next decision (or `emptied`).
func _answered(choice: StringName, ctx: ShellContext, idle: bool, attacker: StringName) -> void:
	if choice == CHOICE_SHOW:
		ctx.request(&"country", {"tag": attacker})
	if not next(ctx, idle):
		emptied.emit()


## The Confirm of one decision; null for a kind it does not know or with no game.
func _confirm(decision: Dictionary, idle: bool) -> Confirm:
	if Session.game == null:
		return null
	var kind := StringName(decision.get("kind", &""))
	if kind == KIND_PEACE:
		return _peace_confirm(decision, idle)
	if kind != KIND_WAR:
		return null
	var game := Session.game
	var attacker := StringName(decision.get("tag", &""))
	var target := StringName(decision.get("target", &""))
	var lines: Array = [
		"%s has declared war on %s." % [_cap(Words.country_the(game, attacker)), Words.country_the(game, target)],
		RULES_LINE,
	]
	var choices: Array[Dictionary] = _choices(attacker, game, idle)
	return Confirm.ask(TITLE, lines, choices, {"danger": true, "seal_letter": "!", "safe_choice": CHOICE_REPORT})


## The peace alert (spec 4.14): tone bad when the peace takes districts from the player, plain otherwise; its lines per terms.
func _peace_confirm(decision: Dictionary, idle: bool) -> Confirm:
	var game := Session.game
	var tag := StringName(decision.get("tag", &""))
	var terms := StringName(decision.get("terms", &""))
	var moved: Array[Vector2i] = []
	moved.assign(decision.get("moved", []) as Array)
	var lines := _peace_lines(game, tag, terms, moved)
	return Confirm.ask(PEACE_TITLE, lines, _choices(tag, game, idle),
		{"danger": terms == &"take", "safe_choice": CHOICE_REPORT})


## The lines of a peace alert: the land that moves, named by place (Words.place), or the white peace's line; a truce line
## for a yield (spec 4.14, the truce is the one Wars.truce_until gives).
static func _peace_lines(game: Game, tag: StringName, terms: StringName, moved: Array[Vector2i]) -> Array:
	var who := _cap(Words.country_the(game, tag))
	var places: Array[String] = []
	for hex: Vector2i in moved:
		places.append(Words.place(game, hex))
	var names := Words.list(places)
	var lines: Array = []
	if moved.is_empty():
		var rest := ": every district returns to its owner" if terms == &"white" else ""
		lines.append("%s has made peace with you%s." % [who, rest])
	elif terms == &"take":
		lines.append("%s has made peace with you: %s %s theirs." % [who, names, "becomes" if moved.size() == 1 else "become"])
	elif terms == &"yield":
		lines.append("%s has made peace with you: %s %s yours." % [who, names, "becomes" if moved.size() == 1 else "become"])
		var until := Wars.truce_until(game, tag, Session.player_tag())
		if until > 0:
			lines.append("A truce holds until %s." % Calendar.date_text(until, game.start_year))
	else:
		lines.append("%s has made peace with you: every district returns to its owner." % who)
	return lines


## The two choices of a decision's Confirm: Show the country (its panel), then the report (or the map at idle).
static func _choices(tag: StringName, game: Game, idle: bool) -> Array[Dictionary]:
	return [
		{"id": CHOICE_SHOW, "label": "Show %s" % Words.country_the(game, tag), "kind": "secondary", "safe": false},
		{"id": CHOICE_REPORT, "label": "To the map" if idle else "To the report", "kind": "primary", "safe": true},
	]


static func _cap(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)
