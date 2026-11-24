# Fog build spec: two fog levels (issues 446 and 435)

Technical director, 2026-11-24. **Status: a proposal; no task starts before the owner's go.** Builds the design
`docs/design/two-fog-levels.md` ("the design") **as the owner answered it** in its last section (2026-11-24). Where the
design's sections 3 to 8 recommend something else, the owner's answers win, and this page wins over both for the build. The
tasks are in `fog-build-plan.md`. Appendix A lists every place in the M3 to M8 specs that this page amends; those specs are
not edited.

**What it is, in one paragraph.** Every country, the AI included, sees the world in three states. **Deep fog**: a hex the
country has never discovered; nothing of it is shown. **Light fog**: a discovered hex not in sight now; all of its land is
shown live and exact (owner, holder, people, goods, buildings, works, the fortress and its garrison, a siege's meter); only
armies, their marches and orders, and battles you did not witness are hidden. **In sight**: the armies there are shown too.
Every number shown is exact: the old "about 1,200" bands are gone. A country starts knowing what it historically knew
(on the north Italy map: the whole map, for every country). A conqueror sees the land it holds at once; the old owner keeps
it in light fog.

**The fog build is done when:**

1. Every rule R1 to R40 below holds, each with its GUT case and its planted fault (P) of section 7.
2. On "Italy, 1480" every country starts with every hex discovered; on a fixture with a thin start (section 7, `FogFixture`)
   no view, no log line, no map layer and no `AiKnow` read gives a land fact of an undiscovered hex, or an army fact of a
   hex out of sight (`test_fog_views.gd`, the monkey's fog invariant).
3. No `Knowledge.band` or `band_text` call is left in `core/` or `shell/` (`test_fog_exact.gd`).
4. An occupier sees and has discovered a captured hex in the same phase; the old owner does not see it unless other sight
   reaches it (`test_sight.gd`).
5. `test_ai_fog.gd` rewritten (section 7) is green with its new plants; the AI tests re-pinned with a written reason each;
   the soak's 100 `ai`, 20 `passive`, 4 `europe` games hold every range of M8 4.17, read by the systems designer.
6. `SaveFile.FORMAT` is 7; a format-6 file reads "older"; save, load, save is byte-equal.
7. `perf_core` and `perf_ui` rows within their limits (section 8); no new row over budget.
8. Lint, import, check_scripts, GUT, both UI `--check`s, `build_map --check`, `build_scenario.gd --check` green; the
   pictures of section 7 signed by the art director; the owner has played the plan's checklist.

---

## 1. What is there (read in the code, master after M8)

| Finding | Where | Meaning for the build |
|---|---|---|
| `Country.explored` is a saved bitset, in the digest; written by `Sight.setup`, `see_path`, `season` only | `core/systems/sight.gd` | It is the discovery set; two writers join (R11) |
| `Sight.setup` sets explored to the land sight (own hexes and one ring) | `sight.gd` 18 | Replaced by R6 (historical start) |
| `Sight.sees`, `witnesses_of`, `SightCache.land_of` read the **owner** byte | `sight.gd` 61, 80; `sight_cache.gd` 31 | Replaced by the **controller** (R13): owner unless `state.occupier` is set |
| `Knowledge.garrison_estimate`: own exact, seen rounded to 100, unseen "assumed" full | `core/views/knowledge.gd` 80 | Replaced by `garrison_known` (R19) |
| `Knowledge.men_of`, `armies_seen`, and 30 view lines call `band` / `band_text` | grep of `core/`, `shell/` | All exact (R24 to R27) |
| `Knowledge.witnessed`: party, witness list, or public-and-known | `knowledge.gd` 132; mirrored by `LogLines` `_told` | Gains the land rule (R29) |
| `Knowledge.siege_access`: exact, seen, hidden | `knowledge.gd` 160 | Gains `land` (R21) |
| `AiKnow` reads owners, occupiers, fortresses, land of any country over the whole map | `core/ai/ai_know.gd` 304 to 374 | Gated by discovery (R33) |
| `ScenarioDef` has no region data; `MapData` has none | `core/defs/` | New scenario fields (R5) |
| `SaveFile.FORMAT` 6, `OLDEST_FORMAT` 6, no upgrade step | `core/game/save_file.gd` | FORMAT 7 (R38) |
| The map has a light "sight veil" (`map/sight_veil`, M6 D34) and no deep-fog layer | `map_modes.gd`, `mode_overlay.gd`, `minimap.gd` | Deep fog added (R36); the veil stays as light fog |
| `vision_ms` (20 ms) is already over budget, issue 422 | `tests/perf_core_budget.json` | The build must not make it worse (section 8) |
| The tile window `TileView` (ui-family-audit U1) is not built; the hex card is the tile panel | `core/views/hex_card.gd` | The build edits the hex card; U1 calls the same `Knowledge` functions |

---

## 2. Decisions taken

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | One test for "discovered" | `Knowledge.discovered(game, viewer, hex)`: viewer `""`, or the explored bit, or `sees` now | One function for player, views and AI; sight that has not yet reached the explored bits still counts |
| D2 | Start data shape | By **region**: `ScenarioDef.regions` (names), `ScenarioDef.region` (one byte a hex), `ScenarioDef.discovery` (per country the regions it knows) | The owner's "hand-made list per country, by region, as data" |
| D3 | North Italy 1480 | One region `europe` holding every hex; all 13 countries (France, Austria and the Papal States too) know it | Every country on the map is European; the owner: "a European country knows the whole of Europe" |
| D4 | Land sight comes from | **Control**: the hexes a country controls (owns and nobody occupies, or occupies) and their ring | Owner answer 5: the conqueror sees held land, the old owner keeps light fog |
| D5 | Discovery after conquest | Set **at once**, in the event that changes control or ownership (capture, cession, release) | A captured town must never read "Unexplored" |
| D6 | Garrisons | Land: **exact** on any discovered fortress; hidden on an undiscovered one; no "assumed" value | Owner answer 2 |
| D7 | Numbers | **Exact everywhere**: `Knowledge.band` and `band_text` are deleted. Read as covering a seen army's men and a witnessed battle's men and morale | Owner answer 3 ("exact everywhere") |
| D8 | What stays hidden in sight | A foreign army's orders, route, standing order and stance stay hidden even in sight (today's rule) | Not asked to change; orders are intentions, not visible things |
| D9 | Country totals | For a known country: treasury, income and men under arms exact, whole country. Land sums (districts, people) are over the hexes the viewer has discovered | Owner answer 3 names "the sums of a country's discovered land"; on north Italy both are the whole |
| D10 | A partly discovered country's panel | The same card, plus "Land you have seen: N districts" for every foreign country, never its total | The owner's default for the open question; no total, so no leak |
| D11 | A siege in light fog | Holder, meter (progress and need) and garrison shown; the besieger unnamed ("Besieged"), its men and the forecast hidden | Owner answer 6; the besieger is an army |
| D12 | Land events | `work_started`, `work_finished`, `work_cancelled`, `town_grew`, `district_declined`, `district_captured` carry `land: true` and no sight list; told at **read time** to the parties and to any viewer that has discovered the hex | A stored list of 60 discoverers per entry would weigh about 3.6 MB in a full chronicle on Europe |
| D13 | Siege and army events | `siege_*`, `army_*`, `unit_lost`, `battle_*`, `unit_moved`, `march_halted` keep sight witnesses | They tell what an army did |
| D14 | The AI | `AiKnow` reads another country's land only on hexes its seat has discovered (D1); nothing else changes in the door | Owner answer 4 |
| D15 | Check refusals | A reason may name a discovered hex's land facts; never an undiscovered hex's owner or fortress; never an army or march out of sight | A check is public to whoever asks (M8 4.3, last row) |
| D16 | Saves | `FORMAT` **7**, `OLDEST_FORMAT` 7; a format-6 save is refused quietly ("Made by an older test build") | The start discovery and the land witness rule change what a saved game means, and the scenario digest changes anyway; no Godot save has reached players |
| D17 | The map | Undiscovered hexes: one flat deep-fog fill (placeholder; the final art comes with the map track); the sight veil stays as the light-fog marker; owner colours, labels, marks, people, overlays and the minimap leave undiscovered hexes blank | The north Italy map has no undiscovered hex in play, so the art is not on the critical path |
| D18 | An undiscovered hex's card | Title "Unexplored", nothing else: no ground, no place name, no owner | Deep fog shows nothing |
| D19 | Late discovery and old land events | A country that discovers a hex later is told the older land events there (History) | Consequence of D12, accepted: you learn a land's past when you reach it |
| D20 | Task IDs | `FG1`, `FG2`, ... | K is taken by M1.5 and M8, F by the UI controls spec |

---

## 3. The rules

Numbered statements. "P" names the planted fault the test must catch. The viewer `""` (the sandbox) sees everything; no
rule below applies to it.

### 3.1 The three states

- **R1** A hex is **undiscovered** by country `t` when `Knowledge.discovered(t, hex)` is false; **discovered, not in sight**
  when it is true and `Knowledge.sees(t, hex)` is false; **in sight** when `sees` is true. Cases: own hex (in sight), the
  ring of own land (in sight), a hex in a known region far away (light fog), a hex outside every known region never walked
  (deep fog). P: `discovered` that reads only the explored bit fails the case "an army's new ring before the vision phase".
- **R2** `sees` implies `discovered` for every country and hex at every moment (an invariant of the soak and the monkey).
  P: a `discovered` without the sight clause breaks it after a retreat.
- **R3** The states are the same function for the player, every view and every AI seat. P: a view with its own fog test is
  found by `test_fog_views.gd`'s scan of the views listed in section 5.
- **R4** Discovery is never lost: no writer clears an explored bit (soak invariant: explored after a season is a superset of
  explored before). P: a writer that assigns instead of ORs.

### 3.2 The discovery set and how it grows

- **R5** `ScenarioDef` gains `regions: Array[StringName]` (index 0 is the first region; byte value `k + 1` in `region` means
  `regions[k]`, 0 means no region), `region: PackedByteArray` (one byte a hex) and `discovery: Array[Dictionary]`
  (`{tag, regions: Array[StringName]}`). `validate`: `region` has the map's hex count or is empty; every byte at most
  `regions.size()`; when `regions` is empty, `discovery` is empty; else every country of `countries` has exactly one entry,
  every name is in `regions`, no name twice. `digest` covers all three. P each: wrong size, byte out of range, a missing
  country, an unknown name, a duplicate.
- **R6** At game start (`Sight.setup`, called by `new_scenario` only) each country's explored = its land sight (R13) OR every
  hex whose region is in its discovery entry. Cases: north Italy, all 13 countries, every hex set; a fixture with
  `discovery = []` for one country, only its land sight. P: setup that ignores `discovery`; setup that forgets the land sight.
- **R7** A scenario with no regions (the made-up Europe of `FakeScenario`, map-only games) starts with the land sight only,
  as today. P: a fake game whose explored is the whole map.
- **R8** Growth, as today: the vision phase adds each country's land sight and its armies' sight; the movement phase adds each
  walk's steps and their rings (`see_path`).
- **R9** Growth, new: a `district_captured` event marks the hex and its ring (land sight) for the event's `tag` before the
  event is queued. Cases: walk-in, siege, storm, retaken. P: the mark left to the next vision phase.
- **R10** Growth, new: an `owners_changed` event marks each of its `hexes` and their ring for the new owner `tag`; a
  `controllers_changed` event (release at peace) marks the hexes for each new controller. P: a cession seen as "Unexplored"
  until the next season.
- **R11** `explored` has exactly five writers: `setup`, `see_path`, `season`, and `Sight.on_emit` for R9 and R10 (through one
  private `_mark`). `test_no_other_writers.gd` pins the list. P: a sixth writer in a view.
- **R12** Discovery sets the "known" set (`SightCache.known_of`) as today: a viewer knows a country once it has discovered one
  hex the country holds. On north Italy every country knows every other from the first season. P: a known set not dropped
  after R9 marks a new owner's hex.

### 3.3 Sight and conquest

- **R13** Land sight = the hexes `t` **controls** and every hex within `land_sight` (1) of them. Control is
  `Occupation.controller_id`: the occupier when `state.occupier` is set, else the owner. `Sight.sees`, `witnesses_of` and
  `SightCache.land_of` read control. P: any of the three reading the owner byte (the cases of R14 and R15 fail).
- **R14** The conqueror sees a hex it occupies, and its ring, from the moment of capture. Case: Milan occupies a Venetian
  district three hexes inside Venice: `sees(MLO, hex)` and its ring true in the same phase, `HexCard` shows Milan as holder.
- **R15** The old owner of an occupied hex keeps it in light fog: `discovered` true, `sees` false unless another controlled
  hex's ring or an army reaches it. Case: the same hex for Venice with no Venetian army near: the card shows the holder,
  people and garrison 0; no Milanese army. P: an old owner that still sees the hex.
- **R16** `SightCache.land_of` is dropped for every country named by `controllers_changed` (as by `owners_changed`). P: a
  stale cache keeps the old owner's sight bytes for the map's veil.
- **R17** Peace (`release`, cession) follows R10 and R13 at once; nothing waits for the vision phase.

### 3.4 What each state shows

| Fact | Undiscovered | Discovered, not in sight | In sight |
|---|---|---|---|
| Ground, place name, owner, holder, colour on the map | hidden | shown | shown |
| People, goods, buildings, works under way, town size | hidden | shown, exact, live | shown, exact, live |
| Fortress, its level, its garrison | hidden | shown, exact | shown, exact |
| A siege: holder, meter, garrison | hidden | shown; besieger unnamed | shown; besieger named, its men exact |
| A siege's forecast ("falls in N seasons") | sides only | sides only | sides only |
| Foreign armies, their men | hidden | hidden | shown, men exact |
| Foreign armies' orders, routes, standing orders | hidden | hidden | hidden |
| A battle record | hidden | hidden unless a side or witness | as witnessed (exact numbers) |
| A walk in the replay | not played | not played | played |

- **R18** Every view in section 5 follows this table through `Knowledge` (R1). P: one case per row in `test_fog_views.gd`.
- **R19** `Knowledge.garrison_known(game, viewer, hex) -> {men, access}` replaces `garrison_estimate`: `exact` with the real
  garrison on a discovered fortress (own, other, occupied by a third); `hidden`, men -1, on an undiscovered one; `none`, men
  0, with no fortress. `assumed` is gone. P: a hidden fortress that reports the full garrison.
- **R20** `Sieges.forecast_for` keeps its signature; `OddsView` and `AiKnow` pass `garrison_known` (now the real men).
- **R21** `Knowledge.siege_access` returns `exact` (viewer `""`, besieger, holder), `seen` (in sight), `land` (discovered,
  not in sight), `hidden` (undiscovered, or no siege, or the two not at war). `SiegeView` at `land`: holder, progress, need,
  garrison, the word "Besieged"; no besieger tag, no men, no rate, no forecast. P: a `land` view that names the besieger.
- **R22** `BattleView` at `seen`: exact men, killed, wounded and morale; no stances, no standing orders, no army ids. P: a
  seen view that shows a stance.
- **R23** `ArmyView.visible(viewer, army)` = own, or `sees(viewer, army.hex)`. The `knows` clause goes (sight implies
  discovery implies known). P: an army out of sight shown because its country is known.

### 3.5 Exact numbers

- **R24** `Knowledge.men_of(viewer, other)`: exact men under arms of the last closed season for a known country; -1 for an
  unknown one. P: a banded value.
- **R25** `Knowledge.armies_seen` entries are `{army, tag, hex, men}` with exact men (the key `men_banded` is renamed `men`).
- **R26** Country-level totals of a known country are exact (D9): treasury, income, men under arms. Land sums are
  `Knowledge.land_seen(game, viewer, other) -> {districts, people}` over the hexes the viewer has discovered, cached per
  `game.version` in `view_cache`; when the viewer has discovered every hex of `other` it equals `Stats`. P: a sum that counts
  an undiscovered hex.
- **R27** `Knowledge.band` and `band_text` are deleted with their last caller. `test_fog_exact.gd` scans `core/` and
  `shell/` for the two names and for the text "about " built in a view. P: a file that keeps one call.
- **R28** The country card of a foreign known country shows "Land you have seen: N districts" (N = `land_seen.districts`).
  An unknown country has no card, as today.

### 3.6 Witnesses, the log, the report

- **R29** `Knowledge.witnessed(event, viewer)`: true for `""`, the actor, `others`; for an event with `land: true`, true when
  `discovered(viewer, event.hex)`; else the witness list; else public-and-known (today). `LogLines`' fast `_told` path gives
  the same answer for every entry and viewer (the pinned equality). P: a land event told by the sight list; a land event on
  an undiscovered hex told.
- **R30** `Sight.on_emit` sets `land: true` on the six land kinds (D12) and gives them no sight list; the other sighted kinds
  keep `witnesses_of` (now by control, R13). The actor and `others` always witness. P: a land kind with a sight list.
- **R31** Log lines, "What befell", History and the timeline name men exactly ("raised 1,000 men"). An unknown actor stays
  unnamed (today). On north Italy every land event of every country is told to every country; the caps of M8 D38 and D39
  (one line a country, `OTHERS_PER_SEASON`, `NOTIFY_RANGE`) bound the log.
- **R32** A check's refusal follows D15: `MovePreview._foreign_reason` and `Movement`'s reasons name a hex's owner or
  fortress only when `discovered`; an army or march only when `sees` (today's `_fog_safe`). P: an undiscovered owner named.

### 3.7 The AI

- **R33** Every `AiKnow` read of another country's land returns only discovered hexes: `owner_of`, `controller_of`,
  `area_state`, `use_at`, `fortress_level`, `is_port` give "nothing" (`&""`, 0, `&"unknown"`, `(0, 0)`, false) on an
  undiscovered hex; `fortresses_of`, `land_of`, `controlled`, `land_field` of another country leave undiscovered hexes out;
  `capital_of(other)` is `Army.NO_HEX` when undiscovered. Own reads are unchanged. P: each read, on a thin fixture.
- **R34** `AiKnow.men_of` and `seen_enemies` are exact (R24, R25); `garrison_estimate` becomes `garrison_known` (R19).
- **R35** The door rule stays: `test_ai_door.gd` keeps its scan; `Sight.` and `Knowledge.discovered` are read only in
  `ai_know.gd`. P: an `ai_war.gd` line that calls `Sight.explored`.

### 3.8 The map

- **R36** `MapModes.discovered_bytes(game, viewer)`: one byte a hex, 1 discovered; cached by `[&"discovered", viewer,
  SightCache.explored_revision(viewer), game.sight.revision()]`. The mode overlay draws byte 0 as the deep-fog fill in every
  mode; owner colours, the occupier stripes, area tints, food, yield and supply values are not drawn there. P: an owner
  colour under deep fog.
- **R37** Map marks and labels (`CountryLabels`, `MapLabels` place names, `CapitalMarks`, `WorkMarks`, `MapPeople`, war marks
  and the siege dial) skip undiscovered hexes; the siege dial shows on a discovered hex in light fog without the besieger's
  colour (R21); army tokens and replay walks keep the sight rule. The minimap shows the deep-fog fill and no owners there.

### 3.9 Saves, replay, digest

- **R38** `SaveFile.FORMAT` 7, `OLDEST_FORMAT` 7. Body unchanged in shape (`country/4`'s `explored` as before; chronicle
  entries may carry `land`). A format-6 header reads `older`. Save, load, save is byte-equal on the thin fixture and on north
  Italy at turn 8. P: a format-6 file that loads.
- **R39** `Game.digest()` is unchanged in form; it differs from M8's for the same seed because explored and the chronicle
  differ. No test pins a digest value. The replay of an action log gives the same digest (`test_replay.gd`,
  `test_ai_determinism.gd` unchanged).
- **R40** `Snapshot.restore` refuses an explored of the wrong size (today) and nothing more; R2 and R4 are checked by the soak
  and `Invariants`, not on load.

---

## 4. The start data

**North Italy 1480 (built now).** `regions = [&"europe"]`; `region` = 1 on every hex (land and sea); `discovery` one entry a
country, `{tag, regions: [&"europe"]}`, for FRA, AUS, SWI, SAV, MLO, VEN, GEN, TUS, PAP, MAN, FER, SIE, LUC (the
scenario's `countries` order). `godot/tools/build_scenario.gd` writes `region` from a region source (north Italy: "every hex is
`europe`") and keeps `regions` and `discovery` when it regrows `owner`; `--check` compares them. `data/README.md` says so.

**The Europe map (later, the map track; not built here).** The rule is the same; only the data is large.
1. **Regions** are lon/lat polygons kept beside the map's sources and rasterised onto the hex grid by the map tools as land
   is (each hex takes the region holding its centre). A first cut, to be checked by the game designer:

| Region | Covers |
|---|---|
| `europe` | Europe to the Urals, Iceland, the Mediterranean and Black Sea islands |
| `maghreb` | North Africa from Morocco to Tripoli |
| `egypt_levant` | Egypt, the Levant, the Red Sea coast |
| `anatolia_caucasus` | Anatolia, the Caucasus, the Caspian shore |
| `atlantic_isles` | Madeira, the Azores, the Canaries, Cape Verde |
| `guinea_coast` | the West African coast to the Gulf of Guinea |
| `sahel` | the trade towns south of the Sahara |
| `arabia_persia` | Arabia, Mesopotamia, Persia |
| beyond (Americas, the far south of Africa, the Indian Ocean coasts) | known to nobody in 1480 |

2. **Per country**, one row: its regions and a short source note. A draft of four rows shows the form: Portugal `europe,
   maghreb, atlantic_isles, guinea_coast` (its voyages to the Gulf of Guinea by the 1470s); Castile `europe, maghreb,
   atlantic_isles`; Venice `europe, maghreb, egypt_levant, anatolia_caucasus` (its trade posts); the Ottomans `europe,
   anatolia_caucasus, egypt_levant, arabia_persia`. Sources for the table: the Fra Mauro world map (1459), the printed
   editions of Ptolemy's Geography (1477 on), portolan charts, and the record of each country's voyages and trade to 1480.
3. The game designer drafts the full table, the creative director reviews it, **the owner approves it** before the Europe
   scenario ships. A country missing from the table fails `validate` (R5), so it cannot be forgotten.

---

## 5. The views

Every view that applies the fog, and what changes. Paths under `godot/`.

| File | Change |
|---|---|
| `core/views/knowledge.gd` | `discovered`, `land_seen`, `garrison_known`; `siege_access` `land`; `witnessed` land rule; `men_of`, `armies_seen` exact; `band`, `band_text` deleted (last) |
| `core/systems/sight.gd`, `sight_cache.gd` | R6, R9 to R11, R13, R16, R30; `explored_revision(viewer)` |
| `core/views/people_view.gd` | `at` gated by `discovered`, exact; no `knows` gate |
| `core/views/hex_card.gd` | "Unexplored" (D18); fortress row exact ("garrison 800 of 800"); siege block by R21 |
| `core/views/improve_card_parts.gd`, `works_view.gd`, `cards_people.gd`, `cards_economy.gd` | a foreign hex's facts by `discovered`; exact |
| `core/views/country_card.gd`, `shell/panels/country_panel.gd` | treasury, men exact; people from `land_seen`; the "Land you have seen" line (R28) |
| `core/views/study_rankings.gd` | exact; land and people from `land_seen`; `unknown_count` unchanged in form |
| `core/views/season_summary.gd`, `summary_doings.gd`, `summary_armies.gd`, `summary_people.gd`, `study_military.gd` | exact men and standing numbers |
| `core/views/odds_view.gd` | garrison from `garrison_known`; a field defender needs `sees`; exact men |
| `core/views/siege_view.gd` | R21's four levels; exact texts |
| `core/views/battle_view.gd` | R22 |
| `core/views/army_view.gd` | R23; exact men |
| `core/views/move_preview.gd`, `supply_view.gd`, `core/systems/movement.gd` | R32; exact numbers |
| `core/views/log_lines.gd`, `log_lines_war.gd`, `study_history.gd` | R29 in `_told`; exact men |
| `core/views/map_modes.gd` | `discovered_bytes`; colour and values gated (R36) |
| `core/ai/ai_know.gd` | R33, R34 |
| `shell/map/mode_overlay.gd` (+ shader), `shell/hud/minimap.gd` | the deep-fog fill (R36, R37) |
| `shell/map/map_people.gd`, `capital_marks.gd`, `work_marks.gd`, `map_wars.gd`, `war_marks.gd`; `shell/mapview/country_labels.gd`, `map_labels.gd` | skip undiscovered (R37) |
| `shell/hud/odds_card.gd`, `hex_menu.gd`, `map_hover.gd`; `shell/panels/hex_panel.gd`, `hex_war.gd`, `army_panel.gd`, `army_war.gd`; `shell/screens/battle_dock.gd` | draw the views' text; no rule of their own; their tests' words change |
| `core/systems/battle_end.gd`, `movement_phase.gd` | unchanged code; their witnesses follow R13 |

---

## 6. Interfaces

```gdscript
# core/defs/scenario_def.gd (edit)
@export var regions: Array[StringName] = []
@export var region: PackedByteArray = PackedByteArray()
@export var discovery: Array[Dictionary] = []          # {tag: StringName, regions: Array[StringName]}
func discovery_of(tag: StringName) -> PackedByteArray  # the start set of a country as an explored bitset (R6)

# core/systems/sight.gd (edit)
const LAND_KINDS: Array[String] = ["work_started", "work_finished", "work_cancelled", "town_grew", "district_declined",
	"district_captured"]
static func setup(game: Game) -> void                  # R6
static func sees(game: Game, tag: StringName, hex: Vector2i) -> bool   # R13: by control
static func on_emit(game: Game, event: Dictionary) -> void   # + R9, R10, R16, R30

# core/systems/sight_cache.gd (edit)
func explored_revision(tag_id: int) -> int             # grows when the country's explored grows

# core/views/knowledge.gd (edit)
static func discovered(game: Game, viewer: StringName, hex: Vector2i) -> bool
static func land_seen(game: Game, viewer: StringName, other: StringName) -> Dictionary   # {districts, people}
static func garrison_known(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary  # {men, access}
static func siege_access(game: Game, viewer: StringName, hex: Vector2i) -> StringName    # exact, seen, land, hidden

# core/views/map_modes.gd (edit)
static func discovered_bytes(game: Game, viewer: StringName) -> PackedByteArray
```

`AiKnow.garrison_estimate` is renamed `garrison_known`; its callers in `core/ai/` change with it.

---

## 7. Tests

All under `godot/tests/core` unless marked. A **thin fixture** is `tests/core/fog_fixture.gd` (new): `FogFixture.thin(g, tag,
radius)` sets a country's explored to its land sight grown by `radius`, then refreshes the sight (state edits in a test are
allowed, as `WarFixture` does); `FogFixture.duel_thin()` is `AiFixture.duel()` with Milan thin at radius 2.

| Test | Cases | Planted faults |
|---|---|---|
| `test_scenario_defs.gd` (edit) | north Italy: 13 entries, `europe` on every hex; `discovery_of` equals all bits | the five of R5 |
| `test_fake_scenario.gd` (edit) | no regions, no discovery | R7 |
| `test_sight.gd` (edit) | R6 both cases; R9 four `by` kinds; R10 cession and release; R13 to R16 cases; R30; `witnesses_agree_with_sees` by control | each of R6, R9, R10, R13, R15, R16, R30 |
| `test_no_other_writers.gd`, `test_owns.gd` (edit) | `explored`'s five writers | R11 |
| `test_knowledge.gd` (edit) | `discovered` three states; `land_seen` partial and whole; `garrison_known` four accesses; `siege_access` four levels; `witnessed` land rule; `men_of` exact | R1, R19, R21, R24, R26, R29 |
| `test_fog_views.gd` (**new**) | on the thin fixture, for each view of section 5: an undiscovered hex gives no land fact; a light-fog hex gives every land fact and no army; in sight gives the army | one per table row of 3.4, and the scan of R3 |
| `test_fog_exact.gd` (**new**) | no `band`, `band_text`, built "about " in `core/`, `shell/` | R27 |
| `test_people_view.gd`, `test_hex_card.gd`, `test_country_card.gd`, `test_study_rankings.gd`, `test_odds_view.gd`, `test_siege_view.gd`, `test_battle_view.gd`, `test_army_view.gd`, `test_move_preview.gd`, `test_log_lines.gd`, `test_log_others.gd`, `test_log_lines_war.gd`, `test_study_history.gd`, `test_season_summary*.gd`, `test_season_doings.gd`, `test_study_military.gd`, `test_summary_war*.gd`, `test_cards_*.gd`, `test_map_modes.gd` (edit) | the new words, exact numbers; "10 countries unknown" becomes "0" on north Italy and a count on the thin fixture | the rule each file's view applies |
| `test_ai_know.gd` (edit) | each read of R33 on the thin fixture | one per read |
| `test_ai_door.gd` (edit) | the scan gains `Sight.` and `Knowledge.discovered` | R35 |
| `test_ai_fog.gd` (**rewritten**) | copy B changes only what Milan may not know **now**: unseen Venetian armies moved and re-ordered, stores, standing orders, the world's luck, and, on the thin fixture, owners, pieces, fortresses and garrisons of undiscovered hexes. It no longer changes discovered garrisons, Venice's treasury or works on discovered hexes (Milan may read them). Each `AiKnow` read compared on both copies | a leak per read; a step reading `Occupation.garrison_of` on an undiscovered hex gives other acts; a step reading `Territory.owner_tag` straight |
| `test_ai_war.gd`, `test_ai_war_aims.gd`, `test_ai_owner.gd`, `test_ai_play.gd`, `test_ai_determinism.gd` | re-pinned where exact men and garrisons move a choice; each re-pin with its reason in the test's comment | as today |
| `test_save_file.gd`, `test_war_save.gd` (edit) | FORMAT 7; round trip on the thin fixture and north Italy turn 8 | R38 |
| `test_invariants.gd` (edit) | R2, R4, "every controlled hex is explored by its controller" | each, with `--plant=fog` in the soak (clears a bit mid-game, tests only) |
| shell: `test_minimap.gd`, `test_mode_overlay.gd`, `test_war_marks.gd`, `test_map_armies.gd`, `test_country_panel.gd`, `test_hex_war.gd`, `test_odds_card.gd`, `test_page_rankings.gd`, `test_battle_dock.gd`, `test_army_panel.gd` (edit) | deep-fog fill on the thin fixture; exact words | R36, R37 |

**Pictures** (1280 x 720 scale 1 and 2560 x 1440 scale 2, signed by the art director): the thin fixture's map (deep fog,
light fog with the veil, in sight); the hex card in each state; a light-fog siege; the country card with "Land you have
seen"; Rankings with exact numbers. Goldens of M4.5 to M8 that show a band are made again and signed.

---

## 8. Performance

Measure before the first task and after the last, in the same run setup, and put both numbers in the pull request.

| Row | Today's limit | Expected | Note |
|---|---|---|---|
| `vision_ms` | 20 (known over, issue 422) | unchanged within 5 % | control reads `state.occupier` beside the owner: one byte more per disc hex |
| `season_ms`, `army_phases_ms`, AI season rows (M8 8.1) | as today | unchanged within 5 % | land events lose their witness walk (cheaper) |
| `history_index_ms`, `study_history_ms`, `study_rankings_ms`, `summary_ms` | as today | within their limits | one explored bit per land entry; `land_seen` cached |
| **new** `discovered_bytes_ms` | 4 | about 1 | one viewer on the made-up Europe, cache cold |
| **new** `land_seen_ms` | 10 | under 5 | 60 viewers x 60 countries on the made-up Europe, cold |
| `perf_ui` frame rows | 16 ms | unchanged | the deep-fog fill is one more value in the overlay's existing texture |

A row past its limit takes the fallback before merge: `land_seen` counts from a per-country discovered-count kept in
`SightCache` (updated in `_mark`), `discovered_bytes` built from the bitset by byte, not by hex.

---

## 9. Risks

- **The log fills on north Italy.** Every country now hears every land event. M8's caps bound it; the systems designer reads
  a 12-season report in FG13 and may lower `OTHERS_PER_SEASON` (a data edit).
- **The AI changes with exact numbers.** Exact men and garrisons move thresholds a little; re-pins must state why. The soak's
  ranges are the safety net.
- **Clairvoyance.** Live land in light fog shows a rival's new castle without scouting: the owner's choice.
- **Deep fog is invisible in play on north Italy.** It is proved by the thin fixture, the monkey's thin seed and the pictures;
  the first real use is the Europe map.
- **Many tests move at once.** Every edited test keeps its planted faults; a task may not delete a P without replacing it.

---

## Appendix A. Amendments to earlier specs

These sections are amended by this page; the old pages stay as written and point nowhere new.

| Spec | Section | Amendment |
|---|---|---|
| m3-build-spec.md | D26, 4.7 (`Knowledge`: `knows`, `band`, `witnessed`) | `discovered` added; `band` deleted (R27); `witnessed` gains the land rule (R29) |
| m3-build-spec.md | 4.9 report sections | numbers of others exact (R31) |
| m4-build-spec.md | 4.16 / 6.2 works card `lands` line; the Standing line; the country card row "Treasury about 1,500" | exact; another country's hex named by `discovered` |
| m4-5-build-spec.md | done-when 3, D10, D13, 4.9 table, the `StudyRankings` and `StudyHistory` interfaces | exact values; land and people from `land_seen`; History by R29 |
| m5-build-spec.md | D32, 4.x "What you may know of others" table, `PeopleView` interface | people on discovered hexes, exact (R18) |
| m6-build-spec.md | D31 (vision by owner), D32, D33, D34, 4.11, 5.0 R4 ("three writers"), the "What you may know" table, `ArmyView` | control (R13); five writers (R11); land kinds (R30); exact men (R25); deep-fog layer (R36); `visible` (R23) |
| m7-build-spec.md | 4.14 witnesses, 4.15 fog table (battle "rounded", garrison "a garrison", siege), the hex card fortress row "banded for others", `SiegeView` | R19, R21, R22; exact |
| m8-build-spec.md | D7, D49, 4.3 the fog table (rows "public everywhere", "banded", "assumed full", "never works"), 4.5 `threats` and `seen` (banded), `AiKnow` interface (`men_of`, `garrison_estimate`), 9 `test_ai_fog.gd` | R24, R33, R34; the fog test of section 7 |
| ui-family-audit.md | 3.3 the tile window's "Explored, not in sight" row | the table of 3.4; `TileView` calls `Knowledge` only |

**Later specs (not built yet), to be re-read by their authors:** m9-build-spec.md 4.17 (infamy "banded": exact), m11-build-spec.md
4.13 (`know_range` adds known countries; discovery still gates land facts), m12-build-spec.md D31 (rankings "banded": exact).
