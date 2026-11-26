# Moves in the month (issue 432)

Status: draft for the owner. Written 2026-11-24 by the game designer from the M6, M7 and M8 build specs and the UI family
audit (no code was read or run). Nothing here is built. Where a number is named it is a data value, not a constant in code. The owner's answers of
2026-11-24 and 2026-11-25 are in the last section; where a section above says otherwise, the answers win.

Words: the game calls one turn a "season". The owner says "month". This page says "season" and means the same thing.

## 1. What the owner asked, and what changes for the player

**The ask (decision of 2026-11-23):** when you pick where an army goes, it moves **at once**, in the season you are playing,
and the move is **final**: no undo.

**Today:** picking a destination only stores a march order. Nothing moves. You press End turn; then the computer's
countries give their orders, then every army walks together ("the movement phase"), then you watch the walks replayed. You
learn what happened only after the season is over.

**After this change:** the army walks the moment you click. You watch it go, you see what it sees on the way, and if it runs
into an enemy army the battle opens right there. You decide the next move knowing the result.

**What the player feels:**
- A turn becomes a sequence of small decisions with answers, instead of a batch of orders handed in blind. This is the
  "I move, I see, I move again" feel of a board game.
- Moves have weight. Because there is no undo, you think before you commit, and the map shows you what a move will cost
  before you do (section 2.9).
- You can no longer scout with an undo (send a rider to look, then pretend you did not). A look costs movement points.
- The computer's countries still act after you press End turn. So in every season **you move first, they answer.**

**An example season turn (north Italy, Spring 1481, Savoy):**

1. Your Army of Turin (pikemen, 12 movement points) stands at Turin. Milan is at war with you; its army was last seen near
   Alessandria, five hexes east.
2. You pick Vercelli (two hexes east on farmland and a road). The preview says "Walks 2 hexes, costs 4 of 12 points. Stands
   in supply." You click. The army walks now, the token slides over the two hexes, the new hexes it sees are lit. It has 8
   points left.
3. From Vercelli your sight shows Milan's army in Novara, three hexes on. You decide not to charge (the odds card says
   "Even"). You pick the small hill at Cerano, 2 points. It walks. 6 points left.
4. You raise two more companies at Turin. They cannot move this season (they are mustering, as today).
5. You press End turn. Milan's seat plays: it sees your army at Cerano and orders its own army to attack. The two meet at
   Cerano. A battle opens, and you are shown the board (the round-by-round board of the UI audit) because you are a side of
   it. After the battle the season's other phases run and the report shows.

Compare today: steps 2 and 3 would have been two stored orders, step 5 would have been one blind walk, and Milan would have
walked at the same moment, possibly past you.

## 2. The model

### 2.1 What exists today (M6, M7, M8)

- Every kind of company has **movement points** a season (pikemen and crossbowmen 12, knights 16, bombards 8). An army uses
  the lowest of its companies. Every hex step costs points by ground, road, river and season (a farmland step 2, woods 3,
  a snow peak 6 plus relief, a road caps a step at 2, a highway at 1).
- An army's **march** is a route to a **goal** that can be up to 12 seasons long. Each End turn the movement phase walks one
  "leg": as many steps as the points allow. What is left over is lost.
- Armies of all countries walk together, step by step in "ticks" (all armies take their first step, then all the second...),
  so two armies racing for one hex are settled by the tick, then by army number.
- A battle starts in that phase when an army steps onto an enemy army, and is fought in the next phase (the battles phase).
- The computer's orders are given at the **start** of End turn (the `ai_orders` phase, seats one after another, the first
  seat rotating each season), and executed by the same movement phase.

### 2.2 The new rule in one line

**One allowance of movement points per army per season. The player spends it at once, move by move. Whatever the player
does not spend is spent in the movement phase of End turn by the army's standing march, if it has one.**

So the points never double. An army that walked at once this season has nothing left for End turn; an army you did not touch
walks its standing march at End turn exactly as today.

### 2.3 "Moves at once": what exactly happens on a click

The march action stays one action (so the same checks, the same refusal words). When it is accepted:

