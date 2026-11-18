# M4.5 build plan: Insights I

Game and UI designer (Opus), 2026-11-17. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/m4-5-build-spec.md` ("the spec").

**Starts after M4 is closed** (its plan's definition of done, the owner's playtest). M4.5 edits views and screens that M2,
M3 and M4 deliver: `EconomyPreview`, `StudyEconomy`, `LogLines`, `MapModes`, `HexCard`, `Stats` (two read-only methods),
`InkChart`, the study frame and its Economy page, the mode overlay, the map scene, the top bar, the action log, the HUD,
the App. **It adds no game rule** (spec D1): no task touches `core/defs/`, `core/systems/`, `core/game/` or `data/`, and the
technical director checks it on every pull request.

**The tasks of `ui-style-and-feedback-plan.md` S4 are folded in with their IDs; the tasks it lacked are Q1 to Q5:**

| S4 task | Here | What changed |
|---|---|---|
| I1 `InkChart` complete | I1, group A | adds `InkMarks` (M4's line drawing moved there, shared with the table), the legend and the fill cues |
| I2 `StudyTable` | I2, group B | **grown to M:** the column kinds `delta`, `bar`, `spark`, `button`, 100 rows at a time, sorting by keyboard; after I1 (it draws with `InkMarks`) |
| I3 Study views | **split:** I3a (Economy's views, L, group A), I3b (Rankings and History, M, group B) | adds `EconomyPreview.worth_seasons`, the `Stats` accessors, `LogLines.filters_of` and the test fixture `InsightsFixture` (I3a; I3b's tests need it) |
| I4 Yields map mode | **split:** I4a (the read model and the hover card's Worth line, S, group B), I4b (the map, M, group C) | the legend is Q4 |
| I5 Economy tabs | I5, group C | **grown to L:** three tab scenes |
| I6 Rankings page | I6, group C | **grown to M:** a line chart under each list |
| I7 History page | I7, group C | the action log's edit (older headers) moved to Q3 |
| I8 Monkey, pictures, perf | I8, group E | adds the five-questions test and the read-only proof |
| (none) | **Q1** `TimelineStrip`; **Q2** the study frame's tabs and the mockup renders; **Q3** the App; **Q4** the Yields legend; **Q5** the perf games, the core rows, the core proof | pieces the spec names that S4 had no task for |

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Kit** | `InkChart` complete, `InkMarks`, `StudyTable`, `TimelineStrip` | I1, I2, Q1 | 3 M |
| **Read models** | Districts, Goods, History, Rankings, the History page's views; Yields' bytes; the Worth line | I3a, I3b, I4a | 1 L, 1 M, 1 S |
| **Pages and map** | the study frame's tabs, Economy's three tabs, Rankings, History, Yields on the map, its legend | Q2, I5, I6, I7, I4b, Q4 | 1 L, 3 M, 2 S |
| **Wiring and proof** | the App, the warmer, the log's headers; perf games and rows; monkey, pictures, the five questions, the read-only proof | Q3, Q5, I8 | 3 M |

15 tasks: 2 L, 10 M, 3 S, about 16.5 worker-days; about 8 working days end to end with the groups below (each group takes
as long as its longest task), plus reviews and the owner's playtest.

```
M4 closed (the owner's playtest)
  -> A:  I3a (L)  I1  Q1  Q2
  -> B:  I3b  I2  I4a
  -> C:  I5 (L)  I6  I7  I4b  Q4
  -> D:  Q3  Q5
  -> E:  I8  -> the owner plays M4.5

Critical path: I3a -> I4a -> I4b -> Q3 -> I8     (and I1 -> I2 -> I5 -> Q3 -> I8; I3a -> I3b -> I7 -> Q3)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel and no two
touch one file.

---

## 2. Tasks

Who, per the standard's section 9 ("Opus (what to show) / Sonnet (views), Haiku (pages)"): *Sonnet* builds the views, the
tools, the map overlay and anything touching the App or input; *Haiku* builds kit pieces, pages and the HUD card from the
spec's tables, and tests from a list; *Opus* reviews what each page shows and its words; *Fable* reviews interfaces.
**Every task's done-when includes: lint (`python tools/lint_godot.py godot`), check_scripts and GUT green**, both UI
`--check`s (`bake_ui.py --check`, `build_theme.gd --check`, which M4.5 does not change) and `build_scenario.gd --check`
(M2). Paths without a prefix are under `godot/`; `docs/` is at the repository root.

### Group A (parallel)

| # | Size, who | Task | Files (new unless said) | Done when |
|---|---|---|---|---|
| I3a | L, Sonnet | **Economy's views and the fixture** | edit `core/views/economy_preview.gd` (`worth_seasons`; the per-hex step shared with `worth_by_hex`), `core/views/study_economy.gd` (`SPANS`, the `LASTS_*` constants, `districts`, `goods`, `lasts`, `history`, `piece_words`), `core/state/stats.gd` (`MADE`, `USED`, `STOCK`, `goods_value`, `goods_series`); `tests/core/insights_fixture.gd`; edit `tests/core/test_economy_preview.gd`, `test_study_economy.gd`, `test_stats.gd` | Spec 4.2 to 4.5, 4.10 (districts at turn 1, history after the first year, goods at turns 1 and 5) to the unit; D3 to D8; `InsightsFixture`'s three games; every M4 test green and unchanged; `worth_seasons` timed on `perf_core`'s M4 game (the made-up Europe) on the task's first day, the number in the pull request, spec 10's fallback applied when over 12 ms |
| I1 | M, Sonnet | **`InkChart` complete, `InkMarks`** | edit `shell/ui/ink_chart.gd`, `tests/shell/test_ink_chart.gd`; `shell/ui/ink_marks.gd`, `tests/shell/test_ink_marks.gd` | Spec 6.2 (`InkChart`, `InkMarks`): `LINE`, `STACKED_BAR`, `SPARK` with 0, 1 and 40 points; legend; marks on every kind; the cursor, its keys and signals; the hover card; `summary()` as the accessibility description; M4's chart cases and the M4 goldens of the card and This season unchanged; the art director signs a sheet of the three new kinds and the five fills |
| Q1 | M, Haiku | **`TimelineStrip`** | `shell/ui/timeline_strip.gd`, `tests/shell/test_timeline_strip.gd` | Spec 6.2 (`TimelineStrip`) and 4.7's geometry, from plain dictionaries (no game); labels at 12, 40 and 680 seasons; marks merged when narrow; keys, signals, hover card, `summary()`; the art director signs it beside the mockup's ticks |
| Q2 | S, Haiku | **The study frame's tabs; the mockup renders** | edit `shell/screens/study.gd`, `shell/screens/study_page.gd`, `tests/fixtures/study_page_sample.tscn` (two tabs), `tests/shell/test_study.gd`; `tests/fixtures/mockup/study_districts.png`, `study_goods.png`, `study_history_tab.png`, `study_rankings.png`, `study_history.png`; edit `tests/fixtures/mockup/README.md` (M1.5's K4: one command line a stage) | Spec 6.3 without `LIST` (Q3 adds it): `open_page` with focus, `last_open_ms`, `milestone`, `shown_tabs`, `select_tab`, `step_tab`, `current_tab`, `tab_changed`, `focus`; Ctrl+`[ ]`; the hint; the `country` and `map_mode` actions forwarded; the five renders made with K4's command at the mockup's "M4.5" |

