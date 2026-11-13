# Reactive prices: harvests, war closing ports, trade fairs (design proposal)

Status: DRAFT for the owner (2026-11-13). Nothing here is approved or built. This is proposal T3 of `docs/reports/trade-fun-test.md`. The owner asked for the design note first, then a decision.
T1 (merchants after the background trade) and T2 (flagged orders, AI re-pick, "Re-pick best") are being built on a branch. This note assumes both.

## Questions for the owner

1. **Build order.** Build T3 after T1 and T2 are merged? Recommended: yes. A price shock is only fun if the player can answer it. T2's "Re-pick best" and the flags are that answer, and T1 makes the order card honest. Alternative: build harvests in parallel. They touch the same files and the same numbers, so it costs more than it saves.
2. **Does war close routes for food too?** Recommended: war closes every route between two markets whose owners are at war, except grain. Cutting grain would starve city markets in two seasons and become a siege weapon nobody asked for. Alternative: close everything (harsh, simple). Alternative: close nothing but luxuries.
3. **Scope of the first version.** Recommended: harvests first (with log line, panel banner and map marker), then war closing, then fairs as the last step. Harvests are small and safe. War closing changes AI income and tolls. Fairs need the most UI. Alternative: ship all three together.
4. **PRICE_CAP 3.5 to 3.0?** Recommended: no. Keep 3.5. I measured that a lower cap makes more goods flat, not fewer (section 6). If the identical cap-priced margins still bother you after T3, solve it with fairs and per-good caps, not with one global number.

## 1. What problem this solves

From the trade fun test (F5):

- Prices settle within 10 to 15 years of the start and stay put. Median yearly change is 0.0% for grain, wine, spices and sugar.
- Half of all luxury market-years sit at the price cap, so every cap-priced route shows the same margin.
- No harvest, war, blockade or event touches a price. The best route in 1500 is the best route in 1600. Trade is set-and-forget after the first setup.

T3 gives the market screen a reason to be opened again. Three small rules, each with a visible cause.

## 2. Rules

### 2.1 Harvests

- Once a year (in the spring season), each active market rolls `HARVEST_CHANCE` (0.12).
- On a hit, one of grain, wine, wool or cotton is chosen among the goods that market produces. The market's provinces make that good at `1 + swing` times their output for `HARVEST_SEASONS` (2) seasons. The swing is `+HARVEST_SWING` (0.25) or `-HARVEST_SWING`, with an equal chance.
- Only the market's own provinces are affected. Prices then follow from the normal supply and demand rule (`set_prices`). No price is set by hand.
- A market can have one harvest at a time. It cannot roll again until the last one has ended.
- Both owners, AI and player, are treated the same. Unowned and colonial markets roll too.

### 2.2 War closes ports

- While two countries are at war, a route whose two markets belong to those two countries is closed: no background trade, and merchants of either side on it deliver nothing.
- The merchant is freed at once and sent back to the pool, with a log line "Route closed by war: Lisbon to Seville". It is not counted as a dead order for T2's flags (it is not the player's mistake) and the AI re-picks it the next season.
- Grain is exempt (question 2).
- Peace opens the route again. Orders are not restored. The player or the AI picks again.
- Third countries are not affected. Only the direct route between the two enemies is closed in v1. (A blockade by ships in the sea lane is a later step. The war and naval designs come first.)
- Who owns a market is `market_owner(world, market)`, the owner of the market's town province. A captured town changes the owner at the next market refresh.

### 2.3 Trade fairs

- About every 16 seasons (`FAIR_EVERY`), one market with at least 3 routes holds a fair. Its demand for one good it does not produce, below the cap today, is multiplied by `FAIR_DEMAND` (2.0) for `FAIR_SEASONS` (4) seasons.
- The fair makes that good dear there, so every merchant who can bring it makes money. It is the "go there now" event that harvests are not.
- A fair never targets a good already at the cap (it could not move the price). Picking from the goods below the cap is what keeps luxuries in play.

### 2.4 What does not change

- `PRICE_FLOOR`, `PRICE_CAP`, `ELASTICITY` and `TOLL_SHARE` stay. The rules above only move supply and demand, and close routes.
- No random event for armies or taxes. Only markets.
- No change to the order of the season, except one new phase (section 7).

## 3. How big is the swing? (measured on the real code, one game)

I ran a seeded all-AI game on the Europe map (seed 1) to 1499, 1539 and 1599. For every active market that produces the good I re-computed the price with the market's own output cut or raised by 25% (the supply after trade, the demand unchanged, the real `set_prices` formula). Mean price change:

| Good | Markets (1499 / 1539 / 1599) | Output -25%, price | Output +25%, price |
|---|---|---|---|
| Grain | 25 / 29 / 33 | +18% (median +19%) | -12% |
| Wine | 14 / 14 / 14 | +38% / +26% / +28% (median +19 to +21%) | -14% |
| Wool | 23 / 24 / 24 | +26% / +21% / +16% (median +18%) | -11 to -12% |
| Cotton | 5 / 5 / 5 | +10% / +11% / +2% | -7% to 0% |

