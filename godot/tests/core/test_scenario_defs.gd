## ScenarioDef and GameDefs (core/defs/scenario_def.gd, core/defs/game_defs.gd;
## docs/architecture/m2-build-spec.md sections 5.1, 8.2, and 10):
## lookups, digest, resource round trip, and planted faults for every GameDefs and ScenarioDef rule.
extends GutTest


func _make_country(p_tag: StringName, p_name: String, p_long: String, p_adj: String,
		p_colour: Color, p_cap_name: String = "") -> CountryDef:
	var c := CountryDef.new()
	c.tag = p_tag
	c.name = p_name
	c.long_name = p_long
	c.adjective = p_adj
	c.colour = p_colour
	c.capital_name = p_cap_name
	c.ruler = "the Ruler of %s" % p_name
	c.arms_division = &"cross"
	c.arms_field = &"gules"
	c.arms_charge = &"argent"
	c.tip = "%s tip." % p_name
	return c


func _make_map() -> MapData:
	var m := MapData.new()
	m.id = "fixture_map"
	m.hex_w_km = 28.0
	m.ref_lat = 45.0
	m.allocate(7, 5)
	for r: int in range(1, 5):
		for c: int in range(2, 7):
			var i := r * 7 + c
			m.land[i] = 1
			m.cover[i] = 0
			m.depth[i] = 0
			m.height_m[i] = 120
			m.relief[i] = 1
	m.places = [
		{"name": "Alpha", "hex": Vector2i(3, 2), "level": 2, "castle": 0},
		{"name": "Beta", "hex": Vector2i(5, 2), "level": 1, "castle": 0},
	]
	m.place_id[m.index_of(Vector2i(3, 2))] = 0
	m.place_id[m.index_of(Vector2i(5, 2))] = 1
	return m


func _make_defs() -> GameDefs:
	var defs := GameDefs.new()
	defs.tinctures = GameDefs.default_tinctures()
	defs.cb_palette = GameDefs.default_cb_palette()
	defs.families = ScenarioFixture.families()
	FakeScenario.economy_into(defs)
	defs.countries = [
		_make_country(&"AAA", "Alpha", "Republic of Alpha", "Alphan", Color("#b3261e")),
		_make_country(&"BBB", "Beta", "Duchy of Beta", "Betan", Color("#2b5aa8")),
		_make_country(&"OUT", "Outland", "Kingdom of Outland", "Outlander", Color("#2e7d3c"), "Farburg"),
	]
	return defs


func _make_scenario(m: MapData) -> ScenarioDef:
	var s := ScenarioDef.new()
	s.id = "fixture_scen"
	s.name = "Fixture Scenario"
	s.blurb = "A small test scenario."
	s.map_id = m.id
	s.map_digest = m.digest()
	s.year = 1480
	s.countries = [&"AAA", &"BBB"]
	s.tempers = [&"builder", &"cautious"]
	s.capitals = [Vector2i(3, 2), Vector2i(5, 2)]
	s.cb_colours = PackedByteArray([0, 4])
	s.seeds = [
		{"hex": Vector2i(3, 2), "tag": &"AAA", "kind": &"town", "note": "Alpha"},
		{"hex": Vector2i(5, 2), "tag": &"BBB", "kind": &"town", "note": "Beta"},
	]
	s.owner = ScenarioGrowth.grow(m, s)
	return s


func test_game_defs_defaults_lookups_and_round_trip() -> void:
	var defs := _make_defs()
	var m := _make_map()
	var scen := _make_scenario(m)
	defs.scenarios = [scen]

	assert_eq(defs.tinctures.size(), 7)
	assert_eq(defs.cb_palette.size(), 8)
	assert_eq(defs.validate(), [] as Array[String])
	assert_eq(defs.country(&"AAA").name, "Alpha")
	assert_null(defs.country(&"ZZZ"))
	assert_eq(defs.scenario("fixture_scen"), scen)
	assert_null(defs.scenario("missing"))

	# Cache updates when entries are appended after first lookup.
	var extra := _make_country(&"CCC", "Gamma", "County of Gamma", "Gamman", Color("#d4a82c"))
	defs.countries.append(extra)
	assert_eq(defs.country(&"CCC"), extra)

	var path := "user://test_game_defs_c6.tres"
	assert_eq(ResourceSaver.save(defs, path), OK)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_not_null(loaded)
	assert_eq(loaded.digest(), defs.digest())
	assert_eq(loaded.validate(), [] as Array[String])


