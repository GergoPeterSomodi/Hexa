## Stub hooks and watched games for the M8 hook tests (docs/architecture/m8-build-spec.md 4.2, 9): a hook that gives BBB's
## orders through Game.act (set_tax), one that records its calls, and one that writes a treasury directly (a planted fault).
class_name OrdersFixture
extends RefCounted

const TAG := &"BBB"


## Three set_tax acts a season for BBB, one a step; the last one wins.
class Stub:
	extends OrdersHook
	var calls: Array[String] = []
	var left := 0
	var acts := 0

	func begin(_game: Game) -> void:
		calls.append("begin")
		left = 3

	func step(game: Game) -> bool:
		calls.append("step")
		left -= 1
		var verdict := game.act("set_tax", {"tag": OrdersFixture.TAG, "level": (game.turn + left) % 3})
		if bool(verdict.get("ok", false)):
			acts += 1
		return left <= 0

	func seats() -> int:
		return 1


## The planted fault: writes a treasury directly, not through Game.act.
class Cheat:
	extends OrdersHook

	func step(game: Game) -> bool:
		game.countries[1].treasury += 77
		return true


## A watched fixture game (the pick taken by watch) with a Stub attached.
static func watched() -> Game:
	var g := ScenarioFixture.game()
	assert(g.watch())
	g.orders = Stub.new()
	return g
