# M10 build spec: Trade

Game and systems designer (Opus), 2026-11-17. **Status: a proposal, design only; it waits for the owner's go.** Builds
milestone M10 of `docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`), the
M1.5 UI foundation (`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`), and the M2 to M9 specs and plans
(`m2-build-*.md` to `m9-build-*.md`, with `m4-5-build-*.md`). Where this page is more exact it wins for M10; section 1.2 lists
every place where it refines an earlier page. The tasks are in `m10-build-plan.md`. This page carries the M10 row of the
standard's 9.1 (the market panel; merchant orders; the Trade mode; the Trade page and the price ring), the M10 row of
`ui-and-controls-plan.md` section 4 (the Trade map mode, the market panel, merchant orders, trade route lines in Layers, the Trade
study page) and of `ui-style-and-feedback-plan.md` S5 (the Trade page, sparklines in tables, the price ring, `price_moved` in the
report, the Trade flows mode). It builds v0.2.2's markets, routes and merchants re-fitted to districts, with the owner's trade
decisions of 2026-11-13 (section 1.3) and the reactive prices of `docs/design/reactive-prices.md` in its recommended form.

**What M10 is.** The walled towns, the cities and the capitals of the map hold **markets**. Every land hex sells in the market it
reaches most cheaply over the ground and the roads (its **catchment**); land no market reaches sells at its owner's home market at
70 %. Markets whose catchments meet are joined by a **route**: a way over the land, with a cost a load and a capacity set by its
roads and its towns. Each season, after the harvest is in, the **trade phase** runs: every country offers what its stores hold
above their reserve, in the markets where it was made, and buys what its reserve lacks at its home market; free traders carry goods
along every open route from cheap to dear; then the countries' own **merchants** (abstract orders: a good, a route, a direction)
carry their loads, imports included; the rest is bought by the market's own people; and every market sets next season's
**prices** from what was on offer against what was wanted, smoothed and bounded. The market towns' owners take **tolls** on the
profit that passes; a country sets its tolls Low, Normal or High; **trade agreements** open markets, **embargoes** close them, and
war closes the roads between enemies to everything but grain. **Roads become works**: a track, a road or a highway, with its ford
or bridge, built edge by edge, changes marches, supply, catchments and routes. The AI sends its merchants on its best orders every
season, sets its tolls by temperament, and signs and breaks trade pacts by opinion. The player sees it all: the **Trade mode** on
key 8 with the catchments, a price lens and the route lines, the **market panel** (E), the **order card**, the road card, the
**Trade page** of the study with sparklines and the 40-season **price ring**, the report's Trade section with its price lines, the
Merchants chip, the reminders, the log and the console.

