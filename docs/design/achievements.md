# Age of Discovery: achievements (draft for the owner, not approved)

Status: design draft. Nothing is built. Requested in the playtest ideas of 2026-11-12 ("for Steam too").

## Owner's decisions (2026-11-13)
1. **All visible**, the odd ones included. No "???" entries.
2. Only **Age of Discovery games with no cheat or debug option** count. Random worlds count, except achievements that name a real country or city.
3. **No difficulty setting**; skill achievements use fixed conditions.
4. **12 first**, the rest after a playtest.
5. **Hard rule:** no achievement ever rewards the slave trade, raids on tribal nations or taking their land.
6. **One string key per achievement**, mapped one-to-one to Steam.
7. **Names:** we propose a list; the owner approves it.

## Questions for the owner
1. **Hidden or shown?** Options: (a) all visible; (b) all visible, but "odd" ones show as "???" until earned; (c) all hidden. Recommend (b): it teaches the game and keeps the jokes fresh.
2. **Which games count?** Options: (a) any game; (b) only Age of Discovery; (c) Age of Discovery only, and never a game with a cheat or debug option on. Recommend (c). Random worlds count, except achievements that name a real country or city.
3. **Difficulty:** there is no difficulty setting today. Recommend none now. Skill achievements use fixed conditions (for example "never more than your starting provinces + 5").
4. **Count:** ship all 36 at once, or start with 12? Recommend 12 first (see the smallest version), then the rest after a playtest.
5. **Slave trade and tribal nations:** recommend a hard rule: no achievement ever rewards the slave trade, raids on tribal nations, or taking their land. Whether a later "abolition" achievement fits is decided with the triangle trade design, not here. Default: none.
6. **Steam ids:** keep one string key per achievement, mapped one-to-one to the Steam name. OK?
7. **Names:** the names below are placeholders. Do you want to name them yourself, or approve a list from us?

## Goal
Achievements give small goals beyond winning, show what the game can do, and are needed for Steam. They never change the rules. A player can ignore them.

## Rules
- An achievement has a stable `key` (never renamed), a name, a text, a `kind` (easy, story, skill, odd), a `hidden` flag and a detector.
- Earned once per profile, not per game. We store the date and the country.
- Detectors only read events and the world. They never change the world (the bus rule in `CLAUDE.md`).
- A game with a cheat or debug option earns nothing. Today the only such switch is `HEXA_DEBUG=1`, which is a developer flag. Any future console or cheat must set the same "no achievements" mark on the game.
- Thresholds live in one `ACHIEVEMENTS` table in `hexa/campaign/data.py`.
- **Taste rule:** no achievement for the slave trade, for harming or displacing tribal nations, or for massacres and sacking. Jokes are about the player's own mistakes, never about other peoples.

## The list (36)
"Event" is a bus kind from `hexa/events.py`. "Poll" is a check of world state on `season_ended`. P is the player's tag. One turn is one season; spring 1480 is turn 0. A province is one land hex (Portugal starts with 27, Venice 43, Genoa 8).

**Needed event data (additive):** the `battle` event today carries only `defender` and `ranged`. Several detectors need a `winner` and the units each side lost. Add them as new fields; old handlers ignore them.

### Easy (10): learn the game
| Name | Condition | Detect |
|---|---|---|
| First Blood | Win a battle | `battle` with P in it, `winner` P (new field) |
| Hold the Gates | Win a battle as defender | `battle`, defender P, `winner` P |
| Foothold | Take a province by siege | `province_captured`, by "siege", tag P |
| Storm the Walls | Take a province by storm | `province_captured`, by "storm", tag P |
| Quill and Ledger | Research a first tech | `tech_researched`, tag P |
| Mason's Pride | Finish a castle | `building_done`, what "castle", tag P |
| A New Page | Reach era II | `era_reached`, era 2, tag P |
| The Olive Branch | End a war you declared with peace | `peace_made` with P, after a `war_declared` by P on the same enemy |
| Merchant Prince | Merchants profit 4 seasons running | poll: merchant profit in the ledger > 0 four times. Teaches merchants, which the 2026-11-11 playtest found unused. |
| Out of the Red | Leave debt after being in debt | poll: treasury >= 0 now, stored flag "was in debt" |

