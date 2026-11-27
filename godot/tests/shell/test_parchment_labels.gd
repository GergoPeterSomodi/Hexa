## The parchment map's dots, town names and icons, the fog and the times of a layout
## (docs/architecture/map-overview-build-spec.md R9 to R13; the country names: test_parchment_labels_names.gd).
## The checks read ParchmentLabels.placed() and measure it on their own. Each planted case (P) feeds a check what a
## wrong layout would give (one without the collision check, a name from the raw places, a viewer kept from setup),
## and the check must report it.
extends ParchmentLabelsCase


# ----- the kinds of each view (R9) ------------------------------------------------------------------------------------


func test_the_far_view_shows_countries_and_capital_dots_only() -> void:
	var g := _full()
	var labels := _labels(g)
	var items := _show(labels, g, 20.0)
	# A country is named unless even 14 px is longer than its room (a three-hex country this far off).
	var fit: Array[String] = []
	for entry: Dictionary in ParchmentView.country_names(g, GEN):
		if _name_width(entry["text"], 14) <= float(entry["span_px"]) * 20.0 / MapTiles.CELL.x:
			fit.append(entry["text"])
	var named: Array[String] = []
	for item: Dictionary in _of(items, ParchmentLabels.KIND_COUNTRY):
		named.append(item["text"])
	assert_eq(named, fit, "every country whose room holds its name is named")
	assert_gte(fit.size(), 11)
	var capitals := _of(items, ParchmentLabels.KIND_CAPITAL)
	assert_eq(capitals.size(), 10, "every capital has its dot")
	assert_true(_named(items, ParchmentLabels.KIND_CAPITAL).is_empty(), "no capital name far off")
	assert_true(_of(items, ParchmentLabels.KIND_TOWN).is_empty(), "no town far off")
	assert_true(_of(items, ParchmentLabels.KIND_ICON).is_empty(), "no icon in Terrain")


func test_the_town_view_adds_town_dots_and_names() -> void:
	var g := _full()
	var labels := _labels(g)
	var items := _show(labels, g, 50.0)
	assert_gt(_of(items, ParchmentLabels.KIND_COUNTRY).size(), 0)
	assert_eq(_named(items, ParchmentLabels.KIND_CAPITAL).size(), _of(items, ParchmentLabels.KIND_CAPITAL).size(),
		"every capital in view is named")
	var listed: Dictionary[Vector2i, Dictionary] = {}
	for town: Dictionary in ParchmentView.towns(g, GEN):
		listed[town["hex"]] = town
	assert_eq(_of(items, ParchmentLabels.KIND_TOWN).size() + _of(items, ParchmentLabels.KIND_CAPITAL).size(),
		listed.size(), "the whole map is in view: every town has its dot")
	assert_gt(_named(items, ParchmentLabels.KIND_TOWN).size(), 0, "towns are named")
	var villages := 0
	for item: Dictionary in _of(items, ParchmentLabels.KIND_TOWN):
		var town := listed[item["hex"]]
		if int(town["level"]) < ParchmentView.TOWN_NAME_LEVEL:
			villages += 1
			assert_eq(str(item["text"]), "", "a village has its dot only")
		elif str(item["text"]) != "":
			assert_eq(str(item["text"]), str(town["name"]))
			assert_between(int(item["size"]), 13, 17)
	assert_gt(villages, 0, "north Italy has villages")
	for item: Dictionary in _named(items, ParchmentLabels.KIND_CAPITAL):
		assert_eq(int(item["size"]), ParchmentLabels.CAPITAL_FONT_PX)


func test_the_town_view_fades_in_from_24_to_28_px() -> void:
	assert_eq(ParchmentLabels.town_fade(24.0), 0.0)
	assert_almost_eq(ParchmentLabels.town_fade(26.0), 0.5, 0.001)
	assert_eq(ParchmentLabels.town_fade(28.0), 1.0)
	var g := _full()
	var labels := _labels(g)
	assert_true(_of(_show(labels, g, 23.9), ParchmentLabels.KIND_TOWN).is_empty())
	var mid := _of(_show(labels, g, 26.0), ParchmentLabels.KIND_TOWN)
	assert_gt(mid.size(), 0)
	assert_almost_eq(float(mid[0]["name_alpha"]), 0.5, 0.001)


