# Battle system, slice 1 "Battles that last" (v0.2.0): build spec

This turns the agreed direction of `docs/design/battle.md` into code. It covers the "Next up" item of
`docs/roadmap/roadmap.md`. The design says what the player sees. This spec says how to build it. If they disagree,
follow this spec and tell the planning session.

**In scope:** battles that stay on a hex for several seasons, three days a season, three lanes and a back line,
fire / shock / flanks / morale / pursuit, killed and wounded, regiment and army morale, joining as reserve,
Attack / Hold / Withdraw, rout, retreat and surrender, castle assaults with the garrison in the line, sieges on the same hex (no bombardment),
the map badge, the battle panel, log lines and ribbons, the AI.

**Not in scope (later slices):** cards, command points, the battle mini-map, lane ground from the real map,
deployment presets, battle events, troop quality, reserve and cannon orders.

**Replaces:** today's one-shot `war.battle()`. The old function is deleted in PR 4. Nothing keeps it alive.

## 1. Decisions at a glance

| Question | Decision | Why |
|---|---|---|
| Where a battle lives | `Battle` dataclass in `state.py`, in a new list `world.battles` | Same pattern as `War`. Saved with the world. Pinned to `hexa.campaign.world` like every state class. |
| One key per battle | The hex (`pos`). At most one battle per hex. | No new id counter. The badge, the panel and the invariants all look battles up by hex. |
| Strength | Keep `unit.hp` as the only truth. Show it as men: a full regiment is 1,000 men. | Every system (supply, debt, AI, healing, panels) already reads `hp`. Changing its unit is the riskiest option. |
| Fractions of a hit point | The battle keeps a per-unit `carry` of damage not yet taken | Daily losses are a few percent; a 10 hp regiment loses 100 men per hp. `carry` makes small losses add up without floats in `hp`. |
| Wounded | Kept by the battle per unit, settled when the battle ends | Wounded only matter at the end. No field on `Unit` needed. |
| Morale | One new `Unit` field, `morale: float = 1.0` | Morale outlives the battle (a beaten army recovers over seasons). The dataclass default fills old saves. |
| How a battle starts | The existing attack order. The stack walks next to the target, then steps in. | The UI (attack chips) and the AI (`attack_options_group`, `attack_group`) already use it. No change to `plan()`, the hot path. |
| When days are fought | A new first phase `battles` in `PHASES`, before `logistics` | Losses first, then the survivors eat. A battle ended this season lets the winner start the siege in the same season. |
| Save version | Bump `saves.VERSION` from 1 to 2 | A save with a `Battle` in it cannot open in an old build (unknown class). The bump makes old builds refuse it quietly. Old saves still load here. |
| Bombardment | **Dropped** (owner, 2026-11-13). Every fight and every siege happens with both sides on the same hex. Guns fight inside battles and add siege points on the hex. | The owner: "for siege and battles too both armies should be on the same tile". |

## 2. Data model

### 2.1 `state.py`

```python
@dataclass(eq=False)
class Battle:
    pos: tuple                    # the hex; one battle per hex
    attacker: str                 # country tag
    defender: str                 # country tag
    start: int                    # world.turn it began
    assault: bool = False         # the defender held a castle with a garrison when it began
    days: int = 0                 # days fought so far
    stance: dict = field(default_factory=dict)     # tag -> "attack" | "hold" | "withdraw"
    lanes: dict = field(default_factory=dict)      # tag -> [unit id | "garrison" | None] * 3 (left, centre, right)
    routed: set = field(default_factory=set)       # unit ids out of the fight (they stay on the hex)
    carry: dict = field(default_factory=dict)      # unit id or "garrison" -> damage not yet taken (hp, < 1)
    wounded_hp: dict = field(default_factory=dict) # unit id -> hp lost as wounded (float)
    men0: dict = field(default_factory=dict)       # tag -> men that have joined the fight (start + joiners)
    killed: dict = field(default_factory=dict)     # tag -> men killed
    wounded: dict = field(default_factory=dict)    # tag -> men wounded
    garrison_morale: float = 1.0
    log: list = field(default_factory=list)        # (turn, day, text); the last BATTLE_LOG lines
    members: set = field(default_factory=set)      # unit ids that have fought in it (start and joiners); a unit counts once
```

- Unit ids, never unit objects. A dead or deserted unit is just missing, and the battle skips it.
- The reserve and the back line are not stored. They are derived each day: a side's war units on the hex that are
  not in a lane and not routed. Artillery is the back line; the rest is the reserve. Less state, fewer ways to drift.
- Generals, wagons and scouts on the hex belong to their side. They never stand in a lane. They retreat or
  surrender with it.
- `Unit` gets one field: `morale: float = 1.0`.
- `Unit.men` (a property, not saved): `round(MEN * hp / kind.hp)`. `Garrison` gets the same with `GARRISON_MEN`.
  The battle panel shows `men - carry` so numbers move smoothly.
- The D5 loop at the bottom of `state.py` pins `Battle` to `hexa.campaign.world`. `world.py` re-exports it.

### 2.2 `world.py`

- `WORLD_DEFAULTS["battles"] = list`. `_migrate` fills it. `_migrate` also runs `fill_defaults` over `self.battles`.
- Facades (plain class attributes, as for the other systems): `battle_at`, `engage`, `battle_order_check`,
  `battle_order`, `end_battles`, `army_morale`, `retreat_spot`. Nothing else in `world.py` grows.