What this says:

- A bad harvest moves a price up 15 to 25% in most cases. A good harvest moves it down about 12%. The swing is felt, because a typical route margin is a few ducats on a base price of 1.5 to 3 for these goods.
- It is not wild. Prices stay between the floor and cap, and 2 seasons is short.
- Cotton hardly moves. It is a small market, and its supply is not the limit. Leave it in the list: it is a different case for the player to notice.
- Wine at the cap (17% of market-years today) ignores a bad harvest, because the price is already at its ceiling. It reacts to a good harvest only. That is fine.
- Events per year: with 25 to 33 grain markets and 14 wine markets, a 0.12 chance per market gives about five to seven harvests a year in the world. Not tested in a full game: the top route's change rate (the report's "every 2 to 3 years") is an expectation, not a measurement.

## 4. How the player learns of it

- **Log line (Money filter).** "Bad wine harvest at Bordeaux: wine +25% for 2 seasons." and "Good grain harvest at Lisbon: grain -12%." Shown only for markets the player owns, has a merchant order at, or has an order route through. Other events appear on the map only. This keeps the log from filling with five lines a year about Poland.
- **Market panel banner.** At the top of the panel: "Bad harvest: wine +25%, until summer 1503", with a small sheaf icon. Fairs: "Trade fair: cloth demand x2, until winter 1507".
- **Price trend arrows** (UI section 6). Next to each price in the Opportunities tables: up, flat or down, comparing the price now with the price one season ago (from `Market.history`). The threshold is 5%. The report said these arrows are all flat until T3 exists. With T3 they carry meaning. The 10-year strip stays for the long view.
- **Map.** In the markets mode, a small marker on a market with an event (a sheaf for harvests, a banner for fairs, a crossed-sword mark on a closed route). The legend lists the three.
- **Floating tag** on the market when an event starts, for the player's markets.
- **Closed routes.** The route ribbon turns grey with a cross and the hover card says "Closed by war until peace". The idle-merchant hint in the top bar says "Merchants 5/7, 1 closed by war".
- **Reminder at end of turn:** unchanged. A free merchant already gets one (T2).
- The market hover card shows the event and the seasons left, and the price strip marks the shock.

## 5. How the AI reacts

- With T2, the AI re-picks its best delivered-profit orders every season. A shock changes the margins, so the AI follows it with no new rule. This is the main reason to build T2 first.
- A merchant on a closed route is freed at once. The AI picks a new order the same season.
- The AI does not plan for an event. It does not stockpile. That is the player's edge and the reason the player will look at the market.
- No change to AI wars. Closing a route lowers tolls for both sides, which is a small brake on war; do not tune the war chance for it in v1. Measure it.
- The AI's own food: the grain exemption means its armies and cities are fed through a war. Bad harvests of grain raise the AI's army food cost for 2 seasons (food is bought at the market price). This is small.

## 6. PRICE_CAP: 3.5 or 3.0?

The report suggested 3.0 so that cap-priced goods stop looking identical. I tested it on the same game. Share of luxury market-goods at the cap, with the cap at 3.5 against 3.0:

| Date | At 3.5 | At 3.0 |
|---|---|---|
| 1499 | 25% | 34% |
| 1539 | 38% | 47% |
| 1599 | 54% | 61% |

(241 to 246 luxury market-goods in each snapshot.)

A lower cap puts 7 to 9 percentage points more goods on the cap, so more routes look the same. The reason is that luxuries are scarce nearly everywhere, and a lower ceiling is reached sooner. A lower cap would also make the spice margin smaller (24.7 to about 21). The identical-margin problem is a result of scarcity, not of the exact cap.

Recommendation: keep 3.5. The harvest goods (grain, wool, cotton) are not capped, so T3 works without touching it. Fairs avoid goods at the cap. If the player-facing sameness of luxuries stays a problem after T3, the options are a per-good cap (spices 4.0, sugar 3.0) or letting a fair lift a price up to 1.25 times the cap. Both can wait for a playtest.

## 7. Technical plan

- **One new season phase**, `events`, before `economy` in `systems/season.py` `PHASES`. It expires old events, rolls new harvests (spring only) and fairs, and emits the events. Because it is a phase and not part of `economy()`, a preview season (`economy(preview=True)`) rolls nothing and sees the current events. The order card and the real season agree.
- **The random stream** comes from a separate `random.Random` seeded from the world seed and the turn, not from `world.rng`. Saves reproduce, and battles and other draws are not shifted by the new draws.
- **State.** One new world attribute, `market_events`: a list of plain tuples `(market name, kind, good, value, until_turn)`. It goes in `WORLD_DEFAULTS` and is owned by a new `systems/marketevents.py` (`OWNS = ("market_events",)`). Events of a market that has gone (a name that no longer exists) are dropped.
- **Where they act.** In `economy()`: the output of a province in a market with a harvest is multiplied (next to `output_mult`), and a fair multiplies `market.demand[good]` before `set_prices`. War closing: `trade_route` and `merchants_trade` skip a route for which `route_closed(world, route)` is true. Grain is allowed through.
- **Events on the bus:** `market_event` (kind, market, good, value, seasons) and `route_closed`. The feed turns them into log lines. Add them to `CAMPAIGN_KINDS`. Handlers do not change the game.
- **A pair for the merchant freed by war:** no new player action is needed. `send_merchant_check` gets one more reason: "Closed by war". Add the case to the agents' random player.
- **The T2 flag** gets a reason field: `dead`, `closed` or `shock`. Only `dead` frees an order after 4 seasons.
- Size rule: the new module stays well under 800 lines; no function over 60 lines.

