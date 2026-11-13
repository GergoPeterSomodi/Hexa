# Trade fun test (full games, 1480 to 1650)

Date: 2026-11-13. Author: systems designer. Status: proposals only, nothing changed in the game code.
Covers roadmap M4 and section 5, "Trade: UI, gameplay and fun testing". Its twin is `economy-fun-test.md`.

## Open questions for the owner (read these first)

1. **Should merchants be able to carry imported goods?** Today a merchant only moves goods that the source market
   produced this season. Venice and Genoa cannot "buy in Alexandria, sell in Cologne", which is the whole point of a
   trading nation. Proposal T1 changes the order of two steps in the season. Do you want re-export trade (my
   recommendation), or should merchants stay a "sell your own surplus" tool?
2. **Is passive toll income meant to be a main income?** Owning a market pays tolls with no action: 25 to 54 percent of
   a trading country's income all game. Should it stay, or should merchants (the player's decisions) earn more of the
   share? (T4.)
3. **Should prices move on their own?** Today they sit still. Do you want harvests and blockades to shake them (T3)?
   This is new content, not a number change.
4. **Is the AI allowed to get better at trade?** T1 and T2 help the AI as much as the player. If you want the player to
   keep an edge, the AI merchant logic must stay as it is. I assume you want the AI fixed too.
5. **Where does the trade layer go on the map** (UI section 6, option A "inside the markets mode" or B "fifth mode")?
   I recommend A, with a "Trade" toggle inside Markets mode, because the data it needs is all market data.

## Verdict

- Trade is the biggest money lever of the first 60 years, and almost nobody uses it well. It then fades into passive
  tolls.
- **The order card lies.** The best-looking order is usually worth nothing. In 18 of 20 checks, the top-ranked order
  delivered zero goods. The AI falls into the same trap: 78 to 88 percent of its merchant-order seasons carry nothing.
- Prices hardly move, so there is no timing, no arbitrage race and no reason to look at the market after the first
  setup. It is set-and-forget.
- A small state with two markets can double its income by re-picking orders every season, so the decision is real, but
  the game does not show what you would gain.

## Method

- Engine: the real world code, seeded AI games, all 49 countries on AI, 684 seasons each (to 1650). No game code was
  changed. Variants were done by overriding a rule or a constant in a throwaway script.
- Focus countries: Portugal (POR), Venice (VEN), France (FRA), Palatinate (PAL, a small German state with 18 provinces
  in 1480), Genoa (GEN). In each variant run, all five follow the stated rule and the other 44 countries stay on the
  normal AI. Seeds 1, 2, 3. Numbers below are means of 3 games. Small countries swing by up to 50 percent between seeds,
  so read differences under 20 percent as noise.
- "Scripted strategies": Idle (no actions), No merchants, Max merchants (re-pick the best orders every season),
  Low tax, High tax, No investment, No building. The normal AI is the baseline ("AI default").
- A separate probe tested single orders: send one merchant on an order, run a preview season, read what it delivered.
  This is how I compared "shown" against "delivered".

## Findings

### F1. Trade is the early economy, then fades (income shares, all countries, mean of 3 games)

| Year | Production tax | Pop taxes | Manufactory profit | Trade (merchants + tolls) |
|---|---|---|---|---|
| 1490 | 29% | 20% | 24% | 27% |
| 1520 | 22% | 15% | 37% | 26% |
| 1550 | 20% | 15% | 42% | 23% |
| 1600 | 20% | 15% | 48% | 17% |
| 1649 | 23% | 18% | 45% | 15% |

Small countries (12 provinces or fewer) depend on it far more: 44 percent of income in 1520, 55 percent in 1550.
In this table the share for trade is merchants plus tolls. The split for the focus countries:

| Country and years | Merchant profit | Tolls | Mean income per season |
|---|---|---|---|
| POR 1480-1520 | 45% | 30% | 168 |
| POR 1560-1620 | 14% | 31% | 575 |
| POR 1620-1650 | 7% | 25% | 1193 |
| VEN 1480-1520 | 38% | 19% | 105 |
| VEN 1560-1620 | 8% | 14% | 593 |
| GEN 1480-1520 | 21% | 54% | 47 |
| GEN 1560-1620 | 3% | 38% | 221 |
| PAL 1520-1560 | 61% | 0% | 57 |
| FRA 1520-1560 | 0% | 9% | 1015 |

