# Tech tree review: does the approved tree fit the new systems?

Status: draft for the owner, 2026-11-24. Planning only: nothing here is built, no code was run, and every pace number below is
a paper estimate from the research rates of the M11 spec (section 4.7). The research soak will measure them.

Sources read: the approved tree (`tech-tree.md`, `tech-tree-build-spec.md`, the approved mockup `images/14_tech_tree_c.png`),
the M11 build spec (`../architecture/m11-build-spec.md`, sections 4.2 to 4.9), and the owner's new decisions in
`economy-rethink.md`, `moves-in-the-month.md` and `two-fog-levels.md`.

A word on the count. The brief says "51 techs". That is 37 tree techs plus 13 national techs plus the one default national
tech (Local levies). The tree you approved is the 37.

## 1. The tree as it stands

Costs are research points (the M11 numbers). A mid-sized country makes 2 to 7 points a season (8 to 30 a year), so a tech of
80 points takes from 3 to 10 years. "Needs" in italics is a prerequisite from another branch (a dashed line on the screen).
Every country also knows its own national tech from the first day (section 4).

Eras: **I Age of Pikes** (from 1480), **II Age of Arquebus** (from 1520, once the country knows 4 era I techs),
**III Age of Musket** (from 1575, once it knows 4 era II techs). The era brings the troop kinds; techs change numbers only.

### 1.1 Military (11 techs)

| Era | Tech | What it does in plain words | Cost | Needs |
|---|---|---|---|---|
| I | Drill yards | Companies learn faster: +1 experience from every battle | 80 | none |
| I | Supply trains | Armies stay fed 2 points further from a depot | 80 | none |
| I | Siege craft | Artillery gives +1 siege point a season | 80 | none |
| II | Tercio | Infantry holds better against cavalry (x1.25 becomes x1.5) | 180 | Drill yards |
| II | Standing army | One more company on a hex (8 becomes 9) | 200 | none |
| II | Bronze guns | Artillery +1 attack, but each battery needs 1 more copper | 200 | Siege craft, *Corned powder* |
| II | Trace italienne | Fortresses defend better (+35 % a level, not +25 %) | 200 | none |
| III | Volley fire | Missile companies +1 attack and fire 15 more a day | 380 | Tercio |
| III | Star forts | Garrisons +2 defence; a siege needs 1 more point per fortress level | 400 | Trace italienne |
| III | Magazines | Supply reaches 2 more; armies eat a quarter less | 380 | Supply trains |
| III | Military revolution | One more company on a hex; a general adds 1 more | 400 | Standing army |

### 1.2 Trade & Industry (10 techs)

| Era | Tech | What it does in plain words | Cost | Needs |
|---|---|---|---|---|
| I | Guilds | Every works costs a tenth fewer ducats | 80 | none |
| I | Double-entry books | +1 merchant | 80 | none |
| I | Crop rotation | Wheat districts +10 % | 70 | none |
| II | Ropewalk | Hemp districts +25 % | 170 | Guilds |
| II | Banking | Taxes on towns +20 % | 200 | Double-entry books |
| II | Corned powder | Artillery fires 15 more a day | 170 | Guilds |
| II | Glass & leather | Grazing districts +20 % | 180 | none |
| III | Joint-stock company | +2 merchants | 400 | Banking, *Town charters* |
| III | Bourse | Market towns reach 2 points further; remote land sells at 80 % | 380 | Banking |
| III | Coffee houses | Towns' research +40 % (the town part of it) | 360 | Glass & leather, *Universities* |

### 1.3 Navigation (9 techs)

The land game has no ships yet, so Navigation was re-fitted to the coast, the merchants' ways and the maps.

