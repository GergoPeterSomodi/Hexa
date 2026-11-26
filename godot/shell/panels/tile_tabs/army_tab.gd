## The Army tab of the tile window (tile-window spec R14, R21, R22, R24, R26, R27; the approved mockups, Appendix B). Two parts:
##   Armies here: the viewer's own armies on the hex (name, state line, men, and an open arrow that selects the army) and the
##   foreign armies in sight (named "An army of <country>", men exact, read-only: no arrow, no state line).
##   Raise a company here (own settlements only): the head line ("Men to levy ... raised this season"), the arms banner when
##   the model gives arms (absent until M9.5), one compact CompanyRow per kind, and "Show all", which asks the App for the
##   Raise companies window. A refusal every row shares word for word (the season's cap: "Genoa (8, 13) has raised its 3
##   companies this season") is said once, under the head line, and the rows keep their own small line (issue 436).
## The tab changes the game only through Session.act (the hammer: the old raise list's rule and toasts, unchanged) and
## requests the App for the rest (app_requested). The company hover card is CompanyCard.of, given through row_hovered.
## Only the open tab exists and the window rebuilds it on each refresh, so fill builds everything once.
class_name ArmyTab
extends TileTab

const ID := &"army"
const LABEL := "Army"
const ORDER := 30
const FIGURE_ARMY := &"army"
const SELECT_TEXT := "Select"
const HEAD := &"TileHead"
const LAND_NOT := [&"sea", &"unexplored", &"sandbox"]

var _game: Game = null
var _viewer: StringName = &""
var _hex: Vector2i = HexPanelContract.NO_HEX
var _rows: Array[CompanyRow] = []
var _open: Array[Button] = []
var _show_all: KitButton = null


## Shown on every land case but the sandbox (R14): not sea, not unexplored, not the sandbox.
static func applies(view: Dictionary) -> bool:
	return not (view.get("case", &"") in LAND_NOT)


## Dimmed with the model's reason (TileView army.reason) when the viewer can neither raise here nor sees an army here.
static func dimmed(view: Dictionary) -> String:
	var army: Dictionary = view.get("army", {})
	if bool(army.get("raise_offered", false)) or int(army.get("armies_seen", 0)) > 0:
		return ""
	return str(army.get("reason", ""))


func fill(game: Game, viewer: StringName, hex: Vector2i, _view: Dictionary) -> void:
	_game = game
	_viewer = viewer
	_hex = hex
	var data := TileArmy.of(game, viewer, hex)
	_build_armies(data.get("armies", []))
	var raise: Dictionary = data.get("raise", {})
	if not raise.is_empty():
		_build_raise(raise)
	if _show_all != null:
		_show_all.theme_type_variation = &"ButtonTileSmall"  # after its _ready, which sets the kind's variation


## The rows of the armies here, for the tests: each army's row node (its open arrow sits on it, own armies only).
func open_buttons() -> Array[Button]:
	return _open.duplicate()


## The compact company rows, in display order.
func company_rows() -> Array[CompanyRow]:
	return _rows.duplicate()


## The Show all button, or null when no raise block is shown.
func show_all_button() -> KitButton:
	return _show_all


## A click on a company's hammer, or the tests' call: the raise of one company through Session.act (the old raise list's
## rule and its toasts, unchanged).
func raise_company(kind: int) -> void:
	var words := raised_text(_game, kind, _hex)
	var verdict := Session.act("raise", {"hex": _hex, "kind": kind, "count": 1})
	if bool(verdict.get("ok", false)):
		toast_requested.emit(words, &"plain")
	else:
		toast_requested.emit(str(verdict.get("reason", "")), &"warn")


## The toast of one company raised, before the act (the wording of the old raise list, unchanged):
## "Raised 1 company of pikemen at Turin (5, 9): −25 ducats, −1 iron."
static func raised_text(game: Game, kind: int, hex: Vector2i) -> String:
	var ud := Military.unit_def(game, kind)
	var cost := Military.cost_of(game, kind, 1)
	var parts: Array[String] = ["−%d ducats" % int(cost["ducats"])]
	for gid: int in game.defs.goods.size():
		var good := game.defs.good(gid)
		var key := String(good.key)
		if (cost["goods"] as Dictionary).has(key):
			parts.append("−%d %s" % [int(cost["goods"][key]), good.name.to_lower()])
	return "Raised 1 company of %s at %s: %s." % [ud.name.to_lower(), Military.hex_text(game, hex), ", ".join(parts)]


func _build_armies(rows: Array) -> void:
	add_theme_constant_override(&"separation", Tokens.S1 + 1)
	add_child(_head("Armies here", false))
	if rows.is_empty():
		add_child(PanelKit.label("No armies here", &"TileHint"))
		return
	for row: Dictionary in rows:
		add_child(_army_row(row))


