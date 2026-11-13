# Changelog

Versions follow `0.MINOR.PATCH` until the Steam release (1.0). Each release is a git tag `vX.Y.Z` with a GitHub
release. The save format has its own number (`hexa/campaign/saves.py` `VERSION`); older saves keep loading
unless a release says otherwise.

**Version numbers (decided 2026-11-13):** one MINOR number per phase of the roadmap; PATCH numbers are the steps
and fixes inside it. 0.1.x is the foundations. **0.2.x is war:** battles (0.2.0), their patches, battle cards, the
battle mini-map, and war goals and peace. Later phases (the living world, history and events, the sea, game feel)
take 0.3.x onwards, and 0.9.x is the Steam Early Access line. 1.0 is the full Steam release.

## v0.2.1: War you can follow
**War:**
- Every battle ends in the turn it starts: days are fought until a side breaks, withdraws or flees, up to 8; at the cap the
  side with the lower morale withdraws. The Battle timing option (Clash, Quick battles) is gone. A second stack that
  attacks the same hex in the same season joins on day 1
- Withdraw takes effect after 2 days of fighting and costs 5% of men (10% for an attacker) and 25 morale. Under 10% front
  morale an army flees: 15% of men, its guns, morale 0.15 (about 2 seasons before it can attack). A broken line pays the
  same. A flight goes to the side's own land first, then any free land, and cannot besiege where it lands that season
- The AI uses the same rules and reads its stance as attacker and defender
- The odds card is recalibrated to the new battles (word bands and ground factors)

**On screen:**
- A "N things to do" task flag under End season (or left of an open panel) replaces the End season pop-up; Fund research
  shows whenever it can be bought. The option is now "Task flag"
- A battle's log line says how it ended and in how many days, and opens its day log

**Under the hood:**
- Battle stats: 100% of battles end in their season (was 76%), 3% by withdrawal (was 36%), the loser loses 32% of its men
  (median, was 16%); a mixed-arms battle perf metric
- Design docs: sieges and retreats (the siege meter for 0.2.2, field forts); mockups of the task flag and the siege badge

Old saves keep loading; a battle in progress finishes in the next season.

## v0.2.0: Battles that last
**War:**
- A stack that moves into an enemy stack starts a battle on that hex. It lasts several days a season until one side's line
  breaks; neither side may leave except by Withdraw or a rout. Three lanes (left, centre, right) with reserves behind them;
  friendly stacks that move in join as reserves
- Each day runs fire, shock, flanks, morale and pursuit. Each side rolls a d6 a day (1 is x0.7 damage, 6 is x1.4), shown in
  the log. A line break (centre, then flanks) and front-line army morale decide who routs; reserves count much less
- Orders each season: Attack, Hold or Withdraw, and a standing order for when you are attacked (Hold or Withdraw)
- Option: Battle timing. Clash (default) fights day 1 in the attacker's season and the rest after both sides could send help;
  Quick battles fights every day at once
- Terrain matters: crossing a pass and attacking uphill cost the attacker; the defender fights on its own ground
- A routed side retreats to the nearest friendly hex, or surrenders if it has none. Losses split into killed and wounded;
  some of the wounded come back after the battle if in supply
- Strength is shown as men everywhere (panels, log, odds), not HP; regiments have morale
- AI-vs-AI battles resolve the same way, leave one log line, and the AI picks its stance and sends reinforcements
- Removed: bombardment and the old one-shot battle

**On screen:**
- The battle panel: both sides, men, the day's dice, front-line morale, the lanes, your order and standing order, a day log
- On the map: a crossed-swords badge with a bar for the front line, the two stacks drawn facing each other
- The odds card: one word before you attack (men, morale and ground behind it)
- Every battle gets a name ("Battle of Redondela") and a year in the log; ribbons mark battles and their end
- A reminder and ribbon while a battle is still on at the end of the season

**Under the hood:**
- Battle rules live in `systems/combat.py` and `systems/battle.py`; the screens read one cached read model; a battle stats
  tool and baseline, seeded scenario tests and a perf row for the worst case
- Save format 2 (battles, unit men and morale). Old saves load

**Design docs for review:** war goals and peace, crown projects, reactive prices, battle size and frontage (width,
back line, rotation, crossbowmen), a docked battle panel, and the research on what makes strategy games fun.

Battle stats at release (clash timing): on plains the attacker wins 53% at 3v3, 77% at 4v3, 87% at 6v4 and 47% at 6v6;
on hills 23%, 50%, 70% and 30%. In AI games the bigger side wins 57% when even, 64% at 1.3x, 89% at 2x and 95% above
2.5x. No battle reached the six-season safety stop. 1,317 tests and 254 nightly soak games pass.

