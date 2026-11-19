## FamilyDef and the family part of GameDefs (core/defs/family_def.gd, core/defs/game_defs.gd;
## docs/architecture/m3-build-spec.md sections 4.3, 5.1 and 7): the 14 committed files against table 4.3, the slot
## numbers, and planted faults (P) for each rule.
extends GutTest

## Table 4.3: key, id, work seasons to level 0..top, clear seasons.
const TABLE: Array = [
	["settlements", 1, [0, 4, 4, 8, 8, 8], 1],
	["castles", 2, [0, 4, 8, 16], 1],
	["wheat", 3, [0, 4, 8, 16], 1],
	["hemp", 4, [0, 4, 8, 16], 1],
	["silk", 5, [0, 4, 8, 16], 1],
	["dyes", 6, [0, 4, 8, 16], 1],
	["vineyard", 7, [0, 4, 8, 16], 1],
	["olives", 8, [0, 4, 8, 16], 1],
	["grazing", 9, [0, 4, 8, 16], 1],
	["timber", 10, [0, 4, 8, 16], 1],
	["mines", 11, [0, 4, 8, 16], 1],
	["quarry", 12, [0, 4, 8, 16], 1],
	["salt", 13, [0, 4, 8, 16], 1],
	["harbour", 14, [0, 4, 8, 16], 1],
]


func _family(p_id: int, p_key: StringName, p_seasons: PackedInt32Array, p_clear: int = 1) -> FamilyDef:
	var f := FamilyDef.new()
	f.id = p_id
	f.key = p_key
	f.work_seasons = p_seasons
	f.clear_seasons = p_clear
	return f


func _valid_vineyard() -> FamilyDef:
	return _family(7, &"vineyard", PackedInt32Array([0, 4, 8, 16]))


func _committed_defs() -> GameDefs:
	return ResourceLoader.load(
		"res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GameDefs


func _committed_copy() -> GameDefs:
	var defs := _committed_defs()
	assert_eq(defs.validate(), [] as Array[String])
	return defs


func _load_family(key: String) -> FamilyDef:
	return ResourceLoader.load(
		"res://data/defs/families/%s.tres" % key, "", ResourceLoader.CACHE_MODE_IGNORE
	) as FamilyDef


func _has(errors: Array[String], fragment: String) -> bool:
	for e: String in errors:
		if e.contains(fragment):
			return true
	return false


func test_committed_files_load_and_match_table() -> void:
	for row: Array in TABLE:
		var key: String = row[0]
		var f := _load_family(key)
		assert_not_null(f, "%s loads" % key)
		if f == null:
			continue
		assert_eq(f.validate(), [] as Array[String], "%s validates" % key)
		assert_eq(f.id, row[1], "%s id" % key)
		assert_eq(String(f.key), key, "%s key" % key)
		assert_eq(f.work_seasons, PackedInt32Array(row[2]), "%s work_seasons" % key)
		assert_eq(f.clear_seasons, row[3], "%s clear_seasons" % key)


func test_committed_families_are_listed_in_game_defs() -> void:
	var defs := _committed_defs()
	assert_not_null(defs)
	assert_eq(defs.families.size(), 14)
	for row: Array in TABLE:
		var f := defs.family(row[1])
		assert_not_null(f, "family %d listed" % row[1])
		if f != null:
			assert_eq(String(f.key), row[0])
	assert_null(defs.family(0))
	assert_null(defs.family(15))
	assert_eq(defs.work_slots_base, 1)
	assert_eq(defs.work_slots_city_level, 4)
	assert_true(defs.works_halt_in_snow_winter)
	assert_eq(defs.validate(), [] as Array[String])


func test_duration_spot_checks() -> void:
	var defs := _committed_defs()
	# Settlements: 4 to level 1 (never begun), 4 to 2, 8 to 3 to 5.
	var s := defs.family(1)
	assert_eq(s.work_seasons[1], 4)
	assert_eq(s.work_seasons[3], 8)
	assert_eq(s.work_seasons.size(), 6)
	# Castles stop at level 3 with 16 seasons.
	var c := defs.family(2)
	assert_eq(c.work_seasons.size(), 4)
	assert_eq(c.work_seasons[3], 16)


func test_defaults() -> void:
	var f := FamilyDef.new()
	assert_eq(f.id, 0)
	assert_eq(f.key, &"")
	assert_eq(f.work_seasons.size(), 0)
	assert_eq(f.clear_seasons, 1)
	var g := GameDefs.new()
	assert_eq(g.families.size(), 0)
	assert_eq(g.work_slots_base, 1)
	assert_eq(g.work_slots_city_level, 4)
	assert_true(g.works_halt_in_snow_winter)


func test_valid_family_passes() -> void:
	assert_eq(_valid_vineyard().validate(), [] as Array[String])


func test_planted_fault_wrong_key() -> void:
	var f := _valid_vineyard()
	f.key = &"wine"
	var errors := f.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("key"), "error mentions key")