| Era | Tech | What it does in plain words | Cost | Needs |
|---|---|---|---|---|
| I | Portolan charts | Port dues +20 % | 70 | none |
| I | Carrack | Harbours and ports catch 25 % more fish | 80 | none |
| I | Astrolabe | Your land sees 1 hex further | 80 | none |
| II | Ocean pilots | Your merchants pay a fifth less transport | 170 | Portolan charts, Astrolabe |
| II | Plantations | Silk, dyes and olives +20 % | 180 | none |
| II | Cartography | You know every country within 4 hexes of your land | 160 | none |
| III | Galleon | Port dues +25 % more; up to 7 merchants | 380 | Carrack, *Ropewalk* |
| III | Mercator charts | Armies see 1 hex further | 360 | Cartography |
| III | Overseas factories | Merchants carry 4 more loads (12 to 16) | 380 | Ocean pilots |

### 1.4 Statecraft (7 techs)

| Era | Tech | What it does in plain words | Cost | Needs |
|---|---|---|---|---|
| I | Tax rolls | Taxes on goods +2 points at every level | 70 | none |
| I | Printing press | Research +15 % | 90 | none |
| II | Universities | Cities +1 research a season, walled towns +0.5 | 200 | Printing press |
| II | Town charters | Towns hold a tenth more people | 170 | none |
| II | Royal bureaucracy | High taxes slow growth half as much; your reach +2 steps | 180 | Tax rolls |
| III | Absolutism | Levies +25 %; High taxes +10 points; war goals +2 districts | 380 | Royal bureaucracy |
| III | Mercantilism | Tolls +2 points at every level | 360 | none |

Totals: era I 11 techs (880 points), era II 14 (2,590), era III 12 (4,560). Statecraft is the thinnest branch (7); Military
is the fullest (11).

## 2. What the owner's new systems need from the tree

Short answer: **the tree fits most of it, but three systems have no tech at all (scouting, arms and refits, market buying),
two techs now have a job the old text does not describe (Guilds and Crop rotation), and one tech has lost its meaning
(Cartography).** Details, system by system.

### 2.1 Industries and their third stage (economy rethink, 3.6)

The rethink says: before M11 an industry opens in a set year (armourer 1485, weaver 1490, bakery 1495, stage 3 in 1520);
M11 replaces the year with techs: **Guilds opens weaver and armourer, Crop rotation opens bakery, a Guilds follow-up opens
stage 3.**

| Question | Answer |
|---|---|
| Guilds and Crop rotation | Already in the tree and in era I: they just gain the unlock. Crop rotation keeps its +10 % wheat. Guilds also keeps "works cost a tenth less", which makes the cheapest early tech also the strongest; propose cutting that to 5 % (question 3) |
| The stage 3 follow-up | **A gap.** No era II Trade tech fits: Ropewalk, Corned powder and Glass & leather are the later industries (rope, powder, glass, tannery), which the rethink keeps out of M9.5. Propose one new tech: **Master craftsmen** |
| Later industries | Ropewalk, Corned powder, Glass & leather keep today's numbers until their industries are designed; then each gets an unlock row and no new node |
| Start order | Every country starts on its cheapest tech, which is Crop rotation (70). So the bakery opens first, not last as the year placeholder had it. Fine (food first), but the owner should know |
| The armourer and the AI | A country without Guilds cannot build an armourer, so it buys arms at the premium. A warlike AI that researches by branch weight (Trade is its lowest) may be slow to Guilds. Suggest an AI score bonus for Guilds when the seat has no armourer and plans a war |

**Conflict to settle.** M11 decision D8 says "no unlock switches; unlocks are eras and numbers". The rethink needs techs that
open industries. The clean way inside D8's spirit: no on/off flag, but whole-number rows (an "industry open" count that is 0
or 1, a "stage maximum" that goes 2 to 3). Needs three new keys (section 2.9).

### 2.2 Arms and refits (3.7, N7 to N9)

Arms are needed to raise a company, bought at a premium from the market (placeholder 1.5 times base) when the country has
none; refit and upgrade need arms too.