func test_goods_mode_puts_an_icon_on_each_district_of_the_good_from_16_px() -> void:
	var g := _full()
	var labels := _labels(g)
	var good := _good_with_districts(g, GEN)
	labels.set_good(good)
	labels.set_mode(MapModes.Mode.GOODS)
	assert_true(_of(_show(labels, g, 15.0), ParchmentLabels.KIND_ICON).is_empty(), "no icon under 16 px")
	var bytes := ParchmentView.goods_bytes(g, GEN)
	for hex_px: float in [20.0, 50.0, 104.0]:
		var items := _show(labels, g, hex_px)
		var icons := _of(items, ParchmentLabels.KIND_ICON)
		assert_gt(icons.size(), 0, "icons at %s px" % hex_px)
		assert_lte(icons.size(), ParchmentView.count_of(g, GEN, good))
		var wrong := 0
		var with_icon: Dictionary[Vector2i, bool] = {}
		for item: Dictionary in icons:
			var i := g.map.index_of(item["hex"])
			with_icon[item["hex"]] = true
			if int(bytes[i * 2]) != good + 1 or int(bytes[i * 2 + 1]) != int(item["stage"]):
				wrong += 1
		assert_eq(wrong, 0, "each icon is on a district of the good, with its stage")
		assert_eq(with_icon.size(), icons.size(), "one icon a district")
		# A district whose whole hex is clear of every name and dot carries its icon.
		var xform := _view(g, hex_px)
		for i: int in g.map.hex_count():
			if int(bytes[i * 2]) != good + 1:
				continue
			var hex := g.map.hex_of(i)
			var cell := Rect2(xform * MapTiles.cell_centre(hex), Vector2.ZERO).grow(hex_px * 0.5)
			var clear := items.all(func(other: Dictionary) -> bool:
				return other["kind"] == ParchmentLabels.KIND_ICON or not _meets(cell, other))
			if clear:
				assert_true(with_icon.has(hex), "%s has its icon at %s px" % [hex, hex_px])
	labels.queue_redraw()
	await wait_process_frames(2)
	var icon: StringName = _of(labels.placed(), ParchmentLabels.KIND_ICON)[0]["icon"]
	assert_not_null(labels._icon_texture(icon), "the Kit icon of the good is found")
	labels.set_mode(MapModes.Mode.OWNER)
	assert_true(_of(labels.placed(), ParchmentLabels.KIND_ICON).is_empty(), "no icon outside Goods")


# ----- the icons and the names (R7, R10) ------------------------------------------------------------------------------


## Every good's icons at this view: how many, of how many districts, how many lie over a country name, and what they
## overlap that they must not (_icon_overlaps).
func _icons_of_all_goods(labels: ParchmentLabels, g: Game, hex_px: float, cover: Array[Rect2]) -> Dictionary:
	var icons_placed := 0
	var districts := 0
	var over_names := 0
	var problems: Array[String] = []
	for good: Dictionary in ParchmentView.goods_list(g):
		labels.set_good(good["id"])
		var items := _show(labels, g, hex_px)
		var icons := _of(items, ParchmentLabels.KIND_ICON)
		icons_placed += icons.size()
		districts += ParchmentView.count_of(g, GEN, good["id"])
		for icon: Dictionary in icons:
			var box: Rect2 = icon["rect"]
			if _of(items, ParchmentLabels.KIND_COUNTRY).any(func(name: Dictionary) -> bool: return _meets(box, name)):
				over_names += 1
		problems.append_array(_icon_overlaps(items, cover))
	return {"icons": icons_placed, "districts": districts, "over_names": over_names, "problems": problems}


