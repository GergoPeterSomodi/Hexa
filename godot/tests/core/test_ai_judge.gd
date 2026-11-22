## Through the same doors (docs/architecture/m8-build-spec.md 9, done-when 2): 12 AI-only seasons with the counting judge in digest
## mode: every act passed its check, succeeded, carried its seat's tag, and no check changed the digest. Planted: a seat that acts
## on a refused check, a result that is not ok, another seat's tag, and a check that writes the game, are each caught.
extends GutTest


## A judge whose re-asked check writes the game: the planted impure check.
class DirtyJudge:
	extends AiJudge

	func _ask(_action: String, _args: Dictionary) -> void:
		game.version += 1
		game.countries[0].treasury += 1


func test_twelve_ai_only_seasons_pass_the_judge_in_digest_mode() -> void:
	var g := AiFixture.watch()
	var judge := AiJudge.new(g, true)
	judge.attach(g.orders as AiTurn)
	for n: int in 12:
		assert_true(bool(Season.run(g)["ok"]))
	assert_eq(judge.problems, [] as Array[String])
	assert_gt(judge.acts, 100, "the countries acted")
	for action: String in ["build", "raise", "set_tax", "march", "declare_war"]:
		assert_true(judge.by_action.has(action), "%s was judged: %s" % [action, str(judge.by_action.keys())])


func test_the_judge_counts_a_clean_act() -> void:
	var g := AiFixture.watch()
	var judge := AiJudge.new(g, true)
	var args := {"tag": &"GEN", "level": 2}
	var verdict := g.check("set_tax", args)
	var result := g.act("set_tax", args)
	judge.on_act(&"GEN", "set_tax", args, verdict, result)
	assert_eq(judge.problems, [] as Array[String])
	assert_eq(judge.acts, 1)


func test_p_a_seat_that_acts_on_a_refused_check_is_caught() -> void:
	var g := AiFixture.watch()
	var judge := AiJudge.new(g, true)
	var args := {"tag": &"GEN", "level": 9}
	var verdict := g.check("set_tax", args)
	assert_false(bool(verdict["ok"]), "the check refuses")
	var result := g.act("set_tax", args)
	judge.on_act(&"GEN", "set_tax", args, verdict, result)
	assert_eq(judge.problems.size(), 2, str(judge.problems))
	assert_true(judge.problems[0].contains("refused") and judge.problems[1].contains("did not succeed"))


func test_p_a_result_that_is_not_ok_after_an_ok_check_is_caught() -> void:
	var judge := AiJudge.new()
	judge.on_act(&"GEN", "set_tax", {"tag": &"GEN"}, {"ok": true}, {"ok": false, "reason": "no"})
	assert_eq(judge.problems.size(), 1)
	assert_true(judge.problems[0].contains("did not succeed"))


func test_p_an_act_with_another_seats_tag_is_caught() -> void:
	var judge := AiJudge.new()
	judge.on_act(&"GEN", "set_tax", {"tag": &"MLO"}, {"ok": true}, {"ok": true})
	judge.on_act(&"GEN", "set_tax", {}, {"ok": true}, {"ok": true})
	assert_eq(judge.problems.size(), 2)
	assert_true(judge.problems[0].contains("another seat's tag"))


func test_p_a_check_that_changes_the_digest_is_caught() -> void:
	var g := AiFixture.watch()
	var judge := DirtyJudge.new(g, true)
	var args := {"tag": &"GEN", "level": 2}
	judge.on_act(&"GEN", "set_tax", args, {"ok": true}, {"ok": true})
	assert_eq(judge.problems.size(), 1, str(judge.problems))
	assert_true(judge.problems[0].contains("changed the digest"))
	var clean := AiJudge.new(g, false)
	clean.on_act(&"GEN", "set_tax", args, {"ok": true}, {"ok": true})
	assert_eq(clean.problems, [] as Array[String], "digest mode off: no re-ask")
