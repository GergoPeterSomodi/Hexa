# Moves build plan: moves in the month (issue 432)

Technical director, 2026-11-25. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/moves-build-spec.md` ("the spec"), which builds `docs/design/moves-in-the-month.md` as the owner answered it
(2026-11-24).

**When it runs.** After the tile window build (issue 436) closes, and **before the battle board** (issue 437, the audit's U2):
the owner's answer 6 of the UI family audit ("decide 432 before building the battle board"), and the board's trigger is the
seam this build leaves (spec 7.1). Both go before M9, whose peace terms make wars longer (the audit 5.1). M9.5 (the economy)
follows and takes the save format after 8 (spec 7.2). By the "fix issues first" rule, issue 427 (the battle end's cost) is fixed
inside this build, in group A, because a battle on a click depends on it.

**Task IDs** are `MV0` to `MV18`, and `MV19` (the owner's request of 2026-11-25, multi-leg marches: Shift+left click adds waypoints; spec 3.11, R58 to R72, D29 to D37).

---

## 1. Groups, effort, order

S is about half a day of one worker, M a day, L two to three days.

| Group | Ships | Tasks | Effort |
|---|---|---|---|
| **A. Foundations** | the fixture and the perf baseline; the walk engine split out (a pure refactor); the allowance and the save format; one battle fought at once, and issue 427 | MV0, MV1, MV2, MV3 | 1 S, 3 M |
| **B. The walk at once** | the march walks in the act, the standing march, battles and storms at once, `season_from`; the preview's leg and risks and the order words; points in the views | MV4, MV5, MV6 | 1 L, 1 M, 1 S |
| **C. The stops and the shell's picture** | stop on sight, the deep-fog step; the live walk and the chained season replay; the points on tokens and panels | MV7, MV8, MV9 | 1 L, 2 M |
| **D. The confirm, the computer, the proofs** | the confirm, the toasts, the dock after a battle, the setting and help; the AI re-pinned on the soak; the invariants; the AI fog test and the twin test; the preview property and the replay proofs | MV10, MV11, MV12, MV13, MV14 | 1 L, 4 M |
| **D2. Multi-leg marches** | stops staged by Shift+left click, the route through them previewed, ordered, stored, walked and drawn; the key `V`, the Esc rung, the card's buttons | MV19 | 1 L |
| **E. Finish** | the monkey, the perf rows, the pictures and docs, the App flow test | MV15, MV16, MV17, MV18 | 4 M |

**20 tasks: 2 S, 14 M, 4 L**, about 25 worker-days; about 11 working days end to end (each group as long as its longest
task), plus reviews and the owner's playtest.

```
tile window closed, owner's go
  -> A:  MV0 (S)  MV1  MV2  MV3                (MV1's digests and MV3's battle cost read by the technical director)
  -> B:  MV4 (L)  MV5  MV6 (S)                 (MV4 is the heart: code reviewer and technical director)
  -> C:  MV7 (L)  MV8  MV9
  -> D:  MV10  MV11 (L)  MV12  MV13  MV14      (MV11's soak tables: the systems designer's verdict before E)
  -> D2: MV19 (L)                              (after MV10: it edits the shell files MV10 edits; code reviewer and technical director)
  -> E:  MV15  MV16  MV17  MV18   -> the owner plays the checklist of section 5

