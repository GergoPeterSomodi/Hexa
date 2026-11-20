## The Statesman's Study (docs/architecture/m4-build-spec.md 6.7): a PanelModal frame the window's size less 30 px, with the
## Ribbon, the date, Close (a KeyCap of I), a NavList of the shown pages, the PageHost and the key hints. One instance
## lives for the App's life. Esc, I and Close take it off the stack without freeing it, so the page, its scroll and
## its state are kept when the App pushes it again. A page's "look there" becomes ctx.request(&"look_at", {hex, select}).
class_name Study
extends Screen

const TITLE := "The Statesman's Study"
const DEFAULT_MILESTONE := "4"
const LOOK_ACTION := &"look_at"
const CLOSE_ACTION := &"game_study"
const PREV_ACTION := &"study_page_prev"
const NEXT_ACTION := &"study_page_next"
const HINT_BASE := "I: close · Enter: look there"
const PAGE_KEYS_HINT := "[ ]: page"
const HINT_JOIN := " · "
const PAGE_KEYS_FROM := 2

@onready var _ribbon: Ribbon = $Frame/VBox/Ribbon
@onready var _date: Label = $Frame/VBox/Head/Date
@onready var _close: KitButton = $Frame/VBox/Head/Close
@onready var _nav: NavList = $Frame/VBox/Body/NavList
@onready var _host: Control = $Frame/VBox/Body/PageHost
@onready var _hints: Label = $Frame/VBox/Hints

var _pages: Array[Dictionary] = []
var _configured: bool = false
var _current: StringName = &""
var _scrolls: Dictionary[StringName, ScrollContainer] = {}


func _init() -> void:
	kind = Screen.Kind.OPAQUE


func _ready() -> void:
	_close.text = "Close"
	_close.hotkey_action = CLOSE_ACTION
	_close.show_key_cap = true
	_close.accessibility_name = "Close"
	_close.pressed.connect(_close_study)
	_nav.selected.connect(open_page)
	_host.accessibility_name = TITLE
	if not _configured:
		_set_pages(StudyPages.shown(DEFAULT_MILESTONE))
	_rebuild_nav()
	_fit_ribbon()
	_refresh_date()


## The pages the Study shows, in order; each entry is {id, title, scene, since}. The App passes StudyPages.shown(milestone).
## A Study never configured shows StudyPages.shown(DEFAULT_MILESTONE).
func configure(entries: Array[Dictionary]) -> void:
	_set_pages(entries)
	_configured = true
	if is_node_ready():
		_rebuild_nav()


## Shows `page`; &"" the last page shown (or the first when none was). An id that is not shown changes nothing.
func open_page(page: StringName) -> void:
	if _pages.is_empty():
		return
	var id := page
	if id == &"":
		id = _current if _index_of(_current) >= 0 else StringName(str(_pages[0].get("id", "")))
	var entry := _entry_of(id)
	if entry.is_empty():
		push_error("Study.open_page: no shown page '%s'" % String(id))
		return
	if _scroll_for(id, entry) == null:
		return
	for key: Variant in _scrolls.keys():
		var key_id := StringName(str(key))
		_scrolls[key_id].visible = key_id == id
	_current = id
	_nav.select(id)
	var shown_page := current_page()
	if shown_page != null:
		shown_page.refresh(Session.game, &"open")
	_refresh_date()


func on_enter() -> void:
	_fit_ribbon()
	_refresh_date()
	if not Events.season_ended.is_connected(_on_season_ended):
		Events.season_ended.connect(_on_season_ended)
	open_page(_current)
	if is_inside_tree():
		var target: Control = _close
		var btn := _nav.button_for(_current)
		if btn != null:
			target = btn
		default_focus = get_path_to(target)


func on_exit() -> void:
	if Events.season_ended.is_connected(_on_season_ended):
		Events.season_ended.disconnect(_on_season_ended)


## Esc closes the Study (it stays alive for the next open).
func back() -> bool:
	_close_study()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _pressed(event, CLOSE_ACTION):
		accept_event()
		_close_study()
	elif _pressed(event, PREV_ACTION):
		accept_event()
		_step_page(-1)
	elif _pressed(event, NEXT_ACTION):
		accept_event()
		_step_page(1)


# ----- accessors (tests and the App read these; nothing here changes the study) -------------------------------------


