## Studiolo top bar date and End season (docs/architecture/m3-build-spec.md section 6.2): a brass medallion with the
## year and the season dial (a click asks for the season report), then the End season plate with its Space key cap.
## A refused end (the country pick is open) shows its reason as a line and as the button's tooltip. It reads Session
## and Events and sends intents only; the top bar places it (Y18).
class_name DateEnd
extends HBoxContainer

signal end_season_requested
signal report_requested

const NO_GAME_TEXT := "No game"
const REPORT_TIP := ". J: the last report"
const END_VARIATION := &"ButtonEndSeason"

var _date: Medallion = null
var _end: KitButton = null
var _verdict: Label = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	_date = $Date as Medallion
	_end = $End as KitButton
	_verdict = $Verdict as Label

	_date.focus_mode = Control.FOCUS_NONE
	_date.pressed.connect(func() -> void: report_requested.emit())

	# The KitButton kinds have no End season variation: the plate is set after the button's own ready.
	_end.focus_mode = Control.FOCUS_NONE
	_end.theme_type_variation = END_VARIATION
	_end.pressed.connect(func() -> void: end_season_requested.emit())

	refresh()


## The bus links live while the widget is in the tree, so a reparent (a top-bar relayout) keeps them.
func _enter_tree() -> void:
	if not Events.game_started.is_connected(_on_game_started):
		Events.game_started.connect(_on_game_started)
	if not Events.country_chosen.is_connected(_on_country_chosen):
		Events.country_chosen.connect(_on_country_chosen)
	if not Events.season_ended.is_connected(_on_season_ended):
		Events.season_ended.connect(_on_season_ended)
	if not Events.game_ended.is_connected(_on_game_ended):
		Events.game_ended.connect(_on_game_ended)
	refresh()


func _exit_tree() -> void:
	if Events.game_started.is_connected(_on_game_started):
		Events.game_started.disconnect(_on_game_started)
	if Events.country_chosen.is_connected(_on_country_chosen):
		Events.country_chosen.disconnect(_on_country_chosen)
	if Events.season_ended.is_connected(_on_season_ended):
		Events.season_ended.disconnect(_on_season_ended)
	if Events.game_ended.is_connected(_on_game_ended):
		Events.game_ended.disconnect(_on_game_ended)


## Reads Session: the year and season of the turn, and the End season verdict (refused: disabled, with its reason).
func refresh() -> void:
	if not is_node_ready():
		return
	var game := Session.game
	if game == null:
		set_date(0, -1)
	else:
		set_date(Calendar.year_of(game.turn, game.start_year), Calendar.season_of(game.turn))
	var verdict := Session.end_season_check()
	_end.set_verdict(verdict)
	var ok := bool(verdict.get("ok", true))
	_verdict.text = "" if ok else str(verdict.get("reason", ""))
	_verdict.visible = not ok


## Shows `year` on the medallion and the lit quarter `season` (0 Spring to 3 Winter); a year of 0 (no game) shows none.
func set_date(year: int, season: int) -> void:
	if not is_node_ready():
		return
	if year <= 0 or season < 0 or season > 3:
		_date.text = ""
		_date.dial = -1
		_date.tooltip_text = NO_GAME_TEXT
		return
	_date.text = str(year)
	_date.dial = season
	_date.tooltip_text = "%s %d%s" % [Calendar.SEASON_NAMES[season], year, REPORT_TIP]


## Turns the medallion's ring (or shows the still hourglass under reduce motion, the medallion's own setting).
func set_busy(on: bool) -> void:
	if is_node_ready():
		_date.set_busy(on, _date.reduce_motion)


func is_busy() -> bool:
	return _date != null and _date.busy


## Re-reads the End season key cap after a rebinding.
func refresh_hotkeys() -> void:
	if is_node_ready():
		_end.refresh_hotkey()


## The refusal line shown under the pick ("" when the end is allowed).
func verdict_text() -> String:
	return _verdict.text if _verdict != null and _verdict.visible else ""


func date_button() -> Medallion:
	return _date


func end_button() -> KitButton:
	return _end


func verdict_label() -> Label:
	return _verdict


func _on_game_started() -> void:
	refresh()


func _on_country_chosen(_tag: StringName) -> void:
	refresh()


func _on_season_ended(_turn: int) -> void:
	refresh()


## The game ended: no date and the End season plate is off, whatever Session still holds.
func _on_game_ended() -> void:
	if not is_node_ready():
		return
	set_date(0, -1)
	_end.set_verdict({"ok": false, "reason": "no game"})
	_verdict.text = ""
	_verdict.visible = false
