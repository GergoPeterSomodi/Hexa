## The one table of player actions (docs/architecture/m1-build-spec.md section 8, m2-build-spec.md section 5.4):
## name -> [check, do]. Each is a static function of (game, args) returning {ok, reason}; `do` checks again and then
## acts. The UI and the AI change the game only through Game.act, which looks the pair up here.
##   build {hex, family, tag}   upgrade {hex, tag}   clear {hex, tag}   cancel_work {hex, tag}   choose_country {tag}
## build, upgrade and clear begin a work (Works); the works phase puts the piece.
class_name Actions
extends RefCounted

const NAMES: Array[String] = ["build", "upgrade", "clear", "cancel_work", "choose_country"]

static var _test_pairs: Dictionary[String, Array] = {}


## [check, do] of an action as Callables, or an empty array for a name that is not an action.
static func pair_of(action: String) -> Array[Callable]:
	match action:
		"build":
			return [Works.build_check, Works.build]
		"upgrade":
			return [Works.upgrade_check, Works.upgrade]
		"clear":
			return [Works.clear_check, Works.clear]
		"cancel_work":
			return [Works.cancel_work_check, Works.cancel_work]
		"choose_country":
			return [Countries.choose_check, Countries.choose]
	if _test_pairs.has(action):
		var raw: Array = _test_pairs[action]
		var typed: Array[Callable] = [raw[0] as Callable, raw[1] as Callable]
		return typed
	return []


## Registers a temporary stub action for OWNS / refusal tests.
static func register_test_action(action: String, check_fn: Callable, do_fn: Callable) -> void:
	_test_pairs[action] = [check_fn, do_fn]


## Clears all temporary stub actions registered by tests.
static func clear_test_actions() -> void:
	_test_pairs.clear()
