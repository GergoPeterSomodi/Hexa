## The replay's hook (docs/architecture/m8-build-spec.md 4.15, 5.4, D33): plays the records a game logged for its AI, so a
## logged game replays without the AI. Built over the log and the index just after an end_season record: the AI's records
## are the ones up to the first orders_done mark. When another end_season or the log's end comes first (a log from before
## M8, or a season no hook played), there are none. Each is played through Game.act, as it was.
class_name LogOrders
extends "res://core/game/orders_hook.gd"

const MARK := "orders_done"
const SEASON := "end_season"

var _log: Array[Dictionary] = []
var _from := 0
var _next := 0
var _stop := 0
var _index := 0


static func over(log: Array[Dictionary], from_index: int) -> LogOrders:
	var out := LogOrders.new()
	out._log = log
	out._from = maxi(from_index, 0)
	out._next = out._from
	out._stop = out._from
	out._index = out._from
	return out


## Finds the first mark after the start; with an end_season or the log's end first there are no records to play.
func begin(_game: Game) -> void:
	_next = _from
	_stop = _from
	_index = _from
	var i := _from
	while i < _log.size():
		var action := str(_log[i].get("action", ""))
		if action == MARK:
			_stop = i
			_index = i + 1
			return
		if action == SEASON:
			return
		i += 1


## Plays the next record through Game.act; true when no record is left.
func step(game: Game) -> bool:
	if _next < _stop:
		var record := _log[_next]
		_next += 1
		var args: Dictionary = record["args"] if record.get("args") is Dictionary else {}
		game.act(str(record.get("action", "")), args)
	return _next >= _stop


func seats() -> int:
	return 0


func seats_done() -> int:
	return 0


## The record after the mark (where the replay resumes), or the start index when there was none.
func index() -> int:
	return _index


func clear() -> void:
	_next = _stop
