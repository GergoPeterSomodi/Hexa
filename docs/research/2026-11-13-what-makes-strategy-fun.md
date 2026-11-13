# What makes grand strategy and 4X fun, and what it means for Hexa

Date: 2026-11-13. Author: market researcher. Status: research and proposals only. Nothing here is approved.
The proposals go to the creative director, then to the owner. The checklist that comes out of this study is
`fun-principles.md` (same folder).

Read first: section 6 (proposals) and section 7 (how Hexa scores today).

## Summary

- **Evidence.** Strategy players reward three things again and again: decisions that matter all game, a world that
  pushes back, and stories they remember. They punish four things: a dull, solved late game; a cluttered or opaque
  UI; a weak AI; and a buggy launch. Each of these four shows up in at least four of the games studied.
- **Evidence.** Big 2025 releases in the genre launched to Mixed reviews (EU5 about 67% positive, Civ VII about 48%),
  mostly for bugs, UI and AI. Small, focused indie strategy games sit at 81 to 89% positive.
- **Judgement.** Hexa's weak spots are the same as the genre's: the fun tests found no decisions after about 1600, a
  treasury that piles up, dominant options (Low tax, passive tolls) and an AI that wastes its merchants. The good
  news: these are known problems with known answers, and several fixes are already approved or drafted.
- **Judgement.** Hexa's best selling points are its period (1480 to 1650 on a real map), its look (code-drawn tiles in
  the Kenney style), ridges and passes as real borders, and battle cards drawn from real battles. Keep them at the
  front of the store page.
- **Top proposal.** Ship the approved economy and trade fixes before new content, then give the game a visible goal
  ("Aims of the crown", one per era) and make money and the AI matter after 1580 (Crown projects, a price revolution,
  an AI that makes peace and plays for goals).

## 1. Fun theory: what the frameworks say

### 1.1 Interesting decisions (Sid Meier)
Meier's GDC 2012 talk treats a game as a series of interesting decisions [S1]. From the talk's write-up:
- A good decision has a **trade-off**: a cost against a gain.
- It is **situational**: the best answer depends on the state of the game.
- It is **persistent**: it shapes play for a while.
- It allows **personal style**: a cautious player and a bold one choose differently.
- The player needs **enough information**. Meier says to err on the side of too much.
- **Pacing** matters: hard decisions one after another overwhelm, and simple ones in a quiet moment bore.

For Hexa: the fun tests measured exactly this. Real decisions per season for a mid-sized country fall from 3 to 5
(1480 to 1540) to 1 to 2 (1540 to 1600) to none after 1600 [H1, F5].

### 1.2 Mechanics, dynamics, aesthetics (MDA)
Hunicke, LeBlanc and Zubek (2004) split a game into rules (mechanics), the behaviour that rules make in play
(dynamics), and the feelings the player has (aesthetics) [S18]. Their eight aesthetics include challenge,
discovery, fantasy, narrative and expression. Designers build from rules up; players feel from the top down.

For Hexa: Age of Discovery should aim at **discovery** (the New World, fog, new eras), **fantasy** (running a
Renaissance state), **challenge** (a world that pushes back) and **narrative** (a story of your country). A rule
change should name which of these it serves.

### 1.3 Needs that keep players playing (self-determination theory)
Ryan, Rigby and Przybylski (2006) found that a game's support for **competence** (I am getting good at this),
**autonomy** (my choices are mine) and **relatedness** (connection to others) each predicts enjoyment and future
play [S19].

For Hexa: competence needs honest feedback (the trade card that lied [H2, F2] breaks it). Autonomy needs several
viable paths (Low tax being always best breaks it [H1, F4]).

### 1.4 "One more turn": staggered goals
Geoff Engelstein's staggered goal theory: keep several projects running that finish at different times, so the
player is always part-way to the next one. Civilization's research, buildings and settlers are his example of the
"one more turn" pull [S2].

For Hexa: research, the build queue and marches already give this early. Late game, the tech tree runs out (97% known
by 1650 for large countries [H1, F9]) and the build list runs out (about 1580), so the pull stops.

