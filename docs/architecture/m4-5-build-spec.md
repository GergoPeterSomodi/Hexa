# M4.5 build spec: Insights I

Game and UI designer (Opus), 2026-11-17. **Status: a proposal, design only; it waits for the owner's go.** Builds
milestone M4.5 of `docs/architecture/godot-architecture.md` (the standard) on the M1 build spec (`m1-build-spec.md`), the
M1.5 UI foundation (`ui-and-controls-spec.md`, `ui-style-and-feedback-spec.md`), and the M2, M3 and M4 specs and plans
(`m2-build-*.md`, `m3-build-*.md`, `m4-build-*.md`). Where this page is more exact it wins for M4.5; section 1.2 lists
every place where it refines an earlier page. The tasks are in `m4-5-build-plan.md`. This page carries the M4.5 part of the
style spec's section 8 (the study's pages) and its section 10 row, and slice S4 of `ui-style-and-feedback-plan.md`.

**What M4.5 is.** The owner asked to look into the economy "as in Civ": pages, not tooltips. M4 left the money and goods
in saved stores (`Stats` rows, the closed ledgers, the goods ring, the chronicle) and one what-if (`EconomyPreview`). M4.5
reads them. The Statesman's Study gains Economy's **Districts**, **Goods** and **History** tabs, a **Rankings** page and a
**History** page with a timeline and the chronicle. The map gains the **Yields** mode (key 4): your land coloured by what
each district earns in a year. The chart and table kit is completed (`InkChart`'s other kinds, `StudyTable`,
`TimelineStrip`). Older season headers in the action log open the History page at that season.

**No new game rules.** M4.5 adds no action, no season phase, no state field, no event kind, no definition and no save
format change. Its code lives in `core/views/` and `shell/`; the only edit elsewhere in `core/` is a pair of read-only
accessors on `Stats` (5.2). Opening a page, a tab, a chart cursor or the Yields mode never changes the game: a test opens
every one of them and finds `Game.digest()`, `Game.version` and the whole snapshot unchanged, and two games, one browsed
and one not, give the same digest eight seasons later (9, `test_study_readonly.gd`).

