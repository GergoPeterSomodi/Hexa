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
	assert_eq(blank.validate(TINCTURES).size(), 7, "all seven required fields reported on blank def")


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
