## The action log's live feed (docs/architecture/m3-build-spec.md section 6.5): the lines of the chronicle for one viewer.
## It holds the game and the viewer only. `entries` is LogLines.entries over the chronicle, so the live lines and a
## `rebuild` from the same (or a saved and loaded) chronicle are the same lines. `unread` counts the chronicle entries
## that made a line since the log was last read. Shell code: it reads the game and writes nothing to it.
class_name LogFeed
extends RefCounted

var unread: int = 0

var _game: Game = null
var _viewer: StringName = &""


## Starts from the chronicle of `game` (a new game or a load): every line is already read.
func rebuild(game: Game, viewer: StringName) -> void:
	_game = game
	_viewer = viewer
	unread = 0


## Takes one chronicled entry (Events.chronicled, after Game.emit has appended it): unread goes up when it makes a line.
func add(entry: Dictionary) -> void:
	if _game == null or entry.is_empty():
		return
	if LogLines.line_of(_game, entry, _viewer).is_empty():
		return
	unread += 1


## The seasons of the lines for `filter`, newest first (LogLines.entries); none without a game.
func entries(filter: StringName) -> Array[Dictionary]:
	if _game == null:
		return []
	return LogLines.entries(_game, _viewer, filter)


func mark_read() -> void:
	unread = 0


## Drops the game (the game ended): no lines, nothing unread.
func clear() -> void:
	_game = null
	_viewer = &""
	unread = 0


func has_game() -> bool:
	return _game != null


func viewer() -> StringName:
	return _viewer
