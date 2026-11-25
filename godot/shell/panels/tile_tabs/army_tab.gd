## The Army tab of the tile window (tile-window spec R14, R21, R22, R24, R26, R27; the approved mockups, Appendix B). Two parts:
##   Armies here: the viewer's own armies on the hex (name, state line, men, and an open arrow that selects the army) and the
##   foreign armies in sight (named "An army of <country>", men exact, read-only: no arrow, no state line).
##   Raise a company here (own settlements only): the head line ("Men to levy ... raised this season"), the arms banner when
##   the model gives arms (absent until M9.5), one compact CompanyRow per kind, and "Show all", which asks the App for the
##   Raise companies window.
## The tab changes the game only through Session.act (the hammer: the old raise list's rule and toasts, unchanged) and
## requests the App for the rest (app_requested). The company hover card is CompanyCard.of, given through row_hovered.
## Only the open tab exists and the window rebuilds it on each refresh, so fill builds everything once.
class_name ArmyTab
extends TileTab

const ID := &"army"
const LABEL := "Army"
const ORDER := 30
const FIGURE_ARMY := &"army"
const OPEN_ICON := &"arrow_right"
const OPEN_FALLBACK := ">"
const ARMY_ICON_PX := 26
const ARMY_BUTTON := Vector2(28, 28)
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
	add_child(PanelKit.label("Armies here", &"SectionHead"))
	if rows.is_empty():
		add_child(PanelKit.label("No armies here", &"Hint"))
		return
	for row: Dictionary in rows:
		add_child(_army_row(row))


## One army: the figure, the title (own name, or "An army of <country>"), the state line (own only), the men exact, and the open
## arrow (own armies only).
func _army_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 9)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ARMY_ICON_PX, ARMY_ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_theme_icon(FIGURE_ARMY, &"Kit"):
		icon.texture = get_theme_icon(FIGURE_ARMY, &"Kit")
	line.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var own := bool(row.get("own", false))
	var title := str(row.get("name", "")) if own else "An army of %s" % str(row.get("country", ""))
	text.add_child(PanelKit.label(title, &"CompanyName"))
	var state := str(row.get("state_text", ""))
	if own and state != "":
		text.add_child(PanelKit.label(state, &"CompanyMeta"))
	line.add_child(text)
	line.add_child(PanelKit.label(str(row.get("men_text", "")), &"CompanyMeta"))
	if own:
		line.add_child(_open_button(row))
	return line


func _open_button(row: Dictionary) -> Button:
	var open := Button.new()
	open.theme_type_variation = &"ButtonIcon"
	open.focus_mode = Control.FOCUS_ALL
	open.mouse_filter = Control.MOUSE_FILTER_STOP
	open.custom_minimum_size = ARMY_BUTTON
	var name_text := str(row.get("name", ""))
	open.tooltip_text = "Select %s" % name_text
	open.accessibility_name = "Select %s" % name_text
	if has_theme_icon(OPEN_ICON, &"Kit"):
		open.icon = get_theme_icon(OPEN_ICON, &"Kit")
	else:
		open.text = OPEN_FALLBACK
	open.pressed.connect(_on_open_pressed.bind(int(row["id"])))
	_open.append(open)
	return open


func _on_open_pressed(army_id: int) -> void:
	app_requested.emit(&"select_army", {"army": army_id, "hex": _hex})


## The raise block of an own settlement: the head line, the arms banner (only when the model has arms), one compact row a kind
## and Show all.
func _build_raise(raise: Dictionary) -> void:
	add_child(PanelKit.label("Raise a company here", &"SectionHead"))
	add_child(PanelKit.label(str(raise.get("head", "")), &"Hint"))
	var arms: Dictionary = raise.get("arms", {})
	if not arms.is_empty():
		add_child(PanelKit.label("Arms in stores %s · %s" % [str(arms.get("in_stores", "")), str(arms.get("premium_text", ""))],
			&"Hint"))
	for row: Dictionary in raise.get("rows", []):
		var company := CompanyRow.make(row, CompanyRow.COMPACT)
		company.hammer_pressed.connect(raise_company)
		company.hovered.connect(_on_company_hovered.bind(company))
		company.unhovered.connect(_on_company_left)
		add_child(company)
		_rows.append(company)
	_show_all = KitButton.new()
	_show_all.kind = KitButton.Kind.SECONDARY
	_show_all.text = "Show all"
	_show_all.focus_mode = Control.FOCUS_ALL
	_show_all.mouse_filter = Control.MOUSE_FILTER_STOP
	_show_all.pressed.connect(_on_show_all_pressed)
	add_child(_show_all)


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