- The tree has **no tech that touches arms**. The only handle today is the existing key for goods in a company's cost
  (`branch.<branch>.cost_goods.<good>`), which already works for arms.
- Refits: the rule is "half the new kind's cost" (a number in data). No tech or card changes it. Era changes make refits a
  big spending moment (every company becomes the next era's kind), so a small relief is welcome.
- Proposal: **Standing army** (a standing force is kept equipped) also makes refits cheaper (half becomes 40 %). The arms
  premium gets relief from two idea cards (section 4). No new tech node.

### 2.3 Scouting and exploration (two fog levels, moves in the month)

The owner's decisions: a country starts knowing what it historically knew (all Europe for a European country), deep fog is
the world beyond; an army may be ordered into deep fog with a movement penalty (rule to come); scouts discover land more
easily.

- **Cartography is now almost dead.** It says "you know every country within 4 hexes of your land". But in Europe every
  country is already known at the start, so on the north Italy map the effect does nothing. It only has meaning for a map
  with a world beyond Europe.
- **Astrolabe** (land sees 1 hex further) widens the discovery ring around land you own. That helps a frontier, not
  exploring. **Mercator** (armies see 1 further, era III) is the only tech that helps a walking army, and it is the last era.
- **Gap:** nothing makes scouts better in the first eras, and nothing softens the deep-fog penalty. A "scout" today is any
  army, best a rider (sight 2).
- Proposal: **a new era I Navigation tech, Pathfinders** (riders see 1 hex further); **rework Cartography** into "marching
  into undiscovered land costs less" (keeping the old know-range row, which still matters beyond Europe); Mercator stays.
  The deep-fog penalty is not yet fixed by the owner, so its numbers wait.

### 2.4 Moves in the month

The movement allowance (12 for infantry, 16 for riders, 8 for guns) now matters more, because the player spends it move by
move and the walk stops when an enemy comes into sight. The tree does not touch it, on purpose: M11 decision says step costs
are never modified. Supply reach and sight are the levers the tree has. Proposal: leave the allowance alone in this version
(question 6). One point of 12 changes nothing with farmland steps costing 2; two points change everything.

### 2.5 Market buying

Workshops buy missing input at 1.2 times base; arms at 1.5. Today no tech or card touches either price.
- Proposal: **Bourse** (era III, market tech) also makes bought input cheaper (1.2 becomes 1.1). One idea card, Fuggers'
  credit, cuts bought inputs and arms by a fifth (section 4). Two new keys.

### 2.6 Slots in settlements

Slots follow the settlement level (village 1, town 2, walled town 3, city 4). Town charters ("towns hold a tenth more
people") already helps indirectly (bigger towns reach the next level). Recommendation: **no tech adds slots in the first
version** (question 9); a slot is a strong thing and the soak has not seen industries yet.

### 2.7 Population growth and prosperity

Growth will be `500 + 350 x surplus + 350 x prosperity`. What the tree has: Crop rotation (more wheat, so more surplus),
Royal bureaucracy (high tax hurts growth less), Town charters (more room), and one idea (Confraternities, growth a fifth
faster). **Gap:** no tech helps growth directly, and Statecraft has only 2 era I techs. Proposal: **Almshouses**
(Statecraft, era I): people grow a tenth faster, using the existing growth key. More people also means more research (the
towns' part), so it feeds itself, mildly.

### 2.8 What the proposals add up to

Three new techs, four changed (Guilds, Cartography, Standing army, Bourse), one rebalanced (Tax rolls, optional):

| New tech | Branch, era | Cost | Needs | Plain effect | Rows |
|---|---|---|---|---|---|
| Pathfinders | Navigation I | 80 | none | Riders see 1 hex further | new key (riders' sight) |
| Almshouses | Statecraft I | 80 | none | People grow a tenth faster | existing growth key, scale 100 |
| Master craftsmen | Trade II | 180 | Guilds | Workshops can be built to the third stage | new key (stage maximum +1) |

| Changed tech | Now | Proposed |
|---|---|---|
| Guilds | works cost -10 % | opens weaver and armourer; works cost -5 % (existing cost key, scale -50) |
| Crop rotation | wheat +10 % | also opens the bakery |
| Cartography (needs Pathfinders added) | know range +3 | know range +3 and marching into undiscovered land costs less (number waits) |
| Standing army | stack +1 | also refits cost 40 %, not half |
| Bourse | reach +2, remote 80 % | also bought input 10 points cheaper |
| Tax rolls (optional) | goods tax +2 points | +3 or +4: at +2 it is about 3 % of goods tax, the weakest effect in the tree at the cheapest price; the soak decides |

After the three additions: **40 tree techs** (Military 11, Trade 11, Navigation 10, Statecraft 8), plus the 14 nationals =
54. Era I has 13 techs (1,040 points), era II 15 (2,770), era III 12 (4,560). The gate arithmetic does not change (4 of
the era). If the owner prefers to stay at 51, the fallback is to fold them in: Pathfinders into Astrolabe, Almshouses into
Town charters, Master craftsmen into Ropewalk. Each loses something (Astrolabe stops being the cheap land-sight tech; a
unlock of stage 3 would then arrive with a hemp tech).

Screen: with Master craftsmen the Trade era II cell holds 5 techs; the ported layout has 2 rows per branch cell. A third row
is a small layout change (the Trade branch grows taller). Era I cells with their national tech still fit in 4: Navigation 4
(Portolan, Carrack, Astrolabe, Pathfinders; no country has a Navigation national tech), Statecraft 3 + 1, Military 3 + 1,
Trade 3 + 1.

### 2.9 Modifier keys: existing, and what is new

All effects of the proposals map to the 55 keys of spec 4.2 except these. A new key needs a reader in the rules, bounds and
a probe test (spec done-when 1b), so the number of tests grows with it.

| New key (plain name) | Used by | Needed for | Needed now? |
|---|---|---|---|
| Industry open (per industry, whole number 0/1) | Guilds, Crop rotation | industries open by tech | yes, with M9.5/M11 |
| Industry stage maximum (add; base 2) | Master craftsmen | stage 3 | yes |
| Industry yield (add, per industry, permille) | Armourers' charter card, Venice, Milan (section 4) | the rethink already names it | yes (it is in the rethink) |
| Market buy price (add, permille; base 1200) | Bourse, Fuggers' credit | cheaper bought input | with market buying |
| Arms buy price (add, permille; base 1500) | Fuggers' credit, Arsenal of Venice | cheaper bought arms | with arms |
| Refit cost (add, permille; base 500) | Standing army | refits | with refit |
| Marching cost into undiscovered land (add) | Cartography, Scouts' guild | the deep-fog penalty | when the owner fixes the rule |
| Riders' sight (per branch sight, add) | Pathfinders | scouts | yes (or use the existing all-armies sight key) |
| Army allowance (add) | none proposed | moves | not proposed |
| Settlement slots (add at level) | none proposed | slots | not proposed |

Existing keys used: growth (9), cost of works (33), wheat output (28), stack limit (3), toll and market (45, 43, 44), the
company goods (26), sight (4, 5, 27), merchants (39 to 41), research (34 to 38). So **six to seven new keys are needed now,
two or three more later**: the registry goes from 55 to about 62-65, and the "one probe per key" test grows with it.

## 3. Balance sanity

Method: points a year = 4 x the research rate of the spec's table (section 4.7), growing about 25 % by 1520. A tech costs 70
to 90 in era I, 160 to 200 in II, 360 to 400 in III; partners who already know it cut up to 30 % (diffusion).

### 3.1 Pace per country (paper estimate)

| Country | Rate 1480 (a season / a year) | Points by 1520 | Era I (880 points, before diffusion) | Years per era I tech | Years per era II tech (180, rate x1.25) | Years per era III tech (380, rate x1.5) |
|---|---|---|---|---|---|---|
| Milan | 7.5 / 30 | about 1,340 | done by 1505 to 1510, then idle | 2.7 | 4.8 | 8.5 |
| Venice | 5.5 / 22 | about 980 | done by 1520 | 3.6 | 6.5 | 11.5 |
| Savoy | 4.6 / 18 | about 820 | done about 1520 | 4.4 | 7.8 | 14 |
| Tuscany | 3.4 / 13.5 | about 600 | 70 % by 1520 | 5.9 | 10.5 | 19 |
| Switzerland | 3.1 / 12.4 | about 555 | 63 % by 1520 | 6.5 | 11.5 | 20 |
| Genoa, Ferrara | 2.45 / 9.8 | about 440 (680 funded yearly) | 50 to 75 % | 8 (5 funded) | 14.5 (9 funded) | 26 (16 funded) |
| Papal States | 2.3 / 9.3 | about 417 | 47 % | 8.6 | 15.5 | 27 |
| Austria, Mantua | 2.0 and 1.75 | 310 to 370 | 35 to 42 % | 10 to 11 | 18 to 20 | 33 to 36 |
| France, Siena, Lucca | 1.5 to 1.6 | 280 to 290 | the cheapest 4 only | 13 | 23 | 41 |

Reading it:
- **The spec's pace claim holds in the middle.** "A tech every 3 to 10 years" fits Milan to Genoa funded; "about 70 % of
  the tree by 1650" fits Milan and Venice and Savoy, not the bottom five (the spec itself says 15 to 20 techs for Siena and
  Lucca).
- **The era II gate (year 1520 plus 4 techs).** The 4 cheapest era I techs cost 70 + 70 + 70 + 80 = 290 points. The poorest
  countries produce about 280 points in 40 years: they pass the gate in 1527 only if they study the 4 cheapest and nothing
  else, so their first 40 years of research have no choice in them. For them funding and diffusion are the real catch-up.
  This matches the spec (1527) but it is worth knowing: a poor country that researches Printing press (90) first misses the
  gate.
- **Finding: the leaders run out of work.** Milan makes about 1,340 points by 1520; era I holds 880 (less with diffusion).
  Milan finishes the whole era around 1505 to 1510, and until 1520 its points are lost (only 4 seasons' worth are kept).
  That is 10 to 15 dead years for the biggest country and perhaps a few for Venice. The year gate does its job (it holds the
  leaders), but the wasted research feels bad and teaches the player that research is capped. The additions in 2.8 add 160
  points to era I and only narrow it. The owner decides how to treat it (question 4); the soak should measure it first.
- **Era II to III is tighter for the leaders**: Milan makes about 1,900 points between 1527 and 1575 against 2,590 (2,770
  with the addition), so it learns most of era II and nothing idles. Good.
- **Funding.** 80 ducats buys 6 points once a year. For Genoa (income about 458 a year, 9.8 points a year) that is a fifth
  of its income for a 60 % faster tech pace: a strong deal, correctly a catch-up tool. For Milan it is +20 %: a mild
  choice. With the new systems the same ducats buy workshops (a weaver slot pays back in about 3 years) and arms, so funding
  will compete honestly. Keep.

### 3.2 Is each branch worth taking?

| Branch | Verdict |
|---|---|
| Military | Worth it for any country at war or threatened; the AI weights it double then. Almost everything is conditional on fighting (Drill yards, Tercio, the fort techs) so a peaceful country can skip it. Watch: **Trace italienne, Star forts and a Defender general stack into very hard fortresses** (castle defence, garrison defence and siege need all rise); fine for stopping steamrolling, but test that no war can end. **Standing army and Military revolution** raise the stack from 8 to 10 (+2 with a general): strong for attackers too |
| Trade & Industry | Strongest for the economy, and now the gateway to industries. Guilds (cheap, opens two workshops, cuts works cost) is the best era I tech; with the unlock it is a must-take. Crop rotation is weak as a number (+10 % wheat) but cheap and now opens the bakery. Ropewalk, Glass & leather and Corned powder are conditional: they only pay if the country has hemp, grazing or artillery, until their industries come. Banking (+20 % town tax) is great for town-heavy Milan and weak for Genoa |
| Navigation | **Uneven by geography.** Port dues and fish matter to Genoa and Venice and are nearly nothing to inland Milan, Savoy, Mantua, Switzerland, Austria (Genoa's port dues change by about 6 ducats for a +20 % tech). For those, only Astrolabe, Ocean pilots, Cartography, Mercator and Overseas factories count. The proposal adds Pathfinders (useful to anyone) and a deep-fog Cartography. Acceptable if the owner accepts a coastal bonus branch (question 10) |
| Statecraft | The best value per point: Printing press (+15 % research, cheap, compounding), Universities, Royal bureaucracy and Absolutism are broad. Thin (7 techs), so it runs out first; Almshouses helps. **Tax rolls is the weak one** (see 2.8). Mercantilism (+2 toll points) is small unless the country has a busy market |

### 3.3 Dead, weak and strong

- **Dead on this map:** Cartography (as written, see 2.3). **Galleon's** ship half and the colony halves of the old design are
  already gone; what remains is port dues and a merchant, fine.
- **Weak:** Tax rolls (+2), Crop rotation (+10 % wheat only), Mercantilism, Overseas factories (+4 loads, one of three
  capacity sources), Drill yards for a peaceful country, Carrack for inland countries.
- **Strong, watch in the soak:** Guilds (cost -10 % on every works), Printing press (+15 % compounding), Banking in town
  countries, Standing army, Military revolution, and **trade stacking**: Double-entry (+1), Joint-stock (+2), Merchant houses
  (+1), Genoese factors (+1) can give +5 merchants in a game, capped by the market-town count and the key's bound.
- **Cost curve:** monotone and clean (the dearest of an era is under the cheapest of the next). Era I spans 70 to 90 for very
  different values (Guilds against Crop rotation cost almost the same). Cheap fixes: Guilds 80 to 90, after its discount is
  cut it can stay at 80.
- **Era gate is any-branch.** Era I has branches of 3, 3, 3 and 2 techs, so 4 techs always spans two branches; era II (4 of
  14) can be reached inside one branch (Military has 4). Fine: nobody is forced into a branch.

## 4. Idea cards and national techs

### 4.1 Duplicates and overlaps (the current text)

| Overlap | Where | Change |
|---|---|---|
| **Venice gets tolls three times** | Banco di Rialto (tolls +25 %), the Arsenal of Venice card (tolls +15 %), Mercantilism (+2 points) | Rework the Arsenal card: arms bought at 1.2 not 1.5 (it is an arsenal) |
| Navigators' guild = Astrolabe | both "land sees 1 further" | Rework into **Scouts' guild**: riders +1 sight and a cheaper march into undiscovered land (when the rule is fixed) |
| Fuggers' credit = Casa di San Giorgio | both "funding a quarter more" (Genoa would get a card equal to its national tech) | Rework Fuggers' credit: bought input and arms 20 points cheaper |
| Pike levies = Local levies and Absolutism | all "levies +10 %" or more; the weakest card | Replace with **Armourers' charter**: armourers make 10 % more arms |
| Three town-tax rows | Civic statutes (+10 %), Indulgences (+10 %), Monte dei Paschi (+5 %) plus Banking (+20 %) | Acceptable (different countries); keep |
| Humanism, Platonic Academy, Printing press | research +10 %, +15 %, +15 %: a Tuscan research game can reach +40 % | Acceptable; watch Tuscany in the soak |
| Milanese armour | cavalry +1 defence, nothing about Milan's real trade | Add armourer output +10 %: armour was Milan's industry |
| Gonzaga captains | "generals cost half": a one-off saving of 50 ducats, the weakest national tech | Replace later by something that scales (the small countries have the lowest research and need the strongest nationals) |

The card changes above are replacements, not additions: the general deck stays at 16 and the nationals at 13. Total new keys
they need are already counted in 2.9.

### 4.2 Gaps in the deck for the new systems

The idea deck should have cards for the new economy so a player can lean into it: industry yield (Armourers' charter, one
more: **Weavers' guild**, cloth yield +10 %, by replacing Merchant houses which duplicates Double-entry and Genoese
factors), market buying (Fuggers' credit), scouting (Scouts' guild), arms (Venice's Arsenal). That is four cards touching
the new systems out of 29.

### 4.3 Era step and how many ideas

Two idea picks per game (era II and era III) stay. The offer is the nation's card plus two general cards weighted to the
top branch; with the deck changes the weighting now leans toward the new systems for a Trade-heavy player. No change to the
rule. One note: an offer left open lapses to its first card at the next era, which is the nation's own card; fine.

### 4.4 The national tech starting slot

The national tech is known at the start and counts for nothing toward the era gate (spec 4.4). The Genoa national tech
(funding +25 %) gives Genoa about +1.5 points a year: the weakest of the nationals next to Gonzaga's. The strong ones are
Platonic Academy (Tuscany +15 % research), Habsburg marriages (Austria: discounts up to half) and Banco di Rialto (Venice:
Banking for free, 200 points). Small countries have the least research, so the order of national strength is the
opposite of what balance wants. Question 8 asks the owner whether to lift Genoa's, Siena's, Lucca's and Mantua's.

## 5. What Kioba (issue 447b, data entry) can start on now

I read 447b as: typing the tech, idea and era data files of spec 4.3 to 4.6 into the data folder (the file format and the
registry of keys are fixed by the spec). I could not find the issue text in the docs, so please correct me if it is
something else.

| Can start now (no owner answer needed) | Waits for an answer |
|---|---|
| The 3 era data files (names, years, gate 4, kinds) | The 3 new techs (questions 1, 2, 5) |
| All 37 tree techs' names, keys, branch, era, cost, prerequisites, flavour lines and icons **except the changed ones** | Guilds, Crop rotation, Cartography, Standing army, Bourse, Tax rolls: they stay as the spec has them until the answers, then get their extra rows |
| The 13 nationals and the default, except Milanese armour and Gonzaga captains | Anything using a new key (2.9): its row cannot validate until the key exists in the registry |
| The 16 general cards except Navigators' guild, Fuggers' credit, Pike levies | Merchant houses (if replaced) and the Arsenal of Venice |
| Existing-key rows: every row whose key is in the 55 | The final deck cost and the deep-fog numbers |
| The text lines and flavour sentences for all of the above | Icons for the 3 new techs (art) |

Tip for Kioba: enter the spec's version of the waiting techs now (it validates), mark them with a comment, and the answers
add rows afterwards; nothing needs retyping. The data for the unit kinds 4 to 11 (the later eras' troops) is independent of
all of this and can go in now.

## 6. Questions for the owner

1. **Add three techs?** Pathfinders (riders see further, Navigation I), Almshouses (people grow a tenth faster, Statecraft I)
   and Master craftsmen (workshops up to stage 3, Trade II): the tree goes from 51 to 54 techs. Alternative: stay at 51 by
   folding them into existing techs (each loses something). *Recommend: add the three.*
2. **Industries opened by tech through whole-number keys.** This overrules M11's "no unlock switches" for one family only
   (industries and their stage). *Recommend: yes; it is the only way to do what the economy rethink asks.*
3. **Guilds: unlock only, or unlock plus the works discount?** Today it cuts every works cost 10 % for 80 points. *Recommend:
   keep it, cut to 5 % (it becomes a must-take either way).*
4. **The leaders run out of things to study before 1520** (Milan about 10 to 15 years; points beyond 4 seasons are lost).
   Options: (a) bank more seasons of points (from 4 to 12, a rush of learning when the era opens); (b) let the leaders study
   next-era techs early at 1.5 times cost; (c) leave it. *Recommend (a), and let the soak measure it first.*
5. **Scouting.** Cartography as written does nothing in Europe; rework it into "cheaper march into undiscovered land" and
   add Pathfinders for riders. Is a "scout" just a rider, or do you want a scout unit later? *Recommend: just riders for
   now; the deep-fog numbers wait for your rule.*
6. **The army's movement allowance.** Should any tech add movement points? *Recommend: no, in this version; supply reach and
   sight are enough levers and one point of 12 means nothing, two means too much.*
7. **Arms and refits relief.** Standing army makes refits 40 % not half; Fuggers' credit and the Arsenal of Venice cheapen
   bought arms; Bourse cheapens bought inputs. Too many places, too few, or right? *Recommend: as proposed, tuned in the
   soak.*
8. **Strengthen the small countries' nationals** (Genoa, Siena, Lucca, Mantua have the weakest start techs and the lowest
   research)? *Recommend: yes, a second pass with the soak numbers, not now.*
9. **Slots.** Should a tech ever add a settlement slot? *Recommend: not in the first version.*
10. **Navigation for inland countries.** Accept that it is mostly a coastal bonus branch, with only a few techs for inland
    countries? Alternative: move one more effect inland (for example Ocean pilots' transport discount applies to all
    merchants, as written; the port dues stay coastal). *Recommend: accept.*

## 7. Risks and what is not done

- No number here is measured: all the pace figures come from the spec's rate table and its cost list. The research soak
  suite (10 games of 440 seasons) is the proof; the owner's answers 3, 4 and 8 should wait for it.
- Each new key adds a reader in the rules, bounds and a probe test, and the registry's "55 keys" is pinned in the M11 tests
  and text; the spec would need updating in one change.
- New techs need icons and a layout row (Trade II).
- Three of the specs (economy rethink, moves, fog) are drafts that the owner has only partly answered; the deep-fog march
  cost and the arms price are placeholders, so the numbers of Cartography, Scouts' guild and the arms relief are too.
- The fog decision changes what "known country" means; if the owner later gives each country a smaller start world than all
  Europe, Cartography's old effect returns to life and the rework should keep it (it does).

---

## Owner's answers, 2026-11-24

1. **Shape:** the tech screen stays a grid by branch (rows) and era (columns), as in the approved picture, drawn in the
   Studiolo kit.
2. **Three new techs (51 becomes 54):** one for faster population growth (the owner's working name "Poor house"), one for the
   third level of industries (working name "Work house"), and a third whose name is still to be decided; with Cartography
   removed and no rider tech, the third is the faster-marching tech (see 6). The names are the owner's working names; the exact
   wording and the effects are settled when the data is entered.
3. **Techs open buildings:** a tech makes a building available to select and build (weaver, armourer, bakery). This
   overrules decision D8 ("no unlock switches") for this one family; the unlock is a whole-number key (0 or 1).
4. **Guilds:** unlock only (weaver and armourer); no works discount. A separate tech improves the industries.
5. **Leaders running out of research before the next age:** the owner will come back to balancing; do nothing now.
6. **Cartography is removed;** there is no rider-sight tech. **One tech gives faster marching** (more movement allowance a
   month); it is balanced against the moves-in-the-month rule when that is built.
7. **Slots:** some techs add an industry slot to a settlement.
8. **Navigation** stays a branch that mainly rewards coastal countries. The principle: not every tech can be taken in one age, so
   players must choose a specialisation.

Not asked, taken as proposed in this review and tuned in the soak: the placement of the arms and refit relief (question 7), and
the stronger national techs for the small countries (question 8). Still open for the data entry: the names of the three new techs.
