# Sieges and retreats

**Status: draft for the owner, ready for the 0.2.2 batch. Not approved. Sections 3 and 5 are built (0.2.1). Section 4
(sieges) is the 0.2.2 build. Section 6 (field forts) waits for its own patch.** It answers the v0.2.0 playtest notes P3
(withdraw or flee), P4 (sieges) and P5 (field forts) of `docs/roadmap/release-0.2.1-brief.md`.

**Principles it is for** (`docs/research/fun-principles.md` v2): **2** (trade-offs: no siege order is always right),
**3** (the price is shown before the choice), **11** (readable and light: one meter, few new clicks).
Checked for harm: **6** (snowballing: slower conquest helps), **12** (the AI plays it too), **9** (a siege is a story).

## 1. Goal

A war should be a chain of decisions, not a chain of free exits and one-season captures.
- When you march on a town you pick: sit down and starve it, or storm it now and bleed.
- When the enemy sits at your castle you pick: send the relief army, or let it fall and trade land for time.
- (0.2.1 already gave the third choice: leave a lost battle early and clean, or run later and pay.)

Why it is fun: every choice has a clock and a cost you can read, and each place that holds out for a few seasons becomes a
small story (Rhodes, Malta and Vienna are the pattern: a siege lasting seasons, a relief army, a last storm).

## 2. What the game does today (checked in the code, after 0.2.1)

- **Siege** (`war.sieges`): an army alone on an enemy province adds `1 + guns + 1 (siege master)` a season. Need:
  `SIEGE_BASE` 1 for no castle; a castle adds `CASTLE_SIEGE` 3 a level (plus the `siege_points` tech). So no castle: 1 season;
  a tower: 4 points; a large castle: 10. The garrison, supply, terrain and the size of the army do not count. A siege does not
  hurt the garrison. A stack that fled or withdrew onto a hex this season makes no progress there (`world.retreated`, 0.2.1).
- **Measured (seeded all-AI games, four worlds, 240 seasons each):** every one of 997 captures by siege took 1 season.
- A castle **with a garrison** is not besieged first: an army that attacks the hex starts an *assault battle* at once
  (garrison in the centre lane). If the field army is gone and the garrison breaks, the castle is stormed.
- **Relief:** an army that attacks the hex where the besieger stands starts a normal battle. While a battle runs on a hex the
  siege makes no progress. So relief already works. What is missing: it is not visible, and a lost siege does nothing.
- The map shows a siege only as ribbons ("Siege 2/5").

## 3. P3: Withdraw and Flee (built in 0.2.1)

Not open any more; this is what shipped, so the siege rules can lean on it.
- **One order, two outcomes, no Flee button.** Every battle ends in the turn it starts: days are fought until a side breaks,
  withdraws or flees, up to `BATTLE_DAYS` 8. At the cap the side with the lower morale withdraws.
- **Withdraw** (an order, or the standing order of an attacked stack): takes effect from the end of day `WITHDRAW_DAY` 2.
  Cost: `WITHDRAW_PURSUIT` 5% of men (10% for an attacker, `WITHDRAW_PURSUIT_ATTACKER`) and `WITHDRAW_MORALE` 0.25 off the
  regiments' morale. The army goes to land its country controls.
- **Flee** (what a broken line or a front morale under `FLEE_MORALE` 0.10 becomes): `FLEE_PURSUIT` 15% of men, guns lost,
  morale `FLEE_MORALE_LEFT` 0.15 (about 2 seasons before it can attack again). It goes to its own land first, then any free
  land. With no free hex the side surrenders.
- **A stack that withdrew or fled makes no siege progress on the hex it lands on that season** (`world.retreated`).
- **AI:** the same rules; it reads its stance as attacker and defender. It never withdraws from an assault on its own castle.
- **Measured in 0.2.1:** 100% of battles end in their season, 3% by Withdraw, the loser loses 32% of its men (median).

What this means for sieges: a relief battle or a storm is settled in one End season. A whole siege can end in one turn: the
relief army arrives, fights, and the siege is lifted or goes on.

