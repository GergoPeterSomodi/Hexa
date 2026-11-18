# UI style (Studiolo) and feedback screens: the plan

Technical director, 2026-11-17. Builds `docs/architecture/ui-style-and-feedback-spec.md` ("the spec"). **Status: a
proposal; no task starts before the owner's go.** It re-bases the M1.5 tasks of `ui-and-controls-plan.md` ("the UI
plan") on Studiolo, then adds the feedback screens to M3, M4 and a new M4.5.

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Milestone | Ships | Tasks |
|---|---|---|---|
| **S0** Style foundation | M1.5, first | Probes, the UI bake, the generated Theme (1x, 2x, flat), fonts, the kit sheet | 7 S, 2 M, 1 L |
| **S1** UI foundation, re-based | M1.5 | The UI plan's slice, built in Studiolo from the start | 4 S, 12 M, 3 L |
| **S2** Season report | M3 | `Stats`, the `stats` phase, `Knowledge`, the report, the year medallion | 5 S, 6 M |
| **S3** Works preview, Economy page | M4 | `Treasury`, `ImprovePreview`, the card, map marks, the study with "This season", icons | 4 S, 7 M, 2 L |
| **S4** Insights I | M4.5 | Chart and table kit complete, Economy tabs, History, Rankings, Yields mode | 3 S, 5 M |
| **S5** Later pages | M5 to M12 | A study page and a report section with each system | inside each milestone |

```
K1 -> K5 -> K6 -> K7 -> K8, K9          P3 -> K5, K7          P2 -> K7 (picks spec 4.8 A, B or C)          G1 -> U17
U1, U2, U3, M1 need no style: they run beside S0
K7 -> U7a, U7b, U8 -> U10..U14, H1 -> U15 -> U16 -> the owner plays M1.5
M1.5 -> M2 (its own spec; bake slice 2) -> M3 core -> R5 -> R6 -> R7, R8 -> R10 -> R11 -> the owner plays M3
W0 (starts now) -> M4 economy system -> W5 -> W8..W11 -> W12 -> the owner plays M4
S3 -> I1..I4 -> I5..I7 -> I8 -> the owner plays M4.5
```

**Critical path:** K1, K5, K6, K7, U7a and U7b, U14, U15, U16 for M1.5 (the bake, K5, is the long pole: nothing
themed is built before it). For the feedback screens: the M3 core, R5, R7 and R8, R10; then **W0, the seasonal
district economy design**, which gates W5 and the works card. W0 starts now, beside S0.

---

## 2. Tasks

Sonnet-sized unless marked. A task owns its files: **no two tasks of one group touch the same file.** Generated files
(`ui_kit.json`, kit PNGs, `theme*.tres`) are re-made by the task that changes their source and belong to it. "Done
when" always includes lint, check_scripts and GUT green, and both `--check`s once K8 is in. Who: *Fable* writes
interfaces and reviews; *Opus* designs; *Sonnet* builds systems, tools and anything touching `Game`, saves, the season
table, `Session` or the App; *Haiku* builds screens and panels from the mockup, data, and tests from a list.

### S0: the style foundation

**Group A (parallel, no dependencies)**