## 8. Numbers for `data.py`

```
HARVEST_CHANCE = 0.12      # per active market per year (rolled in spring)
HARVEST_SWING = 0.25       # output of the hit good, up or down
HARVEST_SEASONS = 2
HARVEST_GOODS = ("grain", "wine", "wool", "cotton")
FAIR_EVERY = 16            # seasons between two fairs in the world (about one in 4 years)
FAIR_DEMAND = 2.0
FAIR_SEASONS = 4
FAIR_MIN_ROUTES = 3
WAR_OPEN_GOODS = ("grain",)   # goods that still cross a route between two countries at war
```

`PRICE_CAP` stays 3.5. README gets a short "Events" table (the player-facing rules).

## 9. Save compatibility

- One new world attribute with a list default in `WORLD_DEFAULTS`. An old save loads with no events and plays as before. A newer save in an older build only carries an extra attribute in the world's `__dict__`, which is harmless, so no `VERSION` bump is needed. Check with `tools/save_compat.py` both ways.
- Closed routes are derived from the wars, so nothing else is saved. An old save with a merchant on a route between two enemies frees it in its first season.
- The behaviour oracle will show a change (new rules): this is a gameplay PR, not a refactor.
- `tests/test_season.py` pins the phase names in order. It changes in the same PR.

## 10. Mockups needed (before any build)

1. The market panel with a harvest banner and trend arrows in the Opportunities tables.
2. The markets map with the three markers (harvest, fair, closed route) and the legend.
3. The log lines and the floating tag.
4. A closed route ribbon and its hover card, and the top-bar merchant chip with "1 closed by war".

## 11. Smallest first version

- Harvests only, four goods, the numbers in section 8.
- The `events` phase, the state and the bus event.
- A log line, the market panel banner and a map marker. Trend arrows with a 5% threshold.
- The AI follows through T2's re-pick. Nothing else for the AI.

Second step: war closing with the grain exemption. Third step: fairs.

## 12. Build steps

1. Wait for T1 and T2 to be merged (question 1). Mockups 1 to 4 approved.
2. `data.py` constants. README events table.
3. `systems/marketevents.py` and the `events` phase. Tests: determinism (same seed, same events, preview rolls nothing), expiry, one harvest at a time, a harvest moves the price the way section 3 says.
4. Hook the output multiplier into `economy()`. Check the order card's preview equals the real season within about 10% with an event active (the same check T1 needs).
5. Bus events, feed lines (only for the player's stake), market panel banner, trend arrows, map marker.
6. Full-game measurement (3 seeds to 1650): events per year, top-route change rate, merchant profit per merchant, income shares, no new debt. Compare with the trade report tables.
7. War closing: `route_closed`, the exemption, the freed merchant, the T2 flag reason, UI for closed routes. Measure tolls and the AI war rate before and after.
8. Fairs. The target pick (below the cap, at least 3 routes). The banner and marker.
9. Save-compat run both ways; update `tests/test_season.py`.

## 13. Risks

- **Not tested in the engine.** Section 3 is a recomputation of prices on real markets, not a game run. The claims about route changes and player decisions are expectations.
- **Noise or nuisance.** If events are too frequent the market screen feels random and the player stops trusting the order card. The numbers are a start; step 6 decides. A safer first value is `HARVEST_CHANCE` 0.08.
- **Bad harvests can starve.** A grain harvest of -25% for 2 seasons lowers food satisfaction in the market. Growth reacts at `0.05 x (food - 0.9)` when food is under 0.9, so the effect is a small dent, not famine. Watch it in step 6.
- **War closing hits tolls and small trading states.** Genoa or Venice at war with a neighbour loses the stream between them. That is the intended cost of war, but check that no AI state goes into debt (the report found only three debt episodes in three games, all from merchants).
- **Preview and real must agree.** If the roll sat inside `economy()` the order card would lie again (the T1 problem). The separate phase prevents it. A test must keep it that way.
- **Cap-priced goods stay flat.** Fairs skip them and harvests do not touch them. Luxuries keep their sameness until the per-good cap idea (section 6) is tried.
- **UI load.** Three markers and a banner on a map that already has a trade layer. Keep the markers small and show them only in the markets mode.
- **Small seeds.** The numbers come from one game on one seed. Treat 10% differences as noise.
