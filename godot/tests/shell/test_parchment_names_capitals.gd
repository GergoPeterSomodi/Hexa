## The parchment's country names and the capitals (docs/architecture/map-overview-build-spec.md, amendment of
## 2026-11-28): a capital's dot and name are a hard obstacle, a country with no clear place for its name is left unnamed
## while its capital stays named, and no larger country loses its name for that. (P): names placed with no care for the
## capitals, and a search without its last step: the checks report them.
extends ParchmentLabelsCase

## A 1920 x 1080 HUD's covering rects in Goods mode: the top bar, the minimap's corner, the goods card, the legend, the
## key hints and the Return button.
const HUD_RECTS: Array[Rect2] = [Rect2(0.0, 0.0, 1920.0, 56.0), Rect2(1686.0, 886.0, 220.0, 178.0),
	Rect2(12.0, 715.0, 372.0, 271.0), Rect2(12.0, 68.0, 220.0, 142.0), Rect2(6.0, 1038.0, 560.0, 36.0),
	Rect2(884.5, 1002.0, 151.0, 32.0)]
const VIEWS: Array[float] = [10.0, 20.0, 24.0, 29.0, 34.0, 41.0, 45.0, 52.0, 60.0, 68.0, 87.0, 104.0, 208.0]


## A search with no last step: no size under those tried for the capitals, no place beside them (a planted fault).
class NoLast:
	extends ParchmentLabels

	func _put_last(_name: Dictionary, _centre: Vector2, _tried: Array[int], _capitals: Array[Dictionary]) -> bool:
		return false


## The country names that lie on a capital's dot or on its shown name.
func _on_capitals(items: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for name: Dictionary in _of(items, ParchmentLabels.KIND_COUNTRY):
		for capital: Dictionary in _of(items, ParchmentLabels.KIND_CAPITAL):
			if _meets(Rect2(capital["dot"], Vector2.ZERO).grow(float(capital["dot_radius"])), name):
				out.append("%s over the dot at %s" % [name["text"], capital["hex"]])
			elif str(capital["text"]) != "" and _meets(capital["rect"], name):
				out.append("%s over the capital name %s" % [name["text"], capital["text"]])
	return out


## What of every view, text size, mode and cover lies on a capital, and how many country names were looked at.
func _all_views(labels: ParchmentLabels, g: Game) -> Array:
	var found: Array[String] = []
	var looked := 0
	labels.set_good(_good_with_districts(g, GEN))
	var none: Array[Rect2] = []
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.GOODS]:
		labels.set_mode(mode)
		for covered: bool in [false, true]:
			labels.set_cover(HUD_RECTS if covered else none)
			for text_size: int in [100, 150]:
				labels.set_options(text_size, false)
				for hex_px: float in VIEWS:
					var items := _show(labels, g, hex_px)
					looked += _of(items, ParchmentLabels.KIND_COUNTRY).size()
					for line: String in _on_capitals(items):
						found.append("mode %d, cover %s, text %d, %s px: %s" % [mode, covered, text_size, hex_px, line])
	return [found, looked]


func test_no_country_name_lies_on_a_capitals_dot_or_name() -> void:
	var g := _full()
	var seen := _all_views(_labels(g), g)
	assert_gt(int(seen[1]), 400, "the case is full of names")
	assert_eq(seen[0], [] as Array[String])
	var faulty := _all_views(_labels(g, NoRoom.new()), g)
	assert_gt((faulty[0] as Array[String]).size(), 0, "(P) names placed with no care for the capitals are reported")


