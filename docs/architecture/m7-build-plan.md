# M7 build plan: War

Game and systems designer (Opus), 2026-11-17. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/m7-build-spec.md` ("the spec").

**Starts after M6 is closed** (its plan's definition of done, the owner's playtest). M7 edits what M1.5 to M6 deliver: `Game`,
`Session`, `Events`, the action and season tables, `Unit`, `Army`, `MapState`, `Stats`, `StatsSystem`, `Armies`, `Military`,
`Movement`, `Supply`, `Vision`, `People`, `Works`, `Economy`, `EconomySeason`, `Knowledge`, the report's view, the reminders, the
log lines, the study's views and pages, the map modes and overlay, the map scene, the floaters, the replay, the season flow, the
hex, army and country panels, the hex menu, the input and the App. The standard's rule holds: the next milestone starts after
the owner has played the last one.

**The M7 row of `ui-style-and-feedback-plan.md` S5** (the losses chart and the wars on the Military page; battle and siege lines
in the report; the war alert as a `DECISIONS` screen) is folded in: the Military page is B19 and B27, the report's lines B19 and
B27, the war alert B20 and B28.

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Numbers and state** | `WarDef` and the units', ground's and families' war fields; `War`, `Battle`, `BattleRecord`, `Siege`, `unit/2`, `army/2`, `map-state/5`, seven series, two people flows; the bake's war pieces; the keys and the setting | B1, B2, B3, B4 | 3 M, 1 S |
| **The rules** | declaring, the score and the truce; occupation, garrisons and castle areas; the pure battle; a battle's life and its end; sieges, supply and people in war; the economy in war; the peace and the timer; movement, the standing order and the storm order; the season, stats and saves | B5 to B13 | 6 L, 3 M |
| **Read models and proofs** | the battle and siege views and the fog; the castle-area lines, the map modes and the country card; events and the log lines; the Savoy war (done-when 1 to 5); the random player, the properties, the perf rows, the war report and the odds calibration | B14 to B18 | 3 L, 2 M |
| **Pieces and screens** | the report, reminders and the Military and History views; the replay's battle marks, `DECISIONS` and the queue; the overlay's stripes and areas; the battle dock; the odds, army and hex-card views and the hover cards; the country panel's war section | B19 to B24 | 3 L, 3 M |
| **The map and the pages** | war marks, area lines, the map scene; the odds card, the hex and army panels and the hex menu; the Military and History pages, the report's War section, the flag and notifications | B25, B26, B27 | 2 L, 1 M |
| **Wiring and proof** | the App; the monkey, the pictures, the UI perf rows | B28, B29 | 1 L, 1 M |

**29 tasks: 15 L, 13 M, 1 S**, about 51 worker-days; about 20 working days end to end with the groups below (each group takes
as long as its longest task), plus reviews and the owner's playtest.

```
M6 closed (the owner's playtest)
  -> A:  B1  B2  B3  B4
  -> B:  B5  B6 (L)  B7 (L)                    (B7's scratch fight table: Opus reads it at its end)
  -> C:  B8 (L)  B9 (L)  B10  B11
  -> D:  B12 (L)  B13 (L)
  -> E:  B14 (L)  B15 (L)  B16  B17  B18 (L)  (B18's war report: Opus's balance gate before F)
  -> F:  B19 (L)  B20  B21  B22 (L)  B23 (L)  B24
  -> G:  B25 (L)  B26 (L)  B27
  -> H:  B28 (L)
  -> I:  B29  -> the owner plays M7

Critical path: B1 -> B7 -> B8 -> B12 -> B14 -> B22 -> B25 -> B28 -> B29     (and B2 -> B6 -> B9 -> B13 -> B18;
               B5 -> B11 -> B17; B14 -> B23 -> B26; B15 -> B21; B16 -> B19 -> B27 -> B28)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel and no two touch
one file. The dependencies inside the rules are cut so that no task of a group calls code of another task of the same group:
battles and peaces never touch `game.sieges` (the sieges phase reads their outcome: the records, the controller, the wars),
and the siege's need and the storm cut are `Occupation`'s (spec 5.3).

---

## 2. Tasks

Who, per the standard's section 9 ("Opus (re-fit battle and siege docs) / Sonnet, Haiku (battle panel)"): *Sonnet* builds
systems, views, tools and anything touching `Game`, saves, the season table, `Session`, `Events`, input, the map or the App;
*Haiku* builds data files, the bake's pieces, kit-based panels, screens and pages from the spec's tables, and tests from a list;
*Opus* reviews the numbers and the words; *Fable* reviews interfaces. Generated files belong to the task that changes their
source. **Every task's done-when includes: lint (`python tools/lint_godot.py godot`), check_scripts and GUT green**, both UI
`--check`s (`bake_ui.py --check`, `build_theme.gd --check`), `build_map --check` and `build_scenario.gd --check`. Paths without
a prefix are under `godot/`; `tools/`, `tests/test_*.py`, `docs/` and `CLAUDE.md` are at the repository root.

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| B1 | M, Haiku (Opus reviews) | **The war numbers and the war fields of units, ground and families** | `core/defs/war_def.gd` (new); edit `core/defs/game_defs.gd` (`war`), `core/defs/unit_def.gd` (`attack`, `defence`, `fire_permille`, `siege_points`), `core/defs/terrain_def.gd` (`defence_permille`, `rough`, `narrow`), `core/defs/family_def.gd` (`fortress`); `data/defs/war.tres` (new); edit `data/defs/game_defs.tres`, `data/defs/units/{pikemen,crossbowmen,knights,bombards}.tres`, `data/defs/terrain/*.tres`, `data/defs/families/settlements.tres`, `data/defs/families/castles.tres`, `data/README.md`; `godot/tools/war_tables.gd` (new); `tests/core/test_war_defs.gd` (new); edit `tests/core/test_unit_defs.gd`, `test_terrain_defs.gd`, `test_family_defs.gd`, `test_economy_defs.gd` | Spec 4.3 to 4.9 and 5.1 entered exactly; every planted fault of spec 9 for these tests; `war_tables.gd` prints the three tables; Opus reads the numbers on the task's first day. Lint, check_scripts, GUT green |
| B2 | M, Sonnet | **War state** | `core/state/war.gd`, `core/state/battle.gd`, `core/state/battle_record.gd`, `core/state/siege.gd` (new); edit `core/state/unit.gd` (`unit/2`), `core/state/army.gd` (`army/2`), `core/state/map_state.gd` (`map-state/5`), `core/state/stats.gd` (seven series), `core/game/game.gd` (the fields of spec 5.2 only), `core/systems/people.gd` (`FLOWS` appends `garrisoned`, `sacked`; `levy` gains `why`, default `raised`; nothing else); `tests/core/test_war_state.gd` (new); edit `tests/core/test_army_state.gd`, `test_map_data.gd`, `test_stats.gd`, `test_people.gd` (the nine flows; a levy booked under its `why`) | Spec 5.2: round trips, `digest_text` moves with every field, the older schemas refused or read with zeros as the spec says; `War.live_between` in either order, ended wars ignored; 49 series; the planted faults of spec 9 for these files. Lint, check_scripts, GUT green |
| B3 | M, Haiku | **Bake slice 6: the war pieces** | `tools/ui_bake/pieces_m7.py` (new); edit `tools/bake_ui.py` (slice 6 in the catalogue), `godot/tools/build_theme.gd` (the `Kit` icons of spec 6.2), `shell/ui/tokens.gd` (`WAR_DIAL`, `WAR_DIAL_TRACK`, `AREA_INK_ALPHA`); re-made `assets/ui/kit/` and `shell/ui/theme.tres`; edit `tests/test_bake_ui.py`, `tests/shell/test_theme.gd`, `tests/shell/test_tokens.gd` | Spec 6.2's textures at 1x and 2x; the asserts of style spec 4.4; both `--check`s pass; the art director signs the war sheet (both badges in three tones at r8, r13, r34; the 24 icons; the die faces). Lint, check_scripts, GUT green |
| B4 | S, Sonnet | **Keys, the setting, the input intents** | edit `shell/input/bindings.gd` (`map_command_storm` Shift+O, `game_battle` B, the `GESTURES` line), `shell/app/settings.gd` (`map/castle_areas`), `shell/input/map_input.gd` (`storm_requested(map_px)` from a Shift+right click, `storm_key_requested` tested exact before `map_command_key`, `battle_requested`); edit `tests/shell/test_bindings.gd`, `test_settings.gd`, `test_map_input.gd` | Spec 6.1: the rows exist with `since: "7"`; Shift+O never also fires O; Shift+right click with no army behaves as a right click; no key fires while a `LineEdit` has focus; P: a bad `map/castle_areas` value falls back. Lint, check_scripts, GUT green |

### Group B (after A)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| B5 | M, Sonnet | **Wars: declaring, the score, the truce** | `core/systems/wars.gd` (new: `at_war`, `enemies`, `war_between`, `of_country`, `score`, `occupied_count`, `truce_until`, `men_under_arms`, `declare_war_check`, `declare_war`, `make_peace_check`, `ceded`, `book_battle`, `digest`); edit `core/game/actions.gd` (`declare_war`); `tests/core/war_fixture.gd` (new: `at_war`, `army_at`); `tests/core/test_wars.gd` (new) | Spec 4.2, 4.9's check table, 5.3 (`Wars` but `make_peace`, `end_war`, `season`): every row of the two check tables with its words (P each); the score symmetric with the capital term (it reads `MapState.occupier`); `ceded` keeps the capital and the last district (P: a take that would empty a country lists one less); the truce from an ended war; `book_battle`; public witnesses. Lint, check_scripts, GUT green |
| B6 | L, Sonnet | **Occupation, garrisons and castle areas** | `core/systems/occupation.gd`, `core/systems/war_cache.gd` (new); edit `core/game/game.gd` (`war_cache` in `DOOR_FIELDS`, `emit`'s forgets, `dev_transfer`'s release), `core/systems/works.gd` (halted and refused on occupied or besieged land); `tests/core/test_occupation.gd` (new); edit `tests/core/test_works.gd`, `test_game_core.gd` | Spec 4.3, 4.4 (capture, release, flush, D18), 5.3 (`Occupation` with `besieged`, `siege_need`, `storm_garrison`; `WarCache`): the 18 fortresses, their garrisons and areas and the held land by country of spec 4.3 on seed 1480; every `area_state`; `regrow` from the hex and its ring (flow `garrisoned`); the cache's forgets (P each); works wait on occupied or besieged land and refuse to begin there. Lint, check_scripts, GUT green |
| B7 | L, Sonnet | **The pure battle** | `core/systems/combat.gd` (new); `tests/core/combat_fixture.gd` (new); `godot/tools/probes/probe_fight.gd` (new: 1,000 fights of 8 against 8 timed, and the scenario pairs of spec 4.6 at 100 seeds, printed); `tests/core/test_combat.gd` (new) | Spec 4.6 and 5.3 (`Combat`): the values, the worked hit (33 men), every phase, morale, the break test, the flight, Withdraw, the cap, the garrison and the assault on fixtures; the odds functions with the spec's Savoy example ("Favourable"); `fight` pure (P: an input changed by `fight` is caught); the 30-seed bands; the probe's `fight_ms` and scenario table in the pull request, read by Opus on the task's last day (a band outside spec 4.6 is a data change in `data/defs/war.tres`, made here with its tests). Lint, check_scripts, GUT green |

### Group C (after B)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| B8 | L, Sonnet | **A battle's life and its end** | `core/systems/battles.gd`, `core/systems/battle_end.gd` (new); edit `core/systems/armies.gd` (`lose_unit_men`, `set_morale`, `add_xp`, `set_standing`, `recover_morale`, `morale_of`, `rank_of`; morale 1,000 on raising); `tests/core/test_battles.gd` (new); edit `tests/core/test_armies.gd` | Spec 4.6 (start, the phase, the end), 4.7 (`engage_check`), 5.3 (`Battles`, `BattleEnd`, the `Armies` additions): every row of `engage_check` (P each); battles and joins within the limit (P: a ninth company); assaults and storms (the cut from `Occupation.storm_garrison`); the end's men, losses, retreat, surrender, wounded, experience, storm and sack; records kept to 60; `battle_fought` and `battle_ended` with the contract fields, a case per `how`; `game.battles` empty after the phase; `Battles.digest` moves with every battle, record and name count; `game.sieges` never written (battles are made in the tests by `Battles.engage`; the movement phase calls it from B12). Lint, check_scripts, GUT green |
| B9 | L, Sonnet | **Sieges, supply and people in war** | `core/systems/sieges.gd` (new); edit `core/systems/supply.gd` (the field over controlled land, depots with fortresses, hostile armies cut it), `core/systems/supply_cache.gd` (`forget_at_war`), `core/systems/people.gd` (the season over controlled hexes booked on owners, besieged hunger, `levy`'s refusal on occupied land); `tests/core/test_sieges.gd` (new); edit `tests/core/test_supply.gd`, `test_people.gd` | Spec 4.4, 4.5 (with the lifts and removals read from records, controllers and wars), 4.11, 4.12, 5.3 (`Sieges`, `Sieges.digest` moving with every siege field): every cell of the siege table played in the engine; the floor (P); hunger; no progress beside a battle; each lift's `why` (P: a lost relief battle lifts with `relief`); a fall opens the area from the next season; walk-in at 250 men (P: 249), held land, retake; garrisons regrow; D18; supply over controlled land; `forget_at_war` drops only the countries at war; besieged hunger; levies refused on occupied land. Lint, check_scripts, GUT green |
| B10 | M, Sonnet | **The economy in war** | edit `core/systems/economy.gd` (the occupation term), `core/systems/economy_season.gd` (`Occupation.controlled`, occupied taxes at half, needs, nobody's upkeep, besieged nothing); `tests/core/test_war_economy.gd` (new); edit `tests/core/test_economy_season.gd`, `test_economy_preview.gd` | Spec 4.10: its table on fixtures; with no war every number of `test_economy_1480.gd`, `test_economy_genoa.gd` and `test_people_growth.gd` unchanged; ceded land in full from the next production; the preview counts today's occupations (a case). Lint, check_scripts, GUT green |
| B11 | M, Sonnet | **The peace and the timer** | edit `core/systems/wars.gd` (`make_peace`, `end_war`, `season`), `core/game/actions.gd` (`make_peace`); edit `tests/core/test_wars.gd` | Spec 4.9: take, white and yield move what the spec says (`Territory.transfer`, `Occupation.release`), armies on closed land sent to their nearest own hex with room or disbanded home (no man lost), the truce, `peace_made` and its witnesses; the timer at 40 seasons as a white peace (`terms` `timer`); `game.sieges` never written (the next sieges phase lifts them). Lint, check_scripts, GUT green |

### Group D (after C)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| B12 | L, Sonnet | **Movement, the standing order, the storm order** | edit `core/systems/movement.gd` (`hostile` as `Wars.at_war`, `open_to`, `open_mask`, `zoc_halts`, the tick's engage and join, `march_check` row 7, `storm_check`, `storm`), `core/systems/military.gd` (`standing_check`, `set_standing`, `can_stand` per side, `raise_check` row 4b), `core/game/actions.gd` (`storm`, `set_standing`); edit `tests/core/test_movement.gd`, `test_military.gd` | Spec 4.7, 4.8, 5.3 (`Movement`, `Military` edits): open land with a war; the mask and a route ending on a fortress; ZOC beside a fortress; the tick: engage, join, blocked, shaken (P each refusal); `storm_check` and `standing_check` every row with words (P each); `can_stand` per side; raising refused on occupied land. Lint, check_scripts, GUT green |
| B13 | L, Sonnet | **The season, stats, saves** | edit `core/game/season.gd` (`PHASES`, `run_phase` with `forget_at_war` after movement and battles), `core/game/game.gd` (the digest; `Occupation.setup` in `new_scenario`), `core/systems/stats_system.gd` (spec 4.19), `core/game/snapshot.gd` (the `war` key, the schemas), `core/game/save_file.gd` (`FORMAT` 5, `OLDEST_FORMAT` 5); edit `tests/core/test_season.gd`, `test_stats.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_owns.gd`, `test_insights_views.gd`, `test_game_core.gd` | **`PHASES` pinned as the thirteen of spec 4.13**; a capture counts in that season's production, the supply fields are dropped after movement and battles (P: a field kept across a battle is caught) and morale recovers in `ready_units` (fixtures built with `WarFixture.army_at`); save, load, save byte-equal with wars, sieges, records, occupation, garrisons, morale; a save in a siege's third season plays on equal (done-when 4's save); the OWNS table of spec 5.3 with its planted fault; the pins moved (thirteen phases, `FORMAT` 5, 49 series, seventeen actions); `season_ms` timed on the fake Europe by a probe run (the number in the pull request). Lint, check_scripts, GUT green |

### Group E (after D)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| B14 | L, Sonnet | **The battle and siege views, the fog** | `core/views/battle_view.gd`, `core/views/siege_view.gd` (new); edit `core/views/knowledge.gd` (`battle_access`, `siege_access`); `tests/core/test_battle_view.gd`, `test_siege_view.gd` (new); edit `tests/core/test_knowledge.gd` | Spec 5.6 for these files and 4.15's fog (P: an unwitnessed record gives `{}`; P: a siege between countries at peace is not shown); a record's frame per day; `sites` only the last season's; `latest_of`; `log_line` gives the spec's sentence for each day; the siege view's `relief` for the exact viewer only; `BattleView` writes its own sentences with M3's `Words` (B16's words are not called). Lint, check_scripts, GUT green |
| B15 | L, Sonnet | **The castle-area lines, the map modes, the country card** | `core/views/area_lines.gd` (new); edit `core/views/map_modes.gd` (the stripes and the area tint in `colour_of`, the constants), `core/views/country_card.gd` (`war`); `tests/core/test_area_lines.gd` (new); edit `tests/core/test_map_modes.gd`, `test_country_card.gd` | Spec 5.6 for these files: area lines on every outer edge of a held area of an enemy and none on open land (P: a fallen area keeps no line); `area_bytes`, `chunks_touched`, `held_by` for each area state; the stripes in both palettes; the war section's states and peace options with what moves (`Wars.ceded`). Lint, check_scripts, GUT green |
| B16 | M, Sonnet (Opus reviews the words) | **Events, Session, the chronicle, the log lines** | edit `shell/autoload/events.gd`, `shell/autoload/session.gd` (the drain, `last_phase_ms`), `core/state/chronicle.gd` (`NOTABLE`), `core/systems/vision.gd` (`SIGHTED`; the land a country sees is the land it controls, spec 4.12), `core/views/log_lines.gd` (the War filter, the sentences of spec 4.14, written in `LogLines`, `record` in `line_of`); edit `tests/shell/test_session.gd`, `tests/core/test_chronicle.gd`, `test_log_lines.gd`, `test_vision.gd` | Spec 4.14 (events, witnesses, log lines), 5.5: the eleven signals drained after their phases, then `chronicled`; the sentences for the player, a witnessed other and an unwitnessed one (P: an unwitnessed battle makes no line); twenty notable kinds; sight from controlled land, dropped on `controllers_changed` (P: a vision that still counts an occupied hex as its owner's source of sight is caught); still two autoloads. Lint, check_scripts, GUT green |
| B17 | M, Sonnet | **The Savoy war (done-when 1 to 5)** | edit `tests/core/war_fixture.gd` (`savoy(defs)`); `tests/core/test_war_savoy.gd` (new) | Spec 4.16 (a) to (e) exactly, season by season, hex by hex, man by man; the battle's result pinned for seed 1480 as the build gives it (its days, dice and losses written in the pull request); done-when 1 to 5 in the core (2's stripes are tested by B15 and B21, 3's dock by B22 on the record this test pins, whose frames `test_battle_replay.gd` of B18 sums). Lint, check_scripts, GUT green |
| B18 | L, Sonnet (Opus reads the report) | **The random player, the properties, the perf rows, the war report, the odds calibration** | edit `tests/core/random_player.gd` (the M7 actions); `tests/core/test_war_property.gd`, `tests/core/test_battle_replay.gd`, `tests/core/test_odds.gd` (new); edit `tests/core/test_check_contract.gd`, `test_men_property.gd`, `test_money_property.gd`, `test_people_property.gd`, `test_replay.gd`, `test_forty_seasons.gd`; edit `godot/tools/perf_fixture.gd` (`europe_war`, `battle_set`), `godot/tools/perf_core.gd` (rows `season_ms`, `battles_ms`, `fight_ms`, `sieges_ms`, `war_ms`, `areas_cold_ms`, `movement_ms`, `save_mb`), `godot/tests/perf_core_budget.json`; `godot/tools/war_report.gd` (new); edit `data/defs/war.tres` (the fitted `odds_words`, `odds_ground`, garrison weights), `CLAUDE.md` (one line: the war report) | **Done-when 6 to 9** (with B13's save tests; the view rows are B29's); the rows printed and within their limits; the war report for seeds 1480 to 1484 in the pull request; **Opus reads it before group F**, and every band of `test_odds.gd` holds against the measured rates; any number change is a data edit with its tests in this pull request. Lint, check_scripts, GUT green |

### Group F (after E)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| B19 | L, Sonnet (Opus reviews the words) | **The report, the reminders, the Military and History views** | edit `core/views/season_summary.gd` (the `war` section, glance, armies, orders, befell, quiet, `COVERED`), `core/views/reminders.gd` (three rules), `core/views/study_military.gd` (wars, battles, `battle_losses`), `core/views/study_history.gd` (`MARK_KINDS` with `war` first); edit `tests/fixtures/report_sample.gd` (a War section from the Savoy fixture); edit `tests/core/test_season_summary.gd`, `test_reminders.gd`, `test_study_military.gd`, `test_study_history.gd` | Spec 4.17, 4.18, 6.9's view: the sections exactly on the Savoy fixture; equal after a save and load; the three rules with their words (P: a war of 31 seasons makes no `war_timer`); the wars and battles rows equal the state; the war marks. Lint, check_scripts, GUT green |
| B20 | M, Sonnet | **The replay's battle marks, `DECISIONS`, the decision queue** | edit `core/views/replay_plan.gd` (`record_battle`, the retreat ticks), `shell/map/replay.gd` (record `battle_started`, `battle_joined`), `shell/app/season_flow.gd` (`decisions_start`, `decisions_done`, the `DECISIONS` state); `shell/app/decision_queue.gd` (new); `tests/shell/test_decision_queue.gd` (new); edit `tests/core/test_replay_plan.gd`, `tests/shell/test_move_replay.gd`, `test_season_flow.gd` | Spec 6.6 and 5.6 (`ReplayPlan`): a battle mark shows from its tick; retreats play after the movement; `DECISIONS` after `REPLAY` with a war on the player, then the report; empty: straight on; Save refused in `DECISIONS`; the queue's order. Lint, check_scripts, GUT green |
| B21 | M, Sonnet | **The overlay's occupied stripes and castle-area tint** | edit `shell/map/mode_overlay.gd`, `shell/map/mode_overlay.gdshader`, `shell/hud/mode_legend.gd` (the Owner mode's line "Striped: held by an enemy" while any district is occupied), `godot/tools/map/probe_mode_overlay.gd`; edit `tests/shell/test_mode_overlay.gd`, `test_mode_legend.gd` | Spec 6.3: the two textures, the uniforms, `update_occupiers` and `update_areas` writing only changed texels (P: one byte, one texel); the stripes in both palettes and in the minimap's material; the probe prints PASS on the runner and the owner's Mac, FAIL with `--plant`; the art director signs the stripes and the tint. Lint, check_scripts, GUT green |
| B22 | L, Haiku | **The battle dock** | `shell/screens/battle_dock.tscn`, `shell/screens/battle_dock.gd`, `shell/screens/battle/regiment_tile.tscn`, `shell/screens/battle/regiment_tile.gd`, `shell/screens/battle/battle_picture.gd`, `shell/ui/tug_bar.gd`, `shell/ui/die_face.gd` (new); edit `shell/screens/screen_ids.gd` (`battle_dock`); `tests/shell/test_battle_dock.gd`, `test_regiment_tile.gd`, `test_tug_bar.gd`, `test_die_face.gd` (new) | Spec 6.5: every part for a won, a lost and a watched battle and a narrow field, from records the Savoy fixture fights; the stepper, Play, keys, reduce motion; a record no longer kept; the art director signs it beside `docs/design/ui/18_battle_panel_v3_a_3lanes.png`. Lint, check_scripts, GUT green |
| B23 | L, Sonnet | **The odds, army and hex-card views, the hover cards** | `core/views/odds_view.gd`, `core/views/cards_war.gd` (new); edit `core/views/move_preview.gd` (`war`, `odds`), `core/views/army_view.gd` (standing, morale, rank, siege, last battle, token flags), `core/views/hex_card.gd` (Fortress, Held by, the area line, Siege); `tests/core/test_odds_view.gd`, `test_cards_war.gd` (new); edit `tests/core/test_move_preview.gd`, `test_army_view.gd`, `test_hex_card.gd` | Spec 5.6 for these files: the odds kinds, the ratio and word through `Combat`'s odds functions, the garrison weight, the ground factor, the chips and the refusals (P: a hidden enemy gives no word); `held_by` from `AreaLines`; the war field in `to()`; the army view's new fields; the hex card's lines; the two hover cards from `BattleView` and `SiegeView`. Lint, check_scripts, GUT green |
| B24 | M, Haiku | **The country panel's war section** | edit `shell/panels/country_panel.tscn`, `shell/panels/country_panel.gd`; edit `tests/shell/test_country_panel.gd` | Spec 6.7: each state's rows, the verdicts on the buttons with their reasons, the declare and peace `Confirm`s naming what moves, the refreshes. Lint, check_scripts, GUT green |

### Group G (after F)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| B25 | L, Sonnet | **The map: war marks, castle-area lines, the scene's updates** | `shell/map/war_marks.gd` (new); edit `shell/mapview/tile_map_view.gd` (`AREAS_Z`, `set_chunk_areas`), `shell/mapview/edge_line_layer.gd` (the dashed `area` kind), `shell/map/map_scene.gd`, `shell/map/map_scene.tscn` (the marks, the area lines on selection, the overlay's occupier updates, the two ribbons); `tests/shell/test_war_marks.gd` (new); edit `tests/shell/test_map_scene.gd`, `test_layer_stack.gd`, `test_border_mesh.gd` | Spec 6.3: badges and dials from the views (P: a hidden record makes no badge), the hover cards, the flash, the size below zoom 0.6; z 82 and 89; the area lines shown only with an army selected, a war on and the setting on, sliced; the updates on each event of the spec's list; the art director signs the badges beside `20_siege_badge.png` and the area lines beside `21_castle_area.png`. Lint, check_scripts, GUT green |
| B26 | L, Haiku | **The odds card, the hex panel, the army panel, the hex menu** | `shell/hud/odds_card.tscn`, `shell/hud/odds_card.gd` (new); edit `shell/panels/hex_panel.tscn`, `shell/panels/hex_panel.gd` (the area chip, Fortress, Held by, the Siege block, Storm now), `shell/panels/army_panel.tscn`, `shell/panels/army_panel.gd` (the standing segment, morale, rank, besieging, Storm, the last battle), `shell/hud/hex_menu.gd` (the three items); `tests/shell/test_odds_card.gd` (new); edit `tests/shell/test_hex_panel.gd`, `test_army_panel.gd`, `test_hex_menu.gd` | Spec 6.4: every kind of odds card (attack, siege, storm, walk-in, held) and a refusal with its way out, from previews `MovePreview.to` builds on the Savoy fixture. Spec 6.8: each part for a held, open, fallen, occupied and besieged hex and for a besieging, a shaken and a fresh army; the verdicts and requests; the refreshes. Lint, check_scripts, GUT green |
| B27 | M, Haiku | **The Military and History pages, the report's War section, the task flag, notifications** | edit `shell/screens/study/page_military.tscn`, `shell/screens/study/page_military.gd`, `shell/screens/study/page_history.gd`, `shell/screens/season_report.tscn`, `shell/screens/season_report.gd`, `shell/hud/task_flag.gd`, `shell/hud/notifications.gd`, `shell/hud/action_log.gd` (a battle line opens the dock); edit `tests/shell/test_page_military.gd`, `test_page_history.gd`, `test_season_report.gd`, `test_task_flag.gd`, `test_notifications.gd`, `test_action_log.gd` | Spec 6.9, 6.10: the Wars and Battles tables and the Battle series from a played fixture, Go and Open; the war marks on the timeline; the War section and its nav count from `report_sample.gd`, links to the dock and the hex; the three rules' lines; the notifications; a battle line of the log requests the dock; the art director signs the page. Lint, check_scripts, GUT green |

### Group H (after G)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| B28 | L, Sonnet | **Wire the App** | edit `shell/app/game_requests.gd` (spec 6.11's table), `shell/app/app.gd` (the milestone `"7"`, the decision queue; under 800 lines), `shell/app/study_warm.gd`, `shell/hud/hud.tscn`, `shell/hud/hud.gd` (the `OddsCard` slot), `shell/hud/layers_popover.tscn`, `shell/hud/layers_popover.gd` (the "Castle areas" switch), `shell/hud/dev_commands.gd` (`declare`, `peace`, `storm`, `standing`, `wars`), `shell/hud/debug_overlay.gd` (the F3 line), `godot/README.md` (the war, the keys, the console); edit `tests/shell/test_app_flow.gd`, `test_hud.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_study_warm.gd` | The flow test of spec 9 end to end; done-when 10 holds in the shell tests; the Layers switch and the Options row change `map/castle_areas` both ways; the war alert at idle and in `DECISIONS`; the console's planted faults; the sandbox refuses `declare`. Lint, check_scripts, GUT green |

### Group I (after H)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| B29 | M, Haiku | **Monkey, pictures, the view and UI perf rows** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`, `godot/tools/perf_core.gd` (rows `odds_ms`, `battle_view_ms`, `area_lines_ms`), `godot/tests/perf_core_budget.json`, `tests/fixtures/ui_sample.gd` (a war sample); the signed pictures as goldens (`godot/tests/goldens/m7_*.png`) | The monkey's new inputs and invariants green on 3 seeds; spec 9's pictures at 1280 x 720 scale 1 and 2560 x 1440 scale 2, signed; spec 8's UI rows and these view rows within their limits. Lint, check_scripts, GUT green |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** signs `Combat.fight`'s input and output, `Battle`, `BattleRecord`, the `Occupation` door and the
  season rows (spec 4.6, 4.13, 5.2, 5.3) before group B starts, and reads the interfaces of B2, B5 to B16, B20, B23, B25 and B28
  before they merge; the OWNS table of B13 with the doors of B6, B8, B9 and B11 together.
- **Opus** reviews B1's numbers on its first day, B7's scratch fight table at its end, B18's war report (seeds 1480 to 1484:
  the battle bands, the siege table in the engine, the held land) before group F starts, the words of B16 and B19 against spec
  4.14, 4.17 and 4.18, and B27's page. A changed number is a data edit with the tests it moves, in B7's or B18's pull request.
- **The art director** signs B3 (the war sheet), B21 (the stripes and the area tint), B22 (the dock beside mockup 18 option A),
  B25 (the badges beside mockup 20 option B, the area lines beside mockup 21), B27 (the Military page: no mockup exists, it is
  built from `game-feedback-screens.md` C.2 and the M6 page) and B29's pictures.
- **Pull requests** say what changes for the player. B5 to B13 change behaviour on purpose (wars, battles, sieges, occupation,
  the economy and people in war, the season's phases); B2 (the new fields of `MapState`, `Unit`, `Army`) and B13 (the war digests joined, the garrisons filled at a new game) change `Game.digest()`: said; no test pins
  a digest value. B13 makes M6 saves unloadable ("Made by an older test build"): said. B7 and B18 may change battle numbers, the
  odds words and ground factors: said, with the measured tables.

---

## 4. The owner's playtest of M7

On Windows (mouse) and on the MacBook (trackpad), with a fresh user folder. New game, More, seed **1480**, Italy 1480, Play as
**Savoy**. Milan is passive until M8: the console (F2) gives it an army and makes the wars on you.

1. F2: `as MLO raise 7 9 pikemen 2`. A Milanese token "~1k" stands at Alessandria (7, 9), beside Vercelli.
2. Click Milan's land: the country panel says "At peace" with a red **Declare war**. Open Venice's panel: Declare war is locked,
   "only neighbours go to war: the Republic of Venice shares no border with the Duchy of Savoy".
3. Declare war on Milan: the question names what war opens; confirm. A toast, a log line under the **War** filter, Milan's panel
   now "At war since Spring 1480 · score 0" with three peace buttons, each locked with its reason.
4. Raise 2 pikemen each at Ivrea, Turin and Vercelli. Select the Army of Ivrea: Milan's held land shows dashed lines and a light
   tint (the areas of Milan, Pavia and the Cisa); Domodossola (7, 6) has none. Hover Domodossola: the card says "Takes it at the
   end of the season." Right-click it. Order the Army of Turin to Vercelli.
5. Space (End Spring), Space (close the report). Space again (End Summer): the replay walks the Army of Ivrea into Domodossola;
   the report's **War** section: "Taken: Domodossola (7, 6) from the Duchy of Milan."; the ribbon "Taken"; press 2: Domodossola is
   striped in Savoy's colour over Milan's; the panel's score is +1.
6. In Autumn, join the Army of Turin to the Army of Vercelli in its panel; set its standing order to **Withdraw** and back to Hold
   (the hover shows both prices). Hover Alessandria: the **odds card** "Attack · ..." with both sides' men and morale. Right-click
   it. Order the Army of Ivrea to Locarno (7, 5).
7. End Autumn: the replay shows the step onto Alessandria and a crossed-swords badge; the report's War section has the Battle of
   Alessandria with both sides' losses; a notification. Close the report: the battle badge stands on Alessandria, ringed in the
   result's tone. Click it (or press **B**): the **battle dock** opens on the left and the map glides so the hex shows beside it;
   step the days with Left and Right, press Play; read the dice, the front-morale bar, the lane tiles (hover one: its numbers),
   the log and the result. Esc closes it.
8. I, `]` to **Military**: the Wars table (score, battles, losses, held), the Battles table (Open reopens the dock), the losses
   chart with **Battle** beside Hunger.
9. Send an army towards Pavia (10, 9): the route stops beside Milan's walls each season. On arrival hover Pavia: "Besiege ·
   falls in about N seasons", "Garrison starves after 3 seasons", "Taking it opens 6 districts", "Shift+right click: storm
   (...)". The amber **dial** fills each season; Pavia's hex panel shows the Siege block.
10. In the siege's second season F5, quit to desktop, Continue: the siege, the dial and the panel as before. Let it fall: "Pavia
    (10, 9) has fallen after N seasons: its land lies open (6 districts)"; the next season an army walks into Lodi and takes it.
11. Shift+right-click a garrisoned fortress with an army selected: the army marches to storm it; the dock shows an assault with
    the garrison in the centre.
12. In Spring 1481, Milan's panel: **Take what you hold** is open; click it: the question names the districts you hold; confirm.
    They become Savoy's (the stripes go, the border moves), every Savoy army on Milan's land is back on Savoy's, and Declare war
    reads "a truce with the Duchy of Milan holds until Spring 1483 (8 more seasons)".
13. F2: `as SWI declare SAV`: the **war alert** at once ("War! The Swiss Confederation has declared war on the Duchy of Savoy."):
    "Show the Swiss Confederation" glides to it and opens its panel; White peace is locked for 4 seasons.
14. Options, Map: turn off "Castle areas": no lines with an army selected; back on. Accessibility, the colour-blind palette: the
    stripes still read.
15. Map sandbox: `declare MLO` says "this map has no countries"; no war buttons anywhere.

---

## 5. Definition of done

1. The spec's "M7 is done when" items 1 to 11 hold.
2. Tasks B1 to B29 merged; CI green, with both UI `--check`s, `build_map --check`, `build_scenario.gd --check`, the probe and the
   nightly `perf_core` and `perf_ui` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac.
5. `godot-architecture.md` 9.2 marks M7 done; `godot/README.md` describes the M7 game.
6. Section 7 below is handed to the M8 and M9 build specs' authors.

---

## 6. How to start

On the day M6 closes:

1. Opus presents the war (spec 4.2 to 4.9 and the worked examples of 4.16) to the owner and Fable in 30 minutes; a changed number
   is a data line now, not a task later. Fable signs `Combat.fight`'s input and output, `Battle`, `BattleRecord`, the `Occupation`
   door and the season rows the same day.
2. Start group A together: **B2, B4** (Sonnet) and **B1, B3** (Haiku). Opus reads B1's numbers on its first day; the art director
   sees B3's badges on its second.
3. B7 starts when group A merges and runs its fight probe (`probe_fight.gd`) in its first days (spec 10's first two risks), so a
   fallback is chosen before B8 builds the battle's life on it.
4. B18's war report goes to Opus the day it runs; group F waits for the balance verdict.

---

## 7. What M7 hands on

- **M8:** the actions `declare_war`, `make_peace`, `march` (attack and besiege), `storm`, `set_standing` with their checks;
  `OddsView`, `SiegeView`, `Sieges.forecast`, `Occupation.area_state`, `BattleView`, `Wars.score`, `Wars.truce_until`,
  `Knowledge` and the reminders `besieged`, `occupied` as its views; `fight_ms`, `battles_ms`, `sieges_ms` as its budget rows; AI
  declarations on the player through `DECISIONS`. Taken up in `m8-build-spec.md` 4.9 to 4.11 and 4.14 (`Sieges.forecast_for`,
  the peace alert).
- **M9:** `Wars.score`'s body, `make_peace`'s terms (the peace screen), the truce of 12 after terms, war goals and casus belli on
  `War`, peace offers in the `war` phase, the `battle_ended` contract, the Wars table moving to the Diplomacy page.
- **M10:** road works change `StepCosts` (retreats and areas follow); markets may feed besieged towns.
- **M11:** generals (stack +2, a term each in the values and the morale loss), techs changing `WarDef` through definitions only,
  later kinds' attack and defence.
- **M12:** countries that fall, war weariness and the brakes, desertion, score with battles.
- **After M12:** the battle board (the mini game between days, width 3 to 7, back slots, rotation, cards) on `Combat.fight` and
  the records; field forts.
- **Saves:** `SaveFile.FORMAT` 5; a new body field with a default needs no bump (M3 4.10).