- `battle_at(world, pos)` is a linear scan of `world.battles`. There are rarely more than 20. No cache. If profiling
  ever shows it, add `_battle_hexes` to `WORLD_CACHES` and clear it in the two functions that change the list.

### 2.3 Saves

- `saves.VERSION = 2`. Old builds see version 2 and ignore the file (`_readable`). This build reads 1 and 2.
- A version 1 save gets `battles = []` and `morale = 1.0` on every unit. Nothing else changes.
- A save taken mid-battle must round-trip: same `world_digest` after save and load, and the next season plays the
  battle on. PR 1 adds this test.
- The bus is not saved, as today. Nothing in the battle holds a bus event or a pygame object.

### 2.4 Module layout

| File | PR | Contents |
|---|---|---|
| `systems/combat.py` (new) | 0, 2 | Pure day resolution. PR 0 moves `general`, `attack_value`, `defense_value` here from war.py (facades unchanged). PR 2 adds `deploy`, `fire`, `shock`, `flanks`, `morale`, `pursuit`, `fight_day`. Writes only the battle object, unit `hp`/`morale` and `prov.garrison`. |
| `systems/battle.py` (new) | 3, 4 | The battle's life: `engage`, `join`, `battle_order_check`/`battle_order`, `battle_season` (the phase), `end_battle`, `end_battles`, `retreat_spot`, `army_morale`. |
| `systems/war.py` | 4 | `attack_group` calls `engage`; the `"bombard"` attack option is removed. `battle()` is deleted. `peace` and `check_alive` call `world.end_battles`. |
| `systems/movement.py` | 3 | `step_in(world, group, pos)`: the last step onto the battle hex, with its own `unit_moved` event. |
| `systems/season.py` | 3 | `("battles", battle.battle_season)` first in `PHASES`. `start_units` skips healing and moves for units in battle; morale recovers outside battle. |
| `systems/military.py`, `supply.py`, `terrain.py` | 3 | Stack limit per side, forage in battle, `move_check` reason. |
| `ai.py` | 5 | `_battles(world, tag)`: stances and joining. Attack threshold uses morale. |
| `feed.py`, `hud/battles.py` (new), `ui/icons.py` | 6 | Log lines, ribbons, the badge. |
| `screens/battle.py`, `screens/battlelayout.py` (new) | 7 | The battle panel. |

`OWNS`: combat.py `("battles", "units", "provinces")`. battle.py `("battles", "units", "provinces", "log", "version",
"_owned", "_castle_list", "_markets_dirty")`. war.py keeps its list. Both modules stay under 800 lines; if
battle.py passes 600, split retreat and end into `systems/aftermath.py`.

## 3. Rules

### 3.1 Starting a battle

- The attack order is the way in. `attack_options_group` stays the check. Its target list (`war.targets`) gains
  battle hexes where the stack's own country is a side and the stack fits (see stack limits). The option for those
  hexes means "join".
- `attack_group(group, target)`:
  1. walks to the stand hex with `move_group` (as today, one `unit_moved` event);
  2. calls `world.engage(group, target)`, and nothing else. `attack_group` must not call `movement.step_in`: `engage`
     makes the one step itself, after its checks, so a refused attack moves nothing (decision 2026-11-13, review of
     PRs 1-3).