| # | Task | Files (new unless said) | Done when |
|---|---|---|---|
| K1 (Haiku, S) | **Tokens** | `shell/ui/tokens.gd`, `tests/shell/test_tokens.gd` | Spec 4.2 and the type and variation tables of 4.3 and 4.7 as data; every ratio of `design.md` 3 passes; the file parses in the bake's one-line form |
| P2 (S) | **Probe: frames and HiDPI** | `godot/tools/probes/probe_ui_frames.gd`, `docs/architecture/probes/ui-frames.md` | PASS or FAIL for each fact of spec 12 from the owner's Retina Mac and from Windows; a recommendation A, B or C for spec 4.8; the added ms and draw calls of a textured HUD over the fake Europe |
| P3 (S) | **Fonts in, and their probe** | `godot/assets/fonts/**` (TTFs, `OFL.txt`, `.import`), `tools/ui_bake/fonts/`, edit `godot/CREDITS.md`; `godot/tools/probes/probe_ui_fonts.gd`, `docs/architecture/probes/ui-fonts.md` | Each file's missing characters listed against the required set; tabular digits measured through `FontVariation`; the fallback proven with system fallback off |
| G1 (S) | **Probe: texture memory** (the UI plan's G1) plus `menu_bg` as RGBA8 against compressed | as the UI plan | as the UI plan |
| K4 (Haiku, S) | **Mockup references and the compare tool** | `godot/tests/fixtures/mockup/<scene>.png` (the nine stages at 1280 x 720, rendered once in headless Chrome; the command in a README beside them), `tools/ui_compare.py`, `tests/test_ui_compare.py` | A side-by-side sheet and a 64 x 36 colour difference from any two pictures; the tool's unittest |

**Group B (after K1 and P3)**

| # | Task | Files | Done when |
|---|---|---|---|
| K5 (L) | **The bake: engine, frames, controls** | `tools/bake_ui.py`, `tools/ui_bake/{tokens,noise,light,shapes,materials,checks,png,pieces_frames,pieces_controls}.py`, `tools/requirements-bake.txt`, `tests/test_bake_ui.py`, `godot/assets/ui/kit/` (`ui_kit.json`, `1x/`, `2x/`, `.import` files) | Slice-1 frames and controls of spec 4.5; equal hashes on macOS, Linux and Windows; every assert of spec 4.4 fires on a planted fault; both scales bake in under a minute; the art director signs the contact sheet beside the mockup |

**Group C (after K5, P2; K6 merges before K7)**

| # | Task | Files | Done when |
|---|---|---|---|
| K6 (M) | **The bake: art pieces** | `tools/ui_bake/pieces_art.py`, `tools/ui_bake/inputs/menu_map.png`, `godot/tools/ui/shot_menu_map.gd`, `godot/assets/ui/menu/`; re-made kit files | `seal`, `stud`, `glow_soft`, `rule_diamond`, `icons_base`, `wordmark`, `rose`, `menu_bg`, `menu_shade`; the wordmark within its tolerance; the menu art beside `menu.jpg` signed |
| K7 (M) | **Theme builder and `KitTheme`** | `godot/tools/build_theme.gd`, `shell/ui/kit_theme.gd`, `shell/ui/theme_high_contrast.tres`, `tests/shell/test_theme.gd`, `test_kit_theme.gd`; re-made `shell/ui/theme.tres` | Spec 4.7 to 4.9 with the mechanism P2 chose; `--check` passes; the `Hex*` aliases keep today's panel working (its new look in the pull request: a look change, said so) |

**Group D (after C)**

| # | Task | Files | Done when |
|---|---|---|---|
| K8 (S) | **Lint and CI** | edit `tools/lint_godot.py` (the rules of spec 2, with an allowlist for today's `map_scene.tscn`), `.github/workflows/godot.yml` (Python 3.12, `pip install -r tools/requirements-bake.txt`, `bake_ui.py --check`, `build_theme.gd --check`) | A planted token change and a hand-edited `theme.tres` each fail CI |
| K9 (Haiku, S) | **Kit sheet** | `godot/tools/ui/kit_sheet.tscn/.gd`, `godot/tools/ui/shot_kit.gd` | One picture each at 1x, 2x and plain showing every variation and state; the art director signs it |

### S1: the M1.5 tasks of the UI plan, re-based

Groups and files as in the UI plan section 2 unless said. S0 and group A run side by side; group B starts when K7 is
merged.

| UI plan task | Verdict | What changes because of Studiolo |
|---|---|---|
| U1 App root | keep | nothing |
| U2 Bindings, zoom, Esc ladder | re-scope (small) | `DEFAULTS` also lists the actions of spec 9 with their `since` |
| U3 Settings, Display | re-scope (small) | adds `dev/ui_kit`; the first-run default of `reduce_motion` comes from the system |
| **M1** (new; Haiku, S; group A) | add | `shell/ui/motion.gd`, `tests/shell/test_motion.gd` (spec 4.11) |
| U4 Tokens, Theme, fonts, lint | **drop** | replaced by K1, P3, K5 to K8 |
| G1 | move | runs in S0 group A |
| U5 Screen, stack, harness | re-scope (small) | `push` calls `Motion.enter`; the shade is `SHADE`; the harness gains `shot(name)` |
| U6 CameraRig, MapInput | keep | nothing |
| U7 The kit | **split** | **U7a** (M): `kit_button.gd` (kinds with `MENU`, lock and reason line, lazy `Glow`), `segmented.gd`, `kit_switch.gd`, `kit_slider.gd`, `key_cap.gd`, `option_row.*`, `test_kit.gd`. **U7b** (Haiku, M): `panel_frame.*` (cartouche title), `modal_frame.*` (ribbon, bosses), `vellum_sheet.*`, `ribbon.gd`, `cartouche.gd`, `nav_list.gd`, `hover_card.*`, `toast_host.*`, `toast.tscn`, `test_kit_frames.gd` |
| U8 App lifecycle | re-scope | sets the window's theme from `KitTheme.load_for` at start and on a UI-scale change; `-- --plain-ui`; `gui/theme/custom` |
| U9 HexCard | keep | nothing |
| U10 Pause, Confirm, Loading | re-scope (look) | pause: ribbon "Paused", `ButtonMenu`s, Resume primary, Quit danger; confirm on `VellumSheet` with the countdown in the pressed seal; loading on the progress channel |
| U11 Options, About | re-scope | 860 x 580; `NavList`; Back in the header; footer Defaults and Apply with staged window rows |
| U12 Main menu, sandbox, credits | re-scope | wordmark, `menu_bg` and `menu_shade` loaded on enter and dropped on exit, the rose, the column at `MENU_COLUMN_X`, the drift; credits on vellum |
| U13 Help | re-scope (look) | `ModalFrame` with a ribbon; three columns of bone key caps |
| U14 HUD frame | re-scope | the walnut `PanelBar` with the brand; card frames for the zoom control and hover card; swallow-tail toasts; adds `shell/hud/key_hints.gd` |
| **H1** (new; Haiku, S; group C) | add | the hex panel in Studiolo: edit `shell/panels/hex_panel.tscn/.gd`, `shell/ui/panel_kit.gd`, `tests/shell/test_hex_panel.gd`, `shell/ui/tokens.gd` (the `Hex*` aliases go), re-made `theme.tres`. Cartouche title, `SectionHead`s, key and value ledger, width `PANEL_W` |
| U15 Wire the App | keep | nothing |
| U16 Monkey, pictures, CI | re-scope | pictures are the mockup's M1.5 scenes at scale 1 and 2 with K4's side-by-side sheets and coarse check; adds `godot/tools/ui/perf_ui.gd` and `godot/tests/perf_ui_budget.json`; the goldens are stored after the owner signs |
| U17 Texture memory fix | keep | nothing |

Merge order: the UI plan's (A, B, C, D, E), with K7 before group B and H1 in group C.

### S2: the season report (M3)

It needs the M3 core from M3's own build spec: `Game.turn`, `PHASES` in `core/game/season.gd`, works in `MapState`,
`to_dict` saves, `action_log`, `Session.end_season`, `save`, `load`.

| # | Group | Task | Files | Done when |
|---|---|---|---|---|
| R1 (Fable, S) | A | **Interfaces into the M3 build spec** | `docs/architecture/m3-build-spec.md` (its feedback section) | `version`, `emit`, `stats`, events with `witnesses`, the `stats` row, `cancel_work` are in M3's spec with their owners |
| R2 (Haiku, S) | A | **`Knowledge`** | `core/views/knowledge.gd`, `tests/core/test_knowledge.gd` | Spec 6.5; the test of spec 11 |
| R3 (Haiku, M) | A | **Bake slice 3 and the medallion** | `tools/ui_bake/pieces_hud.py`, re-made kit files and `theme.tres`, `shell/ui/medallion.gd`, `tests/shell/test_medallion.gd` | Medallions, dial, End season plate, seal tones; busy turns the ring, or shows the hourglass under reduce motion |
| R4 (Haiku, S) | A | **`DeltaChip`** | `shell/ui/delta_chip.gd`, `tests/shell/test_kit_feedback.gd` | Icon and sign in every state, on leather and on vellum |
| R5 (M) | B, after the M3 core | **`Stats` and the phase** | `core/state/stats.gd`, `core/systems/stats_system.gd`, `tests/core/test_stats.gd`; edit `core/game/season.gd`, `core/game/game.gd`, `tests/core/test_season.gd` | Spec 6.2; ring, year rows, save round trip, digest; the phase under 1 ms a country on the fake Europe with 60 countries |
| R6 (S) | C | **Events and Session** | edit `shell/autoload/events.gd`, `session.gd`, `tests/shell/test_session.gd` | `season_ended(turn)` after the last drain; the three work signals |
| R7 (M) | D | **`SeasonSummary` and `Reminders`** | `core/views/season_summary.gd`, `core/views/reminders.gd`, `tests/core/test_season_summary.gd`, `test_reminders.gd` | Spec 6.4 for the M3 sections (glance, before, works, orders); under 2 ms |
| R8 (M) | D | **`SeasonFlow`** | `shell/app/season_flow.gd`, `tests/shell/test_season_flow.gd`; edit `shell/app/app.gd`, `shell/app/settings.gd`, `shell/input/bindings.gd` | Spec 6.7: the guard at 399 and 401 ms, Full, Brief and Off, dropped toasts |
| R9 (Haiku, M) | D | **Date medallion and End season** in the top bar | `shell/hud/date_end.tscn/.gd`, `tests/shell/test_date_end.gd` | The year, the season's quarter, the busy state; a click or J asks for the report |
| R10 (Haiku, M) | E | **The report screen** | `shell/screens/season_report.tscn/.gd`, `tests/shell/test_season_report.gd`; edit `shell/screens/screen_ids.gd` | Spec 6.8 against `report_m4.jpg` cut to M3's sections; links glide; the quiet state |
| R11 (Haiku, S) | F | **Monkey, pictures, perf** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tests/perf_ui_budget.json`, `tests/fixtures/ui_sample.gd` | The invariants and budgets of spec 11 for the report |

Bake slice 2 (minimap frame, shield rims, pennant pole and cloth) ships with M2's own UI tasks, in `tools/ui_bake/pieces_m2.py` (task C5 of `m2-build-plan.md`).

**`m3-build-plan.md` folds these tasks into M3** with their IDs (its opening table): R1 is done by `m3-build-spec.md`;
R6 is merged with the Session season work; R8's edits of `app.gd`, `settings.gd` and `bindings.gd` belong to its tasks
Y18 and Y3; R11 is merged with the M3 monkey and pictures; R5 fills `stats_system.gd` while Y1 writes the season table.
The "M3 core" of the dependency line above is Y1, Y5 and Y6 there. `core/game/view_cache.gd` is created in M3 (Y1), so
W5 below edits it.

### S3: the works preview and the Economy page (M4)

**`m4-build-plan.md` folds these tasks into M4** with their IDs (its opening table): W0 is done by `m4-build-spec.md`; W2
also builds `Stores` and every M4 field of `Country`; W8 and W11 are split in two (kit pieces first, screens after the
previews); W9 no longer edits `settings.gd` or `bindings.gd` (their M4 rows exist); `resource_chip.tscn` is its task N8;
the system tasks are N1 to N12.

| # | Group | Task | Files | Done when |
|---|---|---|---|---|
| W0 (Opus, M; **starts now**) | 0 | **The district economy carries spec 7.3**; Fable signs `district_output`, `market_prices`, `Treasury.move` | the M4 design page and `docs/architecture/m4-build-spec.md` | The six requirements are answered yes or no in writing; a no on 1 or 2 flips assumed decision 2 |
| W1 (S) | A | **`StateView`** | `core/state/state_view.gd`, `tests/core/test_state_view.gd` | Reads fall through; an overlay never changes its base |
| W2 (M) | A | **`Treasury` and the ledger** | `core/systems/treasury.gd`, `tests/core/test_treasury.gd`; edit `core/systems/stats_system.gd` | Spec 6.3; the property test; no other writer of a treasury |
| W3 (L) | A | **Bake slice 4: the icon set and the feedback frames** | `tools/ui_bake/icons.py`, `pieces_feedback.py`, re-made kit files and `theme.tres` | About 48 icons the art director signs on a sheet; `vellum_inset` and the strip cells |
| W4 (M) | A | **`InkChart`, first two kinds** | `shell/ui/ink_chart.gd`, `tests/shell/test_ink_chart.gd` | `PAIRED_BARS` and `LINE_BARS` with 0, 1 and 40 points; redraws only on new data |
| W5 (L) | B, after M4's `Economy` | **`ImprovePreview`, `EconomyPreview`, the cache** | `core/views/improve_preview.gd`, `economy_preview.gd`, `core/game/view_cache.gd`, `tests/core/test_improve_preview.gd` | Spec 7.1 and 7.2; the 200-case property test; a hex panel's build list with previews under 2 ms |
| W6 (S) | B | **The report's money sections** | edit `core/views/season_summary.gd`, `reminders.gd`, their tests | Treasury, Goods, Standing; every ducat sums; the money and food notices |
| W7 (S) | B | **`StudyEconomy.this_season`** | `core/views/study_economy.gd`, `tests/core/test_study_economy.gd` | Equals the ledger and `EconomyPreview` to the unit |
| W8 (Haiku, M) | C | **The card** | `shell/ui/season_strip.tscn/.gd`, `preview_card.tscn/.gd`, `shell/screens/works_preview.tscn/.gd`, `tests/shell/test_works_preview.gd` | Against `works_genoa.jpg` and `works_vineyard.jpg`; the refusal; pin to compare |
| W9 (Haiku, M) | C | **Hex panel rows, confirm, cancel** | edit `shell/panels/hex_panel.tscn/.gd`, `shell/app/settings.gd`, `shell/input/bindings.gd`, `tests/shell/test_hex_panel.gd` | Chips and cost on each row; the three `confirm_works` values; U opens the card; the toast's Undo |
| W10 (M) | C | **Map marks** | `shell/map/preview_marks.gd`, `tests/shell/test_preview_marks.gd`; edit `shell/mapview/tile_map_view.gd`, `core/views/map_modes.gd` | Ghost, labels and tint appear with the card and leave with it; no cell of the real layers is written |
| W11 (Haiku, M) | C | **The study and "This season"** | `shell/screens/study.tscn/.gd`, `study_page.gd`, `study_pages.gd`, `study/page_economy.tscn/.gd`, `shell/ui/resource_chip.tscn`, `tests/shell/test_study.gd` | I and L open it; the tax hover preview; a row looks there; I returns to the same page |
| W12 (Haiku, S) | D | **Monkey, pictures, perf** | as R11 | Spec 11 for the card and the study |

### S4: Insights I (M4.5)

**`m4-5-build-plan.md` folds these tasks into M4.5** with their IDs (its opening table): I3 is split into I3a (Economy's
views, with `EconomyPreview.worth_seasons`, the `Stats` accessors and the test fixture) and I3b (Rankings and History);
I4 into I4a (the read model and the hover card's Worth line) and I4b (the map); I2 grows to M and follows I1 (it draws
with `InkMarks`); I5 grows to L (three tab scenes); I7's action-log edit moves to Q3; I8 adds the five-questions test and
the read-only proof. New: Q1 `TimelineStrip`, Q2 the study frame's tabs and the mockup renders, Q3 the App, Q4 the Yields
legend, Q5 the perf games, core rows and core proof. M4.5 adds no game rule (`m4-5-build-spec.md` D1).

| # | Group | Task | Files | Done when |
|---|---|---|---|---|
| I1 (M) | A | **`InkChart` complete** | edit `shell/ui/ink_chart.gd`, its test | `LINE`, `STACKED_BAR`, `SPARK`, marks, the cursor, `summary()` |
| I2 (Haiku, S) | A | **`StudyTable`** | `shell/ui/study_table.gd`, `tests/shell/test_study_table.gd` | Stable sort, ties by id; keys |
| I3 (M) | A | **Study views** | edit `core/views/study_economy.gd`; `study_rankings.gd`, `study_history.gd`, their tests | Districts, goods, history; rankings only through `Knowledge`; the chronicle filters |
| I4 (M) | A | **Yields map mode** | edit `core/views/map_modes.gd`, the mode overlay and its `Segmented` entry, tests | One draw; a changed hex rewrites one pixel |
| I5 (Haiku, M) | B | **Economy tabs** | edit `shell/screens/study/page_economy.tscn/.gd`, its test | Districts, Goods, History against `study_econ.jpg` |
| I6 (Haiku, S) | B | **Rankings page** | `shell/screens/study/page_rankings.tscn/.gd`, test | Known countries, banded; "n countries unknown" |
| I7 (Haiku, M) | B | **History page** | `shell/screens/study/page_history.tscn/.gd`, test; edit `shell/hud/action_log.gd` (older season headers open it) | Timeline and chronicle; a mark looks there |
| I8 (Haiku, S) | C | **Monkey, pictures, perf** | as R11 | Each page under 16 ms; the owner's five questions |

### S5: later pages, with their systems

Each row is a task group inside that milestone's own build spec; the kit and the screens exist by then.

| M | Study | Report | Other |
|---|---|---|---|
| M5 People | People page; people in Rankings | People section; `town_grew`, `district_declined` | Food map mode |
| M6 Armies | Military page (armies table) | "What befell" with real `witnesses`; raised and marched in Your orders | `REPLAY` before the report; Supply mode |
| M7 War | losses chart, wars | battle and siege lines | the war alert as a `DECISIONS` screen |
| M8 AI | | | the AI reads `Knowledge`; the soak checks the `stats` budget |
| M9 Diplomacy | Diplomacy page; `RelationMatrix` joins the kit | `truce_ended` | peace offer as a decision; Relations mode |
| M10 Trade | Trade page; sparklines in tables; the price ring | `price_moved` | Trade flows mode |
| M11 Research | Research page | research line | idea pick as a decision |
| M12 | score in Rankings; the Debt tab | debt and score lines | the high-contrast row, text size in charts, `seal_cracked`, sounds |

---

## 3. Reviews

The code reviewer reads every task. The technical director reads K5, K7, R5, R7, R8, W2, W5 and the interfaces of R1
and W0. The art director signs K5 and K6 (contact sheets), K9 (kit sheet), W3 (icons) and each slice's side-by-side
pictures. Pull requests: the bake and Theme tasks say "a look change" and carry before and after pictures; every other
task says what changes for the player.

---

## 4. The owner's playtest after each slice

**S0 (a look check).** The kit sheet at 100 % on Windows and at 200 % on the Retina Mac, beside the
mockup: (1) frames, gilt lines and text are sharp at both; (2) every text is readable on leather, walnut and vellum;
(3) nothing looks flat or busy against the mockup; (4) `dev/ui_kit = plain` shows the flat theme; (5) today's hex panel
wears the new look in the game.

**S1 (M1.5).** The twelve steps of the UI plan section 3, and: (1) the main menu matches `menu.jpg`: wordmark,
drifting map, wind rose; (2) at UI scale Auto, 150 % and 200 % the frames stay sharp, and a scale change asks to keep;
(3) hover glows, the confirm's seal presses and counts down; Reduce motion stops all of it; (4) F3 shows the frame
under 16 ms with the HUD up; (5) at 1280 x 720 nothing is clipped.

**S2 (M3).** (1) End season opens the Chancellor's letter; (2) Space, Space plays one season, not two; (3) Brief
opens only for a notice, Off gives the toast, J brings the letter back; (4) a place name closes the letter and glides
there; (5) save, quit, load, J: the same letter; (6) a season with nothing in it says "A quiet season."

**S3 (M4).** (1) Hover "Build vineyard": the card opens with what it brings, the four seasons and the payback; (2)
begin it, then cancel it from the toast: the money returns; (3) begin it again and play to the first vintage: the gain
is what the card said; (4) the letter's Treasury lines add up to the change; (5) L opens the Economy page and the
tax buttons show their effect before you click; (6) Savona's upgrade is refused in plain words.

**S4 (M4.5).** Five questions answered from the study in under a minute each: which district earns most; why the
treasury fell in a given winter; which good runs short; where you rank on land and income; what happened in a given
season. Then "Show on map" for one of them.

---

## 5. Definition of done for the whole effort

1. Every screen of the mockup that its milestone allows exists in Godot and is signed side by side at scale 1 and 2.
2. No `theme_override_`, colour literal or hand-made stylebox outside `shell/ui/` (lint); `bake_ui.py --check` and
   `build_theme.gd --check` are green in CI; the kit stays under 4 MB (1x) and 16 MB (2x).
3. The report explains every ducat (property test) and Space, Space plays one season.
4. A preview equals the season that follows it for four calm seasons (property test) and never changes the digest.
5. No other country's hidden number reaches a screen: `Knowledge` is the only door (test).
6. `Stats` is saved, in the digest and under its budget; J after a load shows the same letter.
7. The perf budgets of spec 11 hold nightly; the monkey is green with its new invariants.
8. The owner has played S1 to S4 and answered the five questions of M4.5.
9. `godot-architecture.md` section 9 carries the rows of spec 10; the UI spec and plan carry their delta notes.

---

## 6. How to start Monday

1. **K1 Tokens** (Haiku): it unblocks the bake.
2. **P3 Fonts in, and their probe** (Sonnet): the bake's font asserts and the Theme need the files.
3. **P2 Frames and HiDPI probe** (Sonnet): the owner runs it once on the Retina Mac; it picks the 2x mechanism.
4. **G1 Texture memory probe** (Sonnet): the same sitting on the Mac.
5. **K4 Mockup references and the compare tool** (Haiku).

The same day, beside them: U1, U2, U3 and M1 (no style needed), and **W0** (Opus begins the seasonal economy
requirements, M4's long lead). K5, the bake, starts when K1 and P3 are merged.
