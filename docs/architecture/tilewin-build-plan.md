# Tile window build plan: one uniform window per tile (issue 436)

Technical director, 2026-11-25. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/tilewin-build-spec.md` ("the spec"), which builds section 3 of `docs/design/ui-family-audit.md` as the
owner answered it (2026-11-24), on top of the fog build.

**When it runs.** After the fog build (on master) and before M9.5, which needs the Industries slot (economy-rethink 11).
It changes no rule, no save and no AI, so it can run beside the paper planning of the next milestone. Issue 432 (moves in
the month) and the battle board are not part of it; the Army tab leaves a field for 432's "points left" (spec D16).

**Task IDs** are `TW0` to `TW15`.

---

## 1. Groups, effort, order

S is about half a day of one worker, M a day.

| Group | Ships | Tasks | Effort |
|---|---|---|---|
| **Gate. The mockup** | the art director's mockup of the window; the owner approves it | TW0 | 1 M (art director) |
| **A. Seams** | three core functions moved to where views may read them; the works rows extracted from the hex panel; the tab registry and its export probe. **No behaviour change** | TW1, TW2, TW3 | 1 M, 2 S |
| **B. Read models** | `TileView` and the raise card, with their tests | TW4, TW5 | 1 M, 1 S |
| **C. The tabs and the frame** | the window, its four tabs and the fog proofs, built and tested beside the old panel (nothing in the HUD yet) | TW6 to TW11 | 4 M, 2 S |
| **D. The swap** | the window replaces the hex panel in the HUD; every caller and test moved; the old panel deleted | TW12 | 1 M |
| **E. Menu, keys, proofs, finish** | the menu's two items, the tab keys, the monkey, the perf rows, the pictures and the docs | TW13, TW14, TW15 | 2 M, 1 S |

**16 tasks: 10 M, 6 S**, about 13 worker-days; about 5 working days end to end (each group as long as its longest task),
plus the mockup's approval, reviews and the owner's playtest.

```
owner's go
  -> Gate: TW0 (art director's mockup)  ......................  owner approves  --+
  -> A:  TW1 (S)  TW2  TW3 (S)                (TW1 records the perf baseline)     |
  -> B:  TW4  TW5 (S)                          (technical director reads TW4's    |
                                                interface before merge)           |
  -> C:  TW6  TW7  TW8 (S)  TW9  TW10 (S)  TW11   <-------------------------------+ (C starts after B AND the approval)
  -> D:  TW12                                  (the fold-in checklist, spec 7.3)
  -> E:  TW13 (S)  TW14  TW15  -> the owner plays the checklist of section 5

Critical path: TW1 -> TW4 -> TW9 -> TW12 -> TW15        (and TW0 -> approval -> C)
```

A group starts when every task of the group before it is merged. Inside a group no two tasks touch one file and no task
calls code another task of its group writes. Shared fixtures have one owner: `tests/shell/fixtures/tile_tabs/` (the fake
tab) TW3; `tests/core/fog_fixture.gd` is the fog build's and is only read here.

---

## 2. Tasks

*Sonnet* builds the core views, the window, the tabs, the swap and anything touching `Session`, `Hud` or the input;
*Haiku* builds the empty Ships tab, the monkey step, the perf rows, the pictures and the player text from a list. **Every
task's done-when includes: lint (`python tools/lint_godot.py godot`), check_scripts and GUT green, both UI `--check`s; no
planted fault (P) of an edited test is deleted without a replacement; no game window is opened without the owner's go
(headless only).** Paths without a prefix are under `godot/`; `tools/`, `docs/`, `README.md` are at the repository root.

### Gate

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW0 | M, art director (creative director reviews) | **The mockup** | `mockups/` beside the repository (not in it): the window at 1280 x 720 for the cases of spec 3.8 (own port on Details, Build and Army; foreign light fog; foreign in sight with an enemy army and a siege; a battle site; sea; deep fog), the strip with five labels, the badges, the job line with Cancel; Studiolo tokens only; built from the spec's sketches (section 6) | The owner has approved the mockup, or named the changes; any change to a rule of the spec goes back to the technical director before group C |

### Group A (parallel; no behaviour change, spec R26)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW1 | S, Sonnet | **Core seams and the perf baseline** | edit `core/systems/improve.gd` (`is_port`, moved), `core/ai/ai_know.gd` (`is_port` calls it), `core/systems/military.gd` (`raise_offered`, moved), `shell/panels/raise_list.gd` (`offered` calls it), `core/views/hex_card.gd` (`war_rows_for`; `war_rows` calls it with `game.player`); edit `tests/core/test_ai_know.gd`, `test_military.gd`, `test_hex_card.gd` (the new names, the same answers) | Spec 1, 4: every existing test unchanged in meaning and green; `test_ai_door.gd` green (the door still reads `AiKnow.is_port`); the baseline of spec 8's existing rows (`hud_frame_worst_ms`, `hex_menu_war_ms`, `works_card_push_ms`, `army_panel_open_ms`) run once headless where the tool allows, the numbers in the pull request |
| TW2 | M, Sonnet | **The works rows and the job line out of the hex panel** | new `shell/panels/tile_tabs/build_rows.gd` (the rows, chips, (i), confirm rule, `begin`, the `works_requested` names), `shell/panels/tile_tabs/job_line.gd` (the work under way and Cancel); edit `shell/panels/hex_panel.gd` and `.tscn` to use both | Spec R17, R26: `test_hex_panel.gd`, `test_hex_panel_people.gd`, `test_works_preview.gd`, `test_hex_menu.gd` **unchanged** and green; `hex_panel.gd` shorter by the moved code; no word, order or signal changed (the code reviewer diffs the moved functions) |
| TW3 | S, Sonnet | **The tab registry and its export probe** | new `shell/panels/tile_tabs/tile_tab.gd` (`TileTab`), `shell/panels/tile_tabs/tile_tabs.gd` (`TileTabs`: `all`, `for_view`, `with_folder`, `reset`), `tests/shell/fixtures/tile_tabs/fake_tab.gd` (`ORDER` 30, label "Industry", applies on own settlements), `tests/shell/test_tile_tabs.gd`, `godot/tools/probes/probe_tile_tabs.gd` | Spec R11, D4: the fake tab found through `with_folder` (P: a hard-coded list); a duplicate `ORDER` named (P); the probe run on an exported Windows build (`--export-release`, headless) lists the folder's scripts, its output in the pull request. If it does not, the task builds the fallback instead: `godot/tools/build_tile_tabs.gd` writes `shell/panels/tile_tabs/tile_tabs_index.gd` from the folder, with `--check` added to CI beside `build_theme.gd --check` |

### Group B (after A, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW4 | M, Sonnet | **TileView** | new `core/views/tile_view.gd`, `tests/core/test_tile_view.gd` | Spec R1 to R4, R9, R10, R12's facts, R13's lines, 3.8, section 4: each case of 3.8 on north Italy and the sandbox, with the planted faults of spec 7.1 for this file; cached by `[&"tile", version, viewer, hex]`; lint's `core/` rules green |
| TW5 | S, Sonnet | **The raise card** | new `core/views/raise_card.gd`, `tests/core/test_raise_card.gd` | Spec R18, D12: each kind's lines (men, move points, upkeep, cost lines, role) from `UnitDef` and `Military.cost_of`; a refused kind keeps its card (P: a card without the cost lines) |

### Group C (after B and the owner's approval of TW0; parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW6 | M, Sonnet | **The window frame** | new `shell/panels/tile_window.gd`, `tile_window.tscn` (extends `HexPanelContract`: header with `Cartouche`, owner link, badges; `JobLine`; the strip from `TileTabs.for_view`; the scroll and `_fit`; one refresh per burst; `show_tab`, `next_tab`, `tab_open`, `tab_ids`, `begin_option`), `tests/shell/test_tile_window.gd` (drives the frame with the fixture's fake tabs) | Spec R13 to R15, R22 (the window's part: `next_tab`, focus on the strip), R23, R24: strip hidden with one tab (P: a greyed tab); R14's choice and fall-back (P: a stale tab); only the open tab has children (R15); R23 at both sizes and both themes with the fake fifth label (P: an overflowing label) |
| TW7 | M, Sonnet | **Details tab** | new `shell/panels/tile_tabs/details_tab.gd` (uses `HexWar.fill`, `PeopleView` words, the battle row, Show supply, Show the castle area, Why not), `tests/shell/test_details_tab.gd` (the cases of `test_hex_panel_people.gd`, `test_hex_panel_fog.gd` and the details half of `test_hex_panel.gd`, copied and adapted) | Spec R16, R13's lines, R20: every copied case green; the battle row's button asks `open_battle`; sea and sandbox rows; the write scan (R20) over the file |
| TW8 | S, Sonnet | **Build tab** | new `shell/panels/tile_tabs/build_tab.gd` (hosts `BuildRows`), `tests/shell/test_build_tab.gd` (the works cases of `test_hex_panel.gd`, copied) | Spec R17: the copied cases green, words and signals unchanged; U reaches the first Upgrade row through the model |
| TW9 | M, Sonnet | **Army tab** | new `shell/panels/tile_tabs/army_tab.gd` (hosts `RaiseList`, the hover card of TW5, "Armies here" rows, optional `points_text`/`arms_text`), `tests/shell/test_army_tab.gd` (the cases of `test_raise_list.gd`, copied, plus own and foreign army rows) | Spec R18: a Select button on own armies only (P: one on a foreign army); the hover card shows; the raise still toasts its words |
| TW10 | S, Haiku | **Ships tab** | new `shell/panels/tile_tabs/ships_tab.gd`, `tests/shell/test_ships_tab.gd` | Spec R19, D5: the one line on Genoa; absent on Asti (P: Ships on an inland town) |
| TW11 | M, Sonnet | **The fog proofs** | new `tests/core/test_tile_fog.gd` (the twin test of R5 on `FogFixture.thin` and `duel_thin`; R4 viewer not `game.player`; R6, R7), `tests/core/test_tile_door.gd` (R8's scan); edit `tests/core/test_fog_exact.gd` (its scan lists the new files) | Spec R4 to R8: each P of spec 7.1 for these files caught; the twin test compares every hex of the map |

### Group D (after C)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW12 | M, Sonnet | **The swap** | edit `shell/hud/hud.tscn`, `hud.gd` (`tile_window()` replaces `hex_panel()`), `shell/app/war_requests.gd`, `shell/hud/hex_menu.gd` (its cast and the works path through `TileWindow.begin_option`; no new item yet), `shell/map/map_armies.gd` (only if it names the panel); delete `shell/panels/hex_panel.gd`, `.tscn`, `tests/shell/test_hex_panel.gd`, `test_hex_panel_people.gd`, `test_hex_panel_fog.gd`, `test_raise_list.gd`; edit the callers of spec 7.2 (`test_hud.gd`, `test_app.gd`, `test_app_flow*.gd`, `test_army_toasts.gd`, `test_works_preview.gd`, `test_hex_menu.gd`'s cast only, `monkey_m6.gd`, `monkey_m7.gd`, `tools/ui/shot_ui.gd`, `shot_ui_m6.gd`, `shot_ui_fog.gd`, `perf_ui.gd`, `perf_ui_m7.gd`, `godot/tests/perf_ui_budget.json` (the `hud_frame_worst_ms` text)) | Spec done-when 2, R21 (opening), R25: the fold-in checklist of spec 7.3 in the pull request and checked by the code reviewer; the app runs headless (`--quit`), the monkey's existing seeds green; no `HexPanel` or `hex_panel(` left in `shell/`, `tests/`, `tools/` |

### Group E (after D, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| TW13 | S, Sonnet | **The menu's items and the tab keys** | edit `shell/hud/hex_menu.gd` ("Tile details...", "Raise companies here..." opens the Army tab), `shell/input/bindings.gd` (labels "Previous tab", "Next tab"), `shell/input/map_input.gd` (Ctrl+[ and Ctrl+] to the window when no screen is up); edit `tests/shell/test_hex_menu.gd`, the bindings and input tests that pin the labels | Spec R21, R22: each menu item clicked reaches its target (P); Ctrl+] with the Study up does not move the window's tab (P); Tab with focus on the map is still Next unit (P); help lists the new labels |
| TW14 | M, Haiku | **Monkey and perf rows** | new `tests/shell/monkey_tile.gd` (extends `MonkeyFog`); edit `tests/shell/test_ui_monkey.gd` (extends it), `godot/tools/perf_core.gd` (`tile_view_ms`), `godot/tests/perf_core_budget.json`, new `godot/tools/ui/perf_ui_tile.gd` (`tile_window_open_ms`, `tile_tab_switch_ms`), `godot/tests/perf_ui_budget.json`, `tools/ui/perf_ui.gd` (calls the new file) | Spec 7.4 and 8: the monkey's invariants green on 3 seeds, one thin; its counters above 0; the rows within limits against TW1's baseline, both tables in the pull request |
| TW15 | M, Haiku (art director signs) | **Pictures, goldens, docs** | new `godot/tools/ui/shot_ui_tile.gd` (the scenes of spec 7.4); the regenerated scenes of `shot_ui.gd`, `shot_ui_m6.gd`, `shot_ui_fog.gd` that showed the panel; edit `README.md` (the tile window and its keys, plain words), `godot/README.md`, `CLAUDE.md` (the `HexPanel` mention becomes `TileWindow`), `docs/architecture/ui-and-controls-spec.md` (bindings rows), `docs/design/ui-family-audit.md` (status line: section 3 built) | Spec 7.4: **the owner is asked before the windowed run**; the pictures at both scales signed by the art director; every changed golden reviewed side by side; README matches spec 3.8 in plain words |

---

## 3. Tests that move

The full table is spec 7.2; by owner task:

- **Copied in group C, deleted in TW12:** `test_hex_panel.gd` (26 cases: works to `test_build_tab.gd`, the rest to
  `test_details_tab.gd` and `test_tile_window.gd`), `test_hex_panel_people.gd` (12, to `test_details_tab.gd`),
  `test_hex_panel_fog.gd` (2, to `test_details_tab.gd`; the fog cases also in `test_tile_fog.gd`), `test_raise_list.gd` (12,
  to `test_army_tab.gd`). While both exist (group C), the old file tests the old panel and the new one the new tab.
- **Edited:** `test_hex_menu.gd` (TW12 its cast, TW13 its items), `test_works_preview.gd`, `test_hud.gd`, `test_app.gd`,
  `test_app_flow.gd`, `test_app_flow_m6.gd`, `test_app_flow_m7.gd`, `test_army_toasts.gd`, `monkey_m6.gd`, `monkey_m7.gd`
  (TW12, names only); `test_ai_know.gd`, `test_military.gd`, `test_hex_card.gd` (TW1); `test_fog_exact.gd` (TW11).
- **Unchanged, must stay green:** `test_hex_war.gd` (`HexWar` is reused), every `core/` rule and AI test, `test_replay*.gd`,
  `test_save_file.gd`, `test_snapshot.gd`, `test_fog_views.gd`, the soak.

---

## 4. Monkey and performance

**Monkey (TW14).** `MonkeyTile` adds one step and one invariant set to the fog monkey (spec 7.4): clicks on random hexes of
each case, tab switches by click and by Ctrl+] / Ctrl+[, the menu's "Tile details..." and "Raise companies here...", a
raise when a row allows it. Counters `tile_opens`, `tile_tab_switches`, `tile_cases` must rise above 0 (at least three
cases a seed). The M6 hex menu counter stays.

**Perf.** TW1 records the baseline of the existing rows before anything moves; TW14 adds `tile_view_ms`,
`tile_window_open_ms`, `tile_tab_switch_ms` and runs every row after. A row more than 5 % slower than the baseline, or past
its limit, takes the spec's fallback (section 8: a two-step fill, Worth moved to Build) in TW14's pull request.

---

## 5. Reviews and the owner's playtest

- **The code reviewer** reads every task; for TW2 it diffs the moved functions line by line; for TW12 it checks the fold-in
  checklist against the files.
- **The technical director** signs spec sections 2, 3 and 4 before group A; reads TW3's probe output and picks the
  registry path; reads TW4's interface before it merges; reads TW11's twin test with TW4 together; reads TW12's checklist.
- **The art director** draws TW0 and signs TW15's pictures and goldens; **the creative director** reviews TW0 before the
  owner sees it.
- **The owner** approves TW0's mockup (it gates group C) and plays the checklist below.
- **Pull requests say what changes for the player:** TW12 replaces the hex panel with the window; TW13 adds the menu item
  and the tab keys; nothing else changes what the player sees until TW12.

**The owner's playtest** (Windows, fresh user folder):

1. New game, Italy 1480, play as Genoa. Click Genoa: the window opens on Build; the strip shows Details, Build, Army,
   Ships. Ships says ships come later.
2. Start a work on a district of yours: the job line shows it on every tab; Cancel works from any tab. Ctrl+] and Ctrl+[
   go through the tabs; Esc closes the window.
3. Army tab at Genoa: raise a company; hover a row for its card; the army appears under "Armies here"; Select selects it.
4. Click a Venetian town far away: owner, people, works and garrison exact; no army shown; no strip (Details only), with
   the Why not line.
5. Declare war on Milan (as Savoy in a new game), march next to a Milanese army: its tile shows "Enemy army here" and an
   Army tab with its men; a besieged castle out of sight shows "Besieged" and no besieger.
6. Click the sea; open the menu with a right click on your own town: "Tile details..." and "Raise companies here..." open
   the window on Details and Army; the works rows still start a work.
7. Look at TW15's signed pictures (deep fog shows only in the thin test fixture on north Italy).

---

## 6. Definition of done

1. The spec's done-when items 1 to 7 hold.
2. TW0 to TW15 merged; CI green with the nightly `perf_core` and `perf_ui` jobs within limits; the soak unchanged.
3. Issue 436 closed by TW15's pull request, with the approved mockup and the signed pictures linked.
4. The owner has played section 5.

---

## 7. Risks

| Risk | Where it shows | Answer |
|---|---|---|
| The swap breaks a caller nobody listed | TW12 | the grep of the done-when (no `HexPanel`, no `hex_panel(`); the monkey's existing seeds; the checklist |
| A copied test drifts from the old one while both exist | group C | the old tests stay untouched until TW12; the reviewer compares each copy with its source |
| The folder listing fails in the Windows build | TW3 | the probe runs on an exported build before anything uses it; the generator fallback keeps "add a file" |
| The mockup asks for something the spec forbids (a new widget, more tabs, a wider window) | TW0 | it comes back to the technical director before group C; the spec is edited first, then built |
| The fifth tab overflows at M9.5 | M9.5 | proved now by R23 with the fake label; the icon fallback is one file |
| Fog leaks through a tab that reads the game straight | later milestones | the door scan covers `core/views/tile_*.gd`; a tab's facts must come from a model there (spec 9) |
| Windowed runs needed for pictures | TW2 (pixel identity), TW15 | headless tests carry TW2; the pictures wait for the owner's go and run once in TW15 |
| Ctrl+[ and Ctrl+] clash with the Study | TW13 | the Study is a screen; the keys go to the window only with no screen up (pinned by a test) |

---

## 8. Defaults taken (none of them blocks the build; the owner may change any before group C)

| Default | Alternative |
|---|---|
| Ships tab on own port settlements only, one line | on every own tile, or every own settlement |
| The window opens on the last tab picked, else Build, else Details | always Details first |
| Tab keys Ctrl+] / Ctrl+[; arrows only with focus on the strip | Tab and the arrows always (they would stop panning the camera and stop Next unit while the window is open) |
| The menu gains "Tile details..." as its first item | no new item (a left click already opens the window) |
| Width stays 296 (the family's), the fifth label is "Industry" | a wider window for this panel only |
| The raise hover card is built now (audit U3) | later, with M9.5's arms line |
