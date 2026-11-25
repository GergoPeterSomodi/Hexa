## TileView (tile-window spec R1 to R4, R10 to R12, R14 facts, R18 land facts, R28 picture facts, 3.9 cases, 7.1 planted faults)
## on north Italy: Genoa (own port), Savona (own inland), Asti (Savoy's, foreign in sight), Milan (Milan's, light fog),
## the sea, the unexplored hexes, and the sandbox.
extends GutTest

@warning_ignore_start("integer_division")
const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const GEN := &"GEN"
const MLO := &"MLO"
const SAV := &"SAV"

var _next_id := 1


func _italy() -> Game:
	var defs := load(DEFS_PATH) as GameDefs
	var scenario: ScenarioDef = null
	for s: ScenarioDef in defs.scenarios:
		scenario = s
	return Game.new_scenario(load(MAP_PATH) as MapData, defs, scenario, 1480)


## The hex of the named place (its place record), or (-1, -1).
func _named(g: Game, place: String) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if str(Improve.place_of(g.map, hex).get("name", "")) == place:
			return hex
	return Vector2i(-1, -1)


## The first hex (in index order) of the case `case_id` for `viewer`, or (-1, -1).
func _first(g: Game, viewer: StringName, case_id: StringName) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if TileView.case_of(g, viewer, hex) == case_id:
			return hex
	return Vector2i(-1, -1)


func _bump(g: Game) -> void:
	g.version += 1


func _keys(list: Array) -> Array:
	var out: Array = []
	for cell: Dictionary in list:
		out.append(cell["key"])
	return out


func _cell(list: Array, key: String) -> Dictionary:
	for cell: Dictionary in list:
		if cell["key"] == key:
			return cell
	return {}


func test_genoa_own_port_picture_and_header() -> void:
	var g := _italy()
	var hex := _named(g, "Genoa")
	var v := TileView.of(g, GEN, hex)
	assert_eq(v["case"], &"own")
	assert_eq(v["sight"], &"sight")
	assert_true(bool(v["own_port"]), "Genoa is a port of Genoa's")
	var head: Dictionary = v["header"]
	assert_eq(head["title"], "Genoa")
	assert_eq(head["stars"], 4, "a walled town (level 4) has four stars")
	assert_true(str(head["place"]).contains("Republic of Genoa"), "the owner's long name is in the place line")
	assert_eq(head["owner"]["relation"], &"yours")
	assert_eq(head["badges"], [], "no badge on a quiet own port")
	var pic: Dictionary = head["picture"]
	assert_eq(pic["kind"], "walled_town")
	assert_eq(pic["level"], 4)
	assert_eq(pic["harbour"], 3, "the harbour addon is the port picture (1 to 3)")
	assert_eq(pic["owner_tag"], "GEN")
	assert_eq(pic["season"], Calendar.season_of(g.turn))
	assert_eq(_keys(v["strip"]), ["people", "food", "works", "ducats"], "own strip: people, food, works, ducats")


func test_savona_own_inland_strip_and_facts() -> void:
	var g := _italy()
	var hex := _named(g, "Savona")
	var v := TileView.of(g, GEN, hex)
	assert_eq(v["case"], &"own")
	## Savona is no port in the committed map (its place record says port false), so no Ships tab: a deviation from
	## spec 3.9's example, which named Savona as the port. Genoa carries the port case (test above).
	assert_false(bool(v["own_port"]))
	assert_eq(v["header"]["picture"]["kind"], "town")
	assert_eq(v["header"]["picture"]["harbour"], 0)
	var treasury := Countries.by_tag(g, GEN).treasury
	assert_eq(_cell(v["strip"], "ducats")["value"], Words.number(treasury), "the viewer's own treasury")
	var food := MapModes.food_year(g, GEN, hex)
	assert_eq(v["land"]["food"], {"made": food.x, "eaten": food.y})
	assert_eq(_cell(v["strip"], "food")["value"], Words.signed(food.x - food.y))
	assert_true(bool(v["build"]["offered"]), "own land: Buildings is offered")
	assert_true(bool(v["army"]["raise_offered"]), "a town of the viewer raises companies")
	assert_eq(v["job"]["label"], "No work under way")
	assert_true(bool(v["job"]["idle"]))
	assert_false(bool(v["job"]["cancel"]), "no work, no Cancel")


