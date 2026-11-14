# Castle areas and clear move refusals

**Status: draft addendum to `docs/design/sieges-and-retreats.md` section 4, for the 0.2.2 build. Creative review: approve with changes (section 12); awaits the owner.** The owner
chose the idea in the v0.2.1 playtest ("a castle holds its area"); the numbers below are for the owner to confirm.

**Why.** In the playtest the owner said: "I wasn't sure if I want to siege every province rather just the main castles."
Today every enemy place, castle or not, needs an army on it for at least 2 seasons (`SIEGE_MIN_SEASONS`). In the same game
the owner could not walk armies deep into Granada, and the game only said "They cannot get there."

**Principles it is for** (`docs/research/fun-principles.md` v2): **2** (a castle's level now buys land, so building one is a
real choice; the attacker picks which castle to besiege), **3** (the card says why land cannot be taken and what taking the
castle opens), **6** (a brake on snowballing: you can nibble a country's open edges, but its heartland waits until you
break the castle that holds it; about a third of the land is held, section 2.2).
Checked for harm: **11** (one new rule, a few new lines of text, no new screen), **1** (wars must still move land, measured
in section 2.5), **12** (the AI must play it, section 3), **16** (tribal lands are not touched, section 2.4).

A "province" here is one hex of the map, as everywhere in the game.

## 1. Goal

The player attacks a country by taking its **castles**. A castle holds the land around it: while the castle stands, enemy
armies may walk, forage and camp on that land, but may not take it. When the castle falls the land lies open, and the army
walks in and takes it, one hex a season per stack. Land that no castle holds is taken by walking in.

Fun: the war has a shape (siege the castle, then sweep the land), the siege is the decision (Besiege or Storm, relieve or
let go), and the long march over open land is quick. The defender's castle level matters: a large castle holds more land.

## 2. Rules

### 2.1 What the map looks like (measured)

Measured on the starting map, Europe 1480 and random worlds 7, 11 and 21 (scratch scripts, not in the repo):

| | Europe 1480 | Random 7 | Random 11 | Random 21 |
|---|---|---|---|---|
| Owned provinces | 4,311 | 6,866 | 6,912 | 7,077 |
| Countries | 49 | 36 | 38 | 37 |
| Castles (levels 3 / 2 / 1) | 67 (7 / 42 / 18) | 60 (5 / 31 / 24) | 51 (2 / 36 / 13) | 54 |
| Castles a country has: median, most | 1, 5 | 1, 4 | 1, 3 | |
| Provinces a country has: median, most | 43, 637 | 144, 696 | 148, 449 | |
| Countries with no castle | 0 | 0 | 0 | 0 |
| Capitals with no castle | 0 | 0 | 0 | 0 |

So castles are few: a typical country has one. The country that owns 637 provinces (Muscovy) has only a few. This decides
the design: an area cannot be "all the land of the country", and it must have a reach.

Region names exist on the Europe map only (`Province.region`, from `regions.py`). Random worlds have none.

### 2.2 Three ways to give land to a castle

An area is made of the province's **own country's** land that joins the castle by a path of its own provinces (so a colony
across the sea belongs to no castle on the mainland). Each province belongs to at most one castle: the nearest by path
(ties: the higher level).

| Way | Rule | Land held (Europe / random) | Provinces per castle (median, most) |
|---|---|---|---|
| **A. Whole country** | Nearest castle, no limit. | 89% / 95% | 30, 637 / 82, 590 |
| **B. Reach by level (recommended)** | Nearest castle within its reach: tower 3, castle 4, large castle 5. | 38% / 31% | 23, 65 / 34, 91 |
| **B2. Reach by level, longer** | Tower 4, castle 6, large castle 8. | 52% / 50% | 27, 124 / 52, 204 |
| **C. Same named region** | Castle in the same historical region. | 16% / 0% | 8, 32 / none |

- A is simplest to say ("take the castle, take the country") but a single castle then holds hundreds of provinces. In the
  war run below, land moves 3 times slower (section 2.5). Rejected.
- C is period-flavoured but random worlds have no regions, most regions have no castle, and it holds only 16% of the land.
  Rejected.
- B is one number a player can read ("a large castle holds land up to 5 hexes away") and it makes castle level a choice
  (principle 2): upgrading a castle holds more land. The reach numbers go in `data.py` (`CASTLE_AREA`) and are tuned in play.
  B2 is the same rule with larger numbers; it held up worse in the run (more wars that move nothing).

