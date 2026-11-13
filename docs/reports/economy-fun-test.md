# Economy fun test (full games, 1480 to 1650)

Date: 2026-11-13. Author: systems designer. Status: proposals only, nothing changed in the game code.
Covers roadmap M4 and section 5, "Economy: UI, gameplay and fun testing". Its twin is `trade-fun-test.md`.

## Open questions for the owner (read these first)

1. **What should surplus money buy?** From about 1560 (France) and 1600 (Portugal, Venice) the treasury grows without
   limit: 150,000 to 850,000 ducats by 1650. Flat extra costs do not fix it (tested). Do you want "Crown projects"
   (E1, my recommendation: a few big purchases that scale with the size of the economy), a harder army economy, or both?
2. **Should investment be a money decision?** Today tile investment pays back in 100 to 500 seasons (25 to 125 years),
   and a player who never invests earns the same. Is it meant to be cosmetic and a pop/need driver, or a real payback
   choice? (E2 makes it a real one, at 15 to 30 years.)
3. **Should High tax be a normal level or an emergency lever?** It cuts income by a third and the population by 80
   percent over a game. Is that the trap you want, or should it be a short war levy that expires? (E3.)
4. **Should the debt and bankruptcy design wait for E1?** Normal play never gets into debt (3 episodes in 3 games, none
   from armies). Bankruptcy has nothing to push against until money has somewhere to go.
5. **Research is out of this report's scope but looks too fast.** Large countries know 97 percent of the tree by 1650
   (target 70 percent) and make 16 to 35 research points a season late (target 2 to 6 for a mid-sized country). Do you want
   it handled in the same balance pass? (Numbers in finding F9.)

## Verdict

- The first 30 to 60 years work: money is tight, there are real choices, and small states stay tight all game.
- After the build-out is done (about 1580 for a mid-sized country) there is **nothing to decide**. The AI buys every
  useful thing it can and then piles up money. A human player will finish earlier than the AI.
- Three of the five obvious options are traps or dead: High tax (loses), tile investment (no return), and settlements /
  ports / marketplaces (negative direct return, only worth it for the slots they open).
- Low tax is the best level from about 1520 for almost everyone, and the game does not tell you.
- Debt does not happen in play.

## Method

Same as the trade report: the real world code, seeded AI games to 1650, all 49 countries on AI, seeds 1, 2 and 3,
means of 3 games. Focus countries: Portugal (POR), Venice (VEN), France (FRA), Palatinate (PAL, 18 provinces in 1480) and
Genoa (GEN). Scripted strategies are the AI with one rule overridden for the five focus countries (Idle, forced tax
level, No investment, No building). Throwaway variants changed one constant or rule at a time, never the repo. The
payback figures come from the engine's preview season: add one level instantly, compare the country's income, undo it.
Small countries swing up to 50 percent between seeds; I treat gaps under 20 percent as noise.

## Findings

### F1. The money curve (AI default, mean of 3 games)

Income per season / treasury:

| Country | 1490 | 1520 | 1550 | 1600 | 1649 |
|---|---|---|---|---|---|
| Portugal | 159 / 574 | 226 / 707 | 335 / 1,030 | 684 / 4,269 | 1,477 / 151,816 |
| Venice | 90 / 520 | 147 / 606 | 256 / 1,021 | 708 / 7,246 | 1,462 / 179,264 |
| France | 258 / 759 | 646 / 1,743 | 1,225 / 12,844 | 2,148 / 283,226 | 4,150 / 847,546 |
| Palatinate | 7 / 17 | 39 / 152 | 64 / 302 | 96 / 482 | 228 / 6,717 |
| Genoa | 33 / 197 | 71 / 414 | 136 / 654 | 240 / 3,202 | 414 / 35,374 |

How income is made (all countries): the manufactory share goes 24% (1490), 37% (1520), 42% (1550), 48% (1600); the production
tax stays near 20 to 29%, pop taxes 15 to 20%, trade falls 27% to 15%. Portugal in 1649 earns 580 from manufactories, 695 from
trade, 199 from pop taxes, 119 from production, and pays 102 in building upkeep and 14 for the army.