func test_own_made_goods_carry_value_at_price() -> void:
	var g := _italy()
	var v := TileView.of(g, GEN, _named(g, "Savona"))
	var made: Array = v["land"]["made"]
	assert_false(made.is_empty())
	for row: Dictionary in made:
		var price := g.defs.goods[int(row["good"])].price_milli
		@warning_ignore("integer_division")
		var want: int = int(row["loads"]) * price / 1000
		assert_eq(row["value"], want, "own rows add the value at price")


func test_asti_foreign_in_sight_has_no_owner_money_and_is_dimmed() -> void:
	var g := _italy()
	var hex := _named(g, "Asti")
	var v := TileView.of(g, GEN, hex)
	assert_eq(v["case"], &"foreign", "Asti is Savoy's, not Genoa's (deviation: spec 3.9 names it as own)")
	assert_eq(v["sight"], &"sight")
	assert_eq(_keys(v["strip"]), ["people", "garrison", "buildings", "armies"], "foreign strip: four cells, no ducats")
	assert_eq(v["header"]["owner"]["relation"], &"foreign")
	assert_eq(v["header"]["picture"]["owner_tag"], "SAV")
	assert_false(bool(v["build"]["offered"]))
	assert_eq(v["build"]["reason"], "not your land: the Duchy of Savoy holds it")
	assert_false(bool(v["army"]["raise_offered"]))
	assert_eq(v["army"]["reason"], "No armies here", "in sight with no army: the reason says so")
	assert_eq(v["land"]["food"], {}, "food is own only")
	assert_eq(v["land"]["made"][0]["value"], null, "a foreign good has no value")
	assert_eq(v["land"]["buildings"][0]["state_text"], "working")
	assert_false(v["land"]["armies_hidden"])
	assert_eq(v["job"], {}, "no work on foreign land: no job line")


func test_milan_light_fog_shows_land_not_armies() -> void:
	var g := _italy()
	var hex := _named(g, "Milan")
	var v := TileView.of(g, GEN, hex)
	assert_eq(v["sight"], &"light")
	assert_eq(v["header"]["picture"]["kind"], "city", "the picture shows in light fog (R6)")
	assert_eq(_cell(v["strip"], "garrison")["value"], "1200/1200", "the garrison is exact on a discovered fortress")
	assert_eq(_cell(v["strip"], "armies")["value"], "fog", "no army count out of sight")
	assert_true(bool(v["land"]["armies_hidden"]))
	assert_eq(v["army"]["reason"], "Out of sight: no armies are shown")
	assert_eq(v["land"]["battle"], {}, "no battle row without a witness")


## Planted fault (7.1): the owner's treasury shown on a foreign tile.
func test_owners_treasury_is_not_shown_on_a_foreign_tile() -> void:
	var g := _italy()
	Countries.by_tag(g, MLO).treasury = 987654
	_bump(g)
	var v := TileView.of(g, GEN, _named(g, "Milan"))
	assert_eq(v["sight"], &"light")
	for cell: Dictionary in v["strip"]:
		assert_ne(cell["key"], "ducats")
		assert_ne(cell["value"], Words.number(987654), "the owner's treasury is never a strip value")


## Planted fault (7.1): Food read through game.player. Viewer Milan on Milan with the player set to Genoa and to Milan
## gives the same food; the viewer Genoa on Savona likewise.
func test_food_reads_the_viewer_not_the_player() -> void:
	var g := _italy()
	var milan := _named(g, "Milan")
	var savona := _named(g, "Savona")
	g.player = GEN
	_bump(g)
	var as_genoa_player := TileView.of(g, MLO, milan)
	var genoa_savona := TileView.of(g, GEN, savona)
	g.player = MLO
	_bump(g)
	var as_milan_player := TileView.of(g, MLO, milan)
	assert_eq(as_milan_player["strip"], as_genoa_player["strip"], "the food cell does not depend on game.player")
	assert_eq(as_milan_player["land"]["food"], as_genoa_player["land"]["food"])
	var food := MapModes.food_year(g, MLO, milan)
	assert_eq(_cell(as_milan_player["strip"], "food")["value"], Words.signed(food.x - food.y))
	g.player = MLO
	_bump(g)
	assert_eq(TileView.of(g, GEN, savona)["land"]["food"], genoa_savona["land"]["food"])