1. The route is planned (as today, with the same winter and pass rules).
2. **The army walks its leg now**: as many steps of the route as its points left allow, step by step, until the points run
   out, it arrives, or something stops it (2.5 to 2.8). Every step is final.
3. The game state changes at once: the army stands on its new hex, the hexes it saw are explored, other countries' sight
   is updated, events are sent (the walk, a halt, a battle).
4. If the route is longer than the points allow, the **rest stays as a standing march** (the goal and route are kept) and
   the army continues at End turn of the **next** season with that season's allowance, one leg a season, as today. See 2.4.

The shell then **plays the walk live**: the token follows the path, a few tenths of a second a hex, the camera follows if
the army leaves the screen, Space skips it. The picture is only a replay of what is already done in the game, so it can never
change the result (reduce motion: the token jumps).

### 2.4 Long marches: the pace does not change

A 12-season march today takes 12 End turns. After the change, the first leg is walked at once (season N), the second at the
End turn of season N+1, and so on. The army never covers more ground per season than today; it only gets there earlier in
real time because the first leg is no longer waiting for End turn. The army panel keeps showing the stops of each season
(the "walk plan" that exists in M6).

Why the second leg is at End turn of N+1 and not at End turn of N: season N's points were spent by the first leg.

### 2.5 One move a season, or many until the points run out? (two options)

**Option A: one move per season.** A move uses the whole allowance. Even a one-hex step ends the army's season: the
leftover points are lost.
- Plus: simplest to explain and to test; strong "no take-backs"; fewer replays to watch.
- Minus: a small, careful move wastes the season. Players will fear clicking. No chance to scout and then pull back or
  choose differently after seeing something new. A hidden cost for beginners ("why can't it move again?").

**Option B: many moves until the points run out (recommended).** The army keeps `points left` (shown on its token and in
its panel). Each move spends what its steps cost. The player may order again with the points left, to any hex the points
reach (a march goal further than that continues as a standing march, 2.4).
- Plus: natural and readable (like Civilization's movement bar), rewards planning, makes scouting a real choice (a rider that
  goes 4 points out and 4 back has spent half its season), and a click on a near hex is cheap rather than a trap.
- Minus: a little more state (one number per army, saved), more refusals to word ("no points left this season"),
  more replays to watch.

**Rules that go with B** (both options need them):
- A step the army cannot pay for with its points left is not taken (the army stops), with one exception kept from M6: the
  **first step of a season** may cost more than the full allowance (so an 8-point battery can still enter a snow peak).
  "First step of a season" now means "the army has spent no points this season".
- A **wade** step (a river too deep for a ford) may be taken only with all points left, and spends all of them (as today).
- A **zone of control** stop (2.7) and entering a **battle** end the army's season: points left become 0.
- **Raising**: a new company has "mustering" this season (as today) and cannot move. It is not given to an army that has
  already moved. **Split**: the new army starts with the parent's points left. **Merge**: the merged army has the lower
  of the two. **Disbanding** changes nothing. Together these close the loophole of splitting and merging to refill points.
- Points are given back at the start of each season (in the calendar step, so the order of the phases does not matter).

The build keeps Option A as a data switch (`moves_per_season` 1 or many): the state "points left" is needed for both, so
choosing A first costs nothing if the owner later wants B.

### 2.6 Meeting an enemy army: the battle opens at once

When a walk steps onto a hex held by an army of a country **at war** with yours (or onto a battle that is already on that
hex and your side is in it):

- The step is taken, the army stands in the hex, and **the battle opens at once**: the attacker is you, the defender the
  other army's country (the M7 rules for sides, ground, crossing, uphill and river are unchanged).
- The shell opens the **battle board** (a window over the map, as decided for the board build; the UI audit's section 4 called
  it the live dock) before you can do anything else. Your stance and the fills are set by you day by day; Auto to the end
  is one click. **Order (owner, 2026-11-25):** this change ships before the board (issue 437). Until the board exists the
  battle is fought automatically at the click and the battle dock shows the result. A battle of the other side's moving, in
  which you take no part, is never played for you.
- **The defender's orders**: it has none to give now; it fights on its standing order (Hold, or Withdraw when a retreat
  hex exists), as today and as the audit says. The computer keeps its fixed stance and automatic fills.