### Group B (after A)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| I3b | M, Sonnet | **Rankings and History's views** | `core/views/study_rankings.gd`, `core/views/study_history.gd`; edit `core/views/log_lines.gd` (`filters_of`, which `line_of` calls); `tests/core/test_study_rankings.gd`, `tests/core/test_study_history.gd`; edit `tests/core/test_log_lines.gd` | Spec 4.6, 4.7, 4.9, 4.10 (Rankings at turn 2), 5.6; **Rankings equals the report's Standing every season of `InsightsFixture.forty_seasons()`**; every planted fault of spec 9 for these files; `StudyHistory.index` timed on `perf_core`'s M4 game with its entry count, in the pull request |
| I2 | M, Haiku | **`StudyTable`** | `shell/ui/study_table.gd`, `tests/shell/test_study_table.gd` | Spec 6.2 (`StudyTable`): the six column kinds, stable sorting with ties by id, the arrows, 100 rows and "show more", Enter, double click and Go, Ctrl+arrows, selection kept by id, the mine row; 100 rows with two custom columns built under 4 ms in a probe run (the number in the pull request); Ctrl+arrows checked on the owner's Mac (spec 10) |
| I4a | S, Sonnet | **Yields' read model; the Worth line** | edit `core/views/map_modes.gd` (`Mode.YIELDS`, `MODE_KEYS`, the Yields constants, `mode_of`, `yield_band`, `yield_bytes`, `yield_ramp`, `legend`, `colour_of`'s `yield_byte`, `modes`, `colour_at`), `core/views/hex_card.gd` (Worth); edit `tests/core/test_map_modes.gd`, `tests/core/test_hex_card.gd` | Spec 4.8, 5.6 (`MapModes`, `HexCard`): the bands' edges, the colour distances (6, 15, 15), 4.8's bytes for Genoa, Genoa's Worth line; planted faults: a Milan hex is 0 and has no Worth line |