Old saves keep loading.

## v0.1.9: Armies you can follow
**Movement and reminders:**
- After End season, the armies and ships you can see walk hex by hex instead of jumping; moves under fog stay instant,
  the replay is capped at about 6 seconds and Space or Enter skips it. New option: Movement speed (Instant, Normal, Slow)
- End-of-turn reminders: before a season ends, a list of what is unfinished (research with no points, merchants with a
  profitable order, nothing being built, armies idle in open land, a pending idea card); a click goes there. New option:
  End-of-turn reminders (on by default)

**Fixes:**
- The Options page's Back button no longer crosses the edge of the box
- Loading a quicksave with the technology screen open no longer crashes

**Under the hood:**
- The code clean-up: the pause menu and technology screen are separate screens; the map drawing caches have size
  limits and every generated sprite is checked in CI; most game rules moved out of `world.py` (3,500 lines to 730) into
  systems modules, with the season order in one table. No rule changed; fixed-seed games play exactly as before
- Design docs for review: stopping steamrolling (diplomacy, rebels), achievements, city states, a scenario mode; measured
  trade and economy reports; an audit of the remaining Kenney art

Old saves keep loading.

## v0.1.8: The new HUD and real place names
**On screen:**
- A new top bar: chips for ducats, provinces, research, regiments, merchants, prestige and more, each with its change
  this season ("198 (+5)"), a hover card with the breakdown and a click that opens its panel. Map modes are icons; the
  bar drops goods, changes and labels as the window narrows
- Floating ribbons rise from the map when something happens where you can see it: Recruited, Battle!, Captured!,
  Siege, Deserted, Colony, Built, in six colours
- An action log in the corner: collapsed to one line, opens to the season's events with All, War, Money and Mine
  filters; a click on a place moves the camera there and selects your troops

**Map and names:**
- Real historical regions and place names on the Europe map (#68), with a Credits button on the start menu (GeoNames,
  CC BY 4.0)

**Under the hood:**
- The code clean-up's first three phases: a safety net for refactors (behaviour oracle, save checks), an event bus and
  a game manager for the season, and a shared UI kit with one module per side panel. No rule changed
- Code review fixes: clicks on the log, top bar and minimap no longer reach the map; the side panel always gets its
  clicks; a castle seized for debt is counted once in the ducats card
- Roadmap: playtest ideas, recruiting at buildings, debt and bankruptcy, trade and economy tests, music, multiplayer

Old saves keep loading.

