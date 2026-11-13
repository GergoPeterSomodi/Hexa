# Release 0.2.1 brief: LOCKED

**LOCKED on 2026-11-13.** The owner decided the batch below (their answers are under "Owner's decisions"). Scope is frozen: new ideas go to the backlog, bugs are the only exception. Draft 1 (the battle board) is in this file's git history; its items moved to 0.2.3 (see "The war line").

## Theme

**War you can follow.** A battle is fought to its end in the turn you start it, losing costs something real, and the game stops
interrupting End season. No new systems: this fixes what made v0.2.0 flat (P1, P2, P3 below). Sieges, the owner's other big
note (P4), are the next patch, 0.2.2.

Principles it is for (docs/research/fun-principles.md v2): **9** you see what happened, **2** trade-offs (retreat has a price),
**11** light to run (no pop-up at End season).

**What to expect.** 0.2.1 takes away friction and free exits. It does not add a new war decision; that is 0.2.2 (besiege or
storm, relieve or let it fall). Play 0.2.1 for "can I follow it, and does losing hurt", not yet for "is war engaging".

## What the v0.2.0 playtest found

The owner played v0.2.0 on 2026-11-13 and approved the release. No bugs were reported. The verdict: "game wasn't really
engaging". The owner's notes, each with what the game does today:

| # | Owner's note | Today |
|---|---|---|
| P1 | "Battles must be within the same turn, otherwise you lose out on the progress of it." | Clash (the default) fights day 1 in the attacker's season and the rest in the next one, so the player sees the start, ends the season and finds the rest already fought. Quick battles fights all the days at once but is an option, not the default. |
| P2 | The end-of-turn pop-up for merchants and armies is not fun. Instead, a flag below the top bar's stats could show the unfinished tasks, so no pop-up is needed. ("Need to think about it.") | `reminders.unfinished` builds the list. A window shows it when End season is pressed, and a click goes to the item. Reminders are an option, on by default. |
| P3 | The enemy withdraws from a battle too easily. Restrict it: an organised withdrawal is one thing, fleeing (just running away) is another. | Withdraw is open every season to any side with a retreat hex, and a standing Withdraw takes effect before day 1 is fought. It costs 5% of men (pursuit, all killed) and keeps morale, so it is the cheap way out of any battle, even one not yet fought. |
| P4 | Castles are captured too quickly. Every place needs a basic defence that takes a couple of turns to take. Each turn the siege makes progress based on attack and defence values. An army that comes to relieve the place fights a battle with the besiegers. A siege needs a map marker like the battle badge. | A province with no castle needs 1 siege point and falls in **one season**. A level 1 castle needs 4: one season with two cannons, two with one. Progress is +1 a season, plus cannons and a siege general; the garrison, supply, terrain and the besieger's size do not count. Sieges show only as ribbons ("Siege 2/5"). A relief army moving in already starts a battle. |
| P5 | *Idea:* an army could build a light field fort with a button (1 to 2 turns). An attacker then picks: besiege it (1 to 2 turns, the enemy can reinforce) or rush it (a battle at once, with a penalty). | Not in the game. The army's only orders are move, attack and forage. |

What this says: the war doesn't feel engaging because its decisions are thin. Battles finish off-screen, losers walk away
cheaply, and land changes hands in a season with no siege to fight over. P2 is a UI-noise point: the pop-up interrupts
every season.

## Open bugs

`gh issue list --state open` returned no open issues on 2026-11-13. The playtest reported no bugs.

## Scope