## The icons that overlap another icon, a capital or town (its dot, or its name) or a cover rect.
func _icon_overlaps(items: Array[Dictionary], cover: Array[Rect2]) -> Array[String]:
	var out: Array[String] = []
	var icons := _of(items, ParchmentLabels.KIND_ICON)
	for n: int in icons.size():
		var box: Rect2 = icons[n]["rect"]
		for m: int in n:
			if box.intersects(icons[m]["rect"]):
				out.append("icon %s over icon %s" % [icons[n]["hex"], icons[m]["hex"]])
		for rect: Rect2 in cover:
			if box.intersects(rect):
				out.append("icon %s under the cover" % icons[n]["hex"])
		for other: Dictionary in items:
			if other.has("dot") and _meets(box, other):
				out.append("icon %s over %s %s" % [icons[n]["hex"], other["kind"], other["hex"]])
	return out


func test_a_country_name_costs_no_district_its_icon() -> void:
	var g := _full()
	var labels := _labels(g)
	labels.set_mode(MapModes.Mode.GOODS)
	# North Italy's whole-map view: every district carries its icon, and a country name finds room clear of them at its own
	# size but for three of timber's (fifteen districts).
	var whole := _icons_of_all_goods(labels, g, 68.0, [])
	assert_gt(int(whole["districts"]), 40)
	assert_eq(int(whole["icons"]), int(whole["districts"]), "every district has its icon at 68 px")
	assert_between(int(whole["over_names"]), 1, 3, "an icon lies over a country name only where the name has no room")
	assert_eq(whole["problems"], [] as Array[String])
	# Farther out capitals and dots take some spots, but the names still take none: as many icons as with no names.
	var far := _icons_of_all_goods(labels, g, 36.0, [])
	var bare := _labels(g, NoNames.new())
	bare.set_mode(MapModes.Mode.GOODS)
	var without := _icons_of_all_goods(bare, g, 36.0, [])
	assert_gt(int(far["over_names"]), 0)
	assert_eq(int(far["icons"]), int(without["icons"]), "country names cost no icon at 36 px")
	assert_eq(far["problems"], [] as Array[String])


func test_icons_overlap_no_icon_capital_dot_or_cover() -> void:
	var g := _full()
	var labels := _labels(g)
	labels.set_mode(MapModes.Mode.GOODS)
	labels.set_cover(_cover_rects())
	var over := 0
	for text_size: int in [100, 150]:
		labels.set_options(text_size, false)
		for hex_px: float in [16.0, 20.0, 29.0, 36.0, 50.0, 68.0, 104.0]:
			var found := _icons_of_all_goods(labels, g, hex_px, _cover_rects())
			over += int(found["over_names"])
			assert_eq(found["problems"], [] as Array[String], "text %d, %s px" % [text_size, hex_px])
	assert_gt(over, 0, "the case holds icons over names")
	var faulty := _labels(g, NoCollision.new())
	faulty.set_mode(MapModes.Mode.GOODS)
	faulty.set_cover(_cover_rects())
	var planted := _icons_of_all_goods(faulty, g, 29.0, _cover_rects())
	assert_gt((planted["problems"] as Array[String]).size(), 0, "(P) the check reports icons placed unchecked")


# ----- the order and the overlaps (R10) -------------------------------------------------------------------------------


## The town names that overlap another placed thing or a cover rect.
func _town_overlaps(items: Array[Dictionary], cover: Array[Rect2]) -> Array[String]:
	var out: Array[String] = []
	for item: Dictionary in _named(items, ParchmentLabels.KIND_TOWN):
		var box: Rect2 = item["rect"]
		for rect: Rect2 in cover:
			if box.intersects(rect):
				out.append("%s under the cover" % item["text"])
		for other: Dictionary in items:
			if not is_same(other, item) and _meets(box, other):
				out.append("%s over %s %s" % [item["text"], other["kind"], other["text"]])
	return out


func test_no_town_name_overlaps_another_thing_or_the_cover() -> void:
	var g := _full()
	var labels := _labels(g)
	labels.set_cover(_cover_rects())
	labels.set_good(_good_with_districts(g, GEN))
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.GOODS]:
		labels.set_mode(mode)
		for text_size: int in [100, 150]:
			labels.set_options(text_size, false)
			for hex_px: float in [28.0, 37.0, 50.0, 80.0, 150.0]:
				var items := _show(labels, g, hex_px)
				assert_eq(_town_overlaps(items, _cover_rects()), [] as Array[String],
					"mode %d, text %d, %s px" % [mode, text_size, hex_px])


