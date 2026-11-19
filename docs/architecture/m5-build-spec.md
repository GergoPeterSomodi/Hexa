# M5 build spec: People

Game and systems designer (Opus), 2026-11-17. **Status: a proposal, design only; it waits for the owner's go.** Builds
milestone M5 of `docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`), the
M1.5 UI foundation (`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`), and the M2, M3, M4 and M4.5 specs and plans
(`m2-build-*.md`, `m3-build-*.md`, `m4-build-*.md`, `m4-5-build-*.md`). Where this page is more exact it wins for M5;
section 1.2 lists every place where it refines an earlier page. The tasks are in `m5-build-plan.md`. This page carries the
M5 row of `ui-style-and-feedback-plan.md` S5 (the People page, people in Rankings, the People section, `town_grew` and
`district_declined`, the Food mode).

**What M5 is.** The map gets people. Every land district holds a number of people, kept per hex. M4's fixed people table
becomes the start and the **room**: a settlement's room comes from its level, a district's from its ground and its jobs.
People grow into their room each season, faster under low taxes, slower in winter. Towns eat from the stores (M4): when
their food is short they lose people to hunger. A village that fills its room **grows into a town by itself**, and the map
shows the bigger piece; a starved town that falls below its floor **declines to a village**. Walls and cities stay the
crown's works, and an upgrade now brings room, not people. People feed M4's economy as before (taxes on people, hands for
the districts, the towns' needs), now with numbers that move. The player sees it: **People and Food chips**, a people line
on the hover card and the hex panel, **growth ribbons**, the **Food mode** (key 5), the study's **People page**, a people
measure in **Rankings**, the report's **People section**, and the log, notifications and task flag lines of the two new
events. The other countries' people run the same rules every season; they take no actions until M8.

**When it starts.** After M4.5 is closed (its plan's definition of done, and the owner has played it). M5 edits `Game`,
`Session`, `Events`, the season table, `MapState`, `Country`, `StateView`, `Stats`, `StatsSystem`, `Economy`,
`DistrictCache`, `Improve`, `WorldImprove`, the previews, the report's view, the reminders, the log lines, the study's
views and pages, the map modes, the mode overlay, the map scene, the labels, the floaters, the chips, the hex and country
panels, the top bar and the App, and builds its screens into the M1.5 frame as M4.5 left it.

**M5 is done when:**

1. **A fed region grows and a starved one shrinks, inside set ranges.** `tests/core/test_people_growth.gd` plays 40
   seasons of "Italy, 1480", seed 1480, calm weather, Normal taxes, no works, and looks at Genoa's land (section 4.12).
   **Fed:** Genoa's people end between 105,000 and 112,000 (from 82,700), its towns between 56,000 and 61,500, and no
   season is hungry. **Starved** (the same game with a definitions copy that makes no food): Genoa's people end between
   55,000 and 62,000, its towns between 7,500 and 11,000, and every season from Winter 1480 is hungry. A fed village grows
   into a town on the map in the season section 4.11 (d) names, and a starved town falls to a village in the season 4.11 (e)
   names.
2. **No person from nowhere.** `tests/core/test_people_property.gd` plays 40 seasons of the 1480 scenario with seeded
   random actions for every country (works begun and cancelled, taxes set, `Game.dev_people`) and weather drawn, and finds
   every season and every country: the change of its people, hex by hex, equals the sum of its closed people flows
   (grew, starved, left, raised, returned, dev); the world's change equals the sum over all countries; no hex is below zero;
   growth never takes a hex past its room; a level changes only with its event (or a work's `work_finished`). A text test
   finds no writer of `people`, `people_start`, `people_end` or `people_flows` outside `people.gd` and the state classes'
   `from_dict`, `duplicate_state` and `create`.
3. **Food is accounted.** In the same run, every season and every country: the towns' food eaten never exceeds the need;
   the towns are fed (`food_fed` 1,000) exactly when the eaten food equals the need; `Stats` `food_made`, `food_eaten` and
   `food_need` equal the closed Stores flows of grain and fish and `Country.food_need`; and, every season of a 40-season run,
   the report's food line says the same numbers (`test_season_summary.gd`).
4. **The report's people lines sum.** For every season of that run, the People section's place lines add up to the
   section's change, and the change equals the country's people at the season's end less at its start
   (`test_season_summary.gd`); save, load and J give the same section.
5. **The preview still equals the season.** M4's 200-case property (`test_improve_preview.gd`) holds with people growing:
   the card's per-season numbers equal four played calm seasons to the unit; `EconomyPreview.with(game, tag, {}, 8)` equals
   eight played seasons for every country, people included (`test_economy_preview.gd`).
6. **Determinism and saves.** Same seed and same action log give the same digest after 40 seasons with people growing,
   towns levelling and `dev_people` records (`test_replay.gd`); save, load, save gives byte-equal files with people, flows
   and the closed season in them; ten seasons after a load give the same digest as ten without (`test_forty_seasons.gd`);
   `SaveFile.FORMAT` is 3 and an M4 save reads as "Made by an older test build".
7. Every M5 UI row of the standard's 9.1 is in the game, built from the kit, each with its GUT test: the People and Food
   chips with their cards; growth ribbons; the people and food lines on the hover card; the hex panel's People section;
   the country panel's people row; the Food mode (key 5) with its legend and the minimap; the study's People page; the
   people measure in Rankings and Standing; the report's People section with real data; the log, notification, ribbon and
   task flag lines of `town_grew`, `district_declined`, `hunger` and `town_full`; map labels that follow a town's level. No
   stand-in is left.
8. On the made-up Europe (494 x 247 hexes, 60 countries, 600 works) the CPU rows of section 8 hold in the nightly
   `perf_core.gd` run (a season's six phases under 190 ms; the people phase under 30 ms; the People page's view under 6 ms).
9. Lint, import, check_scripts and GUT are green, with both UI `--check`s (unchanged: M5 adds no texture or Theme
   variation) and `build_scenario.gd --check`; the art director has signed the pictures of section 9; the owner has played
   the build through the plan's checklist.

---

## 1. What is there, and where this page refines earlier pages

### 1.1 Read in the code (master `6d480d1`), the bake and the specs

| Finding | Where | What it means for M5 |
|---|---|---|
| The tile index has settlement pieces at **levels 1 to 5** (`piece/settlements/1/...` to `.../5/...`), castles and harbour add-ons at 1 to 3 | `godot/assets/tiles/summer/index.json`; `tools/worldmap/pieces/settlements.py` (`LEVELS = range(1, 6)`) | A town that grows or falls a level needs no new art: its cells change name and the bake already has them |
| `Improve.piece_of` gives the piece from `MapState.main_use` and `level`; a port's harbour add-on follows the settlement's level (`ImproveRules.ADDON_LEVEL` 0, 1, 1, 2, 3, 3) | `core/systems/improve.gd`, `improve_rules.gd` | A level change through `Improve` emits `hex_changed`; the map scene redraws the hex and its ring (M1) |
| `WorldImprove._put` keeps `place_distance`, `town_distance` and `city_distance` current when a settlement's level changes; `upgrade_check` applies the pair rules; there is **no way to lower a level** | `core/systems/world_improve.gd` | M5 adds `lower_check` and `lower` (5.3) |
| Cell rules that read a town: level 3 goods need a town (level 3+) within two hexes; silk needs one within two at any stage, dyes within one | `ImproveRules.cell_allowed` | A town may fall to a village only when no such piece near it needs it (4.5) |
| The map's 83 places: **36 towns, 23 villages, 10 walled towns, 2 cities, no hamlet**, 12 with no settlement (forts, hospices) | `data/maps/north_italy.tres` (read for this page) | No hamlet exists at the start; villages and towns are the levels the people move |
| Of the 23 villages, **14 have no town beside them** (Bern, Pontremoli, Belluno, Alba, Fréjus, Cesena, Pesaro, Cortona, Besançon, Glurns, Brignoles, Gubbio, Murten, Moûtiers); the other 9 sit beside a town (Lucca beside Pisa, Siena beside Florence) and cannot grow into towns (pair rule 0) | the same, with `PAIR_RULES` | Growth into a town is a real event in some countries and a "stays a village" line in others |
| **Savona (6, 13) and Cuneo (5, 13) are towns side by side** (places of the data, which the rules never move; pair rule 0 refuses Savona's walls, `m4-build-spec.md` 4.15 e) | `data/maps/north_italy.tres`, `ImproveRules.PAIR_RULES` | If Savona falls to a village it cannot grow back while Cuneo stands (4.5) |
| `MapLabels` sizes a place's name and plate by **`MapData.places[].level`** (the 1480 level) | `shell/mapview/map_labels.gd` (`font_size`, `layout`) | M5 makes it read the live level (6.9) |
| `Bindings.DEFAULTS` has `view_mode_1` to `view_mode_4` and no `view_mode_5`; `Settings.SCHEMA` `state/study_page` already lists `people` | `shell/input/bindings.gd`, `shell/app/settings.gd` | M5 adds `view_mode_5` (key 5) and no setting key |
| The kit already holds `ResourceChip`, `StudyTable`, `InkChart`, `DeltaChip`, `HoverCard`, `Medallion`, `Segmented`, `NavList`, `KitButton` (M1.5 u7c) | `shell/ui/` | M5 builds from them as M4 and M4.5 leave them |
| M4 bakes the icons `people`, `jobs`, `settlement` and, for later chips, `food` | `m4-build-spec.md` 6.2 | The two chips and the page need no new icon |
| v0.2.2: `economy.grow` grows every class by `BASE_GROWTH` + the tax term + a food term each season; `split_food` shares the food demand between grain and fish by supply | `hexa/campaign/systems/economy.py` 158 to 163, 232 to 275; `data.py` 458 to 475 | Section 3 |
| Built by M1.5 to M4.5 and named "(M2)" to "(M4.5)" below: `Territory`, `Countries`, `Works`, `Work`, `Calendar`, `Season`, `Stats`, `StatsSystem`, `Chronicle`, `Knowledge`, `Words`, `WorksView`, `LogLines`, `Reminders`, `SeasonSummary`, `Snapshot`, `SaveFile`, `Replay`, `Economy`, `EconomySeason`, `Treasury`, `Stores`, `DistrictCache`, `StateView`, `EconomyPreview`, `ImprovePreview`, `StudyEconomy`, `EconomyCards`, `StudyRankings`, `StudyHistory`, `MapModes`, `ModeOverlay`, `ModeLegend`, `StudyWarm`, `Study`, `StudyPage`, `StudyPages`, `PageRankings`, `PageHistory`, `ResourceChips`, `CountryCard`, `CountryPanel`, the floaters, the action log, `GameRequests`, `perf_core.gd`, `PerfFixture`, `economy_report.gd`, `economy_tables.gd` | their specs | M5 starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M5 | Why |
|---|---|---|
| `m4-build-spec.md` D6 and 4.3: people are a fixed table; "M5 replaces the table with `MapState.people` growing into the same numbers as room" | `MapState.people` per hex. The M4 table is the **start**: every number of M4 at turn 1 holds. The **room** of a settlement is a new column per level (2,000 / 4,000 / 20,000 / 45,000 / 100,000); the room of other land is M4's countryside people of its cover **plus the jobs of its district** (4.2) | Start people equal to room would leave nothing to grow until a paid upgrade; a room above the start lets towns grow and level up by themselves, and jobs bring people to the districts the player builds |
| M4 4.3: "people and hands count whoever owns the hexes" | Hands and jobs count **only the hexes of the district's own country** (4.7) | A country's numbers then depend only on its own state, so the preview, which simulates one country's people, stays exact. No M4 example changes: they are all fully staffed |
| M4 D10: a shortage lowers contentment and taxes; "M5 adds hunger, decline" | A **food** shortage also costs the towns people (hunger) and may lower a level; wine, salt and oil keep M4's effect on taxes only (4.4, D19) | One cause per effect: food drives growth (the standard's M5 row) |
| M4 D42: "M5 makes people grow into room and re-tunes these costs" | An upgrade brings **room, not people**. Village 100 → **60** ducats + 10 timber; town 300 → **200** + 20 timber + 10 stone; walled town and city unchanged (4.6) | The people raise villages and towns themselves; paying hurries it. Walls and cities bring a work slot, dues, the ring's lift and the room a full town needs |
| M4 5.4: `DistrictCache.FIELDS` 15, staffing kept in the cache | 14 fields: the people-free part. `staffing` and the output after it are worked out on each read from the live people (5.3) | People change every season; a cached staffing would be stale every season |
| M4 4.17: `EconomyPreview.with` runs production and income | It also runs the **people step** each season (growth, hunger, crowding, levels) for the country's own hexes (4.10) | The card, the reminders and Expected must equal the season (M4 done-when 4) |
| M4 4.15 (d): Genoa's city brings "people 30,000 → 60,000" and pays back in 32 seasons | **Replaced** by 4.11 (c): room 45,000 → 100,000, +56 a year, payback Winter 1500 | Follows from D17 |
| M4 and M4.5 tests that pin numbers (4.15 a, b, c, e; 4.12; M4.5's 4.10 and 4.11) | They run with **still people**: a definitions copy with every growth, hunger and crowding rate 0 (`PeopleFixture.still`), as they already force calm weather (4.13) | M4's and M4.5's numbers stay true as statements about the economy alone; M5's own examples carry the growing numbers |
| `m3-build-spec.md` 4.6: `Stats.SERIES` 35 | **40**: appended `people_towns`, `people_grew`, `people_starved`, `people_left`, `food_need` (4.16) | The People page charts and the food line read them; append-only, so a column is still found by name |
| `m4-5-build-spec.md` 4.13 and `test_insights_views.gd`: pins `PHASES`, `FORMAT`, `SERIES`, `NOTABLE` "of M4" | The pins move to M5's values in M5's pull request (section 11) | They prove M4.5 added no rule; M5 adds rules |
| `ui-and-controls-plan.md` section 4 row M5: "a People map mode" | The **Food** mode (key 5): your land by food made less eaten, a year (6.5) | The standard's 9.1 and the style plan's S5 say Food; where the people are shows in the hover card, the People page and the pieces themselves |
| M3 6.6: the floaters are fed by chronicled lines' `floating` word | The floaters gain a public `add_ribbon(hex, text, tone)`; M3's chronicled path calls it, and the map scene adds the season's people ribbons with it (6.8) | Growth ribbons are state changes, not chronicle lines |
| M1 and M2: `MapLabels` takes levels from `MapData.places` | It takes the level of a settlement hex from the game's `MapState` (6.9) | A town that grew must also read as one |
| M4.5 D9 and 4.19 of M4 (Standing): land and income | Rankings and the report's Standing gain **people** (6.7) | M4.5 handed a people measure to M5; Rankings equals Standing (M4.5 done-when 5) |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days). Data changes are a
`.tres` edit plus the test that pins the value.

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | Where people live | **Per land hex**, `MapState.people` (whole persons, `PackedInt32Array`); sea 0. Owned and unowned land both hold people | The district is the unit of the map (owner's answer); packed arrays per the standard 4.3 | M |
| D2 | People at the start | **M4's table**: a settlement its level's people (1,000 / 3,000 / 10,000 / 30,000 / 60,000), other land its cover's countryside people. No luck | Every M4 number of turn 1 (taxes, needs, reserve, start treasury) holds | Data (S) |
| D3 | Room | A settlement: its level's **room** (2,000 / 4,000 / 20,000 / 45,000 / 100,000). Other land: the countryside people of its cover **plus the jobs of the district on it** (M4's `FamilyDef.jobs`; castles have none). Snow and tundra: 0 | A town has room to grow before it needs walls; a district brings work, and people come to it | Data (S) |
| D4 | Who eats from the stores | **The towns** (settlement hexes), as M4; the countryside lives on its own land, which is what its room measures | M4 D9; the countryside's surplus is already the wild yield | M (a countryside need) |
| D5 | When a town is fed | When the country's towns got their whole **food** need this season (M4's food satisfaction, `food_fed` 1,000). One measure for all the towns of a country | The stores are the country's (M4 D11) | S |
| D6 | The growth law | Each season a hex gains `people × rate × season share`, floored, **never past its room** (capped growth, not a slowing curve) | A full town reaches its room exactly, so it can level up; "full at 4,000" reads plainly | M (a logistic law) |
| D7 | Growth rates | **1 % a season at Normal taxes, 1.25 % at Low, 0.5 % at High** (`GameDefs.growth_bp` 100, 125, 50) | M4 handed the tax level's growth effect to M5; v0.2.2's order (Low +, High −); fast enough that a fed village becomes a town in 30 to 40 seasons | Data (S) |
| D8 | Winter | Growth in winter: **none in the snow, half in the frost, full in the mild** (`growth_percent` 100, 100, 100, 0, 50, 100). Hunger in winter: **150 % in the snow, 125 % in the frost** (`hunger_percent` 100, 100, 100, 150, 125, 100) | The calendar's season matters to people as to works (M3 D11) and output (M4 D4) | Data (S) |
| D9 | Hunger | A hungry country's towns each lose `people × 4 % × season share × shortfall` a season (`hunger_bp` 400: 4 % at no food at all), rounded up, never below **200** people (`town_floor`) | v0.2.2 lost up to 4.5 % a season at no food; a place is never emptied | Data (S) |
| D10 | The countryside and hunger | **The countryside never starves in M5**: it grows into its room whatever the stores hold. M6 (foraging) and M7 (sacking) take people from it | D4: it does not eat from the stores | M |
| D11 | People over their room | They **leave**: 2 % a season (`left_bp` 200), rounded up, until the hex is back at its room (a district cleared, a settlement fallen a level, a developer edit) | Room must mean something both ways | Data (S) |
| D12 | Migration | **None.** People never move between hexes or countries; a hex keeps its people when it changes hands | One cause per change and an exact conservation property; refugees can come with war (M7) | L |
| D13 | Towns that grow a level | **The people raise a settlement up to a town (level 3) by themselves**; a walled town (4) and a city (5) stay the crown's works (`GameDefs.people_top_level` 3) | `06-growing-map.md` section 3: "the player chooses... the people fill it in... hamlets become villages"; walls are the crown's | Data (S) |
| D14 | When a settlement grows a level | In the people phase, when it is **full** (people = room), its towns were **fed** this season, **no work is under way** on it, and the pair rules and the works under way nearby allow the next level (4.5). Then `Improve.upgrade` puts the piece and `town_grew` is emitted | The same rules as a paid upgrade; a work under way owns the hex | S |
| D15 | When a settlement falls a level | A village under **1,000** people falls to a hamlet, a town under **2,000** to a village (`falls_below`), unless a work is under way on it or a district within two hexes needs it as its town (4.5). Walled towns and cities **never fall** to people (their walls stand); hamlets fall no further | The hysteresis (village from 2,000, back under 1,000; town from 4,000, back under 2,000) stops a place flickering; no fall may break a neighbour's rule | Data (S) |
| D16 | Paid settlement upgrades | Kept as a **hurry**: village 60 ducats + 10 timber (was 100 + 10), town 200 + 20 timber + 10 stone (was 300 + 20 + 10), walled town and city unchanged (700 + 20 + 60; 1,000 + 20 + 40). Durations unchanged (M3) | A hurried town unlocks the stage-3 districts, silk and dyes around it and a port's dues now; the people would do it later for free. Walls and cities bring a slot, the lift, dues and room | Data (S) |
| D17 | What an upgrade brings | **Room** (and the level's dues, fish, lift, walls, upkeep and slot, as M4); never people at once. M4 D42 is settled by this | People grow; the card says when they fill it | S |
| D18 | Hands and jobs | Count only the hexes of the district's **own country** (1.2) | The preview simulates one country | S |
| D19 | Weather, contentment and people | **Neither changes people directly.** Weather reaches people through the harvest in the stores; wine, salt and oil only change taxes (M4) | No double count; one cause per effect | M a term |
| D20 | Buying food | **None in M5.** A hungry country builds wheat or a fishing harbour, lowers its people's needs by waiting, or starves; buying arrives with markets (M10) | Fixed prices and one home market (M4 D2) cannot price an import | M10's work |
| D21 | Fish and grain | **Fish first, then grain** (M4's `food_order`). v0.2.2's `split_food` (demand shared by supply) is not kept | Fish does not keep; grain does, so the reserve is grain (M4) | S |
| D22 | One door for people | `People.move(game, hex, amount, why)` is the **only writer** of `MapState.people`; flows by reason on the hex's country: `grew`, `starved`, `left`, `raised`, `returned`, `dev` (append-only) | One owner per field; the conservation property needs flows | S |
| D23 | The season table | `people` after `works` (M4's planned row 11): M5's `PHASES` are **production, income, works, people, stats, calendar** | A finished town upgrade gives its room this season; taxes and needs of a season use the people it began with | S (a row move and the pin) |
| D24 | Other countries | Every living country runs the people phase every season, in id order; their towns grow and fall on the map; none acts until M8 | The AI is a player (standard 5.6); their towns are on the owner's map | none |
| D25 | Unowned land, the sandbox | Unowned land keeps its start people and never changes. The sandbox (a map-only game) sets people at the start and never changes them; `dev_people` is refused there | No country, no taxes, no food: nothing to drive them | S |
| D26 | The preview | Simulates the people of the previewing country's own hexes each season with the phase's own functions, levels included; other countries' pieces as they stand now | Exact by construction for one country (D18); a foreign town that grows beside yours inside the window is the one case it cannot see (section 10) | M |
| D27 | Events | `town_grew` and `district_declined` (`why`: `hunger` or `people`; M7 adds `sacked`), both notable | Game feedback D.2, M3's hand-over | S |
| D28 | Reminders | `hunger` (severity 2: your towns went hungry last season) and `town_full` (severity 1: a town or walled town at its room that only a work can lift) | M4 has "food runs out"; M5 adds "it has run out" and "build walls" | S a rule |
| D29 | The report | The **People section**: a line for each of your settlements whose people changed and one for the countryside, summing to the change; level lines and a food line as sub lines; a glance chip; Standing gains people | Game feedback A.2 row 6 and the mockup's People section | S |
| D30 | History kept | Five series appended to `Stats` (1.2); per hex only the people at the last season's start and end (`people_start`, `people_end`) | The page and the report need the last season by place; older seasons by country | M |
| D31 | Saves | `SaveFile.FORMAT` **3**, `OLDEST_FORMAT` 3: M4 saves read "Made by an older test build"; `map-state/4`, `country/3` | An M4 save's digest does not count people, so a loaded game could never match its header (M3's "The save is damaged"); M3 D31 allows raising `OLDEST_FORMAT` before M12 | S |
| D32 | What you may know of others | Another country's people (a hex or the whole) only when `Knowledge.knows`, **banded**; its food, growth, room and hunger never | M4.5 4.9's rule | S |
| D33 | The chips | **People** (your people, the change last season) and **Food** (grain and fish in store, the change) | UI plan M5 row; M4 left them to M5 | S a chip |
| D34 | The map mode | **Food** on key 5: your land by **food made less eaten, a year**, in nine bytes with striped deficits | First come, first numbered (M4.5 D15); "where does my food come from and go" | S |
| D35 | The People page | One page, no tabs, between Economy and Rankings in the nav: your towns (a table), the countryside line, food and growth charts | Game feedback C.2; the mockup's page order | S |
| D36 | Growth ribbons | After a season, a ribbon over each of your settlements whose people changed by 1 % or more or that lost people to hunger ("People +300", "Hunger −120"); "Grew" and "Declined" from the chronicle | The map shows growth (the standard's M5 row) without a ribbon per hex per season | S |
| D37 | The developer's lever | `people c r N` in the console sets a hex's people (`Game.dev_people`, recorded in the action log) | Tests and the playtest need towns at a set size | S |
| D38 | The milestone value | The App's milestone becomes `"5"`: `view_mode_5` registers, the People page and the people measure show | M1.5's rule | none |
| D39 | M6's recruits | People give men through `People.levy` (a check and a move, not an action); at most a tenth of a hex's people a season (`levy_permille` 100); men return through `People.give_back` (4.20) | Armies need people (the brief); one door keeps the conservation property | M6 re-tunes the share (data) |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| `grow()`: each province's peasants grow by `BASE_GROWTH` 0.25 % + `TAX_GROWTH` (+0.15 %, 0, −0.2 %) + `min(0, food − 0.9) × 0.05` a season; nobles at half the rate; burghers too | `systems/economy.py` 232 to 251; `data.py` 458 to 462 | Food drives growth; the tax level moves it (Low faster, High slower); hunger is proportional to the shortfall (about 4.5 % a season at no food) | Growth per district into a room (D3, D6) instead of without limit; 1 % a season at Normal (D7) so the map visibly grows; no classes (towns and countryside) |
| Burghers move from peasants to fill jobs (`moving = min(peasants × 0.006, jobs − burghers)`) | the same, 245 to 250 | Jobs draw people | A district's jobs are room on its hex (D3); no movement between hexes (D12) |
| `split_food(market)`: the food demand is shared between grain and fish by their supply | the same, 158 to 163 | Fish and grain are one food | Fish first, then grain (D21, M4) |
| `SUBSISTENCE` 0.15 grain per 1,000 peasants into the market; food demand 0.25 per 1,000 of every class | `data.py` 475, `NEEDS` | The countryside feeds itself | The countryside eats nothing from the stores; its surplus is the wild yield (M4 D5); only towns eat from the stores (D4) |
| `food_satisfaction()` of the market: supply over demand, at most 1 | `state.py` 94 | A permille of the need met | M4's `satisfaction` of the food need, per country (D5) |
| Settlement levels need people to be bought: `SETTLEMENT_POP` 6k village, 20k town, 45k city; the player pays (`SETTLEMENT_COST`) | `data.py` 233 to 240, `building.py` 93 | A level needs people | The people raise a settlement to a town themselves at its room; walls and cities are paid (D13, D16) |
| A queue finishing a settlement: "X has grown into a town." | `economy.grow` 256 to 271 | The words | `town_grew` for the people's levels; `work_finished` for paid ones |
| Recruiting takes 1,000 peasants a troop; needs 2,000 more left; foraging kills 4 % (`MANPOWER`, `FORAGE_LOSS`) | `data.py` 445 to 454, `military.py` 96 to 116, `supply.py` 106 | Armies take people | The M6 seam: `People.levy`, `give_back` (D39) |
| Colonies grow by `COLONY_GROWTH` 3.5 % and graduate at a size | `colonies.py`, `data.py` 463 | not used | Colonies come after M12 (owner's answer); no founding of new settlements in M5 |
| Population counted in thousands, as floats | everywhere | | Whole persons as integers (standard 5.4) |

---

## 4. Design content

### 4.1 The model in one picture

```
 each season, every living country in id order
 production   towns' needs from the stores (M4): food (fish, then grain), wine, salt, oil       Stores.move used
 income       taxes on people: towns x contentment, countryside (M4), on the people it began with Treasury.move
 works        a finished settlement upgrade raises the room now (M3, M4)
 people       fed = the food taken over the food need (this season, from the flows)              food_need, food_fed
              every owned land hex (index order):
                a settlement, not fed      -> hunger:  − people x 4 % x season share x shortfall People.move starved
                over its room              -> leave:   − 2 % a season, down to the room          People.move left
                else                       -> grow:    + people x rate x season share, to room   People.move grew
              then every settlement of the country (index order):
                full, fed, level < 3, rules allow -> Improve.upgrade, town_grew
                under its floor, level 2 or 3, no neighbour needs it -> Improve.lower, district_declined
 stats        the season's rows (people, towns, flows, food need); People.close: the season's start and end by hex
 any time     People.levy (M6), Game.dev_people (console): People.move raised / dev
```

### 4.2 Where people live: start and room

`People.start_people(game, hex)` (the M4 table) and `People.room_at(game, view, hex)`:

| What stands on the hex | Start (M4) | Room |
|---|---|---|
| Settlement, level 1 hamlet | 1,000 | 2,000 |
| Settlement, level 2 village | 3,000 | 4,000 |
| Settlement, level 3 town | 10,000 | 20,000 |
| Settlement, level 4 walled town | 30,000 | 45,000 |
| Settlement, level 5 city | 60,000 | 100,000 |
| Anything else (wild land, a goods district, a castle) | its cover's countryside people | its cover's countryside people + the district's jobs at its level |

Countryside people by cover (`GameDefs.country_people`, M4): farmland 8,000, grassland 5,000, woods 2,500, marsh 1,500,
rock 600, snow 0, tundra 0, sand 1,500. Jobs (`FamilyDef.jobs`, M4): goods districts 1,000 / 2,000 / 4,000 by stage, harbours
500 / 1,000 / 2,000, castles and settlements none. A settlement's room counts only the settlement; its hex has no
countryside of its own (as M4).

So a wild farmland hex starts **full** (8,000 of 8,000); a vineyard of the second stage on it has room 10,000 and fills
over the seasons; clearing it brings the room back to 8,000 and the extra 2,000 leave (D11).

**Genoa at the start** (seed 1480): people 82,700 (towns 40,000: Genoa 30,000, Savona 10,000; countryside 42,700), room
115,700 (Genoa 45,000, Savona 20,000, the countryside 50,700, of which the vineyard (7, 12) +2,000, the timber camp
(9, 13) +2,000 and the olives (7, 14) +4,000).

### 4.3 Food: who eats, when a country is fed

M4's rules stand (`m4-build-spec.md` 4.2, 4.7, 4.8): in `production` each country's towns take their needs from the
stores, food first (fish, then grain), then wine, salt and oil; the food need is `ceil(town people × 100 / 1,000,000)`
loads a season (a load feeds 10,000 town people); the reserve is four seasons of food in grain; what is above the reserve is
sold at the fixed price. M5 adds what the towns' food does to the people:

- **The food need and fed** of a country for the season: `food_need` = the food need of its towns (as production took it),
  `food_fed` = `min(1000, food eaten × 1000 / food_need)` (1,000 when the need is 0), where the food eaten is the grain and
  fish `used` of this season's open Stores flows (M4). The people phase writes both on the `Country` (they are People's).
- **The countryside eats nothing from the stores** (D4). Its people are its land's; their room is what the land feeds.
- **Every settlement of a country shares its `food_fed`** (D5): the stores are the country's.
- **Food made** is M4's: wheat, wild farmland and grassland grain (weather-bound), harbours' and ports' fish.

Food in a growing game: as towns grow, the need rises one load at each 10,000 town people, the grain reserve with it (four
seasons of food), so less grain is sold, and the stock drains when the land makes less than the towns eat. When the stock is
gone the towns go hungry, lose people, the need falls, and the country settles at what its land feeds. The player's levers
are M4's works (wheat, a fishing harbour, clearing a district to give back its wild grain), the taxes (D7) and, from M10,
markets.

### 4.4 Growth, hunger, crowding

`People.change_at(game, view, hex, season, tax, fed) -> Vector2i` (the amount, signed, and the flow's index) is the one
rule for one hex, used by the phase and the preview. All integers; `slot` is `Economy.slot_of(map, hex, season)` (M4: 0
spring, 1 summer, 2 autumn, or 3 + the hex's climate in winter); `p` the hex's people, `room` its room:

```
if room == 0 and p == 0:                     nothing
elif the hex is a settlement and fed < 1000: loss = ceil(p × hunger_bp × hunger_percent[slot] × (1000 − fed) / 1,000,000,000)
                                             loss = min(loss, max(0, p − town_floor))         -> (−loss, starved)
elif p > room:                               left = min(p − room, ceil(p × left_bp / 10,000))  -> (−left, left)
else:                                        g = floor(p × growth_bp[tax] × growth_percent[slot] / 1,000,000)
                                             g = min(g, room − p)                             -> (+g, grew)
```

(`ceil(a / b)` for positive integers is `(a + b − 1) / b`; the largest product, 100,000 × 400 × 150 × 1000, fits a 64-bit
integer.)

| `GameDefs` field | Value | Meaning |
|---|---|---|
| `growth_bp` | 125, 100, 50 | growth a season in hundredths of a percent, by tax level Low, Normal, High |
| `growth_percent` | 100, 100, 100, 0, 50, 100 | the season's share: spring, summer, autumn, winter in snow, frost, mild |
| `hunger_bp` | 400 | a settlement's loss a season at no food at all |
| `hunger_percent` | 100, 100, 100, 150, 125, 100 | the season's share of hunger |
| `left_bp` | 200 | the share of a crowded hex's people that leaves a season |
| `town_floor` | 200 | hunger never takes a settlement below this |
| `people_top_level` | 3 | the highest level the people raise a settlement to themselves |
| `levy_permille` | 100 | M6's seam: the share of a hex's people one levy may take (4.20) |

What these mean in seasons (fed, from Spring, no other change):

| | Snow | Frost | Mild |
|---|---|---|---|
| A village of 3,000 grows into a town (4,000), Normal | 39 seasons | 34 | 30 |
| the same at Low taxes | 31 | 27 | 24 |
| the same at High taxes | 79 | 69 | 60 |
| A town of 10,000 fills its room (20,000), Normal | 93 | 80 | 70 |
| A walled town of 30,000 fills its room (45,000), Normal | 54 | 47 | 41 |
| A town of 10,000 with no food at all falls under 2,000 (frost) | | 38 | |

### 4.5 Towns that grow a level, and fall

**The settlement levels by people** (`FamilyDef` of settlements; the start column is M4's `people`):

| Level | Start | Room: full, and grows to the next level at | Falls to the level below under | Who raises it |
|---|---|---|---|---|
| 1 hamlet | 1,000 | 2,000 | never | the people (none on north Italy at the start) |
| 2 village | 3,000 | 4,000 | 1,000 | the people, or a work (60 + 10 timber, 4 seasons) |
| 3 town | 10,000 | 20,000 (full: walls give room) | 2,000 | the people, or a work (200 + 20 timber + 10 stone, 8 seasons) |
| 4 walled town | 30,000 | 45,000 (full: a city gives room) | never | a work only (700 + 20 timber + 60 stone, 8 seasons) |
| 5 city | 60,000 | 100,000 | never | a work only (1,000 + 20 timber + 40 stone, 8 seasons) |

**`People.grow_check(game, view, hex, fed)`**, in order (the first refusal is the verdict); it reads the view, so the phase
(on `StateView.of(game.state)`) and the preview (on its what-if view) use the same rule:

| # | Case | Verdict |
|---|---|---|
| 1 | The hex holds no settlement on the view | "not a settlement" |
| 2 | Its level is `people_top_level` or more | "the people raise villages and towns; walls are the crown's work" |
| 3 | A work is under way on the hex (`game.state.work_at(hex)`) | "a work is under way here" |
| 4 | Its people are under its room | "not full: %s of %s people" |
| 5 | `fed` is under 1,000 | "your towns are not fed" |
| 6 | The next level breaks a pair rule against a piece of the view within two hexes (`ImproveRules.pair_reason(SETTLEMENT, level + 1, f, l, d)`, the first in `WorldImprove._pair_conflict`'s order) | the rule's words with the other piece, as `WorldImprove`: "a town needs its own countryside: no two towns side by side (settlements 3 at 5, 13)"; the result also carries `rule` (its index in `PAIR_RULES`) and `other` (its hex) |
| 7 | `Works.pending_conflict(game, hex, SETTLEMENT, level + 1)` is not "" (M3) | its words |
| 8 | Otherwise | ok |

**`People.decline_check(game, view, hex)`**:

| # | Case | Verdict |
|---|---|---|
| 1 | No settlement on the view | "not a settlement" |
| 2 | Level 1 | "a hamlet falls no further" |
| 3 | Level above `people_top_level` | "walls do not fall to hunger" |
| 4 | A work is under way on the hex | "a work is under way here" |
| 5 | Its people are at or above `falls_below[level]` | "not under %s people" |
| 6 | Level 3 only: a goods piece of the view within two hexes would break its cell rule with this settlement a village (a stage-3 district, a silk district or a dye works whose nearest other settlement of level 3 or more is farther than its rule allows: two hexes, two, one) | "the %s at (%d, %d) needs this town" (the family's name, its hex); the result carries `other` |
| 7 | Otherwise | ok |

A village that falls to a hamlet never breaks a rule (a hamlet is still a place), so row 6 reads only level 3.

**The level step of the phase.** After every hex of a country has changed (4.4), its settlements are visited in index
order. For each: `grow_check` on `StateView.of(game.state)` with the country's `fed`; when ok, `Improve.upgrade(game, {hex,
tag})` (which checks the piece's rules again on the real state, M1) and `town_grew` is emitted. Else `decline_check`;
when ok, `Improve.lower(game, {hex, tag})` and `district_declined` is emitted with `why` `hunger` when `fed` < 1,000, else
`people`. A level change earlier in the visit is seen by the later ones (the pair rules read the state as it now is), and
countries go in id order: the same game gives the same map.

**The words** (`Words.settlement(game, hex, level)`, M5): a named place is "Savona (6, 13)"; an unnamed settlement is "the
village near Turin (6, 11)" (its level word from `HexCard.LEVEL_WORDS`, then `Words.place`).

**After a fall.** The settlement's room is its new level's; its people are already under it, so nothing leaves. Savona,
fallen to a village, cannot grow back into a town while Cuneo (5, 13) stands beside it (pair rule 0): its outlook says so
(6.3). A town hurried by a work and a town grown by its people are the same thing afterwards.

### 4.6 The crown's works on settlements

Costs and durations of `data/defs/families/settlements.tres` after M5 (D16; M3's durations, M4's goods):

| To level | Ducats | Goods | Seasons | Brings at once | The people |
|---|---|---|---|---|---|
| 2 village | 60 (M4: 100) | 10 timber | 4 | room 2,000 → 4,000; dues 2 → 5 and fish 1 → 2 at a port; upkeep 0 → 1 | grow into the new room |
| 3 town | 200 (M4: 300) | 20 timber, 10 stone | 8 | room 4,000 → 20,000; a town for the stage-3, silk and dye rules within reach; dues 5 → 12, fish 2 → 4 at a port; upkeep 1 → 2 | the same |
| 4 walled town | 700 | 20 timber, 60 stone | 8 | room 20,000 → 45,000; walls 4; the ring's lift 100; a work slot (M3); dues 12 → 30, fish 4 → 6 | the same |
| 5 city | 1,000 | 20 timber, 40 stone | 8 | room 45,000 → 100,000; walls 6; lift 200; dues 30 → 45, fish 6 → 10; upkeep 2 → 5 | the same |

`ImprovePreview` (M4) shows a settlement upgrade's room and, for levels 2 and 3, the line "Its people raise it themselves
at 4,000 (in about 34 seasons)." (`PeopleView.seasons_to_full`, 5.6: the village near Turin (6, 11) at turn 1); when the
people are already full, "Its people are waiting for it." A paid upgrade never emits `town_grew`: `work_finished` (M3)
tells it.

### 4.7 People in M4's economy: what changes

| M4 formula or datum | After M5 | Numbers |
|---|---|---|
| `Economy.people_at(game, view, hex)` (M4 4.3: the table) | `view.people_at(index)`: `MapState.people`, or the preview's own number for that hex | Turn 1: equal to M4's table |
| `Economy.hands_at` (30 % of the people of the hex and its six land neighbours, whoever owns them) | the hex and its six land neighbours **held by the hex's owner** (D18); on unowned land the hex alone | Every M4 example is fully staffed: unchanged |
| `Economy.jobs_near` (the goods districts on the hex and its ring, any owner) | those **held by the hex's owner** | unchanged in the examples |
| `Economy.staffing` | the same formula on live hands | unchanged at turn 1 |
| `Economy.district_base` fields | adds `raw` (the base times the extra, before staffing), `people` (live); `room` is `People.room_at`; `a0` and `staffing` are live (5.3) | `district_output == season_output(district_base)` still holds |
| `DistrictCache` (M4 D28) | keeps 14 people-free ints a land hex; `base_of` adds the live people, staffing and `a0` | the same outputs; touched by `hex_changed` as before |
| `EconomySeason.town_people`, `country_people`, `needs_of`, `reserve_of` | unchanged code; they read live people through `people_at` | a need rises one load each 10,000 town people |
| Taxes on people (M4 4.9) | unchanged formula, live people | Genoa: 65 in Spring 1480, 66 in Summer (4.11 a) |
| `Treasury.start_amount` (200 + 5 a 1,000 people) | unchanged: people at setup are the table | M4 4.12's treasuries hold |
| `FamilyDef.people` (settlements) | now the **start** people; `room` and `falls_below` join it | values unchanged |
| Settlement costs to levels 2 and 3 | 60 + 10 timber; 200 + 20 timber + 10 stone (D16) | M4 4.4's settlement table edited |
| `EconomyPreview.with` | runs the people step each season (4.10) | 4.11 (c) |

Nothing else of M4 changes: prices, output, the reserve, sales, contentment, the ledger and the two doors are as M4 left them.

### 4.8 The season table after M5

`core/game/season.gd` `PHASES` in M5: **`production`, `income`, `works`, `people`, `stats`, `calendar`**
(`test_season.gd` pins it). The planned order, edited from M4's 4.13:

| # | Name | Arrives | Reads | Writes (through the owner) |
|---|---|---|---|---|
| 1 | `ai_orders` | M8 | everything through views | through `Game.act` only |
| 2 | `movement`, `battles` | M6, M7 | armies, map | armies, battles |
| 3 | `supply` | M6 | armies, owner | armies |
| 4 | `sieges` | M7 | armies, castles | owner, controller |
| 5 | `war_timeouts` | M9 | wars | wars |
| 6 | `production` | M4 | as M4; people (live) for the needs and hands | `stock`, `flows_open` (`Stores.move`); `goods_short` |
| 7 | `trade` | M10 | markets, stocks | stocks, prices |
| 8 | `income` | M4 | as M4; people (live) for the taxes | `treasury`, `ledger_open` (`Treasury.move`) |
| 9 | `debt` | M12 | ledgers, treasury | treasury |
| 10 | `works` | M3 (after income since M4) | as M3 | `works`, `next_work_id`; `main_use`, `level` (through `Improve`) |
| 11 | **`people`** | **M5** | `owner`, `main_use`, `level`, `people`, `turn`, `map.climate`, each country's `tax`, `flows_open` (food used), the works under way, `defs` | `people`, `people_flows`, `food_need`, `food_fed` (`People.move` and `People`); `main_use`, `level` (through `Improve.upgrade`, `Improve.lower`); events `town_grew`, `district_declined`, `hex_changed` |
| 12 | `research` | M11 | research | techs |
| 13 | `extinction`, `scores` | M12 | countries | `alive`, score |
| 14 | `stats` | M3 | as M4, and the people, flows and food need | `stats`; the ledgers and stores (M4); `people_closed`, `people_flows`, `people_start`, `people_end` (`People.close`) |
| 15 | `calendar` | M3 | `turn` | `turn`, `weather` |
| 16 | `ready_units`, `vision` | M6 | armies | armies, explored |

### 4.9 Other countries, unowned land, the sandbox

Every living country runs the people phase every season in id order, at its own tax level (Normal until M8 sets others):
their towns grow, go hungry and level on the map like the player's; `Knowledge` decides what the player hears of it (a
public event is witnessed by countries that know its actor, M3). Unowned land keeps its start people (D25). In a map-only
game the people phase does nothing; `People.setup` still fills the people so the hover card shows them.

### 4.10 The previews with people

`EconomyPreview.with(game, tag, changes, seasons)` (M4) runs, for each previewed season, production and income as M4 says,
then **the people step** of `tag`: `People.change_at` on each hex whose people can change (below), then the level step of
4.5 with `grow_check` and `decline_check` on the what-if view, the view taking the new levels (`StateView.with`) and the
new people (`StateView.with_people`) for the next season. The phase and the preview share every function; the preview
writes nothing.

- **Which hexes it steps:** the country's settlements, and its other hexes whose people are not equal to their room on the
  view (a district filling up, a crowded hex). A full countryside hex cannot change (its growth is capped, it never
  starves), so the step leaves it out; the phase steps every owned hex and gets the same result.
- **District output in the window:** a goods district's staffing is worked out again in a previewed season only when it
  was under 1,000 at the window's start or a hex of its ring lost people in the window (growth only adds hands, and a
  staffing of 1,000 stays 1,000 when hands grow). So M4's delta method holds: the 28 district runs of an option, plus the
  people step of the settlements and the changed ring.
- **Fed** in a previewed season is `goods_step`'s food satisfaction (M4), the same number the phase reads from the flows.
- **Calm weather**, as M4. Other countries' pieces are as they stand now (D26).

`EconomyPreview.with` returns, per season, M4's fields plus `people` (the country's total at the season's end), `towns`,
`fed`, `grew`, `starved`, `left`, `levels` (the level changes as `{hex, from, to}`). `EconomyPreview.expected` (one
season) gives the people this season will end with; the People page shows its change as "Expected this season".

### 4.11 Worked examples

All on "Italy, 1480", **seed 1480**, as Genoa, Normal taxes, calm weather (the tests force calm with `weather_odds = [100, 0,
0]` in their defs copy, as M4's do), people growing (the real rules). "The first-year game" has no works; "the fixture" is
M4's `economy_fixture.gd` ((7, 12) made wild before turn 1). The numbers were worked out by hand from M4's tables and the
rules above; the tests pin them.

**(a) Genoa's first year, people growing** (the first-year game; replaces nothing: M4's 4.15 (a) is the same economy with
still people):

| Season (turn) | People at the start → end | Towns at the start | Food need | Fed | Taxes on people | Taxes on goods | Port dues | Upkeep, walls | Net | Treasury |
|---|---|---|---|---|---|---|---|---|---|---|
| Spring 1480 (1) | 82,700 → 83,285 (▲ +585) | 40,000 | 4 | yes | 65 | 7 | 30 | −12, −4 | **+86** | 610 → 696 |
| Summer 1480 (2) | 83,285 → 83,874 (▲ +589) | 40,400 | 5 | yes | 66 | 6 | 33 | −12, −4 | **+89** | → 785 |
| Autumn 1480 (3) | 83,874 → 84,469 (▲ +595) | 40,804 | 5 | yes | 66 | 67 | 30 | −12, −4 | **+147** | → 932 |
| Winter 1480 (4) | 84,469 → 84,977 (▲ +508) | 41,212 | 5 | yes | 67 | 63 | 21 | −12, −4 | **+135** | → 1,067 |

In Spring the growth is Genoa +300 (30,000 × 1 %), Savona +100, the vineyard (7, 12) +80, the olives (7, 14) +80 and the
timber camp (9, 13) +25; the other nine countryside hexes are full. From Summer the towns hold 40,400 and need 5 food (the
need was `ceil(4.0)`, now `ceil(4.04)`): fish 6 caught, 5 eaten, 1 sold; the grain reserve rises to 20, so of the 6 grain
made only 2 are sold (M4's still economy: 4 eaten, 2 fish and 6 grain sold). Taxes on goods fall from 9 to 6 and taxes on
people rise from 65 to 66: +89 against M4's +91. In Winter no grain is sold (its stock is at the reserve): +135 against +134
(taxes on people 67, on goods 63). The year's treasury is 1,067 (M4: 1,068).

**(b) The report of Spring 1480, People section, on the fixture** (the section `tests/fixtures/report_sample.gd` gets):

| Line | Text | Amount |
|---|---|---|
| total | 82,700 → 83,205 | ▲ +505 |
| place | Genoa (8, 13) 30,300 | ▲ +300 |
| place | Savona (6, 13) 10,100 | ▲ +100 |
| place | The countryside, 12 places, 42,805 | ▲ +105 |
| sub | Food: 8 made for 4 eaten. Fed, 4 to spare. | |

300 + 100 + 105 = 505 (on the fixture (7, 12) is wild and full, so only the olives and the timber camp grow). The glance
gains the chip "People 83,205 ▲ +505"; Standing reads "Among the 3 countries you know, you are 3rd in land (14 districts),
3rd in income (+88 a season) and 3rd in people (83,205)." and, for each known country, M4's line with its people added:
"Savoy: about 58 districts, about +240, about N people." where N is `Knowledge.band` of Savoy's people at the season's end
(the land and income parts are M4's; the test compares N with the band of the game's own number).

**(c) Genoa, walled town to city, at Spring 1480** (the first-year game; replaces M4's 4.15 d):

| Field | Before → after |
|---|---|
| Verdict | "not enough ducats: 1,000 needed, 610 in the treasury" (`blocked_by` ducats); from Spring 1481 (1,067) it can begin |
| Brings (a season) | Room 45,000 → 100,000 · Port dues 30 → 45 ▲ +15 (spring) · Fish 6 → 10 · Upkeep and walls 6 → 11 ▼ −5 · "People 30,000: the new room counts once they pass 45,000, in about 41 seasons." |
| Each season | gain ▲ +15, +16, +15, +10 ("port dues 30 % lower" in winter) |
| Where it lands | This district: dues and fish; Ring of six: "timber near Genoa (9, 13): +1 a season, +2 in winter (the city's market)" · Country, a year 561 → 617 ▲ +56 |
| Treasury only | +13, +14, +14, +8 = +49 a year |
| Cost | 1,000 ducats · 20 timber · 40 stone · 8 seasons · ready Spring 1482 if begun now; M4's ticks |
| Payback | realm: Winter 1500, 83 seasons from now; treasury only: Autumn 1503, 94 seasons |
| Chips | "room +55,000", "+56 a year" |
| Next | "None: Genoa is at its top level." |
| Expensive | yes |

The country's year before (561) is M4's 557 plus the people's taxes growing over the four seasons (65 + 66 + 66 + 67 = 264
against 260). The seasons' gains: dues +15, +16, +15, +10; fish +4, +4, +4, +3; the timber camp's lift +1, +1, +1, +2; upkeep
and walls −5 each season.

**(d) A village grows into a town** (the 1480 scenario with an always-fed defs copy, `food_need_milli` 0, so every
country's towns are fed whatever its land makes): **the village near Turin (6, 11)**, Savoy's Alba (frost, 3,000 people, no
town beside it), is full at 4,000 in the people phase of **Summer 1488 (turn 34)** and grows into a town there:
`town_grew {tag: SAV, hex: (6, 11), level: 3, from: 2, people: 4000}`, one `hex_changed`, and the map's piece cells of
(6, 11) become `piece/settlements/3/...`. Cesena (18, 14), the Papal States' mild-winter port village, does the same in
**Summer 1487 (turn 30)**. Moûtiers (2, 8) (frost) also at turn 34. Lucca (12, 15) fills its 4,000 in Summer 1487 and stays a
village: "Stays a village: Pisa (13, 16) is a town beside Lucca: two towns may not stand side by side."

**(e) A town falls to a village** (the first-year game with a no-food defs copy, and at turn 1 `Game.dev_people` sets
Savona to 2,100 and `Game.dev_goods` empties Genoa's grain): the towns eat nothing (fed 0). Spring: Savona loses `ceil(2,100 ×
400 × 100 × 1000 / 10^9)` = 84 → 2,016. Summer: 81 → 1,935, under 2,000; the olives at (7, 14) still have Genoa within two
hexes, so Savona **falls to a village in the people phase of Summer 1480 (turn 2)**: `district_declined {tag: GEN, hex:
(6, 13), family: 1, level: 2, from: 3, people: 1935, why: hunger}`. With a dye works put at (7, 12) by a direct state edit
(its only town within one hex is Savona), Savona stays a town at 1,935 and no event is emitted.

**(f) The Food mode at Spring 1480** (the first-year game): Genoa (8, 13) makes 22 fish a year and its 30,000 people eat
12: +10, byte 6; Savona (6, 13) makes 6 grain and eats 4: +2, byte 4; the wild farmland (7, 13) makes 7 grain: byte 5; every
other hex of Genoa: 0, byte 3; every hex of another country: byte 0 (the veil).

### 4.12 The 40-season test (done-when 1)

`tests/core/people_fixture.gd` (`PeopleFixture`, new): `genoa(defs)` builds the first-year game with the given defs and
calm weather; `still(defs)`, `always_fed(defs)` and `no_food(defs)` return defs copies (5.6). The fed run is
`genoa(real defs)`; the starved run is `genoa(no_food(defs))`: settlements' `port_fish` all 0 and `wild_yield` of farmland
and grassland all 0, so Genoa makes no food at all (it has no wheat and no harbour).

| After 40 seasons (Winter 1489) | Fed: worked out | Fed: the test's range | Starved: worked out | Starved: the test's range |
|---|---|---|---|---|
| Genoa's people | 108,582 (+31.3 %) | 105,000 to 112,000 | 58,795 (−28.9 %) | 55,000 to 62,000 |
| its towns | 58,798 (Genoa 44,647, Savona 14,151) | 56,000 to 61,500 | 9,011 (Genoa 6,929, Savona 2,082) | 7,500 to 11,000 |
| its countryside | 49,784 | (not tested) | 49,784 | (not tested) |
| hungry seasons | none | none | Winter 1480 (fed 400) and every season after (fed 0) | every season from turn 4 |

The ranges are about ±3 % round the worked values: a change of a rate that moves the result past them is a design change
and edits this table and the test in one pull request (Opus reviews). The starved towns are first fed from the four seasons
of grain in store, which is why the hunger starts in Winter 1480; in the starved run the countryside still grows into its
districts' jobs (D10).

### 4.13 M4's and M4.5's examples and the mockups: what holds

| Page, example | After M5 |
|---|---|
| M4 4.12 (13 countries at the start: people, treasury, needs, reserve) | **Holds** (D2). The first year's nets hold with still people; in a growing game they move by a few ducats a season (4.11 a) |
| M4 4.15 (a) Genoa's first year | **Holds with still people** (`test_economy_genoa.gd` runs on `PeopleFixture.still`); the growing year is 4.11 (a) |
| M4 4.15 (b) the report of Spring 1480 | **Holds** (turn 1); M5 adds the People section of 4.11 (b) |
| M4 4.15 (c) the vineyard card | **Holds with still people**; in a growing game the country's year is a few ducats higher on both sides |
| M4 4.15 (d) Genoa to city | **Replaced** by 4.11 (c) |
| M4 4.15 (e) Savona refused | **Holds** |
| M4.5 4.10 (Districts, History, Goods, Rankings) and 4.11 (the five questions) | **Hold with still people** (`InsightsFixture` runs on `PeopleFixture.still`); the five questions' rows, places and words hold in a growing game |
| `works_genoa.jpg` "People room 70,000 → 100,000" | Now "Room 45,000 → 100,000" (closer to the mockup than M4's people jump) |
| `report_m4.jpg` and `game-feedback-screens.md` A.3, People: "Genoa 62,000 ▲ +700 · Savona 14,000 ▲ +150 · the countryside 136,000 ▲ +450", "Food: 127 made for 104 eaten" | **Replaced** by 4.11 (b) |
| `game-feedback-screens.md` C.3, the tax hover "people ▼ −0.3 % a season" | **Replaced**: "High: people grow 0.5 % a season, not 1 %" (6.7) |
| `play_m4.jpg`'s Grain chip | **Replaced** by the Food chip (grain and fish in store) |

### 4.14 Reminders after M5

`Reminders.RULES`: `treasury_empty`, **`hunger`**, `goods_running_out`, `winter_halt`, `treasury_falling`, **`town_full`**,
`free_slot`; lines worst first (severity, then this order).

| Rule | When | Severity | Text | Action |
|---|---|---|---|---|
| `hunger` | the player's `food_fed` of the last season ended is under 1,000 | 2 | "Your towns went hungry: 8 of 9 food. They lose people each season until they are fed." | `[&"study", &"people"]`, "Open People" |
| `town_full` | a settlement of the player at its room whose next level only a work gives (level 3 or 4) and with no work under way | 1 | "Savona (6, 13) is full at 20,000 people: walls would give it room." / "Genoa (8, 13) is full at 45,000 people: a city would give it room." (two or more: "2 towns are full: Savona (6, 13) and Genoa (8, 13).") | `[&"look_at", hex]` of the first, "Go to Savona" |

M4's `goods_running_out` keeps saying "Food runs out next season." before the stock is gone (it runs `EconomyPreview.with`
for eight seasons, now with people growing, so it sees a growing need).

### 4.15 The season report after M5

`SeasonSummary.of` fills the `people` section (style spec 6.4's shape; `sub` lines are not counted in the sum):

| Id | M5 content |
|---|---|
| `glance` | Treasury (M4); then **People** (the closing value, the change); then M3's Works and Land; then the largest goods swing or the Weather chip; at most five |
| `before` | M3's, M4's and 4.14's lines, at most five |
| `people` | `total` "82,700 → 83,205" (from, to, amount: the country's people at the season's start and end, over the hexes it holds now). Lines: one per settlement of the country whose people changed ("Genoa (8, 13) 30,300", amount the change; `hex` a link); one line "The countryside, 12 places, 42,805" with the countryside's change (only when not zero). `sub` lines: "Savona (6, 13) grew into a town." (good, from the chronicle's `town_grew` of the turn), "Savona (6, 13) fell to a village: hunger." or ": too few people." (bad), and the food line. Rank: `|change| × town_tax_milli / 1,000,000` (the change's worth in taxes a season, as the style spec ranks in ducats) |
| `befell` | M3's and M4's, plus known others' `town_grew` and `district_declined` |
| `standing` | M4's line with people (4.11 b) |

The food line (`sub`), from the closed Stores flows of grain and fish and `Country.food_need`:

| Case | Text |
|---|---|
| fed, made ≥ eaten | "Food: 8 made for 4 eaten. Fed, 4 to spare." |
| fed, made < eaten | "Food: 3 made for 5 eaten. Fed from the stores: 12 left." |
| hungry | "Food: 8 made for 9 needed. 1 short: your towns lost 404 people to hunger." |

The place lines are for the last season ended only (`people_start`, `people_end` hold one season): for an older turn the
section has only its total, from the `Stats` rows. The sandbox's report (M3 D29) has no People section: nothing changes
there. **Quiet** (M3 and M4's rule, plus): the people's change under 2 % and no level line. `swing_permille` and the toast
are M4's.

### 4.16 Stats after M5

`Stats.SERIES` gains, appended: `people_towns`, `people_grew`, `people_starved`, `people_left`, `food_need` (40 series).
`StatsSystem.season` writes, per country: `people` (its hexes' people after the people phase; M4 wrote the table's total),
`people_towns` (its settlements'), `people_grew`, `people_starved`, `people_left` (the season's open flows, as positive
numbers), `food_need` (`Country.food_need`); M4's `food_made` and `food_eaten` as before. Then, after `Treasury.close_ledger`
and `Stores.close`, it calls `People.close`. In a map-only game the pseudo-country `""` (M3 D25) gets the whole map's
people and zeros in the four other series. Sizes on the made-up Europe with 60 countries: ring 0.38 MB, year rows 1.64 MB by
1650 (2.0 MB; M3: 1.74 MB).

### 4.17 Events, the chronicle, the log

| Kind | Fields (besides `kind`, `turn`) | Emitted by | Notable | Typed signal | Heard by |
|---|---|---|---|---|---|
| `town_grew` | `tag`, `hex`, `level` (new), `from`, `people` | `People.season` (the level step) | yes | `town_grew(tag, hex, level)` | `HexPanel` (refresh when it shows the hex), `MapScene` (the Food overlay when in Food mode); through `chronicled`: log, notifications, ribbons, History |
| `district_declined` | `tag`, `hex`, `family` (1 in M5), `level` (new), `from`, `people`, `why` (`hunger`, `people`; M7 `sacked`) | the same | yes | `district_declined(tag, hex, level, why)` | the same |

`Chronicle.NOTABLE` gains both (nine kinds). `LogLines` lines:

| Kind | The player's line | A known other's |
|---|---|---|
| `town_grew` | "Savona (6, 13) grew into a town." keyword "Grew", tone good, filters all, mine; `notify` true; `floating` "Grew" | "Savoy: the village near Turin (6, 11) grew into a town." muted, all; `floating` "Grew" (muted) |
| `district_declined` | "Savona (6, 13) fell to a village: hunger." (": too few people." for `people`) keyword "Declined", tone bad, filters all, mine; `notify` true; `floating` "Declined" | "Milan: Cremona (12, 9) fell to a village." muted, all; `floating` "Declined" (muted) |

No new filter: people lines show in All and Mine. `SeasonSummary.COVERED` is unchanged (the two kinds raise no toast).

### 4.18 Saves and the digest

| Body key | M5 adds | In `Game.digest()` |
|---|---|---|
| `format` | 3 (`SaveFile.FORMAT`; `OLDEST_FORMAT` 3) | no |
| `map_state` | `map-state/4`: `people`, `people_start`, `people_end` (`PackedInt32Array`, one int a hex, sea 0; packed as they are) | `MapState.digest()` |
| `countries` | `country/3`: `people_flows` (`PackedInt32Array` by `People.FLOWS`), `people_closed` (`{turn, flows}`), `food_need`, `food_fed` | each `digest_text()` |
| `stats` | the five series (by name; a save without them would load them as zeros, M3) | `Stats.digest()` |
| `action_log` | `dev_people` records | no (M3 D22) |

`MapState.from_dict` reads schema 3 with the three arrays at zeros (only tests make such a dict: a format-2 save is refused
before). `Country.from_dict` reads `country/2` with empty flows and zeros. Sizes on the made-up Europe: three int arrays of
122,018 hexes, 1.46 MB before compression, mostly equal runs (the countryside at its room): `save_mb` (8) is measured
nightly.

### 4.19 What you may know of others

| Thing | You see |
|---|---|
| Another country's people (its total, a hex's) | only when `Knowledge.knows`; banded (two figures): "about 260,000", "about 30,000" |
| Its rank in people | its place in your Rankings list, from exact values (M4.5 D10) |
| Its food, need, fed, growth, room, its towns' outlook | nothing |
| Its towns that grew or fell | the chronicle lines you witnessed (until M6, a public event is seen by countries that know its actor) |
| Its pieces | the map (they are drawn) |
| Unowned land | its people, exact (no one keeps it) |
| The viewer `&""` (tests, the sandbox) | everything, exact |

### 4.20 The M6 seam: recruits come from the people

M6's `recruit` action (Military) takes its men through People; M5 builds and tests the seam, and nothing in M5 calls it but
its tests:

```gdscript
static func available(game: Game, hex: Vector2i) -> int
	# the men one levy may take here now: people × levy_permille / 1000, floored; 0 at sea, off the map, on unowned land
static func levy_check(game: Game, tag: StringName, hex: Vector2i, men: int) -> Dictionary
	# in order: "not a land hex"; M2's home rule (Territory.at_home_check); "no men asked" (men < 1);
	# "only %d men can be raised here: %s holds %d people" (men > available); ok
static func levy(game: Game, tag: StringName, hex: Vector2i, men: int) -> int
	# checks again; People.move(game, hex, -men, &"raised"); returns the men taken (0 when refused)
static func give_back(game: Game, hex: Vector2i, men: int) -> int
	# disbanded men come home: People.move(game, hex, men, &"returned"); over the room they leave as any crowd (4.4);
	# returns the men placed (0 at sea, off the map, on unowned land, or men < 1)
```

M6 decides how many men a company takes and whether towns or the countryside give them; `levy_permille` is data. The
flows `raised` and `returned` exist from M5 (append-only), so M6 changes no save field for them.

---

## 5. Interfaces

Layers as the standard: `defs`, `state`, `systems`, `game`, `views`, `shell`. `core/` makes no engine calls; M5 draws no
luck. New files are marked **new**; "(M2)" to "(M4.5)" and "(M1.5)" name pieces those milestones build. Every amount is an
`int`.

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/game_defs.gd  (M2 to M4, edit)
@export var growth_bp: PackedInt32Array          # 3, by tax level: 125, 100, 50 (hundredths of a percent a season)
@export var growth_percent: PackedInt32Array     # 6 slots: 100, 100, 100, 0, 50, 100
@export var hunger_bp := 400
@export var hunger_percent: PackedInt32Array     # 6 slots: 100, 100, 100, 150, 125, 100
@export var left_bp := 200
@export var town_floor := 200
@export var people_top_level := 3
@export var levy_permille := 100
# validate() adds: growth_bp 3 entries 0..1000; growth_percent and hunger_percent 6 entries 0..400; hunger_bp 0..2000;
# left_bp 0..5000; town_floor >= 0; people_top_level 1..5; levy_permille 0..1000

# core/defs/family_def.gd  (M3, M4, edit)
@export var room: PackedInt32Array               # settlements: per level, the most people it holds; empty otherwise
@export var falls_below: PackedInt32Array        # settlements: per level, the people under which it falls a level; 0 never
# `people` (M4) is now the start people of a level.
# validate() adds, for settlements only: room and falls_below have TOP_LEVEL + 1 entries; room[0] 0; room rises with the
# level; people[L] <= room[L] for L >= 1; falls_below[1] 0; for 2 <= L, falls_below[L] < room[L - 1] (a settlement that
# falls is under its new room); falls_below[L] 0 above GameDefs.people_top_level (checked by GameDefs.validate, which
# knows both)
```

### 5.2 State (`core/state/`)

```gdscript
# core/state/map_state.gd  (M1 to M3, edit): schema "hexa-godot/map-state/4"
var people: PackedInt32Array          # per hex: whole persons; sea 0. Written only by People (move, setup)
var people_start: PackedInt32Array    # per hex: the people at the start of the last season ended (People.close)
var people_end: PackedInt32Array      # per hex: the people at the end of the last season ended (People.close)
# create() sizes the three; duplicate_state() copies them; to_dict() adds them (packed); from_dict() reads schema 4, and
# schema 1 to 3 with the three at zeros; digest() adds the three in this order

# core/state/country.gd  (M2, M4, edit): schema "hexa-godot/country/3"
var people_flows: PackedInt32Array    # People: the open season's flows, signed, by People.FLOWS
var people_closed: Dictionary = {}    # People: {turn, flows: PackedInt32Array} of the last season ended
var food_need: int = 0                # People: the towns' food need of the season (written in the people phase)
var food_fed: int = 1000              # People: food eaten × 1000 / need of the season (1000 when fed)
# to_dict / from_dict carry them (country/2 reads with zeros and {}; a flows array shorter than People.FLOWS, from before
# a flow was appended, is padded with zeros); digest_text() appends
# "|" + people_flows as a comma list + "|" + people_closed + "|food_need|food_fed"

# core/state/state_view.gd  (M4, edit)
func people_at(i: int) -> int                                  # the view's own number for hex i, else MapState.people[i]
func with_people(people: Dictionary) -> StateView              # hex index -> int; a new view keeping this view's other
	# changes; the base untouched

# core/state/stats.gd  (M3, M4.5, edit)
# SERIES appends "people_towns", "people_grew", "people_starved", "people_left", "food_need" (40)
```

### 5.3 Systems (`core/systems/`)

```gdscript
# core/systems/people.gd  (new)
class_name People extends RefCounted
const OWNS: Array[String] = ["people", "people_start", "people_end", "people_flows", "people_closed", "food_need",
	"food_fed"]
const FLOWS: Array[StringName] = [&"grew", &"starved", &"left", &"raised", &"returned", &"dev"]   # append-only
static func start_people(game: Game, hex: Vector2i) -> int        # 4.2: the M4 table; 0 at sea and off the map
static func room_at(game: Game, view: StateView, hex: Vector2i) -> int   # 4.2
static func setup(game: Game) -> void        # every land hex: people = people_start = people_end = start_people;
	# flows zero; called by Game.new_game and Game.new_scenario before Treasury.setup
static func move(game: Game, hex: Vector2i, amount: int, why: StringName) -> bool
	# THE ONLY WRITER OF PEOPLE after setup. false and nothing changes for: a hex off the map or at sea; a why not in FLOWS;
	# a result below 0; in a game with countries, a hex no country holds; a map-only game. amount 0 changes nothing and
	# returns true. Else people[i] += amount and the owner's people_flows[FLOWS.find(why)] += amount
static func food_need_of(game: Game, view: StateView, tag: StringName) -> int   # EconomySeason.needs_of(...).food
static func fed_of(game: Game, tag: StringName, need: int) -> int
	# min(1000, (grain used + fish used this season, from flows_open) × 1000 / need); 1000 when need is 0
static func change_at(game: Game, view: StateView, hex: Vector2i, season: int, tax: int, fed: int) -> Vector2i
	# 4.4: x the signed amount, y the index in FLOWS (grew, starved or left); (0, 0) when nothing changes
static func grow_check(game: Game, view: StateView, hex: Vector2i, fed: int) -> Dictionary
	# 4.5: {ok, reason, rule: int (-1 none), other: Vector2i (NO_HEX none)}
static func decline_check(game: Game, view: StateView, hex: Vector2i) -> Dictionary   # 4.5: {ok, reason, other}
static func season(game: Game) -> void       # the people phase (4.1, 4.4, 4.5): per living country in id order, food_need
	# and food_fed, every owned land hex in index order through change_at and move, then the level step
static func close(game: Game) -> void        # in stats: every country's people_closed = {turn, flows: people_flows}, flows
	# zeroed; people_start = people_end; people_end = people (copies)
static func available(game: Game, hex: Vector2i) -> int                                   # 4.20
static func levy_check(game: Game, tag: StringName, hex: Vector2i, men: int) -> Dictionary # 4.20
static func levy(game: Game, tag: StringName, hex: Vector2i, men: int) -> int             # 4.20
static func give_back(game: Game, hex: Vector2i, men: int) -> int                         # 4.20
const NO_HEX := Vector2i(-1, -1)

# core/systems/economy.gd  (M4, edit)
static func people_at(game: Game, view: StateView, hex: Vector2i) -> int    # view.people_at(index); 0 at sea, off the map
static func hands_at(game: Game, view: StateView, hex: Vector2i) -> int     # 4.7: the owner's hexes only
static func jobs_near(game: Game, view: StateView, hex: Vector2i) -> int    # 4.7: the owner's hexes only
static func district_base(game: Game, view: StateView, hex: Vector2i) -> Dictionary
	# M4's keys plus raw (thousandths: base × extra before staffing) and people (live); room = People.room_at; staffing
	# and a0 (= raw × staffing / 1000 × (1000 + lift) / 1000, floored in that order, as M4) live

# core/systems/district_cache.gd  (M4, edit)
const FIELDS := 14     # family, level, good, raw, keep, cover, wild_good, weather_bound, port_level, upkeep, walls, jobs,
	# room, lift: the people-free part. base_of(game, i) returns district_base's dictionary: the cached ints plus people,
	# staffing and a0 worked out on the read from game.state's people (a goods district reads the people and the cached jobs
	# of its hex and ring: 14 reads)

# core/systems/world_improve.gd  (M1, edit)
func lower_check(hex: Vector2i) -> Dictionary    # "not a land hex"; "only a settlement falls a level"; "a hamlet falls no
	# further"; else ok (the neighbours' rules are People.decline_check's, which alone calls lower)
func lower(hex: Vector2i) -> Dictionary          # checks again; _put(hex, SETTLEMENT, level - 1) (the distances follow)

# core/systems/improve.gd  (M1, edit): a check and its doer, not actions; OWNS unchanged (main_use, level)
static func lower_check(game: Game, args: Dictionary) -> Dictionary   # {hex, tag}: "no hex given", then WorldImprove's
static func lower(game: Game, args: Dictionary) -> Dictionary         # checks again; game.improvement.lower; hex_changed
```

**OWNS after M5** (`tests/core/test_owns.gd` diffs `Snapshot.of` around every action and phase):

| Field | Written by | In an action | In a phase |
|---|---|---|---|
| `people`, `people_flows` | `People` (`move`) | none of the action table; `Game.dev_people` (the door's developer record) | `people`; M6's levies |
| `people_start`, `people_end`, `people_closed` | `People` (`close`) | no | `stats` |
| `food_need`, `food_fed` | `People` | no | `people` |
| `main_use`, `level` | `Improve` | no (works begin only) | `works` (finishing), **`people`** (`upgrade`, `lower`) |
| everything of M4's table | as M4 5.3 | | |
| `events`, `action_log`, `chronicle`, `version`, `view_cache`, `districts` | `Game` (the door) | yes | yes |

### 5.4 Game, the action table, the season, saves (`core/game/`)

```gdscript
# core/game/game.gd  (M1 to M4, edit)
func dev_people(hex: Vector2i, people_value: int) -> bool
	# People.move(game, hex, people_value - people[i], &"dev"); the action log record {turn, action: "dev_people",
	# args: {hex, people: people_value}}; false (nothing logged) when move refuses or people_value < 0
# new_game: People.setup after the improvement search (when defs is set). new_scenario: Countries.setup, Territory.setup,
# People.setup, then Treasury.setup, Stores.setup and Stats.create (M4's order with People before the purse). with_state
# (M3, tests): People.setup when the given state's people array is empty and defs is set
# digest(): the M4 string, unchanged in form (MapState and each country carry the new fields)

# core/game/actions.gd: unchanged (M5 adds no action)

# core/game/season.gd  (M3, M4, edit)
const PHASES: Array[StringName] = [&"production", &"income", &"works", &"people", &"stats", &"calendar"]
# run_phase: people -> People.season

# core/game/replay.gd  (M3, M4, edit): plays "dev_people" through Game.dev_people
# core/game/snapshot.gd  (M3, M4, edit): type-checks map-state/4's three arrays (size, packed int) and country/3's fields
# core/game/save_file.gd  (M3, M4, edit): FORMAT := 3; OLDEST_FORMAT := 3

# core/systems/stats_system.gd  (M3, M4, edit): 4.16; People.close after Treasury.close_ledger and Stores.close
```

### 5.5 Events and Session (`shell/autoload/`)

```gdscript
# shell/autoload/events.gd  (edit)
signal town_grew(tag: StringName, hex: Vector2i, level: int)
signal district_declined(tag: StringName, hex: Vector2i, level: int, why: StringName)

# shell/autoload/session.gd  (edit)
func dev_people(hex: Vector2i, people_value: int) -> bool   # developer console only; drains
# drain(): town_grew -> Events.town_grew(tag, hex, level); district_declined -> Events.district_declined(tag, hex, level,
#   why); then chronicled (M3). last_phase_ms gains people
```

### 5.6 Views (`core/views/`, pure)

```gdscript
# core/views/words.gd  (M3, M4, edit)
static func settlement(game: Game, hex: Vector2i, level: int) -> String   # "Savona (6, 13)"; "the village near Turin (6, 11)"
static func people(n: int) -> String                                      # "1 person", "30,300 people"

# core/views/people_view.gd  (new)
class_name PeopleView extends RefCounted
static func at(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary
	# {} at sea or off the map; else {shown: bool, exact: bool, people, room, change (people_end − people_start),
	#  text ("30,300 · room 45,000 · ▲ +300"; others known: "about 30,000"; unowned or viewer "": "2,500"; snow: "none")}
	# shown false for an unknown country's land (Knowledge.knows)
static func outlook(game: Game, hex: Vector2i) -> Dictionary     # {text, tone}: the table of 6.3, for the hex's owner
static func seasons_to_full(game: Game, view: StateView, hex: Vector2i) -> int
	# seasons until the hex's people reach its room on the view, stepping change_at fed at the owner's tax from game.turn;
	# -1 past 400 seasons; 0 when full
static func ribbons(game: Game, tag: StringName) -> Array[Dictionary]
	# [{hex, text, tone}] for the settlements of tag in the last season ended: |people_end − people_start| × 100 >=
	# people_start, or a hunger loss: "People +300" (good), "Hunger −120" (bad); index order

# core/views/cards_people.gd  (new; the chips' hover cards)
class_name PeopleCards extends RefCounted
static func people(game: Game, tag: StringName) -> Dictionary
	# {value (the country's people), change (the last season's, from people_start and people_end), title ("People"),
	#  lines: [[text, tone, amount]] ("Towns 40,400", "Countryside 42,885", a rule, "Grew ▲ +585", "Starved", "Left"
	#  (only when not 0), "Room for 32,415 more"), hint ("Click: the People page")}
static func food(game: Game, tag: StringName) -> Dictionary
	# {value (grain + fish in store), change (their closed change), title ("Food"), tone (bad when food_fed < 1000),
	#  lines: ["Made 8 · Eaten 4 · Sold 4" (last season), "Your towns need 5 a season", "Lasts over 8 seasons"
	#  (StudyEconomy.lasts of grain)], hint ("Click: the People page")}

# core/views/study_people.gd  (new)
class_name StudyPeople extends RefCounted
static func of(game: Game, tag: StringName, span: int) -> Dictionary
	# {has_data (a season has ended), date, head: {people, change, towns, countryside, room, room_left, expected},
	#  rows: Array[{id (hex index), hex, place, what, people, room, change, outlook, tone}] (your settlements; people
	#   descending, ties by id),
	#  countryside: {count, people, room, change},
	#  food: {made, eaten, need, fed, text (the report's food line), lasts_text},
	#  labels: Array[String], series: {people, towns, grew, starved, left, food_made, food_eaten, food_need}
	#   (PackedInt32Array, oldest first, from Stats over the span)}
	# cached [&"study_people", version, tag, span]

# core/views/economy_preview.gd  (M4, M4.5, edit): 4.10; seasons[k] gains people, towns, fed, grew, starved, left, levels
# core/views/improve_preview.gd  (M4, edit): brings gains `room` (every option whose room changes) and, for settlements,
#   the people line of 4.11 (c) and 4.6; a settlement's chip is "room +55,000"; M4's people jump is gone
# core/views/hex_card.gd  (M1.5 to M4.5, edit): a "People" line (PeopleView.at's text) on land; a "Food" line on your land
#   when the hex makes or eats food: "made 22, eaten 12 a year" (MapModes.food_year)
# core/views/country_card.gd  (M2, M4, edit): people: {shown, value, banded, change} (yours exact, known banded, else
#   shown false)
# core/views/reminders.gd  (M3, M4, edit): 4.14
# core/views/season_summary.gd  (M3, M4, edit): 4.15
# core/views/log_lines.gd  (M3, M4.5, edit): 4.17
# core/views/study_rankings.gd  (M4.5, edit): MEASURES appends {id = &"people", title = "People", since = "5"};
#   value_of(stats, &"people", tag, turn) reads Stats people
# core/views/study_history.gd  (M4.5, edit): MARK_KINDS [land, declined, grew, finished, stopped, short, begun, tax,
#   chosen]; MARK_ICONS adds declined and grew = &"settlement"; season()'s text adds " · people 83,285"

# core/views/map_modes.gd  (M2, M4.5, edit)
enum Mode { TERRAIN, OWNER, RELIEF, YIELDS, FOOD }     # keys 1 to 5
const MODE_KEYS: Array[StringName] = [&"terrain", &"owner", &"relief", &"yields", &"food"]
const FOOD_ALPHA := 0.70
const FOOD_FLOORS: PackedInt32Array = [1, 5, 10, 20, 40]   # the net food a year that starts bytes 4 to 8
const FOOD_DEFICIT := -10                                   # at or under: byte 1
const FOOD_COLOURS: Array[Color] = [Color("#8e2a17"), Color("#c8664c"), Color("#efe3c4"), Color("#ead68f"),
	Color("#d4bc4e"), Color("#a7a03a"), Color("#6b8b4a"), Color("#35665e")]   # bytes 1 to 8
static func food_year(game: Game, viewer: StringName, hex: Vector2i) -> Vector2i
	# (made, eaten) a year on the viewer's land: the grain and fish of EconomyPreview.worth_seasons(game, viewer, 4) for the
	# hex; eaten = its people now × food_need_milli × 4 / 1,000,000 (floored) for a settlement, else 0; (0, 0) elsewhere
static func food_band(net: int) -> int                      # 1 at or under -10, 2 for -9 to -1, 3 for 0, 4 to 8 by FOOD_FLOORS
static func food_bytes(game: Game, viewer: StringName) -> PackedByteArray   # cols x rows; 0 off the viewer's land; else
	# food_band(made − eaten) of food_year; cached [&"food", version, viewer]
static func food_ramp() -> PackedColorArray                 # 256: [0] clear, [1..8] FOOD_COLOURS, the rest clear
static func legend_title(mode: int) -> String               # "Yields: worth a year"; "Food: made less eaten, a year"; ""
# legend(FOOD): the bands top first ("40 and more", "20 to 39", "10 to 19", "5 to 9", "1 to 4", "Nothing", "Short by 1
#   to 9" (stripes), "Short by 10 or more" (stripes)), then "Not your land"
# colour_of(mode, owner_id, height_byte, palette, tint_on, hot_id, yield_byte := 0, food_byte := 0): FOOD as YIELDS with
#   food_byte (bytes 1 and 2 striped like Yields' loss)
# modes(game): adds FOOD where YIELDS is
```

---

## 6. The UI of M5

Built from the kit and the M3 to M4.5 pieces. Colours and fonts from the Theme; HUD controls take no focus, screens do.
The App's milestone value becomes `"5"` (D38).

### 6.1 Keys and settings

| Action (`Bindings.DEFAULTS`) | Key (Mac) | Since | Who hears it | Does |
|---|---|---|---|---|
| `view_mode_5` (**new**, label "Map mode 5", group View) | 5 | 5 | `MapInput` -> `mode_requested(MapModes.Mode.FOOD)` | the Food mode; refused with M4.5's toasts in a map-only game ("no countries on this map") and while picking ("choose your country first") |

| `Settings.SCHEMA` key | Change |
|---|---|
| `state/map_mode` (M2, M4.5) | choices gain `food` |

No other key or setting: the People page opens from the study (I, `[` `]`), the two chips and the report.

### 6.2 The chips (`shell/hud/chips.tscn/.gd`, M4, edit)

| Chip | Icon | Value | Change | Card | Click |
|---|---|---|---|---|---|
| **People** (`people`) | `people` | your people (`Words.number`) | the last season's (`people_end − people_start`), a `DeltaChip` | `PeopleCards.people` | the study at `{page: &"people"}` |
| **Food** (`food`) | `food` | grain and fish in store | their change over the last closed season (the card's first line in the bad tone when the towns went hungry) | `PeopleCards.food` | the study at `{page: &"people"}` |

Order in the top bar: Ducats, People, Food, Stores. Narrowing (M2 to M4's order kept and extended): Stores hides first, then
Food, then the country's long name, then People's name and change, then Ducats' name and change; the medals and values of
Ducats and People never hide. Refreshes on M4's signals and `season_ended`; hidden in a map-only game and during the pick.
Before a season has ended the changes read "No season has ended yet." in the card and the chip shows no `DeltaChip`.

### 6.3 The hover card and the hex panel

**Hover card** (`HexCard.of`): "People" (`PeopleView.at`'s text) on any land hex where `shown`; "Food" on your land when
the hex makes or eats food ("made 22, eaten 12 a year"), the number behind the Food mode's colour.

**Hex panel** (`shell/panels/hex_panel.tscn/.gd`, M1.5 to M4, edit): a **People** section after the owner row, on land:

- your land: rows "People 30,300 (▲ +300 last season)", "Room 45,000", and the outlook (`PeopleView.outlook`) in a
  `Body` line in its tone;
- a known country's land: "People about 30,000"; an unknown country's: no section; unowned land and the sandbox: the
  number alone.

`PeopleView.outlook(game, hex)` for the hex's owner:

| Case | Text | Tone |
|---|---|---|
| a settlement whose country went hungry last season (`food_fed` < 1,000) | "Hungry: it loses people each season until your towns are fed." | bad |
| level under `people_top_level`, `grow_check` would allow it at its room (rows 3, 6, 7 pass) | "Grows into a town at 4,000 people (in about 34 seasons)." (`seasons_to_full`) | good |
| level under `people_top_level`, a pair rule or a work nearby forbids it | "Stays a village: Cuneo (5, 13) is a town beside Savona: two towns may not stand side by side." (`ImproveRules.PAIR_WORDS` with `rule` and `other`; a work nearby: its words) | plain |
| a work under way on it | "A work is under way here." | plain |
| level 3, under its room | "Room for 9,700 more; walls would give room for 45,000." | plain |
| level 3, full | "Full at 20,000: walls would give it room (a work)." | warn |
| level 4, under / full | "Room for 14,700 more; a city would give room for 100,000." / "Full at 45,000: a city would give it room (a work)." | plain / warn |
| level 5, under / full | "Room for 39,700 more." / "Full: a city holds no more." | plain |
| other land under its room | "Room for 2,000 more: about 80 come each season." (`change_at` for this season, fed) | plain |
| other land full | "Full: the land holds 8,000." | plain |
| other land over its room | "Crowded: about 200 leave each season." | warn |
| room 0 | "No one lives here." | plain |

Refreshes on M4's signals, `town_grew` and `district_declined` (when it shows that hex).

### 6.4 The country panel (`shell/panels/country_panel.tscn/.gd`, M2, M4, edit)

A row "People" in the ledger rows after Towns, from `CountryCard.of(game, tag).people`: yours "83,285 (▲ +585 last season)";
a known country's "about 260,000"; an unknown country: no row. Refreshes on `season_ended`.

### 6.5 The Food mode on the map

- **`ModeOverlay`** (`shell/map/mode_overlay.gd` + `.gdshader`, M2, M4.5, edits): a seventh texture `food` (R8, cols x rows)
  and an eighth `food_ramp` (RGBA8 256 x 1, `MapModes.food_ramp()`); uniform `food_alpha`; mode 4 picks the colour as
  `MapModes.colour_of` does, bytes 1 and 2 striped like Yields' loss (the veil between the stripes), byte 0 the veil. It
  reads no screen texture. `func update_food(bytes: PackedByteArray) -> int` (writes the texels that differ, one texture
  update; returns how many) and `func food_bytes() -> PackedByteArray` (its copy, for tests; as M4.5's `yields_bytes`).
- **`MapScene`** (`shell/map/map_scene.gd`, edit): `set_mode(FOOD)` calls `update_food(MapModes.food_bytes(game, player))`
  first; while the mode is Food, `season_ended`, the three work signals, `tax_set`, `owners_changed`, `game_started`,
  `town_grew` and `district_declined` call it again when `game.version` changed. The mode switch writes `state/map_mode`.
- **`MapInput`** (`shell/input/map_input.gd`, edit): `view_mode_5` emits `mode_requested(MapModes.Mode.FOOD)`.
- **The top bar** (`shell/hud/top_bar.gd`, edit): the mode `Segmented` lists `MapModes.modes(game)` with the names Terrain,
  Owner, Relief, Yields, Food and the tooltip "Food (5)".
- **`ModeLegend`** (`shell/hud/mode_legend.gd`, M4.5, edit): the title from `MapModes.legend_title(mode)`; rows from
  `MapModes.legend(FOOD)`, the deficit swatches with `InkMarks.fill_rect`'s `hatch` in madder.
- **The minimap** draws the same overlay material: Food shows there with no code change.
- **The hover card's Food line** gives the number.

### 6.6 The People page (`shell/screens/study/page_people.tscn/.gd`, new)

`class_name PagePeople extends StudyPage` (no tabs; `page_id` `&"people"`). `StudyPages.LIST` gains
`{id = &"people", title = "People", scene = "res://shell/screens/study/page_people.tscn", since = "5"}` after Economy, so the
nav reads Economy, People, Rankings, History.

```
+==================[ THE STATESMAN'S STUDY ]============== Summer 1480 ==[Close I]=+
| Economy     | 83,285 people: 40,400 in towns, 42,885 in the countryside;        |
| PEOPLE   <  | room for 32,415 more. Expected this season ▲ +589        12 | 40 |
| Rankings    | TOWNS                                  | FOOD                       |
| History     | Place      What        People  Room  Last season  Outlook | Fed: 8 made for 4 eaten... |
|             | Genoa (8,13) walled town 30,300 45,000 ▲ +300 Room for...  | [chart: made, eaten, need] |
|             | Savona (6,13) town      10,100 20,000 ▲ +100 Room for...  | GROWTH AND LOSSES          |
|             | The countryside: 12 places, 42,885 of 50,700, ▲ +185  | [chart: grew / starved, left]|
|             | [Look there] [Show on the map]                          |                            |
+=================================================================================+
```

| Part | Built from | Reads |
|---|---|---|
| Head | a `Hint` line ("83,285 people: 40,400 in towns, 42,885 in the countryside; room for 32,415 more."), a `DeltaChip` "Expected this season" (`head.expected`), a span `Segmented` "12 seasons \| 40 seasons" writing `state/study_span` | `StudyPeople.of` |
| Towns | `SectionHead` "Towns"; a `StudyTable` (columns below), sorted by People, highest first; a `Body` countryside line ("The countryside: 12 places, 42,885 people of 50,700 room, ▲ +185 last season."); `KitButton`s **Look there** (the selected row; Enter does the same) and **Show on the map** (the Food mode, gliding to the selected row) | `rows`, `countryside` |
| Food | `SectionHead` "Food"; a `Body` line (`food.text`, then " Lasts " + `lasts_text`); a `PanelVellumInset` with an `InkChart` `LINE` "Food, a season": Made (`ink_0`, solid), Eaten (`ink_1`, dash), The towns' need (`ink_2`, dotted), legend on | `food`, `series` |
| Growth | a `PanelVellumInset` with an `InkChart` `STACKED_BAR` "Growth and losses, a season": in Grew (`ink_3`); out Starved (`ink_2`), Left (`ink_4`); legend on | `series` |

| Column (id) | Kind | Content |
|---|---|---|
| Place (`place`) | text, expands | `Words.settlement` |
| What (`what`) | text | the level word ("walled town", "village"); " · port" for a port; " · under way: to city" with a work |
| People (`people`) | number | the people now |
| Room (`room`) | number | its room |
| Last season (`change`) | delta | `people_end − people_start` |
| Outlook (`outlook`) | text | `PeopleView.outlook`'s text, in its tone |

The page hears its table's `row_selected` (Look there and Show on the map take that row) and `row_activated` (look there),
and sends `[&"look_at", hex]` and `[&"map_mode", &"food", hex]` (M4.5's study actions). Before a season has ended the head
shows the people and room, the table its rows with no change, the food line "No season has ended yet." and the charts "No
data yet". Built on first open,
refreshed on `season_ended` or a newer `game.version`. At 1280 x 720 the two columns fit; the Food column stacks under the
table below 1,100 px of page width.

### 6.7 Rankings, Standing, History, Economy's tax hover

- **Rankings** (`StudyRankings`, `PageRankings`, M4.5): the third measure **People** ("People"; yours exact "83,285", others
  "about 260,000"); its line chart over the span with rank marks, as land and income. M4.5's layout puts a third measure
  on a second row and the page scrolls (M4.5 6.5); M5's test pins it at 1280 x 720.
- **Standing** (`SeasonSummary`, M4): adds people (4.11 b). Rankings equals Standing every season (M4.5 done-when 5).
- **History** (`StudyHistory`, `PageHistory`, M4.5): marks `declined` (bad) and `grew` (good) with the `settlement` icon, in
  the priority of 5.6; the season line adds " · people 83,285" (a ring row's `people`).
- **The tax hover** (`StudyEconomy.this_season` tax options, M4): the note adds the people: "High: ▲ +38 a season; districts
  ▼ −10 %; people grow 0.5 % a season, not 1 %." / "Low: ... people grow 1.25 % a season." (from `growth_bp`).

### 6.8 The report, task flag, notifications, log, ribbons

- **The season report** (M3's screen): draws the People section of 4.15 (it draws all nine sections since M3); a place line
  is a link (`look_at`); the level and food lines are `sub`.
- **Task flag** (M3, M4): 4.14's lines; `hunger`'s action opens the study at People (M4's `study` action).
- **Notifications** (M3): the player's `town_grew` (good, Go: the town) and `district_declined` (bad).
- **Log** (M3, M4.5): the lines of 4.17; older headers open History (M4.5).
- **Growth ribbons** (the floaters, `shell/map/floaters.gd`, M3, edit): a public `func add_ribbon(hex: Vector2i, text: String,
  tone: StringName) -> void` that M3's chronicled path now calls with each line's `floating` word; after `season_ended` the
  map scene adds `PeopleView.ribbons(game, player)` through it. M3's limits hold (3 a hex, 16 in all, only hexes on screen
  and not under the dock, waiting under the report); reduce motion: a fade in place.

### 6.9 Map labels follow the level (`shell/mapview/map_labels.gd`, M1, M2, edit)

`func set_state(state: MapState) -> void`: the level of a place on a settlement hex (`main_use` 1) comes from `state.level`;
other places keep `MapData.places[].level`. The map scene calls `set_state(game.state)` on `game_started`, and `refresh()` on
a `hex_changed` of a hex that holds a place. A town that grew gets the town's plate and font size (`font_size(3)` 13 px).

### 6.10 The App, `StudyWarm`, F3, the console

| Request or event | The App (`shell/app/game_requests.gd`, `app.gd`) |
|---|---|
| `ResourceChips.chip_pressed(&"people")`, `(&"food")` | the study at `{page: &"people"}` |
| `MapInput.mode_requested(FOOD)`, the top bar's switch | as M4.5: a mode not in `MapModes.modes(game)` toasts; else `set_mode`, then `ModeLegend.show_mode` |
| `Events.season_ended`, `game_started` | `StudyWarm.queue_views()` (which now adds `StudyPeople.of(span)` and, in Food mode, `MapModes.food_bytes`) |

- **F3** (`shell/hud/debug_overlay.gd`, edit): a line "people 1.8 ms · grew 2 · declined 0 · hungry countries 1".
- **Console** (`shell/hud/dev_commands.gd`, M3, M4, edit): `people c r N` (`Session.dev_people(hex, N)`); the problems it
  prints: "no such hex", "N must be a whole number of 0 or more", "no one keeps people there" (sea, unowned land), "the
  sandbox has no countries"; each is a planted fault in its test.
- The App sets the milestone `"5"`.

---

## 7. Data and the editor

| File | Holds | Made by | Checked by |
|---|---|---|---|
| `godot/data/defs/game_defs.tres` (M2 to M4, edit) | the eight people fields of 5.1 with the values of 4.4 | by hand in the inspector (task P1) | `tests/core/test_economy_defs.gd`: `GameDefs.validate()` and the values of 4.4 |
| `godot/data/defs/families/settlements.tres` (M3, M4, edit) | `room` 0, 2000, 4000, 20000, 45000, 100000; `falls_below` 0, 0, 1000, 2000, 0, 0; `cost` levels 2 and 3 → 60, 200; `cost_goods` unchanged | by hand (P1) | `tests/core/test_family_defs.gd`: the values of 4.5 and 4.6 |
| `godot/tools/economy_tables.gd` (M4, edit) | prints 4.4's rates and 4.5's settlement table as Markdown from the `.tres` | P1 | `test_economy_defs.gd` runs it and compares one row of each |
| `godot/data/README.md` (edit) | the people fields of `GameDefs` and the settlement columns | P1 | |

The Food mode's bands, colours and alpha are `MapModes` constants (M4.5 D22's rule: presentation, not rules), printed in 5.6
and pinned by `tests/core/test_map_modes.gd`. No texture, token or Theme variation is added, so `bake_ui.py --check` and
`build_theme.gd --check` pass unchanged; the map file and the scenario are unchanged (`build_map --check`,
`build_scenario --check`).

---

## 8. Speed

`godot/tools/perf_core.gd` (M3 to M4.5) on the made-up Europe: M3's and M4's rows keep their own 8-season game (now with the
people phase in it); the M4.5 and M5 view rows use `PerfFixture.europe_game(40)` and its largest country. Rows in
`godot/tests/perf_core_budget.json`, nightly, never in GUT:

| Row | Limit | What |
|---|---|---|
| `season_ms` | **190** (M4: 150) | the six phases, worst of 8 seasons |
| `production_ms` | **70** (M4: 60) | the production phase (staffing now live for goods districts) |
| `people_ms` | 30 | the people phase over every owned land hex, 60 countries |
| `stats_phase_ms` | 60 (M3) | the stats phase with 40 series and `People.close` |
| `reminders_ms` | **6** (M4: 4) | `Reminders.unfinished`, uncached (the eight-season run steps the people) |
| `expected_ms` | 2 (M4) | `EconomyPreview.expected`, uncached, with its people step |
| `preview_ms` | 1 (M4) | one `ImprovePreview.of` (the option's people step: settlements and the changed ring) |
| `study_people_ms` | 6 | `StudyPeople.of(game, tag, 40)`, uncached |
| `food_bytes_ms` | 14 | `MapModes.food_bytes` (`worth_seasons` cold, then 122,018 bytes) |
| `save_mb` | 8 (M3) | the `.sav` file with the three people arrays |

`godot/tools/ui/perf_ui.gd` (M1.5 to M4.5) gains in `perf_ui_budget.json`: `people_page_open_ms` 16 (north Italy after 40
seasons, cold); `food_mode_ms` 16 (key 5 to the first Food frame); `chips_refresh_ms` 1 (four chips). North Italy for scale:
340 land hexes, 13 countries: the people phase takes well under a millisecond.

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (P).

| File | Cases |
|---|---|
| `tests/core/people_fixture.gd` (**new**) | `PeopleFixture.genoa(defs)`, `still(defs)` (growth_bp 0, 0, 0; hunger_bp 0; left_bp 0), `always_fed(defs)` (`food_need_milli` 0), `no_food(defs)` (settlements' `port_fish` 0; farmland and grassland `wild_yield` 0); each a deep copy, the base defs untouched |
| `tests/core/test_economy_defs.gd`, `test_family_defs.gd` (M3, M4, edit) | the values of 4.4, 4.5, 4.6; `economy_tables.gd`'s people rows; P: growth_percent of 5 entries, hunger_bp −1, people_top_level 6, a room under the start people, a falls_below not under the lower level's room, a falls_below above `people_top_level` |
| `tests/core/test_map_data.gd`, `test_country_state.gd`, `test_state_view.gd` (edits) | `map-state/4` round trip with the three arrays; schema 3 loads with zeros; the digest moves with one person; P: a string in `people` makes `from_dict` return null; `country/3` round trip and `digest_text`; `country/2` loads with zeros; `people_at` and `with_people` (the base untouched, other changes kept) |
| `tests/core/test_stats.gd` (M3, M4.5, edit) | 40 series, the five appended last; the M5 values after a played season; a dict without them loads them as zeros; the projected size at Winter 1650 for 60 countries under 2.5 MB |
| `tests/core/test_world_improve.gd` (M1, edit) | `lower_check` and `lower` (P each refusal); `Improve.lower_check` with no hex (P) and `Improve.lower`'s one `hex_changed`; the distances after a lower (a stage-3 neighbour's `town_distance` grows) |
| `tests/core/test_people.gd` (**new**) | `start_people` and `room_at` for every level, cover and stage; `setup` equals M4 4.12's people per country; `change_at`: growth by each slot and tax, the cap at room, hunger at fed 0, 400 and 999, the winter shares, `town_floor`, crowding, the countryside never starving, room 0; `move` (P: off the map, sea, an unknown why, a result below 0, unowned land, a map-only game; each changes nothing); `fed_of`; the levy seam: `available`, every row of `levy_check` with its words (P each), `levy` moves `raised`, `give_back` moves `returned` and a crowd leaves next season |
| `tests/core/test_people_checks.gd` (**new**) | every row of `grow_check` and `decline_check` with its words on views (P each: a work under way, Savona beside Cuneo (pair rule 0), a pending work nearby, not fed, not full, a walled town, a hamlet, a dye works that needs the town); a view's change is read (a what-if town beside blocks growth) |
| `tests/core/test_economy.gd`, `test_district_cache.gd` (M4, edit) | `people_at` reads the view; hands and jobs count the owner's hexes only (P: a foreign neighbour's people and jobs do not count); `district_base`'s new keys; `district_output == season_output(district_base)` on every land hex of north Italy at turn 1 and after 10 seasons; the cache's 14 fields; staffing follows the people without a touch (P: a cache that keeps staffing across a season is caught) |
| `tests/core/test_no_other_writers.gd` (M4, edit) | adds `.people[`, `people_start`, `people_end`, `.people_flows`, `.people_closed`, `.food_need`, `.food_fed` assignments outside `people.gd` and the state classes' `create`, `duplicate_state`, `from_dict`; P: a planted file in `user://` is caught |
| `tests/core/test_season.gd` (M3, M4, edit) | **`PHASES` is `[production, income, works, people, stats, calendar]`** (the pin); a paid town upgrade finishing in season T gives its room in T's people phase |
| `tests/core/test_people_season.gd` (**new**) | 4.11 (d): Alba and Moûtiers grow into towns at turn 34 and not before, Cesena at turn 30, each with one `town_grew` and one `hex_changed`, and the piece cells of `MapCells.of_hex` become level 3; Lucca stays a village with its outlook; 4.11 (e): Savona falls at turn 2 with its event (P: the dye works at (7, 12) keeps it a town, no event); a walled town at 200 people stays walled; a village under 1,000 becomes a hamlet and grows back into a village at 2,000; the starved town never goes under 200 |
| `tests/core/test_people_genoa.gd` (**new**) | 4.11 (a) exactly (people, towns, need, fed, every money line, treasury 1,067) |
| `tests/core/test_people_growth.gd` (**new**) | **done-when 1**: the fed and starved runs of 4.12 inside their ranges, their hungry seasons; the worked values printed in the test log |
| `tests/core/test_people_property.gd` (**new**) | **done-when 2 and 3**: 40 seasons, seeded random works, cancels, taxes and `dev_people` for every country, weather drawn: per hex and per country the change equals the closed flows; the world's change equals their sum; no hex below 0; no growth past the room; every level change has its event or a `work_finished`; every `town_grew` was full and fed, every `district_declined` under its floor; food eaten never over the need; fed exactly when eaten equals the need; `Stats` food series equal the flows and `food_need` |
| `tests/core/test_economy_genoa.gd`, `test_economy_1480.gd`, `economy_fixture.gd` (M4, edit); `insights_fixture.gd` (M4.5, edit) | built on `PeopleFixture.still`: every M4 and M4.5 number unchanged |
| `tests/core/test_insights_views.gd` (M4.5, edit) | the pins of 4.13 of M4.5 move to M5's values: `PHASES` (six), `SaveFile.FORMAT` 3, 40 series, nine notable kinds; the rest as M4.5 |
| `tests/core/test_economy_preview.gd` (M4, M4.5, edit) | `with(game, tag, {}, 8)` equals eight played seasons for every country with people growing (people, towns, fed, flows, money lines); a village filling its room inside the window levels up in the preview the season it does in play; the stepped hexes are the settlements and the non-full others |
| `tests/core/test_improve_preview.gd` (M4, edit) | the 200-case property with the real (growing) defs; 4.11 (c) exactly; the room line and the people note for a village and a town; M4's (c) and (e) on `PeopleFixture.still` |
| `tests/core/test_snapshot.gd`, `test_save_file.gd` (M3, M4, edit) | M5 fields round-trip; save, load, save byte-equal; `FORMAT` 3; P: a format-2 header reads `older`; a string for `food_need` is refused; `people` of the wrong size is refused |
| `tests/core/test_replay.gd` (M3, M4, edit) | 20 seasons with growth, a level change and `dev_people`: the same digest; P: a changed `dev_people` value gives another |
| `tests/core/test_owns.gd` (M3, M4, edit) | 5.3's table for every action and phase; P: a test-only phase writing `people` directly is reported |
| `tests/core/test_game_core.gd`, `test_forty_seasons.gd`, `test_improve_actions.gd` (edits) | `dev_people` and its record; People before Treasury in `new_scenario`; every season of the 40: the people invariants of done-when 2; the 2,000-action property with the people phase in the season ends |
| `tests/core/test_chronicle.gd`, `test_log_lines.gd`, `test_words.gd` (edits) | `NOTABLE` holds the two kinds; their sentences for the player, a known other and an unknown one (P: never witnessed); `Words.settlement`, `Words.people` |
| `tests/core/test_people_view.gd`, `test_cards_people.gd`, `test_study_people.gd` (**new**) | every outlook row with its words; `at` for yours, known (banded), unknown (P: not shown), unowned, sea; `seasons_to_full` is 34 for the village near Turin (6, 11) at turn 1, 0 for a full hex, −1 on `PeopleFixture.still` (no growth); `ribbons` (1 % and hunger); the two cards' lines sum to the chip's change; the page's view equals 4.11 (a)'s Summer 1480 numbers on the first-year game and its series equal `Stats` |
| `tests/core/test_hex_card.gd`, `test_country_card.gd` (edits) | the People and Food lines; the country's people (yours, known banded, unknown none) |
| `tests/core/test_reminders.gd`, `test_season_summary.gd` (M3, M4, edit) | `hunger` and `town_full` with their words and order (P: a full village makes no `town_full` line); 4.11 (b)'s section on the fixture; **the lines sum to the total every season of a 40-season run** (done-when 4) and the food line's numbers equal the closed flows and `food_need` (done-when 3); the food line's three forms; quiet; the glance chip; Standing with people; equal after a save and load |
| `tests/core/test_study_economy.gd` (M4, M4.5, edit) | the tax options' notes name the people's growth at each level (6.7); everything else unchanged |
| `tests/core/test_study_rankings.gd`, `test_study_history.gd` (M4.5, edit) | the people measure (banded, P: an unknown country absent); Rankings equals Standing with people every season of 40; the two marks and their priority; the season line's people |
| `tests/core/test_map_modes.gd` (M2, M4.5, edit) | `food_band` at −11, −10, −9, −1, 0, 1, 4, 5, 9, 10, 19, 20, 39, 40; `food_ramp`; `worst_delta_e` of neighbouring bytes 3 to 8 at least 6, the veil against every byte at least 15, byte 1 against every other at least 15, bytes 1 and 2 against byte 3 at least 15; `colour_of` in FOOD; `food_year` for Genoa (22, 12) and Savona (6, 4); 4.11 (f)'s bytes (P: a Milan hex is 0); `modes`, `mode_of(&"food")`, `legend(FOOD)`, `legend_title` |
| `tests/shell/test_session.gd` (edit) | the two signals drained after the people phase, then `chronicled`; `dev_people` logs and drains; `last_phase_ms` has people |
| `tests/shell/test_floaters.gd`, `test_map_labels.gd` (M3, M1, edit) | `add_ribbon` within M3's limits; the chronicled path through it; a label's size follows `state.level` for a settlement and the data's level otherwise |
| `tests/shell/test_mode_overlay.gd`, `test_map_scene.gd`, `test_map_input.gd`, `test_bindings.gd`, `test_settings.gd`, `test_mode_legend.gd` (edits) | the two food textures; `update_food` writes only changed texels (P: one byte, one texel); key 5 to Food; updates only while in Food; the restored `food` mode; `view_mode_5` with key 5 since "5"; `state/map_mode` accepts `food` (P: a bad value falls back); the Food legend and title; a `town_grew` repaints exactly `MapCells.touched_by` and refreshes the labels; the season's ribbons |
| `tests/shell/test_resource_chips.gd`, `test_hex_panel.gd`, `test_country_panel.gd` (M4, edit) | the People and Food chips, cards, clicks, the narrowing order; the People section and every outlook row's tone; the country's people row |
| `tests/shell/test_page_people.gd`, `test_study.gd`, `test_page_rankings.gd` (**new**, edits) | the page's parts from the first-year game; Look there and Show on the map; the span; before a season; the digest unchanged by the page; four pages in the nav; Rankings' third measure on its second row at 1280 x 720 |
| `tests/shell/test_season_report.gd`, `test_task_flag.gd`, `test_notifications.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_study_warm.gd`, `test_hud.gd`, `test_app_flow.gd` (edits) | the People section drawn from real data; the hunger line opens People; the two notifications; `people c r N` and its planted faults; the F3 line; the warmer's people view; the top bar's five segments and chip order; end to end: New game as Genoa, the chips, key 5, a season's People section and ribbons, `people 6 11 3990` and a town on the map, the People page, a save and load |
| `tests/shell/test_ui_monkey.gd` (edit) | adds 5, clicks on the People and Food chips and the page's rows; invariants: the digest unchanged by the page, the chips' cards and the Food mode |
| `godot/tools/map/probe_mode_overlay.gd` (M2, M4.5, edit; windowed, CI under xvfb) | Food: the pixel at every hex middle equals `colour_at` (tolerance 3); P: `--plant` swaps two food ramp entries and prints FAIL |
| Pictures (`godot/tools/ui/shot_ui.gd`, edit) | the top bar with the four chips and the People card; the hover card on Genoa; the hex panel's People section for Genoa and for Savona fallen to a village; the Food mode on north Italy with its legend; the People page; Rankings with three measures; the report's People section; the village near Turin before and after it grew (zoom 1). At 1280 x 720 scale 1 and 2560 x 1440 scale 2; signed by the art director, then goldens `godot/tests/goldens/m5_*.png` (0.5 %) |

**Determinism:** `test_replay`, `test_forty_seasons`, `test_people_property`, `test_improve_actions` (M5 draws no luck; the
people rules are integer and walk countries by id and hexes by index). **Save round trip:** `test_snapshot`,
`test_save_file`, `test_forty_seasons`, `test_season_summary` (J after a load).

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| Many countries go hungry within a few years (their towns grow, nobody builds food until M8) and the AI's towns shrink on the map | `godot/tools/economy_report.gd` (M4, edited in P17) prints, for seeds 1480 to 1484 and 40 calm seasons, each country's people, towns, hungry seasons, levels gained and lost; Opus reads it before group E starts | The rule is decided now: if more than 3 of the 10 playable countries are hungry in more than 10 of the 40 seasons, `growth_bp` goes from 125, 100, 50 to 100, 75, 25 (data; it slows the rise of the towns' need without touching M4's numbers, whose start balance M4's own report settled) and the report runs again; 4.4's season table, 4.11 (a) and (d) and 4.12 are worked out again and their tests edited in the same pull request |
| Growth feels too fast or too slow to the owner | the playtest's 40 seasons (plan, step 14) | `growth_bp` (data) |
| The people phase over its budget on Europe | `perf_core` on P5's first week, before the UI builds on it | the phase walks each country's settlements and a list of its non-full hexes kept per version (as the preview does) instead of every owned hex |
| The preview drifts from the season with people growing | the 200-case property and `with(…, 8)` in P7's first week | one code path (built in); drop the delta method for a full country run (slower; `preview_ms` 1 → 3) |
| A foreign town growing beside your full village inside a preview's window (D26) | expected rare; `test_economy_preview` documents the case | none needed: the card is a forecast "at today's map"; the season decides |
| Villages of one country and climate all grow into towns in the same season (they start at 3,000 alike) | the economy report's levels column; the owner's playtest | per-place start people from a hash of the hex (±10 %, data, no luck): an M4 table change, so only if the owner asks |
| Savona, once fallen, can never be a town again beside Cuneo (a fixed conflict of the data) | the outlook says why; the playtest step 9 | none: the rule is the map's |
| Save size with three per-hex arrays on Europe | `save_mb` nightly | `people_start` kept only for settlement hexes (a dictionary) |
| The Food chip duplicates the Stores card | the owner's playtest | hide the Food chip by default (a setting row) |
| M4 or M4.5 tests forget `PeopleFixture.still` and fail on numbers | P5 edits every one in its pull request; CI | none needed |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 9.2: the M5 row points at this spec and its plan, status "specified and planned, waits for the owner's go; starts after M4.5 closes"; the last row reads M6 to M12 |
| `docs/architecture/m4-build-spec.md` | D6, D10, D42 and 4.3: a note that M5 makes people grow (room, hunger, the re-tuned settlement costs, hands and jobs of the owner's hexes); 4.15 (d): a line that M5's 4.11 (c) replaces it; 12, row M5: points here |
| `docs/architecture/m4-build-plan.md` | Section 7, the M5 bullet: points here |
| `docs/architecture/m4-5-build-spec.md` | 4.13: a note that M5 moves the pins (six phases, `FORMAT` 3, 40 series, nine notable kinds) and that `InsightsFixture` runs on still people from M5; 12, row M5: points here |
| `docs/architecture/m3-build-spec.md` | 4.6: a note that M5 appends five series; 12, row M5: points here |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M5: the Food map mode (key 5), the files and the tasks of `m5-build-plan.md` |
| `docs/architecture/ui-and-controls-spec.md` | 2, the map-modes row adds 5 (food); 4.1, the `view_mode` row: 5 Food (M5); 7, the top bar row adds M5's People and Food chips, the switcher row adds Food (M5, key 5) |
| `docs/architecture/ui-style-and-feedback-plan.md` | S5, row M5: folded into `m5-build-plan.md` |
| `docs/architecture/ui-style-and-feedback-spec.md` | Section 8: a note that M5's People page, the people measure and the Food mode are specified in `m5-build-spec.md` |
| `docs/design/ui/game-feedback-screens.md` | A.3, B.5 and C.3: a line that the People section, Genoa's city card and the tax hover's people are replaced by `m5-build-spec.md` 4.11 and 6.7 |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `godot/README.md` (key 5, the People page, the console's `people`; P16),
`godot/data/README.md` (P1). No port rule changes: no new autoload, no new layer; `tools/lint_godot.py` needs no entry (new
files sit in listed folders, each under 800 lines); `CLAUDE.md` gains no command (the report and perf tools exist).

---

## 12. What M5 hands to later milestones

| M | Takes from M5 | M5 leaves for it |
|---|---|---|
| M6 | **`People.available`, `levy_check`, `levy`, `give_back`** and the flows `raised`, `returned` (4.20); people for supply (v0.2.2's `SUPPLY_PER_PEOPLE`: a hex's people feed armies passing); foraging as a flow appended to `People.FLOWS`; the army's food as a need beside the towns' in `EconomySeason.needs_of` (`People.fed_of` stays the towns' share); Supply on key 6; all taken up in `m6-build-spec.md` | Recruits, foraging, armies' food |
| M7 | `district_declined` with `why` `sacked`; captured hexes keep their people (D12); refugees (a flow) if M7 wants them; a besieged town eats its stores; taken up in `m7-build-spec.md` 4.11 (no district falls a level by war: a sack kills people, flow `sacked`; garrisons levy people, flow `garrisoned`; no refugees; a besieged town starves once the siege's stores are out) | War's toll on people |
| M8 | The AI reads `PeopleView`, `StudyPeople`, `MapModes.food_bytes` and the `hunger` and `town_full` reminders; it builds food when hungry and walls when full; the soak checks the conservation property and the `Stats` budget; taken up in `m8-build-spec.md` 4.7 and 4.17 (it reads the reminders, not the people views) | The AI |
| M9 | Peace terms move land with its people (`Territory.transfer`, D12): taken up in `m9-build-spec.md` (people stay on a ceded hex, booked on its new owner from the transfer; no levy in a rising region part) | Diplomacy |
| M10 | Buying food from markets (D20); the food need in market demand; prices of grain and fish by supply; the Trade mode on key 8; **taken up in `m10-build-spec.md`** 4.5 and 4.6 (the reserve bought at the home market, the food need in each market's appetite) | Trade |
| M11 | Techs change `growth_bp`, `hunger_bp`, rooms and jobs through definitions only; **taken up in `m11-build-spec.md`** 4.2 and 4.14 (`growth_bp`, the settlements' room and `levy_permille`; no tech of the approved tree changes hunger or jobs: their keys join the registry when one does) | Research |
| M12 | Score with people (v0.2.2: people / 20); plague and famine as event pop-ups (flows appended); countries that fall when their people do | A whole game |
| **E2** | **Nothing blocking: people are a per-hex array sized by the map; the phase walks owned land; the Europe budgets are measured on the made-up Europe.** | |