A merchant is worth about 12 ducats a season for Portugal and 9 for Venice on the AI's default orders. A player who
leaves merchants idle (as the 2026-11-11 playtest did) gives up more than half of Portugal's 1490 income (about 160 a
season, of which 85 is merchant profit and 39 is tolls).

### F2. The order card promises money the merchant cannot carry (broken)

Cause: `merchant_options` reads each market's supply at the end of the season, after background trade has added
imports. But in `economy()` the merchants run before the background routes, so they can only carry what the source
produced that season, minus half its local demand. Anything the market holds because of imports is invisible to them.

| Test (single order, preview season) | Result |
|---|---|
| Top-ranked order by shown profit, 20 checks (5 countries x 4 dates) | delivered about zero in 18 of 20 |
| Typical phantom orders | spices Genoa to Barcelona shown +153 and delivers 0; cloth Naples to Lisbon shown +54 delivers 0 |
| Best 12 shown orders, summed (VEN, 1550) | shown 522, delivered 404 (a good case) |
| Best 12 shown orders, summed (FRA, 1550) | shown 593, delivered -4 |
| AI orders across the whole world, 1490 / 1510 / 1520 | 78% / 86% / 88% of order-seasons carry zero goods |

The 2026-11-11 playtest's "+69 for wine Lisbon to London" was real, because Lisbon produces wine. Real orders exist
(typically 3 to 7 of the top 12), but the sort order puts the phantom ones first. A new player will click the top
entry, lose a season, and conclude merchants are useless. The ranked list is the worst possible guide.

### F3. The AI wastes most of its merchants

Share of seasons in which the country had merchants out but they earned nothing (3 games):

| | POR | VEN | FRA | PAL | GEN |
|---|---|---|---|---|---|
| AI default | 29% | 33% | 64% | 72% | 86% |
| Max merchants (re-picked every season) | 63% | 36% | 51% | 46% | 54% |

The AI picks orders once and never re-checks them unless they lose money (they usually earn exactly zero, so they stay
forever). Re-picking every season, even with the lying card, raises the whole-game mean income per season:

| Country | AI default | Max merchants | Change |
|---|---|---|---|
| VEN | 516 | 663 | +28% |
| PAL | 86 | 192 | +120% (noisy) |
| FRA | 1634 | 1927 | +18% |
| POR | 529 | 551 | +4% |
| GEN | 181 | 197 | +9% |

Portugal gains nothing because its good orders are its own wine and salt, which the default already found.

### F4. Merchants matter most early and to small or middle states

Whole-game mean income per season, No merchants against AI default: POR 528 vs 529, VEN 307 vs 516 (-40%), PAL 30 vs 86
(-65%), GEN 158 vs 181 (-13%), FRA 1757 vs 1634 (no loss). For the first 70 years Portugal loses 40 to 45 percent without them
(1520: 124 vs 226, 1550: 209 vs 335). After about 1580 merchant income is flat (80 to 100 ducats a season for Portugal
from 1490 to 1650) while everything else grows 10 times, so a merchant is a rounding error by 1600. Number of merchants
grows from 2 to 9 (rule: 1 + market owned + marketplace levels / 3 + techs), so late game has more idle capacity than
profitable cargoes.

### F5. Prices do not move (set-and-forget)

Sampled once a year in all markets over 3 games:

| Good | Median yearly change | 90th percentile | Market-years at price cap (3.5x) | at floor (0.3x) |
|---|---|---|---|---|
| Grain, wine, spices, sugar | 0.0% | 0.7% to 1.9% | wine 17%, spices 51%, sugar 74% | 0% |
| Cloth | 0.7% | 2.2% | 13% | 0% |
| Tools, weapons | 0.3 to 0.5% | 9.6% / 13.2% | 2% / 0.2% | 0% / 4% |
| Tobacco, coffee, dyes | 0.0% | under 1% | 68% / 52% / 42% | 0% |
| Timber, stone | 0.0% | 3.9% / 13.2% | 0% / 2% | 58% / 34% |