## 4. P4: Sieges (the 0.2.2 build)

### 4.1 The model in one line

A siege is a **meter** on the place: `progress / need`. Each season the besieger adds `rate` points, and hunger adds more
after a time. At `progress >= need` the place falls, but **never before `SIEGE_MIN_SEASONS` 2 seasons of siege**. One meter,
one number a season, drawn on the map.

### 4.2 Rules

**When a siege starts.** An enemy army stands on the hex, no defending field army is there (else it is a battle), and no
battle is running. An army with no castle in front of it just walks in, and that is the siege (as today). A castle with a
garrison gives the attacker the choice in 4.5.

**Need** (what the place can take):
```
need = SIEGE_BASE_NEED (4)
     + CASTLE_SIEGE (3) x castle level x garrison share (garrison hp over full hp, rounded up)
     + ELEVATION of the hex (hills 1, mountains 2, snow 2)
     + the owner's "siege_points" tech bonus (as today, per castle level)
```
A castle with a hurt garrison is easier to take, so a failed storm still helps the next try.

**Rate** (what the besieger adds a season):
```
crowd = the besieger's men over the defender's men
        (garrison men = GARRISON_MEN x garrison hp; with no castle, MILITIA_MEN 500)
        under 1x: 0 (too few to hold a siege) | 1x to 2x: 1 | 2x to 4x: 2 | 4x and more: 3
rate  = crowd + guns (the units' siege points, with the artillery tech bonus, as today) + 1 for a Siege master general
rate is capped at SIEGE_RATE_MAX (6)
```
**Hunger** (the garrison's stores): a place has `1 + castle level` seasons of stores. After that each season of siege adds
`SIEGE_HUNGER` (2) extra points. This is the clock that ends a siege and makes relief urgent.

**The floor.** `SIEGE_MIN_SEASONS` 2: a place falls at the end of the season in which `progress >= need` and the besieger
has stood on it for at least 2 seasons (`Province.siege_turns`). It holds for every place (no castle too), every besieger
(guns, general, a huge army) and for retaking an occupied province. The first season is the army arriving and digging in.
A stack that is not there, that is beaten or that retreated onto the hex does not count that season; a lifted siege goes
back to 0 seasons.

**The besieged province's output is lost while the siege lasts.** A besieging stack forages the province it stands on with no
click (**the default**; the game already models foraging), so the siege does not starve the besieger before the garrison.

**Garrison.** It regrows only when nobody besieges (`GARRISON_REGEN`, as today). A siege does not hurt it; a storm does.

**Relief.** An enemy army that attacks the besieger's hex starts a normal battle (as today), settled in the same turn. While it
runs, progress and hunger stop. If the besieger loses, the siege is lifted: progress, hunger and seasons go to 0. If the relief
army loses, the siege goes on with its progress kept. New: the lifting and its log line. (A *sally*, the garrison joining the
relief army's line, is a later idea, section 9.)

**Falling.** The place changes hands (`province_captured`, `by="siege"`, as today). A captured castle's garrison starts at 0.

### 4.3 The numbers: seasons to take (with the 2-season floor)

**How measured.** The meter is not built, so this is the formula of 4.2 run in a scratch script on the engine's own numbers
(`data.py`: 1,000 men a regiment, `GARRISON_MEN` x `GARRISON_HP` = 600 men a castle level, bombard +1, culverin +2
siege points). Full garrisons, plains, no general, no hunger before the stores run out. These are **paper numbers**, not
measured on a built siege; the build proves each cell (section 12). A regiment is 1,000 men.

| Besieger | No castle | Castle 1 | Castle 2 | Castle 3 |
|---|---|---|---|---|
| 1 regiment, no guns | 2 | 4 | cannot (too few) | cannot |
| 3 regiments, no guns | 2 | 3 | 4 | 7 |
| 6 regiments, no guns | 2 | 3 | 4 | 6 |
| 3 regiments + 1 bombard | **2** (was 1) | 2 | 4 | 6 |
| 6 regiments + 1 bombard | **2** (was 1) | 2 | 3 | 5 |
| 3 regiments + 2 culverins | **2** (was 1) | 2 | 2 | 3 |

Without the floor, three cells (no castle, with guns) were 1 season. With it, only those three cells change.
Today's rule: no castle 1 season for everyone; castle 1 needs 4 points; castle 3 needs 10 points (1 a season
without guns: 10 seasons; with two culverins 5 a season: 2 seasons).

Read: a place with no castle takes 2 seasons whatever you bring (so guns do not help there). A big castle takes 6 to 7
seasons without guns and about 3 with good guns. A small army (1 regiment) cannot take a castle 2 or 3 (the crowd rule).
Variations (same script): a Siege master takes about 1 season off castles 2 and 3 (3 regiments at castle 3: 7 to 6);
hills add 1 to need (castle 2: 4 to 5 for 3 regiments), mountains 2.

**The pace options for the owner** (same script, castle columns 1 / 2 / 3):

| Besieger | As drafted (base 4, hunger 2) | Faster (base 3) | Slower (base 5, hunger 1) |
|---|---|---|---|
| 3 regiments, no guns | 3 / 4 / 7 | 2 / 4 / 7 | 3 / 5 / 9 |
| 6 regiments, no guns | 3 / 4 / 6 | 2 / 3 / 5 | 3 / 4 / 6 |
| 3 regiments + 1 bombard | 2 / 4 / 6 | 2 / 3 / 5 | 2 / 4 / 6 |
| 6 regiments + 1 bombard | 2 / 3 / 5 | 2 / 3 / 4 | 2 / 3 / 5 |

"Faster" mostly removes a season at castle 1 and 2; "Slower" mostly adds to the big castle. The floor already flattens the
bottom of the table, so the choice is about castles 2 and 3. As drafted is the middle.

### 4.4 The same in the engine: seeded all-AI games

The formula was also patched into the season in a scratch run (the build's meter with the floor, hunger and crowd, no
other change; the AI is not yet told to besiege). Across 4 worlds and 240 seasons each, 134 wars: 477 of 515 captures by
siege took 2 seasons, 36 show 1 (sieges the stats script counts from the last pause, for example after a battle on the hex; the floor held: no place fell before its besieger had stood there 2 seasons) and 2 took 3. The mean was 1.93 seasons.
The cost to war pace is in 4.7.

### 4.5 Besiege or Storm (the one new choice)

When an army is ordered onto an enemy castle hex that has a garrison and no field army, the attack list gets two entries
(not a new screen):
- **Besiege** (first, the default): move in and start the meter. No battle, no casualties.
- **Storm** (second): the existing assault battle at once. Its odds card counts the garrison with its men cut by the siege
  progress (see 4.6): `garrison hp x (1 - SIEGE_STORM_CUT 0.5 x progress / need)`, rounded up. A siege that has run long is a
  cheaper storm.

A running siege shows "Storm now" in the panel: one click, the same battle. A place with no garrison or no castle needs no
choice: the army walks in and the meter starts. The siege itself costs no clicks a season: it runs in End season.
(Whether the move-in order is allowed onto a garrisoned hex is a small change to `engage_check` and `step_in`; flagged for the build.)

### 4.6 The odds card for garrisons (proposal)

**The problem (measured).** Today the card reads a castle with one factor per level (`CASTLE_ODDS` 1.41, 1.58, 3.11) on the
plains word bands. Scenario fights of one attacking pike stack against a garrison alone (40 seeds each, `scenarios.stage`,
battle days as in 0.2.1, scratch run) show where the attacker wins half the time, as attacker men over garrison men:

| Castle level | Garrison men | Attacker wins half at (men ratio) | The factor `CASTLE_ODDS` has now | Measured from 10% to 95% wins |
|---|---|---|---|---|
| 1 | 600 | about 1.9 | 1.41 | ratio 1.5 to 2.4 |
| 2 | 1,200 | about 1.15 | 1.58 | ratio 0.95 to 1.65 |
| 3 | 1,800 | about 1.05 | 3.11 | ratio 0.75 to 1.4 |

Two facts: a bigger castle's garrison is *weaker* per man (the cause is not checked), and the curve is steep:
from "loses" to "wins" in a ratio span of about 0.7 to 0.9. A level 3 garrison alone loses at ratio 1.7 to 3.3 (93 to 100%), where
the card says Hopeless. With a field army of 2 to 4 regiments behind the walls, the garrison counts about **3 times its men**
(implied weight 2.9 to 3.1 in 5 of 6 runs at levels 2 and 3, one 1.9; 2.9 to 5.7 and noisier at level 1; 40 seeds each). The attacker's win rate
then stops at 65 to 75% because the stack limit is 6 regiments.

**The proposal: read the garrison as men with a weight, not as a ground factor.**
```
defence men = field men on the hex + garrison men (after the siege cut) x GARRISON_ODDS
GARRISON_ODDS = 3.0 when a field army stands with it; alone: (1.8, 1.1, 1.0) by castle level
the ground factor is 1.0 in a storm (the garrison fights, the ground does not count, as today)
the word = odds_word(attacker men / defence men), the same plains bands
```
Checks against the measured fights: 3 regiments against a level 3 garrison alone: ratio 1.67 / 1.0 = Overwhelming (95 to
100% measured; today: Hopeless). 1 regiment against level 1: 1.67 / 1.8 = 0.93, Poor (28% measured; today Even). 4 regiments
against 2 field regiments and a level 2 garrison: 4,000 / (2,000 + 1,200 x 3) = 0.71, Hopeless (2% measured). 6 regiments there:
1.07, Even (50% measured). Where the curve is steepest the word is one band low at the top (2 regiments against level 1 reads
Favourable at 100%): the card under-promises, which is the safe side. The build re-fits the three numbers with the 31 pairs of
`tests/test_odds_card.py` and keeps each pair in its band.

What the card shows for a garrisoned castle: "Garrison 1,100 men (6 hp left of 12 after 4 of 8 siege points; counts x3 behind
walls)". The siege cut is in the number, so a half-done siege visibly turns Hopeless into Even.

