## The hex panel under fog (fog-build-spec 3.4, R1, D18): opened on an undiscovered hex it says "Unexplored" and shows no fact of the hex
## (no owner, place, ground, people, works or actions), as HexCard does; a light-fog hex (discovered, not in sight) shows its owner.
## Reproduced on the thin duel (FogFixture.duel_thin, set before the panel opens: no discovery changes under an open panel).
extends GutTest

const PANEL := "res://shell/panels/hex_panel.tscn"

var _panel: HexPanel = null
var _game: Game = null


func before_each() -> void:
	Bindings.ensure()
	_game = FogFixture.duel_thin()
	_game.player = AiFixture.MILAN
	Session.start_game(_game)
	_panel = (load(PANEL) as PackedScene).instantiate() as HexPanel
	_panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(_panel)


func after_each() -> void:
	Session.end_game()


## The first land hex the player has not discovered whose owner is another country; Army.NO_HEX when none.
func _undiscovered_owned() -> Vector2i:
	for i: int in _game.map.hex_count():
		var hex := _game.map.hex_of(i)
		var owner := Territory.owner_tag(_game, hex)
		if _game.map.is_land(hex) and not Knowledge.discovered(_game, _game.player, hex) and owner != &"" and owner != _game.player:
			return hex
	return Army.NO_HEX


## The first land hex in light fog (discovered, not in sight) owned by another country.
func _light_owned() -> Vector2i:
	for i: int in _game.map.hex_count():
		var hex := _game.map.hex_of(i)
		var owner := Territory.owner_tag(_game, hex)
		if _game.map.is_land(hex) and Knowledge.discovered(_game, _game.player, hex) and not Knowledge.sees(_game, _game.player, hex) \
				and owner != &"" and owner != _game.player:
			return hex
	return Army.NO_HEX


## The text of every visible Label, RichTextLabel and Button under `node`.
func _visible_texts(node: Node, out: PackedStringArray) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label or node is RichTextLabel or node is Button:
		out.append(str(node.get("text")))
	for child: Node in node.get_children():
		_visible_texts(child, out)


func _owner_name(hex: Vector2i) -> String:
	var tag := Territory.owner_tag(_game, hex)
	var cdef := Countries.def_of(_game, tag)
	return cdef.long_name if cdef != null and cdef.long_name != "" else String(tag)


func test_an_undiscovered_hex_panel_says_unexplored_and_shows_no_owner() -> void:
	var hex := _undiscovered_owned()
	assert_ne(hex, Army.NO_HEX, "the thin duel has an undiscovered hex with an owner")
	_panel.show_hex(hex)
	assert_eq(_panel.cartouche().text, "Unexplored", "the panel's header says Unexplored (D18)")
	assert_false((_panel.get_node("Scroll/Body/OwnerRow") as CanvasItem).is_visible_in_tree(), "no owner row on an undiscovered hex")
	var texts := PackedStringArray()
	_visible_texts(_panel, texts)
	for text: String in texts:
		assert_false(text.contains(_owner_name(hex)), "no visible text names the owner of an undiscovered hex: '%s'" % text)


func test_a_light_fog_hex_panel_still_shows_its_owner() -> void:
	var hex := _light_owned()
	assert_ne(hex, Army.NO_HEX, "the thin duel has a light-fog hex with an owner")
	_panel.show_hex(hex)
	assert_ne(_panel.cartouche().text, "Unexplored", "a discovered hex is not Unexplored")
	assert_true((_panel.get_node("Scroll/Body/OwnerRow") as CanvasItem).is_visible_in_tree(), "the owner row shows on a light-fog hex (R18)")
