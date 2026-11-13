# Battle plan review (technical director, 2026-11-13)

A planning review of the battle system: the balance model, the rest of slice 1 (v0.2.0), and the outline of slices 2
and 3. Nothing here is approved. The owner decides (section 6). Measurements were taken on master at commit `3b3d534`
(PRs 0 to 5), before the balance fix now being built. Line numbers refer to that commit.

## 1. Verdict

1. **The model is sound, but two parts of it cannot hit the targets by tuning numbers.** The lanes, phases, men and
   morale are a good base. The break test and the luck are the problem. Today the outcome is a step: equal numbers are a
   coin flip, and one extra regiment wins 100 times in 100.
2. **The fix being built (defender-only ground, shaken reserves) is right but not enough.** Measured: shaken reserves
   alone change no win rate in the scenarios. Two more changes are needed. Both are small and both live in `combat.py`.
3. **Lock the balance before the odds card, not before the whole UI.** PR 6 and PR 7 can go on now if they read the
   battle through one read model. PR 7b (the odds word) must wait for the locked numbers.
4. **One rule is missing and the UI and the cards both need it:** the defender gets no say before day 1 when the AI
   attacks. 92% of battles end in the season they start. See 2.4.
5. **v0.2.0 order:** balance PR (5b), then PR 6 and PR 7 in parallel, then PR 7b, then PR 8. Cut list in section 3.

## 2. The balance model

### 2.1 What was measured

Scenario fights, pikemen on farmland, 100 seeds each, master. Attacker win rate, and days fought (min to max).

| Fight | Ratio | Attack v Hold | Hold v Hold | Days |
|---|---|---|---|---|
| 3 v 3 | 1.00 | 24% | 49% | 4 to 4 |
| 6 v 6 | 1.00 | 25% | 50% | 7 to 8 |
| 7 v 6 | 1.17 | 100% | 100% | 7 to 8 |
| 6 v 5 | 1.20 | 100% | 100% | 7 to 7 |
| 5 v 4 | 1.25 | 100% | 100% | 5 to 6 |
| 4 v 3 | 1.33 | 100% | 100% | 4 to 4 |
| 6 v 4 | 1.50 | 100% | 100% | 5 to 6 |
| 3 v 4 | 0.75 | 0% | 0% | 4 to 4 |

Other arms, 6 a side, Attack v Hold: 6 knights v 6 pikes 0%. 3 pikes and 3 guns v 6 pikes 100%. 6 arquebusiers v 6
pikes 100%. Mixed v the same mixed 27%.

All-AI games (8 games, 40 seasons, master): 159 battles. 146 lasted one season and 13 lasted two. None lasted longer.
Attacker won 93%. Provinces per war 12.8 (baseline 11.3, so +13%, inside the 30% band). Units lost per war 2.6
(baseline 3.6). No battle reached the safety stop. No surrender.

Battle phase cost: 4.6 ms for 10 battles of 6 v 6 pikes. The soft budget is 5 ms, the hard one 15 ms.

### 2.2 Why it is a step

- **The luck washes out.** Every hit rolls plus or minus 15% (`combat.py:244`). A battle has dozens of hits, so the
  rolls average to nothing. Every 3 v 3 lasts exactly 4 days. Raising the spread per hit cannot fix it: it would need
  to be over 100%.
- **The break test rewards idle men at full weight.** Army morale is the sum of morale times men over the men at the
  start (`combat.py:88`). A reserve regiment that never fought counts as much as one in the line. The side with one
  more regiment in reserve always has the higher number, so it never breaks first.
- So the 93% is two things. The AI attacks at 2 to 9 times the strength (a choice, fine). And the model gives the
  stronger side every fight (a fault). Measuring by strength bucket, as now planned, is the right way to see both.

### 2.3 What makes it hit the targets

Tried on a scratch copy of master (no repo change), 200 seeds each. Targets: even 35 to 50%, about 1.3 times 70 to
85%, about 2 times 90% or more.

