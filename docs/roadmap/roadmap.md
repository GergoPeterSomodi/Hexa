# Hexa roadmap

Status as of 2026-11-13. Sources: the project notes, `docs/design/tech-tree.md`, `docs/design/tech-tree-build-spec.md` and the Hexa README. Items marked "(suggested)" are my inferences, not decisions from the notes.

## Next up (decided 2026-11-13): one thing at a time, starting with war

The owner asked for one delivery at a time, starting with war. The order:

1. **Now: M2 battle system, slice 1, "Battles that last" (v0.2.0).** From `docs/design/battle.md`:
   - A stack that moves into an enemy stack starts a battle on that hex. Neither side may leave except by Withdraw or a rout.
   - Three rounds (days) a season, until one army's morale falls under 25%.
   - Three front lanes (left, centre, right) and a back line of cannons and reserves. Each day runs fire, shock, flanks, morale and pursuit.
   - Losses split into killed and wounded; about half the wounded come back after the battle if in supply. Morale per regiment and for the army.
   - A friendly stack that moves in joins as a reserve. A routed side retreats to the nearest friendly hex, or surrenders if it has none.
   - The player's orders each season: Attack, Hold or Withdraw.
   - A battle panel and a crossed-swords badge with a morale bar on the map. AI-vs-AI battles resolve the same way and leave one log line.
   - It **replaces** today's one-shot battle (answers open question 6). Sieges and castle assaults use the same lanes, with the garrison as a front-line card.
   - Not in slice 1: cards, the battle mini-map, deployment presets, battle events, troop quality.
2. **Then M2 slice 2:** battle cards from techs, generals and elites (command points, the hand, sneaky cards).
3. **Then M2 slice 3:** the battle mini-map, lane ground from the real map, deployment, battle events, troop quality.
4. **After M2, one at a time:** the war goals and peace design (wars end by peace terms); trade T1, T2 and T5; economy E2 to E5; then the Crown projects and reactive prices designs.
5. **Decided from the fun research (2026-11-13):** Aims of the crown (score, after the Crown projects, decided with how winning works); rivals for any runaway leader (in the brakes design); the price revolution is parked. See `docs/research/2026-11-13-creative-review.md`.

Everything decided on 2026-11-13 stays recorded in its own doc and waits its turn.

**The war line as of 2026-11-14** (one release at a time; each has its brief in `docs/roadmap/`):
- v0.2.0 "Battles that last" and v0.2.1 "War you can follow" are released.
- **0.2.2 Sieges** is being built: the siege meter, Besiege or Storm, castle areas (a castle holds the land around it) and
  clear move messages.