func test_a_layout_without_the_collision_check_is_reported() -> void:
	var g := _full()
	var labels := _labels(g, NoCollision.new())
	labels.set_cover(_cover_rects())
	labels.set_options(150, false)
	var items := _show(labels, g, 28.0)
	var found := _town_overlaps(items, _cover_rects())
	assert_gt(found.size(), 0, "(P) the check reports the overlaps")
	assert_true(found.any(func(line: String) -> bool: return line.ends_with("under the cover")),
		"(P) and the names under the cover")


func test_a_name_under_the_cover_is_dropped_and_its_dot_stays() -> void:
	var g := _full()
	var labels := _labels(g)
	var open := _show(labels, g, 50.0)
	var town := _named(open, ParchmentLabels.KIND_TOWN)[0]
	var cover: Array[Rect2] = [town["rect"]]
	labels.set_cover(cover)
	var under := _of(labels.placed(), ParchmentLabels.KIND_TOWN).filter(
		func(item: Dictionary) -> bool: return item["hex"] == town["hex"])
	assert_eq(under.size(), 1, "the dot stays")
	assert_eq(str(under[0]["text"]), "", "the name is dropped")


func test_capitals_are_placed_before_every_town() -> void:
	var g := _full()
	var labels := _labels(g)
	for hex_px: float in [28.0, 50.0]:
		var items := _show(labels, g, hex_px)
		var last_capital := -1
		var first_town := items.size()
		for i: int in items.size():
			if items[i]["kind"] == ParchmentLabels.KIND_CAPITAL:
				last_capital = i
			elif items[i]["kind"] == ParchmentLabels.KIND_TOWN:
				first_town = mini(first_town, i)
		assert_gte(last_capital, 0)
		assert_lt(last_capital, first_town, "capitals first in placing order")
		# No town took a capital's place: every capital name is shown, whatever towns lie beside it.
		assert_eq(_named(items, ParchmentLabels.KIND_CAPITAL).size(),
			_of(items, ParchmentLabels.KIND_CAPITAL).size())
		var names := _named(items, ParchmentLabels.KIND_CAPITAL)
		for a: int in names.size():
			for b: int in a:
				assert_false((names[a]["rect"] as Rect2).intersects(names[b]["rect"]), "capital names apart")


func test_goods_discs_are_over_half_a_hex_with_the_pips_under_them() -> void:
	var g := _full()
	var labels := _labels(g)
	labels.set_mode(MapModes.Mode.GOODS)
	labels.set_good(_good_with_districts(g, GEN))
	for hex_px: float in [36.0, 68.0, 104.0]:
		var icons := _of(_show(labels, g, hex_px), ParchmentLabels.KIND_ICON)
		assert_gt(icons.size(), 0)
		for item: Dictionary in icons:
			assert_almost_eq(float(item["size"]) / hex_px, 0.56, 0.02, "the disc's width at %s px" % hex_px)
			var under: float = (item["rect"] as Rect2).end.y - ((item["centre"] as Vector2).y + float(item["radius"]))
			assert_gte(under, 2.0 * ParchmentLabels.PIP_MIN_PX + ParchmentLabels.PIP_GAP_PX - 0.01,
				"the pips' row is under the disc")