### F2. Hoarding: money has no job after about 1560 to 1600

| | Median AI treasury in seasons of income | 90th percentile |
|---|---|---|
| 1520 | 4.2 | 7.4 |
| 1550 | 4.2 | 8.4 |
| 1600 | 4.5 | **95** |
| 1649 | **44** | **213** |

- France passes 2,000 ducats in 1511 to 1516 and 50,000 in 1556 to 1564. Portugal passes 2,000 in 1545 to 1558 and 50,000 in
  1615 to 1626. Venice reaches 50,000 in 1615 to 1634. Genoa gets there in only 1 of 3 games (1633). The small German
  state stays under about 10,000. Small states are fine.
- The 2026-11-11 playtest saw 9,000 ducats by 1517 for an idle player with nothing to buy. The AI shows the same shape
  100 years later because it buys everything on the list first. The checklist is finite.
- The checklist runs out: the number of affordable tile investments drops from 25 to 30 (1480 to 1600) to 1.2 for Portugal and
  0 for Venice and Genoa in 1600 to 1650. France keeps 15 only because it owns 200+ provinces.
- Where the money went (Portugal, cumulative to 1649): buildings 160,000 (323 purchases), tile investment 31,000 (358),
  research funding 9,500 (159), recruiting 3,200 (63). Left unspent: 152,000.
- The AI makes 1.4 purchases a season (POR), 0.9 (VEN), 2.4 (FRA), 0.2 (PAL), 0.6 (GEN). A human has the same checklist.
- Armies are not a sink: army upkeep is 1% of income late (14 of 1,477 for Portugal), buildings 7%.

### F3. Do investments pay back? (engine preview, all four focus countries, five dates from 1482 to 1580)

Pooled over 1,000+ options per kind. "Never" means the option adds less than 0.01 ducats a season at that moment.

| Option | Typical cost | Never pays | Median payback of the rest | Best quarter |
|---|---|---|---|---|
| Tile investment, any level | 25 to 170 | 42% | 505 seasons (126 yrs) | 301 seasons |
| Toolmaker level 1 | 320 | 3% | 55 seasons (14 yrs) | 42 |
| Weaver level 1 | 280 | 21% | 49 seasons (12 yrs) | 33 |
| Toolmaker / weaver level 2 | 560 to 640 | 0 to 33% | 79 to 90 seasons (20 to 22 yrs) | 59 to 69 |
| Level 3 workshops | 840 to 960 | 0 to 25% | 138 to 1,400 seasons | 99 to 123 |
| Marketplace | 200 | 98% | over 1,000 seasons | 159 |
| Port | 150 | 100% | never | - |
| Village, town, city upgrade | 120 to 920 | 100% | never (net -0.2 a season after upkeep) | - |

- **Only manufactories are investments.** A first weaver or toolmaker repays in 8 to 18 years, and it is the one
  decision with a clear answer. Later levels lose value quickly because they saturate the input market.
- **Tile investment is cosmetic as money.** It adds +30% output per level, but the crown only takes 12% of that output's value.
  A 25-ducat level 1 gains 0.03 to 0.6 ducats a season. Proof: the "No investment" strategy earns the same as the AI
  default (POR 550 vs 529, FRA 1512 vs 1634, VEN 417 vs 516 and PAL 126 vs 86, all within noise).
- Settlements, markets and ports are doors (slots, growth, capacity), not returns. The panel does not say so.
- "No building" is clearly worse: POR 323, VEN 248, FRA 1166 against 529, 516, 1634 (-35 to -50%). Building is the economy.

### F4. Tax levels (whole-game mean income per season / population in 1649, thousands)

| | AI default | Always low | Always high |
|---|---|---|---|
| Portugal | 529 / 2,605 | **650** / 3,486 | 363 / 531 |
| Venice | 516 / 2,995 | 536 / 3,602 | 214 / 405 |
| France | 1,634 / 34,075 | **1,807** / 36,316 | 1,223 / 4,743 |
| Palatinate | 86 / 312 | 76 / 1,267 | 16 / 114 |
| Genoa | 181 / 1,043 | **236** / 1,369 | 83 / 62 |

