## The War section of the country panel (docs/architecture/m7-build-spec.md section 6.7; issue #240). It is built from the
## war part of CountryCard.of(...).war: another country at peace (Declare war), in a truce (Declare war, off with its
## reason), at war (since, the score as a DeltaChip, the districts held each way, the three peace buttons), or your own card
## (the wars as links and the truces as lines, with no buttons). Each button's state and reason come from Session.check; a
## click goes through Session.act. A declaration and a peace ask first: the Confirm goes out through confirm_requested when
## the panel has a listener; with none, the first press arms the action and a second press on it does it. The section
## forwards its signals through CountryPanel and changes nothing else.
class_name CountryWar
extends VBoxContainer

signal confirm_requested(screen: Screen)
## A toast for the player: the words of an act that was done (plain).
signal toast_requested(text: String, tone: StringName)
signal country_requested(tag: StringName)

const SECTION_TITLE := "War"
const DECLARE_LABEL := "Declare war"
const DECLARE_TITLE := "Declare war on %s?"
const DECLARE_LINE := "Your armies may enter their land and attack theirs; theirs may enter yours."
const DECLARE_TERMS := "A white peace needs %s of war; taking land needs %d of their districts held, or their armies beaten."
const PEACE_TITLE := "Make peace with %s?"
const CHOICE_DECLARE := {"id": &"confirm", "label": "Declare war", "kind": "danger", "safe": false}
const CHOICE_PEACE := {"id": &"confirm", "label": "Make peace", "kind": "primary", "safe": false}
const CHOICE_KEEP := {"id": &"cancel", "label": "Cancel", "kind": "secondary", "safe": true}

var _tag: StringName = &""
var _card: Dictionary = {}
var _asks: bool = false
## The action the first press armed (no Confirm listener, or a Confirm nobody took): "declare_war:" or "make_peace:take".
var _armed: String = ""
var _notice: String = ""
var _reasons: PackedStringArray = PackedStringArray()
var _retired: Array[Node] = []


func _exit_tree() -> void:
	PanelKit.free_retired(_retired)


## Rebuilds the section for `tag` from its war card. `asks`: the panel has a Confirm listener. A state of none (no player
## yet) hides the section. A new tag drops the armed action.
func fill(tag: StringName, card: Dictionary, asks: bool) -> void:
	if tag != _tag:
		_tag = tag
		_armed = ""
		_notice = ""
	_asks = asks
	_card = card
	PanelKit.clear_children(self, _retired)
	_reasons = PackedStringArray()
	var state := StringName(str(card.get("state", "none")))
	visible = state != &"none" and state != &""
	if not visible:
		return
	add_child(PanelKit.label(SECTION_TITLE, &"SectionHead"))
	match state:
		&"self":
			_add_own()
		&"war":
			_add_at_war()
		_:
			_add_at_peace(state)
	_disarm_if_refused()
	_add_notes()


## The action button of `action` (and `terms` for a peace), or null when the section shows none of it.
func action_button(action: String, terms: StringName = &"") -> KitButton:
	for child: Node in find_children("*", "KitButton", true, false):
		var btn := child as KitButton
		if btn.has_meta(&"key") and str(btn.get_meta(&"key")) == _key_of(action, terms):
			return btn
	return null


## The reason lines under the refused buttons, in order (the buttons' tooltips carry the same words).
func reason_texts() -> PackedStringArray:
	return _reasons


## The notice line (an armed action, or a refusal of the last press), or "" when there is none.
func notice_text() -> String:
	return _notice


## The war card's "state" as the section shows it: &"none", &"self", &"war", &"truce" or &"peace".
func state() -> StringName:
	return StringName(str(_card.get("state", "none")))


func _add_at_peace(current: StringName) -> void:
	if current == &"truce":
		add_child(PanelKit.label(str(_card.get("truce_text", "")), &"TableRow"))
	else:
		add_child(PanelKit.label("At peace", &"TableRow"))
	_add_action(_button_row(), DECLARE_LABEL, KitButton.Kind.DANGER, "declare_war", &"")


