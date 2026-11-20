## The top bar's resource chips (docs/architecture/m4-build-spec.md 6.3): Ducats and Stores for the player's country, the
## values and hover cards from EconomyCards. Shown only in a game with countries and a chosen player (hidden in the
## sandbox and in the country pick). A click on either chip emits study_requested (N12 opens the study's Economy page).
## It reads Session and Events and sends intents only; the top bar places it (N12). Session.dev_money and dev_goods emit
## no event: their caller calls refresh().
class_name Chips
extends HBoxContainer

signal study_requested
## Emitted after every refresh (it sets the chips' visibility itself, so the top bar fits again).
signal refreshed

const DUCATS_ID := &"ducats"
const STORES_ID := &"stores"
const DUCATS_LABEL := "Ducats"
const STORES_LABEL := "Stores"
const RULE_TONE := &"rule"
const HINT_TONE := &"muted"

var _ducats: ResourceChip = null
var _stores: ResourceChip = null
var _ducats_card: Dictionary = {}
var _stores_card: Dictionary = {}
var _narrow: bool = false


func _ready() -> void:
	_ducats = $Ducats as ResourceChip
	_stores = $Stores as ResourceChip
	_ducats.set_resource(DUCATS_ID, &"ducats", DUCATS_LABEL)
	_stores.set_resource(STORES_ID, &"stores", STORES_LABEL)
	_ducats.pressed.connect(_on_chip_pressed)
	_stores.pressed.connect(_on_chip_pressed)
	_apply_narrow()
	refresh()


## The bus links live while the widget is in the tree, so a reparent (a top-bar relayout) keeps them.
func _enter_tree() -> void:
	_link(Events.game_started, _on_game_started)
	_link(Events.game_ended, _on_game_ended)
	_link(Events.country_chosen, _on_country_chosen)
	_link(Events.season_ended, _on_season_ended)
	_link(Events.tax_set, _on_tax_set)
	_link(Events.work_started, _on_work_started)
	_link(Events.work_finished, _on_work_finished)
	_link(Events.work_cancelled, _on_work_cancelled)
	refresh()


func _exit_tree() -> void:
	_unlink(Events.game_started, _on_game_started)
	_unlink(Events.game_ended, _on_game_ended)
	_unlink(Events.country_chosen, _on_country_chosen)
	_unlink(Events.season_ended, _on_season_ended)
	_unlink(Events.tax_set, _on_tax_set)
	_unlink(Events.work_started, _on_work_started)
	_unlink(Events.work_finished, _on_work_finished)
	_unlink(Events.work_cancelled, _on_work_cancelled)


## Reads Session: the chips show for the player's country in a game with countries; otherwise the bar hides them.
func refresh() -> void:
	if not is_node_ready():
		return
	var game := Session.game
	var tag := Session.player_tag()
	var ducats: Dictionary = {}
	var stores: Dictionary = {}
	if game != null and game.has_countries() and tag != &"":
		ducats = EconomyCards.ducats(game, tag)
		stores = EconomyCards.stores(game, tag)
	visible = not ducats.is_empty()
	if not visible:
		_ducats_card = {}
		_stores_card = {}
		refreshed.emit()
		return
	_ducats.set_value(int(ducats["value"]), int(ducats["change"]))
	_ducats_card = _card_of(ducats)
	_ducats.set_card(_ducats_card)
	_stores.visible = not stores.is_empty()
	if _stores.visible:
		_stores.set_value(int(stores["value"]), int(stores["change"]))
		_stores_card = _card_of(stores)
		_stores.set_card(_stores_card)
	else:
		_stores_card = {}
	refreshed.emit()


## Narrowing (the top bar's order, spec 6.3): the Stores name and both changes hide; the values and medals stay.
func set_narrow(on: bool) -> void:
	_narrow = on
	_apply_narrow()


func is_narrow() -> bool:
	return _narrow


## The chips carry no key caps, so a rebinding leaves nothing to re-read (the top bar calls every widget alike).
func refresh_hotkeys() -> void:
	pass


func ducats_chip() -> ResourceChip:
	return _ducats


func stores_chip() -> ResourceChip:
	return _stores


## The Ducats hover card last set: {title, subtitle, lines, ...} with the hint as its last row.
func ducats_card() -> Dictionary:
	return _ducats_card


## The Stores hover card last set (empty when the Stores chip is hidden).
func stores_card() -> Dictionary:
	return _stores_card


## The card for HoverCard: EconomyCards' lines, then a rule and the hint in muted type.
static func _card_of(data: Dictionary) -> Dictionary:
	var lines: Array = (data["lines"] as Array).duplicate()
	lines.append(["", RULE_TONE])
	lines.append([str(data["hint"]), HINT_TONE])
	return {"title": str(data["title"]), "subtitle": "", "lines": lines}


func _apply_narrow() -> void:
	if _ducats == null or _stores == null:
		return
	_stores.set_name_shown(not _narrow)
	_ducats.set_change_shown(not _narrow)
	_stores.set_change_shown(not _narrow)


func _on_chip_pressed() -> void:
	study_requested.emit()


func _link(sig: Signal, handler: Callable) -> void:
	if not sig.is_connected(handler):
		sig.connect(handler)


func _unlink(sig: Signal, handler: Callable) -> void:
	if sig.is_connected(handler):
		sig.disconnect(handler)


func _on_game_started() -> void:
	refresh()


func _on_game_ended() -> void:
	refresh()


func _on_country_chosen(_tag: StringName) -> void:
	refresh()


func _on_season_ended(_turn: int) -> void:
	refresh()


func _on_tax_set(_tag: StringName, _level: int) -> void:
	refresh()


func _on_work_started(_tag: StringName, _hex: Vector2i, _work: Dictionary) -> void:
	refresh()


func _on_work_finished(_tag: StringName, _hex: Vector2i, _work: Dictionary) -> void:
	refresh()


func _on_work_cancelled(_tag: StringName, _hex: Vector2i, _work: Dictionary, _why: StringName) -> void:
	refresh()