- Early (1520) the levels are close: income POR 245 low / 226 normal / 228 high; GEN 71 / 71 / 70. Low costs nothing and
  starts paying by 1550. From then low is the best choice for almost everyone, because growth is +0.15% a season against
  0 (normal) and -0.2% (high). Compounded over 100 years that is a 2x population gap.
- High looks like +40% tax (a flat 1.4 multiplier), but taxes plus production tax are only about 35 to 40% of income, so
  the real gain is 5 to 15% for a few years, then the population is gone. The 2026-11-11 playtest's "free +12.6 a
  season" is real, and so is the 80% loss decades later. The cost is hidden in a tooltip.
- Low tax is a dominant strategy from about 1520. Normal is good for the first 30 years. High is a trap unless used for a short time.

### F5. How many real decisions per season? (human view)

Counts of affordable choices, mean over 3 games, sampled every 4 seasons. "Useful" means payback under 20 years (F3).

| Period | Tile investments | Build options | Merchant routes with a profit | Useful ones (my estimate) |
|---|---|---|---|---|
| POR 1480-1500 | 25 | 26 | 12 | a few workshops, a few orders |
| POR 1540-1600 | 29 | 58 | 30 | about 3 workshops, about 3 orders |
| POR 1600-1650 | 1 | 66 | 45 | 0 to 2 |
| VEN 1500-1540 | 32 | 14 | 21 | about 3 workshops, about 3 orders |
| PAL 1500-1540 | 11 | 4 | 11 | 1 to 2 (every ducat matters) |

- Each province gets one job a season, so a human with 30 provinces still has only a few choices that matter, and **the
  ranking is hidden**. All 25 tile options look alike and pay back in decades. The long list is noise, not choice.
- Real decisions per season for a mid-sized country: 3 to 5 in 1480-1540, 1 to 2 in 1540-1600, 0 after. For a small
  country 1 to 2 all game.
- Once the money piles up, "End Turn" is the only button.

### F6. Idle player (set and forget)

| Idle strategy | POR | VEN | FRA | PAL | GEN |
|---|---|---|---|---|---|
| Whole-game mean income (AI default for comparison) | 146 (529) | 98 (516) | 448 (1634) | 15 (86) | 31 (181) |
| Provinces at 1649 | 21 (63) | 34 (40) | 154 (221) | 10 (5) | 7 (10) |
| Treasury at 1649 | 98,968 | 66,754 | 303,342 | 10,635 | 21,394 |

Doing nothing earns 15 to 30% of the AI's income. Portugal, France and Venice lose provinces to neighbours (Portugal 63 to 21), but all still end rich (Portugal
99,000). Idle also never researches (4 techs at 1649). The game punishes idleness with war, not with money.

### F7. Debt

- 3 debt episodes in 3 full games (49 countries, 170 years each). All three were merchants losing money (-16 to -43 a
  season), not armies. One country (Granada, 14 provinces) stayed in debt for about 60 years.
- Forcing High tax for small states (PAL) gives deficits in 1520 to 1550 (treasury -76 and -40); 5x upkeep (see F8) sends
  PAL into debt. So debt exists only where the rules are pushed hard.
- Debt limit (300 ducats or 6 seasons of running costs) is far below hoard sizes: an economy 10 times bigger than its
  costs never sees it.

### F8. What the number levers do (variants, 3 games each)

