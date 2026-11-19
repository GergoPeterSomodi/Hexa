# M10 build plan: Trade

Game and systems designer (Opus), 2026-11-17. **Status: a proposal; no task starts before the owner's go.** Builds
`docs/architecture/m10-build-spec.md` ("the spec").

**Starts after M9 is closed** (its plan's definition of done, the owner's playtest). M10 edits what M1.5 to M9 deliver: `Game`,
`Session`, `Events`, the action and season tables, `MapState`, `Work`, `Country`, `Stats`, `Deal`, `PeaceOffer`, `GoodDef`,
`GameDefs`, `DiplomacyDef`, `AiDef`, `AiTemperDef`, `Economy`, `EconomySeason`, `Treasury`, `Stores`, `Works`, `StepCosts`,
`Movement`, `Supply`, `Battles`, `Occupation`, `Vision`, `Relations`, `Peace`, `StatsSystem`, `Chronicle`, `Knowledge`, `Words`, the
previews, the report's view, the reminders, the log lines, the study's views and pages, the map modes and overlay, the edge lines,
the crossings, the map scene, the hex, country and peace screens and panels, the chips, the console, F3, the App, the AI, the soak
and the perf tools. The standard's rule holds: the next milestone starts after the owner has played the last one.

**The M10 row of `ui-style-and-feedback-plan.md` S5** (the Trade page; sparklines in tables; the price ring; `price_moved` in the
report; the Trade flows mode) is folded in: the page is X18 and X26 (its tables use M4.5's `spark` cells), the price ring X14 (the
`Stats` ring), X18 and X26 (its chart), the report's price lines X19 and X26, the mode X17 and X25. **The M10 row of
`ui-and-controls-plan.md` section 4** (the Trade map mode, the market panel, merchant orders, trade route lines in Layers, the Trade
study page) is X17 and X25 (the mode and the lines), X15 and X23 (the market panel), X9, X15 and X24 (the orders and the card), X28
(the Layers switch) and X18 and X26 (the page).

**Task IDs** are X1 to X31: the letter X is used by no other plan. M7, M8 and M9 are on GitHub (milestones 19, 20 and 21): M10
changes none of their task rows; every edit M10 makes to their code is an X task here.

---

## 1. Slices, effort, order

S is about half a day of one worker, M a day, L two or three days.

| Slice | Ships | Tasks | Effort |
|---|---|---|---|
| **Numbers, state, keys** | `TradeDef`, the goods' appetites, the pacts' opinions; the state classes, `map-state/7`, `work/3`, `country/6`, `stats/2`, `peace-offer/2`, format 8, the skeletons; bake slice 8; the keys and settings | X1 to X4 | 1 L, 1 M, 2 S |
| **Roads and markets** | living roads and `StepCosts` on `Game`; markets, catchments, routes and the price rule | X5, X6 | 2 L |
| **The rules between markets** | pacts and their relations, route states, tolls and the country step; road works | X7, X8 | 1 L, 1 M |
| **Merchants and the seams** | merchants and their pairs; the economy's seams and the tests' still trade; the peace's open markets; knowledge and words | X9 to X12 | 1 L, 2 M, 1 S |
| **The season** | the trade phase, the season table, the actions table and the notable kinds, the switch of sales to the markets and the previews; the stats and the ring, the events, `Session` and the dev price | X13, X14 | 1 L, 1 M |
| **Read models and proofs** | the market and trade views and cards; the road card and the card's prices; the map's read models; the study's view, the country card, the history series, the matrix states; the report, log and reminders; the properties, saves and the Italian game; the perf rows | X15 to X21 | 2 L, 5 M |
| **The AI and the screens** | the AI's trade; the market panel; the order card; the map; the Trade page and the report screen; the panels and the kit edits | X22 to X27 | 2 L, 4 M |
| **The App and the soak** | the App, the chip, the console, the Layers switch; the soak's invariants and ranges, the trade report | X28, X29 | 2 L |
| **Proof in the window** | the monkey, the pictures, the UI perf rows | X30 | 1 M |
| **Tuning** | the appetites and the ranges on the soak's and the report's tables; the playtest's seed | X31 | 1 M |

**31 tasks: 12 L, 16 M, 3 S**, about 47 worker-days; about 22 working days end to end with the groups below (each group takes as
long as its longest task), plus reviews and the owner's playtest.

```
M9 closed (the owner's playtest)
  -> A:  X1  X2 (L)  X3 (S)  X4 (S)
  -> B:  X5 (L)  X6 (L)                                            (X6's catchment picture and cold time go to Opus and Fable)
  -> C:  X7 (L)  X8
  -> D:  X9 (L)  X10  X11  X12 (S)
  -> E:  X13 (L)  X14
  -> F:  X15 (L)  X16  X17  X18  X19  X20 (L)  X21
  -> G:  X22 (L)  X23  X24  X25 (L)  X26  X27
  -> H:  X28 (L)  X29 (L)                                           (X29's first full soak and report: Opus reads its tables)
  -> I:  X30
  -> J:  X31  -> the owner plays M10

Critical path: X2 -> X6 -> X7 -> X9 -> X13 -> X15 -> X25 -> X28 -> X30 -> X31   (and X5 -> X8; X7 -> X10 -> X13;
               X9 -> X22 -> X29 -> X31; X12 -> X15, X17, X18; X13 -> X20; X14 -> X18, X19; X16 -> X27)
```

