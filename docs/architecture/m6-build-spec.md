# M6 build spec: Armies

Game and systems designer (Opus), 2026-11-17. **Status: a proposal, design only; it waits for the owner's go.** Builds
milestone M6 of `docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`), the
M1.5 UI foundation (`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`), and the M2, M3, M4, M4.5 and M5 specs and
plans (`m2-build-*.md`, `m3-build-*.md`, `m4-build-*.md`, `m4-5-build-*.md`, `m5-build-*.md`). Where this page is more
exact it wins for M6; section 1.2 lists every place where it refines an earlier page. The tasks are in `m6-build-plan.md`.
This page carries the M6 row of `ui-style-and-feedback-plan.md` S5 (the Military page; "What befell" with real
witnesses; raised and marched in "Your orders"; `REPLAY` before the report; the Supply mode).

**What M6 is.** The map gets armies. A country raises **companies** (pikemen, crossbowmen, knights, bombards) in its
towns and villages, paying ducats and goods and taking the men from its people through M5's levy. Companies stand together
as **armies** on the map. During a season the player gives each army an **order** (march to a hex, or hold); every army
walks its march in the season's **movement** phase, as far as its move points carry it over the ground, the roads, the
river crossings and the passes, and the player watches the walks in a **replay** before the season's report. Snow closes
the high passes in winter. An army near a town of its country is **in supply** and eats from the stores; beyond reach it
lives off the land, and where the land feeds no one (the snowfields) it **starves** and loses men. Armies cost upkeep
every season. Each country now **sees** its own land, the ring around it and what its armies see; events far off are no
longer known to all, so the report's "What befell" holds what you witnessed. Foreign land stays closed to armies until war
(M7). The player sees it all: army tokens with their strength, right-click orders with the route and its season stops,
the reach of the season, a move card, the army panel, the Raise tab, the movement replay and its speed option, the hex
right-click menu, the Supply mode (key 6), the Army chip, the study's Military page, men under arms in Rankings and the
report's Armies section, and the reminders for idle and hungry armies.