| Change | 3v3 | 6v6 | 7v6 | 5v4 | 4v3 | 6v4 | 6v3 | 3v4 |
|---|---|---|---|---|---|---|---|---|
| Master (Attack v Hold) | 21% | 20% | 100% | 100% | 100% | 100% | 100% | 0% |
| Shaken reserves only | 21% | 18% | 100% | 100% | 100% | 100% | 100% | 0% |
| + fortune of the day, 35% | 46% | 42% | 92% | 96% | 100% | 100% | 100% | 0% |
| + fortune of the day, 50% | 48% | 42% | 86% | 88% | 98% | 100% | 100% | 2% |
| + fortune 35% and reserves count a quarter | 46% | 52% | 90% | 72% | 69% | 93% | 98% | 21% |
| Same, Hold v Hold | 53% | 56% | 86% | 78% | 77% | 96% | 99% | 28% |

- **Fortune of the day:** one roll per side per day, applied to all the damage that side deals that day. Rolls for a
  whole day do not average out, so close fights spread. It never flips a 2 to 1 fight. This is the owner's wish for
  luck, measured.
- **Reserves count less in the break test:** an army breaks when its line breaks, not when its average does. In the
  trial a regiment outside the lanes counted a quarter.
- The last two rows are inside or near every target. They are a proof that the levers work, not tuned numbers. The
  curve is still lumpy (4 v 3 under 7 v 6). The systems designer tunes it.
- A third lever was tried and rejected: every rout shakes the whole side. It gave a curve that goes down and up again.

**Recommended balance PR (5b), in this order:**
1. Finish the fix now being built: defender-only ground, shaken reserves, win rates by strength bucket.
2. Add the fortune of the day. Write it in the day's log line ("the day went Castile's way"). Luck the player cannot
   see reads as a cheat.
3. Change the break test so the reserve counts less. One number in `data.py`.
4. Retune the AI's attack threshold against the new curve, and measure the war pace again.

### 2.4 The missing rule: the defender's answer

The AI moves, then the round ends, and the first phase fights three days (`game.py:71-74`, `season.py:177`). When the
AI attacks the player, three days are fought before the player sees the battle. With 92% of battles over in one
season, a defending player usually gets a "Defeat!" ribbon and never an order. The order buttons of PR 7 would be dead
for a defender, and so would the cards of slice 2.

**Recommended rule:** day 1 is fought only after the defender has had a turn. A battle the player starts fights at
once, as today (every AI defender acts after the player). A battle an AI starts waits one round when the defender has
not acted since. The defender can then set a stance, send a reserve, or withdraw at half pursuit.

- It is one condition in `battle._fight_season` and one field on `Battle`. It belongs in PR 5b.
- Cost: an AI attack lands one season later. Measure provinces per war again.
- It makes Withdraw a real choice (stand or give ground) and makes joining matter. It is also the planning window the
  cards need.

### 2.5 What to measure (the gate for PR 5b)

All from `tools/battle_stats.py`, seeded, in the PR report.

- **Win rate by strength bucket**, scenarios and AI games: under 0.8, 0.8 to 1.1, 1.1 to 1.5, 1.5 to 2.5, over 2.5.
  At least 30 fights per bucket in the scenarios. The curve must rise with the ratio.
- **One strength number.** Today there are three: `ai._force` (power times morale, `ai.py:321`), `ai._battle_men`
  (men times army morale, `ai.py:368`), and men at the start in the stats tool (`tools/battle_stats.py:34`). Add one
  public function in `combat.py` that the AI, the buckets and the odds card all use. It must count the ground, ranks
  and the general. Without it the odds word will be calibrated on a different number than the one the AI attacks on.
- **Arms matrix:** pikes, knights, guns, shot, mixed, each against each at equal cost. No stack wins or loses more
  than 80%. Today guns in the back line are never hit (`combat.py:296`), so a gun-heavy stack is a free win.
- **Length:** even battles median 2 seasons. Days must vary (today min equals max).
- **War pace:** provinces per war within 30% of 11.3. Battles per war. Wars ending in white peace.
- **Steamrolling:** win rate of the country with the bigger total army; share of battles where the loser loses more
  than half its regiments (target under 10%); regiments lost per war against the baseline.