### 1.5 The late game and the snowball (designers' own words)
- In a PCGamesN round-up, lead designers of Civ VI, Humankind, Stellaris, Crusader Kings III and Total War all name
  the snowball as unsolved. Answers they tried: asymmetric victory paths (Civ VI), AI that gangs up on the leader
  (Humankind), a tipping point where the world turns on the player (Shogun 2's Realm Divide), and time pressure
  instead of size pressure (Warhammer II) [S3].
- Stellaris's director says the genre has not taught players that losing can be fun [S3].
- Bart Stewart argues the 4X late game fails because tactical busywork crowds out strategy, and that the game should
  know when it is over [S15].
- Soren Johnson (Old World) calls victory conditions a necessary evil: without them a 4X becomes an aimless
  simulation. Old World's answer is ambitions: goals drawn by the ruler, ten of which win the game [S4].
- EU5's patch 1.1 added "complacency": a realm with no real rival slowly declines, so the player must seek rivals [S10].

**Evidence strength:** strong. Five studios and three independent writers name the same problem.

## 2. Comparable games: praise and complaints

Method: Steam store pages (score, price, tags), review-theme summaries of Steam reviews (VaporLens; an automated
tool, so read its counts as rough), critic reviews and forum threads. Scores are snapshots taken on 2026-11-13 or
quoted by the source; they move with patches.

| Game | Steam (all time) | Price (UK) | Players praise | Players complain |
|---|---|---|---|---|
| Europa Universalis V (2025) | Mixed, 67% of 14,189; recent 41% | £49.99 | depth; pops and markets that run the economy; control that falls off with distance | bugs and crashes; a crowded UI; a slow, hard start; patches that broke things; money floods by 1500 to 1600 |
| Europa Universalis IV (forums) | - | - | the map, "painting" it, emergent history | boring after about 1600; the player outgrows every rival; repetitive blobbing |
| Crusader Kings III | - | - | emergent stories from characters and families | too easy once the systems are learned; slow late game |
| Civilization VII (2025) | Mixed, about 48% | - | visuals; distinct leaders | civ switching and era breaks; cluttered UI; feels unfinished; price |
| Old World (Mohawk) | Very Positive, 84% of 4,046 | £34.99 | family and events; ambitions; deep decisions | steep learning curve; weak tutorial; UI does not track events well |
| Humankind (Amplitude) | about 73% (VaporLens) | - | combat; culture changes that stop the mid-game slog | AI; tedious late game; lack of polish |
| Millennia (2024) | Mixed | - | alternate-history ages | late game tedious; weak AI; shallow diplomacy; support ended after 18 months |
| Field of Glory: Empires | Very Positive, 81% of 739 | £33.50 | decadence stops the dull late game | decadence feels arbitrary to some |
| Ozymandias (small indie) | Very Positive, 89% of 1,324 | £11.99 | an empire in one sitting; no late-game grind | (few: thin depth for some) |
| Hexarchy (small indie) | Very Positive, about 83% | about $20 | short sessions with depth; deckbuilding mix | clunky controls and UI; repetitive |

Sources: [S5] to [S12], [S14], [S16].

### Patterns across games (evidence, with how many games support each)

1. **Dull or solved late game:** EU4, EU5, Humankind, Millennia, Civ (designers), CK3. Six games. Strong.
2. **UI that hides the game or crowds the screen:** EU5, Civ VII, Old World, Hexarchy, Humankind (thin management UI). Five. Strong.
3. **Weak AI:** Humankind, Millennia, EU5, and the Stellaris designer. Four. Strong.
4. **Buggy or unfinished launch drags reviews for months:** EU5, Civ VII, Millennia, Humankind. Four. Strong.
5. **Emergent stories are the most loved part:** CK3, Old World, EU4 ("painting" history). Three. Medium.
6. **Brakes against growth are loved when they make the late game tense, hated when they feel arbitrary:** Field of
   Glory: Empires (both views), EU5 complacency (new), Shogun 2. Three. Medium.
7. **Era changes help pacing but must not break the player's identity:** Humankind (praised), Civ VII (top
   complaint). Two. Medium, but very relevant to Hexa's eras.
8. **Short, focused indies review best:** Ozymandias, Hexarchy, both praised for short sessions. Two. Medium.

## 3. The Steam market for indie historical strategy

### What the data says (evidence)
- Strategy is about 14% of all-time Steam revenue. Inside it, grand strategy is about 9.7% ($1.16B) and 4X about
  8.5% ($1.01B), led by Paradox and Civ titles [S21].
