# M3 build spec: Time

Technical director (Fable), 2026-11-17. **Status: a proposal, design only; it waits for the owner's go.** Builds milestone
M3 of `docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`), the M1.5 UI
foundation (`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`) and the M2 build spec and plan
(`m2-build-spec.md`, `m2-build-plan.md`). Where this page is more exact it wins for M3; section 1 lists every place
where it refines an earlier page. The tasks are in `m3-build-plan.md`. This page is task R1 of
`ui-style-and-feedback-plan.md` (S2): it carries `version`, `emit`, `stats`, the events with `witnesses`, the `stats`
row and `cancel_work`, each with its owner.

**What M3 is.** The game gets time. A season is a turn: End season (Space) runs one ordered table of phases, the date
moves from Spring 1480 on, and the map shows the calendar's season. Build, upgrade and clear stop being instant: each
**begins a work** that takes seasons and can be cancelled. Every season ends with the **Chancellor's report**, a vellum
letter of what happened. The game can be saved and loaded (a snapshot of plain values, not a pickle), with autosaves, a
quicksave, thumbnails, Continue on the main menu and recovery after a crash. The rules' events feed an action log,
notifications, toasts and rising ribbons. `Stats` keep 40 seasons of numbers per country, `Knowledge` is the one door to
other countries' facts, and `Reminders` say what is left to do. Camera bookmarks, a season fade, a developer console and
the Game options page complete the milestone.

