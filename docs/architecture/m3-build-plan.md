# M3 build plan: Time

Technical director (Fable), 2026-11-17. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/m3-build-spec.md` ("the spec").

**Starts after M2 is closed** (its plan's definition of done, the owner's playtest). M3 edits what M2 and M1.5 deliver:
`Game`, `Session`, `Events`, the action table, `MapState`, `Territory`, `Countries`, the hex panel, the top bar, the
HUD, the map scene, the menus and the options. The standard's rule holds: the next milestone starts after the owner has
played the last one.

**The UI tasks of `ui-style-and-feedback-plan.md` S2 are folded in with their IDs:**

| S2 task | Here | What changed |
|---|---|---|
| R1 (interfaces into the M3 spec) | **done** by the spec | its done-when holds: `version`, `emit`, `stats`, the events with `witnesses`, the `stats` row and `cancel_work` are in the spec with their owners |
| R2 `Knowledge` | R2, group A | `witnessed` takes the game (spec 1.2) |
| R3 bake slice 3, medallion | R3, group A | unchanged |
| R4 `DeltaChip` | R4, group A | unchanged |
| R5 `Stats` and the phase | R5, group B | **exists twice:** the S2 task edited `season.gd` to add the row; here Y1 writes the whole M3 table and R5 fills `stats_system.gd` (no edit of `season.gd` or `test_season.gd`); the chronicle is not in `Stats` (spec 1.2) |
| R6 Events and Session | R6, group B | **exists twice:** merged with the system work on `Session.end_season` (drain after each phase, `dev_transfer`, phase times) |
| R7 `SeasonSummary` and `Reminders` | R7, group D | adds `LogLines`; the shared `Words` helpers are Y7's |
| R8 `SeasonFlow` | R8, group E | **exists twice:** the S2 task also edited `app.gd`, `settings.gd`, `bindings.gd`; those edits belong to Y18 (the App) and Y3 (keys and settings) here |
| R9 date and End season | R9, group C | unchanged |
| R10 the report screen | R10, group E | adds the nine-section fixture; `screen_ids.gd` goes to Y18 |
| R11 monkey, pictures, perf | R11, group G | **exists twice:** merged with the M3 monkey, pictures and UI probe of every M3 screen |

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Time core** | calendar, the season table, the door's bookkeeping, works, stats, definitions | Y1, Y2, Y5, R5, R6 | 2 L, 2 M, 1 S |
| **Saves** | snapshot, save file, replay, Session saves, thumbnails, lock | Y6, Y8 | 1 L, 1 M |
| **Read models** | Knowledge, works view, words, log lines, reminders, the summary | R2, Y7, R7 | 1 L, 1 M, 1 S |
| **Kit and keys** | bake slice 3, medallion, `DeltaChip`, keys and settings, bookmarks | R3, R4, Y3, Y4 | 2 M, 2 S |
| **Screens and HUD** | date and End season, the flow, the report, the log, notifications, task flag, ribbons, the map's season and marks, hex panel, Save and Load, menus, console | R9, Y9, Y10, R8, R10, Y11, Y12, Y13, Y14, Y15, Y16 | 1 L, 9 M, 1 S |
| **Wiring and proof** | the App; the core speed tool and the 40-season rig; monkey, pictures, UI probe | Y18, Y17, R11 | 1 L, 2 M |

28 tasks: 6 L, 17 M, 5 S, about 35 worker-days; about 15 working days end to end with the groups below (each group
takes as long as its longest task), plus reviews and the owner's playtest.

```
M2 closed (the owner's playtest)
  -> A:  Y1 (L)  Y2  Y3  Y4  R2  R3  R4
  -> B:  Y5 (L)  R5  R6
  -> C:  Y6 (L)  Y7  R9
  -> D:  R7 (L)  Y9 (L)  Y8  Y10
  -> E:  R8  R10  Y11  Y12  Y13  Y14  Y15  Y16  Y17
  -> F:  Y18 (L)
  -> G:  R11  -> the owner plays M3

Critical path: Y1 -> Y5 -> Y6 -> R7 -> R8 -> Y18 -> R11   (and Y6 -> Y8 -> Y14 -> Y18)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel and no two
touch one file.

---

## 2. Tasks

Who, per the standard's section 9 ("Fable / Sonnet, Haiku (report, Save and Load screens)"): *Sonnet* builds systems,
tools and anything touching `Game`, saves, the season table, `Session`, `Events`, input or the App; *Haiku* builds
panels and screens from the spec's tables, data files, and tests from a list; *Opus* reviews the works numbers and the
report's words; *Fable* reviews interfaces. Generated files belong to the task that changes their source. **Every
task's done-when includes: lint (`python tools/lint_godot.py godot`), check_scripts and GUT green**, both UI `--check`s
(`bake_ui.py --check`, `build_theme.gd --check`) and `build_scenario.gd --check` (M2).

### Group A (parallel)

| # | Size, who | Task | Files (new unless said) | Done when |
|---|---|---|---|---|
| Y1 | L, Sonnet | **Calendar, the season table, the door's bookkeeping** | `core/systems/calendar.gd`, `core/state/chronicle.gd`, `core/state/luck.gd`, `core/game/view_cache.gd`, `core/game/season.gd`, `core/systems/works.gd` (`OWNS` and an empty `season()` only), `core/systems/stats_system.gd` (`OWNS` and an empty `season()` only); edit `core/game/game.gd` (spec 5.4 without `stats`: `start_year`, `turn`, `chronicle`, `action_log`, `luck`, `version`, `view_cache`, `emit`, the act record, `has_countries`, `date_text`, `dev_transfer`, `new_game`/`with_state` with defs, the digest), `core/systems/improve.gd`, `core/systems/territory.gd` (`owners_changed` with `tag` and `others`), `core/systems/countries.gd` (through `emit`), `shell/autoload/session.gd` (only: `new_game` passes `defs()`); `tests/core/test_calendar.gd`, `test_chronicle.gd`, `test_luck.gd`, `test_game_core.gd`, `test_season.gd`; edit `tests/core/test_territory.gd`, `test_countries.gd` (the event fields) | Spec 4.1, 4.2, 4.4, 4.5, 5.2 (Chronicle, Luck), 5.3 (Calendar), 5.4; `PHASES` pinned as `[works, stats, calendar]`; every case of those test files in spec 9; M1's and M2's tests stay green (an event now carries `turn`: a test that compares a whole event dictionary is edited in this task) |
| Y2 | S, Haiku (Opus reviews) | **Family definitions and the data** | `core/defs/family_def.gd`; edit `core/defs/game_defs.gd`, `core/defs/country_def.gd` (`ruler`); `godot/data/defs/families/{settlements,castles,wheat,hemp,silk,dyes,vineyard,olives,grazing,timber,mines,quarry,salt,harbour}.tres`; edit `godot/data/defs/game_defs.tres`, `godot/data/defs/countries/*.tres` (13), `godot/data/README.md`; `tests/core/test_family_defs.gd`; edit `tests/core/test_country_defs.gd` | Spec 4.3's duration table and slot numbers, 5.1, section 7 entered exactly; the planted faults of spec 9 |
| Y3 | M, Sonnet | **Keys, settings, input intents** | edit `shell/input/bindings.gd` (`game_undo_work`, `dev_console`), `shell/app/settings.gd` (`dev/save_json`, `state/log_open`, `state/log_filter`), `shell/input/map_input.gd` (`end_season_requested(echo)`, `report_requested`, `bookmark_requested(i, set)`, `undo_work_requested`), `shell/input/app_input.gd` (`quicksave_requested`, `quickload_requested`, `console_requested`); edit `tests/shell/test_bindings.gd`, `test_settings.gd`, `test_map_input.gd`; `tests/shell/test_app_input.gd` | Spec 6.1; no key fires while a `LineEdit` has focus; the M3 rows exist with `since: "3"` |
| Y4 | S, Haiku | **Camera bookmarks** | `shell/app/bookmarks.gd`, `tests/shell/test_bookmarks.gd` | Spec 6.12's class; set, get, round trip, bad entries dropped |
| R2 | S, Haiku | **`Knowledge`** | `core/views/knowledge.gd`, `tests/core/test_knowledge.gd` | Spec 4.7 and 5.6; the cases of spec 9 with the planted fault |
| R3 | M, Haiku | **Bake slice 3 and the medallion** | `tools/ui_bake/pieces_hud.py`; edit `tools/bake_ui.py` (slice 3 in the catalogue), `godot/tools/build_theme.gd` (`ButtonEndSeason`, `ButtonMedallion`, Kit icons `medallion_64`, `medallion_30`, `dial_quarters`, `dial_hand`, `hourglass`, `seal_good`, `seal_plain`, `seal_cracked`); re-made `godot/assets/ui/kit/` and `shell/ui/theme.tres`; `shell/ui/medallion.gd`, `tests/shell/test_medallion.gd`; edit `tests/test_bake_ui.py`, `tests/shell/test_theme.gd` | Style spec 4.5 slice 3 at 1x and 2x; busy turns the ring, or shows the hourglass under reduce motion; the art director signs the contact sheet |
| R4 | S, Haiku | **`DeltaChip`** | `shell/ui/delta_chip.gd`, `tests/shell/test_kit_feedback.gd` | Style spec 5: icon and sign in every state, on leather and on vellum |

### Group B (after A)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Y5 | L, Sonnet | **Works** | `core/state/work.gd`; edit `core/state/map_state.gd` (schema 3), fill `core/systems/works.gd`, edit `core/game/actions.gd` (`build`, `upgrade`, `clear`, `cancel_work` to `Works`); `tests/core/test_works.gd`; edit `tests/core/test_improve_actions.gd`, `tests/core/test_map_data.gd`, and the M1/M2 shell tests that expected an instant build: `tests/shell/test_map_scene.gd`, `tests/shell/test_hex_panel.gd` (a build, then `Season.run` until it stands) | Spec 4.3, 5.2 (Work, MapState), 5.3 (Works); every row of both check tables; the three examples of 4.3 (Spring 1481, Autumn 1481, Spring 1482); the 2,000-action property with 40 season ends |
| R5 | M, Sonnet | **`Stats` and the phase** | `core/state/stats.gd`, fill `core/systems/stats_system.gd`; edit `core/game/game.gd` (`stats`, `StatsSystem.setup` in `new_game` and `new_scenario`, the digest); `tests/core/test_stats.gd` | Spec 4.6, 5.2 (Stats), 5.3 (StatsSystem); ring, year rows, columns by name, save round trip, digest; the phase under 1 ms a country is measured by Y17 |
| R6 | M, Sonnet | **Session's season and the events** | edit `shell/autoload/session.gd` (`end_season_check`, `end_season`, `last_phase_ms`, `play_seconds`, `dev_transfer`, the drain of the new kinds and `chronicled`), `shell/autoload/events.gd` (five signals); edit `tests/shell/test_session.gd` | Spec 5.5 (all but the saves); `season_ended` once after the last drain; still two autoloads |

### Group C (after B)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Y6 | L, Sonnet | **Snapshot, save file, replay** | `core/game/snapshot.gd`, `core/game/save_file.gd`, `core/game/replay.gd`; `tests/core/test_snapshot.gd`, `test_save_file.gd`, `test_replay.gd`, `test_owns.gd` | Spec 4.10, 5.4 (Snapshot, SaveFile, Replay), 5.7; **save, load, save byte-equal**; every planted fault; the types probe on its first day (spec 10); the owner runs the GUT suite once on Windows (the rename sequence) |
| Y7 | M, Sonnet | **Works view, words, the hover card's line** | `core/views/works_view.gd`, `core/views/words.gd`; edit `core/views/hex_card.gd`; `tests/core/test_works_view.gd`, `test_words.gd`; edit `tests/core/test_hex_card.gd` | Spec 5.6 (WorksView, Words, HexCard); no engine calls (lint) |
| R9 | M, Haiku | **Date and End season** | `shell/hud/date_end.tscn`, `shell/hud/date_end.gd`, `tests/shell/test_date_end.gd` | Spec 6.2 against `play_m4.jpg`'s medallion and plate; the verdict during the pick |

### Group D (after C)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| R7 | L, Sonnet (Opus reviews the words) | **Log lines, reminders, the season summary** | `core/views/log_lines.gd`, `core/views/reminders.gd`, `core/views/season_summary.gd`; `tests/core/test_log_lines.gd`, `test_reminders.gd`, `test_season_summary.gd` | Spec 4.8, 4.9, 5.6; the M3 sections and words exactly; equal after a save and load; under 2 ms (Y17 measures) |
| Y8 | M, Sonnet | **Session's saves, thumbnails, the lock** | edit `shell/autoload/session.gd` (`save_game`, `autosave_game`, `load_game`, `loaded_ui`, `list_saves`, `newest_save`, `delete_save`, `current_slot`), `shell/app/shell_context.gd` (`saved`); `shell/app/thumbnail.gd`, `shell/app/run_lock.gd`, `godot/tools/ui/probe_capture.gd`; edit `tests/shell/test_session.gd`; `tests/shell/test_run_lock.gd` | Spec 4.10 (the Session side), 5.5, 6.15's two classes; the probe's PASS/FAIL from the owner's Mac and Windows in the pull request on its first day, with the fallback of spec 10 applied on a FAIL |
| Y9 | L, Sonnet | **The map: the calendar's season, the fade, work marks** | edit `shell/map/map_scene.gd`, `shell/map/map_scene.tscn` (`show_season`, `preview_season`, the `SeasonFade` and `WorkMarks` nodes; opens in the calendar's season); `shell/map/season_fade.gd`, `shell/map/work_marks.gd`; `tests/shell/test_work_marks.gd`; edit `tests/shell/test_map_scene.gd`, `tests/shell/test_layer_stack.gd` | Spec 6.9; z 87; the fade 0.4 s and instant under reduce motion (or the probe's fallback); the art director signs the marks and the fade on north Italy |
| Y10 | S, Haiku | **The hex panel's works** | edit `shell/panels/hex_panel.tscn`, `shell/panels/hex_panel.gd`, `tests/shell/test_hex_panel.gd` | Spec 6.8: the Work section, Cancel with its verdict, "4 seasons" on the buttons, a full slot's reason |

### Group E (after D)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| R8 | M, Sonnet | **`SeasonFlow`** | `shell/app/season_flow.gd`, `tests/shell/test_season_flow.gd` | Spec 6.3: the guard at 399 and 401 ms, echo refused, Full, Brief, Off, `show_season`, `autosave_due`, J at turn 1, `count` |
| R10 | M, Haiku | **The report screen** | `shell/screens/season_report.tscn`, `shell/screens/season_report.gd`, `tests/fixtures/report_sample.gd` (the nine sections of `game-feedback-screens.md` A.3 and a quiet season), `tests/shell/test_season_report.gd` | Spec 6.4 against `report_m4.jpg`; the fixture's nine sections drawn; links close and glide; the quiet state |
| Y11 | M, Haiku | **The action log** | `shell/hud/action_log.tscn`, `shell/hud/action_log.gd`, `shell/hud/log_feed.gd`; `tests/shell/test_action_log.gd`, `test_log_feed.gd` | Spec 6.5; `rebuild` equals the live lines; the newest header asks for the report |
| Y12 | M, Haiku | **Notifications and the task flag** | `shell/hud/notifications.tscn/.gd`, `shell/hud/task_flag.tscn/.gd`; `tests/shell/test_notifications.gd`, `test_task_flag.gd` | Spec 6.6 (notifications), 6.7 |
| Y13 | M, Haiku | **Floating ribbons** | `shell/map/floaters.gd`, `shell/map/floater.tscn`; `tests/shell/test_floaters.gd` | Spec 6.6 (ribbons): the motion, the caps (3 a hex, 16), none off screen, they wait under a modal, reduce motion |
| Y14 | M, Haiku | **Save and Load screen** | `shell/screens/save_load.tscn`, `shell/screens/save_load.gd`, `shell/screens/save_rows.gd`; `tests/shell/test_save_load.gd`, `test_save_rows.gd` | Spec 6.10: every state's row, the three `Confirm`s, keys, the name field, refresh on `saved` |
| Y15 | M, Haiku | **Menus and the Game page** | edit `shell/screens/main_menu.tscn/.gd` (Continue, Load game), `shell/screens/pause_menu.tscn/.gd` (Save, Load, subtitle, hints, Save's verdict), `shell/screens/options.gd` (the Game page from milestone 3); edit `tests/shell/test_main_menu.gd`, `test_pause_menu.gd`, `test_options.gd` | Spec 6.11, 6.14 against `menu.jpg` and `pause.jpg` with the M3 buttons |
| Y16 | M, Sonnet | **Developer console and F3** | `shell/hud/dev_console.tscn/.gd`, `shell/hud/dev_commands.gd`; edit `shell/hud/debug_overlay.tscn/.gd` (the M3 line, the Look control, the console's host); `tests/shell/test_dev_console.gd`, `test_dev_commands.gd`; edit `tests/shell/test_debug_overlay.gd` | Spec 6.13; every command and its planted faults |
| Y17 | M, Sonnet | **Core speed tool and the 40-season rig** | `godot/tools/perf_core.gd`, `godot/tests/perf_core_budget.json`, `tests/core/test_forty_seasons.gd`; edit `.github/workflows/godot.yml` (a nightly `perf_core` step), `CLAUDE.md` (one line in the Godot commands) | Spec 8's table printed and in the job summary, every row within its limit; spec 9's forty-season rig green |

### Group F (after E)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| Y18 | L, Sonnet | **Wire the App** | `shell/app/game_requests.gd` (spec 6.15: quicksave, quickload, save, load, continue, bookmarks, undo, the lock, recovery); edit `shell/app/app.gd` (the flow and its callables, the signal connections, the milestone value `"3"`; under 800 lines), `shell/hud/hud.tscn/.gd` (`DateEnd`, `ActionLog`, the `TopRight` column with `TaskFlag` and `Notifications`), `shell/hud/top_bar.tscn/.gd` (the date and End season, narrowing), `shell/hud/layers_popover.tscn/.gd` (the season buttons go), `shell/map/map_scene.tscn` (the `Floaters` node in `Names`), `shell/screens/screen_ids.gd` (`season_report`, `save_load`), `godot/README.md` (layout, keys, saves); edit `tests/shell/test_app_flow.gd`, `tests/shell/test_hud.gd` | The flow test of spec 9 end to end; done-when items 2, 3 and 4 of the spec hold in tests; the sandbox plays seasons too |

### Group G (after F)

| # | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| R11 | M, Haiku | **Monkey, pictures, UI probe** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`; the signed pictures as goldens (`godot/tests/goldens/m3_*.png`) | The monkey's new keys and invariants green on 3 seeds; the pictures of spec 9 at 1280 x 720 scale 1 and 2560 x 1440 scale 2; spec 8's UI rows within their limits |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** reads the interfaces of Y1, Y5, R5, R6, Y6, R7, R8, Y8 and Y18 before they merge, and
  the season table and `OWNS` of Y1 and Y5 together (the one place the order and the owners are written).
- **Opus** reviews Y2's numbers (durations, slots, rulers) against spec 4.3 and section 7, and R7's words against spec
  4.8 and 4.9, before they merge.
- **The art director** signs R3 (slice 3 sheet), R9 (date and End season), R10 (the report against `report_m4.jpg`),
  Y9 (marks and fade), Y11, Y12, Y13, Y14 and the pictures of R11.
- **Pull requests** say what changes for the player. Y5 changes behaviour on purpose (build, upgrade and clear begin a
  work): said in its pull request, with M1's and M2's tests edited in the same pull request. Y1, Y5 and R5 change
  `Game.digest()` (new fields): said; no test pins a digest value.

---

## 4. The owner's playtest of M3

On Windows (mouse) and on the MacBook (trackpad), with a fresh user folder:

1. Main menu: no Continue, no Load game. New game, Italy 1480, Play as Genoa. The top bar shows the medallion "1480"
   with the spring quarter lit and **End season** with a Space key cap. The map is in spring.
2. Select a Genoese wild hex: the build buttons say "4 seasons". Build something: a toast "Work begun: ... Ready
   Spring 1481. Ctrl+Z" (Cmd+Z on the Mac); an hourglass "0/4" stands on the hex; the hover card says "Work: ...".
3. Ctrl/Cmd+Z: "Work cancelled"; the mark goes. Build again. Begin a second work: allowed. A third: refused, "no free
   work slot: 2 of 2 in use"; the button shows the reason.
4. Select the second work's hex: "Work under way ... Cancel the work". Press it: the work and its mark go, and the
   slot is free again ("A work slot is free: 1 of 2 in use" on the task flag).
5. Press **Space**: the ring turns for a moment, the report opens: ribbon "Spring 1480", the seal "G", "The
   Chancellor's report to the Doge of Genoa. Summer 1480 begins.", At a glance (Works, Work slots, Land), Works (two
   begun), Your orders.
6. Press Space: the report closes. Press Space again at once: nothing happens. Then Space: the next season. Do it with
   a double tap: never two seasons.
7. Open the report with J, click a place name in it: it closes and the camera glides there. The date medallion and the
   log's newest header open it too.
8. The map changes to summer with a soft fade. Options, Graphics, Season change Instant: the next change is at once.
   Turn on Reduce motion: instant, and the ribbons fade in place.
9. In Summer 1480 begin a work at (9, 11) or (10, 12), Genoa's snow-climate woods (timber when the hex is wild, an
   upgrade when the search put a piece there). Play to Autumn: the report's "Before
   Winter" and the task flag say it stops until spring; set the report to Brief: the report still opens (a serious
   notice). In Winter it shows "stopped for the winter"; a 4-season work is ready in Autumn 1481, not Summer 1481.
