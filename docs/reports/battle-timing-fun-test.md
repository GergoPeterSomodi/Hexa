# Battle timing fun test: "clash" or "full"

2026-11-13. Systems designer. Read-only on the code. Nothing was changed or committed.

## Verdict

Keep "clash" as the default. Keep "full" as an option, named "Quick battles" in the Options row. No number changes are needed for either mode.

In one line: "clash" gives the player about one real decision per war, "full" about one in seven wars. Clash does not make wars drag and does not change the snowball or the AI speed.

Principles judged by (docs/research/fun-principles.md v2):
- 1, a real decision every few seasons. This is the main test.
- 3, show the price before the choice. A battle that is still open is where odds and costs can be shown.
- 11, readable and light to run. "Full" wins here, so it stays as an option.
- 12, the AI is a rival. Checked: the AI uses the window (it withdraws and changes stance).
- 6, the world pushes back. Checked for harm only: no snowball in either mode.

## What was run

- `tools/battle_stats.py --timing clash|full`: 6 seeds, Europe and random worlds, 60 seasons.
- The same tool at 40 seasons, seeds 1 to 4, to compare with `docs/reports/battle-baseline.json` (also 40 seasons, seeds 1 to 4).
- My own script (kept outside the repo): 8 seeds, Europe and random, 120 seasons, both timings, 32 games. It counts joiners, stance changes and withdraw orders between days, war length, land share and AI time per season.
- The scenario fights of the tests (100 seeds, plains and hills) with a simple scripted player: the side that is behind by 1.5 times or more withdraws at the first look.

## The numbers

AI-only games, 120 seasons, 8 seeds per world type:

| Measure | clash | full |
|---|---|---|
| Wars / battles | 272 / 1039 | 277 / 1121 |
| Battles per war | 3.8 | 4.0 |
| Battle length, median / p90 (seasons) | 1 / 2 | 1 / 1 |
| Battles that last more than 1 season | 27% | 4% |
| Battles that last 3 seasons or more | 1% | 0% |
| Safety stop (6 seasons) reached | 0% | 0% |
| Battles with a stack joining | 12.6% | 9.9% |
| Joiner arrives after the first season | 4.0% | 0.5% |
| Stance change between days (share of all battles) | 12.6% | 1.5% |
| Withdraw order between days (share of all battles) | 10.4% | 1.2% |
| Battles ended by "withdrew" | 30% | 21% |
| Attacker wins (of decided) | 89% | 93% |
| Defender wins | 110 | 85 |
| Battles cut short by peace | 27 | 6 |
| War length, median / mean (seasons) | 10 / 10.0 | 8 / 9.4 |
| Largest country land share, start to end (mean) | 0.114 to 0.114 | 0.114 to 0.114 |
| Largest share, max over games | 0.151 | 0.152 |
| AI time per season (AI plus end of round) | 164 + 179 ms | 168 + 181 ms |

Tool results, 40 seasons, seeds 1 to 4, against the baseline of the old one-shot battles:

| | baseline | clash | full |
|---|---|---|---|
| Battles per war | 2.46 | 3.21 | 3.61 |
| Provinces per war | 11.3 | 13.3 | 14.6 |
| Units lost per war | 3.6 | 3.9 | 3.1 |

The 60-season run (6 seeds) agrees: battles per war 3.86 (clash) and 4.00 (full), provinces per war 14.4 and 15.8, attacker win 90% and 94%, median battle length 1 in both.

Scenario fights (near-even, plains and hills), length in seasons (median):
- clash: 3 v 3 takes 2, 4 v 3 takes 2, 6 v 6 takes 3.
- full: 3 v 3 takes 1 (plains) or 2 (hills), 4 v 3 the same, 6 v 6 takes 2 to 2.5.
- Attacker win rates are the same in both modes (plains: 53%, 77%, 87%, 47%). The rules of a day do not change with the timing, only the seasons do.

## Findings

**F1. In AI games most battles are one-sided, so timing barely shows.**
About 65 to 70% of AI battles start above 2.5 to 1, and the attacker wins 94 to 98% of those. Only about 10% start near even. The AI attacks only when it is much stronger. So AI-only runs under-state the difference between the modes. The difference shows in the closer fights a player picks.

**F2. "Clash" gives a decision window in 27% of battles. "Full" gives one in 4%.**
A window is a season start where the battle still stands, so someone can join, reinforce, withdraw or keep fighting. Per war that is 1.05 windows in clash and 0.15 in full. In the near-even scenario fights the window exists in clash almost every time (the first day almost never ends a fight). In full it exists in only 19 to 87% of fights, and it comes after three days.

**F3. The window is worth using.**
After the first day of a near-even fight the side that is behind still wins 22 to 35% of the time on plains (3 v 3, 4 v 3, 6 v 4) and 29 to 48% on hills. So the choice is not obvious: withdrawing gives up a real chance. The scripted player who withdraws when behind by 1.5 times saves about 9 to 12% of a regiment's men per withdrawal. It gives up a win in a minority of cases (1 of 13 withdrawals in 3 v 3, 7 of 49 in 4 v 3, on plains). With the window after day three ("full") the saving is only 2 to 5%, because the men are already lost. There is a price on both sides, which is what principles 1 and 2 ask for.

