## The parchment's fog proofs on its facts (docs/architecture/map-overview-build-spec.md R12 to R14, done-when 2; plan
## PM6). On FogFixture.thin, in Terrain, Owner and Goods mode, no output of ParchmentView shows anything of a hex the
## viewer has not discovered, and owners and goods are exact on light fog (discovered, out of sight). The lines and
## marks the shaders draw are worked out here from ParchmentView.owner_bytes and ParchmentShape by the shaders' rules,
## which test_parchment_fog_shell.gd pins to the shader sources (headless runs no shader). The labels and the textures
## are proved there too.
## Each check returns what is wrong as a list that is asserted once (GUT keeps the text of every passed check). Each
## planted case (P) feeds a check what a leaking view would give, and the check must report it.
extends GutTest

const GEN := &"GEN"
const MODES: Array[int] = [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.GOODS]
const UNKNOWN := ParchmentView.UNKNOWN


## One thin game: what the viewer knows, worked out hex by hex from Knowledge (the rule the views must agree with).
class Case:
	extends RefCounted

	var what := ""
	var game: Game = null
	var viewer: StringName = &""
	var known := PackedByteArray()  # 1: discovered
	var light := PackedByteArray()  # 1: discovered and out of sight

	func _init(p_what: String, p_game: Game, p_viewer: StringName) -> void:
		what = p_what
		game = p_game
		viewer = p_viewer
		game.player = viewer
		var n := game.map.hex_count()
		known.resize(n)
		light.resize(n)
		for i: int in n:
			var hex := game.map.hex_of(i)
			known[i] = int(Knowledge.discovered(game, viewer, hex))
			light[i] = int(known[i] == 1 and not Knowledge.sees(game, viewer, hex))


## Milan on the duel and Genoa on north Italy, both thin at radius 2.
func _cases() -> Array[Case]:
	var italy := EconomyFixture.game(GEN)
	FogFixture.thin(italy, GEN, 2)
	return [Case.new("duel, Milan", FogFixture.duel_thin(), AiFixture.MILAN), Case.new("north Italy, Genoa", italy, GEN)]


## The good a hex makes by the rules (Economy.good_of), -1 for none.
func _good(g: Game, view: StateView, i: int) -> int:
	return Economy.good_of(g, view, g.map.hex_of(i))


# ----- what a case holds ---------------------------------------------------------------------------------------------


## The things a fog proof needs, counted: a case without one of them would pass its check empty.
func _holds(c: Case) -> Dictionary:
	var g := c.game
	var view := StateView.of(g.state)
	var mine := Countries.by_tag(g, c.viewer).id
	var out := {"dark land": 0, "dark sea": 0, "light foreign land": 0, "light goods": 0, "dark goods": 0,
		"light towns": 0, "dark towns": 0, "known beside dark of another owner": 0, "dark mountains": 0}
	for i: int in g.map.hex_count():
		var land := g.map.land[i] == 1
		var town := g.state.main_use[i] == ImproveRules.SETTLEMENT and g.state.level[i] >= ParchmentView.TOWN_DOT_LEVEL
		if c.known[i] == 0:
			out["dark land"] += int(land)
			out["dark sea"] += int(not land)
			out["dark goods"] += int(_good(g, view, i) >= 0)
			out["dark towns"] += int(town)
			out["dark mountains"] += int(land and g.map.height_m[i] > ParchmentShape.MOUNTAIN_M)
			continue
		if c.light[i] == 1:
			out["light foreign land"] += int(land and g.state.owner[i] != 0 and g.state.owner[i] != mine)
			out["light goods"] += int(_good(g, view, i) >= 0)
			out["light towns"] += int(town)
		if land and g.state.owner[i] != 0:
			for d: int in 6:
				var j := g.map.index_of(g.map.neighbour(g.map.hex_of(i), d))
				if j >= 0 and g.map.land[j] == 1 and c.known[j] == 0 and g.state.owner[j] != g.state.owner[i]:
					out["known beside dark of another owner"] += 1
					break
	return out


func test_each_case_holds_what_the_proofs_read() -> void:
	var empty: Array[String] = []
	for c: Case in _cases():
		var held := _holds(c)
		for key: String in held:
			if int(held[key]) == 0:
				empty.append("%s: no %s" % [c.what, key])
	assert_eq(empty, [] as Array[String])


# ----- the owners, the fill and the lines (R12 to R14) ---------------------------------------------------------------


