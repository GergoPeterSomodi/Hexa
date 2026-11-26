# Recruitment queue: raise companies, ready after one season (issue 463)

**Status: draft; the owner's answers of 2026-11-26 and 2026-11-27 are recorded. Nothing is built.** Grounded in the Godot code
with the moves-in-the-month build (`docs/architecture/moves-build-spec.md`) in the working tree, which is not released yet.

**Owner decisions (2026-11-26), fixed:**

1. Companies are queued with a **minus / count / plus** stepper in the tile window's Army tab, instead of an instant Raise.
2. Every company takes **one season** to be ready (all kinds the same for now).
3. Withdrawing a queued company gives **everything back** (ducats and goods), at any time before it is ready.
4. At most **3 companies queued per settlement** for now; later a barracks or other modifiers set it (data driven).
   Sharpened by decision 6.

**Owner answers (2026-11-26 and 2026-11-27), fixed:**

5. Companies queued together **train one per season, in turn**.
6. The queue limit of a settlement is the **smaller of 3 and today's per-season raise cap**: hamlet 1, village 1, town 2,
   walled town 3, city 3 (its cap of 4 comes down to 3).
7. A settlement **taken by force**: the queue is **lost** (the men go home; the ducats and goods are lost).
8. A settlement **besieged, or with an enemy army on it**: the queue **waits** (nothing finishes and nothing can be queued;
   withdrawing is allowed).
9. A settlement **ceded in a peace**: the queue is **lost**.
10. The tile window's footer queue shows **only the company in training now**.

## 1. Goal

You plan your army a season ahead: order companies, look at your money and the map, change your mind for free, and end the
season. The companies march out next season.

Why it is fun: raising becomes a commitment you can still take back, and a threat has to be seen coming. A town attacked this
season cannot produce defenders on the spot, so where you keep armies and when you start recruiting begin to matter.

## 2. How raising works today

`Military.raise_check` and `Military.raise` (`core/systems/military.gd`), action `raise {hex, kind, count}`.

- **Where and what:** your own settlement, not occupied, no other country's army on it (so never under siege). The settlement
  level gates the kind: pikemen and crossbowmen from a hamlet, knights from a village, bombards from a town.
- **Cap per season**, by settlement level (`FamilyDef.raise_cap`): hamlet 1, village 1, town 2, walled town 3, city 4.
- **Room:** 8 companies of one country on a hex.
- **Men:** a tenth of the people (`levy_permille` 100) of the hex and of your six neighbouring hexes. They leave at once.
- **Price:** ducats and goods at once (pikemen 25 and 1 iron).
- **Result:** the company exists at once. It joins an army on the hex that is fresh (no move points spent) and not marching,
  else it makes a new army. It eats, costs upkeep and can defend this season.
- **Mustering:** an army with a company raised this turn cannot walk this season. An order given to it is stored.
- **Taking it back:** disbanding the company in its raising season, on its home hex, refunds ducats and goods.
- **AI:** `AiForces` raises one company at a time, up to 2 a turn at peace and 4 at war, through the same action.

## 3. The new flow

### 3.1 Season by season

| When | What happens |
|---|---|
| Spring 1481, your turn | Plus queues a company at Turin. Ducats, goods and men leave now. Minus gives all of it back. |
| End season, computer turns | Computer countries queue by the same action. Your queued company does not exist yet: it cannot fight, be seen or be attacked. |
| End season, new `muster` step | After battles, sieges and the works step: in each settlement **the company in training** (the oldest queued) counts down one season. At zero it appears. The ones behind it do not count down. |
| Summer 1481, your turn | The company is in an army with full move points and can march at once. Upkeep and food start with this season. The next one in the queue is now in training. |

- The new `muster` step sits right after `works` and before the calendar turns, so the season report and the statistics for
  Spring include the company. Upkeep and supply have already run, so the queued season is free of both. (Today a company pays
  upkeep in its raising season, so this is a small saving.)
