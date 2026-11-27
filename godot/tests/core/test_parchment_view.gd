## The parchment's facts (docs/architecture/map-overview-build-spec.md R7, R8, R12 to R14, R20, R21, R23, D3, D7): the
## owner and goods bytes, the goods and their legend, the country names, the towns and the hover line. On the thin fog
## fixture (Milan, thin at radius 2) no output holds anything of an undiscovered hex. Each planted case (P) feeds a check
## what a leaking view would give, and the check must report it.
extends GutTest

const VIEWER := AiFixture.MILAN
const GEN := &"GEN"


func _thin() -> Game:
	var g := FogFixture.duel_thin()
	g.player = VIEWER
	return g


func _full() -> Game:
	return EconomyFixture.game(GEN)


## The viewer's discovered hexes, by Knowledge (the rule the views must agree with).
func _known(g: Game, viewer: StringName) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(g.map.hex_count())
	for i: int in g.map.hex_count():
		out[i] = 1 if Knowledge.discovered(g, viewer, g.map.hex_of(i)) else 0
	return out


## The first undiscovered (`seen` false) or light-fog (`seen` true) land hex of another country that `want` accepts.
func _foggy_hex(g: Game, light: bool, want: Callable = Callable()) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		var tag := Territory.owner_tag(g, hex)
		if not g.map.is_land(hex) or tag == &"" or tag == VIEWER:
			continue
		if Knowledge.discovered(g, VIEWER, hex) != light or (light and Knowledge.sees(g, VIEWER, hex)):
			continue
		if not want.is_valid() or bool(want.call(hex)):
			return hex
	return Army.NO_HEX


## Changes what stands on every hex the viewer has not discovered, and who owns it (never the viewer, so its sight and
## its discovered set stay), then drops the view cache. Returns how many hexes changed.
func _scramble_undiscovered(g: Game) -> int:
	var seen := _known(g, VIEWER)
	var mine := Countries.by_tag(g, VIEWER).id
	var changed := 0
	for i: int in g.map.hex_count():
		if seen[i] == 1 or g.map.land[i] == 0:
			continue
		var owner := (int(g.state.owner[i]) + 1 + i % 5) % (g.countries.size() + 1)
		g.state.owner[i] = 0 if owner == mine else owner
		g.state.main_use[i] = (int(g.state.main_use[i]) + 1 + i % 7) % FamilyIds.COUNT
		g.state.level[i] = 1 + (int(g.state.level[i]) + i) % 3
		changed += 1
	g.view_cache.clear()
	return changed


## Every output of ParchmentView for the viewer, as one text.
func _everything(g: Game) -> String:
	var parts: Array = [ParchmentView.owner_bytes(g, VIEWER), ParchmentView.goods_bytes(g, VIEWER),
		ParchmentView.goods_list(g), ParchmentView.country_names(g, VIEWER), ParchmentView.towns(g, VIEWER)]
	for good: Dictionary in ParchmentView.goods_list(g):
		parts.append([ParchmentView.count_of(g, VIEWER, good["id"]), ParchmentView.legend(g, VIEWER, good["id"])])
	for i: int in g.map.hex_count():
		for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.GOODS]:
			parts.append(ParchmentView.tip(g, VIEWER, g.map.hex_of(i), mode, Economy.GRAIN))
	return var_to_str(parts)


# ----- the owner bytes -----------------------------------------------------------------------------------------------


## The undiscovered hexes whose byte is not UNKNOWN: the one test of the owner bytes' fog.
func _owner_leaks(g: Game, bytes: PackedByteArray) -> int:
	var seen := _known(g, VIEWER)
	var out := 0
	for i: int in g.map.hex_count():
		if seen[i] == 0 and bytes[i] != ParchmentView.UNKNOWN:
			out += 1
	return out


func test_owner_bytes_mask_every_undiscovered_hex_and_are_exact_elsewhere() -> void:
	var g := _thin()
	var bytes := ParchmentView.owner_bytes(g, VIEWER)
	assert_eq(bytes.size(), g.map.hex_count())
	assert_gt(bytes.count(ParchmentView.UNKNOWN), 20, "the thin fixture leaves hexes undiscovered")
	assert_eq(_owner_leaks(g, bytes), 0, "255 on every undiscovered hex, land or sea")
	var seen := _known(g, VIEWER)
	var wrong := 0
	for i: int in g.map.hex_count():
		if seen[i] == 1 and bytes[i] != Territory.owner_id(g, g.map.hex_of(i)):
			wrong += 1
	assert_eq(wrong, 0, "a discovered hex: its owner's id, 0 for no one and the sea")
	var light := _foggy_hex(g, true)
	assert_ne(light, Army.NO_HEX, "a light-fog hex to read")
	assert_eq(int(bytes[g.map.index_of(light)]), Territory.owner_id(g, light), "light fog is exact (R14)")


func test_p_the_raw_owner_bytes_are_reported() -> void:
	var g := _thin()
	assert_gt(_owner_leaks(g, g.state.owner), 20, "P: the raw owner gives the undiscovered hexes away")


