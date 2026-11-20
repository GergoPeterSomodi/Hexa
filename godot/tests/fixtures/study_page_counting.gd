## A study page for the tests that records why it was refreshed (tests/shell/test_study_wiring.gd).
extends StudyPage

var reasons: Array[StringName] = []


func refresh(_game: Game, tag: StringName) -> void:
	reasons.append(tag)