- **Stance:** Attack v Hold against Hold v Hold at each bucket. Attack must be right somewhere and wrong somewhere.
- **Cost:** `battle_season` with mixed arms, 8 a side, era 3. Stay under 5 ms, or cache the attack and defence values
  per day (they do not change inside a day).

### 2.6 Risks

| Risk | Sign | Answer |
|---|---|---|
| AI war pace | The softer curve and the defender's answer both slow the AI. | Retune `AI_ATTACK_POWER` in the same PR. Then `WAR_LENGTH_AI` if provinces per war fall over 30%. |
| Steamrolling | A richer country still brings more and better regiments to every fight. | The stack limit caps numbers per hex. The softer curve helps the weaker side at 1.1 to 1.5. Measure it; the real brake is the brakes design. |
| Luck feels unfair | A lost even fight with no visible cause. | The fortune is in the log and the panel. The odds word never promises. |
| Phase budget | 4.6 of 5 ms today, before guns, shot, cards and lane ground. | A worst-case perf metric now. Cache values per day when it passes 5 ms. It is end-of-season time, not frame time. |
| Retuning under the UI | Numbers move after the odds word is calibrated. | 7b is built last. A test maps the word to the measured bucket and fails when the table moves. |

## 3. The rest of slice 1 (v0.2.0)

### 3.1 Order

1. **PR 5b: balance** (section 2.3, 2.4). Gameplay. Gate: section 2.5.
2. **PR 6a: the battle read model** (small, first). One pygame-free function, `battle_view(world, battle, viewer)`,
   returns plain data: sides, lanes, reserve, men, wounded, morale, stances allowed with reasons, the log. Cached on
   `world.version`. The badge, the panel, the feed and the odds card read only this. Slices 2 and 3 will change the
   battle's fields (cards, lane ground, deployment); the screens must not break each time.
3. **PR 6 (log, ribbons, badge, men in panels)** and **PR 7 (panel)**, in parallel, on the read model.
4. **PR 7b: odds card.** After 5b is merged and the bucket table is in the repo.
5. **PR 8: release check.**

### 3.2 Scope: keep, cut, move

| Item | Call | Why |
|---|---|---|
| Log lines and the end summary with the battle's name | Keep | The story of the battle (principle 9). |
| Ribbons | Keep | Cheap. |
| Badge with the tug-of-war bar | Keep | The only map sign of a battle. |
| Men instead of HP in every panel | Keep, but its own small PR | It touches panels that have nothing to do with battles. A slip here must not block the panel. |
| Siege drawn like a battle (spec 3.7) | Move to 0.2.1 | Art and layout work. Not needed to play. |
| Panel: header, sides, bar, field, regiment cards, orders, losses | Keep | The core. |
| Panel: legend, log grouped by season | Cut to a plain last-lines log; legend to 0.2.1 | Saves a day of layout at 1280x720. |
| Panel for battles the player only watches | Move to 0.2.1 | The log line covers them. |
| Odds card | **Keep in v0.2.0** (the spec lets it slip) | The choice to attack is the main battle decision in slice 1. Without the word the player attacks blind. Keep it to one word, men, morale and ground. |
| Two golden scenes | Keep one (the panel) | The map scene churns with every art change. |

### 3.3 The release gate

All must hold. The planning session tags only then.