func test_owner_bytes_of_the_sandbox_viewer_are_the_owners() -> void:
	var g := _full()
	assert_eq(ParchmentView.owner_bytes(g, &""), g.state.owner, "the viewer \"\" sees all")
	assert_eq(ParchmentView.owner_bytes(null, VIEWER), PackedByteArray())


func test_owner_bytes_follow_a_discovery_and_a_change_of_owner() -> void:
	var g := _thin()
	var hex := _foggy_hex(g, false)
	var i := g.map.index_of(hex)
	assert_eq(int(ParchmentView.owner_bytes(g, VIEWER)[i]), ParchmentView.UNKNOWN)
	var before := ParchmentView.owner_bytes(g, VIEWER)
	FogFixture.thin(g, VIEWER, 30)
	assert_eq(int(ParchmentView.owner_bytes(g, VIEWER)[i]), Territory.owner_id(g, hex), "discovered: the owner shows")
	assert_eq(int(before[i]), ParchmentView.UNKNOWN, "the array given earlier is not written")
	var venice := Countries.by_tag(g, AiFixture.VENICE).id
	var to := Countries.by_tag(g, VIEWER).id if Territory.owner_id(g, hex) == venice else venice
	Territory.transfer(g, [hex] as Array[Vector2i], to)
	assert_eq(int(ParchmentView.owner_bytes(g, VIEWER)[i]), to, "the new owner")


# ----- the goods -----------------------------------------------------------------------------------------------------


## The hexes whose goods bytes are not what Economy.good_of and the level say for a hex `seen` marks, and not 0, 0 for
## any other: the one test of the goods bytes.
func _goods_problems(g: Game, bytes: PackedByteArray, seen: PackedByteArray) -> int:
	var view := StateView.of(g.state)
	var out := 0
	for i: int in g.map.hex_count():
		var good := Economy.good_of(g, view, g.map.hex_of(i)) if seen[i] == 1 else -1
		var want := Vector2i.ZERO if good < 0 else Vector2i(good + 1, clampi(g.state.level[i], 1, 3))
		if Vector2i(bytes[2 * i], bytes[2 * i + 1]) != want:
			out += 1
	return out


func test_goods_bytes_are_good_of_and_the_level_on_north_italy() -> void:
	var g := _full()
	var bytes := ParchmentView.goods_bytes(g, &"")
	assert_eq(bytes.size(), 2 * g.map.hex_count())
	assert_eq(_goods_problems(g, bytes, _known(g, &"")), 0)
	assert_gt(ParchmentView.count_of(g, &"", Economy.GRAIN), 0, "north Italy makes grain")


func test_goods_bytes_are_nothing_on_wild_settlement_and_castle_hexes() -> void:
	var g := _full()
	# A castle for certain, whatever the seed built.
	var wild_land := -1
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and g.state.main_use[i] == 0:
			wild_land = i
			break
	g.state.main_use[wild_land] = ImproveRules.CASTLE
	g.state.level[wild_land] = 2
	g.version += 1
	var bytes := ParchmentView.goods_bytes(g, &"")
	var found: Dictionary = {0: 0, ImproveRules.SETTLEMENT: 0, ImproveRules.CASTLE: 0}
	var wrong := 0
	for i: int in g.map.hex_count():
		var use := int(g.state.main_use[i])
		if g.map.land[i] == 0 or not found.has(use):
			continue
		found[use] += 1
		if bytes[2 * i] != 0 or bytes[2 * i + 1] != 0:
			wrong += 1
	for use: int in found:
		assert_gt(int(found[use]), 0, "a hex of use %d to read" % use)
	assert_eq(wrong, 0, "wild hexes, settlements and castles make none (R7)")


func test_goods_bytes_agree_with_good_of_for_every_family_animal_and_ore() -> void:
	var g := _full()
	for i: int in g.map.hex_count():
		g.state.main_use[i] = i % FamilyIds.COUNT
		g.state.level[i] = i % 4  # level 0 makes none
	g.version += 1
	var bytes := ParchmentView.goods_bytes(g, &"")
	assert_eq(_goods_problems(g, bytes, _known(g, &"")), 0, "every family at every level")
	var made := 0
	for good: Dictionary in ParchmentView.goods_list(g):
		if ParchmentView.count_of(g, &"", good["id"]) > 0:
			made += 1
	assert_gte(made, 13, "the animals and the ores of north Italy's heights are among them")


func test_goods_bytes_of_a_thin_viewer_are_nothing_on_undiscovered_hexes() -> void:
	var g := _thin()
	var bytes := ParchmentView.goods_bytes(g, VIEWER)
	assert_eq(_goods_problems(g, bytes, _known(g, VIEWER)), 0, "0, 0 under deep fog; exact elsewhere, light fog too")


func test_p_goods_bytes_that_name_an_undiscovered_district_are_reported() -> void:
	var g := _thin()
	var unmasked := ParchmentView.goods_bytes(g, &"")
	assert_gt(_goods_problems(g, unmasked, _known(g, VIEWER)), 0, "P: the whole map's goods given to a thin viewer")