### Group C (after B)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| I5 | L, Haiku | **Economy's three tabs** | edit `shell/screens/study/page_economy.tscn`, `shell/screens/study/page_economy.gd` (`TABS`, `focus`); `shell/screens/study/economy_districts_tab.tscn`, `economy_districts_tab.gd`, `economy_goods_tab.tscn`, `economy_goods_tab.gd`, `economy_history_tab.tscn`, `economy_history_tab.gd`; edit `tests/shell/test_page_economy.gd` | Spec 4.3 to 4.5 and 6.4 against `study_districts.png`, `study_goods.png` and `study_history_tab.png`, with 4.10's numbers; Look there and Show on the map send their actions; the History ledger adds up; the span writes `state/study_span`; each tab's refresh leaves `Game.digest()` |
| I6 | M, Haiku | **Rankings** | `shell/screens/study/page_rankings.tscn`, `shell/screens/study/page_rankings.gd`, `tests/shell/test_page_rankings.gd` | Spec 4.6 and 6.5 against `study_rankings.png` with 4.10's turn-2 lists; your row; "about"; the unknown line; a row sends `[&"country", tag]`; the charts and their rank marks; fits 1280 x 720; the refresh leaves the digest |
| I7 | M, Haiku | **History** | `shell/screens/study/page_history.tscn`, `shell/screens/study/page_history.gd`, `tests/shell/test_page_history.gd` | Spec 4.7 and 6.6 against `study_history.png` on `genoa_1483`: the timeline, the season line, the filters by milestone, Older and Newest, `focus({turn})`, rows move the cursor, Go looks there; the refresh leaves the digest |
| I4b | M, Sonnet | **Yields on the map** | edit `shell/map/mode_overlay.gd`, `shell/map/mode_overlay.gdshader`, `shell/map/map_scene.gd`, `shell/input/map_input.gd`, `shell/hud/top_bar.gd`, `shell/app/settings.gd` (`state/map_mode` choice `yields`), `godot/tools/map/probe_mode_overlay.gd`; edit `tests/shell/test_mode_overlay.gd`, `test_map_scene.gd`, `test_map_input.gd`, `test_settings.gd`, `test_hud.gd` (the top bar's fourth segment) | Spec 6.7 without the legend: key 4, the switch, the two textures, `update_yields` writing only changed texels (one changed byte, one texel), updates only while in Yields, the restored mode, a mode not in `MapModes.modes(game)` ignored; the probe prints PASS on the runner and on the owner's Mac (and FAIL with `--plant`); the art director signs Yields on north Italy |
| Q4 | S, Haiku | **The Yields legend** | `shell/hud/mode_legend.tscn`, `shell/hud/mode_legend.gd`, `tests/shell/test_mode_legend.gd` | Spec 6.7 (`ModeLegend`): rows from `MapModes.legend(mode)` with `InkMarks` swatches (stripes for a loss); hidden for other modes, under a screen and in photo mode |

### Group D (after C)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Q3 | M, Sonnet | **Wire the App** | edit `shell/app/game_requests.gd` (spec 6.9's table), `shell/app/app.gd` (the milestone `"4.5"`, the `StudyWarm` child, `ModeLegend.show_mode` after each `MapScene.set_mode`; under 800 lines), `shell/screens/study_pages.gd` (`LIST`), `shell/hud/action_log.gd` (older headers), `shell/hud/hud.tscn`, `shell/hud/hud.gd` (the legend's slot), `shell/hud/debug_overlay.gd` (the F3 line), `godot/README.md` (keys 4 and Ctrl+`[ ]`, the pages); `shell/app/study_warm.gd`, `tests/shell/test_study_warm.gd`; edit `tests/shell/test_app_flow.gd`, `test_action_log.gd`, `test_hud.gd`, `test_debug_overlay.gd`, `test_study.gd` (the three pages from `LIST`) | Spec 6.3 (`LIST`), 6.8, 6.9: I, L, `[ ]`, the two chips, a log header and Show on the map land where the spec says; the warmer's queue; key 4 toasts in the sandbox and while picking; the sandbox has no Yields and no study; the flow test of spec 9 end to end |
| Q5 | M, Sonnet | **Perf games, core rows, the core proof** | `godot/tools/perf_fixture.gd`; edit `godot/tools/perf_core.gd`, `godot/tests/perf_core_budget.json`; `tests/core/test_insights_views.gd` | Spec 8's core rows printed in the job summary and within their limits on the made-up Europe; M3's and M4's rows unchanged; `test_insights_views.gd`: every view leaves the snapshot and `version`, equals itself after a save and load, the pins of spec 4.13, the scan for writers with its planted fault |

### Group E (after D)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| I8 | M, Haiku | **Monkey, pictures, UI perf, the five questions, the read-only proof** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`; `tests/shell/test_five_questions.gd`, `tests/shell/test_study_readonly.gd`, `tests/fixtures/study_page_bad.tscn`, `tests/fixtures/study_page_bad.gd`; the signed pictures as goldens (`godot/tests/goldens/m4_5_*.png`) | **Done-when 1 (each answer within four inputs), 2 (every UI row of spec 8 within its limit on the runner) and 4 (the shell proof, with its planted fault)**; the monkey's new keys and invariants green on 3 seeds; spec 9's pictures at 1280 x 720 scale 1 and 2560 x 1440 scale 2, signed |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** reads the interfaces of I3a, I3b and I4a (spec 5.6) before they merge, and Q3 and Q5;
  checks on every pull request that nothing under `core/defs/`, `core/systems/`, `core/game/` or `data/` changed and that
  `core/state/` changed only by I3a's two accessors (spec 4.13).
- **Opus** reviews what each page shows: the dictionaries' texts of I3a and I3b against spec 4.3 to 4.7, the pages of I5,
  I6 and I7 against the mockup renders, and runs the five questions of spec 4.11 on the first build of group D, before the
  owner's playtest. A change of a column or a word is an edit of the spec and the test in the same pull request.
- **The art director** signs I1 (the new kinds and fills), Q1 (the timeline), I4b (Yields on north Italy: the ramp, the
  veil, the stripes) and I8's pictures.
- **Pull requests** say what changes for the player. None changes a rule: `Game.digest()` of every fixture stays as it
  was, and from I8 on `test_study_readonly.gd` runs in every pull request.

---

## 4. The owner's playtest of M4.5

On Windows (mouse) and on the MacBook (trackpad), with a fresh user folder.

**Setup (spec 4.11, about four minutes).** New game, More, seed **1480**, Italy 1480, Play as Genoa. Select (10, 13), the
woods by the sea east of Genoa: **Build timber**. Space, Space seven times, to **Winter 1481**. Select Genoa, **U**, Enter
(the city: "−1,000 ducats"). Space, Space five times, to **Spring 1483**.

**The five questions.** Each from the map with nothing open; start a stopwatch, stop it when you say the answer. Write the
five times down; each must be under a minute.

1. **Which of your districts earns the most?** L, then Ctrl+] (Districts): the first row is Genoa (8, 13), walled town,
   port, under way to city. Press **Show on the map**: the study closes in Yields, Genoa the darkest.