func _add_at_war() -> void:
	add_child(PanelKit.label(str(_card.get("since_text", "")), &"TableRow"))
	var chip := DeltaChip.new()
	add_child(chip)
	chip.set_delta(int(_card.get("score", 0)), "", "score")
	add_child(PanelKit.label(_held_text(), &"TableRow"))
	var row := _button_row()
	for item: Variant in _card.get("peace", []) as Array:
		var option := item as Dictionary
		_add_action(row, str(option["label"]), KitButton.Kind.SECONDARY, "make_peace",
			StringName(str(option["terms"])))


func _add_own() -> void:
	var game := Session.game
	var wars := _card.get("wars", []) as Array
	if wars.is_empty():
		add_child(PanelKit.label("No wars.", &"Hint"))
	else:
		add_child(PanelKit.label("At war with", &"Hint"))
		var row := _button_row()
		for item: Variant in wars:
			var entry := item as Dictionary
			var other := StringName(str(entry["tag"]))
			var score := Wars.score(game, game.player, other)
			var btn := KitButton.new()
			btn.kind = KitButton.Kind.SMALL
			btn.text = "%s (%s)" % [Words.country_the(game, other), Words.signed(score)]
			btn.tooltip_text = "Show this country"
			btn.focus_mode = Control.FOCUS_ALL
			row.add_child(btn)
			btn.pressed.connect(func() -> void: country_requested.emit(other))
	for item: Variant in _card.get("truces", []) as Array:
		var entry := item as Dictionary
		var text := "%s: %s" % [Words.country_the(game, StringName(str(entry["tag"]))), str(entry["text"])]
		add_child(PanelKit.label(text, &"TableRow"))


## "You hold 2 of their districts; they hold none of yours."
func _held_text() -> String:
	return "You hold %s of their districts; they hold %s of yours." % [_count_words(int(_card.get("held_theirs", 0))),
		_count_words(int(_card.get("held_yours", 0)))]


func _count_words(n: int) -> String:
	return "none" if n == 0 else Words.number(n)


func _button_row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	return row


## One action button. Its verdict comes from Session.check; a refused one lists its reason under the section.
func _add_action(row: HFlowContainer, text: String, kind: KitButton.Kind, action: String, terms: StringName) -> void:
	var btn := KitButton.new()
	btn.kind = kind
	btn.text = text
	btn.focus_mode = Control.FOCUS_ALL
	btn.set_meta(&"key", _key_of(action, terms))
	btn.pressed.connect(_press.bind(action, terms))
	row.add_child(btn)
	var verdict := _verdict(action, terms)
	btn.set_verdict(verdict)
	if not bool(verdict["ok"]):
		_reasons.append(str(verdict["reason"]))


func _verdict(action: String, terms: StringName) -> Dictionary:
	if action == "declare_war":
		return Session.check("declare_war", {"target": _tag})
	return Session.check("make_peace", {"target": _tag, "terms": terms})


func _args_of(action: String, terms: StringName) -> Dictionary:
	if action == "declare_war":
		return {"target": _tag}
	return {"target": _tag, "terms": terms}


func _key_of(action: String, terms: StringName) -> String:
	return "%s:%s" % [action, terms]


## A press: with a Confirm listener the question goes out (the act follows its "Declare war" or "Make peace"); without one,
## the first press arms the action and a second press on the same action does it.
func _press(action: String, terms: StringName) -> void:
	var key := _key_of(action, terms)
	var question := _question(action, terms)
	if _asks:
		var confirm := Confirm.ask(str(question["title"]), question["lines"] as Array,
			[question["choice"] as Dictionary, CHOICE_KEEP], {"danger": action == "declare_war",
			"on_result": func(accepted: bool) -> void:
				if accepted:
					_do(action, terms)})
		confirm_requested.emit(confirm)
		if confirm.is_inside_tree():
			return
		confirm.free()
	if _armed == key:
		_do(action, terms)
		return
	_armed = key
	_notice = "Press %s again to confirm." % str((question["choice"] as Dictionary)["label"])
	_rebuild()