func test_counts_read_discovered_districts_only() -> void:
	var g := _thin()
	var seen := _known(g, VIEWER)
	var view := StateView.of(g.state)
	var fewer := 0
	for good: Dictionary in ParchmentView.goods_list(g):
		var expected := 0
		var all := 0
		for i: int in g.map.hex_count():
			if Economy.good_of(g, view, g.map.hex_of(i)) == int(good["id"]):
				all += 1
				expected += int(seen[i])
		assert_eq(ParchmentView.count_of(g, VIEWER, good["id"]), expected, str(good["key"]))
		if expected < all:
			fewer += 1
	assert_gt(fewer, 0, "some good has districts under deep fog")
	assert_eq(ParchmentView.count_of(g, VIEWER, -1), 0)
	assert_eq(ParchmentView.count_of(g, VIEWER, 99), 0)


func test_goods_bytes_follow_a_change_of_use_and_level() -> void:
	var g := _full()
	var hex := EconomyFixture.VINEYARD_HEX
	var i := g.map.index_of(hex)
	g.state.main_use[i] = ImproveRules.VINEYARD
	g.state.level[i] = 1
	var wine := g.defs.good_id(&"wine")
	var one := ParchmentView.goods_bytes(g, GEN)
	var count := ParchmentView.count_of(g, GEN, wine)
	assert_eq([int(one[2 * i]), int(one[2 * i + 1])], [wine + 1, 1])
	g.state.level[i] = 3
	assert_eq(int(ParchmentView.goods_bytes(g, GEN)[2 * i + 1]), 3, "the level is read again")
	g.state.main_use[i] = 0
	assert_eq(int(ParchmentView.goods_bytes(g, GEN)[2 * i]), 0, "cleared")
	assert_eq(ParchmentView.count_of(g, GEN, wine), count - 1)


func test_goods_list_is_every_good_a_family_makes_in_defs_order() -> void:
	var g := _full()
	var list := ParchmentView.goods_list(g)
	assert_eq(list.size(), 16, "every good of the game has a family")
	for k: int in list.size():
		var good := g.defs.goods[k]
		assert_eq(list[k], {"id": good.id, "key": good.key, "name": good.name, "icon": good.icon})
	var defs := EconomyFixture.defs()
	var families: Array[FamilyDef] = []
	for fam: FamilyDef in defs.families:
		if fam.id == ImproveRules.VINEYARD or fam.id == ImproveRules.GRAZING:
			families.append(fam)
	defs.families = families
	g.defs = defs
	var keys: Array = ParchmentView.goods_list(g).map(func(d: Dictionary) -> StringName: return d["key"])
	assert_eq(keys, [&"wine", &"wool", &"cattle", &"horses"], "only what some family makes, in GameDefs order")
	assert_eq(ParchmentView.goods_list(null), [] as Array[Dictionary])


func test_legend_of_grain_on_north_italy() -> void:
	var g := _full()
	var count := ParchmentView.count_of(g, GEN, Economy.GRAIN)
	var rows := ParchmentView.legend(g, GEN, Economy.GRAIN)
	assert_eq(rows.map(func(r: Dictionary) -> int: return r["stage"]), [1, 2, 3, 0, ParchmentView.COUNT_ROW])
	assert_eq(rows.map(func(r: Dictionary) -> int: return r["pips"]), [1, 2, 3, 0, 0])
	assert_eq(rows.map(func(r: Dictionary) -> String: return r["text"]), ["First stage", "Second stage", "Third stage",
		"Not here", "%d districts you know make it" % count])
	assert_eq(ParchmentView.legend(g, GEN, -1), [] as Array[Dictionary], "an unknown good")


func test_count_words() -> void:
	assert_eq(ParchmentView.count_words(0), "none you know")
	assert_eq(ParchmentView.count_words(1), "1 district you know makes it")
	assert_eq(ParchmentView.count_words(14), "14 districts you know make it")
	assert_eq(ParchmentView.count_words(1250), "1,250 districts you know make it")


# ----- the country names ---------------------------------------------------------------------------------------------


