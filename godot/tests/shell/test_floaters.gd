## The floating ribbons (docs/architecture/m3-build-spec.md 6.6, 9): motion, caps (3 a hex, 16 in all), none off the view or
## under the dock, they wait under a modal, reduce motion fades in place, and Events.chronicled starts them.
extends GutTest

var _floaters: Floaters = null
var _view := Rect2(0, 0, 4000, 4000)


func before_each() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_floaters = Floaters.new()
	add_child_autofree(_floaters)
	_floaters.set_view(_view)
	_floaters.set_xform(Transform2D.IDENTITY)


## A land hex with a build option the rules allow, and that option's family id.
func _buildable() -> Dictionary:
	var game := Session.game
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 0 or not Improve.piece_at(game, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(game, hex):
			if bool(option["ok"]):
				return {"hex": hex, "family": int(option["family_id"])}
	return {}


func _hex(n: int) -> Vector2i:
	return Vector2i(n % 8, 2 + floori(float(n) / 8.0))


func test_the_caps_and_the_timing_constants() -> void:
	assert_eq(Floaters.MAX_PER_HEX, 3)
	assert_eq(Floaters.MAX_TOTAL, 16)
	assert_eq(Floaters.LIFETIME, 1.1)
	assert_eq(Floaters.RISE, 40.0)
	assert_eq(Floaters.STAGGER, 0.3)
	assert_eq(Floaters.STEP_DOWN, 18.0)
	assert_eq(Floaters.POP_TIME, 0.06)
	assert_eq(Floaters.FADE_FROM, 0.6)


func test_a_ribbon_is_hidden_until_it_starts_and_then_shows_its_word() -> void:
	var hex := Vector2i(5, 5)
	assert_true(_floaters.spawn("Finished", &"good", hex))
	assert_eq(_floaters.live_count(), 1)
	assert_eq(_floaters.count_at(hex), 1)
	var node := _floaters._ribbons[0]["node"] as PanelContainer
	assert_false(node.visible, "not yet shown at age 0")
	_floaters.advance(0.2)
	assert_true(node.visible)
	assert_eq((node.get_node("HBox/Word") as Label).text, "Finished")
	assert_eq((node.get_node("HBox/Dot") as ColorRect).color, Tokens.GOOD)
	assert_eq(node.theme_type_variation, &"PanelToast")


func test_the_ribbon_rises_and_is_gone_after_its_lifetime() -> void:
	var hex := Vector2i(5, 5)
	var centre := MapTiles.cell_centre(hex)
	_floaters.spawn("Built", &"muted", hex)
	var node := _floaters._ribbons[0]["node"] as PanelContainer
	_floaters.advance(0.2)
	var early := node.position.y + node.get_combined_minimum_size().y * 0.5
	_floaters.advance(0.8)
	var late := node.position.y + node.get_combined_minimum_size().y * 0.5
	assert_true(late < early, "rises")
	assert_true(early < centre.y, "born above the hex")
	assert_true(centre.y - late >= Floaters.RISE * 0.9 - 1.0, "rises about 40 px by the end")
	_floaters.advance(0.2)
	assert_eq(_floaters.live_count(), 0, "gone past 1.1 s")


func test_the_scale_runs_up_to_the_peak_and_settles_within_0_14_seconds() -> void:
	var hex := Vector2i(5, 5)
	_floaters.spawn("Begun", &"plain", hex)
	var node := _floaters._ribbons[0]["node"] as PanelContainer
	_floaters.advance(0.07)
	assert_almost_eq(node.scale.x, Floaters.SCALE_PEAK, 0.01)
	_floaters.advance(0.07)
	assert_almost_eq(node.scale.x, 1.0, 0.01)
	_floaters.advance(0.5)
	assert_almost_eq(node.scale.x, 1.0, 0.001)


func test_the_fade_starts_at_0_6_seconds() -> void:
	var hex := Vector2i(5, 5)
	_floaters.spawn("Cancelled", &"bad", hex)
	var node := _floaters._ribbons[0]["node"] as PanelContainer
	_floaters.advance(0.5)
	assert_almost_eq(node.modulate.a, 1.0, 0.001)
	_floaters.advance(0.4)
	assert_true(node.modulate.a < 0.7, "fading by 0.9 s")


func test_two_ribbons_at_one_hex_start_0_3_seconds_apart_and_sit_18_px_lower() -> void:
	_floaters.set_reduce_motion(true)  # no rise: the gap is the stacking alone
	var hex := Vector2i(5, 5)
	_floaters.spawn("Finished", &"good", hex)
	_floaters.spawn("Gained", &"good", hex)
	var first := _floaters._ribbons[0]
	var second := _floaters._ribbons[1]
	assert_almost_eq(float(second["start"]) - float(first["start"]), Floaters.STAGGER, 0.0001)
	assert_eq(int(first["slot"]), 0)
	assert_eq(int(second["slot"]), 1)
	_floaters.advance(0.5)
	var a := (first["node"] as PanelContainer)
	var b := (second["node"] as PanelContainer)
	assert_almost_eq(b.position.y - a.position.y, Floaters.STEP_DOWN, 0.01, "18 px lower each")


func test_at_most_three_ribbons_a_hex_and_the_oldest_goes() -> void:
	var hex := Vector2i(5, 5)
	_floaters.spawn("one", &"plain", hex)
	_floaters.spawn("two", &"plain", hex)
	_floaters.spawn("three", &"plain", hex)
	_floaters.spawn("four", &"plain", hex)
	assert_eq(_floaters.count_at(hex), 3)
	var words: Array[String] = []
	for ribbon: Dictionary in _floaters._ribbons:
		words.append(((ribbon["node"] as Node).get_node("HBox/Word") as Label).text)
	assert_eq(words, ["two", "three", "four"], "the oldest, 'one', went")


func test_at_most_sixteen_ribbons_in_all() -> void:
	for n: int in 20:
		_floaters.spawn("x", &"plain", _hex(n))
	assert_eq(_floaters.live_count(), 16)
	assert_eq(_floaters.count_at(_hex(0)), 0, "the oldest went")
	assert_eq(_floaters.count_at(_hex(19)), 1)


func test_a_hex_outside_the_view_or_under_the_dock_gets_no_ribbon() -> void:
	assert_false(_floaters.spawn("off", &"plain", Vector2i(500, 500)), "far off the view")
	_floaters.set_view(Rect2(0, 0, 10, 10))
	assert_false(_floaters.spawn("off", &"plain", Vector2i(5, 5)), "not in a 10 px view")
	_floaters.set_view(_view, Rect2(0, 0, 4000, 4000))
	assert_false(_floaters.spawn("docked", &"plain", Vector2i(5, 5)), "under the dock")
	assert_eq(_floaters.live_count(), 0)


func test_a_ribbon_that_leaves_the_view_is_hidden_and_comes_back() -> void:
	var hex := Vector2i(5, 5)
	_floaters.spawn("Built", &"muted", hex)
	_floaters.advance(0.3)
	var node := _floaters._ribbons[0]["node"] as PanelContainer
	assert_true(node.visible)
	_floaters.set_xform(Transform2D(Vector2.RIGHT, Vector2.DOWN, Vector2(-5000.0, -5000.0)))  # the camera moved away
	assert_false(node.visible, "none off screen")
	_floaters.set_xform(Transform2D.IDENTITY)
	assert_true(node.visible)


func test_a_ribbon_under_the_dock_is_hidden() -> void:
	var hex := Vector2i(5, 5)
	_floaters.spawn("Built", &"muted", hex)
	_floaters.advance(0.3)
	var node := _floaters._ribbons[0]["node"] as PanelContainer
	var centre := MapTiles.cell_centre(hex)
	_floaters.set_view(_view, Rect2(centre.x - 200.0, centre.y - 200.0, 400.0, 400.0))
	assert_false(node.visible, "the dock covers it")


func test_they_wait_under_a_modal_and_run_again_after() -> void:
	var hex := Vector2i(5, 5)
	_floaters.spawn("Finished", &"good", hex)
	_floaters.advance(0.3)
	var node := _floaters._ribbons[0]["node"] as PanelContainer
	var before := node.position.y
	_floaters.wait()
	assert_true(_floaters.is_waiting())
	_floaters.advance(5.0)
	assert_eq(_floaters.live_count(), 1, "not expired while waiting")
	assert_eq(node.position.y, before, "frozen in place")
	_floaters.resume()
	_floaters.advance(1.2)
	assert_eq(_floaters.live_count(), 0)


func test_reduce_motion_fades_in_place() -> void:
	_floaters.set_reduce_motion(true)
	var hex := Vector2i(5, 5)
	_floaters.spawn("Lost", &"bad", hex)
	var node := _floaters._ribbons[0]["node"] as PanelContainer
	var centre := MapTiles.cell_centre(hex)
	_floaters.advance(0.3)
	assert_eq(node.scale, Vector2.ONE, "no scale")
	assert_almost_eq(node.position.y + node.get_combined_minimum_size().y * 0.5, centre.y - Floaters.BORN_ABOVE, 0.01, "no rise")
	assert_almost_eq(node.modulate.a, 1.0, 0.001)
	_floaters.advance(0.6)
	assert_true(node.modulate.a < 0.5, "fading")


func test_a_begun_work_is_only_written_in_the_log_not_floated() -> void:
	var found := _buildable()
	var hex := found["hex"] as Vector2i
	_floaters.setup(Session.game)
	assert_true(bool(Session.act("build", {"hex": hex, "family": int(found["family"])})["ok"]))
	assert_eq(_floaters.count_at(hex), 0, "the Begun line starts no ribbon (it is a log line only)")


func test_no_game_no_ribbons_from_the_chronicle() -> void:
	var found := _buildable()
	_floaters.setup(null)
	assert_true(bool(Session.act("build", {"hex": found["hex"], "family": int(found["family"])})["ok"]))
	assert_eq(_floaters.live_count(), 0)


func test_a_land_line_uses_up_to_three_of_its_hexes() -> void:
	var entry := {"kind": "owners_changed", "hexes": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]}
	var line := {"floating": "Lost", "hex": Vector2i(1, 1)}
	assert_eq(_floaters._hexes_for(entry, line, "Lost").size(), 3)
	assert_eq(_floaters._hexes_for(entry, line, "Gained").size(), 3)
	assert_eq(_floaters._hexes_for(entry, line, "Taken"), [Vector2i(1, 1)], "a taken line uses its own hex")


