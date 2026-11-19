## CountryDef (core/defs/country_def.gd; docs/architecture/m2-build-spec.md section 4.7, 5.1 and 10):
## defaults, validation and planted faults (tag form, names, division, tinctures), resource round trip.
extends GutTest

const TINCTURES: Dictionary[StringName, Color] = {
	&"or": Color("#d4a82c"),
	&"argent": Color("#efeadf"),
	&"gules": Color("#b3261e"),
	&"azure": Color("#2b5aa8"),
	&"sable": Color("#241f1c"),
	&"vert": Color("#2e7d3c"),
	&"purpure": Color("#6b3a7a"),
}


func _valid_genoa() -> CountryDef:
	var c := CountryDef.new()
	c.tag = &"GEN"
	c.name = "Genoa"
	c.long_name = "Republic of Genoa"
	c.adjective = "Genoese"
	c.colour = Color("#be3c6e")
	c.capital_name = ""
	c.ruler = "the Doge of Genoa"
	c.arms_division = &"cross"
	c.arms_field = &"argent"
	c.arms_charge = &"gules"
	c.tip = "A narrow coast of harbours under the mountains; little land, much sea."
	return c


func test_defaults_and_divisions() -> void:
	var c := CountryDef.new()
	assert_eq(c.tag, &"")
	assert_eq(c.name, "")
	assert_eq(c.long_name, "")
	assert_eq(c.adjective, "")
	assert_eq(c.colour, Color())
	assert_eq(c.capital_name, "")
	assert_eq(c.arms_division, &"")
	assert_eq(c.arms_field, &"")
	assert_eq(c.arms_charge, &"")
	assert_eq(c.tip, "")
	assert_eq(CountryDef.DIVISIONS.size(), 12)
	for div: StringName in [
		&"plain", &"per_pale", &"per_fess", &"per_bend", &"quarterly", &"cross",
		&"saltire", &"chief", &"fess", &"pale", &"bend", &"bordure",
	]:
		assert_true(CountryDef.DIVISIONS.has(div), "division %s present" % [div])


func test_valid_country_passes_validate() -> void:
	var genoa := _valid_genoa()
	assert_eq(genoa.validate(TINCTURES), [] as Array[String])
	# Outside power: capital_name set, tip empty.
	var pap := CountryDef.new()
	pap.tag = &"PAP"
	pap.name = "Papal States"
	pap.long_name = "Papal States"
	pap.adjective = "Papal"
	pap.colour = Color("#f0e6a0")
	pap.capital_name = "Rome"
	pap.ruler = "the Pope"
	pap.arms_division = &"saltire"
	pap.arms_field = &"gules"
	pap.arms_charge = &"or"
	assert_eq(pap.validate(TINCTURES), [] as Array[String])
	# Plain division allows matching field and charge tinctures.
	var plain := _valid_genoa()
	plain.arms_division = &"plain"
	plain.arms_charge = plain.arms_field
	assert_eq(plain.validate(TINCTURES), [] as Array[String])


func test_planted_fault_tag_form() -> void:
	for bad_tag: StringName in [&"", &"gen", &"Gen", &"GE", &"GENO", &"G1N", &"G-N"]:
		var c := _valid_genoa()
		c.tag = bad_tag
		var errors := c.validate(TINCTURES)
		assert_eq(errors.size(), 1, "bad tag '%s' should report one error" % [bad_tag])
		assert_true(errors[0].contains("tag"), "error mentions tag for '%s'" % [bad_tag])


func test_planted_fault_empty_names() -> void:
	var c := _valid_genoa()
	c.name = ""
	var errors := c.validate(TINCTURES)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("name"))

	c = _valid_genoa()
	c.long_name = "   "
	errors = c.validate(TINCTURES)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("long_name"))

	c = _valid_genoa()
	c.adjective = ""
	errors = c.validate(TINCTURES)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("adjective"))


