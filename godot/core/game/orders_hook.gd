## Who gives the other countries' orders in the ai_orders phase (docs/architecture/m8-build-spec.md 4.2, 5.4, D3, D4): the
## season drives a hook in three calls (Season.orders_begin, orders_step, orders_end). The base hook does nothing and is
## done at once; the AI's AiTurn and the replay's LogOrders extend it. A hook is not state: not saved, not in the digest.
class_name OrdersHook
extends RefCounted


## Starts the turn: the seats, from the game as it is now. Base: nothing.
func begin(_game: Game) -> void:
	pass


## One step of the turn; true when the turn is over. Base: true.
func step(_game: Game) -> bool:
	return true


## How many seats this turn has, and how many are done. Base: 0 and 0.
func seats() -> int:
	return 0


func seats_done() -> int:
	return 0


## Drops the turn (the game ended mid-turn). Base: nothing.
func clear() -> void:
	pass
