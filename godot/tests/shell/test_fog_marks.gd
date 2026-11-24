## The map's marks and labels under fog (fog-build spec R37, FG16): nothing is drawn on an undiscovered hex. Every game is the
## 1480 scenario with Genoa (ArmyFixture.TAG) the player, thinned to its land sight (FogFixture.thin, radius 0), so most of the
## map is undiscovered. Discovery grows through Sight.see_path, which moves the explored revision the marks follow.
extends GutTest

var _g: Game = null
var _scene: MapScene = null
var _dark: StringName = &""


func before_each() -> void:
	_g = WarFixture.game()
	FogFixture.thin(_g, ArmyFixture.TAG, 0)
	_dark = _dark_country()
	Session.start_game(_g)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()


func after_each() -> void:
	Session.end_game()


func _discovered(hex: Vector2i) -> bool:
	return Knowledge.discovered(_g, ArmyFixture.TAG, hex)


func _capital(tag: StringName) -> Vector2i:
	return Countries.by_tag(_g, tag).capital


## A playable country other than the player whose capital the player has not discovered; &"" when there is none.
func _dark_country() -> StringName:
	for c: Country in _g.countries:
		if c != null and c.tag != ArmyFixture.TAG and Countries.playable(_g, c.tag) and c.capital != Country.NO_HEX:
			if not Knowledge.discovered(_g, ArmyFixture.TAG, c.capital):
				return c.tag
	return &""


## A playable country that is neither the player nor `other`; &"" when there is none.
func _third(other: StringName) -> StringName:
	for c: Country in _g.countries:
		if c != null and c.tag != ArmyFixture.TAG and c.tag != other and Countries.playable(_g, c.tag):
			return c.tag
	return &""


## The playable capitals the player has discovered: the pennants it should have.
func _discovered_capitals() -> int:
	var n := 0
	for c: Country in _g.countries:
		if c != null and Countries.playable(_g, c.tag) and c.capital != Country.NO_HEX and _discovered(c.capital):
			n += 1
	return n


## The player walks onto `hex` (radius 0) or near it: the explored set grows and its revision moves.
func _discover(hex: Vector2i, radius: int = 0) -> void:
	var walk: Array[Vector2i] = [hex]
	Sight.see_path(_g, ArmyFixture.TAG, walk, radius)
	_g.version += 1  # every writer of explored bumps the version (the view caches read it)


func _revision() -> int:
	return _g.sight.explored_revision(Countries.by_tag(_g, ArmyFixture.TAG).id)


func _work(hex: Vector2i) -> Work:
	var w := Work.new()
	w.tag = ArmyFixture.TAG
	w.hex = hex
	w.action = &"build"
	w.seasons = 3
	w.seasons_left = 2
	w.started_turn = _g.turn
	return w


func _siege(hex: Vector2i, by: StringName, progress: int, seasons: int) -> void:
	var s := Siege.new()
	s.hex = hex
	s.besieger = by
	s.progress = progress
	s.seasons = seasons
	s.name = "Siege of Test, 1480"
	s.started_turn = _g.turn
	_g.sieges.append(s)
	_g.version += 1


## A hex held by a country other than the player that the player has not discovered; NO_HEX when none.
func _held_far_hex() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		var holder := Occupation.controller_tag(_g, hex)
		if holder != &"" and holder != ArmyFixture.TAG and not _discovered(hex):
			return hex
	return ArmyFixture.NO_HEX


func _has_tag(entries: Array[Dictionary], tag: StringName) -> bool:
	for entry: Dictionary in entries:
		if entry["tag"] == tag:
			return true
	return false


func _ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for i: int in _g.countries.size():
		ids.append(i + 1)
	return ids


func test_the_thin_fixture_leaves_a_capital_in_the_dark() -> void:
	assert_ne(_dark, &"", "precondition: a playable country has a capital the player has not discovered")
	assert_true(_discovered(_capital(ArmyFixture.TAG)), "the player's own capital is discovered")


# --- capital pennants -------------------------------------------------------------------------------------------------


func test_no_pennant_on_an_undiscovered_capital() -> void:
	var pennants := CapitalMarks.new()
	add_child_autofree(pennants)
	pennants.set_mode(MapModes.Mode.OWNER)
	pennants.setup(_g)
	assert_eq(pennants.cloth_colour_of(_dark), Color.TRANSPARENT, "P: a capital mark on an undiscovered hex")
	assert_ne(pennants.cloth_colour_of(ArmyFixture.TAG), Color.TRANSPARENT, "the player's own capital keeps its pennant")
	assert_eq(pennants.pennant_count(), _discovered_capitals(), "one pennant for each discovered capital")


func test_a_pennant_returns_when_its_capital_is_discovered() -> void:
	var pennants := CapitalMarks.new()
	add_child_autofree(pennants)
	pennants.set_mode(MapModes.Mode.OWNER)
	pennants.setup(_g)
	var before := _revision()
	_discover(_capital(_dark))
	assert_gt(_revision(), before, "a discovery moves the explored revision")
	pennants._process(0.0)
	assert_ne(pennants.cloth_colour_of(_dark), Color.TRANSPARENT, "the pennant is back once the capital is discovered")
	assert_eq(pennants.pennant_count(), _discovered_capitals())


# --- work marks -------------------------------------------------------------------------------------------------------


