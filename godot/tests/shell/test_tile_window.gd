## The tile window's frame (tile-window spec R10, R11, R13 to R17, R32 its part, R33, R34; build plan TW9): the header per
## case, the strip, the job line, the tab strip with dimmed tabs, R16's choice and fall-back, lazy tab bodies, one refresh per
## burst, the tab keys, and the width and height at both sizes. The tabs are in-memory stubs (TileTab scripts built from
## source), so the frame is tested before any real tab exists. Planted faults: a dimmed tab that opens (P), a dimmed tab left
## open after a refresh (P), a label too long for the strip (P), a second tab's children kept (P).
extends GutTest

const WINDOW := "res://shell/panels/tile_window.tscn"
## The stub tabs' rules, as expressions over `view` (the TileView of the hex).
const LAND_RULE := "view.get(\"case\", \"\") != \"unexplored\" and view.get(\"case\", \"\") != \"sea\""
const ALWAYS_LIVE := "\"\""
const BUILD_DIMMED := "\"\" if view[\"build\"][\"offered\"] else str(view[\"build\"][\"reason\"])"
const ARMY_DIMMED := "\"\" if view[\"army\"][\"raise_offered\"] or int(view[\"army\"][\"armies_seen\"]) > 0 else \"No armies here\""

var _window: TileWindow = null


func before_each() -> void:
	Bindings.ensure()
	var defs := Session.defs()
	var scenario: ScenarioDef = defs.scenarios[defs.scenarios.size() - 1]
	Session.new_scenario(scenario.id, MapScene.START_SEED, &"GEN")
	_window = (load(WINDOW) as PackedScene).instantiate() as TileWindow
	_window.theme = KitTheme.load_for(1.0)
	add_child_autofree(_window)


func after_each() -> void:
	TileTabs.reset()
	await get_tree().process_frame


## A GDScript tab from source: extends TileTab, with the given ID, LABEL, ORDER and rules. Its fill adds one Label named
## "Body" (and `rows` more named "Row<n>"), so a test can count what the open tab built. `extra` is more source.
func _stub(id: String, label: String, order: int, applies_expr: String, dimmed_expr: String, rows: int = 0,
		extra: String = "") -> GDScript:
	var source := "extends TileTab\n"
	source += "const ID := &\"%s\"\nconst LABEL := \"%s\"\nconst ORDER := %d\n\n" % [id, label, order]
	source += "static func applies(view: Dictionary) -> bool:\n\treturn %s\n\n" % applies_expr
	source += "static func dimmed(view: Dictionary) -> String:\n\treturn %s\n\n" % dimmed_expr
	source += "func fill(_game: Game, _viewer: StringName, _hex: Vector2i, _view: Dictionary) -> void:\n"
	source += "\tvar body := Label.new()\n\tbody.name = \"Body\"\n\tadd_child(body)\n"
	source += "\tfor i: int in %d:\n\t\tvar row := Label.new()\n\t\trow.name = \"Row%%d\" %% i\n\t\tadd_child(row)\n" % rows
	source += extra
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "stub tab %s parses" % id)
	return script


func _std_tabs() -> Array[GDScript]:
	var out: Array[GDScript] = []
	out.append(_stub("land", "Land", 10, LAND_RULE, ALWAYS_LIVE))
	out.append(_stub("buildings", "Buildings", 20, LAND_RULE, BUILD_DIMMED))
	out.append(_stub("army", "Army", 40, LAND_RULE, ARMY_DIMMED))
	return out


func _strip() -> StripCells:
	return _window.get_node("%Strip") as StripCells


func _tab_body() -> VBoxContainer:
	return _window.get_node("%TabBody") as VBoxContainer


func _tab_strip() -> HBoxContainer:
	return _window.get_node("%TabStrip") as HBoxContainer


func _picture() -> SettlementPicture:
	return _window.get_node("%Picture") as SettlementPicture


func _title() -> Label:
	return _window.get_node("%Title") as Label


func _place() -> Button:
	return _window.get_node("%Place") as Button


func _job() -> JobLine:
	return _window.get_node("%WorkBox") as JobLine


