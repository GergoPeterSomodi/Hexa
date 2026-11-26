## The Town tab of the tile window (issue 436, the owner's decision of 2026-11-25: Land and Buildings are one tab, as EU5's
## Infrastructure tab). Top to bottom: the siege block when the tile is besieged (the owner's decision: a siege is a state of the
## tile, so it sits here and not on the Army tab; SiegeView.at for the viewer: the besieger and men where the viewer may know
## them, the meter, the forecast, Show siege), the building strips (building_strips.gd: one wooden strip per group with its icon tiles,
## on land the viewer may build on: own land and the sandbox), then the land facts (land_facts.gd: people and food, made here a
## year, the buildings of foreign land, ground and defence, armies out of sight, the Show buttons). Foreign and unowned land has
## no strips (nothing to build there): the facts alone. The work under way is the window's queue at its foot.
##
## The parts keep their own rules and tests (each is a TileTab, so its signals and fill are the same as when they were tabs);
## this tab only stacks them, forwards their signals, and answers the Buildings part's accessors for the window, the App and the
## tests (row_nodes, begin_option, finish_now...). Live on every case but unexplored; never dimmed.
class_name TownTab
extends TileTab

const ID := &"town"
const LABEL := "Town"
const ORDER := 10
const STRIPS := preload("res://shell/panels/tile_tabs/building_strips.gd")
const FACTS := preload("res://shell/panels/tile_tabs/land_facts.gd")
## The gap between the strips and the facts, in logical pixels.
const PART_GAP := 10
const SIEGE_TITLE := "Under siege"
const SIEGE_BY := "Under siege by %s"
const SIEGE_BUTTON := "Show siege"

## The Settings the strips' hammer reads (game/confirm_works); the window passes App.settings(). Null: the shipped default.
var settings: Settings = null:
	set(value):
		settings = value
		if _strips != null:
			_strips.set("settings", value)

var _strips: TileTab = null
var _facts: TileTab = null


## Shown for every land case and the sea; never for an undiscovered hex (the Land facts' rule).
static func applies(view: Dictionary) -> bool:
	return FACTS.applies(view)


## Never dimmed: where nothing can be built, the tab shows the facts.
static func dimmed(_view: Dictionary) -> String:
	return ""


## Whether the strips show for this view: building is offered here (own land or the sandbox).
static func buildable(view: Dictionary) -> bool:
	return bool((view.get("build", {}) as Dictionary).get("offered", false))


func fill(game: Game, viewer: StringName, hex: Vector2i, view: Dictionary) -> void:
	add_theme_constant_override(&"separation", PART_GAP)
	var siege := SiegeView.at(game, viewer, hex)
	if not siege.is_empty():
		add_child(_siege_block(siege, hex))
	if buildable(view):
		_strips = _part(STRIPS)
		_strips.set("settings", settings)
		_strips.fill(game, viewer, hex, view)
	_facts = _part(FACTS)
	_facts.fill(game, viewer, hex, view)


## The strips part (null where nothing can be built) and the facts part (tests and tools read them).
func strips() -> TileTab:
	return _strips


func facts() -> TileTab:
	return _facts