func test_game_defs_planted_faults() -> void:
	var m := _make_map()

	# Duplicate country tag.
	var defs := _make_defs()
	defs.countries.append(_make_country(&"AAA", "Alpha2", "Alpha Two", "Alphan2", Color("#000000")))
	var errs := defs.validate()
	assert_false(errs.is_empty())
	assert_true(errs.any(func(e: String) -> bool: return e.contains("duplicate tag")))

	# Bad CountryDef (lower-case tag, unknown division, unknown tincture).
	defs = _make_defs()
	defs.countries[0].tag = &"aaa"
	defs.countries[1].arms_division = &"chevron"
	defs.countries[2].arms_field = &"neon"
	errs = defs.validate()
	assert_eq(errs.size(), 3)

	# 7 CB colours instead of 8.
	defs = _make_defs()
	defs.cb_palette.resize(7)
	errs = defs.validate()
	assert_eq(errs.size(), 1)
	assert_true(errs[0].contains("cb_palette"))

	# Scenario listed twice.
	defs = _make_defs()
	var s1 := _make_scenario(m)
	var s2 := _make_scenario(m)
	defs.scenarios = [s1, s2]
	errs = defs.validate()
	assert_eq(errs.size(), 1)
	assert_true(errs[0].contains("duplicate scenario id"))


func test_scenario_def_helpers_digest_and_round_trip() -> void:
	var m := _make_map()
	var defs := _make_defs()
	var s := _make_scenario(m)
	s.countries.append(&"OUT")
	s.tempers.append(&"opportunist")
	s.capitals.append(ScenarioDef.NO_HEX)
	s.cb_colours.append(1)
	s.seeds.append({"hex": Vector2i(6, 4), "tag": &"OUT", "kind": &"anchor", "note": "border"})
	s.owner = ScenarioGrowth.grow(m, s)

	assert_eq(s.validate(m, defs, true), [] as Array[String])
	assert_eq(s.id_of(&"AAA"), 1)
	assert_eq(s.id_of(&"BBB"), 2)
	assert_eq(s.id_of(&"OUT"), 3)
	assert_eq(s.id_of(&"ZZZ"), 0)
	assert_eq(s.id_of(&""), 0)
	assert_eq(s.tag_of(0), &"")
	assert_eq(s.tag_of(1), &"AAA")
	assert_eq(s.tag_of(4), &"")
	assert_true(s.playable(&"AAA"))
	assert_false(s.playable(&"OUT"))
	assert_false(s.playable(&"ZZZ"))

	var std_cols := s.colours(defs, false)
	assert_eq(std_cols.size(), 3)
	assert_true(std_cols[0].is_equal_approx(Color("#b3261e")))
	var cb_cols := s.colours(defs, true)
	assert_true(cb_cols[2].is_equal_approx(defs.cb_palette[1]))

	var base_digest := s.digest()
	assert_eq(base_digest.length(), 64)
	var s_copy := _make_scenario(m)
	s_copy.owner[0] = 99
	assert_ne(s_copy.digest(), _make_scenario(m).digest())

	var path := "user://test_scenario_def_c6.tres"
	assert_eq(ResourceSaver.save(s, path), OK)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_not_null(loaded)
	assert_eq(loaded.digest(), base_digest)
	assert_eq(loaded.validate(m, defs, true), [] as Array[String])