10. Play to Spring 1481: the first work finishes; the report's Works says "Finished: ..."; after the report closes a
    "Finished" ribbon rises from the hex and a notification card waits top right; Go glides there.
11. Report on Off: a toast "Summer 1481 ended: ... J: the report" and no letter; J brings it. Back to Full.
12. The log bottom left: open it; filters All, Works, Mine; click a line: the camera glides. Esc closes it.
13. The task flag "1 thing to do" when a slot is free: click it, click the line: the camera goes to Genoa.
14. F5: "Saved: Quicksave." Pause menu, Save game: type a name, Save in Slot 1: a thumbnail. Save in Slot 1 again: it
    asks. Delete Slot 1 with Del: it asks.
15. Play past Winter 1481: "Autosaved."; the Load tab lists the autosave with its picture.
16. Note the date; quit to desktop; start again: **Continue** "Republic of Genoa · ..." is first and focused. Continue:
    the same date, works, marks and log; J shows the same report as before quitting.
17. Change something, press F9: it asks before losing it. Load an older slot from the pause menu: it asks.
18. Ctrl/Cmd+Shift+1 over Genoa: "Bookmark 1 set."; pan away; Ctrl/Cmd+1 glides back. Save, load: the bookmark is kept.
19. Force-quit the game after an autosave (Task Manager or Force Quit); start it: "Hexa did not close properly. Load the
    autosave from ...?" Load autosave.
