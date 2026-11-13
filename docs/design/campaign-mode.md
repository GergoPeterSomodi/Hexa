# Age of Discovery: campaign mode (draft for the owner, not approved)

Status: design draft. Nothing is built. Requested in the playtest ideas of 2026-11-12 (focus on Age of Discovery, a campaign mode on the same engine).

## Owner's decisions (2026-11-13)
1. Shape: **a list of stand-alone scenarios first**, a chain later.
2. The name in the menu is **"Chronicles"**; `scenario` in the code.
3. The first scenario is **Portugal** down the African coast.
4. **India is left out** for now; an abstract voyage is decided with the naval design.
5. A missed goal gives **a grade** (gold, silver, bronze or fail), not a loss.
6. A scenario **has its own end date and result screen**, with "Keep playing" to continue as free play.
7. Conquest and Colonisation **become scenarios later**, after the engine works; they are not removed now.
8. The Habsburg and Hanse scenarios **wait for the events and characters milestone**.
9. **Fixed grades, no difficulty setting.**
10. The Portugal blurb **says plainly** that the Atlantic slave trade is not modelled yet; the scenario is revised when the triangle trade design lands.

## Questions for the owner
1. **Shape:** (A) a list of stand-alone scenarios; (B) a chain where each scenario carries something into the next; (C) a map of Europe where each step is a choice. Recommend **A first, B later**. The scenario engine is the same.
2. **Name:** in the code, Age of Discovery is already called "campaign" (`--mode campaign`). Calling scenarios "Campaign" in the menu would confuse players and code. Options: "Scenarios", "Chronicles", "Voyages". Recommend **"Chronicles"** for players and `scenario` in the code.
3. **First scenario:** Portugal down the African coast, the Habsburg marriages, or the Hanse decline? Recommend **Portugal** (see below). Note: the real map ends at 13 S and 46.5 E, so the Cape of Good Hope and India are not on it. The scenario stops at what the map shows.
4. **India later?** Options: (a) leave India out; (b) an abstract "voyage to the Indies" from the map's edge (a new mechanic); (c) extend the map. Recommend **(a) now**, and decide (b) with the naval design.
5. **Fail state:** if a goal is missed, is the scenario lost, or does it end with a lower grade? Recommend a grade (gold, silver, bronze, fail), so a near miss still feels good.
6. **Does a scenario end the game early?** Recommend yes: a scenario has its own end date and a result screen, with a "keep playing" button that turns it into free play. Free play (the full 1480-1650 game) is unchanged.
7. **Do the old modes become scenarios?** Recommend yes, later: Conquest and Colonisation only after the scenario engine works. Do not remove them now.
8. **Scripted events?** The Habsburg and Hanse scenarios need scripted events (a wedding, a death). Recommend waiting for the events and characters milestone for those two. Portugal needs none.
9. **Difficulty and grading:** fixed grades from scored goals, no difficulty setting (as in the achievements doc). OK?
10. **West Africa and the slave trade:** the Portugal scenario is set where and when the Atlantic slave trade grew. The game does not model it yet. Options: (a) the blurb says so plainly, and the scenario is revised when the triangle trade design lands; (b) wait for that design before building Portugal. Recommend **(a)**.

## Goal
The main game stays the long 1480-1650 campaign over many evenings. Scenarios sit next to it: a clear story, a target and a finish line in one or two evenings. The player picks a scenario, plays a short span of history with a few goals, and gets a grade. Scenarios teach the game step by step, lead new players into the full game, and give replay value for Steam.

## Inspirations
- Europa Universalis: mission trees (each country has goals with rewards).
- Civilization: scenarios with fixed starts and win conditions.
- Board games (Twilight Struggle, Pax Pamir): short, scored, with a clear end year.
- Hexa's own: one season is one turn, so a 30-year scenario is 120 turns. With the AI's turns on the Europe map, that is a few hours: one or two evenings, not a lunch break. A shorter first scenario (15-20 years, 60-80 turns) is worth testing.