func test_clear_removes_every_ribbon() -> void:
	_floaters.spawn("a", &"plain", Vector2i(5, 5))
	_floaters.spawn("b", &"plain", Vector2i(6, 5))
	_floaters.clear()
	assert_eq(_floaters.live_count(), 0)
	assert_eq(_floaters.get_child_count(), 0)


func test_a_freed_slot_is_reused_so_ribbons_never_overlap() -> void:
	var hex := Vector2i(5, 5)
	_floaters.spawn("A", &"plain", hex)
	_floaters.spawn("B", &"plain", hex)
	_floaters.spawn("C", &"plain", hex)
	_floaters.advance(1.15)  # A has gone; B and C are still up
	assert_eq(_floaters.count_at(hex), 2)
	_floaters.spawn("D", &"plain", hex)
	assert_eq(int(_floaters._ribbons[-1]["slot"]), 0, "the lowest free slot, not 2 (C's)")
	var seen := {}
	for ribbon: Dictionary in _floaters._ribbons:
		if ribbon["hex"] == hex:
			assert_false(seen.has(int(ribbon["slot"])), "no two live ribbons share a slot")
			seen[int(ribbon["slot"])] = true
	assert_eq(seen.size(), 3)


func test_a_game_ending_or_starting_clears_the_ribbons() -> void:
	_floaters.spawn("a", &"plain", Vector2i(5, 5))
	_floaters.spawn("b", &"plain", Vector2i(6, 5))
	Events.game_ended.emit()
	assert_eq(_floaters.live_count(), 0, "game_ended clears them")
	_floaters.spawn("c", &"plain", Vector2i(5, 5))
	Events.game_started.emit()
	assert_eq(_floaters.live_count(), 0, "game_started clears them")


