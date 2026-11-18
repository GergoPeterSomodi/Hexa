# M4 build plan: Economy

Game and systems designer (Opus), 2026-11-17. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/m4-build-spec.md` ("the spec").

**Starts after M3 is closed** (its plan's definition of done, the owner's playtest). M4 edits what M1.5, M2 and M3 deliver:
`Game`, `Session`, `Events`, the action and season tables, `Works`, `Work`, `Calendar`, `StatsSystem`, `Country`, the report's
view, the reminders, the log lines, the hex panel, the country panel, the top bar, the HUD and the App. The standard's rule
holds: the next milestone starts after the owner has played the last one.

**The tasks of `ui-style-and-feedback-plan.md` S3 are folded in with their IDs; the system tasks are N1 to N12:**

| S3 task | Here | What changed |
|---|---|---|
| W0 (the district economy carries spec 7.3) | **done** by the spec | its done-when holds: the six requirements are answered in spec 4.23 (no "no" on 1 or 2); `district_output`, `market_prices` and `Treasury.move` are written out in spec 5.3 for Fable to sign |
| W1 `StateView` | W1, group A | unchanged |
| W2 `Treasury` and the ledger | W2, group B | **grown:** also `Stores` (the goods door) and every M4 field of `Country`; the `stats_system.gd` edit moved to N4 (the season) |
| W3 bake slice 4 | W3, group A | the 48 icons named (spec 6.2) |
| W4 `InkChart`, two kinds | W4, group A | unchanged |
| W5 `ImprovePreview`, `EconomyPreview`, the cache | W5, group D | `view_cache.gd` exists since M3 (no edit); adds `WorksView.ready_turn_of` |
| W6 the report's money sections | W6, group E | adds the M4 reminders' rules and rebuilds M3's `report_sample.gd` |
| W7 `StudyEconomy.this_season` | W7, group E | adds `EconomyCards` (the chips' hover cards) |
| W8 the card | **split:** W8a (kit pieces, group C), W8b (the screen, group E) | the kit pieces need no core; the screen needs W5 |
| W9 hex panel rows, confirm, cancel | W9, group E | the `settings.gd` and `bindings.gd` edits are gone: the rows exist since M1.5 |
| W10 map marks | W10, group E | the tint is drawn by `PreviewMarks`, not the mode overlay; `map_modes.gd` gains only `delta_colour` (N2) |
| W11 the study and "This season" | **split:** W11a (the frame, group C), W11b (the Economy page, group F) | `resource_chip.tscn` moved to N8 |
| W12 monkey, pictures, perf | W12, group H | covers every M4 screen |

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Definitions** | goods, the families' numbers, the economy's numbers, the rules' words | N1, N2 | 1 M, 1 S |
| **Money and goods core** | `StateView`, the two doors, the rules of a hex and a country, the cache | W1, W2, N3 | 2 L, 1 S |
| **The season** | the phases, `set_tax`, works' costs and refunds, weather, stats, saves, events, the log | N4, N5, N6 | 1 L, 2 M |
| **Read models** | the previews, the study's view, the chips' cards, the report's sections, reminders, the hex and country cards | W5, W6, W7, N7 | 1 L, 1 M, 2 S |
| **Kit** | icons, `InkChart`, `SeasonStrip`, `PreviewCard`, `ResourceChip`, the study frame | W3, W4, W8a, N8, W11a | 1 L, 3 M, 1 S |
| **Screens and HUD** | the card, map marks, hex panel rows, the Economy page, the chips, the country panel | W8b, W10, W9, W11b, N9, N11 | 4 M, 2 S |
| **Wiring and proof** | properties, the report tool, perf; the App; monkey, pictures, the UI probe | N10, N12, W12 | 1 L, 2 M |

26 tasks: 6 L, 13 M, 7 S, about 31 worker-days; about 16 working days end to end with the groups below (each group
takes as long as its longest task), plus reviews and the owner's playtest.

```
M3 closed (the owner's playtest)
  -> A:  W3 (L)  N1  W4  N2  W1
  -> B:  W2 (L)  N3 (L)
  -> C:  N4 (L)  W8a  W11a  N8
  -> D:  W5 (L)  N5  N6  N7
  -> E:  W6  W7  W8b  W9  W10  N10  N11
  -> F:  W11b  N9
  -> G:  N12 (L)
  -> H:  W12  -> the owner plays M4

Critical path: N1 -> N3 -> N4 -> W5 -> W7 -> W11b -> N12 -> W12     (and W3 -> W8a -> W8b -> N12)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel and no two
touch one file.

---

## 2. Tasks

Who, per the standard's section 9 ("Opus (district economy, seasonal output) / Sonnet (system), Haiku (chips, works card,
study page, data)"): *Sonnet* builds systems, tools and anything touching `Game`, saves, the season table, `Session`,
`Events`, input or the App; *Haiku* builds the kit pieces, panels and screens from the spec's tables, data files, and
tests from a list; *Opus* reviews the numbers and the words; *Fable* reviews interfaces. Generated files belong to the
task that changes their source. **Every task's done-when includes: lint (`python tools/lint_godot.py godot`),
check_scripts and GUT green**, both UI `--check`s (`bake_ui.py --check`, `build_theme.gd --check`) and
`build_scenario.gd --check` (M2). Paths without a prefix are under `godot/`; `tools/`, `tests/test_*.py`, `docs/` and
`CLAUDE.md` are at the repository root.