**When it starts.** After M4 is closed (its plan's definition of done, and the owner has played it). M4.5 edits views and
screens M2 to M4 deliver: `EconomyPreview`, `StudyEconomy`, `LogLines`, `MapModes`, `HexCard`, `InkChart`, the study
frame and its Economy page, the mode overlay, the map scene, the top bar, the action log, the App's requests.

**M4.5 is done when:**

1. **Five questions, each in under a minute.** The owner answers the five questions of 4.11 from the study, timed with a
   stopwatch from the bare map, each under 60 seconds (the plan's playtest). `tests/shell/test_five_questions.gd` plays the
   same five paths on the calm fixture through the App and reaches each answer in at most four inputs (keys or clicks).
2. **A page opens in under 16 ms.** `godot/tools/ui/perf_ui.gd` on the CI runner (xvfb, Mesa) measures from the input that
   opens a page or tab to the end of the first frame that shows it (`RenderingServer.frame_post_draw`): every M4.5 page and
   tab under 16 ms on the 1480 scenario after 40 seasons with cold caches, and on the made-up Europe (60 countries, 40
   seasons, its largest country) after `StudyWarm` ran. The pure views' rows in `perf_core_budget.json` hold nightly (8).
3. **Others' numbers only for known countries.** Rankings lists only you and the countries `Knowledge.knows`, their values
   banded by `Knowledge.band`, and counts the rest ("10 countries unknown"); History shows only what `Knowledge.witnessed`
   allows; Districts, Goods, the Yields mode and the hover card's Worth line read only your own land. Each has a test with
   a planted fault (9).
4. **No new rules** (above): `test_study_readonly.gd` and `test_insights_views.gd` green; `Season.PHASES`,
   `Actions.NAMES`, `SaveFile.FORMAT`, `Stats.SERIES`, `Chronicle.NOTABLE`, `Treasury.WHY` and `Stores.FLOWS` are those of
   M4 (pinned again by `test_insights_views.gd`).
5. **One number, one source.** Districts' "This season" equals M4's `EconomyPreview.worth_by_hex`; each History-tab season's
   lines add up to its change; Goods' "Lasts" equals the season the money reminder names; Rankings equals the report's
   Standing, every season of a 40-season run (9).
6. Every M4.5 UI row of the standard's 9.1 is in the game, built from the kit, each with its GUT test: Economy's Districts,
   Goods and History tabs; the Rankings page; the History page; the Yields mode (key 4, the top bar's switch, its legend,
   the hover card's Worth line, the minimap); `InkChart` complete; `StudyTable`; `TimelineStrip`; older log headers open
   History. No stand-in is left.
7. Lint, import, check_scripts and GUT are green, with both UI `--check`s (unchanged: M4.5 adds no texture, token or
   variation) and `build_scenario.gd --check`; the art director has signed the pictures of section 9; the owner has played
   the build through the plan's checklist.

---

## 1. What is there, and where this page refines earlier pages

### 1.1 Read in the code (master `860f802`), the mockup and the specs

| Finding | Where | What it means for M4.5 |
|---|---|---|
| The Theme already has the type `InkChart` (`ink_0` to `ink_4` from the five chart inks, `axis`, `grid`, `good`, `bad`, each with a `_slot` form, font `Hint`) and the variation `StudyTree` (headers `TableHeader`, rows `TableRow`, `ROW_HOVER`, `LINE` guides) | `shell/ui/tokens.gd` (K1, K7), `shell/ui/theme.tres` | M4.5 adds no variation, colour or texture: both UI `--check`s stay as they are |
| `Tokens.CHART_CUES`: each ink has a dash (`solid`, `dash`, `dotted`, `dash_dot`, `long_dash`) and a marker (`dot`, `square`, `triangle`, `diamond`, `cross`) | `shell/ui/tokens.gd` | The second cue of a series; M4.5 adds a fill cue for bars in the same order (6.2) |
| Kit icons exist: `arrow_up`, `arrow_down`, `dash`, `tick`, `cross`, `info`, `study`, `zoom_*`; M4's bake slice 4 adds the goods, money, land, season and screen icons (`go`, `warning`, `district`, `settlement`, `tax`, `spending`, `chart`) | `shell/ui/theme.tres`, `m4-build-spec.md` 6.2 | Table cells, timeline marks and the legend take their icons from the Theme, never a file |
| `Segmented` (`set_options`, `select`, `selected_id`, signal `changed`), `KitButton` (`set_verdict`, `cost_text`, `hotkey_action`), `KeyCap`, `Screen`, `ScreenStack`, `ScreenIds` (`study` registered), `Motion.cross_fade` | `shell/ui/`, `shell/screens/screen_ids.gd` | Exist; used as they are |
| `Bindings.DEFAULTS` holds `study_tab_prev` and `study_tab_next` (Ctrl+`[`, Ctrl+`]`, `since: "4.5"`), `view_mode_4` (key 4, `since: "2"`, "Map mode 4"), `game_study` (I), `game_ledger` (L), `study_page_prev`, `study_page_next` | `shell/input/bindings.gd` | M4.5 adds no binding; `MapInput` maps `view_mode_4` to Yields (6.7) |
| `Settings.SCHEMA` holds `state/study_span` (12 or 40, default 12, `since: "4.5"`) and `state/study_page` (economy, rankings, history, people, military, diplomacy, trade, research) | `shell/app/settings.gd` | M4.5 adds no key; `state/map_mode` (M2) gains the choice `yields` |
| `UIHarness` (`mount`, `send_key`, `send_click`, `wait_frames`, `shot`) | `tests/shell/ui_harness.gd` | The five-questions and read-only tests drive the App with it |
| Godot 4.7.2 has `TreeItem.set_custom_draw_callback(column, Callable)`, `TreeItem.add_button`, the `Tree` signals `column_title_clicked(column, mouse_button_index)`, `item_activated`, `item_selected`, `button_clicked`, and `Control.accessibility_description`, `_make_custom_tooltip`, `_get_tooltip` | the engine's class reference (`godot --doctool`, read for this page) | `StudyTable` is a `Tree` with custom-drawn spark and bar cells (6.2) |
| The mockup's M4.5 study: pages Economy, Rankings, History; Economy tabs This season, Districts, Goods, History; Districts columns Place, Use, Level, Gain a season, Upkeep; Goods columns Good, Stock, Change, Made, Used; the History tab "Treasury, last 40 seasons (a row a year before that)"; Rankings two ranked lists side by side, "Only the 6 countries you know. 2 countries unknown. Their numbers are rounded."; History a tick a season, filters All, War, Money, Works, Mine, rows with a Look button | `docs/design/ui/studiolo/hexa-ui-mockup.html` (lines 1170 to 1229), `study_econ.jpg` | The layout this page builds; the columns are refined in 1.2 |
| Built by M1.5 to M4 and named "(M2)", "(M3)", "(M4)" or "(M1.5)" below: `MapModes`, `ModeOverlay`, `ColourContrast`, `Countries`, `Territory`, `Stats`, `StatsSystem`, `Chronicle`, `Knowledge`, `Words`, `WorksView`, `LogLines`, `SeasonSummary`, `Reminders`, `ViewCache`, `Snapshot`, `SaveFile`, `Calendar`, `Economy`, `EconomySeason`, `Treasury`, `Stores`, `EconomyPreview`, `StudyEconomy`, `InkChart`, `HoverCard`, `NavList`, `DeltaChip`, `Study`, `StudyPage`, `StudyPages`, `PageEconomy`, `ResourceChips`, the action log, `GameRequests`, `perf_core.gd`, `perf_ui.gd`, `shot_ui.gd` | their specs | M4.5 starts after they exist |

### 1.2 Refinements (decided here)

| Earlier page | M4.5 | Why |
|---|---|---|
| Style spec 8: Rankings "ranked bars for land and income; your line through time" | One page, no tabs: two ranked lists side by side (the mockup's layout), each a `StudyTable` with a bar column, and under each a line chart of your value with marks where your rank changed (4.6) | The mockup's page; a table sorts and takes the keyboard; the line answers "has my place changed" |
| Style spec 8: Economy History "12 or 40 seasons, stacked in and out" | The same chart, plus a second chart: the treasury at each year's end from the year rows (the mockup's caption "a row a year before that"); the two never share an axis (4.5) | Year rows keep only the winter row: a stock (the treasury) is right at a year's end, a flow (an income) is not |
| Mockup Districts columns Place, Use, Level, Gain a season, Upkeep | Place, What, Gives a year, This season, A year, Upkeep a year, Seasons (a spark of the four seasons) (4.3) | Output changes by season (M4 D4): ranked by one season, a vineyard is last in spring and first in autumn. "Use" and "Level" read as one phrase ("vineyard, second stage") |
| Mockup Goods columns Good, Stock, Change, Made, Used | Good, In store, Change, Made a year, Used a year, Lasts, Store (a spark) (4.4) | The question the tab answers is "which good runs short" |
| Style spec 5: `InkChart` | Adds `legend`, a cursor (`set_cursor`, `cursor`), a fill cue per series for bars, and the static drawing helpers moved to `InkMarks` (6.2) | Five stacked series need a second cue besides the ink; table cells draw sparks with the same code |
| Style spec 5: `StudyTable` | Adds the column kinds `delta`, `bar`, `spark` and `button`, 100 rows at a time with "show more", sorting by keyboard (Ctrl+arrows), `row_selected`; drops `sort_changed` (the table keeps its own sort and nothing else needs to hear it) (6.2) | Europe's largest country holds hundreds of districts; the UI spec's addendum asks for keyboard play of every screen |
| Style spec 8: History "timeline (a tick a season; marks for works, wars, eras)" | `TimelineStrip`, a new kit piece; one mark a season, by a fixed priority (4.7, 6.2) | No kit piece drew a timeline |
| UI spec 4.1 and `m2-build-spec.md` 7.1: `view_mode_4` is Supply (M6) | **Key 4 is Yields from M4.5**; later modes take the next keys in the order they arrive: M5's mode 5, M6's Supply 6 (each milestone adds its `view_mode_<n>`) (D15) | Modes take keys in the order they arrive; Yields arrives first. Both pages are edited (section 11) |
| `game-feedback-screens.md` B.1 and style spec 7.4: Yields is "M2's overlay tinting the district and its ring by gain" | The Yields mode colours your land by worth a year in nine bands; the works card keeps M4's `PreviewMarks` tint (4.8) | The mode answers "which district earns"; the card answers "what this work changes" |
| `m4-build-spec.md` 6.3: the Stores chip opens the study's Economy page | It opens Economy, **Goods** | The stores are that tab |
| `m3-build-spec.md` 6.5: older log headers are plain text until M4.5 | They open the History page at that season (6.8) | Style spec 6.4 |
| Style spec 8: read models "cached by `(game.version, tag)`" | Kept; plus `StudyWarm`, which fills those caches one view a frame after a season, so a page opens warm on Europe (D29) | 16 ms on the 60-country map |
| `m4-build-plan.md` W4: `InkChart`'s first two kinds, no word of marks | `set_marks` drawn on `LINE_BARS` belongs to M4 (its This season chart has marks, `m4-build-spec.md` 6.7); W4's done-when is edited (section 11) | M4's own page needs them |

---

## 2. Decisions taken

Each is decided. "Reverse" is the cost to change it later (S half a day, M a day, L two or three days).

| # | Question | Decision | Why | Reverse |
|---|---|---|---|---|
| D1 | Scope | **No new game rules** (above). Views and screens only; a pair of read-only accessors on `Stats` | The standard's 9 row: "keep the figures; improve: the owner reads them as pages" | none |
| D2 | Pages and tabs in M4.5 | Economy: This season (M4), **Districts, Goods, History**; Debt stays hidden (M12). **Rankings** (no tabs). **History** (no tabs). Nav order Economy, Rankings, History; later pages are inserted in the mockup's order (Trade, Diplomacy, Military, People, Research before Rankings) | Style spec 8; the mockup | S |
| D3 | What a district earns | M4's **worth** (`m4-build-spec.md` D34, 4.17): goods at the fixed price, port dues and its people's taxes, less upkeep and walls, floored per place. Shown **this season** (M4's `worth_by_hex`) and **a year** (the four seasons from now, as `EconomyPreview.with` runs them: calm, works under way standing from their ready turns) | One number with Earns most, the card and Yields | S |
| D4 | Rows of the Districts table | Every hex of yours with a piece (a district, a town, a castle); wild land is **one summary row**, never a row a hex | Nine wild woods in a list hide the five districts that matter | S |
| D5 | "Lasts" of a good | From `EconomyPreview.with(game, tag, {}, 8)`, the money reminder's run (M4 4.18): the first season k (1 to 8) whose need is not fully met; "none left" when k = 1 and the stock is 0, "this season" when k = 1, "in k seasons", "over 8 seasons", "—" for a good no town needs | The reminder's own number: the tab and the task flag never disagree | S |
| D6 | History of money | Flows (incomes, upkeep, spending, goods made and used) come from the **40-season ring** only, in spans of 12 or 40 seasons. Before the ring, the **year rows** give the treasury and land at each year's end, drawn on their own chart. Yearly sums of money are not kept (Stats keeps the winter row of a year, `m3-build-spec.md` 4.6) and are never shown | A winter's incomes are not a year's | M (a yearly-sum series and a save change) |
| D7 | A season's opening treasury | The previous ring row's closing; for the oldest row in the ring (and turn 1), the closing less the season's lines | Stats keeps closings, not openings; a ring row is always whole | S |
| D8 | What "Your spending" was | The chronicle's `work_started` entries of the season with their `work.paid`, less `work_cancelled` refunds; when the chronicle has dropped them (3,000 newest), "works begun (no longer in the chronicle)". Developer money (`Game.dev_money`, M4) shows as **Other (developer)**: the change less every line | `Stats.spending` is one number; the chronicle names the works | S |
| D9 | Rankings' measures | **Land** (`Stats` `land`: land hexes held, the report's "districts") and **income** (the season's money in less upkeep: `income_people + income_goods + income_dues + income_trade − upkeep_districts − upkeep_walls − upkeep_army`, which is M4's `Treasury.left_over` of the closed ledger), both of the **last season ended** | The report's Standing uses these (M4 4.19): one source | S |
| D10 | Whom Rankings shows | You and `Knowledge.known(game, you)`; others' values `Knowledge.band`ed ("about 58", "about +240"); ranks from the exact values, ties by country id, as M4's Standing; a line "10 countries unknown" (`Knowledge.unknown_count`) | Style spec decision 4; M4's Standing does the same | S |
| D11 | Your line through time | A line of your value a season over the span, a dashed line of the largest known other's banded value, and a mark where your rank changed ("rose to 2nd", "fell to 3rd"). "Known" is known **now** | `Knowledge` keeps no history; it changes only with borders until M6 | S |
| D12 | Timeline marks | One mark a season, the first of: your land gained or lost, your work finished or stopped, your shortage, your work begun, your tax change, your choice of country. Others' witnessed lines raise the tick, not a mark | A tick a season, readable at 680 seasons | S |
| D13 | The chronicle list | Witnessed entries only (`LogLines.line_of`, which asks `Knowledge.witnessed`); filters All, Money, Works, Mine (War joins with M7); newest first; whole seasons up to 120 rows; "Older" and "Newest" buttons; the timeline jumps anywhere | A page under 16 ms with 3,000 entries | S |
| D14 | A season's numbers on History | The ring row for the last 40 seasons; for an older Winter, its year row (treasury and land at the year's end); for any other older season, "Numbers are kept for the last 40 seasons and each winter." | D6 | S |
| D15 | Yields' key and later keys | Key 4 (`view_mode_4`) and a fourth segment "Yields" in the top bar. Later modes take the next number keys in the order they arrive: M5's mode 5, M6's Supply 6, M9's Relations 7, M10's Trade 8; each milestone adds its `view_mode_<n>` | First come, first numbered; 1 to 9 are free (bookmarks use Ctrl) | S |
| D16 | What Yields colours | **Your land only**, by its worth a year (D3) in nine bands (4.8); others' land and unowned land under a dark veil; sea clear | A hex's worth uses its owner's taxes and contentment, which `Knowledge` keeps private; the map's pieces already show what others built | S |
| D17 | A loss on the map | Band 1 is madder **with diagonal stripes**, so a loss never rests on hue alone | Castles cost walls and earn little: losses are common on passes | S |
| D18 | Keeping the Yields texture current | Computed when the mode is entered; while it is on, recomputed on `season_ended`, the work signals, `tax_set`, `owners_changed` and `game_started`, and only the texels that changed are written (one texture update a frame) | M2's rule: one draw, a texel a changed hex | S |
| D19 | The number behind a colour | The hover card gains a **Worth** line on your land: "+232 a year (+60 this season)"; none on others' land | Colour is never alone | S |
| D20 | The legend | A small card top left of the map while Yields is on (`ModeLegend`), nine swatches and words | The bands need words | S |
| D21 | Yields where it cannot work | Hidden in a map-only game (toast "no countries on this map", M2's words) and while picking (toast "choose your country first") | No treasury, no worth | S |
| D22 | Where Yields' numbers live | Constants of `MapModes` (bands, colours, alphas), printed in 4.8 and pinned by `test_map_modes.gd`, like M2's relief ramp | Presentation, not rules; the standard's "numbers in `.tres`" is for rules a designer tunes in play | S (move to `GameDefs`) |
| D23 | `InkChart` | M4 ships `LINE_BARS`, `PAIRED_BARS` and marks on them; M4.5 adds `LINE`, `STACKED_BAR`, `SPARK`, the legend, the cursor and its signals, the hover card and `summary()` (6.2) | Style spec 5; M4's page uses marks | S a kind |
| D24 | `StudyTable` | A `Tree`; 100 rows built at a time with a "show more" row; sorting stable, ties by row id, by a header click or Ctrl+Left/Right (column) and Ctrl+Up/Down (direction); Enter, a double click or the row's Go button looks there | Draws only visible rows; bounded node building; keyboard play | S |
| D25 | The timeline | A kit piece, `TimelineStrip` (`shell/ui/`), drawn in `_draw`, colours from the `InkChart` type | Lint: no colour literal outside `shell/ui/` | S |
| D26 | What the study remembers | The page (`state/study_page`, M4) and the span (`state/study_span`) in settings; the tab of each page, each table's sort, the History filter and the cursors for the App's life (the study is one instance); nothing in the save | Style spec 8: "page, tab and scroll are kept" | S |
| D27 | Spans | 12 or 40 seasons (`state/study_span`), one `Segmented` on each page that charts seasons, all writing the one setting | One choice the owner makes once | S |
| D28 | Ways in | I (last page), L (Economy, This season), `[` `]` pages, Ctrl+`[` `]` tabs, the Ducats chip (Economy), the Stores chip (Economy, Goods), the report's "Open the study" (M4), an older log header (History at that season) | The style spec's doors plus the two that land on the right tab | S |
| D29 | Warm pages | `StudyWarm` (shell): after `season_ended`, while the report is up, it calls one study view a frame into `game.view_cache`; a newer `game.version` drops the queue | Europe's views cost up to 12 ms cold; the report gives seconds of idle frames | S (drop it) |
| D30 | "A page opens in under 16 ms" | Measured by `perf_ui.gd` on the CI runner from the opening input to the end of the first frame showing it; north Italy cold, the made-up Europe warm; the cold views on Europe have CPU rows of their own (8) | The UI spec's "the first frame of each screen under 16 ms on the runner" | S |
| D31 | The five questions | The script of 4.11: a fixed setup on seed 1480 as Genoa, five questions with their paths and answers; the owner times each; `test_five_questions.gd` proves each answer is at most four inputs away | Design C.7; S4's playtest | S |
| D32 | Proof of no new rules | `test_study_readonly.gd` (shell: every page, tab, span, sort, cursor and Yields; digest, version, snapshot; the twin games) and `test_insights_views.gd` (core: every view; the pins; a scan for writers) | D1 | none |
| D33 | A country's row in Rankings | Enter or a click on Go closes the study and opens that country's panel (M2's `country` request) | The panel holds what you may know of it (M4's treasury, banded) | S |
| D34 | The milestone value | The App's milestone becomes `"4.5"`: the `since: "4.5"` rows of `Bindings` and `Settings` register and the M4.5 pages and tabs show; nothing is greyed | M1.5's rule: later things are hidden | none |
| D35 | Series on the money chart | At most five: in "Taxes on people", "Taxes on goods", "Port dues"; out "Upkeep and walls", "Your spending". M6's army upkeep joins "Upkeep, walls and army"; M10's trade joins "Dues and trade". The breakdown under the chart shows every line apart | Five inks with five cues | S |
| D36 | `ViewCache` | Unchanged (`SIZE` 64). M4.5 adds about ten keys a version; an evicted view is computed again | No core change for a cache | S (128) |

---

## 3. The v0.2.2 reference

| v0.2.2 | Where | Kept | Changed for the district map, and why |
|---|---|---|---|
| `economy.incomes` fills `country.income` (production, taxes, buildings, trade, upkeep) and each province's `prov.value` (output times price) | `hexa/campaign/systems/economy.py` 181 to 230 | Income by kind; a place's worth | Read from the saved ledgers and `Stats` and from `EconomyPreview` per hex (M4), never recomputed by a page |
| `world.score` (people / 20 + balance × 3 + colonists × 2 + treasury / 50) and `ranking` (alive countries by score) | `systems/season.py` 161 to 172 | A ranked list, the player's row in gold | Ranked by land and income in M4.5 (score is M12's); only known countries, banded; ties by id |
| The ledger panel (L): 28 countries by score with income and colonies, every number exact | `panels/ledger.py` | The ranked list form | L opens Economy (M4); Rankings is its own page behind `Knowledge` |
| The resource `Tracker`: 12 seasons a resource, not saved | `resources.py` (`HISTORY` 12) | 12 seasons as the default span | `Stats`: 40 seasons and a row a year, saved (M3) |
| The action log: 8 seasons of 60 lines, filters All, War, Money, Mine, lines link to places; lost on load | `feed.py` (`KEEP_SEASONS` 8, `PER_SEASON` 60), `hud/actionlog.py` | Filters, links, the sentences | The History page reads the saved chronicle (3,000 entries) over the whole game; older log headers open it |
| Map modes political, terrain, goods, markets on 1 to 4; goods colours each province by its good, with price chips | `mapview.py` (`MODES`, 224, 1366) | A goods map on a number key | Yields colours **your** land by worth a year; the good is named on the hover card and in Districts |

---

## 4. Design content

### 4.1 The study after M4.5

```
+==================[ THE STATESMAN'S STUDY ]============== Spring 1483 ==[Close I]=+
| ECONOMY  <  | This season | Districts | Goods | History |              12 | 40   |
| Rankings    |                                                                    |
| History     |                     (the tab or the page)                          |
|             |                                                                    |
|             |  I: close  [ ]: page  Ctrl+[ ]: tab  Enter: look there             |
+=================================================================================+
```

Pages are built on first open, refreshed on `season_ended` or a newer `game.version` (M4); a hidden tab is marked stale and
refreshed when shown. Every number is a whole number formatted by `Words` (M3): `Words.number` ("1,068"), `Words.signed`
("+86", "−6" with U+2212); gains carry the up arrow and losses the down arrow (`DeltaChip`, M3), never colour alone.

### 4.2 Where each number comes from

| Page, part | Reads | Kept for | Others |
|---|---|---|---|
| Economy, This season (M4) | the closed ledger, `Stats` (12 seasons), `EconomyPreview` | as M4 | none |
| Economy, Districts | `EconomyPreview.worth_seasons(game, you, 4)` and `worth_by_hex` (M4); `Territory.districts`; `WorksView.at` | computed now | none: your land only |
| Economy, Goods | `Country.stock` and `goods_closed` (the last season); the `Stats` goods ring (made, used, stock); `StudyEconomy.lasts` (`EconomyPreview.with`, 8 seasons) | the ring: 40 seasons | none |
| Economy, History | `Stats` ring rows (`income_people`, `income_goods`, `income_dues`, `income_trade`, `upkeep_districts`, `upkeep_walls`, `upkeep_army`, `spending`, `treasury`); the chronicle's works of each season; `Stats` year rows (`treasury`, `land`) | ring 40 seasons; year rows every year | none |
| Rankings | `Stats` ring rows (`land` and the income series) of every country you know | the ring: 40 seasons | known countries, banded |
| History, timeline and list | the chronicle (3,000 newest), through `Knowledge.witnessed` and `LogLines` | 3,000 entries | what you witnessed |
| History, a season's numbers | your `Stats` ring row, or your year row for an older winter | D14 | none |
| Yields mode, hover card Worth | `EconomyPreview.worth_seasons(game, you, 4)` | computed now | none: your land only |

**Ring and year-row rules** (`Stats`, M3 4.6): a ring row exists for each of the last 40 seasons ended (`Stats.row` is
empty otherwise); a year row is the Winter's row, kept for every year. A span longer than the seasons played shows the
seasons played. A chart never mixes ring rows and year rows on one axis. Flows exist only in the ring; stocks (treasury,
land) also at each year's end. The goods ring has no year rows.

### 4.3 Economy, Districts

`StudyEconomy.districts(game, you)`; a `StudyTable` sorted by **A year**, highest first:

| Column (id) | Kind | Content |
|---|---|---|
| Place (`place`) | text, expands | `Words.place`: "Genoa (8, 13)", "near Savona (7, 12)" |
| What (`what`) | text | the piece in words (`HexCard.LEVEL_WORDS` for settlements, castles and harbours; else the family's name and `HexCard.STAGE_WORDS`): "walled town, port", "vineyard, second stage", "castle"; a work under way adds " · under way: to city, ready Winter 1483" (`WorksView.at`) |
| Gives a year (`gives`) | text | the four seasons' goods by good id with `Words.loads`, then dues: "22 fish · dues 114", "42 olive oil", "24 wine" |
| This season (`season`) | delta | the worth of the season in play (`worth_by_hex`) |
| A year (`year`) | delta | the sum of the four seasons' worth |
| Upkeep a year (`upkeep`) | delta (negative) | the four seasons' upkeep and walls |
| Seasons (`seasons`) | spark | the four seasons' worth, the season in play first |

Under the table: "Wild land: 9 places, 7 grain · 10 timber a year, ▲ +57 a year." and "All your land: ▲ +533 a year (each
place rounded down)." Buttons: **Look there** (the selected row; Enter does the same) and **Show on the map** (the Yields
mode, gliding to the selected row or, with none, staying where the camera is). A hint: "Weather not counted."

### 4.4 Economy, Goods

`StudyEconomy.goods(game, you, span)`; a `StudyTable` sorted by **Lasts**, soonest first, ties by good id. A row for every
good in store, made or used in the span, or needed by your towns. Fish and grain share the towns' one food need (M4 D9:
fish eaten first), so both rows carry the food need's Lasts:

| Column (id) | Kind | Content |
|---|---|---|
| Good (`good`) | text with the good's icon (`GoodDef.icon`) | "Salt" |
| In store (`stock`) | number | `Country.stock` now |
| Change (`change`) | delta | the last season's closing less opening (`goods_closed`) |
| Made a year (`made`) | number | the goods ring's `made` over the last four seasons ended |
| Used a year (`used`) | number | the goods ring's `used` over the last four seasons ended |
| Lasts (`lasts`) | text, sorted by value | D5: "none left" (0), "this season" (1), "in 4 seasons" (k), "over 8 seasons" (99), "—" (999) |
| Store (`trend`) | spark | the goods ring's `stock` over the span |

Under the table, for the selected good (the first row at first): an `InkChart` `LINE_BARS` (bars: made a season, `ink_3`;
line: in store, `ink_0`), caption "Salt: made and in store, the last 12 seasons", and a note: "Your towns need 1 salt a
season; none of your land makes it." (`note`: the need, "Your towns eat 4 food a season, fish first, then grain." for fish
and grain, nothing for a good no town needs; then "none of your land makes it" when no district or wild hex of yours makes
it in the four seasons from now, else "most of it from near Savona (7, 12)" for the largest maker). The span
`Segmented` "12 seasons | 40 seasons" sits top right.

### 4.5 Economy, History

`StudyEconomy.history(game, you, span)`:

- **Money in and out** (an `InkChart` `STACKED_BAR` on a `PanelVellumInset`, legend on, caption "Money in and out, a
  season"): per season, upward "Taxes on people" (`ink_0`, solid), "Taxes on goods" (`ink_1`, hatch), "Port dues" (`ink_3`,
  back hatch); downward "Upkeep and walls" (`ink_2`, dots), "Your spending" (`ink_4`, cross hatch) (D35). A mark on every
  season with spending: the largest work's `WorksView.label` ("walled town to city"), tone bad when the treasury fell.
  The cursor starts on the newest season; Left and Right move it; a click on a column sets it.
