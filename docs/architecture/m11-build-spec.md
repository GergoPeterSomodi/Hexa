# M11 build spec: Research

Game and systems designer (Opus), 2026-11-17. **Status: a proposal, design only; it waits for the owner's go.** Builds milestone
M11 of `docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`), the M1.5 UI foundation
(`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`) and the M2 to M10 specs and plans (`m2-build-*.md` to `m10-build-*.md`,
with `m4-5-build-*.md`). Where this page is more exact it wins for M11; section 1.2 lists every place where it refines an earlier page.
The tasks are in `m11-build-plan.md`. This page carries the M11 row of the standard's 9.1 (the tech screen, the idea pick, the
Research page), the M11 row of `ui-and-controls-plan.md` section 4 (the tech screen, opaque, T; the idea pick, modal; the research
chip; the Research study page) and of `ui-style-and-feedback-plan.md` S5 (the Research page, the report's research line, the idea pick
as a decision). It builds the approved tech tree of `docs/design/tech-tree.md` and `docs/design/tech-tree-build-spec.md` (built in
v0.2.2) re-fitted to districts, and the generals M7 moved here (`m7-build-spec.md` D36).

**What M11 is.** Every country studies. Each season its towns, its walled towns and cities and a base share make **research
points**; the points go to the tech it researches, then to the next in its queue. A tech belongs to one of **four branches**
(Military, Trade & Industry, Navigation, Statecraft) and one of **three eras** (the Age of Pikes, of Arquebus, of Musket). An era opens
for a country in **1520** (1575 for the third) once it knows **4 techs** of the era before; it brings that era's four kinds of company
(raised from then on, and old companies **refit** in a town) and an **idea card**: one of three, the nation's own and two drawn toward
the branch it studied most. Ducats buy points once a year (**funding**); a tech is cheaper when countries you trade with know it
(**diffusion**). Every country starts with its **national tech**. A tech or an idea **changes the game only through definitions**: its
effects are rows of a modifier table, and every system reads its numbers from the country's own **effective definitions**
(`Game.defs_of(tag)`), never from a list of techs. **Generals** join the game: a country appoints a few, each with one of five traits,
to lead an army: a larger stack, a fifth more in the trait's fight, a smaller morale loss. The AI researches, funds, picks its ideas,
appoints generals and refits by its temperament. The player sees it all: the **tech screen** (T) with its grid, research strip, queue
and side card, the **idea pick**, the **Research chip**, the **Research page** of the study, the report's Research section, the general
and refit rows of the army panel, the log, the reminders and the console.

