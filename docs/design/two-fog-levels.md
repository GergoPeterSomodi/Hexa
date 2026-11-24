# Two fog levels (issue 446; issue 435 follows)

Status: draft for the owner. Written 2026-11-24. Nothing is built. The owner's decision (ui-family-audit.md, owner's
answers, number 3) is the starting point: deep fog and light fog, the same for every country, the AI included.

## 1. The rule in plain words

There are two fogs, and the line between them is one question: has this country ever seen this hex?

**Deep fog: never discovered.** The country has never seen the hex. Nothing is shown: no owner, no people, no goods, no
buildings. The tile window says "Unexplored".

**Light fog (the fog of war): discovered, not in sight now.** Everything about the land stays visible and stays live: who
holds it, the people, the goods, the buildings and works, the fortress and its level, the tile window. If Venice builds a
mill on a hex you discovered in 1481, you see the mill in 1482 even if no one of yours stands near. Only three things are
hidden, because they are about people moving and fighting, not about land:

1. **Armies:** that they are there, their men, their orders and their routes.
2. **Their movement:** a march across light-fog land is not replayed and not told.
3. **Battles (and sieges' inner numbers) you are not part of or did not witness.**

**In sight now** is the third state and changes nothing but these three: you read the armies, the battles you witness and
the siege and garrison numbers as today (banded men, rounded garrisons, as M7 and M8 already do).

| What you look at | Never discovered | Discovered, not in sight | In sight now |
|---|---|---|---|
| Owner, people, goods, buildings, works | hidden | shown, live | shown, live |
| A fortress and its level | hidden | shown | shown |
| Armies on the hex, their orders | hidden | hidden | shown (banded men for a foreign one) |
| A battle on the hex | hidden | hidden unless you are a side or witnessed it | as witnessed |
| Garrison of a fortress | hidden | estimate only (see 3.4) | rounded to 100 |

Examples.
- You discovered Venice's coast in 1481 and then never sailed there again. In 1485 its harbour town has grown and a
  castle stands. You see both, because land is not hidden once found. You do not see Venice's army camped beside it.
- A Venetian army walks from a light-fog hex to another light-fog hex: no token, no replay, no log line for you.
- Milan takes your border town in a war. You still see that town, who holds it and its people (light fog); you see
  Milan's army in it only if your land or army sight reaches it.
- A hex on the far side of a mountain you never reached: dark. A country whose every hex is dark is "unknown" to you.

The same code answers for the player and for every AI seat.

## 2. How fog works today (read from the code)

### 2.1 The data

- **Sees (in sight now).** `Sight.sees(game, tag, hex)` (godot/core/systems/sight.gd): true when the hex is within the army
  sight of one of the country's armies (the bitset the sight cache rebuilds in `Sight.refresh`), or within `land_sight`
  (data, 1) rings of a hex whose **owner byte** is the country. Derived, not saved (`SightCache`, sight_cache.gd).
- **Explored (discovered).** `Country.explored`: a saved bitset, one bit per hex, "ever seen". It is written only by
  `Sight.setup` (game start: the land sight of the start), `Sight.see_path` (the steps of an army's walk, written by the
  movement phase) and `Sight.season` (the vision phase: land sight and army sight of the season). It is never cleared.
  `Sight.explored(game, tag, hex)` reads a bit. The save already stores it (digest-hashed), so **it is the discovery set**
  the owner asks for.
- **Knows (a country is known).** `Knowledge.knows(game, viewer, other)`: same tag, or a shared land border
  (`Territory.neighbours`), or `Sight.explored_any` (the viewer has explored any hex `other` holds; kept per viewer as a
  256-byte "known" set in the sight cache). `Knowledge.known` is the list.
- Today **no view hides a land fact on a per-hex basis** except the garrison and siege numbers. Land facts are gated only
  by `knows` on the owner (a country you know is shown as a whole, a country you do not know is "unknown").
  The drawn map has no fog layer yet (tile_map_view.gd says "the tint and the fog arrive later").

### 2.2 Every view that applies a fog rule

| File (godot/...) | The rule it applies today |
|---|---|
| core/views/knowledge.gd | The home of the rules: `knows`, `known`, `unknown_count`, `sees`, `men_of` (banded, -1 for an unknown country), `garrison_estimate` (own exact / seen rounded to 100 / unseen assumed full), `armies_seen` (foreign armies on hexes in sight, men banded), `witnessed` (events), `battle_access` (exact side / seen witness / hidden), `siege_access` (exact side / seen / hidden) |
| core/systems/sight.gd, sight_cache.gd | Sees, explored, known, witnesses (`witnesses_of`: owners within land sight of the hex, armies' watchers, the actor) |
| core/views/odds_view.gd | `_garrison_access` (exact / seen / hidden), `_in_view` (sees, or own or held land); hidden defence has no word and no ratio |
| core/views/battle_view.gd | `Knowledge.battle_access`, `witnessed` for the log line, `knows` for naming the sides ("unknown" role words) |
| core/views/siege_view.gd | `siege_access`, `sees`, `knows` for names |
| core/views/hex_card.gd | `_fortress_text` (own exact / seen rounded / "a garrison"), `_sees_siege` |
| core/views/army_view.gd | `visible`: own, or foreign on a hex in sight **and** the country known |
| core/views/people_view.gd | Foreign land: banded when the owner is known, nothing when the owner is unknown |
| core/views/country_card.gd, shell/panels/country_panel.gd | Treasury, people and men banded for a known country, hidden for an unknown one |
| core/views/improve_card_parts.gd | A foreign owner is named only if known |
| core/views/move_preview.gd, core/systems/movement.gd | `_foreign_reason` (names the owner only if known and the hex explored), `_fog_safe` and `_storm_in_view` (a reason that names an unseen hex becomes the generic words) |
| core/views/replay_marks.gd, replay_plan.gd, shell/map/move_replay.gd | A battle mark and a walk shown only on hexes in sight |
| core/views/summary_war.gd, summary_armies.gd, study_military.gd, study_rankings.gd, season_summary.gd | Armies from `armies_seen`; war entries by `witnessed`; known countries only |
| core/views/log_lines.gd, log_lines_war.gd | `witnessed` and `knows` (an unknown actor is unnamed) |
| core/views/study_history.gd, cards_war.gd, area_lines.gd | Read through the views above |
| core/systems/battle_end.gd, movement_phase.gd, battles.gd | Set the `witnesses` of battle and walk events from `Sight.witnesses_of`; the walk's per-step `seen` bytes for the player |
| shell/map/map_wars.gd, war_marks.gd, map_armies.gd, army_tokens.gd, path_marks.gd | Draw only what the views allow (`Knowledge.sees` for marks) |
| shell/hud/odds_card.gd, move_card.gd, hex_menu.gd, map_hover.gd; shell/panels/hex_war.gd, army_panel.gd, army_war.gd; shell/screens/battle_dock.gd | Draw the views' text; no rule of their own |
| core/ai/ai_know.gd | The AI's door (below) |
| tests: core/tests test_knowledge, test_people_view, test_odds_view, test_move_preview, test_replay_marks, test_log_lines_war, test_ai_fog, test_ai_door, test_ai_know; shell tests test_map_armies, test_war_marks, test_odds_card | The fog's tests |

Not found in the code: a fog on the map overlays and modes (mode_overlay.gd, map_people.gd read people straight from the
state or the PeopleView) and on the minimap (hud.gd). They are listed as a gap in 3.1.

### 2.3 The AI door

`AiKnow` (core/ai/ai_know.gd) is the one file of core/ai that reads the game (`test_ai_door.gd` scans the others for
`game.state`, `Armies.`, `Occupation.` and so on). Its rule (m8-build-spec.md 4.3): own country exact; the map, owners,
occupiers, pieces, fortresses, wars public and exact **everywhere** (this includes hexes the AI has never seen: today the
AI has no deep fog); another country's men banded and only if known; foreign armies only on hexes in sight, banded, with no
orders; battles as witnessed; garrisons as `garrison_estimate`; odds through `OddsView`.

`test_ai_fog.gd`: Milan's whole turn (its acts, trace and luck) is the same when Venice's unseen armies are moved and
re-ordered, unseen garrisons lowered by 200, Venice's treasury and works edited, and the luck reseeded. Each `AiKnow` read
is compared on the two copies and a planted leak per read must make them differ. "Works edited" counts as a fact Milan
may not know today.

## 3. What changes, view by view

### 3.1 What "discovered" means

`discovered(country, hex)` = the `explored` bit. No new data. Three questions the owner asked.

**How it starts (1480).** `Sight.setup` sets `explored` to the country's land sight: its own hexes and one ring round them
(`land_sight` = 1). That is a thin world: a neighbour's land beyond the border ring is dark. Today it does not matter much,
because `knows` also counts a shared border, so a bordering country is "known" though its interior is dark; its men and
treasury are banded from the start. Under the new rule the interior of a bordering country is dark (deep fog) while its
border ring is visible. Two choices (owner question 1): keep radius 1 (the pinned test counts of M4.5/M5 hold), or add a
data constant `start_discovery_radius` (a scenario field) so a country starts knowing more of the world round it.
The recommendation below is to keep 1 and decide after a playtest, because a bigger start ripples into the
"unknown countries" numbers pinned in the tests and the AI's `knows`.

**How it grows.** As today: land sight at each vision phase (season), the steps of every walk (and, at the season's end,
the ring of each army), and later ships and scouts (M19). Nothing is added. Conquest and peace gains (3.6) need one
change: the new land is marked at once, not at the next season.

**Saved.** Already saved, already in the digest. **No FORMAT bump is needed** for the discovery set itself. A FORMAT bump
is needed only if the owner chooses a remembered "last known" state for light fog (not asked: the owner said the land
stays live, not remembered), so none.

**Neighbours' land you never saw.** Hex by hex: dark. The country panel for a country with at least one discovered hex
opens (it is "known") and shows only the numbers a country panel shows (3.5); its tile list shows only discovered tiles.
A country with no discovered hex is "unknown" as today (no panel, unnamed in logs).

### 3.2 Land views: shown for every discovered hex, in sight or not

| View | Change |
|---|---|
| `HexCard` / tile window / `TileView` (the planned window, ui-family-audit 3.3) | Replace the "Explored, not in sight" row (ground only, no owner) by: **everything of the land stays**; only the Army block and the Siege block's inner numbers need sight. Never explored: "Unexplored", as drawn. Supersedes ui-family-audit open question 3 |
| `PeopleView.at` | Gate by `Sight.explored(viewer, hex)` instead of `knows(owner)`. A known country's undiscovered hex is hidden (today it would show banded people: a small leak the new rule closes) |
| `Improve` / works cards for foreign land, `improve_card_parts.gd` | Show owner and works on discovered hexes; naming the owner still needs `knows`, which is true for any discovered hex of that owner |
| Map overlays and modes (`mode_overlay.gd`, `map_people.gd`, `work_marks.gd`, `capital_marks.gd`) | Read through a new `Knowledge.discovered(game, viewer, hex)`; undiscovered hexes drawn as deep fog; discovered hexes drawn fully, with no "out of sight" tint on land. The fog layer of tile_map_view.gd ("arrives later") becomes: deep fog dark; light fog a faint tint over **armies only** (tokens are not drawn there) |
| Minimap | Same two levels: undiscovered dark; discovered shows owners; no army pips outside sight |
| Chronicle events about land (`work_started`, `work_finished`, `work_cancelled`, `town_grew`, `district_declined`, `district_captured`) | Witnessed by every country that discovered the hex (not only those whose sight holds it). `Sight.witnesses_of` gets a second rule for these kinds: one bit test per country (at most 60), cheaper than a disc walk |

### 3.3 Army, battle and orders views: unchanged in rule, one-line changes

- `Knowledge.armies_seen`, `ArmyView.visible`, `replay_marks`, `move_replay`, `unit_moved` and `march_halted` witnesses,
  `battle_access`, `BattleView`, `SiegeView`'s numbers: the rule is already "in sight or a side". Nothing moves.
- Light fog on land is now the normal case, so these views must not rely on "unseen land is unknown land": the only
  change is removing the extra `knows` clause in `ArmyView.visible` where it makes an army on seen land invisible
  because its country is unknown (cannot happen once the land is discovered, so a no-op; keep the test).
- `MovePreview` reasons: a reason that names an unseen hex is replaced by the generic words today (`_fog_safe`). Under the
  new rule a reason that names a **discovered land** fact (the owner, the fortress) may be named; one that names an army
  or a march on an unseen hex stays generic. Small edit plus tests.

### 3.4 Garrisons and besieged castles

Is a castle garrison an army? In the code it is a number on the hex (`state.garrison`), not an `Army`, and the owner's own
doctrine (M7 D49) already treats it as hidden men. **Recommendation: yes, treat the garrison as an army number.** The fortress
itself (that it exists, its level, its owner or occupier) is land and stays visible in light fog; the men inside stay
estimated: assumed full outside sight, rounded to 100 in sight, exact for the holder (today's `garrison_estimate`, no code
change). A new line in the tile window says "garrison: not seen".

A **besieged castle** in light fog: the fact "this fortress is under siege" is a state of the land, but it is the work of an
army you cannot see. Options in question 4. Recommended: show only the word "Besieged" (and who holds it now: a captured
hex is a change of holder and is public, as today) and hide the meter, the men and the besieger's name until the hex is in
sight; a side sees all. The siege's "falls in N seasons" forecast stays with the sides.

A **battle** on a light-fog hex: unchanged. You see its result as a change of holder (land) and, if you were not a witness,
no battle record and no log line (`battle_access` is "hidden"). The chronicle's `district_captured` becomes visible (land).

### 3.5 Country panels and the economy numbers

The owner said "presumably the country panels and the economy numbers of the land". Two kinds of numbers must be told apart.

- **Facts of land (per hex or summed over discovered hexes):** people, goods the land makes, buildings, works under way,
  towns and their size. These follow the land: shown **exact** on every discovered hex, in the tile window and in the sums
  over discovered hexes of a country ("seen so far"). Today foreign people are banded; the new rule shows the number the
  tile window can already read, so banding adds nothing but a mismatch. Question 3 asks the owner to confirm exact.
- **Facts of the country's secret ledger:** treasury, debt, stores, income, upkeep, men under arms, war plans. These are not
  land. Stay as today: banded for a known country (`men_of`, treasury band), hidden for an unknown one. Men under arms is
  an army fact, so stays banded.

Consequence for `CountryCard`: a known country's panel adds a line "land seen: N of M hexes" (M hidden) so the player sees
that the picture is partial.

### 3.6 Conquest and the sight of land (issue 435)

**What M7 occupation gives today.** `Sight` reads only the **owner byte** (`game.state.owner`). A hex captured in war changes
its occupier byte (`Occupation.capture`), not its owner, so:
- the old owner keeps full land sight there (it still owns the hex) and sees the occupier's army inside its land;
- the occupier gains **no sight from the hex**; it sees the ring of its armies standing there, and only while they stand;
- a cession in a peace (`owners_changed`) moves the owner byte: the old owner loses the land sight at once, the new owner
  gets the land sight and (via `_or_land`) the discovery bits **at the next vision phase** (a season later).

**What the new rule needs.**
1. Land sight counts the controller too: a country sees a hex it owns **or** holds as occupier, and the ring of it.
   `SightCache.land_of` currently loops `Territory.districts` (owner bytes); add the held hexes
   (`Occupation.controller_id`). It must be dropped by the `controllers_changed` event as it is by `owners_changed`.
2. The occupier discovers the hex at the moment of capture (bit set in `explored`), so its tile window works at once.
3. A ceded hex is discovered at the moment of cession, not next season (the season lag is a visible gap in the new tile
   window: a conquered town shown as "Unexplored" for a season is a bug of the new rule).
4. The old owner keeps its discovery bits (they are never cleared): it still sees the town, its holder and people (light
   fog), and sees armies there only through its own sight (the ring of the land it still owns, or its armies). This is the
   fix the owner expects ("conquest changes who sees the land").
`explored` then has one more writer (capture and cession), amending R4 of the M6 spec ("only three writers"); a test pins the
writers.

### 3.7 Nobody gets a blind spot, nobody an edge

The AI sees the same land facts a player does (discovered hexes) and is blind to the same three things. See 4.

## 4. The AI

**Does it change its decisions?** Almost not. Today the AI door already reads every owner, piece, fortress and war exactly
over the whole map (`AiKnow`: "public"), and reads people only on its own land. The new rule therefore:
- grants nothing new that a decision uses (land facts of discovered foreign hexes it does not read);
- removes one wrong claim ("land of any country is public to the AI"): add a deep-fog gate. An AI seat reads another
  country's land (`AiKnow.land_of(target)`, `fortresses_of(enemy)`, `area_state`) only on hexes it has discovered.
  Targets it has not discovered cannot be picked. A neighbour's border ring is always discovered, so war with a neighbour
  and its first targets are unchanged; the interior of a big enemy is chosen only after the army walked there.
- fairness: the player and the AI now follow one rule and one function (`Knowledge.discovered`); no blind spots are
  *given* to the AI, none are taken.

Expected effect on the pinned behaviour: small; `test_ai_determinism` and `test_ai_war_aims` runs may change in a few
seed-fixture cases (targets deeper than the border ring) and must be re-pinned with a written reason.

**The door and the planted leaks.** `test_ai_door.gd` stays (the scan list gains `Sight.` if not already named). What a
leak means now, in `test_ai_fog.gd`:
- Still a leak: another country's **armies** (position, order, route, men), unseen **battles**, a **garrison** beyond the
  estimate, and its secret ledger (treasury, stores, works under way beyond what land shows). The two copies of the test
  keep changing exactly these.
- No longer a leak (the test must not count it): a discovered hex's people, goods, buildings, works, owner. Move "works
  edited" out of the changed facts for discovered hexes; edit works only on **undiscovered** hexes in copy B.
- New leak, new plants: a read of an **undiscovered** hex (owner, level, fortress) through any `AiKnow` read must fail the
  comparison. Add copy-B edits of owners and pieces on undiscovered hexes and one planted-leak step that reads the state
  straight.

## 5. Conquest sight (summary of 3.6)

Land sight = held land (owner or occupier) plus ring; capture and cession set discovery at once; the old owner keeps the
discovery. Issue 435 is closed by this section and by the tile window needing no change (ui-family-audit 3.3 already says so).

## 6. Saves, tests, monkey run, performance

**Saves.** The discovery set is `Country.explored`, already in `SaveFile` FORMAT 6 and its digest. Nothing new is stored,
so **no FORMAT bump**, and old saves load unchanged. Only if the owner picks a "last known state" memory for light fog
(not recommended, not asked) is a bump needed.

**Tests.** New or changed (all godot/tests/core unless noted):
- `test_knowledge.gd`: `Knowledge.discovered`; `garrison_estimate` unchanged; new cases per row of the table in section 1.
- `test_people_view.gd`: gate by the hex bit (P: a known country's undiscovered hex shows nothing).
- `test_tile_view.gd` (planned): the three states; the Army and battle blocks hidden in light fog; a viewer who sees nothing
  (R8 of the UI audit) sees all land of discovered hexes and no army.
- `test_vision.gd` / sight tests: held land is sight (occupier); capture and cession discover at once (P: no one-season lag);
  `witnesses_of` for land kinds uses discovery.
- `test_log_lines*.gd`: a land event on a discovered hex is told to the viewer; an army event outside sight is not.
- `test_ai_fog.gd`, `test_ai_door.gd`, `test_ai_war_aims.gd`: as in 4.
- `test_save_load` and the replay/digest tests: green without edits (save, load, save is byte-equal).
- Shell tests: `test_map_armies`, `test_war_marks`, `test_odds_card` unchanged; a fog-layer test when the layer lands.
**Monkey run.** The existing monkey (random-order stress) must run with a viewer in light fog and one with deep fog on each
tile; the assertion is "no view returns a land fact for an undiscovered hex and no army fact outside sight". Add this
check as a view-level invariant to the monkey's per-turn loop.
**Performance.** Discovery is one bit test per read, the same cost as `Sight.explored` today. Land-event witnesses: a pass
over at most 60 countries instead of a disc walk. The extra land sight for occupiers adds the held hexes to `land_of`
(rebuilt on `controllers_changed`, which fires once per phase), at most the cost of one more country's land. The fog layer
of the map reads the bitset once per frame change, not per hex. No measurable change expected; measure `season` and `Sight`
costs in the existing perf probe before and after.

## 7. Build plan

| Group | What | Size |
|---|---|---|
| A | `Knowledge.discovered`, land-event witnesses by discovery, `PeopleView` gate, `ArmyView`/`MovePreview` reason edits; tests | M |
| B | Conquest sight (3.6): held land is sight, `controllers_changed` drops the cache, capture and cession discover at once; tests (closes 435) | M |
| C | Tile window / `TileView` and hex card light-fog rows, country card "land seen" line; tests | M |
| D | Map layers: deep-fog dark, army fog tint, minimap, overlay gating (waits for the map's fog layer) | L (lands with the map track) |
| E | AI door: discovery gate in `AiKnow` land reads; `test_ai_fog` re-plants; re-pin AI tests | M |
| F | Monkey invariant, perf probe, changelog and README rules text | S |
Order: A, B, E (core, parallel safe after A), then C, then D, then F. A and B together fix #435 and make the tile window
buildable; C needs the tile window (U1 of the UI audit).

## 8. Questions for the owner

1. **How much world does a country know in 1480?** (a) The land and one ring round it, as today; (b) three rings, a
   scenario number; (c) a hand-made list per country (its neighbours' capitals and the sea lanes). **Recommend (a)** now,
   then raise it after a playtest; it is one number in data, but it moves pinned test counts.
2. **Is a fortress garrison an army for the fog?** (a) Yes: men hidden, estimated as today; the fortress and its level
   shown; (b) no: show exact men in light fog. **Recommend (a).**
3. **Foreign land numbers on discovered hexes: exact or banded?** (a) Exact in the tile window and country sums (the land is
   plain to see); (b) banded as today. **Recommend (a)**; the treasury and men under arms stay banded either way.
4. **A besieged castle you cannot see.** (a) Show only "Besieged" and the holder; hide meter, men and besieger; (b) hide
   the siege fully until in sight; (c) show everything. **Recommend (a).**
5. **Should the AI be limited by deep fog too (targets only on discovered hexes)?** (a) Yes, same function as the player;
   (b) no, keep it reading owners everywhere. **Recommend (a)**: one rule for everyone is the point of the decision; it
   costs a few re-pinned AI tests.
6. **Does a conquered hex stay in the old owner's sight?** (a) The old owner keeps light fog (sees the land, not the army)
   after a cession and sees armies in a hex it still owns but has lost to occupation; (b) it also keeps army sight of ceded
   land for one season. **Recommend (a).**
7. **Does the occupier see the land it holds?** (a) Yes: held land is sight (land sight 1 ring, as any owner); (b) only
   discovery, no sight. **Recommend (a)**; without it the conqueror's armies are the only eyes in its own conquest.
8. **Country panel for a country with only a sliver discovered.** (a) Open as a known country with a "land seen" line;
   (b) show a smaller card ("a country at the edge of your map"). **Recommend (a)**: one card, one rule.

## 9. Risks

- Players may read the live land in light fog as clairvoyance (an enemy's new castle is visible without scouting). That is
  the owner's decision; the only mitigation is the army fog, which still hides the war.
- Raising the start world (question 1) can flatten early discovery and the first war's surprise; keep it small.
- Re-pinning AI tests hides real regressions if done carelessly; each re-pin states a reason.
- The map's deep-fog art is not designed here; it belongs to the map track (group D waits on it).