- Prices settle within 10 to 15 years of the start and stay put. Prices fall in a smooth glide as workshops are built:
  cloth averages 3.0x base in 1485, 1.9x in 1550. The world's mean luxury price (sugar 3.3x to 2.65x) hardly moves.
- Half of all luxury market-years sit at the cap, so every cap-priced route shows the same margin (spices: 24.7 ducats
  a unit to any market). Route choice among them collapses to "whichever has stock", and the price tells you nothing.
- Prices only change when someone changes supply. No harvest, war, blockade or event touches a price. A player who looks
  at the market in 1500 sees what they will see in 1600.

### F6. Tolls are the quiet winner

Owning a market town gives 10 percent of every route's profit passing through, with no effort. Portugal earns 54 a
season from tolls in 1500 and 340 in 1649, a steady 25 to 33 percent of income. Genoa earns 20 (54 percent) to 124
(32 percent). The sum of all route profit in the world grows from 1,544 a season (1485) to 12,721 (1640) because more
markets open and routes get bigger, and the market owner's share grows with it. This is the dominant strategy: own
market towns, press End Turn. It also makes the merchant (an active choice) worth less than the passive stream.

### F7. Dominant strategies and dead options

| Strategy or option | Evidence | Verdict |
|---|---|---|
| Own market towns and sit | tolls 25 to 54% of income, no action | dominant, boring |
| Re-pick merchants each season | +18 to +120% for VEN, FRA, PAL | strong, hidden by F2 |
| Fixed export of local surplus (wine, salt, cloth) | what the default AI does and the only reliable cargo | safe default |
| Re-export cap-priced luxuries | impossible now (F2) | missing, the Venice/Genoa fantasy |
| More marketplaces for capacity | marketplace pays about -0.2 a season on its own | dead as money |
| Merchant after 1600 | flat 80 to 100 a season | dead |

### F8. Debt from trade losses (small, but odd)

In 3 full games with 49 countries, only 3 debt episodes happened, and all came from merchants losing money (trade
-16 to -43 a season, no army). One lasted 60 years (Granada, from 1575, 14 provinces, income of trade -42.8 a season
while production and taxes added 8). Armies never caused debt. The AI recall rule only recalls an order after it loses
and does so once a season, so a recalled order can be re-sent. This needs a look but is not a priority.

## Owner's decisions (2026-11-13)
- **T1 yes:** merchants run after the background trade.
- **T2 yes, all three parts:** flagged and freed dead orders, the AI re-picking its best orders, and the player's "Re-pick best".
- **T3:** write the design note, then decide.
- **T4 not now:** revisit after T1 and T2.
- **T5 yes:** the starter nudge. Merchant capacity stays 12 unless T1 proves too weak.

## Proposals, ranked by value

### T1. Run merchants after the background trade (rule change, one reordering)

- **Change:** in the season, process merchant orders after the background route trade instead of before. A merchant can
  then buy any stock the source market holds, imports included. No numbers change.
- **Why:** F2. The card then shows what is delivered, and Venice, Genoa and Antwerp can become real hubs.
- **Measured (3 games, normal AI):** dead order share POR 29 to 6%, FRA 64 to 24%, GEN 86 to 64% (PAL unchanged at
  about 93%). Merchant profit per merchant: POR 81 to 205, FRA 22 to 58, GEN 11 to 38. Whole-game mean income per season:
  POR 529 to 869 (+64%, partly seed noise), GEN 181 to 202, FRA 1634 to 1710, VEN 516 to 483 (noise).
- **Risk:** Portugal gains most, which is fine. Merchant profit stays 7 to 20 percent of income late, so it does not
  break the economy. Check once built that the preview and the real result agree within about 10 percent.

### T2. Standing orders that report back, and a smarter AI (rule + AI change)

- **Change:** (a) an order that delivers nothing for 2 seasons in a row is flagged, then returned to the pool after 4;
  (b) the AI re-picks its best orders every season (the "Max merchants" script, which is about 40 lines);
  (c) the player gets a one-click "Re-pick best" that applies the top delivered-profit orders.