Critical path: MV1 -> MV4 -> MV7 -> MV11 -> MV15 (MV10 -> MV19 -> MV15 runs beside it; MV19 is shorter than MV11, so the path stays)        (and MV3 -> MV4; MV5 -> MV10 -> MV18; MV8 -> MV10)
```

A group starts when every task of the group before it is merged. Inside a group no two tasks touch one file and no task calls
code another task of its group writes. Shared fixtures have one owner: `tests/core/moves_fixture.gd` MV0, `tests/core/army_fixture.gd`
MV2, `tests/core/invariants.gd` MV12 (MV19 adds I9 and I10 to it after MV12 has merged), `tests/fixtures/ui_sample.gd` MV17; a task that needs a helper in another's fixture asks
the planner and never edits it.

---

## 2. Tasks

*Sonnet* builds the core rules, the views, the AI, `Session`, the saves, the tools that touch the game and the shell; *Haiku*
builds only the monkey, the perf rows and the pictures. **Every task's done-when includes: lint (`python tools/lint_godot.py
godot`), check_scripts and GUT green, both UI `--check`s, `build_map --check`, `build_scenario.gd --check` and
`build_tile_tabs.gd --check`; no planted fault (P) of an edited test deleted without a replacement; no script over 800 lines
without a reason in `tools/lint_godot.py` (watch `movement.gd`, 765 today) and no function over 100 lines; no game window opened
without the owner's go.** Paths without a prefix are under `godot/`; `tools/`, `docs/`, `README.md` are at the repository root.

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| MV0 | S, Sonnet | **The moves fixture and the perf baseline** | new `tests/core/moves_fixture.gd` (`standing`, `duel`, `thin`), `tests/core/test_moves_fixture.gd` | Spec 8: `standing` gives a march order and route with no walk (P: a standing march that has moved the army); `duel` has the armies of spec 8 at the distances it says, Milan's second army out of Savoy's sight; `thin` is `duel` with Savoy at radius 2. The baseline of every row of spec 9 that exists today (`ai_season_ni_ms`, `ai_step_worst_ms`, `ai_seat_ms`, `movement_ms`, `army_phases_ms`, `season_ms`, `battles_ms`, `fight_ms`, `route_hover_ms`, `tokens_refresh_ms`, `army_panel_open_ms`, `replay_frame_ms`) run once headless on north Italy and the made-up Europe, the numbers in the pull request |
| MV1 | M, Sonnet | **The walk engine split out (refactor, no behaviour change)** | new `core/systems/march_leg.gd` (`MarchLeg`: the walk record of `MovementPhase.Walk`, `leg` with a `points` parameter defaulting to the full points, `step`, `room`, `apply` and their helpers, moved); edit `core/systems/movement_phase.gd` (keeps `season`, calls `MarchLeg`); new `tests/core/test_march_leg.gd` | Spec D2: every test of `test_movement_phase.gd`, `test_movement_war.gd`, `test_movement_index.gd`, `test_movement_worked.gd` green **unedited**; `tools/soak.gd --suite=ai --seeds=1-5 --seasons=40 --digest` and `--suite=passive --seeds=1-3 --seasons=20 --digest` print the same digests before and after (both lists in the pull request); labelled refactor; `movement_ms` within 5 % of MV0's |
| MV2 | M, Sonnet | **The allowance and save format 8** | edit `core/state/army.gd` (`army/3`: `points`, `season_from`, `to_dict`, `from_dict`, `digest_text`), `core/systems/armies.gd` (`set_points`, the `from_dict` checks, the digest), new `core/systems/allowance.gd` (`full`, `left`, `fresh`, `refill`, `after_split`, `after_merge`, `after_disband`, `check`), edit `core/systems/military.gd` (a new army's full points; raise joins only a fresh army; split, merge, disband call `Allowance`), `core/game/season.gd` (`ready_units` calls `Allowance.refill`), `core/game/save_file.gd` (`FORMAT` 8, `OLDEST_FORMAT` 8, the doc line), `tests/core/army_fixture.gd` (`spent`); new `tests/core/test_allowance.gd`; edit `tests/core/test_armies.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_war_save.gd`, `test_owns.gd`, `test_no_other_writers.gd`, `tests/shell/test_session.gd` | Spec R12 to R16, R55, D3, D14, D22: each P of `test_allowance.gd`; a format-7 header reads `older` (P: a 7 that loads); points above the full refused on load (P); save, load, save byte-equal on north Italy at turn 8 with spent points; nothing spends points yet (the walks come in MV4), so every movement test is unchanged |
| MV3 | M, Sonnet | **One battle fought at once; issue 427** | edit `core/systems/battles.gd` (`fight_now`, `armies_of`; `season` fights through the same private path), the battle end's hot spot found by profiling (`core/systems/battle_end.gd` or `core/systems/war_cache.gd`, whichever holds the cold cache); edit `tests/core/test_battles.gd` | Spec R26 (the call), D10: `fight_now` fights one battle, keeps its record, flushes and refreshes, and leaves `game.battles` without it (P: the battle still listed); the battles phase gives the same digests as before over the soak's 5 seeds (both lists in the pull request); `battles_ms` within its limit (20) on the war rig, or the measured cause and the remaining gap written in issue 427 and the pull request for the technical director's call; issue 427 closed or re-scoped |

### Group B (after A, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| MV4 | L, Sonnet | **The march walks at once** | new `core/systems/walk_now.gd`; edit `core/systems/movement.gd` (`march`, `continue_march`, `storm` call `WalkNow.walk`, their results; `walk_season`'s `fresh` parameter), `core/systems/march_leg.gd` (points left, fresh, `now`, the blocked words of R24, the zone of control ends the season, R27 after a fought battle, `season_from` through `set_hex`), `core/systems/movement_phase.gd` (standing marches with points only; no `clear_moved`), `core/systems/armies.gd` (`close_season`, `set_hex` keeps `season_from`, `clear_moved` deleted), `core/game/season.gd` (`ready_units` calls `close_season`), `core/systems/battles.gd` (R27 in the phase's fights); new `tests/core/test_walk_now.gd`, `test_walk_battle.gd`, `test_season_from.gd`; edit the tests of spec 8.2 marked MV4 (`test_movement_phase.gd`, `test_movement.gd`, `test_movement_worked.gd`, `test_movement_war.gd`, `test_halt_armies.gd`, `test_winter_armies.gd`, `test_orders_armies.gd`, `test_season_armies.gd`, `test_standing_armies.gd`, `test_reminders_armies.gd`, `test_battles.gd`, `test_fog_views.gd`, `test_check_contract.gd`, `random_player.gd`) | Spec R1 to R3, R5, R8 (core), R10 (core), R17 to R31, R40, D1, D4, D5, D10 to D13, D15: every case and P of the three new tests; every edited test keeps its P with the reason of spec 8.2; `test_replay.gd`, `test_war_property.gd`, `test_ai_turn.gd`, `test_ai_determinism.gd`, `test_season.gd` green unedited (the AI tests of MV11 may be red only where an at-once walk moves a pinned choice: listed in the pull request, fixed in MV11); `movement.gd` under 800 lines |
| MV5 | M, Sonnet | **The preview's leg and risks; the order words** | edit `core/views/move_preview.gd` (`leg`, `leg_of`, `risks`, the lines of R47 but the fog line), new `core/views/move_words.gd`; edit `tests/core/test_move_preview.gd`; new `tests/core/test_move_words.gd` | Spec R45 (the leg from `MarchLeg.leg` with the points left), R46, R47, R52 (the words), R57 (fog-safe): each `why` the leg can give from group A's code and each risk, with their P; `MoveWords.of` for each walk shape of spec section 4 (P: an army out of sight named); cached with `to` (no new cache key); `preview_leg_ms` measured once headless, the number in the pull request |
| MV6 | S, Sonnet | **Points in the views** | edit `core/views/army_view.gd` (`tokens`' `points_left`, `points_full`; `panel`'s `points`), `core/views/tile_army.gd` (`points_text`); edit `tests/core/test_army_view.gd`, `test_tile_army.gd` | Spec R51 (core): own armies only (P: points on a foreign token); the token's points are the lowest of its armies; the text "8 of 12 left this season" |

### Group C (after B, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| MV7 | L, Sonnet | **The walk's stops: sight and the deep-fog step** | edit `core/systems/march_leg.gd` (the seen set at the start, the sight test per step and per tick, the fog step), `core/systems/walk_now.gd` (the seen set of an at-once walk), `core/systems/movement.gd` (`WHY_SIGHTED` in `HALT_WHYS`; `walk_season` and `walk_plan` with the fog mask), `core/defs/game_defs.gd` (`fog_step_cost`, `validate`), `data/defs/game_defs.tres`, `core/views/move_preview.gd` (the `fog` leg and its "Unmapped land" line); new `tests/core/test_walk_sight.gd`, `test_walk_fog.gd`; edit `tests/core/test_economy_defs.gd` (the file that validates `GameDefs`' movement numbers), `test_move_preview.gd` | Spec R6, R7, R32 to R39, D6 to D9: every case and P of the two new tests, at once and in the phase; nothing changes on north Italy (P: a fog step there); the pace over 4 seasons of sight 1 and sight 2 on `MovesFixture.thin()` in the pull request |
| MV8 | M, Sonnet | **The live walk and the chained season replay** | edit `shell/map/move_replay.gd` (the live batch, `live_active`, `skip_live`, `live_finished`), `core/views/replay_plan.gd` (`chain`), `shell/autoload/events.gd` (`unit_moved` gains `now`), `shell/autoload/session.gd` (the drain passes `now`), `shell/map/map_armies.gd` (`_mark_dirty`'s sixth argument only), `shell/app/season_flow.gd` (End season skips a live walk first), `shell/app/game_requests.gd` (the live speed, F5, F9 and load skip it first), `shell/input/map_input.gd` (Space, Enter, Esc skip a live walk); new `tests/core/test_replay_chain.gd`, `tests/shell/test_live_walk.gd`; edit `tests/core/test_replay_plan.gd`, `test_replay_battles.gd`, `test_replay_marks.gd`, `tests/shell/test_move_replay.gd`, `test_season_replay.gd`, `test_replay_click.gd`, `test_move_replay_battles.gd` | Spec R49, R50, D19, D20: each P of the two new tests; a live walk never changes the digest or the version (P); instant and reduce motion play nothing; the player's live walks are not in the season replay (P); `live_walk_frame_ms` measured once headless |
| MV9 | M, Sonnet | **Points on the map and in the panels** | edit `shell/map/army_token.gd` (the points mark, tokens only), `shell/map/army_tokens.gd`, `shell/panels/army_panel.gd` (the points row), `shell/panels/tile_tabs/army_tab.gd` (only if `points_text` is not already shown when present); edit `tests/shell/test_army_tokens.gd`, `test_army_panel.gd`, `test_army_tab.gd`, `test_army_flags.gd` | Spec R51 (shell): the mark full, half, empty; none on a foreign token (P); the panel row equals `ArmyView.panel`'s text; no `Color(` literal; the art director looks at a headless picture of the three marks (no window) |

### Group D (after C, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| MV10 | M, Sonnet | **The confirm, the toasts, the dock after a battle, the setting and help** | edit `shell/map/map_armies.gd` (the risk check and the `Confirm` in `command`, R and Storm; `MoveWords` toasts in place of `_marches_words`; skip a live walk before an order; `battle_opened`), `shell/panels/army_war.gd` (the Storm button through the same confirm), `shell/app/war_requests.gd` (opens the dock on `battle_opened` after `live_finished`), `shell/app/settings.gd` (`game/confirm_moves`), `shell/hud/move_card.gd` (the leg lines' order and tones), `shell/screens/help_overlay.gd`, `shell/hud/key_hints.gd` (the help line); new `tests/shell/test_move_confirm.gd`; edit `tests/shell/test_order_toasts.gd`, `test_move_card.gd`, `test_map_input.gd`, `test_army_war.gd`, `test_app_flow_m6.gd`, `test_app_flow_m7.gd`, the settings and options tests | Spec R4, R8 (shell), R48, R52 (shown), R53, R54, D18, D21: each P of `test_move_confirm.gd`; Cancel changes nothing and toasts nothing; the setting off asks nothing; the dock opens only after the live walk (P); the two M6 and M7 flow tests green with the reasons of spec 8.2 |
| MV11 | L, Sonnet (systems designer decides) | **The computer moves at once** | edit `core/ai/ai_war.gd` (`_march`'s sighted retry), `core/ai/ai_forces.gd` (the same for its marches), `core/ai/ai_brief.gd` (only if `seen` needs a refresh function); edit `tests/core/test_ai_door.gd` (the scan), `test_ai_war.gd`, `test_ai_war_aims.gd`, `test_ai_forces.gd`, `test_ai_play.gd`, `test_ai_owner.gd`, `test_ai_judge.gd`, `test_ai_peace.gd` (re-pins only, each with its reason); a data edit of `data/defs/ai.tres` or the tempers only if the designer asks, with `tests/core/test_ai_defs.gd` | Spec R9, R41 to R44, D17: a sighted halt gets one retry and the AI acts on what it now sees (P); `test_ai_turn.gd` and `test_ai_determinism.gd` green unedited; 100 `ai`, 20 `passive`, 4 `europe` soak games hold every range of M8 4.17 or the designer sets new ranges with a written reason; the tables and the verdict in the pull request; `ai_season_ni_ms` and `ai_step_worst_ms` measured against MV0's |
| MV12 | M, Sonnet | **The invariants and the soak's plant** | edit `tests/core/invariants.gd` (I1 to I8), `tests/core/test_invariants.gd`, `godot/tools/soak.gd` (`--plant=moves`, tests only) | Spec 8.4: each invariant with its P; `soak --quick` green; `--plant=moves` prints its replay line and exits 1 |
| MV13 | M, Sonnet | **The AI fog test and the twin test** | rewrite the scene and add the case of spec 8.2 in `tests/core/test_ai_fog.gd`; new `tests/core/test_walk_twin.gd` | Spec R57, 8.2: the fog test green with its plants kept and the new case (acts before the first revealing walk equal, P: a step reading a hidden army's hex before it); the twin test over every order of Savoy's armies on `duel()` and `thin()` (P: a leg end that moves with an unseen army) |
| MV14 | M, Sonnet | **The cross-proofs** | new `tests/core/test_walk_preview.gd` (the property), `tests/core/test_moves_replay.gd` | Spec done-when 3 and 4, R45, R55, R56: `leg` equals the walk over 200 seeded orders with no unseen army near (P: a leg that ignores the zone of control, planted through a test seam); 20 seasons with player marches, at-once battles and the AI replay to the same digest; a mid-season save loads to the same digest and plays on alike; save, load, save byte-equal |

### Group D2 (after D)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| MV19 | L, Sonnet | **Multi-leg marches: Shift+left click adds waypoints** (GitHub issue "Multi-leg marches: Shift+left click adds waypoints to an army's route", 2026-11-25). Depends on MV2 (`army/3`), MV4 (`WalkNow`), MV5 (`MovePreview`), MV7 (fog and sight in `walk_plan`), MV10 (`map_armies.gd`, `move_card.gd`, the confirm, `MoveWords`) | edit `core/state/army.gd` (`via`: field, `to_dict`, `from_dict`, `digest_text`), `core/systems/armies.gd` (`set_order` takes `via`; the `from_dict` checks), `core/systems/movement.gd` (`march_check`, `march`, `legs_verdict`, `goal_verdict`'s `from`; `halt` clears `via` on the second halt; `continue_march` re-plans through the stops; keep the file under 800 lines by putting `legs_verdict` in `core/systems/march_via.gd`, new), `core/systems/march_leg.gd` (pop a stop on arrival; re-plan through the next stop), `core/systems/walk_now.gd` (pass `via` on), `core/defs/game_defs.gd` (`max_stops`, `validate`), `data/defs/game_defs.tres`, `core/game/replay.gd` and the log encoder only if the round-trip proof fails, `core/views/move_preview.gd` (`via`, `stored`'s stops, the leg cache), `core/views/move_words.gd` (the route shape), `core/views/tile_army.gd` and `core/views/army_view.gd` (the order line "by ..."), `shell/input/map_input.gd` (Shift+left click and `waypoint_requested`, `waypoint_ready`), `shell/input/bindings.gd` (`map_waypoint_key`, the four GESTURES lists), `shell/input/esc_ladder.gd` (`CLEAR_STOPS`), `shell/app/app.gd` (the ladder's state key and the new rung), `shell/map/map_armies.gd` (staging, `command` through the stops, the clears of spec R61), `shell/map/path_marks.gd` (stop markers), `shell/hud/move_card.gd` (the leg lines, "March" and "Clear stops"), `shell/hud/key_hints.gd`, `shell/screens/help_overlay.gd`; new `tests/core/test_march_via.gd`, `test_via_preview.gd`, `tests/shell/test_waypoints.gd`; edit the tests of spec 8.2 marked MV19, plus `tests/core/invariants.gd`, `test_invariants.gd` (I9, I10) and `test_moves_replay.gd` (a multi-leg march in the 20 seasons) | Spec R58 to R72, D29 to D37: every case and P of the three new tests; the check and the act agree for `via` (`test_check_contract.gd`); `via` in `army/3`, FORMAT unchanged at 8 (or 9, the planner says at the start: D31); the round trip of a `march` with `via` through the action log's JSON and `Replay.run` proved first, in the first commit; no file of `core/ai/` names `via` (door scan); Shift+left with no army still selects, Shift+right still storms; `preview_via_ms` and `march_via_ms` measured once headless, the numbers in the pull request; the staged stops never change the digest (test); lint rules of this plan's header. If the first pull request passes 1,500 changed lines, split into MV19a (core: `via`, the check, the walk, the preview, the three core tests) and MV19b (shell: the gestures, the key, the rung, the card, the markers, `test_waypoints.gd`), MV19b after MV19a |

### Group E (after D and D2, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| MV15 | M, Haiku | **The monkey** | new `tests/shell/monkey_moves.gd` (extends `MonkeyTile`); edit `tests/shell/test_ui_monkey.gd` (the moves step), `tests/shell/monkey_m6.gd`, `monkey_m7.gd` (the march step expects a walk; orders blocked only in the season replay) | Spec 8.4: the invariants green on 3 seeds (one thin), every counter above 0; the existing seeds green; plus the multi-leg step of spec 8.4 (counters `moves_stops_staged`, `moves_stops_removed`, `moves_stops_cleared`, `moves_via_committed`, `moves_via_saves`, I9 and I10) |
| MV16 | M, Haiku | **The perf rows** | edit `godot/tools/perf_core.gd` (`walk_now_ms`, `walk_now_worst_ms`, `walk_battle_ms`, `preview_leg_ms`), `godot/tests/perf_core_budget.json`, `godot/tools/ui/perf_ui.gd` or new `godot/tools/ui/perf_ui_moves.gd` (`live_walk_frame_ms`, `move_confirm_push_ms`), `godot/tests/perf_ui_budget.json`, `godot/tools/perf_fixture.gd` (the war rig's marches as standing marches where a row needs them walked in the phase); read `godot/tools/war_report.gd --armies=march` and `army_report.gd` once and note in the pull request what their tables now mean | Spec 9: every row within its limit against MV0's baseline, both tables in the pull request; a row past its limit takes spec 9's fallback in this task (Sonnet does the fallback's code if one is needed; the planner splits it off); plus the rows `preview_via_ms` and `march_via_ms` of spec 9 |
| MV17 | M, Haiku (art director signs) | **Pictures, goldens, docs** | new `godot/tools/ui/shot_ui_moves.gd`, edit `tests/fixtures/ui_sample.gd`; the regenerated M6 and M7 goldens whose army panel or move card changed (`godot/tests/goldens/`); edit `README.md` (the moves rules: points, at once, standing marches, stop on sight, the confirm, battles at once), `godot/README.md`, `docs/design/moves-in-the-month.md` (status line: built), `docs/architecture/godot-architecture.md` (the two luck lines of spec section 6), `CHANGELOG.md` | Spec 8.3: **the owner is asked before the windowed run**; pictures at both scales signed; every changed golden reviewed side by side; README text matches spec 3.0 to 3.5 in plain words; plus a picture of the move card with three staged stops and numbered markers, one of a stored route with its stop markers, and the README's controls table lines for Shift+left click and `V` |
| MV18 | M, Sonnet | **The App flow test** | new `tests/shell/test_app_flow_moves.gd` (with `tests/shell/app_flow_helpers.gd` read, not edited) | Spec done-when 2: each step of spec section 5 through the App headless, with F5 and F9 mid-season; plus a multi-leg step: Shift+left twice, the preview's legs, a right click, the walk past a stop, F5 and F9 with a stop left, Esc on staged stops |

---

## 3. Tests that move

The full table is spec 8.2; by task:

- **Rewritten scene:** `test_ai_fog.gd` (MV13): Venice's moved armies stay outside every hex Milan's armies can walk to or see this
  season; a new case shows that the acts before the first walk that reveals an army are equal, and allows the acts after it to
  differ.
- **Meaning changed (march walks at once):** `test_movement_phase.gd` (standing marches by the fixture, points), `test_movement.gd`,
  `test_movement_worked.gd`, `test_movement_war.gd`, `test_halt_armies.gd`, `test_winter_armies.gd` (MV4); `test_app_flow_m6.gd`,
  `test_app_flow_m7.gd`, `test_order_toasts.gd` (MV10); `monkey_m6.gd`, `monkey_m7.gd` (MV15). Each edited case says in a comment
  "moves in the month: <what changed>".
- **Words and keys only:** the report's army tests (MV4); `test_move_preview.gd` (MV5, MV7); `test_army_view.gd`,
  `test_tile_army.gd` (MV6); the replay tests (MV8); the token, panel and tab tests (MV9); the save tests (MV2).
- **Re-pinned behaviour:** MV11's AI tests, each with "re-pinned for moves in the month: <reason>".
- **Multi-leg marches (MV19):** new `test_march_via.gd`, `test_via_preview.gd`, `test_waypoints.gd`; edited `test_map_input.gd`,
  `test_esc_ladder.gd`, `test_bindings.gd`, `test_help_overlay.gd`, `test_key_hints.gd`, `test_move_card.gd`, `test_armies.gd`,
  `test_snapshot.gd`, `test_save_file.gd`, `test_owns.gd`, `test_no_other_writers.gd`, `test_check_contract.gd`, `random_player.gd`,
  `test_walk_twin.gd`, `test_ai_door.gd`; the cases for `test_moves_replay.gd`, `test_app_flow_moves.gd` and `test_invariants.gd` are
  written by MV19 itself in `test_moves_replay.gd` (MV14's file, merged before MV19), `test_invariants.gd` and `invariants.gd` (MV12's
  files, merged before MV19); `test_app_flow_moves.gd` gets its multi-leg step from MV18, the monkey its step from MV15.
- **Unchanged, must stay green:** `test_season.gd`, `test_replay.gd`, `test_war_property.gd`, `test_ai_turn.gd`,
  `test_ai_determinism.gd`, the combat tests and the bands test, `test_sight.gd`, `test_knowledge.gd`, the tile window's tests
  but `test_army_tab.gd`.

---

## 4. Monkey and performance

**Monkey (MV15).** `MonkeyMoves` adds one step to the tile monkey: select an own army, give one to three orders in the season by
right click, O, R and Storm (a second order to the same army on purpose), answer a confirm with Move or Cancel, skip a live walk
by a click or a key, F5 and F9 mid-season on some steps, end the season. Invariants: every frame, a live walk changes neither the
digest nor the version, and a selected army's token mark equals its panel's points; after every act, spec I1, I3, I4 and I5, and
the army stands where the walk said (`walk.to`). Counters `moves_walked`, `moves_second`, `moves_standing`, `moves_confirms`,
`moves_live_skips`, `moves_mid_saves` above 0 on every seed.

**Multi-leg monkey.** MV15 adds the multi-leg step of spec 8.4 to `MonkeyMoves`: Shift+clicks (also on water, on the army's hex, the
same hex twice), `V`, Esc, the commit by right click and O, a save and load with stops left.

**Perf.** MV0 records the baseline; MV3 gates the battle end (`battles_ms`, issue 427); MV5 and MV8 measure their rows once; MV11
re-measures the AI rows; MV16 adds every new row of spec 9 (including `preview_via_ms` and `march_via_ms`, measured once by MV19) and runs all of them after. A row more than 5 % slower than the
baseline, or past its limit, takes the spec's fallback before merge.

---

## 5. Reviews and the owner's playtest

- **The code reviewer** reads every task; for MV1 it compares the moved functions with their source line by line; for MV4 it
  checks every edited test against its reason in spec 8.2.
- **The technical director** signs spec sections 2, 3 and 4 before group A; reads MV1's digest lists and MV3's battle cost before
  they merge; reads MV4 and MV7 (the rules) and MV14 (the proofs) before they merge; reads MV16's perf tables.
- **The systems designer** gives MV11's verdict on the soak tables (battles a season, wars lost, marches halted on sight) before
  group E.
- **The art director** looks at MV9's points mark (headless picture) and signs MV17's pictures and goldens.
- **The creative director** reads MV5's and MV10's words (the move card, the toasts, the confirm) with the owner's playtest.
- **MV19** is read by the code reviewer (the re-plan through the stops, the pair rule of `via`) and the technical director (R63 to R65, the
  `army/3` edit and the log round trip); the creative director reads its words (the leg lines, the toast, the card's buttons).
- **Pull requests say what changes for the player:** MV2 makes every saved game of earlier builds unloadable ("Made by an older
  test build"); MV4 makes orders walk at once; MV7 halts marches on sight; MV10 adds the confirm; MV11 changes what the computer
  does (with the soak's tables).

**The owner's playtest** (Windows, fresh user folder, the Movement replay speed at Normal):

1. New game, Italy 1480, play as Savoy. Select an army, rest the pointer on a hex two steps away: the move card says what the
   walk costs now and what is left. Right click: the army walks now; its token's points mark shrinks; the panel says how much is
   left.
2. Order the same army again with the points left; then order it to a place three seasons away: it walks the first leg now; the
   card and the toast say when it walks on.
3. End the season: the army walks its next leg only at the end of the next season (not now).
4. Declare war on Milan. March toward a Milanese army you cannot yet see: the walk stops when it comes into sight, with points
   left; Continue (R) walks on.
5. Order an attack on a Milanese army you can see: the confirm asks; Cancel does nothing; Move: the army walks, the battle is
   fought, the battle dock opens when the walk has played.
6. March into Milanese land and to a hex out of supply: each asks once; a plain march never asks. Turn "Confirm risky moves" off
   in Options and see that nothing asks.
7. End the season: Milan's armies answer; the replay plays their walks one after another, then the marches together; the report's
   "Your armies" lines include the walks you made in your turn.
8. In the middle of a season (some armies moved, one halted, one with a standing march): F5, quit, Continue: the same armies,
   points, halts and marches. An older save is refused as an older test build.
9. Look at MV17's signed pictures, including deep fog's "Unmapped land" (deep fog shows on the north Italy map only in the thin
   test fixture).
10. Multi-leg: select an army, Shift+left click two hexes, rest the pointer on a third: one path with numbered stops, a line for
    each leg and a total with the seasons; Esc clears the stops (the army stays selected); stage them again and press `V` on the
    last stop to remove it; right click: the army walks as far as its points reach without halting at a stop; End season: it walks
    on; the thin route with the markers of the stops ahead stays drawn until the end; F5, quit, Continue: the stops left are still
    there. With no army selected Shift+left click still selects, and Shift+right click still storms.

---

## 6. Definition of done

1. The spec's done-when items 1 to 8 hold.
2. MV0 to MV18 merged; CI green with the nightly `soak`, `soak-ranges`, `perf_core` and `perf_ui` jobs within limits.
3. Issue 432 closed by MV18's pull request (with the playtest note), issue 427 by MV3's.
4. The owner has played section 5, and answered Q1 (or left the default).

---

## 7. Risks

| Risk | Where it shows | Answer |
|---|---|---|
| A battle on a click freezes the window (issue 427) | MV3, MV16 | MV3 gates group B on `battles_ms`; `walk_battle_ms` in MV16; the spec 9 fallback |
| MV4 is wide (the walk, battles, storms, the report's origin, 14 edited tests) | group B | MV1 moved the engine first, so MV4 changes rules in one place; the reviewer checks each edited test against spec 8.2; split into MV4a (walk and standing march) and MV4b (battles, storms, `season_from`) if the first pull request passes 1,500 changed lines |
| The AI's tests and the soak move a lot | MV11 | the designer may change data, never code, in MV11; every re-pin states why |
| The fog test of the AI cannot stay "the whole turn equal" | MV13 | the rewritten scene and the new case (spec 8.2) |
| A test written on north Italy cannot see the deep-fog step | MV7, MV13 | every deep-fog case runs on `MovesFixture.thin()`; a review rejects one without it |
| Signal arity: `unit_moved` gains `now` | MV8 | the one task changes the signal, the drain and every listener together (`MoveReplay`, `MapArmies._mark_dirty`, the session test) |
| `movement.gd` passes 800 lines | MV4, MV7 | the new code lives in `walk_now.gd`, `march_leg.gd` and `allowance.gd`; a task that would pass the mark moves a helper there |
| The owner changes the deep-fog rule | after MV7 | one data value and one function (`MarchLeg`'s fog step); the preview line follows |
| Windowed runs for pictures | MV17 | the owner's go first; MV9's mark is looked at headless |

---

## 8. Defaults taken (none blocks the build; the owner may change any before its group)

| Default | Alternative |
|---|---|
| Deep fog: a step onto a hex never mapped (no explored bit) is taken only as the season's first step and spends the whole allowance; mapping comes from the steps and the vision phase's sight ring, so sight 1 makes about one hex a season, knights (sight 2) about two (spec D9) | a fixed extra cost per fog step; a cap of N fog steps a season; refusing undiscovered goals (the design's first draft) |
| Stop on sight applies to standing marches at End season too (spec D6) | only to the walk you order |
| "Comes into sight" means an enemy army the country did not see when the walk began (spec D7) | any enemy army in sight after a step |
| The zone of control beats stop on sight on the same step: the season is over (spec D8) | sight wins and the points are kept |
| Every army that fights a battle, on either side, has no move points left that season (spec D11) | only the attacker |
| The winner of a battle halts with its goal kept and Continue resumes it, as the code does today (spec D12) | it walks on by itself next season (the M7 spec's words) |
| A storm with points left is fought at once; without, the battles phase starts it as today (spec D13) | every storm waits for the battles phase |
| An order that cannot walk now (mustering, no points, a closed pass first) is accepted and kept as a standing march (spec D4) | refused with "no move points left this season" |
| Until the battle board, a battle you open is fought at once and the battle dock opens on it after the walk (spec D21) | a toast with "Open the battle" only |
| The confirm asks for a battle, entering enemy land and ending out of supply, judged on this season's leg; on by default, an Options switch "Confirm risky moves" (spec D18) | judged on the whole march; no switch |
| Space, Enter and Esc during your own live walk skip it and do nothing else; an order, End season, F5 and F9 skip it and then act (spec R49) | the live walk blocks input like the season replay |
| The computer's walks are replayed one after another in the order they were done, then the standing marches together (spec D20) | all together by tick, as today |
| No "one move a season" switch (spec D25) | the design's data switch |
| Fair warning stays the computer's rule only (spec D24) | Q1 |
| Multi-leg marches: a stop is a place to pass, not to halt; the army walks the stops and the goal as one route under one allowance, and does not wait at a stop (spec D29) | the army halts at each stop and needs Continue, or waits one season there |
| Stops are staged in the shell and only the commit is an act; the commit is a right click on the hex under the pointer (or O, or the card's "March"), with the stops drawn on the way (spec D32, D33) | each Shift+left click is an act that stores a stop at once |
| Esc clears every staged stop in one press; one stop is removed by Shift+left click or `V` on the last one (spec D34) | Esc removes the last stop only |
| Waypoints are one `march` with `via`, no new action; `Army.via` in `army/3`, FORMAT unchanged (spec D30, D31) | a new action `march_via`; a separate route list |
| The computer never uses stops; at most six stops (spec D35, D36) | the AI plans multi-leg in a later task; a different limit |
| Without Shift: the key `V` at the cursor and the card's "March" and "Clear stops" buttons (spec R62) | a context menu on the hex |

---

## 9. Open owner questions

1. **Q1. Fair warning for you too?** Today, in the season a computer country declares war, its armies take no order into the
   enemy's land (M8 D23); you have no such rule. With moves at once, you can declare war and strike in the same season before the
   other country can move at all (it answers only at End season). Options: (a) keep it as it is: you may strike at once; (b) the
   same rule for every country: in the season you declare a war, your armies may not step into that enemy's land (they may still
   fight its armies on your own or on unclaimed land), from the next season on they may. **Recommend (b):** the owner's rule is
   that the computer follows the same rules, so the rules should be the same both ways, and it keeps your first move from being
   a free surprise attack. Cost if (b): one check in the march's open land (a small task in group D, `movement.gd` and its tests).
2. **Q2. Ship this before the battle board?** This build gives "battle at once" as a battle fought automatically at the click, its
   result shown in the battle dock; the board (#437) comes next and changes only how the days are played. Options: (a) ship #432
   on its own, then the board (recommended); (b) hold #432 until the board is built and ship both together. **Recommend (a):** the
   rule change is large and wants its own playtest; the board then lands on a tested trigger (spec 7.1), and each can be judged
   alone.
