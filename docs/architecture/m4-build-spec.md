# M4 build spec: Economy

Game and systems designer (Opus), 2026-11-17. **Status: a proposal, design only; it waits for the owner's go.** Builds
milestone M4 of `docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`), the
M1.5 UI foundation (`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`), the M2 spec and plan (`m2-build-spec.md`,
`m2-build-plan.md`) and the M3 spec and plan (`m3-build-spec.md`, `m3-build-plan.md`). Where this page is more exact it
wins for M4; section 1.2 lists every place where it refines an earlier page. The tasks are in `m4-build-plan.md`. This
page is task **W0** of `ui-style-and-feedback-plan.md` (S3): the district economy that carries the style spec's 7.3, with
`district_output`, `market_prices` and `Treasury.move` written out for Fable to sign.

**What M4 is.** The game gets money and goods. Every district makes goods by its family, level, the season and its winter
slot; wild land makes a little; towns hold people who pay taxes and eat; ports bring dues and fish. Each country keeps
stores (a reserve that carries goods across seasons) and sells what is left over at a fixed price; the crown takes taxes
on people, on the goods sold and at its ports, and pays upkeep for districts and walls. Every ducat moves through one
door, `Treasury.move`, into a ledger with a reason; every load of goods through `Stores.move`. Works cost ducats and goods,
paid when they begin and given back when cancelled in their first season. Taxes are set Low, Normal or High. Weather
comes from the world's luck. The player sees it all: **resource chips** in the top bar, the **works card** (what a build
or upgrade brings, per field and per season, from the same code the season runs), the **Statesman's Study** with the
Economy page's "This season" tab (L), the report's **Treasury, Goods and Standing** sections, money notices on the task
flag, costs on the hex panel, the icon set, map marks while a card is open, and a treasury section in the country panel.
The other countries run the same economy every season; they take no actions until M8.