**What the card shows for Besiege: a number, not a word.** Besiege has no dice. The card says **"Falls in about 4 seasons"**
(from rate, need, hunger and the 2-season floor), a second line **"Garrison starves after 3"**, and when there is none,
**"Too few men to hold a siege (need 1,200, you have 1,000)"**. The attack list reads "Besiege (4 seasons)" and "Storm (Poor)".
A relief army the defender can bring is a line "Relief: Castile army 2 days away" in the province panel, not in the card (it can
change; the card stays a pure read of this turn).

### 4.7 What the player sees

- **Map** (like the battle badge; `docs/design/ui/README.md` section 9): the besieged hex shows an amber badge (a tower in a ring,
  the size of the battle's crossed swords). The badge is the **dial** (B, recommended; mockup `docs/design/ui/20_siege_badge.png`):
  its ring fills clockwise from the top, one tick per point; the hunger line is in the hover. The alternative is the **bar** (A):
  a segment bar under the hex. A lifted siege flashes the badge grey once.
- **Province panel:** a "Siege" block: "Lisbon is besieged by Castile. 5 of 10, +3 a season (army 2, guns 1). The garrison
  starves in 2 seasons. Falls in about 2 seasons." Every number has a hover (principle 3). For the besieger a "Storm now" button
  with the odds word. For the defender: "Relief: army X is 2 days away" when one of its armies can reach the hex.
- **Log and ribbons:** "Castile besieges Lisbon (need 10)", "Siege of Lisbon: 5 of 10", "The garrison of Lisbon is starving",
  "The siege of Lisbon is lifted", "Lisbon falls after 4 seasons". The ribbon exists (`feed.py` `_siege_progress`).
- **Task flag:** a place of yours that is besieged shows as a line ("Lisbon is besieged: falls in about 3 seasons").
- **Events** (`hexa/events.py`): `siege_started`, `siege_progress` (exists; add `rate`, `hunger`, `seasons`), `siege_lifted`.
- **Read model:** `siege_view(world, pos, viewer)` in `battleview.py`, with the fog rule of the battle view.

### 4.8 AI

- **Attacker** (`ai.py`): today it attacks at a power ratio of `AI_ATTACK_POWER` 1.1 and picks targets by
  `guns or p.castle == 0 or len(stack) >= 5`. New: targets use *seasons to take* (4.3) from the same formula. It takes the
  nearest place that takes at most `AI_SIEGE_MAX_SEASONS` 4 seasons (6 with guns), counting its supply and the war's remaining
  length. It besieges by default, and storms when the siege is at least half done and its odds ratio is at least
  `AI_ATTACK_POWER`, or when a relief army it cannot beat is coming (a last try). It sends spare stacks to separate targets
  (see 4.9: war pace).
- **Defender:** it sends a relief army when it has a stack with power at least `AI_RELIEF_RATIO` 0.8 of the besieger's and the
  hex is within 2 seasons of travel, with priority to its capital and to castles of level 2 and 3. It rebuilds the
  garrison after a lifted siege.
- **Lifts** a siege when its stack's morale or supply fails, or when it loses a battle.
- **Performance:** one formula per target; no new loop over the map.

### 4.9 The AI war length (measured)

AI wars end at `WAR_LENGTH_AI` 16 turns, or earlier when the war score reaches 5 (`season.war_timeouts`). Seeded all-AI games,
4 worlds (Europe 1480 and random seeds 7, 11, 21), 240 seasons (60 years) each, scratch scripts. "Moved" is provinces that
changed owner at peace.

| | Today (1-season sieges) | Floor and meter, `WAR_LENGTH_AI` 16 | Floor and meter, `WAR_LENGTH_AI` 24 |
|---|---|---|---|
| Wars in 4 x 240 seasons | 142 | 134 | 121 |
| War length, mean (median) | 8.9 (8) | 12.8 (15.5) | 14.2 (12) |
| Ended by the length limit | 31 of 142 (22%) | 67 of 134 (50%) | 42 of 121 (35%) |
| Ended at score 5 | 111 (78%) | 67 (50%) | 79 (65%) |
| Provinces taken by siege or storm per war | 8.0 | 4.8 | 5.4 |
| Provinces moved at peace per war | 4.0 | 2.9 | 3.0 |
| Wars that moved no province | 15% | 23% | 19% |
| Wars that moved 5 or more | 63% | 39% | 44% |
| **Provinces moved per decade, per world** | **23.6** | **16.2** | **15.2** |

Read:
- Today wars end because the score reaches 5, at about 8 seasons. With sieges of 2 or more seasons half of them run out the
  clock; those moved 1.3 provinces on average (a stalemate).
- The map still changes: 16 provinces move per decade in each world, 31% fewer than today (principle 12 holds: it does not stop).
  Fewer provinces change hands, so conquest is slower, as intended (principle 6).
- **A longer limit does not help.** 24 turns gives 0.1 more provinces a war and fewer wars in all; the per-decade number
  falls (15.2). The AI is not short of time; it is short of parallel sieges.
- **Recommendation:** keep `WAR_LENGTH_AI` 16. Change the AI's target rule as in 4.8 (several stacks, nearest 2-season targets,
  besiege while the main army moves on) and re-measure. The target: per decade at least 17 provinces (70% of today), and wars
  that move no province at most 20%. If the AI rule alone does not reach it, then raise the limit to 20, not 24.