| # | Item | Source | Size | Status |
|---|---|---|---|---|
| 1 | **Every battle ends in the turn it starts (P1, owner decision 2).** A battle fights day after day in the attack's season until one side breaks, withdraws or flees. Nothing carries over: if no side has gone by the day cap (proposed 8 days), the side with the lower front morale withdraws (it pays the Withdraw price) and the battle ends that turn. Clash goes; "Quick battles" is no longer an option, it is how battles work; `BATTLE_MAX_SEASONS` goes. To reinforce, attack the same hex with a second stack in the same season: it joins on day 1. No panel opens by itself: the log line ("Battle of Cremona: won in 4 days") and the task flag open the battle panel on the result, with the day log. | P1 | S to M | **In** |
| 2 | **Withdraw or Flee (P3, owner decision 3).** Withdraw is no longer a free exit. The standing order is **Hold** or **Withdraw**; Withdraw takes effect only after a couple of days of fighting (from the end of day 2) and costs men and morale: 5% of men (10% for an attacker) and 25 points of morale (proposed). A side whose front morale falls under **10%** flees: 15% of men, its guns, morale to 0.15 (no attack for about 2 seasons). A side whose line breaks pays the same as a flight. A fleeing army may run to any free land hex near by, not only its own land; with none it surrenders, as today. The AI follows the same rules (it orders Withdraw when it is clearly losing). The order's hover shows both prices before the choice. The numbers are tuned in the build against the done-when bands. | owner; `docs/design/sieges-and-retreats.md` section 3 | S to M | **In** |
| 3 | **Task flags instead of the End season pop-up (P2).** One "N things to do" flag under End season; a click opens the list (the reminder lines, most pressing first), a line goes there. The count drops as tasks are done; at 0 the flag is gone. End season never asks. The reminders option now turns the flag on and off. | mockup `docs/design/ui/19_task_strip_b.png` (A: `19_task_strip_a.png`) | S to M | **In** |
| 4 | Small fixes: the level 1 castle odds band, the orphan word in the order hint, the perf metric that measures pikes only | v0.2.0 backlog | S each | **In**, first to cut |

**Cut list, in order:** 4; then the "any free hex" flight rule in item 2 (a fleeing army in enemy land surrenders, as today);
then item 3 (the pop-up stays one more release, off by default).

**Order of work:** 1 (it changes when everything else happens), 2, 3, 4.

## The war line (0.2.x after this)

- **0.2.2 Sieges (P4):** every place holds out for at least 2 seasons; a siege meter from the besieger's men against the
  garrison, guns, general, castle, terrain and hunger; Besiege or Storm on a garrisoned castle; a relief army that wins lifts
  the siege; the amber siege badge (`docs/design/ui/20_siege_badge.png`). Design: `docs/design/sieges-and-retreats.md`
  section 4. Its batch opens with four questions: the meter or a longer timer; the pace (with a 2-season floor); Besiege as
  the default with Storm second; the badge's bar (A) or dial (B). A besieged place of yours shows in the task flag.
- **0.2.3 The battle board, as a mini game inside the turn (owner decision 2):** draft 1 of this brief (back line, Rotation,
  the AI army-size rules, the docked panel) re-planned so the player watches the days and decides between them (Withdraw,
  Rotation, reserves), all inside the turn.
- **Trade patch:** the `trade-fixes` branch and the forecast question, slotted after 0.2.2 or 0.2.3 (decision 1 below).
- **Field forts (P5):** after sieges have been played; design section 6.
- Then battle cards, the mini-map, war goals and peace, as the roadmap says.

## Done when (draft)

- No open bug issue; tests, soak, save-compat and perf pass (the battles phase may fight up to 8 days a battle: measure it).
- Battle stats: at least 95% of battles end in the season they start (all of them: none carries over); bigger-side win bands within
  5 points of v0.2.0; battles that end by Withdraw under 25% (measured before and after); the loser's share of men lost, before
  and after, in the stats table.
- Setbacks (principle 8): in a seeded run, a mid-sized country that loses a battle can field half its old army within 10 seasons.
- Owner playtest: start a battle and see its end the same turn; open its day log from the log line; give a weak army the
  Withdraw order, and see it leave after day 2 paying men and morale, or flee once its morale is under 10%, with the cost shown first; end
  five seasons without a pop-up and use the task flag at least once.

## Owner's decisions (2026-11-13)

1. **The war line order:** as recommended. 0.2.1 this brief, 0.2.2 sieges, 0.2.3 the battle board, then the trade patch.
2. **Battle length:** "It should end within the turn. A mini game on the battle board is the plan." Every battle ends in the
   turn it starts; nothing carries over (item 1). The battle board (0.2.3) is to become a mini game played inside the turn;
   its brief starts from that.
