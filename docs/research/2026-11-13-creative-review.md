# Creative review: the fun principles (v1) and "What makes strategy fun"

Date: 2026-11-13. Reviewer: creative director. Reviews `fun-principles.md` (v1) and
`2026-11-13-what-makes-strategy-fun.md` (section 6, ten proposals). Nothing here is approved; the owner decides.

Context used: the release order in `docs/roadmap/roadmap.md` ("Next up": v0.2.0 battle slice 1, then slices 2
and 3, then war goals and peace, the trade and economy fixes, Crown projects and reactive prices), the battle build
spec (`docs/design/battle-slice1-build-spec.md`), the war goals, stop-steamrolling, Crown projects, reactive prices,
Chronicles and achievements designs, and the owner's decisions of 2026-11-13 in each.

## Verdict in one paragraph

A strong first study. The evidence is honest, the market read is sensible, and most proposals point at fixes that
are already drafted, which is the right instinct. The principles are a usable checklist with small edits. Of the ten
proposals: six approved (two with changes), three approved with changes for later releases, and one part rejected
(the price revolution as a treasury tax). Only two small things may go into v0.2.0: a naming rule for battles and an
odds card before an attack. Everything else waits its turn.

## 1. The principles

The list is the right shape: each line has a test and a source, and "must not make a line worse without saying why"
is the right rule. Fifteen is at the upper edge of what a reviewer can apply honestly to every design. My edits keep
the count at 16 by merging two lines and adding two that are missing.

### Missing

- **A. History told honestly (new, required).** The study never mentions the slave trade, colonisation or the
  tribal nations, yet three proposals touch them (aims "Found three colonies", the Portugal demo, the West African
  coast). This is a studio rule already (achievements decision 5, Chronicles decision 10). Proposed text:
  "**History told honestly.** The slave trade, colonisation and the tribal nations are never glorified, never a
  reward on their own, and always carry a cost the player sees. Test: no goal, score line, achievement or aim
  rewards the slave trade, raids on tribal nations or taking their land; where the game touches them, the text
  names what happened to the people involved." This should be a hard line, not one a design may trade away.
- **B. More than one way to play well (new).** Meier's "personal style" and the autonomy need are in the study
  (1.1, 1.3) but not in the list. Principle 2 checks single options, not whole strategies. Proposed text:
  "**More than one way to play well.** Test: in a seeded full run, a trader, a conqueror and a coloniser play (the
  AI personalities or scripted players) each finish in the top three of the ranking on at least one seed." This is
  also what keeps the score and the aims honest once winning is decided.

### Merge

- **11 and 12 into one: "Readable and light to run."** Both measure the cost of the interface. Test: one hover
  answers "where does my money come from?" and "who is winning this battle?", and a 1600 save's full season of
  management takes no more clicks than a 1490 one (or has a bulk action with an override).

### Tests too vague to apply

- **1 (a real decision every few seasons):** "a decision with no obvious answer" cannot be counted by a script.
  Make it an audit: for each of 1490, 1560 and 1630, list the decision types open to a mid-sized country (build,
  invest, trade order, project, war, aim, research) and show for each that it is affordable and not dominated. The
  playtest log counts the rest.
- **8 (setbacks are stories):** define "a way back": within 10 seasons of a lost war, revolt or bankruptcy, income
  is back to 80% of before, or the country can field half its old army. And "no single event ends a run" needs a
  scripted check (a lost war at full war score does not kill a mid-sized country).
- **12 (clicks):** there is no click counter. The test needs one (a count in the playtest build or the monkey
  harness), or it cannot be applied. Until then, use the merged test above.
- **11:** say who answers: "a new player in a playtest", not the designer.
- **How to use it:** add one line: "A design names the two or three principles it is *for*; the rest are checked
  only for harm." Otherwise every design claims every principle.

Everything else is fine as written. Principle 6's "a brake that reads as a bare tax fails" is the best line in the
list; I apply it below.

## 2. The proposals

