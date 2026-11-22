## Army panel (docs/architecture/m6-build-spec.md section 6.5; L18, issue #208): the dock's view of one army, read from
## ArmyView.panel. Your own army: its head (the men, the companies here, the place as a link), its order with the buttons
## Hold and Continue march, its companies with a check box each (for Split off and Disband), its supply state, its upkeep
## and move points, and the actions Split off, Join and Disband. A seen foreign army (banded men, no ids) shows the
## country's arms and name, its men and place, and no buttons.
## Every button's enabled state and its reason come from the rules' checks (Session.check); a click goes through
## Session.act. Disband with no refund this season asks first: the Confirm screen goes out through confirm_requested.
## The panel grabs no focus and changes nothing on the map; its Esc is the App's ladder (clear the selection).
class_name ArmyPanel
extends PanelFrame

## The place link was pressed: the hex to look at.
signal look_at_requested(hex: Vector2i)
## A disband that needs a Confirm: the App pushes the screen. With no listener such a disband is not done.
signal confirm_requested(screen: Screen)
## A toast for the player: the words of a disband that was done (plain).
signal toast_requested(text: String, tone: StringName)
## An "Open the battle" press of the war part (ArmyWar): the battle's record id, for the App's dock (M7 6.8).
signal battle_requested(record: int)

const NO_ARMY := -1
const ICON_PX := 24
const FIGURE_PX := 32
const CHECK_PX := 22
const DISBAND_TITLE := "Disband %s?"
const DISBAND_SOME := "Disband %s of the %s?"
const CHOICE_DISBAND := {"id": &"confirm", "label": "Disband", "kind": "danger", "safe": false}
const CHOICE_KEEP := {"id": &"cancel", "label": "Keep", "kind": "secondary", "safe": true}

var _army: int = NO_ARMY
var _ticked: Dictionary = {}
var _join_into: int = NO_ARMY
var _notice: String = ""
var _retired: Array[Node] = []
var _actions_box: VBoxContainer = null
var _join_segment: Segmented = null
var _notice_label: Label = null
## The selection the first press of Disband armed (no Confirm listener): the second press on it disbands.
var _armed_key: String = ""


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = float(Tokens.PANEL_W)
	visible = false
	closed.connect(clear)
	_wire_bus()


func _exit_tree() -> void:
	_unwire_bus()
	PanelKit.free_retired(_retired)


## Shows the army `army_id` (of the player, or a seen foreign one). An id the viewer does not see hides the panel.
func show_army(army_id: int) -> void:
	if army_id != _army:
		_ticked = {}
		_join_into = NO_ARMY
		_armed_key = ""
		_clear_notice()
	_army = army_id
	refresh()
	if not visible:
		_army = NO_ARMY


## The army shown, or NO_ARMY when the panel is hidden.
func shown_army() -> int:
	return _army if visible else NO_ARMY


## Hides the panel and forgets its army (the close button does this too).
func clear() -> void:
	_army = NO_ARMY
	_ticked = {}
	_join_into = NO_ARMY
	_armed_key = ""
	_clear_notice()
	visible = false


## Rebuilds the panel from ArmyView.panel for the shown army; hides it when the viewer does not see that army.
func refresh() -> void:
	if not is_node_ready():
		return
	var game := Session.game
	var data: Dictionary = {}
	if game != null and _army != NO_ARMY:
		data = ArmyView.panel(game, Session.player_tag(), _army)
	if data.is_empty():
		visible = false
		return
	PanelKit.clear_children(body(), _retired)
	_actions_box = null
	_join_segment = null
	_notice_label = null
	if bool(data["mine"]):
		_fill_own(game, data)
	else:
		_fill_foreign(game, data)
	visible = true


## The companies a checkbox ticks (ids in unit order), for the test and the panel's own actions.
func ticked_units() -> PackedInt32Array:
	var out := PackedInt32Array()
	var army: Army = Armies.by_id(Session.game, _army) if Session.game != null else null
	if army == null:
		return out
	for u: Unit in army.units:
		if bool(_ticked.get(u.id, false)):
			out.append(u.id)
	return out


## Ticks or unticks a company (its check box); only the verdicts change, so the focus stays where it is.
func set_ticked(unit_id: int, on: bool) -> void:
	_ticked[unit_id] = on
	_armed_key = ""
	_clear_notice()
	_refresh_verdicts()


