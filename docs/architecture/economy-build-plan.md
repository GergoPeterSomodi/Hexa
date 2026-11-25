# Economy build plan: raw materials, workshops in settlement slots, workers, arms, bread (M9.5, issue 439)

Technical director, 2026-11-25. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/economy-build-spec.md` ("the spec"), which builds `docs/design/economy-rethink.md` revision 3 with the
owner's answers.

**When it runs.** After M9 (diplomacy) is merged and played, and before M10 (trade); the tile window (issue 436) is on master
with its Town tab. The core groups (A to D) need only the owner's go on this plan; the shell group (E) also needs the gate
mockup (EC0) approved. M9.5 changes rules, saves, the AI and the Town tab; it adds no screen and no tab.

**Task IDs** are `EC0` to `EC21`.

---

## 1. Groups, effort, order

S is about half a day of one worker, M a day, L two days.

| Group | Ships | Tasks | Effort |
|---|---|---|---|
| **Gate. The mockup** | the Workshops strip, the plaque bar, the Slots chip, locked and idle tiles, the workshop card with its Buy inputs switch, the arms banner; approved by the owner | EC0 | 1 M |
| **A. Data and state** | three goods, three industries, the economy numbers, the fixture that keeps every old pin; slot arrays, the workshop work, the save format; flow and line names; the icons | EC1 to EC4 | 1 L, 1 M, 2 S |
| **B. The rules, part 1** | slots and the workshop works, gates, tier, raw at hand, workers; the home market and arms for raising; the growth multiplier | EC5 to EC7 | 1 L, 2 M |
| **C. The rules, part 2** | the season step (needs, works, comfort, sales, money); the read models of the tile window; words, events, log, stats | EC8 to EC10 | 1 L, 2 M |
| **D. Previews** | the preview equal to the season with workshops; the workshop card; the economy report | EC11, EC19 | 1 L, 1 S |
| **E. Surfaces and the AI** | the AI's option, weights, buying step, priced raises and war gate; the Town tab; the Army tab; the Study, report and reminders; the map marks | EC12 to EC16 | 2 L, 1 M, 2 S |
| **F. Proofs** | the soak's industry suite and invariants; the monkey and the perf rows | EC17, EC18 | 2 M |
| **G. Balance** | the measured tuning pass | EC20 | 1 M |
| **H. Finish** | docs, amendments, pictures, goldens | EC21 | 1 M |

**22 tasks: 6 L, 11 M, 5 S**, about 25.5 worker-days; about 13 working days end to end (each group as long as its longest
task), plus the gate, reviews and the owner's playtest.

```
owner's go
  -> A:  EC1 (L)  EC2  EC3 (S)  EC4 (S)            EC0 (the gate mockup) runs beside A to D
  -> B:  EC5 (L)  EC6  EC7
  -> C:  EC8 (L)  EC9  EC10
  -> D:  EC11 (L)  EC19 (S)
  -> E (and EC0 approved):  EC12 (L)  EC13 (L)  EC14 (S)  EC15  EC16 (S)
  -> F:  EC17  EC18
  -> G:  EC20
  -> H:  EC21   -> the owner plays the checklist of section 6

