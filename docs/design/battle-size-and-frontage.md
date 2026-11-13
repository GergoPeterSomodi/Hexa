# Battle size, width and rotation (draft for the owner, revised 2026-11-13)

Status: DRAFT, revision 2. Nothing is approved and no game code was changed. Written by the game designer on the owner's
question: how many regiments go into a battle, and how the field scales with that. The owner's answers (end of this doc) are
built in: the field's **width** is an attribute, ranged-first back line, an **era 1 archer** unit, and **rotation** (the owner's
"reverse fielding") as a unit attribute.

Mockups:
- Mine, for this doc (the planning session copies them to `docs/design/images/` when the doc is approved):
  [50b_battle_three_lanes_back_line.png](images/50b_battle_three_lanes_back_line.png) (3 lanes, 6 places a side) and
  [50_battle_five_lanes.png](images/50_battle_five_lanes.png) (5 lanes, 10 places, reserve, "marching in").
- The UX designer's docked panel, which replaces mine for layout: [18_battle_panel_v3_a_5lanes.png](ui/18_battle_panel_v3_a_5lanes.png)
  and its 3-lane, log and tile sheets (`ui/18_battle_panel_v3_*.png`). Base for both: mockup 10, [10_battle_panel.png](images/10_battle_panel.png).

Principles this design is for (docs/research/fun-principles.md v2): **11** readable and light to run (a battle you can read at a
glance, a map that does not fill with tokens), **2** trade-offs (front, back line, pool, rotation and width each have a price),
**12** the AI is a rival (the AI builds armies that fit the field instead of blobs). Checked for harm: 6 (the world pushes
back: big armies must not become free), 1 (a decision every few seasons: no new clicks), 14 (it feels like 1480 to 1650:
crossbowmen and pike-and-shot are the period).

## Questions for the owner (read these first)

Decided already (owner, 2026-11-13): width as an attribute, ranged-first back line with spares as second rank, an era 1 archer,
rotation as a unit attribute. What is still open:

1. **Name for "reverse fielding".** (a) **Rotation** ("the line rotates"; barracks drill, veterans and techs speed it up).
   **Recommended.** "Drill" is taken (barracks drill levels), "relief" is a word for a siege. (b) Relief. (c) Reverse fielding.
2. **How fast a regiment rotates, and what the swap costs.** (a) **Levies 2 days, drilled regulars 1 day, never instant**; while
   a lane swaps its regiment deals half and takes 25% more (measured, section 2.6). Recommended: instant rotation made the bigger
   side win 98% of 6 v 4 (today 85%). (b) Allow instant for Elite troops with a tech. Strong; only if you want a snowball tool.
3. **How the crossbowman joins the game.** (a) **A new 4th branch "missile" with one era 1 kind, Crossbowmen; era 2 and 3
   arquebusiers and musketeers stay infantry and count as ranged through the table; Crossbowmen refit into Arquebusiers.**
   Recommended: smallest change that gives era 1 a ranged troop. (b) Rebuild the branches as pike versus shot for all three eras
   (pikes stay in era 2 and 3 as they did in history; shot is its own branch). Truer to history and fixes "6 pikes lose to
   arquebusiers 3%", but it moves every era 2 and 3 number. Later, with the tech-tree and balance pass.
4. **Which sources add width beyond ground and army size** (section 4.1). (a) **One tech "Drill of Maurice" (a tactics tech,
   era 3) +1 and a general trait "Tactician" +1, at most +2 for a side.** Recommended; the tech tree session places it. (b) No
   tech or general bonus at first.
5. **Stack limit.** Still open; (a) keep 6/7/8 plus a general. **Recommended**: the new numbers do not change it (the limit is
   the cap on a side, 7 lanes need 11 a side, and the AI rule fixes blobs).
6. **Map clutter.** Still open; (a) no map change, the AI army-size rule fixes blobs. **Recommended.** (b) An "army banner" later,
   only if a playtest asks.
7. **Order.** (a) **0.2.1: back line, rotation and the AI rule (3 lanes). 0.2.2: width 3/5/7 and Crossbowmen (art in
   parallel). Cards after.** Recommended: cards target lanes, so the lane count must be settled before them. (b) Everything in
   one patch. (c) Width after the cards (rework risk for the cards).

## 1. What the game does today (read from the code)

- A hex holds at most `stack_limit` war units: 6 (`STACK_BASE`), +1 Standing army (era 2), +1 Military revolution (era 3), +1
  Janissary corps (Turkey), and a general adds +2 (+1 with Military revolution, +1 with the Condottieri idea). In a battle the
  limit counts each side on its own, so a side fields up to the limit. Joiners from next-door hexes count in it.
- The field is **3 lanes** (right lane shut on narrow ground). Each lane holds one regiment. Every other regiment is "reserve".
  It fills an empty lane next dawn (arriving shaken for a day), guns in reserve fire at the enemy centre, and a side with an empty
  centre exposes its reserve. Reserves drain morale faster than the front (0.03 against 0.02 a day).
- Era 2 and 3 infantry shoot the enemy in their own lane (0.03 a day). Guns shoot the centre (0.05 a day). The first has no
  "back line" slot of its own: whoever is not in a lane is "back line".
- So the owner's "6 places" is real: 3 lanes plus up to 3 more that do something. Beyond 6 a regiment adds nothing.

## 2. Measurements

