## Knowledge view tests (docs/architecture/m3-build-spec.md sections 4.7, 5.6 and 9): knows (self, neighbour, far, ""),
## known in id order, unknown_count, band, band_text, witnessed (party, others, listed, public and known, public and
## unknown, "" sees all). Cases marked P are the planted-fault checks of section 9.
extends GutTest

const AAA := &"AAA"
const BBB := &"BBB"
const OUT := &"OUT"


## The 9x7 fixture with its owners replaced: `owners` maps a hex to a country id (0 is unowned).
func _game_with(owners: Dictionary) -> Game:
	var g := ScenarioFixture.game()
	g.state.owner.fill(0)
	for hex: Vector2i in owners:
		g.state.owner[g.map.index_of(hex)] = int(owners[hex])
	return g


## AAA (id 1) and BBB (id 2) share a border; OUT (id 3) is far from both.
func _border_game() -> Game:
	return _game_with({Vector2i(0, 0): 1, Vector2i(1, 0): 2, Vector2i(8, 0): 3})


## AAA sits between BBB and OUT on one row: it knows both; the hex order is the reverse of the id order.
func _between_game() -> Game:
	return _game_with({Vector2i(3, 2): 3, Vector2i(4, 2): 1, Vector2i(5, 2): 2})


func test_knows_self_neighbour_far_and_empty() -> void:
	var g := _border_game()
	assert_true(Knowledge.knows(g, AAA, AAA))
	assert_true(Knowledge.knows(g, AAA, BBB), "a neighbour is known")
	assert_true(Knowledge.knows(g, BBB, AAA), "the border is shared")
	assert_false(Knowledge.knows(g, AAA, OUT), "a far country is not known")
	assert_false(Knowledge.knows(g, OUT, AAA))
	assert_false(Knowledge.knows(g, OUT, BBB), "P: a far viewer does not know a far actor")
	assert_true(Knowledge.knows(g, &"", OUT), "the viewer \"\" sees all")
	assert_true(Knowledge.knows(g, AAA, &""), "the other \"\" is public")
	assert_true(Knowledge.knows(g, &"", &""))
	assert_false(Knowledge.knows(g, &"ZZZ", AAA), "a tag with no country knows nothing")


func test_known_in_id_order_viewer_excluded() -> void:
	var between := _between_game()
	assert_eq(Knowledge.known(between, AAA), [BBB, OUT], "id order, not hex order")
	assert_eq(Knowledge.known(between, BBB), [AAA], "BBB borders AAA only")
	assert_eq(Knowledge.known(between, OUT), [AAA])

	var border := _border_game()
	assert_eq(Knowledge.known(border, AAA), [BBB])
	assert_eq(Knowledge.known(border, OUT), [])
	assert_eq(Knowledge.known(border, &""), [AAA, BBB, OUT], "the viewer \"\" knows every country in id order")
	assert_eq(Knowledge.known(border, &"ZZZ"), [])


func test_unknown_count() -> void:
	var border := _border_game()
	assert_eq(Knowledge.unknown_count(border, AAA), 1, "OUT is unknown to AAA")
	assert_eq(Knowledge.unknown_count(border, OUT), 2, "OUT knows neither")
	assert_eq(Knowledge.unknown_count(border, &""), 0)
	assert_eq(Knowledge.unknown_count(_between_game(), AAA), 0)
	assert_eq(Knowledge.unknown_count(Game.new_game(ScenarioFixture.build()["map"] as MapData, 1), AAA), 0,
		"a map-only game has no countries")


func test_band_two_significant_figures() -> void:
	assert_eq(Knowledge.band(87), 87)
	assert_eq(Knowledge.band(1234), 1200)
	assert_eq(Knowledge.band(1250), 1300, "half rounds away from zero")
	assert_eq(Knowledge.band(-1234), -1200)
	assert_eq(Knowledge.band(-1250), -1300)
	assert_eq(Knowledge.band(0), 0)
	assert_eq(Knowledge.band(99960), 100000)
	assert_eq(Knowledge.band(-5), -5)


func test_band_text() -> void:
	assert_eq(Knowledge.band_text(1234, "ducats"), "about 1,200 ducats")
	assert_eq(Knowledge.band_text(87, ""), "about 87")
	assert_eq(Knowledge.band_text(99960, "ducats"), "about 100,000 ducats")
	assert_eq(Knowledge.band_text(1250, ""), "about 1,300")
	assert_eq(Knowledge.band_text(-1234, "ducats"), "about " + Knowledge.MINUS + "1,200 ducats")
	assert_eq(Knowledge.band_text(0, ""), "about 0")


func test_witnessed_party_and_others() -> void:
	var g := _border_game()
	# The actor always sees its own event, even when the world does not know it (OUT is far from AAA and BBB).
	assert_true(Knowledge.witnessed(g, {"tag": OUT}, OUT), "party: the actor sees it")
	assert_true(Knowledge.witnessed(g, {"tag": OUT, "witnesses": [BBB]}, OUT), "party with a witness list")
	# A listed other sees it: OUT is in `others` and does not know AAA.
	assert_true(Knowledge.witnessed(g, {"tag": AAA, "others": [OUT]}, OUT), "others: a listed other sees it")
	assert_true(Knowledge.witnessed(g, {"tag": AAA, "others": [OUT]}, AAA), "others: the actor sees it")


func test_witnessed_listed() -> void:
	var g := _border_game()
	assert_true(Knowledge.witnessed(g, {"tag": AAA, "witnesses": [OUT]}, OUT), "listed: a far witness sees it")
	# P: a non-empty witness list tells exactly the tags it holds, even a neighbour that knows the actor.
	assert_false(Knowledge.witnessed(g, {"tag": AAA, "witnesses": [OUT]}, BBB), "P: a neighbour not listed does not see it")


func test_witnessed_public() -> void:
	var g := _border_game()
	assert_true(Knowledge.witnessed(g, {"tag": AAA}, BBB), "public and known: a neighbour sees it")
	assert_true(Knowledge.witnessed(g, {"tag": "AAA"}, BBB), "a String tag is read the same")
	assert_false(Knowledge.witnessed(g, {"tag": AAA}, OUT), "P: public and unknown is false")
	assert_false(Knowledge.witnessed(g, {"tag": AAA, "witnesses": []}, OUT), "P: an empty witness list is public")
	assert_false(Knowledge.witnessed(g, {"tag": AAA, "others": []}, OUT), "P: empty others do not tell a far viewer")


func test_witnessed_empty_viewer_sees_all() -> void:
	var g := _border_game()
	assert_true(Knowledge.witnessed(g, {"tag": AAA}, &""))
	assert_true(Knowledge.witnessed(g, {"tag": OUT, "witnesses": [BBB]}, &""), "the viewer \"\" sees all")
	assert_true(Knowledge.witnessed(g, {}, &""))


func test_witnessed_reads_the_chronicle_packed_lists() -> void:
	# The Chronicle stores tag lists as PackedStringArray: LogLines and SeasonSummary hand those entries in.
	var g := _border_game()
	var packed := {"tag": AAA, "others": PackedStringArray([String(OUT)])}
	assert_true(Knowledge.witnessed(g, packed, OUT), "a packed others list tells the loser")
	var listed := {"tag": AAA, "witnesses": PackedStringArray([String(OUT)])}
	assert_true(Knowledge.witnessed(g, listed, OUT), "a packed witness list tells a listed far viewer")
	assert_false(Knowledge.witnessed(g, listed, BBB), "and not a neighbour it does not list")
