## Every action keeps its check (docs/architecture/m6-build-spec.md 9, done-when 5; L13): 3,000 RandomPlayer actions over
## every name of Actions.NAMES on the army fixture, with 40 season ends among them. When the check says no, the action is
## refused and Game.digest() is unchanged; when it says yes, the action succeeds. A planted pair whose do ignores its check
## is caught by the same contract (P).
## Moves in the month (moves-build-spec.md 8.2, MV4): march, Continue and storm now walk (and may fight) in their do half; the pair
## rule must still hold, so the picks weight Continue and storm up (RandomPlayer.next's `moves`). The contract is unchanged.
extends GutTest

const ACTIONS := 3000
const SEASON_ENDS := 40
const EVERY := 75  # ACTIONS / SEASON_ENDS
const SEED := 1480

var _luck: Rng = null


func before_each() -> void:
	_luck = Rng.new()
	_luck.seed_with(SEED)


func after_each() -> void:
	Actions.clear_test_actions()


## The contract for one action: "" when it holds, else what breaks it. Changes the game (the action runs).
static func contract_problem(g: Game, action: String, args: Dictionary) -> String:
	var before := g.digest()
	var check := g.check(action, args)
	var verdict := g.act(action, args)
	var ok := bool(verdict.get("ok", false))
	if not bool(check.get("ok", false)):
		if ok:
			return "%s: the check said no (%s) and the action ran" % [action, check.get("reason", "")]
		if g.digest() != before:
			return "%s: refused, yet the digest changed" % action
		return ""
	if not ok:
		return "%s: the check said yes and the action was refused (%s)" % [action, verdict.get("reason", "")]
	return ""


func test_three_thousand_random_actions_keep_their_checks() -> void:
	var g := ArmyFixture.game()
	# Armies to start with: two on one town (a split and a merge can be made there), one on another hex of the land.
	var town := ArmyFixture.find_town(g)
	ArmyFixture.town(g, town)
	ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 3)
	ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 2)
	ArmyFixture.army(g, ArmyFixture.TAG, g.map.hex_of(Territory.districts(g, ArmyFixture.id_of(g, ArmyFixture.TAG))[0]), 0, 2)
	var ok_count := {}
	var refused := {}
	var problems: Array[String] = []
	for n: int in ACTIONS:
		var tag := g.player if _luck.randi_range(0, 1) == 0 else g.countries[_luck.randi_range(0, g.countries.size() - 1)].tag
		var pick: Dictionary = RandomPlayer.next(g, tag, _luck, true)  # moves in the month: Continue and storm weighted up
		var action: String = str(pick["action"])
		var args: Dictionary = pick["args"]
		var logged := g.action_log.size()
		var problem := contract_problem(g, action, args)
		if problem != "":
			problems.append(problem)
		if g.action_log.size() > logged:
			ok_count[action] = int(ok_count.get(action, 0)) + 1
		else:
			refused[action] = int(refused.get(action, 0)) + 1
		if (n + 1) % EVERY == 0:
			assert_true(bool(Season.run(g)["ok"]), "the season ends at action %d" % n)
			# The two M7 actions changed the random stream, so the picks no longer meet two companies on one hex by chance:
			# two more companies of the player's country muster on the town each season (a merge is then always on offer).
			ArmyFixture.army(g, ArmyFixture.TAG, town, 0, 2)
	assert_eq(problems.size(), 0, "the contract holds: %s" % str(problems.slice(0, 5)))
	for name: String in Actions.NAMES:
		assert_gt(int(ok_count.get(name, 0)) + int(refused.get(name, 0)), 0, "%s was picked" % name)
	for name: String in ["raise", "split_army", "merge_armies", "disband", "march", "halt", "continue_march", "declare_war",
			"set_standing"]:
		assert_gt(int(ok_count.get(name, 0)), 0, "%s succeeded at least once" % name)
		assert_gt(int(refused.get(name, 0)), 0, "%s was refused at least once" % name)
	# No war on this fixture: a storm is refused every time it is picked (its successes are in test_movement_war.gd).
	assert_gt(int(refused.get("storm", 0)), 0, "storm was refused at least once (no war here)")
	assert_eq(g.turn, 1 + SEASON_ENDS, "%d season ends" % SEASON_ENDS)


func test_p_a_pair_whose_do_ignores_its_check_is_caught() -> void:
	# A stub whose check refuses but whose do acts anyway: the contract must report it.
	Actions.register_test_action("planted_refused", _check_no, _do_anyway)
	var g := ArmyFixture.game()
	var problem := contract_problem(g, "planted_refused", {})
	assert_ne(problem, "", "the planted fault is caught")
	# A stub whose check allows but whose do refuses: caught as well.
	Actions.register_test_action("planted_allowed", _check_yes, _do_refuse)
	assert_ne(contract_problem(g, "planted_allowed", {}), "", "a refusal after a yes is caught")


func test_the_honest_stub_passes_the_contract() -> void:
	Actions.register_test_action("honest", _check_no, _do_refuse)
	var g := ArmyFixture.game()
	assert_eq(contract_problem(g, "honest", {}), "", "a check that says no and a do that refuses hold the contract")


static func _check_no(_game: Game, _args: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "no"}


static func _check_yes(_game: Game, _args: Dictionary) -> Dictionary:
	return {"ok": true, "reason": ""}


static func _do_anyway(game: Game, _args: Dictionary) -> Dictionary:
	game.weather[0] = (game.weather[0] + 1) % 3  # a change the digest sees
	return {"ok": true, "reason": ""}


static func _do_refuse(_game: Game, _args: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "refused"}