Order of releases used below: **v0.2.0** (battle slice 1, being built) -> slices 2 and 3 -> **war goals and peace**
-> **trade and economy fixes** (T1, T2, T5, E2 to E5; T1/T2/T5/E5 already sit on a branch) -> **Crown projects and
reactive prices** -> **brakes** -> **Phase 5** (victory, score, end screen) -> **Phase 6** (Steam).

### 1. Ship the approved economy and trade fixes first: APPROVE

- Principles: 2, 3, 5, 13. It fixes a lying card (3) and two dead options (2).
- Fit: already the decided order; this proposal changes nothing. Not in v0.2.0.
- Note for the planning session: T1/T2/T5/E5 are built on a branch. Shipping them as the release straight after
  v0.2.0 (before slices 2 and 3) would put fixes ahead of features, which matches the "fix issues first" rule. That
  is a producer call, not a design question.

### 2. Battles that tell a story: APPROVE WITH CHANGES, inside v0.2.0 (small parts only)

Most of this is already in the spec, so credit where due: the battle panel header is "Battle of X", and the
`battle_ended` log line already names the place, the seasons, the losses, the winner and the retreat (spec 6.2).
What is missing:

- **A naming rule.** The spec never says what X is. Smallest version: the name of the province the hex belongs
  to; at sea or in unowned wild land, the nearest named province within a few hexes, else the terrain or sea name
  ("Battle of the Alps"). The year is added in the log and on the panel ("Battle of Pavia, 1525"). A second battle
  at the same place is "Second Battle of X" (cheap, very period).
- **The name in the event.** Add `name` and `year` to `battle_ended`. This is an additive change to the contract
  with the war goals design, so both docs are edited together. This is what lets the annals (proposal 8) and the
  achievements be built later without touching the battle code again.
- **The odds card before an attack (new UI, keep it small).** On the attack hover: our men against theirs, both
  armies' morale, the ground ("narrow ground: 2 lanes", "level 2 castle"), the general's trait, and one honest
  word from the strength ratio: "favourable", "even", "risky", "hopeless". The bands come from the spec's own
  measured targets (1.5 to 1 odds win at least 85%), and are re-measured in the PR. **No percentage**: a precise
  number that the battle does not keep is the same lie as the old order card (principle 3). Only what the player
  can see counts (fogged reserves are "unknown").
- Principles: 3, 9, 11, 15.
- Guard against scope creep: no battle "story" screen, no after-battle pop-up, no annals in v0.2.0. The odds card
  is the last PR of the release; if it is late, it ships in the first patch and does not hold v0.2.0.

### 3. Aims of the crown: APPROVE WITH CHANGES, after Crown projects, with the Phase 5 victory decision

The most valuable new idea in the study. Principle 10 is the weakest line today and nothing else fixes it.
Principles: 1, 4, 7, 10, 13 (if the AI has them too).

Changes:
- **One goal engine, three users.** Aims, achievements and Chronicles goals all check conditions from events and
  the world. Build one goal checker; do not build three. Keep the roles apart for the player: Chronicles goals are
  fixed by the scenario, achievements live in the profile and never change the rules, aims are chosen in the game
  and give score.
- **Score only in the first version, no lasting bonus.** A lasting bonus for success feeds the snowball (6).
- **More picks than once per era.** Three picks in 170 years is not a decision every few seasons. Pick at the
  start, at each new era, and when an aim is completed or missed (after a short wait).
- **The AI picks aims too**, if aims count toward score, or the ranking is unfair. Show a rival's aim in its
  country panel ("Castile aims to hold Naples by 1510"): that is principle 13 and 6 for free.