**When it starts.** After M9 is closed (its plan's definition of done, and the owner has played it). M10 edits `Game`, `Session`,
`Events`, the action and season tables, `MapState`, `Work`, `Country`, `Stats`, `Deal`, `PeaceOffer`, `GoodDef`, `GameDefs`,
`DiplomacyDef`, `AiDef`, `AiTemperDef`, `Economy`, `EconomySeason`, `Treasury`, `Stores`, `Works`, `StepCosts`, `Movement`,
`Supply`, `SupplyCache`, `Vision`, `Relations`, `Peace`, `StatsSystem`, `Chronicle`, `Knowledge`, `Words`, the previews, the report's
view, the reminders, the log lines, the study's views and pages, the map modes and overlay, the edge lines, the crossings, the map
scene, the hex, country and peace screens and panels, the chips, the console, F3, the App, the AI, the soak and the perf tools,
and builds its screens into the M1.5 frame as M9 left it.

**M10 is done when:**

1. **Prices move with supply.** In `TradeFixture.duo` (4.15 a) the wine price of the West market reads 2,500, 1,886, 2,015 and
   2,751 thousandths for seasons 1 to 4 and the East market's 2,500, 5,625, 4,063 and 3,057, exactly; in the 40-season property run
   every price of every market in every season lies between 300 and 3,500 permille of its good's base price; on "Italy, 1480",
   seed 1480, with the frost slot's weather forced poor for Summer 1480 (calm everywhere else), Milan's grain price for Autumn 1480
   is at least 5 % above the price of the same game with calm weather (`tests/core/test_trade_prices.gd`, `test_trade_italy.gd`).
2. **A trade route changes a town's income.** In the duo fixture's season 2 the route carries 12 wine and the ledger gains a
   `tolls` line of 4 ducats at West (1, 1) for its owner and 4 at East (7, 1) for its; when East's owner declares an embargo on
   West's before season 3, West's owner's season 3 ledger lacks exactly its `tolls` line (2) and its merchant's `trade` line (8),
   and nothing else of that season changes. On seed 1480 as Genoa, the Milan–Genoa route carries goods in at least one season of
   the first two years and Genoa's ledger shows a `tolls` line at Genoa (8, 13) equal to its share recomputed from the route's
   record; `declare_embargo {target: MLO}` removes the line from the next season (`test_trade_duo.gd`, `test_trade_italy.gd`).
3. **Markets on the map.** On seed 1480 the build gives the 14 markets of 4.2, the catchments of 4.3 (hexes and town people per
   market, 91 remote hexes), the 22 routes of 4.4 with their ways' points, lowest road, capacity, cost and winter state, the
   13 home markets and the 27 merchants of 4.7 (`tests/core/test_trade_map.gd` pins the build's tables and `test_merchants.gd` the
   counts; tasks X6 and X9 write them here if they differ).
4. **Merchants carry imports and the card tells the truth (T1, T2, T5, E5).** In `TradeFixture.chain` a merchant from B to C
   carries grain the free traders brought into B in the same season; in the duo fixture the card's "up to 5, +8 a season" equals
   what the merchant delivers (5 wine, +8); in 200 seeded duo cases the card's profit a load equals the delivered profit a load to
   the thousandth, and its amount equals the delivered amount whenever the source's offers and imports equal last season's; an
   order that carries nothing is flagged after 2 seasons and comes home after 4; one that loses money two seasons running comes
   home; Re-pick best keeps the orders among the best and sends the rest; the idle-merchant reminder's Send sends the best order
   (`tests/core/test_merchants.gd`).
5. **Roads are works.** As Savoy in Spring 1480, `build_road {hex: (7, 10), direction: 5}` costs 20 ducats and 2 seasons and lays
   a track with a ford; from Autumn 1480 the step across costs 2 move points (a wade before), the Turin–Genoa way 17 → 11 points
   and its cost 405 → 315 thousandths a load; marches and supply read the same step (`tests/core/test_roads.gd`,
   `test_road_works.gd`).
6. **Tolls, pacts and war.** Every row of 4.8 and 4.9 with its check: a war or an embargo between the controllers of a route's two
   market towns closes it to every good but grain; an army at war with either end standing on its way closes it whole for the
   season; a besieged market town shuts its market; an agreement carries half again as much and gives Low tolls and trade rights;
   a peace whose deal opens the loser's markets lifts its embargo and binds an agreement for 20 seasons
   (`test_trade_pacts.gd`, `test_trade_war.gd`, `test_peace_open_markets.gd`).
7. **No goods or money from nowhere.** `tests/core/test_trade_property.gd` plays 40 seasons with seeded random actions for every
   country (every action of M1 to M10) and weather drawn, and finds every season: per market and good, offered + in − out −
   bought − consumed = 0; per good, the loads in equal the loads out over all routes; per country its `sold` flow equals its offers
   and its `bought` flow its filled bids; its `tax_goods` line equals its sales' value at the season's prices times its share; its
   `purchases` line the filled bids at price; the tolls received equal the tolls charged; no stock below zero; M4's ledger and
   flow identities with the new lines.
8. **Contracts.** `tests/core/test_check_contract.gd` drives the random player over the 30 actions: a refused check changes
   nothing, an allowed one succeeds.
9. **Determinism and saves.** Same seed and same action log give the same digest after 40 seasons of trade (`test_replay.gd`); save,
   load, save gives byte-equal files with markets, prices, the price ring, routes' records, orders, pacts and the living roads in
   them; ten seasons after a load give the digest of ten without; `SaveFile.FORMAT` is 8 and an M9 save reads "Made by an older
   test build" (`test_trade_saves.gd`).
10. **The AI trades.** In the nightly soak (`ai` suite, 100 games of 80 seasons) the ranges of 4.17 hold: merchants working in at
    least 60 % of merchant-seasons, at most 30 % of order-seasons carrying nothing, at most 10 % at a loss, trade income 3 % to 30 % of
    the median country's income, at most 25 % of market-good-seasons at the cap, the median seasonal price change 1 % to 15 %; the
    invariants `prices`, `markets`, `orders`, `roads` and `pacts` hold in every game.
11. **Time in budget.** On the made-up Europe the rows of section 8 hold in the nightly `perf_core.gd` run: the fifteen phases other
    than `ai_orders` under 430 ms, the trade phase under 25 ms, the trade cache from cold under 150 ms, the AI season under M8's
    3,000 ms mean; on north Italy the trade phase under 2 ms.
12. Every M10 UI row of the standard's 9.1 is in the game, built from the M1.5 kit, each with its GUT test: the Trade mode on key 8
    with its two lenses and legend, the route lines (Trade mode and the Layers switch), the market marks and toll badges, the market
    panel with its three tabs and tolls, the order card, the route menu, the road card, the Trade page with its tables, sparklines
    and price ring, the hex, country and peace screens' trade parts, the Merchants chip, the report's Trade section with
    `price_moved` lines, the reminders, the log, notifications, ribbons and the console. No stand-in is left.
13. Lint, import, check_scripts and GUT are green, with both UI `--check`s, `build_map --check` and `build_scenario.gd --check`;
    the art director has signed the trade sheet and the pictures of section 9; the owner has played the build through the plan's
    checklist.

---

## 1. What is there, and where this page refines earlier pages

### 1.1 Read in the code (master `e8d19a9`), the map data and the specs

| Finding | Where | What it means for M10 |
|---|---|---|
| `MapData` per edge (3 a hex, k = 0 E, 1 NE, 2 NW): `road` 0 none, 1 track, 2 road, 3 highway; `crossing` 0 none, 1 ford, 2 wooden bridge, 3 stone bridge, 4 ferry, 5 pass; `road_on(hex, d)`, `edge_index(hex, d)` | `core/defs/map_data.gd` | The starting roads and crossings; M10 copies them into `MapState` and makes them change (D40) |
| North Italy: 40 highway, 71 road and 64 track edges; 29 wooden and 6 stone bridges, 5 fords, no ferry, 31 pass crossings; 340 land hexes, 83 places | `data/maps/north_italy.tres` (read by a script for this page) | The network roads improve |
| `EdgeLines.for_chunk(map, _state, chunk)` takes a `MapState` it does not read; `chunks_of_run(map, hex)` names the chunks to rebuild "when a road is laid or taken up"; `Crossings.of_hex(map, hex)` reads `MapData.crossing` | `core/views/edge_lines.gd`, `core/views/crossings.gd` | The seams for living roads: both read the state from M10 (6.3) |
| 17 places are walled towns, cities or capitals on the map (Milan and Venice cities; Genoa, Florence, Bologna, Pavia, Brescia, Verona, Pisa, Geneva, Padua, Ferrara walled towns; Turin, Mantua, Bern, Siena, Lucca capitals); Pavia stands beside Milan, Siena beside Florence, Lucca beside Pisa | the map file and `data/scenarios/north_italy_1480.tres` (`capitals`) | 14 markets (4.2) |
| `data/geography/markets.json`: v0.2.2's 41 markets (24 in Europe, 17 colonial); only Venice and Genoa lie in the north Italy window | `godot/data/geography/` | Markets come from the towns of the map, not from that list (D2) |
| The improvement search on seed 1480: 71 settlements, 6 castles, 53 goods districts, 210 wild hexes, no mines (so no iron, copper or silver is made on the map) | `tools/worldmap/improve_report.gd -- --seeds=1480` (run read-only for this page) | Iron has no supply on seed 1480: its price sits at the cap and nothing can be bought (4.5) |
| `Settings.SCHEMA` `state/study_page` already lists `trade`; `state/map_mode` lists terrain, owner, relief (M4.5 to M9 add yields, food, supply, relations) | `shell/app/settings.gd` | M10 adds `trade` to `state/map_mode`, and three keys (6.1) |
| `Bindings.DEFAULTS`: 1 to 4 bound; M5 to M9 take 5, 6, 7, P; the letters E, K, Q, V, X, Y, Z and the key 8 are free | `shell/input/bindings.gd`, `ui-and-controls-spec.md` 4.1 | M10 takes 8 (the Trade mode) and E (the market panel) (D63) |
| `ScreenIds.PATHS` names no trade screen | `shell/screens/screen_ids.gd` | M10 adds `merchant_order` |
| `RelationMatrix` states war, ally, truce, peace, self (M9 adds league) | `shell/ui/relation_matrix.gd` | M10 adds `embargo` and `partner` (6.8) |
| `StudyTable`, `InkChart`, `Segmented`, `KitSwitch`, `ResourceChip`, `HoverCard` exist (M1.5); M4.5 completes `StudyTable`'s `spark` and `button` cells and `InkChart`'s `LINE` and `SPARK` | `shell/ui/` | The Trade page's "sparklines in tables" are M4.5's `spark` cells; no new kit piece is needed but the trade icons (6.2) |
| v0.2.2's trade: `rebuild_markets` (provinces to the nearest market within `MARKET_REACH` move cost, the rest "remote" at `REMOTE_PENALTY` 0.7), `build_routes` (adjacent markets by land; sea routes by `sea_walk` within `SEA_ROUTE_RANGE`), `route_capacity` (`ROUTE_BASE` 6 + 4 a marketplace level + 3 a port level), `Route.cost` (0.15 + 0.02 a distance unit, land double), `merchants` (1 + a market owned + marketplace levels / 3, at most 6), `merchant_options`, `send_merchant_check`, `merchants_trade` (`MERCHANT_CAPACITY` 12, source spare = supply − half the demand), `trade_route` (margins sorted, spare and want at 0.7 of the other side), `set_prices` (`(demand + 0.5) / (supply + 0.5)` to the power `ELASTICITY` 0.6, between `PRICE_FLOOR` 0.3 and `PRICE_CAP` 3.5 times base), tolls `TOLL_SHARE` 0.1 of each route's profit to each end's owner, a 40-season price history | `hexa/campaign/systems/trade.py` (286 lines), `economy.py` 21 to 101, 165 to 191, `data.py` 91, 468 to 502 | Section 3 |
| v0.2.2's AI merchants: free merchants take the three best options of each route at a margin over 0.2; an order is recalled once it loses money; never re-picked | `hexa/campaign/ai.py` 180 to 200 | The fault the trade fun test found (F2, F3); M10 follows T1, T2 and E5 (1.3) |
| M4: one home market per country at the fixed price table; `Economy.market_of(game, tag)` returns the country's id; `Economy.market_prices(game, view, market, supply)` returns `GoodDef.price_milli` and reads neither argument; the stores sell what is above the reserve; `Treasury.WHY` "M10 trade"; road works moved to M10; the card's ring price lines wait for M10 | `m4-build-spec.md` D2, D11, 1.2, 4.8, 5.3, 12 | The seams M10 fills (4.11) |
| M5 D20: "buying food arrives with markets (M10)"; M5 12: the food need in market demand, grain and fish priced by supply | `m5-build-spec.md` | The reserve is bought (4.6 steps 4 and 8); the food need is in the market's appetite (4.5) |
| M6 12: "road works change `StepCosts` (it moves onto `Game` and is dropped for the touched hexes); markets may sell grain to armies" | `m6-build-spec.md` 12 | `game.steps` (4.10); armies eat from stores the market refills (D35) |
| M7 12: "road works change `StepCosts` and so retreats and areas; markets may feed besieged towns" | `m7-build-spec.md` 12 | Retreats and areas follow `game.steps`; a besieged market shuts (D33) |
| M8 12: "`AiEconomy` gains merchants (`send_merchant`, `recall_merchant`) and the market's prices in its prior (`Economy.market_prices`); road works as candidates; the soak's trade ranges" | `m8-build-spec.md` 12 | Taken up in 4.16 and 4.17 |
| M9 12: "trade agreements and embargoes as relations: a memory `why` (`trade` +, `embargo` −) and a standing term each; an embargo as a pact the matrix shows; `Deal` gains a row (open market, trade rights) priced in score; `Treasury.WHY` `trade`; road works change reach fields" | `m9-build-spec.md` 12 | Taken up in 4.8 but for the reach fields (1.2) |
| M7, M8 and M9 are on GitHub (milestones 19, 20, 21) | `gh` (read only) | Their plans' task tables stay as they are: every edit M10 makes to their code is an M10 task |
| Built by M1.5 to M9 and named "(M2)" to "(M9)" below: `Territory`, `Countries`, `Works`, `Work`, `Calendar`, `Season`, `Stats`, `StatsSystem`, `Chronicle`, `Luck`, `ViewCache`, `Snapshot`, `SaveFile`, `Replay`, `Knowledge`, `Words`, `LogLines`, `Reminders`, `SeasonSummary`, `GoodDef`, `FamilyDef`, `TerrainDef`, `Economy`, `EconomySeason`, `EconomyPreview`, `ImprovePreview`, `DistrictCache`, `StateView`, `Treasury`, `Stores`, `People`, `StepCosts`, `PathSearch`, `Movement`, `Supply`, `SupplyCache`, `Vision`, `Military`, `Armies`, `Army`, `Occupation`, `Sieges`, `Wars`, `War`, `WarScore`, `WarGoals`, `Peace`, `Deal`, `PeaceOffer`, `Relations`, `DiplomacyDef`, `DiploCache`, `CountryCard`, `HexCard`, `MapModes`, `ModeOverlay`, `ModeLegend`, `StudyEconomy`, `StudyDiplomacy`, `PeaceView`, `PeaceScreen`, `WorksPreview`, `PreviewCard`, `HexMenu`, `SeasonFlow`, `DecisionQueue`, `GameRequests`, `StudyWarm`, `DevCommands`, `PerfFixture`, `perf_core.gd`, `RandomPlayer`, `AiKnow`, `AiBrief`, `AiTurn`, `AiEconomy`, `AiDiplo`, `AiDef`, `AiTemperDef`, `Invariants`, `soak.gd` | their specs | M10 starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M10 | Why |
|---|---|---|
| M4 D2, 5.3: one home market per country, its id the country's id; `market_prices` the fixed table | **Markets stand at towns** (4.2), each with its own prices; `Economy.market_of(game, tag)` returns the country's **home market** (its id is the market town's hex index) or `Economy.ABROAD` (−2); `market_prices` returns the market's prices for the season in play, the fixed table for `ABROAD` (D16) | The seam M4 left: prices become a function of supply in whole thousandths |
| M4 D11, 4.8: the stock above the reserve is sold at the fixed price in `production` | `production` stops at the towns' use; the **trade phase offers** the stock above the reserve in the markets where it was made, and **buys** the reserve's lack at the home market (4.6) | Sales go to markets; M5's "buying food" |
| M4 4.9: `tax_goods` = sold × `price_milli` × share | `tax_goods` = the season's **sales value** (`Country.sales_open`, at the prices of the markets sold in, 70 % remote) × share (4.11) | One rule, the market's price |
| M4 4.17, D29: goods at the fixed price in the realm's measure and the card | Goods at their catchment market's price **held for the window**; the card gains the price line "Sold at Genoa's market: wine 2.50 → about 2.31 next season with it" (4.11) | The ring's price line M4 handed over |
| M4 done-when 4 and the pinned numbers of M4 to M9 (`test_economy_genoa.gd` ...) | Kept on **`TradeFixture.still`** (prices held at base, no route capacity, no merchants, no buying, no remote cut): every earlier pin holds; M10's own preview property runs with trade on (9) | The pattern of M4's calm weather and M5's still people |
| M3 4.6, style spec 6.2: "(M10) each market's 40-season price ring" | The ring lives in **`Stats`** (`markets`, `price_ring`, stats/2), written by the `stats` phase from each market's price paid that season (4.20) | "Stored: Stats, the ledgers, the action log": one store of history |
| M3, M4 plan 7: road works with `MapState` schema 4 | **`map-state/7`** (the numbers moved on): `road` and `crossing` per edge; road works are M3's works on an edge (`work/3`, `Work.direction`) using the same slots, money and goods doors (4.10) | One works door; the numbers of M5 to M9 took 4 to 6 |
| M6 4.3, 5.3: `StepCosts.of(map, defs)` a static memo of the fixed map | **`StepCosts.for_game(game)`** (`game.steps`, a door field) reads the living roads and crossings and forgets the two hexes of a built edge; `of(map, defs)` stays for tools and tests (D44) | M6's hand-off |
| M9 12: "road works change reach fields (`DiploCache.forget_reach` on a road's `hex_changed`)" | **Reach fields do not read roads**: M9's steps stay plain (edge 1, pass 2, crest shut) and `reach_free` 9 keeps its meaning (D46) | Roads in reach would move every M9 pin and the brakes' calibration; roads pay through trade, marches and supply |
| M9 4.8: memories `declared` ... `gift`; standing `at_war`, `truce`, `shared_enemy`, `infamy` | Memories gain **`trade`** (+10 both, at an agreement), **`embargo`** (−20, the target's of the embargoer) and **`trade_cancelled`** (−10); standing gains **`trade_partner`** (+10) and **`embargo`** (−15) (4.8) | M9's hand-off |
| M9 5.2 `Deal {hexes, ducats}`; 4.6's price | `Deal` gains **`open_markets`** (bool), priced `open_markets_price` (5) points (4.8) | M9's "deal row for trade rights" |
| M9 6.3 Relations bytes 0 to 13; `RelationMatrix` states | Bytes **14 "an embargo between you"** and **15 "a trade partner"**; matrix states `embargo` and `partner` (6.8) | "An embargo as a pact the matrix shows" |
| M4.5 D35: the money chart's in series "Port dues" becomes "Dues and trade" in M10 | In: "Dues and trade" = port dues + tolls + a positive merchants' line; out: "Upkeep, army and goods bought" = upkeep, walls, army and purchases, plus a negative merchants' line (4.11) | Five series stay five |
| M4.5 D15, M9 1.2: Trade becomes key 8 | **Trade mode on key 8** (`view_mode_8`), and the owner's decision of 2026-11-13 that the trade layer lives in the markets mode (1.3) | One mode for markets and the trade layer |
| M3 4.9, M9 4.18: twelve report sections | A thirteenth, **`trade`**, after `goods` (4.18) | Style plan S5: the report's `price_moved` |
| Standard 5.3 row 7 "Production (`production`), trade, prices" | Two rows: `production` (M4) then **`trade`** (M10), before `income` (4.12) | One phase per topic; income reads the season's sales |
| `reactive-prices.md` 2.1: a harvest roll per market a year | **M4's weather is the harvest**: weather-bound output moves the offers and so the prices; no second roll (D24) | One source of luck already in place; the note's swing (±25 %) is M4's ×0.75 and ×1.2 |
| `reactive-prices.md` 7: a separate `random.Random` for market events | None: M10 draws no luck (D60) | Prices follow supply and demand deterministically |

### 1.3 The owner's trade decisions of 2026-11-13

Found in `docs/reports/trade-fun-test.md` ("Owner's decisions (2026-11-13)"), `docs/reports/economy-fun-test.md` (its decision E5),
`docs/design/ui/README.md` (sections 1 and 6, "Decided 2026-11-13") and `docs/roadmap/roadmap.md` item 5 with
`docs/research/2026-11-13-creative-review.md` 4. v0.2.2 was frozen before any of them was built (its `economy()` still runs the
merchants before the free traders), so M10 builds them.

| # | Decision | Source | How M10 applies it |
|---|---|---|---|
| 1 | **T1 yes:** merchants run after the background trade | trade-fun-test, Owner's decisions | The trade phase moves the free traders first, then the merchants, who may carry imports (4.6 steps 6 and 7); `TradeFixture.chain` proves it (done-when 4) |
| 2 | **T2 yes, all three parts:** flagged and freed dead orders; the AI re-picks its best orders every season; the player's "Re-pick best" | the same | An order that carries nothing is flagged after 2 seasons and comes home after 4 (4.7); the AI's trade step re-picks every season (4.16); the action `repick_merchants` and the market panel's **Re-pick best** (4.7, 6.4) |
| 3 | **T3:** write the design note, then decide | the same | The note is `docs/design/reactive-prices.md` (draft); the standard (2026-11-15) puts reactive prices in M10, so M10 builds the note's recommended answers: harvests first (here M4's weather, 1.2), war closing every route between enemies but grain (its question 2), fairs last (after M12, section 12), `PRICE_CAP` stays 3.5 (its question 4), the preview rolling nothing (no roll at all) |
| 4 | **T4 not now:** revisit after T1 and T2 | the same | The Normal toll keeps v0.2.2's 10 %; T4's change (6 %, the full 10 % only with a merchant working) is not made; the soak's trade-share range (4.17) is the data for the revisit, read in the tuning task |
| 5 | **T5 yes:** the starter nudge; merchant capacity stays 12 unless T1 proves too weak | the same | The `merchant_idle` reminder names the best order with a one-click **Send** from the first season (4.19); `merchant_capacity` 12 (4.7) |
| 6 | **E5 yes:** auto-recall an order that lost money two seasons in a row | economy-fun-test, Owner's decisions | An order whose profit is below 0 two seasons running comes home (`merchant_freed {why: loss}`), for every country (4.7) |
| 7 | **The trade layer lives in the markets map mode (option A)**; recall and new orders also work from the route ribbons on the map | ui/README 6 | The Trade mode (key 8) is the markets mode: catchments, market marks and the route lines; a right click on a route line opens its menu with Recall and New order (6.3) |
| 8 | Province panel tabs Overview, Build and Raise; **Trade stays the Market button** | ui/README 1 | The hex panel gains a market line with **Open the market** (the market panel), not a Trade tab (6.8) |
| 9 | The top bar is option A (one row, icon chips, merchants among them) | ui/README 1, 2 | The **Merchants** chip (6.9) |
| 10 | **The price revolution is parked** (rejected as proposed; "if it comes back, inside the reactive prices work") | roadmap item 5; creative review 4 | Not in M10; listed after M12 with the fairs (section 12) |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days). Data changes are a
`.tres` edit plus the test that pins the value. Every number below lives in `data/defs/trade.tres` (`TradeDef`), in a `GoodDef`, in
`DiplomacyDef` or in the AI's files; `godot/tools/trade_tables.gd` prints them.

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | What M10 builds | Markets, catchments, routes, prices, the trade phase, merchants, tolls, agreements, embargoes, the war's effects, road works, the AI for all of them, their screens | The standard's M10 row; M4 to M9's hand-offs | none |
| D2 | Where markets stand | At every settlement of level **4 or more** (walled town, city) and every **capital** on the map, unless a larger one stands **beside** it (candidates by level descending, then capitals first, then hex index; a candidate is dropped when a chosen market is 1 hex away) | Markets were the great towns; the district map has them; every capital keeps a home market unless a greater neighbour has one | Data (S): `market_level`, `market_spacing` |
| D3 | A market's id | The hex index of its town; its name the place's name | Stable across seasons and saves; no counter | S |
| D4 | When markets open and close | At the start of the trade phase, from the state then (a town walled by a work, a capital moved by a peace); a closed market's orders come home (`why: gone`) | Markets change with the towns; one place that changes them | S |
| D5 | Catchment | Every land hex joins the market it reaches at the lowest **summer move cost** (M6's step costs over the living roads; a wade 8 points; blocked and closed steps not taken), within **12 points**; ties to the higher market level, then the lower market index; owners do not matter | v0.2.2's `MARKET_REACH`; goods go to the nearest market, borders or not | Data (S): `market_reach` |
| D6 | Land beyond reach | **Remote**: it sells at its owner's (controller's) home market at **700 permille** of that market's price | v0.2.2's `REMOTE_PENALTY` 0.7, as a price cut | Data (S) |
| D7 | A country's home market | The market whose catchment holds its capital; else (a capital off the map or remote) the market with the most of its town people in its catchment, ties to the lower market index; else `ABROAD` | M4's home market, now a place; every 1480 country has one on north Italy | S |
| D8 | Abroad | A country with no home market sells at **the base price × 700 permille** and buys nothing; abroad is not a market (no state, no supply or demand) | The outside powers' off-map economy is not simulated; nothing from nowhere is bought | S |
| D9 | Routes | Two markets whose catchments share an edge are joined by a route **when a way exists inside the two catchments**; its way is the cheapest path between the two towns over those hexes (summer costs; ties by the lower hex index) | v0.2.2's adjacent markets, over land | S |
| D10 | Sea routes, rivers as roads, overseas | **None in M10**: `sea_walk` and every sea route wait for ships (after M12); rivers are crossings only | The owner's first release is land only; boats are ships | L (after M12) |
| D11 | Route cost | **150 + 15 × the way's points** thousandths a load (Milan–Genoa 4 points: 210) | v0.2.2's 0.15 + 0.04 a land step, re-fitted to move points | Data (S) |
| D12 | Route capacity | **6** loads a season + **0, 2, 4, 8** by the way's lowest road (none, track, road, highway) + **2** for a walled town and **4** for a city at each end | v0.2.2's `ROUTE_BASE` 6 with marketplaces replaced by town levels and roads | Data (S) |
| D13 | Winter | A route whose summer way crosses a pass shut by snow is **closed in winter**; others cost their winter points (snow doubles, M6) | Seasons matter to trade as to armies | S |
| D14 | Prices | Per market and good, in thousandths; **next season's price** is set at the end of the trade phase from that season's supply and demand; every deal of a season is at the price set at the end of the last | Deterministic, previewable (season 1 exact), the card honest | M |
| D15 | The price rule | `r = (demand + 1 load) × 1000 / (supply + 1 load)`; target = base × `curve(r)` / 1000 with the curve of 4.5 (v0.2.2's `r^0.6` as eleven integer points); next = price + (target − price) × **500** / 1000; bounded **300 to 3,500 permille** of base | v0.2.2's elasticity 0.6, floor 0.3 and cap 3.5 (the note's question 4); integers on every platform; half-way smoothing | Data (S) |
| D16 | `market_prices` | Returns the market's price vector for the season in play (`Market.price` of a market; the base table for `ABROAD`); it reads no supply: supply sets next season's price in the phase; a what-if of next season's price is `Trade.price_after` | The seam keeps its signature and callers | S |
| D17 | Demand | A market's **appetite** = its catchment's town people × `GoodDef.appetite_milli` (thousandths of a load a season per 1,000 town people, 4.5) + the countries' **bids** at it | v0.2.2's demand by people; towns' own needs come from their stores first (M4), so the appetite is what the market's people buy on top | Data (S) |
| D18 | Supply | The loads offered in the market this season plus imports less exports, before the bids are filled | What was on offer | S |
| D19 | What a country offers | Every load of its stock above its reserve after the towns' use (M4's "sold" amount), split among the markets of the hexes it controls that made the good this season (by catchment, floored), the rest at its home market | M4's sale, sent to where it was made | S |
| D20 | What a country buys | For each good with a reserve (M4, M6), in the order grain, salt, wine, oil, timber, stone, iron, horses, copper: the reserve less the stock, bid at the home market, while the season's **budget** (250 permille of a positive treasury) lasts; filled after the merchants, pro rata when short; paid at the price, rounded up | M5 D20 "buying food"; the reserve keeps its meaning both ways; a country with no salt can buy it | Data (S) |
| D21 | Free traders | Every open route moves goods from the cheaper to the dearer end where the margin (price difference less the route's cost) is above 0, best margin first, each good at most `min(capacity left, spare at the source, want at the destination)` with spare = supply − 70 % of demand and want = demand − 70 % of supply; routes in key order | v0.2.2's `trade_route` | Data (S) |
| D22 | What is left | The market's own people buy every load still on offer after the bids: it leaves the game (`consumed`) | v0.2.2's markets kept no stock; the countries' stores are the stock | S |
| D23 | A route's profit and tolls | Profit = loads × margin; each end's controller takes its **toll** of the profit (Low 50, Normal **100**, High 150 permille), a ledger line `tolls` at the market town's hex | v0.2.2's `TOLL_SHARE` 0.1 (T4 not now); a trade route is a town's income | Data (S) |
| D24 | Harvests and shocks | M4's weather moves weather-bound output, so the offers and next season's prices; no harvest roll, no fair, no price event | 1.2 | M (a roll) |
| D25 | `price_moved` | Emitted when a price changes by more than **150 permille** from the price paid to next season's; the report's lines are read from the price ring and the markets, so they hold after a load | Game feedback D.2; "J after a load shows the same report" | Data (S) |
| D26 | Merchants: units or orders | **Orders**, as v0.2.2: a merchant is an order `{route, good, from}`; no token, no march, no supply | The routes are short and drawn as ribbons (decision 7); units would need ships and supply | L |
| D27 | How many merchants | `min(6, 1 + the market towns the country controls)` | v0.2.2's `1 + owns_market + marketplaces / 3`, at most 6 | Data (S) |
| D28 | A merchant's season | After the free traders, in order id order: carries `min(12, spare)` loads of its good (spare = supply − 50 % of demand at the source), at the season's prices; profit = loads × (price at the destination − price at the source − cost), less the tolls of each end it does not control (partners pay Low); a loss pays no toll | v0.2.2's `merchants_trade` with T1's order; the mockup's "after transport and tolls" | Data (S) |
| D29 | Who may send where | A route from a market where the country controls a hex of its catchment, or (by a trade agreement) one the partner controls | v0.2.2's rule plus trade rights | S |
| D30 | Flags and coming home | 0 loads in a season (not suspended): idle +1, flagged at 2, home at 4 (`why: idle`); a loss two seasons running: home (`why: loss`, E5); a route closed by war or embargo: home at once (`why: closed`); a route or market that is gone: home (`why: gone`); snow, a blockade or a shut market suspend it (no count) | T2 (a), E5, the note's 2.2 | Data (S) |
| D31 | The order card | Shows the margin a load at this season's prices (exact) and "up to n" loads, n = what was left for a merchant at the source after the free traders last season, less the older orders there; "+9 a season" | Shown = delivered: the trade fun test's F2 | S |
| D32 | War between the ends | A route whose two market towns' controllers are at war is closed to every good but **grain** (`GoodDef.war_open`); a country's goods made in the catchment of an enemy's market go to its home market (remote) | `reactive-prices.md` 2.2 and its question 2 | Data (S) |
| D33 | Blockade, siege, occupation | An army of a country at war with either end's controller standing on the way at the phase closes the route **whole** for the season (no grain); a **besieged** market town's market is **shut** (no offers, bids or routes; its prices held); an occupied market town's tolls and merchants count for its occupier | Armies on the road stop the carts; a besieged town is cut off (M7: "a besieged hex makes and pays nothing") | S |
| D34 | Raids | **None**: M7 has no raid action; the blockade is the army's effect on trade | No rule M7 lacks | M |
| D35 | Armies and markets | No direct purchase by armies: they eat from the stores (M6), which the reserve buying refills (D20) | M6's "markets may sell grain to armies" through one door | S |
| D36 | Tolls as the tariff | `set_tolls {level}`: Low, Normal, High take 50, 100, 150 permille of the profit and scale the capacity of the routes at that end by 1,250, 1,000, 750 permille | A choice with two sides: more a load or more loads | Data (S) |
| D37 | Trade agreements | Mutual, made by `sign_trade_agreement {target}`; the target accepts when its opinion of the actor is **0 or more** and no embargo stands either way; routes between their markets carry **1,500 permille**; their merchants pay Low tolls and have trade rights in each other's markets; memories `trade` +10 both; standing `trade_partner` +10 both | M9's hand-off; the score-rule style of M9 (no haggling) | Data (S) |
| D38 | Embargoes | One-sided, `declare_embargo {target}`: closes every route between the two countries' markets to all but grain, sends the target's goods home from the actor's markets and back, frees both sides' orders on those routes; memory `embargo` −20 (the target's); standing `embargo` −15 while it holds | M9's hand-off; the same closure rule as war | Data (S) |
| D39 | Offers of pacts to the player | **None in M10**: an AI never proposes to the human player (the check refuses "the %s decides for itself"); the player proposes to AI countries, which answer by the rule at once | No second offer system; M9's offers are peace's; alliances after M12 bring proposals | M |
| D40 | Roads change | `MapState.road` and `crossing` per edge (map-state/7), set from the map at the start; only road works change them (`Roads`, the one writer) | M3's plan, M4's move, the growing-map design | none |
| D41 | Road works | `build_road {hex, direction}` raises an edge's road one level (none → track → road → highway) as M3's work on an edge: both hexes the actor's controlled land, not a crest without a pass; one work slot, money and goods through M4's doors; halted in snow winters as M3's | One works door; 06-growing-map's "roads and bridges" row | S |
| D42 | Bridges | A road work on a river or stream edge also sets the crossing: a track a **ford** (a ferry on a great river), a road a **wooden bridge**, a highway a **stone bridge**, never lowering one that stands | 06-growing-map's "track, ford or ferry · road, timber bridge · highway, stone bridge" | Data (S) |
| D43 | Road costs | Track 20 ducats, 2 seasons; road 60 + 10 stone, 4 seasons; highway 150 + 20 stone + 10 timber, 8 seasons; double ducats and goods on a pass edge; a wooden bridge +20 + 10 timber; a stone bridge +100 + 30 stone and 2 seasons more; no upkeep | 06-growing-map's "about 40, 100, 250" ladder, cheaper for an edge than a district | Data (S) |
| D44 | `StepCosts` on `Game` | `StepCosts.for_game(game)` keeps `game.steps` (a door field, not saved) from the living roads; a `road_built` forgets the two hexes; `of(map, defs)` stays for tools and tests | M6's hand-off | S |
| D45 | What a road changes | Marches and supply (M6, M7), catchments and routes (D5, D9), from the season after it is built; nothing of M9's reach (D46) | One step cost for armies and carts | none |
| D46 | Roads and reach | Not read by M9's reach fields (1.2) | Keeps M9's pins | M |
| D47 | The road card | `RoadPreview.of`: the step before and after (summer, winter), the routes whose way uses the edge and their cost and capacity, the hexes that change market, cost and time, the requirements, and **"about +n a year"** (the change of your merchants' costs and your tolls at last season's trade, and your remote hexes brought into a market), with its payback | An estimate labelled as one: roads pay in many ways | S |
| D48 | Previews | `EconomyPreview` runs the trade step for the previewed country at **today's prices held** for the window, bids filled up to the home market's supply of last season, tolls and merchants as last season's lines (labelled "about"); the first season's sales and taxes on goods are exact | The deals of a season are at known prices (D14) | M |
| D49 | The M4 to M9 pins | Run on `TradeFixture.still` (1.2) | Their numbers stay true | S |
| D50 | The trade phase's place | After `production`, before `income` (16 phases, 4.12) | Income reads the season's sales | S (the pin) |
| D51 | One owner per field | `Trade` (markets, routes' records, `Country.tolls`, `Country.sales_open`), `Merchants` (orders), `TradePacts` (pacts), `Roads` (road, crossing), `EconomySeason` (`Country.made_markets`), `StatsSystem` (the price ring) | The standard's 4.3 | S |
| D52 | What you may know of others | Prices and volumes of a market only when it is **known** to you: you control a hex of its catchment, or of a market a route joins it to, or you know its controller (M3); others' orders on routes of a known market, tolls levels, pacts, markets, routes and roads: public; others' sales, purchases and merchants' profits: never | Game feedback C.2 "public prices of known markets"; merchants are seen at the market | S |
| D53 | The AI's merchants | Every season the seat ranks every option it may send by the card's estimate, keeps the orders among its best (or within 80 % of the best left out), recalls the others and sends the best missing ones | T2 (b) | Data (S) |
| D54 | The AI's tolls | Set once to its temperament's level (builder Low; cautious, steadfast Normal; aggressive, opportunist, conqueror High) | A static, readable trait | Data (S) |
| D55 | The AI's pacts | Every 8 seasons: lifts an embargo when its opinion rose 20 above its line; embargoes the neighbour it likes least at or under its temperament's line (builders and cautious never); signs with a route partner at or above its line; cancels at −30 or below; one of each a think | Opinion drives pacts as it drives wars (M9) | Data (S) |
| D56 | The AI's roads | Road candidates join the works scan: the edges of the ways of its markets' routes, in its land, under highway, busiest route first (8 a season), carded with the road card's payback against its temperament's `payback_max` | M8's "road works as candidates" | Data (S) |
| D57 | Buying for the player | Automatic as for every country, no switch | The reserve rule is one rule; M12's ways out may add a switch | S |
| D58 | Saves | `SaveFile.FORMAT` **8**, `OLDEST_FORMAT` 8; body key `trade`; `map-state/7`, `work/3`, `country/6`, `stats/2`, `peace-offer/2` | An M9 save's digest has no markets or living roads | S |
| D59 | Sandbox | No markets, no trade, no Trade mode ("no countries on this map"); road works free as other works there | No countries | none |
| D60 | Luck | None drawn by M10's rules; the AI's trade step draws none either | Standard 5.4 | none |
| D61 | Events | `price_moved`, `merchant_sent`, `merchant_recalled`, `merchant_freed`, `route_closed`, `route_opened`, `market_opened`, `market_closed`, `road_built`, `tolls_set`, `embargo_declared`, `embargo_lifted`, `trade_agreement_signed`, `trade_agreement_cancelled` (4.13); winter closures are no event | Game feedback D.2 | S a kind |
| D62 | The report | A section `trade` after `goods`; a Trade chip in At a glance; treasury lines for tolls, merchants and goods bought; the price lines of your markets (4.18) | Style plan S5 | S |
| D63 | Keys | **8** the Trade mode; **E** the market panel (the selected hex's market, else your home market) | Free keys; E for exchange | Bindings (S) |
| D64 | The Trade mode's lenses | **Markets** (catchments in six colours, market towns brighter, remote hatched, closed to you striped) and **Prices** of one good (seven bands of its price against base, unknown markets veiled), switched in the legend | The decided markets mode with the price question every trader asks | S |
| D65 | Route lines | Drawn hex centre to hex centre along the way at z 81: yours gold with arrows and a chip ("wine +9"), free trade ivory by volume (1 to 4 px), closed grey dashed with a cross, snow-closed dotted; always in the Trade mode, in other modes with the Layers switch "Trade routes" | The decided trade layer; the UI plan's "route lines in Layers" | S |
| D66 | The market panel | In the dock, three tabs: **Opportunities** (sell and buy tables with the delivered profit), **All goods** (prices, sparks, supply and demand), **Merchants n/m** (yours with Recall, Re-pick best, the idle hint, the competition); your tolls `Segmented` | `12_market_panel_and_order.png`, re-drawn in the Studiolo kit | M |
| D67 | The order card | An `OVERLAY` (420 px, left): good, source (sorted by delivered profit, the best chosen), Send | The mockup's three clicks | S |
| D68 | The Trade page | Between Economy and Diplomacy: Prices (a sparkline a row), the price ring chart, your merchants, tolls and trade, best and worst goods, pacts | Game feedback C.2; the mockup's nav order | M |
| D69 | The console | `market`, `routes`, `price`, `send`, `recall`, `repick`, `tolls`, `embargo`, `lift`, `pact`, `unpact`, `road`, with `as TAG` | The playtest needs a shock and a pact on demand | S |
| D70 | Speed | `TradeCache` (derived, not saved) keeps the catchments, the ways and the colours, rebuilt on a built road, a settlement's level change or a market change; the phase walks markets, routes and orders only | The made-up Europe has about 170 markets; the catchment search is the only heavy part | S |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| Markets at named points (`geo.MARKETS`, 24 in Europe); a colonial market opens with land near it | `trade.py` 27 to 120 | A market a great town, with its own prices | Markets at the map's walled towns, cities and capitals by a rule (D2); no colonial markets (after M12) |
| Provinces join the nearest market within `MARKET_REACH` (14 × SCALE move cost); the rest are remote and sell at their capital's market at `REMOTE_PENALTY` 0.7 | `rebuild_markets` 63 to 119 | Nearest market by move cost; remote at 70 % | Hexes, not provinces; M6's step costs with the living roads; 12 points (D5, D6) |
| Routes between adjacent markets by land; sea routes within `SEA_ROUTE_RANGE`, Atlantic routes with a tech | `build_routes` 122 to 156 | Adjacent catchments make a route | A way inside the two catchments must exist (D9); no sea (D10) |
| `route_capacity` 6 + 4 a marketplace level + 3 a port level; `Route.cost` 0.15 + 0.02 / SCALE × distance (land × 2) | 166 to 180; `state.py` 113 | A base of 6; a cost with a base and a distance part | Roads and town levels make capacity (D12); move points make the cost (D11) |
| `merchants(tag)` = min(6, 1 + a market owned + marketplace levels / 3) + tech | 182 | At most 6, one plus markets | One plus the market towns controlled (D27) |
| `merchant_options` reads the market at the season's end and sorts by margin × amount; `send_merchant_check`: all busy, or no land near either market | 193 to 218 | The checks | The card shows what will be delivered (D31); more refusals (4.7) |
| `merchants_trade` runs **before** `trade_route`, so merchants carry only the source's own produce: 78 to 88 % of AI order-seasons carried nothing | `economy.py` 92 to 95; trade-fun-test F2, F3 | Capacity 12; spare = supply − 0.5 demand | Merchants after the free traders (T1); flags, coming home, re-pick (T2, E5) |
| `trade_route`: margins over the route cost sorted, `min(capacity, supply − 0.7 demand, demand − 0.7 supply)` a good | 259 to 286 | All of it | Integer loads; routes walked in key order (D21) |
| `set_prices`: `base × clamp(((d + 0.5) / (s + 0.5))^0.6, 0.3, 3.5)` three times a season; history 40 seasons | `economy.py` 165 to 171, 96 to 101 | The curve, the bounds, the 40 seasons | Once a season, for next season, smoothed by half (D14, D15); integers (4.5); the ring in `Stats` (4.20) |
| Tolls: each end's owner takes `TOLL_SHARE` 0.1 of the route's background profit | `economy.incomes` 181 to 191 | 10 % at Normal | A level per country, on merchants too (D23, D28, D36) |
| No buying: the state's goods for works were bought on the market (`pending`) | `state.Market.pending` | Purchases at the market | The reserve bought (D20) |
| No roads in the economy; `move_cost` in market reach | `terrain.py` | Move cost in reach | Roads on edges, built in play (D40 to D45) |
| AI: the three best options a route over a 0.2 margin; recall after a loss; never re-picked | `ai.py` 180 to 200 | Rank by margin × amount | Re-pick every season by the card's estimate (D53) |

---

## 4. Design content

All amounts are whole numbers. Loads are whole; supply and demand inside the price rule are in thousandths of a load ("milli");
prices are thousandths of a ducat; rates are permille. Every division is floored but where it says "rounded up" or "toward zero".

### 4.1 The model in one picture

```
 during the season (actions, any country; the AI only in ai_orders)
   send_merchant {from, to, good}   an order on a route                                   -> merchant_sent
   recall_merchant {order}, repick_merchants {}                                           -> merchant_recalled, merchant_sent
   set_tolls {level}                Low, Normal, High from the next trade phase            -> tolls_set
   declare_embargo / lift_embargo {target}                                                  -> embargo_declared, embargo_lifted
   sign_trade_agreement / cancel_trade_agreement {target}                                   -> trade_agreement_signed, _cancelled
   build_road {hex, direction}      a work on an edge (M3's door, M4's money and goods)    -> work_started
 production   M4's goods made and used; each country's made goods booked by the market of the hex that made them (made_markets)
 trade        markets open and close; route states (war, embargo, blockade, siege, snow)  -> market_opened, market_closed,
              offers (the stock above the reserve) and bids (the reserve's lack)             route_closed, route_opened
              free traders on every open route, then the merchants (T1)                    -> merchant_freed
              bids filled; the rest bought by the market's people
              tolls, merchants' profit, purchases: Treasury.move; next season's prices     -> price_moved
 income       taxes on goods from the season's sales value (M4's line, the market's price)
 works        a road work finished: Roads.set_road                                          -> road_built
 stats        the price ring (the prices paid this season), the trade series
```

### 4.2 Markets: where they stand

`Trade.market_hexes(game)` (D2), in order: the candidates are the settlements of level `market_level` (4) or more and the capitals
on the map of every living country (`Country.capital`, any settlement level); sorted by level descending, then capitals before
others, then hex index; walked in that order, each is kept unless a kept one is within `market_spacing` (1) hex of it. The result
in hex index order. A market's id is its hex index; its name the place's (`MapData.places`), or `Military.hex_text` for an
unnamed settlement. A map-only game (the sandbox) has no markets (D59).

**North Italy, 1480** (the build pins it; `tests/core/test_trade_map.gd`):

| Market | Hex | Level | Controller | Why | Dropped beside it |
|---|---|---|---|---|---|
| Bern | (5, 0) | 2 village | SWI | capital | |
| Geneva | (1, 4) | 4 | SAV | walled town | |
| Brescia | (13, 6) | 4 | VEN | walled town | |
| Venice | (18, 7) | 5 city | VEN | city, capital | |
| Verona | (15, 8) | 4 | VEN | walled town | |
| Padua | (17, 8) | 4 | VEN | walled town (2 hexes from Venice) | |
| Turin | (5, 9) | 3 town | SAV | capital | |
| Milan | (9, 9) | 5 | MLO | city, capital | Pavia (10, 9), walled town |
| Mantua | (14, 10) | 3 | MAN | capital | |
| Ferrara | (16, 10) | 4 | FER | walled town, capital | |
| Bologna | (16, 12) | 4 | PAP | walled town | |
| Genoa | (8, 13) | 4 | GEN | walled town, capital | |
| Florence | (15, 15) | 4 | TUS | walled town, capital | Siena (16, 16), capital |
| Pisa | (13, 16) | 4 | TUS | walled town | Lucca (12, 15), capital |

A market opens when a settlement is walled (a work, M4) or a capital moves to a place none stands beside (M9); it closes when its
town falls below level 4 and is no capital, or a larger market comes to stand beside it. Both are seen at the start of the trade
phase (D4): `market_opened {market, hex, name, witnesses: every living country}` and `market_closed {market, why: &"level" |
&"spacing", witnesses}`; a new market's prices start at the base table, its ring empty.

### 4.3 Catchments and home markets

`TradeCache.catchment(game)`: a multi-source search from every market town over land with `game.steps.cost(i, d, false)` (summer;
a `WADE` step counts `wade_points` 8; `BLOCKED` and `CLOSED` are not taken), ordered by (points, −market level, market index),
up to `market_reach` (12) points. Each reached land hex records its market and its points; the rest are **remote** (−1). The
search is over the land whoever owns it; the hex's controller decides only where its goods go when its market is closed to it
(4.9).

**North Italy, 1480** (catchments as computed for this page by a script of these rules on the committed map; the build pins its
own):

| Market | Hexes | Town people in it | By owner of the hexes |
|---|---|---|---|
| Bern | 14 | 13,000 | SWI 14 |
| Geneva | 40 | 72,000 | SAV 21, SWI 12, FRA 7 |
| Brescia | 21 | 83,000 | MLO 10, VEN 6, SWI 3, AUS 2 |
| Venice | 19 | 69,000 | VEN 17, AUS 2 |
| Verona | 13 | 50,000 | AUS 6, VEN 5, MLO 1, MAN 1 |
| Padua | 4 | 40,000 | VEN 4 |
| Turin | 13 | 40,000 | SAV 13 |
| Milan | 44 | 229,000 | MLO 32, SAV 7, VEN 2, GEN 2, MAN 1 |
| Mantua | 1 | 10,000 | MAN 1 |
| Ferrara | 6 | 30,000 | FER 4, VEN 2 |
| Bologna | 21 | 59,000 | PAP 11, FER 6, MLO 2, VEN 2 |
| Genoa | 23 | 66,000 | GEN 11, SAV 10, MLO 2 |
| Florence | 20 | 39,000 | TUS 10, PAP 5, SIE 4, FER 1 |
| Pisa | 10 | 33,000 | TUS 4, SIE 3, LUC 2, FER 1 |
| Remote | 91 | | AUS 27, FRA 27, SWI 16, SAV 7, MLO 5, VEN 4, PAP 4, GEN 1 |

The remote land is the high Alps and the outside powers' edges: snow, rock and woods that make little.

**Home markets** (`TradeCache.home_market(game, tag)`, D7): SWI Bern, SAV Turin, MLO Milan, VEN Venice, GEN Genoa, TUS Florence,
MAN Mantua, FER Ferrara (their capitals in their own markets' catchments); SIE Florence and LUC Pisa (their capitals in those
catchments); PAP Bologna (36,000 of its town people), AUS Verona (20,000), FRA Geneva (3,000).

**Town people of a market** (`TradeCache.town_people(game, id)`): the people (M5, live) of every settlement hex of its catchment
that is not besieged, whoever owns it; cached by `game.version`.

### 4.4 Routes

`TradeCache.routes(game)`: for every pair of markets `a < b` (by id) whose catchments share an edge, the **way** is the cheapest
path from `a`'s town to `b`'s over hexes of the two catchments (summer costs as 4.3; a search in (points, hex index) order, the
predecessor the lower index on a tie); no way, no route. A route's key is `Vector2i(a, b)`.

| Field | Rule |
|---|---|
| `points` | the sum of the way's summer step costs (a wade 8) |
| `winter_points` | the sum of the winter costs along the same way, or −1 (closed in winter) when a step is `CLOSED` or `BLOCKED` in winter |
| `road` | the lowest `MapState.road` of the way's edges |
| `capacity_base` | `route_capacity_base` (6) + `capacity_by_road[road]` (0, 2, 4, 8) + `capacity_by_level[level a]` + `capacity_by_level[level b]` (2 a walled town, 4 a city, 0 below) |
| `cost_milli` | `route_cost_base_milli` (150) + `route_cost_point_milli` (15) × points; in winter with `winter_points` |
| `capacity` this season | `capacity_base` × `toll_capacity_permille[tolls level of a's controller]` / 1000 × the same for `b` / 1000, × `agreement_capacity_permille` (1,500) / 1000 when the two controllers are partners (4.8) |

**North Italy, 1480** (computed as 4.3; the build pins its own):

| Route | Steps | Points | Lowest road | Capacity | Cost a load | Winter |
|---|---|---|---|---|---|---|
| Bern – Geneva | 6 | 12 | none | 8 | 330 | 22 points, 480 |
| Geneva – Turin | 8 | 18 | none | 8 | 420 | closed (a pass in the snow) |
| Geneva – Milan | 12 | 20 | track | 14 | 450 | closed |
| Brescia – Verona | 5 | 7 | road | 14 | 255 | 8, 270 |
| Brescia – Milan | 5 | 5 | highway | 20 | 225 | 6, 240 |
| Venice – Verona | 4 | 4 | highway | 20 | 210 | as summer |
| Venice – Padua | 2 | 3 | road | 16 | 195 | as summer |
| Verona – Padua | 2 | 2 | highway | 18 | 180 | as summer |
| Verona – Milan | 6 | 6 | highway | 20 | 240 | as summer |
| Verona – Mantua | 3 | 4 | road | 12 | 210 | as summer |
| Verona – Ferrara | 2 | 3 | none | 10 | 195 | as summer |
| Padua – Ferrara | 2 | 10 | none | 10 | 300 | as summer |
| Turin – Milan | 6 | 9 | road | 14 | 285 | as summer |
| Turin – Genoa | 5 | 17 | none | 8 | 405 | as summer |
| Milan – Bologna | 8 | 8 | highway | 20 | 270 | as summer |
| Milan – Genoa | 4 | 4 | highway | 20 | 210 | as summer |
| Mantua – Ferrara | 2 | 6 | none | 8 | 240 | as summer |
| Ferrara – Bologna | 2 | 4 | road | 14 | 210 | as summer |
| Bologna – Genoa | 9 | 17 | none | 10 | 405 | as summer |
| Bologna – Florence | 4 | 4 | highway | 18 | 210 | 5, 225 |
| Genoa – Pisa | 6 | 12 | road | 14 | 330 | as summer |
| Florence – Pisa | 4 | 4 | highway | 18 | 210 | 5, 225 |

Milan and Mantua, Mantua and Bologna, and Bologna and Pisa have touching catchments but no way inside them: no route. A cost of
210 thousandths a load is a fifth of grain's base price and a twelfth of wine's: grain moves only on large gaps, wares easily.

### 4.5 Prices

**Base prices** are M4's `GoodDef.price_milli` (grain 1,000, fish 1,000, oil 2,500, wine 2,500, salt 2,000, hemp 1,200, silk 6,000,
dyes 5,000, wool 1,500, cattle 1,500, horses 3,000, timber 1,000, stone 1,000, iron 2,000, copper 2,500, silver 7,000). Every market
starts every good at its base.

**The rule** (`Trade.next_price(defs, good, price, supply_milli, demand_milli)`, pure):

```
r      = (demand_milli + price_k_milli (1000)) × 1000 / (supply_milli + price_k_milli)        # permille
curve  = price_curve(r)                                                                        # permille, the table below
target = base × curve / 1000
next   = price + (target − price) × price_smooth_permille (500) / 1000                       # the product's division toward zero
next   = clamp(next, base × price_floor_permille (300) / 1000, base × price_cap_permille (3500) / 1000)
```

`price_curve(r)` interpolates linearly (toward zero) between the points of `TradeDef.price_curve`; at and above the last point it is
`price_cap_permille`. The points are v0.2.2's `r^0.6` at eleven ratios, the floor below the second:

| r (permille) | 0 | 250 | 500 | 750 | 1,000 | 1,500 | 2,000 | 3,000 | 4,000 | 6,000 | 8,000 and over |
|---|---|---|---|---|---|---|---|---|---|---|---|
| curve (permille) | 300 | 435 | 660 | 841 | 1,000 | 1,275 | 1,516 | 1,933 | 2,297 | 2,930 | 3,482 (3,500 from 8,000) |

Supply is what was offered in the market this season plus imports less exports, before the bids are filled; demand is the
appetite plus the bids (D17, D18). The prices set are those of the next season's deals; the price paid this season is
`Market.last_price` after the phase.

**Appetite** (`GoodDef.appetite_milli`, thousandths of a load a season per 1,000 town people of the catchment; the market's
appetite = town people × appetite / 1,000): starting values from the map's 1480 totals (about 848,000 town people; a season's
offers of about 150 grain, 150 timber, 42 hemp, 25 wool, 20 stone, 15 oil, 7 salt, 5 wine on seed 1480 by M4's tables), so that
the mean market sits near base:

| Good | grain | fish | oil | wine | salt | hemp | silk | dyes | wool | cattle | horses | timber | stone | iron | copper | silver |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| appetite | 180 | 15 | 18 | 15 | 10 | 50 | 3 | 2 | 30 | 20 | 8 | 150 | 25 | 12 | 6 | 3 |
| war-open | yes | | | | | | | | | | | | | | | |

Milan's market (229,000 town people) wants 41 grain a season of its own; Genoa's (66,000) 11.9.

**How the numbers are fixed.** `godot/tools/trade_report.gd` (headless) plays seasons 1 to 40 of seeds 1480 to 1484 with the AI on
and prints, per good, the median over market-seasons 5 to 40 of the price in permille of base (for goods made somewhere on the
map). The tuning task (X31) changes a good's appetite by the factor `1000 / median` (rounded to a whole number) until every
made good's median lies between **800 and 1,250**, and writes the final table here. Goods nobody makes (iron, copper and silver
on seed 1480) sit at the cap and are not tuned.

### 4.6 The trade phase, step by step

`Trade.season(game)`, in this order (all lists in id order: markets by hex index, routes by key, countries by id, orders by id,
goods by id):

1. **Markets.** `Trade.refresh_markets(game)` (4.2); then for each market `last_price = price`, `shut` = its town besieged
   (`Occupation.besieged`, M7). The season's prices are these `last_price`s.
2. **Route states.** Each route of the cache gets a state (4.9): `open`, `winter`, `blockade`, `shut`, `war` or `embargo` (the last
   two closed to every good but the war-open ones). A change against `RouteRecord.state` for `war`, `embargo`, `blockade` or
   `shut` emits `route_closed {a, b, why, witnesses}`; back to `open` from those, `route_opened`. Orders on a route now `war` or
   `embargo` for their good come home (`Merchants.free`, `why: closed`); so do orders on a route or market that is gone, or on a route
   their country may no longer work (D29: it lost its land there), and the newest orders beyond its `Merchants.count` (a market
   town lost) (`why: gone`).
3. **Offers.** For each living country `c`, `Trade.country_step` (pure) gives its offers: for each good, `surplus = stock −
   reserve` (M4's `reserve_of`, after the towns' use in `production`); the surplus is split over `Country.made_markets` (loads of
   that good its controlled hexes made this season, by market; key −1 remote) in proportion, floored, each market's share sent
   to its **sale market** (that market, or the home market when it is shut, or its controller is at war with `c` or an embargo
   stands between them; remote loads to the home market at 700 permille); the remainder to the home market. `Stores.move(c, g,
   −n, &"sold")`; the market's `offered[g] += n`; `c.sales_open += n × price × (700 if remote else 1000) / 1000` (thousandths of a
   ducat). A country with no open home market sells its home share abroad at base × 700 permille.
4. **Bids.** `country_step` gives its bids: budget = `max(0, treasury) × buy_budget_permille (250) / 1000`; for each good of
   `buy_order` (grain, salt, wine, oil, timber, stone, iron, horses, copper) with a reserve: `want = reserve − stock` (after its
   offers: none of a good it offered); `bid = min(want, budget × 1000 / price)`; `budget −= ceil(bid × price / 1000)`. Bids go to the
   open home market only.
5. **Supply and demand.** Per market and good: `supply = offered × 1000`; `demand = appetite + Σ bids × 1000` (milli).
6. **Free traders** (each route not closed for the good, in key order; `cost_milli` the season's, `winter_cost_milli` in winter; for
   each route, the goods and directions with `margin = price(to) − price(from) − cost_milli > 0`, best margin first, then good id, then a before b): `spare = (supply(from) − demand(from)
   × spare_permille (700) / 1000) / 1000`, `want = (demand(to) − supply(to) × 700 / 1000) / 1000` (floored, at least 0);
   `n = min(capacity left, spare, want)`; `supply(from) −= n × 1000`, `supply(to) += n × 1000`; the route's record gains the flow;
   `profit = n × margin`; each end's controller is owed `profit × toll_permille[its level] / 1000` (thousandths; nothing for an unowned town).
   After the routes, each market's `last_bg = supply` (what a merchant could find there).
7. **Merchants** (T1; each order in id order whose route is open for its good and not suspended): `n = min(merchant_capacity
   (12), (supply(from) − demand(from) × merchant_spare_permille (500) / 1000) / 1000)`, at least 0; supply moves as above;
   `gross = n × (price(to) − price(from) − cost_milli)`; when `gross > 0`, each end not controlled by the order's country is owed
   `gross × rate / 1000`, rate the end controller's toll level, or Low when the two are partners; `net = gross − those tolls`
   (a loss pays none). The order's record gains `(n, net)`.
8. **Bids filled** (each market, each good): when `supply ≥ Σ bids × 1000`, each bid in full; else each `floor(supply / 1000 × bid
   / Σ bids)` and the loads left one by one to the bidders in country id order. `Stores.move(c, g, +n, &"bought")`; the cost
   `ceil(n × price / 1000)` adds to `c`'s purchases.
9. **The market's people** buy what is left: `consumed = supply / 1000 − filled` (it leaves the game).
10. **Money.** Per market: its controller's `Treasury.move(+floor(owed / 1000), &"tolls", market hex)` (count: routes and orders
    that paid). Per country: `Treasury.move(floor toward −∞ (net sum / 1000), &"trade")` (count: orders), `Treasury.move(−purchases,
    &"purchases")` (count: goods bought). Zero lines are not written.
11. **Orders' flags** (`Merchants.book`): 4.7.
12. **Next prices** (4.5) from the season's `supply` and `demand`; a change over `price_moved_permille` (150) against
    `last_price` emits `price_moved {market, good, from, to, witnesses: the market's stakeholders}` (its controller, the controllers
    of its catchment's hexes, the countries with an order on its routes).
13. **Records.** Each market keeps the season's `offered`, `in`, `out`, `bg`, `bought`, `consumed` (loads) and `demand` (milli);
    each route's record its flows (good, loads, from), its profit, its last 4 seasons' loads, its state.

### 4.7 Merchants

`Merchants.count(game, tag)` = `min(merchants_max (6), merchants_base (1) + the market towns tag controls)`. On north Italy, 1480:

| Tag | FRA | AUS | SWI | SAV | MLO | VEN | GEN | TUS | PAP | MAN | FER | SIE | LUC | All |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Merchants | 1 | 1 | 2 | 3 | 2 | 5 | 2 | 3 | 2 | 2 | 2 | 1 | 1 | 27 |

**An order** (`MerchantOrder`): `{id, tag, route (key), good, from (market id), made_turn, history (last 4 seasons: loads, net), idle,
losing, flag}`. **The estimate** (`Merchants.estimate(game, tag, route, from, good)`, the card's number, D31): `up_to = min(12,
(from.last_bg × 1000 − from.last_demand × 500 / 1000) / 1000 − the loads older orders of every country took there last season)`,
at least 0; `margin = price(to) − price(from) − cost_milli` at this season's prices (exact); `per_load = margin − the tolls a load
(as step 7)`; `+n a season = up_to × per_load / 1000`.

`Merchants.send_merchant_check(game, {from, to, good, tag})`, in order:

| # | Case | Verdict |
|---|---|---|
| 1 | No from, to or good given | "no market given", "no good given" |
| 2 | M7 4.2's rows 2 to 4 (no countries, no tag, an unknown country), and the actor not alive | their words; "%s is no more" |
| 3 | `from` or `to` is not a market | "no market at (%d, %d)" |
| 4 | No route joins them | "no route between Genoa and Bologna: their lands do not meet on a way" (the market names) |
| 5 | `good` is not a good id | "no such good" |
| 6 | The route is not open to the actor (D29) | "merchants work routes from markets where you hold land: none near Milan or Turin" |
| 7 | All its merchants have orders | "all your merchants are busy: 2 of 2; recall one first" |
| 8 | The route is closed for the good by war or embargo | "the road is closed: you are at war with the Duchy of Milan" / "an embargo stands between you and the Duchy of Milan" |
| 9 | The same order exists | "a merchant already carries wine from Genoa to Milan" |
| 10 | Otherwise | ok (a margin of 0 or less is allowed: "at a loss" shows on the card) |

`send_merchant` checks again, appends the order (`next_merchant_id`), `merchant_sent {tag, order, witnesses: [tag, the two ends'
controllers]}`. `recall_merchant_check(game, {order, tag})`: "no order given"; "no order %d"; "not your merchant: the %s sent
it"; else ok; `recall_merchant` removes it, `merchant_recalled`. **`repick_merchants_check(game, {tag})`**: row 2 of the table;
"you have no merchant"; "no order would earn anything this season" (the best estimate is 0 or less); else ok;
**`repick_merchants`** (T2 c, also the AI's rule, D53): the options of `Merchants.options(game, tag)` ranked by estimate (ties:
route key, good, the lower `from`); `best` = the first `count` with an estimate over 0; every order not in `best` is recalled unless
its estimate is at least `merchant_keep_permille` (800) of the best option left out; then the options of `best` not held are sent
while merchants are free.

**After the season** (`Merchants.book`, D30): an order that carried 0 loads in a season it was not suspended (snow, blockade, shut)
has `idle += 1`, else 0; `idle ≥ idle_flag_seasons` (2) sets `flag &"idle"`; `idle ≥ idle_free_seasons` (4) brings it home
(`merchant_freed {why: idle}`). `net < 0` sets `losing += 1`, else 0; `losing ≥ loss_free_seasons` (2) brings it home (`why:
loss`, E5). Its history keeps the last `history_seasons` (4).

### 4.8 Tolls, agreements, embargoes

**Tolls** (`Country.tolls`, 0 Low, 1 Normal, 2 High; start Normal): `Trade.set_tolls_check(game, {level, tag})`: M4 4.10's first four
rows; "no such toll level"; "your tolls are already %s"; else ok. `set_tolls` writes it and emits `tolls_set {tag, level, from}`;
it counts from the next trade phase.

| Level | Share of the profit at the market | Capacity of its routes | Shown as |
|---|---|---|---|
| Low | 50 | 1,250 | "Low" |
| Normal | 100 | 1,000 | "Normal" |
| High | 150 | 750 | "High" |

**Pacts** (`TradePact {id, kind (&"agreement" | &"embargo"), a, b, since_turn, ended_turn (0 while in force), bound (the tag a
peace binds, or &""), bound_until}`; `TradePacts` is the writer; an agreement's `a` is its proposer, an embargo's `a` the
embargoer):

`TradePacts.declare_embargo_check(game, {target, tag})`:

| # | Case | Verdict |
|---|---|---|
| 1 | M7 4.2's rows 1 to 4 (no target, no countries, no tag, an unknown country) | their words |
| 2 | The target is the actor | "a country cannot embargo itself" |
| 3 | Either is not alive | "%s is no more" |
| 4 | At war with the target | "you are at war with the %s: the war closes your roads already" |
| 5 | The actor's embargo on the target is in force | "your embargo on the %s is in force already" |
| 6 | A peace binds the actor to an agreement with the target | "the peace binds you to trade with the %s until %s" (`Calendar.date_text` of `bound_until`) |
| 7 | Otherwise | ok |

`declare_embargo`: the pact; any agreement between the two ends (`trade_agreement_cancelled {why: embargo}`); the target's memory
`embargo` of the actor −20 (`Relations.remember`); every order of either country on a route between a market of the one and a
market of the other comes home (`why: closed`); `embargo_declared {tag, others: [target], witnesses: every living country}`.
`lift_embargo_check`: rows 1 to 3; "you have no embargo on the %s"; else ok. `lift_embargo`: `ended_turn`; `embargo_lifted`.

`TradePacts.sign_trade_agreement_check(game, {target, tag})`:

| # | Case | Verdict |
|---|---|---|
| 1 | Rows 1 to 3 of the embargo table | their words ("a country cannot sign with itself") |
| 2 | At war with the target | "not while at war with the %s" |
| 3 | An embargo either way | "an embargo stands between you and the %s: lift it first" / "the %s keeps an embargo on you" |
| 4 | An agreement in force | "a trade agreement with the %s is in force already" |
| 5 | No route joins a market the actor controls to one the target controls | "your markets and theirs share no road: no route joins them" |
| 6 | The target is the human player and the actor is not (D39) | "the %s decides for itself" |
| 7 | The target's opinion of the actor (`Relations.total`) is under `agreement_min_opinion` (0) | "they refuse: their opinion of you is %+d; they sign from 0" |
| 8 | Otherwise | ok |

`sign_trade_agreement`: the pact; memories `trade` +10 both ways; `trade_agreement_signed {tag, others: [target], forced: false,
witnesses: every living country}`. `cancel_trade_agreement_check`: rows 1 to 3; "no trade agreement with the %s"; a binding peace
("the peace binds you to it until %s"); else ok. `cancel_trade_agreement`: `ended_turn`; the target's memory `trade_cancelled` −10;
`trade_agreement_cancelled {why: cancelled}`.

**While an agreement holds** between the controllers of a route's two ends: its capacity × 1,500 / 1000; each one's merchants pay
the Low toll at the other's markets and may work routes from them (trade rights). **While an embargo holds**: the routes between
their markets carry only war-open goods; each one's goods made in the other's catchments go home; neither's merchants work those
routes. Both are public.

**Relations** (`Relations`, M9, edited): memories `trade` (+10, both, at a signing), `embargo` (−20, the target's of the embargoer),
`trade_cancelled` (−10, the other's of the canceller); standing terms `trade_partner` (+10, both, while an agreement holds) and
`embargo` (−15, the target's of the embargoer, while it holds). The numbers live in `DiplomacyDef` (5.1).

**The peace's open markets** (M9, edited): `Deal.open_markets` (bool) costs `open_markets_price` (5) points. `make_peace_check`
gains, after row 12: "their markets are open to you already: an agreement holds" when the two are partners and no embargo stands.
`Peace.apply` gains a step after the tribute: `TradePacts.apply_open_markets(game, winner, loser)`: the loser's embargo on the winner
ends; an agreement between them is signed or kept, bound on the loser for `forced_agreement_seasons` (20); `trade_agreement_signed
{forced: true}`. `Peace.best_deal` adds open markets after the lots and before the ducats when the loser keeps an embargo on the
winner and 5 points are left. The peace screen shows it as a switch row (6.8).

### 4.9 War

| Case | Effect on trade |
|---|---|
| The controllers of a route's two market towns are at war (`Wars.at_war`) | state `war`: the route carries only war-open goods (grain); orders of other goods on it come home at once |
| An embargo between them | state `embargo`: as war |
| An army of a country at war with either end's controller stands on a hex of the way at the phase (after `movement` and `battles`) | state `blockade`: nothing moves; orders suspended |
| Either market town is besieged (`Occupation.besieged`) | state `shut`: nothing moves; the shut market takes no offers and no bids, its prices held; orders suspended |
| A market town occupied | its controller (the occupier) takes its tolls, counts it for its merchants (D27, D29) and, for routes, is the end's controller |
| A hex's market closed to its controller (war with, or embargo between, it and the market town's controller; or the market shut) | its goods go to its controller's home market at 700 permille |
| Occupied districts | produce for the occupier at half (M7) and sell where it sends them |
| Raids | none (D34) |

On seed 1480, Savoy's declaration on Milan (M9 4.22 a) closes Turin – Milan and Geneva – Milan to all but grain; Savoy's 7 hexes in
Milan's catchment sell at Turin at 70 %; Milan's 2 in Genoa's still sell at Genoa.

### 4.10 Roads

**Living roads.** `MapState.road` and `MapState.crossing` (per edge, `MapData`'s layout), set by `Roads.setup` from the map at the
start; `Roads.set_road` is the only writer. `StepCosts` (M6) reads them through `game.steps`; `EdgeLines` and `Crossings` draw them.

**Road works.** `Works.build_road_check(game, {hex, direction, tag})`, in order:

| # | Case | Verdict |
|---|---|---|
| 1 | No hex or no direction 0 to 5 | "no hex given", "no edge given: a direction 0 to 5" |
| 2 | `game.defs` null | M3's words |
| 3 | The neighbour is off the map or at sea | "roads run between two land hexes" |
| 4 | `Territory.at_home_check` refuses the hex or the neighbour (M2, with M7's control) | its words ("not your land: ..."; "the far side is not your land: the Duchy of Milan holds (9, 9)") |
| 5 | The edge is a crest without a pass | "a ridge: no road crosses here" |
| 6 | The edge's road is a highway | "a highway runs here already" |
| 7 | A road work is under way on the edge | "a road work is under way here: road, ready Summer 1481" |
| 8 | M3's row 7 (slots), M4's rows 8 and 9 (ducats, goods), M9's defiant row (either hex's part) | their words |
| 9 | Otherwise | ok |

`build_road` checks again and appends a `Work` with `action &"road"`, `hex` and `direction` normalised to the side that owns the
edge (directions 0 to 2), `level_to` the road + 1, `seasons` from 4.10's table, and pays (M4); `work_started`. The works phase treats
it as M3's: halted in a snow winter when either hex is snow-climate; lost when either hex is no longer the actor's (`work_cancelled
{why: lost}`); finished: `Roads.set_road(game, tag, edge, level_to)` sets the road and the crossing (below), forgets the two hexes
in `game.steps` and emits `road_built {tag, hex, direction, level, crossing, witnesses (Vision)}`; `work_finished`.

| To | Ducats | Goods | Seasons | On a river or stream edge (crossing set, never lowered) |
|---|---|---|---|---|
| 1 track | 20 | | 2 | a ford (a ferry on a great river, class 3) |
| 2 road | 60 | 10 stone | 4 | a wooden bridge: +20 ducats, +10 timber |
| 3 highway | 150 | 20 stone, 10 timber | 8 | a stone bridge: +100 ducats, +30 stone, +2 seasons |

On a pass edge ducats and goods are doubled. Roads have no upkeep. `MapState.road_work_at(edge)` finds a road work; M3's
`work_at(hex)` keeps finding only district works (a road work never blocks a district's work or a town's growth).

**What a road changes** from the season after it stands (D45): M6's step cost across the edge (a track halves, a road caps at 2, a
highway at 1; a ford adds 1, a bridge 0, so a river class 2 is no longer a wade); so marches, supply, retreats and castle areas
(M6, M7); the catchments (4.3) and the ways, costs and capacities of routes (4.4).

**The road card** (`RoadPreview.of(game, tag, hex, direction)`): `verdict`, `blocked_by` (as M4's card), `title` ("Road from (7, 10)
to (7, 11)"), `level` before → after with the crossing ("none → track, a ford across the river"), `steps` (summer and winter move
cost before → after), `routes` (each route whose way uses the edge: its name, points, cost a load and capacity before → after, the
way re-found on the what-if), `catchment` (hexes that change market or stop being remote), `cost` (ducats, goods, seasons, ready
turn, text), `requirements` (the ticks of the check's rows), `gain_year` (D47: Σ over those routes of the change of cost a load ×
(your merchants' loads + the free traders' loads × your end's toll permille / 1000) over its last 4 seasons, + Σ over your hexes
brought into a market of their last year's goods value × 300 / 1000 × your goods share / 1000), `payback` (M4's rule on `gain_year`
a year, "never" when 0), `map_marks` (the edge and the routes' ways).

### 4.11 The economy after M10 (M4 to M9, edited)

| Place | After M10 |
|---|---|
| `EconomySeason.goods_step` (M4 4.8) | Returns the towns' use and the stock; **no sale**: the surplus above the reserve is left to the trade phase |
| `EconomySeason.production` | Writes `made` and `used`; also `Country.made_markets` (market id → loads made per good this season by the hexes it controls, −1 remote) |
| `EconomySeason.money_lines` (M4 4.9) | `tax_goods` = `sales_open × goods_share_permille[tax] / 1,000,000` (thousandths × permille); the other lines unchanged; M9's weariness reads it as before |
| `Economy.market_of(game, tag)` | The home market (4.3), or `ABROAD` (−2), or `NO_MARKET` (−1) for `&""` |
| `Economy.market_prices(game, view, market, supply)` | `Market.price` (the season's prices) of a market; the base table for `ABROAD`; reads no supply (D16) |
| `EconomyPreview.with` (M4 to M9) | After each simulated `production`, `Trade.country_step` at today's prices held (D48): sales value, taxes on goods, bids filled up to the home market's last season's supply (`offered + in − out`), purchases; tolls and merchants as the last closed ledger's lines |
| `ImprovePreview.of` (M4) | Goods at their catchment market's price (remote 700); `lands` gains the price line: "Sold at Genoa's market: wine 2.50 → about 2.31 next season with it" (`Trade.price_after` with the card's extra loads) |
| The realm's measure, a hex's worth (M4 D29, D34) | Goods at their market's price; a market town's worth adds its last season's tolls |
| `EconomyCards.stores` (M4, the Stores chip) | The stock's worth at the home market's prices |
| `StudyEconomy.history` (M4.5 D35) | In: "Taxes on people", "Taxes on goods", "Dues and trade" (port dues, tolls, a positive merchants' line); out: "Upkeep, army and goods bought" (upkeep, walls, army, purchases, a negative merchants' line), "Your spending" |
| `Treasury.WHY` (M4, M6, M9) | Appends `tolls`, `trade`, `purchases` (17); `left_over` counts all three |
| `Stores.FLOWS` (M4, M6) | Appends `bought` (9) |
| `Reminders.goods_running_out` (M4) | Adds "Genoa's market sells it at 2.10: the stores buy it while the treasury allows." when the home market had supply last season, else "no market near you sold it last season." |

**`TradeFixture.still(defs)`** (tests only): a defs copy with `price_smooth_permille` 0, `route_capacity_base` 0 and every capacity
term 0, `merchants_max` 0, `buy_budget_permille` 0 and `remote_permille` 1000: prices stay at base, nothing moves, nothing is bought,
every sale is M4's. Every pinned number of M4 to M9 runs on it: `ScenarioFixture` (M2, `tests/core/scenario_fixture.gd`), on which
M4 to M9's fixtures (`EconomyFixture`, `InsightsFixture`, `PeopleFixture`, `ArmyFixture`, `CombatFixture`, `WarFixture`, `AiFixture`,
`DiplomacyFixture`) build their games, applies it unless a test asks for trade (`ScenarioFixture.with_trade(true)`); M10's tests ask
for it; the soak and the tools play with trade.

### 4.12 The season table after M10

`Season.PHASES` (16; `test_season.gd` pins it): **`ai_orders`, `movement`, `battles`, `supply`, `sieges`, `war`, `relations`,
`production`, `trade`, `income`, `works`, `people`, `stats`, `calendar`, `ready_units`, `vision`**.

| # | Name | Arrives | Reads | Writes (through the owner) |
|---|---|---|---|---|
| 1 to 7 | `ai_orders` ... `relations` | M8, M6, M7, M9 | as M9 | as M9; the AI's trade acts through `Game.act` |
| 8 | `production` | M4 (M10 edits) | as M9; the trade cache's catchments | `stock`, `flows_open` (made, used); `made_markets` (`EconomySeason`); events as M9 |
| 9 | **`trade`** | **M10** | markets, routes' records, orders, pacts, wars, armies, sieges, controllers, stocks, reserves, `made_markets`, people, treasuries, `defs` | `markets`, `routes` (`Trade`); `merchant_orders` (`Merchants`); `stock`, `flows_open` (sold, bought: `Stores`); `treasury`, `ledger_open` (tolls, trade, purchases: `Treasury`); `sales_open` (`Trade`); events `market_opened`, `market_closed`, `route_closed`, `route_opened`, `merchant_freed`, `price_moved` |
| 10 | `income` | M4 (M10 edits) | as M9; `sales_open` | as M9 (`tax_goods` from the sales) |
| 11 to 16 | `works` ... `vision` | M3 to M7 | as M9; the works phase finishes road works | as M9; `road`, `crossing` (`Roads.set_road`); `stats` writes the price ring and the four series, then calls `Trade.close` (resets `sales_open`) after M4's `Treasury.close_ledger` and `Stores.close` |

Why this order: the harvest is in before the markets open; a country sells and buys before its money is counted; a road built this
season counts from the next.

### 4.13 Events, witnesses, log lines

| Kind | Fields (besides `kind`, `turn`) | Emitted by | Notable | Typed signal | Heard by |
|---|---|---|---|---|---|
| `price_moved` | `market`, `good`, `from`, `to`, `witnesses` (stakeholders) | `Trade.season` | no (the report reads the ring) | `price_moved(market, good)` | `MarketPanel`, `PageTrade` (refresh); log (Money) |
| `merchant_sent` | `tag`, `order` (dict), `witnesses` ([tag, end controllers]) | `Merchants.send_merchant` | no (the action log tells "Your orders") | `merchant_sent(tag, order)` | `MarketPanel`, `TradeMarks`, chips; log |
| `merchant_recalled` | `tag`, `order`, `witnesses` | `Merchants.recall_merchant` | no | `merchant_recalled(tag, order)` | the same |
| `merchant_freed` | `tag`, `order`, `why` (`idle`, `loss`, `closed`, `gone`), `witnesses` ([tag]) | `Merchants.book`, `Merchants.free` | yes | `merchant_freed(tag, order, why)` | `MarketPanel`, `TradeMarks`, chips, task flag; log, notifications |
| `route_closed` | `a`, `b`, `why` (`war`, `embargo`, `blockade`, `shut`), `witnesses` (end controllers, countries with orders on it) | `Trade.season` | yes | `route_closed(a, b, why)` | `TradeMarks`, `MapScene` (route lines), `MarketPanel`; log (War for war and blockade, else Money), notifications (a route with your order) |
| `route_opened` | `a`, `b`, `witnesses` | `Trade.season` | yes | `route_opened(a, b)` | the same; log |
| `market_opened` | `market`, `hex`, `name`, `witnesses` (every living country) | `Trade.refresh_markets` | yes | `market_opened(market)` | `MapScene` (Trade bytes, marks); log, notifications (yours) |
| `market_closed` | `market`, `why`, `witnesses` | `Trade.refresh_markets` | yes | `market_closed(market)` | the same |
| `road_built` | `tag`, `hex`, `direction`, `level`, `crossing`, `witnesses` (Vision: who sees either hex) | `Roads.set_road` | yes | `road_built(tag, hex, direction)` | `MapScene` (the chunk's lines, crossings), `HexPanel`; log (Works), ribbons ("Track", "Road", "Highway") |
| `tolls_set` | `tag`, `level`, `from`, `witnesses` (every living country) | `Trade.set_tolls` | yes | `tolls_set(tag, level)` | `MarketPanel`, `CountryPanel`; log (Money) |
| `embargo_declared` | `tag`, `others` ([target]), `witnesses` (every living country) | `TradePacts.declare_embargo` | yes | `embargo_declared(tag, target)` | `CountryPanel`, `MapScene` (Relations bytes, route lines), `MarketPanel`; log, notifications (on you) |
| `embargo_lifted` | the same | `TradePacts.lift_embargo` | yes | `embargo_lifted(tag, target)` | the same |
| `trade_agreement_signed` | `tag`, `others`, `forced`, `witnesses` (every living country) | `TradePacts.sign_trade_agreement`, `apply_open_markets` | yes | `trade_agreement_signed(tag, target)` | `CountryPanel`, `MapScene` (Relations bytes), `MarketPanel`; log, notifications (with you) |
| `trade_agreement_cancelled` | `tag`, `others`, `why` (`cancelled`, `embargo`), `witnesses` | `TradePacts` | yes | `trade_agreement_cancelled(tag, target)` | the same |

`Chronicle.NOTABLE` gains eleven kinds (**forty**). `Vision.SIGHTED` gains `road_built`. `SeasonSummary.COVERED` gains
`merchant_freed`, `route_closed`, `route_opened`, `market_opened`, `market_closed`, `road_built`, `embargo_declared`,
`embargo_lifted`, `trade_agreement_signed`, `trade_agreement_cancelled`.

**Log lines** (`LogLines.line_of`; filter Money, besides All, and Mine for the player's, unless said):

| Kind | The player's line | A witnessed other's |
|---|---|---|
| `merchant_sent` | "You sent a merchant with wine from Genoa to Milan." | (not witnessed in the log) |
| `merchant_freed` | "Your merchant with salt from Genoa to Pisa came home: it carried nothing for 4 seasons." / "...: it lost money two seasons running." / "...: the road was closed by war with the Duchy of Milan." / "...: the route is gone." keyword "Merchant", warn; `notify` true | |
| `route_closed` | "The road from Genoa to Milan is closed: war with the Duchy of Milan (grain still passes)." / "...: an army of the Duchy of Milan stands on it." / "...: Genoa is besieged." / "...: an embargo." keyword "Road", bad; War filter for war and blockade | "The road from Milan to Turin is closed by war." muted |
| `route_opened` | "The road from Genoa to Milan is open again." plain | muted |
| `market_opened` | "A market opens at Savona (6, 13)." good; `notify` for yours | "A market opens at Pavia (10, 9)." muted |
| `market_closed` | "The market at Pavia (10, 9) closes: Milan's market stands beside it." | muted |
| `road_built` | "A track is laid from (7, 10) to (7, 11), with a ford." keyword "Road", good; Works filter; ribbon "Track" | "The Duchy of Savoy laid a road ..." muted |
| `tolls_set` | "You set your tolls to High." | "The Duchy of Milan set its tolls to High." muted |
| `embargo_declared` | "You declared an embargo on the Duchy of Milan." / "The Duchy of Milan declared an embargo on you: no trade between your markets but grain." bad; `notify` true | "Milan declared an embargo on Venice." muted |
| `embargo_lifted` | "You lifted your embargo on the Duchy of Milan." / "The Duchy of Milan lifted its embargo on you." good | muted |
| `trade_agreement_signed` | "You signed a trade agreement with the Republic of Venice: Low tolls and half again as much on the roads between you." / forced: "The peace opens your markets to the Duchy of Milan until Winter 1488." `notify` true | muted |
| `trade_agreement_cancelled` | "You cancelled the trade agreement with the Republic of Venice." / "The Republic of Venice cancelled its trade agreement with you." | muted |
| `price_moved` | (your stake only) "Grain in the Genoa market rises 1.10 → 1.30 (▲ +18 %)." keyword "Price"; `notify` false | |

### 4.14 What you may know of others

| Thing | You see |
|---|---|
| Markets, their towns, catchments, routes, ways, route states, roads, crossings, road works under way on the map | everything (the map) |
| A market's prices, price ring, supply, demand, in and out | only when the market is **known** (`Knowledge.market_seen`, D52); else "?" |
| Others' orders on routes of a known market (country, good, direction) | yes ("Competition here") |
| Others' tolls levels, embargoes, agreements | everything, public |
| Others' sales, purchases, stores, merchants' profits | nothing |
| Your own everything | exact |

`Knowledge.market_seen(game, viewer, market)`: true for `&""`; when the viewer controls a hex of its catchment, or of a market a
route joins it to; or `Knowledge.knows(viewer, its controller)` (M3, M6). `Knowledge.prices_seen(game, viewer, market)` returns the
price vector or an empty array. The AI's door (M8) reads prices only through it.

### 4.15 Worked examples

**(a) `TradeFixture.duo`** (tests only; `tests/core/trade_fixture.gd`): a 9 × 3 map of lowland farmland, frost climate; West (1, 1),
a walled town (level 4, 30,000 people) of country WES (columns 0 to 3); East (7, 1), a city (level 5, 60,000) of EAS (columns 4 to 8);
a highway on the six edges of row 1 between them. Catchments: West's columns 0 to 3, East's 4 to 8 (the tie at column 4 goes to the
city); one route, 6 points, capacity 6 + 8 + 2 + 4 = **20**, cost 150 + 90 = **240** a load; tolls Normal. The fixture's defs copy
gives wine an appetite of 200 (others 0) and no buying: West wants 30 × 200 = **6,000** milli a season, East **12,000**. Before each
phase WES's stores hold 20 wine over its reserve, all made in West's catchment (the fixture sets the stock and `made_markets`); EAS
has none. Wine's base is 2,500.

| Season | Paid West / East | Margin | Free traders | Merchant | West supply → r → target → next | East supply → r → target → next | Tolls West / East | WES's money |
|---|---|---|---|---|---|---|---|---|
| 1 | 2,500 / 2,500 | −240 | none | | 20,000 → 333 → 1,272 → **1,886** | 0 → 13,000 → 8,750 → **5,625** | 0 / 0 | sales 50,000: taxes on goods 35 |
| 2 | 1,886 / 5,625 | 3,499 | 12 (spare 15, want 12) | | 8,000 → 777 → 2,145 → **2,015** | 12,000 → 1,000 → 2,500 → **4,063** | 4,198 / 4,198: **4 / 4** | sales 37,720: 26; tolls +4 at West (1, 1) |
| 3 | 2,015 / 4,063 | 1,808 | 12 | WES's, West → East: 5 (8,000 − 3,000) | 3,000 → 1,750 → 3,487 → **2,751** | 17,000 → 722 → 2,050 → **3,057** | 2,169 / 2,169 + 904: **2 / 3** | sales 40,300: 28; tolls +2; trade +8 (9,040 less East's 904) |

The card before season 3 reads "up to 5" (season 2's supply after the free traders at West, 8 loads, less half of 6) and "+8 a
season" (5 × 1,808 = 9,040, less East's toll of a tenth): what season 3 delivers.

**(b) The embargo.** As (a), but EAS declares an embargo on WES in season 3 after WES sent its merchant: the order comes home at once
(`merchant_freed {why: closed}`); the route carries no wine (wine is not war-open). Season 3: no free traders, no merchant; West's
supply 20,000 → 1,272 → next **1,644**; East's 0 → 8,750 → next **6,406**. WES's season 3 ledger lacks the tolls (+2) and the trade
(+8) lines of (a) and nothing else (its sales were at 2,015 either way); EAS's lacks its tolls (+3).

**(c) `TradeFixture.chain`** (tests only): three markets A, B, C on a line, each one route apart; A offers grain, B and C want it.
In a season the free traders carry grain A → B; a merchant of B's owner on B → C carries grain found at B after the free traders,
which includes A's: T1. The test pins the numbers the build gives.

**(d) North Italy, seed 1480, as Genoa** (`test_trade_italy.gd`, the numbers the build gives pinned): the 14 markets, catchments,
routes and homes of 4.2 to 4.4; Genoa's 2 merchants; its routes Turin – Genoa, Milan – Genoa, Bologna – Genoa, Genoa – Pisa. Spring
1480: every market at base, every margin negative: nothing moves; sales at base (Genoa's one remote hex makes nothing); Summer's
prices follow Spring's supply and demand by 4.5 (the test recomputes each from the record). Genoa's salt runs out in Winter 1480
(M4 4.15): from then its bids go to Genoa's market, and the free traders bring salt from the Venetian pans along Venice – Verona –
Milan – Genoa as the gaps open. Done-when 1's poor-harvest case and done-when 2's tolls and embargo run on this game.

**(e) A track and a ford** (seed 1480, as Savoy, Spring 1480): `build_road {hex: (7, 10), direction: 5}`: the edge between (7, 10)
and (7, 11), both Savoy's farmland, crossed by a river of class 2 with no crossing; the work is stored on (7, 11), direction 2; 20
ducats, 2 seasons (ready Autumn 1480), a free slot of Savoy's 2. From Autumn 1480: the step is farmland 2 with a track (halved: 1)
and a ford (+1): **2** points (a wade before: an army's whole season, 8 points in a trade way); the Turin – Genoa way **17 → 11**
points, its cost **405 → 315** thousandths a load; its lowest road still none, its capacity 8. The road card shows these before the
work begins; its "about +n a year" is 0 in Spring 1480 (no season of trade is on record yet) and from then the toll of Savoy's
Turin on the free traders' gain plus its merchants' saving on the route.

### 4.16 The AI (M8's, edited)

A seat's turn after M10: `brief`, `peace`, `diplomacy`, `war`, `works_scan` × 2, `works_card` × k, `works_act`, **`trade`**,
`forces`, `army` × n, `tax`, `done`. The AI acts only in `ai_orders`, through `AiKnow` and `Game.act`, with no memory and no luck in
its trade step.

**The trade step** (`AiTrade.trade`, new, one step a seat):

1. **Tolls**: when its level is not its temperament's `tolls_level`, `set_tolls`.
2. **Merchants**: `AiKnow.merchant_options(game, t)` (the options of `Merchants.options` with markets it may know, rival orders
   counted), then `repick_merchants`'s rule (D53) acted as single `recall_merchant` and `send_merchant` acts (the AI sees each
   refusal), an option at least `merchant_min_profit` (1) a season.
3. **Pacts**, when `(turn + id) mod pact_every (8) == pact_turn (2)`: lift each of its embargoes whose target it now likes above its
   `embargo_opinion` + 20; declare one on the neighbour it likes least at or under `embargo_opinion` (not at war, not a partner);
   sign one with a route partner (a controller at the other end of a route from its markets) at or above `agreement_opinion`,
   asking the check for them in descending opinion (ties: id) and signing the first it allows, at most `order_tries` (2, M8) checks
   a think (the target's acceptance and the player's refusal, D39, are the check's); cancel one with a partner it likes at −30 or
   less.

**Roads in the works scan** (`AiEconomy.works_scan`, M8, edited): besides 4.7's hexes, `road_scan_edges` (8) edges a season: the
edges of the ways of routes from its markets, in its controlled land, under highway, with no road work under way, the busiest route
first (its last 4 seasons' loads), then edge index. Their prior is `gain_year × 1000 / cost` (cost as M8's prior: ducats + goods at
price); they are carded with `AiKnow.road_card` (the road card's verdict and payback) beside the district cards, under the same
`works_cards`, `payback_max` and reserve rules.

| `AiTemperDef` field (new) | builder | cautious | steadfast | aggressive | opportunist | conqueror |
|---|---|---|---|---|---|---|
| `tolls_level` | 0 Low | 1 Normal | 1 Normal | 2 High | 2 High | 2 High |
| `embargo_opinion` (embargoes at or under; −101 never) | −101 | −101 | −70 | −50 | −60 | −40 |
| `agreement_opinion` (signs at or over; 101 never) | 0 | 10 | 15 | 40 | 20 | 101 |

| `AiDef` field (new) | Value | Used in |
|---|---|---|
| `merchant_min_profit` | 1 | the least a season an option must bring |
| `merchant_keep_permille` | 800 | an order kept at this share of the best option left out |
| `pact_every`, `pact_turn` | 8, 2 | a seat thinks of pacts when `(turn + id) mod 8 == 2` |
| `road_scan_edges` | 8 | road candidates a season |

**`AiKnow` grows** (the door; 5.7): `markets_of`, `home_market`, `merchant_options`, `orders_of`, `merchants_free`, `tolls_level`,
`pacts_of`, `route_partners`, `road_candidates`, `road_card`. `AiBrief` gains `merchants`, `orders`, `tolls`. **The door's text
rule** (M8 4.3) adds the tokens `Trade.`, `Merchants.`, `TradePacts.`, `Roads.`, `TradeCache`, `game.markets`, `game.routes`,
`game.merchant_orders`, `game.pacts`, `game.trade_cache`, `game.steps`. **The fog** adds: unknown markets' prices and others' sales,
purchases and merchants' profits are never read; `test_ai_fog.gd` changes them and finds the same acts.

### 4.17 The soak

`godot/tools/soak.gd` (M8, M9) gains five invariants and the ranges below; no new suite (every suite trades).

| Invariant | Holds after every season |
|---|---|
| `prices` | every market price and every ring slot of every good between 300 and 3,500 permille of its base |
| `markets` | per market and good, the season's offered + in − out − bought − consumed = 0; per good, Σ in = Σ out over the routes |
| `orders` | every order's country alive, its route and markets existing, at most `Merchants.count` orders a country, no order on a route closed by war or embargo for its good |
| `roads` | every road 0 to 3, none on a crest edge without a pass, no road lower than at the start |
| `pacts` | no agreement and embargo in force between one pair; no pact with a dead country; at most one agreement a pair; every binding peace's agreement in force until its date |

| Measure | Suite | Range |
|---|---|---|
| merchant-seasons with an order working | ai | median ≥ 60 % |
| order-seasons that carried nothing (not suspended) | ai | ≤ 30 % (v0.2.2: 78 to 88 %) |
| order-seasons at a loss | ai | ≤ 10 % |
| trade income (tolls and merchants) a country's share of its income | ai | median 3 % to 30 % |
| market-good-seasons at the cap, for goods made on the map | ai | ≤ 25 % |
| the median absolute change of a made good's price from one season to the next | ai | 1 % to 15 % |
| loads bought a country a year | ai | median ≥ 1 |
| embargoes declared a game | ai | median 0 to 3 |
| agreements signed a game | ai | median 0 to 6 |
| road works begun a country in 80 seasons | ai | median 0 to 10 |
| M8's and M9's ranges | as M8, M9 | as M8, M9 (the treasury and money ranges with trade) |

The summary's per-country table gains: merchants working, loads carried, trade income, tolls, purchases, roads built. The ranges are
starting values; the tuning task (X31) measures and keeps them, or changes one with Opus's word in its pull request.

### 4.18 The season report after M10

`SeasonSummary.SECTIONS`: glance, before, treasury, goods, **trade**, works, people, armies, war, diplomacy, orders, befell, standing
(13).

| Id | M10 content |
|---|---|
| `glance` | a **Trade** chip ("Trade +15") when tolls + merchants is not 0 |
| `treasury` | new lines "Tolls at Genoa ▲ +6" (one a market, merged with `Words.list` past three), "Merchants ▲ +9" (or ▼), "Goods bought ▼ −9" |
| `goods` | the flow word "bought" ("Salt 4 ▲ +1 (bought 2, used 1)") |
| `trade` (**new**) | `total` "Trade +15 a season" (tolls + merchants); a line an order ("Wine from Genoa to Milan: 12 carried, +9"; "carried nothing: the road is shut by snow"; "idle 2 seasons: it comes home after 2 more"); a line a market of yours with tolls ("Tolls at Genoa: +6 from 3 routes"); purchases (`sub`: "Bought for the reserve at Genoa: 2 salt, 4 grain (−9)"); **price lines** for the markets where you have a stake whose next price moved more than 15 % (read from the ring and the market: "Grain in the Genoa market rises 1.10 → 1.30 (▲ +18 %): less on offer (8 against 14)."; at most 3, by `|change| × base`); the season's trade events of yours (routes closed and opened, merchants home, markets opened and closed, pacts). Rank: an order its `|net|`, tolls their ducats, a price line `|change| × base / 1000`, an event 20 |
| `orders` | "Sent a merchant with wine from Genoa to Milan.", "Recalled ...", "Re-picked your merchants.", "Set your tolls to High.", "Declared an embargo on ...", "Signed a trade agreement with ...", "Ordered a road from (7, 10) to (7, 11)." |
| `befell` | others' pacts and tolls (public), markets opened and closed, roads built in sight |

**Quiet** (M9's rule, plus): no trade event of yours and no price line.

### 4.19 Reminders after M10

`Reminders.RULES` gains `merchant_idle` and `merchant_flagged` after `treasury_falling`, and `embargo_on_you` after `league_open`.

| Rule | When | Severity | Text | Action |
|---|---|---|---|---|
| `merchant_idle` | a merchant of yours has no order | 1 | "1 of your 2 merchants is idle: wine from Genoa to Milan would bring about +9 a season." / "... idle: no route of yours pays this season." | `[&"send_merchant", {from, to, good}]`, "Send" (T5's one click); with no option `[&"market", home]`, "Open the market" |
| `merchant_flagged` | an order of yours flagged idle | 1 | "Your merchant with salt from Genoa to Pisa has carried nothing for 2 seasons: it comes home after 2 more." | `[&"market", from]`, "Open the market" |
| `embargo_on_you` | another country keeps an embargo on you | 0 | "The Duchy of Milan keeps an embargo on you: no trade between your markets but grain." | `[&"country", tag]`, "Show Milan" |

### 4.20 Stats after M10

`Stats.SERIES` appends `tolls` (ducats received), `purchases` (ducats spent on goods), `sales` (ducats of goods sold, the sales value
/ 1000) and `merchants` (orders working this season) (**58** series); `income_trade` (M3) is now written: tolls + the merchants'
line. **The price ring** (stats/2): `Stats.markets` (`PackedInt32Array` of market ids in the order they first opened) and
`Stats.price_ring` (`[(m × RING + turn % RING) × G + g]`, the price **paid** that season, milli); the stats phase writes it from
`Market.last_price`; a market that opens later appends its id and its ring reads empty before it; a closed market keeps its ring.
`Stats.price_series(market, good, span)` (newest last) and `price_at(market, good, turn)` read it. Sizes on the made-up Europe:
about 170 markets × 40 × 16 = 109,000 ints (0.44 MB before compression).

### 4.21 Saves and the digest

| Body key | M10 adds | In `Game.digest()` |
|---|---|---|
| `format` | 8 (`SaveFile.FORMAT`; `OLDEST_FORMAT` 8) | no |
| `trade` (**new**) | `{schema: "hexa-godot/trade/1", markets: [Market.to_dict()], routes: [RouteRecord.to_dict()], merchant_orders: [MerchantOrder.to_dict()], next_merchant_id, pacts: [TradePact.to_dict()], next_pact_id}` | each `digest_text()` in id order, joined |
| `map_state` | `map-state/7`: `road`, `crossing` (bytes per edge); works `work/3` (`direction`); schema 6 reads with the map's roads (tests only) | `MapState.digest()` adds both |
| `countries` | `country/6`: `tolls`, `sales_open`, `made_markets`; `country/5` refused | each `digest_text()` |
| `stats` | `stats/2`: `markets`, `price_ring`, the four series | `Stats.digest()` |
| `diplomacy` (M9) | its offers are `peace-offer/2` (the deal's `open_markets`) | as M9 |
| `action_log` | M10's actions; the dev record `dev_price` | no |
| (not saved) | `game.steps` (`StepCosts`), `game.trade_cache` (`TradeCache`) | no |

Sizes on the made-up Europe: the roads and crossings 2 × 366,000 bytes before compression (mostly zero), the markets about 170 × 10
arrays × 16, the ring 0.44 MB, the orders and pacts a few hundred entries; `save_mb` stays 8.

---

## 5. Interfaces

Layers after M8: `defs`, `state`, `systems`, `game`, `views`, `ai`, `shell`. `core/` makes no engine calls; M10's rules take no
luck. New files are marked **new**; "(M2)" to "(M9)" name pieces those milestones build. Every amount is an `int`, every rate a
permille, every price in thousandths. Systems never call `Words`: their words name a hex by `Military.hex_text` (M6), a country by
"the " + its long name, a market by `Trade.market_name`, a date by `Calendar.date_text` (M3).

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/trade_def.gd  (new): every number of 4.2 to 4.10, one inspector
class_name TradeDef extends Resource
# markets and catchments
@export var market_level := 4
@export var market_spacing := 1
@export var market_reach := 12
@export var remote_permille := 700
@export var wade_points := 8
# prices
@export var price_floor_permille := 300
@export var price_cap_permille := 3500
@export var price_curve: PackedInt32Array      # pairs (r, curve), r ascending: 0,300, 250,435, 500,660, 750,841, 1000,1000,
	# 1500,1275, 2000,1516, 3000,1933, 4000,2297, 6000,2930, 8000,3482
@export var price_k_milli := 1000
@export var price_smooth_permille := 500
@export var price_moved_permille := 150
@export var spare_permille := 700
@export var merchant_spare_permille := 500
# routes and tolls
@export var route_capacity_base := 6
@export var capacity_by_road: PackedInt32Array  # 4 (none, track, road, highway): 0, 2, 4, 8
@export var capacity_by_level: PackedInt32Array # 6 (settlement level 0 to 5): 0, 0, 0, 0, 2, 4
@export var route_cost_base_milli := 150
@export var route_cost_point_milli := 15
@export var toll_permille: PackedInt32Array     # 3 (Low, Normal, High): 50, 100, 150
@export var toll_capacity_permille: PackedInt32Array   # 3: 1250, 1000, 750
# merchants
@export var merchants_base := 1
@export var merchants_max := 6
@export var merchant_capacity := 12
@export var idle_flag_seasons := 2
@export var idle_free_seasons := 4
@export var loss_free_seasons := 2
@export var history_seasons := 4
# buying
@export var buy_budget_permille := 250
@export var buy_order: Array[StringName] = []  # &"grain", &"salt", &"wine", &"oil", &"timber", &"stone", &"iron", &"horses", &"copper"
# pacts
@export var agreement_capacity_permille := 1500
@export var agreement_min_opinion := 0
@export var forced_agreement_seasons := 20
# road works (index = the level reached: 0 none, 1 track, 2 road, 3 highway)
@export var road_ducats: PackedInt32Array       # 0, 20, 60, 150
@export var road_goods: Array[Dictionary] = []  # {}, {}, {stone: 10}, {stone: 20, timber: 10}
@export var road_seasons: PackedInt32Array      # 0, 2, 4, 8
@export var pass_cost_permille := 2000
@export var bridge_ducats: PackedInt32Array     # 0, 0, 20, 100 (ford or ferry free; wooden; stone)
@export var bridge_goods: Array[Dictionary] = [] # {}, {}, {timber: 10}, {stone: 30}
@export var bridge_seasons: PackedInt32Array    # 0, 0, 0, 2
func curve(r: int) -> int                       # 4.5's interpolation; price_cap_permille from the last point on
func validate(defs: GameDefs) -> Array[String]
	# counts >= 0; market_level 1..5; market_reach 1..60; permilles 0..10000 where a multiplier, 0..1000 where a share; the
	# curve's pairs ascending in r and in curve, from (0, floor) to under the cap; floor < 1000 < cap; arrays sized (4, 6, 3,
	# 3, 4 of each road table); buy_order and the road and bridge goods known GoodDef keys; merchants_base <= merchants_max

# core/defs/good_def.gd  (M4, edit)
@export var appetite_milli := 0     # thousandths of a load a season per 1,000 town people of a market's catchment (4.5)
@export var war_open := false       # carried on a route closed by war or embargo (grain)
# validate() adds: appetite 0..10000

# core/defs/diplomacy_def.gd  (M9, edit)
@export var opinion_trade := 10
@export var opinion_embargo := -20
@export var opinion_trade_cancelled := -10
@export var standing_partner := 10
@export var standing_embargo := -15
@export var open_markets_price := 5
# validate() adds: the signs above; open_markets_price 1..score_max

# core/defs/game_defs.gd  (M2 to M9, edit)
@export var trade: TradeDef = null  # external: data/defs/trade.tres
# validate() adds: trade set and valid

# core/defs/ai_temper_def.gd  (M8, M9, edit)
@export var tolls_level := 1
@export var embargo_opinion := -101
@export var agreement_opinion := 101
# validate(): tolls_level 0..2; both opinions -101..101
# core/defs/ai_def.gd  (M8, M9, edit)
@export var merchant_min_profit := 1
@export var merchant_keep_permille := 800
@export var pact_every := 8
@export var pact_turn := 2
@export var road_scan_edges := 8
# validate(): pact_turn < pact_every; road_scan_edges 0..40; keep 0..1000
```

### 5.2 State (`core/state/`)

```gdscript
# core/state/market.gd  (new)
class_name Market extends RefCounted
const SCHEMA := "hexa-godot/market/1"
var id: int                          # the market town's hex index
var hex: Vector2i
var name: String
var opened_turn: int
var price: PackedInt32Array          # per good: the price of the next season's deals (milli); Trade only
var last_price: PackedInt32Array     # per good: the price paid in the last trade phase
var last_offered: PackedInt32Array   # per good, loads, the last trade phase
var last_in: PackedInt32Array
var last_out: PackedInt32Array
var last_bg: PackedInt32Array        # supply after the free traders (loads): what merchants could find
var last_bought: PackedInt32Array
var last_consumed: PackedInt32Array
var last_demand: PackedInt32Array    # milli
var shut := false                    # besieged at the last phase
static func opened(id_value: int, hex_value: Vector2i, name_value: String, defs: GameDefs, turn: int) -> Market  # base prices
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> Market   # null on a wrong schema, size or type
func digest_text() -> String

# core/state/route_record.gd  (new): what a route did last season
class_name RouteRecord extends RefCounted
const SCHEMA := "hexa-godot/route-record/1"
var key: Vector2i                    # (a, b) market ids, a < b
var state: StringName = &"open"      # &"open", &"winter", &"blockade", &"shut", &"war", &"embargo"
var flows: Array[Dictionary] = []    # [{good, loads, from}] the free traders' last season
var profit: int = 0                  # milli, the free traders' last season
var loads: PackedInt32Array          # the last 4 seasons' loads (free traders and merchants), newest last
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> RouteRecord
func digest_text() -> String

# core/state/merchant_order.gd  (new)
class_name MerchantOrder extends RefCounted
const SCHEMA := "hexa-godot/merchant-order/1"
var id: int
var tag: StringName
var route: Vector2i
var good: int
var from: int                        # a market id of the route
var made_turn: int
var history: PackedInt32Array        # [loads, net] for the last history_seasons seasons, newest last
var idle := 0
var losing := 0
var flag: StringName = &""           # &"" or &"idle"
func to(route_key: Vector2i) -> int  # the other end
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> MerchantOrder
func digest_text() -> String

# core/state/trade_pact.gd  (new)
class_name TradePact extends RefCounted
const SCHEMA := "hexa-godot/trade-pact/1"
var id: int
var kind: StringName                 # &"agreement", &"embargo"
var a: StringName                    # the proposer, or the embargoer
var b: StringName
var since_turn: int
var ended_turn := 0                  # 0 while in force
var bound: StringName = &""          # the country a peace binds to the agreement
var bound_until := 0
func in_force() -> bool
func between(x: StringName, y: StringName) -> bool   # either order
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> TradePact
func digest_text() -> String

# core/state/country.gd  (M2 to M9, edit): schema "hexa-godot/country/6" (country/5 refused)
var tolls := 1                                  # Trade: 0 Low, 1 Normal, 2 High
var sales_open := 0                             # Trade: the season's sales value, milli; reset by Trade.close
var made_markets: Dictionary = {}               # EconomySeason: market id (int, -1 remote) -> PackedInt32Array (per good)
# digest_text() appends "|tolls|sales_open|" + made_markets in key order "id:n,n,...;"

# core/state/map_state.gd  (M1 to M9, edit): schema "hexa-godot/map-state/7"
var road: PackedByteArray            # per edge (MapData's layout): 0 none, 1 track, 2 road, 3 highway; Roads only
var crossing: PackedByteArray        # per edge: MapData's crossing codes; Roads only
func road_at(edge: int) -> int
func crossing_at(edge: int) -> int
func road_work_at(edge: int) -> Work # a work with action &"road" on this edge, or null
# work_at(hex) returns district works only (direction -1); create() copies both arrays from the map; duplicate_state() copies
# them; to_dict() adds them packed; from_dict() reads 7, and 1 to 6 with the map's arrays (tests only); digest() adds both

# core/state/work.gd  (M3, M4, edit): schema "hexa-godot/work/3"
var direction := -1                  # -1 a district work; 0..2 a road work on hex's owned edge (action &"road")
# to_dict adds direction; work/2 loads with -1; digest_text adds "|direction"

# core/state/stats.gd  (M3 to M9, edit): schema "hexa-godot/stats/2" (stats/1 reads with no ring)
# SERIES appends "tolls", "purchases", "sales", "merchants" (58)
var markets: PackedInt32Array        # market ids in the order they first opened
var price_ring: PackedInt32Array     # [(m * RING + turn % RING) * goods + g]: the price paid that season, milli
func add_market(id: int) -> int      # its index (appends a ring of zeros)
func price_at(market: int, good: int, turn: int) -> int       # 0 when absent
func price_series(market: int, good: int, span: int) -> PackedInt32Array   # newest last, the seasons written
# to_dict, from_dict, digest() carry both

# core/state/deal.gd  (M9, edit)
var open_markets := false
# from_args reads {hexes, ducats, open_markets}; to_args, to_dict, digest_text add it; is_empty() is false when it is set

# core/state/peace_offer.gd  (M9, edit): schema "hexa-godot/peace-offer/2" (its deal carries open_markets; /1 refused)

# core/game/game.gd  (M1 to M9, edit; the fields)
var markets: Array[Market] = []                   # Trade; id order
var routes: Array[RouteRecord] = []               # Trade; key order
var merchant_orders: Array[MerchantOrder] = []    # Merchants; id order
var next_merchant_id := 1                         # Merchants
var pacts: Array[TradePact] = []                  # TradePacts; id order
var next_pact_id := 1                             # TradePacts
var steps: StepCosts = null                       # the door's derived step table (StepCosts.for_game); not saved
var trade_cache: TradeCache = TradeCache.new()    # the door's derived trade cache; not saved, not in the digest
```

### 5.3 Systems (`core/systems/`)

```gdscript
# core/systems/trade_cache.gd  (new): derived, rebuilt on demand, never saved. Called as game.trade_cache.<func>(game).
class_name TradeCache extends RefCounted
func catchment(game: Game) -> PackedInt32Array      # per hex: the index in game.markets, -1 remote or sea (4.3)
func points_to(game: Game) -> PackedInt32Array      # per hex: the points to its market, -1
func market_of_hex(game: Game, hex: Vector2i) -> int   # a market id, -1 remote
func routes(game: Game) -> Array[Dictionary]        # key order: {key: Vector2i, a, b (market ids), edges: PackedInt32Array,
	# hexes: PackedInt32Array (the way, town to town), points, winter_points (-1 closed), road, capacity_base, cost_milli,
	# winter_cost_milli}
func route(game: Game, key: Vector2i) -> Dictionary # {} none
func routes_of(game: Game, market: int) -> Array[Vector2i]
func colours(game: Game) -> PackedByteArray         # per market index: 0..5, greedy over catchment adjacency in id order
func home_market(game: Game, tag: StringName) -> int   # 4.3; Economy.ABROAD
func town_people(game: Game, market: int) -> int    # 4.3; cached by version
func forget_all() -> void                           # a road built, a settlement's level changed, a market opened or closed
func filled_ms() -> float                           # the last cold build (F3, perf)

# core/systems/trade.gd  (new): markets, the trade phase, tolls, the country step, prices
class_name Trade extends RefCounted
const OWNS: Array[String] = ["markets", "routes", "tolls", "sales_open"]
const STATES: Array[StringName] = [&"open", &"winter", &"blockade", &"shut", &"war", &"embargo"]
static func setup(game: Game) -> void                     # new_scenario: the markets of 4.2 at base prices; routes' records;
	# nothing in a map-only game
static func market_hexes(game: Game) -> PackedInt32Array  # 4.2's rule on the state now
static func refresh_markets(game: Game) -> void           # 4.2; market_opened, market_closed; Merchants.free(gone); forget_all
static func market(game: Game, id: int) -> Market         # null none
static func market_name(game: Game, id: int) -> String
static func route_state(game: Game, route: Dictionary, good: int) -> StringName   # 4.9 for the season in play
static func closed_to(game: Game, market: int, tag: StringName) -> bool           # shut, war or embargo with its controller
static func toll_rate(game: Game, market: int, payer: StringName) -> int           # permille: the controller's level, Low for
	# partners, 0 for the controller itself or an unowned town
static func capacity(game: Game, route: Dictionary) -> int                          # 4.4 with tolls and agreements
static func appetite(game: Game, market: int, good: int) -> int                     # milli (4.5)
static func next_price(defs: GameDefs, good: int, price: int, supply_milli: int, demand_milli: int) -> int   # 4.5, pure
static func price_after(game: Game, market: int, good: int, extra_loads: int) -> int
	# next_price with last season's supply + extra_loads and last season's demand: the card's price line
static func country_step(game: Game, tag: StringName, stock: PackedInt32Array, reserve: PackedInt32Array,
		made_markets: Dictionary, treasury: int, prices: Callable) -> Dictionary
	# pure (4.6 steps 3 and 4): {offers: [{market, good, loads, remote}], bids: [{market, good, loads}], sales_milli: int};
	# prices(market, good) -> int; the phase passes Market.last_price, the preview today's held prices
static func set_tolls_check(game: Game, args: Dictionary) -> Dictionary   # {level, tag}; 4.8
static func set_tolls(game: Game, args: Dictionary) -> Dictionary         # Country.tolls; tolls_set
static func season(game: Game) -> void                                     # the trade phase (4.6)
static func close(game: Game) -> void                                      # every country's sales_open = 0 (the stats phase)

# core/systems/merchants.gd  (new): orders, their pairs, the card's estimate, the season's carrying
class_name Merchants extends RefCounted
const OWNS: Array[String] = ["merchant_orders", "next_merchant_id"]
const WHY: Array[StringName] = [&"idle", &"loss", &"closed", &"gone"]
static func count(game: Game, tag: StringName) -> int                       # 4.7
static func orders_of(game: Game, tag: StringName) -> Array[MerchantOrder]
static func free_count(game: Game, tag: StringName) -> int
static func may_work(game: Game, tag: StringName, route: Dictionary) -> bool   # D29
static func estimate(game: Game, tag: StringName, route: Vector2i, from: int, good: int) -> Dictionary
	# {up_to, margin, per_load, tolls, per_season, at_loss: bool, rivals: int} (4.7)
static func options(game: Game, tag: StringName) -> Array[Dictionary]        # every {route, from, to, good} it may send,
	# with its estimate, ranked as 4.7; the AI's door filters it by Knowledge
static func best(game: Game, tag: StringName) -> Dictionary                  # the first option over 0, or {}
static func send_merchant_check(game: Game, args: Dictionary) -> Dictionary # {from, to, good, tag}; 4.7
static func send_merchant(game: Game, args: Dictionary) -> Dictionary
static func recall_merchant_check(game: Game, args: Dictionary) -> Dictionary   # {order, tag}
static func recall_merchant(game: Game, args: Dictionary) -> Dictionary
static func repick_merchants_check(game: Game, args: Dictionary) -> Dictionary  # {tag}
static func repick_merchants(game: Game, args: Dictionary) -> Dictionary
static func carry(game: Game, supply: Dictionary, demand: Dictionary, owed: Dictionary) -> Dictionary
	# the phase's step 7: walks the orders on the trade phase's working supply (market id -> PackedInt32Array milli), writes
	# nothing of the game; returns {results: order id -> Vector2i(loads, net milli), moved: [{route, good, loads, from}]}
static func book(game: Game, results: Dictionary, suspended: PackedInt32Array) -> void   # 4.7's flags; merchant_freed
static func free(game: Game, order: MerchantOrder, why: StringName) -> void             # removes; merchant_freed

# core/systems/trade_pacts.gd  (new)
class_name TradePacts extends RefCounted
const OWNS: Array[String] = ["pacts", "next_pact_id"]
static func embargo_between(game: Game, a: StringName, b: StringName) -> bool    # either way, in force
static func embargo_by(game: Game, a: StringName, b: StringName) -> TradePact    # a's on b; null none
static func partners(game: Game, a: StringName, b: StringName) -> bool
static func binding(game: Game, tag: StringName, other: StringName) -> TradePact # a peace binding tag to other; null
static func pacts_of(game: Game, tag: StringName) -> Array[TradePact]           # in force, id order
static func declare_embargo_check(game: Game, args: Dictionary) -> Dictionary   # {target, tag}; 4.8
static func declare_embargo(game: Game, args: Dictionary) -> Dictionary
static func lift_embargo_check(game: Game, args: Dictionary) -> Dictionary
static func lift_embargo(game: Game, args: Dictionary) -> Dictionary
static func sign_trade_agreement_check(game: Game, args: Dictionary) -> Dictionary
static func sign_trade_agreement(game: Game, args: Dictionary) -> Dictionary
static func cancel_trade_agreement_check(game: Game, args: Dictionary) -> Dictionary
static func cancel_trade_agreement(game: Game, args: Dictionary) -> Dictionary
static func apply_open_markets(game: Game, winner: StringName, loser: StringName) -> void   # Peace.apply's step (4.8)

# core/systems/roads.gd  (new): the only writer of the living roads
class_name Roads extends RefCounted
const OWNS: Array[String] = ["road", "crossing"]
static func setup(game: Game) -> void                       # new_scenario: MapState.road, crossing from MapData
static func edge_of(map: MapData, hex: Vector2i, direction: int) -> Vector2i   # the owning side: (hex, 0..2), or (-1, -1)
static func road_check(game: Game, hex: Vector2i, direction: int) -> Dictionary   # rows 3, 5, 6 of 4.10 (the edge's rules)
static func cost_of(game: Game, edge: int, level_to: int) -> Dictionary  # {ducats, goods: {key: n}, seasons, crossing_to}
static func crossing_for(game: Game, edge: int, level_to: int) -> int    # D42; never below the crossing now
static func set_road(game: Game, tag: StringName, edge: int, level_to: int) -> void   # road, crossing; game.steps forgets
	# the two hexes (through Game.emit); road_built

# core/systems/works.gd  (M3 to M9, edit)
static func build_road_check(game: Game, args: Dictionary) -> Dictionary  # {hex, direction, tag}; 4.10
static func build_road(game: Game, args: Dictionary) -> Dictionary        # a Work with action &"road"; pays; work_started
# season(): road works halt (either hex snow in winter), are lost (either hex), finish through Roads.set_road;
# cost_of(game, &"road", ...) reads Roads.cost_of; OWNS unchanged (works, next_work_id)

# core/systems/step_costs.gd  (M6, edit)
static func for_game(game: Game) -> StepCosts      # game.steps, made on first use from map, defs and state.road/crossing
func forget_hexes(indices: PackedInt32Array) -> void   # the two hexes of a built edge
# compute(map, defs, i, d, winter) gains (road, crossing) arguments read from the state by the game's table; of(map, defs)
# keeps the map's for tools and tests; Movement, Supply, Occupation's areas and retreats call for_game(game)

# core/systems/economy.gd  (M4 to M9, edit)
const ABROAD := -2
static func market_of(game: Game, tag: StringName) -> int          # 4.11
static func market_prices(game: Game, view: StateView, market: int, supply: PackedInt32Array) -> PackedInt32Array   # D16
static func sale_price(game: Game, hex: Vector2i, good: int, tag: StringName) -> int   # the price its goods sell at (4.6 step 3),
	# the previews' and worth's price

# core/systems/economy_season.gd  (M4 to M9, edit)
const OWNS: Array[String] = ["tax", "made_markets"]
# goods_step(): no sale; made_of() also returns by_market (market id -> PackedInt32Array); production writes made_markets;
# money_lines(): tax_goods from sales_milli (an argument: Country.sales_open in the phase, the preview's in the preview)

# core/systems/treasury.gd  (M4, M6, M9, edit): WHY appends &"tolls", &"trade", &"purchases" (17)
# core/systems/stores.gd  (M4, M6, edit): FLOWS appends &"bought" (9)
# core/systems/relations.gd  (M9, edit): memories trade, embargo, trade_cancelled; standing trade_partner, embargo (4.8)
# core/systems/peace.gd  (M9, edit): price() adds open_markets_price; make_peace_check's open-markets row; apply()'s step;
#   best_deal()'s step (4.8)
# core/systems/stats_system.gd  (M3 to M9, edit): the four series, income_trade, the price ring; then Trade.close(game)
# core/systems/vision.gd  (M6, edit): SIGHTED gains "road_built"
```

**OWNS after M10** (`tests/core/test_owns.gd` diffs `Snapshot.of` around every action and phase):

| Field | Written by | In an action | In a phase |
|---|---|---|---|
| `markets`, `routes` | `Trade` | no | `trade` |
| `tolls` | `Trade` | `set_tolls` | no |
| `sales_open` | `Trade` | no | `trade`, `stats` (`Trade.close`) |
| `made_markets` | `EconomySeason` | no | `production` |
| `merchant_orders`, `next_merchant_id` | `Merchants` | `send_merchant`, `recall_merchant`, `repick_merchants`, `declare_embargo` (frees) | `trade` |
| `pacts`, `next_pact_id` | `TradePacts` | `declare_embargo`, `lift_embargo`, `sign_trade_agreement`, `cancel_trade_agreement`, `make_peace`, `answer_offer` (open markets) | no |
| `road`, `crossing` | `Roads` | no | `works` |
| `works`, `next_work_id` | `Works` | `build_road` too | `works` |
| `stock`, `flows_open` | `Stores` | as M9 | `trade` too (sold, bought) |
| `treasury`, ledgers | `Treasury` | as M9; `build_road` | `trade` too (tolls, trade, purchases) |
| `relations` | `Relations` | `declare_embargo`, `sign_trade_agreement`, `cancel_trade_agreement` too | as M9 |
| `stats` | `StatsSystem` | no | `stats` (the price ring) |
| everything of M9's table | as M9 5.3 | | |
| `events`, `action_log`, `chronicle`, `version`, `view_cache`, `districts`, `sight`, `supplies`, `war_cache`, `diplo_cache`, `steps`, `trade_cache` | `Game` (`DOOR_FIELDS` gains `steps`, `trade_cache`) | yes | yes |

### 5.4 Game, the action table, the season, saves (`core/game/`)

```gdscript
# core/game/game.gd  (M1 to M9, edit)
const DOOR_FIELDS: Array[String] = ["events", "action_log", "chronicle", "version", "view_cache", "districts", "sight",
	"supplies", "war_cache", "diplo_cache", "steps", "trade_cache"]
func emit(event: Dictionary) -> void      # M9's, plus: road_built -> steps.forget_hexes(the two hexes), trade_cache.forget_all(),
	# supplies cleared; hex_changed of a settlement -> trade_cache.forget_all(); market_opened, market_closed ->
	# trade_cache.forget_all()
func dev_price(market: int, good: int, milli: int) -> bool   # logged {turn, action: "dev_price", args}; Trade's writer sets
	# Market.price (clamped to the bounds); false with no such market or good
# new_scenario: after Unrest.setup: Roads.setup, Trade.setup; Stats gains the markets (Stats.add_market)
# digest(): M9's string + "|" + each market's, route record's, order's and pact's digest_text() (id or key order) +
#   "|" + next_merchant_id + "," + next_pact_id

# core/game/actions.gd  (M3 to M9, edit)
const NAMES: Array[String] = ["build", "upgrade", "clear", "cancel_work", "choose_country", "set_tax", "raise", "march", "halt",
	"continue_march", "split_army", "merge_armies", "disband", "declare_war", "make_peace", "storm", "set_standing",
	"offer_peace", "answer_offer", "send_gift", "join_coalition", "send_merchant", "recall_merchant", "repick_merchants",
	"set_tolls", "declare_embargo", "lift_embargo", "sign_trade_agreement", "cancel_trade_agreement", "build_road"]
#   send_merchant {from, to, good, tag}   recall_merchant {order, tag}   repick_merchants {tag}   set_tolls {level, tag}
#   declare_embargo / lift_embargo / sign_trade_agreement / cancel_trade_agreement {target, tag}
#   build_road {hex, direction, tag}
# pair_of: the first three -> Merchants'; set_tolls -> Trade's; the four pacts -> TradePacts'; build_road -> Works'

# core/game/season.gd  (M3 to M9, edit)
const PHASES: Array[StringName] = [&"ai_orders", &"movement", &"battles", &"supply", &"sieges", &"war", &"relations",
	&"production", &"trade", &"income", &"works", &"people", &"stats", &"calendar", &"ready_units", &"vision"]
# run_phase(trade): Trade.season

# core/game/replay.gd  (M3 to M9, edit): plays dev_price records through Game.dev_price
# core/game/snapshot.gd  (M3 to M9, edit): the trade key; map-state/7, work/3, country/6, stats/2, peace-offer/2; restore
#   type-checks every new field, refuses country/5 and peace-offer/1, rebuilds steps (null) and trade_cache (empty)
# core/game/save_file.gd  (M3 to M9, edit): FORMAT := 8; OLDEST_FORMAT := 8
```

### 5.5 Events and Session (`shell/autoload/`)

```gdscript
# shell/autoload/events.gd  (edit): added signals
signal price_moved(market: int, good: int)
signal merchant_sent(tag: StringName, order: int)
signal merchant_recalled(tag: StringName, order: int)
signal merchant_freed(tag: StringName, order: int, why: StringName)
signal route_closed(a: int, b: int, why: StringName)
signal route_opened(a: int, b: int)
signal market_opened(market: int)
signal market_closed(market: int)
signal road_built(tag: StringName, hex: Vector2i, direction: int)
signal tolls_set(tag: StringName, level: int)
signal embargo_declared(tag: StringName, target: StringName)
signal embargo_lifted(tag: StringName, target: StringName)
signal trade_agreement_signed(tag: StringName, target: StringName)
signal trade_agreement_cancelled(tag: StringName, target: StringName)

# shell/autoload/session.gd  (edit): drain() sends the fourteen kinds to their signals, then chronicled (M3) for the notable;
#   last_phase_ms gains trade; dev_price(market, good, milli) -> bool (the console; drains)
```

### 5.6 Views (`core/views/`, pure)

```gdscript
# core/views/knowledge.gd  (M3 to M9, edit)
static func market_seen(game: Game, viewer: StringName, market: int) -> bool     # 4.14
static func prices_seen(game: Game, viewer: StringName, market: int) -> PackedInt32Array   # empty when not seen

# core/views/words.gd  (M3 to M9, edit)
static func price(milli: int) -> String              # "2.50"
static func price_change(from: int, to: int) -> String   # "1.10 → 1.30 (▲ +18 %)"
static func market(game: Game, id: int) -> String    # "Genoa"; "the market of (6, 13)" for an unnamed town
static func route(game: Game, key: Vector2i) -> String   # "Genoa – Milan" (the lower id first)
static func order_text(game: Game, order: MerchantOrder) -> String   # "wine from Genoa to Milan"
static func tolls_name(level: int) -> String         # "Low", "Normal", "High"
static func road_name(level: int) -> String          # "no road", "a track", "a road", "a highway"
static func crossing_name(code: int) -> String       # "", "a ford", "a wooden bridge", "a stone bridge", "a ferry", "a pass"
static func pact_text(game: Game, pact: TradePact, viewer: StringName) -> String   # "Trade agreement with Venice since Spring 1482"

# core/views/market_view.gd  (new): the market panel's model (6.4)
class_name MarketView extends RefCounted
static func of(game: Game, viewer: StringName, market: int) -> Dictionary
	# {id, name, hex, controller: {tag, name, arms}, yours: bool, seen: bool, status ("", "Shut: besieged", "Closed to you: war
	#  with the Duchy of Milan", "Closed to you: an embargo"), catchment: {hexes, yours, remote_text}, routes: [{key, other,
	#  state, state_text}], tolls: {level, level_text, last (ducats, yours only), options (yours: [{level, label, note}])},
	#  sell: [{good, name, icon, price, trend (-1, 0, 1), best: {market, name, price}, per_season, send: {verdict, args}}] (6 rows
	#  at most), buy: [the same from the cheapest], goods: [{good, name, icon, price, base, trend, spark (12 seasons), offered,
	#  wanted, in, out, bought}], merchants: {count, working, mine: [{order, text, history, flag, flag_text, recall: {verdict}}],
	#  idle_text, best: {}, repick: {verdict}, rivals: [{tag, name, good, from, to}]}, empty_text}
	# cached [&"market", version, viewer, market]

# core/views/trade_view.gd  (new): the order card and the route's card
class_name TradeView extends RefCounted
static func order_options(game: Game, viewer: StringName, market: int, good: int) -> Dictionary
	# {goods: [{good, name, best_per_season}] (the goods with a route from this market), good, sources: [{from, to, route,
	#  from_name, price_from, price_to, transport, tolls, per_load, up_to, per_season, stock_text ("6 on offer after the free
	#  traders last season · 3 made there"), rivals_text, verdict}] (best first), chosen (the best index)}
static func route_card(game: Game, viewer: StringName, key: Vector2i) -> Dictionary
	# {title ("Genoa – Milan"), way_text ("a highway, 4 points"), state_text, flows: [{text}] (last season, both directions),
	#  mine: [{order, buy, sell, margin, transport, tolls, net, history}], cost_text, capacity_text}

# core/views/road_preview.gd  (new): the road card (4.10)
class_name RoadPreview extends RefCounted
static func of(game: Game, tag: StringName, hex: Vector2i, direction: int) -> Dictionary
static func options_of(game: Game, tag: StringName, hex: Vector2i) -> Array[Dictionary]
	# the hex panel's road rows: each edge to land, {direction, to_hex, to_text, level_text, next_text, verdict, cost_text}
static func gain_year(game: Game, tag: StringName, edge: int, level_to: int) -> int   # D47

# core/views/trade_lines.gd  (new): the route lines of a chunk (6.3)
class_name TradeLines extends RefCounted
const MINE_WIDTH := 3.0
const BG_WIDTH: Array[float] = [1.0, 1.6, 2.4, 3.2, 4.0]   # by the last season's loads: 0, 1-5, 6-10, 11-20, 21+
const DASH := 8.0
const GAP := 5.0
static func for_chunk(game: Game, viewer: StringName, chunk: Vector2i, mine_only: bool) -> Array[Dictionary]
	# {kind (&"route_mine", &"route_bg", &"route_closed", &"route_winter"), points: PackedVector2Array (hex centres along the
	#  way, MapTiles.cell_centre), width, arrow: bool, key}
static func chunks_of(game: Game, key: Vector2i) -> Array[Vector2i]
static func route_at(game: Game, px: Vector2, tolerance: float = 6.0) -> Vector2i   # the nearest route within tolerance, or (-1, -1)
static func chips(game: Game, viewer: StringName) -> Array[Dictionary]   # [{key, at (the way's middle), text ("wine +9"), tone}]
static func badges(game: Game, viewer: StringName) -> Array[Dictionary]  # [{market, hex, text ("tolls +6"), yours}]

# core/views/study_trade.gd  (new): the Trade page (6.7)
class_name StudyTrade extends RefCounted
static func of(game: Game, viewer: StringName, span: int, good: int) -> Dictionary
	# {prices: [{good, name, icon, home, home_trend, spark, low: {market, name, price}, high: {...}, stock}], ring: {good,
	#  markets: [{id, name, series: PackedInt32Array}] (home, the cheapest and the dearest known), base, labels}, merchants:
	#  [{order, text, carried, history, total, flag_text}], totals: {tolls, merchants, purchases, sales}, tolls: [{market, name,
	#  last, routes, loads}], best: [{good, name, text}], worst: [...], pacts: [{text, kind}], empty texts}
	# cached [&"study_trade", version, viewer, span, good]

# core/views/cards_trade.gd  (new): hover cards
class_name TradeCards extends RefCounted
static func merchants_chip(game: Game, viewer: StringName) -> Dictionary   # {value "2/3", change, title, lines (each order and
	# its last season, the idle count), hint "E: the market"}
static func market_hover(game: Game, viewer: StringName, market: int) -> Dictionary
static func price_hover(game: Game, viewer: StringName, market: int, good: int) -> Dictionary   # the ring's last 4 and why

# core/views/map_modes.gd  (M2 to M9, edit): Mode gains TRADE (key 8); MODE_KEYS gains &"trade"; TRADE_ALPHA := 0.65;
#   TRADE_COLOURS (6.3); trade_bytes(game, viewer, lens) cached [&"trade", version, viewer, lens]; trade_ramp(lens);
#   legend(TRADE, lens), legend_title(TRADE, lens); modes(game) adds TRADE after RELATIONS in a game with countries;
#   relation_bytes gains 14 (an embargo between you) and 15 (a trade partner) with their colours
# core/views/hex_card.gd  (edit): "Market: sells at Genoa's (3 points)" / "Remote: sells at Genoa's at 70 %" / "A market town";
#   edge_summary(map, hex, kind, state := null) and crossing_summary(map, hex, state := null) read the state's roads and
#   crossings when given (the hover card's "highway (E), road (SW)", "stone bridge (E)" after a road work)
# core/views/country_card.gd  (M2 to M9, edit): trade: {tolls_text, pact: (&"partner", &"embargo_by_you", &"embargo_on_you", &""),
#   sign: {verdict}, cancel: {verdict}, embargo: {verdict}, lift: {verdict}, merchants_text (own)}
# core/views/economy_preview.gd, improve_preview.gd, study_economy.gd, peace_view.gd (open_markets row: {shown, price,
#   verdict, text}), study_diplomacy.gd (matrix states embargo, partner), season_summary.gd, log_lines.gd, reminders.gd
#   (edits): 4.11, 4.13, 4.18, 4.19
```

### 5.7 The AI (`core/ai/`, M8, M9, edits)

```gdscript
# core/ai/ai_know.gd  (edit): the door gains
static func markets_of(game: Game, tag: StringName) -> PackedInt32Array      # market ids it controls
static func home_market(game: Game, tag: StringName) -> int
static func merchant_options(game: Game, tag: StringName) -> Array[Dictionary]   # Merchants.options through Knowledge
static func orders_of(game: Game, tag: StringName) -> Array[Dictionary]      # its own: {order, route, from, good, estimate}
static func merchants_free(game: Game, tag: StringName) -> int
static func tolls_level(game: Game, tag: StringName) -> int
static func pacts_of(game: Game, tag: StringName) -> Array[Dictionary]       # public: {kind, other, by_us, bound}
static func route_partners(game: Game, tag: StringName) -> Array[StringName] # controllers at the far ends of its routes
static func road_candidates(game: Game, tag: StringName, count: int) -> Array[Dictionary]   # 4.16: {hex, direction, edge, prior}
static func road_card(game: Game, tag: StringName, hex: Vector2i, direction: int) -> Dictionary  # {verdict, blocked_by, payback,
	# ducats, goods}
# core/ai/ai_brief.gd  (edit): merchants, orders, tolls
# core/ai/ai_turn.gd  (edit): the trade step after works_act (4.16)
# core/ai/ai_economy.gd  (edit): works_scan's road candidates and their cards
# core/ai/ai_trade.gd  (new): AiTrade.trade(turn, game, brief, arg) (4.16)
```

---

## 6. The UI of M10

Built from the M1.5 kit and the M3 to M9 pieces. Colours and fonts from the Theme; HUD controls take no focus, screens do. The
App's milestone value becomes `"10"`, so the `since: "10"` rows of `Bindings.DEFAULTS` and `Settings.SCHEMA` register and show.
The layout follows `docs/design/ui/11_trade_map.png` and `12_market_panel_and_order.png` (the owner's decided proposals), re-drawn
in the Studiolo kit.

### 6.1 Keys and settings

| Action (`Bindings.DEFAULTS`) | Key (Mac) | Since | Who hears it | Does |
|---|---|---|---|---|
| `view_mode_8` (**new**, "Map mode 8", View) | 8 | 10 | `MapInput` -> `mode_requested(MapModes.Mode.TRADE)` | the Trade mode; M4.5's toasts in the sandbox and while picking |
| `game_market` (**new**, "Market panel", Game) | E | 10 | `MapInput.market_requested` (**new signal**) | the market panel of the selected hex's market, else your home market; "No market sells your goods." with none |

| `Settings.SCHEMA` key | Type (default) | Page, row | Since |
|---|---|---|---|
| `map/trade_routes` (**new**) | bool (false) | Map: "Trade routes on the map"; also the Layers popover's "Trade routes" switch | 10 |
| `state/map_mode` (edit) | choices gain `trade` | no row | 10 |
| `state/trade_lens` (**new**) | string (`markets`; or a good key) | no row: the Trade mode's lens | 10 |
| `state/trade_routes_mine` (**new**) | bool (false) | no row: the legend's Mine / All | 10 |

### 6.2 Bake slice 8: the trade pieces (`tools/ui_bake/pieces_m10.py`, new)

| Texture | Size (1x) | What |
|---|---|---|
| `icons_trade` (atlas, 24 px cells) | 240 x 48 | `market`, `merchant`, `route`, `tolls`, `embargo`, `partner`, `track`, `road`, `highway`, `ford`, `bridge`, `price_up`, `price_down`, `price_flat`, `idle`, `closed`, `remote`, `best`, `buy`, `sell` |

`build_theme.gd` adds them as `Kit` icons. `shell/ui/tokens.gd` gains `ROUTE_MINE_INK #e8c15a` (GOLD's value), `ROUTE_BG_INK #efe3c4`,
`ROUTE_CLOSED_INK #8a8173`, `ROUTE_LOSS_INK #f0806a` (BAD's value) (the bake re-runs: `tokens_sha`). The art director signs the
trade sheet (`bake_ui.py --sheet`): the 20 icons at 1x and 2x beside the diplomacy sheet.

### 6.3 The map: the Trade mode, the route lines, the marks (`shell/map/`, `shell/mapview/`)

**The Trade mode** (`MapModes.trade_bytes(game, viewer, lens)`, one byte a hex). The **Markets** lens:

| Byte | Meaning | Colour | Legend words |
|---|---|---|---|
| 0 | sea | none | |
| 1 to 6 | a hex of the catchment of a market of colour slot k (`TradeCache.colours`) | `TRADE_COLOURS[k]`: `#7a9e7e`, `#c49a5a`, `#6f86a8`, `#b5737a`, `#9a8cc0`, `#5fa39a` | "Sells at Genoa" (one line a market in view, the names) |
| 7 to 12 | the market town of slot k | the slot's colour lightened 25 % | "Market town" |
| 13 | remote land | the veil (M4.5's `VEIL`) with hatching | "Remote: sells at its owner's home market at 70 %" |
| 14 | your land whose market is closed to you | `#a8321a` with stripes | "Closed to you: war, embargo or siege" |

The **Prices** lens (`state/trade_lens` a good key): bytes 1 to 7 a catchment of a known market by its price in permille of base
(up to 500, 501 to 750, 751 to 950, 951 to 1,050, 1,051 to 1,300, 1,301 to 2,000, over 2,000), colours `#1f6f8b`, `#5f9fb0`,
`#a9cdd0`, `#efe3c4`, `#e3b27a`, `#c8664c`, `#8e2a17` (byte 7 striped); 8 a market you do not know (the veil); 9 remote (the hatch).
Legend words "Cheap: half or less of base" ... "Dear: over twice base". Bytes 1 to 14 at `TRADE_ALPHA` (0.65); colour distances
tested as M4.5's (neighbouring bytes at least 6 worst ΔE; stripes on 7 and 14; the veil against every other at least 15).
`ModeOverlay` gains the textures `trade` (R8) and `trade_ramp` (RGBA8 256 x 1), the uniform `trade_alpha`, `func update_trade(bytes:
PackedByteArray) -> int` (the texels that differ) and `trade_bytes()` (a copy, tests). The minimap shows it.

**The legend** (`ModeLegend`, M4.5, edit): the title "Trade: markets" or "Trade: the price of wine"; a `Segmented` **Markets |
Prices**; in Prices a grid of the 16 good icons as toggle `KitButton`s (the lens; writes `state/trade_lens`); the line kinds (gold:
your merchants; ivory: free trade, wider with more loads; grey dashed: closed; dotted: shut by snow); "1 merchant idle" with a
**Best order** button (the `merchant_idle` reminder's action) when one is idle; a `Segmented` **Mine | All** for the lines
(`state/trade_routes_mine`).

**The route lines** (z 81, `TileMapView` `Routes`: one `EdgeLineLayer` a chunk, kinds `route_mine` (a 3 px `ROUTE_MINE_INK`
stroke over a 5 px ink one, an arrow at the way's middle in the order's direction; `ROUTE_LOSS_INK` when its last season lost),
`route_bg` (`ROUTE_BG_INK`, 1 to 4 px by last season's loads, an arrow in the larger flow's direction), `route_closed` (dashed
`ROUTE_CLOSED_INK` with a cross at the middle), `route_winter` (dotted `ROUTE_CLOSED_INK`)): from `TradeLines.for_chunk`, drawn hex
centre to hex centre along each way; shown in the Trade mode always and in every other mode while `map/trade_routes` is on;
rebuilt on `season_ended`, `merchant_sent`, `merchant_recalled`, `merchant_freed`, `route_closed`, `route_opened`, `market_opened`,
`market_closed`, `road_built`, `embargo_declared`, `embargo_lifted`, `trade_agreement_signed`, `trade_agreement_cancelled`,
`game_started` for the chunks of the routes touched, sliced 5 ms a frame.

**The marks** (`shell/map/trade_marks.gd`, **new**, `TradeMarks extends Node2D`, z 87; in the Trade mode and with the route lines):
the `market` Kit icon on every market town; a toll badge ("tolls +6", a `Label` in the `Names` canvas layer) on each market of
yours that took tolls last season; a chip ("wine +9", red at a loss) at the middle of each of your orders' ways (`TradeLines.chips`);
the hover of a route line shows a `HoverCard` from `TradeView.route_card` (buy and sell prices, margin, transport, tolls, profit,
the last 4 seasons; "Click: the market"); a click on a route opens the market panel of its nearer end; **a right click on a route
line** opens the `HexMenu` (M6) with the route's items: "Recall: wine Genoa → Milan" (each order of yours on it), "New order on
Genoa – Milan…" (the order card limited to the route) (decision 7). `MapInput` asks `TradeLines.route_at` before the hex menu when
the lines are shown.

**Roads on the map:** `EdgeLines.for_chunk(map, state, chunk)` and `chunks_of_run` read `MapState.road`; `Crossings.of_hex` gains
`of_state(map, state, hex)` reading `MapState.crossing`; on `road_built` the map scene rebuilds the run's chunks and the two hexes'
crossing cells (a `set_cell` on each). The hover card's road and crossing lines (`HexCard.edge_summary`, `crossing_summary`, M1.5)
read the state, so they name a road the moment it stands.

| z | What | Node | Since |
|---|---|---|---|
| 80 | the overlay gains the Trade texture | `ModeOverlay` | M2, M10 |
| 81 | trade route lines | `TileMapView` `Routes` | M10 |
| 82 | castle-area lines | `TileMapView` `Areas` | M7 |
| 83 | the goal outline | `TileMapView` `Goals` | M9 |
| 87 | market icons, toll badges, route chips | `TradeMarks` | M10 |

```gdscript
# shell/mapview/tile_map_view.gd  (M1 to M9, edit): ROUTES_Z := 81; set_chunk_routes(chunk, lines), route_chunks()
# shell/mapview/edge_line_layer.gd  (M1 to M9, edit): kinds "route_mine", "route_bg", "route_closed", "route_winter"
# shell/map/map_scene.gd  (M1 to M9, edit)
func refresh_routes(keys: Array[Vector2i] = []) -> void   # [] all
func set_trade_lens(lens: StringName) -> void
signal route_clicked(key: Vector2i)
signal route_menu_requested(key: Vector2i, screen_pos: Vector2)
class_name TradeMarks extends Node2D                       # shell/map/trade_marks.gd
func setup(view: TileMapView) -> void
func refresh() -> void
```

### 6.4 The market panel (`shell/panels/market_panel.tscn/.gd`, new; in the dock)

```gdscript
class_name MarketPanel extends PanelContainer   # a PanelFrame with a Cartouche "Genoa market"
func show_market(market: int) -> void           # MarketView.of(Session.game, Session.player_tag(), market)
func show_tab(tab: StringName) -> void          # &"opportunities", &"goods", &"merchants"
```

| Part | Content (from `MarketView.of`) |
|---|---|
| Head | the controller's `CountryArms` and the name; "Yours · 23 districts sell here · 4 routes · tolls +6 last season" (or "The Duchy of Milan's · ..."); the status line in `BAD` when shut or closed to you |
| Tabs (`Segmented`) | **Opportunities**, **All goods**, **Merchants 2/3** |
| Opportunities | "Sell from Genoa": a `StudyTable` (Good with its icon, Here with its trend arrow, Best market (name and price), A season (the delivered estimate, `DeltaChip`), a `button` cell "Send" with its verdict); "Buy for Genoa": the same from the cheapest; six rows each at most; a row's Send opens the order card on that good and route |
| All goods | a `StudyTable`: Good, Price, ▲▼, a `spark` cell (12 seasons of the ring), On offer, Wanted, In, Out, Bought, Base; an unknown market shows "Prices here are not known to you." |
| Merchants | your orders touching this market: a row each ("Wine: Genoa → Milan", the last 4 seasons as a `spark` of the net, "idle 2" or "at a loss" flag chips, **Recall** with its verdict); **Re-pick best** (`set_verdict(Session.check("repick_merchants", {}))`); the idle hint "1 merchant idle: best is wine Genoa → Milan +9" with **Send**; "Competition here": others' orders on its routes ("The Duchy of Milan: salt Genoa → Milan") |
| Tolls (your market only) | a `Segmented` **Low · Normal · High** (`Session.act("set_tolls", {level})`) and its `Hint` ("High: tolls 15 %, routes carry a quarter less") |
| Foot | **Show the routes** (the Trade mode, the camera glides to the market), **Look there** |

Opened from E, the hex panel's **Open the market**, the Merchants chip (your home market), a click on a route line or a toll badge, the
Trade page's rows, the report's price and order lines, the task flag's `merchant_flagged`. Refreshes on `season_ended`, the merchant
signals, `route_closed`, `route_opened`, `tolls_set`, `price_moved`, the pact signals and a newer `game.version`. Esc closes it (the
ladder's panel step, as the country panel).

### 6.5 The order card (`shell/screens/merchant_order.tscn/.gd`, new; `OVERLAY`, 420 px, left)

```gdscript
class_name MerchantOrderCard extends Screen     # kind OVERLAY; a PanelFrame with the cartouche "New order: wine"
func show_order(market: int, good: int = -1, route: Vector2i = Vector2i(-1, -1)) -> void   # TradeView.order_options
func set_good(good: int) -> void
func set_source(index: int) -> void
```

| Step | Content (from `TradeView.order_options`) |
|---|---|
| 1 Good | a `NavList` of the goods with a route from this market, each with its best "+9 a season" (a good with none greyed) |
| 2 From where | a `StudyTable`: Source (market), Price there, Transport, Tolls, A load, Up to, A season; the best row chosen; a row's hover: "6 on offer after the free traders last season · 3 made there · 1 rival order takes 4 first" |
| 3 Send | **Send merchant: +9 a season** (`ButtonPrimary`, `set_verdict(Session.check("send_merchant", args))`; "at a loss" in `BAD` when the margin is under 0) |

Keys: Up and Down move the rows; Enter sends; Esc closes. The card closes after Send with the toast of 6.9.

### 6.6 The road card and the hex panel's roads (M4's `WorksPreview` and `PreviewCard`, M3 to M9's hex panel; edits)

`PreviewCard.show_road(p: Dictionary) -> void` (**new**) draws `RoadPreview.of`: Title and Sub ("Road from (7, 10) to (7, 11)";
"none → a track, with a ford across the river"); **Brings**: "Step, summer 8 (a wade) → 2", "Step, winter ...", a line a route
("Turin – Genoa: 17 → 11 points · 405 → 315 a load · capacity 8"), "Markets: (7, 11) joins Genoa's" when the catchment changes;
**Cost and time** with ticks ("20 ducats · 2 seasons · ready Autumn 1480"; "✓ both sides your land", "✓ a free work slot: 0 of 2
in use", "✓ 20 of 1,500 ducats"); **Gain**: "about +n a year at last season's trade" and the payback ("Pays back in ...", "Its worth
shows in marches and supply" when 0); the refusal bar; **Begin the work**. `WorksPreview.show_road(hex, direction)` pushes it; Enter
begins (`build_road`). Map marks: the edge in gold and the routes' ways (`PreviewMarks`, M4, gains `show_road_marks(p: Dictionary)
-> void`: a 3 px `ROUTE_MINE_INK` stroke on the edge and the ways' centre lines, with no `set_cell`).

**The hex panel** (`shell/panels/hex_panel.tscn/.gd`) gains, for a hex of yours, a **Roads** section: one row per edge to land
(`RoadPreview.options_of`): "To (7, 11), SE: no road → a track and a ford · 20 · 2 seasons" (a `KitButton` with its verdict and an
`(i)` that opens the road card); a road work under way shows its ready date. Refreshes on `road_built` and the work signals.

### 6.7 The Trade page (`shell/screens/study/page_trade.tscn/.gd`, new)

The study's nav after M10: Economy, **Trade**, Diplomacy, Military, People, Rankings, History (`StudyPages.LIST`, since "10").
`PageTrade extends StudyPage`, from `StudyTrade.of(game, you, span, good)`:

| Part | Built from | Reads |
|---|---|---|
| Prices | `SectionHead` "Prices"; a `StudyTable`: Good (icon), At home (price), ▲▼ (a `delta` cell against last season), a `spark` cell (the span), Cheapest known (market, price), Dearest known (market, price), In store; selecting a row sets the ring's good | `prices` |
| The price ring | an `InkChart` `LINE` on a `PanelVellumInset`: the selected good's price at your home market, the cheapest and the dearest market you know, with the base as a dashed line; caption "Wine: the price in three markets, the last 40 seasons"; the span `Segmented` "12 seasons \| 40 seasons" (`state/study_span`) | `ring` |
| Your merchants | a `StudyTable`: Order, Carried last season, Last 4 seasons (a `spark` of the net), Total, Flag; **Re-pick best** | `merchants` |
| Tolls and trade | a `StudyTable` of your markets: Market, Tolls last season, Routes, Loads through; under it "Tolls +6 · Merchants +9 · Goods bought −9 · Goods sold 52" | `tolls`, `totals` |
| Best and worst goods | two short lists: "Best to sell: wine at Milan, +1.30 a load over Genoa"; "Dearest to buy: salt at Genoa, 2.10" | `best`, `worst` |
| Agreements and embargoes | a line each, with the country's link | `pacts` |

"Show on map" switches to the Trade mode with the selected good's Prices lens. Empty states: "No season of trade has passed yet.",
"You have no merchant on the roads.", "You keep no pact." A row's Enter opens that market's panel.

### 6.8 The hex panel, the hover card, the country panel, the peace screen, the Relations mode (edits)

- **Hex panel**: under the Owner row, the market line from `HexCard` ("Sells at Genoa's market, 3 points away" / "Remote: sells at
  Genoa's at 70 %" / on a market town "Genoa market" with **Open the market**); the Roads section of 6.6.
- **Hover card** (`shell/hud/map_hover.gd`): the market's name after the region; in the Prices lens "Wine at Genoa: 2.50".
- **Country panel** (`shell/panels/country_panel.tscn/.gd`): a **Trade** section from `CountryCard.of`: another country: "Their tolls
  Normal · a trade partner" (or "your embargo on them" / "their embargo on you"); **Sign a trade agreement** (its verdict),
  **Cancel the agreement**, **Declare an embargo** (danger; its verdict), **Lift the embargo**; your own: "Tolls: Normal" with a
  `Segmented` to set it, "Merchants 2 of 3 working", your pacts as links. Refreshes on the pact signals and `tolls_set`.
- **Peace screen** (`shell/screens/peace.gd`, M9): the right column gains a `KitSwitch` row "Open their markets: they lift any
  embargo and trade with you on agreement terms for 20 seasons (5 points)" with its verdict; the total and the answer line update.
- **Relations mode** (M9 6.3): bytes 14 "An embargo between you" (`#6b5b8a` with cross-hatching) and 15 "A trade partner"
  (`#3f8f9f`), placed after the league in the priority (war, truce, league, embargo, partner, then opinion).
- **`RelationMatrix`** (`shell/ui/relation_matrix.gd`, M1.5, M9): states `embargo` ("Embargo", icon `embargo`) and `partner`
  ("Partner", icon `partner`), after `league` in the priority.

### 6.9 The report, the task flag, notifications, the log, ribbons, toasts, chips

- **The report screen** (`shell/screens/season_report.gd`): draws the `trade` section (the nav gains "Trade" with its count); price
  and order lines open the market panel; event lines look at the hex.
- **Task flag and notifications** (M3): the rules of 4.19 (the `send_merchant` action sends `ctx.request(&"send_merchant", args)`);
  notifications as 4.13's `notify`.
- **The log** (`shell/hud/action_log.gd`): the lines of 4.13; a route line opens the market panel.
- **Ribbons**: "Track", "Road", "Highway" on both hexes of a built edge.
- **Toasts**:

| When | Text |
|---|---|
| A merchant sent | "A merchant carries wine from Genoa to Milan: about +9 a season." |
| Recalled | "Your merchant with wine from Genoa to Milan comes home." |
| Re-picked | "Re-picked: 2 merchants on their best orders." |
| Tolls set | "Tolls set to High from the next season." |
| An embargo declared, lifted | "Embargo on the Duchy of Milan: no trade between your markets but grain." / "Embargo on the Duchy of Milan lifted." |
| An agreement signed, cancelled | "Trade agreement with the Republic of Venice: Low tolls and more on the roads." / "Trade agreement cancelled." |
| E with no market | "No market sells your goods." |
| The Trade mode in the sandbox | "no countries on this map" |
| A refusal | its reason |

- **Chips** (`shell/hud/chips.tscn/.gd`, M4 to M9, edit): a **Merchants** `ResourceChip` (icon `merchant`, "2/3": working of all,
  its change) after Stores; its hover `TradeCards.merchants_chip`; a click opens the market panel of your home market. Narrowing:
  it hides before Stores. `ResourceChip` gains `set_fraction(value: int, of: int, change: int) -> void` (**new**).

### 6.10 The App, F3, the console, the Layers popover

| Request or event | The App (`shell/app/game_requests.gd`, `app.gd`) |
|---|---|
| `MapInput.market_requested`, `app_requested(&"market", {market})`, `MapScene.route_clicked` | show `MarketPanel` in the dock at that market (E: the selected hex's, else home) |
| `app_requested(&"order", {market, good, route})` | push `MerchantOrderCard` (`ScreenIds` `merchant_order`, **new**) |
| `app_requested(&"send_merchant", {from, to, good})`, `(&"recall", {order})`, `(&"repick")`, `(&"tolls", {level})`, `(&"embargo" \| &"lift" \| &"sign" \| &"cancel_pact", {target})`, `(&"build_road", {hex, direction})` | `Session.act` the action; the toast of 6.9 or the refusal |
| `app_requested(&"road_card", {hex, direction})` | `WorksPreview.show_road` |
| `MapScene.route_menu_requested(key, pos)` | the `HexMenu` (M6) with the route's items |
| `Events.season_ended` | `StudyWarm` adds `StudyTrade.of`, `MarketView.of(home)` and, in the Trade mode, `MapModes.trade_bytes` |

- **F3** (`shell/hud/debug_overlay.gd`): "trade 1.2 ms · markets 14 · routes 22 (2 shut) · orders 7 · cache 9 ms cold".
- **Console** (`shell/hud/dev_commands.gd`): `market NAME` (prints its prices and last season), `routes` (each route's state, cost,
  capacity, last loads), `price NAME GOOD N` (`Game.dev_price`, N thousandths), `send FROM TO GOOD`, `recall ID`, `repick`,
  `tolls low|normal|high`, `embargo TAG`, `lift TAG`, `pact TAG` (sign), `unpact TAG` (cancel), `road C R D` (`build_road`), each with
  M6's `as TAG`; problems "no market NAME", "no such good", "no such number", "no order ID", each a planted fault in its test.
- **The Layers popover** (`shell/hud/layers_popover.tscn/.gd`): a "Trade routes" `KitSwitch` on `map/trade_routes`; hidden in the
  sandbox.
- The App sets the milestone `"10"`. `screen_ids.gd` gains `merchant_order`.

---

## 7. Data and the editor

| File | Holds | Made by | Checked by |
|---|---|---|---|
| `godot/data/defs/trade.tres` (**new**) | `TradeDef` (5.1, the values of 4.2 to 4.10) | by hand in the inspector (task X1) | `tests/core/test_trade_defs.gd`: loads, validates, equals 4.4 to 4.10 and 5.1 |
| `godot/data/defs/goods/*.tres` (M4, edit) | `appetite_milli`, `war_open` (4.5) | by hand (X1); tuned by X31 | `tests/core/test_good_defs.gd` |
| `godot/data/defs/diplomacy.tres` (M9, edit) | the six trade numbers (5.1) | by hand (X1) | `tests/core/test_diplomacy_defs.gd` |
| `godot/data/defs/game_defs.tres` (edit) | `trade` (external) | by hand (X1) | `GameDefs.validate()` in `test_economy_defs.gd` |
| `godot/data/defs/ai.tres`, `tempers/*.tres` (M8, M9, edit) | 4.16's fields | by hand (X22); tuned by X31 | `tests/core/test_ai_defs.gd` |
| `godot/tools/trade_tables.gd` (**new**, headless) | prints 4.5's curve and appetites, 4.7's merchant rule, 4.8's tolls and 4.10's road costs as Markdown from the files | X1 | `test_trade_defs.gd` runs it and compares one row of each |
| `godot/tools/trade_report.gd` (**new**, headless) | 4.5's calibration report and the soak's trade columns for 40 seasons of seeds 1480 to 1484 | X29 | `test_trade_report.gd` runs it on 4 seasons of one seed and parses the table |
| `godot/tools/ai_tables.gd` (M8, edit) | the three new temperament rows and the five `AiDef` rows | X22 | `test_ai_defs.gd` |
| `godot/assets/ui/kit/` (slice 8) | `icons_trade` at 1x and 2x | `tools/bake_ui.py` (X3) | `bake_ui.py --check`, `build_theme.gd --check` in CI |
| `godot/data/README.md` (edit) | `trade.tres`, the goods' new fields | X1 | |

No map data changes: markets come from the map's places and the scenario's capitals by a rule, the living roads start from the map's
roads; `build_map --check` and `build_scenario.gd --check` stay as they are. `core/mapgen/fake_map.gd` (M1) is unchanged: its
places (4 % at level 4) and `FakeScenario`'s capitals give the made-up Europe about 170 markets. The scenario editor (M2) is
unchanged: markets are never painted.

---

## 8. Speed

`godot/tools/perf_core.gd` (M3 to M9) on the made-up Europe: `PerfFixture.europe_trade(seasons)` (**new**, in
`godot/tools/perf_fixture.gd`): M9's `europe_diplomacy` with every country's merchants sent on its best options, 10 embargoes, 20
agreements and 200 road works begun at season 2; `seasons` seasons through `Season.run`. Rows in `godot/tests/perf_core_budget.json`,
nightly, never in GUT:

| Row | Limit | What |
|---|---|---|
| `season_ms` | **430** (M9: 400) | the fifteen phases other than `ai_orders`, worst of 8 seasons |
| `trade_ms` | 25 | the trade phase: about 170 markets, 400 routes, 360 orders, 16 goods |
| `trade_cache_cold_ms` | 150 | catchments, ways and colours from cold (a load, a built road) |
| `production_ms` | 60 (M4) | unchanged with `made_markets` |
| `market_view_ms` | 4 | one `MarketView.of`, uncached |
| `trade_options_ms` | 3 | `Merchants.options` for the largest country |
| `study_trade_ms` | 8 | `StudyTrade.of`, uncached |
| `trade_bytes_ms` | 20 | `MapModes.trade_bytes`, cold |
| `trade_lines_ms` | 8 | `TradeLines.for_chunk`, the worst chunk |
| `road_card_ms` | 2 | one `RoadPreview.of` (its ways re-found on a what-if) |
| `ai_season_ms` | 3,000 mean (M8) | with the trade step and road candidates |
| `save_mb` | 8 (M3) | with the trade key and the living roads |

On north Italy the trade phase is under 2 ms and the cache from cold under 15 ms (`test_trade_cache.gd` prints both, asserts
nothing on time). `godot/tools/ui/perf_ui.gd` gains in `perf_ui_budget.json`: `market_panel_ms` 16 (Genoa's, cold),
`order_card_ms` 16, `trade_mode_ms` 16 (the mode switched in), `trade_page_ms` 16, `route_lines_ms` 8 (every route of north
Italy drawn).

**How it stays in budget.** The catchment search is bounded by `market_reach` (12 points) and runs only when the cache is dropped
(a built road, a level change, a market change); the ways are searched inside two catchments each; the phase walks markets, routes
and orders, never hexes (the made goods come split by market from production's own loop). If `trade_cache_cold_ms` fails, the
fallback is to rebuild only the catchments within 12 points of a built road's hexes and the routes touching them (M).

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (P).

| File | Cases |
|---|---|
| `tests/core/trade_fixture.gd` (**new**) | `TradeFixture.still(defs)` (4.11); `duo(defs)`, `chain(defs)` (4.15 a to c); `flat(game)` (holds a country's offers equal season to season through `Game.dev_goods`); `italy(defs, tag)` (seed 1480, calm) |
| `tests/core/test_trade_defs.gd` (**new**); `test_good_defs.gd`, `test_diplomacy_defs.gd`, `test_economy_defs.gd` (edits) | the files load, validate, equal 4.4 to 4.10 and 5.1; `trade_tables.gd`'s rows; `curve` at every point and between (toward zero); P: a curve out of order, a floor over 1,000, a cap under 1,000, `merchants_base` over `merchants_max`, an unknown good in `buy_order`, a road table of 3, an appetite of −1 |
| `tests/core/test_trade_state.gd` (**new**); `test_country_state.gd`, `test_stats.gd`, `test_map_state.gd`, `test_diplomacy_state.gd` (edits) | `Market`, `RouteRecord`, `MerchantOrder`, `TradePact` round trips; `country/6`, `map-state/7`, `work/3`, `stats/2`, `peace-offer/2`; `digest_text` moves with every field; the price ring's slots and `price_series`; P: a market's price array of 15, a string for `bound_until`, country/5 and peace-offer/1 refused, a ring of the wrong size |
| `tests/core/test_roads.gd` (**new**); `test_step_costs.gd`, `test_edge_lines.gd`, `test_crossings.gd` (edits) | `Roads.setup` equals the map; `edge_of` normalises every direction; `road_check` rows (P each); `cost_of` (pass doubled, bridges by class); `crossing_for` never lowers; `set_road` writes both, emits `road_built`, and `game.steps` forgets only the two hexes (P: a forget of the whole table is caught by a fill counter); `for_game` equals `compute` on every edge after 200 random road levels; the edge lines and crossings read the state |
| `tests/core/test_trade_map.gd` (**new**) | **done-when 3**: 4.2's markets and the dropped three, 4.3's catchments (hexes, people, owners, the 91 remote), 4.4's 22 routes (points, road, capacity, cost, winter) and the three missing, 4.3's homes; a market opening when a fixture walls Savona and closing when it falls (P: a market beside a larger one is caught) |
| `tests/core/test_trade_cache.gd` (**new**) | the catchment's ties (cost, level, index); remote beyond 12; a wade at 8; blocked and closed steps; ways inside two catchments only; `colours` gives neighbours different slots; `forget_all` on a road, a level and a market change, nothing else (P: a cache that forgets nothing after a road is caught); cold times printed |
| `tests/core/test_trade_prices.gd` (**new**) | `next_price` for every curve segment, the smoothing toward zero, the bounds; supply and demand from the record; **done-when 1**'s duo prices (its poor-harvest case is in `test_trade_italy.gd`); `price_moved` above 150 permille only (P: a 149 change emits none); `price_after` |
| `tests/core/test_trade_duo.gd` (**new**) | **done-when 2** and 4.15 (a), (b): every number of the two tables; the tolls lines at the towns' hexes; the embargo's exact difference |
| `tests/core/test_trade.gd` (**new**) | every step of 4.6 on fixtures: offers split by `made_markets` with the remainder home; remote at 700; a closed market sends goods home; abroad at base × 700; bids in `buy_order` within the budget, filled pro rata with the remainder by id; free traders' order, spare and want; capacity with tolls and agreements; consumed; the money lines and counts; the records (P: a route walked out of key order is caught by a twin fixture) |
| `tests/core/test_merchants.gd` (**new**) | **done-when 4**: `count` (4.7's table on seed 1480); `may_work` (land in a catchment; trade rights); `estimate` (exact margin, `up_to` with older rivals); `send_merchant_check` every row (P each); recall and repick rows (P each); T1 on the chain; the 200 duo cases; flags at 2, home at 4; home after two losses; suspended seasons count nothing; freed on war, embargo, a gone route; the reminder's Send |
| `tests/core/test_trade_pacts.gd` (**new**); `test_relations.gd` (M9, edit) | every row of the four checks (P each); the memories and standing terms; an embargo cancels an agreement and frees both sides' orders; agreements' capacity, Low tolls and trade rights; a binding peace refuses the bound side's embargo and cancel until its date; P: an agreement with the player as target sent by an AI is refused |
| `tests/core/test_trade_war.gd` (**new**) | 4.9's table row by row: war closes all but grain; embargo the same; blockade closes all; a besieged town shuts (prices held, no offers or bids); an occupied market's tolls to the occupier; Savoy's declaration on Milan (4.9's worked line); `route_closed` and `route_opened` on change only (P: an open route emitting `route_opened` every season is caught) |
| `tests/core/test_road_works.gd` (**new**); `test_works.gd` (M3 to M9, edit) | `build_road_check` every row (P each); paying and the refund; halting in snow; lost when a side changes hands; finishing sets the road; **done-when 5** (4.15 e) |
| `tests/core/test_peace_open_markets.gd` (**new**); `test_peace.gd`, `test_peace_view.gd` (M9, edits) | the deal row's price; its check row (P); `apply`'s step (an embargo lifted, a bound agreement); the best deal's step; the view's row |
| `tests/core/test_trade_preview.gd` (**new**); `test_economy_preview.gd`, `test_improve_preview.gd`, `test_economy_season.gd`, `test_economy.gd` (edits) | 200 seeded cases with trade on: the first previewed season's offers, sales value, taxes on goods, bought loads and purchases equal the season's when no other country bids at the home market (at least 150 of 200 cases qualify; P: a preview at next season's prices is caught); the card's price line; `market_of`, `market_prices`, `sale_price`; every M4 to M9 preview test green on `TradeFixture.still` |
| `tests/core/test_trade_property.gd` (**new**) | **done-when 7**: 40 seasons, the random player for every country, weather drawn: every identity of done-when 7 every season |
| `tests/core/test_trade_saves.gd` (**new**) | **done-when 9**: save, load, save byte-equal with markets, the ring, records, orders, pacts and roads; ten seasons after a load equal ten without; `FORMAT` 8 (P: a format-7 header reads `older`; a string for a market's price) |
| `tests/core/test_trade_italy.gd` (**new**) | 4.15 (d): the first two years as Genoa, the price recomputation each season, the poor-harvest case (done-when 1), the tolls and the embargo (done-when 2) |
| `tests/core/test_market_view.gd`, `test_trade_view.gd`, `test_road_preview.gd`, `test_trade_lines.gd`, `test_study_trade.gd`, `test_cards_trade.gd` (**new**) | every part of 6.4, 6.5, 6.6, 6.7 as data; the card's verdict equals the check's (P: a view that disagrees with the check is caught); lines on every way and none elsewhere; `route_at` within 6 px; the fog: an unknown market's prices empty (P: a number shown is caught) |
| `tests/core/test_season.gd`, `test_chronicle.gd`, `test_vision.gd` (`road_built` sighted), `test_game_core.gd`, `test_replay.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_owns.gd`, `test_forty_seasons.gd`, `test_money_property.gd`, `test_check_contract.gd`, `test_insights_views.gd` (edits) | **`PHASES` is the sixteen of 4.12** (the pin); forty notable kinds; thirty actions; seventeen `WHY` reasons; nine flows; fifty-eight series; the dev record replays (P: a changed price gives another digest); 5.3's OWNS table (P: a test-only phase writing `price` directly is reported); `DOOR_FIELDS` |
| `tests/core/random_player.gd` (M6 to M9, edit) | the nine new actions with random markets, goods, levels, targets and edges |
| `tests/core/test_knowledge.gd`, `test_words.gd`, `test_hex_card.gd`, `test_country_card.gd`, `test_map_modes.gd`, `test_log_lines.gd`, `test_season_summary.gd`, `test_reminders.gd`, `test_study_economy.gd`, `test_study_diplomacy.gd` (edits) | `market_seen`, `prices_seen`; the words; the market line and the road and crossing lines from the state; the card's trade states; `trade_bytes` per byte in both lenses (both palettes' distances) and relation bytes 14, 15; the sentences of 4.13; the Trade section, the chip and the price lines equal after a save and load; every rule of 4.19 (P: a flagged order at idle 1 makes no line); the history series of 4.11; the matrix states |
| `tests/core/test_ai_trade.gd` (**new**); `test_ai_defs.gd`, `test_ai_know.gd`, `test_ai_door.gd`, `test_ai_economy.gd`, `test_ai_turn.gd`, `test_ai_fog.gd`, `test_ai_play.gd` (M8, M9, edits) | 4.16's tables; the tolls rule; re-pick with its hysteresis; pacts on the think turn only (P: a pact on another turn is caught); road candidates and their cards; the step order; the door's new tokens (P: `Merchants.` in a step module is reported); the fog with unknown markets' prices and others' sales changed; every country still plays |
| `tests/core/invariants.gd`, `test_invariants.gd`, `test_ai_soak_quick.gd` (M8, M9, edits) | the five invariants of 4.17, each with a planted break (a price of 3,501 permille by `dev_price` past its clamp in a test-only path, a market that lost a load, an order of a dead country, a road on a crest, an agreement and an embargo on one pair) |
| `tests/core/test_trade_report.gd` (**new**) | `trade_report.gd` on 4 seasons of seed 1480: the table parses; its medians equal the same medians computed in the test |
| `tests/shell/test_session.gd` (edit) | the fourteen signals drained after their phases, then `chronicled` for the notable |
| `tests/shell/test_market_panel.gd`, `test_merchant_order.gd`, `test_page_trade.gd`, `test_trade_marks.gd` (**new**); `test_hex_panel.gd`, `test_country_panel.gd`, `test_peace_screen.gd`, `test_relation_matrix.gd`, `test_preview_card.gd`, `test_works_preview.gd`, `test_preview_marks.gd`, `test_season_report.gd`, `test_chips.gd`, `test_resource_chip.gd`, `test_mode_overlay.gd`, `test_map_scene.gd`, `test_layer_stack.gd`, `test_map_input.gd`, `test_hex_menu.gd`, `test_bindings.gd`, `test_settings.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_task_flag.gd`, `test_notifications.gd`, `test_action_log.gd`, `test_study.gd`, `test_app_flow.gd` (edits) | every part and tab of 6.4 from `MarketView` fixtures (Send opens the card; tolls act); the card's steps, keys and verdict; the page's parts and empty states; the marks, badges, chips and the route hover; the hex panel's market line and roads; the country panel's trade section; the peace screen's row; the matrix states; the road card; the report's section; the Merchants chip and `set_fraction`; the Trade texture writes only changed texels (P: one byte, one texel); z 81 and 87; 8 and E (P: E with no market toasts); a right click on a route opens its menu; `map/trade_routes` and `state/trade_lens` (P: a bad lens falls back to markets); the console commands and their planted faults; the F3 line; end to end: New game as Genoa, End season twice, 8 (the Trade mode), E (Genoa's market), Send from the idle hint, the order card, Send, End season, the report's Trade section, the chip; `embargo MLO`; Savoy's `road 7 10 5` |
| `tests/shell/test_ui_monkey.gd` (edit) | adds 8, E, clicks in the market panel, the card and the Trade page; invariants: the digest changes only after an accepted action or a season; the market panel and the card never change the digest without an act |
| Python `tests/test_bake_ui.py` (edit) | slice 8's atlas at both scales; the catalogue; the asserts of style spec 4.4 |
| `godot/tools/map/probe_mode_overlay.gd` (M2 to M9, edit; windowed, CI under xvfb) | the Trade texture in both lenses: the pixel at every hex middle equals `colour_at` (tolerance 3); P: `--plant` swaps a byte and prints FAIL |
| Pictures (`godot/tools/ui/shot_ui.gd`, edit) | the Trade mode in both lenses with the route lines, the market panel's three tabs, the order card, the road card, the Trade page, the hex panel's roads, the country panel's trade, the report's Trade section, against `11_trade_map.png` and `12_market_panel_and_order.png`; at 1280 x 720 scale 1 and 2560 x 1440 scale 2; signed by the art director, then goldens `godot/tests/goldens/m10_*.png` (0.5 %) |

**Determinism:** `test_replay`, `test_forty_seasons`, `test_trade_property`, `test_check_contract`, `test_ai_determinism` (M8): M10's
rules draw no luck, walk every list in id, key or hex-index order, and sum integers. **Save round trip:** `test_snapshot`,
`test_save_file`, `test_trade_saves`, `test_season_summary` (J after a load: the Trade section equal).

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| The appetites are far off and most markets sit at the floor or the cap | `trade_report.gd`'s medians in X29; X31 applies 4.5's rule | Data only (appetites); a wider curve (data) |
| Prices swing every season and the player stops trusting the card (the note's "noise") | the soak's "median seasonal change" range (X29) and the playtest step 5 | `price_smooth_permille` 350 (data) |
| Tolls dominate again (F6) | the soak's trade-share range and the per-country tolls column, read by Opus in X31 | T4's change (Normal 60, data), the owner's call then |
| Free traders flatten every gap so merchants earn nothing | the soak's "order-seasons that carried nothing" and merchants' net columns | `spare_permille` 800 or `route_capacity_base` 4 (data) |
| Buying drains treasuries (AI debt before M12) | the soak's treasury range (M8) and a purchases column | `buy_budget_permille` 150 (data) |
| The catchments look wrong on the map (a town sells over a ridge) | X6's picture of the Markets lens for Opus and the art director | `market_reach` 10 or 14 (data) |
| The way inside two catchments misses a real road that runs through a third | `test_trade_map.gd`'s three missing routes, read in X6's pull request | allow the way over a third catchment (S) |
| Remote hexes lose too much (the Alps' timber) | the per-country sales column | `remote_permille` 800 (data) |
| The trade cache too slow on Europe | `trade_cache_cold_ms` in X6's scratch run | section 8's fallback |
| Pop-up noise (route closures, price lines) | the playtest; closures are events only for war, embargo, blockade and siege; price lines only for your stake | fewer price lines (2) |
| The AI builds no roads (low estimates) or too many | the soak's road works range | `road_scan_edges` 4 or 16, a road priority (data) |
| M4 to M9's pins move by accident | every earlier test runs on `TradeFixture.still` (X10) | none needed |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 5.3: row 7 reads "Production (`production`), then trade and prices (`trade`)" (M4, M10); 9.2: the intro names M2 to M10, an M10 row pointing at this spec and its plan, "specified and planned, waits for the owner's go; starts after M9 closes", the last row M11 to M12 |
| `docs/architecture/m4-build-spec.md` | 12, row M10: taken up in `m10-build-spec.md` (markets at towns, `market_prices`'s body, the trade phase's sales and purchases, `map-state/7` road works, the card's price line, `Treasury.WHY` `tolls`, `trade`, `purchases`; M4's pins run on `TradeFixture.still`) |
| `docs/architecture/m5-build-spec.md` | 12, row M10: taken up (the reserve bought at the home market; the food need in each market's appetite; grain and fish priced by supply) |
| `docs/architecture/m6-build-spec.md` | 12, row M10: taken up (`StepCosts.for_game` on `game.steps`; road works; armies fed from stores the market refills) |
| `docs/architecture/m7-build-spec.md` | 12, row M10: taken up (retreats and areas follow `game.steps`; a besieged market shuts, so no market feeds a besieged town) |
| `docs/architecture/m8-build-spec.md` | 12, row M10: taken up in `m10-build-spec.md` 4.16 (the trade step, road candidates, the soak's trade ranges) |
| `docs/architecture/m9-build-spec.md` | 12, row M10: taken up in `m10-build-spec.md` 4.8 (memories and standing, the matrix states, the deal's open markets, `Treasury.WHY`); road works do **not** change reach fields (D46) |
| `docs/architecture/m4-build-plan.md`, `m5-build-plan.md`, `m6-build-plan.md`, `m7-build-plan.md`, `m8-build-plan.md`, `m9-build-plan.md` | Section 7, the M10 bullet: points at this spec |
| `docs/architecture/ui-and-controls-spec.md` | 4.1: the rows `view_mode_8` (8, Trade, M10) and `game_market` (E, M10) |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M10: the files of this spec; the tasks are those of `m10-build-plan.md` |
| `docs/architecture/ui-style-and-feedback-plan.md` | S5, row M10: folded into `m10-build-plan.md` (X14, X17, X18, X19, X25, X26) |
| `docs/architecture/ui-style-and-feedback-spec.md` | 8: a note that the Trade page is specified in this spec 6.7 and the price ring in 4.20 |
| `docs/design/ui/game-feedback-screens.md` | C.2: the Trade page is specified in `m10-build-spec.md` 6.7 |
| `docs/design/reactive-prices.md` | a line under the status: the Godot build is `m10-build-spec.md` (harvests are M4's weather; war closing with grain; fairs after M12) |
| `docs/reports/trade-fun-test.md` | a line under the owner's decisions: built in Godot by `m10-build-spec.md` 1.3 |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `godot/README.md` (the keys, trade, the console; X28), `godot/data/README.md` (X1),
`CLAUDE.md` (the `trade_tables.gd` and `trade_report.gd` lines in the Godot commands; X29). No port rule changes: no new autoload,
no new layer; `tools/lint_godot.py` needs no entry (new files sit in listed folders, each under 800 lines: `trade.gd` about 650,
`merchants.gd` about 450, `trade_cache.gd` about 400).

---

## 12. What M10 hands to later milestones

| M | Takes from M10 | M10 leaves for it |
|---|---|---|
| M11 | Techs that change `TradeDef` numbers through definitions only: `merchant_capacity` (+4), `merchants_max` (+1), `route_cost_point_milli` (−3), `market_reach` (+2), `toll_permille` (+20 a level), `remote_permille` (+100); an idea card that halves `idle_free_seasons`; **taken up in `m11-build-spec.md`** 4.2 and 4.3 (Overseas factories, Galleon, Ocean pilots, Bourse, Mercantilism; Factors' letters) | Research |
| M12 | **Debt and bankruptcy**: purchases and merchants' losses count in M12's debt rules (E5 already brings losing orders home); a country over its debt limit buys nothing (`buy_budget_permille` 0 for it) and its orders come home at bankruptcy; a fallen country's orders and pacts end; **scores**: `income_trade` and the markets held as series M12's score may read; trade fairs as an event kind (a fair multiplies one market's appetite of one good for 4 seasons through `Trade.appetite`, the note's step 3) if the events design wants them (taken up in `m12-build-spec.md` section 12: fairs are the `trade_fair` incident; no buying switch) | A whole game |
| After M12 | **Ships and sea trade**: sea routes between ports (v0.2.2's `sea_walk`, port capacity, naval blockade of a port's routes), river boats on the great rivers, overseas and colonial markets, the Atlantic; the price revolution (parked, 1.3); trade companies; trade clauses in alliances; pact offers to the player (D39); roads in reach fields (a crown project, "Royal road") | |
| **E2, E3** | **Markets on Europe by the same rule (about 600 walled towns, cities and capitals); `market_reach` and the appetites re-tuned there by `trade_report.gd`; section 8's rows on the real map** | |