- **The cursor's season** (left, under the chart): its title; the treasury's opening, closing and change ("Treasury
  1,389 → 519 ▼ −870" in 4.11's game, the weather moving the ducats); a row a line with a `DeltaChip`: Taxes on people,
  Taxes on goods, Port dues (Trade from M10); District upkeep, Walls (Army from M6); Your spending, then one sub-row a work
  ("Begun: walled town to city, Genoa (8, 13) ▼ −1,000", a link) and refunds; Other (developer) when not zero. The rows
  add up to the change (a test).
- **The treasury at each year's end** (right, an `InkChart` `LINE`): one point a year from the year rows, labelled by year;
  "No year has ended yet." before the first winter ends.

### 4.6 Rankings

`StudyRankings.of(game, you, span)`. A head line (`Hint`): "The 3 countries you know, you among them. 10 countries unknown.
Their numbers are rounded." Two columns, **Land, districts** and **Income, a season**, each:

| Part | Content |
|---|---|
| Table | `StudyTable`, sorted by rank: Rank (number), Country (text: the short name, "Genoa (you)" on your row in the header's gold), Value (text sorted by value: yours exact "14", "+86"; others "about 58", "about +240"), a bar column (the value against the largest shown; a negative income draws no bar) |
| Line | "You are 3rd of 3." (`Body`) |
| Chart | `InkChart` `LINE` on a vellum inset, legend on: "You" (`ink_0`, solid) and "The largest you know (about)" (`ink_1`, dash), over the span; marks where your rank changed ("rose to 2nd" good, "fell to 3rd" bad); caption "Your land, the last 12 seasons" |

Enter or a click on a row's Go opens that country's panel (D33). A span `Segmented` top right. Ranks use the exact values
of the last season ended, ties by country id; the bars and texts of others use the band. Before a season has ended: "No
season has ended yet."

### 4.7 History

`StudyHistory`:

- **Timeline** (`TimelineStrip` in a vellum inset, the page's width, 96 px): a tick a season from Spring of the start year to
  the last season ended, its height 4 px plus 3 px a witnessed line (at most 8 lines counted); year labels at each Spring
  when four seasons span 36 px or more, else every 5th, 10th or 50th year, whichever first fits; one mark a season (D12):
  the Kit icon of its kind tinted by tone. When marks would sit closer than 12 px, the slot's highest mark is drawn and the
  hover card lists the rest.

| Mark kind | From the chronicle | Tone | Icon |
|---|---|---|---|
| `land` | `owners_changed` with you as `tag` (gained) or in `others` (lost) | good, bad | `settlement` |
| `finished`, `stopped` | your `work_finished`; your `work_cancelled` with `why` `lost` or `blocked` | good, bad | `district` |
| `short` | your `goods_short` | bad | `warning` |
| `begun` | your `work_started` | plain | `spending` |
| `tax` | your `tax_set` | plain | `tax` |
| `chosen` | your `country_chosen` | plain | `study` |

- **The season line** under the timeline (`SectionHead` with the cursor's title and a `Body` line, D14): for a ring row
  "Treasury 1,068 → 1,153 ▲ +85 · land 14 · income ▲ +85" (the first-year game's Spring 1481: salt short, the towns' taxes
  64); for an older winter "At the year's end: treasury 2,450 · land 16" (the form; the numbers its year row's); else
  "Numbers are kept for the last 40 seasons and each winter."
- **The chronicle**: a `Segmented` of filters **All, Money, Works, Mine** (War from M7: `LogLines.FILTERS`' `since`), the
  buttons **Older** and **Newest**, "Showing 34 of 2,431", and a `StudyTable`: Season (sorted by turn), What (the
  keyword in the line's tone), Line (expands), Go (a button when the line has a hex). Newest first; within a season the
  chronicle's order. Selecting a row moves the timeline's cursor; activating the timeline shows the list from that season
  back (D13).

### 4.8 The Yields mode

`MapModes.yield_bytes(game, you)`: one byte a hex. Your land hex: `yield_band(year)` of its worth a year (D3); any other hex
0. The overlay draws (alphas over the tiles; sea is always clear):

| Byte | Worth a year | Colour (`MapModes.YIELD_COLOURS`) | Legend words |
|---|---|---|---|
| 0 | not your land | the veil `#1c140d` at 0.45 (`VEIL`, `VEIL_ALPHA`) | "Not your land" |
| 1 | under 0 | `#a8321a` with stripes: madder where `floor((d.x + d.y + 3) / 6)` is even (d: map px from the hex's middle; `STRIPE_PX` 6), the veil between | "A loss" |
| 2 | 0 | `#efe3c4` | "Nothing" |
| 3 | 1 to 9 | `#d9d3a0` | "1 to 9" |
| 4 | 10 to 24 | `#b5c98a` | "10 to 24" |
| 5 | 25 to 49 | `#86b37a` | "25 to 49" |
| 6 | 50 to 99 | `#4f9a6e` | "50 to 99" |
| 7 | 100 to 199 | `#2a7d63` | "100 to 199" |
| 8 | 200 to 399 | `#12605a` | "200 to 399" |
| 9 | 400 and more | `#0b3f3c` | "400 and more" |

Bytes 2 to 9 at `YIELD_ALPHA` 0.70. Measured with `ColourContrast.worst_delta_e` (M2: the smaller of normal vision and the
three simulations): neighbouring bytes 2 to 9 differ by 6.7 or more; the veil differs from every ramp colour by 18.3 or
more and madder by 27.1 or more (a test holds them at 6, 15 and 15). The legend's title: "Yields: worth a year". The hover
card's Worth line (D19) gives the number.

On the seed 1480 game as Genoa at Spring 1480 (4.10): Genoa (8, 13) byte 8, the olives (7, 14) 7, the vineyard (7, 12) 6,
Savona (6, 13) and the timber camp (9, 13) 5, the farmland (7, 13) 4, the six woods 3, the two rocks 2.

### 4.9 What you may know of others in M4.5

| Thing | You see |
|---|---|
| Another country's land, income | only when `Knowledge.knows`; banded (`Knowledge.band`: two figures) |
| Its rank | its place in your list (from exact values, ties by id), as the report's Standing |
| Unknown countries | their count only |
| Its districts, goods, stores, worth, taxes | nothing (no Districts row, no Yields colour, no Worth line) |
| Its doings | chronicle lines you witnessed (`Knowledge.witnessed`): until M6 a public event is seen by countries that know its actor |
| The viewer `&""` (tests) | everything, exact |

### 4.10 The worked example: Genoa, seed 1480

"The first-year game" is the 1480 scenario on seed 1480 as Genoa with calm weather, nothing built (`m4-build-spec.md`
4.15 a). Its numbers follow from M4's tables; the tests pin them, and if M4's numbers change these are derived again in the
same pull request.

**Districts at Spring 1480 (turn 1):**

| Place | What | Gives a year | Spring, Summer, Autumn, Winter | A year | Upkeep a year |
|---|---|---|---|---|---|
| Genoa (8, 13) | walled town, port | 22 fish · dues 114 | 60, 63, 60, 49 | ▲ +232 | ▼ −24 |
| near Savona (7, 14) | olives, third stage | 42 olive oil | 0, 0, 35, 70 | ▲ +105 | ▼ −16 |
| near Savona (7, 12) | vineyard, second stage | 24 wine | 2, 2, 62, 2 | ▲ +68 | ▼ −8 |
| Savona (6, 13) | town | 6 grain | 9, 11, 10, 8 | ▲ +38 | ▼ −8 |
| near Genoa (9, 13) | timber, second stage | 37 timber | 5, 5, 5, 18 | ▲ +33 | ▼ −8 |

Wild land: 9 places, 7 grain and 10 timber a year, +57 a year. All your land: +533 a year (M4's realm year is 557: each
place's taxes are rounded down, 6 ducats a season). Genoa's 60: fish 6, dues 30, its 30,000 people's taxes 30, less upkeep 2
and walls 4.

**History after Winter 1480 (turn 5), span 12:**

| Season | People | Goods | Dues | Upkeep | Walls | Spending | Change | Treasury |
|---|---|---|---|---|---|---|---|---|
| Spring 1480 | 65 | 7 | 30 | 12 | 4 | 0 | ▲ +86 | 610 → 696 |
| Summer 1480 | 65 | 9 | 33 | 12 | 4 | 0 | ▲ +91 | → 787 |
| Autumn 1480 | 65 | 68 | 30 | 12 | 4 | 0 | ▲ +147 | → 934 |
| Winter 1480 | 65 | 64 | 21 | 12 | 4 | 0 | ▲ +134 | → 1,068 |

Year rows: 1480: treasury 1,068, land 14. Spring 1480's opening is 696 − 86 = 610 (D7).

**Goods at Spring 1481 (turn 5):**

| Good | In store | Change | Made a year | Used a year | Lasts |
|---|---|---|---|---|---|
| Salt | 0 | ▼ −1 | 0 | 4 | none left |
| Wine | 3 | ▼ −1 | 24 | 4 | over 8 seasons |
| Olive oil | 4 | 0 | 42 | 4 | over 8 seasons |
| Fish | 0 | 0 | 22 | 16 | over 8 seasons |
| Grain | 16 | 0 | 13 | 0 | over 8 seasons |
| Timber | 40 | 0 | 47 | 0 | — |
| Stone | 40 | 0 | 0 | 0 | — |
| Iron | 20 | 0 | 0 | 0 | — |

At turn 1 salt's Lasts is "in 5 seasons" (4 in store, 1 a season); after Spring 1480 it is "in 4 seasons", the season
M4's report names ("Salt runs out in 4 seasons").

**Rankings after Spring 1480 (turn 2):** land: Savoy about 58, Milan about 52, Genoa 14 (3rd of 3); income: Milan about
+260, Savoy about +240, Genoa +86 (3rd of 3); "10 countries unknown" (13 countries, you, and the 2 you know). The same
places and bands as M4's Standing line.

### 4.11 The five questions (the playtest script)

**Setup** (about four minutes; the plan's playtest repeats it): New game, More, seed **1480**, Italy 1480, Play as Genoa.
Select (10, 13), the woods by the sea east of Genoa, and **Build timber** (40 ducats). Press Space, Space seven times, to
**Winter 1481**. Select Genoa (8, 13), press **U**: the card "walled town to city" opens (it is expensive); press Enter:
"−1,000 ducats". Press Space, Space five times, to **Spring 1483**. Each question starts from the map with nothing open and
is timed until the answer is said aloud.

| # | Question | Path | The answer on screen |
|---|---|---|---|
| 1 | Which of your districts earns the most? | **L**, then **Ctrl+]** (Districts) | The first row: "Genoa (8, 13) · walled town, port · under way: to city" with the largest "A year". Then **Show on the map**: the study closes, Yields is on, Genoa is the darkest green |
| 2 | Why did the treasury fall in Winter 1481? | **L**, click **History** (or Ctrl+] three times), click Winter 1481's column (it carries the mark "walled town to city") | "Your spending ▼ −1,000" and under it "Begun: walled town to city, Genoa (8, 13) ▼ −1,000"; the treasury line of that season falls |
| 3 | Which good runs short? | **L**, click **Goods** | The first row: "Salt · 0 · none left", and the note "Your towns need 1 salt a season; none of your land makes it." |
| 4 | Where do you rank on land and income? | **L**, then **]** (Rankings) | "You are 3rd of 3." under Land; under Income your place among Milan, Savoy and you (3rd in the calm test, where Winter 1482 gives Genoa about +138 against Savoy's +167; a good winter for Genoa's olives can lift it to 2nd); Savoy and Milan banded ("about 58", "about 52" for land); "10 countries unknown" |
| 5 | What happened in Spring 1481? | Click the action log's bar (bottom left), click the header **Spring 1481** (or: I, `]` `]`, click Spring 1481 on the timeline) | The History page at Spring 1481: "Your towns ran short of salt: 0 of 1." and the season's line (its treasury, land and income) |

The weather is drawn in the owner's game, so the exact ducats differ from the calm test; the rows, places and words do
not. `test_five_questions.gd` plays the same setup with calm weather (`InsightsFixture.genoa_1483()`) and the same paths.

### 4.12 Opening in under 16 ms

| What | How measured | Where |
|---|---|---|
| A page or tab opens | `perf_ui.gd` injects the opening input (I, `]`, Ctrl+`]`, a tab click) through `Input.parse_input_event`, stamps `Time.get_ticks_usec()`, awaits `RenderingServer.frame_post_draw`, and takes the difference; the worst of 5 opens, each after `game.view_cache.clear()` (cold) or after `StudyWarm.warm_now()` (warm) | the CI runner (xvfb, Mesa), as M1.5's "first frame of each screen" |
| The pure views | `perf_core.gd` times each view call with a cleared cache on the made-up Europe's largest country | nightly, headless |
| The game | north Italy: `PerfFixture.north_italy_game(40)`, the 1480 scenario played 40 seasons as Genoa with seeded random works; the made-up Europe: `PerfFixture.europe_game(40)` | 8 |

The Study also records `last_open_ms` (the synchronous part of an open: the views and the nodes) for the F3 panel.

### 4.13 What M4.5 does not change

No file under `core/defs/`, `core/systems/`, `core/game/` or `data/` changes; in `core/state/` only `stats.gd` gains two
read-only methods. `Season.PHASES` stays `[production, income, works, stats, calendar]`; `Actions.NAMES` stays `build,
upgrade, clear, cancel_work, choose_country, set_tax`; `SaveFile.FORMAT` and `OLDEST_FORMAT` stay 2; `Stats.SERIES` keeps
its 35; `Chronicle.NOTABLE` keeps M4's seven kinds; `Events` gains no signal; `Game.digest()` and the save body are
unchanged. The save's `ui` block (M3, not in the digest) may now hold `map_mode = "yields"`.

> **From M5** (`m5-build-spec.md` 1.2, 4.13): these pins move to M5's values in M5's pull request (`PHASES` gains `people`,
> `SaveFile.FORMAT` 3, `Stats.SERIES` 40, `Chronicle.NOTABLE` nine kinds), and `InsightsFixture` runs on still people
> (`PeopleFixture.still`), so every number of 4.10 and 4.11 holds.

---

## 5. Interfaces

Layers as the standard. New files are marked **new**; "(M2)", "(M3)", "(M4)", "(M1.5)" name pieces those milestones build.
Every amount is an `int`. All views are pure: they read the game, write nothing but `game.view_cache`, and make no engine
call.

### 5.1 Definitions

None.

### 5.2 State (`core/state/stats.gd`, M3, edit): two read-only accessors

```gdscript
const MADE := 0                 # the goods ring's parts (m3-build-spec.md 5.2)
const USED := 1
const STOCK := 2
func goods_value(tag: StringName, turn: int, good: int, part: int) -> int
	# 0 when the row is not written or out of the ring, or the tag, good or part is unknown
func goods_series(tag: StringName, good: int, part: int, span: int) -> PackedInt32Array
	# the last min(span, RING, seasons written) seasons up to last_turn, newest last
```

No field, no save key, no digest change.

### 5.3 Systems, 5.4 Game, 5.5 Events and Session

None. `ViewCache` (M3) holds the new views under the keys named below.

### 5.6 Views (`core/views/`)

```gdscript
# core/views/economy_preview.gd  (M4, edit)
static func worth_seasons(game: Game, tag: StringName, seasons: int = 4) -> Dictionary
	# {turn, seasons, hexes: PackedInt32Array (tag's land hex indices, ascending),
	#  worth: PackedInt32Array [h * seasons + k], upkeep: PackedInt32Array [h * seasons + k] (upkeep and walls, positive),
	#  dues: PackedInt32Array [h * seasons + k], goods: PackedInt32Array [(h * seasons + k) * G + g] (loads)}
	# season k is game.turn + k on the same views, contents and calm weather as with(game, tag, {}, seasons) (works under
	# way standing from their ready turns); a hex's worth is M4 4.17's, floored per hex. Cached [&"worth_seasons",
	# version, tag, seasons]. worth_by_hex (M4) keeps its results: every hex it lists has worth_seasons(game, tag, 1)'s numbers
	# (the per-hex step is shared, its M4 test unchanged)

# core/views/study_economy.gd  (M4, edit)
const SPANS: Array[int] = [12, 40]
const LASTS_NONE_LEFT := 0
const LASTS_OVER := 99
const LASTS_NOT_NEEDED := 999
static func districts(game: Game, tag: StringName) -> Dictionary
	# {has_land, date ("Spring 1483"),
	#  rows: Array[{id (hex index), hex, place, what, work, gives, season, year, upkeep (negative), seasons: PackedInt32Array (4)}]
	#   (pieces only; year descending, ties by id),
	#  wild: {count, gives, year}, total_year}; cached [&"study_districts", version, tag]
static func goods(game: Game, tag: StringName, span: int) -> Dictionary
	# {has_data (a season has ended), span, labels: Array[String] (season titles, oldest first),
	#  rows: Array[{id (good id), key, name, icon, stock, change, made_year, used_year, sold_last, need, lasts, lasts_text,
	#   makes_here: bool, note, stock_series: PackedInt32Array, made_series: PackedInt32Array}] (lasts ascending, ties by id)}
	# cached [&"study_goods", version, tag, span]
static func lasts(game: Game, tag: StringName) -> Dictionary
	# good id -> {value (D5), text}; from EconomyPreview.with(game, tag, {}, 8) (the run Reminders.goods_running_out makes)
static func history(game: Game, tag: StringName, span: int) -> Dictionary
	# {has_data, span,
	#  seasons: Array[{turn, title, opening, closing, change, people, goods, dues, trade, upkeep, walls, army, spending,
	#   other, works: Array[{text, hex, amount}], works_missing: bool}] (oldest first, at most span),
	#  years: Array[{year, closing, land}] (every year row, oldest first)}; cached [&"study_history", version, tag, span]
static func piece_words(game: Game, hex: Vector2i) -> String     # "walled town, port", "vineyard, second stage"

# core/views/study_rankings.gd  (new)
class_name StudyRankings extends RefCounted
const MEASURES: Array[Dictionary] = [{id = &"land", title = "Land, districts", since = "4.5"},
	{id = &"income", title = "Income, a season", since = "4.5"}]   # M5 people, M6 army, M12 score append
static func income_of(stats: Stats, tag: StringName, turn: int) -> int     # D9
static func value_of(stats: Stats, measure: StringName, tag: StringName, turn: int) -> int
static func rank_text(rank: int, total: int) -> String     # "3rd of 3"
static func of(game: Game, viewer: StringName, span: int) -> Dictionary
	# {has_data, turn (the last season ended), known (in the lists, the viewer among them), unknown, head,
	#  measures: Array[{id, title, rank, total, you_text,
	#   rows: Array[{id (country id), tag, name, rank, value, text, mine, bar (permille of the largest shown)}],
	#   line: {labels: Array[String], you: PackedInt32Array, best: PackedInt32Array (banded), marks: Array[Dictionary]}}]}
	# rows: the viewer and Knowledge.known(game, viewer) only; others' value is Knowledge.band of the exact one.
	# Cached [&"rankings", version, viewer, span]

# core/views/study_history.gd  (new)
class_name StudyHistory extends RefCounted
const PAGE := 120
const MARK_KINDS: Array[StringName] = [&"land", &"finished", &"stopped", &"short", &"begun", &"tax", &"chosen"]   # priority
const MARK_ICONS: Dictionary = {land = &"settlement", finished = &"district", stopped = &"district", short = &"warning",
	begun = &"spending", tax = &"tax", chosen = &"study"}
const FILTER_ORDER: Array[StringName] = [&"all", &"war", &"money", &"works", &"mine"]   # shown when LogLines.FILTERS allows
static func index(game: Game, viewer: StringName) -> Dictionary
	# {entries: PackedInt32Array (chronicle indices witnessed by viewer), turns: PackedInt32Array, filters: PackedInt32Array
	#  (a bit per LogLines filter)}; cached [&"history_index", version, viewer]
static func timeline(game: Game, viewer: StringName) -> Dictionary
	# {first_turn (1), last_turn (game.turn - 1), start_year, counts: PackedInt32Array (by turn - 1),
	#  marks: Array[{turn, kind, tone, icon, text, hex, more}]}; cached [&"history_timeline", version, viewer]
static func season(game: Game, viewer: StringName, turn: int) -> Dictionary
	# {turn, title, kept (&"season", &"year", &"none"), text, opening, closing, change, land, income}
static func chronicle(game: Game, viewer: StringName, filter: StringName, upto_turn: int, limit: int = PAGE) -> Dictionary
	# {rows: Array[{id (chronicle index), turn, title, keyword, text, tone, hex, mine}], upto_turn, from_turn,
	#  older_turn (0: none), total (witnessed lines in the filter)}; cached [&"history_chronicle", version, viewer, filter,
	#  upto_turn, limit]
static func filters(milestone: String) -> Array[StringName]     # FILTER_ORDER with LogLines.FILTERS' since <= milestone

# core/views/log_lines.gd  (M3, edit)
static func filters_of(game: Game, entry: Dictionary, viewer: StringName) -> Array[StringName]
	# the filters line_of gives, without building the sentence; [] when not witnessed. line_of calls it

# core/views/map_modes.gd  (M2, edit)
enum Mode { TERRAIN, OWNER, RELIEF, YIELDS }     # keys 1 to 4
const MODE_KEYS: Array[StringName] = [&"terrain", &"owner", &"relief", &"yields"]   # the values of state/map_mode
const YIELD_ALPHA := 0.70
const VEIL := Color("#1c140d")
const VEIL_ALPHA := 0.45
const STRIPE_PX := 6.0
const YIELD_FLOORS: PackedInt32Array = [1, 10, 25, 50, 100, 200, 400]    # the worth a year that starts bytes 3 to 9
const YIELD_COLOURS: Array[Color] = [Color("#a8321a"), Color("#efe3c4"), Color("#d9d3a0"), Color("#b5c98a"),
	Color("#86b37a"), Color("#4f9a6e"), Color("#2a7d63"), Color("#12605a"), Color("#0b3f3c")]   # bytes 1 to 9
static func mode_of(key: StringName) -> int                # -1 unknown
static func yield_band(year: int) -> int                   # 1 under 0, 2 for 0, 3 to 9 by YIELD_FLOORS
static func yield_bytes(game: Game, viewer: StringName) -> PackedByteArray
	# cols x rows, index = row * cols + col; 0 off the viewer's land; cached [&"yields", version, viewer]
static func yield_ramp() -> PackedColorArray               # 256: [0] clear, [1..9] YIELD_COLOURS, the rest clear
static func legend(mode: int) -> Array[Dictionary]         # YIELDS: [{colour, text, stripes: bool}] as 4.8, top byte first,
	# then "A loss" and "Not your land"; other modes []
# colour_of(mode, owner_id, height_byte, palette, tint_on, hot_id, yield_byte: int = 0): YIELDS: height_byte 0 (sea) clear;
#   yield_byte 0 VEIL at VEIL_ALPHA; 1 madder (the stripe's colour at the hex's middle); 2 to 9 the ramp at YIELD_ALPHA
# modes(game): adds YIELDS when game.has_countries() and game.player != &""
# colour_at(game, mode, hex, palette, tint_on, hot_id): YIELDS reads yield_bytes(game, game.player)

# core/views/hex_card.gd  (M1.5 to M4, edit): a line "Worth", "+232 a year (+60 this season)" (tone good, bad when under 0,
#   plain at 0) on a land hex of game.player in a game with countries, from worth_seasons(game, player, 4); none elsewhere
```

## 6. The UI of M4.5

Built from the M1.5 kit and the M3 and M4 pieces. Colours and fonts from the Theme; HUD controls take no focus, screens
do. The App's milestone value becomes `"4.5"` (D34).

### 6.1 Keys and settings

| Action (`Bindings.DEFAULTS`, exists) | Key (Mac) | Who hears it | Does |
|---|---|---|---|
| `view_mode_4` | 4 | `MapInput` -> `mode_requested(MapModes.Mode.YIELDS)` | the Yields mode; refused with a toast in a map-only game and while picking (D21) |
| `study_tab_prev`, `study_tab_next` | Ctrl+`[`, Ctrl+`]` (Cmd) | the study screen | the page's previous or next tab; nothing on a page without tabs |
| `study_page_prev`, `study_page_next` (M4) | `[`, `]` | the study screen | the previous or next of the three pages |
| (table-local) | Ctrl+Left, Ctrl+Right; Ctrl+Up, Ctrl+Down (Cmd) | a focused `StudyTable` | the sort column; descending, ascending |
| (chart-local) | Left, Right, Home, End, Enter | a focused `InkChart` or `TimelineStrip` | the cursor; Shift+Left/Right a year on the timeline; Enter activates |

| `Settings.SCHEMA` key | Change |
|---|---|
| `state/map_mode` (M2) | choices `terrain`, `owner`, `relief`, **`yields`** |
| `state/study_span` (exists, `since: "4.5"`) | read and written by the span `Segmented`s |

### 6.2 The kit

**`InkChart`** (`shell/ui/ink_chart.gd`, M4, edit). What M4 ships stays as it is: `class_name InkChart extends Control`, the
kinds `LINE_BARS` and `PAIRED_BARS`, `ground`, `x_labels`, `y_ticks`, `caption`, `set_series`, `set_marks` (drawn on
`LINE_BARS`), "No data yet", redrawing only from setters, resize and theme change. M4.5 adds:

```gdscript
enum Kind { LINE, LINE_BARS, PAIRED_BARS, STACKED_BAR, SPARK }     # the style spec's five; M4 declares the enum and draws two
signal point_hovered(index: int)          # -1 when the pointer leaves
signal point_activated(index: int)        # a click or Enter
var legend: bool = false                  # a row under the plot: each series' swatch (ink and cue) and name
func set_cursor(index: int) -> void       # -1 none; draws an axis-ink line and a ring on the points
func cursor() -> int
func summary() -> String                  # "Treasury, 4 seasons: from 696 (Spring 1480) to 1,068 (Winter 1480); lowest 696
	# (Spring 1480), highest 1,068 (Winter 1480)." One sentence a series; also the accessibility_description
```

| Kind | Series roles | Drawing |
|---|---|---|
| `LINE` | `line` (each series) | a polyline (2 px, antialiased) in its ink with its dash and marker; one scale |
| `STACKED_BAR` | `in` (stacked up from 0), `out` (given positive, stacked down) | a column a point, each segment its ink and fill cue (`solid`, `hatch`, `dots`, `back_hatch`, `cross_hatch`, in the order of `CHART_CUES`) with a 1 px `axis` outline |
| `SPARK` | one series | no axes, labels or legend; the line in its ink, the last point a 3 px dot |

Every kind: marks (a 6 px triangle above a good point or below a bad one, the text in `Hint` when it fits, else only in the
hover card); the cursor (focusable on screens; Left, Right, Home, End; a click sets it and emits `point_activated`); the
hover card (`_get_tooltip` gives the column's label over a column, `_make_custom_tooltip` returns a `HoverCard` (M1.5) with
the label as title and a line a series `[name, tone, value]`; for `STACKED_BAR` also "Net"); `accessibility_name` =
`caption`, `accessibility_description` = `summary()`. The y ticks of every kind follow the rule M4 ships for its two kinds
(so M4's pictures do not move); x labels are thinned to fit, the last always shown.

**`InkMarks`** (`shell/ui/ink_marks.gd`, **new**): the drawing helpers both `InkChart` and `StudyTable` call; colours are
passed in by the caller from the Theme.

```gdscript
class_name InkMarks extends RefCounted
const FILLS: Array[StringName] = [&"solid", &"hatch", &"dots", &"back_hatch", &"cross_hatch"]   # by ink, as CHART_CUES
static func line(canvas: CanvasItem, points: PackedVector2Array, colour: Color, cue: int, width: float = 2.0) -> void
static func marker(canvas: CanvasItem, at: Vector2, colour: Color, cue: int, size: float = 5.0) -> void
static func fill_rect(canvas: CanvasItem, rect: Rect2, colour: Color, cue: int, outline: Color) -> void
static func spark(canvas: CanvasItem, rect: Rect2, values: PackedInt32Array, colour: Color) -> void
static func bar(canvas: CanvasItem, rect: Rect2, permille: int, colour: Color, track: Color) -> void
static func swatch(canvas: CanvasItem, rect: Rect2, colour: Color, cue: int, as_fill: bool) -> void
```

M4's dash and hollow drawing moves into `InkMarks` unchanged (M4's chart tests and the M4 goldens stay green).

**`StudyTable`** (`shell/ui/study_table.gd`, **new**):

```gdscript
class_name StudyTable extends Tree       # theme_type_variation StudyTree; hide_root; SELECT_ROW; column titles visible
const PAGE := 100
signal row_activated(row: Dictionary)    # Enter, a double click (item_activated) or the row's Go button (button_clicked)
signal row_selected(row: Dictionary)     # item_selected
func set_columns(columns: Array[Dictionary]) -> void
	# {id, title, kind (&"text", &"number", &"delta", &"bar", &"spark", &"button"), align (&"left", &"right"), expand: bool,
	#  min_width: int, ink: int (bar, spark), descending_first: bool (numbers true, text false), sortable: bool}
func set_rows(rows: Array[Dictionary]) -> void
	# each {id: int (unique), cells: {column id: int | String | {value, text, tone, icon}}, hex: Vector2i (optional),
	#  mine: bool (optional), data: Variant (optional)}; a row without an int id is refused (push_error) and skipped
func sort_by(id: StringName, descending: bool) -> void
func sort_state() -> Dictionary          # {id, descending}
func set_sort_state(state: Dictionary) -> void
func select_id(id: int) -> void
func selected_row() -> Dictionary        # {} none
func show_more() -> void                 # PAGE more rows
func shown_count() -> int
func total_count() -> int
```

Sorting is by the cell's value (an int, or the text with `naturalnocasecmp_to`), then by `id` ascending, so equal values
keep one order both ways; the title gains " ↓" or " ↑". `number` cells right-aligned with tabular figures (`TableRow`);
`delta` cells the `arrow_up`, `arrow_down` or `dash` Kit icon tinted `good`, `bad` or muted and the signed number in the
same tone; `bar` and `spark` cells are `CELL_MODE_CUSTOM` with `set_custom_draw_callback` calling `InkMarks.bar` and
`InkMarks.spark` (inks from the `InkChart` type, `_slot` forms on leather); `button` cells `add_button` with the `go` icon.
A `mine` row is drawn in the `TableHeader` gold and its name carries " (you)". After `PAGE` rows a last row reads "Showing
100 of 1,043 · Enter: show 100 more". Selection survives `set_rows` by id. Its `accessibility_name` is the caller's section
title ("Districts") and its `accessibility_description` the sort ("sorted by A year, highest first").

**`TimelineStrip`** (`shell/ui/timeline_strip.gd`, **new**):

```gdscript
class_name TimelineStrip extends Control  # _draw; theme type InkChart (colours), font Hint; minimum 96 px high
signal season_hovered(turn: int)          # -1 when the pointer leaves
signal season_activated(turn: int)        # a click or Enter
func set_timeline(timeline: Dictionary) -> void   # StudyHistory.timeline(game, viewer)
func set_cursor(turn: int) -> void
func cursor() -> int
func summary() -> String                  # "1480 to 1483: 12 seasons; marks in Winter 1480 (finished), Spring 1481
	# (short), Winter 1481 (begun)." Also the accessibility_description
```

Geometry and marks as 4.7; the cursor is a 2 px `ink_4` line with the season's title above it; keys Left, Right (a season),
Shift+Left, Shift+Right (a year), Home, End, Enter; the hover card shows the title, the count ("3 lines") and the marks'
texts. Redraws only on `set_timeline`, `set_cursor`, a hover change, resize and theme change.

### 6.3 The study frame (`shell/screens/study.gd`, `study_page.gd`, `study_pages.gd`, M4, edits)

```gdscript
# Study (M4)
func open_page(page: StringName, focus: Dictionary = {}) -> void   # &"" the last page; focus goes to StudyPage.focus
var last_open_ms: float                   # the synchronous part of the last open (F3)
# StudyPage (M4)
signal tab_changed(tab: StringName)
var milestone: String                      # set by the Study when it builds the page
func shown_tabs() -> Array[Dictionary]     # tabs with since <= milestone
func select_tab(tab: StringName) -> void   # Motion.cross_fade between the tab hosts; remembered for the App's life
func step_tab(delta: int) -> void          # Ctrl+[ ]: stops at the first and last tab
func current_tab() -> StringName
func focus(args: Dictionary) -> void       # virtual; the default selects args.tab when given
# StudyPages (M4)
const LIST: Array[Dictionary] = [
	{id = &"economy", title = "Economy", scene = "res://shell/screens/study/page_economy.tscn", since = "4"},
	{id = &"rankings", title = "Rankings", scene = "res://shell/screens/study/page_rankings.tscn", since = "4.5"},
	{id = &"history", title = "History", scene = "res://shell/screens/study/page_history.tscn", since = "4.5"}]
```

The hint line: "I: close · [ ]: page · Ctrl+[ ]: tab · Enter: look there" (the tab part only on a page with two tabs or
more). The Study hears each page's `tab_changed` to time the switch into `last_open_ms` (the F3 line) and to keep the
hint. Tab moves through a page in its containers' order (the tab buttons, the span, each table, each chart, the buttons);
a tab's cross-fade is instant under reduce motion (`Motion`). L always opens Economy on This season; I opens the last
page on its remembered tab. A page's `action_requested([&"country", tag])` (new) makes the study send
`ctx.request(&"country", {tag})`;
`[&"map_mode", mode, hex]` (hex optional) makes it send `ctx.request(&"look_at", {hex, select: false, mode})` (without a
hex, `{mode}`).

### 6.4 Economy's tabs (`shell/screens/study/page_economy.tscn/.gd`, M4, edit; three tab scenes, new)

```gdscript
# PageEconomy (M4): TABS becomes its `tabs` (M4's StudyPage field), the ids fixed here
const TABS: Array[Dictionary] = [{id = &"this_season", title = "This season", since = "4"},
	{id = &"districts", title = "Districts", since = "4.5", scene = "res://shell/screens/study/economy_districts_tab.tscn"},
	{id = &"goods", title = "Goods", since = "4.5", scene = "res://shell/screens/study/economy_goods_tab.tscn"},
	{id = &"history", title = "History", since = "4.5", scene = "res://shell/screens/study/economy_history_tab.tscn"},
	{id = &"debt", title = "Debt", since = "12"}]
# focus(args): {tab}, plus {hex} (Districts selects that row), {good} (Goods selects that good), {turn} (History's cursor)

# each tab scene: class_name EconomyDistrictsTab / EconomyGoodsTab / EconomyHistoryTab extends VBoxContainer
signal action_requested(action: Array)    # forwarded by the page
func refresh(game: Game, tag: StringName) -> void
func focus(args: Dictionary) -> void
```

| Tab | Built from | Reads | Sends |
|---|---|---|---|
| Districts | a `Hint` line, a `StudyTable` (4.3), two `Body` lines, `KitButton`s Look there and Show on the map | `StudyEconomy.districts` | `[&"look_at", hex]`; `[&"map_mode", &"yields", hex]` |
| Goods | a span `Segmented`, a `StudyTable` (4.4), a `PanelVellumInset` with an `InkChart` `LINE_BARS`, a `Body` note | `StudyEconomy.goods(span)` | nothing (a good has no place) |
| History | a span `Segmented`, a vellum inset with the `STACKED_BAR` chart, an HBox of the season's ledger (`SectionHead`, rows of a `Label` and a `DeltaChip`, work rows as link buttons) and a vellum inset with the year-end `LINE` | `StudyEconomy.history(span)` | `[&"look_at", hex]` from a work row |

A tab refreshes when shown and stale; the span `Segmented` writes `state/study_span` and refreshes the shown tab. Tables
keep their sort for the App's life; the History cursor goes to the newest season when a season has ended since the last
refresh, else stays. Who hears the kit's signals: Districts hears its table's `row_selected` (Look there and Show on the
map take that row) and `row_activated` (look there); Goods hears `row_selected` (its chart and note follow the good);
History hears its chart's `point_activated` (the cursor and the ledger move there) and `point_hovered` (the ledger shows the
hovered season while the pointer is over a column; -1 returns it to the cursor's).

### 6.5 Rankings (`shell/screens/study/page_rankings.tscn/.gd`, new)

`class_name PageRankings extends StudyPage` (no tabs). A head `Hint` line, a span `Segmented`, an HBox of two VBoxes (one a
measure of `StudyRankings.MEASURES` shown by milestone): `SectionHead`, a `StudyTable` (Rank, Country, Value, bar; Go
button), the "You are 3rd of 3." `Body` line, a vellum inset with the `LINE` chart. The page hears each table's
`row_activated` and sends `[&"country", tag]`. "No season has ended yet." before the first season ends. At 1280 x 720
the two columns fit without a scroll; a third measure (M5) wraps to a second row and the page scrolls.

### 6.6 History (`shell/screens/study/page_history.tscn/.gd`, new)

`class_name PageHistory extends StudyPage` (no tabs). A vellum inset with the `TimelineStrip`; a `SectionHead` and `Body`
for the cursor's season (`StudyHistory.season`); a row with the filters `Segmented` (`StudyHistory.filters(milestone)`), the
`KitButton`s Older and Newest and the count; the chronicle `StudyTable` (4.7). `focus({turn})` sets the cursor and shows
the list from that season back. The page hears the timeline's `season_activated` (the cursor and the list's `upto_turn`)
and `season_hovered` (the season line shows the hovered season; -1 returns it to the cursor's), and the table's
`row_selected` (only the cursor moves) and `row_activated` (sends `[&"look_at", hex]`). The filter is remembered for the
App's life (default All).

### 6.7 The Yields mode on the map

- **`ModeOverlay`** (`shell/map/mode_overlay.gd` + `.gdshader`, M2, edits): a fifth texture `yields` (R8, cols x rows,
  zeros) and a sixth `yield_ramp` (RGBA8 256 x 1, `MapModes.yield_ramp()`); uniforms `yield_alpha`, `veil_alpha`,
  `stripe_px`; mode 3 picks the colour as `MapModes.colour_of` does, the stripes measured from the hex's middle the
  fragment already finds. It still reads no screen texture.

```gdscript
func update_yields(bytes: PackedByteArray) -> int    # writes the texels that differ, one texture update; returns how many
func yields_bytes() -> PackedByteArray               # its copy (tests)
```

- **`MapScene`** (`shell/map/map_scene.gd`, M2 to M4, edit): `set_mode(MapModes.Mode.YIELDS)` calls
  `update_yields(MapModes.yield_bytes(game, player))` first; while the mode is Yields, `season_ended`, `work_started`,
  `work_finished`, `work_cancelled`, `tax_set`, `owners_changed` and `game_started` call it again (only when
  `game.version` changed). `set_mode` ignores a mode not in `MapModes.modes(game)` (the App toasts, 6.9); a restored
  `ui.map_mode` not in it becomes Terrain. The mode switch writes `state/map_mode` = `MapModes.MODE_KEYS[mode]`.
- **`MapInput`** (`shell/input/map_input.gd`, edit): `view_mode_4` emits `mode_requested(MapModes.Mode.YIELDS)`.
- **The top bar** (`shell/hud/top_bar.gd`, M2 to M4, edit): the mode `Segmented` lists `MapModes.modes(game)` with the
  names Terrain, Owner, Relief, Yields and tooltips "Yields (4)"; narrowing as M2 (the name hides first).
- **`ModeLegend`** (`shell/hud/mode_legend.tscn/.gd`, **new**): `class_name ModeLegend extends PanelContainer` (`PanelCard`,
  220 px, mouse ignored, focus none) top left of `MapArea` 12 px under the bar (under the F3 panel when that is open);
  `func show_mode(mode: int) -> void` builds a `SectionHead` "Yields: worth a year" and a row a band (a 16 x 12 swatch
  drawn with `InkMarks.fill_rect`, the `hatch` fill in madder for a loss, and the words) from `MapModes.legend(mode)`;
  hidden when the list is empty, while a screen hides the world and in photo mode.
- **The minimap** (M2) draws the same overlay material: Yields shows there too, with no code change.
- **The hover card**: the Worth line (5.6); `MapHover` (M1.5) needs no change.

### 6.8 The action log's older headers (`shell/hud/action_log.gd`, M3, edit)

In a game with countries, a season header other than the newest is a link button (tooltip "Open History at Winter 1480")
that sends `ctx.request(&"study", {page: &"history", turn})`; the newest still opens the last report (M3). In a map-only game
older headers stay plain text.

### 6.9 The App (`shell/app/game_requests.gd`, `app.gd`, M3 and M4, edits), `StudyWarm`, F3

| Request or event | The App |
|---|---|
| `app_requested(&"study", {page, tab, turn, hex, good})` | push the study, `open_page(page, focus)` with the rest of the args |
| `MapInput.study_requested(&"economy")` (L, M4), `study_requested(&"")` (I) | `open_page(&"economy", {tab: &"this_season"})`; `open_page(&"")` (the last page on its remembered tab) |
| `ResourceChips.chip_pressed(&"stores")` | the study at `{page: &"economy", tab: &"goods"}` (`&"ducats"` stays This season) |
| `app_requested(&"look_at", {hex, select, mode})` while the study is up | pop the study; set the mode (`MapModes.mode_of(mode)`) when given; glide and select as M3 when a hex is given |
| `app_requested(&"country", {tag})` while the study is up | pop the study; M2's country request |
| `MapInput.mode_requested(mode)`, the top bar's switch | a mode not in `MapModes.modes(game)` is not passed to `MapScene.set_mode`: the toast "no countries on this map" (a map-only game) or "choose your country first" (while picking); otherwise `set_mode`, then `ModeLegend.show_mode` |
| `Events.season_ended`, `game_started` | `StudyWarm.queue_views()` |

```gdscript
# shell/app/study_warm.gd  (new): a child of the App, process_mode ALWAYS
class_name StudyWarm extends Node
func setup(settings: Settings) -> void
func queue_views() -> void   # for Session.player_tag() in a game with countries: StudyEconomy.this_season, districts,
	# goods(span), history(span), StudyRankings.of(span), StudyHistory.timeline, StudyHistory.chronicle(&"all",
	# game.turn - 1, PAGE), and MapModes.yield_bytes when the map is in Yields; the span from state/study_span
func warm_now() -> void      # runs the whole queue at once (tools and tests)
func pending() -> int
# _process: one view a frame while game.version equals the version at queue time; a newer version clears the queue
```

**F3** (`shell/hud/debug_overlay.gd`, edit): a line "study economy/districts built in 3.4 ms · warm queue 0".

The App sets the milestone `"4.5"`; `Hud` (M1.5) gains the `ModeLegend` slot.

---

## 7. Data and the editor

No data file. The Yields bands, colours and alphas are `MapModes` constants (D22), printed in 4.8 and pinned by
`tests/core/test_map_modes.gd`. No texture, token or Theme variation is added, so `bake_ui.py --check` and
`build_theme.gd --check` pass unchanged; `build_scenario.gd --check` is untouched. The mockup's M4.5 stages (Economy's
Districts, Goods and History tabs, Rankings, History) are rendered once into `godot/tests/fixtures/mockup/study_districts.png`,
`study_goods.png`, `study_history_tab.png`, `study_rankings.png`, `study_history.png` with the command of K4's README (the
mockup's milestone switch at "M4.5"), as references for the side-by-side pictures; they are not checked by CI.

---

## 8. Speed

**The games** (`godot/tools/perf_fixture.gd`, **new**):

```gdscript
class_name PerfFixture extends RefCounted
static func europe_game(seasons: int) -> Game
	# FakeMap.build(494, 247, 1480), FakeScenario.build(map, 60, 1480) with the real goods and families, work_slots_base 10;
	# each season every country begins works up to its free slots at random allowed options (Rng seeded 1480), paying with
	# Game.dev_money when short (the rig, not the rules); `seasons` seasons through Season.run, so the ring is full and the
	# chronicle holds its 3,000 entries at 40
static func north_italy_game(seasons: int) -> Game   # the 1480 scenario on seed 1480 as Genoa, calm weather, the same
	# seeded works for Genoa only, `seasons` seasons
static func largest_tag(game: Game) -> StringName    # the country holding the most land, ties by id
```

**Core** (`godot/tools/perf_core.gd`, M3, edit; rows in `godot/tests/perf_core_budget.json`, nightly, never in GUT): M3's
and M4's rows keep their own 8-season game; the M4.5 rows use `PerfFixture.europe_game(40)`. The viewer is
`PerfFixture.largest_tag(game)`; each call with a cleared `game.view_cache`, the worst of 5:

| Row | Limit (ms) | What |
|---|---|---|
| `study_districts_ms` | 12 | `StudyEconomy.districts` (`worth_seasons` of four seasons inside) |
| `study_goods_ms` | 6 | `StudyEconomy.goods(game, tag, 40)` (an eight-season `EconomyPreview.with` inside) |
| `study_history_ms` | 2 | `StudyEconomy.history(game, tag, 40)` |
| `study_rankings_ms` | 3 | `StudyRankings.of(game, tag, 40)` |
| `history_index_ms` | 6 | `StudyHistory.index` over the 3,000 chronicle entries |
| `history_page_ms` | 3 | `StudyHistory.timeline` and `chronicle(&"all", last, 120)` with the index warm |
| `yield_bytes_ms` | 14 | `MapModes.yield_bytes` (`worth_seasons` cold, then 122,018 bytes) |

**UI** (`godot/tools/ui/perf_ui.gd`, M1.5, edit; rows in `godot/tests/perf_ui_budget.json`), as 4.12:

| Row | Limit (ms) | What |
|---|---|---|
| `study_open_cold_ms` | 16 | the worst of the five M4.5 pages and tabs (Districts, Goods, History tab, Rankings, History), north Italy after 40 seasons, cold |
| `study_open_europe_ms` | 16 | the same five on the made-up Europe as its largest country, after `StudyWarm.warm_now()` |
| `study_tab_switch_ms` | 16 | Ctrl+`]` between two tabs already built |
| `yields_mode_ms` | 16 | key 4 to the first Yields frame, north Italy |
| `yields_update_ms` | 2 | a work begun in Yields: `yield_bytes` warm plus `update_yields` (CPU) |
| `study_table_rows_ms` | 4 | `StudyTable.set_rows` with 100 rows of 7 columns (two custom-drawn) |
| `timeline_draw_ms` | 2 | `TimelineStrip._draw` with 680 seasons and 200 marks |

North Italy's views take well under a millisecond (340 land hexes, 13 countries); its rows measure the nodes.

---

## 9. Tests

GUT unless said. Every new check has a planted-fault case (P).

| File | Cases |
|---|---|
| `tests/core/insights_fixture.gd` (**new**) | `InsightsFixture.genoa_first_year()` (the first-year game of 4.10, played to turn 5), `genoa_1483()` (4.11's setup with calm weather, at turn 13), `forty_seasons()` (the 1480 scenario as Genoa, seeded random works, 40 seasons, calm); each through `Season.run`, weather forced calm by a defs copy with `weather_odds` 100, 0, 0 |
| `tests/core/test_stats.gd` (M3, edit) | `goods_value` and `goods_series` against the ring; wrap at 40; a span longer than the seasons written; P: an unknown good, part or tag gives 0 or an empty array |
| `tests/core/test_economy_preview.gd` (M4, edit) | `worth_seasons` at turn 1 equals 4.10's districts and wild numbers; `worth_by_hex` equals its first season hex by hex; a work under way stands from its ready turn inside the window (Genoa's city in `genoa_1483`, the fourth season); the key changes with `version` (P: a cached result is not served after an action) |
| `tests/core/test_study_economy.gd` (M4, edit) | `districts` equals 4.10 (rows, order, `what`, `gives`, wild, total 533) (P: a hex of Milan's never becomes a row); `goods` equals 4.10 at turn 1 and turn 5; `lasts` equals the season `Reminders` names for every needed good, every season of `forty_seasons` (P: a stock exactly covering eight seasons gives "over 8 seasons", not "in 8"); `history` equals 4.10's first year; every season of `forty_seasons` has its lines adding up to its change; the opening rule at the oldest row; year rows; the works detail names the work and adds up to `spending` (P: a `dev_money` of 500 shows as Other (developer) 500) |
| `tests/core/test_study_rankings.gd` (**new**) | land and income from `Stats`; `income_of` equals `Treasury.left_over` of the closed ledger; ranks with a tie broken by id; only the viewer and the known; `unknown` 10 for Genoa; others banded (P: an unknown country never in the rows; a known other's `value` is `Knowledge.band` of its exact one); equal to `SeasonSummary`'s standing (rank and text) every season of a 40-season run; line marks at rank changes; the viewer `&""` sees all exact; 4.10's turn-2 lists |
| `tests/core/test_study_history.gd` (**new**) | `index` holds exactly the witnessed entries (P: an entry of an unknown country is absent); `timeline` counts and marks on `genoa_1483` (turn 1 begun, 4 finished, 5 short, 8 begun) and the priority; `season` kept `season`, `year` for a winter older than 40 seasons, `none` otherwise (a 48-season run); `chronicle` pages of whole seasons, 120 rows, `older_turn`, each filter; `filters("4.5")` is all, money, works, mine and `filters("7")` adds war (P: an unknown filter is read as `all`) |
| `tests/core/test_log_lines.gd` (M3, edit) | `filters_of` equals `line_of(game, entry, viewer).filters` for every kind and viewer; P: an unwitnessed entry gives [] |
| `tests/core/test_map_modes.gd` (M2, edit) | `yield_band` at -1, 0, 1, 9, 10, 24, 25, 49, 50, 99, 100, 199, 200, 399, 400; `yield_ramp`; `worst_delta_e` of neighbouring bytes 2 to 9 at least 6, the veil and madder against each at least 15; `colour_of` in YIELDS (sea clear, 0 veil, 1 madder, 2 to 9); `yield_bytes` at turn 1 equals 4.8's bytes (P: a Milan hex is 0); `modes` with and without a player and in a map-only game; `mode_of`; `legend` |
| `tests/core/test_hex_card.gd` (edit) | Genoa's Worth line "+232 a year (+60 this season)"; P: none on Milan's land, at sea, in a map-only game |
| `tests/core/test_insights_views.gd` (**new**) | every view of 5.6 on `genoa_1483` leaves `var_to_bytes(Snapshot.of(game))` and `game.version` as they were; each equals itself after a save and load (every input is saved); the pins of 4.13; a text scan of every M4.5 file (`core/views/study_*.gd`, `map_modes.gd`, `economy_preview.gd`, `log_lines.gd`, `hex_card.gd`, `shell/ui/{ink_chart,ink_marks,study_table,timeline_strip}.gd`, `shell/screens/study/*.gd`, `shell/hud/mode_legend.gd`, `shell/app/study_warm.gd`) finds no `.act(`, `Treasury.move(`, `Stores.move(`, `game.emit(`, `Season.run(`, `end_season(`, `dev_money(`, `dev_goods(` or assignment to a field of `game`, `game.state` or a `Country`; P: a planted file in `user://` with `Session.act(` is reported |
| `tests/shell/test_ink_marks.gd` (**new**) | drawn into a 96 x 32 `SubViewport` and read back: a solid line's pixel is its ink; a dash has gaps at its period; each fill cue's pattern; a spark's last dot; a bar's length |
| `tests/shell/test_ink_chart.gd` (M4, edit) | `LINE`, `STACKED_BAR`, `SPARK` with 0 ("No data yet"), 1 and 40 points; the legend's swatches; marks on every kind; Left, Right, Home, End and the signals; a mouse move emits `point_hovered`; the hover card's lines; `summary` for a fixed series; redraw only on new data (a draw counter); M4's cases unchanged |
| `tests/shell/test_study_table.gd` (**new**) | each column kind; numeric and text sorts; ties by id both ways; arrows in titles; 250 rows: 100 shown and the more row, `show_more`; Enter, double click and Go emit `row_activated`; Ctrl+arrows sort; selection kept by id; the mine row; P: a row without an id is skipped with an error |
| `tests/shell/test_timeline_strip.gd` (**new**) | a tick a season; labels at 12, 40 and 680 seasons; marks merged when narrow; keys and signals; `summary`; the hover card |
| `tests/shell/test_study.gd` (M4, edit) | three pages in the nav; `[ ]`; Ctrl+`[ ]` on Economy, nothing on Rankings; the hint; `open_page` with focus (`{tab}` selects it); the tab remembered across a close and an I; `country` and `map_mode` actions forwarded |
| `tests/shell/test_page_economy.gd` (M4, edit) | the four tabs from `TABS`; Districts from 4.10, Look there and Show on the map; Goods with the chart of the selected good; History's chart, cursor, ledger adding up, year chart; the span writes the setting; each tab's refresh leaves the digest |
| `tests/shell/test_page_rankings.gd` (**new**) | two tables; your row; "about"; the unknown line; a row opens the country; the charts; the span; before a season; the digest |
| `tests/shell/test_page_history.gd` (**new**) | the timeline; the season line; filters; Older and Newest; `focus({turn})`; a row moves the cursor; Go looks there; the digest |
| `tests/shell/test_mode_overlay.gd` (M2, edit) | the two new textures' sizes; `update_yields` writes exactly the changed texels (P: one changed byte writes one texel); `set_mode(YIELDS)` changes only a uniform; the minimap material shares `yields` |
| `tests/shell/test_map_scene.gd`, `test_map_input.gd`, `test_hud.gd`, `test_settings.gd` (edits) | key 4 to Yields; updates only while in Yields; `ui.map_mode` restored, an unknown one Terrain; a mode not in `modes(game)` ignored by `set_mode`; the top bar's fourth segment; `state/map_mode` accepts `yields` (P: a bad value falls back) |
| `tests/shell/test_mode_legend.gd` (**new**) | rows from `MapModes.legend`; hidden in other modes, under a screen and in photo mode |
| `tests/shell/test_action_log.gd` (M3, edit) | an older header requests the study at History with its turn; the newest the report; plain in a map-only game |
| `tests/shell/test_study_warm.gd` (**new**) | after `season_ended` one view a frame; `warm_now` fills the cache keys; a newer version clears the queue; the digest unchanged |
| `tests/shell/test_app_flow.gd`, `test_debug_overlay.gd` (edits) | L opens This season and I the remembered tab; the Stores chip opens Goods; a log header opens History; Show on the map ends in Yields; key 4's toasts in the sandbox and while picking; the legend follows the mode; the F3 line |
| `tests/shell/test_five_questions.gd` (**new**) | 4.11 on `genoa_1483` through the App: each answer's text on screen in at most four inputs from the bare map |
| `tests/shell/test_study_readonly.gd` (**new**) | on `genoa_1483` in the App: every page, tab, span, table sort, show more, chart and timeline cursor, filter, Older and Newest, Yields on and off, the hover card on every land hex, the log's older headers, `StudyWarm`; then `Game.digest()`, `version`, `Snapshot.of` bytes, the action log, events and chronicle sizes as before; that game and a fresh `genoa_1483()` give one digest after 8 more seasons; P: `tests/fixtures/study_page_bad.tscn` (a page whose refresh calls `Session.act("set_tax", {level: 2})`) is caught |
| `tests/shell/test_ui_monkey.gd` (edit) | adds 4, Ctrl+`[ ]`, clicks on headers, rows, chart columns, the timeline and log headers; invariants: the digest unchanged by any study input; the legend shown exactly in Yields |
| `godot/tools/map/probe_mode_overlay.gd` (M2, edit; windowed, CI under xvfb) | Yields: the pixel at every hex middle equals `colour_at` (tolerance 3); P: `--plant` swaps two ramp entries and prints FAIL |
| Pictures (`godot/tools/ui/shot_ui.gd`, edit) | Districts, Goods, History tab (cursor on Winter 1481), Rankings, History (cursor on Spring 1481), Yields on north Italy with the legend, a chart's hover card, a sorted table; at 1280 x 720 scale 1 and 2560 x 1440 scale 2, beside the mockup renders of section 7; signed, then goldens `godot/tests/goldens/m4_5_*.png` (0.5 %) |

**Determinism and saves:** M4.5 changes neither; M3's and M4's tests stay green unchanged, and `test_study_readonly.gd`'s
twin games prove the views leave no trace in the play. **Save round trip:** `test_insights_views.gd` (the views equal
after a load).

---

## 10. Risks and probes

| Risk | Probe and when | Fallback |
|---|---|---|
| `worth_seasons` over 12 ms on Europe's largest country | `perf_core` on I3a's first day | one pass a hex: the season-free base from `DistrictCache` (M4) times the sum of the four slots' percents, with the four contents applied to the taxes; same numbers (the test) |
| The witnessed index over 6 ms with 3,000 entries | `perf_core` on I3b's first day | an index kept across versions and extended with the chronicle's new entries (the chronicle only appends) |
| Custom-drawn Tree cells slow or ugly | I2's first day: 100 rows with two custom columns, `study_table_rows_ms` | no spark column in tables; the selected row's chart shows the trend |
| Ctrl+arrows taken by the system on the Mac | the owner, I2's first week | Alt+arrows (Option) |
| Yields' colours unreadable over busy tiles | the art director on north Italy, I4b | alpha 0.85 and the veil at 0.60 (constants) |
| A page over 16 ms cold on the runner | `perf_ui` in I8 | the page builds its tables in the opening frame and its charts in the next (each frame under 16 ms; the charts read "No data yet" for one frame) |
| The five questions take longer than a minute | the owner's playtest; the times written down | a default moves toward the answer (a constant each, S): L opens the last Economy tab; History opens on the season of the newest mark |
| Rankings at 1280 x 720 clipped | the pictures at 1280 x 720 | the charts below the tables, one column, the page scrolls |
| `known now` misleads after borders move (M7) | expected | M7 revisits with explored hexes (M6) |
| `ViewCache` thrash evicts warm views | `test_study_warm` counts misses after a hex panel of ten options | `SIZE` 128 (a constant, S) |

---

## 11. Changes to other pages

Made in this change:

| Page | Edit |
|---|---|
| `docs/architecture/godot-architecture.md` | 9.2, row M4.5: points at this spec and its plan; status "specified and planned, waits for the owner's go; starts after M4 closes" |
| `docs/architecture/ui-style-and-feedback-spec.md` | Section 8: a note of M4.5's refinements (the pages' layouts, `InkChart` and `StudyTable` additions, `TimelineStrip`, the warmer, Yields' meaning) pointing here |
| `docs/architecture/ui-style-and-feedback-plan.md` | S4: a note that `m4-5-build-plan.md` folds I1 to I8 (I3 and I4 split in two) and adds Q1 to Q5; I7's action-log edit moved to Q3 |
| `docs/architecture/ui-and-controls-plan.md` | Section 4, row M4.5: the tasks are those of `m4-5-build-plan.md`; adds `timeline_strip.gd`, `ink_marks.gd`, `mode_legend.*`, `study_warm.gd` |
| `docs/architecture/ui-and-controls-spec.md` | 4.1: `view_mode_1..4` reads "4 Yields (M4.5); later modes take 5 and up as they arrive"; 7: the map-mode switcher lists Yields (M4.5, key 4); 2's map-modes row adds 4.5 (yields) |
| `docs/architecture/m2-build-spec.md` | 7.1: the `view_mode_4` row: Yields from M4.5, Supply on key 6 in M6 (M5's mode takes 5); `state/map_mode` gains `yields` in M4.5. 13: an M4.5 row (the overlay's Yields textures, key 4, the switch) and M6's key 6 |
| `docs/architecture/m4-build-plan.md` | W4's done-when adds "marks on `LINE_BARS` (spec 6.7's chart)" |
| `docs/architecture/m4-build-spec.md` | 9, `test_ink_chart.gd`: adds marks on `LINE_BARS` |
| `docs/design/ui/game-feedback-screens.md` | C.7: a line that M4.5's five questions are `m4-5-build-spec.md` 4.11 |
| `docs/README.md` | Links to this spec and its plan |

Made by the tasks (listed in the plan): `godot/README.md` (keys 4 and Ctrl+`[ ]`, the pages; Q3). No port rule changes: no
new autoload, no new layer; `tools/lint_godot.py` needs no entry (new files sit in listed folders, each under 800 lines);
`CLAUDE.md` gains no command (the perf tools exist).

---

## 12. What M4.5 hands to later milestones

| M | Takes from M4.5 | M4.5 leaves for it |
|---|---|---|
| M5 | `StudyRankings.MEASURES` gains people; the People page on `StudyTable` and `InkChart`; its map mode on key 5 with a `MapModes.legend` (the Food mode); worth follows `Economy.people_at` with no view change; all taken up in `m5-build-spec.md` | People |
| M6 | Rankings' army measure (banded "about 40,000 men"); Supply on key 6; witnesses from vision shrink what History shows of others; `knows` by explored hexes changes Rankings' lists; "Upkeep, walls and army" on the money chart (D35); taken up in `m6-build-spec.md` | Armies |
| M7 | the War filter (`LogLines.FILTERS` `since` 7) and a `war` mark kind before `land`; losses on the Military page; taken up in `m7-build-spec.md` (4.14, 5.6, 6.9) | War |
| M8 | the AI's acts fill the chronicle (the 120-row pages and the index matter); `StudyWarm` after the AI's season; the AI reads `Knowledge` as the pages do; taken up in `m8-build-spec.md` (the chronicle's coverage measured by the soak, D51) | The AI |
| M9 | Relations on key 7; the Diplomacy page with `RelationMatrix`: taken up in `m9-build-spec.md` 6.3, 6.9 | Diplomacy |
| M10 | "Dues and trade" on the money chart; the Trade page with sparks in `StudyTable`; Trade on key 8 | Trade |
| M11 | an `era` mark kind; the Research page; **taken up in `m11-build-spec.md`** 4.21 and 6.6 (the `era` and `tech` marks; the page between People and Rankings) | Research |
| M12 | score in Rankings; the Debt tab (`PageEconomy.TABS`); text size and high contrast in charts (`InkChart` reads the Theme, whose high-contrast set has the chart inks) (taken up in `m12-build-spec.md` section 12; `since` compared as numbers, D49) | A whole game |
| **E2, E3** | **Nothing blocking: every view reads the map through `Territory` and `EconomyPreview`, and the Europe budgets are already measured on the made-up Europe.** | |
