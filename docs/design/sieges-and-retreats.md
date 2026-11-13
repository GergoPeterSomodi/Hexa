# Sieges and retreats: DRAFT

**Status: draft for the owner. Not approved. Nothing is built.** It answers the v0.2.0 playtest notes P3 (withdraw or
flee), P4 (sieges) and P5 (field forts) of `docs/roadmap/release-0.2.1-brief.md`. P1 (a battle finishes in the same turn)
is read as a given; section 5 says what each part does either way.

**Principles it is for** (`docs/research/fun-principles.md` v2): **2** (trade-offs: no exit and no siege order is always
right), **3** (the price is shown before the choice), **11** (readable and light: one meter, few new clicks).
Checked for harm: **6** (snowballing: slower conquest helps), **12** (the AI plays it too), **9** (a siege is a story).

## 1. Goal

A war should be a chain of decisions, not a chain of free exits and one-season captures.
- When your army is losing you pick a price: leave early and clean, or run later and pay.
- When you march on a town you pick: sit down and starve it, or storm it now and bleed.
- When the enemy sits at your castle you pick: send the relief army, or let it fall and trade land for time.

Why it is fun: every choice has a clock and a cost you can read, and each place that holds out for a few seasons becomes a
small story (Rhodes, Malta and Vienna are the pattern: a siege lasting seasons, a relief army, a last storm).

## 2. What the game does today (checked in the code)

- **Withdraw** (`battle.py`): an order any side may take, any season, if a retreat hex exists. At the next season start
  the battle ends. Cost: 5% of men (`WITHDRAW_PURSUIT`), morale kept. Retreat hex = a hex the side *controls* within
  `RETREAT_RANGE` (3 steps). **No such hex: the whole side surrenders.** So an invader beaten in enemy land cannot
  withdraw; it is destroyed.
- **Siege** (`war.sieges`): an army alone on an enemy province adds `1 + guns + 1 (siege master)` a season. Need:
  `SIEGE_BASE` 1 for no castle; a castle adds `CASTLE_SIEGE` 3 a level. So no castle: 1 season; a tower: 4 points; a large
  castle: 10. The garrison, supply, terrain and the size of the army do not count. A siege does not hurt the garrison.
- A castle **with a garrison** is not besieged first: an army that attacks the hex starts an *assault battle* at once
  (garrison in the centre lane); if the field army is gone and the garrison breaks, the castle is stormed.
- **Relief:** an army that attacks the hex where the besieger stands starts a normal battle (`_defender`: enemy war units
  on the hex). While a battle runs on a hex the siege makes no progress. So relief already works. What is missing: it is
  not visible, and a lost siege does nothing to anybody.
- The map shows a siege only as ribbons ("Siege 2/5").

## 3. P3: Withdraw and Flee

### 3.1 The idea

Two different things, with two names and two prices:
- **Withdraw** = an *organised* withdrawal. The army breaks off with its order intact. Cheap, but only while it is still
  organised.
- **Flee** = running away. Always possible, always costly.

### 3.2 Options

**Option A: Withdraw only before the first blow, and only for the attacked side.**
- Open on day 0 only (before day 1 is fought). It is the existing standing order (Hold or Withdraw) plus a button before
  the first day. The attacker chose the fight; if it wants out later it flees.
- Needs: front morale at least `WITHDRAW_MORALE` (0.5) and a retreat hex.
- Cost: `WITHDRAW_PURSUIT` 5% of men (as today). Morale kept. Guns and wagons kept.
- Simple to build and to explain. Weak point: with Clash timing the attacked player sees day 1 only after it is fought,
  so their only chance is the standing order.

**Option B: Withdraw while the army is still steady (a morale gate).**
- Open to both sides on any day while front morale is at least `WITHDRAW_MORALE` (**0.6**) and a retreat hex exists.
  Under that line only Flee is left.
