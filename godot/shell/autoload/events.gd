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
## An army walked: its path (start first), the tick of each step and what the player saw of it. `now` is true for a walk done at
## once (an order's walk, a retreat after a battle fought at once), false for the movement phase's: the replay lays the first
## kind one after another (ReplayPlan.chain) and plays the player's own live (MoveReplay).
signal unit_moved(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray, ticks: PackedInt32Array,
		now: bool)
## An army's march stopped in the movement phase; `why` is `winter`, `blocked` or `no_way`.
signal march_halted(tag: StringName, army: int, why: StringName)
## An army lost men to hunger in the supply phase.
signal army_starved(tag: StringName, army: int, lost: int)
## A company was lost (its last man went): hunger now, battle later.
signal unit_lost(tag: StringName, army: int, unit: int)
## War was declared: `tag` on `target`. Every living country witnesses it (the decision queue, the country panel, the marks).
signal war_declared(tag: StringName, target: StringName)
## A peace ended a war on `terms` (take, white, yield or timer); `tag` asked (the timer names the war's first party).
signal peace_made(tag: StringName, target: StringName, terms: StringName)
## A battle began at `hex` (movement): `attacker` against `defender`.
signal battle_started(hex: Vector2i, attacker: StringName, defender: StringName)
## An army joined the battle at `hex`; `tag` is its country.
signal battle_joined(hex: Vector2i, tag: StringName)
## The battle at `hex` was fought this season (its losses are in the event; a ribbon shows them).
signal battle_fought(hex: Vector2i)
## A battle at `hex` ended; `record` is its battle record id, `winner` the side that won (&"" for a draw).
signal battle_ended(hex: Vector2i, record: int, winner: StringName)
## A siege began at `hex`: `tag` besieges.
signal siege_started(hex: Vector2i, tag: StringName)
## A siege at `hex` progressed: `progress` of `need`.
signal siege_progress(hex: Vector2i, tag: StringName, progress: int, need: int)
## A siege at `hex` was lifted; `why` is left, relief, outnumbered or peace.
signal siege_lifted(hex: Vector2i, tag: StringName, why: StringName)
## The district at `hex` changed hands; `by` is walk, siege, storm, retaken or freed.
signal district_captured(hex: Vector2i, tag: StringName, by: StringName)
## Control of `hexes` changed (the occupier overlay, the area lines, the hex panels).
signal controllers_changed(hexes: Array[Vector2i])
## Every notable event, as the chronicle stores it (plain values): the log, notifications and ribbons.
signal chronicled(entry: Dictionary)
## A season ended; `turn` is the season that ended. Emitted once, after the last phase's drain.
signal season_ended(turn: int)

## An army of the player's was selected on the map (MapArmies.select_army, by a click, Tab or a march's order cursor): the
## army panel shows it. `army_id` is the army's id; the signal says nothing about the game, which is unchanged.
signal army_selected(army_id: int)
## The army selection was cleared on the map (MapArmies.clear_army): the army panel closes. Emitted only when an army was
## selected.
signal army_cleared
## The parchment map became solid (true: it covers the tiles) or stopped being solid (false), once a change, never every
## frame (docs/architecture/map-overview-build-spec.md D13): MapHover picks its card by it. The game is unchanged.
signal map_parchment(solid: bool)
## A battle's mark on the map was clicked (WarMarks, M7 6.3): the battle dock opens on that record. `record` is the
## BattleRecord id; the map says nothing else.
signal battle_mark_clicked(record: int)