| Variant | Change | Effect on whole-game income | Hoard (median treasury in seasons of income, 1649) |
|---|---|---|---|
| AI default | - | POR 529, VEN 516, FRA 1634, PAL 86, GEN 181 | 44 |
| Higher upkeep | buildings x5, units x3, works/settlement/castle x5 | POR 341 (-35%), VEN 187 (-64%), FRA 1155 (-29%), PAL 7 (debt), GEN 154 | not measured; POR 54k, FRA 526k |
| Admin levy | 30% of gross income above 300 | POR 535, VEN 398 (-23%), FRA 1407 (-14%), PAL 79, GEN 162 | 33 (p90 200) |
| Manufactory tax 0.35 to 0.20 | `MANUFACTORY_TAX` | POR 573, VEN 310 (-40%), FRA 1303 (-20%), PAL 38, GEN 140 (-23%) | **8** (p90 173) |
| Production +, works +, manufactory - | `PRODUCTION_TAX` 0.25, `WORKS_BONUS` 0.45, `MANUFACTORY_TAX` 0.25 | POR 779 (+47%), VEN 608 (+18%), FRA 2339 (+43%), PAL 229, GEN 237 (+31%) | higher; POR 304k, FRA 1.3M |

- A flat cost increase hits small states first (Palatinate falls into debt) and leaves France with 526,000.
- A percentage levy (admin) reduces income but leaves the hoard intact: the remaining 70% still piles up. **A tax is not a
  sink. Something has to be worth buying.**
- Trimming the manufactory share does shrink the hoard (44 to 8 seasons of income), and the AI keeps building until
  about 1650 rather than finishing at 1590. That tells us the hoard is a content-exhaustion problem: the longer the
  list lasts, the longer the game stays interesting. The cost is a 20 to 40% income loss for Venice and Genoa.
- Raising the production tax and the works bonus makes tile investment pay (see E2) but pushes income up 20 to 45% and the hoard with it. It needs E1.

### F9. Research pace (side note, not this report's task)

Research points a season: POR 2.1 (1490), 6.1 (1520), 10.6 (1550), 16.4 (1600), 35.5 (1649). France 139 in 1649. Mid-sized target
is 2 to 6. Of Portugal's 16.4 in 1600, 13.7 comes from "burghers / 40". Techs known (of 37 grid techs): POR 12 at 1520, 19 at 1550,
29 at 1600, 36 at 1649 (97%); PAL 23 (62%). With burghers / 100 the same game would give POR 8.2 (1600) and 17 (1649), still above
target. A tech every 3 to 5 years is right until 1600; after that the tree is simply used up.

## Owner's decisions (2026-11-13)
- **E1:** design the Crown projects next, then decide.
- **E2 yes, in full:** `PRODUCTION_TAX` 0.25, `WORKS_BONUS` 0.45, `MANUFACTORY_TAX` 0.25.
- **E3 yes, both:** the tax hover forecast (income and population in 10 and 25 years), and High as a temporary emergency lever.
- **E4 yes:** buildings say what they are for. A production building also shows what it adds to the income each season.
- **E5 yes:** auto-recall an order that lost money two seasons in a row.
- **E6 yes:** bankruptcy waits until the Crown projects exist.

## Proposals, ranked by value

### E1. Crown projects: a sink that scales with the economy (rule change, needs a design)

- **Change:** a short list of big, repeatable purchases with escalating cost: for example Court (+research), Royal road
  (supply and march speed), Navy yard (cheaper ships), Bank (+tax, relieves High tax growth penalty), Cathedral and Palace
  (score points). First purchase costs `PROJECT_COST = 10 x gross income per season` at that moment, and each repeat is
  x1.5. They are one purchase each (no builder unit), usable once per few seasons.
- **Why:** F2 and F8. The levy test shows costs reduce income but not the pile. The problem is the empty list.
- **Expected effect:** with these costs Portugal in 1600 (income 700) needs 7,000 and in 1649 (1,477) needs 15,000, so a
  saved-up 150,000 buys about 6 to 8 projects over 50 years: a decision every 5 to 10 years, and hoarding becomes
  "saving for the next one". Median hoard should settle under 15 seasons of income. Untested in the engine (new content).
- **Also needed:** the AI buys them too, or it hoards forever. Score points from them also fix the playtest's missing goal.

### E2. Make investment pay (numbers)

