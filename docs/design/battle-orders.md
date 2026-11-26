# Battle board: what the player orders each round

Game designer, 2026-11-25. **Status: decided for version 1 (owner, 2026-11-26 and 2026-11-27): watch only. Packages A, B
and C of section 3 are not chosen for v1; they are kept as later options. Nothing here is built.**

## The owner's answers (2026-11-26 and 2026-11-27)

- **Version 1 is watch only:** no stances, no fills, no targets, no presets. The line-up is automatic. The player watches the
  rounds and **may withdraw from the second round**.
- **Withdraw** keeps today's rule as the default (noted here, not newly decided): it needs a hex to fall back to; it costs 5 %
  of the men (10 % as the attacker) and sets morale to 25 %; the army leaves at the end of the round; a break or a wipe in
  that round goes first. Today's code leaves only at the end of day 2, so the build widens it to any round from the second
  (build spec R5, D10).
- **Battles should aim for about 10 rounds.** Today they end after about 3 to 4 days and are capped at 8; what controls this
  and what must change is in the build spec, section 1.3.
- **The board is still a window** over the map, and **Auto stays one click**.

A round is one day of the fight. The rest of this page is the study of orders made before these answers; read "recommended"
and "Core" in it as advice for a later version.

**Why this doc.** The owner was asked "what can you order each round in battle board v1?" and answered (2026-11-25):
"Nothing yet, this should be planned first." This is that plan. It lays out what the fight already decides on its own,
lists every order we could give the player, groups them into three packages, recommends one, and lists what the owner must
decide and which mockups to draw before anything is built.

**Read with:** `docs/architecture/battle-board-build-spec.md` and `battle-board-build-plan.md` (the board's build, written
to the spec's default of stance, fills and gun targets; called "the spec" and "the plan" here), `docs/design/ui-family-audit.md`
section 4 and the owner's answers there, `docs/design/battle.md` (the owner's earlier battle ideas: stance, reserve to a lane,
cannon target, formation presets, events, cards) and `docs/design/battle-size-and-frontage.md` (width, back line, rotation).

**The short answer.** Version 1 is **watch only** (section 3.0). The advice for a later version with orders was package
**B, "Line and guns"**: each dawn you set a **stance** (Attack, Hold, Withdraw,
with Withdraw open on any day from day 2), you choose **who fills a lane** when one opens (on day 1 this is your opening
line-up, with a few named presets), you may **keep a flank open** to hold a company back, and you give **one fire order**
for all your guns and crossbows. Everything has a default that is exactly today's fight, so Auto, the computer and the soak
do not move. Cards, rotation, width and commander actions wait for M24 and the generals.

---

## 1. What the fight does today, and what it decides for you

The Godot fight (`core/systems/combat.gd`, `combat_day.gd`, `combat_hit.gd`, numbers in `data/defs/war.tres`) is a loop of
up to 8 days. A day is: dawn, deploy, two dice (one per side, 1 to 6, giving x0.7 to x1.4), fire, back line, shock, flanks,
morale, the end-of-day check. Every hit draws one spread number (x0.5 to x1.5). Three lanes a side (left, centre, right;
the right lane is shut on narrow ground); each lane holds one company; everything else is the reserve.

**Decisions the engine already makes for both sides:**

| What | Who decides today | The rule |
|---|---|---|
| The opening line-up | the engine (`_pick`) | Centre first, then left, then right. Infantry to the centre, cavalry to the flanks, crossbows and bombards last; ties by best defence, then lowest id |
| Who fills a lane that empties | the engine (`_pick`) | Same rule at each dawn; a company moved up after day 1 is **shaken** (deals half for that day) |
| Holding a company back | nobody: impossible | Every empty open lane is filled while the reserve has anyone, guns included |
| Where guns and crossbows shoot | the engine | Only from the reserve. Bombards at the enemy centre; crossbows spread over centre, left, right; fallback to the next filled lane |
| Stance | fixed for the whole battle | The attacker always Attack; the defender its army's standing order (Hold or Withdraw) |
| When to leave | the standing order | Withdraw leaves **only at the end of day 2**; costs 5 % of men (10 % as attacker), morale set to 25 % |
| Breaking and fleeing | the engine | A side breaks with no reserve and its centre empty, or two lanes empty; or front morale under 10 %. Flight costs 15 % of men and every gun |
| The day-8 cap | the engine | The side with the lower front morale withdraws |
| The unit triangle | the numbers | Pikes against horse x1.25 both ways; horse x1.4 in the open, x0.7 in rough, x0.5 at walls; guns x2 at walls; flank runners x1.25; guns and crossbows hit from the reserve |

**Four facts about today's numbers that shape the orders** (read from `war.tres`, worked by hand):

