## The parchment map's country names (docs/architecture/map-overview-build-spec.md R8, R10, D7, R27): their room and
## their slides, the capitals they make room for, their sizes and their look. (P): names left where R10 alone leaves
## them, and names see-through in every mode: the checks report them.
extends ParchmentLabelsCase


## The planted fault of the opacity: the names see-through in every mode.
class SeeThroughAlways:
	extends ParchmentLabels

	func _name_colours() -> Array[Color]:
		var out := super()
		out[0].a = NAME_ALPHA
		out[1].a = NAME_ALPHA
		return out


# ----- the room and the slides (R8, R10, D7) --------------------------------------------------------------------------


func _entry_for(g: Game, viewer: StringName, item: Dictionary, zoom: float, xform: Transform2D) -> Dictionary:
	var best: Dictionary = {}
	for entry: Dictionary in ParchmentView.country_names(g, viewer):
		if entry["tag"] != item["tag"]:
			continue
		var gap := (xform * (entry["at"] as Vector2)).distance_to(item["centre"])
		if best.is_empty() or gap < (xform * (best["at"] as Vector2)).distance_to(item["centre"]):
			best = entry
	assert_false(best.is_empty(), "a placed name comes from the view, at zoom %s" % zoom)
	return best


## The country names that are longer than their room, outside 14 to 48 px times the text size, moved more than 2.5
## lines across or 0.45 of their length along, or whose line leaves their country.
func _name_problems(g: Game, viewer: StringName, items: Array[Dictionary], hex_px: float, scale_to: float) -> Array[String]:
	var out: Array[String] = []
	var zoom := hex_px / MapTiles.CELL.x
	var xform := _view(g, hex_px)
	var owners := ParchmentView.owner_bytes(g, viewer)
	for item: Dictionary in _of(items, ParchmentLabels.KIND_COUNTRY):
		var entry := _entry_for(g, viewer, item, zoom, xform)
		var extent: Vector2 = item["extent"]
		if extent.x > float(entry["span_px"]) * zoom + SIZE_EPS:
			out.append("%s longer than its room" % item["text"])
		if int(item["size"]) < 14 or int(item["size"]) > roundi(48.0 * scale_to):
			out.append("%s at %d px" % [item["text"], item["size"]])
		var axis := Vector2.from_angle(deg_to_rad(float(item["angle"])))
		var off: Vector2 = (item["centre"] as Vector2) - xform * (entry["at"] as Vector2)
		if absf(off.dot(axis)) > 0.45 * extent.x + SIZE_EPS or absf(off.cross(axis)) > 2.5 * extent.y + SIZE_EPS:
			out.append("%s moved too far: %s" % [item["text"], off])
		var id := Countries.by_tag(g, item["tag"]).id
		var reach := (extent.x - ParchmentTokens.HALO_PX) * 0.5
		for k: int in 81:
			var at: Vector2 = (item["centre"] as Vector2) + axis * lerpf(-reach, reach, k / 80.0)
			var hex := MapModes.hex_at_px(xform.affine_inverse() * at)
			if not g.map.has(hex) or int(owners[g.map.index_of(hex)]) != id:
				out.append("%s leaves its country at %s" % [item["text"], hex])
				break
	return out


func test_country_names_stay_in_their_room_and_on_their_country() -> void:
	var g := _full()
	var labels := _labels(g)
	var all := ParchmentView.country_names(g, GEN).size()
	# 68 px is north Italy's whole-map view at 1920 x 1080 (zoom 0.65); 29 px is where a large map turns solid.
	for hex_px: float in [10.0, 20.0, 29.0, 50.0, 68.0, 104.0]:
		for text_size: int in [100, 150]:
			labels.set_options(text_size, false)
			var items := _show(labels, g, hex_px)
			assert_eq(_name_problems(g, GEN, items, hex_px, text_size / 100.0), [] as Array[String],
				"%s px, text %d" % [hex_px, text_size])
			if hex_px >= 29.0 and hex_px <= 68.0:
				assert_eq(_of(items, ParchmentLabels.KIND_COUNTRY).size(), all, "every country at %s px" % hex_px)


