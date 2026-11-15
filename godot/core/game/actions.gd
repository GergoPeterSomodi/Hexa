## The one table of player actions (docs/architecture/m1-build-spec.md section 8): name -> [check, do]. Each is a
## static function of (game, args) returning {ok, reason}; `do` checks again and then acts. The UI and the AI change
## the game only through Game.act, which looks the pair up here.
##   build   {hex: Vector2i, family: int}    upgrade   {hex: Vector2i}    clear   {hex: Vector2i}
class_name Actions
extends RefCounted

const NAMES: Array[String] = ["build", "upgrade", "clear"]


## [check, do] of an action as Callables, or an empty array for a name that is not an action.
static func pair_of(action: String) -> Array[Callable]:
	match action:
		"build":
			return [Improve.build_check, Improve.build]
		"upgrade":
			return [Improve.upgrade_check, Improve.upgrade]
		"clear":
			return [Improve.clear_check, Improve.clear]
	return []