### Group A (parallel)

| # | Size, who | Task | Files (new unless said) | Done when |
|---|---|---|---|---|
| N1 | M, Haiku (Opus reviews) | **Definitions and the data** | `core/defs/good_def.gd`; edit `core/defs/family_def.gd`, `core/defs/game_defs.gd`; `data/defs/goods/{grain,fish,oil,wine,salt,hemp,silk,dyes,wool,cattle,horses,timber,stone,iron,copper,silver}.tres`; edit `data/defs/families/*.tres` (14), `data/defs/game_defs.tres`, `data/README.md`; `godot/tools/economy_tables.gd`; `tests/core/test_good_defs.gd`, `tests/core/test_economy_defs.gd`; edit `tests/core/test_family_defs.gd` | Spec 4.2, 4.4, 4.6 to 4.12's numbers and 5.1 entered exactly; every planted fault of spec 9 for these three tests; `economy_tables.gd` prints the tables |
| N2 | S, Sonnet | **The rules' words, the ghost's helpers, money words** | edit `core/systems/improve.gd` (`piece_for`), `core/systems/world_improve.gd` (`conflict`; `_pair_conflict` builds its string from it), `core/systems/improve_rules.gd` (`PAIR_WORDS`, `PAIR_NEEDS`), `core/views/map_cells.gd` (`piece_cells`), `core/views/map_modes.gd` (`delta_colour`), `core/views/words.gd` (`ducats`, `loads(n, name)`, `signed_ducats`, `tax_name`); edit `tests/core/test_world_improve.gd`, `test_map_cells.gd`, `test_map_modes.gd`, `test_words.gd` | Spec 5.3 and 5.6 for these; `conflict` names the rule and hex for every pair rule; every M1 refusal string unchanged (the existing tests stay green); `piece_cells` equals `of_hex`'s piece layers for every piece of north Italy |
| W1 | S, Sonnet | **`StateView`** | `core/state/state_view.gd`, `tests/core/test_state_view.gd` | Spec 5.2; reads fall through; an overlay never changes its base |
| W3 | L, Sonnet | **Bake slice 4: the icons and the feedback frames** | `tools/ui_bake/icons.py`, `tools/ui_bake/pieces_feedback.py`; edit `tools/bake_ui.py`, `godot/tools/build_theme.gd` (the `Kit` icons, `PanelVellumInset`, `PanelStripCell`, `PanelStripCellNow`, `InkChart`); re-made `assets/ui/kit/` and `shell/ui/theme.tres`; edit `tests/test_bake_ui.py`, `tests/shell/test_theme.gd` | Spec 6.2's 48 icons and three frames at 1x and 2x; the asserts of style spec 4.4; the art director signs the icon sheet (the 16 goods first, on day 2) |
| W4 | M, Sonnet | **`InkChart`, first two kinds** | `shell/ui/ink_chart.gd`, `tests/shell/test_ink_chart.gd` | `LINE_BARS` and `PAIRED_BARS` with 0, 1 and 40 points; each series an ink and a dash or hollow; marks (`set_marks`) on `LINE_BARS` (spec 6.7's chart); redraws only on new data; "No data yet" |

### Group B (after A)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| W2 | L, Sonnet | **`Treasury`, `Stores` and the country's purse** | `core/systems/treasury.gd`, `core/systems/stores.gd`; edit `core/state/country.gd` (`country/2`: every M4 field, `to_dict`, `from_dict`, `digest_text`); `tests/core/test_treasury.gd`, `test_stores.gd`, `test_no_other_writers.gd`; edit `tests/core/test_country_state.gd` | Spec 4.8, 4.9 (the doors), 4.12 (`setup`), 5.2 (Country), 5.3 (Treasury, Stores); the unit cases and planted faults of spec 9; `country/1` refused |
| N3 | L, Sonnet | **The rules of a hex and of a country; the cache** | `core/systems/economy.gd`, `core/systems/economy_season.gd` (the pure functions: `town_people` to `money_lines`, `debt_limit`; `OWNS`; the phases and the tax pair as empty stubs), `core/systems/district_cache.gd`; `tests/core/test_economy.gd`, `test_economy_season.gd` (pure cases), `test_district_cache.gd` (`touch` called directly) | Spec 4.3 to 4.9, 5.3 (Economy, EconomySeason's pure part), 5.4 (DistrictCache); every family, level and slot of 4.4 equals the table; `district_output == season_output(district_base)` on every land hex of north Italy; no engine calls (lint) |

### Group C (after B)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| N4 | L, Sonnet | **The season, the actions, works' costs, weather, stats** | fill `production`, `income`, `set_tax_check`, `set_tax` in `core/systems/economy_season.gd`; edit `core/game/season.gd` (`PHASES`), `core/game/actions.gd` (`set_tax`), `core/game/game.gd` (`weather`, `districts`, `emit` touches, `dev_money`, `dev_goods`, `new_scenario` setups, the digest), `core/systems/works.gd` (`cost_of`, rows 8 and 9, pay, `refund_goods`, the refund), `core/state/work.gd` (`work/2`), `core/systems/calendar.gd` (weather), `core/systems/stats_system.gd` (spec 4.20, the two closes), `core/game/replay.gd` (dev records); `tests/core/economy_fixture.gd`, `tests/core/test_economy_genoa.gd`; edit `tests/core/test_economy_season.gd` (the phases, `set_tax`, `goods_short`), `test_district_cache.gd` (the 2,000-action case), `test_season.gd`, `test_works.gd`, `test_calendar.gd`, `test_stats.gd`, `test_game_core.gd`, `test_replay.gd`, `test_improve_actions.gd`, `test_owns.gd`, `test_forty_seasons.gd`, and every M1 to M3 test that begins a work in a scenario game (money through `Game.dev_money`) | Spec 4.6, 4.10, 4.11, 4.13, 4.20, 5.3 (Works, Calendar, StatsSystem), 5.4; **`PHASES` pinned as `[production, income, works, stats, calendar]`**; 4.15 (a)'s first year to the ducat (`test_economy_genoa.gd`); the treasury and stores properties over 40 seasons in `test_forty_seasons.gd`; `production` and `income` timed on the fake Europe by a probe run, the numbers in the pull request (spec 10) |
| W8a | M, Haiku | **`SeasonStrip` and `PreviewCard`** | `shell/ui/season_strip.tscn`, `shell/ui/season_strip.gd`, `shell/ui/preview_card.tscn`, `shell/ui/preview_card.gd`, `tests/fixtures/preview_sample.gd` (spec 4.15 c, d, e as dictionaries), `tests/shell/test_preview_card.gd`; edit `tests/shell/test_kit_feedback.gd` (the strip) | Style spec 5 for both; spec 6.5's parts drawn from the fixture against `works_vineyard.jpg` and `works_genoa.jpg`; the refusal forms; compare with one chart scale |
| W11a | M, Haiku | **The study's frame** | `shell/screens/study.tscn`, `shell/screens/study.gd`, `shell/screens/study_page.gd`, `shell/screens/study_pages.gd` (`LIST` empty: W11b adds Economy), `tests/fixtures/study_page_sample.tscn` (a test page), `tests/shell/test_study.gd` | Spec 6.7's frame: ribbon, date, Close with I, `NavList`, page host, hints, `open_page`, kept page and scroll, Esc and I close, the `[ ]` hint hidden with one page; `action_requested` forwarded as `look_at` |
| N8 | S, Haiku | **`ResourceChip`** | `shell/ui/resource_chip.tscn`, `shell/ui/resource_chip.gd`, `tests/shell/test_resource_chip.gd` | Spec 6.3's chip: medal with an icon, name, value, `DeltaChip`, the hover card, its accessibility name; on leather at 1x and 2x |

### Group D (after C)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| W5 | L, Sonnet | **`ImprovePreview`, `EconomyPreview`** | `core/views/improve_preview.gd`, `core/views/economy_preview.gd`; edit `core/views/works_view.gd` (`ready_turn_of`); `tests/core/test_improve_preview.gd`, `test_economy_preview.gd`; edit `tests/core/test_works_view.gd` | Spec 4.17, 5.6; **the 200-case property** (done-when 4); 4.15 (c), (d), (e) exactly; reason words for the 13 pair rules; `with(..., 8)` equals eight played seasons for every country; `options_of` timed on the fake Europe by a probe run (under 2 ms; the number in the pull request) |
| N5 | M, Sonnet | **Saves** | edit `core/game/snapshot.gd`, `core/game/save_file.gd` (`FORMAT` 2, `OLDEST_FORMAT` 2); edit `tests/core/test_snapshot.gd`, `test_save_file.gd` | Spec 4.22; save, load, save byte-equal with every M4 field; the planted faults (format 1 older, `country/1`, a mistyped `treasury`) |
| N6 | M, Sonnet | **Events, `Session`, the log** | edit `shell/autoload/events.gd`, `shell/autoload/session.gd` (`dev_money`, `dev_goods`, the drain), `core/state/chronicle.gd` (`NOTABLE`), `core/views/log_lines.gd`; edit `tests/shell/test_session.gd`, `tests/core/test_chronicle.gd`, `test_log_lines.gd` | Spec 4.21, 5.5; the two signals drained after each phase; the Money filter; `goods_short` never witnessed by others; still two autoloads |
| N7 | S, Haiku | **The hover card and the country card** | edit `core/views/hex_card.gd` (Gives, Weather), `core/views/country_card.gd` (the treasury fields); edit `tests/core/test_hex_card.gd`, `test_country_card.gd` | Spec 6.10's view fields; banded through `Knowledge` (P: an unknown country shows none) |

### Group E (after D)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| W6 | M, Sonnet (Opus reviews the words) | **The report's money sections and the reminders** | edit `core/views/season_summary.gd`, `core/views/reminders.gd`, `tests/fixtures/report_sample.gd` (rebuilt from 4.15 b); edit `tests/core/test_season_summary.gd`, `test_reminders.gd` | Spec 4.18, 4.19; **every ducat sums** (done-when 3) over a 40-season run; 4.15 (b)'s sections exactly; equal after a save and load |
| W7 | S, Sonnet | **`StudyEconomy.this_season` and `EconomyCards`** | `core/views/study_economy.gd`, `core/views/cards_economy.gd`; `tests/core/test_study_economy.gd`, `test_cards_economy.gd` | Spec 5.6; equal to the closed ledger and `EconomyPreview` to the unit; the Ducats card's lines sum to the chip's change |
| W8b | M, Haiku | **The works card screen** | `shell/screens/works_preview.tscn`, `shell/screens/works_preview.gd`, `tests/shell/test_works_preview.gd` | Spec 6.5: `show_option` from `ImprovePreview`, pin, hold, Begin's request, Enter and U, Esc, the treasury switch |
| W9 | M, Haiku | **Hex panel rows, confirm, cancel** | edit `shell/panels/hex_panel.tscn`, `shell/panels/hex_panel.gd`, `tests/shell/test_hex_panel.gd` | Spec 6.4: rows with chips and cost text, the three `confirm_works` values (as `works_card` and `begin_work` requests), Gives and Worth, the refund in the Cancel toast's request |
| W10 | M, Sonnet | **Map marks** | `shell/map/preview_marks.gd`, `tests/shell/test_preview_marks.gd`; edit `shell/map/map_scene.tscn`, `shell/map/map_scene.gd` (the node, `show_preview`, `clear_marks`), `shell/mapview/tile_map_view.gd` (`tileset()`, the season's TileSet for the ghost) | Spec 6.6: ghost, tint, labels come and go; no `set_cell` on the real layers; off with the setting; the art director signs the marks on north Italy |
| N10 | M, Sonnet | **Properties, the economy report, perf** | `tests/core/test_money_property.gd`, `test_economy_1480.gd`, `godot/tools/economy_report.gd`; edit `godot/tools/perf_core.gd`, `godot/tests/perf_core_budget.json`, `CLAUDE.md` (one line: the report tool) | Done-when 2; spec 4.12's table; spec 8's rows printed and within their limits; the report for seeds 1480 to 1484 in the pull request for Opus and the owner |
| N11 | S, Haiku | **The country panel's treasury** | edit `shell/panels/country_panel.tscn`, `shell/panels/country_panel.gd`, `tests/shell/test_country_panel.gd` | Spec 6.10: yours, known (banded), unknown (none); "Open the study" requests the study |

### Group F (after E)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| W11b | M, Haiku | **Economy, This season** | `shell/screens/study/page_economy.tscn`, `shell/screens/study/page_economy.gd`, `tests/shell/test_page_economy.gd`; edit `shell/screens/study_pages.gd` (Economy in `LIST`) | Spec 6.7's page against `study_econ.jpg` with 4.15's numbers; the tax `Segmented` acts and its hover note; a row asks `look_at`; before the first season |
| N9 | S, Haiku | **The chips in the top bar** | `shell/hud/chips.tscn`, `shell/hud/chips.gd`, `tests/shell/test_resource_chips.gd` | Spec 6.3: Ducats and Stores from `EconomyCards`, refreshes, a click requests the study, hidden in the sandbox and the pick |

### Group G (after F)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| N12 | L, Sonnet | **Wire the App** | edit `shell/app/game_requests.gd` (spec 6.12), `shell/app/app.gd` (the milestone `"4"`, the connections; under 800 lines), `shell/hud/hud.tscn`, `shell/hud/hud.gd` (the `Chips` slot), `shell/hud/top_bar.tscn`, `shell/hud/top_bar.gd` (chips placement and narrowing, the study button), `shell/screens/screen_ids.gd` (`study`, `works_preview`), `shell/input/map_input.gd` (`study_requested`), `shell/screens/season_report.gd` ("Open the study"), `shell/hud/dev_commands.gd` (`money`, `goods`, `tax`), `shell/hud/debug_overlay.gd` (the F3 line), `shell/hud/task_flag.gd` (the `study` action), `godot/README.md`; edit `tests/shell/test_app_flow.gd`, `test_hud.gd`, `test_map_input.gd`, `test_season_report.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_task_flag.gd` | The flow test of spec 9 end to end; done-when 6 holds in the shell tests; the sandbox shows no chips and toasts on I |

### Group H (after G)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| W12 | M, Haiku | **Monkey, pictures, UI probe** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`; the signed pictures as goldens (`godot/tests/goldens/m4_*.png`) | The monkey's new keys and invariants green on 3 seeds; spec 9's pictures at 1280 x 720 scale 1 and 2560 x 1440 scale 2, signed; spec 8's UI rows within their limits |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** signs `district_output`, `market_prices` and `Treasury.move` (spec 5.3) before N3 starts,
  and reads the interfaces of W2, N3, N4, W5, N6 and N12 before they merge; the season table and `OWNS` of N4 with W2's
  doors together.
- **Opus** reviews N1's numbers against spec 4.2 to 4.12 on its first day, W6's words against 4.18 and 4.19, and N10's
  economy report (seeds 1480 to 1484) before the playtest; any change of a number is a data edit with its test, in N10's
  pull request.
- **The art director** signs W3 (the icon sheet), W8a (the card against the two mockups), N8 (the chip), W10 (marks),
  W11b (the page against `study_econ.jpg`) and W12's pictures.
- **Pull requests** say what changes for the player. N4 changes behaviour on purpose (works cost; the season order moves
  `works` after `income`; weather draws luck): said in its pull request, with M3's tests edited there. W2, N4 and N5 change
  `Game.digest()` (new fields): said; no test pins a digest value. N5 makes M3 saves unloadable ("Made by an older test
  build"): said.

---

## 4. The owner's playtest of M4

On Windows (mouse) and on the MacBook (trackpad), with a fresh user folder. New game, "More", seed **1480**, Italy 1480,
Play as Genoa.

1. The top bar shows **Ducats 610** and **Stores**. Hover Ducats: "No season has ended yet." and "Expected this season
   ▲ +86". Hover Stores: grain 16, oil 4, wine 4, salt 4, timber 40, stone 40, iron 20.
2. Select (7, 12), the vineyard above Savona: the panel's Gives reads "wine 24 in autumn · upkeep 2 a season" and a Worth
   row. Hover the card: "Gives" in the hover card too.
3. Select (10, 13), wild woods by the sea east of Genoa: rows for olives, grazing, timber, mines, quarry and a fishing
   harbour, each with its cost ("40 · 4 seasons", "60 · 10 timber · 4 seasons") and chips. Hover "Build timber": the card
   opens left of the panel: Brings, the four seasons with Spring gilt, the country chart, cost, payback; the map shows the
   ghost and "+16 timber" (18 a year from the camp, less the 2 the wild wood gave). Shift and move away: the card stays.
   Pin it, hover "Build harbour": two columns, one scale.
4. Select Genoa, press **U**: "Genoa: walled town to city", refused "Not enough ducats: 1,000 needed, 610 in the treasury.",
   but everything shown (people 30,000 → 60,000, upkeep 6 → 11, the timber at (9, 13) lifted). Esc.
5. Select Savona, U: only "Cuneo (5, 13) is a town beside Savona: two towns may not stand side by side."
6. Build timber at (10, 13): the toast "−40 ducats", Ducats 570, the Stores card unchanged (no goods for a first stage).
   Ctrl/Cmd+Z: "+40 ducats back", 610. Build it again.
7. **Space:** the report: Treasury 610 → 656 with Taxes on people +65, Taxes on goods +7, Port dues, Genoa +30, District
   upkeep −12, Walls of Genoa −4, Work begun −40; add them: +46. Goods: Wine, Olive oil, Salt down by one; Before Summer:
   "Salt runs out in 4 seasons; none of your land makes it." Press **Open the study**.
8. The study: Economy, This season: Money in +102, Money out −16, Left over +86, Your spending −40, Expected this season.
   Hover Tax **High**: the note shows its gain and "districts −10 %". Click High: the toast and Expected rises. Set it back
   to Normal before ending the season (a change and a change back cost nothing). A place in Earns most closes the study
   and glides there; I reopens the same page.
9. Play to the end of Autumn: the report's Taxes on goods jumps (wine and oil sold).
10. Play to Spring 1481: a notification "Your towns ran short of salt: 0 of 1."; the log's Money filter shows it; the task
    flag has the salt line.
11. When the treasury passes 1,000 (about Spring 1481) begin Genoa's city: "−1,000 ducats"; the Stores card shows timber
    and stone down by 20 and 40. A walled town's work is "expensive": with Confirm works on Expensive only the row opened
    the card first.
12. Options, Game: Confirm works Always (a row click opens the card), Off (a click begins), back to Expensive only. Preview
    on the map off: no ghost.
13. Play until a "poor" season: the report's glance names it and the grain made falls; the hover card says "poor this
    season".
14. Press **C**: your treasury section; Milan's panel: "Treasury about …" (two figures, banded); France's: no treasury
    (you do not know France).
15. F5, quit to desktop, Continue: Ducats, Stores, J's report and the study are as before.
16. Map sandbox: no chips; a row's card shows goods by season, no money; I says "The sandbox has no treasury."
17. F2: `money 500`, `goods stone 40`, `tax low`: each shows on the chips and in the next report.
18. Play on to **Winter 1489** (`end 4` helps): no error; the study's chart fills twelve seasons.

---

## 5. Definition of done

1. The spec's "M4 is done when" items 1 to 8 hold.
2. Tasks N1 to N12 and W1 to W12 (W8a, W8b, W11a, W11b) merged; CI green, with both UI `--check`s, `build_scenario.gd
   --check`, and the nightly `perf_core` and `perf_ui` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac.
5. `godot-architecture.md` 9.2 marks M4 done; `godot/README.md` describes the M4 game.
6. Section 7 below is handed to the M4.5 and M5 build specs' authors.

---

## 6. How to start

On the day M3 closes:

1. Opus presents the economy (spec 4.1 to 4.12 and the worked examples of 4.15) to the owner and Fable in 30 minutes; a
   change of a number is a data line now, not a task later. Fable signs `district_output`, `market_prices` and
   `Treasury.move` (spec 5.3) the same day.
2. Start group A together: **W3, N2, W1, W4** (Sonnet) and **N1** (Haiku). Opus reads N1's numbers on its first day; the
   art director sees W3's 16 goods icons on its second.
3. N3 and W2 start when group A merges; N3's worker reads spec 4.4 to 4.9 and the worked examples during group A.
4. N4 measures `production_ms` on the fake Europe in its first week (spec 10), before the UI builds on the phases.

---

## 7. What M4 hands on

- **M4.5:** `Stats`' money and goods series and the goods ring; the closed ledgers; `EconomyPreview.worth_by_hex` (the
  Districts tab); `InkChart`'s two kinds to complete; `StudyPages.LIST` and the study frame; `MapModes.delta_colour` for
  the Yields mode.
- **M5:** `Economy.people_at` (reads `MapState.people`; the table becomes room); towns' needs and contentment (hunger,
  decline); food's `goods_short`; the tax level's growth effect; the settlement payoffs to re-tune (spec D42); the People
  and Food chips (icon `food` baked).
- **M6:** `Treasury.WHY` `army`; armies' food from the stores; horses and iron reserves; the Army chip (icon baked).
- **M8:** `set_tax`, works with costs and `cancel_work` as the AI's actions; `ImprovePreview` and `EconomyPreview` as its
  views; the money property in the soak.
- **M10:** the body of `market_prices`; `market_of`; sales to markets; road works (`MapState` schema 4); price lines on the
  card; `Treasury.WHY` `trade`.
- **M12:** `debt_limit`, interest, bankruptcy; the Debt tab; the Prestige chip.
- **Saves:** `SaveFile.FORMAT` 2; a new body field with a default needs no bump (M3 4.10).
