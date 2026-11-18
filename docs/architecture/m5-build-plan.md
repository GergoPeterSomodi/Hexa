# M5 build plan: People

Game and systems designer (Opus), 2026-11-17. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/m5-build-spec.md` ("the spec").

**Starts after M4.5 is closed** (its plan's definition of done, the owner's playtest). M5 edits what M1.5 to M4.5 deliver:
`Game`, `Session`, `Events`, the season table, `MapState`, `Country`, `StateView`, `Stats`, `StatsSystem`, `Economy`,
`DistrictCache`, `Improve`, `WorldImprove`, the previews, the report's view, the reminders, the log lines, the study's views
and pages, the map modes and overlay, the map scene, the labels, the floaters, the chips, the hex and country panels, the top
bar and the App. The standard's rule holds: the next milestone starts after the owner has played the last one.

**The M5 row of `ui-style-and-feedback-plan.md` S5** (People page; people in Rankings; People section; `town_grew`,
`district_declined`; Food map mode) is folded in: the People page is P11, people in Rankings P10 and P11, the People section
P10, the two events P4 to P6, the Food mode P9 and P14.

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Definitions and state** | the people numbers, the settlement columns and costs, the per-hex arrays, the country's flows, the view's people, five series; lowering a settlement; labels and ribbons ready | P1, P2, P3, P15 | 2 M, 2 S |
| **The people rules** | `People`: room, growth, hunger, crowding, the levels, the door, the levy seam; M4's economy on live people | P4 | 1 L |
| **The season** | the people phase, the game's setup, stats, saves, replay; M4 and M4.5 tests on still people | P5 | 1 L |
| **Events, previews, the map's read model, proofs** | the two events and their lines; the previews with people; the Food mode's bytes; the growth test, the properties, the worked year, the report tool, the season's perf rows | P6, P7, P9, P17 | 2 L, 2 M |
| **Read models** | `PeopleView`, the chips' cards, the People page's view, the hover and country cards; the report, reminders, Rankings, History, the tax hover | P8, P10 | 2 M |
| **Screens and the map** | the People page and Rankings' third measure, the chips, the hex and country panels, the Food mode on the map | P11, P12, P13, P14 | 1 L, 3 M |
| **Wiring and proof** | the App, the warmer, F3, the console, the top bar; monkey, pictures, the UI perf rows and the two view rows | P16, P18 | 1 L, 1 M |

18 tasks: 6 L, 10 M, 2 S, about 26 worker-days; about 15 to 16 working days end to end with the groups below (each group
takes as long as its longest task), plus reviews and the owner's playtest.

```
M4.5 closed (the owner's playtest)
  -> A:  P1  P2  P3  P15
  -> B:  P4 (L)
  -> C:  P5 (L)
  -> D:  P7 (L)  P17 (L)  P6  P9          (P17's economy report: Opus's food-balance gate before E)
  -> E:  P8  P10
  -> F:  P14 (L)  P11  P12  P13
  -> G:  P16 (L)
  -> H:  P18  -> the owner plays M5

Critical path: P2 -> P4 -> P5 -> P7 -> P8 -> P14 -> P16 -> P18     (and P1 -> P4; P6 -> P10 -> P11)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel and no two touch
one file.

---

## 2. Tasks

Who, per the standard's section 9 ("Opus / Sonnet, Haiku"): *Sonnet* builds systems, views, tools and anything touching
`Game`, saves, the season table, `Session`, `Events`, input, the map overlay or the App; *Haiku* builds data files, kit-based
panels and pages from the spec's tables, and tests from a list; *Opus* reviews the numbers and the words; *Fable* reviews
interfaces. Generated files belong to the task that changes their source. **Every task's done-when includes: lint
(`python tools/lint_godot.py godot`), check_scripts and GUT green**, both UI `--check`s (`bake_ui.py --check`,
`build_theme.gd --check`, which M5 does not change), `build_map --check` and `build_scenario.gd --check`. Paths without a
prefix are under `godot/`; `docs/` is at the repository root.

### Group A (parallel)

| # | Size, who | Task | Files (new unless said) | Done when |
|---|---|---|---|---|
| P1 | M, Haiku (Opus reviews) | **The people numbers** | edit `core/defs/game_defs.gd` (the eight fields of spec 5.1, `validate`), `core/defs/family_def.gd` (`room`, `falls_below`, `validate`), `data/defs/game_defs.tres`, `data/defs/families/settlements.tres` (`room`, `falls_below`, the costs of levels 2 and 3), `data/README.md`, `godot/tools/economy_tables.gd` (the people tables); edit `tests/core/test_economy_defs.gd`, `tests/core/test_family_defs.gd` | Spec 4.4, 4.5, 4.6 and 5.1 entered exactly; every planted fault of spec 9 for these two tests; `economy_tables.gd` prints the two tables; Opus reads the values on the task's first day |
| P2 | M, Sonnet | **People in the state** | edit `core/state/map_state.gd` (`map-state/4`), `core/state/country.gd` (`country/3`), `core/state/state_view.gd` (`people_at`, `with_people`), `core/state/stats.gd` (five series); edit `tests/core/test_map_data.gd`, `test_country_state.gd`, `test_state_view.gd`, `test_stats.gd` | Spec 4.16, 4.18, 5.2: round trips, the older schemas at zeros, the digests move with one person and one flow; 40 series; the size projection; planted faults of spec 9 for these files |
| P3 | S, Sonnet | **A settlement can fall a level** | edit `core/systems/world_improve.gd` (`lower_check`, `lower`), `core/systems/improve.gd` (`lower_check`, `lower`); edit `tests/core/test_world_improve.gd` | Spec 5.3 for these; each refusal with its words (P each); the distances follow a lower; `lower` emits one `hex_changed`; every M1 refusal string unchanged |
| P15 | S, Haiku | **Labels follow the level; the floaters' public ribbon** | edit `shell/mapview/map_labels.gd` (`set_state`), `shell/map/floaters.gd` (`add_ribbon`, M3's chronicled path through it); edit `tests/shell/test_map_labels.gd`, `tests/shell/test_floaters.gd` | Spec 6.8 and 6.9: a settlement's label from the state's level, others from the data; `add_ribbon` within M3's limits (3 a hex, 16 in all, on screen only, waiting under a modal); M3's ribbon cases unchanged |

