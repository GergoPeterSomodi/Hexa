# M12 build spec: A whole game

Technical director (Fable), with the game and systems designer (Opus) for the numbers, 2026-11-17. **Status: a proposal,
design only; it waits for the owner's go.** Builds milestone M12 of `docs/architecture/godot-architecture.md` (the standard),
the last milestone of its table: **the first public Godot release on Windows**. It builds on the M1 build spec, the M1.5 UI
foundation (`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`) and the M2 to M11 specs and plans (`m2-build-*.md` to
`m11-build-*.md`, with `m4-5-build-*.md`), which are binding. Where this page is more exact it wins for M12; section 1.2 lists
every place where it refines an earlier page. The tasks are in `m12-build-plan.md`. This page carries the M12 row of the
standard's 9.1, the M12 row of `ui-and-controls-plan.md` section 4, the M12 row of `ui-style-and-feedback-plan.md` S5, and
every item that M1 to M11 and the UI documents handed to M12 (section 12 lists each one and what closes it).

**What M12 is.** Countries now **owe**: upkeep is always paid, so a deficit drives the treasury below zero, and a country may
also spend on credit. Debt costs **interest**; as it grows the creditors grow wary, then **refuse credit**, and unpaid companies
**desert**. At the **debt limit** a country is **bankrupt** and settles with its creditors in one of three ways (default, pledge
land, pay with the army), each with lasting costs. A country that loses its last district **falls**: its wars end, its armies
are gone, it leaves the ranking. Every country has a **prestige** (the score): land, people, wealth, learning, arms, markets and
deeds, less infamy. Small **events** (incidents: a plague, a fair, a flood, a patron) offer choices. The game **ends** after
Winter 1650, or earlier by conquest or ruin, on a game-over screen with the final ranking. The game gains its **sound**, the
**Audio** and **Keys** option pages, **text size** and **high contrast**, **tutorial hints**, the "Ask before losing progress"
switch, final **credits**, developer tools off by default, and the **release engineering** that turns `master` into a zip a
stranger can download, check and play: the export, the release workflow, logs, save compatibility from now on, budgets on a
stated minimum PC, a smoke test of the exported build, and 100 AI-only games from 1480 to 1650.