- No open bug issue (fix issues first).
- Full suite, soak with the battle invariants, save-compat, monkey, determinism digest twice: all green.
- A version 1 save loads and plays. A save taken mid-battle loads and plays the battle on.
- The 2.5 measures are in the PR 8 report, inside their targets or accepted by the owner by name.
- Perf: `battle_season` under the hard budget; the panel draws under 4 ms; a frame with 10 badges stays under 16 ms.
- The odds word matches the bucket table (the test).
- README rules match the code (ground, stances, the defender's answer, luck).
- The human playtest below, done by someone who did not build it.

### 3.4 Human playtest (about 40 minutes, one sitting)

1. Start as a mid-sized country. Declare a war. Hover an attack: is the odds word clear, and do you believe it?
2. Attack at "Even". Watch it for two seasons. Can you say who is winning with one look at the map?
3. Open the panel. Can you say why you are winning or losing? Find your men, wounded and morale without help.
4. Change to Hold, then Withdraw. Did the army go where you expected? Was the cost shown before you chose?
5. Get attacked by the AI. Did you get a turn to answer before men died?
6. Send a second stack into your own battle. Did it join, and could you see it in reserve?
7. Attack a castle with a garrison. Was it clear that it was an assault, and what happened to the castle?
8. Lose a battle. Can the beaten army recover in a few seasons, and did the game say why it cannot attack yet?
9. Save in the middle of a battle, quit, load. Same battle, same numbers?
10. Read the log after ten seasons. Can you name one battle, its place and its year?
11. Anything that felt unfair, slow or silent. Write it down with the season.

A "no" on 2, 3, 5 or 9 blocks the release. The rest become issues.

## 4. Slices 2 and 3

### 4.1 Slice 2: cards

**Where the luck goes.** Slice 1 puts the luck in the fortune of the day. Slice 2 moves part of it into the hand: the
fortune range shrinks and the cards carry the rest. The total stays the same, so the win-rate curve stays in its
bands. The gate is the same bucket table with cards on for both sides, plus two card measures: at even odds a side
with cards against a side without wins at most 20 points more; at 2 to 1 the weaker side with cards wins at most 15%.

**How it builds on slice 1.**
1. **Refactor first, no behaviour change:** all multipliers on a hit (stance, ground, shaken, fortune) come from one
   function, `mods(side, lane, phase)`. Today they are separate `if`s in `combat._Day.hit`. Cards then add rows to
   that table and never touch the day's code. The oracle must be identical.
2. **Cards are data:** a table of key, era, cost, target (lane or army), what it needs (terrain, arm, general trait),
   and a list of modifiers or one of a few named effects (no rout today, fire twice, swap lanes). No card has its own
   code path unless it is one of the named effects.
3. **State:** `Battle` gains the deck, the hand, the points and the cards laid for the coming days. All with
   defaults, so old saves load. Bump the save version to 3.
4. **When cards are played:** the days are fought inside the end of the round, with no pause. So the player lays
   cards **once a season, for the three days to come** (the planning window of 2.4). Sneaky cards lie face down and
   trigger on their condition. The round stays one atomic step: AI battles, saves, the replay and the tests keep
   working.
5. **The AI** plays by a short rule list per card type. Both sides use the same table.
6. **The shared balance table:** one file in `docs/reports/`, written by the stats tool, with the buckets, the
   bands, the fortune range, and each card's measured swing. The odds word, the AI thresholds and the card costs are
   all checked against it. One table, one tool, one test.

**PR order:** mods refactor; card data and deck rules (not wired); hand, points and laying cards (rules, no UI); AI
play; the hand UI on the panel; the card art; tuning and release.

### 4.2 Slice 3

In this order, each its own release step, each measured against the same table:
1. **Lane ground from the real map.** The three neighbour hexes facing the enemy set the lanes. This replaces the
   hex-wide ground and the "right lane closed" rule. The `needs` test of a card takes the lane from the start, so
   ground-only cards need no rework.
2. **Deployment** (presets, drag between lanes). It needs the planning window of 2.4.
3. **The mini-map.** A view of the read model. No rules.
4. **Troop quality** (levies, mercenaries, guard). It moves the balance most; it gets its own tuning round.
5. **Events with a choice.** They need a pause, so they fire only at the season's planning step.
6. **Rivers**, once rivers are map data.

## 5. Things in the code and spec that will hurt

1. **The break test** (`combat.py:88`). See 2.2. Its name is also wrong for the player: the bar shows men times
   morale, not morale. Call it "strength" or "will to fight" in the panel, or the bar will seem to lie.
2. **Luck per hit** (`combat.py:244`). See 2.2. Moving the spread to a named number does not change the result.
3. **A stance change does not bump the map's version** (`battle.py:287`). Anything cached on `world.version` (the
   panel, the badge, the read model) will show the old stance. Call `world.changed()` there.