func test_scenario_validate_planted_faults_rules_1_to_3() -> void:
	var m := _make_map()
	var defs := _make_defs()

	# Rule 1: map_id and map_digest changed.
	var s := _make_scenario(m)
	s.map_id = "other_map"
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("map_id")))

	s = _make_scenario(m)
	s.map_digest = "deadbeef"
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("map_digest")))

	# Rule 2: 0 countries, unknown tag, bad cb_colours.
	s = _make_scenario(m)
	s.countries = []
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("countries")))

	s = _make_scenario(m)
	s.countries[1] = &"ZZZ"
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("unknown country")))

	s = _make_scenario(m)
	s.cb_colours[0] = 8
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("cb_colours")))

	# Rule 3: capital on sea, capital with no place, NO_HEX without capital_name.
	s = _make_scenario(m)
	s.capitals[0] = Vector2i(0, 0)
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("capitals")))

	s = _make_scenario(m)
	s.capitals[0] = Vector2i(2, 1)  # land, but no place
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("does not hold a place")))

	var bad_defs := _make_defs()
	bad_defs.country(&"OUT").capital_name = ""
	s = _make_scenario(m)
	s.countries.append(&"OUT")
	s.capitals.append(ScenarioDef.NO_HEX)
	s.cb_colours.append(1)
	s.seeds.append({"hex": Vector2i(6, 4), "tag": &"OUT", "kind": &"anchor", "note": ""})
	s.owner = ScenarioGrowth.grow(m, s)
	assert_true(s.validate(m, bad_defs, false).any(func(e: String) -> bool: return e.contains("capital_name")))


func test_scenario_validate_planted_faults_rules_4_to_7() -> void:
	var m := _make_map()
	var defs := _make_defs()

	# Rule 4: place with no town seed; two seeds on one hex; anchor on a town; seed on sea.
	var s := _make_scenario(m)
	s.seeds.remove_at(1)
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("must have 1 town seed")))

	s = _make_scenario(m)
	s.seeds.append({"hex": Vector2i(3, 2), "tag": &"AAA", "kind": &"anchor", "note": "dup"})
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("duplicate seed")))

	s = _make_scenario(m)
	s.seeds[1]["kind"] = &"anchor"
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("anchor seed on place")))

	s = _make_scenario(m)
	s.seeds.append({"hex": Vector2i(0, 0), "tag": &"AAA", "kind": &"anchor", "note": "sea"})
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("not on land")))

	# Rule 5: pin on sea; pin with unknown tag (&"" is allowed).
	s = _make_scenario(m)
	s.pins = [{"hex": Vector2i(2, 1), "tag": &"", "note": "free"}]
	s.owner = ScenarioGrowth.grow(m, s)
	assert_eq(s.validate(m, defs, true), [] as Array[String])

	s = _make_scenario(m)
	s.pins = [{"hex": Vector2i(0, 0), "tag": &"AAA", "note": "sea"}]
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("pins")))

	s = _make_scenario(m)
	s.pins = [{"hex": Vector2i(2, 1), "tag": &"ZZZ", "note": "unknown"}]
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("pins")))

	# Rule 6: owner byte on sea; invalid owner id; capital owned by another.
	s = _make_scenario(m)
	s.owner[0] = 1
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("sea hex")))

	s = _make_scenario(m)
	s.owner[m.index_of(Vector2i(2, 1))] = 9
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("invalid owner id")))

	s = _make_scenario(m)
	s.owner[m.index_of(Vector2i(5, 2))] = 1
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("capital")))

	# Rule 7 (deep): stale owner (one land byte flipped) fails deep, passes shallow.
	s = _make_scenario(m)
	var flip_idx := m.index_of(Vector2i(4, 2))
	s.owner[flip_idx] = 2 if s.owner[flip_idx] == 1 else 1
	assert_eq(s.validate(m, defs, false), [] as Array[String], "shallow check passes")
	assert_true(s.validate(m, defs, true).any(func(e: String) -> bool: return e.contains("ScenarioGrowth.grow")))

	# Rule 7 (deep): two neighbours with same colour.
	var same_col_defs := _make_defs()
	same_col_defs.country(&"BBB").colour = same_col_defs.country(&"AAA").colour
	s = _make_scenario(m)
	assert_true(s.validate(m, same_col_defs, true).any(func(e: String) -> bool: return e.contains("colour contrast")))

	# Rule 7 (deep): two neighbours with CB colours under 20 apart (orange 0 vs yellow 3 is ~17.03).
	s = _make_scenario(m)
	s.cb_colours = PackedByteArray([0, 3])
	assert_true(s.validate(m, defs, true).any(func(e: String) -> bool: return e.contains("cb_colours contrast")))