## Planted fault (7.1): a picture on an unexplored hex; a place name, a ground word, a sea word or a strip in it.
func test_unexplored_carries_only_the_header_facts() -> void:
	var g := _italy()
	FogFixture.thin(g, GEN, 0)
	var hex := _first(g, GEN, &"unexplored")
	assert_ne(hex, Vector2i(-1, -1), "the thin fixture leaves undiscovered land")
	var v := TileView.of(g, GEN, hex)
	assert_eq(_keys_of(v), ["case", "header", "hex", "sight"], "R3: an unexplored hex carries only four keys")
	assert_eq(v["sight"], &"undiscovered")
	var head: Dictionary = v["header"]
	assert_eq(head["title"], "Unexplored")
	assert_eq(head["subtitle"], "Hex %d, %d" % [hex.x, hex.y])
	assert_eq(head["picture"], {}, "no picture on an unexplored hex")
	assert_eq(head["place"], "")
	assert_eq(head["owner"], {})


func test_undiscovered_sea_reads_unexplored_not_sea() -> void:
	var g := _italy()
	FogFixture.thin(g, GEN, 0)
	var hex := Vector2i(-1, -1)
	for i: int in g.map.hex_count():
		var h := g.map.hex_of(i)
		if not g.map.is_land(h) and not Knowledge.discovered(g, GEN, h):
			hex = h
			break
	assert_ne(hex, Vector2i(-1, -1), "the thin fixture leaves undiscovered sea")
	var v := TileView.of(g, GEN, hex)
	assert_eq(v["case"], &"unexplored", "an undiscovered sea hex is unexplored (R2)")
	assert_eq(v["header"]["title"], "Unexplored")


func test_sea_case_has_no_strip_no_picture_and_land_only() -> void:
	var g := _italy()
	var hex := _first(g, GEN, &"sea")
	assert_ne(hex, Vector2i(-1, -1), "a discovered sea hex")
	var v := TileView.of(g, GEN, hex)
	assert_eq(v["case"], &"sea")
	assert_eq(v["strip"], [], "the strip is hidden at sea")
	assert_eq(v["job"], {})
	assert_eq(v["header"]["picture"], {})
	assert_eq(v["header"]["owner"], {})
	assert_true(str(v["header"]["title"]).ends_with("sea"), "Coastal sea or Open sea")
	assert_false(bool(v["build"]["offered"]))
	assert_false(bool(v["army"]["raise_offered"]))
	assert_false((v["land"]["sea_rows"] as Array).is_empty(), "depth, relief, winter, coasts")
	assert_eq(v["land"]["sea_rows"][0][0], "Depth")


func test_milan_owned_by_milan_is_own_for_milan() -> void:
	var g := _italy()
	var v := TileView.of(g, MLO, _named(g, "Milan"))
	assert_eq(v["case"], &"own", "R2: the owner is the viewer's own")
	assert_eq(v["header"]["owner"]["relation"], &"yours")
	assert_eq(v["header"]["picture"]["owner_tag"], "MLO")


func test_sandbox_strip_is_people_and_food_with_title_bar() -> void:
	var defs := load(DEFS_PATH) as GameDefs
	var g := Game.new_game(load(MAP_PATH) as MapData, 1480, defs)
	var v := TileView.of(g, &"", _named(g, "Genoa"))
	assert_eq(v["case"], &"sandbox")
	assert_eq(_keys(v["strip"]), ["people", "food"])
	assert_eq(v["header"]["owner"], {}, "no owner in the sandbox")
	assert_eq(v["header"]["picture"]["kind"], "walled_town", "the picture shows in the sandbox")
	assert_true(bool(v["build"]["offered"]), "Buildings is offered (the sandbox keeps building)")
	assert_false(bool(v["army"]["raise_offered"]), "no Army tab facts in the sandbox")
	assert_true(bool(v["job"]["idle"]))


