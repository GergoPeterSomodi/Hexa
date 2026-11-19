# M9 build spec: Diplomacy and peace

Game and systems designer (Opus), 2026-11-17. **Status: a proposal, design only; it waits for the owner's go.** Builds
milestone M9 of `docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`), the
M1.5 UI foundation (`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`), and the M2 to M8 specs and plans
(`m2-build-*.md` to `m8-build-*.md`, with `m4-5-build-*.md`). Where this page is more exact it wins for M9; section 1.2 lists
every place where it refines an earlier page. The tasks are in `m9-build-plan.md`. This page carries the M9 row of the
standard's 9.1 (the peace screen; war goals and relations in the country panel; the Relations mode; the Diplomacy page and the
relation matrix) and of `ui-style-and-feedback-plan.md` S5 (`RelationMatrix` joins the kit; `truce_ended` in the report; the
peace offer as a decision). It builds the two approved designs, `docs/design/war-goals-and-peace.md` and
`docs/design/stop-steamrolling.md` (Part A, the brakes, and the parts of Part B that war goals need), re-fitted to districts.

**What M9 is.** A war now has a **reason** and a **goal**. The attacker names its casus belli (conquest, reconquest, or the
league's "contain the aggressor") and aims at a block of the enemy's land: the twelve districts nearest a district it picks.
Fighting earns **war score**: the worth of the enemy districts a side holds (a city is worth far more than a wild hex, a capital
most of all) and points for battles won. At peace the winner **spends its score** on a menu: land in the goal is cheap, other
land dear, land it holds half price, ducats at twelve a point; the loser accepts any deal the score pays for. A white peace and
a surrender stay; a truce of twelve seasons follows terms. Between the countries lie **relations**: each country's opinion of
each other, made of memories that fade (you declared war on us, you took our land, you sent a gift) and of what holds now (at
war, in a truce, a shared enemy, your infamy). And conquest has a price: **infamy** from land taken without a good reason, which
opens a **league** (a coalition) of the conqueror's neighbours, each free to declare on it at no infamy; **war weariness** that
cuts income in long wars; **unrest** in conquered land, per historical region, that cuts taxes and levies; and **overextension**
by distance from the capital and by the land gained since 1480. The AI picks its reason and goal, signs by terms, sues, makes
demands of the player (who may refuse, until the enemy's score reaches 50 and it imposes its peace), joins leagues and sends
gifts. The player sees it all: the declare-war overlay with the goal drawn on the map, the peace screen, the relations and war
goals in the country panel, the Relations mode, the Diplomacy page with its relation matrix, the report's Diplomacy section, and
the demands, white offers, requests for peace and leagues as decisions before the report.

**When it starts.** After M8 is closed (its plan's definition of done, and the owner has played it). M9 edits `Game`, `Session`,
`Events`, the action and season tables, `MapData`, `MapState`, `Country`, `War`, `FamilyDef`, `WarDef`, `GameDefs`,
`Territory`, `Countries`, `Treasury`, `Wars`, `People`, `Works`, `EconomySeason`, `StatsSystem`, `Stats`, `Chronicle`,
`Knowledge`, `Words`, the previews, the report's view, the reminders, the log lines, the study's views and pages, the map modes,
the mode overlay, the map scene, the country, hex and army panels, the hex menu, the decision queue, the chips, the console, F3,
the App, the AI (`AiKnow`, `AiBrief`, `AiTurn`, `AiWar`, `AiPeace`, `AiDef`, `AiTemperDef`, their data), the soak and the map
builder, and builds its screens into the M1.5 frame as M8 left it.

**M9 is done when:**

1. **A war has a reason and a goal.** On "Italy, 1480", seed 1480, as Savoy, in Spring 1480: `declare_war {target: MLO, cb:
   conquest, anchor: (7, 6)}` succeeds; the war's goal is the twelve Milanese districts of 4.3 (Domodossola, Locarno, Lugano,
   Como, Novara and seven others, worth 48); `war_declared` carries `cb`, `goal`, `anchor` and `worth`; Milan's memory of Savoy
   is −40 and its opinion −70 (at war −30); `cb: reconquest` is refused with "the Duchy of Milan holds no district you lost in the last 80 seasons", `cb: contain`
   with "you are in no league against the Duchy of Milan", and an anchor at Turin (5, 9) with "Turin (5, 9) is not the Duchy of
   Milan's land" (`tests/core/test_diplomacy_savoy.gd`, 4.22 (a)).
2. **The score counts worth and battles.** M7's war plays on (Domodossola taken in Summer 1480, the Battle of Alessandria in
   Autumn, Locarno taken in Autumn): in Spring 1481, when Savoy won the battle, Savoy's gross score is 18 (8 + 8 for the two
   towns, 2 for the battle) and Milan's 0, so `WarScore.net(SAV, MLO)` is +18 and `net(MLO, SAV)` −18; when Milan won it, the
   gross scores are 16 and 2 and the net +14; the breakdown names each district and battle (4.22 (b); the test pins the result
   seed 1480 gives, as M7's does).
3. **Wars end by terms.** The peace screen's Best deal for Savoy is the nine goal districts that fit and 24 ducats, priced 18
   (4.22 (c)); `make_peace {terms: deal}` with it succeeds, moves exactly those nine districts, moves 24 ducats from Milan to Savoy
   (`tribute` lines that sum to zero), adds 6.0 infamy to Savoy, sets a truce of 12 seasons ("until Spring 1484"); the Best deal
   with 12 ducats more (price 19) is refused with "they refuse: it costs 19, your war score is 18"; Milan's capital is refused while Savoy does not hold it; in a
   copy, `terms: white` after 4 seasons succeeds and `terms: surrender` from Milan gives the whole goal and 20 % of Milan's
   treasury.
4. **Offers are decisions.** In the duel fixture and its demand setting (Milan's AI against a passive Genoa, the player; 4.22
   (e)): Milan's demand reaches the
   player as `peace_offered` and a `DECISIONS` screen; "Refuse" leaves the war on (`offer_answered {why: refused}`, Milan's opinion
   of Genoa −10); an unanswered demand lapses after 2 seasons; once Milan's net score reaches 50 its deal is **imposed**
   (`peace_made {imposed: true}`), and the peace alert names what moved; a save made with a demand pending loads and, answered,
   plays on to the digest of the game answered before the save (`tests/core/test_offers.gd`, `test_diplomacy_saves.gd`).
5. **Relations move.** After the peace of item 3 Milan's opinion of Savoy is −85, "Hostile" (memories −32 and −40, the truce
   −10, Savoy's infamy −3); it rises 4 a season as its two memories fade (2 each); a gift of 100 ducats raises the receiver's opinion of the giver by 20; the player sees
   another pair's opinion only as a word and only when it knows both countries (`tests/core/test_relations.gd`).
6. **The brakes bite, and not on 1480.** On every hex of the 1480 start every tax share is 1,000 permille and every unrest 0;
   after the peace of item 3 and Spring 1481's `relations` phase Savoy's Lombard part (4 districts) has unrest 40 ("restless": its
   people's taxes at 75 %) and its Valais part 30 with the Army of Ivrea standing there; Savoy's people's taxes lose 3 % to the national part (9 districts gained, 6
   free); a country whose infamy reaches 30.0 while it holds 5 % of the land has a league formed against it, every neighbour and
   victim eligible, and a member's `contain` war adds no infamy for goal land; 6 seasons of war with an army in the field and a lost
   battle give weariness 29 and cut the season's income by 8.7 % (`tests/core/test_brakes.gd`, `test_unrest.gd`,
   `test_coalitions.gd`).
7. **Not by exhaustion.** In the nightly soak (`ai` suite, 100 AI-only games of 80 seasons on north Italy) at most 10 % of the wars
   that ended were ended by the 40-season timer, at least 50 % by a deal or a surrender, and the median war lasted 16 seasons or
   fewer (4.23).
8. **No runaway winner.** In the same soak and the `conqueror` suite (20 games of 80 seasons, one seat played by a conqueror that
   attacks its weakest neighbour whenever it may): no country holds 40 % of the land (136 districts) at any season of any game
   (the invariant `runaway`); the largest country's share at season 80 is 24 % or less in the median game and 33 % or less in
   every game; the conqueror ends at most at the larger of 2 x its start and its start + 12 districts in the median game, and at
   most at the larger of 2.5 x and start + 20 in every game (4.23).
9. **Conservation and contracts.** `tests/core/test_peace_property.gd` plays 40 seasons with seeded random actions for every
   country (every action of M1 to M9) and finds at every peace: the land count unchanged; the districts that changed owner are
   exactly the deal's; occupations between the two cleared; every tribute and gift line paired by an equal opposite line in the
   same season; no treasury made negative by a peace; infamy only up at a peace and down by its decay; every opinion −100 to 100;
   league members always eligible; no war during a truce; at most one pending offer a pair, always to the player.
   `tests/core/test_check_contract.gd` drives the random player over the 21 actions: a refused check changes nothing, an allowed
   one succeeds.
10. **Determinism and saves.** Same seed and same action log give the same digest after 40 seasons with deals, offers, gifts and
    leagues (`test_replay.gd`); save, load, save gives byte-equal files with memories, leagues, offers, unrest bands, `gained` and
    `former` in them; `SaveFile.FORMAT` is 7 and an M8 save reads "Made by an older test build".
11. **Time in budget.** On the made-up Europe the rows of section 8 hold in the nightly `perf_core.gd` run: the fourteen phases
    other than `ai_orders` under 400 ms, the `relations` phase under 25 ms, the war phase under 3 ms, the reach fields from cold under 250 ms, the
    AI season under M8's 3,000 ms mean.
12. Every M9 UI row of the standard's 9.1 is in the game, built from the M1.5 kit, each with its GUT test: the peace screen (every
    state of 6.4), the declare-war overlay with the goal on the map, the country panel's relations and war goals, the Relations mode
    on key 7, the Diplomacy page with the relation matrix and the Wars table (moved from the Military page), the report's
    Diplomacy section with `truce_ended`, the decisions for demands, white offers, requests for peace and leagues, the weariness
    chip, the hex panel's region and unrest, the reminders, the log, the notifications, the ribbons and the console. No stand-in is
    left.
13. Lint, import, check_scripts and GUT are green, with both UI `--check`s, `build_map --check` and `build_scenario.gd --check`;
    the art director has signed the diplomacy sheet and the pictures of section 9; the owner has played the build through the
    plan's checklist.

---

## 1. What is there, and where this page refines earlier pages

### 1.1 Read in the code (master `96c4d9a`), the map data and the specs

