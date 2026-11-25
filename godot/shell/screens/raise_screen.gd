## The Raise companies window (tile-window spec R27; TW14). Opened for one hex with open_for(hex): the place and the men to levy,
## the arms banner (only when the model gives arms), a search box, a filter (All, Can raise) and one tall CompanyRow per kind,
## from the same TileArmy rows the Army tab uses. A hammer raises one company through Session.act (never by touching the
## state); the window refreshes when the game version changes. Esc closes it (ScreenStack pops it). It reads only what
## TileArmy gives the viewer, so a foreign or fogged hex shows no rows and no place.
class_name RaiseScreen
extends Screen

const FILTER_ALL := &"all"
const FILTER_CAN := &"can"
const NO_HEX := Vector2i(-1, -1)
const NOTHING_NOTE := "No company can be raised here."
const NO_MATCH_NOTE := "No company matches."

@onready var _frame: ModalFrame = $Center/Frame

var _hex := NO_HEX
var _data: Dictionary = {}
var _version := -1
var _head: Label = null
var _banner: Label = null
var _search: LineEdit = null
var _filter: Segmented = null
var _rows_box: VBoxContainer = null
var _note: Label = null
var _rows: Array[CompanyRow] = []
var _retired: Array[Node] = []
var _ui_built := false


func _init() -> void:
	kind = Screen.Kind.MODAL
	screen_id = &"raise_screen"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_ensure_ui()
	_refresh()


func on_enter() -> void:
	_ensure_ui()
	_refresh()
	default_focus = get_path_to(_search)


## Esc closes the window (ScreenStack pops it).
func back() -> bool:
	return false


## Shows the window for `hex`.
func open_for(hex: Vector2i) -> void:
	_hex = hex
	if _ui_built:
		_refresh()


func shown_hex() -> Vector2i:
	return _hex


func frame() -> ModalFrame:
	_ensure_ui()
	return _frame


func head_label() -> Label:
	_ensure_ui()
	return _head


## The arms banner label (hidden while the model gives no arms).
func banner_label() -> Label:
	_ensure_ui()
	return _banner


func search_box() -> LineEdit:
	_ensure_ui()
	return _search


func filter_bar() -> Segmented:
	_ensure_ui()
	return _filter


func note_label() -> Label:
	_ensure_ui()
	return _note


## The tall company rows now shown, in display order.
func company_rows() -> Array[CompanyRow]:
	return _rows.duplicate()


## Sets the typed text and shows the matching rows, as typing does.
func set_query(text: String) -> void:
	_ensure_ui()
	_search.text = text
	_render()


## Picks the filter (FILTER_ALL or FILTER_CAN).
func set_filter(id: StringName) -> void:
	_ensure_ui()
	_filter.select(id, true)


## A click on a hammer, or the tests' call: one company of `kind_id` through Session.act, which checks again and does it or
## refuses with its words. The toast is the raise's words, or the refusal's reason.
func raise_company(kind_id: int) -> void:
	var words := ArmyTab.raised_text(Session.game, kind_id, _hex)
	var verdict := Session.act("raise", {"hex": _hex, "kind": kind_id, "count": 1})
	var ok := bool(verdict.get("ok", false))
	if ctx != null:
		ctx.toast(words if ok else str(verdict.get("reason", "")), &"plain" if ok else &"warn")
	_refresh(kind_id)


## Shows `raise` (a TileArmy raise block) as the content, until the next refresh reads the game again.
func show_raise(raise: Dictionary) -> void:
	_ensure_ui()
	_data = raise
	_render()


func _process(_delta: float) -> void:
	var game := Session.game
	if _ui_built and game != null and game.version != _version:
		_refresh()


func _ensure_ui() -> void:
	if _ui_built or _frame == null:
		return
	_ui_built = true
	_frame.closed.connect(_on_close_pressed)
	var body := _frame.body()
	_head = PanelKit.label("", &"Hint")
	_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_head)
	_banner = PanelKit.label("", &"Hint")
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.visible = false
	body.add_child(_banner)
	_search = LineEdit.new()
	_search.placeholder_text = "Search companies"
	_search.clear_button_enabled = true
	_search.accessibility_name = "Search companies"
	_search.text_changed.connect(_on_query_changed)
	body.add_child(_search)
	_filter = Segmented.new()
	_filter.set_options([{"id": FILTER_ALL, "label": "All"}, {"id": FILTER_CAN, "label": "Can raise"}])
	_filter.select(FILTER_ALL)
	_filter.changed.connect(_on_filter_changed)
	body.add_child(_filter)
	_rows_box = VBoxContainer.new()
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_rows_box)
	_note = PanelKit.label("", &"Hint")
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_note)
	default_focus = get_path_to(_search)


## Reads the game again, then draws. `keep_kind` is the row whose hammer had the focus (kept when it still can be).
func _refresh(keep_kind: int = -1) -> void:
	if not _ui_built:
		return
	var game := Session.game
	_version = game.version if game != null else -1
	_data = TileArmy.of(game, Session.player_tag(), _hex).get("raise", {}) if game != null else {}
	_render(keep_kind)


func _render(keep_kind: int = -1) -> void:
	PanelKit.clear_children(_rows_box, _retired)
	_rows.clear()
	var has_data := not _data.is_empty()
	_head.text = _head_text() if has_data else ""
	_head.visible = has_data
	var arms: Dictionary = _data.get("arms", {})
	_banner.visible = not arms.is_empty()
	_banner.text = ""
	if not arms.is_empty():
		_banner.text = "Arms in stores %s · %s" % [str(arms.get("in_stores", "")), str(arms.get("premium_text", ""))]
	_search.editable = has_data
	for row: Dictionary in _data.get("rows", []):
		if not _shown(row):
			continue
		var company := CompanyRow.make(row, CompanyRow.TALL)
		company.hammer_pressed.connect(raise_company)
		_rows_box.add_child(company)
		_rows.append(company)
	_note.visible = _rows.is_empty()
	_note.text = NOTHING_NOTE if not has_data else NO_MATCH_NOTE
	if keep_kind >= 0:
		_refocus.call_deferred(keep_kind)


func _refocus(kind_id: int) -> void:
	for company: CompanyRow in _rows:
		if company.kind == kind_id and not company.hammer().disabled and company.hammer().is_inside_tree():
			company.hammer().grab_focus()
			return


## The place and the men to levy: the place name only on a hex whose raise block exists (own settlement), so a foreign or
## fogged hex gives nothing away.
func _head_text() -> String:
	var place := Military.hex_text(Session.game, _hex) if Session.game != null else ""
	var head := str(_data.get("head", ""))
	return "%s · %s" % [place, head] if place != "" else head


func _shown(row: Dictionary) -> bool:
	var query := _search.text.strip_edges().to_lower()
	if query != "" and not str(row.get("name", "")).to_lower().contains(query):
		return false
	if _filter.selected_id() == FILTER_CAN:
		return StringName(str(row.get("state", ""))) == TileArmy.STATE_READY and int(row.get("can_raise", 0)) > 0
	return true


func _on_query_changed(_text: String) -> void:
	_render()


func _on_filter_changed(_id: Variant) -> void:
	_render()


func _on_close_pressed() -> void:
	finished.emit(&"close")


func _exit_tree() -> void:
	PanelKit.free_retired(_retired)