## M8 (spec 4.4, 5.1): the scenario's tempers and start armies are validated and in its digest (P: an unknown temper).
func test_tempers_and_start_armies_validated_and_in_the_digest() -> void:
	var m := _make_map()
	var defs := _make_defs()
	var s := _make_scenario(m)
	var base := s.digest()
	assert_eq(s.validate(m, defs, false), [] as Array[String])
	s.tempers = [&"builder", &"gambler"]
	assert_true(s.validate(m, defs, false).any(func(e: String) -> bool: return e.contains("tempers[1]: unknown temper 'gambler'")))
	s.tempers = [&"builder", &"steadfast"]
	assert_eq(s.validate(m, defs, false), [] as Array[String])
	assert_ne(s.digest(), base, "tempers are in the digest")
	s.tempers = [&"builder", &"cautious"]
	assert_eq(s.digest(), base)
	s.start_armies = [{"tag": &"AAA", "hex": Vector2i(3, 2), "kind": 0, "count": 1}] as Array[Dictionary]
	assert_eq(s.validate(m, defs, false), [] as Array[String])
	assert_ne(s.digest(), base, "start_armies are in the digest")


func test_build_scenario_tool_rebuild_check_and_planted_fault() -> void:
	var builder := load("res://tools/build_scenario.gd") as GDScript
	assert_not_null(builder)
	var m := _make_map()
	var defs := _make_defs()
	var s := _make_scenario(m)
	s.owner = PackedByteArray()
	s.map_digest = ""
	defs.scenarios = [s]

	builder.call("rebuild_scenario", s, m)
	assert_eq(s.map_digest, m.digest())
	assert_eq(s.validate(m, defs, true), [] as Array[String])

	var rows: Array[Dictionary] = builder.call("summary_rows", m, defs, s)
	assert_eq(rows.size(), 2)
	assert_eq(int(rows[0]["towns"]), 1)
	assert_eq(int(rows[1]["towns"]), 1)
	assert_eq(int(rows[0]["districts"]) + int(rows[1]["districts"]), 20)

	# Save scratch copies in user:// and verify CLI --check passes, then fails on a flipped owner byte.
	var scratch := "user://c6_cli_scratch"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	var map_path := scratch.path_join("fixture_map.tres")
	var scen_path := scratch.path_join("fixture_scen.tres")
	var defs_path := scratch.path_join("game_defs.tres")
	assert_eq(ResourceSaver.save(m, map_path), OK)
	assert_eq(ResourceSaver.save(s, scen_path), OK)
	var saved_scen := ResourceLoader.load(scen_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef
	defs.scenarios = [saved_scen]
	assert_eq(ResourceSaver.save(defs, defs_path), OK)

	var godot_bin := OS.get_executable_path()
	var proj_dir := ProjectSettings.globalize_path("res://")
	var ok_out: Array = []
	var ok_code := OS.execute(godot_bin, [
		"--headless", "--path", proj_dir, "-s", "res://tools/build_scenario.gd", "--",
		"--check", "--defs=" + defs_path, "--maps-dir=" + scratch, "--scenarios-dir=" + scratch,
	], ok_out, true)
	assert_eq(ok_code, 0, "build_scenario --check passes on clean scratch copy: %s" % [ok_out])

	# Flip one land owner byte on disk and verify --check fails with exit code 1.
	var flip_i := m.index_of(Vector2i(4, 2))
	saved_scen.owner[flip_i] = 2 if saved_scen.owner[flip_i] == 1 else 1
	assert_eq(ResourceSaver.save(saved_scen, scen_path), OK)
	var bad_out: Array = []
	var bad_code := OS.execute(godot_bin, [
		"--headless", "--path", proj_dir, "-s", "res://tools/build_scenario.gd", "--",
		"--check", "--defs=" + defs_path, "--maps-dir=" + scratch, "--scenarios-dir=" + scratch,
	], bad_out, true)
	assert_eq(bad_code, 1, "build_scenario --check fails when owner byte is flipped: %s" % [bad_out])

	for fname: String in ["fixture_map.tres", "fixture_scen.tres", "game_defs.tres"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch.path_join(fname)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