func test_a_name_slides_off_a_capital_where_it_can() -> void:
	var g := _full()
	var labels := _labels(g)
	var slid := 0
	for hex_px: float in [29.0, 50.0, 68.0]:
		var items := _show(labels, g, hex_px)
		var xform := _view(g, hex_px)
		for item: Dictionary in _of(items, ParchmentLabels.KIND_COUNTRY):
			var entry := _entry_for(g, GEN, item, hex_px / MapTiles.CELL.x, xform)
			if (item["centre"] as Vector2).distance_to(xform * (entry["at"] as Vector2)) < SIZE_EPS:
				continue
			slid += 1
			for capital: Dictionary in _of(items, ParchmentLabels.KIND_CAPITAL):
				assert_false(_meets(capital["rect"], item), "%s slid clear of %s" % [item["text"], capital["hex"]])
	assert_gt(slid, 0, "some name slides off a capital")


func test_sizes_follow_the_text_size() -> void:
	assert_eq(ParchmentLabels.wanted_name_px(9, 58.0, 1.0), 24, "8 x sqrt(9) at a 58 px hex")
	assert_eq(ParchmentLabels.wanted_name_px(9, 58.0, 1.5), 36)
	assert_eq(ParchmentLabels.wanted_name_px(1, 20.0, 1.0), 14)
	assert_eq(ParchmentLabels.wanted_name_px(400, 58.0, 1.0), 48)
	assert_eq(ParchmentLabels.wanted_name_px(400, 58.0, 1.5), 72)
	assert_eq(ParchmentLabels.town_name_px(3, false, 1.0), 13)
	assert_eq(ParchmentLabels.town_name_px(4, false, 1.0), 15)
	assert_eq(ParchmentLabels.town_name_px(5, false, 1.0), 17)
	assert_eq(ParchmentLabels.town_name_px(3, true, 1.0), 17)
	assert_eq(ParchmentLabels.town_name_px(3, false, 1.5), 20)
	assert_eq(ParchmentLabels.town_name_px(3, true, 1.5), 26)
	var g := _full()
	var labels := _labels(g)
	var sizes := func() -> Dictionary:
		var out: Dictionary = {}
		for item: Dictionary in labels.placed():
			if str(item["text"]) != "":
				out[item["text"]] = int(item["size"])
		return out
	_show(labels, g, 104.0)
	var plain: Dictionary = sizes.call()
	labels.set_options(150, false)
	var large: Dictionary = sizes.call()
	var grown := 0
	for text: String in large:
		if not plain.has(text):
			continue
		assert_gte(large[text], plain[text], "%s never shrinks at 150" % text)
		if large[text] >= roundi(plain[text] * 1.5) - 1:
			grown += 1
	assert_gt(float(grown), large.size() / 2.0, "most names grow by half (a short room holds some back)")
	for item: Dictionary in _named(labels.placed(), ParchmentLabels.KIND_CAPITAL):
		assert_eq(int(item["size"]), 26)


# ----- the names and the capitals -------------------------------------------------------------------------------------