Method. A scratch script played all-AI games with the game's own `ai.run` and `end_round` and listened to the event bus.
12 games of 160 seasons (Europe seeds 1 to 6, random worlds seeds 1 to 6; 160 seasons is 1480 to 1519). 4 Europe games of 560
seasons (1480 to 1619, so era 2 and era 3 are in it). Random worlds past 1519 were not measured (the long run did not finish
in time). Clash timing, the default. The AI attacks only with an edge, so its battles are lopsided; the numbers describe what
the AI does, and a player will meet closer fights. The scripts are in the planning session's scratch, not in the repo.

### 2.1 Stacks on the map

| Europe, 4 games | 1480-1519 | 1520-1574 | 1575-1619 |
|---|---|---|---|
| War units on the map (mean) | 172 | 295 | 590 |
| Stacks (hexes with war units) | 60 | 86 | 130 |
| Stacks of 6 or more | 8 | 19 | 52 (max 77) |
| Stacks at the limit | 8 | 15 | 34 |
| Biggest country's army (units) | 14 | 29 | 57 |
| Stack limit, mean / max (with a general) | 6.0 / 7 (9) | 6.7 / 8 (10) | 7.2 / 9 (12) |

- A country has 1.2 stacks at the start and 2.9 in 1600 (p90 8, max 16). Units per country: mean 3 then 14.5 (p90 41, max 95).
- Europe 1480-1519: 59% of stacks are 2 units (garrisons), 13% are 6 or more. **Random worlds, 1480-1519: 31% to 37% of stacks
  are at the limit of 6**, and 31% of all units stand in a 6-stack. The AI gathers new regiments at the capital, so blobs form there.
- Late Europe: 45% of stacks have 6 or more regiments (25% sit exactly at the limit).
- Country-seasons that move 3 or more war groups: 17% (Europe) and 30% (random worlds) in the first 40 years; 5 or more groups: 2% and 5%.
  Late Europe: mean 2.0 groups, p99 9, max 15 in one season.
- Read: clutter is mild up to 1520 and real from 1575. A top country moves up to 16 stacks.

### 2.2 Battles

| | 1480-1519 | 1520-1574 | 1575-1619 |
|---|---|---|---|
| Field battles (Europe long runs) | 226 | 355 | 229 |
| Regiments a side brings at the start (mean / p90 / max) | 3.7 / 8 / 9 | 3.9 / 7 / 10 | 4.2 / 8 / 12 |
| Sides with more than 3 regiments (more than lanes) | 40% | 46% | 52% |
| Sides with 6 or more | 25% | 25% | 32% |
| Sides with a gun / with shot | 44% / 0% | 45% / 57% | 49% / 76% |
| Ranged regiments per side (guns + shot) | 0.5 | 1.9 | 2.6 |

- **46% of the regiments a side fields sit outside the 3 lanes on the average day** (reserve 1.3 units a side against 1.5 in the lanes; 49% in
  the 160-season set). By battle start, 34% to 41% of the regiments are "beyond the 3 lanes".
- Only 63% of fielded regiments stand in a lane. A 3+3 board (3 lanes with a back row) would hold 93% of them.
- 11% to 26% of battles get a joiner (more in the late game).
- The bigger side has 6 or more in about half of the battles, but the smaller side has 2 or fewer in 74% of those in 1480-1519
  and 31% in 1575-1619. Close big fights (the smaller side at 75% or more of the bigger) are 0%, 6% and 27%. The AI dumps big
  stacks on weak ones, so most of the idle regiments are idle because the other side is small.
- Frontage would matter in few AI battles: with the "mean of both sides" rule only 4% of field battles would be 5 lanes; with
  "the bigger side" it would be 31%. In a player's game the share depends on how even the sides are.

### 2.3 What an extra regiment is worth today (scratch fights on plains, 80 seeds, the test scenarios' own set-up)

| Attacker regiments v 4 pikemen | win | | Even fights | attacker win |
|---|---|---|---|---|
| 3 | 22% | | 6 v 6 | 50% |
| 4 | 50% | | 8 v 8 | 48% |
| 5 | 72% | | 10 v 10 | 46% |
| 6 | 85% | | 11 v 11 | 45% |
| **7, 8, 9, 10, 11** | **85%** (flat) | | 11 v 6 | 74% |

- **The seventh regiment and every one after it is worth nothing in a fight today.** Losses per man fall (12% of the men at
  6 v 4, 7% at 11 v 4), that is all. This is the owner's "inefficient to land 10 to 20 units".
- Guns in the back line are strong: 3 pikes + 3 guns beat 6 pikes 75% of the time (4 + 2 guns: 68%). The back line is a free
  place today. That is an arms matrix problem (battle-plan-review item 9) and the design below keeps it in view.
- Era 2: 6 pikemen against 6 arquebusiers win 3%. Old troops are not an option, which is fine.

### 2.4 Speed and cost

- `fight_day` takes about 0.13 ms for 8 v 8 and 0.15 ms for 11 v 11 today (a busy machine; noisy). A prototype with 5 lanes
  takes 0.16 and 0.19 ms: about 20% more. Ten battles of 8 v 8 for 3 days: 3.9 ms today, 4.8 ms with 5 lanes, against the
  5 ms soft budget (the review says 4.6 ms was measured earlier). It is tight; a day's values need caching in slice B.
- The AI plays no battle rule of its own, so the AI cost is the army-size rule only (a few comparisons in `_army`).


### 2.5 Width: the prototype, run again (copy of the code, not the repo)

