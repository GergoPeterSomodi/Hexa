## One page of the Statesman's Study (docs/architecture/m4-build-spec.md 6.7; the M4.5 tabs are m4-5-build-spec.md 6.3).
## The Study shows the page it picked, and asks it to refresh with the game and a tag. A row or "look there" in a page calls
## request([&"look_at", hex]); a map mode is request([&"map_mode", mode, hex]) and a country request([&"country", tag]); the
## Study turns them into ctx.request calls.
##
## Tabs: a page with `tabs` shows a Segmented strip of the tabs whose `since` milestone is at or before `milestone` (the strip
## shows from two tabs). A tab's body is the child named by its id, or its `scene` instanced under that name, or an empty box.
## Children named by a tab are hidden except the one in view; the others of the page stay as they are.
class_name StudyPage
extends VBoxContainer

signal action_requested(action: Array)
## Emitted when the tab in view changes (select_tab, step_tab, the strip, or focus).
signal tab_changed(tab: StringName)

const STRIP_NAME := "TabStrip"
const STRIP_LABEL := "Tabs"
const MIN_TABS_FOR_STRIP := 2

@export var page_id: StringName = &""

## The tabs of the page ({id, title, since, scene?}); none on a page without tabs.
@export var tabs: Array[Dictionary] = []

## The milestone the Study builds the page at ("4.5"): a tab with a later `since` is not shown.
var milestone: String = Bindings.SHELL_MILESTONE

## The shell's reduce-motion setting, set by the Study before each refresh: a tab switch is instant when true.
var reduce_motion: bool = false

var _tab: StringName = &""
var _strip: Segmented = null
var _hosts: Dictionary = {}
var _tabs_built: bool = false


func _ready() -> void:
	_ensure_tabs()


## Refills the page from the game. Subclasses override it; `tag` says why (open, season_ended, ...).
func refresh(_game: Game, _tag: StringName) -> void:
	pass


## Sends an action up to the Study: [&"look_at", hex], [&"map_mode", mode, hex?] or [&"country", tag].
func request(action: Array) -> void:
	action_requested.emit(action)


## The tabs whose `since` milestone is at or before `milestone`, in order; none when `milestone` is not a number.
func shown_tabs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not milestone.is_valid_float():
		return out
	var now := milestone.to_float()
	for entry: Dictionary in tabs:
		if str(entry.get("since", "0")).to_float() <= now:
			out.append(entry)
	return out


## The tab in view; &"" on a page with no shown tab.
func current_tab() -> StringName:
	_ensure_tabs()
	return _tab


## Shows `tab` (a shown tab id; any other changes nothing) and cross-fades to its body. Remembered for the page's life.
func select_tab(tab: StringName) -> void:
	_ensure_tabs()
	var entry := _shown_entry(tab)
	if entry.is_empty() or tab == _tab:
		return
	var from := _hosts.get(_tab) as Control
	var to := _host_for(tab, entry)
	_tab = tab
	Motion.cross_fade(from, to, reduce_motion)
	_sync_strip()
	tab_changed.emit(tab)


## Moves `delta` tabs along the shown tabs (Ctrl+[ is -1, Ctrl+] is 1). Stops at the first and the last tab.
func step_tab(delta: int) -> void:
	_ensure_tabs()
	var shown := shown_tabs()
	if shown.is_empty():
		return
	var at := 0
	for i: int in range(shown.size()):
		if StringName(str(shown[i].get("id", ""))) == _tab:
			at = i
	var target := clampi(at + delta, 0, shown.size() - 1)
	select_tab(StringName(str(shown[target].get("id", ""))))


## Called by the Study after each open with the focus the caller gave (a page's own keys go in its override).
## The default selects args.tab when it is given.
func focus(args: Dictionary) -> void:
	if args.has("tab"):
		select_tab(StringName(str(args["tab"])))


# ----- internals -----------------------------------------------------------------------------------------------------


## Builds the strip and shows the first shown tab, once. A page without tabs builds nothing.
func _ensure_tabs() -> void:
	if _tabs_built:
		return
	_tabs_built = true
	if tabs.is_empty():
		return
	for entry: Dictionary in tabs:  # every tab's child, shown or not, starts hidden
		var node := get_node_or_null(NodePath(str(entry.get("id", "")))) as Control
		if node != null:
			node.visible = false
	var shown := shown_tabs()
	_strip = Segmented.new()
	_strip.name = STRIP_NAME
	_strip.accessibility_name = STRIP_LABEL
	var items: Array = []
	for entry: Dictionary in shown:
		items.append({"id": StringName(str(entry.get("id", ""))), "label": str(entry.get("title", ""))})
	_strip.set_options(items)
	_strip.changed.connect(_on_strip_changed)
	add_child(_strip)
	move_child(_strip, 0)
	_strip.visible = shown.size() >= MIN_TABS_FOR_STRIP
	if shown.is_empty():
		return
	var first := StringName(str(shown[0].get("id", "")))
	_tab = first
	_host_for(first, shown[0]).visible = true
	_sync_strip()


func _shown_entry(tab: StringName) -> Dictionary:
	for entry: Dictionary in shown_tabs():
		if StringName(str(entry.get("id", ""))) == tab:
			return entry
	return {}


## The body of `id`: the child named by it, else its `scene` instanced under that name, else an empty box. Made once.
func _host_for(id: StringName, entry: Dictionary) -> Control:
	if _hosts.has(id):
		return _hosts[id] as Control
	var host := get_node_or_null(NodePath(String(id))) as Control
	if host == null:
		var path := str(entry.get("scene", ""))
		if path != "" and ResourceLoader.exists(path):
			host = (load(path) as PackedScene).instantiate() as Control
		else:
			host = VBoxContainer.new()
		host.name = String(id)
		host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(host)
	host.visible = false
	_hosts[id] = host
	return host


func _sync_strip() -> void:
	if _strip != null and _strip.selected_id() != _tab:
		_strip.select(_tab)


func _on_strip_changed(id: Variant) -> void:
	select_tab(StringName(str(id)))