Why a short reach is right: the nearest castle is a median of 5 provinces away from the places the AI takes today. A reach of
3 to 5 holds the heartland around each castle and leaves the edges, the frontier and the empty land free. Armies move 6
points a season on plains, so a reach of 5 is about one season of march.

### 2.3 Rules in words (recommended: B)

1. **Held land.** A province inside the area of a castle that its owner still controls is **held**. An enemy army may enter,
   stand and forage there as today (the supply rules do not change), but **no siege starts there and it cannot be taken**.
   The province panel and the card say "Held by the castle of X".
2. **Open land.** Any other enemy province is **open**: an army that stands on it alone (no enemy army there, no battle) at
   the end of the season **takes control of it at once**. There is no 2-season floor and no meter on open land. The
   militia-size check stays (an army needs more men than the militia, `MILITIA_MEN` 500).
3. **Castles keep the sieges.** A garrisoned castle is besieged or stormed exactly as 0.2.2 says. The 2-season floor now
   applies **to castles only** ("a castle holds out at least 2 seasons").
4. **When a castle falls** (siege or storm), its area is **open**: from the next season on, the army (and any other army
   of the taker) walks in and takes each province by standing on it at the end of a season. The land does **not** flip at
   once. (Reason: section 2.5.)
   The log says "The castle of X has fallen: its land lies open (N provinces)". The next season matters: the order the
   provinces are checked in must not change who gets what, so the rule reads the castle's state at the start of the step.
5. **When a castle is retaken** by its owner, the area is held again from that moment. Provinces the enemy already took
   stay taken until the owner walks back in.
6. **Your own land is never held against you.** A province you own that an enemy took is retaken by walking in, at the end of
   the season, even while the enemy holds the area around. (Today it needs a siege.)
7. **A capital with no castle** holds nothing: its land is open. This is rare (every capital starts with a castle, and the
   AI builds one at its capital first, `ai.py`). The capital's +3 war score and "capitals return at peace" stay as they are.
8. **Peace** moves provinces as today: a province the taker controls goes to it, capitals return. A siege ends at peace.
   Held land stays with its owner.
9. **The war still ends at score 5** (AI) as today (`season.war_timeouts`). A fallen castle counts as one province, so a
   typical war is: break one castle (2 to 7 seasons), then take about 4 open provinces.

### 2.4 Colonies, natives, frontier

- **Colonies** on another landmass have no castle on their own landmass, so they are **open**. A young colony may build a
  tower (`building.py`), and a tower holds 3 hexes around it. This gives a colony fort a purpose. Open colonies fall to one
  season on the land (today 2): see the risk in section 7.
- **Tribal lands** have no owner and are outside the war rules. This addendum does not touch them (principle 16: no reward
  for raiding them is added).
- **Frontier and empty land** beyond every reach is open: walk in and take it.

### 2.5 What it does to war pace (measured)

All-AI games, 4 worlds, 240 seasons each, same method as the 0.2.2 brief (`WAR_LENGTH_AI` 16). Scratch runs with a **minimal**
AI change (a stack never marches at held land; open land is a one-season target; everything else as built). The "today" row
reproduces the brief's after-review numbers exactly (20.2 / 22.7 / 20.5 / 15.0).

| Provinces moved per decade | Europe | Random 7 | Random 11 | Random 21 |
|---|---|---|---|---|
| Today (0.2.2 as built) | 20.2 | 22.7 | 20.5 | 15.0 |
| **B: reach 3 / 4 / 5** | 14.8 | 26.8 | 31.2 | 25.8 |
| B2: reach 4 / 6 / 8 | 15.8 | 23.2 | 29.5 | 14.7 |
| A: whole country | 6.8 | 6.5 | 10.8 | 9.7 |

| Wars that move no province / end by the length limit | Europe | Random 7 | Random 11 | Random 21 |
|---|---|---|---|---|
| Today | 12% / 28% | 0% / 18% | 4% / 33% | 13% / 27% |
| **B: 3 / 4 / 5** | 23% / 33% | 9% / 18% | 11% / 19% | 21% / 36% |
| B2: 4 / 6 / 8 | 29% / 48% | 3% / 14% | 5% / 18% | 24% / 42% |
| A: whole country | 40% / 47% | 39% / 50% | 31% / 38% | 38% / 53% |