- A ready company joins the first army of yours on the hex (by id) that is not marching or storming, else it makes a new army
  (if the hex is full, it waits: 3.6). The "fresh army" condition is no longer needed, because points refill right after.
- **One company per season, in turn** (decision 5). Companies queued together at Turin in Spring 1481 are ready one a season:
  the first in Summer 1481, the second in Autumn 1481 (a third, in a walled town or city, in Winter 1481). A settlement
  musters at most one company a season.
- Withdrawing the company in training puts the next one in training at once; it is ready at the coming muster step.
- A company the computer queues into an empty queue during End season is ready in that same End season, as yours queued in
  your turn is. Both sides get it at the same moment.

### 3.2 Numbers (data, not code)

| Name | Where | Value |
|---|---|---|
| `recruit_queue_size` | `GameDefs` | 3 (the most any settlement takes) |
| `raise_cap` | `FamilyDef`, one per settlement level (today's data) | hamlet 1, village 1, town 2, walled town 3, city 4 |
| `raise_seasons` | `UnitDef`, one per kind | 1 for all four |

`Recruiting.queue_size(game, tag, hex)` is the **smaller of `recruit_queue_size` and the level's `raise_cap`** (decision 6:
1, 1, 2, 3, 3) plus a sum of modifiers (none yet; question 9), never below 0. The countdown reads `raise_seasons` through one
function too, so later modifiers have one place to go.

### 3.3 What replaces the cap and "mustering"

- **The queue limit replaces the per-season count.** Nothing counts the raisings of a season any more. `FamilyDef.raise_cap`
  stays as data and now limits the queue: the smaller of it and 3 (decision 6). Because the queue trains one company a season
  (decision 5), no settlement musters more than one a season: hamlets and villages stay at 1 a season, towns go from 2 to 1,
  walled towns from 3 to 1, cities from 4 to 1. A larger place can order further ahead, not faster.
- **Remove the mustering state (recommended).** The queue *is* the mustering. Keeping both would make a company take two
  seasons before it marches. An army that receives a company is no longer frozen. `Army.mustering` and its words, token mark
  and preview cases go; this amends moves rules R15, R16 and R20.
- **Disband no longer refunds.** Disbanding a finished company sends its men home and nothing else. The refund moves to the queue.
- The scenario's starting armies are still placed directly.

### 3.4 When costs and men are taken and returned

| Moment | Ducats and goods | Men |
|---|---|---|
| Queue (plus) | paid: ledger and store flows `raise` | levied from the hex, then its ring; **the source hexes are remembered** |
| Withdraw (minus) | all returned: flow `refund` | back to the same hexes; to the settlement if a source hex is no longer yours |
| Ready | nothing | they are now the company's men |

Everything is checked and taken at queue time, so a ready company never fails for lack of money. Levy shares, tax and food
already see the smaller population, as today. Queued men are in neither the people nor an army, so the "no men appear or
vanish" test counts them as a third place.

### 3.5 Checks and cancelling

`raise` keeps its name and arguments and now queues. Its check keeps today's order, with these changes:

- the cap row becomes "Turin (5, 9) has its queue full: 2 of 2 companies" (or "room in the queue for 1 more company");
- a siege or foreign army: "another country's army stands at ...: nothing can be queued" (a foreign army that is not an enemy:
  question 8);
- room counts companies standing there **plus** those queued there. Marching onto a hex does not count the queue; a ready
  company with no room waits.

`withdraw {muster, tag}` is a new check and action pair, both through `Session.act`.

- Allowed whenever the company is still queued and the settlement is yours and not occupied, **including under siege** (decision
  3). No confirm box: it undoes cleanly.
- The stepper's minus withdraws the newest queued company of that kind; a queue row's minus withdraws that exact one.
- Refused only if the treasury or stores cannot take the refund (the existing hard limits).
- In practice the window is the rest of the season you queued it, plus the seasons it stands in line or waits; for the first in
  line that is the same window as today's refund.

