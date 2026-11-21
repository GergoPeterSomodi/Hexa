## The top bar's resource chips (docs/architecture/m4-build-spec.md 6.3, m5-build-spec.md 6.2): Ducats, People, Food and
## Stores for the player's country, the values and hover cards from EconomyCards and PeopleCards. Shown only in a game with
## countries and a chosen player (hidden in the sandbox and in the country pick); People and Food also need the people and
## the goods of the game. A click on Ducats or Stores emits study_requested with the Economy tab it opens (spec 6.9 of M4.5:
## Ducats This season, Stores Goods); a click on People or Food emits page_requested for the People page (spec 6.2 of M5).
## It reads Session and Events and sends intents only; the top bar places it (N12). Session.dev_money and dev_goods emit
## no event: their caller calls refresh().
class_name Chips
extends HBoxContainer

signal study_requested(tab: StringName)
## A People or Food chip was pressed: the study opens at this page (the People page).
signal page_requested(page: StringName)
## Emitted after every refresh (it sets the chips' visibility itself, so the top bar fits again).
signal refreshed

const DUCATS_ID := &"ducats"
const PEOPLE_ID := &"people"
const FOOD_ID := &"food"
const STORES_ID := &"stores"
const DUCATS_LABEL := "Ducats"
const PEOPLE_LABEL := "People"
const FOOD_LABEL := "Food"
const STORES_LABEL := "Stores"
const PEOPLE_PAGE := &"people"
const RULE_TONE := &"rule"
const HINT_TONE := &"muted"
const BAD_TONE := &"bad"
const ROW_SEPARATION := 0
const CHIP_SEPARATION := 2

var _ducats: ResourceChip = null
var _people: ResourceChip = null
var _food: ResourceChip = null
var _stores: ResourceChip = null
var _ducats_card: Dictionary = {}
var _people_card: Dictionary = {}
var _food_card: Dictionary = {}
var _stores_card: Dictionary = {}
## Whether the data wants each chip (a game with the resource); the top bar's fit may still hide it.
var _wanted: Dictionary = {}
## Whether a season has closed for People and Food: before it, their changes show no DeltaChip.
var _people_closed: bool = false
var _food_closed: bool = false
var _narrow: bool = false


func _ready() -> void:
	_ducats = $Ducats as ResourceChip
	_people = $People as ResourceChip
	_food = $Food as ResourceChip
	_stores = $Stores as ResourceChip
	_ducats.set_resource(DUCATS_ID, &"ducats", DUCATS_LABEL)
	_people.set_resource(PEOPLE_ID, &"people", PEOPLE_LABEL)
	_food.set_resource(FOOD_ID, &"food", FOOD_LABEL)
	_stores.set_resource(STORES_ID, &"stores", STORES_LABEL)
	# Tighter than the Studiolo default, so the four chips fit the bar beside the brand at 1280 px (spec 6.2 of M5).
	add_theme_constant_override(&"separation", ROW_SEPARATION)
	for chip: ResourceChip in [_ducats, _people, _food, _stores]:
		(chip.get_node("Plate/HBox") as HBoxContainer).add_theme_constant_override(&"separation", CHIP_SEPARATION)
	_ducats.pressed.connect(_on_chip_pressed.bind(&"this_season"))
	_people.pressed.connect(_on_page_pressed)
	_food.pressed.connect(_on_page_pressed)
	_stores.pressed.connect(_on_chip_pressed.bind(&"goods"))
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
	var people: Dictionary = {}
	var food: Dictionary = {}
	if game != null and game.has_countries() and tag != &"":
		ducats = EconomyCards.ducats(game, tag)
		stores = EconomyCards.stores(game, tag)
		people = PeopleCards.people(game, tag)
		food = PeopleCards.food(game, tag)
		var c := Countries.by_tag(game, tag)
		_people_closed = c != null and not c.people_closed.is_empty()
		_food_closed = c != null and not c.goods_closed.is_empty()
	visible = not ducats.is_empty()
	_wanted = {DUCATS_ID: visible, PEOPLE_ID: visible and not people.is_empty(),
		FOOD_ID: visible and not food.is_empty(), STORES_ID: visible and not stores.is_empty()}
	if not visible:
		_ducats_card = {}
		_people_card = {}
		_food_card = {}
		_stores_card = {}
		refreshed.emit()
		return
	_ducats.set_value(int(ducats["value"]), int(ducats["change"]))
	_ducats_card = _card_of(ducats)
	_ducats.set_card(_ducats_card)
	_people.visible = wanted(PEOPLE_ID)
	if _people.visible:
		_people.set_value(int(people["value"]), int(people["change"]))
		_people_card = _card_of(people)
		_people.set_card(_people_card)
	else:
		_people_card = {}
	_food.visible = wanted(FOOD_ID)
	if _food.visible:
		_food.set_value(int(food["value"]), int(food["change"]))
		_food_card = _card_of(food)
		_food.set_card(_food_card)
	else:
		_food_card = {}
	_stores.visible = wanted(STORES_ID)
	if _stores.visible:
		_stores.set_value(int(stores["value"]), int(stores["change"]))
		_stores_card = _card_of(stores)
		_stores.set_card(_stores_card)
	else:
		_stores_card = {}
	_apply_narrow()
	refreshed.emit()