20. F3: the turn, the phase times and the last save's time; the Look control previews winter, and the next season
    returns to the calendar. F2: `end 4` plays four seasons and shows the last report; `goto 15 8` glides to Verona;
    `give 9 9 GEN` gives Milan to Genoa: the borders move, the log and a notification say so, the next report's "What
    befell" and Land show it; `digest` prints.
21. Options: a **Game** page with Autosave, Season report and Task flag. The Layers popover has no season buttons.
22. Play on to **Winter 1489** (`end` in the console may help after Winter 1482): no error, the medallion reads 1489.
23. Map sandbox (developer tools): End season works, works take seasons with no slot limit, the report says "The
    sandbox of North Italy".

---

## 5. Definition of done

1. The spec's "M3 is done when" items 1 to 7 hold.
2. Tasks Y1 to Y18 and R2 to R11 merged; CI green, with both UI `--check`s, `build_scenario.gd --check`, and the nightly
   `perf_core` and `perf_ui` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac.
5. `godot-architecture.md` 9.2 marks M3 done; `godot/README.md` describes the M3 game.
6. Section 7 below is handed to the M4 build spec's author.

---

## 6. How to start

On the day M2 closes:

1. Fable presents the season table, the works rules (spec 4.2, 4.3) and the save format (4.10) to the owner and Opus in
   20 minutes; a change of a number is a data line now, not a task later.
