# Fog build plan: two fog levels (issues 446 and 435)

Technical director, 2026-11-24. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/fog-build-spec.md` ("the spec"), which builds `docs/design/two-fog-levels.md` as the owner answered it.

**When it runs.** After M8 is closed and before M9 starts: M9 to M12's specs read `Knowledge` and must find the new rules
(spec, appendix A). Issue 435 is a bug of today's game (a conqueror blind in its own conquest), so by the "fix issues first"
rule the fog build goes before new features. **Recommended:** build it before the tile window (ui-family-audit U1), so U1
builds on the final rules; if the owner wants U1 first, group C's hex card task (FG6) moves into U1's `TileView` instead.

**Task IDs** are `FG1` to `FG19` (K is taken by M1.5 and M8, F by the UI controls spec).

---

## 1. Groups, effort, order

S is about half a day of one worker, M a day.

| Group | Ships | Tasks | Effort |
|---|---|---|---|
| **A. Foundations** | the start data, the save format, the thin fixture and the baseline numbers | FG1, FG2, FG3 | 1 M, 2 S |
| **B. The rules** | sight by control, discovery at once, the land witness marker; `Knowledge`'s new functions | FG4, FG5 | 2 M |
| **C. Views, AI, map core, invariants** | every view of spec section 5 except the marks and labels; the AI door; the deep-fog fill; the soak's fog invariants | FG6 to FG14 | 9 M |
| **D. Behaviour and the map's marks** | the AI re-pinned on the soak; marks and labels | FG15, FG16 | 2 M |
| **E. Proofs and finish** | the cross-view tests, `band` deleted, the monkey, perf rows, pictures, player docs | FG17, FG18, FG19 | 3 M |

**19 tasks: 17 M, 2 S**, about 18 worker-days; about 6 working days end to end (each group as long as its longest task),
plus reviews and the owner's playtest.

```
M8 closed, owner's go
  -> A:  FG1  FG2 (S)  FG3 (S)                 (FG3 records the perf baseline before any rule moves)
  -> B:  FG4  FG5                              (technical director reads both interfaces before merge)
  -> C:  FG6  FG7  FG8  FG9  FG10  FG11  FG12  FG13  FG14
  -> D:  FG15  FG16                            (FG15's soak tables: the systems designer's verdict before E)
  -> E:  FG17  FG18  FG19  -> the owner plays the checklist of section 5

