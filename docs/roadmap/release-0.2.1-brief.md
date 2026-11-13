# Release 0.2.1 brief: DRAFT

**DRAFT. Locked after the owner plays v0.2.0.** Planning on paper only: no 0.2.1 code starts until v0.2.0 ships (docs/studio.md,
"How a release runs"). Reviewed by the creative director on 2026-11-13 (note at the end); the owner has not decided yet.

## Theme

**The battle board.** Battles get their second row (back line, refill, rotation), the AI stops making blobs, and the battle
panel docks beside the map so you can watch the fight and the map at once. One war patch, no new systems, no economy changes.

Principles it is for (docs/research/fun-principles.md v2): **11** readable and light to run, **2** trade-offs, **12** the AI is a
rival. Checked for harm: 1 (no new clicks a season), 3 (the odds card and the rotation toggle must show the price, see changes
below), 6 (instant rotation is a snowball, so it is not allowed), 14 (ranks that relieve each other are the pike-and-shot period).
Principle 16 is not touched.

## Open bugs

`gh issue list --state open` returned no open issues on 2026-11-13. Anything the v0.2.0 playtest finds comes first
("fix issues first"), and is added to the section below.

## What the v0.2.0 playtest found

The owner played v0.2.0 on 2026-11-13 and approved the release. No bugs were reported. The verdict: "game wasn't really
engaging". The battles work, but they don't yet make the game fun to play. Before this brief locks, find out what felt
flat: battles, the turns between them, or the whole game. Check every item below against that question.

## Candidate items

| # | Item | Source | Size | Serves | Status |
|---|---|---|---|---|---|
| B | **Battle board, slice A:** back line (3 slots, ranged first, spares as second rank), refill rules, rotation (levy 2 days, drilled 1 day, Auto / Hold the line), AI army-size rules 1 to 4 (no blobs, second wave, garrisons, board-aware attack ratio) | `docs/design/battle-size-and-frontage.md` sections 4.2, 4.3, 5, 7 | L | 2, 12, 11 | **In** |
| C | **Docked battle panel, smallest version:** option A or B (decision 2), 3 lanes with the back row, pool chips, a one-line "marching in", orders with the rotation toggle, terrain chips, day log, camera centring | `docs/design/ui/README.md` section 9 | M | 11, 9 | **In** |
| E | **Panel legend** (the tile corner marks and slot styles) | `docs/design/battle-plan-review.md` 3.2 | S | 11, 13 | **In**, first to cut |
| H | Small issues from the v0.2.0 release check and playtest; review leftovers (year rule copied in `battle.py`; the perf metric uses pikes only, which the back-line perf gate needs fixed) | review item 11 | S each | release hygiene | **In** |
| A | Trade fixes (T1, T2, T5, review fixes; branch `trade-fixes`) and the order-card forecast fix | `docs/reports/trade-fun-test.md` | S to M | 3, 12, 13 | **Out of 0.2.1:** its own patch (decision 1) |
| D | Sieges drawn like battles | battle-plan-review 3.2 | M, art | 11 | **Out:** 0.2.2 or later, with the width art |
| F | Watch-only panel | same | S to M | 11 | **Out:** the log line covers it |
| G | Second golden scene (map with a battle) | same | S | none | **Merged into C:** the docked panel's golden *is* the map with a battle; C ships with its regenerated goldens |
| I | Tax forecast (E3), investment hints (E4) | `docs/reports/economy-fun-test.md` | S to M | 3, 5 | **Out:** economy, after war goals and peace (roadmap) |

Also out of C for now: the header's battle picture made from terrain tiles (art and a cache; it comes with the width art) and the
7-lane stretch note. The face-off header shows roundels, names, generals and the map's crossed-swords badge only.

Not in 0.2.1: width 3/5/7 and Crossbowmen (slice B), battle cards, the mini-map, war goals and peace, reactive prices (T3).

## Recommended scope (fits one patch)

**In:** playtest bugs first; B; C (smallest version above); E; H.

**Cut list, in the order to drop if something grows:**
1. E, the legend (the tile hover card already explains each mark).
2. The "marching in" line (pool chips stay).
3. The rotation toggle's UI (keep Auto, hide the switch; the AI already plays Auto).

Why this order of work: B changes the board the panel shows, so C is drawn once on the final 3-lane board, and C's layout already
takes 5 lanes, so slice B does not redraw it.

Order of work: playtest bugs, H's perf-metric fix (so B's perf gate measures something real), B rules, B AI, C on the new data, E,
the rest of H.

## Changes the creative review asks for (in the build)

- **The odds card counts the board the way the AI does** (regiments that fit the board in full, the rest at half, frontage doc
  section 5 rule 4). Otherwise the card promises that 11 pikes beat 4 and the board says no (principle 3).
- **The rotation toggle's hover states its price:** "A swapping lane deals half and takes 25% more for 1 to 2 days" (principle 3).
- **A rotation is a log line with the regiment's name** ("The Lisbon Tercio falls back; the Porto levy takes the centre") and the
  tile shows "rotating, day 1 of 2" (principle 9; frontage doc 4.3).
- The panel is checked at 1280x720 with the map's action log moved right of the dock.

## Done when (draft)

- No open bug issue; tests, soak, save-compat and perf pass (battle phase under the 5 ms soft budget, measured with mixed arms, not
  pikes only).