func test_no_goods_icon_is_drawn_above_twice_its_texture() -> void:
	var g := _full()
	var labels := _labels(g)
	labels.set_mode(MapModes.Mode.GOODS)
	var largest: Dictionary[float, float] = {}  # hex px -> the most an icon is enlarged there
	for good: Dictionary in ParchmentView.goods_list(g):
		labels.set_good(good["id"])
		for hex_px: float in [104.0, 208.0, 312.0]:
			for item: Dictionary in _of(_show(labels, g, hex_px), ParchmentLabels.KIND_ICON):
				var texture := labels._icon_texture(item["icon"])
				assert_not_null(texture, str(item["icon"]))
				var radius := float(item["radius"])
				var times := ParchmentIconSpots.glyph_side(radius) / minf(texture.get_width(), texture.get_height())
				largest[hex_px] = maxf(largest.get(hex_px, 0.0), times)
				assert_eq(int(item["size"]), roundi(radius * 2.0))
				var pips := ParchmentLabels.PIP_GAP_PX + 2.0 * ParchmentLabels.pip_radius(radius)
				assert_almost_eq((item["rect"] as Rect2).size.y, 2.0 * radius + pips, 0.01, "the pips follow the disc")
				assert_almost_eq(ParchmentLabels.pip_radius(radius), ParchmentLabels.PIP_SHARE * radius, 0.01)
	assert_eq(largest.size(), 3, "icons at every zoom")
	assert_between(largest.get(104.0, 0.0), 1.5, 2.0, "under the cap at zoom 1: the disc follows the hex")
	for hex_px: float in [208.0, 312.0]:
		assert_almost_eq(largest.get(hex_px, 0.0), 2.0, 0.001, "twice the texture at %s px, no more" % hex_px)


# ----- the renderer's culling ------------------------------------------------------------------------------------------


## Views with the map's point (0, 0) off the screen, one after another on one node: close in, Goods, a far corner.
func test_the_renderer_culls_the_labels_by_what_they_draw() -> void:
	var g := _full()
	var labels := _labels(g)
	labels.set_good(_good_with_districts(g, GEN))
	var corner := Vector2(g.map.cols * MapTiles.CELL.x, g.map.rows * MapTiles.ROW) * 0.75
	for view: Array in [[MapModes.Mode.TERRAIN, 80.0, Vector2.INF], [MapModes.Mode.GOODS, 104.0, Vector2.INF],
			[MapModes.Mode.TERRAIN, 104.0, corner], [MapModes.Mode.GOODS, 208.0, corner]]:
		var what := "mode %d, hex %s px, at %s" % view
		labels.set_mode(view[0])
		var items := _show(labels, g, view[1], view[2])
		var origin := _view(g, view[1], view[2]) * Vector2.ZERO
		assert_false(Rect2(Vector2.ZERO, SCREEN).has_point(origin), "the map's (0, 0) is off the screen: " + what)
		assert_gt(items.size(), 0, what)
		if view[0] == MapModes.Mode.GOODS:
			assert_gt(_of(items, ParchmentLabels.KIND_ICON).size(), 0, what)
		await wait_process_frames(2)
		assert_eq(culled(labels), [] as Array[String], what)


## (P) The rect a Control of size (0, 0) gives the renderer to cull by.
func test_an_empty_culling_rect_is_reported() -> void:
	var g := _full()
	var labels := _labels(g)
	_show(labels, g, 80.0)
	await wait_process_frames(2)
	RenderingServer.canvas_item_set_custom_rect(labels.get_canvas_item(), true, Rect2())
	assert_gt(labels.placed().size(), 0)
	assert_eq(culled(labels).size(), labels.placed().size(), "(P) every entry can be dropped")


# ----- the viewer -----------------------------------------------------------------------------------------------------


## Setup during the country pick (no player), then a country is chosen on a thin start: what the labels place on hexes
## that country has not discovered.
func _leaks_after_the_pick(labels: ParchmentLabels, by_refresh: bool) -> Array[String]:
	var g := EconomyFixture.game(&"")
	assert_eq(g.player, &"", "the pick")
	add_child_autofree(labels)
	labels.setup(g)
	_show(labels, g, 29.0)
	assert_true(bool(g.act("choose_country", {"tag": VIEWER})["ok"]))
	FogFixture.thin(g, VIEWER, 2)
	if by_refresh:
		labels.refresh()
	else:
		await wait_process_frames(2)
	return _on_unexplored(g, labels.placed(), _view(g, 29.0))


func test_the_viewer_is_the_player_chosen_after_setup() -> void:
	for by_refresh: bool in [true, false]:
		var labels := ParchmentLabels.new()
		var found: Array[String] = await _leaks_after_the_pick(labels, by_refresh)
		assert_eq(found, [] as Array[String], "refresh() %s" % by_refresh)
		assert_gt(labels.placed().size(), 0)


func test_a_viewer_kept_from_setup_is_reported() -> void:
	var found: Array[String] = await _leaks_after_the_pick(StaleViewer.new(), true)
	assert_gt(found.size(), 0, "(P) the pick's all-seeing viewer places names on unexplored land")