- `engage_check(world, group, target) -> (ok, reason)` and `engage`: a `*_check` pair. `engage` runs the check and changes
  nothing when it says no. The check refuses, with the reason shown as the hover hint: a stack of more than one country;
  ships (naval, or aboard one); a target that is not a land province; a target not beside the stack, or with a ridge or a
  closed pass between ("Not beside the target", "A ridge or a closed pass lies between"); a stack with no war unit with hp
  ("No regiments to attack with"); a stack whose average morale is under `ATTACK_MORALE` ("Too shaken to attack"); a stack
  already in a battle on another hex ("Already in another battle"); a stack whose war units are all in this battle
  ("Already in this battle"); a stack that does not fit (`fits`: `military.can_stand` per side, so the stack limit, one
  general and the civilians' limit; "Too many units for this hex"); no enemy there ("No enemy here"); countries not at war.
  After the checks `engage` steps in (`movement.step_in`, unless the stack already stands on the hex) and then:
  - Target has only civilians (no war units, no garrison): overrun as today (`lose(..., "overrun")`). No battle.
  - Target is a battle hex: the stack joins its side's reserve. Only its war units that are not yet in the battle
    (`members`) count in `men0[tag]`; all its units become members. A log line.
  - Otherwise a new `Battle`: attacker is the group's owner, defender is the owner of the war units there, or the
    controller of the castle. `assault = True` when the defender controls a castle with `garrison > 0`. Stances:
    attacker `"attack"`, defender `"hold"`. Lanes are deployed at once (3.3), so the panel has something to show.
    Emit `battle_started`. `world.changed()`.
- A stack whose average morale is under `ATTACK_MORALE` (0.5) cannot attack. The check reason: "Too shaken to
  attack". This stops a beaten army from bouncing straight back in.
- Ships: battles are land only. Units aboard a ship cannot attack (as today). A stack cannot step into a battle from
  a ship in slice 1 (the "By river and sea" card is slice 2). Naval units never belong to a battle.
- ZOC: no new ZOC. A battle hex already blocks movement for everyone (`owners_at` shows two owners, so `plan()` will
  not enter it), and its enemy units already block supply lines through it (`in_supply`).

### 3.2 While a battle runs

| Thing | Rule | Where |
|---|---|---|
| Moving | Units in a battle cannot move, board or attack. `start_units` gives them `moves_left = 0`. `move_check` says "In battle: order Withdraw to leave". | season.py, terrain.py |
| Joining | Only through the attack order (3.1). Joiners are reserve. They fight from the next day a gap opens. | battle.py |
| Stack limit | Per side. `can_stand` on a battle hex counts only the units of the side's own owner. The check sits in the branch that today returns False for mixed owners, so the common path costs nothing. | military.py |
| Supply | Unchanged. `logistics` already works per (hex, owner). Units in battle eat and suffer attrition. Out of supply also costs morale (3.4). | supply.py |
| Foraging | Allowed in battle. `forage_check` skips its "no time left" rule for units in battle. | supply.py |
| Siege | None on a battle hex, either way. `sieges` skips the hex (also for a garrison-only assault, where only one owner stands on it). No garrison regrowth either. | war.py |
| Healing | None for units in battle. Morale does not recover in battle. | season.py |
| Raising, refits, drills | Refused on a battle hex: "A battle is being fought here". | military.py |
| Disbanding, desertion | Still allowed. The battle skips missing units. | (none) |

### 3.3 The field

- Lanes per side: left, centre, right. On narrow ground (`NARROW_TERRAIN`: mountains, marsh, jungle, snow) the
  right lane is closed for both sides. Only two lanes fight and no flank attack comes through it.
- Deploy (day 0 and before every day): an empty lane (None, a dead unit, a routed unit) is filled from the reserve.
  Centre first, then left, then right. Infantry prefers the centre, cavalry the flanks. Among equals the best
  `defense_value` goes first, then the lowest id (deterministic). Artillery only goes into a lane when no other
  regiment is left.
- Assault: the defender's centre is `"garrison"` while `prov.garrison > 0` and `garrison_morale > 0`. Its field units
  take the flanks first.

### 3.4 One day

Each battle fights `DAYS_PER_SEASON` (3) days in the `battles` phase, fewer if it ends. Battles are fought in order
of `pos`. All randomness is `world.rng`, so games stay deterministic. Damage of a phase is worked out for both sides
first and applied after, so neither side strikes first.

The damage one regiment `a` does to one target `t` in hp:

```
loss = BASE * t_max_hp * attack_value(a, fight, gen_a) / defense_value(t, dfight, prov, castle, a.branch, gen_t)
       * strength(a) * DEALT[stance_a] * TAKEN[stance_t] * extra * rng.uniform(0.85, 1.15)
strength(a) = a.hp / a.kind.hp     (a worn regiment hits less)
```

`attack_value` and `defense_value` are today's functions, so terrain, castles, ranks, drills, techs, ideas and
generals all plug in as they do now. `fight`/`dfight` are today's: open, rough, assault, garrison.

1. **Fire.** Every gun of the back line fires at the enemy centre (`BASE = FIRE_LOSS`). Era 2 and 3 infantry in a
   lane (arquebusiers, musketeers) fire at the lane opposite (`BASE = SHOT_LOSS`).
2. **Shock.** Each lane fights the lane opposite (`BASE = SHOCK_LOSS`). Pikes against horse: `defense_value`
   already gives infantry `PIKES_VS_HORSE` (+25%) against cavalry. Infantry striking cavalry also gets +25% (`extra`).
3. **Flanks.** If a side's flank lane is empty and the enemy's opposite flank lane holds a regiment, that regiment
   hits the centre instead, with `extra = FLANK_BONUS` (1.25). If the centre is empty too, it hits the nearest
   filled lane.
4. **Morale.** Each regiment loses `MORALE_PER_LOSS * (hp lost today / hp at dawn)`, plus `FRONT_DRAIN` in a lane or
   `RESERVE_DRAIN` in the reserve and back line, plus `HUNGER_DRAIN` if `unit.supplied` is False. A general on the
   side cuts the loss by `GENERAL_MORALE` (15%). Veterans divide it by their rank bonus. A regiment at 0 routs: it
   leaves its lane and joins `routed`. The garrison works the same with `garrison_morale`.
   Army morale: `sum(morale * men) / men0` over the side's war units and the garrison, routed ones counting 0. A side
   under `BREAK` (0.25) breaks. If both are under, the lower one breaks (the attacker on a tie).
5. **Pursuit.** Only on the day a side breaks. The loser loses `PURSUIT` (10%) of its men if the winner has a
   cavalry regiment not routed, else `PURSUIT_FOOT` (4%). All of it is killed, none wounded.

Damage lands through `carry`: whole hit points come off `hp`, the rest waits. `WOUNDED_SHARE` (half) of every hp
lost to fire and shock goes to `wounded_hp` (and, in men, to `wounded[tag]`). A unit at `hp <= 0` is killed with `world.kill(unit, "battle")`.
The garrison loses `prov.garrison` the same way.

### 3.5 Orders

- `battle_order_check(world, pos, tag, stance) -> (ok, reason)` and `battle_order(world, pos, tag, stance)`. A new
  pair, with a facade and a pair in `tests/support/agents.py`. Reasons: "No battle here", "Not your battle",
  "Unknown order", and for Withdraw "Nowhere to withdraw to".
- Attack: `DEALT 1.2`, `TAKEN 1.1`. Hold: `DEALT 0.9`, `TAKEN 0.8`. Attacking an equal army that holds is a losing
  bet; attacking with 1.5 to 1 is a sure one (see the table in 4).
- Withdraw: at the start of the next `battles` phase, before day 1, the side leaves. It suffers half pursuit
  (`WITHDRAW_PURSUIT`, 5%, killed), keeps its morale and retreats (3.6). The other side wins without a fight.
- The stance stays until changed. The AI sets its stances in `ai.run` (section 5).
- Safety stop: a battle that reaches `BATTLE_MAX_SEASONS` (6) seasons ends with the side of lower army morale
  retreating, with no pursuit (decision 2026-11-13). With no retreat hex it is a draw: how `stalemate`, no winner, no
  loser, and no surrender. This prevents two holding armies from sitting forever.

### 3.6 The end of a battle

A battle ends when a side breaks, withdraws, has no war units (and no garrison) left, at the safety stop, or when
peace is made or a side's country disappears. A side with nothing left on the hex ends it as `gone`: a draw, no winner,
no loser, no score. Routed regiments still count as present. In an assault the garrison counts as present while it has hp.

1. **Retreat.** `retreat_spot(world, group, pos)`: a walk over land from `pos`, at most `RETREAT_RANGE` (3 * SCALE)
   steps, that never crosses a wall (`world.walls()`: the ridge crests, and the mountain passes in winter), the sea or a
   hex with an enemy unit. The nearest hex on that walk that the side's country controls, with no battle and room
   (`can_stand`). Nearest by steps; ties go to the hex farthest from the enemy's nearest unit, then the lowest `pos`.
   Set on an order or a break, never per frame. The whole side (routed or not,
   generals and wagons too) moves there. Emit `unit_moved` with path `(pos, spot)`, so the replay shows it. Morale
   of a beaten side is set to at most `RETREAT_MORALE` (0.3).
2. **Surrender.** No spot: the side is lost with `lose(units, "surrendered")` (a new `why`). Its men count as
   killed: war units only (generals, wagons and the rest have no men). The safety stop never surrenders: with no spot
   it is a draw (3.5).
3. **Wounded.** For every surviving unit of both sides: if `in_supply` where it ends up, `hp += floor(wounded_hp *
   WOUNDED_RETURN)` (half), capped at `kind.hp`. The rest of the wounded are gone.
4. **Experience.** Survivors of the winner get +2 xp, of the loser +1. None when the battle had no day (`days == 0`).
5. **Castle.** In an assault, if the defender breaks and the garrison is at 0 hp or 0 morale, or the defender has no
   field units left (the garrison is then the whole army, decision 2026-11-13), the castle is
   stormed: `province_captured` with `by="storm"`, controller to the attacker, siege 0, garrison 0. If the garrison
   still stands, the castle holds; the attacker stays and the normal siege goes on next season. If the attacker
   breaks, the garrison regrows as usual.
6. **Bookkeeping.** Remove the battle from `world.battles`, `world.changed()`, emit `battle_ended`.

- Peace (`war.peace`) calls `world.end_battles(a, b)` first: no pursuit, no retreat, wounded settled; then the
  existing eviction sends the units in foreign land home.
- `check_alive` calls `world.end_battles(tag)` when a country disappears.

### 3.7 Same hex for battles and sieges (owner, 2026-11-13)

- Both sides always stand on the same hex: a battle has both stacks on the battle hex, and a siege has the besieger
  standing on the castle's hex (as today's `sieges` already requires).