A group starts when every task of the group before it is merged. Inside a group the tasks run in parallel, no two touch one file,
and no task calls code another task of its group writes: X2 creates `core/systems/trade_cache.gd`, `trade.gd`, `merchants.gd`,
`trade_pacts.gd` and `roads.gd` with every function's signature and an empty body, and gives `StepCosts.for_game` an interim body
that returns the map's table (`StepCosts.of`), which X5 replaces; X6 needs only that signature (on a fresh game the living roads are
the map's); the calls of X6 and X7 to `Merchants.free` reach X2's empty body until X9 fills it, and X9 tests them.

---

## 2. Tasks

Who, per the standard's section 9 ("Opus / Sonnet, Haiku"): *Sonnet* builds the systems, views, the AI, tools and anything touching
`Game`, saves, the season table, `Session`, `Events`, input or the App; *Haiku* builds data files, the bake slice, the keys, the
market panel, the order card, the Trade page, the panels' parts and the pictures; *Opus* sets and reviews the numbers and the words
and decides the tuning; *Fable* reviews the interfaces. Generated files belong to the task that changes their source. **Every
task's done-when includes: lint (`python tools/lint_godot.py godot`), check_scripts and GUT green**, both UI `--check`s
(`bake_ui.py --check`, `build_theme.gd --check`), `build_map --check` and `build_scenario.gd --check`. Paths without a prefix are
under `godot/`; `tools/`, `tests/test_*.py`, `docs/`, `.github/` and `CLAUDE.md` are at the repository root.

