## Country panel (docs/architecture/m2-build-spec.md section 7.4): the dock's view of one country, read from CountryCard.
## It shows the arms, the ledger and the neighbour links; while the pick is open it also shows the tip and "Play as".
## It changes nothing: its buttons emit signals and the owner of the dock (the App or the pick) acts on them.
## A PanelFrame whose cartouche is the country's short name.
class_name CountryPanel
extends PanelFrame

signal play_requested(tag: StringName)
signal look_at_requested(hex: Vector2i)
signal country_requested(tag: StringName)
signal study_requested
## A declaration or a peace that needs a Confirm: the App pushes the screen. Without a listener the war buttons arm first.
signal confirm_requested(screen: Screen)
## A toast for the player: the words of a war act that was done (plain).
signal toast_requested(text: String, tone: StringName)

const NO_HEX := Country.NO_HEX
const LAND_SHOWN := 3
const LAND_SEPARATOR := " · "
const RELATION_WORDS: Dictionary = {"you": "your country", "neighbour": "neighbour", "outside": "outside power"}

@onready var _arms: CountryArms = $VBox/BodyScroll/Body/Summary/Arms
@onready var _long_name: Label = $VBox/BodyScroll/Body/Summary/Names/LongName
@onready var _relation: Label = $VBox/BodyScroll/Body/Summary/Names/Relation
@onready var _tip: Label = $VBox/BodyScroll/Body/Tip
@onready var _play: KitButton = $VBox/BodyScroll/Body/PlayAs
@onready var _play_reason: Label = $VBox/BodyScroll/Body/PlayReason
@onready var _ledger: GridContainer = $VBox/BodyScroll/Body/Ledger
@onready var _links: HFlowContainer = $VBox/BodyScroll/Body/NeighboursBox/Links
@onready var _show: KitButton = $VBox/Foot/ShowOnMap
@onready var _treasury_box: VBoxContainer = $VBox/BodyScroll/Body/TreasuryBox
@onready var _treasury_value: Label = $VBox/BodyScroll/Body/TreasuryBox/Value
@onready var _treasury_change: DeltaChip = $VBox/BodyScroll/Body/TreasuryBox/Change
@onready var _treasury_expected: DeltaChip = $VBox/BodyScroll/Body/TreasuryBox/Expected
@onready var _treasury_tax: Label = $VBox/BodyScroll/Body/TreasuryBox/Tax
@onready var _study: KitButton = $VBox/BodyScroll/Body/TreasuryBox/OpenStudy
@onready var _war: CountryWar = $VBox/BodyScroll/Body/War

var _tag: StringName = &""
var _picking: bool = false
var _focus: Vector2i = NO_HEX
var _retired: Array[Node] = []


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = float(Tokens.PANEL_W)
	visible = false
	closed.connect(clear)
	_play.pressed.connect(_on_play_pressed)
	_show.pressed.connect(_on_show_pressed)
	_study.pressed.connect(_on_study_pressed)
	_war.confirm_requested.connect(func(screen: Screen) -> void: confirm_requested.emit(screen))
	_war.toast_requested.connect(func(text: String, tone: StringName) -> void: toast_requested.emit(text, tone))
	_war.country_requested.connect(func(who: StringName) -> void: country_requested.emit(who))
	_wire_bus()


func _exit_tree() -> void:
	_unwire_bus()
	PanelKit.free_retired(_retired)


## Shows `tag`'s card. `picking` adds the tip and "Play as" (the pick is open; the verdict decides the button).
func show_country(tag: StringName, picking: bool) -> void:
	_tag = tag
	_picking = picking
	refresh()


## The country shown, or &"" when the panel is hidden.
func shown_tag() -> StringName:
	return _tag if visible else &""


## Hides the panel and forgets its country (the close button does this too).
func clear() -> void:
	_tag = &""
	_picking = false
	_focus = NO_HEX
	_war.fill(&"", {}, false)
	visible = false