func test_add_ribbon_starts_a_ribbon_the_public_way() -> void:
	var hex := Vector2i(5, 5)
	_floaters.add_ribbon(hex, "Finished", &"good")
	assert_eq(_floaters.count_at(hex), 1)
	var node := _floaters._ribbons[0]["node"] as PanelContainer
	assert_eq((node.get_node("HBox/Word") as Label).text, "Finished")
	assert_eq((node.get_node("HBox/Dot") as ColorRect).color, Tokens.GOOD)


func test_add_ribbon_never_floats_begun() -> void:
	_floaters.add_ribbon(Vector2i(5, 5), "Begun", &"plain")
	_floaters.add_ribbon(Vector2i(6, 5), "Begun the road", &"plain")
	assert_eq(_floaters.live_count(), 0, "a quiet word is written in the log only")


func test_add_ribbon_keeps_the_caps_and_the_view() -> void:
	var hex := Vector2i(5, 5)
	_floaters.add_ribbon(hex, "one", &"plain")
	_floaters.add_ribbon(hex, "two", &"plain")
	_floaters.add_ribbon(hex, "three", &"plain")
	_floaters.add_ribbon(hex, "four", &"plain")
	assert_eq(_floaters.count_at(hex), 3, "3 a hex")
	for n: int in 20:
		_floaters.add_ribbon(_hex(n), "x", &"plain")
	assert_eq(_floaters.live_count(), 16, "16 in all")
	_floaters.add_ribbon(Vector2i(500, 500), "off", &"plain")
	assert_eq(_floaters.count_at(Vector2i(500, 500)), 0, "only hexes on the view")