## Drops the notice line (a refusal or an armed disband) without a rebuild.
func _clear_notice() -> void:
	_notice = ""
	if _notice_label != null:
		_notice_label.text = ""
		_notice_label.visible = false


## The button of an action by its name ("halt", "continue_march", "split_army", "merge_armies", "disband"), or null.
func action_button(action: String) -> KitButton:
	for child: Node in body().find_children("*", "KitButton", true, false):
		var btn := child as KitButton
		if btn.has_meta(&"action") and str(btn.get_meta(&"action")) == action:
			return btn
	return null


## The Join segment of the other armies on the hex, or null when there is none.
func join_segment() -> Segmented:
	return _join_segment


## The notice line's text (a refusal, or the armed disband's "Press Disband again"), or "" when hidden.
func notice_text() -> String:
	return _notice_label.text if _notice_label != null and _notice_label.visible else ""


## The reason lines under the actions of the refused buttons, in panel order.
func reason_texts() -> Array[String]:
	var out: Array[String] = []
	if _actions_box == null:
		return out
	var box := _actions_box.get_node_or_null(^"Reasons")
	if box == null:
		return out
	for child: Node in box.get_children():
		if child is Label:
			out.append((child as Label).text)
	return out


# --- own army -------------------------------------------------------------------------------------------------------

func _fill_own(game: Game, data: Dictionary) -> void:
	var army := Armies.by_id(game, _army)
	cartouche_title = str(data["name"])
	var body_box := body()
	body_box.add_child(_head_row(game, army.tag, data))
	_add_section(body_box, "Order")
	_add_order(body_box, data)
	_add_war(body_box, game, data)
	_add_section(body_box, "Companies")
	_add_units(body_box, game, data)
	_add_section(body_box, "Supply")
	_add_supply(body_box, data)
	_add_costs(body_box, data)
	_add_section(body_box, "Actions")
	_actions_box = VBoxContainer.new()
	body_box.add_child(_actions_box)
	_rebuild_actions()
	_notice_label = PanelKit.reason(_notice)
	_notice_label.visible = _notice != ""
	body_box.add_child(_notice_label)
	_refresh_verdicts()


func _head_row(game: Game, tag: StringName, data: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_arms_of(game, tag))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var men := PanelKit.label("%s · %d of %d companies here" % [Words.men(int(data["men"])), (data["units"] as Array).size(),
		int(data["here"])], &"TableRow")
	men.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(men)
	col.add_child(_place_link(game, data["hex"] as Vector2i))
	row.add_child(col)
	return row


func _add_order(parent: VBoxContainer, data: Dictionary) -> void:
	var order := data["order"] as Dictionary
	var text := PanelKit.label(str(order["text"]), &"TableRow")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override(&"font_color", _order_tone(order))
	parent.add_child(text)
	if str(order["arrives_text"]) != "":
		parent.add_child(_wrapped(str(order["arrives_text"])))
	if str(order["waiting_text"]) != "":
		parent.add_child(_wrapped(str(order["waiting_text"])))
	var row := HBoxContainer.new()
	var hold := _action_button("Hold", "halt", KitButton.Kind.SECONDARY, &"hold")
	var cont := _action_button("Continue", "continue_march", KitButton.Kind.SECONDARY, &"march")
	hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.size_flags_stretch_ratio = 1.6  # its text, its lock or icon and its key cap need more room than Hold's
	row.add_child(hold)
	row.add_child(cont)
	parent.add_child(row)


## The war part (ArmyWar, M7 6.8): the standing, the morale, the siege and Storm, the battle. Its requests go out as battle_requested.
func _add_war(parent: VBoxContainer, game: Game, data: Dictionary) -> void:
	var war := ArmyWar.new()
	war.battle_requested.connect(func(record: int) -> void: battle_requested.emit(record))
	parent.add_child(war)
	war.fill(game, data)


## The units list: a check box, the figure, the kind, the men with a bar, and the raising line.
func _add_units(parent: VBoxContainer, game: Game, data: Dictionary) -> void:
	parent.add_child(_wrapped("Tick the companies to split off or disband."))
	for unit: Variant in data["units"] as Array:
		parent.add_child(_unit_row(game, unit as Dictionary))