## The siege block (mockup v4, 6; issue 436 round 3, M5): "Under siege by <besieger>" where the viewer may know who (else "Under
## siege"), the men under it, Show siege (the map looks at the hex), the meter of progress over need with a tick a season, the
## season of the siege and, where the viewer knows it, "Falls in N seasons".
func _siege_block(siege: Dictionary, hex: Vector2i) -> PanelContainer:
	var box := PanelContainer.new()
	box.name = &"SiegeBlock"
	box.theme_type_variation = &"PanelTileSiege"
	box.tooltip_text = "This place is under siege: %s of %s. It falls when the meter is full, unless an army relieves it." % [
		Words.number(int(siege.get("progress", 0))), Words.number(maxi(int(siege.get("need", 1)), 1))]
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	box.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override(&"separation", 0)
	top.add_child(words)
	var besieger := str(siege.get("besieger_name", ""))
	var title := PanelKit.label(SIEGE_BY % besieger if besieger != "" else SIEGE_TITLE, &"TileName")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(title)
	var men := str(siege.get("men_text", ""))
	if men != "" and besieger != "":
		words.add_child(PanelKit.label("with %s" % men, &"TileHintBad"))
	var look := Button.new()
	look.theme_type_variation = &"ButtonTileAct"
	look.text = SIEGE_BUTTON
	look.tooltip_text = "Look at the besieged place on the map."
	look.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	look.pressed.connect(func() -> void: app_requested.emit(&"goto_hex", {"hex": hex}))
	top.add_child(look)
	var need := maxi(int(siege.get("need", 1)), 1)
	var progress := int(siege.get("progress", 0))
	var meter := ProgressBar.new()
	meter.name = &"SiegeMeter"
	meter.show_percentage = false
	meter.max_value = float(need)
	meter.value = float(mini(progress, need))
	meter.custom_minimum_size.y = 8.0
	column.add_child(meter)
	var seasons := int(siege.get("seasons", 0))
	var falls := int(siege.get("falls_in", -1))
	if falls > 0:
		# One tick a season of the whole siege as the viewer knows it: the seasons so far and those to its fall.
		var ticks := TileGlyph.make(TileGlyph.TICKS, 0.0)
		ticks.count = seasons + falls
		meter.add_child(ticks)
		ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	var foot := HBoxContainer.new()
	column.add_child(foot)
	var left := PanelKit.label("Season %s of the siege" % Words.number(maxi(seasons, 1)), &"TileHint")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(left)
	if falls >= 0:
		foot.add_child(PanelKit.label("Falls in %s season%s" % [Words.number(falls), "" if falls == 1 else "s"], &"TileHint"))
	return box


func _part(script: GDScript) -> TileTab:
	var part := script.new() as TileTab
	add_child(part)
	part.row_hovered.connect(func(card: Dictionary, anchor: Rect2) -> void: row_hovered.emit(card, anchor))
	part.row_unhovered.connect(func() -> void: row_unhovered.emit())
	part.works_requested.connect(func(request: Dictionary) -> void: works_requested.emit(request))
	part.toast_requested.connect(func(text: String, tone: StringName) -> void: toast_requested.emit(text, tone))
	part.app_requested.connect(func(what: StringName, args: Dictionary) -> void: app_requested.emit(what, args))
	part.open_tab_requested.connect(func(id: StringName) -> void: open_tab_requested.emit(id))
	return part


# --- the strips' accessors (the window, the App's works flow, the keys and the tests) -----------------------------------------


func row_nodes() -> Dictionary:
	return _strips.call("row_nodes") if _strips != null else {}


func row_data(id: StringName) -> Dictionary:
	return _strips.call("row_data", id) if _strips != null else {}


func begin_option(option: Dictionary, expensive: bool) -> void:
	if _strips != null:
		_strips.call("begin_option", option, expensive)


func press_row(id: StringName) -> void:
	if _strips != null:
		_strips.call("press_row", id)


func finish_now() -> void:
	if _strips != null:
		_strips.call("finish_now")


func is_done() -> bool:
	return _strips == null or bool(_strips.call("is_done"))


func pending() -> int:
	return int(_strips.call("pending")) if _strips != null else 0


func summary_text() -> String:
	return str(_strips.call("summary_text")) if _strips != null else ""


func visible_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if _strips != null:
		out.assign(_strips.call("visible_ids"))
	return out


func search_box() -> LineEdit:
	return _strips.call("search_box") as LineEdit if _strips != null else null


func filter_control() -> Segmented:
	return _strips.call("filter_control") as Segmented if _strips != null else null


func set_query(text: String) -> void:
	if _strips != null:
		_strips.call("set_query", text)


func set_filter(id: StringName) -> void:
	if _strips != null:
		_strips.call("set_filter", id)


func filter() -> StringName:
	return StringName(str(_strips.call("filter"))) if _strips != null else &""