| Finding | Where | What it means for M9 |
|---|---|---|
| `godot/data/geography/regions.json` holds the historical regions (name, lon, lat, 1480 holder) and `city_region`; nothing in `godot/` reads them | `data/geography/`; grep of `godot/` | M9 puts a region on every land hex of the map file (D50) |
| The nearest anchor (the regions' points and the cities named in `city_region`), by v0.2.2's `naming.region_of` distance without its owner and landmass weights, gives **25 regions** on north Italy, 2 to 27 hexes each (Lombardy 27, Piedmont 23, Graubünden 20, Provence 20, Tuscany 20 ...; table 4.12) | a read-only script over `data/maps/north_italy.tres` for this page | Unrest per region part is one meter for every 14 districts or so (D46) |
| Crest edges do not cut north Italy into basins: the land is one piece when only crest edges are cut (crest chains end, the land goes round them) | the same script | "Across a crest" is read from the shortest way, not from basins (D45) |
| Reach from each capital over land (a plain edge 1, a pass edge 2, a crest without a pass shut): the farthest home district is 9 steps (Savoy's Nice and Geneva); Milan 8, Venice 8, Switzerland 8, Ferrara 7; the outside powers measured from their land on the map's edge reach 3 to 7 | the same script | `reach_free` 9: no tax lost to distance on 1480 (D43) |
| Worth by 4.2 on seed 1480: Milan 217 (257 with the capital), Savoy 172 (212), Venice 149 (189), Switzerland 98 (138), Florence 62 (102), Genoa 43 (83), Ferrara 35 (75), Siena 11 (51), Mantua 10 (50), Lucca 5 (45); France 47, Austria 58, the Papal States 53 (capitals off the map) | the same script, with `improve_report.gd -- --seeds=1480` (M7's run) | A score cap of 100 a side is a long, winning war; a small country is one war (D12) |
| Lots on seed 1480 (each district to its nearest settlement of its owner within 4 steps): Milan 20 lots of 1 to 5 districts, Savoy 13, Venice 10, Switzerland 8, Genoa 2 | the same script | The peace screen lists about a lot a town (D20) |
| `RelationMatrix` exists: `set_matrix(tags, names, cells)`, cells `{state, seasons_left, opinion}`, states war, ally, truce, peace, self, 64 x 34 cells, one line, the opinion only in the hover | `shell/ui/relation_matrix.gd` | M9 makes it two lines (state and opinion word), adds the `league` state and the hidden opinion "?" (6.12) |
| `ScreenIds.PATHS` already names `&"peace": "res://shell/screens/peace.tscn"` | `shell/screens/screen_ids.gd` | The peace screen's path; M9 adds `declare_war` |
| `Settings.SCHEMA` `state/study_page` already lists `diplomacy`; `state/map_mode` lists terrain, owner, relief (M4.5 to M6 add yields, food, supply) | `shell/app/settings.gd` | M9 adds `relations` to `state/map_mode` |
| `Bindings.DEFAULTS` has `view_mode_1` to `view_mode_4`; keys taken by M1.5 to M8: WASD, arrows, =, -, F, Home, G, N, H, U, M, C, I, L, J, B, O, Shift+O, R, T (M11), Tab, Space, Enter, [ ], 1 to 6, F1 to F12 | `shell/input/bindings.gd`, `ui-and-controls-spec.md` 4.1 | M9 takes 7 (Relations) and P (the peace screen) (D61) |
| The kit's icons: `icons_base` (M1.5), `icons` (M4, 48), the army (M6) and war (M7) atlases; bake slices 1 to 6 (M8 bakes nothing) | `assets/ui/kit/ui_kit.json`, `tools/ui_bake/`, the specs | M9 is bake slice 7 (6.2) |
| M7: `War {a, b, start_turn, end_turn, terms, won_*, lost_*, moved}`; `Wars.score` the seam; `make_peace {target, terms}` take, white or yield with v0.2.2's acceptance; truce 8 seasons; the 40-season timer; `battle_ended` with the war-goals fields | `m7-build-spec.md` 4.2, 4.9, 5.2, 5.5 | M9 replaces the score's body and the terms, keeps the timer and reads `battle_ended` unchanged |
| M8: `AiKnow` the door; `AiPeace` take, white, yield by temperament; M7's check stands for the loser's acceptance; an AI may impose a peace on the player through it (D28); the peace alert; `peace_risk`; the soak's land-share range "M9 tightens it into no runaway winner" | `m8-build-spec.md` 4.3, 4.11, 4.14, 4.17 | M9 rewrites `AiPeace`, adds the `diplomacy` step, makes demands decisions with a bar at 50 (1.2), and turns the range into the runaway invariant |
| M8 is on GitHub (milestone 20, issues `M8 K10` to `M8 K29`); M7 too (milestone 19) | `gh` (read only) | Their plans' task tables stay as they are: M9's edits to the AI and to M7's war are M9 tasks |
| Built by M1.5 to M8 and named "(M2)" to "(M8)" below: `Territory`, `Countries`, `Works`, `Calendar`, `Season`, `Stats`, `StatsSystem`, `Chronicle`, `Luck`, `ViewCache`, `Snapshot`, `SaveFile`, `Replay`, `Knowledge`, `Words`, `LogLines`, `Reminders`, `SeasonSummary`, `Economy`, `EconomySeason`, `EconomyPreview`, `Treasury`, `Stores`, `People`, `Armies`, `Military`, `Movement`, `StepCosts`, `Supply`, `Vision`, `Wars`, `War`, `Occupation`, `Battles`, `BattleRecord`, `Sieges`, `OddsView`, `BattleView`, `WarCards`, `CountryCard`, `HexCard`, `MapModes`, `ModeOverlay`, `ModeLegend`, `StudyMilitary`, `StudyHistory`, `SeasonFlow`, `DecisionQueue`, `GameRequests`, `DevCommands`, `TugBar`, `PerfFixture`, `perf_core.gd`, `RandomPlayer`, `WarFixture`, `AiKnow`, `AiBrief`, `AiTurn`, `AiWar`, `AiPeace`, `AiForces`, `AiDef`, `AiTemperDef`, `AiFixture`, `AiJudge`, `Invariants`, `soak.gd` | their specs | M9 starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M9 | Why |
|---|---|---|
| Standard 5.3, row 5: "War (`war`): the 40-season safety peace; peace offers" | Row 5 keeps the timer and adds the offers' lapse, the truces that end and the score's bookkeeping; **a new row `relations`** follows it (opinion fading, infamy, weariness, leagues, unrest bands) (D58) | One phase per topic; the brakes must be read before the season's money |
| M7 D29: `Wars.score(a, b)` counts districts ±3 for the capital | The body becomes `WarScore.net(game, a, b)`: worth held plus battle points, capped, net of the other side (D11 to D14). The name stays, so M7's and M8's callers keep working | The war-goals score; the seam M7 left |
| M7 D30, 4.9: terms take, white, yield; acceptance by score 3, or 1 with fewer men; white at score −1 after 4 seasons | Terms **deal**, **white**, **surrender** (and **timer**); a deal is accepted when its price is at most the actor's net score; white when the other's net is 10 or less after 4 seasons; surrender always (D15 to D27) | War-goals 3.6 and 3.7; "no haggling" |
| M7 D32: truce 8 seasons | 12 after a deal or a surrender, 8 after a white peace or the timer (D28) | War-goals 3.7 |
| M7 D33: the last district is never taken | Kept, as `DiplomacyDef.keep_last_district` (true) until M12; **the capital can now be taken** while it is held, and the capital moves (D24, D25) | War-goals question 2 (a); countries that fall are M12's |
| M7 D3 and M7 5.6 "sides (lists: alliances later)" | **No alliances, guarantees or pacts in M9**; a war keeps two principals; the league is soft: a free reason to declare, not a call to arms (D33, D36) | War-goals 3.10 keeps allies out; stop-steamrolling's first version B has none |
| M7 12 and M7 plan 7: "M12: war weariness and the brakes" | **The brakes are M9's** (the standard's M9 row: "anti-steamrolling"): infamy and leagues, weariness, overextension, unrest. Rebels (stop-steamrolling Part C) are not: they come after M12 (D52) | The standard wins; rebels are a separate design (owner's decision 1 of 2026-11-13) |
| M8 D27, D28, 4.11: the AI takes, whites or yields by temperament; the check is the loser's acceptance; an AI may impose a peace on the player at once | The AI makes deals, white peaces and surrenders by M9's rules (4.14); **acceptance is the score rule, the same for every country**, not a temperament (D29); an AI's deal or white peace on the **player** goes as an **offer** the player may refuse, unless the AI's net score is 50 or more, when it is **imposed** (D30, D31) | War-goals 7 ("the player may refuse; nothing is forced") reconciled with M8 D11 and its done-when 6 (the owner must be able to lose a war) |
| M8 12, M9 row: "`AiPeace.answer` by temperament ... the AI sends its offers as M9's actions in the war phase" | **No `AiPeace.answer`**: no AI ever receives an offer (an AI loser accepts by the rule at once); the AI's offers are M9's action `offer_peace`, made in `ai_orders` like every AI act (M8 D1), and they **lapse** in the `war` phase (D30) | One acceptance rule; the AI acts only in its phase |
| M8 4.4, `AiTemperDef`: `take_score`, `yield_after` | Replaced by `greed_margin`, `sue_net`, `surrender_net`, `sue_after`; `join_opinion`, `gift_ducats`, `infamy_guard`, `soak_only` added; `tired_seasons`, `sue_ratio` kept with M9 meanings; `AiDef` gains sixteen fields and loses `yield_ratio` and `prize_range` (4.14) | The score's new scale |
| M8 4.9: the war step's prize and ratio | The target's value is its **goal's worth**, weighted by opinion and by the crest; a reason is chosen; no AI declaration before turn 9; the infamy guard (4.14) | War-goals 7; stop-steamrolling A's "the AI counts the reach and ridge value" |
| M8 4.17: the largest share median ≤ 30 %, every game ≤ 60 % | The invariant `runaway` (40 % at any season) and the tighter ranges of 4.23; a `conqueror` suite | The standard's "soak shows no runaway winner" |
| M8 4.3 `test_ai_door.gd` tokens | Adds `Relations.`, `Coalitions.`, `Brakes.`, `Unrest.`, `Peace.`, `WarScore.`, `WarGoals.`, `DiploCache`, `game.offers`, `game.coalitions`, `game.relations`, `game.diplo_cache` | The door stays one door |
| M4 4.9 money lines; `Treasury.WHY` | Two income losses as their own lines, **`overreach`** (taxes lost to distance, unrest and the national part) and **`weariness`**; two transfers, **`tribute`** and **`gift`** (D40, D41) | "Every ducat of the report sums to the change" (M4); "a new line: Lost to distance and unrest" (stop-steamrolling) |
| M7 4.15: "Wars, peaces, truces, war scores: everything, public" | Kept, plus war goals, reasons and leagues public; others' opinions only as a word when you know both; others' weariness and unrest hidden; infamy public as a word, banded when known (4.17) | "Knowledge fog for others' relations" |
| M7 6.7 (the country panel's three peace buttons) and M7 6.11 (`app_requested(&"declare_war")`, `(&"peace", {terms})`) | The panel's **Make peace…** opens the peace screen; **Declare war…** opens the declare-war overlay (6.4 to 6.6) | War-goals 5: "the peace screen replaces the three peace buttons" |
| M7 6.9: the Wars table on the Military page | Moves to the **Diplomacy** page (6.9); the Military page keeps Battles and the losses | M7 1.2's own note |
| M3 4.9, M7 4.17: eleven report sections | A twelfth, **`diplomacy`**, after `war` (D63) | Truces, leagues, gifts, offers and unrest are not battles |
| M4.5 D15: modes by number as they arrive | **Relations on key 7** (Trade becomes 8 in M10, as planned) | First come, first numbered |
| `ui-style-and-feedback-spec.md` 5: `RelationMatrix` 64 x 34 cells | 64 x 40, two lines (D64) | The opinion word must show without a hover ("never colour alone") |
| M2 D25 / 5.3: `Territory.transfer` writes `owner` | It also writes `gained` (the turn) and `former` (the owner before) (D44) | Home land, reconquest and unrest read them |
| M6 12, M9 row: "military access as a relation opens `open_to`" | **No military access** in M9; `Movement.open_to` unchanged (D33) | Pacts are out with alliances |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days). Data changes are a
`.tres` edit plus the test that pins the value. **The approved designs' questions** are answered by their recommended options:
war-goals 1 (a) a twelve-district goal around an anchor, 2 (a) the capital can be bought while held, 3 (a) the defender may take
attacker land it holds, 4 (a) surrender gives the goal and 20 % of the treasury, 5 lots with a district-by-district view, 6 (a)
the AI keeps a roll but gives each war a goal; and the owner's 2026-11-13 answers of `stop-steamrolling.md` (three separate
designs, medium brakes, unrest per region, home land safe, overextension both ways, leagues against anyone with a warning at
60 %, wars end by terms with a 40-season safety timer only, every tool against unrest costs something).

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | What M9 builds | War goals, the war score, peace terms, offers, relations, gifts, infamy and leagues, weariness, overextension, unrest by region part; the AI for all of them; their screens | The standard's M9 row and the two approved designs | none |
| D2 | Reasons for war (casus belli) | **Conquest** (any neighbour), **reconquest** (the target holds districts you lost within 80 seasons), **contain** (you are in a league against the target). No claims, no humiliation, no defence | War-goals 3.1 and its first version; claims are a Europe table "after the core" (D53) | S a reason |
| D3 | Who may declare | M7's rows (a living neighbour, not at war, out of truce) plus the reason's own rows (4.3) | M7 D1 | S |
| D4 | The goal | Conquest and contain: the **12** districts of the target nearest the **anchor** by steps over the target's land (a plain edge 1, a pass edge 2, a crest without a pass shut), ties by hex index; reconquest: the districts lost, at most 30, in hex index order | War-goals 3.1 (a) | Data (S) |
| D5 | The anchor | A land district of the target, picked by the actor; the overlay and the AI start from `WarGoals.suggest`, and a declaration without one takes the suggestion's (a missing reason is conquest) | War-goals 5: the dialogue outlines the goal; M7's and M8's callers keep working | S |
| D6 | The defender's goal | Every district of the attacker the defender occupies counts as in its goal | War-goals question 3 (a) | S |
| D7 | Goal fixed | The goal is set at the declaration and never changes | One rule for the score and the menu | S |
| D8 | Worth of a district | By its piece: wild 1; goods 2, 3, 4 by level; hamlet 3, village 4, town 8, walled town 12, city 15; castle 1; + 2 a fortress level; + 40 for the capital (`FamilyDef.worth`, `DiplomacyDef`) | War-goals 3.2 re-fitted: goods districts are worth more than wild land on the district map | Data (S) |
| D9 | Where worth lives | `FamilyDef.worth` per level (beside M7's `fortress`), the rest in `DiplomacyDef` | A number in one `.tres` | S |
| D10 | Worth of an outside power's capital | None: it is off the map | M7 4.2 | none |
| D11 | Gross score | The worth of every enemy district the side **occupies** (M7's occupier), plus its battle points; capped at **100** | War-goals 3.3 | Data (S) |
| D12 | Net score | `gross(a) − gross(b)`, −100 to +100; `net(b, a) == −net(a, b)` | War-goals 3.3; M7's symmetry | none |
| D13 | Battle points | The winner of a battle of the war gains 2 + 1 per 1,000 enemy killed + 1 per 2,000 enemy wounded (floored), at most **25** a side a war; a draw nothing; a storm or a siege is occupation, not points | War-goals 3.4; M7's `battle_ended` read unchanged | Data (S) |
| D14 | Where points are kept | `War.battle_a`, `War.battle_b`, written by `Wars.book_battle` (M7) | M7's seam | none |
| D15 | Who makes a deal | The side with a **net score above 0**; its price must be at most its net | War-goals 3.6 | S |
| D16 | Prices | worth x 1 in the goal, x 2 outside, x 0.5 when the winner occupies it, x 1.25 when the winner's shortest way to it crosses a crest; ducats at **12** a point, at most the loser's treasury; rounded up | War-goals 3.6, with the ridge multiplier of stop-steamrolling 5 now (the crest data exists) | Data (S) |
| D17 | Returns | At any peace every occupation between the two is cleared (M7), so the winner's own land comes back free | War-goals 3.6 "return: free" | none |
| D18 | Land not in the deal | Goes back to its owner (M7's release) | War-goals 3.6 | none |
| D19 | Acceptance | **No haggling.** The loser accepts any deal its winner's score pays for and refuses any it does not; the screen says which before sending | War-goals 3.7 | S |
| D20 | Lots | A lot is the districts of one country nearest one of its settlements (steps over its land, at most **4**), ties to the higher level then the lower index; a district no settlement reaches is a lot alone. The screen lists lots, each with its districts | War-goals question 5 | Data (S) |
| D21 | Best deal | The goal's districts by price (then index) while they fit; then whole lots outside the goal by worth per price; then ducats; never the loser's last district (it keeps its most populous) | War-goals 5: "fills the goal, then the best value for the rest" | S |
| D22 | White peace | Asked by either side; accepted when the **other** side's net is at most **10** and the war is **4** seasons old or more | War-goals 3.7 | Data (S) |
| D23 | Surrender | The surrendering side gives the enemy's goal (a defender gives the attacker's goal; an attacker gives nothing) and **20 %** of its treasury (if positive); always accepted | War-goals question 4 (a) | Data (S) |
| D24 | The capital | Can be taken only while the winner occupies it; then the loser's capital moves to its most populous settlement it controls (`Countries.move_capital`, `capital_moved`) | War-goals question 2 (a) | S |
| D25 | The last district | Never taken (`keep_last_district` true): M12 makes countries fall | M7 D33; M12's countries that fall | S (M12) |
| D26 | The timer | M7's 40-season white peace stays, with its warning at 32 | The owner's decision of 2026-11-13 | none |
| D27 | Terms after M9 | `deal`, `white`, `surrender`, `timer`; M7's `take` and `yield` are gone (an M8 save is refused anyway, D60) | One list | none |
| D28 | Truce | **12** seasons after a deal or a surrender, **8** after a white peace or the timer; read from the newest ended war; `truce_ended` when it ends | War-goals 3.7 | Data (S) |
| D29 | Acceptance by temperament | **No.** Every country accepts by D19, D22, D23 | The approved design has one rule; a temperament acting on acceptance would make the screen's answer line a guess | M |
| D30 | Offers | Only the **human player** receives offers: an AI's deal (a **demand**) or white peace (a **white offer**) on the player, and an AI's **request for peace** (a sue, no terms), are `offer_peace` actions; the player answers (accept or refuse); an offer **lapses after 2 seasons**; one pending offer a pair | War-goals 7: "the player may refuse; nothing is forced"; one pop-up a season | S |
| D31 | Imposing | An AI whose net score against the player is **50 or more** makes its deal at once (`make_peace`, `imposed: true`); below that it can only demand | M8 D28 and its done-when 6 (the owner must be able to lose a war) kept at a high bar; without it a player who refuses every demand waits for the timer's white peace | Data (S) |
| D32 | Refusing a demand | Costs the refuser 10 points of the demander's opinion; the war goes on; a new demand only after 4 seasons and with a higher net | War-goals 7's cooldown; a refusal is a choice with a price | Data (S) |
| D33 | Alliances, guarantees, pacts, military access | **None in M9.** They come after M12 as their own milestone (the standard's list) | War-goals 3.10; stop-steamrolling's first version B | L (that milestone) |
| D34 | Relations | Each country's **opinion** of each other, −100 to 100: **memories** (stored, each fading 2 a season to 0, at most 8 a pair) plus **standing** terms (computed now) (4.8) | Stop-steamrolling B: "relations decaying toward 0"; every number with its reason | S |
| D35 | Opinion is directional | `a`'s opinion of `b` and `b`'s of `a` differ (a gift moves only the receiver's) | A gift and a grudge are one-sided | M |
| D36 | Leagues (coalitions) | **Soft:** a league forms against a country whose infamy reaches **30.0** and that holds **5 %** of the land; its neighbours and those it took land from in the last 40 seasons may join; a member gains the `contain` reason (no infamy) and both sides' opinion falls 30; no member is called to war; it ends when the infamy falls under 12.0 | Stop-steamrolling A: "soft, plus an alliance offer between members" without the alliance (D33) | Data (S) |
| D37 | Infamy | Stored in tenths per country; each district a peace gives the winner adds `worth x 5` tenths (0.5 a worth point), half in a conquest goal or for a defender's held land, none in a reconquest or contain goal; fades 0.3 a season | Stop-steamrolling A: infamy for land without a claim, re-fitted to worth | Data (S) |
| D38 | The league warning | A reminder at **60 %** (18.0) and the infamy row of the peace screen and the declare-war overlay, before you act | Owner's decision 6 | none |
| D39 | War weariness | Per country 0 to 100: +4 a season at war with an army outside its land, an enemy on its land or a district occupied; +2 at war otherwise; +5 a battle lost; +1 a district captured from it; −8 a season at peace | Stop-steamrolling A, re-fitted to whole numbers (0 to 10 as tenths) | Data (S) |
| D40 | Weariness's cost | Its income (people's taxes after overreach, goods' share, port dues) falls 3 permille a point (30 % at 100), a ledger line `weariness`; +1 unrest a 10 points; the AI seeks peace from 50 | Stop-steamrolling A | Data (S) |
| D41 | Overextension | Two parts: **reach** (each district's steps from the nearest of its owner's centres beyond 9 cost 25 permille of its people's taxes a step, at most half; home land half that) and the **national part** (each district gained and not yet home beyond 6 costs 1 % of the people's taxes, at most 30 %); a ledger line `overreach` with unrest's tax loss | Owner's decision 5 (both, distance doing most); "no penalty at the start" | Data (S) |
| D42 | Centres | The capital and every city (settlement level 5) the owner controls; an outside power: every district it owns on the map's edge | Stop-steamrolling A (a city or a court; the court is a later building) | S |
| D43 | `reach_free` | **9** steps: the farthest home district of 1480 (Savoy's) | "On turn 1 every country's tax share is 100 %" (stop-steamrolling 9); Europe re-tunes it (E3) | Data (S) |
| D44 | Home land | A district held since the start (`gained` 0) or for 40 seasons; `MapState.gained` and `former` written by `Territory.transfer` | Owner's decision 4 | S |
| D45 | Across a crest | The district's shortest way from the owner's (or the winner's) centres crosses a pass edge (crest edges without a pass are shut); read from the reach field | North Italy has no closed basins (1.1) | S |
| D46 | Where unrest lives | Per **region part**: the districts of one region owned by one country (owner's decision 3, with a split region not shared between owners) | One meter for the land you hold there; your rival's conquest does not unsettle your half | S |
| D47 | Unrest's terms | Computed, not stored: conquest +30 a peace that gave the part land, fading 1.5 a season (cap 60); not home +10; far +1 a step beyond 9 (home half); across a crest +8 (not home); tax Low −10, High +10; weariness +1 a 10; an army of 250 men or more there −10; a fortress it controls there −15; the capital's part −20; 0 to 100 | Stop-steamrolling A's list | Data (S) |
| D48 | Unrest's bands | Calm under 40; **restless** 40 (people's taxes there at 75 %); **rising** 70 (also no levies); **defiant** 100 (no taxes, no levies, no work may begin) | Stop-steamrolling A; "defiant" stands where a revolt would until the rebels milestone (D52) | Data (S) |
| D49 | `unrest_rising` | Emitted when a part's band rises (bands kept per part, saved) | The design's alert "Unrest rising in X" | S |
| D50 | Regions on the map | `MapData.region_id` per hex and `MapData.regions`, made by `build_map.gd` from `regions.json` and `cities.json` (nearest anchor) | The map is data first (standard 1); regions are geography, not scenario | M |
| D51 | Ridges elsewhere | Only the crest term of unrest, the crest price and the AI's crest weight; no siege or supply change | Stop-steamrolling 5's other parts are M6 and M7 rules already re-fitted (relief adds to the siege need) | M |
| D52 | Rebels, independence, free states | **After M12** (stop-steamrolling Part C); M9's defiant band and `gained`/`former` are their seam | A separate design (owner's decision 1) | L |
| D53 | Historical claims | **After M12**, with the Europe play area (war-goals 3.9); the reason list has room for `claim` | Owner's decision 9: "after the core"; a region table | M |
| D54 | Gifts | `send_gift {target, ducats}`: 10 to 200 ducats in tens, one a season, not at war; +2 opinion a 10 ducats, at most +30 a gift (a memory) | Stop-steamrolling B's gift button; the player's one lever on opinion | Data (S) |
| D55 | What opinion does | It moves the AI: no war on a country it is Friendly with (50 or more), more ready against a Hostile one, joins leagues when cold; shown to the player in the panel, the matrix and the Relations mode | A number with effects | Data (S) |
| D56 | The AI's war goal | Reconquest when it can, else contain when a member, else conquest at `WarGoals.suggest`'s anchor (the best goal worth, its price at most 90); weighted by opinion and the crest; guarded by infamy; no declaration before turn 9 | War-goals 7 | Data (S) |
| D57 | The AI's peace | Signs its Best deal when the goal is held, or its net passes the goal's price by its greed, or the score stood still for its `tired_seasons`; surrenders when far behind; asks for peace (the player) when behind; white in a stalemate, when weary or outnumbered (4.14) | War-goals 7 with temperaments | Data (S) |
| D58 | The season | M9's `PHASES`: `ai_orders`, `movement`, `battles`, `supply`, `sieges`, **`war`**, **`relations`**, `production`, `income`, `works`, `people`, `stats`, `calendar`, `ready_units`, `vision` (15) | Peaces and timers first, then the meters, then the money that reads them | S (the pin) |
| D59 | Luck | M9's rules draw none; the AI's rolls stay M8's `Luck.ai` | Standard 5.4 | none |
| D60 | Saves | `SaveFile.FORMAT` **7**, `OLDEST_FORMAT` 7; body key `diplomacy`; `war/2`, `country/5`, `map-state/6` | An M8 save's digest has no relations or score fields, so it could never match its header | S |
| D61 | Keys | **7** the Relations mode; **P** the peace screen (your war with the country shown, else your newest) | Free keys; P for peace | Bindings (S) |
| D62 | The peace screen | A `MODAL` 900 x 640 vellum treaty (`ModalFrame` > `VellumSheet`), one war at a time | War-goals 5: "a screen, not a tiny panel" | M |
| D63 | The report | A twelfth section `diplomacy`; infamy and weariness chips in At a glance | Style plan S5's `truce_ended` | S |
| D64 | The matrix | 64 x 40 cells: line 1 an icon and the state (war, truce, league, peace, self), line 2 the opinion word or "?" | Never colour alone; others' opinions fogged | S |
| D65 | The declare-war overlay | An `OVERLAY` on the left, 420 px, so the map stays live and a click on the target's land moves the anchor | War-goals 5: "the goal outlined on the map" | M |
| D66 | Sandbox | No diplomacy ("this map has no countries") | No countries | none |
| D67 | The console | `infamy TAG n`, `weary TAG n`, `opinion A B n`, `goal TAG`, `deal TAG best`, `offer TAG` with demand, white or sue, `leagues`, and M7's `declare TAG` with a reason and an anchor, with M6's `as TAG` | The playtest needs an infamous country and a demand on demand | S |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| `war_score` = provinces held − lost + 3 for the capital; every province the same | `systems/war.py` 68 | The live occupation part | Worth by piece (D8), battle points (D13), capped, net (D12) |
| `peace_offer` take, white, yield with "take at score 3, or 1 with a weaker army; white at −1 after 4 seasons" | `war.py` 147 to 166 | White after 4 seasons; yield as surrender | The deal menu priced by the score (D15 to D23) |
| `peace`: held provinces to the winner, the capital returned, stacks home (and `free_spot_near`) | `war.py` 84 to 146 | Occupations cleared, armies home (M7) | Only the deal's districts move; the capital may move (D24) |
| `war_timeouts` 16 / 32 seasons, AI score 5 | `systems/season.py` 34 | A war ends | The 40-season white peace only (M7) |
| `_diplomacy`: every 8 seasons a 12 % roll on a neighbour 1.8 times weaker, at most 3 wars | `ai.py` 640 | A rare roll, a weaker target | M8's think turns and temperaments, plus a reason and a goal (D56) |
| No truces, no relations, no infamy, no unrest, no weariness, no coalitions | the whole game | | All new (designs of 2026-11-12 and 13) |
| `regions.py` `REGIONS`, `CITY_REGION`; `naming.region_of` (nearest anchor, own country closer, other landmass farther) | `campaign/regions.py`, `naming.py` | The nearest anchor | No owner weight (the map comes before the scenario); one landmass on north Italy |
| The Python soak's land-share table (`stop-steamrolling.md` 1): the biggest country hardly grows in 40 years | `tools/soak.py` | The measure | The runaway invariant and the conqueror probe (4.23), as the design asks |

---

## 4. Design content

All amounts are whole numbers; rates are permille; infamy is kept in **tenths** (300 tenths is "30.0"). Every number below lives
in `data/defs/diplomacy.tres` (`DiplomacyDef`, 5.1), in `FamilyDef.worth`, or in the AI's files (4.14); `godot/tools/
diplo_tables.gd` prints the tables of 4.2 and 4.6 to 4.12 from the files.

### 4.1 The model in one picture

```
 during the season (actions, any country; the AI only in ai_orders)
   declare_war {target, cb, anchor}     a War with its reason and goal; the target's memory -40         -> war_declared
   make_peace {target, terms, deal}     deal / white / surrender, accepted by the score rule; districts, tribute, infamy,
                                        opinions, the capital, a truce of 12 or 8                         -> peace_made, owners_changed,
                                                                                                            capital_moved
   offer_peace {target, kind, deal}     an AI's demand, white offer or request for peace to the player  -> peace_offered
   answer_offer {offer, accept}         the player's yes (the peace) or no (the demander's opinion -10)  -> offer_answered
   send_gift {target, ducats}           ducats over, the receiver's opinion up                           -> gift_sent
   join_coalition {against}             a member of the league; both opinions -30; the contain reason    -> coalition_joined
 battles    (M7) battle_ended -> Wars.book_battle adds the winner's battle points to its war
 sieges     (M7) occupation changes -> the score follows (it is read live)
 war        the score's bookkeeping (net_last, net_turn); offers lapse; the 40-season timer (M7); truces that end
                                                                                                         -> offer_answered, peace_made,
                                                                                                            truce_ended
 relations  memories fade; infamy fades; weariness; leagues end and form; unrest bands
                                                                                                         -> coalition_ended,
                                                                                                            coalition_formed, unrest_rising
 production, income   the people's taxes by each district's share (reach, unrest) and the national part (the overreach line);
                      the weariness line
 works, people        no work begins in a defiant part; no levy in a rising one
```

### 4.2 Worth of a district

`WarGoals.worth_of(game, hex)` = the piece's `FamilyDef.worth[level]` (wild land: `worth_wild`), + `worth_per_fortress` x its
fortress level (M7 `Occupation.fortress_level`), + `worth_capital` when it is a country's capital (`Country.capital`):

| Piece | Worth | With walls | As a capital |
|---|---|---|---|
| Wild land (`main_use` 0) | 1 | | 41 |
| A goods district (wheat, hemp, silk, dyes, vineyard, olives, grazing, timber, mines, quarry, salt, harbour) at stage 1, 2, 3 | 2, 3, 4 | | |
| Hamlet, village, town | 3, 4, 8 | | 43, 44, 48 |
| Walled town (fortress 2) | 12 | 16 | 56 |
| City (fortress 3) | 15 | 21 | 61 |
| Watchtower, castle, fortress (castles 1 to 3) | 1 | 3, 5, 7 | |

Worth of the 1480 countries on seed 1480 (land only / with the capital): Milan 217 / 257, Savoy 172 / 212, Venice 149 / 189,
Switzerland 98 / 138, Florence 62 / 102, Austria 58, the Papal States 53, France 47 (capitals off the map), Genoa 43 / 83, Ferrara
35 / 75, Siena 11 / 51, Mantua 10 / 50, Lucca 5 / 45. `tests/core/test_war_goals.gd` pins these sums.

### 4.3 Reasons and goals

| Reason (`cb`) | Allowed when (beside M7's rows) | Goal | Infamy for goal land |
|---|---|---|---|
| `conquest` | always | `goal_of(target, anchor)`: 12 districts | half (500 permille) |
| `reconquest` | the target owns districts whose `former` is the actor and whose `gained` is within `reconquest_seasons` (80) | those districts, at most `reconquest_max` (30), hex index order; the anchor is the first | none |
| `contain` | the actor is a member of an open league against the target (4.9) | `goal_of(target, anchor)` | none |

**The goal** (`WarGoals.goal_of(game, target_id, anchor)`): a walk from the anchor over the target's own districts (`owner` the
target), a plain edge 1 step, a pass edge `reach_pass_steps` (2), a crest edge without a pass shut (M6 `StepCosts`' crest rule),
taken in ascending (steps, hex index), the first `goal_districts` (12) reached. A target with fewer gives all it can reach.

**The suggestion** (`WarGoals.suggest(game, tag, target, max_price)`): for each district of the target within `anchor_range` (3)
hexes of the actor's land, in hex index order, its goal, the goal's worth `W` and its price at the declaration `P` (4.6, nothing
held); keep those with `P ≤ max_price`; the best `W x 1000 / (10 + 10 x d)` (d the hex distance from the actor's nearest district),
ties to the lower index: `{anchor, goal, worth, price, crossed}` or `{}`. The overlay starts there with no cap; the AI with
`AiDef.goal_max_price` (90).

`Wars.declare_war_check(game, {target, cb, anchor, tag})`: a missing `cb` is `conquest` and a missing `anchor` the suggestion's
(`WarGoals.suggest` with no cap), so M7's and M8's callers keep working; after M7's rows 1 to 9 (4.2 of M7), in order:

| # | Case | Verdict |
|---|---|---|
| 10 | `cb` not one of the three | "no such reason: conquest, reconquest or contain" |
| 11 | `reconquest` with nothing to retake | "the %s holds no district you lost in the last 80 seasons" |
| 12 | `contain` and the actor is not a member of an open league against the target | "you are in no league against the %s" |
| 13 | `conquest` or `contain` with no anchor given and no suggestion (no district of theirs within 3 hexes of yours) | "choose a district of theirs to aim at" |
| 14 | The anchor is not a land district the target owns | "%s is not the %s's land" (`Military.hex_text`, the long name) |
| 15 | Otherwise | ok |

`declare_war` checks again, then M7's steps, and: `War.cb`, `War.goal` (in walk order), `War.anchor`; the target's memory of the
actor `declared` −40 (`contain` −20); `war_declared` gains `cb`, `goal` (an `Array[Vector2i]`), `anchor` and `worth`.

**Worked** (seed 1480, Savoy on Milan, anchor Domodossola (7, 6)): the walk reaches Domodossola (0 steps); (6, 5), Locarno (7, 5),
(6, 6), (8, 6) and the grazing at (7, 7) (1 step); (7, 4), Lugano (8, 4), Como (8, 5), (9, 6), (8, 7) and Novara (7, 8) (2 steps).
Worth 8 + 1 + 8 + 1 + 1 + 2 + 1 + 8 + 8 + 1 + 1 + 8 = **48**; price at the declaration 48 (no district across a crest from
Turin).

### 4.4 The war score

`WarScore.gross(game, war, side)` = `min(score_max, occupation + min(battle_cap, battle points))`:

- **occupation**: the worth (4.2) of every district of the other side whose occupier (M7) is `side`. It is live: lose the district
  and the points go.
- **battle points**: `War.battle_a` or `battle_b`, added by `Wars.book_battle` (M7) for each battle of the war's two sides that
  has a winner: `battle_win` (2) + the loser's killed / `battle_killed_per_point` (1,000) + the loser's wounded /
  `battle_wounded_per_point` (2,000), floored, from `battle_ended`'s `killed` and `wounded` (the war-goals contract, unchanged). A
  draw (`winner` `&""`) books nothing. A storm or a siege is occupation.

`WarScore.net(game, a, b)` = `gross(a) − gross(b)` of their live war, 0 with none; `net(b, a) == −net(a, b)`. **`Wars.score(game,
a, b)` (M7's seam) now returns `WarScore.net`**, so M7's stats, M8's `AiKnow.score` and the reminders keep their calls.
`WarScore.breakdown(game, a, b)` gives each side `{held: [{hex, worth}], occupation, battles: [{record, name, points}],
battle_points, capped, gross}` and `net`.

**Bookkeeping** (the `war` phase, `Wars.season`): for each live war, when `net(a, b)` differs from `War.net_last`, `net_last` takes
it and `net_turn` the turn. The AI reads `net_turn` to see a score that has stood still (4.14).

### 4.5 Lots

`DiploCache.lots(game, id)`: every settlement (the settlements family, level 1 or more) the country owns is the seat of a lot; each
of its districts joins the lot of the nearest seat by steps over its own land (as the goal's walk) within `lot_radius` (4), ties
to the higher level, then the lower seat index; a district no seat reaches is a lot alone. Lots are in seat index order; a lot's
name is its seat's place ("Domodossola, 3 districts"). Lots depend only on owners and pieces (dropped on `owners_changed` and on a
`hex_changed` of a settlement). On seed 1480 Milan has 20 lots (Milan's own 5 districts, worth 32; Cremona's 5, worth 15; most
others 1 to 4), Savoy 13, Venice 10, Switzerland 8, Genoa 2.

### 4.6 Peace terms

**The price** of a district for the winner `w` of war `W` (`Peace.price_of(game, W, w, hex)`):

```
in_goal = hex in W.goal when w is the attacker; for the defender, hex is the attacker's and w occupies it (D6)
m       = (price_goal_permille 1000 if in_goal else price_outside_permille 2000)
          x (price_held_permille 500 if w occupies it else 1000) / 1000
          x (price_crest_permille 1250 if DiploCache.reach(w).crossed[hex] else 1000) / 1000
price   = ceil(worth x m / 1000)
deal    = sum of its districts' prices + ceil(ducats / tribute_per_point (12))
```

| A town (worth 8) | Not held | Held |
|---|---|---|
| In the goal | 8 | 4 |
| Outside the goal | 16 | 8 |
| Outside, across a crest | 20 | 10 |

A district is **takeable** by `w` from the loser `l` when `l` owns it, it is not `l`'s capital unless `w` occupies it (D24), and
the deal leaves `l` at least one district (`keep_last_district`, D25).

`Peace.make_peace_check(game, {target, terms, deal, tag})` (replaces M7 4.9's; terms `deal` with no `deal` given means the
actor's Best deal, so a caller may ask for "the best I can get"), in order:

| # | Case | Verdict |
|---|---|---|
| 1 | No target or no terms | "no country given", "no terms given" |
| 2 | Rows 2 to 4 of M7 4.2 | their words |
| 3 | Not at war | "not at war with the %s" |
| 4 | `terms` not `deal`, `white` or `surrender` | "no such terms: deal, white or surrender" |
| 5 | white: the war is younger than `min_war_seasons` (4) | "a white peace needs 4 seasons of war: %d more" |
| 6 | white: the target's net score is over `white_max_net` (10) | "they refuse a white peace while their war score is over 10: it is %+d" |
| 7 | deal: the deal (given, or the Best deal when none is given) holds neither a district nor a ducat | "the deal is empty: choose land or ducats" |
| 8 | deal: the actor's net score is 0 or less | "you are not winning: your war score is %+d; ask for a white peace or surrender" |
| 9 | deal: a district the target does not own | "%s is not the %s's to give" |
| 10 | deal: the target's capital, not occupied by the actor | "their capital, %s, can be taken only while you hold it" |
| 11 | deal: it would take every district of the target | "the %s keeps its last district" |
| 12 | deal: ducats below 0, or over the target's treasury (0 when it is below 0) | "they have only %d ducats" |
| 13 | deal: its price is over the actor's net score | "they refuse: it costs %d, your war score is %d" |
| 14 | deal or white: the target is the human player (`game.player`), the actor is not, and the terms are white or the actor's net is under `enforce_net` (50) | "the %s decides for itself: send it as an offer" |
| 15 | Otherwise (a surrender passes after row 3) | ok |

`make_peace` checks again, then `Peace.apply(game, war, winner, loser, deal, terms, info)`: **deal**: the actor wins with the
given deal; **white**: no winner, an empty deal; **surrender**: the target wins with `Peace.surrender_deal` (the target's goal's
takeable districts when the actor is the defender, none when it is the attacker; and `surrender_share_permille` (200) of the
actor's treasury when it is above 0). `apply`, in order:

1. M7's first step: the war ends (`end_turn`, `terms`; M9 also sets `winner`, `ducats`, `infamy`, `moved`).
2. The deal's districts: `Territory.transfer(game, hexes, winner_id)` (one `owners_changed`; `gained` and `former` written), the
   garrison of each ceded fortress 0 (`Occupation.set_garrison`).
3. Tribute: `Treasury.move(loser, −ducats, &"tribute")` and `Treasury.move(winner, +ducats, &"tribute")`.
4. Infamy: `Brakes.add_infamy(winner, Brakes.infamy_of(game, war, winner, hexes))` (4.9).
5. Opinions: a deal or a surrender: the loser's memory `taken` of the winner, −5 a district, at most −40; a white peace or the
   timer's: both memories `white` +10.
6. The capital: when the loser's capital moved, `Countries.move_capital(game, loser_id)` (its controlled settlement with the most
   people, ties to the higher level then the lower index; with none, its district with the most people) and `capital_moved`.
7. M7's remaining steps: every occupation between the two cleared (`Occupation.release`), armies on land no longer open to them sent
   home, `peace_made`, then `owners_changed` and `controllers_changed`; the war's offers dropped.

`peace_made` gains `winner`, `ducats`, `infamy`, `imposed` (true for an AI's deal on the player at net 50 or more), `offer` (the
accepted offer's id, or 0) and `capital` (the loser's new capital, or `Army.NO_HEX`); its `terms` are `deal`, `white`, `surrender`
or `timer`.

**Best deal** (`Peace.best_deal(game, winner, loser)`; the screen's button and the AI's deal), with `r` the winner's net score:

1. The goal's takeable districts in ascending (price, hex index): each whose price fits `r` is taken and `r` falls by it.
2. The loser's lots (4.5) with their takeable districts outside the goal, by worth x 1000 / price descending, ties to the lower
   seat index: each whole lot that fits is taken.
3. If the deal now takes every district of the loser, the deal's district with the most people (ties: the higher worth, the lower
   index) is dropped and its price returns to `r`.
4. Ducats: `min(max(0, the loser's treasury), r x tribute_per_point)`.

**Truces** (`Wars.truce_until`, M7's, with the length by terms): the newest ended war's `end_turn` + `truce_terms` (12) after a
deal or a surrender, + `truce_white` (8) after a white peace or the timer. In the `war` phase of the truce's last season
(`turn + 1 == truce_until`), `truce_ended {tag: a, others: [b], war, witnesses: every living country}`.

### 4.7 Offers to the player

Only the human player receives offers (D30): an AI loser or winner facing another AI acts at once by the rule; the player facing
an AI acts at once too (the AI accepts by the rule). An AI facing the player whose deal or white peace row 14 refuses sends an
offer instead.

`Peace.offer_peace_check(game, {target, kind, deal, tag})`, in order:

| # | Case | Verdict |
|---|---|---|
| 1 | Rows 1 to 3 of `make_peace_check` | their words |
| 2 | `kind` not `demand`, `white` or `sue` | "no such offer: demand, white or sue" |
| 3 | The target is not the human player | "the %s answers at once: make the peace instead" |
| 4 | An offer between the two is pending | "an offer to the %s is already waiting for an answer" |
| 5 | demand: rows 7 to 13 of `make_peace_check` for the deal | their words |
| 6 | white: row 5 | its words |
| 7 | sue: the actor's net score is 0 or more | "you are not losing: there is no peace to ask for" |
| 8 | Otherwise | ok |

`offer_peace` checks again and appends a `PeaceOffer` (id `next_offer_id`; `from` the actor, `to` the target, `kind`, `deal` (a
demand's), `price`, `net` (the actor's), `made_turn` the turn, `lapse_turn` turn + `offer_seasons` (2), `answer` `&""`); every
offer sets `War.demand_turn`, a demand also `demand_net` (through `Wars.note_offer`, the war's writer); `peace_offered {tag: from, others: [to], offer, kind, war, price, hexes, ducats}`.

`Peace.answer_offer_check(game, {offer, accept, tag})`:

| # | Case | Verdict |
|---|---|---|
| 1 | No offer, or no offer with that id | "no such offer" |
| 2 | The offer is not to the actor | "this offer is not to you" |
| 3 | Answered; lapsed | "the offer was already answered"; "the offer has lapsed" |
| 4 | A request for peace (`sue`) | "a request for peace needs no answer: make peace from the peace screen" |
| 5 | accept: `make_peace_check` as the offerer (its terms and deal) now refuses, row 14 aside | "the offer no longer stands: %s" (that reason) |
| 6 | Otherwise | ok |

`answer_offer`: **accept**: the offer is `accepted`, then `Peace.apply` as the offerer's peace (`terms` deal or white, `info.offer`);
**refuse**: `refused`, the offerer's memory `refused` of the actor −10, `offer_answered {tag: to, others: [from], offer, why:
refused}`. **Lapse** (`Peace.season_offers`, the `war` phase): a pending offer with `turn >= lapse_turn` is `lapsed`,
`offer_answered {why: lapsed}`, no opinion change. Answered and lapsed offers stay 8 seasons for the panel and the report, then
drop; a peace drops its war's offers. **Imposing** (D31): an AI whose net is at least 50 passes row 14 and makes its deal at once
(`imposed: true`).

### 4.8 Relations

`Relations.total(game, a, b)`, `a`'s opinion of `b`: `clamp(memories + standing, −100, 100)`.

**Memories** (stored in the `RelationBook`; each fades `opinion_decay` (2) a season toward 0 in the `relations` phase and is
dropped at 0; at most `opinion_memory` (8) a pair, a ninth replacing the oldest):

| `why` | Whose opinion, of whom | Amount |
|---|---|---|
| `declared` | the target's, of the declarer | −40 (`contain`: −20) |
| `taken` | the loser's, of the winner, at a deal or a surrender | −5 a district, at most −40 |
| `white` | both, at a white peace (or the timer's) | +10 |
| `league` | the member's of the aggressor and the aggressor's of the member, at a join | −30 |
| `refused` | the demander's, of the refuser | −10 |
| `gift` | the receiver's, of the giver | +2 a 10 ducats, at most +30 |
| `dev` | the console | any |

**Standing** (computed when asked; `Relations.standing(game, a, b)` lists them for the hover):

| Term | When | Amount |
|---|---|---|
| `at_war` | `a` and `b` are at war | −30 |
| `truce` | a truce holds between them | −10 |
| `shared_enemy` | both at war with one third country, not with each other | +20 |
| `infamy` | `b`'s infamy | −1 a 2.0 of infamy (−infamy / 20 tenths), at most −30 |

**Words** (`DiplomacyDef.opinion_words`): Hostile −100 to −50, Cold −49 to −15, Neutral −14 to 14, Warm 15 to 49, Friendly 50
to 100.

**Gifts.** `Relations.send_gift_check(game, {target, ducats, tag})`: M7 4.2's rows 1 to 4 ("no country given" ...); "a country
cannot send itself a gift"; "%s is no more"; "not while at war with the %s"; ducats not a multiple of `gift_step` (10) from
`gift_min` (10) to `gift_max` (200): "a gift is 10 to 200 ducats, in tens"; "not enough ducats: %d needed, %d in the treasury";
`Country.gift_turn == turn`: "one gift a season: the next in %s"; else ok. `send_gift`: `Treasury.move` −ducats (`gift`) and
+ducats (`gift`), the memory `gift`, `gift_turn`, `gift_sent {tag, others: [target], ducats, opinion}`.

### 4.9 Infamy and leagues

**Infamy** (`Country.infamy`, tenths; `Brakes` the writer): a peace adds to its winner `Brakes.infamy_of(game, war, winner, hexes)`
= `floor(sum over the districts it gains of worth x rate x infamy_per_worth (5) / 1000)`, with `rate` 500 for a conquest goal's
district or the defender's held attacker land, 0 for a reconquest or contain goal's district, 1,000 outside the goal. It fades
`infamy_decay` (3) a season (to 0). Read as words: under 6.0 "Little", under 18.0 "Noted", under 30.0 "Notorious", 30.0 and over
"Infamous".

| Taken at a peace | Infamy |
|---|---|
| The 9 goal districts of 4.22 (c) (worth 24), conquest | 6.0 |
| A walled town outside the goal (worth 16) | 8.0 |
| Genoa's goal of 4.22 (e) (12 districts, its capital among them, worth 81), conquest | 20.2 |

**Leagues** (`Coalitions`; the owner's "coalitions"). In the `relations` phase, first every open league whose aggressor's infamy is
under `coalition_end` (120) or which is no more ends (`ended_turn`, `coalition_ended`); then, for each living country `x` in id
order with infamy at least `coalition_at` (300), owning at least `coalition_min_permille` (50) of the land districts, and no open
league against it: a `Coalition` forms (`formed_turn`; `eligible` = `x`'s neighbours (M2 `Territory.neighbours`) and every
country that lost districts to `x` at a peace in the last `victim_seasons` (40), alive, in id order), `coalition_formed {tag: x,
coalition, eligible, infamy, witnesses: every living country}`.

`Coalitions.join_coalition_check(game, {against, tag})`: M7 4.2's rows 1 to 4; "no league is open against the %s"; "a league
cannot be against yourself"; "only the %s's neighbours and those it took land from may join"; "you are already in the league
against the %s"; else ok. `join_coalition`: the member appended (join order), the two `league` memories, `coalition_joined {tag,
others: [x], coalition, witnesses: every living country}`. A member keeps its place until the league ends; there is no leaving.

### 4.10 War weariness

`Country.weariness` 0 to 100 (`Brakes` the writer), in the `relations` phase for each living country in id order:

| Case | Change |
|---|---|
| At war, and an army of it stands off its own land, or an enemy's army on its land, or an enemy occupies one of its districts | +4 (`weariness_field`) |
| At war otherwise | +2 (`weariness_idle`) |
| Each battle of this season it lost (`BattleRecord`s of the turn) | +5 (`weariness_battle_lost`) |
| Each of its districts captured this season (`district_captured` of the turn, the chronicle) | +1 (`weariness_district_lost`) |
| No live war | −8 (`weariness_peace`) |

Clamped 0 to 100. Its cost: 3 permille a point of the season's income (D40); +1 unrest a 10 points; the AI seeks a white peace
from 50 (4.14).

### 4.11 Overextension: reach and the national part

**The reach field** (`DiploCache.reach(game, id)`): a Dijkstra from the country's centres over all land (a plain edge 1, a pass
edge 2, a crest edge without a pass shut; ties keep the way without a pass crossing): per hex `steps` (−1 unreached) and `crossed`
(1 when the kept way crossed a pass edge). Centres: the capital on the map and every city (settlements level 5) it owns and
controls; an outside power (capital off the map): every district it owns in the map's first or last column or row. A country's
field is made when first asked and dropped on `owners_changed` of its land, `capital_moved` of it, and a `hex_changed` that makes
or unmakes one of its cities.

**The district's share** (`Brakes.tax_share(game, hex)`, permille, for a district its owner controls):

```
over        = max(0, steps - reach_free (9))          unreached: the floor
loss        = over x reach_tax_permille (25)          halved on home land (D44)
reach_share = max(reach_floor_permille (500), 1000 - loss)
share       = reach_share x unrest_share / 1000       unrest_share: calm 1000, restless and rising 750, defiant 0 (4.12)
```

**The national part** (`Brakes.admin_loss(game, tag)`, permille of the people's taxes): `gained` = the country's districts that
are not home land; `min(admin_max (300), max(0, gained − admin_free (6)) x admin_per_extra (10))`.

On 1480 every share is 1,000 and every national part 0 (home land within 9 steps: 1.1). Savoy's 9 districts of 4.22 (c) are 3 to 5
steps from Turin: no reach loss; the national part 30 (3 %). A Savoyard Verona (10 steps from Turin) would lose 25 permille, a
Venice (14) 125.

### 4.12 Unrest by region part

**Regions on the map** (`MapData.region_id`, `MapData.regions`; D50): every land hex takes the nearest anchor of `regions.json`
(each region's own point, and each city of `cities.json` that `city_region` names), by `((lon − x) cos(lat))² + (lat − y)²` in
degrees, ties to the lower region name; regions with no hex are left out; kept in `regions.json` order. North Italy on the
committed map (`tests/core/test_map_build.gd` pins the builder's table; the task that builds it writes it here if it differs):

| Region | Hexes | Holders in 1480 | Region | Hexes | Holders in 1480 |
|---|---|---|---|---|---|
| Lombardy | 27 | Milan 23, Venice 4 | Valais | 14 | Switzerland 9, Milan 5 |
| Piedmont | 23 | Savoy 21, France 1, Genoa 1 | Savoy | 14 | Savoy 14 |
| Graubünden | 20 | Switzerland 10, Milan 6, Austria 4 | Friuli | 12 | Venice 10, Austria 2 |
| Provence | 20 | France 16, Savoy 4 | Mantua | 12 | Venice 5, Milan 3, Mantua 3, Ferrara 1 |
| Tuscany | 20 | Florence 11, Siena 7, Ferrara 1, Lucca 1 | Aosta | 11 | Savoy 8, Switzerland 3 |
| Trentino | 18 | Austria 10, Venice 5, Milan 3 | Franche-Comté | 10 | France 7, Savoy 3 |
| Emilia | 18 | Ferrara 8, Milan 5, Papal States 4, Lucca 1 | Central Switzerland | 10 | Switzerland 8, Milan 2 |
| Veneto | 17 | Venice 15, Austria 1, Ferrara 1 | Dauphiné | 10 | France 10 |
| Swiss Plateau | 16 | Switzerland 15, Savoy 1 | Romagna | 10 | Papal States 6, Venice 2, Ferrara 1, Florence 1 |
| Tyrol | 16 | Austria 15, Venice 1 | Montferrat | 7 | Savoy 5, Milan 2 |
| Liguria | 16 | Genoa 13, Milan 3 | The Marches | 7 | Papal States 7 |
| Salzburg | 5 | Austria 5 | Umbria | 5 | Papal States 3, Florence 2 |
| Bresse | 2 | Savoy 2 (Geneva) | | | |

25 regions, 57 region parts in 1480. A **region part** is the districts of one region one country owns (D46).

**Unrest** (`Unrest.of_part(game, region, owner_id)`, 0 to 100, computed and cached by version; never stored):

| Term | Value |
|---|---|
| `conquest` | the sum, over each distinct turn `g` at which the part gained districts (their `gained`, within the last 20 seasons), of `max(0, 300 − 15 x (turn − g))`, divided by 10 and floored (30 a peace, fading 1.5 a season); at most `unrest_conquest_cap` (60) |
| `foreign` | +10 when a district of the part is not home land |
| `far` | +1 a step of the part's farthest district beyond `reach_free`; halved (floored) when the part is all home land |
| `crest` | +8 when the part is not all home land and a district of it is `crossed` in its owner's reach field |
| `tax` | `unrest_tax[level]`: Low −10, Normal 0, High +10 |
| `weariness` | the owner's weariness / 10 |
| `garrison` | −10 when an army of the owner with at least `militia_men` (250, M7) stands on a district of the part |
| `castle` | −15 when a fortress (M7) the owner owns and controls, not besieged, stands in the part |
| `capital` | −20 for the part that holds the owner's capital |

Bands: **calm** under `restless_at` (40); **restless** 40 to 69 (the part's districts' people's taxes at `restless_share_permille`
750); **rising** 70 to 99 (also no levy: raising, refilling and garrisons, through `People.levy_check`); **defiant** 100 (taxes 0,
no levy, no work may begin). On 1480 every part is 0: every term but tax is 0 or below on home land, and every tax is Normal.

**Bands and their event** (`Unrest.season`, the `relations` phase): each part's band is compared with its stored band
(`game.unrest_bands`, one byte a region and country slot); a higher band emits `unrest_rising {tag: owner, region, name, band
(&"restless", &"rising", &"defiant"), unrest, hexes, witnesses: [owner]}`; the stored band follows it up or down.

**Worked** (4.22 (c), after Spring 1481's `relations` phase: Savoy's weariness is 14 at the peace and 6 after the phase, a term of
0): Savoy's new Lombard part (8, 6), (7, 7), (9, 6), (8, 7): conquest 30 + foreign 10 = **40**, restless; its
Valais part (Domodossola, Locarno, (6, 5), (6, 6), (7, 4)): 40, or **30** with the Army of Ivrea at Locarno (garrison −10).
Twenty seasons on, the conquest term is gone and both parts are at 10 (foreign) until the land is home at 40 seasons.

### 4.13 The brakes in the economy, the people and the works

| Place (M4 to M7, edited) | M9 |
|---|---|
| `EconomySeason.money_lines`: `tax_people` | Stays the full amount (M4 4.9 with M7's occupied half) |
| new line **`overreach`** (no hex; `count` the districts under 1,000) | −(`tax_people` − the same formula with each district's people x its share / 1,000, over the districts the country owns and controls) − (the shared amount x `admin_loss` / 1,000); not written when 0 |
| new line **`weariness`** | −(`tax_people` + `overreach` + `tax_goods` + `port_dues`) x weariness x `weariness_income_permille` (3) / 1,000, floored; not written when 0 |
| `Treasury.WHY` | appends `tribute`, `gift`, `overreach`, `weariness` (14); `SPENDING` gains `gift`; `left_over` leaves `tribute` out |
| `EconomyPreview` (M4) | The same lines through the same function: the preview still equals the season |
| `People.levy_check` (M5, M7) | after M7's "held by": "%s is rising (unrest %d): no men can be raised there" (the region's name) for a district of a rising or defiant part |
| `Works.build_check`, `upgrade_check` (M3, M7) | after M7's rows: "%s is defiant: no work can begin there" |
| `Military.raise_check` (M6) | refused through `People.levy_check` (no row of its own) |

**Worked**: Savoy at war 6 seasons with an army in the field and one battle lost: weariness 6 x 4 + 5 = 29; a season of 300 ducats
of income loses 300 x 29 x 3 / 1000 = 26 (8.7 %).

### 4.14 The AI (M8's, edited)

M8's frame stands: the AI acts only in `ai_orders`, through `AiKnow` and `Game.act`, with no memory of its own and `Luck.ai` its
only luck. M9 changes four things: the war step picks a reason and a goal; the army step prefers goal land; the peace step follows
the rules below; a new **`diplomacy`** step joins leagues and sends gifts. A seat's turn after M9: `brief`, `peace`,
**`diplomacy`**, `war`, `works_scan` x 2, `works_card` x k, `works_act`, `forces`, `army` x n, `tax`, `done`.

**`AiTemperDef` after M9** (`data/defs/tempers/*.tres`; M8's other fields unchanged; `conqueror` is new and for the soak only):

| Field | What it sets | builder | cautious | steadfast | aggressive | opportunist | conqueror |
|---|---|---|---|---|---|---|---|
| `greed_margin` (new) | net beyond the goal's price before it signs | 0 | 0 | 10 | 25 | 15 | 0 |
| `tired_seasons` (kept, new meaning) | seasons of a still score before it signs a partial deal or a white peace | 8 | 8 | 16 | 24 | 12 | 24 |
| `sue_ratio` (kept) | the enemy's men over its own (permille) above which, not ahead, it takes a white peace | 1,300 | 1,200 | 2,000 | 2,500 | 1,500 | 2,500 |
| `sue_net` (new) | at or under this net it asks the player for peace | −15 | −10 | −40 | −45 | −25 | −60 |
| `surrender_net` (new) | at or under this net it surrenders | −40 | −35 | −70 | −80 | −50 | −90 |
| `sue_after` (new) | the war's age before it sues or surrenders | 6 | 4 | 12 | 16 | 8 | 20 |
| `join_opinion` (new) | it joins a league when its opinion of the aggressor is at or under this | −30 | −20 | −40 | −10 | −20 | −101 (never) |
| `gift_ducats` (new) | the gift it sends a threat that dislikes it (0: none) | 50 | 50 | 0 | 0 | 25 | 0 |
| `infamy_guard` (new) | the infamy, permille of `coalition_at`, it will not pass by a conquest (0: no guard) | 500 | 500 | 700 | 900 | 700 | 0 |
| `soak_only` (new) | a scenario may not assign it | no | no | no | no | no | yes |
| `take_score`, `yield_after` | **removed** (M7's score scale) | | | | | | |

`conqueror`'s M8 fields: reserve 4, payback 20, works at war no, army 9 and 18 permille, upkeep share 500, mix 600, 150, 200,
50, `max_wars` 2, `rest_seasons` 0, `war_chest_seasons` 4, `declare_ratio` 1,000, `busy_bonus` 0, `declare_chance` 1,000,
`attack_ratio` 1,100, `siege_max` 6, `storm_share` 400, `storm_ratio` 1,000, `relief_ratio` 800, `withdraw_ratio` 1,800, `fortify`
no.

**`AiDef` after M9** (`data/defs/ai.tres`; M8's fields kept but `yield_ratio` and `prize_range`, which are removed):

| Field (new) | Value | Used in |
|---|---|---|
| `first_war_turn` | 9 | no AI declaration before Spring 1482 (war-goals' "first 8 seasons") |
| `goal_max_price` | 90 | the largest goal price it aims at (`WarGoals.suggest`'s cap; a small country's whole goal fits) |
| `friendly_no_war` | 50 | no war on a country it is Friendly with |
| `hostile_at`, `hostile_bonus` | −50, 200 | at or under `hostile_at` the declare roll gains `hostile_bonus` |
| `contain_bonus` | 300 | `contain`: the declare ratio's need is this much lower, and the roll gains `hostile_bonus` |
| `opinion_weight` | 5 | the target's value x (1,000 − opinion x 5) / 1,000 |
| `crest_weight` | 600 | the value x 600 / 1,000 when the anchor is across a crest from it |
| `goal_siege_bonus`, `goal_walk_bonus` | 150, 100 | the army's besiege and walk-in scores for goal districts |
| `demand_cooldown` | 4 | seasons between its demands on the player, which need a higher net each time |
| `stalemate_seasons`, `stalemate_band` | 12, 10 | a war this old with its net within 10 either way and a still score ends white |
| `capital_held_malus` | 15 | its net counts 15 worse while the enemy holds its capital |
| `weary_peace` | 50 | from this weariness it takes a white peace when not far behind |
| `gift_every` | 8 | a seat thinks of a gift when `(turn + id) mod 8 == 0` |

**The war step** (`AiWar.war`, M8 4.9 edited). On a think turn with `turn >= first_war_turn` and M8's conditions 1 to 5, each
neighbour `n` in id order is a candidate with:

```
cb      = reconquest if AiKnow.reconquest(t, n) is not empty; else contain if t is in an open league against n; else conquest
goal    = reconquest: those districts; else AiKnow.suggest(t, n, goal_max_price) (no suggestion: not a candidate)
skip    when AiKnow.opinion(t, n) >= friendly_no_war; when cb is conquest and
        (infamy + AiKnow.infamy_of_goal(t, n, cb, goal)) x 1000 > infamy_guard x coalition_at (guard > 0)
ratio   = M x 1000 / max(1, Knowledge.men_of(t, n)), capped at 4,000                       (M8)
need    = declare_ratio - busy_bonus (n at war with a third) - contain_bonus (cb contain)
value   = goal worth x (1000 - opinion x opinion_weight) / 1000 x (crest_weight if the anchor is crossed for t else 1000) / 1000
score   = value x ratio / 1000                                     candidates: ratio >= need and value >= 1
```

The best score (ties: lower id) is drawn against `declare_chance` (+ `hostile_bonus` when the opinion is at or under `hostile_at`
or the reason is `contain`); on a pass, `declare_war {target, cb, anchor}`. M8's prize (open land within `prize_range`) is replaced
by the goal's worth, so `prize_range` is removed from `AiDef`.

**The army step** (M8 4.10 edited): a besiege aim on a fortress in the war's goal scores `goal_siege_bonus` (150) more; a walk-in on
a goal district `goal_walk_bonus` (100) more. Nothing else changes.

**The peace step** (`AiPeace.peace`, replacing M8 4.11). For each live war of the seat `t` against `e`, with `net` =
`AiKnow.net(t, e)`, the war's info (`AiKnow.war_info`: `age`, `still` = turn − `net_turn`, the goal's price `gp` now, `goal_held`,
`capital_lost`, `demand_turn`, `demand_net`, `pending`), the first rule that applies:

| # | Rule | Terms it asks |
|---|---|---|
| 1 | `net > 0` and (`goal_held`, or `net >= gp + greed_margin`, or `still >= tired_seasons` and `net > stalemate_band`) | its Best deal: `make_peace {terms: deal}`; when refused (row 14: the player and a net under 50) and no offer is pending and (`turn − demand_turn >= demand_cooldown` and `net > demand_net`, or no demand yet): `offer_peace {kind: demand, deal}` |
| 2 | `n2 = net − (capital_held_malus if capital_lost)`; `n2 <= surrender_net` and `age >= sue_after` | `make_peace {terms: surrender}` |
| 3 | `n2 <= sue_net` and `age >= sue_after` and no offer pending and `turn − demand_turn >= demand_cooldown` | `offer_peace {kind: sue}` (passes only toward the player; toward an AI nothing) |
| 4 | `abs(net) <= stalemate_band` and (`age >= stalemate_seasons` and `still >= tired_seasons`, or weariness `>= weary_peace`, or the enemy's men x 1,000 > its own x `sue_ratio`, or its treasury under 0) | `make_peace {terms: white}`; when refused by row 14: `offer_peace {kind: white}` |

One terms a war a turn; a refusal of both the peace and the offer ends the step for that war. The AI does not know who the player
is: the checks say where an offer is needed (rows 14 and 3 of 4.6 and 4.7).

**The diplomacy step** (`AiDiplo.diplomacy`, new, one step a seat):

1. **Leagues**: for each open league the seat may join (`AiKnow.leagues_open`), in coalition id order, it joins when its opinion of
   the aggressor is at or under `join_opinion`, or it lost districts to it in the last `victim_seasons`, or the aggressor is one of
   its threats and its opinion of it is under 0; at most one join a season.
2. **A gift**: when `gift_ducats > 0`, `(turn + id) mod gift_every == 0`, its treasury is at least `3 x reserve + gift_ducats`, and
   a threat (in threat order, M8 4.5) not at war with it holds an opinion of the seat under 0: `send_gift {target, ducats:
   gift_ducats}`.

**`AiKnow` grows** (the door; 5.7): `infamy`, `weariness`, `opinion`, `opinion_of_us`, `net`, `war_info`, `reconquest`,
`suggest`, `infamy_of_goal`, `crossed`, `leagues_open`, `in_league_against`, `lost_to`, `best_deal`, `threats_dislike`; `AiBrief` gains `infamy`, `weariness`, `wars`
(`war_info` per live war), `leagues` and `opinions` (its own of each neighbour). **The door's text rule** (M8 4.3) adds the tokens
of 1.2. **The fog** (M8 4.3) adds: a country's opinions of third countries, offers not to the seat and others' weariness are never
read; `test_ai_fog.gd` edits them and finds the same acts.

### 4.15 The season table after M9

`Season.PHASES` (15; `test_season.gd` pins it): **`ai_orders`, `movement`, `battles`, `supply`, `sieges`, `war`, `relations`,
`production`, `income`, `works`, `people`, `stats`, `calendar`, `ready_units`, `vision`**.

| # | Name | Arrives | Reads | Writes (through the owner) |
|---|---|---|---|---|
| 1 | `ai_orders` | M8 (M9 edits) | through `AiKnow` (4.14) | through `Game.act` only: M9's actions too |
| 2 to 5 | `movement`, `battles`, `supply`, `sieges` | M6, M7 | as M7 | as M7; `battles` also `War.battle_a`/`battle_b` (`Wars.book_battle`) |
| 6 | **`war`** | M7 (M9 edits) | wars, offers, occupations, turn | `wars` (`Wars`: `net_last`, `net_turn`; the timer's peace through `Peace.apply`, terms `timer`); `offers` (`Peace.season_offers`); `owner`, `gained`, `former` (none: the timer moves none); `relations` (the timer's `white` memories); events `offer_answered`, `peace_made`, `controllers_changed`, `march_halted`, `truce_ended` |
| 7 | **`relations`** | **M9** | relations, countries, wars, battle records of the turn, the chronicle of the turn, coalitions, owners, `gained`, armies, occupiers, fortresses, unrest | `relations` (`Relations`: the memories fade); `infamy`, `weariness` (`Brakes`); `coalitions`, `next_coalition_id` (`Coalitions`); `unrest_bands` (`Unrest`); events `coalition_ended`, `coalition_formed`, `unrest_rising` |
| 8 | `production` | M4 (M7) | as M7 | as M7 |
| 9 | `trade` | M10 | | |
| 10 | `income` | M4 (M9 edits) | as M7; shares, the national part, weariness | the treasury lines `overreach`, `weariness` (`Treasury`) |
| 11 | `debt` | M12 | | |
| 12 to 19 | `works`, `people`, `research` (M11), `extinction` and `scores` (M12), `stats`, `calendar`, `ready_units`, `vision` | M3 to M12 | as M7; `stats` reads the M9 series' sources; `ready_units`' refills and M7's garrison regrowth go through `People.levy_check` | as M7; `stats` writes the five M9 series |

Why this order: the war phase's peaces (the timer) and lapses come first, so the `relations` phase sees the season's wars as they
end; infamy, weariness and unrest settle before `income` reads them; a league formed in the `relations` phase lets its members
declare at the next idle and the AI in the next `ai_orders`.

### 4.16 Events, witnesses, log lines

**New kinds** (the fields besides `kind` and `turn`; one typed signal each; `Session` drains them after every action and phase):

| Kind | Fields | Emitted by | Notable | Typed signal | Heard by |
|---|---|---|---|---|---|
| `peace_offered` | `tag` (from), `others` ([to]), `offer`, `kind` (`demand`, `white`, `sue`), `war`, `price`, `hexes`, `ducats`, `witnesses` ([from, to]) | `Peace.offer_peace` | yes | `peace_offered(offer, tag, kind)` | `DecisionQueue` (the player the target), `CountryPanel`, `PeaceScreen` (refresh); log, notifications |
| `offer_answered` | `tag` (the answerer), `others` ([from]), `offer`, `why` (`accepted`, `refused`, `lapsed`), `witnesses` ([from, to]) | `Peace.answer_offer`, `Peace.season_offers` | yes | `offer_answered(offer, why)` | `CountryPanel`, `PeaceScreen` (leaves the demand state), `DecisionQueue` (drops an unshown one); log |
| `truce_ended` | `tag` (a), `others` ([b]), `war`, `witnesses` (every living country) | `Wars.season` | yes | `truce_ended(tag, other)` | `CountryPanel`, `MapScene` (Relations bytes); log, notifications (yours), the report |
| `coalition_formed` | `tag` (the aggressor), `coalition`, `eligible`, `infamy`, `witnesses` (every living country) | `Coalitions.season` | yes | `coalition_formed(coalition, against)` | `DecisionQueue` (the player eligible: the invitation; the player the aggressor: the alert), `CountryPanel`, `MapScene` (Relations bytes); log, notifications, ribbons none |
| `coalition_joined` | `tag` (the member), `others` ([aggressor]), `coalition`, `witnesses` (every living country) | `Coalitions.join_coalition` | yes | `coalition_joined(coalition, tag)` | `CountryPanel`, `PageDiplomacy`; log, notifications (a member against you) |
| `coalition_ended` | `tag` (the aggressor), `coalition`, `witnesses` (every living country) | `Coalitions.season` | yes | `coalition_ended(coalition)` | `CountryPanel`, `MapScene`; log |
| `gift_sent` | `tag` (giver), `others` ([receiver]), `ducats`, `opinion`, `witnesses` ([giver, receiver]) | `Relations.send_gift` | yes | `gift_sent(tag, other)` | `CountryPanel`, the top bar's chips (the treasury); log, notifications (to you) |
| `capital_moved` | `tag`, `hex` (new), `from` (old), `witnesses` (every living country) | `Countries.move_capital` | yes | `capital_moved(tag, hex)` | `CapitalMarks`, `CountryLabels`, `MapLabels`, `CountryPanel`; log, notifications, ribbons ("Capital") |
| `unrest_rising` | `tag` (owner), `region`, `name`, `band`, `unrest`, `hexes`, `witnesses` ([owner]) | `Unrest.season` | yes | `unrest_rising(tag, region, band)` | `MapScene` (Relations bytes; the ribbon), `HexPanel`; log, notifications (rising, defiant), ribbons ("Restless", "Rising", "Defiant") |

**Edited kinds**: `war_declared` gains `cb`, `goal`, `anchor`, `worth`; `peace_made` gains `winner`, `ducats`, `infamy`, `imposed`,
`offer`, `capital` (4.6), its `terms` now `deal`, `white`, `surrender`, `timer`. Their consumers stay M7's and M8's, plus
`PeaceScreen` (closes on its war's `peace_made`) and `MapScene` (the goal lines and the Relations bytes).

`Chronicle.NOTABLE` gains the nine new kinds (**twenty-nine**). `Vision.SIGHTED` gains none (M9's kinds carry their witnesses).
`SeasonSummary.COVERED` gains `truce_ended`, `peace_offered`, `offer_answered`, `coalition_formed`, `capital_moved`,
`unrest_rising`.

**Log lines** (`LogLines.line_of`; all with the War filter besides All, and Mine for the player's):

| Kind | The player's line | A witnessed other's |
|---|---|---|
| `war_declared` (edited) | "You declared war on the Duchy of Milan: conquest of Domodossola and 11 more districts." / "The Duchy of Milan declared war on you: conquest of Asti and 11 more." | "The Duchy of Milan declared war on the Republic of Venice (conquest)." muted |
| `peace_made` (edited) | "Peace with the Duchy of Milan: you took 9 districts and 24 ducats." / "...: you gave up Asti (8, 10) and 2 more and 120 ducats." / "...: a white peace." / "...: you surrendered: Asti and 4 more." / "...: imposed by the Duchy of Milan: ..." / "...: the war ended after 40 seasons." | "Peace between the Duchy of Milan and the Republic of Genoa: Milan took 12 districts." muted |
| `peace_offered` | "The Duchy of Milan demands: Asti (8, 10) and 2 more and 40 ducats." / "The Duchy of Milan offers a white peace." / "The Duchy of Milan asks for peace." keyword "Offer", warn; `notify` true | (only to its parties) |
| `offer_answered` | "You refused the Duchy of Milan's demand." / "You accepted the Duchy of Milan's demand." / "The Duchy of Milan's demand lapsed." | |
| `truce_ended` | "The truce with the Duchy of Milan has ended." keyword "Truce", plain; `notify` true | "The truce between Milan and Venice has ended." muted |
| `coalition_formed` | "A league forms against the Duchy of Milan: you may join it." / "A league forms against you: 8 countries may join it." keyword "League", bad when against you; `notify` true | "A league forms against the Duchy of Milan." muted |
| `coalition_joined` | "You joined the league against the Duchy of Milan." / "The Republic of Venice joined the league against you." keyword "League"; `notify` true when against you | "Venice joined the league against Milan." muted |
| `coalition_ended` | "The league against you has ended." / "The league against the Duchy of Milan has ended." | muted |
| `gift_sent` | "You sent 50 ducats to the Republic of Genoa: their opinion of you +10." / "The Republic of Genoa sent you 50 ducats." keyword "Gift", good; `notify` true when to you | (only its parties) |
| `capital_moved` | "Your capital moves to Savona (6, 13)." keyword "Capital", bad; `notify` true; `floating` "Capital" | "The Republic of Genoa's capital moves to Savona (6, 13)." muted |
| `unrest_rising` | "Lombardy is restless (unrest 40): its taxes fall by a quarter." / "... is rising (unrest 72): no men can be raised there." / "... is defiant: it pays nothing." keyword "Unrest", warn or bad; `notify` true for rising and defiant; `floating` "Restless", "Rising", "Defiant" | (only the owner) |

### 4.17 What you may know of others

| Thing | You see |
|---|---|
| Wars, their reasons and goals, war scores and their breakdown, peaces and their terms, truces, leagues and their members | everything, public (M7 D49 extended) |
| Your opinion of others, and theirs of you, with every memory and standing term | exact |
| Two other countries' opinion of each other | its word, only when you know both (`Knowledge.knows`); else "?" |
| Another country's infamy | its word ("Notorious"); the number banded (`Knowledge.band`) when you know it |
| Another country's weariness, unrest, overextension and gifts to third countries | nothing |
| Offers | only to their two parties |
| Your own infamy, weariness, unrest, shares | exact |

`Knowledge.opinion_seen`, `infamy_seen` (5.6) are the one door; the panels, the matrix, the AI's door and the Relations mode use
them or read only the viewer's own pairs.

### 4.18 The season report after M9

`SeasonSummary.SECTIONS`: glance, before, treasury, goods, works, people, armies, war, **diplomacy**, orders, befell, standing (12).

| Id | M9 content |
|---|---|
| `glance` | an **Infamy** chip ("Infamy 6.0 of 30", warn from 18.0) when it is over 0; a **Weariness** chip ("Weariness 29 %") when over 0; M7's War chips now read the net score ("At war with Milan: +18") |
| `before` | the reminders of 4.19 |
| `treasury` | M4's lines with the new rows "Lost to distance and unrest −12", "War weariness −26", "Tribute +24", "Gifts −50" |
| `war` | M7's lines; the score line becomes "War score with Milan +18: you hold 2 of their districts (16) and won 1 battle (2); your goal: 2 of 12 held." |
| `diplomacy` (**new**) | `total` "Relations with 8 countries" (your neighbours); lines from the season's events of the viewer: truces ended ("The truce with the Duchy of Milan has ended."), leagues formed, joined and ended (yours and against you), offers made, answered and lapsed, gifts sent and received, capitals moved, unrest rising; an infamy line when it changed ("Infamy 6.0 (+6.0): a league forms at 30.0."); `sub` "Relations: Milan Hostile (−85) · Genoa Neutral (0) · France Cold (−20)" for the viewer's neighbours. Rank: an offer 50, a league 40, unrest by band (30, 40, 50), a truce 10, a gift its ducats / 10 |
| `orders` | from the action log, the viewer's: "Declared war on the Duchy of Milan: conquest of Domodossola and 11 more.", "Made peace with the Duchy of Milan: 9 districts and 24 ducats.", "Sent a gift of 50 ducats to the Republic of Genoa.", "Joined the league against the Duchy of Milan.", "Refused the Duchy of Milan's demand." |
| `befell` | M8's grouping; others' peaces with their terms, leagues formed and joined, others' capitals moved (public) |

**Quiet** (M7's rule, plus): no M9 event of the viewer and no live offer to it.

### 4.19 Reminders after M9

`Reminders.RULES`: `treasury_empty`, `hunger`, `army_hungry`, `army_stores`, `besieged`, **`demand_open`**, `goods_running_out`,
`winter_halt`, `winter_passes`, `occupied`, `peace_risk` (rewritten), **`restless`**, `war_timer`, **`weary`**,
**`coalition_risk`**, `treasury_falling`, `town_full`, `army_idle`, **`truce_ending`**, **`league_open`**, `free_slot`.

| Rule | When | Severity | Text | Action |
|---|---|---|---|---|
| `demand_open` | an offer of kind demand or white to the player is pending | 2 | "The Duchy of Milan demands Asti (8, 10) and 2 more and 40 ducats; it lapses in 2 seasons." | `[&"peace", tag]`, "Answer" |
| `peace_risk` (M8, rewritten) | for each live war: the enemy's net against the player is at least 40, or at least its goal's price | 2 when 40 or more, else 1 | "The Duchy of Milan's war score against you is +42: at +50 it can impose its peace." / "The Duchy of Milan can demand its war goal (Asti and 11 more): its war score +24 pays for it." | `[&"peace", tag]`, "Show the war" |
| `restless` | a part of yours is restless or worse | 2 for rising or defiant, else 1 | "Lombardy is restless (unrest 40): its taxes fall by a quarter. An army there or a castle calms it." (two or more: "2 of your regions are restless: ...") | `[&"look_at", first hex]`, "Go to Lombardy" |
| `weary` | your weariness is 50 or more | 1 | "War weariness 56: your income falls by 17 %." | `[&"study", &"diplomacy"]`, "Open Diplomacy" |
| `coalition_risk` | your infamy is at least `coalition_warn` (18.0) and no league is open against you | 1 | "Infamy 21.5: at 30.0 your neighbours may form a league against you." | `[&"study", &"diplomacy"]` |
| `truce_ending` | a truce of yours ends within 2 seasons | 0 | "The truce with the Duchy of Milan ends in 2 seasons." | `[&"study", &"diplomacy"]`, "Open Diplomacy" |
| `league_open` | an open league you may join and have not | 0 | "A league is open against the Duchy of Milan: you may join it." | `[&"country", tag]` |

### 4.20 Stats after M9

`Stats.SERIES` gains, appended: `infamy` (tenths), `weariness`, `unrest` (the highest of its parts), `overreach_lost` (the
`overreach` line's ducats, positive), `tribute` (received less paid) (**54** series). M3's `war_score` keeps its call (`Wars.score`
summed over the live wars), so it now sums net scores. The Diplomacy page charts `infamy` and `weariness`; Rankings is unchanged.

### 4.21 Saves and the digest

| Body key | M9 adds | In `Game.digest()` |
|---|---|---|
| `format` | 7 (`SaveFile.FORMAT`; `OLDEST_FORMAT` 7) | no |
| `diplomacy` (**new**) | `{schema: "hexa-godot/diplomacy/1", relations: RelationBook.to_dict(), coalitions: [Coalition.to_dict()], next_coalition_id, offers: [PeaceOffer.to_dict()], next_offer_id, unrest_bands (bytes)}` | `RelationBook.digest()`, each `Coalition` and `PeaceOffer` `digest_text()` in id order, the bands' sha256, joined by `Game.digest` |
| `war` | `hexa-godot/war/2` (`War`: `cb`, `goal`, `anchor`, `battle_a`, `battle_b`, `net_last`, `net_turn`, `demand_turn`, `demand_net`, `winner`, `ducats`, `infamy`); `war/1` refused | `War.digest_text` |
| `map_state` | `map-state/6`: `gained` (int32), `former` (bytes), packed; schema 5 reads with zeros (tests only) | `MapState.digest()` adds both |
| `countries` | `country/5`: `infamy`, `weariness`, `gift_turn`; `country/4` refused | each `digest_text()` |
| `stats` | the five series | `Stats.digest()` |
| `action_log` | M9's actions; the dev records `dev_infamy`, `dev_weariness`, `dev_opinion` | no |
| (not saved) | `game.diplo_cache` (`DiploCache`) | no |

Sizes on the made-up Europe: `gained` 0.49 MB and `former` 122 KB before compression (mostly zero); the memories a few thousand
entries (under 0.2 MB); the bands about 75 KB (1,200 regions x 61 slots); `save_mb` stays 8.

### 4.22 Worked examples

On "Italy, 1480", seed 1480, as Savoy, Normal taxes, calm weather (`weather_odds = [100, 0, 0]` in the tests' defs copy, as M4 to
M8), the AI off (`AiTurn.enabled` false) but where said. `tests/core/test_diplomacy_savoy.gd` pins them on M7's `WarFixture.savoy`
(its armies and its luck-drawn Battle of Alessandria).

**(a) Declaring, Spring 1480.** `declare_war {target: MLO, cb: conquest, anchor: (7, 6)}`: ok; the goal of 4.3 (12 districts, worth
48); Milan's memory `declared` of Savoy −40; Milan's opinion of Savoy −40 + `at_war` −30 = −70, "Hostile". `cb: reconquest`:
"the Duchy of Milan holds no district you lost in the last 80 seasons". `cb: contain`: "you are in no league against the Duchy of
Milan". `anchor: (5, 9)`: "Turin (5, 9) is not the Duchy of Milan's land". The overlay's default (`WarGoals.suggest` without a cap)
would have proposed its own anchor; the test pins it as the build gives it.

**(b) The score, Summer 1480 to Spring 1481** (M7 4.16 (b) and (c)). Summer: Domodossola taken: Savoy's occupation 8. Autumn: the
Battle of Alessandria; Locarno taken (8). When Savoy won (Milan lost 410 men, under 1,000 killed): 2 points; Savoy's gross 18,
Milan's 0, net **+18**. When Milan won: Milan's 2 points, net **+14**.

**(c) The peace, Spring 1481** (Savoy won the battle; net 18). Prices (no goal district is across a crest from Turin): Domodossola and
Locarno held, 4 each; (7, 4), (6, 5), (6, 6), (8, 6), (9, 6), (8, 7) wild, 1 each; the grazing (7, 7) 2; Lugano, Como, Novara 8
each. **Best deal**: the six wild districts (6), the grazing (8), Locarno (12), Domodossola (16); the towns do not fit; no lot
outside the goal costs 2 or less (Milan's cheapest, Lodi's, costs 8); ducats 2 x 12 = **24**. Price 18 = net: "They accept."
`make_peace {terms: deal, deal: {hexes: [those nine], ducats: 24}}`: the nine become Savoy's (`gained` 5, `former` Milan); Milan −24
and Savoy +24 (`tribute`); Savoy's infamy +6.0 (worth 24 at half); Milan's memory `taken` −40 (nine districts, capped); the truce
until Spring 1484; Milan's opinion of Savoy −32 (the declaration, faded 8) −40 −10 (`truce`) −3 (Savoy's infamy 6.0) = **−85**.
Adding Lugano: price 26: "they refuse: it costs 26, your war score is 18". Adding Milan (9, 9): "their capital, Milan (9, 9), can be
taken only while you hold it". Savoy's unrest and shares: 4.12 and 4.11's worked lines.

**(c′) If Milan won the battle** (net 14): Best deal: the six wild (6), the grazing (8), Locarno (12); Domodossola does not fit (16);
ducats 2 x 12 = 24; price 14.

**(d) Copies.** A white peace in Spring 1481 (the war is 4 seasons old; Milan's net −18 ≤ 10): both districts return to Milan; both
memories `white` +10; the truce until Spring 1483. Milan's surrender (`make_peace` by Milan, `terms: surrender`): the whole goal's
takeable districts (all 12) and 20 % of Milan's treasury go to Savoy; infamy +12.0 (48 at half).

**(e) The duel and the demand** (`DiplomacyFixture.duel`: M8's `AiFixture.duel` with Genoa the passive player). Milan's first think
turn from turn 9 is turn 11 (Autumn 1482, `(turn + 5) mod 4 == 0`); its suggestion against Genoa is the Genoese district beside
Milan's land with the richest goal (12 of Genoa's 14 districts, Genoa among them, worth 81, price 81 ≤ 90); `declare_war {cb:
conquest}`. Milan besieges Genoa (M8 4.16 (c)): Genoa falls after four seasons and its land lies open; Milan's net passes 50 with
Genoa held (worth 56) and its Best deal is **imposed** when its rule 1 holds (the goal held, or the net past the goal's price + 15)
(`peace_made {imposed: true}`, the peace alert). `DiplomacyFixture.demand` sets the other path: Milan at war with Genoa, occupying
Savona (6, 13) and four wild districts (worth 12) through the `Occupation` door (tests only), `net_turn` 12 seasons back (rule 1's
still score): Milan's peace step asks `make_peace` (refused by row 14: net 12 < 50), then `offer_peace {kind: demand}` with its Best
deal (price ≤ 12); the player refuses (Milan's opinion of Genoa −10); a new demand waits 4 seasons and a higher net; an unanswered
one lapses in the `war` phase two seasons after it was made; a save made with the demand pending, loaded and answered, gives the digest of the game
answered before the save.

**(f) A league** (`DiplomacyFixture.infamous`: `dev_infamy MLO 300` in Spring 1480). The `relations` phase forms the league against
Milan: Milan holds 52 of 340 districts (153 permille ≥ 50); eligible: Austria, Ferrara, Genoa, Lucca, Mantua, Savoy, Switzerland,
Venice (its neighbours). Savoy joins (`join_coalition {against: MLO}`): Savoy's and Milan's memories `league` −30; Savoy may now
`declare_war {cb: contain, anchor: (7, 6)}`; at its peace, goal land adds no infamy. Milan's infamy fades 0.3 a season: the league
ends in the first `relations` phase with Milan under 12.0 (61 seasons later at 0.3 a season, unless Milan takes more).

**(g) Weariness and unrest.** Savoy at war 6 seasons with an army on Milan's land and one battle lost: 29 (4.13). Savoy's parts after
(c): 4.12. A fixture then sets Savoy's taxes High and its weariness 100 (`dev_weariness`): the Lombard part is 30 + 10 + 10 + 10 =
60, restless; a second peace a season later that gives the part another district makes the conquest term (285 + 300) / 10 = 58:
88, rising, and `raise` at (8, 6) is refused with "Lombardy is rising (unrest 88): no men can be raised there".

### 4.23 The soak: wars end by terms, and no runaway winner

`godot/tools/soak.gd` (M8) gains a suite, five invariants and the ranges below. **A runaway winner** is a country that, at any
season of any game, owns at least **400 permille of the land districts** (136 of 340 on north Italy). "No runaway winner" is: the
invariant `runaway` holds in every game of the `ai` and `conqueror` suites, and the land ranges below hold.

| Suite | Games | Seasons | What | Quick |
|---|---|---|---|---|
| `ai`, `passive`, `europe` | M8's | M8's | M8's | M8's |
| **`conqueror`** (new) | seeds 1 to 20 | 80 | north Italy; the seat `playable[(seed − 1) mod 10]` (M8's order) played by the AI with the `conqueror` temperament (`AiPlayers.attach(game, passive, {tag: &"conqueror"})`), the other 12 with their own | seed 1 x 12 |

**Invariants added** (`tests/core/invariants.gd`):

| Name | Holds after every season |
|---|---|
| `runaway` | no country owns 400 permille or more of the land districts |
| `peaces` | every `peace_made` of the season moved exactly its deal's districts; its loser kept at least one district; its tribute lines pair |
| `offers` | every pending offer is to `game.player`, at most one a pair, and none whose `lapse_turn` has passed |
| `leagues` | at most one open league against a country; every member eligible; every open league's aggressor at or over `coalition_end` |
| `relations` | every opinion −100 to 100; at most 8 memories a pair; every infamy at least 0; every weariness 0 to 100 |

**Ranges** (over the suite's games at its last season; starting values the tuning task measures and keeps, or changes with Opus's
word in its pull request):

| Measure | Suite | Range |
|---|---|---|
| ended wars ended by the timer | ai | ≤ 10 % |
| ended wars ended by a deal or a surrender | ai | ≥ 50 % |
| the median length of an ended war | ai | ≤ 16 seasons |
| the largest country's share of the land | ai | median ≤ 24 %, every game ≤ 33 % (replaces M8's 30 % and 60 %) |
| the conqueror's land at season 80 | conqueror | median ≤ max(2 x start, start + 12); every game ≤ max(2.5 x start, start + 20) |
| games with a league formed | conqueror | ≥ 10 of 20 |
| leagues formed a game | ai | median 0 to 3 |
| the most infamous country's infamy | ai | median ≤ 30.0 |
| demands to the player | passive | median ≥ 1 a game |
| a war declared on the passive seat | passive | ≥ 15 of 20 (M8) |
| the passive seat loses a war (a deal or a surrender against it moving ≥ 1 district) | passive | ≥ 5 of 20 (M8's; deals are imposed at 50, the seat never answers) |
| M8's other ranges | as M8 | as M8 |

The summary's per-country table gains: infamy, weariness, leagues against it, deals won and lost, ducats of tribute, unrest's worst
part. **CI**: the nightly `soak` matrix gains `conqueror` 1-20 (judged in its own run).

---

## 5. Interfaces

Layers after M8: `defs`, `state`, `systems`, `game`, `views`, `ai`, `shell`. `core/` makes no engine calls; M9's rules take no
luck. New files are marked **new**; "(M2)" to "(M8)" name pieces those milestones build. Every amount is an `int`, every rate a
permille; infamy in tenths. Systems never call `Words`: their words name a hex by `Military.hex_text` (M6), a country by "the " +
its long name, a region by `MapData.regions[r].name`, a date by `Calendar.date_text` (M3).

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/diplomacy_def.gd  (new): every number of 4.2 to 4.13, one inspector
class_name DiplomacyDef extends Resource
const REASONS: Array[StringName] = [&"conquest", &"reconquest", &"contain"]
const TERMS: Array[StringName] = [&"deal", &"white", &"surrender", &"timer"]
# worth and the score
@export var worth_wild := 1
@export var worth_per_fortress := 2
@export var worth_capital := 40
@export var score_max := 100
@export var battle_win := 2
@export var battle_killed_per_point := 1000
@export var battle_wounded_per_point := 2000
@export var battle_cap := 25
# goals and lots
@export var goal_districts := 12
@export var anchor_range := 3
@export var reconquest_max := 30
@export var reconquest_seasons := 80
@export var lot_radius := 4
# prices and terms
@export var price_goal_permille := 1000
@export var price_outside_permille := 2000
@export var price_held_permille := 500
@export var price_crest_permille := 1250
@export var tribute_per_point := 12
@export var surrender_share_permille := 200
@export var keep_last_district := true
@export var min_war_seasons := 4
@export var white_max_net := 10
@export var enforce_net := 50
@export var offer_seasons := 2
@export var offer_keep_seasons := 8
@export var truce_terms := 12
@export var truce_white := 8
# relations
@export var opinion_declared := -40
@export var opinion_declared_contain := -20
@export var opinion_per_district := -5
@export var opinion_taken_cap := -40
@export var opinion_white := 10
@export var opinion_league := -30
@export var opinion_refused := -10
@export var opinion_gift_per_10 := 2
@export var opinion_gift_cap := 30
@export var opinion_at_war := -30
@export var opinion_truce := -10
@export var opinion_shared_enemy := 20
@export var opinion_infamy_tenths := 20      # -1 opinion a 20 tenths of the other's infamy
@export var opinion_infamy_cap := -30
@export var opinion_decay := 2
@export var opinion_memory := 8
@export var opinion_words: Array[Dictionary] = []   # [{word: "Hostile", from: -100}, {"Cold", -49}, {"Neutral", -14},
	# {"Warm", 15}, {"Friendly", 50}] (ascending)
@export var gift_min := 10
@export var gift_max := 200
@export var gift_step := 10
# infamy and leagues (tenths)
@export var infamy_per_worth := 5
@export var infamy_goal_permille := 500
@export var infamy_decay := 3
@export var infamy_words: Array[Dictionary] = []    # [{word: "Little", from: 0}, {"Noted", 60}, {"Notorious", 180},
	# {"Infamous", 300}]
@export var coalition_at := 300
@export var coalition_end := 120
@export var coalition_warn := 180
@export var coalition_min_permille := 50
@export var victim_seasons := 40
# weariness
@export var weariness_field := 4
@export var weariness_idle := 2
@export var weariness_battle_lost := 5
@export var weariness_district_lost := 1
@export var weariness_peace := 8
@export var weariness_max := 100
@export var weariness_income_permille := 3
# reach and the national part
@export var reach_free := 9
@export var reach_pass_steps := 2
@export var reach_tax_permille := 25
@export var reach_floor_permille := 500
@export var home_seasons := 40
@export var admin_free := 6
@export var admin_per_extra := 10
@export var admin_max := 300
# unrest
@export var unrest_conquest := 30
@export var unrest_conquest_decay_tenths := 15
@export var unrest_conquest_seasons := 20
@export var unrest_conquest_cap := 60
@export var unrest_foreign := 10
@export var unrest_far_per_step := 1
@export var unrest_crest := 8
@export var unrest_tax: PackedInt32Array            # by tax level: -10, 0, 10
@export var unrest_weariness_div := 10
@export var unrest_garrison := -10
@export var unrest_castle := -15
@export var unrest_capital := -20
@export var restless_at := 40
@export var rising_at := 70
@export var defiant_at := 100
@export var restless_share_permille := 750
@export var defiant_share_permille := 0
func truce_of(terms: StringName) -> int          # deal, surrender: truce_terms; white, timer: truce_white
func opinion_word(value: int) -> String          # the last word whose from is at most value
func infamy_word(tenths: int) -> String
func band_of(unrest: int) -> int                 # 0 calm, 1 restless, 2 rising, 3 defiant
func validate() -> Array[String]   # every count >= 0; permilles 0..10000 where a multiplier, 0..1000 where a share; opinion
	# amounts -100..100 with the signs of 4.8; the two word lists ascending from their floors; unrest_tax sized 3;
	# restless_at < rising_at < defiant_at <= 100; coalition_end < coalition_warn < coalition_at; gift_min <= gift_max, both
	# multiples of gift_step; white_max_net < enforce_net <= score_max; truce_white, truce_terms 1..40; reach_floor 0..1000

# core/defs/family_def.gd  (M3 to M7, edit)
@export var worth: PackedInt32Array   # per level (4.2): settlements 0, 3, 4, 8, 12, 15; castles 0, 1, 1, 1; each goods family and
	# the harbour 0, 2, 3, 4. validate(): sized TOP_LEVEL + 1 when set, each 0..100, [0] 0; every family sets it

# core/defs/war_def.gd  (M7, edit): removes peace_min_seasons, take_score, take_score_weak, white_score_min, capital_score and
#   truce_seasons (DiplomacyDef's min_war_seasons, the deal rows, worth_capital, truce_of); validate() loses their rows; the
#   removal comes once nothing reads them (the plan's V19, after M7's make_peace and M8's peace_risk are replaced)

# core/defs/map_data.gd  (M1, edit)
@export var region_id: PackedInt32Array      # per hex: an index into regions; -1 at sea
@export var regions: Array[Dictionary] = []  # {name: String, tag: String (the 1480 holder of regions.json, or ""), lon, lat}
func region_of(hex: Vector2i) -> int         # -1 at sea and off the map
# validate(): region_id sized cols x rows; every land hex 0..regions.size() - 1, every sea hex -1; every region has a hex
# digest(): adds region_id and every region's name, in order

# core/defs/game_defs.gd  (M2 to M8, edit)
@export var diplomacy: DiplomacyDef = null   # external: data/defs/diplomacy.tres
# tempers: M8's five and conqueror (soak_only); validate() adds: diplomacy set and valid; six tempers, unique keys

# core/defs/ai_def.gd, ai_temper_def.gd  (M8, edit): the fields of 4.14 (AiDef: 16 added, yield_ratio and prize_range removed;
#   AiTemperDef: greed_margin, sue_net, surrender_net, sue_after, join_opinion, gift_ducats, infamy_guard, soak_only added,
#   take_score and yield_after removed); validate() for each: greed 0..100, nets -100..0 with surrender_net <= sue_net, ages
#   0..80, join_opinion -101..100, gift 0..200 in tens, infamy_guard 0..1000
# core/defs/scenario_def.gd  (M2, M8, edit): validate() refuses a soak_only temper ("a soak temperament in a scenario")
```

### 5.2 State (`core/state/`)

```gdscript
# core/state/war.gd  (M7, edit): schema "hexa-godot/war/2" (war/1 refused)
const NO_HEX := Vector2i(-1, -1)
var cb: StringName = &"conquest"
var goal: PackedInt32Array            # hex indices, in the goal walk's order (4.3); never changes
var anchor: Vector2i = NO_HEX
var battle_a: int = 0                 # a's battle points, uncapped (WarScore caps)
var battle_b: int = 0
var net_last: int = 0                 # net(a, b) at the last war phase
var net_turn: int = 0                 # the turn net_last last changed
var demand_turn: int = 0              # the turn of the last offer on this war (0 none)
var demand_net: int = 0               # the demander's net then
var winner: StringName = &""          # at its peace: the side that gained (deal, surrender), &"" white or timer
var ducats: int = 0                   # tribute paid at its peace
var infamy: int = 0                   # tenths its winner gained
func in_goal(hex_index: int) -> bool
# terms: &"deal", &"white", &"surrender", &"timer"; digest_text() appends every new field in this order

# core/state/country.gd  (M2 to M7, edit): schema "hexa-godot/country/5" (country/4 refused)
var infamy: int = 0                   # tenths; Brakes only
var weariness: int = 0                # 0..100; Brakes only
var gift_turn: int = 0                # the turn of its last gift; Relations only
# digest_text() appends "|infamy|weariness|gift_turn"

# core/state/map_state.gd  (M1 to M7, edit): schema "hexa-godot/map-state/6"
var gained: PackedInt32Array          # per hex: the turn its owner last changed (0: since the start). Territory only
var former: PackedByteArray           # per hex: the owner before that change (0: none). Territory only
# create() sizes both; duplicate_state() copies them; to_dict() adds them packed; from_dict() reads 6, and 1 to 5 with zeros;
# digest() adds them after M7's three

# core/state/relation_book.gd  (new): the memories of 4.8
class_name RelationBook extends RefCounted
const SCHEMA := "hexa-godot/relations/1"
var memories: Array[Dictionary] = []  # {a: int (whose opinion), b: int (of whom), why: StringName, amount: int, turn: int},
	# ordered by (a, b, turn, why)
func add(a: int, b: int, why: StringName, amount: int, turn: int, keep: int) -> void   # a (keep + 1)th of the pair drops
	# the pair's oldest
func of_pair(a: int, b: int) -> Array[Dictionary]
func sum(a: int, b: int) -> int
func fade(step: int) -> int           # every amount moves step toward 0; zeros dropped; returns how many dropped
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> RelationBook   # null on a wrong schema or type
func digest() -> String

# core/state/coalition.gd  (new)
class_name Coalition extends RefCounted
const SCHEMA := "hexa-godot/coalition/1"
var id: int
var against: StringName
var formed_turn: int
var ended_turn: int = 0               # 0 while open
var eligible: PackedStringArray       # id order, fixed at formation
var members: PackedStringArray        # join order
func open() -> bool
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> Coalition
func digest_text() -> String

# core/state/deal.gd  (new): what a peace moves
class_name Deal extends RefCounted
var hexes: PackedInt32Array           # the loser's districts to the winner, ascending
var ducats: int = 0
static func from_args(d: Dictionary, map: MapData) -> Deal   # {hexes: Array[Vector2i], ducats: int}; null when malformed
func to_args(map: MapData) -> Dictionary
func is_empty() -> bool
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> Deal
func digest_text() -> String

# core/state/peace_offer.gd  (new)
class_name PeaceOffer extends RefCounted
const SCHEMA := "hexa-godot/peace-offer/1"
var id: int
var war: int
var from: StringName
var to: StringName
var kind: StringName                  # &"demand", &"white", &"sue"
var deal: Deal = null                 # a demand's
var price: int = 0
var net: int = 0                      # the offerer's net at the offer
var made_turn: int
var lapse_turn: int
var answer: StringName = &""          # &"" pending, &"accepted", &"refused", &"lapsed"
var answered_turn: int = 0
func pending() -> bool
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> PeaceOffer
func digest_text() -> String

# core/state/stats.gd  (M3 to M7, edit): SERIES appends "infamy", "weariness", "unrest", "overreach_lost", "tribute" (54)

# core/game/game.gd  (M1 to M8, edit; the fields)
var relations: RelationBook = RelationBook.new()   # Relations
var coalitions: Array[Coalition] = []              # Coalitions; id order
var next_coalition_id: int = 1                     # Coalitions
var offers: Array[PeaceOffer] = []                 # Peace; id order
var next_offer_id: int = 1                         # Peace
var unrest_bands: PackedByteArray                  # Unrest: regions x (countries + 1), the band of each part last season
var diplo_cache: DiploCache = DiploCache.new()     # the door's derived cache; not saved, not in the digest
```

### 5.3 Systems (`core/systems/`)

```gdscript
# core/systems/diplo_cache.gd  (new): derived facts, rebuilt on demand, never saved
class_name DiploCache extends RefCounted
func reach(game: Game, id: int) -> Dictionary        # {steps: PackedInt32Array (-1 unreached), crossed: PackedByteArray} (4.11)
func lots(game: Game, id: int) -> Array[Dictionary]  # [{seat: int (hex index), hexes: PackedInt32Array}] seat order (4.5)
func lot_of(game: Game, hex: Vector2i) -> int        # the seat's hex index; -1 none
func parts(game: Game) -> Dictionary                 # (region x 256 + owner id) -> PackedInt32Array, ascending
func unrest_store(game: Game) -> Dictionary          # the parts' keys -> {value, terms: Array[Dictionary]}: filled by Unrest,
	# emptied when game.version has moved since it was filled
func forget_owners(ids: PackedInt32Array) -> void    # owners_changed (its tag and others): lots, parts, the reach of those ids
func forget_reach(id: int) -> void                   # capital_moved, a city made or unmade
func forget_pieces() -> void                         # hex_changed of a settlement: lots
func clear() -> void

# core/systems/war_goals.gd  (new): reasons, goals, worth
class_name WarGoals extends RefCounted
const OWNS: Array[String] = []
static func worth_of(game: Game, hex: Vector2i) -> int                          # 4.2
static func goal_of(game: Game, target_id: int, anchor: Vector2i) -> PackedInt32Array   # 4.3, walk order
static func reconquest_of(game: Game, tag: StringName, target: StringName) -> PackedInt32Array
static func suggest(game: Game, tag: StringName, target: StringName, max_price: int = 1000000) -> Dictionary
	# {anchor, goal, worth, price, crossed} or {} (4.3)
static func reason_check(game: Game, tag: StringName, target: StringName, cb: StringName, anchor: Vector2i) -> Dictionary
	# rows 10 to 14 of 4.3 (with the defaults of a missing cb and anchor)
static func crossed(game: Game, id: int, hex: Vector2i) -> bool                 # diplo_cache.reach(id).crossed
static func reach_steps(game: Game, id: int, hex: Vector2i) -> int
static func goal_worth(game: Game, goal: PackedInt32Array) -> int

# core/systems/war_score.gd  (new): pure
class_name WarScore extends RefCounted
const OWNS: Array[String] = []
static func occupation(game: Game, war: War, side: StringName) -> int
static func gross(game: Game, war: War, side: StringName) -> int
static func net(game: Game, a: StringName, b: StringName) -> int               # 0 with no live war
static func breakdown(game: Game, a: StringName, b: StringName) -> Dictionary   # 4.4
static func battle_points(game: Game, loser_killed: int, loser_wounded: int) -> int

# core/systems/wars.gd  (M7, edit)
static func score(game: Game, a: StringName, b: StringName) -> int    # WarScore.net (the seam's new body)
static func truce_until(game: Game, a: StringName, b: StringName) -> int   # end_turn + DiplomacyDef.truce_of(terms)
static func note_offer(game: Game, war: War, kind: StringName, net: int) -> void   # demand_turn (every kind), demand_net (demand)
# declare_war_check: rows 10 to 14 through WarGoals.reason_check; declare_war: cb, goal, anchor, the declared memory, the event's
#   new fields; book_battle: + the winner's battle points; season (the war phase): the score's bookkeeping, Peace.season_offers,
#   the timer (through Peace.apply, terms timer), truce_ended; end_war(game, war, terms, actor) keeps M7's steps and is called by
#   Peace.apply; make_peace_check and make_peace leave Wars (the action table points at Peace's)

# core/systems/peace.gd  (new)
class_name Peace extends RefCounted
const OWNS: Array[String] = ["offers", "next_offer_id"]
const TERMS: Array[StringName] = [&"deal", &"white", &"surrender"]
const KINDS: Array[StringName] = [&"demand", &"white", &"sue"]
static func price_of(game: Game, war: War, winner: StringName, hex: Vector2i) -> int
static func price(game: Game, war: War, winner: StringName, deal: Deal) -> int
static func takeable(game: Game, war: War, winner: StringName, hex: Vector2i) -> Dictionary   # {ok, reason}
static func goal_price(game: Game, war: War, side: StringName) -> int          # the side's goal at today's prices
static func goal_held(game: Game, war: War, side: StringName) -> bool
static func best_deal(game: Game, winner: StringName, loser: StringName) -> Deal   # 4.6; empty when net <= 0
static func surrender_deal(game: Game, war: War, loser: StringName) -> Deal
static func make_peace_check(game: Game, args: Dictionary) -> Dictionary       # {target, terms, deal, tag}; 4.6
static func make_peace(game: Game, args: Dictionary) -> Dictionary
static func offer_peace_check(game: Game, args: Dictionary) -> Dictionary      # {target, kind, deal, tag}; 4.7
static func offer_peace(game: Game, args: Dictionary) -> Dictionary
static func answer_offer_check(game: Game, args: Dictionary) -> Dictionary     # {offer, accept, tag}
static func answer_offer(game: Game, args: Dictionary) -> Dictionary
static func pending(game: Game, a: StringName, b: StringName) -> PeaceOffer    # either direction; null none
static func apply(game: Game, war: War, winner: StringName, loser: StringName, deal: Deal, terms: StringName,
		info: Dictionary) -> void     # 4.6's seven steps; info {offer, imposed}
static func season_offers(game: Game) -> void      # lapses; drops answered offers older than offer_keep_seasons

# core/systems/relations.gd  (new)
class_name Relations extends RefCounted
const OWNS: Array[String] = ["relations", "gift_turn"]
static func remember(game: Game, of_id: int, toward_id: int, why: StringName, amount: int) -> void   # the only writer
static func total(game: Game, a: StringName, b: StringName) -> int             # a's opinion of b (4.8)
static func standing(game: Game, a: StringName, b: StringName) -> Array[Dictionary]   # [{why, amount}]
static func memories(game: Game, a: StringName, b: StringName) -> Array[Dictionary]
static func send_gift_check(game: Game, args: Dictionary) -> Dictionary         # {target, ducats, tag}
static func send_gift(game: Game, args: Dictionary) -> Dictionary
static func season(game: Game) -> void                                          # the memories fade

# core/systems/coalitions.gd  (new)
class_name Coalitions extends RefCounted
const OWNS: Array[String] = ["coalitions", "next_coalition_id"]
static func open_against(game: Game, tag: StringName) -> Coalition              # null none
static func is_member(game: Game, tag: StringName, against: StringName) -> bool
static func eligible(game: Game, tag: StringName, against: StringName) -> bool
static func may_join(game: Game, tag: StringName) -> Array[Coalition]           # open, eligible, not yet a member
static func join_coalition_check(game: Game, args: Dictionary) -> Dictionary    # {against, tag}
static func join_coalition(game: Game, args: Dictionary) -> Dictionary
static func season(game: Game) -> void                                          # end, then form (4.9)

# core/systems/brakes.gd  (new): infamy, weariness, the shares
class_name Brakes extends RefCounted
const OWNS: Array[String] = ["infamy", "weariness"]
static func infamy_of(game: Game, war: War, winner: StringName, hexes: PackedInt32Array) -> int   # 4.9
static func add_infamy(game: Game, tag: StringName, tenths: int) -> void
static func home(game: Game, hex: Vector2i) -> bool                             # D44
static func gained_count(game: Game, tag: StringName) -> int
static func tax_share(game: Game, hex: Vector2i) -> int                         # 4.11
static func admin_loss(game: Game, tag: StringName) -> int                      # 4.11
static func weariness_loss(game: Game, tag: StringName) -> int                  # weariness x 3 permille
static func season(game: Game) -> void                                          # infamy fades; weariness (4.10)

# core/systems/unrest.gd  (new)
class_name Unrest extends RefCounted
const OWNS: Array[String] = ["unrest_bands"]
const BANDS: Array[StringName] = [&"calm", &"restless", &"rising", &"defiant"]
static func of_part(game: Game, region: int, owner_id: int) -> int
static func terms_of(game: Game, region: int, owner_id: int) -> Array[Dictionary]   # [{why, amount}] (4.12)
static func of_hex(game: Game, hex: Vector2i) -> int                            # its owner's part
static func band_at(game: Game, hex: Vector2i) -> int
static func share(game: Game, hex: Vector2i) -> int                             # 1000, 750 or 0
static func season(game: Game) -> void                                          # bands and unrest_rising
static func setup(game: Game) -> void                                           # unrest_bands sized, all 0 (new_scenario)

# core/systems/territory.gd  (M2, edit): OWNS ["owner", "gained", "former"]; transfer() writes gained = game.turn and former =
#   the old owner for each changed hex, and calls game.diplo_cache.forget_owners through Game.emit (owners_changed)
# core/systems/countries.gd  (M2, M8, edit): OWNS gains "capital"
static func move_capital(game: Game, id: int) -> Vector2i    # 4.6 step 6; emits capital_moved; NO_HEX when it owns nothing
# core/systems/treasury.gd  (M4, M6, edit): WHY appends &"tribute", &"gift", &"overreach", &"weariness"; SPENDING gains &"gift";
#   left_over() leaves out tribute
# core/systems/economy_season.gd  (M4 to M7, edit): money_lines() adds overreach and weariness (4.13)
# core/systems/people.gd  (M5 to M7, edit): levy_check gains the rising row (4.13)
# core/systems/works.gd  (M3 to M7, edit): build_check, upgrade_check gain the defiant row (4.13)
# core/systems/stats_system.gd  (M3 to M7, edit): the five series (4.20)
```

**OWNS after M9** (`tests/core/test_owns.gd` diffs `Snapshot.of` around every action and phase):

| Field | Written by | In an action | In a phase |
|---|---|---|---|
| `wars`, `next_war_id` (and the new `War` fields) | `Wars` | `declare_war`; `make_peace` and `answer_offer` (through `Wars.end_war`) | `battles` (`book_battle`), `war` |
| `offers`, `next_offer_id` | `Peace` | `offer_peace`, `answer_offer`, `make_peace` (drops the war's) | `war` |
| `relations` | `Relations` (`remember`) | `declare_war`, `make_peace`, `answer_offer`, `send_gift`, `join_coalition` | `war` (the timer's white), `relations` |
| `gift_turn` | `Relations` | `send_gift` | no |
| `coalitions`, `next_coalition_id` | `Coalitions` | `join_coalition` | `relations` |
| `infamy`, `weariness` | `Brakes` | `make_peace`, `answer_offer` (infamy) | `relations` |
| `unrest_bands` | `Unrest` | no | `relations` |
| `owner`, `gained`, `former` | `Territory` | `make_peace`, `answer_offer` | no (the timer moves none) |
| `capital` | `Countries` | `make_peace`, `answer_offer` | no |
| `treasury`, ledgers | `Treasury` | `make_peace`, `answer_offer` (tribute), `send_gift` | `income` (overreach, weariness) |
| everything of M7's and M8's tables | as M7 5.3 and M8 5.4 | | |
| `events`, `action_log`, `chronicle`, `version`, `view_cache`, `districts`, `sight`, `supplies`, `war_cache`, `diplo_cache` | `Game` (`DOOR_FIELDS` gains `diplo_cache`) | yes | yes |

### 5.4 Game, the action table, the season, saves (`core/game/`)

```gdscript
# core/game/game.gd  (M1 to M8, edit)
const DOOR_FIELDS: Array[String] = ["events", "action_log", "chronicle", "version", "view_cache", "districts", "sight",
	"supplies", "war_cache", "diplo_cache"]
func emit(event: Dictionary) -> void      # M7's, plus: owners_changed calls diplo_cache.forget_owners(the ids of its tag and
	# others); capital_moved calls forget_reach(id); hex_changed of a settlement calls forget_pieces() (and forget_reach of its
	# owner when a city is made or unmade)
func dev_infamy(tag: StringName, tenths: int) -> void      # logged {turn, action: "dev_infamy", args}; Brakes.add_infamy
func dev_weariness(tag: StringName, value: int) -> void    # logged; Brakes' writer
func dev_opinion(a: StringName, b: StringName, amount: int) -> void   # logged; Relations.remember(..., &"dev", amount)
# new_scenario: after Occupation.setup and Military.setup_start_armies: Unrest.setup
# digest(): M8's string + "|" + relations.digest() + "|" + each coalition's digest_text() + "|" + each offer's digest_text()
#   (id order) + "|" + the sha256 of unrest_bands (all state-level, so the digest exists from task V2 on)

# core/game/actions.gd  (M3 to M8, edit)
const NAMES: Array[String] = ["build", "upgrade", "clear", "cancel_work", "choose_country", "set_tax", "raise", "march", "halt",
	"continue_march", "split_army", "merge_armies", "disband", "declare_war", "make_peace", "storm", "set_standing",
	"offer_peace", "answer_offer", "send_gift", "join_coalition"]
#   declare_war {target, cb, anchor, tag}   make_peace {target, terms, deal: {hexes, ducats}, tag}
#   offer_peace {target, kind, deal, tag}   answer_offer {offer, accept, tag}   send_gift {target, ducats, tag}
#   join_coalition {against, tag}
# pair_of: make_peace, offer_peace, answer_offer -> Peace's; send_gift -> Relations'; join_coalition -> Coalitions'

# core/game/season.gd  (M3 to M8, edit)
const PHASES: Array[StringName] = [&"ai_orders", &"movement", &"battles", &"supply", &"sieges", &"war", &"relations",
	&"production", &"income", &"works", &"people", &"stats", &"calendar", &"ready_units", &"vision"]
# run_phase(relations): Relations.season, Brakes.season, Coalitions.season, Unrest.season, in that order

# core/game/replay.gd  (M3, M8, edit): plays dev_infamy, dev_weariness, dev_opinion records through their Game functions
# core/game/snapshot.gd  (M3 to M8, edit): the diplomacy key, war/2, country/5, map-state/6; restore type-checks every new
#   field, refuses war/1 and country/4, rebuilds diplo_cache empty
# core/game/save_file.gd  (M3 to M8, edit): FORMAT := 7; OLDEST_FORMAT := 7
```

### 5.5 Events and Session (`shell/autoload/`)

```gdscript
# shell/autoload/events.gd  (edit): added signals
signal peace_offered(offer: int, tag: StringName, kind: StringName)
signal offer_answered(offer: int, why: StringName)
signal truce_ended(tag: StringName, other: StringName)
signal coalition_formed(coalition: int, against: StringName)
signal coalition_joined(coalition: int, tag: StringName)
signal coalition_ended(coalition: int)
signal gift_sent(tag: StringName, other: StringName)
signal capital_moved(tag: StringName, hex: Vector2i)
signal unrest_rising(tag: StringName, region: int, band: StringName)

# shell/autoload/session.gd  (edit): drain() sends the nine kinds to their signals, then chronicled (M3) for the notable ones;
#   last_phase_ms gains relations
```

### 5.6 Views (`core/views/`, pure)

```gdscript
# core/views/knowledge.gd  (M3 to M8, edit): the fog of 4.17
static func opinion_seen(game: Game, viewer: StringName, a: StringName, b: StringName) -> Dictionary
	# {access (&"exact", &"word", &"hidden"), value (exact only), word ("?" when hidden)}; exact when viewer is a or b, or &""
static func infamy_seen(game: Game, viewer: StringName, tag: StringName) -> Dictionary
	# {exact: bool, value (exact, or Knowledge.band of it when known, else -1), word}
static func own_brakes(game: Game, viewer: StringName, tag: StringName) -> bool   # true only for viewer's own (or &"")

# core/views/words.gd  (M3 to M8, edit)
static func opinion_word(game: Game, value: int) -> String          # DiplomacyDef.opinion_word
static func infamy_text(tenths: int) -> String                      # "6.0"
static func reason_text(cb: StringName) -> String                   # "conquest", "reconquest", "contain the aggressor"
static func terms_text(terms: StringName) -> String                 # "a deal", "a white peace", "a surrender", "the 40-season peace"
static func deal_text(game: Game, deal: Deal) -> String             # "Domodossola (7, 6), Locarno (7, 5) and 7 more and 24 ducats"
static func goal_text(game: Game, goal: PackedInt32Array) -> String # "Domodossola (7, 6) and 11 more districts"
static func league_text(game: Game, against: StringName) -> String  # "the league against the Duchy of Milan"
static func region_text(game: Game, region: int) -> String          # "Lombardy"
static func band_text(band: int) -> String                          # "calm", "restless", "rising", "defiant"

# core/views/peace_view.gd  (new): the peace screen's whole model (6.4)
class_name PeaceView extends RefCounted
static func of(game: Game, viewer: StringName, enemy: StringName) -> Dictionary
	# {} when not at war. {state (&"winning", &"losing", &"demand", &"sued"), war: {id, since_text, seasons, cb_text,
	#  goal_text, goal_worth, goal: PackedInt32Array}, you: {tag, name, arms, gross, net}, them: {tag, name, arms, gross,
	#  treasury_text}, score: {net, lines (the breakdown in words), marks: [{at, text}] (the goal's price, enforce_net)},
	#  sections: [{id (&"goal", &"other"), title, lots: [{seat, name, region, hexes: [{hex, place, worth, price, full,
	#  held, crossed, ok, reason}], worth, price, ok, reason}]}], ducats: {max, step, per_point}, best: {hexes, ducats},
	#  white: {verdict, text}, surrender: {verdict, gives_text}, offer: {} or {id, kind, text, lapse_text, deal},
	#  enemies: [{tag, name}] (all the viewer's live wars), truce_text, empty_text}; cached [&"peace", version, viewer, enemy]
static func total(game: Game, view: Dictionary, hexes: PackedInt32Array, ducats: int) -> Dictionary
	# {price, net, verdict (Session.check's twin: Peace.make_peace_check), answer_text, answer_tone, infamy: {gain, after,
	#  text, tone}, unrest: [{region, add, text}], admin_text}; pure, uncached (one per click)

# core/views/goal_view.gd  (new): the declare-war overlay's model (6.5)
class_name GoalView extends RefCounted
static func of(game: Game, viewer: StringName, target: StringName, cb: StringName, anchor: Vector2i) -> Dictionary
	# {reasons: [{cb, text, verdict}], cb, anchor, anchor_text, goal: PackedInt32Array, count, worth, price_text, names_text,
	#  infamy_text, opinion_text ("They will think −40 of you."), truce_text, league_text, men: {yours, theirs (banded)},
	#  verdict (declare_war_check)}; anchor NO_HEX: the suggestion's

# core/views/goal_lines.gd  (new)
class_name GoalLines extends RefCounted
const WIDTH := 2.4
const INK_WIDTH := 4.0
const DASH := 7.0
const GAP := 4.0
static func for_chunk(game: Game, goals: Array[Dictionary], chunk: Vector2i) -> Array[Dictionary]
	# goals [{hexes: PackedInt32Array, kind (&"goal", &"goal_against")}]: one line {kind, points: [corner, corner], dashed} on every
	# edge between a goal hex and a hex outside it
static func goals_of(game: Game, viewer: StringName) -> Array[Dictionary]   # the viewer's live wars: its goals (goal) and the
	# enemies' goals on it (goal_against)
static func chunks_touched(game: Game, hexes: PackedInt32Array) -> Array[Vector2i]

# core/views/stability_view.gd  (new)
class_name StabilityView extends RefCounted
static func at(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary
	# {} for others' land; {region, region_text, part (districts), unrest, band, band_text, terms: [{text, amount}], share,
	#  share_text ("Taxes here 75 %"), reach, home, lot}
static func parts(game: Game, viewer: StringName) -> Array[Dictionary]   # the viewer's parts: {region, text, districts,
	# unrest, band, top_term, share, hex}; highest unrest first; cached [&"parts", version, viewer]

# core/views/cards_diplomacy.gd  (new): hover cards
class_name DiploCards extends RefCounted
static func score(game: Game, viewer: StringName, enemy: StringName) -> Dictionary      # the breakdown
static func opinion(game: Game, viewer: StringName, a: StringName, b: StringName) -> Dictionary   # memories and standing
	# (exact access only; a word line otherwise)
static func infamy(game: Game, viewer: StringName, tag: StringName) -> Dictionary
static func unrest(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary
static func league(game: Game, viewer: StringName, coalition: int) -> Dictionary

# core/views/study_diplomacy.gd  (new): the Diplomacy page (6.9)
class_name StudyDiplomacy extends RefCounted
static func of(game: Game, viewer: StringName, span: int) -> Dictionary
	# {matrix: {tags, names, cells (RelationMatrix's, through Knowledge.opinion_seen)}, wars (M7's StudyMilitary rows, moved, with
	#  cb_text and goal_text), scores: [{tag, name, net, marks}], leagues: [{coalition, against, formed_text, members_text,
	#  you (&"member", &"may_join", &"aggressor", &"")}], series: {infamy, weariness}, parts (StabilityView.parts), empty texts};
	# cached [&"study_diplomacy", version, viewer, span]

# core/views/country_card.gd  (M2, M7, edit): war: {state, since_text, cb_text, goal_text, net, breakdown, held_theirs,
#   held_yours, truce_text, declare: {verdict}, peace: {verdict (make_peace with the best deal), best_text}, offer: {} or {id,
#   kind, text, lapse_text}} (M7's peace options removed once the panel reads `peace`); relations: {theirs: opinion_seen(tag, viewer), yours:
#   opinion_seen(viewer, tag), gift: [{ducats, verdict}] (20, 50, 100), leagues: [{coalition, text, join: {verdict}}]};
#   standing (own only): {infamy, infamy_word, coalition_at, weariness, overreach_text, parts (the 3 worst)}
# core/views/hex_card.gd  (edit): "Region" (Lombardy, your part 4 districts), "Unrest" (yours: 40, restless), "In the goal"
#   (of a live war of the viewer, either side), "Lot" (in a peace with that country: "Domodossola, 3 districts")
# core/views/map_modes.gd  (M2 to M6, edit): Mode gains RELATIONS (key 7); MODE_KEYS gains &"relations"; RELATIONS_ALPHA :=
#   0.70; RELATIONS_COLOURS (6.3); relation_bytes(game, viewer) cached [&"relations", version, viewer]; relations_ramp();
#   legend(RELATIONS), legend_title(RELATIONS) "Relations: how they see you, how your land feels"; modes(game) adds RELATIONS
#   after SUPPLY in a game with countries
# core/views/study_military.gd  (M6, M7, edit): `wars` leaves for StudyDiplomacy (with the Military page's Wars table)
# core/views/season_summary.gd, log_lines.gd, reminders.gd  (edits): 4.16, 4.18, 4.19; LogLines' War filter takes the new kinds
```

### 5.7 The AI (`core/ai/`, M8, edits)

```gdscript
# core/ai/ai_know.gd  (edit): the door gains
static func infamy(game: Game, tag: StringName) -> int
static func weariness(game: Game, tag: StringName) -> int
static func opinion(game: Game, tag: StringName, of_tag: StringName) -> int         # Relations.total(tag, of)
static func opinion_of_us(game: Game, tag: StringName, other: StringName) -> int    # Relations.total(other, tag): own pairs only
static func net(game: Game, tag: StringName, enemy: StringName) -> int              # WarScore.net (public)
static func war_info(game: Game, tag: StringName, enemy: StringName) -> Dictionary
	# {war, cb, attacker, age, net, still, goal, goal_price, goal_held, capital_lost, demand_turn, demand_net, pending}
static func reconquest(game: Game, tag: StringName, target: StringName) -> PackedInt32Array
static func suggest(game: Game, tag: StringName, target: StringName, max_price: int) -> Dictionary
static func infamy_of_goal(game: Game, tag: StringName, target: StringName, cb: StringName, goal: PackedInt32Array) -> int
static func crossed(game: Game, tag: StringName, hex: Vector2i) -> bool
static func leagues_open(game: Game, tag: StringName) -> Array[Dictionary]          # {coalition, against}
static func in_league_against(game: Game, tag: StringName, target: StringName) -> bool
static func lost_to(game: Game, tag: StringName, other: StringName, seasons: int) -> int   # public: owners and former
static func best_deal(game: Game, tag: StringName, enemy: StringName) -> Dictionary  # {deal: Dictionary (args), price}
static func threats_dislike(game: Game, tag: StringName, threats: Array[StringName]) -> Array[StringName]   # opinion of tag < 0
# core/ai/ai_brief.gd  (edit): infamy, weariness, wars: Array[Dictionary], leagues: Array[Dictionary], opinions: Dictionary
# core/ai/ai_turn.gd  (edit): the diplomacy step after peace (4.14); seats' temper overrides (the soak's conqueror)
# core/ai/ai_players.gd  (edit): attach(game, passive := [], tempers := {}) -> AiTurn; temper_of reads the override first
# core/ai/ai_war.gd  (edit): war (4.14's war step), war_army's goal bonuses
# core/ai/ai_peace.gd  (edit): peace (4.14's table)
# core/ai/ai_diplo.gd  (new): AiDiplo.diplomacy(turn, game, brief, arg) (4.14)
```

---

## 6. The UI of M9

Built from the M1.5 kit and the M3 to M8 pieces. Colours and fonts from the Theme; HUD controls take no focus, screens do. The
App's milestone value becomes `"9"`, so the `since: "9"` rows of `Bindings.DEFAULTS` and `Settings.SCHEMA` register and show.

### 6.1 Keys and settings

| Action (`Bindings.DEFAULTS`) | Key (Mac) | Since | Who hears it | Does |
|---|---|---|---|---|
| `view_mode_7` (**new**, "Map mode 7", View) | 7 | 9 | `MapInput` -> `mode_requested(MapModes.Mode.RELATIONS)` | the Relations mode; M4.5's toasts in the sandbox and while picking |
| `game_peace` (**new**, "Peace screen", Game) | P | 9 | `MapInput.peace_requested` | the peace screen with the country of the open country panel when at war with it, else the newest live war; "You are at peace." toast |

| `Settings.SCHEMA` key | Type (default) | Page, row | Since |
|---|---|---|---|
| `map/war_goals` (**new**) | bool (true) | Map: "War goals on the map"; also the Layers popover's "War goals" switch | 9 |
| `state/map_mode` (edit) | choices gain `relations` | no row | 9 |

### 6.2 Bake slice 7: the diplomacy pieces (`tools/ui_bake/pieces_m9.py`, new)

| Texture | Size (1x) | What |
|---|---|---|
| `icons_diplomacy` (atlas, 24 px cells) | 216 x 72 | `goal`, `anchor`, `cb_conquest`, `cb_reconquest`, `cb_contain`, `lot`, `tribute`, `demand`, `sue`, `white_peace`, `surrender`, `deal`, `infamy`, `league`, `weariness`, `unrest`, `reach`, `home`, `gift`, `opinion_friendly`, `opinion_warm`, `opinion_neutral`, `opinion_cold`, `opinion_hostile`, `crest_across`, `capital`, `treaty` |

`build_theme.gd` adds them as `Kit` icons. `shell/ui/tokens.gd` gains `SCORE_TRACK #3a2416`, `GOAL_INK #e8c15a` (GOLD's value,
named for the goal line), `GOAL_AGAINST_INK #f0806a` (BAD's value) (the bake re-runs: `tokens_sha`). The art director signs the
diplomacy sheet (`bake_ui.py --sheet`): the 27 icons at 1x and 2x beside the war sheet.

### 6.3 The map: the Relations mode and the goal outline (`shell/map/`, `shell/mapview/`)

`MapModes.relation_bytes(game, viewer)`, one byte a hex (priority: your land by its band; others' land by war, truce, league (public
facts), then, when you know the owner (`Knowledge.knows`), its opinion of you, else unknown):

| Byte | Meaning | Colour (`MapModes.RELATIONS_COLOURS`) | Legend words |
|---|---|---|---|
| 0 | sea, unowned land | none | |
| 1 | your land, calm | `#6f9a64` | "Your land: calm" |
| 2 | your land, restless | `#d9a93a` | "Your land: restless (taxes −25 %)" |
| 3 | your land, rising | `#c8664c` | "Your land: rising (no levies)" |
| 4 | your land, defiant | `#8e2a17` with stripes | "Your land: defiant (no taxes)" |
| 5 | at war with you | `#a8321a` with stripes | "At war with you" |
| 6 | in a truce with you | `#e2b97a` | "In a truce with you" |
| 7 | a league is open against them | `#75510f` | "A league is open against them" |
| 8 | Hostile to you | `#6e2a2a` | "Hostile" |
| 9 | Cold | `#b98a7a` | "Cold" |
| 10 | Neutral | `#cfc6b0` | "Neutral" |
| 11 | Warm | `#8fb8a0` | "Warm" |
| 12 | Friendly | `#2f7f6a` | "Friendly" |
| 13 | a country you do not know | the veil (M4.5's `VEIL`) | "Unknown to you" |

Bytes 1 to 12 at `RELATIONS_ALPHA` (0.70); colour distances tested as M4.5's (neighbouring bytes at least 6 worst ΔE; bytes 4 and 5
striped; the veil and byte 5 against every other at least 15). `ModeOverlay` gains the textures `relations` (R8) and
`relations_ramp` (RGBA8 256 x 1), the uniform `relations_alpha`, `func update_relations(bytes: PackedByteArray) -> int` (the texels
that differ, one texture update) and `relations_bytes()` (a copy, tests); it reads no screen texture. `ModeLegend` shows
`legend(RELATIONS)`. The minimap shows it (the same material). The map scene updates it while in Relations mode on
`season_ended`, `owners_changed`, `war_declared`, `peace_made`, `truce_ended`, `coalition_formed`, `coalition_ended`,
`gift_sent`, `unrest_rising`, `game_started` (when `game.version` changed). The top bar's mode `Segmented` gains "Relations".

**The goal outline** (z 83, `TileMapView` `Goals`: one `EdgeLineLayer` a chunk, kinds `goal` (a solid 2.4 px `GOAL_INK` stroke
over a 4 px ink one) and `goal_against` (the same dashed in `GOAL_AGAINST_INK`)): shown for the declare-war overlay's goal while it
is open, and, with `map/war_goals` on, for the viewer's live wars (`GoalLines.goals_of`) in Owner and Relations modes; rebuilt on
`war_declared`, `peace_made` and `owners_changed` for the chunks touched, sliced 5 ms a frame.

```gdscript
# shell/mapview/tile_map_view.gd  (M1, M2, M6, M7, edit): GOALS_Z := 83; set_chunk_goals(chunk, lines), goal_chunks()
# shell/mapview/edge_line_layer.gd  (M1, M2, M7, edit): kinds "goal" and "goal_against"
# shell/map/map_scene.gd  (M1 to M8, edit)
func show_goal(hexes: PackedInt32Array) -> void     # the overlay's goal (replaces any shown)
func hide_goal() -> void
func refresh_goals() -> void                       # the viewer's live wars' goals (map/war_goals)
signal district_picked(hex: Vector2i)              # while picking: a left click on land picks instead of selecting
func set_district_pick(on: bool) -> void           # the App turns it on while DeclareWar is up
# the Relations texture as above; ribbons "Capital" (capital_moved) and "Restless", "Rising", "Defiant" (unrest_rising) through
#   Floaters.add_ribbon (M5)
```

| z | What | Node | Since |
|---|---|---|---|
| 80 | the overlay gains the Relations texture | `ModeOverlay` | M2, M9 |
| 82 | castle-area lines | `TileMapView` `Areas` | M7 |
| 83 | the goal outline | `TileMapView` `Goals` | M9 |
| 85 | borders | `TileMapView` `Borders` | M2 |

### 6.4 The peace screen (`shell/screens/peace.tscn/.gd`, new; `MODAL`, 900 x 640)

```gdscript
class_name PeaceScreen extends Screen          # kind MODAL; a ModalFrame holding a VellumSheet (ribbon "Peace with the Duchy of
	# Milan", seal: the treaty icon, lede: the war's line)
func show_war(enemy: StringName) -> void       # PeaceView.of(Session.game, Session.player_tag(), enemy)
func select_lot(seat: int, on: bool) -> void
func select_hex(hex: Vector2i, on: bool) -> void
func set_ducats(ducats: int) -> void
func best_deal() -> void
func selection() -> Dictionary                 # {hexes: Array[Vector2i], ducats}
# shell/screens/peace/lot_row.tscn/.gd  (new): LotRow (a PanelSlot row: a KitSwitch, the lot's name and region, its districts'
#   count, worth, price (the full price struck when held: "16 → 8"), the held and crest icons, an expand toggle showing a row a
#   district with its own switch; a refused district is greyed with its reason as the lock's tooltip)
```

| Part | Content (from `PeaceView.of` and `PeaceView.total`) |
|---|---|
| Head | both `CountryArms` and names; "At war since Spring 1480 · 4 seasons · conquest of Domodossola and 11 more (worth 48)"; a `ScoreBar` (6.12) with the net and the marks "goal 40" (the goal's price today: 4.22 (c)) and "50: they can impose" (when the enemy leads); its hover the breakdown (`DiploCards.score`); with more than one war, a `Segmented` of the enemies |
| Left (scroll) | "The war goal" and "Other land": a `LotRow` a lot (goal first, by price); "Every district either side holds returns to its owner unless it is in the deal." |
| Right | "Ducats": a `KitSlider` from 0 to the most the rest of the score and their treasury allow, in steps of 12, "24 ducats (2 points)"; the total "Price 18 of your 18"; the **answer line** in its tone ("They accept." / "They refuse: it costs 19, your war score is 18."); "Infamy +6.0: you would be at 6.0 of 30.0" (warn from 18.0, bad at 30.0); "Unrest: Lombardy +30 (conquered land; taxes there −25 % while restless)"; "The national part: −3 % of your people's taxes"; "A truce of 12 seasons follows (until Spring 1484)" |
| Foot | **Best deal**, **Make peace** (primary; locked with the answer line's reason), **White peace** (its verdict), **Surrender** (danger; "You give Asti (8, 10) and 4 more and 120 ducats"), **Back** (Esc) |

| State | What changes |
|---|---|
| **Winning** (net above 0) | as above; Best deal fills the lots; each switch updates the total and the answer line at once |
| **Losing or even** (net 0 or below) | the left lists "What they could demand" (their Best deal against you, read-only); the slider and Make peace hidden; White peace and Surrender shown with their verdicts |
| **A demand to answer** (an offer of kind demand or white to you) | a ribbon "The Duchy of Milan demands" (or "offers a white peace"); the left shows the offer's deal read-only with "Price 12 of their 12 · lapses in Winter 1482"; the foot **Accept** (danger; `answer_offer {accept: true}`), **Refuse** (`answer_offer {accept: false}`), **Surrender**, **Back** (decide later) |
| **They ask for peace** (a sue) | the Winning state with a ribbon "The Duchy of Milan asks for peace" and Best deal applied on open |
| **Nothing to take** | "They hold nothing you can take: their capital needs holding, and they keep their last district." with ducats only |
| **The war ends while open** | on that war's `peace_made` the screen closes with the toast of 6.10 |

Keys with the screen focused: Up, Down move the rows; Space toggles; Right expands a lot; Enter **Make peace** (or Accept in the
demand state); Tab moves through the foot's buttons; Esc Back. Opened from P, the country panel's **Make peace…**, the hex menu, a demand or request
decision, the Diplomacy page's Wars table, the reminders `demand_open` and `peace_risk`.

### 6.5 The declare-war overlay (`shell/screens/declare_war.tscn/.gd`, new; `OVERLAY`, 420 px, left)

```gdscript
class_name DeclareWar extends Screen           # kind OVERLAY; a PanelFrame with the cartouche "War on the Duchy of Milan"
func show_target(target: StringName, anchor: Vector2i = Vector2i(-1, -1)) -> void   # GoalView.of(...); NO_HEX: the suggestion
func set_reason(cb: StringName) -> void
func set_anchor(hex: Vector2i) -> void         # from MapScene.district_picked
```

| Part | Content (from `GoalView.of`) |
|---|---|
| Reason | a `NavList` of the three reasons, each with its verdict (a refused one greyed, its reason as the tooltip: "you are in no league against the Duchy of Milan") |
| Goal | "Aim at: Domodossola (7, 6) · click a district of Milan to move it"; "12 districts, worth 48: Domodossola, Locarno and 10 more"; "In peace: 48, half where you hold it" |
| Before you act | "Infamy: none for the goal under contain; half under conquest (+12.0 for all of it), double outside it"; "They will think −40 of you."; "Their men: about 1,000; yours 2,000"; "No truce holds."; "Your infamy 6.0 of 30.0" |
| Foot | **Declare war** (danger; `set_verdict(Session.check("declare_war", {target, cb, anchor}))`), **Cancel** (Esc) |

While it is open the map shows its goal (`MapScene.show_goal`) and a left click on the target's land re-anchors it (the App
routes `district_picked`); the camera glides so the goal sits right of the overlay. Opened from the country panel's
**Declare war…** and the hex menu (anchored at that hex).

### 6.6 The country panel's diplomacy (`shell/panels/country_panel.tscn/.gd`, M2 to M7, edit)

From `CountryCard.of(...)`:

| State | Rows |
|---|---|
| Another country, at peace | **Relations**: "They: Cold (−20) · You: Neutral (0)" with the causes' hover (`DiploCards.opinion`); a `Segmented` "20 · 50 · 100" and **Send a gift** (`set_verdict(Session.check("send_gift", {target, ducats}))`); a league line ("A league is open against them: Join" with its verdict, or "In the league against them"); the infamy word ("Notorious"); **Declare war…** (danger; opens the overlay; its verdict is M7's rows) |
| In a truce | "Truce until Spring 1484 (12 more seasons)"; Relations as above; Declare war… locked with its reason |
| At war | "At war since Spring 1480 · conquest of Domodossola and 11 more"; a `ScoreBar` with the net and its hover; "You hold 2 of their districts (16); they hold none of yours; battles 2"; **Show the goal** (glides, the outline); **Make peace…** (opens the peace screen; its verdict is the Best deal's); a pending demand: "They demand Asti and 2 more: it lapses in Winter 1482. Answer…" |
| Your own country | Wars (enemy, net, reason) and Truces as links; Leagues ("against you: 3 members", or "you are in the league against Milan"); **Infamy** bar (`ScoreBar` in one-sided form, 0 to 30.0, the warn mark at 18.0) with its hover; **Weariness** ("29: income −8.7 %"); "Lost to distance and unrest: 12 ducats a season"; the three worst region parts with their bands (links to the hex) |

Refreshes on `war_declared`, `peace_made`, `peace_offered`, `offer_answered`, `truce_ended`, `coalition_formed`,
`coalition_joined`, `coalition_ended`, `gift_sent`, `capital_moved`, `district_captured`, `season_ended`.

### 6.7 Decisions: demands, white offers, requests for peace, leagues (`shell/app/decision_queue.gd`, M7, M8, edit)

The queue's order in `DECISIONS`: war alerts (M7), peace alerts (M8), then **offers**, then **leagues**. M7's war alert gains the
line "Their reason: conquest of Asti (8, 10) and 11 more districts (worth 48)."; M8's peace alert reads M9's terms ("The Duchy of
Milan has made peace with you: Asti (8, 10) and 2 more become theirs, and you pay 120 ducats." / "... imposed its peace, its war
score being +52: ..." / "... a white peace ..." / "... surrendered: ... become yours.") and the truce's length. Each new kind is a
`Confirm`:

| Kind (pushed on) | Title, tone | Lines | Choices |
|---|---|---|---|
| `peace_offered` demand (to you) | "A demand", warn | "The Duchy of Milan demands: Asti (8, 10), Alba (6, 11) and 40 ducats (its war score +24 pays for it).", "Refuse and the war goes on; at +50 it can impose its peace. The demand lapses in Winter 1482." | **Accept** (danger), **Refuse**, **Open the peace screen**, Esc: decide later (it stays pending) |
| `peace_offered` white (to you) | "A white peace", plain | "The Duchy of Milan offers a white peace: every district returns to its owner; a truce of 8 seasons follows." | **Accept** (primary), **Refuse**, Esc: decide later |
| `peace_offered` sue (to you) | "They ask for peace", good | "The Duchy of Milan asks for peace. Your war score is +38." | **Open the peace screen** (primary: the screen with Best deal applied), **Not now** (Esc) |
| `coalition_formed` (you eligible) | "A league", plain | "A league forms against the Duchy of Milan (infamy 31.0). Join it: you may declare war on Milan to contain it, at no infamy for its goal; Milan's opinion of you falls 30." | **Join the league** (`join_coalition`), **Stay out** (Esc; you may join later from the country panel) |
| `coalition_formed` (against you) | "A league against you", danger, seal "!" | "Your infamy (31.0) has raised a league: 8 countries may join it and declare war on you at no cost. It ends when your infamy falls under 12.0." | **Open Diplomacy** (the study's page), **To the report** (primary, Esc) |

An offer answered elsewhere (the country panel, the peace screen) before its decision shows is dropped from the queue
(`offer_answered`; `func drop_offer(offer: int) -> void`, new). At idle (the console) a decision shows at once. Save is refused while the flow is in `DECISIONS` (M3 D48).

### 6.8 The hex panel, the hover card, the hex menu (M2 to M8, edits)

- **Hex panel** (`shell/panels/hex_panel.tscn/.gd`): under the Owner row, "Region: Lombardy" and on your land "Unrest 40 ·
  restless · taxes here 75 %" (the hover `DiploCards.unrest`: "Conquered land +30 · Not home land +10 · An army there −10 (none)");
  "In your war goal against the Duchy of Milan" (or "In the Duchy of Milan's goal against you"); during a war, "Lot: Domodossola, 3
  districts". Refreshes on `unrest_rising`, `owners_changed`, `peace_made`.
- **Hover card** (`shell/hud/map_hover.gd`): the region's name after the owner.
- **Hex menu** (`shell/hud/hex_menu.gd`, M6, M7): on another country's land "Declare war on the Duchy of Milan…" (the overlay
  anchored here; its verdict), at war "Make peace with the Duchy of Milan…", "Show the Duchy of Milan".

### 6.9 The Diplomacy page and the Military page (`shell/screens/study/page_diplomacy.tscn/.gd`, new; `page_military.*`, edit)

The study's nav after M9: Economy, **Diplomacy**, Military, People, Rankings, History (the mockup's order; Trade joins before
Diplomacy in M10).

| Part | Built from | Reads |
|---|---|---|
| Relations | `SectionHead` "Relations"; the `RelationMatrix` (6.12) of you and the countries you know; a cell's activation opens that country's panel (or, for your own row, the peace screen when at war) | `matrix` |
| Wars (moved from Military) | M7's `StudyTable` with two more columns, Reason and Goal ("conquest · Domodossola and 11 more") | `wars` |
| War scores | a `ScoreBar` a live war of yours with its marks; a click opens the peace screen | `scores` |
| Leagues | a `StudyTable`: Against, Formed, Members, You ("member", "may join" with a Join button, "against you") | `leagues` |
| Your standing | an `InkChart` `LINE` of infamy (with a dashed line at 30.0) and weariness, 12 or 40 seasons (`state/study_span`) | `series` |
| Unrest | a `StudyTable`: Region, Districts, Unrest, Band, Main cause, Taxes; "Show on map" switches to Relations mode | `parts` |

Empty states: "No war yet.", "No league yet.", "Your land is calm." The Military page loses its Wars table (M7 6.9) and keeps its
Battles table and losses.

### 6.10 The report, the task flag, notifications, the log, ribbons, toasts, chips

- **The report screen** (`shell/screens/season_report.gd`, M3, M7, edit): draws the `diplomacy` section (the nav gains
  "Diplomacy" with its count); offer lines open the peace screen, league lines the Diplomacy page, unrest lines look at the hex.
- **Task flag and notifications** (M3): the rules of 4.19; notifications as 4.16's `notify`.
- **The log** (`shell/hud/action_log.gd`): the new lines under War; an offer line is a button that opens the peace screen.
- **Ribbons**: "Capital", "Restless", "Rising", "Defiant".
- **Toasts**: a declaration ("War with the Duchy of Milan: conquest of Domodossola and 11 more."); a peace ("Peace with the Duchy of
  Milan: you took 9 districts and 24 ducats."); a gift ("50 ducats to the Republic of Genoa: their opinion of you +10."); a join
  ("You joined the league against the Duchy of Milan."); an answer ("You refused the Duchy of Milan's demand."); a refusal (its
  reason); P with no war ("You are at peace.").
- **Chips** (`shell/hud/chips.tscn/.gd`, M4 to M6, edit): a **Weariness** `ResourceChip` (icon `weariness`, "29", its change)
  shown while weariness is over 0, after the Army chip; its hover the causes and the income lost; a click opens the Diplomacy page.

### 6.11 The App, F3, the console

| Request or event | The App (`shell/app/game_requests.gd`, `app.gd`) |
|---|---|
| `MapInput.peace_requested`, `app_requested(&"peace", {target})` | push `PeaceScreen` (`ScreenIds` `peace`) at that war; none: the toast |
| `app_requested(&"declare", {target, anchor})` | push `DeclareWar` (`ScreenIds` `declare_war`, **new**); `MapScene` listens for picks |
| `MapScene.district_picked(hex)` while `DeclareWar` is up | `DeclareWar.set_anchor(hex)` (a hex of another country toasts "Pick a district of the Duchy of Milan.") |
| `app_requested(&"gift", {target, ducats})`, `(&"join", {against})`, `(&"answer", {offer, accept})` | `Session.act` the action, the toast |
| `Events.peace_offered` to the player, `coalition_formed` with the player eligible or the aggressor | `DecisionQueue.push` (6.7); at idle `next` at once |
| `Events.offer_answered` | `DecisionQueue.drop_offer(offer)` |
| `Events.season_ended` | `StudyWarm` adds `StudyDiplomacy.of` and, in Relations mode, `MapModes.relation_bytes` |

- **F3** (`shell/hud/debug_overlay.gd`): "diplomacy · offers 1 · leagues 1 · infamy 6.0 · weariness 29 · reach fields 3 · war 0.4
  ms · relations 0.6 ms".
- **Console** (`shell/hud/dev_commands.gd`): `infamy TAG n` (`Game.dev_infamy`, n tenths), `weary TAG n` (`dev_weariness`),
  `opinion A B n` (`dev_opinion`), `goal TAG` (prints your war's goal and price, or the suggestion), `deal TAG best` (`make_peace`
  with your Best deal), `offer TAG demand|white|sue` (with `as TAG`: an `offer_peace` from that country to you; a demand carries its
  Best deal), `leagues` (prints the open leagues); M7's `declare TAG` gains `[conquest|reconquest|contain] [c r]` (defaults:
  conquest and the suggestion's anchor); problems "no country TAG", "not at war with TAG", "no such number", "no such offer",
  each a planted fault in its test.
- **The Layers popover** (`shell/hud/layers_popover.tscn/.gd`): a "War goals" `KitSwitch` on `map/war_goals`; hidden in the sandbox.
- The App sets the milestone `"9"`. `screen_ids.gd` gains `declare_war`.

### 6.12 Kit pieces (`shell/ui/`)

```gdscript
# shell/ui/score_bar.gd  (new, kit): ScoreBar (Control, _draw, Tokens only)
class_name ScoreBar extends Control
func set_score(net: int, mine: Color, theirs: Color, marks: Array[Dictionary] = []) -> void   # -100..100: the track, the fill
	# from the middle toward the leader in its colour, the number ("+18", tabular) in the middle, a tick a mark ({at, text},
	# the text in the hover); accessibility_name "War score +18 for you"
func set_meter(value: int, top: int, warn: int) -> void   # the one-sided form (infamy 0..top with the warn tick)
# shell/ui/relation_matrix.gd  (M1.5, edit): CELL_H 40; states gain &"league" ("League", icon league); a cell's line 2 is its
#   `word` (the opinion word, or "?" when hidden) in TableRow's faint colour; the hover lists the state, the seasons left of a
#   truce, and the opinion (the number only when the cell carries `value`)
```

---

## 7. Data and the editor

| File | Holds | Made by | Checked by |
|---|---|---|---|
| `godot/data/defs/diplomacy.tres` (**new**) | `DiplomacyDef` (5.1, the values of 4.2 to 4.13) | by hand in the inspector (task V1) | `tests/core/test_diplomacy_defs.gd`: loads, validates, equals 4.2 to 4.13 |
| `godot/data/defs/families/*.tres` (M3 to M7, edit) | `worth` (4.2) | by hand (V1) | `tests/core/test_family_defs.gd` |
| `godot/data/defs/war.tres` (M7, edit) | the six fields removed | by hand (V19) | `tests/core/test_war_defs.gd` |
| `godot/data/defs/game_defs.tres` (edit) | `diplomacy` (external); the sixth temper (V31) | by hand (V1, V31) | `GameDefs.validate()` in `test_economy_defs.gd` and `test_ai_defs.gd` |
| `godot/data/defs/ai.tres`, `tempers/*.tres` (M8, edit), `tempers/conqueror.tres` (**new**) | 4.14's fields (added by V23; the removed ones go with V29) | by hand (V23, V29, V31); tuned by V33 | `tests/core/test_ai_defs.gd` |
| `godot/data/maps/north_italy.tres` (edit) | `region_id`, `regions` (4.12) | `godot/tools/build_map.gd` from `data/geography/regions.json` and `cities.json` (V3) | `build_map.gd --check` in CI; `test_map_build.gd` (the table of 4.12) |
| `godot/data/scenarios/north_italy_1480.tres` (edit) | `map_digest` (the new map digest) | `godot/tools/build_scenario.gd` (V3) | `build_scenario.gd --check` in CI; `test_scenario_1480.gd` |
| `godot/tools/diplo_tables.gd` (**new**, headless) | prints 4.2's and 4.6 to 4.12's tables as Markdown from the files | V1 | `test_diplomacy_defs.gd` runs it and compares one row of each |
| `godot/tools/ai_tables.gd` (M8, edit) | the new temperament and `AiDef` rows | V23 | `test_ai_defs.gd` |
| `godot/assets/ui/kit/` (slice 7) | the textures of 6.2 at 1x and 2x | `tools/bake_ui.py` (V4) | `bake_ui.py --check`, `build_theme.gd --check` in CI |
| `godot/data/README.md` (edit) | `diplomacy.tres`, `worth`, the regions | V1 | |

`core/mapgen/fake_map.gd` (M1) gives the made-up maps regions in blocks of 8 x 8 hexes (land only, numbered in block order), so the
perf runs have about 1,200 regions on the made-up Europe. The scenario editor (M2) is unchanged: regions are map data, made by the
builder, never painted.

---

## 8. Speed

`godot/tools/perf_core.gd` (M3 to M8) on the made-up Europe: `PerfFixture.europe_diplomacy(seasons)` (**new**, in
`godot/tools/perf_fixture.gd`): M7's `europe_war` with each war given a conquest reason and the suggestion's anchor, 20 deals
made at season 4 (each winner's Best deal), 10 leagues formed (`dev_infamy`), 2,000 memories; `seasons` seasons through
`Season.run`. Rows in `godot/tests/perf_core_budget.json`, nightly, never in GUT:

| Row | Limit | What |
|---|---|---|
| `season_ms` | **400** (M7, M8: 380) | the fourteen phases other than `ai_orders`, worst of 8 seasons |
| `war_ms` | 3 (M7: 2) | the war phase with offers and truces |
| `relations_ms` | 25 | the relations phase: 2,000 memories, 60 countries, the bands of every part |
| `reach_cold_ms` | 250 | the reach fields of all 60 countries from cold |
| `unrest_cold_ms` | 60 | every part's unrest with warm reach fields |
| `lots_ms` | 15 | the lots of the largest country, cold |
| `best_deal_ms` | 5 | one `Peace.best_deal` against the largest country |
| `peace_view_ms` | 10 | `PeaceView.of` against the largest country, uncached |
| `goal_ms` | 3 | one `WarGoals.suggest` |
| `relation_bytes_ms` | 20 | `MapModes.relation_bytes`, cold |
| `ai_season_ms` | 3,000 mean (M8) | with M9's steps |
| `save_mb` | 8 (M3) | with the diplomacy key |

`godot/tools/ui/perf_ui.gd` gains in `perf_ui_budget.json`: `peace_open_ms` 16 (the screen against Milan, cold), `peace_toggle_ms` 4
(a lot switched to the answer line drawn), `declare_open_ms` 16, `goal_lines_ms` 8 (a goal outline drawn on north Italy),
`relations_mode_ms` 16 (the mode switched in), `diplomacy_page_ms` 16.

**How it stays in budget.** The reach fields are made per country only when asked and kept until its land or centres change; a
season with no peace keeps them all. Unrest is a sum of a dozen terms per part, cached by version. The peace screen's base (lots
and prices) is cached by version; a click only sums prices. If `reach_cold_ms` fails, the first fallback is a field bounded to
`reach_free + 20` steps (beyond it: the floor); the second, centres limited to the capital.

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (P).

| File | Cases |
|---|---|
| `tests/core/diplomacy_fixture.gd` (**new**) | `DiplomacyFixture.savoy(defs)`: M7's `WarFixture.savoy` with the declaration of 4.22 (a); `duel(defs)`: M8's `AiFixture.duel`; `demand(defs)`: 4.22 (e)'s demand setting; `infamous(defs)`: 4.22 (f); `occupy(game, tag, hexes)` through the `Occupation` door (tests only) |
| `tests/core/test_diplomacy_defs.gd` (**new**); `test_family_defs.gd`, `test_war_defs.gd`, `test_ai_defs.gd` (edits) | the files load, validate, equal 4.2 to 4.14 and 5.1; `diplo_tables.gd`'s rows; P: an opinion word list out of order, `rising_at` under `restless_at`, `coalition_end` over `coalition_at`, a gift step of 7, a family with no `worth`, `enforce_net` under `white_max_net`, a soak temper in the scenario, `surrender_net` over `sue_net` |
| `tests/core/test_diplomacy_state.gd` (**new**); `test_war_state.gd`, `test_country_state.gd`, `test_stats.gd` (edits) | `War` war/2, `Country` country/5, `RelationBook`, `Coalition`, `Deal`, `PeaceOffer` round trips; `digest_text` moves with every field; `map-state/6` with `gained` and `former`; P: war/1 and country/4 refused, a string for `gained`, a deal with a duplicated hex, an offer of an unknown kind; 54 series |
| `tests/core/test_map_build.gd`, `test_map_data.gd`, `test_fake_map.gd`, `test_scenario_1480.gd` (edits) | the 25 regions and 4.12's table; every land hex a region, sea −1; the digest moves with `region_id`; the made-up maps' block regions; the scenario's map digest; P: a land hex with −1 fails `validate` |
| `tests/core/test_war_goals.gd` (**new**) | worth of every piece kind and the capital (4.2's table and the 1480 sums); `goal_of` for 4.3's worked goal and on a crest fixture (a crest without a pass stops the walk, a pass costs 2); `reconquest_of` after a fixture peace; `suggest` (the cap; ties by index); `reason_check` every row (P each); reach fields: 1.1's farthest home districts, `crossed` on Geneva and not on Domodossola; lots of 4.5 (Milan 20, ties by level then index; P: a lot seat of another owner is caught) |
| `tests/core/test_war_score.gd` (**new**) | occupation is live (lose a district, lose its points); battle points from fixture records (2 + killed/1,000 + wounded/2,000; a draw none; the cap 25); the gross cap 100; `net` symmetric; `Wars.score` equals `net`; the breakdown's lines; the war phase's `net_turn` (P: a phase that writes `net_turn` every season is caught) |
| `tests/core/test_wars.gd` (M7, edit) | `declare_war` rows 10 to 14 with their words (P each), the defaults of a missing reason and anchor; the war's `cb`, `goal`, `anchor`; the `declared` memory; `war_declared`'s fields; truce lengths by terms; `truce_ended` at the truce's last season; the timer's peace through `Peace.apply` with `white` memories |
| `tests/core/test_peace.gd` (**new**) | `price_of` for each cell of 4.6's town table; `takeable` (the capital held and not, the last district: P each); every row of `make_peace_check` with its words (P each); `apply`'s seven steps for deal, white and surrender (what moves, tribute lines pairing, infamy, memories, the capital moved, occupations released, armies home, the war's offers dropped); `best_deal` on 4.22 (c) and (c′) exactly, the last-district rule (P: a best deal taking all is caught), ducats capped by the treasury; `surrender_deal` as attacker and defender |
| `tests/core/test_offers.gd` (**new**) | `offer_peace_check` and `answer_offer_check` every row (P each); a demand's `peace_offered`, `War.demand_*`; accept applies the offerer's deal; refuse costs 10 of opinion; lapse in the war phase two seasons after the offer, no opinion; one pending a pair; an imposed deal at net 50 (row 14 passes) and refused at 49 (P); answered offers dropped after 8 seasons and at the peace |
| `tests/core/test_relations.gd` (**new**) | each memory of 4.8 with its amount and cap; the fade of 2 and the drop at 0; 8 memories a pair (the ninth drops the oldest); each standing term; `total` clamped; the words at their edges; 4.22 (a) and (c)'s opinions; gifts: every row (P each), the tens, one a season, the memory; P: a gift that moves the giver's opinion is caught |
| `tests/core/test_coalitions.gd` (**new**) | formation at 300 and the land share (P: 299 forms none; a 16-district country forms none); `eligible` neighbours and victims; `join_coalition_check` every row (P each); the two `league` memories; `contain` allowed for members only; the end under 120 and on a dead aggressor; 4.22 (f) |
| `tests/core/test_brakes.gd` (**new**) | `infamy_of` per reason and place (4.9's table); the fade; weariness per row of 4.10 (P: a season of peace that adds is caught); `home`; `admin_loss`; **on 1480 every national part 0** (and, with V13's shares, every share 1,000) |
| `tests/core/test_unrest.gd` (**new**) | each term of 4.12 alone and together; the conquest term's fade and cap (two peaces a season apart: 58); bands at 39, 40, 69, 70, 99, 100; **on 1480 every part 0**; `unrest_rising` only on a rise (P: a band falling emits none); the levy row (raise, refill, garrison regrowth refused in a rising part; P) and the works row in a defiant one (P); 4.22 (c) and (g) |
| `tests/core/test_economy_brakes.gd` (**new**); `test_economy_season.gd`, `test_economy_preview.gd`, `test_brakes.gd` (the shares) (edits) | `tax_share` per reach and band; the `overreach` and `weariness` lines by hand on fixtures; none written at 0; the money identity with them; the preview still equals the season for four calm seasons with a restless part and weariness; with no war and no peace every M4 to M8 number of `test_economy_1480.gd` unchanged |
| `tests/core/test_diplomacy_savoy.gd` (**new**) | **done-when 1, 2, 3, 5, 6**: 4.22 (a) to (d) season by season; the seed's battle result pinned |
| `tests/core/test_season.gd` (edit) | **`PHASES` is the fifteen of 4.15** (the pin); the relations phase's order (memories, brakes, leagues, unrest) |
| `tests/core/random_player.gd` (M6 to M8, edit) | `declare_war` with a random reason and anchor, `make_peace` with random terms and random deals (half of them Best deals), `offer_peace` (any kind, to anyone), `answer_offer`, `send_gift`, `join_coalition` |
| `tests/core/test_peace_property.gd` (**new**) | **done-when 9**: 40 seasons, the random player for every country, weather drawn; at every peace: the land count, the moved districts exactly the deal's, occupations cleared, tribute and gift lines paired, no treasury made negative by a peace; infamy up only at a peace; opinions in range; members eligible; no war in a truce; offers only to the player and one a pair |
| `tests/core/test_check_contract.gd`, `test_men_property.gd`, `test_money_property.gd` (edits) | the 21 actions; the money identity with tribute, gifts, overreach and weariness |
| `tests/core/test_diplomacy_saves.gd` (**new**) | **done-when 4, 10**: save, load, save byte-equal with memories, leagues, offers, bands, `gained`, `former`; a save with a demand pending, loaded and answered, equals the game answered before the save; `FORMAT` 7 (P: a format-6 header reads `older`; a string for an offer's `lapse_turn`) |
| `tests/core/test_snapshot.gd`, `test_save_file.gd`, `test_replay.gd`, `test_owns.gd`, `test_game_core.gd`, `test_forty_seasons.gd`, `test_insights_views.gd` (edits) | the M9 fields round-trip; 20 seasons of random diplomacy give the same digest (P: a changed deal gives another); the dev records replay; 5.3's OWNS table (P: a test-only phase writing `infamy` directly is reported); `DOOR_FIELDS`; the pins move to M9's values (fifteen phases, `FORMAT` 7, 54 series, twenty-nine notable kinds, twenty-one actions, fourteen `WHY` reasons) |
| `tests/core/test_peace_view.gd`, `test_goal_view.gd`, `test_goal_lines.gd`, `test_stability_view.gd`, `test_cards_diplomacy.gd`, `test_study_diplomacy.gd` (**new**) | every state of 6.4 from the view (winning, losing, demand, sued, nothing to take); `total`'s answer line equals the check's reason (P: a total that disagrees with the check is caught); the goal view's reasons and verdicts; goal lines on every outer edge and none inside; the parts table; the hover cards; the matrix cells through the fog (P: an unknown pair shows a number) |
| `tests/core/test_knowledge.gd`, `test_words.gd`, `test_country_card.gd`, `test_hex_card.gd`, `test_map_modes.gd`, `test_log_lines.gd`, `test_chronicle.gd`, `test_season_summary.gd`, `test_reminders.gd`, `test_study_military.gd` (edits) | `opinion_seen` exact, word, hidden; `infamy_seen`; the words; the card's states and verdicts; the hex card's lines; `relation_bytes` per byte (both palettes' distances); the sentences of 4.16 for the player and a witnessed other; `NOTABLE`; the Diplomacy section and the chips, equal after a save and load; every rule of 4.19 (P: a truce 3 seasons from its end makes no `truce_ending`); the Wars table gone from Military |
| `tests/core/test_ai_defs.gd`, `test_ai_know.gd`, `test_ai_door.gd`, `test_ai_war.gd`, `test_ai_peace.gd`, `test_ai_turn.gd`, `test_ai_fog.gd`, `test_ai_owner.gd`, `test_ai_play.gd` (M8, edits), `test_ai_diplo.gd` (**new**) | 4.14's tables; each new door function's filter; the new door tokens (P: `Relations.` in a step module is reported); the war step's reason, goal, weights, guard, first turn (P: a declaration at turn 8 is caught); the goal bonuses; each peace rule with its check and the offer fallback (P each); the diplomacy step's joins and gifts (P: a gift at war); the step order; the fog with third pairs' opinions and others' offers changed; the duel's pins moved (Milan declares at turn 11 or later); every country still plays |
| `tests/core/invariants.gd`, `test_invariants.gd` (M8, edits); `test_ai_soak_quick.gd` (edit) | the five invariants of 4.23 with a planted break each (a country given 137 districts by `dev_transfer`, a deal that moved one district too many, an offer to an AI, a member not eligible, an opinion of 101) |
| `tests/shell/test_session.gd`, `test_decision_queue.gd` (edits) | the nine signals drained after their phases, then `chronicled`; each decision of 6.7 with its choices; an offer answered elsewhere leaves the queue; the order |
| `tests/shell/test_peace_screen.gd`, `test_lot_row.gd`, `test_declare_war.gd`, `test_score_bar.gd`, `test_page_diplomacy.gd` (**new**); `test_relation_matrix.gd` (**new**, the piece's own, taking the matrix's cases of `test_kit_feedback.gd`); `test_kit_feedback.gd`, `test_country_panel.gd`, `test_hex_panel.gd`, `test_hex_menu.gd`, `test_page_military.gd`, `test_season_report.gd`, `test_chips.gd`, `test_mode_overlay.gd`, `test_map_scene.gd`, `test_layer_stack.gd`, `test_map_input.gd`, `test_bindings.gd`, `test_settings.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_task_flag.gd`, `test_notifications.gd`, `test_action_log.gd`, `test_app_flow.gd` (edits) | every state and part of 6.4 (a switch updates the answer line; Best deal; the slider's steps; Accept and Refuse in the demand state; it closes on its war's peace); the overlay's reasons, the re-anchor by a map pick, the goal on the map; the bar's fill, number and marks; the matrix's two lines, `league`, "?"; the panel's four states and verdicts; the hex panel's lines; the menu items; the page's parts and empty states; Wars gone from Military; the report's section; the chip; the Relations texture writes only changed texels (P: one byte, one texel); z 83; 7 and P (P: P at peace toasts); `map/war_goals` (P: a bad value falls back); the console commands and their planted faults; the F3 line; end to end: New game as Savoy, the console's Milanese army, Declare war… with the anchor at Domodossola, march, End season, the score, P, Best deal, Make peace, the truce in the panel; before it (a quickload copy), `as MLO offer SAV sue` and the request decision, Not now; in a second game as Genoa with a fixture war, `as MLO offer GEN demand` and the demand decision, Refuse; `infamy MLO 300`, End season, the league decision, Join |
| `tests/shell/test_ui_monkey.gd` (edit) | adds P, 7, clicks in the peace screen, the overlay and the matrix; invariants: the digest changes only after an accepted action or a season; the peace screen never changes the digest without an act |
| Python `tests/test_bake_ui.py` (edit) | slice 7's atlas at both scales; the catalogue; the asserts of style spec 4.4 |
| `godot/tools/map/probe_mode_overlay.gd` (M2 to M7, edit; windowed, CI under xvfb) | the Relations texture: the pixel at every hex middle equals `colour_at` (tolerance 3); P: `--plant` swaps a byte and prints FAIL |
| Pictures (`godot/tools/ui/shot_ui.gd`, edit) | the peace screen (winning, losing, a demand) against the war-goals design's mockup list 3; the declare-war overlay with its goal on the map; the country panel's four states; the Relations mode in both palettes; the Diplomacy page; the decisions; the report's Diplomacy section; at 1280 x 720 scale 1 and 2560 x 1440 scale 2; signed by the art director, then goldens `godot/tests/goldens/m9_*.png` (0.5 %) |

**Determinism:** `test_replay`, `test_forty_seasons`, `test_peace_property`, `test_check_contract`, `test_ai_determinism` (M8): M9's
rules draw no luck, walk every list in id or hex-index order, and sum integers. **Save round trip:** `test_snapshot`,
`test_save_file`, `test_diplomacy_saves` (mid-negotiation), `test_season_summary` (J after a load: the Diplomacy section equal).

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| The prices make wars all-or-nothing on a small map (a capital's 40 dwarfs the rest) | `diplo_tables.gd`'s worth table and the soak's per-country deals (V31's first run), read by Opus before the tuning task | `worth_capital` 25, or `price_held_permille` 600 (data) |
| The AI never demands (the score jumps past 50 when a walled capital falls) | the passive suite's "demands to the player" (V31) | `enforce_net` 70 (data) |
| A player who refuses every demand waits out the timer | the playtest (step 8) and the passive suite's losses | `enforce_net` lower (data) |
| Leagues never form on north Italy (infamy fades faster than wars come), or form every game | the soak's league ranges (V31) | `infamy_per_worth` 4 or 6; `infamy_decay` 2 or 4 (data) |
| The conqueror still runs away | the conqueror suite (V31) | `coalition_at` 250, `admin_per_extra` 15, `unrest_conquest` 35 (data) |
| The brakes freeze the map (the AI goes passive) | M8's "wars declared a game" and "games with a war" ranges, kept | `infamy_guard` higher, `first_war_turn` 5 (data) |
| Unrest is unreadable | every term has a hover line (`DiploCards.unrest`); the playtest step 6 | fewer terms shown (the three largest) |
| The regions of the nearest-anchor rule look wrong on north Italy (Domodossola in Valais) | the art director and Opus read 4.12's table and a Relations-mode picture in V3's pull request | anchors added to `regions.json` through the exporter (`tools/export_geography.py`), the frozen game untouched |
| Reach fields too slow on Europe | `reach_cold_ms` in V22 | section 8's fallbacks |
| The peace screen is a spreadsheet | the playtest steps 4 and 5 (two clicks: Best deal, Make peace) | the hex-by-hex rows collapsed by default (already) |
| Pop-up fatigue (offers, leagues) | the playtest; at most one offer a pair and one league decision a league | league invitations as a notification only (S) |
| The M8 duel and its pins move | V29 re-pins them; M8's done-when 5 and 6 still hold in the soak | none needed |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 5.3: row 5 reads "War (`war`): the 40-season safety peace, offers lapse, truces end (`m7-build-spec.md` 4.9, `m9-build-spec.md` 4.15)"; a new row 6 "Relations (`relations`): memories fade, infamy, weariness, leagues, unrest bands" (M9), later rows renumbered; 9.2: the intro (M2 to M9 have their spec and plan), an M9 row pointing at this spec and its plan, "specified and planned, waits for the owner's go; starts after M8 closes", the last row M10 to M12; "After M12" gains alliances and calls to arms, rebels and free states (stop-steamrolling Part C), historical claims |
| `docs/architecture/m2-build-spec.md` | 13, row M9: points here (`transfer` writes `gained` and `former`; the Relations mode on key 7) |
| `docs/architecture/m4-5-build-spec.md` | 12, row M9: points here |
| `docs/architecture/m5-build-spec.md` | 12, row M9: points here (people stay on a ceded hex, booked on its new owner from the transfer) |
| `docs/architecture/m6-build-spec.md` | 12, row M9: points here (no military access in M9; armies on ceded land go home by M7's rule) |
| `docs/architecture/m6-build-plan.md` | Section 7, the M9 bullet: points here |
| `docs/architecture/m7-build-spec.md` | 12, row M9: taken up here; row M12: the brakes moved to M9 |
| `docs/architecture/m7-build-plan.md` | Section 7: the M9 bullet points here; the M12 bullet loses "war weariness and the brakes" |
| `docs/architecture/m8-build-spec.md` | 4.17: the land-share range's note points at 4.23 here; 12, row M9: taken up here (no `AiPeace.answer`; offers through `offer_peace`; the acceptance rule) |
| `docs/architecture/m8-build-plan.md` | Section 7, the M9 bullet: points here |
| `docs/architecture/ui-and-controls-spec.md` | 4.1: the rows `view_mode_7` (7, Relations, M9) and `game_peace` (P, M9) |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M9: the files of this spec; the tasks are those of `m9-build-plan.md` |
| `docs/architecture/ui-style-and-feedback-spec.md` | 5, the `RelationMatrix` row: 64 x 40, two lines, `league`; 6.4: the section ids gain `diplomacy`; 8: a note that the Diplomacy page is specified here |
| `docs/architecture/ui-style-and-feedback-plan.md` | S5, row M9: folded into `m9-build-plan.md` (V19, V21, V28, V30) |
| `docs/design/ui/game-feedback-screens.md` | C.2: the Diplomacy page is specified in this spec 6.9 |
| `docs/design/war-goals-and-peace.md`, `docs/design/stop-steamrolling.md` | a line under the status: the Godot build is `m9-build-spec.md` |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `godot/README.md` (the keys, diplomacy, the console; V30), `godot/data/README.md` (V1; the
conqueror's line, V31), `CLAUDE.md` (the `diplo_tables.gd` line and the soak's conqueror suite in the Godot commands; V31), `.github/workflows/godot.yml`
(the conqueror shard; V31). No port rule changes: no new autoload, no new layer; `tools/lint_godot.py` needs no entry (new files sit
in listed folders, each under 800 lines: `peace.gd` about 600, `diplo_cache.gd` about 400).

---

## 12. What M9 hands to later milestones

| M | Takes from M9 | M9 leaves for it |
|---|---|---|
| M10 | **Trade agreements and embargoes** as relations: a memory `why` (`trade` +, `embargo` −) and a standing term each in `Relations.standing`; an embargo as a pact the matrix shows (`RelationMatrix` states gain one); `Deal` gains a row (open market, trade rights) priced in score; `Treasury.WHY` `trade`; road works change reach fields (`DiploCache.forget_reach` on a road's `hex_changed`) | Trade |
| M11 | Techs that change `DiplomacyDef` numbers through definitions only (Statecraft: `goal_districts` +2, `price_outside_permille` −250, `infamy_decay` +1, `reach_free` +2); an idea card that halves weariness | Research |
| M12 | **A country that loses everything:** M9 keeps `keep_last_district` true and moves the capital (`Countries.move_capital`); M12 sets it false, adds `Countries.fall` (the dead country's wars end through `Peace.apply` with terms `fallen`, its offers dropped, `Coalitions.season` ends a league on a dead aggressor already, its `RelationBook` rows kept for a later rebirth). **Debt:** `declare_war_check` gains M12's "a country over its debt limit cannot declare" after row 9; tribute and surrender never push a treasury below 0 (D16, D23). **Score:** infamy and weariness are series M12's score may read. The difficulty scale may scale `enforce_net` against the player | A whole game |
| After M12 | **Alliances** (calls to arms, per-ally peace: `Peace.apply` takes the war; `BattleView`'s sides are lists); **rebels and free states** (stop-steamrolling Part C: the defiant band, `gained`, `former`, the regions); **historical claims** (war-goals 3.9: a `claim` reason, a table on the Europe map) | |
| **E2, E3** | **Regions for Europe from `regions.json` in E2's `build_map`; `reach_free`, `admin_free` and the league share re-tuned on Europe (data); the rows of section 8 measured on the made-up Europe.** | |