4. **Three strength formulas** (`ai.py:321`, `ai.py:368`, `tools/battle_stats.py:34`). See 2.5.
5. **Guns cannot be hit** (`combat.py:296`). The back line fires and takes no fire. Counter-battery is a later slice;
   until then cap the guns that fire in a day, or let part of the enemy's fire fall on them. Measure with the arms
   matrix.
6. **The battle log is English text in the save** (`battle.py:44`, `combat.py:423`). The panel and the feed will be
   built on it. A Steam release in more than one language cannot translate a saved sentence. Store the kind and the
   numbers; make the sentence when it is drawn. Cheap now, a save migration later.
7. **Day state in the save.** The fix being built adds `Battle.shaken`, filled in `deploy` and cleared at the end of
   the same day. It is never set between seasons, so it does not belong in the saved state. Keep it on the day object.
8. **The flanks phase rarely fires.** A reserve refills an empty lane before the next day, so a flank is only open
   when a side has no reserve left. In big fights the phase is dead; in small ones it decides everything. Count flank
   hits per battle in the stats before the panel draws a "flank" story.
9. **Two tags per battle** (`state.py`, `Battle.attacker` and `defender`). Allies cannot join ("Not your battle").
   Fine for v0.2.0. The alliances design will need sides as lists; the read model should already give sides as lists
   so the screens do not change then.
10. **The spec's own table is out of date.** Section 4 of the build spec says 6 v 4 wins 100% and calls that "the
    target shape". The owner's targets now say otherwise. Replace that table with the bucket table when 5b lands, and
    move the scenario bands in `tests/test_battle.py` to the new bands.
11. **Small:** the year rule is copied in `battle.py:174`; the perf metric uses pikes only, the cheapest case.

## 6. Decisions for the owner

1. **Luck in slice 1.** (a) Fortune of the day, one roll per side per day, shown in the log: recommended. (b) No
   luck until the cards: then no tuning can reach the targets for close fights, and v0.2.0 ships the step.
2. **The break test.** (a) The reserve counts less, so an army breaks when its line breaks: recommended. (b) Keep
   the average: then one extra regiment keeps winning nearly every time.
3. **The defender's answer.** (a) Day 1 waits until the defender has had a turn: recommended. (b) Keep it as it is
   and add standing orders later. (c) Fight one day, not three, in the first season.
4. **The odds card.** (a) In v0.2.0, built last: recommended. (b) In the first patch, as the spec allows.
5. **What moves to 0.2.1:** sieges drawn like battles, the panel legend, the watch-only panel, the second golden:
   recommended. Or keep all in v0.2.0 and ship later.
6. **Cards and time.** (a) Cards are laid once a season for the next three days: recommended. (b) The game pauses
   every day of a battle: closer to the mockups, but it breaks the one-step round and triples the clicks.
7. **Home ground.** The defender on its own land draws one extra card at the start: recommended (it matches
   defender-only ground and helps the weaker side). Ground-only cards: yes, through the card's `needs` test.
8. **The log in the save** (5.6): structured now: recommended. Or text now and a migration before Steam.
9. **Guns** (5.5): a stopgap in 5b if the arms matrix shows a gun stack over 80%: recommended. Or wait for
   counter-battery in a later slice.

## Owner's decisions (2026-11-13)
1. **Luck:** each side rolls a d6 each battle day, shown as dice: 1 = x0.7, 2 = x0.8, 3 = x0.9, 4 = x1.1, 5 = x1.2, 6 = x1.4 damage that day (6 against 1 is twice the damage). Generals and cards may add +1 or a re-roll later.
2. **Break test:** reserves count much less; an army breaks when its line breaks.
3. **Timing:** build both and fun-test them: "clash" (day 1 in the attack's season, the rest after both sides can act and send help) and "full" (all days at once). Each army gets a standing order for when it is attacked (Hold by default, or Withdraw).
4. **Odds card:** in v0.2.0, built last.
5. Taken as recommended by the planning session: move sieges drawn like battles, the panel legend, the watch-only panel and the second golden scene to 0.2.1; cards are laid once a season for the coming days; home ground gives the defender one extra card and ground-only cards use a card `needs` test; the battle log is stored as data; a gun stopgap only if the arms matrix shows a gun stack over 80%.
