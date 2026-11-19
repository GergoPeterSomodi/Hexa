# M8 build plan: the AI

Technical director (Fable) with the game and systems designer (Opus), 2026-11-17. **Status: a proposal; no task starts before
the owner's go.** Builds `docs/architecture/m8-build-spec.md` ("the spec").

**Starts after M7 is closed** (its plan's definition of done, the owner's playtest). M8 edits what M1.5 to M7 deliver: `Game`,
the season table, `Replay`, `Snapshot`, `SaveFile`, `ScenarioDef`, `GameDefs`, `Countries`, `Military`, `Sieges`, `Movement`, `Knowledge`,
`OddsView`, the report's view, the log lines, the reminders, the replay's plan, `Session`, the season flow, the map and app
input, the decision queue, the HUD, the console, F3, the App and the lint, and adds the `core/ai/` layer, the AI's data and the
soak tool. The standard's rule holds: the next milestone starts after the owner has played the last one.

**The M8 row of `ui-style-and-feedback-plan.md` S5** (the AI reads `Knowledge`; the soak checks the `stats` budget) is folded
in: the AI's door is K14, the `stats` budget is a range of the soak (K22). **The M8 row of `ui-and-controls-plan.md` section 4**
(the AI-turn pill, the map limited to the camera, the AI's moves replayed) is K15, K16, K26 and K28.

**Task IDs** start at K10: K1 to K9 are the M1.5 bake tasks of `ui-style-and-feedback-plan.md`.

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Foundations** | the layer order; the AI's numbers and temperaments; the orders hook, the `ai_orders` row, AI-only games and the trimmed log; the fog-safe seams (garrison estimate, `forecast_for`, the plan cache) | K10, K11, K12, K13 | 1 L, 2 M, 1 S |
| **The frame** | the door, the brief, the turn and its step queue; the busy pill | K14, K15 | 1 L, 1 S |
| **The behaviour and the shell's door** | `Session`'s slices, the flow and the camera-only map; the AI's money and works, its forces, its war, its peace | K16 to K20 | 4 L, 1 M |
| **Proofs** | the judge, the fog, determinism, the duel, every country plays; the soak tool and its nightly job; the AI's perf rows and the E3 measurement | K21, K22, K23 | 2 L, 1 M |
| **Tuning and the UI's content** | the balance pass on the soak's tables; what others did in the report, the log and the reminder; the replay's focus and the peace alert; the console and F3 | K24 to K27 | 4 M |
| **Wiring and proof** | the App; the monkey, the pictures, the UI perf rows | K28, K29 | 1 L, 1 M |

**20 tasks: 9 L, 9 M, 2 S**, about 33 worker-days; about 15 working days end to end with the groups below (each group takes as
long as its longest task), plus reviews and the owner's playtest.

```
M7 closed (the owner's playtest)
  -> A:  K10 (S)  K11  K12 (L)  K13
  -> B:  K14 (L)  K15 (S)                        (K14's scratch run of the brief on the made-up Europe)
  -> C:  K16 (L)  K17 (L)  K18 (L)  K19 (L)  K20
  -> D:  K21 (L)  K22 (L)  K23                   (K22's first full soak: Opus reads its tables before group E)
  -> E:  K24  K25  K26  K27                      (K24: Opus's balance verdict before group F)
  -> F:  K28 (L)
  -> G:  K29  -> the owner plays M8

Critical path: K12 -> K14 -> K19 -> K21 -> K24 -> K28 -> K29     (and K11 -> K14 -> K17, K18, K20; K13 -> K19;
               K14 -> K16 -> K28; K22 -> K24; K15 -> K28; K25, K26, K27 -> K28)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel, no two touch one
file, and no task calls code another task of its group writes: the step modules of group C (K17 to K20) are filled into the
empty functions K14 creates and call only `AiKnow` and `AiBrief` (K14), never each other (`AiTurn` dispatches an army's step to
`AiWar.war_army` at war and `AiForces.peace_army` at peace; the posts are `AiBrief.post_of`); the soak (K22) has its own
counting judge and the proofs (K21) their own `AiJudge`.

---

## 2. Tasks

Who, per the standard's section 9 ("Fable (AI frame) + Opus (temperaments) / Sonnet"): *Sonnet* builds the AI, systems, views,
tools and anything touching `Game`, saves, the season table, `Session`, `Events`, input or the App; *Haiku* builds data files,
the kit-based pill, the console's commands and tests from a list; *Opus* sets and reviews the temperaments' numbers and the
words; *Fable* reviews interfaces. Generated files belong to the task that changes their source. **Every task's done-when
includes: lint (`python tools/lint_godot.py godot`), check_scripts and GUT green**, both UI `--check`s (`bake_ui.py --check`,
`build_theme.gd --check`), `build_map --check` and `build_scenario.gd --check`. Paths without a prefix are under `godot/`;
`tools/`, `tests/test_*.py`, `docs/`, `.github/` and `CLAUDE.md` are at the repository root.

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| K10 | S, Sonnet | **The layer order: views below ai** | edit `tools/lint_godot.py` (`CORE_RANK`: `views/` 5, `ai/` 6; the docstring's order), `CLAUDE.md` (the Port rules' layer line), `godot/README.md` (the Layout's `ai/` and `views/` lines, the Rules' "Layers, one way") | Spec D2 and 1.2: the lint passes on the tree; the pull request shows a scratch run in which a `core/views/` file naming `res://core/ai/x.gd` is reported and a `core/ai/` file naming `res://core/views/x.gd` passes; the three texts and the standard's section 2 give one order. Lint, check_scripts, GUT green |
| K11 | M, Haiku (Opus reviews) | **The AI's numbers and the temperaments** | `core/defs/ai_def.gd`, `core/defs/ai_temper_def.gd` (new); edit `core/defs/game_defs.gd` (`ai`, `tempers`, `temper()`, `validate`), `core/defs/scenario_def.gd` (`tempers`, `start_armies`, `validate`, `digest`); `data/defs/ai.tres`, `data/defs/tempers/builder.tres`, `cautious.tres`, `steadfast.tres`, `aggressive.tres`, `opportunist.tres` (new); edit `data/defs/game_defs.tres`, `data/scenarios/north_italy_1480.tres` (the 13 tempers of spec 4.4, `start_armies` empty), `godot/tools/build_scenario.gd` (keeps both fields when it regrows `owner`), `core/mapgen/fake_scenario.gd` (tempers by id mod 5, no start armies), `data/README.md`; `godot/tools/ai_tables.gd` (new); `tests/core/test_ai_defs.gd` (new); edit `tests/core/test_scenario_defs.gd`, `tests/core/test_fake_scenario.gd` | Spec 4.4 and 5.1 entered exactly; every planted fault of spec 9 for `test_ai_defs.gd`; `ai_tables.gd` prints the two tables of spec 4.4; `build_scenario.gd --check` green with the new fields; Opus reads the numbers and the assignments on the task's first day. Lint, check_scripts, GUT green |
| K12 | L, Sonnet | **The orders hook, the `ai_orders` row, AI-only games, the trimmed log** | `core/game/orders_hook.gd`, `core/game/log_orders.gd` (new); edit `core/game/game.gd` (`orders`, `ai_only`, `watch()`, the digest), `core/game/season.gd` (`PHASES`, `orders_begin`, `orders_step`, `orders_end`, `run_phase`, `end_check`), `core/game/replay.gd` (`LogOrders`, `watch` records), `core/game/snapshot.gd` (`ai_only`, the log kept 40 seasons, `log_from`), `core/game/save_file.gd` (`FORMAT` 6, `OLDEST_FORMAT` 6), `core/systems/countries.gd` (`choose_check` refused in a watched game); `tests/core/test_orders_hook.gd` (new); edit `tests/core/test_season.gd`, `test_replay.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_game_core.gd`, `test_owns.gd`, `test_countries.gd` | Spec 4.2 (the hook's calls), 4.12 (`watch`), 4.15, 5.4: **`PHASES` pinned as the fourteen**; the `orders_done` mark every season; a recorder hook gives the same calls through `run_phase` and through begin, steps and end; `LogOrders` replays a stub hook's logged acts to the same digest and a log with no mark plays none; save, load, save byte-equal with a trimmed log; `FORMAT` 6 (P: a format-5 header reads `older`); `test_owns.gd`'s phase check with a stub hook acting through `Game.act` (P: a stub that writes a treasury directly is reported); every planted fault of spec 9 for these files. Lint, check_scripts, GUT green |
| K13 | M, Sonnet | **Fog-safe seams: the garrison estimate, `forecast_for`, the plan cache** | edit `core/systems/sieges.gd` (`forecast_for`), `core/views/knowledge.gd` (`men_of`, `garrison_estimate`), `core/views/odds_view.gd` (the estimate and `forecast_for`), `core/systems/movement.gd` (`plan` cached in `game.view_cache`); edit `tests/core/test_sieges.gd`, `test_knowledge.gd`, `test_odds_view.gd`, `test_movement.gd` | Spec 5.3, 5.7 for these files, D49, D50: the cases and planted faults of spec 9 for these tests; M7's `test_war_savoy.gd` and the odds bands of `test_odds.gd` unchanged (own and seen fortresses read as before); `route_ms` measured once by a probe run, the number in the pull request. Lint, check_scripts, GUT green |

### Group B (after A)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| K14 | L, Sonnet | **The AI frame: the door, the brief, the turn** | `core/ai/ai_know.gd`, `core/ai/ai_brief.gd`, `core/ai/ai_trace.gd`, `core/ai/ai_turn.gd`, `core/ai/ai_players.gd` (new); `core/ai/ai_economy.gd`, `core/ai/ai_forces.gd`, `core/ai/ai_war.gd`, `core/ai/ai_peace.gd` (new: every step function of spec 5.5 with its signature and an empty body, for group C); `tests/core/ai_fixture.gd`, `tests/core/test_ai_know.gd`, `tests/core/test_ai_door.gd`, `tests/core/test_ai_turn.gd` (new) | Spec 4.2 (the steps, their order and bounds), 4.3 (the fog table through `AiKnow`; the door's text rule), 4.5 (the brief, `post_of`), 4.12 (the seats), 5.5: every case of these tests with its planted fault; a turn stepped one at a time equals the turn at once; a scratch run of empty steps on `PerfFixture.europe_war` gives `AiBrief.make`'s time (in the pull request, against `ai_brief_ms`). Lint, check_scripts, GUT green |
| K15 | S, Haiku | **The busy pill** | `shell/hud/busy_pill.tscn`, `shell/hud/busy_pill.gd` (new); edit `core/views/words.gd` (`orders_progress`); `tests/shell/test_busy_pill.gd` (new); edit `tests/core/test_words.gd` | Spec 6.1: the three texts, `PanelCard`, the still `hourglass`, mouse ignored, focus none; `orders_progress` counts `min(done + 1, total)`; the art director signs a picture of it beside the mockup's pill. Lint, check_scripts, GUT green |

### Group C (after B)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| K16 | L, Sonnet | **`Session`'s slices, the flow, the map limited to the camera** | edit `shell/autoload/session.gd` (spec 5.6: `ai_enabled`, `ai`, `begin_season`, `step_orders`, `orders_progress`, `finish_season`, `end_season`, `in_season`, `watch`, `set_seat_passive`; `start_game` attaches the AI; `check` and `act` refused in season), `shell/app/season_flow.gd` (spec 6.2), `shell/input/map_input.gd` (`block_orders`, `blocked`), `shell/input/app_input.gd` (F5 and F9 while in season), `tests/shell/ui_harness.gd` (the AI off); edit `tests/shell/test_session.gd`, `test_season_flow.gd`, `test_map_input.gd`, `test_app_input.gd` | Spec 5.6, 6.2, D36, D40, D47: begin, steps and finish give `end_season`'s digest; a drain after every step; an act between two steps refused and nothing changes (P); the slices with injected callables, the budget switching on `camera_moved`, `progressed`, `abort`, `count` 3; each blocked intent emits `blocked` and changes nothing (P), each camera intent works; every M3 to M7 shell test green with the harness's AI off. Lint, check_scripts, GUT green |
| K17 | L, Sonnet (Opus reviews) | **The AI's money and works** | edit `core/ai/ai_economy.gd` (`works_scan`, `works_card`, `works_act`, `tax`, `prior`); `tests/core/test_ai_economy.gd` (new) | Spec 4.6, 4.7 and **4.16 (a) exactly**: every row of the tax table and every case and planted fault of spec 9 for this test; the trace's lines name each choice and its numbers. Lint, check_scripts, GUT green |
| K18 | L, Sonnet (Opus reviews) | **The AI's forces in peace, and the scenario's starting armies** | edit `core/ai/ai_forces.gd` (`forces`, `peace_army`), `core/systems/military.gd` (`setup_start_armies`), `core/game/game.gd` (its call in `new_scenario` after `Occupation.setup`); `tests/core/test_ai_forces.gd` (new); edit `tests/core/test_military.gd` | Spec 4.8, 5.3, D19 to D21, D30: every case and planted fault of spec 9 for `test_ai_forces.gd`; a fixture's start list raises its armies through the door with their men levied; 1480's empty list leaves every M4 to M7 pinned number unchanged. Lint, check_scripts, GUT green |
| K19 | L, Sonnet (Opus reviews) | **The AI at war: declaring, aims, standing orders, storms** | edit `core/ai/ai_war.gd` (`war`, `war_army`, `aims`); `tests/core/test_ai_war.gd` (new) | Spec 4.9, 4.10, **4.16 (b) and (c)** on the duel and `WarFixture` scenes, D22 to D26: every case and planted fault of spec 9 for this test, fair warning (P). Lint, check_scripts, GUT green |
| K20 | M, Sonnet | **The AI's peace** | edit `core/ai/ai_peace.gd` (`peace`); `tests/core/test_ai_peace.gd` (new) | Spec 4.11, D27: each terms' rule with its check (P each); a refusal ends that war's step; one terms a war a turn. Lint, check_scripts, GUT green |

### Group D (after C)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| K21 | L, Sonnet | **The proofs: the judge, the fog, determinism, the duel, every country plays** | `tests/core/ai_judge.gd`, `tests/core/test_ai_judge.gd`, `tests/core/test_ai_fog.gd`, `tests/core/test_ai_determinism.gd`, `tests/core/test_ai_owner.gd`, `tests/core/test_ai_play.gd` (new); edit `tests/core/test_replay.gd` (40 AI seasons replayed with no AI), `tests/core/test_owns.gd` (the phase with the real AI); and any system or view file in which the fog test finds a leak (closed with its planted fault) | **Done-when 1 to 4**, and the duel of done-when 5 and 6, as spec 9 lists them, each with its planted fault; the seasons of the duel pinned as the build gives them (in the pull request). Lint, check_scripts, GUT green |
| K22 | L, Sonnet | **The soak** | `godot/tools/soak.gd`, `godot/tools/probes/probe_logger.gd`, `tests/core/invariants.gd`, `tests/core/test_invariants.gd`, `tests/core/test_ai_soak_quick.gd` (new); edit `.github/workflows/godot.yml` (the nightly `soak` matrix and `soak-ranges`), `CLAUDE.md` (the soak's commands in the Godot block) | Spec 4.17: the three suites, every invariant (P each), the ranges table, the JSON and the job summary, the replay line of a failed game (shown with a planted break, `--plant=money`, which edits a treasury mid-game, tests only), the error counter (`probe_logger.gd` PASS on the runner, or the grep net with the probe's FAIL in the pull request); a full run of the four `ai` shards, `passive` and `europe` on a runner by hand dispatch, their tables in the pull request; **Opus reads them before group E**. Lint, check_scripts, GUT green |
| K23 | M, Sonnet | **The AI's perf rows and the E3 measurement** | edit `godot/tools/perf_fixture.gd` (`europe_ai`: M7's `europe_war` made with `Game.watch()` before its first season, the AI attached), `godot/tools/perf_core.gd` (spec 8.1's rows, `--ai-map`, `--ai-scenario`, spec 8.3's table), `godot/tests/perf_core_budget.json` | Spec 8.1 to 8.3, done-when 8's core rows: the rows printed and within their limits on the made-up Europe and north Italy; the E3 table printed for the made-up Europe with each criterion's verdict; a failed row takes 8.1's fallbacks in order as data edits of `data/defs/ai.tres` with `tests/core/test_ai_defs.gd`'s values, in this pull request. Lint, check_scripts, GUT green |

### Group E (after D)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| K24 | M, Sonnet (Opus decides) | **The tuning pass** | edit `data/defs/tempers/builder.tres`, `cautious.tres`, `steadfast.tres`, `aggressive.tres`, `opportunist.tres`, `data/defs/ai.tres`, `tests/core/test_ai_defs.gd` (the values), `tests/core/test_ai_owner.gd`, `tests/core/test_ai_play.gd` (pinned seasons), `docs/architecture/m8-build-spec.md` (4.4's tables as `ai_tables.gd` prints them; 4.17's ranges where Opus changes one), `docs/architecture/m8-build-plan.md` (section 4, step 9's seed); and, when D51 applies, `core/state/chronicle.gd` (`KEEP` 6,000) with `tests/core/test_chronicle.gd` | Every range of spec 4.17 holds on 100 `ai`, 20 `passive` and 4 `europe` games with the final data; Opus's verdict and the per-country table (land at 20, 40 and 80 seasons, wars won and lost, treasury, men) in the pull request; **the playtest's seed**: the first seed from 1480 on where a passive Genoa loses a war within 40 seasons (the soak's `--suite=passive --seed=...` with Genoa as the seat), written into step 9 of section 4; the chronicle's coverage checked (D51). Lint, check_scripts, GUT green |
| K25 | M, Sonnet (Opus reviews the words) | **What others did: the report, the log, the reminder** | edit `core/views/season_summary.gd` (`orders` by the viewer's tag, `befell` one line a country and the ranks, the watched lede), `core/views/log_lines.gd` (`OTHERS_PER_SEASON`, the "more" line, `NOTIFY_RANGE`), `core/views/reminders.gd` (`peace_risk`); edit `tests/core/test_season_summary.gd`, `test_log_lines.gd`, `test_reminders.gd`, `tests/fixtures/report_sample.gd` (a grouped "What befell") | Spec 4.14 for these views, D38, D39, D28's reminder: every case and planted fault of spec 9 for these tests; the report's sections equal after a save and load. Lint, check_scripts, GUT green |
| K26 | M, Sonnet | **The replay's focus and the peace alert** | edit `core/views/replay_plan.gd` (`set_focus`), `shell/map/replay.gd` (`start(speed, focus)`), `shell/app/decision_queue.gd` (the `peace_made` kind); edit `tests/core/test_replay_plan.gd`, `tests/shell/test_move_replay.gd`, `tests/shell/test_decision_queue.gd` | Spec 6.3, 6.4 and 4.14's peace alert, D37: a seen step outside the focus plays instantly, inside it is timed (P); the alert's title, tone, lines per terms and choices, queued after the war alerts. Lint, check_scripts, GUT green |
| K27 | M, Haiku | **The console and F3** | edit `shell/hud/dev_commands.gd` (`ai TAG`, `ai off`, `ai on`, `ai pass TAG`, `ai play TAG`, `watch`), `shell/hud/debug_overlay.gd` (the AI line); edit `tests/shell/test_dev_commands.gd`, `tests/shell/test_debug_overlay.gd` | Spec 6.5, D45: every command and its planted faults ("no country TAG", "no AI in this game", "only during the pick", "wait for the season to end"); the F3 line. Lint, check_scripts, GUT green |

### Group F (after E)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| K28 | L, Sonnet | **Wire the App** | edit `shell/app/game_requests.gd` (spec 6.6's table), `shell/app/app.gd` (the milestone `"8"`, the flow's new callables, `abort`; under 800 lines), `shell/hud/hud.tscn`, `shell/hud/hud.gd` (the `TopCentre` slot and the pill), `shell/hud/top_bar.gd` ("Watching" with the sandbox seal in a watched game), `shell/map/map_scene.gd` (`view_hexes`), `godot/README.md` (the AI, the soak, the console, the pill, the layers' note); edit `tests/shell/test_app_flow.gd`, `tests/shell/test_hud.gd`, `tests/shell/test_map_scene.gd` | Spec 6.6 and the end to end of spec 9 (`test_app_flow.gd`): the pill counting to 12 / 12, a blocked click and a free pan, the replay's seen AI walks, the grouped report, `ai MLO`, `ai off`, `watch`; **done-when 9** in the shell tests; still two autoloads. Lint, check_scripts, GUT green |

### Group G (after F)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| K29 | M, Haiku | **Monkey, pictures, the UI perf rows** | edit `tests/shell/test_ui_monkey.gd` (the AI on; spec 9's invariants), `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd` (the rows, and `--ai-map`, `--ai-scenario` for spec 8.2's windowed E3 rows), `godot/tests/perf_ui_budget.json` (`ai_frame_ms`, `ai_turn_wall_ms`, `busy_pill_ms`), `tests/fixtures/ui_sample.gd` (an AI season sample); the signed pictures as goldens (`godot/tests/goldens/m8_*.png`) | The monkey's invariants green on 3 seeds; spec 9's pictures at 1280 x 720 scale 1 and 2560 x 1440 scale 2, signed by the art director; done-when 8's UI rows within their limits; the two windowed E3 rows printed for the made-up Europe. Lint, check_scripts, GUT green |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** signs the orders hook and the season's three calls (spec 4.2, 5.4), the door's fog table and
  text rule (4.3), the step bound (4.2) and `Session`'s slice API (5.6) before group A starts, and reads the interfaces of K11,
  K12, K13, K14, K16 and K28 before they merge; reads K21's fog and determinism tests and K22's invariants together.
- **Opus** reads K11's numbers and the 13 assignments on its first day, reviews the rules of K17 to K20 against spec 4.6 to
  4.11, reads K22's soak tables before group E, and gives K24's balance verdict before group F (a changed number is a data
  edit with the tests it moves, in K24's pull request); reviews the words of K25 against spec 4.14.
- **The art director** signs K15 (the pill beside the mockup's) and K29's pictures (the pill's three texts, the grouped report,
  the peace alert).
- **Pull requests** say what changes for the player. K12 changes `Game.digest()` (`ai_only`) and makes M7 saves unloadable
  ("Made by an older test build"); K11 changes the scenario's digest (`tempers`): said; no test pins a digest value. K13
  changes the odds card for unseen fortresses (the full garrison): said. K16 and K28 change the season's feel (the slices, the
  camera-only map): said. K17 to K20 and K24 change what the other countries do: said, with the soak's tables.

---

## 4. The owner's playtest of M8

On Windows (mouse) and on the MacBook (trackpad), with a fresh user folder.

1. New game, More, seed **1480**, Italy 1480, Play as **Genoa**. Press Space (End Spring): the pill at the top reads "Countries
   are moving 1 / 12", counting to 12 / 12, then "The season ends", and it is gone with the report (companies raised in
   Spring muster, so the first walks, and the replay's line "The moves of Summer 1480 · Space skips them", come a season
   later). While the pill shows, click a hex: a toast says the map takes orders when the countries are done; pan and zoom
   work.
2. Close the report. Tokens of your neighbours stand where you can see (Savoy's, Milan's). Hover one: "about 500 men", no
   more. Press J: "What befell Genoa" has one line per country you know (for example "Milan raised about 1,000 men at Novara (7, 8) and
   began 2 works."); "Your orders" lists only yours.
3. F2: `ai MLO`: Milan's last turn (its tax, its works and their paybacks, its raises, its armies' posts). `ai SAV`.
4. Play 8 seasons (`end 8` in the console, or Space, Space): each season the pill passes in under a second; the log's season
   headers end with "and N more about other countries" when they are many; a notification only for armies raised near you.
5. Open the pause menu while the pill shows: Save game is greyed "Wait for the season to end"; F5 toasts the same; the pill
   goes on under the menu; Resume.
6. Raise 2 pikemen at Genoa and set them to Withdraw; then put them back to Hold. Note the AI armies at your border (Milan's,
   Savoy's) and their posts across from you.
7. Main menu, New game, the same seed, and in the pick F2 `watch`: the pick ends, the top bar shows "Watching"; `end 20`: watch
   the countries build, raise, march and fight; open a battle badge's dock; the Wars table of the Military page (I) lists the
   wars between them. Note who grows and who shrinks.
8. Main menu, New game, seed 1480, Play as **Savoy**. Declare war on Milan (the country panel); End season: Milan's armies move
   to meet you or to its posts; set your army on Hold beside a Milanese army and watch whether Milan's stands on Withdraw (the
   dock after a battle shows "them: Hold" or "Withdraw"). Fight on until Milan makes a white peace or yields (the peace alert).
9. Main menu, New game, seed **1480** (K24 replaces this number with the first seed from 1480 on that gives the loss, when
   1480 does not), Play as **Genoa**, and raise nothing. Play
   `end 4` again and again: a war is declared on you (the war alert); enemy armies take your open land and besiege Genoa (the
   dial); the task flag's **peace_risk** line warns "...: it can make peace now and keep them"; then the **peace alert**:
   "The Duchy of Milan has made peace with you: ... become theirs." You have lost a war.
10. F2 `ai off`, End season: the log shows no other country's orders this season; `ai on`. F3: the "ai 12 seats · ... ms"
    line.
11. F5 in a quiet season; F2 `digest`; quit to desktop; Continue; F2 `digest`: the same. Space: the season plays on.
12. Options, Game: Movement replay speed Instant: no replay after End season, the pill goes straight to the report; Slow:
    slower walks; back to Normal.

---

## 5. Definition of done

1. The spec's "M8 is done when" items 1 to 10 hold.
2. Tasks K10 to K29 merged; CI green, with both UI `--check`s, `build_map --check`, `build_scenario.gd --check`, and the
   nightly `soak`, `soak-ranges`, `perf_core` and `perf_ui` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac.
5. `godot-architecture.md` 9.2 marks M8 done; `godot/README.md` describes the M8 game.
6. Section 7 below is handed to the M9, M10, M11 and M12 build specs' authors, and spec 8.3's criteria to the E3 decision.

---

## 6. How to start

On the day M7 closes:

1. Opus presents the temperaments (spec 4.4, the 13 assignments and the worked examples of 4.16) to the owner and Fable in 30
   minutes; a changed number or assignment is a data line now, not a task later. Fable signs the hook, the door and the slice
   API the same day.
2. Start group A together: **K10, K12, K13** (Sonnet) and **K11** (Haiku). Opus reads K11's numbers on its first day.
3. K14 runs its scratch brief on the made-up Europe in its last day, so a fallback of spec 8.1 is chosen before group C fills
   the steps.
4. K22 runs `probe_logger.gd` on its first day (spec 10), and its first full soak goes to Opus the day it runs; group E waits
   for Opus's reading, group F for K24's verdict.

---

## 7. What M8 hands on

- **M9** (taken up in `m9-build-spec.md` 4.14, which drops `AiPeace.answer`: every country accepts by the score rule)**:** `AiPeace.answer` for peace offers by temperament (replacing M7's fixed acceptance for AI countries); the AI's offers
  as M9's actions in the `war` phase, reaching the player through `DECISIONS`; war goals and a casus belli chosen by
  `AiWar.war`; relation numbers on `AiTemperDef`; `Relations` through `AiKnow`; the soak's land-share range turned into "no
  runaway winner".
- **M10:** merchants and the market's prices in `AiEconomy`; road works as candidates; the soak's trade ranges (taken up in
  `m10-build-spec.md` 4.16 and 4.17).
- **M11:** research and idea picks by temperament branch weights; generals and refits in `AiForces` (taken up in
  `m11-build-spec.md` 4.17).
- **M12:** debt and bankruptcy in the AI's money; seats that fall; a difficulty scale in `AiDef` on the New game page; the
  soak to 1650 and the old-saves check.
- **E3:** `perf_core.gd --ai-map --ai-scenario` and spec 8.3's criteria; the soak's `europe` suite on the real map.
- **Saves:** `SaveFile.FORMAT` 6; a new body field with a default needs no bump (M3 4.10).
