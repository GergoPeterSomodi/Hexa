## The event bus (autoload "Events"; docs/architecture/m1-build-spec.md section 8): one signal per kind of event. The
## rules never see it: they append events to Game.events, and Session turns each one into a signal here after an
## action. Handlers read the game and draw; they never change it.
extends Node

## A hex's state changed (build, upgrade, clear): the map view redraws it and its neighbours, the panel refreshes.
signal hex_changed(hex: Vector2i)
## A new game began (or a game was put in place): everything that shows the game starts again from Session.game.
signal game_started
## The current game ended and Session.game is now null.
signal game_ended
## Land changed owner (Territory.transfer): the map redraws those hexes' overlay, borders and labels, the dock refreshes.
signal owners_changed(hexes: Array[Vector2i])
## The human player chose a country (choose_country): the pick ends, the top bar and the map show it.
signal country_chosen(tag: StringName)
## A work was ordered (build, upgrade, clear): work marks, the hex panel, the toast and the task flag.
signal work_started(tag: StringName, hex: Vector2i, work: Dictionary)
## A work finished in the works phase: its piece stands now.
signal work_finished(tag: StringName, hex: Vector2i, work: Dictionary)
## A work ended without finishing; `why` is `order`, `lost` or `blocked`.
signal work_cancelled(tag: StringName, hex: Vector2i, work: Dictionary, why: StringName)
## A country's towns ran short of a need (food, wine, salt or oil) that was met last season: chips, task flag.
signal goods_short(tag: StringName, good: StringName)
## A country set its tax level (0 low, 1 normal, 2 high): chips, study page, country panel, toast.
signal tax_set(tag: StringName, level: int)
## Every notable event, as the chronicle stores it (plain values): the log, notifications and ribbons.
signal chronicled(entry: Dictionary)
## A season ended; `turn` is the season that ended. Emitted once, after the last phase's drain.
signal season_ended(turn: int)
