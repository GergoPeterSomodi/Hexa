## One page of the Statesman's Study (docs/architecture/m4-build-spec.md 6.7). The Study shows the page it picked, and asks
## it to refresh with the game and a tag. A row or "look there" in a page calls request([&"look_at", hex]); the Study
## turns that into ctx.request(&"look_at", {hex, select}).
class_name StudyPage
extends VBoxContainer

signal action_requested(action: Array)

@export var page_id: StringName = &""

## The tabs of the page ({id, title, since}); the tabs are hidden until M4.5 and M12.
var tabs: Array[Dictionary] = []


## Refills the page from the game. Subclasses override it; `tag` says why (open, season_ended, ...).
func refresh(_game: Game, _tag: StringName) -> void:
	pass


## Sends an action up to the Study: [&"look_at", hex] or [&"map_mode", mode].
func request(action: Array) -> void:
	action_requested.emit(action)
