## Country state (core/state/country.gd; docs/architecture/m2-build-spec.md section 5.2, 5.9 and 10):
## defaults, JSON-safe round trip, schema validation and digest_text sensitivity.
extends GutTest


func test_defaults_and_create() -> void:
	var empty := Country.new()
	assert_eq(empty.id, 0)
	assert_eq(empty.tag, &"")
	assert_eq(empty.capital, Country.NO_HEX)
	assert_eq(empty.capital, Vector2i(-1, -1))
	assert_true(empty.alive)

	var gen := Country.create(7, &"GEN", Vector2i(8, 13))
	assert_eq(gen.id, 7)
	assert_eq(gen.tag, &"GEN")
	assert_eq(gen.capital, Vector2i(8, 13))
	assert_true(gen.alive)

	var fra := Country.create(1, &"FRA", Country.NO_HEX, false)
	assert_eq(fra.id, 1)
	assert_eq(fra.tag, &"FRA")
	assert_eq(fra.capital, Country.NO_HEX)
	assert_false(fra.alive)


func test_round_trip_through_json() -> void:
	var src := Country.create(7, &"GEN", Vector2i(8, 13), true)
	var d := src.to_dict()
	assert_eq(d["schema"], Country.SCHEMA)
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	assert_true(parsed is Dictionary)
	var back := Country.from_dict(parsed as Dictionary)
	assert_not_null(back)
	assert_eq(back.id, src.id)
	assert_eq(back.tag, src.tag)
	assert_eq(back.capital, src.capital)
	assert_eq(back.alive, src.alive)
	assert_eq(back.digest_text(), src.digest_text())

	# Outside power with off-map capital and alive = false also survives JSON round trip.
	var off_map := Country.create(2, &"AUS", Country.NO_HEX, false)
	var off_parsed: Variant = JSON.parse_string(JSON.stringify(off_map.to_dict()))
	assert_true(off_parsed is Dictionary)
	var off_back := Country.from_dict(off_parsed as Dictionary)
	assert_not_null(off_back)
	assert_eq(off_back.id, 2)
	assert_eq(off_back.tag, &"AUS")
	assert_eq(off_back.capital, Country.NO_HEX)
	assert_false(off_back.alive)
	assert_eq(off_back.digest_text(), off_map.digest_text())


func test_from_dict_refuses_wrong_schema_and_bad_capital() -> void:
	var d := Country.create(5, &"MLO", Vector2i(9, 9)).to_dict()
	d["schema"] = "hexa-godot/country/99"
	assert_null(Country.from_dict(d), "wrong schema version returns null")
	d["schema"] = "nope"
	assert_null(Country.from_dict(d), "unknown schema returns null")
	assert_null(Country.from_dict({}), "empty dict returns null")

	for bad_cap: Variant in [[9], [9, 9, 1], "9,9", 42]:
		var malformed := Country.create(5, &"MLO", Vector2i(9, 9)).to_dict()
		malformed["capital"] = bad_cap
		assert_null(Country.from_dict(malformed), "malformed capital returns null")

	# Direct Vector2i in an in-memory dictionary is also accepted.
	var direct := {"schema": Country.SCHEMA, "id": 5, "tag": &"MLO", "capital": Vector2i(9, 9), "alive": true}
	var from_direct := Country.from_dict(direct)
	assert_not_null(from_direct)
	assert_eq(from_direct.capital, Vector2i(9, 9))


func test_digest_text_format_and_changes_with_each_field() -> void:
	var gen := Country.create(7, &"GEN", Vector2i(8, 13), true)
	assert_eq(gen.digest_text(), "7|GEN|8,13|true")
	var fra := Country.create(1, &"FRA", Country.NO_HEX, false)
	assert_eq(fra.digest_text(), "1|FRA|-1,-1|false")

	var base := gen.digest_text()
	var seen: Dictionary = {base: true}
	var edits: Array[Callable] = [
		func(c: Country) -> void: c.id = 8,
		func(c: Country) -> void: c.tag = &"VEN",
		func(c: Country) -> void: c.capital = Vector2i(9, 13),
		func(c: Country) -> void: c.capital = Vector2i(8, 14),
		func(c: Country) -> void: c.alive = false,
	]
	for edit: Callable in edits:
		var c := Country.create(7, &"GEN", Vector2i(8, 13), true)
		edit.call(c)
		var text := c.digest_text()
		assert_false(seen.has(text), "edit must change digest_text: %s" % text)
		seen[text] = true