3. **Leaving a battle:** "After a couple of turns within the battle mini game the player or AI can decide to retreat, or flee
   when morale is too low. Like 10%? Withdraw costs morale and % of army." Withdraw only after a couple of days, at a cost in
   men and morale; flight below 10% morale (item 2). In 0.2.1 the choice is the standing order set before the fight; in the
   0.2.3 mini game it becomes a choice made between days.
4. **Task flag:** B, one "N things to do" flag with a list (item 3).
   Added the same day (owner): the flag shows Fund research whenever it can be bought (once a year), not only while the
   current tech has no points; "nothing being researched" stays.

## Creative review (2026-11-13, draft 2)

**Verdict: approve with changes (made above).** The theme answers P1, P2 and P3 and stays one small patch. It removes
friction more than it adds decisions, so it will not by itself make war "engaging"; the brief now says so, and the new war
decisions come with sieges in 0.2.2. The war-line order is right.

Changes made:
- **Withdraw no longer acts before day 1.** Today a standing Withdraw takes effect before any day is fought. With one-season
  battles the only moment left is day 0, when every army is above 60%: the gate would never bite and the AI (weaker side,
  morale at least 60%) would refuse every battle for 5%. That is P3 made worse. Now Withdraw acts at the end of day 1, so the
  60% gate is a real test: measured, the loser is about at the line after day 1 in pike fights and well under it in mixed
  fights, so reading the fight early pays (principles 2, 3).
- **One order, two outcomes, no Flee button.** In a fight that ends in one turn there is no moment to press Flee. Flee is what a
  Withdraw order becomes when the army is shaken, and the price of a break. One hover shows both prices (principle 3, 11).
- **Flee is lighter:** 15% of men, morale 0.15, guns lost. Cut: the 20% against cavalry, lost wagons and 10% desertion. Stacked,
  the draft cost about 24% of men plus guns and wagons on *every* lost battle (a break pays the flight price): a snowball for the
  winner (principles 6, 8) and three hidden numbers. The fuller price stays as option 3c. A principle 8 check is in Done when.
- **No auto-opening battle panel.** A panel opening by itself each season is the pop-up of P2 again. The result reaches the
  player through the log line and the Army task flag.
- **Task flag: B recommended** (one flag with a list). It is one widget, it sits where the eye is at the end of a season,
  it survives narrow windows (the top bar drops chips as it narrows; A's flags would lose their chips), and it reuses the
  reminder lines. Size S to M instead of M. A stays the second option; it matches the owner's words more literally.
- **Reinforcing is said plainly.** One-season battles lose the "hold on, help is coming" moment: reinforcing moves to before
  the attack (two stacks attack together). The defender's only answer to an AI attack is its standing order, which is why the
  order must mean something (above). Option 2b keeps carry-overs for anyone who wants that drama back.
- Cut list reordered (cavalry extra already cut); 0.2.3's board flagged for a re-read; Done when and the playtest checklist fixed to
  match (the old line "try to withdraw, refused under 60%" could not happen in a one-turn battle).
- Number to recheck: the draft said "35% to 78%" end within 3 days; the design doc's own counts give 40% to 78%.

**Siege design (section 4): ready for 0.2.2 with changes.** The meter, hunger as the clock, free foraging and Besiege or Storm as
the one new choice are good: a siege becomes a short story with a clock (principles 2, 9, 14). Changes before its batch:
- A floor of 2 seasons. The table lets 3 regiments with one bombard take a place with no castle in 1 season, against the owner's
  "a couple of turns" (P4).
- Pick one badge. B (the dial) cannot run into the battle badge, as A does at full zoom; the hunger tick then goes in the hover.
- Sync section 3 and section 5 with this brief's decisions 2 and 3 (they assume Clash and a Flee button).
- Keep the AI war length check (a 6-season siege in a 16-season AI war) as a must-measure, not a risk note.
- Owner questions trimmed to four: the model (meter or longer timer), the pace (with the 2-season floor), Besiege default with
  Storm second, the badge A or B. Free foraging becomes the default, not a question; the fort questions wait for the fort patch.
