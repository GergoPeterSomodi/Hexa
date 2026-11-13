# UI designs for upcoming features (proposals, 2026-11-12)

Mockups for the owner's review: **sections 2 and 3 approved on 2026-11-12; sections 1 and 4-8 decided on 2026-11-13 (see each section's Decided block)**. Every image is 1280x720, drawn over real game screenshots. Cyan boxes and numbered circles are review notes, not UI. Each section lists the open choices and what the game needs for it. Once a section is approved, it moves into the roadmap's milestone as built work.

---

## 1. UI kit and button style (M3 UI clean-up)


**Decided 2026-11-13:** the kit as drawn. Labels in Segoe Semibold 13. Province panel tabs Overview, Build and Raise (plus Fleet, see section 4); Trade stays the Market button in the footer. The top bar is option A (section 2).
**Images:** `01_ui_kit.png`, `01b_ui_kit_panels.png`, `02_topbar_before_after.png`, `03_province_panel_before_after.png`

**What they show:**
- **Buttons:** one family of four kinds (primary, secondary, danger and toggle), each in five states (normal, hover, pressed, disabled and selected).
  - The shape is the same for all: radius 5, a 1 px ink outline, a lit top edge and a 2 px lip that drops away when the button is pressed.
  - There are three sizes (22, 26 and 32 px), plus an icon slot and a cost slot.
  - There are 35 icons, two-tone with ink outlines.
  - Colour tokens: the game's own, plus `PANEL_HEAD`, `CARD_BG`, `WARN_C` and `INFO_C`.
  - Type scale: Georgia for titles, Segoe Semibold 13 for labels. Today's labels use light Segoe 12.
  - A today-versus-new row compares the two styles.
- **Panels:**
  - A header band and a tab row.
  - Rows: plain, zebra, hover and action rows (label, status and a button column of fixed width).
  - Collapsible sections, and a footer that stays put.
  - The hover card, the one-line hint, the modal and the toggle groups.
  - Spacing rules on a 4 px grid, with measurements.
- **Top bar (02):** today's bar, then option A (one row, icon chips) and option B (today's row tidied, plus a 28 px resource strip with words).
- **Province panel (03):** today's panel next to the new Overview tab, which has:
  - stat tiles
  - level pips
  - a "Money from this province" section
  - a building summary
  - a "this season" status line
  - a footer that stays put

**Open choices:**
- Top bar A (icons and numbers, nothing lost from the map) or B (words, 28 px less map). The recommendation is A.
- Labels in Segoe Semibold 13 (the proposal) or keep light Segoe 12.
- Province panel tabs: Overview, Build and Raise. Should Trade be a tab too, or stay the Market button in the footer?

**Data and code needed:**
- A shared UI kit module (`hexa/ui/` or `campaign/uikit.py`) with `Button(kind, state, icon, detail)`, `Panel`, `Tabs`, `Row`, `Tooltip` and `Modal`. The roadmap's architecture review already plans it.
- An icon set: code-drawn like this mockup, or PNGs.
- Panel bodies scroll, and the panel keeps a scroll offset for each tab.
- Per-province income: taxes, manufactories and upkeep for each province. The world adds these up today, but doesn't keep them per province.

## 2. Resource bar

**Approved 2026-11-12: top bar option A** (one row of icon chips with numbers and the change since last turn).
**Images:** `02_topbar_before_after.png` (options A and B), `04_resource_bar.png` (in the game, with hover cards)

**What they show:**
- Chips for ducats, research, regiments, merchants and prestige. Each has its value and its change since the start of the season, for example `3,548 (+45)`: green up, red down, grey for no change.
- Two key goods (horses and gunpowder) show their home-market price, red when it rises.
- The ducats hover card has three groups of lines: income, spending and one-off items. The total is the season's change, and the footer gives next season's expected change.
- The regiments card lists raised, lost and deserted units.
- Clicking a chip opens its panel: the treasury, the tech screen, the army list, the market or the ledger. The Market and Ledger buttons go, because the chips replace them.