1. **Stance is a pace dial, not an edge.** Damage dealt is multiplied by your stance and by the enemy's: Attack deals 1.2
   and takes 1.1; Hold deals 0.9 and takes 0.8. Attack against Hold: you deal x0.96, you take x0.99, an even trade. Both on
   Attack: x1.32 each way; both on Hold: x0.72 each way. So the stance mostly sets **how fast and how bloody** the day is,
   while the flat morale drain (2 % a day in a lane, 3 % in the reserve) ticks the same. Fast suits the side with more men or
   better matchups; slow suits the side waiting for day 2 to withdraw, or for day 8. That is a real choice, but a subtle
   one, and the board must say it in words.
2. **Guns and crossbows only shoot from the reserve.** In a lane they fight hand to hand with weak numbers (bombards defence
   1). Today the engine sends them into a lane as soon as nothing else is left. "Keep my guns back" is a decision the
   player cannot make.
3. **The reserve protects the line and costs morale.** While a side has a reserve it cannot break by its lanes, but each
   company in it loses 3 % morale a day against 2 % in a lane.
4. **The line-up never looks at the enemy.** `_pick` does not check who stands opposite. A player who puts pikes against
   the enemy's knights will beat the default. That is the first skill the board rewards, and the reason the computer needs
   a smarter pick later (section 4.5).

---

## 2. The order candidates

**For v1 only one of these is built: Withdraw from the second round (2.2).** Every other candidate is later; the ratings
below are the advice for that later version.

Each candidate below says what it changes in play, its depth against its cost, what it does to determinism and replay, what
the UI needs, how the computer gets the same order, and a rating: **Core** (in the recommended package), **Good** (worth it,
in the rich package or as a choice), **Later** (needs another system first), **No**.

"Determinism" for every candidate: an order is an input, logged with the day (spec R7); the battle stays a pure function of
its input, its luck state and the orders. Orders that change who stands where change **how many** spread draws a day takes,
so they change the luck of later battles. That is accepted in the spec (risk "orders change later luck"). A candidate that
draws a number of its own is marked.

### 2.1 Stance each day: Attack, Hold, Withdraw

- **Changes:** the day's pace and losses (fact 1). Sticky from day to day.
- **Depth / cost:** low depth alone, very cheap (spec R5 already builds it).
- **UI:** a three-way switch in the footer; each hover shows the price from `WarDef` ("deals +20 %, takes +10 %"); the
  round card names both stances after the day ("Both sides attacked: losses were heavy").
- **AI:** keeps M7's fixed stance in v1 (spec D9); a per-day rule later (4.5).
- **History:** Bicocca (1522): the Swiss attacked entrenched arquebusiers and were cut down; Hold on good ground is the
  stance of Cerignola (1503).
- **Rating: Core.**

### 2.2 Retreat timing: Withdraw on any day from day 2

- **Changes:** today a Withdraw leaves at the end of day 2 or never. With the change the player can fight on and leave on
  day 3, 4 or 6 when the day goes badly, paying the same price. The flight under 10 % front morale stays automatic and is
  far worse (15 % of men and all guns), so the decision is "leave now at a price, or gamble one more day".
- **Depth / cost:** the most dramatic choice for its cost: one comparison changed (spec R5, D10).
- **UI:** Withdraw disabled on day 1 with its reason; its hover names both prices; a red line on the tug bar at the flee
  level.