## Rebuilds the panel from CountryCard for the shown country; hides it when the game has no such country.
func refresh() -> void:
	if not is_node_ready():
		return
	var card := CountryCard.of(Session.game, _tag)
	if card.is_empty():
		visible = false
		return
	cartouche_title = str(card["name"])
	_fill_head(card)
	_fill_picking(card)
	_fill_ledger(card)
	_war.fill(_tag, card["war"] as Dictionary, confirm_listened())
	_fill_neighbours(card)
	_fill_treasury(card)
	_focus = card["focus"] as Vector2i
	_show.disabled = _focus == NO_HEX
	visible = true


## The "Play as" button (hidden outside the pick).
func play_button() -> KitButton:
	return _play


## The "Show on the map" footer button.
func show_button() -> KitButton:
	return _show


## The capital link, or null when the capital is off the map.
func capital_button() -> Button:
	for child: Node in _ledger.get_children():
		if child is Button:
			return child as Button
	return null


## The neighbour links in id order.
func neighbour_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in _links.get_children():
		if child is Button:
			out.append(child as Button)
	return out


## The ledger as key, value, key, value, ... (a link counts as its text).
func ledger_texts() -> Array[String]:
	var out: Array[String] = []
	for child: Node in _ledger.get_children():
		if child is Label:
			out.append((child as Label).text)
		elif child is Button:
			out.append((child as Button).text)
	return out


## The long name line, or "" when hidden.
func long_name_text() -> String:
	return _long_name.text if _long_name.visible else ""


## The relation line ("your country", "neighbour", "outside power"), or "" when hidden.
func relation_text() -> String:
	return _relation.text if _relation.visible else ""


## The tip in the pick, or "" when hidden.
func tip_text() -> String:
	return _tip.text if _tip.visible else ""


## The reason line under "Play as", or "" when hidden.
func play_reason_text() -> String:
	return _play_reason.text if _play_reason.visible else ""


func _fill_head(card: Dictionary) -> void:
	_arms.set_country(card["arms"] as Dictionary)
	_long_name.text = str(card["long_name"])
	_long_name.visible = true
	_relation.text = str(RELATION_WORDS.get(str(card["relation"]), ""))
	_relation.visible = _relation.text != ""


func _fill_picking(card: Dictionary) -> void:
	var tip := str(card["tip"])
	_tip.text = tip
	_tip.visible = _picking and tip != ""
	_play.visible = _picking
	_play_reason.visible = false
	if not _picking:
		return
	_play.text = "Play as " + str(card["name"])
	var verdict := Session.check("choose_country", {"tag": _tag})
	_play.set_verdict(verdict)
	var reason := str(verdict.get("reason", ""))
	_play_reason.text = reason
	_play_reason.visible = reason != ""


func _fill_ledger(card: Dictionary) -> void:
	PanelKit.clear_children(_ledger, _retired)
	_add_row("Capital", _capital_control(card["capital"] as Dictionary))
	_add_row("Districts", _value(str(int(card["districts"]))))
	_add_row("Towns", _value(_towns_words(card)))
	var people := card["people"] as Dictionary
	if bool(people["shown"]):
		_add_row("People", _value(_people_words(people)))
	var army := card["army"] as Dictionary
	if bool(army["shown"]):
		_add_row("Under arms", _value(_army_words(army)))
	_add_row("Passes", _value(_passes_words(card["passes"] as Array)))
	_add_row("Land", _value(_land_words(card["land"] as Array)))


func _add_row(key_text: String, value: Control) -> void:
	_ledger.add_child(PanelKit.label(key_text, &"Hint"))
	_ledger.add_child(value)


func _capital_control(cap: Dictionary) -> Control:
	var cap_name := str(cap["name"])
	if bool(cap["off_map"]):
		return _value(cap_name + ", off this map")
	var hex := cap["hex"] as Vector2i
	return _link(cap_name, "Show the capital on the map", func() -> void: look_at_requested.emit(hex))


