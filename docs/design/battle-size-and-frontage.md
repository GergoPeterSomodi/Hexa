# Battle size and frontage (draft for the owner, 2026-11-13)

Status: DRAFT. Nothing is approved and no code was changed. Written by the game designer on the owner's question:
how many regiments go into a battle, and how the field scales with that.

Mockups (new, drawn for this doc; the planning session copies them to `docs/design/images/` when the doc is approved):
- [50b_battle_three_lanes_back_line.png](images/50b_battle_three_lanes_back_line.png): 3 lanes with a back line, 6 places a side.
- [50_battle_five_lanes.png](images/50_battle_five_lanes.png): 5 lanes, 10 places a side, reserve and "marching in".
- Base for both: mockup 10, [10_battle_panel.png](images/10_battle_panel.png).

Principles this design is for (docs/research/fun-principles.md v2): **11** readable and light to run (a battle you can read at a
glance, a map that does not fill with tokens), **2** trade-offs (a regiment in the back line, in the front, or in reserve each
has a price), **12** the AI is a rival (the AI builds armies that fit the field instead of blobs). Checked for harm: 6 (the
world pushes back: big armies must not become free), 1 (a decision every few seasons: the new orders must not add clicks).

## Questions for the owner (read these first)

1. **How much now, and when?**
   (a) Slice A in a 0.2.x patch before the cards: the back line, the ranged-by-era table, the reserve rules and the AI's
   army-size rule. Still 3 lanes. Slice B (5 lanes) later, with the mini-map slice, because lane ground comes from the three
   hexes facing the enemy. **Recommended.**
   (b) Both slices in one patch before the cards.
   (c) After the cards. Not recommended: the cards (Grand battery, Change of front, Pike and shot) need the board to exist first.
2. **Back line: ranged troops only, or any spare regiment too?**
   (a) Ranged first, then any spare regiment as "second rank" (it cannot shoot, it steps up with no shake). **Recommended.** A
   six-stack then fills the board exactly: 3 in front, 3 behind, which is the picture in your words.
   (b) Ranged troops only. Pike-only armies see no change from today, and 3 of 6 regiments still sit "in reserve".
3. **Archers.** There is no archer or crossbow unit in the game. Ranged troops today are guns (all eras) and the era 2 and 3
   infantry (arquebusiers, musketeers).
   (a) No new unit. Era 1 has bombards only in the back line; "pike and shot" starts in era 2. **Recommended** (history: the
   Age of Pikes is the pike era; a new unit is art, balance and AI work that this design does not need).
   (b) Add era 1 archers or crossbowmen as a fourth branch. Costs art, data and a rule for who raises them.
4. **Stack limit.** Today 6, +1 with Standing army, +1 with Military revolution, +2 (+1) with a general: 11 at most (12 for
   Turkey). (a) Keep it. **Recommended**: the limit is the cap on a side in a battle and it is rarely the problem (below).
   (b) Raise it by era (6, 8, 10). Fewer tokens on the map, but only safe after 5 lanes exist; test it then.
5. **Relief of a tired regiment** (the "morale is low" half of your rule). (a) In slice A, at 25% morale, once per
   regiment. **Recommended**, but the first numbers say it helps the bigger side a lot (6 v 4 goes from 85% to 98% at 35%), so
   it ships with the lower threshold and a re-measure. (b) Only refill on death or rout in slice A, relief in slice B.
6. **Map clutter.** (a) Do nothing on the map now (one token per hex already). Fix blobs with the AI's army-size rule.
   **Recommended.** (b) Add an "army banner" that groups the stacks of one country and one order. Later, if a playtest says so.

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

### 2.5 A prototype (copy of the code, not the repo)

I made a scratch copy of `combat.py` with a variable lane count (centre-out fill, flank wheel for every unmatched lane, the
break rules generalised) and ran the same fights.

| Rule | 6 v 4 | 7 v 4 | 9 v 4 | 10 v 4 | 8 v 8 | 11 v 6 | Days (7 v 4) |
|---|---|---|---|---|---|---|---|
| Today, 3 lanes | 85% | 85% | 85% | 85% | 48% | 74% | 3.9 |
| 5 lanes if the **bigger** side has 7 or more | 85% | **100%** | **100%** | 100% | 48% | 100% | **1.9** |
| 5 lanes if the **mean** of the two sides is 7 or more | 85% | 85% | 85% | 100% | 48% | 85% | 3.9 |
| Mean rule + relief at 35% | 98% | 100% | 100% | 100% | 46% | 100% | 4.7 |