## The question of an action: its title, its lines and its choice (the Confirm's words of 6.7).
func _question(action: String, terms: StringName) -> Dictionary:
	var who := Words.country_the(Session.game, _tag)
	if action == "declare_war":
		var lines: Array = [DECLARE_LINE]
		var numbers := _numbers()
		if numbers != null:
			lines.append(DECLARE_TERMS % [Words.seasons(numbers.peace_min_seasons), numbers.take_score])
		return {"title": DECLARE_TITLE % who, "lines": lines, "choice": CHOICE_DECLARE}
	return {"title": PEACE_TITLE % who, "lines": [_option_text(terms)], "choice": CHOICE_PEACE}


func _numbers() -> WarDef:
	var game := Session.game
	return game.defs.war if game != null and game.defs != null else null


## The sentence under a peace option of the card: what moves (CountryCard's words).
func _option_text(terms: StringName) -> String:
	for item: Variant in _card.get("peace", []) as Array:
		var option := item as Dictionary
		if StringName(str(option["terms"])) == terms:
			return str(option["text"])
	return ""


func _moves_of(terms: StringName) -> Array:
	for item: Variant in _card.get("peace", []) as Array:
		var option := item as Dictionary
		if StringName(str(option["terms"])) == terms:
			return option["moves"] as Array
	return []


## Does the action through Session.act. The toast or the refusal's reason; the section is rebuilt either way.
func _do(action: String, terms: StringName) -> void:
	var toast := _toast_of(action, terms)
	var verdict := Session.act(action, _args_of(action, terms))
	_armed = ""
	_notice = ""
	if bool(verdict["ok"]):
		toast_requested.emit(toast, &"plain")
	else:
		_notice = str(verdict["reason"])
	_rebuild()


## The toast of a done act, worked out before it: "War with the Duchy of Milan.", "Peace with the Duchy of Milan: you took
## 2 districts.", "Peace with the Duchy of Milan: everything returns to its owner."
func _toast_of(action: String, terms: StringName) -> String:
	var who := Words.country_the(Session.game, _tag)
	if action == "declare_war":
		return "War with %s." % who
	var count := _moves_of(terms).size()
	if count > 0 and terms == &"take":
		return "Peace with %s: you took %s." % [who, Words.plural(count, "district", "districts")]
	if count > 0 and terms == &"yield":
		return "Peace with %s: you gave up %s." % [who, Words.plural(count, "district", "districts")]
	return "Peace with %s: everything returns to its owner." % who


## Rebuilds the section from the current card (after an act, or when the armed notice changes).
func _rebuild() -> void:
	var card := CountryCard.of(Session.game, _tag)
	fill(_tag, card.get("war", {}) as Dictionary, _asks)


## An armed action the rules no longer allow (its button is refused now) drops its notice.
func _disarm_if_refused() -> void:
	if _armed == "":
		return
	var btn := _button_by_key(_armed)
	if btn == null or btn.disabled:
		_armed = ""
		_notice = ""


func _button_by_key(key: String) -> KitButton:
	for child: Node in find_children("*", "KitButton", true, false):
		var btn := child as KitButton
		if btn.has_meta(&"key") and str(btn.get_meta(&"key")) == key:
			return btn
	return null


func _add_notes() -> void:
	if _notice != "":
		add_child(PanelKit.reason(_capital_first(_notice)))
	for reason: String in _reasons:
		add_child(PanelKit.reason(_capital_first(reason)))


func _capital_first(text: String) -> String:
	if text == "":
		return ""
	return text.substr(0, 1).to_upper() + text.substr(1)
