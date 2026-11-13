# War goals and peace: design proposal

Status: DRAFT for the owner (2026-11-13). Nothing here is approved or built. It is one of three separate designs that came out of `stop-steamrolling.md` (brakes, war goals and peace, rebels). This one stands on its own: it works with no brakes and no rebels, and leaves hooks for both. It is built after the battle system v0.2.0 (see the roadmap, "Next up").

## Questions for the owner

1. **How big may a war with no reason (a "plain conquest") be?** A goal is the land the attacker may take cheaply. Options: (a) the 12 enemy hexes nearest to a chosen anchor hex, anything beyond costs double; (b) a whole historical region; (c) no limit, everything costs the same. Recommended: (a). It keeps the player picking a target, works on random worlds (they have no regions) and stops one war from eating a country. Claims later give the bigger, whole-region goals.
2. **Can the capital change hands?** Today the capital always goes back. Options: (a) it can be bought for 40 score, only while the winner holds it; (b) never, so no country can be wiped out by peace; (c) only as the last lot. Recommended: (a). Holding the enemy capital is then the big prize the owner asked for, and a country can still die.
3. **May the defender take land when it wins?** Options: (a) yes, any attacker hex it holds is "in the goal" for the defender, so a counter-invasion pays; (b) the defender gets only white peace and ducats. Recommended: (a). Otherwise attacking is free of risk.
4. **What does surrender cost?** Today the winner takes everything it holds. Options: (a) the loser gives the war goal and 20% of its treasury, nothing else; (b) keep today's rule. Recommended: (a). Surrender becomes a real choice: give the goal now, or fight on and risk more.
5. **Does the peace screen sell land by block ("lot") or by single hex?** A lot is the hexes that belong to the same enemy settlement. Recommended: lots, with a hex-by-hex view for the picky. One province is one hex and 87% of owned hexes are empty, so hex-by-hex means hundreds of rows.
6. **Does the AI keep its 12% roll to start a war?** Options: (a) keep the roll (every 8th season) but give each war a goal and a reason, and end wars by terms; (b) a desire score for every neighbour. Recommended: (a) first, to keep today's world pace, and move to (b) only if the soak shows a flat world.

Decided already (owner, 2026-11-13, in `stop-steamrolling.md`): wars end by peace terms with a 40-season safety timer only; allies may refuse a call to arms at a cost in relations (later work); a small table of historical claims after the core, personal unions later; coalitions form against anyone, the player included (brakes design, hook below).

## 1. What happens today (checked in the code)

- **Declare war** (`war.declare_war`, `war_check`): allowed on any living neighbour you are not at war with. No reason, no goal, no truce, no allies. `War` holds only `a`, `b`, `start`.
- **War score** (`war.war_score`): your hexes held by the enemy's army subtract, the enemy hexes you hold add, +3 if you hold their capital. An empty hex counts like a city.
- **Player peace** (`war.peace_offer`, buttons in `panels/country.py`): "take" is accepted at score 3 or more, or at 1 or more when their army is not stronger. The winner then gets every hex it holds; the capital returns. "White" needs score -1 or better and 4 seasons of war. "Yield" is always accepted and the enemy takes everything it holds.
- **Timers** (`season.war_timeouts`): a war ends at 16 seasons (`WAR_LENGTH_AI`), 32 if the player is in it. Between two AIs it also ends at once at a score of 5 either way. A player war that times out lets **each side keep what it holds**.
- **AI** (`ai._diplomacy`): every 8th season a country at peace with over 100 ducats and 2 or more army strength rolls 12%, then attacks a random neighbour whose army is under 1/1.8 of its own. At most `MAX_WARS` = 3 wars in the world (a constant in `ai.py`). The AI **never offers peace to the player** and never asks for it. AI armies (`ai._campaign`) go for the nearest enemy hex, not for a purpose.
- **Peace** moves land only by `peace()`: hexes held change owner, held units are moved home, markets refresh.
- **Battle:** today's battle is one strike; the battle design (v0.2.0) replaces it with multi-season battles with killed, wounded and morale.

Consequences: the cheapest hex and the richest city count the same; a winning player never chooses what to take; an AI never ends a war because it got what it wanted; there is no truce, so wars chain.

## 2. Goal