Read:
- **Today 92% of the AI's siege captures are open provinces** (Europe: 168 open, 13 castles in 240 seasons). With the new rule
  the AI's targets change almost completely: castle captures go from 13 / 19 / 16 / 23 to 13 / 25 / 33 / 28.
- **A (whole country) stalls wars**: 4 in 10 move nothing. It confirms the reach is needed.
- **B holds the pace in three worlds out of four** and is the best of the three. Europe (14.8) and Random 21 (wars moving
  nothing 21%, ending by the limit 36%) just miss the brief's targets (17 a decade, 20%, 35%). The AI used here is only a
  stub; the real AI work (section 3, a stack sweeps the open land after a castle falls) is expected to close the gap, the same
  way the 0.2.2 AI work did. **This is an estimate: the build must re-measure** (section 9).
- **The largest country's land share is the same as today** within noise (Europe 14.9%, Random 7 10.0%, Random 11 6.5%,
  Random 21 7.5%; today 14.9 / 9.9 / 6.5 / 7.7).
- **Why land does not flip at once when a castle falls:** a castle's area is 23 provinces on the median. Flipping it would give
  the taker score 5 in one move (the AI war ends at once) and take half of a small country in one season. That is the
  snowball (principle 6). Walking in costs one season a stack per province, which is the pace of today.
- Paper estimate, not measured: a player with 3 stacks needs about one siege (2 to 7 seasons) and then 4 to 8 seasons to
  sweep, so a 32-season player war holds 2 to 3 castles. Today it holds about 4 to 5 places of any kind.

## 3. Player and AI

- **Player.** Right-click on held land: the army moves there (if it can) and a line says "Moves in, but cannot take the
  land: held by the castle of X". Right-click on open land: it moves and takes it at the end of the season. Attack a castle:
  Besiege or Storm as 0.2.2. The odds card of a castle gets one line: "Taking it opens N provinces to you."
- **AI** (`ai.py`, small changes to the 0.2.2 AI):
  1. Targets. `_besiege_nearest` and the fallback march skip held provinces (no forecast: `siege_forecast` returns None for
     them) and count open provinces as 1 season. So its targets are, in order: a castle 2 or 3 it can take in time, then
     open provinces, then castles 1.
  2. After a castle falls, spare stacks **fan out** over the opened area, one province each (the 0.2.2 split-stack rule, now for
     open land).
  3. A defender's stack retakes its own land first when it can (own land is never held against it).
  4. The AI builds towers and castles where it already does; the reach is a small extra value for a border castle
     (`ai.py` `invest` value for "castle", a number to tune, not a new system).
- **Cost:** one dictionary look-up per target; the area map is built once per change (section 9). The AI time per season must stay within the brief's limit (not measured yet).

## 4. UI

Mockup to draw (art director), proposed as `docs/design/ui/21_castle_area.png`, Kenney look, ink outlines. **First version
(creative review): only the war-stack view of point 1 below, the chip of point 2 and the card of point 3.** The area is
counted along the land, so a player cannot count it by eye: the map must show it, and the panel chip alone does not
(hovering hex by hex is a chore). So one map view is never cut:

- **With a war stack selected,** the areas of countries at war with you get the **thin dashed ink line** in the owner's
  colour and the light tint (about 12%) inside; open land of those countries has no line. With no stack selected the map is
  unchanged. This is the only map layer in the first version.

Later (not in 0.2.2), the full look:

1. **The map, hover on a castle (or on any province in an area).** The area's outer edge gets a **thin dashed ink line** in the
   owner's colour with a very light tint (about 12%) inside; a small pennant in the same colour sits on the castle. Held
   land shows a tiny closed-padlock mark in the corner of each province **only** when the player has a war stack selected
   next to it (so the map stays calm). An **open** area (castle fallen) shows the same line **dotted and grey**, with an
   open-padlock on the castle. Select a war stack: areas of countries at war with you are outlined faintly. No always-on layer.
2. **The province panel.** A chip under the name: "Held by the castle of Toledo (castle, 4 hexes)" with a shield, or "Open
   land: no castle holds it" (plain), or "Open: the castle of Toledo has fallen" (a broken-shield). A castle's own panel
   adds "Holds 23 provinces" and its reach, with a hover that lists the provinces. Every number has a hover (principle 3).
3. **The hover card on a refused or held hex** (two lines, like the siege card): a red first line with the reason, a grey
   second line with the way out. Example:
   `Cannot take this land yet` / `Held by the castle of Toledo, 3 hexes away. Besiege it: falls in about 4 seasons.`
   Open land card: `Takes control at the end of the season.`