- Equal fights stay equal (8 v 8 48%, 11 v 11 54%). Good.
- **A wider field lets the bigger side wheel round empty lanes. That is a cliff**: with the "bigger side" rule one more
  regiment turns 85% into 100% and halves the battle. The "mean of both sides" rule moves the cliff to a real 2.5 to 1 edge
  (10 v 4). The flank bonus (`FLANK_BONUS` 1.25) is the lever to soften it. Acceptance test: no step of more than 10 points per added regiment.
- Relief at 35% with a 25-point lead adds 13 points to the bigger side (6 v 4: 85% to 98%) and takes 10 to 16 points off the
  attacker in even fights (4 v 4: 50% to 40%). Use a lower threshold and re-measure.

## 3. Options

Each option lists what it gives, what it costs, the principles it serves, how it reads (map and panel, mockup 10), AI cost,
the 5 ms battle budget, and the save.

### A. Frontage that grows with army size (3, 5, 7 lanes)

- Gives: more regiments fight at once. Wide armies out-wheel narrow ones, so ground matters (a narrow pass or a castle caps the
  frontage at 3 and a small army can choose to meet the big one there). History: at Cerignola (1503) Gonzalo de Cordoba chose ditched
  ground, which the Dig trenches card already names.
- Costs: the wheel cliff above. Both sides must use the same lane count, so the count needs a rule (bigger side, mean, or
  smaller side). "Smaller side" removes the cliff but leaves big armies idle, which is today's problem.
- Principles: 2 (trade-off: ground and size), 14 (it feels like real battle lines). Harm check: 11 if the cards get too small.
- Readability: 5 lanes fit mockup 10's panel with compact cards (150 by 56 px, 5 across in 800 px). 7 lanes would need 100 px
  cards with no numbers; do not go there unless the stack limit rises past 12.
- AI cost: none in the AI. Battle cost +20%. Save: a lane list of 5 instead of 3 (a list, loads as is).
- Interaction: lane ground from the real map (battle.md round 2) names only three facing hexes; 5 lanes need the outer two to copy
  the nearest one. Do it with the mini-map slice.

### B. A back line for ranged troops, and reserves that refill (the owner's rule)

- "Ranged by era", one table in `data.py`: **era 1 bombards; era 2 culverins and arquebusiers; era 3 field guns and
  musketeers.** Cavalry is never ranged (the Pistol ride card adds it later). The Kind says it by branch and era, so units
  and saves do not change.
- Back line = one slot behind each lane (3 slots, 5 with 5 lanes). Ranged troops fill it first, then any spare regiment
  ("second rank", Question 2).