**Open choices:**
- Key goods: (a) the home-market price of goods you need (shown here; it needs no new model), or (b) a national stockpile (a new model).
- Score or prestige: which number counts as "prestige"? Today only the ledger score exists.
- What the delta means: the actual change since the season began (shown), or the expected change next season (today's number). The card shows both.
- At 1024 px wide: drop the key goods first, then move the deltas into the cards.

**Data and code needed:**
- The world remembers each resource's value at the start of the season: treasury, research points, regiment count, merchants, prestige and key-goods prices.
- A list of one-off money events each season, with a reason and a place, such as "raised pikemen in Verona -40". This fits the planned event bus.
- Unit gains and losses each season: raised, killed, deserted, disbanded.
- The country's `income` dict, split into merchants and tolls (today it is one "trade" line).

## 3. Floating action text and the action log

**Approved 2026-11-12: treatment C (ribbon tag) with six colours** (war red, siege amber, gains gold, own actions green, losses rose, others white). The action log is as mocked.
**Images:** `05_floating_text_styles.png`, `06_floating_text_motion.png`, `07_action_log.png`

**What they show:**
- **05:** three treatments over grass, snow, sea and towns at radius 34:
  - **A, storybook:** Georgia bold 22, an ink outline, a shadow and an icon
  - **B, bold game:** Segoe Black, capitals, a thick outline and a lit gradient
  - **C, ribbon tag:** Palatino on a dark pill with a coloured edge
  - There is a colour for each kind of event: war red, gains gold, own green and neutral white (the owner's four), plus two candidates: amber for sieges and rose for losses.
- **06:** frame strips of the motion (1.1 s) for A and B, a timing chart (rise, opacity, size pop), the stacking of three messages on one hex, and the rules.
- **07:** the collapsible action log in the bottom-left corner. It has filters (All, War, Money, Mine), groups by season, and coloured keywords with icons. Place names are links, and clicking one glides the camera there. The collapsed state is one line with a "+8 new" badge.

**Open choices:**
- The treatment: A, B or C.
- Six colours or the owner's four. Amber for sieges and rose for losses are optional.
- Gains (+12 ducats): rise straight up, or drift to the ducats chip.
- How far back the log goes: two seasons, with older lines in the ledger (proposed), or the whole game.

**Data and code needed:**
- An event bus, or at least `world.events`: a list of (kind, keyword, text, place, owner, visible) for each action.
- The text and the log listen to it. The action text comes from the same place as today's `world.message` lines.
- A visibility check, so the player only sees what is in their view: hidden under fog, log line only when off screen.
- Timing tied to the planned slower movement: the word appears when the moving unit arrives.
- A small animation list in the app (start time, hex, image), drawn after the map and before the panels.

## 4. Recruiting at buildings


**Decided 2026-11-13:**
- Option A, lists: one row per unit with its stats and cost. No separate "Not here" section: units that can't be raised here stay in the list, greyed out, and the hover card gives the reason (the missing building with a Build shortcut, the nearest place that can raise it).
- Ships go on their own **Fleet** tab, shown only in coastal provinces, with the same row style.
- The Stable buys horses from the home market; any province can build one. The horse price's hover card explains why it moved (supply and demand: herds lost, stables buying).
- No mercenaries for now. Colonies raise militia only. Scouts, wagons and colonists can be raised in any owned town.
- Clicking a greyed row does nothing; the hover card explains.
- Revised mockup: `17_recruit_raise_v2.png` (its costs are placeholders; the galleon still needs its own figure; the mockup's click hint on greyed rows is out of date).
**Images:** `08_recruit_raise_tab.png`, `08b_recruit_build_tab.png`

**What they show:**
- **Option A, the Raise tab:**
  - "Raise here" lists each unit with its figure, stats, cost and what allows it: Barracks I, the capital or Port I.
  - "Not here" gives the reason ("Needs a stable") and a Build shortcut with its cost. It also names the nearest place that can raise the unit, as a link that jumps there.
  - A placeholder slot for mercenaries.
- **Option B:** the same data as a grid of cards.
- **08b:**
  - A "Show where (R)" map overlay with badges on every province that can raise each kind.
  - The Build tab grouped as Military, then Manufactories, then Trade and learning. The new Stable is tagged NEW and uses the Kenney horse trough for its art.
  - A Stable hover card with its cost, upkeep, requirements and the horse price.

**Open choices:**
- Option A (lists) or B (cards).
- Whether the stable needs horses in the province or on the market.
- Mercenaries: whether to have them at all, and where they are hired (left open).
- Scouts, wagons and colonists: shown here as raised anywhere, which is still to be decided.
- What colonies can raise. The suggestion is militia only; it isn't shown.
- The "R" key for the overlay is a suggestion.

**Data and code needed:**
- `recruit_check` returns a structured reason with the missing building, so the UI can offer that building.
- A query for the nearest owned province that can raise a given kind, and how many seasons away it is.
- A new `Building("stable", ...)` with art, cost and upkeep. The Foundry's hint changes, because towns no longer cast cannons.
- The overlay needs a list, per kind, of the provinces that can raise it.

## 5. Debt and bankruptcy


**Decided 2026-11-13:**
- Option B, **loans**: lenders with amount, rate and term, a credit rating and offers.
- At bankruptcy, for now **all penalties apply** (default on the creditors, provinces pledged, the army pays). Provinces go to the lender country. Penalties last a set number of years, and the debt is wiped.
- Bankruptcy is built only after the Crown projects exist (economy report E6), so money has a use first.
- Dev notes for later: let the player choose the penalty in the pop-up, with a fair value on each choice (a unit or a poor province must not clear 10,000 ducats; the deeper the debt, the more it takes). A repayment event could also offer to pay off part of a debt with provinces or units before bankruptcy.
**Images:** `09_debt_bar_and_panel.png`, `10_bankruptcy_popup.png`

**What they show:**
- **Top bar:** in debt, the ducats chip becomes a red debt chip with a scroll icon and a thin stage gauge under it.
- **The debt panel (option A, debt as one number):**
  - the debt and the limit
  - a stage gauge: interest 2%, interest 4%, credit refused, then bankruptcy, with a "you" marker
  - a countdown: "Bankrupt in 9 seasons", and when credit is refused
  - this season's income, spending and interest
  - "Ways out" as one-click actions with their effect: high tax, disband, recall a merchant, sell a building
  - the debt over the last 8 seasons
- **Option B (inset), loans:** a credit rating, lenders with amount, rate and term, Repay, and this season's offers.
- **The bankruptcy pop-up (10):**
  - It uses the event frame (15), with a Kenney-tile picture, a stats strip and three choice cards: default on the creditors, pledge provinces, or pay with the army.
  - Each card lists its good and bad outcomes, a chance (dice), and how long it lasts.
  - It has a confirm button and no Cancel.

**Open choices (from `debt-and-bankruptcy.md`):**
- Debt as one number (A) or as loans (B).
- Penalties: a choice at bankruptcy (shown), all of them, or random by situation.
- Provinces go to a creditor country (shown with Genoa) or simply break away.
- Penalty length: years, or until a reform.
- The debt is wiped completely (shown) or partly carried over.
- The stage thresholds shown (40% and 75% of the limit) are placeholders.

**Data and code needed:**
- `debt_stage(tag)` and `seasons_to_bankruptcy(tag)`, from the current deficit.
- The debt history for the last N seasons.
- The "ways out" estimates: what each action would change.
- A bankruptcy event with its choices and lasting modifiers (with timers) on the country.
- For B: a loan model (lender, principal, rate, term) and a credit rating.

## 6. Trade


**Decided 2026-11-13:** the trade layer lives in the markets map mode (A). Recall and new orders also work from the route ribbons on the map.
**Images:** `11_trade_map.png`, `12_market_panel_and_order.png`

**What they show:**
- **11, a trade layer on the markets map:**
  - Your merchants are gold ribbons with moving dashes, arrows for direction, and a chip with the good and the profit.
  - Background trade is shown as thin white lines, their width set by volume.
  - Tolls you collect appear as a badge on the market.
  - A route to a market off screen runs to the edge of the map and names it there.
  - The legend has a "1 merchant idle, Best route" shortcut and a Mine/All filter.
  - The hover card for a route shows the buy and sell prices, the margin, transport and tolls, the profit, and the last 4 seasons.
- **12, the market panel:**
  - An Opportunities tab with a sell table and a buy table: the good, the price here with a trend arrow, the best market elsewhere, and the profit per merchant a season, with Sell or Buy buttons.
  - "Your merchants", with Recall buttons.
  - An idle-merchant hint.
  - "Competition here": rival merchants and their effect on prices.
  - **A 3-click order card:** (1) the good, (2) where from, sorted by profit with the best pre-selected, (3) Send.

**Open choices:**
- The trade layer inside the markets mode (A, shown) or a fifth map mode, Trade (B).
- Should Recall and new orders also be possible from the map ribbons?

**Data and code needed:**
- Each merchant's profit history (the last 4 seasons). Today only `route.results` for the last season exists.
- A ranking of the best opportunities across all routes from your markets: the good, the direction and the net profit after transport and tolls (`merchant_options` already does this for one route).
- The volume of each route's flows, for the line width.
- Each market's price trend: the last season's price.

## 7. Economy


**Decided 2026-11-13:** the Treasury is the wide window. Investment hints: the ranked panel (A) plus a "Best here" line in each province's Overview; no map badges. Research buildings get no payback figure; only money-making investments are ranked.
**Images:** `13_economy_treasury.png`, `14_investment_hints.png`

**What they show:**
- **13, the Treasury window (wide, over a dimmed map):**
  - "Money in" and "Money out" as stacked bars, plus what's left over.
  - In and out legends.
  - One-off items.
  - The last 12 seasons: change bars and a treasury line, with a note for a bad season.
  - "Earns most" and "Costs most", as links that jump to the place.
  - Tax-level buttons that preview their effect on hover.
  - Tabs: This season, Provinces, History and Debt.
- **14, "What to build next":**
  - Every affordable investment, ranked by payback (cost divided by gain), with filters.
  - A payback bar coloured green, gold or amber.
  - A hover card with the sums.
  - A warning when money piles up: the playtest's 9,000 ducats.
  - Option B: payback badges on the map.
  - A "Best here" hint in each province's Overview tab.

**Open choices:**
- Treasury as a wide window (shown) or kept inside the side panel's country tab.
- Investment hints as a panel (A), map badges (B), or both.
- Whether research buildings (the university) get a "payback" in research points.

**Data and code needed:**
- A season history of the treasury and the net change (12 or more seasons).
- Income and cost per province and per army.
- A payback estimate for each possible build, invest or settlement upgrade: the extra output times the price, minus the inputs and upkeep.
- A preview of the tax effect for each tax level.

## 8. Event pop-up (Phase 3: the frame only)


**Decided 2026-11-13:** option A only, for every event. Events wait until the AI turn is over. Pictures (see `16_event_art_compare.png`): composed from the game's tiles and figures by default; painted only for a few big moments (a new age, bankruptcy, a great discovery).
**Image:** `15_event_popup_frame.png` (the bankruptcy pop-up, `10`, reuses it)

**What it shows:**
- **Option A, a centred event:**
  - The kit's modal, with a picture made from Kenney tiles in code.
  - Georgia text and a quote.
  - Three choice cards, with outcomes marked good (green), bad (red) and chance (amber dice).
  - Hovering a gamble shows the odds and what changes them, such as a tech or a busy port.
  - Keys 1-3 choose.
- **Option B, a small card tied to its hex by a gold line:** for local events, such as "Silver near Zara".

**Open choices:**
- A only, or A for country-wide events and B for local ones (proposed).
- Pictures composed from tiles in code, or painted for each event.
- Whether events may interrupt the AI turn (proposed: no, they wait).

**Data and code needed:**
- An event definition: the title, text, picture recipe, conditions, and choices with their effects and chances.
- An event queue that the app shows between turns.
- Planned for Phase 3, except the frame, which bankruptcy needs first.

## 9. Battle panel v3: docked on the left

**Status: proposal (2026-11-13).** Nothing is decided yet.
**Images:** `18_battle_panel_v3_a_3lanes.png`, `18_battle_panel_v3_a_5lanes.png`, `18_battle_panel_v3_b_5lanes.png`, `18_battle_panel_v3_b_3lanes_log.png`, `18_battle_panel_v3_tiles.png`

Today the battle panel is a centred modal that hides the map. Version 3 docks it on the left, under the top bar. The battle's hex, its badge and the front-line bar stay in view to the right. The board follows the battle-size draft (`docs/design/battle-size-and-frontage.md`):
- 2 x lanes places a side: each lane has one back slot behind it. Ranged troops fill the back slots first, then spare regiments as "second rank".
- The reserve pool shows as chips, with a "Marching in" line for stacks waiting next door.
- There are 3 lanes today and 5 at most. 7 lanes appear only as a stretch note on the tiles sheet.

**What they show (both options):**
- **Face-off header:**
  - The attacker on the left and the defender on the right, each with a country roundel (two-tone, with a banner), the side and "you", and the general with his trait (or "No general", greyed).
  - In the middle, a small battle picture made from the hex's own terrain tiles. It shows the two sides' figures facing each other and the map's crossed-swords badge.
  - The battle's name and year in the title band, with a jump-to-hex button and a close button.
- **Stats, mirrored per side:**
  - Men now and at the start, killed and wounded.
  - The day's d6 next to each side, with its multiplier (green above 1, red below).
  - Front-line morale as two halves growing out from the middle, with a red tick at the 5% break point in each half.
- **Regiment tiles:**
  - Each tile shows the game's unit figure, a men bar and a morale bar.
  - Corner marks: routing (red tile and a red arrow), shaken ("!"), wavering (yellow dot), and in back slots "fires" (gold) or READY (green).
  - Slots: a broken lane is dashed red, a lane closed by terrain is hatched, and an empty slot is dashed grey.
  - A tile shows more text the wider it is: compact (none), medium (the men) and wide (name, men and tag). Hovering a tile shows the numbers card.
- **Below the board:**
  - The order (Attack, Hold or Withdraw) and the standing order "If attacked" (Hold or Withdraw).
  - The terrain modifiers as chips (defender's ground, uphill, pass crossing). A stripe in the side's colour shows whom each one helps.
  - The day log.
  - While the dock is open, the map's action log line moves to the right of it.

**Option A, a narrow dock (420 px)** (`_a_3lanes`, `_a_5lanes`):
- The lanes run across, as in mockups 10 and 50. The enemy sits above the dashed front line (reserve chips, then back slots, then front), and you sit below (front, then back, then reserve).
- The lanes share the width: 116 px wide tiles at 3 lanes, 67 px medium tiles at 5 lanes. Lane names sit under the front line.
- With one modifier its chip has a word. With several they become icon chips, and the words show on hover.
- The day log is always visible (4 lines), with a "full log (L)" link.

**Option B, a wide dock (560 px)** (`_b_5lanes`, `_b_3lanes_log`):
- The board mirrors the header. Your reserve, back and front columns are on the left and the enemy's on the right. Each lane is one row, with its name and the clash in the middle.
- Tiles are 104 px wide and always show the name and the men. Rows are 52 px at 5 lanes and 66 px at 3.
- Men, killed and wounded sit under each name, and the dice beside the picture.
- Tabs: Regiments, Day log (with a red "+N" for new lines) and Ground. The footer, with the terrain chips (in full words), the orders and the standing order, shows on every tab.

**Recommendation: A.**
- It keeps the board the battle-size draft and the approved mockups 10 and 50 use (lanes across, back rows behind), so the panel, the doc and the later cards slice all speak of the same picture.
- Orders, modifiers and the log fit on one screen with no tab, which means fewer clicks.
- It covers a third of a 1280 px window instead of 44%.
- B reads better at a glance (the true left-right mirror, names on every tile), and is the better choice if the owner wants the header's mirror carried into the board.

**Open choices:**
1. A or B (recommended: A).
2. Which side sits nearer the front line in A? Proposed: the enemy always above and you below. The other way is attacker below and defender above, even when you defend.
3. Front-line morale: two halves from the middle (proposed: shows each side's own break point), or today's single tug-of-war bar (it matches the map's bar).
4. The day log: always visible in the panel (A), or in a tab (B)?
5. Should the dock push the map's camera so the battle hex is never under it (proposed: yes, centre the battle in the free part of the map when the dock opens)?

**Data and code needed:**
- `battleview`: the lane count, `back` (a slot list per side), `pool`, the joiners marching in (the stack, where from, when), the general's name and trait, and each regiment's tag (fires or ready). It already has men, start, killed, wounded, front morale, dice, stance, standing order, uphill, crossing, ground and the log.
- A battle picture made from the terrain's tile pair (data.py's terrain sprites) and two `art.figure`s, cached per battle.
- `screens/battle.py` becomes a docked screen: not opaque, map input passes through to the right of the dock, and `view_rect()` narrows while it is open.
- The country roundel and the d6 face as kit pieces (`ui/kit.py`), and the pool chip as a kit chip.
- Generator: `mockups/ui-designs/gen_18_battle_v3.py`, drawn over the headless shots `base/battle_dock_a.png` and `battle_dock_b.png` (today's Battle of Redondela, no side panel). The 5-lane numbers are invented, so the map under them still shows today's 5-against-3 battle.

---

## Not designed here
- **The rest of the battle UI:** it already has approved mockups in `docs/design/battle.md`. Only the docked panel (section 9) is proposed here.
- **The outliner or alert list, text size, and colour-blind options:** these are in the M3 clean-up list but outside this brief. The kit's tokens and type scale are where they would plug in.
- **The army list panel** (opened from the regiments chip) and the **Provinces and History tabs** of the treasury are named but not drawn.