A scratch copy of `combat.py` with a variable lane count (centre-out fill, unmatched lanes wheel, break rule generalised to "half
the open lanes, rounded up"). Attacker win rate by attacker regiments (80 seeds, plains, pikes). `*` marks a 5-lane field.

| Defender | Attacker regiments: win % | Step across the width change |
|---|---|---|
| 4 | 3:22 4:50 5:72 6:85 7:85 8:85 9:85 10:85 11:85 | never widens (4 cannot fill 5 lanes) |
| 5 | 4:31 5:51 6:72 7:80 8:81 **9:88\*** 10:88\* 11:88\* | +7 (3 lanes: +0) |
| 6 | 5:29 6:50 7:62 **8:74\*** 9:82\* 10:85\* 11:85\* | +12 (3 lanes: +8) |
| 7 | 6:39 **7:52\*** 8:66\* 9:81\* 10:82\* 11:85\* | at the edge of the table |
| 8 | 7:22\* 8:45\* 9:64\* 10:79\* 11:85\* | 5 lanes all through; 3 lanes gave 7:38 8:48 9:64 10:72 11:72 |
| 10 | 9:18\* 10:45\* 11:60\* | |

- **The cliff of the first draft is gone.** There, 10 regiments against 4 on 5 lanes won 100% (from 85% at 9) and the battle
  fell from 3.9 to 1.9 days. The cause was not the flank bonus (1.25, 1.1 and 1.0 gave the same numbers). It was a thin
  defender: 4 regiments on 5 lanes have no reserve, so one routed regiment empties a lane. **The fix is a rule: a lane count may
  not be wider than the smaller side can fill** (largest odd number at or under its regiments, at least 3).
- Acceptance test, restated. Steps of 20 to 28 points between 3 and 5 regiments are the ordinary growth of even fights, on
  3 lanes too. The test is on the **change of width**: the step across it may exceed the same step on 3 lanes by at most 8
  points. Measured: +7 (5 v 8 to 9) and +4 (6 v 7 to 8). Re-run the table in the build and in `tools/battle_stats.py`.
- Even fights stay even: 8 v 8 on 5 lanes 45% to 48% attacker, 11 v 11 on 7 lanes 54%. A wider field lets numbers tell more, in
  both directions (7 v 8 attacker 38% on 3 lanes, 22% on 5).
- With a tactics bonus of +1 to the army-size score the width switches one regiment earlier (6 v 5 is 5 lanes); the curves stay smooth.
- Share of AI battles by width (1,699 field battles of the measured games): 3 lanes 96%, 5 lanes 4%, 7 lanes 0%. With +1 from
  techs 92% / 8% / 0%, with +2 91% / 9% / 0.2%. AI battles are lopsided; a player's close fights reach 5 lanes more often.
- Cost: `fight_day` about 0.16 ms (8 v 8) and 0.19 ms (11 v 11) on 5 and 7 lanes, against 0.13 and 0.15 ms on 3 lanes.

### 2.6 Rotation: how fast, and what the swap costs (prototype, 3 lanes, 80 seeds, attacker win %)

The prototype: when a front regiment's morale falls under a threshold and a regiment with 25 points more morale waits in the
back row or the pool, they swap after `tempo` days. While the swap is pending the front regiment deals `SWAP_DEAL` (0.5) of its
damage and takes `SWAP_TAKEN` (1.25) times damage (the lane is exposed), and the regiment that comes in is shaken for a day. Once
per regiment.

| Rule | 3 v 4 | 4 v 4 | 5 v 4 | 6 v 4 | 6 v 6 | 8 v 6 | Days at 6 v 4 |
|---|---|---|---|---|---|---|---|
| No relief (today) | 22 | 50 | 72 | 85 | 50 | 70 | 3.9 |
| **Instant**, under 25% | 14 | 48 | 78 | **98** | 44 | **90** | 4.6 |
| Instant, under 35% | 14 | 40 | 82 | 98 | 35 | 88 | 4.7 |
| 1 day, under 25% | 24 | 50 | 70 | 84 | 55 | 74 | 4.0 |
| 2 days, under 25% | 24 | 50 | 71 | 85 | 56 | 74 | 4.0 |
| 1 day, under 35% | 26 | 49 | 68 | 84 | 45 | 71 | 4.1 |
| 2 days, under 35% | 28 | 54 | 68 | 82 | 46 | 78 | 4.0 |
| 1 day, under 50% (too early) | 25 | 51 | 61 | 80 | 41 | 61 | 4.6 |
| 2 days, under 50% (too early) | 31 | 52 | 64 | **72** | 39 | **60** | 4.3 |
| 1 day, under 35%, harsh swap (deals 0.3, takes 1.5) | 31 | 51 | 74 | 85 | 51 | 71 | 4.3 |

- **Instant rotation is a snowball.** The side with the bigger reserve gains 13 points at 6 v 4 and 20 at 8 v 6, and the weaker
  side loses 8 at 3 v 4. It is the wrong default.
- **With a swap of 1 or 2 days it is nearly neutral** (within 8 points of today in every cell) and the weaker side gets a few points back. A
  battle lasts about 4 days, and a regiment under 25% usually routs within a day or two, so 2 and 3 days give the same result:
  a slow swap never completes. That is the honest result: rotation is a small lever in numbers. It pays in story (the line turns over)
  and in decisions (when to rotate).
- **Rotating too early costs.** At 50% morale the bigger side drops to 72% (6 v 4) and 60% (8 v 6): its exposed lane is hit and
  the regiment that came in is shaken. This is the trade-off principle 2 asks for.
- Read for the rules: threshold 35% with the AI and an attribute for the player; drilled troops swap in 1 day, levies in 2, and
  the harsh swap (deals 0.3, takes 1.5) is the levy's price. Never instant without a card.

### 2.7 The archer: arms matrix (prototype; 40 seeds per pair, plains, 3 lanes)

I added a Crossbowman kind (hp 8, attack 5, defence 2, 28 ducats) to the scratch copy. In the back row it shoots at `XB_FIRE` a
day at the enemy centre (bombards 0.05); in a lane it shoots 0.03 and fights weakly; a +20% against horse was included. Overall
strength is the mean win share against the other nine compositions, attacker edge averaged out.

| Composition (6 regiments) | XB_FIRE 0.035 | **0.025** | 0.015 |
|---|---|---|---|
| 6 pikes | 39% | 44% | 50% |
| 4 pikes + 2 crossbowmen | 67% (best 90) | **62% (best 79)** | 56% (best 75) |
| 3 pikes + 3 crossbowmen | 63% | 59% | 50% |
| 6 crossbowmen | 31% | 32% | 29% |
| 4 pikes + 2 knights | 30% | 34% | 40% |
| 3 pikes + 2 knights + 1 crossbowman | 48% | 44% | 43% |
| 6 knights | 23% | 25% | 29% |
| 4 pikes + 2 bombards | 72% | 75% (best 89) | 77% |
| 3 pikes + 3 bombards | 58% | 59% | 60% |
| 3 pikes + 2 crossbowmen + 1 bombard | 68% | 66% | 64% |

- At 0.025 no crossbow mix beats another composition by 80% or more. The target of the plan review is "no composition wins
  more than 80%"; it holds for the crossbow mixes there and fails for 0.035 (90%).
- **A pure crossbow stack is weak (about 32%):** the archer is a support troop, not a stack. Good.
- **Two existing problems show up.** (1) 4 pikes + 2 bombards is the strongest mix (75%, best 89%): the free back line,
  as in 2.3. Cut the bombard's `FIRE_LOSS` from 0.05 to about 0.04 when the back line ships and re-run. (2) **Knights are the
  weakest composition against everything** (6 knights 25%); crossbowmen with a bonus against horse would sink them further.
  Recommend no bonus against cavalry for the archer, and a separate look at era 1 cavalry.

## 3. Options (status after the owner's answers)

Each option lists what it gives, what it costs, the principles it serves, how it reads, AI cost, the 5 ms battle budget, and the save.

### A. Width as an attribute (3 to 7 lanes). CHOSEN, spec in 4.1

- Gives: more regiments fight at once; ground and army size matter; the smaller army can pick narrow ground; techs and generals
  can widen the field later. History: at Cerignola (1503) Gonzalo de Cordoba chose ditched ground, which the Dig trenches card names.
- Costs: both sides share one lane count, so it needs a rule. The first draft (the bigger side's size) made a cliff (2.5). The rule
  of 4.1 (mean of both sides, never wider than the smaller side can fill) does not.
- Readability: the UX designer's docked panel (420 px) shows 3 lanes with large tiles and 5 with medium tiles; 7 lanes need
  small tiles (about 52 px). Practical maximum: 7.
- AI cost: none. Battle cost +20% (2.5). Save: `Battle.width` (default 3), a list of lanes of that length.

### B. A back line for ranged troops, and reserves that refill. CHOSEN, spec in 4.2

Ranged first, then spare regiments as a second rank (owner, 2026-11-13). Ranged by era is one table in `data.py`.

### C. Rotation of tired regiments. CHOSEN as a unit attribute, spec in 4.3

### D. An era 1 archer. CHOSEN, spec in 4.4

### E. The limit: bigger stacks, more joiners, or a cap

- E1. Raise the limit by era (6, 8, 10). Fewer tokens, but more idle regiments unless width grows. Only after width ships.
- E2. Keep the limit as a cap on a side and let extra stacks **wait on next-door hexes and join** as space frees (today's join
  rule). The panel lists "marching in". **Recommended.**
- E3. A per-side battle cap below the limit. Not needed: the board is 2 times the lanes (6, 10 or 14) and the rest wait in the pool.

### F. Map clutter

- F1. Leave it: the map draws one token per hex per side already (`_draw_units` groups by hex and side). Mild before 1575.
- F2. Merge stacks automatically. Rejected: it takes control from the player and does nothing for the AI.
- F3. An army banner: adjacent stacks of one country and one order draw as one flag with a number. UI only. Only if a playtest asks.
- F4. **The AI builds armies that fit the field** (section 5). **Recommended.**

## 4. The recommended design

### 4.1 Width: the number of lanes, as an attribute

`Battle.width` is the number of lanes both sides fight in. It is odd (3, 5 or 7) so there is a centre lane; on narrow ground it
is 3 with the right lane closed, so 2 fight (today's rule). The minimum is 3, the maximum 7.

**Formula** (all numbers in `data.py`):

1. Army size score: `P = round((n_att + t_att + n_def + t_def) / 2)`, where `n` is a side's war regiments on the hex, joiners
   included, and `t` is the side's width bonus from techs and its general (`0` to `WIDTH_BONUS_MAX` = 2).
2. From the score: `L_army` = 3 when `P` is 6 or less, 5 when `P` is 7 to 10, 7 when `P` is 11 or more (`WIDTH_STEPS`).
3. From the smaller side: `L_fill` = the largest odd number not above the smaller side's regiments, at least 3. A field
   no side can fill is not allowed (this removes the cliff, 2.5).
4. From the ground: `WIDTH_CAP`: open ground (plains, steppe, desert, tundra, savanna, beach) 7; hills, forest and the other rough
   ground 5; narrow ground (mountains, marsh, jungle, snow) 3; a castle assault 3.
5. `width = max(3, min(L_army, L_fill, cap))`, worked out at the start of each season of the battle and never narrower than it was
   (a joiner can widen it).

| Sides (regiments) | Ground | Techs | Width | Why |
|---|---|---|---|---|
| 6 v 6 | open | none | 3 | `P` 6 |
| 8 v 8 | open | none | 5 | `P` 8 |
| 8 v 8 | hills | none | 5 | cap 5 |
| 8 v 8 | mountains | none | 3 (2 fight) | narrow cap |
| 10 v 4 | open | none | 3 | the smaller side cannot fill 5 |
| 10 v 6 | open | none | 5 | `P` 8, 6 fills 5 |
| 11 v 11 | open | none | 7 | `P` 11 |
| 9 v 9 | open | +2 each | 7 | `P` 11, 9 fills 7 |
| 8 v 8 | castle assault | none | 3 | assault cap |

**Sources, now and later.** Ground and army size are the first version. Techs and generals are hooks with no content until the tech tree
session places them: a `width` effect key (added to `tech.EFFECT_KEYS`) and a general trait **Tactician** (+1; one more entry in
`GENERAL_TRAITS`, which today has open, rough, assault, defense and cavalry). Suggested homes: Tercio (era 2) or Volley fire (era 3)
+1 for the infantry-led line, and a drill tech of Maurice of Nassau's kind (era 3) +1. At most +2 for a side. A bonus never widens
past the ground cap or the smaller side's fill, so it cannot make a thin army wide.

**Practical maximum.** The docked panel (420 px, UX mockup 18) fits 3 lanes with large tiles, 5 with medium tiles and **7 with small
tiles (52 px, men on hover)**. 9 lanes would be 40 px tiles: unreadable. The stack limit (12 at most) cannot fill 7 lanes plus a back
row (14 places) anyway. So 7 is the maximum.

### 4.2 Back line, board and reserve

- **Back slots = width**, one behind each lane. The board is `2 x width` places: 6, 10 or 14. A six-stack on 3 lanes fills it.
- **Ranged by era** (`RANGED` in `data.py`; no unit changes): era 1 bombards and **Crossbowmen** (4.4); era 2 culverins and
  arquebusiers; era 3 field guns and musketeers. Cavalry is never ranged.
- **Who goes in the back:** ranged first, then spare regiments as a **second rank** (they cannot shoot; they step up with no shake;
  they drain morale like the front, `FRONT_DRAIN`). The pool is everyone beyond the board, off the board.
- **How they shoot:** guns `FIRE_LOSS` 0.05 a day (to cut to about 0.04, 2.7) at their own column's enemy front regiment, the
  centre when that is empty (today all guns hit the centre). Missile troops 0.025 a day (4.4). Shot in the back 0.02, in a front
  lane 0.03 (today). The back row is safe until the enemy's centre breaks (`BACKLINE_LOSS`, today's rule).
- **Refill at dawn:** a dead or routed front regiment is replaced by its column's second rank (no shake), else by the best of the pool
  (shaken, `RESERVE_SHAKEN`, as today), else a ranged regiment from the back (guns last). An empty back slot takes a ranged regiment
  from the pool.

### 4.3 Rotation (the owner's "reverse fielding"): a unit attribute

Name: **rotation**. (Question 1.) It says how fast a tired front regiment swaps places with a fresh one behind it.

- **Trigger:** a front regiment under `ROTATION_MORALE` (0.35) with a regiment 25 points fresher (`ROTATION_GAP`) in its column's
  back slot or in the pool. Once per regiment per battle. The AI and the default do this on their own; the Orders box gets one
  toggle, "Rotate tired regiments: Auto / Hold the line".
- **Time (days):** `rotation` is the attribute of the pair, the slower of the two. **Levy 2 days; drilled regular 1 day** (barracks
  drill at level 1 or more, or Veteran rank); **Elite 1 day with a light penalty**. A tech or a card can take a day off, never below 1
  (instant only by a card: "Reserves forward", for the card slice).
- **While the swap is pending** the lane stays and fights: its regiment deals `SWAP_DEAL` and takes `SWAP_TAKEN` times damage
  (levy 0.3 and 1.5; regular 0.5 and 1.25; Elite 0.7 and 1.1). That is the exposure. The enemy keeps fighting the other lanes
  as usual, and no other rule changes. If the front regiment routs first, the normal refill steps in, shaken. When the days are up the
  fresh regiment takes the lane, shaken for its first day (`RESERVE_SHAKEN`), and the tired one goes to the back or the pool.
- **What raises it:** barracks drill, veteran rank, a drill tech, cards. **What lowers it:** levies, supply shortage (a hungry stack is 1 day slower).
- **Measured** (2.6): instant rotation is a snowball (6 v 4 from 85% to 98%); 1 or 2 days is nearly neutral (within 8 points of
  today); rotating too early (under 50%) costs the bigger side (6 v 4 down to 72%). A 3-day swap never completes in a 4-day battle.
- Shows on the panel as a tag on the swapping tile ("rotating, day 1 of 2") with the tile half-lit, and as a log line.

### 4.4 The era 1 archer: Crossbowmen

| | Crossbowmen | Pikemen (era 1) | Arquebusiers (era 2) | Bombards (era 1) |
|---|---|---|---|---|
| Branch | **missile** (new) | infantry | infantry | artillery |
| HP (1,000 men at full) | 8 | 10 | 10 | 8 |
| Attack / defence | 5 / 2 | 4 / 5 | 5 / 6 | 6 / 1 |
| Moves | 3 | 3 | 3 | 2 |
| Gold | 28 | 25 | 30 | 60 |
| Goods per raise | weapons 1.0, grain 1.0, timber 0.5 | weapons 1.0, grain 1.0 | weapons 1.5, grain 1.0, gunpowder 0.5 | iron 2, tools 1, copper 1.5, gunpowder 1 |
| Upkeep | 0.5 | 0.5 | 0.6 | 1.0 |
| Needs | nothing (any province) | nothing | nothing | a town or a foundry |

- **Era and countries:** era 1 (1480 to about 1520), any country that can raise era 1 troops. Later "armies move on" as for pikes. The AI
  raises them at 20% of its regiments once it has 4 or more (`_raise`: cavalry 30%, artillery 15%, missile 20%). National flavour
  for later: English longbowmen (ENG national tech, +1 attack) and Genoese crossbowmen; names only, no art now.
- **How they shoot:** from a back slot, `MISSILE_FIRE` 0.025 a day at their column's enemy front regiment (the centre when
  empty), a hit worked out like a gun's. In the front lane 0.03 and they fight with attack 5, defence 2: weak, so the lane
  rank puts them last, as guns. Against pikes: normal damage (the pike's defence 5 and the pike bonus against horse do not
  apply). **Against cavalry: no bonus** (knights are already the weakest troop, 2.7). Against guns: they cannot reach the enemy
  back row unless the centre has broken. They are safe in the back and cheap (28 ducats against a bombard's 60), and a pure stack of
  them is weak (about 32%), so they are a support arm.
- **Upgrade:** refit (existing rule, half the new kind's cost, in one of your towns or cities) turns Crossbowmen into Arquebusiers
  once the country reaches era 2. Because the branch changes, `UnitKind` gets `refit_to` (a key) and `refit_check` follows it; a
  kept unit keeps xp and drill levels. Era 2 and 3 shot stay in the infantry branch and count as ranged through the table (Question 3).
- **Data and code touched (all outside this doc's brief):** `data.py` (the kind, `BRANCHES`, `BRANCH_NAMES`, `FIGHT_ATTACK` and
  `FIGHT_DEFENSE` rows for "missile", `RANGED`, `MISSILE_FIRE`), `tech.py` effect keys `missile_attack` and `missile`, `raise_options` (skip
  a branch with no troop in the era), `ai._raise`, the recruit tab, the unit panel, README tables, and tests that loop over `BRANCHES`.
- **Arms matrix targets** (a scripted run, 100 seeds per pair, plains and hills, 6 regiments a side of equal cost):
  no composition wins 80% or more of the matchups head to head; no composition averages above 70% against the others; 4 pikes
  + 2 crossbowmen 55% to 65% overall; 6 crossbowmen 25% to 35%; 4 pikes + 2 bombards under 70% after the bombard cut; 6 knights over 35%
  (a fix for era 1 cavalry, separate from this design). First numbers in 2.7.
- **Art brief for the art director** (`art.figure` and `art.token`, Kenney look: flat two-tone, ink outline, code-drawn):
  1. A Crossbowman figure for the map (zoomed in) and the battle tiles. Readable at 52 px (docked panel, 7 lanes) and 24 px (map
     token, far zoom). Silhouette: a horizontal stave across the chest or aimed at the enemy, a sallet or kettle hat, a leather
     brigandine, a bolt quiver at the belt. Not a tall pike (pikemen), not a gun barrel (arquebusiers), not mounted (cavalry).
  2. A second pose for the back row: kneeling behind a pavise (large rectangular shield) with the stave up, so the back row looks
     different from the front.
  3. Country colour on the tabard or shield edge, like the other figures; the existing token tint rules apply.
  4. A "missile" branch badge for the unit panel, the Raise tab and the battle tile (a crossbow glyph in `ui/icons.py`); era 2 and
     3 shot keep their figures and get no badge.
  5. Card scenes (game-style cards) reuse the figure; an optional volley variant: three figures with bolts as thin lines.
  6. `tests/test_sprite_hashes.py` fixtures are regenerated with the new figures.

### 4.5 Rules table

| Thing | Number | Notes |
|---|---|---|
| Regiments a side may field | the hex's stack limit (6, 7, 8; +2 or +3 with a general) | unchanged; the rest wait next door and join |
| Width | 3 to 7, formula 4.1 | `WIDTH_STEPS` ((6, 3), (10, 5), (99, 7)), `WIDTH_CAP`, `WIDTH_BONUS_MAX` 2 |
| Back slots / board | width / 2 x width | 6, 10, 14 |
| Ranged | `RANGED`: artillery from era 1, infantry from era 2, missile era 1 | |
| Fire a day | guns 0.05 (to about 0.04), missile 0.025, shot in the back 0.02, shot in a lane 0.03 | |
| Rotation | `ROTATION_MORALE` 0.35, `ROTATION_GAP` 0.25, levy 2 days, regular 1, once each | swap deals / takes: 0.3 / 1.5, 0.5 / 1.25, 0.7 / 1.1 |
| Second rank drain | `FRONT_DRAIN` 0.02 | the pool keeps `RESERVE_DRAIN` 0.03 |
| Wheel bonus | `FLANK_BONUS` 1.25 | not the cause of the cliff, so it stays |

**Line breaks and dice.** The centre is the middle lane (`width // 2`). An empty centre with nothing to fill it breaks the army and
shocks it once (`CENTRE_SHOCK`). Flank lanes are all the others; each day a flank stays broken the centre loses `FLANK_MORALE`.
"Two broken lanes break the army" becomes **half the open lanes, rounded up**: 2 of 3, 3 of 5, 4 of 7, and 1 of the 2 open lanes
on narrow ground; at 3 lanes today's numbers do not change. A lane that never held a regiment is open ground, not a broken lane
(already the rule): the enemy wheels round it. A broken centre exposes the back slots (`BACKLINE_LOSS`). **Dice:** unchanged, one
d6 per side per day (`DICE`, 0.7 to 1.4) for every lane.

### 4.6 What the panel shows

The UX designer's docked panel (mockup 18, 420 px) is the layout. This design needs from it: the lane count in the header
("Hills, 5 lanes"); a back row under each side's front row; tiles that shrink with the width (large at 3, medium at 5, small at 7, men
and morale numbers on hover); a "READY" mark on a second-rank regiment and "fires" on a ranged one; a "rotating, day 1 of 2" tag on a
swapping tile; the pool as chips with their morale; "marching in" for joiners next door; a width line in the terrain chips
("5 lanes: open ground, 8 v 8"). The read model (`battleview`) gets `width`, `back`, `pool`, `pending`.

### 4.7 Interactions

- **Economy and debt:** upkeep unchanged, so waiting in the pool costs as much as fighting. Debt desertion takes the pool first.
  Crossbowmen are cheaper than any other ranged troop.
- **War and supply:** unchanged. The supply brake (units over the supply limit lose a hit point a season) stays the natural cap on
  blobs. The AI rule respects it. A hungry stack rotates 1 day slower.
- **Tech:** Standing army and Military revolution (+1 stack) add regiments to the pool beyond the 6-place board; they pay when width
  5 opens. Volley fire (+1 infantry attack) helps shot and pikes. A width tech and the Tactician trait are the new hooks.
- **Cards (next slice):** most cards target a lane, so the lane count must exist first. Grand battery, Guns gallop up, Countermarch
  (shot fires twice) and Pike and shot need the back line; Change of front swaps two lanes; "Reserves forward" is rotation by card.
- **Generals:** +2 stack places and the Tactician trait (+1 width).
- **Castles:** an assault is 3 lanes and the garrison holds the centre front; the back row holds the defender's guns.
- **Lane ground from the real map** (mini-map slice): the three facing hexes set lanes 3 to 5 of a 3-lane field. A wider field takes
  the nearest facing hex's ground for its outer lanes.

### 4.8 Risks

- **Back-line guns are already a free place** (2.3, 2.7): 4 pikes + 2 bombards is the strongest mix (75%, best 89%). Cut `FIRE_LOSS`
  to about 0.04 with slice A, and if a gun stack still wins more than 80%, give guns a reach of their column and its neighbours.
- **Width makes numbers tell more** (7 v 8 on 5 lanes: attacker 22%, on 3 lanes 38%). Intended, but re-run the odds-card bands
  (`ODDS_WORDS`): the plains calibration holds for 3 lanes only.
- **Rotation can be exploited** by rotating too early (it costs the bigger side, 2.6) or never mattering (a slow swap never
  completes). It is a small lever; do not tune the game around it.
- **The efficient size stays 6.** A six-stack fills the 3-lane board and 7 or more pay only when width 5 opens, so a player can
  still spam six-stacks. The brakes are upkeep, supply and the brakes design; the AI rule is the only fix here.
- **Snowball:** unchanged in size terms; the 85% plateau above 6 regiments goes away with width 5, which then helps the bigger army.
  Measure it with the stop-steamrolling set-up.
- **New branch cost:** a fourth branch touches the raise options, the AI quota, the recruit tab, the README and several tests.

## 5. Player and AI

The player's orders stay Attack, Hold and Withdraw, plus one toggle, rotation Auto or Hold the line. The player's new choices are
how many regiments to bring, which arms (ranged for the back row) and the ground (it sets the width).

The AI plays the same board; it has no battle rule of its own. It builds and moves armies with these rules (F4, slice A; the crossbow quota in slice B):

1. **A field army is up to 6 regiments** (the board of 3 lanes with a back line; 10 once width 5 can open), at most the stack limit, plus its general. The AI
   gathers new regiments into one main army up to 6, then starts a second army at the next town, and moves an army only with
   3 or more regiments (the main army and the second one).
2. **No blobs:** a stack of 6 or more does not take in another stack of 3 or more unless it is waiting to attack the same hex.
   Surplus regiments go as a **second wave** to a hex next to the target and join the battle after it starts (`battle_joined`).
3. **Garrisons:** 1 to 2 regiments per border castle or town, never a 2-stack in the interior.
4. The AI's attack ratio counts the regiments that fit the board in full, and the rest at half, so it does not believe 11 pikemen
   beat 4 pikemen. (Today they do not, and the AI would learn nothing.)
5. **Arms:** about 20% missile troops once the army has 4 regiments, 30% cavalry, 15% guns (slice B). It rotates on Auto.
6. Targets to prove it in a seeded Europe run to 1600: stacks of 6 or more under 30% of all stacks (45% today), at most 110 stacks
   on the map (130), the share of regiments outside the board under 25% (46% by the day count, 34% to 41% by the battle count),
   and a country moving 6 groups or fewer at a time at p99 (9 today). AI time per season may not grow more than 10%.

Risk: split armies are weaker in a fight. Check the snowball (the biggest country's land share, 0.114 to 0.114 in the timing test)
does not change.


## 6. Perf and saves

- Battle phase: slice A adds a loop over at most 3 back slots and the rotation check; slice B adds about 20% on 5 and 7 lanes (2.5).
  Cache the day's values when the phase passes 5 ms. `tools/perf.py` gets a `battle_season` row with 10 battles of 11 v 11 on 7 lanes
  as the worst case.
- Saves: `Battle.lanes` stays a list of lanes (length 3, 5 or 7). New `Battle` fields with defaults: `width` (3), `back` (empty),
  `pending` (rotations under way, empty), `relieved` (ids, empty). `fill_defaults` loads old saves, which come up as 3 lanes with no back row; the
  first dawn fills the back from the reserve. The new unit kind and branch are saved by key, so old saves load, and an old save has no
  Crossbowmen. No `VERSION` bump; run `tools/save_compat.py` as usual. Rotation and width are derived from units and techs, not saved.

## 7. Where it fits (release order)

- v0.2.0 ships with 3 lanes and a reserve.
- **Slice A, 0.2.1 (a patch before the cards):** the back line (3 slots, ranged table, second rank), the refill rules, **rotation** (levy
  2 days, drilled 1 day, auto, threshold 35%), the bombard `FIRE_LOSS` cut if the matrix asks, and the AI army-size rules. Still
  3 lanes. The pike win-rate bands stay.
- **Slice B, 0.2.2:** the **width attribute** (ground, army size and the fill rule; the tech and general hooks exist but carry no
  content), widths 5 and 7 on the panel, and **Crossbowmen** (data, AI quota, refit path, README; the art director's figure and badge
  in parallel, so the art is ready when the rules are). The cards come after.
- **Cards slice:** the width tech and the Tactician trait arrive with the tech tree and card pass; "Reserves forward" is a card.
- Why before the cards: cards target lanes and the back line, so the lane count and the back row must be fixed first, or the card
  pass is rework. Why the split: A needs no art and no new branch; B needs the new branch and the art.
- **Mini-map slice (later):** lane ground for lanes 4 to 7 copies the nearest facing hex.

### Smallest first version (slice A, 0.2.1)

1. `data.py`: `RANGED`, `BACK_SHOT_LOSS`, `ROTATION_MORALE`, `ROTATION_GAP`, `ROTATION_DAYS`, `SWAP_DEAL`, `SWAP_TAKEN`.
2. `combat.deploy`: a back row of 3 slots per side; ranged first, then spares; the refill order of 4.2; rotation at dawn with the pending swaps.
3. `fire`: back-slot shot at 0.02; guns hit their own column (the centre when empty). `_Day.hit` reads the swapping set.
4. `Battle.back`, `pending`, `relieved` with defaults; `battleview` adds `back`, `pool`, `pending`; the panel draws the back row and the "rotating" tag.
5. The Orders box gets the "Rotate tired regiments" toggle; the AI rotates on Auto.
6. AI: the army-size rules 1 to 4 of section 5.
7. Tests: the pike band tests stay; new bands for 3 pikes + 3 guns (target under 70% against 6 pikes, 75% today), 4 v 4 and 6 v 4 with
   rotation (within 8 points of today), a pool-refill case, a rotation case (swap completes in 1 day for a regular, 2 for a levy).
   The seeded run of section 5 is the acceptance proof.

Out of scope for slice A: widths 5 and 7, the terrain cap, Crossbowmen, the army banner, deployment drag, per-lane dice, width techs.

## 8. Open points and what I did not measure

- Random worlds after 1519 were not measured; the late numbers are Europe only (4 games).
- AI-only battles are lopsided (width 5 in 4% of them). A playtest with close fights will show how often wider fields apply.
- The prototype is a quick copy, not tested code: it shows the shape of the curves, not final numbers. The rotation, wheel and
  crossbow numbers need tuning in the build. Timings come from a busy machine and are rough.
- Era 1 cavalry is the weakest troop in the matrix (6 knights about 25%). Not part of this design; flagged for the balance pass.
- Option (b) of Question 3 (pike versus shot as separate branches in all eras) is not designed here.

## Owner's decisions (2026-11-13)
1. **Battlefield width as an attribute, and smaller unit figures.** The width of the field (how many lanes) is its own attribute, set by the ground and the armies (and later techs and generals), not a fixed 3. The panel uses smaller unit figures (compact tiles) so a wide field fits. The revision proposes the attribute and its sources.
2. **Back line:** ranged first, then spare regiments as a second rank.
3. **Archers:** add an era 1 archer (or crossbow) unit, with art, data and rules.
4. **Relief as an attribute:** a unit attribute for how quickly a reserve or second rank changes places with a tired front regiment (working name: "reverse fielding", to be named). The change takes time; while it happens, the enemy keeps fighting the other lanes (and the swapping lane is exposed). Measure how quickly it should happen.
5. Still open: stack limit (recommended: keep 6/7/8 plus a general) and map clutter (recommended: the AI stacking rule, no map change).


Revision 2 (designer): item 1 is section 4.1 (formula, sources, minimum 3, maximum 7), item 2 is the back line of 4.2, item 3 is
the Crossbowmen of 4.4, item 4 is rotation, 4.3. Items 5 of this list (stack limit, map clutter) stay as recommended; the new
numbers do not change them. The remaining questions are at the top.