- **Sensitive topics.** No aim counts colonies founded, land taken from tribal nations or anything the slave trade
  touches (principle A). Use exploration and charting aims instead ("Round Cape Bojador", "Chart the coast to the
  Gold Coast"), plus war, building, project and peace aims. Colony aims wait for the natives and triangle trade
  designs.
- **Dependencies:** project aims need Crown projects; war aims are best after war goals. Building aims before
  those means writing aims twice.
- **Smallest version:** 12 aims (4 per era, 2 of them national for the larger countries), 3 offered, one active,
  deadline 10 to 20 years, score on success, nothing lost on a miss but the chance, the AI picks by simple weights,
  shown on the start card, the country panel and the Prestige hover.

### 4. Crown projects plus a price revolution: Crown projects APPROVE (already designed); price revolution REJECT as proposed

- Crown projects already have a design waiting for the owner (`docs/design/crown-projects.md`). Nothing to add.
- **The price revolution as a yearly loss on a treasury above 15 seasons of income fails principle 6** in its own
  words: it is a bare tax on the hoard. It also fails 2 (it is not a choice) and adds a second rule for a problem
  the Crown projects design already attacks twice (projects to buy, and the treasury counting for score only up
  to 15 seasons).
- **It contradicts the Crown projects design.** Repeat projects cost more than 15 seasons of income after the
  first two or three (the cost rises x1.3 to x1.5 per repeat), so a player saving for the next one is punished for
  doing exactly what that design asks.
- **History:** the price revolution was real, but it was rising prices and wages over decades, not money vanishing
  from a chest. Spain was hit hardest. If it comes back, model it as a slow rise in costs and goods prices for
  everyone, with an announced event around 1540, inside the reactive prices work, and only if the Crown projects
  measurement shows the hoard still above 15 seasons.
- Principles if reworked that way: 15, 7.

### 5. An AI that plays for goals and makes peace: APPROVE, in the war goals release

- Already in the war goals draft (the AI names a goal, sues for peace, demands, accepts by terms). The proposal is a
  priority call: the AI parts are must-have in that release, not polish. I agree.
- Add an acceptance test from principle 13: in a seeded full run, wars end by terms with land changing hands each
  decade, and the AI asks the player for peace at least once when losing.
- "Uses Crown projects and T2" belongs to those releases, not to war goals.
- Principles: 13, 6, 8.

### 6. A rival for the leader: APPROVE WITH CHANGES, in the brakes release

- The gap it names is real: coalitions trigger on infamy only, so a rich peaceful runaway meets nothing.
  Historically right too (the League of Cambrai against rich Venice).
- **The cause must be readable** (principle 6): "France names you its rival: you lead the ranking by 40%", shown on
  the map and in the country panel, with the margin before it happens (a warning, as coalitions get at 60%).
- **Two tiers**, so the brake fits the behaviour: wealth draws rivals (a cheap war goal against you, and prestige
  for beating them); aggression draws coalitions (infamy, as decided). A rival is not a coalition.
- **Two-way:** the player may name one rival too, and beating a rival in a war gives prestige. That turns a brake
  into a goal and a story (principles 9, 10).
- It must hit an AI runaway (France) exactly as it hits the player.
- Smallest version: the leader by a set margin is named rival by up to two of its largest neighbours; the
  "Contain the aggressor" slot the war goals design reserves gets a sibling, "Contain the rival".
- Principles: 6, 8, 13.

### 7. The first five seasons: APPROVE WITH CHANGES, with the trade fixes release

- T5 (the merchant nudge) is approved and on the branch; the start card is the new part.
- Smallest start card: who you are, how the game ends today (the 1650 ranking, honestly, until Phase 5 decides),
  three first steps as clickable pointers (a trade order, a build, research). Add the first aim when aims exist.
- Principle 14's "seen a threat" should not be met by scripting a war. The start card names the nearest threat
  instead ("Castile: army twice yours, on your border").
- Not in v0.2.0.
- Principles: 14, 10, 11.

### 8. The chronicle of your game: APPROVE WITH CHANGES, Phase 5

- **Rename it.** "Chronicles" is the owner-approved name of the scenario mode. Call this "Annals" (or "History of
  the reign").
- The data cannot come from the bus: the bus is never saved and its history is bounded. The annals need a small,
  bounded, saved list on the world, filled from events. That is a design point for the technical director.
- Smallest version: an Annals tab in the ledger, one line per named battle, war and peace, new era and aim, with
  a place link. Border maps per era come later.
- In v0.2.0 the only prerequisite is the battle name and year in `battle_ended` (proposal 2).
- Principles: 9, 10.

### 9. Late-game bulk actions: REWORK, later

- The principle is right; the examples are not ready. "Invest best here" across a region risks set-and-forget
  (it removes the decision principle 1 wants). "Garrison restless regions" needs unrest, which does not exist yet.
  "Re-pick best" is already approved (T2).
- First measure clicks per season in a 1600 save (the counter principle 12 needs), then design bulk actions for
  the actions that actually pile up, each with a preview.
- Principles: 12 (and must not break 1).

### 10. The demo is a Chronicle: APPROVE IN PRINCIPLE, Phase 6, the scenario choice open

- A short arc with a grade is the right demo shape.
- **The Portugal Chronicle as the demo needs care.** The demo is the public face of the game, and Portugal down
  the West African coast is where the Atlantic slave trade began. The owner decided the scenario's blurb says
  plainly that the slave trade is not modelled; for a demo that may read as a cleaned-up colonial adventure.
  Either the triangle trade design is settled and reflected before the demo, or the demo uses a different
  Chronicle (for example a war scenario that shows off the battle system, the game's newest strength).
- Principles: 14, 15, A.

### Summary table

| # | Proposal | Verdict | Release | Principles |
|---|---|---|---|---|
| 1 | Approved fixes first | Approve | after v0.2.0 (as decided) | 2, 3, 5, 13 |
| 2 | Battles that tell a story | Approve with changes | **v0.2.0**: naming rule, name in event, odds card (last PR) | 3, 9, 11, 15 |
| 3 | Aims of the crown | Approve with changes | after Crown projects, with Phase 5 victory | 1, 4, 7, 10, 13 |
| 4 | Crown projects / price revolution | Approve / Reject as a treasury tax | Crown projects release / parked | 5, 1 / fails 2, 6 |
| 5 | AI plays for goals, makes peace | Approve | war goals release | 13, 6, 8 |
| 6 | A rival for the leader | Approve with changes | brakes release | 6, 8, 13 |
| 7 | The first five seasons | Approve with changes | trade fixes release | 14, 10, 11 |
| 8 | The chronicle (rename: Annals) | Approve with changes | Phase 5 | 9, 10 |
| 9 | Late-game bulk actions | Rework | after a click measurement | 12 |
| 10 | The demo is a Chronicle | Approve in principle | Phase 6 | 14, 15, A |

## 3. Decisions for the owner

1. **Battles in v0.2.0.** (a) The naming rule with the year and the name in `battle_ended`, plus the odds card as
   the last PR, which may slip to a patch; (b) names only; (c) neither. **Recommend (a).**
2. **Aims of the crown.** (a) Yes, and aims add to the score that decides the 1650 ranking; (b) yes, but as
   flavour with no score; (c) no. **Recommend (a)**, built after Crown projects and decided together with the
   victory question, with the AI picking aims too.
3. **The price revolution.** (a) Not as a treasury tax; park it, and revisit as rising prices and costs inside
   reactive prices if the Crown projects run still shows a hoard; (b) add it to Crown projects as proposed.
   **Recommend (a).**
4. **Rivals.** (a) Any runaway leader draws rivals (wealth: rivals; aggression: coalitions), with the cause shown
   before it happens, and the player may name a rival too; (b) only aggressors (infamy, as today's draft).
   **Recommend (a).**
5. **Early Access price and the demo.** (a) Decide neither now; revisit when the store page is planned, with about
   $20 to $25 as the working figure and the demo scenario chosen in the light of the triangle trade design;
   (b) fix the price and the Portugal demo now. **Recommend (a).**
6. **The principles.** Adopt v2 with the edits in section 1 (add "History told honestly" as a hard line and "More
   than one way to play well", merge 11 and 12, sharpen the tests of 1, 8, 11 and 12). The market researcher
   keeps the list. **Recommend yes.**

## 4. Risks

- The odds card can lie if the word bands are not re-measured after the battle numbers are tuned. It needs its own
  test against the spec's measured odds.
- Adding `name` and `year` to `battle_ended` touches a contract with the war goals design; both docs must change in
  the same PR.
- Aims depend on the unanswered victory question. Building aims before the owner decides how to win risks doing
  them twice.
- None of the proposals was tested in the engine; the principles' numbers (15 seasons, 10 seasons back) are
  starting points.