## v0.1.7: Mountains as natural borders
**Mountains and passes:**
- Ridge crests are natural borders: mountain hexes stay walkable, but land armies, supply, zones of control and roads
  cross a ridge only at a pass. There are 24 named passes plus extra ones wherever a ridge would split a landmass. Passes
  close in winter: a march that meets a closed pass waits for spring, and the hover names the pass (#87)
- The ridges live in the landscape tiles: five crest looks by range, altitude, terrain and climate; mountains draw about
  half as many peaks; in summer a pass is a valley with a track and a hospice, in winter a snow-filled saddle with a
  frozen snowflake mark (from mid zoom in). New option: Pass names (off by default)
- Africa: Maghreb steppe and plains, Sahel savanna and steppe, jungle only in the tropics, on Europe and random worlds (#97)

**Map:**
- No grid lines with the grid off at any zoom (#93, #95); no wave of tiles after a zoom (#94); no trees in the water (#96);
  borders stay in every map mode (#98); town names never overlap
- All 32 goods have their own code-drawn object in the Goods view (Deposits), replacing borrowed Kenney sprites and the
  crate fallback (fish is a basket of fish now, not a box)

**Playtest fixes:**
- Tech prerequisites enforced (#88); a "War on you!" alert (#89); the current research and queue marked (#90); Exit and
  Main menu ask Yes or No (#91); long marches wait for you at the end of a season, R continues them (#92)

**Code review and kioba's tests:**
- Kioba's testing foundation merged (#72-#86): CI on GitHub Actions, window, monkey and golden-screenshot tests, nightly
  soak and perf runs, a save-compatibility check
- Every bug they pinned is fixed: damaged save and settings files, three Colonisation rules, a minimap click, and orders
  round foreign land
- Code review fixes: the tax preview no longer changes the season, "a university", stuck-stack reasons, and
  greyed-out button hints

Old saves keep loading; mountain passes are rebuilt when a save is loaded.

## v0.1.6: Bug-fix round 2
The rest of kioba's v0.1.6 and v0.1.7 milestones, and a seamless map:
- With the hex grid off (G), tiles join with no gaps at any zoom; washes, fog and frost draw no lines between hexes (#71)
- Fog clears at once for hexes revealed partway through a move (#26)
- Changing the tax level previews the income without rerunning the season's economy (#23)
- Random worlds use their own Old World / New World regions instead of Europe's cut-offs (#31)
- An AI march plans its path once and walks without rescanning cargo (#30)
- One saves/options folder lookup (#32); loading builds the map view once; dead code removed (#33, #34)

## v0.1.5: Bug-fix round
**UI and controls** (kioba's milestone):
- Right-clicking to close the pause menu no longer gives the selected stack an order (#16)
- Loading a save slot asks first, as Main menu and Exit already did (#17)
- The top bar lays out from the right edge, so End season never covers Menu; Market and Ledger hide when they don't fit (#18)
- Esc clears the selected stack first; the next Esc opens the pause menu (#19)
- Attacking, founding and foraging cancel the stack's standing move order (#22)
- The panel close button closes the country and market panels (#24)

**Economy:**
- Debt limit of 6 seasons of running costs (at least 300 ducats); interest stops at the limit. Over it, with a deficit,
  unpaid troops desert, then creditors seize buildings, works, castles and settlement levels. An AI in debt raises taxes,
  stops spending and disbands troops. Interim rule until the debt and bankruptcy design (#69).

**Map:**
- Close-zoom panning is smooth and new ground fills in about a second; map overlays build about 6x faster (#67)
- Closed passes are marked in winter at every zoom; town names draw over unit tokens at zoom 13 and out (#70)
- Random worlds get up to 8 mountain passes that close in winter

## v0.1.4: New map look and playtest fixes
**New map look (M3, first part):**
- The two closest zooms draw a blended landscape: wavy edge transitions between every kind of ground, peaks and
  forests that rise over the hex behind, a treeline on the Alps, natural field systems on developed farms and
  forest clearings around towns. The map changes as provinces grow.
- Winter covers the high mountains in snow. **Mountain passes close in winter**: Gotthard, Brenner, Mont Cenis,
  Simplon, Great St Bernard, Roncesvalles, Dukla and Lupkow. Land armies can't enter them until spring (ships
  and armies already standing on one are not stopped); the AI routes around them.
- A faint hex grid, on by default: **G** or the options menu turns it off.
- The Goods view no longer crashes on cattle, copper and the other new goods.

Fixes from the 2026-11-11 playtest:
- Log lines read "upgraded to open fields" and "started an armoury" instead of "now a open fields" / "a armoury"
- Long button labels (Invest, ...) are cut with an ellipsis instead of running over the cost
- Merchant order buttons follow the merchant rules; a loss-making order stays allowed but its hint warns in red
- The game-over banner wraps inside the screen and names your own place and score
- No siege progress on a hex where two sides' troops stand
- A stack that can't move says why (a unit raised this season, already moved, or foraged), in a toast and in the unit panel

## v0.1.3: War and peace rules
Fixes from kioba's war and logistics milestone (all merged PRs, with tests):
- Cannons no longer bombard their own stack when it stands on an enemy castle hex (#63, fixes #12)
- Only the owner can forage a stack, so a player can't freeze an enemy army by foraging it (#62, fixes #13)
- Peace only sends home armies standing in the other party's land, so a siege on another front is kept (#61, fixes #14)
- White peace keeps provinces occupied by a third country in another war (#60, fixes #15)
- Boarding only picks a ship with room for the whole group (#66, fixes #20)
- Cut-off computer armies forage at the end of the season instead of just losing strength (#64, fixes #21)
- Battle reports count the strength lost in that fight, not all missing strength (#65, fixes #28)

## v0.1.2: Tech tree
- **Tech tree** for Age of Discovery: 37 techs in four branches (Military, Trade & Industry, Navigation,
  Statecraft) over three eras, plus a national tech for every country. Press **T** to open it.
- **Research** each season from the base, burghers, universities and coffee houses, plus once-a-year funding
  (60 ducats for 15 points). Techs are cheaper when your market partners already know them. There's a queue: click
  a far tech to queue its path.
- **Era gate:** era II opens from 1520 with 4 era I techs; era III from 1575 with 4 era II techs. At each new era
  you pick 1 of 3 idea cards (one is your nation's).
- **What techs change:**
  - stack size, drill levels, siege, the large castle, supply
  - merchants, taxes and routes
  - new manufactories: ropewalk, powder mill, glassworks, tannery
  - carracks and the new galleon, Atlantic crossings, plantations
  - universities, and more
- **AI** countries choose research by their situation, fund it and pick idea cards.
- Old saves load: their countries get techs that fit their era.
- The start menu shows the game version.

## v0.1.1: Crashes and save/load safety
No failed save, bad save file, bad settings file or bad `--nation` can crash the game or silently lose progress
(#5 to #11). See the GitHub release for details.