func ribbon() -> Ribbon:
	return _ribbon


func close_button() -> KitButton:
	return _close


func nav() -> NavList:
	return _nav


func page_host() -> Control:
	return _host


func hint() -> Label:
	return _hints


func date_label() -> Label:
	return _date


## The hint line: "[ ]: page" is in it only from two pages.
func hint_text() -> String:
	if _pages.size() >= PAGE_KEYS_FROM:
		return HINT_BASE + HINT_JOIN + PAGE_KEYS_HINT
	return HINT_BASE


## "Spring 1480" for the game's turn; "" with no game.
func date_text() -> String:
	var game := Session.game
	if game == null:
		return ""
	return Calendar.date_text(game.turn, game.start_year)


func current_page_id() -> StringName:
	return _current


func current_page() -> StudyPage:
	if not _scrolls.has(_current):
		return null
	var scroll := _scrolls[_current]
	if scroll.get_child_count() == 0:
		return null
	return scroll.get_child(0) as StudyPage


## The ScrollContainer that holds page `id` (kept while the page is hidden), or null when it was never shown.
func page_scroll(id: StringName) -> ScrollContainer:
	if not _scrolls.has(id):
		return null
	return _scrolls[id]


# ----- internals -----------------------------------------------------------------------------------------------------


func _set_pages(entries: Array[Dictionary]) -> void:
	_pages.clear()
	for entry: Dictionary in entries:
		_pages.append(entry.duplicate())


func _rebuild_nav() -> void:
	var items: Array = []
	for entry: Dictionary in _pages:
		items.append({"id": entry.get("id", ""), "text": str(entry.get("title", ""))})
	_nav.set_items(items)
	if _index_of(_current) < 0:
		_current = &""
	if _current != &"":
		_nav.select(_current)
	_hints.text = hint_text()
	_hints.accessibility_name = _hints.text


func _index_of(id: StringName) -> int:
	for i: int in range(_pages.size()):
		if StringName(str(_pages[i].get("id", ""))) == id:
			return i
	return -1


func _entry_of(id: StringName) -> Dictionary:
	var idx := _index_of(id)
	if idx < 0:
		return {}
	return _pages[idx]


## The page's ScrollContainer, made on its first open: the scene is instanced once and then kept.
func _scroll_for(id: StringName, entry: Dictionary) -> ScrollContainer:
	if _scrolls.has(id):
		return _scrolls[id]
	var path := str(entry.get("scene", ""))
	var packed: PackedScene = null
	if ResourceLoader.exists(path):
		packed = load(path) as PackedScene
	var page_node: StudyPage = null
	if packed != null:
		page_node = packed.instantiate() as StudyPage
	if page_node == null:
		push_error("Study: no study page scene for '%s' at %s" % [String(id), path])
		return null
	page_node.page_id = id
	page_node.action_requested.connect(_on_page_action)
	page_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = String(id)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	scroll.add_child(page_node)
	_host.add_child(scroll)
	_scrolls[id] = scroll
	return scroll


func _step_page(step: int) -> void:
	if _pages.size() < PAGE_KEYS_FROM:
		return
	var idx := posmod(_index_of(_current) + step, _pages.size())
	open_page(StringName(str(_pages[idx].get("id", ""))))


func _on_page_action(action: Array) -> void:
	if action.size() < 2 or ctx == null:
		return
	if StringName(str(action[0])) != LOOK_ACTION:
		return
	ctx.request(LOOK_ACTION, {"hex": action[1], "select": true})


func _on_season_ended(_turn: int) -> void:
	_refresh_date()
	var shown_page := current_page()
	if shown_page != null:
		shown_page.refresh(Session.game, &"season_ended")


func _refresh_date() -> void:
	if not is_node_ready():
		return
	_date.text = date_text()
	_date.accessibility_name = _date.text


func _fit_ribbon() -> void:
	if _ribbon == null:
		return
	_ribbon.text = TITLE
	_ribbon.custom_minimum_size.x = maxf(Ribbon.MIN_WIDTH, _ribbon.single_line_width())


## Closes the Study: it leaves the stack and is not freed, so the App can push it again.
func _close_study() -> void:
	if ctx == null:
		return
	var stack := ctx.stack as ScreenStack
	if stack != null:
		stack.remove(self)


func _pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action, false, true)