## The regions of one owner over the hexes `seen` marks, of CountryNames.MIN_REGION_HEXES or more: [{tag, region}],
## worked out here by a plain flood fill.
func _regions(g: Game, seen: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var done: Dictionary = {}
	for c: Country in g.countries:
		for start: int in g.map.hex_count():
			if done.has(start) or seen[start] == 0 or g.map.land[start] == 0 or g.state.owner[start] != c.id:
				continue
			var region: Array[int] = [start]
			done[start] = true
			var head := 0
			while head < region.size():
				for d: int in 6:
					var j := g.map.index_of(g.map.neighbour(g.map.hex_of(region[head]), d))
					if j >= 0 and not done.has(j) and seen[j] == 1 and g.map.land[j] == 1 and g.state.owner[j] == c.id:
						done[j] = true
						region.append(j)
				head += 1
			if region.size() >= CountryNames.MIN_REGION_HEXES:
				out.append({"tag": c.tag, "region": region})
	return out


## The long axis of the region's hex centres in degrees, within 55, found by trying every tenth of a degree: the angle
## along which the centres spread most.
func _long_axis(g: Game, region: Array) -> float:
	var mid := Vector2.ZERO
	for i: int in region:
		mid += MapTiles.cell_centre(g.map.hex_of(i))
	mid /= float(region.size())
	var best := 0.0
	var most := -1.0
	for step: int in range(-899, 901):
		var axis := Vector2.from_angle(deg_to_rad(step * 0.1))
		var spread := 0.0
		for i: int in region:
			spread += pow((MapTiles.cell_centre(g.map.hex_of(i)) - mid).dot(axis), 2.0)
		if spread > most:
			most = spread
			best = step * 0.1
	return clampf(best, -ParchmentView.NAME_ANGLE_MAX_DEG, ParchmentView.NAME_ANGLE_MAX_DEG)


## What is wrong with a list of names for a viewer: a name that is not of a region of discovered hexes (its size), a
## region with no name, or a name that does not stand on its region.
func _name_problems(g: Game, names: Array[Dictionary], viewer: StringName) -> Array[String]:
	var out: Array[String] = []
	var regions := _regions(g, _known(g, viewer))
	for entry: Dictionary in names:
		var at := g.map.index_of(MapModes.hex_at_px(entry["at"]))
		var found := -1
		for r: int in regions.size():
			if regions[r]["tag"] == entry["tag"] and (regions[r]["region"] as Array).size() == int(entry["hexes"]) \
					and (regions[r]["region"] as Array).has(at):
				found = r
				break
		if found < 0:
			out.append("%s of %d hexes is no discovered region at its place" % [entry["tag"], entry["hexes"]])
		else:
			regions.remove_at(found)
	for left: Dictionary in regions:
		out.append("%s has a region with no name" % left["tag"])
	return out


func test_country_names_are_of_discovered_regions_only() -> void:
	var g := _thin()
	var names := ParchmentView.country_names(g, VIEWER)
	assert_gt(names.size(), 2, "the viewer and its neighbours are named")
	assert_eq(_name_problems(g, names, VIEWER), [] as Array[String])
	var full := _regions(g, _known(g, &""))
	var smaller := 0
	for entry: Dictionary in names:
		for r: Dictionary in full:
			if r["tag"] == entry["tag"] and (r["region"] as Array).size() > int(entry["hexes"]):
				smaller += 1
				break
	assert_gt(smaller, 0, "some country is named by part of its land only")


func test_p_a_region_counted_with_an_undiscovered_hex_is_reported() -> void:
	var g := _thin()
	var counted := ParchmentView.country_names(g, VIEWER)
	counted[0]["hexes"] = int(counted[0]["hexes"]) + 1
	assert_gt(_name_problems(g, counted, VIEWER).size(), 0, "P: one hex more than the discovered region")
	assert_gt(_name_problems(g, ParchmentView.country_names(g, &""), VIEWER).size(), 0,
		"P: the names of the whole land given to a thin viewer")


## The names whose room leaves their region: some point from at - span / 2 to at + span / 2 along the angle (both ends
## and every 2 px between) is not on the region of discovered hexes that `at` stands on.
func _run_problems(g: Game, names: Array[Dictionary], viewer: StringName) -> Array[String]:
	var out: Array[String] = []
	var regions := _regions(g, _known(g, viewer))
	for entry: Dictionary in names:
		var at: Vector2 = entry["at"]
		var region: Array = []
		for r: Dictionary in regions:
			if r["tag"] == entry["tag"] and (r["region"] as Array).has(g.map.index_of(MapModes.hex_at_px(at))):
				region = r["region"]
		var axis := Vector2.from_angle(deg_to_rad(float(entry["angle_deg"])))
		var reach := float(entry["span_px"]) * 0.5
		var samples := ceili(reach)
		var off := 0
		for k: int in range(-samples, samples + 1):
			var p := at + axis * (reach * float(k) / float(samples))
			if not region.has(g.map.index_of(MapModes.hex_at_px(p))):
				off += 1
		if off > 0 or reach <= 0.0:
			out.append("%s at %s: %d of %d samples off its region" % [entry["tag"], at, off, 2 * samples + 1])
	return out


## The longest unbroken stretch inside `region` along `angle` found by sampling: lines 6 px apart, a point every 4 px.
func _longest_run(g: Game, region: Array, angle: float) -> float:
	var axis := Vector2.from_angle(deg_to_rad(angle))
	var across := Vector2(-axis.y, axis.x)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for i: int in region:
		var c := MapTiles.cell_centre(g.map.hex_of(i))
		var uv := Vector2(c.dot(axis), c.dot(across))
		low = low.min(uv)
		high = high.max(uv)
	var best := 0.0
	for line: int in ceili((high.y - low.y) / 6.0) + 1:
		var run := 0.0
		var u := low.x - 70.0
		while u <= high.x + 70.0:
			if region.has(g.map.index_of(MapModes.hex_at_px(axis * u + across * (low.y + 6.0 * line)))):
				run += 4.0
				best = maxf(best, run)
			else:
				run = 0.0
			u += 4.0
	return best


## The names as the view gave them before: the region's whole length along the angle as the span, at the middle of the
## hex centres, or at the region's innermost hex when that middle is off the region.
func _whole_extent(g: Game, names: Array[Dictionary], viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var regions := _regions(g, _known(g, viewer))
	for entry: Dictionary in names:
		for r: Dictionary in regions:
			var region: Array = r["region"]
			if r["tag"] != entry["tag"] or not region.has(g.map.index_of(MapModes.hex_at_px(entry["at"]))):
				continue
			var axis := Vector2.from_angle(deg_to_rad(float(entry["angle_deg"])))
			var mid := Vector2.ZERO
			var low := INF
			var high := -INF
			for i: int in region:
				var c := MapTiles.cell_centre(g.map.hex_of(i))
				mid += c
				low = minf(low, c.dot(axis))
				high = maxf(high, c.dot(axis))
			mid /= float(region.size())
			if not region.has(g.map.index_of(MapModes.hex_at_px(mid))):
				mid = MapTiles.cell_centre(CountryNames.region_label_hex(g.map, PackedInt32Array(region)))
			out.append(entry.merged({"at": mid, "span_px": high - low + 104.0}, true))
	return out


func test_country_names_angle_span_text_and_place() -> void:
	for g: Game in [_thin(), _full()]:
		var viewer := g.player
		var regions := _regions(g, _known(g, viewer))
		var names := ParchmentView.country_names(g, viewer)
		assert_eq(names.size(), regions.size())
		for k: int in names.size():
			var entry := names[k]
			var region: Array = regions[k]["region"]
			assert_eq(entry["tag"], regions[k]["tag"], "country id order, then region order")
			assert_eq(entry["text"], Countries.def_of(g, entry["tag"]).name)
			var angle: float = entry["angle_deg"]
			assert_between(angle, -55.0, 55.0, str(entry["tag"]))
			var found := _long_axis(g, region)
			# A region as long upright as level has no long axis to speak of; every other agrees with the search.
			if absf(found) < 54.9:
				assert_almost_eq(angle, found, 0.2, "%s: the main axis of its discovered hex centres" % entry["tag"])
			var longest := _longest_run(g, region, angle)
			assert_gte(float(entry["span_px"]), 0.85 * longest, "%s: about the longest stretch there is" % entry["tag"])
			assert_lte(float(entry["span_px"]), longest + 40.0, "%s: and a stretch that is there" % entry["tag"])
		assert_eq(_run_problems(g, names, viewer), [] as Array[String], "every name's room lies on its region")


## A full game in which the country `tag` holds exactly `hexes` (the rest of its land is no one's).
func _holding(tag: StringName, hexes: Array[Vector2i]) -> Game:
	var g := _full()
	var id := Countries.by_tag(g, tag).id
	for i: int in g.map.hex_count():
		if g.state.owner[i] == id:
			g.state.owner[i] = 0
	for hex: Vector2i in hexes:
		g.state.owner[g.map.index_of(hex)] = id
	return g


func _names_for(g: Game, tag: StringName, viewer: StringName = &"") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in ParchmentView.country_names(g, viewer):
		if entry["tag"] == tag:
			out.append(entry)
	return out


func test_a_level_row_is_level_and_a_column_is_held_at_55_degrees() -> void:
	var row: Array[Vector2i] = []
	var column: Array[Vector2i] = []
	for k: int in 6:
		row.append(Vector2i(4 + k, 4))
		column.append(Vector2i(4, 3 + k))
	var level := _names_for(_holding(GEN, row), GEN)
	assert_eq(level.size(), 1)
	assert_almost_eq(float(level[0]["angle_deg"]), 0.0, 0.001)
	assert_almost_eq(float(level[0]["span_px"]), 6.0 * 104.0 - 1.0, 0.01, "six hexes across, half a px in at each end")
	var middle := (MapTiles.cell_centre(row[0]) + MapTiles.cell_centre(row[5])) * 0.5
	assert_almost_eq((level[0]["at"] as Vector2).distance_to(middle), 0.0, 0.01, "the middle")
	var upright := _names_for(_holding(GEN, column), GEN)
	assert_eq(upright.size(), 1)
	assert_almost_eq(absf(float(upright[0]["angle_deg"])), 55.0, 0.001)
	assert_eq(_names_for(_holding(GEN, row.slice(0, 2)), GEN).size(), 0, "two hexes are not named")


func test_a_name_never_stands_off_its_region() -> void:
	var middle := Vector2i(8, 6)
	var ring: Array[Vector2i] = []
	for d: int in 6:
		ring.append(_full().map.neighbour(middle, d))
	var g := _holding(GEN, ring)
	var names := _names_for(g, GEN)
	assert_eq(names.size(), 1)
	assert_true(ring.has(MapModes.hex_at_px(names[0]["at"])), "the middle of a ring is not its own: the name stands on it")


## A U (a level foot of seven hexes with an arm of four up from each end: the middle of the centres lies in the hollow),
## and two blocks side by side joined by a thin way below them.
func _bent_shapes() -> Array[Array]:
	var u: Array[Vector2i] = []
	var split: Array[Vector2i] = []
	for col: int in range(4, 11):
		u.append(Vector2i(col, 8))
	for row: int in range(4, 8):
		u.append_array([Vector2i(4, row), Vector2i(10, row)])
	for col: int in range(4, 12):
		split.append(Vector2i(col, 6))
	for row: int in range(3, 6):
		for col: int in [2, 3, 4, 11, 12, 13]:
			split.append(Vector2i(col, row))
	return [u, split]


func test_a_bent_or_split_region_is_given_one_unbroken_run() -> void:
	for shape: Array[Vector2i] in _bent_shapes():
		var g := _holding(GEN, shape)
		var names := _names_for(g, GEN, &"")
		assert_eq(names.size(), 1, "one region")
		assert_eq(int(names[0]["hexes"]), shape.size())
		assert_eq(_run_problems(g, names, &""), [] as Array[String], "every point of the room is on the region")
		var region: Array = shape.map(func(h: Vector2i) -> int: return g.map.index_of(h))
		var longest := _longest_run(g, region, names[0]["angle_deg"])
		assert_gte(float(names[0]["span_px"]), 0.9 * longest - 8.0, "the long way is taken, not an arm's width")
		assert_gte(float(names[0]["span_px"]), 5.0 * 104.0)
		assert_lt(float(names[0]["span_px"]), longest + 8.0)


func test_p_a_room_over_the_whole_extent_of_a_bent_region_is_reported() -> void:
	for shape: Array[Vector2i] in _bent_shapes():
		var g := _holding(GEN, shape)
		var old := _whole_extent(g, _names_for(g, GEN, &""), &"")
		assert_eq(old.size(), 1)
		assert_eq(_run_problems(g, old, &"").size(), 1, "P: the region's whole length runs off a bent or split region")


func test_a_clamped_angle_gives_a_run_inside_the_region() -> void:
	# An upright column held at 55 degrees: the room is a short slant across it, not its height.
	var column: Array[Vector2i] = []
	for row: int in range(3, 11):
		column.append(Vector2i(4, row))
	var g := _holding(GEN, column)
	var names := _names_for(g, GEN, &"")
	assert_eq(_run_problems(g, names, &""), [] as Array[String])
	assert_lt(float(names[0]["span_px"]), 300.0, "far under the column's length")
	assert_gte(float(names[0]["span_px"]), 104.0, "and a hex's room at least")
	assert_eq(_run_problems(g, _whole_extent(g, names, &""), &"").size(), 1, "P: its whole extent is not on it")


func test_of_near_equal_runs_the_one_nearest_the_middle_is_taken() -> void:
	# Five rows of ten hexes, the bottom one longer by one: its run is the longest, the middle row's is 10 / 11 of it.
	var block: Array[Vector2i] = []
	for row: int in range(4, 9):
		for col: int in range(3, 13 if row < 8 else 14):
			block.append(Vector2i(col, row))
	var g := _holding(GEN, block)
	var names := _names_for(g, GEN, &"")
	assert_eq(names.size(), 1)
	assert_eq(MapModes.hex_at_px(names[0]["at"]).y, 6, "the name stays in the middle, not on the longest row")
	var region: Array = block.map(func(h: Vector2i) -> int: return g.map.index_of(h))
	var longest := _longest_run(g, region, names[0]["angle_deg"])
	assert_between(float(names[0]["span_px"]), ParchmentView.NAME_RUN_NEAR * longest - 8.0, longest - 40.0,
		"a run near the longest, which is on another line")
	assert_eq(_run_problems(g, names, &""), [] as Array[String])


func test_two_discovered_patches_joined_only_under_fog_are_named_apart() -> void:
	# Seven hexes in a row; the viewer discovers the two ends of three and not the one between.
	var row: Array[Vector2i] = []
	for k: int in 7:
		row.append(Vector2i(2 + k, 3))
	var g := _holding(GEN, row)
	var lucca := Countries.by_tag(g, &"LUC")
	g.sight.clear()
	Sight.refresh(g)
	var bits := PackedByteArray()
	bits.resize((g.map.hex_count() + 7) >> 3)
	for k: int in [0, 1, 2, 4, 5, 6]:
		var i := g.map.index_of(row[k])
		bits[i >> 3] = bits[i >> 3] | (1 << (i & 7))
	lucca.explored = bits
	g.sight.clear()
	Sight.refresh(g)
	g.version += 1
	assert_false(Knowledge.discovered(g, &"LUC", row[3]), "the hex between is under deep fog")
	var names := _names_for(g, GEN, &"LUC")
	assert_eq(names.size(), 2, "the fog between hides that they join")
	for entry: Dictionary in names:
		assert_eq(int(entry["hexes"]), 3)
	assert_eq(_names_for(g, GEN).size(), 1, "one region to a viewer that sees all")


func test_country_names_follow_a_change_of_owner_and_are_copies() -> void:
	var g := _full()
	var before := ParchmentView.country_names(g, GEN)
	var untouched := before.duplicate(true)
	before[0]["text"] = "spoiled"
	assert_eq(ParchmentView.country_names(g, GEN), untouched, "a caller's change does not reach the next answer")
	var venice := Countries.by_tag(g, &"VEN")
	var genoa := Countries.by_tag(g, GEN)
	var taken: Array[Vector2i] = []
	for i: int in Territory.districts(g, venice.id):
		if taken.size() < 12:
			taken.append(g.map.hex_of(i))
	Territory.transfer(g, taken, genoa.id)
	var after := ParchmentView.country_names(g, GEN)
	assert_ne(after, untouched, "the transfer renames")
	assert_eq(_name_problems(g, after, GEN), [] as Array[String])
	g.view_cache.clear()
	assert_eq(ParchmentView.country_names(g, GEN), after, "the kept names equal names made from nothing")
	assert_eq(ParchmentView.country_names(EconomyFixture.game(&""), &""), ParchmentView.country_names(_full(), &""))
	assert_eq(ParchmentView.country_names(Game.new_game(EconomyFixture.map(), 1480), &""), [] as Array[Dictionary],
		"a map-only game names none")


# ----- the towns -----------------------------------------------------------------------------------------------------


func _town_leaks(g: Game, towns: Array[Dictionary]) -> int:
	var out := 0
	for town: Dictionary in towns:
		if not Knowledge.discovered(g, VIEWER, town["hex"]):
			out += 1
	return out


func test_towns_are_capitals_first_then_by_level_then_name() -> void:
	var g := _full()
	var towns := ParchmentView.towns(g, &"")
	var capitals: Dictionary = {}
	for c: Country in g.countries:
		if c.alive and c.capital != Country.NO_HEX:
			capitals[c.capital] = true
	var wanted: Dictionary = capitals.duplicate()
	for i: int in g.map.hex_count():
		if g.state.main_use[i] == ImproveRules.SETTLEMENT and g.state.level[i] >= ParchmentView.TOWN_DOT_LEVEL:
			wanted[g.map.hex_of(i)] = true
	assert_eq(towns.size(), wanted.size(), "every village or larger and every capital, once")
	for k: int in towns.size():
		var town := towns[k]
		var hex: Vector2i = town["hex"]
		var i := g.map.index_of(hex)
		assert_true(wanted.has(hex))
		assert_eq(town["capital"], capitals.has(hex), str(hex))
		assert_eq(town["capital"], k < capitals.size(), "capitals first")
		assert_eq(town["name"], str(Improve.place_of(g.map, hex).get("name", "")))
		assert_eq(town["level"], int(g.state.level[i]))
		assert_eq(town["at"], MapTiles.cell_centre(hex))
		if k > 0 and towns[k - 1]["capital"] == town["capital"]:
			var above := towns[k - 1]
			assert_true(int(above["level"]) > int(town["level"]) or (above["level"] == town["level"]
				and str(above["name"]) <= str(town["name"])), "by level, then name: %s before %s" % [above, town])


func test_towns_read_the_state_and_the_capitals() -> void:
	var g := _full()
	var genoa := Countries.by_tag(g, GEN)
	var village := -1
	for i: int in g.map.hex_count():
		if g.state.main_use[i] == ImproveRules.SETTLEMENT and g.state.level[i] == 2 and g.map.hex_of(i) != genoa.capital:
			village = i
			break
	var listed := func(hex: Vector2i) -> Array:
		return ParchmentView.towns(g, &"").filter(func(t: Dictionary) -> bool: return t["hex"] == hex)
	assert_eq((listed.call(g.map.hex_of(village)) as Array).size(), 1)
	g.state.level[village] = 1
	assert_eq((listed.call(g.map.hex_of(village)) as Array).size(), 0, "a hamlet has no dot")
	g.state.level[g.map.index_of(genoa.capital)] = 1
	assert_eq((listed.call(genoa.capital) as Array).size(), 1, "a capital is listed whatever its level")
	genoa.alive = false
	assert_eq((listed.call(genoa.capital) as Array).size(), 0, "a dead country has no capital")
	genoa.alive = true
	var place := Improve.place_of(g.map, genoa.capital)
	var first: Dictionary = (listed.call(genoa.capital) as Array)[0]
	assert_eq([first["name"], first["capital"]], [str(place["name"]), true])
	first["name"] = "spoiled"
	assert_eq((listed.call(genoa.capital) as Array)[0]["name"], str(place["name"]), "the towns given are copies")


func test_towns_of_a_thin_viewer_are_discovered_ones() -> void:
	var g := _thin()
	var towns := ParchmentView.towns(g, VIEWER)
	assert_gt(towns.size(), 3)
	assert_eq(_town_leaks(g, towns), 0)
	var seen := _known(g, VIEWER)
	var all := ParchmentView.towns(g, &"")
	assert_eq(towns.size(), all.filter(func(t: Dictionary) -> bool: return seen[g.map.index_of(t["hex"])] == 1).size())
	assert_gt(_town_leaks(g, all), 0, "P: the whole map's towns given to a thin viewer are reported")


# ----- the hover line ------------------------------------------------------------------------------------------------


## True when the line names the fact.
func _names_fact(line: String, fact: String) -> bool:
	return fact != "" and line.contains(fact)


func test_tip_of_an_undiscovered_hex_is_unexplored() -> void:
	var g := _thin()
	var named := func(hex: Vector2i) -> bool: return str(Improve.place_of(g.map, hex).get("name", "")) != ""
	var hex := _foggy_hex(g, false, named)
	assert_ne(hex, Army.NO_HEX, "a named place under deep fog")
	for mode: int in [MapModes.Mode.TERRAIN, MapModes.Mode.OWNER, MapModes.Mode.GOODS]:
		var line := ParchmentView.tip(g, VIEWER, hex, mode, Economy.GRAIN)
		assert_eq(line, "Unexplored")
		assert_false(_names_fact(line, str(Improve.place_of(g.map, hex)["name"])))
	assert_true(_names_fact(HexCard.title_of(g.map, hex), str(Improve.place_of(g.map, hex)["name"])),
		"P: a line with the hex's place name is reported")
	var wrong := 0
	var seen := _known(g, VIEWER)
	for i: int in g.map.hex_count():
		if (ParchmentView.tip(g, VIEWER, g.map.hex_of(i), MapModes.Mode.TERRAIN, 0) == "Unexplored") != (seen[i] == 0):
			wrong += 1
	assert_eq(wrong, 0, "\"Unexplored\" exactly on the undiscovered hexes, sea too")


func test_tip_names_the_place_the_owner_and_the_good() -> void:
	var g := _full()
	var genoa_capital := Countries.by_tag(g, GEN).capital
	assert_eq(ParchmentView.tip(g, GEN, genoa_capital, MapModes.Mode.TERRAIN, 0), "Genoa · Genoa", "a town makes none")
	var hex := EconomyFixture.VINEYARD_HEX
	var i := g.map.index_of(hex)
	g.state.main_use[i] = ImproveRules.VINEYARD
	g.state.level[i] = 2
	g.version += 1
	var place := str(Improve.place_of(g.map, hex).get("name", ""))
	var head := "%sGenoa" % ("" if place == "" else place + " · ")
	var wine := g.defs.good_id(&"wine")
	assert_eq(ParchmentView.tip(g, GEN, hex, MapModes.Mode.GOODS, wine), head + " · Wine, second stage")
	assert_eq(ParchmentView.tip(g, GEN, hex, MapModes.Mode.TERRAIN, wine), head + " · Wine")
	assert_eq(ParchmentView.tip(g, GEN, hex, MapModes.Mode.OWNER, Economy.GRAIN), head + " · Wine", "the hex's own good")
	assert_eq(ParchmentView.tip(g, GEN, hex, MapModes.Mode.GOODS, Economy.GRAIN), head,
		"Goods mode speaks of the chosen good only")
	g.state.owner[i] = 0
	assert_eq(ParchmentView.tip(g, GEN, hex, MapModes.Mode.TERRAIN, wine),
		head.replace("Genoa", "Unclaimed land") + " · Wine")


func test_tip_of_a_light_fog_hex_is_exact_and_of_sea_and_off_map() -> void:
	var g := _thin()
	var light := _foggy_hex(g, true)
	var owner := Countries.def_of(g, Territory.owner_tag(g, light)).name
	assert_true(_names_fact(ParchmentView.tip(g, VIEWER, light, MapModes.Mode.OWNER, 0), owner), "light fog is exact")
	for i: int in g.map.hex_count():
		if g.map.land[i] == 0 and Knowledge.discovered(g, &"", g.map.hex_of(i)):
			assert_eq(ParchmentView.tip(g, &"", g.map.hex_of(i), MapModes.Mode.TERRAIN, 0), "Sea")
			break
	assert_eq(ParchmentView.tip(g, VIEWER, Vector2i(-1, 0), MapModes.Mode.TERRAIN, 0), "")
	assert_eq(ParchmentView.tip(null, VIEWER, Vector2i.ZERO, MapModes.Mode.TERRAIN, 0), "")


# ----- nothing undiscovered reaches any output -----------------------------------------------------------------------


func test_no_output_changes_when_the_undiscovered_land_changes() -> void:
	var g := _thin()
	var before := _everything(g)
	var seen := _known(g, VIEWER)
	assert_gt(_scramble_undiscovered(g), 50, "land under deep fog to change")
	assert_eq(_known(g, VIEWER), seen, "the discovered set is as it was")
	assert_true(_everything(g) == before, "no output holds anything of an undiscovered hex")


func test_p_an_output_that_reads_the_undiscovered_land_changes_with_it() -> void:
	var g := _thin()
	var before := var_to_str(ParchmentView.towns(g, &""))
	var names := var_to_str(ParchmentView.country_names(g, &""))
	_scramble_undiscovered(g)
	assert_true(var_to_str(ParchmentView.towns(g, &"")) != before, "P: towns that read the fog are seen to change")
	assert_true(var_to_str(ParchmentView.country_names(g, &"")) != names, "P: and so do names")