- When the battle ends the army either stays (a win) or retreats
  as M7 says. Either way its season of movement is over (points left 0). The rest of your standing march continues in later seasons if the army still has it and wins.
- If you do not want a battle, do not step there. The preview marks a step into an enemy army (2.9).

**Where the dice come from.** The battle draws its luck from the same shared luck stream as today (the world stream), but
now at the moment you walk, not in the battles phase. Battles are fought in the order they happen, not in hex order. This
is allowed because the action log records the order of everything the player does, so replay gives the same dice.

**Stop when an enemy comes into sight (recommended).** A walk ends (with the points kept) the step **after** an army of a
country at war with you first comes into your sight, so you are never walked blindly into a stack you could have avoided.
It is the same idea as the "zone of control", only wider (sight 1 or 2 hexes against 1). Without it, a rider with sight 2
walking a long route could charge into a bigger army it saw one step earlier. Zone of control (adjacent hostile army) stops
the army anyway, as today.

**Stepping into an enemy army you cannot see.** In light fog armies are hidden (issue 446: light fog hides only armies,
their moves and battles you are not in). A step onto an unseen enemy army at war is a battle like any other: there is no
ambush bonus for either side in v1. A step onto an unseen army of a country you are **at peace** with is refused: the walk
stops on the hex before, and the log says "another country's army stands at Alessandria (7, 9)" exactly as the check says
today, so no new fact is leaked.

**A siege.** An army that arrives at a hostile fortress and has a besiege order starts its siege at End turn, in the sieges
phase, as today. A **storm** order is different: the walk takes the army to the fortress and the assault battle opens at once
on the board (the garrison fights as in M7). A relief army that walks onto the besiegers' hex is a battle like any other.
An army that leaves the hex of its siege lifts it at the season's siege phase (the check already looks at where the
army stands then). Taking a district (walking in and occupying) is counted at the season's end phases, not the second the
army arrives; the walk only brings it there.

### 2.7 Zones of control, closed land, weather

- **Zone of control**: stepping to a hex next to an army of a country at war with you (or next to a hostile garrisoned
  castle) ends the walk there and ends the army's season. The same for armies of the computer when it moves.
- **Closed passes (winter)**: the route is planned with the rules of today. When the next step is a pass shut by snow, the
  army stops on the hex before and its status is "waits for spring", a standing march, as today. In spring the pass reopens
  and the standing march resumes at End turn. No change in the words.
- **Weather and season**: the step costs are those of the current season at the moment of the click (winter doubles snow, as
  today). The player sees them in the preview.

### 2.8 Other armies and other hexes

- **A hex another army enters first**: whoever acts first gets there. A hex holds at most 8 companies of one country (the
  stack limit) and cannot hold two countries at peace. If your leg's end hex fills up (or you order into a full hex), the
  march action refuses with the existing words ("no room at Vercelli (6, 9): 8 of 8 companies") **when the order is given**.
  If a hex on the route fills during the walk (not possible for you: nothing else moves during your walk), the army stops on
  the last hex with room. The "step back" rule for crowded hexes at the end of the movement phase stays only for standing
  marches.
- **A hex deep in the fog** (never discovered): the order is **refused** ("you have not discovered that land"), and the
  route may only cross hexes your country has discovered. The walk discovers more as it goes; a longer route is re-planned at
  the next leg. This keeps the light-fog rule (the map you know is fully drawn) from leaking undiscovered ground to the
  route finder.
- **A hex in light fog**: fully usable (the land is known). Only armies on it are unknown, see 2.6.

### 2.9 What the player is shown before committing

Because moves cannot be undone, the existing move preview (reach line, stops, the hover card) becomes the main tool:
- The hover shows the path, its cost in points ("Walks 3 hexes, 7 of 12 points; 5 left"), where it stops this season if the
  route is longer, and the **warnings** that already exist or are new: "enters enemy land", "ends out of supply (the army
  will forage; hungry in 2 seasons)", "steps into the enemy army at Cerano: a battle, odds Even", "passes a zone of control".
