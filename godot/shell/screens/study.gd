## The Statesman's Study (docs/architecture/m4-build-spec.md 6.7): a PanelModal frame the window's size less 30 px, with the
## Ribbon, the date, Close (a KeyCap of I), a NavList of the shown pages, the PageHost and the key hints. One instance
## lives for the App's life. Esc, I and Close take it off the stack without freeing it, so the page, its scroll and
## its state are kept when the App pushes it again. A page's "look there" becomes ctx.request(&"look_at", {hex, select}) (the App
## pops the study first). While it is on the stack the study listens for tax_set, work_started, work_finished, work_cancelled
## and season_ended and refreshes the page in view; a page's [&"set_tax", level] is done here through Session.act (the App's
## tax_set handler makes the toast). The Economy page reads the shell's game/gain_treasury_only switch before each refresh.
## Ctrl+[ ] and Ctrl+] (study_tab_prev, study_tab_next) step the tabs of the page in view; [ ] still steps the pages.
## open_page(page, focus) gives the focus to the page, and last_open_ms times the open (the F3 line). Rankings is given the
## shell's settings (its span is state/study_span, as Economy's); Economy finds them through this screen's ctx.
class_name Study
extends Screen

const TITLE := "The Statesman's Study"
const DEFAULT_MILESTONE := "4"
const LOOK_ACTION := &"look_at"
const CLOSE_ACTION := &"game_study"
const PREV_ACTION := &"study_page_prev"
const NEXT_ACTION := &"study_page_next"
const TAX_ACTION := &"set_tax"
const TREASURY_KEY := "game/gain_treasury_only"
const PAGE_KEY := "state/study_page"
const HINT_CLOSE := "I: close"
const HINT_LOOK := "Enter: look there"
const PAGE_KEYS_HINT := "[ ]: page"
const TAB_KEYS_HINT := "Ctrl+[ ]: tab"
const HINT_JOIN := " · "
const PAGE_KEYS_FROM := 2
const TAB_KEYS_FROM := 2
const TAB_PREV_ACTION := &"study_tab_prev"
const TAB_NEXT_ACTION := &"study_tab_next"
const COUNTRY_ACTION := &"country"
const MAP_MODE_ACTION := &"map_mode"
const REDUCE_KEY := "accessibility/reduce_motion"

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
## The milestone the pages are built at: their tabs are shown from it (the App's SHELL_MILESTONE unless configure says).
var milestone: String = Bindings.SHELL_MILESTONE
## The synchronous part of the last open_page, in milliseconds (the F3 line).
var last_open_ms: float = 0.0
## The page and focus the next on_enter opens (queue_open): the App sets them before it pushes the study, so the page is
## built and timed once.
var _next_page: StringName = &""
var _next_focus: Dictionary = {}


func _init() -> void:
	kind = Screen.Kind.OPAQUE


func _ready() -> void:
	_close.text = "Close"
	# The date sits on the leather: the dim vellum flavour colour is unreadable there.
	_date.add_theme_color_override(&"font_color", Tokens.MUTED)
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
func configure(entries: Array[Dictionary], at_milestone: String = "") -> void:
	if at_milestone != "":
		milestone = at_milestone
	_set_pages(entries)
	_configured = true
	if is_node_ready():
		_rebuild_nav()


## Shows `page`; &"" the last page shown (or the first when none was). An id that is not shown changes nothing.
## `focus` goes to the page's focus() (a tab: {tab}). The synchronous part is timed into last_open_ms.
func open_page(page: StringName, focus: Dictionary = {}) -> void:
	var started := Time.get_ticks_usec()
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
	_remember_page(id)
	_refresh_shown(&"open")
	var shown_page := current_page()
	if shown_page != null:
		shown_page.focus(focus)
	_refresh_date()
	_refresh_hint()
	last_open_ms = float(Time.get_ticks_usec() - started) / 1000.0


## Names the page (&"" the last one) and its focus that the next push opens, in one open_page.
func queue_open(page: StringName, focus: Dictionary = {}) -> void:
	_next_page = page
	_next_focus = focus


func on_enter() -> void:
	_fit_ribbon()
	_refresh_date()
	_listen(true)
	var page := _next_page if _next_page != &"" and _index_of(_next_page) >= 0 else _current
	var focus := _next_focus
	_next_page = &""
	_next_focus = {}
	open_page(page, focus)
	if is_inside_tree():
		var target: Control = _close
		var btn := _nav.button_for(_current)
		if btn != null:
			target = btn
		default_focus = get_path_to(target)