- **Change:** `PRODUCTION_TAX` 0.12 to 0.25, `WORKS_BONUS` 0.30 to 0.45, `MANUFACTORY_TAX` 0.35 to 0.25.
- **Measured (tested exactly this):** tile investment pays 3.1 times faster: median payback from 126 years to about 40
  years, best quarter about 25 years. Whole-game income per season: POR +47%, VEN +18%, FRA +43%, GEN +31%, PAL +160% (noisy).
  Late manufactory share of income falls, early land share rises, so the first 60 years feel richer.
- **Risk:** richer players and richer AI, bigger hoard if E1 is not built. If you want to keep totals flat, drop
  `PRODUCTION_TAX` to 0.20 and keep the rest. A level 1 would then repay in about 55 seasons, in line with workshops.
  Also consider making level 1 and 2 cost more (`WORKS_COST` x2) once the return is real, so the choice stays tight.

### E3. Taxes: show the trade-off, soften High (UI plus one number)

- **Change:** show the 10 and 25 year projection of income and population per level on hover (UI section 7 already
  previews the income; add population). Make High an emergency lever: `TAX_GROWTH["high"]` -0.002 to -0.0012 and a rule
  that High reverts to Normal after 12 seasons, so it works as a war levy, not a lifestyle.
- **Expected effect (calculated, not run):** the compounding gap in population against Normal over 100 years shrinks by about a third (before food limits), and
  Low stays the best long-run level with a visible price (income 0.7x). That keeps a real Low versus Normal timing choice
  (Normal until about 1520, Low after).
- **Alternative:** leave the numbers and fix only the information.

### E4. Tell the player what each building is for (UI, no numbers)

- Village/town/city, marketplace and port show "unlocks N slots / +trade capacity / net -0.2 a season" instead of a payback.
  Workshops show a real payback in years (8 to 18 for level 1). The "Best here" hint should skip tile levels while they
  pay 100+ years, or label them "cosmetic".

### E5. Stop the quiet trade debt (rule, small)

- A merchant order that lost money two seasons in a row is recalled automatically, for the player and the AI. Prevents the
  60-year Granada case and costs nothing else. Details with T2 in the trade report.

### E6. Hold bankruptcy until E1 (scheduling)

- Do not build the bankruptcy model until money has a use; test it with a high-upkeep variant (F8) or with E1 in place.

## What UI section 7 (Economy) should show

1. **Treasury window:** "Money in" and "Money out" as proposed. Add a line "Unspent for N seasons" and a seasons-of-income
   figure ("your treasury is 44 seasons of income"). It is the honest warning the playtest asked for.
2. **"What to build next" payback bars:** calibrate the colours to the measured spread. Green under 20 years (workshops
   level 1), gold 20 to 50 years, amber over 50. With today's numbers every tile investment is amber and every settlement
   is grey ("unlocks slots"). That is accurate, but it will look empty until E2 or E1.
3. **Tax buttons:** preview income now and the population in 10 and 25 years for each level. Today the real cost of High is
   invisible.
4. **Investment hint card:** show "cost 25, +0.1 a season, pays back in 250 seasons". It will be honest and a little
   discouraging, which is the finding.
5. **History tab:** 12 seasons are enough to see the early game, not the hoard. Add a 10-year view and the seasons-of-income
   figure for the long run.
6. **Earns most / Costs most:** list manufactories and tolls separately. At 1600 manufactories are about half of income and a
   player who does not see that cannot judge E2.
7. **Debt tab:** keep, but expect to be empty in normal play until E1 is in.

## Risks and unfinished

- Three seeds per variant; the small-state numbers move up to 50% between seeds. The shapes (F2, F3, F4, F6) are the same in all three games.
- The preview payback ignores long-run pop growth that a village or marketplace may bring, so the "never" rows are direct returns only.
- The admin levy, higher upkeep and E2 package were run; E1, E3's softened High, E5 and the research change were not.
- Variants alter the world (the AI reacts), so before/after differences include drift.
- The AI's buying rules (reserve = 80 plus 3x income) probably leave money idle on purpose; I did not change them. A smarter AI would raise AI incomes and lower hoards a little.