- **Click commits.** For three risky kinds of move only (a battle, entering enemy land, ending out of supply) the click
  opens a small confirm: "This opens a battle at Cerano (odds: Even). Move? [Move] [Cancel]". Cancel means nothing happened.
  (Q3.)
- After the move: the toast says what happened. The panel shows the points left and the standing march, if any.
- Ctrl+Z (undo) keeps working for works only. The help line says "Army moves are final."

### 2.10 Supply and foraging

Supply is judged at the **end of the season**, where the army stands then (the supply phase, unchanged). Moving at once
changes nothing in the rules: an army out of the depot's reach when the season ends forages and may starve, as today. What
changes is that you now see it before you press End turn, and you can still walk back with points left (Option B). The
preview's "ends out of supply" warning is the answer to "I did not know". Supply lines, depots and the forage table are
unchanged data.

### 2.11 What the other countries see, and who moves first

**The order of a season becomes:**

1. **The player's turn**: orders and moves, all at once and in order. Everything the player does is real from the click.
2. **End turn: the computer's orders.** Each computer seat in turn (first seat rotating each season, as M8 D9) gives its
   orders. A **march is also at once for the computer**: its army walks the moment the seat orders it (same rule, same
   code), so a later seat sees the earlier seat's army where it now stands, if it can see it. The pill ("Countries are
   moving") is shown as today; the shell **replays the computer's walks you can see** after its turn, as today's replay.
3. **The movement phase**: every army with a **standing march** and points left walks its next leg, tick by tick as today.
4. Then battles (the ones not already fought), supply, sieges, war, production and the rest, as today.

**What this means for fairness:**
- **The player always acts before the computer in a season.** So the player has no fear of being "beaten to a hex" by the
  computer in the same season, and the computer's army that you attack cannot walk away first (its standing order Withdraw is
  its only answer). That is a **first-mover advantage for the player**, partly balanced because the computer answers last: it
  sees where you ended your season and can attack your armies before your next turn. It is chess-like, not simultaneous.
- **Between computer seats** the first mover rotates (M8), so no country always wins a race.
- **The simultaneous "tick" race** between the player and the computer is gone. It remains only inside the movement phase,
  among standing marches (all of them leftovers after the at-once part), where it is as today.
- **The computer only knows what it sees** (M8 fog rule, light fog hides armies). The player's moves are visible to it only
  when they are in its sight after they have happened. The computer does not read your orders; there are no orders to read
  (the move is done), only positions.
- **A declared war** ("fair warning" of M8): a country that declares war this season does not send armies into the enemy's
  land in that same season. **Owner answer, 2026-11-25: this holds for every country, the player included.** You may declare
  a war and fight the enemy's armies on your own or unclaimed land at once, but your armies may not enter its land until the
  next season, and an order that breaks the rule is refused with a clear sentence and a hint. The rule binds the one who
  declares: when a computer country declares war on you, your armies are free. Without it a declaration and a strike would
  come in one season of the player's, before the other country can move at all.

## 3. Saves, determinism, replay, fog

**What is stored.** A move is an accepted **action** (the march), already logged by the game as every accepted action is.
Replaying the log plays the march again, which walks the same steps from the same state. Nothing new to log for walks:
a walk is the consequence of the action, not a second action.

**New state, saved.**
- Per army: `points left` this season (a number). The army record gets a new version (army/3, with the digest including it).
- A **battle can exist while the game is idle** (between your move and its fight, when you leave the board or save). Today
  "a battle exists only between the movement and battles phases", so the battle record must now be saved. The audit's plan
  (a `battle/2` body: the battle's start, its luck state, and the orders given so far, re-fought to the same day on load;
  the owner answered "saving is allowed anywhere") covers it. The save format number goes up once for both.
- The standing march, goal and route are saved as today.