- **Next after 0.2.2: a castles map mode** (owner's request, 2026-11-14). A map mode, next to terrain, goods and markets,
  that shows every castle and the land each one holds: the area in the owner's colour, the castle's level, castles under
  siege and fallen castles, for all countries (not only while a war stack is selected, as in 0.2.2). It builds on the
  castle-area rule of `docs/design/castle-areas.md`; its design and mockup come in the next planning batch.
- Then the battle board as a mini game inside the turn (0.2.3 brief draft), the trade patch, field forts, battle cards,
  the battle mini-map, war goals and peace.

## 1. Vision

Hexa started in 2020 as a pygame hex-tile map editor. It is becoming a playable turn-based strategy game against the computer. The main mode, Age of Discovery, is a Europa Universalis-like game from 1480 to 1650 on a hex map. The player picks a real country (or a random world), runs its economy of goods, markets and trade routes, grows towns and castles, colonises the Americas and Africa, and goes to war with neighbours. The art stays in the Kenney hexagon tile style, but each part should look distinct and creative, not like a copy of another part. The two smaller modes, a medieval conquest match and a colonisation survival mode, remain as they are.

**Final goal: publish Hexa on Steam** (decided 2026-11-11; see `docs/roadmap/long-term-roadmap.md`, Phase 6).

**GitHub milestones** (file issues against these):
- feature milestones:
  - [M3 Map look & UI polish](https://github.com/GergoPeterSomodi/Hexa/milestone/7), next up
  - [M2 Battle system](https://github.com/GergoPeterSomodi/Hexa/milestone/8)
  - [M4 Balance & fun pass](https://github.com/GergoPeterSomodi/Hexa/milestone/9)
  - [M5 World & naming fixes](https://github.com/GergoPeterSomodi/Hexa/milestone/10)
  - [Events & characters (Phase 3)](https://github.com/GergoPeterSomodi/Hexa/milestone/11)
  - [1.0 Steam release](https://github.com/GergoPeterSomodi/Hexa/milestone/12)
- bug-fix releases: v0.1.3, v0.1.5, v0.1.6 and v0.1.7 (shipped; v0.1.7 also brought the ridge rule and art, M3)
- the testing foundation
- M1 (the tech tree) shipped as v0.1.2.
- The first part of M3 (the blended map look and winter passes) shipped as v0.1.4.

## 2. Guiding principles

- **Ask first, then build.** Confirm the look and play of any big feature with the user, with mockups, before any code is written.
- **Keep the game's style.** New work uses the Kenney tile art and extends the existing modes. Do not write a parallel game.
- **Be creative inside that style.** The user rejected look-alike tiles. Each good, unit and building should look distinct.
- **Build big chunks.** The user prefers a whole feature built, tested and then shown, rather than many small steps.
- **Push straight to master.** The user declined feature branches.
- **Fix issues first (user rule, 2026-11-12).** Open bug issues get fixed and released before new features start. A feature round starts only when the bug list is empty or the user says otherwise.
- **Haiku workers build, the main session plans and reviews.** Each task names the files to touch, the files not to touch, what done looks like, and the test or screenshot that proves it. The main session reads the diff, runs the tests and looks at screenshots before reporting. Tasks on the same file run one at a time.
- **Saved ideas stay saved.** When the user says to save an idea for later, it goes in the backlog and is not built.
- **Old saves keep working** (suggested, from the tech spec's migration plan).
- **Numbers live in data files and get tuned in play.** Costs and balance are changed in `data.py` and checked in full runs.
- **Working notes:** pygame 2.6 and pygame-gui 0.5.7 in a local virtual environment. Rule tests run with `python -m unittest discover -s tests -t .` from `Hexa/`.

## 3. What exists today

Per the README and notes. The README does not confirm the 2x finer hex grid from the art round, so check the code before relying on it.

**Map and generation**
- Real 1480 map of Europe, North Africa and the Mediterranean: about 14,000 provinces and about 50 countries.
- Random world: new invented countries each game, an inland sea and an unknown New World. `--seed` repeats a map.
- Wave function collapse grows the terrain on both maps (latitude, mountains, deserts, marsh, rivers).
- Edge-matched tileset for coasts, rivers, roads, bridges, walls, towns and castles.
- Fog: black (never seen) and light (known, not visible).
- Zoomable tile art, winter frost, settlements that grow from village to city.

**Economy and goods**
- 32 goods: raw, luxury, money (silver, gold) and made-in-town goods. Each province makes one raw good.
- About 20 markets with trade routes, tolls and prices between 0.3x and 3.5x base.
- Pops (peasants, burghers, nobles), taxes, seven kinds of manufactory, marketplaces, ports and shipyards.
- Province investment: five levels per goods tile, paid in ducats and local goods.
- Merchants with manual export and import orders.

**Colonisation (inside Age of Discovery)**
- Colonists, caravels and carracks, colonies, trading posts, and founding in the New World across the Atlantic.

**War**
- Stacks of 6, 7 or 8 by era (a general adds 2). Infantry, cavalry and cannons, upgraded by era.
- Battles today: the best three units per side form the front line.
- Castles with four levels, zones of control, sieges, supply depots, wagons and foraging.
- Veterans and elites, barracks and foundry drills, generals, and declaring war and peace.

**UI and saves**
- Start menu, Esc menu, eight save slots, quicksave (F5/F9), autosave, and Continue.
- Options: fullscreen, window sizes (1280x720 default, 1600x900, 1920x1080), autosave and scroll speed.
- Map modes (1 to 4), goods view sub-modes, hover cards, movement preview with path costs, country panel (C) and ledger (L).

**Other modes:** Conquest (a small medieval map against one rival) and Colonisation (survival against two rival companies). The old tile editor is `Hex.py`.

## 4. Approved but not built

### Tech tree (in progress, being built now)
- Four branches (Military, Trade & Industry, Navigation, Statecraft) over three eras. One research at a time, with a queue.
- Era II opens in 1520 once the country knows 4 era I techs. Era III opens in 1575 after 4 era II techs.
- At each new era the player picks 1 of 3 idea cards: one national card and two general cards.
- Research points come from the base, burghers, universities, printing press and coffee houses. Diffusion makes known techs cheaper for neighbours.
- Troops stay tied to eras. Military techs give tactics, siege, castles, supply and stack size instead.
- A tech screen (T hotkey) with battle-card chips on each node. Each country starts with a national tech.
- Build spec: `docs/design/tech-tree-build-spec.md` (new `tech.py`, `techscreen.py`, world, AI and tests).
- Note: the build spec says 38 techs, but the design tables list 37. Check which is right before the build finishes.

### Battle system (approved, not built)
- A shared tile with three lanes, played with cards.
- Cards come from researched techs (1 to 2 each), from general traits and from elite regiments. Every deck starts with five era I cards.
- Command points per day; Military revolution adds one.
- Mockups 10, 11, 13, 14 to 16 show the battle panel, map, minimap and card designs.
- **Design notes:** `docs/design/battle.md` is in `docs/design/battle.md`.

## 5. Idea backlog (saved, not designed)

- **Tile blending:** soften the hard hex edges between neighbouring tiles.
- **More zoom:** a closer zoom level than the current maximum (hex radius 34 px).
- **Province names:** replace "near X" with a better scheme, such as real region or county names, generated local names, or terrain plus region.
- **Landmark tiles** for famous cities (Venice, Constantinople, Paris, London, Lisbon), based on historic views.
- **Smoother transitions** between black fog, brown dirt, steppe and desert, and green grass.
- **Map look: OPTION 1 CHOSEN (2026-11-11): "mostly tiles, blended"** (see [43_three_options.png](../design/images/43_three_options.png)). The user added:
  - Goods tiles and every other special tile (e.g. salt pans next to green) get a crisp transition band to differing neighbours. No hard edges.
  - Objects are never cut off at the hex top. Trees, peaks and buildings may rise over the hex behind (draw back to front), and forests continue across tiles.
  - **The environment changes with the game:**
    - a town built in a forest clears the trees around it
    - development spreads fields
    - winter frost
  - **Seasonal blocked areas:** mountain passes (mountain or snow hexes) can't be crossed in winter. They are painted snowed-in with a "closed" mark; this is a gameplay rule as well as art.
- **Environments, not single tiles (earlier idea, now refined by the option 1 choice above):** the map is drawn as one landscape that runs across hexes. The user liked all three ideas, combined:
  - **Layered landscape (the base):** blended ground, mountain ranges along their real ridge lines, forests and objects placed across hex borders by density, rivers in valleys, then towns and units.
  - **Neighbour-aware tiles:** ridges join, edges thin out, ground blends at edges (transition approach b).
  - **Multi-hex set pieces:** e.g. the Alps massif, river deltas, volcanoes, landmark cities with suburbs.
  - **Hex grid:** faint lines with a toggle key.
  - The approved object and tile mockups (`docs/design/images/`) are the art for it. This is part of M3 (polish), and it starts with a mockup on real map data.
- **Review the starting map (user request 2026-11-11):** there are too many towns and villages at the start. Thin out the starting settlements so that towns and cities stand out and growing new ones feels earned. Check this against real 1480 town density. It's planned with M5 (world and naming fixes).
- **UI clean-up and improvement (user request 2026-11-11):**
  - one consistent look for buttons: sizes, states, icons, hover and press feedback
  - tidy panels and spacing
  - clear typography and information hierarchy
  - fewer clicks for common tasks
  - an outliner or alert list
  - text size and colour-blind options
  - The design comes with mockups for approval first.
  - It is planned with the polish round (M3), before the battle system, and the playtest report's UI ideas feed into it.
- **Movement pace and floating action text (user request 2026-11-12):**
  - **Slower visible movement.** Movement is too fast, especially for the computer's armies and ships. Units in the player's vision walk hex by hex at a readable pace, so the player can follow what each one does. Moves under fog of war stay instant. Speed comes from the scroll/animation option, with a key to skip or speed up the computer's turn (suggested).
  - **Floating action text.** A short word rises from the hex where something happens and fades after about one second: "Attacked!", "Sieging", "Captured!", "Retreat", "Foraged", "Recruited", "+12 ducats". It shows for the player's own actions and for anything the player can see.
  - **Action log box.** Floating text is easy to miss, so every floating message is also written to a small log box on screen: forage, healing, recruiting, attacks, sieges and captures, own actions first. Each line names the place, and clicking a line jumps the camera there (suggested). It builds on today's message lines in the bottom-left corner. It can be collapsed and scrolls back through the season.
  - **The look matters:** the font, size, colour, outline and motion must be right and readable over every terrain. A colour per kind of event: war red, gains gold, own green, neutral white (suggested). The design comes with mockups for approval first.
  - Planned with the polish round (M3).
- **Recruiting only at certain places (user request 2026-11-12):**
  - Today almost any owned province can raise troops. Only cannons (a town or a foundry), ships (a port or a shipyard) and generals (the capital) have place rules.
  - **Decided (2026-11-12): every unit type is raised only at its own building.** Where you raise an army then matters.
    - Infantry: barracks (agreed).
    - Cavalry: a new building, such as a stable or stud farm. It could also need horses in the province or market (suggested).
    - Cannons: the foundry. Today a town is enough; that would go.
    - Ships: the port, plus the shipyard for carracks and galleons (as today).
    - The other units (scouts, supply wagons, colonists, generals): their building or place is to be decided. Generals already come from the capital.
    - Elite troops: their building, if one is added.
    - Colonies: what they can raise is to be decided (suggested: militia only).
  - **Mercenaries: undecided.** Whether to have them at all, and where they are hired.
  - The new buildings need art, costs and upkeep. Check them against the province investment levels and the era unlocks.
  - The province panel shows where each unit can be raised, and the hint explains why a place can't.
  - The AI needs to plan around it: build recruiting sites and march troops to the front.
  - Design first, with the user. Planned with the balance pass (M4), or with the battle system (M2) if its troop types change.
- **Trade: UI, gameplay and fun testing (user request 2026-11-12):**
  - **UI:** review the market panel, the merchant orders and the trade routes on the map. Is it clear what sells where and for how much, and what a merchant earns? Can an order be set up in a few clicks? Can you see your trade flows on the map?
  - **Gameplay:** do trade choices matter? Check route profits against tolls and transport, market competition with the AI, prices that react to supply, and whether merchants stay unused (the 2026-11-11 playtest found them unused).
  - **Fun testing:** a playtest focused on trade only, in a full game. Is it interesting to play a trading country, such as Venice, Genoa or Portugal? Are there decisions every few seasons, or is it set-and-forget? Write it up with findings and proposals, for approval before any redesign.
- **Economy: UI, gameplay and fun testing (user request 2026-11-12):**
  - **UI:** review the treasury breakdown, the province panel, investment, buildings and the goods views. Can the player see where money comes from and goes, and what to build next? Are the numbers explained in the hover hints?
  - **Gameplay:** check the money curve over a full game. The 2026-11-11 playtest found about 9,000 ducats by 1517 with nothing to spend them on. Check the money sinks, investment payback times, the tax levels, debt (#69), and whether small and large countries both have interesting choices.
  - **Fun testing:** an economy-focused playtest of a full game: the pacing of growth, meaningful choices, and how rewarding it feels to see provinces develop. Write it up with findings and proposals, for approval before any redesign.
  - Both run as part of the balance and fun pass (M4). Their UI findings feed the UI clean-up (M3).
- **Resource bar (user request 2026-11-12):**
  - A bar at the top shows each resource with its current value and how much it changed since the last turn, for example "Ducats 3548 (+45)".
  - Green for a gain, red for a loss.
  - Today the top bar shows only ducats, with the expected income per season, not what really changed.
  - Resources (suggested): ducats, research points, manpower or army size, merchants, prestige or score, and the country's key goods stock.
  - Hovering over a resource shows why it changed: the season's income and spending lines, like the treasury breakdown, plus one-off items such as a building, a battle or a loan.
  - Clicking a resource opens its panel, such as the ledger or the tech screen (suggested).
  - It needs the world to remember each resource's value at the start of the season, and the reasons for one-off changes.
  - Planned with the UI clean-up (M3). Mockups come first, together with the button style.
- **Debt and bankruptcy (user request 2026-11-12):** a hard debt limit, and past it bankruptcy: a reset with long-lasting penalties (castles ruined, units desert, provinces lost to creditors, an economy penalty). The model and penalties are still open. It has its own roadmap: [debt-and-bankruptcy.md](debt-and-bankruptcy.md). The v0.1.5 debt rule (#69) is an interim fix until then. It's planned with M4.
- **Architecture review and refactor (user request 2026-11-12):**
  - The goal: avoid spaghetti code. Use reusable modules and a game manager system, so the game is easier to maintain, debug and extend toward Steam.
  - **Today:** the campaign is about 20,000 lines. Some files do too much:
    - `world.py` (about 3,100 lines): map building, economy, war, supply, tech, investment, debt and saves in one class
    - `app.py` (about 1,500): input, every panel and the turn flow
    - `mapview.py` and `landscape.py` (about 1,200-1,500 each)
  - **Review first:** a written report with these parts, for the user's approval before any code moves:
    - a dependency map
    - the largest classes and functions
    - duplicated code (for example, the three game modes each with their own app and render code)
    - hidden coupling, global state and caches
    - the proposed structure
  - **Likely direction (suggested):**
    - **A game manager:** owns the turn and season loop, the active screen and the save/load lifecycle. Systems register with it instead of the app calling everything directly.
    - **Systems as modules:** economy, trade, military and supply, tech, investment, debt, diplomacy and seasons/weather, each with its own state, rules, `*_check`/action pairs and tests. `CampaignWorld` becomes a thin container.
    - **An event bus:** a system announces what happened ("unit attacked", "province captured", "debt seized"), and the UI listens. This feeds the floating text, the action log and the resource bar without wiring each one by hand.
    - **A reusable UI kit:** buttons, panels, lists, tooltips and modals, shared by every screen and by the UI clean-up's new button style.
    - **A shared rendering layer and caches:** one cache and budget helper for map art instead of several hand-made ones.
    - **Shared code across the three modes:** where it helps. Leave the legacy editor alone.
  - **Rules:**
    - Refactor in small, tested steps, with no gameplay change in the same commit.
    - Old saves keep loading.
    - The full suite and the long-run invariant tests pass after each step.
  - **When:** after the current bug-fix round (v0.1.5), and before the bigger features (battle system, events), so they are built on the new structure. The event bus and UI kit go first, because the floating text, action log, resource bar and UI clean-up need them.
- **Ideas from the owner's playtest (2026-11-12).** The bugs from the same playtest are filed as GitHub issues and fixed first.
  - **Ridges as natural borders (owner, 2026-11-12):** not a hard block on expansion, but geography that shapes it. Italian states stayed in the Po valley for a reason and didn't spread over the Alps, and the reverse holds too. Ridges should make natural borders show up in play. Built (v0.1.7 work): crests block moves, supply, ZOC and roads except through passes, and passes close in winter. To do, with the balance pass (M4):
    - land across a crest is harder to take and hold, but still possible: slower sieges and supply through a pass, more unrest or cost for provinces cut off by a ridge from the rest of the country, and higher peace costs for land across a crest
    - the AI prefers to grow within its own valley or basin, and crosses a ridge only when the prize is worth it
    - the art keeps the crest readable as a natural border, toned down to the landscape (round-3 mockups)
  - **Mountains and passes (decided, revised):** mountain hexes stay walkable. Only the hex edges along the main ridge crests block movement, so armies cross a ridge at named pass edges, which close in winter. The crest gets its own art (options for approval). Being built now.
  - **End-of-turn reminders:** before End season, list unfinished things: an unassigned merchant, research to fund, idle armies, an empty build queue. It can be turned off in Options.
  - **Achievements:** design ideas wanted (for Steam too).
  - **Random map types:** archipelago, one land (Pangaea), continents and more, as a later project. The random map is too much like Europe today. The map creator also needs less repetitive tiles.
  - **Focus on Age of Discovery:** maybe drop Conquest and Colonisation for now, focus on Age of Discovery, and bring the other modes back later on the same engine. Ideas are wanted for a **campaign mode** built on the Age of Discovery engine.
  - **Buildings on mountains** should add to the mountain (a fort on the slope, a mine in the rock), not replace it. **Goods upgrades** should change the tile: wheat fields grow, a port or barracks appears on the village tile, without changing the tile's character. Design options with mockups first.
  - **Seasons:** autumn trees (browns and oranges) and spring trees (blossom, fresh green). This needs a **climate map**, because not every place has four seasons: tropics wet and dry, the north long winters, deserts.
  - **Menus:** brainstorm menu designs (the start menu, the Esc menu, options).
  - **Diplomacy rework:** alliances, wars with war goals, claims to the throne.
  - **Stop steamrolling:** big countries start with an advantage. Ideas: overextension, coalitions against aggressors, war exhaustion, administrative limits, unrest in conquered land.
  - **Rebels:** unrest, revolts, independence movements.
  - **Triangle trade, with the slave trade (sensitive).** The owner wants it in because it is history, but handled with care and balanced so it is never a free win. The owner's model: like a board game where slave-trade cards give a lot of production now, but count as negative points at the end for each card kept. Other costs could be unrest, diplomatic penalties with some countries, later abolition events and stability. The design will be written carefully, reviewed by the owner, and presented respectfully, never as a reward or glorified.
  - **North Africa:** too much jungle; needs proper desert and savanna tiles. The terrain fix is a bug; the new tiles are art.
  - **Colonisation rework:** the UI and gameplay. The colonist unit may not be needed: for example, colonies could be founded from the province panel or by ships.
  - **Naval:** deep-sea exploration, blockades and ship battles, with design, UI and gameplay.
  - **Animated coastline:** a moving surf line along the coasts. Feasible: the coast edges are already known per hex, so an animated band of a few frames, or a shifting alpha mask, drawn only at close zooms. It needs a frame-budget check.
  - **City states:** design ideas wanted (for example, free cities like Venice, Genoa and the Hanse towns, with trade leagues and protection).
  - **Tribal nations in the New World:** tribes as their own nations, with lands, trade, alliances and resistance to colonisation. Designed with care.
  - **Kenney art audit:** track which Kenney Hexagon Pack art the game still uses. The owner likes it, but may replace it before the Steam release with similar art of our own. Keep a list and plan replacements.
  - **Map modes keep borders:** every map mode (terrain, goods, markets) keeps the country borders faintly, so you can see where your country ends. This is a small fix and is filed as a bug.
- **Multiplayer (owner request, 2026-11-12):**
  - Several human players in one Age of Discovery game, each a country. The other countries are AI.
  - **Steps, cheapest first:**
    1. **Hotseat:** players take turns on one computer. Fog and panels switch between players, with a "pass to the next player" screen.
    2. **Online, turn-based:** everyone plans their season, then the season resolves for all, with a turn timer. Possibly async (play-by-mail style), with a small server or Steam lobby.
    3. **Steam:** Steam lobbies, invites and networking (Steamworks), plus reconnect and save/resume for multiplayer games.
  - **Gameplay:**
    - simultaneous orders and how they resolve (battles when both move, contested markets)
    - diplomacy between humans: alliances, trade deals and chat
    - AI takeover when a player drops
    - fairness: starting countries, and the steamrolling question
    - victory rules (open question 1)
  - **Tech (needs the architecture plan):**
    - **Deterministic simulation:** seeded randomness and no hash-order effects. The same-behaviour oracle already checks determinism.
    - The game manager runs the season loop, so orders can come from any source: local, network or AI.
    - Saves double as the sync format, with desync detection using the world digest.
  - **When:** after the core game is fun in single player (M4) and the architecture refactor (at least Phases 1 and 3). Hotseat could come earlier. The design comes first, for the owner's approval.
- **Game music and sound (owner request, 2026-11-12):**
  - **Music:** a soundtrack in a period style (late medieval and Renaissance: lute, viol, recorder, drums, choir), changing with the situation:
    - calm in peace, tense in war, triumphant after a victory
    - by era (1480 / 1520 / 1575)
    - by season
    - by region (Mediterranean, northern, the Ottoman lands, the New World)

    It crossfades between pieces, with no hard cuts.
  - **Main theme (owner, 2026-11-12):** an epic, memorable title theme for the start menu and the opening.
    - **Mood references:** the owner named World of Warcraft's "Call to Arms", Baldur's Gate's opening theme, The Elder Scrolls opening themes, and Europa Universalis V. These set the feeling only. Nothing is copied: no melodies, no quotes, no sound-alikes.
    - **What to aim for:** a quiet opening (a solo instrument, or a voice over a drone) that builds to a full sweep of horns, strings, choir and war drums. A short, singable motif, our own "Hexa" theme, that comes back in the game's music:
      - softly in peace
      - in brass in war
      - as a fanfare at a new age
    - **Period colour:** an orchestra with Renaissance colour (lute, shawm, recorder, frame drum), so it sounds like 1480-1650, not modern fantasy.
    - **Shape:** about 2-3 minutes, with a loopable menu section and a short sting for the logo or Steam trailer.
    - **First step:** a written brief for the owner to approve: the mood words, the instruments, the motif idea and the structure. Then commission a composer, or pick properly licensed music. Credit it in the game.
  - **Sound effects:** clicks and UI feedback, end of season, march and battle, siege, a ship's bell, coins for trade, a fanfare for a new age, and a war alert. Sounds go with the floating text and event pop-ups.
  - **Options:** music and effects volume and mute, and a "music only in menus" choice.
  - **Rights:** only music and sound we may ship on Steam: commissioned, made for Hexa, or properly licensed (CC0 or a paid licence), with credits. Track every file and its licence, as with the Kenney art audit.
  - **Tech:** pygame.mixer, with music streamed (OGG), and sound effects preloaded and limited. The event bus (architecture Phase 1) triggers the sounds.
  - The design comes first (a short audio brief and a mood list for the owner's approval). Planned before the Steam release, after the event bus. An audio-director role joins the studio when it starts.
- **Game studio of agents (owner request, 2026-11-12):** work like "Claude Code Game Studios": a team of specialised agents, with a creative or game director who reviews designs, plus a game designer, a level and map designer, an art director, a UI/UX designer, a systems/balance designer, a QA and playtest lead, a code reviewer, and a producer who keeps the roadmap. Each has a clear role, inputs, outputs and review gates. The owner approves the roster first.
- **RPG-style event pop-ups:** interactive choices with good or bad outcomes. This is planned for the long-term roadmap's Phase 3 (History and events). Don't start it yet.
- **Known loose ends:**
  - balance
  - coastline following the hex shape
  - small towns
  - slow AI colonisation
  - the random-world start country

## 6. Proposed milestones (suggested)

Each design is approved by the user before its build starts. M1 and M2 must run in order, because battle cards come from techs.

**M1. Tech tree**
- Goal: research and eras drive the game.
- In: `tech.py`, world hooks, AI research, idea picks and funding, the tech screen, the new-age card pick, save migration, and tests.
- Depends on: the approved tech tree design.
- Done when:
  - `tests/test_tech.py` and `tests/test_tech_world.py` pass.
  - Era II cannot start before 1520 or before 4 era I techs; era III cannot start before 1575 or before 4 era II techs.
  - The player and the AI both pick an idea card at a new era.
  - An old save loads with its techs filled in.
  - T opens the tech screen, which shows all four branches with battle-card chips.

**M2. Battle system**
- Goal: contested hexes are fought on the shared tile with three lanes and cards.
- In: the battle screen, lanes, deck building from techs and generals, command points, and tactics from techs.
- Depends on: M1 (tech keys are the card sources) and `docs/design/battle.md`.
- Done when:
  - A battle runs from contest to result in the game.
  - The player's deck uses cards from its techs and generals.
  - Each tech's listed cards exist and do what their text says.
  - The battle panel matches the approved mockups, and the tests pass.

**M3. Visual polish round**
- Goal: the map looks smoother and more crafted, and the UI is cleaned up: a consistent button style, tidy panels, clearer layout.
- In: tile blending, closer zoom, smoother fog, dirt and grass edges, landmark tiles for a first set of cities, slower visible movement, and floating action text.
- Depends on: user approval of the mockups first. It touches different files from M1 and M2, so it can run in parallel (suggested).
- Done when:
  - The user approves the mockups.
  - Zoom goes beyond the current 34 px radius.
  - Edges blend in screenshots.
  - With the hex grid off (G), there are no gaps between tiles at any zoom (#71).
  - At least five named cities have landmark tiles.
  - Units the player can see move at a pace that can be followed, and moves under fog stay instant.
  - Actions show floating text whose font and colours the user approved.
  - The same actions are listed in an action log box that the player can read back later.
  - Screenshots are reviewed.

**M4. Balance and playtest pass**
- Goal: a full 1480 to 1650 game feels right.
- In: research pace and tech costs, battle numbers, economy and army upkeep, and AI pace, including colonisation. It also includes the trade and economy UI, gameplay and fun tests (section 5).
- Depends on: M1 and M2, because the numbers need the finished systems.
- Done when:
  - Seeded full runs to 1650 hit the pace targets: 2 to 6 RP a season for a mid-sized country, a tech every 3 to 10 years, and about 70% of the tree by 1650.
  - The AI reaches era III in most runs.
  - No country stalls at zero research (suggested).
  - The findings are written up for the user.
  - The trade and economy fun-test reports are done, and their approved proposals are built.

**M5. World and naming fixes**
- Goal: fix the loose ends that make the map feel unfinished.
- In: a review of the starting map (fewer starting towns and villages), province names, coastlines that follow the hex shape, small towns, the random-world start country, and slow AI colonisation if M4 did not cover it.
- Depends on: M3 for coastline and town art, and on the naming choice in section 7.
- Done when:
  - A random world gives a sensible start country.
  - Province names no longer read "near X", under the scheme the user picks.
  - Coastlines no longer follow the hex shape in screenshots.
  - Small towns show on the map.
  - AI colonisation runs at the agreed pace.

## 7. Answers so far (2026-11-11)
- **Winning:** undecided. Keep the 1650 ranking for now.
- **Game length:** many evenings, a long campaign. Pace research, growth and AI for that.
- **Battles:** both. Card battles on the shared tile, plus a quick auto-resolve option, used for small fights and AI-vs-AI.
- **Priority:** polish first. After the tech tree (M1, already started), do the visual polish round (M3) before the battle system (M2).

## 8. Open questions for the user

1. What does winning look like in Age of Discovery? The notes give win rules only for the old conquest game.
2. How long should one game take? Age of Discovery spans 170 seasons, and the early notes said 15 to 30 minutes.
3. ~~Is this single-player only, or will multiplayer come later?~~ Answered 2026-11-12: multiplayer is planned (see the backlog: hotseat, then online, then Steam).
4. Which screen size is the target? The default is 1280x720, and the options go up to 1920x1080.
5. How hard should the AI be, and should every country play the same?
6. ~~Does the new battle system replace the current three-unit front-line battles, or sit next to them?~~ Decided 2026-11-13: it replaces them.
7. For province names: real regions or counties, generated local names, or a mix?
8. In a random world, should the player choose the start country or get one at random?
9. What matters more next: more depth (new systems) or more polish (look and feel)?
