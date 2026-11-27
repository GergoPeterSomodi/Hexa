## The tile window's fit (the owner's 540 banner design of 2026-11-26): full height under the top bar, no scrollbar, and every
## visible part inside the window at 1920 x 1080, 2560 x 1440 (UI scale 1.0), 1280 x 720 and 1024 x 600, on your own walled port
## town (Genoa, every live tab), another country's land, your fortress under siege, the sea and a never discovered hex. When the
## window is short the placeholder boxes hide first, then the facts' sections; the building strips, the siege block and the
## raise rows never hide. Placeholders never show on foreign land, at sea or in deep fog. Planted faults: a fixed 640 window (the
## height check), a scrollbar left on (the bar check), a placeholder on foreign land (the example check).
extends GutTest

const WINDOW := "res://shell/panels/tile_window.tscn"
const TAG := ArmyFixture.TAG
## The top bar the window docks under in these tests.
const BAR := 64.0
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1280, 720), Vector2i(1024, 600)]
## The one size where the body may fall back to scrolling (the owner's rule: only when the real content alone cannot fit there).
const SMALL := Vector2i(1024, 600)

## The cases that fell back to scrolling at SMALL (printed once at the end, for the report).
var _fallbacks: PackedStringArray = []

var _g: Game


func before_each() -> void:
	Bindings.ensure()
	_g = ArmyFixture.game()
	ArmyFixture.rich(_g)
	Session.start_game(_g)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


## A window docked at the right of a `logical` viewport (UI scale 1.0), under the bar.
func _window_at(logical: Vector2i) -> TileWindow:
	var sub := SubViewport.new()
	sub.size = logical
	add_child_autofree(sub)
	var win := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	sub.add_child(win)
	win.theme = KitTheme.load_for(1.0)
	win.position = Vector2(float(logical.x - Tokens.TILE_WINDOW_W), BAR)
	return win


func _named(place: String) -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if str(Improve.place_of(_g.map, hex).get("name", "")) == place:
			return hex
	return ArmyFixture.NO_HEX


func _case(name: String) -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if str(TileView.of(_g, TAG, hex).get("case", "")) == name:
			return hex
	return ArmyFixture.NO_HEX


## A fortress Genoa holds (another than Genoa when it has one, else Genoa itself), besieged by a neighbour at war with it (the
## defender reads the siege exact).
func _besieged_fortress() -> Vector2i:
	var fort := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if Occupation.fortress_level(_g, hex) > 0 and Occupation.controller_tag(_g, hex) == TAG:
			if fort == ArmyFixture.NO_HEX or fort == _named("Genoa"):
				fort = hex
	if fort == ArmyFixture.NO_HEX:
		return fort
	var enemy := WarFixture.neighbour_of(_g, TAG)
	WarFixture.at_war(_g, enemy, TAG)
	var s := Siege.new()
	s.hex = fort
	s.besieger = enemy
	s.progress = 2
	s.seasons = 1
	s.name = "Siege of Test, 1480"
	s.started_turn = _g.turn
	_g.sieges.append(s)
	_g.version += 1
	return fort


## Every case of the test, by name: Genoa (with a company raised there, so an army of yours stands on it), a foreign hex, a
## besieged fortress of Genoa's, the sea.
func _cases() -> Dictionary:
	var genoa := _named("Genoa")
	var kind := 0
	for unit: UnitDef in _g.defs.units:
		if unit.key == &"pikemen":
			kind = unit.id
	assert_true(bool(Session.act("raise", {"hex": genoa, "kind": kind, "count": 1}).get("ok", false)), "a company raised at Genoa")
	return {"own town": genoa, "foreign": _case("foreign"), "siege": _besieged_fortress(), "sea": _case("sea")}


## Every tab the window shows for its hex (none: the one body of a never discovered hex), each filled and fitted.
func _each_tab(win: TileWindow, check: Callable) -> void:
	var tabs: Array[StringName] = win.live_tab_ids()
	if tabs.is_empty():
		tabs.append(&"")
	for id: StringName in tabs:
		if id != &"":
			win.show_tab(id)
		var node := win.tab_node()
		if node != null and node.has_method("finish_now"):
			node.call("finish_now")
		await _frames(3)
		check.call(id)


## The visible Controls under `node` with a size (the parts a player sees).
func _visible_parts(node: Node, out: Array[Control], skip: Node = null) -> Array[Control]:
	for child: Node in node.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			var c := child as Control
			if c.size.x > 0.5 and c.size.y > 0.5:
				out.append(c)
			if c != skip:
				_visible_parts(c, out, skip)
	return out


func _examples_in(node: Node) -> int:
	var count := 0
	for c: Control in _visible_parts(node, []):
		if c.has_meta(&"example") or c is SoonTag:
			count += 1
	return count


func _check(win: TileWindow, logical: Vector2i, where: String, examples_allowed: bool) -> void:
	assert_almost_eq(win.size.y, float(logical.y) - BAR, 0.5, where + ": the window fills the height under the bar")
	assert_eq(win.size.x, float(Tokens.TILE_WINDOW_W), where + ": 540 wide")
	var scroll: Node = null
	if win.scrollbar_shown() and logical == SMALL:
		# The fallback: allowed only where every ranked part is already hidden (the real content alone does not fit).
		for node: Control in TileBoxes.ranked(win.get_node("%TabBody")):
			assert_false(node.visible, where + ": the body scrolls only after every ranked part (%s) is hidden" % node.name)
		_fallbacks.append(where)
		scroll = win.get_node("%Scroll")
	else:
		assert_false(win.scrollbar_shown(), where + ": no scrollbar")
	var box := win.get_global_rect().grow(0.5)
	var outside := 0
	for c: Control in _visible_parts(win, [], scroll):
		if not box.encloses(c.get_global_rect()):
			outside += 1
			if outside <= 3:
				assert_true(false, "%s: %s (%s) at %s is outside the window %s" % [where, c.name, c.get_class(), c.get_global_rect(), box])
	assert_eq(outside, 0, where + ": every visible part inside the window")
	if not examples_allowed:
		assert_eq(_examples_in(win), 0, where + ": no placeholder")