func _unit_row(game: Game, unit: Dictionary) -> Control:
	var uid := int(unit["id"])
	var row := HBoxContainer.new()
	var box := CheckBox.new()
	box.focus_mode = Control.FOCUS_ALL
	box.button_pressed = bool(_ticked.get(uid, false))
	box.tooltip_text = "Select this company"
	box.accessibility_name = "Select %s" % str(unit["name"])
	box.toggled.connect(func(on: bool) -> void: set_ticked(uid, on))
	box.custom_minimum_size = Vector2(CHECK_PX, CHECK_PX)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)
	var fig := TextureRect.new()
	fig.custom_minimum_size = Vector2(FIGURE_PX, FIGURE_PX)
	fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ud := Military.unit_def(game, int(unit["kind"]))
	if ud != null and fig.has_theme_icon(ud.figure, &"Kit"):
		fig.texture = fig.get_theme_icon(ud.figure, &"Kit")
	row.add_child(fig)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override(&"separation", 0)
	var line := HBoxContainer.new()
	var name_label := PanelKit.label(str(unit["name"]), &"TableRow")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var full := int(unit["full"])
	var men := int(unit["men"])
	line.add_child(PanelKit.label("%s / %s men" % [Words.number(men), Words.number(full)], &"Hint"))
	col.add_child(line)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = float(maxi(full, 1))
	bar.value = float(men)
	bar.custom_minimum_size.y = 5.0
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(bar)
	var raise_text := "mustering" if bool(unit["mustering"]) else str(unit["raised_text"])
	var words := ArmyWar.company_words(unit)
	if words != "":
		raise_text += " · " + words
	var raise_line := PanelKit.label(raise_text, &"Hint")
	raise_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(raise_line)
	row.add_child(col)
	return row


func _add_supply(parent: VBoxContainer, data: Dictionary) -> void:
	var supply := data["supply"] as Dictionary
	var state := int(supply["state"])
	var tone := Tokens.GOOD
	if state == Supply.FORAGED:
		tone = Tokens.WARN
	elif state == Supply.HUNGRY:
		tone = Tokens.BAD
	var text := PanelKit.label(str(supply["text"]), &"TableRow")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override(&"font_color", tone)
	parent.add_child(text)
	var fed := str(supply["fed_text"])
	var lost := int(supply["lost_last"])
	if lost > 0:
		fed += " · %s lost last season" % Words.men(lost)
	parent.add_child(_wrapped(fed))


func _add_costs(parent: VBoxContainer, data: Dictionary) -> void:
	var chip := DeltaChip.new()
	chip.invert = true
	chip.set_delta(-int(data["upkeep"]), "ducats a season", "Upkeep")
	parent.add_child(chip)
	parent.add_child(PanelKit.label("Move points %d · Sight %d" % [int(data["mp"]), int(data["sight"])], &"Hint"))


# --- actions ----------------------------------------------------------------------------------------------------------

## Rebuilds the action rows: Split off, Join and Disband. Hold and Continue sit in the order block. The verdicts are set
## by _refresh_verdicts, which also lists the reasons of the refused buttons.
func _rebuild_actions() -> void:
	if _actions_box == null or _army == NO_ARMY:
		return
	PanelKit.clear_children(_actions_box, _retired)
	var row := HFlowContainer.new()
	row.add_child(_action_button("Split off", "split_army", KitButton.Kind.SECONDARY, &"split"))
	_actions_box.add_child(row)
	_add_join(_actions_box)
	var disband_row := HFlowContainer.new()
	disband_row.add_child(_action_button("Disband", "disband", KitButton.Kind.DANGER, &"disband"))
	_actions_box.add_child(disband_row)


## The Join row: a segment of the other armies of the player on the hex, and the button. No row when there is none.
func _add_join(parent: VBoxContainer) -> void:
	var others := _others_here()
	if others.is_empty():
		return
	if _join_into == NO_ARMY or not _has_other(others, _join_into):
		_join_into = int(others[0]["id"])
	var seg := Segmented.new()
	var items: Array = []
	for other: Dictionary in others:
		items.append({"id": int(other["id"]), "label": "%s (%s)" % [str(other["name"]), Words.men(int(other["men"]))]})
	seg.set_options(items)
	seg.select(_join_into)
	seg.changed.connect(func(id: Variant) -> void:
		_join_into = int(id)
		_refresh_verdicts())
	_join_segment = seg
	parent.add_child(seg)
	var row := HFlowContainer.new()
	row.add_child(_action_button("Join", "merge_armies", KitButton.Kind.SECONDARY, &"merge"))
	parent.add_child(row)