**When it starts.** After M2 is closed (its plan's definition of done, and the owner has played it). M3 edits the
`Game`, `Session`, `Events`, the action table, `MapState` and the M2 systems' event calls, and builds its screens into
the M1.5 frame as M2 left it.

**M3 is done when:**

1. **40 seasons by hand.** A New game on "Italy, 1480" plays from Spring 1480 to Winter 1489 through End season with no
   error: the date medallion, the map's season and the report follow the calendar; every work begun finishes in the
   season `WorksView.ready_turn` gave when it began and shows on the map. `tests/core/test_forty_seasons.gd` plays the
   same 40 seasons headless with random works and checks the invariants of section 9 every season.
2. **Save, quit, load gives the same digest.** After a load `Game.digest()` equals the digest written in the save's
   header and the digest of the game that was saved; ten more seasons played from the loaded game give the same digest
   as ten seasons played without saving; save, load, save gives byte-equal files (with the clock fixed). The owner does
   it once by hand: save, quit the program, start it, Continue.
3. **Space, Space plays one season.** With the report on Full, the first Space ends the season and the second closes the
   report; with it on Off, the second Space inside 400 ms is refused (`test_season_flow.gd`, an injected clock: refused
   at 399 ms, accepted at 401 ms).
4. **Save, load, J shows the same report.** `SeasonSummary.of` gives an equal dictionary before the save and after the
   load (test), and the owner sees the same letter.
5. Every M3 UI row of the standard's 9.1 is in the game, built from the M1.5 kit, each with its GUT test: date and End
   season; the season report; the action log, notifications, toasts and floating ribbons; the task flag; Save and Load
   with thumbnails; quicksave and quickload; Continue and Load on the main menu; three rotating autosaves and recovery;
   camera bookmarks; the season fade option; the developer console; the Game options page. The season preview is gone
   from the Layers popover and lives only in F3.
6. On the made-up Europe (494 x 247 hexes) with the made-up 60-country scenario and 600 works, the CPU rows of section 8
   hold in the nightly `godot/tools/perf_core.gd` run (a season's phases under 100 ms, a save under 1 s, a load under
   2 s, a save file under 8 MB, `SeasonSummary.of` under 2 ms).
7. Lint, import, check_scripts and GUT are green, with both UI `--check`s and `build_scenario.gd --check`; the art
   director has signed the pictures of section 9; the owner has played the build through the plan's checklist.

---

## 1. What is there today, and where this page refines earlier pages

### 1.1 Read in the code (master `2765383`)

| Finding | Where | What it means for M3 |
|---|---|---|
| `Game` holds `map`, `state`, `seed_value`, `events` (an array of dictionaries), `improvement`; no turn, version, log or luck | `core/game/game.gd` | M3 adds the calendar, the door's bookkeeping, `stats`, `chronicle`, `luck` (5.4) |
| `Actions.pair_of` matches three names to `Improve.*_check` / `Improve.*`; no `Callable`s in a const (the M1 spec's `TABLE` const became a `match`) | `core/game/actions.gd` | The season table uses the same pattern: a const list of names and a `match` (5.4) |
| Build, upgrade and clear change `main_use` and `level` at once through `WorldImprove.build_on`, `upgrade`, `clear`; each queues `{kind: "hex_changed", hex}` | `core/systems/improve.gd`, `world_improve.gd` | The pairs stay as the **finishing** step of a work; the actions move to `Works` (4.3) |
| `ImproveRules.pair_reason(fa, la, fb, lb, radius)` and `hex_distance(a, b)` exist; `TOP_LEVEL` is 5 for settlements, 3 for every other family; 14 families (ids 1 to 14) | `core/systems/improve_rules.gd` | The rule "works under way count as finished" reuses them (4.3) |
| `MapState` schema `hexa-godot/map-state/1`, two byte arrays, base64 in `to_dict` | `core/state/map_state.gd` | M2 makes it schema 2 (`owner`); M3 makes it 3 (`works`) |
| `Rng` wraps one `RandomNumberGenerator` with `get_state`/`set_state`; one instance, no streams | `core/rng.gd` | M3 adds the three streams of standard 5.4 as `Luck` (4.10) |
| `Session`: `game`, `new_game`, `start_game`, `map_of`, `check`, `act`, `_drain` (hex_changed only); `Events`: `hex_changed`, `game_started` | `shell/autoload/` | M2 adds `drain()` public and two events; M3 adds the season, saves and five signals (5.5) |
| `Bindings.DEFAULTS` **already lists the M3 actions** with `since: "3"`: `game_end_season` (Space, Enter), `game_report` (J), `game_quicksave` (F5, Ctrl+S), `game_quickload` (F9, Ctrl+L), `cam_bookmark_go_1..9` (Ctrl+1..9), `cam_bookmark_set_1..9` (Ctrl+Shift+1..9) | `shell/input/bindings.gd` | M3 adds only `game_undo_work` and `dev_console` (6.1) |
| `Settings.SCHEMA` **already holds** `game/autosave` (`off`, `yearly`, `five_years`; `yearly`), `game/task_flag` (true), `game/season_report` (`full`, `brief`, `off`; `full`), `graphics/season_change` (`instant`, `fade`; `fade`), all `since: "3"` | `shell/app/settings.gd` | M3 adds `dev/save_json`, `state/log_open`, `state/log_filter` (6.1) |
| `ShellContext`: `settings`, `stack`, `toast_requested(text, tone)`, `app_requested(what, args)` | `shell/app/shell_context.gd` | M3 adds one signal, `saved` (6.10) |
| `EscLadder.decide` has the step `CLOSE_HUD_LIST` ("the task list, M3") | `shell/input/esc_ladder.gd` | The task list and the open log use it (6.5, 6.7) |
| `HexCard.of` gives `lines` of `[label, tone, value]`; `LEVEL_WORDS` (settlements, castles, harbour) and `STAGE_WORDS` name the levels | `core/views/hex_card.gd` | Work labels use these words; the card gains a "Work" line (6.8) |
| `MapScene.set_season(value: String)` swaps the TileSet by name; `TilesetBuilder.SEASONS` is `["spring", "summer", "autumn", "winter"]`; the scene opens in summer | `shell/map/map_scene.gd`, `shell/mapview/tileset_builder.gd` | The calendar's season index is the same order; the map opens in the calendar's season (6.9) |
| The lint forbids `OS`, `Time`, `Engine`, threads and the scene tree in `core/`, **not** `FileAccess`, `DirAccess`, `JSON` or `Marshalls` | `tools/lint_godot.py` `CORE_FORBIDDEN` | Save files are read and written in `core/game`; the wall clock and the thumbnail come from the shell (4.10) |
| No `FamilyDef`: build times exist nowhere (the improvement is instant) | `core/defs/` | M3 creates `FamilyDef` with the works numbers (4.3, 5.1) |
| The M1.5 frame (App, HUD, kit, `Screen`, `ScreenStack`, `Confirm`, `Loading`, `ToastHost`, `VellumSheet`, `NavList`, `Segmented`, `KitButton`, `CameraRig`, `AppInput`) is being built (U2, U3, U9 merged) | `ui-and-controls-plan.md`, `ui-style-and-feedback-plan.md` S1 | M3 names those pieces "(M1.5)" and starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M3 | Why |
|---|---|---|
| Standard 5.3, row 14: "Autosave" is a phase | **Not a phase.** The shell's `SeasonFlow` saves after the report closes (6.3). The table holds only rules that change the game | A save needs a thumbnail and the wall clock, both shell things, and it changes nothing in the game; the standard's table is edited (section 11) |
| Standard 5.3, row 12: "Calendar: next season, weather" (M3) | The calendar phase only advances the turn in M3. **Weather arrives with M4**, drawn from `Luck.world` in the same phase | Weather changes output, which is M4's; drawing it now would be luck with no effect |
| Standard 5.3: no `stats` row | `stats` sits after the scores (M12) and before the calendar; in M3 the table is **works, stats, calendar** | Style spec 6.2 |
| Style spec 6.1 and 6.2: notable events go to `stats.chronicle` through `StatsSystem.chronicle` | **`Chronicle` is its own state class on `Game`**, written only by `Game.emit` (the door, like `events` and `action_log`). `Stats` holds the rings and year rows only; `StatsSystem.chronicle` is dropped | Every system emits; a field written by all systems can have no system owner, so the OWNS test could not hold. The door owns it |
| Style spec 6.2: `SERIES` (35) with `districts_<family>` (16) | 35 series: the 19 named ones, `works_running`, `works_finished`, and `districts_<family>` for the **14** families of `ImproveRules` (4.6) | The game has 14 families; the art kit's 16 includes pieces that are not families |
| Style spec 6.4: M3's `before` rules are "a free work slot, winter closing passes and fields" | "A free work slot" (severity 1) and "**winter stops works in the snow**" (severity 2) | Passes and fields have no effect before M4 and M6; the winter rule of 4.3 is M3's only winter effect, and the report must not warn of nothing |
| Style spec 6.5: `witnessed(event, viewer)` | `witnessed(game, event, viewer)`: a public event (no witness list) is seen only by countries that know its actor | Until M6 every event is public; without this a far country would hear of every vineyard |
| Style spec 6.6: one `Events` signal per kind | One typed signal per kind **and** `Events.chronicled(entry)`, emitted for every notable event with its plain chronicle entry | The log, notifications and ribbons are built from chronicle entries after a load; one shape for live and loaded lines |
| Style spec 7.2: `core/game/view_cache.gd` arrives with M4 (W5) | It arrives in M3 (the report and the task flag cache by `game.version`); W5 uses it | The style spec already puts `view_cache` on `Game` in M3 |
| UI spec 7: "Undo the last build this season ... M4 (until then Clear undoes)"; style spec 7.4: Undo in the toast | `cancel_work` arrives in M3 (style spec section 1, refinement 6); the undo is **Ctrl/Cmd+Z** (`game_undo_work`) and the hex panel's "Cancel the work"; toasts are mouse-ignored, so the toast shows the key | A click cannot reach a toast (style spec 5) |
| UI spec 7: the developer console is "a `LineEdit` over the F3 panel" | It sits at the foot of the F3 panel; **F2** focuses it | The backtick is `dev_debug`, and Shift+backtick would also match it (Godot matches an action whose modifiers are a subset of the event's) |
| M1 spec 4: "from M3 the living [roads and crossings] are in `MapState`" | Road works arrive with **M10** (a road changes market reach, the works preview's "road to the market"; `m4-build-spec.md` 1.2 moved them from M4); M3 keeps the starting roads | M3's scope is district works; the M1 line is edited (section 11) |
| M2 spec 5.4: `Game.defs` is null in a map-only game | `defs` is set in **every** game from M3 (the sandbox needs the work times); `has_countries()` is `scenario != null` | One code path for works in the sandbox and in a scenario |
| UI spec 5.4: one "Autosave" slot | Three, `auto1` to `auto3`, the oldest written over; the Load tab lists them newest first | One bad season (a crash, a mistake) cannot cost the last good autosave |
| UI spec 7: the log's filters All, War, Money, Mine | **All, Works, Mine** in M3; Money arrives with M4 and War with M7 (hidden before, the UI spec's rule) | Works are M3's only kind; the History page (style spec 8) has the same five filters |
| UI spec 6.3: the season fade is "a `TextureRect` in the HUD" | A `CanvasLayer` at layer 9 in the map scene, under the HUD's 10 | The captured picture holds the HUD; under the live HUD it covers only the map, and it belongs to the map's season swap |
| UI spec 3.6: `Session.save(slot)`, `load(slot)` | `Session.save_game`, `load_game`, `autosave_game` | A method named `load` would hide GDScript's `load()` inside `session.gd`, which `map_of` uses |
| M2 spec 5.3 and 5.5: rules append to `game.events` | Rules call `game.emit(event)`; `owners_changed` gains `tag` (the new owner) and `others` (the old owners) | The chronicle and `Knowledge.witnessed` need the parties |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days).

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | The calendar | One turn is one season. Turn 1 is Spring of the scenario's `year` (1480; the sandbox 1480). Season `(turn − 1) mod 4`: Spring, Summer, Autumn, Winter; year `start_year + floor((turn − 1) / 4)` | v0.2.2's `data.date` exactly | S |
| D2 | The winter-year rule | **Winter belongs to the year in which it begins:** Winter 1480 is turn 4 (December 1480 to February 1481); the year number changes with Spring. A year's last row of history is its winter | v0.2.2's rule; the autosave and the year rows fall on the turn of the year | S |
| D3 | The end of the game | None in M3: the calendar runs on. M12 adds "the game is over" after Winter 1650 to `Season.end_check` | The score and the end are M12's | S |
| D4 | Weather | None in M3 (1.2) | No effect before M4 | none |
| D5 | The season table | `core/game/season.gd`: `PHASES` is a const list of names, `run_phase` a `match`; M3's rows **works, stats, calendar**; the full planned order is in 4.2; `test_season.gd` pins the names | Standard 5.3; actions already use a `match` | S a row |
| D6 | Who runs a season | `Session.end_season()` runs `Season.begin`, each phase with a `drain()` after it, `Season.finish`, then emits `season_ended(turn)`; tools, tests and the replay call `Season.run` (no drain). End season is **not** in the action table (it is no country's act) but is **recorded** in the action log | Standard 4.4: drained after each phase; the replay needs the season marks | S |
| D7 | Works take seasons | `build`, `upgrade` and `clear` keep their names and **begin a work**; the piece changes when the work finishes, in the `works` phase. The `Improve` pairs stay as the finishing step | The owner's growing map: "change over time"; v0.2.2's buildings took 4 seasons | L |
| D8 | How long | `FamilyDef.work_seasons` (4.3): a stage-1 district 4 seasons, stage 2 8, stage 3 16; a settlement to village 4, to town, walled town or city 8; any clear 1 | `06-growing-map.md` section 3 (stage 1 a year, 2 two years, 3 four years); the mockup's "8 seasons" for Genoa 4 → 5 | Data (S) |
| D9 | How many at once | **Work slots: 1 + one per settlement of level 4 or more** the country owns (`GameDefs.work_slots_base`, `work_slots_city_level`). Genoa 2, Milan 3, Venice 5, Lucca 1. A map-only game has no limit | `06-growing-map.md` section 3 ("1 work at a time plus 1 per city"); the mockup's "1 of 2 in use" for Genoa | Data (S) |
| D10 | Works per hex | One | One district, one main use, one job | S |
| D11 | Winter | **A work on a hex of snow climate makes no progress in winter** (`GameDefs.works_halt_in_snow_winter`, true). Its ready date moves by a season | Gives the calendar its first meaning; the map already knows the climate | Data (S) |
| D12 | Two works that would clash | A work may begin only if its target keeps every pair rule against the targets of the works under way within two hexes ("a work under way at (9, 11) would break it: ...") | No work can be blocked by another's finish; no finish order matters | M |
| D13 | A work that cannot finish | Checked again when it finishes; if its land was lost or a rule now refuses it, it is cancelled in the works phase (`why` `lost` or `blocked`, with the reason), with no refund | A guard, never expected; the M7 capture makes "lost" real | S |
| D14 | `cancel_work` | Any time while the work is under way, by its country. A **full refund in its first season** only: `Works.refund` returns `work.paid` then, else 0. M3 pays nothing (`paid` is 0); M4 adds the `Treasury.move` line in `cancel_work` | Style spec 7.4; cancelling later frees a slot, which is useful | S |
| D15 | Undo | Ctrl/Cmd+Z (`game_undo_work`): cancels the newest work the player began this season; the hex panel's "Cancel the work" | 1.2 | S |
| D16 | Where works live | `MapState.works` (an `Array[Work]` in id order) and `MapState.next_work_id`; schema `map-state/3` | Standard 4.3 ("plus works in progress"); style spec 7.3 #6 | M |
| D17 | Works numbers | `FamilyDef` (`core/defs/family_def.gd`), one `.tres` a family in `data/defs/families/`, listed by `GameDefs.families`; M4 adds costs, upkeep and output to it | Standard 4.1 names `FamilyDef`; no number in code | S |
| D18 | The report's address | `CountryDef.ruler` ("the Doge of Genoa"); the lede "The Chancellor's report to the Doge of Genoa. Summer 1480 begins." | The mockup's words | Data (S) |
| D19 | The event shape | A plain dictionary: `kind`, `turn` (set by `emit`), and as the kind needs `tag` (the actor), `hex`, `hexes`, `others` (other parties), `witnesses` (from M6; empty means public), `work`, `why`, `reason` | M1's and M2's events are dictionaries already | S |
| D20 | The chronicle | `Chronicle` on `Game`, written only by `Game.emit` for the kinds in `Chronicle.NOTABLE`; the newest 3,000 entries; saved; in the digest | 1.2 | M |
| D21 | Signals | One typed signal per kind, plus `Events.chronicled(entry)` for every notable one | 1.2 | S |
| D22 | The action log | `Game.action_log`: every accepted action `{turn, action, args}`, the season marks `{turn, action: "end_season"}` and developer transfers. Saved whole, **not** in the digest (it is a record, checked by the file round trip). M8 owns its size once the AI acts: if the save passes 8 MB, M8 keeps the log from the last autosave (settled by `m8-build-spec.md` D33: a save keeps the last 40 seasons of records, `log_from`; memory keeps all) | Standard 5.1: seed plus log replays a game | M |
| D23 | `Game.version` | Plus one for each accepted action and each season; not saved, not in the digest; every view cache lives in `game.view_cache` and keys on it | Style spec 6.1 | S |
| D24 | `Stats` series | 35 (4.6); values in M3: `land`, `districts_<family>`, `works_running`, `works_finished`; the rest zero until their systems | 1.2 | S |
| D25 | Stats without countries | A map-only game has one pseudo-country `""` counting the whole map | One code path; the sandbox's report works | S |
| D26 | Fog | `Knowledge` as style spec 6.5 with `witnessed(game, event, viewer)` (1.2); `knows` is a shared border (M2's `Territory.neighbours`) until M6 adds explored hexes; viewer `""` sees all | Style spec 6.5 | S |
| D27 | Reminders in M3 | `free_slot` (severity 1) and `winter_halt` (severity 2) (4.8) | 1.2 | S a rule |
| D28 | The report in M3 | Sections `glance`, `before`, `works`, `orders`, `befell` (4.9); the M4 to M12 sections are drawn by the same screen from a fixture | 9.1's M3 row ("the report's frame, What befell, Your orders"); M3 playable without them | none |
| D29 | The sandbox's report | It opens too, for the viewer `""`: seal "S", lede "The sandbox of North Italy, seed 1480. Summer 1480 begins." | The developer's map tool gets the same loop | S |
| D30 | The save file | Line 1 a JSON header; then the body: one dictionary of plain values and packed arrays, `var_to_bytes` (objects off), compressed with zstd (4.10) | Standard 5.5 | M |
| D31 | Old saves | `SaveFile.FORMAT` 1. Each bump adds an upgrade function; **until the first public release (M12) a bump may instead raise `OLDEST_FORMAT`** (older saves listed as "Made by an older test build"); from M12 every bump has an upgrade and CI loads saves kept from each release | Standard 5.5: saves may break before the first public release | S |
| D32 | Where the file code lives | `core/game/save_file.gd` and `snapshot.gd` (files under `user://` only); the wall clock, play time, build number and thumbnail come from the shell as arguments | The lint allows `FileAccess` in `core/`, not `Time` | S |
| D33 | Writing safely | Write `<slot>.sav.tmp`; rename the old `.sav` to `.sav.bak`; rename the tmp to `.sav`; delete the `.bak`. A read falls back to `.bak` | On Windows Godot's rename deletes the target first, so a plain rename-over is not atomic | S |
| D34 | Slots | `quick`, `1` to `8`, and three autosaves `auto1` to `auto3` (the oldest is written over); an optional name per save | UI spec 5.4; three autosaves so one bad season cannot cost everything | S |
| D35 | Autosave timing | After the report of a Winter closes (the save is at the start of Spring): every year (default), every fifth year (when `(year − start_year) mod 5 == 0`), or off (`game/autosave`) | v0.2.2 saved at the turn of the year (`turn % every == 1`) | S |
| D36 | Thumbnails | 192 x 108 PNG beside the save (`user://saves/<slot>.png`), taken from the viewport with the HUD and screens hidden for one frame; none when headless (a placeholder) | UI spec 5.4 | S |
| D37 | Recovery | `user://running.lock` while a game runs; at start, a lock left behind and an autosave newer than every other save ask "Load the autosave from Spring 1482?" | UI spec 5.5 | S |
| D38 | UI state in the save | The body's `ui` block: bookmarks, camera, map mode, look preview; not in the digest | UI spec 7: bookmarks "stored with the game" | S |
| D39 | The map's season | Follows the calendar; it changes after the report closes; the F3 panel's "Look" previews a season until the next season ends; the Layers popover loses its season buttons | UI spec 8; style spec section 1, refinement 10 | S |
| D40 | Season fade | `graphics/season_change` Fade: a capture of the screen on a layer under the HUD fades out over 0.4 s while the chunks swap; Instant under reduce motion | UI spec 6.3 | S |
| D41 | Notifications | Cards top right for your own finished or stopped works and your land gained or lost; four at most; a card lives until dismissed or until two seasons have ended | UI spec 7 | S |
| D42 | Floating ribbons | v0.2.2's numbers (1.1 s, 40 px rise, 0.3 s stagger, 3 a hex, 16 in all), in screen space; only hexes on screen | `hexa/campaign/hud/floating.py` | S |
| D43 | The log | Built from the chronicle (so it survives a load); filters All, Works, Mine in M3 (Money M4, War M7); the last 8 seasons (v0.2.2's two years); 60 lines a season | v0.2.2 `feed.py` | S |
| D44 | The sandbox | Has time and works (no slot limit, actor `""`), saves and the report | The developer tests M3 there | S |
| D45 | Luck | `Luck` (three `Rng` streams: world, ai, decor) on `Game`, seeded from the seed, saved and in the digest. **Nothing draws in M3**; M4 draws weather from `world` | Standard 5.4; the save format is complete from its first number | S |
| D46 | Land lost under a work | The work goes on until the next works phase, which cancels it (`lost`); `Territory.transfer` is unchanged | One place decides a work's end | S |
| D47 | Brief | Opens the report only for a serious notice (severity 2) or a swing over a tenth of the treasury (`swing_permille > 100`; always 0 before M4); otherwise the toast | Style spec 6.7 | none |
| D48 | Save while a season runs | Refused with "Wait for the season to end" while the flow is `RUNNING` (M6 adds `REPLAY`, M7 `DECISIONS`): Save greyed in the pause menu, F5 toasts. Allowed while the report is up. In M3 the season runs inside one call, so the refusal never shows; it is the rule for M8's sliced AI | UI spec 5.2 | none |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| One turn = one season; `date(turn) = SEASONS[(turn − 1) % 4] + START_YEAR + (turn − 1) // 4`; `END_YEAR` 1650 | `hexa/campaign/data.py` 11 to 17 | The rule and its words | The start year comes from the scenario; no end before M12 |
| `PHASES`: the one ordered table of (name, function) that `end_round` walks; `tests/test_season.py` pins the names; `advance_turn` moves the turn and closes and opens passes | `campaign/systems/season.py` | One table, pinned names, the turn step | Names and a `match` (GDScript consts hold no `Callable`); the table grows per milestone (4.2); passes close with M6 |
| `GameManager.end_season`: settle preview, AI, `end_round`, the orders hook, the autosave, markets, then `season_ended` on the bus | `campaign/game.py` | The order "rules, then autosave, then season_ended"; a manager without a window (`Session` and `Season`) | The autosave moves to the shell after the report (1.2); the bus is drained after each phase |
| Buildings: `BUILD_TURNS = 4`; `prov.queue` counts down in `economy.grow`; `building_done` when it reaches 0; "one job a season" (`busy`) | `data.py` 190, `systems/building.py`, `economy.py` 255 to 271 | A queue that counts down in a season phase; an event when done | Per family and stage (D8); slots per country instead of one job per province (D9); the winter rule (D11) |
| `saves.py`: one JSON header line, then a pickle; `VERSION` 2; slots 1 to 8, `quick`, `auto`; `.tmp` then `os.replace`; `listing()`, `latest()`, `describe()`; a load never crashes | `campaign/saves.py` | The header line, the slots, the write-then-replace, "never crash", the listing from headers | A snapshot of plain values instead of a pickle (standard 5.5); the header carries the digest; three autosaves; `.bak` for Windows |
| Autosave every year or five years (`AUTOSAVE_TURNS`), when `turn % every == 1` | `hexa/settings.py`, `game.py` | The options and the timing | Run by the shell after the report |
| `EventBus`: `emit` queues and keeps a history, `drain` hands out, taps never change the world, never saved | `hexa/events.py` | Events queue on the game and are drained; handlers never act; never saved | Typed signals per kind (standard 4.4); the notable ones are also kept, saved, in the chronicle |
| The feed: who hears what (a party, or the hex in sight); the log of 8 seasons, 60 lines each, filters, links; floating text | `campaign/feed.py`, `hud/actionlog.py`, `hud/floating.py` | Who hears what (`Knowledge.witnessed`), the bounds, the filters, the ribbon numbers | The log is rebuilt from the saved chronicle; v0.2.2's feed was lost on load |
| The task flag: `reminders.unfinished(world, tag)` lines with an action | `campaign/reminders.py`, `hud/tasks.py` | One function a rule, a line with a click action, cached per version | Severity per line; M3's two rules (4.8) |
| The resource `Tracker` keeps 12 seasons, **not saved** | `campaign/resources.py` | | `Stats` keep 40 seasons and a row a year, saved (style spec 6.2) |

---

## 4. Design content

### 4.1 The calendar

| Turn | Season (index) | Year | Text |
|---|---|---|---|
| 1 | Spring (0) | 1480 | Spring 1480 |
| 2 | Summer (1) | 1480 | Summer 1480 |
| 3 | Autumn (2) | 1480 | Autumn 1480 |
| 4 | Winter (3) | 1480 | Winter 1480 (December 1480 to February 1481) |
| 5 | Spring (0) | 1481 | Spring 1481 |
| 40 | Winter (3) | 1489 | Winter 1489 (the 40th season: done-when 1) |
| 681 | Spring (0) | 1650 | Spring 1650 (M12's last year begins) |

`season_of(turn) = posmod(turn − 1, 4)`; `year_of(turn, start) = start + floori((turn − 1) / 4.0)`;
`turn_of(season, year, start) = (year − start) * 4 + season + 1`. The `calendar` phase adds one to `game.turn` and
nothing else. "The season that ended" is always `game.turn − 1` after a season, and `season_ended(turn)` carries it.

### 4.2 The season table

`core/game/season.gd`. **M3's `PHASES`: `works`, `stats`, `calendar`.** The planned order of every milestone (standard
5.3 with the edits of section 11); a milestone adds its rows where they stand here and edits `test_season.gd`. (M4 moves
`works` after `income` and `debt`, so a work stands and produces from the season after it finishes: `m4-build-spec.md`
1.2 and 4.13 hold the order from M4 on.)

| # | Name | Arrives | Reads | Writes (through the owner) |
|---|---|---|---|---|
| 1 | `ai_orders` | M8 | everything through views | through `Game.act` only |
| 2 | `movement`, `battles` | M6, M7 | armies, map | armies, battles |
| 3 | `supply` | M6 | armies, owner | armies |
| 4 | `sieges` | M7 | armies, castles | owner (`Territory.transfer`), controller |
| 5 | `war_timeouts` | M9 | wars | wars |
| 6 | **`works`** | **M3** | `turn`, `map.climate`, `state.works`, `owner`, `defs.families` | `works`, `next_work_id` (`Works`); `main_use`, `level` (`Improve`, through `Improve.build`, `upgrade`, `clear`) |
| 7 | `production`, `trade` | M4, M10 | districts, markets, weather | stocks, prices |
| 8 | `income`, `debt` | M4, M12 | ledgers | treasury (`Treasury.move`) |
| 9 | `people` | M5 | food | people |
| 10 | `research` | M11 | research | techs |
| 11 | `extinction`, `scores` | M12 | countries | `alive`, score |
| 12 | **`stats`** | **M3** | `countries`, `owner`, `main_use`, `works`, the chronicle of `turn` | `stats` (`StatsSystem`); M4 adds `Treasury.close_ledger` here |
| 13 | **`calendar`** | **M3** | `turn` | `turn` (`Calendar`); M4 adds the weather draw from `luck.world` |
| 14 | `ready_units`, `vision` | M6 | armies | armies, explored |

The autosave is not a row: the shell saves after the report (6.3). `Season.end_check(game)` refuses, in order:

| Case | Verdict |
|---|---|
| The game has countries and no player | "choose your country first" (M2's words) |
| (M12) the calendar has passed Winter 1650 | "the game is over" |
| Otherwise | ok |

### 4.3 Works

**The actions** (`core/game/actions.gd` maps them to `Works`):

| Action | Args | Begins |
|---|---|---|
| `build` | `{hex, family, tag}` | a work to put `family` at level 1 on a wild hex |
| `upgrade` | `{hex, tag}` | a work to raise the hex's piece one level |
| `clear` | `{hex, tag}` | a work to take the piece off (the hex becomes wild) |
| `cancel_work` | `{hex, tag}` | (ends the work under way on the hex) |

**The checks.** `Works.build_check`, `upgrade_check` and `clear_check` refuse, in this order (the first refusal is the
verdict):

| # | Case | Verdict |
|---|---|---|
| 1 | No hex in the args (build: or no family) | M1's words: "no hex given", "no piece given" |
| 2 | `game.defs` is null | "no work data: this game has no definitions" |
| 3 | `Territory.at_home_check(game, tag, hex)` refuses (M2's home rule) | its reason ("not your land: the Duchy of Milan holds it", "choose your country first") |
| 4 | A work is under way on the hex | "a work is under way here: %s, ready %s" (its label, its ready date) |
| 5 | `Improve.build_check` / `upgrade_check` / `clear_check` refuses (the piece's rules of M1) | its reason, unchanged ("something already stands here", "a town needs its own countryside: ...") |
| 6 | The target breaks a pair rule against a work under way within two hexes | "a work under way at (%d, %d) would break it: %s" (that work's hex, the pair rule's reason) |
| 7 | The game has countries and the actor's works fill its slots | "no free work slot: %d of %d in use" |
| 8 | Otherwise | ok |

The home rule comes before the work under way, so another country's work is never named; the work under way comes
before the piece's rules, so an upgrade asked on a hex whose build is under way hears "a work is under way here" rather
than "nothing is built here". Row 6 uses `ImproveRules.pair_reason(f, l, w_family, w_level_to, hex_distance(hex, w.hex))` for every work `w` under way
with `w.hex != hex` and distance 1 or 2; a `clear` work has no target piece and never clashes. The target of the new work
is `(family, 1)` for build, `(f, level + 1)` for upgrade, nothing for clear.

`Works.cancel_work_check`:

| Case | Verdict |
|---|---|
| No hex given | "no hex given" |
| No work on the hex | "no work is under way here" |
| The work's `tag` is not the actor's | "not your work: the %s ordered it" (the long name) |
| Otherwise | ok |

**Beginning.** `Works.build` (and `upgrade`, `clear`) checks again and, when ok, appends a `Work` (id
`next_work_id`, then `next_work_id += 1`) with `started_turn = game.turn`, `seasons = seasons_left =
Works.seasons_for(...)`, `paid = 0`, and emits `work_started`. Nothing else changes: `main_use` and `level` stay.

**Durations** (`FamilyDef.work_seasons[level_to]`; a clear takes `FamilyDef.clear_seasons`):

| Family (key) | to 1 | to 2 | to 3 | to 4 | to 5 | Clear |
|---|---|---|---|---|---|---|
| `settlements` | 4 (never begun: places come from the map) | 4 | 8 | 8 | 8 | 1 (never allowed: places are not pulled down) |
| `castles` | 4 | 8 | 16 | | | 1 |
| `wheat`, `hemp`, `silk`, `dyes`, `vineyard`, `olives`, `grazing`, `timber`, `mines`, `quarry`, `salt`, `harbour` | 4 | 8 | 16 | | | 1 |

These are the design page's starting values, not estimates: they are data, the playtest's 40 seasons check that a work
of each length finishes in its season, and M4 sets costs beside them in the same files.

**Slots.** `Works.slots(game, tag) = defs.work_slots_base + (the settlements of tag with level >= defs.work_slots_city_level)`
(1 and 4); -1 (no limit) in a map-only game. On the 1480 scenario (M2 spec 4.2, "towns of which level 4+"):

| SAV | MLO | VEN | GEN | TUS | SWI | MAN | FER | SIE | LUC | PAP | FRA | AUS |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 3 | 5 | 2 | 3 | 1 | 1 | 2 | 1 | 1 | 2 | 1 | 1 |

A settlement upgraded to level 4 adds a slot from the season it stands.

**The works phase** (`Works.season(game)`), every work in id order:

1. **Lost:** in a game with countries, `Territory.at_home_check(game, work.tag, work.hex)` refuses: the work is
   removed and `work_cancelled` emitted with `why: &"lost"`, `reason` the check's words.
2. **Halted:** `Works.halted(game, work, game.turn)`: `defs.works_halt_in_snow_winter`, the season `game.turn` is
   Winter and `map.climate` of the hex is 0 (snow). Nothing changes; the work waits.
3. **Progress:** `seasons_left −= 1`. At 0 the piece is put through `Improve.build(game, {hex, family, tag})`,
   `Improve.upgrade(game, {hex, tag})` or `Improve.clear(game, {hex, tag})` (each checks the piece's rules again and
   emits `hex_changed`). Ok: the work is removed and `work_finished` emitted. Refused (never expected after row 6 of the
   checks): removed, `work_cancelled` with `why: &"blocked"` and the reason.

**When it stands.** A work begun in season T with n seasons and no halt finishes in the works phase of season T + n − 1
and stands from season T + n. `WorksView.ready_turn` walks the seasons from `game.turn`, skipping halted ones:

| Work | Begun | Seasons | Halts | Stands from |
|---|---|---|---|---|
| Vineyard, first stage, near Savona (7, 12), frost climate | Spring 1480 (1) | 4 | none | Spring 1481 (5) (the mockup's "ready Spring 1481") |
| Timber, first stage, near Milan (9, 11): Genoese woods at 1,488 m, snow climate | Summer 1480 (2) | 4 | Winter 1480 | Autumn 1481 (7), not Summer 1481 |
| Genoa (8, 13): walled town to city | Spring 1480 (1) | 8 | none (mild) | Spring 1482 (9) |

**Cancelling.** `Works.cancel_work` checks again, removes the work, computes `refund = Works.refund(game, work)`
(`work.paid` when `work.started_turn == game.turn`, else 0; always 0 in M3), and emits `work_cancelled` with
`why: &"order"` and `refund`. **The M4 hook:** M4 adds, in `cancel_work` after `refund`, one line
`Treasury.move(game, work.tag, refund, &"refund", work.hex)` and sets `paid` in `build`, `upgrade` and `clear`; nothing
else in M3's code changes for money. (`m4-build-spec.md` 4.11 refines it: works also cost goods, so `Work` gains
`paid_goods`, the refund has a second call, `Stores.move` per good, and the check table gains rows 8 and 9, money and
goods.)

### 4.4 Events and the chronicle

`Game.emit(event)` sets `event.turn = game.turn` when absent, appends the event to `game.events`, and, when its kind is
in `Chronicle.NOTABLE`, appends `Chronicle.plain(event)` to the chronicle. Rules never append to `game.events` directly
from M3 (M1's `Improve._changed`, M2's `Territory.transfer` and `Countries.choose` are edited to call `emit`).

| Kind | Fields (besides `kind`, `turn`) | Emitted by | Notable | Typed signal | Heard by |
|---|---|---|---|---|---|
| `hex_changed` | `hex` | `Improve` (M1) | no | `hex_changed(hex)` | map scene, hex panel, hover card |
| `owners_changed` | `hexes`, `tag` (new owner, `""` for no one), `others` (old owners, id order) | `Territory.transfer` (M2) | yes | `owners_changed(hexes)` | map (M2); log, notifications, ribbons (`chronicled`) |
| `country_chosen` | `tag` | `Countries.choose` (M2) | yes | `country_chosen(tag)` | App, top bar, map (M2); log |
| `work_started` | `tag`, `hex`, `work` (`Work.to_dict()`) | `Works.build`, `upgrade`, `clear` | yes | `work_started(tag, hex, work)` | work marks, hex panel, App (the toast), task flag; log, ribbons |
| `work_finished` | `tag`, `hex`, `work` | `Works.season` | yes | `work_finished(tag, hex, work)` | work marks, hex panel, task flag; log, notifications, ribbons |
| `work_cancelled` | `tag`, `hex`, `work`, `why` (`order`, `lost`, `blocked`), `reason`, `refund` | `Works.cancel_work`, `Works.season` | yes | `work_cancelled(tag, hex, work, why)` | work marks, hex panel, task flag; log, notifications, ribbons |
| (`season_ended`) | `turn` (the season that ended) | `Session`, after the last phase's drain; not a game event, never chronicled | | `season_ended(turn)` | `SeasonFlow`, date and End season, task flag, work marks, notifications, log, hex panel, F3 |

`witnesses` is absent on every M3 event (public); M6 fills it from vision. `Chronicle.plain` turns `StringName` into
`String` and arrays of tags into `PackedStringArray`, so an entry is equal after a round trip through bytes. The
chronicle keeps the newest **3,000** entries (style spec 6.2: about 0.3 MB on Europe).

### 4.5 The action log and the replay

`Game.act` appends `{turn, action, args: Chronicle.plain(args)}` to `game.action_log` when the verdict is ok, and adds
one to `game.version`. `Season.begin` appends `{turn, action: "end_season", args: {}}`. `Game.dev_transfer` appends
`{turn, action: "dev_transfer", args: {hexes, to_id}}`. `Replay.run` starts the same game (`Game.new_scenario` or
`Game.new_game` with the seed) and plays the records in order: `end_season` through `Season.run`, `dev_transfer`
through `Game.dev_transfer`, every other one through `Game.act`. Same seed and same log give the same digest (test).

### 4.6 Stats

Style spec 6.2, with the refinements of 1.2. `SERIES`, append-only, a column found by name:

```
treasury, income_people, income_goods, income_dues, income_trade, upkeep_districts, upkeep_walls, upkeep_army,
spending, people, food_made, food_eaten, land, army_men, losses, war_score, prestige, score, research,
works_running, works_finished,
districts_settlements, districts_castles, districts_wheat, districts_hemp, districts_silk, districts_dyes,
districts_vineyard, districts_olives, districts_grazing, districts_timber, districts_mines, districts_quarry,
districts_salt, districts_harbour
```

The `stats` phase writes, for every country in id order (the pseudo-country `""` in a map-only game), the row of the
season that is ending (`game.turn`, before the calendar moves it) at ring slot `turn mod 40`, and in Winter appends the
same row to `years`. M3's values: `land` (`Territory.count`; all land hexes for `""`), `districts_<f>` (the country's
hexes whose `main_use` is `f`), `works_running` (its works after the works phase), `works_finished` (its
`work_finished` entries of `turn` in the chronicle). Every other series is 0 until its milestone (M5 appends `people_towns`,
`people_grew`, `people_starved`, `people_left`, `food_need`: `m5-build-spec.md` 4.16). `goods_ring` has
`G = 0` goods until M4 (an empty array). Sizes on Europe with 60 countries: ring 0.34 MB, years 1.4 MB by 1650.

### 4.7 Knowledge

Style spec 6.5, with:

- `knows(game, viewer, other)`: true when `viewer == ""`, `other == ""`, `viewer == other`, or `other`'s id is in
  `Territory.neighbours(game, id_of(viewer))`; M6 adds "one of other's hexes explored".
- `witnessed(game, event, viewer)`: true when `viewer == ""`; or `viewer` is the event's `tag` or in its `others`; or
  the event has a non-empty `witnesses` list holding `viewer`; or it has none and `knows(game, viewer, event.tag)`.
- `band(n)`: two significant figures, half away from zero, sign kept: 87 → 87, 1,234 → 1,200, 1,250 → 1,300,
  −1,234 → −1,200, 99,960 → 100,000. `band_text(n, unit)`: "about 1,200 ducats" ("about 87" with no unit).

M3's readers: `LogLines` and `SeasonSummary` (`witnessed`); `known`, `unknown_count`, `band` and `band_text` are tested
in M3 and first read by M4's Standing section, M4.5's Rankings and M8's AI.

### 4.8 Reminders (the task flag and the report's notices)

`Reminders.unfinished(game, tag)` gives lines worst first (severity descending, then the order of `RULES`):

| Rule | When | Severity | Text | Action |
|---|---|---|---|---|
| `winter_halt` | the current season is Autumn and `tag` has works on snow-climate hexes | 2 (serious) | "Winter comes: 1 work in the snow stops until spring: timber, first stage, near Milan (9, 11)." (two or more: "2 works in the snow stop until spring: ..." with `Words.list`) | `[&"look_at", first hex]`, "Go to (9, 11)" |
| `free_slot` | a game with countries and `Works.in_use < Works.slots` for `tag` | 1 | "A work slot is free: 1 of 2 in use." | `[&"look_at", capital]`, "Show Genoa" |

Severity 0 is information (none in M3). `serious` is true when a line has severity 2. M4 adds the money and food rules.

### 4.9 The season report in M3

`SeasonSummary.of(game, tag, turn)` (style spec 6.4) for the season `turn` that ended. In M3:

| Field | Value |
|---|---|
| `title` | "Spring 1480" (the season that ended) |
| `next` | "Summer 1480" |
| `lede` | "The Chancellor's report to the Doge of Genoa. Summer 1480 begins." (`ruler`); sandbox: "The sandbox of North Italy, seed 1480. Summer 1480 begins."; quiet: "A quiet season." |
| `seal_letter` | the short name's first letter ("G"); sandbox "S" |
| `quiet` | nothing finished, begun or cancelled, no order, nothing befell, `land` unchanged |
| `serious` | a `before` line has severity 2 |
| `swing_permille` | 0 (M4: the treasury's change over the treasury) |
| `toast` | "Spring 1480 ended: 1 work finished. J: the report" (the first glance chip); quiet: "Spring 1480 ended: a quiet season. J: the report" |

**Sections in M3** (fixed order; a section with no line is left out, except `glance`, always there):

| Id | Title | Lines in M3 |
|---|---|---|
| `glance` | At a glance | Up to five chips: **Works** ("1 finished, 1 under way"; good when one finished); **Work slots** ("2 of 2 in use"; countries only); **Land** ("14 districts", with ▲ +n / ▼ −n against the season before when it changed; countries only) |
| `before` | Before Summer | the reminders (4.8), at most five, each with its button |
| `works` | Works | **Finished:** "Finished: vineyard, first stage, near Savona (7, 12)." (good); **Begun:** "Begun: timber, first stage, near Milan (9, 11). Ready Autumn 1481."; **Under way:** "Under way: walled town to city, Genoa (8, 13): 1 of 8 seasons. Ready Spring 1482." (warn and "stopped for the winter" when halted this season); **Cancelled:** "Cancelled: ..." with ", the land was lost." or ": <reason>." (bad) |
| `orders` | Your orders | from the action log of `turn`, one line per kind: "Ordered to build: vineyard near Savona (7, 12) and timber near Milan (9, 11).", "Ordered to upgrade: ...", "Ordered to clear: ...", "Cancelled: ...", "Took the rule of the Republic of Genoa." |
| `befell` | What befell Genoa (sandbox: "What befell the map") | witnessed events of others: "Milan finished a vineyard at (9, 11).", "The Duchy of Milan took 3 districts from the Republic of Venice: Bergamo (11, 8) and 2 more." |

`rank` in M3 is the work's `seasons` (orders and befell: 0); lines sort by rank, six show, `more` counts the rest; the
three largest of the report carry `top`. A line with a `hex` is a link. A quiet season shows `glance` with one line
("2 works under way; nothing else of note." or "No works under way."; scenario: the button "Show Genoa") and `before`.
**The sections M4 and later fill** (`treasury`, `goods`, `people`, `standing`) are drawn by the same screen from
`tests/fixtures/report_sample.gd` (the mockup's Genoa numbers of `game-feedback-screens.md` A.3), so M4 adds data,
not drawing.

### 4.10 Saves

**Files** in `user://saves/`: `<slot>.sav`, `<slot>.png` (thumbnail), and during a write `<slot>.sav.tmp` and
`<slot>.sav.bak`. Slots: `quick`, `1` to `8`, `auto1` to `auto3`.

**Line 1, the header** (JSON on one line, UTF-8, under 4 KB):

| Key | Example | From |
|---|---|---|
| `hexa` | `"save"` | constant |
| `format` | `1` | `SaveFile.FORMAT` |
| `build` | `"0.3.0"` | `application/config/version` (shell) |
| `slot`, `name` | `"3"`, `"Republic of Genoa, Spring 1482"` | the caller |
| `map_id`, `map_digest` | `"north_italy"`, sha256 | `MapData.digest()` |
| `scenario_id`, `scenario_digest` | `"north_italy_1480"` or `""` | `ScenarioDef.digest()` |
| `tag`, `country` | `"GEN"`, `"Republic of Genoa"` (`""`, `"Sandbox"` in a map-only game) | `Game.player`, `CountryDef.long_name` |
| `turn`, `date` | `9`, `"Spring 1482"` | `Calendar` |
| `saved_unix`, `play_seconds` | int, int | the shell's clock |
| `body_bytes`, `body_size`, `body_sha256` | compressed size, plain size, sha256 of the compressed bytes | `SaveFile.write` |
| `digest` | sha256 | `Game.digest()` at the save |

**The body** after the newline: `var_to_bytes(body).compress(FileAccess.COMPRESSION_ZSTD)`; a load decompresses with
`body_size` and refuses objects (`bytes_to_var`). What each piece contributes:

| Body key | From | Holds | In `Game.digest()` |
|---|---|---|---|
| `format` | `SaveFile.FORMAT` | 1 | no |
| `game` | `Game` | `map_id`, `scenario_id`, `seed`, `start_year`, `turn`, `player` | yes (each) |
| `map_state` | `MapState.to_dict()`, schema 3 | `main_use`, `level`, `owner` (M2's schema 2 field; base64), `works` (`Work.to_dict()` in id order), `next_work_id` | `MapState.digest()` |
| `countries` | `Country.to_dict()` in id order (M2 5.9) | `id`, `tag`, `capital`, `alive` | each `digest_text()` |
| `stats` | `Stats.to_dict()` | `series` names, `tags`, `count`, `last_turn`, `ring`, `years`, `goods`, `goods_ring` (packed) | `Stats.digest()` |
| `chronicle` | `Chronicle.to_dict()` | the entries | `Chronicle.digest()` |
| `luck` | `Luck.to_dict()` | the three stream states | `Luck.digest_text()` |
| `action_log` | `Game.action_log` | the records | no (D22) |
| `ui` | the shell | `bookmarks`, `camera` `{centre, zoom}`, `map_mode`, `look` | no |
| (not saved) | `Game.defs`, `scenario`, `map` | named by id and digest in the header and `game` | M2 5.9 |
| (not saved) | `events`, `version`, `view_cache`, `improvement` | rebuilt (`WorldImprove.over`) or empty | no |

`Game.digest()` after M3 is sha256 of `"map id|seed|scenario id or ''|player|start_year|turn|state.digest()|each
country's digest_text()|stats.digest()|chronicle.digest()|luck.digest_text()"`. Determinism: every stored amount is
an integer; lists are walked by id; `Chronicle.plain` and `Work.to_dict` store plain types; dictionary keys are written
in code order.

**Reading.** `SaveFile.read_header(slot)` gives `empty`, `ok`, `newer`, `older` or `broken`; `Session.list_saves()` turns
an `ok` into `other_map` or `other_build` when the header's map or scenario does not match this build (map digests
cached per map id):

| State | When | Row text |
|---|---|---|
| `empty` | no `.sav` and no `.bak` | "Empty slot" |
| `ok` | the header parses, `OLDEST_FORMAT <= format <= FORMAT` | the country and date |
| `newer` | `format > FORMAT` | "Made by a newer Hexa" (greyed) |
| `older` | `format < OLDEST_FORMAT` | "Made by an older test build" (greyed) |
| `other_map` | the map id is unknown here, or its digest differs | "Made for another map" (greyed) |
| `other_build` | the scenario id is unknown, or its digest differs (M2 5.9) | "Made by another build" (greyed) |
| `broken` | the header does not parse | "Cannot be read" (greyed) |

A load also refuses (state `broken`, "Cannot be read") when the body's sha256, size or types are wrong, and
"The save is damaged" when the loaded game's digest differs from the header's. A load never crashes: every value of the
body is type-checked by `Snapshot.restore` before use.

**Writing** (D33): make `user://saves/`; write `<slot>.sav.tmp` and close it; if `<slot>.sav` exists, delete an old
`.bak` and rename `.sav` to `.sav.bak`; rename `.tmp` to `.sav`; delete `.bak`. Any failure deletes the `.tmp` and
returns the problem ("permission denied", "no space left on the disk", "the save could not be written"); the old save
stays in `.sav` or `.bak`. `read_header` and `read` use `.bak` when `.sav` is missing or broken. With `dev/save_json`
on, `<slot>.body.json` is also written (`JSON.stringify(body, "  ")`) for reading by a developer; it is never read
back.

**Autosave** (D35): `SeasonFlow.autosave_due(turn, start_year, every)` is true when the season that begins is Spring and
`every` is `yearly`, or Spring of a year with `(year − start_year) mod 5 == 0` and `every` is `five_years`. The slot
written is the first empty of `auto1..auto3`, else the one with the oldest `saved_unix`.

**Recovery** (UI spec 5.5): the App writes `user://running.lock` (`{started_unix, map_id}`) when a game starts and
deletes it on the main menu and at a clean quit. At start, when the lock is there and the newest autosave's `saved_unix`
is newer than every other save's, a `Confirm` asks "Hexa did not close properly. Load the autosave from Spring 1482?"
with **Load autosave** and **Not now** (focused, Esc). Either way the lock is deleted.

**Migration rule** (D31): `SaveFile.FORMAT` is 1 and `OLDEST_FORMAT` 1. A change to the body that an old save cannot
meet with defaults bumps `FORMAT` in the same pull request with either an upgrade function `_upgrade_<n>(body) ->
Dictionary` (format n to n + 1) in `save_file.gd`, run in order on load, or, before M12, `OLDEST_FORMAT` raised to the
new number. A new field with a default needs no bump: each `from_dict` fills it (style spec: "a later series loads as
zeros"). Each state class keeps its own schema string (`map-state/3`, `work/1`, `country/1`, `stats/1`, `chronicle/1`,
`luck/1`) and reads its older schemas.

---

## 5. Interfaces

Layers as the standard: `defs`, `state`, `systems`, `game`, `views`, `shell`. `core/` makes no engine calls; it takes no
luck in M3. New files are marked **new**; "(M2)" and "(M1.5)" name pieces those milestones build.

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/family_def.gd  (new): the works numbers of one family; M4 adds costs, upkeep and output
class_name FamilyDef extends Resource
@export var id: int                          # ImproveRules family id, 1 to 14
@export var key: StringName                  # ImproveRules.NAMES[id]: &"vineyard"
@export var work_seasons: PackedInt32Array   # index = the level a work reaches; [0] = 0; size TOP_LEVEL[id] + 1
@export var clear_seasons: int = 1
func validate() -> Array[String]             # key matches the id; size TOP_LEVEL[id] + 1; [0] is 0; levels 1 up and
	# clear_seasons each 1 to 64

# core/defs/game_defs.gd  (M2, edit)
@export var families: Array[FamilyDef] = []        # 14, external files
@export var work_slots_base := 1
@export var work_slots_city_level := 4
@export var works_halt_in_snow_winter := true
func family(id: int) -> FamilyDef                  # null when unknown
# validate() adds: 14 families with ids 1 to 14 once each; each family's validate(); work_slots_base >= 1;
# work_slots_city_level 1 to 5

# core/defs/country_def.gd  (M2, edit)
@export var ruler: String                          # "the Doge of Genoa"; validate(): not empty
```

### 5.2 State (`core/state/`)

```gdscript
# core/state/work.gd  (new)
class_name Work extends RefCounted
const SCHEMA := "hexa-godot/work/1"
var id: int
var tag: StringName              # the actor; &"" in a map-only game
var hex: Vector2i
var action: StringName           # &"build", &"upgrade", &"clear"
var family: int                  # build: the family; upgrade, clear: the hex's family when begun
var level_to: int                # build 1; upgrade level + 1; clear 0
var started_turn: int
var seasons: int
var seasons_left: int
var paid: int = 0                # ducats paid; 0 until M4
func to_dict() -> Dictionary     # plain: tag and action as String
static func from_dict(d: Dictionary) -> Work          # null on a wrong schema, a missing or mistyped field
func digest_text() -> String     # "id|tag|c,r|action|family|level_to|started_turn|seasons|seasons_left|paid"

# core/state/map_state.gd  (M1, M2; edit)
const SCHEMA := "hexa-godot/map-state/3"  # 2 loads with no works; 1 loads with owner zeros and no works
var works: Array[Work] = []               # in id order; written only by Works
var next_work_id: int = 1
func work_at(hex: Vector2i) -> Work       # null when none
# duplicate_state() copies the works (new Work objects); to_dict() adds "works" and "next_work_id";
# digest() adds each work's digest_text() and next_work_id

# core/state/chronicle.gd  (new)
class_name Chronicle extends RefCounted
const SCHEMA := "hexa-godot/chronicle/1"
const KEEP := 3000
const NOTABLE: Array[String] = ["work_started", "work_finished", "work_cancelled", "owners_changed", "country_chosen"]
var entries: Array[Dictionary] = []       # oldest first
static func plain(event: Dictionary) -> Dictionary    # deep copy; StringName -> String; tag arrays -> PackedStringArray
func add(event: Dictionary) -> void       # appends plain(event); drops the oldest past KEEP
func of_turn(turn: int) -> Array[Dictionary]          # scans from the newest
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> Chronicle     # null on a wrong schema
func digest() -> String                   # sha256 of var_to_bytes(entries)

# core/state/luck.gd  (new): standard 5.4's three streams
class_name Luck extends RefCounted
const SCHEMA := "hexa-godot/luck/1"
var world := Rng.new()                    # rules (weather from M4, battles M7)
var ai := Rng.new()                       # the AI (M8)
var decor := Rng.new()                    # looks only
static func seeded(seed_value: int) -> Luck   # world: seed; ai: seed ^ 0x5bd1e995; decor: seed ^ 0x27d4eb2f
func to_dict() -> Dictionary              # {schema, world, ai, decor}: get_state() of each
static func from_dict(d: Dictionary, seed_value: int) -> Luck     # missing or wrong: seeded(seed_value)
func digest_text() -> String              # "world|ai|decor" states

# core/state/stats.gd  (new): style spec 6.2 without the chronicle
class_name Stats extends RefCounted
const SCHEMA := "hexa-godot/stats/1"
const RING := 40
const SERIES: Array[String] = [...]       # the 35 of 4.6, append-only
var tags: PackedStringArray               # id order; [""] in a map-only game
var count: int                            # rows written
var last_turn: int                        # the newest row's turn; 0 none
var ring: PackedInt32Array                # [(c * RING + turn % RING) * S + s]
var years: PackedInt32Array               # [(y * C + c) * S + s], y = year - start_year, one block each Winter
var goods: int                            # G; 0 until M4
var goods_ring: PackedInt32Array          # [((c * RING + turn % RING) * G + g) * 3 + (made, used, stock)]
static func create(p_tags: PackedStringArray, p_goods: int) -> Stats
static func column(name: String) -> int   # -1 unknown
func row(tag: StringName, turn: int) -> PackedInt32Array      # empty: not written or out of the ring
func value(tag: StringName, turn: int, name: String) -> int    # 0 when absent
func series(tag: StringName, name: String, span: int) -> PackedInt32Array   # newest last, span <= RING
func year_row(tag: StringName, year_index: int) -> PackedInt32Array
func to_dict() -> Dictionary              # includes the series names, so columns are matched by name on load
static func from_dict(d: Dictionary) -> Stats   # a series missing in d is zeros; an unknown one is dropped
func digest() -> String
```

### 5.3 Systems (`core/systems/`)

```gdscript
# core/systems/calendar.gd  (new)
class_name Calendar extends RefCounted
const OWNS: Array[String] = ["turn"]
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const SPRING := 0
const SUMMER := 1
const AUTUMN := 2
const WINTER := 3
const FIRST_TURN := 1
const DEFAULT_YEAR := 1480
static func season_of(turn: int) -> int
static func year_of(turn: int, start_year: int) -> int
static func turn_of(season: int, year: int, start_year: int) -> int
static func date_text(turn: int, start_year: int) -> String        # "Winter 1480"
static func season_name(turn: int) -> String                        # "Winter"
static func is_winter(turn: int) -> bool
static func season(game: Game) -> void                              # the phase: game.turn += 1

# core/systems/works.gd  (new; created by task Y1 with OWNS and an empty season(), filled by Y5)
class_name Works extends RefCounted
const OWNS: Array[String] = ["works", "next_work_id"]
static func build_check(game: Game, args: Dictionary) -> Dictionary     # 4.3; args {hex, family, tag}
static func build(game: Game, args: Dictionary) -> Dictionary           # begins the work; emits work_started
static func upgrade_check(game: Game, args: Dictionary) -> Dictionary   # {hex, tag}
static func upgrade(game: Game, args: Dictionary) -> Dictionary
static func clear_check(game: Game, args: Dictionary) -> Dictionary     # {hex, tag}
static func clear(game: Game, args: Dictionary) -> Dictionary
static func cancel_work_check(game: Game, args: Dictionary) -> Dictionary   # {hex, tag}
static func cancel_work(game: Game, args: Dictionary) -> Dictionary     # emits work_cancelled (why order, refund)
static func season(game: Game) -> void                                  # the works phase (4.3)
static func seasons_for(game: Game, action: StringName, family: int, level_to: int) -> int
static func slots(game: Game, tag: StringName) -> int                   # -1: no limit (a map-only game)
static func in_use(game: Game, tag: StringName) -> int
static func halted(game: Game, work: Work, turn: int) -> bool           # the winter rule
static func pending_conflict(game: Game, hex: Vector2i, family: int, level_value: int) -> String   # "" or the words
static func refund(game: Game, work: Work) -> int                       # the M4 hook (4.3)

# core/systems/stats_system.gd  (new; created by Y1 with OWNS and an empty season(), filled by R5)
class_name StatsSystem extends RefCounted
const OWNS: Array[String] = ["stats"]
static func setup(game: Game) -> void          # Stats.create(tags of the countries, or [""], goods 0); at game start
static func season(game: Game) -> void         # the stats phase (4.6)
static func row_now(game: Game, tag: StringName) -> PackedInt32Array   # the values as the phase would write them

# core/systems/improve.gd  (M1, edit): _changed calls game.emit; build, upgrade and clear are no longer actions:
#   the works phase calls them to put a finished work's piece. OWNS unchanged (main_use, level).
# core/systems/territory.gd  (M2, edit): transfer emits through game.emit with tag and others (4.4).
# core/systems/countries.gd  (M2, edit): choose emits through game.emit.
```

### 5.4 Game, the action table, the season (`core/game/`)

```gdscript
# core/game/game.gd  (M1, M2; edit)
const DOOR_FIELDS: Array[String] = ["events", "action_log", "chronicle", "version", "view_cache"]
var start_year: int = Calendar.DEFAULT_YEAR
var turn: int = Calendar.FIRST_TURN
var stats: Stats = null
var chronicle: Chronicle = Chronicle.new()
var action_log: Array[Dictionary] = []
var luck: Luck = null
var version: int = 0                       # not saved
var view_cache: ViewCache = ViewCache.new()   # not saved
static func new_game(p_map: MapData, p_seed: int, p_defs: GameDefs = null) -> Game     # luck seeded, StatsSystem.setup
static func with_state(p_map: MapData, p_state: MapState, p_seed: int = 0, p_defs: GameDefs = null) -> Game
static func new_scenario(p_map: MapData, p_defs: GameDefs, p_scenario: ScenarioDef, p_seed: int) -> Game
	# M2's, now passing p_defs to new_game; start_year = p_scenario.year; StatsSystem.setup after the countries
func has_countries() -> bool               # scenario != null
func emit(event: Dictionary) -> void       # 4.4
func act(action: String, args: Dictionary) -> Dictionary   # on ok: the action log record and version += 1 (4.5)
func date_text() -> String                 # Calendar.date_text(turn, start_year)
func dev_transfer(hexes: Array[Vector2i], to_id: int) -> int   # Territory.transfer plus its action log record
func digest() -> String                    # 4.10

# core/game/actions.gd  (edit)
const NAMES: Array[String] = ["build", "upgrade", "clear", "cancel_work", "choose_country"]
# build, upgrade, clear, cancel_work -> Works pairs; choose_country -> Countries (M2)

# core/game/season.gd  (new)
class_name Season extends RefCounted
const PHASES: Array[StringName] = [&"works", &"stats", &"calendar"]
static func end_check(game: Game) -> Dictionary      # 4.2
static func begin(game: Game) -> void                # the action log's end_season record
static func run_phase(game: Game, phase: StringName) -> void   # match: Works.season, StatsSystem.season, Calendar.season
static func finish(game: Game) -> void               # version += 1
static func run(game: Game) -> Dictionary            # end_check, begin, every phase, finish; no drain (tools, tests, replay)

# core/game/view_cache.gd  (new)
class_name ViewCache extends RefCounted
const SIZE := 64
func get_or_make(key: Array, make: Callable) -> Variant   # the oldest entry goes past SIZE
func clear() -> void

# core/game/snapshot.gd  (new)
class_name Snapshot extends RefCounted
static func of(game: Game, ui: Dictionary = {}) -> Dictionary     # the body of 4.10
static func restore(body: Dictionary, map: MapData, defs: GameDefs) -> Dictionary
	# {game: Game or null, ui: Dictionary, problem: String}; type-checks every value; WorldImprove.over rebuilds

# core/game/save_file.gd  (new)
class_name SaveFile extends RefCounted
const FORMAT := 1
const OLDEST_FORMAT := 1
const DIR := "user://saves"
const SLOTS: Array[String] = ["quick", "1", "2", "3", "4", "5", "6", "7", "8"]
const AUTO_SLOTS: Array[String] = ["auto1", "auto2", "auto3"]
const THUMB := Vector2i(192, 108)
static func path_of(slot: String, dir: String = DIR) -> String
static func header_of(game: Game, slot: String, info: Dictionary) -> Dictionary   # info: build, name, saved_unix, play_seconds
static func write(game: Game, slot: String, info: Dictionary, ui: Dictionary, dir: String = DIR, json_too: bool = false) -> String
	# "" or the problem; the write sequence of 4.10
static func read_header(slot: String, dir: String = DIR) -> Dictionary   # {state: StringName, header: Dictionary}
static func read(slot: String, dir: String = DIR) -> Dictionary          # {problem: String, header, body}
static func remove(slot: String, dir: String = DIR) -> bool             # .sav, .bak, .png, .body.json
static func auto_slot(dir: String = DIR) -> String                       # the autosave slot to write next

# core/game/replay.gd  (new)
class_name Replay extends RefCounted
static func run(map: MapData, defs: GameDefs, scenario_id: String, seed_value: int, log: Array[Dictionary]) -> Game
```

### 5.5 Events and Session (`shell/autoload/`)

```gdscript
# shell/autoload/events.gd  (edit): added signals
signal work_started(tag: StringName, hex: Vector2i, work: Dictionary)
signal work_finished(tag: StringName, hex: Vector2i, work: Dictionary)
signal work_cancelled(tag: StringName, hex: Vector2i, work: Dictionary, why: StringName)
signal chronicled(entry: Dictionary)      # every notable event, as the chronicle stores it
signal season_ended(turn: int)            # the season that ended; after the last phase's drain

# shell/autoload/session.gd  (edit)
var play_seconds: float = 0.0             # counted in _process while a game runs and the tree is not paused
var current_slot: String = ""             # the slot last saved or loaded
var last_phase_ms: Dictionary = {}        # phase name -> ms of the last season (F3, perf)
func end_season_check() -> Dictionary     # Season.end_check(game); "no game" without one
func end_season() -> Dictionary           # check; Season.begin; each phase then drain(); Season.finish; season_ended;
	# unsaved_actions += 1 (M1.5's count: a played season is progress the quit question protects)
func save_game(slot: String, thumbnail: Image = null, ui: Dictionary = {}, name: String = "") -> String
	# not `save`/`load`: a method named load would hide GDScript's load() inside session.gd. SaveFile.write with the wall clock, play_seconds and the build; the PNG after; unsaved_actions = 0; "" or the problem
func autosave_game(thumbnail: Image, ui: Dictionary) -> String     # save_game(SaveFile.auto_slot(), ...)
func load_game(slot: String) -> String    # read, check the map and scenario, Snapshot.restore, the digest check, start_game;
	# play_seconds and current_slot from the header; "" or the problem; nothing starts on a problem
func loaded_ui() -> Dictionary            # the ui block of the last load ({} after a new game)
func list_saves() -> Array[Dictionary]    # {slot, state, header, thumbnail (path or "")}: autosaves, quick, 1..8; headers
	# only; adds the states other_map and other_build (4.10)
func newest_save() -> Dictionary          # the loadable save with the newest saved_unix, or {}
func delete_save(slot: String) -> bool
func dev_transfer(hexes: Array[Vector2i], tag: StringName) -> int    # developer console only; drains
# drain() (M2) adds: work_started, work_finished, work_cancelled to their signals; then chronicled(Chronicle.plain(e))
#   for every kind in Chronicle.NOTABLE
# new_game / new_scenario / load reset play_seconds, current_slot, last_phase_ms
```

### 5.6 Views (`core/views/`, pure)

```gdscript
# core/views/knowledge.gd  (new)
class_name Knowledge extends RefCounted
static func knows(game: Game, viewer: StringName, other: StringName) -> bool
static func known(game: Game, viewer: StringName) -> Array[StringName]      # id order, viewer excluded
static func unknown_count(game: Game, viewer: StringName) -> int
static func band(n: int) -> int
static func band_text(n: int, unit: String) -> String
static func witnessed(game: Game, event: Dictionary, viewer: StringName) -> bool

# core/views/words.gd  (new)
class_name Words extends RefCounted
const MINUS := "−"
static func number(n: int) -> String             # "1,240"
static func signed(n: int) -> String             # "+86", "−6", "0"
static func plural(n: int, one: String, many: String) -> String   # "1 work", "2 works"
static func place(game: Game, hex: Vector2i) -> String   # "Savona (6, 13)"; "near Savona (7, 12)" (a named place within
	# 2 hexes, nearest, ties by place order); "(7, 12)"
static func list(items: Array[String], shown: int = 2) -> String  # "a, b and 2 more"
static func country_the(game: Game, tag: StringName) -> String    # "the Republic of Genoa"; "" for ""
static func seasons(n: int) -> String           # "1 season", "4 seasons"

# core/views/works_view.gd  (new)
class_name WorksView extends RefCounted
static func label(game: Game, work: Work) -> String     # build "vineyard, first stage"; upgrade "walled town to city"
	# (settlements, castles, harbour) or "vineyard, first to second stage"; clear "clearing the vineyard" (HexCard's
	# LEVEL_WORDS and STAGE_WORDS); a line adds the place: "<label>, <Words.place>"
static func at(game: Game, hex: Vector2i) -> Dictionary  # {} or {label, tag, progress ("1 of 4 seasons"), ready
	# ("Spring 1481"), ready_turn, halted (bool: halted in the current season), started_turn}
static func ready_turn(game: Game, work: Work) -> int
static func seasons_of(game: Game, action: StringName, hex: Vector2i, family: int = -1) -> int   # for button cost text
static func slots(game: Game, tag: StringName) -> Dictionary   # {used, total}; total -1: no limit
static func of_country(game: Game, tag: StringName) -> Array[Dictionary]   # at() of each work of tag, id order
static func last_begun(game: Game, tag: StringName) -> Vector2i # the newest work of tag begun this turn; NO_HEX none
const NO_HEX := Vector2i(-1, -1)

# core/views/log_lines.gd  (new)
class_name LogLines extends RefCounted
const FILTERS: Array[Dictionary] = [{id = &"all", since = "3"}, {id = &"works", since = "3"}, {id = &"mine", since = "3"},
	{id = &"money", since = "4"}, {id = &"war", since = "7"}]
const SEASONS_SHOWN := 8
const PER_SEASON := 60
static func line_of(game: Game, entry: Dictionary, viewer: StringName) -> Dictionary
	# {} when not witnessed; else {text, keyword, tone (good, plain, bad, muted), hex, mine, filters: Array[StringName],
	#  notify: bool, floating: String, turn}
static func entries(game: Game, viewer: StringName, filter: StringName) -> Array[Dictionary]
	# [{turn, title ("Spring 1480"), lines}], newest season first, SEASONS_SHOWN seasons, PER_SEASON lines each

# core/views/reminders.gd  (new)
class_name Reminders extends RefCounted
const RULES: Array[StringName] = [&"winter_halt", &"free_slot"]
static func unfinished(game: Game, tag: StringName) -> Array[Dictionary]
	# {kind, severity, text, hint, action: Array, action_label, hex}; cached in game.view_cache by
	# [&"reminders", game.version, game.turn, tag]
static func winter_halt(game: Game, tag: StringName) -> Dictionary   # {} when it does not apply
static func free_slot(game: Game, tag: StringName) -> Dictionary

# core/views/season_summary.gd  (new): style spec 6.4 with M3's content (4.9)
class_name SeasonSummary extends RefCounted
const SECTIONS: Array[StringName] = [&"glance", &"before", &"treasury", &"goods", &"works", &"people", &"orders",
	&"befell", &"standing"]   # M6 inserts &"armies" after &"people" (m6-build-spec.md 4.14); M7 &"war" after &"armies"
	# (m7-build-spec.md 4.17)
const COVERED: Array[String] = ["work_finished", "work_cancelled", "owners_changed"]   # toasts dropped while a season runs
const SHOWN := 6
static func of(game: Game, tag: StringName, turn: int) -> Dictionary
	# cached in game.view_cache by [&"summary", game.version, turn, tag]; {} when turn < 1 or turn >= game.turn

# core/views/hex_card.gd  (M1.5, edit): a "Work" line, tone warn: "vineyard, first stage: 1 of 4 seasons, ready
#   Spring 1481" (or ": stopped for the winter, ready Autumn 1481"), after the piece rows
```

### 5.7 Who writes what (`OWNS`)

| Field | Written by | In an action | In a phase |
|---|---|---|---|
| `state.main_use`, `state.level` | `Improve` | no (from M3) | `works` (finishing) |
| `state.owner` | `Territory` (M2) | no (tests, editor, `dev_transfer`) | `sieges` (M7) |
| `state.works`, `state.next_work_id` | `Works` | `build`, `upgrade`, `clear`, `cancel_work` | `works` |
| `countries`, `player` | `Countries` (M2) | `choose_country` | `extinction` (M12) |
| `turn` | `Calendar` | no | `calendar` |
| `stats` | `StatsSystem` | no | `stats` |
| `events`, `action_log`, `chronicle`, `version`, `view_cache` | `Game` (the door; `Game.DOOR_FIELDS`) | yes | yes |
| `luck` | any system, by drawing through `Rng` only (none in M3) | | |
| `map`, `defs`, `scenario`, `seed_value`, `start_year`, `improvement` | set when a game is made or restored; never in play | | |

`tests/core/test_owns.gd` diffs `Snapshot.of(game)` before and after every action and every phase: only the owners'
fields and the door's may differ.

---

## 6. The UI of M3

Built from the M1.5 kit (`ui-and-controls-spec.md` 3.5, `ui-style-and-feedback-spec.md` 5). Colours and fonts from the
Theme; HUD controls take no focus, screens do. The shell's milestone value (M1.5 passes it to `Bindings.ensure` and the
Options screen) becomes `"3"`.

### 6.1 Keys and settings

| Action (`Bindings.DEFAULTS`) | Key (Mac) | Since | Who hears it | Does |
|---|---|---|---|---|
| `game_end_season` | Space, Enter (exists) | 3 | `MapInput` -> `end_season_requested(echo: bool)` | `SeasonFlow.request_end` |
| `game_report` | J (exists) | 3 | `MapInput` -> `report_requested` | the last report |
| `game_quicksave`, `game_quickload` | F5, Ctrl+S (Cmd+S); F9, Ctrl+L (Cmd+L) (exist) | 3 | `AppInput` (works under the pause menu) -> `quicksave_requested`, `quickload_requested` | 6.10 |
| `cam_bookmark_go_1..9`, `cam_bookmark_set_1..9` | Ctrl+1..9, Ctrl+Shift+1..9 (Cmd) (exist) | 3 | `MapInput` -> `bookmark_requested(index: int, set: bool)` | 6.12 |
| `game_undo_work` (**new**) | Ctrl+Z (Cmd+Z) | 3 | `MapInput` -> `undo_work_requested` | cancels the newest work begun this season |
| `dev_console` (**new**) | F2 | 3 | `AppInput` -> `console_requested` | focuses the console (developer tools on) |

Every key of `MapInput` is ignored while a `LineEdit` has focus (M1.5 "text fields win") and under a modal screen
(`MapInput` is `PAUSABLE`).

| `Settings.SCHEMA` key | Type, choices (default) | Page, row | Since |
|---|---|---|---|
| `game/autosave` (exists) | `off`, `yearly`, `five_years` (`yearly`) | Game: "Autosave: Off, Every year, Every 5 years" | 3 |
| `game/season_report` (exists) | `full`, `brief`, `off` (`full`) | Game: "Season report"; also the report's footer | 3 |
| `game/task_flag` (exists) | bool (true) | Game: "Task flag" | 3 |
| `graphics/season_change` (exists) | `instant`, `fade` (`fade`) | Graphics: "Season change" | 3 |
| `dev/save_json` (**new**) | bool (false) | Advanced: "Write saves as JSON too" | 3 |
| `state/log_open` (**new**) | bool (false) | no row (remembered) | 3 |
| `state/log_filter` (**new**) | `all`, `works`, `mine` (`all`) | no row (remembered) | 3 |

### 6.2 The top bar: date and End season (`shell/hud/date_end.tscn/.gd`, new)

```gdscript
class_name DateEnd extends HBoxContainer   # focus NONE; in the top bar right of the mode switch (M4's chips go between)
signal end_season_requested
signal report_requested
func refresh() -> void            # from Session.game: year, dial, verdict of Session.end_season_check()
func set_busy(on: bool) -> void   # the medallion's ring turns (`Motion.spin_ring`; reduce motion: the still hourglass)
```

| Part | Content |
|---|---|
| `Date` | `Medallion` (R3) 64 px lapis: `text` the year ("1480"), `dial` the season (0 to 3); tooltip "Spring 1480. J: the last report"; a click emits `report_requested` |
| `End` | a `KitButton` of variation `ButtonEndSeason` (the `endseason_plate_*` 160 x 44): "End season" and a `KeyCap` of `game_end_season`; `set_verdict(Session.end_season_check())` (off with "choose your country first" during the pick); emits `end_season_requested` |

Refreshes on `game_started`, `country_chosen`, `season_ended` and the flow's `state_changed`. Narrowing: the date and
End season never hide.

### 6.3 The flow (`shell/app/season_flow.gd`, new)

```gdscript
class_name SeasonFlow extends Node          # owned by the App; process_mode ALWAYS
enum State { IDLE, RUNNING, REPLAY, DECISIONS, REPORT }
const GUARD_MS := 400
signal state_changed(state: State)
var settings: Settings
var clock: Callable                         # () -> int, ms; the App gives Time.get_ticks_msec, tests a fake
var show_season: Callable                   # (season: int, fade: bool) -> void: MapScene.show_season
var push_report: Callable                   # (summary: Dictionary) -> void: pushes season_report
var toast: Callable                         # (text: String, tone: StringName, key_action: StringName) -> void
var autosave: Callable                      # () -> void: the App's autosave step (thumbnail, Session.autosave_game, toast)
func request_end(echo: bool = false, count: int = 1) -> bool
	# refused (false) on echo, outside IDLE, before guard_until, or when the check fails (toasts its reason)
func reopen_report() -> void                # J: push the summary of game.turn - 1; "No season has ended yet." at turn 1
func report_closed() -> void                # the report's on_exit (through ctx app_requested report_closed)
func state() -> State
static func autosave_due(turn: int, start_year: int, every: String) -> bool   # 4.10
```

- **IDLE** accepts `request_end` (not an echo, not before `guard_until`).
- **RUNNING:** `state_changed` (the date's busy ring), one frame awaited so it is drawn, `Session.end_season()`.
  With `count` > 1 (the console) the seasons before the last run with no report.
- **REPLAY** (M6) and **DECISIONS** (M7, M9, M11): empty in M3; the flow passes through.
- **REPORT:** `summary = SeasonSummary.of(game, player, game.turn - 1)`. Full: `push_report(summary)`. Brief: push when
  `serious` or `swing_permille > 100`, else `toast(summary.toast, &"plain", &"game_report")`. Off: the toast.
- **Back to IDLE** (on `report_closed`, or at once when nothing was pushed): `guard_until = clock() + GUARD_MS`;
  `show_season(Calendar.season_of(game.turn), setting == "fade" and not reduce_motion)`; `autosave()` when
  `autosave_due`. A report reopened by J also sets the guard when it closes.

### 6.4 The season report (`shell/screens/season_report.tscn/.gd`, new; `MODAL`, 900 x 640)

Style spec 6.8 against `report_m4.jpg`, cut to M3's sections. A `ModalFrame` (M1.5) holding a `VellumSheet` (M1.5):

| Part | Content |
|---|---|
| Ribbon | `title` ("Spring 1480") |
| Seal | `seal_letter`, tone vermilion; `press_seal()` on enter |
| Lede | `lede` in `LabelFlavour` |
| Nav | an ink `NavList` of the sections present, each with its `count` |
| Body | one scrolling VBox: per section a `LabelInkHead` title and its lines; `glance` as up to five boxed chips (a `PanelSlot` with the label, the value and a `DeltaChip` in ink); a line: a gilt bar when `top`, the text (`LabelInk`; a link button when it has a `hex`), `detail` (`LabelInkMuted`), the amount as a `DeltaChip` (M4 on), the action button (`action_label`) in `before` |
| Footer | "Open the study" (hidden until M4); `Segmented` "Full, Brief, Off" bound to `game/season_report`; `ButtonMenuPrimary` "Begin Summer" (the season that begins; "Back to the map" when J reopened an older report) with a `KeyCap` of Space, the default focus |

Space, Enter, Esc and the primary button close it (`back()` returns false). A link or an action button closes it and
sends `ctx.request(&"look_at", {hex, select: true})`. `on_exit` sends `ctx.request(&"report_closed")`.

```gdscript
class_name SeasonReport extends Screen
func show_summary(summary: Dictionary) -> void      # builds the sections; any of the nine ids is drawn
```

### 6.5 The action log (`shell/hud/action_log.tscn/.gd`, `shell/hud/log_feed.gd`, new)

Bottom left of `MapArea`, above the key hints. **Collapsed:** one line 400 px wide, the newest line and a "+8 new" badge
(`BAD` text on `CARD_BG`). **Open:** a `PanelCard` 470 x 268: a header (`Segmented` of the filters of
`LogLines.FILTERS` up to the milestone, a collapse button), then the seasons, newest first: a season header ("Spring
1480"), lines of a keyword chip in the line's tone and the sentence (`Body`; others' lines `Hint`). A line with a hex is
a button: `ctx.request(&"look_at", {hex, select: true})`. The **newest season header** opens the last report
(`report_requested`); older headers are plain text until M4.5. The wheel scrolls inside it. Esc closes it (Esc ladder
step `CLOSE_HUD_LIST`). Its open state and filter are `state/log_open`, `state/log_filter`.

```gdscript
class_name LogFeed extends RefCounted
func rebuild(game: Game, viewer: StringName) -> void      # from the chronicle (game_started, a load)
func add(entry: Dictionary) -> void                       # Events.chronicled; unread += 1 when it makes a line
func entries(filter: StringName) -> Array[Dictionary]     # LogLines.entries
var unread: int
func mark_read() -> void
```

### 6.6 Notifications, toasts, floating ribbons

**Notifications** (`shell/hud/notifications.tscn/.gd`, new): top right of `MapArea`, under the task flag. Up to four
`PanelCard`s 300 px wide, newest on top: a tone dot, the line's text (`Body`, two lines at most), a small "Go" button
(look at the hex, select it, dismiss) and a close button. Fed by `Events.chronicled` lines with `notify` true: in M3 the
player's `work_finished`, `work_cancelled` with `why` lost or blocked, and `owners_changed` where the player gained or
lost land. A card is dropped when two seasons have ended since it came. Hidden while a screen hides the world.

**Toasts** (`ToastHost`, M1.5) that M3 adds:

| When | Text | Tone | Key cap |
|---|---|---|---|
| The player began a work | "Work begun: vineyard, first stage, near Savona (7, 12). Ready Spring 1481." | plain | `game_undo_work` |
| The player cancelled a work | "Work cancelled: vineyard, first stage, near Savona (7, 12)." | plain | |
| Undo with nothing begun this season | "Nothing to undo this season." | plain | |
| End season refused | its reason ("choose your country first") | bad | |
| The report not shown (Brief, Off) | `summary.toast` | plain | `game_report` |
| J at turn 1 | "No season has ended yet." | plain | |
| Saved (quicksave, a slot) | "Saved: Quicksave." / "Saved: Slot 3." | good | |
| Autosaved | "Autosaved." | plain | |
| A save failed | "Could not save: permission denied." / "Could not autosave: ..." | bad | |
| Loaded | "Loaded: Slot 3, Spring 1482." | good | |
| No quicksave | "No quicksave yet." | plain | |
| Bookmarks | "Bookmark 3 set." / "Bookmark 3 is empty: Ctrl+Shift+3 sets it." (the platform's key text) | plain | |

While the flow is `RUNNING`, `ToastHost.drop(SeasonSummary.COVERED)` drops toasts of those kinds (M3 raises none; M4 on).

**Floating ribbons** (`shell/map/floaters.gd`, `shell/map/floater.tscn`, new): in the map scene's `Names` canvas layer
(screen space), placed each frame from the hex's map position while any lives. A ribbon is a `PanelContainer` of
variation `PanelToast` with a tone dot and the line's `floating` word: Begun (the player's work, plain), Finished (good;
others' known: "Built", muted), Cancelled (bad), Gained, Lost (the player's land, three hexes at most), Taken (others').
v0.2.2's motion: born above the hex, rises 40 px with an ease-out over 1.1 s, pops in within 0.06 s, scale 0.6 to 1.2 to
1.0 in 0.14 s, fades from 0.6 s; same size at every zoom; 0.3 s apart and 18 px lower each at one hex; at most 3 a hex
and 16 in all; only hexes inside the view and not under the dock. Reduce motion: no rise, no scale, a fade in place.
The ribbons are World children (`PAUSABLE`), so those of a season wait under the report and rise when it closes.

### 6.7 The task flag (`shell/hud/task_flag.tscn/.gd`, new)

Top right of `MapArea`, under End season. A small `PanelCard` "2 things to do" (`Number` gold count, `Label`); hidden
at 0, with `game/task_flag` off, and while a screen is up. A click opens a list (a `PanelCard` 540 px wide, one row of
44 px a line: a tone dot by severity, the text, the hint in `Hint`); a click on a row presses its action (look at, select)
and closes the list; Esc or a click elsewhere closes it (Esc ladder `CLOSE_HUD_LIST`). Lines from
`Reminders.unfinished(game, player)`, refreshed on `season_ended`, `work_started`, `work_finished`, `work_cancelled`,
`country_chosen` and `game_started`.

### 6.8 The hex panel and the hover card (M1.5, M2; edits)

- **Hex panel** (`shell/panels/hex_panel.tscn/.gd`): when `WorksView.at(game, hex)` is not empty, a "Work under way"
  section: the label, "1 of 4 seasons, ready Spring 1481" (or "stopped for the winter, ready ..."), and a `KitButton`
  "Cancel the work" with `set_verdict(Session.check("cancel_work", {hex}))` (another country's work: no button). Every
  build, upgrade and clear button gets `cost_text` = `Words.seasons(WorksView.seasons_of(...))` ("4 seasons"); refused
  buttons show their reason (a full slot: "no free work slot: 2 of 2 in use"). Refreshes on the three work signals,
  `season_ended` and `hex_changed`.
- **Hover card:** `HexCard.of` gives the Work line (5.6); `MapHover` needs no change.

### 6.9 The map: the calendar's season, the fade, the work marks (`shell/map/`)

```gdscript
# shell/map/map_scene.gd  (edit)
func show_season(season: int, fade: bool) -> void   # TilesetBuilder.SEASONS[season] through set_season; with fade the
	# SeasonFade captures first. Ignored while a look preview is on (it ends at the next season_ended)
func preview_season(season: int) -> void            # F3's Look: 0 to 3 a season, -1 back to the calendar
# game_started: show_season(Calendar.season_of(game.turn), false) instead of START_SEASON; work marks set up
```

- **`SeasonFade`** (`shell/map/season_fade.gd`, new): a `CanvasLayer` at layer 9 (under the HUD's 10) with a
  `TextureRect`. `capture()` awaits `RenderingServer.frame_post_draw`, takes `get_viewport().get_texture().get_image()`,
  shows it at alpha 1; the swap starts below; a tween takes the alpha to 0 in 0.4 s and hides it. Headless or reduce
  motion: nothing.
- **`WorkMarks`** (`shell/map/work_marks.gd`, new; z 87, between the pennants at 86 and the marks at 90): for each work,
  the kit icon `hourglass` (24 px, `get_window().theme.get_icon(&"hourglass", &"Kit")`) 30 px above the hex's middle,
  and under it "2/4" (`draw_string` with the Theme's `Label` font, `Tokens.TEXT` over a 2 px `Tokens.INK` outline);
  modulated `Tokens.FAINT` while halted. Drawn at zoom 0.45 and above. Redrawn on the work signals, `season_ended` and
  `game_started`.

| z | What | Since |
|---|---|---|
| 86 | pennants | M2 |
| **87** | **work marks** | **M3** |
| 90 | selection, build targets | M1 |
| layer 9 | the season fade | M3 |

### 6.10 Save and Load (`shell/screens/save_load.tscn/.gd`, `shell/screens/save_rows.gd`, new; `MODAL`, 860 x 580)

A `ModalFrame` with the ribbon "Save game" or "Load game" and a `Segmented` "Save | Load" under it (from the main menu,
with no game running, only the Load tab shows). A scrolling list of rows (the Save tab: Quicksave and Slot 1 to 8; the Load tab: the three autosaves newest
first, Quicksave, Slot 1 to 8):

| Part | Content |
|---|---|
| Thumbnail | 192 x 108 `TextureRect` from `user://saves/<slot>.png` (loaded two rows a frame); a `PanelSlot` "No picture" otherwise |
| Title (`Body`) | "Republic of Genoa · Spring 1482" (or the save's name above it); "Empty slot"; "Autosave · Spring 1482" |
| Detail (`Hint`) | "North Italy · saved 17 Nov 2026, 14:32 · played 2 h 05 min · Hexa 0.3.0" |
| State (`Reason`) | the greyed states' words (4.10) |
| Buttons | Save tab: "Save here"; Load tab: "Load"; a small "Delete" on used rows |

The Save tab has a `LineEdit` "Name" above the list (default "<long name>, <date>"; text fields win). Up and Down move
between rows, Enter saves or loads, Del deletes, Esc goes back. Saving over a used slot, loading over unsaved actions
(`Session.unsaved_actions > 0`) and deleting go through `Confirm` (M1.5): "Save over Slot 3? Republic of Genoa, Spring
1481", "Load Slot 3? Unsaved changes are lost.", "Delete Slot 3? It cannot be undone." Save asks the App
(`ctx.request(&"save", {slot, name})`); the App takes the thumbnail and saves, then `ctx.saved.emit(slot, problem)`;
the screen refreshes its rows. Load asks `ctx.request(&"load", {slot})`.

```gdscript
# shell/screens/save_rows.gd  (new; pure, in the shell because it formats the wall clock)
class_name SaveRows extends RefCounted
static func of(list: Array[Dictionary], tab: StringName, now_unix: int) -> Array[Dictionary]
	# {slot, title, detail, state_text, thumbnail, can_act: bool, can_delete: bool}
# shell/app/shell_context.gd  (M1.5, edit)
signal saved(slot: String, problem: String)
```

**Quicksave** (F5): the App saves to `quick` (thumbnail first); refused with a toast when no game runs. **Quickload**
(F9): "No quicksave yet." when empty; with unsaved actions a `Confirm` "Load the quicksave? Unsaved changes are lost.";
then the load.

### 6.11 Main menu, pause menu, recovery (M1.5, M2; edits)

- **Main menu:** **Continue** first when `Session.newest_save()` is not empty, primary and focused, with a `Hint` line
  under it "Republic of Genoa · Spring 1482"; then New game (primary when there is no Continue), Map sandbox (developer
  tools), **Load game** (hidden when no save exists; opens `save_load` on Load), Options, Credits, Quit (the mockup's
  order).
- **Pause menu:** Resume, **Save game**, **Load game**, Options, Help and keys, Main menu, Quit to desktop. Subtitle
  "Republic of Genoa · Spring 1480" (sandbox: "North Italy · Sandbox, seed 1480 · Spring 1480"). The hint line adds
  "F5 quicksave  F9 quickload". Save greyed with "Wait for the season to end" while the flow is `RUNNING` (D48).
- **Loading** (M1.5): the App pushes it with "Reading the save", then the map's "Drawing the map 63 %".
- **Recovery:** 4.10; the `Confirm` is pushed over the main menu.

### 6.12 Camera bookmarks (`shell/app/bookmarks.gd`, new)

```gdscript
class_name Bookmarks extends RefCounted
const COUNT := 9
func set_at(index: int, centre: Vector2, zoom: float) -> void   # 1 to 9
func get_at(index: int) -> Dictionary                            # {centre, zoom} or {}
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> Bookmarks               # bad entries dropped
```

The App keeps one per game. Set: the centre and zoom of the last `CameraRig.view_changed` (M1.5). Go: `CameraRig.look_at`
then `zoom_to` (a glide; a jump under reduce motion). Saved in the body's `ui` block; restored from `Session.loaded_ui()`.

### 6.13 The developer console and F3 (`shell/hud/dev_console.tscn/.gd`, `shell/hud/dev_commands.gd`, new; edit `shell/hud/debug_overlay.*`)

At the foot of the F3 panel (developer tools on): a `LineEdit` and the last 8 output lines. F2 or a click focuses it;
Enter runs the line; Up and Down walk a history of 20; Esc leaves it.

| Command | Does |
|---|---|
| `build c r family` (a name of `ImproveRules.NAMES` or its id) | `Session.act("build", {hex, family})` |
| `upgrade c r`, `clear c r`, `cancel c r` | `upgrade`, `clear`, `cancel_work` |
| `choose TAG` | `choose_country` |
| `end [n]` (1 to 40, default 1) | `ctx.request(&"end_seasons", {count})`: the flow plays n seasons, the report only after the last |
| `goto c r` | `ctx.request(&"look_at", {hex, select: true})` |
| `look spring\|summer\|autumn\|winter\|calendar` | `ctx.request(&"dev_look", {season})` (-1 for calendar) |
| `give c r [c r ...] TAG` | `Session.dev_transfer(hexes, tag)` (`""` frees the land) |
| `digest`, `seed`, `help` | print the digest (12 characters), the seed, the commands |

```gdscript
class_name DevCommands extends RefCounted
static func parse(text: String, game: Game) -> Dictionary
	# {kind: &"act" | &"end" | &"goto" | &"look" | &"give" | &"digest" | &"seed" | &"help", action, args, problem}
```

**F3 additions:** a line "turn 9 · Spring 1482 · works 3 · phases works 0.4, stats 0.2, calendar 0.0 ms · save 32 ms"
(from `Session.last_phase_ms` and the last save's time), and the season control becomes **"Look: Calendar, Spring,
Summer, Autumn, Winter"** (a `Segmented`) sending `season_preview_requested(i)` with -1 for Calendar.

### 6.14 Options: the Game page (M1.5; edit)

The Options screen's page list gains **Game** after Accessibility (UI spec 6.7), shown from milestone 3: the rows
`game/autosave`, `game/season_report`, `game/task_flag` (from `Settings.SCHEMA`). Graphics shows "Season change";
Advanced shows "Write saves as JSON too".

### 6.15 The App (`shell/app/app.gd`, M1.5, M2; edits) and its game requests (`shell/app/game_requests.gd`, new)

The M3 handlers live in `GameRequests` (a `RefCounted` the App makes with itself, the HUD and the flow), so `app.gd`
stays under the 800-line limit; the App connects the signals below to it.

| Request or event | The App |
|---|---|
| `MapInput.end_season_requested(echo)`, `DateEnd.end_season_requested` | `flow.request_end(echo)` |
| `MapInput.report_requested`, `DateEnd.report_requested`, the log's newest header | `flow.reopen_report()` |
| `MapInput.undo_work_requested` | `WorksView.last_begun(game, player)`; `Session.act("cancel_work", {hex})`, or the toast "Nothing to undo this season." |
| `MapInput.bookmark_requested(i, set)` | 6.12 and its toasts |
| `AppInput.quicksave_requested`, `quickload_requested`, `console_requested` | 6.10; focus the console |
| `app_requested(&"save", {slot, name})` | `Thumbnail.take` then `Session.save_game`; toast; `ctx.saved.emit` |
| `app_requested(&"load", {slot})`, `(&"continue")` | pops the screens, pushes Loading, `Session.load_game`; a problem pops Loading, toasts it and shows the main menu; then the camera and bookmarks from `loaded_ui()` |
| `app_requested(&"report_closed")`, `(&"end_seasons", {count})`, `(&"dev_look", {season})` | the flow; `MapScene.preview_season` |
| `Events.work_started` (the player's) | the toast with the undo key |
| `flow.state_changed` | `DateEnd.set_busy`, the pause menu's Save verdict |
| flow's `autosave` | `Thumbnail.take`, `Session.autosave_game(image, ui)`, "Autosaved." or the failure toast |
| game start (new, sandbox, load) | writes `running.lock`; `end_game` and a clean quit delete it |
| start of the program | recovery (4.10) after the main menu shows |

```gdscript
# shell/app/thumbnail.gd  (new)
class_name Thumbnail extends RefCounted
static func take(viewport: Viewport, hide: Array[CanvasLayer]) -> Image
	# a coroutine: hides the layers, awaits frame_post_draw, copies, shows them, scales to 192 x 108 (Lanczos);
	# null when headless or the copy is empty
# shell/app/run_lock.gd  (new)
class_name RunLock extends RefCounted
const PATH := "user://running.lock"
static func write(map_id: String, now_unix: int) -> void
static func clear() -> void
static func left_behind() -> bool
```

`Hud` (M1.5) gains slots: `DateEnd` in the top bar after the mode switch; `ActionLog` in `MapArea`'s bottom left; a
`TopRight` column with `TaskFlag` and `Notifications`. The **Layers popover** loses its season buttons.

---

## 7. Data and the editor

| File | Holds | Made by | Checked by |
|---|---|---|---|
| `godot/data/defs/families/<key>.tres` (14, **new**) | `FamilyDef`: id, key, `work_seasons`, `clear_seasons` (table 4.3) | by hand (task Y2) | `tests/core/test_family_defs.gd`: every file loads and validates, values equal table 4.3 |
| `godot/data/defs/game_defs.tres` (M2, edit) | `families` (the 14, external), `work_slots_base` 1, `work_slots_city_level` 4, `works_halt_in_snow_winter` true | by hand (Y2) | `test_country_defs.gd` (M2) runs `GameDefs.validate()` |
| `godot/data/defs/countries/<tag>.tres` (M2, edit) | `ruler` (below) | by hand (Y2) | `CountryDef.validate` |
| `godot/assets/ui/kit/` (slice 3) | medallions, dial, hourglass, End season plate, seal tones | `tools/bake_ui.py` (R3) | `bake_ui.py --check`, `build_theme.gd --check` in CI |

Rulers: SAV the Duke of Savoy; MLO the Duke of Milan; VEN the Doge of Venice; GEN the Doge of Genoa; TUS the Signoria
of Florence; SWI the Diet of the Confederation; MAN the Marquis of Mantua; FER the Duke of Ferrara; SIE the Signoria of
Siena; LUC the Elders of Lucca; FRA the King of France; AUS the Archduke of Austria; PAP the Pope.

No generated data: the families are edited in the Godot inspector like the countries; the definition test is the CI
proof. The scenario editor (M2) is unchanged. `godot/data/README.md` gets a `families/` line.

---

## 8. Speed

`godot/tools/perf_core.gd` (**new**, headless, no window): `FakeMap.build(494, 247, 1480)`, `FakeScenario.build(map, 60,
1480)` (M2) with the 14 `FamilyDef`s of `data/defs/game_defs.tres` added to its `GameDefs` and `work_slots_base` 10, a
game, 600 works begun through `Works.build` with `Rng` seeded 1480 (10 a country, each a valid option), then 8 seasons through
`Season.run`, then save and load to `user://perf/`. Rows in `godot/tests/perf_core_budget.json` (**new**), nightly in
`.github/workflows/godot.yml`, never in GUT; a row past its limit fails the job:

| Row | Limit | What |
|---|---|---|
| `season_ms` | 100 | the three phases, worst of 8 seasons |
| `works_phase_ms` | 20 | the works phase with 600 works, worst |
| `stats_phase_ms` | 60 | the stats phase (1 ms a country), worst |
| `digest_ms` | 100 | `Game.digest()` |
| `snapshot_ms` | 150 | `Snapshot.of` |
| `save_ms` | 1,000 | `SaveFile.write` (bytes, zstd, sha, the file sequence) |
| `load_ms` | 2,000 | `SaveFile.read`, `Snapshot.restore` with `WorldImprove.over`, the digest check |
| `save_mb` | 8 | the `.sav` file |
| `summary_ms` | 2 | `SeasonSummary.of` for the largest country, uncached |
| `reminders_ms` | 2 | `Reminders.unfinished`, uncached |
| `work_check_ms` | 1 | one `Works.build_check` with 600 works under way (the pending scan) |

The UI probe (`godot/tools/ui/perf_ui.gd`, M1.5) gains, in `godot/tests/perf_ui_budget.json`: the report's push under 16
ms; the Save and Load screen's push with 12 rows under 16 ms; the log opening under 16 ms; 16 live ribbons under 1 ms a
frame; the season fade's capture frame under 50 ms on the owner's Mac (gpu class, enforced with `--gpu-limits`).

North Italy for scale: 340 land hexes, 13 countries, a few works; nothing there is measurable.

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (marked P).

| File | Cases |
|---|---|
| `tests/core/test_calendar.gd` (new) | season, year and text for turns 1 to 9 and 40, 681 (Winter 1480 is turn 4, Spring 1481 turn 5); `turn_of` inverts both for 680 turns; `is_winter`; the phase adds exactly one |
| `tests/core/test_chronicle.gd` (new) | `add` and `of_turn`; 3,001 adds keep the newest 3,000; `plain` types (StringName to String); round trip through `var_to_bytes` gives an equal digest; P: a wrong schema gives null |
| `tests/core/test_luck.gd` (new) | `seeded` is deterministic and the three streams differ; round trip; P: a missing stream falls back to `seeded` |
| `tests/core/test_game_core.gd` (new) | `emit` queues every event and chronicles only the notable; `act` records only accepted actions with the turn and plain args; `version` rises per accepted act and per season; `new_game` and `new_scenario` set `start_year`, `turn` 1, luck, stats; the digest moves with `turn`, a chronicle entry, a luck state; `has_countries`; `ViewCache` holds 64 |
| `tests/core/test_season.gd` (new) | **`PHASES` is `[works, stats, calendar]`** (the pin); `end_check` every row (P: a scenario game with no player is refused with "choose your country first" and nothing changes); `run` writes the end_season record and calls the phases in order (a recorder); `run_phase` of an unknown name does nothing |
| `tests/core/test_territory.gd`, `test_countries.gd` (M2, edit) | `owners_changed` carries `tag` and `others`; every event goes through `emit` and carries `turn`; `owners_changed` and `country_chosen` reach the chronicle |
| `tests/core/test_family_defs.gd` (new) | the 14 files load and validate; the values of table 4.3; P: a wrong key, a size that does not fit `TOP_LEVEL`, a 0 season, two families with one id, `work_slots_base` 0, `work_slots_city_level` 6 |
| `tests/core/test_country_defs.gd` (M2, edit) | every country has a ruler; P: an empty ruler is reported |
| `tests/core/test_works.gd` (new) | every row of the two check tables, each with its words (P each); durations per family and level; a work begun in Spring 1480 with 4 seasons stands from Spring 1481; the snow work stands from Autumn 1481; the pending pair rule (P: two level-3 goods works side by side, the second refused); slots on the 1480 scenario equal table 4.3 (GEN 2, LUC 1) and none in a map-only game; a work on land transferred away is cancelled `lost` at the next works phase; a work made unfinishable by a direct state edit is cancelled `blocked` with the reason; `cancel_work` in its first season and later (refund 0, event fields); works keep id order |
| `tests/core/test_improve_actions.gd` (M1, M2; edit) | the 2,000-action property, now with 40 season ends among them and actors from all tags and `""`: check and act agree; an accepted works action adds exactly one work and one `work_started`; a refused one leaves the digest; every accepted works action is on the actor's land; every finished work's hex has its target; slots never exceeded; same seed and actions, same digest |
| `tests/core/test_map_data.gd` (M1, M2; edit) | `MapState` schema 3 round trip with works; schema 1 and 2 dicts load with no works; the digest moves with one work's `seasons_left`; `duplicate_state` copies works; P: a work dict with a string for `seasons_left` makes `from_dict` return null |
| `tests/core/test_stats.gd` (new) | the ring wraps at 40 (the 41st row overwrites the 1st); year rows in Winter only; a dict missing a series loads it as zeros, an unknown series is dropped; save, load, save equal; the digest moves with a row; GEN's M3 values on the scenario fixture (`tests/core/scenario_fixture.gd`, M2); a map-only game has the tag `""` |
| `tests/core/test_knowledge.gd` (new) | `knows` (self, neighbour, far, `""`); `known` in id order; `unknown_count`; `band` (87, 1,234, 1,250, −1,234, 0, 99,960); `band_text`; `witnessed` (party, others, listed, public and known, P: public and unknown is false; `""` sees all) |
| `tests/core/test_snapshot.gd` (new) | `of` and `restore` keep the digest for a sandbox, a scenario before the pick, and after 12 seasons with works; every key of 4.10 present; each M2 5.9 field round-trips; P each: a wrong format, a missing `map_state`, a wrong map size, an unknown scenario, a scenario digest that differs, a mistyped value (a string for `turn`) |
| `tests/core/test_save_file.gd` (new) | in `user://test_saves_<n>/`: the header's keys; **save, load, save gives byte-equal files** (fixed `saved_unix`); `read_header` states `empty`, `ok`, `newer`, `older`, `broken`; P: one flipped body byte reads as broken; a truncated file is broken; `.bak` used when `.sav` is missing; a left `.tmp` is ignored; the autosave slot is the empty or oldest; 200 random byte files never crash and read as broken; `StringName`, `Vector2i` and packed arrays survive |
| `tests/core/test_replay.gd` (new) | 20 seasons of seeded random actions, one `dev_transfer`; `Replay.run` from the seed and the log gives the same digest; P: one changed logged argument gives another digest |
| `tests/core/test_owns.gd` (new) | each action and each phase changes only its owners' fields and the door's (5.7), measured on `Snapshot.of`; P: a test-only phase that writes `turn` from `Works` is reported |
| `tests/core/test_forty_seasons.gd` (new) | the 1480 scenario as Genoa: each season up to the free slots works begin at random valid options (seeded), 40 seasons; every season: slots never exceeded, every work on its owner's land, one work a hex, `stats.count` equals the seasons, the chronicle at most 3,000; every work finishes in the turn `WorksView.ready_turn` said when it began; a save and load every 10 seasons gives the same final digest as the run without saves; J's summary equal before and after each load |
| `tests/core/test_works_view.gd` (new) | labels (vineyard, first stage; walled town to city; vineyard, first to second stage; clearing the vineyard); `at` progress, ready, halted; `ready_turn` across a winter; `slots`; `last_begun`; `seasons_of` |
| `tests/core/test_hex_card.gd` (M1.5, edit) | the Work line, its halted form, none without a work |
| `tests/core/test_words.gd` (new) | `number`, `signed` with U+2212, `plural`, `place` (named, near, bare), `list` ("and 2 more"), `seasons` |
| `tests/core/test_log_lines.gd` (new) | each kind's sentence for the actor, a known other, an unknown other (`{}`); keyword, tone, filters, `notify`, `floating`; `entries` newest season first, 8 seasons, 60 lines; the filters by milestone |
| `tests/core/test_reminders.gd` (new) | `free_slot` (0 of 2: a line; 2 of 2: none; map-only: none); `winter_halt` only in Autumn with snow works; worst first; `serious` |
| `tests/core/test_season_summary.gd` (new) | an M3 season's sections and lines (glance chips, finished, begun, under way, cancelled, orders grouped, befell); six then `more`; three `top`; the quiet state; P: an unwitnessed event is absent; equal after a save and load; the toast and lede for Genoa and the sandbox |
| `tests/shell/test_session.gd` (M1.5, M2; edit) | `end_season` drains after each phase in order (a recorder on `Events`); `season_ended` once with the ended turn after the last drain; refused before the pick with no change; the work signals and `chronicled`; `last_phase_ms` keys; `dev_transfer` logs and drains; `save_game`, `load_game`, `autosave_game`, `list_saves`, `newest_save`, `delete_save`; a load of a broken, newer or other-map save returns its problem and starts nothing (P each); P: a header digest that differs from the loaded game's is refused with "The save is damaged"; `end_season` adds one to `unsaved_actions`; `unsaved_actions` 0 after a save; `play_seconds` round trip; `loaded_ui` |
| `tests/shell/test_bindings.gd`, `test_settings.gd`, `test_map_input.gd` (edits); `test_app_input.gd` (new) | the two new actions; the three new keys (P: a wrong value falls back); Space emits `end_season_requested` with `echo`; J, bookmarks, Ctrl+Z; F5, F9 and F2 under the pause menu (`AppInput`); nothing while a `LineEdit` has focus |
| `tests/shell/test_medallion.gd`, `test_kit_feedback.gd` (new) | R3, R4: the dial lights one quarter; busy turns the ring or shows the hourglass under reduce motion; `DeltaChip` icon and sign in every state |
| `tests/shell/test_date_end.gd` (new) | the year and quarter follow the turn; the End season verdict and its reason during the pick; a click emits; busy |
| `tests/shell/test_season_flow.gd` (new) | **the guard: refused at 399 ms, accepted at 401 ms** (injected clock); echo refused; Full pushes; Brief pushes only when serious; Off toasts; a refused check toasts its reason; `show_season` with fade per setting and instant under reduce motion; `autosave` called when due (yearly at Spring, five_years at 1485, never when off); J at turn 1 toasts; `count` 4 plays four seasons and one report |
| `tests/shell/test_season_report.gd` (new) | the fixture's nine sections all drawn; an M3 summary drawn; the quiet state; links and action buttons request `look_at` and close; Space, Enter, Esc close; the seal pressed; the `Segmented` writes the setting; nav counts; Begin focused |
| `tests/shell/test_action_log.gd`, `test_log_feed.gd` (new) | `rebuild` from a chronicle equals the live lines; unread counts; filters; a line requests `look_at`; the newest header requests the report; Esc closes |
| `tests/shell/test_notifications.gd`, `test_task_flag.gd` (new) | four cards at most, dropped after two seasons, Go looks and dismisses; the flag's count, list, a row's action, hidden at 0 and with the option off |
| `tests/shell/test_work_marks.gd`, `test_floaters.gd` (new); `test_map_scene.gd`, `test_layer_stack.gd` (edits) | marks follow the works and the halt; z 87; ribbons: 3 a hex, 16 in all, none off screen, they wait under a modal; the map opens in the calendar's season; `show_season` with and without fade; the preview holds until `season_ended` |
| `tests/shell/test_hex_panel.gd` (edit) | the Work section; Cancel's verdict; "4 seasons" on the buttons; a full slot's reason |
| `tests/shell/test_save_load.gd`, `test_save_rows.gd` (new) | rows for every state; Save over asks; Load over unsaved asks; Delete asks; Del and Enter keys; the name field; the `saved` signal refreshes |
| `tests/shell/test_main_menu.gd`, `test_pause_menu.gd`, `test_options.gd` (edits) | Continue first and focused with a save, hidden without; Load hidden without saves; Save and Load in the pause menu; the subtitle with the date; the Game page's three rows; no season buttons in Layers |
| `tests/shell/test_dev_console.gd`, `test_dev_commands.gd` (new); `test_debug_overlay.gd` (edit) | every command parses; P: a bad hex, an unknown family, `end 41` give a problem; history; F2 focuses; the F3 line and the Look control |
| `tests/shell/test_bookmarks.gd`, `test_run_lock.gd` (new) | set, get, round trip, bad entries dropped; the lock written, cleared, left behind |
| `tests/shell/test_app_flow.gd`, `test_hud.gd` (edits) | New game, pick Genoa, build, Space (report), Space (closes), Space within 400 ms (nothing), J (the same report), F5, quit to the main menu (asks: no, saved), Continue (the same digest), Ctrl+1 after Ctrl+Shift+1, recovery's question with a lock left; the HUD slots |
| `tests/shell/test_ui_monkey.gd` (edit) | adds Space, Space Space, J, F5, F9, Ctrl+1..9, Ctrl+Shift+1..9, Ctrl+Z, the report's links; invariants: at most one season a guard window; paused exactly while the report is up; the digest unchanged by opening the report, the log or Save and Load; save then load keeps the digest |
| Python `tests/test_bake_ui.py` (edit) | slice 3 pieces at both scales; the asserts of style spec 4.4 |
| Pictures (`godot/tools/ui/shot_ui.gd`, M1.5) | the report (an M3 season of Genoa; the quiet one; the fixture's nine sections) against `report_m4.jpg`; the top bar with the date and End season against `play_m4.jpg`; the log open; notifications and the task flag; Save and Load with thumbnails; the pause and main menus with Save, Load and Continue; work marks and a ribbon. Signed by the art director; then goldens (0.5 %) |

**Determinism:** `test_improve_actions`, `test_replay`, `test_forty_seasons`. **Save round trip:** `test_snapshot`,
`test_save_file`, `test_forty_seasons`, `test_session` (standard 6: every pull request from M3).

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| `var_to_bytes` changes a `StringName` or a typed array on the way back, so a digest differs after a load | `test_save_file.gd` (types survive) on Y6's first day, before `Snapshot` is built | `Chronicle.plain` and `Work.to_dict` already store plain types; extend `plain` to every body value |
| Godot's rename on Windows fails or is not atomic | `test_save_file.gd` simulates each step's leftovers; the owner runs the GUT suite once on Windows in Y6 | The `.bak` sequence (built in) |
| The viewport capture (thumbnails, the fade) is empty or slow on the Mac's Compatibility driver | `godot/tools/ui/probe_capture.gd` (new, windowed: a capture after `frame_post_draw`, its time and a pixel check), on the owner's Mac on Y8's first day (Y9's fade uses its answer) | Thumbnails from the far picture's texture with the overlay (no screen read); the fade as the World's `modulate` to `BG` and back over 0.4 s |
| The 400 ms guard feels slow or too short on a trackpad | the owner's playtest (step 6) | `GUARD_MS` is a constant (S) |
| Works feel slow (16 seasons for stage 3) | the playtest's 40 seasons | `FamilyDef` data (S) |
| The winter rule surprises | the playtest (step 10) and the report's notice | `works_halt_in_snow_winter` false (data) |
| Saves grow with the action log once the AI acts | `save_mb` in the nightly row; M8 measures with the AI | M8 keeps the log from the last autosave (D22) |
| The report is too much to read | the owner reads three reports in the playtest | Brief by default (one setting) |
| Two works side by side refused by the pending rule confuse the player | the refusal words name the other work's hex | none needed |
| An M1.5 piece the report needs (`VellumSheet`, `NavList`) is late | M3 starts after M1.5 closes | none |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 5.3: the `stats` row before the calendar; the calendar row's weather moves to M4; row 14 (autosave) leaves the table: the shell saves after the report. 9.2, row M3: points at this spec and its plan; status "specified and planned, waits for the owner's go; starts after M2 closes" |
| `docs/architecture/m1-build-spec.md` | Section 4: the living roads and crossings join `MapState` with road works in M4, not M3 (since moved to M10 by `m4-build-spec.md` 1.2) |
| `docs/architecture/m2-build-spec.md` | 5.4: `defs` is set in every game from M3 and `has_countries()` is `scenario != null`; 5.5: from M3 the rules call `game.emit`, and `owners_changed` carries `tag` and `others` |
| `docs/architecture/ui-style-and-feedback-spec.md` | Section 6: a note of M3's refinements (the chronicle on `Game`, 35 series with 14 families, the M3 notices, `witnessed` with the game, `Events.chronicled`, `view_cache` from M3) |
| `docs/architecture/ui-style-and-feedback-plan.md` | S2: a note that `m3-build-plan.md` folds R1 to R11 (R1 done by this spec; R6 with the Session work; R8's App and key edits in Y18 and Y3; R11 with the M3 monkey) and that W5 edits `view_cache.gd` |
| `docs/architecture/ui-and-controls-spec.md` | 3.6: `Session.save_game`, `load_game`; 4.1: `game_undo_work` (Ctrl+Z) and `dev_console` (F2) rows; 7: the Undo row (`cancel_work` in M3, the refund in M4) and the console row (F2, the foot of F3) |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M3: the tasks are those of `m3-build-plan.md` |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `godot/README.md` (layout, keys, saves; Y18), `CLAUDE.md` (the `perf_core.gd`
line in its Godot command list; Y17), `godot/data/README.md` (Y2), `.github/workflows/godot.yml` (the nightly
`perf_core` step; Y17), `tools/lint_godot.py` `CORE_RANK` needs no entry (new files sit in listed folders). No port rule
changes: no new autoload, no new layer.

---

## 12. What M3 hands to later milestones

| M | Takes from M3 | M3 leaves for it |
|---|---|---|
| M4 | `Work.paid`, `Works.refund` and the one `Treasury.move` line in `cancel_work`; the `production`, `trade`, `income` rows between `works` and `stats`; `Treasury.close_ledger` in the `stats` phase; weather from `luck.world` in the calendar phase; `SeasonSummary`'s `treasury`, `goods`, `standing` sections (the screen draws them already), `swing_permille`, money reminders; `FamilyDef` for costs and output; `view_cache` for previews; "Open the study" (road works, schema 4 of `MapState`, moved to M10 by `m4-build-spec.md` 1.2) | Money |
| M4.5 | the chronicle for History; `Stats` rings and years for charts and Rankings; `Knowledge.band` and `known`; older log headers open History | Insights |
| M5 | `people`, `food_made`, `food_eaten` series; `town_grew`, `district_declined` into `Chronicle.NOTABLE`; the People section; all taken up in `m5-build-spec.md` (which appends five series) | People |
| M6 | `witnesses` on events from vision; `knows` by explored hexes; the flow's `REPLAY` state; `ready_units`, `vision` rows; the winter rule's passes; all taken up in `m6-build-spec.md` (which adds the `armies` section and the `movement`, `supply` rows) | Armies |
| M7 | the flow's `DECISIONS` state; war kinds into the chronicle, the log's War filter, notifications for battles; `owners_changed` by capture cancels works `lost`; taken up in `m7-build-spec.md` (a capture changes the occupier, not the owner: a work on occupied or besieged land waits, and is cancelled `lost` only when a peace moves the owner) | War |
| M8 | AI actions through `Game.act` (logged); `ai_orders` row; `Luck.ai`; the action log's size (D22); `Knowledge` as the AI's only door; taken up in `m8-build-spec.md` (the orders hook and `Season.orders_*`, `Session.begin_season` / `step_orders` / `finish_season`, `Game.ai_only`, "Your orders" by the viewer's tag) | The AI |
| M12 | "the game is over" in `Season.end_check`; `OLDEST_FORMAT` frozen and CI loads saves kept from each release; `seal_cracked`; score rows (taken up in `m12-build-spec.md` section 12: 684 seasons, `OLDEST_FORMAT` 10 frozen) | The whole game |
| **E2** | **Nothing blocking: the save names the map by id and digest and stores none of it, and the season, works, stats and saves scale with countries and works, not hexes, so the Europe map file is built without touching M3's code.** | |
