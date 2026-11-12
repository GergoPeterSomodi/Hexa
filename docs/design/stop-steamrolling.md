# Stop steamrolling, diplomacy and rebels: design proposal

Status: DRAFT for the owner (2026-11-12). Nothing here is approved or built. Each part lists its mockups; the owner sees mockups before any build.

The three parts are one system seen from three sides:
- **Stop steamrolling** is the brake: conquest costs more the more you hold.
- **Diplomacy** is the rules of war: why a war starts, what the winner may take, who joins.
- **Rebels** are the price of holding land you took: unrest turns into revolts.

They share three meters (regional unrest, country infamy, country war weariness), so they should be approved as one package and built in slices.

## Questions for the owner

1. **One package or three?** Recommended: one design, built in three slices (brakes, then war goals, then rebels).
2. **How hard should the brakes bite?** (a) soft: a big country is slower and poorer; (b) medium: a big country must fight revolts and coalitions to keep growing; (c) hard: a country above a size cannot grow. Recommended: (b). Never (c).
3. **Where does unrest live: per hex or per region?** A province is one hex, and 87% of owned land has no village. Per-hex unrest would mean hundreds of meters and one garrison per hex. Options: (a) per hex; (b) per historical region (434 on the Europe map, median 6 hexes; France has 43, Muscovy 24). Recommended: (b). The player reads "Catalonia is restless", and movements and free states (Part C) use the same unit. Random worlds have no regions today, so they need generated ones first (see Risks).
4. **Is the starting land safe?** Without a rule, the distance penalty would hit Muscovy, the Azores or Crete on turn 1. Options: (a) land held at the start, or held for 40 seasons (10 years), counts as **home land**: no foreign-region unrest and half the distance penalty; (b) no exemption. Recommended: (a). The brakes act on growth, not on the 1480 map.
5. **Overextension: national or by distance?** (a) one national admin number; (b) distance from the capital and admin centres; (c) both. Recommended: (c), with (b) doing most of the work, because the player can see it on the map.
6. **Coalitions: also against the player?** Recommended: yes, against anyone, so the player feels the same brake. A warning shows at 60% of the limit, and the peace screen shows the infamy before you sign.
7. **Rebels: a stack of soldiers, or only a region flipping?** Recommended: both, in two steps. First the rebel stack (it uses today's siege and battle rules). Independence and free states come second.
8. **Can a dead country come back?** Recommended: yes, as a free state from its old region (like Portugal in 1640). Europe map only until random worlds have regions.
9. **Claims to the throne in the first version?** (a) skip; (b) a small table of historical claims that gives a war goal with a bigger cap; (c) full personal unions. Recommended: (b), but after the core (step 9). Unions later.
10. **Alliances: how binding?** (a) a call to arms the ally may refuse, at a cost in relations; (b) automatic join. Recommended: (a).
11. **Should war end by peace terms, not by a timer?** Today AI wars end after 16 seasons and the player's after 32. Recommended: yes, with a 40-season safety timer only.
12. **Tools against unrest** (garrison, castle, a court, buying off rebels): yes, never a free button. Each costs ducats, troops or tax.

## 1. What happens today (checked in the code)

- **War:** `war_check` allows war on any living neighbour you are not already at war with. No casus belli, no truce, no allies.
- **War score** (`war_score`): provinces you occupy minus provinces you lost, +3 if you hold their capital. Every province counts the same, empty or city.
- **Player peace** (`peace_offer`, from the country panel): "take" is accepted at score 3 or more, or at 1 or more if their army is not stronger than yours; the winner then takes every province it occupies, except the capital, which goes back. White peace needs score -1 or better and 4 seasons of war. Surrender is always accepted.
- **Timers** (`end_round`): an AI war ends at 16 seasons (`WAR_LENGTH_AI`) or as soon as the score reaches 5 either way, and the leader takes what it occupies. A war with the player ends at 32 seasons, and then **each side keeps what it occupies**.
- **AI wars** (`ai._diplomacy`): every 8th season a country at peace, with over 100 ducats, rolls a 12% chance and attacks a random neighbour whose army is under 1/1.8 of its own. At most `MAX_WARS` = 3 wars in the world (a constant in `ai.py`, not `data.py`).
- **Conquered land** pays tax at once. There is no unrest, no infamy and no rebels. Tax (low, normal, high) is set for the whole country, not per province.
- **The only costs of size** are army upkeep, settlement and castle upkeep, and the supply range.
- **The map:** a province is one hex. Of 4,311 owned land hexes in Europe 1480, 3,773 (87%) have no settlement, 432 a village, 73 a town and 33 a city. Muscovy holds 637 hexes but only 2 settlements and 1 castle.

Measurement (seeded all-AI games, no player, 160 seasons = 40 years, Europe 1480 and two random worlds; land provinces owned):

| World | Biggest at start | Biggest after 40 years | Median country at start | Wars running at the end |
|---|---|---|---|---|
| Europe 1480 | Muscovy 637 | Muscovy 642 | 43 | 1 |
| Random seed 1 | 502 | 502 | - | 0 |
| Random seed 2 | 609 | 609 | - | 2 |

What this says:
- **The start is the problem, not AI growth.** Europe has 49 countries. Muscovy holds about 15% of all land, 15 times the median. France has 161, Castile 109, England 77, Venice 43, Portugal 27.
- **The AI hardly changes the map in 40 years.** The top four change by under 3%, and no country died. But a full game is 170 years (680 seasons), so a full-length run is needed before we say the AI never snowballs.
- **So the steamroller is the player,** and any AI made more aggressive (war goals will do that). A human who beats one weak neighbour at a time meets no brake today.
- Brakes are built first, and tuned with a scripted "conqueror" player that attacks its weakest neighbour whenever it can, not only with all-AI runs. Step 0 of the build plan builds that probe.

(Measured with a scratch script on `CampaignWorld` and `GameManager.end_season`; not in the repo.)

## 2. Part A: stop steamrolling

### The problem
A country that wins early wins more, with no cost for size. Taken land pays at once, there is nothing to fear in a war, and neighbours do not react.

### Real history to borrow from
- Big composite states were hard to hold: Charles V's lands, the Ottoman reach into Hungary, the Spanish Netherlands (revolt from 1566).
- Rivals ganged up on the strong: the League of Cambrai against Venice (1508), the leagues against Charles V.
- Ridges and seas split states: the Alps, the Pyrenees and the Channel kept most borders stable for centuries.

### The brakes (five, each simple on its own)

| Brake | What the player feels | Rule in one line |
|---|---|---|
| Overextension | far land pays less and is restless | a reach penalty by distance to the capital or an admin centre |
| Unrest in conquered land | newly taken land is unsafe for years | a decaying unrest bump after each conquest |
| Infamy and coalitions | neighbours unite against a grabber | land taken without a claim adds infamy; high infamy opens a coalition |
| War weariness | long wars hurt | a meter that cuts income and makes the AI ask for peace |
| Natural borders | crossing a ridge costs more | ridge modifiers on unrest, siege and peace cost, and AI target choice |

### Options for the core model

**Option 1: one national "admin" number.** Capacity from cities, courts and techs against the weight of the land held. Over 100%: taxes fall and unrest rises everywhere.
- Good: one bar, easy to balance. Bad: it feels like a tax, not geography, and hits compact France as hard as a scattered empire.

**Option 2: distance, per region.** Each region has a reach cost from its distance (in hexes, through passes, never over a crest) to the nearest capital or admin centre (a city or a court). Far regions pay a smaller tax share and are more restless.
- Good: the player reads it as a map mode; it rewards a compact country, gives cities a new job, and works with ridges and seas. Bad: needs a cached distance field, recomputed on ownership or building changes.

**Option 3: both (recommended).** Option 2 for the local feel, plus a mild national part that counts only land **gained since the start**, so no country is punished for its 1480 size.

### Numbers to start from (`data.py`)
All names are proposals; every value goes to `data.py`. Distances are in hexes and scale with `SCALE`. All values are tuned with the conqueror probe.

```
# Unrest, per region, 0 to 100
UNREST_CONQUEST        = 30     # added when land in the region changes owner by war or purchase
UNREST_CONQUEST_DECAY  = 1.5    # lost per season (gone in 20 seasons = 5 years)
UNREST_FOREIGN_REGION  = 10     # not home land (question 4)
UNREST_FAR_PER_STEP    = 1.0    # per 2*SCALE hexes of reach beyond REACH_FREE
UNREST_RIDGE           = 8      # the way to the capital crosses a crest (through a pass)
UNREST_HIGH_TAX        = 10     # the country's tax is high; low gives -10 (applies everywhere)
UNREST_WAR_WEARINESS   = 1.0    # per weariness point (0 to 10)
UNREST_GARRISON        = -10    # troops stand in the region; capped, see Risks
UNREST_CASTLE          = -15    # a castle in the region
UNREST_COURT           = -15    # an admin centre in or next to the region (new building, later)
UNREST_HOME_CAPITAL    = -20    # the capital's region
REACH_FREE             = 12 * SCALE   # hexes from a capital or court with no penalty
REACH_TAX_LOSS         = 0.02   # tax share lost per 2*SCALE hexes beyond REACH_FREE, floor 0.4; home land loses half
HOME_SEASONS           = 40     # seasons held before taken land counts as home land
ADMIN_FREE_GAIN        = 30     # hexes gained since the start before the national part bites
ADMIN_PER_EXTRA        = 0.004  # tax lost nationwide per gained hex over ADMIN_FREE_GAIN, max 0.3
# Thresholds
UNREST_RESTLESS        = 40     # tax -25% in the region, a warning in the panel
UNREST_RISING          = 70     # rebel chance each season; no recruiting there
UNREST_REVOLT          = 100    # revolt (Part C)
# Infamy, per country, 0 up
INFAMY_BY_LEVEL        = (0.25, 1.0, 2.0, 4.0)  # per hex taken with no claim: empty land, village, town, city
INFAMY_CLAIMED         = 0.0    # taking land in the war goal or a claim costs nothing
INFAMY_DECAY           = 0.25   # per season (1 a year)
COALITION_AT           = 25     # infamy that opens a coalition
COALITION_END          = 10
COALITION_MIN_SHARE    = 0.05   # the aggressor holds this share of all land, or of its neighbours' land
# War weariness, per country, 0 to 10
WEARINESS_PER_SEASON   = 0.4    # while at war with an army in the field or an enemy on your land
WEARINESS_LOST_BATTLE  = 0.5
WEARINESS_LOST_PROVINCE= 0.1    # per hex lost to the enemy (most hexes are empty land)
WEARINESS_DECAY        = 0.8    # per season of peace
WEARINESS_INCOME       = 0.03   # income lost per point
WEARINESS_AI_PEACE     = 5      # the AI asks for peace above this
```

Colonies and trading posts have no reach penalty and no infamy in the first version: they have their own rules today, and the colonisation rework and the tribal nations design decide their costs (see Sensitive topics).

Reading the numbers: a freshly conquered region starts at 30 (below restless); a far foreign region under normal tax at about 30 + 10 + 3 = 43 (restless, taxed less). Add high tax and some weariness and it nears 70. A garrison and a castle bring it down. A home region near the capital sits near 0. Taking 100 empty hexes, or 25 villages, with no claim opens a coalition; it fades after about 15 years of good behaviour.

### What the player sees
- **Province panel:** the region's unrest bar in four colours (calm, restless, rising, revolt). Hover lists each cause with its number ("Recently conquered +21", "Far from the capital +6", "Garrison -10"). A line "Tax share 85%" shows the reach loss.
- **Map mode "Stability":** regions tinted calm to red, reach rings from each capital or court as faint contour lines, basins (section 5) faintly. Country borders stay visible, as for every map mode.
- **Country panel:** infamy and weariness as two small bars with hover text, and "Gained land 42 of 30 free" for the national part. "Coalition risk" appears at 60% of `COALITION_AT`.
- **Before you act:** the declare-war dialogue and the peace screen show the infamy, the unrest bump and the expected tax share of the land you would take. No brake is felt for the first time after the fact.
- **Alerts:** "Unrest rising in <region>" as floating text, "Coalition formed against you!" as a box like the war alert, war weariness as a top-bar chip.
- **Treasury breakdown:** a new line "Lost to distance and unrest".

Mockups needed (before any build):
1. Province panel with the unrest bar and the hover reasons.
2. The Stability map mode with reach contours.
3. Country panel with the meters and the coalition warning.
4. The "Coalition formed" alert box.
5. Treasury breakdown line.

### What the AI does
- Counts the unrest and reach cost of a target before it attacks: land far from its capital or across a crest is worth less.
- Keeps infamy below 70% of `COALITION_AT` unless the target is weak and claimed.
- Garrisons restless regions; builds castles first where unrest is above `UNREST_RISING`.
- Asks for peace when weariness is over `WEARINESS_AI_PEACE`, or when a coalition has formed and it is losing.
- Joins a coalition when the aggressor's infamy is over the line, its own army is free, and it is not allied to the aggressor.

### Coalition rule
- A coalition forms when a country's infamy passes `COALITION_AT` and it holds at least `COALITION_MIN_SHARE` of the land. Members are its neighbours (and anyone it took land from) that are not allied to it.
- Members get a "Contain the aggressor" war goal that costs no infamy, and relations with the aggressor fall by 30.
- It fades when infamy falls under `COALITION_END`. The AI joins by its own rules; the player may join or decline.

### How hard the coalition bites
- **Soft:** only the relation drop and a free war goal. A possible war, not a certain one.
- **Hard:** members declare war at once. Clear, but one bad conquest can end a run.
- **Recommended: soft, plus an alliance offer between members.** The AI uses the free war goal when its odds are good.

### Risks
- **Every run stalls at the starting map.** Tune with the conqueror probe so a good player can hold about 1.5 to 2 times the starting land by 1650.
- **Unrest unreadable.** Every number has a hover reason, and every cost is shown before the war or peace that causes it.
- **Coalition-ed for colonising.** Unowned land and colonies cost no infamy.
- **Snowball:** a big country's tax pays for garrisons everywhere. Garrison troops pay upkeep, the garrison bonus does not stack, and reach unrest cannot be garrisoned away below the distance part.
- **Micromanagement:** per-region unrest and a garrison bonus per region (not per hex) keep the number of things to watch small.
- **City states:** a bought city state (city-states design) counts as gained land and gets the conquest bump, but no infamy. This replaces that design's "half income for 8 seasons" stand-in.

### Smallest first version (A)
Regional unrest (conquest bump, foreign region, tax, garrison, castle), home land, the tax and recruit effects at the thresholds, reach by distance, the national part on gained land, infamy and a soft coalition, weariness income loss. No new buildings (the court comes later). Map mode and panel hover. AI target scoring.

## 3. Part B: diplomacy rework

### The problem
War is a dice roll every eight seasons. A war has no reason, no goal and no friends, and the winner takes everything it occupies. There are no alliances, no truces and no grudges. The world feels flat, and the player has no diplomacy to play.

### Real history to borrow from
- Casus belli: rulers needed a reason, even a weak one (a dynastic claim, an insult, a border dispute). The Hundred Years' War ran on a claim to the French crown; the Italian Wars (from 1494) on claims to Naples and Milan.
- Alliances and leagues: the League of Cambrai (1508), the Holy League (1511), the Franco-Ottoman alliance (1536).
- Peace terms were bargained: a province, a payment, a marriage.

### Rules in outline
- **Relations:** -100 to +100 for each pair that has met, decaying toward 0. Gifts and alliances raise it; border grabs, wars and coalitions lower it.
- **Pacts:** alliance, non-aggression pact, truce. A truce follows every peace.
- **Casus belli (CB)** gives a war goal:
  - **Conquest** (no CB): allowed against any neighbour, costs infamy.
  - **Claim:** paid for with ducats (`CLAIM_COST`) on a region next to your land; takes a few seasons; no infamy.
  - **Throne claim:** a data table of historical claims (later).
  - **Liberation / reconquest:** take back a region that was yours.
  - **Contain the aggressor:** from a coalition.
  - **Defence:** an ally was attacked.
  - **Humiliate:** gold and relations, no land; for small wars.
- **War goal:** one per war. The winner takes land in the goal cheaply, and more only at a higher war-score cost and extra infamy.
- **War score** (0 to 100 per side): replaces today's count. Occupied land counts by its peace cost, won battles add a little, the capital counts big.
- **Allies:** a call to arms when war is declared; the ally answers within a season, and may refuse (relations -20).

### Options

**Option 1: light layer on today's rules.** Truces, relations and claims; peace keeps "take what you occupy", capped by the goal.
- Good: small, ships fast. Bad: war goals feel like a coat of paint.

**Option 2: war goals with a war-score budget (recommended).** The winner spends war score to buy land from a menu.
- Good: the core of Europa Universalis-style peace, and it plays well; it links straight to infamy and ridges; the AI can reason about it. Bad: needs a peace screen and more code.

**Option 3: vassals, unions and marriages.** Very historical, but huge. Keep for Phase 2 of the long-term roadmap.

### Peace cost (for Option 2)
```
WAR_SCORE_MAX           = 100     # a side's score; reaching it means total victory
PEACE_COST_BY_LEVEL     = (1, 4, 8, 15)  # per hex: empty land, village, town, city
PEACE_COST_CAPITAL      = 40
PEACE_COST_OUTSIDE_X    = 2.0     # land not in the war goal
PEACE_COST_RIDGE_X      = 1.25    # land across a crest from the winner's land
PEACE_COST_OCCUPIED_X   = 0.5     # the winner holds it with an army
SCORE_PER_BATTLE        = 3       # per battle won, at most 15 per war
TRUCE_SEASONS           = 12      # 3 years
WAR_TIMER_SAFETY        = 40      # an old war closes with white peace
CLAIM_COST              = 60      # ducats per claim
CLAIM_SEASONS           = 4
RELATION_ALLIANCE_MIN   = 40
ALLY_REFUSE_RELATION    = -20
MAX_PACTS               = 2       # alliances per country
```
Reading it: a town across a crest, outside the goal, costs 8 x 2.0 x 1.25 = 20 war score. A claimed town costs 8, or 4 if your army holds it. A region of six empty hexes and a village in the goal costs about 10. A city plus the capital is about 55. A "take the border region" war is cheap; "swallow a country" is long and infamy-heavy.

`SCORE_PER_BATTLE` is a diplomacy rule, not part of the battle screen; the battle design left "war score" out of the battle aftermath on purpose, so the owner should confirm it.

### What the player sees
- **Diplomacy screen** (new, from the country panel): the countries met, each with a relations bar, pacts, truce time, and buttons for gift, alliance, claim and declare war. A disabled button says why on hover ("Truce for 7 more seasons").
- **Declare war dialogue:** pick the CB and goal (highlighted on the map); shows the infamy cost and the known allies on each side.
- **War panel:** the war score as a tug-of-war bar, the goal, the allies.
- **Peace dialogue:** a menu of land with its peace cost, a running total against the war score, and the infamy and unrest each choice adds. White peace and surrender stay.
- **Alerts:** "Your ally X was attacked: join?" with accept and refuse; "Truce ends" chips.

Mockups needed:
1. Diplomacy screen.
2. Declare war dialogue with the goal picker on the map.
3. War panel with the score bar and allies.
4. Peace dialogue with the cost menu.
5. Call-to-arms alert box.

### What the AI does
- Scores each neighbour by relations, claims, strength, allies, the reach and ridge value of the goal, and infamy. Picks a CB and goal, or stays at peace. This replaces the 12% roll.
- Buys claims on weak neighbours in peace, and uses them.
- Makes peace by war score and weariness, not a timer.
- Answers a call to arms by relations, its own wars and the odds; drops allies that failed it.
- Never starts a war in the first 8 seasons of the game or within a truce.

### Interactions
- **Debt** (debt-and-bankruptcy roadmap): a country over its debt limit cannot join wars; a creditor's claim on provinces as a CB waits for that design.
- **City states** (city-states design): protection pacts and leagues were moved here. They are not in this package's first version; they come after alliances (step 5), with that design's rules as input.
- **Tech:** Statecraft techs could cut claim cost and unrest, and halve the far-land tax loss (to be placed in the tech tree).
- **Battle system (M2):** army morale exists only after M2; until then weariness touches income and unrest only. Later, a retreat from the field adds weariness.

### Risks
- **A spreadsheet screen.** Lean on a few strong verbs.
- **Every war a world war.** At most `MAX_PACTS` alliances per country; calls to arms are optional.
- **Claim spam.** Ducat cost and delay.
- **The AI goes passive** once every target has a cost. The soak checks it (section 10).

### Smallest first version (B)
Truces, relations (shown in the country panel), claims (buy and use), war goals with the peace-cost menu, white peace and surrender, an AI that uses claims. No alliances yet (step 5), no throne claims (step 9).

## 4. Part C: rebels

### The problem
Nothing pushes back when a player takes and holds land, so conquered land is just more tax. A rising is also a story: it is a reason to keep armies near home.

### Real history to borrow from
- The Peasants' War (1524), the Pilgrimage of Grace (1536), the Dutch Revolt (1566), the Catalan and Portuguese revolts (1640), the Irish risings, the Celali revolts.
- Motives: tax, religion, a foreign ruler, a lost war, an unpaid army.

### Rules in outline
- Unrest (Part A) is the engine:
  - **40 restless:** 25% less tax from the region, a warning.
  - **70 rising:** each season a chance (`REBEL_CHANCE` x (unrest - 70)) of a rebel band in the region. No recruiting there.
  - **100 revolt:** a rebel stack of `REVOLT_STRENGTH` appears, and the player gets the revolt choice (below).
- **Rebel stack:** era I infantry owned by the neutral tag `REB`. It besieges the owner's nearest ungarrisoned hex in the region and fights. It forages. Hexes it takes change **control**, not owner, until retaken.
- **Independence movement** (slice 2): when a historical region held by a foreign owner averages over `MOVEMENT_UNREST` and rebels hold it for `REBEL_HOLD` seasons, a movement forms. A living old owner gets a free liberation CB; a dead one can be reborn as a free state.

### Options
**Option 1: rebel stacks only.** Rebels spawn, fight and fade; control returns on retake.
- Good: uses today's war and siege code; the player must react with troops. Bad: no lasting story.

**Option 2: rebels plus regions that return to the old owner** (or become unowned if it is dead).
- Good: simple. Bad: dead countries stay dead; fewer story beats.

**Option 3: rebels plus independence and rebirth (recommended, in slice 2).** A held region forms a free state: a revived or new tag ("Free Catalonia") with a capital, a small treasury and troops, at war with its old master, able to make peace by war score.
- Good: the full independence movement the owner asked for, tied to war goals and stability. Bad: needs a country-creation path and new invariants.

### Numbers to start from (`data.py`)
```
REBEL_CHANCE        = 0.02     # per season per point of unrest over UNREST_RISING
REVOLT_STRENGTH     = 3        # infantry in the first rebel stack; grows with unrest
REBEL_HOLD          = 8        # seasons held before a movement may form
REBEL_FADE          = 12       # seasons without holding land before a band disbands
MOVEMENT_UNREST     = 60
FREE_STATE_TREASURY = 80
FREE_STATE_TROOPS   = 4
FREE_STATE_TRUCE    = 8        # seasons with no third-party attack on the new state
REBIRTH_COOLDOWN    = 160      # seasons before the same tag can be reborn again
```

### What the player sees
- **Rebel units:** a grey stack with a torn banner and a pitchfork-and-scythe badge in the flat map style, so it reads apart from any country (not a raised fist, which is a modern symbol). Hexes under rebel control show hatching.
- **Revolt choice** (at 100 only, in the shared event pop-up frame; several revolts in one season share one pop-up): crush them (send troops, +weariness), buy them off (ducats, -20 unrest), or grant a local charter (the region pays no tax for 8 seasons, -30 unrest). The country tax is not touched.
- **Alerts:** "Revolt!" floating text, a log line, an "Independence movement in <region>" box.
- **Province panel:** "Rebels hold this land" with a hint to retake it.
- **Free state birth:** a banner with the region's name and flag colour.

Mockups needed:
1. The rebel stack and the hatching on the map.
2. The revolt choice pop-up.
3. The "Independence movement" and "free state born" banners.

### What the AI does
- Reacts to rising unrest: garrisons, lowers tax, builds a castle, brings the nearest army home; it puts revolts before foreign wars.
- A reborn free state plays like any country; its old master can try to take it back with a reconquest CB.
- Rebels follow a simple routine: seek the weakest held hex in their region, besiege, retreat from a stronger stack.

### Interactions
- **Debt:** the debt roadmap's warning stages include unrest; this meter is where that unrest goes. Unpaid troops desert as today.
- **War:** weariness adds unrest everywhere. Supporting rebels in an enemy country is a later feature.
- **Tech and ideas:** Statecraft techs and an idea card could lower the revolt chance.
- **Triangle trade:** its design wants unrest as one of the slave trade's costs; this meter is the hook.

### Risks
- **Free kills or endless nuisance.** Bands fade, stack size scales with unrest, strong stacks only at 100.
- **Cascades.** Unrest stays per region; a revolt adds only a flat +5 to neighbouring regions.
- **Pop-up fatigue.** The choice appears only at 100, at most one pop-up per season.
- **A crowded map.** `REBIRTH_COOLDOWN` and the movement threshold keep free states rare; the soak counts them.
- **Invariants:** a neutral `REB` controller and revived tags may break `tests/support/invariants.py`. Updating them is the first task of step 7.

### Smallest first version (C)
Rebel stacks owned by `REB`, spawning at 70+, taking control not ownership, fading. The revolt choice at 100. No movements or free states yet.

## 5. Ridges and passes as natural limits

Built today: crests block moves, supply, ZOC and roads except through passes, and passes close in winter. The roadmap's to-do list becomes:
- **Siege and supply:** a siege of land whose only approach is through a pass takes 1.5 times as long (`RIDGE_SIEGE_X`). Supply through a pass counts 2 steps.
- **Unrest:** `UNREST_RIDGE` when the way to the capital crosses a crest.
- **Peace cost:** `PEACE_COST_RIDGE_X` = 1.25.
- **AI basins:** a basin is land connected without crossing a crest. The AI scores a target in its own basin at 100% and across a crest at 60%, and crosses when the prize is worth it: a city, a pass fortress, a claim, or an ally's call.
- **Seas** count the same for home land: an island or land across a strait is "across" for reach and cost.
- **Map:** the Stability map mode shows basins faintly, so the player sees why the Po valley holds together.

Open choice: should the basin rule be a hard filter for the AI early on? Recommended: a soft weight only.

## 6. Fun and snowball checks

- **Conquest stays fun.** A won war gives a clear gain (a rich city, a port) and a clear job (a garrison, a court), shown before you sign.
- **A meaningful choice every few seasons:** which claim to buy, which war goal, how much to take at peace, how to answer a revolt, whether to join a coalition. None of the meters is set-and-forget: they move when you act.
- **A peaceful player is not punished:** home land has no foreign or conquest unrest; the meters run only when land changes hands, tax is high, or wars drag on.
- **A weak country** gets help from coalitions and claims.
- **Do not nerf the start.** Measured goal: from Europe 1480, the conqueror probe holds no more than about 1.5 to 2 times its starting land by 1650, and the biggest AI stays under 25% of all land.
- **Long runs:** no negative-treasury loop, no tag without a capital, no war with itself, no rebel stack with nowhere to stand.

## 7. How saves migrate

The save format has one version number, and missing fields take defaults (`saves.py`, `_migrate`). No version bump is needed if every new field has a default.
- `Province.gained: int = 0` (season taken; 0 = home land), so old saves start with no recent conquests and all land as home land.
- Region unrest lives in a world dict `unrest: {region: float}`, empty at load.
- `Country.infamy: float = 0.0`, `Country.weariness: float = 0.0`, `Country.start_land: int` (filled by `_migrate` from today's count).
- `War` gets `goal: tuple = ()`, `cb: str = "conquest"`, `score: float = 0.0`. An old war with no goal keeps today's rules and timers (16 seasons for the AI, 32 with the player) until it ends.
- World defaults: `relations`, `pacts`, `truces`, `claims`, `coalitions`, `movements`, all empty at load. `_migrate` seeds relations at 0 for neighbours.
- The `REB` tag is added to the countries on first use; older saves load without it.
- Test: `tools/save_compat.py` loads a save from the last release and plays a season (it runs on every pull request that touches the campaign code).

## 8. Build plan

This follows the structure rules in CLAUDE.md. `hexa/campaign/systems/`, `systems/season.py` `PHASES` and `WORLD_CACHES` arrive with the architecture refactor, so this package starts after those phases land, and after the open bug list is empty.

New system modules, each with an `OWNS` list, `x_check`/`x` pairs, facades on `CampaignWorld`, pairs in `tests/support/agents.py`, numbers in `data.py` (including today's `MAX_WARS`), README rows and bus events. No change of existing behaviour without a switch in the same PR.

| Module | Writes (OWNS) | Does |
|---|---|---|
| `campaign/systems/stability.py` | `unrest`, `Province.gained`, `Country.weariness` | unrest sources, reach field, home land, weariness, thresholds |
| `campaign/systems/diplomacy.py` | `relations`, `pacts`, `truces`, `claims`, `Country.infamy`, `coalitions`, `War.goal/cb/score` | CBs, claims, war goals, war score, peace cost, alliances, coalitions |
| `campaign/systems/rebels.py` | rebel units, `movements`, free-state creation | spawn, behave, independence |

Season order (in `PHASES` only): `stability` after economy and before collect, so tax uses the new share; `diplomacy` after sieges (scores, coalitions, truces); `rebels` after stability.

Steps (each one PR and one gameplay change, behind a switch until tuned):
0. **Probes, no behaviour change.** The conqueror player in `tests/support/agents.py`; a land-share measurement over a full 680-season game; invariants for the new fields. Re-run the table in section 1 as the baseline.
1. **Stability, read-only.** Unrest, reach, home land and weariness computed and shown (panel hover, Stability map mode), with no effect. Mockups A1 and A2 approved first.
2. **Stability with effects.** Tax share, recruit block, thresholds, garrison and castle effects. Tuned with the probe. README table.
3. **Diplomacy core.** Relations, truces, claims, war goals, war score, the peace-cost menu (replacing `peace_offer` and the timers), AI uses claims. Mockups B1 to B4.
4. **Infamy and coalitions.** Mockups A3 and A4.
5. **Alliances.** Pacts, call to arms. Mockup B5. City-state protection and leagues can follow here.
6. **Ridges.** Siege, supply, peace cost, unrest and AI basins.
7. **Rebels, slice 1.** `REB` tag, stacks, control, the revolt choice, AI reaction. Mockups C1 and C2. Invariants first.
8. **Rebels, slice 2.** Movements, free states, rebirth. Mockup C3. Regions for random worlds before this step, or Europe only.
9. **Throne claims** (table), then balance: full seeded runs (Europe and random) plus the probe, and a fun test written up for the owner.

Timing: steps 0 to 4 are the steamroller fix; 5 to 9 the richer diplomacy and rebels. It fits the balance pass (M4). The debt design's bankruptcy pop-up and the events system share the revolt choice's pop-up frame.

New bus events (in the `hexa/events.py` docstring; handlers never change the world): `unrest_rising`, `revolt`, `rebels_defeated`, `independence`, `claim_made`, `pact_made`, `pact_broken`, `call_to_arms`, `coalition_formed`, `coalition_ended`. `war_declared` and `peace_made` gain the CB and the goal.

## 9. Tests to write
- Unrest sums: each cause alone, then together; the conquest bump decays to zero in 20 seasons; home land after `HOME_SEASONS`.
- No penalty at the start: on turn 1 every country's tax share is 100% and unrest is near 0.
- Reach: the distance field never crosses a crest except at a pass, and a closed winter pass lengthens it.
- Peace cost: a claimed town across a crest costs the stated amount.
- Coalition: opens above `COALITION_AT`, closes under `COALITION_END`, never includes an ally.
- Rebels: a stack spawns at 70+ and never at 40; control returns to the owner on retake.
- Conqueror probe: land share by 1650 within the target band.
- All-AI soak (Europe and random): no invariant breaks, few free states, no endless war.
- Save: an old save loads and plays (save-compat).

## 10. Risks of the whole package
- **Too much at once.** Keep the three slices, and keep the first measurable.
- **Too many meters.** The player sees unrest, infamy and weariness, each as one bar with one hover, and every cost before the action that causes it.
- **The AI goes passive.** Wars per 100 seasons in the soak should not fall below today's level, and the map should move a little (a few regions per decade).
- **Measured on 40 of 170 years only.** The baseline must be re-run over a full game before tuning.
- **Random worlds have no regions** (every hex has an empty region name). Regional unrest, home land and free states need generated regions there, or they fall back to clusters around towns. Needs its own small design.
- **Performance.** The reach field and relations are recomputed on ownership or building change only, in a listed cache.
- **Sensitive topics.** Rebels and conquest are shown as costs, not trophies: no achievement or reward text celebrates crushing a revolt (the achievements design's taste rule). The New World is out of scope: native resistance belongs to the tribal nations design, not to the `REB` rebels, and "no infamy for colonies" is a placeholder for that design, not a statement that the land is empty. Colonial independence is after 1650 and out of scope.

## Creative director review (2026-11-12)

**Verdict: ready for the owner, with the changes made in this pass.** The package fits the vision: it gives the long campaign a reason to grow carefully, makes ridges matter in play, and turns war into decisions (claim, goal, peace menu, revolt choice). Changes made: corrected today's peace and timer rules (player wars end with each side keeping what it occupies; AI wars end at a score of 5); stopped the brakes from punishing the 1480 map (the national cap counted Muscovy's 637 hexes against a cap of 60, so it would have lost its whole tax on turn 1; now home land and only land gained count); moved unrest from hexes to regions, since 87% of hexes are empty; added costs for empty land; shown every cost before the war or peace that causes it; linked the debt, city-state and battle designs; added the random-world and New World gaps.

Weigh most:
1. **Unrest per region and home land** (questions 3 and 4). They decide whether the brakes feel like geography or like a tax on the starting map.
2. **Soft coalitions against the player too** (question 6). This is the main brake on a human, and the main risk of feeling punished. The warning at 60% and the infamy shown on the peace screen are what keep it fair.
3. **Scope.** Steps 0 to 4 already fix steamrolling. Rebels slice 2 (free states) needs regions on random worlds and should not block the rest.