## Sets each action button's verdict from its check (every button of the panel, the order block's too) and lists the
## reasons of the refused ones under the actions.
func _refresh_verdicts() -> void:
	if _actions_box == null or _army == NO_ARMY:
		return
	var reasons := PackedStringArray()
	for child: Node in body().find_children("*", "KitButton", true, false):
		var btn := child as KitButton
		if not btn.has_meta(&"action"):
			continue
		var verdict := _verdict_of(str(btn.get_meta(&"action")))
		btn.set_verdict(verdict)
		if not bool(verdict["ok"]):
			reasons.append(str(verdict["reason"]))
	var box := _reasons_box()
	PanelKit.clear_children(box, _retired)
	for reason: String in reasons:
		box.add_child(PanelKit.reason(_capital_first(reason)))


func _reasons_box() -> VBoxContainer:
	var box := _actions_box.get_node_or_null(^"Reasons") as VBoxContainer
	if box == null:
		box = VBoxContainer.new()
		box.name = &"Reasons"
		_actions_box.add_child(box)
	return box


## The verdict of an action for the shown army (its check, with the ticked companies and the chosen Join army).
func _verdict_of(action: String) -> Dictionary:
	var args := {"army": _army}
	match action:
		"split_army":
			args["units"] = ticked_units()
			return Session.check("split_army", args)
		"merge_armies":
			args["into"] = _join_into
			return Session.check("merge_armies", args)
		"disband":
			return Session.check("disband", _disband_args_for(_disband_targets()))
		_:
			return Session.check(action, args)


## The arguments of one disband action for `targets`: the set of companies (args units), or the whole army (no units).
func _disband_args_for(targets: PackedInt32Array) -> Dictionary:
	var args := {"army": _army}
	if not _is_whole(targets):
		args["units"] = targets
	return args


func _action_button(text: String, action: String, kind: KitButton.Kind, icon: StringName) -> KitButton:
	var btn := KitButton.new()
	btn.kind = kind
	btn.text = text
	btn.icon_name = icon
	btn.focus_mode = Control.FOCUS_ALL
	btn.set_meta(&"action", action)
	btn.pressed.connect(_on_action_pressed.bind(action))
	if action == "continue_march":
		btn.hotkey_action = &"game_continue_march"
		btn.show_key_cap = true
	return btn


func _on_action_pressed(action: String) -> void:
	match action:
		"halt", "continue_march":
			_act(action, {"army": _army})
		"split_army":
			_act(action, {"army": _army, "units": ticked_units()})
			_ticked = {}
		"merge_armies":
			if _act(action, {"army": _army, "into": _join_into}):
				show_army(_join_into)
		"disband":
			_disband()


## Runs an action through Session.act; a refusal shows its reason. Returns whether it was done.
func _act(action: String, args: Dictionary) -> bool:
	var verdict := Session.act(action, args)
	_notice = "" if bool(verdict["ok"]) else str(verdict["reason"])
	refresh()
	return bool(verdict["ok"])


## Disband, as one action for the set. Confirm is skipped only when every company is refunded in full. Otherwise a Confirm
## goes out through confirm_requested when someone listens (freed again when nobody takes it on); with no listener the
## first press arms the disband and a second press on the same selection does it.
func _disband() -> void:
	var targets := _disband_targets()
	if _all_refunded(targets):
		_disband_now(targets)
		return
	if _has_confirm_listener():
		var confirm := _disband_confirm(targets)
		if confirm != null:
			confirm_requested.emit(confirm)
			if confirm.is_inside_tree():
				return
			confirm.free()
	var key := _targets_key(targets)
	if _armed_key == key:
		_disband_now(targets)
		return
	_armed_key = key
	var back := _refund_of(targets)
	var back_text := " and %s ducats come back" % Words.number(back) if back > 0 else ""
	_notice = "Press Disband again to confirm: %s go home%s." % [Words.men(_men_of(targets)), back_text]
	refresh()


## Whether some listener is connected to confirm_requested (the App pushes the Confirm).
func _has_confirm_listener() -> bool:
	return not get_signal_connection_list(&"confirm_requested").is_empty()