## One army as mockup v4's small card: the figure on a wooden icon tile, the title (own name, or "An army of <country>"), one
## small line (the men, and for an own army its state), and the Select button (own armies only).
func _army_row(row: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelTileUnit"
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", Tokens.S2 + 2)
	card.add_child(line)
	line.add_child(icon_tile(self, FIGURE_ARMY))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 0)
	var own := bool(row.get("own", false))
	var title := str(row.get("name", "")) if own else "An army of %s" % str(row.get("country", ""))
	var name_label := PanelKit.label(title, &"TileName")
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(name_label)
	var men := str(row.get("men_text", ""))
	var state := str(row.get("state_text", ""))
	var points := str(row.get("points_text", "")) if own else ""
	var parts: Array[String] = [men]
	if own and state != "":
		parts.append(state)
	if points != "":
		parts.append(points)
	var small := PanelKit.label(" · ".join(parts), &"TileHint")
	card.tooltip_text = "%s: %s%s" % [title, small.text, "" if own else "
Not yours: seen, not commanded."]
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(small)
	line.add_child(text)
	if own:
		line.add_child(_open_button(row))
	return card


func _open_button(row: Dictionary) -> Button:
	var open := Button.new()
	open.theme_type_variation = &"ButtonTileAct"
	open.focus_mode = Control.FOCUS_ALL
	open.mouse_filter = Control.MOUSE_FILTER_STOP
	open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_text := str(row.get("name", ""))
	open.text = SELECT_TEXT
	open.tooltip_text = "Select %s" % name_text
	open.accessibility_name = "Select %s" % name_text
	open.pressed.connect(_on_open_pressed.bind(int(row["id"])))
	_open.append(open)
	return open


func _on_open_pressed(army_id: int) -> void:
	app_requested.emit(&"select_army", {"army": army_id, "hex": _hex})


## The raise block of an own settlement: the head, the counts on their own muted line under it (M4: green is for gains only), the
## shared refusal said once with a stop sign, the arms banner (only when the model has arms), one compact row a kind and Show all.
func _build_raise(raise: Dictionary) -> void:
	add_child(_head("Raise a company here", true))
	var head := PanelKit.label(str(raise.get("head", "")), &"TileHint")
	head.name = &"RaiseCounts"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(head)
	var rows: Array = raise.get("rows", [])
	var shared := shared_reason(rows)
	if shared != "":
		add_child(_refusal(_season_words(shared)))
	var arms: Dictionary = raise.get("arms", {})
	if not arms.is_empty():
		var banner := PanelKit.label("Arms in stores %s · %s" % [str(arms.get("in_stores", "")), str(arms.get("premium_text", ""))],
			&"TileHint")
		banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(banner)
	for raw: Variant in rows:
		var row := (raw as Dictionary).duplicate()
		row["reason_shared"] = shared != "" and str(row.get("reason", "")) == shared
		var company := CompanyRow.make(row, CompanyRow.COMPACT)
		company.hammer_pressed.connect(raise_company)
		company.hovered.connect(_on_company_hovered.bind(company))
		company.unhovered.connect(_on_company_left)
		add_child(company)
		_rows.append(company)
	_show_all = KitButton.new()
	_show_all.kind = KitButton.Kind.SMALL
	_show_all.text = "Show all"
	_show_all.size_flags_horizontal = Control.SIZE_SHRINK_END
	_show_all.focus_mode = Control.FOCUS_ALL
	_show_all.mouse_filter = Control.MOUSE_FILTER_STOP
	_show_all.pressed.connect(_on_show_all_pressed)
	add_child(_show_all)


## The shared refusal's words (M4): the season's cap reads "All 3 companies raised this season" (the town and the hex are the
## window's title already); any other refusal is said as the rule says it.
func _season_words(shared: String) -> String:
	var cap := Military.raise_cap(_game, _hex)
	if cap > 0 and Military.raised_here(_game, _viewer, _hex) >= cap:
		return "All %s companies raised this season" % Words.number(cap)
	return shared


## The refusal line: a red stop sign and the words, the reason whole as its tooltip.
func _refusal(words: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = &"Refusal"
	line.add_theme_constant_override(&"separation", Tokens.S2)
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.tooltip_text = words + "\nNo company can be raised here until the next season."
	var stop := TileGlyph.make(TileGlyph.STOP, 16.0)
	stop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(stop)
	var text := PanelKit.label(words, &"TileHintBad")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	return line


## A small-caps group head; `gap` puts room above it (a group after another).
static func _head(text: String, gap: bool) -> Label:
	var head := PanelKit.label(text, HEAD)
	head.uppercase = true
	if gap:
		head.custom_minimum_size.y = 26.0
		head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return head


## The refusal that every raise row shares word for word, when there are two rows or more and none is ready (the season's
## cap, or a town that may not raise): said once above the rows. "" when the rows differ or one may be raised.
static func shared_reason(rows: Array) -> String:
	if rows.size() < 2:
		return ""
	var first := ""
	for raw: Variant in rows:
		var row := raw as Dictionary
		var reason := str(row.get("reason", ""))
		if StringName(str(row.get("state", ""))) == TileArmy.STATE_READY or reason == "":
			return ""
		if first == "":
			first = reason
		elif reason != first:
			return ""
	return first


func _on_show_all_pressed() -> void:
	app_requested.emit(&"raise_screen", {"hex": _hex})


## The pointer or the keyboard is on a company row: its CompanyCard, anchored to the row. A kind with no card (not raisable
## here) shows none.
func _on_company_hovered(kind: int, company: CompanyRow) -> void:
	var card := CompanyCard.of(_game, _viewer, _hex, kind)
	if card.is_empty():
		return
	row_hovered.emit(card, Rect2(company.get_global_rect()))


func _on_company_left() -> void:
	row_unhovered.emit()
