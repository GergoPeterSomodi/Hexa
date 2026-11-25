# Moves build spec: moves in the month (issue 432)

Technical director, 2026-11-25. **Status: a proposal; no task starts before the owner's go.** Builds the design
`docs/design/moves-in-the-month.md` ("the design") **as the owner answered it** in its last section (2026-11-24). Where the
design's sections 2 to 6 say something else, the owner's answers win, and this page wins over both for the build. The tasks
are in `moves-build-plan.md`. Appendix A lists every place in earlier specs that this page amends (those specs are not
edited); Appendix B lists where the design and today's code disagree.

Words: the game calls a turn a "season", the owner says "month"; this page says "season". "Move points" are the allowance
the design calls "points".

**What it is, in one paragraph.** An order to march no longer waits for End season: the army **walks in the same click**,
as far as its move points of this season reach, and the walk is final. An army may be ordered again and again until its
points are spent. A route longer than one season's points walks its first leg now and keeps the rest as a **standing
march**, which the movement phase walks one leg a season from the next season on, so a long march keeps today's pace. A
walk stops when an enemy army it did not see comes into sight (the points are kept), stops for good beside an enemy (zone of
control), and steps slowly through land the country has never mapped. A step onto an enemy army opens the battle **in the
same click**; until the battle board (issue 437) exists the battle is fought at once and its result is shown in the
battle dock. The player moves first; at End season every computer seat moves the same way, through the same action. Risky
moves (a battle, entering enemy land, ending out of supply) ask once. The picture of a walk plays live on the map and never
changes the result.

**The moves build is done when:**

1. Every rule R1 to R57 below holds, each with its GUT case and its planted fault (P) of section 8.
2. On north Italy, Savoy at war with Milan: a march walks before `Session.act` returns, a second march walks with the points
   left, a march past the season's points leaves a standing march that walks at End season of the next season, and a march
   onto a Milanese army fights the battle in the same act (`test_app_flow_moves.gd`).
3. `MovePreview.to(...).leg` equals the walk that follows for every accepted order on which no army the viewer cannot see
   stands (the property test over 200 seeded orders, `test_walk_preview.gd`).
4. A game of 20 seasons with player marches, at-once battles and the AI replays from its action log to the same digest;
   a save at idle in the middle of a season loads to the same digest and plays on alike (`test_moves_replay.gd`).
5. The soak's 100 `ai`, 20 `passive` and 4 `europe` games hold the M8 ranges as the systems designer re-reads them, with the
   new invariants (section 8.4) green.
6. `SaveFile.FORMAT` is 8; a format-7 save reads "older"; save, load, save is byte-equal after at-once moves.
7. The perf rows of section 9 within their limits, issue 427 (the battle end's cost) closed.
8. Lint, import, check_scripts, GUT, both UI `--check`s, `build_map --check`, `build_scenario.gd --check`,
   `build_tile_tabs.gd --check` green; the pictures of 8.5 signed by the art director; the owner has played the plan's
   checklist.
9. Multi-leg marches (owner request 2026-11-25, section 3.11, R58 to R72): Shift+left click stages stops, the preview and the
   commit run through them, one `march` with `via` walks the whole route season by season, the stops survive a save, and the
   AI never uses them (`test_march_via.gd`, `test_via_preview.gd`, `test_waypoints.gd`, I9 and I10).

---

## 1. What is there (read in the code, master after the fog build and the tile window)

| Finding | Where | Meaning for the build |
|---|---|---|
| `march`, `halt`, `continue_march`, `storm` are actions of `Movement`; `march` only stores the order and the route (`Armies.set_order`) and emits `army_changed` | `godot/core/systems/movement.gd` (765 lines), `godot/core/game/actions.gd` | The actions stay; their `do` half walks at once (R17). The file is near the 800-line mark: new code goes to new files |
| The movement phase plans every marching army's leg alone (`_leg`), then walks the legs tick by tick in army id order, engages contacts through `Battles.engage`, cuts steps into another country's hex, steps back for the stack limit, applies orders and halts, emits `unit_moved` and `march_halted` | `godot/core/systems/movement_phase.gd` (`Walk`, `_leg`, `_ticks`, `_tick`, `_room`, `_apply`) | The same engine walks one army at once: it is split out first as a pure refactor (D2) |
| An army's move points are `Movement.mp_of` (the slowest company's `UnitDef.mp`: pikemen and crossbowmen 12, knights 16, bombards 8); nothing stores what an army spent | `movement.gd`, `godot/data/defs/units/*.tres` | A new saved field `Army.points` (R12) |
| `Movement.walk_season` / `walk_plan`: the wade and the "costlier than the points, first step only" rules, the season-by-season stops | `movement.gd` | "First step" becomes "the army is fresh" (R18); plans learn the fog step (R39) |
| A zone of control ends a leg in the phase with no halt (the march goes on next season) | `MovementPhase._leg`, `Movement.zoc_halts` | Now it also ends the season: points 0 (R25) |
| A blocked step names the holder's country whether or not it is in sight ("an army of %s is at %s") | `MovementPhase._cut` | A fog leak (fog R32 missed it); the shared step uses fog-safe words (R24) |
| `Battles.engage` starts, joins or storms; the `battles` phase fights every battle in hex index order (`Combat.fight`, `game.luck.world`) and empties `game.battles`; a storm order standing on its goal starts its assault there | `godot/core/systems/battles.gd` (`engage`, `season`, `_fight`) | `fight_now` fights one battle at once (R26); the phase path stays for standing marches |
| `game.battles` and the records are already in the save (`battles/1`); at idle the list is empty | `battles.gd` `to_dict`, `godot/core/game/snapshot.gd` | No `battle/2` now: a battle fought in the act leaves nothing open (D10); `battle/2` is the board's (section 7) |
| A battle's attacker gets order none with its goal and route kept (`Battles._step_in`); the beaten side retreats with `unit_moved` (why `retreat`) and halts | `battles.gd`, `godot/core/systems/battle_end.gd` | The winner keeps today's state (D12) |
| `Military.raise` puts new companies into the first army of the tag on the hex that does not march | `godot/core/systems/military.gd` | Only into a fresh army (R15) |
| `Armies.clear_moved` empties every army's `moved_from` at the start of the movement phase; the season report's "A → B" lines read `moved_from` | `godot/core/systems/armies.gd`, `godot/core/views/summary_armies.gd` | At-once walks would vanish from the report: `season_from` (R40) |
| `Season.PHASES`: `ai_orders` first, then `movement`, `battles`, ... `calendar`, `ready_units`, `vision`; Session refuses `act` and `check` while a season runs | `godot/core/game/season.gd`, `godot/shell/autoload/session.gd` | The order the owner chose already holds: the player acts at idle, the computer at End season (R3). PHASES do not change |
| The AI acts only through `AiKnow.act` (check, then `Game.act`); `AiWar._march`, `_recover`, `_post`, `AiForces` march and halt; seats rotate by turn | `godot/core/ai/` | The AI's marches walk at once with no new code path (R9, R41) |
| The replay plays the action log through `Game.act`, the AI's records through `LogOrders` | `godot/core/game/replay.gd`, `log_orders.gd` | At-once walks and battles are consequences of logged acts: nothing new to log (section 6) |
| `MoveReplay` keeps the season's `unit_moved` and plays them after the season with a `ReplayPlan` (ticks, seen flags, battle marks, retreats after the last tick); orders are refused while it runs | `godot/shell/map/move_replay.gd`, `godot/core/views/replay_plan.gd`, `replay_marks.gd`, `godot/shell/map/map_armies.gd` (`REPLAY_BLOCKED`) | A live mode for the player's own walks (R49) and a chained plan for the computer's (R50) |
| `MovePreview.to`: the verdict, the route, the season stops, crossings, the winter line, the supply at the march's end, the war words; `MapArmies.command` acts on a right click or O | `godot/core/views/move_preview.gd`, `godot/shell/map/map_armies.gd`, `godot/shell/hud/move_card.gd` | Gains this season's `leg` and the `risks` (R45, R46); the confirm sits in `command` (R48) |
| `TileArmy` rows carry an empty `points_text` kept for this issue | `godot/core/views/tile_army.gd` | Filled (R51) |
| `SaveFile.FORMAT` 7, `OLDEST_FORMAT` 7; `Army.SCHEMA` `army/2`; the loader compares the loaded game's digest with the header's | `godot/core/game/save_file.gd`, `godot/core/state/army.gd`, `session.gd` `load_game` | FORMAT 8 (D22) |
| Issue 427: the battles phase costs about 1.7 s a battle on the made-up Europe war rig (the fight is 1 ms; suspected a cold war cache per battle end) | `godot/tests/perf_core_budget.json` `battles_ms` | A battle on a click must not freeze the window: fixed in this build (MV3) |
| `march` takes `{army, goal}` only; `Army.goal` is the end of `Army.route`; the re-plan of a blocked step goes to `goal`; `halt` twice clears goal and route | `godot/core/systems/movement.gd` (`march`, `_march_verdict`, `goal_verdict`, `halt`), `godot/core/state/army.gd`, `godot/core/systems/armies.gd` `set_order` | A route through stops needs a stored list of the stops not yet reached (R64) and a re-plan that never skips one (R65) |
| Right click (`map_command`) commands, Shift+right click storms (`MapInput._storms`, `storm_ready`); Shift+left click is only the select click (`MapInput._on_unit` merely excludes Shift) and Shift alone is "fast pan" and holds the works card | `godot/shell/input/map_input.gd`, `godot/shell/input/bindings.gd` (`cam_pan_fast`, GESTURES), `godot/shell/app/war_requests.gd`, `godot/shell/app/works_flow.gd` | Shift+left is free as a gesture with an army selected; no clash with a click (R58); the key list and the four GESTURES lists gain lines (R62) |
| Esc runs `EscLadder.decide`: screen, HUD list, then clear the selection (an army counts), else the pause menu; `MapArmies.command` stages nothing | `godot/shell/input/esc_ladder.gd`, `godot/shell/app/app.gd` `_on_back_requested`, `godot/shell/map/map_armies.gd` | A new rung `CLEAR_STOPS` above `CLEAR_SELECTION` (R61) |
| The path is drawn by `PathMarks` from a preview dictionary (`stops` = season stops, `crossings`), the stored route thin | `godot/shell/map/path_marks.gd`, `godot/core/views/move_preview.gd` `to` and `stored` | Stop markers and per-leg lines (R59, R68) |

---