## The pairs of country names that overlap, and the country names over a capital's dot or name.
func _name_overlaps(items: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	var names := _of(items, ParchmentLabels.KIND_COUNTRY)
	for n: int in names.size():
		var quad := _quad(names[n])
		for m: int in n:
			if not Geometry2D.intersect_polygons(quad, _quad(names[m])).is_empty():
				out.append("%s over %s" % [names[n]["text"], names[m]["text"]])
		for capital: Dictionary in _of(items, ParchmentLabels.KIND_CAPITAL):
			if _meets(capital["rect"], names[n]) or _meets(
					Rect2(capital["dot"], Vector2.ZERO).grow(float(capital["dot_radius"])), names[n]):
				out.append("%s over the capital at %s %s" % [names[n]["text"], capital["hex"], capital["text"]])
	return out


func _quad(name: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for side: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		out.append((name["centre"] as Vector2) + (side * (name["extent"] as Vector2)).rotated(
			deg_to_rad(float(name["angle"]))))
	return out


## The overlaps of north Italy's views from zoom 0.5 (under its zoom-out limit; the whole-map view is about 0.65) to the
## closest, at both text sizes. At text 150 only from the whole-map view in: farther out Ferrara's name has no room.
func _overlaps_of_north_italy(labels: ParchmentLabels, g: Game) -> Array[String]:
	var out: Array[String] = []
	for text_size: int in [100, 150]:
		labels.set_options(text_size, false)
		for zoom: float in [0.5, 0.58, 0.65, 0.84, 1.0, 1.5, 2.0]:
			if text_size == 150 and zoom < 0.65:
				continue
			var items := _show(labels, g, zoom * MapTiles.CELL.x)
			if zoom <= 0.65:  # closer in, part of the map is off the screen
				assert_eq(_of(items, ParchmentLabels.KIND_COUNTRY).size(), 13, "all 13 named at zoom %s" % zoom)
			assert_eq(_named(items, ParchmentLabels.KIND_CAPITAL).size(),
				_of(items, ParchmentLabels.KIND_CAPITAL).size(), "every capital named at zoom %s" % zoom)
			for line: String in _name_overlaps(items):
				out.append("text %d zoom %s: %s" % [text_size, zoom, line])
	return out


func test_no_country_name_overlaps_a_name_or_a_capital_on_north_italy() -> void:
	var g := _full()
	assert_eq(_overlaps_of_north_italy(_labels(g), g), [] as Array[String])


func test_names_left_where_r10_leaves_them_are_reported() -> void:
	var g := _full()
	var found := _overlaps_of_north_italy(_labels(g, NoRoom.new()), g)
	assert_true(found.any(func(line: String) -> bool: return line.contains("zoom 0.65: Florence over the capital")),
		"(P) Florence over its capital at the whole-map view is reported")


## The capitals whose names are shown above their dots, by name.
func _names_above(items: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for item: Dictionary in _named(items, ParchmentLabels.KIND_CAPITAL):
		if (item["rect"] as Rect2).end.y < (item["dot"] as Vector2).y:
			out[item["text"]] = item
	return out


func test_a_capital_name_goes_above_its_dot_to_make_room() -> void:
	var g := _full()
	var labels := _labels(g)
	var left := _labels(g, NoRoom.new())
	var moves := 0
	for hex_px: float in [52.0, 60.0, 68.0, 87.0, 104.0, 208.0]:
		var items := _show(labels, g, hex_px)
		var above := _names_above(items)
		# What is above with no country name asking for room.
		var before := _names_above(_show(left, g, hex_px))
		for text: String in above:
			if before.has(text):
				continue
			moves += 1
			for other: Dictionary in items:
				if other["kind"] != ParchmentLabels.KIND_ICON and not is_same(other, above[text]):
					assert_false(_meets(above[text]["rect"], other),
						"%s clear of %s %s at %s px" % [text, other["kind"], other["text"], hex_px])
	assert_gt(moves, 0, "a country name's room moves some capital's name above")


# ----- the look (the approved mockup) ---------------------------------------------------------------------------------


func test_country_names_are_letter_spaced() -> void:
	var g := _full()
	var labels := _labels(g)
	for item: Dictionary in _of(_show(labels, g, 68.0), ParchmentLabels.KIND_COUNTRY):
		assert_almost_eq((item["extent"] as Vector2).x, _name_width(item["text"], item["size"]), SIZE_EPS,
			"%s: the spacing counts in the fitted width" % item["text"])
	assert_eq((labels._name_face(48) as FontVariation).spacing_glyph, 4, "0.08 em")


## The modes whose country names have the wrong opacity (ink or halo): 0.82 in Goods, whole in Terrain and Owner, whole
## everywhere in high contrast. The modes are gone through twice, so a return from Goods is read too.
func _opacity_problems(labels: ParchmentLabels) -> Array[String]:
	var out: Array[String] = []
	for high: bool in [false, true]:
		labels.set_options(100, high)
		for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.GOODS, MapModes.Mode.OWNER, MapModes.Mode.GOODS,
				MapModes.Mode.TERRAIN]:
			labels.set_mode(mode)
			var want := 0.82 if mode == MapModes.Mode.GOODS and not high else 1.0
			for colour: Color in labels._name_colours():
				if absf(colour.a - want) > 0.005:
					out.append("mode %d, high contrast %s: %.2f, not %.2f" % [mode, high, colour.a, want])
	return out


func test_country_names_are_see_through_in_goods_mode_only() -> void:
	var g := _full()
	var labels := _labels(g)
	assert_eq(_opacity_problems(labels), [] as Array[String])
	# R27: in Goods mode the see-through ink on its see-through halo still reads on every land the halo may lie on.
	labels.set_options(100, false)
	labels.set_mode(MapModes.Mode.GOODS)
	var tokens := ParchmentTokens.colours(false)
	var ink := labels._name_colours()[0]
	var halo := labels._name_colours()[1]
	for under: StringName in [&"land", &"sea", &"goods_1", &"goods_2", &"goods_3", &"unknown"]:
		var paper := (tokens[under] as Color).blend(halo)
		assert_gte(Tokens.contrast_ratio(paper.blend(ink), paper), 4.5, "name ink over %s" % under)


func test_p_names_see_through_in_every_mode_are_reported() -> void:
	var found := _opacity_problems(_labels(_full(), SeeThroughAlways.new()))
	assert_gt(found.size(), 0, "(P) see-through names outside Goods mode and in high contrast")