## The hexes whose owner byte is not what the viewer may know: UNKNOWN exactly under deep fog (the unknown fill), else
## the owner's id (0 no one and the sea), light fog too.
func _owner_problems(c: Case, bytes: PackedByteArray) -> Array[String]:
	var out: Array[String] = []
	if bytes.size() != c.game.map.hex_count():
		return ["%d owner bytes" % bytes.size()]
	for i: int in bytes.size():
		var hex := c.game.map.hex_of(i)
		var want := UNKNOWN
		if c.known[i] == 1:
			want = Territory.owner_id(c.game, hex) if c.game.map.land[i] == 1 else 0
		if bytes[i] != want:
			out.append("%s: %s byte %d, not %d%s" % [c.what, hex, bytes[i], want,
				" (light fog)" if c.light[i] == 1 else ""])
	return out


## What the shaders draw from the owner bytes (parchment_line, parchment_hatch): [{kind: coast | border | district |
## mountain, a: hex index, b: the other hex or -1}].
func _drawn(g: Game, bytes: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows := Vector2i(0, g.map.rows)
	var edges := ParchmentShape.edges(g.map, rows)
	var first: PackedInt32Array = edges["a"]
	var second: PackedInt32Array = edges["b"]
	var kinds: PackedByteArray = edges["kind"]
	for k: int in first.size():
		var a := first[k]
		var b := second[k]
		if b < 0 or bytes[a] == UNKNOWN:
			continue
		if kinds[k] == ParchmentShape.Edge.COAST:
			out.append({"kind": "coast", "a": a, "b": b})
		elif bytes[b] != UNKNOWN:
			out.append({"kind": "district" if bytes[a] == bytes[b] else "border", "a": a, "b": b})
	for hex: int in (ParchmentShape.mountains(g.map, rows)["hex"] as PackedInt32Array):
		if bytes[hex] != UNKNOWN:
			out.append({"kind": "mountain", "a": hex, "b": -1})
	return out


## The lines and marks drawn on or from a hex under deep fog (R13: a coast needs its land hex only), the borders and
## district lines that do not tell the owners as they are, and the ones that are missing.
func _line_problems(c: Case, bytes: PackedByteArray) -> Array[String]:
	var g := c.game
	var out: Array[String] = []
	var lines := _drawn(g, bytes)
	for line: Dictionary in lines:
		var a: int = line["a"]
		var b: int = line["b"]
		var kind: String = line["kind"]
		if c.known[a] == 0:
			out.append("%s: a %s on the undiscovered %s" % [c.what, kind, g.map.hex_of(a)])
		elif kind == "border" or kind == "district":
			if c.known[b] == 0:
				out.append("%s: a %s between %s and the undiscovered %s" % [c.what, kind, g.map.hex_of(a), g.map.hex_of(b)])
			elif (g.state.owner[a] != g.state.owner[b]) != (kind == "border"):
				out.append("%s: a %s between owners %d and %d" % [c.what, kind, g.state.owner[a], g.state.owner[b]])
	var edges := ParchmentShape.edges(g.map, Vector2i(0, g.map.rows))
	var wanted := 0
	for k: int in (edges["a"] as PackedInt32Array).size():
		var a: int = edges["a"][k]
		var b: int = edges["b"][k]
		var coast: bool = edges["kind"][k] == ParchmentShape.Edge.COAST
		wanted += int(b >= 0 and c.known[a] == 1 and (coast or c.known[b] == 1))
	for hex: int in (ParchmentShape.mountains(g.map, Vector2i(0, g.map.rows))["hex"] as PackedInt32Array):
		wanted += int(c.known[hex] == 1)
	if lines.size() != wanted:
		out.append("%s: %d lines and marks drawn, %d between and on discovered hexes" % [c.what, lines.size(), wanted])
	return out


func test_owners_and_lines_show_nothing_under_deep_fog_and_are_exact_under_light_fog() -> void:
	for c: Case in _cases():
		var bytes := ParchmentView.owner_bytes(c.game, c.viewer)
		assert_eq(_owner_problems(c, bytes), [] as Array[String], "%s: the owners and the fill" % c.what)
		assert_eq(_line_problems(c, bytes), [] as Array[String], "%s: the lines and the marks" % c.what)


## The case's owner bytes with every undiscovered land hex read as no one's land: what a view that masked it as unowned
## would give.
func _unowned_for_unknown(c: Case) -> PackedByteArray:
	var bytes := ParchmentView.owner_bytes(c.game, c.viewer).duplicate()
	for i: int in bytes.size():
		if c.known[i] == 0 and c.game.map.land[i] == 1:
			bytes[i] = 0
	return bytes


func test_p_a_border_between_a_discovered_and_an_undiscovered_hex_is_reported() -> void:
	for c: Case in _cases():
		var leaking := _unowned_for_unknown(c)
		var between := _line_problems(c, leaking).filter(func(line: String) -> bool:
			return line.contains("a border between") and line.contains("and the undiscovered"))
		assert_gt(between.size(), 0, "%s (P): a border drawn out of the known land into the deep fog" % c.what)
		assert_gt(_owner_problems(c, leaking).size(), 0, "%s (P): and the fill there is not the unknown paper" % c.what)
		assert_gt(_line_problems(c, c.game.state.owner).size(), 0, "%s (P): the raw owners" % c.what)


# ----- the goods, their counts and the legend (R7, R13, R14, R20, R21) -----------------------------------------------


## The hexes whose goods bytes are not the good and stage of a discovered district, or not 0, 0 elsewhere.
func _goods_byte_problems(c: Case, bytes: PackedByteArray) -> Array[String]:
	var g := c.game
	var view := StateView.of(g.state)
	var out: Array[String] = []
	if bytes.size() != 2 * g.map.hex_count():
		return ["%d goods bytes" % bytes.size()]
	for i: int in g.map.hex_count():
		var good := _good(g, view, i) if c.known[i] == 1 else -1
		var want := Vector2i.ZERO if good < 0 else Vector2i(good + 1, clampi(g.state.level[i], 1, 3))
		var have := Vector2i(bytes[2 * i], bytes[2 * i + 1])
		if have != want:
			out.append("%s: %s goods %s, not %s%s" % [c.what, g.map.hex_of(i), have, want,
				" (light fog)" if c.light[i] == 1 else ""])
	return out


## good id -> the districts the viewer has discovered that make it.
func _known_counts(c: Case) -> Dictionary:
	var view := StateView.of(c.game.state)
	var out: Dictionary = {}
	for good: Dictionary in ParchmentView.goods_list(c.game):
		out[good["id"]] = 0
	for i: int in c.game.map.hex_count():
		var good := _good(c.game, view, i)
		if good >= 0 and c.known[i] == 1:
			out[good] += 1
	return out


## The goods whose count is not that of the discovered districts; `counts` is good id -> the count shown.
func _count_problems(c: Case, counts: Dictionary) -> Array[String]:
	var want := _known_counts(c)
	var out: Array[String] = []
	for good: int in want:
		if int(counts.get(good, -1)) != int(want[good]):
			out.append("%s: good %d counted %s, %d discovered districts" % [c.what, good, counts.get(good), want[good]])
	return out


## good id -> ParchmentView.count_of for a viewer.
func _counts_shown(c: Case, viewer: StringName) -> Dictionary:
	var out: Dictionary = {}
	for good: Dictionary in ParchmentView.goods_list(c.game):
		out[good["id"]] = ParchmentView.count_of(c.game, viewer, good["id"])
	return out


## The legends whose rows are not the three stages, "Not here" and the words of the discovered count.
func _legend_problems(c: Case) -> Array[String]:
	var want := _known_counts(c)
	var out: Array[String] = []
	for good: int in want:
		var rows := ParchmentView.legend(c.game, c.viewer, good)
		var texts: Array = rows.map(func(row: Dictionary) -> String: return row["text"])
		var expected: Array = ["First stage", "Second stage", "Third stage", "Not here",
			ParchmentView.count_words(want[good])]
		if texts != expected:
			out.append("%s: the legend of good %d reads %s, not %s" % [c.what, good, texts, expected])
	return out


func test_goods_counts_and_legend_read_discovered_districts_exactly() -> void:
	for c: Case in _cases():
		assert_eq(_goods_byte_problems(c, ParchmentView.goods_bytes(c.game, c.viewer)), [] as Array[String],
			"%s: the goods bytes" % c.what)
		assert_eq(_count_problems(c, _counts_shown(c, c.viewer)), [] as Array[String], "%s: the counts" % c.what)
		assert_eq(_legend_problems(c), [] as Array[String], "%s: the legend" % c.what)


func test_p_a_goods_count_with_an_undiscovered_district_is_reported() -> void:
	for c: Case in _cases():
		var view := StateView.of(c.game.state)
		var counts := _known_counts(c)
		for i: int in c.game.map.hex_count():
			var good := _good(c.game, view, i)
			if good >= 0 and c.known[i] == 0:
				counts[good] += 1
				break
		assert_eq(_count_problems(c, counts).size(), 1, "%s (P): one district under deep fog counted" % c.what)
		assert_gt(_count_problems(c, _counts_shown(c, &"")).size(), 0, "%s (P): the whole map's counts" % c.what)
		assert_gt(_goods_byte_problems(c, ParchmentView.goods_bytes(c.game, &"")).size(), 0,
			"%s (P): the whole map's goods" % c.what)


# ----- the hover line (R14, R23) -------------------------------------------------------------------------------------


## The hover line a hex should read, from the state: "Unexplored" under deep fog; else "Sea", or place, owner and good.
func _tip_wanted(c: Case, view: StateView, i: int, mode: int, chosen: int) -> String:
	var g := c.game
	if c.known[i] == 0:
		return "Unexplored"
	if g.map.land[i] == 0:
		return "Sea"
	var parts := PackedStringArray()
	var place := str(Improve.place_of(g.map, g.map.hex_of(i)).get("name", ""))
	if place != "":
		parts.append(place)
	var tag := Territory.owner_tag(g, g.map.hex_of(i))
	parts.append("Unclaimed land" if tag == &"" else Countries.def_of(g, tag).name)
	var good := _good(g, view, i)
	if good >= 0 and mode != MapModes.Mode.GOODS:
		parts.append(g.defs.good(good).name)
	elif good >= 0 and good == chosen:
		parts.append("%s, %s" % [g.defs.good(good).name,
			ParchmentView.STAGE_TEXTS[clampi(g.state.level[i], 1, 3) - 1].to_lower()])
	return " · ".join(parts)


## The hover lines, in every mode (Goods with every good), that are not the wanted ones, for a view asked as `viewer`.
func _tip_problems(c: Case, viewer: StringName) -> Array[String]:
	var view := StateView.of(c.game.state)
	var goods: Array = ParchmentView.goods_list(c.game).map(func(good: Dictionary) -> int: return good["id"])
	var out: Array[String] = []
	for i: int in c.game.map.hex_count():
		var hex := c.game.map.hex_of(i)
		for mode: int in MODES:
			for chosen: int in (goods if mode == MapModes.Mode.GOODS else [goods[0]]):
				var line := ParchmentView.tip(c.game, viewer, hex, mode, chosen)
				var want := _tip_wanted(c, view, i, mode, chosen)
				if line != want:
					out.append("%s: %s mode %d good %d reads '%s', not '%s'" % [c.what, hex, mode, chosen, line, want])
	return out


func test_the_hover_line_is_unexplored_under_deep_fog_and_exact_elsewhere() -> void:
	for c: Case in _cases():
		assert_eq(_tip_problems(c, c.viewer), [] as Array[String], c.what)


func test_p_hover_lines_that_read_the_fog_are_reported() -> void:
	var c := _cases()[0]
	assert_gt(_tip_problems(c, &"").size(), 0, "(P): the lines of a viewer that sees all")


# ----- the names and the towns (R8, R13) -----------------------------------------------------------------------------


## The regions of one owner over the discovered land, of CountryNames.MIN_REGION_HEXES or more, by a plain flood fill:
## [{tag, region: Dictionary (hex index -> true)}].
func _regions(c: Case) -> Array[Dictionary]:
	var g := c.game
	var out: Array[Dictionary] = []
	var done: Dictionary = {}
	for country: Country in g.countries:
		for start: int in g.map.hex_count():
			if done.has(start) or c.known[start] == 0 or g.map.land[start] == 0 or g.state.owner[start] != country.id:
				continue
			var region: Array[int] = [start]
			done[start] = true
			var head := 0
			while head < region.size():
				for d: int in 6:
					var j := g.map.index_of(g.map.neighbour(g.map.hex_of(region[head]), d))
					if j >= 0 and not done.has(j) and c.known[j] == 1 and g.map.land[j] == 1 and g.state.owner[j] == country.id:
						done[j] = true
						region.append(j)
				head += 1
			if region.size() >= CountryNames.MIN_REGION_HEXES:
				var held: Dictionary = {}
				for i: int in region:
					held[i] = true
				out.append({"tag": country.tag, "region": held})
	return out


## The names that are not one for each discovered region: its size, its place on it, and the whole of its room (every
## 2 px from at - span / 2 to at + span / 2 along the angle) on the region.
func _name_problems(c: Case, names: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	var regions := _regions(c)
	for entry: Dictionary in names:
		var at: Vector2 = entry["at"]
		var home := c.game.map.index_of(MapModes.hex_at_px(at))
		var found := -1
		for r: int in regions.size():
			if regions[r]["tag"] == entry["tag"] and (regions[r]["region"] as Dictionary).has(home):
				found = r
		if found < 0 or (regions[found]["region"] as Dictionary).size() != int(entry["hexes"]):
			out.append("%s: %s of %d hexes is no discovered region at its place" % [c.what, entry["tag"], entry["hexes"]])
			continue
		var region: Dictionary = regions[found]["region"]
		var axis := Vector2.from_angle(deg_to_rad(float(entry["angle_deg"])))
		var reach := float(entry["span_px"]) * 0.5
		var samples := ceili(reach * 0.5)
		for k: int in range(-samples, samples + 1):
			var hex := MapModes.hex_at_px(at + axis * (reach * float(k) / float(samples)))
			if not region.has(c.game.map.index_of(hex)):
				out.append("%s: the room of %s runs onto %s" % [c.what, entry["tag"], hex])
				break
		regions.remove_at(found)
	for left: Dictionary in regions:
		out.append("%s: %s has a region with no name" % [c.what, left["tag"]])
	return out


## The towns that are not those of the discovered hexes: every settlement of a village or more and every living
## country's capital, with its level and whether it is a capital.
func _town_problems(c: Case, towns: Array[Dictionary]) -> Array[String]:
	var g := c.game
	var capitals: Dictionary = {}
	for country: Country in g.countries:
		if country.alive and country.capital != Country.NO_HEX:
			capitals[country.capital] = true
	var want: Dictionary = {}  # hex -> [level, capital]
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		var settled := g.state.main_use[i] == ImproveRules.SETTLEMENT
		if c.known[i] == 1 and (capitals.has(hex) or (settled and g.state.level[i] >= ParchmentView.TOWN_DOT_LEVEL)):
			var level := int(g.state.level[i]) if settled else int(Improve.place_of(g.map, hex).get("level", 0))
			want[hex] = [level, capitals.has(hex)]
	var out: Array[String] = []
	for town: Dictionary in towns:
		var hex: Vector2i = town["hex"]
		if not want.has(hex):
			out.append("%s: a town on %s (%s)" % [c.what, hex, town["name"]])
		elif want[hex] != [town["level"], town["capital"]]:
			out.append("%s: %s reads %s, not %s" % [c.what, hex, [town["level"], town["capital"]], want[hex]])
		want.erase(hex)
	for hex: Vector2i in want:
		out.append("%s: the town on %s is missing" % [c.what, hex])
	return out


func test_names_and_towns_read_discovered_hexes_only() -> void:
	for c: Case in _cases():
		var names := ParchmentView.country_names(c.game, c.viewer)
		assert_gt(names.size(), 0, c.what)
		assert_eq(_name_problems(c, names), [] as Array[String], "%s: the names" % c.what)
		assert_eq(_town_problems(c, ParchmentView.towns(c.game, c.viewer)), [] as Array[String], "%s: the towns" % c.what)


func test_p_names_and_towns_of_the_whole_map_are_reported() -> void:
	for c: Case in _cases():
		assert_gt(_name_problems(c, ParchmentView.country_names(c.game, &"")).size(), 0, "%s (P): names" % c.what)
		assert_gt(_town_problems(c, ParchmentView.towns(c.game, &"")).size(), 0, "%s (P): towns" % c.what)


# ----- every output, in every mode, whatever lies under the deep fog -------------------------------------------------


## Every output of ParchmentView for a viewer, by name: the bytes, the goods with their counts and legends, the names,
## the towns, and the hover line of every hex in Terrain, Owner and Goods mode (every good).
func _outputs(c: Case, viewer: StringName) -> Dictionary:
	var g := c.game
	var out := {"owner bytes": ParchmentView.owner_bytes(g, viewer), "goods bytes": ParchmentView.goods_bytes(g, viewer),
		"goods": ParchmentView.goods_list(g), "names": ParchmentView.country_names(g, viewer),
		"towns": ParchmentView.towns(g, viewer)}
	var goods: Array = ParchmentView.goods_list(g).map(func(good: Dictionary) -> int: return good["id"])
	out["counts and legends"] = goods.map(func(good: int) -> Array:
		return [ParchmentView.count_of(g, viewer, good), ParchmentView.legend(g, viewer, good)])
	for mode: int in MODES:
		var lines := PackedStringArray()
		for i: int in g.map.hex_count():
			for chosen: int in (goods if mode == MapModes.Mode.GOODS else [goods[0]]):
				lines.append(ParchmentView.tip(g, viewer, g.map.hex_of(i), mode, chosen))
		out["hover lines, mode %d" % mode] = lines
	return out


## Changes who owns the land and what stands on it on every hex `which` marks (never to or from the viewer, so its
## sight and its discovered set stay) and drops the view cache. Returns how many hexes changed.
func _scramble(c: Case, which: PackedByteArray) -> int:
	var g := c.game
	var mine := Countries.by_tag(g, c.viewer).id
	var changed := 0
	for i: int in g.map.hex_count():
		if which[i] == 0 or g.map.land[i] == 0 or g.state.owner[i] == mine:
			continue
		var owner := (int(g.state.owner[i]) + 1 + i % 5) % (g.countries.size() + 1)
		g.state.owner[i] = 0 if owner == mine else owner
		g.state.main_use[i] = (int(g.state.main_use[i]) + 1 + i % 7) % FamilyIds.COUNT
		g.state.level[i] = 1 + (int(g.state.level[i]) + i) % 3
		changed += 1
	g.view_cache.clear()
	g.version += 1
	return changed


## The names of the outputs that differ.
func _changed_outputs(before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in before:
		if var_to_str(after[key]) != var_to_str(before[key]):
			out.append(key)
	return out


func test_no_output_in_any_mode_changes_with_the_land_under_deep_fog() -> void:
	for c: Case in _cases():
		var before := _outputs(c, c.viewer)
		var dark := PackedByteArray()
		dark.resize(c.known.size())
		for i: int in dark.size():
			dark[i] = 1 - c.known[i]
		assert_gt(_scramble(c, dark), 20, "%s: land under deep fog to change" % c.what)
		assert_eq(_changed_outputs(before, _outputs(c, c.viewer)), [] as Array[String], c.what)


func test_p_outputs_that_read_the_deep_fog_change_with_it() -> void:
	var c := _cases()[1]
	var before := _outputs(c, &"")
	var dark := PackedByteArray()
	dark.resize(c.known.size())
	for i: int in dark.size():
		dark[i] = 1 - c.known[i]
	_scramble(c, dark)
	var changed := _changed_outputs(before, _outputs(c, &""))
	var still: Array = before.keys().filter(func(key: String) -> bool: return not changed.has(key))
	assert_eq(still, ["goods"], "(P): for a viewer that sees all, every output but the list of goods follows the land")


func test_light_fog_changes_show_at_once_and_exactly() -> void:
	for c: Case in _cases():
		var owners := ParchmentView.owner_bytes(c.game, c.viewer)
		var goods := ParchmentView.goods_bytes(c.game, c.viewer)
		assert_gt(_scramble(c, c.light), 10, "%s: land under light fog to change" % c.what)
		var after := ParchmentView.owner_bytes(c.game, c.viewer)
		assert_true(after != owners and ParchmentView.goods_bytes(c.game, c.viewer) != goods,
			"%s: the owners and goods follow the land under light fog" % c.what)
		assert_eq(_owner_problems(c, after), [] as Array[String], "%s: the owners" % c.what)
		assert_eq(_line_problems(c, after), [] as Array[String], "%s: the lines" % c.what)
		assert_eq(_goods_byte_problems(c, ParchmentView.goods_bytes(c.game, c.viewer)), [] as Array[String],
			"%s: the goods" % c.what)
		assert_eq(_count_problems(c, _counts_shown(c, c.viewer)), [] as Array[String], "%s: the counts" % c.what)
		assert_eq(_tip_problems(c, c.viewer), [] as Array[String], "%s: the hover lines" % c.what)
		assert_eq(_name_problems(c, ParchmentView.country_names(c.game, c.viewer)), [] as Array[String],
			"%s: the names" % c.what)
		assert_eq(_town_problems(c, ParchmentView.towns(c.game, c.viewer)), [] as Array[String], "%s: the towns" % c.what)