## 2. Decisions taken

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | Where the walk happens | Inside the existing actions: `Movement.march`, `continue_march` and `storm` call `WalkNow.walk` after setting the order. **No new action name**; the verdict gains a `walk` dictionary | The design's "the march stays one action": the same checks, refusals, log records, AI door and replay |
| D2 | One engine or two | **One**: the movement phase's leg, step, contact, cut, room and apply code moves to `MarchLeg` (a pure refactor, its own task, digests equal before and after); the phase walks many `MarchLeg`s tick by tick, `WalkNow` walks one | Two walk engines would drift; the phase's rules are tested |
| D3 | How the allowance is kept | `Army.points`: the move points **left** this season, 0 to `Movement.mp_of`. Refilled in `ready_units`. "Fresh" = points equal to the full points (and above 0) | Storing what is left (not what was spent) closes the disband loophole (dropping the slow company would raise a spent-based allowance) |
| D4 | An order that cannot walk now | Accepted and stored as a standing march: a mustering army, an army with 0 points, a winter wait at the first step. No new refusal | One rule; the preview says when it sets out; the AI needs no new case |
| D5 | Zone of control | Ends the walk **and the season** (points 0) at once and in the phase; the march stays standing, no halt | The design 2.7; today it already ends the leg with no halt |
| D6 | Stop on sight, where | In the at-once walk **and** in the movement phase's standing marches | Owner answer 5 names "the walk"; one step rule for both walks (D2) |
| D7 | "Comes into sight" | An army of a country at war with the walker's, standing within the walking army's sight after a step, that the walker's country did not see when the walk began | Measurable, fog-safe (it is in sight now, so it may be named), deterministic |
| D8 | Zone of control against sight on one step | Zone of control wins (points 0) | The design: "zone of control stops the army anyway" |
| D9 | Deep fog (the owner will come back to the rule) | **Default:** a step onto a hex the walker's country has not explored (its explored bit) is a fog step: taken only when the army is fresh, it spends all the points, like a wade. One data value, `GameDefs.fog_step_cost` (-1: all points). The vision phase explores the army's sight ring, so sight 1 advances about one hex a season through unmapped land and knights (sight 2) about two | Owner answer 6: "for example one tile a month; scouts discover land more easily". The explored bit, not sight, because the army's own sight ring makes every next hex "discovered" (fog D1) and a sight-based rule would never bite |
| D10 | A battle before the board | Fought at once in the act (`Battles.fight_now`: `Combat.fight` on the live input, `BattleEnd.apply`), the defender on its standing order; `game.battles` is empty at idle as today | Owner answer 7 gives the result at once; the board (#437) later changes only how the days are played (section 7) |
| D11 | Who is done after a battle | Every army of both sides that fought ends its season (points 0), at once and in the phase | The design 2.5 ("entering a battle ends the army's season") applied to both sides, so a beaten computer army cannot walk again in the same season |
| D12 | The winner's march | Today's code: order none, goal and route kept; Continue (R) or the AI re-orders | The code already does this (Appendix B, item 2); no behaviour change rides on it |
| D13 | Storm | A storm with points left walks at once and its assault is fought on arrival (or at once when it stands on the fortress); with 0 points or mustering it stays a standing storm and the battles phase starts it as today | The design 2.6; one rule for march and storm |
| D14 | Raise, split, merge, disband | Raise joins only a fresh army that does not march, else makes a new army; split: the new army gets the parent's points (capped at its own full); merge: the lower of the two (capped); disband: capped at the new full | The design 2.5's loophole rules in the D3 form |
| D15 | The report's moves | New `Army.season_from` (the hex the army stood on when it first moved this season); `ready_units` copies it into `moved_from` and clears it; `clear_moved` at the phase start goes | The report and J must show the season's at-once walks too, and a walk in the next season must not change the report of the last |
| D16 | The season's order | `Season.PHASES` unchanged; the player's turn is the idle time before End season | Owner answer 2 is today's order |
| D17 | The computer | Same action. After a walk that halted on sight, the AI re-reads what it sees (`brief.seen`) and gives that army one more step (`army_retry`, bounded by `order_tries`) | Owner: the AI follows the same rules; a halt it does not answer would park its armies |
| D18 | The confirm | Shell only, from `MovePreview.leg`'s `risks`; for march, continue and storm; a setting `game/confirm_moves` (on by default) | Owner answer 3; the AI never confirms |
| D19 | The live walk | `MoveReplay` in a **live mode**; no new `SeasonFlow` state; any input that acts skips it first | A walk is a picture of a done thing; blocking input for it would be a stall |
| D20 | The season replay | The computer's at-once walks are laid one after another in the order they happened (`ReplayPlan.chain`), then the phase's walks tick by tick; the player's live walks are not played again | Sequential walks drawn as simultaneous would show armies passing each other that never met |
| D21 | A battle you open, before the board | After its walk has played, the battle dock opens on its record (read-only stepper, as a badge click does) | "I see what happened at once" (the design 1) without building the board |
| D22 | Saves | `SaveFile.FORMAT` **8**, `OLDEST_FORMAT` 8, no upgrade step; `Army.SCHEMA` `army/3` | Two new army fields enter the digest, so a format-7 file would load as "damaged"; a format-7 action log means something else under the new rules; no Godot save has reached players (fog D16's reasoning) |
| D23 | Luck | At-once battles draw `game.luck.world` inside the act, in act order; checks, previews, views and pauses draw nothing (pinned) | The action log fixes the order of every draw (the design 3) |
| D24 | Fair warning (M8 D23) | Stays a rule of the AI only (default); open owner question Q1 | Not asked; changing the player's war start is the owner's call |
| D25 | Option A of the design (one move a season) | **Not built**: no `moves_per_season` switch | The owner chose B; a switch nobody uses is dead code |
| D26 | Sight after a walk | `Sight.refresh` (the whole army part) once at the walk's end; the per-step sight test reads the walker's own disc only. Fallback (section 9): an incremental refresh | Simplest correct; `Sight.refresh` is a loop over the armies |
| D27 | Explored along an at-once walk | The steps only (radius 0), as the phase (fog R8); the rings come with the vision phase | One explored rule for both walks; D9's pace depends on it |
| D28 | Task IDs | `MV0` to `MV18` (and `MV19`, D37) | M, MOV and W are taken or ambiguous |
| D29 | What a stop is (multi-leg, owner request 2026-11-25) | A **stop is a place the route must pass, not a place the army halts**: the stops and the goal are one longer route walked under one allowance, season by season, by the same engine (`MarchLeg`). The army does not stop at a stop; it halts only for the reasons it halts today | "First leg at once, the rest per month" is exactly R5 applied to the longer route; separate orders per leg would ask a confirm and wait a season at every stop |
| D30 | How the order carries the stops | `march` gains an optional `via` (list of hexes, in order, the goal not included); **no new action name**; `march_check` and `march` stay a pair | A second action would double the checks, the AI door, the log grammar and `random_player.gd`; an empty or missing `via` is today's march byte for byte |
| D31 | Where the stops are stored | `Army.via` (hex indices of the stops not yet reached, the goal not in it), a third new field of `army/3` beside `points` and `season_from`; written only by `Armies.set_order`. **Fits `army/3` and FORMAT 8**: `army/3` is unbuilt, so MV19 edits it in place; if a FORMAT 8 build has reached players by then, MV19 bumps to 9 (`OLDEST_FORMAT` 9) and says so | The route alone loses the stops (a re-plan would cut across them), and the preview, the panel and the markers need them |
| D32 | Staging | **Shell only** (`MapArmies` holds the staged hexes): no act, no log record, no save until the commit; Shift+left click with an army of yours selected stages, without one it selects as today | An undone plan must leave no trace in the game or the digest; the log only holds decisions |
| D33 | The commit | A plain right click on a hex while stops are staged orders `march {goal: that hex, via: staged}`, so the route drawn under the pointer is the route ordered (what you see is what you commit); a right click on the last staged stop commits with that stop as the goal; the command key O does the same at the cursor | One rule for "right click commands"; the brief's "right click on the last hex" is the special case where the pointer rests on the last stop |
| D34 | Esc | **Esc clears every staged stop in one press** (a new ladder rung above clearing the army); removing one stop is Shift+left click or `V` on the last stop | Esc already means "step out of whatever is in progress, one level at a time"; a plan of stops is one level; one press that removes only the last stop would need up to six presses to leave and would sit oddly with the other rungs; the one-at-a-time removal already has two ways |
| D35 | The computer | **No multi-leg for the AI** (default): its marches never carry `via`; `Army.via` is empty for every computer army | The AI plans destination by destination each season (`AiWar`, `AiForces`); stops give it nothing and cost soak time |
| D36 | How many stops | `GameDefs.max_stops` = 6 (at most six stops before the goal, so at most seven legs) | A data value; the check and the shell read it |
| D37 | Task IDs for this request | One task, `MV19`, in a new group D2 between D and E | It edits `map_armies.gd` and `move_card.gd`, which MV10 also edits, so it cannot be in group D |

---

## 3. The rules

"P" names the planted fault the test must catch. "The walker" is the army that walks; "its country" its tag. Every walk
rule holds for the player's armies and the computer's alike.

### 3.0 The owner's rules (2026-11-24, and the brief of 2026-11-25)

- **R1 At once and final.** An accepted `march`, `continue_march` or (with points left) `storm` walks its army inside the
  same `Game.act`, before it returns; the game state after the act is final. No action undoes a walk; Ctrl+Z stays for
  works only (`GameRequests.undo_work`). P: a march that only stores its order (the army still on its old hex after the act).
- **R2 Many moves a season.** Each army has one allowance a season (`Army.points`, full = `Movement.mp_of`). Each walk spends
  what its steps cost; a later order walks with what is left, until it is spent. P: a second march that walks with the full
  points.
- **R3 The player first, the computer answers.** The player's orders walk while the flow is idle; at End season the
  `ai_orders` phase runs every computer seat (the first seat rotating each season, M8 D9) and their marches walk at once
  through the same action; then the movement phase walks the standing marches. `Season.PHASES` is unchanged. P: a phase table
  with `movement` before `ai_orders` (the pin of `test_season.gd`).
- **R4 Confirm only risky moves.** An order whose walk this season opens a battle, enters land of a country at war with the
  walker's, or ends out of supply asks once ("Move" / "Cancel"); every other order is one click; Cancel changes nothing.
  P: a confirm on a plain march; a march into a seen enemy army with no confirm.
- **R5 Long marches keep their pace.** The first leg walks at once; the rest of the route stays as the standing march and walks
  one leg a season in the movement phase from the next season on (this season's points are spent). P: an army that walks two
  legs in one season.
- **R6 Stop on sight.** A walk ends on the step after which an enemy army first comes into its sight (D7); the points left
  are kept. P: a walk that walks past a newly seen enemy army.
- **R7 Orders into deep fog.** An order may name a goal the country has not discovered, and its route may cross undiscovered
  land; those steps carry the movement penalty of D9 (a data value; the owner will set the final rule). P: an undiscovered
  goal refused; a fog step at its normal cost.
- **R8 Battle at once.** A walk that steps onto an army of a country at war with the walker's, or a storm that reaches its
  fortress, opens the battle in the same act; until #437 it is fought at once (D10) and the shell shows it in the dock after
  the walk has played (D21). P: a battle left in `game.battles` after the act.
- **R9 The computer follows the same rules.** The AI orders through `AiKnow.act` and the same actions; no AI-only walk; its
  armies spend points, stop on sight, take fog steps and fight at once alike. P: a file of `godot/core/ai/` that names
  `WalkNow`, `MarchLeg` or `MovementPhase` (the door scan of `test_ai_door.gd`).
- **R10 Save anywhere.** At idle, after any number of at-once moves, a save then a load gives the same digest, points,
  standing marches and `season_from`; F5 during a live walk saves (the walk is done in the game; the picture is skipped).
  P: points lost on load.
- **R11 Decided before the board.** This build defines the battle board's seam (section 7) and builds no board.

### 3.1 The allowance

- **R12** `Army.points` (whole number, 0 to the army's full) is written only by `Armies.set_points`. `Allowance`
  (`godot/core/systems/allowance.gd`, new) holds the reads and the rules: `full(game, army)` = `Movement.mp_of`, `left(army)`,
  `fresh(game, army)` (points equal to full and above 0), and the R13 to R15 adjustments. P: a second writer of `points`
  (`test_owns.gd` and `test_no_other_writers.gd` pin the field).
- **R13** `Allowance.refill(game)` runs in the `ready_units` phase (the new season's start, before `vision`): every army's points
  become its full. A new army gets its full points when it is made (`Military.raise` after its companies, the scenario's
  start armies). Nothing else raises an army's points. P: points that grow inside an action.
- **R14** Points never go below 0, and never above the full: every writer clamps, and `Allowance.check` (invariant I1) says
  which army breaks it.
- **R15** Raise joins the first army of the tag on the hex that is **fresh and not marching**; otherwise it makes a new army.
  Split: the new army's points = min(the parent's points, its own full); the parent's = min(its points, its new full). Merge:
  `into` gets min(the two armies' points, its new full). Disband of companies: min(points, the new full). P: split then merge
  that gives more points than either army had; a raise into an army that has walked.
- **R16** Mustering is unchanged: an army with a company raised this turn does not walk, at once or in the phase; an order
  given to it is stored (R20).

### 3.2 The walk at once

- **R17** `Movement.march`, `continue_march`, and `storm` when its army has points left call `WalkNow.walk(game, army)` after
  `Armies.set_order` and return `{ok, reason, army, walk}` (section 4). The `*_check` halves never walk and keep their words.
  P: a check that moves the army.
- **R18** The walk is one `MarchLeg` with the army's **points left** in place of its full points, under the phase's leg rules:
  the stored route step by step; a re-plan where the next step is no longer open (up to `Movement.MAX_REPLANS`); a closed
  pass: the wait or the winter detour of M6 D20; a wade step or a step costing more than the points left is taken only when
  the army is fresh and spends all its points. Then the steps are taken one by one with the contact rule (R26), the
  other-country rule (R24) and the zone of control (R25). P: a wade taken by an army that walked already this season.
- **R19** At the walk's end, through `Armies`: the hex (and `season_from`, R40); the order (arrived: hold, goal cleared; route
  left: the march stays with the rest of the route; halted: order none, goal and route kept, `halt_why` and `halt_text`); the
  points left. Events, in order: `unit_moved` (with `now: true`), `march_halted` for a halt, `army_changed`. Explored: the
  steps (`Sight.see_path`, radius 0, D27); then `Sight.refresh`. P: an at-once walk with no `unit_moved`.
- **R20** An order that cannot walk now is accepted and stored, and walks nothing: mustering (`walk.stopped` `&"mustering"`),
  0 points (`&"no_points"`), the first step a closed pass with the wait chosen (`&"winter"`, waiting set as today). P: any of
  the three refused.
- **R21** An army never spends more than its full points in a season: at most one step a season costs more than the points
  left, and only when the army is fresh (invariant I2). P: a walk at once then a phase leg that both take such a step.
- **R22** The movement phase walks only armies with a march or storm order, not mustering, with points above 0; each leg uses
  the points left and leaves what is left (`Armies.set_points`). P: a phase that walks an army that spent its points at once.
- **R23** Room: the goal's check (`Military.can_stand` with `_adding`) at order time, as today. The at-once walk runs the
  same room cut as the phase with its one walk, so a leg that would end on a hex already full of the walker's companies ends
  on the last hex with room. The phase's step-back rule stays. P: nine companies of one country on a hex after a walk.
- **R24** A step onto a hex where an army of another country at peace stands (or a test-hostile pair) is not taken: the walk
  stops before it, halt `blocked`. The words name the country only when the walker's country sees the hex ("an army of the
  Duchy of Milan is at Novara (8, 9)"; else "another country's army stands at Novara (8, 9)", the words of
  `Battles.engage_check`, and the place only when discovered). The phase's `_cut` uses the same words. P: the country named
  out of sight (today's phase does).
- **R25** A step (not onto the goal) beside an army of a country at war or a hostile garrisoned fortress (`Movement.zoc_halts`)
  ends the walk and the army's season: points 0, the march stays standing, no halt; at once and in the phase. P: points kept
  after a zone of control.

### 3.3 Battles at once, storms

- **R26** A contact step (a hex with an army of a country at war, a battle on the hex, or a storm's fortress) calls
  `Battles.engage` as today. When engage takes the army in, `WalkNow` calls `Battles.fight_now(game, battle)`: the battle's
  input (`input_of`), `Combat.fight` with `game.luck.world`, `BattleEnd.apply`, the record kept (the oldest dropped past
  `battle_records_kept`), `Occupation.flush`, `Sight.refresh`. `game.battles` is empty after the act; `walk.battle` is the
  record's id. P: the battle left for the battles phase.
- **R27** After every fought battle (`fight_now` and each battle of the battles phase) every surviving army of both sides has
  points 0 (D11). P: a beaten army that walks again in the same `ai_orders` phase.
- **R28** A contact `engage_check` refuses (too shaken, two enemy countries, room) stops the walk before the hex with today's
  halt words (`WHY_SHAKEN`, `WHY_ENEMY`, `WHY_BATTLE`). P: a shaken army that steps in.
- **R29** Storm (D13): with points left and standing on its fortress, the assault opens and is fought in the act; with a route,
  the walk walks there and the assault is fought on arrival (the storm's contact, `MovementPhase._contact`); points 0 after.
  With 0 points or mustering the storm is stored and the battles phase starts it (today's path). A halted storm and Continue
  behave as today, and Continue walks at once. P: a storm with points left that waits for the battles phase.
- **R30** The winner of an at-once battle keeps today's state: order none, goal and route kept, points 0 (D12); its panel reads
  "Halted" with Continue. P: a winner that walks on in the same season.
- **R31** Luck (D23): a battle's days are drawn when it is fought, in the order the acts are done; `Game.check`, every view,
  `MovePreview` and a pause draw nothing. P: 1,000 checks and previews that change `game.luck` (the luck digest compared).

### 3.4 Stop on sight

- **R32** At the walk's start the walker's country's seen set S is the armies of countries at war with it whose hex it sees
  (`Sight.sees`). After each step taken that opened no battle, the armies of countries at war within the walking army's sight
  (`SightCache.disc(hex, army sight)`, read through `Movement.armies_on`) are looked up; one that is not in S ends the walk
  there: halt `sighted` (`Movement.WHY_SIGHTED`), order none, goal and route kept, the points left kept. The halt's words:
  "an army of the Duchy of Milan came into sight at Novara (8, 9)" (it is in sight, so it may be named). P: a walk that goes
  on.
- **R33** The zone of control wins on the same step (R25, D8). A step onto the goal ends the walk as arrived. P: a sighted
  halt that keeps points beside the enemy.
- **R34** The movement phase applies the same rule to each walk: S is taken at the phase's start; the test runs at each tick
  with the armies where they stand at that tick. P: a phase walk that passes an army that walked into its sight.
- **R35** Continue after a sighted halt walks at once with the points left and a new S (the army seen is now in it), so it does
  not stop again for the same army. P: Continue that halts at once on the same army.

### 3.5 Deep fog (default of D9)

- **R36** A fog step is a step onto a hex whose explored bit (`Sight.explored`) the walker's country lacks. It is taken only
  when the army is fresh, and spends `GameDefs.fog_step_cost` (-1: all the points), at once and in the phase. `GameDefs.validate`
  accepts -1 or 1 to 99. P: a fog step taken second in a season.
- **R37** The step explores its hex (R19); the vision phase explores the army's sight ring (today, `Sight.season`), so the
  next steps are mapped by the next season: about one hex a season with sight 1, about two with sight 2. P: a sight-2 army
  that advances one hex a season through unmapped land.
- **R38** `Movement.walk_season` and `walk_plan` take the walker's country's unexplored hexes as fog steps (a cautious
  arrival estimate); the route search keeps using the real map (the leak the owner's answer accepts; section 10). An
  undiscovered goal is not refused for being undiscovered, and its refusal words follow fog R32.
- **R39** On north Italy every country has explored every hex at the start (fog D3), so R36 to R38 change nothing there; they
  are proved on `FogFixture.thin`. P: a fog step on north Italy.

### 3.6 Where an army came from

- **R40** `Army.season_from` is the hex the army stood on when it first moved this season (`Army.NO_HEX` before). Every
  `Armies.set_hex` of a walk, a retreat or a peace placement sets it only when it is `NO_HEX`. In `ready_units`,
  `Armies.close_season` sets `moved_from = season_from` and `season_from = NO_HEX` for every army; `Armies.clear_moved` and its
  call at the movement phase's start go. The season report (`SummaryArmies`) keeps reading `moved_from`, so it shows a
  season's at-once walks and phase walks together, and a walk of the next season does not change the last report (J).
  P: an at-once walk missing from the report; a report changed by a walk after it.

### 3.7 The computer

- **R41** `AiWar._march` and the marches of `AiForces`: when the act's `walk.stopped` is `sighted`, the step refreshes
  `brief.seen` from `AiKnow.seen_enemies` and asks `turn.army_retry`, so the army decides again with what it now sees (at
  most `order_tries` steps a season, as today). P: a sighted halt that leaves the army halted for the season.
- **R42** A later seat reads where an earlier seat's armies now stand through the live sight (`AiKnow`), as it reads anything.
  The brief stays made at the seat's start; only `seen` is refreshed (R41).
- **R43** Fair warning (M8 D23) is unchanged: in the season a seat declares a war, its armies take no order into that enemy's
  land (Q1 asks whether the player gets the same rule).
- **R44** A turn stepped one step a frame equals the turn at once (`test_ai_turn.gd`, `test_ai_determinism.gd`), and the
  replay of the AI's records through `LogOrders` equals the live season, with at-once walks and battles in it. P: a step that
  reads the event queue (kept from M8).

### 3.8 What the player is shown before an order

- **R45** `MovePreview.to(game, tag, army, hex)` gains `leg`: the walk `WalkNow` would do now if no army the viewer cannot see
  stands in its way: `{hexes (walked now, in order), cost, points_before, points_after, full, end, why}` with `why` one of
  `&"arrives"`, `&"points"` (out of points, the rest standing), `&"fog"`, `&"winter"`, `&"zoc"`, `&"battle"`, `&"sighted"`
  (an army the viewer sees now cannot be newly sighted, so the preview never gives this one), `&"mustering"`, `&"no_points"`.
  It equals the walk that follows whenever no unseen army is on or beside the leg (done-when 3). P: a leg that ignores the
  zone of control.
- **R46** `MovePreview.to(...).risks`: an array of `{kind, text}` from what the viewer knows: `&"battle"` (the leg's last step
  is onto an army at war the viewer sees, or the storm's fortress), `&"enemy_land"` (a hex of the leg is controlled by a
  country at war with the walker's and the army does not stand in that country's land now), `&"out_of_supply"` (the leg's end
  is out of supply at the season's end, `SupplyView` as the march end's line today). P: a risk from an army the viewer does
  not see (the twin test of R57).
- **R47** The preview's lines gain, in this order after the war line: "Walks 3 hexes now: 7 of 12 move points, 5 left."; for a
  route longer than the season "Stops at Cerano (7, 9) this season; walks on at the end of next season, there in Autumn
  1481."; "No move points left this season: it sets out at the end of next season."; "Unmapped land at (12, 3): the army
  spends its season finding the way."; then the risk lines. The words are `MovePreview`'s; the move card draws them.
- **R48** The confirm (shell): `MapArmies.command`, the R key's continue and the Storm requests read `MovePreview.to(...).risks`
  (for a storm, its battle); when it is not empty and `game/confirm_moves` is on, a `Confirm` asks ("Move the Army of Turin?",
  one line a risk, "Move" / "Cancel"); Move does the `Session.act`, Cancel nothing (no toast). `game/confirm_moves` is a new
  setting (bool, on, page "game", label "Confirm risky moves"). P: an act before the answer.

### 3.9 The shell: the live walk, tokens, panels, words

- **R49** **The live walk.** `MoveReplay` keeps the `unit_moved` events (and the battle events) that arrive while
  `Session.in_season()` is false as one live batch and plays it from the next frame with a `ReplayPlan` at the
  `game/movement` speed (instant or reduce motion: not played); the camera follows the walker as the replay does. Before any
  input that acts (an order, R, Storm, End season, F5, F9, a load) and on Space, Enter, Esc or a click on the map, a running
  live walk is skipped (the tokens land where the game has them); Space, Enter and Esc then do nothing more. No `SeasonFlow`
  state is added and no order is refused because a live walk runs. P: a live walk that changes the game (digest, version);
  an order refused during a live walk.
- **R50** **The season replay.** Records that arrive while a season runs are the season's; `ReplayPlan.chain(records)` (pure)
  lays the records with `now` one after another in arrival order (each walk's ticks after the last tick of the one before; a
  retreat right after its battle's walk), then the phase's records tick by tick after the last; the `MAX_SECONDS` cap and the
  speeding up are unchanged. The player's live walks are never in it. P: two at-once walks of the computer played on the same
  ticks; a player's walk played twice.
- **R51** **Points on view.** `ArmyView.tokens` gives own tokens `points_left` and `points_full` (the lowest left and the
  lowest full of the armies on the token); `ArmyToken` draws a small points mark (a bar of left over full; empty at 0; none on a
  foreign token). `ArmyView.panel` gives `points` `{left, full, text}` ("8 of 12 left this season"), shown in the army panel's
  costs block where the move points are today. `TileArmy` rows fill `points_text` with the same text. A foreign army shows no
  points (fog D8: orders are hidden). P: points on a foreign token.
- **R52** **The words.** `MoveWords.of(game, viewer, army_id, walk)` (`godot/core/views/move_words.gd`, new, pure) gives the
  order's toast: walked ("The Army of Turin walks to Vercelli (6, 9): 8 of 12 move points left."); walked with a standing rest
  ("... walks to Cerano (7, 9); it marches on to Pavia (10, 9) at the end of next season."); stored ("... sets out for Pavia
  (10, 9) at the end of next season."); sighted ("... stops at Cerano (7, 9): an army of the Duchy of Milan came into sight at
  Novara (8, 9)."); battle ("... attacks at Novara (8, 9): the Battle of Novara, 1481."); zone of control ("... stops beside
  an army of the Duchy of Milan at Cerano (7, 9): its season is over."). `MapArmies` shows them instead of today's
  `_marches_words`. P: a toast that names an army out of sight.
- **R53** **The dock after a battle.** When the live walk of an act with `walk.battle` set has played or been skipped (or was
  not played), `WarRequests.open_battle(record)` opens the battle dock on it. P: the dock opened before the walk ends.
- **R54** **Help.** The help overlay and the key hints say "Army moves are final: an army walks when you give the order." The
  season replay's line `REPLAY_BLOCKED` stays for the season's replay only.

### 3.10 Saves, digest, determinism, fog

- **R55** `SaveFile.FORMAT` 8, `OLDEST_FORMAT` 8 (D22). `Army` `army/3` adds `points` and `season_from`; `Army.from_dict` refuses
  a missing or mistyped field and a negative `points`; `Armies.from_dict` refuses points above the army's full and a
  `season_from` off the map. A format-7 header reads `older`. Save, load, save is byte-equal on north Italy with armies
  mid-season (some walked, one standing, one halted on sight). P: a format-7 file that loads; points above the full that load.
- **R56** `Army.digest_text` adds the two fields, so `Game.digest()` covers them. `Replay.run` of a log with player marches,
  at-once battles and AI seasons gives the live game's digest (`test_replay.gd`, `test_war_property.gd`,
  `test_moves_replay.gd`). No test pins a digest value. P: one changed march argument gives another digest (kept).
- **R57** Fog: an at-once walk's `unit_moved` carries `seen` and `witnesses` as the phase's (`MarchLeg`); a foreign walk is
  played to the viewer only where seen; refusals, halt words, the preview's `leg` and `risks` name only what the walker's
  country has discovered or sees (fog R32, D15). Twin test: two games that differ only in armies the viewer does not see give
  equal `MovePreview.to` results (verdict, leg, risks, lines) for every order of the viewer's armies. P: a risk or a leg end
  that moves with an unseen army.

### 3.11 Multi-leg marches (owner request 2026-11-25; GitHub issue "Multi-leg marches: Shift+left click adds waypoints to an army's route")

"A stop" is a waypoint (D29). "Staged" stops live in the shell only. Every rule of 3.0 to 3.10 holds for the whole route.

- **R58 Staging.** With an army of yours selected, the flow idle and orders not blocked, Shift+left click (no Ctrl, Alt or Meta) on
  a hex appends it to `MapArmies`' staged stops: no act, no log record, no change of the digest or the version. Refused with a
  toast, nothing appended: off the map, water, the same hex as the army or as the stop before it, more than `GameDefs.max_stops`,
  or a leg the verdict refuses (`Movement.goal_verdict` from the previous point, fog-safe words). Shift+left click on the last
  staged stop removes it. With no army selected Shift+left is the plain select; while the season replay runs it is refused as any
  order is (`blocked_click`). P: a staging that changes the digest; Shift+left with no army that no longer selects.
- **R59 The picture before the order.** `MovePreview.via(game, tag, army_id, stops, hex)` (stops staged, `hex` the pointer's hex
  as the goal) gives the route through every stop in order: for each leg `{from, to, hexes, cost, seasons, arrives_turn}`, the
  whole route's total cost, seasons and arrival, the verdict, and this season's walk (`leg` and `risks`, R45 and R46) read on the
  whole route. The map draws one path through the stops, a numbered marker on each stop, and the lines "Leg 2: Vercelli (6, 9)
  to Novara (8, 9): 5 move points, 1 season, there in Summer 1481." and "Whole route: 3 legs, 14 move points, 2 seasons, there in
  Autumn 1481." (the hover card's tooltip carries the total). The legs of staged stops are cached per (army, version, from, to), so
  moving the pointer recomputes only the last leg. P: a total that is not the sum of its legs; a preview that skips a stop.
- **R60 The commit.** A plain right click on a hex while stops are staged, or O at the cursor, orders `march {army, goal: hex,
  via: staged}` through `Session.act` (the confirm of R48 reads the whole first season's risks); on `ok` the staged list is
  emptied; refused, the stops stay and the toast gives the reason. A right click on the army's own hex halts as today and
  drops the stops. Shift+right click (storm) with stops staged is refused ("A storm takes no stops: clear them first (Esc)");
  a storm and `continue_march` never take `via`. P: a commit that drops a stop; a storm that drops the stops silently.
- **R61 Clearing.** `EscLadder` gains `CLEAR_STOPS` (state key `has_stops`) above `CLEAR_SELECTION`: Esc clears every staged stop
  (D34); the staged stops also clear when another army is selected, the selected army is gone, End season starts, a save is
  loaded or a new game begins. Shift+left click or `V` on the last staged stop removes it. F5 saves the game without them.
  P: Esc that leaves stops staged; stops that outlive their army's selection.
- **R62 A way without Shift.** New binding `map_waypoint_key` ("Add or remove a stop at the cursor", group Map, key `V`, free
  today): at the order cursor (Alt+arrows) or else the hovered hex it acts as Shift+left click. While stops are staged the move
  card shows two buttons, "March" (commits to the pointer's hex or the order cursor, as O) and "Clear stops" (as Esc). The
  help overlay lists the key; each of the four GESTURES lists of `bindings.gd` gains "Shift+left click: add a stop to the
  selected army's march (V at the cursor)"; `key_hints.gd` shows "V stop" while an army is selected. No other binding changes
  (checked: `V` and Shift+left are unused; Shift+right click, Shift+O, Shift+wheel and Shift as fast pan and as the held works
  card are different gestures). P: a binding that duplicates another key; a GESTURES list without the new line.
- **R63 The order.** `Movement.march_check` and `march` read `args["via"]` (an `Array[Vector2i]`, default empty): at most
  `max_stops`; each point differs from the one before it; every leg `goal_verdict` from the previous point (the first from the
  army's hex), the first refusing leg's words prefixed "Stop 2: " (or "The goal: "); the route is the legs' hexes joined; the room
  check is for the goal only (a stop is passed through). An empty `via` gives today's order and today's words. The check and the
  act agree (`test_check_contract.gd`). P: a bad second leg accepted; a check that says yes and an act that refuses.
- **R64 The stored stops.** `Army.via` (PackedInt32Array of hex indices, the next stop first, the goal not in it) is written
  only by `Armies.set_order(game, army, order, goal, route, via)`; a plain march, a storm, a hold and an arrival give an empty
  `via`; `halt` once and a halted march keep goal, route and `via` (Continue resumes them); `halt` twice clears them;
  `continue_march` re-plans through the kept stops. `army/3` saves it and the digest covers it (`Army.digest_text`);
  `Army.from_dict` refuses a non-hex or more than `max_stops`, and a non-empty `via` with no goal. P: a `via` left after a hold; a
  second writer of `via` (`test_owns.gd`, `test_no_other_writers.gd`).
- **R65 The walk.** The route is walked as one: one allowance, the same sight, zone-of-control, fog and battle rules, the army
  not stopping at a stop (D29). `MarchLeg` removes a stop from `via` when a step lands on it. A re-plan (a blocked step,
  `MAX_REPLANS`, a winter detour) plans from where the army stands to the next stop and then through the rest, never straight
  to the goal; a stop that cannot be reached halts the army with today's halt words (`blocked` or `no_way`), goal and `via` kept.
  The first season's allowance walks at once (R5); the rest walks one season at a time in the movement phase, as any standing
  march. P: a walk or a re-plan that skips a stop; an army that halts at a stop with points left.
- **R66 Reading a stop.** The events (`unit_moved` paths), the live walk, the replay and the report are those of one march; the
  report's "marches to" line names the goal. A stop reached on the season's last point is popped and the army waits there for
  the next season. P: a popped stop that is still on the route's next step.
- **R67 Deep fog.** A stop may be a hex the country has not discovered (R7); its legs' fog steps spend as any (R36), the preview
  marks "Unmapped land" on the leg that has one (the lines of R47 on the whole route), and every refusal and line names only
  what the country has discovered or sees (R57). Twin test extended to orders with `via`. P: a leg's refusal that names an
  unseen hex; a fog step in a leg taken as a normal one.
- **R68 The route stays drawn.** `MovePreview.stored` gives the remaining stops; `PathMarks` draws the stored route thin with a
  small marker on each remaining stop (a stop leaves the picture when it is popped); the army panel's order line reads "Marching
  to Pavia (10, 9) by Vercelli (6, 9), Novara (8, 9)" and `TileArmy`'s row likewise; a new command (a march with or without
  `via`, a halt) replaces it. A foreign army's stops are never shown (fog D8). P: a marker for a stop already passed; a stop shown
  on a foreign army.
- **R69 The computer.** No `AiKnow.act` call carries `via` and no file of `godot/core/ai/` names it (the door scan of
  `test_ai_door.gd` gains `"via"`); invariant I9 holds for every army of the AI. The AI may be given stops by a later task, not
  by this one (D35). P: a computer army with a non-empty `via`.
- **R70 Saves, log, replay.** `via` is in `army/3` (D31); the action log's `march` record carries it as hexes and `Replay.run`
  reads it back (MV19 proves the round trip through the log's JSON and fixes `Replay._hexes` or the log encoder only if the
  proof fails); staged stops are never saved. A format-7 file stays older (D22). P: staged stops that load; a log record that
  loses `via`.
- **R71 Determinism.** A multi-leg march is one action and one record, draws no luck in check or preview, and the game after a
  replay of a log with multi-leg marches has the live game's digest. P: a digest that differs between the live game and its
  replay.
- **R72 The words.** `MoveWords.of` gains the route shape: "The Army of Turin walks to Vercelli (6, 9) on its way to Pavia
  (10, 9) by Novara (8, 9): 8 of 12 move points left."; a stored one: "... sets out for Pavia (10, 9) by Novara (8, 9) at the end
  of next season."; a halt on sight keeps the line of R52 and the panel says "Halted" with Continue (the stops kept). Only seen
  or discovered places are named. P: a toast that names a stop out of sight.

---

## 4. Interfaces

```gdscript
# godot/core/state/army.gd (edit): SCHEMA "hexa-godot/army/3"
var points: int = 0                      # move points left this season (R12)
var season_from: Vector2i = NO_HEX       # where it stood when it first moved this season (R40)

# godot/core/systems/armies.gd (edit)
static func set_points(game: Game, army: Army, points: int) -> void      # clamps to 0..Allowance.full
static func close_season(game: Game) -> void                              # ready_units: moved_from = season_from; clear (R40)
# set_hex keeps season_from once set; clear_moved is deleted

# godot/core/systems/allowance.gd (new): class_name Allowance; OWNS []
static func full(game: Game, army: Army) -> int                           # Movement.mp_of
static func left(army: Army) -> int
static func fresh(game: Game, army: Army) -> bool                         # points == full and > 0
static func refill(game: Game) -> void                                    # ready_units (R13)
static func after_split(game: Game, parent: Army, fresh_army: Army, parent_before: int) -> void   # R15
static func after_merge(game: Game, into: Army, a_points: int, into_points: int) -> void          # R15
static func after_disband(game: Game, army: Army) -> void                                          # R15
static func check(game: Game) -> PackedStringArray                        # I1 lines, for the invariants

# godot/core/systems/march_leg.gd (new, MV1 refactor of MovementPhase): class_name MarchLeg
# The record of one walk (MovementPhase.Walk moved here, the same fields plus `points`, `seen_at_start`, `now`)
static func leg(game: Game, steps: StepCosts, army: Army, winter: bool, points: int) -> MarchLeg
static func step(game: Game, w: MarchLeg, k: int, occ: Dictionary) -> void          # one tick of one walk (MovementPhase._tick)
static func room(game: Game, walks: Array, by_id: Dictionary) -> void
static func apply(game: Game, walks: Array, memo: Dictionary) -> void

# godot/core/systems/walk_now.gd (new): class_name WalkNow; OWNS []
## {steps: int, from: Vector2i, to: Vector2i, stopped: StringName (&"" arrived, &"points", &"mustering", &"no_points",
##  &"winter", &"zoc", &"fog", &"sighted", &"blocked", &"shaken", &"enemy", &"battle"), text: String, points: int,
##  full: int, standing: bool, battle: int (record id, -1)}
static func walk(game: Game, army: Army) -> Dictionary

# godot/core/systems/movement.gd (edit)
const WHY_SIGHTED := &"sighted"           # joins HALT_WHYS
# march, continue_march, storm return {ok, reason, army, walk}
static func walk_season(map: MapData, steps: StepCosts, cur: int, route: PackedInt32Array, idx: int, mp: int,
		winter: bool, fresh: bool = true, fog: PackedByteArray = PackedByteArray()) -> Dictionary

# godot/core/systems/battles.gd (edit)
static func fight_now(game: Game, battle: Battle) -> int                   # the record id (R26); -1 for a draw by peace
static func armies_of(game: Game, battle: Battle) -> Array[Army]          # both sides, for R27

# godot/core/defs/game_defs.gd (edit)
@export var fog_step_cost := -1           # -1: all points, first step only (D9)

# godot/core/views/move_preview.gd (edit): to() gains
#  leg: {hexes: Array[Vector2i], cost, points_before, points_after, full, end: Vector2i, why: StringName}
#  risks: Array[{kind: StringName (&"battle" | &"enemy_land" | &"out_of_supply"), text: String}]
static func leg_of(game: Game, tag: StringName, army_id: int, hex: Vector2i) -> Dictionary   # the leg alone, cached with to()

# godot/core/views/move_words.gd (new): class_name MoveWords
static func of(game: Game, viewer: StringName, army_id: int, walk: Dictionary) -> Dictionary   # {text, tone}

# godot/core/views/replay_plan.gd (edit)
static func chain(records: Array[Dictionary]) -> Array[Dictionary]       # R50, pure

# godot/core/views/army_view.gd (edit): tokens() own entries gain points_left, points_full; panel() gains points

# godot/shell/autoload/events.gd (edit)
signal unit_moved(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray, ticks: PackedInt32Array,
		now: bool)

# godot/shell/map/move_replay.gd (edit)
signal live_finished(record: int)          # the battle record of the batch, -1 for none
func live_active() -> bool
func skip_live() -> bool

# godot/shell/map/map_armies.gd (edit)
signal battle_opened(record: int)          # an order's walk opened a battle: WarRequests opens the dock after the walk
```

```gdscript
# Multi-leg marches (MV19, section 3.11)
# godot/core/state/army.gd (edit): army/3 gains
var via: PackedInt32Array = PackedInt32Array()   # stops not yet reached, next first, the goal not in it (R64)

# godot/core/systems/armies.gd (edit)
static func set_order(game: Game, army: Army, order: StringName, goal: Vector2i, route: PackedInt32Array,
		via: PackedInt32Array = PackedInt32Array()) -> void           # the only writer of `via`

# godot/core/systems/movement.gd (edit): march_check / march read args["via"]: Array[Vector2i] (default empty)
static func legs_verdict(game: Game, army: Army, tag: StringName, via: Array[Vector2i], goal: Vector2i) -> Dictionary
#   {ok, reason, hexes (the joined route), legs: [{from, to, hexes}], via: PackedInt32Array}; goal_verdict gains `from: Vector2i`

# godot/core/defs/game_defs.gd (edit)
@export var max_stops := 6

# godot/core/views/move_preview.gd (edit)
static func via(game: Game, tag: StringName, army_id: int, stops: Array[Vector2i], hex: Vector2i) -> Dictionary
#   to()'s keys plus legs: Array[{from, to, hexes, cost, seasons, arrives_turn, fog}], stops: Array[Vector2i],
#   total: {cost, seasons, arrives_turn, legs}; stored() gains stops

# godot/core/views/move_words.gd (edit): of() reads walk.via_text; godot/shell/input/esc_ladder.gd: CLEAR_STOPS
# godot/shell/input/map_input.gd: signal waypoint_requested(map_px: Vector2); var waypoint_ready: Callable (an army of yours selected)
# godot/shell/map/map_armies.gd: add_stop(hex) -> bool, remove_last_stop(), clear_stops(), stops() -> Array[Vector2i]; command() reads them
# godot/shell/input/bindings.gd: action map_waypoint_key, key V
```

`unit_moved` events gain the key `now` (true for an at-once walk and for the retreats of its battle). Session's drain passes
it to the signal; `MapArmies._mark_dirty` takes one more optional argument.

---

## 5. A season, from the player's chair (north Italy, Spring 1481, Savoy at war with Milan)

1. The Army of Turin (pikemen, 12 move points) is selected. Its token shows a full points mark.
2. The pointer rests on Vercelli. The move card: "Walks 2 hexes now: 4 of 12 move points, 8 left." and the supply line. A
   right click: the army walks now (the token slides two hexes, the camera follows); the toast "The Army of Turin walks to
   Vercelli (6, 9): 8 of 12 move points left."; the panel says "8 of 12 left this season".
3. Pavia, five hexes on: "Walks 3 hexes now: 7 of 8 move points, 1 left." / "Stops at Cerano (7, 9) this season; walks on at
   the end of next season, there in Summer 1481." A right click: on the second step an army of Milan comes into sight at
   Novara. The walk stops at its hex with the points kept; the toast says so; the panel reads "Halted" with Continue.
4. The pointer on Novara (the Milanese army): "Attacks the Duchy of Milan: odds Even." and the risk "This opens a battle at
   Novara". A right click asks "Move the Army of Turin?" / "Move". The army walks, the battle is fought, the dock opens on
   the Battle of Novara, 1481 when the walk has played. The army's points are 0.
5. End season: the computer's seats play; Milan's other army, which sees the Army of Turin, marches on it and fights at once.
   The pill shows "Countries are moving"; after the phases the replay plays Milan's walks one after another, then the
   standing marches together; then the report, whose "Your armies" line reads "Army of Turin: Turin → Novara".

**Multi-leg (owner request 2026-11-25).** 6. The Army of Turin is selected. Shift+left click on Vercelli stages stop 1, Shift+left
click on Novara stage 2; the pointer rests on Pavia: one path runs Turin, Vercelli, Novara, Pavia with markers 1 and 2, the lines
"Leg 1: ... 1 season", "Leg 2: ...", "Leg 3: ..." and "Whole route: 3 legs, 14 move points, 2 seasons, there in Summer 1481", and
this season's walk as in step 2. Esc would clear the two stops; instead a right click on Pavia asks nothing (a plain route) and
orders the march: the army walks as far as its points reach, passes Vercelli without stopping, the toast says "... walks to Cerano
(7, 9) on its way to Pavia (10, 9) by Novara (8, 9)". The route stays drawn thin with the markers of the stops still ahead; at End
season the army walks on, and a marker leaves the picture when the army has passed its stop.

---

## 6. Saves, determinism and the replay of a season's moves

**What is stored.** An order is an accepted action, logged by `Game.act` as every action is (`{turn, action, args}`). The walk,
the battle and the retreat are consequences of the action and are not logged. The new state is two army fields (`points`,
`season_from`), saved in `army/3` and covered by the digest. A battle never stays open at idle in this build (D10), so the
battle body is unchanged (`battles/1`).

**Why FORMAT 8 (D22).** A format-7 body has `army/2` armies: read with defaults, its game's digest would differ from the header's
(the loader then says "The save is damaged"), and its action log, replayed, would walk where the old game stored orders. A clean
refusal ("Made by an older test build") is what the fog build did with format 6. No upgrade step; `OLDEST_FORMAT` 8.

**The determinism replay (`Replay.run`).** It plays the log in order through `Game.act`. A player's march walks, and may fight,
inside its act, from the same state, with the same `game.luck.world` state, so it does the same thing. At an `end_season` record
the season runs; its AI records are played by `LogOrders` through `Game.act` in the order they were logged (seat by seat), so the
AI's at-once walks and battles happen in the same order with the same draws; then the phases. Draw order = log order (D23), so
the digest after the replay equals the live one. Nothing in the replay or `LogOrders` changes. Two lines join the standard
(`godot-architecture.md`, the luck rule): a battle's days are drawn when it is fought, in the order of the acts; a check, a view,
a preview and a pause draw nothing.

**The picture of a season's moves (the shell).** Two kinds:
- **The player's own walks** play **live**, from the frame after the act (R49): the batch of that act (its walk, its battle's
  mark, the beaten side's retreat) on one `ReplayPlan`. The game already holds the end; the picture only moves tokens.
- **The computer's walks and the standing marches** are recorded while the season runs and played after it, as today, through
  `ReplayPlan.chain` (R50): first the at-once walks of `ai_orders` one after another in the order they were done (that is the
  seat order of the season), each with its battle mark and retreat, then the movement phase's walks together tick by tick. The
  6-second cap still bounds the whole.

**Tools.** `godot/tools/soak.gd --digest` prints the digests the refactor (MV1) must keep. `war_report.gd --armies=march` and
`perf_fixture.gd` order marches through `Game.act`, so those now walk their first leg when given: their tables are re-read in
MV16, and the perf rig's first season walks only what is left.

**Multi-leg marches (R70, R71).** One `march` record with a `via` list of hexes; the walk, the pops of the stops and the re-plans are
consequences of it and are not logged. The stops left are in `army/3` (`via`), so a save at idle keeps a half-walked multi-leg
march; the staged stops (shell only) are not saved. A save made while a live walk plays is saved after the walk (the game already
holds the end), with the stops that were left.

---

## 7. Seams

### 7.1 The battle board (#437)

The board replaces **how a battle's days are played**, not when a battle starts. What this build leaves for it:

| Seam | In this build | What #437 does with it |
|---|---|---|
| The one call that fights an at-once battle | `Battles.fight_now(game, battle)`, called by `WalkNow` (march and storm) only | Asks a board hook first (an `OrdersHook`-like object on `Game`, not saved): "auto" fights now as here; "board" leaves the battle open in `game.battles` and returns -1 |
| A battle open at idle | Never (I4) | Allowed for the player's own battles; `Season.end_check` refuses End season while one is open ("Finish the battle first"); the board's day actions (`battle_day`, `battle_auto` with their checks, the audit 4.2) |
| The save | `battles/1` already saves `game.battles` | `battle/2` (the start, `luck_before`, the orders so far; re-fought to the same day on load, the audit 4.4) and its format number |
| The dock after the walk | `MapArmies.battle_opened` -> `WarRequests.open_battle(record)` when the live walk ends (D21) | The same moment opens the dock in live mode on the open battle |
| Luck | `game.luck.world` in act order (D23) | Unchanged: a day is drawn when played; a pause draws nothing |
| Battles in End season (the computer attacks you in `ai_orders`; standing marches in the battles phase) | Fought automatically, as today | The flow pauses the computer's turn (an `AiTurn` step not done while a board battle is open) and the battles phase (`Season.run_to` / `run_from` of the audit) |
| Points | Every army that fought has 0 (R27) | Unchanged |

### 7.2 The economy (M9.5 and M10)

- **Arms (M9.5).** A raise needs arms; the raise rule here (join only a fresh army, R15) does not read goods, so the two do not
  meet. `TileArmy` rows carry both `points_text` (filled here) and `arms_text` (M9.5).
- **The save.** M9.5's economy-rethink names "FORMAT 7"; this build takes 8, so M9.5 takes the next number.
- **Supply.** The out-of-supply risk reads `SupplyView` at the leg's end; M9.5's markets and M10's trade change what feeds an
  army, not where the warning reads it.
- **Later movers.** Ships (M19) and caravans reuse `Allowance` with their own full points; `WalkNow` takes an army, so a ship
  walk is a new caller of `MarchLeg` on the sea mask, not a new rule.

---

## 8. Tests

All under `godot/tests/`. Every edited test keeps its planted faults; a task may not delete a P without replacing it.
`tests/core/moves_fixture.gd` (new, MV0): `standing(g, army, goal)` gives an army a standing march without walking it (state
edits in a test are allowed, as `WarFixture` does); `duel()` is `AiFixture.duel()` with Savoy and Milan
at war, a Savoyard army 3 hexes from a Milanese one and another Milanese army 2 hexes out of Savoy's sight; `thin()` is `duel()`
with Savoy thin at radius 2 (`FogFixture.thin`). `ArmyFixture.spent(g, army, points)` (MV2) sets an army's points.

### 8.1 New tests

| Test | Cases | Planted faults |
|---|---|---|
| `core/test_march_leg.gd` (MV1) | the refactor: every case of `test_movement_phase.gd` run through `MarchLeg` equals the phase; the soak digests of the PR | none new (refactor) |
| `core/test_allowance.gd` | full by the slowest company; refill in `ready_units`; split, merge, disband, raise (R15); clamps (R14) | R12 to R16 |
| `core/test_walk_now.gd` | R17 to R25 on `MovesFixture.duel()`: walks before the act returns; a second march with the points left; the standing rest; stored orders (R20); wade and the costly first step only fresh; room cut; blocked words in and out of sight; zone of control ends the season | each of R17 to R25 |
| `core/test_walk_battle.gd` | R26 to R31: a march onto the enemy fights in the act, the record kept, `game.battles` empty; both sides at 0 points; a refused contact; storm with and without points; the winner halted; luck unchanged by 1,000 checks and previews | each |
| `core/test_walk_sight.gd` | R32 to R35 at once and in the phase; zone of control wins; Continue does not stop again for the same army | each |
| `core/test_walk_fog.gd` | R36 to R39 on `MovesFixture.thin()`: a fog step only fresh; sight 1 against sight 2 pace over 4 seasons; `walk_plan` estimate; nothing on north Italy | each |
| `core/test_walk_twin.gd` (MV13) | R57: two games that differ only in armies Savoy does not see give equal `MovePreview.to` results (verdict, leg, risks, lines) and equal refusals for every order of Savoy's armies, on `duel()` and `thin()` | a leg end or a risk that moves with an unseen army |
| `core/test_walk_preview.gd` | R45 to R47: `leg` and `risks` for each `why` and each risk; the property: `leg` equals the walk over 200 seeded orders with no unseen army near | a leg that ignores the zone of control; a risk from an unseen army |
| `core/test_move_words.gd` | each toast of R52 | an army out of sight named |
| `core/test_season_from.gd` | R40: the report's lines after at-once and phase walks; J unchanged by a later walk | the two of R40 |
| `core/test_moves_replay.gd` | done-when 4: 20 seasons with player marches, at-once battles and the AI replay to the same digest; a save at idle mid-season loads to the same digest and plays on alike; save, load, save byte-equal (R55) | one changed march argument gives another digest |
| `core/test_replay_chain.gd` | R50: `ReplayPlan.chain` lays at-once walks one after another, retreats after their battle, then the phase's ticks | two at-once walks on the same ticks |
| `shell/test_live_walk.gd` | R49: the live batch plays, lands on the core hexes, never changes the game; skipped by an order, R, End season, F5, Space, Esc, a click; instant and reduce motion play nothing; the camera follows | an order refused during a live walk |
| `shell/test_move_confirm.gd` | R48: a confirm for each risk, none for a plain march, Cancel changes nothing, the setting off | an act before the answer |
| `shell/test_app_flow_moves.gd` | done-when 2 through the App headless: select, preview, walk, a second walk, a standing rest, the sighted halt and Continue, a battle and its dock, End season with the computer's walks replayed, the report's lines, F5 and F9 mid-season | as the steps |
| `core/test_march_via.gd` (MV19) | R63 to R66, R70, R71: the check and the act agree for `via` (a bad leg refused with its prefix, too many stops, a stop equal to its neighbour); the joined route; the walk passes a stop without halting; a re-plan goes through the next stop; a unreachable stop halts with the words and Continue resumes; `halt` once keeps and twice clears `via`; save, load, save equal; `Replay.run` of a log with multi-leg marches equals the live digest; the log's JSON round trip keeps `via` | each of R63 to R66 and R70 |
| `core/test_via_preview.gd` (MV19) | R59, R67, R68: legs, totals (the sum of the legs), seasons and arrival per leg; the whole route's `leg` and `risks`; the stored route's stops; the fog-safe words on `FogFixture.thin`; the cache by leg | a total that is not the sum; a skipped stop |
| `shell/test_waypoints.gd` (MV19) | R58, R60 to R62: Shift+left stages, again on the last removes, with no army selects, refused while the season replay runs; the digest and version never change before the commit; right click and O commit the staged route; a refusal keeps the stops; Esc clears all (ladder rung); a new selection, End season, load and a new game clear; `V` at the cursor; the card's "March" and "Clear stops"; the storm refused with stops | each |

### 8.2 Tests that move or change (and why)

| Test | Change | Why | Task |
|---|---|---|---|
| `core/test_movement_phase.gd` | the cases give their armies standing marches through `MovesFixture.standing` instead of `Game.act("march")`; "walks within its move points" uses the points left; "the zone of control ends the leg" also checks points 0; `unit_moved` keys gain `now` | `march` walks at once now, so the phase has nothing left to walk after an act | MV4 |
| `core/test_movement.gd`, `test_movement_worked.gd`, `test_halt_armies.gd`, `test_winter_armies.gd` | a march's first leg is walked by the act: the worked walks (Po bridge, Little St Bernard wait, Mont Cenis) assert the army's hex after the act equals the plan's first stop; the winter wait begins in the act | R5, R18 | MV4 |
| `core/test_movement_war.gd` | "a march onto an enemy army engages it in the tick" becomes "in the act, fought at once"; "a marching army caught in a battle keeps its march" now a standing-march case; "a storm that arrives starts an assault" at once | R26, R29 | MV4 |
| `core/test_battles.gd` | the phase cases stay; `fight_now` cases join; both sides at 0 points after a fought battle | R26, R27 | MV3, MV4 |
| `core/test_orders_armies.gd`, `test_season_armies.gd`, `test_standing_armies.gd`, `test_reminders_armies.gd` | the "marched" and "walked" lines of the report come from `season_from` | R40 | MV4 |
| `core/test_armies.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_war_save.gd`, `shell/test_session.gd` | `army/3`; FORMAT 8; a format-7 file older; the new refusals | R55 | MV2 |
| `core/test_move_preview.gd` | `leg` and `risks` keys; the route lines unchanged | R45 to R47 | MV5 |
| `core/test_replay_plan.gd`, `test_replay_battles.gd`, `test_replay_marks.gd` | the chained cases; the old cases (no `now`) unchanged | R50 | MV8 |
| `core/test_ai_war.gd`, `test_ai_war_aims.gd`, `test_ai_forces.gd`, `test_ai_play.gd`, `test_ai_owner.gd`, `test_ai_judge.gd`, `test_ai_peace.gd` | re-pinned where an at-once walk moves a later choice (an army no longer where the old test expected after its march; a battle already fought in the seat's turn); each re-pin with a comment "re-pinned for moves in the month: <reason>" | R9, R41 | MV11 |
| `core/test_ai_fog.gd` | the scene keeps Venice's moved armies outside every hex Milan's armies can walk to or see this season (so Milan's own walks reveal nothing that differs); a new case: once a walk reveals an army, the acts after it may differ, and the acts before it do not | at-once walks reveal land during the turn, which the old "whole turn equal" could not allow | MV13 |
| `core/test_ai_door.gd` | the scan gains `WalkNow`, `MarchLeg`, `MovementPhase`, `Allowance.` | R9 | MV11 |
| `core/test_check_contract.gd`, `random_player.gd` | Continue and storm weighted up; the contract unchanged | the do half now does more; the pair rule must still hold | MV4 |
| `core/test_invariants.gd`, `invariants.gd` | I1 to I8 | 8.4 | MV12 |
| `core/test_owns.gd`, `test_no_other_writers.gd`, `test_fog_views.gd` | `points` and `season_from` writers; `WalkNow` calls `Sight.see_path` (an existing entry point, no sixth writer); the fog views' walks through the fixture | R12, R19 | MV2, MV4 |
| `shell/test_move_replay.gd`, `test_season_replay.gd`, `test_replay_click.gd`, `test_move_replay_battles.gd` | the live mode beside the season mode; a click during a live walk skips it and acts (only the season replay refuses) | R49 | MV8 |
| `shell/test_order_toasts.gd`, `test_move_card.gd`, `test_map_input.gd` | `MoveWords` toasts; the leg lines; R on a halted march walks at once | R47, R52 | MV10 |
| `shell/test_app_flow_m6.gd`, `test_app_flow_m7.gd` | the march walks before End season (the army's hex after the order); the M7 flow's battle is fought at the order and the dock opens after the walk; the replay after End season shows only the computer's and the standing walks | R1, R8, R50 | MV10 |
| `shell/test_army_panel.gd`, `test_army_tokens.gd`, `test_army_tab.gd`, `test_army_flags.gd` | the points row, the token mark, `points_text` | R51 | MV9 |
| `shell/monkey_m6.gd`, `monkey_m7.gd` | the march step expects the army to have walked; "orders blocked" only during the season replay | R1, R49 | MV15 |
| `shell/test_map_input.gd`, `test_esc_ladder.gd`, `test_bindings.gd`, `test_help_overlay.gd`, `test_key_hints.gd`, `test_move_card.gd` | the Shift+left case, the `CLEAR_STOPS` rung, `map_waypoint_key` and the GESTURES lines, the card's staged buttons; the existing Shift+right storm cases unchanged | R58, R61, R62 | MV19 |
| `core/test_armies.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_owns.gd`, `test_no_other_writers.gd` | `via` in `army/3` and its refusals; its only writer | R64, R70 | MV19 |
| `core/test_check_contract.gd`, `random_player.gd` | `march` with a random `via`; the pair rule holds | R63 | MV19 |
| `core/test_walk_twin.gd`, `test_ai_door.gd`, `test_invariants.gd` | orders with `via` in the twin test; the scan gains `"via"`; I9 and I10 | R67, R69 | MV19 |
| `core/test_moves_replay.gd`, `shell/test_app_flow_moves.gd` | a multi-leg march in the 20 seasons; the multi-leg step of section 5 through the App, F5 and F9 with stops left | R70, R71 | MV19 for `test_moves_replay.gd`, MV18 for `test_app_flow_moves.gd` |

**Unchanged, must stay green:** `test_season.gd` (PHASES pinned), `test_replay.gd`, `test_war_property.gd`, `test_ai_turn.gd`,
`test_ai_determinism.gd`, `test_combat_*` and the bands test (the fight does not change), `test_sight.gd`, `test_knowledge.gd`,
the tile window's tests other than `test_army_tab.gd`.

### 8.3 Pictures

`godot/tools/ui/shot_ui_moves.gd` (new; 1280 x 720 scale 1 and 2560 x 1440 scale 2): a token with a full, a half and an empty
points mark; the move card with a leg and a standing rest; the move card with the three risks; the confirm; the army panel's
points row; a live walk mid-way (one still); the Army tab row with `points_text`. Goldens of M6 and M7 whose army panel or move
card changed are made again and signed. **The owner is asked before any windowed run.**

### 8.4 Monkey and invariants

**Invariants** (`tests/core/invariants.gd`, read by the soak every season and by the monkey after every act):
- **I1** every army: 0 <= points <= its full.
- **I2** no army spends more than its full points in a season: the step costs of its `unit_moved` paths of the season (recomputed
  with `StepCosts`, a wade or fog step counted as the points it had) add up to at most its full.
- **I3** points grow only in `ready_units` (never inside an act or another phase).
- **I4** `game.battles` is empty at idle.
- **I5** after every act: at most `stack_limit` companies of one country on a hex; no two countries on a hex outside a battle;
  no army on a hex it cannot stand on.
- **I6** a save then a load at idle gives the same digest (the monkey every eighth act; the soak every tenth season, as today).
- **I7** no `unit_moved` with `now` of the player's country is in the season replay's records.
- **I8** an army with a standing march and 0 points does not move in the movement phase.
- **I9** every army: `via` has at most `GameDefs.max_stops` entries, each a hex of the map, none while the goal is `NO_HEX`; every
  army of a computer country has an empty `via`; after each step of a walk the stops left are all still ahead on the route (the
  route's hexes contain `via` in order).
- **I10** (monkey) staging, hovering, removing and clearing stops never change the digest or the version; only the commit does.

`tools/soak.gd --plant=moves` (tests only) gives one army its points back in the middle of a season: I2 and I3 must catch it, print
the replay line and exit 1.

**Monkey** (`tests/shell/monkey_moves.gd`, extends `MonkeyTile`): selects own armies and gives several orders a season (right
click, O, R, Storm), answers the confirm both ways, skips live walks by clicks and keys, saves and loads mid-season, ends seasons.
Every frame: a live walk never changes the digest or the version; the token mark of a selected army equals its panel's points.
After every act: I1, I3, I4, I5, and the army's hex equals the walk's `to`. Counters `moves_walked`, `moves_second` (a second order
for an army in one season), `moves_standing`, `moves_confirms`, `moves_live_skips`, `moves_mid_saves` above 0 on every seed.

**Multi-leg step (MV19 gives the helpers, MV15 plays it):** with an own army selected the monkey Shift+clicks one to four stops
(including the pointer on the last stop, the same hex twice and water), presses `V` and Esc, commits by right click or O, and
sometimes saves and loads with stops left. Counters `moves_stops_staged`, `moves_stops_removed`, `moves_stops_cleared`,
`moves_via_committed`, `moves_via_saves` above 0 on every seed; I9 and I10 after every act and frame.

---

## 9. Performance

MV0 records the baseline of the existing rows; MV16 adds the new rows and measures all; both tables in MV16's pull request.

| Row | Class | Limit | Expected | Note |
|---|---|---|---|---|
| **new** `walk_now_ms` (`perf_core`) | cpu | 2.0 mean | about 0.5 | 200 seeded at-once marches on north Italy, 1 to 4 seasons of route, the plan cached, `Sight.refresh` included |
| **new** `walk_now_worst_ms` (`perf_core`) | cpu | 8.0 | about 2 | the worst of the same; it bounds one AI step (`ai_step_worst_ms` 8) |
| **new** `walk_battle_ms` (`perf_core`) | cpu | 20.0 worst | under 10 | an at-once march into an 8 against 8 enemy on north Italy: the fight, `BattleEnd.apply`, the flush and the sight, worst of 20; needs issue 427 fixed (MV3) |
| **new** `preview_leg_ms` (`perf_core`) | cpu | 2.0 | about 0.5 | `MovePreview.to` with `leg` and `risks`, cold, worst of 50 |
| `ai_season_ni_ms` | cpu | 200 | within 10 % of the baseline | the computer's marches now walk and fight in `ai_orders` |
| `ai_step_worst_ms`, `ai_seat_ms` | cpu | 8, 50 | as today on north Italy | a step with an at-once battle is the risk (section 10) |
| `movement_ms`, `army_phases_ms`, `season_ms` | cpu | as today | lower | the phase walks only standing marches |
| `battles_ms` (issue 427) | cpu | 20 | within the limit after MV3 | the same cause as `walk_battle_ms` |
| **new** `live_walk_frame_ms` (`perf_ui`) | cpu | 2.0 | under 0.5 | one frame of a live walk with a battle mark and a retreat, mean of 30 (as `replay_frame_ms`) |
| **new** `move_confirm_push_ms` (`perf_ui`) | gpu | 16 | under 8 | the confirm pushed cold and drawn |
| `route_hover_ms`, `tokens_refresh_ms`, `army_panel_open_ms` | as today | as today | unchanged within 5 % | the leg, the points mark, the points row |
| **new** `preview_via_ms` (`perf_core`) | cpu | 4.0 | about 1.5 | `MovePreview.via` with 5 staged stops and a new pointer hex, the staged legs cached, worst of 50; cold (all 6 legs) at most 12 |
| **new** `march_via_ms` (`perf_core`) | cpu | 6.0 worst | about 2 | `march_check` then `march` with 6 stops on north Italy (7 route searches), worst of 50; one AI step is unaffected (the AI sends none) |

Fallbacks: past `walk_now_worst_ms`, `Sight.refresh` becomes an incremental `Sight.moved(game, army, from)` (the walker's disc out,
its new disc in, per-country counts kept in `SightCache`); past `walk_battle_ms` after MV3, the battle end's area and control
caches are dropped once per act instead of once per battle; past `preview_leg_ms`, the leg reuses the plan's `walk_plan` first
stop and computes the risks only for the hovered hex; past `preview_via_ms`, the preview computes the legs behind the pointer's hex only on a pause of the pointer (the staged legs stay cached); past `march_via_ms`, `legs_verdict` plans the legs from one shared cost field per leg start.

---

## 10. Risks

- **A battle on a click freezes the window.** Issue 427's 1.7 s a battle on the war rig. MV3 fixes it first, with
  `walk_battle_ms` as the gate; north Italy is smaller, but the Europe map is not.
- **The computer's turn gets slower and lumpier.** Each march walks and may fight inside one AI step. `walk_now_worst_ms` and
  `ai_step_worst_ms` watch it; a battle step past the frame budget is visible as one long frame of the pill.
- **The player's first move.** The player strikes before the computer can move away; the computer answers at End season. With
  fair warning AI-only (D24), a player can declare war and attack in the same click-season while the defender cannot answer:
  Q1.
- **Stop on sight changes End season's marches.** Standing marches that see a new enemy now halt instead of walking into it; the
  AI re-orders every season, the player gets a halt to answer. The soak's war ranges (battles a season, wars lost) are read
  again by the systems designer (MV11).
- **The route finder knows the fog.** Orders into deep fog are planned on the real map (R38): a ridge the country never saw
  shapes its route. Accepted by owner answer 6's "may be ordered"; the final deep-fog rule may change it.
- **The deep-fog default reads oddly.** A hex in sight but never mapped (in sight, not explored) costs a whole season: the preview
  line names it ("Unmapped land"). The owner will set the final rule.
- **Two engines in disguise.** `WalkNow` and the phase share `MarchLeg` (D2); MV1 is a pure refactor proved by digests, so later
  differences are rules, not drift.
- **The fog test of the AI.** At-once walks reveal land mid-turn; the rewritten `test_ai_fog.gd` keeps the hidden facts out of
  reach of this season's walks (8.2).
- **Many tests move at once.** Every edited test keeps its planted faults; the changed tests are listed with their reason.
- **A stop is a place to pass, not to stop** (D29). A player who expects the army to wait at each stop will see it walk on; the
  card says "passes", the toast and the markers show it; a "halt at stops" option is not built (an owner question only if asked).
- **Shift+left click is new on the map.** Every other Shift use was checked (R62); the click only means something with an army
  selected, so a player who holds Shift for fast pan or the works card and clicks with an army selected stages a stop. The key
  list and the gesture lines say so; Esc clears.
- **Route search cost.** Up to 7 searches per check and per hover; the legs are cached and the perf rows gate it (section 9).
- **`army/3` is edited after MV2.** If a FORMAT 8 build has shipped when MV19 starts, the format becomes 9 (D31).
- **Reload to retry the dice.** Accepted by the owner (the design's answer 7 of 2026-11-24).

---

## Appendix A. Amendments to earlier specs

These sections are amended by this page; the old pages stay as written.

| Spec | Section | Amendment |
|---|---|---|
| m6-build-spec.md | 4.4 (the leg, "what is left over is lost"), 4.7 (march: an order), 4.10 (movement phase: every marching army), 5.0 R1, 6.3, 6.4 (the replay of the season), 6.10 (order toasts) | The march walks at once (R1, R17); the phase walks standing marches with points (R22); the leg uses points left (R18); `moved_from` by `season_from` (R40); the live walk (R49); `MoveWords` toasts (R52) |
| m6-build-spec.md | D21, D40 (zone of control ends the leg) | Also ends the season: points 0 (R25) |
| m6-build-spec.md | raise joins an army that does not march | Only a fresh one (R15) |
| m7-build-spec.md | 4.6 (a battle starts in the movement phase, is fought in the battles phase), 4.8 (apply: "a winner goes on next season"), 6.4, 6.8 | At once for orders (R26); the phase path stays for standing marches; the winner halted as the code has it (D12, R30) |
| m8-build-spec.md | 4.2 (`ai_orders`: orders executed by the movement phase), 4.10 (the AI's march), 8.1 | The AI's marches walk at once (R9, R41); perf rows of section 9 |
| fog-build-spec.md | R8 (growth by the movement phase), R32 (refusal words) | At-once walks explore their steps too (R19, D27); the blocked words fog-safe in the phase as well (R24) |
| tilewin-build-spec.md | R21 (`points_text` optional) | Filled (R51) |
| ui-family-audit.md | 4.3 way 3, 4.4 (the save of a battle at idle), 5.1 (U2's trigger) | Section 7.1: the trigger is `fight_now`; no battle is open at idle until the board |
| moves-in-the-month.md | 2.5 (Option A switch), 2.8 (deep fog refused), 3 ("the save format goes up once for both"; "behaviour oracle") | D25; owner answer 6 and D9; FORMAT 8 now, `battle/2` with #437; no Godot oracle (Appendix B) |
| ui-and-controls-spec.md | 3.3 (the Esc ladder), 4.1 (the pointer actions), the key table | A rung `CLEAR_STOPS`; Shift+left click with an army selected stages a stop; the key `V` (R61, R62) |
| m7-build-spec.md | 6.1 (Shift+right click storms) | Unchanged; refused while stops are staged (R60) |

## Appendix B. Where the design and today's code disagree

| # | The design says | The code does | This build |
|---|---|---|---|
| 1 | A battle exists only between the movement and battles phases, so the battle record must now be saved (`battle/2`, one format bump for both) | `game.battles` is already in the save (`battles/1`), empty at idle | Fought in the act, nothing is open at idle: no `battle/2` now; FORMAT 8 is for `army/3` only (D10, D22) |
| 2 | After a battle the rest of the winner's standing march continues in later seasons (and m7-build-spec 4.8: "an army in a battle keeps its march order") | `Battles._step_in` sets order none (goal and route kept); the winner must Continue | Today's code kept (D12) |
| 3 | Raising: a new company is not given to an army that has already moved | `Military.raise` joins the first army on the hex that does not march | Changed (R15) |
| 4 | Orders into never-discovered land are refused (2.8; replaced by owner answer 6) | No discovery gate: undiscovered goals are accepted and routed on the real map, at normal cost | The fog step penalty (D9) |
| 5 | A blocked step onto an unseen army at peace gives the check's words "another country's army stands at ..." | The phase's `_cut` names the country whatever the sight | Fog-safe words in both walks (R24) |
| 6 | The behaviour oracle is turned off and re-based by hand | The oracle (`tools/same_behaviour.py`) is the frozen Python game's; the Godot game has none | The proofs are the replay and digest tests, the soak and MV1's digest comparison |
| 7 | Fair warning keeps the player from being struck in the season a war begins, and "the AI defender already has its turn before the walks" (M8 D23) | Fair warning is the AI's rule only; under at-once moves the defender has no turn before the player's walk | Q1 |
| 8 | Points are given back in the calendar step | The season's refills are in `ready_units` (after `calendar`) | `ready_units` (R13) |
| 9 | The season report and its "moves" are not discussed | `moved_from` is cleared at the movement phase's start, so at-once walks would vanish from the report | `season_from` (R40) |
| 10 | Sight is refreshed for the moved army only | `Sight.refresh` rebuilds the army part of every country | Whole refresh at the walk's end, incremental only as the perf fallback (D26) |
| 11 | (Owner request 2026-11-25) "Shift+left on the map is free" | Shift+left click is the select click with a modifier that is ignored (`MapInput._on_unit` only skips tokens); it is free as a gesture and with no army selected stays a select | Shift+left stages a stop only while an army of yours is selected (R58) |
| 12 | "The army marches leg by leg, the first leg at once, the rest per month" | `march` takes `{army, goal}` and stores one route; the re-plan goes to the goal | One longer route through the stops, walked as every route is (D29, R65); `via` in `march` and in `army/3` (D30, D31) |