**Luck order.** The luck stream is drawn at the click (the battle's days) and in the phases. The order of draws is the
order of the log, so replays, the digest and saves agree. Two things must be written into the standard: (1) a battle's
days are drawn when played, in order of play; (2) a pause on the battle board draws nothing.

**Reload and the dice.** A player can reload a save before a move and take a different decision against the same dice. The
owner accepted this (answer 7, 2026-11-24).

**Fog.** The fog rule is the one the owner set in issue 446: deep fog is never-discovered ground (nothing shown, not
orderable, not routed through); light fog is discovered ground out of sight now (the land, owners, people, buildings and
works stay visible; **only armies, their moves and orders, and battles you are not part of are hidden**). Under this change:
- The walk shows other countries' armies only while they are in sight (as today).
- The same rule applies to the computer, and the computer's walks are replayed to you only where you could see them.
- Fog is lifted by the walk itself, step by step (the army's sight moves with it).

**Tests and tools that change** (names as in the specs; the build lists them exactly):
- **Movement tests** (M6): "march stores an order then the phase walks it" becomes "march walks now; the leftover is a
  standing march; points left; the phase walks only standing marches with points left".
- **Season and phase tests**: the movement phase now has less to do; a pinned order test for `Season.PHASES` stays (the phase
  still exists).
- **Battle tests** (M7): a battle can be opened by an action and fought on the board; `test_battle_replay` and the replay
  test gain a case with a battle opened by a march in the player's turn; the "bands" test (seeds 1 to 500) stays valid because
  the fight itself does not change.
- **AI door and soak tests** (M8): the AI's march now moves at once; the door test still holds (the AI acts through the same
  action); the soak's ranges (wars per game, wars lost) are measured again, since the AI's armies now do not wait in
  the movement phase. `perf_core` gets a line for an AI season with walks.
- **The monkey (random-input test)**: it now clicks marches mid-turn; invariants after every action: stack limit, no army on a
  hex it cannot stand on, points left between 0 and the army's full points, save then load gives the same digest, a battle
  at idle survives save and load.
- **Behaviour oracle** (same-fixed-seed games before and after): expected to **differ** (the walks are no longer
  simultaneous). It is turned off for this change and re-based by hand, with the reason written in the change.
- **Pictures** (goldens): the army token with a points-left mark; the confirm; the walk playing (one still).

## 4. Alternatives considered

1. **Preview-only mode** (you see exactly where the army will be and what it will meet, but nothing moves until End turn).
   Good: undoable, safe, nothing changes in the save. Bad: it is today's game with a better preview; it does not give the
   "I move, I see, I move again" feel, and it does not meet the owner's decision (moves final, at once). Rejected, but its
   idea (a strong preview) is part of section 2.9.
2. **Moves at once, resolved at End turn.** The army's token visibly moves when you click, but battles, sieges, supply and the
   computer's answer are decided at End turn together. Good: keeps the simultaneous tick race and the existing phase order
   almost intact, the AI does not need to move at once. Bad: "I moved but I do not see what happened" remains; a move
   into the enemy would just be a promise; two modes of truth (the picture and the state) are a source of bugs and
   confusion. Rejected: the owner wanted the answer at once.
3. **The computer moves first** (at the start of your turn, before you see the map). Good: you are always the last mover and
   can answer everything. Bad: you can never strike an army before it moves again; it feels like losing the initiative every
   season; it needs the computer's turn at the start of a season (new place for the report). Rejected; section 2.11's
   order (you first, they answer) is more readable.
4. **A fixed order for all moves by country rank** (a "who moves first" table). Rejected as arbitrary; the rotation of M8
   already gives fairness among the computer's seats.

## 5. Risks

| Risk | What could go wrong | What we do |
|---|---|---|
| **Misclick** | A final move is a costly mistake | The preview, the points left, a confirm for battle, enemy land and out-of-supply moves (Q3) |
| **Scouting with undo is gone** | Intended | Looking costs points; the riders' sight 2 does the rest |
| **Player first-mover advantage** | The player strikes an AI army before it can move away | Fair warning for every country (no entering the land of a country you declared war on in the same season); the AI answers in the same End turn; Withdraw standing order; if the playtest shows it, the AI may keep a defender's free "step away" (not built now) |
| **The AI feels slow** | Each AI march now includes a walk and a sight refresh | One walk per march costs little (a route search dominates); the sight is refreshed for the moved army only, not the whole map; `perf_core` pins the limit (AI season on north Italy under 200 ms today) |
| **Combat before the AI acts** | The AI never gets to react to your attack in the season | It reacts the next End turn; the board shows the AI's army fights on its standing order |
| **Long animations** | A turn of ten moves is ten walks | Short walk time, Space skips, reduce motion; moves play in order and never block input for long |
| **The luck stream shifts** | Weather draws come after battle draws | Logged order makes replays exact; goldens and the soak are re-based |
| **Battle open at idle** | Save, quit, reload mid-battle | Battle record saved (3); a test for save, load, then finish the board |
| **Exploit: split, move, merge to refill points** | Free extra moves | Split gives points left, merge takes the lower (2.5) |
| **Exploit: raise next to the enemy and move at once** | Raised companies cannot move this season (mustering), as today | no change |
| **Exploit: reload-scum the dice** | The owner accepted it | Noted, not fixed |
| **Spoils of position: an army blocks a pass by being first** | The player moves first | A pass is held by who is there, not by speed; the AI can still attack it |
| **A bug between "at once" and the standing march** | Double movement | One field (points left) guards both; an invariant in the monkey and the soak: no army ever spends more than its full points in a season |

## 6. Build plan

Sizes: S under half a day, M about a day, L two to three days of a worker, then review. All inside the Godot game, in the
`core` layer first, then the shell. Groups in order; each ends with all tests green.

| Group | Size | What | Specs and tests touched |
|---|---|---|---|
| **A. Allowance and the walk now** | L | The army's `points left` (army/3 and its digest, reset each season, split and merge rules). `march` walks its first leg at once; `continue_march` and `halt` rewritten around it; a march's leftover is a standing march. The step rules (first step of a season, wade, zone of control, closed pass, room) for a single walking army; sight refreshed for that army only. Option A or B by one data value. | M6 4.4, 4.7, 4.11; M6's movement tests and the army fixture; one new test file for points |
| **B. Meeting and battle at once** | L | A walk onto an enemy army or a storm opens a battle at once (`Battles.engage` reused); the battle can be idle (save: battle/2 and the format number); luck order; "stop when an enemy comes into sight"; unseen armies; refusal words | M7 4.6, 4.8; battle replay tests; save and snapshot tests; the audit's 4.3 and 4.4 updated |
| **C. The season and the computer** | L | The movement phase only walks standing marches with points left; the AI's march acts at once (same action), the seat order rotating; pill and replay of the computer's walks you can see; `Season`, `SeasonFlow` states (a flow with a battle in the player's turn); fair-warning rule for every country, the player included (owner answer 2026-11-25) | M8 4.2, 4.10, 6.2; `test_season`, AI door, `perf_core`, the soak |
| **D. The shell** | M | The live walk playback and skip; points-left mark on tokens and the army panel; preview lines and warnings; the confirm for risky moves; toasts, help line "Army moves are final" | the UI audit's unit and map parts; golden pictures; the UI test for the confirm |
| **E. Proof** | M | Monkey invariants (points left, battle at idle, save then load); soak ranges measured and set again; the behaviour oracle re-based by hand; README rule text; the three build specs and the audit amended in the same change | `test_ui_monkey`, soak tool, nightly reports, README, CHANGELOG |

Order against the rest: this goes **before** the battle board (the owner's answer 6, confirmed on 2026-11-25), because the board's trigger moves
from the battles phase to the walk. Group B and the board share the saved battle record, so they are built together or B
first. The M9 spec (next after M8) is read against group C for the AI's walks.

## 7. Questions for the owner

1. **One move a season, or many until the points run out?** Option A: one move uses the whole season's allowance. Option B:
   many moves, each spending what it costs, until the points are gone. **Recommend B** (a small click is not a trap, scouting
   is a real choice); one switch in the data lets us start with A if you prefer.
2. **Who moves first in a season?** Option 1: you first, then the computer when you press End turn, and the computer's armies
   also walk at once (they answer, they see where you stand). Option 2: the computer first, at the start of your turn.
   **Recommend Option 1** (you hold the initiative; they answer; the first mover among the computer's countries rotates).
3. **Does a click on a risky move ask once more?** Risky means it opens a battle, enters enemy land, or leaves the army out of
   supply. Options: always one click (fast, risky), or a small confirm on risky moves only, or always a confirm. **Recommend
   the confirm on risky moves only.**
4. **A long march: how fast?** Option 1 (recommended): the first leg is walked at once, the rest at End turn, one leg a
   season, so the pace of a long march is unchanged. Option 2: the army may keep walking at once until points run out, and a
   long route simply takes more seasons in the player's own turns (no standing marches). Option 1 keeps the pace and the
   existing "standing march" so the computer's armies and the player's behave alike.
5. **Does an army stop when an enemy first comes into sight?** Option 1 (recommended): yes, with its points kept, so you
   decide what to do next. Option 2: only a neighbouring enemy stops it (the existing zone of control); you may walk
   straight into a bigger army you saw one step earlier. Recommend Option 1.
6. **Ordering into never-seen land.** Option 1 (recommended): refused; routes cross only discovered land; the walk reveals
   more. Option 2: allowed; the route finder knows the map even where the player does not (simpler, a small leak).
7. **When a battle is opened by your move, is it fought on the board at once?** Option 1 (recommended, as the audit
   plans): yes, the board opens at once and you play it day by day, or press Auto. Option 2: the battle is marked and you
   fight it later this season or at End turn. Option 1 gives the "I see what happened at once" feel the decision wants.

---

## Owner's answers, 2026-11-24

1. **Many moves a month:** an army may move many times until its movement allowance for the month runs out (option B).
2. **Who moves first:** the player first, then the computer answers at End turn (its armies also walk at once).
3. **Confirm:** ask once more only on risky moves (a move that starts a battle, enters enemy land, or ends out of supply).
4. **Long marches:** the first leg at once, the rest one leg a month at End turn (the pace of a march is unchanged).
5. **Stop on sight:** the walk stops when an enemy army comes into sight, and the rest of the allowance is kept.
6. **Unknown land (deep fog):** an army MAY be ordered into land never discovered, with a movement penalty (for example one
   tile a month, to be tuned); scouts discover land more easily. The owner will come back to the exact rule. This replaces the
   draft's recommendation to refuse such orders.
7. **Battle at once:** a move that reaches an enemy army at war opens the battle at once on the board.
8. **Multi-leg marches (owner request, 2026-11-25; GitHub issue "Multi-leg marches: Shift+left click adds waypoints to an army's
   route").** With an army selected, Shift+left click on a hex adds a waypoint. The path preview is drawn through every waypoint
   in order, with each leg's cost and the seasons it takes; a plain right click on the last hex (or the command key) commits the
   whole route; Esc clears the waypoints; Shift+left click on the last waypoint removes it. After the order the army marches leg
   by leg (the first leg at once, the rest a month at a time at End turn), stopping when an enemy comes into sight; the route
   stays drawn until done and a new command changes it. Fog applies per waypoint (deep-fog legs allowed with the movement
   penalty). Built by `docs/architecture/moves-build-spec.md` section 3.11 (R58 to R72, D29 to D37) and task MV19 of the plan.
9. **Fair warning (2026-11-25):** the rule "no country may enter an enemy's land in the season it declares war" applies to every
   country, the player included. The player gets a clear refusal text and a hint. Built by
   `docs/architecture/moves-build-spec.md` section 3.12 (R73, D24) and task MV20.
10. **Order (2026-11-25):** moves in the month (#432) ships before the battle board (#437). Until the board exists a battle is
    fought automatically at the click and the battle dock shows the result (spec D39).
11. **Several battles at End turn (2026-11-25):** "Auto all battles at the end of turn is a hit. Ask before it runs all, with a
    notification that can be turned off." At End turn, when you have one or more battles to fight, the game asks once "Fight
    your N battles automatically?" (Yes: all of them on Auto; No: play them on the board once it exists), with a "Don't ask
    again" option that is turned back on in Options. This applies from the moves build on; before the board exists every
    battle is automatic anyway, so the question first appears with the board. The setting, its Options row and the question
    are built with this change and stay dormant until then (spec 3.12, R74, D40; task MV21).