func _towns_words(card: Dictionary) -> String:
	var towns := int(card["towns"])
	var cities := int(card["cities"])
	if cities == 0:
		return str(towns)
	if cities == 1:
		return "%d, 1 of them a city" % towns
	return "%d, %d of them cities" % [towns, cities]


## The People row (spec 6.4): yours exact with last season's change ("83,285 (▲ +585 last season)"); a known country's
## banded ("about 260,000"). The row is not shown for an unknown country, so no number of it is.
func _people_words(people: Dictionary) -> String:
	if bool(people["banded"]):
		return Knowledge.band_text(int(people["value"]), "")
	var text := Words.number(int(people["value"]))
	var change := int(people["change"])
	if change != 0:
		text += " (%s %s last season)" % [PeopleView.UP if change > 0 else PeopleView.DOWN, Words.signed(change)]
	return text


## The Under arms row (spec 6.10): yours exact with the count of armies ("1,000 men in 1 army", "none" with no army); a known
## country's banded ("about 1,000 men"). The row is not shown for an unknown country (CountryCard.army is not shown).
func _army_words(army: Dictionary) -> String:
	if bool(army["banded"]):
		return Knowledge.band_text(int(army["value"]), "men")
	var count := Armies.of_country(Session.game, _tag).size()
	if count == 0:
		return "none"
	return "%s in %d %s" % [Words.men(int(army["value"])), count, "army" if count == 1 else "armies"]


func _passes_words(passes: Array) -> String:
	if passes.is_empty():
		return "none"
	var names := PackedStringArray()
	for pass_name: Variant in passes:
		names.append(str(pass_name))
	return ", ".join(names)


func _land_words(land: Array) -> String:
	if land.is_empty():
		return "none"
	var parts := PackedStringArray()
	for at: int in mini(land.size(), LAND_SHOWN):
		var row := land[at] as Dictionary
		parts.append("%s %d" % [str(row["cover"]), int(row["count"])])
	return LAND_SEPARATOR.join(parts)


func _fill_neighbours(card: Dictionary) -> void:
	PanelKit.clear_children(_links, _retired)
	var neighbours := card["neighbours"] as Array
	if neighbours.is_empty():
		_links.add_child(PanelKit.label("none", &"Hint"))
		return
	for nb: Variant in neighbours:
		var row := nb as Dictionary
		var nb_tag := StringName(str(row["tag"]))
		_links.add_child(_link(str(row["name"]), "Show this country", func() -> void: country_requested.emit(nb_tag)))


func _value(value_text: String) -> Label:
	var lbl := PanelKit.label(value_text, &"TableRow")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _link(link_text: String, tip: String, on_press: Callable) -> KitButton:
	var btn := KitButton.new()
	btn.kind = KitButton.Kind.SMALL
	btn.text = link_text
	btn.tooltip_text = tip
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(on_press)
	return btn


func _on_play_pressed() -> void:
	play_requested.emit(_tag)


func _on_show_pressed() -> void:
	look_at_requested.emit(_focus)


## Spec 6.10: the treasury section. Yours: the exact treasury, last season's change, the expected net (when the card
## carries one) and the tax. A known foreign country: a banded figure only. Unknown: no section at all.
func _fill_treasury(card: Dictionary) -> void:
	var treasury := card["treasury"] as Dictionary
	var shown := bool(treasury["shown"])
	_treasury_box.visible = shown
	if not shown:
		_study.visible = false
		return
	var banded := bool(treasury["banded"])
	var value := int(treasury["value"])
	_treasury_value.text = "Treasury " + (Knowledge.band_text(value, "") if banded else Words.number(value))
	_study.visible = not banded
	_treasury_change.visible = not banded
	_treasury_expected.visible = false
	_treasury_tax.visible = false
	if banded:
		return
	_treasury_change.set_delta(int(treasury["change"]), "", "Last season")
	var expected: Variant = treasury["expected"]
	if expected != null:
		_treasury_expected.set_delta(int(expected), "", "Expected this season")
		_treasury_expected.visible = true
	_treasury_tax.text = "Taxes " + str(treasury["tax"])
	_treasury_tax.visible = str(treasury["tax"]) != ""


