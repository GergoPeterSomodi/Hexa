## A study page that breaks the rule on purpose (docs/architecture/m4-5-build-spec.md 9): its refresh changes the game, the way
## no page may. tests/shell/test_study_readonly.gd opens it and requires the proof to FAIL for it (the planted fault).
## Never part of the study's pages (StudyPages.LIST); only the test builds it.
extends StudyPage

var _busy: bool = false


## Sets the player's tax to another level through Session.act: an accepted action in the middle of a read.
func refresh(game: Game, _tag: StringName) -> void:
	if _busy or game == null:
		return
	var country := Countries.by_tag(game, game.player)
	if country == null:
		return
	_busy = true  # the act's tax_set may refresh a listening Study again: once is enough
	Session.act("set_tax", {"level": (country.tax + 1) % 3})
	_busy = false
