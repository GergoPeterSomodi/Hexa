# Battle system design (side session, 2026-11-10). User CHOSE: "A, using C's lanes" + "men + wounded"

Mockups: [10_battle_panel.png](../design/images/10_battle_panel.png), [11_battle_map_and_options.png](../design/images/11_battle_map_and_options.png) (script in that session's scratchpad, not in repo).

## Today (for reference)
world.py _battle: one-shot strike on an adjacent hex; best FRONT=3 fight, rest add SUPPORT_BONUS 5% (max 25%);
back-line cannons fire first at 0.6; defenders counter at COUNTER 0.6; units die at hp 0. Garrison = infantry-like unit.

## Agreed direction
- Start: moving a stack INTO an enemy stack's hex starts a Battle object on that tile. Both stay; neither may move
  away except by Withdraw/rout. Units in battle cannot siege or heal, still eat (supply/attrition apply).
- Pace: 3 days (rounds) per season, resolved at end of round; lasts until one side's army morale < 25%.
- Joining: a friendly stack moving into the battle hex joins as reserve next day (stack limits per side apply).
- Field per side: front line = 3 lanes (left flank, centre, right flank; terrain/river can shrink to 2);
  back line = cannons (fire over front; cannon order: centre or counter-battery) + reserves (fill first gap).
  Cavalry prefers flanks, infantry centre.
- Each day uses C's phases: 1 Fire (cannons/shot), 2 Shock (per lane; pikes vs horse +25%), 3 Flanks (a lane whose
  enemy routed/emptied hits the centre +25%), 4 Morale (regiment at 0 routs; army <25% breaks), 5 Pursuit
  (winner's cavalry adds ~10% losses to the retreating side).
- Strength: regiments of 1,000 men instead of HP; losses split killed/wounded; ~half wounded return after the
  battle if in supply. Morale per regiment + army morale (tug-of-war bar). Rout -> retreat to nearest own/friendly
  hex away from enemy; no route -> regiment surrenders/destroyed.
- Castles: battle in a castle province is an assault; the Garrison is a front-line card with castle defense.
- Generals (trait bonuses, +morale), veterans (rank bonus, steadier morale), eras (troop types), terrain
  (frontage, defense), supply (out of supply: morale drain) all plug in.
- Player orders per season: stance Attack/Hold/Withdraw, commit reserve to a lane, cannon target.
- Map: both stacks drawn on the hex with crossed-swords badge + morale bar; click opens battle panel.
  AI battles: one log line/report (name, seasons, men lost/wounded, who retreated where).
Nothing implemented; no repo files touched.

## Round 2 (user follow-up): extra ideas chosen. Mockups 12_more_battle_ideas.png, 13_battle_minimap.png
User: "On the map show them on the same tile, but generate a 'mini-map' for the battle" using ideas 1, 2, 3, 6:
- World map: both stacks on one tile (crossed swords + morale bar). Clicking opens a generated battle MINI-MAP
  (~12x9 small Kenney hexes), 3 lanes side by side; each regiment stands on its own little hex.
- (1) Lane ground comes from the real map: the 3 neighbour hexes facing the enemy set left/centre/right
  (forest +25% def & no charge; river: attacker -30%, ford; hills: guns +20%; mountains/marsh close a lane).
- (2) Deploy before day 1: formation presets (Pike & shot, Cavalry wings, Refused flank, Gun line) + drag
  between lanes; AI picks a fitting one; a cavalry general reveals the enemy formation.
- (3) Events with a choice on some days (rain, general wounded, powder runs dry, mercenaries want pay, gap in line).
- (6) Troop quality: levies (cheap, fast, morale 50%), regulars, mercenaries (120%, paid each season, desert
  if unpaid), one guard per country (never routs first); a routing lane shakes its neighbours; pike+shot +10%.
- NOT chosen: (4) pincers/surrender/rearguard, (5) aftermath (prisoners, captured guns, war score, ribbons).

## APPROVED by the user (2026-11-10): build A + C lanes + mini-map with ideas 1, 2, 3, 6 as described above.

## Round 3 (2026-11-11): BATTLE CARDS. Mockups [14_battle_cards.png](../design/images/14_battle_cards.png), 15_sneaky_cards.png
User asked for cards for extra/boost actions, "rolled" from the technology tree (tree itself TBD). User chose:
- Deck = random draw: every researched tech adds 1-2 cards; general traits and Elite regiments add their own card.
  Draw 4 at battle start, +1 per day, max hand 5. 3 command points/day (+1 good general, +1 Staff college tech).
  Re-roll: pay 1 point to swap a card. Most cards target one lane (drag onto the lane). Some cards counter others.
  AI plays by simple rules; enemy cards shown in the battle log. Events (idea 3) stay separate from cards.
- Card types wanted: battle boosts (Fire/Shock/Morale), extra actions (Move), siege cards, general & Elite cards,
  AND sneaky cards from real history. A 'Scouts' card or a cavalry general can spot/cancel a sneaky card.
- Example cards: Pike hedge, Knightly charge, Rally the banner, Grand battery, Forced march, Pike and shot,
  Rolling volley, Dig in, Pistol ride, Platoon fire, Guns gallop up, Lure the horse.
- Sneaky (history): Feigned retreat (Hastings 1066), Sharpened stakes (Agincourt 1415), Ambush in the woods
  (Morgarten 1315, forest lane only), Turncoats (Bosworth 1485, pay ducats), Night attack (Targoviste 1462),
  Through the wall (Pavia 1525), Smoke screen (Duna 1701), Campfires burning (Assunpink 1777: withdraw, no pursuit);
  siege: The open gate (Antioch 1098), Burn the fields (Provence 1536: enemy can't forage).
- Example tech -> card map in mockup 14 is a placeholder; the tech tree still has to be designed.

## Round 4 (2026-11-11): more card ideas, mockup 16_more_cards.png: APPROVED by the user (all 18 added)
- Boosts: Pike square (Grandson/Murten 1476), Wagon fort (Hussites 1420s, needs wagon), Countermarch (Maurice of
  Nassau 1590s, shot fires twice), Hold the line (Rocroi 1643, no rout today).
- Extra actions: Call the ban (raise 1 levy on the spot, costs people), Change of front (swap two lanes),
  Loot the baggage (Grandson 1476: win -> ducats + enemy wagon), By river and sea (ship-borne stack joins).
- General & Elite: Lead from the front (Lutzen 1632, general may be wounded), Dig trenches (Cerignola 1503,
  defence-trait general), Veterans' resolve (Elite ignores first rout).
- Sieges: Great bombard (Constantinople 1453), Counter-mine (stops 'Mine the walls'), Sally out (Malta 1565).
- Sneaky: Catch them crossing (Stirling Bridge 1297, river lane).
- New World set: Native allies (Tlaxcalans 1521), Know the land (ignore forest/jungle/marsh), Guns and horses
  (first day vs troops without gunpowder: -30% morale).
Tech-tree session: each card should hang off a tech node (1-2 cards per tech) or a general trait / Elite rank.

## APPROVED (2026-11-11): the card system (Round 3, incl. the 10 sneaky cards) and all 18 cards of Round 4. Ready to build once the tech tree is designed.

## Round 5 (2026-11-11): detailed card LOOK, mockup 17_cards_detailed.png (proposed)
User: cards were "a bit lowkey", wanted more detail. Proposed look (pygame-drawn, Kenney style kept):
- Frame metal shows the era: bronze (era 1), silver (2), gold (3); general/Elite cards purple-gold frame + name.
- Painted scene (~190x150): sky gradient, distant hills, Kenney terrain tiles as ground, art.figure() units,
  effects (smoke puffs, muzzle flash, dust streaks, night tint + moon + campfire glow, castle tile).
- Type emblem top-left (Shock, Fire, Morale, Move, Sneaky, Siege, General), red wax seal top-right = cost.
- Title on a ribbon in the type colour; chips (LANE/ARMY, CAVALRY, GUNS, HIDDEN, ONCE, SIEGE, DUCATS); era pips.
- Rules text, then an italic flavour line; footer: history battle + source (Tech: X / Trait: Y).
- Card back: country colour weave, gold border, country token, country name.
- Sneaky cards lie face down on the field until they trigger, then flip; a played card flies to its lane and
  the lane glows in the type colour that day; enemy cards small in the log, click for full card.
Render script: cards_detailed.py in the battle-design session's scratchpad (not in repo).

## Round 6 (2026-11-11): card look pushed further, mockup 18_cards_deluxe.png (proposed; supersedes 17)
- Scene: clouds, layered hills + haze, Kenney ground tiles, ranks of figures (depth: back rows smaller),
  waving country banners, dust clouds, light rays, smoke + muzzle flashes, warm vignette.
- Frame per era: era 1 gothic pointed arch window + bronze; era 2 round arch + gold scrolls + silver;
  era 3 cut-corner window + laurels + gold. Corner gems in the type colour; era pips as gems.
- Parchment texture (light speckle + faint stains), embossed title plate (type colour, gradient, era-metal rim,
  shadowed serif title), drop-cap first letter in the type colour, italic flavour line, footer (history + source).
- Close-up view on hover/tap (big card). Hand: 4-5 cards fanned at the bottom of the battle map, hovered card
  lifts; drag onto a lane -> lane glows in the card's type colour. Enemy sneaky card lies face down on its lane.
Render script: cards_deluxe.py in the battle-design session's scratchpad (not in repo).

## Round 7 (2026-11-11): card PICTURES more detailed, mockup 19_card_pictures.png (proposed)
User disliked the card pictures (too simple). Proposed: separate, detailed figures drawn only for card art
(map units keep art.figure). Drawn with pygame shapes at 3x, outlined (art._outlined), smooth-scaled:
- knight(): galloping horse (mane, chanfron, crinet plates, reins), caparison in country colour with gold
  lilies + scalloped gold hem, rider in plate (armet + visor + 3-feather plume), surcoat, heater shield with
  charge, couched lance with vamplate + swallowtail pennon.
- pikeman(): morion with comb + plume, breastplate with highlight, puffed slashed trunk hose, striped hose,
  sword; variants: pike upright, pike lowered (front rank), gunner (hat + feather, linstock with burning match).
- culverin(): tapering bronze barrel with rings, highlight, dolphins, cascabel; wooden cheeks/trail; spoked wheels.
- Scenes: sky gradient + sun glow, soft clouds, snow-capped mountains, haze layers, rolling hills, Kenney tree
  objects, textured grass with tufts + flowers, dust clouds, big smoke, flags with crosses (Swiss white cross),
  distant troops smaller + hazed (depth). Gabions for the battery.
Render script: card_art.py in the battle-design session's scratchpad (not in repo).

## Round 8 (2026-11-11): card PICTURE STYLE DECIDED: A "Game style" (mockup 20_card_picture_styles.png)
User found the detailed hand-drawn figures (round 7, mockup 19) "not natural" -> DROPPED.
Card pictures use the map's own art.figure()/art.token() figures and Kenney tiles (as in style A of mockup 20:
sky gradient + soft clouds, Kenney grass/forest tiles, big friendly figures in front, enemy smaller behind,
country token in a corner). Silhouette, woodcut and real-painting styles were rejected.
Card frame/layout: the deluxe frame of mockup 18 (era frame shapes, seal, emblem, title plate) is still the
latest proposal for the frame; only the picture style changed.

## Round 9 (2026-11-11): full cards = deluxe frame (mockup 18) + game-style pictures, mockup [21_cards_game_style.png](../design/images/21_cards_game_style.png) (proposed). Script: cards_game_style.py in this session scratchpad.

## APPROVED (2026-11-11): final card look = mockup [21_cards_game_style.png](../design/images/21_cards_game_style.png) (deluxe era frames from mockup 18 + game-style pictures with art.figure/art.token and Kenney tiles). Mockups 17, 19, 20 are superseded.
