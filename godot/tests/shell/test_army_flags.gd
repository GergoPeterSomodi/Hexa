## The army reminders on the task flag, the army cards of the notifications and the army ribbons (docs/architecture/m6-build-spec.md
## 4.15, 6.10; L22): an idle army lights the flag and an order clears it, a hungry army lights it at severity 2, the Go of the
## player's army card and the flag's army row select the army, and only the player's own army events float a word.
extends GutTest

const TASK_FLAG := "res://shell/hud/task_flag.tscn"
const OTHER := &"SAV"

var _flag: TaskFlag = null
var _selected: Array[int] = []
var _hexes: Array[Vector2i] = []


func before_each() -> void:
	Session.start_game(ArmyFixture.game())
	_flag = (load(TASK_FLAG) as PackedScene).instantiate() as TaskFlag
	add_child_autofree(_flag)
	_selected = []
	_hexes = []
	_flag.army_requested.connect(func(army: int, hex: Vector2i) -> void:
		_selected.append(army)
		_hexes.append(hex))


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


func _kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for line: Dictionary in _flag.lines():
		out.append(line["kind"])
	return out


func _line(kind: StringName) -> Dictionary:
	for line: Dictionary in _flag.lines():
		if line["kind"] == kind:
			return line
	return {}


func _out_of_supply_hex(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and not Supply.in_supply(g, ArmyFixture.TAG, hex, false):
			return hex
	return ArmyFixture.NO_HEX


func _starved_entry(a: Army, lost: int, tag: StringName = ArmyFixture.TAG) -> Dictionary:
	return {"kind": "army_starved", "tag": str(tag), "army": a.id, "hex": a.hex, "lost": lost, "men": a.men(),
		"why": "out_of_supply", "name": a.name, "turn": Session.game.turn, "witnesses": [str(tag)]}


func test_an_army_with_no_order_lights_the_flag_and_an_order_clears_it() -> void:
	var g := Session.game
	var town := ArmyFixture.find_town(g)
	var a := ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 1)
	g.version += 1  # Reminders are cached by version; the fixture's army is made without an event
	_flag.refresh()
	assert_true(_kinds().has(&"army_idle"), "a new army awaits orders")
	assert_true(_flag.visible)
	var verdict := Session.act("march", {"army": a.id, "goal": ImproveRules.neighbour(town, 0)})
	assert_true(bool(verdict["ok"]), str(verdict))
	assert_false(_kinds().has(&"army_idle"), "the order clears the line through army_changed")


func test_a_hungry_army_is_severity_two_on_the_flag() -> void:
	var g := Session.game
	var hex := _out_of_supply_hex(g)
	assert_ne(hex, ArmyFixture.NO_HEX)
	var a := ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 1)
	Armies.set_supply(g, a, Supply.HUNGRY, 100)
	g.version += 1
	_flag.refresh()
	var hungry := _line(&"army_hungry")
	assert_false(hungry.is_empty(), "the hungry army is a line")
	assert_eq(int(hungry["severity"]), 2)
	assert_eq(hungry["action"], [&"select_army", a.id])
	assert_true(_flag.visible)


func test_the_row_of_an_army_line_selects_the_army_and_closes_the_list() -> void:
	var g := Session.game
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	g.version += 1
	_flag.refresh()
	_flag.open_list()
	assert_true(_flag.is_list_open())
	var index := _kinds().find(&"army_idle")
	assert_gt(index, -1)
	assert_true(_flag.choose_row(index))
	assert_eq(_selected, [a.id], "the army is selected")
	assert_false(_flag.is_list_open(), "the list closes")


func test_a_players_starved_army_card_goes_to_its_army_on_go() -> void:
	var notes := Notifications.new()
	add_child_autofree(notes)
	var g := Session.game
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	Events.chronicled.emit(_starved_entry(a, 40))
	assert_eq(notes.card_count(), 1, "the player's hunger is a card")
	var card := notes.cards()[0]
	assert_eq(card["tone"], &"bad")
	assert_eq(int(card["army"]), a.id)
	var asked: Array[int] = []
	var hexes: Array[Vector2i] = []
	notes.army_requested.connect(func(army: int, _hex: Vector2i) -> void: asked.append(army))
	notes.go_requested.connect(func(hex: Vector2i) -> void: hexes.append(hex))
	assert_true(notes.go(int(card["id"])))
	assert_eq(asked, [a.id], "Go selects the army")
	assert_eq(hexes, [] as Array[Vector2i], "not a look at the hex")
	assert_eq(notes.card_count(), 0, "the card goes")


