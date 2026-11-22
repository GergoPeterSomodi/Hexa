# M7 build spec: War

Game and systems designer (Opus), 2026-11-17. **Status: a proposal, design only; it waits for the owner's go.** Builds
milestone M7 of `docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`), the
M1.5 UI foundation (`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`), and the M2, M3, M4, M4.5, M5 and M6 specs
and plans (`m2-build-*.md` to `m6-build-*.md`). Where this page is more exact it wins for M7; section 1.2 lists every place
where it refines an earlier page. The tasks are in `m7-build-plan.md`. This page carries the M7 row of
`ui-style-and-feedback-plan.md` S5 (the losses chart and the wars on the Military page; battle and siege lines in the report;
the war alert as a `DECISIONS` screen).

## M7 amendments after M6 (2026-11-21)

Read against master `e8a49f5` (M6 built, 2026-11-21): the code under `godot/`, M6's spec sections 4 and 5 (5.0 R1 to R13,
A1 to A15) and this spec. **Where this section and the rest of the page differ, this section wins for M7.** Each row:
what the page says, what is true now (file and line, under `godot/` unless marked), what the task must do, and the task
(B-number of `m7-build-plan.md`). The body was edited only for the plain renames of rows 1, 2, 10, 31 and 47 (and the
spec's references to them); everything else here is an instruction, not a redesign. Design questions are in "Questions
for the owner" at the end of this section.

| # | The page says | True now (file:line) | M7 must do | Task |
|---|---|---|---|---|
| 1 | `Vision` is the sight system (1.1, 4.12, 4.14, 5.3, 5.6). **Body renamed.** | `class_name Sight` (`core/systems/sight.gd:7`), `SightCache` (`sight_cache.gd:6`), test `tests/core/test_sight.gd`. `Vision` is only an enum in `core/defs/colour_contrast.gd:6`. | Read `Sight` everywhere; the file is `sight.gd`; `Sight.SIGHTED` (`sight.gd:12`) gains the kinds of 4.14. | B14, B15, B16, B17, B23 |
| 2 | `run_phase`: `movement -> Movement.season` (5.4). **Body renamed.** | `MovementPhase.season` (`core/systems/movement_phase.gd:37`, called from `core/game/season.gd:28`); `movement.gd` has no `season`. | Call `MovementPhase.season`. | B13 |
| 3 | B12 edits the tick's engage, join and step back in `movement.gd`. | The tick is in `movement_phase.gd` (339 lines: `_leg` 73, `_ticks` 154, `_room` 187, `_step_back` 209, `_apply` 243). `movement.gd` (515) holds `open_to` (99), `march_check` (360), `halt` (394). | B12 also edits `movement_phase.gd`. Its file is added to B12 (the order holds; the plan is not edited). | B12 |
| 4 | `Movement.hostile` becomes `Wars.at_war`, the test pairs kept (4.8, 5.3). | `hostile(_game, a, b)` (`movement.gd:36`) reads the test registry `_hostile`; `register_test_hostility` (41), `clear_test_hostility` (46). | `hostile` answers from `Wars.at_war`; the test registry (A12's seam) still wins when set. Both paths tested. | B12, B5 |
| 5 | Open land follows a war (4.8: `open_to` with a war). | `open_mask` is cached in the pinned slot `open_masks` keyed `[hash(owner), owner.size(), hex_count]` (`movement.gd:160`). A declaration moves no owner, so the cached mask stays stale. | Add the war state to the key (a revision of the live wars, or their count and hash). Test: declare, then `open_to` answers yes at once. | B12 (with B5) |
| 6 | Supply fields live in `SupplyCache` (`supply_cache.gd`), `game.supplies`, `forget_at_war`; DOOR_FIELDS has `supplies` (4.12, 5.3, 5.4, 4.13, B9, B13). | None exists: no `supply_cache.gd`, no `SupplyCache`, no `game.supplies`; `DOOR_FIELDS` (`game.gd:29`) is M6's seven. The fields sit in the view cache's pinned slots `supply_land` and `supply_depots` (`supply.gd:19-20`, 43-53), keyed by `_land_key` and `_depot_key` (`supply.gd:314-322`): owner, settlement and level, not the occupier, besieged land or hostile armies. | Engineering choice for Fable before B9: (a) build `SupplyCache` as M6 R5 wrote it, moving the two slots into it, or (b) keep the view cache and add the occupier and the war state to both keys. Either way the key holds the occupier, and a hostile army's cut is never reused across a phase (a B9 test). `supplies` joins DOOR_FIELDS only under (a). | B9, B13 |
| 7 | `army/2` adds `standing`; `unit/2` adds `morale`, `xp`; `order` gains `storm` (5.2). | `army/1` (`core/state/army.gd:6`), `unit/1` (`unit.gd:6`). Army: `id, tag, name, hex, units, order` (`none`, `hold`, `march`: `army.gd:8-10`), `goal, route, waiting, halt_why, halt_text, moved_from, supply, lost_last, created_turn`; no `standing`, no `battle`. Unit: `id, kind, men, home, raised_turn, paid, paid_goods`. The order check in `from_dict` is at `army.gd:100`. | As 5.2; `ORDER_STORM`, the check at `army.gd:100`, and the digests (`army.gd:128`, `unit.gd:63`) extended. M7 depends on M6 only through these classes. | B2, B8, B12 |
| 8 | Event payloads: `kind` names a unit kind (4.14 fields). | `kind` is the event type in every emit. Army events carry `kind_id` and `name`: `army_raised` (`military.gd:309`), `unit_lost` (`armies.gd:133`). | A unit kind in a payload is `kind_id`. No battle or siege payload uses `kind` for anything else. | B8, B16 |
| 9 | `FORMAT` 5 and `OLDEST_FORMAT` 5; an M6 save reads "Made by an older test build" (4.20, D55, 9). | `FORMAT := 4`, `OLDEST_FORMAT := 4` (`core/game/save_file.gd:9-10`); a header under `OLDEST_FORMAT` gives state `older` (`save_file.gd:179`). | Bump both to 5. Check the words the shell shows for state `older`: they must read "Made by an older test build", or the page's words change (one of the two, decided in B13). | B13 |
| 10 | `map-state/5` added to "the current `map-state/2`" (1.1). **Body corrected.** | `SCHEMA := "hexa-godot/map-state/4"` (`core/state/map_state.gd:12`); `/1` to `/3` are read as older. | As 5.2: `/5` adds three arrays; `/4` reads with zeros (tests only). | B2 |
| 11 | `People.FLOWS` appends `garrisoned`, `sacked` (nine); B2's files are `people.gd` only (5.2, B2). | `FLOWS` has seven (`people.gd:15`). `PEOPLE_FLOW_COUNT := 7` lives in `core/state/country.gd:11` and sets the width of `people_flows` (padding and refusal, `country.gd:187-227`). | Add `core/state/country.gd` to B2's files: `PEOPLE_FLOW_COUNT` 9. `test_people` and `test_stores` pins follow. | B2 |
| 12 | `People.levy(..., why := &"raised")`; levies refused on occupied land (5.3, 4.11). | `levy(game, tag, hex, men)` (`people.gd:520`), no `why`; `levy_check` (504). | Add `why` (default `raised`); the occupied refusal in `levy_check`. Callers in `military.gd` keep their form. | B2, B9 |
| 13 | Thirteen phases (4.13, 5.4, B13). | Ten (`core/game/season.gd:9-10`): movement, supply, production, income, works, people, stats, calendar, ready_units, vision. `test_season.gd:7` pins the ten. `run_phase` is a `match` (25-46). | Thirteen as 4.13. `ready_units` runs `Military.refill` then `Armies.recover_morale`. Repin `test_season.gd`. | B13 |
| 14 | `Stats.SERIES` 42 plus seven is 49 (4.19, 5.2). | 42 (`core/state/stats.gd:11-19`; `tests/core/test_stats.gd:19` asserts 42). `war_score` is already series 15 (M3's). | Append the seven; not `war_score` again. Pins move. | B2, B13 |
| 15 | Halt keeps the goal; a second halt is hold (the M7 halt note). | True: a first halt on a march keeps goal and route, order none; a second halt sets hold and clears goal (`movement.gd:382-407`); `halt_check` refuses a hold order. | No change. Storm and withdraw do not break it: B12 adds a test that a storm order halts the same way. | B12 |
| 16 | `Military.disband` takes its units atomically (brief). | Already: `disband(game, args)` with the `units` array (`military.gd:372`; `_disband_ids` 480-493; `_drop_of` 495). | No change. Battle losses must not call `disband`. | none |
| 17 | Standing "Hold" and the order "hold" (4.7, 5.2). | Two fields, one word: `Army.order` `hold` (`army.gd:9`) and the new `standing` `hold`. | Keep both constants apart (`STANDING_HOLD`, `ORDER_HOLD`); no test compares them. Owner question 1. | B2, B12, B26 |
| 18 | `OddsView.of(game, viewer, army_id, hex, storm)`; `MovePreview.to(...)`; `reach()` unchanged (5.6). | `ArmyView.tokens(game, viewer)` (`core/views/army_view.gd:19`), `panel(game, viewer, army_id)` (124); `MovePreview.reach(game, viewer, army_id)` (`move_preview.gd:26`); `MovePreview.to(game, tag, army_id, hex)` (68) takes the tag, not the viewer. | `OddsView` takes the viewer as `reach` does. `to` keeps `tag` and gains `war` and `odds`. | B23 |
| 19 | `colour_of(..., occupier_id := 0, area_byte := 0)` (5.6). | Now `colour_of(mode, owner_id, height_byte, palette, tint_on, hot_id, yield_byte, food_byte, supply_byte, seen, veil_on)` (`core/views/map_modes.gd:366-368`). `STRIPE_PX` (46) is the yield stripe; `OCCUPIED_STRIPE_PX` is new. | Append the two after `veil_on`. | B15, B21 |
| 20 | `Chronicle.NOTABLE` gains six: twenty (4.14). | Fourteen (`core/state/chronicle.gd:8-10`). | Plus six. | B16 |
| 21 | `Actions.NAMES` seventeen (5.4). | Thirteen (`core/game/actions.gd:11-12`); `pair_of` is a `match` (18). | Plus four; four pairs in `pair_of`. | B5, B11, B12 |
| 22 | Eleven events drained to their signals (5.5). | Seventeen typed signals in `shell/autoload/events.gd`; `Session.drain` is a `match` (`session.gd` 386 on). `last_phase_ms` keys come from the phase loop (`session.gd:184-189`). | Eleven signals and their arms. `last_phase_ms` needs no change. | B16 |
| 23 | Three reminder rules (4.18). | Eleven in `RULES` (`core/views/reminders.gd:8-10`). | Fourteen. | B19 |
| 24 | `war` section after `armies`; `COVERED` gains four (4.17). | Ten sections (`core/views/season_summary.gd:12-13`), `COVERED` six (15). `season_summary.gd` is 724 lines. | Build the section in `core/views/summary_war.gd` (as `summary_armies.gd`, M6 R12), not inside `season_summary.gd`. | B19 |
| 25 | Military study gains `battle_losses`, `wars`, `battles` (6.9). | Four series (`core/views/study_military.gd:11`); `of(game, viewer, span)` (19). | Add the series and the two keys. | B19 |
| 26 | `StudyHistory.MARK_KINDS` gains `war` first (5.6). | Nine kinds (`core/views/study_history.gd:10`). | Prepend `war`. | B19 |
| 27 | A War filter, since 7 (4.14). | Already there: `{id = &"war", since = "7"}` (`core/views/log_lines.gd:7-8`). | No new filter; the 4.14 sentences only. | B16 |
| 28 | `Knowledge` gains `battle_access`, `siege_access` (5.6). | `core/views/knowledge.gd` has `sees` (57) and `witnessed` (102). | Add both beside `witnessed`. | B14 |
| 29 | Replay: `shell/map/replay.gd` (plan B20); `replay_plan.gd` gains `record_battle` and battle poses (5.6). | `shell/map/replay.gd` does not exist. The file is `shell/map/move_replay.gd` (class `MoveReplay`). `core/views/replay_plan.gd`: `setup(records, speed)` (24), `poses()` (85). | B20 edits `move_replay.gd`; `replay_plan.gd` gains `record_battle(hex, tick)` and the `battles` key of `poses()`. The plan's name is wrong; the plan is not edited. | B20 |
| 30 | `DECISIONS` is a new state; `decisions_start`, `decisions_done` (6.6). | `State.DECISIONS` exists (`shell/app/season_flow.gd:8`), entered from `replay_done` (119-124, "none before M7"). The two functions do not. | B20 adds the two functions and the queue; it does not add the state. | B20 |
| 31 | The App's milestone becomes "7" (6 intro, 6.11, B28). **Body corrected.** | The value is `Bindings.SHELL_MILESTONE := "6"` (`shell/input/bindings.gd:247`), used by `shell/app/app.gd:97`. Also `shell/screens/options.gd:12` `TARGET_MILESTONE := 6.0`; `shell/screens/study.gd:15` `DEFAULT_MILESTONE "4"`. | B28 sets `SHELL_MILESTONE` to "7" and `TARGET_MILESTONE` to 7.0. The M7 `since: "7"` rows of B4 register only then. | B28, B4 |
| 32 | `map_command_storm` Shift+O; "Shift+O never also fires O" (6.1). | `map_command_key`, since 6, is bound to `O` and `Shift+F10` (`bindings.gd:146-147`). No `B` binding exists (checked). `view_mode_6` since 6 exists (`bindings.gd:68`). | B4 matches Shift+O exactly and tests that Shift+O fires storm only and plain O still fires the command key. | B4 |
| 33 | A new `map/castle_areas` row (6.1). | Absent. `shell/app/settings.gd` is 781 lines; the row (about 10 lines) leaves under 10 before lint's 800 line. | B4 writes the row compactly, or splits a settings group out first. | B4 |
| 34 | `season_ms` limit 380 (8, 9). | 320 with `known_over` #409 (`godot/tests/perf_core_budget.json:4`); its text says "the ten phases". | 380 keeps the #409 note until #409 closes; the text says thirteen. Owner question 3. | B18 |
| 35 | New rows: `battles_ms`, `fight_ms`, `sieges_ms`, `war_ms`, `areas_cold_ms`, `odds_ms`, `battle_view_ms`, `area_lines_ms`; `save_mb` with 60 records (8). | None of the names is in `perf_core_budget.json`; `save_mb` (8, mem) exists. UI rows in `perf_ui_budget.json` are not yet there. | Add the rows; no name clash. | B18, B29 |
| 36 | `movement_ms` 25 "(M6) with battles engaged at the ticks" (8). | 25 with `known_over` #418 (66 ms measured against 25). `supply_ms` #420, `vision_ms` #422, `cost_field_ms` #419, the army rows #423. No #424 is in the budget file. | Battles at the ticks raise the phase: the row keeps #418 and its text names the battles. A figure past the known number opens an issue. Owner question 3. | B12, B18 |
| 37 | `app.gd` stays under 800 (5, B28). | 796 lines, no `SIZE_REASONS` entry (`tools/lint_godot.py:50`). | B28 moves the war requests to `shell/app/war_requests.gd` before it adds a line. | B28 |
| 38 | `game_requests.gd` takes the M7 table (6.11). | 766 lines, 61 functions. M6 R12 asked for `shell/app/army_requests.gd`; it was never created: M6's requests sit in `game_requests.gd` and `app.gd`. | B28 creates `shell/app/war_requests.gd` for M7's requests. The M6 requests stay where they are (a split of them is not M7's). | B28 |
| 39 | Map scene takes the war marks, area lines and updates (6.3). | `shell/map/map_scene.gd` is 800 lines exactly; lint's limit is "over 800". | B25 puts the wiring in a child node (`shell/map/map_wars.gd`, as `map_armies.gd`) before any line is added to `map_scene.gd`. | B25 |
| 40 | Army and hex panels gain their M7 parts (6.8). | `shell/panels/army_panel.gd` 717, `hex_panel.gd` 651, `shell/mapview/tile_map_view.gd` 696. | `army_panel.gd` will pass 800: its war parts go into a child node first. Watch `hex_panel.gd`. | B26, B25 |
| 41 | B10: the preview counts today's occupations. | `core/views/economy_preview.gd` is 1,052 lines with a `SIZE_REASONS` entry (`tools/lint_godot.py:53`). | No M7 task edits this file. B10 must not grow it. | B10 |
| 42 | Top bar fit thresholds: six modes, the Army chip. | Already so: six mode segments and the Army chip (`shell/hud/top_bar.gd:24-25`; fit steps 155-159, 202, 220). The M7 page adds no chip. | None. A war chip would need its own fit step. | none |
| 43 | Kit names `PanelCard`, `PanelSlot`, `SectionHead`, `progress_fill` (5.6, 6.4, 6.5, 6.8). | None is a class name. The kit has `PanelFrame`, `PanelKit` (static `label`, `reason`, `fill_rows`), `VellumSheet.section_box`, `Cartouche`, `KitButton`, `KitSwitch`, `DeltaChip`, `Segmented`, `InkChart`, `StudyTable`, `CountryArms` (`shell/ui/`). `TugBar`, `DieFace`, `RegimentTile` are new. | Use the existing kit classes: the odds card is a `PanelFrame`, not a `PanelCard`. | B22, B23, B26, B27 |
| 44 | The move card (6.4). | `class_name MoveCard` (`shell/hud/move_card.gd:5`). | Name as is. | B26 |
| 45 | Overlay textures `occupier` and `area` (6.3). | The overlay has owner, heights, palette, ramp (and M6's supply). `shell/map/mode_overlay.gd` 574 lines. | As 6.3. | B21 |
| 46 | Bake slice 6 in `tools/ui_bake/pieces_m7.py`, `tools/bake_ui.py` (6.2). | `tools/bake_ui.py` and `tools/ui_bake/pieces_m6.py` exist; `pieces_m7.py` is new. | As 6.2. | B3 |
| 47 | `tests/core/test_vision.gd`; the tests named in 9 and B16. **Body renamed.** | `tests/core/test_sight.gd` exists; `ArmyFixture` (`tests/core/army_fixture.gd`), `tests/core/random_player.gd`, `tests/test_bake_ui.py` exist. | Use `test_sight.gd`; `war_fixture.gd` and `combat_fixture.gd` are new. | B3, B16, B17, B18 |
| 48 | B9's relief and "no progress beside a battle" cases (4.5, B9). | Battle records come from B8 in the same group C. | B9's tests build a `BattleRecord` by hand from B2's schema; B9 does not call B8's code. The group order holds. | B9 |
| 49 | B5 in group B: `Wars` for `at_war`, `enemies`, `occupied_count`, and `Territory.neighbours` (4.2, 5.3). | `Territory.neighbours` (`core/systems/territory.gd:154`), `Territory.transfer` (69), `Territory.owner_tag` (38), `Armies.men_of_country` (`armies.gd:54`) exist. | As the plan. | B5 |
| 50 | Works wait on occupied or besieged land (4.4, 5.3). | `Works.halted(game, work, turn)` exists (`core/systems/works.gd:293`); `Works.build_check` (18). | As the plan. | B6 |
| 51 | Economy functions (4.10, 5.3). | `Economy.district_output` (`economy.gd:271`), `EconomySeason.town_people` (17), `country_people` (22), `needs_of` (28), `made_of` (79), `money_lines` (212), `production` (235), `income` (267) exist. | As the plan; no rename. | B10 |

**Order of the groups (plan section 1).** Holds, with two notes. Group A (B1 to B4) is independent. Group C's B8 and B9 are
both in C: B9's cases that read a battle record use a hand-made record (row 48); nothing else crosses inside a group. The
dependencies that cross groups hold: B12 needs `Battles.engage` (C); B13 needs B9's `SupplyCache` or the view-cache keys
(row 6); B17 needs B12 and B13 (D); B20 needs `BattleView.latest_of` (E); B26 needs `OddsView` (F); B28 needs the decision
queue (B20), the dock (B22), the odds card (B26) and the marks (B25). No plan change. Two plan file lists are wrong and
are corrected here, not in the plan: B12 (row 3) and B20 (row 29).

**The M6 Army fields.** B2 needs only the classes of M6 (`Army`, `Unit`, `army/1`, `unit/1`), not any field M6 has not
built: its `standing` and morale are new. No task of M7 waits on an M6 change that is not in master.

**Acceptance note for B5, B8, B9 and B13 (added after the group A review, 2026-11-21).** The state classes (`War`, `Battle`, `BattleRecord`, `Siege`, `MapState` /5) check their own fields and caps in `from_dict`. The Game-level loaders do the cross-checks and the wiring: `wars`, `battles`, `battle_records`, `sieges` and the two name maps must be in `Game.digest`, `to_dict` and the snapshot, and on load every id they hold must exist (an army id in a battle is a living army, a war names two living countries, an occupier is a country id and sits on a land hex). B13 pins this with a save/load test that has live wars, sieges and records; B5, B8 and B9 each carry the acceptance line for their own class.

### Questions for the owner (design and scope; the engineering questions went to Fable)

1. **The standing words.** The standing is "Hold" or "Withdraw", and the army order is already "hold" (row 17). Keep
   "Hold" for the standing, or call it "Stand" to keep the two apart on screen?
2. **The key.** Shift+O is the storm key in 6.1, next to the plain O that already runs the command at the cursor (row 32).
   Is Shift+right click enough, with Shift+O only as the keyboard way?
3. **The budgets.** `season_ms` is already over its limit (#409, 771 ms on a shared machine) and `movement_ms` is over
   (#418). M7 raises `season_ms` to 380 and keeps `movement_ms` at 25 while battles run at the ticks. Accept those limits
   with the issues still open, or close #409 and #418 first?

---

**What M7 is.** Countries go to war. A country declares war on a neighbour; from then on each side's armies may enter the
other's land. An army ordered onto a hex where an enemy army stands **attacks** it: the two armies fight a **battle** of
lanes and days (battle slice 1) in the season's `battles` phase, right after the movement phase, and the battle is settled
inside that phase; the loser retreats, flees or surrenders. The map's **fortresses** are its districts with walls: the castle
pieces on the passes (watchtower, castle, fortress) and the walled towns and cities. A fortress has a **garrison** and
**holds the land around it**: enemy armies may walk and forage there but take nothing while it stands. An army that stands
alone on a hostile fortress **besieges** it: a meter fills each season from the besieger's men, its guns and the garrison's
hunger, and the place falls after two seasons at the least; or the army **storms** it, an assault battle with the garrison in
the centre lane. Land no fortress holds is **taken by walking in**. A taken district is **occupied**: its owner stays, its
controller changes, its output goes to the occupier at half, and the map stripes it in the occupier's colour. The war is
**ended by hand**: a peace that takes the districts you hold, a white peace, or a yield, each accepted or refused by a fixed
rule (the enemy is passive until M8), and a truce of eight seasons follows. The player sees it all: Declare war in the
country panel, the war alert as a decision before the report, the odds card on an attack, battle and siege badges on the
map, the castle areas with an army selected, the battle dock that plays a battle's days back, the hex and army panel's war
lines, the report's War section, the Military page's wars, battles and losses, and the War filter in the log.

**When it starts.** After M6 is closed (its plan's definition of done, and the owner has played it). M7 edits `Game`,
`Session`, `Events`, the action and season tables, `Unit`, `Army`, `MapState`, `Stats`, `StatsSystem`, `Armies`, `Military`,
`Movement`, `Supply`, `Sight`, `People`, `Works`, `Economy`, `EconomySeason`, `Knowledge`, the previews, the report's view,
the reminders, the log lines, the study's views and pages, the map modes, the mode overlay, the map scene, the floaters,
the replay, the season flow, the hex, army and country panels, the hex menu, the input and the App, and builds its screens
into the M1.5 frame as M6 left it.

**M7 is done when:**

1. **A war is declared.** On "Italy, 1480", seed 1480, as Savoy, in Spring 1480: `declare_war {target: MLO}` succeeds,
   `war_declared` reaches every living country, Milan's land opens to Savoy's armies and Savoy's to Milan's
   (`Movement.open_to`); `declare_war {target: VEN}` is refused with "only neighbours go to war: the Republic of Venice
   shares no border with the Duchy of Savoy", and a second declaration on Milan with "already at war with the Duchy of
   Milan" (`tests/core/test_war_savoy.gd`, section 4.16 (a)).
2. **Land is taken by walking in.** The Army of Ivrea (2 pikemen raised at Ivrea (6, 8) in Spring 1480), ordered to
   Domodossola (7, 6), walks Bard fort (6, 7) and Domodossola in Summer 1480 and takes it in Summer's `sieges` phase
   (`district_captured {by: walk}`): from that season's production Domodossola's goods and its people's taxes count for
   Savoy at half; the Owner mode stripes it in Savoy's colour; Savoy's war score against Milan is +1 (4.16 (b)).
3. **A battle is fought.** A Milanese army of 2 pikemen raised at Alessandria (7, 9) (the console's `as MLO raise`) is attacked
   by Savoy's 4 pikemen from Vercelli in Autumn 1480: the Battle of Alessandria, 1480 is fought in that season's `battles`
   phase in 1 to 8 days and ends with a winner and a loser; every man is booked (killed, wounded, wounded who returned);
   `battle_ended` carries the fields of the war-goals contract (5.5); the battle dock plays its days and ends on the same
   totals (4.16 (c)).
4. **A fortress is besieged.** An army of 4 pikemen (2,000 men) standing alone on Pavia (10, 9) (a walled town: fortress 2,
   garrison 800) takes it at the end of its fourth season of siege (the meter 2, 4, 6, 10 of 10, hunger from the fourth
   season); Pavia's area (Lodi, Piacenza, Cremona and 3 more) lies open from the next season; a save made in the third season
   of the siege loads and plays on to the same digest (4.16 (d)).
5. **The war is ended by hand.** In Spring 1481 `make_peace {target: MLO, terms: take}` is accepted and Domodossola and
   Locarno become Savoy's (`owners_changed`), every occupation between the two is cleared, every Savoy army on Milan's land
   goes to its nearest own hex with room, and for 8 seasons a new declaration is refused ("a truce with the Duchy of Milan holds until Spring 1483 (8 more
   seasons)"); in a copy of the game a white peace instead returns both districts to Milan (4.16 (e)).
6. **Men and districts are conserved.** `tests/core/test_war_property.gd` plays 40 seasons of the 1480 scenario with seeded
   random actions for every country (M1 to M7's actions: works, taxes, raises, marches onto enemies, storms, standing
   orders, declarations, peaces) and weather drawn, and finds every season, for every country: the change of its people plus
   its men under arms plus its garrisons equals grew − starved − left + dev − foraged − sacked − men its armies lost − men its
   garrisons lost (4.14); every land district has its owner, and an occupier only while that occupier is at war with the
   owner; owners change only at a peace (or `Game.dev_transfer`); no two countries' armies share a hex outside the battles
   phase; no battle is left after the battles phase; no garrison above its fortress's full men; every morale 0 to 1,000.
7. **Every action keeps its check.** `tests/core/test_check_contract.gd` (M6) drives the random player over the 17 actions of
   the table, 3,000 actions with 40 season ends: when the check says no, the action returns not ok and `Game.digest()` is
   unchanged; when it says yes, the action succeeds.
8. **Determinism, saves and the battle replay.** Same seed and same action log give the same digest after 40 seasons of war
   (`test_replay.gd`); save, load, save gives byte-equal files with wars, sieges, occupations, garrisons and battle records in
   them; a snapshot taken between the movement and battles phases (battles pending) restores and plays on to the same digest
   (`test_battle_replay.gd`); every battle record, fought again by `Combat.fight` from its own input and luck state, gives a
   record with the same digest; `SaveFile.FORMAT` is 5 and an M6 save reads as "Made by an older test build".
9. **Season time in budget.** On the made-up Europe (494 x 247 hexes, 60 countries, 600 armies, 30 wars) the CPU rows of
   section 8 hold in the nightly `perf_core.gd` run: the season's thirteen phases under 380 ms; the battles phase under 20
   ms with 20 battles of 8 against 8; the sieges phase under 25 ms.
10. Every M7 UI row of the standard's 9.1 is in the game, built from the M1.5 kit, each with its GUT test: Declare war and the
    war section in the country panel; the war alert as a `DECISIONS` screen; the odds card; battle and siege badges; the
    castle areas with a war army selected; occupied land striped in the Owner mode in both palettes; the battle dock with its
    day replay; the hex panel's fortress, area and siege lines with Storm now; the army panel's standing order, morale and
    siege; the report's War section; the Military page's wars, battles and the Battle losses; the War filter in the log and the
    war marks on the History timeline; the reminders for besieged and occupied land and the war timer. No stand-in is left.
11. Lint, import, check_scripts and GUT are green, with both UI `--check`s, `build_map --check` and `build_scenario.gd
    --check`; the art director has signed the war sheet and the pictures of section 9; the owner has played the build through
    the plan's checklist.

---

## 1. What is there, and where this page refines earlier pages

### 1.1 Read in the code (master `d62d440`), the map data and the specs

| Finding | Where | What it means for M7 |
|---|---|---|
| 14 families; `CASTLE` is family 2 with levels 1 to 3 (`HexCard.LEVEL_WORDS`: watchtower, castle, fortress); settlements 1 to 5 (hamlet, village, town, walled town, city); pair rule 12 "a walled town is its own fortress: no castle against its wall" | `core/systems/improve_rules.gd`, `core/views/hex_card.gd` | **Fortresses are pieces**: castles 1 to 3 and settlements 4 and 5 (D9) |
| The search puts castles only on pass hexes (watchtower or castle, `_domain_of`); a player may build a watchtower on a wild pass and upgrade it to a fortress ("only a watchtower can stand on a pass") | `core/systems/world_improve.gd` 592 to 640, 222 to 234 | Fortresses can be built and raised in play; the castle family's `FamilyDef.walls` (M4) is its pay |
| On seed 1480: 6 castle pieces (Hospice Splugen (10, 3) and Hospice Simplon (6, 4) watchtowers, Swiss; Hospice Little St Bernard (3, 7) castle, Savoy; (3, 12) watchtower, France (Col de Larche); (11, 13) castle, Milan (the Cisa); (5, 14) watchtower, Savoy (Col di Tenda)); 10 walled towns (Geneva, Brescia, Verona, Padua, Pavia, Ferrara, Bologna, Genoa, Florence, Pisa) and 2 cities (Milan, Venice) | `tools/worldmap/improve_report.gd -- --seeds=1480` (run read-only for this page) | 18 fortresses on 340 land hexes, 1 in 19: three times denser than v0.2.2's Europe (67 castles on 4,311 hexes), so the castle areas are shorter (D12) |
| `MapData.places[].castle` holds a historical castle per place (Milan 3, Bellinzona 3, Turin 2, Genoa 2, Pavia 2, Bard fort 1); no rule reads it; Bard fort (6, 7) is a place with no settlement, a wild hex | `data/maps/north_italy.tres` (read for this page) | Unread in M7 (D10): the walls of the game are its pieces |
| Savoy's neighbours are France, Genoa, Milan and Switzerland (M2's 24 pairs); Venice is not one | `m2-build-spec.md` 4.5 | Done-when 1's refusal |
| `MapState` holds `main_use`, `level`, `owner` (schema `map-state/4`); `Territory.transfer` writes `owner` and queues one `owners_changed` | `core/state/map_state.gd`, `core/systems/territory.gd` | M7 adds `occupier`, `garrison`, `unsupported` (map-state/5) and calls `transfer` only at a peace |
| `Actions.pair_of` is a `match`; `register_test_action` lets a test register a stub pair | `core/game/actions.gd` | M7 adds four pairs |
| `Confirm.configure({title, lines, choices, danger, on_result, ...})`; `ScreenStack` kinds `MODAL`, `OPAQUE`, `OVERLAY` | `shell/screens/confirm.gd`, `shell/ui/screen.gd` | The war alert and the declare and peace questions are `Confirm`s; the battle dock is an `OVERLAY` |
| `Bindings` parses key chords and the bare mouse buttons; "Shift+MouseRight" is not a parsable event | `shell/input/bindings.gd` 460 to 520 | Shift+right click is read by `MapInput` from the event's modifier, as M6's Shift+click (6.1) |
| `EdgeLineLayer` draws strokes and polygons per kind, one mesh a chunk; `TileMapView` has `BORDERS_Z := 85` and a `Borders` node | `shell/mapview/edge_line_layer.gd`, `tile_map_view.gd` | The castle area line is one more chunk kind, at z 82 (6.3) |
| `ModeOverlay` reads `owner_ids`, `heights`, `palette`, `ramp` (M2), with the M4.5 to M6 textures planned | `shell/map/mode_overlay.gd`, `.gdshader` | Two more R8 textures: `occupier` (stripes) and `area` (the castle-area tint) |
| v0.2.2 war: `war.py` (declare, score, peace, the siege meter, open land, castle areas), `battle.py` (engage, join, retreat, the end), `combat.py` (3 lanes, fire, back line, shock, flanks, morale, the break test, the flight), `battleview.py` (the fog rule, the odds card, the siege view), `battlelog.py` (the log as data), `areas.py` | `hexa/campaign/` | Section 3 |
| The approved designs: battle slice 1 and 1b, the 0.2.1 rule that a battle ends in the turn it starts (owner decision 2 of `docs/roadmap/release-0.2.1-brief.md`), sieges 0.2.2 (the meter, the floor, Besiege or Storm, the dial badge), castle areas (held and open land), war goals (the `battle_ended` contract, 3.4) | `docs/design/battle*.md`, `sieges-and-retreats.md`, `castle-areas.md`, `war-goals-and-peace.md` | Kept and re-fitted (section 3) |
| Built by M1.5 to M6 and named "(M2)" to "(M6)" below: `Territory`, `Countries`, `Works`, `Calendar`, `Season`, `Stats`, `StatsSystem`, `Chronicle`, `Luck`, `ViewCache`, `Snapshot`, `SaveFile`, `Replay`, `Knowledge`, `Words`, `LogLines`, `Reminders`, `SeasonSummary`, `Economy`, `EconomySeason`, `Treasury`, `Stores`, `DistrictCache`, `StateView`, `EconomyPreview`, `People`, `UnitDef`, `TerrainDef`, `Unit`, `Army`, `Armies`, `Military`, `StepCosts`, `PathSearch`, `Movement`, `Supply`, `SupplyCache`, `Sight`, `SightCache`, `ArmyView`, `MovePreview`, `SupplyView`, `StudyMilitary`, `StudyHistory`, `ReplayPlan`, `MoveReplay`, `ArmyTokens`, `ArmyPanel`, `MoveCard`, `HexMenu`, `PageMilitary`, `SeasonFlow`, `GameRequests`, `StudyWarm`, `perf_core.gd`, `PerfFixture`, `RandomPlayer`, `ArmyFixture` | their specs | M7 starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M7 | Why |
|---|---|---|
| M6 12, M7 row: "the battle hex rule (two countries share a hex only in a battle: `Army.battle`, `army/2`)" | **A battle never outlives the season's `battles` phase** (D5): it is made in the movement phase and settled in the next phase, so no army field marks it; `army/2` carries the army's **standing order** instead | The owner's 0.2.1 rule "it should end within the turn"; one place (`game.battles`) knows the live battles |
| M6 D4: "No generals (M7 with battles)"; M6 12: "`Military.stack_limit` (adds generals ...)" | **No generals in M7; they come with M11** (D36). The stack limit stays 8 a country, counted per side on a battle hex | Generals are traits, and traits belong with the research tree's definitions; M7's numbers are tuned without them |
| M2 13, M7 row: "a `controller` byte beside `owner`" | **`MapState.occupier`**: 0 when the owner holds the district, else the id of the country that occupies it (D13) | An owner change (a peace, the editor, `dev_transfer`) needs no second byte kept in step; `controller = occupier or owner` is one line |
| M2 13: "`Territory.transfer` for capture" | A capture changes the **occupier**, not the owner; `Territory.transfer` runs only at a peace (and in `dev_transfer`, tests and the editor) (D13) | v0.2.2: `province_captured` sets the controller; the owner changes at the peace |
| M2 4.6 and UI spec 6.5: "the pattern on occupied land comes with occupation (M7)" | Occupied land is **striped** with the occupier's colour over the owner's in the Owner mode and the Terrain tint, **in both palettes** (D52) | Colour is never the only cue (M2 4.6) |
| M3 4.2, M4 4.13, M5 4.8, M6 4.10: row 5 `war_timeouts` (M9) | Row 5 arrives early as **`war`**: the 40-season safety peace and its warning (D31); M9 adds its peace offers to the same row | The owner's 2026-11-13 decision "wars end by peace terms, with a 40-season safety timer only"; a war between two countries the player cannot end must still end |
| M3 4.9 and style spec 6.4: ten section ids (M6) | An eleventh, **`war`**, after `armies` (D47) | Battles, sieges, captures and peace are a story of their own; Armies keeps the armies |
| M3 6.3, M6 6.4: `DECISIONS` "empty until M7" | Filled: the war alert, one `Confirm` per war declared on the player in the season (D44) | Style spec 6.7 |
| M3 D46: "land lost under a work: cancelled `lost` at the next works phase"; M3 12: "`owners_changed` by capture cancels works `lost`" | A work on an **occupied or besieged** hex makes no progress (it waits); it is cancelled `lost` only when the owner changes at a peace (D20) | A capture is not a change of owner; the work goes on when the land comes back |
| M4 12, M7 row: "captured land produces for its new owner from the next production" | Occupied land produces **for its occupier, at half**, from the production of the season it is taken (captures fall before production); a besieged hex makes nothing; ceded land is its new owner's in full from the next production (D21 to D24) | 4.10 |
| M5 12, M7 row: "`district_declined` with `why` `sacked`" | A stormed walled town or city is **sacked**: 15 % of its people die (People flow `sacked`, appended); no district falls a level by war (D27). `district_declined`'s `why` keeps `hunger` and `people` | A breached wall was rebuilt; a sack killed people. One cause per effect |
| M5 12: "refugees (a flow) if M7 wants them" | **No refugees** (D28) | People never move between hexes (M5 D12); the conservation property stays exact |
| M5 12: "a besieged town eats its stores" | A besieged settlement takes nothing from its country's stores; once the garrison's stores are out it **starves** at M5's hunger rule with no food (D26) | The siege's hunger clock is the town's too |
| M6 D24: castles "not depots in M6" | A fortress its country owns and controls, not besieged, is a **depot** (D34) | M6's hand-over |
| M6 4.8: the supply field over "hexes held by `tag`" | Over the hexes the country **controls**; a hex with a hostile army is not walked (D34) | An enemy army cuts a supply line |
| M6 4.4: `Movement.open_to` "M7 adds the land of a country `hostile` to `tag`" | Kept; `Movement.hostile` becomes `Wars.at_war`; `open_mask` also closes every **hostile garrisoned fortress** but the route's goal (a march ends on a fortress, never passes it) (D39) | v0.2.2: a castle is taken or bypassed |
| M6 D21: zones of control "M7 makes it war, and adds castles" | Kept: an army stepping beside a hostile army **or a hostile garrisoned fortress** ends its leg there (D40) | v0.2.2 `zoc` |
| M6 4.7 row 7: "another country's army stands at ..." | For a country at war with the actor the goal is an **attack** and `Battles.engage_check` gives the verdict (D38) | M6's seam |
| M6 4.11: `unit_lost.why` (`starved`; M7 `battle`) | `battle` and `surrendered` | v0.2.2 |
| M6 4.15: `march_halted.why` `winter`, `blocked`, `no_way` | Adds `defeated` (the army lost a battle), `peace` (sent home), `shaken` (too shaken to attack) | Each halt has its words |
| UI plan section 4, M7 row: "the war alert (`Confirm`)" | A `Confirm` queued by a shell `DecisionQueue` and shown in `DECISIONS` (or at once when the declaration came while the flow was idle) | One door for M9's peace offers and M11's idea picks |
| UI plan section 4, M7 row: `shell/map/war_marks.gd`, `shell/hud/odds_card.*`, `shell/screens/battle_dock.*` | Kept, plus the castle-area chunk lines in `TileMapView` and the battle dock's `RegimentTile`, `BattlePicture` and the kit's `TugBar` and `DieFace` | The mockups 18, 20 and 21 |
| `game-feedback-screens.md` C.2: Diplomacy "(wars M7)" | M7's wars live on the **Military page** (a Wars table and a Battles table); M9's Diplomacy page takes the Wars table over | One page per milestone's content; Diplomacy does not exist before M9 |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days). Data changes are a
`.tres` edit plus the test that pins the value.

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | Who may declare war | A living country on a **neighbour** (M2's `Territory.neighbours`, by owner), not at war with it, out of truce. No casus belli, no goal (M9) | v0.2.2's `war_check`; war goals are M9's | S |
| D2 | What war opens | Each side's land (by owner) is **open** to the other's armies; armies of the two may attack each other; fortresses may be besieged | v0.2.2 `may_enter` | none |
| D3 | Allies | **None.** A war has two countries; a country may be in several wars | M9's alliances | M9's work |
| D4 | How a battle starts | **An army steps onto a hex where an army of a country at war with it stands** (in the movement phase, at its tick); an army with a **storm** order also starts one on arriving at a hostile garrisoned fortress | M6's tick seam; v0.2.2's attack order | M |
| D5 | How long a battle lasts | **To its end in the `battles` phase of the season it starts**, at most `battle_days` (8) days; nothing carries over (owner decision 2 of 0.2.1). At the cap the side with the lower front morale withdraws | The owner: "it should end within the turn"; the 0.2.3 battle board (a mini game between days) is a later milestone | S (a day cap per season instead) |
| D6 | The battle's field | **Three lanes** (left, centre, right) and a reserve a side; the right lane is closed on narrow ground; ranged companies in the reserve fire; lanes and days as battle slice 1 and 1b (fire, back line, shock, flanks, morale, the break test, the flight) | Battle slice 1 (the standard's "keep lanes and days"); width 3 to 7, the back slots and rotation are the battle board's | L |
| D7 | Luck in a battle | Each side's d6 a day (0.7 to 1.4) and a spread on every hit (0.5 to 1.5), drawn from **`Luck.world`**, battles in hex index order | v0.2.2 slice 1b; one stream (standard 5.4) | Data (S) |
| D8 | Joining | An army of a side that steps onto the battle hex in the same movement phase joins its side's reserve, up to the stack limit a side (8) | v0.2.1: "to reinforce, attack the same hex with a second stack in the same season" | S |
| D9 | What a fortress is | A district whose piece has walls: **castles 1, 2, 3** (watchtower, castle, fortress) give fortress levels 1, 2, 3; a **walled town 2**, a **city 3** (`FamilyDef.fortress`) | The standard's "castles are districts with levels"; pair rule 12 already says a walled town is a fortress | Data (S) |
| D10 | `MapData.places[].castle` | **Unread** | It would put a fortress on wild Bard fort and make Turin and Bellinzona fortresses with no walls drawn and no walls upkeep; the pieces are one source | S |
| D11 | Garrisons | **400 men a fortress level** at full (600 per level in v0.2.2, scaled to 500-man companies); a fortress its owner holds and nobody besieges regrows **100 men a level a season**, levied from the people of its hex and its ring (People flow `garrisoned`); an occupied fortress has no garrison | v0.2.2's garrison and regrowth; no man from nowhere (M5) | Data (S) |
| D12 | Castle areas | A fortress **holds** its owner's land within **1, 2 or 3 hexes** by fortress level, counted along that land, never across a crest without a pass; each hex belongs to its nearest fortress (ties: the higher level, then the lower index). North Italy: 139 of 340 hexes held (41 %) | `castle-areas.md` way B; v0.2.2's 3, 4, 5 would hold 233 (69 %) on this denser map, and the design wanted about a third | Data (S) |
| D13 | Occupation | `MapState.occupier` per hex (0: the owner holds it); the **controller** is the occupier or the owner. Captures, storms and retakes write it; a peace or the timer clears it. The owner never changes in war | v0.2.2's controller; M2's byte, simplified (1.2) | M |
| D14 | Taking land | An army of at least `militia_men` (250) standing alone at the end of a season on a hostile district that **no standing fortress holds** takes it (`by: walk`); held land is not taken; your **own** occupied land is retaken the same way, held or not | `castle-areas.md` 2.3 | S |
| D15 | Taking a fortress | **Besiege** (the default: an army alone on a hostile garrisoned fortress starts the meter) or **Storm** (an assault battle); a fortress with no garrison is walked into | `sieges-and-retreats.md` 4.5 | S |
| D16 | The siege meter | need = 4 + 3 x level x the garrison's share (up) + the ground's elevation; rate = crowd (besieger's men over the garrison's: under 1x none, 1x 1, 2x 2, 4x 3) + guns (a bombard battery 1), at most 6; hunger +2 a season once the stores (1 + level seasons) are out; it falls at the end of a season in which the meter reaches the need, **never before 2 seasons** | 0.2.2's meter and floor | Data (S) |
| D17 | A fortress falls | Its land lies **open from the next season** (each hex taken by walking in); a fortress its owner retakes holds again | `castle-areas.md` 2.3, points 4 and 5 | S |
| D18 | Land with no support | An occupied district with **no army of its occupier within 3 hexes** and no garrison for **6 seasons** in a row goes back to its owner (`by: freed`) | v0.2.2's "the people drive out a garrison nobody supports" | Data (S) |
| D19 | Storming | Storm faces the garrison cut by half the siege's share done; a won storm takes the fortress at once and **sacks** a walled town or city (D27) | 0.2.2's storm cut | Data (S) |
| D20 | Works in war | A work on an occupied or besieged hex makes no progress; none can begin there ("held by the Duchy of Savoy: no work can begin on occupied land") | 1.2 | S |
| D21 | Occupied output | Goods, port dues and the people's taxes of an occupied district count for the **occupier**, each **at half** (`occupied_output_permille`, `occupied_tax_permille` 500); its towns' needs are taken from the occupier's stores in full | M4's hand-over ("occupation may cut output"); feeding a taken city is the occupier's burden | Data (S) |
| D22 | Upkeep in war | Nobody pays the upkeep and walls of an occupied or besieged district | The occupier does not keep it; the owner cannot | S |
| D23 | A besieged hex | Makes nothing, pays nothing, takes nothing from the stores, and its people do not grow | 0.2.2: "the besieged province's output is lost while the siege lasts" | S |
| D24 | Ceded land | Is its new owner's in full from the next production (the peace is an action, or the war phase, which both fall before production) | M4's hand-over | none |
| D25 | People of occupied land | Stay where they are and are booked on their **owner** (People flows); they grow by the controller's tax level and food | M5 D12; people belong to the land | S |
| D26 | Besieged people | Grow nothing; once the garrison starves (the siege's hunger) the settlement loses people at M5's hunger rule with food 0 | 1.2 | Data (S) |
| D27 | Sacking | A stormed walled town or city loses `sack_permille` (150) of its people (People flow `sacked`) | 1.2 | Data (S) |
| D28 | Refugees | None | 1.2 | L |
| D29 | War score (the M9 seam) | `Wars.score(a, b)` = districts of b that a occupies − districts of a that b occupies, + 3 when a holds b's capital, − 3 the other way; symmetric. M9 replaces the body (worth by level, battle points) | v0.2.2's `war_score`, made symmetric | M9's work |
| D30 | Peace | `make_peace {target, terms}` with terms **take** (the districts you occupy, the capital and a last district excepted, become yours), **white** (everything returns) or **yield** (the enemy takes the districts it occupies); the passive enemy accepts by v0.2.2's rule: take at score ≥ 3, or ≥ 1 when its men under arms are not above yours; white at score ≥ −1 after 4 seasons of war; yield always | v0.2.2 `peace_offer`; the standard's "ended by hand against a passive enemy" | S |
| D31 | Ending a war otherwise | A war of **40 seasons** ends in white peace in the `war` phase; a reminder 8 seasons before | The owner's 2026-11-13 decision (war-goals 3.8) | Data (S) |
| D32 | Truce | **8 seasons** after any peace, no declaration between the two | Stops declare, take, declare; M9 sets 12 after terms | Data (S) |
| D33 | A country that would fall | A peace never takes a country's last district (its capital, or its most populous district when the capital is off the map) | Countries that fall are M12's | S |
| D34 | Supply in war | The field runs over the land a country controls; depots are controlled settlements of level 2 or more, ports, and owned fortresses not besieged; a hex with a hostile army is not walked | M6's hand-over | S |
| D35 | Morale | Each company keeps a morale (0 to 1,000, `unit/2`); a battle drains it; it recovers 250 a season in the `ready_units` phase when its army was fed; an army under 500 cannot attack | Battle slice 1 | Data (S) |
| D36 | Generals | **None in M7** (M11) | 1.2 | M |
| D37 | Experience | A company gains 2 experience for a won battle and 1 for a lost one (only when a day was fought); 3 makes it Veteran (×1.1 attack, defence, morale loss ÷1.1), 7 Elite (×1.2) | v0.2.2 `VETERAN_RANKS` | Data (S) |
| D38 | The attack order | **A march onto a hex with an army of an enemy** is the attack (M6's row 7 seam); its refusals come from `Battles.engage_check` | One order, the M6 door | none |
| D39 | Marching past a fortress | A route never passes a hostile garrisoned fortress; it may end on one (a siege) | v0.2.2 | S |
| D40 | Zones of control | Beside a hostile army or a hostile garrisoned fortress a leg ends | M6 D21 | S |
| D41 | The standing order | Each army has one, **Hold** (default) or **Withdraw**: the stance it takes when attacked; Withdraw leaves from the end of day 2 at a price (5 % of its men, 25 points of morale) and only when a retreat hex exists | The 0.2.1 rule; the player's decision before contact | S |
| D42 | After a battle | The loser retreats (a Withdraw to its own land; a broken army to any free land, its own first) within 6 steps, or **surrenders**; half the wounded of each side come back where it ends in supply | Battle slice 1, 0.2.1 | S |
| D43 | Battle records | Every battle leaves a **record** (its input, a frame a day, its end, the luck state before its first day); the newest **60** are kept and saved; `battle_ended` carries the record's id and totals | The dock plays the days back (the standard's read-only battle view); the replay test fights it again | Data (S) |
| D44 | The war alert | A war declared on the player queues a `Confirm` shown in `DECISIONS` before the report (or at once at idle): "Show the Duchy of Milan" or "To the report" | UI spec 2; style spec 6.7 | S |
| D45 | The battle dock | An `OVERLAY` on the left, 420 px (design 18 option A), read-only: the face-off, the dice, the front morale, the lanes and reserve of the day shown, the log, the result, and a day stepper that plays the days back | The mockup; the battle is over when the player sees it (D5) | M |
| D46 | Badges | The **battle sites** of the season that ended (crossed swords in a ring tinted by result, with the front-morale bar) and the **live sieges** (the amber dial, 0.2.2's option B) | The sieges doc's recommendation, built in v0.2.2 | S |
| D47 | The report | An eleventh section, **War** (1.2); war chips in At a glance; declarations, peaces, standing orders and storms in Your orders; others' witnessed battles, captures and public wars in What befell | Style plan S5, M7 row | S |
| D48 | Events | `war_declared`, `peace_made`, `battle_started`, `battle_joined`, `battle_fought`, `battle_ended`, `siege_started`, `siege_progress`, `siege_lifted`, `district_captured`, `controllers_changed` (5.5) | The brief's list, with M2's capture renamed for districts | S |
| D49 | Who hears of a war | `war_declared` and `peace_made` reach **every living country**; battles, sieges and captures their sides and the countries that see the hex | M6's risk note: "M7's war events are public"; sight for what happens on a hex | S |
| D50 | The odds card | One word from the strength ratio (men x morale), divided by the defender's ground factor; for a fortress "Besiege: falls in about N seasons" and Storm's word; bands and factors start at v0.2.2's and are re-fitted by `war_report.gd` (B18) | Battle slice 1 PR 7b; sieges 4.6 | Data (S) |
| D51 | Castle areas on the map | With an army of yours selected and a war on, the areas the enemies' standing fortresses hold get a **dashed ink line** in the owner's colour and a 12 % tint (`map/castle_areas`, on) | `castle-areas.md` 4: "one map view is never cut" | S |
| D52 | Occupied land on the map | Diagonal stripes of the occupier's colour, 8 px, over the owner's colour in Owner mode and the Terrain tint, both palettes | 1.2 | S |
| D53 | Keys | Shift+right click (or **Shift+O**) orders a storm; **B** opens the dock on your newest battle | Keyboard play; B is free | Bindings (S) |
| D54 | The season | M7's `PHASES`: **movement, battles, supply, sieges, war, production, income, works, people, stats, calendar, ready_units, vision** (4.13) | The standard's rows 2 to 5 | S (the pin) |
| D55 | Saves | `SaveFile.FORMAT` **5**, `OLDEST_FORMAT` 5; body key `war`; `map-state/5`, `army/2`, `unit/2` | An M6 save's digest has no occupation or morale, so it could never match its header | S |
| D56 | The sandbox | No wars ("this map has no countries") | No countries | none |
| D57 | The console | `declare TAG`, `peace TAG take|white|yield`, `storm ID c r`, `standing ID hold|withdraw`, `wars`, and M6's `as TAG` prefix | The playtest needs an enemy army and a war on the player before the AI exists | S |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| `War(a, b, start)`; `at_war`, `enemies`; `war_check` (not self, alive, not at war, only neighbours); `declare_war` emits `war_declared` | `systems/war.py` 38 to 65, `state.py` 216 | The checks and their order; the event | Words as M2's ("the Duchy of Milan"); a truce row (D32); ended wars kept for the Military page |
| `war_score` = taken − lost + 3 for the capital | `war.py` 68 | The terms | Symmetric (D29); M9 replaces it |
| `peace(a, b, winner)`: battles end first, controlled provinces go to the winner (capitals return), sieges between them end, stacks in the other's land go home or are evicted, `peace_made`; `peace_offer` take/white/yield with their acceptance rule | `war.py` 84 to 165 | All of it | The last district is never taken (D33); armies are sent to the nearest own land with room or, with none, disbanded home (men never lost); a truce (D32) |
| `war_timeouts`: 16 seasons (AI), 32 (player), or score 5 between AIs | `systems/season.py` 34 | A war that cannot last forever | The 40-season white peace only (D31; the owner's decision for M9) |
| `targets`, `attack_options_group`, `attack_group`: a stack walks beside the target and `engage`s | `war.py` 176 to 243 | Attack, join, overrun | The attack is a march order walked in the movement phase (D4, D38); no civilians to overrun (M6 has none) |
| `engage_check`: one country, no ships, land, beside, no ridge between, regiments, `ATTACK_MORALE` 0.5, not in another battle, fits, an enemy, at war | `systems/battle.py` 97 to 146 | The reasons that still apply | Distance and ridges are the route's (M6); the rest are rows of 4.7 |
| `Battle` state: lanes, routed, carry, wounded, men0, killed, garrison morale, log, members, name, crossing, uphill, broken, held, storm cut | `state.py` 223 | Every rule they carry | The live `Battle` holds only what the battle starts with (5.2); the day state lives inside `Combat.fight`, the history in the record (D43) |
| `combat.py`: `deploy` (centre first, infantry centre, cavalry flanks, artillery last, best defence, lowest id; a reserve moving up after day 0 is shaken), `fire` (guns at the centre), `backline`, `shock`, `flanks` (×1.25), `morale` (5 per share lost, drains 0.02 and 0.03, hunger 0.03), `breaker` (empty centre, two lanes, front morale under 0.10), `pursuit` (the flight: 15 %, guns lost, morale 0.15); `STANCE` attack 1.2/1.1, hold 0.9/0.8; `DICE` 0.7 to 1.4; `HIT_SPREAD` 0.5; `FIGHT_ATTACK`, `FIGHT_DEFENSE`; `PIKES_VS_HORSE` 1.25; `CASTLE_DEFENSE` 0.25 a level; the garrison a fighter of attack 3 and defence 3 + 2 a level | `systems/combat.py`, `data.py` 346 to 400 | The phases, their order, their numbers | Whole numbers: men and permille instead of hit points and floats (5.3); crossbowmen join as a ranged arm firing from the reserve at 0.025 (`battle-size-and-frontage.md` 4.4); the terrain defence from cover and relief (4.6); a river crossing penalty on day 1 (rivers are edges now) |
| `_fight_season`: days until a side goes, Withdraw from the end of day 2, the cap of 8 days; `_end_battle`: retreat or surrender, experience, wounded back in supply, the storm, `battle_ended` with its contract | `battle.py` 559 to 687 | All of it | The retreat walks M6's step costs; armies, not stacks; the record (D43) |
| `retreat_spot`: 3 x SCALE (6) steps, own land first, then nearest, then farthest from the enemy, then lowest position | `battle.py` 343 | All of it | Steps over `StepCosts` (BLOCKED and CLOSED edges are walls) |
| The siege meter: need, crowd, guns, hunger, the 2-season floor, the storm cut, lift on relief, fall; `MILITIA_MEN` 500; garrison regrowth; "driven out" after 6 seasons | `war.py` 275 to 557 | All of it | Garrisons 400 a level and militia 250 for 500-man companies; regrowth from the people (D11); occupied fortresses keep no garrison |
| Castle areas: reach 3, 4, 5 by level along own land, nearest castle; held, fallen, open; open land taken at once at the season's end | `systems/areas.py`, `war.py` 428 to 557 | The rule and the states | Reach 1, 2, 3 (D12); walled towns and cities hold land too (D9) |
| `battleview.py`: the fog rule (exact to a side, rounded when seen, hidden), the odds view (strength ratio over the ground factor, the garrison weighted 3.1 behind a field army and 1.8, 1.1, 1.0 alone), the siege view (meter, rate, hunger, falls in, relief) | `battleview.py` | All of it | A battle's view is read from its record, which outlives the battle (D43) |
| `battlelog.describe`: records as data, words made when shown | `battlelog.py` | The rule | Records are the frames of 5.2; the words are `BattleView`'s |
| `ODDS_WORDS` (Hopeless, Poor 0.8, Even 1.0, Favourable 1.2, Overwhelming 2.5), `GROUND_ODDS` (hills 1.34, forest 1.40, marsh 2.08, mountains 3.39, snow 2.92) | `data.py` 417 to 440 | The words and starting values | Re-fitted on the district map by `war_report.gd` (D50) |

---

## 4. Design content

### 4.1 The model in one picture

```
 during the season (actions, any country)
   declare_war {target}                 Wars: a War, both lands open                         -> war_declared
   march {army, goal}  (M6)             a goal with an enemy army is an attack (engage_check)
   storm {army, goal}                   march, and storm on arrival (or now, when besieging)
   set_standing {army, standing}        Hold or Withdraw when attacked
   make_peace {target, terms}           take / white / yield; occupations cleared; truce      -> peace_made, owners_changed
 movement   (M6) ticks; a step onto an enemy army's hex starts a Battle (or joins one); a step beside an enemy army or
            fortress ends the leg; a storm order arriving starts an assault        -> battle_started, battle_joined
 battles    storms of besiegers; every battle fought to its end (Combat.fight), records kept; losers retreat or surrender;
            a won storm takes the fortress and sacks a town                        -> battle_fought, battle_ended, unit_lost,
                                                                                      district_captured
 supply     (M6) over controlled land; enemy armies cut lines
 sieges     every army alone on hostile land: a garrisoned fortress -> the meter; open land -> taken; own land -> retaken;
            held land -> nothing. Garrisons regrow; unsupported occupations go back -> siege_*, district_captured
 war        a war of 40 seasons -> white peace                                     -> peace_made
 production, income   occupied districts for the occupier at half; besieged hexes nothing (M4, M5 edits)
 works, people, stats, calendar   (M3 to M5; works wait on occupied land; besieged towns starve)
 ready_units  (M6) refill; morale +250 for fed armies
 vision     (M6) sight from controlled land and armies
```

### 4.2 War: declaring, the score, the truce

`Wars.declare_war_check(game, {target, tag})`, in order (the first refusal is the verdict):

| # | Case | Verdict |
|---|---|---|
| 1 | No target given | "no country given" |
| 2 | The game has no countries | "this map has no countries" |
| 3 | `tag` is `&""` | "choose your country first" |
| 4 | No country has `tag` or `target` | "no country %s" |
| 5 | `target` is `tag` | "a country cannot make war on itself" |
| 6 | Either is not alive | "%s is no more" (the name) |
| 7 | They are at war | "already at war with the %s" (the long name) |
| 8 | A truce holds (4.9) | "a truce with the %s holds until %s (%d more seasons)" (`Calendar.date_text` of the first season it may) |
| 9 | `target` is not in `Territory.neighbours(tag)` | "only neighbours go to war: the %s shares no border with the %s" |
| 10 | Otherwise | ok |

`declare_war` checks again, appends a `War` (id `next_war_id`, `a` the actor, `b` the target, `start_turn` = `game.turn`), and
emits `war_declared {tag, target, war, witnesses: every living country}`. Nothing else changes: armies already in place stay;
the next movement phase may attack.

**The score** (`Wars.score(game, a, b)`, the M9 seam): `occupied(a in b) − occupied(b in a) + capital_score x (a holds b's
capital) − capital_score x (b holds a's capital)` with `capital_score` 3; `occupied(x in y)` counts y's districts whose
occupier is x. A capital off the map counts for nobody. `score(b, a) == −score(a, b)`.

**A war's record** (`War`, 5.2): its start, its end and terms, the battles each side won, the men each lost in battle, and
the districts that changed owner at its peace. Ended wars stay in `game.wars` (a dozen in a long game): the Military page's
Wars table and the truce read them.

### 4.3 Fortresses, garrisons, castle areas

`Occupation.fortress_level(game, hex)` = `FamilyDef.fortress[level]` of the hex's piece (`main_use`, `level`):

| Piece | Fortress level | Full garrison (`garrison_per_level` 400 x level) | Holds land within | Regrows a season |
|---|---|---|---|---|
| Watchtower (castles 1) | 1 | 400 | 1 hex | 100 |
| Castle (castles 2), walled town (settlements 4) | 2 | 800 | 2 hexes | 200 |
| Fortress (castles 3), city (settlements 5) | 3 | 1,200 | 3 hexes | 300 |

**Garrisons.** `MapState.garrison` holds each fortress hex's men (0 elsewhere). A new game sets every fortress to full
(`Occupation.setup`). In the `sieges` phase a fortress its owner holds (occupier 0), with no siege and no hostile army on it,
regrows `garrison_regen_per_level x level` men up to full: `People.levy(..., why &"garrisoned")` on the hex, then on its ring
hexes its owner holds and controls, in direction order, each up to `People.available` (M5). A fortress whose level falls
(a clear work, a sack does not) gives its excess men back (`People.give_back`, flow `returned`). A captured fortress's
garrison is lost (booked as garrison losses, 4.14) and an occupied fortress keeps none.

**Areas** (`Occupation.area_of(game, hex)`, the derived `WarCache`). For each fortress in hex index order, a walk over its
owner's land (`owner` equal to the fortress's owner), never across a crest edge without a pass (M6's `StepCosts` BLOCKED by
crest), up to `area_reach[level]` (1, 2, 3) steps; a hex belongs to the nearest fortress, ties to the higher level, then the
lower hex index. `Occupation.area_state(game, hex)`:

| State | When | What an enemy army may do there |
|---|---|---|
| `castle` | the hex is a fortress | besiege or storm it (4.5, 4.7); walk in when its garrison is 0 |
| `held` | its owner controls it and its fortress stands (the fortress's owner controls the fortress) | stand, forage; take nothing |
| `fallen` | its owner controls it and its fortress is occupied | take it by walking in |
| `open` | no fortress holds it, or it is occupied | take it (an enemy) or retake it (its owner) by walking in |

The membership depends only on owners and pieces; "held" or "fallen" is read from the fortress's occupier when asked. The
`WarCache` is dropped by `Game.emit` on `owners_changed` and on `hex_changed` of a hex whose fortress level changed.

**North Italy on seed 1480** (worked out from the map data and the improvement report with these rules for this page;
`tests/core/test_occupation.gd` pins it):

| Fortress | Owner | Level | Garrison | Its area (hexes, the fortress included) |
|---|---|---|---|---|
| Hospice Splugen (10, 3) | Switzerland | 1 | 400 | 4 |
| Geneva (1, 4) | Savoy | 2 | 800 | 9 |
| Hospice Simplon (6, 4) | Switzerland | 1 | 400 | 5 |
| Brescia (13, 6) | Venice | 2 | 800 | 7 |
| Hospice Little St Bernard (3, 7) | Savoy | 2 | 800 | 13 |
| Venice (18, 7) | Venice | 3 | 1,200 | 16 |
| Verona (15, 8) | Venice | 2 | 800 | 6 |
| Padua (17, 8) | Venice | 2 | 800 | 5 |
| Milan (9, 9) | Milan | 3 | 1,200 | 17 |
| Pavia (10, 9) | Milan | 2 | 800 | 7 |
| Ferrara (16, 10) | Ferrara | 2 | 800 | 6 |
| (3, 12) (the Col de Larche) | France | 1 | 400 | 4 |
| Bologna (16, 12) | Papal States | 2 | 800 | 7 |
| Genoa (8, 13) | Genoa | 2 | 800 | 12 |
| (11, 13) (the Cisa) | Milan | 2 | 800 | 5 |
| (5, 14) (the Col di Tenda) | Savoy | 1 | 400 | 5 |
| Florence (15, 15) | Florence | 2 | 800 | 7 |
| Pisa (13, 16) | Florence | 2 | 800 | 4 |

Held land by country (of its land): Switzerland 9 of 45, Savoy 27 of 58, Venice 34 of 42, Milan 29 of 52, Ferrara 6 of 12,
France 4 of 34, Papal States 7 of 20, Genoa 12 of 14, Florence 11 of 14; Austria, Mantua, Siena and Lucca have no fortress
(all open). In all 139 of 340 (41 %). Milan's open land is its Alpine north (Bellinzona, Lugano, Locarno, Domodossola, Como,
Chiavenna, Sondrio, Lecco, Bormio and the passes), (13, 8), (13, 9) and Parma; Milan's own area holds Novara, Alessandria,
Monza and Varese; Pavia's holds Lodi, Piacenza, Cremona, (12, 8), (12, 10) and (11, 11). Savoy's heartland (Turin,
Vercelli, Ivrea, Asti) is open: its fortresses are Geneva and the passes.

### 4.4 Occupation: taking, retaking, losing

In the `sieges` phase, every land hex where armies of exactly one country stand and no battle was fought this season, and
which no army of that country retreated onto this season (from this season's battle records), in hex index order. Let `t` be
that country, `c` the hex's controller:

| Case | What happens |
|---|---|
| `t == c` | nothing (a fortress of `t`'s regrows as 4.3) |
| `t` is the hex's owner and `c` is not (own land occupied by an enemy) | retaken when `t`'s men there are at least `militia_men`: occupier 0, `district_captured {by: retaken}` (a garrisoned enemy hold cannot exist: occupied fortresses have no garrison) |
| `t` is not at war with `c` | nothing |
| a fortress with garrison > 0 | the siege (4.5) |
| `area_state` is `held` (read from the fortresses standing at the phase's start) | nothing |
| otherwise (open, fallen, a fortress with no garrison) and `t`'s men there are at least `militia_men` (250) | taken: occupier = `t`, `district_captured {by: walk}`; a fortress taken this way opens its area (4.5's fall) |

**Freed land** (D18): every occupied hex with no army of its occupier within `support_range` (3) hexes and no garrison adds one
to `MapState.unsupported`; at `unsupported_seasons` (6) it goes back to its owner (`district_captured {tag: owner, by:
freed}`); an army of the occupier within reach resets the count to 0.

Every change of an occupier in a phase or action is batched into one `controllers_changed {hexes, tag, others}` at its end
(`Occupation.flush`), which the map, the supply and sight caches and the war cache hear through `Game.emit`.

### 4.5 Sieges

**When.** In the `sieges` phase (4.4) an army of `t` alone on a fortress with a garrison, at war with its controller,
starts a `Siege` (`siege_started`; its name "Siege of Pavia, 1480", "Second Siege of Pavia, 1481" for a repeat) and the
arrival season counts; a running siege goes on. A siege makes no progress in a season in which a battle was fought on its
hex.

**The numbers** (`Sieges.terms(game, hex, t)`; the need is `Occupation.siege_need`, which the storm cut also reads):

```
garrison  = MapState.garrison[hex]                        (men)
full      = garrison_per_level x level
need      = siege_base_need (4) + ceil(siege_per_level (3) x level x garrison / full) + relief_elevation[relief]
            relief_elevation by relief level 0..6: 0, 0, 0, 1, 1, 2, 2   (hills and highland 1, mountains and peaks 2)
men       = the men of t's armies on the hex
crowd     = 0 when men < garrison; 1 under 2x; 2 under 4x; 3 from 4x   (crowd_bands 2000, 4000 permille)
guns      = the siege_points of t's companies there (a bombard battery 1)
rate      = min(siege_rate_max (6), crowd + guns), 0 when crowd is 0 (too few men: no siege)
stores    = 1 + level   (seasons)
hunger    = siege_hunger (2) in each season after the stores are out
```

Each season: `seasons += 1; progress += rate + hunger; siege_progress {progress, need, rate, hunger, seasons}`; the place falls
when `seasons >= siege_min_seasons (2)` and `progress >= need`.

**Lifted** (`siege_lifted {why}`, at the start of each siege's turn in the `sieges` phase): `t` is no longer at war with the
hex's controller (`peace`; until then no view shows a siege between countries at peace); `t` fought a battle on the hex this
season and lost it (`relief`, read from this season's records); no army of `t` is left on the hex (`left`); the crowd fell to
0 (`outnumbered`). A siege whose hex `t` now controls (a storm) is removed without an event. Progress, seasons and hunger go
to 0; the next siege starts afresh.

**Falling**: `district_captured {by: siege, name, seasons, opened}` with `opened` the districts of its area its owner still
controls; occupier = `t`; the garrison's men are lost; the siege is removed. Its area lies open from the next season (the
phase reads the standing fortresses at its start).

**Seasons to take** (no guns but where said, plain ground, full garrisons; `tests/core/test_sieges.gd` pins every cell):

| Besieger | Watchtower (need 7, 400 men) | Castle or walled town (need 10, 800) | Fortress or city (need 13, 1,200) |
|---|---|---|---|
| 1 company of pikemen (500) | 4 (crowd 1: 1, 2, 5, 8) | cannot (500 < 800) | cannot |
| 2 companies (1,000) | 3 (2, 4, 8) | 6 (1, 2, 3, 6, 9, 12) | cannot |
| 4 companies (2,000) | 3 (3, 6, 11) | 4 (2, 4, 6, 10) | 7 (1, 2, 3, 4, 7, 10, 13) |
| 8 companies (4,000) | 3 (3, 6, 11) | 4 (3, 6, 9, 14) | 6 (2, 4, 6, 8, 12, 16) |
| 6 pikemen and 2 bombards (3,200, guns 2) | 2 (5, 10) | 2 (5, 10) | 4 (4, 8, 12, 16) |

Read: a watchtower holds out three or four seasons against a field army without guns; a walled town four to six; a city six
or seven; guns halve it. Hills add one to the need, mountains two.

### 4.6 Battles

**Start** (`Battles.engage(game, army, hex, tick)`, from the movement phase; the checks are `engage_check`'s, 4.7):

- A battle on the hex whose side the army's country is: it **joins** (`battle_joined`), when its side's companies there plus
  its own stay within the stack limit (8).
- Else an army of a country at war with the army's stands there: a new `Battle`; the attacker is the stepping army's country,
  the defender the country of the lowest-id army on the hex. It is an **assault** when the hex is a fortress the defender
  controls with a garrison: the garrison holds the defender's centre.
- Else (no army) a hostile garrisoned fortress and the army's order is `storm`: a new assault battle with the garrison alone.
- The battle keeps the attacker's last step: `crossing` (the edge is a pass edge), `uphill` (the stand hex's relief is under
  the battle hex's), `river` (the edge has a river of class 1 to 3 and no bridge). Its name is set now: "Battle of
  Alessandria, 1480" (the hex's place; else the nearest named place within 2 hexes; else "Battle at (3, 8), 1480"), "Second
  Battle of ..." for a repeat (the count per place in `battle_names`). `battle_started {tag: attacker, hex, others:
  [defender], defender, assault, name, year, tick}`.

**The battles phase** (`Battles.season(game)`): first every army whose order is `storm` and that stands on its goal (a hostile
garrisoned fortress it besieges) starts its assault; then every battle, in hex index order, is fought by `Combat.fight` from an
**input** built of the live state (5.2) with `game.luck.world`, and its result applied (4.6, the end). `game.battles` is empty
after the phase.

**Stances.** The attacker fights on **Attack**; the defender on its first army's **standing order**: Hold, or Withdraw when a
retreat hex exists for it (else Hold).

**Ground** (`Combat.ground_of(game, hex)`):

| Term | Rule |
|---|---|
| Rough | the hex's cover is woods, marsh, rock or snow (`TerrainDef.rough`), or its relief is 3 (hills) or more |
| Narrow (the right lane closed) | marsh or snow cover (`TerrainDef.narrow`), or relief 5 (mountains) or more |
| Defence (for the defender only) | `TerrainDef.defence_permille` (woods 250, marsh 150, rock 50, snow 250, the rest 0) + `relief_defence_add[relief]` (0, 0, 0, 50, 150, 300, 500) |
| Fight | the attacker strikes in `assault` while the garrison fights, else `open` or `rough`; the defender's companies are struck in `garrison` in an assault, else `open` or `rough`; the attacker is struck in `open` or `rough` |
| The attacker's penalties | uphill −50 permille all battle; a pass crossing −300 and a river crossing −200 on day 1 (multiplied) |

**The values** of a company (whole thousandths; `UnitDef.attack`, `defence`; the rank by experience: 1,000, 1,100, 1,200):

```
att(a)  = attack x fight_attack[branch][fight] x rank / 1000
def(t)  = defence x fight_defence[branch][fight] x rank / 1000
          x (1000 + ground defence) / 1000              (the defender's companies, not in an assault)
          x (1000 + castle_defence_permille (250) x level) / 1000    (every defender's fighter in an assault)
          x pikes_vs_horse (1250) / 1000                (an infantry company struck by cavalry)
the garrison: attack 3, defence 3 + 2 x level, branch infantry, rank 1,000
```

| `fight_attack` (open, rough, assault) | `fight_defence` (open, rough, garrison) |
|---|---|
| infantry 1000, 1000, 1000 | 1000, 1100, 1300 |
| missile 1000, 900, 800 | 800, 900, 900 |
| cavalry 1400, 700, 500 | 1000, 800, 800 |
| artillery 1000, 600, 2000 | 500, 500, 800 |

| Kind (`UnitDef`, M6) | Men | Attack | Defence | Fire (permille a day, from the reserve) | Siege points |
|---|---|---|---|---|---|
| Pikemen | 500 | 4 | 5 | 0 | 0 |
| Crossbowmen | 500 | 5 | 2 | 25 | 0 |
| Knights | 250 | 6 | 3 | 0 | 0 |
| Bombards | 100 | 6 | 1 | 50 | 1 |

**A hit** (`Combat.hit`), every division floored, in this order:

```
x = t_full x base                        base: shock 80, fire 50 or 25, back line 40 (permille)
x = x x att(a) / def(t)
x = x x a_men / a_full                   (a worn company hits less)
x = x x dealt[stance of a] / 1000        attack 1200, hold 900, withdraw 1000
x = x x taken[stance of t] / 1000        attack 1100, hold 800, withdraw 1000
x = x x extra / 1000                     1250 for infantry striking cavalry and for a flank, else 1000
x = x x shaken / 1000                    500 for a company moved up from the reserve today (after day 0), else 1000
x = x x ground / 1000                    the attacker's penalties (above); 1000 for the defender
x = x x dice[roll of a's side] / 1000    700, 800, 900, 1100, 1200, 1400 for 1 to 6
x = x x spread / 1000                    spread = luck.world.randi_range(500, 1500), one draw a hit
hit = min(x / 1000, the target's men left)
wounded = hit x wounded_share (500) / 1000; killed = hit − wounded       (the flight and withdraw prices: all killed)
```

Worked hit: pikemen on Attack against pikemen on Hold on farmland, both at full, roll 4, spread 1000: 500 x 80 = 40,000; x
4,000 / 5,000 = 32,000; x 1,200 / 1,000 = 38,400; x 800 / 1,000 = 30,720; x 1,100 / 1,000 = 33,792; hit 33 men (16 wounded, 17
killed).

**A day** (`Combat.day`, as `combat.fight_day` of v0.2.2): **deploy** (every open lane empty at dawn takes a company of its
side's reserve: centre first, then left, then right; infantry first in the centre, cavalry on the flanks, crossbowmen and
bombards last, then the best defence, then the lowest unit id; the defender's centre is the garrison while it has men and
morale; a company that moves up after day 0 is shaken today; lanes that held a company and stay empty are broken: a broken
centre shocks its side once (−250 morale), each day a broken flank stays open its centre loses 100); the **rolls** (attacker,
then defender); **fire** (each ranged company in a reserve: a bombard battery at the enemy centre, crossbowmen the k-th
crossbow company of its side at the lane `FILL_ORDER[k mod 3]`, each falling back to the first filled lane); **back line** (a
side whose centre is empty exposes its reserve: the enemy's reserve hits it at 40); **shock** (each lane against the same
lane, both ways); **flanks** (a company with nobody opposite in a flank lane strikes the enemy centre, or the nearest filled
lane, ×1.25); each phase's hits are worked out from its start and applied together; **morale** (each fighter loses `5 x
lost_today x 1000 / men_at_dawn` + 20 in a lane or 30 in the reserve, + 30 when its army was hungry at the last supply
phase, the sum divided by its rank; at 0 it routs: it leaves its lane and stays on the hex); the **break test** (a side breaks
when its centre is empty with no reserve, two lanes are (either one on narrow ground), or its front morale (the men-weighted
morale of its lanes) is under 100; both: the lower front morale, the attacker on a tie); the **flight** of a broken side (each
fighter loses 150 permille of its men, all killed; its bombards are lost whole; morale set to 150). Days follow until a side
breaks or has no fighter left; a side on Withdraw leaves at the end of day 2 (`withdraw_day`), paying 50 permille of its men
(100 for the attacker) and 250 morale; at the end of day 8 the side with the lower front morale withdraws, paying the same,
unless it has no retreat hex and the other has.

**The end** (`BattleEnd.apply`): every company takes its men and morale from the result (`Armies`); a company at 0 is lost
(`unit_lost {why: battle}`); a beaten side retreats (`Battles.retreat_spot`: a walk of at most `retreat_range` (6) steps over
edges that are not BLOCKED or CLOSED, never into a hex with an enemy army or a hostile garrisoned fortress; a Withdraw to land
its country controls; a broken or capped side to its own land, unowned land or land of a country at war with it, its own
controlled land first; the nearest by steps, then the farthest from the nearest enemy army, then the lowest index; with room
for the whole side) as one `unit_moved` per army (`why:
retreat`, ticks after the movement's last), or **surrenders** (every company lost, `unit_lost {why: surrendered}`, its men
killed); half the wounded of each surviving company return when its army ends in supply (`Supply.in_supply`); the winner's
companies gain 2 experience and the loser's 1 when a day was fought; a beaten side's armies halt (`order` none, `halt_why`
`defeated`, `march_halted {why: defeated}`); in an assault the fortress is **stormed** when the defender broke or surrendered and
its garrison has no men or no morale left, or the garrison stood alone: occupier = the attacker, garrison 0, a walled town or
city sacked (4.11), `district_captured {by: storm}` (the sieges phase that follows removes its siege); else the garrison keeps
its uncut men less what the storm cost it. A besieger that lost a relief battle sees its siege lifted by the sieges phase that
follows (`relief`). Then `Wars.book_battle`
(the war's battles won and men lost), the record (D43), `battle_fought {tag, hex, days, killed, wounded, morale}` and
`battle_ended` (5.5).

**Starting expectations** (v0.2.2's 0.2.1 measures, pikemen on farmland, attacker on Attack, defender on Hold, 100 seeds;
`godot/tools/war_report.gd` measures the same table on the district map in task B18 and `tests/core/test_combat.gd` keeps
30-seed bands of it): 3 v 3 attacker wins 35 to 55 %; 4 v 3 60 to 85 %; 6 v 4 60 to 90 %; 4 v 2 and 6 v 3 65 to 95 %; the same
pairs in woods at least 10 points lower than on farmland; every battle ends in 1 to 8 days and the day cap ends under 10 %.

**The odds** (D50; `Combat.odds_strength`, `odds_factor`, `odds_word`): a side's strength is the sum over its companies of
men x morale / 1,000; a garrison adds its men x `garrison_odds_permille` (3,100) / 1,000 when a field army of its side stands
with it, or x `garrison_odds_alone[level]` / 1,000 when it stands alone (1,800, 1,100, 1,000 for levels 1 to 3). The ratio is
attack x 1,000 / defence (defence at least 1); the factor is `odds_ground` of the hex's key (1,000 in an assault, where the
walls are in the garrison's weight); the word is the last entry of `odds_words` whose `from` is at most ratio x 1,000 /
factor. A viewer who sees the defender only rounded (4.15) gets the word from the rounded men; a hidden defender gives no
word. Savoy's 2,000 men against Milan's 1,000 on farmland: ratio 2,000, factor 1,000, "Favourable".

### 4.7 Orders: attack, besiege, storm, the standing order

**Attack** is M6's `march` to a hex where an army of a country at war with the actor stands: `Movement.march_check` row 7
asks `Battles.engage_check(game, {army, hex, tag})`:

| # | Case | Verdict |
|---|---|---|
| 1 | M6's rows 1 to 3 (no army, unknown, not yours) | their words |
| 2 | The hex holds an army of a country not at war with the actor | M6's "another country's army stands at Alessandria (7, 9)" |
| 3 | The army's men-weighted morale is under `attack_morale` (500) | "too shaken to attack: morale 34 %, 50 % needed (it recovers 25 a season when fed)" |
| 4 | The actor's companies already standing or ordered there plus the army's exceed 8 | "no room: 7 of 8 companies of yours stand there already" |
| 5 | Otherwise | ok (the route's rows 6 to 9 of M6 follow in `march_check`) |

In the movement phase the same check runs at the tick of the step: a refusal ends the leg before the hex (`march_halted
{why: shaken}` or `blocked`).

**Besiege** is a `march` to a hostile garrisoned fortress with no army on it (the route ends there; the siege starts in the
`sieges` phase).

**Storm** (`Movement.storm_check(game, {army, goal, tag})`): M6's march rows 1 to 5; "no walls to storm at Alessandria (7, 9)"
(not a fortress); "not at war with the %s" (its controller); "your own walls" (the actor controls it); "its garrison is gone:
march in to take it" (garrison 0); `engage_check` rows 3 and 4; then, when the army does not stand on the goal, M6's route
rows 6 to 9. `storm` sets `order` &"storm", the goal and the route (empty when it stands there), and emits `army_changed`. It
storms on arriving (movement) or in the next `battles` phase (already there).

**The standing order** (`Military.standing_check(game, {army, standing, tag})`): M6's army rows; "no standing order given";
"no such standing order: hold or withdraw"; "the Army of Turin already holds when attacked" / "... already withdraws when
attacked"; else ok. `set_standing` writes `Army.standing` and emits `army_changed`.

### 4.8 The movement phase after M7 (M6 4.4, edited)

- **Open land** (`Movement.open_to`): own land, unowned land, and land whose owner is at war with the army's country.
- **The mask** (`Movement.open_mask`): `open_to` less every hostile garrisoned fortress; `plan` adds the route's goal.
- **Ticks** (M6 step 2): a step onto a hex holding an army of another country is taken only when that country is at war with
  the army's: `Battles.engage` (a battle or a join); the army's leg ends there, and so does the defender's (it is in battle).
  A step onto a battle hex: a join when the army's country is a side and it fits, else not taken (`blocked`). A step onto a
  hostile garrisoned fortress ends the leg there (a storm order engages, 4.6).
- **Zones of control** (`Movement.zoc_halts`): a neighbour holds an army of a country at war with the army's, or is a
  fortress with a garrison controlled by such a country.
- **Room** (M6 step 3): counted per country, so on a battle hex each side counts its own.
- **Apply** (M6 step 4): an army in a battle keeps its march order and the rest of its route (a winner goes on next season).

### 4.9 Peace

`Wars.make_peace_check(game, {target, terms, tag})`, in order:

| # | Case | Verdict |
|---|---|---|
| 1 | No target or no terms given | "no country given", "no terms given" |
| 2 | Rows 2 to 4 of 4.2 | their words |
| 3 | Not at war | "not at war with the %s" |
| 4 | `terms` not `take`, `white` or `yield` | "no such terms: take, white or yield" |
| 5 | white: the war is younger than `peace_min_seasons` (4) | "a white peace needs 4 seasons of war: %d more" |
| 6 | white: `score(tag, target)` under `white_score_min` (−1) | "they are winning (score %+d): they refuse a white peace" |
| 7 | take: the actor occupies none of the target's districts | "you hold none of their districts" |
| 8 | take: score under `take_score` (3), and not (score at least `take_score_weak` (1) with the target's men under arms not above the actor's) | "they refuse: score %+d; hold 3 or more of their districts, or beat their armies" |
| 9 | Otherwise | ok |

`make_peace` checks again, then, in order: the war ends (`end_turn`, `terms`); **take**: every district of the target the actor
occupies, but the target's capital and its last district (D33), goes to the actor (`Territory.transfer`), its garrison 0;
**yield**: the same the other way; then every occupation between the two is cleared (`Occupation.release`); every army of
either standing on land no longer open to it goes to the nearest hex (by hex distance, ties by index) of its own land where
it fits, with its order cleared (`march_halted {why: peace}`; with none it is disbanded home, `People.give_back`); `peace_made
{tag, target, terms, war, moved (the districts that changed owner), released, witnesses: every living country}`; then M2's
`owners_changed` and M7's `controllers_changed`. Works on ceded hexes are cancelled `lost` by the next works phase (M3 D13).
Sieges between the two are lifted (`peace`) by the next `sieges` phase; meanwhile `SiegeView` shows none (4.5).

**The timer** (`Wars.season`, the `war` phase): a war whose `game.turn − start_turn` reaches `war_timer_seasons` (40) ends as
a white peace with terms &"timer" (the same steps). The reminder `war_timer` warns from 32.

**The truce** (`Wars.truce_until(game, a, b)`): the newest ended war between the two, `end_turn + truce_seasons` (8).

### 4.10 The war in the economy (M4, edited)

Each district counts in the economy for its **controller** (`Occupation.controller_id`). With no war every number of M4, M4.5
and M5 is unchanged (no district is occupied). With occupation:

| M4 term | An occupied district (occupier ≠ 0, no siege) | A besieged district |
|---|---|---|
| `district_output` goods and port dues | for the occupier, `x occupied_output_permille (500) / 1000` after weather, floored | nothing |
| taxes on its people (`tax_people`) | its people count for the occupier at `occupied_tax_permille (500)`: `town_people` and `country_people` of a country are `Σ own controlled + Σ occupied x 500 / 1000` | not counted |
| goods tax on sales | the occupier's sales (its stores) | none |
| towns' needs (food, wine, salt, oil) | its town people need from the occupier's stores in full | nothing taken |
| upkeep and walls | nobody pays | nobody pays |
| hands, jobs, staffing (M5 D18) | as M5: counted over the hexes of the district's owner | as M5 |

`Economy.district_output(game, view, hex, season, weather, tax)` gains the term (an occupier on the hex, read from the game's
state; a `StateView` carries no occupier, so a preview counts today's occupations); `EconomySeason.made_of`, `town_people`,
`country_people`, `needs_of` and `money_lines` walk `Occupation.controlled(game, id)` instead of `Territory.districts`. The
`DistrictCache` keeps the season-free part as before; the occupation term is applied after it. A preview foresees no capture
and no peace.

Worked: Domodossola (7, 6), a town of 10,000 at the start, taken by Savoy in Summer 1480: Savoy's taxes on people gain about
5 ducats a season (10,000 people x 1 ducat per 1,000 x 500 / 1,000 at Normal and full contentment), Milan's fall by about 10;
Savoy's towns' food need rises by one load a season (139,000 town people); its grassland's wild grain counts for Savoy at half.

### 4.11 The war and the people (M5, edited)

- **Who is booked.** People flows are booked on the hex's **owner**, always (M5 `People.move`); a capture moves nobody.
- **Growth on occupied land** reads the controller's tax level and food (`People.season` walks the hexes each country controls
  and books on their owners); an occupied settlement never grows a level (`People.grow_check` refuses "occupied: it does not
  grow while the Duchy of Savoy holds it").
- **Besieged settlements** grow nothing and take no food; once the siege's stores are out (`Sieges.starving`), M5's hunger
  rule runs with fed 0: `loss = ceil(p x 400 x hunger_percent x 1000 / 10^9)`, down to `town_floor`.
- **Sacking** a stormed walled town or city: `People.move(hex, −(people x 150 / 1000), &"sacked")`.
- **Levies** (raise, refill, garrisons) take only from hexes the levying country owns **and controls**; `People.levy_check`
  gains "held by the Duchy of Savoy: no men can be raised here".
- **Foraging** (M6) on enemy land books `foraged` on the enemy (the owner).
- **No refugees**, no migration (D28).

`People.FLOWS` appends `garrisoned` and `sacked` (nine flows).

### 4.12 Supply, sight, morale (M6, edited)

- **Supply** (`Supply.field`): over the hexes the country controls (own and not occupied, or occupied by it), not over hexes
  holding an army of a country at war with it; depots: controlled settlements of level 2 or more, ports, and fortresses it
  owns and controls with no siege on them. `SupplyCache` is dropped for a country on `controllers_changed` and, for every
  country at war, after the movement and battles phases.
- **Sight** (`Sight`): a country sees the hexes it **controls** and their ring (M6 said "holds"); the land part is dropped on
  `controllers_changed`. Fortresses give no sight of their own (M6 D31 stands).
- **Morale** (`Armies.recover_morale`, the `ready_units` phase, after M6's refill): every company of an army whose `supply`
  is 0 or 1 gains `morale_recovery` (250), up to 1,000. A new company starts at 1,000.

### 4.13 The season table after M7

`core/game/season.gd` `PHASES` in M7: **`movement`, `battles`, `supply`, `sieges`, `war`, `production`, `income`, `works`,
`people`, `stats`, `calendar`, `ready_units`, `vision`** (`test_season.gd` pins it). The planned order, edited from M6's 4.10:

| # | Name | Arrives | Reads | Writes (through the owner) |
|---|---|---|---|---|
| 1 | `ai_orders` | M8 | everything through views | through `Game.act` only |
| 2 | `movement` | M6 (M7 edits) | as M6; wars, fortresses, garrisons, battles | as M6; `battles` (`Battles.engage`, `join`); events as M6, `battle_started`, `battle_joined` |
| 3 | **`battles`** | **M7** | battles, armies, units, map, owner, occupier, garrison, sieges, supply, `luck.world` | `battles`, `battle_records`, `next_record_id`, `battle_names` (`Battles`); armies' units, men, morale, xp, hex, order (`Armies`); `occupier`, `garrison` (`Occupation`, a storm); `people`, `people_flows` (`People.move` sacked); `wars` (`Wars.book_battle`); `luck`; events `battle_fought`, `battle_ended`, `unit_lost`, `unit_moved`, `march_halted`, `district_captured`, `controllers_changed` |
| 4 | `supply` | M6 (M7 edits) | as M6; occupier | as M6 |
| 5 | **`sieges`** | **M7** | armies, owner, occupier, garrison, sieges, the war cache, this season's records, people | `sieges`, `siege_names` (`Sieges`); `occupier`, `garrison`, `unsupported` (`Occupation`); `people`, `people_flows` (`People.levy` garrisoned); events `siege_started`, `siege_progress`, `siege_lifted`, `district_captured`, `controllers_changed` |
| 6 | **`war`** | **M7** (M9 adds peace offers) | wars, turn | `wars` (`Wars`); `occupier` (`Occupation.release`), armies' hex and order (`Armies`) as a peace (4.9); events `peace_made`, `controllers_changed`, `march_halted` |
| 7 | `production` | M4 (M7 edits) | as M5; occupier, sieges | as M5 |
| 8 | `trade` | M10 | | |
| 9 | `income` | M4 (M7 edits) | as M6; occupier, sieges | as M6 |
| 10 | `debt` | M12 | | |
| 11 | `works` | M3 (M7 edits) | as M5; occupier, sieges | as M5 |
| 12 | `people` | M5 (M7 edits) | as M5; occupier, sieges | as M5 |
| 13 | `research` | M11 | | |
| 14 | `extinction`, `scores` | M12 | | |
| 15 | `stats` | M3 | as M6; wars, records, occupier, garrison | `stats` (M7 series) |
| 16 | `calendar` | M3 | | |
| 17 | `ready_units`, `vision` | M6 (M7 edits) | as M6 | as M6; morale (`Armies.recover_morale`) |

Why this order: losses first, then the survivors eat (battles before supply, v0.2.2); a battle won this season lets the winner
take land in the same season (sieges after battles); a capture counts in the season's production (sieges before production);
the timer's peace comes after the season's captures and before the money (war before production).

### 4.14 Events, witnesses, log lines, conservation

**Events** (the fields besides `kind` and `turn`; one typed signal each; `Session` drains them after every action and phase):

| Kind | Fields | Emitted by | Notable | Typed signal | Heard by |
|---|---|---|---|---|---|
| `war_declared` | `tag`, `target`, `war`, `witnesses` (every living country) | `Wars.declare_war` | yes | `war_declared(tag, target)` | `DecisionQueue` (the player is the target), `CountryPanel`, `TopBar`'s country panel refresh, `WarMarks`; through `chronicled`: log, notifications, ribbons ("War!") |
| `peace_made` | `tag`, `target`, `war`, `terms` (`take`, `white`, `yield`, `timer`), `moved` (hexes), `released` (hexes), `witnesses` (every living country) | `Wars.make_peace`, `Wars.season` | yes | `peace_made(tag, target, terms)` | `CountryPanel`, `ArmyTokens`, `WarMarks`; log, notifications, ribbons ("Peace") |
| `battle_started` | `tag` (attacker), `hex`, `others` ([defender]), `defender`, `assault`, `name`, `year`, `tick`, `witnesses` | `Battles.engage` | no | `battle_started(hex, attacker, defender)` | `MoveReplay` (the badge in the replay), F3 |
| `battle_joined` | `tag`, `hex`, `army`, `side` (`attacker`, `defender`), `men`, `witnesses` | `Battles.engage` | no | `battle_joined(hex, tag)` | `MoveReplay`, F3 |
| `battle_fought` | `tag` (attacker), `hex`, `others`, `days`, `killed`, `wounded` ({tag: men}), `morale` ({tag: front morale}), `witnesses` | `BattleEnd.apply` | no | `battle_fought(hex)` | `MapScene` (a "−420 men" ribbon over the hex for the player's side), F3 |
| `battle_ended` | the war-goals 3.4 contract: `tag` (attacker), `hex`, `attacker`, `defender`, `winner`, `loser` (tags or `&""`), `assault`, `how` (`broke`, `withdrew`, `surrendered`, `destroyed`, `gone`; `peace` is reserved: no battle outlives its phase), `cause` (`centre`, `lanes`, `morale`, `order`, `cap`, `&""`), `seasons` (1), `days`, `name`, `year`, `killed`, `wounded` ({tag: men}, pursuit and surrender included), `retreat` (hex or `Army.NO_HEX`), `record` (id), `stormed` (bool), `others` ([defender]), `witnesses` | `BattleEnd.apply` | yes | `battle_ended(hex, record, winner)` | `WarMarks`, `ArmyPanel`, `BattleDock` (when open on the hex); log, notifications, ribbons ("Victory!", "Defeat!", others' "Battle") |
| `siege_started` | `tag` (besieger), `hex`, `others` ([controller]), `name`, `need`, `level`, `garrison`, `men`, `witnesses` | `Sieges.season` | yes | `siege_started(hex, tag)` | `WarMarks`, `HexPanel`; log, notifications (your fortress), ribbons ("Siege") |
| `siege_progress` | `tag`, `hex`, `others`, `progress`, `need`, `rate`, `hunger`, `seasons`, `name`, `witnesses` | `Sieges.season` | no | `siege_progress(hex, tag, progress, need)` | `WarMarks` (the dial), `MapScene` (the "Siege 6/10" ribbon for the player's sieges and its besieged fortresses), `HexPanel` |
| `siege_lifted` | `tag`, `hex`, `others`, `why` (`left`, `relief`, `outnumbered`, `peace`), `name`, `progress`, `need`, `seasons`, `witnesses` | `Sieges.season` | yes | `siege_lifted(hex, tag, why)` | `WarMarks` (the grey flash), `HexPanel`; log, notifications, ribbons ("Lifted") |
| `district_captured` | `tag` (the new controller), `hex`, `others` ([the old controller]), `owner`, `by` (`walk`, `siege`, `storm`, `retaken`, `freed`), `name`, `seasons`, `opened` (districts its fall opens), `witnesses` | `Occupation.capture` (from `Sieges`, `BattleEnd`) | yes | `district_captured(hex, tag, by)` | `HexPanel`, `CountryPanel`; log, notifications (yours gained or lost), ribbons ("Taken", "Lost", "Freed") |
| `controllers_changed` | `hexes`, `tag`, `others` | `Occupation.flush` | no | `controllers_changed(hexes)` | `MapScene` (the overlay's occupier texels, the area lines), `WarMarks`, the hex panel and hover card, F3 |

`Chronicle.NOTABLE` gains the six notable kinds (twenty). `Sight.SIGHTED` gains `battle_started`, `battle_joined`,
`battle_fought`, `battle_ended`, `siege_started`, `siege_progress`, `siege_lifted`, `district_captured` (the actor and the
`others` always witness). `SeasonSummary.COVERED` gains `battle_ended`, `district_captured`, `siege_lifted`, `peace_made`.
`unit_moved` gains `why` (`march`, `retreat`) and its `ticks` continue after the movement's last tick for retreats.

**Log lines** (`LogLines.line_of`; others' lines only when witnessed; all with the filter **War** (`since` 7) besides All, and
Mine for the player's; M6's army kinds join War too):

| Kind | The player's line | A witnessed other's |
|---|---|---|
| `war_declared` | "You declared war on the Duchy of Milan." / "The Duchy of Milan declared war on you!" keyword "War", bad; `notify` true when on you; `floating` "War!" | "The Duchy of Milan declared war on the Republic of Venice." muted |
| `peace_made` | "Peace with the Duchy of Milan: you took 2 districts." / "...: a white peace." / "...: you gave up 3 districts." / "...: the war ended after 40 seasons." keyword "Peace", plain; `notify` true; `floating` "Peace" | "Peace between the Duchy of Milan and the Republic of Venice." muted |
| `battle_ended` | "Battle of Alessandria, 1480: you won in 4 days. You lost 120 men (60 wounded), the Duchy of Milan 410; they fled to (8, 8)." / "...: you lost ..." keyword "Battle", good or bad; `notify` true; `floating` "Victory!" / "Defeat!"; a link opens the dock | "Battle of Gavi, 1481: Milan beat Genoa." muted; `floating` "Battle" |
| `siege_started` | "You besiege Pavia (10, 9): it needs 10." / "Savoy besieges your Pavia (10, 9)." keyword "Siege", warn; `notify` true for yours; `floating` "Siege" | "Savoy besieges Pavia (10, 9)." muted |
| `siege_lifted` | Your siege: "The siege of Pavia (10, 9) is lifted: your army left." (`left`) / "...: a relief army beat yours." (`relief`) / "...: your army is too small for its garrison." (`outnumbered`) / "...: peace was made." (`peace`), warn. Your fortress: "The siege of your Pavia (10, 9) is lifted." good. Keyword "Lifted"; `notify` true; `floating` "Lifted" | "The siege of Pavia (10, 9) is lifted." muted |
| `district_captured` | "Taken: Domodossola (7, 6) from the Duchy of Milan." / "Lost: Vercelli (6, 9) to the Duchy of Milan." / "Pavia (10, 9) has fallen after 4 seasons: its land lies open (6 districts)." / "Retaken: Asti (8, 10)." / "Freed: ... went back to the Duchy of Milan." keyword "Taken", "Lost", "Fallen", good or bad; `notify` true; `floating` "Taken" / "Lost" | "Savoy took Domodossola (7, 6)." muted |

**Conservation of men** (`test_war_property.gd`), per country and season, from the closed flows and `Stats`:

```
Δ people + Δ men under arms + Δ garrison men
  = grew − starved − left + dev − foraged − sacked                   (People flows booked on the country)
    − hunger losses (M6) − battle losses (killed, wounded not returned, pursuit, flight, surrender)
    − garrison losses (battle, a fall, a capture)
raised, returned and garrisoned move people into men and back inside one country; every levy is on land it owns and controls
```

**Conservation of districts**: the land count never changes; every land district keeps an owner (north Italy has no unowned
land); `occupier` is 0 or a living country at war with the owner; owners change only through `make_peace`, the timer and
`dev_transfer`; a peace moves only districts the winner occupied, never the capital or the last district.

### 4.15 What you may know of others

| Thing | You see |
|---|---|
| Wars, peaces, truces, war scores | everything, public (D49) |
| Who holds a district (occupation) | everything: the map shows it to all |
| A battle (the dock, the badge, the log) | exact as a side (or the viewer `&""`); seen (men rounded to 100, morale to 5 %, stances and standing orders hidden) when you witnessed it; else nothing |
| A siege (the badge, the hex panel) | exact as besieger or defender; seen (the meter exact, men rounded) while you see the hex (`Sight.sees`); else nothing |
| A fortress's garrison | exact for its owner; seen rounded while you see the hex; else "a garrison" |
| Another country's standing orders, storms, routes | nothing |

### 4.16 Worked examples

All on "Italy, 1480", **seed 1480**, as Savoy, Normal taxes, calm weather (`weather_odds = [100, 0, 0]` in the tests' defs
copy, as M4 to M6). The hexes, routes and areas were worked out from the map data, the improvement report and the rules above
for this page; `tests/core/test_war_savoy.gd` pins them (`tests/core/war_fixture.gd`, `WarFixture.savoy()`), and pins the
luck-drawn battle by its result on seed 1480 as the build gives it.

**(a) Declaring, Spring 1480.** The console's `as MLO raise 7 9 pikemen 2` raises Milan's Army of Alessandria (1,000 men) at
Alessandria (7, 9) (Milan's town; it holds, passive). Savoy: `declare_war {target: MLO}`: ok; `war_declared` with 13
witnesses; `Movement.open_to(SAV, (7, 9))` is now true. `declare_war {target: VEN}`: "only neighbours go to war: the
Republic of Venice shares no border with the Duchy of Savoy". Savoy raises 2 pikemen each at Ivrea (6, 8), Turin (5, 9) and
Vercelli (6, 9) (150 ducats, 6 iron, 3,000 people); orders the Army of Ivrea to Domodossola (7, 6) and the Army of Turin to
Vercelli.

**(b) Walking in, Summer 1480.** The Army of Ivrea walks Bard fort (6, 7) (2 points) and Domodossola (4): no fortress or
enemy army beside either hex. Summer's `sieges` phase: Domodossola is open land (no fortress holds it: Milan's area reaches 3
hexes and Domodossola lies further), 1,000 men ≥ 250: taken, `district_captured {tag: SAV, hex: (7, 6), owner: MLO, by:
walk}`, one `controllers_changed`. Summer's production and income count it for Savoy at half (4.10). `Wars.score(SAV, MLO)`
is +1. In the same movement phase the Army of Turin reaches Vercelli (beside Alessandria's Milanese army: its leg would end
there anyway). At Autumn's idle the player joins it to the Army of Vercelli (4 companies, 2,000 men) and orders it onto
Alessandria (an attack: `engage_check` ok, morale 1,000), and orders the Army of Ivrea on to Locarno (7, 5).

**(c) The Battle of Alessandria, Autumn 1480.** Autumn's movement: the Army of Vercelli steps onto Alessandria at tick 1:
`battle_started {name: "Battle of Alessandria, 1480"}`; Savoy attacks on Attack, Milan holds on Hold; farmland, plain relief:
open ground, three lanes, no penalties. The battles phase fights it to its end (1 to 8 days); the test pins the seed's days,
dice, losses and result. Every company's men after the battle equal its men before less its killed and its wounded that did
not return; the record's last frame equals the state; `Combat.fight` from the record's input and `luck_before` gives the same
record digest. The Army of Ivrea takes Locarno in Autumn's sieges phase (score +2). If Savoy wins, its army stands on
Alessandria: Milan's held land, so it takes nothing there and forages it (M6).

**(d) The Siege of Pavia** (a fixture: `WarFixture.army_at(game, SAV, (10, 9), pikemen, 4)` builds 4 companies on Pavia
through the `Armies` door, at war with Milan, in Spring 1480). Pavia: walled town, fortress 2, garrison 800, plain (relief 2):
need 4 + 3 x 2 = 10; crowd 2,000 / 800 = 2.5: 2 a season; stores 3 seasons. Spring: `siege_started` ("Siege of Pavia, 1480",
need 10), progress 2; Summer 4; Autumn 6 (a save here, loaded, plays on to the same digest); Winter 6 + 2 + 2 = 10 ≥ 10 after 4
seasons: `district_captured {by: siege, opened: 6}`, occupier SAV, garrison 0. From Spring 1481 Lodi, Piacenza, Cremona, (12, 8),
(12, 10) and (11, 11) are `fallen`: any Savoy army standing alone on one takes it.

**(e) The peace, Spring 1481.** Savoy occupies Domodossola and Locarno: score +2; Milan's men under arms are at most 1,000,
Savoy's at least 2,000: `make_peace {target: MLO, terms: take}` passes row 8 by its second clause: ok. Domodossola and Locarno
become Savoy's (one `owners_changed {tag: SAV, others: [MLO]}`); `peace_made {terms: take, moved: 2}`; every Savoy army on
Milan's land goes to its nearest own hex: when the Army of Vercelli won at Alessandria and stands there (no longer open to
it), to Vercelli (6, 9) (distance 1, the lowest index of the three Savoy hexes beside it), and the test checks whichever the
seed gives; the take is accepted either way (Savoy keeps at least the Army of Ivrea's 1,000 men, Milan at most 1,000);
`declare_war {target: MLO}` then reads "a truce with the Duchy of Milan holds until Spring 1483 (8 more seasons)". In a copy,
`make_peace {terms: white}` (the war has lasted 4 seasons, score +2 ≥ −1): both districts go back to Milan's control, Milan's
production counts them in full from that season.

### 4.17 The season report after M7

`SeasonSummary.SECTIONS`: glance, before, treasury, goods, works, people, armies, **war**, orders, befell, standing.

| Id | M7 content |
|---|---|
| `glance` | a **War** chip per live war of the viewer ("At war with Milan: +2"), when at war this season or the last |
| `before` | the reminders of 4.18 |
| `armies` | M6's lines; an army that fought adds "the Battle of Alessandria" to its men line |
| `war` | `total` "At war with 1 country" (or "At peace"); a line per battle the viewer fought this season ("Battle of Alessandria, 1480: you won in 4 days. You lost 120 men, they 410." a link that opens the dock); a line per siege of the viewer or of its fortresses ("Siege of Pavia: 6 of 10, +2 a season; falls in about 1 season." / "Savoy besieges your Pavia (10, 9): 6 of 10."); captures and losses ("Taken: Domodossola (7, 6)."); falls and lifts; a peace or a declaration; `sub` "War score with Milan +2: you hold 2 of their districts, they hold none of yours." Rank: men lost for battles, `need − progress` for sieges, 1 for captures |
| `orders` | from the action log: "Declared war on the Duchy of Milan.", "Made peace with the Duchy of Milan: took 2 districts.", "Ordered to storm: the Army of Vercelli at Pavia (10, 9).", "The Army of Turin now withdraws when attacked." |
| `befell` | M6's, plus others' witnessed battles, sieges and captures and every war and peace between others (public) |

**Quiet** (M6's rule, plus): no war event and no live siege of the viewer's.

### 4.18 Reminders after M7

`Reminders.RULES`: `treasury_empty`, `hunger`, `army_hungry`, `army_stores`, **`besieged`**, `goods_running_out`, `winter_halt`,
`winter_passes`, **`occupied`**, **`war_timer`**, `treasury_falling`, `town_full`, `army_idle`, `free_slot`.

| Rule | When | Severity | Text | Action |
|---|---|---|---|---|
| `besieged` | a fortress of the player is besieged | 2 | "Pavia (10, 9) is besieged by Savoy: 6 of 10; it falls in about 1 season." (two or more: "2 of your fortresses are besieged: ...") | `[&"look_at", hex]`, "Go to Pavia" |
| `occupied` | an enemy occupies districts of the player | 1 | "The Duchy of Milan holds 2 of your districts: Asti (8, 10) and 1 more." | `[&"look_at", first hex]` |
| `war_timer` | a war of the player has lasted 32 seasons or more | 1 | "The war with the Duchy of Milan ends in a white peace in 8 seasons." | `[&"country", tag]`, "Show Milan" |

### 4.19 Stats after M7

`Stats.SERIES` gains, appended: `battle_losses`, `battles_won`, `battles_lost`, `districts_held`, `districts_lost`,
`garrison_men`, `garrison_lost` (**49** series). `StatsSystem.season` writes per country: `losses` (M3's series: hunger plus
battle losses of its armies), `battle_losses`, `battles_won`, `battles_lost` (this season's records), `districts_held` (others'
districts it occupies), `districts_lost` (its districts others occupy), `garrison_men` (the men of the fortresses it owns),
`garrison_lost`, and M3's `war_score` (the sum of `Wars.score` over its live wars).

### 4.20 Saves and the digest

| Body key | M7 adds | In `Game.digest()` |
|---|---|---|
| `format` | 5 (`SaveFile.FORMAT`; `OLDEST_FORMAT` 5) | no |
| `war` (**new**) | `{schema: "hexa-godot/war/1", wars: [War.to_dict()], next_war_id, battles: [Battle.to_dict()] (empty at idle), battle_records: [BattleRecord.to_dict()], next_record_id, battle_names, sieges: [Siege.to_dict()], siege_names}` | `Wars.digest` (the wars), `Battles.digest` (the live battles, the records, `next_record_id`, `battle_names`) and `Sieges.digest` (the sieges, `siege_names`), in id or hex order, joined by `Game.digest` |
| `map_state` | `map-state/5`: `occupier` (bytes), `garrison` (int32), `unsupported` (bytes), packed as they are; schema 4 reads with no occupation and empty garrisons (tests only) | `MapState.digest()` adds the three |
| `armies` | `army/2` (`standing`), `unit/2` (`morale`, `xp`); `army/1` and `unit/1` refused | each `digest_text()` |
| `stats` | the seven series | `Stats.digest()` |
| `action_log` | the M7 actions | no |
| (not saved) | `game.war_cache` (`WarCache`) | no |

Sizes on the made-up Europe: occupier and unsupported 122 KB each, garrison 0.49 MB before compression (mostly zero); 60
records of about 3 KB (0.18 MB); a few hundred wars and sieges: under 0.1 MB. `save_mb` stays 8.

---

## 5. Interfaces

Layers as the standard: `defs`, `state`, `systems`, `game`, `views`, `shell`. `core/` makes no engine calls; its only luck
is `Luck.world` through `Rng` (weather, M4; battles). New files are marked **new**; "(M1.5)" to "(M6)" name pieces those
milestones build. Every amount is an `int`; every rate a permille.

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/war_def.gd  (new): every number of the war, one inspector
class_name WarDef extends Resource
const BRANCHES: Array[StringName] = [&"infantry", &"missile", &"cavalry", &"artillery"]   # UnitDef.BRANCHES' order
@export var shock_permille := 80
@export var backline_permille := 40
@export var flank_permille := 1250
@export var pikes_vs_horse_permille := 1250
@export var fight_attack: Dictionary[StringName, PackedInt32Array] = {}    # branch -> [open, rough, assault] (4.6)
@export var fight_defence: Dictionary[StringName, PackedInt32Array] = {}   # branch -> [open, rough, garrison]
@export var stance_dealt: Dictionary[StringName, int] = {}                 # attack 1200, hold 900, withdraw 1000
@export var stance_taken: Dictionary[StringName, int] = {}                 # attack 1100, hold 800, withdraw 1000
@export var dice_permille: PackedInt32Array                               # 6: 700, 800, 900, 1100, 1200, 1400
@export var hit_spread_permille := 500
@export var morale_per_loss := 5
@export var front_drain := 20
@export var reserve_drain := 30
@export var hunger_drain := 30
@export var reserve_shaken_permille := 500
@export var flank_morale := 100
@export var centre_shock := 250
@export var flee_morale := 100
@export var flee_pursuit_permille := 150
@export var flee_morale_left := 150
@export var withdraw_day := 2
@export var withdraw_pursuit_permille := 50
@export var withdraw_pursuit_attacker_permille := 100
@export var withdraw_morale := 250
@export var battle_days := 8
@export var wounded_share_permille := 500
@export var wounded_return_permille := 500
@export var attack_morale := 500
@export var morale_recovery := 250
@export var retreat_range := 6
@export var crossing_penalty_permille := 300
@export var uphill_penalty_permille := 50
@export var river_penalty_permille := 200
@export var relief_defence_add: PackedInt32Array   # 7 relief levels: 0, 0, 0, 50, 150, 300, 500
@export var relief_rough_from := 3
@export var relief_narrow_from := 5
@export var relief_elevation: PackedInt32Array     # 7: 0, 0, 0, 1, 1, 2, 2 (uphill, the siege's need)
@export var rank_xp: PackedInt32Array              # 0, 3, 7
@export var rank_permille: PackedInt32Array        # 1000, 1100, 1200
@export var rank_names: PackedStringArray          # "", "Veteran", "Elite"
@export var xp_win := 2
@export var xp_lose := 1
@export var garrison_attack := 3
@export var garrison_defence := 3
@export var garrison_defence_per_level := 2
@export var castle_defence_permille := 250
@export var garrison_per_level := 400
@export var garrison_regen_per_level := 100
@export var battle_records_kept := 60
@export var siege_base_need := 4
@export var siege_per_level := 3
@export var siege_min_seasons := 2
@export var siege_hunger := 2
@export var siege_rate_max := 6
@export var crowd_bands: PackedInt32Array          # 2000, 4000 (permille of the garrison's men)
@export var storm_cut_permille := 500
@export var militia_men := 250
@export var area_reach: PackedInt32Array           # 4 fortress levels: 0, 1, 2, 3
@export var unsupported_seasons := 6
@export var support_range := 3
@export var occupied_output_permille := 500
@export var occupied_tax_permille := 500
@export var sack_permille := 150
@export var peace_min_seasons := 4
@export var take_score := 3
@export var take_score_weak := 1
@export var white_score_min := -1
@export var capital_score := 3
@export var truce_seasons := 8
@export var war_timer_seasons := 40
@export var war_timer_warning := 32
@export var odds_words: Array[Dictionary] = []     # [{word: "Hopeless", from: 0}, {"Poor", 800}, {"Even", 1000},
	# {"Favourable", 1200}, {"Overwhelming", 2500}] (permille of the ratio; ascending)
@export var odds_ground: Dictionary[StringName, int] = {}   # open 1000, hills 1340, woods 1400, marsh 2080,
	# mountains 3390, snow 2920 (the v0.2.2 measures; re-fitted by B18)
@export var garrison_odds_permille := 3100         # a garrison's weight behind a field army
@export var garrison_odds_alone: PackedInt32Array  # by fortress level 0..3: 0, 1800, 1100, 1000
func validate() -> Array[String]   # every branch in both fight tables with 3 entries 1..4000; the stance keys attack, hold,
	# withdraw 1..4000; dice 6 ascending 1..4000; arrays sized (7, 7, 3, 3, 3, 2, 4, 4); permilles 0..1000 where a share;
	# battle_days 1..20; withdraw_day < battle_days; area_reach ascending 0..10; crowd_bands ascending; odds_words ascending
	# from 0; the six odds_ground keys present; every count >= 0

# core/defs/unit_def.gd  (M6, edit)
@export var attack: int            # 1..20 (4.6)
@export var defence: int           # 1..20
@export var fire_permille: int = 0 # a ranged company's fire a day from the reserve; 0: not ranged
@export var siege_points: int = 0  # added to a siege's rate
func ranged() -> bool              # fire_permille > 0
# validate() adds: attack and defence 1..20; fire_permille 0..200; siege_points 0..6

# core/defs/terrain_def.gd  (M6, edit)
@export var defence_permille: int = 0
@export var rough := false
@export var narrow := false
# validate() adds: defence_permille 0..1000

# core/defs/family_def.gd  (M3 to M6, edit)
@export var fortress: PackedInt32Array   # per level: the fortress level of the piece (settlements 0, 0, 0, 0, 2, 3;
	# castles 0, 1, 2, 3); empty for the goods families. validate(): sized TOP_LEVEL + 1 when set, each 0..3, [0] 0

# core/defs/game_defs.gd  (M2 to M6, edit)
@export var war: WarDef = null           # external: data/defs/war.tres
# validate() adds: war set and war.validate()
```

### 5.2 State (`core/state/`)

```gdscript
# core/state/war.gd  (new)
class_name War extends RefCounted
const SCHEMA := "hexa-godot/war/1"
var id: int
var a: StringName                 # who declared
var b: StringName
var start_turn: int
var end_turn: int = 0             # 0 while it lasts
var terms: StringName = &""       # &"take", &"white", &"yield", &"timer" when it ended
var won_a: int = 0                # battles won by a
var won_b: int = 0
var lost_a: int = 0               # men a lost in battle (killed, wounded not returned, flight, surrender)
var lost_b: int = 0
var moved: int = 0                # districts that changed owner at its peace
func live() -> bool               # end_turn == 0
func other(tag: StringName) -> StringName
static func live_between(wars: Array[War], a: StringName, b: StringName) -> War   # the live war between a and b in
	# either order, or null: the one loop that Wars.at_war, Wars.war_between and Occupation.besieged share
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> War     # null on a wrong schema or type
func digest_text() -> String      # "id|a|b|start|end|terms|won_a|won_b|lost_a|lost_b|moved"

# core/state/battle.gd  (new): a battle between its start (movement) and its fight (battles); never at idle
class_name Battle extends RefCounted
const SCHEMA := "hexa-godot/battle/1"
var hex: Vector2i
var attacker: StringName
var defender: StringName
var start_turn: int
var assault: bool = false
var armies: Dictionary = {}       # tag (String) -> PackedInt32Array of army ids, in the order they came
var tick: int = 0                 # the movement tick it started at
var name: String = ""
var crossing: bool = false
var uphill: bool = false
var river: bool = false
var storm_from: int = 0           # a storm's garrison men before the cut (0: no cut)
var storm_cut: int = 0            # the garrison men the storm faces
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> Battle
func digest_text() -> String

# core/state/battle_record.gd  (new): what a battle was, for the dock, the report and the replay test
class_name BattleRecord extends RefCounted
const SCHEMA := "hexa-godot/battle-record/1"
var id: int
var turn: int
var hex: Vector2i
var name: String
var year: int
var attacker: StringName
var defender: StringName
var input: Dictionary             # Combat.fight's input (5.3), plain values
var luck_before: int              # game.luck.world's state before its first day
var frames: Array[Dictionary] = []   # one a day: {day, rolls: PackedInt32Array [att, def], lanes: [PackedInt32Array 3,
	# PackedInt32Array 3] (keys; -2 empty, -1 the garrison), men: Dictionary {key: men}, morale: {key: permille},
	# routed: PackedInt32Array, shaken: PackedInt32Array, killed: PackedInt32Array [att, def], wounded: [att, def],
	# front: PackedInt32Array [att, def], broke: int (-1, 0, 1), cause: String, withdrew: int}
var end: Dictionary = {}          # Combat's end plus {how, cause, winner, loser (tags), retreat {army: hex}, surrendered:
	# PackedInt32Array (units), returned: {key: men}, stormed: bool, sacked: int (people)}
var witnesses: PackedStringArray
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> BattleRecord
func digest() -> String           # sha256 of var_to_bytes(to_dict()) less witnesses

# core/state/siege.gd  (new)
class_name Siege extends RefCounted
const SCHEMA := "hexa-godot/siege/1"
var hex: Vector2i
var besieger: StringName
var progress: int = 0
var seasons: int = 0
var name: String = ""
var started_turn: int
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> Siege
func digest_text() -> String      # "c,r|besieger|progress|seasons|name|started"

# core/state/unit.gd  (M6, edit): schema "hexa-godot/unit/2" (unit/1 refused)
var morale: int = 1000            # 0..1000
var xp: int = 0
# digest_text() appends "|morale|xp"
# core/state/army.gd  (M6, edit): schema "hexa-godot/army/2" (army/1 refused)
const ORDER_STORM := &"storm"
const STANDING_HOLD := &"hold"
const STANDING_WITHDRAW := &"withdraw"
var standing: StringName = STANDING_HOLD
# digest_text() appends "|standing"; mustering() unchanged
# core/state/map_state.gd  (M1 to M5, edit): schema "hexa-godot/map-state/5"
var occupier: PackedByteArray     # per hex: 0 the owner holds it, else the occupying country's id. Occupation only
var garrison: PackedInt32Array    # per hex: men of a fortress's garrison; 0 elsewhere. Occupation only
var unsupported: PackedByteArray  # per hex: seasons an occupied hex had no support (D18). Occupation only
# create() sizes the three; duplicate_state() copies them; to_dict() adds them packed; from_dict() reads schema 5, and 1
# to 4 with the three at zeros; digest() adds them in this order
# core/state/stats.gd  (M3 to M6, edit): SERIES appends "battle_losses", "battles_won", "battles_lost", "districts_held",
#   "districts_lost", "garrison_men", "garrison_lost" (49)

# core/game/game.gd  (M1 to M6, edit; the fields)
var wars: Array[War] = []                    # Wars; id order
var next_war_id: int = 1                     # Wars
var battles: Array[Battle] = []              # Battles; hex index order; empty at idle
var battle_records: Array[BattleRecord] = [] # Battles; id order, the newest battle_records_kept
var next_record_id: int = 1                  # Battles
var battle_names: Dictionary = {}            # Battles: place (String) -> battles named there
var sieges: Array[Siege] = []                # Sieges; hex index order
var siege_names: Dictionary = {}             # Sieges: place -> sieges named there
var war_cache: WarCache = WarCache.new()     # the door's derived cache; not saved, not in the digest
```

### 5.3 Systems (`core/systems/`)

Systems never call `Words`; their words name a hex by `Military.hex_text` (M6) and a country by "the " + its long name.

```gdscript
# core/systems/wars.gd  (new)
class_name Wars extends RefCounted
const OWNS: Array[String] = ["wars", "next_war_id"]
const TERMS: Array[StringName] = [&"take", &"white", &"yield"]
static func at_war(game: Game, a: StringName, b: StringName) -> bool      # War.live_between(game.wars, a, b) != null
	# (Movement.hostile)
static func enemies(game: Game, tag: StringName) -> Array[StringName]      # id order
static func war_between(game: Game, a: StringName, b: StringName) -> War   # War.live_between(game.wars, a, b)
static func of_country(game: Game, tag: StringName) -> Array[War]         # live and ended, id order
static func score(game: Game, a: StringName, b: StringName) -> int         # 4.2, the M9 seam
static func occupied_count(game: Game, by: StringName, of_tag: StringName) -> int
static func truce_until(game: Game, a: StringName, b: StringName) -> int  # 0 when none
static func men_under_arms(game: Game, tag: StringName) -> int             # Armies.men_of_country
static func declare_war_check(game: Game, args: Dictionary) -> Dictionary  # {target, tag}; 4.2
static func declare_war(game: Game, args: Dictionary) -> Dictionary
static func make_peace_check(game: Game, args: Dictionary) -> Dictionary   # {target, terms, tag}; 4.9
static func make_peace(game: Game, args: Dictionary) -> Dictionary
static func ceded(game: Game, war: War, terms: StringName, actor: StringName) -> Array[Vector2i]   # what would move (the
	# country panel's question and the peace)
static func end_war(game: Game, war: War, terms: StringName, actor: StringName) -> void   # 4.9's steps (make_peace, timer)
static func book_battle(game: Game, record: BattleRecord) -> void
static func season(game: Game) -> void       # the war phase: the timer
static func digest(game: Game) -> String     # the wars (digest_text, id order) and next_war_id

# core/systems/occupation.gd  (new): the only writer of occupier, garrison and unsupported
class_name Occupation extends RefCounted
const OWNS: Array[String] = ["occupier", "garrison", "unsupported"]
static func setup(game: Game) -> void                                    # occupier 0; every fortress at full (new_scenario)
static func fortress_level(game: Game, hex: Vector2i) -> int             # FamilyDef.fortress of the piece; 0 none
static func garrison_full(game: Game, hex: Vector2i) -> int
static func controller_id(game: Game, hex: Vector2i) -> int              # occupier or owner; 0 sea, off the map, unowned
static func controller_tag(game: Game, hex: Vector2i) -> StringName
static func is_occupied(game: Game, hex: Vector2i) -> bool
static func controlled(game: Game, id: int) -> PackedInt32Array           # hex indices it controls, ascending; war_cache
static func besieged(game: Game, hex: Vector2i) -> bool                  # a siege on the hex whose besieger is at war with
	# its controller (reads game.sieges and War.live_between)
static func siege_need(game: Game, hex: Vector2i) -> int                 # 4.5's need from level, garrison and ground
static func storm_garrison(game: Game, hex: Vector2i, tag: StringName) -> int   # the garrison a storm by tag faces (D19):
	# garrison x (1000 - storm_cut x progress / need) / 1000, rounded up; the uncut garrison when tag besieges nothing there
static func area_of(game: Game, hex: Vector2i) -> Vector2i                # its fortress, or Army.NO_HEX; war_cache
static func area_state(game: Game, hex: Vector2i, standing: PackedByteArray = PackedByteArray()) -> StringName
	# &"castle", &"held", &"fallen", &"open"; `standing` (a byte a fortress hex: 1 stood at the phase's start) when given
static func members(game: Game, fortress: Vector2i) -> PackedInt32Array   # its area, nearest first
static func standing(game: Game) -> PackedByteArray                       # 1 on every fortress its owner controls
static func capture(game: Game, hex: Vector2i, tag: StringName, by: StringName, info: Dictionary) -> void
	# occupier = tag's id (0 when tag is the owner), the garrison's men booked lost, unsupported 0; district_captured;
	# the hex joins the pending flush
static func release(game: Game, hexes: Array[Vector2i]) -> void            # occupier 0 (a peace); pending flush
static func set_garrison(game: Game, hex: Vector2i, men: int) -> void      # 0..full; garrison losses booked by the caller
static func regrow(game: Game, hex: Vector2i) -> int                      # 4.3; returns men levied
static func flush(game: Game) -> void                                     # one controllers_changed for the pending hexes
static func support_season(game: Game) -> void                            # D18 (in the sieges phase)

# core/systems/war_cache.gd  (new): the door's derived cache: areas, controlled lists, the fortress list
class_name WarCache extends RefCounted
func fortresses(game: Game) -> PackedInt32Array      # fortress hex indices, ascending
func area_index(game: Game) -> PackedInt32Array      # per hex: its fortress's hex index, -1 none
func controlled(game: Game, id: int) -> PackedInt32Array
func forget_areas() -> void                          # owners_changed, a fortress level changed
func forget_control() -> void                        # controllers_changed, owners_changed
func clear() -> void

# core/systems/combat.gd  (new): the whole battle as a pure function (no writes but the Rng's draws)
class_name Combat extends RefCounted
const OWNS: Array[String] = []
const LANES := 3
const CENTRE := 1
const FILL_ORDER: PackedInt32Array = [1, 0, 2]
const GARRISON := -1
const EMPTY := -2
static func ground_of(game: Game, hex: Vector2i) -> Dictionary   # {cover, relief, defence, rough, narrow, key (an
	# odds_ground key), elevation}
static func attack_value(war: WarDef, attack: int, branch: StringName, fight: int, rank: int) -> int
static func defence_value(war: WarDef, defence: int, branch: StringName, fight: int, rank: int, ground: int, castle: int,
		versus_cavalry: bool) -> int
static func hit(war: WarDef, ctx: Dictionary, striker: Dictionary, target: Dictionary, base: int, extra: int, rng: Rng) -> int
static func fight(war: WarDef, input: Dictionary, rng: Rng) -> Dictionary
	# input: {hex, attacker, defender, assault, ground (ground_of), crossing, uphill, river, stance: {att, def},
	#  can_retreat: {att, def}, fighters: Array[{key (unit id), side (0 attacker, 1 defender), army, kind, branch, men,
	#  full, attack, defence, fire, rank, morale, hungry}] (key order), garrison: {men, full, level} or {}}
	# returns {frames: Array[Dictionary] (BattleRecord's), end: {how, cause, winner (0, 1, -1), loser, days,
	#  men: {key: men}, morale: {key}, wounded: {key: men}, killed: PackedInt32Array, wounded_total: PackedInt32Array,
	#  lost_whole: PackedInt32Array (bombards of a flight), garrison: {men, morale}, storm: bool}}
static func day(war: WarDef, state: Dictionary, rng: Rng) -> Dictionary   # one day on fight's working state
static func odds_strength(men: int, morale: int) -> int                     # men x morale / 1000 (4.6, the odds)
static func odds_factor(war: WarDef, ground_key: StringName, assault: bool) -> int   # odds_ground[key]; 1000 in an assault
static func odds_word(war: WarDef, ratio_over_factor_permille: int) -> String     # D50: the last band at or below

# core/systems/battles.gd  (new): a battle's life
class_name Battles extends RefCounted
const OWNS: Array[String] = ["battles", "battle_records", "next_record_id", "battle_names"]
static func at(game: Game, hex: Vector2i) -> Battle                  # the live battle there, or null
static func of_army(game: Game, army_id: int) -> Battle
static func engage_check(game: Game, args: Dictionary) -> Dictionary # {army, hex, tag}; 4.7 (also the tick's check)
static func engage(game: Game, army: Army, hex: Vector2i, tick: int, last_edge: int) -> bool   # 4.6: a battle or a join
static func fits(game: Game, tag: StringName, hex: Vector2i, adding: int) -> bool
static func input_of(game: Game, battle: Battle) -> Dictionary      # Combat.fight's input from the live state
static func season(game: Game) -> void                              # the battles phase (4.6)
static func record(game: Game, id: int) -> BattleRecord             # null when no longer kept
static func records_of(game: Game, tag: StringName, turn: int = 0) -> Array[BattleRecord]   # newest first; turn 0 all
static func name_for(game: Game, hex: Vector2i) -> String           # and counts it in battle_names
static func retreat_spot(game: Game, tag: StringName, armies: Array[Army], hex: Vector2i, own_only: bool) -> Vector2i
static func can_retreat(game: Game, tag: StringName, hex: Vector2i) -> bool
static func digest(game: Game) -> String

# core/systems/battle_end.gd  (new): applying a fought battle (split from battles.gd: size)
class_name BattleEnd extends RefCounted
const OWNS: Array[String] = []                    # writes through Armies, Occupation, People, Wars, Battles
static func apply(game: Game, battle: Battle, result: Dictionary, luck_before: int) -> BattleRecord   # 4.6, the end
static func sack(game: Game, hex: Vector2i) -> int                   # people killed (D27)

# core/systems/sieges.gd  (new)
class_name Sieges extends RefCounted
const OWNS: Array[String] = ["sieges", "siege_names"]
static func at(game: Game, hex: Vector2i) -> Siege
static func terms(game: Game, hex: Vector2i, tag: StringName, men: int = -1, guns: int = -1) -> Dictionary
	# {men, garrison, full, crowd, guns, rate, need, stores, ok}; men and guns -1: tag's armies on the hex
static func forecast(game: Game, hex: Vector2i, tag: StringName, men: int, guns: int, progress: int, seasons: int) -> int
	# seasons until it falls at this rate, the arrival season counted; -1 never (too few men) or past 60
static func starving(game: Game, hex: Vector2i) -> bool              # a siege there whose stores are out
static func season(game: Game) -> void                               # the sieges phase (4.4, 4.5, garrisons, D18): lifts and
	# removals first (4.5), then the meters, captures, regrowth and support. Battles and peaces never touch game.sieges:
	# this phase reads their outcome (this season's records, the controller, the wars)
static func digest(game: Game) -> String

# core/systems/armies.gd  (M6, edit): the door gains
static func lose_unit_men(game: Game, army: Army, unit_id: int, amount: int, why: StringName) -> int   # unit_lost at 0
static func set_morale(game: Game, army: Army, unit_id: int, morale: int) -> void
static func add_xp(game: Game, army: Army, unit_id: int, xp: int) -> void
static func set_standing(game: Game, army: Army, standing: StringName) -> void
static func recover_morale(game: Game) -> void      # the ready_units phase (4.12)
static func morale_of(army: Army) -> int            # men-weighted, permille
static func rank_of(game: Game, unit: Unit) -> int  # 0, 1, 2 by WarDef.rank_xp
# lose_men (M6) books why &"battle" or &"surrendered" as well as &"starved"; a unit raised starts at morale 1000

# core/systems/military.gd  (M6, edit)
static func standing_check(game: Game, args: Dictionary) -> Dictionary   # {army, standing, tag}; 4.7
static func set_standing(game: Game, args: Dictionary) -> Dictionary
# can_stand: a hex holding an army of a country at war with tag counts only tag's units (a battle hex); raise_check gains
#   "held by the %s: no men can be raised here" (row 4b, after the home rule) on an occupied hex

# core/systems/movement.gd  (M6, edit)
static func hostile(game: Game, a: StringName, b: StringName) -> bool    # Wars.at_war (the test pairs kept)
static func storm_check(game: Game, args: Dictionary) -> Dictionary      # {army, goal, tag}; 4.7
static func storm(game: Game, args: Dictionary) -> Dictionary
# open_to, open_mask, zoc_halts, the tick step, march_check row 7: 4.8

# core/systems/supply.gd, sight.gd, people.gd, works.gd, economy.gd, economy_season.gd  (M3 to M6, edits): 4.10 to 4.12;
#   People.FLOWS appends &"garrisoned", &"sacked"; People.levy(game, tag, hex, men, why := &"raised");
#   Works.halted adds "occupied or besieged"; Works.build_check, upgrade_check, clear_check gain row 3b "held by the %s: no
#   work can begin on occupied land" and "under siege: no work can begin"
# core/systems/supply_cache.gd  (M6, edit): func forget_at_war(game: Game) -> void   # forget(id) for every country in a live
#   war (4.12)
# core/systems/stats_system.gd  (M3 to M6, edit): 4.19
```

**OWNS after M7** (`tests/core/test_owns.gd` diffs `Snapshot.of` around every action and phase):

| Field | Written by | In an action | In a phase |
|---|---|---|---|
| `wars`, `next_war_id` | `Wars` | `declare_war`, `make_peace` | `battles` (`book_battle`), `war` |
| `battles`, `battle_records`, `next_record_id`, `battle_names` | `Battles` | no | `movement` (engage), `battles` |
| `sieges`, `siege_names` | `Sieges` | no | `sieges` |
| `occupier`, `garrison`, `unsupported` | `Occupation` | `make_peace` | `battles` (storm), `sieges`, `war` |
| `owner` | `Territory` (M2) | `make_peace` | `war` (a timer peace moves none; kept for M9) |
| `armies` (units, men, morale, xp, standing, hex, order) | `Armies` | M6's, `storm`, `set_standing`, `make_peace` (sent home) | `movement`, `battles`, `supply`, `war`, `ready_units` |
| `people`, `people_flows` | `People` | M6's | `battles` (sacked), `sieges` (garrisoned), M6's |
| `luck` | drawn through `Rng` | no | `battles`, `calendar` |
| everything of M6's table | as M6 5.3 | | |
| `events`, `action_log`, `chronicle`, `version`, `view_cache`, `districts`, `sight`, `supplies`, `war_cache` | `Game` (the door; `DOOR_FIELDS` gains `war_cache`) | yes | yes |

### 5.4 Game, the action table, the season, saves (`core/game/`)

```gdscript
# core/game/game.gd  (M1 to M6, edit)
const DOOR_FIELDS: Array[String] = ["events", "action_log", "chronicle", "version", "view_cache", "districts", "sight",
	"supplies", "war_cache"]
func emit(event: Dictionary) -> void      # M6's, plus: Sight.SIGHTED kinds get witnesses (the actor and `others` always);
	# owners_changed calls war_cache.forget_areas() and forget_control(); controllers_changed calls war_cache.forget_control(),
	# supplies.forget and sight.forget_land for tag and others; hex_changed of a hex whose fortress level changed calls
	# war_cache.forget_areas()
# new_scenario: after People.setup: Occupation.setup (garrisons full). dev_transfer: Occupation.release(hexes) first.
# digest(): M6's string + "|" + Wars.digest(game) + "|" + Battles.digest(game) + "|" + Sieges.digest(game)

# core/game/actions.gd  (M3 to M6, edit)
const NAMES: Array[String] = ["build", "upgrade", "clear", "cancel_work", "choose_country", "set_tax", "raise", "march",
	"halt", "continue_march", "split_army", "merge_armies", "disband", "declare_war", "make_peace", "storm", "set_standing"]
#   declare_war {target, tag}  make_peace {target, terms, tag}  storm {army, goal, tag}  set_standing {army, standing, tag}
# pair_of: declare_war, make_peace -> Wars' pairs; storm -> Movement's; set_standing -> Military's

# core/game/season.gd  (M3 to M6, edit)
const PHASES: Array[StringName] = [&"movement", &"battles", &"supply", &"sieges", &"war", &"production", &"income",
	&"works", &"people", &"stats", &"calendar", &"ready_units", &"vision"]
# run_phase: movement -> MovementPhase.season, then game.supplies.forget_at_war(game); battles -> Battles.season, then
#   game.supplies.forget_at_war(game); sieges -> Sieges.season; war -> Wars.season; ready_units -> Military.refill, then
#   Armies.recover_morale

# core/game/snapshot.gd  (M3 to M6, edit): the war key, map-state/5, army/2, unit/2; restore type-checks every new field,
#   refuses army/1 and unit/1, and rebuilds war_cache empty
# core/game/save_file.gd  (M3 to M6, edit): FORMAT := 5; OLDEST_FORMAT := 5
# core/game/replay.gd  (M3): unchanged (the M7 actions are played through Game.act)
```

### 5.5 Events and Session (`shell/autoload/`)

```gdscript
# shell/autoload/events.gd  (edit): added signals
signal war_declared(tag: StringName, target: StringName)
signal peace_made(tag: StringName, target: StringName, terms: StringName)
signal battle_started(hex: Vector2i, attacker: StringName, defender: StringName)
signal battle_joined(hex: Vector2i, tag: StringName)
signal battle_fought(hex: Vector2i)
signal battle_ended(hex: Vector2i, record: int, winner: StringName)
signal siege_started(hex: Vector2i, tag: StringName)
signal siege_progress(hex: Vector2i, tag: StringName, progress: int, need: int)
signal siege_lifted(hex: Vector2i, tag: StringName, why: StringName)
signal district_captured(hex: Vector2i, tag: StringName, by: StringName)
signal controllers_changed(hexes: Array[Vector2i])

# shell/autoload/session.gd  (edit): drain() sends the eleven kinds to their signals, then chronicled (M3) for the notable
#   ones; last_phase_ms gains battles, sieges, war
```

The `battle_ended` fields are the war-goals contract (`docs/design/war-goals-and-peace.md` 3.4): the two tags and the hex;
`winner` the side that did not break, withdraw or get destroyed; a draw (`gone`, and the reserved `peace`) has `winner` and
`loser` `&""` and scores nothing; `killed` and `wounded` per side for the whole battle, pursuit and surrender included (a
surrendered side's men as killed); `assault`. M9 reads it unchanged.

### 5.6 Views (`core/views/`, pure)

```gdscript
# core/views/battle_view.gd  (new): the read-only battle view, from a record
class_name BattleView extends RefCounted
const ROUND_MEN := 100
const ROUND_MORALE := 50
static func access(game: Game, viewer: StringName, record: BattleRecord) -> StringName   # &"exact", &"seen", &"hidden"
static func of(game: Game, viewer: StringName, record_id: int, day: int = -1) -> Dictionary
	# {} hidden or unknown; else {access, id, name, year, hex, place, days, day (shown; -1 the last), sides: {attacker:
	#  [tag], defender: [tag]} (lists: alliances later), viewer_side (&"attacker", &"defender", &""), ground: {text ("Farmland
	#  · 3 lanes"), lanes_open, chips: [{text, icon, helps (tag)}]}, side: {tag: {name, arms, role_text ("Attacker · you"),
	#  general_text ("No general"), men, start, killed, wounded, roll, mult_text ("×1.1"), mult_tone, front (permille),
	#  stance_text (exact only), lanes: [3 x {key, kind, name, figure, men, full, morale, routed, shaken, fires, empty,
	#  closed, broken}], reserve: [{key, name, figure, men, morale, fires}], routed: [...]}}, log: Array[{day, text, tone}],
	#  result: {text, tone, winner, how}, kept: bool (false: the record is gone; the totals from the chronicle entry)}
	# cached [&"battle_view", version, viewer, record_id, day]
static func sites(game: Game, viewer: StringName) -> Array[Dictionary]
	# the battle badges: records of turn game.turn - 1 the viewer may see: {record, hex, name, tone (&"good", &"bad",
	#  &"plain"), front: PackedInt32Array [att, def], attacker_colour_id, defender_colour_id}; cached [&"sites", version, viewer]
static func latest_of(game: Game, tag: StringName) -> int    # B's record: the newest record tag fought in; -1 none
static func log_line(record: BattleRecord, frame: Dictionary, names: Dictionary) -> String   # the day's sentence (as v0.2.2
	# battlelog.describe): "Day 2: Savoy 48 killed, 46 wounded; Milan 61 killed, 59 wounded. Milan broke (centre)."

# core/views/odds_view.gd  (new): the odds card
class_name OddsView extends RefCounted
static func of(game: Game, viewer: StringName, army_id: int, hex: Vector2i, storm: bool = false) -> Dictionary
	# {kind (&"attack", &"siege", &"storm", &"walk_in", &"held", &"none"), ok, reason, title, word, tone,
	#  ratio_permille (or -1), factor_permille, attack: {men, morale, strength}, defence: {access, men, morale, strength,
	#  garrison: {men, weight_permille, cut}}, chips: [{text, helps}], besiege: {seasons, need, rate, stores, too_few_text},
	#  storm_word, opens (districts), held_by: {hex, name, distance}}; cached [&"odds", version, viewer, army_id, hex, storm]
static func word(game: Game, ratio_over_factor_permille: int) -> String   # Combat.odds_word with game.defs.war

# core/views/siege_view.gd  (new)
class_name SiegeView extends RefCounted
static func at(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary
	# {} none or hidden; else {access, name, besieger, defender, besieger_name, defender_name, place, progress, need, rate,
	#  hunger, seasons, stores_left, starving, falls_in, garrison_text, relief: [{army, hex, men_text, seasons}] (the
	#  defender's armies that can reach it within 4 seasons, nearest 3; exact viewer only)}
static func all(game: Game, viewer: StringName) -> Array[Dictionary]   # the dials: {hex, progress, need, tone}; cached

# core/views/area_lines.gd  (new)
class_name AreaLines extends RefCounted
const DASH := 6.0
const GAP := 4.0
const WIDTH := 1.6
static func for_chunk(game: Game, viewer: StringName, chunk: Vector2i) -> Array[Dictionary]
	# {kind: "area", points: [corner, corner], colour_id (the owner's), dashed: true} on every edge between a held hex of an
	# area of a standing fortress of a country at war with viewer and a hex outside that area
static func area_bytes(game: Game, viewer: StringName) -> PackedByteArray   # 1 on those held hexes (the 12 % tint)
static func chunks_touched(game: Game, hexes: Array[Vector2i]) -> Array[Vector2i]
static func held_by(game: Game, hex: Vector2i) -> Dictionary   # {state, fortress, name ("the castle of Pavia"), distance}

# core/views/cards_war.gd  (new): hover cards
class_name WarCards extends RefCounted
static func site(game: Game, viewer: StringName, record_id: int) -> Dictionary    # {title, lines, hint "Click: the battle"}
static func siege(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary    # "Siege of Pavia: 6 of 10" + lines

# core/views/move_preview.gd  (M6, edit): to() gains war: {kind (as OddsView), text, tone} and odds (OddsView.of) for an
#   attack, siege or storm target; reach() unchanged; the walk-in and held notes of castle-areas 4 card 3
# core/views/army_view.gd  (M6, edit): panel() gains standing, morale (permille) per unit and the army's, rank name per unit,
#   siege {hex, name, progress, need, falls_in}, storm_verdict, last_battle {record, name, result}; tokens() gains besieging
#   and shaken flags
# core/views/hex_card.gd  (edit): "Fortress" (level words and "garrison 800 of 800", banded for others), "Held by" (the
#   occupier, since), the area line (held by the castle of X, N hexes; open land) when a war of the viewer is on, "Siege"
# core/views/country_card.gd  (edit): war: {state (&"war", &"peace", &"truce", &"self"), since_text, score, held_theirs,
#   held_yours, truce_text, declare: {verdict}, peace: [{terms, label, verdict, moves: Array[Vector2i], text}]}
# core/views/map_modes.gd  (edit): OCCUPIED_STRIPE_PX := 8.0; AREA_ALPHA := 0.12; occupier texels from MapState.occupier;
#   area_bytes through AreaLines; colour_of(..., occupier_id := 0, area_byte := 0): stripes of the occupier's palette colour
#   over the owner's in OWNER and the Terrain tint (alternating bands of OCCUPIED_STRIPE_PX along x + y)
# core/views/knowledge.gd  (M3, M6, edit): battle_access, siege_access (4.15); war facts public
# core/views/season_summary.gd, reminders.gd, log_lines.gd, study_military.gd, study_history.gd (edits): 4.14, 4.17, 4.18,
#   6.9; LogLines.FILTERS' war (since "7") shows; line_of() gains record (the battle record id of a battle_ended line, -1
#   elsewhere); StudyHistory.MARK_KINDS gains &"war" first (icon &"battle"): the viewer's
#   war_declared, peace_made and battle_ended
# core/views/replay_plan.gd  (M6, edit): record_battle(hex: Vector2i, tick: int); poses() also returns {battles:
#   [{hex, shown}]} from that tick; retreats play as walks after the last movement tick
```

---

## 6. The UI of M7

Built from the M1.5 kit and the M3 to M6 pieces. Colours and fonts from the Theme; HUD controls take no focus, screens do.
The milestone `Bindings.SHELL_MILESTONE` (the App's value) becomes `"7"`, so the `since: "7"` rows of `Bindings.DEFAULTS` and `Settings.SCHEMA` register and
show and `LogLines.FILTERS`' War appears.

### 6.1 Keys and settings

| Action (`Bindings.DEFAULTS`) | Key (Mac) | Since | Who hears it | Does |
|---|---|---|---|---|
| `map_command` (exists) with Shift | Shift+right click (Shift+two-finger click) | 7 | `MapInput.storm_requested(map_px)` (read from the event's `shift_pressed`, as M6's Shift+click) | with an army of yours selected: `storm` at that hex; else as a right click |
| `map_command_storm` (**new**, "Storm at the cursor", Map) | Shift+O | 7 | `MapInput.storm_key_requested` (tested with `is_action(..., true)`, exact, before `map_command_key`) | `storm` at the cursor |
| `game_battle` (**new**, "Last battle", Game) | B | 7 | `MapInput.battle_requested` | the dock on `BattleView.latest_of(player)`; "You have fought no battle." toast |

`Bindings.GESTURES` gains "Shift+right click (Shift+two-finger click): storm a fortress with the selected army".

| `Settings.SCHEMA` key | Type (default) | Page, row | Since |
|---|---|---|---|
| `map/castle_areas` (**new**) | bool (true) | Map: "Castle areas with an army selected"; also the Layers popover's "Castle areas" switch | 7 |

### 6.2 Bake slice 6: the war pieces (`tools/ui_bake/pieces_m7.py`, new)

| Texture | Size (1x) | What |
|---|---|---|
| `badge_battle` | 40 x 40 | crossed swords on a dark roundel, ink outline (the ring drawn at run time in the result's tone) |
| `badge_siege` | 40 x 40 | a gate tower on a dark roundel (the amber dial drawn at run time) |
| `icons_war` (atlas, 24 px cells) | 192 x 72 | `war`, `peace`, `truce`, `battle`, `siege`, `storm`, `besiege`, `attack`, `hold`, `withdraw`, `flee`, `victory`, `defeat`, `fortress`, `garrison`, `area_held`, `area_open`, `routed`, `shaken`, `fires`, `occupied`, `uphill`, `pass_cross`, `river_cross` |
| `die_face` | 28 x 28 | a bone d6 face (the pips drawn by `DieFace`) |

`build_theme.gd` adds them as `Kit` icons. `shell/ui/tokens.gd` gains `WAR_DIAL #f0a850` (WARN's value, named for the
dial), `WAR_DIAL_TRACK #3a2416`, `AREA_INK_ALPHA 0.9` (the bake re-runs: `tokens_sha`). The art director signs the war sheet
(`bake_ui.py --sheet`): both badges in each tone at r8, r13 and r34 (mockup 20's sizes), the 24 icons, the die face 1 to 6.

### 6.3 The map: war marks, castle areas, occupied land (`shell/map/`, `shell/mapview/`)

| z | What | Node | Since |
|---|---|---|---|
| 80 | the overlay gains the occupied stripes and the area tint | `ModeOverlay` | M2, M7 |
| 82 | the castle-area dashed lines | `TileMapView` `Areas` (`EdgeLineLayer` a chunk, kind `area`) | M7 |
| 88 | army tokens (a besieging token shows the `siege` state icon) | `ArmyTokens` (M6) | M6 |
| 89 | battle sites and siege dials, with their hover cards | `WarMarks` | M7 |
| 90 | the selection and the order cursor | `marks` | M1, M6 |

```gdscript
# shell/map/war_marks.gd  (new)
class_name WarMarks extends Node2D     # z_index 89; one mark per BattleView.sites and SiegeView.all entry
signal site_clicked(record: int)
signal siege_clicked(hex: Vector2i)
func setup(view: TileMapView) -> void
func refresh(game: Game, viewer: StringName) -> void   # adds, updates, frees marks to match the two views
func flash_lifted(hex: Vector2i) -> void               # the grey flash of a lifted siege (0.6 s; instant under reduce motion)
func mark_at(hex: Vector2i) -> Node2D
# shell/mapview/tile_map_view.gd  (M1, M2, M6, edit): AREAS_Z := 82; set_chunk_areas(chunk, lines), area_chunks()
# shell/mapview/edge_line_layer.gd  (M1, M2, edit): kind "area": a dashed stroke of the line's colour (DASH, GAP, WIDTH)
# shell/map/mode_overlay.gd + .gdshader  (M2 to M6, edit): textures occupier (R8) and area (R8); uniforms stripes_on,
#   stripe_px, area_on, area_alpha; update_occupiers(hexes), update_areas(bytes) -> int (texels written); occupier_bytes(),
#   area_bytes() copies for tests
# shell/map/map_scene.gd  (M1 to M6, edit): the WarMarks node; refresh on battle_ended, siege_started, siege_progress,
#   siege_lifted, district_captured, controllers_changed, war_declared, peace_made, season_ended, game_started; the overlay's
#   occupier texels on controllers_changed; the area lines and tint shown while an army of yours is selected, a war of yours
#   is on and map/castle_areas is on (built for every chunk at selection, sliced 5 ms a frame, kept until a controller,
#   owner or fortress change or a peace); ribbons "Siege 6/10" (siege_progress) and "−420 men" (battle_fought) through
#   Floaters.add_ribbon (M5)
```

- **A battle site** (the season that ended): `badge_battle` 30 px above the hex's middle, its ring in the result's tone
  (good: the viewer won; bad: lost; muted: others'), the front-morale bar under it (attacker's colour from the left, the
  defender's from the right, split at their front morale, a tick at each flee line); the place name stays (M1 labels). Below
  zoom 0.6 the mark keeps its screen size. A click opens the dock; the hover card is `WarCards.site`.
- **A siege**: `badge_siege` with the amber dial filling clockwise from the top (`progress / need`, one tick a point); the
  hover card `WarCards.siege` ("Siege of Pavia: 6 of 10 · Each season +2 · Falls in about 1 season · The garrison starves
  after 3"). A click selects the hex (the hex panel shows the siege). A lifted siege flashes grey once.
- **Occupied land**: in Owner mode and the Terrain tint, diagonal bands of the occupier's colour 8 px wide alternate with the
  owner's; borders follow the owner (M2). The minimap shows the same (the same material).
- **Castle areas** (mockup 21, the first version): while an army of yours is selected and a war of yours is on, every held
  area of an enemy's standing fortress has a 1.6 px dashed ink line in the owner's colour on its outer edges and a 12 % tint
  inside; fallen and open land have no line.

### 6.4 The odds card (`shell/hud/odds_card.tscn/.gd`, new)

```gdscript
class_name OddsCard extends PanelContainer    # PanelCard, 300 px, mouse ignored, focus none; by the pointer (or the cursor)
func show_odds(preview: Dictionary) -> void   # MovePreview.to(...) whose war.kind is attack, siege, storm, walk_in or held
func hide_card() -> void
```

Shown instead of the move card (M6) when the hovered hex (or the order cursor) is a war target of the selected army. Lines
(from `preview.odds` and `preview.war`): the title (the place); the kind and the word in its tone ("Attack · Favourable",
"Besiege · falls in about 4 seasons", "Storm · Poor"); "You 2,000 men · morale 100 %"; "They about 1,000 men · morale 100 %"
(or "a garrison of 800 · counts ×3.1 behind its walls"); the ground chips ("Woods +25 % for them", "Uphill −5 %", "Across the
Sesia −20 % on day 1"); the route's arrival ("There in Autumn 1480"); for a fortress "Garrison starves after 3 seasons",
"Taking it opens 6 districts", "Shift+right click: storm (Poor)"; for held land "Moves in, but cannot take it: held by the castle
of Pavia (10, 9), 2 hexes away." in normal text and "Besiege it: falls in about 4 seasons." in `Hint`; for open land "Takes it
at the end of the season."; a refusal in `BAD` with its way out ("Too shaken to attack: morale 34 %, 50 % needed." / "It
recovers 25 a season when fed."). The right-click toast says the first line.

### 6.5 The battle dock (`shell/screens/battle_dock.tscn/.gd`, new; `OVERLAY`, 420 px, left)

```gdscript
class_name BattleDock extends Screen          # kind OVERLAY; a PanelFrame with the cartouche title
func show_record(record_id: int, day: int = -1) -> void   # BattleView.of(Session.game, Session.player_tag(), id, day)
func step_day(delta: int) -> void
func play() -> void                           # the days from day 1, 0.6 s each; reduce motion: jumps to the last
func shown_record() -> int
# shell/screens/battle/regiment_tile.tscn/.gd  (new): RegimentTile, a PanelSlot: figure, name, men, men bar and morale bar
#   (progress_fill), marks (routed red tile, shaken "!", fires gold, READY none in M7), the hover card of mockup 18
# shell/screens/battle/battle_picture.gd  (new): BattlePicture (Control): the battle hex's ground tile from the season's
#   TilesetBuilder.load_season (shell only), the two sides' figures from the Kit atlas facing each other, badge_battle between
# shell/ui/tug_bar.gd  (new, kit): TugBar: two halves growing from the middle, each in its side's palette colour, a tick at
#   each side's flee line, the percentages beside; Tokens only
# shell/ui/die_face.gd  (new, kit): DieFace: die_face with 1 to 6 pips (Tokens.VELLUM_INK) and the multiplier under it
```

| Part (mockup 18, option A) | Content (from `BattleView.of`) |
|---|---|
| Title band | the name ("Battle of Alessandria, 1480"), a look-at button (glides to the hex), close |
| Face-off | the attacker left, the defender right: `CountryArms` (small), the name, "Attacker · you", "No general" greyed (M11); the `BattlePicture` between, "Farmland · 3 lanes · day 3" under it |
| Stats, mirrored | "Men now / start", killed, wounded; a `DieFace` each side with "×1.1" in its tone |
| Front morale | a `TugBar` "Front-line morale · flees under 10 %" |
| Board | the enemy's reserve chips, its three lane tiles, the dashed front line (crossed swords over each fighting lane, a hatched closed lane, a dashed red broken lane, a dashed grey empty one), your three lanes, your reserve; for a watcher, the attacker below |
| Below the board | "Fought on: Attack · them: Hold"; your armies' standing order line with a button "Open the army" (when it still exists); the ground chips; the day log (4 lines, "Full log" toggles all) |
| Result | "Savoy won in 4 days: Milan broke (centre) and fled to (8, 8)." in its tone |
| Day stepper | ◀ "Day 3 of 4" ▶ and Play (`KitButton`s); Left, Right, Home, End with the dock focused; Enter plays |

Opened from a battle badge, a report or log line, a notification's Go, the Military page's Battles table, the army panel's
last battle, and B; the camera glides so the hex sits in the free part of the map right of the dock. Esc closes it (M1.5's
ladder: the top screen). A hidden record shows nothing (the opener refuses with "You did not see that battle."); a record no
longer kept shows the totals of its chronicle entry and "The day-by-day account of this battle is no longer kept."

### 6.6 The war alert and `DECISIONS` (`shell/app/decision_queue.gd`, new; `shell/app/season_flow.gd`, edit)

```gdscript
class_name DecisionQueue extends RefCounted
signal emptied
func push(decision: Dictionary) -> void      # {kind: &"war_declared", tag, target, turn}
func count() -> int
func next(ctx: ShellContext) -> bool         # pushes the next decision's Confirm; false when none is left
func clear() -> void
```

The App pushes a decision on `Events.war_declared` when the target is the player. `SeasonFlow` gains `decisions_start`
((on_done: Callable) -> bool) and `decisions_done()`: after `replay_done()` (or RUNNING when there was no replay) the flow
enters **DECISIONS** when the queue is not empty and shows them one by one; when it empties, **REPORT** as M3. A declaration
at idle (the console in M7, M8's AI never at idle) pushes its `Confirm` at once.

The `Confirm` ("War!", danger tone, seal "!"): lines "The Duchy of Milan has declared war on the Duchy of Savoy.", "Their
armies may now enter your land, and yours theirs. Your armies' standing orders decide what they do when attacked."; choices
**Show the Duchy of Milan** (secondary: closes, the country panel, a glide) and **To the report** (primary, focused, Esc;
"To the map" at idle). Save is refused while the flow is in `DECISIONS` (M3 D48).

### 6.7 The country panel's war section (`shell/panels/country_panel.tscn/.gd`, M2 to M6, edit)

From `CountryCard.of(...).war`:

| State | Rows |
|---|---|
| Another country at peace | "At peace"; a `KitButton` of kind DANGER "Declare war" with `set_verdict(Session.check("declare_war", {target}))`; a click asks `Confirm` ("Declare war on the Duchy of Milan?", lines "Your armies may enter their land and attack theirs; theirs may enter yours.", "A white peace needs 4 seasons of war; taking land needs 3 of their districts held, or their armies beaten.", choices **Declare war** (danger) and **Cancel** (focused)) |
| In a truce | "Truce until Spring 1483 (8 more seasons)"; Declare war off with its reason |
| At war | "At war since Spring 1480 · score +2" (a `DeltaChip`), "You hold 2 of their districts; they hold none of yours."; three buttons **Take what you hold**, **White peace**, **Yield**, each with `set_verdict(Session.check("make_peace", {target, terms}))` and its reason as the lock's tooltip; a click asks `Confirm` naming what moves ("Peace with the Duchy of Milan: Domodossola (7, 6) and Locarno (7, 5) become yours; every other district returns." / "...: everything returns to its owner." / "...: Asti (8, 10) becomes theirs.") |
| Your own country | "Wars: at war with the Duchy of Milan (+2)" with a link per war; "Truces: the Republic of Genoa until Winter 1481" |

Refreshes on `war_declared`, `peace_made`, `district_captured`, `controllers_changed`, `season_ended`.

### 6.8 The hex panel, the army panel, the hex menu (M2 to M6, edits)

- **Hex panel** (`shell/panels/hex_panel.tscn/.gd`): under the Owner row, the **area chip** (mockup 21): "Held by the castle of
  Pavia (10, 9), 2 hexes" (a shield), "Open land: no castle holds it" (plain), "Open: the castle of Pavia has fallen" (a broken
  shield), shown while a war of the player is on; "Held by the Duchy of Savoy since Summer 1480" on occupied land; a
  **Fortress** row ("Walled town · garrison 800 of 800"; others banded); a **Siege** block when besieged (SiegeView: "Pavia is
  besieged by Savoy. 6 of 10, +2 a season (crowd 2, guns 0). The garrison starves after 3 seasons. Falls in about 1 season.",
  for the defender "Relief: the Army of Lodi, 1 season away"), and for an army of yours on it **Storm now** with the odds word
  (`Session.act("storm", {army, goal: hex})`, its verdict). Refreshes on the siege and capture signals.
- **Army panel** (`shell/panels/army_panel.tscn/.gd`, M6): a `Segmented` "If attacked: Hold | Withdraw"
  (`Session.act("set_standing", ...)`, the hover saying both prices: "Withdraw leaves after 2 days: 5 % of its men and 25
  points of morale; if it breaks first it flees: 15 % and its guns."); the army's morale ("Morale 62 %"; "too shaken to attack:
  50 % needed" in `Reason`); per company its morale bar and rank ("Veteran"); "Besieging Pavia (10, 9): 6 of 10" with **Storm**;
  "Last battle: the Battle of Alessandria, 1480 (won)" as a link to the dock. Refreshes on `battle_ended`, `siege_progress`.
- **Hex menu** (`shell/hud/hex_menu.gd`, M6): on a hex with a battle site of the last season "Open the Battle of Alessandria,
  1480"; on a besieged hex "Show the siege of Pavia"; on another country's land "Show the Duchy of Milan" (the country panel,
  where Declare war is).

### 6.9 The Military and History pages (`shell/screens/study/page_military.*`, `page_history.*`, M4.5, M6, edits)

`StudyMilitary.of` (M6) gains `wars: [{tag, country, since_text, state_text, score, won, lost, yours_lost, theirs_lost,
held_theirs, held_yours, tone}]` (live first, then ended, newest first), `battles: [{record, name, result, yours_lost,
theirs_lost, tone}]` (the viewer's last 12), and `series.battle_losses`.

| Part | Built from | Reads |
|---|---|---|
| Losses (M6) | the `InkChart` `STACKED_BAR` gains "Battle" (`ink_1`, hatch) beside "Hunger" | `series.army_starved`, `series.battle_losses` |
| Wars (**new**) | `SectionHead` "Wars"; a `StudyTable`: Enemy, Since, Score (delta), Battles (text "2 won, 1 lost"), Your losses (number), Theirs (number), Held (text "2 of theirs · 0 of yours"), State (text: "at war", "peace: took 2", "white peace", "truce until Spring 1483"), Go (button: the country panel) | `wars` |
| Battles (**new**) | `SectionHead` "Battles"; a `StudyTable`: Battle, Result (text in tone), Your losses, Theirs, Open (button: the dock) | `battles` |

Empty states: "No war yet." and "No battle yet." The History page's timeline shows the `war` marks (crossed swords) first;
its chronicle's War filter shows from milestone 7.

### 6.10 The report, the task flag, notifications, the log, ribbons, toasts

- **The report screen** (`shell/screens/season_report.gd`, M3, edit): draws the `war` section (the nav gains "War" with its
  count); battle lines open the dock (`[&"battle", record]`), siege and capture lines look at the hex.
- **Task flag and notifications** (M3, edits): the three rules of 4.18; notifications for a war on you, your battles, your
  fortresses besieged, fallen or lifted, districts taken and lost, a peace; Go opens the dock or looks at the hex.
- **The log** (`shell/hud/action_log.gd`, M3, M4.5, edit): the War filter; a line whose `record` is 0 or more (a `battle_ended`
  line, `LogLines.line_of` gains `record`, -1 elsewhere) is a button that sends `ctx.request(&"battle", {record})` instead of
  `look_at`.
- **Ribbons** (M3, M5): "War!", "Peace", "Victory!", "Defeat!", "Battle", "Siege", "Siege 6/10", "Lifted", "Taken", "Lost",
  "Freed", "−420 men".
- **Toasts** M7 adds: a declaration ("War with the Duchy of Milan."); a peace ("Peace with the Duchy of Milan: you took 2
  districts."); an attack order ("The Army of Vercelli marches on Alessandria (7, 9): Favourable, there in Autumn 1480."); a
  siege order ("The Army of Vercelli marches to besiege Pavia (10, 9): falls in about 4 seasons."); a storm order ("The Army of
  Vercelli marches to storm Pavia (10, 9): Even.", the storm's odds word); a standing
  order ("The Army of Turin now withdraws when attacked."); a refusal (its reason); B with no battle.

### 6.11 The App, F3, the console

| Request or event | The App (`shell/app/game_requests.gd`, `app.gd`) |
|---|---|
| `MapInput.storm_requested(map_px)`, `storm_key_requested` | with an army selected: `Session.act("storm", {army, goal})`, the toast; else as a right click |
| `MapInput.battle_requested`, `app_requested(&"battle", {record})`, `WarMarks.site_clicked` | push `BattleDock` (`ScreenIds` `battle_dock`) at the record, glide |
| `WarMarks.siege_clicked(hex)` | select the hex |
| `app_requested(&"declare_war", {target})`, `(&"peace", {target, terms})` | the `Confirm` of 6.7, then `Session.act`, the toast |
| `Events.war_declared` (the player the target) | `DecisionQueue.push`; at idle `next` at once |
| `SeasonFlow.decisions_start` | `DecisionQueue.next`, its `emptied` -> `flow.decisions_done()` |
| `MapScene.army_selected`, `army_cleared` (M6) | the area lines on and off (6.3) |
| `Events.season_ended` | `StudyWarm` adds `StudyMilitary.of` with the wars and `BattleView.sites` |

- **F3** (`shell/hud/debug_overlay.gd`, edit): "wars 1 · battles 1 · sieges 1 · occupied 2 · battles 0.8 ms · sieges 0.3 ms ·
  war 0.0 ms · areas 139".
- **Console** (`shell/hud/dev_commands.gd`, edit): `declare TAG` (`declare_war`), `peace TAG take|white|yield`
  (`make_peace`), `storm ID c r`, `standing ID hold|withdraw`, `wars` (prints yours: enemy, since, score), with M6's `as TAG`;
  problems: "no country TAG", "no such terms", "no army ID", "no such standing order", each a planted fault in its test.
- **The Layers popover** (`shell/hud/layers_popover.tscn/.gd`, edit): a "Castle areas" `KitSwitch` on `map/castle_areas`;
  hidden in the sandbox.
- The App sets `Bindings.SHELL_MILESTONE` to `"7"`. `Hud` gains the `OddsCard` slot beside the `MoveCard`. `screen_ids.gd` gains `battle_dock`.

---

## 7. Data and the editor

| File | Holds | Made by | Checked by |
|---|---|---|---|
| `godot/data/defs/war.tres` (**new**) | `WarDef` (5.1, the values of 4.3 to 4.9) | by hand in the inspector (task B1); the odds words and ground factors re-fitted by B18 | `tests/core/test_war_defs.gd`: loads, validates, equals 4.3 to 4.9 |
| `godot/data/defs/units/{pikemen,crossbowmen,knights,bombards}.tres` (M6, edit) | `attack`, `defence`, `fire_permille`, `siege_points` (4.6) | by hand (B1) | `tests/core/test_unit_defs.gd` |
| `godot/data/defs/terrain/*.tres` (M6, edit) | `defence_permille`, `rough`, `narrow` (4.6) | by hand (B1) | `tests/core/test_terrain_defs.gd` |
| `godot/data/defs/families/{settlements,castles}.tres` (M3 to M6, edit) | `fortress` (4.3) | by hand (B1) | `tests/core/test_family_defs.gd` |
| `godot/data/defs/game_defs.tres` (edit) | `war` (external) | by hand (B1) | `test_economy_defs.gd` runs `GameDefs.validate()` |
| `godot/tools/war_tables.gd` (**new**, headless) | prints 4.3's, 4.5's and 4.6's tables as Markdown from the `.tres` | B1 | `test_war_defs.gd` runs it and compares one row of each |
| `godot/tools/war_report.gd` (**new**, headless) | the scenario table of 4.6 (win rate, days, losses by pair, ratio and ground, 100 seeds), the siege table of 4.5 played in the engine, held land per country on seeds 1480 to 1484, the odds bands fitted to the measured rates | B18 | `test_odds.gd` ties every band to the measured rates; the report goes into B18's pull request |
| `godot/assets/ui/kit/` (slice 6) | the textures of 6.2 at 1x and 2x | `tools/bake_ui.py` (B3) | `bake_ui.py --check`, `build_theme.gd --check` in CI |
| `godot/data/README.md` (edit) | `war.tres`, the new fields | B1 | |

No generated game data; the map file and the scenario are unchanged (`build_map --check`, `build_scenario --check`).

---

## 8. Speed

`godot/tools/perf_core.gd` (M3 to M6) on the made-up Europe: `PerfFixture.europe_war(seasons)` (**new**, in
`godot/tools/perf_fixture.gd`): M6's `europe_armies` and, at its start, 30 wars between neighbouring pairs (the lowest-id
countries first, each pair once) declared through `declare_war`; each country at war orders half its armies by `march` at the
nearest enemy army or garrisoned fortress of its enemy (`Rng` seeded 1480), re-ordered on arrival; `seasons` seasons through
`Season.run`. Rows in `godot/tests/perf_core_budget.json`, nightly, never in GUT:

| Row | Limit | What |
|---|---|---|
| `season_ms` | **380** (M6: 320) | the thirteen phases, worst of 8 seasons |
| `battles_ms` | 20 | the battles phase with 20 battles of 8 against 8 (`PerfFixture.battle_set(20)`) |
| `fight_ms` | 1.5 | one `Combat.fight` of 8 against 8, mean |
| `sieges_ms` | 25 | the sieges phase with 100 sieges and 1,000 occupied districts |
| `war_ms` | 2 | the war phase |
| `areas_cold_ms` | 150 | the war cache's areas and controlled lists from cold |
| `odds_ms` | 2 | one `OddsView.of`, uncached |
| `battle_view_ms` | 2 | `BattleView.of` of an 8-day record, uncached |
| `area_lines_ms` | 300 | `AreaLines.for_chunk` over every chunk for one viewer (the slices' total) |
| `movement_ms` | 25 (M6) | with battles engaged at the ticks |
| `save_mb` | 8 (M3) | with 60 records, the occupation and garrison arrays |

`godot/tools/ui/perf_ui.gd` gains in `perf_ui_budget.json`: `battle_dock_open_ms` 16 (an 8-day record, cold); `dock_day_step_ms`
4; `war_marks_refresh_ms` 4 (60 marks); `odds_hover_ms` 4 (a hover change to the card drawn, cold); `area_show_ms` 16 (the first
slice of the area lines on north Italy). North Italy for scale: 340 land hexes, a few battles: nothing there is measurable.

**How the battles phase stays in budget.** A battle is a few dozen fighters and at most 8 days; each day is a handful of loops
over 3 lanes and the reserves, all integers; the values of each fighter are worked out once a battle (they change only with
rank and ground). If `fight_ms` fails, the first fallback is caching each pair's `att / def` for the battle; the second, one
spread draw per lane and phase instead of per hit (the dice stay per day).

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (P).

| File | Cases |
|---|---|
| `tests/core/war_fixture.gd` (**new**) | `WarFixture.savoy(defs)`: M6's `ArmyFixture.savoy` with the Milanese army of 4.16 (a); `at_war(game, a, b)`; `army_at(game, tag, hex, kind, count)` builds an army through the `Armies` door (tests only) |
| `tests/core/combat_fixture.gd` (**new**) | `CombatFixture.input(sides, ground, garrison)` builds a `Combat.fight` input on a fixture ground; `CombatFixture.rng(seed)` |
| `tests/core/test_war_defs.gd` (**new**); `test_unit_defs.gd`, `test_terrain_defs.gd`, `test_family_defs.gd` (M6, edits) | the files load, validate, equal 4.3 to 4.9 and 5.1; `war_tables.gd`'s rows; P: a fight table of 2 entries, dice not ascending, withdraw_day 8 with battle_days 8, an odds word out of order, a missing odds_ground key, area_reach not ascending, attack 0, a fortress level 4 |
| `tests/core/test_war_state.gd` (**new**); `test_army_state.gd`, `test_map_data.gd`, `test_stats.gd` (M6, edits) | `War`, `Battle`, `BattleRecord`, `Siege` round trips; `digest_text` moves with every field; `unit/2`, `army/2`, `map-state/5`; P: `army/1` and `unit/1` refused, a string for `occupier`, a record frame without `lanes`; 49 series, a dict without the seven loads them as zeros |
| `tests/core/test_wars.gd` (**new**) | every row of `declare_war_check` and `make_peace_check` with its words (P each); `score` symmetric, the capital term; `make_peace` take, white, yield: what moves, the capital and the last district kept (P: a take that would leave a country with no district moves one less), occupations released, `game.sieges` untouched (the next `sieges` phase lifts them with `peace`), armies sent to the nearest own hex with room (and disbanded home with none), the truce; the timer at 40 seasons and the warning at 32; `book_battle`; `war_declared` and `peace_made` witnesses are every living country |
| `tests/core/test_occupation.gd` (**new**) | `fortress_level` for every piece; `setup` fills garrisons; the 18 fortresses, their garrisons and area sizes and the held land by country of 4.3 on seed 1480; `area_state` for each state (castle, held, fallen, open); a crest without a pass stops an area; ties by level then index; `capture` (each `by`), `release`, `flush` (one `controllers_changed` per phase); `regrow` levies the hex then the ring (flow `garrisoned`), only for an owner-held, unbesieged fortress; D18 after 6 seasons, reset by support; the war cache dropped by `owners_changed`, `controllers_changed` and a fortress's `hex_changed` (P: a cache that ignores `controllers_changed` is caught) |
| `tests/core/test_combat.gd` (**new**) | the values of 4.6 for each branch and fight; the worked hit (33 men) with a stub `Rng`; each phase on fixtures (deploy order, shaken after day 0, fire by kind and lane, back line, shock both ways, flanks ×1.25, pikes against horse); morale (loss, drains, hunger, rank); the break test (centre, lanes, narrow, morale); the flight; Withdraw from the end of day 2 with its price; the cap at 8 and its loser; the garrison in the centre and the assault values; `fight` is pure (the same input and `Rng` state give the same output; the input unchanged); the 30-seed bands of 4.6 (P: a shock of 0 fails a band) |
| `tests/core/test_battles.gd` (**new**) | `engage_check` every row (P each); a step onto an enemy makes one battle and `battle_started`; a join within the stack limit (P: a ninth company refused); an assault with a garrison; a storm order on arrival and when besieging; stances from standing orders (Withdraw only with a retreat hex); `input_of` from the state; the end: men and morale applied, units lost (`battle`), bombards lost on a flight, retreat to the nearest spot by the rules (own first for Withdraw), surrender with none (`surrendered`), wounded returned only in supply, experience, a stormed fortress (occupier, garrison 0, a town sacked); records kept to 60 (the oldest dropped); `battle_fought` and `battle_ended` fields (the war-goals contract, a case per `how`); `game.battles` empty after the phase; `game.sieges` never written (P: a battle phase that removes a siege is caught) |
| `tests/core/test_sieges.gd` (**new**) | `terms` and `forecast`; every cell of 4.5's table played in the engine; the floor (P: a siege that falls in 1 season fails); hunger after the stores; no progress in a season with a battle on the hex; lifts by each `why`; a fall opens the area from the next season, not this one; walk-in on open land with 250 men (P: 249 men take nothing), nothing on held land, retake of own land; the storm cut |
| `tests/core/test_movement.gd`, `test_military.gd`, `test_supply.gd`, `test_sight.gd`, `test_people.gd`, `test_works.gd` (M3 to M6, edits) | `open_to` with a war; the mask closes hostile fortresses but the goal; ZOC beside a fortress; the tick: engage, join, blocked, a step onto a fortress; `march_check` row 7 through `engage_check`; `storm_check` every row, `standing_check` every row (P each); `can_stand` per side; raising refused on occupied land; the field over controlled land, depots with fortresses, a hostile army cuts it; sight from controlled land; `People.FLOWS` nine; occupied growth by the controller's tax and food; besieged hunger; the sack; levies refused on occupied hexes; works halted on occupied or besieged hexes and refused to begin there |
| `tests/core/test_war_economy.gd` (**new**) | 4.10's table on fixtures: occupied output and taxes at half to the occupier, needs in full from its stores, nobody pays upkeep or walls, a besieged hex nothing; with no war every M4 and M5 number of `test_economy_1480.gd` and `test_people_growth.gd` unchanged; ceded land in full from the next production |
| `tests/core/test_war_savoy.gd` (**new**) | **done-when 1 to 5**: 4.16 (a) to (e) season by season, hex by hex, man by man; the battle's result pinned for seed 1480 |
| `tests/core/test_season.gd` (M3 to M6, edit) | **`PHASES` is `[movement, battles, supply, sieges, war, production, income, works, people, stats, calendar, ready_units, vision]`** (the pin); a capture counts in that season's production; morale recovery in `ready_units` |
| `tests/core/random_player.gd` (M6, edit) | adds `declare_war` (a neighbour or anyone), `make_peace` (random terms), `storm` (an army and a fortress near or far), `set_standing`, and marches onto enemy armies and fortresses |
| `tests/core/test_war_property.gd` (**new**) | **done-when 6**: 40 seasons, the random player for every country, weather drawn; the men identity of 4.14 per country and for the world; the district invariants; no shared hex outside the battles phase; `game.battles` empty at idle; garrisons ≤ full; morale 0 to 1,000; every siege on a garrisoned fortress with its besieger alone there |
| `tests/core/test_check_contract.gd`, `test_men_property.gd`, `test_money_property.gd`, `test_people_property.gd` (M4 to M6, edits) | the 17 actions; the identities with the M7 terms (sacked, garrisoned, battle losses) |
| `tests/core/test_battle_replay.gd` (**new**) | **done-when 8**: a snapshot after the movement phase with battles pending restores and plays on to the same digest; every record of a 20-season war fought again from its input and `luck_before` gives the same digest (P: a changed spread in one hit gives another); a record's last frame equals the units' men and morale after the battle; the dock's frames sum to `battle_ended`'s totals |
| `tests/core/test_snapshot.gd`, `test_save_file.gd`, `test_replay.gd`, `test_owns.gd`, `test_game_core.gd`, `test_forty_seasons.gd`, `test_insights_views.gd` (edits) | wars, sieges, records, occupation, garrisons, morale and standing round-trip; save, load, save byte-equal; a save in the third season of a siege plays on equal (done-when 4); `FORMAT` 5 (P: a format-4 header reads `older`; a string for a siege's `progress`); 20 seasons of random war actions give the same digest (P: a changed `make_peace` terms gives another); 5.3's OWNS table (P: a test-only phase writing `occupier` directly is reported); `DOOR_FIELDS`; the pins move to M7's values (thirteen phases, `FORMAT` 5, 49 series, twenty notable kinds, seventeen actions) |
| `tests/core/test_battle_view.gd`, `test_odds_view.gd`, `test_siege_view.gd`, `test_area_lines.gd`, `test_cards_war.gd` (**new**) | the view of a record exact, seen (rounded) and hidden (P: an unwitnessed record gives `{}`); a day's frame; `sites` only the last season's; `latest_of`; the odds kinds and words, the garrison weight, the ground factor, the chips, the refusal; the siege view and its fog; area lines on every outer edge of a held area and none on open land, the tint bytes; the hover cards |
| `tests/core/test_move_preview.gd`, `test_army_view.gd`, `test_hex_card.gd`, `test_country_card.gd`, `test_map_modes.gd`, `test_knowledge.gd`, `test_log_lines.gd`, `test_chronicle.gd`, `test_season_summary.gd`, `test_reminders.gd`, `test_study_military.gd`, `test_study_history.gd`, `test_replay_plan.gd` (edits) | the war field and the odds in `to()`; the panel's standing, morale, rank, siege, last battle; the Fortress, Held by, area and Siege lines; the war section's states and peace options; the occupied stripes in `colour_of` (both palettes) and the area tint; the access rules; the sentences of 4.14 for the player, a witnessed other and an unwitnessed one; `NOTABLE`; the War section on the Savoy fixture, equal after a save and load; the three rules (P: a white war of 31 seasons makes no `war_timer`); the wars and battles rows; the war marks; `record_battle` and the retreat ticks |
| `tests/shell/test_session.gd`, `test_season_flow.gd` (edits), `test_decision_queue.gd` (**new**) | the eleven signals drained after their phases, then `chronicled`; `DECISIONS` after `REPLAY` with one war declared on the player, then the report; at idle the alert at once; Save refused in `DECISIONS`; the queue's order |
| `tests/shell/test_battle_dock.gd`, `test_regiment_tile.gd`, `test_tug_bar.gd`, `test_die_face.gd`, `test_odds_card.gd`, `test_war_marks.gd` (**new**); `test_mode_overlay.gd`, `test_map_scene.gd`, `test_layer_stack.gd`, `test_country_panel.gd`, `test_hex_panel.gd`, `test_army_panel.gd`, `test_hex_menu.gd`, `test_page_military.gd`, `test_page_history.gd`, `test_season_report.gd`, `test_task_flag.gd`, `test_notifications.gd`, `test_action_log.gd`, `test_map_input.gd`, `test_bindings.gd`, `test_settings.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_hud.gd`, `test_app_flow.gd` (edits) | every part of 6.5 for a won, lost and watched battle and a narrow field; the stepper, Play and reduce motion; the tile's marks; the odds card's lines per kind; badges from the views (P: a hidden record makes no badge), the dial, the flash; the occupier and area textures write only changed texels (P: one byte, one texel); z 82 and 89; the war section's states and its `Confirm`s; the area chip, Fortress, Siege block, Storm now; the standing segment and Storm; the hex menu's items; the Wars and Battles tables, the Battle series; the War section and its links; a log battle line opens the dock; the rules' lines; Shift+right click, Shift+O (exact match), B; `map/castle_areas` (P: a bad value falls back); the console commands and their planted faults; the F3 line; end to end: New game as Savoy, the console's Milanese army, declare war (the `Confirm`), raise and march, the odds card, End season, the replay with the battle badge, the report's War section, B opens the dock, Play, a siege of a castle with a save and load, a peace from the country panel |
| `tests/shell/test_ui_monkey.gd` (edit) | adds Shift+right clicks, Shift+O, B, clicks on badges and the dock, the country panel's war buttons; invariants: the digest changes only after an accepted action or a season; no two countries' armies share a hex at idle; the dock never changes the digest |
| Python `tests/test_bake_ui.py` (edit) | slice 6's pieces at both scales; the catalogue; the asserts of style spec 4.4 |
| `godot/tools/map/probe_mode_overlay.gd` (M2 to M6, edit; windowed, CI under xvfb) | the stripes and the area tint: the pixel at every hex middle equals `colour_at` (tolerance 3); P: `--plant` swaps an occupier id and prints FAIL |
| Pictures (`godot/tools/ui/shot_ui.gd`, edit) | the dock (won, lost, narrow ground) against `docs/design/ui/18_battle_panel_v3_a_3lanes.png`; the odds card for an attack, a siege and held land; a battle site and a siege dial against `20_siege_badge.png` (option B); the castle areas with an army selected against `21_castle_area.png`; occupied land in Owner mode in both palettes; the country panel's war section; the war alert; the report's War section; the Military page with wars and battles; at 1280 x 720 scale 1 and 2560 x 1440 scale 2; signed by the art director, then goldens `godot/tests/goldens/m7_*.png` (0.5 %) |

**Determinism:** `test_replay`, `test_forty_seasons`, `test_war_property`, `test_check_contract`, `test_battle_replay`
(battles draw only `Luck.world`, in hex index order, each hit and roll in a fixed order). **Save round trip:**
`test_snapshot`, `test_save_file`, `test_battle_replay` (mid-battle snapshot), `test_war_savoy` (mid-siege file),
`test_season_summary` (J after a load: the War section equal).

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| The battle numbers do not fit the bands on 500-man companies and integer hits | `war_report.gd`'s scenario table on B7's last day (a scratch run of `Combat.fight`) and in B18 (the engine), read by Opus before group F | the shock and morale numbers are data (S each); the odds words follow the measures |
| GDScript too slow for the battles phase on Europe | `fight_ms` in B7's first days (a probe of 1,000 fights of 8 v 8) | section 8's two fallbacks |
| Battles that end in their phase give the player no decision in a fight | the playtest (steps 6 to 8); the standing order and the odds card are the decisions | the 0.2.3 battle board, its own milestone after M12; or a day cap per season (data, S) |
| Castle areas hold too much or too little on the dense map (41 %) | `war_report.gd`'s held land on seeds 1480 to 1484 in B18 | `area_reach` 0, 1, 1, 2 or 0, 2, 3, 4 (data) |
| Zones of control beside fortresses make marches crawl | the playtest's march to Pavia (step 10) | ZOC from fortresses off (one line) |
| The passive enemy makes the war one-sided and the peace trivial | expected until M8; the playtest uses the console for Milan's army | none in M7 |
| A take peace snowballs before M9 | the truce (D32), the capital and last district kept; the soak from M8 | `take_score` higher (data) |
| Records grow saves | `save_mb` nightly with 60 records | `battle_records_kept` 20 |
| The stripes read as noise over the tint | the pictures of section 9 | `OCCUPIED_STRIPE_PX` 12, or stripes in Owner mode only (constants) |
| The occupation term breaks M4's preview equality | `test_economy_preview.gd` with occupied land in a fixture (the preview counts today's occupations) | none needed: one code path |
| The war alert is a pop-up the owner disliked (P2 of 0.2.1) | the playtest; it comes only when a war is declared on you | a notification only (S) |
| Mid-battle saves never happen in play | by design (D5): the snapshot test proves the format | none |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 5.3, row 5: "War: the 40-season safety peace (M7); peace offers (M9)"; 9.2: the M7 row points at this spec and its plan, status "specified and planned, waits for the owner's go; starts after M6 closes"; the last row reads M8 to M12 |
| `docs/architecture/m1-build-spec.md` | Section 5, the layer table: rows z 82 (castle-area lines, M7) and z 89 (war marks, M7) |
| `docs/architecture/m2-build-spec.md` | 13, row M7: points here (the `occupier` byte, `transfer` only at a peace, the stripes in both palettes) |
| `docs/architecture/m3-build-spec.md` | 5.6: `SECTIONS` gains `war` (M7) after `armies`; 12, row M7: points here (works wait on occupied land) |
| `docs/architecture/m4-build-spec.md` | 12, row M7: points here (occupied output at half to the occupier; upkeep none; besieged nothing) |
| `docs/architecture/m4-5-build-spec.md` | 12, row M7: points here |
| `docs/architecture/m5-build-spec.md` | 12, row M7: points here (flows `garrisoned` and `sacked`; no `district_declined` by war; no refugees; besieged hunger) |
| `docs/architecture/m6-build-spec.md` | D4: generals move to M11; 12, row M7: points here (no `Army.battle`: `army/2` is the standing order) |
| `docs/architecture/m6-build-plan.md` | Section 7, the M7 bullet: points here |
| `docs/architecture/ui-and-controls-spec.md` | 4.1: the rows `map_command_storm` (Shift+O; Shift+right click) and `game_battle` (B) |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M7: the tasks are those of `m7-build-plan.md`, with this spec's files |
| `docs/architecture/ui-style-and-feedback-spec.md` | 6.4: the section ids gain `war`; 8: a note that M7's Military page parts are specified here |
| `docs/architecture/ui-style-and-feedback-plan.md` | S5, row M7: folded into `m7-build-plan.md` |
| `docs/design/ui/game-feedback-screens.md` | C.2: a line that M7's wars and battles are on the Military page (this spec 6.9) |
| `docs/design/war-goals-and-peace.md` | 3.4: a line that the Godot `battle_ended` is `m7-build-spec.md` 4.14 and 5.5 |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `godot/README.md` (the keys, the war, the console; B28), `godot/data/README.md` (B1),
`CLAUDE.md` (the `war_report.gd` line in the Godot commands; B18). No port rule changes: no new autoload, no new layer;
`tools/lint_godot.py` needs no entry (new files sit in listed folders, each under 800 lines: `battles.gd` and `battle_end.gd`
are split for that).

---

## 12. What M7 hands to later milestones

| M | Takes from M7 | M7 leaves for it |
|---|---|---|
| M8 | The AI acts through `declare_war`, `make_peace`, `march` (attack, besiege), `storm`, `set_standing` with the same checks; it reads `OddsView`, `SiegeView` (`falls_in`), `Sieges.forecast`, `Occupation.area_state`, `BattleView`, `Wars.score`, `Wars.truce_until`, `Knowledge` and the reminders `besieged`, `occupied`; `fight_ms`, `battles_ms`, `sieges_ms` are its budget rows; war alerts from AI declarations fill `DECISIONS`; taken up in `m8-build-spec.md` 4.9 to 4.11 (`Sieges.forecast_for` and `Knowledge.garrison_estimate`, also in `OddsView`; the peace alert in `DECISIONS`) | The AI's war: when to declare, whom to attack, when to sue |
| M9 | `Wars.score`'s body (worth by level, battle points from `War.won_*` and the records), `make_peace`'s terms list (the peace screen replaces the three buttons), the truce (12 after terms), `War` gains a goal and a casus belli, peace offers in the `war` phase, the `battle_ended` contract, `war_declared` gains `cb` and `goal`, Relations; the Diplomacy page takes the Wars table; taken up in `m9-build-spec.md` (terms deal, white, surrender; `make_peace` moves to `Peace`; `WarDef` loses its six peace fields to `DiplomacyDef`; the brakes are M9's) | Diplomacy and peace |
| M10 | Road works change `StepCosts` and so retreats and areas; markets may feed besieged towns; **taken up in `m10-build-spec.md`** 4.9 and 4.10 (retreats and areas follow `game.steps`; a besieged market town shuts its market, so no market feeds a besieged town) | Trade |
| M11 | Generals (a kind or a trait, `Military.stack_limit` +2, one term each in `attack_value`, `defence_value` and the morale loss), techs that change `WarDef` numbers through definitions only, later kinds' attack and defence, era 2 shot; **taken up in `m11-build-spec.md`** 4.10, 4.11 and 4.14 (generals as traits on armies; each side's `WarDef` in `Combat`'s input; the era 2 shot is the missile branch's fire) | Research |
| M12 | Countries that fall (a war ends with its side), desertion through `Armies.lose_men`, score with battles (war weariness and the brakes of `stop-steamrolling.md` moved to M9: `m9-build-spec.md` 4.9 to 4.13) (taken up in `m12-build-spec.md` section 12: battles count as deeds in the prestige) | A whole game |
| After M12 | The battle board (the 0.2.3 mini game between days, width 3 to 7, back slots, rotation, cards): `Combat.fight` and the records are its seam; field forts (`sieges-and-retreats.md` 6) | |
| **E2, E3** | **Nothing blocking: wars, battles, sieges, occupation and areas scale with countries, armies and fortresses; the Europe budgets are measured on the made-up Europe (section 8).** | |