- An older Chris Zukowski analysis found 4X the least crowded genre but among the best earning per game (average
  about $86,600 against $3,700 for puzzle games) [S22]. Old data and self-selected samples: read it as direction.
- Quantic Foundry's nine-year trend: "strategy" (enjoying careful planning) fell more than any other motivation.
  They suggest players are more easily overloaded [S20].
- Store tags on every comparable game: Strategy, Grand Strategy, Historical, 4X, Turn-Based. EU5 adds Economy and
  Trading. Ozymandias adds Hex Grid [S16].
- Prices: small indies £12 to £20; mid-size historical strategy (Old World, Field of Glory: Empires) £33 to £35;
  Paradox £50 [S16].
- Wishlists: guides give 5,000 to 10,000 as a floor for a viable launch [S22]. Zukowski's first-two-weeks benchmarks
  for a new page: 100 (bronze), 500 (silver), 1,200 (gold), 7,000 (diamond) [S22].
- Next Fest: most wishlists gained during the fest (68 to 88%) come from people who never play the demo; a demo
  released before the fest earned about 2.5 times more fest wishlists; median demo conversion is about 16% [S22].

### What it means (judgement)
- There is a paying audience that wants deep historical strategy, and it is not crowded with small studios. But it
  is used to Paradox depth, and it is quick to punish bugs, a bad UI and a weak AI.
- The trend away from heavy planning favours **readability and short goals inside a long game**. Hexa's long,
  many-evenings campaign is right for this audience, but it needs a short format beside it. The approved
  "Chronicles" scenarios are that format.
- A price of about $20 to $25 in Early Access fits a small studio's historical strategy game; under the mid-size
  £33 to £35 band until the content matches. This is my estimate, not data.
- Launch quality matters more than launch features. Two of the biggest names in the genre lost months of review
  score to bugs and UI.

## 4. First impressions and the store page

Evidence from marketing guides [S17, S23]:
- **Trailer:** open on gameplay in the first few seconds; cut logos and titles from the opening. Keep it under about
  60 seconds.
- **Screenshots:** shoppers click through screenshots first. At least one must show the UI so the genre is clear.
  The first three matter most.
- **Capsule:** must read at a tiny size (about 120 to 184 px wide).
- **Demo:** about 30 to 60 minutes, a complete arc with a strong end that leaves the player wanting more. Not "the
  first 30 minutes of the full game". Start fast; no wall of tutorial. Release it before Next Fest. Plan two to four
  demo updates.
- **The first minutes of play:** players decide within minutes whether to keep going.

What this means for Hexa (judgement):
- The first screenshot should be the real 1480 map at a mid zoom with tile art, borders, a battle badge and the top
  bar. The map is the hook; the playtest also called it the best part [H4].
- The trailer should open on armies walking across a pass, then a battle card being played.
- The demo should be the approved Portugal Chronicle, cut to a 30 to 60 minute arc with a grade at the end.
- The first five seasons of any game must show the goal, one good trade order, one build, research, and a threat.

## 5. What Hexa has and plans (checked in the docs)

- **Built:** real 1480 map, ridges and passes, 32 goods and markets, merchants, pops and taxes, tech tree with eras and
  idea cards, castles and sieges, supply, the top bar with resource changes, floating text, an action log, end-of-turn
  reminders, slow visible movement.
- **Being built:** battle slice 1, "Battles that last" (v0.2.0): lanes, days, morale, wounded, Attack/Hold/Withdraw.
  Cards and the battle mini-map come in slices 2 and 3.
- **Approved, not built:** E2 (investment pays), E3 (tax forecast, High as an emergency lever), E4 (buildings say what
  they are for), E5 (auto-recall losing orders), T1 (merchants after background trade), T2 (flagged orders, AI
  re-pick, "Re-pick best"), T5 (merchant nudge), the achievements list (12 first) and Chronicles (Portugal first).
- **Drafted, waiting for decisions:** Crown projects (E1), reactive prices (T3), war goals and peace, brakes (stop
  steamrolling), rebels, debt and bankruptcy.
- **Open:** how to win (roadmap open question 1).

## 6. Proposals for Hexa, ranked by fun gained against cost

Type: **New** = a new idea; **Change** = a change to an approved design; **Supports** = support for something
already planned. Principle numbers refer to `fun-principles.md`.

