# Tech tree v2: a bigger tree you cannot finish (draft for the owner, 2026-11-24)

Status: **draft, planning only.** Nothing here is built. It replaces the tree of `m11-build-spec.md` 4.3 (37 tree techs, Cartography
removed) with **72 tree techs, 6 in every branch and age**, and it keeps the 13 national techs and the default. It folds in the owner's
answers of 2026-11-24 (`tech-tree-review.md`, last section). Sources: that review, `tech-tree.md`, `tech-tree-build-spec.md`,
`m11-build-spec.md` (4.2 to 4.8), `economy-rethink.md`, `moves-in-the-month.md`, `two-fog-levels.md`, `ui-family-audit.md`.
Every number is a starting point for the research soak to tune. Costs are in research points (a season is a quarter of a year; funding is once a
year, so 6 points a year is 1.5 a season).

## 1. The principle, the size and the specialisation maths

**Principle.** In an age nobody can learn everything. A country learns roughly one branch fully plus part of a second (the poorest: about
one branch's worth in all). What a country skips, it can buy through diffusion (partners who know a tech make it up to 30 % cheaper),
through trade, or learn later when it is cheap next to the new age's techs. Specialisation is forced by **points, not by locks**:
no tech excludes another.

**Size.** 4 branches x 3 ages x 6 = **72 tree techs** (was 37). Plus the 13 national techs and the default, which stay as they are.
Per age: 24 techs. Totals (list price, before diffusion):

| Age | Techs | Cost range | Per branch (6 techs) | Age total |
|---|---|---|---|---|
| I, Pikes (1480 to 1520) | 24 | 65 to 90 | 450 | 1,800 |
| II, Arquebus (1520 to 1575) | 24 | 100 to 135 | 700 | 2,800 |
| III, Musket (1575 to 1650) | 24 | 160 to 210 | 1,125 | 4,500 |
| Whole tree | 72 | | | 9,100 |

Each branch has the same total (450, 700, 1,125) in every age, so no branch is cheaper to complete. The dearest of an age is under the
cheapest of the next (90 < 100, 135 < 160), as in the spec.

### 1.1 The rates have to change (this is the key finding)

With the M11 rates (spec 4.7: base 1.5, towns 15 per 1,000 people, 100/250/500 per walled town/city) the rich country makes five times what
the poorest does. The owner's target (rich 60 %, mid 40 to 45 %, poor 25 to 30 % of an age) needs a ratio of about two to one.

| Country (1480 rate, a season) | Points in age I (160 seasons), current rates | Share if the age costs 1,800 |
|---|---|---|
| Milan 7.4 | about 1,340 | 74 % |
| Venice 5.4 | about 980 | 54 % |
| Savoy 4.5 | about 800 | 44 % |
| Genoa 2.4 (3.9 funded) | about 440 (660 funded) | 24 % (37 %) |
| Siena, Lucca 1.5 | about 256 | 14 % |

At 14 % the poor country cannot even open age II (four cheapest techs cost about 270). To hit 60 / 43 / 27 % **I propose new rate data**
(D9 of the spec; all values are data in `ResearchDef`):

| Value | Spec now | Proposed |
|---|---|---|
| `base_milli` (every country) | 1,500 | **3,000** |
| `town_milli` (per 1,000 town people) | 15 | **8** |
| `by_level` town / walled town / city | 100 / 250 / 500 | **50 / 125 / 250** |
| Funding (80 ducats for 6 points a year) | same | same (relatively weaker, which is right: it is a catch-up tool) |

Resulting rate, growing with the towns as in the spec (x1.34 of the variable part by 1520, x1.75 by 1575). Average points a season in each age:

| Country | Class | 1480 rate | Avg I | Avg II | Avg III |
|---|---|---|---|---|---|
| Milan | rich | 6.1 | 6.7 | 7.9 | 9.2 |
| Venice | upper mid | 5.1 | 5.4 | 6.2 | 6.9 |
| Savoy | mid | 4.6 | 4.9 | 5.5 | 6.0 |
| Genoa, Ferrara | low mid (funded adds 1.9) | 3.5 | 3.6 | 3.8 | 4.0 |
| Siena, Lucca, Mantua, France | poor | 3.0 to 3.1 | 3.0 | 3.1 | 3.1 |

**What each can afford** (points an age = average rate x 160 / 220 / 300 seasons; before diffusion, before research-boosting techs):

| Country | Points I | Share of 1,800 | Points II | Share of 2,800 | Points III | Share of 4,500 |
|---|---|---|---|---|---|---|
| Milan (rich) | 1,060 | **59 %** | 1,730 | **62 %** | 2,760 | **61 %** |
| Venice | 860 | 48 % | 1,360 | 49 % | 2,070 | 46 % |
| Savoy (mid) | 780 | **43 %** | 1,210 | **43 %** | 1,800 | **40 %** |
| Genoa, no funding | 575 | 32 % | 830 | 30 % | 1,190 | 26 % |
| Genoa, funding every year (80 ducats) | 875 | 49 % | 1,240 | 44 % | 1,750 | 39 % |
| Siena (poor) | 485 | **27 %** | 670 | **24 %** | 920 | **20 %** |

Reading it: a rich country buys about **2.4 branch-ages** (a whole branch twice and a bit of a third); a mid country about 1.7; a poor
country about 1 (one branch, or a scatter of the cheap ones). The poor in age III fall to 20 % (target 25 to 30): funding (+450 points)
lifts it to 30 %, and diffusion (below) adds more. I would not raise the costs of age III to chase it; I would let the soak move it.

**Diffusion helps the right people.** A tech known by 3 trade partners costs 30 % less, so a poor country next to a specialist can
take what that neighbour learned. Real shares are 5 to 10 points higher than the table, more for the poor with big neighbours. That
is the intended catch-up and it also makes trade partners matter.

### 1.2 The age gate and banked research

- **The gate (year + 4 techs of the previous age, any branch) can stay as the owner approved it.** It no longer shapes anything:
  four cheap techs cost about 260 points, which even the poorest make by about 1506, so it only has to guard against a country with no
  research at all. Raising it (say to 6) would take 80 % of a poor country's whole age I (6 cheapest = 385 of 485) and force their
  choice, which is the opposite of the aim. The year (1520, 1575) is the real clock. *Recommendation: keep 4; the gate counts any
  branch.* (Question 2.)
- **Banked research (4 seasons) needs no change.** Nobody finishes an age, so nobody idles: the old problem "Milan runs out in 1505" is
  gone (Milan finishes 59 % of the age). The owner said to leave leaders for later balancing; it is solved as a side effect.
- **Older techs stay learnable** (a country in age II may still learn age I techs it skipped; they stay cheap). This is how a country
  widens later; it costs points that a new-age tech would have used, which is the choice.
- **Research boosters must be rationed.** Printing press, Cathedral schools, Universities, Coffee houses, Learned societies (+ Platonic
  Academy, Humanism) all raise the points. Together they can add about +35 % to a research specialist; the shares above do not
  include that. They are in Statecraft on purpose (a specialist in Statecraft can leave the pack), but the soak must check that no
  country reaches 85 % of an age.

## 2. The tree

Legend: **Cost** in points. **Needs**: same-branch needs in plain text, cross-branch needs in *italics* (dashed lines on the screen).
**Key**: `#n` is the row of spec 4.2; `NEW Kn` is a new key (section 5); "(as spec)" means the effect and row are unchanged from
`m11-build-spec.md` 4.3. Kept techs keep their name and effect; where the effect changes the line says "changed".
Era I cells also draw the country's national tech (gold tag), see section 6.

### 2.1 Military (identity: fight, hold, supply)

**Era I (450)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Drill yards | Companies gain +1 experience from every battle | 70 | | #11, #12 (as spec) |
| Supply trains | Supply reaches 2 points further | 70 | | #1 (as spec) |
| Siege craft | Artillery +1 siege point a season | 75 | | #24 (as spec) |
| Crossbow leagues (new) | Crossbowmen +1 defence (pavise shields) | 75 | | #22 missile +1 |
| Stud farms (new) | Knights need 1 horse fewer (3 to 2): horse-poor countries can raise cavalry | 80 | *Crop rotation* | #26 cavalry horses add -1 |
| Recruiting sergeants (new) | Every company costs a tenth fewer ducats | 80 | | #25 x4 scale -100 |

**Era II (700)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Tercio | Infantry struck by cavalry holds better (x1.25 to x1.5) | 110 | Drill yards | #13 (as spec) |
| Standing army | One more company on a hex (8 to 9); **refits cost 40 % of the new kind, not half** | 130 | | #3 as spec; **NEW K7** refit -100 (changed, from the review) |
| Bronze guns | Artillery +1 attack; a battery needs 1 more copper | 130 | Siege craft, *Corned powder* | #21, #26 (as spec) |
| Trace italienne | Fortresses defend better (+35 % a level) | 125 | | #14 (as spec) |
| Marching columns (new, the faster-marching tech; name TBD) | Every army gets 2 more movement points a month (infantry 12 to 14, riders 16 to 18, guns 8 to 10) | 100 | Supply trains | **NEW K9** |
| Captains' commissions (new) | A general costs a quarter less and a country may field **one more general** | 105 | Drill yards | #18 scale -250; **NEW K10** |

**Era III (1,125)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Volley fire | Missile companies +1 attack, fire 15 more a day | 190 | Tercio | #21, #23 (as spec) |
| Star forts | Garrisons +2 defence; a siege needs 1 more point a fortress level | 205 | Trace italienne | #15, #16 (as spec) |
| Magazines | Supply +2 more; armies eat a quarter less | 180 | Supply trains | #1, #2 (as spec) |
| Military revolution | One more company on a hex; a general adds 1 more | 210 | Standing army | #3, #17 (as spec) |
| Siege parks (new) | Artillery and infantry +1 siege point: sieges end sooner | 170 | Siege craft, Bronze guns | #24 artillery +1, infantry +1 |
| Royal armouries (new) | Your armourers make a fifth more arms | 170 | Standing army, *Arms fairs* | **NEW K3** armourer yield +200 |

### 2.2 Trade & Industry (identity: workshops, markets, merchants)

**Era I (450)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Guilds | **Opens the weaver and the armourer** (unlock only; no works discount) | 75 | | **NEW K1** weaver, armourer open (changed) |
| Double-entry books | +1 merchant | 80 | | #39 (as spec) |
| Crop rotation | Wheat districts +10 %; **opens the bakery** | 65 | | #28; **NEW K1** bakery open (changed) |
| Fulling mills (new) | Weavers make 15 % more cloth | 80 | Guilds | **NEW K3** weaver yield +150 |
| Deep shafts (new) | Mines +15 %: iron and copper for arms and guns | 80 | | #28 mines scale 150 |
| Mule trains (new) | Merchants carry 2 more loads | 70 | | #41 add 2 |

**Era II (700)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Ropewalk | Hemp districts +25 % (opens the rope industry when it exists) | 105 | Guilds | #28 (as spec); later K1 |
| Banking | Taxes on towns +20 % | 130 | Double-entry books | #7 (as spec) |
| Corned powder | Artillery fires 15 more a day (opens the powder mill when it exists) | 110 | Guilds | #23 (as spec); later K1 |
| Glass & leather | Grazing +20 % (opens glass and tannery when they exist) | 110 | | #28 (as spec); later K1 |
| Work house (new, owner's working name) | **Industries can be built to stage 3; towns and walled towns get +1 industry slot** | 135 | Guilds | **NEW K2, K4** |
| Arms fairs (new) | Arms bought from the market cost 1.3 times base, not 1.5 | 110 | Double-entry books | **NEW K6** add -200 |

**Era III (1,125)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Joint-stock company | +2 merchants | 205 | Banking, *Town charters* | #39 (as spec) |
| Bourse | Market towns reach 2 further; remote land sells at 80 %; **bought inputs cost 1.1, not 1.2** | 195 | Banking | #43, #44; **NEW K5** (changed, from the review) |
| Coffee houses | Towns' research +40 % | 190 | Glass & leather, *Universities* | #35 (value re-scaled, section 5) |
| Manufactories (new) | Every industry makes 10 % more; villages and cities get +1 slot | 195 | Work house | **NEW K3** x3, **K4** |
| Public bakeries (new) | Bakeries bake a quarter more bread (food, growth) | 160 | Crop rotation, *Town charters* | **NEW K3** bakery +250 |
| Master builders (new) | Every works job costs a tenth fewer ducats (the old Guilds discount, moved here) | 180 | Work house | #33 scale -100 |

### 2.3 Navigation (identity: coast, merchants' ways, exploration; mostly a coastal branch)

Without Cartography or any rider-sight tech, **exploration under deep fog** is three steps of one new key: the march penalty into land
nobody has seen gets smaller. The size of the penalty is the owner's open rule (`moves-in-the-month.md` answer 6); these techs only
shave it, so they cannot be tuned until the rule is fixed.

**Era I (450)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Portolan charts | Port dues +20 % | 65 | | #29 (as spec) |
| Carrack | Harbours and ports catch 25 % more fish | 75 | | #28, #30 (as spec) |
| Astrolabe | Your land sees 1 hex further | 75 | | #4 (as spec) |
| Rutters (new) | Marching into undiscovered land costs a quarter less | 80 | | **NEW K8** add -250 |
| River barges (new) | Merchants pay 2 less per route point (works inland too) | 70 | | #42 add -2 |
| Salted provisions (new) | Armies eat an eighth less (explorers and long marches) | 85 | | #2 add -25 |

**Era II (700)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Ocean pilots | Merchants pay a fifth less transport | 120 | Portolan, Astrolabe | #42 add -3 (as spec) |
| Plantations | Silk, dyes and olives +20 % | 125 | | #28 x3 (as spec) |
| Dead reckoning (new) | Marching into undiscovered land costs a quarter less again | 115 | Rutters, Astrolabe | **NEW K8** |
| Consulates (new) | Remote land sells 5 points dearer; an idle merchant comes home 1 season sooner | 120 | Portolan | #44 add 50, #47 add -1 |
| Shipwrights' quays (new) | Harbour works cost a quarter less | 105 | Carrack | #32 harbour scale -250 |
| Entrepots (new) | Market towns reach 1 further; port dues +10 % | 115 | Portolan, *Banking* | #43 add 1, #29 scale 100 |

**Era III (1,125)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Galleon | Port dues +25 % more; up to 7 merchants | 205 | Carrack, *Ropewalk* | #29, #40 (as spec) |
| Mercator charts | Armies see 1 hex further. **Changed: needs Ocean pilots and Astrolabe** (Cartography is gone) | 185 | Ocean pilots, Astrolabe | #27 (as spec) |
| Overseas factories | Merchants carry 4 more loads (12 to 16) | 200 | Ocean pilots | #41 (as spec) |
| Admiralty maps (new) | Marching into undiscovered land costs a quarter less again (three techs: three quarters in all) | 175 | Dead reckoning | **NEW K8** |
| Free ports (new) | Port dues +20 % | 190 | Entrepots | #29 scale 200 |
| Chartered convoys (new) | Merchants pay 2 less per route point | 170 | Consulates | #42 add -2 |

Route-cost stacking (River barges -2, Ocean pilots -3, Convoys -2 of a base 15) is about -47 %: watch it in the soak.

### 2.4 Statecraft (identity: people, taxes, learning, the law of war)

**Era I (450)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Tax rolls | Taxes on goods +2 points | 65 | | #6 (as spec) |
| Printing press | Research +15 % | 90 | | #34 (as spec) |
| Poor house (new, owner's working name) | People grow a tenth faster | 75 | | #9 scale 100 |
| Cathedral schools (new) | Towns' research +25 % | 80 | | #35 add 2 |
| Poll lists (new) | A levy takes 11.5 % of a hex's people, not 10 %: more men for arms to equip | 65 | | #10 add 15 |
| Chancery seals (new) | War goals one district bigger | 75 | | #49 add 1 |

**Era II (700)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Universities | Cities +0.5 research, walled towns +0.25 (re-scaled) | 130 | Printing press | #36 (value re-scaled) |
| Town charters | Towns hold a tenth more people | 105 | | #31 (as spec) |
| Royal bureaucracy | High taxes slow growth half as much; reach +2 steps | 120 | Tax rolls | #9, #48 (as spec) |
| War councils (new) | War weariness grows a quarter slower | 110 | Chancery seals | #52 to #55 scale -250 |
| Academies (new) | Techs known by partners get cheaper by up to 40 % (not 30) | 125 | Universities | #38 add 100 |
| Cadastre (new) | Normal taxes +5 points | 110 | Tax rolls | #8 add 50 at Normal |

**Era III (1,125)**

| Tech | Plain effect | Cost | Needs | Key |
|---|---|---|---|---|
| Absolutism | Levies +25 %; High taxes +10 points; war goals +2 districts | 205 | Royal bureaucracy | #10, #8, #49 (as spec) |
| Mercantilism | Tolls +2 points at every level | 175 | | #45 (as spec) |
| Provincial governors (new) | Your reach +3 steps: far lands are less restless and pay more | 185 | Royal bureaucracy | #48 add 3 |
| Learned societies (new) | Research +10 % | 200 | Academies, Printing press | #34 add 100 |
| Law of nations (new) | Losing districts weighs half as much; infamy fades 0.1 faster | 175 | War councils | #55 scale -500, #51 add 1 |
| State monopolies (new) | Taxes on goods +2.5 points | 185 | Cadastre | #6 add 25 |

### 2.5 What is kept, changed and new

| Group | Count | Which |
|---|---|---|
| Kept as the owner approved | 36 | all 37 of the spec minus Cartography; none renamed |
| Changed in effect | 6 | Guilds (unlock only), Crop rotation (+ bakery), Standing army (+ refit), Bourse (+ bought inputs), Mercator charts (new needs), Universities and Coffee houses (re-scaled values only) |
| Removed | 1 | Cartography |
| New | 36 | 7 Military, 8 Trade, 10 Navigation, 11 Statecraft |
| Total tree | 72 | 6 per branch per age |

The three techs the owner agreed are in: Poor house (Statecraft I), Work house (Trade II) and the faster marching tech (Marching
columns, Military II; **name still to be decided**). Cost lines of the kept techs are re-set (the spec's 80/180/380 come down to about 75/115/190
because the pool per age is the same but the techs are twice as many); the effect numbers do not move.

Coverage of the new systems: **industries** (Guilds, Crop rotation, Fulling mills, Work house, Manufactories, Public bakeries),
**arms and refits** (Arms fairs, Royal armouries, Standing army, Deep shafts), **slots** (Work house, Manufactories), **population**
(Poor house, Town charters, Public bakeries), **scouting under deep fog** (Rutters, Dead reckoning, Admiralty maps, Salted
provisions), **market buying** (Bourse, Arms fairs), **movement** (Marching columns), **sieges and fortresses** (Siege craft, Siege
parks, Trace italienne, Star forts), **generals** (Captains' commissions, Military revolution), **taxation** (Tax rolls, Cadastre,
State monopolies, Absolutism), **diplomacy and trade** (Chancery seals, War councils, Law of nations, Consulates, Free ports).
No tech is a bare "+5 %" filler: the weakest changes one decision (for instance Poll lists, which moves the men limit against the arms limit).

## 3. Each branch's identity when a country goes deep

| Branch | Going deep (about 450 / 700 / 1,125 points = the whole branch) looks like | Trade-off |
|---|---|---|
| Military | Era I: cheap cavalry and crossbows, cheaper companies. II: bigger stacks, cheaper refits, two generals, armies that march 14. III: sieges end fast, fortresses are very hard, a strong armourer. A war machine | Economy and research are skipped; refits and arms still need the armourer and iron, which Trade provides |
| Trade & Industry | I: weaver, armourer and bakery open early with a richer mine. II: stage 3 and extra slots, cheaper arms bought. III: more output, cheaper builds, big merchant fleets. A workshop economy | Almost no war tech: the country buys arms (at a premium) and relies on others to arm |
| Navigation | I: cheap dues and fish, deep-fog marches a quarter cheaper. II: consulates, quays, entrepots. III: ports with dues +65 % over the age, convoys, cheap overseas routes. A coastal trade state, or an explorer on a random world | Poor for inland countries (River barges, Salted provisions, Mercator, Chartered convoys and Overseas factories still work inland); weak on a known Europe where deep fog matters little |
| Statecraft | I: people grow faster, more men per levy, larger war goals. II: slower weariness, cheaper learning from partners. III: far provinces held, research +10 %. A research and administration state that wins long wars and wide conquests | No direct fighting or economic power: it gets bigger and learns faster, then must buy the rest |

**What the AI does:** it scores each tech as in the design (`tech-tree.md`, AI) with one added bonus: techs of the branch it already knows
most get x1.3, so AI countries specialise (one branch deep, one half) instead of spreading; the personality weights stay.

## 4. Forced choice by cost (no locks)

A branch-age is worth 450, 700 or 1,125 points; a poor country has about 1 of them, a mid country 1.7, a rich one 2.4. Typical builds
in age I:

| Country | Spends about | A plausible build |
|---|---|---|
| Rich (Milan, 1,060) | 2 branches + 160 | all of Trade (workshops open) + all of Military + 2 cheap Navigation |
| Mid (Savoy, 780) | 1 branch + 330 | Statecraft (Printing press first) + the cheap half of Military |
| Poor (Siena, 485) | 1 branch | Trade core: Guilds, Crop rotation, Double-entry, Fulling mills, Mule trains (370) + 1 more; the rest by diffusion |

Pairs that compete hard (about the same points, different jobs): **Work house vs Marching columns vs Arms fairs** (age II
choices at 100 to 135: workshop, army or supply); **Printing press vs Guilds** (research against industry, 90 vs 75); **Siege parks vs
Learned societies**. Each branch's four most useful techs in an age cost about 70 % of the cell, so a deep specialist gets the core and
leaves the tail. Tuning lever: `ERA_GATE` stays; only costs (data) and the three rate values move.

## 5. New modifier keys, and what spec 4.2 must change

Registry goes from 55 to **65** keys (ten new rows); each needs a reader, bounds, a "forgets" and a probe test (spec done-when 1b).

| Key | Name | Ops | Bounds | Read by | Used by |
|---|---|---|---|---|---|
| K1 | `industry.<kind>.open` | add (0 or 1) | 0..1 | `Works.industry_open` (replaces the year gate) | Guilds, Crop rotation; later Ropewalk, Corned powder, Glass & leather |
| K2 | `industry.stage_max` | add | 2..3 | `Works.stage_max` | Work house |
| K3 | `industry.<kind>.yield_permille` | add | 0..500 | `Industry.output` | Fulling mills, Royal armouries, Public bakeries, Manufactories |
| K4 | `family.settlements.slots` | add `at` level | 0..2 | `Slots.count_at` | Work house, Manufactories |
| K5 | `economy.buy_input_permille` | add | -300..0 (base 1,200) | `Buying.price` | Bourse |
| K6 | `economy.buy_arms_permille` | add | -500..0 (base 1,500) | `Buying.price` | Arms fairs; the Arsenal of Venice card moves here |
| K7 | `war.refit_permille` | add | -300..0 (base 500) | `Military.refit_cost` | Standing army |
| K8 | `defs.deepfog_cost_permille` | add | -1000..0 (base the rule) | `StepCosts` deep-fog term | Rutters, Dead reckoning, Admiralty maps (numbers wait for the rule) |
| K9 | `units.march` | add | 0..4 | movement allowance a month | Marching columns |
| K10 | `war.generals_base` | add | 0..4 | `Generals.places` | Captains' commissions |

**Amendments to spec 4.2 / 4.3:** (a) replace the tree table by section 2; (b) the sentence "step costs are never modified" now has
two exceptions, K8 and K9 (the allowance and the deep-fog term, not the terrain costs); (c) register D8's exception: K1 and K2 are
whole-number rows, no on/off switch outside this family; (d) row #5 `defs.know_range` stays registered but **no tech uses it any more**
(keep for random worlds and future cards, or drop it: the registry stays 64); (e) D9 rates as in 1.1; and because `town_milli` falls from 15 to 8, **Coffee houses becomes add 3** (was 6), **Universities
add 500 at 5 and 250 at 4** (was 1,000 and 500); (f) 4.4 gate text unchanged ("4 tree techs"), era I cell text "at most 4 techs after nationals" is gone
(see 6); (g) `ResearchDef` validate: techs ids 0..71 (national from 72), ideas unchanged; (h) the probe tests count 65; (i) the Venice card Arsenal:
"arms cost 1.2" through K6 (review 4.1). Old save format is unchanged (the new FORMAT already refuses older saves).

## 6. What the screen needs (the Studiolo kit)

The approved picture (`images/14_tech_tree_c.png`) is a grid of 4 branch rows x 3 age columns; each cell is **2 cards wide x up to 2 rows**
(4 cards). The new cell holds **6 (plus the national tech in age I, so 7)**. Measured from the picture (1600 x 900): a card is about
170 x 70, a cell 350 x 175. With 6 cards a cell is **2 columns x 3 rows**: about 350 x 250, so the 4 branch rows are about 1,000 px
plus a 130 px header and strip, too tall for any window shorter than about 1,200 px.

Options:
1. **Two columns x three rows with a vertical scroll** (branch labels stay on the left, the era headers and the research strip stay on top). The simplest port of the
   approved look; the grid keeps its shape and the dashed lines still work. *Recommended.*
2. **Compact cards** (about 60 px high: icon, name, cost; the effect line only in the side card): 3 rows x 60 = 200 per cell, 4 rows =
   about 840 + header: fits 1080p with no scroll, still scrolls at 720p.
3. **One branch open at a time:** a tab per branch, the others as one-line progress chips. Hides the cross-branch lines, which is a
   main reason for the grid. Not recommended.

What the layout port (`techlayout`, pure) must do: 3 rows per cell; the national tech takes a seventh slot in the age I cell (put it in
the first row of the cell, a card wider than the rest or a gold chip in the branch label: I recommend the label chip, so the cell stays
6 and the slot never moves); scroll offset; dashed cross-branch lines drawn across the scrolled grid; a "jump to" for a queued far tech; the
hover card and the side card as today. The side card's "unlocks" list grows (industry names, slots, deep-fog line). The Fund and queue strip stay as in the picture.
Icons: 36 new icons (art), 1 per tech; reuse the existing 31 where fine (the list in 4.3 icons) until the art pass.

## 7. Data-entry order for Kioba (issues 447a and 447b)

| Step | Can be entered now | Waits |
|---|---|---|
| 1 | The era files (names, years, gate 4); the 36 kept techs with their spec rows (names, keys, branch, era, flavour, icons); costs from section 2; Guilds and Crop rotation with their K1 rows once K1 is registered | Costs may change after the soak |
| 2 | New techs that use only existing keys: Crossbow leagues, Stud farms, Recruiting sergeants, Siege parks, Deep shafts, Mule trains, Master builders, Consulates, Shipwrights' quays, Entrepots, River barges, Salted provisions, Free ports, Chartered convoys, Poor house, Cathedral schools, Poll lists, Chancery seals, War councils, Academies, Cadastre, Provincial governors, Learned societies, Law of nations, State monopolies, Captains' commissions (its #18 row; K10 later), Standing army (its #3 row; K7 later) | The owner answers 1, 2, 3 |
| 3 | The 13 nationals and the default; the 16 general cards except those named in the review (Navigators' guild, Fuggers' credit, Pike levies, Merchant houses, Arsenal) | Review answers 7 and 8 |
| 4 | Rows using a **new key**, entered the day the key is registered: K1 (Guilds, Crop rotation), K2 and K4 (Work house, Manufactories), K3 (Fulling mills, Royal armouries, Public bakeries), K5 (Bourse), K6 (Arms fairs), K7, K9 (Marching columns), K10, K8 (Rutters, Dead reckoning, Admiralty maps: numbers wait for the deep-fog rule) | Each new key (reader + test) |
| 5 | The research rate values (D9) | Owner question 1 |

Tip: enter every tech now with its plain-text line and cost, and leave rows that use a new key commented out; the tree is then
complete and valid (the keys it lacks have no effect yet), and nothing needs retyping. The tree test (ids 0..71 in order, acyclic, unique keys) can be written now.

## 8. Risks

- **The rates are the biggest change.** Flattening them makes a poor country nearly as fast as a mid-size one early (3.0 against 4.6 to 6.1).
  That is the aim (they must be able to specialise), but the leaders' headstart in towns shrinks; the soak must still show Milan well ahead.
- **Research boosters** (Printing press, Cathedral schools, Universities, Coffee houses, Learned societies, Academies) can snowball a
  Statecraft specialist; cap at +35 %.
- **Three deep-fog techs rest on a rule the owner has not fixed;** on a Europe map (everything known) they do little. Navigation's
  inland value is Rivers barges, Salted provisions, Mercator, Convoys and Overseas factories only.
- **Route-cost stacking** (about -47 %) and **tax stacking** (Tax rolls, Cadastre, State monopolies, Absolutism, Royal mint card) need the soak.
- **Costs are not measured.** Every share above is paper arithmetic from the rate table; the research soak (10 games of 440 seasons) is the proof.
- **Tree size costs UI and art:** 36 new icons, a scroll in the screen, 10 new probe tests; the AI scoring needs the branch-depth bonus.
- **Unfinished:** later industries (rope, glass, powder, tannery) have no K1 rows yet; the name of the marching tech; the Gonzaga captains national
  (generals cost half) now overlaps Captains' commissions (they stack to -75 %): the review already asked for a replacement.

## 9. Questions for the owner

1. **Flatten the research rates** (base 1.5 to 3.0 a season, towns' share about half)? Without it a poor country can learn only 14 % of an age and
   cannot even open age II. Options: (a) flatten as proposed; (b) keep the rates and accept 14 % for the poor, 74 % for the rich; (c) a middle: base 2.2.
   *Recommend (a).*
2. **Keep the age gate at "year + 4 techs"?** It no longer shapes choices. Options: (a) keep 4; (b) raise to 6 (forces cheap techs on the poor). *Recommend (a).*
3. **Targets:** accept rich 60 %, mid 40 to 45 %, poor 20 to 27 % (poor falls to 20 % in age III unless it funds or trades)? Options: (a) accept; (b) lower age III's costs
   to 3,800 so the poor reach 24 %. *Recommend (a); let the soak decide.*
4. **Name of the faster-marching tech** (working name Marching columns). Options: Marching columns, Forced marches (a battle card already has this name), Military roads.
   *Recommend Marching columns; and +2 movement points (12 to 14).*
5. **Slots:** Work house gives +1 slot in towns and walled towns; Manufactories +1 in villages and cities. Too many or too few?
   *Recommend as written (one slot tech in age II, one in age III).*
6. **Works discount:** it left Guilds and returned as Master builders (Trade III, 10 %). Keep it there, or drop it altogether? *Recommend keep.*
7. **Deep-fog techs** (Rutters, Dead reckoning, Admiralty maps: three quarters off the march penalty in all): keep three, or only two? *Recommend keep three; numbers wait for your rule.*
8. **Research boosters:** accept up to +35 % for a research specialist, or cap lower (+25 %: drop Learned societies' effect to Statecraft's other job)? *Recommend +35 % and measure.*
9. **Screen layout:** vertical scroll (option 1), compact cards (option 2) or both (cards compact below 1,000 px)? *Recommend option 1 now; compact cards later if the playtest asks.*
10. **Replace weak nationals** (Gonzaga captains, Genoa's Casa di San Giorgio) when the soak says so? Same as review question 8. *Recommend yes, second pass.*

---

## Owner's answers, 2026-11-24

1. **Research rates:** flatten them so the richest country researches about twice as fast as the poorest (not five times).
2. **Age gate:** no tech minimum; an age opens by the year only. (This replaces "year plus 4 techs" for the whole tree; the
   cost of techs, not a gate, forces the specialisation.)
3. **The faster-marching tech** is called **Military roads** (Military, age II, +2 movement points a month).
4. **The screen:** the tree scrolls vertically at first; compact cards come later if they are needed.
Not asked yet: the remaining questions of section 9 (slot techs, the works discount moved to Master builders, the three
deep-fog techs, the research-booster cap, replacing the weaker national techs); the draft's recommendations stand for them until the owner changes them.