## True when every company the disband takes was raised this season on its home hex (its refund is in full).
func _all_refunded(targets: PackedInt32Array) -> bool:
	var army := Armies.by_id(Session.game, _army)
	if army == null:
		return false
	for u: Unit in army.units:
		if (_is_whole(targets) or targets.has(u.id)) and not (u.raised_turn == Session.game.turn and u.home == army.hex):
			return false
	return true


func _men_of(targets: PackedInt32Array) -> int:
	var army := Armies.by_id(Session.game, _army)
	var men := 0
	if army != null:
		for u: Unit in army.units:
			if _is_whole(targets) or targets.has(u.id):
				men += u.men
	return men


func _targets_key(targets: PackedInt32Array) -> String:
	var parts := PackedStringArray()
	for id: int in targets:
		parts.append(str(id))
	return ",".join(parts)


## The Confirm of a disband with nothing refunded: "Disband 2 companies of the Army of Turin?" and the men who go home.
func _disband_confirm(targets: PackedInt32Array) -> Confirm:
	var army := Armies.by_id(Session.game, _army)
	if army == null:
		return null
	var title := DISBAND_TITLE % army.name
	var count := targets.size()
	if not _is_whole(targets):
		title = DISBAND_SOME % [Words.units(count, _kind_def(army, targets)), army.name]
	var men := 0
	for u: Unit in army.units:
		if targets.has(u.id):
			men += u.men
	var body_text := "%s go home." % Words.men(men)
	var choices: Array[Dictionary] = [CHOICE_DISBAND, CHOICE_KEEP]
	return Confirm.ask(title, [body_text], choices, {"danger": true, "on_result": func(accepted: bool) -> void:
		if accepted:
			_disband_now(targets)})


## One Session.act for the whole set (or the whole army): the rules take every company or none (a refused set changes
## nothing), so the panel never leaves half of a disband behind.
func _disband_now(targets: PackedInt32Array) -> void:
	_armed_key = ""
	var words := _disband_words(targets)
	if _act("disband", _disband_args_for(targets)):
		_ticked = {}
		toast_requested.emit(words, &"plain")


## The toast of a disband, worked out before the act: "Disbanded 1 company of pikemen: +25 ducats back, 500 men home to
## Turin (5, 9)." The men go to the companies' home when they share one, else to the army's hex.
func _disband_words(targets: PackedInt32Array) -> String:
	var game := Session.game
	var army := Armies.by_id(game, _army)
	if army == null:
		return ""
	var drop: Array[Unit] = []
	for u: Unit in army.units:
		if _is_whole(targets) or targets.has(u.id):
			drop.append(u)
	if drop.is_empty():
		return ""
	var what := "1 company" if drop.size() == 1 else "%d companies" % drop.size()
	if drop.all(func(u: Unit) -> bool: return u.kind == drop[0].kind):
		what += " of " + Military.unit_def(game, drop[0].kind).name.to_lower()
	var parts: Array[String] = []
	var back := _refund_of(targets)
	if back > 0:
		parts.append("+%s ducats back" % Words.number(back))
	var home := drop[0].home if drop.all(func(u: Unit) -> bool: return u.home == drop[0].home) else army.hex
	parts.append("%s home to %s" % [Words.men(_men_of(targets)), Military.hex_text(game, home)])
	return "Disbanded %s: %s." % [what, ", ".join(parts)]


## The companies a disband takes: the ticked ones in unit order, or -1 (the whole army) when none is ticked.
func _disband_targets() -> PackedInt32Array:
	var ticked := ticked_units()
	if ticked.is_empty():
		return PackedInt32Array([-1])
	return ticked


func _is_whole(targets: PackedInt32Array) -> bool:
	return targets.size() == 1 and targets[0] == -1


## The ducats and goods back for the companies: only those raised this season on their home hex (the checks' rule).
func _refund_of(targets: PackedInt32Array) -> int:
	var army := Armies.by_id(Session.game, _army)
	if army == null:
		return 0
	var refund := 0
	for u: Unit in army.units:
		if (_is_whole(targets) or targets.has(u.id)) and u.raised_turn == Session.game.turn and u.home == army.hex:
			refund += u.paid
	return refund