### Group A (parallel)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| X1 | M, Haiku (Opus reviews) | **The numbers: `TradeDef`, the goods' appetites, the pacts' opinions** | `core/defs/trade_def.gd` (new); edit `core/defs/good_def.gd` (`appetite_milli`, `war_open`, `validate`), `core/defs/diplomacy_def.gd` (the six numbers, `validate`), `core/defs/game_defs.gd` (`trade`, `validate`); `data/defs/trade.tres` (new); edit `data/defs/goods/*.tres`, `data/defs/diplomacy.tres`, `data/defs/game_defs.tres`, `data/README.md` (trade, the goods' new fields); `godot/tools/trade_tables.gd` (new); `tests/core/test_trade_defs.gd` (new); edit `tests/core/test_good_defs.gd`, `tests/core/test_diplomacy_defs.gd`, `tests/core/test_economy_defs.gd` | Spec 4.4 to 4.10 and 5.1 entered exactly; every planted fault of spec 9 for these tests; `trade_tables.gd` prints the tables; Opus reads the numbers on the task's first day. Lint, check_scripts, GUT green |
| X2 | L, Sonnet | **The state, the saves, the skeletons** | `core/state/market.gd`, `core/state/route_record.gd`, `core/state/merchant_order.gd`, `core/state/trade_pact.gd` (new); edit `core/state/country.gd` (country/6), `core/state/map_state.gd` (map-state/7: `road`, `crossing`, `road_at`, `crossing_at`, `road_work_at`; `work_at` district works only), `core/state/work.gd` (work/3), `core/state/stats.gd` (stats/2: 58 series, `markets`, `price_ring`, `add_market`, `price_at`, `price_series`), `core/state/deal.gd` (`open_markets`), `core/state/peace_offer.gd` (peace-offer/2); `core/systems/trade_cache.gd`, `core/systems/trade.gd`, `core/systems/merchants.gd`, `core/systems/trade_pacts.gd`, `core/systems/roads.gd` (new: spec 5.3's classes with `OWNS`, every signature and an empty body); edit `core/systems/step_costs.gd` (the signatures of `for_game` and `forget_hexes`, the interim body of section 1), `core/systems/treasury.gd` (`WHY` 17), `core/systems/stores.gd` (`FLOWS` 9), `core/game/game.gd` (the fields, `DOOR_FIELDS`, the digest, `emit`'s drops, `new_scenario` calling `Roads.setup`, `Trade.setup` and `Stats.add_market`), `core/game/snapshot.gd`, `core/game/save_file.gd` (`FORMAT` 8, `OLDEST_FORMAT` 8); `tests/core/test_trade_state.gd` (new); edit `tests/core/test_country_state.gd`, `test_stats.gd`, `test_map_state.gd`, `test_diplomacy_state.gd`, `test_treasury.gd`, `test_stores.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_game_core.gd` (`DOOR_FIELDS`), `test_owns.gd` (the new fields' owners), `test_insights_views.gd` (the pins of format 8, 58 series, 17 `WHY` reasons, 9 flows) | Spec 5.2, 4.21 and the `Treasury` and `Stores` lines of 5.3: every round trip and planted fault of spec 9 for these tests; save, load, save byte-equal; `FORMAT` 8 (P: a format-7 header reads `older`); every M3 to M9 test green. Lint, check_scripts, GUT green |
| X3 | S, Haiku | **Bake slice 8: the trade icons** | `tools/ui_bake/pieces_m10.py` (new); edit `tools/bake_ui.py` (the slice), `shell/ui/tokens.gd` (the four route inks), `godot/tools/build_theme.gd` (the Kit icons); `godot/assets/ui/kit/**`, `shell/ui/theme.tres` (generated); edit `tests/test_bake_ui.py` | Spec 6.2: the 20 icons at 1x and 2x; both `--check`s; the art director signs the sheet. Lint, check_scripts, GUT green |
| X4 | S, Haiku | **The keys and the settings** | edit `shell/input/bindings.gd` (`view_mode_8`, `game_market`), `shell/app/settings.gd` (`map/trade_routes`, `state/trade_lens`, `state/trade_routes_mine`; `state/map_mode` gains `trade`); edit `tests/shell/test_bindings.gd`, `tests/shell/test_settings.gd` | Spec 6.1: the rows with `since: "10"`; a bad `state/trade_lens` falls back to `markets` (P). Lint, check_scripts, GUT green |

### Group B (after A)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| X5 | L, Sonnet | **Living roads and `StepCosts` on `Game`** | edit `core/systems/roads.gd` (fill: `setup`, `edge_of`, `road_check`, `cost_of`, `crossing_for`, `set_road`), `core/systems/step_costs.gd` (`for_game` from the state's roads and crossings, `forget_hexes`, `compute`'s road and crossing arguments), `core/systems/movement.gd`, `core/systems/supply.gd`, `core/systems/battles.gd` (`retreat_spot`), `core/systems/occupation.gd` (the area walk) (their `StepCosts.of` calls to `for_game`), `core/views/edge_lines.gd` (`for_chunk` and `chunks_of_run` read the state), `core/views/crossings.gd` (`of_state`); `tests/core/test_roads.gd` (new); edit `tests/core/test_step_costs.gd`, `test_movement.gd`, `test_supply.gd`, `test_edge_lines.gd`, `test_crossings.gd` | Spec 4.10's living roads and 5.3's `Roads` and `StepCosts`: every case and planted fault of spec 9 for these tests; a text test finds no `StepCosts.of(` in `core/systems/` outside `step_costs.gd` (P); every M6 and M7 test green. Lint, check_scripts, GUT green |
| X6 | L, Sonnet | **Markets, catchments, routes and the price rule** | edit `core/systems/trade_cache.gd` (fill: catchments, ways, colours, homes, town people, `forget_all`), `core/systems/trade.gd` (`setup`, `market_hexes`, `refresh_markets`, `market`, `market_name`, `appetite`, `next_price`, `price_after`); `tests/core/trade_fixture.gd`, `tests/core/test_trade_map.gd`, `tests/core/test_trade_cache.gd`, `tests/core/test_trade_prices.gd` (new) | Spec 4.2 to 4.5 and 5.3 for these files: **done-when 3**'s markets, catchments, routes and homes pinned as the build gives them (written into spec 4.2 to 4.4 where they differ); the price rule's cases (curve, smoothing, bounds, `price_after`); every fixture of spec 9's `trade_fixture.gd` builds; a picture of the catchments (a scratch run of `probe_mode_overlay.gd` colouring by market) and `trade_cache_cold_ms` on `PerfFixture.europe_war` in the pull request, for Opus, the art director and Fable. Lint, check_scripts, GUT green |

### Group C (after B)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| X7 | L, Sonnet | **Pacts, route states, tolls and the country step** | edit `core/systems/trade_pacts.gd` (fill: the queries, the four pairs, `apply_open_markets`), `core/systems/relations.gd` (the memories and standing terms of 4.8), `core/systems/trade.gd` (`route_state`, `closed_to`, `toll_rate`, `capacity`, `country_step`, `set_tolls_check`, `set_tolls`); `tests/core/test_trade_pacts.gd`, `tests/core/test_trade_war.gd` (new); edit `tests/core/test_relations.gd` | Spec 4.6 steps 3 and 4 (as `country_step`), 4.8 and 4.9: every row and planted fault of spec 9 for these tests but the phase's own cases (prices held, orders home, events on change: X13); order freeing reaches `Merchants.free`, tested in X9. Lint, check_scripts, GUT green |
| X8 | M, Sonnet | **Road works** | edit `core/systems/works.gd` (`build_road_check`, `build_road`; the works phase's halt, loss and finish of road works through `Roads.set_road`; `cost_of` for roads); `tests/core/test_road_works.gd` (new); edit `tests/core/test_works.gd` | Spec 4.10's checks and works: every row and planted fault of spec 9 for these tests; **done-when 5** (spec 4.15 e) on seed 1480. Lint, check_scripts, GUT green |

### Group D (after C)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| X9 | L, Sonnet | **Merchants** | edit `core/systems/merchants.gd` (fill: `count`, `orders_of`, `free_count`, `may_work`, `estimate`, `options`, `best`, the three pairs, `carry`, `book`, `free`); `tests/core/test_merchants.gd` (new) | Spec 4.7 and 5.3 for this file: **done-when 4** but T1's chain (which needs the phase: X13) and the reminder's Send (X19); 4.7's counts on seed 1480; every row and planted fault of spec 9 for `test_merchants.gd`; the freeing that X6 and X7 call (a closed market, an embargo's routes). Lint, check_scripts, GUT green |
| X10 | M, Sonnet | **The economy's seams** | edit `core/systems/economy.gd` (`ABROAD`, `market_of`, `market_prices`, `sale_price`), `core/systems/economy_season.gd` (`made_of`'s `by_market`; `production` writes `made_markets`; `money_lines` takes the sales value as an argument, which the income phase still fills with M4's fixed-price value until X13; `OWNS`), `tests/core/scenario_fixture.gd` (`with_trade`, and `TradeFixture.still` by default), `tests/core/trade_fixture.gd` (its Italian game asks for trade); edit `tests/core/test_economy.gd`, `tests/core/test_economy_season.gd` | Spec 4.11's `market_of`, `market_prices`, `sale_price` and `made_markets`: their cases of spec 9; no money or goods number of M4 to M9 moves (every earlier test green unchanged). Lint, check_scripts, GUT green |
| X11 | M, Sonnet | **The peace's open markets** | edit `core/systems/peace.gd` (`price`, the check's row, `apply`'s step, `best_deal`'s step), `core/views/peace_view.gd` (the row); `tests/core/test_peace_open_markets.gd` (new); edit `tests/core/test_peace.gd`, `tests/core/test_peace_view.gd` | Spec 4.8's open markets: every case and planted fault of spec 9; M9's pins of 4.22 green (no open markets in those deals). Lint, check_scripts, GUT green |
| X12 | S, Sonnet | **Knowledge and words** | edit `core/views/knowledge.gd` (`market_seen`, `prices_seen`), `core/views/words.gd` (spec 5.6's nine functions); edit `tests/core/test_knowledge.gd`, `tests/core/test_words.gd` | Spec 4.14 and 5.6 for these files: the fog's cases (P: an unknown market's prices shown is caught); every word. Lint, check_scripts, GUT green |

### Group E (after D)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| X13 | L, Sonnet | **The trade phase, the season table and the switch of sales** | edit `core/systems/trade.gd` (`season`, `close`), `core/game/season.gd` (16 `PHASES`, the trade phase), `core/game/actions.gd` (30 names, the pairs), `core/state/chronicle.gd` (forty notable kinds), `core/systems/economy_season.gd` (`goods_step` without sale; the income phase's `tax_goods` from `sales_open`), `core/views/economy_preview.gd` (the trade step at held prices, D48); `tests/core/test_trade.gd`, `tests/core/test_trade_duo.gd`, `tests/core/test_trade_preview.gd` (new); edit `tests/core/test_trade_prices.gd` (done-when 1's duo case), `tests/core/test_merchants.gd` (T1's chain), `tests/core/test_season.gd`, `tests/core/test_trade_war.gd` (the phase's cases), `tests/core/test_chronicle.gd`, `tests/core/test_insights_views.gd` (the pins of 16 phases, 30 actions, 40 notable kinds), `tests/core/test_economy_preview.gd`, and any M4 to M9 test outside X14's files that builds its game without `ScenarioFixture` and pins money or goods (moved onto `TradeFixture.still`; listed in the pull request) | Spec 4.6, 4.11's switch, 4.12 and 4.15 (a) to (c): **`PHASES` pinned as the sixteen**; the thirty actions and forty notable kinds; **done-when 1 and 2** on the duo fixture exactly; T1 on the chain; the preview property of spec 9 (200 cases); every step's case and planted fault of spec 9 for `test_trade.gd`; every M4 to M9 pin unchanged on `TradeFixture.still`; `trade_ms` measured once on the made-up Europe with a scratch trade fixture, in the pull request. Lint, check_scripts, GUT green |
| X14 | M, Sonnet | **The stats and the ring, the events, `Session`, the dev price** | edit `core/systems/stats_system.gd` (the four series, `income_trade`, the price ring, `Trade.close`), `core/systems/vision.gd` (`SIGHTED`), `core/game/game.gd` (`dev_price`), `core/game/replay.gd` (the dev record), `shell/autoload/events.gd` (fourteen signals), `shell/autoload/session.gd` (`drain`, `last_phase_ms`, `dev_price`); edit `tests/core/test_stats.gd` (the ring written), `test_vision.gd`, `test_game_core.gd`, `test_replay.gd`, `tests/shell/test_session.gd` | Spec 4.13's emitters and signals, 4.20, 5.4, 5.5: the fourteen signals drained after their phases; the ring holds the paid prices; the dev record replays to the same digest (P: a changed price gives another). Lint, check_scripts, GUT green |

### Group F (after E)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| X15 | L, Sonnet | **The market and trade views and the trade cards** | `core/views/market_view.gd`, `core/views/trade_view.gd`, `core/views/cards_trade.gd` (new); edit `core/views/cards_economy.gd` (the Stores chip at the home market's prices); `tests/core/test_market_view.gd`, `tests/core/test_trade_view.gd`, `tests/core/test_cards_trade.gd` (new); edit `tests/core/test_cards_economy.gd` | Spec 5.6 for these files and every part of 6.4 and 6.5 as data; the card's verdict equals the check's (P); the fog (P); `market_view_ms` and `trade_options_ms` measured once by a probe run, in the pull request. Lint, check_scripts, GUT green |
| X16 | M, Sonnet | **The road card and the works card's prices** | `core/views/road_preview.gd` (new); edit `core/views/improve_preview.gd` (market prices, the price line); `tests/core/test_road_preview.gd` (new); edit `tests/core/test_improve_preview.gd` | Spec 4.10's road card and 4.11's card lines: spec 4.15 (e)'s card exactly; every case of spec 9; M4's card cases green on `TradeFixture.still`. Lint, check_scripts, GUT green |
| X17 | M, Sonnet | **The map's read models: the Trade bytes, the route lines, the hex card** | edit `core/views/map_modes.gd` (`TRADE`, `trade_bytes`, the palettes, the ramps, the legends; relation bytes 14 and 15), `core/views/hex_card.gd` (the market line; the road and crossing summaries read the state); `core/views/trade_lines.gd` (new); `tests/core/test_trade_lines.gd` (new); edit `tests/core/test_map_modes.gd`, `tests/core/test_hex_card.gd` | Spec 6.3's byte tables (both palettes' distances), 6.8's Relations bytes, 5.6 for these files: every case and planted fault of spec 9; `trade_bytes_ms` and `trade_lines_ms` measured once. Lint, check_scripts, GUT green |
| X18 | M, Sonnet | **The Trade page's view, the country card, the history series, the matrix states** | `core/views/study_trade.gd` (new); edit `core/views/country_card.gd` (the trade section), `core/views/study_economy.gd` (4.11's history series), `core/views/study_diplomacy.gd` (the matrix states); `tests/core/test_study_trade.gd` (new); edit `tests/core/test_country_card.gd`, `test_study_economy.gd`, `test_study_diplomacy.gd` | Spec 5.6 for these files, 6.7's parts and 6.8's country states as data: every case of spec 9. Lint, check_scripts, GUT green |
| X19 | M, Sonnet (Opus reviews) | **The report, the log, the reminders** | edit `core/views/season_summary.gd` (the `trade` section, the chip, the treasury and goods lines, the price lines from the ring), `core/views/log_lines.gd` (4.13's lines and filters), `core/views/reminders.gd` (4.19's rules, `goods_running_out`'s words), `tests/fixtures/report_sample.gd` (a Trade section); edit `tests/core/test_season_summary.gd`, `test_log_lines.gd`, `test_reminders.gd`, `tests/core/test_merchants.gd` (the reminder's Send) | Spec 4.13, 4.18, 4.19: every sentence and rule with its planted fault; the section equal after a save and load; Opus reads the words. Lint, check_scripts, GUT green |
| X20 | L, Sonnet | **The proofs: the property, the contract, saves, the Italian game** | `tests/core/test_trade_property.gd`, `tests/core/test_trade_saves.gd`, `tests/core/test_trade_italy.gd` (new); edit `tests/core/random_player.gd` (the nine new actions), `tests/core/test_check_contract.gd`, `test_owns.gd` (the new actions and the trade phase), `test_forty_seasons.gd`, `test_money_property.gd` | **Done-when 1, 2 (the Italian halves), 7, 8, 9** as spec 9 lists them, each with its planted fault; the Italian game's numbers pinned as the build gives them. Lint, check_scripts, GUT green |
| X21 | M, Sonnet | **The perf rows** | edit `godot/tools/perf_fixture.gd` (`europe_trade`), `godot/tools/perf_core.gd` (spec 8's rows), `godot/tests/perf_core_budget.json` | Spec 8: every row printed and within its limit on the made-up Europe; a failed row takes section 8's fallback in this pull request. Lint, check_scripts, GUT green |

### Group G (after F)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| X22 | L, Sonnet (Opus reviews) | **The AI's trade** | `core/ai/ai_trade.gd` (new); edit `core/ai/ai_know.gd` (spec 5.7's functions), `core/ai/ai_brief.gd`, `core/ai/ai_turn.gd` (the trade step), `core/ai/ai_economy.gd` (road candidates and cards), `core/defs/ai_def.gd`, `core/defs/ai_temper_def.gd` (the new fields), `data/defs/ai.tres`, `data/defs/tempers/builder.tres`, `cautious.tres`, `steadfast.tres`, `aggressive.tres`, `opportunist.tres`, `conqueror.tres`, `godot/tools/ai_tables.gd`; `tests/core/test_ai_trade.gd` (new); edit `tests/core/test_ai_defs.gd`, `test_ai_know.gd`, `test_ai_door.gd`, `test_ai_economy.gd`, `test_ai_turn.gd`, `test_ai_fog.gd`, `test_ai_play.gd` | Spec 4.16 and 5.7: every case and planted fault of spec 9 for these tests (P: a pact off its think turn; `Merchants.` in a step module); `ai_season_ms` measured once on the made-up Europe, in the pull request; Opus reads the numbers on the first day. Lint, check_scripts, GUT green |
| X23 | M, Haiku | **The market panel** | `shell/panels/market_panel.tscn`, `shell/panels/market_panel.gd` (new); `tests/shell/test_market_panel.gd` (new) | Spec 6.4 from `MarketView` fixtures: every part, tab and state; Send asks for the order card; the tolls `Segmented` acts; the art director signs its pictures beside `12_market_panel_and_order.png`. Lint, check_scripts, GUT green |
| X24 | M, Haiku | **The order card** | `shell/screens/merchant_order.tscn`, `shell/screens/merchant_order.gd` (new); edit `shell/screens/screen_ids.gd` (`merchant_order`); `tests/shell/test_merchant_order.gd` (new) | Spec 6.5 from `TradeView` fixtures: the three steps, the keys, Send's verdict, Esc. Lint, check_scripts, GUT green |
| X25 | L, Sonnet | **The map: the Trade mode, the route lines, the marks** | edit `shell/map/mode_overlay.gd`, `shell/map/mode_overlay.gdshader`, `shell/hud/mode_legend.gd` (the lenses, the goods, the line kinds, Best order, Mine and All), `shell/hud/top_bar.gd` (the Trade segment), `shell/mapview/tile_map_view.gd` (`Routes`), `shell/mapview/edge_line_layer.gd` (the four route kinds), `shell/map/map_scene.gd` (6.3's functions, signals and refreshes; road lines, crossings and the "Track", "Road", "Highway" ribbons on `road_built`), `shell/input/map_input.gd` (`view_mode_8`; the route under a right click), `godot/tools/map/probe_mode_overlay.gd`; `shell/map/trade_marks.gd` (new); `tests/shell/test_trade_marks.gd` (new); edit `tests/shell/test_mode_overlay.gd`, `test_map_scene.gd`, `test_layer_stack.gd`, `test_map_input.gd` | Spec 6.3: the texture writes only changed texels (P: one byte, one texel); z 81 and 87; the probe's `--plant` FAILs; `trade_mode_ms` and `route_lines_ms` measured once. Lint, check_scripts, GUT green |
| X26 | M, Haiku | **The Trade page and the report screen** | `shell/screens/study/page_trade.tscn`, `shell/screens/study/page_trade.gd` (new); edit `shell/screens/study_pages.gd` (`LIST`), `shell/screens/season_report.gd` (the Trade section, its links); `tests/shell/test_page_trade.gd` (new); edit `tests/shell/test_study.gd`, `tests/shell/test_season_report.gd` | Spec 6.7 and 6.9's report from the view fixtures: every part and empty state; the ring chart's span; the links. Lint, check_scripts, GUT green |
| X27 | M, Haiku | **The panels and the kit's edits** | edit `shell/panels/hex_panel.tscn`, `shell/panels/hex_panel.gd` (the market line, the Roads section), `shell/panels/country_panel.tscn`, `shell/panels/country_panel.gd` (the Trade section), `shell/hud/map_hover.gd` (the market and price lines), `shell/screens/peace.gd` (the open-markets row), `shell/ui/preview_card.gd` (`show_road`), `shell/screens/works_preview.gd` (`show_road`), `shell/map/preview_marks.gd` (`show_road_marks`), `shell/ui/relation_matrix.gd` (`embargo`, `partner`), `shell/ui/resource_chip.gd` (`set_fraction`); edit `tests/shell/test_hex_panel.gd`, `test_country_panel.gd`, `test_peace_screen.gd`, `test_preview_card.gd`, `test_works_preview.gd`, `test_preview_marks.gd`, `test_relation_matrix.gd`, `test_resource_chip.gd` | Spec 6.6 and 6.8 from the card and view fixtures: every row, state and verdict; the refreshes. Lint, check_scripts, GUT green |

### Group H (after G)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| X28 | L, Sonnet | **Wire the App: requests, the chip, the console, Layers** | edit `shell/app/game_requests.gd` (6.10's table), `shell/app/app.gd` (the milestone `"10"`; under 800 lines), `shell/app/study_warm.gd`, `shell/hud/chips.tscn`, `shell/hud/chips.gd` (Merchants), `shell/hud/layers_popover.tscn`, `shell/hud/layers_popover.gd` (Trade routes), `shell/hud/hex_menu.gd` (the route items), `shell/hud/dev_commands.gd`, `shell/hud/debug_overlay.gd`, `shell/hud/task_flag.gd` (the `send_merchant` action), `shell/hud/action_log.gd` (route lines open the market), `shell/input/map_input.gd` (`game_market`, `market_requested`), `godot/README.md`; edit `tests/shell/test_app_flow.gd`, `test_chips.gd`, `test_hex_menu.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_task_flag.gd`, `test_notifications.gd`, `test_action_log.gd`, `test_map_input.gd` (P) | Spec 6.9, 6.10 and the end to end of spec 9 (`test_app_flow.gd`); **done-when 12** in the shell tests; still two autoloads. Lint, check_scripts, GUT green |
| X29 | L, Sonnet | **The soak and the trade report** | edit `godot/tools/soak.gd` (the ranges and the summary's columns), `tests/core/invariants.gd` (five invariants), `tests/core/test_invariants.gd`, `tests/core/test_ai_soak_quick.gd`; `godot/tools/trade_report.gd`, `tests/core/test_trade_report.gd` (new); edit `CLAUDE.md` (the `trade_tables.gd` and `trade_report.gd` lines in the Godot block) | Spec 4.17 and 4.5's report: every invariant (P each), the ranges and the summary; a full run of every suite on a runner by hand dispatch and a `trade_report.gd` run, the tables in the pull request; **Opus reads them before group J**. Lint, check_scripts, GUT green |

### Group I (after H)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| X30 | M, Haiku | **Monkey, pictures, the UI perf rows** | edit `tests/shell/test_ui_monkey.gd`, `godot/tools/ui/shot_ui.gd`, `godot/tools/ui/perf_ui.gd`, `godot/tests/perf_ui_budget.json`, `tests/fixtures/ui_sample.gd` (a market with orders, a closed route); the signed pictures as goldens (`godot/tests/goldens/m10_*.png`) | The monkey's invariants green on 3 seeds; spec 9's pictures at 1280 x 720 scale 1 and 2560 x 1440 scale 2, signed by the art director; spec 8's UI rows within their limits. Lint, check_scripts, GUT green |

### Group J (after I)

| ID | Size, who | Task | Files | Done when |
|---|---|---|---|---|
| X31 | M, Sonnet (Opus decides) | **The tuning pass** | edit `data/defs/goods/*.tres` (appetites), `data/defs/trade.tres`, `data/defs/ai.tres`, `data/defs/tempers/*.tres`, `tests/core/test_trade_defs.gd`, `test_good_defs.gd`, `test_ai_defs.gd` (the values), `tests/core/test_trade_italy.gd` (pins the tuned data moves), `godot/tests/goldens/m10_*.png` (re-made when a number on a picture moved, signed again), `docs/architecture/m10-build-spec.md` (4.5's appetites as `trade_tables.gd` prints them; 4.17's ranges where Opus changes one), `docs/architecture/m10-build-plan.md` (section 4's seed) | **Done-when 10**: every range of spec 4.17 on 100 `ai`, 20 `conqueror`, 20 `passive` and 4 `europe` games with the final data; 4.5's rule met (every made good's median 800 to 1,250 on `trade_report.gd`); Opus's verdict and the per-country table in the pull request; **the playtest's seed**: the first seed from 1480 on where Genoa's first-season best option is over 0, written into step 3 of section 4. Lint, check_scripts, GUT green |

---

## 3. Reviews

- **The code reviewer** reads every task.
- **Fable (technical director)** signs the state, the save format, the door fields and the phase's order (spec 5.2, 5.4, 4.21, 4.12)
  before group A starts; reads the interfaces of X2, X5, X6, X7, X9, X13 and X15 before they merge; reads X6's and X13's cold and
  phase times and X21's rows; reads X20's property and save tests and X29's invariants together.
- **Opus** reads X1's numbers on its first day, X6's catchment picture with the art director, X19's words, X22's temperament and
  `AiDef` numbers on its first day, reads X29's soak tables and trade report before group J and gives X31's balance verdict (a
  changed number is a data edit with the tests it moves, in X31's pull request).
- **The art director** signs X3's sheet, X6's catchment picture, X23's market panel beside `12_market_panel_and_order.png`, and X30's
  pictures (the Trade mode in both lenses with the lines, the market panel's tabs, the order card, the road card, the Trade page, the
  hex panel's roads, the country panel's trade, the report's section).
- **Pull requests** say what changes for the player. X2 makes M9 saves unloadable ("Made by an older test build"): said. X10 puts every
  earlier test on `TradeFixture.still`: said. X13 moves the sales to the markets and adds the trade phase, so every season's money
  moves with trade on: said, with the list of tests it moved. X22 changes what the other countries do: said, with the soak's tables. No test pins a
  digest value.

---

## 4. The owner's playtest of M10

On Windows (mouse) and on the MacBook (trackpad), with a fresh user folder.

1. New game, More, seed **1480**, Italy 1480, Play as **Genoa**. Press **8**: the Trade mode. Fourteen markets in six colours; Genoa's
   catchment reaches Savona and the Savoyard coast; the high Alps hatched (remote). Hover a hex: "Sells at Genoa's market". The
   legend: Markets | Prices.
2. Switch the legend to Prices and pick salt: every market is "near base" (the first season). End season. Prices again: the bands
   differ now. Pick wine, then grain.
3. Press **E**: Genoa's market panel. Opportunities: the sell rows with "a season" estimates; All goods: the prices and their sparks;
   Merchants 0/2 with "2 merchants idle: best is ..." (X31 writes the seed where the best is over 0 here: seed **1480** until then).
   The task flag says the same: press its **Send**. A gold line with a chip appears on the map.
4. In Opportunities press another row's **Send**: the order card. Step through the goods; read a source's "up to n · +n a season"
   and its hover ("n on offer after the free traders last season"). Send.
5. End season. The report (J): the Trade section ("... carried, +n"), Treasury's "Tolls at Genoa" and "Merchants" lines; the
   Merchants chip "2/2"; hover it. Open the market panel's Merchants tab: each order's last season; the numbers match the card's.
6. Press **I**, then `]` to Trade: the Prices table with sparks; select salt: the price ring; switch the span to 40 seasons; Your
   merchants; Tolls and trade; Show on map (the Trade mode with salt's prices).
7. F2: `price Genoa salt 6000`; End season: the report's price line for salt in Genoa; the treasury's "Goods bought" line if your
   salt was short. F2 `market Genoa` prints the prices.
8. Press C, then Milan's link: the country panel's Trade section ("Their tolls Normal"); **Sign a trade agreement** (its answer, or
   "they refuse: their opinion of you is ..."). Then **Declare an embargo**: the toast; the Milan – Genoa line turns grey and dashed;
   the notification that your merchant on it came home; press 7: Milan in the embargo colour; I, `]` to Diplomacy: "Embargo" in the
   matrix. End season: no tolls from that road; **Lift the embargo**.
9. Your market panel's Tolls: **High**; End season; hover the Milan – Genoa line: its capacity lower; the toll badge on Genoa.
10. Main menu, New game, seed 1480, as **Savoy**. Select (7, 10); the hex panel's Roads: "To (7, 11), SE: no road → a track and a
    ford · 20 · 2 seasons"; its (i): the road card ("Turin – Genoa: 17 → 11 points · 405 → 315 a load"). Begin the work. End two
    seasons: the "Track" ribbon, the ford on the map. Raise an army at Asti (M6) and plan a march across: the step costs 2.
11. As Savoy, declare war on Milan (M9's overlay): the Turin – Milan line turns grey ("closed by war: grain still passes"); hover your
    land beside Milan in the Trade mode: "Closed to you"; the report's Trade section names the closed road.
12. Layers popover: **Trade routes** on; press 2 (Owner): the lines stay. Options, Map: the same switch.
13. Main menu, New game, seed 1480, and in the pick F2 `watch`; `end 40`: the legend's **All**: the AI's merchants on the roads; F2
    `routes`: most routes carry goods; the Trade page of the watched game lists prices everywhere.
14. F5, F2 `digest`, F9, F2 `digest`: the same, with orders, pacts and a road under way; J shows the same Trade section.

---

## 5. Definition of done

1. The spec's "M10 is done when" items 1 to 13 hold.
2. Tasks X1 to X31 merged; CI green, with both UI `--check`s, `build_map --check`, `build_scenario.gd --check`, and the nightly
   `soak`, `soak-ranges`, `perf_core` and `perf_ui` jobs within their limits.
3. The pictures of spec 9 are signed and stored as goldens.
4. The owner has played the checklist of section 4 on Windows and the Mac.
5. `godot-architecture.md` 9.2 marks M10 done; `godot/README.md` describes the M10 game.
6. Section 7 below is handed to the M11 and M12 build specs' authors.

---

## 6. How to start

On the day M9 closes:

1. Opus presents the numbers (spec 4.4 to 4.10: the market rule and the 14 markets, the price curve and appetites, the merchants,
   the tolls, the pacts and the road costs) and the duo example (4.15 a) to the owner and Fable in 30 minutes; a changed number is a
   data line now, not a task later. Fable signs the state, the save format, the door fields and the phase's place the same day.
2. Start group A together: **X2** (Sonnet) and **X1, X3, X4** (Haiku). Opus reads X1's numbers on its first day.
3. X6 runs its catchment picture and its cold time on the made-up Europe in its last day, so section 8's fallback is chosen before
   X13 and X21 build on it.
4. X29's first full soak and trade report go to Opus the day they run; group J waits for Opus's reading.

---

## 7. What M10 hands on

- **M11:** techs changing `TradeDef` through definitions only (merchant capacity, merchants, the route cost a point, market reach, the
  tolls, the remote share); an idea card that brings idle orders home sooner (taken up in `m11-build-spec.md` 4.2 and 4.3).
- **M12:** debt and bankruptcy reading purchases and merchants' losses; no buying over the debt limit; orders home at bankruptcy;
  a fallen country's orders and pacts ended; `income_trade` and the markets held for the score; trade fairs as an event kind
  through `Trade.appetite`, if the events design wants them.
- **After M12:** ships and sea trade (sea routes, port capacity, naval blockade), river boats, overseas and colonial markets, the
  price revolution, trade companies, alliances' trade clauses, pact offers to the player, roads in reach fields.
- **E2, E3:** markets on Europe by the same rule; `market_reach` and the appetites re-tuned there; section 8's rows on the real map.
- **Saves:** `SaveFile.FORMAT` 8; a new body field with a default needs no bump (M3 4.10).
