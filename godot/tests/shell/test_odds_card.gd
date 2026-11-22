## The odds card (docs/architecture/m7-build-spec.md 6.4; M7 B26): the hover card of a war target of the selected army, in place of the
## move card. Its words are OddsView's and MovePreview's, laid out as they are (the card text equals card_of of them). Fog: a hex the
## player does not see gives no odds card (the move card's words, with no numbers). A shaken army's refusal gives its two sentences in
## BAD. The card takes no mouse and no focus. Planted faults: an odds card that shows an unseen enemy's numbers; a card that steals
## the focus; a card that wraps past its width.
extends GutTest

var _game: Game = null
var _scene: MapScene = null
var _hover: MapHover = null


func before_each() -> void:
	_game = ArmyFixture.game()
	Session.start_game(_game)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_hover = MapHover.new()
	add_child_autofree(_hover)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


## A land hex of Genoa beside an enemy's land (the enemy at war with Genoa): {ours, theirs, enemy}; {} when none.
func _contact() -> Dictionary:
	var enemy := WarFixture.neighbour_of(_game, ArmyFixture.TAG)
	WarFixture.at_war(_game, enemy, ArmyFixture.TAG)
	var eid := ArmyFixture.id_of(_game, enemy)
	var mine := ArmyFixture.id_of(_game, ArmyFixture.TAG)
	for i: int in _game.map.hex_count():
		var hex := _game.map.hex_of(i)
		if not _game.map.is_land(hex) or Territory.owner_id(_game, hex) != mine:
			continue
		for d: int in 6:
			var beside := ImproveRules.neighbour(hex, d)
			if _game.map.is_land(beside) and Territory.owner_id(_game, beside) == eid:
				return {"ours": hex, "theirs": beside, "enemy": enemy}
	return {}


## The first hex of an enemy at war with Genoa that Genoa does not see and holds no army on; NO_HEX when none.
func _unseen_enemy_hex(enemy: StringName) -> Vector2i:
	var eid := ArmyFixture.id_of(_game, enemy)
	for i: int in _game.map.hex_count():
		var hex := _game.map.hex_of(i)
		if _game.map.is_land(hex) and int(_game.state.owner[i]) == eid and not Knowledge.sees(_game, ArmyFixture.TAG, hex) \
				and Armies.at(_game, hex).is_empty():
			return hex
	return ArmyFixture.NO_HEX


## Our army beside the contact and the enemy army on the far hex; selects ours on the map. Returns {army (id), c (contact)}.
func _fight_set_up() -> Dictionary:
	var c := _contact()
	assert_false(c.is_empty(), "Genoa borders an enemy on the 1480 map")
	var mine := ArmyFixture.army(_game, ArmyFixture.TAG, c.ours, 0, 2)
	ArmyFixture.army(_game, c.enemy, c.theirs, 0, 1)
	_game.version += 1
	_armies().sync()
	assert_true(_armies().select_army(mine.id))
	return {"army": mine.id, "c": c}


func _texts(lines: Array) -> Array[String]:
	var out: Array[String] = []
	for line: Variant in lines:
		out.append(str((line as Array)[0]))
	return out


func _card_texts() -> Array[String]:
	var out: Array[String] = []
	for text: String in _hover.odds_card().line_texts():
		out.append(text)
	return out


func test_hovering_an_enemy_with_an_army_selected_shows_the_odds_card() -> void:
	var set_up := _fight_set_up()
	_hover.on_hover_changed(set_up.c.theirs, Vector2(200, 200))
	assert_true(_hover.odds_card().is_open(), "the odds card shows over an enemy hex")
	assert_false(_hover.move_card().is_open(), "and the move card does not")


func test_the_card_text_is_the_odds_view_words() -> void:
	var set_up := _fight_set_up()
	var hex: Vector2i = set_up.c.theirs
	_hover.on_hover_changed(hex, Vector2(200, 200))
	var preview := MovePreview.to(_game, ArmyFixture.TAG, set_up.army, hex)
	var odds := OddsView.of(_game, ArmyFixture.TAG, set_up.army, hex)
	var card := OddsCard.card_of(preview, odds)
	assert_eq(_hover.odds_card().title_text(), str(card.title), "the title is the place")
	assert_eq(_card_texts(), _texts(card.lines), "the lines are the card's words, in order")
	assert_eq(_hover.odds_card().way_text(), str(card.way_out), "and the way out is the hint")
	assert_eq(str(odds.kind), "attack", "an enemy army is an attack")
	assert_eq(str(card.lines[0][0]), str(odds.kind_text), "the first line is the kind and the word")
	assert_true(str(odds.kind_text).begins_with("Attack · "), "the word follows the kind")