### Group B (after A)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| P4 | L, Sonnet | **The people rules** | `core/systems/people.gd`; edit `core/systems/economy.gd` (`people_at` through the view, `hands_at` and `jobs_near` of the owner's hexes, `district_base`'s keys), `core/systems/district_cache.gd` (14 fields, live staffing); `tests/core/people_fixture.gd`, `tests/core/test_people.gd`, `tests/core/test_people_checks.gd`; edit `tests/core/test_economy.gd`, `test_district_cache.gd`, `test_no_other_writers.gd` | Spec 4.2 to 4.5, 4.7, 4.20, 5.3: every case and planted fault of spec 9 for these files; `district_output == season_output(district_base)` on every land hex of north Italy; `People.season` and `People.close` exist and are tested on a game built by the test (the season table is P5's); no engine calls (lint) |

### Group C (after B)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| P5 | L, Sonnet | **The season, the game, stats and saves** | edit `core/game/season.gd` (`PHASES`, `people`), `core/game/game.gd` (People in `new_game` and `new_scenario`, `dev_people`), `core/systems/stats_system.gd` (spec 4.16, `People.close`), `core/game/replay.gd` (`dev_people`), `core/game/snapshot.gd` (the new fields' checks), `core/game/save_file.gd` (`FORMAT` 3, `OLDEST_FORMAT` 3); `tests/core/test_people_season.gd`; edit `tests/core/test_season.gd`, `test_game_core.gd`, `test_replay.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_owns.gd`, `test_forty_seasons.gd`, `test_improve_actions.gd`, and, for still people, `tests/core/economy_fixture.gd`, `test_economy_genoa.gd`, `test_economy_1480.gd`, `tests/core/insights_fixture.gd`, `test_insights_views.gd` (the pins to M5's values) | **`PHASES` pinned as `[production, income, works, people, stats, calendar]`**; spec 4.11 (d) and (e) in `test_people_season.gd` to the season; save, load, save byte-equal with the M5 fields; every M4 and M4.5 test green with its numbers unchanged on `PeopleFixture.still`; the people phase timed on the made-up Europe by a probe run (the number in the pull request; spec 10's fallback applied when over 30 ms) |