- How they shoot. Guns: as today, `FIRE_LOSS` 0.05 a day, at the front regiment of their own column (centre if it is empty;
  today all guns hit the centre). Shot in the back line: `BACK_SHOT_LOSS` 0.02 a day at the same target, safe from the enemy
  until the centre breaks (today's `BACKLINE_LOSS` rule). Shot in a front lane still shoots at 0.03 as today.
- Reserve: the regiments beyond the board wait off the board. A reserve is a pool, not a place on screen.
- Refill rules, each with a price: (1) a front regiment that dies or routs is replaced at dawn by its own column's second-rank
  regiment with no shake, else by the best of the pool (shaken, `RESERVE_SHAKEN`, as today), else a ranged regiment moves up from
  the back (guns last). (2) A front regiment under `RELIEF_MORALE` swaps with a fresher one (25 points more morale) from its
  column's back slot or the pool, once per regiment per battle; the newcomer is shaken for a day. (3) An empty back slot is
  filled at dawn from the pool by a ranged regiment.
- Principles: 11 (the board shows what each regiment does), 2 (a gun in the back is safe and fires, but cannot hold a lane).
- AI cost: none. Battle cost small (a loop over the back slots). Save: `Battle` gets `back` (a dict of tag to slot list,
  default empty) and `relieved` (ids, default empty); old saves load with defaults and the next dawn fills the slots from the reserve.
- Risks: free back-line damage (see 2.3), and relief helps the bigger reserve (2.5).

### C. The limit: bigger stacks, more joiners, or a cap

- C1. Raise the limit by era (6, 8, 10). Fewer tokens (a top country has 16 stacks in 1600) but it makes idle regiments worse
  unless frontage grows. Safe only after A.
- C2. Keep the limit as a cap on a side and let extra stacks **wait on next-door hexes and join** as space frees (today's join rule).
  Nothing to build in the rules; the panel lists "marching in: X from Y, arrives next season" (mockup 50). **Recommended.**
- C3. A per-side battle cap lower than the limit (the board only). Not needed: the board is 2 times the lanes (6 or 10) and the rest wait in the pool for free. A second cap
  adds a rule the player must learn.

### D. Map clutter

- D1. Leave it. The map already draws one token per hex per side (`_draw_units` groups by hex and side). Measured: clutter is mild before 1575.
- D2. Merge stacks automatically. Rejected: it removes the player's control and does nothing for the AI.
- D3. An army banner: a country's adjacent stacks on one order draw as one flag with a number. UI work only (mapview, no rules).
  Worth it only if a playtest says the late map is unreadable.
- D4. **The AI builds armies that fit the field** (section 5). It cuts blobs and 2-stack scatter at the source. **Recommended.**

## 4. The recommended design

Slice A is the first step. Slice B follows with the mini-map. Numbers are `data.py` constants.

### 4.1 Rules

| Thing | Number | Notes |
|---|---|---|
| Regiments a side may field | the hex's stack limit (6, 7, 8; +2/+3 with a general) | unchanged; extra stacks wait next door and join |
| Lanes `L` | slice A: 3. Slice B: 3 if `S` is 6 or less, 5 if `S` is 7 to 10 | `S` = round of the mean of both sides' regiments at the season start; only grows in a battle |
| Frontage cap by ground | `FRONTAGE_CAP`: open ground 5, hills and forest 3, narrow ground 2 (the closed right lane), castle assault 3 | the smaller army can pick the ground |
| Back slots | `L` (one behind each lane) | ranged first, then spare regiments |
| Board | `2 L` places: 6, 10 | a six-stack fills it exactly |
| Ranged | `RANGED = {artillery: era 1, infantry: era 2}` | bombards; culverins + arquebusiers; field guns + musketeers |
| Back-line shot | `BACK_SHOT_LOSS` 0.02 a day | front lane shot 0.03, guns 0.05 as today |
| Relief | `RELIEF_MORALE` 0.25, fresher by `RELIEF_GAP` 0.25, once each | first measure at 0.35 gave +13 points to the bigger side |
| Second rank drain | `FRONT_DRAIN` (0.02) | the pool keeps `RESERVE_DRAIN` (0.03) |
| Wheel bonus | `FLANK_BONUS` 1.25, tune toward 1.15 if the cliff stays | acceptance: no step over 10 points a regiment |

### 4.2 Line breaks and the dice

- **Break rules stay.** The centre is the middle lane (`L // 2`). An empty centre with nothing to fill it breaks the army and shocks it once
  (`CENTRE_SHOCK`). Flank lanes are all the others. Each day a flank stays broken the centre loses `FLANK_MORALE`.
  "Two broken lanes break the army" becomes: **half the open lanes, rounded up** (2 of 3, 3 of 5, and 1 of the 2 open lanes on narrow
  ground), so today's numbers do not change at 3 lanes.
- A lane that never held a regiment is open ground, not a broken lane (already the rule): the enemy wheels round it. With a small army
  in a wide field the bigger side wheels, with the cliff of 2.5.
- The exposed back line stays: a broken centre exposes the back slots to the enemy's back line at `BACKLINE_LOSS`.
- **Dice:** unchanged. One d6 per side per day (`DICE`, 0.7 to 1.4) for every column. No die per lane.

### 4.3 What the panel shows

- 3 lanes (mockup 50b): mockup 10 plus a back row under each side's front row. Cards at today's size. A "READY" tag on a spare
  second-rank regiment and "fires" on a ranged one. A line under the board: "Reserve: none".
- 5 lanes (mockup 50): compact cards (150 by 56 px): token, name, state tag, men bar, morale bar; the men number on hover. Lane
  names above the front line: far left, left, centre, right, far right. A closed lane greyed. The reserve is a row of chips (one per
  pool regiment, morale on it), and "Marching in" lists the joiners from next-door hexes. 1280 by 720 fits: the field is 800 by 330 px.
- The read model (`battleview`) gets `back` and `pool` lists and the lane count; the panel reads only those. The badge on the map
  shows the regiments on the board and the pool as one number.
- No new buttons: the existing orders stay. One new line of help under them when relief is on. The cannon order row (centre or own
  lane) belongs to the cards slice.

### 4.4 Interactions

- **Economy and debt:** upkeep is unchanged, so a regiment in the pool costs as much as one in a lane: the player pays to wait. A debt
  desertion takes the pool first. A castle assault caps the frontage at 3 and the garrison holds the front centre.
- **War and supply:** unchanged. The supply brake (units over the supply limit lose a hit point a season) stays the natural cap on
  blobs. The AI rule respects it.
- **Tech:** Standing army and Military revolution (+1 stack each) add regiments to the pool beyond the 6-place board, which pay only at 5 lanes (slice B).
  Volley fire (+1 infantry attack) helps shot and pikes. Tercio (pikes vs horse) is a front-lane tech.
  Era 2 and 3 get a real reason to raise guns and shot.
- **Cards (next slice):** most cards target one lane, so the lane count must exist first. Grand battery, Guns gallop up, Countermarch
  (shot fires twice) and Pike and shot need the back line. Change of front swaps two columns.
- **Generals:** a general adds stack places (+2) and now also lets a side reach the 7th and 8th regiment that fills the back row of 5 lanes.
- **Random worlds:** blobs of 6 are common there (31% to 37% of stacks); the AI rule in section 5 matters most.

### 4.5 Risks

- **Back-line guns are a free place** (2.3). Slice A adds shot to the back, which makes this worse. Guard: re-run the arms matrix
  (battle-plan-review item 9) in slice A and keep the exposure rule; if a gun stack still wins above 80%, give guns a 1-lane reach
  (own column and its neighbours) or cut `FIRE_LOSS`.
- **The wheel cliff** (2.5): ship slice B only with the "mean of the sides" rule and a measured curve.
- **Relief snowballs the bigger reserve** (2.5): ship at 0.25, once each, re-measure at 4 v 4 and 6 v 4.
- **The efficient size stays 6.** A six-stack fills the board and 7 or more pay only at 5 lanes, so a player can still spam six-stacks.
  Real brakes are elsewhere: upkeep, supply, the brakes design. The AI rule below is the only fix here.
- **Exploit:** a defender cannot shrink the field to deny the wheel except by terrain, which is a fair choice. An attacker cannot widen a
  field the mean rule does not widen.
- **Snowball:** unchanged in size terms; the 85% plateau above 6 regiments goes away only with slice B, which then helps the bigger
  army. Measure it with the stop-steamrolling set-up.

## 5. Player and AI

The player's orders do not change (Attack, Hold, Withdraw). The player's new choices are who goes in the back slots (the board fills
by the same rule, one drag between slots can come with deployment in slice 3) and how many regiments to bring.

The AI plays the same board; it has no battle rule of its own. It builds and moves armies with these rules (D4, slice A):

1. **A field army is up to 6 regiments** (the board of 3 lanes with a back line), at most the stack limit, plus its general. The AI
   gathers new regiments into one main army up to 6, then starts a second army at the next town, and moves an army only with
   3 or more regiments (the main army and the second one).
2. **No blobs:** a stack of 6 or more does not take in another stack of 3 or more unless it is waiting to attack the same hex.
   Surplus regiments go as a **second wave** to a hex next to the target and join the battle after it starts (`battle_joined`).
3. **Garrisons:** 1 to 2 regiments per border castle or town, never a 2-stack in the interior.
4. The AI's attack ratio counts the regiments that fit the board in full, and the rest at half, so it does not believe 11 pikemen
   beat 4 pikemen. (Today they do not, and the AI would learn nothing.)
5. Targets to prove it in a seeded Europe run to 1600: stacks of 6 or more under 30% of all stacks (45% today), at most 110 stacks
   on the map (130), the share of regiments outside the board under 25% (46% by the day count, 34% to 41% by the battle count),
   and a country moving 6 groups or fewer at a time at p99 (9 today). AI time per season may not grow more than 10%.

Risk: split armies are weaker in a fight. Check the snowball (the biggest country's land share, 0.114 to 0.114 in the timing test)
does not change.

## 6. Perf and saves

- Battle phase: slice A adds a loop over at most 3 back slots; slice B adds about 20% (2.4). Cache the day's values when the phase passes 5 ms.
  `tools/perf.py` gets a `battle_season` row with 10 battles of 11 v 11 as the worst case.
- Saves: `Battle.lanes` stays a list of lanes (length 3 or 5). New fields with defaults: `back`, `relieved`, `frontage` (default 3).
  `fill_defaults` loads old saves. No `VERSION` bump; run `tools/save_compat.py` as usual. A battle saved in a 3-lane build loads with 3 lanes and no back line; the first dawn fills the back from the reserve.

## 7. Where it fits

- v0.2.0 ships with 3 lanes and a reserve. **Slice A goes in a 0.2.x patch before the cards.** Reason: the cards target lanes and
  the back line (Grand battery, Pike and shot, Countermarch), and a card pass on a board that then changes means rework. Slice A
  touches no lane count, so the win-rate bands of the tests stay (only the gun and shot lines move).
- **Slice B (5 lanes, the terrain cap)** goes with the mini-map slice, after the cards, because lane ground and 5 lanes are the same
  geometry and the cards need a first balance on 3 lanes.
- Order inside the milestone: 0.2.0 (3 lanes) -> 0.2.1 slice A -> cards -> mini-map with slice B.

### Smallest first version (slice A)

1. `RANGED` table, `BACK_SHOT_LOSS`, `RELIEF_MORALE`, `RELIEF_GAP` in `data.py`.
2. `combat.deploy`: a back row of 3 slots per side; ranged first, then spares. The refill order of 4.1 (own second rank with no shake, then the pool, then ranged last).
3. `fire`: shot in a back slot shoots at 0.02; guns hit their own column, centre when it is empty. Relief at dawn.
4. `Battle.back`, `Battle.relieved` with defaults; `battleview` adds `back`, `pool`; the panel draws the back row (mockup 50b).
5. AI: the army-size rules 1 to 4 of section 5.
6. Tests: the band tests stay for pikes; new bands for 3 pikes + 3 guns (target under 70% against 6 pikes, 75% today), 4 v 4 with relief (45% to 55%), and a
   pool-refill case. The seeded run of section 5 is the acceptance proof.

Out of scope for slice A: 5 or 7 lanes, terrain frontage, army banner, a new archer unit, deployment drag, per-lane dice.

## 8. Open points and what I did not measure

- Random worlds after 1519 were not measured; the late numbers are Europe only (4 games).
- AI-only battles are lopsided. A playtest with close fights will show how often 5 lanes would apply.
- The prototype is a quick copy, not tested code: it shows the shape of the curves, not final numbers. The relief and wheel numbers need tuning.
- Timings come from a busy machine and are rough.

## Owner's decisions (2026-11-13)
1. **Battlefield width as an attribute, and smaller unit figures.** The width of the field (how many lanes) is its own attribute, set by the ground and the armies (and later techs and generals), not a fixed 3. The panel uses smaller unit figures (compact tiles) so a wide field fits. The revision proposes the attribute and its sources.
2. **Back line:** ranged first, then spare regiments as a second rank.
3. **Archers:** add an era 1 archer (or crossbow) unit, with art, data and rules.
4. **Relief as an attribute:** a unit attribute for how quickly a reserve or second rank changes places with a tired front regiment (working name: "reverse fielding", to be named). The change takes time; while it happens, the enemy keeps fighting the other lanes (and the swapping lane is exposed). Measure how quickly it should happen.
5. Still open: stack limit (recommended: keep 6/7/8 plus a general) and map clutter (recommended: the AI stacking rule, no map change).
