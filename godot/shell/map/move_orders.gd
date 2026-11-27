## What an army order shows the player before and after it (docs/architecture/moves-build-spec.md R48, R49, R52; D18): the risks
## of a march, a storm or a Continue (MovePreview's), the question about a risky one and the order's toast (MoveWords). MapArmies
## owns one and gives every order through it; the App (WarRequests) sets its settings and callables. With `ask` unset (a scene
## with no App) nothing is asked and the order is given at once. It never changes the game itself: `run` calls the order it is given.
class_name MoveOrders
extends RefCounted

const SETTING := "game/confirm_moves"
const TITLE := "Move the %s?"
const MOVE_LABEL := "Move"
const CANCEL_LABEL := "Cancel"
const BATTLE_RISK := "This opens a battle at %s."
## The question's first line for a march with path points: every point in order, the goal last.
const PATH_LINE := "Path: %s."
const PATH_JOIN := ", then "
const STORM_WORDS := "The %s marches to storm %s%s."
## The toast of an attack whose army did not live through it (MoveWords reads the army after the walk and finds none).
const LOST_WORDS := "The %s attacks at %s: %s."

## The App's settings (game/confirm_moves is read at each order); null reads the shipped default (on).
var settings: Settings = null
## (Screen) -> void: puts the question on the App's stack. Unset: nothing is asked.
var ask: Callable = Callable()
## () -> bool: skips a running live walk (MoveReplay.skip_live). Unset: there is none.
var live_skip: Callable = Callable()


## An order acts: a live walk that is still playing lands first (R49).
func skip_live() -> void:
	if live_skip.is_valid():
		live_skip.call()


## Whether risky moves are asked about.
func wanted() -> bool:
	return settings == null or bool(settings.get_value(SETTING))


## Gives `order` at once, or, for an order with risks while the setting asks, puts the question first: Move gives the order (on
## the next idle frame, once the question has left the screen), Cancel does nothing. True when a question was asked. `path` is
## path_line's, "" for a plain march.
func run(army_name: String, risks: Array[Dictionary], order: Callable, path: String = "") -> bool:
	if risks.is_empty() or not wanted() or not ask.is_valid():
		order.call()
		return false
	ask.call(question(army_name, risks, order, path))
	return true


## "Path: Susa (4, 9), then Pinerolo (4, 10).": the points of a march to `hex` through `via`; "" with no points.
static func path_line(game: Game, via: Array[Vector2i], hex: Vector2i) -> String:
	if via.is_empty():
		return ""
	var places := PackedStringArray()
	for point: Vector2i in via:
		places.append(Words.place(game, point))
	places.append(Words.place(game, hex))
	return PATH_LINE % PATH_JOIN.join(places)


## The question about a risky move: "Move the Army of Turin?", the path of a march with points, one line a risk, "Move" and
## "Cancel".
static func question(army_name: String, risks: Array[Dictionary], order: Callable, path: String = "") -> Confirm:
	var lines: Array = []
	if path != "":
		lines.append(path)
	for risk: Dictionary in risks:
		lines.append(str(risk["text"]))
	var screen := Confirm.make({"title": TITLE % army_name, "lines": lines, "confirm_label": MOVE_LABEL,
		"cancel_label": CANCEL_LABEL})
	screen.chose.connect(func(choice: StringName) -> void:
		if choice == &"confirm":
			order.call_deferred())
	return screen


## The risks of a march of the army to `hex` through the path points `via` (R46, R60: MovePreview.to's, or MovePreview.via's on
## the whole path); none for a refused march (the order then says why).
static func march_risks(game: Game, tag: StringName, army_id: int, hex: Vector2i, via: Array[Vector2i] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var preview := MovePreview.to(game, tag, army_id, hex) if via.is_empty() else MovePreview.via(game, tag, army_id, via, hex)
	if bool((preview["verdict"] as Dictionary).get("ok", false)):
		out.assign(preview["risks"] as Array)
	return out


## The risks of a storm of `hex` that the rules allow (R48): its battle when the assault comes this season (the army stands
## there, or this season's leg reaches it), then the other risks of the walk there.
static func storm_risks(game: Game, tag: StringName, army_id: int, hex: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var army := Armies.by_id(game, army_id)
	if army == null:
		return out
	var leg := MovePreview.leg_of(game, tag, army_id, hex)
	if army.hex == hex or (not (leg["hexes"] as Array).is_empty() and leg["end"] == hex):
		out.append({"kind": MovePreview.RISK_BATTLE, "text": BATTLE_RISK % Words.place(game, hex)})
	for risk: Dictionary in march_risks(game, tag, army_id, hex):
		if StringName(risk["kind"]) != MovePreview.RISK_BATTLE:
			out.append(risk)
	return out


## The risks of Continue: those of the kept march through its kept path points, or of the halted storm it resumes.
static func continue_risks(game: Game, tag: StringName, army_id: int) -> Array[Dictionary]:
	var army := Armies.by_id(game, army_id)
	if army == null:
		var none: Array[Dictionary] = []
		return none
	if army.halt_why == Movement.WHY_STORM:
		return storm_risks(game, tag, army_id, army.goal)
	return march_risks(game, tag, army_id, army.goal, MarchVia.hexes_of(game, army.via))


## The toast of an order's walk ({text, tone}, R52): MoveWords' words, read after the walk. `army_name` is the army's name
## from before the order, for an army that is gone after its battle.
static func words(game: Game, tag: StringName, army_id: int, army_name: String, walk: Dictionary) -> Dictionary:
	var out := MoveWords.of(game, tag, army_id, walk)
	var record := int(walk.get("battle", -1))
	if str(out.get("text", "")) != "" or record < 0:
		return out
	var battle := str(BattleView.of(game, tag, record).get("name", ""))
	var tail := "the " + battle if battle != "" else "a battle"
	return {"text": LOST_WORDS % [army_name, Words.place(game, walk["to"] as Vector2i), tail],
		"tone": MovePreview.TONE_WARN}


## The toast of a storm: "... marches to storm Pavia (10, 9): Even." while it only stands (mustering, no points left: nothing
## walked), else the walk's own words. `odds_word` is the storm's word from before the order, "" for none.
static func storm_words(game: Game, tag: StringName, army_id: int, army_name: String, walk: Dictionary, hex: Vector2i,
		odds_word: String) -> Dictionary:
	var stopped := StringName(walk.get("stopped", &""))
	if stopped != WalkNow.MUSTERING and stopped != WalkNow.NO_POINTS:
		return words(game, tag, army_id, army_name, walk)
	var tail := ": %s" % odds_word if odds_word != "" else ""
	return {"text": STORM_WORDS % [army_name, Words.place(game, hex), tail], "tone": MovePreview.TONE_PLAIN}