**When it starts.** After M3 is closed (its plan's definition of done, and the owner has played it). M4 edits `Game`,
`Session`, `Events`, the action table, the season table, `Works`, `Calendar`, `StatsSystem`, `Country`, `Work`, the
report's view, the reminders, the log lines, the hex panel, the top bar, the country panel and the App, and builds its
screens into the M1.5 frame as M3 left it.

**M4 is done when:**

1. **Building choices change your income.** On "Italy, 1480", seed 1480, as Genoa: the first year's treasury lines equal
   section 4.15's table to the ducat (`tests/core/test_economy_genoa.gd`); a vineyard built on the fixture's (7, 12)
   changes the country's year by exactly the card's numbers (+22 a year at the realm's measure, +10 at the treasury's).
2. **No money from nowhere.** `tests/core/test_money_property.gd` plays 40 seasons of the 1480 scenario with seeded random
   actions for every country (works begun and cancelled, taxes set) and finds, every season and every country: the
   treasury's change equals the sum of its ledger lines; each line's reason is in `Treasury.WHY`; each good's stock change
   equals the sum of its flows; a refund never exceeds what the work paid, and only in its first season. A text test finds
   no writer of `treasury` or `stock` outside `treasury.gd` and `stores.gd`.
3. **Every ducat of the report sums to the change.** For every season of that run, the report's Treasury section lines add
   up to `closing − opening` and its Goods lines to each stock's change (`test_season_summary.gd`).
4. **The preview equals the season for four calm seasons.** `tests/core/test_improve_preview.gd`: 200 seeded cases (a
   country, a hex, an option it allows): finish the work at once in a copy, play four seasons with calm weather, and the
   card's per-season district output, the country's goods made, used and sold, and every money line equal the preview to
   the unit; a preview never changes `Game.digest()`.
5. **Determinism and saves.** Same seed and same action log give the same digest after 40 seasons with weather drawn
   (`test_replay.gd`); save, load, save gives byte-equal files with treasuries, ledgers, stocks, flows, taxes and weather
   in them; ten seasons after a load give the same digest as ten without (`test_forty_seasons.gd`).
6. Every M4 UI row of the standard's 9.1 is in the game, built from the M1.5 kit, each with its GUT test: the resource
   chips with hover cards; the works card with the four-season strip, gain per field, the country chart, cost, payback and
   compare; the study frame with Economy, This season (I, L); the icon set; costs and chips on the hex panel rows; the
   M4 task flag rules; the report's money sections and "Open the study"; map marks while a card is open; the country
   panel's treasury section. No stand-in panel is left.
7. On the made-up Europe (494 x 247 hexes, 60 countries, 600 works) the CPU rows of section 8 hold in the nightly
   `perf_core.gd` run (a season's phases under 150 ms; production under 60 ms; a hex panel's previews under 2 ms).
8. Lint, import, check_scripts and GUT are green, with both UI `--check`s and `build_scenario.gd --check`; the art director
   has signed the icon sheet and the pictures of section 9; the owner has played the build through the plan's checklist.

---

## 1. What is there today, and where this page refines earlier pages

### 1.1 Read in the code (master `e3a42be`) and in the data

| Finding | Where | What it means for M4 |
|---|---|---|
| 14 families, ids 1 to 14 (`settlements` 1 to 5; `castles` and 12 goods families 1 to 3); `cell_allowed` holds the ground rules; `GROUND_NEEDS` the refusal words; `PAIR_RULES` the pair rules | `core/systems/improve_rules.gd` | Output is per family and level; the card's requirement lines reuse the rules |
| A grazing piece's `extra` is sheep, cattle or horses (by height and a hash), a mine's is iron, copper or silver (by a hash) | `core/systems/improve.gd` `piece_of` | The good of a grazing or mining district is its `extra`: no new map data |
| `MapData.fertility` and `ore` are all zero (M1: "0 until M4") | `data/maps/north_italy.tres` | M4 does not read them (D27) |
| `MapData.places[]` holds `level`, `port`, `port_mode`; 18 ports, among them Genoa (8, 13) level 4 "carved"; Savona (6, 13) is level 3, no port, not on the coast | the map file | Port dues and port fish come from the places' `port` on a coast hex |
| On seed 1480 the search puts on Genoa's 14 districts: Genoa walled town (8, 13), Savona town (6, 13), vineyard stage 2 (7, 12), timber stage 2 (9, 13), olives stage 3 (7, 14), 9 wild | `tools/worldmap/improve_report.gd -- --seeds=1480` (run read-only for this page) | The worked examples (4.15) use these; the vineyard example clears (7, 12) in a test fixture |
| `Bindings.DEFAULTS` already lists `game_study` (I), `game_ledger` (L), `study_page_prev` (`[`), `study_page_next` (`]`) with `since: "4"`, the tab keys with `since: "4.5"`, and the gesture line "Shift: hold the works card" | `shell/input/bindings.gd` | M4 adds no binding; `MapInput` gains the intents (6.1) |
| `Settings.SCHEMA` already holds `game/confirm_works` (`off`, `expensive`, `always`; `expensive`), `game/preview_on_map` (true), `game/gain_treasury_only` (false, no row), `state/study_page`, `state/study_span`, all `since: "4"` or `"4.5"` | `shell/app/settings.gd` | M4 adds no setting |
| `ShellContext.request(what, args)` emits `app_requested` | `shell/app/shell_context.gd` | Screens ask the App for the study, the card and `look_at` this way |
| The exported `goods.json` holds v0.2.2's 32 goods with base prices (grain 1.0, wine 2.5, silk 6.0 ...) | `godot/data/goods.json` | The M4 price table keeps v0.2.2's prices for the 16 goods the families make (4.2) |
| M2 and M3 deliver `GameDefs`, `CountryDef`, `ScenarioDef`, `Country`, `Territory`, `Countries`, `FamilyDef`, `Work`, `Works`, `Calendar`, `Season`, `Stats`, `StatsSystem`, `Chronicle`, `Luck`, `ViewCache`, `Snapshot`, `SaveFile`, `Replay`, `Knowledge`, `Words`, `WorksView`, `LogLines`, `Reminders`, `SeasonSummary` and the M3 screens | `m2-build-spec.md` 5, `m3-build-spec.md` 5 and 6 | Named "(M2)" and "(M3)" below; M4 starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M4 | Why |
|---|---|---|
| Standard 5.3 and M3 4.2: works (row 6) runs before production (7) and income (8) | **`works` runs after `income`**: M4's table is `production, income, works, stats, calendar` (4.13) | A work finishing in season T then first produces in T + 1, the season M3 says it "stands from". It is v0.2.2's order (`economy`, `collect`, then `grow` counted the queues down). The card's ready date and first yield need it |
| M3 1.2 and 12, M3 plan 7: road works arrive with M4 (`MapState` schema 4) | **Road works move to M10** (Trade); M4 keeps the starting roads and its output reads no road | A road's worth is market reach, which only markets (M10) give; M4 has one home market per country at fixed prices |
| M1 spec 4: `fertility`, `ore` "0 until M4" | Stay 0 and unread; E2 (the Europe map build) decides whether soil and ore data fill them | The goods of a mine come from the piece's `extra`; north Italy has no soil data. One term less to tune now |
| Style spec 7.3 #1: `data/defs/season_profiles.tres` (`SeasonProfileDef`) | The profile is a field of each `FamilyDef` (`season_percent`, six numbers) | One family's numbers in one inspector; no id matching across files |
| Style spec 7.2: `district_output(game, view, hex, season, weather := CALM)` returns `{goods, ducats, upkeep, jobs, room}` | Adds the argument `tax` (−1: the owner's level) and the fields `walls`, `staffing`, `lift`, `good`, `wild` (5.3) | The tax level changes output (D13); the card shows staffing and the ring lift |
| Style spec 7.1: `expensive` is "over a quarter of the treasury, or four seasons or more" | Over a quarter of the treasury, or **eight seasons or more** (`GameDefs.expensive_permille`, `expensive_seasons`) | Every first stage takes four seasons (M3): the old rule would confirm every work |
| Style spec 6.3: one ledger, reasons `tax_people, tax_goods, port_dues, upkeep_districts, upkeep_walls, work, refund` | The same, plus `dev`; and a second door for goods, **`Stores.move`**, with flows `made, used, sold, work, refund, dev` | Goods are paid for works and refunded; one owner per field needs one writer of the stock too |
| M3 4.3: "M4 adds one line `Treasury.move(... refund ...)` in `cancel_work` and sets `paid`" | Two calls: `Treasury.move` and, per good, `Stores.move`; `Work` gains `paid_goods`; the checks gain rows 8 and 9 (money, goods) | Works cost goods as well as ducats (06-growing-map 3; the mockup's "600 ducats · 40 stone · 20 timber") |
| M3 4.10: `SaveFile.FORMAT` 1 | **2**, and `OLDEST_FORMAT` 2: M3 saves read as "Made by an older test build" | A country of an M3 save has no treasury, stores or tax that a default could make right; M3 D31 allows raising `OLDEST_FORMAT` before M12 |
| M3 1.2: weather "drawn from `Luck.world` in the same phase" | Drawn in the `calendar` phase for the season that begins, one value per winter slot (snow, frost, mild), stored in `Game.weather` (owner `Calendar`) | The report and the hover card can name the coming season's weather; one draw per climate zone suits Europe |
| UI plan section 4 M4: `shell/screens/works_card.*` | `shell/screens/works_preview.tscn/.gd` (the style spec's name) | One name |
| UI plan section 4 M4: chips "ducats ... and the like" | M4's chips are **Ducats** and **Stores**; People and Food come with M5, Army M6, Research M11, Prestige M12 | Hidden, not greyed; the mockup's Grain and Prestige chips belong to M5 and M12 |
| Game feedback B.4: a neighbour line "Savona buys the wine: its price 2.8 → 2.5" | M4's ring lines are staffing and the town's lift (4.5); price lines arrive with M10 | Prices are fixed until M10 |
| Style spec 7.1: `ghost.tiles` is `MapCells.of_hex` on the what-if view | `MapCells.piece_cells(map, Improve.piece_for(map, hex, family, level), hex)`: the piece layers only | `of_hex` takes a `MapState`, not a `StateView`; the ghost needs only the piece |
| Style spec 8: the study opens from "the top bar's book button" | A small `KitButton` (icon `study`, tooltip "The Statesman's Study (I)") right of the date medallion, as in `play_m4.jpg` | One more way in, where the mockup puts it |
| M3 6.5: log filters All, Works, Mine (Money M4) | **Money** joins in M4: the lines of `tax_set`, `goods_short` and of works that paid or were refunded | UI spec 7 |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days). Data changes are a
`.tres` edit plus the test that pins the value.

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | Where the economy sits in the season | Two rows, **`production`** (goods: made, used, sold) and **`income`** (money), before `works`; M4's `PHASES`: `production, income, works, stats, calendar` (4.13) | Standard rows 7 and 8; a work stands and produces from the season after it finishes (1.2) | S (a row move and the pin), M for the previews' numbers |
| D2 | Markets | **One home market per country**, its id the country's id; prices are a **fixed table** (`GoodDef.price_milli`); `Economy.market_prices(game, view, market, supply)` returns it and reads neither argument | The seam M10 fills: prices become a function of supply in whole thousandths, markets become places | M10's work |
| D3 | Which goods | **16**: grain, fish, oil, wine, salt, hemp, silk, dyes, wool, cattle, horses, timber, stone, iron, copper, silver (the goods the 14 families make), ids 0 to 15, append-only | Made goods (cloth, tools, weapons) need workshops no family has; M6 and later append their goods | Data (S) per good |
| D4 | Seasons change output | Each family has a **season profile** of six whole percents (spring, summer, autumn, winter in snow, frost, mild) on its `FamilyDef` | Style spec assumed decision 2; the strip is honest only with seasons | Data (S) |
| D5 | Wild land | Every owned land hex yields a little by its cover (farmland and meadow grain, woods timber); a district or a town keeps a share of it (`keep_wild`) | Building on a field gives up some of its grain: the card's "grain 6 → 2" | Data (S) |
| D6 | People | **No people state in M4.** People are a fixed table: a settlement by level, the countryside by cover (4.3); towns are always full. M5 replaces the table with `MapState.people` growing into the same numbers as room | M5 owns growth; M4 needs people for taxes, food and hands now | M5's work (the seam is one function) |
| D7 | Workers and staffing | A district needs `jobs`; the hands of a hex are 30 % of the people of the hex and its six neighbours; staffing = hands over the jobs of the districts there, at most 100 % | v0.2.2's staffing, re-fitted to the ring; it bites in the high valleys and grows with M5's people | Data (S); the rule M |
| D8 | Districts change their ring | Two ring terms only: **staffing** (D7) and a **town's lift**: a goods district beside a walled town gets +10 %, beside a city +20 % (the best neighbour counts). `district_output` reads the hex and its six neighbours, nothing further | Style spec assumed decision 8 ("a little"); a change touches 7 hexes, so a preview is 28 district runs | Data (S) |
| D9 | Food and other needs | **Towns** eat and drink from the stores: food (fish first, then grain), wine, salt, oil per 1,000 town people a season; the countryside feeds itself (its surplus is the wild yield) | v0.2.2's needs, cut to what the families make; M5 adds hunger | Data (S) |
| D10 | What a shortage does in M4 | Lowers the towns' contentment, and the towns' taxes by up to a quarter (4.7); emits `goods_short`; no other effect until M5 (hunger, decline) | A notice must not warn of nothing (M3 1.2); M5 owns people | M5 adds effects (M) |
| D11 | Stocks | Each country keeps **stores** per good; the **reserve** is four seasons of the towns' needs, plus 40 timber, 40 stone and 20 iron; what is above the reserve after the season's use is **sold** at the fixed price | Stocks carry goods across seasons (style spec 7.3 #2); goods turn into money without markets; M10 replaces the flat sale | M10 (M) |
| D12 | Taxes on goods | The crown takes a share of the value of the goods **sold**: Low 50 %, Normal 70 %, High 90 % | Goods must pay the treasury for districts to be worth building; the share keeps people's taxes the larger income, as in 1480 | Data (S) |
| D13 | Tax levels | Low, Normal, High multiply taxes on people by 70, 100, 140 % and set the goods share (D12); districts make goods at **105, 100, 90 %** (people work less under High). `set_tax` at any time; it counts from the next income phase. M5 adds the effect on growth | A real choice in M4 without growth; v0.2.2's 0.7, 1.0, 1.4 | Data (S) |
| D14 | Ports | A port place on a coast hex brings **port dues** (by level, 30 % lower in winter) and **catches fish** (by level, the fishing profile) | The mockup's "Port dues, Genoa"; Genoa feeds itself from the sea | Data (S) |
| D15 | Upkeep | Districts 1, 2, 4 ducats a season by stage (mines and harbours 2, 3, 5); settlements 0, 0, 1, 2, 2, 5 by level; **walls**: walled town 4, city 6, castles 2, 4, 8 | 06-growing-map 3 ("a small upkeep, so over-building hurts"); the mockup's vineyard 1 a season and Genoa 6 → 11 | Data (S) |
| D16 | Build costs | Stage 1 40 ducats; stage 2 100 + 10 timber; stage 3 250 + 20 timber + 20 stone (mines and harbours more); towns and castles their own table (4.4); clearing is free | 06-growing-map 3 (about 40, 100, 250); goods for the larger works | Data (S) |
| D17 | Paying | Ducats and goods are paid **when the work begins** (`Treasury.move` `work`, `Stores.move` `work`); `cancel_work` in the work's first season gives both back (`refund`); later, nothing (M3 D14) | Style spec 7.4; the undo is honest | S |
| D18 | Not enough | A work is refused when the treasury is under its ducats ("not enough ducats: 40 needed, 12 in the treasury") or a good is short ("not enough stone: 40 needed, 12 in store"): rows 8 and 9 of M3's check table | One door for the AI (M8) and the player | S |
| D19 | At zero money (debt is M12's) | Upkeep is **always paid**, so the treasury may fall below zero; nothing that costs ducats can begin while it is under the cost; no interest, no desertion, no seizure. `EconomySeason.debt_limit` returns 0 (M12 gives the real limit) and a serious notice says the treasury is empty | M12 owns debt and bankruptcy; a country must never be stuck by a rule M4 does not have | M12's work |
| D20 | Start of a game | Treasury `200 + 5` per 1,000 people (Genoa 610, Milan 1,905); stores at their reserve | No hand numbers per country; scales to Europe; a calm first year | Data (S) |
| D21 | Weather | Drawn in the `calendar` phase for the season that begins: per winter slot, calm 60 %, good 20 %, poor 20 %; crops (and wild grain) ×120 % or ×75 %; previews count calm ("Weather not counted") | M3 handed it over; it is the only luck in M4's rules | Data (S) |
| D22 | Other countries | Every living country runs `production` and `income` every season in id order; none acts until M8 | The AI is a player (standard 5.6); their numbers must be real for Standing | none |
| D23 | The sandbox | No money and no stores: the economy phases skip it, works are free, no chips; the card shows the district's goods by season only | It is the developer's map tool; money needs countries | M |
| D24 | The money door | `Treasury.move(game, tag, amount, why, hex, count)` is the only code that changes a treasury; lines merge by `(why, hex)`; taxes are one line a country, ports, walls and works a line per hex | Style spec 6.3; a ledger small enough to save on Europe | S |
| D25 | The goods door | `Stores.move(game, tag, good, amount, why)` is the only code that changes a stock; flows per good and reason in a packed array; never below zero | One owner per field; the report's Goods lines sum to each change | S |
| D26 | Units | Money in whole ducats, goods in whole loads, prices and rates in thousandths; integer steps, each floored (4.4) | Standard 5.4: stored amounts are integers; one rounding rule for the season and the preview | M |
| D27 | `fertility`, `ore` | Unread in M4 (1.2) | No soil data; a mine's ore is its piece | M (a term and a map rebuild) |
| D28 | Speed | A derived **`DistrictCache`** on `Game` keeps each land hex's season-free part of `district_output`; `Game.emit` of `hex_changed` marks the hex and its ring dirty; not saved, not in the digest | Europe has 70,000 land hexes; the season reads each once | S (drop the cache) |
| D29 | What "gain" means on the card | **The realm's measure** by default: goods made at the fixed price, plus port dues and taxes on people, less upkeep; the switch "Treasury only" (`game/gain_treasury_only`) shows the crown's ducats. Payback uses the measure shown | The style spec's rule (7.1); the mockup's numbers are the realm's | S |
| D30 | The preview's window | The **four seasons from now**, today's districts with works under way standing from their ready turns, calm weather, stores simulated from today's stock | Equal to the season by construction (D1, D26); the strip shows each season once | M |
| D31 | Payback | From the ready turn, the four previewed seasons' gains repeated, until the sum reaches the cost (ducats plus goods at price); "never" past 400 seasons; "a prestige work" when never | The mockup's rule ("at today's prices") | S |
| D32 | Expensive | Cost over a quarter of the treasury, or eight seasons or more (1.2) | Confirms only the large works | Data (S) |
| D33 | The chips | **Ducats** (treasury, the last season's change; card: the closed ledger and "Expected this season") and **Stores** (the stock's worth at price; card: each good's stock and change) | UI plan M4 row; the mockup's chip style; later chips with their systems | S a chip |
| D34 | Earns most, costs most | By place: each hex's worth for the season in play (goods at price, dues, its people's taxes; upkeep and walls), from the same preview as "Expected this season"; estimates rounded per place | The ledger keeps taxes as one line a country (D24); a place's worth is what the player can act on | S |
| D35 | The report's money | Sections **Treasury** (the closed ledger, every ducat), **Goods** (each good's stock, change and flows), **Standing** (rank in land and income among known countries); glance chips for the treasury and the largest goods swings; `swing_permille` | Style spec 6.4; the screen draws them since M3 | none |
| D36 | Money notices | `treasury_empty` (serious), `goods_running_out` (serious for food within two seasons), `treasury_falling` (attention) | M3 handed "the money and food reminders" over | S a rule |
| D37 | Events | `goods_short` (only the actor witnesses it) and `tax_set`; money itself is state, not an event | Game feedback D.2 | S |
| D38 | Saves | `SaveFile.FORMAT` 2 and `OLDEST_FORMAT` 2 (1.2); `country/2`, `work/2`; `Game.weather` in the body and the digest | M3 D31 | S |
| D39 | The country panel | Your country: treasury, last change, expected, tax level, "Open the study"; a known country: treasury about (banded); an unknown one: nothing | M2 handed "the country panel's treasury section" to M4; `Knowledge` is the one door | S |
| D40 | The refusal in plain words | `WorldImprove.conflict` returns the pair rule and the other hex; `ImproveRules.PAIR_WORDS` holds one sentence a rule ("Cuneo (5, 13) is a town beside Savona: two towns may not stand side by side.") | No string parsing; the card's refusal reads as a sentence | S |
| D41 | Not built in M4 | Districts, Goods, History and Debt tabs; the Yields mode; Rankings, History pages (M4.5, M12); reactive prices, markets, roads works (M10); people growth (M5) | Their milestones | none |
| D42 | Settlement payoffs | M4's towns are full (D6), so a town upgrade brings all its people at once; M5 makes people grow into room and re-tunes these costs | M4 must be playable alone; the numbers move once, with M5 | M5's data |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| Goods with base prices (grain 1.0 ... spices 9.0); `OUTPUT` per 1,000 peasants; prices between `PRICE_FLOOR` 0.3 and `PRICE_CAP` 3.5 times base by supply and demand (`ELASTICITY` 0.6) | `data.py` 30 to 92; `economy.set_prices` | The 16 base prices of the goods the families make; "a price is a function of supply" as the seam | Prices fixed until M10 (D2); output per district by level and season, not per peasant (D4) |
| `economy()` runs once a season: subsistence grain from peasants, a province's good × workers × works factor, manufactories, routes, then `incomes` | `systems/economy.py` | One function the season and the preview share (`preview=True` projected without using anything up) | The preview is a `StateView` overlay over the same pure functions (style spec 7.2), not a replayed world with undo |
| `incomes`: production tax 12 % of the goods' value × the tax rate; peasant 0.02 and burgher 0.15 ducats per 1,000 × the rate × the settlement bonus; burghers pay half when cloth is short; upkeep of buildings, works, settlements and castles | `economy.incomes` | Taxes on people and on goods by the tax level; needs that cut town taxes (here food, wine, salt, oil); upkeep by holding | One rate for towns and one for the countryside (no classes until M5); the goods tax is on what is sold, at a higher share, since stores keep the rest (D11, D12) |
| `TAX_LEVELS` low 0.7, normal 1.0, high 1.4; `TAX_GROWTH` +0.0015, 0, −0.002; `preview_tax` | `data.py` 458; `economy.preview_tax` | The three levels and the multipliers; the hover preview | High also cuts output in M4 (D13); growth is M5's |
| `collect`: `treasury += balance` | `economy.collect` | | Every ducat through `Treasury.move` with a reason (D24) |
| Building: `build_check` refuses when the treasury is short ("Costs 40 ducats"); `build_cost` = ducats + goods at local prices; goods "bought" on the market; "one job a season" (`busy`); `BUILD_TURNS` 4 | `systems/building.py` | Refuse when short; costs in ducats and goods | Goods come from the country's stores (D17); M3's work slots replace "one job a season"; durations 4, 8, 16 (M3) |
| `WORKS_COST` 25, 45, 75, 112, 162 and goods per level; `WORKS_UPKEEP` 0.05 a level | `data.py` 192 to 230 | Costs rise with the stage; a small upkeep | Three stages per family with 06-growing-map's 40, 100, 250 (D16) |
| `SUBSISTENCE` 0.15 grain per 1,000 peasants; food demand 0.25 per 1,000 | `data.py` 475, `NEEDS` | Food drives the towns | The countryside feeds itself; towns eat 0.1 a 1,000 (D9); the wild yield is the countryside's surplus (D5) |
| `debt_limit` (`DEBT_FLOOR` 300, 6 seasons of costs), interest 2 %, desertion, seizure | `systems/debt.py` | | M12 (D19) |
| Starting treasury `150 + 4 / AREA` per province | `worldgen.py` 424 | A base plus a share by size | By people (D20) |
| The resource `Tracker`: chips with value, change and hover lines that add up to the change ("Other" for the rest); **not saved** | `campaign/resources.py` | Chips with value, change and a card | The card reads the saved closed ledger, so every line is real and nothing is "Other" |
| `reminders.nothing_built` ("Nothing is being built, and you can pay for it") | `campaign/reminders.py` | The idea | M3's `free_slot`; M4's money and goods notices (4.18) |

---
## 4. Design content

### 4.1 The model in one picture

```
 each season, every living country in id order
 production   every owned land hex: district_output(hex, season, weather, tax)  ->  goods made        Stores.move made
              towns' needs (food: fish then grain; wine; salt; oil)              ->  goods used        Stores.move used
              stock above the reserve                                             ->  goods sold        Stores.move sold
              a need not met (and met last season)                                ->  goods_short
 income       taxes on people (towns x contentment, countryside)                 ->  tax_people        Treasury.move
              the crown's share of the goods sold                                 ->  tax_goods
              each port's dues                                                    ->  port_dues  (per port)
              district upkeep; walls                                              ->  upkeep_districts, upkeep_walls (per walled hex)
 works        progress; a finished work stands from the next season (M3)
 stats        the season's row; Treasury.close_ledger; Stores.close
 calendar     turn + 1; weather for the season that begins
 any time     build / upgrade / clear: Treasury.move work, Stores.move work      cancel_work in the first season: refund
              set_tax (counts from the next income)
```

### 4.2 Goods (`data/defs/goods/<key>.tres`, `GoodDef`)

Ids are the order of the table and the index of every per-good array (stock, flows, `Stats.goods_ring`). Append-only.
Prices are v0.2.2's base prices in thousandths of a ducat. "Need" is loads a season per 1,000 town people, in
thousandths; food is one need shared by fish and grain (`GameDefs.food_need_milli`).

| Id | Key | Name | Kind | Price (milli) | Need (milli) | Weight (permille) | Reserve | Made by |
|---|---|---|---|---|---|---|---|---|
| 0 | `grain` | Grain | food | 1,000 | food | food | 4 seasons of food | wheat; wild farmland and meadow |
| 1 | `fish` | Fish | food | 1,000 | food (eaten first) | food | 0 | harbour; port towns |
| 2 | `oil` | Olive oil | staple | 2,500 | 10 | 100 | 4 seasons of need | olives |
| 3 | `wine` | Wine | staple | 2,500 | 20 | 100 | 4 seasons of need | vineyard |
| 4 | `salt` | Salt | staple | 2,000 | 10 | 100 | 4 seasons of need | salt pans |
| 5 | `hemp` | Hemp and flax | ware | 1,200 | 0 | 0 | 0 | hemp |
| 6 | `silk` | Silk | ware | 6,000 | 0 | 0 | 0 | silk |
| 7 | `dyes` | Dyes | ware | 5,000 | 0 | 0 | 0 | dye works |
| 8 | `wool` | Wool | ware | 1,500 | 0 | 0 | 0 | grazing (sheep) |
| 9 | `cattle` | Cattle | ware | 1,500 | 0 | 0 | 0 | grazing (cattle) |
| 10 | `horses` | Horses | ware | 3,000 | 0 | 0 | 0 | grazing (horses) |
| 11 | `timber` | Timber | material | 1,000 | 0 | 0 | 40 | timber; wild woods |
| 12 | `stone` | Stone | material | 1,000 | 0 | 0 | 40 | quarry |
| 13 | `iron` | Iron | material | 2,000 | 0 | 0 | 20 | mines (iron) |
| 14 | `copper` | Copper | ware | 2,500 | 0 | 0 | 0 | mines (copper) |
| 15 | `silver` | Silver | ware | 7,000 | 0 | 0 | 0 | mines (silver) |

Food: `food_need_milli` 100 (a load a season feeds 10,000 town people), `food_weight` 700. The four weights add to 1,000.
A need is `ceil(town_people × need_milli / 1,000,000)` loads a season (0 town people need nothing). The reserve of a
needed good is `reserve_seasons` (4) times its need; of a material its fixed reserve; grain's is four seasons of food.

### 4.3 People and hands (fixed in M4; M5 makes them grow)

`Economy.people_at(game, view, hex)`: a settlement hex holds its level's people (`FamilyDef.people` of settlements);
any other land hex holds the countryside people of its cover (`GameDefs.country_people`); sea holds none.

| Settlement level | 1 hamlet | 2 village | 3 town | 4 walled town | 5 city |
|---|---|---|---|---|---|
| People | 1,000 | 3,000 | 10,000 | 30,000 | 60,000 |

| Cover | farmland | grassland | woods | marsh | rock | snow | tundra | sand |
|---|---|---|---|---|---|---|---|---|
| Countryside people | 8,000 | 5,000 | 2,500 | 1,500 | 600 | 0 | 0 | 1,500 |

**Town people** of a country are the people of its settlement hexes; **countryside people** the rest of its land.
**Hands** of a hex: `(people of the hex + people of its six land neighbours) × hands_permille (300) / 1000`. People and
hands count whoever owns the hexes (people cross borders to work).

### 4.4 District output

`Economy.district_output(game, view, hex, season, weather, tax)` is the one function. `slot` is the season (0 spring, 1
summer, 2 autumn) or, in winter, `3 + MapData.climate` (3 snow, 4 frost, 5 mild). A goods district of family `f` at
level `L` (all integers, every division floored, in this order):

```
a0 = base[L] × extra_permille                 # thousandths of a load a season at 100 %; extra 1000 unless grazing or mines
a0 = a0 × staffing / 1000                     # 4.5
a0 = a0 × (1000 + lift) / 1000                # 4.5          (a0 is what DistrictCache keeps, D28)
a  = a0 × season_percent[slot] / 100
a  = a × output_permille[tax] / 1000          # 1050, 1000, 900
a  = a × weather_permille[w] / 1000           # only when weather_bound; w = Game.weather[climate]; 1000, 1200, 750
n  = a / 1000                                  # loads of the family's good this season
```

Then every hex adds its **wild yield**: `n = wild_yield[cover][slot] × 1000 × keep / 100 × weather_permille / 1000 / 1000`
of its cover's good (weather only on grain), where `keep` is 100 on a wild hex and the family's `keep_wild[L]` on any
piece (100 for castles). A **port** (a place with `port` on a hex with a sea side) adds fish
`port_fish[L] × 1000 × fishing_percent[slot] / 100 × output_permille[tax] / 1000 / 1000` and port dues
`port_dues[L] × port_dues_percent[slot] / 100` ducats. `upkeep` and `walls` are `FamilyDef.upkeep[L]` and `walls[L]`.
Unowned land yields nothing to anyone.

**Wild yield** (`GameDefs.wild_good`, `wild_yield`, loads a season):

| Cover | Good | Spring | Summer | Autumn | Winter snow | Winter frost | Winter mild | A frost year |
|---|---|---|---|---|---|---|---|---|
| farmland | grain | 1 | 3 | 2 | 0 | 0 | 1 | 6 |
| grassland | grain | 0 | 1 | 1 | 0 | 0 | 0 | 2 |
| woods | timber | 0 | 0 | 1 | 0 | 1 | 1 | 2 |
| marsh, rock, snow, tundra, sand | none | | | | | | | 0 |

**Goods families** (`FamilyDef`; base in loads a season at 100 %; percents per slot; years at full staffing, Normal, calm):

| Family | Good | Base 1 / 2 / 3 | Sp | Su | Au | W snow | W frost | W mild | Weather | Keep wild % 1 / 2 / 3 | Frost year 1 / 2 / 3 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| wheat | grain | 10 / 20 / 32 | 20 | 100 | 40 | 0 | 0 | 10 | yes | 0 / 0 / 0 | 16 / 32 / 50 (mild 17 / 34 / 53) |
| hemp | hemp | 10 / 20 / 32 | 0 | 50 | 100 | 0 | 0 | 0 | yes | 50 / 25 / 0 | 15 / 30 / 48 |
| silk | silk | 3 / 6 / 10 | 100 | 50 | 0 | 0 | 0 | 0 | yes | 50 / 25 / 0 | 4 / 9 / 15 |
| dyes | dyes | 2 / 4 / 7 | 50 | 100 | 50 | 0 | 0 | 0 | yes | 50 / 25 / 0 | 4 / 8 / 13 |
| vineyard | wine | 12 / 24 / 40 | 0 | 0 | 100 | 0 | 0 | 0 | yes | 50 / 25 / 0 | 12 / 24 / 40 |
| olives | oil | 8 / 16 / 28 | 0 | 0 | 50 | 0 | 0 | 100 | yes | 50 / 25 / 0 | mild only: 12 / 24 / 42 |
| grazing | wool, cattle, horses (extra 1000, 750, 375) | 8 / 16 / 26 | 100 | 120 | 60 | 0 | 30 | 30 | yes | 0 / 0 / 0 | sheep 23 / 48 / 79; cattle 17 / 36 / 58; horses 7 / 17 / 27 |
| timber | timber | 6 / 12 / 20 | 50 | 50 | 50 | 0 | 150 | 150 | no | 0 / 0 / 0 | 18 / 36 / 60 (snow 9 / 18 / 30) |
| mines | iron, copper, silver (extra 1000, 750, 250) | 4 / 8 / 14 | 100 | 100 | 100 | 0 | 70 | 100 | no | 0 / 0 / 0 | iron 14 / 29 / 51; copper 11 / 22 / 37; silver 3 / 7 / 11 |
| quarry | stone | 6 / 12 / 20 | 100 | 100 | 100 | 0 | 70 | 100 | no | 0 / 0 / 0 | 22 / 44 / 74 |
| salt | salt | 4 / 8 / 14 | 50 | 150 | 100 | 0 | 0 | 20 | yes | 0 / 0 / 0 | 12 / 24 / 42 |
| harbour | fish | 4 / 8 / 14 | 100 | 100 | 100 | 30 | 50 | 70 | no | 0 / 0 / 0 | 14 / 28 / 49 |

Durations are M3's (`FamilyDef.work_seasons`, unchanged): 4, 8 and 16 seasons to stages 1, 2 and 3; a clear 1.

| Family | Jobs 1 / 2 / 3 | Upkeep 1 / 2 / 3 | To stage 1 | To stage 2 | To stage 3 | Ground (the card's line) |
|---|---|---|---|---|---|---|
| wheat | 1,000 / 2,000 / 4,000 | 1 / 2 / 4 | 40 | 100 + 10 timber | 250 + 20 timber + 20 stone | "low farmland, up to 600 m" |
| hemp | same | 1 / 2 / 4 | 40 | 100 + 10 timber | 250 + 20 timber + 20 stone | "farmland at a river or stream, up to 400 m" |
| silk | same | 1 / 2 / 4 | 40 | 100 + 10 timber | 250 + 20 timber + 20 stone | "farmland or meadow within two hexes of a town, up to 600 m, no snow winter" |
| dyes | same | 1 / 2 / 4 | 40 | 100 + 10 timber | 250 + 20 timber + 20 stone | "farmland or meadow beside a town, up to 500 m" |
| vineyard | same | 1 / 2 / 4 | 40 | 100 + 10 timber | 250 + 20 timber + 20 stone | "farmland or meadow, 100–900 m, no snow winter" |
| olives | same | 1 / 2 / 4 | 40 | 100 + 10 timber | 250 + 20 timber + 20 stone | "the mild winter, on the coast or up to 900 m" |
| grazing | same | 1 / 2 / 4 | 40 | 100 + 10 timber | 250 + 20 timber + 20 stone | "meadow, or woods from 700 m" |
| timber | same | 1 / 2 / 4 | 40 | 100 + 10 timber | 250 + 20 timber + 20 stone | "woods up to 1,800 m" |
| quarry | same | 1 / 2 / 4 | 40 | 100 + 10 timber | 250 + 20 timber + 20 stone | "rock, or upland from 700 m" |
| salt | same | 1 / 2 / 4 | 40 | 100 + 10 timber | 250 + 20 timber + 20 stone | "a low shore" |
| mines | same | 2 / 3 / 5 | 60 + 10 timber | 150 + 20 timber | 350 + 30 timber + 20 stone | "rock, or high ground from 1,000 m" |
| harbour | 500 / 1,000 / 2,000 | 2 / 3 / 5 | 60 + 10 timber | 150 + 20 timber | 350 + 30 timber + 20 stone | "a coast with no port beside it" |

Every stage also needs its reach (M1's rules, unchanged): stage 2 a place within two hexes or a road; stage 3 a town within
two hexes (and, but for mines and quarries, not above 1,200 m off the coast; mines and quarries a road). Weather-bound
families and wild grain change by weather; the others never.

**Settlements** (family 1; `FamilyDef` of `settlements`; level 1 is never begun, places come from the map; M3's durations: to
village 4 seasons, to town, walled town or city 8):

| Level | People | Keep wild % | Upkeep | Walls | Ring lift (permille) | Port fish (a season at 100 %) | Port dues (a season at 100 %) | To this level |
|---|---|---|---|---|---|---|---|---|
| 1 hamlet | 1,000 | 100 | 0 | 0 | 0 | 1 | 2 | (never begun) |
| 2 village | 3,000 | 100 | 1 | 0 | 0 | 2 | 5 | 100 + 10 timber |
| 3 town | 10,000 | 100 | 2 | 0 | 0 | 4 | 12 | 300 + 20 timber + 10 stone |
| 4 walled town | 30,000 | 75 | 2 | 4 | 100 | 6 | 30 | 700 + 20 timber + 60 stone |
| 5 city | 60,000 | 50 | 5 | 6 | 200 | 10 | 45 | 1,000 + 20 timber + 40 stone |

Port dues percent by slot (`port_dues_percent`): 100, 110, 100, and 70 in every winter. Fishing percent
(`fishing_percent`, also harbours'): 100, 100, 100; winter 30 snow, 50 frost, 70 mild.

**Castles** (family 2; on passes; no goods in M4: their worth is war, M6 and M7): keep wild 100; upkeep 0; walls 2, 4, 8;
to level 1 (watchtower) 60 + 10 timber + 10 stone, 2 (castle) 200 + 40 stone, 3 (fortress) 500 + 80 stone + 10 iron; 4, 8
and 16 seasons (M3).

**Clearing** costs nothing, takes one season (M3) and gives nothing back.

### 4.5 Staffing and the ring

- `jobs_near(hex)`: the jobs of the goods districts on the hex and its six neighbours (`FamilyDef.jobs[L]`).
- `staffing(hex)` (permille) for a goods district: `1000` when `jobs_near` is 0, else `min(1000, hands(hex) × 1000 /
  jobs_near(hex))`. Settlements and castles have no jobs and are not scaled.
- `lift(hex)` (permille) for a goods district: the largest `ring_lift` of the settlements among its six neighbours
  (walled town 100, city 200), whoever owns them.

So a change on a hex changes `district_output` on that hex and its six neighbours, and nowhere else (style spec 7.3 #4).

### 4.6 Weather

`Calendar.season` (M3), after `turn += 1`, draws the weather of the season that begins for each winter slot in the order
snow, frost, mild: `r = game.luck.world.randi_range(1, 100)`; calm when `r <= odds[0]`, good when `r <= odds[0] + odds[1]`,
poor otherwise (`GameDefs.weather_odds` 60, 20, 20). `Game.weather` is three bytes (0 calm, 1 good, 2 poor); a new game
starts calm. `weather_permille` is 1,000, 1,200 and 750. Only weather-bound families and wild grain feel it. Every preview
counts calm. `Calendar.weather_text(game, tag)` names the slots where `tag` holds land and the weather is not calm, with
the places "in the high valleys" (snow), "inland" (frost), "on the coast" (mild): "Summer: good on the coast, poor in the
high valleys (crops +20 %, −25 %)."; "" when all is calm. The report's glance and the hover card show it.

### 4.7 Needs and contentment

In `production`, after the goods made are stored, each country's towns take their needs from the stores: food from fish,
then grain; then wine, salt and oil. `satisfaction` of a need is `taken × 1000 / need` (1,000 when the need is 0).

```
content = (700 × food + 100 × wine + 100 × salt + 100 × oil) / 1000          # each a satisfaction in permille
factor  = content_floor (750) + content × (1000 − 750) / 1000                 # 750 to 1,000
```

`factor` scales the towns' taxes (4.9). When a need is not fully met this season and was met last season, `production`
emits `goods_short {tag, good: food|wine|salt|oil, need, taken, witnesses: [tag]}`.

### 4.8 Stores: the reserve, sales and flows

After the needs, every good whose stock is above its reserve (4.2) is **sold** down to the reserve, at the fixed price.
The stock is never negative. Every change is a `Stores.move` with one of the flows:

| Flow | Sign | By |
|---|---|---|
| `made` | + | `production`: the goods made |
| `used` | − | `production`: the towns' needs taken |
| `sold` | − | `production`: the stock above the reserve |
| `work` | − | `Works.build`, `upgrade`, `clear`: the goods of a work's cost |
| `refund` | + | `Works.cancel_work` in the work's first season |
| `dev` | ± | `Game.dev_goods` (the developer console; recorded in the action log) |

Per country, `flows_open` holds the season's flows (good × flow); `Stores.close` (in the `stats` phase) moves them to
`goods_closed {turn, opening, closing, flows}`. Property: for every good, `closing − opening == sum of its flows`.

### 4.9 Money

The `income` phase, for each living country in id order, at the country's tax level `t` (`Country.tax`, 0 Low, 1 Normal,
2 High), from this season's flows:

| Line (`why`) | Hex | Amount (ducats, floored) |
|---|---|---|
| `tax_people` | none | `(town_people × town_tax_milli × factor / 1000 + countryside_people × country_tax_milli) × tax_permille[t] / 1,000,000,000` |
| `tax_goods` | none | `(sum over goods of sold × price_milli) × goods_share_permille[t] / 1,000,000` |
| `port_dues` | each port | `port_dues[L] × port_dues_percent[slot] / 100` |
| `upkeep_districts` | none (`count` = districts with upkeep) | `− sum of upkeep` over the country's hexes |
| `upkeep_walls` | each walled hex | `− walls` |

`town_tax_milli` 1,000, `country_tax_milli` 600 (thousandths of a ducat per 1,000 people a season); `tax_permille` 700,
1,000, 1,400; `goods_share_permille` 500, 700, 900. Port dues are customs: the tax level does not change them.

Lines from actions (at the moment of the action): `work` (− the work's ducats, at its hex), `refund` (+ what it paid,
at its hex), `dev` (the console). `Treasury.close_ledger` (in `stats`) moves the season's lines to `ledger_closed {turn,
opening, closing, lines}`. Property: `closing − opening == sum of the lines`.

### 4.10 Tax levels

| Level | Taxes on people | Share of goods sold | Districts' output | Shown as |
|---|---|---|---|---|
| Low | 70 % | 50 % | 105 % | "Low" |
| Normal (start) | 100 % | 70 % | 100 % | "Normal" |
| High | 140 % | 90 % | 90 % | "High" |

`EconomySeason.set_tax_check(game, {level, tag})`, in order:

| Case | Verdict |
|---|---|
| The game has no countries | "this map has no countries" |
| `tag` is `&""` | "choose your country first" |
| No country has `tag` | "no country %s" |
| The country is not alive | "%s is no more" |
| `level` is not 0, 1 or 2 | "no such tax level" |
| `level` is the country's level | "taxes are already %s" ("Low", "Normal", "High") |
| Otherwise | ok |

`set_tax` checks again, writes `Country.tax` and emits `tax_set {tag, level, from}`. It counts from the next `production`
(output) and `income` (rates); a change and a change back in one season cost nothing.

### 4.11 Paying for works; zero money

`Works.cost_of(game, action, family, level_to) -> {ducats: int, goods: {good key: loads}}` reads `FamilyDef.cost[level_to]`
and `cost_goods[level_to]` (a clear is free; a map-only game pays nothing). M3's check table gains two rows after row 7:

| # | Case | Verdict |
|---|---|---|
| 8 | The game has countries and the actor's treasury is under the work's ducats | "not enough ducats: %d needed, %d in the treasury" |
| 9 | A good of the cost is short in the actor's stores (the first in good id order) | "not enough %s: %d needed, %d in store" (the good's name in lower case) |

`Works.build`, `upgrade` and `clear`, after appending the work, call `Treasury.move(game, tag, −ducats, &"work", hex)` and,
per good in id order, `Stores.move(game, tag, good, −n, &"work")`, and set `work.paid` and `work.paid_goods`.
`Works.cancel_work` gives back `Works.refund(game, work)` ducats (`&"refund"`, at the hex) and `Works.refund_goods` goods
when `work.started_turn == game.turn`; otherwise nothing. A work cancelled `lost` or `blocked` (M3 D13) gives nothing back.

**At zero money** (D19): upkeep is always paid, so a treasury may fall below zero; rows 8 and 9 refuse everything that
costs; `treasury_empty` (4.18) says so. `EconomySeason.debt_limit(game, tag)` returns 0; M12 replaces it, adds interest
(a `Treasury.WHY` `interest`) and bankruptcy.

### 4.12 The start of a game

`Treasury.setup` and `Stores.setup` run in `Game.new_scenario` after `Countries.setup` and `Territory.setup` (M2), with every
country at Normal and calm weather:

- treasury `start_treasury_base (200) + start_treasury_per_1000 (5) × (all its people / 1000)`;
- stores at the reserve (4.2); flows zero; `ledger_from` the treasury; `stock_from` the stock.

People do not depend on the seed (settlements are the map's places; the countryside is the cover), so neither do these:

| Tag | People | Town | Countryside | Treasury | Needs a season (food, wine, salt, oil) | Grain reserve | First year's net on seed 1480 (Sp, Su, Au, Wi) |
|---|---|---|---|---|---|---|---|
| SAV | 260,400 | 129,000 | 131,400 | 1,500 | 13, 3, 2, 2 | 52 | 240, 307, 281, 167 (995) |
| MLO | 341,700 | 249,000 | 92,700 | 1,905 | 25, 5, 3, 3 | 100 | 261, 314, 309, 263 (1,147) |
| VEN | 303,200 | 175,000 | 128,200 | 1,715 | 18, 4, 2, 2 | 72 | 288, 423, 335, 234 (1,280) |
| GEN | 82,700 | 40,000 | 42,700 | 610 | 4, 1, 1, 1 | 16 | 86, 91, 147, 134 (458) |
| TUS | 103,500 | 63,000 | 40,500 | 715 | 7, 2, 1, 1 | 28 | 133, 144, 146, 180 (603) |
| SWI | 122,600 | 66,000 | 56,600 | 810 | 7, 2, 1, 1 | 28 | 82, 82, 89, 80 (333) |
| MAN | 23,000 | 10,000 | 13,000 | 315 | 1, 1, 1, 1 | 4 | 15, 19, 17, 15 (66) |
| FER | 70,200 | 40,000 | 30,200 | 550 | 4, 1, 1, 1 | 16 | 51, 55, 55, 56 (217) |
| SIE | 18,000 | 3,000 | 15,000 | 290 | 1, 1, 1, 1 | 4 | 12, 12, 16, 20 (60) |
| LUC | 5,500 | 3,000 | 2,500 | 225 | 1, 1, 1, 1 | 4 | 8, 8, 9, 6 (31) |
| PAP | 117,100 | 39,000 | 78,100 | 785 | 4, 1, 1, 1 | 16 | 100, 119, 111, 124 (454) |
| FRA | 62,400 | 9,000 | 53,400 | 510 | 1, 1, 1, 1 | 4 | 46, 52, 55, 51 (204) |
| AUS | 53,800 | 23,000 | 30,800 | 465 | 3, 1, 1, 1 | 12 | 32, 32, 111, 32 (207) |

The last column is the money lines' sum (no works begun, calm weather forced in the test's defs); it depends on the
pieces the search puts down, so it is pinned for seed 1480 only (`test_economy_1480.gd`). Lucca and Siena are poor on
purpose: M2 named them the hard starts.

### 4.13 The season table after M4

`core/game/season.gd` `PHASES` in M4: **`production`, `income`, `works`, `stats`, `calendar`** (`test_season.gd` pins
it). The planned order of every milestone, edited from M3's 4.2:

| # | Name | Arrives | Reads | Writes (through the owner) |
|---|---|---|---|---|
| 1 | `ai_orders` | M8 | everything through views | through `Game.act` only |
| 2 | `movement`, `battles` | M6, M7 | armies, map | armies, battles |
| 3 | `supply` | M6 | armies, owner | armies |
| 4 | `sieges` | M7 | armies, castles | owner, controller |
| 5 | `war_timeouts` | M9 | wars | wars |
| 6 | **`production`** | **M4** | `owner`, `main_use`, `level`, `weather`, each country's `tax` and `stock`, `defs` | `stock`, `flows_open` (`Stores.move`); events `goods_short` |
| 7 | `trade` | M10 | markets, stocks | stocks, prices |
| 8 | **`income`** | **M4** | `owner`, `main_use`, `level`, `turn`, `tax`, `flows_open`, `defs` | `treasury`, `ledger_open` (`Treasury.move`) |
| 9 | `debt` | M12 | ledgers, treasury | treasury |
| 10 | **`works`** | **M3** (moved here in M4) | as M3 4.2 | as M3 4.2 |
| 11 | `people` | M5 | food, stores | people |
| 12 | `research` | M11 | research | techs |
| 13 | `extinction`, `scores` | M12 | countries | `alive`, score |
| 14 | **`stats`** | **M3** | as M3, and the ledgers and flows | `stats`; `ledger_closed`, `ledger_open`, `ledger_from` (`Treasury.close_ledger`); `goods_closed`, `flows_open`, `stock_from` (`Stores.close`) |
| 15 | **`calendar`** | **M3** | `turn` | `turn`, `weather` (`Calendar`); draws `luck.world` |
| 16 | `ready_units`, `vision` | M6 | armies | armies, explored |

### 4.14 Other countries, unowned land, the sandbox

Every living country runs both phases every season, in id order, with its own tax level (Normal: nobody else sets it
until M8). Their works, treasuries and stores are real; `Knowledge` (M3) decides what the player may see of them.
Unowned land makes nothing and costs nothing. A map-only game (the sandbox) has no countries: the phases do nothing,
`Works.cost_of` is zero, the chips are hidden, the study cannot open ("the sandbox has no treasury"), and the works card
shows the district's goods by season with the money rows hidden.

### 4.15 Worked examples

All on "Italy, 1480", **seed 1480**, as Genoa, Normal taxes, calm weather (the tests force calm with
`weather_odds = [100, 0, 0]` in their copy of the defs). "The fixture" is the same game with (7, 12) made wild before
turn 1 (`tests/core/economy_fixture.gd`): the search put a second-stage vineyard there, and the mockup's example builds
a first one.

**(a) Genoa's land and its first year (seed 1480, no works).** People 82,700 (towns 40,000); treasury 610; stores grain
16, oil 4, wine 4, salt 4, timber 40, stone 40, iron 20; needs a season food 4, wine 1, salt 1, oil 1.

| Hex | What stands | Cover, winter | People | Spring | Summer | Autumn | Winter | Upkeep + walls | Notes |
|---|---|---|---|---|---|---|---|---|---|
| (8, 11) | wild | woods, frost | 2,500 | | | timber 1 | timber 1 | 0 | |
| (9, 11) | wild | woods, snow | 2,500 | | | timber 1 | | 0 | |
| (7, 12) | vineyard, second stage | farmland, frost | 8,000 | | | wine 24 | | 2 | keeps 25 % of the wild grain: 0 every season |
| (8, 12) | wild | woods, frost | 2,500 | | | timber 1 | timber 1 | 0 | |
| (9, 12) | wild (a pass) | woods, frost | 2,500 | | | timber 1 | timber 1 | 0 | |
| (10, 12) | wild | woods, snow | 2,500 | | | timber 1 | | 0 | |
| (6, 13) | Savona, town | farmland, frost | 10,000 | grain 1 | grain 3 | grain 2 | | 2 | keeps all its wild grain |
| (7, 13) | wild (a pass) | farmland, mild | 8,000 | grain 1 | grain 3 | grain 2 | grain 1 | 0 | |
| (8, 13) | Genoa, walled town, port | woods, mild | 30,000 | fish 6; dues 30 | fish 6; dues 33 | fish 6; dues 30 | fish 4; dues 21 | 2 + 4 | its wild timber at 75 %: 0 |
| (9, 13) | timber, second stage | woods, mild | 2,500 | timber 6 | timber 6 | timber 6 | timber 19 | 2 | Genoa's lift +10 %: 12 × 1.1 × 50 % = 6.6 → 6; winter 150 % → 19 |
| (10, 13) | wild | woods, mild | 2,500 | | | timber 1 | timber 1 | 0 | |
| (6, 14) | wild | rock, frost | 600 | | | | | 0 | |
| (7, 14) | olives, third stage | farmland, mild | 8,000 | | | oil 14 | oil 28 | 4 | 28 × 50 % and × 100 % |
| (5, 15) | wild | rock, mild | 600 | | | | | 0 | |

Every district is fully staffed (hands far above jobs).

| Season (turn) | Made | Used | Sold | Taxes on people | Taxes on goods | Port dues | Upkeep | Walls | Net | Treasury |
|---|---|---|---|---|---|---|---|---|---|---|
| Spring 1480 (1) | grain 2, fish 6, timber 6 | fish 4, oil 1, wine 1, salt 1 | grain 2, fish 2, timber 6 | 65 | 7 | 30 | −12 | −4 | **+86** | 610 → 696 |
| Summer 1480 (2) | grain 6, fish 6, timber 6 | the same | grain 6, fish 2, timber 6 | 65 | 9 | 33 | −12 | −4 | **+91** | → 787 |
| Autumn 1480 (3) | grain 4, fish 6, oil 14, wine 24, timber 12 | the same | grain 4, fish 2, oil 11, wine 21, timber 12 | 65 | 68 | 30 | −12 | −4 | **+147** | → 934 |
| Winter 1480 (4) | grain 1, fish 4, oil 28, timber 23 | the same | grain 1, oil 27, timber 23 | 65 | 64 | 21 | −12 | −4 | **+134** | → 1,068 |

Taxes on people: `(40,000 × 1,000 × 1,000 / 1,000 + 42,700 × 600) × 1,000 / 10^9 = 65.62 → 65`. Taxes on goods in
autumn: `(4 + 2 + 11 × 2.5 + 21 × 2.5 + 12) × 1,000 = 98,000` thousandths × 700 / 1,000,000 = 68.6 → 68. Salt runs out in
Winter 1480 (no land of Genoa can make it); from Spring 1481 salt's satisfaction is 0, contentment 900, the towns' factor
975, and taxes on people 64.

**(b) The report of Spring 1480 on the fixture**, the vineyard at (7, 12) begun that season:

| Section | Lines |
|---|---|
| At a glance | Treasury 658 ▲ +48 · Works 1 under way · Wine 3 ▼ −1 · Olive oil 3 ▼ −1 · Salt 3 ▼ −1 |
| Before Summer | Wine runs out in 4 seasons; the first vintage is Autumn 1481. [Go to (7, 12)] · Salt runs out in 4 seasons; none of your land makes it. [Show Genoa] · A work slot is free: 1 of 2 in use. [Show Genoa] |
| Treasury | 610 → 658 ▲ +48: Taxes on people ▲ +65 · Taxes on goods ▲ +7 · Port dues, Genoa ▲ +30 · District upkeep, 4 districts ▼ −10 · Walls of Genoa ▼ −4 · Work begun: vineyard, first stage, near Savona (7, 12) ▼ −40 · Left over each season ▲ +88; with your spending ▲ +48 |
| Goods | Fish 0 (caught 6, eaten 4, sold 2) · Grain 16 (made 3, sold 3) · Timber 40 (made 6, sold 6) · Wine 3 ▼ −1 (drunk 1) · Olive oil 3 ▼ −1 (used 1) · Salt 3 ▼ −1 (used 1) · Unchanged: stone, iron |
| Works | Begun: vineyard, first stage, near Savona (7, 12). Ready Spring 1481. |
| Your orders | Ordered to build: vineyard near Savona (7, 12). |
| Standing | Among the 3 countries you know, you are 3rd in land (14 districts) and 3rd in income (+88 a season). Savoy: about 58 districts, about +240. Milan: about 52 districts, about +260. |

The sums close: 65 + 7 + 30 − 10 − 4 − 40 = 48 = 658 − 610; wine 4 − 1 = 3.

**(c) The vineyard card (the mockup's `works_vineyard.jpg`)**, the fixture in Spring 1480, "Build vineyard" at (7, 12):

| Field | Before → after |
|---|---|
| Title, subtitle | "Vineyard, first stage"; "near Savona (7, 12) · farmland, 665 m · frost winter · a river on the W edge" |
| Brings (a year) | Wine 0 → 12 ▲ +12 · Grain 6 → 2 ▼ −4 · Jobs 0 → 1,000 · Upkeep, a season 0 → 1 ▼ −1 |
| Each season (Spring gilt) | Spring: grain 1 → 0, ▼ −2 · Summer: grain 3 → 1, ▼ −3 · Autumn: wine 0 → 12, grain 2 → 1, ▲ +28 · Winter: "frost: nothing grows", ▼ −1 |
| Where it lands | This district, a year 6 → 32 ▲ +26 · Upkeep ▼ −4 · Ring of six: nothing changes · Country, a year 511 → 533 ▲ +22 |
| Country gain, a season (chart) | Spring 96 → 94 · Summer 105 → 102 · Autumn 140 → 168 · Winter 170 → 169 |
| Cost and time | "40 ducats · 4 seasons · ready Spring 1481 · first vintage Autumn 1481"; ✓ farmland or meadow, 100–900 m, no snow winter ✓ a free work slot: 0 of 2 in use ✓ 40 of 610 ducats |
| Payback | "Pays back in Autumn 1482, 10 seasons from now (at today's prices)." Treasury only: +10 a year (Spring 87 · Summer 93 · Autumn 128 · Winter 135 against 88 · 95 · 114 · 136), "Autumn 1484, 18 seasons from now" |
| Next | "Stage 2 possible (Savona (6, 13) 1 hex away); stage 3 possible (a town within two hexes, under 1,200 m)." |
| Expensive | no (40 is under a quarter of 610; 4 seasons) |

**(d) Genoa, walled town to city (seed 1480, Spring 1480; the mockup's `works_genoa.jpg`)**: refused for money, so the card
shows everything with its refusal bar.

| Field | Before → after |
|---|---|
| Verdict | "not enough ducats: 1,000 needed, 610 in the treasury" (`blocked_by` ducats); from Spring 1481 (1,068) it can begin |
| Brings (a season) | People 30,000 → 60,000 · Taxes on people (the country) 65 → 95 ▲ +30 · Port dues 30 → 45 ▲ +15 (spring) · Fish 6 → 10 · Towns' food 4 → 7 a season · Upkeep and walls 6 → 11 ▼ −5 |
| Each season | gain ▲ +45, +46, +45, +40 ("port dues 30 % lower" in winter) |
| Where it lands | This district: dues and fish; Ring of six: "timber near Genoa (9, 13): +1 a season, +2 in winter (the city's market)" · Country, a year 557 → 733 ▲ +176 |
| Treasury only | +40, +39, +26, +36 = +141 a year (a city keeps a larger reserve of grain and wine, so less is sold) |
| Cost | 1,000 ducats · 20 timber · 40 stone · 8 seasons · ready Spring 1482 if begun now; ✓ no other town beside it, no castle against its wall ✓ a free work slot ✗ 1,000 of 610 ducats ✓ 20 of 40 timber ✓ 40 of 40 stone |
| Payback | realm: Spring 1488, 32 seasons from now; treasury only: Summer 1489, 37 seasons |
| Next | "None: Genoa is at its top level." |
| Expensive | yes |

**(e) Savona, town to walled town**: refused by a rule (`blocked_by` rule): only the refusal. `Works.upgrade_check` row 5
gives M1's words, "a town needs its own countryside: no two towns side by side (settlements 3 at 5, 13)"; the card shows
`reason_words`: **"Cuneo (5, 13) is a town beside Savona: two towns may not stand side by side."**

### 4.16 The mockup's numbers against these tables

The mockup's figures were examples (`game-feedback-screens.md` says so). What M4 reproduces, and what replaces the rest:

| Screen | Reproduced exactly | Replaced (by) |
|---|---|---|
| `works_vineyard.jpg` | Brings wine 0 → 12, grain 6 → 2, upkeep −4 a year; the four cells (wine 0 > 0, 0 > 0, 0 > 12; grain 1 > 0, 3 > 1, 2 > 1; "frost: nothing grows"; −2, −3, +28, −1); this district 6 → 32 ▲ +26; country ▲ +22 a year; cost, ready date, first vintage; payback Autumn 1482, 10 seasons; next stages | Country 658 → 680 and the chart's 164 → 162 ... (4.15 c: 511 → 533); the neighbour line "Savona buys the wine: price 2.8 → 2.5" (prices react in M10; M4's ring lines are staffing and lift); "work slot 1 of 2" (M3's words "0 of 2 in use") |
| `works_genoa.jpg` | Upkeep 6 → 11; "port dues 30 % lower" in winter; "Next stage: none" | People room 70,000 → 100,000 (30,000 → 60,000); taxes 38 → 52 (the country's 65 → 95); jobs for burghers (settlements have no jobs until M5); sight and market reach (M6, M10: hidden); gains +9 a season (+45, +46, +45, +40); 600 ducats (1,000); requirements "highway", "food to spare" (not rules); payback 67 seasons and "a prestige work" (32 seasons) |
| `report_m4.jpg` | The section order, the line kinds, the vineyard −40, the slot notice | 1,154 → 1,240 ▲ +86 and every line (4.15 b); "31 districts" (Genoa has 14 land hexes, 4 with upkeep); "Walls of Genoa and Savona" (Savona has no walls); Grain 320, Fish 64, Wine 41 (the stores keep a reserve of a few seasons: grain 16) |
| `study_econ.jpg` | The layout and the line kinds | +151, −25, +126, +131 (4.15 b's +102, −14, +88; expected +95 in Summer); the chart's 1478 to 1480 seasons (no history before the game starts: the chart shows the seasons played); "Polcevera woods +4" (Earns most from 4.17's worth) |
| `play_m4.jpg` | Ducats chip with change | Grain chip (M5), Prestige chip (M12); values (Ducats 658 ▲ +48, Stores) |

`design.md` 6a and `game-feedback-screens.md` B.4, B.5 and C.3 get a line pointing here (section 11).

### 4.17 Previews

**`EconomyPreview.with(game, tag, changes, seasons)`** is the one what-if (the card, the tax hover, "Expected this season",
the money notices). It starts at `game.turn`, from the country's stock and tax level now, with calm weather, and runs
`seasons` seasons of the country's `production` and `income` exactly as the phases do (the same functions of
`Economy` and `EconomySeason`), with:

- the country's **works under way** standing from their `WorksView.ready_turn` (a clear removes its piece then);
- `changes.hexes` (`hex index -> Vector2i(main_use, level)`) standing from the first season;
- `changes.tax` (−1: keep) from the first season.

It never writes the game. **Delta method:** the country's hexes' outputs for the seasons asked are computed once a
version (`view_cache` key `[&"made", game.version, tag, turn, seasons]`) from `DistrictCache`; a change re-runs
`district_output` on its hex and six neighbours for each season (28 runs for four seasons) and replaces those hexes'
part; the country step (needs, sales, money) then runs whole for each season (a few dozen integer steps).

**Two measures** (D29): **realm** = goods made at price + taxes on people + port dues − upkeep − walls; **treasury** = the
money lines' sum (taxes on people, taxes on goods sold, dues, upkeep, walls). A hex's **worth** (D34) for a season = its
goods at price + its dues + its people's taxes (`people × rate × factor` for a town, `people × country rate` otherwise,
at the country's level) − its upkeep and walls, floored per hex.

**`ImprovePreview.of(game, tag, hex, option)`** (`option = {action, family}`; cached in `view_cache` by
`[&"preview", game.version, tag, hex, action, family, treasury_only]`) gives the style spec's 7.1 dictionary with:

| Field | M4 content |
|---|---|
| `verdict` | `game.check(action, args)` itself |
| `blocked_by` | `&""` when ok; `&"slot"`, `&"ducats"` or `&"goods"` when the first refusal is row 7, 8 or 9 (the card shows everything with a refusal bar); `&"rule"` for any other row (the card shows only the refusal) |
| `reason_words` | a pair-rule refusal (row 5's pair rules, through `WorldImprove.conflict`; row 6's work under way as the other place) takes `ImproveRules.PAIR_WORDS` (4.15 e); every other refusal is the verdict's words with a capital and a full stop |
| `cost` | `Works.cost_of`, `WorksView.seasons_of`, `ready_turn` (`WorksView.ready_turn_of`), `first_yield_turn` (the first season from the ready turn when the family's good is made), `text` |
| `requirements` | ground (`FamilyDef.ground_text`, ok by `cell_allowed`); reach for stages 2 and 3; one line per pair rule that concerns the option's family and level (`ImproveRules.PAIR_NEEDS`, ok when `WorldImprove.conflict` finds no break of it); "a free work slot: n of m in use"; "n of m ducats"; per good "n of m <good>" |
| `brings` | goods districts: each good of the hex a year, jobs, upkeep a season; settlements: people, taxes on people (the country), port dues, fish, towns' food, upkeep and walls, a season; castles: walls and "Its worth shows in war." |
| `by_season` | four cells, the calendar's order, `now` the current season: the hex's goods before → after, a note (winter "frost: nothing grows" / "snow: nothing grows" when all are 0; "port dues 30 % lower" for a port), the country's measure before and after, and `gain` (the hex's realm change, including its people's taxes for a town) |
| `lands` | district (its goods' worth a year, before → after), upkeep (the year's change), ring lines (staffing or lift that changed; another country's hex only when `Knowledge.knows`, its amount outside the totals: "Also changes Savoy's district at (5, 13)"), country a year |
| `payback` | D31; `prestige` true when never |
| `next_stages` | each higher level: ok by the cell rule and the pair rules against today's neighbours, with the words of 4.15 c |
| `chips` | up to three: the main good a year ("wine +12 a year"), the gain a year ("+22 a year", or the treasury's with the switch), and for a town its people ("people +30,000") |
| `expensive` | D32 |
| `map_marks` | the hex and each ring hex whose year changes: `{delta (realm, a year), label ("+12 wine", "+5 timber")}` |
| `ghost` | `{hex, tiles: MapCells.piece_cells(map, Improve.piece_for(map, hex, family, level), hex)}` |

A map-only game: the money fields are empty and `cost.text` is "4 seasons".

### 4.18 Reminders after M4

`Reminders.RULES`: `treasury_empty`, `goods_running_out`, `winter_halt` (M3), `treasury_falling`, `free_slot` (M3); lines worst
first (severity, then this order).

| Rule | When | Severity | Text | Action |
|---|---|---|---|---|
| `treasury_empty` | the treasury is under 0 | 2 | "The treasury is empty: 120 ducats owed. Upkeep is still paid; no work can begin." | `[&"study", &"economy"]`, "Open the study" |
| `goods_running_out` | `EconomyPreview.with(game, tag, {}, 8)` finds a need (food, wine, salt, oil, in that order; one line each) not fully met in season k (1 to 8) | 2 for food with k ≤ 2; else 1 | "Wine runs out in 4 seasons; the first vintage is Autumn 1481." / "Salt runs out in 4 seasons; none of your land makes it." / "Food runs out next season." (`GoodDef.harvest_word`: grain "harvest", fish "catch", oil "olive harvest", wine "vintage", salt "salt season") | `[&"look_at", hex]` of the first district or work under way that makes it in the window ("Go to (7, 12)"), else the capital ("Show Genoa") |
| `treasury_falling` | the treasury is 0 or more and "Expected this season" is below 0 | 1 | "The treasury will fall by 12 ducats this season." | `[&"study", &"economy"]` |

### 4.19 The season report after M4

`SeasonSummary.of` fills the three sections M3 left to M4 and the money parts of the others (the style spec's 6.4 shape;
`sub` lines are not counted in a section's sum):

| Id | M4 content |
|---|---|
| `glance` | Treasury (the closing value, the change) first; then M3's Works and Land; then up to three goods with the largest `|change| × price`; a Weather chip for the season that begins, `Calendar.weather_text` when it is not empty; at most five |
| `before` | M3's and 4.18's lines, at most five |
| `treasury` | `total` "610 → 658" (from, to, amount); a line per closed-ledger line: "Taxes on people", "Taxes on goods", "Port dues, Genoa", "District upkeep, 4 districts", "Walls of Genoa" (walls lines merged into one with `Words.list`), "Work begun: <label, place>" (the label from the chronicle's `work_started` of that turn and hex), "Refund: <label>", "Developer"; then two `sub` lines "Left over each season" and "With your spending". Rank = `|amount|` |
| `goods` | a line per good with a flow or a change: the good's name, `value` the closing stock, `amount` the change, `detail` "(made 3, sold 3)" with the words caught (fish), eaten (food), drunk (wine), used, sold, for works, back from works; rank `|change| × price`, then the flows' worth; `unchanged` "Unchanged: stone, iron" |
| `works` | M3's lines; a finished one gains `detail` "Brings wine 12 a year; upkeep 1 a season." (from `district_output` on the state now) |
| `orders` | M3's, plus "Set taxes to High." (the action log's `set_tax`) |
| `befell` | M3's, plus known others' `tax_set` |
| `standing` | one line "Among the n countries you know, you are k-th in land (14 districts) and k-th in income (+88 a season)." (income: the closed ledger's lines but `work`, `refund` and `dev`); then one muted line a known country, banded: "Milan: about 52 districts, about +260." (`Knowledge.band`) |

`swing_permille` = `|closing − opening| × 1000 / max(1, |opening|)`. `toast`: "Spring 1480 ended: ▲ +48 ducats. J: the report".
**Quiet** (M3's rule, plus): the treasury's change under 2 % of the opening and no good's stock change of 2 % or more;
its one line: "The treasury grew by 88 ducats; nothing else of note." `SeasonSummary.COVERED` gains `goods_short`.
`tests/fixtures/report_sample.gd` (M3) is rebuilt from 4.15 b's summary, the People section staying a fixture until M5.

### 4.20 Stats after M4

`StatsSystem.season` writes, per country, the M4 series of M3's 4.6: `treasury` (closing), `income_people`, `income_goods`,
`income_dues` (the closed ledger's sums), `upkeep_districts`, `upkeep_walls` (as positive ducats), `spending` (work less
refunds, positive), `people` (the M4 table's total), `food_made` and `food_eaten` (grain and fish). `income_trade`,
`upkeep_army` stay 0 (M10, M6). `Stats.create` takes `goods = defs.goods.size()` (16); `goods_ring` holds made, used and
the closing stock per good. Then it calls `Treasury.close_ledger` and `Stores.close`.

### 4.21 Events, the chronicle, the log

| Kind | Fields (besides `kind`, `turn`) | Emitted by | Notable | Typed signal | Heard by |
|---|---|---|---|---|---|
| `goods_short` | `tag`, `good` (`&"food"`, `&"wine"`, `&"salt"`, `&"oil"`), `need`, `taken`, `witnesses: [tag]` | `EconomySeason.production` (4.7) | yes | `goods_short(tag, good)` | chips, task flag; log (Money, Mine), notifications |
| `tax_set` | `tag`, `level`, `from` | `EconomySeason.set_tax` | yes | `tax_set(tag, level)` | chips, study page, country panel; log (Money, Mine) |

Money is state, not an event (game feedback D.2). `LogLines` lines:

| Kind | The player's line | A known other's |
|---|---|---|
| `goods_short` | "Your towns ran short of salt: 0 of 1." keyword "Short", tone bad, filters all, money, mine; `notify` true | (never witnessed) |
| `tax_set` | "You set taxes to High." keyword "Taxes", plain, filters all, money, mine | "Milan set taxes to High." muted, all, money |
| `work_started` (M3) with `paid` > 0 | adds " (−40 ducats)"; filters add money; the ribbon reads "Begun −40" | |
| `work_cancelled` (M3) with `refund` > 0 | adds " (+40 ducats back)"; filters add money | |

`LogLines.FILTERS`' Money (`since: "4"`) shows from M4.

### 4.22 Saves and the digest

| Body key | M4 adds | In `Game.digest()` |
|---|---|---|
| `format` | 2 (`SaveFile.FORMAT`; `OLDEST_FORMAT` 2) | no |
| `game` | `weather` (3 bytes) | yes |
| `countries` | `country/2`: `treasury`, `tax`, `ledger_open`, `ledger_from`, `ledger_closed`, `stock`, `flows_open`, `stock_from`, `goods_closed` | each `digest_text()` |
| `map_state` | its works are `work/2` (`paid_goods`) | `MapState.digest()` (each `Work.digest_text()`) |
| `stats` | `goods` 16 and the goods ring | `Stats.digest()` |
| (not saved) | `DistrictCache` (rebuilt on first use) | no |

`Game.digest()` after M4: M3's string with `weather` (as `"s,f,m"`) after `turn`. Sizes on the fake Europe with 60
countries: about 2 KB a country (stocks, flows, two ledgers of about ten lines): 0.12 MB, inside M3's 8 MB.

### 4.23 The style spec's six requirements (7.3), answered

| # | Requirement | Answer |
|---|---|---|
| 1 | A season profile per family and winter slot as data | **Yes**: `FamilyDef.season_percent`, six whole percents (in each family's file, not a separate one: 1.2) |
| 2 | Stocks carry goods across seasons | **Yes**: the stores and their reserve (4.8) |
| 3 | `district_output` is a pure function of the map, a `StateView`, the hex, the season and the definitions; luck only through `weather` (calm in previews) | **Yes**, with the tax level as one more explicit argument (1.2) |
| 4 | Ring effects are terms of `district_output` over the ring, nowhere else | **Yes**: staffing and the town's lift (4.5) |
| 5 | Prices are a function of supply, in whole thousandths | **Yes in form**: `market_prices(game, view, market, supply)` gives whole thousandths; in M4 its body is the fixed table and reads no supply; M10 writes the body (D2) |
| 6 | Works in `MapState` with their fields and a slot count; every cost through `Treasury.move` | **Yes**: M3's `Work` plus `paid_goods`; goods through `Stores.move` |

No answer is "no" on 1 or 2: the style spec's assumed decision 2 stands.

---
## 5. Interfaces

Layers as the standard: `defs`, `state`, `systems`, `game`, `views`, `shell`. `core/` makes no engine calls; its only luck
is the weather draw through `Rng`. New files are marked **new**; "(M2)", "(M3)" and "(M1.5)" name pieces those milestones
build. Every amount is an `int`.

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/good_def.gd  (new)
class_name GoodDef extends Resource
const KINDS: Array[StringName] = [&"food", &"staple", &"ware", &"material"]
@export var id: int                       # 0 to 15: its place in GameDefs.goods and in every per-good array
@export var key: StringName               # &"wine"
@export var name: String                  # "Wine"
@export var kind: StringName              # one of KINDS
@export var price_milli: int              # the fixed price, thousandths of a ducat (M10 makes prices react)
@export var need_milli: int = 0           # staples: loads a season per 1,000 town people, in thousandths; food: 0 (GameDefs)
@export var need_weight: int = 0          # staples: permille of contentment; food: 0 (GameDefs.food_weight)
@export var food_order: int = -1          # food: the order it is eaten (fish 0, grain 1); -1 otherwise
@export var reserve_fixed: int = 0        # materials: loads always kept (timber 40, stone 40, iron 20)
@export var harvest_word: String = ""     # "vintage", "harvest", "catch", "olive harvest", "salt season"
@export var icon: StringName              # the Kit icon (6.2): &"good_wine"
func validate() -> Array[String]          # key form; kind known; price_milli > 0; need_milli >= 0; weights 0..1000;
	# food goods have food_order >= 0 and no need_milli; icon not empty

# core/defs/family_def.gd  (M3, edit): the economy's numbers beside work_seasons
@export var good: StringName = &""                       # the good it makes; &"" for settlements, castles, grazing, mines
@export var by_extra: Dictionary[String, StringName] = {} # grazing {sheep: wool, cattle: cattle, horses: horses}; mines
	# {iron: iron, copper: copper, silver: silver}: Improve.piece_of's extra -> good
@export var extra_permille: Dictionary[String, int] = {}  # grazing {sheep 1000, cattle 750, horses 375}; mines {iron 1000,
	# copper 750, silver 250}
@export var base: PackedInt32Array            # per level, [0] = 0: loads a season at 100 %
@export var season_percent: PackedInt32Array  # 6: spring, summer, autumn, winter snow, winter frost, winter mild
@export var weather_bound := false
@export var keep_wild: PackedInt32Array       # per level: percent of the hex's wild yield kept
@export var jobs: PackedInt32Array            # per level: people needed at full output
@export var upkeep: PackedInt32Array          # per level: ducats a season
@export var walls: PackedInt32Array           # per level: ducats a season (settlements 4 and 5, castles)
@export var cost: PackedInt32Array            # per level reached: ducats ([0] and settlements' [1] are 0)
@export var cost_goods: Array[Dictionary] = []  # per level reached: {good key (String): loads}
@export var ground_text: String = ""          # the card's ground line (4.4); "" for settlements and castles
@export var people: PackedInt32Array          # settlements: per level; empty otherwise
@export var ring_lift: PackedInt32Array       # settlements: per level, permille
@export var port_fish: PackedInt32Array       # settlements: per level, loads a season at 100 %
@export var port_dues: PackedInt32Array       # settlements: per level, ducats a season at 100 %
# validate() adds: every per-level array has TOP_LEVEL[id] + 1 entries; season_percent has 6 in 0..400; keep_wild 0..100;
# a goods family has good or by_extra (each value a known good key, each extra in ImproveRules.ANIMALS or ORES) and base
# > 0 from level 1; cost_goods keys are known goods; settlement arrays only on settlements

# core/defs/game_defs.gd  (M2, M3; edit)
@export var goods: Array[GoodDef] = []              # 16, external, in id order
@export var wild_good: Array[StringName] = []       # per cover (8): &"grain", &"grain", &"timber", &"", &"", &"", &"", &""
@export var wild_yield: PackedInt32Array            # 8 covers x 6 slots (4.4)
@export var country_people: PackedInt32Array        # per cover (8): 8000, 5000, 2500, 1500, 600, 0, 0, 1500
@export var hands_permille := 300
@export var food_need_milli := 100
@export var food_weight := 700
@export var content_floor := 750
@export var reserve_seasons := 4
@export var town_tax_milli := 1000
@export var country_tax_milli := 600
@export var tax_permille: PackedInt32Array          # 700, 1000, 1400
@export var goods_share_permille: PackedInt32Array  # 500, 700, 900
@export var output_permille: PackedInt32Array       # 1050, 1000, 900
@export var port_dues_percent: PackedInt32Array     # 6 slots: 100, 110, 100, 70, 70, 70
@export var fishing_percent: PackedInt32Array       # 6 slots: 100, 100, 100, 30, 50, 70
@export var start_treasury_base := 200
@export var start_treasury_per_1000 := 5
@export var weather_odds: PackedInt32Array          # calm, good, poor in percent: 60, 20, 20
@export var weather_permille: PackedInt32Array      # 1000, 1200, 750
@export var expensive_permille := 250
@export var expensive_seasons := 8
func good(id: int) -> GoodDef                       # null when out of range
func good_id(key: StringName) -> int                # -1 when unknown (a dictionary built on first use)
# validate() adds: 16 goods with ids 0..15 once each, in order; the four weights add to 1000; arrays sized (8, 48, 3, 6);
# weather_odds add to 100; every FamilyDef's goods are known
```

### 5.2 State (`core/state/`)

```gdscript
# core/state/state_view.gd  (new): MapState plus a what-if overlay (style spec 7.2)
class_name StateView extends RefCounted
static func of(state: MapState) -> StateView
func with(changes: Dictionary) -> StateView         # hex index -> Vector2i(main_use, level); a new view, the base untouched
func main_use_at(i: int) -> int
func level_at(i: int) -> int
func changed() -> PackedInt32Array                  # the overlay's hex indices, ascending

# core/state/country.gd  (M2, edit): schema "hexa-godot/country/2" (country/1 is refused: D38)
var treasury: int = 0                    # Treasury
var ledger_open: Array[Dictionary] = []  # Treasury: {why: StringName, hex: Vector2i, amount: int, count: int, spending: bool}
var ledger_from: int = 0                 # Treasury: the treasury when ledger_open was opened
var ledger_closed: Dictionary = {}       # Treasury: {turn, opening, closing, lines}
var tax: int = 1                         # EconomySeason: 0 Low, 1 Normal, 2 High
var stock: PackedInt32Array              # Stores: per good id
var flows_open: PackedInt32Array         # Stores: [good * Stores.FLOWS.size() + flow], signed
var stock_from: PackedInt32Array         # Stores: the stock when flows_open was opened
var goods_closed: Dictionary = {}        # Stores: {turn, opening: PackedInt32Array, closing, flows}
# to_dict / from_dict carry every field (StringName as String; packed arrays as they are); digest_text() appends
# "|treasury|tax|ledger_from|" + each open line "why:c,r:amount:count" + "|" + the closed ledger + "|" + stock, flows_open,
# stock_from as comma lists + "|" + goods_closed

# core/state/work.gd  (M3, edit): schema "hexa-godot/work/2"
var paid_goods: Dictionary = {}          # good key (String) -> loads paid when begun; work/1 loads with {}
# to_dict adds paid_goods; digest_text adds "|good:n,good:n" in good id order

# core/game/game.gd  (M3, edit; fields below)
var weather: PackedByteArray = PackedByteArray([0, 0, 0])   # Calendar: per climate (snow, frost, mild): 0 calm, 1 good, 2 poor
var districts: DistrictCache = DistrictCache.new()           # the door's derived cache; not saved, not in the digest
```

### 5.3 Systems (`core/systems/`)

```gdscript
# core/systems/economy.gd  (new): the pure rules of one hex and the prices; writes nothing
class_name Economy extends RefCounted
const OWNS: Array[String] = []
const CALM := 0
const GOOD := 1
const POOR := 2
const NO_MARKET := -1
static func slot_of(map: MapData, hex: Vector2i, season: int) -> int        # 0..2, or 3 + climate in winter
static func people_at(game: Game, view: StateView, hex: Vector2i) -> int    # 4.3; M5 reads state.people here
static func hands_at(game: Game, view: StateView, hex: Vector2i) -> int     # 4.3
static func jobs_near(game: Game, view: StateView, hex: Vector2i) -> int    # 4.5
static func staffing(game: Game, view: StateView, hex: Vector2i) -> int     # permille, 4.5
static func lift_at(game: Game, view: StateView, hex: Vector2i) -> int      # permille, 4.5
static func good_of(game: Game, view: StateView, hex: Vector2i) -> int      # the district's good id, -1 none
static func district_base(game: Game, view: StateView, hex: Vector2i) -> Dictionary
	# the season-free part: {family, level, good, a0 (thousandths), keep, cover, wild_good, weather_bound, port_level (0 none),
	#  upkeep, walls, jobs, room (people), staffing, lift}
static func season_output(base: Dictionary, map_climate: int, season: int, weather: int, tax: int, defs: GameDefs) -> Dictionary
	# applies the slot's percent, the tax's output, the weather: {goods: PackedInt32Array (16), ducats, upkeep, walls}
static func district_output(game: Game, view: StateView, hex: Vector2i, season: int, weather: int = CALM, tax: int = -1) -> Dictionary
	# = season_output(district_base(...)) merged: {goods: PackedInt32Array by good id, ducats (port dues), upkeep, walls,
	#  jobs, room, staffing, lift, good, wild}; tax -1: the owner's level (Normal on unowned land)
static func market_of(game: Game, tag: StringName) -> int                   # M4: the country's id (NO_MARKET for &"")
static func market_prices(game: Game, view: StateView, market: int, supply: PackedInt32Array) -> PackedInt32Array
	# whole thousandths by good id; M4: GoodDef.price_milli, reading neither market nor supply (the M10 seam)

# core/systems/economy_season.gd  (new): a country's season, the two phases and the tax pair
class_name EconomySeason extends RefCounted
const OWNS: Array[String] = ["tax"]
const NEEDS: Array[StringName] = [&"food", &"wine", &"salt", &"oil"]
static func town_people(game: Game, view: StateView, tag: StringName) -> int
static func country_people(game: Game, view: StateView, tag: StringName) -> int
static func needs_of(game: Game, view: StateView, tag: StringName) -> Dictionary      # {food, wine, salt, oil}: loads a season
static func reserve_of(game: Game, view: StateView, tag: StringName) -> PackedInt32Array   # per good id (4.2)
static func made_of(game: Game, view: StateView, tag: StringName, season: int, weather: PackedByteArray, tax: int) -> Dictionary
	# {made: PackedInt32Array, dues: Array[Dictionary] {hex, amount}, upkeep: int, upkeep_count: int,
	#  walls: Array[Dictionary] {hex, amount}}; from DistrictCache when view is the game's own, else district_output
static func goods_step(game: Game, needs: Dictionary, reserve: PackedInt32Array, stock: PackedInt32Array, made: PackedInt32Array) -> Dictionary
	# pure (4.7, 4.8): {used: PackedInt32Array, sold: PackedInt32Array, stock: PackedInt32Array, taken: Dictionary,
	#  satisfaction: Dictionary, content: int}
static func content_of(game: Game, needs: Dictionary, used: PackedInt32Array) -> int  # the same content from used goods
static func money_lines(game: Game, view: StateView, tag: StringName, tax: int, content: int, sold: PackedInt32Array, made_info: Dictionary) -> Array[Dictionary]
	# pure (4.9): [{why, hex, amount, count}] in the order of 4.9; zero lines left out
static func production(game: Game) -> void    # the phase: per country, made_of, goods_step, Stores.move made/used/sold; goods_short
static func income(game: Game) -> void        # the phase: per country, content_of(flows_open), money_lines, Treasury.move each line
static func set_tax_check(game: Game, args: Dictionary) -> Dictionary   # {level, tag}; 4.10
static func set_tax(game: Game, args: Dictionary) -> Dictionary         # writes Country.tax; emits tax_set
static func debt_limit(game: Game, tag: StringName) -> int              # 0 in M4 (M12)

# core/systems/treasury.gd  (new)
class_name Treasury extends RefCounted
const OWNS: Array[String] = ["treasury", "ledger_open", "ledger_from", "ledger_closed"]
const NO_HEX := Vector2i(-1, -1)
const WHY: Array[StringName] = [&"tax_people", &"tax_goods", &"port_dues", &"upkeep_districts", &"upkeep_walls", &"work",
	&"refund", &"dev"]                      # append-only; M6 army, M10 trade, M12 interest
const SPENDING: Array[StringName] = [&"work", &"refund"]
static func setup(game: Game) -> void      # 4.12: each country's start treasury; ledger_from; empty ledgers
static func start_amount(game: Game, tag: StringName) -> int
static func move(game: Game, tag: StringName, amount: int, why: StringName, hex: Vector2i = NO_HEX, count: int = 1) -> bool
	# THE ONLY WRITER OF A TREASURY. false (and nothing changes) for an unknown tag or a why not in WHY; amount 0 adds no
	# line; else treasury += amount and the line (why, hex) gains amount and count (a new line keeps first-added order)
static func close_ledger(game: Game) -> void   # every country: ledger_closed = {turn, opening: ledger_from, closing: treasury,
	# lines: ledger_open}; ledger_open = []; ledger_from = treasury
static func can_pay(game: Game, tag: StringName, ducats: int) -> bool    # treasury >= ducats
static func left_over(lines: Array[Dictionary]) -> int                    # the lines' sum but SPENDING and dev

# core/systems/stores.gd  (new)
class_name Stores extends RefCounted
const OWNS: Array[String] = ["stock", "flows_open", "stock_from", "goods_closed"]
const FLOWS: Array[StringName] = [&"made", &"used", &"sold", &"work", &"refund", &"dev"]
static func setup(game: Game) -> void      # 4.12: stock = EconomySeason.reserve_of(...); flows zero; stock_from = stock
static func move(game: Game, tag: StringName, good: int, amount: int, why: StringName) -> bool
	# THE ONLY WRITER OF A STOCK. false (nothing changes) for an unknown tag or good, a why not in FLOWS, or a stock that would
	# fall below 0; else stock[good] += amount and flows_open[good * F + flow] += amount
static func close(game: Game) -> void      # every country: goods_closed = {turn, opening: stock_from, closing: stock, flows:
	# flows_open}; flows_open zero; stock_from = stock
static func short_of(game: Game, tag: StringName, goods: Dictionary) -> String
	# "" or "not enough stone: 40 needed, 12 in store" (the first short good in id order)
static func flow(country: Country, good: int, why: StringName, closed: bool = false) -> int

# core/systems/works.gd  (M3, edit)
static func cost_of(game: Game, action: StringName, family: int, level_to: int) -> Dictionary   # {ducats, goods: {key: n}}; 4.11
static func refund_goods(game: Game, work: Work) -> Dictionary   # work.paid_goods when started_turn == turn, else {}
# build_check, upgrade_check, clear_check: rows 8 and 9 (4.11); build, upgrade, clear: pay and set paid, paid_goods;
# cancel_work: Treasury.move(refund) and Stores.move(refund goods). OWNS unchanged (works, next_work_id)

# core/systems/calendar.gd  (M3, edit)
const OWNS: Array[String] = ["turn", "weather"]
static func draw_weather(game: Game) -> void    # 4.6; called by season() after turn += 1
static func weather_text(game: Game, tag: StringName) -> String    # 4.6; "" when the land of tag is all calm

# core/systems/stats_system.gd  (M3, edit): the M4 values of 4.20; then Treasury.close_ledger(game) and Stores.close(game)

# core/systems/improve.gd  (M1, edit)
static func piece_for(map: MapData, hex: Vector2i, family_id: int, level_value: int) -> Dictionary
	# what piece_of would give for this family and level on this hex (the card's ghost); {} for family 0

# core/systems/world_improve.gd  (M1, edit)
func conflict(hex: Vector2i, family_id: int, level_value: int) -> Dictionary
	# {} or {rule: int (index in ImproveRules.PAIR_RULES), hex: Vector2i, family: int, level: int}: the first pair rule broken,
	# in the order _pair_conflict walks; _pair_conflict builds its string from it (its words unchanged)

# core/systems/improve_rules.gd  (M1, edit)
const PAIR_WORDS: Array[String] = [...]   # one per PAIR_RULES entry, two %s: the other hex (Words.place) and this one (its
	# place's name when it is a named place, else "this district"):
	# [0] "%s is a town beside %s: two towns may not stand side by side."
	# [1] "%s holds the area round %s: no castle within two hexes of another."
	# [2] "%s is a third stage beside %s: two third stages never touch."
	# [3] "%s is a mine beside %s: one mining district a valley."
	# [4] "%s is a quarry beside %s: one quarry a hill."
	# [5] "%s is a mine or quarry beside %s: the two are kept apart."
	# [6] "%s has salt pans beside %s: salt pans are a special shore."
	# [7] "%s has a fishing harbour beside %s: harbours are spaced along the shore."
	# [8] "%s has a dye works within two hexes of %s: one dye works a town."
	# [9] "%s is a dye works or salt pans beside %s: the two are kept apart."
	# [10] "%s is silk or olives beside %s: the two groves are kept apart."
	# [11] "%s is grown silk beside %s: silk is a town's luxury."
	# [12] "%s is a walled town or castle beside %s: no castle against a town's wall."
const PAIR_NEEDS: Array[String] = [...]   # one short requirement per PAIR_RULES entry, for the card's ticks: "no other town
	# beside it", "no other castle within two hexes", "no other third stage beside it", "no other mine beside it", "no other
	# quarry beside it", "no mine or quarry beside it", "no other salt pans beside it", "no other fishing harbour beside
	# it", "no other dye works within two hexes", "no dye works or salt pans beside it", "no silk or olives beside it", "no
	# other grown silk beside it", "no castle against a town's wall"
```

**OWNS after M4** (`tests/core/test_owns.gd` diffs `Snapshot.of` around every action and phase):

| Field | Written by | In an action | In a phase |
|---|---|---|---|
| `treasury`, `ledger_open`, `ledger_from`, `ledger_closed` | `Treasury` | `build`, `upgrade`, `clear`, `cancel_work` (works' `work`, `refund`); `Game.dev_money` | `income`; `stats` (`close_ledger`) |
| `stock`, `flows_open`, `stock_from`, `goods_closed` | `Stores` | `build`, `upgrade`, `clear`, `cancel_work`; `Game.dev_goods` | `production`; `stats` (`close`) |
| `tax` | `EconomySeason` | `set_tax` | no |
| `turn`, `weather` | `Calendar` | no | `calendar` |
| M3's fields (`main_use`, `level`, `owner`, `works`, `next_work_id`, `countries`, `player`, `stats`) | as M3 5.7 | | `works` now runs after `income` |
| `events`, `action_log`, `chronicle`, `version`, `view_cache`, `districts` | `Game` (the door; `DOOR_FIELDS` gains `districts`) | yes | yes |
| `luck` | drawn only through `Rng` (the weather) | | `calendar` |

### 5.4 Game, the action table, the season (`core/game/`; and the cache)

```gdscript
# core/systems/district_cache.gd  (new; a systems file because it calls Economy, and Game holds it): the season-free
#   part of district_output for every land hex
class_name DistrictCache extends RefCounted
const FIELDS := 15                                  # the ints of district_base a hex, in its order
var _ints: PackedInt32Array                         # FIELDS a land hex (about 4 MB on Europe); a byte array marks the fresh ones
func base_of(game: Game, i: int) -> Dictionary     # Economy.district_base of hex index i on StateView.of(game.state),
	# computed on first use, kept as ints until touched, returned as the same dictionary
func touch(game: Game, hex: Vector2i) -> void       # forget the hex and its six neighbours
func clear() -> void
func size() -> int                                   # hexes held (F3)

# core/game/game.gd  (M3, edit)
const DOOR_FIELDS: Array[String] = ["events", "action_log", "chronicle", "version", "view_cache", "districts"]
func emit(event: Dictionary) -> void        # M3's, plus: a "hex_changed" event calls districts.touch(event.hex)
func dev_money(tag: StringName, amount: int) -> bool        # Treasury.move(..., &"dev"); action log {turn, action:
	# "dev_money", args: {tag, amount}}; false in a map-only game
func dev_goods(tag: StringName, good: int, amount: int) -> bool   # Stores.move(..., &"dev"); action log "dev_goods"
# new_scenario: after Countries.setup and Territory.setup: Treasury.setup, Stores.setup; Stats.create(tags, defs.goods.size())
# digest(): M3's string with weather after turn (4.22)

# core/game/actions.gd  (M3, edit)
const NAMES: Array[String] = ["build", "upgrade", "clear", "cancel_work", "choose_country", "set_tax"]
#   set_tax {level: int, tag}  -> [EconomySeason.set_tax_check, EconomySeason.set_tax]

# core/game/season.gd  (M3, edit)
const PHASES: Array[StringName] = [&"production", &"income", &"works", &"stats", &"calendar"]
# run_phase: production -> EconomySeason.production; income -> EconomySeason.income (M3's three unchanged)

# core/game/replay.gd  (M3, edit): plays "dev_money" and "dev_goods" records through Game.dev_money / dev_goods
# core/game/snapshot.gd  (M3, edit): the body of 4.22; restore type-checks every new field and refuses country/1
# core/game/save_file.gd  (M3, edit): FORMAT := 2; OLDEST_FORMAT := 2
```

### 5.5 Events and Session (`shell/autoload/`)

```gdscript
# shell/autoload/events.gd  (edit): added signals
signal goods_short(tag: StringName, good: StringName)
signal tax_set(tag: StringName, level: int)

# shell/autoload/session.gd  (edit)
func dev_money(tag: StringName, amount: int) -> bool      # developer console only; drains
func dev_goods(tag: StringName, good: int, amount: int) -> bool
# drain(): goods_short -> Events.goods_short(tag, good); tax_set -> Events.tax_set(tag, level); then chronicled (M3)
# last_phase_ms gains production and income
```

### 5.6 Views (`core/views/`, pure)

```gdscript
# core/views/economy_preview.gd  (new)
class_name EconomyPreview extends RefCounted
static func with(game: Game, tag: StringName, changes: Dictionary, seasons: int = 4) -> Dictionary
	# changes {hexes: Dictionary (index -> Vector2i), tax: int (-1 keep)}; 4.17. Returns
	# {seasons: Array[{turn, season, made: PackedInt32Array, used, sold, stock: PackedInt32Array, content, lines:
	#  Array[Dictionary], net, realm}], year: {net, realm}}
static func expected(game: Game, tag: StringName) -> Dictionary    # with(game, tag, {}, 1).seasons[0]
static func worth_by_hex(game: Game, tag: StringName) -> Array[Dictionary]
	# [{hex, worth, upkeep, label}] for the season in play, 4.17; cached by [&"worth", version, tag]

# core/views/improve_preview.gd  (new)
class_name ImprovePreview extends RefCounted
static func of(game: Game, tag: StringName, hex: Vector2i, option: Dictionary) -> Dictionary   # 4.17's dictionary
static func options_of(game: Game, tag: StringName, hex: Vector2i) -> Array[Dictionary]
	# the hex panel's rows: each {action, family, label ("Build vineyard"), verdict, cost_text ("40 · 4 seasons"), chips,
	#  expensive}: build options of a wild hex (Improve.build_options), else upgrade, then clear
static func reason_words(game: Game, hex: Vector2i, option: Dictionary, verdict: Dictionary) -> String
static func payback(gains: Array[int], cost: int, ready_turn: int, start_year: int) -> Dictionary   # D31

# core/views/study_economy.gd  (new)
class_name StudyEconomy extends RefCounted
static func this_season(game: Game, tag: StringName) -> Dictionary
	# {date ("Spring 1480"), turn, has_season (false before any season ended),
	#  money_in: {total, lines: [{label, amount, hex}]}, money_out: {total, lines}, left_over,
	#  spending: {total, lines}, change (closing - opening), expected: {net, lines},
	#  tax: {level, options: [{level, label, change (expected net at that level - now), note}]},
	#  earns_most: [3 x {label, amount, hex}], costs_most: [3 x ...],
	#  chart: {treasury: PackedInt32Array, change: PackedInt32Array, labels: Array[String], marks: [{index, text, tone}]}}
	# from ledger_closed, Stats (12 seasons) and EconomyPreview; cached by [&"study_economy", version, tag]

# core/views/cards_economy.gd  (new; the chips' hover cards)
class_name EconomyCards extends RefCounted
static func ducats(game: Game, tag: StringName) -> Dictionary
	# {value, change, title ("Ducats"), lines: [[text, tone, amount]] (the closed ledger's lines, a rule, "Expected this
	#  season"), hint ("L: the Economy page")}
static func stores(game: Game, tag: StringName) -> Dictionary
	# {value (the stock's worth at price), change, title ("Stores"), lines: [[good, tone, "stock (change)"]] for goods in
	#  store or changed, hint}

# core/views/reminders.gd  (M3, edit): RULES of 4.18; treasury_empty, goods_running_out, treasury_falling
# core/views/season_summary.gd  (M3, edit): 4.19
# core/views/log_lines.gd  (M3, edit): 4.21
# core/views/words.gd  (M3, edit)
static func ducats(n: int) -> String           # "40 ducats", "1 ducat"
static func loads(n: int, name: String) -> String    # "12 wine", "1 salt" (the good's name in lower case)
static func signed_ducats(n: int) -> String    # "+48 ducats", "−40 ducats"
static func tax_name(level: int) -> String     # "Low", "Normal", "High"
# core/views/works_view.gd  (M3, edit)
static func ready_turn_of(game: Game, hex: Vector2i, seasons: int) -> int   # a work begun now on this hex (halts counted)
# core/views/hex_card.gd  (M1.5, edit): a "Gives" line for a district ("wine 24 in autumn"; "fish 6, dues 30 a season")
#   and a "Weather" line when the hex's season is not calm
# core/views/map_cells.gd  (M1, edit)
static func piece_cells(map: MapData, piece: Dictionary, hex: Vector2i) -> Dictionary   # the piece layers' names only
# core/views/map_modes.gd  (M2, edit)
static func delta_colour(delta: int) -> Color   # the card's tint: GOOD at +, BAD at −, alpha 0.35 (Tokens' values as consts)
```

---
## 6. The UI of M4

Built from the M1.5 kit (`ui-and-controls-spec.md` 3.5, `ui-style-and-feedback-spec.md` 5) and M3's pieces. Colours and
fonts from the Theme; HUD controls take no focus, screens do. The shell's milestone value becomes `"4"`, so the M4 rows of
`Bindings.DEFAULTS` and `Settings.SCHEMA` (which exist) are registered and shown.

### 6.1 Keys and settings

| Action (`Bindings.DEFAULTS`, exists) | Key (Mac) | Who hears it | Does |
|---|---|---|---|
| `game_study` | I | `MapInput` -> `study_requested(&"")` (**new signal**) | opens the study on its last page (`state/study_page`); I again or Esc closes it (the screen) |
| `game_ledger` | L | `MapInput` -> `study_requested(&"economy")` | opens the study on Economy, This season |
| `study_page_prev`, `study_page_next` | `[`, `]` | the study screen | the previous or next page; with one page in M4 they do nothing, and the hint hides |
| `game_upgrade` | U (exists, since 1) | `MapInput.upgrade_requested` (exists) | **from M4 opens the works card** for the selected hex's upgrade (on a wild hex its first allowed build), "Begin the work" focused; Enter or U again begins (style spec 1, refinement 8) |
| (gesture) | Shift held | the card | keeps the card while the pointer leaves the row |

| `Settings.SCHEMA` key (exists) | Choices (default) | Page, row |
|---|---|---|
| `game/confirm_works` | `off`, `expensive`, `always` (`expensive`) | Game: "Confirm works: Off, Expensive only, Always" |
| `game/preview_on_map` | bool (true) | Game: "Preview on the map" |
| `game/gain_treasury_only` | bool (false) | no row: the card's "Treasury only" switch, remembered |
| `state/study_page` | `economy` | no row: the study's last page |

### 6.2 The icon set and bake slice 4 (style spec 4.5, task W3)

`tools/ui_bake/icons.py` draws 48 two-tone woodcut icons (ink line, one flat pigment, 24 px cells at 1x, 48 at 2x) into
`icons` (256 x 128 at 1x; 10 x 5 cells, two spare); `tools/ui_bake/pieces_feedback.py` draws `vellum_inset` (96 x 96, M 16,
C 10, tiled centre), `strip_cell` and `strip_cell_now` (48 x 48, M 12, C 6). `build_theme.gd` adds them as `Kit` icons and the
variations `PanelVellumInset`, `PanelStripCell`, `PanelStripCellNow` and the type `InkChart` (colours `ink_0`..`ink_4` from
the chart tokens, `axis`, `grid`, `good`, `bad`, each with a `_slot` form).

| Group | Kit icon names |
|---|---|
| Goods (16) | `good_grain`, `good_fish`, `good_oil`, `good_wine`, `good_salt`, `good_hemp`, `good_silk`, `good_dyes`, `good_wool`, `good_cattle`, `good_horses`, `good_timber`, `good_stone`, `good_iron`, `good_copper`, `good_silver` |
| Money (9) | `ducats`, `stores`, `tax`, `upkeep`, `walls`, `port_dues`, `spending`, `refund`, `payback` |
| Land and people (5) | `people`, `jobs`, `district`, `settlement`, `castle` |
| Seasons and weather (6) | `season_spring`, `season_summer`, `season_autumn`, `season_winter`, `weather_good`, `weather_poor` |
| Screens (8) | `study`, `pin`, `info`, `go`, `warning`, `ring`, `chart`, `sold` |
| Later chips, baked now (4) | `food` (M5), `army` (M6), `research` (M11), `prestige` (M12) |

The art director signs the sheet (`bake_ui.py --sheet`) beside the mockup's medallion icons.

### 6.3 Resource chips (`shell/ui/resource_chip.tscn/.gd`, `shell/hud/chips.tscn/.gd`, new)

```gdscript
class_name ResourceChip extends Button     # flat; a PanelSlot plate > HBox: Medal (M3's Medallion at medallion_30 with the
	# icon), Name (Label), Value (Number), Change (DeltaChip); focus NONE; accessibility_name "Ducats: 658, up 48"
func set_resource(id: StringName, icon_name: StringName, label: String) -> void
func set_value(value: int, change: int) -> void
func set_card(card: Dictionary) -> void     # _make_custom_tooltip returns a HoverCard (M1.5) with the card
class_name ResourceChips extends HBoxContainer   # in the top bar after the mode switch, before DateEnd (M3)
signal chip_pressed(id: StringName)
func refresh() -> void                       # EconomyCards.ducats / stores for Session.player_tag()
```

| Chip | Value | Change | Card | Click |
|---|---|---|---|---|
| **Ducats** (`ducats`) | the treasury | the last closed season's `closing − opening` | the closed ledger's lines with amounts, a rule, "Expected this season ▲ +95", the hint "L: the Economy page" | the study, Economy |
| **Stores** (`stores`) | the stock's worth at price | the worth's change over the last closed season | a line a good in store or changed: "Wine 3 (▼ −1)"; the hint "The reserve keeps four seasons of the towns' needs; the rest is sold." | the study, Economy |

The top bar also gains the **study button**: a small `KitButton` with the icon `study` right of the date medallion (as in
`play_m4.jpg`), tooltip "The Statesman's Study (I)", opening the study's last page; hidden in a map-only game; it never
hides when the bar narrows.

Refreshes on `game_started`, `country_chosen`, `season_ended`, `work_started`, `work_cancelled`, `tax_set`, `goods_short` and
the App's `refresh_hud`. Hidden in a map-only game and during the pick. Narrowing (M2, M3 order kept): Stores hides first,
then the country's long name, then the Ducats chip's name and change; its medal and value never hide.

### 6.4 The hex panel (`shell/panels/hex_panel.tscn/.gd`, M1.5 to M3; edit)

For a hex of the player's land:

- **"Build here"** (or "Work here"): one row per `ImprovePreview.options_of(game, player, hex)`: a `KitButton` (label "Build
  vineyard", `cost_text` "40 · 4 seasons" or "100 · 10 timber · 8 seasons", `set_verdict`), an `(i)` icon button
  (`info`), up to three boxed `DeltaChip`s from `chips`, and the `Reason` line when refused. Hovering a row for the
  tooltip delay, `(i)` or U open the card. A click on the row: `game/confirm_works` `off` begins the work; `expensive` begins
  it unless `expensive`, then opens the card; `always` opens the card.
- **"Gives"**: for a district or settlement, "wine 24 in autumn · upkeep 2 a season" (`district_output` over the year) and a
  ledger row "Worth, this season ▲ +63" (`EconomyPreview.worth_by_hex`); for wild land "grain 6 a year (wild)".
- M3's work section and Cancel stay; Cancel's toast now names the refund.

Refreshes on M3's signals and `tax_set`. In a map-only game the rows carry "4 seasons" and goods chips only.

### 6.5 The works card (`shell/screens/works_preview.tscn/.gd`, `shell/ui/preview_card.tscn/.gd`, `shell/ui/season_strip.tscn/.gd`, new)

```gdscript
class_name WorksPreview extends Screen      # OVERLAY; left of the dock, its top at the hex panel's top; the map stays live
func show_option(hex: Vector2i, option: Dictionary) -> void    # ImprovePreview.of(Session.game, player, hex, option)
func pin(on: bool) -> void                  # keep this card; the next option opens beside it (compare, one chart scale)
func hold(on: bool) -> void                 # Shift
class_name PreviewCard extends PanelContainer   # PanelCard, 556 px; the style spec 5's tree
signal begin_pressed
signal pin_toggled(on: bool)
signal closed
signal look_at_requested(hex: Vector2i)
func show_preview(p: Dictionary) -> void
func show_compare(a: Dictionary, b: Dictionary) -> void
var treasury_only: bool                     # bound to game/gain_treasury_only
class_name SeasonStrip extends HBoxContainer
func set_seasons(cells: Array[Dictionary], now: int) -> void    # the style spec's cell shape; hidden when the four are equal
```

| Part | From `ImprovePreview` |
|---|---|
| Top | when pinned, the option names as toggles ("Genoa to city · Vineyard near Savona"); close |
| Title, Sub | `title`, `subtitle` |
| Brings | `brings`: label left, "0 → 12" and a `DeltaChip` right |
| Each season | `SeasonStrip` of `by_season` (`now` gilt-edged; zero lines in `FAINT`) |
| Where it lands, Country gain | `lands` lines; an `InkChart` `PAIRED_BARS` of `by_season` before and after (before `ink_0` hollow, after `ink_3` solid), caption "A year 511 → 533 ▲ +22" |
| Cost and time | `cost.text`; `requirements` with a tick or cross icon and a word ("✓" `GOOD_INK`, "✗" `BAD_INK`); `payback.text`; `next_stages` |
| Refusal | when `verdict` is not ok: a `BAD` bar with `reason_words`; for `blocked_by` rule nothing else |
| Foot | "Weather not counted" (`LabelFlavour`); "Treasury only" (`KitSwitch`); "Pin to compare"; **"Begin the work"** (`ButtonPrimary`, off with the lock and reason when refused) |

Keys: Enter or U begins; Esc closes; the wheel scrolls. Begin sends `ctx.request(&"begin_work", {hex, option})`. The card
closes on a new selection, Esc, or after Begin. Map marks show while it is up (6.6).

### 6.6 Map marks (`shell/map/preview_marks.gd`, new; a World child)

```gdscript
class_name PreviewMarks extends Node2D
func setup(view: TileMapView) -> void
func show_preview(preview: Dictionary) -> void   # ghost, tint, labels; nothing when game/preview_on_map is off
func clear_marks() -> void
```

- **Ghost:** one `TileMapLayer` with the season's TileSet at z 75 (over the standing group, under the overlay), `modulate.a
  = 0.55`, cells from `preview.ghost.tiles`.
- **Tint:** the hex and its ring, `draw_colored_polygon` in `MapModes.delta_colour(delta)` at z 82.
- **Labels:** up to seven still `Label`s in the `Names` canvas layer ("+12 wine"), placed from `map_marks`.

It writes no cell of `TileMapView`'s layers (the test counts `set_cell` calls).

| z | What | Since |
|---|---|---|
| 75 | the card's ghost | M4 |
| 82 | the card's tint | M4 |

### 6.7 The Statesman's Study (`shell/screens/study.tscn/.gd`, `study_page.gd`, `study_pages.gd`, `study/page_economy.tscn/.gd`, new)

```gdscript
class_name Study extends Screen             # OPAQUE; one instance for the App's life (page, tab and scroll kept)
func open_page(page: StringName) -> void    # &"" the last page
class_name StudyPage extends VBoxContainer   # page_economy.gd is `class_name PageEconomy extends StudyPage`
signal action_requested(action: Array)      # [&"look_at", hex] or [&"map_mode", mode]
var page_id: StringName
var tabs: Array[Dictionary]                 # {id, title, since}
func refresh(game: Game, tag: StringName) -> void
class_name StudyPages extends RefCounted
const LIST: Array[Dictionary] = [{id = &"economy", title = "Economy", scene = "res://shell/screens/study/page_economy.tscn", since = "4"}]
static func shown(milestone: String) -> Array[Dictionary]
```

**The frame** (style spec 8): a `PanelModal` frame the window's size less 30 px; the `Ribbon` "The Statesman's Study" over
its top band; a head with the date in `LabelFlavour` ("Spring 1480") and Close with a `KeyCap` of I; a body of a `NavList`
(the shown pages; Economy only in M4) and the `PageHost`; a hint line ("I: close · Enter: look there"; "[ ]: page" from
two pages). Esc or I close it.

**Economy, This season** (`PageEconomy`; the tabs Districts, Goods, History and Debt are hidden until M4.5 and M12), from
`StudyEconomy.this_season`:

| Column | Content |
|---|---|
| Left | `SectionHead` "Money in" with its total (`NumberGood`); a row a line ("Taxes on people ▲ +65", "Port dues, Genoa ▲ +30" a link); "Money out" with its total and rows; then "Left over, a season", "Your spending" (its lines: "vineyard near Savona (7, 12) ▼ −40"), "Treasury this season", "Expected this season" (each a `DeltaChip`; Expected's tooltip lists its lines); **Tax**: a `Segmented` Low, Normal, High (the level set) and a `Hint` under it: the hovered level's note ("High: ▲ +38 a season; districts ▼ −10 %"), the set one "Normal: as now". Pressing a level: `Session.act("set_tax", {level})` |
| Right | a `PanelVellumInset` with an `InkChart` `LINE_BARS`: "The last 12 seasons" (fewer when fewer have passed), bars the change a season, the line the treasury, marks on a season whose spending was over a quarter of its income ("Spring 1480: vineyard"); caption "bars: change a season · line: treasury"; then "Earns most" and "Costs most", three link rows each |

Before the first season ends the money rows read "No season has ended yet." and only Expected and Tax show. A row or
"look there" emits `action_requested([&"look_at", hex])`; the study asks `ctx.request(&"look_at", {hex, select: true})`; the
App pops it and glides; I returns to the same page and scroll. Refreshes on `season_ended`, `tax_set`, the work signals and
a newer `game.version`. In a map-only game the study does not open (toast "The sandbox has no treasury.").

### 6.8 The season report (M3's screen; edit)

The screen draws the M4 sections it already knows. Its footer's **"Open the study"** (with a `KeyCap` of I) shows from
M4: it closes the report and asks `ctx.request(&"study", {page: &"economy"})`. A `before` line's action `[&"study", page]`
does the same.

### 6.9 Task flag, notifications, toasts, log, ribbons (M3's pieces)

- **Task flag** (`shell/hud/task_flag.gd`, M3; edit): shows 4.18's lines; a line's action `[&"study", page]` sends
  `ctx.request(&"study", {page})` (M3 knew only `look_at`).
- **Notifications:** the player's `goods_short` ("Your towns ran short of salt: 0 of 1.", Go: the capital).
- **Toasts** M4 adds:

| When | Text | Tone | Key cap |
|---|---|---|---|
| The player began a work that cost money | "Work begun: vineyard, first stage, near Savona (7, 12). −40 ducats. Ready Spring 1481." | plain | `game_undo_work` |
| The player cancelled in the first season | "Work cancelled: vineyard, first stage, near Savona (7, 12). +40 ducats back." | plain | |
| Taxes set | "Taxes set to High: about ▲ +38 a season." (the expected change) | plain | |
| U with nothing to build or upgrade | "Nothing to build or upgrade here." | plain | |
| The study in the sandbox | "The sandbox has no treasury." | plain | |

- **Log:** the Money filter (4.21). **Ribbons:** "Begun −40" on the work's hex.

### 6.10 The country panel and the hover card (M2, M1.5; edits)

**Country panel** (`shell/panels/country_panel.tscn/.gd`): a **Treasury** section after Land, from `CountryCard.of`
(M2's view gains `treasury: {shown, value, banded, change, expected, tax}`):

| Country | Rows |
|---|---|
| Yours | "Treasury 658 (▲ +48 last season)", "Expected this season ▲ +95", "Taxes Normal", a `KitButton` "Open the study" with a `KeyCap` of L |
| Known (`Knowledge.knows`) | "Treasury about 1,500" (`Knowledge.band_text`) |
| Not known | no section |

The section refreshes on `season_ended`, `tax_set` and the work signals.

**Hover card:** `HexCard.of` gains "Gives" ("wine 24 in autumn"; a port: "fish 6, dues 30 a season") and "Weather"
("good this season: crops +20 %") when not calm.

### 6.11 Options, F3, the console

- **Options, Game page:** the rows Confirm works and Preview on the map show from milestone 4 (they exist in the schema).
- **F3:** a line "production 3.1 ms · income 0.4 ms · districts cached 340 · weather calm, good, calm".
- **Console** (M3's `DevCommands`): `money N [TAG]` (`Session.dev_money`), `goods KEY N [TAG]` (`Session.dev_goods`),
  `tax low|normal|high` (`act("set_tax")`); planted faults: an unknown good, a non-number, an unknown tag.

### 6.12 The App (`shell/app/game_requests.gd`, `app.gd`, M3; edits)

| Request or event | The App |
|---|---|
| `MapInput.study_requested(page)`, `app_requested(&"study", {page})`, a chip's `chip_pressed`, the top bar's study button | push the study at the page (the sandbox: the toast) |
| `MapInput.upgrade_requested` | push the card for the selected hex's upgrade (or first allowed build); "Nothing to build or upgrade here." when none |
| `app_requested(&"works_card", {hex, option})`, `(&"close_card")` | push or update the card; pop it |
| `app_requested(&"begin_work", {hex, option})` | `Session.act(action, args)`; the toast of 6.9 or the refusal; pop the card |
| `app_requested(&"look_at", ...)` while the study is up | pop the study first (M3's look_at after) |
| `app_requested(&"refresh_hud")` | `ResourceChips.refresh()` (after the console's money and goods) |
| `Events.tax_set` (the player's) | the toast |

`Hud` (M1.5) gains the `Chips` slot in the top bar. `screen_ids.gd` gains `study` and `works_preview`. The App sets the
milestone value `"4"`.

---
## 7. Data and the editor

| File | Holds | Made by | Checked by |
|---|---|---|---|
| `godot/data/defs/goods/<key>.tres` (16, **new**) | `GoodDef` (table 4.2) | by hand in the inspector (task N1) | `tests/core/test_good_defs.gd`: every file loads and validates; the values equal 4.2 |
| `godot/data/defs/families/<key>.tres` (14, M3, edit) | the M4 fields of `FamilyDef` (tables of 4.4) | by hand (N1) | `tests/core/test_family_defs.gd`: the values equal 4.4 |
| `godot/data/defs/game_defs.tres` (M2, M3; edit) | `goods` (the 16, external), the wild yields, countryside people, rates, levels, weather, start and expensive numbers (5.1) | by hand (N1) | `tests/core/test_economy_defs.gd`: `GameDefs.validate()` and the values of 4.2 to 4.12 |
| `godot/assets/ui/kit/` (slice 4) | `icons`, `vellum_inset`, `strip_cell`, `strip_cell_now` at 1x and 2x | `tools/bake_ui.py` (W3) | `bake_ui.py --check`, `build_theme.gd --check` in CI |
| `godot/tools/economy_tables.gd` (**new**, headless) | prints 4.2's and 4.4's tables as Markdown from the `.tres` (the standard's "tables in docs are printed from the data") | N1 | `tests/core/test_economy_defs.gd` runs it and compares one row of each table with the values it reads |

No generated data: the definitions are edited in the Godot inspector as M3's families are, and the definition tests are the
CI proof. `godot/data/README.md` gets a `goods/` line and the families' new fields. The scenario editor (M2) is unchanged;
the map file is unchanged (D27).

---

## 8. Speed

`godot/tools/perf_core.gd` (M3) on the made-up Europe (494 x 247), `FakeScenario.build(map, 60, 1480)` with the real
`goods` and `families` added to its `GameDefs`, `work_slots_base` 10, 600 works begun, 8 seasons through `Season.run`, then
save and load. Rows in `godot/tests/perf_core_budget.json`, nightly, never in GUT:

| Row | Limit | What |
|---|---|---|
| `season_ms` | **150** (M3: 100) | the five phases, worst of 8 seasons |
| `production_ms` | 60 | the production phase over every land hex (warm `DistrictCache`) |
| `income_ms` | 20 | the income phase |
| `cache_build_ms` | 400 | `DistrictCache` filled for every land hex from cold (a new game, a load) |
| `preview_ms` | 1 | one `ImprovePreview.of`, the country's base warm, the option cold |
| `options_ms` | 2 | `ImprovePreview.options_of` on a hex with ten options (the hex panel) |
| `expected_ms` | 2 | `EconomyPreview.expected`, uncached |
| `reminders_ms` | **4** (M3: 2) | `Reminders.unfinished`, uncached (it simulates eight seasons) |
| `study_ms` | 2 | `StudyEconomy.this_season`, uncached |
| `summary_ms` | 2 | `SeasonSummary.of` with the money sections |
| `save_mb` | 8 | unchanged |

`godot/tools/ui/perf_ui.gd` (M1.5) gains in `perf_ui_budget.json`: the card's push under 16 ms; the study's push under
16 ms; the chips' refresh under 1 ms; the map marks' show under 2 ms. North Italy for scale: 340 land hexes, 13 countries:
nothing there is measurable.

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (P).

| File | Cases |
|---|---|
| `tests/core/test_good_defs.gd` (new) | the 16 files load, validate, equal 4.2; P: ids out of order, a price of 0, a food with a need, weights not adding to 1,000, an unknown kind, an empty icon |
| `tests/core/test_family_defs.gd` (M3, edit) | the M4 fields equal 4.4; P: an array of the wrong size, an unknown good in `cost_goods`, `keep_wild` 101, settlement arrays on a goods family, an extra not in `ANIMALS` or `ORES` |
| `tests/core/test_economy_defs.gd` (new) | `GameDefs` M4 values; `economy_tables.gd`'s rows; P: weather odds adding to 99, seven covers, a family naming an unknown good |
| `tests/core/test_state_view.gd` (new) | reads fall through; `with` never changes the base or another view; `changed` ascending |
| `tests/core/test_economy.gd` (new) | `district_output` for every family, level and slot of 4.4 on a fixture map (the frost years of the table); wild yields and `keep`; staffing below 100 % (a third-stage mine with six rock neighbours: 7 × 600 people give 1,260 hands for 4,000 jobs, staffing 315) and its ring competition (a second district beside it lowers both); lift beside a walled town and a city, the best counting; port fish and dues; weather only on bound families and wild grain; the tax's output; `slot_of`; `people_at`; `market_prices` equal to the table whatever the supply (P: a changed supply array leaves the prices); `district_output == season_output(district_base)` on every land hex of north Italy, every season |
| `tests/core/test_economy_season.gd` (new) | needs (ceil); reserve; `goods_step` (fish eaten first; satisfactions; sales down to the reserve; never below zero); content and factor; `money_lines` against 4.9 by hand; `set_tax_check` every row (P each) and its event; a tax change counts from the next phases; `goods_short` once when a need starts failing, witnessed by its actor only; `debt_limit` 0 |
| `tests/core/test_treasury.gd` (new) | `move` merges by (why, hex) in first-added order; `count`; amount 0 adds nothing; P: an unknown why, an unknown tag change nothing and return false; `close_ledger`; `left_over`; `setup`'s start amounts (the property over 40 seasons is in `test_forty_seasons.gd` and `test_money_property.gd`) |
| `tests/core/test_stores.gd` (new) | `move`, flows by reason, `close` (the closed change equals the flows' sum); P: a move below zero, an unknown flow and an unknown good refused; `short_of` words; `setup`'s stores |
| `tests/core/test_works.gd` (M3, edit) | rows 8 and 9 with their words (P each); begin pays (`paid`, `paid_goods`, a `work` line, `work` flows); cancel in the first season refunds both, later nothing; `lost` and `blocked` refund nothing; clear is free; a map-only game pays nothing; M3's cases get the money they need through `Game.dev_money` |
| `tests/core/test_calendar.gd` (M3, edit) | the weather draws three values a season from `luck.world` in slot order; odds 100, 0, 0 give calm; a seed gives the same weather; the digest moves with the weather |
| `tests/core/test_season.gd` (M3, edit) | **`PHASES` is `[production, income, works, stats, calendar]`** (the pin); a work finishing in season T first produces in T + 1 and pays its upkeep from T + 1 |
| `tests/core/test_stats.gd` (M3, edit) | the M4 series after a played season equal the closed ledger and flows; `goods` 16; the goods ring's made, used and stock |
| `tests/core/test_district_cache.gd` (new) | `touch` forgets the hex and its ring; a cold cache equals `district_base` on every land hex of north Italy; after 2,000 random actions with 40 season ends (through `Game.emit`'s touches) it still does; P: a cache whose `touch` does nothing is caught |
| `tests/core/test_economy_genoa.gd` (new) | 4.15 (a)'s tables exactly (per hex and per season, treasury 1,068 after Winter 1480); the fixture builds and gives 4.15 (b)'s ledger and flows (the summary's words are `test_season_summary.gd`'s) |
| `tests/core/test_economy_1480.gd` (new) | 4.12's table for the 13 countries (people, treasury, needs, reserve, first year's nets on seed 1480 with calm weather) |
| `tests/core/test_money_property.gd` (new) | the M4 done-when 2: 40 seasons, seeded random works, cancels and taxes for every country; every check of done-when 2 every season |
| `tests/core/test_improve_preview.gd` (new) | **property, 200 seeded cases** (done-when 4); 4.15 (c), (d) and (e) exactly; `blocked_by` for each refusal kind; `reason_words` for each of the 13 pair rules on fixtures; payback (Autumn 1482, Spring 1488, "never" for a castle); expensive; a map-only game; a preview leaves the digest; the view cache keys on version |
| `tests/core/test_economy_preview.gd` (new) | `with(game, tag, {}, 8)` equals eight played seasons for every country of the 1480 scenario (calm); works under way stand from their ready turns; a tax change; `worth_by_hex` against 4.17's example |
| `tests/core/test_study_economy.gd` (new) | `this_season` equals the closed ledger to the unit; Expected equals `EconomyPreview.expected`; the tax options; Earns and Costs most; the chart's 12 seasons; before any season ended |
| `tests/core/test_cards_economy.gd` (new) | the Ducats card's lines sum to the chip's change; the Stores card; a map-only game gives nothing |
| `tests/core/test_reminders.gd` (M3, edit) | the three rules and the order; P: a treasury of −1 gives `treasury_empty`; a stock exactly covering eight seasons gives no line; food at k = 2 is serious, k = 3 is not |
| `tests/core/test_season_summary.gd` (M3, edit) | 4.15 (b)'s sections on the fixture; the Treasury lines sum to the change and the Goods lines to each stock change, every season of a 40-season run; standing through `Knowledge` (P: an unknown country is absent); quiet; `swing_permille`; the toast; equal after a save and load |
| `tests/core/test_log_lines.gd`, `test_chronicle.gd` (M3, edit) | `NOTABLE` holds the two kinds; `goods_short` and `tax_set` sentences; the Money filter; works lines with amounts; P: another country never hears of a `goods_short` |
| `tests/core/test_snapshot.gd`, `test_save_file.gd` (M3, edit) | M4 fields round-trip; save, load, save byte-equal; `FORMAT` 2; P: a format-1 header reads `older`; a `country/1` dict is refused; a string for `treasury` is refused |
| `tests/core/test_replay.gd` (M3, edit) | 20 seasons with works, cancels, `set_tax`, `dev_money` and weather: the same digest; P: one changed tax level gives another |
| `tests/core/test_country_state.gd` (M2, edit), `test_game_core.gd` (M3, edit) | `country/2` round trip and `digest_text` with every M4 field (P: a `country/1` dict gives null); `weather`, `districts` and the dev records on `Game` |
| `tests/core/test_owns.gd` (M3, edit) | 5.3's OWNS table for every action and phase; P: a test-only action writing `treasury` directly is reported |
| `tests/core/test_no_other_writers.gd` (new) | a text scan of `core/` and `shell/` finds no assignment to `.treasury`, `.stock`, `.flows_open`, `.ledger_open` outside `treasury.gd`, `stores.gd` and `country.gd`'s `from_dict`; P: a planted file in `user://` is caught |
| `tests/core/test_forty_seasons.gd` (M3, edit) | adds every season: the ledger and flow properties; no stock below zero; no treasury change without a line |
| `tests/core/test_improve_actions.gd` (M1 to M3, edit) | the 2,000-action property with `set_tax` and costs; refused works leave the treasury and stores |
| `tests/core/test_words.gd`, `test_works_view.gd`, `test_hex_card.gd`, `test_map_cells.gd`, `test_map_modes.gd`, `test_world_improve.gd`, `test_country_card.gd` (edits) | the new helpers: `ducats`, `loads`, `tax_name`; `ready_turn_of`; the Gives and Weather lines; `piece_cells`; `delta_colour`; `conflict` (its string unchanged); the treasury section (yours, known banded, unknown none) |
| `tests/shell/test_resource_chip.gd`, `test_resource_chips.gd` (new) | the chip's parts, its card and accessibility name; values, change and card from the Genoa fixture; a click requests the study; hidden in a map-only game and the pick; narrowing order |
| `tests/shell/test_kit_feedback.gd` (M3, edit), `test_ink_chart.gd` (new) | `SeasonStrip` marks `now`, hides when flat; `InkChart` `LINE_BARS` and `PAIRED_BARS` with 0, 1 and 40 points, ink and dash per series, marks on `LINE_BARS`, redraws only on new data |
| `tests/shell/test_preview_card.gd`, `test_works_preview.gd` (new) | the card's parts against 4.15 (c), (d), (e) from `tests/fixtures/preview_sample.gd`; a rule refusal shows only the refusal; a money refusal shows all and the bar; pin to compare (one chart scale); Shift holds; Enter and U begin; Esc closes; the switch writes `game/gain_treasury_only` |
| `tests/shell/test_preview_marks.gd` (new) | ghost, tint and labels come and go with the card; no `set_cell` on `TileMapView`'s layers; nothing with `game/preview_on_map` off |
| `tests/shell/test_hex_panel.gd` (M1.5 to M3, edit) | rows with chips and cost text; the three `confirm_works` values; U opens the card; Gives and Worth |
| `tests/shell/test_study.gd`, `test_page_economy.gd` (new) | I and L open, I and Esc close; a row requests `look_at` and the study pops; I reopens the same page and scroll; one page hides the `[ ]` hint; the page's lines from 4.15's numbers; the tax `Segmented` acts and its hover note; before the first season; the sandbox toast |
| `tests/shell/test_season_report.gd`, `test_country_panel.gd`, `test_session.gd`, `test_map_input.gd`, `test_dev_commands.gd`, `test_task_flag.gd`, `test_hud.gd`, `test_debug_overlay.gd`, `test_app_flow.gd` (edits) | Open the study; the treasury section; the two signals drained, `dev_money`; I and L; the console's three commands with planted faults; a `study` line opens the study; end to end: New game as Genoa, build with its cost, cancel with its refund, set taxes, open the study, J shows the money sections |
| `tests/shell/test_ui_monkey.gd` (edit) | adds I, L, `[`, `]`, U, clicks on chips, rows and the card; invariants: the world hidden exactly while the study is up; the digest unchanged by the study, a card or a chip's card |
| Python `tests/test_bake_ui.py` (edit) | slice 4 at both scales; 48 icons in the catalogue; the asserts of style spec 4.4 |
| Pictures (`godot/tools/ui/shot_ui.gd`) | the card for the vineyard (against `works_vineyard.jpg`), Genoa (`works_genoa.jpg`), Savona refused, two pinned; the study's This season (`study_econ.jpg`); the top bar with chips and a chip's card (`play_m4.jpg`); the report with money sections (`report_m4.jpg`); map marks; the hex panel rows; the country panel's treasury. Signed by the art director, then goldens (0.5 %) |

**Determinism:** `test_improve_actions`, `test_replay`, `test_forty_seasons`, `test_money_property`. **Save round trip:**
`test_snapshot`, `test_save_file`, `test_forty_seasons`.

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| The balance feels wrong: towns too lucrative (D42), districts too weak, a start too poor (Lucca, Siena) | `godot/tools/economy_report.gd` (**new**, headless, task N10): 40 calm seasons of the 1480 scenario on seeds 1480 to 1484, every country's year (treasury, the lines, contentment, shortages); read by Opus and the owner before the playtest | Data only: rates, costs, people (S each) |
| A seed leaves a country short of food for good (its farmland is all towns) | the same report's shortage column | `food_need_milli` or the wild yield (data) |
| `production` over its budget on Europe | `perf_core` in N4's first week, before the UI builds on it | the per-country sums kept as running totals updated by `hex_changed` (M) |
| The preview drifts from the season | the 200-case property in W5's first week | one code path (built in); drop the delta method for a full country run (slower, M) |
| The cache and the direct path round differently | `test_district_cache` | drop the cache (S) |
| M3's tests break because works now cost | N4 edits them in the same pull request (`Game.dev_money`) | none needed |
| 48 icons take longer than a slice | W3 starts in group A, the art director signs a first 16 (goods) early | the medal shows the good's initial in Cinzel until the icon lands (the chip and card keep working) |
| The card is too much to read | the owner's playtest step 3 | hide `next_stages` and the chart behind "More" (S) |
| Weather surprises in the first seasons | playtest step 12 | `weather_odds` 100, 0, 0 (data) |
| The other countries pile up money with no actions until M8, so Standing looks odd | expected; Standing ranks income, not treasury | none |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 5.3: the works row moves after income and debt (M4); production and income named; the calendar row's weather is M4's. 9.2, row M4: points at this spec and its plan; status "specified and planned, waits for the owner's go; starts after M3 closes" |
| `docs/architecture/m3-build-spec.md` | 4.2: a note that M4 moves `works` after `income` (`m4-build-spec.md` 4.13); 4.3: the M4 hook is two calls and the checks gain rows 8 and 9; 1.2 and 12: road works move to M10 |
| `docs/architecture/m3-build-plan.md` | Section 7: road works move to M10; the M4 hook as above |
| `docs/architecture/m1-build-spec.md` | Section 4: `fertility` and `ore` stay 0 and unread in M4 (E2 decides); the living roads arrive with road works in M10 |
| `docs/architecture/ui-style-and-feedback-spec.md` | Section 7: a note of M4's refinements (the profile in `FamilyDef`, `tax` in `district_output`, `Stores.move`, `expensive` at eight seasons, the requirements answered in `m4-build-spec.md` 4.23) |
| `docs/architecture/ui-style-and-feedback-plan.md` | S3: a note that `m4-build-plan.md` folds W0 to W12 (W0 done by the spec) |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M4: the tasks are those of `m4-build-plan.md`; the card is `shell/screens/works_preview.*` |
| `docs/design/ui/game-feedback-screens.md` | B.4, B.5, C.3: a line that the examples are replaced by `m4-build-spec.md` 4.15 and 4.16 (Genoa's city is 1,000 ducats and pays back in 32 seasons, not a prestige work) |
| `docs/design/ui/design.md` | 6a: the same pointer |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `godot/README.md` (the M4 game; N12), `godot/data/README.md` (N1), `CLAUDE.md` (the
`economy_report.gd` line in the Godot commands; N10). No port rule changes: no new autoload, no new layer;
`tools/lint_godot.py` needs no entry (new files sit in listed folders, each under 800 lines).

---

## 12. What M4 hands to later milestones

| M | Takes from M4 | M4 leaves for it |
|---|---|---|
| M4.5 | `Stats` money and goods series, the ledgers, `EconomyPreview.worth_by_hex` (Districts tab), the goods ring (Goods tab), `InkChart`'s two kinds (to complete), the study frame and `StudyPages.LIST`, `MapModes.delta_colour` (the Yields mode) | Insights |
| M5 | `Economy.people_at` (the one seam: it reads `MapState.people` from M5, the table becoming room), towns' needs and contentment (hunger, decline), `goods_short` of food, the tax level's growth effect, the People chip (icon `food` baked), settlement payoffs to re-tune (D42) | People |
| M6 | `Treasury.WHY` gains `army`; armies eat from the stores (a need); horses and iron reserves; the Army chip (icon baked) | Armies |
| M7 | captured land produces for its new owner from the next production; walls upkeep of castles; occupation may cut output (a term of `district_output`) | War |
| M8 | the AI acts through `build`, `set_tax`, `cancel_work` with the same checks; `ImprovePreview` and `EconomyPreview` are its views; the soak checks the money property | The AI |
| M10 | `market_prices` gets its body (supply); `market_of` returns real markets; sales go to markets instead of the flat price; road works (`MapState` schema 4); the ring's price lines on the card; `Treasury.WHY` `trade` | Trade |
| M11 | techs change `FamilyDef` numbers through definitions only | Research |
| M12 | `debt_limit`, interest (`WHY` `interest`), bankruptcy; the Debt tab; the Prestige chip | A whole game |
| **E2** | **Nothing blocking: the economy reads the map's cover, climate, places and ports, which the Europe map file has; `fertility` and `ore` may be filled there and read by a later term.** | |
