# M9 build plan: Diplomacy and peace

Game and systems designer (Opus), 2026-11-17. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/m9-build-spec.md` ("the spec").

**Starts after M8 is closed** (its plan's definition of done, the owner's playtest). M9 edits what M1.5 to M8 deliver: `Game`,
`Session`, `Events`, the action and season tables, `MapData`, `MapState`, `Country`, `War`, `FamilyDef`, `WarDef`, `GameDefs`,
`Territory`, `Countries`, `Treasury`, `Wars`, `People`, `Works`, `EconomySeason`, `Stats`, `StatsSystem`, `Chronicle`, `Knowledge`,
`Words`, the report's view, the reminders, the log lines, the study's views and pages, the map modes and overlay, the map scene,
the country and hex panels, the hex menu, the decision queue, the chips, the console, F3, the App, the AI and its data, the soak and
the map builder. The standard's rule holds: the next milestone starts after the owner has played the last one.

**The M9 row of `ui-style-and-feedback-plan.md` S5** (the Diplomacy page; `RelationMatrix` joins the kit; `truce_ended` in the
report; the peace offer as a decision; the Relations mode) is folded in: the page is V18 and V28, the matrix V21, the report's
section V19 and V28, the decisions V30, the mode V17 and V26. **The M9 row of `ui-and-controls-plan.md` section 4** (the peace
screen, war goals and relations in the country panel, the Diplomacy page; with this spec, the declare-war overlay and the
Relations mode) is V16, V24, V25, V26, V27 and V28.

**Task IDs** are V1 to V33: the letter V is used by no other plan. M7 and M8 are on GitHub (milestones 19 and 20): M9 changes
none of their task rows; every edit M9 makes to their code is a V task here.

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Numbers, state, map** | `DiplomacyDef` and worth; the state classes, `war/2`, `country/5`, `map-state/6`, format 7; regions on the map; bake slice 7; the keys and settings | V1 to V5 | 1 L, 2 M, 2 S |
| **The first rules** | the derived cache, worth, goals, lots and reach; relations and gifts; infamy and weariness | V6, V7, V8 | 1 L, 2 M |
| **War, unrest, leagues** | the score and the war's reason and goal; unrest by region part; leagues | V9, V10, V11 | 1 L, 2 M |
| **Peace and the season** | deals, offers, answers, the capital; the economy's two lines; the season, stats, events, `Session`; knowledge and words | V12 to V15 | 1 L, 2 M, 1 S |
| **Read models and proofs** | the peace, goal and goal-line views; the stability view, the Relations bytes, the hex card and hover cards; the country card and the Diplomacy page's view; the report, log and reminders; the properties, saves and the Savoy war; the kit pieces; the perf rows | V16 to V22 | 2 L, 4 M, 1 S |
| **The AI's door and the screens** | the AI's door, brief, data and war step; the peace screen; the declare-war overlay; the map; the country and hex panels; the Diplomacy page and the report screen | V23 to V28 | 2 L, 4 M |
| **The AI's peace and the App** | the AI's peace and diplomacy steps; the App, the decisions, the chips, the console | V29, V30 | 1 L, 1 M |
| **Proof** | the soak's suite, invariants and ranges; the monkey, pictures and UI perf rows | V31, V32 | 1 L, 1 M |
| **Tuning** | the balance pass on the soak's tables; the playtest's seed | V33 | 1 M |

**33 tasks: 10 L, 19 M, 4 S**, about 46 worker-days; about 21 working days end to end with the groups below (each group takes as
long as its longest task), plus reviews and the owner's playtest.

```
M8 closed (the owner's playtest)
  -> A:  V1  V2 (L)  V3  V4 (S)  V5 (S)
  -> B:  V6 (L)  V7  V8
  -> C:  V9 (L)  V10  V11
  -> D:  V12 (L)  V13  V14  V15 (S)
  -> E:  V16 (L)  V17  V18  V19  V20 (L)  V21 (S)  V22          (V22's first reach-field reading goes to Fable)
  -> F:  V23 (L)  V24  V25  V26 (L)  V27  V28
  -> G:  V29  V30 (L)
  -> H:  V31 (L)  V32                                               (V31's first full soak: Opus reads its tables)
  -> I:  V33  -> the owner plays M9

Critical path: V2 -> V6 -> V9 -> V12 -> V16 -> V26 -> V30 -> V31 -> V33   (and V12 -> V20; V15 -> V17, V18 -> V27, V28;
               V15 -> V23 -> V29 -> V31; V21 -> V24, V27, V28; V3 -> V6 -> V10 -> V13; V30 -> V32)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel, no two touch one file,
and no task calls code another task of its group writes: V2 creates `core/systems/diplo_cache.gd` with every function's signature
and an empty body, which V6 fills; V12 makes the interim edits that keep M7's and M8's code and tests green when the terms change
(`ai_peace.gd`'s terms, the test pins), which V29 then replaces; V23 creates `core/ai/ai_diplo.gd` with its step's signature for
V29.

---

## 2. Tasks

Who, per the standard's section 9 ("Opus / Sonnet, Haiku (peace screen)"): *Sonnet* builds the systems, views, the AI, tools and
anything touching `Game`, saves, the season table, `Session`, `Events`, input or the App; *Haiku* builds data files, the bake slice,
the keys, the kit pieces, the peace screen, the declare-war overlay, the panels and the pages from their views, the console's
commands and the pictures; *Opus* sets and reviews the numbers and the words and decides the tuning; *Fable* reviews the interfaces.
Generated files belong to the task that changes their source. **Every task's done-when includes: lint (`python
tools/lint_godot.py godot`), check_scripts and GUT green**, both UI `--check`s (`bake_ui.py --check`, `build_theme.gd --check`),
`build_map --check` and `build_scenario.gd --check`. Paths without a prefix are under `godot/`; `tools/`, `tests/test_*.py`,
`docs/`, `.github/` and `CLAUDE.md` are at the repository root.

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| V1 | M, Haiku (Opus reviews) | **The numbers: `DiplomacyDef` and worth** | `core/defs/diplomacy_def.gd` (new); edit `core/defs/family_def.gd` (`worth`, `validate`), `core/defs/game_defs.gd` (`diplomacy`, `validate`); `data/defs/diplomacy.tres` (new); edit `data/defs/families/*.tres` (`worth`), `data/defs/game_defs.tres`, `data/README.md` (diplomacy, worth, the regions); `godot/tools/diplo_tables.gd` (new); `tests/core/test_diplomacy_defs.gd` (new); edit `tests/core/test_family_defs.gd` | Spec 4.2 to 4.13 and 5.1 entered exactly; every planted fault of spec 9 for these tests; `diplo_tables.gd` prints the tables; Opus reads the numbers on the task's first day. Lint, check_scripts, GUT green |
| V2 | L, Sonnet | **The state and the saves** | edit `core/state/war.gd` (war/2), `core/state/country.gd` (country/5), `core/state/map_state.gd` (map-state/6), `core/state/stats.gd` (54 series); `core/state/relation_book.gd`, `core/state/coalition.gd`, `core/state/deal.gd`, `core/state/peace_offer.gd`, `core/systems/diplo_cache.gd` (new; the skeleton of spec 5.3 for V6); edit `core/systems/territory.gd` (`gained`, `former`, `OWNS`), `core/systems/treasury.gd` (`WHY`, `SPENDING`, `left_over`), `core/game/game.gd` (the fields, `DOOR_FIELDS`, the digest), `core/game/snapshot.gd`, `core/game/save_file.gd` (`FORMAT` 7, `OLDEST_FORMAT` 7); `tests/core/test_diplomacy_state.gd` (new); edit `tests/core/test_war_state.gd`, `tests/core/test_country_state.gd`, `tests/core/test_stats.gd`, `tests/core/test_territory.gd`, `tests/core/test_snapshot.gd`, `tests/core/test_save_file.gd` | Spec 5.2, 4.21 and the `Territory` and `Treasury` lines of 5.3: every round trip and planted fault of spec 9 for these tests; save, load, save byte-equal; `FORMAT` 7 (P: a format-6 header reads `older`). Lint, check_scripts, GUT green |
| V3 | M, Sonnet | **Regions on the map** | edit `core/defs/map_data.gd` (`region_id`, `regions`, `region_of`, `validate`, `digest`), `godot/tools/build_map.gd` (the nearest anchor from `data/geography/regions.json` and `cities.json`), `core/mapgen/fake_map.gd` (8 x 8 block regions), `data/maps/north_italy.tres` (rebuilt), `data/scenarios/north_italy_1480.tres` (its `map_digest`, by `build_scenario.gd`); edit `tests/core/test_map_build.gd`, `tests/core/test_map_data.gd`, `tests/core/test_fake_map.gd`, `tests/core/test_scenario_1480.gd` | Spec 4.12's regions and D50: the builder's table equals 4.12's (or the pull request writes the builder's table into the spec's 4.12); both `--check`s green; a Relations-like picture of the regions (a scratch run of `probe_mode_overlay.gd` colouring by region) in the pull request for Opus and the art director. Lint, check_scripts, GUT green |
| V4 | S, Haiku | **Bake slice 7: the diplomacy icons** | `tools/ui_bake/pieces_m9.py` (new); edit `tools/bake_ui.py` (the slice), `shell/ui/tokens.gd` (`SCORE_TRACK`, `GOAL_INK`, `GOAL_AGAINST_INK`), `godot/tools/build_theme.gd` (the Kit icons); `godot/assets/ui/kit/**`, `shell/ui/theme.tres` (generated); edit `tests/test_bake_ui.py` | Spec 6.2: the 27 icons at 1x and 2x; both `--check`s; the art director signs the sheet. Lint, check_scripts, GUT green |
| V5 | S, Haiku | **The keys and the setting** | edit `shell/input/bindings.gd` (`view_mode_7`, `game_peace`), `shell/app/settings.gd` (`map/war_goals`; `state/map_mode` gains `relations`); edit `tests/shell/test_bindings.gd`, `tests/shell/test_settings.gd` | Spec 6.1: the rows with `since: "9"`; a bad `map/war_goals` value falls back (P). Lint, check_scripts, GUT green |

### Group B (after A)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| V6 | L, Sonnet | **Worth, goals, lots and reach** | edit `core/systems/diplo_cache.gd` (fill: reach fields with crossings, lots, parts, the forgets), `core/game/game.gd` (`emit`'s cache drops); `core/systems/war_goals.gd` (new); `tests/core/test_war_goals.gd` (new) | Spec 4.2 to 4.5, 4.11's field and 5.3 for these files: 4.2's sums on seed 1480, 4.3's worked goal, 1.1's reach facts, 4.5's lots; every case and planted fault of spec 9 for `test_war_goals.gd`; a scratch run of the reach fields on `PerfFixture.europe_war` gives `reach_cold_ms` in the pull request. Lint, check_scripts, GUT green |
| V7 | M, Sonnet | **Relations and gifts** | `core/systems/relations.gd` (new); `tests/core/test_relations.gd` (new) | Spec 4.8 and 5.3 for this file: every memory, standing term, word and gift row with its planted fault. Lint, check_scripts, GUT green |
| V8 | M, Sonnet | **Infamy and weariness** | `core/systems/brakes.gd` (new: `infamy_of`, `add_infamy`, `home`, `gained_count`, `admin_loss`, `weariness_loss`, `season`); `tests/core/test_brakes.gd` (new) | Spec 4.9's infamy, 4.10 and 4.11's national part: every case and planted fault of spec 9 for `test_brakes.gd` but the shares (V13). Lint, check_scripts, GUT green |

### Group C (after B)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| V9 | L, Sonnet | **The score and the war's reason and goal** | `core/systems/war_score.gd` (new); edit `core/systems/wars.gd` (`declare_war_check` rows 10 to 15, `declare_war`'s reason, goal, anchor, memory and event fields, `book_battle`'s points, `truce_until` by terms, the war phase's bookkeeping and `truce_ended`); `tests/core/test_war_score.gd` (new); edit `tests/core/test_wars.gd` | Spec 4.3, 4.4, 4.6's truces and 5.3 for these files: every case and planted fault of spec 9 for these tests; `Wars.score` keeps M7's body until V12 (so M7's and M8's pins stay). Lint, check_scripts, GUT green |
| V10 | M, Sonnet | **Unrest by region part** | `core/systems/unrest.gd` (new); edit `core/systems/people.gd` (the rising row), `core/systems/works.gd` (the defiant rows), `core/game/game.gd` (`Unrest.setup` in `new_scenario`); `tests/core/test_unrest.gd` (new); edit `tests/core/test_people.gd`, `tests/core/test_works.gd` | Spec 4.12 and 4.13's levy and works rows: every case and planted fault of spec 9; on 1480 every part 0. Lint, check_scripts, GUT green |
| V11 | M, Sonnet | **Leagues** | `core/systems/coalitions.gd` (new); `tests/core/test_coalitions.gd` (new) | Spec 4.9's leagues and 4.22 (f): every row and planted fault of spec 9. Lint, check_scripts, GUT green |

### Group D (after C)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| V12 | L, Sonnet | **Peace by terms, offers, the capital** | `core/systems/peace.gd` (new); edit `core/systems/wars.gd` (`score` = `WarScore.net`, `end_war`'s new fields, the war phase's lapses and the timer through `Peace.apply`; M7's `make_peace` pair removed), `core/systems/countries.gd` (`move_capital`, `OWNS`), `core/game/actions.gd` (21 names, the pairs), `core/ai/ai_peace.gd` (interim: M8's rules asking `deal` with the Best deal for take and `surrender` for yield, through the door), `core/ai/ai_know.gd` (`net`, `best_deal`), `tests/core/random_player.gd` (the new terms), `core/views/country_card.gd` (interim: M7's three peace options become deal (the Best deal), white and surrender), `shell/hud/dev_commands.gd` (interim: M7's `peace TAG` takes deal, white or surrender); `tests/core/test_peace.gd`, `tests/core/test_offers.gd` (new); edit `tests/core/test_wars.gd`, `tests/core/test_countries.gd`, `tests/core/test_war_savoy.gd` (M7's (e) in M9's terms), `tests/core/test_ai_peace.gd` (interim pins), `tests/core/test_reminders.gd` (M8's `peace_risk` pins on the new score), `tests/core/test_country_card.gd`, `tests/shell/test_country_panel.gd`, `tests/shell/test_dev_commands.gd` (interim) | Spec 4.6, 4.7, 5.3 for these files: every row of the three checks and every planted fault of spec 9 for `test_peace.gd` and `test_offers.gd`; 4.22 (c) and (c′) exactly; every M7 and M8 test green with the moved pins listed in the pull request. Lint, check_scripts, GUT green |
| V13 | M, Sonnet | **The brakes in the economy** | edit `core/systems/economy_season.gd` (the `overreach` and `weariness` lines), `core/systems/brakes.gd` (`tax_share`); `tests/core/test_economy_brakes.gd` (new); edit `tests/core/test_economy_season.gd`, `tests/core/test_economy_preview.gd`, `tests/core/test_money_property.gd`, `tests/core/test_brakes.gd` (the shares) | Spec 4.11's shares and 4.13: the lines by hand on fixtures; the preview still equals the season; with no war every M4 to M8 number unchanged; on 1480 every share 1,000. Lint, check_scripts, GUT green |
| V14 | M, Sonnet | **The season, the stats, the events, `Session`** | edit `core/game/season.gd` (15 `PHASES`, the relations phase), `core/game/game.gd` (`dev_infamy`, `dev_weariness`, `dev_opinion`), `core/game/replay.gd` (the dev records), `core/systems/stats_system.gd` (the five series), `core/state/chronicle.gd` (29 notable kinds), `shell/autoload/events.gd` (nine signals), `shell/autoload/session.gd` (`drain`, `last_phase_ms`); edit `tests/core/test_season.gd`, `tests/core/test_chronicle.gd`, `tests/core/test_game_core.gd`, `tests/core/test_replay.gd`, `tests/shell/test_session.gd` | Spec 4.15, 4.16's emitters and signals, 4.20, 5.4, 5.5: **`PHASES` pinned as the fifteen**; the nine signals drained after their phases; the dev records replay to the same digest (P: a changed dev amount gives another). Lint, check_scripts, GUT green |
| V15 | S, Sonnet | **Knowledge and words** | edit `core/views/knowledge.gd` (`opinion_seen`, `infamy_seen`, `own_brakes`), `core/views/words.gd` (spec 5.6's nine functions); edit `tests/core/test_knowledge.gd`, `tests/core/test_words.gd` | Spec 4.17 and 5.6 for these files: the fog's three accesses (P: an unknown pair's number shown is caught); every word. Lint, check_scripts, GUT green |

### Group E (after D)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| V16 | L, Sonnet | **The peace, goal and goal-line views** | `core/views/peace_view.gd`, `core/views/goal_view.gd`, `core/views/goal_lines.gd` (new); `tests/core/test_peace_view.gd`, `tests/core/test_goal_view.gd`, `tests/core/test_goal_lines.gd` (new) | Spec 5.6 for these files and every state of 6.4 and part of 6.5 as data; `total`'s answer line equals the check's reason (P); `peace_view_ms` measured once by a probe run, in the pull request. Lint, check_scripts, GUT green |
| V17 | M, Sonnet | **Stability, the Relations bytes, the hex card, the hover cards** | `core/views/stability_view.gd`, `core/views/cards_diplomacy.gd` (new); edit `core/views/map_modes.gd` (`RELATIONS`, `relation_bytes`, the ramp, the legend), `core/views/hex_card.gd` (region, unrest, goal, lot); `tests/core/test_stability_view.gd`, `tests/core/test_cards_diplomacy.gd` (new); edit `tests/core/test_map_modes.gd`, `tests/core/test_hex_card.gd` | Spec 6.3's byte table (both palettes' distances), 5.6 for these files: every case and planted fault of spec 9. Lint, check_scripts, GUT green |
| V18 | M, Sonnet | **The country card and the Diplomacy page's view** | edit `core/views/country_card.gd` (the new war, relations and standing fields; M7's `peace` options stay for M7's panel until V27); `core/views/study_diplomacy.gd` (new); `tests/core/test_study_diplomacy.gd` (new); edit `tests/core/test_country_card.gd` | Spec 5.6 for these files, 6.6's four states and 6.9's parts as data; the matrix cells through the fog (P). Lint, check_scripts, GUT green |
| V19 | M, Sonnet (Opus reviews) | **The report, the log, the reminders; the trimmed `WarDef`** | edit `core/views/season_summary.gd` (the `diplomacy` section, the chips, the war line), `core/views/log_lines.gd` (4.16's lines), `core/views/reminders.gd` (4.19's rules, `peace_risk` rewritten), `core/defs/war_def.gd` (the six peace fields removed, now that nothing reads them), `data/defs/war.tres`, `tests/fixtures/report_sample.gd` (a Diplomacy section); edit `tests/core/test_season_summary.gd`, `tests/core/test_log_lines.gd`, `tests/core/test_reminders.gd`, `tests/core/test_war_defs.gd` | Spec 4.16, 4.18, 4.19 and 5.1's `WarDef` line: every sentence and rule with its planted fault; the section equal after a save and load; a grep shows no reader of the removed fields; Opus reads the words. Lint, check_scripts, GUT green |
| V20 | L, Sonnet | **The proofs: properties, contract, saves, the Savoy war** | `tests/core/diplomacy_fixture.gd`, `tests/core/test_peace_property.gd`, `tests/core/test_diplomacy_saves.gd`, `tests/core/test_diplomacy_savoy.gd` (new); edit `tests/core/random_player.gd` (the four new actions, reasons, anchors, deals), `tests/core/test_check_contract.gd`, `tests/core/test_men_property.gd`, `tests/core/test_owns.gd`, `tests/core/test_forty_seasons.gd`, `tests/core/test_insights_views.gd` (the pins) | **Done-when 1, 2, 3, 5, 6, 9, 10** as spec 9 lists them, each with its planted fault; the battle's result pinned for seed 1480. Lint, check_scripts, GUT green |
| V21 | S, Haiku | **The kit pieces: `ScoreBar`, the matrix** | `shell/ui/score_bar.gd` (new); edit `shell/ui/relation_matrix.gd` (two lines, `league`, "?"); `tests/shell/test_score_bar.gd`, `tests/shell/test_relation_matrix.gd` (new); edit `tests/shell/test_kit_feedback.gd` (its matrix cases move to the new file) | Spec 6.12: both forms of the bar; the matrix's cells, keys and hover; Tokens only (the lint). Lint, check_scripts, GUT green |
| V22 | M, Sonnet | **The perf rows** | edit `godot/tools/perf_fixture.gd` (`europe_diplomacy`), `godot/tools/perf_core.gd` (spec 8's rows), `godot/tests/perf_core_budget.json` | Spec 8: every row printed and within its limit on the made-up Europe; a failed row takes section 8's fallbacks in this pull request. Lint, check_scripts, GUT green |

### Group F (after E)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| V23 | L, Sonnet (Opus reviews) | **The AI's door, brief, numbers and war step** | edit `core/ai/ai_know.gd` (spec 5.7's functions), `core/ai/ai_brief.gd`, `core/ai/ai_turn.gd` (the `diplomacy` step, temper overrides), `core/ai/ai_players.gd` (`attach`'s `tempers`), `core/ai/ai_war.gd` (the war step, the goal bonuses); `core/ai/ai_diplo.gd` (new: the step's signature, empty, for V29); edit `core/defs/ai_def.gd` (the sixteen fields; `prize_range` removed), `core/defs/ai_temper_def.gd` (the eight new fields), `core/defs/scenario_def.gd` (no soak temper), `data/defs/ai.tres`, `data/defs/tempers/builder.tres`, `cautious.tres`, `steadfast.tres`, `aggressive.tres`, `opportunist.tres`, `godot/tools/ai_tables.gd`; edit `tests/core/test_ai_defs.gd`, `tests/core/test_ai_know.gd`, `tests/core/test_ai_door.gd`, `tests/core/test_ai_war.gd`, `tests/core/test_ai_turn.gd`, `tests/core/test_ai_fog.gd` | Spec 4.14's tables, the war step and 5.7: every case and planted fault of spec 9 for these tests (P: a declaration at turn 8; `Relations.` in a step module); `ai_season_ms` measured once on the made-up Europe, in the pull request; Opus reads the numbers on the first day. Lint, check_scripts, GUT green |
| V24 | M, Haiku | **The peace screen** | `shell/screens/peace.tscn`, `shell/screens/peace.gd`, `shell/screens/peace/lot_row.tscn`, `shell/screens/peace/lot_row.gd` (new); edit `shell/screens/screen_ids.gd` (`declare_war`); `tests/shell/test_peace_screen.gd`, `tests/shell/test_lot_row.gd` (new) | Spec 6.4: every part and state from `PeaceView` fixtures, the keys; a switch updates the answer line; the art director signs its pictures beside the war-goals design's mockup list. Lint, check_scripts, GUT green |
| V25 | M, Haiku | **The declare-war overlay** | `shell/screens/declare_war.tscn`, `shell/screens/declare_war.gd` (new); `tests/shell/test_declare_war.gd` (new) | Spec 6.5 from `GoalView` fixtures: the reasons and their verdicts, the re-anchor through `set_anchor`, Declare war's verdict, Esc. Lint, check_scripts, GUT green |
| V26 | L, Sonnet | **The map: the Relations mode, the goal outline, the capital** | edit `shell/map/mode_overlay.gd`, `shell/map/mode_overlay.gdshader`, `shell/hud/mode_legend.gd`, `shell/hud/top_bar.gd` (the Relations segment), `shell/mapview/tile_map_view.gd` (`Goals`), `shell/mapview/edge_line_layer.gd` (`goal`, `goal_against`), `shell/map/map_scene.gd` (6.3's functions and refreshes, the ribbons, `district_picked`), `shell/map/capital_marks.gd`, `shell/mapview/country_labels.gd`, `shell/mapview/map_labels.gd` (`capital_moved`), `shell/input/map_input.gd` (`view_mode_7`), `godot/tools/map/probe_mode_overlay.gd`; edit `tests/shell/test_mode_overlay.gd`, `tests/shell/test_map_scene.gd`, `tests/shell/test_layer_stack.gd`, `tests/shell/test_map_input.gd` | Spec 6.3: the texture writes only changed texels (P: one byte, one texel); z 83; the probe's `--plant` FAILs; `relations_mode_ms` and `goal_lines_ms` measured once. Lint, check_scripts, GUT green |
| V27 | M, Haiku | **The country and hex panels** | edit `shell/panels/country_panel.tscn`, `shell/panels/country_panel.gd`, `shell/panels/hex_panel.tscn`, `shell/panels/hex_panel.gd`, `shell/hud/map_hover.gd`, `core/views/country_card.gd` (M7's `peace` options removed); edit `tests/shell/test_country_panel.gd`, `tests/shell/test_hex_panel.gd`, `tests/core/test_country_card.gd` | Spec 6.6 and 6.8's panel and hover lines from the card fixtures: the four states, every verdict, the refreshes. Lint, check_scripts, GUT green |
| V28 | M, Haiku | **The Diplomacy page, the Military page, the report screen** | `shell/screens/study/page_diplomacy.tscn`, `shell/screens/study/page_diplomacy.gd` (new); edit `shell/screens/study.gd` (the nav), `shell/screens/study/page_military.tscn`, `shell/screens/study/page_military.gd` (Wars out), `core/views/study_military.gd` (`wars` out with it), `shell/screens/season_report.gd` (the section); `tests/shell/test_page_diplomacy.gd` (new); edit `tests/shell/test_page_military.gd`, `tests/shell/test_season_report.gd`, `tests/core/test_study_military.gd` | Spec 6.9 and 6.10's report from the view fixtures: every part and empty state; the links. Lint, check_scripts, GUT green |

### Group G (after F)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| V29 | M, Sonnet (Opus reviews) | **The AI's peace and diplomacy** | edit `core/ai/ai_peace.gd` (4.14's table, replacing V12's interim), `core/ai/ai_diplo.gd` (joins, gifts), `core/defs/ai_def.gd` (`yield_ratio` removed), `core/defs/ai_temper_def.gd` (`take_score`, `yield_after` removed), `data/defs/ai.tres`, `data/defs/tempers/builder.tres`, `cautious.tres`, `steadfast.tres`, `aggressive.tres`, `opportunist.tres`, `godot/tools/ai_tables.gd`; `tests/core/test_ai_diplo.gd` (new); edit `tests/core/test_ai_peace.gd`, `tests/core/test_ai_owner.gd`, `tests/core/test_ai_play.gd`, `tests/core/test_ai_defs.gd` | Spec 4.14's peace and diplomacy steps and **done-when 4's** duel and demand: each rule with its check and the offer fallback (P each); the duel's seasons re-pinned as the build gives them; every M8 test green. Lint, check_scripts, GUT green |
| V30 | L, Sonnet | **Wire the App: decisions, chips, the console** | edit `shell/app/game_requests.gd` (6.11's table), `shell/app/app.gd` (the milestone `"9"`; under 800 lines), `shell/app/decision_queue.gd` (6.7's kinds, `drop_offer`), `shell/app/study_warm.gd`, `shell/hud/chips.tscn`, `shell/hud/chips.gd` (Weariness), `shell/hud/hex_menu.gd`, `shell/hud/layers_popover.tscn`, `shell/hud/layers_popover.gd`, `shell/hud/dev_commands.gd`, `shell/hud/debug_overlay.gd`, `shell/hud/action_log.gd` (offer lines open the peace screen), `shell/input/map_input.gd` (`peace_requested`), `godot/README.md`; edit `tests/shell/test_app_flow.gd`, `tests/shell/test_decision_queue.gd`, `tests/shell/test_chips.gd`, `tests/shell/test_hex_menu.gd`, `tests/shell/test_dev_commands.gd`, `tests/shell/test_debug_overlay.gd`, `tests/shell/test_task_flag.gd`, `tests/shell/test_notifications.gd`, `tests/shell/test_action_log.gd`, `tests/shell/test_map_input.gd` (P) | Spec 6.7, 6.10, 6.11 and the end to end of spec 9 (`test_app_flow.gd`); **done-when 12** in the shell tests; still two autoloads. Lint, check_scripts, GUT green |

### Group H (after G)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| V31 | L, Sonnet | **The soak: no runaway winner, wars by terms** | edit `godot/tools/soak.gd` (the `conqueror` suite, the ranges, the summary's columns), `tests/core/invariants.gd` (five invariants), `tests/core/test_invariants.gd`, `tests/core/test_ai_soak_quick.gd`, `core/defs/game_defs.gd` (six tempers), `data/defs/game_defs.tres`, `data/README.md` (the conqueror); `data/defs/tempers/conqueror.tres` (new); edit `.github/workflows/godot.yml` (the conqueror shard), `CLAUDE.md` (the `diplo_tables.gd` and conqueror lines in the Godot block) | Spec 4.23: the suite, every invariant (P each), the ranges and the summary; a full run of every suite on a runner by hand dispatch, the tables in the pull request; **Opus reads them before group I**. Lint, check_scripts, GUT green |
| V32 | M, Haiku | **Monkey, pictures, the UI perf rows** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`, `tests/fixtures/ui_sample.gd` (a war with a demand); the signed pictures as goldens (`godot/tests/goldens/m9_*.png`) | The monkey's invariants green on 3 seeds; spec 9's pictures at 1280 x 720 scale 1 and 2560 x 1440 scale 2, signed by the art director; spec 8's UI rows within their limits. Lint, check_scripts, GUT green |

### Group I (after H)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| V33 | M, Sonnet (Opus decides) | **The tuning pass** | edit `data/defs/diplomacy.tres`, `data/defs/ai.tres`, `data/defs/tempers/*.tres`, `tests/core/test_diplomacy_defs.gd`, `tests/core/test_ai_defs.gd` (the values), `tests/core/test_ai_owner.gd` (pinned seasons), `docs/architecture/m9-build-spec.md` (the tables as `diplo_tables.gd` and `ai_tables.gd` print them; 4.23's ranges where Opus changes one), `docs/architecture/m9-build-plan.md` (section 4's seed) | **Done-when 7 and 8**: every range of spec 4.23 on 100 `ai`, 20 `conqueror`, 20 `passive` and 4 `europe` games with the final data; Opus's verdict and the per-country table in the pull request; **the playtest's seed**: the first seed from 1480 on where a passive Genoa receives a demand within 40 seasons, written into step 8 of section 4. Lint, check_scripts, GUT green |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** signs the state, the save format and the door fields (spec 5.2, 5.4, 4.21) and the acceptance rule
  with the offers (4.6, 4.7) before group A starts; reads the interfaces of V2, V6, V9, V12, V14, V16 and V23 before they merge;
  reads V20's property and save tests and V31's invariants together; reads V22's reach-field numbers.
- **Opus** reads V1's numbers on its first day, V3's regions with the art director, V19's words, V23's temperament and `AiDef`
  numbers on its first day, reviews V29's rules against spec 4.14, reads V31's soak tables before group I and gives V33's balance
  verdict (a changed number is a data edit with the tests it moves, in V33's pull request).
- **The art director** signs V4's sheet, V3's region picture, V24's peace screen beside the war-goals design's mockup list, and V32's
  pictures (the peace screen's states, the overlay with its goal, the Relations mode in both palettes, the country panel, the
  Diplomacy page, the decisions, the report's section).
- **Pull requests** say what changes for the player. V3 changes the map's digest and so the scenario's (`map_digest`): said. V2 makes
  M8 saves unloadable ("Made by an older test build"): said. V12 changes how wars end and moves M7's and M8's pins: said, with the
  list. V13 changes the season's money (two lines): said. V23 and V29 change what the other countries do: said, with the soak's
  tables. No test pins a digest value.

---

## 4. The owner's playtest of M9

On Windows (mouse) and on the MacBook (trackpad), with a fresh user folder.

1. New game, More, seed **1480**, Italy 1480, Play as **Savoy**. Press C, then Milan's link: the panel's Relations reads "They:
   Neutral (0) · You: Neutral (0)"; hover it: no memory yet. Press **Declare war…**: the overlay opens on the left and the map
   shows a gold outline. Conquest is chosen; Reconquest and Contain are greyed (hover: "the Duchy of Milan holds no district you
   lost in the last 80 seasons", "you are in no league against the Duchy of Milan"). Click Domodossola (7, 6) on the map: the
   outline moves; "12 districts, worth 48". Read "They will think −40 of you." Declare war; the toast names the goal.
2. F2: `ai pass MLO` (Milan stays passive; the others play), then `as MLO raise 7 9 pikemen 2`. Raise and march as M7's playtest did (the Army of Ivrea to Domodossola, then Locarno; the Army
   of Vercelli on Alessandria). End seasons to Spring 1481. Watch the **Weariness** chip appear and rise; hover it.
3. Press **7**: the Relations mode. Milan's land is striped red (at war), the opinion colours elsewhere; your land green (calm).
   The gold outline shows your goal. The legend names each colour. Press 2 (Owner): the outline stays.
4. Press **P**: the peace screen. The score bar reads +18 (or +14 if you lost the battle); hover it: the two towns and the battle.
   Press **Best deal**: nine districts and 24 ducats, "They accept." Switch Lugano on: "They refuse: it costs 26, your war score is
   18." Switch it off. Expand Domodossola's lot: its districts one by one. Read the infamy row (+6.0), the unrest row (Lombardy +30)
   and the truce (until Spring 1484). Before you make it: F5, Back, F2 `as MLO offer SAV sue`: "They ask for peace" shows at once
   (idle); **Open the peace screen**: Best deal is already applied; Back; F9. Then P again and **Make peace**.
5. The toast; the report (J): the Diplomacy section ("Infamy 6.0 (+6.0)"), the treasury's "Tribute +24", the war section's peace
   line. Milan's panel: "Truce until Spring 1484", "They: Hostile (−85)"; hover: "You declared war on us −32 · You took our land
   −40 · A truce −10 · Your infamy −3". Declare war… is locked with the truce's reason.
6. Select (8, 6): the hex panel reads "Region: Lombardy · Unrest 40 · restless · taxes here 75 %"; hover the causes. March an army
   onto it; End season: unrest 28 (the conquest term fading, the army −10), calm. The task flag's `restless` line goes.
7. Genoa's panel: Send a gift of 50: Genoa's opinion of you rises by 10; a second gift the same season is refused with "one gift a
   season: the next in ...".
8. Main menu, New game, seed **1480** (V33 replaces it with the first seed from 1480 on where a passive Genoa receives a demand
   within 40 seasons), Play as **Genoa**, raise nothing; `end 4` again and again: the war alert names Milan's reason and goal (never
   before Spring 1482); the task flag's `peace_risk`; then **A demand** in the decisions: **Refuse**; Milan's panel shows its
   opinion of you 10 lower. When the next demand is pending: F5, F2 `digest`, F9, F2 `digest`: the same; the demand is still in
   Milan's panel and the task flag's `demand_open`. Play on until the peace is imposed: the peace alert says so.
9. Main menu, New game, seed 1480, Savoy. F2 `infamy MLO 300`; End season: **A league** in the decisions: **Join the league**.
   Milan's panel: "In the league against them"; Declare war… now allows **Contain** ("no infamy for the goal").
10. Press I, then `]` to Diplomacy: the matrix (your row's hover shows numbers; two others' cell shows a word or "?"), the Wars table
    (moved from Military), the war scores, the Leagues table with yours, the infamy and weariness chart, the Unrest table ("Show on
    map" switches to Relations).
11. Options, Map: "War goals on the map" off: the outlines go; the Layers popover's switch turns them on again.
12. Main menu, New game, seed 1480, and in the pick F2 `watch`; `end 40`: the log's peace lines name what moved ("Peace between ...:
    Milan took 12 districts"); a league may form; the Diplomacy page's Wars table lists deals, white peaces and surrenders, few
    timers. Note who grows and whether anyone runs away.

---

## 5. Definition of done

1. The spec's "M9 is done when" items 1 to 13 hold.
2. Tasks V1 to V33 merged; CI green, with both UI `--check`s, `build_map --check`, `build_scenario.gd --check`, and the nightly
   `soak` (with the `conqueror` shard), `soak-ranges`, `perf_core` and `perf_ui` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac.
5. `godot-architecture.md` 9.2 marks M9 done; `godot/README.md` describes the M9 game.
6. Section 7 below is handed to the M10, M11 and M12 build specs' authors.

---

## 6. How to start

On the day M8 closes:

1. Opus presents the numbers (spec 4.2 to 4.13: the worth table, the prices, the league and the brakes) and the two worked wars
   (4.22) to the owner and Fable in 30 minutes; a changed number is a data line now, not a task later. Fable signs the state, the
   save format, the acceptance rule and the offers the same day.
2. Start group A together: **V2, V3** (Sonnet) and **V1, V4, V5** (Haiku). Opus reads V1's numbers on its first day; the art
   director and Opus see V3's region picture on its last.
3. V6 runs its reach-field scratch run on the made-up Europe in its last day, so section 8's fallback is chosen before V13 and V22
   build on it.
4. V31's first full soak goes to Opus the day it runs; group I waits for Opus's reading.

---

## 7. What M9 hands on

- **M10:** trade agreements and embargoes as relations (a memory reason and a standing term each, a matrix state), a deal row for
  trade rights, `Treasury.WHY` `trade`, road works dropping reach fields (taken up in `m10-build-spec.md`; roads do not change
  reach fields, its D46).
- **M11:** techs changing `DiplomacyDef` through definitions only (goal size, the outside price, infamy's fade, `reach_free`); an
  idea card against weariness (taken up in `m11-build-spec.md` 4.3 to 4.6).
- **M12:** countries that fall (`keep_last_district` off, `Countries.fall`, wars ended with terms `fallen`); the debt row in
  `declare_war_check`; infamy and weariness for the score; a difficulty that may scale `enforce_net` (taken up in
  `m12-build-spec.md`: infamy counts, weariness and a difficulty do not).
- **After M12:** alliances and calls to arms; rebels and free states on the defiant band, `gained`, `former` and the regions;
  historical claims on the Europe map.
- **E2, E3:** regions for Europe in E2's map build; the reach and league numbers re-tuned there; section 8's rows on the real map.
- **Saves:** `SaveFile.FORMAT` 7; a new body field with a default needs no bump (M3 4.10).