| Rank | Proposal | Type | Fun gained | Cost | Principles |
|---|---|---|---|---|---|
| 1 | Ship the approved economy and trade fixes first | Supports | high | low | 1, 2, 3, 13 |
| 2 | Battles that tell a story | Supports (v0.2.0) | high | low | 3, 9, 11 |
| 3 | Aims of the crown: a goal per era | New | high | medium | 4, 10, 7 |
| 4 | Crown projects plus a price revolution | Supports E1 + New | high | medium | 1, 5, 15 |
| 5 | An AI that plays for goals and makes peace | Supports war goals | high | medium | 13, 6 |
| 6 | A rival for the leader | Change (brakes) | medium-high | medium | 6, 8 |
| 7 | The first five seasons | Supports (T5, reminders) | medium | low | 14, 10 |
| 8 | The chronicle of your game | Supports Phase 5 end screen | medium | low-medium | 9, 10 |
| 9 | Late-game bulk actions | New | medium | medium | 12 |
| 10 | The demo is a Chronicle | Supports Chronicles, Phase 6 | medium (sales) | low | 14, 15 |

### 1. Ship the approved economy and trade fixes first (Supports)
- **What:** build E2, E3, E4, E5, T1, T2 and T5 before any new economy content.
- **Why:** they fix a lying order card, two dead options and a dominant one. A new system on top of a broken
  signal stays broken. The genre's evidence (pattern 2) says players do not forgive UI that hides the truth.
- **Fun gained:** high. **Cost:** low (numbers, one reordering, UI lines; mostly measured already).

### 2. Battles that tell a story (Supports v0.2.0)
- **What:** inside slice 1, without new mechanics:
  - Name each battle after the nearest settlement and the year ("Battle of Pavia, 1525") in the log, the battle
    panel and the `battle_ended` event.
  - Before an attack, show the odds the player can read: both sides' men, morale and the lane match-up.
  - After a battle, one short summary: who broke, men killed and wounded, where the loser retreated.
- **Why:** the playtest found war opaque [H4]. Named moments are what players remember (pattern 5). Named battles
  also feed proposal 8 and the achievements.
- **Fun gained:** high. **Cost:** low. It should go to the battle build as a small addition, not wait.

### 3. Aims of the crown: a goal per era (New)
- **What:** at the start and at each new era, the player picks one aim from three, like the idea cards (the same
  screen and pattern). An aim is a concrete, period goal with a deadline of about 10 to 20 years, for example:
  "Hold a port on the Barbary coast", "Found three colonies", "Win a battle against a larger army", "Make Lisbon a
  city", "Finish two Crown projects", "Keep the peace for 20 years". Completing one gives prestige (score) and a
  small lasting bonus. Missing it costs a little prestige, nothing more. Some aims come from the country (national),
  some are general, as with ideas.
- **Why:** Hexa has no stated goal [H4], and the late game has no pull. Goals with deadlines give the medium layer
  of staggered goals (principle 4). Johnson's ambitions solved the same problem in Old World [S4]. This is the
  principle, not a copy: Hexa's version reuses its own era gate and card pick, and names historical aims.
- **Links:** it gives the "how do you win" question an answer (score = aims + projects + ranking), feeds the
  achievements and gives the Chronicles grades a shape.
- **Fun gained:** high. **Cost:** medium (a pick screen exists; needs about 30 aims, checks and AI picks).
- **Owner decision:** do you want aims, and should they count toward winning?

### 4. Crown projects plus a price revolution (Supports E1, plus New)
- **What:** build Crown projects as drafted [H7]. Add one historical rule: **the price revolution**. From about 1540,
  New World silver raises prices across Europe. In Hexa: from 1540 a treasury above about 15 seasons of income loses
  a small share of its value each year, and the event is announced ("Silver from the Indies: prices are rising").
  Money spent on projects, buildings or armies is safe.
- **Why:** the economy test showed that a tax does not fix the hoard; something must be worth buying [H1, F8]. Crown
  projects are that something. The price revolution adds a reason to spend now rather than later, and it is real
  history of the period (principle 15). Inflation alone is not a choice, so it only works together with projects.
- **Fun gained:** high. **Cost:** medium (projects are drafted; the price revolution is one rule, one event, one line in
  the treasury card).
- **Owner decision:** add the price revolution to the Crown projects design?