- Bombardment from 2 hexes away is **removed**: `attack_options_group` drops the `"bombard"` option and the AI's
  bombard step goes. Guns help a siege by standing on the hex (their siege points, as today) and fight in battles in
  the back line.
- The map draws a siege like a battle: the besieging stack and the castle with its garrison together on the one hex,
  with a siege badge and a progress bar (progress / need) instead of the morale bar.
- The feed's bombardment line and the `ranged` flag of the old `battle` event go; the `battle` event itself goes with
  `battle()` in PR 4.

### 3.8 Morale outside battle

`start_units` raises every war unit's morale by `MORALE_RECOVERY` (0.25) a season, up to 1.0, if it is not in a
battle and was fed. A new unit starts at 1.0.

## 4. Numbers (data.py)

Starting numbers. PR 5 tunes them with the stats tool. Today's `FRONT = 3` stays and means three lanes.

```python
MEN = 1000                 # men in a full regiment
GARRISON_MEN = 100         # men per garrison hit point (a level 3 castle: 1,800)
DAYS_PER_SEASON = 3
SHOCK_LOSS = 0.08          # share of a regiment's hp lost a day in an even lane fight
FIRE_LOSS = 0.05           # a gun's fire
SHOT_LOSS = 0.03           # era 2 and 3 infantry's shot
FLANK_BONUS = 1.25
STANCE = {"attack": (1.2, 1.1), "hold": (0.9, 0.8)}   # (damage dealt, damage taken)
MORALE_PER_LOSS = 2.5      # morale lost per share of the regiment lost that day
FRONT_DRAIN, RESERVE_DRAIN, HUNGER_DRAIN = 0.04, 0.03, 0.03
GENERAL_MORALE = 0.15
BREAK = 0.25               # army morale under this breaks the army
ATTACK_MORALE = 0.5        # a stack this shaken cannot start an attack
PURSUIT, PURSUIT_FOOT, WITHDRAW_PURSUIT = 0.10, 0.04, 0.05
WOUNDED_SHARE, WOUNDED_RETURN = 0.5, 0.5
RETREAT_MORALE, MORALE_RECOVERY = 0.3, 0.25
BATTLE_MAX_SEASONS = 6
BATTLE_LOG = 24
NARROW_TERRAIN = ("mountains", "marsh", "jungle", "snow")
```