## The unit definition shared by the targets, or null when they differ (the line then says "companies").
func _kind_def(army: Army, targets: PackedInt32Array) -> UnitDef:
	var kind := -2
	for u: Unit in army.units:
		if targets.has(u.id):
			if kind != -2 and kind != u.kind:
				return null
			kind = u.kind
	return Military.unit_def(Session.game, kind) if kind >= 0 else null


func _others_here() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var army := Armies.by_id(Session.game, _army)
	if army == null:
		return out
	for other: Army in Armies.at(Session.game, army.hex):
		if other.tag == army.tag and other.id != army.id:
			out.append({"id": other.id, "name": other.name, "men": other.men()})
	return out


func _has_other(others: Array[Dictionary], id: int) -> bool:
	for other: Dictionary in others:
		if int(other["id"]) == id:
			return true
	return false


# --- foreign army ---------------------------------------------------------------------------------------------------

func _fill_foreign(game: Game, data: Dictionary) -> void:
	var army := Armies.by_id(game, _army)
	cartouche_title = str(data["country"])
	var body_box := body()
	var row := HBoxContainer.new()
	row.add_child(_arms_of(game, army.tag))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(PanelKit.label(_capital_first(str(data["men_text"])), &"TableRow"))
	col.add_child(_place_link(game, data["hex"] as Vector2i))
	row.add_child(col)
	body_box.add_child(row)


# --- helpers ----------------------------------------------------------------------------------------------------------

func _arms_of(game: Game, tag: StringName) -> CountryArms:
	var arms := CountryArms.new()
	arms.small = true
	var card := CountryCard.of(game, tag)
	if not card.is_empty():
		arms.set_country(card["arms"] as Dictionary)
	return arms


func _place_link(game: Game, hex: Vector2i) -> KitButton:
	var btn := KitButton.new()
	btn.kind = KitButton.Kind.SMALL
	btn.text = Words.at(game, hex, "at")
	btn.tooltip_text = "Show this place on the map"
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(func() -> void: look_at_requested.emit(hex))
	return btn


func _add_section(parent: VBoxContainer, text: String) -> void:
	parent.add_child(PanelKit.label(text, &"SectionHead"))


func _wrapped(text: String) -> Label:
	var lbl := PanelKit.label(text, &"Hint")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _order_tone(order: Dictionary) -> Color:
	if str(order["halt_text"]) != "" or str(order["waiting_text"]) != "":
		return Tokens.WARN
	return Tokens.TEXT


func _capital_first(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


## Connects and disconnects the bus signals that refresh the panel.
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


## The bus signals that change an army's card; each one refreshes the panel while it is shown.
func _wiring() -> Array:
	return [
		[Events.army_changed, _on_army_event],
		[Events.army_raised, _on_army_raised],
		[Events.army_disbanded, _on_army_disbanded],
		[Events.army_starved, _on_army_starved],
		[Events.unit_lost, _on_unit_lost],
		[Events.march_halted, _on_march_halted],
		[Events.season_ended, _on_season_ended],
		[Events.controllers_changed, _on_war_changed],
		[Events.siege_started, _on_war_changed],
		[Events.siege_progress, _on_war_changed],
		[Events.siege_lifted, _on_war_changed],
		[Events.battle_ended, _on_war_changed],
		[Events.war_declared, _on_war_changed],
		[Events.peace_made, _on_war_changed],
	]


## A war signal (siege, battle, war or peace): the war part (Storm, the siege line, the battle) is rebuilt while the panel shows.
## Any arity is accepted, the signals carry different arguments.
func _on_war_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null) -> void:
	_refresh_if_shown()


func _refresh_if_shown() -> void:
	if visible:
		refresh()


func _on_army_event(_tag: StringName, _army_id: int) -> void:
	_refresh_if_shown()


func _on_army_raised(_tag: StringName, _hex: Vector2i, _army_id: int) -> void:
	_refresh_if_shown()


func _on_army_disbanded(_tag: StringName, _hex: Vector2i, _army_id: int) -> void:
	_refresh_if_shown()


func _on_army_starved(_tag: StringName, _army_id: int, _lost: int) -> void:
	_refresh_if_shown()


func _on_unit_lost(_tag: StringName, _army_id: int, _unit: int) -> void:
	_refresh_if_shown()


func _on_march_halted(_tag: StringName, _army_id: int, _why: StringName) -> void:
	_refresh_if_shown()


func _on_season_ended(_turn: int) -> void:
	_refresh_if_shown()
