## The war part of the army panel (docs/architecture/m7-build-spec.md 6.8; M7 B26): the standing of an army when it is attacked (a
## Segmented Hold | Withdraw, each price in its hover), its morale (a bar, the word, "too shaken" in Reason), its siege and the Storm
## button of a besieging army (with the Shift+O key cap), its battle in progress and the last battle of its country, each with
## "Open the battle" (battle_requested with the record id; the App's dock listens). Every enabled state and reason is the rules'
## check (Session.check); a click goes through Session.act. Storm goes through the map's orders (MapArmies.storm: the question
## of a risky move, the toast, the battle's dock), as Shift+O does; with no map it acts here. It is a child of ArmyPanel (the
## panel stays under 800 lines) and keeps its buttons out of the panel's verdict loop (no "action" meta), so its checks are
## its own.
@warning_ignore_start("integer_division")
class_name ArmyWar
extends VBoxContainer

## "Open the battle": the record id of the battle to show in the dock (-1 when the battle is not fought yet: no record).
signal battle_requested(record: int)

const NO_RECORD := -1
const STANDING_HOLD := "hold"
const STANDING_WITHDRAW := "withdraw"
const STORM_HOTKEY := &"map_command_storm"
const STORM_TEXT := "Storm"
const OPEN_TEXT := "Open the battle"
const NO_RECORD_REASON := "The battle is not fought yet."
const HOLD_TIP := "Stands and fights when it is attacked."
const SHAKEN_TEXT := "Too shaken to attack: %d %% needed."

var _army := -1
var _standing_now := STANDING_HOLD
var _standing: Segmented = null
var _reason: Label = null


## Builds the war part of `data` (ArmyView.panel of an own army, with its war parts). Each button's verdict is set here.
func fill(game: Game, data: Dictionary) -> void:
	_army = int(data.get("id", -1))
	_standing_now = str(data.get("standing", STANDING_HOLD))
	add_child(PanelKit.label("War", &"SectionHead"))
	_add_standing(game)
	_add_morale(game, data)
	_add_siege(game, data)
	_add_battle(data)
	_reason = PanelKit.reason("")
	_reason.visible = false
	add_child(_reason)


## The company line of a unit (its morale word, rank name and experience): "Steady · Veteran · 40 xp", "" when none.
static func company_words(unit: Dictionary) -> String:
	var parts := PackedStringArray()
	var word := str(unit.get("morale_word", ""))
	if word != "":
		parts.append(word)
	var rank := str(unit.get("rank_name", ""))
	if rank != "":
		parts.append(rank)
	parts.append("%d xp" % int(unit.get("xp", 0)))
	return " · ".join(parts)


## The standing: a Segmented "If attacked" with Hold and Withdraw; the price of Withdraw in its hover. The other segment is
## disabled with the check's reason when the rules refuse it.
func _add_standing(game: Game) -> void:
	add_child(_wrapped("If attacked", &"Hint"))
	var war := game.defs.war
	var seg := Segmented.new()
	seg.set_options([
		{"id": STANDING_HOLD, "label": "Hold", "tooltip": HOLD_TIP},
		{"id": STANDING_WITHDRAW, "label": "Withdraw",
			"tooltip": "Withdraw leaves after %d days; if it breaks first it flees." % war.withdraw_day},
	])
	seg.select(_standing_now)
	seg.changed.connect(_on_standing)
	add_child(seg)
	_standing = seg
	for id: String in [STANDING_HOLD, STANDING_WITHDRAW]:
		if id == _standing_now:
			continue
		var verdict := Session.check("set_standing", {"army": _army, "standing": id})
		var btn := seg.button_for(id)
		if btn != null and not bool(verdict["ok"]):
			btn.disabled = true
			btn.tooltip_text = str(verdict["reason"])


## The morale: a bar, "Morale 62 % · Wavering", and "Too shaken to attack" in Reason below the attack threshold.
func _add_morale(game: Game, data: Dictionary) -> void:
	var morale := int(data.get("morale", 0))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = float(morale) / 10.0
	bar.custom_minimum_size.y = 6.0
	add_child(bar)
	add_child(PanelKit.label("%s · %s" % [str(data.get("morale_text", "")), str(data.get("morale_word", ""))], &"TableRow"))
	if bool(data.get("too_shaken", false)):
		add_child(PanelKit.reason(SHAKEN_TEXT % (game.defs.war.attack_morale / 10)))


