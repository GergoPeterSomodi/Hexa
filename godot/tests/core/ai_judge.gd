## The counting judge of the AI's acts (docs/architecture/m8-build-spec.md 9, 4.17), independent of the AI's own code: it reads only what
## AiTurn tells it (tag, action, args, verdict, result) and the game. Every act of a seat must have been allowed by its check
## (`verdict.ok`), have succeeded (`result.ok`) and carry the seat's own tag (`args.tag`). With `digests` on, the judge also asks the
## check once more of the game as it stands and fails when that changes `Game.digest()` (a check is a pure question), and counts the
## acts that changed nothing. `problems` holds one line per broken rule; `acts` and `by_action` count the acts judged.
##   judge.attach(hook): hook.judge = on_act.
##   on_act(tag, action, args, verdict, result): the callable of AiTurn.judge.
class_name AiJudge
extends RefCounted

var game: Game = null
var digests := false
var problems: Array[String] = []
var acts := 0
var by_action: Dictionary = {}
var _last := ""


func _init(for_game: Game = null, with_digests: bool = false) -> void:
	game = for_game
	digests = with_digests
	if game != null and digests:
		_last = game.digest()


## Makes the hook tell this judge of every act.
func attach(hook: AiTurn) -> void:
	hook.judge = Callable(self, "on_act")


func on_act(tag: StringName, action: String, args: Dictionary, verdict: Dictionary, result: Dictionary) -> void:
	acts += 1
	by_action[action] = int(by_action.get(action, 0)) + 1
	var label := "%s %s %s" % [tag, action, str(args)]
	if not bool(verdict.get("ok", false)):
		problems.append("act on a check that refused (%s): %s" % [str(verdict.get("reason", "")), label])
	if not bool(result.get("ok", false)):
		problems.append("act that did not succeed (%s): %s" % [str(result.get("reason", "")), label])
	if StringName(str(args.get("tag", ""))) != tag:
		problems.append("act with another seat's tag: %s" % label)
	if digests and game != null:
		var before := game.digest()
		_ask(action, args)
		if game.digest() != before:
			problems.append("a check changed the digest: %s" % label)


## The check asked once more of the game as it stands (a test judge overrides it with a planted impure check).
func _ask(action: String, args: Dictionary) -> void:
	game.check(action, args)
