## GUT tests for the Studiolo medallion (docs/architecture/ui-style-and-feedback-spec.md sections 4.11 and 5;
## m3-build-spec.md 6.2): the rim textures by size, the dial hand on one lit quarter, the busy ring, and the
## hourglass under reduce motion.
extends GutTest

var _harness: UIHarness = null
var _root: Control = null


func before_each() -> void:
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = VBoxContainer.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)


func after_each() -> void:
	_root = null
	_harness = null


func test_rim_texture_follows_the_size() -> void:
	var theme := _root.theme
	var medal := Medallion.new()
	_root.add_child(medal)
	var ring_icon := medal.get_node("Ring/RingTexture") as TextureRect
	assert_true(ring_icon.visible, "the baked rim replaces the code ring")
	assert_eq(ring_icon.texture, theme.get_icon(&"medallion_64", &"Kit"), "64 px rim")

	medal.small = true
	assert_eq(ring_icon.texture, theme.get_icon(&"medallion_30", &"Kit"), "30 px rim")
	assert_eq(ring_icon.texture.get_size(), Vector2(30.0, 30.0))


func test_dial_hand_points_at_one_lit_quarter() -> void:
	var medal := Medallion.new()
	_root.add_child(medal)
	var hand := medal.hand_node()
	assert_not_null(hand, "Dial/Hand exists")
	assert_eq(hand.get_parent().name, &"Dial", "the hand sits in the Dial")

	medal.dial = -1
	assert_false(hand.visible, "no season, no hand")

	var seen: Dictionary[float, bool] = {}
	for q: int in 4:
		medal.dial = q
		assert_true(hand.visible, "hand shows on quarter %d" % q)
		assert_almost_eq(hand.rotation, Medallion.hand_rotation(q), 0.0001, "hand angle on quarter %d" % q)
		seen[hand.rotation] = true
	assert_eq(seen.size(), 4, "each quarter has its own hand angle")
	assert_almost_eq(Medallion.hand_rotation(0), PI * 0.25, 0.0001, "spring points at the upper right quarter")

	medal.dial = 4
	assert_false(hand.visible, "out of range, no hand")


func test_busy_turns_the_ring_and_hides_the_hourglass() -> void:
	var medal := Medallion.new()
	_root.add_child(medal)
	medal.set_busy(true, false)
	assert_true(medal.is_spinning(), "ring spins when motion is allowed")
	assert_false(medal.busy_icon_node().visible, "no hourglass while the ring turns")

	medal.set_busy(false, false)
	assert_false(medal.is_spinning(), "ring stops when idle")
	assert_almost_eq(medal.ring_node().rotation, 0.0, 0.0001, "ring back at rest")


func test_reduce_motion_shows_the_hourglass_and_no_spin() -> void:
	var medal := Medallion.new()
	_root.add_child(medal)
	medal.set_busy(true, true)
	assert_false(medal.is_spinning(), "reduce motion: the ring stays still")
	assert_true(medal.busy_icon_node().visible, "reduce motion: the hourglass shows")
	assert_eq(medal.busy_icon_node().texture, _root.theme.get_icon(&"hourglass", &"Kit"), "the Kit hourglass")
	assert_false((medal.get_node("BusyIndicator") as Control).visible, "the text fallback stays hidden")

	medal.set_busy(false, true)
	assert_false(medal.busy_icon_node().visible, "idle: no hourglass")


func test_text_fallback_is_plain_ascii() -> void:
	var medal := Medallion.new()
	_root.add_child(medal)
	var text := (medal.get_node("BusyIndicator") as Label).text
	assert_eq(text, "wait")
	for i: int in text.length():
		assert_lt(text.unicode_at(i), 128, "fallback text is ASCII")
