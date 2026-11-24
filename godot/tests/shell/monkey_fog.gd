## The fog part of the UI monkey (test_ui_monkey.gd extends this, which extends MonkeyM8): the player sees only what the fog build
## lets it see (docs/architecture/fog-build-spec.md 3.4, 4, 7; plan section 4, FG18). A fog seed plays with every M8 action and
## the fog step: the pointer hovers, or a click lands, on a random undiscovered hex on screen (the hover card and the hex panel
## open on it). A thin seed (FogFixture.thin at FOG_THIN_RADIUS on the player's country, applied once the country is picked, at the
## end of a step) makes the deep fog where most of the map is undiscovered.
## Invariants, every frame of a fog seed: on a sample of undiscovered hexes HexCard.of gives only "Unexplored" (no owner), PeopleView.at
## is not shown, and no army token of another country stands there; the hover card and the hex panel, when they show an undiscovered
## hex, carry no visible text that names its owner; each foreign army out of sight is in no view (ArmyView.visible false, no token,
## no Knowledge.armies_seen entry). Not covered here: the log and the reports (their rule, Knowledge.witnessed, is tested in
## tests/core/test_fog_views.gd).
class_name MonkeyFog
extends MonkeyM8

## The fog counters a fog seed must raise above 0: the sampled dark hexes, the text checks of a dark card or panel, the hidden armies.
const FOG_REQUIRED: Array[String] = ["fog_hexes", "fog_dark", "fog_armies_hidden"]
## Undiscovered hexes sampled per frame by the model check.
const FOG_SAMPLE := 16
## The thin seed's radius around the country's land sight (FogFixture.thin).
const FOG_THIN_RADIUS := 2
## The share of the steps that are fog steps (the rest are the M8 and earlier steps).
const FOG_STEP_PERCENT := 15
## Random picks tried for a dark hex on screen before a fog step gives up.
const FOG_PICK_TRIES := 40

## The fog actions are on (a fog seed), and the seed's thin flag.
var _fog: bool = false
var _fog_thin: bool = false
## The game the pick was checked on (the thin fixture is applied once per game), and the sample cursor over the hexes.
var _fog_game: Game = null
var _fog_cursor: int = 0


## Starts the fog counters on a fog seed (after the M8 ones).
func _fog_begin(on: bool, thin: bool) -> void:
	_fog = on
	_fog_thin = thin
	_fog_game = null
	_fog_cursor = 0
	if on:
		for key: String in FOG_REQUIRED:
			_n[key] = 0
		_n["fog_thins"] = 0


## Stops the fog actions and checks that each fog counter was raised (a thin seed thinned its country once).
func _fog_end(on: bool, seed_value: int) -> void:
	_fog = false
	if not on:
		return
	gut.p("monkey fog seed %d counters: %s" % [seed_value, JSON.stringify(_n)])
	# The normal seed starts with every hex discovered in the small map, so only the thin seed must raise the hex counters (FG18).
	var required: Array[String] = []
	if _fog_thin:
		required.append_array(FOG_REQUIRED)
	else:
		required.append("fog_armies_hidden")
	for key: String in required:
		assert_gt(int(_n[key]), 0, "seed %d: the fog monkey did %s" % [seed_value, key])
	if _fog_thin:
		assert_gt(int(_n["fog_thins"]), 0, "seed %d: the thin seed thinned the player's country (once per game: a load is a new game)" % seed_value)


## After a step with a fog seed: the thin fixture on the first look at a picked game (a thin seed), then the fog invariants.
## The thinning is the last act of its step, so the next step's digest starts from the thinned game.
func _fog_after_step(app: App, seed_value: int, step: int) -> void:
	if not _fog:
		return
	var game := Session.game
	if game == null or not game.has_countries() or game.player == &"" or app.is_starting() or app.map_scene() == null:
		return
	if game != _fog_game:
		_fog_game = game
		if _fog_thin:
			FogFixture.thin(game, game.player, FOG_THIN_RADIUS)
			_bump("fog_thins")
		return
	_fog_assert(app, game, "seed %d step %d" % [seed_value, step])


## The M8 step of a seed: on a fog seed a quarter of these are fog steps (a Confirm on the stack is always the M8 step's to answer).
func _m8_step(rng: Rng, vp: SubViewport, app: App) -> void:
	if _fog and not (app.stack().top() is Confirm) and rng.randi_range(0, 3) == 0:
		await _fog_step(rng, vp, app)
		await _wait_frames(2)
	else:
		await super._m8_step(rng, vp, app)


## One fog step: a random dark hex on screen is hovered (a pointer move) or clicked (the hex panel opens on it).
func _fog_step(rng: Rng, vp: SubViewport, app: App) -> void:
	var game := Session.game
	if game == null or not game.has_countries() or app.map_scene() == null or app.is_starting():
		return
	var hex := _fog_pick_dark(rng, vp, app, game)
	if hex == MapInput.NO_HEX:
		return
	var pos := _m6_screen_pos(app, hex)
	if rng.randi_range(0, 2) == 0:
		var motion := InputEventMouseMotion.new()
		motion.position = pos
		motion.global_position = pos
		vp.push_input(motion)
	else:
		_send_click(vp, pos, MOUSE_BUTTON_LEFT)