Critical path: EC1 -> EC5 -> EC8 -> EC11 -> EC12 or EC13 -> EC17 -> EC20 -> EC21
```

**Parallelism rules.** A group starts when every task of the group before it is merged. Inside a group no two tasks touch one
file and no task calls code another task of its group writes. Every merge leaves the suite green: a task that changes a
committed number changes the tests that pin it, or the fixture keeps them (spec R70). Shared files have one owner each:
`tests/core/industry_fixture.gd` and `tests/core/economy_fixture.gd` EC1; `tests/core/random_player.gd` EC5;
`tests/core/invariants.gd` EC17; `tools/perf_fixture.gd`, `tests/perf_core_budget.json`, `tests/perf_ui_budget.json` EC18 (EC5
records the baseline in its pull request without editing them); the Kit icons (`tools/bake_ui.py`, `godot/assets/ui/kit/`)
EC4; `tools/build_theme.gd` and both themes EC13; `data/defs/game_defs.tres` EC1 (later tasks edit their own `.tres` files:
units EC6, families EC8, tempers and `ai.tres` EC12, the numbers in EC20).

---

## 2. Tasks

*Sonnet* builds everything in `core/`, the AI, the shell, `Session` and the tools' logic; *Haiku* builds the mockup, the
icons, the monkey, the perf rows, the report tables and the pictures. **Every task's done-when includes: lint (`python
tools/lint_godot.py godot`), check_scripts, GUT, both UI `--check`s, `build_tile_tabs.gd --check`, `build_scenario.gd
--check` and `bake_ui.py --check` green; no planted fault (P) of an edited test deleted without a replacement; no game window
opened without the owner's go; every pinned number it moves is listed in its pull request with the reason.** Paths without a
prefix are under `godot/`; `tools/` (Python), `docs/`, `README.md`, `CLAUDE.md`, `.github/` at the repository root.

### Gate

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| EC0 | M, Haiku (art director leads, creative director reviews) | **The mockup** | an HTML mockup outside the repository (`mockups/`), shared as a private page | The owner's v4 Town tab with: the Workshops strip in its four moments (1480 all locked; 1485 one ready; a walled town with two built, one building, one idle; a city full), the plaque's count and bar on every strip, the Slots chip, every tooltip of spec 6.3, the workshop card with the Buy inputs switch, the Army tab's arms banner and a refused raise; the owner has approved it (open questions 3, 4 and 6 are answered on it) |

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| EC1 | L, Sonnet | **Defs, data and the fixture** | new `core/defs/industry_def.gd`, `core/defs/economy_def.gd`, `data/defs/industries/weaver.tres`, `armourer.tres`, `bakery.tres`, `data/defs/economy.tres`, `data/defs/goods/cloth.tres`, `arms.tres`, `bread.tres`, `tests/core/industry_fixture.gd`, `tests/core/test_industry_defs.gd`; edit `core/defs/good_def.gd` (COUNT 19, the made kind, `food_permille`, validate), `core/defs/game_defs.gd` (`industries`, `economy`, lookups, validate, digest), `data/defs/game_defs.tres`, `data/defs/goods/grain.tres`, `fish.tres` (`food_permille` 1000), `tests/core/economy_fixture.gd` (`industry` argument, off by default), `tests/core/test_good_defs.gd`, `test_economy_defs.gd` | Spec R1 to R3, R7, R70 (the fixture's `off` and `on`, written against today's unit costs and `keep_wild` so it is a no-op until EC6 and EC8 change them): the tables of R1 to R3 exactly; validate's P cases; with the fixture off, the whole suite green unchanged; tests on the committed defs that see 19 goods and 2 arms at the start are fixed and listed |
| EC2 | M, Sonnet (technical director reads) | **State, saves, digest** | new `tests/core/test_slot_state.gd`; edit `core/state/map_state.gd` (three arrays, schema), `core/state/state_view.gd` (`with_slots`, readers), `core/state/work.gd` (`industry`, `workshop`, `work/3`), `core/game/save_file.gd` (FORMAT, OLDEST_FORMAT, the format note), `core/game/snapshot.gd` (only if its type checks need it), `tests/core/test_state_view.gd`, `test_save_file.gd`, `test_snapshot.gd`, `test_war_save.gd`, `test_country_state.gd` | Spec R9 to R11, R13, R14: arrays sized and copied; the old schema reads empty; the overlay never writes the base (P); FORMAT master's + 1 and an older file "older" (P); save, load, save byte-equal with planted slots and a workshop work; the flags in the digest (P); pinned digests re-pinned once, each listed |
| EC3 | S, Sonnet | **Flow and line names** | edit `core/systems/stores.gd` (FLOWS + `worked`, `bought`, `crafted`), `core/systems/treasury.gd` (WHY + `upkeep_workshops`, `inputs_bought`, `arms_bought`; SPENDING + `arms_bought`), `core/views/words.gd` (their words: "Workshop upkeep", "Inputs bought", "Arms bought", "worked", "bought", "made in workshops"), `tests/core/test_stores.gd`, `test_treasury.gd`, `test_words.gd` | Spec R40's names: appended, never reordered; `left_over` leaves `arms_bought` out; flows and lines round-trip in a save |
| EC4 | S, Haiku (art director signs) | **Icons** | edit `tools/bake_ui.py` (the icon recipes) and the baked kit in `godot/assets/ui/kit/` | Eight Kit icons in the Studiolo style: `good_cloth`, `good_arms`, `good_bread`, `ind_weaver` (loom), `ind_armourer` (anvil), `ind_bakery` (loaf), `workshop` (the group), `slots` (the chip); `bake_ui.py --check` green; a sheet signed by the art director |

### Group B (after A, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| EC5 | L, Sonnet (technical director reads the interfaces) | **Slots and the workshop works** | new `core/systems/slots.gd`, `core/systems/industry.gd`, `tests/core/test_slots.gd`, `test_industry_actions.gd`, `test_industry_rules.gd`; edit `core/systems/works.gd` (`industry_open`, `stage_max`, `workshop_cost`, `_begin_workshop`, the workshop path of `_put_piece`, seasons and cost by industry, the "works crew" words of D7), `core/systems/improve.gd` (`clear_here` calls `Slots.clear_hex`), `core/systems/economy.gd` (`jobs_i` adds `Industry.jobs_at`; `staffing` of a settlement with working slots), `core/systems/district_cache.gd` (slot jobs in `F_JOBS`; touched by `Slots`), `core/systems/season_profile.gd` (its key gains the slot arrays' hash), `core/game/actions.gd` (three actions), `core/views/works_view.gd` (labels "weaver, first stage", "weaver, first to second stage"), `core/views/tile_buildings.gd` (only `blocked_by` reading "no free works crew"), `tests/core/random_player.gd` (three pairs), `test_works.gd`, `test_improve_actions.gd`, `test_check_contract.gd`, `test_owns.gd`, `test_no_other_writers.gd`, `test_economy.gd`, `test_district_cache.gd`, `test_season_profile.gd`, `test_works_view.gd` | Spec R12, R15 to R23, R25 to R29, D5 to D7: every row of R17 and R18 in order, each with its words and `kind`; the gate at Winter 1489 and Spring 1490 (P); one of each; the check/act pair over every settlement of three countries (P); idle by level, occupation and siege, and waking (P); capture hands over; clearing drops (P); workshop jobs in a neighbour's staffing (P); raw at hand: own, foreign (P), stage 1 (P), 2, 3, ties; `output` floors; the perf baseline of spec 10 measured at the start and put in the pull request |
| EC6 | M, Sonnet | **The home market and arms for raising** | new `core/systems/buying.gd`, `tests/core/test_buying.gd`, `test_military_arms.gd`; edit `core/systems/military.gd` (`arms_quote`, the arms step of `raise_check`, `raise`'s bought arms and line, `raise_options` text), `data/defs/units/pikemen.tres`, `crossbowmen.tres`, `knights.tres`, `bombards.tres` (R4), `tests/core/test_military.gd`, `test_unit_defs.gd`, and the raise tests the change reaches (`test_ai_forces.gd`, `test_army_share.gd`, `test_log_others.gd`, `test_movement_war.gd` where they run on the committed defs) | Spec R4, R31, R45 to R48: price per good and permille 0; plan in batches at a budget; take moves `bought` only; a stub market test (the M10 seam); raise with own arms, bought arms, the reserve used, neither (refusal, nothing changed: P), market off; the arms_bought line at the hex; the check/act pair with arms (P); with the fixture off every M6 to M8 pin unchanged |
| EC7 | M, Sonnet | **Growth from surplus and prosperity** | new `core/systems/growth.gd`, `tests/core/test_growth.gd`; edit `core/systems/people.gd` (`_rule` and `rule_of` take `mult`; `season` computes it per country by `Growth.of_flows`; `fed_of` in food units), `tests/core/test_people_growth.gd`, `test_people_season.gd`, `test_people.gd`, `test_cards_people.gd` | Spec R33's `fed_of`, R42 to R44: 40 seeded cases of `mult`; the surplus clamp and need 0; comfort parts (cloth, bread) on planted flows; hunger untouched (P); with the fixture off (mult 1000) every M5 pin unchanged; `of_flows` and `of_step` agree on planted arrays (`of_step` is used by EC11) |

### Group C (after B, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| EC8 | L, Sonnet (technical director and systems designer read) | **The season step** | new `tests/core/test_workshop_season.gd`, `test_industry_numbers.gd`; edit `core/systems/economy_season.gd` (`goods_step` with food units, bread first up to the share, works, cloth comfort, sales; `reserve_for` for bread; `content_of` in units; `production` applying the moves in R36's order; `money_lines` and `income` with `upkeep_workshops` and `inputs_bought`; the floor), `data/defs/families/hemp.tres`, `silk.tres`, `dyes.tres`, `vineyard.tres`, `olives.tres` (`keep_wild` 0), `tests/core/test_economy_season.gd`, `test_money_property.gd`, `test_economy_genoa.gd`, `test_economy_1480.gd`, `test_family_defs.gd`, `test_economy_preview.gd` (only where `goods_step`'s new keys appear) | Spec R5, R30, R32 to R39, R41's inputs: the step order (P: works before needs); own then bought; the floor (P); the switch; the reserve never lowered by a workshop (P); needs met and reserve unchanged after the works step over 40 seeded seasons; bread as 1.5 units (P: one unit); cloth comfort; the move order never below 0; flows and money identities; upkeep only for working slots; bought input paid once (P); `test_industry_numbers.gd` pins every cell of the design's section 5 as integers; with the fixture off Genoa's table unchanged |
| EC9 | M, Sonnet | **The tile window's models** | new `tests/core/test_tile_workshops.gd`, `test_industry_fog.gd`; edit `core/views/tile_view.gd` (Slots chip with `tip`, `raw`, `workers`, `growth`, foreign slot buildings and count), `core/views/tile_buildings.gd` (the Workshops group, its rows and states including `idle`, `gate_of` from `kind`, `slots`, every group's `workforce` and `tip`, each row's `tip`), `core/views/tile_army.gd` (the arms banner), `core/views/company_card.gd` (the arms line), `core/views/map_modes.gd` (`food_year` with the bakery), `tests/core/test_tile_view.gd`, `test_tile_buildings.gd`, `test_tile_army.gd`, `test_company_card.gd`, `test_tile_fog.gd`, `test_tile_door.gd`, `test_fog_exact.gd`, `test_map_modes.gd` | Spec R24, R53 to R60's model fields, section 6.1 and the words of 6.3 (from the models: P a word built elsewhere), section 7: Genoa through 1480, 1485, 1490, 1520; a ready row for a closed industry (P); a hammer against its check over every row of three settlements (P); bar values within max (P); the twin test with slots (P); no output of a foreign slot (P); workshop row gains stay `null` until EC11 (the tab shows no number) |
| EC10 | M, Sonnet | **Words, events, log and stats** | new `core/views/log_lines_industry.gd`; edit `core/game/season.gd` (the `calendar` row calls `Industry.season_news`), `core/views/log_lines.gd` (dispatch only), `core/state/chronicle.gd` (`industry_opened` notable), `core/state/stats.gd` (SERIES appended), `core/systems/stats_system.gd` (the new series), `shell/autoload/session.gd` and `shell/autoload/events.gd` (the two events), `tests/core/test_log_lines.gd`, `test_stats.gd`, `test_chronicle.gd`, `test_season.gd` (names unchanged; the news case) | Spec R41, D19, the events of section 4: one `industry_opened` per industry per game in its year's first season (none in a sandbox); log lines for workshop works, `buy_inputs_set` and the openings; the stats columns filled and an older stats dict loading with zeros; the phase names unchanged |

### Group D (after C, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| EC11 | L, Sonnet (technical director reads) | **The preview and the workshop card** | new `core/views/workshop_preview.gd`, `tests/core/test_workshop_preview.gd`; edit `core/views/economy_preview.gd` (the working list per season from its view with `changes.slots`, the running treasury, the step's new keys, `money_lines` with the workshop numbers, the people step with `Growth.of_step`), `core/views/improve_preview.gd` (workshop options in `options_of`, `of` delegates; only the delegation lines: the file is allowlisted and must not grow past its count), `tests/core/test_economy_preview.gd`, `test_improve_preview.gd`, `test_ai_preview_share.gd` | Spec R50 to R52: 200 seeded cases including builds, upgrades, gates, the switch, the floor, bread, cloth and raises, preview equals season to the unit (P: the preview reading the game's treasury after season 1); the card's workshop section; its gain equals EconomyPreview's year difference (P); the at-hand hex in the card's marks; `TileBuildings`' workshop rows now carry gains (EC9's `null`s filled) |
| EC19 | S, Haiku | **Economy report and tables** | edit `tools/economy_report.gd` (the industry block: per country and slot used, bought, crafted, worth, tier, at hand; the new lines), `tools/economy_tables.gd` (the industries table, the economy numbers) | `economy_report.gd -- --seeds=1480-1484 --seasons=60` prints the block; the tables print spec R1 to R4's numbers from the defs; no rule code touched |

### Group E (after D and the gate, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| EC12 | L, Sonnet (technical director reads the prior) | **The AI** | new `tests/core/test_ai_industry.gd`; edit `core/ai/ai_economy.gd` (workshop options in `_scan_hex`, their prior, the weights, the siting priority and slot value), `core/ai/ai_know.gd` (`workshop_options`, `input_surplus`, `slots_seen`, `arms_quote`: the door), `core/ai/ai_forces.gd` (priced raises), `core/ai/ai_war.gd` (the arms blocker line, the prize term), `core/ai/ai_turn.gd` (the `buying` step after `works_act`), `core/defs/ai_temper_def.gd` (`industry_priority`), `core/defs/ai_def.gd` (`arms_priority`, `at_hand_priority`, `slot_value`, `war_arms_companies`, `industry_value`), `data/defs/tempers/*.tres`, `data/defs/ai.tres`, `tests/core/test_ai_economy.gd`, `test_ai_turn.gd`, `test_ai_war.gd`, `test_ai_door.gd`, `test_ai_fog.gd`, `test_ai_determinism.gd`, `test_ai_forces.gd` | Spec R64 to R69: the prior on four fixture towns (own wool, bought only, a loss: 0, an upgrade); the weights table; siting priority; the buying step's switches and the armourer's exception; a raise priced with arms never refused for money (P); the blocker line and peace still made at war; the prize term; the traces; the door scan lists the new reads; the fixture games' determinism digests unchanged (P: the blocker firing under the fixture) |
| EC13 | L, Sonnet | **The Town tab and the workshop card** | new `tests/shell/test_town_workshops.gd`, `tests/shell/test_workshop_card.gd`; edit `shell/panels/tile_tabs/building_strips.gd`, `shell/ui/building_row.gd`, `shell/ui/strip_cells.gd`, `shell/panels/tile_tabs/land_facts.gd`, `core/views/building_card.gd` (the workshop sections), `shell/screens/works_preview.gd` (the workshop section and the switch), `shell/app/works_flow.gd` (`workshop_card`), `tools/build_theme.gd`, `shell/ui/theme.tres`, `shell/ui/theme_high_contrast.tres` (`PanelTileTileIdle`), `tests/shell/test_town_tab_strips.gd`, `test_building_row.gd`, `test_tile_window_tips.gd`, `test_works_preview.gd`, `test_works_flow.gd`, `tests/core/test_building_card.gd` | Spec R55 to R57, R59, R61, section 6.2 against the approved EC0 mockup: the Workshops strip, plaque count and bar with tooltips, the idle tile, locked tiles' words, the Slots chip, the raw, workers and growth lines; a click on a built tile opens the card (P: on a foreign tile); the switch acts through `Session.act` (P); no word formatted in the shell (P); `build_theme.gd --check` green |
| EC14 | S, Sonnet | **Arms on the Army tab** | edit `shell/panels/tile_tabs/army_tab.gd`, `shell/screens/raise_screen.gd`, `shell/ui/company_row.gd`, `tests/shell/test_army_tab.gd`, `test_raise_screen.gd` | Spec R60 shown: the arms banner when present; the arms part of each row's line; the refused row's words; the card's arms line |
| EC15 | M, Sonnet | **Study, report and reminders** | new `core/views/summary_industry.gd`; edit `core/views/study_economy.gd` (19 goods, the three columns, the Industries list), `core/views/season_summary.gd` (calls `SummaryIndustry` only), `core/views/reminders.gd` (the opening reminder), `core/views/study_people.gd` (the growth word), `core/views/cards_economy.gd` (the new lines' cards), `shell/screens/study_pages.gd` (the Industries list and columns, if the page lays them out), `tests/core/test_study_economy.gd`, `test_season_summary.gd`, `test_reminders.gd`, `test_study_people.gd`, `test_cards_economy.gd`, `tests/shell/test_study.gd` | Spec R63: the columns and the list (open, "opens in 1490"); the treasury page's three lines; "Industry added +64 this year" equal to the year's crafted worth less the input's worth and the upkeep; the reminder for four seasons after an opening with a free slot, gone when built; `season_summary.gd` grows by its call lines only |
| EC16 | S, Sonnet | **Map marks** | new `core/views/workshop_marks.gd`, `shell/map/workshop_marks.gd`, `tests/core/test_workshop_marks.gd`, `tests/shell/test_workshop_marks_layer.gd`; edit `shell/map/map_scene.gd` (adds the layer) | Spec R62, section 7: one mark per working slot beside its settlement; none on undiscovered hexes (P) or for idle slots; the layer redraws on `game.version` only |

### Group F (after E, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| EC17 | M, Sonnet (systems designer reads) | **The soak's industry suite and invariants** | edit `tools/soak.gd` (suite `industry`: each seed as A and B, spec D31), `tools/soak_game.gd` (the records of spec 9), `tools/soak_ranges.gd` (the `industry` rows), `tests/core/invariants.gd` (the seven invariants of spec 9), `tests/core/test_invariants.gd` (a planted break each), `tests/core/test_ai_soak_quick.gd`, `.github/workflows/godot.yml` (the nightly `soak-ranges` job runs the suite) | Spec section 9: each invariant caught on a planted break; `soak.gd -- --suite=industry --quick` runs both twins and prints the table; a failure prints its replay line |
| EC18 | M, Haiku | **Monkey and perf rows** | edit `tests/shell/monkey_tile.gd` (the workshop step and invariants), `tests/shell/test_ui_monkey.gd`, `tools/perf_core.gd`, `tools/perf_fixture.gd` (`europe_industry`), `tests/perf_core_budget.json`, `tools/ui/perf_ui_tile.gd`, `tests/perf_ui_budget.json` | Spec 8.4 and 10: invariants green on 3 seeds (one prepared past 1490), counters above 0; every row within its limit against EC5's baseline, both tables in the pull request; a row past its limit takes the spec's fallback in this task |

### Group G (after F)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| EC20 | M, Sonnet (systems designer measures and signs) | **The balance pass** | edit data only: `data/defs/economy.tres`, `data/defs/industries/*.tres`, `data/defs/units/*.tres` (ducat costs only), `data/defs/tempers/*.tres`, `data/defs/ai.tres`; `tools/soak_ranges.gd` (the measured values of the `ai` suite's moved ranges and the `industry` ranges kept); `tests/core/test_industry_numbers.gd` and the pins of any number moved | The full `industry` suite (10 seeds, 160 seasons) and the full `ai` suite meet their ranges; the pull request has both tables before and after each change, the levers moved and why; no rule code touched |

### Group H (after G)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| EC21 | M, Haiku (art director signs) | **Docs, amendments, pictures** | edit `README.md` (the workshops, slots, tiers, raw at hand, buying, bread, arms, growth: plain tables from the defs), `godot/README.md`, `CLAUDE.md` (the soak line names the `industry` suite), `docs/design/economy-rethink.md` (status built; FORMAT; spec D9, D10, D12; section 5's integers from `test_industry_numbers.gd`), `docs/architecture/m9-build-spec.md`, `m10-build-spec.md`, `m11-build-spec.md`, `tilewin-build-spec.md` (spec Appendix A), `docs/roadmap/roadmap.md` (M9.5 built); edit `tools/ui/shot_ui_tile.gd` and the scenes of spec 8.3; the regenerated goldens | Spec 8.3: **the owner is asked before the windowed run**; the pictures at both scales signed against EC0; changed goldens reviewed side by side; README's tables equal the defs (the reviewer checks each number) |

---

## 3. Tests that move

The full table is spec 8.2; by task:

- **EC1:** `test_good_defs.gd`, `test_economy_defs.gd` (19 goods, the made kind). Tests on the committed defs that see the 19
  goods or the 2 start arms (scenario and start-stock tests) are fixed and listed; everything through `EconomyFixture.defs`
  stays unchanged because the fixture is off by default (the whole point of the task).
- **EC2:** `test_save_file.gd`, `test_snapshot.gd`, `test_war_save.gd`, `test_country_state.gd` (FORMAT, round trips, the one
  digest re-pin); `test_state_view.gd` (the overlay).
- **EC3:** `test_stores.gd`, `test_treasury.gd`, `test_words.gd` (appended names).
- **EC5:** `test_works.gd` and `test_improve_actions.gd` ("works crew" words; the workshop path), `test_check_contract.gd`
  and `random_player.gd` (three pairs), `test_owns.gd`, `test_no_other_writers.gd`, `test_economy.gd`,
  `test_district_cache.gd`, `test_season_profile.gd`, `test_works_view.gd`.
- **EC6:** `test_military.gd`, `test_unit_defs.gd` (arms); the raise tests on the committed defs (the design names
  `test_ai_forces.gd`, `test_army_share.gd`, `test_log_others.gd`, `test_movement_war.gd`): each either moves to the fixture
  or pins the arms text, with the reason.
- **EC7:** `test_people_growth.gd`, `test_people_season.gd`, `test_people.gd`, `test_cards_people.gd` (`fed_of` in units;
  `mult` 1000 under the fixture).
- **EC8:** `test_economy_season.gd`, `test_money_property.gd`, `test_economy_genoa.gd`, `test_economy_1480.gd` (unchanged
  under the fixture; new keys of the step), `test_family_defs.gd` (`keep_wild`).
- **EC9:** `test_tile_view.gd`, `test_tile_buildings.gd`, `test_tile_army.gd`, `test_company_card.gd`, `test_tile_fog.gd`,
  `test_tile_door.gd`, `test_fog_exact.gd`, `test_map_modes.gd`.
- **EC10:** `test_log_lines.gd`, `test_stats.gd`, `test_chronicle.gd`, `test_season.gd` (names unchanged).
- **EC11:** `test_economy_preview.gd` (the 200 cases), `test_improve_preview.gd`, `test_ai_preview_share.gd`.
- **EC12:** `test_ai_economy.gd`, `test_ai_turn.gd` (the `buying` step), `test_ai_war.gd`, `test_ai_door.gd`, `test_ai_fog.gd`,
  `test_ai_determinism.gd` (digests re-pinned), `test_ai_forces.gd`.
- **EC13 to EC15:** `test_town_tab_strips.gd`, `test_building_row.gd`, `test_tile_window_tips.gd`, `test_works_preview.gd`,
  `test_works_flow.gd`, `test_building_card.gd`, `test_army_tab.gd`, `test_raise_screen.gd`, `test_study_economy.gd`,
  `test_season_summary.gd`, `test_reminders.gd`, `test_study_people.gd`, `test_cards_economy.gd`, `test_study.gd`.
- **EC17:** `test_invariants.gd`, `test_ai_soak_quick.gd`.
- **Unchanged, must stay green:** every rule test through `EconomyFixture.defs`, `test_season.gd`'s phase list,
  `test_replay*.gd`, `test_battles.gd`, `test_combat*.gd`, `test_supply.gd`, `test_occupation*.gd`, `test_wars*.gd`,
  `test_sight.gd`, `test_fog_views*.gd`.

**Goldens and pictures** change once, in EC21 (spec 8.3). **The worked-numbers test** (EC8) is the bridge between the design
and the code: its integers go into the design's section 5 in EC21.

---

## 4. Monkey, soak and performance

**Monkey (EC18).** `MonkeyTile` gains the workshop step and its invariants (spec 8.4): hovers, ready hammers, the workshop
card, the Buy inputs switch; counters `workshop_cards`, `buy_switches`, `workshop_builds` above 0 on at least one of three
seeds (one a prepared state past 1490, so the gate is open).

**Soak (EC17, measured in EC20).** Invariants every season in every suite (spec 9); the new `industry` suite with its twin
ranges. How balance is measured: the same 10 seeds and AI play A (the rules) and B (no industry ever opens); per country at
year 40, crown income A over B is the industry's worth, the bought share watches the unlimited-supply loophole, men under arms
and refusals watch the arms drag, people watch the growth rule; the `ai` suite's M8 ranges are re-measured once. The levers
are data only (spec 9); every change in EC20 shows both tables.

**Perf (EC5, EC18).** EC5 records the baseline of spec 10's rows before its rules land; EC18 adds the new rows and the
industry rig and measures all. A row more than 5 % slower than the baseline, or past its limit, takes the spec's fallback in
EC18's pull request.

---

## 5. Determinism, saves and replay

- **Determinism.** No new luck. Order is fixed everywhere (countries by id, settlements by index, slots by position, goods by
  id). The AI's jitter is drawn once per card as today; a seat with no workshop option draws the same numbers as before.
  Pinned digest texts change once in EC2, because the digest now covers the slot arrays (its shape, not the play). After
  EC2, under `IndustryFixture.off` the fixture games' digests do not move (every task keeps them, EC12 included: with no open
  industry, no arms in any cost and the market off, the AI's new option, step and blocker change nothing). Digests of games on
  the committed defs move with the rules; each is re-pinned once, in the task that moves it, with the reason.
- **Saves.** `SaveFile.FORMAT` = master's + 1 (8 if M9 has not landed, 9 if it has), `OLDEST_FORMAT` the same: an older save
  reads "Made by an older test build" and is not loaded (the owner's Q10: public save compatibility starts at M12). The body:
  `map_state` with the three slot arrays (schema one up), works with `industry` (`work/3`), goods arrays of 19, the appended
  flows, lines and stats columns. Save, load, save is byte-equal (EC2, again on a played game in EC17's quick soak).
- **Replay.** The action log gains `build_workshop`, `upgrade_workshop` and `set_buy_inputs`; replays look them up in the one
  action table, so nothing else changes. A replay from an older format is refused with its save.
- **Later milestones.** M10 and M11 take the next FORMAT numbers and schema numbers (spec Appendix A, written by EC21).

---

## 6. Reviews and the owner's playtest

- **The code reviewer** reads every task; for EC5 it checks each refusal row against its words and `kind`; for EC8 the step
  order and the move order; for EC11 the 200 cases; for EC13 that no word is formatted in the shell.
- **The technical director** reads EC2 (state and saves), EC5's interfaces before they merge, EC8 and EC11 together (the
  preview equals the season), EC12's prior and EC18's perf tables.
- **The systems designer** reads EC8's worked numbers, EC17's ranges and runs EC20.
- **The art director** leads EC0 and signs EC4's icons and EC21's pictures; **the creative director** reviews EC0 before
  the owner sees it.
- **Pull requests say what changes for the player.** Nothing the player sees changes before EC5 (workshops can be ordered by
  the action, not yet by the window) and EC13 (the Town tab); EC6 changes raising (arms); EC7 slows growth; EC8 makes bread
  food and drops the second yield of five district kinds.

**The owner's playtest** (Windows, fresh user folder):

1. New game, Italy 1480, play as Genoa. Click Genoa: the Town tab shows a **Workshops** strip with three locked tiles
   ("opens in 1485", "1490", "1495"), the plaque "0 / 4 slots" and the **Slots** chip "0 / 4". Hover each tile and the plaque.
2. The Land and Settlement strips' bars and their tooltips (workers; people of room). The land facts' raw and workers lines.
3. Army tab at Genoa: the arms banner. Raise pikemen until the stores' 2 arms are used: the next one says "1 bought, 14
   ducats". Spend the treasury down and try again: the refusal line names arms, stores and ducats.
4. Play to Spring 1485: the log says the armourer's craft is open. Build an armourer: the job line shows it; Cancel gives the
   money back the same season; build again; four seasons later the tile shows I and "Working".
5. Try to upgrade Genoa's level while a workshop is building: refused ("a work is under way here").
6. Click the built armourer: its card shows the recipe, the tier (125 % in a city), raw at hand (or none) and the Buy inputs
   switch. Switch it off, end a season: no "Inputs bought" line; on again: the line returns.
7. Play to 1495 and build a bakery: the Study's goods page shows bread, worked and bought columns; the town's food line shows
   bread; the growth word changes.
8. A foreign town in light fog: its workshops show with "working", and no numbers.
9. The map shows small trade marks beside towns with working workshops.
10. The report: "Industry added +N this year"; the treasury page: Workshop upkeep, Inputs bought, Arms bought.
11. Load a save from before this build: "Made by an older test build".
12. Look at EC21's signed pictures.

---

## 7. Definition of done

1. The spec's done-when items 1 to 8 hold.
2. EC0 approved; EC1 to EC21 merged; CI green with the nightly `perf_core`, `perf_ui`, `soak` and `soak-ranges` jobs within
   limits.
3. Issue 439 closed by EC21's pull request, with the approved mockup and the signed pictures linked; the amendments of spec
   Appendix A are on master.
4. The owner has played section 6.

---

## 8. Risks

| Risk | Where it shows | Answer |
|---|---|---|
| Old pins break when the data changes | EC1, EC6, EC8 | the fixture is off by default in `EconomyFixture.defs`; each task lists every pin it moves |
| The season step and the preview drift | EC8, EC11 | one pure `goods_step` for both; the 200 seeded cases; the technical director reads both |
| The step order makes towns starve | EC8 | needs before works; the reserve pinned unchanged after works (40 seasons) |
| The home market prints money or drains treasuries | EC8, EC20 | the floor; the bought-share and treasury ranges; the margin rule in the AI |
| Arms deadlock an AI at war | EC12, EC17 | the blocker only stops declarations; peace stays; the soak's "no raise for 40 seasons" range |
| Growth too slow at 500 | EC7, EC20 | intended by the owner; weights are data; the people range of both suites |
| Snowball of rich cities | EC20 | the twin ranges; the city tier lever (1250 to 1150) |
| `improve_preview.gd` past its allowlisted size | EC11 | the card lives in `workshop_preview.gd`; the allowlist count may not grow |
| M9 touches the same files | all core groups | start after M9 merges; FORMAT and schema numbers by rule (spec R13) |
| A word formatted in the shell drifts from the model | EC13 | spec D32 and R57's planted fault |
| The two meanings of "slot" confuse | EC5, EC13 | spec D7: "works crews" in every word; the playtest checks it |
| Windowed runs needed for pictures | EC21 | the owner's go first; EC0's mockup needs no game window |

---

## 9. Defaults taken (none blocks the build; the owner may change any before its task)

| Default | Alternative |
|---|---|
| The owner's cut-off note on the Buildings tab is read as "category rows, each row a kind of building with its workforce on the tile": one wooden strip per category, a workforce bar on its plaque (spec D24, D25) | per-building workers on each tile; a separate Workers tab |
| Group order on the Town tab: Settlement, Workshops, Land, Harbour, Defence | Workshops last |
| Workshop jobs 500 / 1,000 / 2,000 by stage, sharing the settlement's hands with the districts round it | free workers (no jobs); jobs from the town alone |
| Upkeep by stage: weaver and armourer 2 / 3 / 5, bakery 1 / 2 / 4 (the design gives stage 2 only) | flat upkeep |
| Raw at hand: stage 2 250 permille, stage 3 300 (the owner's "small steps", N6) | stage 3 350 |
| An idle slot pays no upkeep and employs no one; an idle slot cannot be upgraded | idle slots pay |
| A workshop build whose slot vanished before it finished is cancelled "blocked", as works are | it waits |
| No demolish of a single workshop; clearing the settlement drops them all | a "pull down" action |
| The Buy inputs flag survives capture (the new owner inherits the switch) | reset to on |
| Arms bought for a raise ignore the treasury floor | the floor for arms too |
| Countries start with 2 arms each (the reserve) | no arms at the start |
| Towns keep eating fish before grain (the code), bread first up to its comfort share (open question 1) | the design's grain, fish, then bread |
| Armies eat grain only (bread is for towns) | armies eat bread |
| Cloth's comfort need: 0.05 loads a season per 1,000 town people (`need_milli` 50; a town of 10,000 uses 1 load a season) | no cloth need |
| The growth word: slow under 700, steady under 1,000, fast from 1,000 | three bands from the soak |
| The Food chip counts a settlement's bakery | the land's food only |
| The product is a `crafted` flow; bought arms an `arms_bought` line in spending | the design's `made` flow and one "Inputs bought" line |
| The AI weights of spec R65 and `AiDef` values: arms 1500, at hand 1500, slot value 10, war arms companies 4, industry value 300 | other numbers from EC20 |
| `Military.refill` stays free (open question 2) | refill takes arms |

---

## 10. Open owner questions (each with a recommendation)

1. **How towns eat bread.** The design eats bread last, which leaves its comfort (and so its effect on growth) at zero almost
   always. *Recommend: towns eat bread first up to 30 % of their food, then fish and grain, then any other bread (spec D9).*
   Alternative: bread last as the design (bread is then mostly a sale good and an emergency food).
2. **Does the free refill of men need arms?** The owner said refit and upgrade need arms (N9); Godot has neither yet, only the
   free regaining of men in supply. *Recommend: refill stays free in M9.5; M11's refit and upgrade take arms (spec R49).*
   Alternative: refill takes 1 arms a season for every country that regains men (a small steady drain).
3. **Where the Buy inputs switch lives.** *Recommend: on the workshop's card, opened by a click on its tile in the Workshops
   strip (spec D27); on by default.* Alternative: a right-click on the tile toggles it, with a small mark on the tile when off.
4. **The plaque bars.** For Land, Harbour and Workshops the bar is workers employed of the jobs; Settlement and Defence have no
   jobs. *Recommend: Settlement shows people of its room, Defence its garrison of full; no bar where neither applies (spec
   D25).* Alternative: bars only on strips with jobs.
5. **Cloth as a comfort need.** Comfort from cloth needs the towns to use some cloth, which then is not sold. *Recommend: towns
   use a little cloth (0.05 loads a season per 1,000 town people) after the workshops make it (spec D10).*
   Alternative: comfort from cloth counts cloth made, not used (towns consume none; simpler, but comfort then rewards
   making, not wearing).
6. **The fourth chip on a settlement.** *Recommend: Slots "2 / 3" replaces Works on settlements; Works stays on other own land
   and in the hammer's refusals (spec D26).* Alternative: five chips on settlements.