**F4. "Clash" does not make wars drag.**
Median battle length is 1 season. Only 1% of battles last three seasons or more. No battle reached the 6-season safety stop in either mode. War length is 10 against 8 seasons at the median (10.0 against 9.4 at the mean), and provinces per war are about 8% lower in clash. That is a small cost. The one visible drag is the battles cut short by peace: 27 in clash (2.6%) against 6.

**F5. "Full" is a dice roll the player cannot react to.**
96% of full battles end in the season they begin. The player gives one order (attack or hold) and reads the result. The next chance to act is the next fight. In 65 to 81% of near-even 3 v 3 and 4 v 3 plains fights the whole fight is over in one season. Late joiners are 0.5% of battles. It is not wrong for a player who wants fast play, but it is the weaker mode for principles 1 and 3.

**F6. The AI uses the window.**
In clash, defenders change stance in 47% of the battles that last more than one season, and withdraw in 39% of them. In full they almost never get the chance. So principle 12 holds in clash: the AI answers a battle, it does not just take it.

**F7. Allies already join in the first season in both modes.**
Fights are resolved at the end of the round, so a stack that moves to the battle hex in the same season is a joiner before the first day. Clash adds only the late joiners (4% of battles). The "allies can join" argument for clash is real but small. The decision to withdraw or reinforce is the larger gain.

**F8. No difference in snowball, growth or speed.**
The largest country keeps its land share (0.114 mean at the start and the end in both modes; max 0.151 against 0.152). AI time per season is the same within 3%.

**F9. Both modes fight more than the old war did.**
Battles per war went from 2.5 to 3.2 (clash) or 3.6 (full), and provinces per war from 11.3 to 13.3 or 14.6. This is by design (a battle is now a place, not one roll), and it is not a timing issue. Full is a little higher than clash in both.

**F10. One thing outside timing.**
AI attacks are very lopsided: 89 to 93% attacker wins. A player who attacks closer fights will see a different game from the one the AI plays. Worth a look at `AI_STANCE_RATIO` (1.2) in the next AI tuning round.

## As a player: how many seasons have a real decision?

| | clash | full |
|---|---|---|
| Before the battle: attack or not, which stack, which stance | every battle | every battle |
| Order for the first fight, given in the start season | yes | yes |
| A season where the battle still stands, to join, reinforce, withdraw or keep fighting | 1.05 per war (27% of battles) | 0.15 per war (4%) |
| What the player can see at that decision | morale, losses and a day of dice | nothing, the battle is over |

In clash a player who fights near-even battles meets that window in almost every one of them. In full they meet it about once in seven wars. After the first order, "full" gives close to no battle decisions. That is weak for principle 1 as far as battles go, though other systems keep the player busy.

Does "full" feel like a dice roll? A little: a 6 v 4 fight is decided in 2 seasons with one order, and all the dice (a d6 per side per day, plus per-hit luck) land in one blind block. In clash the same dice are spread over seasons with a look in between, so a bad roll reads as a turn in the story. That also helps principle 9 (remembered moments).

## Recommendation

1. **Default: "clash".** Reason: 1.05 against 0.15 decision windows per war, no drag, no snowball change, the same AI speed.
2. **Keep "full" as an option**, called "Quick battles". Reason: principle 11 (light to run). It costs nothing to keep and the rules are the same.
3. **No data.py changes for either mode.** The 6-season safety stop is never reached, and the stats show nothing to tune. Pursuit on a withdraw (0.05) against a break (0.10) already makes withdrawing a real trade-off: it saves about 10% of a regiment and gives up a 22 to 35% chance to win.

## Decisions for the owner

1. Which default? (a) clash, recommended; (b) full; (c) clash for the player and full for the AI: not recommended, the AI would play by other rules than the player meets.
2. Keep "full" as an Options row? (a) yes, as "Quick battles", recommended; (b) remove it to cut the test surface.
3. The first season in clash fights one day. (a) keep it at one, recommended: it gives the window in nearly every near-even fight; (b) two days: the window comes later and more fights end before it. I did not measure (b).
4. Prompt the player when a battle needs orders? (a) yes: a season-start banner and a ribbon "Battle of X is still on: join, withdraw or fight on". Recommended, because the clash window is easy to miss. It is a UI change and needs the owner's approval. (b) no.
5. Should the AI attack more even fights? (F10, not a timing issue.) (a) look at it in the next AI tuning round; (b) leave.

## Risks and not done

- The AI-only runs have no player. The window counts come from AI games and from scenario fights with a scripted player. A real playtest should confirm them.
- The scripted player is crude (withdraw if behind by 1.5 times). I did not script reinforcing, because that needs a second stack near the battle.
- The scenario length in the tool counts "one day, then the rest" for clash. It does not model peace cutting a battle short.
- 120 seasons is 30 years of play at 4 seasons a year, which is most of the game.
- If the AI gets bolder (F10), run this test again: the gap between the modes will grow.