2. **Why did the treasury fall in Winter 1481?** L, click History, click Winter 1481's column (its mark reads "walled town
   to city"): "Your spending ▼ −1,000", and under it "Begun: walled town to city, Genoa (8, 13)".
3. **Which good runs short?** L, click Goods: the first row, Salt, 0 in store, "none left"; the note says none of your land
   makes it.
4. **Where do you rank on land and income?** L, then ]: "You are 3rd of 3." under Land, and under Income unless a good
   winter lifted Genoa to 2nd; Savoy and Milan banded ("about 58" and "about 52" for land); "10 countries unknown".
5. **What happened in Spring 1481?** Click the action log's bar, click its header "Spring 1481": the History page there,
   "Your towns ran short of salt: 0 of 1."

**Then:**

6. Press **4**: your land in greens, darker where it earns more; others' land under a dark veil; the legend top left;
   hover Genoa: a Worth line, a year and this season (the year above +200); hover Milan's land: no Worth line; the
   minimap shows the same. Press 1: Terrain, the legend gone.
7. Districts: click "A year": the order flips, the arrow turns; Ctrl+Left and Ctrl+Right move the sort; Enter on Savona
   glides there.
8. Economy's History: Left and Right move the cursor; the ledger under the chart adds up to the season's change; switch to
   40 seasons; the year chart shows 1480, 1481, 1482.