- Cost: as A.
- **Measured** (40 seeds per fight, the scenario fights of `tests/support/scenarios.py`, plains, paper tool in my
  scratchpad): after day 1 the side that will lose has front morale of about 0.65 in the pike fights (3 v 3, 4 v 3, 6 v 4,
  6 v 6; medians 0.62 to 0.67), and after day 2 it is under 0.6 in 97 to 100% of them. In the mixed fights with guns and
  knights the loser is under 0.6 after day 1 already (medians 0.31 to 0.44). So a 0.6 gate means "the window is about day
  1": you must read the fight early and leave early, which is the decision we want. It is a number the player can read on
  the morale bar, not an arbitrary day count.
- Weak point: the *attacker* can walk away at 5% after one bad day, so a probing attack is nearly free. See the extra cost
  in the recommendation.

**Option C: A rear guard pays for a clean exit.**
- Open to both sides on any day, but the army leaves its weakest regiment behind. That regiment is lost (it fights on alone
  and is destroyed; its men count as killed). The rest leave with no pursuit loss. Needs 2 regiments and morale of 0.5.
- A real trade-off and period colour. But it needs a regiment pick (or an automatic pick), and it is the cheapest exit for
  a big army with spare regiments: a snowball for the large side.

**Recommendation: Option B, with one extra cost for the attacker:** an attacker that withdraws after it has fought at
least one day loses `ATTACKER_WITHDRAW_EXTRA` 5% more (10% in all: it left the field it chose). B keeps one organised
decision after day 1 and gives the attacked side a fair window. C's rear guard stays a later idea (a general trait or a card).

### 3.3 Flee (all options)

Open always, to any side, while the battle is on.

| Cost | Number (data.py) | Why |
|---|---|---|
| Men killed in pursuit | `FLEE_PURSUIT` 15%, 20% against an enemy with cavalry | A rout is hunted. A broken army's pursuit today is 10% (`PURSUIT`), 4% for foot (`PURSUIT_FOOT`) |
| Morale | at most `FLEE_MORALE` 0.15 (a broken army today: 0.3) | The army cannot attack for 2 seasons (`ATTACK_MORALE` 0.5, recovery +0.25 a season) |
| Guns and wagons | lost | You cannot run with guns. Costs artillery armies most |
| Scatter | 10% of the survivors desert | A fleeing army falls apart |
| Castle garrison | stays and holds, as today | |

Flee is the same as a rout that you call yourself. The trade-off: fleeing on day 1 costs about what losing costs, but you
keep the rest of the army; staying risks a win and risks a break. Neither is always right.

A fleeing side with no hex to go to surrenders, as today (see 3.4).

### 3.4 One fix the design needs: the retreat hex

Today a retreat hex must be *controlled* by the side. An army in enemy land has none, so it can neither withdraw nor flee:
it surrenders. That makes every deep attack all or nothing and turns a lost battle into a wiped-out army (a snowball for
the defender). Proposal:
- Organised Withdraw needs a hex the side controls, as today.
- Flee may use *any free land hex* in range (no enemy unit, no battle, room), nearest first, own land preferred. The
  morale crash and the scatter are the price of choosing foreign ground.
- A side with no free hex at all still surrenders.

### 3.5 Player and AI

- **Player:** the battle panel's Withdraw button shows its state on hover: "Withdraw (lose 5%; needs morale 60%, yours
  66%)" or, when shut, "Withdraw is closed (morale under 60%). Flee instead: lose 15% of men, guns and wagons, morale
  to 15%". Flee is a second button, red, always there, its price in the hover (principle 3). One confirm for Flee only.
- **AI** (`_battle_stance` in `ai.py`): today it withdraws when its army morale is under `AI_WITHDRAW_MORALE` 0.4 and the
  enemy's is `AI_WITHDRAW_LEAD` 0.15 higher. New: it withdraws while morale is at least 0.6 and it is the weaker side by
  the inverse of `AI_STANCE_RATIO` (1.2); it flees only when morale is under 0.6 and staying is a clear loss (the enemy
  much stronger). It never withdraws from an assault on its own castle (the garrison fights on, as today).