- Limits of this run: the AI still storms castles instead of besieging (its rule is unchanged), and no relief logic. Small
  samples: 134 wars; read the sizes, not the decimals.

### 4.10 Interactions

- **Economy:** the besieged province's output stops (foraged). A captured place pays the captor as today. A besieging army
  still costs upkeep, and a long siege is a real cost: the intended brake. No new money flows.
- **War and peace:** `war.peace` ends sieges (progress to 0, siege lifted). War score for a place is unchanged. The war
  goals and peace design (`docs/design/war-goals-and-peace.md`) may want "hold the city for N seasons"; the meter gives it
  a clean hook.
- **Tech:** the `siege` and `siege_points` bonuses keep their meaning (rate, need). The gun cards already say "+X a season".
- **Supply:** wagons still help; the besieger eats the land; the garrison's stores are the clock.
- **Battles:** one battle per hex. A siege pauses while a battle runs. A stack that retreated onto a hex makes no progress
  that season (0.2.1).

### 4.11 Risks

- **Turtling:** every castle takes long, so a defender could build and sit. Brakes: hunger (stores run out in 2 to 5 seasons),
  guns, storms that cut the garrison, the lost output of the province, and the cost of castles (up to 800 ducats plus 2
  upkeep). If a playtest shows turtling, raise `SIEGE_HUNGER` before the rate.