func test_no_scrollbar_and_everything_inside_at_four_sizes() -> void:
	var cases := _cases()
	for logical: Vector2i in SIZES:
		var win := _window_at(logical)
		for name: String in cases:
			var hex: Vector2i = cases[name]
			if hex == ArmyFixture.NO_HEX:
				continue
			win.show_hex(hex)
			await _each_tab(win, func(id: StringName) -> void:
				_check(win, logical, "%s %s on %s" % [str(logical), name, id], name == "own town" or name == "siege"))
	if not _fallbacks.is_empty():
		gut.p("The body scrolls (real content alone does not fit) at: " + ", ".join(_fallbacks))


func test_deep_fog_has_no_placeholder_and_fits() -> void:
	FogFixture.thin(_g, TAG, 0)
	_g.version += 1
	var deep := _case("unexplored")
	if deep == ArmyFixture.NO_HEX:
		pending("no undiscovered hex after thinning")
		return
	for logical: Vector2i in SIZES:
		var win := _window_at(logical)
		win.show_hex(deep)
		await _frames(3)
		_check(win, logical, "%s deep fog" % str(logical), false)
		assert_true(win.live_tab_ids().is_empty(), "no tabs on a never discovered hex")


func test_own_town_shows_its_placeholders_on_a_tall_screen_and_hides_them_first_on_a_short_one() -> void:
	var genoa := _named("Genoa")
	var tall := _window_at(Vector2i(1920, 1080))
	tall.show_hex(genoa)
	tall.show_tab(&"town")
	(tall.tab_node() as Object).call("finish_now")
	await _frames(3)
	assert_gt(_examples_in(tall), 0, "the Town tab of your own town shows placeholders at 1920 x 1080")
	var tab := tall.tab_node() as TownTab
	assert_true(tab.strips().is_visible_in_tree(), "the strips show")
	var small := _window_at(Vector2i(1024, 600))
	small.show_hex(genoa)
	small.show_tab(&"town")
	(small.tab_node() as Object).call("finish_now")
	await _frames(3)
	var short := small.tab_node() as TownTab
	assert_true(short.strips().is_visible_in_tree(), "the strips never hide")
	assert_gt(small.fit_hidden(), 0, "the short window hid ranked parts")
	# Whatever hid, no shown part outranks a hidden one: the highest ranks hide first.
	var lowest_hidden := 1000
	var highest_shown := -1
	for node: Control in TileBoxes.ranked(short):
		if node.visible:
			highest_shown = maxi(highest_shown, int(node.get_meta(TileBoxes.RANK)))
		else:
			lowest_hidden = mini(lowest_hidden, int(node.get_meta(TileBoxes.RANK)))
	assert_lte(highest_shown, lowest_hidden, "a shown part never outranks a hidden one")


## The HUD's frame in small (hud.tscn): a full-rect column of the top bar and the row below it, whose dock holds the window.
## A bar that grows or shrinks moves the dock's parents only, so the window must refit from its place on the screen (found by
## the monkey, seed 1508 step 307: the bar grew from 58 to 61 and the window hung 3 px below the screen).
func test_the_window_follows_the_top_bar_when_it_grows_or_shrinks() -> void:
	var sub := SubViewport.new()
	sub.size = Vector2i(1280, 720)
	add_child_autofree(sub)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	sub.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar := Control.new()
	bar.custom_minimum_size.y = 58.0
	column.add_child(bar)
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(main)
	var area := Control.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(area)
	var dock := VBoxContainer.new()
	main.add_child(dock)
	var win := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	dock.add_child(win)
	win.theme = KitTheme.load_for(1.0)
	win.show_hex(_named("Genoa"))
	await _frames(4)
	for height: float in [58.0, 61.0, 70.0, 58.0]:
		bar.custom_minimum_size.y = height
		await _frames(4)
		var rect := win.get_global_rect()
		assert_almost_eq(rect.position.y, height, 0.5, "a bar of %d: the window starts under it" % int(height))
		assert_almost_eq(rect.end.y, 720.0, 0.5, "a bar of %d: the window ends at the foot of the screen" % int(height))


func test_the_siege_block_and_the_raise_rows_never_hide() -> void:
	var fort := _besieged_fortress()
	if fort == ArmyFixture.NO_HEX:
		pending("Genoa holds no fortress")
		return
	var win := _window_at(Vector2i(1024, 600))
	win.show_hex(fort)
	win.show_tab(&"town")
	await _frames(3)
	var block := win.tab_node().find_child("SiegeBlock", false, false) as Control
	assert_not_null(block, "the siege block is drawn")
	assert_true(block.is_visible_in_tree(), "and shown at 1024 x 600")
	assert_false(block.has_meta(TileBoxes.RANK), "it carries no rank")
	var genoa := _named("Genoa")
	win.show_hex(genoa)
	if win.show_tab(&"army"):
		await _frames(3)
		for row: CompanyRow in (win.tab_node() as ArmyTab).company_rows():
			assert_true(row.is_visible_in_tree(), "the raise row %s shows at 1024 x 600" % row.name)
