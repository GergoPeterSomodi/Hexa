## The decision queue (docs/architecture/m7-build-spec.md 6.6, B20): what the player must decide before the report. Today that
## is a war declared on the player (D44): one Confirm each, shown in DECISIONS (SeasonFlow.decisions_start) or at once when the
## declaration came while the flow was idle. The queue shows them in the order pushed; `emptied` follows the last answer, and
## SeasonFlow then goes on to the report. It holds no game state: it reads names through Words and pushes Confirm screens.
class_name DecisionQueue
extends RefCounted

## Emitted after the last queued decision was answered (the flow's decisions_done is connected to it).
signal emptied

const KIND_WAR := &"war_declared"
const CHOICE_SHOW := &"show"
const CHOICE_REPORT := &"report"
const TITLE := "War!"
const RULES_LINE := "Their armies may now enter your land, and yours theirs. Your armies' standing orders decide what they do when attacked."

var _items: Array[Dictionary] = []


## Adds a decision to the back of the queue: {kind, tag (the attacker), target (the player), turn}.
func push(decision: Dictionary) -> void:
	_items.append(decision.duplicate())


func count() -> int:
	return _items.size()


func clear() -> void:
	_items = []


## Pushes the first queued decision's Confirm onto ctx's stack; false when none is left (or none can be shown). `idle` is
## true when no season is running: the last choice then reads "To the map" (spec 6.6).
func next(ctx: ShellContext, idle: bool = false) -> bool:
	if ctx == null or not (ctx.stack is ScreenStack):
		return false
	while not _items.is_empty():
		var decision: Dictionary = _items.pop_front()
		var confirm := _confirm(decision, idle)
		if confirm == null:
			continue
		confirm.finished.connect(_answered.bind(ctx, idle, StringName(decision.get("tag", &""))))
		(ctx.stack as ScreenStack).push(confirm)
		return true
	return false


## A choice of a decision's Confirm: Show asks the country panel for the attacker; then the next decision (or `emptied`).
func _answered(choice: StringName, ctx: ShellContext, idle: bool, attacker: StringName) -> void:
	if choice == CHOICE_SHOW:
		ctx.request(&"country", {"tag": attacker})
	if not next(ctx, idle):
		emptied.emit()


## The Confirm of one decision; null for a kind it does not know or with no game.
func _confirm(decision: Dictionary, idle: bool) -> Confirm:
	if StringName(decision.get("kind", &"")) != KIND_WAR or Session.game == null:
		return null
	var game := Session.game
	var attacker := StringName(decision.get("tag", &""))
	var target := StringName(decision.get("target", &""))
	var lines: Array = [
		"%s has declared war on %s." % [_cap(Words.country_the(game, attacker)), Words.country_the(game, target)],
		RULES_LINE,
	]
	var choices: Array[Dictionary] = [
		{"id": CHOICE_SHOW, "label": "Show %s" % Words.country_the(game, attacker), "kind": "secondary", "safe": false},
		{"id": CHOICE_REPORT, "label": "To the map" if idle else "To the report", "kind": "primary", "safe": true},
	]
	return Confirm.ask(TITLE, lines, choices, {"danger": true, "seal_letter": "!", "safe_choice": CHOICE_REPORT})


static func _cap(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)