- **AI:** keeps its standing order in v1; a rule later ("withdraw when front morale is under 30 % after day 2 and the odds
  word is Poor or worse").
- **Rating: Core.**

### 2.3 Fills: who takes an open lane (and the day-1 line-up)

- **Changes:** at a dawn with an empty open lane, the player picks which reserve company steps in, instead of `_pick`. On
  day 1 every lane is empty, so this is the **opening line-up**. It is where the unit triangle becomes the player's: pikes
  opposite their knights, knights on a flank where they will find crossbows.
- **Depth / cost:** high depth, cheap in rules (spec R3); the UI is the real cost (one chooser per open lane).
- **UI:** an empty lane shows its candidates as small regiment tiles with a matchup word (Strong, Even, Weak) against the
  enemy company in that lane, the usual pick marked and pre-selected; hover gives the reasons ("Pikes against horse
  +25 %"). Day 1 adds **presets** (2.10).
- **AI:** `_pick` in v1; a matchup pick later.
- **History:** Breitenfeld (1631): when the Saxons fled, the Swedes swung reserve regiments into the broken flank.
- **Rating: Core.**

### 2.4 Keep a flank open (hold a company back)

- **Changes:** a fill may be "leave this lane open". The company stays in the reserve: a gun keeps shooting, a fresh
  company is kept for later. The price is the engine's own: a lane that held a company and is now empty is **broken**
  (the centre loses 10 % morale each day it stays so), and the enemy company in that lane wheels into your centre at x1.25.
  On day 1 a lane that never held anyone is open ground: no broken-lane drain, but the enemy still wheels round it.
- **Depth / cost:** a real trade-off at almost no code cost (one more value in the fill chooser).
- **Exploit and the rule that closes it:** an army that keeps everyone back never breaks by its lanes (it has a reserve)
  and is not measured by front morale (nobody in a lane). So **the centre may never be left open while the reserve can
  fill it**; only the flanks can. With that rule the side still breaks by morale and by its centre.
- **UI:** "Leave open" as the last entry of a flank chooser, with its price in the hover.
- **AI:** never leaves a lane open in v1 (its default).
- **History:** Pavia (1525): the French king's charge masked his own guns; keeping guns clear of the line is the lesson.
- **Rating: Core** (owner decision Q3).

### 2.5 Fire orders for guns and crossbows

Two forms:

| Form | What the player sets | Clicks | Notes |
|---|---|---|---|
| **One fire order** for the army | "Fire at: usual / left / centre / right", for every ranged company still in the reserve | one chooser | Most armies have 0 to 2 ranged companies in era 1 (measured: 0.5 a side on average up to 1520) |
| **Per company** (the spec's R4) | each ranged company's lane | one chip per company | Matters only with 3 or more ranged companies (era 2 and 3 shot) |

- **Changes:** where the reserve's fire lands. Focus fire can break one enemy lane a day sooner; a broken enemy centre
  shocks the whole enemy army (25 % morale) and exposes its reserve. Shooting the knights on their flank before they charge
  is the triangle again.
- **Depth / cost:** medium depth, cheap rules either way (fallback to the next filled lane, as today).
- **UI:** one fire chooser with a matchup word for each lane ("Crossbows on their pikes: Even"); per company needs one chip
  on each reserve tile.
- **AI:** today's targets.
- **Risk:** guns are already the strongest addition (4 pikes + 2 bombards was the best mix in the frontage study). Focus
  fire may push it further; measure in the `orders` soak suite before release.
- **History:** Ravenna (1512): the French guns pounded the Spanish lines until the Spanish horse left their trenches to
  charge, a fire order that forced the other side's stance.
- **Rating: Core** as one fire order; per company **Good** later (owner decision Q2).

### 2.6 Formation width (frontage)

- **Changes:** the lane count (3, 5, 7) by ground and army size, as `battle-size-and-frontage.md` designed. A player order
  could only be "narrow the field" (refuse a flank), which the narrow-ground rule already does by terrain.
- **Depth / cost:** high depth, high cost: every lane rule, the bands and the odds words change and need a balance pass.
- **Rating: Later (M24).** On the board in v1 the width is shown as a fact ("Narrow ground: the right lane is shut").

### 2.7 Flank orders (wheel or hold)

- **Changes:** today a flank company with nobody opposite always wheels into the enemy centre at x1.25. An order "stay"
  would rarely be right, and "swap two lanes" is the approved card Change of front.
- **Rating: No** as a daily order; **Later** as a card.

### 2.8 Rotation (pull a tired company back)

- **Changes:** swap a tired front company with a fresh one. Measured in the frontage study: an instant swap is a snowball
  (6 against 4: win from 85 % to 98 %); a swap that takes 1 to 2 days, with the lane exposed while it happens, is fair.
- **Depth / cost:** good story, a small lever in numbers, and it needs swap timing, exposure numbers and a "rotating" state
  on the board.
- **Rating: Later (M24),** with the back line it belongs to.

### 2.9 Rally and commander actions

- **Changes:** a once-per-battle "Rally the banner" (one company regains morale) or "Lead from the front" (the general
  risks a wound for a bonus). Gives a "when to spend it" decision, which daily orders lack.
- **Depth / cost:** good depth; needs generals (not in the Godot game yet) or a stand-in. New numbers in `WarDef`
  (for example `rally_morale`), no extra draw if the effect is fixed.
- **AI:** needs its own rule ("rally the centre when it is under 30 %").
- **Rating: Later** with generals; a general-less version is in the rich package (2.11).

### 2.10 Formation presets (day 1)

- **Changes:** nothing in the rules. A preset fills the day-1 choosers in one click: **Usual** (today's pick), **Horse on
  the wings**, **Strongest against their strongest**, **Guns kept back** (flanks left open for ranged companies). The
  player can still change any lane after. This is the owner's "deployment presets" idea of `battle.md` round 2, built as a
  shortcut.
- **Depth / cost:** removes clicks, adds none. Pure view code (the preset is a list of fills, checked like any fill).
- **Rating: Core** (owner decision Q5).

### 2.11 One-shot tactics or cards

- **Changes:** the approved card system (`battle.md` rounds 3 to 9: a deck from techs, generals and elites, command points,
  sneaky cards) is the full version. A stand-in before the deck: three **universal tactics, each once per battle**:
  **Charge** (your cavalry deals +25 % today, takes +10 %), **Volley** (your reserve's fire doubles today), **Stand fast**
  (no company of yours routs today; morale cannot go under 1).
- **Depth / cost:** the best "remembered moment" maker, but every tactic is a new rule with numbers to balance, an AI rule,
  and art. The card system was approved to come from the tech tree (M11) and generals.
- **Rating: Good** for the rich package; the real cards stay **Later** (M24).

### 2.12 Use of terrain

- **Changes:** the ground is chosen on the map: where you attack, whether you cross a river, whether you storm. In battle
  it is a fixed fact (chips: river crossed, uphill, pass, walls).
- **Rating: No** as an order. The board shows each ground effect as a chip with its number, and the matchup words include it.

### 2.13 A forecast before Fight day

- **Changes:** nothing in the rules. Under each facing pair, the men each side would lose today with the worst and best
  dice ("you lose 120 to 260, they lose 90 to 190"), worked out from the hit formula without drawing.
- **Depth / cost:** strong for "readable cause and effect", but a dense screen; the range is wide (the dice and the spread
  together span about x0.35 to x2.1), which may confuse more than it helps.
- **Rating: Good** for the rich package; v1 shows the matchup word only (owner decision Q10).

### 2.14 Summary of ratings

| # | Candidate | Depth | Cost | Rating |
|---|---|---|---|---|
| 2.1 | Stance each day | low | very low | **Core** |
| 2.2 | Withdraw on any day from day 2 | high | very low | **Core** |
| 2.3 | Fills and the day-1 line-up | high | medium (UI) | **Core** |
| 2.4 | Keep a flank open | medium | low | **Core** |
| 2.5 | One fire order (per company later) | medium | low | **Core** |
| 2.10 | Day-1 presets | none (saves clicks) | low | **Core** |
| 2.11 | Three one-shot tactics | high | medium, balance | Good (rich) |
| 2.13 | Loss forecast | medium | medium | Good (rich) |
| 2.9 | Rally, commander actions | medium | needs generals | Later |
| 2.6, 2.8 | Width, rotation | high | high, balance | Later (M24) |
| 2.7, 2.12 | Flank orders, terrain | low | | No |

---

## 3. Version 1 and the three packages

### 3.0 Version 1: watch only (decided)

1. **Dawn.** The board (a window over the map) shows both armies, the lanes, the reserves, the tug bar with the flee line,
   the ground chips, the odds word and the round number. The line-up and every refill are automatic.
2. **Next round** plays the day with today's rules. Dice show, hits play, the round card says what happened.
3. **Withdraw** is greyed on the first round and open from the second when the army has a hex to fall back to; its hover names
   the price.
4. **Auto to the end**, one click, plays the rest with default orders; it never withdraws.
5. **The end.** The result card, and "Review in the dock".

The computer's side keeps its input stance all battle. The End-turn question "Fight your N battles automatically?" and the
options stand as the build spec says (D19, D23).

**Packages A, B and C below are not chosen for v1.** All three keep the spec's frame: a board for battles you are a side of,
the round card, Auto to the end one click away, save at any dawn, and **default orders give exactly M7's fight**.

### 3.1 Fun principles for the board

Taken from `docs/research/fun-principles.md` and applied to a battle:

1. **Meaningful:** each order has a price and a situation where it is wrong (principle 2). No order is always right.
2. **Show the price before the choice** (principle 3): every stance, fill, fire lane and Withdraw shows its numbers in its
   hover, read from `WarDef`, never typed.
3. **Readable cause and effect:** the round card says what happened **because of** an order ("Your crossbows fired at their
   left: their knights lost 60 men before the charge").
4. **No hidden dice:** the dice are shown with their multiplier after each day; matchup words leave the dice out and say
   so; nothing is rolled while you think, and a reload gives the same day for the same orders.
5. **Short** (principle 11): the owner's target is about 10 rounds (today 3 to 5 days). At most one or two real decisions
   a round; Enter fights the round; a whole battle should still take about a minute, under ten seconds with Auto.
6. **Auto is honest:** Auto plays the default orders, the same the computer plays. Playing well should beat Auto by a
   little, not a lot (target: **5 to 15 points of win rate in an even fight**, owner decision Q9), so nobody feels forced
   to play every battle.

### 3.2 Package A, "Command the day" (minimal; later)

**Orders:** stance each day; Withdraw on any day from day 2. Line-up, fills and fire stay automatic and are shown.

**The round as the player lives it:**

1. **Dawn.** The board shows both armies, the lanes as the engine deployed them, the reserves, the tug bar with the flee
   line, the ground chips, the odds word, "Day 3 of 8".
2. **Choose.** One switch: Attack, Hold, Withdraw. The stance from yesterday is already set; usually nothing to do.
3. **Fight day** (Enter). Dice show, hits play, the tug bar moves (0.6 s).
4. **Round card:** "Day 3. You lost 240 men, Milan 310. Your left gave way; your knights moved up (shaken). Dice 4 (x1.1)
   against 2 (x0.8)."

**Good:** tiny to build (the spec minus BB9's choosers), nothing to balance. **Bad:** the triangle is something you watch,
not something you use; most days have no decision. The audit's risk R6 ("three stances may feel thin") is likely true.

### 3.3 Package B, "Line and guns" (the advice for later)

**Orders:** package A, plus fills with the day-1 line-up and presets, "Leave open" on a flank, and one fire order.

**The round as the player lives it:**

1. **Before day 1 (the line-up).** The board opens with your three lanes empty and your army in the reserve row. The enemy's
   army list is shown (who they have, men, morale, rank) but **not** where they will stand (owner decision Q4). A preset
   row: Usual, Horse on the wings, Strongest against their strongest, Guns kept back. Each lane shows its chooser with the
   usual pick selected. You may press Fight day 1 at once: that is today's fight.
2. **Day 1 plays.** Both sides deploy, the dice roll, the round card says what each lane did and why ("Your pikes held
   their knights on the right: pikes +25 % against horse").
3. **Each later dawn.** Most dawns have nothing to choose but the stance. A **chooser appears only when one of your lanes
   is open** ("Your left is open: fill with Pikemen 420 (Even), Knights 240 (Strong: their crossbows in the open) or leave
   open"). The **fire chooser** sits on the reserve row when you have a gun or crossbow there: "Fire at: usual (centre) /
   left / right", each with its word.
4. **Withdraw** lights up from day 2; its hover says "leaves at the end of this day: you lose 5 % of your men, morale falls
   to 25 %; if your front falls under 10 % you flee instead: 15 % and your guns".
5. **Fight day.** The round card ties orders to results: "Your bombards fired at their left: 70 crossbowmen fell"; "Your
   right was left open: their knights rode into your centre (+25 %)".
6. **The end.** The result card (won, withdrew, fled, wiped out, held to day 8), men killed and wounded, the retreat or
   the storm; "Review in the dock".

**Typical decisions in a 4-day battle:** a line-up (one click with a preset), one refill, maybe one fire change, one
"leave or stay" from day 2. Four to six choices, each tied to the triangle or to the price of leaving.

### 3.4 Package C, "Battle plan" (rich; later)

**Orders:** package B, plus three one-shot tactics (2.11), the loss forecast (2.13), and the computer using the same menu by
simple rules (4.5).

**The round as the player lives it:** as B, and at each dawn a **tactics tray** of three tiles (Charge, Volley, Stand fast;
each greys out once used); the round card names a tactic the enemy used ("Milan's knights charged: +25 % today"). Under each
lane the day's forecast range.

**Good:** close to the approved card system's feel (a hand, a moment to spend it) and the closest to "a mini game inside the
turn". **Bad:** new numbers and AI rules mean the bands, the soak ranges and the AI tests all move; it collides with M24's
real cards (the stand-in tactics would be replaced or would need to become cards); more to read each dawn.

### 3.5 How Auto fits every package

- **Auto to the end** on the board: in v1 it plays the remaining days with default orders and never withdraws (spec D11).
  In a later version with orders it would keep the last stance given and default fills and fire; in package C no tactics.
- **Auto in Options** ("Your battles"): the board does not open; the battle is fought with defaults and shown as a toast
  with "Review".
- **The battles prompt** at End turn (4.4).
- **Nothing to choose:** a lone garrison with no reserve, no retreat and no gun is fought at once (spec D17).

---

## 4. Interactions

### 4.1 Fog

- The board opens only for a side of the battle, and a side sees both armies exactly (fog rule unchanged).
- **The enemy's coming orders are never shown** (spec R25): its stance, fills and fire for the day you are choosing. Its
  past stances are shown after each day.
- **Day 1 is blind by default:** you see their army list but not their line-up, because both sides deploy at the same dawn.
  Options (Q4): blind; the defender lines up first and the attacker sees it (history: the defender usually drew up first);
  or you see the computer's line-up (it is predictable anyway, but showing it breaks the symmetry rule).
- A battle opened by walking onto an unseen army (moves design 2.6) starts like any other; the board shows everything
  from day 1.
- Battles you are not in: no board, no prompt, only the finished record (light fog hides them).

### 4.2 The unit triangle

The orders of package B are where the triangle becomes a choice:

| Triangle line | Order that uses it | Its counter |
|---|---|---|
| Pikes hold horse (x1.25 both ways) | put pikes opposite their knights in the line-up | the enemy's knights may not go where you guessed (blind day 1) |
| Horse rides down shot and guns (x1.4 in the open) | knights to the flank facing crossbows; on rough ground they lose it (x0.7) | pikes moved up into that lane |
| Shot and guns wear pikes down from the back | keep guns in the reserve, fire at their pike lane | a broken centre exposes your reserve |
| Guns against walls (x2) | in a storm, fire at the garrison (the centre: today's default) | the garrison's castle bonus |

The board shows each pairing as a word with its reasons, computed from the same functions the hit uses (spec R26), so the
words cannot drift from the numbers.

**Balance note:** knights are the weakest era 1 troop in the frontage study (6 knights about 25 % against other mixes). Good
fills make knights useful (flank against crossbows), which is a small fix by play rather than by numbers.

### 4.3 Sieges and storms

- **A storm** is the assault battle: the garrison holds the defender's centre. For the attacker, the fire order defaults to
  the centre (the garrison); fills choose who faces the walls (guns are x2 at walls but defend 1); **Withdraw from day 2 is
  "call off the storm"**, a key choice the siege design wants (a failed storm still hurts the garrison).
- **The defender** with a field army beside the garrison orders its flanks; a lone garrison has no choice and is fought at
  once (D17).
- Besiege or Storm stays a map decision (sieges design 4.5); the board adds nothing before the storm starts.

### 4.4 Several battles in one season: the prompt

**Settled on 2026-11-25** (build spec D23, R47): one question "Fight your N battles automatically?" with Yes, No and "Don't
ask again". The proposal below, with ticks by battle, is the earlier idea and is not what is built.

The owner wants a prompt "Fight your N battles automatically?" with a setting to turn it off.

**Proposal:**

- When End turn reaches the battles phase and **two or more** battles of yours wait (owner decision Q7 sets the number),
  the season pauses once, before the first, with a small window:

  ```
  You have 3 battles this season
    [x] Play  Cerano      your 4,000 against 3,200   Even
    [ ] Play  Novara      your 2,500 against 800     Overwhelming
    [ ] Play  Asti        your 1,000 against 2,600   Poor
  [Play the ticked ones]   [Fight all automatically]
  ( ) Don't ask again (Options: Your battles)
  ```

  The ticks start on the battles whose odds word is Poor, Even or Favourable (the close ones); Hopeless and Overwhelming
  start unticked.
- The ticked ones open on the board in hex order as the spec plans (R21); the others are fought with defaults in their
  place. The board's footer keeps "Auto this season's other battles" (spec D18).
- **The Options entry** "Your battles" gets three values: **Ask when I have 2 or more** (default), **Always play on the
  board**, **Always fight automatically**. "Don't ask again" sets "Always play on the board".
- A battle opened by your own move at idle never prompts: you chose it, the board opens, Auto is one click.
- Determinism: an unticked battle is played with defaults, which is what a missing order means (spec D12), so the action
  log needs no new record and replays the same. The prompt's choices live in the shell's battle hook (spec R19), not in
  the save; a load inside the pause asks again.

### 4.5 The computer: same rules, how it picks

- **Same rules:** the computer's side can give every order the player can. In v1 it gives the **default** every day
  (spec D9): its input stance, `_pick` fills, never "leave open", today's fire. That keeps every AI-versus-AI battle, the
  bands, the soak ranges and the AI tests exactly as measured.
- **A smarter computer later** (owner decision Q8), applied to **every** battle it fights so the rules stay the same for
  all, with the bands measured again:
  - Fill by matchup: the candidate with the best matchup word against the company opposite, then `_pick`'s order.
  - Withdraw when its front morale is under 30 % after day 2 and the odds word is Poor or worse, if it has a retreat.
  - Hold when its odds word is Favourable or better and it is the defender; Attack otherwise.
  - Fire at the enemy lane facing its weakest company.
  - Rules are pure and draw nothing from the luck streams (no "ai" stream draw inside a battle).
- In package C the computer also needs a tactic rule ("Stand fast when its centre is under 30 %"), which is a reason to
  keep tactics for the card system.

### 4.6 Economy, war score, debt

No order costs money or goods in packages A and B. Withdrawing early saves men (upkeep, refills) and loses the battle's war
score; fleeing loses the guns (60 ducats a battery plus goods). These prices are already in M7; the board only makes the
choice visible.

---

## 5. The owner's decision and what is left for later

**Decided (2026-11-26 and 2026-11-27): watch only** (section 3.0). The earlier recommendation was package B; it, package A
and package C are kept for a later version. Answered and no longer open: Q1 (no package in v1), Q2 and Q3 (no fire orders
and no held flank in v1), Q5 (no presets), Q6 (Withdraw from the second round), Q7 (the End-turn question, 2026-11-25) and
Q11 (no tactics now).

**Questions that matter only if orders come back** (none blocks v1; the numbers are kept):

| # | Question | Options | Recommend |
|---|---|---|---|
| Q4 | What you see on day 1 when you line up yourself | (a) **their army list, not their line-up** (both deploy at the same dawn); (b) the defender lines up first and the attacker sees it; (c) the computer's line-up shown | **(a)**; (b) is a good later rule for scouts or a cavalry general |
| Q8 | The computer's orders | (a) **defaults (today's fight); a matchup and morale rule for every battle as the first follow-up, bands measured again**; (b) the rule at once | **(a)** |
| Q9 | How much better is a played battle than Auto? | (a) **a little: 5 to 15 points of win rate in an even fight**; (b) a lot, playing is the way to win | **(a)**: you will not want to play every battle |
| Q10 | Help before the day is fought | (a) **matchup words with reasons**; (b) also the men each side may lose today (a range) | **(a)**; (b) after a playtest (whether v1 shows the words: build plan question 8) |
| Q12 | Stance as a pace dial | (a) **keep today's numbers (Attack and Hold trade evenly; Attack is faster and bloodier) and say so on the board**; (b) a balance pass to give stances counters | **(a)** first; revisit with the computer's rule (Q8) |

---

## 6. Mockups, and what changes in the build spec and plan

### 6.1 Mockups to draw before any build

**Reduced for the watch-only v1:** only the build spec's Appendix B mockups are drawn (MK1 and MK3 to MK6). **None of MK-O1
to MK-O7 below is drawn for v1**; they belong to a later version with orders.

These extend the spec's Appendix B (MK1 to MK6, gate BB0). One battle throughout: Savoy against Milan at Cerano, 4 against
4 companies (pikes, pikes, knights, bombards against pikes, knights, crossbows, pikes), code-drawn Studiolo look, 1280 x 720
with a 2x crop, as the tile window's mockups were made (artifact pages, no repository file).

| # | Mockup | What it must show | Replaces or extends |
|---|---|---|---|
| MK-O1 | **The line-up (day 1), package B** | three empty lanes with choosers, the usual pick marked; the preset row; the enemy army list without positions; the stance switch; Fight day 1 | extends MK2 |
| MK-O2 | **A dawn mid-battle, package B** | one open flank with its chooser including "Leave open" and its price; the fire chooser on the reserve row with three lane words; Withdraw's hover with both prices; the flee line on the tug bar | extends MK3 (one fire chooser instead of per-company chips) |
| MK-O3 | **The round card** | per-lane losses; the dice with multipliers; a sentence tied to each order given (a fill, a fire order, an open flank); both stances named | extends MK4 |
| MK-O4 | **The battles prompt** | three battles with odds words and ticks; Play the ticked ones / Fight all automatically; "Don't ask again"; the Options entry with its three values | extends MK5 |
| MK-O5 | **Package A for comparison** | the same dawn as MK-O2 with only the stance switch, so the owner can feel the difference | new |
| MK-O6 | **Package C extras for comparison** | the tactics tray (Charge, Volley, Stand fast), one used; the forecast ranges under each lane | new; drawn only if the owner wants C considered |
| MK-O7 | **The matchup hover** | a candidate's word with its reasons ("Pikes against horse +25 %", "Rough ground: horse -30 %"), and the triangle legend | extends MK6 |

The art director reviews the look, the creative director reviews the fun (each decision with a price, a short round)
before the owner sees them.

### 6.2 What would change in the build spec and plan if package B is chosen later

**Not applied: B is not chosen for v1.** The rule and task numbers refer to the spec and plan as they stood before the
watch-only cut, kept here as the starting list for a later version.

**Spec, decisions:**

- **D1** becomes: stance, fills (with "leave open" on a flank), and one fire order per side per day; presets are view-only.
- **D18** is replaced by the prompt of 4.4 (the footer button stays).
- **D19** becomes three values: Ask when 2 or more (default), Always play, Always auto.
- Q1, Q4 and Q5 of the plan's section 9 are answered by Q1, Q7 of this doc; Q3 stays as recommended.

**Spec, rules:**

- **R2:** orders become `{stance, fills, fire}`; `fills` maps a lane to a fighter key **or to "open"** (flank lanes only);
  `targets` is replaced by `fire`, one lane or absent.
- **R3:** a fill of "open" leaves the lane empty at deploy; the default pick skips it; the broken-lane and wheel rules apply
  unchanged; the centre can never be "open" while the reserve has a company that could fill it.
- **R4:** rewritten: every ranged company still in the reserve after deploy shoots the `fire` lane, falling back as
  `target_at` does; with no `fire`, today's targets. (If the owner picks Q2 (b), R4 stays as written.)
- **R6:** new refusals: "open" on the centre ("the centre must be held while you have a reserve"); "open" on a closed lane;
  `fire` on a closed lane; `fire` with no ranged company in the reserve. The per-company target refusals go.
- **R24:** the plan's `targets` rows become one `fire` row (the lanes allowed, each with its matchup against the company
  there now, the default); each flank fill slot gains the "open" candidate with its price text; a new `presets` list
  (name, fills, each fill checked); the enemy's day-1 line-up is not in the plan (R25 already says so).
- **R26:** `BattleMatchup` also gives the word for "open" (the wheel against your centre) and for a fire lane.
- **R29:** a price line for "Leave open" ("this lane counts as broken: your centre loses 10 % morale a day, and their
  company there strikes your centre at +25 %"), from `WarDef.flank_morale` and `flank_permille`.
- **R33, R34, R35:** the footer gains nothing; the chooser gains "Leave open"; R35's target chips become one fire chooser
  on the reserve row; the preset row on day 1.
- **R41:** keys for the presets (for example F1 to F4 on day 1) and for the fire chooser.
- **R43, R44:** the prompt (a SeasonFlow step before the first wait, listing the waiting battles from the season's
  battles; the hook's `wants` reads the ticks); "Don't ask again" writes the setting.
- **Unchanged:** R1 (the identity), R5 (stance, Withdraw from day 2), R7 to R23 (the live battle, the season, the save,
  the replay), R25, R27, R28, R30, R31, R32, R36 to R40, R42, R45, R46.

**Plan, tasks:**

| Task | Change |
|---|---|
| BB0 | the mockups of 6.1 in place of MK2 to MK6's current briefs; the owner answers Q1 to Q12 |
| BB1 | fills with "open", one fire lane instead of per-company targets; tests in `test_combat_orders.gd` for "open" (flank, centre refused, day 1 never-held lane), fire lane and its fallback |
| BB6 | `BattlePlan` fire row, "open" candidates, presets; `BattleMatchup` for "open" and fire lanes; tests |
| BB7 | the battles prompt and the three-value Options entry; `test_battle_wait.gd` gains the prompt cases (ticks, all auto, don't ask) |
| BB9 | `target_chip.gd` becomes `fire_chooser.gd`; the preset row; "Leave open" in `fill_chooser.gd`; their tests |
| BB11 | the monkey's counter `board_targets` becomes `board_fire`; add `board_open_lanes`, `board_presets`, `board_prompts` |
| BB12 | the `orders` soak suite's random hook uses "open" and fire; it also reports a **scripted good player** (matchup fills, fire at the knights, withdraw under 30 %) against Auto in even fights, to check Q9's 5 to 15 points |
| BB14 | README: the orders, the presets, the prompt, the Options entry |

The effort stays about the same as the plan's (one widget simpler, one prompt added): about 19 worker-days.

---

## 7. Risks

**For v1 (watch only):** watching may feel passive, and about 10 rounds mean about 10 clicks a battle (build plan question
6; Auto stays one click); the 10-round retune moves every measured battle (build spec 1.3). The risks below belong to a
later version with orders.

| Risk | Where | Answer |
|---|---|---|
| Playing beats Auto by too much, so every battle must be played | the triangle against the computer's blind `_pick` | measure in BB12 against Q9's target; the computer's matchup pick (Q8) as the first follow-up |
| Focus fire makes guns even stronger | 2.5 | the `orders` suite reports 4 pikes + 2 bombards with focus; the bombard fire cut of the frontage study is ready if needed |
| "Leave open" becomes a never-break trick | 2.4 | the centre rule (Q3); a test that an army with only flanks open still breaks by morale |
| Withdraw on any day lets a side "hit and run" every season | 2.2 | the price (5 or 10 % of men, morale to 25 %) and the slow morale recovery after it (`morale_recovery`); watch the war report's withdraw count |
| Stance feels meaningless (fact 1) | 2.1 | the round card says it plainly ("both attacked: heavy losses"); Q12 keeps the door open |
| Too many clicks across a long war | 3.1 principle 5 | the prompt, presets, Auto, D17; the playtest counts clicks per battle |
| Package B's tactics wish grows into cards early | owner's appetite | cards stay M24, from the tech tree and generals, as approved in `battle.md` |
| The day-1 blind line-up feels like guessing | 4.1 | the enemy's line-up follows a readable rule (infantry centre, horse on the wings), shown in the legend; Q4 (b) as a scout rule later |

## 8. Smallest first version

Watch only (section 3.0): the board as a window, the automatic line-up, Next round, the round card, Withdraw from the second
round, Auto to the end, the End-turn question, and battles of about 10 rounds. The earlier floor with orders (package B
without presets: a stance each day, fills with the day-1 line-up, "Leave open" on a flank, one fire order, the battles
prompt) is the starting point if orders come back.

## 9. Genre notes (for reference, not copied)

- **Europa Universalis:** no orders inside a battle; choices are made before it (general, ground, army mix, frontage), and
  the daily dice are shown. Light to run, but the player only watches. Hexa's board adds a few choices without leaving
  that lightness.
- **Imperator and Crusader Kings II:** one tactic per phase with counters; a simultaneous hidden choice. Close to our stance,
  and a model if Q12 (b) is ever chosen.
- **Total War:** full real-time battles with auto-resolve; when auto-resolve is clearly worse, players feel forced to fight
  by hand. The reason for Q9's small target.
- **Humankind:** battles in rounds on the map, with reinforcements and retreat; many players auto the obvious ones. The
  reason for the prompt's ticks on close battles only.
- **Commands and Colors** (board game): a left, centre and right with orders given to a section. Our three lanes read
  the same way.
- **Hannibal: Rome vs Carthage** (board game): battle cards played in a duel. The model for M24's cards, not for v1.
- **Battle Brothers, Heroes of Might and Magic:** full tactical battles; too heavy for a 4X where a war has dozens of
  battles.