**When it starts.** After M11 is closed (its plan's definition of done, and the owner has played it). M12 edits `Game`,
`Session`, `Events`, the action and season tables, `Country`, `Market`, `War`, `Stats`, `GameDefs`, `ScenarioDef`,
`DiplomacyDef`, `AiDef`, `AiTemperDef`, `Treasury`, `Stores`, `People`, `EconomySeason`, `Armies`, `Wars`, `Peace`,
`Coalitions`, `TradePacts`, `Trade`, `Merchants`, `Research`, `Countries`, `StatsSystem`, `Chronicle`, `Vision`, `Knowledge`,
`Words`, the report's view, the reminders, the log lines, the study's views and pages, the cards and panels, the decision queue,
the chips, the console, F3, the App, `Settings`, `KitTheme`, `InkChart`, the options screen, the credits and About screens, the
main menu, the AI, the soak, the perf tools, the tile bake, the UI bake, the export preset and the CI workflows.

**M12 is done when:**

1. **Debt.** On `DebtFixture.lone` (4.14 a) the debt limit is **360**, interest is **2** ducats on a debt of 100 and **8** on
   200, the stage is `debt` below 180, `wary` from 180, `refused` from 306 and the country is bankrupt at the debt phase from
   360; spending is allowed down to a treasury of −306 and refused below; in the refused stage with a deficit of 50 the
   companies desert in troop order until 50 ducats of upkeep are saved; each of the three settlements gives the numbers of 4.14 a
   exactly; every row of `settle_debt_check` with its planted fault (`test_debt.gd`, `test_bankruptcy.gd`).
2. **Countries fall.** On `FallFixture.duel` (4.14 b) a peace that takes the loser's last district makes it fall in that
   season's `extinction` phase: its wars end with terms `fallen`, its armies, merchants' orders, pacts, offers and league seats
   are gone, `country_fell` is emitted once, and every invariant of 4.15 holds (`test_fall.gd`).
3. **Prestige and the end.** `Score.of` equals 4.6's formula on `ScoreFixture.parts` (4.14 c) part by part; the deeds of a
   season come from that season's chronicle and nothing else; a game on `EndFixture.short` (end year = start year) is over after
   its fourth season (`over` `calendar`), End season then refuses "the game is over"; conquest and ruin end it as 4.7 says
   (`test_score.gd`, `test_ending.gd`).
4. **Incidents.** With `IncidentFixture.always` the draw, the place, the choice's effects and the lapse of 4.8 hold for each of
   the eleven incidents, every effect through its owner's writer; the same seed gives the same incidents (`test_incidents.gd`).
5. **Contracts.** `tests/core/test_check_contract.gd` drives the random player over the **40** actions: a refused check changes
   nothing, an allowed one succeeds; `test_owns.gd` finds every new field written only by its owner (5.3).
6. **Determinism and saves.** Same seed and same action log give the same digest after 40 seasons with debt, falls, incidents
   and the dev records (`test_replay.gd`); save, load, save is byte-equal; `SaveFile.FORMAT` is **10**, `OLDEST_FORMAT` **10**
   and frozen; an M11 save reads "Made by an older test build"; the three release saves of `godot/tests/fixtures/saves/0.3.0/`
   load and play a season in CI on every pull request (`test_release_saves.gd`).
7. **A whole game, 100 times.** The `whole` soak suite (100 AI-only games of north Italy from Spring 1480 to Winter 1650, 684
   seasons each) runs with no crash, no script error and every invariant holding every season, and every range of the balance
   gate (4.15) holds; it runs green on the release commit.
8. **Time in budget.** On the made-up Europe the rows of section 8.7 hold in the nightly `perf_core.gd` run (the twenty phases
   other than `ai_orders` under **460 ms**); on the reference PC the release budgets of 8.7 hold; on the Windows runner the CPU
   rows hold.
9. **The release.** Pushing the tag `v0.3.0` runs `.github/workflows/release.yml` to a draft GitHub release with
   `Hexa-0.3.0-windows.zip`, its `.sha256`, and notes from the template and `CHANGELOG.md`; the zip has the layout of 8.3; the
   exported `Hexa.exe` passes the headless smoke (8 seasons, save, load, same digest) and the windowed smoke on the Windows
   runner; `tools/release/check_release.py` passes (one version string, licences complete, changelog section present).
10. Every M12 UI row of the standard's 9.1 and of `ui-and-controls-plan.md` section 4 is in the game, built from the M1.5 kit,
    each with its GUT test: the event pop-up (incidents and bankruptcy), the game-over and prestige screen, the Debt tab, the debt
    chip and the Prestige chip, prestige in Rankings and in the report, the Audio page and bus layout, the Keys page, text size
    and high contrast (charts included, `seal_cracked`), tutorial hints and the hint level, the "Ask before losing progress"
    switch, developer tools off by default with the sandbox hidden, the final credits, the sounds and the music. No stand-in is
    left.
11. The **map look before the release** (8.15) is in: the decor density option, the ranges along crest chains, the finished
    spring and autumn palettes, the high-contrast marks; the art director has signed the release look side by side.
12. Every item of the **no-blocker checklist** (9.3) is ticked in `docs/release/0.3.0-checklist.md`, the owner has played a
    whole game from Spring 1480 to the game-over screen through the release playtest (plan section 4), and the release notes
    are written.
13. Lint, import, check_scripts and GUT are green, with both UI `--check`s, `build_map --check`, `build_scenario.gd --check`,
    `build_tileset --check`, `keys_table.gd --check` and `check_audio.py`; the art director has signed the M12 sheet and the
    pictures of section 9.

---

## 1. What is there, and where this page refines earlier pages

### 1.1 Read in the code (master `c67438c`), the data, v0.2.2 and the specs

| Finding | Where | What it means for M12 |
|---|---|---|
| The code is at M2 (C1 to C13 merged); M3 to M11 are specified and planned, not built. M3 to M11 are GitHub milestones 14 to 23 | `godot/`; `gh` (read only) | M12 builds on their interfaces as specified; their task rows stay as they are, and every edit M12 makes to their files is an M12 task |
| `Settings.SCHEMA` already holds `accessibility/text_size` (100 to 150, `since: "12"`), `accessibility/high_contrast`, `game/confirm_loss`, `game/hints` (off, basic, all), `audio/master`, `music`, `effects`, `ambient`, `audio/mute_unfocused` (all `since: "12"`), `graphics/decor_density` (full, thin, sparse; `since: "12"`) and `dev/developer_tools` (default **true**, `since: "1.5"`) | `godot/shell/app/settings.gd` | The keys exist; M12 makes them work, flips the developer default (D50) and hides `audio/ambient` (D57) |
| `OptionsKeys` already rebinds keys inside the Controls page (capture, clash refusal, Reset keys, `keys/<action>` in `settings.cfg`) | `godot/shell/screens/options_keys.gd` (291 lines) | M12 moves it to its own **Keys** page and completes it (D52) |
| `Options.PAGES` is Display, Graphics, Controls, Map, Accessibility, Advanced, About; `TARGET_MILESTONE := 1.5` compared as `float(since)` | `godot/shell/screens/options.gd` | M12 adds Audio and Keys; the milestone comes from the App (D49) |
| `KitTheme.load_for(ui_scale, kit_mode, high_contrast)` and `theme_high_contrast.tres` exist (the flat theme of the style spec 4.9) | `godot/shell/ui/kit_theme.gd`, `godot/shell/ui/theme_high_contrast.tres` | Text size is a fourth argument; the high-contrast theme gains the chart inks and the bold marks (D54, D55) |
| `ScreenStack` has `signal changed`; `ShellContext` has `toast_requested`, `app_requested` and `request(what, args)` | `godot/shell/ui/screen_stack.gd`, `godot/shell/app/shell_context.gd` | The sound board hears screens through `changed` (6.9) |
| About shows the version, engine, system, renderer, screen, memory, game and folders with **Copy diagnostics**; Credits renders `res://CREDITS.md` | `godot/shell/screens/about.gd`, `credits.gd`, `godot/CREDITS.md` | M12 adds the logs and the last run's tail to About and completes the credits (8.5, 8.12) |
| `project.godot`: `config/version="0.3.0"`, `use_custom_user_dir` "Hexa", `auto_accept_quit=false`, Compatibility renderer, `import_etc2_astc=true` | `godot/project.godot` | The version string's one home (D2); logging and the crash message are added (8.5) |
| `export_presets.cfg`: "Windows Desktop", `embed_pck=true`, `s3tc_bptc=true`, `export_filter="all_resources"`, no exclude filter, `file_version="0.3.0.0"` and `product_version="0.3.0.0"` written by hand, `export_angle=0`, `codesign/enable=false` | `godot/export_presets.cfg` | Tests, tools and GUT are exported today; the version is written twice; M12 fixes both (8.2) |
| CI: `export-windows` and `smoke-windows` run on a tag `v0.3.*` or by hand; the smoke starts `Hexa.exe --headless --quit-after 60` | `.github/workflows/godot.yml` | M12 moves them into `release.yml` and makes the smoke play seasons (8.4, 8.9) |
| `CHANGELOG.md` gives 0.3.x to the Godot port ("0.3.0 The map ..."), 0.9.x to Steam Early Access, 1.0 to Steam | `CHANGELOG.md` | The first public Godot release is **0.3.0** (D2); M12 rewrites the 0.3.x header |
| No sound file, no bus layout, no `assets/audio/` | `godot/` | Sound is new (6.9) |
| Debt in v0.2.2: limit `max(DEBT_FLOOR 300, DEBT_SEASONS 6 × running costs)`; interest `DEBT_INTEREST` 2 % a season on the debt up to the limit; over the limit with a deficit: troops desert (oldest era, weakest, farthest), then creditors seize one level at a time, then the debt is held at the limit | `hexa/campaign/systems/debt.py` (129 lines), `systems/economy.py` 225, `data.py` 478 to 482 | Section 3 |
| Score in v0.2.2: `people / 20 + max(0, balance) × 3 + colonists × 2 + max(0, treasury) / 50`, 0 when dead; ranking: living countries by score; the "prestige" chip showed the score | `systems/season.py` 161 to 172; `resources.py` 80 | Prestige is the score (D27) |
| The end in v0.2.2: `advance_turn` sets `world.over` when the year passes `END_YEAR` 1650; a banner gives the top three and the player's place | `systems/season.py` 54 to 60; `app.py` 804 to 830 | 4.7 and the game-over screen (6.5) |
| Extinction in v0.2.2: `check_alive`: no province → `alive = False`, its battles end, its units and wars removed, "X has disappeared from the map." | `systems/war.py` 672 to 681 | 4.5 |
| The bankruptcy and event pop-ups are drawn: `10_bankruptcy_popup.png` (three cards: default, pledge provinces, pay with the army; a stats strip; "No Cancel: the game waits for a choice"), `09_debt_bar_and_panel.png` (option A: one number with the stage gauge, the countdown and "Ways out"; option B: loans), `15_event_popup_frame.png`, `16_event_art_compare.png` (composed from tiles or painted) | `docs/design/ui/` | 6.3, 6.4; option A and composed pictures (D6, D39) |
| The owner's open questions on debt (loans, which penalties, creditor countries, duration, carry-over) | `docs/roadmap/debt-and-bankruptcy.md` | Answered by D6 to D16 |
| Achievements' owner decision 3 (2026-11-13): "No difficulty setting; skill achievements use fixed conditions" | `docs/design/achievements.md` | No difficulty in M12 (D40), closing M8 D29 and M9's hand-off |
| The owner's answers of 2026-11-15: the first public release is a land game; north Italy until the owner is happy with the features, then Europe; "the hex-edge coast with a drawn wobble is accepted" | standard, "Owner's answers" | D3, D5 |
| Built by M1.5 to M11 and named "(M2)" to "(M11)" below: every class of `m11-build-spec.md` 1.1's last row, plus `Research`, `Generals`, `ModsCache`, `ModApply`, `ResearchView`, `IdeaPick`, `TechScreen`, `ResearchFixture`, `research_report.gd`, `DecisionQueue`, `SeasonFlow`, `BusyPill`, `AiTurn`, `AiResearch`, `PageEconomy`, `StudyRankings`, `StudyEconomy`, `StudyPage`, `InkChart`, `StudyTable`, `VellumSheet`, `ResourceChip`, `EconomyCards`, `CountryCard`, `PeaceView`, `RelationBook`, `Relations`, `Brakes`, `Coalitions`, `WarScore`, `Market`, `MerchantOrder`, `TradePact`, `PerfFixture`, `UIHarness`, `Thumbnail`, `RunLock`, `SaveFile`, `Snapshot` | their specs | M12 starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M12 | Why |
|---|---|---|
| M4 D19: "nothing that costs ducats can begin while [the treasury] is under the cost"; `Treasury.can_pay` is `treasury >= ducats`; `EconomySeason.debt_limit` returns 0 | `Treasury.can_pay(game, tag, ducats)` is true for `ducats <= 0` and otherwise `treasury - ducats >= -Debt.credit_line(game, tag)`; `EconomySeason.debt_limit` returns `Debt.limit` (4.1) | Debt as a tool (borrow to win a war) needs credit; one function changes, every check that called it follows; M4's "a free clear refused below zero" goes away |
| M4 4.18 `treasury_empty` ("The treasury is empty: 120 ducats owed. Upkeep is still paid; no work can begin.") | Same rule id, new words by stage (4.12) | Work can now begin on credit |
| M4.5 D9: income = `Treasury.left_over` | `interest` counts in `left_over` (a running cost) and in `StudyRankings.income_of` (`− interest`); `bankruptcy` and `incident` lines do not (one-off, like M9's `tribute`) | Rankings stays equal to the report's Standing (M4.5 done-when 5) |
| M4.5 `PageEconomy.TABS` `{id = &"debt", title = "Debt", since = "12"}` with no scene | Gains `scene = "res://shell/screens/study/economy_debt_tab.tscn"` (6.4) | The tab's page |
| M4.5 / M3: `since` strings compared "since <= milestone" with no type | Every `since` (settings rows, bindings, tabs, pages, filters, measures) is compared as a **number** (`float(since) <= float(milestone)`) through one helper, `Words.since_shown(since, milestone)` (**new**, core views; the shell calls it too) | As text "12" < "4.5": the Debt tab would show early and the War filter vanish at "12" |
| M7 D33, M9 `DiplomacyDef.keep_last_district` true | **false** in `data/defs/diplomacy.tres` (the class default stays true for fixtures); a peace may take the last district and the country falls (4.5) | "Countries that fall are M12's" |
| M9 `Peace.TERMS`, `DiplomacyDef.TERMS`, `War.terms`, `truce_of`, `Words.terms_text` | Gain **`fallen`**: the war of a fallen country ends with it, the other side the winner, no truce (`truce_of(&"fallen")` 0) | M9's hand-off: wars end through `Peace.apply` with terms `fallen` |
| M9 `peaces` invariant: "its loser kept at least one district" | "its loser kept at least one district, or fell in that season's `extinction` phase" | `keep_last_district` off |
| M9 `declare_war_check` rows 10 to 15 | A row **9a** after row 9: "your creditors will not fund a war: your debt is past the credit line" (stage `refused` or a bankruptcy pending); rows 10 to 15 keep their numbers | M9's hand-off; M9's pins name rows 10 to 14 |
| M10 D57: "M12's ways out may add a switch" for buying | **No switch**: a country in debt already buys nothing (M10 step 4's `max(0, treasury)`) | The rule exists; a switch adds a choice with no use |
| M10 hand-off: "the markets held as series M12's score may read" | No series: `Score` counts the markets a country controls from `Trade` at the `scores` phase | The number is in the state; a series would duplicate it |
| M10 hand-off: trade fairs "if the events design wants them"; M10 D24 and 1.3: "fairs after M12" | **Fairs are an incident** (`trade_fair`, 4.8) through `Trade.appetite` | The events design wants them; the two M10 lines disagreed |
| M10 `Merchants.WHY` (idle, loss, closed, gone) | Appends **`bankrupt`**; a fallen country's orders go with `gone` | M10's hand-off: orders home at bankruptcy |
| M11 `fund_research_check` | Gains a row after its last refusal row: "your treasury is in debt" (treasury < 0) | M11's hand-off |
| M6 `Armies.lose_men(game, army, amount, why)` | `why` **`deserted`** (debt) and **`fallen`** (a country that falls) | M6's hand-off |
| M3 4.2: `stats` "after the scores (M12)"; M4 to M11's planned rows 9 and 13 | **21 phases**: `debt` after `income`; `incidents`, `extinction`, `scores` after `research` and before `stats` (4.10) | The standard's rows 8 and 12; the incidents need the season's people and research |
| M3 D3 and 4.2: "(M12) the calendar has passed Winter 1650: the game is over"; M8 "the full-length soak to 1650 (680 seasons)"; M11 "681 seasons" | A game of the 1480 scenario has **684 seasons** (turn 1 Spring 1480 to turn 684 Winter 1650); `game.over` is set in the `scores` phase of turn 684; End season refuses from then on (4.7) | One number; M8's 680 and M11's 681 were off |
| M3 `Season.end_check` rows (choose your country, the game is over) | Adds "settle with your creditors first" (the player's bankruptcy pending) | The mockup: "No Cancel: the game waits for a choice" |
| M8 `Game.watch()`: only during the pick | Also when the player's country has fallen (ruin): the game goes on AI-only to 1650 | The game-over screen's "Watch to the end" (6.5) |
| M3 D31: "from M12 every bump has an upgrade and CI loads saves kept from each release"; M3 4.10 `other_build` greys a save whose scenario digest differs | `OLDEST_FORMAT` frozen at 10; `ScenarioDef.known_digests` lets a save of an earlier release's scenario load; "The save is damaged" is not checked on an upgraded save (8.6) | Otherwise any data fix after 0.3.0 would grey every save |
| `ui-and-controls-spec.md` 7: tutorial hints "anchored to Controls by node path, from a hint table (`.tres`)" | Kept: `HintDef.anchor` is a `NodePath` from the App; a test resolves every anchor in the harness App (6.8) | As specified |
| `ui-and-controls-spec.md` 6.6: Volumes master, music, effects, ambient | Ambient has a bus but no sound in 0.3.0: its row is hidden (`since: "13"`) (D57) | A slider with nothing to hear is a stand-in |
| `ui-and-controls-plan.md` section 4, "Map-look milestone"; `m1-build-spec.md` 14 "(before the first public release)" | The look items that change the map's data-to-tile rules ship in M12 (8.15); the renderer items go to **M14 Map look II** (section 13) | D5 |
| `game-feedback-screens.md` A.4: "Score 48 ▲ +2, 3rd of 6." | The word is **Prestige** ("Prestige 412 ▲ +3, 3rd of the 6 you know.") | The chip is named Prestige (M4) and v0.2.2's prestige chip showed the score (D27) |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days). Data changes are a
`.tres` edit plus the test that pins the value. Every number below lives in a definition (`data/defs/debt.tres`,
`score.tres`, `incidents.tres`, `incidents/*.tres`, `diplomacy.tres`, `tempers/*.tres`, `ai.tres`, the scenario) and
`godot/tools/whole_tables.gd` prints them.

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | What M12 builds | Debt and bankruptcy, countries that fall, prestige and the end, incidents, their screens, the remaining options and accessibility, hints, sound, credits, the map look before the release, release engineering and the whole-game proofs | The standard's M12 row and every hand-off of section 12 | none |
| D2 | Name and version | **Hexa 0.3.0**, tag `v0.3.0`; the one version string is `godot/project.godot` `application/config/version`; the export preset's version fields are empty (Godot fills them from it); the save header's `build`, the About page and the main menu read it | `CHANGELOG.md` gives 0.3.x to the Godot port and 0.9/1.0 to Steam; 0.3.0 was never tagged | S |
| D3 | Play area of 0.3.0 | **North Italy**, scenario Italy 1480 (13 countries); the made-up Europe stays the speed proof | E2's map file does not exist; every soak range of M8 to M11 was set on north Italy; the owner: "north Italy until the owner is happy with the features" | Europe is **M13** (section 13) |
| D4 | When Europe switches in | When all of 8.14 hold on the real map: E2's file and a Europe 1480 scenario validate; M8 8.3's criteria; the `whole` suite on Europe (20 games) with no crash and the ranges of 4.15; the owner's word. It ships as 0.4.0 | M8 8.3 wrote the measured half; the rest makes it a game | none (criteria) |
| D5 | The map look before the release | **In M12:** decor density, ranges along crest chains, finished spring and autumn palettes, bold high-contrast marks, and the art director's side-by-side of the release look. **M14 Map look II (after M12):** the real shoreline as meshes, a ground splat shader, trees one by one, bridge and road restyle, water and coast animation, a 2x bake for Retina, mipmaps | M1 14 put the look "before the first public release"; the owner accepted the hex-edge coast (2026-11-15); the renderer items carry frame-budget risk on the 122,000-hex map and the release is Windows-only | L (each renderer item is about a week) |
| D6 | The debt model | **One number** (option A of `09_debt_bar_and_panel.png`): debt is a negative treasury; no loans as an action | One rule the player reads at a glance; loans (option B) need a lender model; they come with **M18 Crown projects and loans** (section 13) | L |
| D7 | The debt limit | `limit = max(debt_floor 300, debt_seasons 6 × costs)`, costs = the mean of the last `cost_seasons` 4 seasons' `upkeep_districts + upkeep_walls + upkeep_army` from `Stats` (fewer rows at the start; none: the floor) | v0.2.2's rule at district scale; a stable number that a single bad season does not move | Data (S) |
| D8 | Stages | By debt / limit in permille: **`debt`** (0 to 499), **`wary`** (500 to 849), **`refused`** (850 to 999); **bankrupt** at 1,000 or more in the debt phase; `solvent` at a treasury ≥ 0 | The mockup's gauge: interest 2 %, interest 4 %, credit refused, bankrupt | Data (S) |
| D9 | Interest | Each `debt` phase: `ceil(min(debt, limit) × rate / 1000)`, rate **20** permille (`debt`), **40** (`wary`, `refused`), plus **30** for 80 seasons after a default; a ledger line `interest` | v0.2.2's 2 % on the debt up to the limit; the rising rate is the roadmap's first warning | Data (S) |
| D10 | Credit | A cost may be paid while `treasury − cost ≥ −credit_line`, `credit_line = limit × 850 / 1000`; 0 while a bankruptcy is pending and for **8** seasons after one (`fresh_seasons`) | "Borrow to win a war" (the roadmap's fun test); the line stops before the limit, so spending alone never makes a bankruptcy | Data (S) |
| D11 | Desertion | In the debt phase, a country in stage `refused` whose season (after interest) closed below 0 loses companies in `Debt.troop_order` (oldest era first, then the fewest men, then farthest from the capital; never a general) until their upkeep covers the deficit, at most half its companies a season; men lost through `Armies.lose_men(why deserted)`; one `troops_deserted` event | v0.2.2's `disband(need)`; M6's hand-off | S |
| D12 | Bankruptcy | In the debt phase, a living country with `debt ≥ limit` becomes bankrupt: `pending_settle` set, interest stops, credit 0, the `bankrupt` event. Its owner settles with `settle_debt`; a settlement still pending at the next debt phase is a **default** (`why lapsed`). For the player, End season is refused while one is pending | The mockup's "the game waits for a choice"; the AI acts in the next `ai_orders`, before the next debt phase | S |
| D13 | The settlements | **Default:** the debt wiped; taxes and the merchants' trade line −25 % fading to 0 over 40 seasons; interest +3 points for 80 seasons; each creditor remembers `defaulted` −50; deeds −20. **Pledge land:** the debt wiped; the first creditor takes districts (never the capital) nearest its land until their worth × 30 ducats covers the debt, at most a quarter of the bankrupt's districts (needs 4 or more); deeds −20. **Pay with the army:** the debt halved; half the companies desert (dearest upkeep first); every fortress of level 2 or more loses a level; deeds −10 (4.3) | The three cards of `10_bankruptcy_popup.png`, at district scale; the dice of card 3 are dropped (D33's luck stays in incidents) | Data (S) a number |
| D14 | Creditors | `ScenarioDef.creditors`: **GEN, TUS, VEN** for Italy 1480 (the Casa di San Giorgio, the Medici bank, the Venetian banks); living, not the debtor, not at war with it, in that order; with none, the two living countries with the largest treasury | The mockup's "Genoa and the Fuggers"; a scenario names its bankers | Data (S) |
| D15 | Every bankruptcy also | Generals dismissed (`why bankrupt`), merchants' orders home (`Merchants.WHY` `bankrupt`), no credit and no second bankruptcy for 8 seasons, `bankruptcies` counted; works already paid go on | M10's and M11's hand-offs | S |
| D16 | Ways out | The Debt tab lists actions that exist, each with its effect a season from `EconomyPreview.with`: taxes to High (`set_tax`), disband the oldest companies (opens the army), recall a merchant at a loss (`recall_merchant`), cancel works begun this season (`cancel_work`), sue for a white peace (opens the peace screen). **No "sell a building" action** | Every way out is an action with its check; selling is a new rule with its own balance | M (a sell action) |
| D17 | War on credit | `declare_war_check` row 9a refuses in stage `refused` or with a bankruptcy pending; at stages `debt` and `wary` war is allowed | M9's hand-off ("over its debt limit cannot declare"), at the line where credit stops | S |
| D18 | Research in debt | `fund_research_check` refuses "your treasury is in debt" below 0 | M11's hand-off | S |
| D19 | Tribute and surrender | Unchanged: never push a treasury below 0 (M9 D16, D23); bankruptcy never pays a winner | M9's rule | none |
| D20 | Purchases and merchants' losses | Their ledger lines (`purchases`, `trade`) count in the season's net like any line; buying stops in debt by M10's own rule | M10's hand-off is already true by construction | none |
| D21 | Earlier pins | Every M3 to M11 test runs on **`DebtFixture.off`** (no limit, no interest, no stages, no credit: M4 D19 exactly; no incident, no fall check); M12's own tests turn them on | M11's `ResearchFixture.off` pattern | S |
| D22 | When a country falls | In the `extinction` phase, a living country that owns **no district** falls (`Countries.fall`). People go with their land (M9 `Territory.transfer`), so "when their people do" (M5) is the same moment | One rule; land is what a country is | S |
| D23 | The last district | `keep_last_district` false: a peace may take it; the capital moves while any land is left (M9 `move_capital`) | M9 D25 | Data (S) |
| D24 | What falling does | `alive` false, `fell_turn`; its live wars end through `Peace.apply` with terms `fallen` (the other side wins; nothing moves; its occupations released); its armies lost (`why fallen`) with their generals; its merchants' orders freed (`gone`); its pacts ended; it leaves every league as member and as eligible (a league against it ends: M9); its pending offers dropped; its relation memories kept; its stats rows kept; `country_fell` | M9's and M10's hand-offs, v0.2.2's `check_alive` | S |
| D25 | Countries that rise | **None in 0.3.0**; the colour-blind colour of a new country (M2's hand-off) comes with **M16 Rebels and free states** | No rule makes a country in M12 | none |
| D26 | The player's country falls | The game is over (`ruin`) at the end of that season; the game-over screen offers **Watch to the end** (M8's `Game.watch`, extended) and Main menu | The player sees the ending; watching costs nothing | S |
| D27 | Prestige | The score is called **Prestige** in every word the player reads; the code says `score` (`Score`, `Country.score`, the `score` series of M3); the Prestige chip (M4's baked icon `prestige`) shows it | v0.2.2's prestige chip showed the score; one word | S |
| D28 | The formula | `score = land + people + wealth + learning + arms + markets + deeds − infamy` (4.6), integers, 0 for a fallen country | Every hand-off's part: people (M5), men (M6), battles (M7), infamy (M9), markets and trade (M10), research (M11) | Data (S) a weight |
| D29 | Deeds | `Country.deeds`, changed only in the `scores` phase from the season's chronicle entries (battles, peaces, falls, bankruptcies, eras, incident choices); never decays | One writer; the chronicle already holds every notable thing | S |
| D30 | Weariness in the score | **Not counted** (it already costs income); infamy is | No double count | Data (S) |
| D31 | The ranking | Living countries by score, ties by id; fallen ones below, the latest fallen first; during play only known countries, banded (M4.5); **at the game's end every country is known and exact** | M4.5's fog rule while it matters; the ending reveals all | S |
| D32 | The end | Over by **calendar** after Winter 1650 (`ScenarioDef.end_year` 1650, turn 684), **conquest** (the player, or in a watched game one country, is the only living country), or **ruin** (the player's country fell). No play after 1650: the game stays open to view, save and leave | v0.2.2's end; nothing in the data goes past 1650 | S |
| D33 | Incidents (events) | **Eleven** data incidents (4.8): each season each living country rolls `chance_permille` **50** from `luck.world` (id order), then draws one allowed incident by weight; each at most once in `cooldown_seasons` 40 per country, none before turn 5, one open at a time | The UI row "event pop-ups"; M5's plague and famine; M10's fairs; small and data-driven | Data (S) an incident |
| D34 | Incident effects | Eight kinds, each through its owner: `ducats` (`Treasury.move`, why `incident`), `goods` (`Stores.move`), `people` (`People.move`, why `plague` or `incident`), `opinion` (`Relations.remember`), `fair` (`Trade.add_fair`, **new**), `research` (`Research.add_progress`, **new**), `men` (`Armies.add_men`), `deeds` (read by `Score` from the chronicle) | One owner per field | S a kind |
| D35 | Answering | The player's incident is a decision (`DECISIONS`); Esc decides later; one still open at the next incidents phase takes its **last choice** (always the passive one) (`why lapsed`). The AI takes the allowed choice with the highest `ai_value` at once | M11's idea pattern; the passive choice is the safe lapse | S |
| D36 | Fairs | The `trade_fair` incident: a charter multiplies one market's appetite for one good by 1,500 permille for 4 seasons through `Trade.appetite` | M10's note, step 3 | Data (S) |
| D37 | Plague and famine | `plague` and `famine` are incidents; People's flows append **`plague`** and **`incident`**; famine's choices act on stores and ducats, never on M5's hunger rule | M5's hand-off; one cause per effect (M5 D19) | S |
| D38 | The pop-up frame | Option A of `15_event_popup_frame.png` only (centred, `MODAL`); option B (a small card tied to a hex) not built | One frame for incidents and bankruptcy; B is a second frame for few events | M |
| D39 | Pictures | **Composed from the map's own tiles** (`16_event_art_compare.png` option 1): the incident's hex and its ring drawn by a `TileVignette` with the season's TileSet; painted pictures not made | 0 KB a picture, always the right place and season | M |
| D40 | Difficulty | **None** | The owner's achievements decision 3 (2026-11-13); closes M8 D29 and M9's "may scale `enforce_net`" | M |
| D41 | The AI's money | A new step `debt` after `brief`: settles a pending bankruptcy; in stage `wary` or worse: recalls merchants at a loss and cancels this season's works; M8's tax and disband rules and M9's white peace at `T < 0` stay; it answers its incidents at once | M8's hand-off; the AI already has the distress rules | S |
| D42 | The AI's settlement | `AiTemperDef.bankrupt_pick`, the first allowed of: builder `army, default, pledge`; cautious `default, army, pledge`; steadfast `pledge, default, army`; aggressive `default, pledge, army`; opportunist `pledge, army, default`; conqueror `default, pledge, army` | Data, like every temperament choice | Data (S) |
| D43 | The season table | **21** phases (4.10) | Standard rows 8 and 12, plus incidents | S (the pin) |
| D44 | Events | Eight kinds: `debt_stage_changed`, `troops_deserted`, `bankrupt`, `debt_settled`, `country_fell`, `game_over`, `incident_offered`, `incident_resolved` (4.11) | Each something the player should notice | S a kind |
| D45 | Saves | `SaveFile.FORMAT` **10**, `OLDEST_FORMAT` **10**, **frozen**: from 0.3.0 every bump adds `_upgrade_<n>` and no save of a public release is refused | Standard 5.5; M3 D31 | none (policy) |
| D46 | Save compatibility in CI | Three saves made by the release build (`godot/tests/fixtures/saves/0.3.0/`: Spring 1481, Spring 1520, the game over of `EndFixture.italy_short`) load and play a season in `test_release_saves.gd` on every pull request; each release adds its three | M3 D31's "CI loads saves kept from each release" | S |
| D47 | Data fixes after a release | `ScenarioDef.known_digests` (the digests of earlier releases' scenario files) is accepted by the header check; a changed map digest needs a format bump with an upgrade; the "damaged" check is skipped for a save that was upgraded | A typo fix in a `.tres` must not grey every save | S |
| D48 | Settings across versions | `settings.cfg` gains `[meta] schema = 2`; a file without it (a test build's) loses its `dev/*` keys on load; unknown keys and actions are dropped (M1.5's rule) | Every tester's file holds `dev/developer_tools = true`; the flip must reach them | S |
| D49 | `since` | Compared as numbers by `Words.since_shown` (core; the shell's settings rows, bindings, tabs and pages call it too); the App's milestone is `"12"` | 1.2 | S |
| D50 | Developer tools | `dev/developer_tools` default **false**: the sandbox entry, F3, F2, Ctrl/Cmd+R and the dev console are hidden; the Advanced page still offers the switch; `-- --dev` turns them on for one run; `-- --sandbox` implies `--dev` | `ui-and-controls-spec.md` 5.1, 6.7, Q11: "On until M12" | S |
| D51 | "Ask before losing progress" | `game/confirm_loss` (On) governs leaving to the menu, quitting, closing the window, New game and loading over unsaved progress; **overwriting and deleting a save always ask** | A file deleted cannot be won back by play | S |
| D52 | The Keys page | Its own page after Audio: every keyboard action of milestone 12 by group, two key caps an action, click a cap and press a key; Esc cancels; a clash is refused naming the other action; per-action reset and "Reset all keys"; mouse buttons and gestures shown, not rebindable; `app_back` cannot lose Esc | The rebinding page of `ui-and-controls-spec.md` 6.4; the capture code exists | S |
| D53 | The build list by keys | With the hex panel focused, **1 to 9** press the n-th build option (the works card opens as with a click); otherwise 1 to 8 stay the map modes | `ui-and-controls-spec.md` 4.5 ("number keys in the open panel is M12") | S |
| D54 | Text size | 100 % to 150 % in steps of 10 (the schema's int range, the slider snaps to 10); `KitTheme.load_for(..., text_percent)` scales every font size of the Theme, `InkChart` reads the Theme's sizes; applied at once | `ui-and-controls-spec.md` 6.5; game feedback D.4 | S |
| D55 | High contrast | The player's row; the flat theme gains the chart inks (`ink_0..4` at 7:1 or more on black, each with M4.5's dash and marker), a flat `seal_cracked`, the 3 px INFO focus ring; the map uses the bold select and grid tiles and the mode overlay's alpha 0.75 | Style spec 4.9; design.md 8 | S |
| D56 | Tutorial hints | **20** hints in `data/ui/hints.tres` (6.8): level Basic (15) or All (5 more); each shown once (`state/hints_seen`), one at a time, after its trigger; a bubble anchored by `NodePath`; "Hide hints" sets the level to Off | `ui-and-controls-spec.md` 7 | S a hint |
| D57 | Sound | Effects from **Kenney's CC0 packs** (Interface Sounds, RPG Audio, Impact Sounds, Music Jingles); music: **three tracks** we render from public-domain Renaissance dances (Susato 1551, Praetorius 1612, Arbeau 1589) with the FluidR3_GM soundfont (MIT); **no ambient** in 0.3.0 (bus kept, row hidden) | Clear licences; no cost; design.md 7's list | M |
| D58 | Buses and mixing | `default_bus_layout.tres`: Master (a limiter at −1 dB), Music, Effects, Ambient; effects at −3 dBFS peak, music at about −20 LUFS; one sound id at most every 120 ms; 6 effect voices; music shuffled with 20 s of silence between tracks | Quiet, readable, never stacked | S |
| D59 | Credits | `godot/CREDITS.md` complete (8.12): the project, Godot and its third-party notices (from `Engine` at run time), fonts, map data (ETOPO 2022, GeoNames), sounds (Kenney), music (composers, our renderings, FluidR3_GM); the credits screen shows it with the engine notices; reached from the main menu, About and the game-over screen | Every licence's terms met | S |
| D60 | Localisation | **Not in 0.3.0** (English only). Strings stay in one place by layer: core sentences only in `Words`, names in the `.tres` files, shell labels in the scenes and the shell's scripts; new shell text goes through `tr()`-ready constants (6.13) | Localising later is a PO file and `tr()`, not a rewrite | L (when it comes) |
| D61 | Installer | **A zip**, no installer | No admin rights, no uninstaller, user data already in `%APPDATA%\Hexa` | M (an Inno Setup script) |
| D62 | Code signing | **Unsigned** in 0.3.0; the release notes say how to pass SmartScreen ("More info", "Run anyway") and publish the SHA-256; signing is revisited for Steam (0.9) | A certificate costs a yearly fee and SmartScreen trust builds slowly; Steam does not need it | M |
| D63 | Logs and crashes | Godot's file log on (`user://logs/hexa.log`, the last **10** kept, rotated at start); the App writes a header line (version, system, renderer) at start; a crash message names the folder; About opens the folder and copies the last run's tail when it did not close cleanly | One place to look; no crash service | S |
| D64 | The release workflow | `.github/workflows/release.yml` on a tag `v*.*.*`: checks, export, licences, zip, checksum, smokes, draft release (8.4) | A tag makes the whole release | S |
| D65 | Changelog | `CHANGELOG.md` is the source; the workflow takes the section `## v0.3.0` into the notes | One place, already kept | S |
| D66 | Minimum PC | Windows 10 22H2 or 11, 64-bit; 4 threads at 2.5 GHz; 8 GB RAM; an OpenGL 3.3 GPU with 2 GB (Intel UHD 620 class); 1 GB of disk; 1280 x 720 (8.7) | The Compatibility renderer's floor; the budgets are measured on the reference PC and on the runner | S (words) |
| D67 | Smoke test | The exported exe runs `-- --smoke --seasons=8`: a new game as Genoa, 8 seasons with the AI, save, load, the same digest, 2 more seasons from both, exit 0 (8.9) | Proves the export plays, not only starts | S |
| D68 | Whole-game rig | The `whole` soak suite: seeds 1 to 100, 684 seasons, AI-only, north Italy; 10 seeds nightly, all 100 on the release commit (4.15) | The standard's "start to 1650 with no blocker" | S |
| D69 | "No blocker" | The checklist of 9.3, every item measurable, ticked in `docs/release/0.3.0-checklist.md` | A word turned into a list | none |
| D70 | The balance gate | The ranges of 4.15 on the `whole` suite; a failed range is a data change in the tuning task, read by Opus | The fun is in the numbers | Data (S) |
| D71 | The game-over screen | An opaque letter: why it ended, your place and prestige by part, the chart of your prestige, the final ranking of every country, five highlights from your chronicle; buttons View the map, Watch to the end (ruin only), Credits, Main menu | v0.2.2's banner, as a screen | S |
| D72 | Dev records | `dev_incident` and `dev_year` (logged, replayed); `Game.dev_used` (saved) set by any dev record; the game-over screen says so | Playtests reach 1650 in minutes; achievements later need the flag | S |
| D73 | Steam | Not in 0.3.0; with 0.9 (section 13) | The standard's "not covered" list | none |
| D74 | The Mac | A development platform only; no Mac build is published | The owner: Windows only | none |
| D75 | Caps in long games | M8's caps stay: `Chronicle.KEEP` 3,000, `Snapshot.LOG_SEASONS` 40, `battle_records_kept` 60; a save stays under 2 MB on north Italy at 1650 (measured by the suite) | Bounded saves; replay is from a save, not from 1480 | Data (S) |
| D76 | The decisions' order | War alerts, peace alerts, offers, leagues, ideas, then **bankruptcy**, then **incidents** | M9 and M11's pins keep their order; End season waits for the bankruptcy anyway | S |
| D77 | Report | No new section: the treasury section gains interest, bankruptcy and incident lines; glance chips for a stage change, a bankruptcy, a fall and a prestige swing; Standing gains prestige; What befell gains falls and others' bankruptcies; the seal is **cracked** in a season of your bankruptcy or a fall you witnessed of your own land | Fourteen sections are enough (M11) | S |
| D78 | The Debt tab | Option A's panel: the debt and limit, the stage gauge, the countdown, this season, the ways out, the debt of the last 8 seasons, your bankruptcies and their penalties (6.4) | The mockup; the Economy page's fifth tab | S |
| D79 | The chips | The Ducats chip becomes a debt chip below 0 (a scroll icon `debt`, red value, the stage gauge under it); the **Prestige** chip after Research | `09_debt_bar_and_panel.png` note 1; M4's chip list | S |
| D80 | Luck | Two new draws, both `luck.world` in id order: the incidents' roll and draw. Bankruptcy has no dice | Standard 5.4 | none |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| `debt_limit`: `max(DEBT_FLOOR 300, DEBT_SEASONS 6 × running costs)`, costs = upkeep, military and colonies of the season | `systems/debt.py` 21 to 26; `data.py` 478 to 482 | The floor, the six seasons | Costs averaged over 4 seasons of M4's and M6's upkeep series (D7); no colonies |
| Interest 2 % a season on the debt up to the limit | `systems/economy.py` 225 | 2 % up to the limit | 4 % past half the limit; +3 points after a default (D9) |
| Spending only from a positive treasury | `systems/building.py` (`build_check`), `military.py` | | Credit to 85 % of the limit (D10) |
| `troop_order`: oldest era, then weakest, then farthest from the capital; never the general | `systems/debt.py` 29 to 36 | The order (fewest men for "weakest") | Generals are traits on armies (M11): an army's general is dismissed, not deserted |
| `disband(need)`: remove troops until the deficit is saved | `systems/debt.py` 39 to 51 | Desertion until the deficit is saved | Only in the `refused` stage, at most half the companies a season (D11) |
| `seize_one`: creditors take one level of the costliest holding a season | `systems/debt.py` 54 to 98 | | Replaced by the pledge settlement, chosen once (D13) |
| `unpaid`: desertion, seizures, then the debt held at the limit ("the creditors refuse more credit") | `systems/debt.py` 101 to 129 | "Credit refused" as a stage | Bankruptcy at the limit with three settlements (D12, D13), as the owner's roadmap asks |
| The AI in distress: raises taxes, stops spending, disbands until it runs a surplus | `ai.py` 57 to 79 | All of it (M8 already) | Plus its settlement by temperament (D42) |
| `score`: `people / 20 + max(0, balance) × 3 + colonists × 2 + max(0, treasury) / 50`; 0 when dead | `systems/season.py` 161 to 166 | People, wealth, a treasury part; 0 when dead | Parts at district scale with land, learning, arms, markets, deeds and infamy (4.6); the treasury part capped (crown projects' question 4) |
| `ranking`: living countries by score | `systems/season.py` 169 to 172 | | Ties by id; the fallen below; known countries only until the end (D31) |
| The end: `advance_turn` sets `over` past 1650; a banner with the top three and the player's place, "Press L for the ledger" | `systems/season.py` 54 to 60; `app.py` 804 to 830 | Over after 1650; the ranking and your place | A game-over screen; conquest and ruin end it too (D32) |
| `check_alive`: no province → dead, its battles end, units and wars removed, "has disappeared from the map"; a capital lost → moved | `systems/war.py` 672 to 681 | All of it | Wars end through M9's `Peace.apply` with terms `fallen`; M10's orders and pacts; M9 moves capitals already (D24) |
| `PHASES`: `debt` after `collect`, `extinction` after `research` | `systems/season.py` 176 to 193 | The two places | Plus `incidents` and `scores` (4.10) |
| No events system; the debt roadmap's pop-up "can share the system with the RPG-style events (Phase 3)" | `docs/roadmap/debt-and-bankruptcy.md` | | Incidents and the bankruptcy share one pop-up (D38) |
| No sound | | | Sound is new (6.9) |
| `resources.py` "prestige": the score on the top bar | `hexa/campaign/resources.py` 80 | The chip shows the score | Called Prestige everywhere (D27) |

---

## 4. Design content

### 4.1 Debt: the limit, the stages, interest and credit

For a country `c` (all amounts whole ducats; `Debt` computes, `Treasury` writes):

| Name | Rule | Data (`DebtDef`, `data/defs/debt.tres`) |
|---|---|---|
| `debt` | `max(0, -treasury)` | |
| `costs` | the mean, over the last `cost_seasons` rows of `Stats` for `c` (fewer at the start), of `upkeep_districts + upkeep_walls + upkeep_army`; 0 with no row | `cost_seasons` 4 |
| `limit` | `max(debt_floor, debt_seasons × costs)` | `debt_floor` 300, `debt_seasons` 6 |
| `ratio` | `debt × 1000 / limit`, floored | |
| stage | `solvent` (treasury ≥ 0), `debt` (ratio < `wary_at`), `wary` (< `refused_at`), `refused` (≥ `refused_at`); `bankrupt` while a settlement is pending | `wary_at` 500, `refused_at` 850 |
| rate (permille a season) | `rate_debt` in `debt`, `rate_wary` in `wary` and `refused`; plus `default_rate_add` while `turn < default_turn + default_rate_seasons` | 20, 40, 30, 80 |
| interest | in the debt phase, when the treasury is below 0 and no settlement is pending: `ceil(min(debt, limit) × rate / 1000)` | |
| credit line | `limit × credit_permille / 1000`; **0** while a settlement is pending or `turn < fresh_until` | `credit_permille` 850, `fresh_seasons` 8 |
| may pay | `ducats <= 0`, or `treasury − ducats ≥ −credit_line` | |
| bankrupt | in the debt phase, `debt ≥ limit` | `bankrupt_permille` 1000 |

`DebtDef.enabled` (true) switches all of it; `DebtFixture.off` sets it false, which gives M4 D19 exactly: no interest, no
stage but `solvent` or `debt`, credit 0, no bankruptcy (D21).

**The countdown** (the Debt tab and the chip's card, computed by `DebtView`, since the preview is a view): with `net` the
preview's expected net a season (`EconomyPreview.expected`, M4) less the interest of the current stage, `seasons_to_refused = ceil((refused_at × limit / 1000 − debt) / −net)` and
`seasons_to_bankrupt = ceil((limit − debt) / −net)` when `net < 0`; "never at this rate" otherwise.

### 4.2 The debt phase

`Debt.season(game)`, per living country in id order:

1. **A settlement left pending** since an earlier turn is settled as `default` (`debt_settled`, `why: lapsed`). (The player's
   cannot be: End season refuses while it waits; a watched or AI-only game can.)
2. **Interest**: `Treasury.move(game, tag, −interest, &"interest")` when owed (4.1).
3. **Desertion** (D11): when the stage after step 2 is `refused` and the season's running net is below 0 (`net` = the sum of
   `ledger_open`'s lines that are not `SPENDING`, interest included), companies desert in `Debt.troop_order` (the oldest era first,
   then the fewest men, then the farthest from the capital by hex distance, then the lower unit id) until their upkeep (each unit's
   share of M6's `upkeep_of`, `Debt.unit_upkeep`) reaches `−net`, at most `ceil(companies / 2)`: `Armies.lose_men(game, army,
   unit.men, &"deserted")` for each (M6 emits `unit_lost`), then one `troops_deserted` event.
4. **Bankruptcy** (D12): when `debt ≥ limit` and `turn ≥ fresh_until` (no second bankruptcy in the 8 seasons after one; a
   country still over its limit then stays `refused` and its companies desert by step 3): `pending_settle` true,
   `bankrupt_turn` = turn; the `bankrupt` event.
5. **The stage**: written to `debt_stage`; when it differs from the stored one, `debt_stage_changed`.

### 4.3 The settlements

`settle_debt {option, tag}` (`Debt.settle_debt_check` / `settle_debt`), option `&"default"`, `&"pledge"` or `&"army"`.

| Row | Refusal |
|---|---|
| 1 | "%s is no more" (not alive) |
| 2 | "you are not bankrupt" (no settlement pending) |
| 3 | "no such settlement: default, pledge or army" |
| 4 | pledge: "no creditor can take land: %s" ("none is at peace with you" / "none is left") |
| 5 | pledge: "you hold too little land: 4 districts at least" |
| 6 | ok |

| Settlement | What it does (the debt `D` at the moment) | Lasting | Deeds |
|---|---|---|---|
| **Default on the creditors** | `Treasury.move(+D, &"bankruptcy")` (the treasury is 0) | taxes (`tax_people`, `tax_goods`) and the merchants' `trade` line × `Debt.income_factor`: `1000 − default_income_permille × (default_seasons − s) / default_seasons` permille, `s` the seasons since, for `default_seasons` 40 (750 at once, 875 after 20, 1,000 after 40); interest `+default_rate_add` for 80 seasons; each creditor (D14) remembers `&"defaulted"` −50 toward the debtor (`Relations.remember`) | `deeds_default` −20 |
| **Pledge land** | the first creditor of `Debt.creditors_of` takes districts: the debtor's owned and controlled districts but its capital, by hex distance to the creditor's nearest district (ties: lower index), while `Σ WarGoals.worth_of × pledge_ducats_per_worth` (30) is under `D` and the count is under `max(1, districts × pledge_max_permille (250) / 1000)`; `Territory.transfer` (M2, M9's `gained`/`former` set: the land is "lost" for M9's reconquest reason); then `Treasury.move(+D, &"bankruptcy")` | a reconquest reason against the creditor for 80 seasons (M9's rule) | `deeds_pledge` −20 |
| **Pay with the army** | `Treasury.move(+ceil(D / 2), &"bankruptcy")`; `ceil(companies × army_desert_permille (500) / 1000)` companies desert, the dearest upkeep first (ties: `troop_order`); every **castle** (family 2) of level 2 or 3 loses a level (`Improve.lower_fortress`, **new**, `district_declined` with `why: bankrupt`) | castles rebuilt at full cost | `deeds_army` −10 |

Every settlement then (D15): `pending_settle` false; `fresh_until` = turn + `fresh_seasons`; `bankruptcies` + 1; each army's general
dismissed (`Armies.set_general(game, army, &"")`, M11's `general_dismissed` with `why: bankrupt`); every merchant order freed
(`Merchants.free(game, order, &"bankrupt")`); the `debt_settled` event. The settlement may leave a treasury below 0 (pay with the
army): the stage is recomputed at once and interest resumes at the next debt phase.

**Creditors** (D14): `Debt.creditors_of(game, tag) -> Array[StringName]`: `ScenarioDef.creditors` living, not `tag`, not at war
with it, in order; when none, the two living other countries with the largest treasury (ties: id). Italy 1480: GEN, TUS, VEN.

**The AI's choice** (D42): the first option of its temperament's `bankrupt_pick` that `settle_debt_check` allows.

### 4.4 Ways out (the Debt tab)

`DebtView.ways_out(game, tag)` lists, each with its effect a season from `EconomyPreview.with(game, tag, changes)` (M4) and the
action's own verdict:

| Way out | Shown when | Effect shown | Press |
|---|---|---|---|
| "Taxes to High" | tax below High | the preview's net with tax High minus today's | `set_tax {level: 2}` |
| "Disband the N oldest companies" | companies exist | their upkeep (`Debt.unit_upkeep`) | opens the army panel of the first army (`app_requested(&"army", {id})`) |
| "Recall the merchant on {route}" | an order with `losing > 0` (M10) | the order's last net | `recall_merchant {order}` |
| "Cancel the works begun this season" | a work begun this turn | its refund (M4) | `cancel_work {hex}` for each, one confirm |
| "Seek a white peace with {country}" | at war | the war's weariness cost a season (M9) | opens the peace screen (`app_requested(&"peace", {tag})`) |

### 4.5 Countries that fall

`Countries.fall(game, id, by)`, called by the `extinction` phase for each living country owning no district (in id order):

1. `alive` false, `fell_turn` = turn, `capital` = `NO_HEX`.
2. For each live war of the country (id order): `Peace.apply(game, war, other, fallen_tag, Deal.new(), &"fallen", {})`: the war
   ends, nothing moves (it owns nothing), its occupations are released and the other side's armies go home (M9 step 7); no truce,
   no infamy, no tribute; `peace_made` with terms `fallen`.
3. Its armies: `Armies.lose_men(game, army, men, &"fallen")` for every unit until none is left (M6 removes empty armies; M11's
   `general_lost` for a general).
4. Its merchants' orders: `Merchants.free(game, order, &"gone")`; its pacts: `TradePacts.end_of(game, tag, &"fallen")` (**new**:
   sets `ended_turn` on every pact in force with it).
5. Leagues: `Coalitions.drop(game, tag)` (**new**): removed from every league's `members` and `eligible`; a league against it ends
   by M9's own rule in the next relations phase.
6. Offers: M9's `Peace.pending` offers from or to it dropped (`Peace.drop_of(game, tag)`, **new**).
7. Its works on edges (M10 road works) are cancelled by `Works`' own rule in the next works phase (`lost`); nothing else.
8. `country_fell {tag, by, turn, witnesses: every living country}`. `by` is the country that took its last district (the newest
   `owners_changed` of the season that named it among `others`), or `&""`.

Kept: its treasury, stores, research, relation memories (they fade by M9's rule) and statistics rows. It is never an AI seat
again (M8 seats are living countries), never a merchant's partner, never a research partner, never a creditor.

**Ruin**: when `tag` is the player's, `Ending` ends the game in the same `scores` phase (4.7).

### 4.6 Prestige (the score)

`Score.of(game, tag) -> int` (0 for a fallen country), from `ScoreDef` (`data/defs/score.tres`):

| Part | Rule | Data |
|---|---|---|
| land | districts owned × `land_points` | 3 |
| people | the country's people / `people_per_point` | 2,000 |
| wealth | `max(0, the mean over the last net_seasons Stats rows of income_people + income_goods + income_dues + income_trade − upkeep_districts − upkeep_walls − upkeep_army − interest)` (M4.5 D9's income, the sum `StudyRankings.income_of` makes; read from `Stats`, since a system does not call a view) + `min(treasury_cap_points, max(0, treasury) / treasury_per_point)` | 4; 100; 200 |
| learning | `Research.known_points(game, tag)` / `research_per_point` | 40 |
| arms | `Wars.men_under_arms(game, tag)` / `men_per_point` | 1,000 |
| markets | the market towns it controls (`Trade` markets whose town hex it controls) × `market_points` | 5 |
| deeds | `Country.deeds` | |
| infamy | − `Country.infamy` (tenths) / `infamy_per_point` | 10 |

**Deeds** (D29), added in the `scores` phase from `game.chronicle.of_turn(turn)` (M3), each entry once:

| Chronicle entry | Deeds |
|---|---|
| `battle_ended` (M7) with a winner and at least `deeds_battle_men` (500) killed and wounded on the loser | winner +`deeds_battle_won` (2), loser `deeds_battle_lost` (−1) |
| `peace_made` with terms `deal` or `surrender` (M9) | winner +`deeds_peace_won` (10), loser `deeds_peace_lost` (−10) |
| `country_fell` with a `by` | `by` +`deeds_country_taken` (15) |
| `debt_settled` | the debtor: `deeds_default` (−20), `deeds_pledge` (−20) or `deeds_army` (−10) |
| `era_reached` (M11) | +`deeds_era` (5) |
| `incident_resolved` | the choice's `deeds` |

Example (`ScoreFixture.parts`): 12 districts, 120,000 people, income 48 a season for four seasons, treasury 658, known points
1,200, 1,000 men, 1 market, deeds 12, infamy 40 tenths: 36 + 60 + (48 + 3) + 30 + 1 + 5 + 12 − 4 = **191**.

`Score.season(game)` (the `scores` phase): adds the season's deeds, writes `Country.score` for every country (0 for the
fallen), then `Ending.check(game)`. `Score.rank_of(game, tag) -> int` ranks the living by `score`, ties by id.

### 4.7 The end of the game

`ScenarioDef.end_year` (1650). `Ending.last_turn(game) = Calendar.turn_of(Calendar.WINTER, end_year, start_year)` (684 for
1480). `Ending.check(game)`, at the end of the `scores` phase, when `over` is `&""`:

| Reason | When | Note |
|---|---|---|
| `ruin` | the player's country is not alive | first: a fall in the season of the last turn is still ruin |
| `conquest` | a player: the player's is the only living country; AI-only: one living country | |
| `calendar` | `turn ≥ last_turn` | the scores of Winter 1650 are the final ones |

It sets `game.over`, `game.over_turn` (= turn) and emits `game_over {reason, winner (the top score's tag), player}`. The rest of
the season runs (stats, calendar, ready units, vision). `Season.end_check` then refuses "the game is over". `Game.watch()`
(M8) after a ruin sets `ai_only`, `player` `&""` and `over` `&""` (logged): the game goes on to its calendar end.

The final ranking (D31) is `Score.ranking(game)`: the living by score, then the fallen by `fell_turn` descending; at the end the
game-over view shows every country exact, known or not.

### 4.8 Incidents

`IncidentsDef` (`data/defs/incidents.tres`): `chance_permille` 50, `cooldown_seasons` 40, `first_turn` 5, `lapse` "last". Each
incident is an `IncidentDef` (`data/defs/incidents/<key>.tres`) with a weight, a condition, a place rule and two or three
`IncidentChoiceDef`s, each with effects (`IncidentEffectDef`: `kind`, `amount`, `good`, `scope`, `target`), `deeds` and `ai_value`.

**The phase** (`Incidents.season`): first every open incident older than this turn lapses (its last choice, `why: lapsed`); then
for each living country in id order with none open and `turn ≥ first_turn`: roll `luck.world` 0 to 999 < `chance_permille`;
then the allowed incidents (condition true, a place found, not in cooldown) are drawn by weight from `luck.world`; the place is
found by the incident's rule (no luck); `pending_incident` = `{key, hex, turn}`, `incident_turns[key]` = turn; the event
`incident_offered`. An AI country answers in its next `ai_orders`; until then it stays open (it lapses the season after).

**The deck** (D33; `{town}` is the place's name, effects in the place's terms; `ring` = the six neighbours it owns):

| Key | Title | Condition and place | Choices (effects; deeds; `ai_value`) | Weight |
|---|---|---|---|---|
| `plague` | "Plague in {town}" | not winter; the owned settlement of level 3 or more with the most people, at least 10,000 | 1 "Close the gates": ducats −40, people −30 ‰ at the town (`plague`); 2 "Keep the market open": people −80 ‰ at the town and −30 ‰ in its ring (`plague`); 3 "Pray and process": people −60 ‰ at the town (`plague`), opinion +10 from PAP; ai 3, 1, 2 | 10 |
| `famine` | "Hunger in {region}" | the country's `food_fed` under 900 (M5); the hungriest owned settlement | 1 "Buy grain abroad": ducats −60, goods grain +20; 2 "Requisition the countryside": goods grain +10, deeds −3; 3 "Let them fend": nothing; ai 3, 2, 1 | 10 |
| `trade_fair` | "A fair at {market}" | at peace; spring or summer; a market town it controls | 1 "Grant a charter": ducats −40, fair (the market's good with the highest price, ×1,500 ‰, 4 seasons); 2 "Tax the stalls": ducats +30; 3 "Refuse": nothing; ai 3, 2, 1 | 8 |
| `silver` | "Silver near {place}" | an owned district of relief level 3 or more | 1 "Work it for the crown": ducats +120, people −20 ‰ at the hex (`incident`); 2 "Sell the rights": ducats +60, opinion +10 from the first creditor; 3 "Leave the hills be": nothing; ai 2, 3, 1 | 6 |
| `condottiere` | "A condottiere offers his company" | at war; its largest army on its own land | 1 "Hire him": ducats −80, men +400 to that army (`Armies.add_men`, spread over its units, capped at full); 2 "Send him away": nothing; ai 2, 1 | 6 |
| `flood` | "The {river} floods" | spring; an owned farmland district on a river edge | 1 "Rebuild the banks": ducats −50; 2 "Let the waters fall": people −20 ‰ at the hex (`incident`), goods grain −10; ai 2, 1 | 8 |
| `patron` | "A painter seeks a patron" | a city or the capital; treasury ≥ 200 | 1 "Commission an altarpiece": ducats −100, deeds +5; 2 "Send him away": nothing; ai 1, 2 | 6 |
| `scholar` | "A scholar from Constantinople" | an owned settlement of level 3 or more | 1 "Endow a chair": ducats −80, research +4,000 milli (`Research.add_progress`); 2 "There is no room": nothing; ai 3, 1 | 6 |
| `envoy` | "An envoy from {country}" | a living neighbour whose opinion of it is −20 to +20 | 1 "Feast him": ducats −30, opinion +15 both ways; 2 "Keep him waiting": opinion −10 from the neighbour; ai 2, 1 | 8 |
| `bandits` | "Bandits on the road to {town}" | an owned town (level 3 or more) with a road edge | 1 "Send the guard": ducats −30; 2 "Pay them off": ducats −15, deeds −2; 3 "Do nothing": people −10 ‰ at the town (`incident`); ai 3, 2, 1 | 8 |
| `harvest` | "A bountiful harvest" | summer or autumn; the season's weather good (M4) | 1 "Fill the granaries": goods grain +20; 2 "Sell the surplus": ducats +40; ai 2, 1 | 10 |

Rules: a choice whose `ducats` cost is more than the country may pay (`Treasury.can_pay`) is refused with that reason; goods are
taken up to the stock (never below 0); people use `People.move` (M5) and are floored per hex; `opinion` targets are `neighbour`
(the place's country), `creditor` (the first of `Debt.creditors_of`) or a tag; a target that is not alive drops that effect.
The last choice is always allowed (it costs nothing). `answer_incident {choice, tag}`: rows "%s is no more", "no event waits for
an answer", "no such choice: 1 to %d", the choice's own refusal, ok.

**Fairs** (D36): `Trade.add_fair(game, market, good, permille, seasons)` appends `{good, permille, until}` to `Market.fairs`
(`market/2`); `Trade.appetite` multiplies by every fair in force; the trade phase drops ended fairs.

### 4.9 The AI (M8 to M11, edited)

A seat's turn after M12: `brief`, **`debt`**, `peace`, `diplomacy`, `war`, `works_scan` × 2, `works_card` × k, `works_act`,
`trade`, `research`, `forces`, `army` × n, `tax`, `done`. The AI acts only in `ai_orders`, through `AiKnow` and `Game.act`.

**The debt step** (`AiDebt.debt`, **new**, one step a seat):

1. A settlement pending: `settle_debt` with the first allowed option of `bankrupt_pick` (D42).
2. An incident open: `answer_incident` with the allowed choice of the highest `ai_value` whose ducats leave at least the reserve
   `R` (M8), else the last choice.
3. Stage `wary` or worse: recall each merchant order with `losing > 0` (`recall_merchant`); begin no work whose cost would take
   it past half its credit line (`AiEconomy`'s works step reads `AiKnow.debt_of`); row 9a refuses war in `refused` anyway.

M8's rules stay: High taxes when `T < 0`; disband one company when `T < 0` and `N_high < 0`; white peace when `T < 0` (M9). A
fallen country is no seat (M8 seats are living countries). `AiKnow` grows: `debt_of(game, t) -> Dictionary` ({stage, debt,
limit, pending}), `settle_options(game, t) -> Array[StringName]` (allowed, in the temperament's order), `incident_of(game, t) ->
Dictionary`, `incident_choices(game, t) -> Array[Dictionary]` ({n, ducats, ai_value, ok}). The door's text rule (M8 4.3) adds the
tokens `Debt.`, `Incidents.`, `Score.`, `Ending.`.

| `AiTemperDef.bankrupt_pick` | builder | cautious | steadfast | aggressive | opportunist | conqueror |
|---|---|---|---|---|---|---|
| | army, default, pledge | default, army, pledge | pledge, default, army | default, pledge, army | pledge, army, default | default, pledge, army |

### 4.10 The season table after M12

`Season.PHASES` (21; `test_season.gd` pins it): `ai_orders`, `movement`, `battles`, `supply`, `sieges`, `war`, `relations`,
`production`, `trade`, `income`, **`debt`**, `works`, `people`, `research`, **`incidents`**, **`extinction`**, **`scores`**, `stats`,
`calendar`, `ready_units`, `vision`.

| # | Name | Arrives | Reads | Writes (through the owner) |
|---|---|---|---|---|
| 1 to 10 | `ai_orders` ... `income` | M3 to M10 | as M11 | as M11; the AI's `settle_debt` and `answer_incident` through `Game.act` |
| 11 | **`debt`** | **M12** | treasuries, `ledger_open`, `Stats` upkeep rows, armies, units, `DebtDef`, `pending_settle`, `default_turn` | treasury (`interest`, a lapsed default's `bankruptcy`), armies (deserters), the debt fields; events `debt_stage_changed`, `troops_deserted`, `bankrupt`, `debt_settled` |
| 12 to 14 | `works`, `people`, `research` | M3, M5, M11 | as M11 | as M11 |
| 15 | **`incidents`** | **M12** | countries, settlements, people, markets, rivers, relief, weather, wars, opinions, `IncidentsDef`, `luck.world` | `pending_incident`, `incident_turns`, a lapsed incident's effects (each through its owner), `luck`; events `incident_offered`, `incident_resolved` |
| 16 | **`extinction`** | **M12** | owners, countries, wars, armies, orders, pacts, leagues, offers | `alive`, `fell_turn`, `capital` (`Countries`), wars (`Peace.apply`), armies, orders, pacts, leagues, offers; `country_fell` |
| 17 | **`scores`** | **M12** | the turn's chronicle, districts, people, `Stats` income rows, treasuries, `Research.known_points`, men, markets, infamy, `ScoreDef` | `deeds`, `score` (`Score`); `over`, `over_turn` (`Ending`); `game_over` |
| 18 to 21 | `stats` ... `vision` | M3, M6 | as M11; `stats` reads `score`, `deeds`, the interest and deserted lines | `stats` writes `score`, `prestige` (the deeds), `interest`, `deserted` |

Why this order: debt follows the season's income, so a deficit is known; works and people come after, so a settlement's
transfers and lost castles count from this season's works; incidents read this season's people and research; the fall comes
after every phase that moves land this season (war, the pledge); the scores read the falls; the stats read the scores.

### 4.11 Events, witnesses, log lines

| Kind | Fields (besides `kind`, `turn`) | Emitted by | Notable | Typed signal | Heard by |
|---|---|---|---|---|---|
| `debt_stage_changed` | `tag`, `stage`, `from`, `debt`, `limit`, `witnesses` ([tag]) | `Debt.season`, `Debt.settle_debt` | yes | `debt_stage_changed(tag, stage)` | `Chips`, `PageEconomy` (Debt tab), `TaskFlag`; log (Money), notifications (yours, `refused`) |
| `troops_deserted` | `tag`, `men`, `companies`, `armies` (ids), `hexes`, `witnesses` (Vision of the hexes) | `Debt.season`, `Debt.settle_debt` | yes | `troops_deserted(tag, men, companies)` | `ArmyPanel`, `ArmyTokens`, `Chips`; log (War, Money), notifications (yours), ribbons |
| `bankrupt` | `tag`, `debt`, `limit`, `options` (allowed), `witnesses` (every living country) | `Debt.season` | yes | `bankrupt(tag, debt)` | the App (a decision for the player), `Chips`, `TaskFlag`; log, notifications |
| `debt_settled` | `tag`, `option`, `why` (`pick`, `lapsed`), `wiped`, `districts` (pledge), `creditor`, `men`, `castles`, `witnesses` (every living country) | `Debt.settle_debt` | yes | `debt_settled(tag, option)` | `EventPopup`, `Chips`, `PageEconomy`, `MapScene` (owners already by `owners_changed`); log, notifications |
| `country_fell` | `tag`, `by`, `witnesses` (every living country) | `Countries.fall` | yes | `country_fell(tag)` | `DecisionQueue` (drops its decisions), `CountryPanel`, `MapScene` (labels), `PageDiplomacy`, `PageRankings`; log, notifications |
| `game_over` | `reason`, `winner`, `player` (no `witnesses`: public) | `Ending.check` | yes | `game_over(reason)` | the App (the game-over screen after the report), `SeasonFlow`, `BusyPill` |
| `incident_offered` | `tag`, `incident`, `hex`, `witnesses` ([tag]) | `Incidents.season` | yes | `incident_offered(tag, incident)` | the App (a decision for the player), `TaskFlag`; log (yours) |
| `incident_resolved` | `tag`, `incident`, `choice`, `why` (`pick`, `lapsed`), `hex`, `deeds`, `lines` (the effects done, as data), `witnesses` ([tag]) | `Incidents.answer_incident`, `Incidents.season` | yes | `incident_resolved(tag, incident, choice)` | `EventPopup`, `Chips`; log (yours), ribbons |

`Chronicle.NOTABLE` gains the eight (**56**). `Vision.SIGHTED` gains `troops_deserted`. `SeasonSummary.COVERED` gains all eight
but `game_over`.

**Log lines** (`LogLines.line_of`; All and Mine for the player's unless said):

| Kind | The player's line | A witnessed other's |
|---|---|---|
| `debt_stage_changed` | `debt`: "You are in debt: 120 ducats at 2 % a season." warn; `wary`: "Your creditors grow wary: interest rises to 4 %." warn; `refused`: "Credit refused: no spending until the debt falls below 306 ducats." bad, `notify`; `solvent`: "Your debts are paid." good. Money | |
| `troops_deserted` | "Unpaid, 3 companies desert (1,250 men)." bad, War and Money; `notify`; ribbon "Deserted" | "The Duchy of Milan's unpaid troops desert." muted |
| `bankrupt` | "Bankruptcy! Your debt of 400 ducats has reached its limit. Settle with your creditors." bad; `notify` | "The Duchy of Milan is bankrupt." plain |
| `debt_settled` | default: "You defaulted: the debt of 400 is wiped; taxes and trade −25 % for 10 years." / pledge: "You pledged 2 districts to the Republic of Genoa: the debt is wiped." / army: "You paid with the army: the debt is halved; 3 companies leave and 2 castles fall a level." / lapsed: "Your creditors waited no longer: you defaulted." bad | "The Duchy of Milan defaulted on its creditors." muted |
| `country_fell` | yours: "Your country is no more." bad; one you took: "The Republic of Lucca is no more: its last land is yours." good | "The Republic of Lucca is no more." plain; `notify` for a neighbour |
| `game_over` | "The year 1651 has come: the game is over." / "Italy is yours." / "Your country is no more: the game is over." | |
| `incident_offered` | "An event in Savona: plague. Choose (the event waits)." warn | |
| `incident_resolved` | "Plague in Savona: you closed the gates (−40 ducats, 900 people lost)." plain; lapsed: "... you did nothing in time." | |

### 4.12 The season report, reminders, Stats, the study

**`SeasonSummary`** (no new section; D77):

| Id | M12 content |
|---|---|
| `glance` | chips: "In debt" (warn) on entering `debt`; "Credit refused" (bad); "Bankrupt" (bad); "A country fell" (plain); "Prestige +12" (good or bad when the season's change is 10 or more) |
| `before` | notices: "Settle with your creditors: the game waits." (rank 1,000); "An event waits: Plague in Savona." (rank 600); "Bankrupt in 6 seasons at this rate." (rank 500, when `seasons_to_bankrupt ≤ 8`) |
| `treasury` | lines `interest` ("Interest on 240 owed ▼ −5"), `bankruptcy` ("Debt wiped ▲ +400" / "halved"), `incident` ("Event: the fair at Genoa ▼ −40") |
| `armies` | "3 companies deserted, unpaid." |
| `orders` | "Settled with your creditors: default.", "Answered: Plague in Savona, close the gates." |
| `befell` | falls ("The Republic of Lucca is no more.", rank 900), bankruptcies of known countries (rank 300), incidents of yours lapsed |
| `standing` | "Prestige 412 ▲ +3, 3rd of the 6 you know." (the line M4.5's Standing adds; Rankings shows the same rank) |

The report's seal is `cracked` (D77) when your country settled a bankruptcy this season or lost its capital; `good` and `plain` as
M3.

**`Reminders.RULES`** gains `settle_debt` (first), `incident_open` after `idea_pending`, `debt_wary` after `treasury_empty`, and
rewrites `treasury_empty`'s words:

| Rule | When | Severity | Text | Action |
|---|---|---|---|---|
| `settle_debt` | a settlement of yours is pending | 2 | "Bankrupt: choose how to settle with your creditors." | `[&"bankruptcy"]`, "Settle" |
| `incident_open` | an incident of yours is open | 1 | "An event waits: Plague in Savona." | `[&"incident"]`, "Answer" |
| `treasury_empty` (M4, rewritten) | treasury below 0 | 1 (`debt`), 2 (`refused`) | "In debt: 240 ducats at 2 %. Credit stops at 306." / "Credit refused: nothing that costs ducats can begin." | `[&"study", &"economy", &"debt"]`, "Open the Debt tab" |
| `debt_wary` | stage `wary` and `seasons_to_bankrupt ≤ 12` | 1 | "Bankrupt in 9 seasons at this rate." | `[&"study", &"economy", &"debt"]` |

**`Stats.SERIES`** appends `interest` and `deserted` (**62**); M12 writes M3's `score` (the total) and `prestige` (the deeds).
`StudyRankings.income_of` subtracts `interest` (1.2).

**The study.** `PageEconomy.TABS` `debt` gains its scene (6.4). `StudyRankings.MEASURES` appends `{id = &"score", title =
"Prestige", since = "12"}` (values from `Country.score`; banded for others as M4.5). `StudyHistory.MARK_KINDS` gains `fell`
(bad, icon `fell`) after `war` and `bankrupt` (bad, icon `bankrupt`) after `era`. `StudyDiplomacy.of` (M9) lists living
countries only: a fallen country leaves the relation matrix and the wars table keeps its ended wars ("no more" in the name).

### 4.13 Saves and the digest

| Body key | M12 adds | In `Game.digest()` |
|---|---|---|
| `format` | 10 (`SaveFile.FORMAT`; `OLDEST_FORMAT` 10, frozen) | no |
| `game` | `over` (String), `over_turn`, `dev_used` | yes (`over`, `over_turn`; `dev_used` no) |
| `countries` | `country/8`: `debt_stage`, `pending_settle`, `bankrupt_turn`, `bankruptcies`, `default_turn`, `fresh_until`, `fell_turn`, `deeds`, `score`, `pending_incident` ({key, hex, turn} or {}), `incident_turns` ({key: turn}); `country/7` refused | each `digest_text()` |
| `trade` | `market/2` with `fairs`; `market/1` refused | as M10 |
| `stats` | `stats/2` with `interest`, `deserted` appended (by name) | `Stats.digest()` |
| `luck` | the world stream after the incidents' draws | as M3 |
| `action_log` | `settle_debt`, `answer_incident`; the dev records `dev_incident`, `dev_year` | no |

Sizes: about 20 ints a country; `save_mb` stays 8 on the made-up Europe and a north Italy save at 1650 is under 2 MB (the suite
measures it).

**The migration table** (D45 to D47; `SaveFile.read_header` states):

| Format | Made by | 0.3.0 does |
|---|---|---|
| 1 to 9 | the M3 to M11 test builds | lists it greyed: "Made by an older test build" (`older`) |
| 10 | 0.3.0 | loads |
| 11 and later | a later build | greyed: "Made by a newer Hexa" (`newer`) |

From 0.3.0: `OLDEST_FORMAT` stays 10; a bump to `n + 1` adds `_upgrade_<n>(body) -> Dictionary` and keeps every earlier
release's saves loading; `ScenarioDef.known_digests` lists the scenario digests of earlier releases (a save naming one loads);
a save upgraded on load is not checked against its header digest ("damaged"), and its next save writes a new header.

### 4.14 Worked examples

**(a) `DebtFixture.lone`** (tests only; `tests/core/debt_fixture.gd`): `ScenarioFixture`'s 9 x 7 map with three countries; debt
on; country A (id 1) with four `Stats` rows of `upkeep_districts` 20, `upkeep_walls` 10, `upkeep_army` 30 (costs 60); one army
of 6 companies; one castle of level 3; creditors B, C.

| Case | Result |
|---|---|
| limit | max(300, 6 × 60) = **360**; credit line 306; `wary` from 180 |
| treasury −100 | stage `debt`; interest ceil(100 × 20 / 1000) = **2** |
| treasury −200 | stage `wary`; interest ceil(200 × 40 / 1000) = **8** |
| treasury −300, a work of 10 | refused: −310 < −306 |
| treasury −320, a season's net −50 | stage `refused`; companies desert in troop order until 50 ducats of upkeep are saved |
| treasury −360 at the debt phase | bankrupt; `pending_settle`; credit 0 |
| default (debt 400) | `bankruptcy` +400, treasury 0; taxes × 750 permille at once, 875 after 20 seasons; B and C remember −50 |
| pledge (debt 400, 10 districts) | at most max(1, 10 × 250 / 1000) = **2** districts to B (nearest first); the debt wiped |
| army (debt 400, 6 companies) | `bankruptcy` +200, treasury −200; **3** companies desert; the castle falls to level 2 |

**(b) `FallFixture.duel`**: A and B at war on the fixture map; B holds one district; A makes peace taking it (`keep_last_district`
false): in that season's `extinction` phase B falls (`fell_turn`); the war's record shows terms `deal` (the peace's), B's other
war with C ends with terms `fallen`; B's army and its merchant order are gone; `country_fell {tag: B, by: A}`; A's deeds +10
(peace) +15 (country taken) in the `scores` phase.

**(c) `ScoreFixture.parts`**: 4.6's example, **191**.

**(d) `EndFixture.short`**: the fixture with `end_year` = `start_year` (1480): turn 4 (Winter 1480) is the last; after its
`scores` phase `over` is `calendar`; End season refuses "the game is over"; `EndFixture.italy_short` does the same on north Italy
with `end_year` 1481 (8 seasons).

**(e) `IncidentFixture.always`**: `chance_permille` 1,000, one incident at a time from a list; seed 1480 gives the pinned key,
place and turn; answering choice 1 of `plague` at a town of 20,000 removes 600 people and 40 ducats; leaving it open lapses to
choice 3 at the next incidents phase.

### 4.15 The soak: the whole game and the balance gate

`godot/tools/soak.gd` (M8 to M11) gains the suite, four invariants and the ranges below.

| Suite | Games | Seasons | What | Quick |
|---|---|---|---|---|
| **`whole`** (new) | seeds 1 to 100 | 684 (to the calendar's end) | north Italy, Italy 1480, AI-only (`Game.watch`), debt, incidents and falls on; every save at turns 160, 400 and 684 written, loaded and played 4 seasons, its digest equal to the unsaved game's | seed 1 × 24 |

In the `whole` suite M9's `runaway` invariant is counted and reported, not failing (its games run eight times the 80 seasons it was
set for), as M11 did for `research`.

| Invariant | Holds after every season |
|---|---|
| `debt` | every living country: `debt_stage` equals `Debt.stage_of`; a pending settlement only with `debt ≥ limit` at its turn and never older than one season; credit 0 while pending or fresh; after a debt phase, a country with `debt ≥ limit` is pending or within its fresh seasons; no interest line while pending |
| `fallen` | a country is alive exactly when it owns a district (checked after `extinction`); a fallen country has no army, order, live war, pact in force, league seat, pending offer, open incident or pending settlement; its `score` is 0 |
| `score` | every living country's `score` equals `Score.of` at the `scores` phase; `deeds` change only in that phase |
| `ending` | `over` is `&""` until `last_turn`, an empty-land player or one country left; once set it never changes but by `Game.watch` after a ruin |
| M8 to M11's | as theirs; M9's `peaces` reads 1.2's edit |

**The balance gate** (D70; `whole` suite, 100 games, the final data):

| Measure | Range |
|---|---|
| games over by the calendar | ≥ 95 |
| countries fallen a game | median 0 to 4; every game ≤ 9 |
| bankruptcies a game (all countries) | median 0 to 3; no country more than 3 in a game |
| country-seasons in debt (treasury < 0) | ≤ 15 % |
| country-seasons in `refused` | ≤ 3 % |
| companies deserted a game | median ≤ 20 |
| the largest land share at 1650 | median ≤ 35 %; every game ≤ 60 % |
| incidents a living country in 100 seasons | median 3 to 8 |
| incidents lapsed (AI) | 0 (the AI always answers) |
| the top prestige at 1650 over the median living prestige | ≤ 4 |
| techs known a country at 1650 (median) | 22 to 30 (M11's) |
| people at 1650 over people at 1480 | 90 % to 250 % |
| wars a country in 100 seasons (median) | 1 to 8 |
| AI season on north Italy, worst | ≤ 400 ms (M8) |
| core memory (`OS.get_static_memory_usage`) at turn 684 over turn 100 | ≤ 1.10 |
| save at 1650 | ≤ 2 MB |

The summary's per-country table gains: bankruptcies, seasons in debt, deserted men, fell turn, final prestige and rank, incidents
offered and lapsed. **CI**: the nightly `soak` matrix gains `whole` seeds 1-5 and 6-10 (each about 15 minutes); the release
workflow runs all 100 in a matrix of 10 legs (seeds 1-10 ... 91-100), judged together by `soak-ranges`.

---

## 5. Interfaces

Layers after M8: `defs`, `state`, `systems`, `game`, `views`, `ai`, `shell`. `core/` makes no engine calls; M12's luck is the
incidents' roll and draw (`luck.world`), through `Rng`. New files are marked **new**; "(M2)" to "(M11)" name pieces those
milestones build. Every amount is an `int`, every rate a permille. Systems never call `Words`.

### 5.1 Definitions (`core/defs/`)

```gdscript
# core/defs/debt_def.gd  (new): every number of 4.1 to 4.3, one inspector
class_name DebtDef extends Resource
const OPTIONS: Array[StringName] = [&"default", &"pledge", &"army"]   # the settlements (4.3)
@export var enabled := true
@export var debt_floor := 300
@export var debt_seasons := 6
@export var cost_seasons := 4
@export var wary_at := 500                    # permille of the limit
@export var refused_at := 850
@export var bankrupt_permille := 1000
@export var rate_debt := 20                   # permille a season
@export var rate_wary := 40
@export var default_rate_add := 30
@export var default_rate_seasons := 80
@export var credit_permille := 850
@export var fresh_seasons := 8
@export var desert_max_permille := 500        # of companies a season, rounded up
@export var default_income_permille := 250
@export var default_seasons := 40
@export var defaulted_opinion := -50
@export var pledge_ducats_per_worth := 30
@export var pledge_max_permille := 250
@export var pledge_min_districts := 4
@export var army_desert_permille := 500
func validate() -> Array[String]   # floors >= 0; 0 < wary_at < refused_at < bankrupt_permille = 1000; rates 0..1000;
	# credit_permille <= refused_at; seasons >= 1; permilles 0..1000; defaulted_opinion -100..0

# core/defs/score_def.gd  (new): 4.6
class_name ScoreDef extends Resource
@export var land_points := 3
@export var people_per_point := 2000
@export var net_seasons := 4
@export var treasury_per_point := 200
@export var treasury_cap_points := 100
@export var research_per_point := 40
@export var men_per_point := 1000
@export var market_points := 5
@export var infamy_per_point := 10
@export var deeds_battle_men := 500
@export var deeds_battle_won := 2
@export var deeds_battle_lost := -1
@export var deeds_peace_won := 10
@export var deeds_peace_lost := -10
@export var deeds_country_taken := 15
@export var deeds_default := -20
@export var deeds_pledge := -20
@export var deeds_army := -10
@export var deeds_era := 5
func validate() -> Array[String]   # divisors >= 1; points >= 0; the losses <= 0, the gains >= 0

# core/defs/incident_effect_def.gd  (new)
class_name IncidentEffectDef extends Resource
const KINDS: Array[StringName] = [&"ducats", &"goods", &"people", &"opinion", &"fair", &"research", &"men", &"deeds"]
@export var kind: StringName                   # one of KINDS
@export var amount := 0                        # ducats, loads, permille of people, opinion, milli-points, men
@export var good: StringName = &""             # goods: a GoodDef key
@export var scope: StringName = &"place"       # people: place, ring
@export var target: StringName = &""           # opinion: neighbour, creditor, or a CountryDef tag; "both" for two-way
@export var permille := 1000                   # fair: the appetite factor
@export var seasons := 0                       # fair: how long
func validate(defs: GameDefs) -> Array[String]

# core/defs/incident_choice_def.gd  (new)
class_name IncidentChoiceDef extends Resource
@export var title: String
@export var effects: Array[IncidentEffectDef] = []
@export var deeds := 0
@export var ai_value := 0
func ducats_cost() -> int                      # the sum of negative ducats effects, as a positive number

# core/defs/incident_def.gd  (new)
class_name IncidentDef extends Resource
@export var key: StringName
@export var title: String                      # "Plague in {place}"
@export var text: String                       # the letter, with {place}, {country}, {river}
@export var quote: String
@export var tags: String                       # the sub line's last word: "disease", "trade", "discovery"
@export var weight := 1
const RULES: Array[StringName] = [&"largest_town", &"hungriest", &"market_town", &"high_ground", &"army_home",
	&"river_farm", &"city_or_capital", &"town", &"neighbour", &"road_town", &"capital"]
@export var rule: StringName                   # one of RULES: how the place is found
@export var seasons: PackedByteArray = PackedByteArray()   # allowed seasons 0..3; empty: every season
@export var war := 0                           # -1 at peace only, 0 any, 1 at war only
@export var min_people := 0
@export var min_level := 0
@export var min_treasury := 0
@export var fed_below := 0                     # permille; 0: no condition
@export var weather_good := false
@export var choices: Array[IncidentChoiceDef] = []   # 2 or 3; the last costs nothing
func validate(defs: GameDefs) -> Array[String] # 2..3 choices; the last has no cost; rule known; seasons 0..3

# core/defs/incidents_def.gd  (new)
class_name IncidentsDef extends Resource
@export var enabled := true
@export var chance_permille := 50
@export var cooldown_seasons := 40
@export var first_turn := 5
func validate() -> Array[String]

# core/defs/game_defs.gd  (M2 to M11, edit)
@export var debt: DebtDef
@export var score: ScoreDef
@export var incidents: IncidentsDef
@export var incident_list: Array[IncidentDef] = []
func incident(key: StringName) -> IncidentDef  # null when unknown
# validate() adds: debt, score, incidents set and valid; incident keys unique; each incident valid

# core/defs/scenario_def.gd  (M2, edit)
@export var end_year := 1650
@export var creditors: Array[StringName] = []
@export var known_digests: PackedStringArray = PackedStringArray()   # digests of this scenario in earlier releases
# validate(): end_year > year; creditors are CountryDef tags of the scenario

# core/defs/diplomacy_def.gd  (M9, edit): TERMS appends &"fallen"; truce_of(&"fallen") returns 0
# core/defs/ai_temper_def.gd  (M8 to M11, edit)
@export var bankrupt_pick: Array[StringName] = [&"default", &"army", &"pledge"]
# validate(): bankrupt_pick is a permutation of DebtDef.OPTIONS
```

### 5.2 State (`core/state/`)

```gdscript
# core/state/country.gd  (M2 to M11, edit): schema "hexa-godot/country/8" (country/7 refused)
var debt_stage: StringName = &"solvent"   # Debt
var pending_settle := false               # Debt
var bankrupt_turn := 0                    # Debt: 0 never
var bankruptcies := 0                     # Debt
var default_turn := 0                     # Debt: the last default, 0 none
var fresh_until := 0                      # Debt: no credit while turn < fresh_until
var fell_turn := 0                        # Countries: 0 alive
var deeds := 0                            # Score
var score := 0                            # Score
var pending_incident: Dictionary = {}     # Incidents: {key: String, hex: Vector2i, turn: int} or {}
var incident_turns: Dictionary = {}       # Incidents: key (String) -> the turn last offered
# digest_text() appends "|" + debt_stage + "|" + pending_settle + "|" + bankrupt_turn + "|" + bankruptcies + "|" + default_turn
# + "|" + fresh_until + "|" + fell_turn + "|" + deeds + "|" + score + "|" + the open incident's key, hex and turn + "|" + the
# incident turns sorted by key

# core/state/market.gd  (M10, edit): schema "hexa-godot/market/2" (market/1 refused)
var fairs: Array[Dictionary] = []         # Trade: {good: int, permille: int, until: int}, in the order added
# digest_text() appends each fair as "good:permille:until"

# core/state/war.gd  (M7, M9, edit): terms may be &"fallen" (restore accepts it); no schema change
# core/state/stats.gd  (M3 to M11, edit): SERIES appends "interest", "deserted" (62)

# core/game/game.gd  (M1 to M11, edit; the fields)
var over: StringName = &""                # Ending: &"", &"calendar", &"conquest", &"ruin"
var over_turn := 0                        # Ending
var dev_used := false                     # Game: set by any dev record; saved, not in the digest
```

### 5.3 Systems (`core/systems/`)

```gdscript
# core/systems/debt.gd  (new)
class_name Debt extends RefCounted
const OWNS: Array[String] = ["debt_stage", "pending_settle", "bankrupt_turn", "bankruptcies", "default_turn", "fresh_until"]
const STAGES: Array[StringName] = [&"solvent", &"debt", &"wary", &"refused"]
const OPTIONS: Array[StringName] = DebtDef.OPTIONS
static func debt_of(game: Game, tag: StringName) -> int
static func costs(game: Game, tag: StringName) -> int                 # 4.1
static func limit(game: Game, tag: StringName) -> int
static func ratio(game: Game, tag: StringName) -> int                 # permille
static func stage_of(game: Game, tag: StringName) -> StringName       # live; "bankrupt" is pending_settle, not a stage
static func rate(game: Game, tag: StringName) -> int                  # permille a season
static func interest(game: Game, tag: StringName) -> int              # what the next debt phase charges
static func credit_line(game: Game, tag: StringName) -> int
static func may_pay(game: Game, tag: StringName, ducats: int) -> bool
static func income_factor(game: Game, tag: StringName) -> int         # permille, 1000 without a default in force
static func troop_order(game: Game, tag: StringName) -> Array[Dictionary]   # [{army: int, unit: int, upkeep: int}]
static func unit_upkeep(game: Game, army: Army, unit: Unit) -> int    # its share of Military.upkeep_of (M6)
static func creditors_of(game: Game, tag: StringName) -> Array[StringName]
static func pledge_plan(game: Game, tag: StringName) -> Dictionary    # {creditor, hexes: Array[Vector2i], worth, ok, reason}
static func settle_debt_check(game: Game, args: Dictionary) -> Dictionary   # {option, tag}; 4.3
static func settle_debt(game: Game, args: Dictionary) -> Dictionary
static func season(game: Game) -> void                                # the debt phase (4.2)

# core/systems/treasury.gd  (M4 to M11, edit)
static func can_pay(game: Game, tag: StringName, ducats: int) -> bool # Debt.may_pay (1.2); with debt off: treasury >= ducats
# WHY appends &"interest", &"incident", &"bankruptcy" (23); left_over counts interest, not incident or bankruptcy

# core/systems/stores.gd  (edit): FLOWS appends &"incident" (11)
# core/systems/people.gd  (M5, edit): FLOWS appends &"plague", &"incident"
# core/systems/merchants.gd  (M10, edit): WHY appends &"bankrupt"
# core/systems/economy_season.gd  (M4, edit): debt_limit(game, tag) returns Debt.limit; money_lines multiplies tax_people and
#   tax_goods by Debt.income_factor / 1000 (rounded down)
# core/systems/trade.gd  (M10, edit): step 10's merchants' line times Debt.income_factor / 1000 when positive; and
static func add_fair(game: Game, market: int, good: int, permille: int, seasons: int) -> void   # the fairs' only writer
#   appetite(game, market, good) multiplies by each fair in force; the trade phase drops fairs with until <= turn
# core/systems/research.gd  (M11, edit)
static func add_progress(game: Game, tag: StringName, milli: int, why: StringName) -> void      # to progress; why "incident"
#   fund_research_check: the row "your treasury is in debt" (treasury < 0) after its last refusal row
# core/systems/wars.gd  (M7, M9, edit): declare_war_check row 9a (1.2)
# core/systems/improve.gd  (M1, M5, edit)
static func lower_fortress(game: Game, hex: Vector2i, why: StringName) -> bool   # a castle (family 2) of level 2 or 3 falls a
#   level; WorldImprove.lower_castle(hex) (new) does it; hex_changed and district_declined {why}
# core/systems/peace.gd  (M9, edit): TERMS appends &"fallen"; apply() with terms fallen: no deal, no infamy, no truce, no
#   memories; and
static func drop_of(game: Game, tag: StringName) -> void              # every pending offer from or to tag
# core/systems/coalitions.gd  (M9, edit)
static func drop(game: Game, tag: StringName) -> void                 # out of every league's members and eligible
# core/systems/trade_pacts.gd  (M10, edit)
static func end_of(game: Game, tag: StringName, why: StringName) -> void   # ended_turn on every pact in force with tag

# core/systems/countries.gd  (M2, M9, edit): OWNS gains "alive", "fell_turn"
static func fall(game: Game, id: int, by: StringName) -> void        # 4.5
static func season(game: Game) -> void                               # the extinction phase: fall() for each living country
	# owning no district, id order

# core/systems/score.gd  (new)
class_name Score extends RefCounted
const OWNS: Array[String] = ["deeds", "score"]
static func of(game: Game, tag: StringName) -> int
static func parts(game: Game, tag: StringName) -> Dictionary          # {land, people, wealth, learning, arms, markets, deeds,
	# infamy, total}
static func deeds_of_turn(game: Game, turn: int) -> Dictionary        # {tag: amount} from chronicle.of_turn(turn) (4.6)
static func ranking(game: Game) -> Array[StringName]                  # 4.7
static func rank_of(game: Game, tag: StringName) -> int               # 1-based among the living; 0 when fallen
static func season(game: Game) -> void                                # the scores phase; then Ending.check

# core/systems/ending.gd  (new)
class_name Ending extends RefCounted
const OWNS: Array[String] = ["over", "over_turn"]
const REASONS: Array[StringName] = [&"calendar", &"conquest", &"ruin"]
static func last_turn(game: Game) -> int
static func seasons_left(game: Game) -> int
static func is_over(game: Game) -> bool
static func check(game: Game) -> void                                 # 4.7; emits game_over

# core/systems/incidents.gd  (new)
class_name Incidents extends RefCounted
const OWNS: Array[String] = ["pending_incident", "incident_turns"]
const KINDS: Array[StringName] = IncidentEffectDef.KINDS
const RULES: Array[StringName] = IncidentDef.RULES
static func allowed(game: Game, tag: StringName) -> Array[IncidentDef]     # conditions, a place, no cooldown
static func place_of(game: Game, tag: StringName, incident: IncidentDef) -> Vector2i   # NO_HEX when none
static func choice_check(game: Game, tag: StringName, n: int) -> Dictionary  # the choice's own refusal (its ducats)
static func answer_incident_check(game: Game, args: Dictionary) -> Dictionary     # {choice, tag}; 4.8
static func answer_incident(game: Game, args: Dictionary) -> Dictionary
static func season(game: Game) -> void                                # lapses, then the roll and the draw (4.8)
```

**OWNS after M12** (`tests/core/test_owns.gd` diffs `Snapshot.of` around every action and phase):

| Field | Written by | In an action | In a phase |
|---|---|---|---|
| the six debt fields of `Country` | `Debt` | `settle_debt` | `debt` |
| `alive`, `fell_turn`, `capital` | `Countries` | no (M9's `move_capital` in a peace) | `extinction` |
| `deeds`, `score` | `Score` | no | `scores` |
| `over`, `over_turn` | `Ending` | `watch` (M8, a ruin reset) | `scores` |
| `pending_incident`, `incident_turns` | `Incidents` | `answer_incident` | `incidents` |
| `fairs` (of `markets`) | `Trade` | `answer_incident` | `trade` (drops), `incidents` (a lapse) |
| `treasury`, ledgers | `Treasury` | M11's; `settle_debt`, `answer_incident` | M11's; `debt`, `incidents` |
| `stock`, flows | `Stores` | `answer_incident` | `incidents` |
| `people`, people flows | `People` | `answer_incident` | `incidents` |
| `armies` | `Armies` | `settle_debt`, `answer_incident` | `debt`, `extinction` |
| `main_use`, `level` | `Improve` | `settle_debt` (castles) | M5's |
| owners, `gained`, `former` | `Territory` | `settle_debt` (pledge) | M9's |
| `memories` | `Relations` | `settle_debt` (default), `answer_incident` | `incidents` |
| `progress` | `Research` | `answer_incident` | `incidents` |
| `merchant_orders` | `Merchants` | `settle_debt` | `extinction` |
| pacts | `TradePacts` | no | `extinction` |
| wars | `Wars` / `Peace` | no | `extinction` |
| leagues, offers | `Coalitions`, `Peace` | no | `extinction` |
| `dev_used` | `Game` | the dev records | no |
| everything of M11's table | as M11 5.3 | | |

### 5.4 Game, the action table, the season, saves (`core/game/`)

```gdscript
# core/game/game.gd  (M1 to M11, edit)
func dev_incident(tag: StringName, key: StringName) -> bool   # logged {turn, action: "dev_incident", args}; offers it now
	# (Incidents' writer, place by its rule); false for an unknown tag or key, no place, or one open
func dev_year(year: int) -> bool        # logged; Calendar's writer sets turn to Spring of year (start_year <= year <= end_year)
func watch() -> bool                    # (M8) also when the player's country has fallen: ai_only, player &"", over &"" (4.7)
# every dev_* record sets dev_used; new_scenario: Debt, Score and Incidents need no setup (their fields default)
# digest(): M11's string; the countries' digest_text carry the M12 fields; then "|" + over + "|" + over_turn

# core/game/actions.gd  (M3 to M11, edit)
const NAMES: Array[String] = [... M11's thirty-eight ..., "settle_debt", "answer_incident"]
# pair_of: settle_debt -> Debt's; answer_incident -> Incidents'

# core/game/season.gd  (M3 to M11, edit)
const PHASES: Array[StringName] = [&"ai_orders", &"movement", &"battles", &"supply", &"sieges", &"war", &"relations",
	&"production", &"trade", &"income", &"debt", &"works", &"people", &"research", &"incidents", &"extinction", &"scores",
	&"stats", &"calendar", &"ready_units", &"vision"]
# run_phase: debt -> Debt.season; incidents -> Incidents.season; extinction -> Countries.season; scores -> Score.season
# end_check(game) rows: (1) "choose your country first" (M3, M8's ai_only); (2) "the game is over" (Ending.is_over);
#   (3) "settle with your creditors first" (the player's pending_settle); ok

# core/game/replay.gd  (edit): plays dev_incident, dev_year through Game
# core/game/snapshot.gd  (edit): country/8, market/2; over, over_turn, dev_used; restore type-checks every new field (stages
#   and options known, keys known incidents, hexes on the map) and refuses the older schemas
# core/game/save_file.gd  (edit)
const FORMAT := 10
const OLDEST_FORMAT := 10               # frozen from 0.3.0 (D45)
static func upgrade(body: Dictionary) -> Dictionary    # runs _upgrade_<n> for n from body.format to FORMAT - 1; none yet
# read_header(): a scenario digest in ScenarioDef.known_digests counts as current (D47); read(): the header digest is not
#   compared when the body was upgraded
```

### 5.5 Events and Session (`shell/autoload/`)

```gdscript
# shell/autoload/events.gd  (edit): added signals
signal debt_stage_changed(tag: StringName, stage: StringName)
signal troops_deserted(tag: StringName, men: int, companies: int)
signal bankrupt(tag: StringName, debt: int)
signal debt_settled(tag: StringName, option: StringName)
signal country_fell(tag: StringName)
signal game_over(reason: StringName)
signal incident_offered(tag: StringName, incident: StringName)
signal incident_resolved(tag: StringName, incident: StringName, choice: int)

# shell/autoload/session.gd  (edit): drain() sends the eight kinds to their signals, then chronicled (M3) for the notable;
#   last_phase_ms gains debt, incidents, extinction, scores; dev_incident(tag, key), dev_year(year) -> bool (the console);
#   watch() -> bool (Game.watch, drained)
```

### 5.6 Views (`core/views/`, pure)

```gdscript
# core/views/debt_view.gd  (new): the Debt tab, the debt chip, the bankruptcy pop-up
class_name DebtView extends RefCounted
static func of(game: Game, tag: StringName) -> Dictionary     # {debt, limit, ratio, stage, stage_text, gauge: {wary_at,
	# refused_at, you}, rate_text, countdown: {text, to_refused, to_bankrupt}, season: {income, spending, interest, net},
	# penalties: [{text, until_text}], history: PackedInt32Array (the debt of the last 8 seasons), bankruptcies: [{turn_text,
	# option_text}]}
static func ways_out(game: Game, tag: StringName) -> Array[Dictionary]   # [{id, text, gain, gain_text, action: Array, verdict}]
static func chip(game: Game, tag: StringName) -> Dictionary  # {debt_mode, value, change, icon, stage, card}
static func bankruptcy(game: Game, tag: StringName) -> Dictionary   # the pop-up: {title, sub, lede, quote, strip: [{icon,
	# value, label}], options: [{id, n, title, lines: [{tone, text}], foot, verdict, risky}], note, hex}

# core/views/incident_view.gd  (new)
class_name IncidentView extends RefCounted
static func of(game: Game, tag: StringName) -> Dictionary     # {key, title, sub, text, quote, hex, choices: [{n, title,
	# lines: [{tone, text}], verdict}]}; {} when none is open

# core/views/score_view.gd  (new)
class_name ScoreView extends RefCounted
static func parts(game: Game, viewer: StringName, tag: StringName) -> Dictionary   # {rows: [{part, text, value}], total,
	# change, rank_text}; exact for the viewer, banded for a known other, {} for an unknown one (exact for all once over)
static func chip(game: Game, viewer: StringName) -> Dictionary     # {value, change, card}

# core/views/end_view.gd  (new): the game-over screen's model
class_name EndView extends RefCounted
static func of(game: Game, viewer: StringName) -> Dictionary  # {reason, title, lede, seal, place_text, parts, series:
	# {score: PackedInt32Array, labels}, ranking: [{rank, tag, name, score, fell_text, mine}], highlights: [{turn_text, text}],
	# buttons: [&"map", &"watch", &"credits", &"menu"], dev_used}

# core/views/study_debt.gd  (new): the Debt tab's data (DebtView.of plus the span's chart)
class_name StudyDebt extends RefCounted
static func of(game: Game, viewer: StringName, span: int) -> Dictionary

# core/views/words.gd  (M3 to M11, edit)
static func debt_stage_name(stage: StringName) -> String     # "Solvent", "In debt", "Creditors wary", "Credit refused"
static func settlement_name(option: StringName) -> String    # "Default on the creditors", "Pledge land", "Pay with the army"
static func prestige_text(score: int, change: int, rank: int, total: int) -> String   # "Prestige 412 ▲ +3, 3rd of 6"
static func end_title(reason: StringName, name: String) -> String
static func since_shown(since: String, milestone: String) -> bool   # float(since) <= float(milestone)
# terms_text gains fallen: "the war ended with the Republic of Lucca"

# core/views/knowledge.gd  (M3 to M11, edit): knows() is true for every country once game.over is set
# core/views/country_card.gd  (edit): a fallen country {fallen_text "No more since Spring 1530"}; prestige {text, rank_text}
# core/views/season_summary.gd, log_lines.gd, reminders.gd  (edits): 4.11, 4.12
# core/views/study_rankings.gd  (M4.5, edit): MEASURES appends score; income_of subtracts interest
# core/views/study_history.gd  (edit): MARK_KINDS fell, bankrupt
# core/views/cards_economy.gd  (M4, edit): EconomyCards.ducats gains the debt lines (stage, rate, credit left, countdown)
```

### 5.7 The AI (`core/ai/`, M8 to M11, edits)

```gdscript
# core/ai/ai_debt.gd  (new)
class_name AiDebt extends RefCounted
static func debt(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void   # 4.9, one step a seat

# core/ai/ai_know.gd  (edit): the door gains
static func debt_of(game: Game, t: StringName) -> Dictionary                  # {stage, debt, limit, pending}
static func settle_options(game: Game, t: StringName) -> Array[StringName]    # allowed, in bankrupt_pick's order
static func incident_of(game: Game, t: StringName) -> Dictionary
static func incident_choices(game: Game, t: StringName) -> Array[Dictionary] # {n, ducats, ai_value, ok}
# core/ai/ai_brief.gd  (edit): debt (the stage)
# core/ai/ai_turn.gd  (edit): the debt step after brief; the door's text rule gains Debt., Incidents., Score., Ending.
```

---

## 6. The UI of M12

Built from the M1.5 kit and the M3 to M11 pieces. Colours and fonts from the Theme; HUD controls take no focus, screens do. The
App's milestone value becomes `"12"`, so every row, tab, measure and binding with `since: "12"` shows (compared as numbers,
D49). The layouts follow `docs/design/ui/10_bankruptcy_popup.png`, `09_debt_bar_and_panel.png` (option A, the right panel),
`15_event_popup_frame.png` (option A) and `16_event_art_compare.png` (composed from tiles), re-drawn in the Studiolo kit.

### 6.1 Keys and settings

No new binding. Screens' own keys: the event pop-up (**1** to **3** pick a card, **Left**/**Right** move, **Enter** chooses, **Esc**
decides later for an incident and does nothing for a bankruptcy); the game-over screen (**Enter** or **Esc**: View the map); the
hex panel with focus (**1** to **9** press the n-th build option, D53); a hint bubble (**Enter** "Got it"; **Esc** is the first
step of the Esc ladder while a bubble shows).

| Settings key (`Settings.SCHEMA`) | Change in M12 |
|---|---|
| `dev/developer_tools` | default **false** (D50) |
| `audio/ambient` | `since: "13"` (hidden, D57) |
| `accessibility/text_size` | gains `"step": 10` (the slider snaps) |
| `state/hints_seen` (**new**) | TYPE_STRING, "", the seen hint ids joined by ",", no row |
| `[meta] schema` (written by `SettingsIO`, not a schema key) | 2 (D48) |

`Options.PAGES` after M12: **Display, Graphics, Controls, Map, Accessibility, Game, Audio, Keys, Advanced, About**.

### 6.2 Bake slice 10: the whole-game pieces (`tools/ui_bake/pieces_m12.py`, new)

| Texture | Size (1x) | What |
|---|---|---|
| `icons_whole` (atlas, 24 px cells) | 240 x 72 | `debt` (a scroll with a red seal), `interest`, `bankrupt` (a broken coin), `pledge` (a deed with a hex), `army_pay` (a halved banner), `default` (a torn bond), `fell` (a fallen pennant), `hint` (a quill with a dot), `audio`, `music`, `effects`, `keys`, `text_size`, `contrast`, `logs`, `plague`, `famine`, `fair`, `silver`, `condottiere`, `flood`, `patron`, `scholar`, `envoy`, `bandits`, `harvest` (26 cells, 4 spare) |
| `stage_gauge` | 192 x 12 | the gauge's frame (9-slice, margins 6) |

`build_theme.gd` adds the icons as `Kit` icons and the variations `ChoiceCard`, `ChoiceCardSelected`, `ChoiceCardRefused`,
`HintBubble`, `StageGauge` (colours `band_debt`, `band_wary`, `band_refused`, `mark`), and in `theme_high_contrast.tres` the
`InkChart` inks of D55: `ink_0` #ffffff, `ink_1` #ffd646, `ink_2` #5fd3ff, `ink_3` #ff9a6b, `ink_4` #9dff8a (each 7:1 or more on
#000000, asserted by the bake) and a flat `seal_cracked` (a #ffd646 ring cut by a gap). `shell/ui/tokens.gd` gains `DEBT_INK
#c0392b`, `WARY_INK #d98a2b`, `REFUSED_INK #8e1f1f`, `HC_INKS` (the five above). The art director signs the M12 sheet
(`bake_ui.py --sheet`): the icons at 1x and 2x, a choice card in each state, the gauge in each stage, both themes.

### 6.3 The event pop-up (`shell/screens/event_popup.tscn/.gd`, new; `MODAL`, 1040 x 620)

```gdscript
class_name EventPopup extends Screen          # kind MODAL, screen_id &"event_popup"
signal answered(kind: StringName, choice: Variant)   # &"incident" with the card number, &"bankruptcy" with the option
func show_incident(view: Dictionary) -> void  # IncidentView.of
func show_bankruptcy(view: Dictionary) -> void # DebtView.bankruptcy
func selected() -> int                        # 0 none
func select(n: int) -> void
func choose() -> void                         # the selected card; Session.act through ctx.request

# shell/ui/choice_card.tscn/.gd  (new kit piece)
class_name ChoiceCard extends Button          # variation ChoiceCard / ChoiceCardSelected / ChoiceCardRefused
func show_choice(c: Dictionary) -> void       # {n, title, lines: [{tone, text}], foot, verdict, risky}

# shell/ui/tile_vignette.gd  (new kit piece)
class_name TileVignette extends Control       # the hex and its six neighbours drawn with the map's own tiles
func show_place(map: MapData, game: Game, hex: Vector2i, tiles: TilesetBuilder) -> void
	# MapCells.of_hex for the 7 hexes into its own small TileMapLayers (ground, sea, coast, piece ground, trees, relief, piece
	# back and front) with the season's TileSet, fitted to its size; shares the textures (no new memory)
```

| Part | Incident | Bankruptcy |
|---|---|---|
| Title | "Plague in Savona" (gold, `PanelRibbon`-free heading) | "Bankruptcy!" |
| Sub | "Event · Republic of Genoa · Summer 1481 · disease" | "Republic of Genoa · Winter 1484 · debt 412 of 360" |
| Picture | `TileVignette` of the place, 220 x 170 in a `PanelSlot` | `TileVignette` of the capital |
| Text and quote | the incident's `text` and `quote` (italic) | "Your bankers have refused another ducat ..." and "A state that cannot pay its soldiers soon has none." |
| Strip | none | three cells: debt and limit, ducats a season, companies unpaid |
| Cards | 2 or 3 `ChoiceCard`s: number, title, lines (▲ good, ▼ bad, ▶ plain; never colour alone), foot | the three settlements of 4.3 (foot: "Lasts 10 years, fading" / "Until you retake them" / "Castles rebuilt at full cost"); a refused one greyed with its reason |
| Foot | "Keys 1 to 3 choose. Esc: decide later (the event lapses next season)." | "This cannot be undone. Penalties fade over 10 years." |
| Button | **Choose** (primary; off until a card is selected) | **Settle: default** (danger; the label follows the card) |

Shown through `DECISIONS` (6.12). A refusal from `Session.act` toasts its reason and keeps the pop-up. Opened again by the task
flag's line, the report's notice or the chip. The sandbox has neither.

### 6.4 The Debt tab and the chips

`shell/screens/study/economy_debt_tab.tscn/.gd` (**new**, `EconomyDebtTab extends Control`; `PageEconomy.TABS` `debt` scene),
from `StudyDebt.of`:

| Part | Content |
|---|---|
| Head | "−240" (`NumberInk` bad) "ducats owed"; right: "limit 360" and "6 seasons of costs" |
| Gauge | `StageGauge` (**new**, `shell/ui/stage_gauge.gd`, `_draw` from the Theme): bands "Interest 2 %", "Interest 4 %", "Credit refused", a "you" mark, "Bankrupt" at the end; under high contrast the bands are hatched and labelled |
| Countdown | a card with the `hourglass` icon: "Bankrupt in 9 seasons" / "at −62 a season: in Spring 1484. Credit refused in 4." / "Not at this rate." |
| This season | income, spending, interest ("Interest, 2 % of 240"), net (`StudyTable`) |
| Ways out | `DebtView.ways_out` rows: text, "+38 a season" (`DeltaChip`), a button with the action's verdict |
| Debt, the last 8 seasons | `InkChart` `LINE_BARS`: bars the debt, a dashed line the limit (span 12 or 40 by `state/study_span`) |
| Penalties | "Taxes and trade −20 % (default of Spring 1484), fading until Spring 1494"; "Interest +3 points until Spring 1504" |
| Bankruptcies | "Spring 1484: defaulted." |
| Empty state | "No debt. You may spend on credit up to 306 ducats." with the empty gauge |

**Chips** (`shell/hud/chips.gd`, M4 to M11): the Ducats chip below 0 shows the `debt` icon, the value as bad ink and a 4 px
`StageGauge` under it (`DebtView.chip`); its card gains the stage, the rate, the credit left and the countdown; a click opens the
Debt tab. The **Prestige** chip (`ResourceChip` id `prestige`, icon `prestige`) after Research shows `Country.score` and its
change since last season; its card lists the parts (`ScoreView.chip`); a click opens Rankings on the Prestige measure. When the
bar narrows, Prestige hides first, then M4's order.

### 6.5 The game-over screen (`shell/screens/game_over.tscn/.gd`, new; `OPAQUE`)

```gdscript
class_name GameOver extends Screen            # kind OPAQUE, screen_id &"game_over"; EndView.of(Session.game, viewer)
func show_end(view: Dictionary) -> void
```

A `VellumSheet` letter in the walnut frame: the ribbon "The year 1651" (calendar), "Italy is yours" (conquest) or "The Republic
of Genoa is no more" (ruin); the seal `good` (first place or conquest), `plain`, or `cracked` (ruin); the lede ("Italy remembers
the Republic of Genoa second among its powers."); your place and prestige ("2nd of 13 · Prestige 612"); your prestige by part (a
`StudyTable`); your prestige through the years (`InkChart` `LINE` from `Stats` year rows); the **final ranking of every country**
(rank, arms, name, prestige, "No more since 1530"); five highlights from your chronicle; "Developer commands were used in this
game." when `dev_used`. Buttons: **View the map** (default; the game stays open, the top bar's End season reads **Results**
and reopens this screen), **Watch to the end** (ruin only: `Session.watch()`), **Credits**, **Main menu** (asks per D51).
It is pushed after the season's report closes, in the season `game_over` was heard.

### 6.6 Rankings, the report, the panels

- **Rankings** (`shell/screens/study/page_rankings.gd`, M4.5): the Prestige measure first in the switch and the page's default
  from M12; rows exact for you, banded for known others, "N countries unknown"; the line "You" and "The largest you know".
- **The report** (`shell/screens/season_report.gd`, M3 to M11): draws M12's lines from `SeasonSummary` (4.12); the seal
  `cracked` per D77; the glance chips' icons.
- **The country panel** (`shell/panels/country_panel.gd`): a fallen country shows "No more since Spring 1530" and no action; a
  living one gains "Prestige 412 · 3rd" (rank among those you know).
- **The hex panel** (`shell/panels/hex_panel.gd`): with focus in its build list, **1** to **9** press the n-th option (D53).

### 6.7 Options

- **Audio** (new page): Master, Music, Effects (sliders 0 to 100 %, step 5), Mute when in the background; a **Test** button by
  Effects sends `ctx.request(&"sound", {id: &"seal"})`. Volumes apply at once: the page only sets `Settings`, and the
  `SoundBoard` hears `Settings.changed` for `audio/*` and calls `apply_volumes` (`AudioServer.set_bus_volume_db(i,
  linear_to_db(v / 100.0))`, 0 % mutes the bus).
- **Keys** (new page): `OptionsKeys` moves from Controls (D52): groups Camera, Map, View, Game, App (and Developer while
  developer tools are on); two key caps an action; click a cap or **Rebind**, press a key; Esc cancels; a clash is refused
  ("F is already Fit whole map"); per-action **Reset** and **Reset all keys**; mouse and gesture rows are shown with "fixed".
- **Accessibility**: **Text size** (100 to 150 %, step 10; applies at once by `KitTheme.load_for(scale, kit, high_contrast,
  text_percent)`) and **High contrast** (switch; applies at once).
- **Game**: **Ask before losing progress** (D51), **Hints** (Off, Basic, All) and **Show hints again** (clears
  `state/hints_seen`).
- **Advanced**: **Developer tools** (off by default; turning it on shows the sandbox entry, F3, F2 and Ctrl/Cmd+R at once).
- **About**: adds "Logs: %APPDATA%\Hexa\logs" with **Open logs folder**; **Copy diagnostics** appends the last 40 lines of the
  previous run's log when that run did not close cleanly (`RunLock.left_behind`, M3).

### 6.8 Tutorial hints

```gdscript
# shell/hud/hint_def.gd  (new)
class_name HintDef extends Resource
@export var id: StringName
@export var level := 1                     # 1 Basic, 2 All
@export var trigger: StringName            # an Events signal name, &"game_started", &"screen:<id>" or &"turn:<n>"
@export var anchor: NodePath               # from the App root; empty: the screen's centre
@export var side: StringName = &"below"    # above, below, left, right
@export var text: String
# shell/hud/hint_table.gd  (new)
class_name HintTable extends Resource
@export var hints: Array[HintDef] = []
func validate() -> Array[String]           # ids unique; levels 1..2; triggers known
# shell/hud/hint_layer.gd + hint_layer.tscn  (new): on the HUD layer
class_name HintLayer extends Control
func setup(app: Node, table: HintTable, settings: Settings) -> void
func trigger(name: StringName) -> void     # queues the matching unseen hints of the level (at most 3)
func showing() -> StringName
func dismiss() -> void                     # marks it seen (state/hints_seen) and shows the next
```

A bubble is a `PanelCard` with the `HintBubble` variation, an arrow to its anchor, the text, **Got it** and **Hide hints**. One
at a time; only in a game with a player (not the sandbox, not a watched game); a hint whose anchor is hidden waits until it shows
or is dropped at the season's end; never over a modal screen (it waits). The App forwards `Events` signals, screen pushes and
`season_ended` to `trigger`.

| # | Id | Level | Trigger | Anchor (from the App) | Text |
|---|---|---|---|---|---|
| 1 | `pick` | 1 | `screen:new_game` | the country pick's banner | "Pick a country on the map. Genoa is a good first game: rich, small and by the sea." |
| 2 | `top_bar` | 1 | `game_started` | the chips | "Your money, people and armies. Hover a chip to see where its number comes from." |
| 3 | `select` | 1 | `game_started` (after `top_bar`) | the map's centre | "Click a hex of your land to see what stands there and what you can build." |
| 4 | `works` | 1 | `screen:works_preview` | the works card | "The works card shows what a work brings, season by season, before you pay." |
| 5 | `end_season` | 1 | `work_started` | End season | "When your orders are given, end the season (Space)." |
| 6 | `report` | 1 | `screen:season_report` | the report's nav | "The chancellor's report: what happened and what waits. Space begins the next season." |
| 7 | `task_flag` | 1 | `turn:2` | the task flag | "The flag lists what is left to do this season." |
| 8 | `study` | 1 | `turn:4` | the Ducats chip | "Press I for the study: your economy, rankings and history." |
| 9 | `research` | 1 | `research_idle` | the Research chip | "Nothing is being researched. Press T to choose." |
| 10 | `raise` | 1 | `turn:8` | the hex panel's Raise tab | "Raise companies in your towns; with an army selected, right-click to march." |
| 11 | `war` | 1 | `war_declared` | the notifications | "War. Battles are fought in the season; the odds card shows your chances before you march." |
| 12 | `peace` | 1 | `war_long` (a war of yours reaches 8 seasons) | the country panel's peace button | "Press P to see the peace terms. A war score of 50 lets the winner impose them." |
| 13 | `debt` | 1 | `debt_stage_changed` (to `debt`) | the Ducats chip | "You are in debt. Interest is due each season; the Debt tab shows the ways out." |
| 14 | `incident` | 1 | `incident_offered` | the pop-up's cards | "Events offer choices. Each card says what it brings; the last one costs nothing." |
| 15 | `save` | 1 | `turn:12` | the menu button | "F5 saves at once. The game also saves every year." |
| 16 | `modes` | 2 | `turn:3` | the map-mode switch | "Keys 1 to 8 change the map mode: owners, yields, food, supply, relations, trade." |
| 17 | `log` | 2 | `turn:5` | the action log | "The action log: click a line to look at the place." |
| 18 | `bookmarks` | 2 | `turn:6` | the map's centre | "Ctrl+Shift+1 sets a camera bookmark; Ctrl+1 jumps back." |
| 19 | `market` | 2 | `turn:10` | the Merchants chip | "Press E for your market: prices, goods and your merchants." |
| 20 | `prestige` | 2 | `turn:16` | the Prestige chip | "Prestige ranks the countries at the end of 1650: land, people, wealth, learning and deeds." |

`war_long` is a shell trigger the App sends when a war of the player's reaches 8 seasons (`Wars.of_country`, M7).

### 6.9 Sound

`shell/app/sound_board.gd` (**new**, `SoundBoard extends Node`, a child of the App; not an autoload):

```gdscript
class_name SoundBoard extends Node
func setup(settings: Settings, stack: ScreenStack) -> void
func play(id: StringName) -> void           # unknown ids are ignored; the same id at most every gap_ms
func apply_volumes() -> void
func set_music(on: bool) -> void            # on in a game and on the main menu; off in the loading screen
func playing() -> Array[StringName]         # tests
```

It reads `godot/assets/audio/sounds.json` (`{id: {file, bus, volume_db, gap_ms}}`), keeps 6 `AudioStreamPlayer`s for Effects
and one for Music (streamed OGG), connects `get_tree().node_added` to hear every `BaseButton`'s `pressed` (and `toggled` for
`KitSwitch`, `Segmented`), `ScreenStack.changed` for screens opening and closing, the App's `app_requested(&"sound", {id})`, and
the `Events` signals below. Mute when in the background: `AudioServer.set_bus_mute(0, true)` on
`NOTIFICATION_APPLICATION_FOCUS_OUT` while `audio/mute_unfocused` is on.

| Id | When | Bus | Source (CC0 unless said) |
|---|---|---|---|
| `ui_click` | a button pressed | Effects | Kenney, Interface Sounds (a soft click) |
| `ui_toggle` | a switch or segment toggled (the quill tick) | Effects | Kenney, Interface Sounds (a tick) |
| `ui_open` | a modal or opaque screen opens (the paper slide) | Effects | Kenney, RPG Audio (a book or cloth slide) |
| `ui_close` | it closes | Effects | Kenney, RPG Audio (a book close) |
| `ui_refused` | a toast of tone bad (a refused action) | Effects | Kenney, Interface Sounds (an error) |
| `seal` | the report's seal pressed, a settlement or an event chosen (the seal thud) | Effects | Kenney, Impact Sounds (a soft heavy impact) |
| `page_turn` | a season begins (`season_ended`) | Effects | Kenney, RPG Audio (a book flip) |
| `coin` | your work begun, your funding, a tribute received | Effects | Kenney, RPG Audio (coins handled) |
| `build` | your work finished | Effects | Kenney, Impact Sounds (wood) |
| `battle` | a battle of yours ended | Effects | Kenney, Impact Sounds (a metal clash) |
| `war_bell` | war declared on or by you | Effects | Kenney, Impact Sounds (a bell) |
| `fanfare` | your era reached; a peace you won; the end in first place or by conquest | Effects | Kenney, Music Jingles (a short fanfare) |
| `doom` | your bankruptcy; your country fell; the end by ruin | Effects | Kenney, Music Jingles (a low jingle) |
| `march` | your army's walk in the replay begins | Effects | Kenney, RPG Audio (footsteps) |
| `music_1`, `music_2`, `music_3` | the playlist (main menu and play) | Music | Our renderings of Tielman Susato's *Danserye* (1551), Michael Praetorius's *Terpsichore* (1612) and Thoinot Arbeau's *Orchésographie* tunes (1589): public-domain compositions, notes entered by us (`tools/audio/scores/*.mid`), rendered by `tools/audio/render_music.py` with the FluidR3_GM soundfont (MIT licence) |

The exact file of each pack is recorded in `sounds.json` (`source`, `licence`) by task J30, and the owner approves the set by
ear. **Mixing** (D58): `godot/default_bus_layout.tres` (project setting `audio/buses/default_bus_layout`): Master (an
`AudioEffectLimiter`, ceiling −1 dB), Music, Effects, Ambient (each sending to Master; Ambient unused in 0.3.0); effects
normalised to −3 dBFS peak with `volume_db` per row for balance (clicks −12, seal −6, fanfares −4); music at about −20 LUFS,
OGG Vorbis q5, 2 to 3 minutes a track, shuffled, 20 s of silence between tracks; `gap_ms` 120 (clicks 60). Audio memory: effects
decoded about 3 MB; music streamed.

### 6.10 Credits and About

`shell/screens/credits.gd` (M1.5): renders `godot/CREDITS.md` (8.12) by sections, then "Godot Engine's third-party notices"
from `Engine.get_copyright_info()` and `Engine.get_license_info()` (each component, its copyright and licence name; the full
texts are in the zip's `LICENSES/`). Reached from the main menu, About and the game-over screen. `shell/screens/about.gd` gains
the logs line and button and the last run's tail (6.7).

### 6.11 Main menu, sandbox, developer tools, confirmations

- **Main menu** (`shell/screens/main_menu.gd`): Continue, New game, Load game, Options, Credits, Quit; **Map sandbox** only
  while developer tools are on (D50). The version bottom right from `application/config/version`.
- **Command line**: `-- --dev` (developer tools on for this run), `-- --sandbox` (implies `--dev`), `-- --smoke [--seasons=N]
  [--windowed]` (8.9), M2's `-- --new-game`.
- **Confirmations** (`shell/app/app.gd`): with `game/confirm_loss` off, Main menu, Quit to desktop, the window's close, New game
  and Load over unsaved actions go ahead without asking; Save over a slot and Delete a save always ask (D51).

### 6.12 Decisions, the App, F3, the console

**Decisions** (`shell/app/decision_queue.gd`, M7 to M11): the order of D76. The App pushes `{kind: &"bankrupt", tag, turn}` on
`Events.bankrupt` (the player's) and `{kind: &"incident_offered", tag, turn}` on `Events.incident_offered` (the player's); `next`
shows the `EventPopup` for each. A bankruptcy cannot be left (Esc toasts "Choose how to settle: the game waits."); an incident's
Esc leaves it open (the reminder, the chip and the notice remain). A decision answered elsewhere is dropped (`debt_settled`,
`incident_resolved`); a decision naming a country that fell is dropped (`country_fell`). After a load, a pending settlement shows
at once as a decision; an open incident shows through its reminder.

| Request or event | The App (`shell/app/game_requests.gd`, `app.gd`) |
|---|---|
| `app_requested(&"bankruptcy")`, the reminder | push `EventPopup` (bankruptcy) when one is pending |
| `app_requested(&"incident")`, the reminder | push `EventPopup` (incident) when one is open |
| `app_requested(&"settle_debt", {option})`, `(&"answer_incident", {choice})` | `Session.act`; the toast or the refusal; `seal` sound |
| `app_requested(&"study", {page: &"economy", tab: &"debt"})` | open the study on the Debt tab |
| `Events.game_over` | remember it; after the report closes, push `GameOver` |
| `app_requested(&"game_over")` (the Results button) | push `GameOver` |
| `app_requested(&"watch")` | `Session.watch()`; close `GameOver`; the busy pill and replay as a watched game |
| `app_requested(&"sound", {id})` | `SoundBoard.play` |
| `Events.*` and screen pushes | `HintLayer.trigger` (6.8) |
| `Events.season_ended` | `StudyWarm` adds `StudyDebt.of` and `ScoreView.chip` |

- **F3** (`shell/hud/debug_overlay.gd`): "debt 0.2 ms · incidents 0.1 ms · extinction 0.0 · scores 0.4 · in debt 3 · bankrupt
  0 · fallen 1 · top GEN 612 · over –".
- **Console** (`shell/hud/dev_commands.gd`): `settle OPTION` (`settle_debt`), `incident KEY` (`Session.dev_incident`), `answer
  N` (`answer_incident`), `year YEAR` (`Session.dev_year`), `fall TAG TO` (M3's `dev_transfer` of every district of TAG to TO;
  the next extinction phase does the rest), `prestige [TAG]` (prints `Score.parts`), `over` (prints `Ending`'s state), each with
  M6's `as TAG`; problems "no such settlement", "no incident KEY", "no year YEAR in this game", "no country TAG", each a planted
  fault in its test. M4.5's `money N [TAG]` makes a debt.
- The App sets the milestone `"12"`, applies text size and high contrast at start and on change, owns the `SoundBoard` and the
  `HintLayer`, writes the log's header line (8.5), and runs the smoke mode (8.9). `app.gd` stays under 800 lines: the smoke mode
  lives in `shell/app/smoke_run.gd` (**new**) and the confirm rules in `shell/app/leave_rules.gd` (**new**).

### 6.13 Localisation (stance, D60)

0.3.0 is English only. The strings live in three places, and nowhere else: **core sentences** only in `core/views/words.gd`
(`Words`) and the views that call it (systems emit events with data, never words; M3's rule); **names** in the `.tres` files
(countries, goods, techs, incidents, hints); **shell labels** in the `.tscn` files and the shell's scripts. When localisation
comes (after M12, section 13): Godot's `TranslationServer` with PO files; `Words`' templates and the `.tres` names go through
`tr()`; scenes use `auto_translate_mode`; `Words.number` already formats numbers in one place. No string is built by
concatenating words in a system, so no rule changes then.

---

## 7. Data and the editor

| File | Holds | Made by | Checked by |
|---|---|---|---|
| `godot/data/defs/debt.tres` (**new**) | `DebtDef` (4.1 to 4.3) | by hand (J6); tuned by J37 | `tests/core/test_whole_defs.gd` |
| `godot/data/defs/score.tres` (**new**) | `ScoreDef` (4.6) | by hand (J6); tuned by J37 | `test_whole_defs.gd` |
| `godot/data/defs/incidents.tres` (**new**) | `IncidentsDef` | by hand (J6) | `test_whole_defs.gd` |
| `godot/data/defs/incidents/<key>.tres` (**new**, 11) | `IncidentDef` with its choices and effects as sub-resources (4.8) | by hand (J6) | `tests/core/test_incident_data.gd`: every row of 4.8 |
| `godot/data/defs/game_defs.tres` (edit) | `debt`, `score`, `incidents`, `incident_list` | by hand (J6) | `GameDefs.validate()` |
| `godot/data/defs/diplomacy.tres` (M9, edit) | `keep_last_district` false | by hand (J6) | `test_whole_defs.gd` |
| `godot/data/defs/tempers/*.tres` (M8, edit) | `bankrupt_pick` (4.9) | by hand (J6) | `tests/core/test_ai_defs.gd` |
| `godot/data/scenarios/north_italy_1480.tres` (M2, generated) | `end_year` 1650, `creditors` GEN, TUS, VEN, `known_digests` [] | `godot/tools/build_scenario.gd` (J6 edits its source table) | `build_scenario.gd --check` in CI |
| `godot/data/ui/hints.tres` (**new**) | `HintTable` (6.8) | by hand (J29) | `tests/shell/test_hints.gd`; `test_hint_anchors.gd` (every anchor resolves in the harness App) |
| `godot/tools/whole_tables.gd` (**new**, headless) | prints 4.1 to 4.8 and the hints as Markdown from the files | J6 | `test_whole_defs.gd` runs it and compares one row of each table |
| `godot/assets/audio/sounds.json`, `effects/*.ogg`, `music/*.ogg` (**new**) | the sound list of 6.9 with `file`, `bus`, `volume_db`, `gap_ms`, `source`, `licence` | J30 (picked from the packs; music rendered) | `tools/audio/check_audio.py` in CI: every row's file exists and is OGG, every source named in `CREDITS.md`, every licence CC0 or our own, durations within 0.05 to 4 s (effects) and 90 to 240 s (music) |
| `tools/audio/render_music.py`, `tools/audio/scores/*.mid` (**new**) | the music's notes and its renderer (FluidSynth with FluidR3_GM) | J30 | run by hand; its output is committed |
| `godot/default_bus_layout.tres` (**new**) | the buses (6.9) | the Godot editor (J28) | `tests/shell/test_sound_board.gd` |
| `godot/assets/ui/kit/` (slice 10), `godot/assets/ui/icon/hexa.ico` and `hexa.png` (**new**) | `icons_whole`, `stage_gauge`; the app icon (16 to 256 px, the wind rose on walnut) | `tools/bake_ui.py` (J3) | `bake_ui.py --check`, `build_theme.gd --check` |
| `godot/assets/tiles/**`, `assets/tiles/tiles_*.tres` | the bold marks (J4), the relief forms (J11), the spring and autumn palettes (J16) | `tools/worldmap/tileset_bake/` and `godot/tools/build_tileset.gd` | `build_tileset --check` |
| `godot/tests/fixtures/saves/0.3.0/*.sav` and `.png` (**new**, 3) | the release saves (D46) | `godot/tools/release/make_release_saves.gd` (J21) | `tests/core/test_release_saves.gd` |
| `godot/data/README.md` (edit) | the M12 files | J6 | |

The scenario editor (M2) shows `end_year`, `creditors` and `known_digests` in the inspector; nothing else changes. No map data
changes: falls, debt and incidents read the map and the state.

---

## 8. Release engineering and speed

### 8.1 One version string

`godot/project.godot` `application/config/version` ("0.3.0") is the only place. It is read by the main menu, the About page, the
save header's `build` (M3), the log's header line and the export (8.2). `tools/release/check_release.py` (**new**) fails when: a
tag `vX.Y.Z` differs from it; `export_presets.cfg` holds a version; `CHANGELOG.md` has no section `## vX.Y.Z`; `CREDITS.md`
misses a font family, a sound pack, the GeoNames, ETOPO or FluidR3_GM lines; the export's exclude filter misses `tests/*`,
`tools/*` or `addons/gut/*`.

### 8.2 The Windows export

`godot/export_presets.cfg`, preset "Windows Desktop" (edits): `exclude_filter="tests/*, tools/*, addons/gut/*, shell/editor/*"`;
`include_filter="data/*, assets/tiles/*/*.json, assets/audio/sounds.json"`; `application/file_version=""` and
`application/product_version=""` (Godot uses `application/config/version`); `application/icon="res://assets/ui/icon/hexa.ico"`;
`application/file_description="Hexa, a strategy game of Renaissance Italy"`; `application/copyright="2026, the Hexa project"`;
`application/export_angle=1` (ANGLE ships beside the exe, the fallback when the OpenGL driver fails); `binary_format/embed_pck=true`,
`texture_format/s3tc_bptc=true`, `codesign/enable=false` kept. `project.godot` gains `config/icon` and
`rendering/gl_compatibility/fallback_to_angle=true`.

The exact command (from the repository root, `GODOT` set, the export templates of 4.7.2 installed):

```bash
"$GODOT" --headless --path godot --import
"$GODOT" --headless --path godot --export-release "Windows Desktop" "$PWD/build/Hexa.exe"
"$GODOT" --headless --path godot -s res://tools/release/write_licences.gd -- --out="$PWD/build/LICENSES"
```

### 8.3 The zip, the installer, signing

```
Hexa-0.3.0-windows.zip
  Hexa-0.3.0/
    Hexa.exe                     the game; its data packed inside
    libEGL.dll, libGLESv2.dll    ANGLE (the OpenGL fallback)
    README.txt                   docs/release/README.txt: how to start, the SmartScreen note, the keys, where saves and logs live,
                                 how to remove the game (delete this folder and %APPDATA%\Hexa)
    CHANGELOG.txt                the v0.3.0 section of CHANGELOG.md
    CREDITS.txt                  godot/CREDITS.md
    LICENSES/                    godot.txt, godot-third-party.txt (from Engine), OFL-cinzel.txt, OFL-alegreya.txt,
                                 OFL-alegreya-sc.txt, OFL-alegreya-sans.txt, OFL-noto.txt, FluidR3_GM.txt (MIT), kenney-cc0.txt
Hexa-0.3.0-windows.zip.sha256    "<sha256>  Hexa-0.3.0-windows.zip"
```

**A zip, not an installer** (D61): unzip anywhere, no admin rights; saves and settings in `%APPDATA%\Hexa`. **Unsigned** (D62):
`README.txt` and the release notes say "Windows may warn that the publisher is unknown: choose More info, then Run anyway", and
publish the checksum (`Get-FileHash Hexa-0.3.0-windows.zip` to compare).

### 8.4 The release workflow (`.github/workflows/release.yml`, new)

On a tag `v*.*.*` (and by hand with `dry_run`): `permissions: contents: write`.

| Job | Runs on | Does |
|---|---|---|
| `verify` | ubuntu | `python tools/release/check_release.py --tag "$GITHUB_REF_NAME"` |
| `checks` | ubuntu | the composite action `.github/actions/godot-checks` (**new**: godot.yml's `checks` steps moved into it, used by both workflows): import, lint, both UI `--check`s, check_scripts, the main scene, `build_theme`, `build_tileset`, `build_map`, `build_scenario` `--check`s, `keys_table.gd --check`, `check_audio.py`, GUT |
| `whole` | ubuntu, a matrix of 10 legs | `soak.gd --suite=whole --seeds=<a>-<b>`; then `soak-ranges` judges the 100 games (4.15) |
| `export` | ubuntu | import; the export of 8.2; `write_licences.gd`; the zip of 8.3; `sha256sum`; artifact `hexa-windows` |
| `smoke-windows` | windows-latest | unzip; `Hexa.exe --headless -- --smoke --seasons=8` must print `SMOKE OK` and exit 0; `Hexa.exe --rendering-driver opengl3_angle -- --smoke --seasons=4 --windowed` the same, its screenshot kept |
| `perf-windows` | windows-latest | Godot 4.7.2 for Windows (`setup-godot` gains a `platform` input); `perf_core.gd -- --cpu-only` on north Italy and the made-up Europe against `perf_core_budget.json` (CPU rows only; no GPU on the runner) |
| `release` | ubuntu, needs all | `python tools/release/release_notes.py` (the template, the changelog section, the checksum) then `gh release create "$GITHUB_REF_NAME" --draft --title "Hexa X.Y.Z" --notes-file notes.md` with the zip and its `.sha256` |

The owner publishes the draft after the release playtest. `godot.yml` keeps a hand-dispatched playtest zip (its `export-windows`
job, renamed `playtest-zip`, no tag trigger) and drops `smoke-windows` (the release workflow owns it).

### 8.5 Logs and crashes

`godot/project.godot` gains: `debug/file_logging/enable_file_logging.pc=true`, `debug/file_logging/log_path="user://logs/hexa.log"`,
`debug/file_logging/max_log_files=10`, `debug/settings/crash_handler/message="Hexa stopped. Its log is in %APPDATA%\Hexa\logs:
please attach it to a bug report."`. At start the App prints one line: "Hexa 0.3.0 · Windows 10.0.19045 · gl_compatibility ·
<adapter>". Godot renames the previous log with its date at start and keeps ten. M3's `RunLock` marks an unclean exit; the next
start toasts "Hexa did not close properly; its log is kept (Options, About)" beside M3's autosave recovery question. About's
**Copy diagnostics** adds the previous log's last 40 lines then.

### 8.6 Saves and settings across versions

Saves: 4.13's migration table (D45 to D47). **The save-compatibility check in CI** is `tests/core/test_release_saves.gd`, in GUT on
every pull request: for each folder under `godot/tests/fixtures/saves/` (`0.3.0/` first) it reads every save's header (state
`ok`), loads it, plays one season, saves and loads again, and finds equal digests. `godot/tools/release/make_release_saves.gd`
writes a release's three saves (Spring 1481 and Spring 1520 of seed 1480 as Genoa with the AI on, and the game over of
`EndFixture.italy_short`) in the release's own pull request; they are never regenerated afterwards.

Settings (D48): `SettingsIO` writes `[meta] schema = 2`; on load, a file without `meta/schema` drops every `dev/*` key; keys not
in `Settings.SCHEMA` and `[keys]` entries for unknown actions are dropped (M1.5); a value out of range falls back to the default
(M1.5).

| `settings.cfg` | Made by | 0.3.0 does |
|---|---|---|
| no `[meta]` | M1.5 to M11 test builds | keeps every valid key but `dev/*` |
| `schema = 2` | 0.3.0 | reads it |
| `schema` above 2 | a later build | reads the keys it knows (later builds keep that rule) |

### 8.7 Speed: the minimum PC, the budgets, the measured pass

**The minimum PC** (D66), printed in `README.txt` and the release notes: Windows 10 (22H2) or 11, 64-bit; a 4-thread x86-64
CPU at 2.5 GHz (Intel Core i5-6500 or AMD Ryzen 3 2200G class); 8 GB of RAM; a GPU with an OpenGL 3.3 driver and 2 GB (Intel
UHD 620 or better; ANGLE when the driver fails); 1 GB of disk; a 1280 x 720 screen.

`godot/tools/perf_core.gd` (M3 to M11) on the made-up Europe, `PerfFixture.europe_whole(seasons)` (**new**, in
`godot/tools/perf_fixture.gd`): M11's `europe_research` with debt and incidents on, 10 countries in debt, 2 bankrupt, 1 to fall;
rows in `godot/tests/perf_core_budget.json`, nightly, never in GUT:

| Row | Limit | What |
|---|---|---|
| `season_ms` | **460** (M11: 440) | the twenty phases other than `ai_orders`, worst of 8 seasons |
| `debt_ms` | 10 | the debt phase, 60 countries |
| `incidents_ms` | 8 | the incidents phase |
| `extinction_ms` | 5 (30 in a season with a fall) | the extinction phase |
| `scores_ms` | 10 | the scores phase (the chronicle of the turn, 60 countries) |
| `debt_view_ms` | 2 | `DebtView.of` and `ways_out`, uncached |
| `study_debt_ms` | 4 | `StudyDebt.of` |
| `end_view_ms` | 30 | `EndView.of` (once a game) |
| `ai_season_ms` | 3,000 mean (M8) | with the debt step |
| `save_mb` | 8 (M3) | with the M12 fields |

`godot/tools/ui/perf_ui.gd` gains in `perf_ui_budget.json`: `event_popup_ms` 16 (opened cold with the vignette), `game_over_ms`
33, `debt_tab_ms` 16, `audio_page_ms` 16, `keys_page_ms` 16, `text_size_apply_ms` 100 (a Theme rebuild, once), `hint_show_ms` 4.

**The release budgets** (the measured pass, written in `docs/release/0.3.0-perf.md` by J38 with the machine's CPU, GPU and RAM):

| Budget | Limit | Measured on |
|---|---|---|
| A frame at every zoom, panning, north Italy at 1920 x 1080 | 16 ms worst | the reference PC (the owner's Windows PC), `perf_map.gd --gpu-limits` |
| The 122,000-hex frame budgets of M1 9 | as M1 | the reference PC |
| End season to the report on north Italy (12 AI seats, replay off) | 3 s | the reference PC; the runner (`perf-windows`) |
| The AI season on north Italy | 200 ms mean (M8's `ai_season_ni_ms`) | the runner |
| Start to the main menu | 4 s | the reference PC |
| New game to the first frame of the map | 8 s | the reference PC |
| Load a 1650 save | 2 s | the reference PC; the runner |
| Memory in play | 1.2 GB RAM; video memory per 8.8 | the reference PC (F3's `MEMORY_STATIC`, `RENDER_VIDEO_MEM_USED`) |

The runner (`windows-latest`, 4 vCPU) stands for the minimum CPU; the minimum GPU is checked by the owner's or a tester's
UHD-620-class laptop in the release playtest (9.3 item 5); without one, the notes name the GPU the reference pass used.

### 8.8 Memory budget

| What | Budget (Windows, BPTC) | Source |
|---|---|---|
| Tiles, spring to autumn / winter | 76 / 224 MB; 152 / 300 MB with the next season preloaded | `ui-and-controls-spec.md` 6.3 |
| UI kit | 1x under 4 MB, 2x under 16 MB in play; `menu_bg` (8.3 MB) freed in play | style spec 4.10 |
| Font atlases | 8 MB | style spec 4.10 |
| The mode overlay and far picture | under 8 MB on north Italy | M2 |
| Audio | effects about 3 MB decoded; music streamed | 6.9 |
| The event pop-up's vignette | 0 (shares the TileSet) | 6.3 |
| **Video memory in play** | **512 MB** (the M1 budget) | `perf_ui.gd` fails past it |

### 8.9 The smoke test of the exported build

`-- --smoke [--seasons=N] [--windowed]` (`shell/app/smoke_run.gd`, **new**): with developer tools off and the AI on, a new game of
Italy 1480, seed 1480, as Genoa; N seasons through `Session` (default 8), decisions answered by their safe choice (war alerts "To
the report", offers refused, incidents' last choice, a settlement `default`); a save to `user://smoke/` (never the player's
slots); a load; the digest equal; two more seasons from both, equal digests; prints `SMOKE OK <digest>` and quits with 0, or
prints the failure and quits with 1. Windowed, it shows the map and the report for a frame each and saves
`user://smoke/smoke.png`.

### 8.10 The checks in CI

| Check | Job | When |
|---|---|---|
| Lint, import, check_scripts, main scene, GUT (with `test_release_saves.gd`) | `godot.yml` `checks` (the composite action) | every pull request |
| `bake_ui.py --check`, `build_theme.gd --check`, `build_tileset --check`, `build_map --check`, `build_scenario.gd --check`, **`keys_table.gd --check`**, **`check_audio.py`** | the same | every pull request |
| **`check_release.py`** (without `--tag`) | the same | every pull request |
| UI pictures and `perf_ui` | `ui-shots` | pull requests touching the shell |
| `perf_map`, `perf_core`, `soak` (with `whole` 1-10), `soak-ranges` | nightly | nightly |
| The whole release | `release.yml` | a tag |

### 8.11 The docs for players

- **`README.md`** (root) gains, first, a short section "Hexa 0.3.0 (Windows)": what it is (a strategy game of north Italy from
  1480 to 1650), the download (the release page), starting it (the SmartScreen note), saves and logs, the minimum PC, and the
  **controls table generated** between `<!-- keys:begin -->` and `<!-- keys:end -->` by `godot/tools/keys_table.gd` (**new**,
  headless) from `Bindings.DEFAULTS` up to milestone 12 (action, keys, Mac keys); `--check` fails when the table differs. The
  Python sections follow under "The Python game (v0.2.2, frozen)".
- `docs/release/README.txt` (**new**, the zip's readme) carries the same table (written by the same tool).
- `CLAUDE.md`: the Godot commands gain `soak.gd --suite=whole`, `whole_tables.gd`, `keys_table.gd --check`,
  `tools/release/check_release.py`, `make_release_saves.gd`, the smoke and the export of 8.2.
- `godot/README.md`: the M12 game, the release, the new folders (`assets/audio/`, `data/ui/`, `tools/release/`).

### 8.12 Licences and credits (`godot/CREDITS.md`, complete)

| Section | Content |
|---|---|
| Hexa | "Hexa 0.3.0, a game of the Hexa project (github.com/GergoPeterSomodi/Hexa)." |
| Godot Engine | kept (the MIT notice); the third-party components from `Engine.get_copyright_info()` in the credits screen and `LICENSES/godot-third-party.txt` |
| Art | kept: drawn in code for Hexa; no third-party art in the game |
| Map data | the relief: NOAA NCEI, ETOPO 2022 15 Arc-Second Global Relief Model (doi:10.25921/fd45-gt74); place names: GeoNames (CC BY 4.0, geonames.org), as `data/geography/placenames.json`'s credit says (this replaces "arrive with the map data in 0.3.0 and are credited here then") |
| Fonts | kept (Cinzel, Cinzel Decorative as a bake input only, Alegreya, Alegreya SC, Alegreya Sans, Noto Sans; SIL OFL 1.1) |
| Sound | Kenney (kenney.nl): Interface Sounds, RPG Audio, Impact Sounds, Music Jingles; CC0 1.0, credited with thanks |
| Music | Tielman Susato (*Danserye*, 1551), Michael Praetorius (*Terpsichore*, 1612), Thoinot Arbeau (*Orchésographie*, 1589): public domain; arranged and rendered for Hexa with the FluidR3_GM soundfont by Frank Wen (MIT licence) |
| Tools (not shipped) | GUT 9.7.1 (MIT) for the tests |

### 8.13 The release notes template (`docs/release/notes-template.md`, new)

Sections, filled by `tools/release/release_notes.py`: **Hexa X.Y.Z** (one paragraph: what the game is); **Download** (the zip,
its SHA-256); **Before you start** (SmartScreen; the minimum PC); **What is in this release** (the changelog section); **Saves**
("Saves of 0.3.0 and later keep loading in later versions"); **Known issues** (from `docs/release/known-issues.md`, kept by the
owner); **Credits** (a link to `CREDITS.txt`).

### 8.14 The Europe switch (D3, D4)

0.3.0 ships on north Italy. Europe switches in with **M13 Europe** (section 13) when all hold, measured on the real map:

| Criterion | Limit | From |
|---|---|---|
| E2's map file of Europe at 28 km validates, rebuilt to the same digest in CI | yes | standard 4.2 |
| A Europe 1480 scenario (about 60 countries) validates; `build_scenario.gd --check` | yes | M2 |
| `ai_season_ms` | 3,000 mean, 5,000 worst | M8 8.3 |
| `ai_step_worst_ms`; `season_ms` | 8; 460 | M8 8.3, this page 8.7 |
| The AI turn's wall time; a frame while the AI runs | 10 s; 16 ms mean, 24 worst | M8 8.3 |
| `save_mb`; load after 40 AI seasons | 8; 2,000 ms | M8 8.3 |
| A frame at every zoom | 16 ms | M1 |
| The `europe` soak 4 x 40, then the `whole` suite on Europe (20 games, 684 seasons) | no crash; every invariant; 4.15's ranges re-set for Europe by Opus | M8, this page |
| The owner's word | after a Europe playtest | standard 9 |

A failed budget takes M8's fallbacks, then a larger hex (data, not code). Europe ships as 0.4.0.

### 8.15 The map look before the release (D5)

| Item | In M12 | Done when |
|---|---|---|
| Decor density (`graphics/decor_density`: full, thin, sparse) | J4: `MapCells.fill_hex` takes a density (the tree wedges' `option` steps down: full → thin → sparse; hills and ridges unchanged); the map scene re-fills the tree layers on change | the three densities on north Italy at zoom 1 signed by the art director; `perf_map` unchanged at full |
| Bold high-contrast marks | J4: `mark/select_bold` (a 5 px ring) and `mark/grid_bold` (2 px) in `mark_tiles.py`; `MapCells` uses them under `accessibility/high_contrast` | both on the map under high contrast |
| Ranges along crest chains | J11: `relief/<kind>/<form>/<v>` gains forms `tall` (a crest hex with two crest edges or more) and `left`, `right` (a ridge following one crest edge on that side) in `decor_tiles.py`; `MapTiles` picks the form from `MapData.crest` | the Alps read as ranges at zoom 0.5 and 1 (art director); `missing_names()` empty |
| Spring and autumn palettes | J16: the art director's palettes in `tools/worldmap/tileset_bake/art.py` (M1 12.8: "still stand-ins") | the four seasons side by side, signed |
| The release look | J38: north Italy in the four seasons at zooms 0.5, 1, 2 beside the style frame | signed in `docs/design/map/release-look.md` |
| Real shoreline meshes, ground splat shader, trees one by one, bridge and road restyle, water and coast animation, 2x bake for Retina, mipmaps | **M14 Map look II** (section 13) | |

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (P).

### 9.1 The files

| File | Cases |
|---|---|
| `tests/core/debt_fixture.gd` (**new**) | `DebtFixture.off(defs)` (D21: `debt.enabled` false, `incidents.enabled` false, `keep_last_district` true), `on(defs)`, `lone(defs)` (4.14 a) |
| `tests/core/fall_fixture.gd`, `score_fixture.gd`, `end_fixture.gd`, `incident_fixture.gd` (**new**) | `FallFixture.duel` (4.14 b); `ScoreFixture.parts` (4.14 c); `EndFixture.short`, `italy_short` (4.14 d); `IncidentFixture.always(defs, keys)` (4.14 e) |
| `tests/core/scenario_fixture.gd` (edit) | `with_debt(on)`; `DebtFixture.off` by default, so every M3 to M11 pin holds unchanged |
| `tests/core/test_whole_defs.gd` (**new**) | every class's `validate` (P: `wary_at` ≥ `refused_at`; `credit_permille` above `refused_at`; a `bankrupt_pick` that is not a permutation; an incident whose last choice costs ducats; an unknown effect kind or place rule; a fair with no seasons; `end_year` ≤ `year`; a creditor not in the scenario; a score divisor of 0); `whole_tables.gd`'s rows |
| `tests/core/test_incident_data.gd` (**new**) | 4.8's deck exactly (keys, weights, conditions, choices, effects, deeds, `ai_value`) |
| `tests/core/test_debt.gd` (**new**) | **done-when 1**'s limit, stages, rates, interest, credit line, `can_pay` (P: a work at −310 allowed is caught; a free clear refused below zero is caught), desertion's order and cap (P: a general's army losing its general to desertion; more than half the companies), the debt phase's five steps in order, its events |
| `tests/core/test_bankruptcy.gd` (**new**) | every row of `settle_debt_check` (P each); the three settlements' numbers of 4.14 a; creditors (dead, at war, none: the two richest); the pledge plan (never the capital; the cap; nearest first); the lapse to default; `fresh_until`; generals dismissed; orders freed with `bankrupt`; `debt_settled` once |
| `tests/core/test_fall.gd` (**new**) | **done-when 2**: 4.14 b; terms `fallen` in every list (P: a `fallen` peace with a truce); pacts ended; league seats dropped (P: a dead member left in `members`); offers dropped; seats (an AI seat list without the dead); `Game.watch` after a ruin (`keep_last_district` false in the data is pinned by `test_whole_defs.gd`) |
| `tests/core/test_score.gd` (**new**) | **done-when 3**: 4.6's parts on `ScoreFixture.parts` (191); deeds from the turn's chronicle only (P: an entry counted twice; a deed written outside the phase); a fallen country 0; ties by id; `known_points` and `men_under_arms` used |
| `tests/core/test_ending.gd` (**new**) | `EndFixture.short`: over after turn 4; `last_turn` 684 for 1480; conquest; ruin before calendar; `end_check`'s rows (P: End season allowed when over; allowed with a pending settlement); `game_over` once |
| `tests/core/test_incidents.gd` (**new**) | **done-when 4**: the roll and draw from `luck.world` (pinned per seed); cooldown, first turn, one open; every place rule; every effect kind through its owner (P: a test-only effect writing `treasury` directly is reported by `test_no_other_writers.gd`); the lapse to the last choice; `answer_incident`'s rows (P each); fairs in `Trade.appetite` and their end |
| `tests/core/test_whole_property.gd` (**new**) | 40 seasons with the random player for every country (every action of M1 to M12) on `DebtFixture.on` with incidents: every season the `debt`, `fallen`, `score` and `ending` invariants hold and the ledger sums to the treasury's change (interest included) |
| `tests/core/test_whole_saves.gd` (**new**) | save, load, save byte-equal with debts, a pending settlement, a fallen country, an open incident, fairs and `over`; ten seasons after a load equal ten without; `FORMAT` 10 (P: a format-9 header reads `older`; a `country/7` body refused; an unknown incident key; a stage `"broke"`) |
| `tests/core/test_whole_italy.gd` (**new**) | `EndFixture.italy_short` (north Italy, end 1481, the AI on): 8 seasons, over by the calendar, `EndView.of` lists 13 countries, a save at the end loads to the game-over |
| `tests/core/test_release_saves.gd` (**new**) | 8.6: every save under `tests/fixtures/saves/` loads (state `ok`), plays a season, saves and loads to the same digest (P: a fixture save with a changed scenario digest not in `known_digests` reads `other_build`) |
| `tests/core/test_season.gd`, `test_chronicle.gd`, `test_vision.gd`, `test_game_core.gd`, `test_replay.gd`, `test_snapshot.gd`, `test_save_file.gd`, `test_owns.gd`, `test_forty_seasons.gd`, `test_money_property.gd`, `test_men_property.gd`, `test_check_contract.gd`, `test_insights_views.gd`, `test_treasury.gd`, `test_stores.gd`, `test_stats.gd`, `test_country_state.gd`, `test_war_state.gd`, `test_people.gd` (edits) | **`PHASES` is the twenty-one of 4.10** (the pin); fifty-six notable kinds; forty actions; twenty-three `WHY`; eleven flows; sixty-two series; `dev_incident` and `dev_year` replay (P: another year gives another digest); 5.3's OWNS table (P: a test-only phase writing `deeds`); `country/8`, `market/2` round trips and refusals; `SaveFile.upgrade` with no step returns the body |
| `tests/core/test_peace.gd`, `test_coalitions.gd`, `test_trade_pacts.gd`, `test_merchants.gd`, `test_trade.gd`, `test_research.gd`, `test_wars.gd`, `test_improve_actions.gd`, `test_economy_season.gd` (M3 to M11, edits) | `fallen`; `drop`; `end_of`; `bankrupt`; `add_fair` and the factor on the merchants' line; `add_progress` and the fund row (P); row 9a (P: a refused-stage country declaring); `lower_fortress` (castles only; P: a town lowered); `income_factor` on the tax lines and `debt_limit` |
| `tests/core/random_player.gd` (edit) | `settle_debt` and `answer_incident` with random options |
| `tests/core/test_words.gd`, `test_knowledge.gd`, `test_country_card.gd`, `test_season_summary.gd`, `test_log_lines.gd`, `test_reminders.gd`, `test_study_history.gd`, `test_study_rankings.gd`, `test_cards_economy.gd` (edits); `test_debt_view.gd`, `test_incident_view.gd`, `test_score_view.gd`, `test_end_view.gd`, `test_study_debt.gd` (**new**) | the words; every reader of `since` through `Words.since_shown` (P: "12" shown at milestone "4.5"); every country known once over (P: fog after the end); the sentences of 4.11 and 4.12 (P: a deserted line with no companies); the report equal after a save and load; every reminder (P: `settle_debt` with nothing pending makes no line); the Prestige measure; income minus interest equals `left_over` (M4.5's equality kept); the views' verdicts equal the checks (P) |
| `tests/core/test_ai_debt.gd` (**new**); `test_ai_defs.gd`, `test_ai_know.gd`, `test_ai_door.gd`, `test_ai_turn.gd`, `test_ai_play.gd` (edits) | the settlement by temperament; the incident answer by `ai_value` and reserve; recalls at a loss in `wary`; the step order; the door's tokens (P: `Debt.` in a step module); a fallen seat never acts |
| `tests/core/invariants.gd`, `test_invariants.gd`, `test_ai_soak_quick.gd` (M8 to M11, edits) | `debt`, `fallen`, `score`, `ending` (P each: a stale stage, a dead country with an army, a score off by one, `over` changed twice); `peaces` as 1.2 |
| `tests/shell/test_event_popup.gd`, `test_choice_card.gd`, `test_tile_vignette.gd`, `test_game_over.gd`, `test_economy_debt_tab.gd`, `test_stage_gauge.gd`, `test_sound_board.gd`, `test_hints.gd`, `test_smoke_run.gd`, `test_leave_rules.gd` (**new**) | every part of 6.3 to 6.9 from the views' fixtures; keys 1 to 3, Enter, Esc per kind (P: Esc closing a bankruptcy); the vignette's seven hexes and its season; the game-over's buttons per reason; the tab's empty state; the gauge's stages and its high-contrast hatching; volumes to buses, mute on focus out, the 120 ms gap, 6 voices (a fixture `sounds.json`); hints: level, once, one at a time, the queue of 3, hidden anchors wait, "Hide hints"; the smoke in-process on `EndFixture.short` prints `SMOKE OK`; `confirm_loss` off asks nothing on leave and still asks on delete (P) |
| `tests/shell/test_options.gd`, `test_options_keys.gd`, `test_settings.gd`, `test_kit_theme.gd`, `test_ink_chart.gd`, `test_chips.gd`, `test_decision_queue.gd`, `test_app_flow.gd`, `test_main_menu.gd`, `test_about.gd`, `test_credits.gd`, `test_hex_panel.gd`, `test_country_panel.gd`, `test_page_rankings.gd`, `test_season_report.gd`, `test_dev_commands.gd`, `test_debug_overlay.gd`, `test_session.gd`, `test_bindings.gd` (edits) | the ten pages; every schema key has a row and every row a key; the Keys page's capture, clash, resets, fixed mouse rows (P: Esc unbound from `app_back`); schema 2's migration (P: a test build's `dev/developer_tools = true` survives); the developer default off; **every key persists** (set to a valid non-default, save, load, equal); text size scales every font size (P: one variation left unscaled); the high-contrast inks; the debt chip and the Prestige chip; the decisions' order (D76) and drops; the sandbox hidden and `--dev`; About's logs; Credits' sections and the engine notices; the number keys; a fallen country's panel; the Prestige measure first; the cracked seal; the console's commands and faults; the F3 line; the eight signals drained after their phases and actions; **end to end** (`test_app_flow.gd`): a new game as Genoa, `money -300`, End season (interest and the stage), `year 1650`, End season to the game-over screen, View the map, Results, Main menu |
| `tests/shell/test_keyboard_reach.gd`, `test_text_fit.gd`, `test_hint_anchors.gd` (**new**) | every `ScreenIds.PATHS` scene exists, opens in the harness, takes focus, Tab reaches every enabled button, Esc does what its kind says (9.3 item 9); at 150 % text on 1280 x 720 no `Label` or `Button` of the shot list is clipped (`TextFit.clipped`, **new** `shell/ui/text_fit.gd`); every hint's anchor resolves in the harness App |
| `tests/shell/test_ui_monkey.gd` (edit) | adds the event pop-up's keys, the Debt tab, the Keys and Audio pages, `year 1650` then the game-over; the digest changes only after an accepted action or a season |
| Python `tests/test_bake_ui.py` (edit), `tests/test_check_release.py`, `tests/test_check_audio.py` (**new**) | slice 10 and the icon at both scales and the contrast asserts; each failure of `check_release.py` (a second version string, a missing changelog section, a missing credit, a missing exclude); each failure of `check_audio.py` |
| Pictures (`godot/tools/ui/shot_ui.gd`, edit) | the event pop-up (plague; bankruptcy), the game-over (calendar; ruin), the Debt tab in each stage, the chips in debt, the Audio and Keys pages, text at 150 %, high contrast (the map, the Economy page with charts, a modal), a hint bubble; 1280 x 720 scale 1 and 2560 x 1440 scale 2; signed by the art director, then goldens `godot/tests/goldens/m12_*.png` (0.5 %) |

**Determinism:** `test_replay`, `test_forty_seasons`, `test_whole_property`, `test_check_contract`, `test_ai_determinism` (M8):
the incidents' roll and draw are the only luck M12 adds, taken in country id order; lists in id order; integers. **Save round
trip:** `test_snapshot`, `test_save_file`, `test_whole_saves`, `test_release_saves`, `test_season_summary` (J after a load).

### 9.2 The whole-game proofs

| Proof | What it shows | Where |
|---|---|---|
| The `whole` suite (4.15) | 100 games from Spring 1480 to Winter 1650 with no crash, every invariant, the balance gate | nightly (10 games), the release workflow (100) |
| The release saves (D46) | a save of 0.3.0 loads and plays in every later build | GUT, every pull request |
| `test_whole_italy.gd` | a short whole game on the real map ends, ranks and saves | GUT, every pull request |
| The smoke of the exported build (8.9) | the zip a player downloads plays, saves and loads | the release workflow |
| The owner's release playtest (plan section 4) | a person plays it from the pick to the game-over screen | by hand, before the draft is published |

### 9.3 The no-blocker checklist (`docs/release/0.3.0-checklist.md`, filled by J38)

| # | Item | Measured by | Passes when |
|---|---|---|---|
| 1 | No crash in long games | the `whole` suite on the release commit | 100 of 100 games end; no script error in any log |
| 2 | The rules hold | the same | every invariant of M8 to M12, every season of every game |
| 3 | The balance gate | `soak-ranges` | every range of 4.15 |
| 4 | Saves | `test_release_saves.gd`; an M11 save; a Winter 1650 save | the three 0.3.0 saves load and play; the M11 save reads "Made by an older test build"; the 1650 save opens on the game-over (from 0.3.1: the saves of the last two releases) |
| 5 | Speed | 8.7 on the reference PC and the runner; a UHD-620-class laptop for 30 minutes | every release budget; the laptop's F3 worst frame under 33 ms in normal play (or the notes name the tested GPU) |
| 6 | Memory | 8.8 in winter with preload, on the reference PC | video memory under 512 MB, RAM under 1.2 GB |
| 7 | Accessibility | `test_keyboard_reach`, `test_text_fit`, the bake's contrast asserts; the owner plays 20 seasons in high contrast at 150 % text | all green; the owner reads every screen |
| 8 | Every setting persists | `test_settings.gd`'s every-key case; the owner changes 10 options, quits, starts | equal values |
| 9 | Every screen reachable by keyboard; no stand-in | `test_keyboard_reach`; the lint's text rule (`tools/lint_godot.py`: no "TODO", "stand-in" or "placeholder" text in `shell/**/*.tscn`) | green |
| 10 | The exported build | the smokes (8.9), `check_release.py --zip` (the layout of 8.3), the checksum | `SMOKE OK` headless and windowed; the layout exact |
| 11 | Licences and credits | `check_release.py`; the credits screen | green; every section shows |
| 12 | A whole game by hand | the owner's release playtest (plan section 4) | the game-over screen reached; no crash; End season always plays or says why; every checkpoint ticked |
| 13 | Docs | `keys_table.gd --check`; the notes; `known-issues.md` | current; written; reviewed by the owner |
| 14 | The look | 8.15 | the release look signed |

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| Credit makes bankruptcies common (the AI spends to its line) | the `whole` suite's bankruptcy and debt ranges in J33, read by Opus before J37 | `credit_permille` 700, `debt_seasons` 8 (data) |
| Default is too mild: a player defaults on purpose | the release playtest; the suite's bankruptcies by option | `default_income_permille` 350, `default_seasons` 60 (data) |
| Falls snowball now that the last district can be taken | the falls and land-share ranges (J33) | `keep_last_district` true for 0.3.0 (data, S) |
| One part dominates prestige (learning late, land early) | the suite's per-part table at turns 160, 400, 684 (J33) | weights in `score.tres` (data) |
| Incidents feel like noise | the playtest; incidents a country in 100 seasons | `chance_permille` 30; `cooldown_seasons` 60 (data) |
| `Chronicle.KEEP` trims a turn's entries on Europe before the scores phase reads them | `test_score.gd` on the made-up Europe: `of_turn` returns every entry of the turn | the scores phase reads the season's events from `game.events` before the drain (S) |
| 684-season games take too long on the runners | the first nightly `whole` run (J33) | 20 legs of 5 games (CI only) |
| Memory grows over a long game | the suite's memory range | find and cap the grower (rings, chronicle) |
| Empty version fields do not fall back to the project version in 4.7.2 | J5's first day: export, read `(Get-Item Hexa.exe).VersionInfo` on the runner | the release workflow writes both fields from the project version before the export; `check_release.py` accepts only that derived value |
| ANGLE export or `fallback_to_angle` misbehave | J12's windowed smoke with `opengl3_angle` on the runner | `export_angle=0` and the native driver only; the notes say OpenGL 3.3 is required |
| A Kenney pack lacks a fitting sound (a bell, a fanfare) | J30 | another CC0 source, named in `sounds.json` and `CREDITS.md` |
| The music's rendering sounds cheap | the owner by ear (J30) | no music in 0.3.0: `audio/music` `since: "13"`, the playlist off (S) |
| 150 % text breaks layouts | `test_text_fit.gd` (J36) | the range 100 to 130 % (data in the schema) |
| Hooking every button through `node_added` costs frames | `perf_ui.gd` (J35) | `KitButton` calls `SoundBoard` through `ctx.request(&"sound")` (S) |
| Antivirus flags the unsigned exe | the release smoke on Windows Defender (the runner) | submit the file to Microsoft's analysis portal before publishing (S); signing at 0.9 |
| The owner's whole playthrough is long (684 seasons, about 8 hours) | the playtest's sittings | the checkpoints of plan section 4; nothing skipped by console in the release run |
| The look items are not signed in time | the art director's reviews of J4, J11, J16 | ship without the crest ranges (M1's relief tiles), the rest is small |
| The save promise constrains 0.3.x fixes | every pull request after the tag (D45) | an upgrade function per bump; never a refusal |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 5.3: row 8 reads "Income and upkeep (`income`), then debt (`debt`: interest, desertion, bankruptcy; `m12-build-spec.md` 4.2)"; a new row "Incidents (`incidents`): small events with choices (M12)" after research; row 12 reads "Countries that are gone (`extinction`), then scores and the end (`scores`) (M12)"; 9.2: the intro names M2 to M12, the M12 row points at this spec and its plan, "specified and planned, waits for the owner's go; starts after M11 closes"; the Europe track: E2 and E3 are M13's (`m12-build-spec.md` 8.14); "After M12" points at this spec's section 13; 11: sound and localisation are specified (`m12-build-spec.md` 6.9, 6.13), Steam comes with 0.9 |
| `docs/architecture/m2-build-spec.md` to `m11-build-spec.md` (with `m4-5-build-spec.md`) | section 12 (13 in M2), the M12 row: "taken up in `m12-build-spec.md` section 12" |
| `docs/architecture/m4-build-plan.md`, `m4-5-build-plan.md`, `m5-build-plan.md` to `m11-build-plan.md` | section 7, the M12 bullet: points at this spec |
| `docs/architecture/ui-and-controls-plan.md` | section 4: the M12 row names this spec's files and the tasks of `m12-build-plan.md`; the map-look row: decor density in M12, the rest in M14 Map look II (`m12-build-spec.md` 8.15) |
| `docs/architecture/ui-style-and-feedback-plan.md` | S5, row M12: folded into `m12-build-plan.md` (J18, J22, J26, J28, J30) |
| `docs/architecture/m1-build-spec.md` | 14: a line: the map-look items are split by `m12-build-spec.md` 8.15 (M12 and M14) |
| `docs/design/ui/design.md` | 7 and 8: sound and high contrast are specified in `m12-build-spec.md` 6.9 and D55 |
| `docs/design/ui/game-feedback-screens.md` | C.7, row M12: specified in `m12-build-spec.md` 4.12, 6.4, 6.6; the word is Prestige |
| `docs/design/reactive-prices.md` | the status line: fairs are M12's `trade_fair` incident |
| `docs/design/stop-steamrolling.md` | the status line: alliances and rebels are M15 and M16 of `m12-build-spec.md` section 13 |
| `docs/roadmap/debt-and-bankruptcy.md` | a status line: designed in `m12-build-spec.md` (option A, three settlements); loans are M18 |
| `docs/README.md` | links to this spec and its plan |

Made by the tasks (listed in the plan): `CHANGELOG.md` (the 0.3.x header and the v0.3.0 section; J5, J38), `README.md` (the
0.3.0 section and the generated controls table; J34), `CLAUDE.md` (the commands of 8.11; J34), `godot/README.md` (J31, J34),
`godot/data/README.md` (J6), `godot/CREDITS.md` (J32), `.github/workflows/godot.yml` and `release.yml` (J12, J33),
`tools/lint_godot.py` (the scene text rule; J36). No port rule changes: no new autoload (the sound board and the hint layer are
App children), no new layer; new files sit in listed folders, each under 800 lines (`debt.gd` about 500, `incidents.gd` about
450, `event_popup.gd` about 350, `app.gd` held under 800 by `smoke_run.gd` and `leave_rules.gd`).

---

## 12. What M12 takes from earlier milestones (the hand-off ledger)

Every hand-off, "left for M12", "M12 adds/owns" and deferral line of the standard, the M1 to M11 specs and plans, the UI
documents and the design pages, and what closes it. A row closed by "section 13" names the after-M12 milestone that owns it.
The ledger was checked twice against `grep -n "M12"` over `docs/architecture`, `docs/design` and `docs/design/ui`, and against
the hand-off sections of every spec and plan.

| # | Item | From | Closed by |
|---|---|---|---|
| 1 | Debt and bankruptcy | standard 9 (M12), 5.3 row 8 | D6 to D21, 4.1 to 4.4; J7, J13 |
| 2 | Countries that fall ("countries that are gone") | standard 9, 5.3 row 12 | D22 to D26, 4.5; J8 |
| 3 | Score and the end | standard 9, 5.3 row 12 | D27 to D32, 4.6, 4.7; J9 |
| 4 | The Audio and Keys option pages | standard 9, 9.1 | 6.7; J27, J28 |
| 5 | Text size and high contrast | standard 9.1 | D54, D55; J22, J27 |
| 6 | Event pop-ups | standard 9.1 | D33 to D39, 6.3; J10, J24 |
| 7 | Tutorial hints | standard 9.1 | D56, 6.8; J29 |
| 8 | Final credits | standard 9.1 | D59, 8.12; J32 |
| 9 | Sound ("not covered: sound") | standard 9, 11 | D57, D58, 6.9; J28, J30 |
| 10 | The game-over and score screen | standard 9.1 | D71, 6.5; J25 |
| 11 | Score in Rankings; the Debt tab | standard 9.1 | 4.12, 6.4, 6.6; J18, J26 |
| 12 | Old saves keep loading from the first public release; CI checks saves kept from each release | standard 5.5 | D45 to D47, 8.6; J21, J38 |
| 13 | Localisation ("not covered") | standard 11 | D60, 6.13; section 13 (M27) |
| 14 | Steam integration ("not covered") | standard 11 | D73; section 13 (M26) |
| 15 | The Europe track: E2's map, E3's measure and the switch | standard 9.2 | D3, D4, 8.14; section 13 (M13) |
| 16 | "After M12, in an order the owner picks" | standard 9.2 | section 13 |
| 17 | Performance measured before each release | standard 6 | 8.7; J20, J38 |
| 18 | The map-look milestone "before the first public release": shoreline, ranges along crest chains, ground shader, trees one by one, bridges and road style | `m1-build-spec.md` 14 | D5, 8.15: ranges J11; the rest section 13 (M14) |
| 19 | Spring and autumn are "still stand-ins from the kit's palettes" | `m1-build-spec.md` 12.8 | 8.15; J16 |
| 20 | The rebinding page (the file format exists) | `ui-and-controls-spec.md` 4.1, 6.4; plan 5.3 | D52, 6.7; J27 |
| 21 | The panel's build list by number keys | `ui-and-controls-spec.md` 4.5, 6.5 | D53; J27 |
| 22 | "Ask before losing progress" (always on until M12) | `ui-and-controls-spec.md` 6.6 | D51, 6.11; J31 |
| 23 | Hints, Off, Basic, All | `ui-and-controls-spec.md` 6.6 | D56; J27, J29 |
| 24 | Volumes master, music, effects, ambient; mute in the background | `ui-and-controls-spec.md` 6.6 | D57, D58, 6.7; J27, J28 |
| 25 | The Options pages Audio and Keys | `ui-and-controls-spec.md` 6.7 | 6.1, 6.7; J27 |
| 26 | Developer tools "On until M12"; the sandbox behind it; the sandbox "the developer's map tool until M12" | `ui-and-controls-spec.md` 5.1, 6.7, 11 Q11; `m2-build-spec.md` D9 | D50, 6.11; J17, J31 |
| 27 | `Confirm` used for "events (M12)" | `ui-and-controls-spec.md` 5.3 | D38: events use `EventPopup`, not `Confirm`; 6.12; J24, J31 |
| 28 | Tutorial hints "anchored to Controls by node path, from a hint table (`.tres`)" | `ui-and-controls-spec.md` 7 | 6.8; J29, J36 |
| 29 | The map-look row: decor density, water and coast animation, a 2x bake for Retina, mipmaps | `ui-and-controls-plan.md` 4; spec 6.3, 8, 11 Q9 | D5: decor density J4; the rest section 13 (M14) |
| 30 | `graphics/decor_density` with `since: "12"` in the code | `godot/shell/app/settings.gd` | 8.15; J4 |
| 31 | The M12 UI files: `event.*`, `game_over.*`, options pages, `default_bus_layout.tres`, `build_theme.gd --high-contrast` | `ui-and-controls-plan.md` 4 | 6.3 (`event_popup.*`), 6.5, 6.7, 6.9; `build_theme.gd` already writes both themes, so no flag; J3, J22, J24, J25, J27, J28 |
| 32 | The high-contrast row ("the player's row arrives in M12"); charts follow the Theme | `ui-style-and-feedback-spec.md` 4.9 | D55; J22, J27 |
| 33 | Economy's Debt tab; Rankings' score; "M12 adds score, the Debt tab, text size, the high-contrast row, sounds" | `ui-style-and-feedback-spec.md` 8, 10 | 4.12, 6.4, 6.6, D54, D55, 6.9 |
| 34 | S5 M12: score in Rankings; the Debt tab; debt and score report lines; the high-contrast row; text size in charts; `seal_cracked`; sounds | `ui-style-and-feedback-plan.md` S5 | 4.12, 6.4, D54, D55, D77, 6.9; J18, J22, J26, J28, J30 |
| 35 | Sound: paper slide, quill tick, seal thud, page turn, coin | `docs/design/ui/design.md` 7 | 6.9's list |
| 36 | The high-contrast theme: flat boxes, black fields, white text, 2 px borders, a 3 px focus ring | `docs/design/ui/design.md` 8 | D55 (kept as built in S0, with the inks) |
| 37 | Standing: "score M12" | `game-feedback-screens.md` A.2 | 4.12 `standing` |
| 38 | "Debt 240: interest ▼ −5." "Score 48 ▲ +2, 3rd of 6." | `game-feedback-screens.md` A.4 | 4.12 (the word Prestige) |
| 39 | Text size "reflows the vellum and the chart fonts" | `game-feedback-screens.md` D.4 | D54; J22, J36 |
| 40 | C.7 M12: score in Rankings, the Debt tab, text size and high contrast in charts | `game-feedback-screens.md` C.7 | as rows 33, 34 |
| 41 | `Country.alive` and "is no more" | `m2-build-spec.md` 13 | D24, 4.5; J8 |
| 42 | Colour-blind colours for countries that appear in play | `m2-build-spec.md` 13 | D25; section 13 (M16) |
| 43 | "No sea war before M12"; a sea owner layer | `m2-build-spec.md` D5 | section 13 (M19) |
| 44 | Tribes and unowned land wait for colonies | `m2-build-spec.md` 4 | section 13 (M21) |
| 45 | The owner byte (1 to 254) | `m2-build-spec.md` D4 | Europe has about 60 countries: it stays one byte; M13 checks it (section 13) |
| 46 | "The game is over" after Winter 1650 in `Season.end_check` | `m3-build-spec.md` D3, 4.2, 12 | D32, 4.7; J9, J14 |
| 47 | `OLDEST_FORMAT` frozen; CI loads saves kept from each release | `m3-build-spec.md` D31, 12 | D45, D46; J21, J38 |
| 48 | `seal_cracked` | `m3-build-spec.md` 12 | D77, 6.5, D55; J25, J26 |
| 49 | Score rows | `m3-build-spec.md` 12 | 4.12; J14 (the series), J18 |
| 50 | The report's "M4 to M12 sections" | `m3-build-spec.md` D28 | D77: lines, no new section; J18 |
| 51 | `stats` after the scores | `m3-build-spec.md` 4.2 | 4.10 |
| 52 | The player's country dies (no rule) | the M3 table's gap | D26, 4.7 |
| 53 | After a release: `other_build` on a scenario fix; "damaged" after an upgrade | `m3-build-spec.md` 4.10 | D47, 8.6; J21 |
| 54 | The release's version (the header's `build`) | `m3-build-spec.md` 4.10 | D2, 8.1; J5 |
| 55 | `debt_limit`, interest (`WHY` `interest`), bankruptcy | `m4-build-spec.md` D19, 4.17, 12; plan 7 | D7 to D13, 1.2; J2, J7, J13 |
| 56 | The Debt tab | `m4-build-spec.md` D41, 6 | 6.4; J26 |
| 57 | The Prestige chip (icon baked in M4) | `m4-build-spec.md` 1.2, 6.2, 12 | D27, D79, 6.4; J26 |
| 58 | `treasury_empty`'s words; a free clear refused below zero | `m4-build-spec.md` 4.18 | 1.2, 4.12; J7, J18 |
| 59 | Score in Rankings; `PageEconomy.TABS` `debt` without a scene | `m4-5-build-spec.md` D2, 12; plan 7 | 1.2, 6.4, 6.6; J18, J26 |
| 60 | Text size and high contrast in charts | `m4-5-build-spec.md` 12 | D54, D55; J22 |
| 61 | `since` compared as text | the M4.5 gap | D49; J15, J17 |
| 62 | Rankings equals the report's Standing | `m4-5-build-spec.md` done-when 5 | 1.2 (interest), 4.12; J18 |
| 63 | Score with people (v0.2.2's people / 20) | `m5-build-spec.md` 12; plan 7 | 4.6 people |
| 64 | Plague and famine as event pop-ups (flows appended) | `m5-build-spec.md` 12 | D37, 4.8; J2, J10 |
| 65 | Countries that fall when their people do | `m5-build-spec.md` 12 | D22 |
| 66 | Desertion through `Armies.lose_men` (`deserted`) | `m6-build-spec.md` 12; plan 7 | D11, 4.2; J7 |
| 67 | Bankruptcy disbands | `m6-build-spec.md` 12 | 4.3 (pay with the army); J7 |
| 68 | Score with men under arms | `m6-build-spec.md` 12 | 4.6 arms |
| 69 | A forced disband outside one's land (M6's `disband_check` refuses) | the M6 gap | D11: desertion is `lose_men`, men lost, not `disband` |
| 70 | Ships and fog of discovery after M12 | `m6-build-spec.md` D4, D34 | section 13 (M19, M20) |
| 71 | Countries that fall: a war ends with its side | `m7-build-spec.md` 12; plan 7 | D24 |
| 72 | Desertion | `m7-build-spec.md` 12 | D11 |
| 73 | Score with battles | `m7-build-spec.md` 12 | 4.6 deeds (the game's prestige; M9 owns the war score) |
| 74 | The battle board, field forts | `m7-build-spec.md` D5, 12 | section 13 (M24) |
| 75 | Refugees (none in M7, D28) | `m7-build-spec.md` D28 | section 13 (M16) |
| 76 | `how: peace` "is reserved" | `m7-build-spec.md` 4.11 | stays reserved for alliances' per-ally peace (M15) |
| 77 | Debt and bankruptcy in the AI's money | `m8-build-spec.md` 12; plan 7 | D41, D42, 4.9; J23 |
| 78 | Seats that fall | `m8-build-spec.md` 12 | 4.5 (seats are living); J23 |
| 79 | A difficulty as an `AiDef` scale on the New game page | `m8-build-spec.md` D29, 12 | D40: none (the owner's decision) |
| 80 | The full-length soak to 1650 ("680 seasons") | `m8-build-spec.md` 12 | D68, 4.15 (684 seasons); J33 |
| 81 | The old-saves check | `m8-build-spec.md` 12 | D46; J21 |
| 82 | Caps in long games; `Chronicle.KEEP` | `m8-build-spec.md` D51 | D75 |
| 83 | `keep_last_district` off; `Countries.fall`; wars ended with terms `fallen` | `m9-build-spec.md` D25, 12; plan 7 | D23, D24, 1.2; J1, J2, J6, J8 |
| 84 | `declare_war_check`'s debt row after row 9 | `m9-build-spec.md` 12 | D17 (row 9a); J13 |
| 85 | Tribute and surrender never push a treasury below 0 | `m9-build-spec.md` 12 | D19 |
| 86 | Infamy and weariness for the score | `m9-build-spec.md` 12; plan 7 | D28 (infamy), D30 (weariness not) |
| 87 | A difficulty that may scale `enforce_net` | `m9-build-spec.md` 12 | D40 |
| 88 | Alliances, rebels and free states, historical claims | `m9-build-spec.md` D33, D52, D53 | section 13 (M15, M16, M17) |
| 89 | Humiliate, defence, a non-aggression pact, city-state protection | `m9-build-spec.md` D2; `stop-steamrolling.md` B | section 13 (M15; M23) |
| 90 | A dead country's "later rebirth"; the court building | `m9-build-spec.md` 12, D42 | section 13 (M16) |
| 91 | `fallen` missing from `TERMS`, `truce_of`, `War.terms`, `Words.terms_text` | the M9 gap | 1.2; J1, J2, J8, J15 |
| 92 | The `peaces` invariant | the M9 gap | 1.2; J33 |
| 93 | A dead league member | the M9 gap | D24 (`Coalitions.drop`); J8 |
| 94 | Purchases and merchants' losses in the debt rules | `m10-build-spec.md` 12; plan 7 | D20 |
| 95 | No buying over the debt limit | `m10-build-spec.md` 12 | D20, 1.2 (M10's own rule) |
| 96 | Orders home at bankruptcy | `m10-build-spec.md` 12 | D15; J2 (`WHY`), J7 |
| 97 | A fallen country's orders and pacts end | `m10-build-spec.md` 12 | D24; J8 |
| 98 | `income_trade` and the markets held for the score | `m10-build-spec.md` 12 | 4.6 wealth (income has trade) and markets |
| 99 | Trade fairs as an event kind ("after M12" in D24 and 1.3) | `m10-build-spec.md` 12, D24, 1.3 | D36, 1.2; J10 |
| 100 | "M12's ways out may add a switch" (buying) | `m10-build-spec.md` D57 | 1.2: no switch |
| 101 | The tolls change T4 "revisit after T1 and T2" | `m10-build-spec.md` 1.3 | J37 reads the trade-share range and decides it (data) |
| 102 | Sea routes, river boats, colonial markets, the price revolution, trade companies, pact offers to the player, roads in reach fields | `m10-build-spec.md` 12, D10, D39 | section 13 (M19; M15; M18) |
| 103 | Luck for market events | `m10-build-spec.md` D60 | D33, D80 (the incidents carry luck) |
| 104 | The score's research part: `known_points`, `techs`, `era`, `era_turns` | `m11-build-spec.md` 12; plan 7 | 4.6 learning, `deeds_era`; J9 |
| 105 | The end at 1650 with no era after the third | `m11-build-spec.md` 12 | D32 |
| 106 | `fund_research_check`'s debt row | `m11-build-spec.md` 12 | D18; J13 |
| 107 | Generals dismissed at bankruptcy | `m11-build-spec.md` 12 | D15; J7 |
| 108 | The idea pick stays its own decision screen | `m11-build-spec.md` 12 | 6.3 (the pop-up is for incidents and bankruptcy only) |
| 109 | The `research` suite to 681 seasons as the whole-game rig | `m11-build-spec.md` 12 | D68: the `whole` suite (684); `research` stays 440 |
| 110 | Ships, colonies, battle cards, drill, characters, Bourse's price swing | `m11-build-spec.md` 12, D33 to D35 | section 13 (M19, M21, M24, M25) |
| 111 | The debt roadmap's open questions (loans, penalties, creditors, duration, carry-over) | `docs/roadmap/debt-and-bankruptcy.md` | D6, D13, D14, D15; loans section 13 (M18) |
| 112 | "The bankruptcy pop-up and the events system share the revolt choice's frame" | `stop-steamrolling.md` 8 | D38 (one frame; M16's revolts reuse `EventPopup`) |
| 113 | Fairs "after M12" | `reactive-prices.md` | D36 |
| 114 | "No difficulty setting" | `achievements.md` (owner, 2026-11-13) | D40 |
| 115 | Spending only from a positive treasury (M4 D19) | `m4-build-spec.md` D19 | D10, 1.2 |

---

## 13. After M12: the roadmap

The standard's list, the items M9, M10 and M11 moved after M12, and the items this page parks. **The owner picks the order**
(standard 9); the numbers below are the recommended order and are names until a milestone starts. Sizes are rough, in
worker-days of building (specs, reviews and playtests on top). No spec is written here.

| Milestone | What it adds | What it needs from the code | Size | Python reference (v0.2.2) |
|---|---|---|---|---|
| **M13 Europe** (0.4.0) | E2's real 28 km Europe map file; a Europe 1480 scenario (about 60 countries); E3's measure and the switch (8.14); markets, regions, national techs and creditors for Europe; `MapData.fertility` and `ore` decided (M4 D27) | `tools/build_map.gd` and `core/mapgen` on `data/geography/*.json` and the heights; `ScenarioGrowth`, `build_scenario.gd`; M9's `regions.json`; M10's market rule; M11's national techs; M8 8.2's `perf_core.gd --ai-map`; the owner byte (stays 8-bit) | 35 | `hexa/campaign/geo.py`, `systems/worldgen.py`, `data.py`, `placenames.py`, `regions.py`, `naming.py` |
| **M14 Map look II** | the real shoreline as chunk meshes (Genoa's bay, the capes), a ground splat shader with slope shading, trees one by one, the bridge and road restyle, water and coast animation, a 2x bake for Retina, mipmaps | `MapData.shoreline`, `height_grid` (M1 14), `TileMapView`, `EdgeLineLayer`, `MapCells`, the tile bake; E1's budgets | 25 | `tools/worldmap/` (the style frame's `render.py`, `frame_bake.py`), `hexa/campaign/landscape.py`, `nature.py` |
| **M15 Alliances and calls to arms** | alliances, calls to arms, per-ally peace, military access, non-aggression pacts, humiliate and defence terms, pact offers to the player (M10 D39), trade clauses | `Peace.apply` per war side, `BattleView` sides as lists, `RelationBook`, `DecisionQueue`, `Movement.open_to`, `TradePacts`, `how: peace` | 30 | none (`war-goals-and-peace.md` 3.10, `stop-steamrolling.md` Part B) |
| **M16 Rebels and free states** | revolts on the defiant band, independence, free states, a fallen country's rebirth, the court building, refugees, colour-blind colours for new countries (M2) | M9's unrest bands, `gained`, `former`, regions; `Countries` gaining ids (the owner byte, `Stats` tags, `unrest_bands` sizing); `EventPopup` for the revolt choice | 30 | none (`stop-steamrolling.md` Part C) |
| **M17 Historical claims** | the `claim` reason, a claims table, bought claims | M13's Europe; `WarGoals` reasons; M9's reconquest | 10 | none (`war-goals-and-peace.md` 3.9) |
| **M18 Crown projects and loans** | the four crown projects (Bank, Court, Cathedral, Royal road); loans (the debt's option B: lenders, rates, terms, a credit rating); selling a building | `Debt`, `Treasury`, `Score`'s treasury part, `Works`, M10's reach fields for the Royal road | 20 | none (`crown-projects.md`, `debt-and-bankruptcy.md`) |
| **M19 Ships, sea war and sea trade** | ships as kinds, movement and sight at sea, naval battles, blockade, sea routes, port capacity, river boats, overseas markets, the sea owner layer (M2 D5), Navigation's ship rows (M11), the price revolution, trade companies | `UnitDef`, `StepCosts` at sea, `Movement`, `Combat`, `Trade` (routes), `ModKeys` rows | 45 | `systems/movement.py` (naval, `aboard`), `military.py`, `combat.py`, `trade.py` (`sea_walk`), `data.py` |
| **M20 Exploration and fog of discovery** | an unknown map that is explored, fog of discovery, maps as knowledge | `Vision.explored` (M6), `Knowledge`, the sight veil, `MapModes` | 15 | `systems/season.py` (`explore_home`, `see_from`, `explore_all`), `world.py` (`known_world`), `mapview.py` |
| **M21 Colonies** | founding, settlers, natives, colonial markets, Town charters' colonial rows | M19, M20; unowned land and tribes (M2); M10's markets | 30 | `systems/colonies.py`, `data.py` (`COLONY_*`), `systems/worldgen.py` (tribes) |
| **M22 Random worlds** | a generated world and its countries and names | `core/mapgen`, `fake_map.gd`'s successor, `FakeScenario`, regions for random worlds | 25 | `randomgeo.py`, `regions.py`, `naming.py`, `wfc.py`, `wfctiles.py` |
| **M23 City states** | a city-state kind with its rules and soft cap, buying small city states, protection | `Countries`, `CountryDef`, `Peace` deals, M15's protection | 15 | none (`city-states.md`) |
| **M24 The battle board and field forts** | the 0.2.3 mini game between days (width 3 to 7, back slots, rotation, cards), battle cards from techs, drill at barracks, field forts | `Combat.fight` and the records (M7), `ModKeys` (M11) | 30 | `screens/battle.py`, `battlelayout.py`, `systems/battle.py`, `combat.py`, `battlelog.py` |
| **M25 Characters** | named generals and rulers with lives, experience and death | `Army.general` (M11), `TraitDef` | 15 | `systems/military.py` (generals) |
| **M26 Achievements and Steam** (0.9) | the twelve first achievements, Steam integration, code signing revisited | `Game.dev_used` (M12), the chronicle, the release workflow | 15 | none (`achievements.md`) |
| **M27 Localisation** | a second language | `Words`, the `.tres` names, the scenes (6.13) | 10 | none |