func test_planted_fault_unknown_division_and_tinctures() -> void:
	var c := _valid_genoa()
	c.arms_division = &"chevron"
	var errors := c.validate(TINCTURES)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("arms_division"))

	c = _valid_genoa()
	c.arms_field = &"orange"
	errors = c.validate(TINCTURES)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("arms_field") and errors[0].contains("tincture"))

	c = _valid_genoa()
	c.arms_charge = &"crimson"
	errors = c.validate(TINCTURES)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("arms_charge") and errors[0].contains("tincture"))

	var blank := CountryDef.new()
	assert_eq(blank.validate(TINCTURES).size(), 8, "all eight required fields reported on blank def")


func test_resource_round_trip_preserves_fields() -> void:
	var src := _valid_genoa()
	var path := "user://test_country_def_c1.tres"
	var err := ResourceSaver.save(src, path)
	assert_eq(err, OK)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CountryDef
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_not_null(loaded)
	assert_eq(loaded.tag, src.tag)
	assert_eq(loaded.name, src.name)
	assert_eq(loaded.long_name, src.long_name)
	assert_eq(loaded.adjective, src.adjective)
	assert_true(loaded.colour.is_equal_approx(src.colour))
	assert_eq(loaded.capital_name, src.capital_name)
	assert_eq(loaded.arms_division, src.arms_division)
	assert_eq(loaded.arms_field, src.arms_field)
	assert_eq(loaded.arms_charge, src.arms_charge)
	assert_eq(loaded.tip, src.tip)
	assert_eq(loaded.validate(TINCTURES), [] as Array[String])


func test_committed_data_defs_and_scenario_load_and_validate() -> void:
	var tres_paths: Array[String] = []
	_collect_tres("res://data/defs/countries", tres_paths)
	tres_paths.append("res://data/defs/game_defs.tres")
	assert_eq(tres_paths.size(), 14, "expected game_defs.tres + 13 country .tres files")
	assert_true(tres_paths.has("res://data/defs/game_defs.tres"))

	var defs := ResourceLoader.load(
		"res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GameDefs
	assert_not_null(defs)
	assert_eq(defs.validate(), [] as Array[String])
	assert_eq(defs.countries.size(), 13)

	var country_count := 0
	for path: String in tres_paths:
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_not_null(res, "failed to load %s" % path)
		if path == "res://data/defs/game_defs.tres":
			assert_true(res is GameDefs, "%s should be GameDefs" % path)
			assert_eq((res as GameDefs).validate(), [] as Array[String], path)
		else:
			assert_true(res is CountryDef, "%s should be CountryDef" % path)
			var cdef := res as CountryDef
			assert_eq(cdef.validate(defs.tinctures), [] as Array[String], path)
			assert_not_null(defs.country(cdef.tag), "%s missing from GameDefs" % path)
			country_count += 1
	assert_eq(country_count, 13)

	var map := ResourceLoader.load(
		"res://data/maps/north_italy.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as MapData
	var scen := ResourceLoader.load(
		"res://data/scenarios/north_italy_1480.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as ScenarioDef
	assert_not_null(map)
	assert_not_null(scen)
	assert_eq(scen.validate(map, defs, true), [] as Array[String])


func test_every_country_has_its_spec_ruler() -> void:
	var rulers := {
		&"SAV": "the Duke of Savoy", &"MLO": "the Duke of Milan", &"VEN": "the Doge of Venice",
		&"GEN": "the Doge of Genoa", &"TUS": "the Signoria of Florence",
		&"SWI": "the Diet of the Confederation", &"MAN": "the Marquis of Mantua",
		&"FER": "the Duke of Ferrara", &"SIE": "the Signoria of Siena", &"LUC": "the Elders of Lucca",
		&"FRA": "the King of France", &"AUS": "the Archduke of Austria", &"PAP": "the Pope",
	}
	var defs := ResourceLoader.load(
		"res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GameDefs
	assert_eq(defs.countries.size(), 13)
	for c: CountryDef in defs.countries:
		assert_true(rulers.has(c.tag), "%s has a spec ruler" % [c.tag])
		assert_eq(c.ruler, rulers.get(c.tag, ""), "%s ruler" % [c.tag])


func test_planted_fault_empty_ruler() -> void:
	var c := _valid_genoa()
	c.ruler = ""
	var errors := c.validate(TINCTURES)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("ruler"))


static func _collect_tres(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect_tres(full, out)
			elif entry.ends_with(".tres"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