**When it starts.** After M5 is closed (its plan's definition of done, and the owner has played it). M6 edits `Game`,
`Session`, `Events`, the action and season tables, `Country`, `Stats`, `StatsSystem`, `EconomySeason`, `Treasury`, `Stores`,
`People`, `Knowledge`, the previews, the report's view, the reminders, the log lines, the study's views and pages, the map
modes, the mode overlay, the map scene, the floaters, the season flow, the chips, the hex and country panels, the top bar,
the input and the App, and builds its screens into the M1.5 frame as M5 left it.

**M6 is done when:**

1. **Raise an army.** On "Italy, 1480", seed 1480, as Savoy: two companies of pikemen raised at Turin (5, 9) in Spring
   1480 cost 50 ducats and 2 iron (one `raise` ledger line at Turin, one `raise` flow), take 1,000 people from Turin
   (People flow `raised`), form the Army of Turin of 1,000 men, and pay 12 ducats of upkeep in that season's income phase
   (`tests/core/test_army_savoy.gd`).
2. **March it across the Po and a pass.** The same army, ordered to Vercelli (6, 9) in Spring, musters in Spring and walks
   in Summer's movement phase across the Po on the wooden bridge (2 move points); ordered on in Autumn to (3, 8) beyond the
   crest (15 move points by Turin, Aosta's valley and the Little St Bernard), it walks to the saddle (3, 7) in Autumn,
   waits there for spring in Winter (the pass edge is closed by snow) and crosses the pass edge into (3, 8) in Spring 1481
   (section 4.13); the replay plays each walk. The test pins every hex and season; `unit_moved` carries the paths.
3. **It starves out of supply.** Ordered to the Mont Cenis saddle (3, 9) (snow cover, 3,320 m, no depot within reach), the
   army stands out of supply, the land there feeds no one, and it loses a tenth of its men each season (a fifth in a snow
   winter); `army_starved` is emitted, the report's Armies section, a notification and a ribbon say so; in Winter the
   saddle's three pass edges are closed while the way back to Susa (4, 9) stays open (the same test).
4. **Men are conserved.** `tests/core/test_men_property.gd` plays 40 seasons of the 1480 scenario with seeded random
   actions for every country (raises, marches, halts, splits, merges, disbands, works, taxes) and weather drawn, and finds,
   every season and every country: the change of its people plus the change of its men under arms equals grew − starved −
   left + dev − foraged − men lost by armies; every raise and refill moved exactly as many people into men, every disband
   the reverse; no army or unit below zero; no store below zero; supplied armies never ate more than their need.
5. **Every action keeps its check.** `tests/core/test_check_contract.gd` drives the seeded random player
   (`tests/core/random_player.gd`) over every action of the table, M1's to M6's, 3,000 actions with 40 season ends: when
   the check says no, the action returns not ok and `Game.digest()` is unchanged; when it says yes, the action succeeds.
6. **The move budget holds.** In the same runs no army spends more move points in a season than its slowest unit has,
   crosses a crest or a closed pass, steps into land not open to it, shares a hex with another country's army, or ends a
   movement phase with more than 8 companies of its country on its hex (`test_men_property.gd` checks each walk).
7. **Determinism and saves.** Same seed and same action log give the same digest after 40 seasons with armies
   (`test_replay.gd`); save, load, save gives byte-equal files with armies, routes and explored hexes in them; ten seasons
   after a load give the same digest as ten without (`test_forty_seasons.gd`); `SaveFile.FORMAT` is 4 and an M5 save reads
   as "Made by an older test build".
8. **Season time in budget.** On the made-up Europe (494 x 247 hexes, 60 countries, 600 armies with march orders) the
   CPU rows of section 8 hold in the nightly `perf_core.gd` run: a season's ten phases under 320 ms; the movement phase
   under 25 ms; one march order's route under 2 ms on average and 8 ms at worst; the reach preview under 2 ms.
9. Every M6 UI row of the standard's 9.1 is in the game, built from the M1.5 kit, each with its GUT test: army tokens and
   their selection; right-click orders; the reach and the route with its season stops on the map; the move card; the army
   panel; the Raise tab; Tab, R, the hex cursor (Alt/Option+arrows) and O; the movement replay and its speed option; the
   hex right-click menu when no army is selected; the Supply mode (key 6) with its legend and the sight veil; the Army chip;
   the Military page; men under arms in Rankings and Standing; the report's Armies section, "What befell" with real
   witnesses and raised and marched in "Your orders"; `REPLAY` before the report; the reminders for idle and hungry armies.
   No stand-in is left.
10. Lint, import, check_scripts and GUT are green, with both UI `--check`s, `build_map --check` and
    `build_scenario.gd --check`; the art director has signed the token sheet and the pictures of section 9; the owner has
    played the build through the plan's checklist.

---

## 1. What is there, and where this page refines earlier pages

### 1.1 Read in the code (master `a48b08e`), the map data and the specs

| Finding | Where | What it means for M6 |
|---|---|---|
| `Bindings.DEFAULTS` already lists `game_next_unit` (Tab), `game_continue_march` (R) and `map_cursor_left/right/up/down` (Alt+arrows), all `since: "6"`; there is no `view_mode_5` or `view_mode_6` yet (M5 adds 5) | `shell/input/bindings.gd` | M6 adds `view_mode_6` (6) and `map_command_key` (O, Shift+F10) |
| `Settings.SCHEMA` already holds `game/movement` (`instant`, `normal`, `slow`; `normal`; Game page, `since: "6"`); `state/study_page` lists `military`; `state/map_mode` has terrain, owner, relief (M4.5 and M5 add yields, food) | `shell/app/settings.gd` | M6 adds `supply` to `state/map_mode` and one key, `map/sight_veil` |
| `MapData` per edge: `river` (1 to 3 a river's class, 4 a stream), `crest`, `pass_edge`, `road` (1 track, 2 road, 3 highway), `crossing` (1 ford, 2 bridge_wood, 3 bridge_stone, 4 ferry, 5 pass); per hex `cover`, `relief`, `height_m`, `climate` (0 snow, 1 frost, 2 mild) | `core/defs/map_data.gd` | Every movement and supply rule of M6 reads these; no map change |
| North Italy: 340 land hexes; river edges by class 15, 133, 34 and 53 streams; crossings: 31 pass, 29 wooden and 6 stone bridges, 5 fords, no ferry; 89 crest edges, 45 of them pass edges (31 with a road); land climate snow 174, frost 134, mild 32 | `data/maps/north_italy.tres` (read for this page) | The great river (class 3: the Po, from Turin down) is crossed only at its five wooden bridges: Turin–Vercelli, Vercelli–Alessandria, (9, 10)–Milan, Pavia–Piacenza, and at Ferrara |
| The Mont Cenis saddle (3, 9): snow cover, 3,320 m, Savoy's; its pass edges lead to (4, 10), (3, 8) and (2, 9); the Little St Bernard saddle (3, 7) has pass edges to (2, 7) and (3, 8) | the same | The worked route and the starving army of 4.13 |
| The marks atlas has `mark/grid`, `select`, `target`, `white` and the crossing marks (`ford`, `bridge_wood`, `bridge_stone`, `ferry`, `pass`, six directions each) | `assets/tiles/summer/index.json` | Reach tiles use `mark/white`; the order cursor uses `mark/target` |
| `TileMapView` has `OVERLAYS = {"marks": [90, ""]}`, the standing group at z 70 (`Standing`, y-sorted), lines at 50, borders at 85 | `shell/mapview/tile_map_view.gd` | Two overlay layers join (`reach`, `reach_next`); tokens get their own node at z 88 (1.2) |
| `Actions.pair_of` is a `match`; `Actions.register_test_action` lets a test register a stub pair | `core/game/actions.gd` | The M6 hostility seam uses the same pattern (5.3) |
| v0.2.2's armies: `UnitKind` and `TROOPS` (pikemen 25 gold, knights 45, bombards 60; 3, 5 and 2 move points on 57 km hexes); `STACK_BASE` 6; `MANPOWER` 1,000 men a troop; `SUPPLY_RANGE` 3 x SCALE; `FORAGE_LOSS` 4 %; `ATTRITION` 1 hp; `logistics`, `in_supply`, `supply_limit`; `may_enter` closed to non-enemies; `plan` (Dijkstra), `move_group` emitting `unit_moved` with `seen`; `replay.py` | `hexa/campaign/data.py`, `systems/military.py`, `movement.py`, `terrain.py`, `supply.py`, `replay.py` | Section 3 |
| `battle-size-and-frontage.md` adds the era 1 Crossbowmen (missile branch, 28 gold, back line) | `docs/design/battle-size-and-frontage.md` 4.4 | M6 raises them; their fire is M7's |
| The owner's look for armies (2026-11-14): direction A, "a small hex plate in the nation's colour with one or two figures, a pennant", the **strength** on the badge, the regiment count in the hover card, a gold ring when selected | `docs/design/godot-look/README.md` | The token of 6.3 |
| Built by M1.5 to M5 and named "(M2)" to "(M5)" below: `Territory`, `Countries`, `Works`, `Calendar`, `Season`, `Stats`, `StatsSystem`, `Chronicle`, `Luck`, `ViewCache`, `Snapshot`, `SaveFile`, `Replay`, `Knowledge`, `Words`, `WorksView`, `LogLines`, `Reminders`, `SeasonSummary`, `Economy`, `EconomySeason`, `Treasury`, `Stores`, `DistrictCache`, `StateView`, `EconomyPreview`, `ImprovePreview`, `StudyEconomy`, `StudyRankings`, `StudyHistory`, `MapModes`, `ModeOverlay`, `ModeLegend`, `StudyWarm`, `People`, `PeopleView`, `StudyPeople`, `PeopleCards`, `SeasonFlow`, `ResourceChips`, the floaters, the action log, `GameRequests`, `perf_core.gd`, `PerfFixture`, `economy_report.gd` | their specs | M6 starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M6 | Why |
|---|---|---|
| v0.2.2: a stack walks the moment it is ordered; a multi-season march waits each season for R | **Orders, executed in the season's `movement` phase** (standard 5.3 row 2). An order persists until the army arrives (it then holds), is halted, or is changed; **R continues a halted march** | The standard's table has movement as a phase; one door for the player and the AI (M8); all armies walk at once, so nobody moves first; orders can be changed all season; the replay plays every walk after End season (`REPLAY`) |
| Standard 3.2 layer 6 and M1 spec 5: "army tokens are small scenes in the same group, so they sort with the trees" | Tokens sit in their own y-sorted node, **`ArmyTokens`, at z 88**, above the mode overlay (80), the borders (85), the pennants (86) and the work marks (87) | A mode tint must never dim an army and a tree must never hide one; the owner's look puts the strength badge first |
| Standard 2: "`Country`, `Army`, `War`, `Market` objects"; the brief's `Army`/`Unit` | **`Army`** (one or more units of one country on one hex under one order) and **`Unit`** (a company: a kind and its men). The player reads "company" | The mockup's "1 company of crossbowmen"; the report sorts armies by men |
| M4 12, M6 row: "`Treasury.WHY` gains `army`" | **Two reasons:** `upkeep_army` (the season's upkeep, one line a country) and `raise` (raising, a line a hex); `SPENDING` gains `raise`; a raise cancelled in its season is a `refund` | The Stats series is named `upkeep_army`; raising is the player's spending, upkeep a running cost |
| M4 12 and M4 plan 7, M6: "horses and iron reserves" | Horses keep **10** and copper **5** in store (`reserve_fixed`); iron keeps M4's 20 | Without a reserve every horse and every load of copper is sold each season and no knight or bombard could be raised |
| M5 12 and 4.20: "the army's food as a need beside the towns' in `EconomySeason.needs_of`" | `needs_of` gains `army_food` (the supplied armies' food a season), read by the reserve and the previews; the armies eat it in the **supply** phase, before the towns eat in production | Armies march on grain; one place takes the food, the reserve keeps it |
| M5 4.20: `People.levy` "takes its men"; M6 "decides how many men a company takes and whether towns or the countryside give them" | A company takes 500 men (knights 250, bombards 100) from the settlement where it is raised and then from that settlement's own ring, each hex up to `People.available` | A village alone (3,000 people, 300 available) could not raise one company |
| M5 12: "foraging as a flow appended to `People.FLOWS`" | `foraged`, appended; an army that forages takes 2 % of the hex's people a season | The conservation property needs every person accounted for |
| M3 4.7, style spec 6.5: `knows` "from M6 an explored hex"; `witnesses` "every country until vision arrives (M6)" | `Country.explored` (saved) and a derived sight cache; `Knowledge.knows` adds "has explored a hex of other"; events at a hex get `witnesses` from sight (4.11) | "What befell" with real witnesses |
| M4 6.2 and 4.16: "sight ... (M6 ... hidden)" on the works card | **No sight from settlements or castles in M6**: land sees its ring, armies 1 or 2 hexes; the card's sight line stays hidden | A city seeing three hexes would make countries known on turn 1 that M3 to M5 pin as unknown; M7 may give castles a watch |
| M3 4.9 and style spec 6.4: nine section ids | A tenth, **`armies`**, between `people` and `orders` | An army's men, place, supply and losses are its own story; "Your orders" keeps the orders |
| M3 6.3: `REPLAY` (M6) "empty in M3; the flow passes through" | Filled: the flow plays the season's walks, Space or Enter skips, Instant and reduce motion skip it | Style spec 6.7 |
| M4.5 D15: Supply on key 6 | Kept: `view_mode_6` (key 6), the sixth segment "Supply" | First come, first numbered |
| UI spec 7: the hex menu "only when no army of yours is selected (then a right click is an order)" | Kept; with an army selected, a right click on the army's own hex is **Hold** | One click meaning per state |
| UI spec 4.5: "Alt+arrows move the selection and the camera follows" | With no army selected they move the selected hex; **with an army selected they move the order cursor**, and **O** (or Shift+F10) orders a march to it; with no army selected O opens the hex menu | Keyboard play of every order |
| `game-feedback-screens.md` C.2: Military "armies table (men, upkeep, supply, place), losses chart, upkeep share" | One page, no tabs: your armies, the upkeep chart, the losses chart, and the armies you see (banded) | The page's widgets; M7 adds wars |
| M2 13: "the overlay for the Supply mode (one more texture) and fog (another)" | Two R8 textures, `supply` and `sight`; the sight veil draws in every mode when `map/sight_veil` is on | The land is known (fog of discovery is one of the milestones after M12); only what you cannot see now is veiled |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days). Data changes are a
`.tres` edit plus the test that pins the value.

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | When armies move | **Orders during the season, walks in the `movement` phase** (1.2). An order is `march` to a goal hex or `hold`; an army with neither awaits orders | Standard 5.3; the AI acts through the same door; simultaneous and deterministic | L |
| D2 | A march over many seasons | The route is planned once, when the order is given, and walked season after season; it is re-planned only when its next step is blocked; on arrival the army **holds**. A blocked march with no new route **halts** (no order, the goal kept); **R** continues it | Predictable and cheap: a stored route costs nothing a season | S |
| D3 | Army and unit | An **army** is units of one country on one hex under one order; a **unit** is a company of one kind with its men. Several armies of one country may share a hex; split and merge are actions | Orders per army; strength per company for M7's lanes | M |
| D4 | Which kinds | Era 1 only: **pikemen** (infantry), **crossbowmen** (missile), **knights** (cavalry), **bombards** (artillery). No generals (M11: `m7-build-spec.md` D36), no wagons (depots and stores feed armies), no scouts (the map is known), no ships (after M12) | `battle-size-and-frontage.md` 4.4; M11 brings later eras | Data (S) a kind |
| D5 | Men per company | Pikemen and crossbowmen 500, knights 250, bombards 100 (four guns and their crews) | 28 km districts: a company is a few hundred men, as the condottieri's | Data (S) |
| D6 | What a company costs | Pikemen 25 ducats + 1 iron, upkeep 6; crossbowmen 30 + 1 iron + 1 timber, upkeep 7; knights 45 + 1 iron + 3 horses, upkeep 10; bombards 60 + 5 iron + 3 copper, upkeep 8 (ducats a season at full strength) | v0.2.2's gold and the mockup's "crossbowmen ▼ −30"; an army of four companies costs Genoa about a third of its net | Data (S) |
| D7 | Where companies are raised | On a settlement of yours: pikemen and crossbowmen from a hamlet up, knights from a village (2), bombards from a town (3). A settlement raises at most 1, 1, 2, 3, 4 companies a season by level 1 to 5 (`FamilyDef.raise_cap`) | Towns muster men and gear; the cap keeps a city from raising a host in one season | Data (S) |
| D8 | Where the men come from | `People.levy` (M5) on the settlement first, then on its own ring in direction order, each hex up to `People.available` | M5's seam; the countryside gives men too | S |
| D9 | Mustering | Units raised in a season do not walk in that season's movement phase; an army holding any of them waits ("musters") | v0.2.2: a troop raised this season cannot move | Data-free (S) |
| D10 | Undo | Disbanding a unit in its raising season, on its raising hex, gives back its ducats and goods; men always go home | As works' first-season refund (M3 D14) | S |
| D11 | Disbanding | The men go back to the unit's home hex if it is still yours, else to the army's hex; disbanding is allowed only in your own land | People never vanish; one door (`People.give_back`) | S |
| D12 | Stack limit | **8 units of one country on a hex**, checked when raising, when ordering (the goal) and at the end of each movement phase (a march stops short where it fits) | v0.2.2's 6 regiments of 1,000 on 57 km, re-fitted to 500-man companies; M7's 3 lanes and back line hold 6 | Data (S) |
| D13 | Borders | Armies stand only on **their own land and unowned land**; foreign land opens with war (M7, `Movement.open_to`) | v0.2.2 ("their land is closed to your army"); no war before M7 | S |
| D14 | Two countries on a hex | Never in M6; in M7 only in a battle | The battle hex rule is M7's | none |
| D15 | Move points | Foot (pikemen, crossbowmen) **12** a season, knights **16**, bombards **8**; an army moves at its slowest unit's pace; points left at a season's end are lost | v0.2.2's 3, 5 and 2 on 57 km hexes (6, 10, 4 at SCALE 2) re-fitted to 28 km: a season's march on roads crosses half the map | Data (S) |
| D16 | Ground | The step into a hex costs its cover's points (farmland, grassland, sand 2; woods, tundra 3; marsh, rock 4; snow 6) plus its relief's (highland +1, mountains +2, high peaks +3); a road on the edge caps it (highway 1, road 2) or halves it (track, rounded up) | 01-terrain-and-relief: valleys cheap, heights dear; roads are where armies march | Data (S) |
| D17 | Rivers are edges | A stream +1; a river of class 1 +2 where nothing crosses it; **class 2 with no crossing takes a whole season to wade**; **class 3 (the Po) only at a crossing**; a ford +1, a ferry +2, a bridge 0 | `02-water.md` 3.1's hooks; a great river is a wall with gates | Data (S) |
| D18 | Crests | A crest edge is never crossed, but at a pass edge | v0.2.2 and `01-terrain-and-relief.md` | none |
| D19 | Winter | A pass edge **closes in winter** when either hex beside it has the snow winter; a step into a snow-winter hex costs double in winter | The calendar's season matters to armies as to works (M3 D11) and fields (M4 D4) | Data (S) |
| D20 | A pass closed on the way | The march takes a winter detour when one exists that costs at most twice the remaining summer route and less than two seasons more; else it **waits for spring** at the pass's foot, its order kept | v0.2.2 `pass_wait` | Data (S) |
| D21 | Zones of control | An army stepping beside a hostile army ends its walk there for the season; built now behind `Movement.hostile`, which is false for everyone in M6 (M7 makes it war, and adds castles) | v0.2.2's halt beside enemy castles; M7 needs the seam | S |
| D22 | Walks that meet | The movement phase walks every army step by step in **ticks** (army id order); a step into a hex holding another country's army is not taken (M7: an attack); a walk that would end over the stack limit stops on the last hex of its route where it fits | Deterministic and fair; the replay shows the ticks | M |
| D23 | Supply | An army is **in supply** within **8 supply points** of a **depot** of its country (a settlement of level 2 or more, or a port) through its own land; a supply line stops at crests, closed passes and great rivers without a crossing, and wades a class 2 river for 3 points | v0.2.2's depots and range, measured in ground so the Alps lie beyond reach | Data (S) |
| D24 | Castles | **Not depots in M6** (they hold no stores until M7's garrisons) | One cause per effect | S |
| D25 | Food | Supplied armies eat **1 load a season per 5,000 men** (`army_food_milli` 200) from the stores, grain first, then fish, in the supply phase | Soldiers eat twice a townsman's ration (M4: a load feeds 10,000 a season) | Data (S) |
| D26 | Out of supply | The army **forages** its hex: the land feeds a share of its people as soldiers (by cover; snow none), all of it in spring to autumn and in a mild winter, half in frost, none in snow; foraging takes 2 % of the hex's people a season (flow `foraged`) | v0.2.2's forage on districts; the land pays | Data (S) |
| D27 | Hunger | Unfed men are lost: a tenth a season, a fifth in a snow winter, 15 % in frost (rounded up); a unit at 0 is lost | v0.2.2 lost a hit point of six a season; one cause, deterministic | Data (S) |
| D28 | Refill | A unit in supply on its country's land regains up to a tenth of its full men a season (knights 25, bombards 10) from the people of its hex, free | v0.2.2 healed at home; men come from people (M5's seam) | Data (S) |
| D29 | Upkeep | Paid in the income phase, one line a country (`upkeep_army`, count = armies), each unit `ceil(upkeep × men / full)`; always paid (M4 D19) | M4's rule for running costs | S |
| D30 | The doors | Every ducat through `Treasury.move` (`raise`, `upkeep_army`, `refund`), every load through `Stores.move` (`raise`, `army`, `refund`), every person through `People.move` (`raised`, `returned`, `foraged`), every man through `Armies` | One writer a field (standard 4.3) | none |
| D31 | Vision | A country sees its own land and the hexes beside it, and each army's sight (foot and guns 1, an army with knights 2) | v0.2.2's `update_visibility`; known countries stay as M3 to M5 pinned them | Data (S) |
| D32 | Explored | `Country.explored` (a bitset, saved) gains every hex a country has seen, including along its armies' walks | Knowledge's "explored hex" (M3 4.7) | S |
| D33 | Witnesses | An event at a hex of the kinds in `Vision.SIGHTED` carries the countries whose sight holds the hex (the actor always) | Style spec 6.5; v0.2.2's `seen` | S |
| D34 | What is hidden | The land is known (no fog of discovery); other countries' armies are drawn only where you see; a light veil marks the hexes you do not see (`map/sight_veil`, on) | The owner's answer: land game; discovery comes after M12 | S |
| D35 | Starting armies | **None** in the 1480 scenario; M8 seeds armies with the AI (`m8-build-spec.md` D30: `ScenarioDef.start_armies` exists and 1480's is empty; every AI raises in its first season) | Armies that never move would cost upkeep and move every M4 and M5 number; M8 gives them behaviour | M |
| D36 | The sandbox | No armies (raising refused: "the sandbox has no armies"); no Supply mode | No countries, no people to levy | S |
| D37 | Army names | "Army of <the place of its hex, else the nearest named place within two hexes, else its country>"; a name already in use by a living army of the country gets "Second", "Third" ... "Tenth", then a number | The mockup's "Army of Novi" | S |
| D38 | Events | `army_raised`, `army_disbanded`, `march_halted`, `army_starved`, `unit_lost` (notable); `army_changed`, `unit_moved` (not notable) (4.11) | Game feedback D.2; M5's hand-over | S |
| D39 | The season | M6's `PHASES`: **movement, supply, production, income, works, people, stats, calendar, ready_units, vision** (4.10) | The standard's rows 2, 3 and 16 | S (the pin) |
| D40 | Saves | `SaveFile.FORMAT` **4**, `OLDEST_FORMAT` 4; body key `armies`; `country/4` | An M5 save's digest counts no armies or explored hexes, so it could never match its header | S |
| D41 | Luck | **None.** Every M6 rule is integer and walks armies by id | Determinism; M7's battles draw from `Luck.world` | none |
| D42 | The replay | Every walk of a season is played at once, tick by tick: 180 ms a step (Normal), 320 ms (Slow), the whole replay at most 6 s (9 s), never under 40 ms a step; Instant skips it; reduce motion plays it instantly; steps nobody of yours saw are instant | v0.2.2 `replay.py`, simpler because the phase already walks in ticks | Data (S) |
| D43 | Right click | With an army of yours selected: march there (Hold on its own hex); with none: the hex menu | UI spec 7 | S |
| D44 | Keys | Tab: the next army that needs orders; R: continue a halted march; Alt/Option+arrows: the cursor; **O** or Shift+F10: command at the cursor; 6: Supply | UI spec 4.1, 4.5 | Bindings (S) |
| D45 | The report | A tenth section, Armies; raised, marched, held, split, joined and disbanded in Your orders; others' witnessed army events and the foreign armies in sight in What befell; men under arms in At a glance and Standing | Style plan S5 row M6 | S |
| D46 | Rankings | A fourth measure, **Men under arms** (Stats `army_men`), banded for others | M4.5's hand-over; Rankings equals Standing (M4.5 done-when 5) | S |
| D47 | The chips | An **Army** chip (men under arms, the change last season) after Food | UI plan M6; icon `army` baked in M4 | S |
| D48 | The preview | `EconomyPreview.with` runs each previewed season's army step for the country's armies **where they stand**: their food from the stores, foraging, hunger, refill and upkeep | M4 done-when 4 must hold with armies; a marching army is previewed where it stands | M |
| D49 | Performance | Routes by A* on a bucket queue over a lazily filled step table; supply fields cached by country until the land or a depot changes; budget rows in `perf_core` (section 8) | The AI's hot path (M8) | M |
| D50 | The console | `raise c r kind [n]`, `march ID c r`, `hold ID`, `armies`, and the prefix `as TAG` for any action command (developer tools only, through `Session.act`, logged) | The playtest needs a foreign army in sight before the AI exists | S |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| `TROOPS` by branch and era: pikemen (hp 10, 25 gold, weapons and grain), knights (45 gold, horses), bombards (60 gold, iron, copper, gunpowder, needs a town); `GENERAL`, `WAGON`, `SCOUT`; `raise_options` (one troop a branch of the era) | `data.py` 254 to 335; `military.py` 30 | The three era 1 kinds and their gold; bombards need a town; one kind a branch of the era | Crossbowmen join (battle-size-and-frontage 4.4); men instead of hit points; goods from M4's stores (iron, timber, horses, copper: no weapons or gunpowder goods exist); no generals, wagons or scouts (D4) |
| `stack_limit`: `STACK_BASE` 6 war units a hex, +2 with a general; `CIVILIAN_LIMIT` 3; `can_stand` | `military.py` 36 to 59 | A per-hex limit of one country's units | 8 companies of 500 (D12); no civilians; generals in M7 |
| `recruit_check`: a battle here; one job a season; era; town for cannons; the capital for generals; gold; `land_spot`; peasants (2,000 must be left) | `military.py` 62 to 100 | Refusals in order, each with its words; a settlement raises; the men are taken | A cap by level (D7) instead of one job a season; men through `People.levy` (D8); no `land_spot` (the units stand on the settlement) |
| `refit`, `upgrade` (drill at barracks) | `military.py` 130 to 205 | | M11 (refit to later eras), M7 (drill) |
| `may_enter`: walls (crest, shut pass); foreign land only at war; `zoc`: hexes beside enemy castles halt a march | `movement.py` 25 to 52 | All of it | ZOC behind `Movement.hostile` (D21); unowned land open |
| `plan`: Dijkstra over a stack's moves; `reachable_group`, `next_season_reach`, `path_to`, `route`, `cost_field`, `step_toward_group`; `pass_wait` | `movement.py` 74 to 381 | The searches, the reach of this season and the next, the whole-map cost field for the AI, waiting for spring | A* on a bucket queue (integer costs); a route stored on the order (D2) |
| `move_group`: walks the route at once, sees along the way, emits `unit_moved` (tag, end, ids, path, `seen` per hex) | `movement.py` 188 to 248 | The event and `seen` | Walked in the movement phase in ticks (D22); `unit_moved` also carries `ticks` and `witnesses` |
| `step_cost`: terrain move 1 to 3; roads 1 between road hexes; a river shared by both hexes cheaper; `step_walls` (ridges always, passes in winter) | `terrain.py` 41 to 65 | Terrain costs, roads cheaper, walls | Costs by cover and relief (D16); roads on edges; rivers are obstacles on edges, with crossings (D17); only passes beside the snow winter close (D19) |
| `is_depot` (castle, town, port), `in_supply` (within `SUPPLY_RANGE` through controlled land and no enemies), `supply_limit` (troops a province feeds: 2 + people / 4 ...), `logistics` (feed or attrition), `forage` (4 % of the people), wagons | `supply.py` | Depots, reach through own land, foraging costs people, hunger costs strength | Reach in ground points (D23); castles not depots in M6 (D24); food from the stores (D25); the land feeds a share of its people (D26); no wagons |
| `replay.py`: walks played hex by hex, 180 ms a hex, capped 6 s, countries in turn order, fogged steps instant | `campaign/replay.py` | The pace, the cap, the fog rule, the speed option | All walks at once by ticks (D42) |
| `start_units`: moves back, healing at home, morale | `systems/season.py` 96 | Healing at home | Refill from people (D28) |
| Units are seen within `unit_sight`; provinces see 1; `update_visibility` | `season.py` 133 to 156 | Land sees its ring; armies see 1 or 2 | Witnesses on events (D33); explored saved (D32) |

---

## 4. Design content

### 4.1 The model in one picture

```
 during the season (actions, any country)
   raise {hex, kind, count}      Treasury.move raise, Stores.move raise, People.levy (raised)  -> army_raised
   march {army, goal}            route planned (A*), stored on the army                         -> army_changed
   hold, continue_march, split_army, merge_armies, disband                                      -> army_changed / army_disbanded
 movement     every army with a march (id order), mustering armies wait: walk the stored route by ticks within its move
              points; closed pass -> detour or wait for spring; blocked -> re-plan or halt; stack limit at the end
                                                                       Armies.set_hex  -> unit_moved, march_halted
 supply       every country (id order): its armies in supply eat from the stores (Stores.move army); the others forage
              (People.move foraged); unfed men are lost                Armies.lose_men -> army_starved, unit_lost
 production, income (+ upkeep_army), works, people, stats (+ army series), calendar   (M3 to M5)
 ready_units  supplied units on their land refill from the people of their hex (People.levy raised)  -> army_changed
 vision       every country's sight from its land and armies; explored hexes grow
```

### 4.2 The kinds (`data/defs/units/<key>.tres`, `UnitDef`)

| Id | Key | Name; one, many | Branch | Men | Raise | Goods | Upkeep a season | Move points | Sight | Raised from level | Refill a season |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | `pikemen` | Pikemen; company of pikemen, companies of pikemen | infantry | 500 | 25 | 1 iron | 6 | 12 | 1 | 1 hamlet | 50 |
| 1 | `crossbowmen` | Crossbowmen; company of crossbowmen ... | missile | 500 | 30 | 1 iron, 1 timber | 7 | 12 | 1 | 1 hamlet | 50 |
| 2 | `knights` | Knights; company of knights ... | cavalry | 250 | 45 | 1 iron, 3 horses | 10 | 16 | 2 | 2 village | 25 |
| 3 | `bombards` | Bombards; battery of bombards, batteries of bombards | artillery | 100 | 60 | 5 iron, 3 copper | 8 | 8 | 1 | 3 town | 10 |

Ids are the order of `GameDefs.units`, append-only. Combat numbers (attack, defence, fire, lane rank) are M7's fields on
the same class. Upkeep of a unit: `ceil(upkeep × men / full)`; an army's is the sum; a country's is the sum of its armies'.

### 4.3 The ground (`data/defs/terrain/<key>.tres`, `TerrainDef`) and the step cost

| Cover id | Key | Move points to enter | Forage (permille of the hex's people fed as soldiers a season) |
|---|---|---|---|
| 0 | farmland | 2 | 250 |
| 1 | grassland | 2 | 250 |
| 2 | woods | 3 | 200 |
| 3 | marsh | 4 | 150 |
| 4 | rock | 4 | 150 |
| 5 | snow | 6 | 0 |
| 6 | tundra | 3 | 100 |
| 7 | sand | 2 | 150 |

`StepCosts.compute(map, defs, i, d, winter)`, the cost of stepping from hex `i` across its edge `d` into its neighbour
`j` (all integers, in this order; the first that applies of the rules marked "blocked" ends it):

```
j off the map or sea                                  -> BLOCKED
crest[e] == 1 and pass_edge[e] == 0                   -> BLOCKED
winter and pass_edge[e] == 1 and (climate[i] == 0 or climate[j] == 0)   -> CLOSED (a pass shut by snow)
g = TerrainDef(cover[j]).move + relief_move_add[relief[j]]           # relief_move_add 0, 0, 0, 0, 1, 2, 3
road[e] == 3: g = min(g, highway_cap)       (1)
road[e] == 2: g = min(g, road_cap)          (2)
road[e] == 1: g = ceil(g / track_divisor)   (2)
winter and climate[j] == 0: g = g × winter_snow_percent / 100   (200)
river[e] == 4 (a stream): g += 0 with a bridge (crossing 2, 3), else stream_cost (1)
river[e] in 1..3: crossing 2 or 3 (a bridge) +0; 1 (a ford) +ford_cost (1); 4 (a ferry) +ferry_cost (2);
                  no crossing: class 1 +river_cost (2); class 2 (river_wade_class) -> WADE; class 3 (river_wall_class) -> BLOCKED
```

`BLOCKED` 255, `WADE` 254, `CLOSED` 253; every other cost is 1 to 252. A **WADE** step can be taken only as an army's first
step of a season and spends all its move points; in the route search it counts `wade_plan_cost` (12). The supply line's
cost (`StepCosts.supply_cost`) is the same with WADE as `supply_wade_cost` (3) and CLOSED blocked.

Worked steps on north Italy (summer): Turin (5, 9) to Vercelli (6, 9): farmland on a road over the Po's wooden bridge, 2;
Turin to Susa (4, 9) 2; Susa to the Mont Cenis saddle (3, 9): snow 6 + high peaks 3 = 9; the saddle to (3, 8) across the
pass edge on a track: ceil(9 / 2) = 5; in winter that edge is CLOSED (both hexes snow winter) and Turin to Susa costs 2
(frost) while Susa to the saddle costs 18.

### 4.4 Moving

**Move points.** `Movement.mp_of(game, army)` = the smallest `UnitDef.mp` of its units. Each movement phase an army
spends at most that many points; what is left is lost.

**Where an army may stand** (`Movement.open_to(game, tag, hex)`): a land hex held by `tag`, or held by no one; M7 adds the
land of a country `hostile` to `tag`. **Who is hostile** (`Movement.hostile(game, a, b)`): nobody in M6, except pairs a
test registers (`Movement.register_test_hostility(a, b)`, the pattern of `Actions.register_test_action`).

**Room** (`Military.can_stand(game, tag, hex, adding, leaving)`): "" when `hex` holds no army of another country and the
units of `tag` there (less the armies in `leaving`, which march away) plus `adding` are at most `stack_limit` (8); else the
words of 4.7.

**The route** (`Movement.plan(game, army, goal)`): A* from the army's hex to `goal` over hexes `open_to` the army's
country, costs of `StepCosts.cost` with the rules of the current season (winter when `Calendar.is_winter(game.turn)`),
WADE at `wade_plan_cost`, CLOSED and BLOCKED not entered, the heuristic `hex distance × 1` (the cheapest step), the search
stopping past `march_seasons_max × mp` (12 seasons). In winter the route is planned twice, with the winter rules and with
the summer ones; when the summer route crosses a pass edge that is CLOSED now, the summer route is kept (the army will
**wait for spring** at the pass) unless a winter route exists that costs at most `wait_ratio_percent` (200 %) of the summer
route and less than `wait_extra_seasons` (2) × the army's move points more, which is then taken. The result: `{ok, hexes: PackedInt32Array (from the next step to the goal), cost, waits: pass name
or "", reason}`.

**The walk** (`Movement.walk_plan(game, army, route, from_turn)`): season by season from `from_turn`, the army skipping
its mustering season, walks the route's steps with the costs of that season until the next step costs more than the
points left (a WADE step only with all points, then the season ends) or is CLOSED (the season ends: it waits). It gives
`{stops: Array[{turn, index}] (where the army stands at the end of each season), arrives_turn (the season it stands on the
goal at the end of), seasons}`. The preview and the army panel show these stops; the movement phase walks the same rule
for one season.

**The movement phase** (`Movement.season(game)`):

1. **Legs.** For every army in id order with `order == march` and not mustering: walk one season of its route as above
   (the leg); a CLOSED next step applies D20 (`Movement.winter_wait`: a detour re-planned now, or the army waits: it does
   not move and `army.waiting` becomes `&"winter"`; `march_halted {why: winter, waits: true}` is emitted the first season it
   waits); a BLOCKED next step or one into land no longer `open_to` it re-plans with the season's rules; no route halts the
   march (`order` none, `halt_why` `no_way`, the goal kept, `march_halted {why: no_way}`).
2. **Ticks.** Tick 1, 2, ...: every army with a step left at this tick, in id order, takes it unless the hex holds another
   country's army at that moment (then its leg ends there: M6 halts it, `halt_why` `blocked`, "an army of the Duchy of
   Milan stands at Alessandria (7, 9)"; M7 makes a hostile one a battle). An army stepping onto a hex beside a hostile army
   (`Movement.zoc_halts`) ends its leg there (M6: never, but in tests).
3. **Room.** The legs' ends are checked in army id order: while the companies of a country ending on a hex exceed 8, the
   last army there in id order steps back one hex along its leg (to its start at worst, where it stood when the phase
   began), and the check runs again until every hex fits (each step back moves one army toward its start, so it ends); a
   march cut short this way keeps its order and goes on next season.
4. **Apply.** `Armies.set_hex` for every army that moved (and `moved_from`, its hex before the phase); the leg's steps are
   removed from its route; an army on its goal holds (`order` hold, the route and goal cleared). Each walk emits one
   `unit_moved` (4.11) and adds the hexes it saw on the way to its country's explored hexes (`Vision.see_path`). The sight
   cache is refreshed after the phase so that the later phases' events have the new witnesses.

**Zones of control** (D21): `Movement.zoc_halts(game, tag, hex)` is true when a neighbour of `hex` holds an army of a
country `hostile` to `tag`. M7 adds the garrisoned castles of hostile countries.

### 4.5 Raising

`Military.raise_check(game, {hex, kind, count, tag})` (`count` 1 when absent), in order (the first refusal is the
verdict):

| # | Case | Verdict |
|---|---|---|
| 1 | No hex or no kind given | "no hex given", "no kind given" |
| 2 | `count` under 1 | "count the companies: 1 or more" |
| 3 | The game has no countries | "the sandbox has no armies" |
| 4 | `Territory.at_home_check(game, tag, hex)` refuses | its words (M2) |
| 5 | No settlement stands on the hex | "companies are raised in towns and villages: no settlement here" |
| 6 | `kind` is not a `UnitDef` id | "no such kind of company" |
| 7 | The settlement's level is under the kind's `min_level` | "%s are raised in a village or larger" / "... in a town or larger" (the kind's name) |
| 8 | The companies raised on this hex this season plus `count` exceed `raise_cap[level]` | "%s has raised its %d companies this season" / "... can raise 1 more company this season" (`Military.hex_text`) |
| 9 | `Military.can_stand(game, tag, hex, count)` refuses | its words ("no room: 8 of 8 companies stand here") |
| 10 | The men at hand (`Military.men_at_hand`: `People.available` of the hex and of its ring hexes held by `tag`) are under `count × men` | "only %d men can be raised here this season: %d are needed" |
| 11 | The treasury is under `count × cost` | "not enough ducats: %d needed, %d in the treasury" (M4's words) |
| 12 | A good of `count × cost_goods` is short | `Stores.short_of`'s words ("not enough horses: 3 needed, 0 in store") |
| 13 | Otherwise | ok |

`Military.raise` checks again, then: `Treasury.move(game, tag, −ducats, &"raise", hex)`; per good in id order
`Stores.move(game, tag, good, −n, &"raise")`; the men by `People.levy` on the hex, then on its ring hexes held by `tag` in
direction order 0 to 5, each `min(still needed, People.available)`; the units (`raised_turn` = `game.turn`, `home` = hex,
`paid`, `paid_goods` per unit) join the first army of `tag` on the hex (lowest id) whose order is not `march`, else a new
army (named by D37, order none); `army_raised` is emitted.

**Men at hand on north Italy at the start** (the hex alone; its ring adds more): a hamlet 100, a village 300, a town
1,000, a walled town 3,000, a city 6,000; farmland 800, woods 250. Turin (a town, 10,000 people) raises its 2 companies a
season from its own people.

### 4.6 Disbanding, splitting, merging

`Military.disband_check(game, {army, unit, tag})` (`unit` −1 for the whole army): no army given ("no army given"); no
such army ("no army %d"); not yours ("not your army: the %s commands it"); a `unit` not in it ("company %d is not in the
%s"); the army's hex not held by `tag` ("disband only in your own land: (%d, %d) is not yours"); else ok. `disband`: for
each unit, in id order: when `raised_turn == game.turn` and the army stands on the unit's `home`, `Treasury.move(+paid,
&"refund", hex)` and `Stores.move(+n, &"refund")` per good; the men by `People.give_back` to `home` when `tag` holds it, else
to the army's hex; the unit is removed; an empty army is removed; `army_disbanded` is emitted.

`Military.split_check(game, {army, units, tag})`: no army; no such army; not yours; no units given ("no companies given");
a unit not in it; all of its units ("a split must leave at least one company behind"); else ok. `split_army` makes a new
army on the same hex with those units, `order` hold, named by D37; two `army_changed`.

`Military.merge_check(game, {army, into, tag})`: either missing ("no army given"); either unknown; either not yours; the
same army ("an army cannot join itself"); different hexes ("the armies stand on different hexes"); else ok.
`merge_armies` moves every unit of `army` into `into` (which keeps its order), removes `army`, emits `army_changed` for
both (`gone` true for `army`). The stack limit always holds: both stand on the hex already.

### 4.7 Orders

`Movement.march_check(game, {army, goal, tag})`:

| # | Case | Verdict |
|---|---|---|
| 1 | No army or no goal given | "no army given", "no goal given" |
| 2 | No army has the id | "no army %d" |
| 3 | The army is another country's | "not your army: the %s commands it" |
| 4 | The goal is off the map or at sea | "that is off the map", "armies cannot walk on water" |
| 5 | The goal is the army's hex | "the army stands there already" |
| 6 | The goal is not `open_to` the army's country | "not your land: the %s holds it, and your armies cross no border in peace" |
| 7 | `Military.can_stand(game, tag, goal, <the army's units>, [army])` refuses (the armies there that march away do not count; the armies already ordered there do) | its words: "no room at Vercelli (6, 9): 8 of 8 companies" or "another country's army stands at Alessandria (7, 9)" |
| 8 | `Movement.plan` finds no route | "no way there by land: a ridge, a great river or another country's land lies between" |
| 9 | The route takes more than `march_seasons_max` seasons | "too far: more than 12 seasons' march" |
| 10 | Otherwise | ok |

`march` sets `order` march, `goal`, `route` (`plan`'s hexes), clears `halt_why`, `halt_text` and `waiting`, and emits
`army_changed`. `Movement.halt_check(game, {army, tag})`: rows 1 to 3; "the army holds already" when its order is hold;
else ok; `halt` sets `order` hold and clears goal, route and waiting. `Movement.continue_check(game, {army, tag})`: rows 1
to 3; "no march to continue" (no goal); "the march goes on by itself" (its order is march); then rows 6 to 9 on the kept
goal; `continue_march` re-plans and sets `order` march.

**Mustering.** An army with a unit whose `raised_turn` is the current turn musters: it accepts orders and walks from the
next movement phase.

### 4.8 Supply

**Depots** (`Supply.is_depot(game, tag, hex)`): a hex held by `tag` with a settlement of level `depot_min_level` (2) or
more, or a place with a port.

**The field** (`Supply.field(game, tag, winter)`): a multi-source search from every depot of `tag` over hexes held by
`tag`, with `StepCosts.supply_cost` and the rules of the season (winter or not), up to `supply_reach` (8) points; one byte
a hex (1 in supply). Kept in `game.supplies` (`SupplyCache`, derived) per (country, winter), dropped for a country when its
land or one of its settlements changes (`Game.emit` of `owners_changed`, or `hex_changed` on a settlement hex).

On north Italy at the start, out of supply in summer (in winter): Savoy 8 (17) of 58 hexes, among them the Mont Cenis
saddle (3, 9) and (4, 8); Milan 5 (9) of 52, the snow heights by the Gotthard, the Bernina, the Stelvio and Monte Rosa; Genoa 2 (4) of
14, (6, 14) and (5, 15); Venice 7 (11) of 42; Austria 26 (30) of 37; France 16 (21) of 34 (worked out from the map data
with these rules for this page; `tests/core/test_supply.gd` pins the lists).

**The supply phase** (`Supply.season(game)`), every living country in id order, its armies in id order:

1. **In supply** (`field[hex]`): the country's supplied men `M` need `ceil(M × army_food_milli / 1,000,000)` loads; they
   take grain, then fish, through `Stores.move(..., &"army")`; `fed` = taken × 1000 / need (1000 when the need is 0). Each
   supplied army's unfed men are `men − floor(men × fed / 1000)`.
2. **Out of supply**: the army forages its hex: the land feeds `forage_cap = people × forage_permille[cover] / 1000 ×
   forage_percent[slot] / 100` men (floored at each step; `forage_percent` 100, 100, 100 and in winter 0 snow, 50 frost,
   100 mild), shared by the country's armies on that hex in id order; its unfed men are those over its share. When an
   army fed any men there, the hex loses `ceil(people × forage_loss_permille / 1000)` people (2 %), once per country and
   hex a season, through `People.move(..., &"foraged")` (refused, and nothing lost, on unowned land).
3. **Hunger**: an army's loss is `min(men, ceil(unfed × starve_permille[slot] / 1000))` (`starve_permille` 100, 100, 100
   and in winter 200 snow, 150 frost, 100 mild), spread over its units by their share of its men (floored), the rest
   from the units in id order; `Armies.lose_men` writes it; a unit at 0 is removed with `unit_lost`; an army with no unit
   left is removed. `army_starved {why: out_of_supply | stores_empty}` is emitted for every army that lost men.
4. **Its state** (`Army.supply`): 0 fed from the stores, 1 fed by the land, 2 hungry; `Army.lost_last` the men lost.

`Supply.country_step(game, view, tag, season, stock, armies)` is the same arithmetic as a pure function (no writes), which
the supply phase applies and `EconomyPreview` simulates.

### 4.9 Refill and upkeep

**Refill** (the `ready_units` phase, `Military.refill(game)`): every army in id order whose `supply` is 0 and whose hex
its country holds: each unit under its full men, in id order, takes `min(full − men, UnitDef.refill, People.available)`
men by `People.levy` on the army's hex; `army_changed` once per army refilled.

**Upkeep** (the income phase): `EconomySeason.money_lines` gains, after the walls, one line `{why: upkeep_army, hex:
NO_HEX, amount: −Military.upkeep_country(game, tag), count: armies}`; upkeep is always paid (M4 D19).

**The armies' food in the economy.** `EconomySeason.needs_of` gains `army_food`: `ceil(men of the country's armies in
supply now × army_food_milli / 1,000,000)`; `reserve_of` keeps grain for `reserve_seasons` (4) × (food + army food).

### 4.10 The season table after M6

`core/game/season.gd` `PHASES` in M6: **`movement`, `supply`, `production`, `income`, `works`, `people`, `stats`,
`calendar`, `ready_units`, `vision`** (`test_season.gd` pins it). The planned order, edited from M5's 4.8:

| # | Name | Arrives | Reads | Writes (through the owner) |
|---|---|---|---|---|
| 1 | `ai_orders` | M8 | everything through views | through `Game.act` only |
| 2 | **`movement`**, `battles` | **M6**, M7 | armies, routes, map, owner, turn, sight | `armies` (`Armies`); `explored` (`Vision.see_path`); events `unit_moved`, `march_halted` |
| 3 | **`supply`** | **M6** | armies, owner, settlements, stock, people, turn, map | `armies` (men, supply; `Armies`); `stock`, `flows_open` (`Stores.move` army); `people`, `people_flows` (`People.move` foraged); events `army_starved`, `unit_lost` |
| 4 | `sieges` | M7 | armies, castles | owner, controller |
| 5 | `war_timeouts` | M9 | wars | wars |
| 6 | `production` | M4 | as M5; the reserve with the army's food | as M5 |
| 7 | `trade` | M10 | markets, stocks | stocks, prices |
| 8 | `income` | M4 | as M5; the armies' upkeep | `treasury`, `ledger_open` (`Treasury.move`, `upkeep_army` added) |
| 9 | `debt` | M12 | ledgers, treasury | treasury |
| 10 | `works` | M3 | as M5 | as M5 |
| 11 | `people` | M5 | as M5 | as M5 |
| 12 | `research` | M11 | research | techs |
| 13 | `extinction`, `scores` | M12 | countries | `alive`, score |
| 14 | `stats` | M3 | as M5; armies, the losses of the season | `stats` (M6 series); the closes of M4 and M5 |
| 15 | `calendar` | M3 | `turn` | `turn`, `weather` |
| 16 | **`ready_units`**, **`vision`** | **M6** | armies, supply, people (the new season's) | `armies` (men), `people`, `people_flows` (`People.levy` raised); `explored` (`Vision`) |

### 4.11 Vision, witnesses, events

**Sight** (`Vision`, the derived `SightCache` on `Game`): a country sees every hex it holds and its six neighbours
(`land_sight` 1), and around each army the army's sight (the largest `UnitDef.sight` of its units) in hex distance. The
land part is kept per country until its land changes; the army part is rebuilt by `Vision.refresh` (at game start and
load, after the movement phase, in the vision phase and after `dev_transfer`). `Vision.sees(game, tag, hex)`; the viewer
`&""` sees all.

**Explored** (`Country.explored`, a bitset of `ceil(hex_count / 8)` bytes, saved): set at game start to the land sight; the
vision phase adds the season's sight; the movement phase adds the hexes around each walk's steps. `Knowledge.knows` (M3)
becomes: M3's rule, **or** `viewer` has explored a hex `other` holds.

**Witnesses** (`Game.emit`): an event whose kind is in `Vision.SIGHTED` (`work_started`, `work_finished`,
`work_cancelled`, `town_grew`, `district_declined`, `army_raised`, `army_disbanded`, `army_starved`, `unit_lost`) with a
`hex` and no `witnesses` gets `witnesses` = the tags whose sight holds the hex, the actor always among them, in id order.
`unit_moved` carries the tags whose sight at the movement phase's start holds a hex of its path, the actor among them.
`march_halted` carries `witnesses: [tag]` (as M4's `goods_short`). `owners_changed`, `tax_set`, `country_chosen` stay public.

**Events** (the fields besides `kind` and `turn`; one typed signal each; `Session` drains them after every action and phase):

| Kind | Fields | Emitted by | Notable | Typed signal | Heard by |
|---|---|---|---|---|---|
| `army_raised` | `tag`, `hex`, `army`, `units` (ids), `kind`, `count`, `men`, `ducats`, `goods` ({key: loads}), `witnesses` | `Military.raise` | yes | `army_raised(tag, hex, army)` | `ArmyTokens`, `ArmyPanel`, `RaiseList`, `ResourceChips`, task flag; through `chronicled`: log, notifications (others'), ribbons ("Raised") |
| `army_disbanded` | `tag`, `hex`, `army`, `units`, `men`, `refund`, `witnesses` | `Military.disband` | yes | `army_disbanded(tag, hex, army)` | `ArmyTokens`, `ArmyPanel`, `RaiseList`, chips; log |
| `army_changed` | `tag`, `hex`, `army`, `gone` (bool) | `split_army`, `merge_armies`, `march`, `halt`, `continue_march`, `Military.refill` | no | `army_changed(tag, army)` | `ArmyTokens`, `ArmyPanel`, `PathMarks`, the reach layers, task flag, chips |
| `unit_moved` | `tag`, `army`, `path` (hexes, start first), `ticks` (the tick of each step), `seen` (`PackedByteArray`: 1 where `game.player` saw the step's hex or the army is the player's; all 1 when `game.player` is `&""`), `witnesses`, `arrived` | the movement phase | no | `unit_moved(tag, army, path, seen, ticks)` | `MoveReplay`, `ArmyTokens`, F3 |
| `march_halted` | `tag`, `army`, `hex`, `why` (`winter`, `blocked`, `no_way`), `reason`, `waits` (bool), `witnesses: [tag]` | the movement phase | yes | `march_halted(tag, army, why)` | `ArmyPanel`, task flag; log, notifications |
| `army_starved` | `tag`, `army`, `hex`, `lost`, `men` (left), `why` (`out_of_supply`, `stores_empty`), `witnesses` | the supply phase | yes | `army_starved(tag, army, lost)` | `ArmyTokens`, `ArmyPanel`, chips; log, notifications, ribbons ("Hunger −100") |
| `unit_lost` | `tag`, `army`, `unit`, `kind`, `hex`, `why` (`starved`; M7 `battle`), `army_left` (units left), `witnesses` | `Armies.lose_men` | yes | `unit_lost(tag, army, unit)` | `ArmyTokens`, `ArmyPanel`, chips; log, notifications |

`Chronicle.NOTABLE` gains the five notable kinds (fourteen). `SeasonSummary.COVERED` gains `army_starved` and `unit_lost`
(their toasts drop while a season runs; the report holds them).

**Log lines** (`LogLines.line_of`; others' lines only when witnessed):

| Kind | The player's line | A witnessed other's |
|---|---|---|
| `army_raised` | "You raised 2 companies of pikemen at Turin (5, 9) (−50 ducats)." keyword "Raised", plain, filters all, mine, money; `floating` "Raised" | "Milan raised 2 companies at Novara (7, 8): about 1,000 men." keyword "Raised", warn, all; `notify` true |
| `army_disbanded` | "You disbanded 1 company of pikemen of the Army of Turin (+25 ducats back)." plain, all, mine (money when refunded) | "Milan disbanded about 500 men at Novara (7, 8)." muted, all |
| `march_halted` | winter: "The Army of Turin waits for spring at Susa (4, 9): the Mont Cenis is closed by snow." warn; else "The Army of Turin halted at Susa (4, 9): no way to (3, 8) near Hospice Mont Cenis by land." warn; all, mine; `notify` true; `floating` "Halted" | (never witnessed) |
| `army_starved` | "The Army of Turin lost 100 men to hunger at Hospice Mont Cenis (3, 9): out of supply." bad, all, mine; `notify` true; `floating` "Hunger −100" | "A Milanese army lost men to hunger at (8, 3) near Bellinzona." muted, all |
| `unit_lost` | "A company of pikemen of the Army of Turin is gone: starved at Hospice Mont Cenis (3, 9)." bad, all, mine; `notify` true | "A Milanese company starved at (8, 3) near Bellinzona." muted, all |

No new filter: army lines show in All and Mine (raises with money in Money); M7 adds them to War.
Places in the army sentences come from `Words.at` (5.6): "at Susa (4, 9)", "at Hospice Mont Cenis (3, 9)" (the saddles'
named places are their hospices), "to (3, 8) near Hospice Mont Cenis" for an unnamed hex.

### 4.12 What you may know of others

| Thing | You see |
|---|---|
| Another country's army on the map, its token, its hover card | only on hexes you see; its men banded (`Knowledge.band`: "about 1,000 men"); no company count, no order |
| Its men under arms (Rankings, Standing, the country panel) | when `Knowledge.knows`, banded |
| Its raises, disbands, hunger, losses | the chronicle lines you witnessed |
| Its routes, orders, supply, upkeep | nothing |
| The viewer `&""` (tests, the sandbox) | everything, exact |

### 4.13 Worked examples

All on "Italy, 1480", **seed 1480**, as Savoy, Normal taxes, calm weather (`weather_odds = [100, 0, 0]` in the tests'
defs copy, as M4's), people growing (the real rules). The numbers were worked out from the map data and the rules above
for this page; `tests/core/test_army_savoy.gd` pins them (`tests/core/army_fixture.gd`, `ArmyFixture.savoy()`).

**(a) Raising at Turin, Spring 1480.** Savoy: treasury 1,500, iron 20 in store. Turin (5, 9), a town of 10,000 people:
1,000 men at hand on the hex (6,300 with its ring: Vercelli, Ivrea, Susa and Chivasso 1,000 each, (5, 8) 500,
(6, 10) 800), a cap of 2 companies. `raise {hex: (5, 9), kind: 0, count: 2}`: ledger line "Raised: 2
companies of pikemen at Turin (5, 9)" −50; iron −2 (flow `raise`); Turin 10,000 → 9,000 people (flow `raised` 1,000); the
Army of Turin, units 1 and 2, 1,000 men, order none, mustering. A third raise: "Turin (5, 9) has raised its 2 companies
this season". Spring's income: "Army upkeep, 1 army" −12. The supply phase: Turin is a depot; 1,000 men need 1 grain.

**(b) Across the Po.** Ordered to Vercelli (6, 9) in Spring: the route is the one step over the wooden bridge (2 points).
The army musters in Spring's movement phase; in Summer's it walks the step (tick 1); `unit_moved {path: [(5, 9), (6, 9)],
ticks: [1], arrived: true}`; from Autumn 1480 it holds at Vercelli.

**(c) Across a pass.** Ordered from Vercelli to (3, 8) in Autumn 1480: the route (15 points) is Turin (5, 9) 2, (5, 8) 6,
(4, 7) 8, the Little St Bernard saddle (3, 7) 10, (3, 8) 15 across the saddle's pass edge on a track. Autumn's phase walks
to (3, 7) (10 of 12 points; the next step costs 5); Winter's: the pass edge (3, 7)–(3, 8) is CLOSED (both hexes snow
winter); the winter detour costs 61 points against the summer route's 5, past the rule of D20, so the army **waits for
spring** at (3, 7) (`march_halted {why: winter, waits: true}`); Spring 1481's phase walks the last step. (3, 7) lies within
Aosta's reach (in supply), in winter too.

**(d) The Mont Cenis saddle.** The army of (a), ordered from Turin to (3, 9) in Spring 1480, musters in Spring and walks
in Summer (11 points: Susa 2, the saddle 9): out of supply (no depot within 8 supply points), snow cover with no people:
the land feeds no one. Summer's supply phase takes `ceil(1,000 × 100 / 1000)` = 100 men (900 left), Autumn's 90 (810), Winter
1480's a fifth (`starve_permille` 200 in the snow winter): 162 (648). In Winter the saddle's three pass edges are CLOSED,
but its edge to Susa (4, 9) is no pass edge: ordered back to Turin in Winter, the army walks Susa (2, Susa being frost
winter) and Turin (2) that season. The test pins each season's men.

**(e) Upkeep and the report of Spring 1480** (raising at Turin): Treasury: "Raised: 2 companies of pikemen at Turin (5, 9)
▼ −50", "Army upkeep, 1 army ▼ −12"; Goods: "Iron 18 ▼ −2 (for raising 2)", "Grain ... (eaten by the army 1)"; Armies:
"Men under arms 0 → 1,000 ▲ +1,000"; "Army of Turin at Turin (5, 9): 1,000 men, mustering."; Your orders: "Raised 2
companies of pikemen at Turin (5, 9) (▼ −50)." and, when ordered, "Ordered to march: the Army of Turin to Vercelli (6, 9).".

### 4.14 The season report after M6

`SeasonSummary.of` (M3 to M5) gains the `armies` section and army lines in the others (`SECTIONS`: glance, before,
treasury, goods, works, people, **armies**, orders, befell, standing):

| Id | M6 content |
|---|---|
| `glance` | after People: **Men under arms** (the closing value, the change), when the viewer had armies this season or the last |
| `before` | the reminders of 4.15 |
| `treasury` | "Raised: <units> at <place>" per raise line; "Army upkeep, n armies"; refunds of raises "Refund: <units>" |
| `goods` | the flow words "eaten by the army" (`army`) and "for raising" (`raise`) in `detail` |
| `armies` | `total` "Men under arms 1,000 → 900" (Stats `army_men` of the season before and this one); a line per army of the viewer that moved, changed men, starved or musters: "Army of Turin: Turin (5, 9) → Vercelli (6, 9), 1,000 men." (`moved_from`), "Army of Turin at Hospice Mont Cenis (3, 9): 900 men ▼ −100, out of supply." (a link to the army); lines of the season's `unit_lost` of the viewer; `sub` "Upkeep: 12 ducats a season." and "Your armies ate 1 grain from the stores." Rank: `|men change|`, moved armies 1 |
| `orders` | from the action log of the turn: "Raised 2 companies of pikemen at Turin (5, 9) (▼ −50).", "Ordered to march: the Army of Turin to Vercelli (6, 9).", "Ordered to hold: the Army of Turin.", "Split the Army of Turin.", "Joined the Second Army of Turin to the Army of Turin.", "Disbanded 1 company of pikemen of the Army of Turin (+25 ducats back)." |
| `befell` | M3 to M5's, now with real witnesses; plus others' witnessed `army_raised`, `army_disbanded`, `army_starved`, `unit_lost`; and, for the season that just ended only, one line per foreign army the viewer sees now: "A Milanese army of about 1,000 men stands at Alessandria (7, 9)." (a link) |
| `standing` | M5's line with "and k-th in men under arms (1,000)"; each known country's line adds "about N men" |

**Quiet** (M3 to M5's rule, plus): no army event, no march, and the men under arms changed under 2 %.

### 4.15 Reminders after M6

`Reminders.RULES`: `treasury_empty`, `hunger`, **`army_hungry`**, **`army_stores`**, `goods_running_out`, `winter_halt`,
**`winter_passes`**, `treasury_falling`, `town_full`, **`army_idle`**, `free_slot`; worst first (severity, then this order).

| Rule | When | Severity | Text | Action |
|---|---|---|---|---|
| `army_hungry` | an army of the player stands out of supply now (`Supply.in_supply` false) and its route does not end this season in supply, or lost men in the last supply phase | 2 | "The Army of Turin at Hospice Mont Cenis (3, 9) is out of supply: it lost 100 men and will lose about 90 more." (two or more: "2 armies are out of supply: ...") | `[&"select_army", id]`, "Show the army" |
| `army_stores` | the grain and fish in store are under the supplied armies' food of this season (`EconomySeason.needs_of(...).army_food`) | 2 | "Your stores cannot feed your armies: 0 grain for 1 needed. Unfed men starve." | `[&"study", &"military"]`, "Open Military" |
| `winter_passes` | Autumn, and `Movement.walk_plan` of a march of the player's has it wait in Winter at a pass edge that closes then (its route crosses that edge after this season's walk) | 1 | "Winter closes the Little St Bernard: the Army of Turin waits for spring at Hospice Little St Bernard (3, 7) unless it crosses this season." | `[&"select_army", id]` |
| `army_idle` | an army of the player has no order (new, or halted) | 1 | "1 army awaits orders: the Army of Turin at Turin (5, 9)." / "2 armies await orders: the Army of Turin and the Second Army of Turin." | `[&"select_army", first id]`, "Show the army" |

The action `[&"select_army", id]` is new (the task flag, the report's buttons and the App understand it: select the army,
glide there).

### 4.16 Stats after M6

`Stats.SERIES` gains, appended: `army_raised` (men raised this season, refills not counted), `army_starved` (men lost to
hunger this season): **42** series. `StatsSystem.season` writes per country: `army_men` (its armies' men after the supply
phase), `upkeep_army` (the season's ledger line, positive), `losses` (all men its armies lost this season: hunger in M6,
battle from M7), `army_raised`, `army_starved`. The goods ring's `used` adds the flows `army` and `raise`.

### 4.17 Saves and the digest

| Body key | M6 adds | In `Game.digest()` |
|---|---|---|
| `format` | 4 (`SaveFile.FORMAT`; `OLDEST_FORMAT` 4) | no |
| `armies` (**new**) | `{schema: "hexa-godot/armies/1", next_army_id, next_unit_id, list: [Army.to_dict()]}` (each army's units inside it, `unit/1`) | `Armies.digest(game)`: each army's `digest_text()` in id order and the two counters |
| `countries` | `country/4`: `explored` (a `PackedByteArray`, kept packed) | each `digest_text()` adds the sha256 of `explored` |
| `stats` | the two series (by name) | `Stats.digest()` |
| `action_log` | the M6 actions | no (M3 D22) |
| (not saved) | `game.sight` (`SightCache`), `game.supplies` (`SupplyCache`), `StepCosts` | no |

`Game.digest()` after M6: M5's string with `|` + `Armies.digest(game)` after the countries' texts. `Snapshot.restore`
type-checks every army and unit field and refuses `country/3`. Sizes on the made-up Europe with 600 armies of 4 units:
about 150 bytes an army, 0.09 MB; the explored bitsets 60 x 15 KB, 0.9 MB before compression, mostly equal runs.

---

## 5. Interfaces

Layers as the standard: `defs`, `state`, `systems`, `game`, `views`, `shell`. `core/` makes no engine calls and draws no
luck in M6. New files are marked **new**; "(M2)" to "(M5)" and "(M1.5)" name pieces those milestones build. Every amount
is an `int`.

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/unit_def.gd  (new)
class_name UnitDef extends Resource
const BRANCHES: Array[StringName] = [&"infantry", &"missile", &"cavalry", &"artillery"]
@export var id: int                                  # 0..3: its place in GameDefs.units
@export var key: StringName                          # &"pikemen"
@export var name: String                             # "Pikemen"
@export var one: String                              # "company of pikemen"
@export var many: String                             # "companies of pikemen"
@export var branch: StringName                       # one of BRANCHES
@export var era: int = 1
@export var men: int                                 # at full strength
@export var cost: int                                # ducats to raise one
@export var cost_goods: Dictionary[String, int] = {} # good key -> loads per unit
@export var upkeep: int                              # ducats a season at full strength
@export var mp: int                                  # move points a season
@export var sight: int = 1
@export var min_level: int = 1                       # the settlement level that may raise it
@export var refill: int                              # men regained a season in supply at home
@export var figure: StringName                       # the Kit icon of its token figure: &"fig_infantry"
func validate(defs: GameDefs) -> Array[String]       # key form; branch known; men, cost, upkeep, mp > 0; sight 1..3;
	# min_level 1..5; refill 1..men; cost_goods keys known goods, loads > 0; figure not empty

# core/defs/terrain_def.gd  (new)
class_name TerrainDef extends Resource
@export var id: int                                  # the MapData.cover number, 0..7
@export var key: StringName                          # MapTiles.COVERS[id]: &"farmland"
@export var name: String                             # "Farmland"
@export var move: int                                # move points to enter at relief 0 to 3
@export var forage_permille: int                     # its people fed as soldiers a season, permille
func validate() -> Array[String]                     # key matches the id; move 1..20; forage 0..1000

# core/defs/game_defs.gd  (M2 to M5, edit)
@export var units: Array[UnitDef] = []               # 4, external, in id order
@export var terrains: Array[TerrainDef] = []         # 8, external, in cover order
@export var relief_move_add: PackedInt32Array        # 7 relief levels: 0, 0, 0, 0, 1, 2, 3
@export var highway_cap := 1
@export var road_cap := 2
@export var track_divisor := 2
@export var winter_snow_percent := 200
@export var pass_closing_climate := 0                # a pass edge beside this winter closes in winter (0 snow)
@export var stream_cost := 1
@export var river_cost := 2                          # a class 1 river with no crossing
@export var ford_cost := 1
@export var ferry_cost := 2
@export var river_wade_class := 2                    # this class with no crossing takes a season to wade
@export var river_wall_class := 3                    # from this class on, no crossing means no way
@export var wade_plan_cost := 12
@export var supply_reach := 8
@export var supply_wade_cost := 3
@export var depot_min_level := 2
@export var army_food_milli := 200                   # loads a season per 1,000 men, thousandths
@export var forage_percent: PackedInt32Array         # 6 slots: 100, 100, 100, 0, 50, 100
@export var forage_loss_permille := 20
@export var starve_permille: PackedInt32Array        # 6 slots: 100, 100, 100, 200, 150, 100
@export var stack_limit := 8
@export var march_seasons_max := 12
@export var wait_ratio_percent := 200
@export var wait_extra_seasons := 2
@export var land_sight := 1
func unit_def(id: int) -> UnitDef                    # null when out of range
func terrain(cover: int) -> TerrainDef               # null when out of range
# validate() adds: 4 units with ids 0..3 once each; 8 terrains in cover order; arrays sized (7, 6, 6); every cap and cost
# 1..20; river_wade_class < river_wall_class, both 1..3; supply_reach 1..40; stack_limit 1..20; percents 0..400;
# army_food_milli 1..5000; forage_loss_permille 0..1000; depot_min_level 1..5; march_seasons_max 1..40;
# wait_ratio_percent 100..1000; wait_extra_seasons 0..12; land_sight 1..3; pass_closing_climate 0..2

# core/defs/family_def.gd  (M3 to M5, edit)
@export var raise_cap: PackedInt32Array              # settlements: per level, companies a season (0, 1, 1, 2, 3, 4); empty otherwise
```

`data/defs/goods/horses.tres` and `copper.tres` (M4) get `reserve_fixed` 10 and 5; nothing else of M4's goods changes.

### 5.2 State (`core/state/`)

```gdscript
# core/state/unit.gd  (new): a company
class_name Unit extends RefCounted
const SCHEMA := "hexa-godot/unit/1"
var id: int
var kind: int                     # UnitDef id
var men: int
var home: Vector2i                # the hex it was raised on
var raised_turn: int
var paid: int = 0                 # ducats paid (its refund in its raising season)
var paid_goods: Dictionary = {}   # good key (String) -> loads
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> Unit          # null on a wrong schema or a mistyped field
func digest_text() -> String      # "id|kind|men|c,r|raised_turn|paid|good:n,..."

# core/state/army.gd  (new)
class_name Army extends RefCounted
const SCHEMA := "hexa-godot/army/1"
const NO_HEX := Vector2i(-1, -1)
const ORDER_NONE := &""
const ORDER_HOLD := &"hold"
const ORDER_MARCH := &"march"
var id: int
var tag: StringName
var name: String
var hex: Vector2i
var units: Array[Unit] = []       # id order
var order: StringName = ORDER_NONE
var goal: Vector2i = NO_HEX
var route: PackedInt32Array       # hex indices, the next step first, the goal last
var waiting: StringName = &""     # &"winter" while it waits for spring
var halt_why: StringName = &""    # &"blocked", &"no_way" after a halt (order none, goal kept)
var halt_text: String = ""
var moved_from: Vector2i = NO_HEX # its hex before the last movement phase; NO_HEX when it did not move
var supply: int = 0               # the last supply phase: 0 fed from the stores, 1 fed by the land, 2 hungry
var lost_last: int = 0            # men lost in the last supply phase
var created_turn: int
func men() -> int
func mustering(turn: int) -> bool # a unit has raised_turn == turn
func unit(id: int) -> Unit        # null when not in it
func to_dict() -> Dictionary      # plain: StringName as String, route packed
static func from_dict(d: Dictionary) -> Army          # null on a wrong schema, a bad unit or a mistyped field
func digest_text() -> String      # "id|tag|name|c,r|created_turn|order|goal|route|waiting|halt_why|halt_text|moved_from|
	# supply|lost_last|" + each unit's digest_text

# core/state/country.gd  (M2, M4, M5, edit): schema "hexa-godot/country/4" (country/3 refused: D40)
var explored: PackedByteArray     # Vision: bit i is set when hex i was ever seen
# digest_text() appends "|" + explored.sha256 (hex)

# core/state/stats.gd  (M3 to M5, edit): SERIES appends "army_raised", "army_starved" (42)

# core/game/game.gd  (M1 to M5, edit; fields below)
var armies: Array[Army] = []      # Armies; id order
var next_army_id: int = 1         # Armies
var next_unit_id: int = 1         # Armies
var sight: SightCache = SightCache.new()        # the door's derived cache; not saved, not in the digest
var supplies: SupplyCache = SupplyCache.new()   # the same
```

### 5.3 Systems (`core/systems/`)

Systems never call `Words` (a view, M3). Their check words name a hex by `Military.hex_text`: "Turin (5, 9)" when the
hex holds a named place (`Improve.place_of`, M1), else "(3, 8)"; a country by its `CountryDef` name ("the Duchy of
Milan"). The panels and the log use `Words.at` (5.6) on the same hexes.

```gdscript
# core/systems/step_costs.gd  (new): the step table, filled a hex at a time on first use; keyed by map and defs
class_name StepCosts extends RefCounted
const CLOSED := 253
const WADE := 254
const BLOCKED := 255
static func of(map: MapData, defs: GameDefs) -> StepCosts     # one table per (map, defs) pair (a static memo)
static func compute(map: MapData, defs: GameDefs, i: int, direction: int, winter: bool) -> int   # 4.3, the pure rule
func cost(i: int, direction: int, winter: bool) -> int         # from the table (filled on first use)
func supply_cost(i: int, direction: int, winter: bool) -> int  # WADE -> supply_wade_cost; CLOSED -> BLOCKED
func filled() -> int                                           # hexes filled (F3, perf)
static func clear_all() -> void                                # tests

# core/systems/path_search.gd  (new): Dial's bucket queue on integer costs
class_name PathSearch extends RefCounted
const INF := 1 << 30
# Pure: it knows no country. `allowed` has one byte a hex (1: the searcher may stand there), made by the caller
# (Movement.open_mask for armies, the country's own land for supply).
static func route(map: MapData, steps: StepCosts, allowed: PackedByteArray, from: Vector2i, goal: Vector2i, winter: bool,
		max_cost: int, wade_cost: int) -> Dictionary
	# A*, h = hex distance; WADE at wade_cost; CLOSED and BLOCKED not entered; {ok, cost, hexes: PackedInt32Array}
static func reach(map: MapData, steps: StepCosts, allowed: PackedByteArray, from: Vector2i, budget: int, winter: bool) -> Dictionary
	# a bounded Dijkstra with the walk's WADE rule (only at cost 0, spending the budget); {hex index: cost}
static func field(map: MapData, steps: StepCosts, allowed: PackedByteArray, starts: PackedInt32Array, budget: int,
		winter: bool, supply: bool) -> PackedInt32Array
	# multi-source; cost per hex, INF unreached; supply = true uses StepCosts.supply_cost
static func cost_field(map: MapData, steps: StepCosts, allowed: PackedByteArray, goal: Vector2i, winter: bool) -> PackedInt32Array
	# the whole-map cost to goal from every allowed hex (reverse steps): M8's march

# core/systems/armies.gd  (new): the only writer of armies and men
class_name Armies extends RefCounted
const OWNS: Array[String] = ["armies", "next_army_id", "next_unit_id"]
static func by_id(game: Game, id: int) -> Army                  # null when none
static func of_country(game: Game, tag: StringName) -> Array[Army]   # id order
static func at(game: Game, hex: Vector2i) -> Array[Army]        # id order
static func units_at(game: Game, tag: StringName, hex: Vector2i, leaving: PackedInt32Array = PackedInt32Array()) -> int
static func men_of_country(game: Game, tag: StringName) -> int
static func create(game: Game, tag: StringName, hex: Vector2i, name: String) -> Army
static func add_units(game: Game, army: Army, kind: int, count: int, raised_turn: int, home: Vector2i, paid: int, paid_goods: Dictionary) -> PackedInt32Array
static func lose_men(game: Game, army: Army, amount: int, why: StringName) -> int   # spread (4.8); unit_lost at 0;
	# removes an empty army; returns the men lost
static func add_men(game: Game, army: Army, unit_id: int, amount: int) -> int        # refill; capped at full
static func remove_units(game: Game, army: Army, ids: PackedInt32Array) -> Array[Unit]
static func move_units(game: Game, from_army: Army, to_army: Army, ids: PackedInt32Array) -> void
static func remove(game: Game, army: Army) -> void
static func set_hex(game: Game, army: Army, hex: Vector2i, moved_from: Vector2i) -> void
static func set_order(game: Game, army: Army, order: StringName, goal: Vector2i, route: PackedInt32Array) -> void
static func set_route(game: Game, army: Army, route: PackedInt32Array) -> void
static func set_halt(game: Game, army: Army, why: StringName, text: String) -> void
static func set_waiting(game: Game, army: Army, waiting: StringName) -> void
static func set_supply(game: Game, army: Army, state: int, lost: int) -> void
static func clear_moved(game: Game) -> void                     # moved_from = NO_HEX for all, at the phase's start
static func to_dict(game: Game) -> Dictionary
static func from_dict(d: Dictionary, game: Game) -> String       # "" or the problem; fills game.armies and the counters
static func digest(game: Game) -> String

# core/systems/military.gd  (new): raising, disbanding, splitting, merging, refill, upkeep
class_name Military extends RefCounted
const OWNS: Array[String] = []                    # writes through Armies, People, Treasury, Stores
const ORDINALS: Array[String] = ["Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth"]
static func unit_def(game: Game, kind: int) -> UnitDef
static func stack_limit(game: Game, tag: StringName) -> int     # GameDefs.stack_limit (M7 adds generals)
static func raise_cap(game: Game, hex: Vector2i) -> int         # FamilyDef.raise_cap of the settlement's level; 0 none
static func raised_here(game: Game, tag: StringName, hex: Vector2i) -> int
static func men_at_hand(game: Game, tag: StringName, hex: Vector2i) -> int
static func can_stand(game: Game, tag: StringName, hex: Vector2i, adding: int, leaving: PackedInt32Array = PackedInt32Array()) -> String
	# 4.4's room: "" or the words of 4.7 row 7
static func cost_of(game: Game, kind: int, count: int) -> Dictionary   # {ducats, goods: {key: loads}}
static func upkeep_of(game: Game, army: Army) -> int
static func upkeep_country(game: Game, tag: StringName) -> int
static func raise_options(game: Game, tag: StringName, hex: Vector2i) -> Array[Dictionary]
	# a row per UnitDef: {kind, name, men, mp, verdict (raise_check with count 1), cost_text ("25 · 1 iron")}
static func army_name(game: Game, tag: StringName, hex: Vector2i) -> String   # D37 (its own search of map.place_id, rings 0 to 2)
static func hex_text(game: Game, hex: Vector2i) -> String     # "Turin (5, 9)", "(3, 8)": the check words' place
static func raise_check(game: Game, args: Dictionary) -> Dictionary       # {hex, kind, count, tag}; 4.5
static func raise(game: Game, args: Dictionary) -> Dictionary
static func disband_check(game: Game, args: Dictionary) -> Dictionary     # {army, unit, tag}; 4.6
static func disband(game: Game, args: Dictionary) -> Dictionary
static func split_check(game: Game, args: Dictionary) -> Dictionary       # {army, units: PackedInt32Array, tag}
static func split_army(game: Game, args: Dictionary) -> Dictionary
static func merge_check(game: Game, args: Dictionary) -> Dictionary       # {army, into, tag}
static func merge_armies(game: Game, args: Dictionary) -> Dictionary
static func refill(game: Game) -> void                                    # the ready_units phase (4.9)

# core/systems/movement.gd  (new)
class_name Movement extends RefCounted
const OWNS: Array[String] = []                    # writes through Armies and Vision
static func mp_of(game: Game, army: Army) -> int
static func winter_now(game: Game) -> bool        # Calendar.is_winter(game.turn)
static func open_to(game: Game, tag: StringName, hex: Vector2i) -> bool
static func hostile(game: Game, a: StringName, b: StringName) -> bool    # false in M6 but registered test pairs
static func register_test_hostility(a: StringName, b: StringName) -> void
static func clear_test_hostility() -> void
static func zoc_halts(game: Game, tag: StringName, hex: Vector2i) -> bool
static func open_mask(game: Game, tag: StringName) -> PackedByteArray   # open_to for every hex; cached [&"open", version, tag]
static func plan(game: Game, army: Army, goal: Vector2i) -> Dictionary    # 4.4: {ok, hexes, cost, waits, reason}
static func walk_plan(game: Game, army: Army, route: PackedInt32Array, from_turn: int) -> Dictionary   # 4.4
static func winter_wait(game: Game, army: Army) -> Dictionary             # D20: {waits, pass_name, detour: PackedInt32Array}
static func march_check(game: Game, args: Dictionary) -> Dictionary       # {army, goal, tag}; 4.7
static func march(game: Game, args: Dictionary) -> Dictionary
static func halt_check(game: Game, args: Dictionary) -> Dictionary        # {army, tag}
static func halt(game: Game, args: Dictionary) -> Dictionary
static func continue_check(game: Game, args: Dictionary) -> Dictionary    # {army, tag}
static func continue_march(game: Game, args: Dictionary) -> Dictionary
static func season(game: Game) -> void                                    # the movement phase (4.4)
static func cost_field(game: Game, tag: StringName, goal: Vector2i) -> PackedInt32Array   # PathSearch.cost_field with
	# open_mask and this season's rules

# core/systems/supply.gd  (new)
class_name Supply extends RefCounted
const OWNS: Array[String] = []                    # writes through Armies, Stores, People
const FED := 0
const FORAGED := 1
const HUNGRY := 2
static func is_depot(game: Game, tag: StringName, hex: Vector2i) -> bool
static func field(game: Game, tag: StringName, winter: bool) -> PackedByteArray   # 4.8, from game.supplies
static func in_supply(game: Game, tag: StringName, hex: Vector2i, winter: bool) -> bool
static func forage_cap(game: Game, view: StateView, hex: Vector2i, season: int) -> int
static func food_need(game: Game, men: int) -> int
static func starve_loss(game: Game, hex: Vector2i, season: int, unfed: int) -> int
static func country_step(game: Game, view: StateView, tag: StringName, season: int, stock: PackedInt32Array, armies: Array[Dictionary]) -> Dictionary
	# pure: armies [{id, hex, men, units: [{id, men}]}] -> {food_taken: {good: n}, fed, foraged: {hex index: people},
	#  losses: {army id: men}, states: {army id: 0|1|2}}
static func season(game: Game) -> void            # the supply phase (4.8)

# core/systems/supply_cache.gd  (new): the door's derived cache of supply fields
class_name SupplyCache extends RefCounted
func field_of(game: Game, tag: StringName, winter: bool) -> PackedByteArray
func forget(tag_id: int) -> void
func clear() -> void

# core/systems/vision.gd  (new)
class_name Vision extends RefCounted
const OWNS: Array[String] = ["explored"]
const SIGHTED: Array[String] = ["work_started", "work_finished", "work_cancelled", "town_grew", "district_declined",
	"army_raised", "army_disbanded", "army_starved", "unit_lost"]
static func setup(game: Game) -> void             # explored = land sight; called by new_scenario and on load (no explored)
static func refresh(game: Game) -> void           # rebuilds the army part of game.sight
static func sees(game: Game, tag: StringName, hex: Vector2i) -> bool
static func witnesses_of(game: Game, hex: Vector2i, actor: StringName) -> PackedStringArray
static func see_path(game: Game, tag: StringName, hexes: Array[Vector2i], radius: int) -> void   # explored along a walk
static func explored(game: Game, tag: StringName, hex: Vector2i) -> bool
static func explored_any(game: Game, viewer: StringName, other: StringName) -> bool
static func season(game: Game) -> void            # the vision phase: refresh, then explored |= sight

# core/systems/sight_cache.gd  (new): the door's derived cache: per country a land-sight bitset and an army-sight bitset
class_name SightCache extends RefCounted
func land_of(game: Game, tag_id: int) -> PackedByteArray
func armies_of(game: Game, tag_id: int) -> PackedByteArray
func forget_land(tag_id: int) -> void
func clear() -> void

# core/systems/treasury.gd  (M4, edit): WHY appends &"upkeep_army", &"raise"; SPENDING appends &"raise"
# core/systems/stores.gd  (M4, edit): FLOWS appends &"army", &"raise"
# core/systems/people.gd  (M5, edit): FLOWS appends &"foraged"
# core/systems/economy_season.gd  (M4, M5, edit): needs_of adds army_food (4.9); reserve_of keeps it;
#   money_lines(game, view, tag, tax, content, sold, made_info, army_upkeep: int = 0) adds the upkeep_army line
# core/systems/stats_system.gd  (M3 to M5, edit): 4.16
```

**OWNS after M6** (`tests/core/test_owns.gd` diffs `Snapshot.of` around every action and phase):

| Field | Written by | In an action | In a phase |
|---|---|---|---|
| `armies`, `next_army_id`, `next_unit_id` | `Armies` | `raise`, `march`, `halt`, `continue_march`, `split_army`, `merge_armies`, `disband` | `movement`, `supply`, `ready_units` |
| `explored` | `Vision` | no | `movement` (`see_path`), `vision` |
| `treasury`, ledgers | `Treasury` | `raise`, `disband` (refund); M4's | `income` (upkeep_army); M4's |
| `stock`, flows | `Stores` | `raise`, `disband` (refund); M4's | `supply` (army); M4's |
| `people`, `people_flows` | `People` | `raise` (levy), `disband` (give back); M5's | `supply` (foraged), `ready_units` (levy); M5's |
| everything of M5's table | as M5 5.3 | | |
| `events`, `action_log`, `chronicle`, `version`, `view_cache`, `districts`, `sight`, `supplies` | `Game` (the door; `DOOR_FIELDS` gains `sight`, `supplies`) | yes | yes |

### 5.4 Game, the action table, the season, saves (`core/game/`)

```gdscript
# core/game/game.gd  (M1 to M5, edit)
const DOOR_FIELDS: Array[String] = ["events", "action_log", "chronicle", "version", "view_cache", "districts", "sight", "supplies"]
func emit(event: Dictionary) -> void      # M5's, plus: Vision.SIGHTED kinds with a hex get witnesses (4.11); owners_changed
	# calls sight.forget_land and supplies.forget for the countries in tag and others; hex_changed on a settlement hex calls
	# supplies.forget for its owner
# new_scenario: after People.setup: Vision.setup (explored), Vision.refresh. A map-only game (new_game, with_state) has no
#   armies and no sight (the viewer &"" sees all)
# dev_transfer (M3): Vision.refresh after the transfer
# digest(): 4.17

# core/game/actions.gd  (M3, M4, edit)
const NAMES: Array[String] = ["build", "upgrade", "clear", "cancel_work", "choose_country", "set_tax",
	"raise", "march", "halt", "continue_march", "split_army", "merge_armies", "disband"]
#   raise {hex, kind, count, tag}  march {army, goal, tag}  halt {army, tag}  continue_march {army, tag}
#   split_army {army, units, tag}  merge_armies {army, into, tag}  disband {army, unit, tag}
# pair_of: raise, split_army, merge_armies, disband -> Military's pairs; march, halt -> Movement's; continue_march ->
#   [Movement.continue_check, Movement.continue_march]

# core/game/season.gd  (M3 to M5, edit)
const PHASES: Array[StringName] = [&"movement", &"supply", &"production", &"income", &"works", &"people", &"stats",
	&"calendar", &"ready_units", &"vision"]
# run_phase: movement -> Movement.season; supply -> Supply.season; ready_units -> Military.refill; vision -> Vision.season

# core/game/snapshot.gd  (M3 to M5, edit): the armies key (Armies.to_dict / from_dict), country/4; restore runs
#   Vision.refresh after the game is rebuilt
# core/game/save_file.gd  (M3 to M5, edit): FORMAT := 4; OLDEST_FORMAT := 4
# core/game/replay.gd  (M3 to M5): unchanged (the M6 actions are played through Game.act)
```

### 5.5 Events and Session (`shell/autoload/`)

```gdscript
# shell/autoload/events.gd  (edit): added signals
signal army_raised(tag: StringName, hex: Vector2i, army: int)
signal army_disbanded(tag: StringName, hex: Vector2i, army: int)
signal army_changed(tag: StringName, army: int)
signal unit_moved(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray, ticks: PackedInt32Array)
signal march_halted(tag: StringName, army: int, why: StringName)
signal army_starved(tag: StringName, army: int, lost: int)
signal unit_lost(tag: StringName, army: int, unit: int)

# shell/autoload/session.gd  (edit)
# drain(): the seven kinds to their signals; then chronicled (M3) for the notable ones. last_phase_ms gains movement,
#   supply, ready_units, vision. act()/check(): a console "as TAG" passes its own tag (the existing rule: args with a tag
#   keep it)
```

### 5.6 Views (`core/views/`, pure)

```gdscript
# core/views/army_view.gd  (new)
class_name ArmyView extends RefCounted
static func tokens(game: Game, viewer: StringName) -> Array[Dictionary]
	# one per (hex, country) the viewer sees: {hex, tag, armies: PackedInt32Array, men, text ("450", "1.0k"; others "~1k"),
	#  exact: bool, figure (the figure of the kind with the most men), mustering, marching, waiting, hungry, mine};
	#  cached [&"tokens", version, viewer]
static func panel(game: Game, viewer: StringName, army_id: int) -> Dictionary
	# {} when unseen; {mine, id, name, tag, country (long name), hex, place, men, limit, here (units of its country on the
	#  hex), units: [{id, kind, name, men, full, raised_text, mustering}], order: {kind, text, goal, stops, arrives_text,
	#  waiting_text, halt_text}, supply: {state, text, fed_text, lost_last}, upkeep, mp, sight,
	#  others_here: [{id, name, men}]}; others' armies: {mine: false, country, hex, men_text ("about 1,000 men")}
static func needing_orders(game: Game, tag: StringName) -> PackedInt32Array   # order none first (id order), then the rest
static func token_text(men: int, exact: bool) -> String

# core/views/move_preview.gd  (new)
class_name MovePreview extends RefCounted
static func reach(game: Game, army_id: int) -> Dictionary
	# {season: PackedInt32Array (hex indices it can stand on at this season's end), next: PackedInt32Array (by the next
	#  season's end, current rules)}; mustering: season empty; cached [&"reach", version, army]
static func to(game: Game, tag: StringName, army_id: int, hex: Vector2i) -> Dictionary
	# {verdict (march_check), kind (&"go", &"note", &"refusal"), title (the place), hexes: Array[Vector2i],
	#  stops: [{hex, turn, text ("Summer 1480")}], arrives_turn, arrives_text, seasons,
	#  crossings: [{hex, to, kind (&"bridge", &"ford", &"ferry", &"wade", &"pass"), name}], winter: {pass, closes, waits},
	#  supply_end: {in_supply, feeds, loss}, lines: Array[Array] ([text, tone]), way_out}; cached [&"move", version, army, hex]

# core/views/supply_view.gd  (new)
class_name SupplyView extends RefCounted
static func at(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary
	# {shown, state (&"depot", &"in", &"winter_cut", &"out"), text ("In supply", "Out of supply: the land feeds about 90
	#  men a season", "In supply, cut off in winter"), feeds}; shown false off the viewer's land and unowned land

# core/views/cards_military.gd  (new): the Army chip's hover card
class_name MilitaryCards extends RefCounted
static func army(game: Game, tag: StringName) -> Dictionary
	# {value (men under arms), change (last season), title ("Men under arms"), lines: [["2 armies, 4 companies", ...],
	#  ["Upkeep a season", tone, amount], ["Out of supply", tone, "1 army"], ["Lost last season", tone, n]], hint
	#  ("Click: the Military page")}

# core/views/study_military.gd  (new)
class_name StudyMilitary extends RefCounted
static func of(game: Game, viewer: StringName, span: int) -> Dictionary
	# {has_armies, head: {men, armies, units, upkeep, share (permille of the left-over income)},
	#  rows: [{id, name, place, hex, men, units, upkeep, supply_text, order_text, tone}] (men descending, ties by id),
	#  seen: [{tag, country, hex, place, men_text}] (foreign armies in sight),
	#  labels, series: {army_men, upkeep_army, losses, army_starved, income} (Stats over the span)}
	# cached [&"study_military", version, viewer, span]

# core/views/replay_plan.gd  (new): the replay's schedule; reads events and a clock, never the game
class_name ReplayPlan extends RefCounted
const PACE := {&"normal": Vector2i(180, 6000), &"slow": Vector2i(320, 9000)}   # ms a step, ms in all
const MIN_STEP := 40
func record(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray, ticks: PackedInt32Array) -> void
func start(speed: StringName) -> bool               # false when nothing seen is recorded
func advance(ms: float) -> void
func active() -> bool
func skip() -> void
func poses() -> Array[Dictionary]                   # [{army, a: Vector2i, b: Vector2i, f: float, shown: bool}]
func step_ms() -> float

# core/views/knowledge.gd  (M3, edit): knows adds the explored clause (4.11)
static func sees(game: Game, viewer: StringName, hex: Vector2i) -> bool
static func armies_seen(game: Game, viewer: StringName) -> Array[Dictionary]   # foreign armies in sight: {army, tag, hex,
	# men_banded}; id order
# core/views/map_modes.gd  (M2, M4.5, M5, edit)
enum Mode { TERRAIN, OWNER, RELIEF, YIELDS, FOOD, SUPPLY }     # keys 1 to 6
const MODE_KEYS: Array[StringName] = [&"terrain", &"owner", &"relief", &"yields", &"food", &"supply"]
const SUPPLY_ALPHA := 0.70
const SIGHT_VEIL_ALPHA := 0.25
const SUPPLY_COLOURS: Array[Color] = [Color("#a8321a"), Color("#c8664c"), Color("#e2b97a"), Color("#9cb3d6"),
	Color("#4f79b8"), Color("#1f3f7a")]     # bytes 1 to 6 (6.6)
static func supply_bytes(game: Game, viewer: StringName) -> PackedByteArray   # cached [&"supply", version, viewer]
static func supply_ramp() -> PackedColorArray
static func sight_bytes(game: Game, viewer: StringName) -> PackedByteArray    # 1 seen, 0 not; cached [&"sight", version, viewer]
# legend(SUPPLY) and legend_title(SUPPLY) "Supply: where your armies are fed"; colour_of(..., supply_byte := 0)
# (bytes 1 striped like Yields' loss); modes(game) adds SUPPLY where FOOD is
# core/views/hex_card.gd  (edit): "Armies" (yours: "Army of Turin: 1,000 men, holding"; seen others: "Milan: about 1,000
#   men"), "Supply" on your land (SupplyView.at's text)
# core/views/country_card.gd  (edit): army: {shown, value, banded} (yours exact, known banded, else shown false)
# core/views/words.gd  (edit): men(n) "1,000 men"; units(n, def) "2 companies of pikemen"; army_of(game, tag) "A Milanese army";
#   at(game, hex, word = "at"): "at Susa (4, 9)", "to Vercelli (6, 9)"; an unnamed hex "to (3, 8) near Hospice Mont Cenis"
#   (the named place M3's Words.place picks: within 2 hexes, nearest, ties by place order); "at (3, 8)" with none. The
#   army sentences use it; M3 to M5's sentences keep Words.place
# core/views/economy_preview.gd  (M4 to M5, edit): D48: each previewed season runs Supply.country_step for the country's
#   armies where they stand, the refill, and the upkeep line; seasons[k] gains army_men, army_lost
# core/views/season_summary.gd, reminders.gd, log_lines.gd (edits): 4.11, 4.14, 4.15
# core/views/study_rankings.gd  (M4.5, M5, edit): MEASURES appends {id = &"army", title = "Men under arms", since = "6"}
```

---

## 6. The UI of M6

Built from the M1.5 kit and the M3 to M5 pieces. Colours and fonts from the Theme; HUD controls take no focus, screens do.
The App's milestone value becomes `"6"`, so the `since: "6"` rows of `Bindings.DEFAULTS` and `Settings.SCHEMA` register and
show.

### 6.1 Keys and settings

| Action (`Bindings.DEFAULTS`) | Key (Mac) | Since | Who hears it | Does |
|---|---|---|---|---|
| `map_command` (exists) | right click (two-finger click) | 1 | `MapInput.command_requested(map_px)` | with an army of yours selected: `march` there, or `halt` on its own hex; with none: the hex menu (6.8) |
| `game_next_unit` (exists) | Tab | 6 | `MapInput` -> `next_army_requested` | selects the next army of `ArmyView.needing_orders`, glides there |
| `game_continue_march` (exists) | R | 6 | `MapInput` -> `continue_march_requested` | `continue_march` for the selected army; a refusal toasts |
| `map_cursor_left`, `_right`, `_up`, `_down` (exist) | Alt+arrows (Option) | 6 | `MapInput` -> `cursor_moved(direction)` | no army selected: the selection moves (W, E; up and down keep the column: even rows NE/SE, odd rows NW/SW); an army selected: the order cursor moves and the route follows; the camera follows either |
| `map_command_key` (**new**, "Command at the cursor", group Map) | O, Shift+F10 | 6 | `MapInput` -> `command_key_requested` | a right click at the cursor (or the selection) |
| `view_mode_6` (**new**, "Map mode 6", group View) | 6 | 6 | `MapInput` -> `mode_requested(MapModes.Mode.SUPPLY)` | the Supply mode; M4.5's toasts in the sandbox and while picking |

`Bindings.GESTURES`: the right-click line reads "Right click (two-finger click): order the selected army; with none, the
hex menu" on every platform.

| `Settings.SCHEMA` key | Type, choices (default) | Page, row | Since |
|---|---|---|---|
| `game/movement` (exists) | `instant`, `normal`, `slow` (`normal`) | Game: "Movement replay speed" | 6 |
| `map/sight_veil` (**new**) | bool (true) | Map: "Shade what you cannot see"; also the Layers popover's "Sight" switch; `MapScene.configure` applies it | 6 |
| `state/map_mode` (M2 to M5) | choices gain `supply` | no row | |

### 6.2 Bake slice 5: the army pieces (`tools/ui_bake/pieces_m6.py`, new)

| Texture | Size (1x) | What |
|---|---|---|
| `army_plate` | 56 x 48 | a small hex plate, white with an ink edge (tinted the country's colour at run time) |
| `army_plate_ring` | 64 x 56 | the gold selection ring with a soft glow |
| `army_badge` | 36 x 18 | a brass-rimmed slot for the strength |
| `figures` (atlas, 32 px cells) | 128 x 32 | `fig_infantry` (a pikeman), `fig_missile` (a crossbowman: the stave across the chest, a kettle hat; battle-size-and-frontage 4.4's brief), `fig_cavalry` (a mounted knight), `fig_artillery` (a bombard on its bed) |
| `icons_army` (atlas, 24 px cells) | 192 x 48 | `march`, `hold`, `halted`, `wait_snow`, `muster`, `supply_ok`, `supply_out`, `forage`, `raise`, `disband`, `split`, `merge`, `bridge`, `ford`, `wade`, `pass_mark` |
| `path_stop` | 20 x 20 | a brass ring that holds a season's numeral on the route |

`build_theme.gd` adds them as `Kit` icons. `shell/ui/tokens.gd` gains `MAP_REACH #ffd64633`, `MAP_REACH_NEXT #ffd64614`,
`MAP_PATH #f6e3a1`, `MAP_PATH_WARN #f0806a`, `MAP_PATH_INK #0b0806` (the bake re-runs: `tokens_sha`). The art director signs
the token sheet (`bake_ui.py --sheet`): plates in all 13 colours with each figure, the badge, the ring, the icons.

### 6.3 The map: tokens, reach, route, cursor (`shell/map/`, `shell/mapview/`)

| z | What | Node | Since |
|---|---|---|---|
| 83 | the reach of this season and of the next (`mark/white` tinted `MAP_REACH`, `MAP_REACH_NEXT`) | `TileMapView` overlay layers `reach`, `reach_next` | M6 |
| 84 | the route and its season stops | `PathMarks` | M6 |
| 88 | army tokens, y-sorted among themselves | `ArmyTokens` | M6 |
| 90 | the selection and the order cursor (`mark/target`) | `marks` (M1) | M1, M6 |

```gdscript
# shell/map/army_tokens.gd  (new)
class_name ArmyTokens extends Node2D       # z_index 88, y_sort_enabled; one ArmyToken a (hex, country) from ArmyView.tokens
signal token_clicked(hex: Vector2i, tag: StringName)
func setup(view: TileMapView) -> void
func refresh(game: Game, viewer: StringName) -> void     # adds, updates and frees tokens to match ArmyView.tokens
func set_selected(army_id: int) -> void
func show_poses(poses: Array[Dictionary]) -> void         # the replay's: walking armies drawn between two hexes
func token_at(hex: Vector2i, tag: StringName) -> ArmyToken
# shell/map/army_token.tscn/.gd  (new)
class_name ArmyToken extends Node2D        # Plate (Sprite2D, army_plate tinted), Figure, Pennant (pennant_pole + cloth
	# tinted, M2's pieces), Badge (army_badge + Label in the Number font), State (a small icon: muster, march, wait_snow,
	# supply_out), Ring (army_plate_ring, when selected)
func show_token(token: Dictionary, colour: Color) -> void
# shell/map/path_marks.gd  (new)
class_name PathMarks extends Node2D        # z 84; _draw: the route as a polyline (MAP_PATH over a 2 px MAP_PATH_INK), the
	# legs beyond supply in MAP_PATH_WARN, a path_stop with the season's numeral at each stop, a crossing icon (bridge,
	# ford, wade, pass_mark) at each crossing; redraws only on show_route and clear
func show_route(preview: Dictionary) -> void
func clear_route() -> void
# shell/map/map_scene.gd  (M1 to M5, edit)
signal army_selected(army_id: int)
signal army_cleared
func select_army(army_id: int) -> void     # selects, rings the token, fills the reach, emits army_selected
func selected_army() -> int                # -1 none
func move_cursor(direction: int) -> void   # 6.1's rule; the order cursor with an army selected, else the selection
func cursor_hex() -> Vector2i
# shell/mapview/tile_map_view.gd  (M1, edit): OVERLAYS gains "reach": [83, ""] and "reach_next": [83, ""]
```

- **A token** stands on its hex's centre, 20 px above it, its foot (the y-sort origin) at the centre. Its badge shows
  `ArmyView.token_text`: men under 1,000 as the number, else thousands with one decimal ("1.0k"); others' banded ("~1k").
  Two or more armies of one country on a hex are one token; the hover card lists them. Below zoom 0.6 a token keeps its
  on-screen size (`scale = 0.6 / zoom`).
- **Selection.** A click on a hex with your token selects its first army (another click on the same token selects the
  next army there); Shift+click selects the hex itself; a click elsewhere selects that hex (M1). The army panel opens in
  the dock (6.5). Esc clears it (M1.5's ladder, the dock step).
- **Reach.** With an army of yours selected, `MovePreview.reach` fills `reach` and `reach_next`; a mustering army shows
  only `reach_next`.
- **The route.** The hovered hex (or the order cursor) asks `MovePreview.to`; `PathMarks.show_route` draws it at once (no
  tooltip delay; the preview is cached by hex). The move card (6.7) shows its words.
- **Orders on the map**: an army with a march shows its stored route in a thinner line while it is selected.
- **The replay**: while `MoveReplay` is active, `ArmyTokens.show_poses` draws the walking tokens between hexes; a step
  the player did not see hides the token for that step.

### 6.4 The movement replay (`shell/map/replay.gd`, new) and the season flow

```gdscript
class_name MoveReplay extends Node        # a World child, process_mode PAUSABLE; holds a ReplayPlan
signal finished
func record(tag: StringName, army: int, path: Array[Vector2i], seen: PackedByteArray, ticks: PackedInt32Array) -> void
	# Events.unit_moved
func start(speed: StringName) -> bool     # &"normal" | &"slow"; false when nothing to show
func skip() -> void
func active() -> bool
func poses() -> Array[Dictionary]
```

`SeasonFlow` (M3, edit) gains three callables, `replay_start` ((speed: StringName) -> bool), `replay_skip` (() -> void),
`hold_ribbons` ((on: bool) -> void), and `func replay_done() -> void`:

- **RUNNING:** `hold_ribbons(true)`; `Session.end_season()`; then `speed` = `game/movement` (`instant` under reduce
  motion); `instant`, or `replay_start(speed)` false: on to `DECISIONS`; else **REPLAY**.
- **REPLAY:** the map is live (not paused); `request_end` (Space, Enter, the End season plate) calls `replay_skip()`
  and starts no season; a click on the map pans and zooms but neither selects nor orders (the toast "The moves are still
  playing: Space skips them."; from M8 the block is `MapInput.block_orders`, `m8-build-spec.md` 6.2); `MoveReplay.finished`
  calls `replay_done()`: `DECISIONS` (empty until M7), then
  **REPORT** as M3.
- **Back to IDLE:** `hold_ribbons(false)` (the floaters' `hold(on)`, new: ribbons queued while held rise when released).
- Save is refused with "Wait for the season to end" while the flow is `RUNNING` or `REPLAY` (M3 D48).

### 6.5 The army panel (`shell/panels/army_panel.tscn/.gd`, new; in the dock)

```gdscript
class_name ArmyPanel extends PanelContainer    # a PanelFrame (M1.5) with the cartouche title
signal look_at_requested(hex: Vector2i)
signal army_requested(army_id: int)            # another army on the hex
func show_army(army_id: int) -> void           # ArmyView.panel(Session.game, Session.player_tag(), id)
func refresh() -> void
func clear() -> void
func shown_army() -> int
```

| Part | Content (from `ArmyView.panel`) |
|---|---|
| Title (cartouche) | the army's name |
| Head | `CountryArms` (small), "1,000 men · 2 of 8 companies here" (`Body`); the place as a link |
| Order | the order's text in `Body`, its tone: "Marching to (3, 8) near Hospice Mont Cenis: at Hospice Little St Bernard (3, 7) in Winter 1480, there in Spring 1481." / "Holding at Vercelli (6, 9)." / "Waits for spring at Hospice Little St Bernard (3, 7): the Little St Bernard is closed by snow." / "Halted at Susa (4, 9): no way to (3, 8) near Hospice Mont Cenis by land." / "Musters this season: marches from Summer 1480." / "Awaits orders."; buttons **Hold** (`halt`), **Continue march** with a `KeyCap` of R (`continue_march`), each with `set_verdict` |
| Companies | a row a unit: the figure icon, the kind, "450 / 500 men" with a `progress_fill` bar, "raised Spring 1480" or "mustering" in `Hint`; a check box per row (for Split and Disband) |
| Supply | "In supply: fed from the stores (1 grain a season)." / "Out of supply: the land feeds 0 of 1,000 men; about 100 are lost a season." / "Fed by the land at (4, 12) near Cuneo: 90 of 90 men." (tone by state) |
| Costs | "Upkeep 12 ducats a season" with a `DeltaChip`; "Move points 12 · Sight 1" in `Hint` |
| Actions | **Split off** (the ticked units; `split_army`), **Join** a `Segmented` of the other armies of yours on the hex (`merge_armies`), **Disband** (the ticked units, or the army; through `Confirm` when nothing is refunded: "Disband 2 companies of the Army of Turin? 1,000 men go home to Turin (5, 9)."), **Raise here** (opens the hex panel's Raise tab when the army stands on a settlement of yours) |
| A seen foreign army | the country's name and arms, "About 1,000 men", the place; no actions |

Refreshes on `army_changed`, `army_raised`, `army_disbanded`, `army_starved`, `unit_lost`, `march_halted`, `season_ended`.

### 6.6 The Supply mode (`shell/map/mode_overlay.gd` + `.gdshader`, edits) and the sight veil

`MapModes.supply_bytes(game, viewer)`, one byte a hex:

| Byte | Meaning | Colour (`MapModes.SUPPLY_COLOURS`) | Legend words |
|---|---|---|---|
| 0 | not your land (and not unowned) | the veil (M4.5's `VEIL` at `VEIL_ALPHA`) | "Not your land" |
| 1 | out of supply; the land feeds no one this season | `#a8321a` with stripes | "Out of supply, starving" |
| 2 | out of supply; the land feeds under 1,000 men | `#c8664c` | "Out of supply, the land feeds a few" |
| 3 | out of supply; the land feeds 1,000 or more | `#e2b97a` | "Out of supply, the land feeds an army" |
| 4 | in supply now, cut off in winter (shown from Spring to Autumn) | `#9cb3d6` | "In supply until winter" |
| 5 | in supply | `#4f79b8` | "In supply" |
| 6 | a depot | `#1f3f7a` | "A depot (a village or larger, a port)" |

Bytes 1 to 6 at `SUPPLY_ALPHA` (0.70); the colour distances are tested as M4.5's (neighbouring bytes 2 to 6 at least 6
worst ΔE, the veil and byte 1 against every other at least 15). `ModeOverlay` gains the textures `supply` (R8),
`supply_ramp` (RGBA8 256 x 1) and `sight` (R8: 1 seen), the uniforms `supply_alpha`, `sight_veil_on`, `sight_alpha`, and
`func update_supply(bytes: PackedByteArray) -> int`, `func update_sight(bytes: PackedByteArray) -> int` (the texels that
differ, one texture update), `supply_bytes()`, `sight_bytes()` (copies, tests). The sight veil draws `VEIL` at
`SIGHT_VEIL_ALPHA` over every land hex not seen, in every mode, when `map/sight_veil` is on (off in a map-only game). It
reads no screen texture. `ModeLegend` (M4.5) shows `legend(SUPPLY)` under the title "Supply: where your armies are fed".
The minimap shows both (the same material).

The map scene updates `supply` while in Supply mode, and `sight` always, on `season_ended`, `army_changed`, `army_raised`,
`army_disbanded`, `unit_lost`, `owners_changed`, `game_started`, `town_grew` and `district_declined` (when
`game.version` changed).

### 6.7 The move card (`shell/hud/move_card.tscn/.gd`, new)

```gdscript
class_name MoveCard extends PanelContainer    # PanelCard, 300 px, mouse ignored, focus none; by the pointer (or the cursor)
func show_move(preview: Dictionary) -> void   # MovePreview.to
func hide_card() -> void
```

Shown instead of the hex hover card (`MapHover`, M1.5) while an army of yours is selected and the pointer is over another
hex. Its lines (`preview.lines`, each with its tone): the title (the place); "There in Autumn 1480 (2 seasons)" or "At the
season's end: Susa (4, 9)"; "Musters first: marches from Summer 1480."; a crossing a line ("Crosses the Po on the bridge
at Vercelli.", "Wades the Dora Baltea: a whole season.", "Crosses the Little St Bernard pass: closed in winter."); "Waits
for spring at Hospice Little St Bernard (3, 7): the pass is closed." in winter; at the goal: "In supply." or "Out of supply: the land feeds no one;
about 100 men lost a season." (bad); a refusal in `BAD` with the way out in `Hint` ("Not your land: the Duchy of Milan
holds it, and your armies cross no border in peace." / "Go round their land."). The right-click toast says the same words.

### 6.8 The Raise tab and the hex menu

**The Raise tab** (`shell/panels/raise_list.tscn/.gd`, new; a part of the hex panel, `shell/panels/hex_panel.tscn/.gd`,
edit): on a settlement of yours the hex panel's action area gets a `Segmented` "Works | Raise" (Works by default). Raise
shows a head line ("Men at hand: 6,300 · 2 companies this season": `Military.men_at_hand`, the hex and its ring) and a row per `Military.raise_options`: the figure
icon, the name, "500 men · 12 move points" (`Hint`), a `KitButton` "Raise" with `cost_text` "25 · 1 iron" and
`set_verdict`; a refused row shows its reason. A click raises one company (`Session.act("raise", {hex, kind})`), the toast
"Raised 1 company of pikemen at Turin (5, 9): −25 ducats, −1 iron." Refreshes on `army_raised`, `army_disbanded`,
`season_ended`, `tax_set`, `goods_short` and the work signals.

**The hex menu** (`shell/hud/hex_menu.gd`, new; `class_name HexMenu extends PopupMenu`): opened by a right click (or O)
with no army of yours selected, at the pointer or the cursor's hex. Items, each disabled with its reason as the item's
tooltip when refused: the hex's works options (`ImprovePreview.options_of`, M4: "Build vineyard · 40 · 4 seasons"; "Upgrade
...", "Clear ..."), a separator, "Raise companies here..." (selects the hex and opens the Raise tab; on your settlements),
one item per army of yours on the hex ("Select the Army of Turin"), "Show supply (6)". Keyboard: the menu's own focus
(Up, Down, Enter, Esc). `func open_for(hex: Vector2i, at: Vector2) -> void`; signal `chosen(action: Array)` with
`[&"work", hex, option]` (the App treats it as a click on the hex panel's row, M4's `game/confirm_works` rule),
`[&"raise_tab", hex]`, `[&"select_army", id]` or `[&"map_mode", &"supply"]`.

### 6.9 The Military page (`shell/screens/study/page_military.tscn/.gd`, new)

`class_name PageMilitary extends StudyPage` (no tabs; `page_id` `&"military"`). `StudyPages.LIST` gains `{id =
&"military", title = "Military", scene = "res://shell/screens/study/page_military.tscn", since = "6"}` after Economy (the
mockup's order: Economy, Military, People, Rankings, History).

| Part | Built from | Reads |
|---|---|---|
| Head | a `Hint` line "1,000 men in 1 army, 2 companies; upkeep 12 ducats a season, 5 % of your income." (Savoy's first season) and a span `Segmented` (`state/study_span`) | `StudyMilitary.of(...).head` |
| Your armies | `SectionHead` "Your armies"; a `StudyTable`: Army (text), Place (text), Men (number), Companies (number), Upkeep (delta, negative), Supply (text in its tone), Order (text), Go (button); sorted by Men; **Look there** and **Show on the map** (the Supply mode at the selected army) | `rows` |
| Upkeep | a `PanelVellumInset` with an `InkChart` `LINE_BARS`: bars the army upkeep a season (`ink_2`), line the left-over income (`ink_0`), caption "Upkeep and income, a season" | `series` |
| Losses | an `InkChart` `STACKED_BAR`: out "Hunger" (`ink_2`, dots); M7 adds "Battle"; caption "Men lost, a season" | `series` |
| Armies you see | `SectionHead` "Foreign armies in sight"; a `StudyTable`: Country, Place, Men (banded text), Go; "No foreign army in sight." when empty | `seen` |

A row's Go or Enter sends `[&"look_at", hex]`; "Show on the map" `[&"map_mode", &"supply", hex]`. Before any army: "You
have no army. Raise companies in your towns and villages (the hex panel's Raise tab)."

### 6.10 Chips, Rankings, the country panel, the hover card, the report, the task flag, the log

- **The Army chip** (`shell/hud/chips.gd`, M4, M5, edit): icon `army`, value men under arms, change last season's, card
  `MilitaryCards.army`, click the study at `{page: &"military"}`. Order: Ducats, People, Food, Army, Stores; narrowing:
  Stores first, then Food, then Army, then the long name (M5's order after that).
- **Rankings** (`shell/screens/study/page_rankings.gd`, M4.5, M5, edit): the fourth measure on the second row.
- **The country panel** (`shell/panels/country_panel.gd`, M2 to M5, edit): a row "Under arms" after People: yours "1,000
  men in 1 army"; a known country "about 1,000 men"; an unknown one no row.
- **The hover card**: the Armies and Supply lines (5.6); over a token, the armies of that token.
- **The report screen** (`shell/screens/season_report.gd`, M3, edit): draws the `armies` section (the nav gains "Armies"
  with its count); its lines link to the army (`[&"select_army", id]`) or the hex.
- **The task flag and notifications** (M3, edits): the action `[&"select_army", id]` and the Go of army lines select the
  army through `ctx.request(&"select_army", {army})`.
- **Ribbons** (M3, M5): "Raised", "Halted", "Hunger −100" through `add_ribbon` (M5) from the chronicled lines.
- **Toasts** M6 adds: a raise (6.8); an order ("The Army of Turin marches to Vercelli (6, 9): there in Autumn 1480."); a
  hold ("The Army of Turin holds at Vercelli (6, 9)."); a refused order or key (its reason); a disband ("Disbanded 1
  company of pikemen: +25 ducats back, 500 men home to Turin (5, 9)."); the replay ("The moves are still playing: Space
  skips them."); Tab with no army ("You have no army.").

### 6.11 The App, F3, the console

| Request or event | The App (`shell/app/game_requests.gd`, `app.gd`) |
|---|---|
| `MapScene.army_selected(id)`, `army_cleared` (**new** signals) | the dock shows the `ArmyPanel`, or the hex panel again |
| `MapInput.command_requested(map_px)`, `command_key_requested` | with an army selected: `Session.act("march", {army, goal})` or `halt` on its hex, the toast; else `HexMenu.open_for` |
| `MapInput.next_army_requested`, `continue_march_requested`, `cursor_moved(dir)` | Tab, R, the cursor (6.1) |
| `app_requested(&"select_army", {army})` | pop the screens over the map, select the army, glide |
| `Events.unit_moved` | `MoveReplay.record` |
| `SeasonFlow` callables | `replay_start` -> `MoveReplay.start`, `replay_skip` -> `MoveReplay.skip`, `hold_ribbons` -> `Floaters.hold`; `MoveReplay.finished` -> `flow.replay_done()` |
| `ResourceChips.chip_pressed(&"army")` | the study at `{page: &"military"}` |
| `MapInput.mode_requested(SUPPLY)` | as M4.5: a mode not in `MapModes.modes(game)` toasts; else `set_mode`, `ModeLegend.show_mode` |
| `Events.season_ended`, `game_started` | `StudyWarm.queue_views()` adds `StudyMilitary.of(span)` and, in Supply mode, `MapModes.supply_bytes` |

- **F3** (`shell/hud/debug_overlay.gd`, edit): a line "armies 3 · units 6 · movement 0.6 ms · supply 0.4 ms · vision 0.2
  ms · steps filled 340".
- **Console** (`shell/hud/dev_commands.gd`, edit): `raise c r kind [n]` (`raise`; kind a key or id), `march ID c r`, `hold
  ID`, `armies` (prints yours: id, name, hex, men, order), and the prefix `as TAG` on any action command (`as MLO raise 9 9
  pikemen 2`); the problems they print: "no such hex", "no such kind", "no army ID", "no country TAG", each a planted fault
  in its test.
- The App sets the milestone `"6"`. `Hud` (M1.5) gains the `MoveCard` slot and the `ArmyPanel` in the dock.
- **The Layers popover** (`shell/hud/layers_popover.tscn/.gd`, the style plan's U14, edit): a fourth `KitSwitch` "Sight" under Relief, bound
  to `map/sight_veil` as the other three are bound to theirs; hidden in the sandbox.

---

## 7. Data and the editor

| File | Holds | Made by | Checked by |
|---|---|---|---|
| `godot/data/defs/units/{pikemen,crossbowmen,knights,bombards}.tres` (**new**) | `UnitDef` (table 4.2) | by hand in the inspector (task L1) | `tests/core/test_unit_defs.gd`: every file loads, validates, equals 4.2 |
| `godot/data/defs/terrain/{farmland,grassland,woods,marsh,rock,snow,tundra,sand}.tres` (**new**) | `TerrainDef` (table 4.3) | by hand (L1) | `tests/core/test_terrain_defs.gd` |
| `godot/data/defs/game_defs.tres` (M2 to M5, edit) | `units`, `terrains` (external), the M6 numbers of 5.1 | by hand (L1) | `tests/core/test_economy_defs.gd`: `GameDefs.validate()` and the values of 4.3 to 4.9 |
| `godot/data/defs/families/settlements.tres` (M3 to M5, edit) | `raise_cap` 0, 1, 1, 2, 3, 4 | by hand (L1) | `tests/core/test_family_defs.gd` |
| `godot/data/defs/goods/horses.tres`, `copper.tres` (M4, edit) | `reserve_fixed` 10, 5 | by hand (L1) | `tests/core/test_good_defs.gd` |
| `godot/tools/military_tables.gd` (**new**, headless) | prints 4.2's and 4.3's tables as Markdown from the `.tres` | L1 | `test_unit_defs.gd` runs it and compares one row of each |
| `godot/assets/ui/kit/` (slice 5) | the textures of 6.2 at 1x and 2x | `tools/bake_ui.py` (L14) | `bake_ui.py --check`, `build_theme.gd --check` in CI |
| `godot/data/README.md` (edit) | the `units/` and `terrain/` folders, the M6 fields | L1 | |

No generated game data; the map file and the scenario are unchanged (`build_map --check`, `build_scenario --check`).

---

## 8. Speed

`godot/tools/perf_core.gd` (M3 to M5) on the made-up Europe: `PerfFixture.europe_armies(seasons)` (**new**, in
`godot/tools/perf_fixture.gd`): M4.5's `europe_game` and, at its start, ten armies a country (600) of 1 to 8 pikemen raised
through `raise` at the country's settlements (money and iron through `Game.dev_money`, `dev_goods`: the rig, not the
rules), each ordered by `march` to a hex of its own land 1 to 4 seasons away (`Rng` seeded 1480), re-ordered on arrival;
`seasons` seasons through `Season.run`. Timing with `Time.get_ticks_usec()` in the tool. Rows in
`godot/tests/perf_core_budget.json`, nightly, never in GUT:

| Row | Limit | What |
|---|---|---|
| `season_ms` | **320** (M5: 190) | the ten phases, worst of 8 seasons |
| `movement_ms` | 25 | the movement phase, 600 marching armies |
| `supply_ms` | 40 | the supply phase, warm `SupplyCache` |
| `supply_cold_ms` | 600 | every country's two supply fields from cold (a load, a border change everywhere) |
| `ready_units_ms` | 10 | the refill |
| `vision_ms` | 20 | the vision phase |
| `route_ms` | 2 mean, 8 worst | `Movement.plan` for 200 seeded orders 1 to 4 seasons long (the AI's hot path in M8) |
| `reach_ms` | 2 | `MovePreview.reach`, worst of 200 armies, uncached |
| `cost_field_ms` | 120 | `PathSearch.cost_field` over the whole map, worst of 20 goals (M8's march) |
| `step_fill_us` | 40 | filling one hex's 12 step costs, mean |
| `tokens_ms` | 4 | `ArmyView.tokens` for the largest country with 600 armies, uncached |
| `military_view_ms` | 6 | `StudyMilitary.of(game, tag, 40)`, uncached |
| `supply_bytes_ms` | 20 | `MapModes.supply_bytes`, cold field |
| `summary_ms` | 2 (M3) | `SeasonSummary.of` with the armies section |
| `save_mb` | 8 (M3) | with 600 armies and the explored bitsets |

`godot/tools/ui/perf_ui.gd` (M1.5 to M5) gains in `perf_ui_budget.json`: `army_panel_open_ms` 16; `tokens_refresh_ms` 4
(100 tokens); `route_hover_ms` 4 (a hover change to the route drawn, cold); `replay_frame_ms` 2 (40 walking tokens a
frame); `supply_mode_ms` 16 (key 6 to the first Supply frame); `military_page_open_ms` 16 (north Italy after 40 seasons,
cold). North Italy for scale: 340 land hexes, a few armies: nothing there is measurable.

**How the path search stays inside its budget.** Costs are small integers, so the searches use Dial's bucket queue (no
heap); A* uses the hex distance as its heuristic (every step costs 1 or more); the step table is filled a hex at a time on
first use and kept for the map; a march is planned once and stored (D2), so a season walks stored routes at a few
array reads a step; supply fields are kept per country until its land or a settlement changes. If `route_ms` fails, the
first fallback is a search bounded to an ellipse round the start and the goal (the A* is otherwise unchanged); the
second, a coarse field of 8 x 8 hex blocks for goals over 4 seasons away.

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (P).

| File | Cases |
|---|---|
| `tests/core/army_fixture.gd` (**new**) | `ArmyFixture.savoy(defs)`: the 1480 scenario on seed 1480 as Savoy, calm weather; `with_army(game, tag, hex, kind, count)` raises through `raise` (money through `dev_money` when short) |
| `tests/core/random_player.gd` (**new**) | `RandomPlayer.next(game, tag, rng) -> {action, args}`: picks one action name of `Actions.NAMES` and args from the state (a hex of its land or any hex, a family, a kind, an army of its own or another's, a goal near or far, units of an army, a level), so refusals and successes both occur; M1 to M6's actions |
| `tests/core/test_unit_defs.gd`, `test_terrain_defs.gd` (**new**) | the files load, validate, equal 4.2 and 4.3; `military_tables.gd`'s rows; P: a branch unknown, men 0, refill above men, an unknown good in `cost_goods`, a cover id out of order, forage 1001 |
| `tests/core/test_economy_defs.gd`, `test_family_defs.gd`, `test_good_defs.gd` (M4, M5, edit) | the M6 numbers of 5.1; `raise_cap`; the two reserves; P: `forage_percent` of 5 entries, `river_wade_class` 3 with `river_wall_class` 3, `stack_limit` 0, a `raise_cap` on a goods family |
| `tests/core/test_economy_1480.gd` (M4, edit) | 4.12's nets re-derived with the horses and copper reserves (the countries that keep them sell less in their first seasons); the rest unchanged |
| `tests/core/test_army_state.gd` (**new**) | `Unit` and `Army` round trips; `digest_text` moves with each field; `mustering`; P: a wrong schema, a string for `men`, a unit dict missing `kind` |
| `tests/core/test_country_state.gd`, `test_stats.gd` (edits) | `country/4` with `explored`; `country/3` refused (P); 42 series, the two appended last; a dict without them loads them as zeros |
| `tests/core/test_step_costs.gd` (**new**) | every rule of 4.3 on a 9 x 7 fixture map built in the test (each cover, each relief, highway, road, track, stream, each river class with each crossing, crest, pass in summer and winter, snow winter double); the worked steps of 4.3 on north Italy; `supply_cost`; the lazy fill equals `compute` on every edge of north Italy in both seasons |
| `tests/core/test_path_search.gd` (**new**) | `route` finds the cheapest route on fixtures (ties by the lower hex index); it never crosses a crest, a closed pass, a great river with no crossing or foreign land; WADE only at a leg's start in `reach`; `field` multi-source equals single-source minima; `cost_field` equals `route` costs from 50 random starts; the routes of 4.13 (b) to (d) |
| `tests/core/test_armies.gd` (**new**) | the door: `create`, `add_units`, `lose_men` spread and remainder by id, a unit at 0 removed with `unit_lost`, an empty army removed, `move_units`, `set_*`; the counters; `to_dict`/`from_dict` round trip (P: a duplicate army id is refused) |
| `tests/core/test_military.gd` (**new**) | every row of `raise_check`, `disband_check`, `split_check`, `merge_check` with its words (P each); raise pays (ledger `raise`, flows `raise`), levies the hex then the ring in direction order, joins the first non-marching army, else a new one named by D37 (the ordinals); disband refunds only in the raising season on the home hex, men home or to the army's hex; split, merge; `raise_options`; `upkeep_of` at partial strength; `refill` takes from the hex's people, capped, only in supply on own land; `hex_text` for a named and an unnamed hex; `army_name` on a hospice hex ("Army of Hospice Mont Cenis" after a split there) |
| `tests/core/test_vision.gd` (**new**) | land sight is the land and its ring; army sight 1 and 2; `refresh` after a move; explored set at the start equals M3's `knows` for every pair of the 1480 scenario (the pinned unknown counts of M4.5 and M5 hold); `see_path`; `witnesses_of` (P: a far country is absent); `explored_any` |
| `tests/core/test_knowledge.gd`, `test_log_lines.gd`, `test_season_summary.gd` (M3 to M5, edit) | `knows` with the explored clause; `sees`, `armies_seen` (banded; P: an unseen army is absent); a known other's hex event outside your sight is no longer witnessed (the M3 to M5 cases that assumed public events edited); the M6 sentences of 4.11 for the player, a witnessed other and an unwitnessed one |
| `tests/core/test_movement.gd` (**new**) | every row of `march_check`, `halt_check`, `continue_check` (P each); `plan` with the winter rule (D20: a detour taken, a wait kept); `walk_plan`'s stops; the phase: mustering armies wait, legs within move points, WADE only first, CLOSED waits and emits `march_halted` once, a re-plan after a blocked step, a halt with no way, ticks in id order, a foreign army blocks (P: a registered hostility stops the walk beside the army: `zoc_halts`), the stack truncation (three armies of 4 ending on one hex: the third steps back), arrival holds, `unit_moved`'s `path`, `ticks`, `seen` for a player and for `&""`, `witnesses`, `moved_from`, explored along the path |
| `tests/core/test_supply.gd` (**new**) | depots; the field on north Italy at the start, summer and winter, for every country (the counts and lists of 4.8 pinned); `forage_cap` by cover and slot; the phase: food from grain then fish (flow `army`), `fed` with short stores, foraging shared by armies on a hex, `foraged` once per hex and country (nothing on unowned land), hunger by slot, `army_starved`'s fields, `unit_lost`; `country_step` equals the phase on 200 seeded states (pure) |
| `tests/core/test_army_savoy.gd` (**new**) | **done-when 1 to 3**: 4.13 (a) to (e) exactly, season by season, hex by hex, man by man |
| `tests/core/test_season.gd` (M3 to M5, edit) | **`PHASES` is `[movement, supply, production, income, works, people, stats, calendar, ready_units, vision]`** (the pin); an army raised in Spring walks in Summer's phase; upkeep paid in its raising season |
| `tests/core/test_economy_season.gd`, `test_treasury.gd`, `test_stores.gd`, `test_people.gd` (M4, M5, edit) | the `upkeep_army` line and its count; `needs_of.army_food`; the reserve keeps it; WHY, SPENDING, FLOWS appended (P: an unknown why is refused as before); `foraged` moves people and its flow |
| `tests/core/test_money_property.gd`, `test_people_property.gd` (M4, M5, edit) | the random runs now raise, march, disband: every ducat through `Treasury.move`, every load through `Stores.move`, every person through `People.move` (the `foraged` flow) |
| `tests/core/test_men_property.gd` (**new**) | **done-when 4 and 6**: 40 seasons, `RandomPlayer` for every country, weather drawn; the conservation identity per country and for the world; the move budget per walk; no army over the stack limit at a phase's end; no store below 0; fed never over the need |
| `tests/core/test_check_contract.gd` (**new**) | **done-when 5**: 3,000 `RandomPlayer` actions with 40 season ends; check no: act not ok, digest unchanged; check yes: act ok; P: a test-registered pair whose do ignores its check is caught |
| `tests/core/test_economy_preview.gd`, `test_improve_preview.gd` (M4 to M5, edit) | `with(game, tag, {}, 8)` equals eight played seasons for every country of the 1480 scenario with armies holding (fed, foraging and starving ones): men, food, losses, upkeep, money lines; the 200-case property with holding armies; a marching army is previewed where it stands (documented, a case) |
| `tests/core/test_snapshot.gd`, `test_save_file.gd`, `test_replay.gd`, `test_owns.gd`, `test_game_core.gd`, `test_forty_seasons.gd`, `test_insights_views.gd` (edits) | armies, routes and explored round-trip; save, load, save byte-equal; `FORMAT` 4 (P: a format-3 header reads `older`; a string for an army's `hex`; a route of the wrong type); the same digest after 20 seasons of random army actions (P: a changed `march` goal gives another); 5.3's OWNS table (P: a test-only phase writing `armies` directly is reported); `DOOR_FIELDS`; ten seasons after a load equal; the pins move to M6's values (ten phases, `FORMAT` 4, 42 series, fourteen notable kinds, thirteen actions) |
| `tests/core/test_army_view.gd`, `test_move_preview.gd`, `test_supply_view.gd`, `test_cards_military.gd`, `test_study_military.gd`, `test_replay_plan.gd` (**new**) | tokens per (hex, country), only seen ones, texts exact and banded (P: an unseen foreign army absent); the panel's order texts for each state; `needing_orders`; `reach` (mustering: next only); `to` for each kind of line and refusal of 4.7, the stops and crossings of 4.13; `SupplyView.at` states; the chip card's lines; the page's view equals the state and `Stats`; the plan: ticks played together, unseen steps instant, the cap and `MIN_STEP`, `skip`, `poses` |
| `tests/core/test_hex_card.gd`, `test_country_card.gd`, `test_map_modes.gd`, `test_reminders.gd`, `test_study_rankings.gd`, `test_words.gd`, `test_chronicle.gd` (edits) | the Armies and Supply lines; the army row (yours, known banded, unknown none); `supply_bytes` on north Italy (Savoy's (3, 9) byte 1, Turin byte 6), `sight_bytes`, the colour distances, `legend(SUPPLY)`, `modes`; the four rules with their words and order (P: a holding army makes no `army_idle` line); the army measure, Rankings equals Standing every season of 40; `men`, `units`, `army_of`; `NOTABLE` |
| `tests/shell/test_session.gd`, `test_season_flow.gd`, `test_floaters.gd` (edits) | the seven signals drained after their phases, then `chronicled`; `REPLAY` after `RUNNING`, Space skips without a season, Instant and reduce motion skip, the report after `replay_done`; Save refused in REPLAY; ribbons held and released |
| `tests/shell/test_move_replay.gd`, `test_army_tokens.gd`, `test_path_marks.gd` (**new**); `test_map_scene.gd`, `test_layer_stack.gd`, `test_mode_overlay.gd`, `test_mode_legend.gd` (edits) | records and plays; tokens from `ArmyView` (P: a foreign token on an unseen hex is not made), badge texts, the ring, poses during the replay; the route's stops and crossings; z 83, 84, 88; selection by click and Shift+click; the reach layers; `update_supply`, `update_sight` write only changed texels (P: one byte, one texel); the Supply legend |
| `tests/shell/test_army_panel.gd`, `test_raise_list.gd`, `test_hex_menu.gd`, `test_move_card.gd`, `test_page_military.gd` (**new**); `test_hex_panel.gd`, `test_country_panel.gd`, `test_resource_chips.gd`, `test_study.gd`, `test_page_rankings.gd`, `test_season_report.gd`, `test_task_flag.gd`, `test_notifications.gd` (edits) | every part of 6.5 for a holding, marching, waiting, halted, mustering and starving army and a foreign one; Hold, Continue, Split, Join, Disband (the `Confirm`), Raise here; the Raise tab's rows and verdicts, a click raises; the hex menu's items and their disabled reasons, O opens it; the move card's lines; the Military page from a played fixture, its tables and charts, Look there; the Works/Raise segment; the Under arms row; the Army chip and the narrowing order; five pages in the nav; the fourth measure; the Armies section and its links; `select_army` from the flag and a notification |
| `tests/shell/test_map_input.gd`, `test_bindings.gd`, `test_settings.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_hud.gd`, `test_app_flow.gd` (edits) | right click with and without an army, O, Tab, R, Alt+arrows (the column rule), 6; the new bindings with `since: "6"`; `map/sight_veil`, `state/map_mode` `supply` (P: a bad value falls back); the console's commands and their planted faults; the F3 line; the dock and the move card's slot; end to end: New game as Savoy, raise at Turin, order to Vercelli, End season (muster), End season (the replay, then the report), order to the Mont Cenis, a season of hunger in the report, Tab, R after a halt, a save and load |
| `tests/shell/test_ui_monkey.gd` (edit) | adds right clicks with an army selected, Tab, R, O, Alt+arrows, 6, clicks on tokens and the army panel's buttons; invariants: the digest changes only after an accepted action or a season; no order is given while the replay runs; the token count equals `ArmyView.tokens` after every frame of IDLE |
| Python `tests/test_bake_ui.py` (edit) | slice 5's pieces at both scales; the catalogue; the asserts of style spec 4.4 |
| `godot/tools/map/probe_mode_overlay.gd` (M2 to M5, edit; windowed, CI under xvfb) | Supply and the veil: the pixel at every hex middle equals `colour_at` (tolerance 3); P: `--plant` swaps two supply ramp entries and prints FAIL |
| Pictures (`godot/tools/ui/shot_ui.gd`, edit) | tokens on north Italy at zoom 1 and 0.5 (Savoy's two armies, one selected with its reach and route); the move card for a pass crossing and for a refusal; the army panel (holding, starving); the Raise tab; the hex menu; the Supply mode with its legend and the veil; the replay mid-walk; the Military page; the report with the Armies section (beside the mockup's render at its "M6 armies" switch, `tests/fixtures/mockup/report_m6.png`); at 1280 x 720 scale 1 and 2560 x 1440 scale 2; signed by the art director, then goldens `godot/tests/goldens/m6_*.png` (0.5 %) |

**Determinism:** `test_replay`, `test_forty_seasons`, `test_men_property`, `test_check_contract` (M6 draws no luck; armies
walk by id, hexes by index). **Save round trip:** `test_snapshot`, `test_save_file`, `test_forty_seasons`,
`test_season_summary` (J after a load: the Armies section and the armies in sight are equal).

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| GDScript too slow for the searches on Europe (`route_ms`, `cost_field_ms`) | `godot/tools/probes/probe_paths.gd` (**new**, L3: the fake Europe, 200 random routes, 20 cost fields, the step fill) on L3's first days, before L6 builds the phase on it | 8's two fallbacks, in that order |
| The supply fields too slow cold on Europe | `supply_cold_ms` on L7's first day | the fields only for countries with armies (others have none until M8) |
| Witnesses from sight empty "What befell" and the history of others' events the owner liked | the playtest (step 17) and the report of a game with the console's `as MLO` | none needed: the rule is the design (style spec 6.5); M7's war events are public |
| Armies feel slow or fast (12 move points) | the playtest's marches; `godot/tools/army_report.gd` (**new**, L13: for every country, its supply coverage in summer and winter, its raise capacity a season, and the route seasons between its capital and its farthest town) read by Opus before group F | the move points and costs are data (S each) |
| Iron, horses or copper gate raising too hard for countries that make none | the army report's raise capacity column | lower the goods per unit (data), never buying (M10) |
| A stack limit of 8 with no generals makes battles in M7 bigger than its board | M7's own design | the limit is data |
| Ticks and the stack truncation give odd walks when many armies converge | `test_movement`'s cases; the monkey's invariant | truncate at order time instead (the goal reserved): M |
| The replay of 600 AI walks (M8) is unreadable | M8's busy pill and its own replay rules | `game/movement` Instant |
| Tokens over the overlay hide the map's colour under them | the pictures of section 9 | a token at 85 % alpha in a map mode (a constant) |
| Saves grow with routes and explored bitsets | `save_mb` nightly | routes rebuilt on load (a re-plan) |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 3.2, layer 6's note: army tokens sit in their own node at z 88 (M6), not in the standing group; 9.2: the M6 row points at this spec and its plan, status "specified and planned, waits for the owner's go; starts after M5 closes"; the last row reads M7 to M12 |
| `docs/architecture/m1-build-spec.md` | Section 5, the layer table: the standing group's "later the army tokens" points at M6's z 88 |
| `docs/architecture/m3-build-spec.md` | 5.6: `SeasonSummary.SECTIONS` gains `armies` (M6); 12, row M6: points here |
| `docs/architecture/m4-build-spec.md` | 12, row M6: points here (WHY `upkeep_army` and `raise`; the reserves; the army's food) |
| `docs/architecture/m5-build-spec.md` | 12, row M6: points here |
| `docs/architecture/m4-5-build-spec.md` | 12, row M6: points here |
| `docs/architecture/ui-style-and-feedback-spec.md` | 6.4: the section ids gain `armies`; section 8: a note that the Military page is specified here |
| `docs/architecture/ui-style-and-feedback-plan.md` | S5, row M6: folded into `m6-build-plan.md` |
| `docs/architecture/ui-and-controls-spec.md` | 4.1: the `map_command_key` row (O, Shift+F10) and `view_mode` 6 Supply; 7: the hex menu row and the switcher's Supply (key 6) |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M6: the tasks are those of `m6-build-plan.md`, with this spec's files |
| `docs/design/ui/game-feedback-screens.md` | C.2: a line that the Military page is `m6-build-spec.md` 6.9 |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `godot/README.md` (the keys, the Raise tab, the console; L24), `godot/data/README.md`
(L1), `CLAUDE.md` (the `army_report.gd` line in the Godot commands; L13). No port rule changes: no new autoload, no new
layer; `tools/lint_godot.py` needs no entry (new files sit in listed folders, each under 800 lines).

---

## 12. What M6 hands to later milestones

| M | Takes from M6 | M6 leaves for it |
|---|---|---|
| M7 | **The seams:** `march_check` row 7 refuses a goal holding another country's army: M7 turns a hostile one into an attack order through its `Battles.engage_check(game, army, hex)`, which the movement phase's tick step also calls (the step into a hostile army becomes `Battles.engage`); `Movement.hostile` (becomes `Wars.at_war`); `Movement.open_to` (adds hostile land); `Movement.zoc_halts` (adds garrisoned hostile castles); the `battles` phase follows `movement`; `Military.stack_limit` (adds generals; counted per side on a battle hex); the battle hex rule (two countries share a hex only in a battle: `Army.battle`, `army/2`); `Unit` gains morale and experience (`unit/2`); `UnitDef` gains the combat numbers; castles become depots and garrisons; `Supply.field` over controlled land; `unit_lost.why` `battle`; `Stats.losses` with battle losses; the Military page's losses chart gains "Battle"; the log's War filter takes the army kinds. Taken up in `m7-build-spec.md` (1.2): a battle never outlives the season's
`battles` phase, so no `Army.battle` field: `army/2` carries the army's standing order; generals move to M11 | Battles, sieges, occupation |
| M8 | The AI acts through `raise`, `march`, `halt`, `continue_march`, `split_army`, `merge_armies`, `disband` with the same checks; it reads `Knowledge.armies_seen`, `Knowledge.sees`, `ArmyView` of its own armies, `MovePreview`, `Movement.plan`, `PathSearch.cost_field`, `Supply.field`, `SupplyView`, `Military.raise_options` and the reminders `army_idle`, `army_hungry`, `army_stores`; `route_ms` and `cost_field_ms` are its budget rows; the scenario's starting armies (`ScenarioDef.start_armies`) arrive with it; the chronicle's size with army events; taken up in `m8-build-spec.md` (it reads its own armies through `AiKnow`, `Movement.plan` inside the `march` check, cached; `PathSearch.cost_field` is not used, D48) | The AI |
| M9 | Peace moves land with its armies' standing (an army on land that changes hands halts: D2's re-plan): taken up in `m9-build-spec.md` (armies on ceded land go home by M7's rule); **no military access in M9** (pacts come with alliances, after M12), `open_to` unchanged | Diplomacy |
| M10 | Road works change `StepCosts` (it moves onto `Game` and is dropped for the touched hexes); markets may sell grain to armies; **taken up in `m10-build-spec.md`** 4.10 and D35 (`StepCosts.for_game` on `game.steps`; armies eat from stores the market refills) | Trade |
| M11 | Later kinds and refit (`UnitDef.era`, a refit action); techs change move points, supply reach and costs through definitions only; **taken up in `m11-build-spec.md`** 4.10 and 4.14 (eight later kinds, `refit`; supply reach, army food, sight and costs by the country's definitions; move points change with the kinds, never by a tech: one step table) | Research |
| M12 | Debt's desertion through `Armies.lose_men` (`why` `deserted`); bankruptcy disbands; score with men under arms (taken up in `m12-build-spec.md` section 12) | A whole game |
| **E2, E3** | **Nothing blocking: armies, routes, supply and sight scale with armies and countries; the Europe budgets are measured on the made-up Europe (section 8).** | |