Critical path: FG1 -> FG4 -> FG12 -> FG15 -> FG17      (and FG5 -> FG9 -> FG15; FG13 -> FG16 -> FG19)
```

A group starts when every task of the group before it is merged. Inside a group no two tasks touch one file and no task
calls code another task of its group writes. Shared fixtures have one owner: `tests/core/fog_fixture.gd` FG3,
`tests/fixtures/report_sample.gd` FG8, `tests/fixtures/ui_sample.gd` FG19.

---

## 2. Tasks

*Sonnet* builds the rules, views, AI door, saves, tools and anything touching `Game`, `Session` or the soak; *Haiku* builds
fixtures, the monkey step, pictures and player text from a list. **Every task's done-when includes: lint
(`python tools/lint_godot.py godot`), check_scripts and GUT green, both UI `--check`s, `build_map --check` and
`build_scenario.gd --check`; no planted fault (P) of an edited test is deleted without a replacement.** Paths without a
prefix are under `godot/`; `tools/`, `docs/`, `README.md` are at the repository root.

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| FG1 | M, Sonnet | **The start data by region** | edit `core/defs/scenario_def.gd` (`regions`, `region`, `discovery`, `discovery_of`, `validate`, `digest`), `data/scenarios/north_italy_1480.tres` (one region `europe`, 13 entries), `godot/tools/build_scenario.gd` (writes `region` from the region source, keeps the fields, `--check`), `core/mapgen/fake_scenario.gd` (no regions), `data/README.md`; edit `tests/core/test_scenario_defs.gd`, `test_fake_scenario.gd` | Spec R5, R7, D3, section 4: the five planted faults of R5; north Italy's `discovery_of` is every bit for each of the 13 tags; `build_scenario.gd --check` green; the scenario digest changes (said in the pull request) |
| FG2 | S, Sonnet | **Save format 7** | edit `core/game/save_file.gd` (`FORMAT` 7, `OLDEST_FORMAT` 7, the doc line); edit `tests/core/test_save_file.gd` | Spec R38, D16: a format-6 header reads `older` (P: a 6 that loads); a format-7 round trip on north Italy byte-equal |
| FG3 | S, Haiku | **The thin fixture and the baseline** | `tests/core/fog_fixture.gd` (new: `thin`, `duel_thin`), `tests/core/test_fog_fixture.gd` (new) | Spec 7: `thin(g, tag, r)` leaves exactly the land sight grown by `r` (P: a thin set missing the own land); the perf baseline of spec 8's rows run once on the made-up Europe and north Italy, the numbers in the pull request |

### Group B (after A, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| FG4 | M, Sonnet | **Sight by control, discovery at once, land events** | edit `core/systems/sight.gd` (`setup` with `discovery_of`, `sees` and `witnesses_of` by control, `on_emit` for `district_captured`, `owners_changed`, `controllers_changed`, `LAND_KINDS` and the `land` marker), `core/systems/sight_cache.gd` (`land_of` by control, `explored_revision`, forgotten on `controllers_changed`); edit `tests/core/test_sight.gd`, `test_no_other_writers.gd`, `test_owns.gd` | Spec R6, R9 to R13, R16, R17, R30, closes issue 435: every case and planted fault of spec 7 for these tests; `witnesses_agree_with_sees_for_every_country` by control; the five writers pinned |
| FG5 | M, Sonnet | **Knowledge: discovered, land_seen, garrison_known, the siege's land level** | edit `core/views/knowledge.gd` (`discovered`, `land_seen`, `garrison_known` replacing `garrison_estimate`, `siege_access` with `land`, `witnessed` land rule, `men_of` exact, `armies_seen` `men`), and the call sites of the two renames only: `core/ai/ai_know.gd` (2 lines), `core/views/odds_view.gd` (2 lines), `study_military.gd`, `summary_armies.gd` (the key); edit `tests/core/test_knowledge.gd` | Spec R1, R19, R21, R24 to R26, R29: every case and P of spec 7 for `test_knowledge.gd`; `band` still present (FG17 deletes it); the views keep their old words until group C |

### Group C (after B, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| FG6 | M, Sonnet | **Land views** | edit `core/views/people_view.gd`, `hex_card.gd`, `improve_card_parts.gd`, `works_view.gd`, `cards_people.gd`, `cards_economy.gd`; edit `tests/core/test_people_view.gd`, `test_hex_card.gd`, `test_cards_economy.gd`, `test_improve_preview.gd`, `tests/shell/test_hex_panel_people.gd` | Spec R18 (land rows), D18, R19 in the fortress row, R21 in the siege block: an undiscovered hex reads "Unexplored" only (P: a place name shown); a light-fog hex shows people exact and the garrison exact |
| FG7 | M, Sonnet | **Country numbers** | edit `core/views/country_card.gd`, `study_rankings.gd`, `shell/panels/country_panel.gd`; edit `tests/core/test_country_card.gd`, `test_study_rankings.gd`, `test_rankings_armies.gd`, `tests/shell/test_country_panel.gd`, `test_page_rankings.gd` | Spec R26, R28, D9, D10: treasury and men exact; people and land from `land_seen` (P: an undiscovered hex counted, on the thin fixture); the "Land you have seen" line; north Italy shows every country known |
| FG8 | M, Sonnet | **The report** | edit `core/views/season_summary.gd`, `summary_doings.gd`, `summary_armies.gd`, `summary_people.gd`, `study_military.gd`; edit `tests/core/test_season_summary.gd`, `test_season_summary_people.gd`, `test_season_doings.gd`, `test_study_military.gd`, `test_standing_armies.gd`, `tests/fixtures/report_sample.gd` | Spec R31: exact men and standing numbers; "What befell" lists land events of every discovered hex (P: a land event on an undiscovered hex in the thin fixture's report) |
| FG9 | M, Sonnet | **War views** | edit `core/views/odds_view.gd`, `siege_view.gd`, `battle_view.gd`, `cards_war.gd`; edit `tests/core/test_odds_view.gd`, `test_odds_calibration.gd`, `test_siege_view.gd`, `test_battle_view.gd`, `test_cards_war.gd`, `tests/shell/test_odds_card.gd`, `test_hex_war.gd`, `test_battle_dock.gd` | Spec R19 to R22: the odds of a discovered fortress use the real garrison (P: the full garrison); a light-fog siege names no besieger (P); a seen battle shows exact men and no stance (P) |
| FG10 | M, Sonnet | **Armies and moves** | edit `core/views/army_view.gd`, `move_preview.gd`, `supply_view.gd`, `cards_military.gd`, `core/systems/movement.gd` (the reason words only); edit `tests/core/test_army_view.gd`, `test_move_preview.gd`, `test_movement.gd`, `test_cards_military.gd`, `tests/shell/test_army_panel.gd`, `test_army_flags.gd` | Spec R23, R25, R32: `visible` own or in sight (P: an army out of sight shown); a reason names a discovered owner, never an undiscovered one (P) |
| FG11 | M, Sonnet | **Log and history** | edit `core/views/log_lines.gd` (`_told`, exact men), `log_lines_war.gd`, `study_history.gd`; edit `tests/core/test_log_lines.gd`, `test_log_others.gd`, `test_log_lines_war.gd`, `test_study_history.gd`, `test_chronicle.gd`, `tests/shell/test_timeline_strip.gd` | Spec R29, R31, D19: `_told` equals `witnessed` for every kind and viewer on north Italy and the thin fixture (P: a land event told by the sight list) |
| FG12 | M, Sonnet | **The AI door and its fog test** | edit `core/ai/ai_know.gd` (R33, R34); edit `tests/core/test_ai_know.gd`, `test_ai_door.gd`; rewrite `tests/core/test_ai_fog.gd` (section 3) | Spec R33 to R35: one P per gated read on `FogFixture.duel_thin()`; the rewritten fog test green with its three new plants |
| FG13 | M, Sonnet | **The map's deep fog (core and overlay)** | edit `core/views/map_modes.gd` (`discovered_bytes`, the gates), `shell/map/mode_overlay.gd`, `mode_overlay.gdshader`, `shell/hud/minimap.gd`, `shell/map/map_scene.gd` (re-sends the bytes when `explored_revision` moves); edit `tests/core/test_map_modes.gd`, `tests/shell/test_mode_overlay.gd`, `test_minimap.gd` | Spec R36, D17: the fill on the thin fixture in every mode (P: an owner colour under deep fog); the veil unchanged; the art director signs a picture of the placeholder fill |
| FG14 | M, Sonnet | **The soak's fog invariants** | edit `tests/core/invariants.gd` (R2, R4, controlled hexes explored), `tests/core/test_invariants.gd`, `godot/tools/soak.gd` (`--plant=fog`, tests only) | Spec R2, R4: each invariant with its P; `soak --quick` green; `--plant=fog` prints its replay line and exits 1 |

### Group D (after C, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| FG15 | M, Sonnet (systems designer decides) | **The AI re-pinned on the soak** | edit `tests/core/test_ai_war.gd`, `test_ai_war_aims.gd`, `test_ai_owner.gd`, `test_ai_play.gd`, `test_ai_determinism.gd` (re-pins only, each with its reason); a data edit of `data/defs/ai.tres` or the tempers only if the designer asks, with `tests/core/test_ai_defs.gd` | Spec done-when 5: 100 `ai`, 20 `passive`, 4 `europe` soak games hold every range of M8 4.17; the tables and the designer's verdict in the pull request; a 12-season north Italy report read for log volume (spec 9) |
| FG16 | M, Sonnet | **Marks and labels** | edit `shell/map/map_people.gd`, `capital_marks.gd`, `work_marks.gd`, `map_wars.gd`, `war_marks.gd`, `shell/mapview/country_labels.gd`, `map_labels.gd`; edit `tests/shell/test_war_marks.gd`, `test_map_armies.gd`, `test_map_armies_gone.gd`, `test_floaters.gd` | Spec R37: nothing drawn on an undiscovered hex (P: a capital mark, a label); the light-fog siege dial without the besieger's colour (P) |

### Group E (after D, parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| FG17 | M, Sonnet | **The cross-view proofs; `band` deleted** | `tests/core/test_fog_views.gd`, `tests/core/test_fog_exact.gd` (new); edit `core/views/knowledge.gd` (delete `band`, `band_text`), `tests/core/test_knowledge.gd` (their cases go), `tests/core/test_war_save.gd` (round trip on the thin fixture and north Italy turn 8) | Spec done-when 2, 3, 6, R3, R18, R27, R38: every row of spec 3.4 on the thin fixture through every view of section 5; the scan finds no `band`; save, load, save byte-equal |
| FG18 | M, Haiku | **Monkey and perf rows** | `tests/shell/monkey_fog.gd` (new, extends `MonkeyM8`); edit `tests/shell/test_ui_monkey.gd` (the fog step, a thin seed), `godot/tools/perf_core.gd` (`discovered_bytes_ms`, `land_seen_ms`), `godot/tests/perf_core_budget.json`, `godot/tools/ui/perf_ui.gd` (only if a row moves) | Section 4: the monkey's fog invariant green on 3 seeds, one of them thin; spec 8's rows within limits against FG3's baseline, both tables in the pull request |
| FG19 | M, Haiku (art director signs) | **Pictures, goldens, player docs** | edit `godot/tools/ui/shot_ui.gd` (the fog scenes of spec 7), `tests/fixtures/ui_sample.gd`; the regenerated goldens of M4.5 to M8 that showed a band (`godot/tests/goldens/`); edit `README.md` (the player's fog rules), `godot/README.md`, `docs/design/two-fog-levels.md` (status line: built), `docs/architecture/godot-architecture.md` (the fog line of 9.x) | Spec 7's pictures at both scales signed; every changed golden reviewed and signed; README text matches spec 3.4 in plain words |

---

## 3. Tests to rewrite

The tests whose pinned words or numbers move, by owner task. Each keeps its planted faults.

- **Rewritten:** `test_ai_fog.gd` (FG12). Copy B now changes only what Milan may not know: unseen Venetian armies moved,
  re-ordered, given other standing orders; Venice's stores; the world's luck; and on `duel_thin` the owners, pieces,
  fortresses and garrisons of hexes Milan has not discovered. It stops changing discovered garrisons (now exact), Venice's
  treasury (now readable) and works on discovered hexes (land). New plants: a step that reads `Occupation.garrison_of` on an
  undiscovered fortress, a step that reads `Territory.owner_tag` straight, each giving other acts. The cases "a seen garrison
  inside its hundred" and "a seen garrison under fifty reads as none" are replaced by "a discovered garrison is read exactly"
  and "an undiscovered fortress gives no card".
- **Re-written cases:** `test_sight.gd` (`explored_start_equals_the_border_rule` becomes "the start equals land sight OR the
  regions"; `an_owner_change_explores_the_gain_at_the_vision_phase` becomes "at once"), `test_knowledge.gd` (the garrison
  estimate cases; `band` cases deleted in FG17), `test_study_rankings.gd` ("10 countries unknown" for Genoa becomes 0 on
  north Italy and a count on the thin fixture).
- **Words and numbers only:** the rest of the lists of FG6 to FG11, FG13, FG16; their shell twins; the goldens (FG19).
- **Re-pinned behaviour:** FG15's AI tests, each with a comment line "re-pinned for the fog build: <reason>".
- **Unchanged, must stay green:** `test_replay.gd`, `test_replay_plan.gd`, `test_replay_marks.gd`, `test_snapshot.gd`,
  `test_ai_turn.gd`, `test_ai_judge.gd`, every M2 to M7 rule test that does not read `Knowledge`.

---

## 4. Monkey and performance

**Monkey (FG18).** `MonkeyFog` adds one step and one invariant to M8's monkey. The step: on a thin seed (every fourth seed,
the player's explored thinned to radius 2 after the pick by `FogFixture.thin`), hover and open random hexes and the country
panels. The invariant, every frame the step runs: for a hex with `discovered` false, `HexCard.of` gives only "Unexplored",
`PeopleView.at` is empty, no token, mark or label is drawn there; for a foreign army with `sees` false, no token and no
`ArmyView` row. Counters `fog_hexes`, `fog_dark`, `fog_armies_hidden` must rise above 0 on the thin seed.

**Perf.** FG3 records the baseline of spec 8's rows before any rule moves; FG18 adds the two new rows and runs all rows
after. A row more than 5 % slower than the baseline, or past its limit, is fixed by spec 8's fallbacks in FG18's pull
request; `vision_ms` (issue 422) must not grow.

---

## 5. Reviews and the owner's playtest

- **The code reviewer** reads every task.
- **The technical director** signs spec sections 2, 3 and 6 before group A; reads FG4's and FG5's interfaces before they
  merge; reads FG12's fog test and FG14's invariants together; reads FG17's scan.
- **The systems designer** gives FG15's verdict on the soak tables and the log volume before group E.
- **The art director** signs FG13's placeholder fill and FG19's pictures and goldens.
- **The game designer** drafts the Europe map's region table (spec section 4) when the map track reaches it; not in this
  build.
- **Pull requests say what changes for the player:** FG1 and FG2 make M8 saves unloadable ("Made by an older test build");
  FG4 changes who sees occupied land; group C changes every "about" number to an exact one; FG15 changes what the other
  countries do (with the soak's tables).

**The owner's playtest** (Windows, fresh user folder):

1. New game, seed 1480, Italy 1480, play as Genoa. Click a Venetian town far from you: owner, people, works and
   "garrison N of M" exact; no Venetian army shown unless one of yours is near.
2. Open Venice's country panel: treasury and men under arms exact, "Land you have seen: N districts". Open Rankings: all 12
   other countries, exact numbers.
3. End 4 seasons: the log tells other countries' works anywhere on the map; armies raised far away are not told.
4. New game as Savoy, declare war on Milan, walk an army into a Milanese district two hexes deep and take it: at once the
   district shows Savoy as holder and the hexes around it are in sight (any Milanese army there is drawn).
5. Watch an AI war (F2 `watch` in a new game, `end 12`): a besieged castle out of sight shows "Besieged", the meter and the
   garrison, and no besieger; in sight it names the besieger and its men.
6. F5, quit, Continue: the same game. Try an M8 save: it is refused as an older test build.
7. Look at FG19's signed pictures of deep fog (deep fog shows on the north Italy map only in the thin test fixture; it
   comes into play with the Europe map).

---

## 6. Definition of done

1. The spec's done-when items 1 to 8 hold.
2. FG1 to FG19 merged; CI green with the nightly `soak`, `soak-ranges`, `perf_core` and `perf_ui` jobs within limits.
3. Issues 446 and 435 closed by the pull requests that finish them (FG17 and FG4).
4. The owner has played section 5.

---

## 7. Risks

| Risk | Where it shows | Answer |
|---|---|---|
| Group C is wide (9 tasks) and touches many tests | merge order, a shared helper edited twice | one owner per shared fixture (section 1); a task that needs another's helper asks the planner, never edits it |
| Exact numbers change the AI's choices | FG15's soak | the systems designer may change data, never code, in FG15 |
| The log grows on north Italy | FG8, FG11, FG15 | M8's caps; a data edit of the cap if the designer asks |
| Many goldens move at once | FG19 | each changed golden reviewed side by side; only band words and fog may differ |
| A test written against the north Italy map cannot see deep fog | every group | every deep-fog case runs on the thin fixture; a review rejects a deep-fog case without it |
| U1 (tile window) built in parallel | `hex_card.gd`, `hex_panel.gd` | not in parallel: fog first (recommended) or FG6 folded into U1 |
| The Europe map's history data is late or argued | the Europe scenario | `validate` refuses a missing country, so the scenario cannot ship without the approved table |