- **Measured:** the Max merchants script: +28% VEN, +18% FRA, +120% PAL. Dead order share falls from 64 to 51 percent
  for France even with the lying card, and far further with T1.
- **Cost:** the AI gets richer too (world merchant profit +17%). I recommend taking that, because the AI's trade is
  currently the weakest part of its play.

### T3. Prices that react (rule change, new content)

- **Change:** each market, each year, rolls a harvest: grain, wine, wool and cotton output at that market's provinces
  at +/-25 percent for one or two seasons (about 1 market-year in 8 is hit). War closes the enemy's ports for trade. A
  trade fair event every few years makes one good demand 2x for 4 seasons at one market.
- **Why:** F5. Gives the first reason to look at the market screen again after 1500. Today the best route in 1500 is the
  best route in 1600.
- **Expected effect:** the top route changes about every 2 to 3 years; with T2's flags a player has a decision every few
  seasons. Not tested in the engine (new rules). Needs a design note before building.
- **Numbers to start with:** `HARVEST_SWING = 0.25`, `HARVEST_CHANCE = 0.12` per market per year, duration 2 seasons.
  Also consider `PRICE_CAP` 3.5 to 3.0 so cap-priced goods stop all looking identical (spices margin 24.7 to 21).

### T4. Make tolls reward activity (number change plus an option)

- **Change:** `TOLL_SHARE` 0.10 to 0.06, and let a market's owner keep the full 0.10 only on routes where the owner has
  a merchant working.
- **Measured (the plain 0.06 test):** whole-game income per season for GEN 181 to 133 (-26%), VEN 516 to 377 (-27%), POR
  and FRA unchanged; the AI stays solvent. Tolls fall from 25 to 54 percent of income to roughly 15 to 30 percent.
- **Risk:** hurts small trading states most (Genoa). Pair with T1 so their merchants earn the difference. Choose this
  only if you want the player's actions to matter more than the map.

### T5. A merchant starter nudge and a visible cap on capacity (UI plus a small number)

- **Change:** the first time a merchant is free, show the best delivered-profit order with one click (playtest M2).
  Consider `MERCHANT_CAPACITY` 12 to 14 once T1 is in, so a hub order is worth about 30 to 40 ducats a season early.
- **Expected effect:** a new player sees the lever in the first 5 seasons. Capacity change is untested; leave it unless
  T1 turns out too weak.

## What UI section 6 (Trade) should show

The UI proposal is good. These parts must be backed by delivered numbers, not shown ones:

1. **Opportunity tables:** the profit column must be what the merchant would deliver, with the stock behind it ("6 units
   in stock, 3 produced here"). With T1 this equals stock; without T1, mark imports as "cannot carry".
2. **Last 4 seasons per order** (already planned): the single most useful column. A grey "delivered 0" chip would have
   caught every dead order in this test.
3. **A badge for dead orders** on the ribbon and a count in the top bar ("Merchants 5/7, 2 idle-by-failure").
4. **Tolls as their own line** in the hover card, next to merchant profit, so the player sees the passive stream and what
   their merchants add on top.
5. **Price trend arrows** only mean something once T3 exists. Until then they are all flat: show "stable" and a 10-year
   price strip instead.
6. **"Best route" shortcut** should rank by delivered profit, then by profit per merchant.
7. **Competition here:** the data exists (other countries' orders on the same route eat the same supply). Show it, because
   it is what makes a route "taken".

## Risks and unfinished

- Three seeds per variant. Small-country figures are noisy. The conclusions I would stake the proposals on (F2, F3, F5,
  F6) show in all three games.
- Variants change the world after year 10 (the AI reacts), so before/after differences include random drift.
- The single-order probe used the engine's own preview season, which leaves the real state untouched; it matches the
  actual per-order results seen in full games (zero-goods shares).
- T3 and the re-pick flag are not tested in the engine. Everything else above was run.
- The toll figures in the tables are recomputed at the base 10 percent. Late in the game tech bonuses lift real tolls by up
  to 1.3 times (Portugal 1600: trade 300, of which merchants 90 and tolls 163 at base rate), so passive income is a little larger than shown.
- Colonial trade and the Atlantic routes were not studied separately in this pass.
