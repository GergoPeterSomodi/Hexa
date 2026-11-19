# M11 build plan: Research

Game and systems designer (Opus), 2026-11-17. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/m11-build-spec.md` ("the spec").

**Starts after M10 is closed** (its plan's definition of done, the owner's playtest). M11 edits what M1.5 to M10 deliver: `Game`,
`Session`, `Events`, the action and season tables, `Country`, `Army`, `Unit`, `BattleRecord`, `Stats`, `GameDefs`, `WarDef`, `UnitDef`,
`AiDef`, `AiTemperDef`, `Economy`, `EconomySeason`, `DistrictCache`, `People`, `Works`, `Military`, `Armies`, `Movement`, `Supply`,
`Vision`, `SightCache`, `Combat`, `Battles`, `BattleEnd`, `Occupation`, `Sieges`, `Wars`, `WarGoals`, `Peace`, `Brakes`, `Unrest`, `Trade`,
`TradeCache`, `Merchants`, `StatsSystem`, `Chronicle`, `Knowledge`, `Words`, the previews, the report's view, the reminders, the log
lines, the study's views and pages, the hex, country, army and battle views and panels, the decision queue, the chips, the console,
F3, the App, the AI, the soak and the perf tools. The standard's rule holds: the next milestone starts after the owner has played the
last one.

**The M11 row of `ui-style-and-feedback-plan.md` S5** (the Research page; the report's research line; the idea pick as a decision) is
folded in: the page is Z13 and Z20, the research line Z14 and Z20, the decision Z19. **The M11 row of `ui-and-controls-plan.md`
section 4** (the tech screen, opaque, T; the idea pick, modal; the research chip opens it; the Research study page) is Z12 and Z18 (the
tech screen), Z12 and Z19 (the idea pick), Z21 and Z22 (the chip) and Z13 and Z20 (the page).

**Task IDs** are Z1 to Z25: the letter Z is used by no other plan. **25 tasks: 11 L, 14 M**, about 42 worker-days. M7, M8, M9 and
M10 are on GitHub (milestones 19 to 22): M11 changes none of their task rows; every edit M11 makes to their code is a Z task here.

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Definitions, state, bake** | the definition classes, the modifier registry and engine; `country/7`, `army/3`, `unit/3`, `battle-record/2`, format 9, the skeletons and the new arguments; bake slice 9 | Z1 to Z3 | 2 L, 1 M |
| **Data and the door** | the tree, the ideas, the eras, the traits, the later kinds in `.tres`; `Game.defs_of`, `ModsCache` and the data-only scan | Z4, Z5 | 2 M |
| **The rules and the hooks** | the research system; every reading site of the 55 keys on the country's definitions | Z6 to Z9 | 2 L, 2 M |
| **Kinds, generals, the season, the read models** | later kinds and refits, generals; the season table, actions, events, `Session`; words and the tech screen's models | Z10 to Z12 | 2 L, 1 M |
| **Read models and proofs** | the study's and panels' views; the report, the log and the reminders; the property, saves, the Italian game and the 55 probes; the perf rows | Z13 to Z16 | 1 L, 3 M |
| **The AI and the screens** | the AI's research, generals and refits; the tech screen; the idea pick; the Research page and the report screen; the panels | Z17 to Z21 | 2 L, 3 M |
| **The App and the soak** | the App, the chip, the console; the `research` suite, its invariants and ranges, the research report | Z22, Z23 | 2 L |
| **Proof in the window** | the monkey, the pictures, the UI perf rows | Z24 | 1 M |
| **Tuning** | the costs, rates, weights and ranges on the soak's and the report's tables | Z25 | 1 M |

**25 tasks: 11 L, 14 M**, about 42 worker-days; about 18 working days end to end with the groups below (each group takes as long as its longest task), plus reviews and the owner's
playtest.

```
M10 closed (the owner's playtest)
  -> A:  Z1 (L)  Z2 (L)  Z3
  -> B:  Z4  Z5                                                     (Z4's tables: Opus reads them on its first day)
  -> C:  Z6 (L)  Z7  Z8 (L)  Z9                                     (Z8's war_report general rows go to Opus)
  -> D:  Z10 (L)  Z11 (L)  Z12
  -> E:  Z13  Z14  Z15 (L)  Z16
  -> F:  Z17 (L)  Z18 (L)  Z19  Z20  Z21
  -> G:  Z22 (L)  Z23 (L)                                           (Z23's first research suite: Opus reads its tables)
  -> H:  Z24
  -> I:  Z25  -> the owner plays M11

Critical path: Z1 -> Z4 -> Z6 -> Z11 -> Z15 -> Z17 -> Z23 -> Z24 -> Z25   (and Z2 -> Z5 -> Z8 -> Z10 -> Z13 -> Z21 -> Z22;
               Z5 -> Z7, Z9; Z6 -> Z12 -> Z18, Z19; Z11 -> Z14 -> Z20; Z3 -> Z18, Z19, Z21)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel, no two touch one file,
and no task calls code another task of its group writes. Z2 creates `core/systems/research.gd`, `generals.gd` and `mods_cache.gd`
with every function's signature and an empty body (`ModsCache.defs_for` returns `game.defs`; `Generals.of_side`, `max_of` and `count`,
three reads, are filled there, so Z8's battle terms can find a side's general), gives `Military.refit_check`, `refit`,
`stack_limit_at`, `kind_of` and `refit_cost` their signatures, and adds the new last arguments of `Military.unit_def`, `cost_of`,
`can_stand`, `Supply.food_need`, `Works.cost_of` and `WarGoals.goal_of` with bodies unchanged, so the hook tasks of group C fill their
own files and pass the arguments from their own callers. Z5's `ModsFixture.grant` is what the hook tests of Z7 to Z9 use; Z6's
`ResearchFixture.off` turns research off in `ScenarioFixture` for every earlier test while Z2's empty `Research.setup` already gives
no country an effect until then. Z11's action table names `Generals`' and `Military`'s pairs through Z2's signatures; Z10 fills them;
Z12's views take their verdicts from `Research`'s check functions directly (not through `Game.check`, whose table Z11 extends).

---

## 2. Tasks

Who, per the standard's section 9 ("Opus / Sonnet (system), Haiku (tech screen)"): *Sonnet* builds the systems, views, the AI, tools
and anything touching `Game`, saves, the season table, `Session`, `Events`, input or the App; *Haiku* builds data files, the bake slice,
the tech screen, the idea pick, the Research page, the panels' parts and the pictures; *Opus* sets and reviews the numbers and the
words and decides the tuning; *Fable* reviews the interfaces. Generated files belong to the task that changes their source. **Every
task's done-when includes: lint (`python tools/lint_godot.py godot`), check_scripts and GUT green**, both UI `--check`s
(`bake_ui.py --check`, `build_theme.gd --check`), `build_map --check` and `build_scenario.gd --check`. Paths without a prefix are
under `godot/`; `tools/`, `tests/test_*.py`, `docs/`, `.github/` and `CLAUDE.md` are at the repository root.

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Z1 | L, Sonnet | **The definitions and the modifier engine** | `core/defs/mod_def.gd`, `core/defs/mod_keys.gd`, `core/defs/mod_apply.gd`, `core/defs/tech_def.gd`, `core/defs/idea_def.gd`, `core/defs/era_def.gd`, `core/defs/trait_def.gd`, `core/defs/research_def.gd` (new); edit `core/defs/game_defs.gd` (`research`, `techs`, `ideas`, `eras`, `traits`, `know_range`, the lookups, `validate`: the new rules apply once `research` is set), `core/defs/war_def.gd` (the generals' and refits' fields, `validate`), `core/defs/unit_def.gd` (`validate`: era 1 to 3), `core/defs/ai_temper_def.gd` (`validate`: `mix` sized 4 by branch); `tests/core/test_research_defs.gd`, `tests/core/test_mod_apply.gd` (new); edit `tests/core/test_war_defs.gd`, `tests/core/test_unit_defs.gd`, `tests/core/test_ai_defs.gd` | Spec 4.2 (the 55 rows of `ModKeys.KEYS` with their ops, bounds, readers, whose and forgets) and 5.1: every case and planted fault of spec 9 for these tests; `ModApply` leaves the base unchanged (the probe of spec 10, on its first day); every M3 to M10 test green unchanged. Lint, check_scripts, GUT green |
| Z2 | L, Sonnet | **The state, the saves, the skeletons** | edit `core/state/country.gd` (country/7), `core/state/army.gd` (army/3, `mustering` with `refit_turn`), `core/state/unit.gd` (unit/3), `core/state/battle_record.gd` (battle-record/2), `core/state/stats.gd` (60 series); `core/systems/research.gd`, `core/systems/generals.gd`, `core/systems/mods_cache.gd` (new: spec 5.3's classes with `OWNS`, every signature and an empty body; `defs_for` returns `game.defs`; `Generals.of_side`, `max_of`, `count` filled); edit `core/systems/armies.gd` (`set_general`, `refit_units` filled), `core/systems/military.gd` (the signatures of section 1, bodies unchanged; `raise_options` by the country's era, `raise_check`'s row 6b and `kind_of` filled, so the later kinds Z4 adds are never raised in the Age of Pikes), `core/systems/supply.gd` (`food_need`'s `tag`), `core/systems/works.gd` (`cost_of`'s `tag`), `core/systems/war_goals.gd` (`goal_of`'s `by_id`), `core/systems/treasury.gd` (`WHY` 20, `SPENDING`), `core/systems/stores.gd` (`FLOWS` 10), `core/game/game.gd` (`mods`, `DOOR_FIELDS`, `defs_of`, `new_scenario` calling `Research.setup`), `core/game/snapshot.gd`, `core/game/save_file.gd` (`FORMAT` 9, `OLDEST_FORMAT` 9); edit `tests/core/test_country_state.gd`, `test_army_state.gd`, `test_war_state.gd`, `test_military.gd` (row 6b, the era's options), `test_stats.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_game_core.gd` (`DOOR_FIELDS`), `test_owns.gd` (the new fields' owners), `test_treasury.gd`, `test_stores.gd`, `test_insights_views.gd` (the pins of format 9, 60 series, 20 `WHY` reasons, 10 flows) | Spec 5.2, 4.22 and the `Treasury` and `Stores` lines of 5.3: every round trip and planted fault of spec 9 for these tests; save, load, save byte-equal; `FORMAT` 9 (P: a format-8 header reads `older`); every M3 to M10 test green. Lint, check_scripts, GUT green |
| Z3 | M, Haiku | **Bake slice 9: the research pieces** | `tools/ui_bake/pieces_m11.py` (new); edit `tools/bake_ui.py` (the slice), `shell/ui/tokens.gd` (the five tokens of spec 6.2), `godot/tools/build_theme.gd` (the Kit icons; the variations `TechNode*`, `IdeaCard`, `IdeaCardNational`, `TechLinks`); `godot/assets/ui/kit/**`, `shell/ui/theme.tres`, `shell/ui/theme_high_contrast.tres` (generated); edit `tests/test_bake_ui.py` | Spec 6.2: the 47 icons and 8 figures at 1x and 2x; the variations in both Themes; both `--check`s; the art director signs the research sheet. Lint, check_scripts, GUT green |

### Group B (after A)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Z4 | M, Haiku (Opus reviews) | **The data: the tree, the ideas, the eras, the traits, the later kinds** | `data/defs/research.tres`, `data/defs/techs/*.tres` (51), `data/defs/ideas/*.tres` (29), `data/defs/eras/1.tres`, `2.tres`, `3.tres`, `data/defs/traits/*.tres` (5), `data/defs/units/landsknechts.tres`, `arquebusiers.tres`, `lancers.tres`, `culverins.tres`, `pike_regiments.tres`, `musketeers.tres`, `cuirassiers.tres`, `field_guns.tres` (new); edit `data/defs/war.tres`, `data/defs/game_defs.tres`, `data/README.md`; `godot/tools/research_tables.gd` (new); `tests/core/test_research_data.gd` (new); edit `tests/core/test_unit_defs.gd`, `tests/core/test_war_defs.gd` (the new values) | Spec 4.3 to 4.6, 4.10, 4.11 and 5.1 entered exactly: **done-when 1 (c) and 3**, every planted fault of spec 9 for `test_research_data.gd`; `research_tables.gd` prints the tables; `GameDefs.validate()` passes with research set; Opus reads the tables on the task's first day. Lint, check_scripts, GUT green |
| Z5 | M, Sonnet | **The effective definitions and the data-only rule** | edit `core/systems/mods_cache.gd` (fill), `core/game/game.gd` (`defs_of` through the cache; `emit`'s forgets of spec 4.2), `core/systems/district_cache.gd` (`forget_land`); `tests/core/mods_fixture.gd`, `tests/core/test_mods_cache.gd`, `tests/core/test_research_data_only.gd` (new) | Spec 4.2's cache and forgets and 5.8: every case and planted fault of spec 9 for these tests (**done-when 1 (a)**); `ModsFixture.grant` gives a country exactly the granted rows. Lint, check_scripts, GUT green |

### Group C (after B)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Z6 | L, Sonnet | **The research system** | edit `core/systems/research.gd` (fill: `setup`, `national_of`, `rate`, `rate_parts`, `partners`, `cost`, `diffusion`, `available`, `cheapest_available`, `path_to`, `dependants`, `era_ready`, `gate_state`, `seasons_left`, `known_points`, `learn`, `step_era`, `draw_ideas`, the five pairs, `season`); `tests/core/research_fixture.gd`, `tests/core/research_script.gd`, `tests/core/test_research.gd`, `tests/core/test_research_rate.gd`, `tests/core/test_era_gate.gd`, `tests/core/test_research_ideas.gd` (new); edit `tests/core/scenario_fixture.gd` (`with_research`; `ResearchFixture.off` by default) | Spec 4.3 to 4.9, 4.12 and 4.18 (a), (b): **done-when 4 and 5**; the 13 rates of 4.7 pinned as the build gives them (written into spec 4.7 where they differ); every row and planted fault of spec 9 for these tests; every M3 to M10 pin unchanged on `ResearchFixture.off`. Lint, check_scripts, GUT green |
| Z7 | M, Sonnet | **Hooks in the economy, the people and the works** | edit `core/systems/economy.gd` (`district_base`, `district_output`, `season_output` with the owner's definitions), `core/systems/economy_season.gd` (`money_lines`, `made_of`; `needs_of` passes the tag to `Supply.food_need`), `core/systems/district_cache.gd` (`base_of` with the owner's definitions), `core/systems/people.gd` (`change_at`, `room_at`, `available`), `core/systems/works.gd` (`cost_of`'s body and its callers), `core/views/improve_preview.gd` (the actor's costs); `tests/core/test_mod_hooks_economy.gd` (new); edit `tests/core/test_economy.gd`, `tests/core/test_district_cache.gd`, `tests/core/test_people.gd`, `tests/core/test_works.gd`, `tests/core/test_improve_preview.gd` | Spec 4.14's economy, people and works rows: rows 6 to 10 and 28 to 33 of 4.2 change exactly their numbers for the granted country and nothing for its neighbour; `forget_land` drops only the owner's hexes; every M4, M5 and M4.5 pin green. Lint, check_scripts, GUT green |
| Z8 | L, Sonnet | **Hooks in the armies and the war** | edit `core/systems/military.gd` (`unit_def`, `cost_of`, `stack_limit`, `stack_limit_at`, `can_stand` with the general), `core/systems/movement.gd` (`can_stand` with the arriving army's general), `core/systems/supply.gd`, `core/systems/vision.gd` (army sight by country), `core/systems/sight_cache.gd` (land sight by country), `core/systems/battles.gd` (`input_of`: `wars`, `generals`; `fits`), `core/systems/combat.gd` (each side's `WarDef`, the general terms, the morale cut), `core/systems/battle_end.gd` (experience by country; `BattleRecord.generals`), `core/systems/occupation.gd` (`siege_need` and the garrison by the controller), `core/systems/sieges.gd` (the rate by the besieger; the siege master), `godot/tools/war_report.gd` (the general rows); `tests/core/test_mod_hooks_war.gd` (new); edit `tests/core/test_military.gd`, `test_movement.gd`, `test_supply.gd`, `test_vision.gd`, `test_combat.gd`, `test_battles.gd`, `test_occupation.gd`, `test_sieges.gd` | Spec 4.11's battle terms and 4.14's army and war rows: rows 1 to 4, 11 to 27 of 4.2; **done-when 6's two hits** (40 and 28 men); each side's values from its own definitions (P of spec 9); `war_report.gd`'s general rows in the pull request for Opus; every M6 and M7 pin green. Lint, check_scripts, GUT green |
| Z9 | M, Sonnet | **Hooks in diplomacy, trade and knowledge** | edit `core/systems/war_goals.gd` (`goal_of` by the declarer and its callers), `core/systems/wars.gd` (the declaration's goal call), `core/systems/peace.gd`, `core/systems/brakes.gd`, `core/systems/unrest.gd`, `core/systems/trade.gd`, `core/systems/trade_cache.gd` (each market's own reach), `core/systems/merchants.gd`, `core/views/knowledge.gd` (`know_range`, `techs_seen`, `ideas_seen`, `era_seen`), `core/views/goal_view.gd` (the declarer's goal); `tests/core/test_mod_hooks_trade.gd` (new); edit `tests/core/test_war_goals.gd`, `test_peace.gd`, `test_brakes.gd`, `test_unrest.gd`, `test_trade.gd`, `test_trade_cache.gd`, `test_merchants.gd`, `test_knowledge.gd`, `test_goal_view.gd` | Spec 4.13 and 4.14's diplomacy, trade and knowledge rows: rows 5 and 39 to 55 of 4.2; the catchment with two reaches; the free traders' base cost beside a merchant's own; the fog's cases (P: an unknown country's techs shown is caught); every M9 and M10 pin green. Lint, check_scripts, GUT green |

### Group D (after C)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Z10 | L, Sonnet | **Later kinds, refits and generals** | edit `core/systems/military.gd` (`later_options`, `refit_cost`, `refit_check`, `refit`, the merge row and the general's pass, `upkeep_of` with the general, a whole army's disband dismissing it), `core/systems/generals.gd` (the two pairs), `core/systems/armies.gd` (`remove` emits `general_lost`); `tests/core/test_generals.gd`, `tests/core/test_refit.gd` (new); edit `tests/core/test_military.gd`, `tests/core/test_armies.gd` | Spec 4.10 and 4.11: **done-when 6** but the two hits (Z8) and **done-when 7**; every row and planted fault of spec 9 for these tests. Lint, check_scripts, GUT green |
| Z11 | L, Sonnet | **The season, the actions, the events, `Session`** | edit `core/game/season.gd` (17 `PHASES`, the research phase), `core/game/actions.gd` (38 names, the pairs), `core/state/chronicle.gd` (48 notable kinds), `core/systems/vision.gd` (`SIGHTED`), `core/systems/stats_system.gd` (`research`, `techs`, `era`), `core/game/game.gd` (`dev_tech`, `dev_research`, `dev_era`), `core/game/replay.gd` (the dev records), `shell/autoload/events.gd` (eleven signals), `shell/autoload/session.gd` (`drain`, `last_phase_ms`, the dev wrappers); edit `tests/core/test_season.gd`, `test_chronicle.gd`, `test_vision.gd`, `test_stats.gd`, `test_game_core.gd`, `test_replay.gd`, `test_insights_views.gd` (the pins of 17 phases, 38 actions, 48 notable kinds), `tests/shell/test_session.gd` | Spec 4.15, 4.16's emitters and signals, 5.4, 5.5: **`PHASES` pinned as the seventeen**; the eleven signals drained after their phases and actions; the dev records replay to the same digest (P: a changed tech gives another); `research_ms` measured once on north Italy (printed). Lint, check_scripts, GUT green |
| Z12 | M, Sonnet | **Words and the research read models** | edit `core/views/words.gd` (spec 5.6's seven functions); `core/views/tech_layout.gd`, `core/views/research_view.gd`, `core/views/idea_view.gd`, `core/views/cards_research.gd` (new); `tests/core/test_tech_layout.gd`, `tests/core/test_research_view.gd`, `tests/core/test_idea_view.gd`, `tests/core/test_cards_research.gd` (new); edit `tests/core/test_words.gd` | Spec 5.6 for these files, 6.3 to 6.5 as data: `TechLayout` equals `techlayout.py`'s cells and states on the fixture table; `move` in every direction; the side card's verdicts equal the checks (P); every case of spec 9. Lint, check_scripts, GUT green |

### Group E (after D)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Z13 | M, Sonnet | **The study's and the panels' read models** | `core/views/study_research.gd` (new); edit `core/views/country_card.gd` (research), `core/views/hex_card.gd` (the learning line), `core/views/army_view.gd` (general and refit rows, raise options by era), `core/views/battle_view.gd` (the general text from the record), `core/views/odds_view.gd` (the general line), `core/views/study_military.gd` (the General column), `core/views/study_history.gd` (the `era` and `tech` marks); `tests/core/test_study_research.gd` (new); edit `tests/core/test_country_card.gd`, `test_hex_card.gd`, `test_army_view.gd`, `test_battle_view.gd`, `test_odds_view.gd`, `test_study_military.gd`, `test_study_history.gd` | Spec 4.21, 5.6 for these files and 6.6, 6.7 as data: every case of spec 9 (P: an unknown country in the known countries' table is caught). Lint, check_scripts, GUT green |
| Z14 | M, Sonnet (Opus reviews) | **The report, the log, the reminders** | edit `core/views/season_summary.gd` (the `research` section, the glance chip, the treasury, orders and befell lines), `core/views/log_lines.gd` (4.16's lines and filters), `core/views/reminders.gd` (4.20's rules), `tests/fixtures/report_sample.gd` (a Research section); edit `tests/core/test_season_summary.gd`, `test_log_lines.gd`, `test_reminders.gd` | Spec 4.16 and 4.20: every sentence and rule with its planted fault; the section equal after a save and load; Opus reads the words. Lint, check_scripts, GUT green |
| Z15 | L, Sonnet | **The proofs: the probes, the property, saves, the Italian game** | `tests/core/test_mod_hooks.gd`, `tests/core/test_research_property.gd`, `tests/core/test_research_saves.gd`, `tests/core/test_research_italy.gd` (new); edit `tests/core/random_player.gd` (the eight new actions), `tests/core/test_check_contract.gd`, `test_owns.gd` (the new actions and the research phase), `test_forty_seasons.gd`, `test_money_property.gd`, `test_men_property.gd` | **Done-when 1 (b), 2's pull-request half, 8, 9** as spec 9 lists them, each with its planted fault; the 55 probes of 4.2; the Italian game's turns pinned as the build gives them. Lint, check_scripts, GUT green |
| Z16 | M, Sonnet | **The perf rows** | edit `godot/tools/perf_fixture.gd` (`europe_research`), `godot/tools/perf_core.gd` (spec 8's rows), `godot/tests/perf_core_budget.json` | Spec 8: every row printed and within its limit on the made-up Europe; a failed row takes section 8's fallback in this pull request. Lint, check_scripts, GUT green |

### Group F (after E)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Z17 | L, Sonnet (Opus reviews) | **The AI's research, generals and refits** | `core/ai/ai_research.gd` (new); edit `core/ai/ai_know.gd` (spec 5.7's functions; the goal estimate by the seat), `core/ai/ai_brief.gd` (`defs`, `research`), `core/ai/ai_turn.gd` (the research step, `research_scripts`), `core/ai/ai_forces.gd` (appoint, refit, the mix by branch and era), `core/ai/ai_economy.gd` (`prior` on `brief.defs`), `core/defs/ai_def.gd`, `core/defs/ai_temper_def.gd` (the new fields, `validate`), `data/defs/ai.tres`, `data/defs/tempers/builder.tres`, `cautious.tres`, `steadfast.tres`, `aggressive.tres`, `opportunist.tres`, `conqueror.tres`, `godot/tools/ai_tables.gd`; `tests/core/test_ai_research.gd` (new); edit `tests/core/test_ai_defs.gd`, `test_ai_know.gd`, `test_ai_door.gd`, `test_ai_forces.gd`, `test_ai_economy.gd`, `test_ai_turn.gd`, `test_ai_fog.gd`, `test_ai_play.gd` | Spec 4.17 and 5.7: every case and planted fault of spec 9 for these tests (P: funding at war; `Research.` in a step module); `ai_season_ms` measured once on the made-up Europe, in the pull request; Opus reads the numbers on the first day. Lint, check_scripts, GUT green |
| Z18 | L, Haiku | **The tech screen** | `shell/screens/tech.tscn`, `shell/screens/tech.gd`, `shell/screens/tech/tech_node.tscn`, `shell/screens/tech/tech_node.gd`, `shell/screens/tech/tech_links.gd`, `shell/screens/tech/tech_side.tscn`, `shell/screens/tech/tech_side.gd` (new); `tests/shell/test_tech_screen.gd`, `tests/shell/test_tech_node.gd` (new) | Spec 6.1 and 6.3 from `ResearchView` fixtures: every part, state and key; a click sets, Shift queues, a right click and Delete remove; the banner; the art director signs its pictures beside `14_tech_tree_c.png`. Lint, check_scripts, GUT green |
| Z19 | M, Haiku | **The idea pick and its decision** | `shell/screens/idea_pick.tscn`, `shell/screens/idea_pick.gd`, `shell/screens/tech/idea_card.tscn`, `shell/screens/tech/idea_card.gd` (new); edit `shell/app/decision_queue.gd` (the `ideas_offered` kind, its order, its drop); `tests/shell/test_idea_pick.gd` (new); edit `tests/shell/test_decision_queue.gd` | Spec 6.4 and 6.9 from `IdeaView` fixtures: the cards, Take, Decide later, the keys; the decision after the leagues; dropped when answered elsewhere; the art director signs it beside `14_tech_tree_d_new_age.png`. Lint, check_scripts, GUT green |
| Z20 | M, Haiku | **The Research page, the report screen, the Military page** | `shell/screens/study/page_research.tscn`, `shell/screens/study/page_research.gd` (new); edit `shell/screens/study_pages.gd` (`LIST`), `shell/screens/season_report.gd` (the Research section, its links), `shell/screens/study/page_military.gd` (the General column); `tests/shell/test_page_research.gd` (new); edit `tests/shell/test_study.gd`, `tests/shell/test_season_report.gd`, `tests/shell/test_page_military.gd` | Spec 6.6 and 6.8's report from the view fixtures: every part and empty state; the span; the links. Lint, check_scripts, GUT green |
| Z21 | M, Haiku | **The panels, the chip piece, the tokens** | edit `shell/panels/country_panel.tscn`, `shell/panels/country_panel.gd`, `shell/panels/army_panel.tscn`, `shell/panels/army_panel.gd`, `shell/panels/raise_list.tscn`, `shell/panels/raise_list.gd`, `shell/panels/hex_panel.tscn`, `shell/panels/hex_panel.gd`, `shell/screens/battle_dock.gd`, `shell/hud/odds_card.gd`, `shell/ui/resource_chip.gd` (`set_fraction` with `of` 0), `shell/map/army_tokens.gd` (figures by era, the general icon); edit `tests/shell/test_country_panel.gd`, `test_army_panel.gd`, `test_raise_list.gd`, `test_hex_panel.gd`, `test_battle_dock.gd`, `test_odds_card.gd`, `test_resource_chip.gd`, `test_army_tokens.gd` | Spec 6.7 and 6.5's chip piece from the card and view fixtures: every row, state and verdict; the refreshes. Lint, check_scripts, GUT green |

### Group G (after F)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Z22 | L, Sonnet | **Wire the App: requests, the chip, the console** | edit `shell/app/game_requests.gd` (6.10's table), `shell/app/app.gd` (the milestone `"11"`; under 800 lines), `shell/app/study_warm.gd`, `shell/hud/chips.tscn`, `shell/hud/chips.gd` (Research), `shell/hud/dev_commands.gd`, `shell/hud/debug_overlay.gd`, `shell/hud/task_flag.gd` (the actions), `shell/hud/action_log.gd` (research lines open the tech screen), `shell/hud/notifications.gd`, `shell/map/floaters.gd` (the ribbons), `shell/input/map_input.gd` (`tech_requested`), `godot/README.md`; edit `tests/shell/test_app_flow.gd`, `test_chips.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_task_flag.gd`, `test_notifications.gd`, `test_action_log.gd`, `test_floaters.gd`, `test_map_input.gd` (P: T in the sandbox), `test_bindings.gd` (`game_tech` shows from `"11"`) | Spec 6.5, 6.8, 6.10 and the end to end of spec 9 (`test_app_flow.gd`); **done-when 12** in the shell tests; still two autoloads. Lint, check_scripts, GUT green |
| Z23 | L, Sonnet | **The soak and the research report** | edit `godot/tools/soak.gd` (the `research` suite, the scripted Genoa, `runaway` reported in it, the ranges and the summary's columns), `tests/core/invariants.gd` (`research`, `generals`; `armies` with `stack_limit_at`), `tests/core/test_invariants.gd`, `tests/core/test_ai_soak_quick.gd`, `.github/workflows/godot.yml` (the `research` 1-5 and 6-10 runs, judged by `soak-ranges`), `CLAUDE.md` (the `research_tables.gd` and `research_report.gd` lines in the Godot block); `godot/tools/research_report.gd`, `tests/core/test_research_report.gd` (new) | Spec 4.19: every invariant (P each), the ranges and the summary; a full run of every suite on a runner by hand dispatch and a `research_report.gd` run to 1650 on seeds 1480 to 1482, the tables in the pull request; **Opus reads them before group I**. Lint, check_scripts, GUT green |

### Group H (after G)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Z24 | M, Haiku | **Monkey, pictures, the UI perf rows** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`, `tests/fixtures/ui_sample.gd` (a country in 1523 with a queue, an offer, a general); the signed pictures as goldens (`godot/tests/goldens/m11_*.png`) | The monkey's invariants green on 3 seeds; spec 9's pictures at 1280 x 720 scale 1 and 2560 x 1440 scale 2, signed by the art director; spec 8's UI rows within their limits. Lint, check_scripts, GUT green |

### Group I (after H)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Z25 | M, Sonnet (Opus decides) | **The tuning pass** | edit `data/defs/research.tres`, `data/defs/techs/*.tres` (costs), `data/defs/war.tres` (the generals' numbers), `data/defs/ai.tres`, `data/defs/tempers/*.tres`, `tests/core/test_research_data.gd`, `tests/core/test_war_defs.gd`, `tests/core/test_ai_defs.gd` (the values), `tests/core/test_research_italy.gd`, `tests/core/test_research_rate.gd` (pins the tuned data moves), `godot/tests/goldens/m11_*.png` (re-made when a number on a picture moved, signed again), `docs/architecture/m11-build-spec.md` (4.3, 4.7, 4.8, 4.19 where Opus changes a number), `docs/architecture/m11-build-plan.md` (section 4's console note) | **Done-when 2 and 10**: every range of spec 4.19 on 10 `research`, 100 `ai`, 20 `conqueror`, 20 `passive` and 4 `europe` games with the final data; `research_report.gd` to 1650 on three seeds: median techs known by Winter 1650 22 to 30; M8 to M10's ranges re-measured with research and generals on (kept, or changed with Opus's word); Opus's verdict and the per-country table in the pull request. Lint, check_scripts, GUT green |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** signs the registry, the effective definitions, the state, the save format, the door fields and the
  phase's place (spec 4.2, 5.1, 5.2, 5.4, 4.22, 4.15) before group A starts; reads the interfaces of Z1, Z2, Z5, Z6, Z8, Z10, Z11 and
  Z12 before they merge; reads Z16's rows and Z11's research time; reads Z15's probes, property and save tests and Z23's invariants
  together.
- **Opus** reads Z4's tables on its first day, Z8's `war_report.gd` general rows, Z14's words, Z17's branch weights and `AiDef`
  numbers on its first day; reads Z23's soak tables and research report before group I and gives Z25's balance verdict (a changed
  number is a data edit with the tests it moves, in Z25's pull request).
- **The art director** signs Z3's sheet, Z18's tech screen beside `14_tech_tree_c.png`, Z19's idea pick beside
  `14_tech_tree_d_new_age.png`, and Z24's pictures (the tech screen in 1480 and 1523, the idea pick, the Research page, the army panel's
  general and refit rows, the report's section).
- **Pull requests** say what changes for the player. Z2 makes M10 saves unloadable ("Made by an older test build"): said. Z6 puts every
  earlier test on `ResearchFixture.off` and starts every country on its national tech and its cheapest research: said. Z7, Z8 and Z9
  move every per-country number onto the country's definitions (no number moves while no country has an effect): said, with the list
  of reading sites. Z10 brings generals and refits: said. Z17 changes what the other countries do: said, with the soak's tables. No
  test pins a digest value.

---

## 4. The owner's playtest of M11

On Windows (mouse) and on the MacBook (trackpad), with a fresh user folder.

1. New game, More, seed **1480**, Italy 1480, Play as **Genoa**. The top bar's **Research** chip: "0/70" and "+2"; hover it:
   "Researching Crop rotation: 0 of 70, about 29 seasons", the points by source, "The Age of Arquebus: 1520 and 4 era I techs".
2. Press **T**: the tech screen. Four branches, three ages; Casa di San Giorgio in Statecraft's first cell with the gold tag, known;
   Crop rotation gold (researching); era II and III faint. Click **Banking**: the toast "Banking waits for the Age of Arquebus (1520 and
   4 era I techs)". Click **Tax rolls**: the strip shows it. **Shift+click Printing press**: the queue shows it. Right click it: gone.
3. With the keyboard only: arrows walk the grid, the side card follows; **Enter** researches; **Shift+Enter** queues; **Delete**
   removes; **Tab** reaches Fund research and Close; **Esc** closes.
4. **Fund research**: the toast "+7.5 research points for 80 ducats" (Casa di San Giorgio adds a quarter); press it again: refused,
   "funded already: again in 4 seasons".
5. End season twice. The report (J): the Research section ("Researching Tax rolls: 12 of 70, about 24 seasons."), Treasury's
   "Research funded ▼ −80"; the chip's progress.
6. F2: `tech double_entry`: the log "You learned Double-entry books: +1 merchant."; press **E**: the market panel's "Merchants 0/3".
7. Select Genoa (8, 13): the hex panel's "Learning +0.7 a season (30,603 people, a walled town)"; its Raise tab: pikemen, crossbowmen,
   knights, bombards, and the Age of Arquebus's four greyed ("landsknechts wait for the Age of Arquebus (1520 and 4 era I techs)").
   Raise 2 companies of pikemen. End season.
8. F2: `era`: the idea pick at once: "A NEW AGE", the Age of Arquebus, three cards, Genoese factors with the gold band first. Press
   **Esc**: decide later; the task flag's "Choose your idea" line; press T: the banner; **Choose**; **Take** a general card: its toast;
   the tech screen and the country panel list the idea.
9. The Raise tab now offers landsknechts, arquebusiers, lancers and culverins; pikemen refused ("your armies have moved on: raise
   landsknechts instead"). The Army of Genoa's panel: **Refit** "2 companies of the Age of Pikes: refit as landsknechts · 30 · 2 iron";
   press it: the toast, "Musters this season".
10. Raise 2 companies of landsknechts and join them to the Army of Genoa (4 companies). Its General row: "No general · 0 of 1 in the
    field"; pick **Ranger** ("+20 % in woods and hills"); **Appoint · 100**; the token shows the general mark; the head line "4 of 10
    companies here".
11. Press **I**, then `]` to Research: the points chart, the sources, techs by branch, the age's two ticks, your ideas, the known
    countries' ages.
12. Main menu, New game, seed 1480; in the pick F2 `watch`; `end 40` four times and `end 1` (Spring 1520 ends): the log's "entered the Age of
    Arquebus" lines; the Research page of the watched game lists the countries' ages; a battle's dock shows "General: ..." for a side
    with one.
13. F5, F2 `digest`, F9, F2 `digest`: the same, with a queue, an offer and a general; J shows the same Research section.

---

## 5. Definition of done

1. The spec's "M11 is done when" items 1 to 13 hold.
2. Tasks Z1 to Z25 merged; CI green, with both UI `--check`s, `build_map --check`, `build_scenario.gd --check`, and the nightly
   `soak` (with `research`), `soak-ranges`, `perf_core` and `perf_ui` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac.
5. `godot-architecture.md` 9.2 marks M11 done; `godot/README.md` describes the M11 game.
6. Section 7 below is handed to the M12 build spec's author.

---

## 6. How to start

On the day M10 closes:

1. Opus presents the tree, the ideas and the national techs (spec 4.3 to 4.6), the rates and the pace (4.7, 4.8), the generals (4.11)
   and the duo example (4.18 a) to the owner and Fable in 30 minutes; a changed number is a data line now, not a task later. Fable
   signs the registry, the state, the save format, the door fields and the phase's place the same day.
2. Start group A together: **Z1** and **Z2** (Sonnet) and **Z3** (Haiku). Z1 runs the duplicate probe of spec 10 on its first day,
   so `ModApply`'s copying is settled before Z5 builds on it.
3. Z8 runs `war_report.gd` with generals on its last day, so Opus can move the bonus before Z10 and Z17 build on it.
4. Z23's first full research suite and the report to 1650 go to Opus the day they run; group I waits for Opus's reading.

---

## 7. What M11 hands on

- **M12:** the score's research part (`Research.known_points`, `Stats` `techs` and `era`, `era_turns`, the chronicle's tech and era
  entries); the end at 1650 with no era after the third; the debt row in `fund_research_check` and generals dismissed at bankruptcy;
  the `research` soak suite run to 681 seasons as the whole-game rig.
- **After M12:** ships and the sea (Navigation's ship rows, carracks and galleons as kinds, sea routes, the Atlantic), colonies, battle
  cards, drill, named generals with lives (characters), the price-swing part of Bourse; each new effect a registry key with its probe.
- **E2, E3:** research rates re-tuned on the real Europe by `research_report.gd`; each country's own national tech.
- **Saves:** `SaveFile.FORMAT` 9; a new body field with a default needs no bump (M3 4.10).