A quick model of these rules (pikemen and knights at their era 1 values, open ground, attacker on Attack, defender
on Hold, 300 seeds each) gives:

| Fight | Days, median (p90) | Seasons, median (p90) | Attacker wins | Losses A / B |
|---|---|---|---|---|
| 3 pikes v 3 pikes | 4 (4) | 2 (2) | 16% | 23% / 22% |
| 6 pikes v 6 pikes | 8 (8) | 3 (3) | 18% | 22% / 22% |
| 4 pikes, 2 knights, 1 gun, both sides | 6 (7) | 2 (3) | 22% | 26% / 25% |
| 6 pikes v 4 pikes | 5 (6) | 2 (2) | 100% | 15% / 21% |
| 8 mixed v 5 pikes | 6 (6) | 2 (2) | 100% | 13% / 27% |

Losses are before pursuit. That is the target shape: an even battle lasts 1 to 3 seasons, odds decide it, and
attacking an equal army that holds usually fails. The model is too even (little spread). The real game adds
terrain, generals, ranks and supply, so PR 5 must measure the real thing.

## 5. The AI (`ai.py`)

- **Attack.** `_campaign` keeps its rule: attack when our power is at least 1.3 times theirs. Power becomes
  `world.power(u) * u.morale`, and `_defence_power` adds an ongoing battle's side the same way. Bombard is removed (see 3.7); previously it stayed as
  today.
- **Join.** Before looking for new targets, a stack with moves joins a battle of its own side within reach (an
  attack option on a battle hex) when its side's army morale is not higher than the enemy's, or its side has fewer
  men. Joining wins over a new attack.
- **Stance** (`_battles(world, tag)`, called from `run` before `_army`), once per season for each battle it is in:
  - Withdraw when its army morale is under 0.4, the enemy's is at least 0.15 higher, and a retreat spot exists.
  - Attack when its men times morale is at least 1.2 times the enemy's.
  - Otherwise Hold. A defender in a castle assault always holds.
  - With no retreat spot it never withdraws: it fights on.
- AI-vs-AI battles run through exactly the same phase. The feed gives them one log line when they end (section 6).

## 6. UI

### 6.1 Events (`hexa/events.py`)

Add to `CAMPAIGN_KINDS` and the docstring:

| Kind | tag, pos | Data |
|---|---|---|
| `battle_started` | attacker, hex | `defender`, `assault` |
| `battle_joined` | joiner, hex | `side` ("attacker" or "defender"), `men` |
| `battle_fought` | attacker, hex | `defender`, `days`, `morale` {tag: share}, `killed` {tag: men}, `wounded` {tag: men}; one per battle per season |
| `battle_ended` | attacker, hex | `attacker`, `defender`, `winner` (tag, or None), `loser` (tag, or None), `assault` (bool), `how` ("broke", "withdrew", "surrendered", "stalemate", "peace", "gone"), `seasons`, `killed` {tag: men}, `wounded` {tag: men}, `retreat` (hex or None) |

`battle_ended` is a contract with the war goals design (`docs/design/war-goals-and-peace.md`, section 3.4),
which turns it into war score. Its fields are fixed by that design:
- the two tags (`attacker`, `defender`) and the hex (`pos`);
- `winner`: the side whose army did not break and did not withdraw. A side that withdraws or surrenders loses. The
  safety stop counts as a withdrawal of the lower side, so it has a winner (how "withdrew", no pursuit), unless that
  side has no retreat hex: then it is a draw (how "stalemate"). Peace, a vanished country and a side left with nothing
  (how "peace", "gone") are draws too. A draw has `winner = None` and `loser = None`: worth nothing;
- `killed` and `wounded`: men per side for the whole battle, keyed by tag, pursuit and surrender included (a
  surrendered side's men count as killed);
- `assault`: whether it was a castle assault.
It is emitted exactly once per battle, for every battle (AI-vs-AI too, seen or not), after the battle is removed
from `world.battles` and after any `province_captured` of a storm. The battle code knows nothing about war score;
war goals subscribes to the event (its own system reads `bus.history` or a tap, never the battle object).
Changing these fields later is a change to both designs.

`battle` goes with bombardment (see 3.7). `unit_lost` gains `why="surrendered"`.

### 6.2 Log and ribbons (`feed.py`)

- `battle_started`: "Battle!" ribbon (war colour), log line "Battle at X: A attacked B."
- `battle_fought`: a log line only when the player is a side: "Battle at X, season 2: you lost 600 men (300
  wounded), they lost 900. Morale 64% to 46%."