- **Snowballing:** slower sieges slow conquest, which helps principle 6. The risk is the big army with guns: it takes
  everything in 2 to 3 seasons. The crowd and need numbers keep a *small* army out of big castles; the largest country can
  still win. Test with the stop-steamrolling seeded run: the biggest country's land share must not rise faster than today.
- **Stalling AI wars:** measured in 4.9; the fix is the AI target rule, not the timer.
- **Hunger and foraging** hit the besieged player's economy even when the siege fails. The panel says it.
- **The floor is flat at the bottom:** guns do not speed up a place with no castle. Intended (the owner asked for "a couple of
  turns"); a gun card should say "castles" not "places".
- **Clicks:** the only new decision is Besiege or Storm. Principle 11 holds.

## 5. P1 and these designs (built in 0.2.1)

The owner's note was that a battle should finish in the same turn. **Built:** every battle ends in the turn it starts, and the
Battle timing option (Clash, Quick battles) is gone. Consequences used in this doc:
- Withdraw is an order that acts from day 2, and Flee is the price of a break (section 3). No Flee button, no pause between days.
- A second stack that attacks the same hex in the same season joins on day 1. Reinforcing means attacking together.
- **Sieges:** the meter is per season. A relief battle or a storm is settled in one End season, so a siege can be lifted or won
  by storm inside one turn.
- **Forts:** unchanged (section 6).

## 6. P5: Field forts (the owner's idea, lower priority; not in 0.2.2)

### 6.1 Idea

An army on a land hex clicks **Build fort**. After a short time the hex holds a light fort (palisade, ditch, a few guns:
the earthworks of the period). It helps whoever stands in it, and an attacker can besiege it or rush it.

### 6.2 Rules

- **Build:** a stack of 1 or more regiments, not on a castle hex, not on a city, not in a battle. Costs `FORT_COST` 40 ducats
  and 1 timber, and the stack stays in place `FORT_TURNS` 2 seasons (1 with a Siege master general). If it leaves or is
  attacked before the end, the work is lost.
- **Strength:** in the siege formula a fort has `need` 4 + `FORT_SIEGE` 2 = 6 and a garrison of `FORT_HP` 3 (300 men). It adds
  `FORT_DEFENSE` 0.15 defence to its owner's armies (a castle level adds 0.25, `CASTLE_DEFENSE`). Stores: 1 season.
- **It lasts only with an army.** After `FORT_DECAY` 2 empty seasons it is gone. It is not a supply depot, so forts do not push
  a front forward. A country has at most `FORT_MAX` 4 forts at once.
- **The attacker's choice** when an enemy fort holds a stack:
  - **Rush:** attack now. A battle starts with the fort's defence bonus and its garrison in the line. The attacker deals
    `RUSH_PENALTY` 20% less damage on its first 2 days (the ditch). The battle is settled in one turn.
  - **Besiege:** the stack settles on a hex next to the fort and *invests* it. The stack inside is cut off from supply and its
    stores clock starts; the siege meter of section 4 runs with the fort's numbers. The defender may send a relief army, or
    leave by Withdraw (section 3).
- **The invested rule is the hard part.** Today a siege stands on the same hex, so an army inside a fort or castle can only be
  reached by a battle. Rule: a stack beside a hex that holds an enemy stack and a fort or castle, with no enemy of its own on that
  hex, *invests* it. The defender counts as cut off and its stores clock runs. This costs one supply check on the
  neighbouring hexes. If the owner does not want it, a fort can only be rushed, or besieged when empty.

### 6.3 The player

- **Button** on the army panel: "Build fort (40 ducats, 1 timber, 2 seasons)", numbers on the hover.
- **Map:** a small fort glyph on the hex (a pale palisade ring, flat, one ink outline), a hammer pip while it is built, and the
  siege badge when besieged.
- **Attack list:** "Rush" and "Besiege" as in 4.5. The odds card for Rush states the penalty.
- **Log:** "Castile begins a fort at X", "The fort at X is done", "The fort at X is abandoned".

### 6.4 AI

Version 1: the AI does not build forts, but it plays against them (rush or besiege by the same formula). Version 2: it builds
one when a stack has held a threatened border hex for 2 seasons and its country is the weaker side. It never builds a chain
into enemy land (the limit, the decay and "not a depot" prevent it).

### 6.5 Risks

- **Fort chains** (build, advance, build) are a snowball tool. Brakes: not a depot, decays when empty, `FORT_MAX`, 2 seasons of
  standing still, 40 ducats.
- **Turtling:** a fort is a cheap castle. Brakes: weaker than a castle 1, needs an army to stay (it eats and costs upkeep),
  and an invested fort starves in 1 season.
- **Clicks:** one button, used rarely. **Complexity:** the invested rule; that is why forts come after the siege rules.
- The fort questions (when, and the invested rule) are asked when the fort patch is planned, after sieges are played.

## 7. Release fit

| Part | Touches | Size | Fits |
|---|---|---|---|
| P3 Withdraw and Flee, P1 | `battle.py`, `combat.py`, `data.py`, AI stance | S to M | **0.2.1, shipped** |
| P4 Sieges | `war.sieges`, `data.py`, `engage_check`, the odds card, province panel block, map badge (art), events and feed, task flag, AI targets and relief, save fields, tests and stats | M to L | **0.2.2**, its own patch |
| P5 Field forts | all of P4 plus the invested rule, the build order, map glyph, AI v1 | M | **0.2.3 or 0.3.0**, after P4 is played (the battle board is 0.2.3 in the war line) |

## 8. Save format

- **P3:** none (shipped).
- **P4:** `Province` gets `siege_turns: int = 0` (seasons besieged: the floor and hunger) and `besieger: str = ""`. Old saves have
  both at the defaults: a siege in progress keeps its `siege` points and starts its hunger clock at 0. `saves.VERSION` goes up by 1
  only if the loader needs it (defaulted fields do not). The `need` formula changes, so an old mid-siege save may flip a place
  that was nearly taken (and the floor makes a place that had 1 point to go wait 2 seasons); say so in the release notes.
- **P5:** `Province` gets `fort: tuple | None` = (owner tag, hp, seasons left to build, empty seasons). `Unit` needs no field.
- Round-trip test: a save in the middle of a siege has the same `world_digest` after load, and the next season plays on.

## 9. Not in this design (later)

- A **sally** (the garrison joins the relief army's line) and a **sortie**: need the garrison in an attacker's line
  (`combat.py` has it only for the defender).
- **Bombardment** from a distance: removed in slice 1, stays out.
- **Mines, breaches, plague in the camp:** period events, with the events system.
- **Naval blockade** of a port as a siege: the sea slice.
- **Rear guard** (a clean Withdraw that leaves one regiment behind) as a general trait or a card.

## 10. Questions for the owner

Four. A recommended answer is first in each. Free foraging by besiegers is the default, not a question; forts wait for their
own patch.

1. **The model.** (a) **The siege meter:** need from castle level, garrison and terrain; rate from army size against
   garrison, guns and general; hunger after the stores run out; and the 2-season floor. (b) Simply longer timers: keep today's
   points and raise the numbers, plus the floor (no garrison, no hunger, no relief story, the odds card still wrong).
2. **The pace, with the 2-season floor.** (a) **As is** (base need 4, hunger 2: no castle 2 seasons; castle 1: 2 to 4; a large
   castle 6 to 7 without guns, about 3 with good guns; table in 4.3). (b) Faster (`SIEGE_BASE_NEED` 3: a large castle 5 for 6
   regiments). (c) Slower (need 5, hunger 1: a large castle 9 for 3 regiments).
3. **A garrisoned castle.** (a) **Besiege is the default, Storm is the second entry** (one extra choice in the attack list;
   the odds card reads garrisons as in 4.6). (b) Always an assault, as today (no new choice, but then the meter is only for
   places without a garrison, and the 3 to 7 season table does not apply to the places that matter).
4. **The siege badge.** (a) **B, the dial** (the ring of the badge fills; cannot run into the battle badge; the hunger line is
   in the hover). (b) A, the bar under the hex (more readable at a glance; at the closest zoom it runs into a neighbouring
   battle badge). Mockup: `docs/design/ui/20_siege_badge.png`.

## 11. Build order for 0.2.2

One theme, in this order, each step green before the next.

1. **Rules** (`systems/war.py`, `data.py`): constants (`SIEGE_BASE_NEED`, `SIEGE_MIN_SEASONS`, `SIEGE_HUNGER`, `SIEGE_RATE_MAX`,
   `MILITIA_MEN`, the crowd bands, `SIEGE_STORM_CUT`, elevation need); `Province.siege_turns` and `besieger`; the rewritten
   `sieges` (need, rate, hunger, floor, lifting on relief or retreat); events `siege_started`, `siege_lifted`, `rate` and
   `hunger` on `siege_progress`; `engage_check` and `step_in` allow a move onto a garrisoned hex to besiege; the Storm cut of the
   garrison; the stats tool prints seasons to take (section 12). README rules table and numbers.
2. **Read models and the odds card** (`battleview.py`): `siege_view`; the garrison weight in `odds_view` (4.6); a Besiege entry
   with seasons to take; re-fit `GARRISON_ODDS` against `tests/test_odds_card.py`; remove `CASTLE_ODDS`.
3. **AI** (`ai.py`): targets by seasons to take; besiege by default and the storm rule; relief army; lift rule; spare stacks to
   separate targets; re-run the AI war-length measure of 4.9.
4. **UI** (`hud/`, `panels/`, `feed.py`, `reminders.py`): the badge (the owner's pick, 4.7), the province panel Siege block,
   the odds card lines, "Besiege" and "Storm" entries and "Storm now", log lines and ribbons, a task flag line for a besieged
   place of yours.
5. **Art** (`art.py`, `render/draw.py`): the badge, in the Kenney look (flat two-tone, one ink outline, amber ring and gate
   tower), at every zoom size of the mockup; the grey lift flash; goldens regenerated and reviewed.
6. **Proof and release**: section 12, soak, save-compat, changelog (the old mid-siege save note).

## 12. Done when

Measurable targets (the "How to prove it" list):
- **Pace table:** every cell of 4.3 within 1 season in the engine (the stats tool plays each besieger against each place);
  no place falls in under 2 seasons in any test or soak game; 1 regiment cannot take castle 2 or 3.
- **Odds card:** each of the 31 garrison scenario pairs lands in its word's band (or one band low at the top, never one band
  high); the level 3 garrison alone at ratios 1.7 to 3.3 no longer reads Hopeless.
- **AI war length** (seeded all-AI, the same 4 worlds, 240 seasons): at least 17 provinces moved per decade per world (70% of
  today's 23.6), wars that move no province at most 20%, wars ended by the length limit at most 50%.
- **Snowballing:** the largest country's land share by 1600 is not higher than today's in the stop-steamrolling run.
- **AI time:** per season at most 10% more than today (`tools/perf.py`).
- **Saves:** a mid-siege save has the same `world_digest` after load and plays on; the save-compat job passes.
- **Window tests:** the siege badge and the province panel block have goldens; no new pop-up; the only new click is Besiege or
  Storm; the full test suite, soak and monkey runs pass.
- **Playtest:** a hand-played siege of a castle 2 or 3 shows its seasons, its hunger line and a relief battle in the log and
  badge; nobody needs to read this doc to follow it.
