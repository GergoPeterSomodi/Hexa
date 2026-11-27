## The room of the parchment's country names (docs/architecture/map-overview-build-spec.md R10, D7, R13): clear of the
## HUD's cover rects and of the goods icons where their own land allows, and read again whenever the discovered set
## moves. Each case fails without its fix; (P): names placed with no such care are reported.
extends ParchmentLabelsCase

## The HUD of a 1920 x 1080 window in Goods mode: the top bar, the minimap, the zoom control, the scale bar, the goods
## card and the Return button.
const HUD_RECTS: Array[Rect2] = [Rect2(0.0, 0.0, 1920.0, 56.0), Rect2(1686.0, 886.0, 220.0, 124.0),
	Rect2(1696.0, 1018.0, 210.0, 48.0), Rect2(1550.0, 1038.0, 128.0, 28.0), Rect2(12.0, 715.0, 372.0, 271.0),
	Rect2(884.5, 1002.0, 151.0, 32.0)]
## The tile window's dock.
const DOCK := Rect2(1624.0, 56.0, 296.0, 1024.0)
## North Italy's whole-map view at 1920 x 1080, and one notch in.
const WHOLE_PX := 69.12
const NOTCH_PX := 80.0


## Country names placed by the capitals' rules alone (a planted fault).
class NoCare:
	extends ParchmentLabels

	func _put_name(name: Dictionary, centre: Vector2, sizes: Array[int], capitals: Array[Dictionary]) -> bool:
		return _put_clear(name, centre, sizes, capitals)


## The country names that lie under one of `cover`, or whose line leaves their country.
func _cover_problems(g: Game, items: Array[Dictionary], cover: Array[Rect2], hex_px: float) -> Array[String]:
	var out: Array[String] = []
	var inverse := _view(g, hex_px).affine_inverse()
	var owners := ParchmentView.owner_bytes(g, GEN)
	for item: Dictionary in _of(items, ParchmentLabels.KIND_COUNTRY):
		for rect: Rect2 in cover:
			if _meets(rect, item):
				out.append("%s under %s" % [item["text"], rect])
		var axis := Vector2.from_angle(deg_to_rad(float(item["angle"])))
		var reach := ((item["extent"] as Vector2).x - ParchmentTokens.HALO_PX) * 0.5
		var id := Countries.by_tag(g, item["tag"]).id
		for k: int in 41:
			var hex := MapModes.hex_at_px(inverse * ((item["centre"] as Vector2) + axis * lerpf(-reach, reach, k / 40.0)))
			if not g.map.has(hex) or int(owners[g.map.index_of(hex)]) != id:
				out.append("%s leaves its country at %s" % [item["text"], hex])
				break
	return out


func _cover_case(labels: ParchmentLabels, g: Game, hex_px: float, cover: Array[Rect2]) -> Array[String]:
	labels.set_cover(cover)
	var items := _show(labels, g, hex_px)
	assert_eq(_of(items, ParchmentLabels.KIND_COUNTRY).size(), 13, "every country keeps its name at %s px" % hex_px)
	return _cover_problems(g, items, cover, hex_px)


func test_country_names_slide_out_from_under_the_hud_on_their_own_land() -> void:
	var g := _full()
	var labels := _labels(g)
	var docked: Array[Rect2] = HUD_RECTS.duplicate()
	docked.append(DOCK)
	for hex_px: float in [WHOLE_PX, NOTCH_PX]:
		for cover: Array[Rect2] in [HUD_RECTS, docked]:
			assert_eq(_cover_case(labels, g, hex_px, cover), [] as Array[String], "%s px, %d covers" % [hex_px, cover.size()])
	var faulty := _labels(g, NoCare.new())
	assert_gt(_cover_case(faulty, g, NOTCH_PX, docked).size(), 0, "(P) names under the HUD are reported")


func test_a_name_with_no_land_clear_of_the_cover_is_still_written() -> void:
	var g := _full()
	var labels := _labels(g)
	var all: Array[Rect2] = [Rect2(-4000.0, -4000.0, 10000.0, 10000.0)]
	labels.set_cover(all)
	assert_eq(_of(_show(labels, g, WHOLE_PX), ParchmentLabels.KIND_COUNTRY).size(), 13, "under it, as before")


## [country names under an icon of the good, the names' sizes by text].
func _icon_case(labels: ParchmentLabels, g: Game, good: StringName) -> Array:
	labels.set_good(g.defs.good_id(good))
	var items := _show(labels, g, WHOLE_PX)
	var over: Array[String] = []
	var sizes: Dictionary = {}
	for item: Dictionary in _of(items, ParchmentLabels.KIND_COUNTRY):
		sizes["%s %s" % [item["text"], (item["hex"] as Vector2i).x < 6]] = item["size"]
		for icon: Dictionary in _of(items, ParchmentLabels.KIND_ICON):
			if _meets(icon["rect"], item):
				over.append("%s under the %s icon at %s" % [item["text"], good, icon["hex"]])
	assert_eq(_of(items, ParchmentLabels.KIND_ICON).size(), ParchmentView.count_of(g, GEN, g.defs.good_id(good)),
		"%s: every district has its icon" % good)
	return [over, sizes]


func test_country_names_slide_off_the_goods_icons_without_shrinking() -> void:
	var g := _full()
	var labels := _labels(g)
	var plain: Dictionary = {}
	for item: Dictionary in _of(_show(labels, g, WHOLE_PX), ParchmentLabels.KIND_COUNTRY):
		plain["%s %s" % [item["text"], (item["hex"] as Vector2i).x < 6]] = item["size"]
	labels.set_mode(MapModes.Mode.GOODS)
	for good: StringName in [&"grain", &"oil", &"wine", &"salt", &"hemp", &"wool", &"stone"]:
		var found := _icon_case(labels, g, good)
		assert_eq(found[0], [] as Array[String], "%s: no icon covers a name's letters" % good)
		assert_eq(found[1], plain, "%s: no name shrinks for an icon" % good)
	var faulty := _labels(g, NoCare.new())
	faulty.set_mode(MapModes.Mode.GOODS)
	var wine: Array = _icon_case(faulty, g, &"wine")
	assert_true((wine[0] as Array).any(func(line: String) -> bool: return line.begins_with("Austria")),
		"(P) the wine icon over Austria is reported")


func test_the_names_follow_the_discovered_set_when_only_the_sight_moves() -> void:
	var g := _thin()
	var labels := _labels(g)
	var before := _show(labels, g, 29.0).size()
	var c := Countries.by_tag(g, VIEWER)
	var explored := g.sight.explored_revision(c.id)
	var all := PackedByteArray()
	all.resize((g.map.hex_count() + 7) >> 3)
	all.fill(255)
	g.sight.set_army_part({c.id: all}, {})  # the armies see everything; the explored set stays as it is
	assert_eq(g.sight.explored_revision(c.id), explored)
	assert_eq(MapModes.discovered_bytes(g, VIEWER).count(0), 0, "P: the discovered set moved")
	await wait_process_frames(2)
	assert_eq(labels._owners.count(ParchmentView.UNKNOWN), 0, "the names read it, as the parchment does")
	assert_gt(labels.placed().size(), before)
	var reads := labels.layout_count
	g.sight.set_army_part({c.id: all}, {})
	await wait_process_frames(2)
	assert_eq(labels.layout_count, reads, "sight that moves with the same discovered set reads nothing")