- Seeded Europe run to 1600: stacks of 6 or more under 30% of stacks (45% today), at most 110 stacks (130 today), AI time per season
  up by at most 10%.
- Pike win-rate bands unchanged; 3 pikes + 3 guns under 70% against 6 pikes (75% today); 4 v 4 and 6 v 4 with rotation within 8
  points of today.
- Owner playtest: fight a battle with a back line, watch a rotation happen and find its log line, read who is winning with the dock
  open, open and close the dock at 1280x720, and check that the odds word matched the result.

## Owner's decisions for 0.2.1 (one batch: 4, plus 1 only if trade stays in)

Recommended choice first in each.

1. **Theme: is trade in this patch?** The trade branch is built, but it changes the AI's income and its season (the AI re-picks
   orders every season, world merchant profit +17%). B's acceptance run measures the AI's stacks and AI time against today; with
   trade in the same build, a miss cannot be traced to either change.
   (a) **0.2.1 is the battle board only. Trade ships as its own small patch right after (0.2.2) with the forecast fix; width and
   Crossbowmen move to 0.2.3.** Recommended: one theme, a clean acceptance run, and trade still ships soon.
   (b) Trade first: 0.2.1 is the trade patch, the battle board is 0.2.2. Ships finished work sooner, but breaks "starting with war"
   and puts the v0.2.0 battle feedback a release further away.
   (c) Both in 0.2.1, as first drafted. Not recommended.
   (This also settles the frontage doc's question 7, the release order: back line first, width second, cards after.)

2. **Rotation speed and cost** (the measurement the owner asked for, frontage doc 2.6). (a) **Levies 2 days, drilled regulars 1
   day, never instant; while it swaps, the lane deals half and takes 25% more.** Measured: 1 to 2 days is close to today's results;
   instant made the bigger side win 98% of 6 v 4 (85% today), a snowball. (b) Instant for Elite troops with a tech.

3. **Dock: narrow or wide.** (a) **A, narrow (420 px): lanes across, the day log always visible.** Same picture as the frontage doc
   and the approved mockups 10 and 50; covers a third of a 1280 px window. (b) B, wide (560 px): a true left-right mirror with names
   on every tile, but 44% of the window and the log in a tab.

4. **Take the recommended defaults?** (a) **Yes, all of them:** the name is "Rotation"; the stack limit stays 6/7/8 plus a general;
   no map change for clutter (the AI rule fixes blobs); in the dock the enemy is always above and you below; front-line morale shows
   as two halves from the middle with each side's break tick; the camera centres the battle hex in the free part of the map when the
   dock opens. (b) Yes, except the ones you name.

5. **Only if decision 1 is (b) or (c): the trade order card's forecast.** The order card shows the profit an order *could* make;
   what the merchant *delivers* is often less, because the source market has less stock than the card assumes. The same estimate
   drives the AI, which re-picks every season on the card's figure, gets less, and swaps its orders again the next season (order
   churn). (a) **The card and the AI both use the delivered estimate (capped by the source's stock, after other merchants' share),
   and the card shows the stock behind it ("6 in stock, 3 produced here").** Recommended: one honest number for the player and the
   AI, which ends the churn; done when the card and the delivered result agree within about 10%. (b) Keep the potential figure and
   add a "delivered last season" line; the AI keeps planning on the potential, so the churn stays. With decision 1 (a), this
   question opens the trade patch's batch instead, with the same recommendation.

Decisions that only matter later (not in this batch):
- Frontage doc question 3 (how the Crossbowman joins) and question 4 (width sources: tech and general): with slice B.
- The 7-lane stretch note in the panel proposal: with slice B.
- Cards timing, home ground and ground-only cards: cards slice.
- Trade T3 prices that react and T4 tolls: their own design pass, after 0.2.x; E2 to E5 economy: after war goals and peace.

## Risks

- B is the big one: it changes how every battle plays and the AI's army shape. If the seeded run misses its targets, ship the back
  line and the dock without B's AI rule only with owner approval.
- B is L and C is M: together this is a full patch. If either grows, the cut list above applies before anything else slips.
- Perf: back slots add a loop per battle; cache a day's values if the phase passes 5 ms.
- The rotation numbers are from a prototype; they need tuning in the build, within the done-when bands.
- With decision 1 (a), the trade branch waits one more release; its rebase onto B's AI changes (`ai.py`) is small but real.

## Creative review (2026-11-13)

**Verdict: approve with changes.** The draft was two patches (a war patch and an economy patch) plus four art and layout items.
Changes made:
- **Cut trade (A) to its own patch** (decision 1): a different theme, and it would confound B's acceptance run. Its forecast
  question is rewritten plainly (decision 5): the card's expected profit against the delivered profit, and the AI's order churn it causes.
- **Cut D, F and I outright** instead of "cut if it grows"; **merged G into C** (the dock's golden is the map with a battle);
  **cut C's terrain battle picture** (art) to the width release.
- **Decisions 12 to 4 (plus 1 conditional):** the order question (old 6) and the scope question (old 12) merged into decision 1;
  the day-log question (old 10) follows from the dock choice; name, stack limit, map clutter, side placement, morale bar and camera
  (old 2, 4, 5, 8, 9, 11) are one "take the defaults" decision.
- **Added three build changes for principles 3 and 9:** the odds card counts the board as the AI does, the rotation toggle shows its
  price, and a rotation is a named log line.
- Each kept item names the principles it serves (table above).