## The country names among `items`.
func _texts(items: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for item: Dictionary in _of(items, ParchmentLabels.KIND_COUNTRY):
		out.append(item["text"])
	return out


func test_a_country_with_no_clear_place_is_left_unnamed_and_its_capital_stays() -> void:
	var g := _full()
	var labels := _labels(g)
	# Mantua, three hexes round its capital: at 34 px a hex its name has no place clear of it.
	var items := _show(labels, g, 34.0)
	assert_does_not_have(_texts(items), "Mantua")
	var capital := Countries.by_tag(g, &"MAN").capital
	var kept := _of(items, ParchmentLabels.KIND_CAPITAL).filter(
		func(item: Dictionary) -> bool: return item["hex"] == capital)
	assert_eq(kept.size(), 1, "its capital's dot is there")
	assert_eq(str(kept[0]["text"]) if not kept.is_empty() else "", "Mantua", "and its capital's name")
	assert_has(_texts(_show(labels, g, 68.0)), "Mantua", "with room for it, the country is named")


## The countries a search leaves unnamed, by "px text: name", over the views from the town view in.
func _lost(labels: ParchmentLabels, g: Game) -> Array[String]:
	var out: Array[String] = []
	for text_size: int in [100, 150]:
		labels.set_options(text_size, false)
		for hex_px: float in [29.0, 34.0, 52.0, 68.0]:
			var named := _texts(_show(labels, g, hex_px))
			for entry: Dictionary in ParchmentView.country_names(g, GEN):
				if not named.has(entry["text"]):
					out.append("%d %d: %s" % [hex_px, text_size, entry["text"]])
	out.sort()
	return out


func test_only_small_countries_with_no_room_lose_their_names() -> void:
	var g := _full()
	var allowed: Array[String] = ["29 100: Mantua", "29 150: Ferrara", "29 150: Mantua", "29 150: Siena",
		"34 100: Mantua", "34 150: Mantua"]
	assert_eq(_lost(_labels(g), g), allowed)
	var short := _lost(_labels(g, NoLast.new()), g)
	assert_gt(short.size(), allowed.size(), "(P) a search without its last step loses more names, and it is reported")


## Searches that never give the icons up: a capital's name stays held off their spots (a planted fault).
class HeldIcons:
	extends ParchmentLabels

	func _put_over_icons(_name: Dictionary, _centre: Vector2, _sizes: Array[int], _capitals: Array[Dictionary]) -> void:
		pass


## The countries unnamed on the goods map of grain at 1280 x 720, at the zoom-out limit (hexes 29.1 px wide) and a
## little farther in, by "px: name".
func _lost_among_icons(labels: ParchmentLabels, g: Game) -> Array[String]:
	var screen := Vector2(1280.0, 720.0)
	var middle := Vector2(g.map.cols * MapTiles.CELL.x, g.map.rows * MapTiles.ROW) * 0.5
	labels.set_mode(MapModes.Mode.GOODS)
	labels.set_good(Economy.GRAIN)
	var out: Array[String] = []
	for hex_px: float in [29.1, 33.0]:
		var zoom := hex_px / MapTiles.CELL.x
		labels.relayout(Transform2D(Vector2(zoom, 0.0), Vector2(0.0, zoom), screen * 0.5 - middle * zoom), zoom, screen)
		var named := _texts(labels.placed())
		for entry: Dictionary in ParchmentView.country_names(g, GEN):
			if not named.has(entry["text"]):
				out.append("%.1f: %s" % [hex_px, entry["text"]])
	out.sort()
	return out


func test_no_country_loses_its_name_to_a_goods_icons_spot() -> void:
	var g := _full()
	var allowed: Array[String] = ["29.1: Mantua", "33.0: Mantua"]
	assert_eq(_lost_among_icons(_labels(g), g), allowed)
	var held := _lost_among_icons(_labels(g, HeldIcons.new()), g)
	assert_has(held, "29.1: Ferrara", "(P) a capital's name held off an icon's spot costs a country its name")


## A name put past a box may land far from where it started, among capitals its search did not look at.
func test_a_capital_far_from_a_names_place_is_in_its_way_too() -> void:
	var far := {"dot": Vector2(900.0, 100.0), "dot_radius": 5.0, "rect": Rect2(870.0, 106.0, 60.0, 20.0),
		"text": "Far", "hex": Vector2i.ZERO}
	var capitals: Array[Dictionary] = [far]
	var home := Vector2(100.0, 100.0)
	var half := Vector2(40.0, 10.0)
	assert_false(ParchmentCapitalRoom.far_clear(capitals, home, half, Vector2(900.0, 100.0), Vector2.RIGHT, half),
		"on its dot")
	assert_false(ParchmentCapitalRoom.far_clear(capitals, home, half, Vector2(900.0, 128.0), Vector2.RIGHT, half),
		"on its name")
	assert_true(ParchmentCapitalRoom.far_clear(capitals, home, half, Vector2(900.0, 160.0), Vector2.RIGHT, half),
		"clear of it")