func test_no_work_mark_on_an_undiscovered_hex_and_it_returns_on_discovery() -> void:
	var marks := WorkMarks.new()
	add_child_autofree(marks)
	var dark_hex := _capital(_dark)
	_g.state.works.append(_work(dark_hex))
	_g.state.works.append(_work(_capital(ArmyFixture.TAG)))
	_g.version += 1
	marks.setup(_g)
	assert_eq(marks.mark_count(), 1, "P: only the work on a discovered hex has a mark")
	assert_true(marks.mark_at(dark_hex).is_empty(), "no work mark on an undiscovered hex")
	_discover(dark_hex)
	marks._process(0.0)
	assert_eq(marks.mark_count(), 2, "the work mark is back once the hex is discovered")
	assert_false(marks.mark_at(dark_hex).is_empty())


# --- war marks and the siege dial -------------------------------------------------------------------------------------


func test_no_siege_dial_on_an_undiscovered_hex() -> void:
	var hex := _capital(_dark)
	var besieger := _third(_dark)
	assert_ne(besieger, &"", "precondition: a third country to besiege from")
	WarFixture.at_war(_g, besieger, _dark)
	_siege(hex, besieger, 2, 1)
	var marks := _scene.get_node("WarMarks") as WarMarks
	marks.refresh(_g, ArmyFixture.TAG)
	assert_null(marks.siege_mark(hex), "P: a siege dial on an undiscovered hex")


func test_a_light_fog_siege_shows_its_dial_without_the_besieger_colour() -> void:
	var hex := _held_far_hex()
	assert_ne(hex, ArmyFixture.NO_HEX, "precondition: a far hex held by another country")
	var holder := Occupation.controller_tag(_g, hex)
	var besieger := _third(holder)
	assert_ne(besieger, &"", "precondition: a besieger that is neither the player nor the holder")
	assert_false(Sight.sees(_g, ArmyFixture.TAG, hex), "precondition: the player does not see the hex")
	WarFixture.at_war(_g, besieger, holder)
	_siege(hex, besieger, 2, 1)
	var marks := _scene.get_node("WarMarks") as WarMarks
	var wars := _scene.get_node("MapWars") as MapWars
	marks.refresh(_g, ArmyFixture.TAG)
	assert_null(marks.siege_mark(hex), "no dial while the hex is undiscovered")
	_discover(hex)
	assert_eq(Knowledge.siege_access(_g, ArmyFixture.TAG, hex), &"land", "a discovered, unseen hex is light fog")
	wars._process(0.0)
	var dial := marks.siege_mark(hex)
	assert_not_null(dial, "the siege dial shows in light fog once the hex is discovered")
	if dial != null:
		assert_eq(dial.tone, &"plain", "P: the dial takes no besieger colour (the player is neither side)")
		assert_eq(dial.dial_done, 2, "the dial shows the progress")


# --- country and place names ------------------------------------------------------------------------------------------


func test_a_country_is_named_by_its_discovered_hexes_only() -> void:
	var labels := CountryLabels.new()
	add_child_autofree(labels)
	labels.setup(_g)
	assert_true(_has_tag(labels.entries(), ArmyFixture.TAG), "the player's own land is named")
	assert_false(_has_tag(labels.entries(), _dark), "P: a label names a country with no discovered hex")
	var everything := CountryLabels.fog_places_of(_g, _ids(), &"")
	assert_eq(everything.size(), CountryNames.places(_g).size(), "with every hex discovered, the placements are CountryNames'")
	_discover(_capital(_dark), 2)
	labels._process(0.0)
	assert_true(_has_tag(labels.entries(), _dark), "the country is named once its land is discovered")


func test_a_place_on_an_undiscovered_hex_has_no_plate() -> void:
	var none: Array[Rect2] = []
	var screen := Rect2(Vector2(-100000.0, -100000.0), Vector2(200000.0, 200000.0))
	var all_places := MapLabels.layout(_g.map, Transform2D.IDENTITY, screen, ThemeDB.fallback_font, none, null, {})
	var fog := func(hex: Vector2i) -> bool: return _discovered(hex)
	var seen := MapLabels.layout(_g.map, Transform2D.IDENTITY, screen, ThemeDB.fallback_font, none, null, {}, fog)
	assert_gt(all_places.size(), seen.size(), "P: a place on an undiscovered hex has a plate")
	for item: Dictionary in seen:
		assert_true(_discovered(item["hex"] as Vector2i), "every plate is on a discovered hex")


# --- people ribbons ---------------------------------------------------------------------------------------------------


func test_every_people_ribbon_of_the_player_is_on_a_discovered_hex() -> void:
	var c := Countries.by_tag(_g, ArmyFixture.TAG)
	for i: int in Territory.districts(_g, c.id):
		_g.state.main_use[i] = People.SETTLEMENTS
		_g.state.people_start[i] = 1000
		_g.state.people_end[i] = 2000
	_g.version += 1
	var ribbons := PeopleView.ribbons(_g, ArmyFixture.TAG)
	assert_gt(ribbons.size(), 0, "the player's settlements have people ribbons")
	for ribbon: Dictionary in ribbons:
		assert_true(_discovered(ribbon["hex"] as Vector2i), "a people ribbon is only on a hex the player discovers")
