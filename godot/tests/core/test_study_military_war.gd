## The Military page's war rows (docs/architecture/m7-build-spec.md 6.9; M7 plan B19): the viewer's wars (live first, then ended,
## newest first) with their state words ("at war", "white peace", "truce until ..."), the score, the battles, the men booked and the
## districts held each way; the battles of the viewer (none before a battle); the battle_losses series of the page equals the
## stats. Only the viewer's own wars: another country's war is not in its rows.
extends GutTest

const SAV := &"SAV"
const MLO := &"MLO"

var _g: Game = null


func before_each() -> void:
	_g = EconomyFixture.game(SAV, false, true, EconomyFixture.SEED, false)
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func test_a_live_war_is_at_war_and_a_stranger_war_is_absent() -> void:
	var live := WarFixture.at_war(_g, SAV, MLO)
	var rows := StudyMilitaryWar.wars(_g, SAV)
	assert_eq(rows.size(), 1, "one war of the viewer")
	var row := rows[0]
	assert_eq(row["tag"], MLO, "the enemy")
	assert_eq(str(row["state_text"]), "at war", "a live war")
	assert_eq(int(row["war"]), live.id, "the war's id")
	assert_eq(int(row["held_theirs"]), 0, "no district held")
	var other := WarFixture.at_war(_g, MLO, &"VEN")
	assert_eq(StudyMilitaryWar.wars(_g, SAV).size(), 1, "a war between two others is not the viewer's")
	assert_eq(StudyMilitaryWar.wars(_g, MLO).size(), 2, "it is the other's")
	assert_true(other.live(), "the other war is live")


func test_an_ended_white_war_reads_white_peace_and_its_truce() -> void:
	var w := WarFixture.ended(_g, SAV, MLO, 1, &"white")
	_g.turn = 20
	var row := StudyMilitaryWar.wars(_g, SAV)[0]
	assert_eq(str(row["state_text"]), "white peace", "a white peace after the truce")
	assert_eq(str(row["tone"]), "plain", "an ended war is plain")
	assert_eq(int(row["war"]), w.id, "the id")


func test_a_truce_reads_until_its_season_when_it_runs() -> void:
	WarFixture.ended(_g, SAV, MLO, 1, &"white")
	_g.turn = 2
	var row := StudyMilitaryWar.wars(_g, SAV)[0]
	assert_true(str(row["state_text"]).begins_with("truce until "), "the truce runs: %s" % str(row["state_text"]))


func test_live_wars_come_before_ended_ones() -> void:
	WarFixture.ended(_g, SAV, MLO, 1, &"white")
	WarFixture.at_war(_g, SAV, &"VEN")
	_g.turn = 20
	var rows := StudyMilitaryWar.wars(_g, SAV)
	assert_eq(str(rows[0]["state_text"]), "at war", "the live war is first")
	assert_eq(rows.size(), 2, "both wars listed")


func test_no_battle_before_a_battle() -> void:
	assert_true(StudyMilitaryWar.battles(_g, SAV).is_empty(), "no kept record, no row")


func test_the_battle_losses_series_is_the_stats_series() -> void:
	var view := StudyMilitary.of(_g, SAV, 4)
	assert_true(view.has("battles") and view.has("wars"), "the page carries the two lists")
	assert_true((view["series"] as Dictionary).has("battle_losses"), "the series is on the page")
	assert_eq(StudyMilitary.SERIES.has("battle_losses"), true, "the series is named")