### Group D (after C)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| P6 | M, Sonnet | **Events, Session, the chronicle, the log, the words** | edit `shell/autoload/events.gd`, `shell/autoload/session.gd` (`dev_people`, the drain, `last_phase_ms`), `core/state/chronicle.gd` (`NOTABLE`), `core/views/log_lines.gd`, `core/views/words.gd` (`settlement`, `people`); edit `tests/shell/test_session.gd`, `tests/core/test_chronicle.gd`, `test_log_lines.gd`, `test_words.gd`, `tests/shell/test_notifications.gd` | Spec 4.17, 5.5, `Words` of 5.6: the two signals drained after the people phase, then `chronicled`; the sentences for the player, a known and an unknown other; the two notifications; still two autoloads |
| P7 | L, Sonnet | **The previews with people** | edit `core/views/economy_preview.gd` (the people step, the stepped hexes, the window's staffing, the new season fields), `core/views/improve_preview.gd` (the room line, the people note, the room chip); edit `tests/core/test_economy_preview.gd`, `tests/core/test_improve_preview.gd` | Spec 4.10, 4.11 (c), 5.6: **the 200-case property with the real (growing) defs** (spec done-when 5); `with(..., 8)` equals eight played seasons for every country, people included; 4.11 (c) exactly; M4's (c) and (e) on still people; `preview_ms` and `reminders_ms` timed on the made-up Europe by a probe run (the numbers in the pull request) |
| P9 | M, Sonnet | **The Food mode's read model** | edit `core/views/map_modes.gd` (`Mode.FOOD`, `MODE_KEYS`, the FOOD constants, `food_year`, `food_band`, `food_bytes`, `food_ramp`, `legend(FOOD)`, `legend_title`, `colour_of`'s `food_byte`, `modes`); edit `tests/core/test_map_modes.gd` | Spec 5.6 (`MapModes`): the bands' edges, the colour distances (6, 15, 15, 15), `food_year` and 4.11 (f)'s bytes for Genoa; planted fault: a Milan hex is 0 |
| P17 | L, Sonnet (Opus reads the report) | **Proofs, the worked year, the report tool, the season's perf rows** | `tests/core/test_people_growth.gd`, `tests/core/test_people_property.gd`, `tests/core/test_people_genoa.gd`; edit `godot/tools/economy_report.gd` (people, towns, hungry seasons, levels gained and lost per country), `godot/tools/perf_core.gd` (`season_ms`, `production_ms`, `people_ms`, `stats_phase_ms`, `reminders_ms`, `expected_ms`, `preview_ms`, `save_mb` on the M5 season), `godot/tests/perf_core_budget.json`; and, only when spec 10's food-balance rule applies, `data/defs/game_defs.tres` (`growth_bp`) with the tests it moves (`test_people_genoa.gd`, `test_people_growth.gd`, `test_people_season.gd`, `test_people.gd`) | **Done-when 1, 2 and 3** (3's report part is P10's); 4.11 (a) exactly; the rows printed and within their limits; the economy report for seeds 1480 to 1484 in the pull request; **Opus applies spec 10's food-balance rule before group E starts** (a data change, if any, lands in this pull request with the tests it moves) |