## A random undiscovered hex whose centre is on the viewport; MapInput.NO_HEX after FOG_PICK_TRIES tries.
func _fog_pick_dark(rng: Rng, vp: SubViewport, app: App, game: Game) -> Vector2i:
	var n := game.map.hex_count()
	if n == 0:
		return MapInput.NO_HEX
	var screen := Rect2(Vector2.ZERO, Vector2(vp.size))
	for _t: int in FOG_PICK_TRIES:
		var hex := game.map.hex_of(rng.randi_range(0, n - 1))
		if Knowledge.discovered(game, game.player, hex):
			continue
		if screen.has_point(_m6_screen_pos(app, hex)):
			return hex
	return MapInput.NO_HEX


## The fog invariants of one frame: a sample of undiscovered hexes, the open hover card and hex panel, the armies out of sight.
func _fog_assert(app: App, game: Game, tag: String) -> void:
	var viewer := game.player
	var n := game.map.hex_count()
	if n == 0:
		return
	var tokens := _fog_tokens(app)
	var sampled := 0
	var idx := _fog_cursor % n
	var scanned := 0
	while sampled < FOG_SAMPLE and scanned < n:
		var hex := game.map.hex_of(idx)
		if not Knowledge.discovered(game, viewer, hex):
			sampled += 1
			_fog_check_hex(game, viewer, hex, tokens, tag)
		idx = (idx + 1) % n
		scanned += 1
	_fog_cursor = idx
	_fog_check_panels(app, game, viewer, tag)
	_fog_check_armies(game, viewer, tokens, tag)


## The map's army tokens (null when the map has no army layer yet).
func _fog_tokens(app: App) -> ArmyTokens:
	var map := app.map_scene()
	if map == null:
		return null
	var layer := map.get_node_or_null("MapArmies") as MapArmies
	return layer.tokens() if layer != null else null


## One undiscovered hex: its card is "Unexplored" and nothing else, no people are shown, no other country's token stands on it.
func _fog_check_hex(game: Game, viewer: StringName, hex: Vector2i, tokens: ArmyTokens, tag: String) -> void:
	_bump("fog_hexes")
	var card := HexCard.of(game, hex)
	assert_eq(str(card.get("title", "")), "Unexplored", "%s: an undiscovered hex's card says only Unexplored" % tag)
	assert_eq(str(card.get("owner", "")), "", "%s: an undiscovered hex's card names no owner" % tag)
	assert_false(bool(PeopleView.at(game, viewer, hex).get("shown", false)), "%s: an undiscovered hex shows no people" % tag)
	if tokens == null:
		return
	for c: Country in game.countries:
		if c.tag != viewer:
			assert_null(tokens.token_at(hex, c.tag), "%s: no army token of %s on an undiscovered hex" % [tag, c.tag])


## The hover card and the hex panel, when either shows an undiscovered hex: their visible text names no owner of it.
func _fog_check_panels(app: App, game: Game, viewer: StringName, tag: String) -> void:
	var hud := app.hud()
	var hover := hud.map_hover()
	if hover.is_card_visible() and hover.card() != null:
		var hovered := hover.hovered_hex()
		if hovered != MapInput.NO_HEX and not Knowledge.discovered(game, viewer, hovered):
			_fog_check_texts(hover.card(), game, hovered, "the hover card", tag)
	var panel := hud.hex_panel()
	if panel.is_visible_in_tree() and panel.shown_hex() != MapInput.NO_HEX:
		var shown := panel.shown_hex()
		if not Knowledge.discovered(game, viewer, shown):
			_fog_check_texts(panel, game, shown, "the hex panel", tag)


## The visible text under `node` names no owner of the undiscovered hex `hex` (its tag and its long name).
func _fog_check_texts(node: Node, game: Game, hex: Vector2i, what: String, tag: String) -> void:
	_bump("fog_dark")
	var names := PackedStringArray()
	var owner_tag := Territory.owner_tag(game, hex)
	if owner_tag != &"" and owner_tag != game.player:
		names.append(String(owner_tag))
		var cdef := Countries.def_of(game, owner_tag)
		if cdef != null and str(cdef.long_name) != "":
			names.append(str(cdef.long_name))
	var texts := PackedStringArray()
	_fog_texts(node, texts)
	for text: String in texts:
		for owner_name: String in names:
			assert_false(text.contains(owner_name), "%s: %s shows the owner of an undiscovered hex: '%s'" % [tag, what, text])


## The text of every visible Label, RichTextLabel and Button under `node`, in tree order.
static func _fog_texts(node: Node, out: PackedStringArray) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label or node is RichTextLabel or node is Button:
		var text := str(node.get("text"))
		if text != "":
			out.append(text)
	for child: Node in node.get_children():
		_fog_texts(child, out)


## Every foreign army out of sight is in no view; every foreign army the listing gives is in sight.
func _fog_check_armies(game: Game, viewer: StringName, tokens: ArmyTokens, tag: String) -> void:
	for army: Army in game.armies:
		if army.tag == viewer or Knowledge.sees(game, viewer, army.hex):
			continue
		_bump("fog_armies_hidden")
		assert_false(ArmyView.visible(game, viewer, army), "%s: an army out of sight is in no view" % tag)
		if tokens != null:
			assert_null(tokens.token_at(army.hex, army.tag), "%s: an army out of sight has no token" % tag)
	for seen: Dictionary in Knowledge.armies_seen(game, viewer):
		var army := seen["army"] as Army
		if army.tag != viewer:
			assert_true(Knowledge.sees(game, viewer, army.hex), "%s: an army the listing gives is in sight" % tag)