## The siege of a besieging army: "Besieging Pavia (10, 9): 6 of 10", the forecast, the storm's word and the Storm button.
func _add_siege(game: Game, data: Dictionary) -> void:
	var siege: Dictionary = data.get("siege", {})
	if siege.is_empty():
		return
	var hex: Vector2i = siege.hex
	add_child(PanelKit.label("Besieging %s: %d of %d" % [Words.place(game, hex), int(siege.progress), int(siege.need)], &"TableRow"))
	var falls := int(siege.get("falls_in", -1))
	if falls >= 0:
		add_child(_wrapped("Falls in about %s." % _seasons(falls), &"Hint"))
	var word := str(data.get("storm_word", ""))
	if word != "":
		add_child(_wrapped("Storm: %s." % word, &"Hint"))
	var btn := KitButton.new()
	btn.kind = KitButton.Kind.SECONDARY
	btn.text = STORM_TEXT
	btn.focus_mode = Control.FOCUS_ALL
	btn.hotkey_action = STORM_HOTKEY
	btn.show_key_cap = true
	btn.set_verdict(Session.check("storm", {"army": _army, "goal": hex}))
	btn.pressed.connect(_on_storm.bind(hex))
	add_child(btn)


## The battle in progress ("In battle: ...", "Open the battle") or, when none, the last battle of the country ("Last battle:
## ... (won)" with its link). The record id comes from the country's newest record when its name is the battle's; a battle with
## no record yet has nothing to open and its button says so.
func _add_battle(data: Dictionary) -> void:
	var battle: Dictionary = data.get("battle", {})
	var last: Dictionary = data.get("last_battle", {})
	if not battle.is_empty():
		add_child(PanelKit.label("In battle: %s" % str(battle.get("name", "")), &"TableRow"))
		add_child(_open_button(_record_of(battle, last)))
	elif not last.is_empty():
		add_child(_wrapped("Last battle: %s (%s)" % [str(last.get("name", "")), str(last.get("result", ""))], &"Hint"))
		add_child(_open_button(int(last.get("record", NO_RECORD))))


func _open_button(record: int) -> KitButton:
	var btn := KitButton.new()
	btn.kind = KitButton.Kind.SMALL
	btn.text = OPEN_TEXT
	btn.focus_mode = Control.FOCUS_ALL
	var verdict := {"ok": record >= 0, "reason": "" if record >= 0 else NO_RECORD_REASON}
	btn.set_verdict(verdict)
	btn.pressed.connect(func() -> void: battle_requested.emit(record))
	return btn


## The record of the army's battle: the country's newest record when it carries the battle's name, else NO_RECORD.
static func _record_of(battle: Dictionary, last: Dictionary) -> int:
	if int(last.get("record", NO_RECORD)) >= 0 and str(last.get("name", "")) == str(battle.get("name", "")):
		return int(last.record)
	return NO_RECORD


## A standing choice: the rules' order (set_standing); a refusal shows its reason and puts the Segmented back.
func _on_standing(id: Variant) -> void:
	var verdict := Session.act("set_standing", {"army": _army, "standing": str(id)})
	if bool(verdict["ok"]):
		return
	_show_reason(str(verdict["reason"]))
	_standing.select(_standing_now)


## The storm of the besieged hex (storm, with the goal the hex): a refusal shows its reason here; an allowed one is the map's
## order (asked first when risky, moves-build-spec.md R48). With no map it acts at once.
func _on_storm(hex: Vector2i) -> void:
	var args := {"army": _army, "goal": hex}
	var armies := MapArmies.in_tree(self)
	var verdict := Session.check("storm", args) if armies != null else Session.act("storm", args)
	if not bool(verdict["ok"]):
		_show_reason(str(verdict["reason"]))
		return
	if armies != null:
		_show_reason("")
		armies.storm(_army, hex)


func _show_reason(text: String) -> void:
	if _reason == null:
		return
	_reason.visible = text != ""
	_reason.text = "" if text == "" else text.substr(0, 1).to_upper() + text.substr(1) + "."


func _wrapped(text: String, variation: StringName) -> Label:
	var lbl := PanelKit.label(text, variation)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _seasons(n: int) -> String:
	return "%d season%s" % [n, "" if n == 1 else "s"]


## The standing shown (the Segmented's selection): for the tests.
func standing_id() -> String:
	return str(_standing.selected_id()) if _standing != null else ""


## The Segmented of the standing, for the tests and the keyboard path.
func standing_segment() -> Segmented:
	return _standing


## The Storm button of the besieging army, or null when the army besieges nothing.
func storm_button() -> KitButton:
	for child: Node in find_children("*", "KitButton", true, false):
		if str((child as KitButton).text) == STORM_TEXT:
			return child as KitButton
	return null


## The Open the battle buttons, in order.
func open_buttons() -> Array[KitButton]:
	var out: Array[KitButton] = []
	for child: Node in find_children("*", "KitButton", true, false):
		if str((child as KitButton).text) == OPEN_TEXT:
			out.append(child as KitButton)
	return out


## The reason line's text, "" when hidden.
func reason_text() -> String:
	return _reason.text if _reason != null and _reason.visible else ""