2. Start group A together: **Y1, Y3** (Sonnet) and **Y2, Y4, R2, R3, R4** (Haiku). Fable reads Y1's `Game` and `Season`
   interfaces on its first day; Opus reads Y2's numbers on its first day.
3. Y5 starts as soon as group A merges; it is the milestone's longest step, so its worker reads spec 4.3 during group A.
4. Y8's capture probe goes to the owner's Mac and Windows on its first day (spec 10), so Y9's fade and the thumbnails
   know their fallback before they are built.

---

## 7. What M3 hands to M4

- **Money hooks:** `Work.paid` (set in `Works.build`, `upgrade`, `clear`), `Works.refund` and the one `Treasury.move`
  line in `cancel_work` (spec 4.3); `Treasury.close_ledger` in the `stats` phase; the `production`, `trade` and
  `income` rows between `works` and `stats` (spec 4.2).
- **The report:** `SeasonSummary`'s `treasury`, `goods` and `standing` sections, already drawn by the screen from
  `tests/fixtures/report_sample.gd`; `swing_permille`; "Open the study"; the money and food reminders; toasts of
  `goods_short` dropped while a season runs (`COVERED`).
- **Data:** `FamilyDef` gains costs, upkeep and output beside `work_seasons`; `GameDefs.goods` sets `Stats.goods`.
- **Luck:** weather from `game.luck.world` in the `calendar` phase.
- **Road works** (spec 1.2): `MapState` schema 4 with road and crossing per edge.
- **Caches:** `game.view_cache` for `ImprovePreview` (W5).
- **Saves:** `SaveFile.FORMAT` 1; a new body field with a default needs no bump (spec 4.10).