### 5. An AI that plays for goals and makes peace (Supports war goals and peace)
- **What:** in the war goals build, give priority to the AI parts: the AI names a goal, fights for it, offers and
  accepts peace by war score, and uses Crown projects and T2's re-pick.
- **Why:** a weak AI is a top-three complaint in the genre (pattern 3). Today Hexa's AI never offers peace to the
  player and attacks on a 12% roll [H6]. A rival with visible aims is half of a tense late game.
- **Fun gained:** high. **Cost:** medium (already in the draft; this is a priority call).

### 6. A rival for the leader (Change to the brakes draft)
- **What:** add to the brakes design: when a country (the player included) leads the ranking by a clear margin, its
  largest neighbours name it their rival. Rivals get a cheap war goal against it and join coalitions more readily.
  Beating a named rival in a war gives prestige. Show "Rival of: France, Castile" in the country panel.
- **Why:** designers' best answers to the snowball were "the world turns on the leader" [S3] and "seek a rival" [S10].
  The coalition rule in the draft triggers on infamy only; a peaceful runaway (a rich trader) meets no pushback.
- **Fun gained:** medium-high. **Cost:** medium (uses the draft's relations, goals and coalitions).
- **Owner decision:** should a peaceful leader also draw rivals, or only an aggressor?

### 7. The first five seasons (Supports T5 and reminders)
- **What:** a short start card: who you are, how the game ends and scores, and your first aim (proposal 3). Then T5's
  merchant nudge, a "Best here" build hint, and a pointer to research. No tutorial wall.
- **Why:** the playtest's new player left merchants idle for 40 seasons and had no goal [H4]. Demo advice says the
  first minutes decide (section 4).
- **Fun gained:** medium. **Cost:** low.

### 8. The chronicle of your game (Supports the Phase 5 end screen)
- **What:** the game keeps a short history: named battles, wars and their peace terms, aims completed, eras reached,
  borders at each era. At the end (or from the ledger) the player reads it as a few pages, with the border maps side
  by side.
- **Why:** remembered moments (principle 9); it also gives the player something to share and the store page a
  screenshot. The action log and bus events already hold most of the data.
- **Fun gained:** medium. **Cost:** low to medium.

### 9. Late-game bulk actions (New)
- **What:** as the country grows, add bulk orders with an override: "Re-pick best" for merchants (approved), "Invest
  best here" across a region, and "Garrison restless regions". Each shows what it will do before it does it.
- **Why:** principle 12. The genre's late game drowns in clicks (pattern 1, [S9], [S15]); EU5 had to add bulk army
  commands in a patch [S10].
- **Fun gained:** medium. **Cost:** medium.

### 10. The demo is a Chronicle (Supports Chronicles and Phase 6)
- **What:** the Steam demo is the Portugal Chronicle cut to a 30 to 60 minute arc, ending with a grade and a
  "wishlist to keep playing" screen. Release it before a Next Fest, with the store page live months earlier.
- **Why:** section 4. A long sandbox makes a weak demo; a short arc with a grade makes a strong one.
- **Fun gained:** medium (for sales, high). **Cost:** low once Chronicles exist.

### Decisions for the owner
1. Aims of the crown (3): yes or no, and should aims count toward winning?
2. Price revolution (4): add it to the Crown projects design?
3. Rivals (6): only for aggressors, or for any runaway leader?
4. Battle storytelling (2): add named battles and the odds preview to v0.2.0 now?
5. Pricing and launch (judgement only): Early Access at about $20 to $25, with the demo as a Chronicle?

## 7. How Hexa scores today against the principles

Honest view from the fun tests, the playtest and the docs. "Planned" names the fix already on the roadmap.
Numbering is the v2 list of `fun-principles.md`. The owner's decisions on this study's proposals and on the principles are in `2026-11-13-creative-review.md` (end of the file).

| # | Principle | Today | Why | Planned fix |
|---|---|---|---|---|
| 1 | A decision every few seasons | weak | 3 to 5 a season early, 0 after 1600 [H1] | E1, T3, war goals, aims (new) |
| 2 | Trade-offs, not checklists | weak | Low tax dominant, tile investment dead, tolls dominant [H1, H2] | E2, E3, T4 later |
| 3 | Price before the choice | partial | hover cards and move preview are good; the order card lied; High tax's cost hidden | T1, E3, E4 |
| 4 | Overlapping goals | partial | good early; tree 97% done by 1650, build list done by about 1580 | research pace pass, projects |
| 5 | Every resource has a job | weak | median hoard 44 seasons of income in 1649 | E1 |
| 6 | World pushes back | weak | no brakes; the map barely moves; AI never asks for peace | brakes, war goals |
| 7 | Eras change what you do | partial | era gate, idea cards and troops by era; research too fast | research pace pass |
| 8 | Setbacks are stories | partial | debt almost never happens; wars end by a timer | bankruptcy, war goals, rebels |
| 9 | Remembered moments | weak | one-line battles today; log and floating text help | v0.2.0, events (Phase 3) |
| 10 | A goal from the first season | weak | only the 1650 ranking; winning undecided | none yet (aims proposed) |
| 11 | Readable and light to run (old 11 + 12) | partial | top bar and province panel praised; war opaque; reminders, march R, re-pick (approved); late-game clicks not measured, no click counter | UI clean-up, battle panel, T2, click counter |
| 12 | AI is a rival (old 13) | weak | 78 to 88% of AI orders carry nothing; AI hoards; random war roll | T2, war goals |
| 13 | Fun in the first 30 minutes (old 14) | partial | the map and first season are pleasant; merchants hidden; no goal | T5 |
| 14 | Feels like 1480 to 1650 (old 15) | good | real map, ridges and passes, history battle cards, Chronicles | keep |
| 15 | More than one way to play well (new) | not measured | no seeded run of trader, conqueror and coloniser yet; Low tax and tolls suggest one dominant line [H1, H2] | E2, E3, T4; a run once scoring is decided |
| 16 | History told honestly (new, hard line) | not measured | no aim, score or achievement touches the subject yet; colonies and the West African coast come with later designs | check every aim, achievement and Chronicle blurb; triangle trade design |

Reading it: Hexa is strong on look and period, and fair early. It is weak where the whole genre is weak: the late
game, the AI and the goal. The weakest lines all have a drafted or approved fix except principle 10 (a goal), which
is why proposal 3 is the one new idea I rank high.

## 8. Risks and gaps

- VaporLens theme counts are automated and small; I used them only where a critic or the store page agreed.
- Steam scores move with patches (EU5 went from Mixed to lower recent scores in 2026). They are snapshots.
- Market numbers (genre revenue, wishlist floors, demo conversion) come from marketing analysts and self-selected
  surveys. Use them as direction, not targets.
- I found no hard data on median sales for small indie grand strategy games, or on the age of the audience.
- I did not read forum threads in languages other than English, and I did not play the games for this study.
- No Hexa proposal here was tested in the engine. Proposal 4's numbers (15 seasons, a small yearly loss) are a start
  for the systems designer to measure.

## Sources

Fun theory and design
- [S1] Sid Meier, "Interesting Decisions", GDC 2012, write-up: https://www.gamedeveloper.com/design/gdc-2012-sid-meier-on-how-to-see-games-as-sets-of-interesting-decisions
- [S2] Geoff Engelstein, "Staggered Goal Engagement Theory": https://gametek.substack.com/p/staggered-goal-engagement-theory
- [S3] PCGamesN, designers on the strategy endgame: https://www.pcgamesn.com/civilization-vi/strategy-game-endgame-design
- [S4] Soren Johnson, Old World Designer Notes #11 "The End": https://www.designer-notes.com/?p=1748
- [S13] Axioms of Dominion, "Snowballing, map painting, blobbing": https://axiomsofdominion.substack.com/p/snowballing-map-painting-blobbing
- [S15] Bart Stewart, "Five suggestions for 4X fun": https://www.gamedeveloper.com/design/five-suggestions-for-4x-fun
- [S18] Hunicke, LeBlanc, Zubek, MDA (2004): https://users.cs.northwestern.edu/~hunicke/MDA.pdf
- [S19] Ryan, Rigby, Przybylski (2006), motivation in video games: https://selfdeterminationtheory.org/player-experience-of-needs-satisfaction-pens/

Games
- [S5] Civilization VII: https://vaporlens.app/app/1295660/sid_meiers_civilization_vii ; https://www.windowscentral.com/gaming/civilization-vii-steam-rating-mostly-negative ; https://80.lv/articles/less-than-half-of-civilization-vii-s-players-on-steam-are-happy-with-the-game/
- [S6] Humankind: https://vaporlens.app/app/1124300/humankind™ ; https://aftermath.site/humankind-re-review-amplitude-impressions-pc-sega-4x/ ; https://gamesradar.com/humankind-review
- [S7] Crusader Kings III: https://pcgamer.com/crusader-kings-3-review ; https://vaporlens.app/app/1158310/crusader_kings_iii
- [S8] Old World: https://store.steampowered.com/app/597180/Old_World/ ; https://www.pcgamer.com/old-world-review/ ; https://opencritic.com/game/11628/-
- [S9] Forums on the late game: https://forums.civfanatics.com/threads/the-core-of-4x-games-boring-endgame-problem-a-short-essay-about-rapidly-increasing-complexity.677400/ ; https://steamcommunity.com/app/3450310/discussions/0/572679490124331539/ ; https://admin-forum.paradoxplaza.com/forum/threads/is-map-painting-a-core-identity-of-europa-universalis.1492888/latest
- [S10] Europa Universalis V: https://store.steampowered.com/app/3450310/Europa_Universalis_V/ ; https://acoup.blog/2025/10/31/miscellania-europa-universalis-v-confirmed-first-impressions/ ; https://mein-mmo.de/en/the-latest-game-from-the-swedish-strategy-geniuses-punishes-you-now-if-you-get-too-comfortable,1555483/ ; https://finalboss.io/europa-universalis-5-rossbach-1-1-tackles-ui ; https://mein-mmo.de/en/the-swedish-strategy-nerds-are-now-even-exaggerating-with-the-updates-delivering-72-pages-of-patch-notes,1567059/
- [S11] Millennia: https://pcgamer.com/games/strategy/millennia-review ; https://www.pcgamesn.com/millennia/final-update ; https://mein-mmo.de/en/a-strategy-game-was-supposed-to-be-the-alternative-to-civilization-but-now-the-developers-are-giving-up-the-game-after-18-months,1530582
- [S12] Field of Glory: Empires: https://store.steampowered.com/app/1011390/Field_of_Glory_Empires/ ; https://www51.slitherine.com/news/field-of-glory-empires-dev-diary-6-culture-and-decadence18-03-19 ; https://www.gamewatcher.com/field-of-glory-empires/review ; https://www.gog.com/en/game/field_of_glory_empires
- [S14] Hexarchy: https://store.steampowered.com/app/1356810/Hexarchy ; https://www.notebookcheck.net/Deck-building-meets-Civilization-innovative-4X-strategy-for-less-than-2-on-Steam-for-the-first-time.1187792.0.html
- [S16] Store pages for tags and prices: Old World, EU5, Field of Glory: Empires (above) and Ozymandias: https://store.steampowered.com/app/1768280/Ozymandias_Bronze_Age_Empire_Sim/

Market
- [S17] Demo advice: https://gmtk.substack.com/p/how-to-make-a-great-steam-next-fest ; https://unity.com/es/blog/steam-next-fest-developer-tips-unity
- [S20] Quantic Foundry, strategy motivation decline: https://quanticfoundry.com/?p=4830 ; https://pushsquare.com/news/2024/05/bombshell-report-finds-players-becoming-less-interested-in-deep-strategy-games
- [S21] GameDiscoverCo genre revenue shares: https://newsletter.gamediscover.co/p/which-genres-have-ruled-steam-a-new
- [S22] Chris Zukowski (How To Market A Game) data: https://howtomarketagame.com/salesSurvey/ ; https://wnhub.io/news/stores-and-publishing/item-17662 ; https://www.steampageanalyzer.com/blog/how-to-get-steam-wishlists
- [S23] Store page advice: https://howtomarketagame.com/?p=896 ; https://www.gamedeveloper.com/business/how-to-get-the-most-out-of-your-steam-page

Hexa docs
- [H1] `docs/reports/economy-fun-test.md`
- [H2] `docs/reports/trade-fun-test.md`
- [H3] `docs/design/stop-steamrolling.md`
- [H4] `docs/reports/playtest-2026-11-11.md`
- [H5] `docs/design/battle.md`
- [H6] `docs/design/war-goals-and-peace.md`
- [H7] `docs/design/crown-projects.md`