### 3.6 Siege, capture and other trouble

The owner's answers of 2026-11-26 and 2026-11-27 (decisions 7 to 9). The rows "no room" and "no longer there" were not asked
and keep this page's recommendation.

| Case | Rule | Status |
|---|---|---|
| Besieged, or an enemy army stands on the settlement | The queue **waits** (no countdown, as works halt in war). Nothing finishes and nothing new can be queued. Withdraw allowed. | decided (8); a foreign army that is not an enemy: question 8 |
| **Taken by force** (storm, siege, walk-in) | The queue is **lost**: the men go home to the people, the ducats and goods are lost. | decided (7) |
| **Ceded in a peace** | The queue is **lost**, in the same way as when taken by force. | decided (9) |
| No room for the company that is ready | It waits, with the reason shown. Withdraw allowed. | recommended; whether those behind it train meanwhile: question 7 |
| The settlement is no longer there (cleared) | Withdrawn with a full refund. | recommended |

The capture and peace rules apply the moment control changes (a storm during your turn included), through one function. A
settlement that shrinks keeps its queue: level gates and the queue limit are checked only when queuing. So companies already
queued stay even when the limit falls (a lower level, or a later modifier); only new ones are refused.

## 4. Fog and the computer

**Fog.** A queue is the owner's own information. Another country's tile shows no queue, no count and no footer row. Queuing and
withdrawing have no witnesses. The army is seen normally once it exists. A broken muster is reported to its owner only. No check
or refusal of another country may depend on your queue (a "twin" test: two games differing only in foreign queues look alike).

**Computer.** Same checks and actions, no shortcut. `AiForces` changes:

- queued companies count toward its goal of men, its upkeep room and its mix of kinds (without this it over-raises every turn);
- places keep today's order (nearest the front first) and must pass the check;
- `raises_peace` 2 and `raises_war` 4 stay, now meaning companies queued per turn; since a settlement musters one a season,
  the computer gets more companies a season only by queuing in more settlements (whether it should is measured in the soak);
- first version: it never withdraws. The soak counts companies and ducats stuck in waiting queues; if that is high, add "withdraw
  when broke".

## 5. Saves and replay

- New state: `game.musters` (one entry per queued company) and `next_muster_id`, written only by a new `Recruiting` system:
  `{id, tag, hex, kind, queued_turn, seasons_left, paid, paid_goods, levy: [[hex, men]]}`.
- It is saved, checked on load and covered by `Game.digest()`.
- The action log records `raise` and `withdraw`; the AI's records replay through the same door. The `muster` step uses no luck.
  Ready companies are consequences, not log records.
- **Take save FORMAT 9** (`OLDEST_FORMAT` 9, no upgrade step). FORMAT 8 is unreleased, but its saves would not mean the same:
  the body and digest gain the queue, and an old `raise` record would queue instead of create. Folding into 8 is safe only if
  this ships with the moves build **and** no format-8 save exists outside tests, playtests included. Later specs move up one.

## 6. Seams

**Arms (M9.5, `economy-build-spec.md` R45 to R49).** Arms are needed to **queue**: the arms quote joins the queue check; arms
from stores are taken, and the shortfall bought, at queue time. The entry records stored goods and bought arms (with their
price) apart. Withdraw **undoes the exact transaction**: stored arms return to the stores and the ducats paid for bought arms
return as ducats, so queue and withdraw is never a way to shop. A broken muster loses both. Nothing is checked again when the
company is ready. M10's market must undo its stock change the same way. Whichever build lands second adapts the other.

**Barracks and modifiers.** A barracks (building, settlement slot or technology) adds to `queue_size` (how it combines with
the size cap: question 9), and later perhaps shortens `raise_seasons` or opens kinds. No barracks is designed or built here.