## Planted fault (7.1): a foreign army count not gated by sight. A Milan army on a light hex is not counted or named.
func test_foreign_army_out_of_sight_is_not_counted_or_badged() -> void:
	var g := _italy()
	var milan := _named(g, "Milan")
	Armies.create(g, MLO, milan, "Test Army")
	_bump(g)
	var v := TileView.of(g, GEN, milan)
	assert_eq(v["sight"], &"light")
	assert_eq(_cell(v["strip"], "armies")["value"], "fog")
	assert_eq(int(v["army"]["armies_seen"]), 0)
	assert_eq(v["header"]["badges"], [], "no Foreign army badge out of sight")


func test_foreign_army_in_sight_is_counted_and_badged_on_own_land() -> void:
	var g := _italy()
	var savona := _named(g, "Savona")
	Armies.create(g, MLO, savona, "Test Army")
	_bump(g)
	var v := TileView.of(g, GEN, savona)
	assert_eq(int(v["army"]["armies_seen"]), 1)
	assert_true(bool(v["army"]["raise_offered"]), "raising stays offered beside an army")
	var labels: Array = []
	for badge: Dictionary in v["header"]["badges"]:
		labels.append(badge["text"])
	assert_true(labels.has("Foreign army here"), "a foreign army in sight is badged plain")


func test_enemy_army_in_sight_is_badged_bad_at_war() -> void:
	var g := _italy()
	var savona := _named(g, "Savona")
	Wars.declare_war(g, {"tag": GEN, "target": MLO})
	Armies.create(g, MLO, savona, "Test Army")
	_bump(g)
	var v := TileView.of(g, GEN, savona)
	var found := false
	for badge: Dictionary in v["header"]["badges"]:
		if badge["text"] == "Enemy army here":
			found = badge["tone"] == &"bad"
	assert_true(found, "an army of a country at war with the viewer is Enemy army here, in bad tone")


func test_work_under_way_on_own_land_has_cancel_and_on_foreign_none() -> void:
	var g := _italy()
	var savona := _named(g, "Savona")
	var w := Work.new()
	w.id = _next_id
	_next_id += 1
	w.tag = GEN
	w.hex = savona
	w.action = Works.BUILD
	w.family = ImproveRules.VINEYARD
	w.level_to = 1
	w.started_turn = g.turn
	w.seasons = 4
	w.seasons_left = 4
	g.state.works.append(w)
	_bump(g)
	var own := TileView.of(g, GEN, savona)
	assert_true(bool(own["job"]["cancel"]), "Cancel on your own work")
	assert_eq(own["job"]["tag"], GEN)
	assert_false(bool(own["job"]["idle"]))
	assert_true(str(own["job"]["label"]).contains("vineyard"))
	var other := TileView.of(g, MLO, savona)
	var other_job: Dictionary = other["job"]
	assert_false(bool(other_job.get("cancel", false)), "no Cancel on another country's work")


func test_view_is_cached_per_version_and_viewer() -> void:
	var g := _italy()
	var hex := _named(g, "Genoa")
	var first := TileView.of(g, GEN, hex)
	var mid := g.view_cache.size()
	var second := TileView.of(g, GEN, hex)
	assert_eq(g.view_cache.size(), mid, "a second read is served from the cache (no new entry)")
	assert_eq(first, second)
	TileView.of(g, MLO, hex)
	assert_gt(g.view_cache.size(), mid, "the viewer is part of the key")
	var after_viewer := g.view_cache.size()
	_bump(g)
	TileView.of(g, GEN, hex)
	assert_gt(g.view_cache.size(), after_viewer, "a new version is a new key")


func test_off_map_is_empty() -> void:
	var g := _italy()
	assert_eq(TileView.of(g, GEN, Vector2i(-5, -5)), {})


func _keys_of(view: Dictionary) -> Array:
	var keys := view.keys()
	keys.sort()
	return keys
