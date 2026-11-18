## GUT tests for Session lifecycle (unsaved_actions, start_game/new_game reset, end_game -> Events.game_ended)
## (docs/architecture/ui-and-controls-spec.md section 3.6; ui-and-controls-plan.md U8).
extends GutTest

var _prev_game: Game = null
var _prev_unsaved: int = 0


func before_each() -> void:
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions


func after_each() -> void:
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved


func _first_buildable() -> Dictionary:
	var g := Session.game
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or not Improve.piece_at(g, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(g, hex):
			if bool(option["ok"]):
				return {"hex": hex, "family": int(option["family_id"])}
	return {}


func test_unsaved_actions_counts_successful_acts_and_resets_on_new_or_start_game() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	assert_not_null(Session.game)
	assert_eq(Session.unsaved_actions, 0, "new_game resets unsaved_actions to 0")

	# Refused act must not increment unsaved_actions
	var refused := Session.act("upgrade", {"hex": Vector2i(-1, -1)})
	assert_false(bool(refused.get("ok", false)))
	assert_eq(Session.unsaved_actions, 0, "refused act leaves unsaved_actions unchanged")

	var target := _first_buildable()
	assert_false(target.is_empty(), "north_italy has a buildable hex")
	var hex := target["hex"] as Vector2i
	var built := Session.act("build", {"hex": hex, "family": int(target["family"])})
	assert_true(bool(built.get("ok", false)))
	assert_eq(Session.unsaved_actions, 1, "successful build increments unsaved_actions")

	var cleared := Session.act("clear", {"hex": hex})
	assert_true(bool(cleared.get("ok", false)))
	assert_eq(Session.unsaved_actions, 2, "successful clear increments unsaved_actions")

	# new_game resets unsaved_actions
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED + 1)
	assert_eq(Session.unsaved_actions, 0, "second new_game resets unsaved_actions")

	# start_game with existing Game also resets unsaved_actions
	assert_true(bool(Session.act("build", {"hex": _first_buildable()["hex"], "family": int(_first_buildable()["family"])}).get("ok", false)))
	assert_eq(Session.unsaved_actions, 1)
	var fake := FakeMap.build(10, 10, 1)
	Session.start_game(Game.with_state(fake, MapState.create(fake)))
	assert_eq(Session.unsaved_actions, 0, "start_game resets unsaved_actions")


func test_end_game_clears_game_resets_unsaved_and_emits_game_ended() -> void:
	var ended_count := [0]
	var on_ended := func() -> void: ended_count[0] += 1
	Events.game_ended.connect(on_ended)

	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	var target := _first_buildable()
	assert_true(bool(Session.act("build", {"hex": target["hex"], "family": int(target["family"])}).get("ok", false)))
	assert_eq(Session.unsaved_actions, 1)

	Session.end_game()
	Events.game_ended.disconnect(on_ended)

	assert_null(Session.game, "end_game clears Session.game")
	assert_eq(Session.unsaved_actions, 0, "end_game resets unsaved_actions")
	assert_eq(ended_count[0], 1, "end_game emits Events.game_ended once")

	var check_res := Session.check("build", {"hex": Vector2i.ZERO, "family": 1})
	assert_false(bool(check_res.get("ok", false)))
	assert_eq(str(check_res.get("reason", "")), "no game")
