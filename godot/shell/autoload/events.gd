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
## A settlement grew a level in the people phase (People.season): the hex panel refreshes, the Food overlay repaints.
signal town_grew(tag: StringName, hex: Vector2i, level: int)
## A settlement fell a level in the people phase; `why` is `hunger` or `people`.
signal district_declined(tag: StringName, hex: Vector2i, level: int, why: StringName)
## A company or army was raised in a hex (Military.raise): the army tokens, the panels, the chips, the ribbons.
signal army_raised(tag: StringName, hex: Vector2i, army: int)
## An army was disbanded in a hex (Military.disband); the army may be gone now (listeners check Armies.by_id).
signal army_disbanded(tag: StringName, hex: Vector2i, army: int)
## An army's order, place, companies or men changed (split, merge, march, halt, refill): tokens, panels, path marks.
signal army_changed(tag: StringName, army: int)
## An army walked in the movement phase: its path (start first), the tick of each step and what the player saw of it.
signal unit_moved(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray, ticks: PackedInt32Array)
## An army's march stopped in the movement phase; `why` is `winter`, `blocked` or `no_way`.
signal march_halted(tag: StringName, army: int, why: StringName)
## An army lost men to hunger in the supply phase.
signal army_starved(tag: StringName, army: int, lost: int)
## A company was lost (its last man went): hunger now, battle later.
signal unit_lost(tag: StringName, army: int, unit: int)
## Every notable event, as the chronicle stores it (plain values): the log, notifications and ribbons.
signal chronicled(entry: Dictionary)
## A season ended; `turn` is the season that ended. Emitted once, after the last phase's drain.
signal season_ended(turn: int)