**When it starts.** After M10 is closed (its plan's definition of done, and the owner has played it). M11 edits `Game`, `Session`,
`Events`, the action and season tables, `Country`, `Army`, `Unit`, `BattleRecord`, `Stats`, `GameDefs`, `WarDef`, `UnitDef`,
`AiDef`, `AiTemperDef`, `Economy`, `EconomySeason`, `DistrictCache`, `People`, `Works`, `Military`, `Armies`, `Supply`, `SupplyCache`,
`Vision`, `SightCache`, `Combat`, `Battles`, `BattleEnd`, `Occupation`, `Sieges`, `WarGoals`, `Peace`, `Brakes`, `Unrest`, `Trade`,
`TradeCache`, `Merchants`, `StatsSystem`, `Chronicle`, `Knowledge`, `Words`, the report's view, the reminders, the log lines, the study's
views and pages, the hex, country, army and battle views and panels, the chips, the console, F3, the App, the AI, the soak and the perf
tools, and builds its screens into the M1.5 frame as M10 left it.

**M11 is done when:**

1. **Techs change rules through definitions only.** (a) `tests/core/test_research_data_only.gd` scans every file of `core/systems/`,
   `core/game/`, `core/ai/` and the rule-reading views of `core/views/` outside the allowed list of 5.8 and finds no read of
   `Country.techs`, `.ideas`, `.pending_ideas`, `GameDefs.techs`, `GameDefs.ideas`, no `TechDef`, `IdeaDef` or `ModDef` and no tech or
   idea key; a planted test-only file reading `country.techs` is reported. (b) `tests/core/test_mod_hooks.gd` grants, for each of the 55 keys of the
   registry (4.2), a test tech with only that effect to one country, and the key's probe moves by exactly the amount of the table
   for that country and not at all for its neighbour; a planted hook that reads `game.defs` instead of `game.defs_of(tag)` fails its
   probe. (c) Every effect of every `TechDef` and `IdeaDef` names a registered key with an allowed operation, and applying every tech,
   idea and national tech at once stays inside every key's bounds (`test_research_data.gd`).
2. **An era passes in play.** In the nightly `research` soak suite (10 AI-only games of 440 seasons, Genoa's research step scripted,
   4.19) the median turn of reaching the Age of Arquebus over all country-games is **161 to 189** (Spring 1520 to Spring 1527), at least
   **80 %** of country-games are in it by turn 240, at least **50 %** are in the Age of Musket by turn 440, the scripted Genoa reaches
   the Age of Arquebus by turn 169 in at least 9 of 10 games and the Age of Musket by turn 420 in at least 7, and the `research`
   invariant holds every season. On every pull request `tests/core/test_research_italy.gd` plays seed 1480 with no AI and Genoa's research
   scripted, and Genoa enters the Age of Arquebus in the research phase of **Spring 1520 (turn 161)**, offered three cards with
   Genoese factors first.
3. **The tree.** 37 tree techs in 4 branches and 3 eras, 13 national techs and the default, 16 general and 13 national ideas, with the
   costs, prerequisites and effects of 4.3 to 4.6 exactly; the prerequisites acyclic; every tree tech reachable from the start; every
   prerequisite of an era at or below its tech's; costs monotone by era (the dearest of an era under the cheapest of the next)
   (`tests/core/test_research_data.gd`, each with a planted fault).
4. **Points and costs.** On a new game of seed 1480 the 13 countries' research rates are 4.7's table exactly; in `ResearchFixture.duo`
   (4.18 a) East learns Crop rotation in the research phase of turn 25 and West, a trade partner, in turn 29 (32 without diffusion); a
   funding gives 6,000 milli-points (7,500 with Casa di San Giorgio) for 80 ducats once in 4 seasons (`test_research_rate.gd`,
   `test_research.gd`).
5. **The queue, the gate and the ideas.** Every row of the five research checks with its planted fault; a far tech queues its path;
   points beyond the cost carry to the next queued tech in the same phase; points with nothing researched are kept up to four
   seasons' worth; the gate opens exactly when both the year and the count hold; the offer is the nation's card plus two general
   cards drawn with weight 3 toward the top branch, from `luck.world`, seeded and pinned; an offer still open at the next era adopts
   its first card (`test_research.gd`, `test_era_gate.gd`, `test_research_ideas.gd`).
6. **Generals.** M7's worked hit (pikemen on Attack against pikemen on Hold, roll 4, spread 1000) gives **40** men with a Field marshal
   on the attacker's side and **28** with a Defender on the defender's (33 without); a side with a general holds `8 + 2` companies on
   its hex; Genoa may appoint 1 general, Milan 2, Venice 3 at the start; every row of the two general checks with its planted fault;
   a general is lost with its army and passes on a merge (`test_generals.gd`, `test_combat.gd`).
7. **Later kinds and refits.** In the Age of Arquebus Genoa raises landsknechts, arquebusiers, lancers and culverins and no kind of the
   Age of Pikes; its Army of Genoa (2 pikemen, 1 crossbowmen) at Genoa (8, 13) refits for **47 ducats and 3 iron** and musters that
   season (`test_refit.gd`).
8. **Contracts.** `tests/core/test_check_contract.gd` drives the random player over the 38 actions: a refused check changes nothing,
   an allowed one succeeds.
9. **Determinism and saves.** Same seed and same action log give the same digest after 40 seasons of research with the dev records
   (`test_replay.gd`); save, load, save gives byte-equal files with techs, queues, progress, ideas, offers, generals and refit turns;
   ten seasons after a load give the digest of ten without; `SaveFile.FORMAT` is 9 and an M10 save reads "Made by an older test build"
   (`test_research_saves.gd`).
10. **The AI researches.** In the nightly `ai` suite the ranges of 4.19 hold (techs known at season 80, fundings, generals appointed)
    and in the `research` suite its era and pace ranges; the invariants `research` and `generals` hold in every game of every suite.
11. **Time in budget.** On the made-up Europe the rows of section 8 hold in the nightly `perf_core.gd` run: the sixteen phases other
    than `ai_orders` under 440 ms, the research phase under 8 ms, every country's effective definitions from cold under 30 ms, the AI
    season under M8's 3,000 ms mean; on north Italy the research phase under 1 ms.
12. Every M11 UI row of the standard's 9.1 is in the game, built from the M1.5 kit, each with its GUT test: the tech screen (T) with its
    top band, strip, queue, era headers, grid, links, side card, legend and keyboard path; the idea pick in `DECISIONS`; the Research
    chip; the Research page; the report's Research section and lines; the country panel's research section; the army panel's general
    and refit rows; the Raise tab's kinds by era; the hex panel's learning line; the battle dock's and odds card's general lines; the
    log, notifications, ribbons, toasts, reminders and the console. No stand-in is left.
13. Lint, import, check_scripts and GUT are green, with both UI `--check`s, `build_map --check` and `build_scenario.gd --check`; the art
    director has signed the research sheet and the pictures of section 9; the owner has played the build through the plan's checklist.

---

## 1. What is there, and where this page refines earlier pages

### 1.1 Read in the code (master `5c8ddf3`), the data, v0.2.2 and the specs

| Finding | Where | What it means for M11 |
|---|---|---|
| `GameDefs` holds `countries`, `scenarios`, the tinctures and the palette; M3 to M10 add `families`, `goods`, `units`, `terrains`, `war`, `ai`, `tempers`, `diplomacy`, `trade` and their numbers | `core/defs/game_defs.gd`; `m3-build-spec.md` to `m10-build-spec.md` 5.1 | Every number a tech may change already sits in a definition; M11 adds a way to change it per country (4.1) |
| No earlier page defines a modifier: M4 to M10 hand to M11 "techs change `FamilyDef`, `growth_bp`, `WarDef`, `DiplomacyDef`, `TradeDef` numbers through definitions only" | the section 12 of `m4` to `m10-build-spec.md` | M11 builds the modifier engine and the per-country definitions (D4 to D7) |
| `Bindings.DEFAULTS` holds `game_tech` (T, "Technology screen", `since: "11"`) | `shell/input/bindings.gd` | The key exists; it registers when the App's milestone becomes `"11"` |
| `ScreenIds.PATHS` holds `tech` (`res://shell/screens/tech.tscn`) and `idea_pick` (`res://shell/screens/idea_pick.tscn`); the scenes do not exist | `shell/screens/screen_ids.gd` | M11 writes both scenes at those paths |
| `Settings.SCHEMA` `state/study_page` lists `research` | `shell/app/settings.gd` | No settings key is added |
| `Stats.SERIES` has had `research` since M3 (0 until its milestone); M10 leaves 58 series | `m3-build-spec.md` 4.6, `m10-build-spec.md` 4.20 | M11 writes `research` and appends `techs` and `era` (60) |
| M4 baked the `research` chip icon for M11 | `m4-build-spec.md` 6.2 | The Research chip needs no new chip art |
| M6's kinds are era 1 only (`UnitDef.era` 1); "M11 brings later eras" and refit | `m6-build-spec.md` D4, 12 | Eight later kinds and the `refit` action (4.10) |
| M7: "No generals in M7; they come with M11 (D36)"; the dock shows "No general" greyed; M7's hand-off: a stack +2, one term each in attack, defence and the morale loss; WarDef numbers; later kinds' attack and defence; era 2 shot | `m7-build-spec.md` 1.2, D36, 6.5, 12 | Generals as traits on armies (4.11) |
| M7's battle draws a d6 a day and has no card deck | `m7-build-spec.md` 4.6 | The tree's battle cards are not built (D34) |
| M7 has no drill at barracks (v0.2.2's `upgrade`) | `m7-build-spec.md` (no drill row) | Drill yards is re-fitted to experience (4.3) |
| M8's `AiTemperDef.mix` is sized by `UnitDef` id (4 kinds) | `m8-build-spec.md` 5.1 | From M11 the mix is by branch (1.2) |
| M8's hand-off: research and idea picks by temperament branch weights; generals and refits in `AiForces` | `m8-build-spec.md` 12 | 4.17 |
| M9: Statecraft changes `goal_districts`, `price_outside_permille`, `infamy_decay`, `reach_free`; an idea halves weariness | `m9-build-spec.md` 12 | Royal bureaucracy, Absolutism, the Holy See, Resident ambassadors, Ordinanza (4.3 to 4.6) |
| M10: techs change `merchant_capacity`, `merchants_max`, `route_cost_point_milli`, `market_reach`, `toll_permille`, `remote_permille`; an idea halves `idle_free_seasons` | `m10-build-spec.md` 12 | Trade & Industry, Navigation, Mercantilism, Factors' letters |
| M4.5: an `era` mark kind and the Research page | `m4-5-build-spec.md` 12 | 4.21, 6.6 |
| North Italy, seed 1480: 71 settlements (23 villages, 36 towns, 10 walled towns, 2 cities); per country 4.7 | `data/maps/north_italy.tres` places (read by a script for this page), `m2-build-spec.md` 4.4 | The research rates of 4.7 |
| v0.2.2's research: `research_rate` (0.6 + burghers / 40 + universities, × (1 + research)), `tech_cost` (diffusion 10 % a neighbour on its markets, cap 30 %, era scale ×2.5 and ×4), `set_research` (its path, the rest the queue), `unqueue` (with dependants), `fund_research` (60 ducats → 15 points once a year), `research_season` (points on, finish while they last, keep 2 seasons' points when idle, the gate), `new_age` (era up, 3 cards), `start_techs` (national, coastal Portolan, big Drill yards) | `hexa/campaign/systems/research.py` (279 lines), `tech.py` (530 lines), `data.py` 339 to 442 | Section 3 |
| v0.2.2's screen: top bar 50 px, strip 64, era heads 66, nodes 54 high, 2 per row per era, 2 rows per branch, side card 22 % (270 to 340 px), states known, researching, queued, available, blocked, later | `hexa/campaign/screens/techlayout.py` (131), `techscreen.py` (165), `techdraw.py` (665) | `TechLayout` ports the layout as a pure view (5.6, 6.3) |
| v0.2.2's AI: branch weights (war ×2, coastal and colonial navigation ×1.5, poor trade ×1.5, personality ×1.25), gate techs ×1.5, a 0.9 to 1.1 jitter; funds when the treasury is over 8 seasons of upkeep at peace; its national card unless a general card scores 1.5 times more | `hexa/campaign/ai.py` 96 to 165 | 4.17 |
| v0.2.2's generals: a kind raised in the capital (120 gold, upkeep 1, at most 1 + provinces / 20), five traits at +20 %, stack +2, morale loss −15 % | `data.py` 323, 342, 359 to 362, 382; `military.py` 36 to 79; `combat.py` 28 to 56, 483 to 487 | 4.11 |
| M7, M8, M9 and M10 are on GitHub (milestones 19 to 22) | `gh` (read only) | Their plans' task tables stay as they are: every edit M11 makes to their code is an M11 task |
| Built by M1.5 to M10 and named "(M2)" to "(M10)" below: `Territory`, `Countries`, `Works`, `Work`, `Calendar`, `Season`, `Stats`, `StatsSystem`, `Chronicle`, `Luck`, `ViewCache`, `Snapshot`, `SaveFile`, `Replay`, `Knowledge`, `Words`, `LogLines`, `Reminders`, `SeasonSummary`, `GoodDef`, `FamilyDef`, `TerrainDef`, `UnitDef`, `WarDef`, `DiplomacyDef`, `TradeDef`, `AiDef`, `AiTemperDef`, `Economy`, `EconomySeason`, `EconomyPreview`, `ImprovePreview`, `DistrictCache`, `StateView`, `Treasury`, `Stores`, `People`, `StepCosts`, `PathSearch`, `Armies`, `Army`, `Unit`, `Military`, `Movement`, `Supply`, `SupplyCache`, `Vision`, `SightCache`, `Occupation`, `Combat`, `Battles`, `BattleEnd`, `BattleRecord`, `Sieges`, `Wars`, `WarGoals`, `WarScore`, `Peace`, `Relations`, `Brakes`, `Unrest`, `DiploCache`, `Trade`, `TradeCache`, `Merchants`, `TradePacts`, `Roads`, `CountryCard`, `HexCard`, `ArmyView`, `BattleView`, `OddsView`, `StudyMilitary`, `StudyHistory`, `MapModes`, `SeasonFlow`, `DecisionQueue`, `GameRequests`, `StudyWarm`, `StudyPages`, `StudyPage`, `DevCommands`, `PerfFixture`, `perf_core.gd`, `RandomPlayer`, `ScenarioFixture`, `TradeFixture`, `AiKnow`, `AiBrief`, `AiTurn`, `AiForces`, `AiEconomy`, `Invariants`, `soak.gd`, `war_report.gd`, `ai_tables.gd` | their specs | M11 starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M11 | Why |
|---|---|---|
| Every system of M3 to M10 reads its numbers from `game.defs` | A number a modifier may touch (the 55 keys of 4.2) is read from **`game.defs_of(tag)`**, the definitions of the country that number belongs to (4.2's "whose"); every other number stays on `game.defs` | The one door that keeps "through definitions only" true: techs make definitions, systems read definitions |
| M6 4.3: `StepCosts.of(map, defs)` one table per definitions | Movement's step costs are **never** modified: `StepCosts` keeps reading the base `game.defs` (the registry refuses its fields) | One step table for every army (M10's `game.steps`); techs act on supply, sight and kinds instead |
| M6 5.3: `Military.unit_def(game, kind)`, `cost_of(game, kind, count)`; `Supply.food_need(game, men)`; M3/M4 `Works.cost_of(game, action, family, level_to)`; M9 `WarGoals.goal_of(game, target_id, anchor)` | Each gains a last argument naming whose definitions apply: `tag := &""` (`by_id := 0` for `goal_of`); the default reads `game.defs` | Old callers keep working; a task fills the body and moves its own callers (plan section 1) |
| M6 D12, M7 4.6: the stack limit is 8 a country on a hex | `Military.stack_limit(game, tag)` is the country's `stack_limit` (8, +1 Standing army, +1 Military revolution); `stack_limit_at(game, tag, hex, with_general)` adds the general's `general_stack` (2) when an army of the country on the hex (or the one arriving) has a general | Generals and techs both raise it, through numbers |
| M7 5.3: `Combat.fight(war, input, rng)` with one `WarDef` | The input gains `wars` (the two sides' effective `WarDef`s) and `generals` (each side's trait as plain values); the base `war` keeps the global numbers (shock, dice, stances, days) | A side's techs and general act on its own values only |
| M7 D36 "generals are traits" | A general is a **trait on an army** (`Army.general`, `army/3`), not a company; the five traits are `TraitDef` data | The companies, lanes and men identities of M6 and M7 stay as they are |
| M7 `battle-record/1` | `battle-record/2` adds the two sides' general traits (the dock shows them) | The dock reads records, never the live state |
| M6 5.1: `GameDefs.validate` "4 units with ids 0..3 once each" | Once `research` is set: 12 units with ids 0 to 11, one kind a branch an era (4.10) | The later kinds are data of the same class |
| M6 D9: units raised this season muster | A unit refitted this season (`Unit.refit_turn`, `unit/3`) musters too | A refit takes the season, as v0.2.2's "no time left" |
| M6 4.5: `raise_options` "a row per `UnitDef`" | A row per branch: the kind of the country's era (four rows, as before); `later_options` (**new**) gives the next era's four with their refusal for the Raise tab's greyed rows; older and later kinds are refused (row 6b) | Troops follow eras (the approved design); M6's four-row pins hold |
| M8 5.1: `AiTemperDef.mix` by `UnitDef` id, sized `defs.units.size()` (4) | Sized 4 **by branch** (infantry, missile, cavalry, artillery): the same values; `AiForces` raises the country's era kind of each branch | Twelve kinds now; the values of the five temperaments do not move |
| M8 5.5: the door's AI files read `game.defs` | They read the seat's own numbers through `AiBrief.defs` (`AiKnow.defs(game, t)`, the seat's effective definitions) | The AI prices works and armies as its rules will |
| M3 4.2, standard 5.3 row 11: `research` between `people` and the scores | `research` after `people` and before `stats`: **17 phases** (4.15) | Rates read the season's people; stats read the season's points |
| M3 4.9, M10 4.18: thirteen report sections | A fourteenth, **`research`**, after `people` (4.20) | Style plan S5: the report's research line |
| M3 4.7: `Knowledge.knows` is neighbours, M6 adds one hex explored | Also a country with land within the viewer's **`know_range`** hexes of the viewer's land (1, the neighbour rule, by default; Cartography 4) (4.13) | Cartography's effect is a number on a definition |
| M4.5 `StudyHistory.MARK_KINDS` (M7 puts `war` first) | `era` second, after `war`; `tech` before `tax` (4.21) | The M4.5 hand-off |
| `tech-tree.md`: "Era II still opens tile levels 3-4 and era III opens level 5" | District levels are **not** gated by era (D8) | Every stage was open in M3 to M10 and their numbers, the AI's works and the playtests count on it |
| `tech-tree.md`: Navigation techs on sea routes, ships, colonies | Navigation is re-fitted to the coast, the merchants' ways and the maps (D3); its ship effects wait for ships (after M12) | The first release is a land game (owner's answer, 2026-11-15) |
| `tech-tree-build-spec.md` "Effect keys" (float bonuses, unlock flags) | Integer modifier rows on definition fields: `add` or `scale` (permille), no unlock flag (D5, D8) | Integers everywhere (standard 5.4); unlocks are eras and numbers |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days). Data changes are a `.tres` edit
plus the test that pins the value. Every number below lives in `data/defs/research.tres` (`ResearchDef`), a `TechDef`, `IdeaDef`,
`EraDef`, `TraitDef`, `UnitDef`, `WarDef` or the AI's files; `godot/tools/research_tables.gd` prints them.

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | What M11 builds | Research points, the tree, the queue, funding, diffusion, eras and their gates, idea cards, national techs, the modifier engine and per-country definitions, eight later kinds and refits, generals, the AI for all of them, their screens | The standard's M11 row; M4 to M10's hand-offs | none |
| D2 | The tree | The approved 4 branches × 3 eras, **37 techs** with their names, branches, eras and prerequisites; **one tech and four ideas renamed** where their subject is not in the land game (Colonial charters → Town charters; the ideas Privateer letters → River pilots, Colonial agents → Fishing fleets, Reformed church → Confraternities, Town charters → Civic statutes) | "Keep the approved tree" (standard 9); a name must say what it does | S a name |
| D3 | Navigation in a land game | Kept as the fourth branch, re-fitted to **the coast, the merchants' ways and the maps**: port dues, fish, sight, transport, knowing far countries, silk and dyes; ships, sea routes and colonies after M12 add their effects as rows | Four branches is the approved shape; the coast, rivers and maps exist on the district map | M (rows) |
| D4 | How a tech changes a rule | Its effects are **`ModDef` rows** (key, op, value); `ModApply.apply(game.defs, effects)` builds the country's **effective `GameDefs`**; systems read `game.defs_of(tag)`; no system reads a tech | "Techs change rules through definitions only" (done-when 1); previews, AI and rules agree by construction | L |
| D5 | Operations | `add` (an amount) and `scale` (a permille delta); a field's value is `(base + Σ add) × (1000 + Σ scale) / 1000`, floored; an array field takes the row at every entry or at `at`; a dictionary field (`fight_attack`, `cost_goods`) at its named entry; then clamped to the key's bounds | Sums are order-free and integer; v0.2.2's effects were summed the same way | S |
| D6 | Which numbers | Only the **55 keys** of the registry `ModKeys` (4.2); a key exists only with its reader and its probe test; movement step costs, prices, the free traders' routes and the battle's global numbers are never keys | One step table, one price rule; every key proven | S a key |
| D7 | Whose definitions | Each key names the country whose numbers apply (4.2): a district's owner, an army's or a company's country, a fortress's controller, a market town's controller, a merchant's, a declarer, a winner | A tech helps its owner, never a neighbour | S |
| D8 | Unlocks | **None as flags.** Eras bring their kinds of company (the approved "troops stay tied to eras"); techs change numbers; district stages are **not** gated by era | M3 to M10 opened every stage and tuned their numbers and the AI's works on it; a gate would move every pin | L (a gate) |
| D9 | Research points | A country's rate in milli-points a season: `base_milli` **1,500** + its towns' people × `town_milli` **15** / 1,000 + per settlement `by_level` (town **100**, walled town **250**, city **500**), times `(1000 + bonus_permille) / 1000`; over its owned settlements it controls (4.7) | v0.2.2's base and burghers re-fitted: districts have few towns, so a larger base keeps Lucca in the race (1.5 to 7.5 a season on north Italy, the design's "2 to 6" for a mid-sized country) | Data (S) |
| D10 | Taxes and the countryside | **Not sources**: learning lives in towns; ducats enter only by funding | One door from money to points; the tax level already moves growth, contentment and weariness | S |
| D11 | Funding | `fund_research`: **80 ducats → 6 points** (× `1000 + fund_bonus_permille`), **once every 4 seasons**, to the tech being researched | v0.2.2's ducat funding at district prices: a real choice for Genoa (a quarter of a season's net), small for Milan | Data (S) |
| D12 | Units | Points are stored in **milli-points**; costs in points; a tech is learned when `progress ≥ cost × 1000` | Whole numbers (standard 5.4); "12 of 80" reads in points | S |
| D13 | Progress | Belongs to the country, not to a tech: changing the research keeps it | v0.2.2; no penalty to read, nothing to lose by browsing | S |
| D14 | Nothing researched | Points are kept up to **`idle_keep_seasons` 4** seasons of the rate; the reminder says so | v0.2.2's "points don't pile up" (2 seasons) widened: a big country waiting for a gate year keeps a year's points | Data (S) |
| D15 | Overflow | In the phase, points beyond a cost carry to the next queued tech, which may be learned the same season | v0.2.2 | S |
| D16 | Costs | Per tech: era I **70 to 90**, era II **160 to 200**, era III **360 to 400** points (4.3) | The design's relative prices × 2 for district rates: a mid country learns a tech every 3 to 10 years and about 70 % of the tree by 1650 (4.8) | Data (S) |
| D17 | Diffusion | A tech costs **100 permille less** for each **trade partner** that knows it, at most **300** (+200 Habsburg marriages): partners are the living countries controlling land in the catchment of a market where you control land, or of a market one route from it (M10) | v0.2.2's "a country you share a market with", on M10's markets and routes | Data (S) |
| D18 | The queue | `set_research {tech}`: its unknown path (prerequisites first) becomes the research and the queue (replacing it); `queue_research {tech}`: its path is appended; `unqueue_research {tech}`: removes it and the queued techs that need it, the current research too | v0.2.2's click and right click, plus Shift+click to add | S |
| D19 | The era gate | Era II in the research phase of a season of **1520 or later** with **4 tree techs of era I** known; era III **1575** and 4 of era II; national and `also_knows` techs do not count | The approved gate; the year holds the leaders, the count the laggards | Data (S) |
| D20 | What an era brings | Its four kinds of company for raising (older kinds refused); old companies refit; an idea offer; its techs researchable | The approved design | S |
| D21 | Later kinds | Eight `UnitDef`s, ids 4 to 11: **landsknechts, arquebusiers, lancers, culverins** (era 2), **pike regiments, musketeers, cuirassiers, field guns** (era 3) (4.10); M7's "era 2 shot" is the missile branch's fire | v0.2.2's troops by era, split into M6's four branches | Data (S) a kind |
| D22 | Refit | `refit {army}`: every company of an older era becomes its branch's kind of the country's era, on a settlement of the country of level **3** or more, for **half** the new kind's ducats and goods each (rounded up); the refitted companies muster that season | v0.2.2's half-cost refit in a town | Data (S) |
| D23 | Idea offers | At each era step: **3 cards**: the nation's own (when not taken), then general cards not taken drawn with weight **3** for the branch with the most tree techs known (all tied tops), else 1, from **`luck.world`** | The approved draw; the world's stream is the one for rules | Data (S) |
| D24 | The deck | **16 general** cards (5 military, 4 trade, 3 navigation, 4 statecraft) and **13 national** ones (4.6) | The design's "12 to 16" plus one card for each 1480 country | Data (S) a card |
| D25 | An offer left open | Stays until picked (the reminder `idea_pending`); when the next era comes first, its first card is adopted (`why: lapsed`) and the new offer drawn | Two ideas a game, never three cards in limbo | S |
| D26 | National techs | One per country, era I, known at the start, drawn in its branch's era I cell with a gold tag (4.5); a country with none (the made-up Europe's) gets **Local levies**; Venice's also knows Banking | The approved design, a tech for each of the 13 | Data (S) |
| D27 | Other start techs | **None** (v0.2.2's coastal Portolan and big-empire Drill yards are dropped) | Every 1480 country starts on equal terms but its national; the gate's year does the pacing | S |
| D28 | The first research | Every country starts researching its **cheapest available tech** (ties: lower id); the player may change it with no loss (D13) | No point is lost while the player looks; the AI re-picks at once if it wants | S |
| D29 | Generals | **They exist**, as leaders of armies: `appoint_general {army, trait}` puts one on an army; a trait is chosen from five | M7 D36; the player chooses the captain for the war at hand | L |
| D30 | What a general does | Its side holds **`general_stack` 2** more companies on its hex; its trait adds **200 permille** to the attack and defence values where it applies (Field marshal open ground, Ranger rough ground, Siege master assaults (+1 siege point a season), Defender when defending, Cavalier cavalry); its side's morale loss is cut by **150 permille** | v0.2.2's general, each term one of M7's | Data (S) |
| D31 | How many, at what cost | `1 + walled towns and cities you control / 2`, at most **4**; **100 ducats** to appoint, **4 a season** in the army's upkeep | v0.2.2's 120 gold and 1 + provinces / 20 at district scale | Data (S) |
| D32 | Generals and armies | Appointed on an army standing on land its country owns and controls; a merge keeps the remaining army's general (two generals refused); a split leaves it with the old army; lost with its army (all companies lost or surrendered); dismissed with no refund | One general an army; no general walks alone | S |
| D33 | Names, rank, death | **None in M11**: a general is known by its trait ("a Ranger"); no experience, no death in battle; names and lives come with the characters design after M12 | Traits are the rules; characters are a design of their own | M |
| D34 | Battle cards | **Not built**: M7's battle has no deck | No rule M7 lacks | L |
| D35 | Drill | **Not built**; Drill yards gives experience faster instead | M7 has no drill | S |
| D36 | What you may know of others' research | A **known** country's era, known techs, ideas and national tech are public; its research in progress, queue, progress, rate and funding never show; an unknown country shows nothing (4.13) | "Their research in progress ... never show" (game feedback C.5); the side card's "who has it" | S |
| D37 | Cartography | A new `GameDefs.know_range` (1): `Knowledge.knows` adds the countries with land within that many hexes of yours; Cartography +3 | The design's "see every coast you trade with" as a number | S |
| D38 | The research phase | After `people`, before `stats`: 17 phases (4.15) | Rates read the season's people; the report reads the points | S (the pin) |
| D39 | Luck | The idea draw (`luck.world`, in the research phase) and the AI's jitter (`luck.ai`); nothing else | Standard 5.4 | none |
| D40 | Previews | Count the techs known when made; a tech learned during a preview's window shows from the next preview | The research phase comes after income; the preview stays a function of the state | S |
| D41 | The M4 to M10 pins | Run on **`ResearchFixture.off`** (no rate, no funding, no national tech, no general places): no country ever has an effect; M11's own tests ask for research | M10's `TradeFixture.still` pattern | S |
| D42 | Saves | `SaveFile.FORMAT` **9**, `OLDEST_FORMAT` 9; `country/7`, `army/3`, `unit/3`, `battle-record/2`; no new body key | An M10 save's digest has no research | S |
| D43 | Events | `tech_learned`, `era_reached`, `ideas_offered`, `idea_adopted`, `research_set`, `research_funded`, `research_idle`, `general_appointed`, `general_dismissed`, `general_lost`, `army_refitted` (4.16) | Game feedback D.2 ("research and era kinds with their milestones") | S a kind |
| D44 | The report | A section `research` after `people`; a glance chip for a tech learned or a new age; treasury lines for funding, generals and refits (4.20) | Style plan S5 | S |
| D45 | Reminders | `idea_pending` (2), `research_idle` (1), `refit_due` (0) (4.20) | What is left to do | S |
| D46 | Keys | **T** (exists) opens and closes the tech screen; inside it the arrows, Enter, Shift+Enter, Delete, Home, Tab and Esc (6.1) | The UI spec's T; the keyboard path | Bindings (S) |
| D47 | The tech screen | An `OPAQUE` screen in the walnut frame: top band, strip, era heads, the grid with links, side card, legend (6.3); `TechLayout` is the pure port of `techlayout.py`; Godot containers lay it out | The approved mockup in the Studiolo kit | M |
| D48 | The idea pick | A `MODAL` screen shown in **`DECISIONS`** after the leagues; Esc decides later | One door for decisions (M7, M9) | S |
| D49 | The Research chip | `ResourceChip` "Research": progress of the current tech in points (`set_fraction`), its change the rate; "—" when idle; click: the tech screen | The UI plan's chip | S |
| D50 | The Research page | Between People and Rankings (6.6) | The mockup's nav order (game feedback C.1) | S |
| D51 | The AI's research | When idle: the available tech with the best `weight × 1000 / cost`; weights by temperament and situation (4.17); funds at peace with the treasury over `fund_ducats + 2 R`; its card unless a general one scores 1.5 times more | v0.2.2's AI in data | Data (S) |
| D52 | The AI's generals and refits | Appoints for its largest army of 4 companies or more when a place is free and the money is over its reserve, the trait by the army and its temperament; refits one army a season where it stands in a town | M8's hand-off | Data (S) |
| D53 | The scripted player | `ResearchScript.gate_first` (tests and the soak): the cheapest available tech of its era until the gate's 4 are known, then the cheapest; funds yearly with 300 ducats or more; takes the first card | A pace measure that does not move when the AI is tuned | S |
| D54 | The soak | A `research` suite (10 games of 440 seasons), the invariants `research` and `generals`, the ranges of 4.19 | "An era passes in play" needs 161 seasons at least | S |
| D55 | The sandbox and watched games | The sandbox has no research (T: "no countries on this map"); a watched game's T toasts "Choose a country to see its research."; the Research page shows the known countries of no one (everyone, as M4.5) | No player country | none |
| D56 | The console | `tech`, `points`, `era`, `research`, `queue`, `unqueue`, `fund`, `idea`, `general`, `dismiss`, `refit`, with `as TAG` (6.10) | The playtest reaches an age without 160 seasons | S |
| D57 | Speed | `ModsCache` (a door field, never saved) keeps each country's effective definitions until its techs or ideas change; a key names the caches its change must forget (4.2) | Effective definitions are read in every phase | S |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| 37 grid techs in 4 branches × 3 eras with prerequisites, costs 35 to 200 scaled ×2.5 / ×2.5 / ×4 | `tech.py` 72 to 250, 444 | The tree, its names, branches, eras, prerequisites and relative prices | Costs written per tech at district rates (D16); effects re-fitted to the systems M4 to M10 built (4.3); Colonial charters renamed (D2) |
| Effects as a summed dictionary of float bonuses and unlock flags read by `world.bonus` and `world.has` | `tech.py` 497 to 524; `world.py` | Summed effects; one place that applies them | Integer modifier rows on definition fields; effective definitions per country; no flags (D4, D5, D8) |
| `research_points`: 0.6 + burghers / 40 + universities (+ coffee), × (1 + research) | `tech.py` 527 to 530 | A base, the towns, a multiplier | Base 1.5, town people at 15 a thousand, settlement levels; Universities raise the level parts (D9) |
| `fund_research` 60 ducats → 15 points, once a year | `research.py` 60 to 80 | Once a year, to the current tech | 80 → 6 (D11) |
| `cost`: diffusion 10 % a neighbour on its markets, cap 30 %, Sagres −25 % navigation | `tech.py` 447 to 455 | 10 % a partner, cap 30 % | Partners by M10's catchments and routes (D17); no navigation discount on the map |
| `set_research`, `unqueue`, `advance`, `finish_research` | `research.py` 125 to 194 | Path then queue; dependants removed; overflow carried | `queue_research` added; the current research may be removed (D18) |
| `research_season`: points on, finish, idle keep 2 seasons, gate | `research.py` 149 to 159 | All of it | Idle keep 4 seasons (D14); integers |
| `era_ready`: 1520 / 1575 and 4 techs of the era | `tech.py` 463 to 472 | All of it | none |
| `new_age`: troops message, 3 cards drawn weighted 3 : 1 to the top branch | `research.py` 197 to 206; `tech.py` 475 to 494 | The draw | From `luck.world`; an open offer lapses to its first card at the next era (D25) |
| National techs (12) and regional defaults by the capital's longitude and latitude | `tech.py` 254 to 321; `research.py` 215 to 226 | One national tech known at the start | One for each of the 13 countries of 1480 in data; a default for the rest (D26) |
| Start techs: coastal Portolan, colonial Astrolabe, big Drill yards; first research the cheapest | `research.py` 229 to 245 | The cheapest first research | No start techs but the national (D27) |
| `TROOPS` by branch and era; `refit_check` / `refit` at half cost in a town | `data.py` 295 to 319; `military.py` 130 to 161 | Kinds by era, half-cost refits | Twelve kinds in M6's four branches (D21); refit an army at once (D22) |
| `GENERAL` a unit kind; traits; `GENERAL_STACK` 2; `GENERAL_BONUS` 0.2; `GENERAL_MORALE` 0.15 | `data.py`; `military.py`; `combat.py` | The traits, +20 %, stack +2, morale −15 % | A trait on an army (D29), 100 ducats and 4 a season (D31) |
| The AI's `_research`, `_fund`, `_pick_idea` | `ai.py` 96 to 165 | Weights by branch and situation; the gate bonus; the national card rule | In data (`AiTemperDef.branch_weights`, `AiDef`); jitter from `luck.ai` (D51) |
| The tech screen and the new-age modal | `screens/tech*.py` | The layout, the states, the strip, the queue, the side card, the modal | Studiolo kit; a pure layout view; the modal as a decision (D47, D48) |
| Battle cards from techs | `tech.py` `cards` | | Not built (D34) |

---

## 4. Design content

All amounts are whole numbers. Research points are stored in thousandths ("milli-points"); costs are points; rates are permille.
Every division is floored but where it says "rounded up".

### 4.1 The model in one picture

```
 during the season (actions, any country; the AI only in ai_orders)
   set_research {tech}            its path becomes the research and the queue                    -> research_set
   queue_research {tech}          its path joins the end of the queue                             -> research_set
   unqueue_research {tech}        it and the queued techs that need it leave                       -> research_set
   fund_research {}               Treasury.move research; progress += 6 points (once a year)       -> research_funded
   pick_idea {idea}               one of the three cards; the others are dropped                   -> idea_adopted
   appoint_general {army, trait}  Treasury.move general; Armies.set_general                        -> general_appointed
   dismiss_general {army}         Armies.set_general &""                                            -> general_dismissed
   refit {army}                   Treasury.move refit, Stores.move refit; Armies.refit_units         -> army_refitted
 ... (M3 to M10's phases, each reading its numbers from game.defs_of(the country it belongs to))
 research   every living country (id order): points = its rate; learn while progress covers the cost (overflow on)
            -> tech_learned; nothing left -> research_idle; the gate met -> era_reached, an offer drawn  -> ideas_offered
 stats      the research, techs and era series
 any time   a tech or an idea known -> ModsCache forgets the country; its keys' caches forget (4.2)
```

### 4.2 The modifier engine and the registry

**A modifier** is a `ModDef` row `{key, op, value, at}`. `ModApply.apply(base, effects)` returns `base` itself when `effects` is empty,
else a shallow copy of `base` (`GameDefs.duplicate(false)`) in which each touched part is replaced by its own copy (`war`, `trade`,
`diplomacy`, `research`; `families` and `units` as new arrays sharing the untouched entries, the touched entries copied), then for
each touched field, in key order: `value = (base value + Σ add) × (1000 + Σ scale) / 1000`, an integer division rounding toward −∞, then clamped to the
key's bounds. An array field takes a row at every entry, or at the entry `at`; the entries of 0 stay 0 under `scale`. A dictionary
field takes the row at its named entry (the key's last part). The effective definitions are never saved.

**The effects of a country** (`ModApply.effects_of(defs, techs, ideas)`): its known techs in the order learned (the national first),
then its ideas in the order adopted, each tech's and idea's `effects` in file order.

**`Game.defs_of(tag)`** returns `game.mods.defs_for(game, tag)`: `game.defs` for `&""`, an unknown or dead country, or one with no
effects; else its effective definitions, built on first use and kept until `ModsCache.forget(tag)`. `Game.emit` of `tech_learned` or
`idea_adopted` calls `mods.forget(tag)`, then, for each key the tech or idea touches, the key's **forgets** below
(`districts.forget_land(game, tag)`, `supplies.forget(id)`, `sight.forget_land(id)`, `trade_cache.forget_all()`).

**The registry** (`core/defs/mod_keys.gd`, `ModKeys.KEYS`): the only keys a `ModDef` may name. `<family>` is a `FamilyDef.key`,
`<branch>` a `UnitDef.BRANCHES` entry, `<good>` a `GoodDef.key`. "Whose" is the country whose `defs_of` the reader calls. The probe
is what `test_mod_hooks.gd` measures after granting one test tech with the row `{key, op, value}` of its column.

| # | Key | Ops | Bounds | Read by | Whose | Forgets | Probe (row given → expected) |
|---|---|---|---|---|---|---|---|
| 1 | `defs.supply_reach` | add | 1..40 | `SupplyCache.field_of` | the army's country | `supplies` | add 2: a depot's field reaches a hex at 10 supply points (8 before) |
| 2 | `defs.army_food_milli` | add | 1..5000 | `Supply.food_need` | the army's country | | add −50: 20,000 men eat 3 loads a season (4) |
| 3 | `defs.stack_limit` | add | 1..20 | `Military.stack_limit` | the country | | add 1: 9 |
| 4 | `defs.land_sight` | add | 1..3 | `SightCache.land_of` | the country | `sight` | add 1: a hex 2 steps from its land is seen |
| 5 | `defs.know_range` | add | 1..8 | `Knowledge.knows` | the viewer | | add 3: a country whose nearest land is 4 hexes away is known |
| 6 | `defs.goods_share_permille` | add (every or `at`) | 0..1000 | `EconomySeason.money_lines` | the country | | add 20: `tax_goods` of 50,000 milli sold at Normal 35 → 36 |
| 7 | `defs.town_tax_milli` | scale | 0..10000 | `EconomySeason.money_lines` | the country | | scale 200: the towns' part of `tax_people` × 1.2 |
| 8 | `defs.tax_permille` | add `at` | 0..10000 | `EconomySeason.money_lines` | the country | | add 100 at 2: High's `tax_people` × 1500 / 1400 |
| 9 | `defs.growth_bp` | add `at`, scale | 0..1000 | `People.change_at` | the hex's owner | | add 25 at 2: a 10,000-people hex at High grows 75 (50 before) |
| 10 | `defs.levy_permille` | add | 0..1000 | `People.available` | the hex's owner | | add 25: a town of 10,000 gives 1,250 men (1,000) |
| 11 | `war.xp_win` | add | 0..10 | `BattleEnd.apply` | the company's country | | add 1: a winner's company gains 3 |
| 12 | `war.xp_lose` | add | 0..10 | `BattleEnd.apply` | the company's country | | add 1: a loser's company gains 2 |
| 13 | `war.pikes_vs_horse_permille` | add | 1000..4000 | `Combat.defence_value` | the struck company's country | | add 250: pikemen struck by knights on farmland def 7,500 (6,250) |
| 14 | `war.castle_defence_permille` | add | 0..1000 | `Combat` (assault) | the fortress's side | | add 100: a level-2 fortress's defenders × 1,700 / 1,500 |
| 15 | `war.garrison_defence` | add | 1..20 | `Combat` (garrison), `Occupation` | the fortress's controller | | add 2: a level-1 garrison's defence 7 (5) |
| 16 | `war.siege_per_level` | add | 0..10 | `Occupation.siege_need` | the fortress's controller | | add 1: a level-2 fortress needs 12 (10) |
| 17 | `war.general_stack` | add | 0..6 | `Military.stack_limit_at` | the country | | add 1: 11 with a general (10) |
| 18 | `war.general_cost` | scale | 1..1000 | `Generals.appoint_general` | the country | | scale −500: 50 ducats |
| 19 | `war.fight_attack.<branch>` | scale | 1..4000 | `Combat.attack_value` | the striker's country | | scale 100 cavalry: knights' open attack 9,240 (8,400) |
| 20 | `war.fight_defence.<branch>` | scale | 1..4000 | `Combat.defence_value` | the struck company's country | | scale 100 infantry: pikemen's open defence 5,500 (5,000) |
| 21 | `branch.<branch>.attack` | add | 1..20 | `Military.unit_def` (→ `Battles.input_of`) | the company's country | | add 1 artillery: bombards 7 |
| 22 | `branch.<branch>.defence` | add | 1..20 | `Military.unit_def` | the company's country | | add 1 cavalry: knights 4 |
| 23 | `branch.<branch>.fire_permille` | add | 0..200 | `Military.unit_def` | the company's country | | add 15 missile: crossbowmen 40 |
| 24 | `branch.<branch>.siege_points` | add | 0..6 | `Sieges.terms` | the besieger | | add 1 artillery: a battery of bombards gives 2 |
| 25 | `branch.<branch>.cost` | scale | 1..1000 | `Military.cost_of` | the raising country | | scale −250 cavalry: knights 33 ducats |
| 26 | `branch.<branch>.cost_goods.<good>` | add | 0..20 | `Military.cost_of` | the raising country | | add 1 artillery copper: bombards 4 copper |
| 27 | `units.sight` | add | 1..3 | `Vision` (army sight) | the army's country | `sight` | add 1: an army of pikemen sees 2 hexes |
| 28 | `family.<family>.base` | scale | 0..400 per entry | `Economy.district_base` | the hex's owner | `districts` | scale 100 wheat: a wheat district of stage 2 makes 22 (20) at 100 % |
| 29 | `family.settlements.port_dues` | scale | 0..400 | `Economy.season_output` | the hex's owner | `districts` | scale 200: Genoa's dues 30 → 36 at 100 % |
| 30 | `family.settlements.port_fish` | scale | 0..100 | `Economy.season_output` | the hex's owner | `districts` | scale 250: Genoa's fish 6 → 7 |
| 31 | `family.settlements.room` | scale | 0..1000000 | `People.room_at` | the hex's owner | `districts` | scale 100: a walled town holds 49,500 (45,000) |
| 32 | `family.<family>.cost` | scale | 0..100000 | `Works.cost_of` | the actor | | scale −250 castles: a castle 150 (200) |
| 33 | `families.cost` | scale | 0..100000 | `Works.cost_of` | the actor | | scale −100: a vineyard first stage 36 (40) |
| 34 | `research.bonus_permille` | add | 0..2000 | `Research.rate` | the country | | add 150: 2,450 → 2,817 |
| 35 | `research.town_milli` | add | 0..100 | `Research.rate` | the country | | add 6: 40,000 town people give 840 (600) |
| 36 | `research.by_level` | add `at` | 0..10000 | `Research.rate` | the country | | add 1,000 at 5: a city gives 1,500 |
| 37 | `research.fund_bonus_permille` | add | 0..2000 | `Research.fund_research` | the country | | add 250: a funding gives 7,500 |
| 38 | `research.diffusion_cap_permille` | add | 0..1000 | `Research.cost` | the country | | add 200: four partners cut 400 permille (300) |
| 39 | `trade.merchants_base` | add | 0..12 | `Merchants.count` | the country | | add 1: Genoa 3 (2) |
| 40 | `trade.merchants_max` | add | 1..12 | `Merchants.count` | the country | | add 1: a country with 6 market towns has 7 (6) |
| 41 | `trade.merchant_capacity` | add | 1..60 | `Merchants.estimate`, `carry` | the order's country | | add 4: up to 16 loads |
| 42 | `trade.route_cost_point_milli` | add | 0..100 | `Merchants.estimate`, `carry` | the order's country | | add −3: the duo route costs its merchant 150 + 6 × 12 = 222 a load (240) |
| 43 | `trade.market_reach` | add | 1..60 | `TradeCache.catchment` | the market town's controller | `trade_cache` | add 2: a market reaches hexes at 14 points |
| 44 | `trade.remote_permille` | add | 0..1000 | `Trade.country_step` | the offering country | | add 100: remote goods sell at 800 permille |
| 45 | `trade.toll_permille` | add, scale | 0..1000 | `Trade.toll_rate` | the market town's controller | | add 20: Normal 120 |
| 46 | `trade.idle_flag_seasons` | add | 1..12 | `Merchants.book` | the order's country | | add −1: flagged after 1 idle season |
| 47 | `trade.idle_free_seasons` | add | 1..12 | `Merchants.book` | the order's country | | add −2: home after 2 |
| 48 | `diplomacy.reach_free` | add | 0..40 | `Brakes.tax_share`, `Unrest` (far term) | the hex's owner | | add 2: a district 11 steps from the capital is over by 0 steps (2) |
| 49 | `diplomacy.goal_districts` | add | 1..60 | `WarGoals.goal_of` | the declarer | | add 2: a goal of 14 districts |
| 50 | `diplomacy.price_outside_permille` | add | 1000..10000 | `Peace.price_of` | the winner | | add −250: a district outside the goal at 1,750 permille of its worth |
| 51 | `diplomacy.infamy_decay` | add | 0..50 | `Brakes.season` | the country | | add 1: 4 tenths a season |
| 52 | `diplomacy.weariness_field` | scale | 0..100 | `Brakes.season` | the country | | scale −500: 2 a season in the field |
| 53 | `diplomacy.weariness_idle` | scale | 0..100 | `Brakes.season` | the country | | scale −500: 1 |
| 54 | `diplomacy.weariness_battle_lost` | scale | 0..100 | `Brakes.season` | the country | | scale −500: 2 |
| 55 | `diplomacy.weariness_district_lost` | scale | 0..100 | `Brakes.season` | the country | | scale −500: 0 |

Bounds hold the rule's own `validate()` limits; `test_research_data.gd` applies every tech, idea and national tech at once and finds
no field clamped. Fields not in the table, among them every field `StepCosts` reads (`TerrainDef.move`, `relief_move_add`, road
caps, crossing costs, `winter_snow_percent`), the price rule's (`price_*`, appetites), the free traders' (`route_capacity_base`,
`route_cost_base_milli`, `spare_permille`) and the battle's global ones (shock, dice, stances, days), stay the base's.

### 4.3 The tree

Ids are the order of `GameDefs.techs`, append-only; costs in points. "Needs" in italics cross a branch (dashed on the screen). Lines
are the effect text the screen shows (`TechDef.lines`); effects the rows of 4.2.

**Military**

| Id | Key | Name | Era | Cost | Needs | Effects | Lines |
|---|---|---|---|---|---|---|---|
| 0 | `drill_yards` | Drill yards | I | 80 | | `war.xp_win` add 1; `war.xp_lose` add 1 | "Companies gain experience faster: +1 from every battle" |
| 1 | `supply_trains` | Supply trains | I | 80 | | `defs.supply_reach` add 2 | "Supply reaches 2 points further" |
| 2 | `siege_craft` | Siege craft | I | 80 | | `branch.artillery.siege_points` add 1 | "Artillery +1 siege point a season" |
| 3 | `tercio` | Tercio | II | 180 | Drill yards | `war.pikes_vs_horse_permille` add 250 | "Infantry struck by cavalry holds better: ×1.25 → ×1.5" |
| 4 | `standing_army` | Standing army | II | 200 | | `defs.stack_limit` add 1 | "One more company on a hex (8 → 9)" |
| 5 | `bronze_guns` | Bronze guns | II | 200 | Siege craft, *Corned powder* | `branch.artillery.attack` add 1; `branch.artillery.cost_goods.copper` add 1 | "Artillery +1 attack; a battery needs 1 more copper" |
| 6 | `trace_italienne` | Trace italienne | II | 200 | | `war.castle_defence_permille` add 100 | "Fortresses defend better: +35 % a level, not +25 %" |
| 7 | `volley_fire` | Volley fire | III | 380 | Tercio | `branch.missile.attack` add 1; `branch.missile.fire_permille` add 15 | "Missile companies +1 attack and fire 15 more a day" |
| 8 | `star_forts` | Star forts | III | 400 | Trace italienne | `war.garrison_defence` add 2; `war.siege_per_level` add 1 | "Garrisons +2 defence; a siege needs 1 more point a fortress level" |
| 9 | `magazines` | Magazines | III | 380 | Supply trains | `defs.supply_reach` add 2; `defs.army_food_milli` add −50 | "Supply reaches 2 more; armies eat a quarter less" |
| 10 | `military_revolution` | Military revolution | III | 400 | Standing army | `defs.stack_limit` add 1; `war.general_stack` add 1 | "One more company on a hex; a general adds 1 more" |

**Trade & Industry**

| Id | Key | Name | Era | Cost | Needs | Effects | Lines |
|---|---|---|---|---|---|---|---|
| 11 | `guilds` | Guilds | I | 80 | | `families.cost` scale −100 | "Works cost a tenth fewer ducats" |
| 12 | `double_entry` | Double-entry books | I | 80 | | `trade.merchants_base` add 1 | "+1 merchant" |
| 13 | `crop_rotation` | Crop rotation | I | 70 | | `family.wheat.base` scale 100 | "Wheat districts +10 %" |
| 14 | `ropewalk` | Ropewalk | II | 170 | Guilds | `family.hemp.base` scale 250 | "Hemp districts +25 %" |
| 15 | `banking` | Banking | II | 200 | Double-entry books | `defs.town_tax_milli` scale 200 | "Taxes on towns +20 %" |
| 16 | `corned_powder` | Corned powder | II | 170 | Guilds | `branch.artillery.fire_permille` add 15 | "Artillery fires 15 more a day" |
| 17 | `glass_leather` | Glass & leather | II | 180 | | `family.grazing.base` scale 200 | "Grazing +20 %: hides for the tanners" |
| 18 | `joint_stock` | Joint-stock company | III | 400 | Banking, *Town charters* | `trade.merchants_base` add 2 | "+2 merchants" |
| 19 | `bourse` | Bourse | III | 380 | Banking | `trade.market_reach` add 2; `trade.remote_permille` add 100 | "Your market towns reach 2 points further; remote land sells at 80 %" |
| 20 | `coffee_houses` | Coffee houses | III | 360 | Glass & leather, *Universities* | `research.town_milli` add 6 | "Towns' research +40 %" |

**Navigation**

| Id | Key | Name | Era | Cost | Needs | Effects | Lines |
|---|---|---|---|---|---|---|---|
| 21 | `portolan` | Portolan charts | I | 70 | | `family.settlements.port_dues` scale 200 | "Port dues +20 %" |
| 22 | `carrack` | Carrack | I | 80 | | `family.harbour.base` scale 250; `family.settlements.port_fish` scale 250 | "Harbours and ports catch 25 % more fish" |
| 23 | `astrolabe` | Astrolabe | I | 80 | | `defs.land_sight` add 1 | "Your land sees 1 hex further" |
| 24 | `ocean_pilots` | Ocean pilots | II | 170 | Portolan charts, Astrolabe | `trade.route_cost_point_milli` add −3 | "Your merchants pay a fifth less transport" |
| 25 | `plantations` | Plantations | II | 180 | | `family.silk.base`, `family.dyes.base`, `family.olives.base` scale 200 each | "Silk, dyes and olives +20 %" |
| 26 | `cartography` | Cartography | II | 160 | | `defs.know_range` add 3 | "You know every country within 4 hexes of your land" |
| 27 | `galleon` | Galleon | III | 380 | Carrack, *Ropewalk* | `family.settlements.port_dues` scale 250; `trade.merchants_max` add 1 | "Port dues +25 % more; up to 7 merchants" |
| 28 | `mercator` | Mercator charts | III | 360 | Cartography | `units.sight` add 1 | "Armies see 1 hex further" |
| 29 | `overseas_factories` | Overseas factories | III | 380 | Ocean pilots | `trade.merchant_capacity` add 4 | "Merchants carry 4 more loads (12 → 16)" |

**Statecraft**

| Id | Key | Name | Era | Cost | Needs | Effects | Lines |
|---|---|---|---|---|---|---|---|
| 30 | `tax_rolls` | Tax rolls | I | 70 | | `defs.goods_share_permille` add 20 | "Taxes on goods +2 points at every level" |
| 31 | `printing_press` | Printing press | I | 90 | | `research.bonus_permille` add 150 | "Research +15 %" |
| 32 | `universities` | Universities | II | 200 | Printing press | `research.by_level` add 1,000 at 5 and 500 at 4 | "Cities +1 research a season, walled towns +0.5" |
| 33 | `town_charters` | Town charters (v0.2.2: Colonial charters) | II | 170 | | `family.settlements.room` scale 100 | "Towns hold a tenth more people" |
| 34 | `royal_bureaucracy` | Royal bureaucracy | II | 180 | Tax rolls | `defs.growth_bp` add 25 at 2; `diplomacy.reach_free` add 2 | "High taxes slow growth half as much; your reach +2 steps" |
| 35 | `absolutism` | Absolutism | III | 380 | Royal bureaucracy | `defs.levy_permille` add 25; `defs.tax_permille` add 100 at 2; `diplomacy.goal_districts` add 2 | "Levies +25 %; High taxes +10 points; war goals +2 districts" |
| 36 | `mercantilism` | Mercantilism | III | 360 | | `trade.toll_permille` add 20 | "Tolls +2 points at every level" |

Per era: I 11 techs (70 to 90), II 14 (160 to 200), III 12 (360 to 400); the dearest of an era (90, 200) is under the cheapest of
the next (160, 360). Cross-branch needs: Bronze guns ← Corned powder, Joint-stock company ← Town charters, Coffee houses ←
Universities, Galleon ← Ropewalk. Totals 880, 2,590 and 4,560 points.

**Flavour** (`TechDef.flavour`, the side card's italic line) is v0.2.2's sentence for every kept tech (`tech.py`), and for Town
charters "Charters give the towns their own courts, markets and walls to fill."

**Icons** (`TechDef.icon`, bake slice 9): `tech_drill`, `tech_wagon`, `tech_cannon` (Siege craft, Bronze guns), `tech_pike`,
`tech_flag` (Standing army, Town charters), `tech_castle`, `tech_musket`, `tech_star`, `tech_barrel`, `tech_crown` (Military
revolution, Royal bureaucracy, Absolutism), `tech_guild`, `tech_scale` (Double-entry books, Mercantilism), `tech_wheat`, `tech_rope`,
`tech_bank`, `tech_powder`, `tech_glass`, `tech_scroll` (Joint-stock company, Tax rolls), `tech_coin`, `tech_cup`, `tech_chart`,
`tech_ship`, `tech_compass` (Astrolabe, Mercator charts), `tech_globe`, `tech_plant`, `tech_map`, `tech_galleon`, `tech_factory`,
`tech_press`, `tech_book`.

### 4.4 Eras

`data/defs/eras/<n>.tres` (`EraDef`):

| Era | Name | Opens | Gate | Kinds (infantry, missile, cavalry, artillery) | Roman |
|---|---|---|---|---|---|
| 1 | Age of Pikes | 1480 (the start) | | pikemen, crossbowmen, knights, bombards (ids 0 to 3) | I |
| 2 | Age of Arquebus | 1520 | 4 tree techs of era I | landsknechts, arquebusiers, lancers, culverins (4 to 7) | II |
| 3 | Age of Musket | 1575 | 4 tree techs of era II | pike regiments, musketeers, cuirassiers, field guns (8 to 11) | III |

`Research.era_ready(game, tag)`: an era after the country's exists; `Calendar.year_of(game.turn, game.start_year)` is at least its
`year`; the tree techs of the country's era it knows (national and `also_knows` techs not counted) number at least its `gate_techs`.
In the research phase, after the points (4.9), a ready country steps (`Research.step_era`): `era += 1`; `era_turns[era − 1] = turn`;
`era_reached {tag, era}`; an open offer adopts its first card (`idea_adopted {why: lapsed}`); a new offer is drawn (4.6). One step a
season at most.

### 4.5 National techs

Known from the start (`Research.setup`, D26); `cost` 0; never researched; drawn in the era I cell of their branch for their own
country only, with a gold tag of the country's name.

| Id | Key | Name | Country | Branch | Effects | Lines |
|---|---|---|---|---|---|---|
| 37 | `gendarmerie` | Gendarmerie | FRA | military | `war.fight_attack.cavalry`, `war.fight_defence.cavalry` scale 100 | "Cavalry +10 %" |
| 38 | `habsburg_marriages` | Habsburg marriages | AUS | statecraft | `research.diffusion_cap_permille` add 200 | "Diffusion cuts up to half a tech's cost" |
| 39 | `reislaufer` | Reisläufer | SWI | military | `war.fight_attack.infantry`, `war.fight_defence.infantry` scale 100 | "Infantry +10 %" |
| 40 | `keepers_of_the_passes` | Keepers of the passes | SAV | military | `defs.supply_reach` add 2 | "Supply reaches 2 points further" |
| 41 | `milanese_armour` | Milanese armour | MLO | military | `branch.cavalry.defence` add 1 | "Cavalry +1 defence" |
| 42 | `banco_di_rialto` | Banco di Rialto | VEN | trade | `also_knows` Banking; `trade.toll_permille` scale 250 | "Banking known; tolls +25 %" |
| 43 | `casa_di_san_giorgio` | Casa di San Giorgio | GEN | statecraft | `research.fund_bonus_permille` add 250 | "Funding gives a quarter more" |
| 44 | `platonic_academy` | Platonic Academy | TUS | statecraft | `research.bonus_permille` add 150 | "Research +15 %" |
| 45 | `holy_see` | Holy See | PAP | statecraft | `diplomacy.infamy_decay` add 1 | "Infamy fades 0.1 more a season" |
| 46 | `gonzaga_captains` | Gonzaga captains | MAN | military | `war.general_cost` scale −500 | "Generals cost half" |
| 47 | `este_foundries` | Este foundries | FER | military | `branch.artillery.attack` add 1 | "Artillery +1 attack" |
| 48 | `monte_dei_paschi` | Monte dei Paschi | SIE | trade | `defs.town_tax_milli` scale 50 | "Taxes on towns +5 %" |
| 49 | `lucchese_silk` | Lucchese silk | LUC | trade | `family.silk.base` scale 250 | "Silk +25 %" |
| 50 | `local_levies` | Local levies | (default) | military | `defs.levy_permille` add 10 | "Levies +10 %" |

`TechDef.nation` holds the tag (`&""` for the tree and the default); `Research.national_of(game, tag)` is the TechDef whose nation is
`tag`, else `ResearchDef.default_national`. The era I cells after nationals hold at most 4 techs (military 3 + 1, trade 3 + 1,
statecraft 2 + 1, navigation 3).

### 4.6 Idea cards

**The draw** (`Research.draw_ideas(game, tag)`): `offer = []`; the IdeaDef whose `nation` is `tag` and that the country has not
adopted joins first; then, while `offer` holds fewer than `idea_cards` (3) and the pool (general IdeaDefs not adopted, id order) is
not empty: each card weighs `idea_top_weight` (3) when its branch is a top branch (the branches with the most tree techs known; none
when every count is 0), else `idea_weight` (1); `r = game.luck.world.randi_range(1, total)`; the pool is walked in order subtracting
weights until `r ≤ 0`; that card joins and leaves the pool. `pending_ideas = offer`; `ideas_offered {tag, ideas, witnesses: [tag]}`.

**General cards** (ids 0 to 15, `data/defs/ideas/<key>.tres`):

| Id | Key | Name | Branch | Effects | Lines |
|---|---|---|---|---|---|
| 0 | `condottieri` | Condottieri | military | `branch.cavalry.cost` scale −250; `war.general_stack` add 1 | "Cavalry costs a quarter less; a general adds 1 more company" |
| 1 | `engineers` | Engineers | military | `family.castles.cost` scale −250 | "Castle works cost a quarter less" |
| 2 | `pike_levies` | Pike levies | military | `defs.levy_permille` add 10 | "A levy takes 11 % of a hex's people, not 10 %" |
| 3 | `cannon_founders` | Cannon founders | military | `branch.artillery.siege_points` add 1 | "Artillery +1 siege point" |
| 4 | `remount_stables` | Remount stables | military | `war.fight_attack.cavalry`, `war.fight_defence.cavalry` scale 50 | "Cavalry +5 % in a fight" |
| 5 | `fuggers_credit` | Fuggers' credit | trade | `research.fund_bonus_permille` add 250 | "Funding gives a quarter more" |
| 6 | `royal_mint` | Royal mint | trade | `defs.goods_share_permille` add 30 | "Taxes on goods +3 points at every level" |
| 7 | `merchant_houses` | Merchant houses | trade | `trade.merchants_base` add 1 | "+1 merchant" |
| 8 | `factors_letters` | Factors' letters | trade | `trade.idle_free_seasons` add −2; `trade.idle_flag_seasons` add −1 | "An idle merchant is flagged after 1 season and comes home after 2" |
| 9 | `navigators_guild` | Navigators' guild | navigation | `defs.land_sight` add 1 | "Your land sees 1 hex further" |
| 10 | `river_pilots` | River pilots (v0.2.2: Privateer letters) | navigation | `trade.route_cost_point_milli` add −2 | "Your merchants pay less transport" |
| 11 | `fishing_fleets` | Fishing fleets (v0.2.2: Colonial agents) | navigation | `family.harbour.base` scale 200 | "Harbours +20 %" |
| 12 | `humanism` | Humanism | statecraft | `research.bonus_permille` add 100 | "Research +10 %" |
| 13 | `confraternities` | Confraternities (v0.2.2: Reformed church) | statecraft | `defs.growth_bp` scale 200 | "People grow a fifth faster" |
| 14 | `civic_statutes` | Civic statutes (v0.2.2: Town charters) | statecraft | `defs.town_tax_milli` scale 100 | "Taxes on towns +10 %" |
| 15 | `resident_ambassadors` | Resident ambassadors | statecraft | `diplomacy.price_outside_permille` add −250; `diplomacy.infamy_decay` add 1 | "Land outside your war goal costs less in peace; infamy fades faster" |

**National cards** (ids 16 to 28):

| Id | Key | Name | Country | Branch | Effects | Lines |
|---|---|---|---|---|---|---|
| 16 | `taille_royale` | Taille royale | FRA | statecraft | `defs.tax_permille` add 50 at 2 | "High taxes +5 points" |
| 17 | `imperial_mines` | Imperial mines | AUS | trade | `family.mines.base` scale 150 | "Mines +15 %" |
| 18 | `mercenary_cantons` | Mercenary cantons | SWI | military | `branch.infantry.cost` scale −200 | "Infantry costs a fifth less" |
| 19 | `alpine_tolls` | Alpine tolls | SAV | trade | `trade.toll_permille` add 15 | "Tolls +1.5 points at every level" |
| 20 | `navigli` | The Navigli | MLO | navigation | `family.wheat.base` scale 150 | "Wheat +15 %: the canals water the plain" |
| 21 | `arsenal` | Arsenal of Venice | VEN | navigation | `trade.toll_permille` scale 150 | "Tolls +15 %" |
| 22 | `genoese_factors` | Genoese factors | GEN | trade | `trade.merchants_base` add 1 | "+1 merchant" |
| 23 | `ordinanza` | Ordinanza | TUS | military | the four `diplomacy.weariness_*` scale −500 | "A citizen militia: war weariness grows half as fast" |
| 24 | `indulgences` | Indulgences | PAP | statecraft | `defs.town_tax_milli` scale 100 | "Taxes on towns +10 %" |
| 25 | `mantuan_horse` | Mantuan horse | MAN | military | `war.fight_attack.cavalry` scale 100 | "Cavalry +10 % in attack" |
| 26 | `ferrarese_bastions` | Ferrarese bastions | FER | military | `war.castle_defence_permille` add 50 | "Fortresses +5 % a level" |
| 27 | `wool_guild` | Wool guild of Siena | SIE | trade | `family.grazing.base` scale 150 | "Grazing +15 %" |
| 28 | `silk_exchange` | Silk exchange | LUC | trade | `trade.merchant_capacity` add 4 | "Merchants carry 4 more loads" |

**Icons** (`IdeaDef.icon`): the branch's (`branch_military`, `branch_trade`, `branch_navigation`, `branch_statecraft`); a national
card adds the gold `national` band.

### 4.7 Research points

`Research.rate(game, tag)` (milli-points a season) over the country's **settlements it owns and controls** (`Occupation.controller_id`
is its id), in hex index order:

```
towns  = Σ MapState.people[hex] × research.town_milli / 1000            (each settlement, floored)
levels = Σ research.by_level[level]                                       (each settlement)
sum    = research.base_milli + towns + levels
rate   = sum × (1000 + research.bonus_permille) / 1000                    (the country's effective ResearchDef)
```

A country with no settlement has `base_milli` only (France and Austria keep theirs: their towns on the map). `Research.rate_parts`
gives the screen's parts: `base`, `towns` (with the people), `levels` (with the counts), `bonus` (permille), `funding` (the points
funded this season, 0 or one funding).

**North Italy, seed 1480, a new game** (the start people of `m5-build-spec.md` 4.2: hamlet 1,000, village 3,000, town 10,000,
walled town 30,000, city 60,000; `test_research_rate.gd` pins it):

| Tag | Settlements (villages, towns, walled, cities) | Town people | Towns | Levels | National | Rate (milli) | A season |
|---|---|---|---|---|---|---|---|
| FRA | 3, 0, 0, 0 | 9,000 | 135 | 0 | | 1,635 | 1.6 |
| AUS | 1, 2, 0, 0 | 23,000 | 345 | 200 | | 2,045 | 2.0 |
| SWI | 2, 6, 0, 0 | 66,000 | 990 | 600 | | 3,090 | 3.0 |
| SAV | 3, 9, 1, 0 | 129,000 | 1,935 | 1,150 | | 4,585 | 4.5 |
| MLO | 3, 15, 1, 1 | 249,000 | 3,735 | 2,250 | | 7,485 | 7.4 |
| VEN | 5, 1, 3, 1 | 175,000 | 2,625 | 1,350 | | 5,475 | 5.4 |
| GEN | 0, 1, 1, 0 | 40,000 | 600 | 350 | | 2,450 | 2.4 |
| TUS | 1, 0, 2, 0 | 63,000 | 945 | 500 | +150 | 3,386 | 3.3 |
| PAP | 3, 0, 1, 0 | 39,000 | 585 | 250 | | 2,335 | 2.3 |
| MAN | 0, 1, 0, 0 | 10,000 | 150 | 100 | | 1,750 | 1.7 |
| FER | 0, 1, 1, 0 | 40,000 | 600 | 350 | | 2,450 | 2.4 |
| SIE | 1, 0, 0, 0 | 3,000 | 45 | 0 | | 1,545 | 1.5 |
| LUC | 1, 0, 0, 0 | 3,000 | 45 | 0 | | 1,545 | 1.5 |

The settlements are the map's places by their 1480 holders (`m2-build-spec.md` 4.4); the build pins what it gives, and task Z6 writes
the table here if it differs.

### 4.8 Costs, diffusion and pace

`Research.cost(game, tag, tech)` (points): `TechDef.cost × (1000 − min(cap, diffusion_permille × n)) / 1000`, floored, at least 1,
where `cap = research.diffusion_cap_permille` (300) and `n` the trade partners (D17) that know it. `Research.partners(game, tag)`:
`M` = the markets (`TradeCache.market_of_hex`) of the land hexes `tag` controls; `M'` = `M` and every market one route from `M`
(`TradeCache.routes_of`); the partners are the living countries other than `tag` that control a land hex whose market is in `M'`, id
order; cached in `view_cache` by `[&"partners", game.version, tag]`. A game without markets uses `Territory.neighbours`.

**The pace the numbers give** (estimates the soak measures, 4.19; the tuning task keeps or moves them):

| Country | Rate 1480 → 1520 → 1575 (points a season, towns growing) | 4 era I techs | Era II | 4 era II techs | Era III | Techs by 1650 |
|---|---|---|---|---|---|---|
| Milan | 7.4 → 9.5 → 12 | 1489 | 1520 | 1527 | 1575 | 36 to 37 |
| Genoa, Ferrara | 2.4 → 3.0 → 3.8 (+1.5 a season funded) | 1506 | 1520 | 1560 | 1575 | 24 to 28 |
| Siena, Lucca | 1.5 → 1.7 → 2.0 | 1527 | 1527 to 1532 | 1600 | 1600 | 15 to 20 |

A median country learns a tech every 3 to 10 years and about 70 % of the tree by 1650, as the design asks.

### 4.9 The research phase

`Research.season(game)`, every living country in id order (a country with no land skipped):

1. `rate = Research.rate(game, tag)`; `progress += rate`; `research_last = rate`.
2. When `researching` is −1 or already known (a dev grant, an `also_knows`): `advance` (the next queue entry that is unknown, of an era
   at or below the country's, with every need known, becomes `researching`; entries passed are dropped).
3. While `researching` is not −1 and `progress ≥ cost(researching) × 1000`: `progress −= cost × 1000`; `Research.learn(game, tag,
   tech, &"research")` (appends to `techs` and `tech_turns`, every `also_knows` too; `tech_learned {tag, tech, why, cost}`); `advance`.
4. When the queue ran out in this phase: `research_idle {tag, witnesses: [tag]}`.
5. When `researching` is −1: `progress = min(progress, idle_keep_seasons × rate)`.
6. When `era_ready`: `step_era` (4.4).

### 4.10 Later kinds and refits

`data/defs/units/<key>.tres` (`UnitDef`, M6, M7; ids append-only):

| Id | Key | Name; one, many | Branch | Era | Men | Raise | Goods | Upkeep | Move | Sight | From level | Refill | Attack | Defence | Fire | Siege | Figure |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 to 3 | M6, M7's | | | 1 | | | | | | | | | | | | | `fig_infantry` ... |
| 4 | `landsknechts` | Landsknechts; company of landsknechts, companies of landsknechts | infantry | 2 | 500 | 30 | 1 iron | 7 | 12 | 1 | 1 | 50 | 5 | 6 | 0 | 0 | `fig_infantry_2` |
| 5 | `arquebusiers` | Arquebusiers; company of arquebusiers ... | missile | 2 | 500 | 34 | 2 iron | 8 | 12 | 1 | 1 | 50 | 6 | 3 | 40 | 0 | `fig_missile_2` |
| 6 | `lancers` | Lancers; company of lancers ... | cavalry | 2 | 250 | 50 | 1 iron, 3 horses | 10 | 16 | 2 | 2 | 25 | 7 | 3 | 0 | 0 | `fig_cavalry_2` |
| 7 | `culverins` | Culverins; battery of culverins, batteries of culverins | artillery | 2 | 100 | 66 | 5 iron, 4 copper | 9 | 8 | 1 | 3 | 10 | 7 | 1 | 65 | 2 | `fig_artillery_2` |
| 8 | `pike_regiments` | Pike regiments; company of the pike regiments ... | infantry | 3 | 500 | 34 | 2 iron | 8 | 12 | 1 | 1 | 50 | 6 | 7 | 0 | 0 | `fig_infantry_3` |
| 9 | `musketeers` | Musketeers; company of musketeers ... | missile | 3 | 500 | 38 | 2 iron | 9 | 12 | 1 | 1 | 50 | 7 | 4 | 55 | 0 | `fig_missile_3` |
| 10 | `cuirassiers` | Cuirassiers; company of cuirassiers ... | cavalry | 3 | 250 | 58 | 2 iron, 3 horses | 11 | 16 | 2 | 2 | 25 | 8 | 4 | 0 | 0 | `fig_cavalry_3` |
| 11 | `field_guns` | Field guns; battery of field guns ... | artillery | 3 | 100 | 72 | 6 iron, 5 copper | 10 | 10 | 1 | 3 | 10 | 9 | 2 | 80 | 2 | `fig_artillery_3` |

`GameDefs.validate` (M6's "4 units with ids 0..3") becomes: 12 units with ids 0 to 11 once each, and every era 1 to 3 holds exactly
one kind of each branch (`EraDef.kinds` lists them).

**Raising** (`Military.raise_options`, `raise_check`, M6 4.5): the options are the four kinds of the country's era;
`Military.later_options(game, tag, hex)` gives the four of the next era with their refusal (the Raise tab greys them). `raise_check` gains row **6b** after row 6: a kind of an older era: "your armies have moved on: raise
landsknechts instead" (the branch's kind of the country's era); of a later era: "landsknechts wait for the Age of Arquebus (1520 and 4
era I techs)".

**`Military.refit_check(game, {army, tag})`**, in order:

| # | Case | Verdict |
|---|---|---|
| 1 | No army given; no army with the id; another country's | M6's words ("no army given", "no army %d", "not your army: the %s commands it") |
| 2 | Every company is of the country's era or later | "every company of the %s is of the newest kinds" |
| 3 | The army's hex is not a settlement of level `refit_min_level` (3) or more that `tag` owns and controls | "refit in a town of yours: %s is not one" (`Military.hex_text`) |
| 4 | The treasury is under the ducats | "not enough ducats: %d needed, %d in the treasury" |
| 5 | A good is short | `Stores.short_of`'s words |
| 6 | Otherwise | ok |

The cost: per company of an older era, the new kind's `cost` and each `cost_goods` entry × `refit_permille` (500) / 1000, rounded up,
read from the country's effective definitions. `refit` checks again, then `Treasury.move(−ducats, &"refit", hex)`, per good
`Stores.move(−n, &"refit")`, `Armies.refit_units(game, army, ids, kinds, game.turn)` (each unit's `kind`, `refit_turn`; its men, morale
and experience kept; men above the new kind's are not possible, every branch keeps its men), and emits `army_refitted {tag, army,
hex, count, kinds, witnesses}`. An army with a unit whose `refit_turn` is the turn **musters** (`Army.mustering`).

**Example** (`test_refit.gd`): Genoa in the Age of Arquebus, the Army of Genoa at Genoa (8, 13) (a walled town) with 2 companies of
pikemen and 1 of crossbowmen: landsknechts 30 → 15 ducats and 1 iron each, arquebusiers 34 → 17 and 2 → 1 iron: **47 ducats and 3
iron**.

### 4.11 Generals

**Places.** `Generals.max_of(game, tag) = min(generals_cap (4), generals_base (1) + walled towns and cities it controls /
generals_per_towns (2))`; `Generals.count(game, tag)` = its armies with a general. On seed 1480: Genoa 1, Milan 2, Venice 3, Florence 2,
Savoy, Ferrara, the Papal States 1, every other 1.

**Traits** (`data/defs/traits/<key>.tres`, `TraitDef`):

| Key | Name | Lines | Fights it helps (attack and defence) | Branch | When defending | Bonus | Siege points | Icon |
|---|---|---|---|---|---|---|---|---|
| `field_marshal` | Field marshal | "+20 % on open ground" | open | | | 200 | 0 | `trait_field` |
| `ranger` | Ranger | "+20 % in woods and hills" | rough | | | 200 | 0 | `trait_ranger` |
| `siege_master` | Siege master | "+20 % in assaults; +1 siege point a season" | assault (and garrison) | | | 200 | 1 | `trait_siege` |
| `defender` | Defender | "+20 % when defending" | | | yes | 200 | 0 | `trait_defender` |
| `cavalier` | Cavalier | "+20 % for cavalry" | | cavalry | | 200 | 0 | `trait_cavalier` |

**In battle** (`Battles.input_of`, `Combat`; M7 4.6 edited): a side's general is the trait of its army with the most men on the hex
(ties: lower id); `input.generals[side]` holds `{key, fights, branch, defending, bonus}` or `{}`:

```
att(a) = M7's att with the striker's side's WarDef  × (1000 + bonus) / 1000 when its side's general helps:
         the fight (0 open, 1 rough, 2 assault) is in fights, or the company's branch is the trait's
def(t) = M7's def with the struck side's WarDef     × (1000 + bonus) / 1000 when its side's general helps:
         the fight (0 open, 1 rough, 2 garrison) is in fights, the branch is the trait's, or defending and its side defends
a fighter's morale loss of a day × (1000 − general_morale_cut_permille (150)) / 1000 when its side has a general
```

M7's worked hit with a Field marshal on the attacker's side: 500 × 80 = 40,000; × 4,800 / 5,000 = 38,400; × 1,200 / 1,000 = 46,080;
× 800 / 1,000 = 36,864; × 1,100 / 1,000 = 40,550; **hit 40 men** (20 wounded, 20 killed; 33 without). With a Defender on the
defender's side instead: × 4,000 / 6,000 = 26,666; × 1.2 = 31,999; × 0.8 = 25,599; × 1.1 = 28,158; **28 men**.

**Elsewhere:** `Military.stack_limit_at` adds `general_stack` (2); `Battles.fits` uses it per side; `Sieges.terms` adds the siege
master's `siege_points` (1) to the rate of a siege its army lays (still capped by `siege_rate_max`); `Military.upkeep_of` adds
`general_upkeep` (4) to an army with a general (M6's `upkeep_army` line); `BattleRecord.generals` keeps both sides' traits.

**`Generals.appoint_general_check(game, {army, trait, tag})`**, in order: rows 1 of refit; "no such trait" (not a `TraitDef` key);
"the %s has a general already"; "a general takes command in your own land" (the army's hex is not owned and controlled by `tag`);
"no general can be appointed in this game" (`max_of` 0); "all your generals are in the field: %d of %d"; "a general costs %d ducats:
%d in the treasury" (`general_cost` of the effective `WarDef`); ok. `appoint_general`: `Treasury.move(−cost, &"general", hex)`,
`Armies.set_general(game, army, trait)`, `general_appointed {tag, army, trait, hex, witnesses}`.

**`dismiss_general_check(game, {army, tag})`**: rows 1; "the %s has no general"; ok. `dismiss_general`: `Armies.set_general(&"")`,
`general_dismissed {tag, army, trait, why: &"order"}`. **M6's `merge_check`** gains, after "the armies stand on different hexes":
"both armies have a general: dismiss one first"; `merge_armies` gives `into` the moving army's general when `into` has none. A split's
new army has none. **`Armies.remove`** of an army with a general emits `general_lost {tag, army, trait, why}` (`why` the army's: `lost`
in battle or hunger, `surrendered`); disbanding a whole army dismisses its general (`general_dismissed {why: &"disband"}`).

### 4.12 The actions and their checks

| Action | Args | Pair | Rows, in order (the first refusal is the verdict) |
|---|---|---|---|
| `set_research` | `{tech, tag}` | `Research` | "this map has no countries"; "choose your country first"; "no country %s"; "%s is no more"; "no such tech"; "%s is a national tech: it is known from the start"; "you know %s already"; "%s waits for the %s (%d and %d era %s techs)"; "you are researching %s already" (the same path and queue); ok: `researching = path[0]`, `queue = path[1..]` |
| `queue_research` | `{tech, tag}` | `Research` | the first eight of `set_research`; "%s is in your research already" (every tech of its path is researching or queued); ok: the missing path appended; when `researching` is −1 the first becomes it |
| `unqueue_research` | `{tech, tag}` | `Research` | the first five of `set_research`; "%s is not in your research"; ok: it and the queued techs that need it, directly or through each other, leave; when it was the research, `advance` |
| `fund_research` | `{tag}` | `Research` | the first four of `set_research`; "research is off in this game" (`fund_points` 0); "nothing is being researched: pick a tech first"; "funded already: again in %s" (`Words.seasons` of `funded_turn + fund_every − turn`); "funding costs %d ducats: %d in the treasury"; ok: `Treasury.move(−fund_ducats, &"research")`, `progress += fund_points × (1000 + fund_bonus_permille)`, `funded_turn = turn` |
| `pick_idea` | `{idea, tag}` | `Research` | the first four of `set_research`; "no idea is on offer"; "that card is not on offer"; ok: `ideas`, `idea_turns` append; `pending_ideas` emptied |
| `appoint_general` | `{army, trait, tag}` | `Generals` | 4.11 |
| `dismiss_general` | `{army, tag}` | `Generals` | 4.11 |
| `refit` | `{army, tag}` | `Military` | 4.10 |

The path (`Research.path_to(game, tag, tech)`): its unknown needs depth-first in `needs` order, each before the techs that need it,
then the tech. The era row names the tech's era: "Banking waits for the Age of Arquebus (1520 and 4 era I techs)".

### 4.13 What you may know of others

| Thing | You see |
|---|---|
| Your own research, ideas, offers, generals | everything, exact |
| A known country's era, the turn it entered it, its known techs (and when each was learned), its ideas, its national tech | everything (public) |
| A known country's research in progress, queue, progress, rate, funding | nothing |
| An unknown country | nothing; counted in "n countries unknown" |
| The generals of other countries | only in battle records you may see (M7's access: the dock's face-off) |
| A tech's diffusion | the share it cuts and the count: "−20 %: 2 countries you trade with know it" (the rule's own number) |

`Knowledge.knows(game, viewer, other)` (M3, M6) is also true when a land hex of `other` lies within `defs_of(viewer).know_range` hexes
of a land hex of `viewer` (1 by default: the neighbour rule already true); cached by `[&"known", game.version, viewer]`.
`Knowledge.techs_seen`, `ideas_seen` and `era_seen` return a known country's lists and era, or empty and 0. The AI's door (M8) reads
others' research only through them (it needs none for its own choices).

### 4.14 The economy, people, armies, war, diplomacy and trade after M11 (M4 to M10, edited)

| Place | After M11 |
|---|---|
| `Economy.district_base` (M4 4.4) | `FamilyDef` of the hex's **owner's** effective definitions (`base`, the settlement's `room` and port numbers); `DistrictCache.forget_land(game, tag)` drops its hexes when the owner's family or settlement keys change |
| `Economy.season_output` | called with the owner's effective definitions (the port dues and fish) |
| `EconomySeason.money_lines` | `town_tax_milli`, `tax_permille`, `goods_share_permille` of the country's |
| `People.change_at`, `room_at`, `available` (M5) | `growth_bp`, the settlements' `room`, `levy_permille` of the hex's owner's |
| `Works.cost_of(game, action, family, level_to, tag)` (M3, M4) | the actor's `FamilyDef.cost` |
| `Military.unit_def(game, kind, tag)`, `cost_of(game, kind, count, tag)`, `stack_limit`, `stack_limit_at` (M6) | the country's `UnitDef`s, `stack_limit` and `war.general_stack` |
| `Supply.food_need(game, men, tag)`, `SupplyCache.field_of` (M6) | the army's country's `army_food_milli` and `supply_reach` |
| `SightCache.land_of`, `Vision`'s army sight (M6) | the country's `land_sight`; each kind's `sight` of the army's country |
| `Battles.input_of`, `Combat` (M7) | each fighter's attack, defence and fire from its country's `UnitDef`; `input.wars` (the two sides' `WarDef`), `input.generals` (4.11) |
| `BattleEnd.apply` (M7) | each company's `xp_win`, `xp_lose` from its country's |
| `Occupation.siege_need`, `Sieges.terms` (M7) | the fortress controller's `siege_per_level` and garrison numbers; the besieger's artillery `siege_points` and the siege master |
| `WarGoals.goal_of(game, target_id, anchor, by_id)` (M9) | the declarer's `goal_districts` |
| `Peace.price_of` (M9) | the winner's `price_outside_permille` |
| `Brakes.tax_share`, `Brakes.season`, `Unrest`'s far term (M9) | the owner's `reach_free`; each country's `infamy_decay` and four weariness numbers |
| `TradeCache.catchment` (M10) | each market town's controller's `market_reach` (a multi-source search where a source stops at its own reach) |
| `Trade.country_step`, `Trade.toll_rate` (M10) | the offering country's `remote_permille`; the market town controller's `toll_permille` |
| `Merchants.count`, `estimate`, `carry`, `book` (M10) | the country's `merchants_base`, `merchants_max`; the order's country's `merchant_capacity`, `route_cost_point_milli`, idle numbers (the free traders keep the base route cost) |
| `Knowledge.knows` (M3) | the viewer's `know_range` (4.13) |
| `EconomyPreview`, `ImprovePreview`, `RoadPreview`, `OddsView`, the AI's cards | through the same systems: the techs known now (D40) |

**`ResearchFixture.off(defs)`** (tests only): a defs copy with `base_milli`, `town_milli`, every `by_level` and `fund_points` 0,
`start_national` false, `generals_base` and `generals_cap` 0: no country ever has an effect, no general is ever appointed.
`ScenarioFixture` (M2) applies it unless a test asks `with_research(true)`; every pin of M3 to M10 holds; M11's tests ask for research;
the soak and the tools play with it.

### 4.15 The season table after M11

`Season.PHASES` (17; `test_season.gd` pins it): **`ai_orders`, `movement`, `battles`, `supply`, `sieges`, `war`, `relations`,
`production`, `trade`, `income`, `works`, `people`, `research`, `stats`, `calendar`, `ready_units`, `vision`**.

| # | Name | Arrives | Reads | Writes (through the owner) |
|---|---|---|---|---|
| 1 to 12 | `ai_orders` ... `people` | M3 to M10 | as M10; every per-country number from `defs_of` (4.14) | as M10; the AI's research, general and refit acts through `Game.act` |
| 13 | **`research`** | **M11** | countries, settlements' people and levels, controllers, the techs of partners (markets and routes), `defs_of`, `turn`, `start_year`, `luck.world` | the twelve research fields (`Research`); `luck` (the draw); events `tech_learned`, `research_idle`, `era_reached`, `idea_adopted` (lapsed), `ideas_offered` |
| 14 to 17 | `stats` ... `vision` | M3, M6 | as M10; `stats` reads `research_last`, `techs`, `era` | as M10; `stats` writes `research`, `techs`, `era` |

Why this order: the season's people make the season's points; a tech learned counts from the next season's phases; the report reads
the points from the stats.

### 4.16 Events, witnesses, log lines

| Kind | Fields (besides `kind`, `turn`) | Emitted by | Notable | Typed signal | Heard by |
|---|---|---|---|---|---|
| `tech_learned` | `tag`, `tech`, `why` (`research`, `dev`), `cost` (no `witnesses`: those who know the country) | `Research.learn` | yes | `tech_learned(tag, tech)` | `TechScreen`, `Chips`, `CountryPanel`, `PageResearch`; log, notifications (yours), ribbons |
| `era_reached` | `tag`, `era` (no `witnesses`) | `Research.step_era` | yes | `era_reached(tag, era)` | `TechScreen`, `Chips`, `CountryPanel`, `RaiseList`, `ArmyPanel`, `PageResearch`; log, notifications (yours), ribbons |
| `ideas_offered` | `tag`, `ideas`, `witnesses` ([tag]) | `Research.step_era` | yes | `ideas_offered(tag, ideas)` | the App (a decision for the player), `TechScreen`, `TaskFlag`; log (yours) |
| `idea_adopted` | `tag`, `idea`, `why` (`pick`, `lapsed`) (no `witnesses`) | `Research.pick_idea`, `step_era` | yes | `idea_adopted(tag, idea)` | `TechScreen`, `IdeaPick`, `CountryPanel`, `PageResearch`; log |
| `research_set` | `tag`, `tech`, `queue`, `witnesses` ([tag]) | `set_research`, `queue_research`, `unqueue_research` | no | `research_set(tag, tech)` | `TechScreen`, `Chips` |
| `research_funded` | `tag`, `milli`, `ducats`, `witnesses` ([tag]) | `fund_research` | no | `research_funded(tag, milli)` | `TechScreen`, `Chips`; log (Money) |
| `research_idle` | `tag`, `witnesses` ([tag]) | `Research.season` | yes | `research_idle(tag)` | `Chips`, `TaskFlag`; log (yours), notifications |
| `general_appointed` | `tag`, `army`, `trait`, `hex`, `witnesses` (Vision) | `Generals.appoint_general` | yes | `general_appointed(tag, army, trait)` | `ArmyPanel`, `ArmyTokens`; log (War), ribbons |
| `general_dismissed` | `tag`, `army`, `trait`, `why` (`order`, `disband`), `witnesses` ([tag]) | `Generals.dismiss_general`, `Military.disband` | no | `general_dismissed(tag, army)` | `ArmyPanel`, `ArmyTokens`; log |
| `general_lost` | `tag`, `army`, `trait`, `why`, `witnesses` (Vision) | `Armies.remove` | yes | `general_lost(tag, army, trait)` | `ArmyPanel`, `ArmyTokens`; log (War), notifications (yours) |
| `army_refitted` | `tag`, `army`, `hex`, `count`, `kinds`, `witnesses` (Vision) | `Military.refit` | yes | `army_refitted(tag, army, count)` | `ArmyPanel`, `ArmyTokens`, `RaiseList`; log (War), ribbons |

`Chronicle.NOTABLE` gains the eight kinds marked yes above (**48**); the log
is fed from the chronicle, so the three kinds that are not notable (`research_set`, `research_funded`, `general_dismissed`) make no log
line: their toasts and the report's orders and treasury lines tell them. `Vision.SIGHTED` gains `general_appointed`, `general_lost`, `army_refitted`.
`SeasonSummary.COVERED` gains `tech_learned`, `era_reached`, `idea_adopted`, `general_lost`, `army_refitted`.

**Log lines** (`LogLines.line_of`; All and Mine for the player's unless said):

| Kind | The player's line | A witnessed other's |
|---|---|---|
| `tech_learned` | "You learned Banking: taxes on towns +20 %." keyword "Learned", good; `notify` true; ribbon "Banking" at the capital | "The Duchy of Milan learned Banking." muted |
| `era_reached` | "A new age: the Age of Arquebus. Landsknechts, arquebusiers, lancers and culverins can now be raised; refit your companies in a town." keyword "Age", good; `notify` true; ribbon "A new age" at the capital | "The Duchy of Milan entered the Age of Arquebus." plain |
| `ideas_offered` | "Choose your idea for the Age of Arquebus (T)." warn | |
| `idea_adopted` | "You adopted Humanism: research +10 %." good / lapsed: "Your offer lapsed: you adopted Genoese factors." | "The Duchy of Milan adopted Condottieri." muted |
| `research_idle` | "Nothing is being researched: pick a tech (T)." warn; `notify` true | |
| `general_appointed` | "A Ranger takes command of the Army of Novi (+20 % in woods and hills)." War filter; ribbon "General" | "The Duchy of Milan's Army of Pavia has a general." muted |
| `general_lost` | "The Army of Novi and its general are lost." bad, War; `notify` true | "The Duchy of Milan's Army of Pavia lost its general." muted |
| `army_refitted` | "The Army of Novi refits 3 companies as landsknechts and arquebusiers (−47 ducats)." War; ribbon "Refitted" | "The Duchy of Milan refitted the Army of Pavia." muted |

### 4.17 The AI (M8's, edited)

A seat's turn after M11: `brief`, `peace`, `diplomacy`, `war`, `works_scan` × 2, `works_card` × k, `works_act`, `trade`, **`research`**,
`forces`, `army` × n, `tax`, `done`. The AI acts only in `ai_orders`, through `AiKnow` and `Game.act`; its research draws only
`luck.ai`.

**The research step** (`AiResearch.research`, new, one step a seat):

1. **Idea**: an offer pending: each card scores `branch_weights[branch] × situation[branch] / 1000 × jitter / 1000`; the nation's card
   is taken unless the best general card scores more than its score × `idea_own_permille` (1,500) / 1000; `pick_idea`.
2. **Research**, when `researching` is −1 (`AiKnow.research_of`): every available tech of `AiKnow.tech_options` scores
   `branch_weights[branch] × situation[branch] / 1000 × gate × 1000 / cost × jitter / 1000` (`gate` = `research_gate_permille` (1,500)
   for a tech of the seat's era while the next era exists and fewer than its `gate_techs` are known, else 1,000); the best (ties:
   lower id) is `set_research`.
3. **Funding**: at peace (no enemy), `fund_points` over 0, the treasury at least `fund_ducats + fund_reserve_mult (2) × R` and the
   check allowing it: `fund_research`.

`situation[branch]` starts at 1,000 each, then: military × `research_war_permille` (2,000) / 1000 with enemies or threats; trade ×
`research_poor_permille` (1,500) / 1000 when the treasury is under `R`; navigation × `research_coast_permille` (1,300) / 1000 when a
settlement of the seat is a port.

| `AiTemperDef.branch_weights` (military, trade, navigation, statecraft) | builder | cautious | steadfast | aggressive | opportunist | conqueror |
|---|---|---|---|---|---|---|
| | 800, 1300, 1000, 1100 | 1000, 1100, 900, 1200 | 1300, 900, 800, 1100 | 1500, 800, 800, 900 | 1200, 1100, 900, 1000 | 1600, 800, 700, 900 |

**Generals and refits** (`AiForces.forces`, M8, edited; after its raises):

- **Appoint**: when `AiKnow.general_room` is over 0: the seat's army with the most companies, at least `general_min_companies` (4), no
  general, on land it owns and controls, with `T − cost ≥ R`; the trait: Cavalier when cavalry is at least a quarter of its companies;
  else Siege master when it holds artillery and the seat is at war; else Defender for a cautious or steadfast seat at peace; else
  Ranger when its hex is rough; else Field marshal; `appoint_general`; at most `generals_per_season` (1).
- **Refit**: the first army (id order) standing in a town of the seat (level 3 or more) with companies of an older era, the money over
  `R` after it: `refit`; at most `refits_per_season` (1).
- **Raise**: M8's `mix` read by branch; the kind is the seat's era kind of the branch (`AiKnow.kind_of`).

| `AiDef` field (new) | Value | Used in |
|---|---|---|
| `research_war_permille` | 2,000 | military weight at war or under threat |
| `research_poor_permille` | 1,500 | trade weight under the reserve |
| `research_coast_permille` | 1,300 | navigation weight with a port |
| `research_gate_permille` | 1,500 | the era's techs while its gate is unmet |
| `fund_reserve_mult` | 2 | funds with `fund_ducats + 2 R` or more |
| `idea_own_permille` | 1,500 | the national card's margin |
| `general_min_companies` | 4 | the smallest army it gives a general |
| `generals_per_season`, `refits_per_season` | 1, 1 | acts a season |

**`AiKnow` grows** (5.7): `defs`, `research_of`, `tech_options`, `ideas_offered`, `kind_of`, `general_room`, `general_cost`,
`refit_options`. `AiBrief` gains `defs` (the seat's effective definitions, read by `AiEconomy.prior` and the forces' costs) and
`research`. **The door's text rule** (M8 4.3) adds the tokens `Research.`, `Generals.`, `ModApply.`, `game.mods`, `.defs_of(`, `.techs`,
`.ideas`, `.pending_ideas`. **The fog**: others' research in progress is never read; `test_ai_fog.gd` changes it and finds the same acts.
The steps after `research` read `AiKnow.defs` afresh, so an idea picked counts at once. `AiTurn.research_scripts` (a test seam like
`judge`, never saved): tag → `Callable(turn, game, brief)` run instead of the whole
research step (the soak's scripted Genoa).

### 4.18 Worked examples

**(a) `ResearchFixture.duo`** (tests only; `tests/core/research_fixture.gd`): M10's `TradeFixture.duo` map with research on: WES
(id 1) holds West (1, 1), a walled town of 30,000; EAS (id 2) holds East (7, 1), a city of 60,000; one route joins their markets, so
each is the other's trade partner; the fixture's countries have no national tech; 500 ducats each; calm; people held still
(`PeopleFixture.still`, M5); both passive.

| | WES | EAS |
|---|---|---|
| Rate | 1,500 + 30,000 × 15 / 1000 (450) + 250 = **2,200** | 1,500 + 900 + 500 = **2,900** |
| First research | Crop rotation (70: the cheapest, lowest id) | Crop rotation |
| Learned | turn **29**: progress 2,200 × t; at turn 25 EAS learns it after WES's phase (id order), so from turn 26 WES's cost is 70 × 900 / 1000 = 63; 2,200 × 29 = 63,800 ≥ 63,000 (turn 32, 70,400, without a partner) | turn **25**: 2,900 × 25 = 72,500 ≥ 70,000 (69,600 at 24); 2,500 carried |
| With a funding at turns 1, 5, 9, 13 and 17 (80 ducats each) | +6,000 each before the phase: 2,200 × 18 + 30,000 = 69,600 < 70,000 at turn 18; 2,200 × 19 + 30,000 = 71,800 at turn **19**: learned, 1,800 carried; the treasury 500 − 400 = 100 | |

**(b) The gate on `ResearchFixture.quick`** (the duo with era II in 1481, era III in 1482, costs a tenth, floored, at least 1): WES is
played by `ResearchScript.gate_first` before each End season, EAS stays passive. EAS learns Crop rotation (7) in turn 3 (8,700), so
WES's costs it 6 from turn 4: WES learns Crop rotation in turn **4** (8,800; 2,800 carried), Portolan charts (7) in turn **6**, Tax
rolls (7) in turn **10** and Drill yards (8) in turn **13** (8,600). Turn 13 is Spring 1483: WES enters the Age of Arquebus in that
research phase, its offer drawn; the test pins the three cards for the seed.

**(c) North Italy, seed 1480, as Genoa** (`test_research_italy.gd`: no orders hook, so no AI acts; before each season the test acts
the research choices of `ResearchScript.gate_first` for Genoa, without funding):
the rates of 4.7; Genoa learns Crop rotation, Portolan charts, Tax rolls and Drill yards by turn 120 or earlier; it enters the Age of
Arquebus in the research phase of turn **161**; its offer is Genoese factors and two general cards drawn from the seed's world stream.
The turns of each tech are pinned as the build gives them.

**(d) A general** (M7's worked hit): 40 men with a Field marshal, 28 with a Defender (4.11).

**(e) A refit** (4.10): 47 ducats and 3 iron.

### 4.19 The soak

`godot/tools/soak.gd` (M8 to M10) gains the suite, two invariants, the ranges below and the scripted player.

| Suite | Games | Seasons | What | Quick |
|---|---|---|---|---|
| **`research`** (new) | seeds 1 to 10 | 440 | north Italy, AI-only; Genoa's research step scripted (`ResearchScript.gate_first`: the cheapest available tech of its era until the gate's count is met, then the cheapest; funds yearly with 300 ducats or more; takes the first card), every other step of Genoa the AI's | seed 1 × 24 |

In the `research` suite `runaway` (M9) is counted and reported, not ending the game (its games run five times the 80 seasons it was
set for).

| Invariant | Holds after every season |
|---|---|
| `research` | every living country: era 1 to 3, never lower than before; techs distinct, known ids; every tree tech known has its needs known (techs known at turn 0 excepted) and an era at or below the country's; `researching` −1 or an available tech; the queue distinct, unknown, of eras at or below; `progress` at least 0 and under the cost of `researching` (× 1000), or at most `idle_keep_seasons × research_last` when idle; `pending_ideas` empty or 3 distinct cards not adopted; ideas adopted at most `era − 1` |
| `generals` | per country, armies with a general at most `Generals.max_of`; every general a `TraitDef` key; M8's `armies` invariant reads `Military.stack_limit_at` |

| Measure | Suite | Range |
|---|---|---|
| the median turn of reaching era II over country-games (unreached counted as 441) | research | 161 to 189 |
| country-games in era II by turn 240 | research | ≥ 80 % |
| country-games in era III by turn 440 | research | ≥ 50 % |
| the scripted Genoa's era II turn | research | ≤ 169 in ≥ 9 of 10 games |
| the scripted Genoa's era III turn | research | ≤ 420 in ≥ 7 of 10 games |
| techs known a country at turn 440 (median) | research | 20 to 30 |
| seasons a country starts its research phase with nothing researched while a tech is available (median a country-game) | research | ≤ 4 |
| the research rate a country at turn 240 (median, points a season) | research | 2.5 to 6.0 |
| companies of an older era, 8 seasons after their country's era step (share) | research | ≤ 50 % |
| techs known a country at season 80 (median, the national counted) | ai | 2 to 6 |
| fundings a country in 80 seasons (median) | ai | 1 to 20 |
| generals appointed a game (median) | ai | ≥ 3 |
| M8's, M9's and M10's ranges | as theirs | as theirs (with research and generals on: the tuning task re-measures them) |

The summary's per-country table gains: era II and III turns, techs at 80, 240 and 440, the rate, fundings, ideas, generals, refits.
**CI**: the nightly `soak` matrix gains `research` 1-5 and 6-10 (each about 5 minutes), judged together by `soak-ranges`.
`godot/tools/research_report.gd` (new, headless): per seed and country the era turns, techs at 1520, 1575 and 1650, the rate a
decade, fundings and ideas over any number of seasons (`--seeds=1480,1481 --seasons=681`); the tuning task runs it to 1650 on three
seeds and keeps the median techs known by Winter 1650 between 22 and 30 (60 to 80 % of the tree).

### 4.20 The season report, reminders, Stats

`SeasonSummary.SECTIONS`: glance, before, treasury, goods, trade, works, people, **research**, armies, war, diplomacy, orders, befell,
standing (14).

| Id | M11 content |
|---|---|
| `glance` | a chip "Learned Banking" (good) when a tech of yours was learned; "A new age" (gold) when an era was reached |
| `treasury` | "Research funded ▼ −80", "A general appointed ▼ −100", "Refits ▼ −47" (the lines `research`, `general`, `refit`) |
| `research` (**new**) | `total` "Research +2.4 a season" (`Stats.research` of the season / 1000, one decimal); "Researching Double-entry books: 12 of 80, about 28 seasons." (rank 10); "Learned: Banking. Taxes on towns +20 %." (good, rank its cost); "A new age: the Age of Arquebus." (good, rank 1,000); "Choose your idea for the Age of Arquebus." (warn, rank 500); "Adopted: Humanism. Research +10 %." (rank 300); "Nothing is being researched: points beyond four seasons are lost." (bad, rank 400); the diffusion line (`sub`) "Banking costs 20 % less: 2 countries you trade with know it." |
| `orders` | "Research: Banking (then 2 more).", "Queued: Universities.", "Removed from the research: Universities.", "Funded research: +6 points (80 ducats).", "Adopted the idea Humanism.", "Appointed a Ranger to the Army of Novi.", "Dismissed the general of the Army of Novi.", "Refitted 3 companies of the Army of Novi." |
| `befell` | others' eras ("The Duchy of Milan entered the Age of Arquebus.", rank 50), techs (one line a country: "Venice learned Banking and Guilds.", rank 5) and ideas, of countries you know |

**Quiet** (M10's rule, plus): no tech learned, no era, no idea of yours.

`Reminders.RULES` gains `idea_pending` after `demand_open`, `research_idle` after `merchant_flagged`, `refit_due` after `army_idle`.

| Rule | When | Severity | Text | Action |
|---|---|---|---|---|
| `idea_pending` | an offer of yours is pending | 2 | "Choose your idea for the Age of Arquebus: three cards wait." | `[&"ideas"]`, "Choose" |
| `research_idle` | `researching` is −1 | 1 | "Nothing is being researched: points beyond four seasons are lost." / with nothing available: "Every tech of your age is known: the Age of Arquebus opens in 1520." (severity 0) | `[&"tech"]`, "Open research (T)" |
| `refit_due` | an army of yours holds companies of an older era | 0 | "4 companies are of the Age of Pikes: refit them in a town of yours." | `[&"army", id]`, "Show the army" |

`Stats.SERIES` appends `techs` (known, the national counted) and `era` (**60**); `research` (M3) is written: `research_last` (milli).

### 4.21 The study and the history

The study's nav after M11: Economy, Trade, Diplomacy, Military, People, **Research**, Rankings, History (`StudyPages.LIST`, since
"11"). `StudyHistory.MARK_KINDS` after M11: `war`, **`era`** (good, icon `era`: the viewer's `era_reached`), `land`, `finished`,
`stopped`, `short`, **`tech`** (good, icon `tech_book`: the viewer's `tech_learned`), `begun`, `tax`, `chosen` (M5's `declined` and
`grew` where M5 put them). The Military page's armies table gains a General column.

### 4.22 Saves and the digest

| Body key | M11 adds | In `Game.digest()` |
|---|---|---|
| `format` | 9 (`SaveFile.FORMAT`; `OLDEST_FORMAT` 9) | no |
| `countries` | `country/7`: `era`, `techs`, `tech_turns`, `researching`, `queue`, `progress`, `research_last`, `funded_turn`, `ideas`, `idea_turns`, `pending_ideas`, `era_turns`; `country/6` refused | each `digest_text()` |
| `armies` | `army/3` (`general`), `unit/3` (`refit_turn`); `army/2`, `unit/2` refused | each `digest_text()` |
| `war` (M7) | its records are `battle-record/2` (`generals`); `/1` refused | as M7 |
| `stats` | `stats/2` with the two series appended (by name: older rows load as zeros) | `Stats.digest()` |
| `luck` | the world stream after the draws | as M3 |
| `action_log` | M11's eight actions; the dev records `dev_tech`, `dev_research`, `dev_era` | no |
| (not saved) | `game.mods` (`ModsCache`), every effective `GameDefs` | no |

Sizes: a country's research is under 200 ints; on the made-up Europe 60 countries add about 50 KB before compression; `save_mb` stays
8.

---

## 5. Interfaces

Layers after M8: `defs`, `state`, `systems`, `game`, `views`, `ai`, `shell`. `core/` makes no engine calls; M11's luck is the idea
draw (`luck.world`) and the AI's jitter (`luck.ai`), each through `Rng`. New files are marked **new**; "(M2)" to "(M10)" name pieces
those milestones build. Every amount is an `int`, every rate a permille, research points in milli. Systems never call `Words`; their
words name a tech by `TechDef.name`, an era by `EraDef.name`, an army by `Army.name`, a hex by `Military.hex_text` (M6).

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/mod_def.gd  (new): one modifier row
class_name ModDef extends Resource
const OPS: Array[StringName] = [&"add", &"scale"]
@export var key: String               # a ModKeys key: "trade.merchant_capacity", "family.wheat.base", "war.fight_attack.cavalry"
@export var op: StringName = &"add"
@export var value: int = 0            # add: the amount; scale: a permille delta (+100 = a tenth more)
@export var at: int = -1              # an array field's entry; -1 every entry
func validate() -> Array[String]      # ModKeys.known(key); op in OPS and allowed for the key; value != 0; at -1 or within the field's size

# core/defs/mod_keys.gd  (new): the registry (4.2); plain constants, no engine call
class_name ModKeys extends RefCounted
const KEYS: Dictionary = {}           # pattern -> {ops: Array[StringName], min: int, max: int, reader: String, whose: String,
	#   forgets: Array[StringName]}: the 55 rows of 4.2 (patterns hold <family>, <branch>, <good>)
static func known(key: String) -> bool
static func resolve(key: String, defs: GameDefs) -> Dictionary
	# {} unknown; else {scope: &"defs" | &"war" | &"trade" | &"diplomacy" | &"research" | &"family" | &"families" | &"branch" |
	#  &"units", target: StringName (a family key, a branch or ""), field: StringName, part: StringName (a dictionary entry or ""),
	#  row: Dictionary (its KEYS row)}
static func forgets_of(effects: Array[ModDef]) -> Array[StringName]   # the union of the rows' forgets, in KEYS order

# core/defs/mod_apply.gd  (new): the only reader of ModDefs
class_name ModApply extends RefCounted
static func apply(base: GameDefs, effects: Array[ModDef]) -> GameDefs   # 4.2; base itself when effects is empty
static func effects_of(defs: GameDefs, techs: PackedInt32Array, ideas: PackedInt32Array) -> Array[ModDef]   # 4.2's order
static func value_of(base_value: int, adds: int, scales: int) -> int      # (base + adds) * (1000 + scales) floor-divided by 1000 (ints)
static func diff(a: GameDefs, b: GameDefs) -> PackedStringArray           # the "scope.target.field[.part]" paths that differ (tests)

# core/defs/tech_def.gd  (new)
class_name TechDef extends Resource
@export var id: int                   # its place in GameDefs.techs, append-only
@export var key: StringName           # &"banking"
@export var name: String              # "Banking"
@export var branch: StringName        # ResearchDef.branches entry
@export var era: int = 1              # 1..3
@export var cost: int = 0             # points; 0 for a national tech
@export var needs: Array[StringName] = []
@export var effects: Array[ModDef] = []    # sub-resources in the file
@export var lines: PackedStringArray       # the effect text
@export var flavour: String = ""
@export var icon: StringName               # &"tech_bank"
@export var nation: StringName = &""       # a national tech's tag; &"" the tree and the default
@export var also_knows: Array[StringName] = []
@export var was: String = ""               # the v0.2.2 name when renamed
func is_tree() -> bool                     # nation == &"" and cost > 0
func validate(defs: GameDefs) -> Array[String]
	# key form; branch known; era 1..3; a tree tech's cost 1..2000, a national's 0; needs known tree keys, no self, of eras
	# <= era; every effect valid; lines not empty; icon not empty; also_knows known tree keys

# core/defs/idea_def.gd  (new)
class_name IdeaDef extends Resource
@export var id: int
@export var key: StringName
@export var name: String
@export var branch: StringName
@export var effects: Array[ModDef] = []
@export var lines: PackedStringArray
@export var icon: StringName
@export var nation: StringName = &""       # a national card's tag
@export var was: String = ""
func validate(defs: GameDefs) -> Array[String]

# core/defs/era_def.gd  (new)
class_name EraDef extends Resource
@export var id: int                        # 1..3
@export var name: String                   # "Age of Arquebus"
@export var roman: String                  # "II"
@export var year: int                      # 1520
@export var gate_techs: int = 4            # tree techs of the era before (0 for era 1)
@export var kinds: PackedInt32Array        # 4, by branch: UnitDef ids
func validate(defs: GameDefs) -> Array[String]   # kinds known, of this era, one a branch in BRANCHES order

# core/defs/trait_def.gd  (new): a general's trait (4.11)
class_name TraitDef extends Resource
@export var key: StringName                # &"ranger"
@export var name: String                   # "Ranger"
@export var lines: PackedStringArray       # "+20 % in woods and hills"
@export var icon: StringName
@export var fights: PackedInt32Array       # Combat fight kinds it helps: 0 open, 1 rough, 2 assault / garrison
@export var branch: StringName = &""       # cavalier: &"cavalry"
@export var defending := false
@export var bonus_permille := 200
@export var siege_points := 0
func validate() -> Array[String]           # key form; fights in 0..2; branch "" or known; bonus 0..1000; siege_points 0..6
func plain() -> Dictionary                 # {key, fights, branch, defending, bonus}: Combat's input

# core/defs/research_def.gd  (new): every number of 4.6 to 4.9, one inspector
class_name ResearchDef extends Resource
@export var branches: Array[StringName] = [&"military", &"trade", &"navigation", &"statecraft"]
@export var branch_names: PackedStringArray  # "Military", "Trade & Industry", "Navigation", "Statecraft"
@export var base_milli := 1500
@export var town_milli := 15
@export var by_level: PackedInt32Array      # 6 (settlement levels 0 to 5): 0, 0, 0, 100, 250, 500
@export var bonus_permille := 0
@export var fund_ducats := 80
@export var fund_points := 6
@export var fund_every := 4
@export var fund_bonus_permille := 0
@export var diffusion_permille := 100
@export var diffusion_cap_permille := 300
@export var idle_keep_seasons := 4
@export var idea_cards := 3
@export var idea_top_weight := 3
@export var idea_weight := 1
@export var start_national := true
@export var default_national: StringName = &"local_levies"
func validate(defs: GameDefs) -> Array[String]   # 4 branches and names; counts >= 0; by_level sized 6; permilles 0..2000;
	# fund_every 1..40; idea_cards 1..5; default_national a known national TechDef with nation &""

# core/defs/game_defs.gd  (M2 to M10, edit)
@export var research: ResearchDef = null    # external: data/defs/research.tres
@export var techs: Array[TechDef] = []      # 51, external: data/defs/techs/<key>.tres, in id order
@export var ideas: Array[IdeaDef] = []      # 29, external: data/defs/ideas/<key>.tres
@export var eras: Array[EraDef] = []        # 3, external: data/defs/eras/<n>.tres
@export var traits: Array[TraitDef] = []    # 5, external: data/defs/traits/<key>.tres
@export var know_range := 1                 # Knowledge (4.13)
func tech(id: int) -> TechDef               # null out of range
func tech_id(key: StringName) -> int        # -1 unknown (a dictionary built on first use)
func idea(id: int) -> IdeaDef
func idea_id(key: StringName) -> int
func era(n: int) -> EraDef                  # null out of 1..3
func trait_def(key: StringName) -> TraitDef # null unknown
# validate() adds: research set and valid; techs with ids 0..50 in order, unique keys, each valid; the tree acyclic; every
# national's nation a CountryDef tag or "" once; ideas ids 0..28, unique keys, at most one national card a country; 3 eras 1..3
# with ascending years; 5 traits; 12 units, one kind a branch an era; know_range 1..8

# core/defs/war_def.gd  (M7, M9, edit): generals and refits
@export var general_cost := 100
@export var general_upkeep := 4
@export var general_stack := 2
@export var general_morale_cut_permille := 150
@export var generals_base := 1
@export var generals_per_towns := 2
@export var generals_cap := 4
@export var refit_permille := 500
@export var refit_min_level := 3
# validate() adds: costs >= 0; general_stack 0..6; the cut 0..1000; generals_base <= generals_cap <= 8; generals_per_towns >= 1;
# refit_permille 0..1000; refit_min_level 1..5

# core/defs/unit_def.gd  (M6, M7, edit): validate() era 1..3 (the twelve-kind rule is GameDefs'); figure any "fig_*" icon

# core/defs/ai_temper_def.gd  (M8, M9, M10, edit)
@export var branch_weights: PackedInt32Array   # 4 (ResearchDef.branches order), permille
# mix (M8): 4 by branch (infantry, missile, cavalry, artillery), the same values; validate(): mix sized 4; branch_weights sized 4,
# each 100..5000

# core/defs/ai_def.gd  (M8 to M10, edit): the eight fields of 4.17; validate(): permilles 1000..10000; counts 0..8
```

### 5.2 State (`core/state/`)

```gdscript
# core/state/country.gd  (M2 to M10, edit): schema "hexa-godot/country/7" (country/6 refused)
var era: int = 1                          # Research
var techs: PackedInt32Array               # Research: TechDef ids known, in the order learned (the national first)
var tech_turns: PackedInt32Array          # Research: the turn each was learned (0: at the start)
var researching: int = -1                 # Research: a TechDef id, -1 none
var queue: PackedInt32Array               # Research
var progress: int = 0                     # Research: milli-points, the country's (D13)
var research_last: int = 0                # Research: milli-points of the last research phase
var funded_turn: int = 0                  # Research: 0 never
var ideas: PackedInt32Array               # Research: IdeaDef ids, in the order adopted
var idea_turns: PackedInt32Array          # Research
var pending_ideas: PackedInt32Array       # Research: the offer, empty when none
var era_turns: PackedInt32Array           # Research: 3 entries, the turn each era began (era 1: 1; 0 not yet)
func knows_tech(id: int) -> bool
# digest_text() appends "|" + era + "|" + each array joined by "," + "|" + researching + "|" + progress + "|" + research_last +
# "|" + funded_turn, in the order above

# core/state/army.gd  (M6, M7, edit): schema "hexa-godot/army/3" (army/2 refused)
var general: StringName = &""             # a TraitDef key, &"" none; Armies only
func mustering(turn: int) -> bool         # M6's, and a unit with refit_turn == turn
# digest_text() appends "|" + general

# core/state/unit.gd  (M6, M7, edit): schema "hexa-godot/unit/3" (unit/2 refused)
var refit_turn: int = 0                   # Armies: the turn it was last refitted, 0 never
# digest_text() appends "|" + refit_turn

# core/state/battle_record.gd  (M7, edit): schema "hexa-godot/battle-record/2" (/1 refused)
var generals: PackedStringArray           # [attacker's trait, defender's trait], "" none; BattleEnd writes it
# to_dict, from_dict carry it; digest_text() appends "|" + both traits joined by ","

# core/state/stats.gd  (M3 to M10, edit): SERIES appends "techs", "era" (60)

# core/game/game.gd  (M1 to M10, edit; the fields)
var mods: ModsCache = ModsCache.new()     # the door's derived per-country definitions; not saved, not in the digest
```

### 5.3 Systems (`core/systems/`)

```gdscript
# core/systems/mods_cache.gd  (new): derived, built on demand, never saved. Called as game.mods.<func>(game, tag).
class_name ModsCache extends RefCounted
func defs_for(game: Game, tag: StringName) -> GameDefs   # 4.2
func effects_for(game: Game, tag: StringName) -> Array[ModDef]
func forget(tag: StringName) -> void
func clear() -> void
func built() -> int                                      # countries held (F3)

# core/systems/research.gd  (new): points, costs, the queue, the phase, eras, ideas
class_name Research extends RefCounted
const OWNS: Array[String] = ["era", "techs", "tech_turns", "researching", "queue", "progress", "research_last", "funded_turn",
	"ideas", "idea_turns", "pending_ideas", "era_turns"]
static func setup(game: Game) -> void                     # new_scenario: era 1, era_turns [1, 0, 0]; the national (and its
	# also_knows) at turn 0 when start_national; researching = cheapest_available; nothing in a map-only game
static func national_of(game: Game, tag: StringName) -> TechDef
static func rate(game: Game, tag: StringName) -> int      # 4.7
static func rate_parts(game: Game, tag: StringName) -> Dictionary   # {base, towns, people, levels, counts: PackedInt32Array (by
	# level), bonus_permille, funding, total}
static func partners(game: Game, tag: StringName) -> Array[StringName]   # 4.8
static func cost(game: Game, tag: StringName, tech: int) -> int          # 4.8
static func diffusion(game: Game, tag: StringName, tech: int) -> Dictionary   # {permille, partners: Array[StringName]}
static func available(game: Game, tag: StringName) -> PackedInt32Array    # tree techs unknown, needs known, era <= era; id order
static func cheapest_available(game: Game, tag: StringName) -> int        # -1 none
static func path_to(game: Game, tag: StringName, tech: int) -> PackedInt32Array
static func dependants(game: Game, tag: StringName, tech: int) -> PackedInt32Array   # in its queue
static func era_ready(game: Game, tag: StringName) -> bool
static func gate_state(game: Game, tag: StringName) -> Dictionary         # {next: int (0 none), year, year_ok, need, known}
static func seasons_left(game: Game, tag: StringName) -> int              # to finish researching at this rate; -1 none
static func known_points(game: Game, tag: StringName) -> int              # the costs of its known tree techs (M12's score part)
static func learn(game: Game, tag: StringName, tech: int, why: StringName) -> void
static func step_era(game: Game, tag: StringName, why: StringName) -> void
static func draw_ideas(game: Game, tag: StringName) -> PackedInt32Array   # 4.6; draws luck.world
static func set_research_check(game: Game, args: Dictionary) -> Dictionary     # {tech, tag}; 4.12
static func set_research(game: Game, args: Dictionary) -> Dictionary
static func queue_research_check(game: Game, args: Dictionary) -> Dictionary
static func queue_research(game: Game, args: Dictionary) -> Dictionary
static func unqueue_research_check(game: Game, args: Dictionary) -> Dictionary
static func unqueue_research(game: Game, args: Dictionary) -> Dictionary
static func fund_research_check(game: Game, args: Dictionary) -> Dictionary    # {tag}
static func fund_research(game: Game, args: Dictionary) -> Dictionary
static func pick_idea_check(game: Game, args: Dictionary) -> Dictionary        # {idea, tag}
static func pick_idea(game: Game, args: Dictionary) -> Dictionary
static func season(game: Game) -> void                                          # the research phase (4.9)

# core/systems/generals.gd  (new)
class_name Generals extends RefCounted
const OWNS: Array[String] = []                    # writes through Armies and Treasury
static func max_of(game: Game, tag: StringName) -> int
static func count(game: Game, tag: StringName) -> int
static func of_side(game: Game, tag: StringName, hex: Vector2i) -> TraitDef    # the trait of its army with the most men there
static func appoint_general_check(game: Game, args: Dictionary) -> Dictionary  # {army, trait, tag}; 4.11
static func appoint_general(game: Game, args: Dictionary) -> Dictionary
static func dismiss_general_check(game: Game, args: Dictionary) -> Dictionary  # {army, tag}
static func dismiss_general(game: Game, args: Dictionary) -> Dictionary

# core/systems/armies.gd  (M6, M7, edit): the door gains
static func set_general(game: Game, army: Army, trait: StringName) -> void
static func refit_units(game: Game, army: Army, ids: PackedInt32Array, kinds: PackedInt32Array, turn: int) -> void
# remove(): general_lost for an army with a general (why from the caller: lost, surrendered)

# core/systems/military.gd  (M6, M7, edit)
static func unit_def(game: Game, kind: int, tag: StringName = &"") -> UnitDef   # defs_of(tag)
static func cost_of(game: Game, kind: int, count: int, tag: StringName = &"") -> Dictionary
static func stack_limit(game: Game, tag: StringName) -> int                      # defs_of(tag).stack_limit
static func stack_limit_at(game: Game, tag: StringName, hex: Vector2i, with_general: bool = false) -> int
static func kind_of(game: Game, tag: StringName, branch: StringName) -> int      # the branch's kind of the country's era
static func later_options(game: Game, tag: StringName, hex: Vector2i) -> Array[Dictionary]   # the next era's kinds, raise_options'
	# rows with their row 6b verdict; [] at the last era
static func refit_cost(game: Game, army: Army) -> Dictionary                     # {ducats, goods: {key: n}, ids, kinds}
static func refit_check(game: Game, args: Dictionary) -> Dictionary              # {army, tag}; 4.10
static func refit(game: Game, args: Dictionary) -> Dictionary
# can_stand(game, tag, hex, adding, leaving, with_general := false): the limit is stack_limit_at; raise_options: the era's four (4.10);
# raise_check row 6b; merge_check's general row; merge_armies passes the general; upkeep_of adds general_upkeep; disband of a
# whole army dismisses its general

# core/systems/supply.gd, supply_cache.gd, vision.gd, sight_cache.gd  (M6, edits): 4.14; SupplyCache and SightCache gain nothing
#   but the forget calls through Game.emit; Supply.food_need(game, men, tag := &"")
# core/systems/combat.gd, battles.gd, battle_end.gd, occupation.gd, sieges.gd  (M7, edits): 4.11, 4.14; Battles.input_of adds
#   wars and generals; BattleEnd writes BattleRecord.generals
# core/systems/economy.gd, economy_season.gd, district_cache.gd  (M4, edits): 4.14;
#   DistrictCache.forget_land(game: Game, tag: StringName) -> void   # forgets every hex the country owns
# core/systems/people.gd  (M5, edit), works.gd  (M3, edit: cost_of(game, action, family, level_to, tag := &"")): 4.14
# core/systems/war_goals.gd (goal_of(..., by_id := 0)), peace.gd, brakes.gd, unrest.gd  (M9, edits): 4.14
# core/systems/trade.gd, trade_cache.gd, merchants.gd  (M10, edits): 4.14
# core/systems/treasury.gd  (edit): WHY appends &"research", &"general", &"refit" (20); SPENDING appends the same three
# core/systems/stores.gd  (edit): FLOWS appends &"refit" (10)
# core/systems/stats_system.gd  (edit): research, techs, era (4.20)
# core/systems/vision.gd  (edit): SIGHTED gains the three of 4.16
```

**OWNS after M11** (`tests/core/test_owns.gd` diffs `Snapshot.of` around every action and phase):

| Field | Written by | In an action | In a phase |
|---|---|---|---|
| the twelve research fields of `Country` | `Research` | `set_research`, `queue_research`, `unqueue_research`, `fund_research`, `pick_idea` | `research` |
| `armies` (and `general`, unit kinds and `refit_turn`) | `Armies` | M6 to M10's; `appoint_general`, `dismiss_general`, `refit`, `merge_armies` (the general) | M6 to M10's (lost generals with their armies) |
| `treasury`, ledgers | `Treasury` | M10's; `fund_research`, `appoint_general`, `refit` | `income` (generals' upkeep in `upkeep_army`); M10's |
| `stock`, flows | `Stores` | M10's; `refit` | M10's |
| `luck` | drawn through `Rng` | no | `battles`, `calendar`, `research` |
| `stats` | `StatsSystem` | no | `stats` (the three series) |
| everything of M10's table | as M10 5.3 | | |
| `events`, `action_log`, `chronicle`, `version`, `view_cache`, `districts`, `sight`, `supplies`, `war_cache`, `diplo_cache`, `steps`, `trade_cache`, `mods` | `Game` (`DOOR_FIELDS` gains `mods`) | yes | yes |

### 5.4 Game, the action table, the season, saves (`core/game/`)

```gdscript
# core/game/game.gd  (M1 to M10, edit)
const DOOR_FIELDS: Array[String] = ["events", "action_log", "chronicle", "version", "view_cache", "districts", "sight",
	"supplies", "war_cache", "diplo_cache", "steps", "trade_cache", "mods"]
func defs_of(tag: StringName) -> GameDefs          # mods.defs_for(self, tag)
func emit(event: Dictionary) -> void               # M10's, plus: tech_learned and idea_adopted -> mods.forget(tag) and the
	# forgets of the tech's or idea's keys (4.2)
func dev_tech(tag: StringName, tech: int) -> bool  # logged {turn, action: "dev_tech", args}; Research.learn(why dev); false for
	# an unknown tag or tech, or one known
func dev_research(tag: StringName, milli: int) -> bool   # logged; Research's writer adds to progress (at least 0 after)
func dev_era(tag: StringName) -> bool              # logged; Research.step_era(why dev) when a next era exists
# new_scenario: after Trade.setup: Research.setup
# digest(): M10's string (the countries' digest_text carry the research; armies the general)

# core/game/actions.gd  (M3 to M10, edit)
const NAMES: Array[String] = [... M10's thirty ..., "set_research", "queue_research", "unqueue_research", "fund_research",
	"pick_idea", "appoint_general", "dismiss_general", "refit"]
# pair_of: the first five -> Research's; the two generals -> Generals'; refit -> Military's

# core/game/season.gd  (M3 to M10, edit)
const PHASES: Array[StringName] = [&"ai_orders", &"movement", &"battles", &"supply", &"sieges", &"war", &"relations",
	&"production", &"trade", &"income", &"works", &"people", &"research", &"stats", &"calendar", &"ready_units", &"vision"]
# run_phase(research): Research.season

# core/game/replay.gd  (edit): plays dev_tech, dev_research, dev_era through Game
# core/game/snapshot.gd  (edit): country/7, army/3, unit/3, battle-record/2; restore type-checks every new field (tech and idea ids
#   in range, traits known) and refuses the older schemas; game.mods empty
# core/game/save_file.gd  (edit): FORMAT := 9; OLDEST_FORMAT := 9
```

### 5.5 Events and Session (`shell/autoload/`)

```gdscript
# shell/autoload/events.gd  (edit): added signals
signal tech_learned(tag: StringName, tech: int)
signal era_reached(tag: StringName, era: int)
signal ideas_offered(tag: StringName, ideas: PackedInt32Array)
signal idea_adopted(tag: StringName, idea: int)
signal research_set(tag: StringName, tech: int)
signal research_funded(tag: StringName, milli: int)
signal research_idle(tag: StringName)
signal general_appointed(tag: StringName, army: int, trait: StringName)
signal general_dismissed(tag: StringName, army: int)
signal general_lost(tag: StringName, army: int, trait: StringName)
signal army_refitted(tag: StringName, army: int, count: int)

# shell/autoload/session.gd  (edit): drain() sends the eleven kinds to their signals, then chronicled (M3) for the notable;
#   last_phase_ms gains research; dev_tech(tag, tech), dev_research(tag, milli), dev_era(tag) -> bool (the console; drain)
```

### 5.6 Views (`core/views/`, pure)

```gdscript
# core/views/knowledge.gd  (M3 to M10, edit): knows() and know_range (4.13)
static func techs_seen(game: Game, viewer: StringName, other: StringName) -> PackedInt32Array   # empty when not known
static func ideas_seen(game: Game, viewer: StringName, other: StringName) -> PackedInt32Array
static func era_seen(game: Game, viewer: StringName, other: StringName) -> int                  # 0 when not known

# core/views/words.gd  (M3 to M10, edit)
static func points(milli: int) -> String                 # "2.4" (floored to a tenth); "6" when whole
static func tech_name(game: Game, tech: int) -> String
static func idea_name(game: Game, idea: int) -> String
static func era_name(game: Game, era: int) -> String     # "the Age of Arquebus"
static func kinds_text(game: Game, era: int) -> String   # "landsknechts, arquebusiers, lancers and culverins"
static func trait_name(game: Game, key: StringName) -> String   # "Ranger"
static func branch_name(game: Game, branch: StringName) -> String

# core/views/tech_layout.gd  (new): the pure port of techlayout.py (6.3)
class_name TechLayout extends RefCounted
const COLS_PER_ERA := 2
const ROWS_PER_BRANCH := 2
const NODE_MIN := Vector2(140, 54)          # read by TechNode._get_minimum_size
const SIDE_MIN := 270.0
const SIDE_SHARE := 0.22                    # of the screen's width, 270 to 340
static func cells(game: Game, viewer: StringName) -> Dictionary
	# Vector2i(branch index, era) -> PackedInt32Array: tree techs in id order, the viewer's national last in era 1
static func slots(game: Game, viewer: StringName) -> Dictionary
	# tech id -> Vector2i(column 0..5, row 0..7): column (era - 1) * 2 + i % 2, row branch * 2 + i / 2
static func links(game: Game, viewer: StringName) -> Array[Dictionary]   # {from, to, cross: bool, on_path: bool}
static func state_of(game: Game, viewer: StringName, tech: int) -> StringName
	# &"known", &"researching", &"queued", &"available", &"blocked", &"later" (techlayout.tech_state)
static func order_of(game: Game, viewer: StringName) -> Dictionary      # tech -> 0 researching, 1.. queued
static func move(slots: Dictionary, from_tech: int, step: Vector2i) -> int
	# the keyboard: the nearest occupied slot in the step's direction (within the column first, then the next column); from_tech
	# when none
static func who_has(game: Game, viewer: StringName, tech: int) -> Array[StringName]   # known countries knowing it, id order

# core/views/research_view.gd  (new): the tech screen's model
class_name ResearchView extends RefCounted
static func screen(game: Game, viewer: StringName) -> Dictionary
	# {title "Technology", sub ("Republic of Genoa · Summer 1523 · Age of Arquebus"), rate: {text "+2.4 a season", parts:
	#  [{id, label, value_text}]}, fund: {verdict, label "Fund research +6", cost_text "80 ducats"}, strip: {tech, name, icon,
	#  progress (permille), text "62 / 170 · about 30 seasons", empty_text "Nothing is being researched: click a tech."},
	#  queue: [{tech, name, icon}] (5 shown), more_text "+2 more", hint, eras: [{era, roman, name, status_text ("reached 1480" |
	#  "1520 · 3 of 4 era I techs"), locked, troops_text}], branches: [{branch, name, icon, known_text "3 / 11 known"}],
	#  nodes: [{tech, slot, name, icon, line, state, cost_text, progress, order, needs_text ("needs Corned powder"),
	#  national_text}], links, legend: [{state, label}], ideas_pending: bool}
	# cached [&"tech_screen", version, viewer]
static func side(game: Game, viewer: StringName, tech: int) -> Dictionary
	# {tech, name, icon, branch_text "Trade & Industry · era II", status_text ("RESEARCHING 62 / 170", "AVAILABLE · 170",
	#  "LATER AGE · 170", "LOCKED: needs Guilds", "KNOWN since Spring 1502"), status_tone, flavour, brings: lines, needs:
	#  [{tech, name, known}], leads_to: [{tech, name}], who_has: {names, diffusion_text}, research: {verdict, label ("Research",
	#  "Research it and 2 before it")}, queue: {verdict}, unqueue: {verdict, shown}}
static func chip(game: Game, viewer: StringName) -> Dictionary
	# {value, of, change (points a season, rounded), idle: bool}: the Research chip

# core/views/idea_view.gd  (new): the idea pick's model
class_name IdeaView extends RefCounted
static func offer(game: Game, viewer: StringName) -> Dictionary
	# {} none; else {date_text "SPRING 1520 · A NEW AGE", era_name, lines (what the era opens), cards: [{idea, name, branch,
	#  branch_name, icon, lines, national: bool, nation_text "GENOA · NATIONAL", take: {verdict}}], hint}

# core/views/cards_research.gd  (new): hover cards
class_name ResearchCards extends RefCounted
static func chip(game: Game, viewer: StringName) -> Dictionary     # {title, lines (researching, the parts, the next era), hint
	# "T: the technology screen"}
static func tech(game: Game, viewer: StringName, tech: int) -> Dictionary
static func idea(game: Game, viewer: StringName, idea: int) -> Dictionary
static func trait_card(game: Game, key: StringName) -> Dictionary

# core/views/study_research.gd  (new): the Research page (6.6)
class_name StudyResearch extends RefCounted
static func of(game: Game, viewer: StringName, span: int) -> Dictionary
	# {points: {series: PackedInt32Array (Stats research, milli), labels, marks: [{turn, kind (&"tech" | &"era"), text}]},
	#  parts: [{label, value_text}], branches: [{branch, name, known, total, by_era: PackedInt32Array}], age: {name, next_name,
	#  year_text, year_ok, techs_text, techs_ok, progress}, ideas: [{name, when, lines}], countries: [{tag, name, era_name,
	#  techs, ideas, national}], unknown_text, empty texts}
	# cached [&"study_research", version, viewer, span]

# core/views/country_card.gd  (M2 to M10, edit): research: own {era_text, researching_text, rate_text, techs_text, ideas_text,
#   open: [&"tech"]}; a known other {era_text, techs_text "4 techs: Banking, Guilds and 2 more", national_text, ideas_text}
# core/views/hex_card.gd  (edit): research_line on an own settlement: "Learning +0.7 a season (30,300 people, a walled town)"
# core/views/army_view.gd  (M6, edit): panel gains general: {trait, text, places_text "1 of 2 generals in the field", appoint:
#   {verdict, traits: [{key, name, lines, verdict}], cost_text}, dismiss: {verdict}}, refit: {count, text "3 companies of the Age of
#   Pikes: refit as landsknechts and arquebusiers", cost_text "47 · 3 iron", verdict}; raise options by era (4.10)
# core/views/battle_view.gd  (M7, edit): side.general_text from the record: "General: Ranger" / "No general"; general_lines
# core/views/odds_view.gd  (M7, edit): general_text for each side the viewer may see ("Your general: Field marshal (+20 % on open
#   ground)")
# core/views/study_military.gd, study_history.gd  (edits): 4.21
# core/views/season_summary.gd, log_lines.gd, reminders.gd  (edits): 4.16, 4.20
```

### 5.7 The AI (`core/ai/`, M8 to M10, edits)

```gdscript
# core/ai/ai_know.gd  (edit): the door gains
static func defs(game: Game, tag: StringName) -> GameDefs                          # game.defs_of(tag)
static func research_of(game: Game, tag: StringName) -> Dictionary                 # own: {era, researching, queue, progress,
	# pending: PackedInt32Array, funded_turn, gate: Research.gate_state}
static func tech_options(game: Game, tag: StringName) -> Array[Dictionary]         # {tech, branch, era, cost} of Research.available
static func ideas_offered(game: Game, tag: StringName) -> Array[Dictionary]        # {idea, branch, national}
static func kind_of(game: Game, tag: StringName, branch: StringName) -> int
static func general_room(game: Game, tag: StringName) -> int                       # max_of - count
static func general_cost(game: Game, tag: StringName) -> int
static func refit_options(game: Game, tag: StringName) -> Array[Dictionary]        # {army, ducats, goods} where refit_check allows
# core/ai/ai_brief.gd  (edit): defs, research
# core/ai/ai_turn.gd  (edit): the research step after trade; var research_scripts: Dictionary = {}
# core/ai/ai_forces.gd  (edit): appoint, refit, the mix by branch (4.17)
# core/ai/ai_economy.gd  (edit): prior() reads brief.defs
# core/ai/ai_research.gd  (new): AiResearch.research(turn, game, brief, arg) (4.17)
```

### 5.8 The data-only rule (`tests/core/test_research_data_only.gd`)

The scan covers `core/systems/`, `core/game/`, `core/ai/` and `core/views/`. Files allowed to read `Country.techs`, `ideas`,
`pending_ideas`, `GameDefs.techs`, `ideas` and the classes `TechDef`, `IdeaDef`, `ModDef`: `core/defs/*`, `core/state/country.gd`,
`core/systems/research.gd`, `core/systems/mods_cache.gd`, `core/game/game.gd`, `core/game/snapshot.gd`, `core/ai/ai_know.gd`, and
the display views that show research but compute no rule: `core/views/knowledge.gd`, `words.gd`, `research_view.gd`,
`tech_layout.gd`, `idea_view.gd`, `cards_research.gd`, `study_research.gd`, `country_card.gd`, `season_summary.gd`, `log_lines.gd`,
`reminders.gd`. Every other view (the previews, the odds, the map modes, the army and battle views) is scanned like a system. No file
of `core/` holds a tech or idea key as a string literal outside `core/defs/` (the default national's key in `research_def.gd` is the
one). Everything else reads numbers through `game.defs_of`.

---

## 6. The UI of M11

Built from the M1.5 kit and the M3 to M10 pieces. Colours and fonts from the Theme; HUD controls take no focus, screens do. The App's
milestone value becomes `"11"`, so `game_tech` (T) registers and shows. The layouts follow `docs/design/images/14_tech_tree_c.png`
and `14_tech_tree_d_new_age.png` (the approved mockups), re-drawn in the Studiolo kit.

### 6.1 Keys and settings

| Action (`Bindings.DEFAULTS`) | Key (Mac) | Since | Who hears it | Does |
|---|---|---|---|---|
| `game_tech` (exists) | T | 11 | `MapInput.tech_requested` (**new signal**); inside the screen `TechScreen` itself | opens the tech screen; T or Esc closes it; in the sandbox "no countries on this map"; in a watched game "Choose a country to see its research." |

Inside the tech screen (the screen's own keys, not bindings): **arrows** move the selection over the grid (`TechLayout.move`);
**Enter** researches the selected tech (`set_research`); **Shift+Enter** queues it (`queue_research`); **Delete** or **Backspace**
removes it (`unqueue_research`); **Home** selects the current research; **Tab** walks the side card's buttons, Fund research and Close.
Inside the idea pick: **Left**, **Right** move between the cards' Take buttons; **Enter** takes; **Esc** decides later. No settings key
is added (`state/study_page` lists `research`; the page's span is `state/study_span`).

### 6.2 Bake slice 9: the research pieces (`tools/ui_bake/pieces_m11.py`, new)

| Texture | Size (1x) | What |
|---|---|---|
| `icons_research` (atlas, 24 px cells) | 240 x 120 | the 30 tech icons of 4.3; `branch_military`, `branch_trade`, `branch_navigation`, `branch_statecraft`; `era`, `idea`, `fund`, `queue`, `lock_era`, `national`; `trait_field`, `trait_ranger`, `trait_siege`, `trait_defender`, `trait_cavalier`; `refit`, `general` (47 cells, 3 spare) |
| `figures_eras` (atlas, 32 px cells) | 256 x 32 | `fig_infantry_2` (a landsknecht with pike and slashed doublet), `fig_missile_2` (an arquebusier), `fig_cavalry_2` (a lancer), `fig_artillery_2` (a culverin), `fig_infantry_3` (a pikeman in a morion), `fig_missile_3` (a musketeer at a rest), `fig_cavalry_3` (a cuirassier), `fig_artillery_3` (a field gun on wheels) |

`build_theme.gd` adds them as `Kit` icons and the variations `TechNodeKnown`, `TechNodeResearching`, `TechNodeQueued`,
`TechNodeAvailable`, `TechNodeBlocked`, `TechNodeLater`, `IdeaCard` (+ `IdeaCardNational`) and `TechLinks` (colours `line`,
`line_path`, `line_cross`) from tokens. `shell/ui/tokens.gd` gains `BRANCH_MILITARY #b5473a` (madder), `BRANCH_TRADE #c49a3a` (ochre),
`BRANCH_NAVIGATION #3f6fa8` (lapis), `BRANCH_STATECRAFT #7a4f9a` (purpure), `TECH_PATH #e8c15a` (GOLD's value) (the bake re-runs:
`tokens_sha`). The art director signs the research sheet (`bake_ui.py --sheet`): the 47 icons and 8 figures at 1x and 2x, a node in
each state, an idea card of each branch.

### 6.3 The tech screen (`shell/screens/tech.tscn/.gd`, new; `OPAQUE`)

```gdscript
class_name TechScreen extends Screen            # kind OPAQUE, screen_id &"tech"; ResearchView.screen(Session.game, you)
func select(tech: int) -> void                  # the side card shows it; the node takes focus
func selected() -> int
func refresh() -> void
# shell/screens/tech/tech_node.tscn/.gd  (new): class_name TechNode extends Button; func show_node(n: Dictionary) -> void;
#   signal right_clicked(tech: int); its variation by state; _get_minimum_size() TechLayout.NODE_MIN
# shell/screens/tech/tech_links.gd  (new): class_name TechLinks extends Control; func set_links(links: Array[Dictionary],
#   rects: Dictionary) -> void; draws in _draw(): solid within a branch, dashed across (draw_dashed_line), gold on the path
# shell/screens/tech/tech_side.tscn/.gd  (new): class_name TechSide extends PanelContainer; func show_side(s: Dictionary) -> void
```

| Part | Built from | Content |
|---|---|---|
| Frame | `PanelFrame` full rect, the walnut band | a `Cartouche` "Technology" and the sub line in `Hint` |
| Top band | `HBoxContainer` of `DeltaChip`s and `Hint` labels | "Research +2.4 a season", then the parts "Base 1.5 · Towns 0.6 · Settlements by level 0.3 · ×1.00 · Funding 0"; **Fund research +6** (`KitButton` primary, cost slot "80 ducats", `set_verdict(Session.check("fund_research", {}))`); **Close** with a `KeyCap` of T |
| Strip | `HBoxContainer` | the icon tile, "RESEARCHING" in `Hint`, the name, a `ProgressBar` (the Theme's `progress_fill`), "62 / 170 · about 30 seasons"; "QUEUE" and up to five `KitButton`s (toggle style, icon and name; a click selects, a right click removes), "+2 more"; the hint "Click a tech to research it and its path. Shift+click queues it. Right click or Delete removes it." |
| Era heads | an `HBoxContainer`: a spacer as wide as the branch labels, then three `VBoxContainer`s with equal stretch | "I Age of Pikes" (`Display`), "reached 1480"; "II Age of Arquebus", "1520 · 3 of 4 era I techs" with the `lock_era` icon while locked; "troops: pikemen, crossbowmen, knights, bombards" |
| Grid | a `ScrollContainer` holding a `VBoxContainer` of four branch rows, `TechLinks` behind them; a branch row is an `HBoxContainer`: its label, then three era cells with the heads' stretch, each a `GridContainer` of 2 columns | branch labels: the branch icon on a `Medallion`, the name, "3 / 11 known"; a `TechNode` at each slot of `TechLayout.slots` (column `i % 2`, row `i / 2` of its cell), an empty `Control` where a cell holds fewer; the node: icon tile, name, line, then the state's foot ("known ✓", a progress bar and "62 / 95", "queued #2 · 170", "170", "needs Corned powder" in `BAD`, faint "380"); a national node carries the gold tag |
| Side card | `TechSide` (a `VellumSheet` in a card frame, `SIDE_SHARE` of the width) | icon, name, "Trade & Industry · era II", the status line in its tone, the flavour (Alegreya italic), **Brings** (the lines), **Needs** (each with ✓ or ✗), **Leads to**, **Who has it** (names of known countries and the diffusion line), **Research** (primary, its verdict; "Research it and 2 before it"), **Queue** (secondary), **Remove from the research** (shown when queued) |
| Legend | a `HBoxContainer` at the foot | known, researching, queued, available, needs a prerequisite, later era; solid line, dashed cross-branch, gold your path |
| Idea banner | a `HBoxContainer` over the strip while an offer is pending | "Choose your idea for the Age of Arquebus." with **Choose** (opens the idea pick) |

A click on a node selects it and asks `set_research` (a later-era node toasts its reason); Shift+click asks `queue_research`; a right
click asks `unqueue_research`. At 1280 x 720 (scale 1) the eight rows of nodes take 4 × (2 × 54 + 8 + 12) = 512 px under about 180
px of bands; when the window is smaller the grid scrolls (the wheel inside it never zooms the map: the map is paused under an opaque
screen).
Refreshes on `tech_learned`, `research_set`, `research_funded`, `era_reached`, `ideas_offered`, `idea_adopted`, `season_ended` and a
newer `game.version`. T and Esc close it (the ladder's top-screen step).

### 6.4 The idea pick (`shell/screens/idea_pick.tscn/.gd`, new; `MODAL`, 900 x 600)

```gdscript
class_name IdeaPick extends Screen              # kind MODAL, screen_id &"idea_pick"; IdeaView.offer(Session.game, you)
func show_offer() -> void
# shell/screens/tech/idea_card.tscn/.gd  (new): class_name IdeaCard extends PanelContainer; func show_card(c: Dictionary) -> void;
#   signal taken(idea: int); variation IdeaCard or IdeaCardNational; the band in the branch's colour
```

| Part | Content |
|---|---|
| Frame | `ModalFrame` with the `Ribbon` "A new age" |
| Head | "SPRING 1520 · A NEW AGE" (`Hint` caps), "The Age of Arquebus" (`Display`, GOLD) |
| Lines | "Landsknechts, arquebusiers, lancers and culverins can now be raised. Refit your companies in a town of yours.", "Era II techs are open. Choose one idea to keep:" |
| Cards | three `IdeaCard`s: the branch's band with its icon at 48 px, the branch name in caps ("TRADE & INDUSTRY", "GENOA · NATIONAL" in gold), the name (`Display`), the lines, **Take** (`KitButton`, `set_verdict(Session.check("pick_idea", {idea}))`) |
| Foot | "One card is always your nation's; the other two lean to the branch you study most." and **Decide later** (Esc) |

Take acts `pick_idea`, toasts "Idea adopted: Humanism. Research +10 %." and closes. Opened by `DecisionQueue` in `DECISIONS`, the tech
screen's banner, the reminder's Choose and the console. Closes itself on `idea_adopted` for the player.

### 6.5 The Research chip and the hover cards

**The Research chip** (`shell/hud/chips.tscn/.gd`, M4 to M10, edit): a `ResourceChip` (icon `research`) after Army: `set_fraction(12,
80, 2)` (points toward the current tech of its cost, the rate rounded as its change); idle: "—" in `WARN` (`set_fraction(0, 0, 0)`
shows "—": a `ResourceChip` edit); its hover `ResearchCards.chip` ("Researching Double-entry books: 12 of 80, about 28 seasons";
"Points a season 2.4: base 1.5, towns 0.6, settlements by level 0.3"; "The Age of Arquebus: 1520 and 4 era I techs (2 known)"); a click opens
the tech screen. Narrowing: it hides first, before Merchants. Order: Ducats, People, Food, Army, **Research**, Weariness (when over 0),
Stores, Merchants.

**Hover cards**: a node (`ResearchCards.tech`: name, line, cost "170 points: about 70 seasons at your rate", state, "needs ..."); an
idea card (`ResearchCards.idea`); a trait in the army panel (`ResearchCards.trait_card`).

### 6.6 The Research page (`shell/screens/study/page_research.tscn/.gd`, new)

`PageResearch extends StudyPage`, from `StudyResearch.of(game, you, span)`:

| Part | Built from | Reads |
|---|---|---|
| Points | `SectionHead` "Research"; an `InkChart` `LINE` on a `PanelVellumInset`: points a season (`Stats.research`), marks for techs learned (good) and ages (gold); caption "Research points a season, the last 12 seasons"; the span `Segmented` "12 seasons \| 40 seasons" (`state/study_span`) | `points` |
| Where the points come from | a `StudyTable`: Source, A season: "Base 1.5", "Towns (40,400 people) 0.6", "Settlements by level 0.3", "Bonus ×1.15", "Funding this season 6", the total | `parts` |
| Techs by branch | a `StudyTable`: Branch (icon), Known (of), Era I, Era II, Era III; a row's Enter opens the tech screen | `branches` |
| The age | "Age of Pikes → Age of Arquebus": "1520 (in 12 seasons)" and "4 era I techs (3 known)" each with ✓ or ✗ and a `ProgressBar` of the count; "The last age" when at era III | `age` |
| Your ideas | a line each: "Humanism (Spring 1520): research +10 %." | `ideas` |
| Known countries | a `StudyTable`: Country (`CountryArms` and name), Age, Techs known, Ideas, National tech; "2 countries unknown" | `countries`, `unknown_text` |
| Foot | **Open the technology screen (T)** | |

Empty states: "No tech learned yet: the first comes with Crop rotation in about 24 seasons.", "No idea yet: the first comes with the
Age of Arquebus.", "You know no other country yet." Refreshes on `season_ended`, `tech_learned`, `era_reached`, `idea_adopted`.

### 6.7 The panels (edits)

- **Country panel** (`shell/panels/country_panel.tscn/.gd`): a **Research** section from `CountryCard.of(...).research`: yours "Age of
  Pikes · Researching Crop rotation: 12 of 70 · 2.4 a season · 3 techs · no idea yet" with **Open the technology screen**; a known
  other's "Age of Arquebus · 14 techs: Banking, Guilds and 12 more · national: Banco di Rialto · ideas: Arsenal of Venice".
- **Army panel** (`shell/panels/army_panel.tscn/.gd`, M6, M7): a **General** row from `ArmyView.panel(...).general`: "General: Ranger
  (+20 % in woods and hills)" with **Dismiss** (its verdict), or "No general · 1 of 2 in the field" with a `Segmented` of the five trait
  icons (the selected trait's lines in `Hint`) and **Appoint · 100** (`Session.act("appoint_general", {army, trait})`); a **Refit**
  row: "3 companies of the Age of Pikes: refit as landsknechts and arquebusiers" with **Refit · 47 · 3 iron** (`set_verdict`); the
  Companies rows show the stack "4 of 10 companies here" with the general's +2.
- **Raise tab** (`shell/panels/raise_list.tscn/.gd`, M6): the four kinds of your era, then the next era's four greyed with their reason.
- **Hex panel** (`shell/panels/hex_panel.tscn/.gd`): on your settlement the line "Learning +0.7 a season (30,300 people, a walled town)".
- **Battle dock** (`shell/screens/battle_dock.tscn/.gd`, M7): the face-off's general text from `BattleView` ("General: Ranger" with the
  trait icon; "No general" greyed).
- **Odds card** (`shell/hud/odds_card.tscn/.gd`, M7): a line "Your general: Field marshal (+20 % on open ground)" when the attacking
  army has one.
- **Military page** (`shell/screens/study/page_military.gd`, M6, M7): the General column.
- **Army tokens** (`shell/map/army_tokens.gd`, M6): the figure of the army's main kind by era (`figures_eras`); a small `general` icon on
  the plate of your army when it has a general (others' generals are not shown, 4.13).

### 6.8 The report, the task flag, notifications, the log, ribbons, toasts

- **The report screen** (`shell/screens/season_report.gd`): draws the `research` section (the nav gains "Research" with its count);
  its lines open the tech screen; the idea line opens the idea pick.
- **Task flag and notifications** (M3): the rules of 4.20 (the actions `[&"tech"]`, `[&"ideas"]`, `[&"army", id]` through
  `ctx.request`); notifications as 4.16's `notify`.
- **The log** (`shell/hud/action_log.gd`): the lines of 4.16; a research line opens the tech screen.
- **Ribbons** (`shell/map/floaters.gd`): the tech's name and "A new age" at the capital; "General" and "Refitted" at the army's hex.
- **Toasts**:

| When | Text |
|---|---|
| Research set | "Researching Banking, then 2 more in the queue." / "Researching Banking." |
| Queued, removed | "Queued Universities: 3 in the queue." / "Removed Universities from the research." |
| Funded | "+6 research points for 80 ducats." |
| An idea taken | "Idea adopted: Humanism. Research +10 %." |
| A general appointed, dismissed | "A Ranger takes command of the Army of Novi: −100 ducats." / "The general of the Army of Novi is dismissed." |
| Refitted | "Refitted 3 companies of the Army of Novi: −47 ducats, −3 iron." |
| A later-era node clicked | "Banking waits for the Age of Arquebus (1520 and 4 era I techs)." |
| T in the sandbox, in a watched game | "no countries on this map" / "Choose a country to see its research." |
| A refusal | its reason |

### 6.9 Decisions (`shell/app/decision_queue.gd`, M7 to M10, edit)

The queue's order in `DECISIONS`: war alerts (M7), peace alerts (M8), offers and leagues (M9), then **ideas**. The App pushes
`{kind: &"ideas_offered", tag, turn}` on `Events.ideas_offered` when the tag is the player's; `next` shows the `IdeaPick` for it (not a
`Confirm`); Esc leaves it pending (the reminder and the tech screen's banner remain); after a load a pending offer shows through the reminder and
the banner, not as a decision. An offer answered elsewhere before it shows is
dropped (`idea_adopted`). At idle (the console's `era`) it shows at once. Save is refused while the flow is in `DECISIONS` (M3 D48).

### 6.10 The App, F3, the console

| Request or event | The App (`shell/app/game_requests.gd`, `app.gd`) |
|---|---|
| `MapInput.tech_requested`, `app_requested(&"tech", {tech})`, the chip's click | push `TechScreen` (`ScreenIds` `tech`), selecting `tech` when given |
| `app_requested(&"ideas")` | push `IdeaPick` when an offer is pending |
| `app_requested(&"set_research" \| &"queue_research" \| &"unqueue_research", {tech})`, `(&"fund_research")`, `(&"pick_idea", {idea})`, `(&"appoint_general", {army, trait})`, `(&"dismiss_general", {army})`, `(&"refit", {army})` | `Session.act` the action; the toast of 6.8 or the refusal |
| `Events.ideas_offered` (the player's) | `DecisionQueue.push` |
| `Events.season_ended` | `StudyWarm` adds `StudyResearch.of` and `ResearchView.screen` |

- **F3** (`shell/hud/debug_overlay.gd`): "research 0.3 ms · mods 13 built · ages I 9 · II 4 · III 0".
- **Console** (`shell/hud/dev_commands.gd`): `tech NAME` (`Session.dev_tech`), `points N` (`dev_research`, N milli-points), `era`
  (`dev_era`), `research NAME`, `queue NAME`, `unqueue NAME`, `fund`, `idea NAME` (`pick_idea`), `general ID TRAIT`
  (`appoint_general`), `dismiss ID`, `refit ID`, each with M6's `as TAG`; problems "no tech NAME", "no idea NAME", "no such trait",
  "no army ID", each a planted fault in its test.
- The App sets the milestone `"11"`.

---

## 7. Data and the editor

| File | Holds | Made by | Checked by |
|---|---|---|---|
| `godot/data/defs/research.tres` (**new**) | `ResearchDef` (5.1, 4.6 to 4.9) | by hand in the inspector (Z4) | `tests/core/test_research_defs.gd` |
| `godot/data/defs/techs/<key>.tres` (**new**, 51) | `TechDef` with its `ModDef` rows as sub-resources (4.3, 4.5) | by hand (Z4); costs tuned by Z25 | `tests/core/test_research_data.gd`: every row of 4.3 and 4.5 |
| `godot/data/defs/ideas/<key>.tres` (**new**, 29) | `IdeaDef` (4.6) | by hand (Z4) | `test_research_data.gd` |
| `godot/data/defs/eras/1.tres` to `3.tres` (**new**) | `EraDef` (4.4) | by hand (Z4) | `test_research_data.gd` |
| `godot/data/defs/traits/<key>.tres` (**new**, 5) | `TraitDef` (4.11) | by hand (Z4) | `test_research_data.gd` |
| `godot/data/defs/units/<key>.tres` (M6, 8 **new**) | 4.10's eight kinds | by hand (Z4) | `tests/core/test_unit_defs.gd` |
| `godot/data/defs/war.tres` (M7, edit) | the generals' and refits' numbers | by hand (Z4) | `tests/core/test_war_defs.gd` |
| `godot/data/defs/game_defs.tres` (edit) | `research`, `techs`, `ideas`, `eras`, `traits`, `know_range` | by hand (Z4) | `GameDefs.validate()` in `test_research_defs.gd` |
| `godot/data/defs/ai.tres`, `tempers/*.tres` (M8 to M10, edit) | 4.17's fields | by hand (Z17); tuned by Z25 | `tests/core/test_ai_defs.gd` |
| `godot/tools/research_tables.gd` (**new**, headless) | prints 4.3 to 4.7 and 4.10 to 4.11 as Markdown from the files, and the registry of 4.2 from `ModKeys` | Z4 | `test_research_data.gd` runs it and compares one row of each table |
| `godot/tools/research_report.gd` (**new**, headless) | 4.19's per-country report | Z23 | `test_research_report.gd` runs 8 seasons of one seed and parses the table |
| `godot/tools/ai_tables.gd` (M8, edit) | the branch weights and the `AiDef` rows | Z17 | `test_ai_defs.gd` |
| `godot/tools/war_report.gd` (M7, edit) | rows with a general of each trait on each side | Z8 | `test_odds.gd` (its run) |
| `godot/assets/ui/kit/` (slice 9) | `icons_research`, `figures_eras` at 1x and 2x | `tools/bake_ui.py` (Z3) | `bake_ui.py --check`, `build_theme.gd --check` in CI |
| `godot/data/README.md` (edit) | the research files | Z4 | |

No map data changes: research reads the settlements and people the map and M5 give. `core/mapgen/fake_map.gd` and `FakeScenario` (M2)
are unchanged: the made-up Europe's countries take the default national tech. The scenario editor (M2) is unchanged.

---

## 8. Speed

`godot/tools/perf_core.gd` (M3 to M10) on the made-up Europe: `PerfFixture.europe_research(seasons)` (**new**, in
`godot/tools/perf_fixture.gd`): M10's `europe_trade` with research on, 20 countries given 10 techs each and 10 in the Age of Arquebus
through `dev_tech` and `dev_era`, 60 generals appointed; `seasons` seasons through `Season.run`. Rows in `godot/tests/perf_core_budget.json`,
nightly, never in GUT:

| Row | Limit | What |
|---|---|---|
| `season_ms` | **440** (M10: 430) | the sixteen phases other than `ai_orders`, worst of 8 seasons |
| `research_ms` | 8 | the research phase: 60 countries, about 600 settlements |
| `mods_cold_ms` | 30 | `defs_of` for every country from cold (a load) |
| `mods_one_ms` | 1 | one country's effective definitions after a tech |
| `tech_screen_view_ms` | 4 | `ResearchView.screen` and `TechLayout`, uncached |
| `study_research_ms` | 8 | `StudyResearch.of`, uncached |
| `production_ms` | 60 (M4) | with owners' definitions and `forget_land` |
| `ai_season_ms` | 3,000 mean (M8) | with the research step, generals and refits |
| `save_mb` | 8 (M3) | with the research fields |

On north Italy the research phase is under 1 ms (`test_research.gd` prints it, asserts nothing on time). `godot/tools/ui/perf_ui.gd`
gains in `perf_ui_budget.json`: `tech_screen_ms` 16 (opened cold, 51 nodes and the links), `tech_links_ms` 4 (one `_draw`),
`idea_pick_ms` 16, `research_page_ms` 16.

**How it stays in budget.** Effective definitions are built once a country and a change (a tech or an idea a season at most), shallow
copies sharing every untouched part; the hot loops (production over hexes, people over hexes, combat over fighters) fetch their
country's definitions once per country or side, never per hex or hit; `forget_land` drops only the owner's hexes. If `production_ms`
fails, the fallback is to keep each country's family table in `DistrictCache` keyed by its `ModsCache` version (S).

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (P).

| File | Cases |
|---|---|
| `tests/core/mods_fixture.gd` (**new**) | `ModsFixture.grant(game, tag, effects)`: a test `TechDef` with these rows appended to a defs copy, known by `tag`, `game.mods.forget(tag)` (the hook tests) |
| `tests/core/research_fixture.gd` (**new**) | `ResearchFixture.off(defs)`, `quick(defs)`, `duo(defs)` (4.18 a), `italy(defs, tag)` (seed 1480, calm, research on) |
| `tests/core/test_research_defs.gd` (**new**); `test_unit_defs.gd`, `test_war_defs.gd`, `test_ai_defs.gd` (edits) | every class's `validate` (P: a cost of 0 on a tree tech, a need of a later era, a national with a cost, an unknown key in a `ModDef`, `scale` on an add-only key, `at` out of range, an era's kinds of two branches, a trait fight of 3, a `by_level` of 5 entries, a mix of 12, a branch weight of 0) |
| `tests/core/test_mod_apply.gd` (**new**) | `value_of` (positive, negative, floors); every op on an int, an array (every entry, `at`), a dictionary entry, a `UnitDef` by branch, a `FamilyDef` by key, `families`; untouched parts shared, touched ones copied (the base never changes: P, a test writing through the copy finds the base unchanged); clamping; `effects_of`'s order; `diff` names exactly the touched paths |
| `tests/core/test_research_data.gd` (**new**) | **done-when 1 (c) and 3**: the tables of 4.3 to 4.6 and 4.10, 4.11 exactly; acyclic (P: a planted cycle); every tree tech reachable from the empty set era by era (P: a need on a missing key); costs monotone by era (P: an era I cost of 170); every national era I with cost 0 and one a country of 1480 (P: two for VEN); every effect key registered with its op; all techs, ideas and nationals at once clamp nothing; `research_tables.gd`'s rows |
| `tests/core/test_mods_cache.gd` (**new**) | `defs_for` equals `ModApply.apply` of `effects_for`; `game.defs` for `&""`, a dead country, a country with none; forgotten on `tech_learned` and `idea_adopted` only (P: a cache never forgotten serves the old number); the forgets of 4.2 called for the touched keys and no others |
| `tests/core/test_research_data_only.gd` (**new**) | **done-when 1 (a)**: the scan of 5.8 (P: a planted file under a temporary path reading `country.techs`, and one holding `"banking"`) |
| `tests/core/test_mod_hooks.gd` (**new**) | **done-when 1 (b)**: the 55 probes of 4.2, each for the granted country and its unmoved neighbour (P: one probe run with a hook reading `game.defs` fails) |
| `tests/core/test_mod_hooks_economy.gd`, `test_mod_hooks_war.gd`, `test_mod_hooks_trade.gd` (**new**); `test_economy.gd`, `test_district_cache.gd`, `test_people.gd`, `test_works.gd`, `test_improve_preview.gd`, `test_military.gd`, `test_movement.gd`, `test_supply.gd`, `test_vision.gd`, `test_combat.gd`, `test_battles.gd`, `test_occupation.gd`, `test_sieges.gd`, `test_war_goals.gd`, `test_goal_view.gd`, `test_peace.gd`, `test_brakes.gd`, `test_unrest.gd`, `test_trade.gd`, `test_trade_cache.gd`, `test_merchants.gd`, `test_knowledge.gd` (edits) | each system's reading sites take the right country's definitions (4.14); `forget_land` drops only the owner's hexes; the catchment with two reaches; the free traders keep the base route cost while a merchant pays its own; every earlier pin green on `ResearchFixture.off` |
| `tests/core/test_research.gd` (**new**) | **done-when 5**: every row of the five checks (P each); a path queued; replace and append; unqueue with dependants and of the current research; overflow in one phase; the idle keep; funding's points, interval, ducats; `research_set` and `research_funded` events; the phase on fixtures step by step |
| `tests/core/test_research_rate.gd` (**new**) | **done-when 4**: 4.7's table on seed 1480; owned and controlled settlements only (an occupied town counts for neither: P); the parts add to the total; the duo's rates and turns (4.18 a); diffusion over markets and one route (P: a partner two routes away counts nothing); the cap with Habsburg marriages |
| `tests/core/test_era_gate.gd` (**new**) | the year and the count both needed (P: a national tech counted); one step a season; `era_turns`; the quick fixture's turn 13 (4.18 b); the lapsed offer |
| `tests/core/test_research_ideas.gd` (**new**) | the draw: the national first; weights 3 and 1; no card twice; ties of top branches; the same seed gives the same cards, another seed another (pinned); the AI's and the player's offers alike |
| `tests/core/test_generals.gd` (**new**) | **done-when 6**: `max_of` on seed 1480; every row of the two checks (P each); upkeep in `upkeep_army`; the merge and split rules; lost with its army (`general_lost`), dismissed on a disband; the stack at a hex with and without; the siege master's point |
| `tests/core/test_refit.gd` (**new**); `test_military.gd`, `test_armies.gd`, `test_army_state.gd` (edits) | **done-when 7**: raise options and row 6b by era (P each); every row of `refit_check` (P each); 4.10's 47 ducats and 3 iron; the refitted muster; men, morale and experience kept |
| `tests/core/test_combat.gd`, `test_battles.gd` (M7, edits) | 4.11's two hits; the morale cut; each side's `WarDef` used for its own values (P: the attacker's tech changing the defender's value is caught); `BattleRecord.generals` |
| `tests/core/test_research_property.gd` (**new**) | 40 seasons with the random player for every country (every action of M1 to M11) on `ResearchFixture.quick`: every season the `research` and `generals` invariants hold and `defs_of` of every country equals `ModApply.apply` of its effects |
| `tests/core/test_research_saves.gd` (**new**) | **done-when 9**: save, load, save byte-equal with techs, queues, progress, ideas, offers, generals, refit turns; ten seasons after a load equal ten without; `FORMAT` 9 (P: a format-8 header reads `older`; a tech id of 99; a trait `"knight"`) |
| `tests/core/test_research_italy.gd` (**new**) | **done-when 2**'s pull-request half and 4.18 (c): no AI, Genoa's research scripted: era II at turn 161, the offer, the techs' turns pinned |
| `tests/core/test_season.gd`, `test_chronicle.gd`, `test_vision.gd`, `test_game_core.gd`, `test_replay.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_owns.gd`, `test_forty_seasons.gd`, `test_money_property.gd`, `test_men_property.gd`, `test_check_contract.gd`, `test_insights_views.gd`, `test_treasury.gd`, `test_stores.gd`, `test_stats.gd`, `test_country_state.gd`, `test_war_state.gd` (edits) | **`PHASES` is the seventeen of 4.15** (the pin); forty-eight notable kinds; thirty-eight actions; twenty `WHY` reasons; ten flows; sixty series; the dev records replay (P: a changed tech gives another digest); 5.3's OWNS table (P: a test-only phase writing `progress` directly is reported); `DOOR_FIELDS`; `country/7`, `army/3`, `unit/3`, `battle-record/2` round trips and refusals |
| `tests/core/random_player.gd` (M6 to M10, edit) | the eight new actions with random techs, ideas, armies and traits |
| `tests/core/test_words.gd`, `test_knowledge.gd`, `test_country_card.gd`, `test_hex_card.gd`, `test_army_view.gd`, `test_battle_view.gd`, `test_odds_view.gd`, `test_study_military.gd`, `test_study_history.gd`, `test_log_lines.gd`, `test_season_summary.gd`, `test_reminders.gd` (edits); `test_research_view.gd`, `test_tech_layout.gd`, `test_idea_view.gd`, `test_cards_research.gd`, `test_study_research.gd` (**new**) | the words; `techs_seen`, `ideas_seen`, `era_seen` (P: an unknown country's techs shown); `know_range`; every part of 6.3 to 6.7 as data; `TechLayout` against `techlayout.py`'s cells and states for the same country (a fixture table), `move` in every direction and at the edges; the side card's verdicts equal the checks (P: a view that disagrees is caught); the sentences of 4.16 and 4.20 (P: a refit line with no companies); the section equal after a save and load; every reminder (P: `research_idle` with a research set makes no line) |
| `tests/core/test_ai_research.gd` (**new**); `test_ai_defs.gd`, `test_ai_know.gd`, `test_ai_door.gd`, `test_ai_forces.gd`, `test_ai_economy.gd`, `test_ai_turn.gd`, `test_ai_fog.gd`, `test_ai_play.gd` (M8 to M10, edits) | 4.17's scores, the gate factor, the idea rule, funding's rule (P: funding at war); appoint and its trait choice; refit; the raise by branch and era; the step order; the door's new tokens (P: `Research.` in a step module); the fog with others' progress changed; the scripts seam |
| `tests/core/invariants.gd`, `test_invariants.gd`, `test_ai_soak_quick.gd` (M8 to M10, edits) | `research` and `generals` (P each: a known tech without its need, a progress over the cost, a fifth general); the `armies` invariant's stack with a general |
| `tests/core/research_script.gd` (**new**), `test_research_report.gd` (**new**) | `ResearchScript.gate_first(game, tag) -> Array[Dictionary]` (the season's `{action, args}`: research, funding, the idea), its choices on fixtures; the report on 8 seasons of one seed parses, its medians equal the test's own |
| `tests/shell/test_session.gd` (edit) | the eleven signals drained after their phases and actions, then `chronicled` for the notable |
| `tests/shell/test_tech_screen.gd`, `test_tech_node.gd`, `test_idea_pick.gd`, `test_page_research.gd` (**new**); `test_decision_queue.gd`, `test_country_panel.gd`, `test_army_panel.gd`, `test_raise_list.gd`, `test_hex_panel.gd`, `test_battle_dock.gd`, `test_odds_card.gd`, `test_page_military.gd`, `test_season_report.gd`, `test_chips.gd`, `test_resource_chip.gd`, `test_army_tokens.gd`, `test_floaters.gd`, `test_map_input.gd`, `test_bindings.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_task_flag.gd`, `test_notifications.gd`, `test_action_log.gd`, `test_study.gd`, `test_app_flow.gd` (edits) | every part of 6.3 from `ResearchView` fixtures (a click sets, Shift queues, a right click removes; the keyboard path; the banner); the node in every state; the idea pick's cards, keys, Take and Decide later; the decision's order after the leagues; the page's parts and empty states; the panels' rows and verdicts; the report's section; the chip and `set_fraction(0, 0, 0)`; tokens by era and the general icon; T (P: T in the sandbox toasts); the console's commands and planted faults; the F3 line; end to end: New game as Genoa, T, click Tax rolls, Shift+click Printing press, Fund research, close, End season twice, the report's Research section, `era`, the idea pick, Take, the Raise tab's landsknechts, a refit, appoint a Ranger |
| `tests/shell/test_ui_monkey.gd` (edit) | adds T, clicks and keys in the tech screen and the idea pick; the digest changes only after an accepted action or a season |
| Python `tests/test_bake_ui.py` (edit) | slice 9's atlases at both scales; the catalogue; the asserts of style spec 4.4 |
| Pictures (`godot/tools/ui/shot_ui.gd`, edit) | the tech screen (Genoa, 1480 and a fixture at 1523 with a queue), the idea pick, the Research page, the army panel's general and refit rows, the report's Research section, against `14_tech_tree_c.png` and `14_tech_tree_d_new_age.png`; at 1280 x 720 scale 1 and 2560 x 1440 scale 2; signed by the art director, then goldens `godot/tests/goldens/m11_*.png` (0.5 %) |

**Determinism:** `test_replay`, `test_forty_seasons`, `test_research_property`, `test_check_contract`, `test_ai_determinism` (M8): the
draw is the only world luck M11 adds and is taken in country id order; every list is walked in id order; integers. **Save round
trip:** `test_snapshot`, `test_save_file`, `test_research_saves`, `test_season_summary` (J after a load: the Research section equal).

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| `Resource.duplicate(false)` shares or copies typed arrays differently from what `ModApply` assumes | `test_mod_apply.gd`'s "the base never changes" in Z1, first day | build every touched part with `new()` and copy its exported properties by `get_property_list()` (S) |
| The pace is off: eras come late (small states never reach II) or early | the `research` suite's ranges and `research_report.gd` in Z23, read by Opus before Z25 | data: `base_milli`, `town_milli`, the costs; the gate count 3 (S each) |
| Big countries idle for years before 1520 | the suite's idle-seasons range | `idle_keep_seasons` 8; the era I costs up 10 % (data) |
| Funding dominates research | the fundings range and the rate's share from funding in the report | `fund_points` 4 or `fund_every` 8 (data) |
| A modifier hook missed: a number stays the base for one country | `test_mod_hooks.gd` (55 probes) | none needed: a key without its probe cannot be registered |
| Hot loops slowed by `defs_of` | `production_ms`, `season_ms`, `ai_season_ms` in Z16 | section 8's fallback |
| Generals unbalance battles | `war_report.gd`'s general rows in Z8 (win rates with a general on either side, 100 seeds), read by Opus | `bonus_permille` 150 (data) |
| Refits drain treasuries at an era step (AI debt before M12) | the soak's treasury range (M8) and the older-kinds share | `refit_permille` 400, `refits_per_season` 1 kept (data) |
| The tech screen does not fit at 1280 x 720 | Z18's pictures at scale 1 and 2 | the grid scrolls (built in); node height 48 (S) |
| The idea draw moves the world stream and so the weather after 1520 | accepted: deterministic; the replay test covers it | none |
| M3 to M10's pins move | every earlier test on `ResearchFixture.off` (Z6) | none needed |
| The AI researches the same branch everywhere | the summary's techs by branch per temperament (Z23) | branch weights (data) |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 5.3: row 11 reads "Research (`research`): points, techs learned, the era gate and idea offers (`m11-build-spec.md` 4.9)"; 9.2: the intro names M2 to M11, an M11 row pointing at this spec and its plan, "specified and planned, waits for the owner's go; starts after M10 closes", the last row M12 |
| `docs/architecture/m4-build-spec.md` | 12, row M11: taken up in `m11-build-spec.md` (`FamilyDef` base, cost, port and room through `Game.defs_of`) |
| `docs/architecture/m4-5-build-spec.md` | 12, row M11: taken up (the `era` and `tech` marks; the Research page) |
| `docs/architecture/m5-build-spec.md` | 12, row M11: taken up (`growth_bp`, the settlements' room, `levy_permille`; no tech of the approved tree changes hunger or jobs: their keys can be registered when one does) |
| `docs/architecture/m6-build-spec.md` | 12, row M11: taken up (eight later kinds and `refit`; supply reach, army food, sight and costs; move points change with the kinds, never by tech: one step table) |
| `docs/architecture/m7-build-spec.md` | 12, row M11: taken up (generals as traits on armies, stack +2, terms in attack, defence and morale; the `WarDef` keys; later kinds; the era 2 shot is the missile branch's fire) |
| `docs/architecture/m8-build-spec.md` | 5.1: `mix` is by branch from M11; 12, row M11: taken up (`AiResearch`, `branch_weights`, `AiForces`' generals and refits) |
| `docs/architecture/m9-build-spec.md` | 12, row M11: taken up (Royal bureaucracy `reach_free`, Absolutism `goal_districts`, Resident ambassadors and the Holy See `price_outside_permille` and `infamy_decay`, Ordinanza halves weariness) |
| `docs/architecture/m10-build-spec.md` | 12, row M11: taken up (the `TradeDef` keys of 4.2; Galleon `merchants_max` +1; Factors' letters `idle_free_seasons` −2) |
| `docs/architecture/m4-5-build-plan.md`, `m5-build-plan.md`, `m6-build-plan.md`, `m7-build-plan.md`, `m8-build-plan.md`, `m9-build-plan.md`, `m10-build-plan.md` | Section 7, the M11 bullet: points at this spec |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M11: the files of this spec; the tasks are those of `m11-build-plan.md` |
| `docs/architecture/ui-style-and-feedback-plan.md` | S5, row M11: folded into `m11-build-plan.md` (Z13, Z14, Z19, Z20) |
| `docs/architecture/ui-style-and-feedback-spec.md` | 8: a note that the Research page is specified in this spec 6.6 |
| `docs/design/ui/game-feedback-screens.md` | C.2: the Research page is specified in `m11-build-spec.md` 6.6 |
| `docs/design/tech-tree.md` | a line under the title: the Godot build is `m11-build-spec.md` (re-fitted to districts: effects as modifiers, Navigation on the coast, no tile gates, generals as traits) |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `godot/README.md` (the keys, research, the console; Z22), `godot/data/README.md` (Z4),
`CLAUDE.md` (the `research_tables.gd` and `research_report.gd` lines in the Godot commands; Z23). No port rule changes: no new
autoload, no new layer; `tools/lint_godot.py` needs no entry (new files sit in listed folders, each under 800 lines: `research.gd`
about 600, `mod_apply.gd` about 300, `tech.gd` about 400).

---

## 12. What M11 hands to later milestones

| M | Takes from M11 | M11 leaves for it |
|---|---|---|
| M12 | **Score and the end**: `Research.known_points(game, tag)` (the costs of its known tree techs), `Stats` `techs` and `era`, `era_turns`, the chronicle's `tech_learned` and `era_reached` for M12's score and its end at 1650 (no era after the third; research runs to the last season); **debt**: `fund_research_check` gains M12's debt row ("your treasury is in debt"), a bankrupt country's generals are dismissed; **event pop-ups**: the idea pick stays its own decision screen; the `research` soak suite run to 681 seasons as the whole-game rig | A whole game |
| After M12 | **Ships and the sea**: Navigation's ship rows (sea route range, ships' sight and moves, carracks and galleons as kinds, the Atlantic), colonies (Town charters' old colonial rows), battle cards (if the battle design gains a deck), drill at barracks, characters (named generals with lives and experience), the price-swing part of Bourse; new keys join the registry with their probes | |
| **E2, E3** | **Research on Europe**: the rates re-tuned by `research_report.gd` on the real map (about 600 walled towns and cities); the made-up Europe's default national replaced by each country's own | |
