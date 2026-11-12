# Hexa roadmap

Status as of 2026-11-11. Sources: the project notes, `docs/design/tech-tree.md`, `docs/design/tech-tree-build-spec.md` and the Hexa README. Items marked "(suggested)" are my inferences, not decisions from the notes.

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
- bug-fix releases: v0.1.3 (shipped), then kioba's v0.1.5 to v0.1.7
- the testing foundation
- M1 (the tech tree) shipped as v0.1.2.
- The first part of M3 (the blended map look and winter passes) shipped as v0.1.4.

## 2. Guiding principles

- **Ask first, then build.** Confirm the look and play of any big feature with the user, with mockups, before any code is written.
- **Keep the game's style.** New work uses the Kenney tile art and extends the existing modes. Do not write a parallel game.
- **Be creative inside that style.** The user rejected look-alike tiles. Each good, unit and building should look distinct.
- **Build big chunks.** The user prefers a whole feature built, tested and then shown, rather than many small steps.
- **Push straight to master.** The user declined feature branches.
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
  - Limit recruiting so that where you raise an army matters. The suggested rules:
    - infantry in towns and cities, or with barracks
    - cavalry in provinces with horses or a stable
    - mercenaries in rich trade cities
    - elite troops only with their building
    - colonies raise only militia
  - The province panel shows where each unit can be raised, and the hint explains why a place can't.
  - The AI needs to plan around it: build recruiting sites and march troops to the front.
  - Design first, with the user. Planned with the balance pass (M4), or with the battle system (M2) if its troop types change.
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
  - At least five named cities have landmark tiles.
  - Units the player can see move at a pace that can be followed, and moves under fog stay instant.
  - Actions show floating text whose font and colours the user approved.
  - The same actions are listed in an action log box that the player can read back later.
  - Screenshots are reviewed.

**M4. Balance and playtest pass**
- Goal: a full 1480 to 1650 game feels right.
- In: research pace and tech costs, battle numbers, economy and army upkeep, and AI pace, including colonisation.
- Depends on: M1 and M2, because the numbers need the finished systems.
- Done when:
  - Seeded full runs to 1650 hit the pace targets: 2 to 6 RP a season for a mid-sized country, a tech every 3 to 10 years, and about 70% of the tree by 1650.
  - The AI reaches era III in most runs.
  - No country stalls at zero research (suggested).
  - The findings are written up for the user.

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
3. Is this single-player only, or will multiplayer come later?
4. Which screen size is the target? The default is 1280x720, and the options go up to 1920x1080.
5. How hard should the AI be, and should every country play the same?
6. Does the new battle system replace the current three-unit front-line battles, or sit next to them?
7. For province names: real regions or counties, generated local names, or a mix?
8. In a random world, should the player choose the start country or get one at random?
9. What matters more next: more depth (new systems) or more polish (look and feel)?
