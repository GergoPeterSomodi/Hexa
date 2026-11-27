## The invariants of the moves monkey (MonkeyMoves extends this, which extends MonkeyTile; moves-build-spec.md 8.4; MV15):
## every frame, a live walk changes neither the digest nor the version, and else the selected army's token mark says its
## panel's points; after every order and every step, I1, I4, I5 and I9 of tests/core/invariants.gd hold, points grow in no
## season's middle (I3) and an army that walked stands at its walk's end; around every staging act, I10.
class_name MonkeyMovesChecks
extends MonkeyTile

## The app the frame watch reads (a moves seed's).
var _moves_app: App = null
## Army id -> the last hex of its last walk at once heard since the last check.
var _moves_ends: Dictionary = {}
## What every army had at the last look: {game, turn, points {id: points}} (I3).
var _moves_look: Dictionary = {}
## The last frame of a live walk: {game, digest, version, unsaved, records} ({} when none played).
var _moves_frame_seen: Dictionary = {}


func _moves_on_unit_moved(tag: StringName, army: int, path: Array[Vector2i], _seen: PackedByteArray,
		_ticks: PackedInt32Array, now: bool) -> void:
	if now and not Session.in_season() and tag == Session.player_tag() and not path.is_empty():
		_moves_ends[army] = path.back()
	else:
		_moves_ends.erase(army)  # a season's walk (or a peace's move) came after the walk at once


## Every army that walked at once since the last check stands at its walk's end (its battle's retreat is its last walk).
func _moves_check_ends(game: Game) -> void:
	for id: int in _moves_ends:
		var army := Armies.by_id(game, id)
		if army != null:
			assert_eq(army.hex, _moves_ends[id], "%s: army %d stands where its walk said" % [_tag, id])
	_moves_ends = {}


## Every frame: a live walk leaves the digest and the version while no act is accepted; else the selected army's mark.
func _moves_on_frame() -> void:
	var app := _moves_app
	var game := Session.game
	if app == null or not is_instance_valid(app) or game == null or app.is_starting() or app.map_scene() == null \
			or Session.in_season() or not app.requests().replay.live_active():
		_moves_frame_seen = {}
		if app != null and is_instance_valid(app) and game != null and not app.is_starting() and app.map_scene() != null \
				and not Session.in_season():
			_moves_check_mark(app, game)
		return
	var now := {"game": game, "digest": game.digest(), "version": game.version, "unsaved": Session.unsaved_actions,
		"records": game.action_log.size(), "step": _step_no}
	var seen := _moves_frame_seen
	if not seen.is_empty() and seen["game"] == game and seen["unsaved"] == now["unsaved"] and seen["records"] == now["records"] \
			and seen["step"] == now["step"] and not _dev_changed:
		_bump("moves_frames")
		assert_eq(now["version"], seen["version"], "%s: a live walk never changes the version" % _tag)
		assert_eq(now["digest"], seen["digest"], "%s: a live walk never changes the digest" % _tag)
	_moves_frame_seen = now


## What every army has now, for I3.
func _moves_look_now() -> void:
	var game := Session.game
	if game == null or Session.in_season():
		_moves_look = {}
		return
	var points: Dictionary = {}
	for a: Army in game.armies:
		points[a.id] = a.points
	_moves_look = {"game": game, "turn": game.turn, "points": points}


## I1, I4, I5 and I9 (I4 and I5 hold at idle: a season in progress is the soak's to judge).
func _moves_check_game(game: Game, what: String) -> void:
	var lines := Invariants.point_lines(game)
	lines.append_array(Invariants.act_lines(game))
	lines.append_array(Invariants.stop_lines(game))
	assert_eq(Invariants.report(lines) if not lines.is_empty() else "", "", "%s: the invariants %s" % [_tag, what])
	_bump("moves_checks")


func _moves_check_staged(game: Game, digest: String, version: int, what: String) -> void:
	var lines := Invariants.staged_lines(game, digest, version)
	lines.append_array(Invariants.stop_lines(game))
	assert_eq(Invariants.report(lines) if not lines.is_empty() else "", "", "%s: the invariants after %s" % [_tag, what])


## After every step: the game's invariants at idle, the walks' ends and I3 since the last look.
func _moves_invariants(app: App, tag: String) -> void:
	_tag = tag
	var game := Session.game
	if game == null or not game.has_countries() or game.player == &"" or app.is_starting() or app.map_scene() == null:
		_moves_look = {}
		return
	if Session.in_season():
		_moves_look = {}
		_moves_ends = {}
		return
	_moves_check_game(game, "after a step")
	if not _moves_look.is_empty() and _moves_look["game"] == game and _moves_look["turn"] == game.turn:
		var had := _moves_look["points"] as Dictionary
		for a: Army in game.armies:
			if had.has(a.id):
				assert_lte(a.points, int(had[a.id]), "%s: army %d gains no points in the middle of a season" % [_tag, a.id])
		_moves_check_ends(game)
	_moves_ends = {}
	_moves_look_now()


## The selected army's token mark says what its panel says (a stack's token shows the fewest points of its armies).
func _moves_check_mark(app: App, game: Game) -> void:
	var layer := _m6_map_armies(app)
	var panel := app.hud().army_panel()
	if layer == null or layer.selected_army() < 0 or app.stack().count() != 0 or app.requests().replay.live_active() \
			or app.requests().replay.active() or panel.shown_army() != layer.selected_army():
		return
	var army := Armies.by_id(game, layer.selected_army())
	if army == null:
		return
	var token := layer.tokens().token_at(army.hex, army.tag)
	if token == null:
		return
	var full := Allowance.full(game, army)
	var said := "%d of %d left this season" % [army.points, full]
	if not AppFlowHelpers.labels_under(panel).has(said):  # asserted only when wrong: this runs every frame
		fail_test("%s: the panel does not say '%s'" % [_tag, said])
	var left := army.points
	var least := full
	for other: Army in Armies.at(game, army.hex):
		if other.tag == army.tag:
			left = mini(left, other.points)
			least = mini(least, Allowance.full(game, other))
	if token.points_shown():
		_bump("moves_marks")
		var tip := "%d of %d move points left this season" % [left, least]
		if token.points_tip() != tip:
			fail_test("%s: the token's mark says '%s', the panel's points '%s'" % [_tag, token.points_tip(), tip])