## Narrowing (the top bar's order, spec 6.2 of M5): the Stores name and changes hide first, then Food's, then the country's
## long name, then People's name and change, then Ducats' name and change; the medals and values never hide here.
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


func people_chip() -> ResourceChip:
	return _people


func food_chip() -> ResourceChip:
	return _food


func stores_chip() -> ResourceChip:
	return _stores


## Whether the data wants the chip with this id (a game without people or goods does not); the top bar's fit uses it
## to restore a chip it hid.
func wanted(id: StringName) -> bool:
	return bool(_wanted.get(id, false))


## Whether the chip with this id shows its change: Ducats and Stores always, People and Food once a season has closed.
func change_wanted(id: StringName) -> bool:
	if id == PEOPLE_ID:
		return _people_closed
	if id == FOOD_ID:
		return _food_closed
	return true


## The Ducats hover card last set: {title, subtitle, lines, ...} with the hint as its last row.
func ducats_card() -> Dictionary:
	return _ducats_card


## The People hover card last set (empty when the People chip is hidden).
func people_card() -> Dictionary:
	return _people_card


## The Food hover card last set (empty when the Food chip is hidden).
func food_card() -> Dictionary:
	return _food_card


## The Stores hover card last set (empty when the Stores chip is hidden).
func stores_card() -> Dictionary:
	return _stores_card


## The card for HoverCard: the data's lines, then a rule and the hint in muted type. A data `tone` of bad (the towns went
## hungry) puts the first line in the bad tone.
static func _card_of(data: Dictionary) -> Dictionary:
	var lines: Array = (data["lines"] as Array).duplicate()
	if data.get("tone", &"") == BAD_TONE and not lines.is_empty():
		var first := (lines[0] as Array).duplicate()
		first[1] = BAD_TONE
		lines[0] = first
	lines.append(["", RULE_TONE])
	lines.append([str(data["hint"]), HINT_TONE])
	return {"title": str(data["title"]), "subtitle": "", "lines": lines}


func _apply_narrow() -> void:
	if _ducats == null or _stores == null:
		return
	_stores.set_name_shown(not _narrow)
	_stores.set_change_shown(not _narrow and change_wanted(STORES_ID))
	_food.set_name_shown(not _narrow)
	_food.set_change_shown(not _narrow and change_wanted(FOOD_ID))
	_people.set_name_shown(not _narrow)
	_people.set_change_shown(not _narrow and change_wanted(PEOPLE_ID))
	_ducats.set_change_shown(not _narrow)


func _on_chip_pressed(tab: StringName) -> void:
	study_requested.emit(tab)


func _on_page_pressed() -> void:
	page_requested.emit(PEOPLE_PAGE)


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