## 7. UI and tooltips

No separate stepper mock was found in the repository; these are the states to show. The layout follows the tile window
(`docs/architecture/tilewin-build-spec.md` R12, R21, R26, R27). `docs/design/ui/` recruit pictures are older proposals.

**Army tab, head:** "Men to levy 800 · queue 1 of 2" (a town; the limit of the settlement).

**Company row:** figure, name, age badge, "500 men · 25 ducats + 1 iron", then `[-] 1 [+]`. The count is the companies of that
kind queued here.

| State | Look | Tooltip |
|---|---|---|
| Plus ready | enabled | "Queue 1 company of pikemen: 25 ducats, 1 iron, 500 men. Ready Summer 1481." (the season of its turn: behind one in training, Autumn 1481) |
| Plus refused (money, goods, men, room) | greyed, red reason line | the rule's reason |
| Level too low | lock | "Knights are raised in a village or larger" |
| Queue full, siege or enemy army | all plus greyed, reason said once under the head | "Queue full: 2 of 2. Withdraw one to change it." |
| Minus ready | enabled | "Withdraw 1 company of pikemen: +25 ducats, +1 iron, 500 men go home." |
| None of the kind queued | minus greyed, count 0 | "None queued" |

**Queue list**, under the rows, heading "Queued": one row per company, in the order they train, with figure, name, state and
minus. States: "in training: ready Summer 1481" (the first); "queued: ready Autumn 1481" (those behind, one season apart);
"waiting: under siege"; "waiting: an enemy army is here"; "waiting: no room (8 of 8)". Waiting uses the bad tone. The row tooltip
lists what a withdrawal returns. Empty: no heading.

**Footer queue:** the work row stays as it is. Below it, one recruit row for **the company in training only** (decision 10): its
small figure and "ready Summer 1481" (or "waiting: under siege"). The companies behind it are not shown here; the queue list of
the Army tab has them all, and a click on the row opens that tab. Idle text appears only when there is neither a work nor a
company; the "one work at a time" tooltip no longer describes the whole footer.

**Elsewhere:** the Raise companies window uses the same stepper. The company card gains "Ready: Summer 1481" and "Upkeep starts
when ready". Toasts: "Queued ... ready Summer 1481." and "Withdrawn: ...". The season report and log say "1 company of pikemen
ready at Turin", or that a muster was broken. Plus and minus work from the keyboard.

## 8. Risks

- **No emergency defence.** This is the largest change: an exposed town cannot answer an attack in the same season. Walls and
  garrisons matter more and the attacker gains. The soak and a playtest must judge it.
- **Slower raising in large places** (at most 1 company a settlement a season; today a town raises 2, a walled town 3, a city
  4). Likely to shrink armies, slow a country's recovery after a lost battle and favour realms with many settlements. Measure
  men under arms, leader against the median, and captures per war; the computer's goals of men may not be reached.
- **Money parked out of reach of a rule.** Nothing takes treasury today, so parking gains nothing. Debt and bankruptcy must
  decide whether queued money counts.
- **Safe from hunger:** queued men do not eat. Small (at most 3 companies a settlement, up to three seasons).
- **A lost queue stings:** a capture or a cession takes the ducats and goods of every company queued there.
- **Stuck queues** under long sieges: visible, and withdrawable.
- **Cost of change:** many tests create armies with `raise`; they need a helper first.

## 9. Smallest first version

All the owner decisions (1 to 10), section 3, the computer using the queue, saves and replay, the stepper, queue list and
footer row.
Left out: barracks and modifiers, different times per kind, reordering the queue, computer withdrawals, a ready notification
beyond the report and log.

## 10. Questions for the owner

Questions 1 to 6 are answered (decisions 5 to 10 at the top). Open, each with the recommendation the build takes unless the
owner says otherwise:

- **7. A company is ready and the hex has no room (8 companies). Do the ones behind it train meanwhile?** (a) No: it holds the
  training place until it fits or is withdrawn. (b) Yes: the next one trains and several may stand ready.
  **Recommend (a)**: one line, one rule.
- **8. A foreign army that is not an enemy stands on the settlement.** Your answer names an enemy army; today's raise check
  refuses on any other country's army. (a) Any other country's army makes the queue wait and refuses new companies, as today.
  (b) Only an enemy army does; others change nothing. **Recommend (b)**, the words of your answer, with the refusal text naming
  the enemy.
- **9. A later barracks or modifier.** (a) It adds to the settlement's own limit (a town with a barracks: 2 + 1). (b) It
  raises the 3, and the size cap still applies. **Recommend (a)**; not needed for the first version.

## 11. Build tasks

Start after the moves build is committed (it edits the same files). The issue is marked M; as listed it is nearer L, split so
that each task stays small. `military.gd` is near the 800-line mark, so the queue gets its own files. Paths are under `godot/`.

| Task | Size | What | Main files |
|---|---|---|---|
| RQ0 | S | Test helper "make a raised company now"; move tests to it (no behaviour change) | `tests/core/army_fixture.gd`, tests that act `raise` |
| RQ1 | M | Queue state and rules (one company in training a settlement, the limit by level), `raise` and `withdraw`, `muster` step, capture and peace rules, data values, FORMAT 9, digest, replay | new `core/state/muster.gd`, `core/systems/recruiting.gd`; `military.gd`, `occupation.gd`, `wars.gd`, `core/game/{game,actions,season,snapshot,save_file}.gd`, `core/defs/{game_defs,unit_def}.gd`, data files |
| RQ2 | S/M | Remove mustering, the disband refund and the per-season count (`raise_cap` stays: it now limits the queue) (with RQ1, same release) | `army.gd`, `movement.gd`, `movement_phase.gd`, `walk_now.gd`, `military.gd`, `family_def.gd`, `settlements.tres`, `core/views/{move_preview,move_words,army_view,summary_armies,reminders,company_card}.gd`, `shell/map/{army_token,army_tokens,move_orders}.gd`, `shell/panels/army_panel.gd`, `tools/` reports |
| RQ3 | S | The computer counts and uses the queue | `core/ai/{ai_forces,ai_know}.gd`, `tests/core/test_ai_forces.gd`, `random_player.gd` |
| RQ4 | M | Models and words: rows, queue list, footer, events, log, report, statistics | `core/views/{tile_army,tile_view,company_card,log_lines,season_summary,summary_doings}.gd`, `core/state/{chronicle,stats}.gd`, `shell/autoload/{events,session}.gd`, `shell/hud/notifications.gd` |
| RQ5 | M | Stepper, queue list, footer row, tooltips, toasts, player docs | `shell/ui/company_row.gd`, `shell/panels/tile_tabs/army_tab.gd`, `shell/screens/raise_screen.gd`, `shell/panels/tile_window.gd`, shell tests, monkey, `godot/README.md` |
| RQ6 | S | Soak and ranges, perf, pictures (art director), owner playtest | `tools/soak.gd`, `tools/ui/shot_ui_tile.gd` |

**Key tests:** queue then withdraw leaves the digest's money, goods and people as before; the first company ready exactly one
season later and able to march, the second one season after it, never two from one settlement in a season; one company over the
limit refused at each level (hamlet and village the 2nd, town the 3rd, walled town and city the 4th); withdrawing the company in
training moves the next one up; each row of 3.6; the computer never over its limit or goal; foreign queues invisible; save,
load, save byte-equal with a waiting queue; replay gives the live digest.

**Earlier pages this amends:** `m6-build-spec.md` (raising and refund), `moves-build-spec.md` (R15, R16, R20),
`tilewin-build-spec.md` (R12, R21, R22, R26, R27), `economy-build-spec.md` (R46, R49), and the FORMAT numbers of later specs.