- **Standing order:** an attacked stack's standing order (Hold or Withdraw) stays. "Withdraw" now means: leave before day 1
  if morale is at least 0.6, else hold.

### 3.6 Risks

- **Withdraw spam at 5%.** The gate and the attacker's extra cost limit it. Measure the share of battles ended by a
  Withdraw before and after in `tools/battle_stats.py`; target under 25%.
- **Flee too harsh for gun armies.** Playtest; the numbers are data constants.
- No save impact (section 8).

## 4. P4: Sieges

### 4.1 The model in one line

A siege is a **meter** on the place: `progress / need`. Each season the besieger adds `rate` points, and hunger adds more
after a time. At `progress >= need` the place falls. One meter, one number a season, drawn on the map.

### 4.2 Rules

**When a siege starts.** An enemy army stands on the hex, no defending field army is there (else it is a battle), and no
battle is running. An army with no castle in front of it just walks in, and that is the siege (as today). A castle with a
garrison gives the attacker the choice in 4.5.

**Need** (what the place can take):
```
need = SIEGE_BASE_NEED (4)
     + CASTLE_SIEGE (3) x castle level x garrison share (garrison hp over full hp, rounded up)
     + ELEVATION of the hex (hills 1, mountains 2, snow 2)
     + the owner's "siege_points" tech bonus (as today)
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

**The besieged province's output is lost while the siege lasts.** A besieging stack counts as foraging the province it
stands on, with no click (the game already models foraging), so the siege does not starve the besieger before the garrison.

**Garrison.** It regrows only when nobody besieges (`GARRISON_REGEN`, as today). A siege does not hurt it; a storm does.

**Relief.** An enemy army that attacks the besieger's hex starts a normal battle (as today). While it runs, progress and
hunger stop. If the besieger loses, the siege is lifted: progress and hunger go to 0. If the relief army loses, the siege
goes on with its progress kept. New: the lifting and its log line. (A *sally*, the garrison joining the relief army's
line, is a later idea, section 9.)

**Falling.** At `progress >= need` the place changes hands (`province_captured`, `by="siege"`, as today). A captured castle's
garrison starts at 0 (as today).

### 4.3 The numbers: seasons to take

From the formula, full garrisons, plains, no general (a paper calculation with a scratch script; to be checked with the
battle stats tool when built). A regiment is 1,000 men. "1 bombard" is +1 point, "2 culverins" +4.

| Besieger | No castle | Castle 1 | Castle 2 | Castle 3 |
|---|---|---|---|---|
| 1 regiment, no guns | 2 | 4 | cannot (too few) | cannot |
| 3 regiments, no guns | 2 | 3 | 4 | 7 |
| 6 regiments, no guns | 2 | 3 | 4 | 6 |
| 3 regiments + 1 bombard | 1 | 2 | 4 | 6 |
| 6 regiments + 1 bombard | 1 | 2 | 3 | 5 |
| 3 regiments + 2 culverins | 1 | 2 | 2 | 3 |

Today: no castle 1 season; castle 1 needs 4 points (one season with two guns, two with one); castle 3 needs 10.

Read: a place with no castle takes 2 seasons for a plain army, 1 with guns (a couple of turns, as asked, and guns matter).
A big castle takes 6 to 7 seasons without guns and about 3 with good guns. A Siege master adds +1 (about one season off the
big ones). Hills add 1 to need, mountains 2. A small raiding army cannot take a big castle (the crowd rule).

### 4.4 What the player sees

- **Map** (like the battle badge; `docs/design/ui/README.md` section 9, mockup 11): the besieged hex shows an amber badge (a
  tower glyph in a ring, the size of the battle's crossed swords) and under it a progress bar `progress / need` drawn as pips:
  amber = progress, a dark tick where hunger starts, a red outline when the garrison is starving. A lifted siege flashes the
  badge grey once. Flat two-tone shading, one ink outline, as the rest of the set.
- **Province panel:** a "Siege" block: "Lisbon is besieged by Castile. 5 of 10, +3 a season (army 2, guns 1). The garrison
  starves in 2 seasons. Falls in about 2 seasons." Every number has a hover (principle 3). For the besieger a "Storm now"
  button with the odds word (4.5). For the defender: "Relief: army X is 2 days away" when one of its armies can reach the hex.
- **Log and ribbons:** "Castile besieges Lisbon (need 10)", "Siege of Lisbon: 5 of 10", "The garrison of Lisbon is starving",
  "The siege of Lisbon is lifted", "Lisbon falls after 4 seasons". The ribbon exists (`feed.py` `_siege_progress`); it gets
  the new numbers and the hunger line.
- **Events** (`hexa/events.py`): `siege_started`, `siege_progress` (exists; add `rate`, `hunger`), `siege_lifted`.
- UI proposal to write for the badge and the panel block: `docs/design/ui/` (the siege badge, next to the battle one).

### 4.5 Besiege or Storm (the one new choice)

When an army is ordered onto an enemy castle hex that has a garrison and no field army, the attack list gets two entries
(not a new screen):
- **Besiege** (first, the default): move in and start the meter. No battle, no casualties.
- **Storm** (second): the existing assault battle at once. Its odds card counts the garrison with its hp cut by the siege
  progress: `garrison hp x (1 - 0.5 x progress / need)`. A siege that has run long is a cheaper storm. A storm on day 0 of a
  large castle is the worst bet in the game and the odds word says so.

A running siege shows "Storm now" in the panel: one click, the same battle. A place with no garrison or no castle needs no
choice: the army walks in and the meter starts. The siege itself costs no clicks a season: it runs in End season.
(Whether the move-in order is allowed onto a garrisoned hex is a small movement change; flagged for the build.)

### 4.6 AI

- **Attacker** (`ai.py`): today it attacks at a power ratio of `AI_ATTACK_POWER` 1.1 and picks targets by
  `guns or p.castle == 0 or len(stack) >= 5`. New: targets use *seasons to take* (4.3) from the same formula. It takes the
  nearest place that takes at most `AI_SIEGE_MAX_SEASONS` 4 seasons (6 with guns), counting its supply and the war's remaining
  length. It besieges by default, and storms when the siege is at least half done and its odds ratio is at least
  `AI_ATTACK_POWER`, or when a relief army it cannot beat is coming (a last try).
- **Defender:** it sends a relief army when it has a stack with power at least `AI_RELIEF_RATIO` 0.8 of the besieger's and the
  hex is within 2 seasons of travel, with priority to its capital and to castles of level 2 and 3. It rebuilds the
  garrison after a lifted siege.
- **Lifts** a siege when its stack's morale or supply fails, or when it loses a battle.
- **Performance:** one formula per target; no new loop over the map.

### 4.7 Interactions

- **Economy:** the besieged province's output stops (foraged). A captured place pays the captor as today. A besieging army
  still costs upkeep, and a long siege is a real cost: the intended brake. No new money flows.
- **War and peace:** `war.peace` ends sieges (progress to 0, siege lifted). War score for a place is unchanged. The war
  goals and peace design (`docs/design/war-goals-and-peace.md`) may want "hold the city for N seasons"; the meter gives it
  a clean hook.
- **Tech:** the `siege` and `siege_points` bonuses keep their meaning (rate, need). The gun cards already say "+X a season".
- **Supply:** wagons still help; the besieger eats the land; the garrison's stores are the clock.
- **Battles:** one battle per hex, as spec 3.7. A siege pauses while a battle runs.

### 4.8 Risks

- **Turtling:** every castle takes long, so a defender could build and sit. Brakes: hunger (stores run out in 2 to 5 seasons),
  guns, storms that cut the garrison, the lost output of the province, and the cost of castles (up to 800 ducats plus 2
  upkeep). If a playtest shows turtling, raise `SIEGE_HUNGER` before the rate.
- **Snowballing:** slower sieges slow conquest, which helps principle 6. The risk is the big army with guns: it takes
  everything in 1 to 3 seasons. The crowd and need numbers keep a *small* army out of big castles; the largest country can
  still win. Test with the stop-steamrolling seeded run: the biggest country's land share must not rise faster than today.
- **Stalling AI wars:** AI wars end after about 16 turns (`WAR_LENGTH_AI`); a 6-season siege eats a third of that. Check that
  AI wars still change the map each decade (principle 12).
- **Hunger and foraging** hit the besieged player's economy even when the siege fails. The panel says it.
- **Clicks:** the only new decision is Besiege or Storm. Principle 11 holds.

## 5. P1 and these designs

The owner wants a battle to finish in the same turn. Either Quick battles ("full") becomes the default, or Clash changes.
(Measured with the scenario fights: 52% to 78% of the pike fights end within 3 days, one season; 4 v 3 pikes 26 of 40 and
6 v 4 pikes 16 of 40; mixed fights 27 of 40. So some battles still need a second turn even with 3 days a season.)

- **Withdraw and Flee:** with Quick battles a fight has no turn break, so a decision after day 1 is lost. Then Withdraw is a
  day-0 choice (the standing order, and a button on the attack confirmation for the defender), and Flee is the break of the
  fight (the rout rule). Flee's price becomes the price of a *break*, and a day-by-day Flee button is only needed if Clash
  stays. The AI's check runs once on day 0. **Recommended: keep the rules as written; with Quick battles only the day-0 part
  is used.** A "pause after day 1 to choose Withdraw or Flee" is the middle way if the owner wants the choice back; it is an
  extra click, so not recommended.
- **Sieges:** unchanged. The meter is per season whichever timing is used. With Quick battles a relief battle or a storm
  finishes in the same turn, so a whole siege can end in one End season: the relief arrives, fights, the siege lifts. With
  Clash the siege pauses until the battle ends (as today).
- **Forts:** unchanged (section 6).

## 6. P5: Field forts (the owner's idea, lower priority)

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
    `RUSH_PENALTY` 20% less damage on its first 2 days (the ditch). With Quick battles it is settled in one turn.
  - **Besiege:** the stack settles on a hex next to the fort and *invests* it. The stack inside is cut off from supply and its
    stores clock starts; the siege meter of section 4 runs with the fort's numbers. The defender may send a relief army (it
    fights the besieger as in 4.2), or leave by Withdraw or Flee (section 3).
- **The invested rule is the hard part.** Today a siege stands on the same hex, so an army inside a fort or castle can only be
  reached by a battle. Rule: a stack beside a hex that holds an enemy stack and a fort or castle, with no enemy of its own on that
  hex, *invests* it. The defender counts as cut off and its stores clock runs. This costs one supply check on the
  neighbouring hexes. If the owner does not want it, a fort can only be rushed, or besieged when empty (question 9).

### 6.3 The player

- **Button** on the army panel: "Build fort (40 ducats, 1 timber, 2 seasons)", numbers on the hover.
- **Map:** a small fort glyph on the hex (a pale palisade ring, flat, one ink outline), a hammer pip while it is built, and the
  siege badge and bar when besieged.
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

## 7. Release fit

| Part | Touches | Size | Fits |
|---|---|---|---|
| P3 Withdraw and Flee | `battle.py` stance checks, `data.py`, panel buttons and hovers, AI stance, battle stats | S to M | **0.2.1**, if small (it shares the battle panel and P1's code) |
| P4 Sieges | `war.sieges`, `data.py`, province panel block, map badge and bar (art), events and feed, AI targets and relief, save fields, tests and stats | M to L | **0.2.2**, its own patch (the brief puts "sieges drawn like battles" at 0.2.2 or later) |
| P5 Field forts | all of P4 plus the invested rule, the build order, map glyph, AI v1 | M | **0.2.3 or 0.3.0**, after P4 is played |

One theme a patch: 0.2.1 is the battle board, so P3 goes in only if it stays small. Otherwise P3 goes with P4 as "war that
has a cost".

## 8. Save format

- **P3:** none; new constants only. A save with a `withdraw` stance loads as today.
- **P4:** `Province` gets `siege_turns: int = 0` (seasons besieged, for hunger) and `besieger: str = ""`. Old saves have both at
  the defaults: a siege in progress keeps its `siege` points and starts its hunger clock at 0. `saves.VERSION` goes up by 1
  only if the loader needs it (defaulted fields do not). The `need` formula changes, so an old mid-siege save may flip a place
  that was nearly taken; say so in the release notes.
- **P5:** `Province` gets `fort: tuple | None` = (owner tag, hp, seasons left to build, empty seasons). `Unit` needs no field.
- Round-trip test: a save in the middle of a siege has the same `world_digest` after load, and the next season plays on.

## 9. Not in this design (later)

- A **sally** (the garrison joins the relief army's line) and a **sortie**: need the garrison in an attacker's line
  (`combat.py` has it only for the defender).
- **Bombardment** from a distance: removed in slice 1, stays out.
- **Mines, breaches, plague in the camp:** period events, with the events system.
- **Naval blockade** of a port as a siege: the sea slice.
- **Rear guard** (Option C) as a general trait or a card.

## 10. Questions for the owner

Recommended answer first in each.

1. **P3: which Withdraw rule?** (a) **B: open to both sides while front morale is at least 60%; an attacker that withdraws after
   fighting pays 5% extra.** (b) A: only the attacked side, only before day 1. (c) C: a rear guard stays behind, the rest leave clean.
2. **P3: how hard is Flee?** (a) **15% of men (20% against cavalry), morale 15%, guns and wagons lost, 10% desert.** (b) The same but
   keep the guns. (c) Heavier: 25% of men.
3. **P3: where does a fleeing army in enemy land go?** (a) **Any free land hex nearby; it surrenders only when there is none**
   (so deep attacks are not all or nothing). (b) Keep today's rule: own land only, else it surrenders.
4. **P4: the model.** (a) **The meter: need from castle level, garrison and terrain; rate from army size against garrison, guns and
   general; hunger after the stores run out.** (b) Keep today's points and raise the numbers (no garrison, no hunger): still a timer.
5. **P4: attacking a garrisoned castle.** (a) **Besiege is the default; Storm is a second entry.** (b) Keep today's rule: always an assault.
6. **P4: do besiegers eat the province for free?** (a) **Yes, a besieging stack forages by itself.** (b) No: supply stays as today.
7. **P4: the pace.** (a) **As the table (2 seasons with no castle; a large castle 6 to 7 without guns, about 3 with good guns).**
   (b) Faster (`SIEGE_BASE_NEED` 3). (c) Slower (need 5, hunger 1).
8. **P5: forts, and when.** (a) **After sieges are played: 0.2.3 or later; the AI does not build in version 1.** (b) With the siege
   patch. (c) Drop the idea.
9. **P5: the invested rule** (a stack beside a fort with an army inside starves it). (a) **Yes.** (b) No: forts are rushed, or
   besieged only when empty.
10. **P3 in 0.2.1 or later?** (a) **In 0.2.1 if it stays a small change to the battle panel; else with P4.** (b) Always with P4.
11. **If Quick battles becomes the default, do you want an optional pause after day 1 to Withdraw or Flee?** (a) **No: Withdraw is
    the day-0 choice and Flee is the break.** (b) Yes, one pause, one click.

## 11. How to prove it (when built)

- The table in 4.3 against the code with the battle stats tool: seasons to take within 1 of the table.
- Scenario fights with Withdraw and Flee on: the share ended by a Withdraw under 25%; the loser's loss with Flee about the same as
  the loss of a lost fight (so fleeing is never always right nor never right).
- A seeded full-game run to 1600: places captured per decade, stacks, the largest country's land share (not higher than today),
  AI time per season (at most 10% more), wars ended by a siege.
- Soak and save-compat as for every release. Window test: the siege badge and the province panel block (goldens).