func test_planted_fault_size_does_not_fit_top_level() -> void:
	# Vineyard tops out at level 3: four entries fit, five and three do not.
	var long := _family(7, &"vineyard", PackedInt32Array([0, 4, 8, 16, 16]))
	var errors := long.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("work_seasons"))
	var short := _family(7, &"vineyard", PackedInt32Array([0, 4, 8]))
	errors = short.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("work_seasons"))
	# Settlements top out at level 5: six entries fit, five do not.
	var settle := _family(1, &"settlements", PackedInt32Array([0, 4, 4, 8, 8]))
	errors = settle.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("work_seasons"))


func test_planted_fault_zero_season() -> void:
	var f := _family(7, &"vineyard", PackedInt32Array([0, 4, 0, 16]))
	var errors := f.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("work_seasons[2]"))
	# A nonzero entry at 0 is also refused.
	var zero_base := _family(7, &"vineyard", PackedInt32Array([1, 4, 8, 16]))
	errors = zero_base.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("work_seasons[0]"))
	# Clearing takes 1 to 64 seasons.
	var no_clear := _family(7, &"vineyard", PackedInt32Array([0, 4, 8, 16]), 0)
	errors = no_clear.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("clear_seasons"))


func test_seasons_range_is_one_to_sixty_four() -> void:
	var over := _family(7, &"vineyard", PackedInt32Array([0, 4, 8, 65]))
	assert_eq(over.validate().size(), 1)
	var top := _family(7, &"vineyard", PackedInt32Array([0, 1, 8, 64]), 64)
	assert_eq(top.validate(), [] as Array[String])


func test_planted_fault_id_out_of_range() -> void:
	for bad_id: int in [0, 15]:
		var f := _family(bad_id, &"vineyard", PackedInt32Array([0, 4, 8, 16]))
		var errors := f.validate()
		assert_eq(errors.size(), 1, "id %d refused" % bad_id)
		assert_true(errors[0].contains("id"))


func test_planted_fault_two_families_one_id() -> void:
	var defs := _committed_copy()
	var fams: Array[FamilyDef] = defs.families.duplicate()
	fams[2] = _family(1, &"settlements", PackedInt32Array([0, 4, 4, 8, 8, 8]))
	defs.families = fams
	assert_true(_has(defs.validate(), "duplicate family id 1"), "duplicate id reported")


func test_planted_fault_family_count() -> void:
	var defs := _committed_copy()
	var fams: Array[FamilyDef] = defs.families.duplicate()
	fams.pop_back()
	defs.families = fams
	assert_true(_has(defs.validate(), "families has 13 entries, expected 14"), "13 families reported")


func test_planted_fault_work_slots() -> void:
	var defs := _committed_copy()
	defs.work_slots_base = 0
	assert_true(_has(defs.validate(), "work_slots_base"), "base 0 reported")
	defs.work_slots_base = 1
	defs.work_slots_city_level = 6
	assert_true(_has(defs.validate(), "work_slots_city_level"), "city level 6 reported")
	defs.work_slots_city_level = 0
	assert_true(_has(defs.validate(), "work_slots_city_level"), "city level 0 reported")
	defs.work_slots_city_level = 5
	assert_eq(defs.validate(), [] as Array[String], "city level 5 is allowed")


func test_planted_fault_null_family_entry() -> void:
	var defs := _committed_copy()
	var fams: Array[FamilyDef] = defs.families.duplicate()
	fams[0] = null
	defs.families = fams
	assert_true(_has(defs.validate(), "families[0]: entry is null"), "null entry reported")


func test_resource_round_trip() -> void:
	var src := _valid_vineyard()
	var path := "user://test_family_def.tres"
	assert_eq(ResourceSaver.save(src, path), OK)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as FamilyDef
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_not_null(loaded)
	assert_eq(loaded.id, src.id)
	assert_eq(loaded.key, src.key)
	assert_eq(loaded.work_seasons, src.work_seasons)
	assert_eq(loaded.clear_seasons, src.clear_seasons)
	assert_eq(loaded.validate(), [] as Array[String])