## Rules

### What a scenario is
A scenario is **data**, not code. One entry in `SCENARIOS` in `hexa/campaign/scenarios.py` (data module, no pygame):
- `id`, `title`, `blurb`, `player` (a tag), `map` (the real Europe map only), `start_year` (1480 or later: the map's data is for 1480), `end_year`;
- `setup`: optional changes to the 1480 start (more ducats, a fleet, an extra tech);
- `goals`: a list of goal records, each with `kind`, parameters, `points` and a `required` flag;
- `grades`: points needed for bronze, silver, gold;
- `rules`: switches, such as "the player may not declare war before 1500" or "AI peaceful until 1490".

### Goal kinds (a small fixed set, each tested by one function)
| Kind | Example | Checked from |
|---|---|---|
| `own_province` | Hold Lisbon by 1510 | province owner at a turn |
| `found` | Found a trading post south of the equator | `colony_founded` |
| `tech` | Know 2 era I Navigation techs | `tech_researched` |
| `era` | Reach era II by 1525 | `era_reached` |
| `income` | 400 ducats income by 1510 | ledger |
| `survive` | Still own the capital in 1510 | province owner |
| `prestige_rank` | Top 3 prestige | prestige list |
| `war_won` | Win a war against Castile | `peace_made` (`winner`) |
| `no_war` | Declare no war before 1500 | `war_declared` |
| `own_all` | Own N provinces of a region | region list (`regions.py`) |

Each goal has a **deadline** (a turn) and a state: waiting, done, failed. Points are given when done, at the turn it is done (early bonus: x1.25 if done before half of the time).

### Grades
Points over the scenario. Required goals must be done for silver or gold. Grades are stored in the profile file (the same file idea as achievements), not in saves.

### Chains
A chain is a list of scenario ids with a **carry** rule between them. A carry is small and plain:
- a **legacy** point total, which gives a small start bonus (+ducats, +1 merchant) in the next scenario;
- one **kept idea card**;
- the country can change (Portugal, then Spain).
Nothing else is carried, so each scenario is fair when played alone. The chain state lives in the profile.

## The three scenarios

### 1. Portugal: down the African coast (1480-1510, 120 turns) - recommended first
Why first: it needs the least new code. It uses exploration, trading posts, colonies, ports and research, all of which exist. It has no scripted events and no characters. It teaches the heart of the game, the age of discovery.

Checked against today's rules: Portugal (POR) knows the African coast from turn 0 (`COLONIAL`), trading posts may be founded in Africa south of 17 N and east of 20 W, and the Astrolabe tech (Navigation, era I) allows colonies across the Atlantic. Era I Navigation has three techs: Portolan charts, Carrack and Astrolabe.

- **Start:** Portugal (POR), real 1480 map. Setup: +300 ducats and a caravel.
- **Goals** (points):
  1. Know 2 of the 3 era I Navigation techs by 1490 (20, required).
  2. Found a trading post on the Guinea coast (south of 10 N) by 1492 (20, required).
  3. Found a trading post south of the equator by 1500 (30).
  4. Found a colony across the Atlantic by 1508 (Brazil was reached in 1500) (40, required for gold).
  5. Reach 400 ducats income by 1510 (20).
  6. Still own Lisbon in 1510 and lose no war (20).
  7. Optional: own 3 spice provinces by 1510 (20).
- **Grades:** 100 bronze, 140 silver, 170 gold (tune in a measured run).
- **Teaches:** research, ports, posts, colonies, income.
- **Honest framing:** the blurb says what the voyages were for (gold, spices and a sea route to Asia) and who was already there. The African peoples on the coast (Wolof, Akan, Benin, Kongo) were kingdoms and trading partners, not empty land. The Atlantic slave trade began on this coast in these years. The game does not model it yet; the blurb names it and does not hide it, and the scenario is revised when the triangle trade and tribal nations designs land. No goal rewards taking African land by force.

### 2. The Habsburg marriages (1480-1530)
- **Start:** Austria (AUS) or Burgundy (BUR). (The marriage of 1477 has already happened by the map's 1480 start; the scenario opens just after it.)
- **Story:** Spain, Bohemia and Hungary come to one house by marriage.
- **Goals:** gain thrones by marriage, not by war (hold N provinces of BUR, CAS, ARA, BOH, HUN by treaty); stay at peace with France.
- **Needs:** a marriage action in diplomacy (does not exist), dynasty and heirs (events and characters milestone), scripted events. **Do not build before** that milestone. It is the best second or third scenario.

### 3. The Hanse decline (1480-1560)
- **Start:** the Hansa (HAN).
- **Story:** keep the Baltic trade against Dutch, English and Danish pressure.
- **Goals:** keep Lubeck, keep the league (see city states), hold a market share in grain and fish, avoid tribute to Denmark.
- **Needs:** leagues (now moved to the diplomacy rework in `city-states.md`) and a market-share goal kind. A good fit **after** both ship.

### Later scenarios on the same engine
- **Conquest:** the old match as a scenario: a small generated map, goal `capture_castle`. Needs a new goal kind and a fixed-size map.
- **Colonisation:** a start with a colony ship, a goal of `population` or `independence`. Needs a goal kind `colony_independent`. It must follow the tribal nations design.
Both only add goal kinds and a `setup`. They keep their own old apps until the engine can host them.

## Player and AI
- **Player:** picks a scenario in a new "Chronicles" menu page; plays with the full game UI plus a goals panel; sees a result screen with the grade.
- **AI:** unchanged by default. A scenario may set `ai_hints`: for example "Castile does not attack Portugal before 1495", so the story is possible. These are simple flags read by the AI, not new AI.
- AI countries do not have goals. Their behaviour is what the sandbox already does.

## UI
- **Chronicles page** in the start menu: a list of scenario cards (title, years, country, best grade).
- **Intro card:** a short story, a map crop and the goals, before the first turn.
- **Goals panel:** a collapsible list on the HUD: goal text, deadline and a tick. Clicking a goal jumps the camera to the place. New HUD module `hud/goals.py`.
- **Notices:** an action-log line when a goal is done or failed, plus a floating tag at the place.
- **Result screen:** a `Screen` with the grade, points, goals done, "keep playing" and, for chains, "next scenario".
- UI proposals live in `docs/design/ui/` (see mockups).

## Interactions
- **Achievements:** a scenario can give its own achievements. They read the `goal_done` event.
- **City states:** the Hanse scenario depends on leagues.
- **Tech tree, economy, war:** untouched. They produce the events that goals read.
- **Events and characters (Phase 3):** needed for marriages. The scenario engine will call scripted events through the same event layer when it exists.
- **Triangle trade and tribal nations:** the Portugal and Colonisation scenarios must be revised when those designs land.
- **Saves:** the scenario id and goal states are saved with the game, so a scenario can be saved and loaded.
- **Multiplayer:** a scenario with one human is fine; shared scenarios need an owner decision later.
- **Difficulty:** none; grades only.

## Risks
- **Pulling focus from the main game:** scenarios are the on-ramp, not the product. The long 1480-1650 game must stay the heart of the Steam page.
- **Too long for a "short" mode:** 120 turns with AI turns is hours. Measure a real Portugal run before fixing the length.
- **Off-map history:** India and the Cape are not on the map. The scenario must not promise them.
- **Too scripted:** if the AI ignores the story, the scenario feels random. Keep goals about the player's own choices, not the AI's.
- **Too easy to cheese:** a goal such as "found a post" can be done at once with no cost. Use deadlines and minimums (a post that still stands at the end).
- **Sensitive history:** West Africa 1480-1510 is where the Atlantic slave trade began. Handle it as question 10 says: honest, never glorified, revised with the triangle trade design.
- **Name clash:** "campaign" already means Age of Discovery in the code; use `scenario` for the new system.
- **Scope creep:** mission trees can grow forever. Keep the goal list to the ten kinds above.
- **Chain locks:** forcing players to finish the first scenario for the second is annoying. Recommend all scenarios open from the start.
- **Structure not there yet:** `hexa/campaign/systems/` and `systems/season.py` arrive with the refactor phases. Build after those land.
- **Save and tests:** goal state must be deterministic. Tests replay with fixed seeds.

## Smallest first version
- The scenario engine with 5 goal kinds: `found`, `tech`, `income`, `survive`, `era`.
- One scenario: Portugal, down the African coast.
- A goals panel, a result screen and a "Chronicles" menu entry with one card.
- Grades stored in the profile. No chains, no carry.
About two worker rounds: rules, then UI.

## Build plan (fits the structure rules)
1. **Data:** `hexa/campaign/scenarios.py` (pure data: `SCENARIOS`, goal records) and constants in `data.py`.
2. **Rules:** `hexa/campaign/systems/scenario.py` (pygame-free). Functions `goal_check(world, goal)`, `evaluate(world)`, `start_scenario(world, id)`. `OWNS = {"scenario"}`. New world attribute `scenario` (id, start turn, goal states, done flag), added to `WORLD_DEFAULTS` as `None`, so old saves load as free play and no `VERSION` bump is needed.
3. **Season order:** add a `scenario` phase to `systems/season.py PHASES`, at the end, after research and before the autosave. It evaluates goals only; it never changes other systems.
4. **Events:** new kinds `goal_done`, `goal_failed`, `scenario_ended` (tag, `id`, `grade`, `points`). Added to `CAMPAIGN_KINDS` and the docstring. Goals read existing events through a tap or from world state; handlers do not change the world.
5. **Actions:** `start_scenario_check/start_scenario` pair, with a facade on `CampaignWorld` and a pair in `tests/support/agents.py`. The menu calls it; the AI does not.
6. **Game manager:** `GameManager.start(scenario_id)` builds the world with `setup` applied (through public actions and data, not by poking attributes), and stops at the scenario's end until the player picks "keep playing".
7. **Profile:** grades in the profile file shared with achievements (`hexa/profile.py`). Never in saves.
8. **UI:** `hud/goals.py`, `screens/scenario_result.py`, a Chronicles page in `menu.py`/start flow; widgets from `kit`, colours from `theme`.
9. **Tests:** one test per goal kind with a prepared world; a determinism test (two runs, same digest); a save and load test mid-scenario; a test that free play ignores the scenario code. README gets a "Chronicles" section. Oracle: add a prepared scenario state to `tools/oracle_runner.py` when the system lands.
10. Not a refactor PR. Split into two PRs: engine and scenario, then UI.

## Mockups needed before any build
1. The Chronicles menu page with scenario cards (open, best grade).
2. The scenario intro card (a short story, map crop, goals list), including the Portugal blurb text for the owner to read.
3. The goals panel on the HUD (collapsed, expanded, one goal done, one failed).
4. The result screen with the grade (gold, silver, bronze, fail) and "keep playing".
5. For chains (later): the carry screen with legacy points and the kept idea card.

## Creative director review (2026-11-12)
**Verdict: ready for the owner, after the fixes made here.** The engine idea is sound: scenarios as data, a small set of goal kinds, nothing changed in the core game. But the first scenario promised the Cape and India, which are off the map, so I reworked it into "down the African coast" with goals the current rules allow. I also fixed the play-length claim and a naming clash, and added honest framing for West Africa.

Weigh most:
1. **Scenarios are the on-ramp, not the product.** The long 1480-1650 game stays the heart of the Steam release. Is a scenario mode worth building before M4 makes that game fun?
2. **The Portugal blurb and the slave trade** (question 10): honest now, revised later, or wait for the triangle trade design.
3. **Timing:** it needs the refactor's `systems/` layout, so it fits after the architecture phases, not before.
