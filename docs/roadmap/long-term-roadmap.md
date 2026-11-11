# Hexa long-term roadmap

Status as of 2026-11-11. This is the big picture. The near-term plan (M1 to M5) is in `docs/roadmap/roadmap.md`, and the battle design is in `docs/design/battle.md`. Items marked "(suggested)" are my ideas, not decisions from the user. Phase lengths assume about a few months of work each at the current pace.

## 1. Where Hexa is heading

The finished game is a long-campaign Europa Universalis-like strategy game on the 1480 to 1650 map, with a random world as the alternative. A full campaign takes many evenings, so pacing matters as much as depth. Each country has an economy, diplomacy, religion, rebels and a navy, and history unfolds through events that the player can shape. The look stays with the Kenney hexagon tiles, with each part given its own distinct style. The conquest and colonisation modes stay as smaller side games.

**Final goal (decided by the user, 2026-11-11): publish Hexa on Steam.** Every phase works toward a game that meets Steam's bar: stable, polished, with clear goals and a store page.

## 2. Phases

### Phase 1. Foundations (the near-term M1 to M5)
- **Theme:** make the core systems solid before adding more.
- **Goal:** the tech tree, polish round, battle system, balance pass and world fixes are in and tested.
- **Features (summary, see `docs/roadmap/roadmap.md` for detail):**
  - M1 tech tree, with research, the era gate and idea cards
  - M3 visual polish (moved ahead of the battle system by the user's choice)
  - M2 battle system: card battles on the shared tile with a three-lane mini-map, plus a quick auto-resolve
  - M4 balance and playtest pass
  - M5 world and naming fixes
- **Depends on:** nothing new.
- **Finished when:** the M1 to M5 "done when" lines are met, and a full 1480 to 1650 seeded game can be played from start to end without a stall.

### Phase 2. Living world
- **Theme:** countries have politics, not just armies and money.
- **Goal:** diplomacy, stability and religion make each country feel different and alive.
- **Features:**
  - Diplomacy depth: alliances, peace terms, vassals, royal marriages and a relations score per country pair.
  - Stability and rebels: unrest from taxes, religion and defeat, which can spawn rebel stacks.
  - Government types (suggested): a few forms, such as monarchy, republic and merchant council, each with its own rules and bonuses.
  - Religion and the Reformation from 1517: faiths spread through provinces, and a reform event splits the map.
- **Depends on:** Phase 1 (the tech tree idea cards and the economy numbers must be stable).
- **Finished when:** two runs with different countries feel different in diplomacy and stability, and a Reformation event splits the religions on the map.

### Phase 3. History and events
- **Theme:** the big moments of the period happen, and the player can respond.
- **Goal:** scripted historical event chains with choices, plus emergent events that do not depend on the script.
- **Features:**
  - **RPG-style event pop-ups (user request 2026-11-11).** Interactive, actionable pop-ups with good or bad outcomes. The design is not settled; these were the questions on the table:
    - kinds: province life, named characters with traits, exploration, history chains
    - outcomes: dice with shown odds, fixed results, or hidden results
    - look: an illustrated parchment card or a simple dialog
    - frequency: about 1 a year, every few seasons, or a player option
  - Historical event chains with choices, such as the fall of Granada (1492), Columbus's voyages, the Treaty of Tordesillas, the Ottoman sieges, the Reformation and the Armada.
  - Explorer and colonial events, such as discoveries, native contacts and disease.
  - Native nations as real actors with their own rulers and alliances, not just villages.
  - Trade companies (suggested): charters that bundle colonies and routes under one owner.
- **Depends on:** Phase 2 (diplomacy and religion give the events their hooks).
- **Finished when:** each major event chain fires in a suitable seeded run, shows its choices, and the outcome changes the map.

### Phase 4. War and sea
- **Theme:** the navy matters, and the battle system is fully mature.
- **Goal:** naval war, blockades and piracy join the land war.
- **Features:**
  - Naval combat with fleets, admirals and boarding.
  - Blockades that cut a coastal country's trade routes.
  - Piracy and privateers, including letters of marque.
  - Sieges and fortress depth: longer sieges, siege engineers and fortress upgrades (suggested).
  - Battle system maturity: generals' traits, veterans, the card and auto-resolve balance, and sneaky cards for events.
- **Depends on:** M2 battle system (Phase 1) and the diplomacy of Phase 2 (for war declarations and peace terms at sea).
- **Finished when:** a seeded war can be fought on land and sea with a blockade, and auto-resolve gives results close to card battles in test runs.

### Phase 5. Game feel and onboarding
- **Theme:** a new player can learn the game and finish a campaign feeling it was worth the time.
- **Goal:** clear goals, a proper ending, sound and performance.
- **Features:**
  - Victory conditions: see section 4 (undecided). The current placeholder is the 1650 ranking.
  - Score and an end-of-game screen with the key numbers and history.
  - A tutorial or first-game guide.
  - Music and sound.
  - UI polish and accessibility: text size, colour-blind-safe map modes, key remapping (suggested).
  - The UI clean-up starts early, in Phase 1 (M3), at the user's request: a consistent button style and states, tidy panels, clear hierarchy, fewer clicks. Phase 5 finishes it to Steam standard.
  - Performance at 14,000 hexes on slower PCs (suggested; it can start during Phase 2 and continue).
- **Depends on:** Phases 2 and 3, because the victory and score need the systems that produce them.
- **Finished when:** a new player can finish a campaign with the guide, the end screen shows a clear result, and the map stays playable at an agreed frame rate on a target low-end PC.

### Phase 6. Release on Steam
- **Theme:** the game ships on Steam.
- **Goal:** a stable, packaged build sold or released on Steam.
- **Features:**
  - A packaged Windows build (exe), with an installer or zip.
  - Save versioning and stability, so future updates do not break saves.
  - Settings and documentation, and crash reporting.
  - A random-world setup screen (choose the seed, size and countries).
  - Data files that are easy to edit, so the community can change balance (suggested; mod support later).
  - **Steam release work:**
    - a Steamworks partner account (the one-off app fee) and a store page with capsule art, screenshots, a trailer and a description
    - Steam build upload (SteamPipe)
    - achievements and cloud saves (suggested)
    - a "Coming soon" page early, to gather wishlists
    - a demo or a Steam Next Fest entry (suggested)
    - an age rating questionnaire
    - an in-game licence/credits screen (the Kenney assets are CC0, but credit is good practice)
    - Early Access first, then a full release (suggested)
  - Stretch: hot-seat multiplayer first, then online multiplayer if wanted; other start dates (for example 1444 or 1600).
- **Depends on:** Phase 5 (a finished game to package). Save versioning already exists and grows with each phase.
- **Finished when:** Hexa is live on Steam, it installs and plays a full campaign on a fresh Windows machine through Steam, and an old save still loads after an update.

## 3. Dependencies at a glance

```
Phase 1 Foundations (M1 tech, M3 polish, M2 battles, M4 balance, M5 world)
   |
   +--> Phase 2 Living world (diplomacy, stability, religion)
   |       |
   |       +--> Phase 3 History and events
   |               |
   +---------------+--> Phase 5 Game feel (victory, score, tutorial, performance)
   |                         |
   +--> Phase 4 War and sea  |
   |   (needs M2 + Phase 2)  |
                              +--> Phase 6 Release (exe, saves, settings, stretch)

Save versioning: already in place (`saves.VERSION` plus migration of old saves), extended every phase.
Performance work: start in Phase 2 (suggested), finish in Phase 5.
```

Phase 4 can run alongside Phase 3 if the user wants war earlier.

## 4. Decisions the user will need to make

Short questions, asked before each phase starts, so the build is not blocked:

- **Phase 1:** When M1 is done, should the tech screen be the main way to see the era, or should a small era panel also show on the main screen?
- **Phase 2:** How many government types do you want (suggested: three to four)? Is religion in scope at all?
- **Phase 2:** Should rebels be able to take a province and form a new country?
- **Phase 3:** How much history should be scripted, and how much emergent? (suggested: scripted chains for about ten big events, and random events for the rest)
- **Phase 3:** Are native nations allowed to become playable countries?
- **Phase 4:** Are pirates and privateers in, and is naval boarding wanted?
- **Phase 5, victory:** Which win condition should be the default? Options: the 1650 ranking (current placeholder), reaching a set score, holding a set number of provinces, completing a set number of historical goals, or a mix. Also: should the player be able to lose, and how?
- **Phase 5:** How long should a campaign be? The notes say "many evenings". Should there be a quick mode for short games?
- **Phase 5:** Is a tutorial wanted, or is a short written guide enough?
- **Phase 6:** Is hot-seat multiplayer a yes, and is online multiplayer ever wanted?
- **Phase 6:** The target is Steam (decided). Open questions: Early Access or a full release first? Paid or free, and at what price? A demo for Steam Next Fest? When should the "Coming soon" page go up?
- **Any phase:** Which screen size and PC is the low-end target for the performance work?

## 5. Risks and how to handle them

- **Performance on the big map.** About 14,000 provinces and the finer tiles may be slow on older PCs. Handle it with a performance budget per phase, profiling before each big feature, and drawing only what is on screen (suggested).
- **Balance gets harder as systems grow.** Every new system changes the numbers of the others. Handle it with seeded test runs that are repeated after each phase, and by keeping numbers in data files (`data.py` and the other data modules) so they can be tuned without code changes.
- **Art consistency across many Haiku-made assets.** Many workers may produce tiles that look different. Handle it with a style sheet in the repo (palette, outline weight, tile size), a review step where the planner checks screenshots side by side, and a rule that art is shown to the user in mockups before it is built.
- **Old saves breaking.** Each new feature adds fields to the save. Handle it with a save version number, a migration function per version (the tech tree already uses this), and a test that loads a saved file from each earlier version.
- **Scope creep.** The list of ideas keeps growing. Handle it by holding new ideas in the backlog until a phase is planned, as the user asked.
- **Long gaps between sessions.** Designs get lost between sessions. Handle it with the mockups folder and a short notes file per phase (suggested).

## 6. How we work

The user approves each design with mockups before any code is written. The planner (the main session) splits the work into small, well-scoped tasks and gives them to Haiku workers, who build them on the named files only. The planner then reviews each result: it reads the diff, runs the tests, and looks at screenshots, and sends fixes back to the same worker when needed. Once a feature passes review and the user has seen it, the work is pushed straight to master on GitHub. Ideas that come up during a phase go into the backlog and are not built until their phase starts.
