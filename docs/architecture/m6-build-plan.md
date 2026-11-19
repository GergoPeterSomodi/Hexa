# M6 build plan: Armies

Game and systems designer (Opus), 2026-11-17. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/m6-build-spec.md` ("the spec").

**Starts after M5 is closed** (its plan's definition of done, the owner's playtest). M6 edits what M1.5 to M5 deliver:
`Game`, `Session`, `Events`, the action and season tables, `Country`, `Stats`, `StatsSystem`, `EconomySeason`, `Treasury`,
`Stores`, `People`, `Knowledge`, the previews, the report's view, the reminders, the log lines, the study's views and pages,
the map modes and overlay, the map scene, the floaters, the season flow, the chips, the hex and country panels, the top bar,
the input and the App. The standard's rule holds: the next milestone starts after the owner has played the last one.

**The M6 row of `ui-style-and-feedback-plan.md` S5** (the Military page; "What befell" with real `witnesses`; raised and
marched in "Your orders"; `REPLAY` before the report; the Supply mode) is folded in: the Military page is L12 and L21, the
witnesses L5, the report's lines L12 and L22, the replay L15, the Supply mode L11, L17 and L16.

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Definitions and state** | the kinds, the ground, the M6 numbers and reserves; `Army`, `Unit`, explored, two series; the bake's army pieces; the keys and settings | L1, L2, L14, L23 | 4 M |
| **The rules** | step costs and the path search; the armies' door, raising, disbanding, splitting, merging, refill; vision and witnesses; movement; supply | L3, L4, L5, L6, L7 | 4 L, 1 M |
| **The season** | the phases, upkeep, the army's food in the economy, stats, saves | L8 | 1 L |
| **Read models and proofs** | events and the log; the previews with armies; tokens, routes, supply bytes, cards; the random player, the properties, the core perf rows, the army report | L9, L10, L11, L13 | 2 L, 2 M |
| **Pieces and screens** | the report, reminders, Rankings and the Military view; the replay and the flow; the overlay's Supply mode; the army panel; the Raise tab and the hex menu; the move card | L12, L15, L17, L18, L19, L20 | 1 L, 4 M, 1 S |
| **The map and the pages** | tokens, the route, the reach, the cursor; the Military page, the Army chip; the report's Armies section | L16, L21, L22 | 1 L, 2 M |
| **Wiring and proof** | the App; monkey, pictures, the view and UI perf rows | L24, L25 | 1 L, 1 M |

**25 tasks: 10 L, 14 M, 1 S**, about 39.5 worker-days; about 20 working days end to end with the groups below (each group
takes as long as its longest task), plus reviews and the owner's playtest.

```
M5 closed (the owner's playtest)
  -> A:  L1  L2  L14  L23
  -> B:  L3 (L)  L4 (L)  L5
  -> C:  L6 (L)  L7 (L)
  -> D:  L8 (L)
  -> E:  L11 (L)  L13 (L)  L9  L10          (L13's army report: Opus's balance gate before F)
  -> F:  L12 (L)  L15  L17  L18  L19  L20
  -> G:  L16 (L)  L21  L22
  -> H:  L24 (L)
  -> I:  L25  -> the owner plays M6

Critical path: L1 -> L3 -> L6 -> L8 -> L11 -> L17 -> L16 -> L24 -> L25     (and L2 -> L4 -> L7 -> L8; L9 -> L12 -> L22 -> L24)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel and no two touch
one file.

---

## 2. Tasks

Who, per the standard's section 9 ("Opus (re-fit) / Sonnet (movement, supply), Haiku (panel)"): *Sonnet* builds systems,
views, tools and anything touching `Game`, saves, the season table, `Session`, `Events`, input, the map or the App; *Haiku*
builds data files, the bake's pieces, kit-based panels and pages from the spec's tables, and tests from a list; *Opus*
reviews the numbers and the words; *Fable* reviews interfaces. Generated files belong to the task that changes their source.
**Every task's done-when includes: lint (`python tools/lint_godot.py godot`), check_scripts and GUT green**, both UI
`--check`s (`bake_ui.py --check`, `build_theme.gd --check`), `build_map --check` and `build_scenario.gd --check`. Paths without
a prefix are under `godot/`; `tools/`, `tests/test_*.py`, `docs/` and `CLAUDE.md` are at the repository root.

### Group A (parallel)

| # | Size, who | Task | Files (new unless said) | Done when |
|---|---|---|---|---|
| L1 | M, Haiku (Opus reviews) | **The kinds, the ground and the M6 numbers** | `core/defs/unit_def.gd`, `core/defs/terrain_def.gd`; edit `core/defs/game_defs.gd`, `core/defs/family_def.gd` (`raise_cap`); `data/defs/units/{pikemen,crossbowmen,knights,bombards}.tres`, `data/defs/terrain/{farmland,grassland,woods,marsh,rock,snow,tundra,sand}.tres`; edit `data/defs/game_defs.tres`, `data/defs/families/settlements.tres`, `data/defs/goods/horses.tres`, `data/defs/goods/copper.tres`, `data/README.md`; `godot/tools/military_tables.gd`; `tests/core/test_unit_defs.gd`, `tests/core/test_terrain_defs.gd`; edit `tests/core/test_economy_defs.gd`, `test_family_defs.gd`, `test_good_defs.gd`, `test_economy_1480.gd` | Spec 4.2, 4.3 and 5.1 entered exactly; every planted fault of spec 9 for these tests; `military_tables.gd` prints the two tables; M4's 4.12 nets re-derived with the two reserves in `test_economy_1480.gd`, read by Opus on the task's first day |
| L2 | M, Sonnet | **Army and unit state** | `core/state/army.gd`, `core/state/unit.gd`; edit `core/state/country.gd` (`country/4`: `explored`), `core/state/stats.gd` (two series), `core/game/game.gd` (`armies`, `next_army_id`, `next_unit_id` only); `tests/core/test_army_state.gd`; edit `tests/core/test_country_state.gd`, `tests/core/test_stats.gd` | Spec 5.2: round trips, `digest_text` moves with every field, `mustering`, `country/3` refused, 42 series; the planted faults of spec 9 for these files |
| L14 | M, Haiku | **Bake slice 5: the army pieces, tokens, Theme icons** | `tools/ui_bake/pieces_m6.py`; edit `tools/bake_ui.py` (slice 5 in the catalogue), `godot/tools/build_theme.gd` (the `Kit` icons of spec 6.2), `shell/ui/tokens.gd` (`MAP_REACH`, `MAP_REACH_NEXT`, `MAP_PATH`, `MAP_PATH_WARN`, `MAP_PATH_INK`); re-made `assets/ui/kit/` and `shell/ui/theme.tres`; edit `tests/test_bake_ui.py`, `tests/shell/test_theme.gd`, `tests/shell/test_tokens.gd` | Spec 6.2's textures at 1x and 2x; the asserts of style spec 4.4; both `--check`s pass; the art director signs the token sheet (13 colours x 4 figures, the badge, the ring, the 16 icons) |
| L23 | M, Sonnet | **Keys, settings, input intents** | edit `shell/input/bindings.gd` (`view_mode_6`, `map_command_key`, the `GESTURES` line), `shell/app/settings.gd` (`map/sight_veil`, `state/map_mode` `supply`), `shell/input/map_input.gd` (`next_army_requested`, `continue_march_requested`, `cursor_moved(direction: int)`, `command_key_requested`; the key-6 mode is L16's); edit `tests/shell/test_bindings.gd`, `test_settings.gd`, `test_map_input.gd` | Spec 6.1: the M6 rows exist with `since: "6"`; Alt+arrows' column rule; no key fires while a `LineEdit` has focus; P: a bad `state/map_mode` value falls back |

### Group B (after A)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| L3 | L, Sonnet | **Step costs and the path search** | `core/systems/step_costs.gd`, `core/systems/path_search.gd`; `godot/tools/probes/probe_paths.gd` (the fake Europe: 200 routes, 20 cost fields, the step fill, printed); `tests/core/test_step_costs.gd`, `tests/core/test_path_search.gd` | Spec 4.3, 5.3 (`StepCosts`, `PathSearch`); every rule of 4.3 on the fixture map; the worked steps of 4.3 on north Italy; the lazy fill equals `compute` everywhere; the routes of 4.13 (b) to (d); the probe's numbers in the pull request on its first days (spec 10's first risk; a fallback of spec 8 applied when `route_ms` or `cost_field_ms` is over) |
| L4 | L, Sonnet | **The armies' door and Military** | `core/systems/armies.gd`, `core/systems/military.gd` (raise, disband, split, merge, `can_stand`, `refill`, names, upkeep, options); edit `core/game/actions.gd` (`raise`, `split_army`, `merge_armies`, `disband`), `core/systems/treasury.gd` (WHY, SPENDING), `core/systems/stores.gd` (FLOWS), `core/systems/people.gd` (FLOWS `foraged`); `tests/core/army_fixture.gd`, `tests/core/test_armies.gd`, `tests/core/test_military.gd`; edit `tests/core/test_treasury.gd`, `test_stores.gd`, `test_people.gd` | Spec 4.2, 4.5, 4.6, 4.9 (refill), 5.3 (`Armies`, `Military`); every row of the four check tables with its words (P each); raise's payments and levy order; the refund rule; the naming with ordinals; `refill` on a state the test builds |
| L5 | M, Sonnet | **Vision, explored, witnesses** | `core/systems/vision.gd`, `core/systems/sight_cache.gd`; edit `core/game/game.gd` (`sight`, `DOOR_FIELDS`, `emit`'s witnesses and forgets, `dev_transfer`'s refresh, `Vision.setup` in `new_scenario` and `with_state`), `core/views/knowledge.gd` (`knows`, `sees`, `armies_seen`), `core/views/words.gd` (`men`, `units`, `army_of`, `at`: spec 5.6); `tests/core/test_vision.gd`; edit `tests/core/test_knowledge.gd`, `tests/core/test_log_lines.gd`, `tests/core/test_season_summary.gd` (the M3 to M5 cases that took hex events as public), `tests/core/test_words.gd` | Spec 4.11 (sight, explored, witnesses), 5.3 (`Vision`); explored at the start equals M3's `knows` for every pair of the 1480 scenario; the tests build armies as state (L2's classes); P: a far country is not a witness; `Words.at` for a named hex, an unnamed one ("to (3, 8) near Hospice Mont Cenis") and one with no place within 2 hexes |

### Group C (after B)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| L6 | L, Sonnet | **Movement** | `core/systems/movement.gd`; edit `core/game/actions.gd` (`march`, `halt`, `continue_march`); `tests/core/test_movement.gd` | Spec 4.4, 4.7, 5.3 (`Movement`): every row of the three check tables (P each); `plan` with D20; `walk_plan`; the phase's legs, ticks, truncation, waits, re-plans, halts, `unit_moved` fields, `moved_from`, explored along a walk; `zoc_halts` with a registered hostility (P) |
| L7 | L, Sonnet | **Supply** | `core/systems/supply.gd`, `core/systems/supply_cache.gd`; edit `core/game/game.gd` (`supplies`, `DOOR_FIELDS`, `emit`'s forgets for supply); `tests/core/test_supply.gd` | Spec 4.8, 5.3 (`Supply`, `SupplyCache`): depots, the field on north Italy (the counts and lists of 4.8, summer and winter), `forage_cap`, the phase (food, foraging, hunger, events), `country_step` equal to the phase on 200 seeded states; `supply_cold_ms` and `supply_ms` timed on the fake Europe by a probe run (the numbers in the pull request) |

### Group D (after C)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| L8 | L, Sonnet | **The season, upkeep, stats, saves** | edit `core/game/season.gd` (`PHASES`), `core/game/game.gd` (the digest), `core/systems/economy_season.gd` (`upkeep_army` line, `needs_of.army_food`, the reserve), `core/systems/stats_system.gd` (spec 4.16), `core/game/snapshot.gd` (armies, `country/4`, the refresh), `core/game/save_file.gd` (`FORMAT` 4, `OLDEST_FORMAT` 4); `tests/core/test_army_savoy.gd`; edit `tests/core/test_season.gd`, `test_game_core.gd`, `test_economy_season.gd`, `test_stats.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_owns.gd`, `test_insights_views.gd` (the pins to M6's values) | **`PHASES` pinned as `[movement, supply, production, income, works, people, stats, calendar, ready_units, vision]`**; spec 4.13 (a) to (e) exactly (done-when 1 to 3); save, load, save byte-equal with armies, routes and explored; the OWNS table of 5.3 with its planted fault; `season_ms` timed on the fake Europe by a probe run (the number in the pull request) |

### Group E (after D)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| L9 | M, Sonnet (Opus reviews the words) | **Events, Session, the chronicle, the log, the words** | edit `shell/autoload/events.gd`, `shell/autoload/session.gd` (the drain, `last_phase_ms`), `core/state/chronicle.gd` (`NOTABLE`), `core/views/log_lines.gd`; edit `tests/shell/test_session.gd`, `tests/core/test_chronicle.gd`, `test_log_lines.gd` | Spec 4.11 (events, log lines), 5.5: the seven signals drained after their phases, then `chronicled`; the sentences for the player, a witnessed other and an unwitnessed one; still two autoloads |
| L10 | M, Sonnet | **The previews with armies** | edit `core/views/economy_preview.gd`; edit `tests/core/test_economy_preview.gd`, `tests/core/test_improve_preview.gd` | Spec D48: `with(..., 8)` equals eight played seasons for every country with holding armies (fed, foraging, starving); the 200-case property with holding armies; the marching case documented; `expected_ms` and `preview_ms` timed by a probe run (in the pull request) |
| L11 | L, Sonnet | **Read models: tokens, routes, supply, cards** | `core/views/army_view.gd`, `core/views/move_preview.gd`, `core/views/supply_view.gd`, `core/views/cards_military.gd`; edit `core/views/map_modes.gd` (`Mode.SUPPLY`, `MODE_KEYS`, the SUPPLY constants, `supply_bytes`, `supply_ramp`, `sight_bytes`, `legend(SUPPLY)`, `legend_title`, `colour_of`'s `supply_byte`, `modes`), `core/views/hex_card.gd`, `core/views/country_card.gd`; `tests/core/test_army_view.gd`, `test_move_preview.gd`, `test_supply_view.gd`, `test_cards_military.gd`; edit `tests/core/test_map_modes.gd`, `test_hex_card.gd`, `test_country_card.gd` | Spec 5.6 for these files, 6.6's bytes and colour distances; the fog (P: an unseen foreign army absent from the tokens; an unknown country's army row absent); the stops and crossings of 4.13 in `MovePreview.to` |
| L13 | L, Sonnet (Opus reads the report) | **The random player, the properties, the core perf rows, the army report** | `tests/core/random_player.gd`, `tests/core/test_men_property.gd`, `tests/core/test_check_contract.gd`; edit `tests/core/test_money_property.gd`, `test_people_property.gd`, `test_replay.gd`, `test_forty_seasons.gd`; edit `godot/tools/perf_fixture.gd` (`europe_armies`), `godot/tools/perf_core.gd` (rows `season_ms`, `movement_ms`, `supply_ms`, `supply_cold_ms`, `ready_units_ms`, `vision_ms`, `route_ms`, `cost_field_ms`, `step_fill_us`, `save_mb`), `godot/tests/perf_core_budget.json`; `godot/tools/army_report.gd`; edit `CLAUDE.md` (one line: the army report) | **Done-when 4 to 8** (with L8's save tests; the view rows are L25's); the rows printed and within their limits; the army report for seeds 1480 to 1484 in the pull request; **Opus reads it before group F** and any number change is a data edit with its tests in this pull request |

### Group F (after E)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| L12 | L, Sonnet (Opus reviews the words) | **The report, the reminders, Rankings, Standing, the Military view** | edit `core/views/season_summary.gd` (`armies`, orders, befell, glance, standing, quiet, `COVERED`), `core/views/reminders.gd` (four rules), `core/views/study_rankings.gd` (`army`); `core/views/study_military.gd`; edit `tests/fixtures/report_sample.gd` (the Armies section, real What befell and Your orders lines from a played fixture); `tests/core/test_study_military.gd`; edit `tests/core/test_season_summary.gd`, `test_reminders.gd`, `test_study_rankings.gd` | Spec 4.14, 4.15, 6.9's view: the sections exactly on the Savoy fixture; Rankings equals Standing every season of 40; the planted faults of spec 9 for these files; equal after a save and load |
| L15 | M, Sonnet | **The movement replay and the season flow** | `core/views/replay_plan.gd`, `shell/map/replay.gd`; edit `shell/app/season_flow.gd` (the callables, `REPLAY`, `replay_done`), `shell/map/floaters.gd` (`hold`); `tests/core/test_replay_plan.gd`, `tests/shell/test_move_replay.gd`; edit `tests/shell/test_season_flow.gd`, `test_floaters.gd` | Spec 6.4, D42: ticks played together, unseen steps instant, the cap and `MIN_STEP`; Space skips without a season; Instant and reduce motion skip; the report after `replay_done`; Save refused in `REPLAY`; ribbons held and released |
| L17 | M, Sonnet | **The overlay's Supply mode and the sight veil** | edit `shell/map/mode_overlay.gd`, `shell/map/mode_overlay.gdshader`, `shell/hud/mode_legend.gd`, `godot/tools/map/probe_mode_overlay.gd`; edit `tests/shell/test_mode_overlay.gd`, `test_mode_legend.gd` | Spec 6.6: the three textures, the uniforms, `update_supply` and `update_sight` writing only changed texels (P: one byte, one texel); the legend; the probe prints PASS on the runner and the owner's Mac, FAIL with `--plant` |
| L18 | M, Haiku | **The army panel; the country panel's row** | `shell/panels/army_panel.tscn`, `shell/panels/army_panel.gd`; edit `shell/panels/country_panel.tscn`, `shell/panels/country_panel.gd`; `tests/shell/test_army_panel.gd`; edit `tests/shell/test_country_panel.gd` | Spec 6.5 for every army state of its table and a foreign army; the buttons' verdicts and requests; the `Confirm` of a disband with no refund; the Under arms row (yours, known banded, unknown none) |
| L19 | M, Haiku | **The Raise tab and the hex menu** | `shell/panels/raise_list.tscn`, `shell/panels/raise_list.gd`, `shell/hud/hex_menu.gd`; edit `shell/panels/hex_panel.tscn`, `shell/panels/hex_panel.gd` (the Works/Raise segment); `tests/shell/test_raise_list.gd`, `tests/shell/test_hex_menu.gd`; edit `tests/shell/test_hex_panel.gd` | Spec 6.8: the head line, a row per kind with its cost text and verdict, a click raises; the menu's items, their disabled reasons, keyboard |
| L20 | S, Haiku | **The move card** | `shell/hud/move_card.tscn`, `shell/hud/move_card.gd`; `tests/shell/test_move_card.gd` | Spec 6.7: every kind of line, from previews that `MovePreview.to` builds on the Savoy fixture (`ArmyFixture.savoy`); a refusal's tone and way out |

### Group G (after F)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| L16 | L, Sonnet | **The map: tokens, route, reach, cursor, selection** | `shell/map/army_tokens.gd`, `shell/map/army_token.tscn`, `shell/map/army_token.gd`, `shell/map/path_marks.gd`; edit `shell/mapview/tile_map_view.gd` (the `reach`, `reach_next` overlays), `shell/map/map_scene.gd`, `shell/map/map_scene.tscn` (the nodes, `army_selected`, `army_cleared`, the cursor, the Supply and sight updates, the replay's poses), `shell/input/map_input.gd` (`view_mode_6`); `tests/shell/test_army_tokens.gd`, `tests/shell/test_path_marks.gd`; edit `tests/shell/test_map_scene.gd`, `test_layer_stack.gd`, `test_map_input.gd` | Spec 6.3, 6.6's map updates: tokens from `ArmyView` (P: an unseen foreign token not made), badges, the ring, the scale below zoom 0.6; selection by click, again and Shift+click; the reach layers; the route's stops and crossings; z 83, 84, 88; key 6; the art director signs tokens, reach and route on north Italy |
| L21 | M, Haiku | **The Military page, Rankings' fourth measure, the Army chip** | `shell/screens/study/page_military.tscn`, `shell/screens/study/page_military.gd`; edit `shell/screens/study_pages.gd` (`military` after `economy`), `shell/screens/study/page_rankings.gd`, `shell/hud/chips.tscn`, `shell/hud/chips.gd`; `tests/shell/test_page_military.gd`; edit `tests/shell/test_study.gd`, `test_page_rankings.gd`, `test_resource_chips.gd` | Spec 6.9 and 6.10 (chip, Rankings): the page from the played fixture, its tables and charts, Look there and Show on the map; five pages in the nav; the fourth measure on its row; the chip's card, click and narrowing order; the art director signs the page |
| L22 | M, Haiku | **The report's Armies section, the task flag, notifications** | edit `shell/screens/season_report.tscn`, `shell/screens/season_report.gd`, `shell/hud/task_flag.gd`, `shell/hud/notifications.gd`; edit `tests/shell/test_season_report.gd`, `test_task_flag.gd`, `test_notifications.gd` | Spec 6.10: the Armies section and its nav count drawn from `report_sample.gd`; links and buttons request `select_army` or `look_at`; the four reminders' lines and actions |

### Group H (after G)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| L24 | L, Sonnet | **Wire the App** | edit `shell/app/game_requests.gd` (spec 6.11's table: orders, the hex menu, Tab, R, the cursor, `select_army`, the replay's callables, the chip), `shell/app/app.gd` (the milestone `"6"`, `MoveReplay`, the flow; under 800 lines), `shell/app/study_warm.gd` (the Military view, the supply bytes), `shell/hud/hud.tscn`, `shell/hud/hud.gd` (the `MoveCard` slot, the `ArmyPanel` in the dock), `shell/hud/top_bar.gd` (the Supply segment and tooltip "Supply (6)", the chips' order), `shell/hud/layers_popover.tscn`, `shell/hud/layers_popover.gd` (the "Sight" switch on `map/sight_veil`), `shell/hud/dev_commands.gd` (`raise`, `march`, `hold`, `armies`, `as TAG`), `shell/hud/debug_overlay.gd` (the F3 line), `godot/README.md` (keys, the Raise tab, the orders, the console); edit `tests/shell/test_app_flow.gd`, `test_hud.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_study_warm.gd` | The flow test of spec 9 end to end; done-when 9 holds in the shell tests; the Layers popover's Sight switch and the Options entry change `map/sight_veil` both ways (`test_hud.gd`); the sandbox has no Raise tab, no Supply mode, no tokens, and refuses `raise` |

### Group I (after H)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| L25 | M, Haiku | **Monkey, pictures, the view and UI perf rows** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`, `godot/tools/perf_core.gd` (rows `reach_ms`, `tokens_ms`, `military_view_ms`, `supply_bytes_ms`, `summary_ms`), `godot/tests/perf_core_budget.json`, `tests/fixtures/ui_sample.gd` (an army sample); `tests/fixtures/mockup/report_m6.png` (the mockup's report at its "M6 armies" switch, with K4's command) and its line in `tests/fixtures/mockup/README.md`; the signed pictures as goldens (`godot/tests/goldens/m6_*.png`) | The monkey's new inputs and invariants green on 3 seeds; spec 9's pictures at 1280 x 720 scale 1 and 2560 x 1440 scale 2, signed; spec 8's UI rows and these view rows within their limits |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** signs `StepCosts`, `PathSearch`, `Armies` (the door), the movement phase's ticks and the
  season rows (spec 4.3, 4.4, 4.10, 5.3) before L3 and L4 start, and reads the interfaces of L2, L3, L4, L5, L6, L7, L8,
  L11, L15, L16 and L24 before they merge; the `OWNS` table of L8 with the doors of L4 and L5 together.
- **Opus** reviews L1's numbers on its first day (spec 4.2, 4.3, 5.1, the reserves' effect on M4's 4.12), L13's army
  report (seeds 1480 to 1484) before group F starts, the words of L9 and L12 against spec 4.11, 4.14 and 4.15, and L21's
  page. A changed number is a data edit with the tests it moves, in L13's pull request.
- **The art director** signs L14 (the token sheet), L16 (tokens, reach and route on north Italy at zoom 1 and 0.5), L17
  (the Supply colours, the stripes, the veil and the legend), L21 (the Military page; no mockup exists, it is built from
  `game-feedback-screens.md` C.2 and the M4.5 pages' kit) and L25's pictures.
- **Pull requests** say what changes for the player. L4, L6, L7 and L8 change behaviour on purpose (armies, the season's
  phases, upkeep, the reserves); L5 changes what "What befell" and the log show of others (witnesses from sight): said, with
  the M3 to M5 tests it moves. L2, L5 and L8 change `Game.digest()` (new fields): said; no test pins a digest value. L8
  makes M5 saves unloadable ("Made by an older test build"): said. L1 changes two goods' reserves: said, with M4's 4.12
  nets moved in its pull request.

---

## 4. The owner's playtest of M6

On Windows (mouse) and on the MacBook (trackpad), with a fresh user folder. New game, More, seed **1480**, Italy 1480, Play
as **Savoy**. The weather is drawn in your game; the men and the routes below do not depend on it.

1. The top bar shows an **Army** chip "0" after Food. Select Turin (5, 9): the hex panel has a "Works | Raise"
   switch. Raise: "Men at hand: 6,300 · 2 companies this season"; pikemen "25 · 1 iron", crossbowmen "30 · 1 iron · 1
   timber", knights and bombards each with their cost or a lock and its reason (no horses or no copper in store).
2. Raise pikemen twice: two toasts with the cost; a token on Turin reading "1.0k"; the Army chip 1,000; Ducats 1,450. A
   third: refused, "Turin (5, 9) has raised its 2 companies this season".
3. Click the token: the army panel "Army of Turin · 1,000 men · 2 of 8 companies here · Musters this season". The task
   flag: "1 army awaits orders". Press **Tab**: the same army is selected and the camera glides to it.
4. Hover Vercelli (6, 9): the route over the Po bridge, the move card "Musters first: marches from Summer 1480 · There in
   Autumn 1480 · Crosses the Po on the bridge at Vercelli". Right-click it: the toast; the flag empties.
5. **Space**: the report: Your orders "Raised 2 companies of pikemen at Turin (5, 9) (▼ −50)." and "Ordered to march...";
   Treasury "Raised: ... ▼ −50" and "Army upkeep, 1 army ▼ −12"; Armies "Men under arms 0 → 1,000". Close it.
6. **Space** again (End season of Summer): the replay: the token walks Turin to Vercelli over the bridge, then the report
   opens; its Armies: "Army of Turin: Turin (5, 9) → Vercelli (6, 9), 1,000 men." (Space during a replay ends it at once
   and opens the report.)
7. In Autumn, with the army selected, hover (3, 8) beyond the Little St Bernard: the route by Aosta's valley, two season
   stops, "Crosses the Little St Bernard pass: closed in winter". Right-click it. The task flag: "Winter closes the Little St
   Bernard...". End Autumn: the army stands on the saddle (3, 7). End Winter: the report and a notification, "The Army of Turin
   waits for spring at Hospice Little St Bernard (3, 7): the Little St Bernard is closed by snow." End Spring 1481: it
   has crossed to (3, 8).
8. Press **6**: the Supply mode, the legend top left: the Mont Cenis saddle (3, 9) striped madder (out of supply, starving),
   Turin and Vercelli deep blue (depots), the plain blue; other countries' land under the veil; the minimap the same. Press 1.
9. In Spring 1481, raise two more companies at Turin (a new army, the **Second Army of Turin**: the first is away); order
   them to the Mont Cenis (3, 9): the move card warns "Out of supply: the land feeds no one; about 100 men lost a season".
   Two seasons later (End Summer) the report: "Second Army of Turin at Hospice Mont Cenis (3, 9): 900 men ▼ −100, out of
   supply."; a notification; the ribbon "Hunger −100"; the task flag's serious line. End Winter: "−162". Order it back to
   Turin: it walks off the saddle even in winter (the edge to Susa is no pass edge).
10. **Alt/Option+arrows** with the army selected: the order cursor moves, the route follows; **O** orders the march there.
    Esc, then Alt+arrows move the selected hex; **O** opens the hex menu with the works and "Raise companies here...".
11. Right-click a hex with no army selected: the hex menu; a refused item shows its reason as a tooltip.
12. The army panel: tick one company, **Split off**: two armies on the hex (the token shows both in its hover card); **Join**
    them again. Raise one more and **Disband** it the same season: "+25 ducats back, 500 men home to Turin (5, 9)".
13. Halt a march (Hold); then **R**: "no march to continue". Order a march to a hex of Milan: refused, "not your land: the
    Duchy of Milan holds it, and your armies cross no border in peace."
14. **I**, then `]` to **Military**: your armies with their men, upkeep, supply and orders; the upkeep chart; the losses
    chart with the hunger; "No foreign army in sight." `]` to Rankings: a fourth list, **Men under arms**.
15. F2: `as MLO raise 9 9 pikemen 2`, then `as MLO march <its id> 7 9` (Alessandria, beside Vercelli). Two seasons on: a
    Milanese token "~1k" at Alessandria; its hover card "Milan: about 1,000 men"; the report's What befell "A Milanese army of
    about 1,000 men stands at Alessandria (7, 9)."; the Military page lists it. Shift the camera to Milan: no token there
    (out of your sight), and the land is lightly veiled.
16. Options, Game: Movement replay speed **Slow**, then **Instant** (no replay); Accessibility, Reduce motion: instant. Back
    to Normal.
17. F5, quit to desktop, Continue: the armies, their orders and routes, the Supply mode and J's report as before.
18. Map sandbox: no Raise tab, no tokens; 6 says "no countries on this map"; `raise 5 9 pikemen` says the sandbox has no
    armies.

---

## 5. Definition of done

1. The spec's "M6 is done when" items 1 to 10 hold.
2. Tasks L1 to L25 merged; CI green, with both UI `--check`s, `build_map --check`, `build_scenario.gd --check`, the probe and
   the nightly `perf_core` and `perf_ui` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac.
5. `godot-architecture.md` 9.2 marks M6 done; `godot/README.md` describes the M6 game.
6. Section 7 below is handed to the M7 and M8 build specs' authors.

---

## 6. How to start

On the day M5 closes:

1. Opus presents the armies (spec 4.2 to 4.9 and the worked examples of 4.13) to the owner and Fable in 30 minutes; a
   changed number is a data line now, not a task later. Fable signs `StepCosts`, `PathSearch`, the `Armies` door, the
   movement phase's ticks and the season rows (spec 4.3, 4.4, 4.10, 5.3) the same day.
2. Start group A together: **L2, L23** (Sonnet) and **L1, L14** (Haiku). Opus reads L1's numbers on its first day; the art
   director sees L14's figures on its second.
3. L3 starts when group A merges and runs its path probe on the fake Europe in its first days (spec 10's first risk), so a
   fallback is chosen before L6 builds the phase on it.
4. L7 times the supply fields cold on the fake Europe on its first day.
5. L13's army report goes to Opus the day it runs; group F waits for the balance verdict.

---

## 7. What M6 hands on

- **M7:** `Movement.hostile` (war), `Movement.open_to` (hostile land), `Movement.zoc_halts` (add castles), the movement
  phase's step into a hostile army (an attack; the `battles` phase after `movement`), `Military.stack_limit` (generals; per
  side on a battle hex), the battle hex rule (`Army.battle`, `army/2`), `Unit` morale and experience (`unit/2`), `UnitDef`'s
  combat numbers, castles as depots and garrisons, supply over controlled land, `unit_lost.why` `battle`, battle losses in
  `Stats.losses` and the Military page, the War filter for the army kinds. Taken up in `m7-build-spec.md` and
  `m7-build-plan.md` (battles never outlive their phase: `army/2` is the standing order; generals move to M11).
- **M8:** the seven army actions with their checks; `Knowledge.armies_seen`, `Knowledge.sees`, `ArmyView`, `MovePreview`,
  `Movement.plan`, `PathSearch.cost_field`, `Supply.field`, `SupplyView`, `Military.raise_options` and the reminders
  `army_idle`, `army_hungry`, `army_stores` as its views; `route_ms` and `cost_field_ms` as its budget rows; the scenario's
  starting armies; the chronicle's size with army events. Taken up in `m8-build-spec.md` (`cost_field` not used, D48; 1480's
  start armies empty, D30).
- **M9:** land that changes hands under an army re-plans or halts its march (D2); taken up in `m9-build-spec.md`, which adds no
  military access (`open_to` unchanged).
- **M10:** road works change `StepCosts` (it moves onto `Game`); markets may feed armies (taken up in `m10-build-spec.md`).
- **M11:** later kinds and refit; techs change move points, supply reach and costs through definitions only (taken up in
  `m11-build-spec.md` 4.10 and 4.14).
- **M12:** desertion through `Armies.lose_men` (`deserted`); bankruptcy disbands; score with men under arms (taken up in
  `m12-build-spec.md`).
- **Saves:** `SaveFile.FORMAT` 4; a new body field with a default needs no bump (M3 4.10).
