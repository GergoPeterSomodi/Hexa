## Context object owned by the App and passed to screens and the HUD
## (docs/architecture/ui-and-controls-spec.md section 3.2). Screens read game state via Session
## and ask the App for app-level operations (toasts, quit, main menu, sandbox, fullscreen, screenshot,
## look_at) through this context rather than reaching the App or World by node path.
class_name ShellContext
extends RefCounted

signal toast_requested(text: String, tone: StringName)
signal app_requested(what: StringName, args: Dictionary)
## The App has tried a save (request &"save"): the slot and the problem ("" when it worked). Save and Load refreshes.
signal saved(slot: String, problem: String)
## The top bar's height changed (a resize, a country chosen): screens under it re-read top_inset().
signal top_inset_changed

var settings: Settings = null
var stack: Control = null
## () -> bool: whether the season is running (SeasonFlow RUNNING). The App sets it; the pause menu greys Save by it.
var season_running_func: Callable = Callable()
## () -> float: the screen y of the top bar's bottom edge. The App sets it.
var top_bar_bottom_func: Callable = Callable()


func _init(p_settings: Settings = null, p_stack: Control = null) -> void:
	settings = p_settings
	stack = p_stack


func toast(text: String, tone: StringName = &"plain") -> void:
	toast_requested.emit(text, tone)


func request(what: StringName, args: Dictionary = {}) -> void:
	app_requested.emit(what, args)


## Where a screen under the top bar starts: the bar's real bottom edge (Tokens.BAR_H before it is laid out) plus a gap.
func top_inset() -> float:
	var bottom := float(Tokens.BAR_H)
	if top_bar_bottom_func.is_valid():
		bottom = maxf(bottom, float(top_bar_bottom_func.call()))
	return bottom + float(Tokens.S2)


## True while the season runs (the pause menu's Save then reads "Wait for the season to end").
func season_running() -> bool:
	return season_running_func.is_valid() and bool(season_running_func.call())