9. History: Left and Right on the timeline, Shift+Right a year, Enter; filter Money (the city's line with "(−1,000
   ducats)"), Mine; Older, Newest.
10. Rankings: Milan's row, Enter: Milan's panel, its treasury rounded to two figures ("Treasury about" and the number).
11. F2: `digest`. Open every page and tab, sort tables, hover chart points, switch Yields on and off. `digest` again: the
    same text.
12. F3: the study line shows the last page built in a few milliseconds; no page or tab opens with a visible pause.
13. F5, quit to desktop, Continue: the study shows the same numbers; the map is in Yields if you left it there.
14. Make the window 1280 x 720: Rankings shows both lists and both charts; nothing is cut.
15. Map sandbox: 4 says "no countries on this map"; older log headers are plain; I says "The sandbox has no treasury."
16. Back in the game, play on to **Spring 1490** (`end 28` in the console): the History tab at 40 seasons is full; the year
    chart shows 1480 to 1489; the timeline's labels thin out; no error.

---

## 5. Definition of done

1. The spec's "M4.5 is done when" items 1 to 7 hold.
2. Tasks I1 to I8 (I3a, I3b, I4a, I4b) and Q1 to Q5 merged; CI green, with both UI `--check`s, `build_scenario.gd
   --check`, and the nightly `perf_core` and `perf_ui` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac, with the five times written in the milestone's
   notes, each under a minute.
5. `godot-architecture.md` 9.2 marks M4.5 done; `godot/README.md` describes the M4.5 game.
6. Section 7 below is handed to the M5 build spec's author.

---

## 6. How to start

On the day M4 closes:

1. Opus walks the owner and Fable through spec 4.1 to 4.11 (the pages, Yields and the five questions) in 20 minutes; a
   change of a column or a question is a line in the spec now, not a task later.
2. Start group A together: **I3a** and **I1** (Sonnet), **Q1** and **Q2** (Haiku). Fable reads I3a's dictionaries (spec 5.6)
   on its first day; I3a times `worth_seasons` on the made-up Europe the same day (spec 10).
3. Q2's mockup renders go to the art director and Opus on its first day: they are the references for group C.
4. I2 starts the day I1 merges (group B); its Ctrl+arrows go to the owner's Mac in its first week.

---

## 7. What M4.5 hands on

- **M5:** a people measure in `StudyRankings.MEASURES`; the People page from `StudyTable` and `InkChart`; its map mode on
  key 5 with a `MapModes.legend`; worth, Districts and Yields follow `Economy.people_at` with no view change.
- **M6:** an army measure (banded); Supply on key 6; witnesses from vision; `knows` by explored hexes; "Upkeep, walls and
  army" on the money chart (spec D35).
- **M7:** the War filter and a `war` mark kind first in `StudyHistory.MARK_KINDS`.
- **M8:** the AI fills the chronicle: the 120-row pages, the witnessed index and `StudyWarm` carry it.
- **M9, M10, M11:** Relations (key 7), Trade (key 8, "Dues and trade"), the eras' marks; their pages on the kit.
- **M12:** score in Rankings; the Debt tab (`PageEconomy.TABS`); text size and high contrast in charts.
- **Saves:** unchanged (`SaveFile.FORMAT` 2); the `ui` block may hold `map_mode = "yields"`.