### Group E (after D)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| P8 | M, Sonnet (Opus reviews the words) | **The people's read models** | `core/views/people_view.gd`, `core/views/cards_people.gd`, `core/views/study_people.gd`; edit `core/views/hex_card.gd` (People, Food), `core/views/country_card.gd` (people); `tests/core/test_people_view.gd`, `tests/core/test_cards_people.gd`, `tests/core/test_study_people.gd`; edit `tests/core/test_hex_card.gd`, `test_country_card.gd` | Spec 5.6 and 6.3: every outlook row with its words; the fog (P: an unknown country's people not shown); the cards' lines sum to the chips' changes; the page's view equals 4.11 (a)'s Summer 1480 numbers |
| P10 | M, Sonnet (Opus reviews the words) | **The report, the reminders, Rankings, History, the tax hover** | edit `core/views/season_summary.gd` (People section, glance, quiet, Standing), `core/views/reminders.gd` (`hunger`, `town_full`), `core/views/study_rankings.gd` (people), `core/views/study_history.gd` (two marks, the season line), `core/views/study_economy.gd` (the tax notes), `tests/fixtures/report_sample.gd` (the People section of 4.11 b); edit `tests/core/test_season_summary.gd`, `test_reminders.gd`, `test_study_rankings.gd`, `test_study_history.gd`, `test_study_economy.gd` | Spec 4.14, 4.15, 6.7: **the people lines sum every season of a 40-season run** (done-when 4) and the food line equals the closed flows and `food_need` (done-when 3's report part); 4.11 (b) exactly; Rankings equals Standing with people every season; the planted faults of spec 9 for these files |

### Group F (after E)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| P11 | M, Haiku | **The People page; Rankings' third measure** | `shell/screens/study/page_people.tscn`, `shell/screens/study/page_people.gd`, `tests/shell/test_page_people.gd`; edit `shell/screens/study_pages.gd` (`LIST`), `shell/screens/study/page_rankings.gd` (the third measure's row when M4.5's layout needs it), `tests/shell/test_study.gd`, `tests/shell/test_page_rankings.gd` | Spec 6.6 and 6.7 from the first-year game: the head, the table's columns and sort, the countryside line, the two charts, Look there and Show on the map, the span, before a season, the digest unchanged; four pages in the nav; Rankings' three measures at 1280 x 720; the art director signs the page |
| P12 | M, Haiku | **The People and Food chips** | edit `shell/hud/chips.tscn`, `shell/hud/chips.gd`, `tests/shell/test_resource_chips.gd` | Spec 6.2: values, changes, cards from `PeopleCards`, clicks request the People page, hidden in the sandbox and the pick; the art director signs the four chips |
| P13 | M, Haiku | **The hex panel's People section; the country's people** | edit `shell/panels/hex_panel.tscn`, `shell/panels/hex_panel.gd`, `shell/panels/country_panel.tscn`, `shell/panels/country_panel.gd`, `tests/shell/test_hex_panel.gd`, `tests/shell/test_country_panel.gd` | Spec 6.3 and 6.4: yours, known (banded), unknown (none), unowned; every outlook row's tone; refreshes on `town_grew` and `district_declined` |
| P14 | L, Sonnet | **The Food mode on the map; the map's people** | edit `shell/map/mode_overlay.gd`, `shell/map/mode_overlay.gdshader`, `shell/map/map_scene.gd` (Food updates, `MapLabels.set_state` and `refresh`, the season's ribbons through `add_ribbon`), `shell/input/map_input.gd` (`view_mode_5`), `shell/input/bindings.gd` (`view_mode_5`), `shell/app/settings.gd` (`state/map_mode` `food`), `shell/hud/mode_legend.gd` (`legend_title`), `godot/tools/map/probe_mode_overlay.gd`; edit `tests/shell/test_mode_overlay.gd`, `test_map_scene.gd`, `test_map_input.gd`, `test_bindings.gd`, `test_settings.gd`, `test_mode_legend.gd` | Spec 6.5, 6.8, 6.9: key 5, the two textures, `update_food` writing only changed texels (P: one byte, one texel), updates only while in Food, the restored mode; a `town_grew` repaints exactly `MapCells.touched_by` and refreshes the labels; the ribbons; the probe prints PASS on the runner and the owner's Mac (and FAIL with `--plant`); the art director signs Food on north Italy and the grown village's piece |

### Group G (after F)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| P16 | L, Sonnet | **Wire the App** | edit `shell/app/game_requests.gd` (spec 6.10's table), `shell/app/app.gd` (the milestone `"5"`; under 800 lines), `shell/app/study_warm.gd` (the people view, the food bytes), `shell/hud/top_bar.gd` (the chips' order and narrowing, the Food segment and its tooltip), `shell/hud/dev_commands.gd` (`people`), `shell/hud/debug_overlay.gd` (the F3 line), `godot/README.md` (key 5, the People page, the console's `people`); edit `tests/shell/test_app_flow.gd`, `test_hud.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_study_warm.gd`, `test_season_report.gd`, `test_task_flag.gd` | The flow test of spec 9 end to end; done-when 7 holds in the shell tests; the sandbox has no Food mode, no chips and refuses `people` |