### Story (10): the age itself
| Name | Condition | Detect |
|---|---|---|
| Below the Line | Found a trading post south of the equator | `colony_founded`, what "trading post", latitude < 0 |
| Across the Ocean Sea | Found a colony across the Atlantic | `colony_founded`, `not world.in_old_world(pos)`, west of 30 W |
| Spice Monopoly | Own 3 provinces whose good is spices | poll: provinces with good "spices" >= 3 |
| The Grand Tour | Explore 60% of the sea hexes | poll: explored sea hexes against the sea total |
| Union by Treaty | Gain a major country's capital by peace | `peace_made` with `moved` holding a capital. (Becomes "Golden Marriage" once marriages exist.) |
| Gunpowder Age | Reach era III in its first years | `era_reached`, era 3, year < 1580 (era III opens in 1575, so this is a 5-year window) |
| Unbroken Crown | Still hold your starting capital in 1650 | poll, last turn |
| The Hanse Endures | As the Hansa (HAN), still hold Lubeck in 1650 | poll, last turn |
| Venetian Glass | As Venice (VEN), top income in 1550 | poll at 1550, compare all countries |
| Queen of Cities | Take Constantinople from another country | `province_captured`, pos = Constantinople. The Ottomans hold it in 1480, so as them it means retaking it. |

### Skill (9): hard but fair
| Name | Condition | Detect |
|---|---|---|
| David and Goliath | Win a war you declared on a country with 3x your provinces | `war_declared` with a size `ratio` (new field), then `peace_made` with `winner` P |
| Iron Discipline | Win 5 battles in a row, losing no unit | counter on `battle` (`winner`, losses: new fields); resets on a loss |
| No Deserters | Fight a war of 20+ seasons, win 3+ battles in it, and have no `unit_deserted` | counters per war. The battle count stops a far-away "paper war" from earning it. |
| Bulwark | Be declared war on 3 times, and lose no province for 20 years | `war_declared` (target P), `province_captured` (loser P), timers |
| Balanced Books | 20 seasons in a row with surplus and no debt | poll: net income > 0, treasury > 0 |
| Small is Beautiful | Reach era III without ever owning more than your starting provinces + 5 | poll: stored max province count, then `era_reached` 3 |
| Quick Study | Know 12 techs before 1560 | poll: tech count, year. Tune with a measured run so it is hard, not normal. |
| The Long Game | Be in the top 3 by prestige in 1650 | poll, last turn |
| Peaceful Merchant | Reach 1600 having declared no war, with income in the top 5 | stored flag on `war_declared`; poll at 1600. The income part stops a do-nothing game from earning it. |

### Odd (7): jokes and quirks
| Name | Condition | Detect |
|---|---|---|
| Snowed In | Be stopped by a closed pass in winter | `pass_closed` plus a `march` notice naming a pass for an army of P |
| The Last Straw | Your whole army deserts in one season | `unit_deserted` count equals all war units of P |
| Sunk Cost | Lose 5 ships in one season | `unit_lost`, why "sunk", counted per season |
| Kitchen Table Diplomacy | Make peace within 1 season of declaring war | `war_declared` then `peace_made`, turns apart <= 1 |
| Paper Tiger | Declare war on a country with 5x your provinces | `war_declared` with `ratio` >= 5 |
| Here Be Dragons | A ship of yours reaches the edge of the map | poll: a ship of P on an edge hex |
| Bankrupt Emperor | A creditor seizes your castle | `debt_seized`, tag P |

Names are placeholders for review.

## Player and AI
- Only the player's tag is tracked. The AI does not earn or know about achievements.
- AI-dependent ones (David and Goliath, Bulwark, The Long Game) read honest world state, so AI strength shifts their difficulty a little, as it does for everything.

## UI
- **Toast** at the top when earned: icon, name, text, about 4 seconds. Uses `kit` panels and `theme` colours.
- **Achievements screen:** a `Screen` in `campaign/screens/achievements.py`, opened from the start menu and the pause menu. A card grid with tabs per kind. Earned cards in colour with the date, locked cards two-tone grey, hidden cards "???". A line on top: "14 of 36".
- **Progress:** locked cards with a counter show it ("Balanced Books: 12 of 20 seasons"), so streaks are visible.
- **Action log:** a line "Achievement: Foothold", with a new notice kind `achievement` in `feed.NOTICES`.
- **End-of-game list** once an end screen exists.
- UI proposals go in `docs/design/ui/` (see mockups below).

## Storage
- Never in saves. Saves are per game; achievements are per profile.
- One file `achievements.json` in the settings folder (the same place as the options). Shape: version, `earned` (key to turn, year, country) and `progress` (key to number).
- Written atomically (temp file, then rename). A missing or broken file becomes an empty profile with a log line. It must never crash the game.
- Streak counters live in the tracker for the session. A reload resets them. That is a known small loss; it keeps saves clean.