- `battle_ended`: one line for any battle the player can see, AI-vs-AI included. This is the one line per AI
  battle: "Battle of Toro (3 seasons): Castile beat Portugal. Castile lost 2,300 men (900 wounded), Portugal 4,100;
  Portugal retreated to Braganza." Ribbon "Victory!" (gain) or "Defeat!" (loss) for the player, "Battle won" for
  others. A storm keeps its own "Captured!" from `province_captured`.
- The ribbons keep waiting for the replay (`replay.ready_at`), as today.
- Visibility follows today's `_party` / `_seen` rules.

### 6.3 Map (mockup `11_battle_map_and_options.png`, left column)

- Both stacks on the hex: `MapView._draw_units` groups a battle hex by (hex, owner) and draws the attacker left and
  the defender right (offset about a third of the hex radius). The offsets come from a small function in a new
  `campaign/render/battlemark.py`. mapview.py is at its size cap (1,531 lines, 2% growth allowed), so it gets at
  most 15 new lines.
- The badge and the bar: `hud/battles.py`, drawn by `Hud.draw_world` above the ribbons. A crossed-swords badge
  (a new `battle` icon in `ui/icons.py`, ink outline, flat two-tone, in the Kenney look) above the hex, and below it
  a tug-of-war bar: attacker colour from the left, defender from the right, split at `army_morale(a) /
  (army_morale(a) + army_morale(d))`, with a thin mark at each side's break point. The place name under it, as in
  the mockup. Badge sprites go in a `BoundedCache("battle_badge", ...)`, keyed by zoom; the bar is two rects drawn
  each frame.
- Shown for battles the player is in or can see. Hidden under fog like any stack.
- Clicking the badge opens the battle panel. Clicking the hex still selects your own stack; the unit panel then says
  "In battle at X" and has an "Open battle" button.

### 6.4 The battle panel (mockup `10_battle_panel.png`, without the cards)

`screens/battle.py`, a `Screen` (not opaque; the map shows under a shade). Geometry in `screens/battlelayout.py`
(no drawing), drawing in the screen. Opened by `CampaignApp.press(("battle", pos))`. Esc, right-click or a click
outside closes it.