### Group H (after G)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| P18 | M, Haiku | **Monkey, pictures, perf** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`, `godot/tools/perf_core.gd` (`study_people_ms`, `food_bytes_ms`, timed as M4.5's view rows are), `godot/tests/perf_core_budget.json`; the signed pictures as goldens (`godot/tests/goldens/m5_*.png`) | The monkey's new keys and invariants green on 3 seeds; spec 9's pictures at 1280 x 720 scale 1 and 2560 x 1440 scale 2, signed; spec 8's UI rows and the two view rows within their limits |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** signs `People.move`, `change_at`, the people row of the season table and the save fields
  (spec 4.4, 4.8, 4.18, 5.2, 5.3) before P4 starts, and reads the interfaces of P2, P4, P5, P7, P14 and P16 before they
  merge; the `OWNS` table of P5 with P4's door together.
- **Opus** reviews P1's numbers on its first day, P17's economy report (seeds 1480 to 1484) before group E starts (the
  food-balance rule of spec 10), the words of P6, P8 and P10 against spec 4.14, 4.15, 4.17 and 6.3, and P11's page. A changed
  number is a data edit with the tests it moves, in P17's pull request.
- **The art director** signs P11 (the page; no mockup exists, the page is built from `game-feedback-screens.md` C.2 and the
  M4.5 pages' kit), P12 (the four chips), P14 (the Food colours, the stripes and the legend on north Italy; the village near
  Turin before and after it grew) and P18's pictures.