## Interactions
- **Bus:** reads events through `bus.tap`. A failing tap is already caught by the bus.
- **Tech, debt, war, colonies:** they only supply events. Additive changes: `ratio` on `war_declared`; `winner` and losses on `battle`.
- **City states and campaign mode:** scenario goals are not achievements. A scenario may add its own achievements, whose detectors check the scenario id.
- **Triangle trade and tribal nations:** their designs must not add achievements that break the taste rule above.
- **Multiplayer:** each human has a profile slot; deal with it when multiplayer is designed.

## Risks
- **Cheese:** "Kitchen Table Diplomacy" and "Paper Tiger" can be farmed with a ten-second war. Accepted: they are jokes, and earned once.
- **Do-nothing games:** any achievement that a player can earn by pressing End season (no war, no spending, survive) needs a second condition. Checked above; check again for new ones.
- **Save scumming:** allowed. Streaks reset on load, so they need one session.
- **Steam cannot take an achievement back.** A detector bug that hands one out wrongly is permanent for that player. Test every detector before the Steam build, and ship the Steam hook later than the local list.
- **Missing event data:** the `battle` and `war_declared` fields above do not exist yet. Without them, five achievements cannot be built.
- **Structure not there yet:** `hexa/campaign/systems/` and `systems/season.py` arrive with the refactor phases. Until then the tracker sits where the structure rules allow.
- **Edited or debug games** earn nothing.
- **Grind:** none needs more than one game.
- **Spoilers:** story names reveal events; the hidden mode fixes it.
- **Taste:** the slave trade and harm to tribal nations are excluded on purpose.

## Smallest first version
12 achievements: the 10 easy ones plus Gunpowder Age and Queen of Cities. Tracker, JSON file, toast, a plain list screen with text cards and no icons. No Steam. About one worker round, plus the `battle` event fields.

## Steam mapping (later)
- The `key` becomes the Steam API name (same string, upper case, for example `ACH_FIRST_BLOOD`).
- A thin platform module wraps the Steam stats calls. A `NullPlatform` is used without Steam, so tests and offline play do not change.
- At start, sync both ways: a key earned locally is sent to Steam; a key earned on Steam is added locally. The result is the union of both.
- Steam wants a name, text and two icons (earned and grey) per achievement. The icon sheet must export at the size Steam asks for.

## Build plan (fits the structure rules)
1. `hexa/campaign/systems/achievements.py` (pygame-free): the detector table and a `Tracker` with `on_event(event)` and `on_season(world)`. It writes no world attribute, so `OWNS` is empty. Profile file read and write in a small `hexa/profile.py`, outside the world.
2. Thresholds and the table in `campaign/data.py` as `ACHIEVEMENTS`, plus a README section.
3. `GameManager` makes the tracker, taps the bus and calls `on_season` on `season_ended`. The tracker emits a new kind `achievement_earned` (tag, `key`). Add it to `CAMPAIGN_KINDS` and the docstring. Toast and log handlers subscribe; they do not change the world.
4. Additive event data: `ratio` on `war_declared`; `winner` and per-side losses on `battle`. No new world attribute, so no `WORLD_DEFAULTS` entry and no `VERSION` bump.
5. `screens/achievements.py` and a toast in `hud/`. Icons through `ui/icons.py` and a `BoundedCache`.
6. Tests: one per detector with a hand-made `bus.emit`; a corrupt-file test; a debug-flag test; a test that the tracker never changes the world (digest before and after). Not a refactor PR.

## Mockups needed before any build
1. The toast in the HUD.
2. The grid screen: earned, locked (with progress), hidden, with tabs.
3. Icon sheet for all 36, in the game's flat two-tone ink style.
4. The end-of-game list (only if an end screen is designed).

## Creative director review (2026-11-12)
**Verdict: ready for the owner.** The design is small, read-only and fits the event bus. I fixed one impossible achievement (India is off the map), renamed three with bad echoes ("Peace in Our Time", "Fortress Europe", "Defender of the Faith"), replaced a joke about native raids and an AFK one ("Penny Wise"), and closed do-nothing cheese.

Weigh most:
1. **The taste rule** (question 5): no achievement for the slave trade or harm to tribal nations, written down now, before those designs exist.
2. **Steam cannot take an achievement back:** ship the local list first, and the Steam hook only after a playtest.
3. **12 first, then 24 more** after a playtest shows which goals players actually chase.