- **Header:** "Battle of X", then the ground ("open ground", "narrow ground: 2 lanes", "assault on a level 2
  castle"), "season 2, day 5".
- **Sides:** each with its flag token, name, regiments and general (trait).
- **Army morale bar:** the tug-of-war bar, both percentages on it, "breaks at 25%".
- **The field:** enemy back line (guns, reserves) at the top, enemy lanes, the dashed front line with crossed swords
  per fighting lane, our lanes, our back line at the bottom. Lane labels left flank, centre, right flank. A closed
  lane is greyed.
- **Regiment card:** a new `kit.regiment_card` (the kit rule: no hand-drawn widget). The unit figure (`art.figure`
  or `art.token`), name, rank tag (Veteran, Elite), state tag (RESERVE, ROUTING, fires, Garrison), a men bar (green:
  fit, orange: wounded), "760 men +60 wounded", and a morale bar (blue).
- **Orders** ("Your orders this season"): Attack, Hold, Withdraw as `kit.menu_button`s, the current one selected.
  Each is enabled by `battle_order_check`, and its reason is the hover hint. One line under them says what the
  stance does. No reserve or cannon rows (those are later slices). A battle the player only watches shows no orders.
- **Losses:** killed and wounded per side.
- **Battle log:** `battle.log`, grouped by season, newest at the bottom.
- **Legend** as in the mockup.
- It must fit 1280x720. It reads the world only through public functions and changes it only through
  `battle_order`.

### 6.5 Strength shown as men

The unit panel, the hover cards and the raise panel show men instead of HP ("760 men"). The rule is in `Unit.men`.
See open question 2.

## 7. Tests and proof

### 7.1 Contract tests (new `tests/test_battle.py`, pygame-free)

Use `fresh()` worlds and a new helper `tests/support/battles.py` (`setup(world, attacker_spec, defender_spec,
terrain=None, castle=0)` places two stacks next to each other at war).

- Attacking an enemy stack moves the stack onto its hex, makes one `Battle`, emits `battle_started` and two
  `unit_moved`, and leaves both sides there.
- Units in battle: no moves next season, `move_check` refuses with the reason, no healing, morale does not recover,
  still fed (attrition applies), can forage; no siege progress and no garrison regrowth on the hex.
- Three days a season. A battle never fights a day after it ended.
- A regiment at 0 morale routs and a reserve fills its lane on the next day. Cavalry goes to the flanks, infantry to
  the centre.
- Pikes against horse and the flank bonus each change the day's damage by 25% (fixed seed, one lane).
- Army under 25% breaks; pursuit is 10% with cavalry, 4% without.
- Retreat goes to the nearest own hex; no spot means surrender (`unit_lost` with `why="surrendered"`).
- Wounded: half come back in supply, none out of supply.
- Joining adds to the reserve and to `men0`; the per-side stack limit refuses a stack that does not fit.
- Withdraw: half pursuit, morale kept, the other side wins.
- Assault: the garrison stands in the centre; storm when it breaks; the castle holds when the field army breaks
  first.
- No bombard: the `"bombard"` option is gone from `attack_options_group`, and a siege only progresses with the besieger on the hex.
- Peace and extinction end battles. The safety stop ends a battle at 6 seasons.
- `battle_ended` is emitted once per battle with every field of 6.1 (a contract test per `how`, including
  `winner = None` after peace), and `CAMPAIGN_KINDS` lists the four new kinds.
- `battle_order_check`/`battle_order` obey the `*_check` contract. Add the pair, and a campaign attack move, to
  `tests/support/agents.py`.
- `test_season.py` pins `battles` as the first phase.
- `test_architecture.py`: `OWNS` of the new modules, no pygame, size limits.

### 7.2 Invariants (`tests/support/invariants.py`)

- `one-country-per-hex` allows exactly the two sides on a battle hex.
- New: every battle's sides are at war; its hex has war units of both sides (or the garrison); every lane id is a
  living unit of that side on that hex; no unit is in two battles; `0 <= morale <= 1`; `0 <= carry < 1`; no battle
  is older than `BATTLE_MAX_SEASONS + 1` seasons.
- `stack-limit` counts per side on a battle hex.

### 7.3 Proving the gameplay is right (the oracle will change by design)

`tools/same_behaviour.py` compares with the base. After PR 4 every war game differs, so the oracle cannot prove the
switch. It still guards the refactor PRs (0, and 2 and 3 before they are wired in). For the switch:

1. **Fixed-seed scenarios.** `tests/test_battle.py` plays the five fights of the table in section 4 for 30 seeds each
   (cheap: a few thousand day calls) and asserts bands, not exact numbers: an even 3 v 3 lasts 1 to 3 seasons in at
   least 80% of seeds; 1.5 to 1 odds win at least 85%; losses of the loser between 15% and 50%.
2. **Stats tool.** `tools/battle_stats.py` (new, pygame-free, public API only). Two parts: the scenario table above,
   and N all-AI games (Europe and random, 40 seasons) that count battles, length in seasons (median, p90, at the
   safety stop), attacker win rate, killed and wounded shares, surrenders, storms, and provinces that changed hands
   per war. PR 0 records today's numbers for the same games (battles per war, units lost per war, provinces per war),
   so PR 5 can compare.
3. **Soak.** `python -m tools.soak` (the nightly) with the new invariants every turn. No break and no battle stuck
   past the safety stop.
4. **Determinism.** `PYTHONHASHSEED=0 python -m tests.support.digest_run` gives the same digest twice. Battles are
   fought in `pos` order; sets are never iterated without sorting.
5. **Re-baseline.** After PR 4 lands, the oracle's base is the new master, so later refactors are guarded again.

Targets for PR 5 (the owner may change them): median battle 1 to 3 seasons; at most 5% reach the safety stop;
provinces changed hands per AI war within 30% of the PR 0 baseline; no country loses more than half its regiments in
one battle more than 1 time in 10.

### 7.4 Saves

- `tests/test_saves.py`: a save taken mid-battle round-trips (same digest; next season the battle goes on; the
  panel data is the same). A version 1 save loads with `battles == []` and every `morale == 1.0`.
- `tools/save_compat.py` (CI job): the base's three saves (version 1) load and play a season with this checkout.
  Since `VERSION` changed, the job also accepts a quiet refusal; we want them to play, and the PR description says
  so. Add a fourth save to `save_compat.py write` only if the base has battles (not before v0.2.0).
- The other direction: an old build refuses a version 2 save quietly (`saves.load` returns None). This is the
  existing "bump alone" case in `tests/test_save_compat.py`.

### 7.5 Performance

- `tools/perf.py` gets a `battle_season` metric: one `battles` phase with 10 battles of 8 v 8. Budget: soft 5 ms,
  hard 15 ms, in `tests/perf_budget.json` in PR 4.
- `ai_season` may not grow more than 10% (the join search reuses `attack_options_group`, which the AI already runs).
- The battle panel draws in under 4 ms at 1280x720; the badges add under 0.5 ms with 10 battles on screen. Check
  with `tools/perf.py` MapView metrics.
- `can_stand`, `targets` and `start_units` touch battles only in a branch the common path never takes.

### 7.6 Window tests and goldens

- `tests/ui/test_battle_panel.py`: open from the badge and from the unit panel, press Hold, Withdraw is greyed
  without a retreat hex, Esc closes, the panel fits 1280x720.
- Two new golden scenes: a battle on the map (zoomed in) and the panel. Made by the goldens workflow on Linux.
- The monkey gets the new screen for free; it must stay green.

## 8. Pull requests

Each is one Haiku worker's round, in this order. Each updates README (rules the player sees), the CLAUDE.md
architecture lines it changes and the `events.py` docstring when it adds events. No PR mixes a refactor and a
gameplay change. Keep each file's existing line endings.

| # | PR | Files | Done when |
|---|---|---|---|
| 0 | **Refactor: combat values move to `systems/combat.py`; baseline stats.** Move `general`, `attack_value`, `defense_value` (facades unchanged). Add `tools/battle_stats.py` with the AI-game part, run on today's code. Add `tests/support/battles.py`. | war.py, combat.py (new), world.py facades, tools/battle_stats.py, tests/support/battles.py, test_architecture.py | Label `refactor`. Oracle identical, save-compat green, goldens identical. The baseline table is pasted in the PR. |
| 1 | **Data model and save version.** `Battle`, `Unit.morale`, `Unit.men`, `WORLD_DEFAULTS["battles"]`, `battle_at`, `VERSION = 2`, invariants that allow battle hexes. Nothing creates a battle yet. | state.py, world.py, saves.py, data.py (`MEN`, `GARRISON_MEN`), invariants.py, test_saves.py | A hand-made battle round-trips through a save. Version 1 saves load. Save-compat green. Oracle: the only difference is the new fields (the reviewer checks the digest with them removed). |
| 2 | **Day resolution, not wired.** `combat.deploy`, `fire`, `shock`, `flanks`, `morale`, `pursuit`, `fight_day`, the numbers in data.py. | combat.py, data.py, test_battle.py (day tests) | Day tests and the scenario bands in 7.3.1 pass. No caller in the game, so the oracle is identical. |
| 3 | **The battle's life, not wired.** `battle.py`: `engage`, `join`, `battle_order_check`/`battle_order`, `battle_season`, `end_battle`, `end_battles`, `retreat_spot`, `army_morale`; `movement.step_in`; events. | battle.py (new), movement.py, events.py, world.py facades, test_battle.py | Contract tests of 7.1 pass when they call `engage` directly. The phase is not in `PHASES` yet, so the oracle is identical. |
| 4 | **The switch (gameplay).** `attack_group` uses `engage`; the bombard option removed; `battle()` deleted; the `battles` phase; the locks of 3.2; peace and extinction; the agents pair; test updates (test_campaign, test_events, test_hud_data, tests/ui/test_hud); perf budget. | war.py, season.py, military.py, supply.py, terrain.py, test_season.py, agents.py, the tests above, perf_budget.json, README | Whole suite green. Soak `--quick` green with the new invariants. Save-compat green. The oracle reports the change by design; the PR says so. The game plays a war without a crash (the stats tool runs). |
| 5 | **AI and tuning.** `_battles`, joining, morale in power. Run `tools/battle_stats.py` and tune data.py to the targets of 7.3. | ai.py, data.py, README tables | The targets of 7.3 are met, or the PR shows the numbers and asks. `test_tech_ai` and the full soak green. Before/after table in the PR. |
| 6 | **Log, ribbons, map badge.** Feed lines, the `battle` icon, `hud/battles.py`, the two-stack drawing, "In battle" in the unit panel, men instead of HP. | feed.py, hud/, ui/icons.py, render/battlemark.py (new), mapview.py (at most 15 lines), panels/unit.py, panels/cards.py | test_hud_data covers the new kinds. A screenshot of a battle on the map at two zooms, reviewed by the art director. mapview.py within its cap. |
| 7 | **Battle panel.** `screens/battle.py`, `battlelayout.py`, `kit.regiment_card`, the press table entries. | screens/, ui/kit.py, app.py (press table only; app.py is at its cap of 917 lines and may not grow past 2%) | Window tests of 7.6 pass. Screenshot at 1280x720 and 1920x1080, compared with mockup 10 and reviewed. Goldens regenerated and reviewed. |
| 8 | **Release check.** README rules and tables final, CLAUDE.md "Battles" bullet, changelog draft for v0.2.0. Nightly soak, perf, save-compat, monkey. | docs only, plus fixes found | All green. The planning session tags v0.2.0. |

PRs 2 and 3 can be one round if the worker finishes early. PRs 6 and 7 touch different files and may run in parallel.
The game on master between PR 4 and PR 7 has battles without a panel (the log and stance-free defaults work). That
is fine because nothing is released before PR 8.

## 9. Risks

| Risk | What could happen | What we do |
|---|---|---|
| AI war pace | Armies locked for 2 to 3 seasons take fewer provinces before `WAR_LENGTH_AI` (16 seasons) ends the war. Wars end in white peace more often. | PR 0 baseline, PR 5 compare. If provinces per war drop more than 30%, raise `WAR_LENGTH_AI` to 20 in PR 5 (a number, not a design change). |
| Steamrolling | A big country wins every battle and the pursuit and surrender rules wipe out small armies faster than today. | The loser's loss share is in the stats. Surrender only with no own hex within reach. Link to `docs/design/stop-steamrolling.md` in PR 5 and check its measures still hold. |
| Stalemates | Two holding armies sit forever. | The 6-season safety stop, the AI's withdraw rule, and an invariant. |
| Bouncing | A beaten army walks back in next season. | `ATTACK_MORALE` 0.5 and `RETREAT_MORALE` 0.3: it needs a season or more to recover. |
| Hidden state | Lane ids drift from the units on the hex. | Ids only; the reserve is derived; invariants check every turn in the soak. |
| Save breaks | A pickled `Battle` in an old build. | `VERSION` 2 makes old builds skip the file. Save-compat and the round-trip test. |
| Balance of one number | `SHOCK_LOSS` and `MORALE_PER_LOSS` decide almost everything. | They are in data.py and the stats tool shows their effect in one run. |
| Size caps | mapview.py and app.py are at their caps. | New modules for drawing and the screen; at most a few lines in the old files. |
| Test churn | 8 call sites of today's battle and attack in tests. | Rewritten in PR 4 only, each to the new rule, not deleted. |

## 10. Owner's decisions (2026-11-13)

1. **Bombardment is dropped.** Battles and sieges both have the two sides on the same hex (see 3.7).
2. **Men everywhere.** Strength shows as men in every panel and card; the rules keep `hp`.
3. **The safety stop is 6 seasons.** The side with lower morale withdraws; target under 5% of battles.
4. Age of Discovery only. Conquest and Colonisation are not changed.