func on_exit() -> void:
	_listen(false)


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
	elif _pressed(event, TAB_PREV_ACTION):
		accept_event()
		_step_tab(-1)
	elif _pressed(event, TAB_NEXT_ACTION):
		accept_event()
		_step_tab(1)


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


## The hint line: "[ ]: page" from two pages, "Ctrl+[ ]: tab" from two shown tabs of the page in view, then the look key.
func hint_text() -> String:
	var parts := PackedStringArray([HINT_CLOSE])
	if _pages.size() >= PAGE_KEYS_FROM:
		parts.append(PAGE_KEYS_HINT)
	var page := current_page()
	if page != null and page.shown_tabs().size() >= TAB_KEYS_FROM:
		parts.append(TAB_KEYS_HINT)
	parts.append(HINT_LOOK)
	return HINT_JOIN.join(parts)


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
	_refresh_hint()


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
	page_node.milestone = milestone
	page_node.reduce_motion = _reduce_motion()
	var rankings := page_node as PageRankings
	if rankings != null and ctx != null:
		rankings.settings = ctx.settings  # the span (state/study_span) is shared with Economy and kept
	page_node.action_requested.connect(_on_page_action)
	page_node.tab_changed.connect(_on_tab_changed)
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


func _step_tab(step: int) -> void:
	var page := current_page()
	if page != null:
		page.step_tab(step)


func _on_page_action(action: Array) -> void:
	if action.size() < 2 or ctx == null:
		return
	match StringName(str(action[0])):
		LOOK_ACTION:
			ctx.request(LOOK_ACTION, {"hex": action[1], "select": true})
		COUNTRY_ACTION:
			ctx.request(COUNTRY_ACTION, {"tag": action[1]})
		MAP_MODE_ACTION:
			var args := {"mode": action[1]}
			if action.size() >= 3:
				args["hex"] = action[2]
				args["select"] = false
			ctx.request(LOOK_ACTION, args)
		TAX_ACTION:
			var verdict := Session.act(String(TAX_ACTION), {"level": int(action[1])})
			if not bool(verdict.get("ok", false)):
				var reason := str(verdict.get("reason", ""))
				ctx.toast(reason.substr(0, 1).to_upper() + reason.substr(1) + ".", &"bad")
			_refresh_shown(&"tax_set")


## The page in view is filled again from the game, with the shell's measure switch set first.
func _refresh_shown(why: StringName) -> void:
	var shown_page := current_page()
	if shown_page == null:
		return
	shown_page.reduce_motion = _reduce_motion()
	var economy := shown_page as PageEconomy
	if economy != null:
		economy.treasury_only = ctx != null and ctx.settings != null and bool(ctx.settings.get_value(TREASURY_KEY))
	shown_page.refresh(Session.game, why)


## The shell's reduce-motion setting: a tab switch is instant then.
func _reduce_motion() -> bool:
	return ctx != null and ctx.settings != null and bool(ctx.settings.get_value(REDUCE_KEY))


## Keeps the last page in the setting state/study_page so a later run can open on it.
func _remember_page(id: StringName) -> void:
	if ctx != null and ctx.settings != null and str(ctx.settings.get_value(PAGE_KEY)) != String(id):
		ctx.settings.set_value(PAGE_KEY, String(id))


## The bus signals that change what the page shows: linked while the study is on the stack.
func _listen(on: bool) -> void:
	var pairs: Array = [
		[Events.season_ended, _on_season_ended], [Events.tax_set, _on_tax_set], [Events.work_started, _on_work_event],
		[Events.work_finished, _on_work_event], [Events.work_cancelled, _on_work_cancelled],
	]
	for pair: Array in pairs:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if on and not sig.is_connected(handler):
			sig.connect(handler)
		elif not on and sig.is_connected(handler):
			sig.disconnect(handler)


func _on_season_ended(_turn: int) -> void:
	_refresh_date()
	_refresh_shown(&"season_ended")


func _on_tax_set(_tag: StringName, _level: int) -> void:
	_refresh_shown(&"tax_set")


func _on_work_event(_tag: StringName, _hex: Vector2i, _work: Dictionary) -> void:
	_refresh_shown(&"work")


func _on_work_cancelled(_tag: StringName, _hex: Vector2i, _work: Dictionary, _why: StringName) -> void:
	_refresh_shown(&"work")


func _on_tab_changed(_tab: StringName) -> void:
	_refresh_hint()


func _refresh_hint() -> void:
	if not is_node_ready():
		return
	_hints.text = hint_text()
	_hints.accessibility_name = _hints.text


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