## The War section (spec 6.7), for the tests and the App's notes.
func war_section() -> CountryWar:
	return _war


## Whether some listener is connected to confirm_requested (the App pushes the Confirm); the war buttons ask with it.
func confirm_listened() -> bool:
	return not get_signal_connection_list(&"confirm_requested").is_empty()


## The treasury section is shown (the viewer's own country or a known one).
func treasury_visible() -> bool:
	return _treasury_box.visible


## "Treasury 658" or "Treasury about 1,900", or "" when hidden.
func treasury_text() -> String:
	return _treasury_value.text if _treasury_box.visible else ""


## The last-season change readout, or "" when hidden (yours only).
func change_text() -> String:
	return _treasury_change.text() if _treasury_change.visible else ""


## The expected net readout, or "" when the card carries none.
func expected_text() -> String:
	return _treasury_expected.text() if _treasury_expected.visible else ""


## The tax line ("Taxes Normal"), or "" when hidden.
func tax_text() -> String:
	return _treasury_tax.text if _treasury_tax.visible else ""


## The "Open the study" button (yours only).
func study_button() -> KitButton:
	return _study


## The bus signals that change the treasury; each one refreshes the panel while it is shown.
func _wiring() -> Array:
	return [
		[Events.season_ended, _on_season_ended],
		[Events.tax_set, _on_tax_set],
		[Events.work_started, _on_work_changed],
		[Events.work_finished, _on_work_changed],
		[Events.work_cancelled, _on_work_cancelled],
		[Events.town_grew, _on_town_grew],
		[Events.district_declined, _on_district_declined],
		[Events.war_declared, _on_war_declared],
		[Events.peace_made, _on_peace_made],
		[Events.district_captured, _on_district_captured],
		[Events.controllers_changed, _on_controllers_changed],
		[Events.country_chosen, _on_country_chosen],
	]


func _wire_bus() -> void:
	for pair: Array in _wiring():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if not sig.is_connected(handler):
			sig.connect(handler)


func _unwire_bus() -> void:
	for pair: Array in _wiring():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


func _refresh_if_shown() -> void:
	if visible:
		refresh()


func _on_season_ended(_turn: int) -> void:
	_refresh_if_shown()


func _on_tax_set(_tag: StringName, _level: int) -> void:
	_refresh_if_shown()


func _on_work_changed(_tag: StringName, _hex: Vector2i, _work: Dictionary) -> void:
	_refresh_if_shown()


func _on_work_cancelled(_tag: StringName, _hex: Vector2i, _work: Dictionary, _why: StringName) -> void:
	_refresh_if_shown()


func _on_town_grew(_tag: StringName, _hex: Vector2i, _level: int) -> void:
	_refresh_if_shown()


func _on_district_declined(_tag: StringName, _hex: Vector2i, _level: int, _why: StringName) -> void:
	_refresh_if_shown()


func _on_war_declared(_who: StringName, _target: StringName) -> void:
	_refresh_if_shown()


func _on_peace_made(_who: StringName, _target: StringName, _terms: StringName) -> void:
	_refresh_if_shown()


func _on_district_captured(_hex: Vector2i, _who: StringName, _by: StringName) -> void:
	_refresh_if_shown()


func _on_controllers_changed(_hexes: Array[Vector2i]) -> void:
	_refresh_if_shown()


func _on_country_chosen(_who: StringName) -> void:
	_refresh_if_shown()


func _on_study_pressed() -> void:
	study_requested.emit()