# ----- the fog (R12, R13) ---------------------------------------------------------------------------------------------


## What of `items` lies on a hex the viewer has not discovered: the entry's own hex, and every 3 px of its box (turned,
## for a country name), its edges too.
func _on_unexplored(g: Game, items: Array[Dictionary], xform: Transform2D) -> Array[String]:
	var out: Array[String] = []
	var inverse := xform.affine_inverse()
	for item: Dictionary in items:
		if not Knowledge.discovered(g, VIEWER, item["hex"]):
			out.append("%s %s stands on %s" % [item["kind"], item["text"], item["hex"]])
			continue
		if item.has("dot") and str(item["text"]) == "":
			continue
		var rect: Rect2 = item["rect"]
		var centre := rect.get_center()
		var extent := rect.size
		var angle := 0.0
		if item["kind"] == ParchmentLabels.KIND_COUNTRY:
			centre = item["centre"]
			extent = item["extent"]
			angle = deg_to_rad(float(item["angle"]))
		var nx := ceili(extent.x / 3.0)
		var ny := ceili(extent.y / 3.0)
		var bad := Vector2i(-1, -1)
		for x: int in nx + 1:
			for y: int in ny + 1:
				var local := Vector2(lerpf(-0.499, 0.499, float(x) / nx), lerpf(-0.499, 0.499, float(y) / ny)) * extent
				var hex := MapModes.hex_at_px(inverse * (centre + local.rotated(angle)))
				if g.map.has(hex) and not Knowledge.discovered(g, VIEWER, hex):
					bad = hex
		if bad != Vector2i(-1, -1):
			out.append("%s %s reaches %s" % [item["kind"], item["text"], bad])
	return out


func test_nothing_is_placed_on_an_undiscovered_hex() -> void:
	var g := _thin()
	var labels := _labels(g)
	var goods: Array[int] = []
	for good: Dictionary in ParchmentView.goods_list(g):
		if ParchmentView.count_of(g, VIEWER, good["id"]) > 0:
			goods.append(good["id"])
	assert_gt(goods.size(), 0)
	var kinds: Dictionary[StringName, int] = {}
	for text_size: int in [100, 150]:
		labels.set_options(text_size, false)
		for hex_px: float in [5.0, 12.0, 20.0, 29.0, 50.0, 68.0, 104.0]:
			for good: int in [-1] + goods:
				labels.set_mode(MapModes.Mode.TERRAIN if good < 0 else MapModes.Mode.GOODS)
				labels.set_good(good)
				var items := _show(labels, g, hex_px)
				for item: Dictionary in items:
					kinds[item["kind"]] = int(kinds.get(item["kind"], 0)) + 1
				var found := _on_unexplored(g, items, _view(g, hex_px))
				assert_eq(found, [] as Array[String], "text %d, %s px, good %d" % [text_size, hex_px, good])
	for kind: StringName in [&"country", &"capital", &"town", &"icon"]:
		assert_gt(int(kinds.get(kind, 0)), 0, "the case is not empty: %s" % kind)


func test_a_name_from_the_raw_places_is_reported() -> void:
	var g := _thin()
	var xform := _view(g, 50.0)
	var font := _font("alegreya_sc_bold")
	var raw: Array[Dictionary] = []
	for place: Dictionary in CountryNames.places(g):
		var centre: Vector2 = xform * (place["at"] as Vector2)
		var extent := font.get_string_size(place["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		raw.append({"kind": ParchmentLabels.KIND_COUNTRY, "hex": MapModes.hex_at_px(place["at"]), "text": place["text"],
			"rect": Rect2(centre - extent * 0.5, extent), "centre": centre, "extent": extent, "angle": 0.0})
	assert_gt(_on_unexplored(g, raw, xform).size(), 0, "(P) the raw places name unexplored land, and the check says so")


# ----- when it lays out (R11) -----------------------------------------------------------------------------------------


