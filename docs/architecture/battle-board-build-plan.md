# Battle board build plan: battles played day by day on a board (issue 437, with 438)

Technical director, 2026-11-25. **Status: a proposal; nothing starts before the owner's go; no build task before the
mockups (BB0) are approved and the open questions of section 9 (3 and 5 to 10, each with its recommendation as the default)
are answered; the owner answered 2 and 4 on 2026-11-25, and 1 on 2026-11-26 and 2026-11-27: version 1 is watch only, and
battles should aim for about 10 rounds.** Builds
`docs/architecture/battle-board-build-spec.md` ("the spec").

**When it runs.** After the moves build (issue 432, `docs/design/moves-in-the-month.md`; the owner's answer 6: decide 432
before the board; confirmed on 2026-11-25: moves ships first, and until the board exists battles are fought automatically). Group A may start once the moves build's spec is approved, because it touches only the fight and the
season's battles phase; group B and the later groups wait until the moves build has merged its walk and its `Battles.engage` call at idle
(the spec's section 3.6). Before M9.5 and M9. It changes no balance number: with default orders every fight is M7's
(the spec's done-when 2), so the board itself moves neither the AI, the soak nor the bands. **The one exception is BB15**
(proposed), the retune to about 10 rounds (spec 1.3, D24), which does move them and lands before BB1. The build changes the
save format (spec R45).

**Task IDs** are `BB0` to `BB15`. **The sizes below were set before the watch-only cut** (no fills, targets or stance
switch) and are not re-estimated; BB1, BB4, BB6 and BB9 should come out smaller, and BB15 is not sized yet.

---

## 1. Groups, effort, order

S is about half a day of one worker, M a day, L two days.

| Group | Ships | Tasks | Effort |
|---|---|---|---|
| **Gate. The mockups** | five mockups approved by the owner (spec Appendix B); the answers of section 9 (3 and 5 to 10) | BB0 | 1 M |
| **Before A. The pace (proposed)** | battles of about 10 rounds, measured and pinned | BB15 | not sized |
| **A. The fight's seam** | the split of `Combat` with orders, the identity proved over 500 seeds; the battles phase sliced; the perf baseline | BB1, BB2, BB3 | 1 L, 1 M, 1 S |
| **B. The live battle** | `battle/2`, `BattleLive`, the two actions, the guard, the wait in the phase | BB4 | 1 L |
| **C. Saves, views, widgets** | the save and the replay; `BattlePlan`, `BattleMatchup`, `BattleRound`, `of_live`; the dock's parts as shared widgets | BB5, BB6, BB8 | 1 L, 2 M |
| **D. The flow and the board** | Session's wait, the BATTLE state, the Options entries and the End-turn question; the board screen (a window over the map) | BB7, BB9 | 2 L |
| **E. Openers, soak, perf** | every way in; the `orders` soak suite; the perf rows | BB10, BB12, BB13 | 2 M, 1 S |
| **F. Proofs and finish** | the monkey; pictures, goldens, docs | BB11, BB14 | 2 M |

**Total without BB15: 15 tasks: 5 L, 8 M, 2 S**, about 19 worker-days; about 11 working days end to end (each group as long
as its longest task), plus reviews and the owner's playtest (an upper figure after the watch-only cut).

```
owner's go, mockups approved (BB0), section 9 answered
  -> BB15 (proposed: the 10-round retune, before BB1 records its digests)
  -> A:  BB1 (L)  BB2  BB3 (S)                   (A may start before the moves build lands; it touches no file of it)
  -> moves build merged (walk and engage at idle)
  -> B:  BB4 (L)
  -> C:  BB5  BB6 (L)  BB8
  -> D:  BB7 (L)  BB9 (L)
  -> E:  BB10  BB12 (S)  BB13
  -> F:  BB11  BB14   -> the owner plays the checklist of section 5

Critical path: BB15 -> BB1 -> BB4 -> BB6 -> BB9 -> BB10 -> BB11 -> BB14
```

A group starts when every task of the group before it is merged. Inside a group no two tasks touch one file and no task
calls code another task of its group writes. Shared fixtures have one owner: `tests/core/combat_fixture.gd` BB1 (it gains
the 500-seed digest fixture); a new `tests/core/board_fixture.gd` (player armies next to enemy armies at war, three
battles by hex index, an assault, a narrow ground, a lone garrison) BB4; `tests/core/fog_fixture.gd` is only read. New
`Tokens` entries: none expected (the dock's tokens serve); if the mockup needs one, BB8 adds it.

---

## 2. Tasks

*Sonnet* builds the core, the views, the flow, the board, the openers and the soak suite; *Haiku* builds the perf rows,
the monkey and the pictures. The technical director (Opus) reads BB1, BB2 and BB4 before they merge (the luck seam).
**Every task's done-when includes: lint (`python tools/lint_godot.py godot`), check_scripts, GUT, both UI `--check`s and
`build_tile_tabs.gd --check` green; `test_combat_bands.gd` and the AI tests unchanged and green; no planted fault (P) of an
edited test deleted without a replacement; no game window opened without the owner's go.** Paths without a prefix are
under `godot/`; `tools/`, `docs/`, `README.md` at the repository root.

### Gate

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| BB0 | M, the planning session's designer (Sonnet), the art director and the creative director review | **The mockups** | artifact pages, linked from the spec's Appendix B (no repository file) | MK1 and MK3 to MK6 made (MK2, the line-up choosers, is dropped) at 1280 x 720 with a 2x crop, one battle throughout, code-drawn look, Studiolo tokens; reviewed; **approved by the owner**, his choices written into the spec (D4, D19, D23; D1, D5, D18 and D24 are decided) |

### Before group A (proposed; waits for question 7)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| BB15 | not sized, Sonnet (systems designer measures and signs) | **Battles of about 10 rounds** | edit `data/defs/war.tres` (hit bases, flat morale drains, `battle_days`), `data/defs/units/*.tres` (`fire_permille`), `core/defs/war_def.gd` (`MAX_BATTLE_DAYS`), `core/state/battle_record.gd` (`MAX_DAYS` and its load checks), the odds words' bands, `tests/core/test_combat_bands.gd`, `test_combat_props.gd`, `test_war_defs.gd` and the other pins it moves, `tools/soak_ranges.gd` | Spec 1.3: the mean and spread of battle length from `war_report.gd` and `probe_calibrate.gd` before and after, in the pull request; the typical battle near 10 rounds and few at the cap; men lost per battle near today's; bands, odds words, soak and AI ranges measured again and signed; every moved pin listed with the reason; the save format checked (more frames a record) |

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| BB1 | L, Sonnet (technical director reads) | **The fight's split and the Withdraw order** | edit `core/systems/combat.gd`, `combat_day.gd` (withdraw `>=`), `combat_state.gd` (the day's orders); new `core/systems/combat_orders.gd`; edit `core/state/battle_record.gd` (`orders`, `battle-record/2`); edit `tests/core/combat_fixture.gd`; new `tests/core/test_combat_split.gd`, `test_combat_orders.gd`; edit `test_combat.gd`, `test_combat_props.gd`, `test_combat_hostile.gd` | **First commit:** the 500-seed digests (frames, end, luck state) recorded from the unsplit M7 code, on BB15's numbers, into the fixture. Then spec R1, R2 and R5 to R7: the digests equal after the split (P: one extra draw a day); each refusal of R6 (P each); Withdraw on days 2, 3, 7; the record's orders replay (P); `test_combat_bands.gd` untouched by this task and green; `fight_ms` measured once, within 5 % of BB3's baseline |
| BB2 | M, Sonnet (technical director reads) | **The battles phase sliced, the battle hook** | edit `core/systems/battles.gd` (`season_begin`, `season_step`, `season_end`; `season` built on them), `core/game/season.gd` (`run_phase(&"battles")` through the steps); new `core/game/battle_orders.gd`, `core/game/log_battle_orders.gd`; edit `core/game/game.gd` (`battle_orders` field only); new `tests/core/test_battle_phase.gd`; edit `test_battles.gd`, `test_season.gd` | Spec R18, R19 (the base hook and the log hook on a synthetic log), R21: the sliced phase equals the atomic one on the war rig's seasons (digest, P: a step that fights two); storms engage once (P); hex order kept (P); no behaviour change: the soak's quick suite gives the same digests as before |
| BB3 | S, Haiku | **The perf baseline** | none changed; numbers in the pull request | `fight_ms`, `battles_ms`, `battle_view_ms`, `season_ms`, `save_ms`, `load_ms` (`perf_core`) and `battle_dock_open_ms`, `dock_day_step_ms` (`perf_ui`) run twice on master, the medians in the pull request as the build's baseline |

### Group B (after A, and after the moves build's walk and engage at idle are merged)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| BB4 | L, Sonnet (technical director reads) | **The live battle** | edit `core/state/battle.gd` (`battle/2` fields, `to_dict`, `from_dict`, `digest_text`); new `core/systems/battle_live.gd`; edit `core/game/actions.gd` (`battle_day`, `battle_auto`), `core/game/game.gd` (`season_stage`, `check` asks `BattleLive.guard`, digest), `core/game/season.gd` (`end_check` refuses with a live battle), `core/systems/battles.gd` (`season_step` waits through the hook; the moves build's `fight_at` call, if it added one, now calls `BattleLive.fight_at`); edit `tests/core/invariants.gd`, `test_owns.gd`, `test_no_other_writers.gd`, `test_invariants.gd`; new `tests/core/board_fixture.gd`, `test_battle_live.gd`, `test_battle_actions.gd`, `test_battle_season_wait.gd` | Spec R8 to R17, R20, R22, R46: the guard over every name of `Actions.NAMES` (P); input and luck frozen on day 1 (P); rebuild equals and the mismatch ends a draw (P); one function plays a day (P); the pair property over 200 seeded orders (nothing, Withdraw, illegal ones); the wait draws nothing (P); the AI march into the player's army fights nothing before the phase (P; with a standing march of the movement phase if the moves build's computer at-once march is not merged yet); D17's lone garrison fought at once; `season_stage` has one writer |

### Group C (after B, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| BB5 | M, Sonnet | **Saves and replay** | edit `core/systems/battles.gd` (the `battles/2` body: its cross-checks of a live battle), `core/game/snapshot.gd` (`season_stage`), `core/game/save_file.gd` (FORMAT, OLDEST_FORMAT), `core/game/replay.gd` (`LogBattleOrders` in `end_season`, the index after it); new `tests/core/test_battle_save.gd`; edit `test_replay.gd`, `test_save_file.gd`, `test_war_save.gd` | Spec R8's load checks (P each), R23, R45: byte-equal save, load, save at idle day 3 and in the wait at days 0 and 2 (P); the previous format refused quietly (P); a log with battle orders at idle and in season replays to the same digest (P: a doubled record); the FORMAT number agreed with the moves build (D20) and written in the pull request |
| BB6 | L, Sonnet | **The board's read models** | new `core/views/battle_plan.gd`, `battle_matchup.gd`, `battle_round.gd`; edit `core/views/battle_view.gd` (`of_live`; the round in the dock's model); new `tests/core/test_battle_plan.gd`, `test_battle_matchup.gd`, `test_battle_round.gd`, `test_battle_door.gd`; edit `test_battle_view.gd` | Spec R24 to R30 and section 5: the Withdraw option agrees with `CombatOrders.check` (P); no coming enemy order (P); matchup words against the hit's factors over every branch pair and both fights (P); per-lane losses add up (P); prices follow a changed `WarDef` (P); `{}` for a witness (P); the door scan (P each); `battle_plan_ms` measured once headless, number in the pull request |
| BB8 | M, Sonnet | **The dock's parts as shared widgets** | new `shell/screens/battle/battle_field.gd`, `tug_bar.gd`, `day_log.gd`, `dice_row.gd`, `regiment_card.gd` and their tests; edit `shell/screens/battle_dock.gd` (uses them) | A refactor with no change to the dock: `test_battle_dock.gd` unchanged and green, the dock's goldens identical; the widgets take plain dictionaries (the dock's model), not the game; `RegimentCard` per spec R38's lines from `BattleMatchup.legend` read through the model; no `Color(` literal; the dock under 640 lines after |

### Group D (after C, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| BB7 | L, Sonnet | **The wait in Session, the BATTLE state, the Options entries, the End-turn question** | edit `shell/autoload/session.gd` (`BATTLE_ACTIONS`, `waiting_battle`, the wait in `finish_step`, `battle_waiting` from `drain`, the resume on load), `shell/autoload/events.gd` (`battle_waiting`, `battle_day_fought`), `shell/app/season_flow.gd` (BATTLE, the two replays, `open_board`, `battle_done`, the report count), new `shell/app/board_hook.gd`, edit `shell/app/settings.gd`, `shell/screens/options.gd` (the `battles` entry; the row "Battles at End turn" shown, built hidden by the moves build's MV21), `core/views/battles_at_end.gd` (`count` and `available`, from MV21), `shell/screens/auto_battles_ask.gd` (Yes sends `battle_auto`, No opens the board; MV21's widget), `shell/screens/pause_menu.gd` (Save allowed in BATTLE; the autosave skipped); edit `tests/shell/test_season_flow.gd`, `test_options.gd`, the settings test, `test_auto_battles_prompt.gd` (MV21's); new `tests/shell/test_battle_wait.gd`, `test_battle_prompt.gd` | Spec R43, R44, R47 with a fake board callable: the state walk RUNNING, REPLAY, BATTLE, RUNNING, REPLAY, DECISIONS, REPORT (P: a report before the battle); act refuses everything but the battle actions in the wait (P); save in the wait then load resumes at the waited battle without re-running movement (P); the Options' Auto sends `battle_auto` at idle and the hook wants nothing (P); the End-turn question: Yes sends `battle_auto` for each waiting battle in hex order, No opens the board, the box keeps the answer and Options sets it back to ask, no question with a count of 0 or with `auto` (P each) |
| BB9 | L, Sonnet | **The board** | new `shell/screens/battle_board.gd`, `.tscn`, `shell/screens/battle/orders_strip.gd` (the footer), `round_card.gd`, `result_card.gd` and their tests; edit `shell/screens/screen_ids.gd` (`battle_board`), `shell/input/bindings.gd` (the board's actions); new `tests/shell/test_battle_board.gd`, `test_board_tips.gd`, `test_board_sizes.gd` | Spec R31 to R33, R36 to R41 and R48 on the approved mockup (a window over the map and the dock column, no dock changed while it is up; no footer button for the other battles; watch only): opened in its tests by `open_live` on a fixture battle; Next round sends no order (P); Withdraw disabled on round 1 and sends the withdrawal from round 2 (P); Esc asks (P); the hover walk (P); every label 15 or more and inside the viewport at the four sizes and both themes (P); keys (P: Space reaching End season); reduce motion |

### Group E (after D, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| BB10 | M, Sonnet | **Every way in** | edit `shell/app/war_requests.gd` (`battle_waiting` and a live battle's `open_battle` push the board; the camera glide; the finished one the dock), `shell/app/app.gd` or `game_requests.gd` (the flow's `open_board` callable), `shell/panels/army_war.gd` ("Open the board"), `shell/panels/tile_tabs/land_facts.gd` (the live row), `shell/map/war_marks.gd` (a live badge), `core/views/reminders_war.gd` (the task flag line "Finish the Battle of X"); edit `tests/shell/test_army_panel.gd`, `test_town_tab.gd`, `test_war_marks.gd`, `test_task_flag.gd`; new `tests/shell/test_battle_flow.gd` | Spec R42 and the flow end to end headless: a march into an enemy army opens the board; three days and Auto; End season with a computer attack shows the walk, then the board, then the report; save in the wait and load; the Options' Auto; each opener reaches the board for a live battle and the dock for a finished one (P) |
| BB12 | S, Sonnet (systems designer reads) | **The `orders` soak suite** | edit `tools/soak.gd` (`--suite=orders`, a seeded random `BattleOrders` for one country: Withdraw on a random round, Auto sometimes), the nightly workflow's suite list | Spec 7.3: invariants every season on 10 seeds of 40 seasons; each game's log replays to its digest; the `ai`, `passive` and `europe` suites give the same digests as before BB1 (P: a planted extra draw in `play_day` fails the identity check); its war ranges in the pull request, read by the systems designer |
| BB13 | M, Haiku | **The perf rows** | edit `tools/perf_core.gd`, `tests/perf_core_budget.json`, new `tools/ui/perf_ui_board.gd`, edit `tests/perf_ui_budget.json`, `tools/ui/perf_ui.gd` | Spec 8: every new row added and within its limit; the "as today" rows within 5 % of BB3's baseline; both tables in the pull request; a row past its limit takes the spec's fallback in this task |

### Group F (after E, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| BB11 | M, Haiku | **The monkey** | new `tests/shell/monkey_board.gd`; edit `tests/shell/test_ui_monkey.gd` | Spec 7.4: invariants green on 3 seeds (one thin), counters above 0; a failure prints its replay line |
| BB14 | M, Haiku (art director signs) | **Pictures, goldens, docs** | new `tools/ui/shot_ui_board.gd`; the regenerated goldens of the army panel, the Town tab's battle row and the dock; edit `README.md` (the board, watching and Withdraw, Auto, the keys, the Options entries, the End-turn question), `godot/README.md`, `CLAUDE.md` (the Godot port rules' list where it names the battle dock), `docs/architecture/ui-and-controls-spec.md` (bindings), `docs/design/ui-family-audit.md` (status: section 4 built, the amendments of spec Appendix A), `docs/architecture/m7-build-spec.md` is **not** edited (spec Appendix A is the record) | Spec 7.5: **the owner is asked before the windowed run**; pictures at the three sizes signed against the approved mockups; changed goldens reviewed side by side; README in plain words matching spec R29's prices and R41's keys (watching, Withdraw, Auto) |

---

## 3. Tests that move

The full table is spec 7.2; by task:

- **BB15:** the bands, the props' day cases, the war defs and every other pin the 10-round retune moves.
- **BB1:** `test_combat.gd`, `test_combat_props.gd`, `test_combat_hostile.gd` call `fight` through the split and gain one
  hostile case per refusal; `test_combat_bands.gd` is **not edited by BB1**: it is the identity's witness.
- **BB2:** `test_battles.gd` (the phase through begin, steps and end), `test_season.gd` (the sliced battles phase equals
  the atomic one; PHASES unchanged).
- **BB4:** `invariants.gd`, `test_invariants.gd` (the live battle rules), `test_owns.gd`, `test_no_other_writers.gd`.
- **BB5:** `test_replay.gd`, `test_save_file.gd`, `test_war_save.gd`.
- **BB6:** `test_battle_view.gd` (`of_live`).
- **BB7:** `test_season_flow.gd` (BATTLE), `test_options.gd` and the settings test.
- **BB8:** `test_battle_dock.gd` unchanged and green (the refactor's proof).
- **BB10:** `test_army_panel.gd`, `test_town_tab.gd`, `test_war_marks.gd`, `test_task_flag.gd`.
- **BB11:** `test_ui_monkey.gd` gains the board monkey.
- **Unchanged after BB15, must stay green:** every AI test, `test_ai_determinism.gd`, `test_combat_bands.gd`, the soak's `ai`,
  `passive`, `europe` suites (same digests), `test_fog_views.gd`, `test_tile_*.gd`, `monkey_m7.gd`, `monkey_tile.gd`.

---

## 4. Monkey and performance

**Monkey (BB11).** `MonkeyBoard` adds one step and its invariants to the fog monkey (spec 7.4): marches into enemy armies,
legal and illegal orders (Withdraw on any round), Next round, Withdraw, Auto, Esc and both answers, saves and loads at
random dawns, End seasons that
bring the computer's attacks, the End-turn question answered both ways, the Options' entries switched. Invariants each frame: nothing but the battle actions while a
battle is live; Withdraw enabled exactly when the check allows it; the board shows the plan's numbers; the rebuilt
luck equals the world's; days 0 to `battle_days` and no more orders than days; save and load give the same digest and plan; the board
inside the viewport; no board without a live or waited battle. Counters `board_days`, `board_autos`, `board_saves`,
`season_waits`, `board_withdraws` above 0.

**Perf.** BB3 records the baseline; BB1 measures `fight_ms` and BB6 `battle_plan_ms` once each so the seams are chosen on
numbers; BB13 adds every row of spec 8 and runs all. A row more than 5 % slower than the baseline, or past its limit, takes
the spec's fallback in BB13's pull request.

---

## 5. Reviews and the owner's playtest

- **The code reviewer** reads every task; for BB1 it checks the digest fixture was made before the first code change (the
  commit order) and that `fight` has no second path; for BB4 the guard against every action name; for BB5 the byte-equal
  saves; for BB8 that the dock's goldens are identical.
- **The technical director** reads BB1, BB2 and BB4 before they merge (the luck seam), and reads this spec's section 3.6
  side by side with the moves build spec **before group A starts**: the computer's battles must not be fought at engage.
- **The systems designer** measures and signs BB15, then reads BB12's ranges and confirms the bands and the soak did not
  move after it.
- **The art director** reviews BB0's mockups and signs BB14's pictures; **the creative director** reviews BB0's mockups for
  fun (light to run, readable to watch, Withdraw's price clear) before the owner sees them.
- **Pull requests say what changes for the player:** BB15 makes every battle longer (about 10 rounds); otherwise nothing
  the player sees changes before BB9; BB10 turns the board on;
  BB5 makes older saves unreadable (said in its pull request and in the changelog of the release).

**The owner's playtest** (Windows, fresh user folder):

1. New game, Italy 1480, play as Savoy at war with Milan. March an army onto a Milanese army (the moves build's confirm
   appears first). A board window opens over the map at once: both armies, the odds word, the matchup words. The line-up is
   automatic; Withdraw is greyed on the first round with its reason.
2. Press Next round: the round card says what each lane lost and why ("your pikes held their knights: +25 %"); the dice
   show. Watch a few rounds; count how many a battle takes (the aim is about 10).
3. Hover every icon and number on the board: each explains itself; hover a regiment for its card.
4. From the second round, hover Withdraw (it names the price first), then choose it: the army leaves at the end of that round
   paying it.
5. Start another battle and press Auto to the end (one click): the result card at once; "Review in the dock" opens its days.
6. Press Esc in a battle: "Fight the rest automatically?"; Keep fighting returns to the board.
7. Save on round 3, quit, load: the same dawn; Next round gives the same round each time you reload (the dice are fixed by
   the save).
8. Press End season with your army next to Milan's: Milan's march plays, then the question "Fight your N battles
   automatically?" appears (No: the board opens inside the season; save there, load, finish it; the report counts your
   battles). With two battles, Yes runs both on Auto. Tick "Don't ask again" once and see the answer kept; Options' "Battles at
   End turn" sets it back to "Ask me".
9. Options: "Your battles: Auto": the next battle is only a toast with "Review" and the End turn asks nothing.
10. Look at BB14's signed pictures.

---

## 6. Definition of done

1. The spec's done-when items 1 to 6 hold.
2. BB1 to BB14 (and BB15, if question 7 keeps it) merged; CI green with the nightly `perf_core`, `perf_ui` and the soak
   (with `orders`) within limits; the
   `ai`, `passive` and `europe` soak digests unchanged.
3. Issue 437 closed by BB14's pull request, with the approved mockups and the signed pictures linked; issue 438's battle
   part marked done in the audit.
4. The owner has played section 5.

---

## 7. Risks

| Risk | Where it shows | Answer |
|---|---|---|
| The split changes the luck draws and moves every battle | BB1 | the 500-seed digest fixture from the unsplit code is the first commit; BB1 does not edit the bands test |
| The 10-round retune moves the balance of every war | BB15 | one data-led task before BB1, measured before and after; the systems designer signs it |
| The moves build fights the computer's battles at engage, breaking hex order and the bands | BB4, BB12 | spec 3.6 read side by side before group A; `test_battle_season_wait.gd`'s P; the soak identity |
| A live battle with no board soft-locks the game | BB7, BB10 | the guard's words name the battle; the task flag and the badge open the board; the monkey's invariant |
| The save in the season wait is a new path | BB5, BB7 | saves at days 0 and 2 of a wait in the tests; one resume function; a damaged stage refused |
| Two FORMAT bumps in one release (moves and board) | BB5 | D20: one bump when both ship together, agreed in BB5's pull request |
| The board is too big for 1280 x 720 with 8 companies a side | BB9 | R39's test with a full battle; the mockup at that size first |
| The triangle words read wrong | BB6 | computed from the hit's own factors, tested over every pair |
| Battles tire the player (about 10 clicks a battle) or watching feels passive | playtest | Auto, the End-turn question (Yes: all on Auto), the Options' Auto, D17; question 6 |
| Windowed runs needed for pictures | BB14 | the owner's go first; every other task is headless |
| The owner wants orders after all | later | version 1 is watch only (Q1 answered); the packages of `battle-orders.md` stay as later work on the same seam (spec Appendix C) |

---

## 8. Defaults taken (none blocks the build; the owner may change any before group D)

| Default | Alternative |
|---|---|
| Withdraw from the second round keeps today's price and conditions, and the army leaves at the end of that round (D10) | leaving at once, before the round is fought |
| One click a round (R33, R36; question 6) | the rounds play by themselves |
| One luck stream with the guard (D2) | a per-battle stream (re-bases the bands, the soak and the AI tests) |
| End-turn battles fought in the battles phase, the season pausing at yours (D6) | fight them at the start of your next turn (an asymmetry with the computer's battles) |
| Saving allowed in the End-turn pause (D7) | Save disabled until the season ends |
| Withdraw offered every round from the second with a retreat (D10) | Withdraw only at the end of day 2 (today's code) |
| Auto plays default orders and never withdraws (D11) | Auto follows a withdrawal rule |
| A lone garrison's battle is fought at once and reported (D17) | the board opens anyway |
| Witnesses see a battle only when it is over (D14) | a live view for witnesses |
| The board's text 15 logical or larger everywhere, lane labels included (R39) | 14 for lane labels |
| The computer's side keeps M7's fixed stance and usual picks (D9) | see question 3 |
| The board is a window over the shaded map, not the dock in live mode (owner answer 2026-11-25; D5, R48) | the dock in live mode, 420 px on the left |
| Several battles in one End turn: one question before they run, Yes all on Auto, No the board, with a "Don't ask again" box and an Options row (owner answer 2026-11-25; D18, D23, R47); each board keeps "Auto this one" | an "Auto the rest" button on each board |

---

## 9. Questions for the owner (design and scope only)

Questions 2 and 4 were answered on 2026-11-25 and are kept below as the record. Question 1 was answered on 2026-11-26 and
2026-11-27 and is no longer open. **Still open: 3 and 5 to 10**, each with its recommendation as the default.

**Answered on 2026-11-26 and 2026-11-27** (the former question 1, the orders of v1): version 1 is **watch only**: no
stances, no fills, no targets, no presets; the line-up is automatic; the player watches the rounds and may withdraw from the
second round; Auto stays one click; the board is still a window; battles should aim for about 10 rounds. The order packages
of `docs/design/battle-orders.md` are not chosen for v1 (spec D1, D10, D11, D24; Appendix C).

- **2. The board's place (mockup MK1). ANSWERED 2026-11-25: (b), a board window over the shaded map, like the Python battle
  panel.** The dock in live mode is dropped; the finished-battle dock stays the review (spec D5, R48).
- **3. May the computer withdraw in the middle of your battles too?** You may leave from the second round; today the computer
  leaves only by a defender's standing Withdraw at round 2. Options: (a) no, it keeps M7's fixed stance (results stay as
  measured); (b) a simple rule (leave when its front morale is under 30 % after the second round). **Recommend (a) for v1**
  and (b) after your playtest; (b) changes the measured bands.
- **4. Several of your battles in one End turn. ANSWERED 2026-11-25.** The owner's words: "Auto all battles at the end of turn
  is a hit. Ask before it runs all, with a notification that can be turned off." So the "Auto the rest" button idea is
  replaced: at End turn, when you have battles to fight, the game asks once "Fight your N battles automatically?" (Yes: all
  on Auto; No: play them on the board), with a "Don't ask again" box and an Options row that turns it back on; each board
  keeps its own "Auto this one" (Auto to the end). Spec D18, D23, R47; the setting and the widget are built earlier, by the
  moves build's MV21, and stay dormant until this build.
- **5. An Options entry "Your battles".** Options: (a) Play on the board (default) or Auto; (b) no entry, the board always
  opens; (c) three values with "ask only when the odds are not Hopeless or Overwhelming". **Recommend (a):** your rule is
  "play my battles, Auto one click away"; the entry costs little and helps a long war. (The End-turn question has its own row,
  "Battles at End turn": spec D23.)
- **6. How do the rounds advance while you watch?** (a) One click a round (Next round, or Enter). (b) They play by
  themselves, about a second each, with Pause, Next and Withdraw. **Recommend (a)** for v1: nothing moves while you decide
  whether to leave; (b) if ten clicks feel heavy in the playtest.
- **7. What exactly does "about 10 rounds" mean, and when is it done?** (a) A typical battle ends near 10 rounds, with a cap
  around 15; the retune is its own task before the board (BB15), by smaller hits and daily morale drains, so a battle costs
  about the men it costs today. (b) Every battle ends by round 10 at the latest (a cap of 10). (c) Retune after the board.
  **Recommend (a)** (spec 1.3).
- **8. Matchup words and the triangle legend on a watch-only board?** (a) Keep them: they explain who is winning and why.
  (b) Drop them, since nothing can be changed. **Recommend (a).**
- **9. A battle where you cannot withdraw** (an army with no hex to fall back to). (a) It opens on the board like any other;
  only a lone garrison is fought at once. (b) Every battle without a Withdraw is fought at once and reported.
  **Recommend (a):** watching is the point of v1.
- **10. Withdraw ends the battle with one click. Ask first?** (a) No extra box: the price is in the hover. (b) A short
  confirm naming the price. **Recommend (a)** (spec R36); (b) if the playtest shows misclicks.
