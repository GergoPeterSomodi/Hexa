## The place-name keys (PlaceNames, M7 review): one rule for the battle and siege name tables. A key is 1 to 200 characters, with no
## control character (below 32, or 127) and none of the digest separators ';', '=' and '|'. Each forged key is refused by the
## rule itself and by both tables' loaders (Battles._names_from, Sieges.from_dict).
extends GutTest


func _forged_keys() -> Array[String]:
	var out: Array[String] = []
	out.append("")
	out.append("x".repeat(PlaceNames.NAME_KEY_MAX + 1))
	out.append("Pavia;1480")
	out.append("Pavia=3")
	out.append("Pavia|1480")
	out.append("Pavia\nSiege")
	out.append("Pavia\rSiege")
	out.append("Pavia\tSiege")
	out.append("Pavia" + String.chr(7))
	out.append("Pavia" + String.chr(127))
	return out


func test_a_plain_name_is_a_key() -> void:
	assert_true(PlaceNames.key_ok("Pavia"), "a plain name")
	assert_true(PlaceNames.key_ok("Milano 2"), "a space is fine")
	assert_true(PlaceNames.key_ok("x".repeat(PlaceNames.NAME_KEY_MAX)), "the longest name is fine")
	assert_true(PlaceNames.key_ok("Città di Torino"), "a non-ASCII letter is fine")


func test_each_forged_key_is_refused_by_the_rule() -> void:
	for key: String in _forged_keys():
		assert_false(PlaceNames.key_ok(key), "refused: %s" % key.c_escape())


func test_each_forged_key_is_refused_by_the_battle_table() -> void:
	assert_not_null(Battles._names_from({"Pavia": 2}), "a plain battle name loads")
	for key: String in _forged_keys():
		var forged := {}
		forged[key] = 1
		assert_null(Battles._names_from(forged), "battle name table refuses: %s" % key.c_escape())


func test_each_forged_key_is_refused_by_the_siege_table() -> void:
	var g := EconomyFixture.game(&"SAV", false, true, 1480, true)
	Occupation.setup(g)
	var good := Sieges.to_dict(g)
	good["siege_names"] = {"Pavia": 2}
	assert_eq(Sieges.from_dict(good, g), "", "a plain siege name table loads")
	for key: String in _forged_keys():
		var forged := {"sieges": [], "siege_names": {}}
		(forged["siege_names"] as Dictionary)[key] = 1
		assert_ne(Sieges.from_dict(forged, g), "", "siege name table refuses: %s" % key.c_escape())