The defender needs words too: when open land of yours is taken, the log line names it as today ("Toledo's land: Talavera
taken by Portugal"); when one of your castles falls, the log line and the ribbon say how much land now lies open.

Also: a ribbon and log line when a castle falls ("The castle of X has fallen: its land lies open (N provinces)"), and the
task flag line of a defender whose castle holds land under attack stays as in 0.2.2. With no stack selected, only the panel chip shows.

## 5. Clear move refusals

Today `app.right_click` ends with `stuck_reason(group) or "They cannot get there."` and `movement.stuck_reason` knows only the
cases of units with no moves left. The causes the owner met (mountains with slow bombards, the zone of control beside an
enemy castle, the stack limit) have no words. Add `movement.refusal(world, group, pos)`: it returns the first reason that
fits, in this order, and the app shows it as the toast **and** as the hover hint before the click (principle 3).

The rules behind each reason are in `movement.py` (`may_enter`, `plan`, `zoc`, `reachable_group`), `military.can_stand`
(stack limit, civilians, generals) and `terrain.move_check` (ridge, pass, battle).

Creative review: the old rows 10 and 11 are one case (the room left) and are merged; the old rows 13, 14 and 16 (now 12, 13 and 15) are **notes**, not
refusals (the move happens), and say so; every refusal now ends with a way out where one exists.

| # | Case (where in code) | Message | Kind |
|---|---|---|---|
| 1 | The stack is in a battle (`move_check`) | In battle: order Withdraw to leave. *(exists)* | refusal |
| 2 | Ridge crest between the hexes (`move_check`) | Nobody can cross the ridge here; armies need a pass. *(exists)* | refusal |
| 3 | Pass shut by snow (`move_check`, `pass_wait`) | The Brenner pass is closed by snow until spring. *(exists; the march waits)* | refusal |
| 4 | Target is sea or lake for a land stack (`may_enter`) | Armies cannot walk on water: load them onto a ship. | refusal |
| 5 | A unit has no moves left (`stuck_reason`) | They foraged this season... / They have already moved... / ...raised this season... *(exists)* | refusal |
| 6 | Foreign land, not at war (`may_enter`) | Not at war with Portugal: their land is closed to your army. | refusal |
| 7 | Wagons, settlers and the like on enemy land (`may_enter`) | Only soldiers, generals and scouts may enter enemy land: split off the wagons and settlers. | refusal |
| 8 | An enemy army on the target (`plan`: `occupied`) | An enemy army stands there (4,200 men). Right-click again to attack. *(and the attack's own reason when it cannot: "Too shaken to attack", "Not at war"...)* | refusal |
| 9 | Another country's army on the target, no battle (`can_stand`) | Another country's army stands there: pick another hex. | refusal |
| 10 | Own or allied stack full or too full (`stack_limit`) | No room: the stack there has 4 of 6 troops and you are sending 4. Split the army or pick another hex. *(full: "has 6 of 6")* | refusal |
| 11 | Too many civilians or two generals (`CIVILIAN_LIMIT`, one general) | A hex holds 3 settlers and scouts. / A hex holds one general. | refusal |
| 12 | The way passes an enemy castle (`zoc`) | Stops beside the castle of Granada this season: enemy castles halt a march. Goes on next season. *(shown as the hover and when the plan ends there)* | note |
| 13 | The march takes more seasons (slow unit, rough ground, `path_to`, `next_season_reach`) | About 3 seasons away: the bombards (4 moves) and the mountains (3 each) slow the march. | note |
| 14 | No land route in 4 seasons (`path_to` empty) | No way there by land: a ridge or the sea lies between. / Too far: more than 4 seasons away. | refusal |
| 15 | Held land (new, part of item 7) | Moves in, but cannot take it: held by the castle of Toledo. Take the castle first. | note |
| 16 | Nothing above fits | They cannot get there. *(kept, should be rare; each use is logged in the playtest build to find a missing case)* | refusal |

Rules for the wording: say the cause, the number and the way out in one line; the names are the real ones (the pass, the
castle, the slowest unit's name); 13 names the slowest unit and the dearest ground on the route (the data is in
`unit_moves` and `step_cost`). A note is shown in the same place as a refusal but in the normal text colour, never red,
so the player can tell "this happens, slowly" from "this does not happen".

## 6. Interactions

- **Sieges (0.2.2):** the meter, hunger, storm cut, relief and the badge are unchanged and now apply to castles only. Open
  land has no meter, no badge and no "besieged" output stop.
- **Economy:** a held province keeps producing while enemies stand on it (they may forage it, as in any enemy land). Only a
  *castle* under siege stops its output, as 0.2.2. Open land taken by an army changes control at once, so its
  output changes hands at once (today 2 seasons later).
- **War and peace:** `war_score` counts provinces by controller; unchanged. Peace transfer as today. War goals and peace
  (`war-goals-and-peace.md`): a goal "take the castle of X" becomes natural; a later design can read areas.
- **Tech:** the `siege_points` tech helps a castle's meter, not its reach. A "castle reach +1" tech is a later idea, not now.
- **Debt, colonies:** colonies are easier to take (2.4). Debt unchanged.
- **Supply:** unchanged; a stack in held land forages as in any enemy land. The six-season "driven out" rule for a
  province held without support stays and acts as a natural limit on deep raids.

## 7. Risks

- **Slow wars (principle 1).** Measured: fine in 3 worlds of 4, a small miss in 2 (section 2.5). Fallback: lower the reach (2 / 3
  / 4) before touching the war length or the floor.
- **Turtling.** A player who builds large castles holds a lot. The cost is the castle (money, the Trace italienne tech) and a
  big castle is the target the AI picks first; the defender's relief decision is the 0.2.2 one.
- **Weak colonies.** Open colonies fall in one season. Mitigation: a colony tower holds 3 hexes (2.4). Watch it in the
  playtest; the fallback is the 2-season floor for colonies only.
- **Reach edges look arbitrary.** A province 6 hexes from a large castle is free, 5 is held. The hover border makes the line
  visible; the numbers are small enough to read.
- **A castle on an island or a pocket holds nothing.** Fine: a country whose castle is on another landmass leaves its mainland
  open.
- **Exploit: building a tower next to the enemy's army to hold land at war.** A tower costs and takes seasons to build
  (`building.py`); allowed, it is a real defence. The area changes only at the start of the next season's step.
- **The AI wins on open land and skips the castles.** About two thirds of the land is open and a war ends at score 5, so
  an AI can end a war on five frontier hexes without a siege. Then sieges are not the decision, only a detour. Guard: the
  new "AI uses it" line in section 9 (half the wars that move land include a castle). Fallback: the AI's targets weigh a
  castle above open land when the castle can fall before the war ends.
- **Land falls fast for the defender.** Open land goes in one season (v0.2.1 pace, faster than the 0.2.2 build), so a
  player may see their frontier drop in a season and feel the castle did nothing. Answer: the war-stack area line shows
  what the castle holds, and the log names the castle in each capture of its land.
- **Principle 16:** nothing here lets a conqueror take tribal land more easily. Colonies of a European country are the
  ones that become open.

## 8. Smallest first version

Build now (0.2.2): the rule in 2.3 with reach B (3 / 4 / 5), open land taken at the end of the season, castles keep the
sieges and the floor, the AI target change, the province-panel chip, the war-stack area line (section 4, the one map
layer), the hover card and odds-card line, the log line, and the messages 4 to 16 (section 5). Not in the first version:
the hover-on-castle border, the dotted "fallen" line, the padlock marks, the "holds N provinces" list, the castle-fall
ribbon (the log line carries it), a tech for reach, areas on the minimap.

## 9. Save impact, AI changes, build order, done when

**Save impact.** None of the needed numbers is stored: the area is worked out from owner, castle level and the castle's
controller. The world keeps a cache (`_areas`, default `None` in `WORLD_DEFAULTS` and listed in `WORLD_CACHES`, cleared in `forget_castles()` which
already runs when a castle is built or lost, and when a peace changes owners). No new field on `Province` or `Unit`, no
`saves.VERSION` change. Old saves: a militia siege running on a held province is lifted at the first step ("held by the
castle"); one on open land ends at that step. The release notes say so.

**AI changes.** Section 3, three small edits in `ai.py` (targets, fan-out after a fall, retake own land first) and one in
`war.siege_forecast` (None for held land, 1 for open land).

**Build order.**
1. Data and rule: `CASTLE_AREA` in `data.py`, `world.area_of(pos)` (cached), `war.held_by(world, pos, tag)`, the open-land
   capture in the siege step, the castle fall opens the area, tests for 2.3 (each point).
2. Move refusals: `movement.refusal`, the app toast and the hover hint, a test for each row of section 5.
3. AI: targets, fan-out, retake; the all-AI run of section 2.5.
4. Screen: panel chip, hover border, card lines, log line and ribbon; mockup 21 drawn first by the art director.
5. Proof: tests, soak, save-compat, perf, the measurements below.

**Done when.**
- No open bug issue; the suite, soak, save-compat and perf pass; AI time per season up by at most 10%.
- **Rule tests:** an army on held land starts no siege and takes nothing (in 2.3 point 1); on open land it takes control at the
  end of the season in one season; a castle falling opens its area from the next step and not before; retaking own land is one
  season; a castle never falls in under 2 seasons by siege (the Storm on arrival still can).
- **Pace** (all-AI, 4 worlds, 240 seasons, the brief's targets): at least 17 provinces per decade in each world, at most 20% of
  wars move nothing, at most 35% end by the length limit; the largest country's land share by 1600 not above today's.
  If Europe or one random world misses by a little, lower the reach by one first.
- **AI uses it:** at least half of its captures of castles 2 and 3 follow 2 or more seasons of siege; **at least half of
  the AI wars that move land include a castle taken or besieged for 2 or more seasons** (so the AI does not win its wars on
  frontier land alone and skip the castles); no stack parked on held land for more than 2 seasons in any test game.
  (Creative review: the old line "60% of captures after a castle fell or on open land" was met by definition, since every
  capture that is not a castle is on open land.)
- **Open-land sweep:** in the all-AI run, report the median and the most provinces one war takes in the season after a
  castle falls. A war that takes more than 6 in that one season is a snowball to look at before release.
- **Refusals:** every row of section 5 has a test (the message and the case); in a scripted game the line "They cannot get
  there." appears in no test case we have built, and the playtest build logs each use.
- **Owner playtest:** take a castle and see its land open; with a stack selected, say which enemy land is held before
  clicking; try to take a held province and read why; send bombards over mountains and read the message; move onto a full
  stack and read it; Castile against Granada, 1484, deep into the country.

## 10. What it changes in the 0.2.2 brief

- Scope item 1 text: "every castle holds out at least 2 seasons" (the floor is for castles); open land is taken at the end
  of the season.
- **New item 7: Castle holds its area** (size M) and **new item 8: Clear move refusals** (size S).
- Item 4 (AI): targets and fan-out as in section 3. Item 5 (on screen): area chip, hover line, log line.
- **Done when:** the pace line "no place falls to a siege in under 2 seasons" becomes "no castle"; add the lines of section 9.
  The "Measured in the build" numbers are measured again after the rule, as above.
- **Size:** the brief was already at the top of what one patch holds, and this adds about a third. Creative review: that is
  more than one patch can carry safely, so the first version is already trimmed (section 8: no hover-on-castle border, no
  padlocks, no fallen line, no castle list, no ribbon; messages 10 and 11 merged). Cut list, in order, if it is still too
  big: item 6 of the brief (odds words) first as before; message 11 (civilians and generals: rare, the fallback line covers
  it); message 7's way out (keep the refusal); the AI fan-out, only if the targets are met without it; the odds-card line
  "Taking it opens N provinces" (the panel chip keeps the number). Never cut: the rule itself, the AI target change, the
  war-stack area line on the map (without it held land cannot be seen, and the patch repeats the playtest's "why can't I"),
  the panel chip, messages 4, 6, 8 to 10 and 12 to 15 (the cases the owner met).
- **If the build still runs long:** ship the clear move messages (item 8) in 0.2.2 and move castle areas (item 7) to
  0.2.3 whole, rather than ship a half rule. Item 8 answers the playtest note on its own; item 7 changes the war's shape and
  needs its pace re-measured.
- "Defaults" gains: **open land falls at the end of the season; a fallen castle opens its area, it does not flip it.**
- Not in 0.2.2 (unchanged): field forts. A field fort (design section 6) could later hold land like a tower; keep that in mind.

## 11. Questions for the owner

A hex is one tile of the map (one province). "Held" land cannot be taken while its castle stands; "open" land is taken by
standing on it. A season is one turn.

1. **How far around it does a castle hold the land?**
   - **(Recommended) Short, by size: a tower holds the land up to 3 hexes away, a castle 4, a large castle 5.** About a
     third of all land is held, the rest is open. In the test games wars moved land about as fast as now, and a bigger
     castle is worth building because it holds more.
   - Longer: 4 / 6 / 8 hexes. Half the land is held. Wars were slower and more of them took nothing.
   - The whole country: take its castle and all its land is open. Wars stalled: 4 in 10 took nothing. Not advised.
2. **When you take a castle, what happens to the land it held?**
   - **(Recommended) It is open: your armies walk onto it and take one hex each per season.** The war keeps today's pace,
     and spreading your armies to collect the land is part of the war.
   - It all becomes yours at once. Simple and striking, but one castle then gives about 23 hexes and ends most wars in one
     move.
3. **Open land (most of the land, including colonies and the frontier): how long must an army stand on it to take it?**
   - **(Recommended) One season: stand on it at the end of the season and it is yours.** This changes a rule you set for
     0.2.2 ("every place holds out at least 2 seasons"): with castles holding the heartland, the wait moves to the
     castles, and open land goes back to the v0.2.1 speed. Colonies fall faster; a tower in a colony holds 3 hexes.
   - Keep 2 seasons for every place. Wars get slower than in the tests (not measured), and the castle matters less because
     open land is slow too.

## 12. Creative review (2026-11-14)

**Verdict: approve with changes (made above).** It answers the owner's own playtest note and gives war a shape: break the
castle, then sweep its land. It puts the siege, the 0.2.2 decision, where it matters (a few castles, each worth a choice)
instead of on every hex. Castle level becomes a real build choice (principle 2), the odds card prices the reward (3), and
a heartland that holds while the edges fall is a brake you can name (6). Approved for the owner batch on the condition
below that it fits the release; otherwise the move messages ship alone.

Changes made:
- **One map layer is never cut.** The draft's first cut was the area border, which would leave a rule the player cannot
  see: the reach is counted along the land, so it cannot be counted by eye, and hovering hex by hex is a chore. That is the
  playtest's "why can't I" again (principles 3, 11). The first version keeps one cheap view: with a war stack selected, the
  enemy's held areas get a dashed line and a light tint. The hover-on-castle border, padlocks, the fallen line, the castle
  list and the ribbon wait.
- **Scope cut and a fallback.** The addendum adds about a third to a brief already at the top of one patch. Cut list made
  concrete (section 10), and a clean split if the build runs long: ship the move messages in 0.2.2, move castle areas whole
  to 0.2.3. Never half a rule.
- **A useless "done when" line replaced.** "60% of AI captures after a castle fell or on open land" was true by definition.
  Now: half the AI wars that move land include a castle taken or besieged 2+ seasons, so the AI cannot win on frontier land
  alone (principle 12). Added a measure of the sweep after a castle falls (snowball watch).
- **Honest principle claim.** "You cannot nibble a country" was not true with two thirds of the land open; now "the edges
  can be nibbled, the heartland waits for the castle".
- **Move messages.** Rows 10 and 11 merged (one case: room left). Three rows are notes, not refusals (castle halt, slow
  march, held land) and are shown in normal colour, not red. Each refusal ends with a way out where one exists (ship,
  split off wagons, pick another hex, take the castle first). 16 rows now.
- **Defender's view and the economy line** worded plainly (section 4, section 6).
- **Owner questions reworded:** terms defined once at the top; question 3 now says it reverses a rule the owner set for
  0.2.2 (every place holds 2 seasons) and that open land is most of the land, not only colonies and the frontier.

Fun risks to watch (measure in the build, then the playtest):
- **Stalemates:** Europe (14.8 a decade) and random 21 (21% of wars move nothing) miss the brief's targets in the scratch
  run. The fix order is right: real AI targets first, then a shorter reach, never a longer war.
- **Snowball when an area opens:** AI wars stop at score 5, so the sweep is capped; a player war (32 seasons, no score cap)
  can sweep a whole area with three stacks in about 8 seasons. That is the intended reward; watch it with principle 6.
- **AI walking over open land:** the new done-when line guards it.
- **Colonies too easy:** one season to take an open colony. Watch in play; the fallback (2 seasons for colonies only) is
  one number. A colony tower holding 3 hexes is a good new reason to build one.
- **Faster wars on random worlds** (26.8 and 31.2 a decade against 22.7 and 20.5): largest-country share unchanged, so
  accepted, but watch it.

Sensitive topics: none touched. Tribal lands are outside the rule, and nothing makes them easier to take (principle 16).
Colonies that become open are European colonies taken in wars between European countries.