func _tab_button(id: StringName) -> Button:
	for child: Node in _tab_strip().get_children():
		if child.has_meta("tab_id") and child.get_meta("tab_id") == id:
			return child as Button
	return null


## The first hex of the map whose TileView (for the player) passes `pred`; NO_HEX when none does.
func _hex_where(pred: Callable) -> Vector2i:
	var game := Session.game
	var viewer := Session.player_tag()
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if bool(pred.call(TileView.of(game, viewer, hex))):
			return hex
	return HexPanelContract.NO_HEX


func _has_picture(view: Dictionary) -> bool:
	var head: Dictionary = view.get("header", {})
	return not (head.get("picture", {}) as Dictionary).is_empty()


func _own_land(view: Dictionary) -> bool:
	return str(view.get("case", "")) == "own"


func _own_settlement(view: Dictionary) -> bool:
	return _own_land(view) and bool(view["army"]["raise_offered"])


func _foreign(view: Dictionary) -> bool:
	return str(view.get("case", "")) == "foreign"


func _sea(view: Dictionary) -> bool:
	return str(view.get("case", "")) == "sea"


func _unexplored(view: Dictionary) -> bool:
	return str(view.get("case", "")) == "unexplored"


func _key(code: Key, ctrl: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	return event


# --- the frame per case -----------------------------------------------------------------------------------------------


func test_starts_hidden_with_no_hex() -> void:
	assert_false(_window.visible, "the window starts hidden")
	assert_eq(_window.shown_hex(), HexPanelContract.NO_HEX, "no hex is shown")
	assert_true(_window.tab_ids().is_empty(), "no tabs without a hex")


func test_own_land_shows_the_four_strip_cells_and_the_title() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	assert_true(_window.visible, "the window shows for a hex")
	assert_eq(_strip().cell_count(), 4, "own land has four strip cells")
	var view := TileView.of(Session.game, Session.player_tag(), hex)
	assert_eq(_title().text, str(view["header"]["title"]), "the title is the header's title")
	var expected := PackedStringArray()
	for cell: Dictionary in view["strip"]:
		expected.append(str(cell["value"]))
	assert_eq(_strip().values(), expected, "the strip shows the view's values in order")


func test_unexplored_shows_only_its_title() -> void:
	var hex := _hex_where(_unexplored)
	if hex == HexPanelContract.NO_HEX:
		pending("no undiscovered hex on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	assert_eq(_title().text, "Unexplored", "an undiscovered hex is titled Unexplored")
	assert_eq(_strip().cell_count(), 0, "no strip on an undiscovered hex")
	assert_true(_window.tab_ids().is_empty(), "no tabs on an undiscovered hex")
	assert_false(_job().visible, "no job line on an undiscovered hex")


func test_sea_hides_the_strip_and_the_tab_strip() -> void:
	var hex := _hex_where(_sea)
	if hex == HexPanelContract.NO_HEX:
		pending("no sea hex on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	assert_eq(_strip().cell_count(), 0, "sea has no strip cells")
	assert_false(_tab_strip().visible, "the tab strip hides when only Land is shown")


func test_settlement_shows_its_picture_and_other_land_does_not() -> void:
	var settlement := _hex_where(_has_picture)
	if settlement == HexPanelContract.NO_HEX:
		pending("no settlement on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(settlement)
	assert_true(_picture().visible, "a settlement shows the picture")
	assert_false(_picture().current_recipe().is_empty(), "the picture has a recipe")
	var plain := _hex_where(func(view: Dictionary) -> bool: return _foreign(view) and not _has_picture(view))
	if plain != HexPanelContract.NO_HEX:
		# Mockup v4 (issue 436): the wide picture is on every tile; other land shows the bare land, with no settlement in it.
		_window.show_hex(plain)
		assert_true(_picture().visible, "other land shows the bare land")
		for shape: Dictionary in _picture().current_recipe():
			assert_ne(shape["part"], &"house", "no house on land without a settlement")


func test_strip_values_match_the_view_on_foreign_land() -> void:
	var hex := _hex_where(_foreign)
	if hex == HexPanelContract.NO_HEX:
		pending("no foreign land on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	var view := TileView.of(Session.game, Session.player_tag(), hex)
	assert_eq(_strip().cell_count(), (view["strip"] as Array).size(), "one cell per view cell")


func test_owner_link_emits_the_owner_tag() -> void:
	var hex := _hex_where(_foreign)
	if hex == HexPanelContract.NO_HEX:
		pending("no foreign land on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	var view := TileView.of(Session.game, Session.player_tag(), hex)
	var tag: StringName = view["header"]["owner"]["tag"]
	assert_false(_place().disabled, "the owner link is live on owned land")
	var seen: Array[StringName] = []
	_window.country_requested.connect(func(t: StringName) -> void: seen.append(t))
	_place().pressed.emit()
	assert_eq(seen, [tag] as Array[StringName], "the link asks for the owner's country")


# --- tabs: which show, which open, dimmed ------------------------------------------------------------------------------


func test_own_land_opens_buildings_by_default() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	assert_eq(_window.tab_open(), &"buildings", "Buildings opens first when it is live (R16)")
	assert_eq(_tab_body().get_child_count(), 1, "only the open tab has a body")
	assert_eq(_tab_body().get_child(0).get_child(0).name, "Body", "the open tab filled itself")


func test_foreign_land_dims_buildings_and_opens_land() -> void:
	var hex := _hex_where(_foreign)
	if hex == HexPanelContract.NO_HEX:
		pending("no foreign land on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	assert_true(_window.tab_ids().has(&"buildings"), "Buildings shows on foreign land, dimmed")
	assert_false(_window.live_tab_ids().has(&"buildings"), "Buildings is not live on foreign land")
	assert_eq(_window.tab_open(), &"land", "Land opens when Buildings is dimmed")
	var button := _tab_button(&"buildings")
	assert_not_null(button, "the dimmed tab has a button")
	assert_true(button != null and button.disabled, "a dimmed tab is disabled (not clickable)")
	assert_true(button != null and button.tooltip_text != "", "a dimmed tab names its reason as tooltip")


func test_a_dimmed_tab_does_not_open_by_show_tab() -> void:
	var hex := _hex_where(_foreign)
	if hex == HexPanelContract.NO_HEX:
		pending("no foreign land on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	assert_false(_window.show_tab(&"buildings"), "a dimmed tab refuses to open")
	assert_eq(_window.tab_open(), &"land", "the open tab stays Land")


func test_only_the_open_tab_has_children_after_a_switch() -> void:
	var hex := _hex_where(_own_settlement)
	if hex == HexPanelContract.NO_HEX:
		pending("no own settlement that raises here")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	assert_true(_window.show_tab(&"army"), "a live tab opens")
	assert_eq(_tab_body().get_child_count(), 1, "the old tab is freed, only the new one has a body")
	assert_eq(_window.tab_open(), &"army", "Army is open")


func test_ctrl_bracket_steps_live_tabs_and_skips_dimmed() -> void:
	var hex := _hex_where(_foreign)
	if hex == HexPanelContract.NO_HEX:
		pending("no foreign land on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	assert_true(_window.handle_key(_key(KEY_BRACKETRIGHT, true)), "Ctrl+] is used")
	assert_eq(_window.tab_open(), &"land", "with one live tab, Ctrl+] stays on it (Buildings skipped)")
	assert_false(_window.handle_key(_key(KEY_BRACKETRIGHT, false)), "] alone is not a tab key")


func test_ctrl_bracket_cycles_all_live_tabs_on_own_land() -> void:
	var hex := _hex_where(_own_settlement)
	if hex == HexPanelContract.NO_HEX:
		pending("no own settlement that raises here")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	var live := _window.live_tab_ids()
	var start := _window.tab_open()
	_window.handle_key(_key(KEY_BRACKETRIGHT, true))
	assert_eq(_window.tab_open(), live[posmod(live.find(start) + 1, live.size())], "Ctrl+] steps to the next live tab")
	_window.handle_key(_key(KEY_BRACKETLEFT, true))
	assert_eq(_window.tab_open(), start, "Ctrl+[ steps back")


func test_screen_up_blocks_the_tab_keys() -> void:
	var hex := _hex_where(_own_settlement)
	if hex == HexPanelContract.NO_HEX:
		pending("no own settlement that raises here")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	var before := _window.tab_open()
	_window.screens_up = func() -> bool: return true
	assert_false(_window.handle_key(_key(KEY_BRACKETRIGHT, true)), "the keys do nothing while a screen is up")
	assert_eq(_window.tab_open(), before, "the open tab does not move")


func test_begin_option_goes_to_the_open_tab_when_it_takes_it() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	var tabs := _std_tabs()
	tabs[1] = _stub("buildings", "Buildings", 20, LAND_RULE, ALWAYS_LIVE, 0,
			"\nfunc begin_option(_option: Dictionary, _expensive: bool) -> void:\n\tset_meta(\"begun\", true)\n")
	_window.use_tabs(tabs)
	_window.show_hex(hex)
	assert_true(_window.begin_option({}, false), "the open Buildings tab takes the option")
	assert_true(_tab_body().get_child(0).has_meta("begun"), "the open tab got it")


# --- R16: the remembered tab and the fall-back -------------------------------------------------------------------------


func test_last_pick_opens_again_on_a_tile_where_it_is_live() -> void:
	var settlement := _hex_where(_own_settlement)
	var plain := _hex_where(func(view: Dictionary) -> bool: return _own_land(view) and not bool(view["army"]["raise_offered"]))
	if settlement == HexPanelContract.NO_HEX or plain == HexPanelContract.NO_HEX:
		pending("needs an own settlement and an own plain tile")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(settlement)
	_window.show_tab(&"army")
	_window.show_hex(plain)
	assert_eq(_window.tab_open(), &"buildings", "Army is dimmed on the plain tile: Buildings opens")
	_window.show_hex(settlement)
	assert_eq(_window.tab_open(), &"army", "the last pick (Army) opens again where it is live")


func test_refresh_falls_back_when_the_open_tab_turns_dimmed() -> void:
	var hex := _hex_where(_own_settlement)
	if hex == HexPanelContract.NO_HEX:
		pending("no own settlement that raises here")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	_window.show_tab(&"army")
	var closed := _std_tabs()
	closed[2] = _stub("army", "Army", 40, LAND_RULE, "\"Closed for the test\"")
	_window.use_tabs(closed)
	assert_eq(_window.tab_open(), &"buildings", "a dimmed open tab falls back to Buildings, no toast")
	assert_eq(_tab_body().get_child_count(), 1, "the fallback tab is the only body")


func test_one_refresh_per_burst() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	await get_tree().process_frame
	var before := _window.rebuilds
	Events.hex_changed.emit(hex)
	Events.hex_changed.emit(hex)
	Events.hex_changed.emit(hex)
	await get_tree().process_frame
	assert_eq(_window.rebuilds - before, 1, "three events in one frame make one refresh")


# --- R33: the width with five labels, the height at both sizes -------------------------------------------------------


func _five_tabs() -> Array[GDScript]:
	var out: Array[GDScript] = []
	var labels: Array[String] = ["Land", "Buildings", "Army", "Ships", "Industry"]
	for i: int in labels.size():
		out.append(_stub(labels[i].to_lower(), labels[i], 10 + i * 10, LAND_RULE, ALWAYS_LIVE))
	return out


func test_five_labels_fit_the_panel_width_in_both_themes() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_window.use_tabs(_five_tabs())
	var themes: Array[Theme] = [KitTheme.load_for(1.0), KitTheme.load_for(2.0), KitTheme.load_for(1.0, &"auto", true)]
	for theme: Theme in themes:
		_window.theme = theme
		_window.show_hex(hex)
		await get_tree().process_frame
		var total := float(_tab_strip().get_theme_constant("separation")) * float(maxi(_tab_strip().get_child_count() - 1, 0))
		for child: Node in _tab_strip().get_children():
			total += (child as Control).get_combined_minimum_size().x
		assert_eq(_tab_strip().get_child_count(), 5, "five tab buttons")
		# The tile window's own width since issue 436 (mockup v4), no longer the dock's PANEL_W.
		assert_true(total <= float(Tokens.TILE_WINDOW_W), "five labels fit %d px (they need %d)" % [Tokens.TILE_WINDOW_W, int(total)])


func _window_inside(size: Vector2i, ui_scale: float) -> bool:
	var sub := SubViewport.new()
	sub.size = size
	add_child_autofree(sub)
	var win := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	sub.add_child(win)
	win.theme = KitTheme.load_for(ui_scale)
	win.position = Vector2(0.0, float(Tokens.BAR_H))
	win.use_tabs(_long_tabs())
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		return true
	win.show_hex(hex)
	for i: int in 4:
		await get_tree().process_frame
	var bottom := win.position.y + win.size.y
	return bottom <= float(size.y) - float(Tokens.S2) + 0.5


func _long_tabs() -> Array[GDScript]:
	var out: Array[GDScript] = []
	out.append(_stub("land", "Land", 10, LAND_RULE, ALWAYS_LIVE, 120))
	return out


func test_window_stays_inside_the_viewport_at_both_sizes() -> void:
	assert_true(await _window_inside(Vector2i(1280, 720), 1.0), "1280 x 720 at scale 1 stays inside the viewport")
	assert_true(await _window_inside(Vector2i(2560, 1440), 2.0), "2560 x 1440 at scale 2 stays inside the viewport")


# --- issue 436: one size for every case and tab, legible text ----------------------------------------------------------


## A window with the real tabs in a 1280 x 720 viewport (scale 1, or the high-contrast theme), under a 64 px top bar.
func _real_window(high_contrast: bool) -> TileWindow:
	var sub := SubViewport.new()
	sub.size = Vector2i(1280, 720)
	add_child_autofree(sub)
	var win := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	sub.add_child(win)
	win.theme = KitTheme.load_for(1.0, &"auto", high_contrast)
	win.position = Vector2(984.0, 64.0)
	return win


## The hexes of each case this map has: own settlement, own plain land, foreign, sea, undiscovered.
func _case_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pred: Callable in [_own_settlement, func(v: Dictionary) -> bool: return _own_land(v) and not _has_picture(v),
			_foreign, _sea, _unexplored]:
		var hex := _hex_where(pred)
		if hex != HexPanelContract.NO_HEX:
			out.append(hex)
	return out


func test_the_window_is_one_size_for_every_case_and_tab() -> void:
	var win := _real_window(false)
	var sizes := {}
	for hex: Vector2i in _case_hexes():
		win.show_hex(hex)
		var tabs := win.live_tab_ids()
		if tabs.is_empty():
			tabs.append(&"")
		for id: StringName in tabs:
			if id != &"":
				win.show_tab(id)
			for i: int in 3:
				await get_tree().process_frame
			sizes["%s %s" % [hex, id]] = win.size
	assert_gt(sizes.size(), 4, "several cases and tabs were shown")
	for key: String in sizes:
		assert_eq(sizes[key], Vector2(Tokens.TILE_WINDOW_W, Tokens.TILE_WINDOW_H), "the window's size on %s" % key)


## Issue 436 (mockup v4): at UI scale 1.0, 1.25 and 1.5 (the App's content scale: a 1920 x 1080 window seen as 1920 x 1080,
## 1536 x 864 and 1280 x 720 logical pixels, its kit theme for that scale), the window is the same size on every case and tab,
## TILE_WINDOW_W wide, as tall as the room under a 64 px top bar allows up to TILE_WINDOW_H, and inside the viewport.
func test_the_window_is_one_size_for_every_case_and_tab_at_each_ui_scale() -> void:
	var physical := Vector2i(1920, 1080)
	for ui_scale: float in [1.0, 1.25, 1.5]:
		var logical := Vector2i(roundi(physical.x / ui_scale), roundi(physical.y / ui_scale))
		var sub := SubViewport.new()
		sub.size = physical
		sub.size_2d_override = logical
		sub.size_2d_override_stretch = true
		add_child_autofree(sub)
		var win := (load(WINDOW) as PackedScene).instantiate() as TileWindow
		sub.add_child(win)
		win.theme = KitTheme.load_for(ui_scale)
		win.position = Vector2(float(logical.x - Tokens.TILE_WINDOW_W), 64.0)
		var sizes := {}
		for hex: Vector2i in _case_hexes():
			win.show_hex(hex)
			var tabs := win.live_tab_ids()
			if tabs.is_empty():
				tabs.append(&"")
			for id: StringName in tabs:
				if id != &"":
					win.show_tab(id)
				var node := win.tab_node()
				if node != null and node.has_method("finish_now"):
					node.call("finish_now")
				for i: int in 3:
					await get_tree().process_frame
				sizes["%s %s" % [hex, id]] = win.size
		var want := Vector2(Tokens.TILE_WINDOW_W, minf(float(Tokens.TILE_WINDOW_H), float(logical.y) - 64.0 - float(Tokens.S2)))
		assert_gt(sizes.size(), 4, "several cases and tabs were shown at scale %s" % ui_scale)
		for key: String in sizes:
			assert_eq(sizes[key], want, "the window's size on %s at scale %s" % [key, ui_scale])
		assert_lte(win.get_rect().end.y, float(logical.y) + 0.5, "inside the viewport at scale %s" % ui_scale)


## Every label the window shows on a case and tab, with its colour: none uses a vellum ink (dark on the dark panel), none is
## faded by its ancestors, and each reads against the panel at 4.5 : 1 or better, in the Studiolo and the high-contrast theme.
func test_every_label_reads_on_the_dark_panel_in_both_themes() -> void:
	for high_contrast: bool in [false, true]:
		var win := _real_window(high_contrast)
		var panel: Color = Tokens.HIGH_CONTRAST["PANEL_BG"] if high_contrast else Tokens.PANEL_BG
		for hex: Vector2i in _case_hexes():
			win.show_hex(hex)
			var tabs := win.live_tab_ids()
			if tabs.is_empty():
				tabs.append(&"")
			for id: StringName in tabs:
				if id != &"":
					win.show_tab(id)
				var node := win.tab_node()
				if node != null and node.has_method("finish_now"):
					node.call("finish_now")
				await get_tree().process_frame
				_check_labels(win, panel, "%s %s hc=%s" % [hex, id, high_contrast])


func _check_labels(node: Node, panel: Color, where: String) -> void:
	if node is Label and (node as Label).is_visible_in_tree() and (node as Label).text != "":
		var label := node as Label
		assert_false(str(label.theme_type_variation).begins_with("LabelInk"), "%s: '%s' is vellum ink" % [where, label.text])
		var colour := label.get_theme_color(&"font_color")
		var ratio := Tokens.contrast_ratio(colour, panel)
		assert_gte(ratio, 4.5, "%s: '%s' (%s) reads at %.1f : 1" % [where, label.text, label.theme_type_variation, ratio])
		var at: Node = label
		while at != null and at is CanvasItem:
			assert_eq((at as CanvasItem).modulate.a, 1.0, "%s: '%s' is not faded" % [where, label.text])
			at = at.get_parent()
	for child: Node in node.get_children():
		_check_labels(child, panel, where)


# --- the owner's two mockup defects (issue 436): the close cross centred, the chips' numbers inside their pills ------------


func test_the_close_cross_is_drawn_centred_in_its_circle() -> void:
	var hex := _hex_where(_own_land)
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	await get_tree().process_frame
	var close := _window.close_button()
	assert_eq(close.text, "", "no text glyph (font metrics would move it)")
	assert_null(close.icon, "no icon either: two lines drawn about the centre")
	var cross := _window.close_glyph_rect()
	assert_almost_eq(cross.get_center().x, close.size.x * 0.5, 0.01, "centred across")
	assert_almost_eq(cross.get_center().y, close.size.y * 0.5, 0.01, "centred down")
	assert_true(Rect2(Vector2.ZERO, close.size).encloses(cross), "inside the button")


## The chips of these values, in a window of a 1280 or 1024 wide game at UI scale 1.0, 1.25 and 1.5: each number lies inside its
## pill, a value that fits is whole, a long one ends in an ellipsis, and the tooltip always says it whole.
func test_chip_numbers_stay_inside_their_pills_at_every_scale_and_width() -> void:
	var sets: Array = [["9,999,999", "9,999,999", "9,999,999", "9,999,999"], ["400 / 400", "6,200", "+11", "5,820"],
		["1,500 / 1,500", "9,800", "2", "fog"], ["29,500", "+11", "0 of 2", "100,585"]]
	var hex := _hex_where(_own_land)
	for width: int in [1280, 1024]:
		for ui_scale: float in [1.0, 1.25, 1.5]:
			var sub := SubViewport.new()
			var height := roundi(width * 9.0 / 16.0)
			sub.size = Vector2i(roundi(width * ui_scale), roundi(height * ui_scale))
			sub.size_2d_override = Vector2i(width, height)
			sub.size_2d_override_stretch = true
			add_child_autofree(sub)
			var win := (load(WINDOW) as PackedScene).instantiate() as TileWindow
			sub.add_child(win)
			win.theme = KitTheme.load_for(ui_scale)
			win.use_tabs(_std_tabs())
			win.show_hex(hex)
			var strip := win.get_node("%Strip") as StripCells
			for values: Array in sets:
				var cells: Array = []
				for v: Variant in values:
					cells.append({"key": "people", "value": str(v), "label": "People", "tone": "plain"})
				strip.show_cells(cells)
				for i: int in 2:
					await get_tree().process_frame
				_check_chips(strip, "%s at %d wide, scale %s" % [str(values), width, ui_scale])


func _check_chips(strip: StripCells, where: String) -> void:
	for chip: Node in strip.get_children():
		var pill := (chip as Control).get_global_rect().grow(0.5)
		var value := chip.find_child("Value", true, false) as Label
		var text := str(chip.get_meta("value"))
		assert_true(pill.encloses(value.get_global_rect()), "%s: '%s' lies inside its pill" % [where, text])
		assert_true(value.clip_text, "%s: '%s' clips rather than spill" % [where, text])
		assert_true((chip as Control).tooltip_text.contains(": " + text), "%s: the tooltip says '%s' whole" % [where, text])
		var font := value.get_theme_font(&"font")
		var need := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, value.get_theme_font_size(&"font_size")).x
		if text.length() <= 9:
			assert_lte(need, value.size.x + 0.5, "%s: '%s' fits whole (needs %d, has %d)" % [where, text, int(need), int(value.size.x)])


# --- the strip cells widget --------------------------------------------------------------------------------------------


func test_strip_cells_show_at_most_four_and_hide_when_empty() -> void:
	var strip := StripCells.new()
	add_child_autofree(strip)
	strip.show_cells([])
	assert_false(strip.visible, "no cells hide the strip")
	var cells: Array = []
	for i: int in 6:
		cells.append({"key": "k%d" % i, "value": "v%d" % i, "label": "L", "tone": "good"})
	strip.show_cells(cells)
	assert_true(strip.visible, "cells show the strip")
	assert_eq(strip.cell_count(), StripCells.MAX_CELLS, "a sixth cell is not shown")
	assert_eq(StripCells.variation_of(&"bad"), &"NumberBad", "a bad tone takes the bad number variation")


## The tab's request signals (TileTab) forwarded by the window: a stub with one poke per signal, emitted from the open tab.
const POKE := ("
func poke_hover() -> void:
	row_hovered.emit({\"row\": 1}, Rect2(1, 2, 3, 4))
"
	+ "
func poke_unhover() -> void:
	row_unhovered.emit()
"
	+ "
func poke_works() -> void:
	works_requested.emit({\"what\": &\"begin_work\", \"args\": {\"n\": 3}})
"
	+ "
func poke_toast() -> void:
	toast_requested.emit(\"Raised\", &\"good\")
"
	+ "
func poke_app() -> void:
	app_requested.emit(&\"raise_screen\", {\"hex\": Vector2i(1, 2)})
"
	+ "
func poke_open() -> void:
	open_tab_requested.emit(&\"land\")
")


func _poked_window(hex: Vector2i) -> void:
	var tabs := _std_tabs()
	tabs[1] = _stub("buildings", "Buildings", 20, LAND_RULE, ALWAYS_LIVE, 0, POKE)
	_window.use_tabs(tabs)
	_window.show_hex(hex)
	assert_eq(_window.tab_open(), &"buildings", "the poking tab is open")


func test_tab_row_hover_is_forwarded() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_poked_window(hex)
	var seen: Array = []
	_window.row_hovered.connect(func(card: Dictionary, anchor: Rect2) -> void: seen.append([card, anchor]))
	_tab_body().get_child(0).call("poke_hover")
	assert_eq(seen.size(), 1, "the window re-emits the tab's row_hovered once")
	assert_eq((seen[0] as Array)[0], {"row": 1}, "the card is forwarded")
	assert_eq((seen[0] as Array)[1], Rect2(1, 2, 3, 4), "the anchor is forwarded")


func test_tab_row_unhover_is_forwarded() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_poked_window(hex)
	var count := [0]
	_window.row_unhovered.connect(func() -> void: count[0] += 1)
	_tab_body().get_child(0).call("poke_unhover")
	assert_eq(count[0], 1, "the window re-emits row_unhovered")


func test_tab_works_request_is_forwarded_as_what_and_args() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_poked_window(hex)
	var seen: Array = []
	_window.works_requested.connect(func(what: StringName, args: Dictionary) -> void: seen.append([what, args]))
	_tab_body().get_child(0).call("poke_works")
	assert_eq(seen.size(), 1, "the window re-emits works_requested once")
	assert_eq((seen[0] as Array)[0], &"begin_work", "the request's what is forwarded")
	assert_eq((seen[0] as Array)[1], {"n": 3}, "the request's args are forwarded")


func test_tab_toast_is_forwarded() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_poked_window(hex)
	var seen: Array = []
	_window.toast_requested.connect(func(text: String, tone: StringName) -> void: seen.append([text, tone]))
	_tab_body().get_child(0).call("poke_toast")
	assert_eq(seen, [["Raised", &"good"]], "the window re-emits toast_requested")


func test_tab_app_request_is_forwarded() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_poked_window(hex)
	var seen: Array = []
	_window.app_requested.connect(func(what: StringName, args: Dictionary) -> void: seen.append([what, args]))
	_tab_body().get_child(0).call("poke_app")
	assert_eq(seen.size(), 1, "the window re-emits app_requested once")
	assert_eq((seen[0] as Array)[0], &"raise_screen", "the app request's what is forwarded")


func test_tab_open_request_opens_the_tab() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_poked_window(hex)
	_tab_body().get_child(0).call("poke_open")
	assert_eq(_window.tab_open(), &"land", "open_tab_requested opens the tab through show_tab")


func test_dimmed_tab_button_keeps_its_tooltip_and_takes_the_pointer() -> void:
	var hex := _hex_where(_foreign)
	if hex == HexPanelContract.NO_HEX:
		pending("no foreign land on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	var button := _tab_button(&"buildings")
	assert_not_null(button, "the dimmed tab has a button")
	if button == null:
		return
	assert_true(button.disabled, "the tab is disabled")
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP, "a disabled tab still takes the pointer, so its tooltip shows")
	assert_false(button.get_tooltip(Vector2.ZERO).is_empty(), "the reason is the tooltip")


func test_job_line_uses_the_window_viewer_not_game_player() -> void:
	var hex := _hex_where(_own_land)
	if hex == HexPanelContract.NO_HEX:
		pending("no own land on this map")
		return
	_window.use_tabs(_std_tabs())
	_window.show_hex(hex)
	var shown_by_viewer := not WorksView.at(Session.game, hex, Session.player_tag()).is_empty()
	assert_eq(_job().visible, shown_by_viewer, "the job line shows the work of the window's viewer")