- **Pull requests** say what changes for the player. P4 and P5 change behaviour on purpose (people grow and starve; towns
  level by themselves; the season gains a phase; hands count the owner's land only): said in P5's pull request, with every
  M4 and M4.5 test moved to still people there. P2 and P5 change `Game.digest()` (new fields): said; no test pins a digest
  value. P5 makes M4 saves unloadable ("Made by an older test build"): said. P1 changes two costs: said.

---

## 4. The owner's playtest of M5

On Windows (mouse) and on the MacBook (trackpad), with a fresh user folder. New game, More, seed **1480**, Italy 1480, Play as
Genoa. The weather is drawn in your game: the people numbers below do not depend on it (Genoa's food is its port's fish),
the ducats do by a few.

1. The top bar shows **Ducats 610**, **People 82,700**, **Food 16** and Stores. Hover People: "Towns 40,000", "Countryside
   42,700", "Room for 33,000 more". Hover Food: "Your towns need 4 a season", "Lasts over 8 seasons".
2. Hover Genoa: "People 30,000 · room 45,000" and "Food: made 22, eaten 12 a year". Select it: the People section reads
   "Room for 15,000 more; a city would give room for 100,000." Select the vineyard (7, 12): "Room for 2,000 more: about 80
   come each season."
3. Press **5**: the Food mode. Genoa in green-gold, Savona paler, the farmland (7, 13) between, the woods parchment; your
   neighbours under the dark veil; the legend top left, "Food: made less eaten, a year". The minimap shows the same. Press 1.
4. Press **F5** (a quicksave of Spring 1480 to come back to). Select Genoa, press **U**: the card reads "Room 45,000 →
   100,000", gains +15, +16, +15, +10 a season, payback in Winter 1500 (at the realm's measure), refused for ducats. Esc.
5. F2 (the console): `people 6 11 3990`, then Space. The log and the report's What befell: "Savoy: the village near Turin
   (6, 11) grew into a town."; on the map the piece at (6, 11) is a town now and its label is larger. **F9.**
6. F2: `people 6 13 1900`, then Space: a notification "Savona (6, 13) fell to a village: too few people."; its piece
   shrinks. Select it: "Stays a village: Cuneo (5, 13) is a town beside Savona: two towns may not stand side by side."
   **F9.**
7. F2: `people 8 13 80000` and `goods grain -16`, then Space: the report's food line "Food: 8 made for 9 needed. 1 short:
   your towns lost 404 people to hunger."; the Food chip's card says so; the task flag has "Your towns went hungry"; in the
   Food mode Genoa is striped madder. **F9** (nothing of steps 5 to 7 is left).
8. **Space**: the report's **People** section: "Genoa (8, 13) 30,300 ▲ +300", "Savona (6, 13) 10,100 ▲ +100", "The
   countryside, 12 places, 42,885 ▲ +185"; the total 82,700 → 83,285 ▲ +585 (add them); "Food: 8 made for 4 eaten. Fed, 4 to
   spare." The glance has "People 83,285 ▲ +585". Close it: "People +300" rises over Genoa, "People +100" over Savona.
9. Space, Space: Summer's report. Its Treasury shows Taxes on people **66** (it was 65): the people pay as they grow.
10. Press **I**, then `]` to the **People** page: Genoa and Savona with their room and outlook, the countryside line, the
    food and growth charts filling. "Show on the map": the study closes in the Food mode on Genoa.
11. Press I, `]` `]` to Rankings: a third list, **People**: "You are 3rd of 3.", Savoy banded ("about 260,000").
12. The Economy page's tax **High**: its note says people grow 0.5 % a season, not 1 %. Set it back to Normal.
13. Play on to **Summer 1490** (`end 40` in the console): no error; when Genoa is full (Spring 1490) the task flag says
    "Genoa (8, 13) is full at 45,000 people: a city would give it room."; the People page's charts show 40 seasons and
    Savona's outlook reads "Room for ... more; walls would give room for 45,000."
14. F5, quit to desktop, Continue: the chips, J's People section and the People page are as before.
15. Map sandbox: the hover card shows people and nothing changes after a season; 5 says "no countries on this map"; `people
    6 13 1900` says the sandbox has no countries.

---

## 5. Definition of done

1. The spec's "M5 is done when" items 1 to 9 hold.
2. Tasks P1 to P18 merged; CI green, with both UI `--check`s, `build_map --check`, `build_scenario.gd --check`, and the
   nightly `perf_core` and `perf_ui` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac.
5. `godot-architecture.md` 9.2 marks M5 done; `godot/README.md` describes the M5 game.
6. Section 7 below is handed to the M6 build spec's author.

---

## 6. How to start

On the day M4.5 closes:

1. Opus presents the people (spec 4.1 to 4.6 and the worked examples of 4.11) to the owner and Fable in 30 minutes; a changed
   number is a data line now, not a task later. Fable signs `People.move`, `change_at`, the season row and the save fields
   (spec 5.2, 5.3) the same day.
2. Start group A together: **P2, P3** (Sonnet) and **P1, P15** (Haiku). Opus reads P1's numbers on its first day.
3. P4 starts when group A merges; its worker reads spec 4.2 to 4.5 and the worked examples during group A.
4. P5 times the people phase on the made-up Europe in its first days (spec 10), before the views build on it.
5. P17's economy report goes to Opus the day it runs; group E waits for the food-balance verdict.

---

## 7. What M5 hands on

- **M6:** the levy seam (`People.available`, `levy_check`, `levy`, `give_back`) and the flows `raised` and `returned`;
  people for supply; foraging as a flow appended to `People.FLOWS`; the army's food as a need beside the towns' (`fed_of`
  stays the towns' share); Supply on key 6.
- **M7:** `district_declined` with `why` `sacked`; captured land keeps its people; refugees as a flow if wanted.
- **M8:** `PeopleView`, `StudyPeople`, `MapModes.food_bytes` and the `hunger` and `town_full` reminders as the AI's views; the
  soak checks the conservation property and the `Stats` budget.
- **M10:** buying food from markets; the food need in market demand; grain and fish prices by supply.
- **M11:** techs change the growth, hunger, room and jobs numbers through definitions only.
- **M12:** score with people; plague and famine pop-ups; countries that fall with their people.
- **Saves:** `SaveFile.FORMAT` 3; a new body field with a default needs no bump (M3 4.10).