func test_the_odds_word_is_in_its_tone() -> void:
	var set_up := _fight_set_up()
	var hex: Vector2i = set_up.c.theirs
	_hover.on_hover_changed(hex, Vector2(200, 200))
	var odds := OddsView.of(_game, ArmyFixture.TAG, set_up.army, hex)
	var first := _hover.odds_card().get_node("VBox/Rows").get_child(0) as Label
	var want: String = {"good": "NumberGood", "bad": "NumberBad"}.get(str(odds.tone), "Label")
	assert_eq(str(first.theme_type_variation), want, "the kind line takes the odds tone")
	assert_eq(str(first.get_meta(&"words", "")), str(odds.kind_text))


func test_unseen_enemy_hex_shows_no_odds_card() -> void:
	var set_up := _fight_set_up()
	var hex := _unseen_enemy_hex(set_up.c.enemy)
	if hex == ArmyFixture.NO_HEX:
		pending("no unseen enemy hex on this map")
		return
	_hover.on_hover_changed(hex, Vector2(200, 200))
	assert_false(_hover.odds_card().is_open(), "an unseen hex gives no odds card")
	for text: String in _card_texts():
		assert_false(text.contains("morale"), "and no numbers of its army: %s" % text)


func test_shaken_army_gets_its_refusal_in_the_odds_card() -> void:
	var set_up := _fight_set_up()
	var army := Armies.by_id(_game, set_up.army)
	for u: Unit in army.units:
		u.morale = 200
	_game.version += 1
	var hex: Vector2i = set_up.c.theirs
	_hover.on_hover_changed(hex, Vector2(200, 200))
	assert_true(_hover.odds_card().is_open(), "a shaken army's refusal is an odds card")
	var texts: Array[String] = _card_texts()
	var last: String = texts.back()
	assert_true(last.begins_with("Too shaken to attack: morale"), "the refusal's first sentence: %s" % last)
	assert_true(last.contains("needed"), "and its way out: the morale needed")


func test_refusals_that_name_no_war_stay_the_move_card() -> void:
	var odds := {"kind": "attack", "ok": false, "reason": "Not your land."}
	assert_false(OddsCard.wants({"verdict": {"ok": false, "reason": "x"}}, odds), "a refusal that is not a shaken army")
	assert_false(OddsCard.wants({"verdict": {"ok": true}}, {"kind": "none"}), "no war target, no odds card")
	assert_false(OddsCard.wants({"verdict": {"ok": true}}, {}), "an empty odds is none")
	assert_true(OddsCard.wants({"verdict": {"ok": true}}, {"kind": "walk_in"}), "a walk in is a war target")


func test_card_of_siege_lines_and_way_out() -> void:
	var odds := {"kind": "siege", "ok": true, "title": "Pavia (10, 9)", "kind_text": "Besiege · falls in about 4 seasons",
		"tone": "plain", "attack": {"men": 2000, "morale": 1000}, "defence": {"access": "hidden"},
		"chips": [{"text": "Uphill −5 % for you"}], "notes": ["Garrison starves after 3 seasons"],
		"hint": "", "reason": ""}
	var card := OddsCard.card_of({"title": "x", "verdict": {"ok": true}}, odds)
	assert_eq(card.title, "Pavia (10, 9)")
	assert_eq(_texts(card.lines), ["Besiege · falls in about 4 seasons", "You 2,000 men · morale 100 %",
		"Uphill −5 % for you", "Garrison starves after 3 seasons"], "the siege's lines in order")
	odds["ok"] = false
	odds["reason"] = "Not at war with it."
	var refused := OddsCard.card_of({"verdict": {"ok": false}}, odds)
	assert_eq((refused.lines as Array).back(), ["Not at war with it.", "bad"], "a refusal is its reason in BAD")
	assert_eq(refused.way_out, "", "with no way out line")


func test_the_card_takes_no_focus_and_no_mouse() -> void:
	var set_up := _fight_set_up()
	_hover.on_hover_changed(set_up.c.theirs, Vector2(200, 200))
	var card := _hover.odds_card()
	assert_eq(card.focus_mode, Control.FOCUS_NONE, "the card is never focusable")
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and ignores the mouse")
	assert_false(card.has_focus(), "it does not take the focus")


func test_the_card_fits_its_width_with_its_words_wrapped() -> void:
	var set_up := _fight_set_up()
	_hover.on_hover_changed(set_up.c.theirs, Vector2(200, 200))
	await get_tree().process_frame
	await get_tree().process_frame
	var card := _hover.odds_card()
	assert_lte(card.size.x, OddsCard.CARD_W + 0.5, "the card is no wider than its width")
	for label: Node in card.find_children("*", "Label", true, false):
		var l := label as Label
		if l.visible:
			assert_lte(l.custom_minimum_size.x, OddsCard.WRAP_W + 0.5, "%s wraps at the card's width" % l.text)