func test_another_countrys_army_card_looks_at_its_hex_on_go() -> void:
	var notes := Notifications.new()
	add_child_autofree(notes)
	var g := Session.game
	var hex := ArmyFixture.find_town(g)
	var entry := {"kind": "army_raised", "tag": str(OTHER), "hex": hex, "army": 99, "units": [], "kind_id": 0,
		"count": 2, "men": 900, "ducats": 0, "goods": {}, "name": "", "turn": g.turn,
		"witnesses": [str(OTHER), str(ArmyFixture.TAG)]}
	Events.chronicled.emit(entry)
	assert_eq(notes.card_count(), 1, "a witnessed raise is a card")
	var card := notes.cards()[0]
	assert_eq(card["tone"], &"warn")
	assert_eq(int(notes.cards()[0]["army"]), -1, "not the player's army: no army id")
	var asked: Array[int] = []
	var hexes: Array[Vector2i] = []
	notes.army_requested.connect(func(army: int, _hex: Vector2i) -> void: asked.append(army))
	notes.go_requested.connect(func(h: Vector2i) -> void: hexes.append(h))
	assert_true(notes.go(int(card["id"])))
	assert_eq(asked, [] as Array[int])
	assert_eq(hexes, [hex], "Go looks at the hex")


func test_a_disbanded_army_card_go_still_carries_its_hex() -> void:
	var notes := Notifications.new()
	add_child_autofree(notes)
	var g := Session.game
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	Events.chronicled.emit(_starved_entry(a, 40))
	var id := int(notes.cards()[0]["id"])
	Armies.remove(g, a)  # disbanded: the army is gone from the game
	var asked: Array[int] = []
	var hexes: Array[Vector2i] = []
	notes.army_requested.connect(func(army: int, hex: Vector2i) -> void:
		asked.append(army)
		hexes.append(hex))
	assert_true(notes.go(id))
	assert_eq(asked, [a.id], "the request still names the army")
	assert_eq(hexes, [a.hex], "and the hex, for the fallback look")


func test_a_disbanded_army_row_still_carries_its_hex() -> void:
	var g := Session.game
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	g.version += 1
	_flag.refresh()
	var index := _kinds().find(&"army_idle")
	assert_gt(index, -1)
	Armies.remove(g, a)  # disbanded silently: the flag's lines are not read again yet
	assert_true(_flag.choose_row(index))
	assert_eq(_selected, [a.id], "the row names the army")
	assert_eq(_hexes, [a.hex], "and its hex")


func test_a_gone_army_falls_back_to_its_hex_then_to_a_toast() -> void:
	var hex := Vector2i(3, 4)
	assert_eq(GameRequests.army_outcome(true, hex, true), &"moved", "selected and glided to")
	assert_eq(GameRequests.army_outcome(false, hex, true), &"look", "gone or foreign: its hex is looked at")
	assert_eq(GameRequests.army_outcome(false, WorksView.NO_HEX, true), &"gone", "no hex: the army is gone")
	assert_eq(GameRequests.army_outcome(false, hex, false), &"gone", "no map: the army is gone")


func test_a_players_hunger_floats_its_word_and_another_countrys_does_not() -> void:
	var g := Session.game
	var fl := Floaters.new()
	add_child_autofree(fl)
	fl.setup(g)
	fl.set_view(Rect2(-100000, -100000, 200000, 200000))
	fl.set_xform(Transform2D.IDENTITY)
	var a := ArmyFixture.army(g, ArmyFixture.TAG, ArmyFixture.find_town(g), 0, 1)
	Events.chronicled.emit(_starved_entry(a, 40))
	assert_eq(fl.live_count(), 1, "the player's hunger floats")
	assert_eq(fl.count_at(a.hex), 1)
	var word := (fl.get_child(0).get_node("HBox/Word") as Label).text
	assert_true(word.begins_with("Hunger "), word)
	assert_true(word.find("40") >= 0, word)
	Events.chronicled.emit(_starved_entry(a, 40, OTHER))
	assert_eq(fl.live_count(), 1, "another country's hunger is muted: no word")