War gets a point. The attacker names **what it wants** (a war goal) and **why it may** (a casus belli). Fighting earns **war score** from land held, battles won and the enemy capital. At peace the winner **spends the score** on a menu: land in the goal is cheap, other land is dear, ducats cost score too. The fun is in the choices: which target, which fights are worth it, take the sure small prize now or push for a city.

Real history behind it: wars were fought for a prize (the Italian Wars for Naples and Milan, the Hundred Years' War for a crown), and treaties traded a province, a payment, a marriage. A truce followed most treaties. The 1480 to 1650 feel is the Treaty of Cateau-Cambresis, not total conquest.

## 3. Rules

All numbers live in `data.py` (names proposed in section 4). Distances scale with `SCALE`.

### 3.1 Casus belli and war goal

A war has one **casus belli (CB)** and one **goal**, both fixed at the declaration. The goal is a set of enemy hexes.

| CB | Allowed when | Goal | Notes |
|---|---|---|---|
| **Conquest** | any neighbour, no truce | the `GOAL_HEXES` (12) enemy hexes nearest to an anchor hex the attacker picks, connected to it | the core CB |
| **Reconquest** | the target holds hexes that were yours, lost within `RECONQUEST_SEASONS` (80) | those hexes (at most `GOAL_HEXES_MAX`, 30) | needs `Province.former_owner` |
| **Claim** (after the core) | a row of the claims table fits (section 3.9) | the whole claimed region | Europe map only |
| **Contain the aggressor** | (hook) a coalition from the brakes design | like Conquest | the brakes design adds it; no infamy |

Cut from the first version: Humiliate (gold, no land), Defence (needs alliances), liberation (needs free states, the rebels design). Each can be added as one row.

- **Defender:** has no declared goal. Any attacker hex it holds counts as "in its goal" (question 3).
- **Anchor:** the attacker clicks an enemy hex; the dialogue shows the goal outlined on the map and its price in score.
- **Checks:** `war_check(world, a, b, cb, anchor)` returns `(ok, reason)`: not a neighbour, already at war, **truce for N more seasons**, anchor not an enemy land hex, CB not allowed, first 8 seasons of the game (AI only), world cap on wars (AI only).
- **Colonies and trading posts** count as settlement level 1 for score and cost. They are never the anchor of a goal in the first version (colony rules decide their fate; see the colonisation and tribal nations designs).

### 3.2 Worth of a hex

Each enemy hex has a **worth** in score points, by settlement level (`Province.settlement`: 0 empty, 1 village, 2 town, 3 city):

`PEACE_COST_BY_LEVEL = (1, 4, 8, 15)`, and the capital hex adds `PEACE_COST_CAPITAL` (40).

A castle adds `PEACE_COST_CASTLE` (2 per castle level) so a fortress hex is not the same as an empty one.

### 3.3 War score

The war panel shows one bar from -100 to +100, **net score** of a side = its gross score minus the enemy's gross score. Gross score of a side (capped at `WAR_SCORE_MAX` = 100):

- **Occupation:** the worth of every enemy hex the side controls (`Province.controller`, set by siege or storm as today). It is live: lose the hex and the points go.
- **Battles:** points for each battle won, from the battle results (3.4). They stay.

The side with the positive net can spend that net on peace terms. A side at zero or below can only ask for white peace or give up.

Reading it: an attacker holds a city (15) and 6 empty hexes (6) and won two battles (8): gross 29. The defender holds 4 of the attacker's empty hexes and won one battle (5): gross 9. Net is +20 for the attacker.

- (2026-11-13) `battle_ended` also carries `name` ("Battle of X") and `year`, for the log and the peace screen.

### 3.4 Battles and the war score

The battle system (v0.2.0) leaves war score out of the battle code on purpose. This design reads **one event** at the end of each battle, `battle_ended`, and the battle build must emit it with these fields: the two tags, the hex, the **winner** (the side whose army did not break, withdraw or get destroyed; a draw has no winner, how `peace` or `gone`), men **killed** and **wounded** per side, and whether the fight was a castle assault. Rules:

- The winner gets `BATTLE_SCORE_WIN` (2) + `BATTLE_SCORE_PER_1000` (1) per 1,000 enemy men killed + half that per 1,000 wounded.
- At most `BATTLE_SCORE_CAP` (25) battle points per side per war, so a war of battles alone cannot buy a city.
- A drawn or ongoing battle gives nothing: a draw has `winner` None (how `peace` or `gone`), so no score is booked. A battle in the winner's own land counts the same.
- (2026-11-13) A side destroyed in the fight (how `destroyed`: no regiment or garrison left after a day) is the loser and the other side the winner, so the winner is booked. `gone` is a side that vanished between seasons (desertion, starvation, disbanding, peace): a draw.
- Taking a castle by storm or siege is occupation, not battle points.
- The war stores `battle_a` and `battle_b` (floats).

If this design were built before the battle system, the stand-in is today's `battle` event: 1 point per enemy unit lost. Do not ship that; build after v0.2.0.

### 3.5 Battles and the capital

- Holding the enemy capital gives its worth (a capital hex 40 plus its own level).
- An enemy-held capital makes the AI much more ready for peace (section 7). No other effect is added.
- If the capital is bought in the peace menu, `check_alive` already moves the loser's capital to its biggest remaining province. The country dies only if it has no hex left.
- A capital can be bought only while the winner **holds it** (question 2).

### 3.6 The peace menu

Peace is made from the **winner's** side (net score above zero); the loser can accept or refuse. The menu items and prices (in score points):

| Item | Price |
|---|---|
| A hex, or a lot (a block of hexes of one enemy settlement), **in the goal** | worth x 1.0 |
| Land **outside the goal** | worth x `PEACE_COST_OUTSIDE_X` (2.0) |
| Land **held by the winner's army** | x `PEACE_COST_HELD_X` (0.5) on top of the above |
| Land across a crest from the winner's land | x `PEACE_COST_RIDGE_X` (1.0 now; 1.25 when the ridge work lands) |
| **Ducats** from the loser's treasury | `TRIBUTE_PER_POINT` (12 ducats) per point, at most the loser's treasury |
| **Return** a hex the winner lost | free (it gives up nothing) |

- **Total price** must be at most the winner's net score. The screen shows the running total.
- **Held and outside the goal** costs 2.0 x 0.5 = 1.0 x worth, which is exactly the score that hex gave. So "take what you hold" is always paid for by the score it earned (less what the enemy earned). **Held and in the goal** costs half: the reward for holding the prize.
- **Lots:** a lot is the enemy hexes nearest to the same enemy settlement (path distance, capped at `LOT_RADIUS`, 6 hexes), with hexes of no settlement joined to the nearest. A country with no settlement is one lot per `LOT_RADIUS` block. The lot is labelled by its settlement or, on the Europe map, by its region name. A lot is bought whole or in single hexes through a hex-by-hex view. This works on random worlds, which have no regions.
- **Terms are a list**, so later items (a marriage, a vassal, open ports, a pact break) can be added as rows.
- **Not bought:** every enemy hex the winner holds that is not in the deal goes back to its owner (as `peace()` does today).
- **Units** on land that changes hands are moved home or lost, as today.
- **Winner at war with two countries:** each war has its own score and menu.

Worked examples (starting numbers): a town across a crest (later), outside the goal and not held: 8 x 2.0 x 1.25 = 20. A town in the goal, held: 8 x 1.0 x 0.5 = 4. A goal of 1 city, 2 villages and 9 empty hexes is 32, or 16 if all are held. A plain conquest of that goal needs about 16 held-score and a battle or two. The capital in the goal and held costs 40 + its level, halved, so it is a big prize but not free.

### 3.7 White peace, surrender, truce

- **White peace:** everything goes back to its owner and no one pays. The side asking has no condition, but the other side accepts only if its net score is **at most `WHITE_PEACE_MAX_NET` (10)**, and the war has lasted `MIN_WAR_SEASONS` (4). Truce `TRUCE_WHITE` (8).
- **Surrender:** the surrendering side gives the **war goal** to the enemy (as the defender: the attacker's goal; as the attacker: nothing, but it pays) and `SURRENDER_TRIBUTE_SHARE` (20%) of its treasury (not below 0). Always accepted. Nothing else changes hands, so the winner does not get everything it holds (question 4). Truce `TRUCE_TERMS`.
- **Terms peace:** truce `TRUCE_TERMS` (12 seasons, 3 years).
- **Truce:** while it lasts, neither side can declare war on the other and the declare button says "Truce for N more seasons". It stops nothing else. A truce cannot be broken in the first version (breaking one is an infamy topic for the brakes design).
- **Truce data:** `world.truces = {(a, b): end_turn}`, with a and b sorted. Expired entries are dropped each season.
- **No haggling.** The loser accepts any deal the score pays for, and refuses any it does not. The screen says which, before sending.

### 3.8 Safety timer

- A war that reaches `WAR_TIMER_SAFETY` (40 seasons, 10 years) ends in **white peace**: every hex goes back, truce `TRUCE_TIMER` (8). It replaces `WAR_LENGTH_AI`, the 16/32 timers and the "score 5" auto end.
- At 32 seasons the player gets a toast ("This war ends in 8 seasons with white peace"). The AI does not need it: it ends wars long before (section 7).
- If a country has no hex left, the war ends with the country (as today in `check_alive`).

### 3.9 Claims (after the core)

A small table, in a data file, of historical claims, for the Europe map only. Each row: claimant tag, region (the `Province.region` name), start year, end year, a short reason ("Crown of Naples", "Duchy of Burgundy"). Examples to start from, to be checked by a history pass: France on Naples and Milan (from 1494), England on Normandy and Guyenne, Castile on Navarre, Burgundy-Habsburg on Burgundy, Poland-Lithuania on Livonia, Muscovy on Novgorod's old lands. About 20 rows.

- A claim is active when the claimant exists, the region still belongs to someone else, and the year is in range.
- The claim CB gives the **whole region** as the goal and, when the brakes design exists, no infamy.
- Claims can also be bought with ducats (`CLAIM_COST`) for a region next to your land. This is a later add and not in the first claims build.
- Personal unions (a throne passing to a ruler) are out of scope.

### 3.10 What stays out

- **Allies:** a war is two principal countries (`War.a` and `War.b`). The alliance design (later) adds sides, the call to arms (the ally may refuse, relations drop) and per-ally peace. This design keeps peace in one function, `peace_make(world, war, terms)`, so a war with more members changes one place.
- **Vassals and tribute that repeats**, marriages, trade-right terms: later rows of the terms list.
- **Naval blockades** as score: later, with the naval design.

## 4. Numbers to start from (`data.py`)

All names are proposals. Tune with the soak (section 9).

```
# War goal and score
GOAL_HEXES              = 12      # plain conquest: enemy hexes in the goal
GOAL_HEXES_MAX          = 30      # reconquest cap
RECONQUEST_SEASONS      = 80      # a lost hex stays a reconquest goal this long
WAR_SCORE_MAX           = 100     # gross score cap per side
PEACE_COST_BY_LEVEL     = (1, 4, 8, 15)   # per hex: empty, village, town, city
PEACE_COST_CAPITAL      = 40
PEACE_COST_CASTLE       = 2       # per castle level
PEACE_COST_OUTSIDE_X    = 2.0     # land not in the goal
PEACE_COST_HELD_X       = 0.5     # land the winner's army holds
PEACE_COST_RIDGE_X      = 1.0     # 1.25 when the ridge work lands
LOT_RADIUS              = 6       # hexes a settlement's lot reaches
TRIBUTE_PER_POINT       = 12      # ducats per score point
# Battles (read from the v0.2.0 battle_ended event)
BATTLE_SCORE_WIN        = 2
BATTLE_SCORE_PER_1000   = 1       # per 1,000 enemy killed; wounded count half
BATTLE_SCORE_CAP        = 25      # per side per war
# Ending a war
MIN_WAR_SEASONS         = 4       # before white peace
WHITE_PEACE_MAX_NET     = 10      # the other side's net must be at most this
SURRENDER_TRIBUTE_SHARE = 0.2
TRUCE_TERMS             = 12      # 3 years
TRUCE_WHITE             = 8
TRUCE_TIMER             = 8
WAR_TIMER_SAFETY        = 40
WAR_TIMER_WARNING       = 32
# AI
MAX_WARS                = 3       # moved from ai.py
AI_FIRST_WAR_SEASON     = 8       # no AI war before this
AI_GOAL_MAX_COST        = 60      # the AI will not aim at a bigger goal
AI_GREED_MARGIN         = 15      # extra net it wants beyond the goal before signing
AI_STALL_SEASONS        = 6       # no score change this long: it signs what it can
AI_SUE_NET              = -25     # a loser at or below this asks for peace
AI_STALEMATE_SEASONS    = 12      # war this long with a flat score: it offers white peace
AI_DEMAND_COOLDOWN      = 4       # seasons before it asks the player again
OFFER_SEASONS           = 2       # an offer to the player lapses after this
```

Reading the numbers: a typical goal (32 worth) is a few villages and a town, and takes a few seasons of occupation. A 100-score war is a long, winning war. The cap on battle points (25) means the siege and the march, not luck in one fight, decide the result.

## 5. What the player sees

Mockups first; none are made yet. The pop-up frame is the event frame of `docs/design/ui/15_event_popup_frame.png`; buttons and panels come from the UI kit.

### Declare-war dialogue
Opened from the country panel or by clicking a neighbour's hex. Shows the target, a CB list (greyed rows say why on hover: "No claim", "Truce for 7 more seasons"), the goal outlined on the map with a hex count and its price ("Goal worth 32"), and a "Declare war" button. Cancel leaves nothing changed. A line is reserved for the infamy the brakes design will fill ("Infamy +0" is not shown until that design exists).

### War score bar
In the country panel's war section and in a small chip near the top bar while at war. A tug-of-war bar from -100 to +100 with the net number. Hover shows the breakdown: "You hold 17 worth (+17), battles won +8; they hold 4 (+4), battles +5". Goal hexes get a coloured outline on the map; hexes you hold get a hatched edge. A "war is old" toast at 32 seasons.

### Peace screen
Replaces the three peace buttons. A screen (not a tiny panel) with:
- the header: you and them, the bar, seasons of war, the CB and the goal;
- the list of **lots** (the goal first), each with its name, hexes, worth and price (struck down to the half price if held), a checkbox, and a hex-by-hex view;
- a ducats slider;
- a running total against the net score and one answer line ("They accept", or "They refuse: costs 41, you have 35");
- buttons: **Best deal** (fills the goal, then the best value for the rest), **Send**, **White peace**, **Surrender**, Back;
- a reserved row for infamy and unrest (brakes), blank until they exist.

### Alerts
- "X asks for peace": a pop-up when the AI loser sues (it opens the peace screen).
- "X demands: Navarre (6 hexes), 40 ducats": a pop-up with Accept and Refuse and an Open-screen link; a lapse after `OFFER_SEASONS`.
- Truce chip in the country panel with seasons left; "Truce ends" log line.
- Log lines for peace carry the CB and what changed hands.

### Mockups needed
1. Declare-war dialogue with the goal outlined on the map.
2. War score bar, chip and hover breakdown; the goal and held hexes on the map.
3. Peace screen with lots, the total and the answer line (a winning case and a losing case).
4. AI demand and "asks for peace" pop-ups in the event frame.
5. Country panel: truce chip and the disabled declare button.

## 6. Interactions

- **Economy:** tribute moves ducats; never more than the loser's treasury, so it cannot create debt. Ownership changes already refresh markets and the cache (`changed(ownership=True)`).
- **Battle (v0.2.0):** the `battle_ended` event feeds the score (3.4). Battle code does not know war score. A retreat from the field is a loss for the score.
- **Tech:** a Statecraft tech could cut `PEACE_COST_OUTSIDE_X` slightly or raise `GOAL_HEXES`; place it in the tech tree later.
- **Debt:** a country in the debt stages cannot declare war (hook, `war_check`); a lender's claim as a CB waits for the debt design.
- **City states:** protection and leagues wait for alliances.
- **Brakes (later):** four hooks. (1) `peace_infamy(world, tag, terms)` returns 0.0 and the screen has a row for it. (2) When a hex changes hands, set `Province.gained = turn` (the brakes design reads it). (3) The CB table has a slot for "Contain the aggressor". (4) The AI reads `country.weariness` with `getattr` and treats missing as 0.
- **Rebels (later):** none needed; they read `Province.gained` and `former_owner`.
- **Alliances (later):** `peace_make` takes the war, so it can add sides; `War` keeps `a` and `b` as principals.
- **Achievements:** no text that celebrates conquest as a trophy (the achievements design's taste rule); log lines state facts.

## 7. What the AI does

### Starting a war (replaces the target choice, keeps the roll)
Every 8th season, 12% roll, treasury over 100, army strength at least 2, no war running, world under `MAX_WARS`, game past `AI_FIRST_WAR_SEASON`, as today. Then, for each neighbour out of truce:
- Pick the best CB: Reconquest if it has lost hexes there, then a claim (later), then Conquest.
- Pick an anchor: the enemy lot with the best (worth / distance from its own land), keeping the goal's price at most `AI_GOAL_MAX_COST`. Cities, castles and ports raise the value.
- Attack only if its army is still above 1.8x the target's (today's test).
- It stores the goal on the war; its armies prefer **goal hexes** over the nearest enemy hex when they choose a siege target (`ai._campaign`: goal hexes first, then today's rule).

### Making peace (replaces the timers)
Each season, for each war it is in (AI plays in tag order, before `end_round`):
- **Winning (net at or above the price of the goal):** signs when the goal is held, or net is at least goal price + `AI_GREED_MARGIN`, or the score has not moved for `AI_STALL_SEASONS`. The deal is the goal first, then extra lots by best worth per score until the net is spent; ducats last.
- **Short of the goal:** after `AI_STALL_SEASONS` without change, and net above 10, it takes the best partial deal.
- **Losing:** at net `AI_SUE_NET` or worse it asks for peace. Against an AI winner, the winner's deal is applied. Against the player, a "X asks for peace" pop-up appears, once per `AI_DEMAND_COOLDOWN`.
- **Stalemate:** a war of `AI_STALEMATE_SEASONS` with net inside plus or minus 10 and no change gets a white peace.
- **Capital held by the enemy:** the AI treats its net as 15 worse for the "losing" test.
- **Against the player:** if the AI is winning and its goal is affordable, it sends a **demand** (a deal worth its net). The player may refuse; nothing is forced. It asks again after `AI_DEMAND_COOLDOWN` only if its net has risen.
- AI-to-AI deals apply at once; no one haggles.

### Accepting
The AI as the loser accepts a player deal when the price is at most the player's net (as the screen says). As the winner it never accepts a worse deal than the score allows. It refuses white peace while its own net is over `WHITE_PEACE_MAX_NET`.

### Risks for AI behaviour
It must not go passive or loop: the soak counts wars started and ended per 100 seasons and compares them with the baseline of section 9.

## 8. Save compatibility

The save format has one `VERSION`; missing fields take defaults (`saves.py`, `_migrate`, `fill_defaults`). No version bump if every new field has a default.
- `War` gets `cb: str = "conquest"`, `goal: tuple = ()`, `anchor: tuple = ()`, `battle_a: float = 0.0`, `battle_b: float = 0.0`. An **old war loads as a conquest with an empty goal**: all land costs the outside price, so the same code runs and there is no second rule set. Its timer counts from its `start`, so a war older than 40 seasons ends at the first season after loading with white peace.
- `Province.former_owner: str = ""` and `Province.gained: int = 0`, both set when a hex changes hands (empty on old saves).
- World: `truces: dict` and `offers: list`, both default empty, listed in `WORLD_DEFAULTS` and in the module's `OWNS`. Derived caches (lots, goal prices, score) go in `WORLD_CACHES`, keyed on `world.version`, never saved.
- `peace_offer` keeps its name and signature for the old callers (the UI and the random players in `tests/support/agents.py`) for one release, as a thin wrapper that builds a "best deal" or the white/surrender terms, then is removed with the screen's arrival.
- Test: `tools/save_compat.py` loads a save of the last release, with a running war, and plays a season; the war ends by the new rules without a crash.

## 9. Smallest first version

Worth shipping, after battle v0.2.0:
- Conquest CB with an anchor and a 12-hex goal; the dialogue with the outlined goal.
- War score from occupation, battles and the capital; the bar.
- The peace screen with lots, ducats, white peace, surrender and truces, the answer line and Best deal.
- The 40-season safety timer replacing every old timer.
- AI that chooses a goal, aims at it, signs by terms, sues for peace, demands, and lets the player refuse.
- Defender's rights (question 3).

Not in it: reconquest, claims, alliances, infamy, hex-by-hex view (lots only first), the ridge multiplier.

## 10. Build plan

New module `hexa/campaign/systems/peace.py` (goals, score, lots, terms, truces, the season's war end); it imports down only. `war.py` keeps fighting (`declare_war` and `war_check` move their checks to it with a facade; the old `war_score`, `peace` and `peace_offer` become thin wrappers then go). `season.py` `PHASES`: `war_timeouts` becomes `peace.war_ends` in the same slot. Pairs for `tests/support/agents.py`: `war_check`/`declare_war` with the new arguments, `peace_check`/`peace_make`. Numbers in `data.py`, a README table, new events: `war_declared` gains `cb` and `goal`, `peace_made` gains the terms, plus `truce_started`, `peace_offered`.

0. **Baseline, no behaviour change.** Measure with seeded all-AI games (Europe and two random worlds, 160 seasons) wars started per 100 seasons, how long wars last and how much land moves, so section 7's "not passive" can be checked. Check what `battle_ended` needs in the battle build and agree its fields.
1. **State and score, read-only.** `War` fields, `Province.former_owner/gained`, worth, goal selection, the new score computed beside the old and shown in the panel. Mockups 2.
2. **Peace engine.** `peace_check`/`peace_make`, truces, lots, the safety timer, the wrapper for old callers; old timers removed. Behind a switch until step 4 passes the soak.
3. **Player screens.** Declare dialogue and peace screen. Mockups 1, 3, 5.
4. **AI.** Goal choice, goal-first sieges, signing, sueing, demands. Mockup 4. Then the soak.
5. **Battle score.** Wire `battle_ended`. (Do this inside step 2 if v0.2.0 has landed.)
6. **Reconquest CB.**
7. **Claims table and the claim CB** (after the core), history check of the rows.
8. **Balance:** full seeded runs, then a written fun test for the owner.

Each step is one PR with one gameplay change.

## 11. Tests to write

- Worth and price: the worked examples of 3.6 give the stated numbers.
- Net score: a held city plus two battles gives the right number; losing a held hex lowers it; the cap holds.
- A deal above the net is refused, and `peace_make` changes nothing then; at or below, it succeeds (the `*_check` contract).
- Land not in the deal returns to its owner; units on moved land go home.
- Capital buyable only when held; a country with no hex left dies.
- Truce blocks `war_check` both ways and expires.
- White peace needs 4 seasons and a low enemy net. Surrender gives the goal and 20% of the treasury.
- Safety timer: a 40-season war ends in white peace; an old save's war does too.
- Ducats never exceed the loser's treasury.
- AI: signs when the goal is paid, sues when losing, demands the player can refuse, makes a white peace in a stalemate; never starts a war in a truce or before season 8.
- Soak (Europe and random): no invariant breaks, no war over 40 seasons, wars per 100 seasons not below the step 0 baseline by more than a third.
- Save-compat as in section 8.

## 12. Risks

- **Score is fungible.** Many held empty hexes can buy a city outside the goal at double price. Accepted: it costs effort and the held-empty-land route is slow. Watch in the soak.
- **A spreadsheet screen.** Lean on Best deal and the goal-first order; the player can win with two clicks.
- **The AI goes passive** or loops on demands. Cooldowns, the soak baseline and a cap of one pop-up per season.
- **Pop-up fatigue.** At most one AI offer pop-up per season, folded into the event frame; lapses by `OFFER_SEASONS`.
- **Snowball.** Peace is the thing that decides conquest speed now. Plain conquest is capped at 12 hexes at the cheap price, and the truce (12 seasons) stops chains. The brakes design adds the real cost of size; without it a patient player can still take a country in a few wars. This design does not fix steamrolling alone, and says so.
- **Island and distant wars** may never produce score; the stalemate peace and the 40-season timer end them.
- **Random worlds** have no regions: goals and lots use hex distance and settlements, so they work; claims are Europe only.
- **Battle dependency.** If v0.2.0 slips, the score has no battle part; occupation alone still works.
- **Invariants.** A hex changing hands in peace must keep the existing guarantees (a capital for every tag, no unit on foreign land at war's end); the invariant checkers get the new fields in step 1.
- **Sensitive topics.** The log states what changed hands, not triumph. Colonies and native land are out of scope.