func test_add_ribbon_waits_under_a_modal() -> void:
	_floaters.add_ribbon(Vector2i(5, 5), "Finished", &"good")
	_floaters.advance(0.3)
	_floaters.wait()
	_floaters.advance(5.0)
	assert_eq(_floaters.live_count(), 1, "not expired while a modal is up")
	_floaters.resume()
	_floaters.advance(1.2)
	assert_eq(_floaters.live_count(), 0)


func test_ribbons_of_two_close_hexes_never_overlap_sideways() -> void:
	_floaters.set_reduce_motion(true)
	_floaters.set_xform(Transform2D(0.0, Vector2(0.15, 0.15), 0.0, Vector2.ZERO))  # far zoom: the hexes are close
	var a := Vector2i(5, 5)
	var b := Vector2i(6, 5)
	_floaters.spawn("Hunger −7,984", &"bad", a)
	_floaters.spawn("Hunger −1,200", &"bad", b)
	_floaters.advance(0.5)
	var first := _floaters._ribbons[0]["node"] as PanelContainer
	var second := _floaters._ribbons[1]["node"] as PanelContainer
	var r1 := Rect2(first.position, first.get_combined_minimum_size())
	var r2 := Rect2(second.position, second.get_combined_minimum_size())
	assert_false(r1.intersects(r2), "neighbouring ribbons do not cover each other's text: %s %s" % [r1, r2])


func test_a_long_people_ribbon_word_is_as_wide_as_its_text_and_the_plate_holds_it() -> void:
	for text: String in ["Hunger −7,984", "People +100,000"]:
		var node := (_floaters.spawn(text, &"bad", Vector2i(5, 5)) as bool)
		assert_true(node)
		var ribbon := _floaters._ribbons[_floaters._ribbons.size() - 1]["node"] as PanelContainer
		var word := ribbon.get_node("HBox/Word") as Label
		var wide := word.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, word.get_theme_font_size("font_size")).x
		assert_gte(word.get_combined_minimum_size().x, wide, "the word's minimum width holds %s" % text)
		assert_gte(ribbon.get_combined_minimum_size().x, wide + 8.0, "the plate is wider than the word plus the dot")
		_floaters.clear()