func test_no_layout_while_nothing_changes() -> void:
	var g := _thin()
	var labels := _labels(g)
	_show(labels, g, 50.0)
	var count := labels.layout_count
	assert_eq(count, 1, "setup waits for a view; the first view lays out once")
	await wait_process_frames(60)
	_show(labels, g, 50.0)
	assert_eq(labels.layout_count, count, "60 frames and the same view: no layout")


func test_each_change_lays_out_once() -> void:
	var g := _full()
	var labels := _labels(g)
	_show(labels, g, 50.0)
	var count := labels.layout_count
	var changes: Array[Callable] = [
		func() -> void: _show(labels, g, 51.0),
		func() -> void: labels.set_cover(_cover_rects()),
		func() -> void: labels.set_options(150, false),
		func() -> void: labels.set_options(150, true),
		func() -> void: labels.set_mode(MapModes.Mode.GOODS),
		func() -> void: labels.set_good(Economy.GRAIN),
		func() -> void: labels.refresh(),
	]
	for change: Callable in changes:
		change.call()
		count += 1
		assert_eq(labels.layout_count, count)
	labels.set_cover(_cover_rects())
	labels.set_options(150, true)
	labels.set_mode(MapModes.Mode.GOODS)
	labels.set_good(Economy.GRAIN)
	labels.set_alpha(0.5)
	assert_eq(labels.layout_count, count, "the same values and a fade lay out nothing")
	assert_almost_eq(labels.modulate.a, 0.5, 0.001)
	labels.set_mode(MapModes.Mode.TERRAIN)
	count += 1
	labels.set_good(Economy.GRAIN + 1)
	assert_eq(labels.layout_count, count, "a good changes nothing outside Goods")


func test_a_hidden_parchment_waits_to_lay_out() -> void:
	var g := _full()
	var labels := _labels(g)
	_show(labels, g, 50.0)
	labels.set_alpha(0.0)
	assert_false(labels.visible)
	var count := labels.layout_count
	_show(labels, g, 40.0)
	_show(labels, g, 45.0)
	labels.refresh()
	assert_eq(labels.layout_count, count)
	assert_true(labels.placed().is_empty())
	labels.set_alpha(1.0)
	assert_eq(labels.layout_count, count + 1, "shown again: one layout, of the last view")
	assert_gt(labels.placed().size(), 0)


func test_a_view_change_reads_no_facts_and_refresh_does() -> void:
	var g := _full()
	var labels := _labels(g)
	var before := _of(_show(labels, g, 50.0), ParchmentLabels.KIND_COUNTRY)
	# Genoa takes every hex: the names change only when the facts are read again.
	var hexes: Array[Vector2i] = []
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and g.state.owner[i] > 0:
			hexes.append(g.map.hex_of(i))
	assert_gt(Territory.transfer(g, hexes, Countries.by_tag(g, GEN).id), 0)
	var moved := _of(_show(labels, g, 49.0), ParchmentLabels.KIND_COUNTRY)
	assert_eq(moved.size(), before.size(), "a new view keeps the old names")
	labels.refresh()
	var after := _of(labels.placed(), ParchmentLabels.KIND_COUNTRY)
	assert_lt(after.size(), before.size())
	for item: Dictionary in after:
		assert_eq(item["tag"], GEN)


func test_a_new_discovery_names_the_land_by_itself() -> void:
	var g := _thin()
	var labels := _labels(g)
	var before := _show(labels, g, 29.0).size()
	var c := Countries.by_tag(g, VIEWER)
	c.explored = FogFixture.grown(g, VIEWER, 40)
	g.sight.grew(c.id)
	g.version += 1
	await wait_process_frames(2)
	assert_gt(labels.placed().size(), before, "more is shown once more is discovered")


func test_no_game_places_nothing() -> void:
	var labels := ParchmentLabels.new()
	add_child_autofree(labels)
	labels.relayout(Transform2D.IDENTITY, 0.5, SCREEN)
	assert_true(labels.placed().is_empty())
	labels.setup(_full())
	assert_gt(labels.placed().size(), 0, "a view already known: setup lays out")
	labels.setup(null)
	assert_true(labels.placed().is_empty())
	assert_false((labels as Node) is Control, "no Control: it takes no mouse, and is culled by what it draws")
