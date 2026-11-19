# M12 build plan: A whole game

Technical director (Fable), with the game and systems designer (Opus), 2026-11-17. **Status: a proposal; no task starts before
the owner's go.** Builds `docs/architecture/m12-build-spec.md` ("the spec"). M12 ends with the first public Godot release,
**Hexa 0.3.0** on Windows.

**Starts after M11 is closed** (its plan's definition of done, the owner's playtest). M12 edits what M1.5 to M11 deliver (the
spec's list under "When it starts"). The standard's rule holds: the next milestone starts after the owner has played the last one.

**The M12 row of `ui-style-and-feedback-plan.md` S5** (score in Rankings; the Debt tab; the debt and score report lines; the
high-contrast row, text size in charts, `seal_cracked`, sounds) is folded in: J18 (the views), J22 (text size and high contrast
in charts), J26 (the Debt tab, Rankings, the report screen), J28 and J30 (sounds). **The M12 row of `ui-and-controls-plan.md`
section 4** (the event pop-up frame, the game-over and score screen, the Audio page and bus layout, the Keys page, text size and
high contrast, tutorial hints and the hint level, the "Ask before losing progress" switch, developer tools off and the sandbox
hidden, final credits) is J24, J25, J27, J28, J22, J29, J31 and J32.

**Task IDs** are J1 to J38: the letter J is used by no other plan. **38 tasks: 11 L, 27 M**, about 55 worker-days. M3 to M11 are
on GitHub (milestones 14 to 23): M12 changes none of their task rows; every edit M12 makes to their code is a J task here.

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Foundations** | the definitions; the state, saves (format 10) and skeletons; bake slice 10 and the app icon; the decor density and bold marks; the release scaffolding (one version, the preset, logs) | J1 to J5 | 2 L, 3 M |
| **The rules** | the data; debt and bankruptcy; countries that fall; prestige and the end; incidents; the crest ranges; the release workflow | J6 to J12 | 3 L, 4 M |
| **The season and the words** | the debt hooks in other systems; the season table, actions, events, `Session`; the words and read models; the spring and autumn palettes; settings across versions and `since` | J13 to J17 | 1 L, 4 M |
| **Read models and proofs** | the study, report, reminders, log and cards; the properties, saves and contract; the perf rows; the release saves; text size and high contrast | J18 to J22 | 1 L, 4 M |
| **The AI and the screens** | the AI's debt; the event pop-up; the game-over screen; the Debt tab, chips, Rankings, panels; the options pages; the sound board; the hints | J23 to J29 | 2 L, 5 M |
| **Sound and the App** | the sounds and the music; the App wired | J30, J31 | 1 L, 1 M |
| **Credits, the whole suite, the docs** | credits and About; the `whole` soak; the players' docs | J32 to J34 | 1 L, 2 M |
| **Proof in the window** | the monkey, pictures and UI rows; keyboard reach, text fit, hint anchors, every setting persisting | J35, J36 | 2 M |
| **Tuning** | the balance gate on 100 whole games | J37 | 1 M |
| **The release** | the release candidate, the checklist, the tag | J38 | 1 M |

**38 tasks: 11 L, 27 M**, about 55 worker-days; about 26 working days end to end with the groups below (each group takes as long
as its longest task), plus reviews, the release playtest (two days of the owner's time) and the tag.

```
M11 closed (the owner's playtest)
  -> A:  J1 (L)  J2 (L)  J3  J4  J5                          (J5's version probe on its first day)
  -> B:  J6  J7 (L)  J8 (L)  J9  J10 (L)  J11  J12           (J6's tables: Opus reads them on its first day)
  -> C:  J13  J14 (L)  J15  J16  J17
  -> D:  J18  J19 (L)  J20  J21  J22
  -> E:  J23 (L)  J24 (L)  J25  J26  J27  J28  J29
  -> F:  J30  J31 (L)
  -> G:  J32  J33 (L)  J34                                   (J33's first whole run: Opus reads its tables)
  -> H:  J35  J36
  -> I:  J37                                                 (the 100 whole games on the tuned data)
  -> J:  J38  -> the owner's release playtest -> tag v0.3.0 -> the owner publishes the draft

Critical path: J2 -> J7 -> J14 -> J19 -> J23 -> J31 -> J33 -> J36 -> J37 -> J38
               (and J1 -> J6 -> J15 -> J18 -> J26; J8 -> J14; J10 -> J14; J5 -> J12 -> J21 -> J38; J3 -> J24, J26)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel, no two touch one file,
and no task calls code another task of its group writes. J2 creates `core/systems/debt.gd`, `score.gd`, `ending.gd` and
`incidents.gd` with `OWNS`, every signature of spec 5.3 and empty bodies, and gives `Countries.fall` and `season`,
`Peace.drop_of`, `Coalitions.drop`, `TradePacts.end_of`, `Trade.add_fair`, `Research.add_progress` and `Improve.lower_fortress`
their signatures (bodies return or do nothing), so the rule tasks of group B fill their own files and call the others' finished
signatures only. `DebtFixture.off` (J2) keeps every M3 to M11 pin as it is until the rule tasks turn debt on in their own tests.
J14's season table calls the phase functions J7 to J10 filled; J15's views read the systems' functions directly (not through
`Game.check`, whose table J14 extends).

---

## 2. Tasks

Who, per the standard's section 9 ("Fable + Opus / Sonnet, Haiku"): *Sonnet* builds the systems, views, the AI, the tools, CI and
anything touching `Game`, saves, the season table, `Session`, `Events`, settings, input or the App; *Haiku* builds data files,
the bake slice, the screens, the pages, the panels' parts, the hints and the sounds; *Opus* sets and reviews the numbers and the
words and decides the tuning; *Fable* reviews the interfaces and the release; the **art director** signs the look and the sheet.
Generated files belong to the task that changes their source. **Every task's done-when includes: lint (`python
tools/lint_godot.py godot`), check_scripts and GUT green**, both UI `--check`s (`bake_ui.py --check`, `build_theme.gd --check`),
`build_map --check`, `build_scenario.gd --check` and `build_tileset --check` (and, from J34, `keys_table.gd --check`; from J30,
`check_audio.py`; from J5, `check_release.py`). Paths without a prefix are under `godot/`; `tools/`, `tests/test_*.py`, `docs/`,
`.github/`, `README.md`, `CHANGELOG.md` and `CLAUDE.md` are at the repository root.

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| J1 | L, Sonnet | **The definitions** | `core/defs/debt_def.gd`, `core/defs/score_def.gd`, `core/defs/incidents_def.gd`, `core/defs/incident_def.gd`, `core/defs/incident_choice_def.gd`, `core/defs/incident_effect_def.gd` (new); edit `core/defs/game_defs.gd` (`debt`, `score`, `incidents`, `incident_list`, `incident`, `validate`), `core/defs/scenario_def.gd` (`end_year`, `creditors`, `known_digests`, `validate`), `core/defs/diplomacy_def.gd` (`TERMS` `fallen`, `truce_of`), `core/defs/ai_temper_def.gd` (`bankrupt_pick`, `validate`); `tests/core/test_whole_defs.gd` (new; the classes' cases); edit `tests/core/test_scenario_defs.gd`, `tests/core/test_diplomacy_defs.gd`, `tests/core/test_ai_defs.gd` | Spec 5.1: every `validate` case and planted fault of spec 9 for these classes; every M3 to M11 test green unchanged. Lint, check_scripts, GUT green |
| J2 | L, Sonnet | **The state, the saves, the skeletons** | edit `core/state/country.gd` (country/8), `core/state/market.gd` (market/2), `core/state/war.gd` (`fallen`), `core/state/stats.gd` (62 series), `core/game/game.gd` (`over`, `over_turn`, `dev_used`), `core/game/snapshot.gd`, `core/game/save_file.gd` (`FORMAT` 10, `OLDEST_FORMAT` 10, `upgrade` with no step), `core/systems/treasury.gd` (`WHY` 23, `left_over`), `core/systems/stores.gd` (`FLOWS` 11), `core/systems/people.gd` (`FLOWS` `plague`, `incident`), `core/systems/merchants.gd` (`WHY` `bankrupt`), `core/views/words.gd` (`since_shown` only, so groups B and C can use it); `core/systems/debt.gd`, `core/systems/score.gd`, `core/systems/ending.gd`, `core/systems/incidents.gd` (new: spec 5.3's classes with `OWNS`, every signature, empty bodies); the signatures of `Countries.fall`/`season` (`core/systems/countries.gd`), `Peace.drop_of` (`peace.gd`), `Coalitions.drop` (`coalitions.gd`), `TradePacts.end_of` (`trade_pacts.gd`), `Trade.add_fair` (`trade.gd`), `Research.add_progress` (`research.gd`), `Improve.lower_fortress` (`improve.gd`); `tests/core/debt_fixture.gd` (new: `off`, `on`, `lone`); edit `tests/core/scenario_fixture.gd` (`with_debt`, off by default); edit `tests/core/test_country_state.gd`, `test_trade_state.gd`, `test_war_state.gd`, `test_stats.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_game_core.gd`, `test_owns.gd` (the new fields' owners), `test_treasury.gd`, `test_stores.gd`, `test_people.gd`, `test_merchants.gd`, `test_words.gd` (`since_shown`; P: "12" shown at "4.5"), `test_insights_views.gd` (the pins of format 10, 62 series, 23 `WHY`, 11 flows) | Spec 5.2, 4.13 and the lists of 5.3: every round trip and planted fault of spec 9 for these tests; save, load, save byte-equal; `FORMAT` 10 (P: a format-9 header reads `older`); every M3 to M11 test green on `DebtFixture.off`. Lint, check_scripts, GUT green |
| J3 | M, Haiku | **Bake slice 10 and the app icon** | `tools/ui_bake/pieces_m12.py` (new); edit `tools/bake_ui.py` (the slice), `shell/ui/tokens.gd` (spec 6.2's tokens and `HC_INKS`), `godot/tools/build_theme.gd` (the Kit icons; `ChoiceCard*`, `HintBubble`, `StageGauge`; the high-contrast inks and flat `seal_cracked`); `godot/assets/ui/kit/**`, `godot/assets/ui/icon/hexa.ico`, `hexa.png`, `shell/ui/theme.tres`, `shell/ui/theme_high_contrast.tres` (generated); edit `tests/test_bake_ui.py` | Spec 6.2: the 26 icons, the gauge frame and the icon (16 to 256 px) at 1x and 2x; the variations in both Themes; the contrast asserts (7:1 for the high-contrast inks); both `--check`s; the art director signs the M12 sheet. Lint, check_scripts, GUT green |
| J4 | M, Sonnet (art director signs) | **The map look, 1: decor density and the bold marks** | edit `core/views/map_cells.gd` (`fill_hex` and `of_hex` take a density; the bold marks under high contrast), `shell/map/map_scene.gd` (re-fill the tree layers on `graphics/decor_density`; the bold marks on `accessibility/high_contrast`), `tools/worldmap/tileset_bake/mark_tiles.py` (`mark/select_bold`, `mark/grid_bold`); `godot/assets/tiles/**` and `assets/tiles/tiles_*.tres` (generated); edit `tests/core/test_map_cells.gd`, `tests/shell/test_map_scene.gd`, `tests/test_tileset_bake.py` | Spec 8.15's first two rows: the three densities on north Italy at zoom 1 and the bold marks signed by the art director; `missing_names()` empty at every density; `perf_map` unchanged at full; `build_tileset --check`. Lint, check_scripts, GUT green |
| J5 | M, Sonnet | **The release scaffolding** | edit `godot/export_presets.cfg` (spec 8.2 but the icon), `godot/project.godot` (spec 8.5's logging and crash message, `fallback_to_angle`); `tools/release/check_release.py`, `tests/test_check_release.py`, `docs/release/notes-template.md`, `docs/release/README.txt` (the zip's readme without the keys table), `docs/release/known-issues.md` (new); edit `CHANGELOG.md` (the 0.3.x header: the Godot port is north Italy, 0.3.0 the first public release) | Spec 8.1 to 8.3 and 8.13: `check_release.py` passes on `master` and fails on each planted fault of `test_check_release.py`; **the version probe of spec 10 on the first day** (an export read on the Windows runner by hand dispatch; the fallback taken in this pull request if it fails); `--export-release` with the new filters ships no `tests/`, `tools/` or `addons/gut/` (listed from the pck). Lint, check_scripts, GUT green |

### Group B (after A)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| J6 | M, Haiku (Opus reviews) | **The data** | `data/defs/debt.tres`, `data/defs/score.tres`, `data/defs/incidents.tres`, `data/defs/incidents/plague.tres`, `famine.tres`, `trade_fair.tres`, `silver.tres`, `condottiere.tres`, `flood.tres`, `patron.tres`, `scholar.tres`, `envoy.tres`, `bandits.tres`, `harvest.tres` (new); edit `data/defs/game_defs.tres`, `data/defs/diplomacy.tres` (`keep_last_district` false), `data/defs/tempers/builder.tres`, `cautious.tres`, `steadfast.tres`, `aggressive.tres`, `opportunist.tres`, `conqueror.tres` (`bankrupt_pick`), `godot/tools/build_scenario.gd` (the source table: `end_year`, `creditors`), `data/scenarios/north_italy_1480.tres` (generated), `data/README.md`; `godot/tools/whole_tables.gd`, `tests/core/test_incident_data.gd` (new); edit `tests/core/test_whole_defs.gd` (the data's rows), `tests/core/test_ai_defs.gd` (the values) | Spec 4.1, 4.3, 4.6, 4.8, 4.9 and 7 entered exactly: every row of `test_incident_data.gd`; `GameDefs.validate()` passes; `whole_tables.gd` prints the tables; `build_scenario.gd --check`; **Opus reads the tables on the task's first day**. Lint, check_scripts, GUT green |
| J7 | L, Sonnet | **Debt and bankruptcy** | edit `core/systems/debt.gd` (fill), `core/systems/treasury.gd` (`can_pay` through `Debt.may_pay`), `core/systems/improve.gd` (`lower_fortress`), `core/systems/world_improve.gd` (`lower_castle`); `tests/core/test_debt.gd`, `tests/core/test_bankruptcy.gd` (new); edit `tests/core/debt_fixture.gd` (`lone`'s rows), `tests/core/test_improve_actions.gd`, `tests/core/test_treasury.gd` | Spec 4.1 to 4.3 and 4.14 a: **done-when 1**; every row and planted fault of spec 9 for these tests; the settlement's transfers through `Territory`, castles through `Improve`, memories through `Relations`, orders through `Merchants.free`, generals through `Armies.set_general`; every M3 to M11 pin green on `DebtFixture.off`. Lint, check_scripts, GUT green |
| J8 | L, Sonnet | **Countries that fall** | edit `core/systems/countries.gd` (`fall`, `season`, `OWNS`), `core/systems/peace.gd` (`fallen` in `apply`, `drop_of`), `core/systems/coalitions.gd` (`drop`), `core/systems/trade_pacts.gd` (`end_of`), `core/game/game.gd` (`watch` after a ruin); `tests/core/fall_fixture.gd`, `tests/core/test_fall.gd` (new); edit `tests/core/test_countries.gd`, `test_peace.gd`, `test_coalitions.gd`, `test_trade_pacts.gd`, `test_game_core.gd` | Spec 4.5 and 4.14 b: **done-when 2**; every case and planted fault of spec 9 for these tests; M9's `keep_last_district` sites read the data (false) and their pins pass on the fixtures (true). Lint, check_scripts, GUT green |
| J9 | M, Sonnet | **Prestige and the end** | edit `core/systems/score.gd` (fill), `core/systems/ending.gd` (fill); `tests/core/score_fixture.gd`, `tests/core/end_fixture.gd`, `tests/core/test_score.gd`, `tests/core/test_ending.gd` (new) | Spec 4.6, 4.7, 4.14 c and d: **done-when 3** with `Score.season` and `Ending.check` called directly (`end_check`'s rows come with J14); every other case and planted fault of spec 9 for these tests. Lint, check_scripts, GUT green |
| J10 | L, Sonnet | **Incidents** | edit `core/systems/incidents.gd` (fill), `core/systems/trade.gd` (`add_fair`, `appetite` with fairs, fairs dropped in the phase), `core/systems/research.gd` (`add_progress`); `tests/core/incident_fixture.gd`, `tests/core/test_incidents.gd` (new); edit `tests/core/test_trade.gd`, `tests/core/test_research.gd` | Spec 4.8 and 4.14 e: **done-when 4** on fixture incidents built in code; every effect through its owner (`test_no_other_writers.gd` green); the roll and draw pinned per seed; every row and planted fault of spec 9 for these tests. Lint, check_scripts, GUT green |
| J11 | M, Sonnet (art director signs) | **The map look, 2: ranges along crest chains** | edit `tools/worldmap/tileset_bake/decor_tiles.py` (relief forms `tall`, `left`, `right`), `core/views/map_tiles.gd` (the form from `MapData.crest`); `godot/assets/tiles/**`, `assets/tiles/tiles_*.tres` (generated); edit `tests/core/test_map_tiles.gd`, `tests/test_tileset_bake.py` | Spec 8.15's third row: the Alps at zoom 0.5 and 1 signed by the art director; `missing_names()` empty on north Italy and the fake map; `build_tileset --check`. Lint, check_scripts, GUT green |
| J12 | M, Sonnet | **The release workflow** | `.github/workflows/release.yml`, `.github/actions/godot-checks/action.yml` (new); edit `.github/workflows/godot.yml` (`checks` through the composite action; `playtest-zip` by hand; no `smoke-windows`), `.github/actions/setup-godot/action.yml` (a `platform` input: Linux and Windows); `godot/tools/release/write_licences.gd`, `tools/release/release_notes.py` (new); edit `godot/export_presets.cfg` (the icon), `godot/project.godot` (`config/icon`), `shell/app/app.gd` (a `--smoke` stub that quits with 0; J31 replaces it) | Spec 8.2 to 8.4 and 8.10: a hand dispatch with `dry_run` on a branch produces the zip of 8.3, its checksum and the notes, runs the headless and the windowed (ANGLE) smokes on `windows-latest` against a stub `--smoke` that only quits with 0 (J31 makes it play), and creates no release; **the ANGLE probe of spec 10**; godot.yml's `checks` unchanged in what it runs. Lint, check_scripts, GUT green |

### Group C (after B)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| J13 | M, Sonnet | **Debt in the other systems** | edit `core/systems/wars.gd` (row 9a), `core/systems/research.gd` (the fund row), `core/systems/economy_season.gd` (`debt_limit`, `income_factor` on the tax lines), `core/systems/trade.gd` (the factor on the merchants' line); edit `tests/core/test_wars.gd`, `test_research.gd`, `test_economy_season.gd`, `test_trade.gd` | Spec 1.2's rows for M9, M10, M11 and M4, D17, D18, 4.3's default: each with its planted fault; M9's rows 10 to 15 keep their numbers; every M3 to M11 pin green on `DebtFixture.off`. Lint, check_scripts, GUT green |
| J14 | L, Sonnet | **The season, the actions, the events, `Session`** | edit `core/game/season.gd` (21 `PHASES`, `run_phase`, `end_check`'s rows), `core/game/actions.gd` (40 names, the pairs), `core/state/chronicle.gd` (56 notable kinds), `core/systems/vision.gd` (`SIGHTED`), `core/systems/stats_system.gd` (`score`, `prestige`, `interest`, `deserted`), `core/game/game.gd` (`dev_incident`, `dev_year`, `dev_used`), `core/game/replay.gd` (the dev records), `shell/autoload/events.gd` (eight signals), `shell/autoload/session.gd` (`drain`, `last_phase_ms`, `dev_incident`, `dev_year`, `watch`); edit `tests/core/test_season.gd`, `test_chronicle.gd`, `test_vision.gd`, `test_stats.gd`, `test_game_core.gd`, `test_replay.gd`, `test_insights_views.gd` (the pins of 21 phases, 40 actions, 56 notable kinds), `test_ending.gd` (`end_check`'s rows), `tests/shell/test_session.gd` | Spec 4.10, 4.11's emitters and signals, 5.4, 5.5: **`PHASES` pinned as the twenty-one**; the eight signals drained after their phases and actions; the dev records replay to the same digest (P: another year gives another); `debt_ms`, `incidents_ms`, `scores_ms` measured once on north Italy (printed). Lint, check_scripts, GUT green |
| J15 | M, Sonnet | **The words and the M12 read models** | edit `core/views/words.gd` (spec 5.6's functions but `since_shown` (J2), `terms_text` `fallen`), `core/views/knowledge.gd` (all known once over); `core/views/debt_view.gd`, `core/views/incident_view.gd`, `core/views/score_view.gd`, `core/views/end_view.gd` (new); `tests/core/test_debt_view.gd`, `test_incident_view.gd`, `test_score_view.gd`, `test_end_view.gd` (new); edit `tests/core/test_words.gd`, `test_knowledge.gd` | Spec 5.6 for these files and 6.3 to 6.5 as data: every part from the fixtures; the views' verdicts equal the checks (P); the fog (P: an unknown country's prestige shown before the end). Lint, check_scripts, GUT green |
| J16 | M, Haiku (art director decides) | **The map look, 3: spring and autumn** | edit `tools/worldmap/tileset_bake/art.py` (the two palettes); `godot/assets/tiles/**`, `assets/tiles/tiles_*.tres` (generated); edit `tests/test_tileset_bake.py` (the palettes' pins) | Spec 8.15's fourth row: the four seasons side by side signed by the art director; `build_tileset --check`; the indexes identical across sets (M1's test). Lint, check_scripts, GUT green |
| J17 | M, Sonnet | **Settings across versions, `since`, developer tools** | edit `shell/app/settings.gd` (`dev/developer_tools` false, `audio/ambient` since "13", `state/hints_seen`, the text size step, `since` through `Words.since_shown`), `shell/app/settings_io.gd` (`[meta] schema = 2`, the migration), `shell/input/bindings.gd` (`since` through `Words.since_shown`), `shell/screens/study_page.gd` (`shown_tabs` by number); edit `tests/shell/test_settings.gd`, `tests/shell/test_bindings.gd`, `tests/shell/test_study.gd` | Spec D48 to D50, 6.1, 8.6's table: every case and planted fault of spec 9 for these tests (P: "12" shown at "4.5"; a test build's `dev/developer_tools = true` survives); **every key persists** (the every-key case). Lint, check_scripts, GUT green |

### Group D (after C)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| J18 | M, Sonnet (Opus reviews the words) | **The study, the report, the reminders, the log, the cards** | `core/views/study_debt.gd` (new); edit `core/views/study_rankings.gd` (the Prestige measure; `income_of` less interest), `core/views/study_history.gd` (`fell`, `bankrupt`), `core/views/season_summary.gd` (4.12), `core/views/reminders.gd` (4.12), `core/views/log_lines.gd` (4.11), `core/views/cards_economy.gd` (the debt lines), `core/views/country_card.gd` (fallen, prestige), `core/views/study_diplomacy.gd` (living countries only), `tests/fixtures/report_sample.gd` (the M12 lines); `tests/core/test_study_debt.gd` (new); edit `tests/core/test_study_diplomacy.gd`, `tests/core/test_study_rankings.gd`, `test_study_history.gd`, `test_season_summary.gd`, `test_reminders.gd`, `test_log_lines.gd`, `test_cards_economy.gd`, `test_country_card.gd` | Spec 4.11, 4.12 and 6.4 as data: every sentence and rule with its planted fault; Rankings equals Standing (M4.5's equality); the report equal after a save and load; **Opus reads the words**. Lint, check_scripts, GUT green |
| J19 | L, Sonnet | **The proofs: the property, saves, the contract, a short whole game** | `tests/core/test_whole_property.gd`, `tests/core/test_whole_saves.gd`, `tests/core/test_whole_italy.gd` (new); edit `tests/core/random_player.gd` (`settle_debt`, `answer_incident`), `tests/core/test_check_contract.gd` (40 actions), `tests/core/test_owns.gd` (spec 5.3's table), `test_forty_seasons.gd`, `test_money_property.gd`, `test_men_property.gd` | **Done-when 5 and 6** (but the release saves, J21) as spec 9 lists them, each with its planted fault; `test_whole_italy.gd` green. Lint, check_scripts, GUT green |
| J20 | M, Sonnet | **The perf rows** | edit `godot/tools/perf_fixture.gd` (`europe_whole`), `godot/tools/perf_core.gd` (spec 8.7's rows), `godot/tests/perf_core_budget.json` | Spec 8.7: every row printed and within its limit on the made-up Europe; a failed row takes spec 10's fallback in this pull request. Lint, check_scripts, GUT green |
| J21 | M, Sonnet | **Save compatibility from 0.3.0** | edit `core/game/save_file.gd` (`known_digests` in `read_header`; no "damaged" check after an upgrade); `godot/tools/release/make_release_saves.gd`, `tests/core/test_release_saves.gd`, `godot/tests/fixtures/saves/README.md` (new: what the folder holds and that it is never regenerated); edit `tests/core/test_save_file.gd` | Spec D45 to D47 and 8.6: the tool writes three saves into a temporary folder that the test loads and plays; the test is green with the folder empty (it lists none) and with the temporary saves; the planted faults of spec 9. Lint, check_scripts, GUT green |
| J22 | M, Sonnet | **Text size and high contrast** | edit `shell/ui/kit_theme.gd` (`load_for(..., text_percent)`; the high-contrast inks and bold focus), `shell/ui/ink_chart.gd` (sizes and inks from the Theme); `shell/ui/text_fit.gd` (new: `TextFit.clipped(root) -> Array[String]`); edit `tests/shell/test_kit_theme.gd`, `tests/shell/test_ink_chart.gd` | Spec D54, D55: every font size scaled at 150 % (P: a variation left unscaled); the chart inks in both themes; `TextFit` finds a planted clipped label. Lint, check_scripts, GUT green |

### Group E (after D)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| J23 | L, Sonnet (Opus reviews) | **The AI's debt, settlements and incidents** | `core/ai/ai_debt.gd` (new); edit `core/ai/ai_know.gd` (spec 5.7's functions), `core/ai/ai_brief.gd` (`debt`), `core/ai/ai_turn.gd` (the debt step; the door's tokens), `core/ai/ai_economy.gd` (works within half the credit line); `tests/core/test_ai_debt.gd` (new); edit `tests/core/test_ai_know.gd`, `test_ai_door.gd`, `test_ai_turn.gd`, `test_ai_play.gd` | Spec 4.9: every case and planted fault of spec 9 for these tests (P: `Debt.` in a step module); a fallen seat never acts; `ai_season_ms` measured once on the made-up Europe, in the pull request; Opus reads the settlement and answer counts of 20 AI seasons on north Italy. Lint, check_scripts, GUT green |
| J24 | L, Haiku | **The event pop-up** | `shell/screens/event_popup.tscn`, `shell/screens/event_popup.gd`, `shell/ui/choice_card.tscn`, `shell/ui/choice_card.gd`, `shell/ui/tile_vignette.gd` (new); edit `shell/screens/screen_ids.gd` (`event_popup`, `game_over`); `tests/shell/test_event_popup.gd`, `tests/shell/test_choice_card.gd`, `tests/shell/test_tile_vignette.gd` (new) | Spec 6.3 from `IncidentView` and `DebtView.bankruptcy` fixtures: every part, card state and key per kind (P: Esc closing a bankruptcy); the vignette's seven hexes in the season's TileSet; the art director signs it beside `15_event_popup_frame.png` and `10_bankruptcy_popup.png`. Lint, check_scripts, GUT green |
| J25 | M, Haiku | **The game-over screen** | `shell/screens/game_over.tscn`, `shell/screens/game_over.gd` (new); `tests/shell/test_game_over.gd` (new) | Spec 6.5 from `EndView` fixtures (calendar, conquest, ruin): every part, the buttons per reason, the seal, the dev line; Enter and Esc; the art director signs it. Lint, check_scripts, GUT green |
| J26 | M, Haiku | **The Debt tab, the gauge, the chips, Rankings, the report, the country panel** | `shell/screens/study/economy_debt_tab.tscn`, `economy_debt_tab.gd`, `shell/ui/stage_gauge.gd` (new); edit `shell/screens/study/page_economy.gd` (the tab's scene), `shell/hud/chips.gd` (the debt mode, Prestige), `shell/screens/study/page_rankings.gd` (Prestige first), `shell/screens/season_report.gd` (the lines, the cracked seal), `shell/panels/country_panel.gd`, `shell/panels/country_panel.tscn` (fallen, prestige); `tests/shell/test_economy_debt_tab.gd`, `tests/shell/test_stage_gauge.gd` (new); edit `tests/shell/test_page_economy.gd`, `test_chips.gd`, `test_page_rankings.gd`, `test_season_report.gd`, `test_country_panel.gd` | Spec 6.4 and 6.6 from the view fixtures: every part and empty state; the gauge in each stage and in high contrast; the chips' narrowing order; the art director signs the tab beside `09_debt_bar_and_panel.png`. Lint, check_scripts, GUT green |
| J27 | M, Haiku | **The options pages and the build list by keys** | edit `shell/screens/options.gd` (the ten pages; Audio's Test button; Show hints again; the milestone from the App's context), `shell/screens/options_keys.gd` (its own page; per-action reset; fixed mouse rows; `app_back` keeps Esc), `shell/panels/hex_panel.gd` (1 to 9); edit `tests/shell/test_options.gd`, `tests/shell/test_options_keys.gd`, `tests/shell/test_hex_panel.gd` | Spec 6.7, D52, D53: every page and row (every schema key has a row; P); the Keys page's capture, clash and resets (P: Esc unbound from `app_back`); the number keys (P: a key pressing a refused option). Lint, check_scripts, GUT green |
| J28 | M, Sonnet | **The sound board and the buses** | `shell/app/sound_board.gd`, `godot/default_bus_layout.tres`, `tests/fixtures/sounds_sample.json` (new); edit `godot/project.godot` (`audio/buses/default_bus_layout`); `tests/shell/test_sound_board.gd` (new) | Spec 6.9's code and D58 on the fixture list: buses and volumes, mute on focus out, the gap, 6 voices, the button and screen hooks, the `Events` table (P: a sound played twice inside its gap). Lint, check_scripts, GUT green |
| J29 | M, Haiku (Opus reviews the words) | **Tutorial hints** | `shell/hud/hint_def.gd`, `shell/hud/hint_table.gd`, `shell/hud/hint_layer.gd`, `shell/hud/hint_layer.tscn`, `godot/data/ui/hints.tres` (new); `tests/shell/test_hints.gd` (new) | Spec 6.8: the twenty hints entered exactly; level, once, one at a time, the queue, hidden anchors wait, Hide hints, Esc (on a fixture table and a fixture App); **Opus reads the texts**. Lint, check_scripts, GUT green |

### Group F (after E)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| J30 | M, Haiku (the owner approves by ear) | **The sounds and the music** | `godot/assets/audio/sounds.json`, `godot/assets/audio/effects/*.ogg`, `godot/assets/audio/music/*.ogg`, `tools/audio/render_music.py`, `tools/audio/scores/susato.mid`, `praetorius.mid`, `arbeau.mid`, `tools/audio/check_audio.py`, `tests/test_check_audio.py` (new); edit `.github/actions/godot-checks/action.yml` (the `check_audio.py` step) | Spec 6.9's list: every id has a file, source, licence, volume and gap; `check_audio.py` green and failing on each planted fault of its test; the owner approves the set by ear (a note in the pull request). Lint, check_scripts, GUT green |
| J31 | L, Sonnet | **Wire the App** | edit `shell/app/app.gd` (milestone `"12"`; text size and high contrast applied; the `SoundBoard` and the `HintLayer` mounted; the log's header line; `--dev`, `--smoke`; under 800 lines), `shell/app/game_requests.gd` (spec 6.12's table), `shell/app/decision_queue.gd` (`bankrupt`, `incident_offered`, order D76, the drops), `shell/app/season_flow.gd` (the game-over after the report), `shell/app/study_warm.gd`, `shell/screens/main_menu.gd` (the sandbox behind developer tools), `shell/hud/top_bar.gd` (Results when over), `shell/hud/task_flag.gd` (the M12 actions), `shell/hud/dev_commands.gd` (spec 6.12's commands), `shell/hud/debug_overlay.gd` (the F3 line); `shell/app/smoke_run.gd`, `shell/app/leave_rules.gd` (new); edit `godot/README.md` (the M12 game); edit `tests/shell/test_app_flow.gd`, `test_decision_queue.gd`, `test_main_menu.gd`, `test_task_flag.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`; `tests/shell/test_smoke_run.gd`, `tests/shell/test_leave_rules.gd` (new) | Spec 6.11, 6.12, 8.9: the end to end of spec 9 (`test_app_flow.gd`); the smoke prints `SMOKE OK` in-process; `confirm_loss` (P); the decisions' order and drops; the console's commands and planted faults; still two autoloads; a release workflow dry run's smokes now play 8 seasons. Lint, check_scripts, GUT green |

### Group G (after F)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| J32 | M, Haiku | **Credits and About** | edit `godot/CREDITS.md` (spec 8.12), `shell/screens/credits.gd` (sections, the engine notices), `shell/screens/about.gd` (the logs line, Open logs folder, the last run's tail); `tests/shell/test_credits.gd` (new); edit `tests/shell/test_about.gd` | Spec 6.10, 8.12: every section; `check_release.py` green on the credits; the planted faults of spec 9 (P: a log tail copied after a clean exit). Lint, check_scripts, GUT green |
| J33 | L, Sonnet | **The whole-game soak** | edit `godot/tools/soak.gd` (the `whole` suite, the saves at 160, 400 and 684, `runaway` reported, the ranges, the summary's columns), `tests/core/invariants.gd` (`debt`, `fallen`, `score`, `ending`; `peaces` as spec 1.2), `tests/core/test_invariants.gd`, `tests/core/test_ai_soak_quick.gd`, `.github/workflows/godot.yml` (the nightly `whole` 1-5 and 6-10, judged by `soak-ranges`), `.github/workflows/release.yml` (the `whole` matrix of 10 legs) | Spec 4.15: every invariant (P each), the ranges and the summary; a full run of the 100 games on runners by hand dispatch, the tables in the pull request; **Opus reads them before group I**. Lint, check_scripts, GUT green |
| J34 | M, Sonnet | **The docs for players** | `godot/tools/keys_table.gd` (new); edit `README.md` (the 0.3.0 section and the generated table), `docs/release/README.txt` (the table), `CLAUDE.md` (spec 8.11's commands), `godot/README.md` (the release, the new folders), `.github/actions/godot-checks/action.yml` (the `keys_table.gd --check` step); `tests/shell/test_keys_table.gd` (new) | Spec 8.11: the table equals `Bindings.DEFAULTS` to milestone 12; `--check` fails on a planted edit; the owner reads the README section. Lint, check_scripts, GUT green |

### Group H (after G)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| J35 | M, Haiku | **Monkey, pictures, the UI perf rows** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`, `tests/fixtures/ui_sample.gd` (a country in debt, a pending settlement, an open incident, a game over); the signed pictures as goldens (`godot/tests/goldens/m12_*.png`) | The monkey's invariants green on 3 seeds; spec 9's pictures at 1280 x 720 scale 1 and 2560 x 1440 scale 2, signed by the art director; spec 8.7's UI rows within their limits. Lint, check_scripts, GUT green |
| J36 | M, Sonnet | **Keyboard reach, text fit, hint anchors, no stand-in** | `tests/shell/test_keyboard_reach.gd`, `tests/shell/test_text_fit.gd`, `tests/shell/test_hint_anchors.gd` (new); edit `tools/lint_godot.py` (the scene text rule); `tests/test_lint_godot.py` (new: the rule and its planted fault) | Spec 9.3 items 7 and 9: every screen of `ScreenIds.PATHS` by keyboard; no clipped text at 150 % on the shot list; every hint's anchor resolves; the lint fails on a planted "placeholder" label. Lint, check_scripts, GUT green |

### Group I (after H)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| J37 | M, Sonnet (Opus decides) | **The tuning pass: the balance gate** | edit `data/defs/debt.tres`, `data/defs/score.tres`, `data/defs/incidents.tres`, `data/defs/incidents/*.tres`, `data/defs/tempers/*.tres`, `data/defs/trade.tres` (spec 12 row 101's tolls decision), `tests/core/test_whole_defs.gd`, `tests/core/test_incident_data.gd` (the values), `godot/tests/goldens/m12_*.png` (re-made when a number on a picture moved, signed again), `docs/architecture/m12-build-spec.md` (4.1, 4.3, 4.6, 4.8, 4.15 where Opus changes a number) | **Done-when 7**: every range of spec 4.15 on the 100 `whole` games with the final data; M8 to M11's ranges re-measured with debt and incidents on (kept, or changed with Opus's word); the tolls decision of row 101 written; Opus's verdict and the per-country table in the pull request. Lint, check_scripts, GUT green |

### Group J (after I)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| J38 | M, Sonnet (Fable reviews; the owner and the art director sign) | **The release candidate** | `godot/tests/fixtures/saves/0.3.0/*.sav`, `*.png` (made by `make_release_saves.gd` on the candidate), `docs/release/0.3.0-checklist.md`, `docs/release/0.3.0-perf.md`, `docs/design/map/release-look.md` (new); edit `CHANGELOG.md` (the `## v0.3.0` section), `docs/release/known-issues.md`, `docs/architecture/godot-architecture.md` (9.2: M12 done) | Spec 9.3: every item of the checklist ticked with its evidence; the release budgets measured on the reference PC; the release look signed; the owner's release playtest (section 4) passed; a release workflow dry run green on the candidate; then the tag `v0.3.0` pushed and the draft release made. Lint, check_scripts, GUT green |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** signs the state, the save format and its freeze, the phases' places, the `OWNS` table and the
  decisions' order (spec 4.10, 4.13, 5.2 to 5.4, D45 to D47, D76) before group A starts; reads the interfaces of J1, J2, J7, J8,
  J9, J10, J14 and J15 before they merge; reads J12's workflow, J21's save rules and J31's smoke together; reads J33's invariants
  and J19's properties together; signs J38's checklist and the tag.
- **Opus** reads J6's tables on its first day, J18's and J29's words, J23's settlement and answer counts; reads J33's whole-game
  tables before group I and gives J37's balance verdict (a changed number is a data edit with the tests it moves, in J37's pull
  request).
- **The art director** signs J3's sheet and icon, J4's densities and marks, J11's ranges, J16's palettes, J24's pop-up beside
  `15_event_popup_frame.png` and `10_bankruptcy_popup.png`, J25's game-over, J26's Debt tab beside `09_debt_bar_and_panel.png`,
  J35's pictures, and J38's release look.
- **The owner** approves J30's sounds by ear, reads J34's README section, plays the release playtest (section 4) and publishes
  the draft release.
- **Pull requests** say what changes for the player. J2 makes M11 saves unloadable ("Made by an older test build") and freezes the
  format from 0.3.0: said. J7 lets a country spend on credit and makes debt cost: said. J8 lets a peace take the last district
  (`keep_last_district` false, J6): said. J10 brings events: said. J17 turns developer tools off by default: said. J23 changes
  what the other countries do in debt: said, with the soak's tables. No test pins a digest value.

---

## 4. The owner's release playtest

On Windows (mouse), with the zip of the candidate unpacked to a new folder and a fresh `%APPDATA%\Hexa` (rename the old one);
then on the MacBook (trackpad) from `master` for part A only. Part A checks the M12 features in about an hour with developer
tools on; part B is a whole game, as a player, with developer tools off.

**Part A: the M12 features** (about 60 minutes; Options, Advanced, Developer tools on)

1. The main menu: no Map sandbox. Options, Advanced: Developer tools on; back: Map sandbox shows. Turn it off again: hidden.
2. Options, Audio: Master, Music, Effects, Mute when in the background; **Test** plays the seal. Music plays on the menu; Alt+Tab
   away: silence; back: music.
3. Options, Keys: rebind End season to **K**; press **F** on another action: "F is already Fit whole map"; Reset all keys.
4. Options, Accessibility: Text size **150 %**: every page reflows, nothing cut; **High contrast**: black fields, white text, the
   yellow focus ring. Back to 100 % and off.
5. New game, seed **1480**, Genoa. The hints: "Pick a country on the map ..." then, in play, the chips' hint; **Got it**.
6. F2: `money -300`. The Ducats chip turns red with the debt icon and a gauge; hover: "In debt: 300 ducats at 2 %. Credit stops
   at ..."; begin a work: allowed on credit. End season: the report's treasury shows "Interest ▼ −6"; the log "You are in debt".
7. Press **I**, Economy, the **Debt** tab: the gauge with "you", the countdown, This season, the Ways out (Taxes to High: press it,
   the toast), the chart.
8. F2: `money -2000`; End season: the event pop-up **Bankruptcy!** with three cards; Esc: the toast "the game waits"; End season:
   refused "settle with your creditors first". Press **3**, then **Settle**: the debt halved, companies gone, the toast and the log.
9. F2: `incident plague`: the pop-up "Plague in Genoa" with three cards; **Esc** (decide later); the task flag's line; End
   season: it lapses to "Pray and process"; the log says so.
10. F2: `fall LUC TUS`, End season: "The Republic of Lucca is no more."; it leaves the Diplomacy page's matrix; Rankings lists it
    below the living.
11. The **Prestige** chip: hover: the parts; click: Rankings on Prestige, your rank; the report's Standing line equals it.
12. F2: `year 1650`; End season four times: the report of Winter 1650, then **the game-over screen**: "The year 1651", your place,
    your prestige by part, the chart, the ranking of every country, "Developer commands were used in this game". **View the map**:
    End season reads **Results**; press it; **Main menu**.
13. Options, Game: **Ask before losing progress** off; New game, play a season, Main menu: no question; Load game, a slot,
    Delete: still asks. On again.
14. Options, About: the version 0.3.0, the logs line; **Open logs folder** opens `%APPDATA%\Hexa\logs` with `hexa.log`.

**Part B: a whole game** (about 8 hours in 4 sittings; developer tools off; Normal movement; hints Basic)

New game, seed of your choice, a country of your choice (not the one of Part A). Play as a player would. At each checkpoint, write
the date, your prestige and rank, your treasury and stage, and one sentence of what happened, in `docs/release/0.3.0-checklist.md`:

| Checkpoint | Look for |
|---|---|
| Summer 1481 (season 6) | the hints met so far were useful and not in the way; one save (F5) and one load (F9) |
| Spring 1494 (season 57) | a war fought; the report and the log told you why each season went as it did |
| Spring 1520 (season 161) | an era came (yours or a neighbour's); a few events met; the Debt tab at least opened once |
| Spring 1550 (season 281) | quit the game and start it again: Continue opens where you were; the settings you changed held |
| Spring 1575 (season 381) | the third era; no screen you could not leave by Esc |
| Spring 1600 (season 481) | prestige: does the ranking match what you see on the map? |
| Spring 1625 (season 581) | season time: End season to the report never felt slow |
| Winter 1650 (season 684) | the game-over screen; the ranking; save; leave; load the save: the game-over again |

Pass: no crash; End season always played or said why; nothing blocked you; every checkpoint written. Anything else goes into
`docs/release/known-issues.md` (fixed before the tag if it is a blocker by the checklist, listed if not).

---

## 5. Definition of done

1. The spec's "M12 is done when" items 1 to 13 hold.
2. Tasks J1 to J38 merged; CI green, with every `--check` of the plan's section 2 and the nightly `soak` (with `whole`),
   `soak-ranges`, `perf_core`, `perf_ui` and `perf_map` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens; the release look is signed.
4. Every item of `docs/release/0.3.0-checklist.md` is ticked; the owner has played section 4 on Windows (and part A on the Mac).
5. The tag `v0.3.0` is pushed, the release workflow is green, and the owner has published the draft release.
6. `godot-architecture.md` 9.2 marks M12 done; `godot/README.md`, `README.md` and `CHANGELOG.md` describe 0.3.0.
7. Section 7 below is handed to the authors of the after-M12 milestones.

---

## 6. How to start

On the day M11 closes:

1. Opus presents the debt numbers and the three settlements (spec 4.1 to 4.3), the prestige formula (4.6), the deck of eleven
   incidents (4.8) and the balance gate (4.15) to the owner and Fable in 30 minutes; a changed number is a data line now, not a
   task later. Fable signs the state, the save format and its freeze, the phases' places and the `OWNS` table the same day.
2. Start group A together: **J1**, **J2**, **J4** and **J5** (Sonnet) and **J3** (Haiku). J5 runs the version probe on its first
   day, so the export's fallback is settled before J12 builds the workflow on it.
3. The art director books three short sessions: J4 (group A), J11 (group B), J16 (group C), so the look is signed long before J38.
4. J33's first full `whole` run goes to Opus the day it runs; group I waits for Opus's reading.
5. The owner keeps two days free when group J starts, for the release playtest.

---

## 7. What M12 hands on

- **After M12** (spec section 13; the owner picks the order): M13 Europe (E2, E3, the switch of spec 8.14, 0.4.0); M14 Map look
  II; M15 Alliances; M16 Rebels and free states; M17 Historical claims; M18 Crown projects and loans; M19 Ships, sea war and sea
  trade; M20 Exploration and fog of discovery; M21 Colonies; M22 Random worlds; M23 City states; M24 The battle board and field
  forts; M25 Characters; M26 Achievements and Steam (0.9); M27 Localisation. Each starts from its spec, written when it is next.
- **Seams M12 leaves:** `EventPopup` for M16's revolts and later events; `Game.dev_used` for M26's achievements; `Countries.fall`
  and the `extinction` phase for M16's countries that rise; `Score.parts` for M18's crown projects; `ScenarioDef.creditors` for
  M18's lenders; `Words` and the `.tres` names for M27.
- **Saves:** `SaveFile.FORMAT` 10, `OLDEST_FORMAT` 10, frozen: every later bump adds `_upgrade_<n>` and keeps the 0.3.0 saves of
  `godot/tests/fixtures/saves/0.3.0/` loading (spec D45, D46); a new body field with a default needs no bump (M3 4.10).
- **Releases:** a tag `vX.Y.Z` runs `release.yml`; each release adds its three saves to `godot/tests/fixtures/saves/` and its
  section to `CHANGELOG.md`.
