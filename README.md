# Hexa

[![tests](https://github.com/GergoPeterSomodi/Hexa/actions/workflows/tests.yml/badge.svg)](https://github.com/GergoPeterSomodi/Hexa/actions/workflows/tests.yml)

A small turn-based strategy game on a hex map, made with pygame. It has three modes:

- **Age of Discovery:** Europe, North Africa and the Mediterranean in 1480, with about 50 real
  countries. Pick any of them, run an economy of goods, markets and trade routes, fight your
  neighbours, and sail into the unknown to colonise the Americas, Africa and the Atlantic islands.
- **Conquest:** a small medieval map against one rival kingdom. Grow towns and capture its castle.
- **Colonisation:** a big unknown continent. Land your colonists, survive the winters, deal with
  native tribes, trade with your homeland and out-grow two rival companies.

## Setup

```bash
pip install -r requirements.txt
python play.py
```

The start menu picks the mode and, for colonisation, how you start and how you win.
You can also skip the menu:

```bash
python play.py --mode campaign --nation POR             # Age of Discovery as Portugal
python play.py --mode campaign --map random --seed 7    # Age of Discovery on a random world
python play.py --mode conquest --seed 42
python play.py --mode colony --start land --goal independence
```

`--seed` replays the same map. The map number is shown in the window title. **M** goes back to the menu.
`python play.py --help` lists every option.

`--nation` takes a country's tag or name in any case (`POR`, `por`, `Portugal`). Random worlds invent their own
countries (pass `--seed` too); an unknown name opens the country chooser and the terminal lists that map's countries.

## Conquest

- **Goal:** move a soldier onto the enemy (red) castle. If nobody wins by turn 40, the higher
  **score** wins: the total HP of all your units plus 10 per town.
- **Select** one of your blue units by clicking it, or press **Tab** to cycle through units that can still move.
- **Move** by clicking a highlighted hex. Moving reveals the map around your units.
- **Attack** by clicking an enemy with a red outline. If it isn't adjacent, your unit walks next to it first.
  Attacking needs at least one move left and ends that unit's turn. The defender strikes back if it survives.
- **Train units:** click one of your towns (click twice if a unit is standing in it), then a unit button
  or press **1-4**. Each town trains one unit per turn; new units can act next turn.
- **Build:** move a worker onto grassland, dirt, forest or hills inside your borders and press **B**.
- **Found a town:** move a settler at least 3 hexes away from every other town and press **B**.
- **End turn** with the button or **Space**. The enemy then moves.
- **R** starts a new map. **Esc** deselects, or quits if nothing is selected.

### Economy

You collect **food**, **wood** and **stone** at the start of every turn. The bar at the bottom shows
what you have and your income per turn.

| Source | Produces |
|---|---|
| Your castle | +2 food, +1 wood, +1 stone |
| Each other town | +1 food, +1 wood |
| Farm (grassland or dirt, costs 2 wood) | +2 food |
| Lumber camp (forest, costs 2 food) | +2 wood |
| Mine (hills, costs 3 wood) | +2 stone |
| Each soldier | -1 food (upkeep) |

- Every town owns the land within 2 hexes of it, shown by a border in its owner's color.
  Buildings on that land produce for the town's owner, so capturing a town takes its buildings too.
- An enemy unit standing on one of your buildings stops it from producing.
- If you run out of food, every soldier loses 1 HP per turn until there is food again.

### Units

| Unit | Cost | HP | Attack | Defense | Moves | Sight | Notes |
|---|---|---|---|---|---|---|---|
| Scout (arrow) | 2 food, 1 wood | 6 | 2 | 0 | 4 | 3 | Fast explorer. Cannot capture towns. |
| Soldier (swords) | 2 food, 2 wood, 1 stone | 10 | 5 | 1 | 2 | 2 | Fights and captures towns. Eats 1 food per turn. |
| Worker (hammer) | 3 food, 1 wood | 4 | - | 0 | 2 | 1 | Builds farms, lumber camps and mines. Cannot fight. |
| Settler (house) | 5 food, 3 wood | 4 | - | 0 | 2 | 1 | Founds a new town. Cannot fight. |

### Terrain

| Terrain | Move cost | Defense |
|---|---|---|
| Grassland, dirt | 1 | +0 |
| Forest | 2 | +1 |
| Hills | 2 | +2 |
| Mountain, lake | impassable | - |
| Your own town or castle | as the land | +1, and heals 2 HP per turn |

### Other rules

- Capturing an enemy town takes it over (with its land). Capturing the enemy **castle** wins the game.
- A unit that neither moves nor fights heals 1 HP at the end of the turn, but not while next to an enemy.
- Flanking: each of your other units next to the target adds +1 damage to your attack.
- The computer builds its own economy: workers, settlers and up to 4 towns. It keeps one soldier
  guarding its castle, gathers 3 soldiers, then attacks together. It can see the whole map.

All numbers are in `hexa/rules.py` if you want to rebalance the game.

## Age of Discovery

One turn is one season, from spring 1480 to 1650. Every land hex is a province.

**Controls:** left-click selects a province or unit, **right-click** moves the selected unit (or attacks
a red-outlined enemy). Right-click far away to send a unit there over several seasons. Mouse wheel or
**+/-** zooms, right-drag or **WASD** scrolls, **1-4** switch map modes (political, terrain, goods, markets;
press **3** again to switch the goods view between chips, deposits and prices), **Tab** cycles units,
**C** opens your country, **L** the ledger, **G** shows or hides the faint hex grid, **R** continues the selected
stack's march (see Moving), **Space** ends the season (while moves are being shown, **Space** or **Enter** skips them
instead; see Watching moves; with something unfinished it asks first, see End-of-turn reminders).
Hover anything for a moment to get a card explaining it: troops, buttons, provinces, goods.

**The top bar** is one row. After your country's name come the resource chips, each an icon, its value and, in
brackets, what changed since the season began: green for more, red for less, grey (±0) for no change.

| Chip | Shows | Click opens |
|---|---|---|
| Ducats | the treasury | the ledger |
| Research | points toward the current technology (and its cost); the change is what you gained | the technology screen |
| Provinces | provinces you own | your country panel |
| Regiments | war units | your country panel |
| Merchants | busy / all | the home market |
| Prestige | your score | the ledger |
| Horses, gunpowder | the price at your capital's market; a rise is red, you pay more | the home market |

Hover a chip for its card. The ducats card lists the season's income and spending and then the one-off items
(raising troops, building, battles, seizures), the change since the season began, and the change expected next season. The
other cards list their one-off items (units raised, lost or deserted; provinces taken or lost; technologies finished).
Then come the date and season, the four map modes (icons: **1-4**), **Menu** and **End season**. In a narrow window the
bar drops things in this order: the key goods, the changes (they stay in the cards), "End season" shortens to "End",
then chips from the right.

**Floating text:** what happens in view rises from its hex as a ribbon for about a second: **red** for war (battles,
a province taken from someone else), **amber** for a siege, **gold** for gains (a province, a finished
building), **green** for what you did on purpose (recruited, built, foraged, founded), **rose** for your losses
(units, a province, raids) and **white** for what other countries do in your sight. Several at one hex queue up and
stack; nothing floats for hexes off screen, under the open panel or in the fog.

**The action log** is in the bottom-left corner: collapsed it is one line, the newest entry, with a red "+N new" for
what came since you last opened it. Click it to open the box: lines grouped by season, newest first, each with the icon
and colour of its kind, with the filters **All**, **War**, **Money** and **Mine**. The mouse wheel scrolls it. Click a
line (the place name is the link) and the camera glides there, rings the hex and selects your stack if one is there. It
keeps the last two years; the saved message log (`world.log`) is the longer record. Besides battles, raising, building and
the like it tells ideas adopted, colonies grown into provinces, troops cut off from supply, marches waiting for your order, and
the season's treasury line and credit refusals (under **Money**). Clicks and drags on the box, the minimap and the top bar do not
reach the map.

**Moving:** a selected stack shows where it can go this season (green, bright edge), next season (blue),
what it can attack (red; "fire" for cannons), and "stop" where an enemy castle will halt it. Hover a hex to
see the path, the move cost of each step and how many seasons it takes.

**Watching moves:** the game is played at once, but what you can see is shown slowly. After **End season** the armies and
ships of the other countries walk hex by hex at about 0.18 seconds a hex (so you can follow them), and so does a stack
you send more than a step. Only steps you saw are shown (a step counts when you could see either hex of it); a march in the
fog is instant. Countries walk one after the other in turn order, the stacks of one country together; a long season is played
faster, never longer than about 6 seconds. The floating text of a battle or a capture shows when the walkers get to the hex.
The map still pans and zooms, **Space** or **Enter** skips the rest, and the **End season** button waits until it is over.
The **Movement speed** option sets it: Instant (no replay), Normal or Slow (about 0.32 seconds a hex, up to 9 seconds).

**End-of-turn reminders:** before the season ends, a small list shows what you left unfinished, if anything: an idea
card waiting for your pick, no technology being researched, a technology with no points yet that you could fund, merchants
without orders (while a route of yours has something to carry), nothing being built while you could pay for a building,
and armies that did nothing this season (not moved, attacked, foraged or marching, not besieging and not sitting in
one of your own castles). Click a line to go to the thing it names (the market, the technology screen, the province, the
army). **End season anyway** (or **Enter**) ends the season, **Back** (or **Esc**, or a right-click) does not. **Space**
does nothing on the list, so a double tap cannot end a season you were warned about. The **End-of-turn reminders** option
turns the list off.

**Marches:** a right-click far away starts a march over several seasons. When the season ends, a march does not
move on by itself: the stack waits for your order. Its planned route stays on the map as a dashed gold line, and
Tab cycles to it. Press **R** or the **Continue march (R)** button in the unit panel to walk on for this season.
You cannot cross a ridge crest except at a pass, and a pass closed by snow stops the march until spring; the message
says so each time you try.

### Technology
- **T** (or **Technology** in the country panel) opens the tech tree.
  - It has four branches: Military, Trade & Industry, Navigation and Statecraft.
  - Each branch spans three eras and has 37 techs in all.
  - Every country also starts with one national tech, such as Portugal's Sagres school.
- **Researching:** one tech at a time. Click a far tech to queue its whole path; right-click removes a tech from the queue.
- **Research points** come from:
  - a base amount
  - burghers
  - universities, a city building unlocked by a tech
  - coffee houses
  - research bonuses, such as the Printing press
  - **Fund research**: 60 ducats buy 15 points, once a year
  - A tech is cheaper if countries you share markets with already know it.
- **What techs give:** tactics, drill levels, siege, castles (the large castle needs Trace italienne), supply, and stack size (base 6). They also give merchants, taxes, new manufactories (ropewalk, powder mill, glassworks, tannery), carracks and galleons, Atlantic crossings, plantations, and more.
- **Troop types still come with the eras.**
  - Era II opens from 1520 once you know 4 era I techs.
  - Era III opens from 1575 with 4 era II techs.
  - At each new era you pick 1 of 3 idea cards (one is your nation's), which are permanent bonuses.

### Menu, saving and options
- **Esc** (or **M**, or the **Menu** button) pauses the game and opens the menu: resume, save, load, options, back to the main menu, exit.
  **Exit to desktop** and **Main menu** ask Yes or No first, since unsaved progress is lost. Esc on that question
  goes back to the menu.
- **Saving:** there are eight save slots plus a quicksave (**F5** saves, **F9** loads) and an autosave (every year by default). Each slot shows the country, the date and the map.
  - Saves are kept in `~/.hexa/saves`. If a save can't be written (a read-only folder or a full disk), a message says why, the game carries on, and the slot keeps its previous save.
  - **Continue** on the start menu loads your latest save. If that save can't be read, the start menu says so instead of starting a new game.
- **Options:**
  - fullscreen (also **F11**)
  - window size: 1280x720, 1600x900 or 1920x1080; the map fills the extra space
  - autosave: off, every year or every 5 years
  - scroll speed
  - movement speed: instant, normal or slow (how fast the moves you can see are shown, see Watching moves)
  - end-of-turn reminders: on or off (see End-of-turn reminders)
  - hex grid (also **G**) and pass names: the mountain pass names shown on the closest zoom, off by default (the pass art and the winter snowflake mark on a closed pass always show)
- Options are kept in `~/.hexa/settings.json`. If that file can't be written (a read-only folder or a full disk), a changed option still applies until you quit, and a message says it wasn't saved.

### The map
- **Two maps** (pick one in the menu, or with `--map europe|random`):
  - **Europe 1480** is the real map, with about 14,000 provinces.
  - **Random world** is a new world every game (`--seed` repeats one). It has invented countries in a known Old World with an inland sea, and an unknown New World across the ocean.
- **Wave function collapse:** both maps grow their terrain this way.
  - Every hex gets odds from its geography (latitude, mountain ranges, deserts, steppes, marsh regions, rivers).
  - Neighbouring hexes must fit together: mountains rise through hills, deserts fade through steppe and savanna, and snow only touches cold land.
  - Like clumps with like, so forests, marshes and hills form natural regions.
  - The random world also lays out its continents by wave function collapse, on a coarse grid.
- **Terrain:** farmland, steppe, forest, hills, mountains, desert, jungle, tundra, marsh, taiga, savanna, coast and snowfield.
  - Each has its own move cost, defense and population.
  - Vineyards, pastures and plantations show what farmland grows.
- **Rivers** (Rhine, Danube, Loire, Nile, Mississippi...): river land holds more people, and marching along a river costs one move less.
- **Roads** join each country's towns and its neighbours' capitals. Along a road, every hex costs one move.
- **Edge-matched tiles:** coasts, rivers, roads, bridges, town walls, towns and castles come from a wave function collapse tileset (`wfctiles.py`).
  - Every tile has a socket on each of its six edges, so coastlines, rivers and roads always join across hexes.
  - Settlements grow from hamlet to great city, and coastal towns get harbours.
- **Looks:**
  - Coasts have surf and shallow water.
  - Rivers have banks, and bridges where roads cross.
  - Borders are ribbons in the country's colours.
  - Towns and cities grow extra houses, mines smoke, and ports get docks.
  - Northern Europe frosts over in winter.
- **Close zoom** (hex radius 21 and 34): the landscape is drawn with the tile art. Peaks and forests cross hex borders,
  treeline and snow follow the altitude, and farms grow field systems with hedgerows. The faint hex grid is on by default
  (**G**, or Options > Hex grid).
- **Ridge crests and passes:** every hex can be entered, mountains and snowfields included, at its normal move cost.
  But the edge between two hexes on opposite sides of a ridge crest (the Alps, Pyrenees, Carpathians, Apennines, Atlas,
  Caucasus, Andes...) cannot be crossed in any season, so an army walks up its own valleys but must cross the ridge at a
  **pass**. Supply, zones of control and roads do not cross a crest either, except at a pass. Ships are not affected.
  - A pass is one or two crest edges that stay open. The real ones are Gotthard, Simplon, Great St Bernard, Mont Cenis,
    Col de Larche, Brenner, Arlberg, Tauern, Semmering, Roncesvalles, Somport, Perthus, Pajares, Cisa, Dukla, Lupkow,
    Verecke, Tihuta, Predeal, Iron Gates, Shipka, Darial, Cilician Gates and Tizi n'Tichka. Wherever the ridges would
    still cut a landmass in two, the game opens one more pass there (named after the nearest city), so every landmass
    stays in one piece in summer.
  - In winter (every fourth season, turn 4, 8, ...) the passes are closed by snow: the move says "The Gotthard pass is
    closed by snow until spring." A march that meets a closed pass waits for spring. With the passes shut there is
    usually a long way round or none at all, not a short detour. Only the step across the pass is closed: no army is
    ever stranded, because the hexes themselves stay open.
  - Trade routes and market reach
    ignore crests: goods cross the mountains in every season. Armies, battles, supply, zones of control, recruiting and siege support
    do not cross them.
  - A march that would only get through a pass walks nowhere in winter: if the way round has become much longer, the
    stack waits for spring ("The Gotthard pass is closed by snow; the march waits for spring."). The AI does the same.
  - A random world gets crests on its own ridges, passes on its longest ridges (up to 8), and the extra passes it needs
    to stay connected.
- **Debt:** a country may go into debt down to a limit of 6 seasons of running costs (at least 300 ducats). It pays 2%
  interest a season on debt up to that limit. Over the limit with a deficit, unpaid troops desert, oldest first and never
  the general. With no troops left, creditors seize buildings, works, castles and then settlement levels, one at a time.
  The log tells you each step.
- **Units:** close up, a stack shows up to three figures of what it holds, with a shield for its size. Zoomed out, it shows as a board-game token with era pips.

### Fog
- **Black fog:** places your country has never seen. In 1480 that is everything west of the Canaries:
  the Azores, Cape Verde and the Americas (Portugal and Castile also know the African coast).
- **Light fog:** places you know but cannot see right now. You see owners and terrain, not armies.
  You see around your provinces and your units; ships see furthest.

### Economy
- **Goods (32):**
  - **Raw:** grain, fish, salt, wine, wool, cotton, timber, iron, horses, cattle, stone, copper, hemp & flax.
  - **Luxuries:** sugar, tobacco, furs, ivory, spices, olive oil, silk, dyes, cocoa and coffee.
  - **Money:** silver and gold.
  - **Made in towns:** cloth, tools, weapons, rope & sails, glass, leather and gunpowder.
  - Each province produces one raw good, where it grew in 1480 (shown by the goods map mode). For example: horses on the steppe and in Hungary, copper in Sweden and Hungary, silk in Anatolia and Lombardy, olives around the Mediterranean, cocoa in Central America, coffee in Yemen and Ethiopia.
- **What goods are needed for:**
  - **Cavalry:** horses and leather.
  - **Cannons:** copper and gunpowder.
  - **Arquebusiers and musketeers:** gunpowder.
  - **Ships:** rope & sails.
  - **Towns, cities and castles:** stone, plus glass for a city and gunpowder for a large castle.
  - **Province investment:** timber, tools, stone and iron.
  - All of it is bought on the local market, so shortages raise prices.
- **Pops:** peasants, burghers and nobles. Peasants work the land, burghers staff manufactories,
  everyone eats and buys cloth, wine, salt and (the rich) sugar, spices, furs and more.
- **Markets:** about 20 market towns (Lisbon, London, Antwerp, Venice, Constantinople...).
  Each province sells in its nearest market. Prices rise when demand beats supply and fall when
  goods pile up (between 0.3× and 3.5× the base price). Colonial markets (Havana, Bahia, Elmina...)
  open once someone settles near them.
- **Trade routes:** goods flow between neighbouring markets (and across the Atlantic) from cheap to dear
  by themselves; market owners take tolls.
- **Merchants** are yours to play: in a market panel press **+** on a route and give a merchant an order,
  **export** or **import** a good you choose (12 units a season). The card shows the expected profit;
  the profit or loss each season is yours. You get more merchants from marketplaces and market towns.
- **The tile:** zoom in (mouse wheel) to see the map in tile art. Each province's tile can be improved:
  - **Investment** (no builder units: press **Invest** in the province panel):
    - Every goods tile has five levels, each with its own look. For example: wheat strips → open fields → grange barn → windmill farm → manor estate; iron diggings → … → ironworks; fishing beach → … → fishing harbour.
    - Each level costs ducats plus timber, tools, stone or iron bought on the local market, and gives +30% goods.
    - Levels 3–4 need the second era, and level 5 the third.
  - **Settlement:** countryside → village → town → city. Needs enough people; gives more taxes and
    building slots (1 / 3 / 5).
  - **Castle:** tower → small castle → large castle. Defensive: +defense for your armies there and much longer sieges.
- **One job per province each season:** train a unit, or start a settlement, castle or building (4 seasons to finish).
- **Buildings** (use the settlement's slots):
  - Manufactories:
    - weavers (wool or cotton → cloth)
    - toolmakers (iron → tools)
    - armouries (iron + tools → weapons)
    - ropewalks (hemp → rope & sails)
    - glassworks (stone + timber → glass)
    - tanneries (cattle → leather)
    - powder mills (salt(petre) + timber → gunpowder)
  - Marketplaces, ports and shipyards. Manufactories buy their inputs on the
  market and need burghers.
- **Money each season:** taxes on goods produced and on people (low/normal/high tax), a share of
  manufactory profits, and trade; minus upkeep for buildings, armies, ships and young colonies.
- Food shortages make people shrink; full markets make them grow.

### Colonies
Raise **colonists** (1,000 settlers from a province) and a **caravel** or **carrack** at a port.
Move the colonists onto the ship, sail into the black fog, and land on unclaimed coast:
- **Found a colony:** settlers take the land and it grows; at 5,000 people it becomes a full province.
  Natives nearby may raid young colonies.
- **Open a trading post:** on a coast with natives, who keep living there and produce goods for you.

### War
**Troops** stack on a hex (6 in 1480, 7 and 8 in later eras; a general adds 2). Click a stack to select it all;
untick units in the side panel to leave them behind. Right-click moves the ticked units or attacks.

| | 1480 | from ~1520 | from ~1575 | Good at |
|---|---|---|---|---|
| Infantry | Pikemen | Arquebusiers | Musketeers | Defending, holding castles, stopping cavalry |
| Cavalry | Knights | Lancers | Cuirassiers | Fast; hits hard in open land, weak in forests, hills and against castles |
| Cannons | Bombards | Culverins | Field guns | Fire from the back line of a battle, add siege points on their hex and smash castles; weak up close |

- **Battles:** an attack on an enemy stack or a garrisoned castle starts a battle on that hex, and a stack beside a battle
  its country is in joins it. Both armies stand on the hex and fight up to **3 days a season**. Each side fights in three
  **lanes** (left, centre, right; the right lane is closed on mountains, marsh, jungle and snow). The rest of the army is
  the reserve, and guns of the back line fire at the enemy centre. A lane that empties is refilled from the reserve:
  cavalry to the flanks, infantry to the centre. A regiment that moves up into a broken lane fights its first day at
  **half strength**. A flank with no enemy in front comes round for a bonus. Castles, veterans, generals and pikes against
  horse count as they do in any fight. The **ground** counts for the side that held the hex when the battle began: hills,
  forest and mountains protect the defender, and an attacker standing on the same hill gets none. An attack that comes
  **across a mountain pass** deals 30% less damage on its first day, and an attacker from **lower ground** deals 5% less
  all battle. An army
  under 25% morale **breaks**: the winner pursues it. The beaten army **retreats** to the nearest hex of its country within
  3 hexes, or **surrenders** when there is none. A side whose last regiment or garrison is destroyed in the fight loses (the
  other side wins); a side that vanishes between seasons (deserted, starved, disbanded, at peace) is a draw. A battle that lasts **6 seasons** ends with the weaker army withdrawing, so no two armies stay locked for
  long. Peace ends the battles of the two countries with no pursuit. Battles have names: "Battle of Toro, 1480", and
  "Second Battle of Toro, 1481" for a repeat on the same place.
- **In battle:** a stack cannot move, raise troops, refit, drill or heal. It still eats, and it can forage. A regiment under
  half morale cannot attack. Outside battle a fed regiment wins back a quarter of its morale a season. Battle numbers:

| Battle number | Value |
|---|---|
| Days fought a season | 3 |
| Lanes | 3 (2 on narrow ground) |
| Men in a full regiment | 1,000 |
| A stack under this morale cannot attack | 50% |
| An army under this morale breaks | 25% |
| Pursuit of a broken army (cavalry on the winning side / on foot) | 10% / 4% of its men |
| Pursuit of a withdrawing army | 5% of its men |
| Damage an attack loses crossing a mountain pass (first day only) | 30% |
| Damage an attacker loses fighting from lower ground (all battle) | 5% |
| Damage a reserve regiment deals on the day it moves up into a lane | half |
| Luck in each hit (up or down by) | 50% |
| Morale a day lost in reserve | 12.5 points |
| Wounded who come back when the battle ends in supply | half |
| A beaten army's morale, at most | 30% |
| Morale back a season outside battle | 25 points |
| Safety stop | 6 seasons |
- **Castles** have their own garrison (stronger with each level). They stop enemy armies walking past
  (armies must halt next to them) and must be **besieged** for several seasons (cannons and siege-master
  generals shorten it) or stormed. Taking a province without a castle needs one season.
- **Getting better:** research (burghers, or pay to fund it) unlocks new eras; **refit** old troops in a town.
  A **barracks** (infantry, cavalry) or **foundry** (cannons) lets you drill units for +attack / +defense.
  Units that survive battles become **Veteran** (+10%) and **Elite** (+20%). **Generals** (raised in your
  capital) give +2 stack room and +20% in their speciality: open field, forests and hills, storming castles,
  defending, or cavalry.
- **Feeding armies:** every troop takes 1,000 men from its province when raised and eats 0.5 grain a
  season from the local market (paid in ducats, it raises food prices). Each province **feeds** a number of
  troops (people and farms; half in foreign land): bigger stacks lose 1 HP a season. **Supply lines:** towns,
  castles and ports are depots; a stack within 3 hexes of one through land you control is in supply. Enemy
  armies cut the line; cut-off troops cannot heal and lose 1 HP a season. A **supply wagon** feeds its stack for
  4 seasons away from depots (refills in supply), or the stack can **forage** foreign land (the province loses
  people and half its goods).
- Troops heal in their own land when fed (faster in towns). Declare war on a neighbour from their country panel;
  make peace from yours: demand the land you occupy, offer white peace, or give up.
- **War on you:** when a neighbour declares war, a "War on you!" box opens once any idea card or the tech screen is
  closed. The log says so too, and the country panel shows who declared the war and how many seasons ago.

All numbers are in `hexa/campaign/data.py`; the map, countries and markets in `hexa/campaign/geo.py`.

## Colonisation

One turn is one season: spring, summer, autumn, winter. The map is bigger than the window:
scroll with the **arrow keys**, **WASD** or by dragging with the **right mouse button**, or click the minimap.
**C** centres on what you have selected.

### Setup choices

| Start | |
|---|---|
| Arrive by sea | A ship with 2 colonists, a soldier and a pioneer. Sail to the coast, land, found your first colony. |
| Settled coast | A colony of 2 people on the coast, with a soldier, a pioneer, a scout and a ship. |

| Goal | |
|---|---|
| Survive 10 years | After 40 seasons the best score wins: 10 per colony, 5 per person, 2 per building, 1 per soldier, gold / 10. Wiping out both rivals also wins. |
| Independence | Reach 12 population and 3 soldiers, then **declare independence** in a colony. The Crown lands 4 waves of royal regulars. Hold out for 12 turns (or destroy them all) to win. |
| Endless | No time limit. |

You lose if you have no colonies and no colonists left.

### Colonies

- **Colonists** found colonies (**B**) at least 3 hexes from other colonies and 3 from native villages,
  or **join** (**J**) a colony next to them for +1 population.
- Each colony owns the land within 2 hexes. **Pioneers** build there (**B**):

| Building | Land | Cost | Produces |
|---|---|---|---|
| Farm | grassland, plains | 2 wood | +3 food (nothing in winter) |
| Fishery | beach | 2 wood | +2 food, all year |
| Trapper camp | forest | 2 food | +2 wood +1 fur (winter: +1 wood +2 furs) |
| Silver mine | hills | 3 wood | +2 gold |

- A building only produces if someone works it: **each person in a colony works one building**.
- A colony itself makes +2 food +1 wood. Every person eats 1 food and every soldier 1 food per turn.
- Each colony does **one job per turn** (buttons or keys **1-7**): train a scout, pioneer or soldier,
  turn a person into a colonist, **grow** (+1 person for 6 food) or build a **stockade** (+2 defense).

### Survival

- **Winter:** farms freeze, every colony burns 1 wood, and units outside your own land lose 1 HP.
- **Summer:** colonies of 3+ people can lose a person to fever.
- **Out of food or wood:** your biggest colony loses a person (and soldiers starve when food runs out).

### The homeland

Sail a ship to the glowing east edge of the map to trade: sell furs (2 gold each) and timber,
buy food, colonists (6 gold), pioneers (5) and soldiers (8). Bought units board the ship.
Selling furs pleases the Crown: every 8 furs sold earns a free colonist the next spring.
A ship carries 4 units; select it and pick a passenger to take it ashore (costs 1 move).

### Native tribes

Three tribes live in villages inland. The coloured dot on a village shows their mood towards you:
green friendly, yellow wary, orange angry, red at war.

- A **scout** visiting a village for the first time gets a gift: gold, food, maps, or even a new colonist.
- Click a village to **gift** (3 gold, calms the whole tribe) or **trade** (2 wood for 3 furs, once per turn).
  You need a unit next to it or a colony within 4 hexes.
- Tribes get angry when you found colonies within 4 hexes of their villages, build next to them,
  or attack them. At 100 tension they go to war: their braves raid your colonies (stealing food
  and people) and burn your buildings. Gifts bring peace back.
- Soldiers can burn an empty village for loot, but that means war with its tribe and angers the others.

### Rival companies

The Crimson Company lands in the north and the Golden Company in the south. They settle,
build, trade with the natives and the homeland, and from about year 5 they attack weak colonies,
yours or each other's. Soldiers capture an enemy colony by walking into it when it is empty.

| Unit | Cost | HP | Attack | Defense | Moves | Notes |
|---|---|---|---|---|---|---|
| Colonist | 1 person + 2 food, or 6 gold | 4 | - | 0 | 2 | Founds or joins colonies |
| Pioneer | 3 food 1 wood, or 5 gold | 4 | - | 0 | 2 | Builds |
| Scout | 2 food 1 wood | 6 | 2 | 0 | 4 | Sees far, visits villages |
| Soldier | 2 food 2 wood 2 gold, or 8 gold | 10 | 5 | 1 | 2 | Fights, captures colonies, eats 1 food |
| Ship | - | 12 | - | 1 | 5 | Carries 4 units, trades with the homeland |
| Brave (natives) | - | 8 | 4 | 1 | 3 | Raids colonies, burns buildings |
| Regular (Crown) | - | 12 | 6 | 2 | 2 | The royal army after you declare independence |

All colonisation numbers are in `hexa/colony/rules.py`.

## Map editor

`python Hex.py` opens the original tile-painting map editor (it uses `map3.xml`).

## Development

**Plans and designs** live in [`docs/`](docs/README.md):
- the [roadmap](docs/roadmap/roadmap.md) and the [long-term roadmap](docs/roadmap/long-term-roadmap.md), whose final goal is a Steam release
- the approved designs (tech tree, battle system) with their mockups
- playtest and issue-triage reports

Version history is in [CHANGELOG.md](CHANGELOG.md).

The tests use Python's built-in `unittest` and, apart from the window tests in `tests/ui/` and nine game modules
that draw (skipped without pygame, see [Window tests](#window-tests-pygame)), don't need pygame:

```bash
python -m unittest discover -s tests -t .                              # all tests (about 4 minutes)
HEXA_FAST=1 python -m unittest discover -s tests -t .                  # skip the slow tests (about 45 seconds)
python -m unittest tests.test_game                                     # one file
python -m unittest tests.test_game.HexGridTest.test_pixel_round_trip   # one test
```

`HEXA_FAST=1` skips the tests marked `@slow` (the 100-season AI history and the other AI game loops, the tech AI's
60 and 40 seasons among them, the cavalry battle statistics, the random-world tests, the property-test games and the
world-cache memory test); they still count as tests, shown as skipped. CI always runs everything.
`tests/test_tech_ai.py` (its two long AI runs) and `tests/test_campaign.py` (it builds the full Europe map) are the
slowest.

`tests/test_fuzz_files.py` damages `settings.json` and save files at random (truncation, flipped bytes, wrong JSON
types, binary garbage, a good header with a wrong-shaped world after it) and checks that loading them never raises.
It runs 300 cases per test by default (a few seconds); `HEXA_FUZZ_CASES=3000` runs more, and `HEXA_FUZZ_SEED=<n>`
sets the first seed. A failure prints the seed of the case and a command that replays only that case, e.g.
`HEXA_FUZZ_SEED=20260110 HEXA_FUZZ_CASES=1 python3 -m unittest tests.test_fuzz_files`.

`tests/test_properties.py` checks whole games in all three modes. The same seed must play the same game under two
`PYTHONHASHSEED` values (two processes; Conquest to the end, Colonisation 30 rounds, the campaign 4 seasons), and a
campaign saved and loaded must play on exactly like the original. A seeded random player tries every `x_check` /
`x` pair, legal and illegal: a refused action must change nothing and an allowed one must succeed. The world
invariants in `tests/support/invariants.py` (units on legal hexes, cargo within capacity, stocks never negative,
province owners alive, prices within their limits, ...) are checked after every turn of those games. It plays 20
random games per mode (Conquest to the end, Colonisation 10 rounds, the campaign 3 seasons); `HEXA_PROP_GAMES=100`
plays more and `HEXA_PROP_SEED=<n>` sets the first seed. `HEXA_FAST=1` keeps one short game per mode. A failing
game prints its seed, its first problem and a command that replays only that game, e.g.
`HEXA_PROP_SEED=7 HEXA_PROP_GAMES=1 python3 -m unittest tests.test_properties.ColonyGamesTest`. To see a
determinism digest by hand: `PYTHONHASHSEED=0 python3 -m tests.support.digest_run colony 5 --turns 30`.

Shared test helpers live in `tests/support/`: `europe()` (one read-only Europe world), `fresh(player)` (a world
you may change), `random_world(seed)`, `play_seasons(world, n)`, `TempHome` and `@slow`; the invariant checkers
`check_conquest`, `check_colony` and `check_campaign`; the random players (`agents.py`), whole-world digests
(`digests.py`) and all-AI game loops (`games.py`). A test that changes a shared world fails the module's
`tearDownModule` guard, so use `fresh()` for anything you mutate.

The game rules, AI and map generation don't use pygame; only the window, menu and drawing code do.
To keep test runs or experiments away from your real saves and options, set `HEXA_HOME` to another folder
(the default is `~/.hexa`).

Python 3.10 or newer is needed (the suite passes on 3.10, the oldest version CI tests). Every push and pull
request runs the whole suite on GitHub Actions (`.github/workflows/tests.yml`) on Python 3.10, 3.13 and the
newest release, without installing pygame (the window tests show as skipped there; the `ui` job runs them).
Pull requests that change `hexa/campaign/` also run the [save compatibility](#save-compatibility) job.
To reproduce a CI run locally:

```bash
HEXA_HOME=$(mktemp -d) python -m unittest discover -s tests -t . -v
HEXA_HOME=$(mktemp -d) python -m unittest discover -s tests -t . -v --durations 15   # Python 3.12+: slowest tests
```

To see which code the tests reach, install coverage.py (the only development dependency, never needed to play)
and run the suite under it. The settings are in `.coveragerc` (branch coverage; `hexa/` and `play.py`, without the
tests and the legacy editor). Branch coverage is about 5 times slower on Python 3.12 and older, so CI measures on 3.14:

```bash
pip install -r requirements-dev.txt
HEXA_HOME=$(mktemp -d) coverage run -m unittest discover -s tests -t .
coverage report            # table in the terminal; coverage html writes htmlcov/index.html
```

Every CI run also shows the coverage table on its summary page and attaches the HTML report as the `htmlcov`
artifact. There is no minimum yet.

### Window tests (pygame)

`tests/ui/` drives the real windows (start menu, Conquest, Colonisation, Age of Discovery) through their own
`run()` loops with no screen: SDL's dummy video and audio drivers, fake time and scripted mouse and keyboard
input, then checks the game state. They need pygame, which has no wheels for Python 3.14 or newer yet, so use a
Python 3.12 (or 3.13) virtual environment. Without pygame these tests show as skipped. So do nine test modules of
the game's own that sit next to the unit tests but import pygame at the top (`tests/test_landscape.py`,
`test_passes.py`, `test_playtest.py`, `test_techscreen.py`, `test_uifixes.py`, `test_wfctiles.py`,
`test_goodsobjects.py`, `test_mapview_polish.py` and `test_town_labels.py`): each skips as a whole, and the `ui`
job runs them.

```bash
python3.12 -m venv .venv && .venv/bin/pip install pygame==2.6.1 -r requirements-dev.txt
HEXA_HOME=$(mktemp -d) .venv/bin/python -m unittest discover -s tests/ui -t . -v   # only the window tests (about 1.5 minutes)
HEXA_HOME=$(mktemp -d) .venv/bin/python -m unittest discover -s tests -t .         # everything, window tests included
HEXA_REQUIRE_PYGAME=1 python -m unittest discover -s tests/ui -t .                 # without pygame: errors, not skips
```

`HEXA_REQUIRE_PYGAME=1` turns the skips into errors, so a run that is meant to test the windows can't pass by
skipping them; CI's `ui` job sets it. When a window test fails it saves the last frame on screen to
`test-artifacts/<test name>.png` (`HEXA_TEST_ARTIFACTS` picks another folder), and CI attaches that folder to
the failed run. `SDL_VIDEODRIVER` and `SDL_AUDIODRIVER` default to `dummy`; set them (e.g. `SDL_VIDEODRIVER=x11`)
to open a real window instead, though the scripted run doesn't slow down for you to watch.

The helpers are in `tests/support/harness.py`: `UITestCase` (pygame set up, a temporary `HEXA_HOME`, the
driver reset; `self.hold_keys()` holds keys down for the scrolling that reads `pygame.key.get_pressed()`),
`driver.at(frame, events)` and `driver.run_for(frames, until=...)` to script a run, the events `key`, `click`,
`drag`, `wheel` and `hover`, and `button_rect`, `end_turn_rect`, `pause_button_rect`, `menu_option_rect`,
`menu_start_rect`, `hex_pixel` and `minimap_pixel` (a hex's cell on the Colonisation minimap) to find things on
screen from the window's own state. Test
modules in `tests/ui/` import pygame and the window modules inside the tests, never at the top, so the
pygame-free run can still import them.

Importing the `tests` package turns the movement replay and the end-of-turn reminders off for the whole test run
(`tests/__init__.py`; the game ships both on), so that the many tests that press End season get the next season at once.
The tests of those two features switch them on.

`tests/ui/test_monkey.py` is a seeded monkey: it feeds each window random input through its own `run()` loop,
keys from a whitelist (never QUIT; Space and Return end the turn now and then), left, right and middle clicks
anywhere or aimed at the window's own buttons, units, reachable hexes and minimap, drags, wheel turns, mouse moves
and held scroll keys, one action a frame or, with the burst probability, 2 to 6 in the same frame. When Esc or M
ends the loop it simply runs again until the frame budget is used. A session fails on any exception and on any
broken world invariant that no known open bug explains (`KNOWN_OPEN` in `tests/support/invariants.py`). Each
session has its own temporary `HEXA_HOME`, and the Age of Discovery sessions of odd seeds play with the movement replay on (seeds 1, 5, 9 and so on with the reminders too). By default it plays seeds 1 and 2 of each mode, 800 frames (the
campaign 300), burst 0.3, in about 30 seconds; three environment variables scale it:

```bash
HEXA_MONKEY_SEEDS=30 HEXA_MONKEY_BURST=0.5 .venv/bin/python -m unittest tests.ui.test_monkey.MonkeyTest   # seeds 1 to 30
HEXA_MONKEY_SEEDS=5-9 HEXA_MONKEY_FRAMES=3000,campaign=600 .venv/bin/python -m unittest tests.ui.test_monkey.MonkeyTest
.venv/bin/python -m tools.monkey colony 7 800 --burst 0.5          # replay one session (a failure prints this line)
.venv/bin/python -m tools.monkey campaign 1-30 300 --burst 0.5     # bug hunting: a batch of seeds, a line each
.venv/bin/python -m tools.monkey --issues                          # the input withheld for known open crashes
```

`HEXA_MONKEY_SEEDS` is a count (`30`: seeds 1 to 30), a range (`5-9`) or a list (`3,8,12`); `HEXA_MONKEY_FRAMES`
sets every mode's budget (`3000`), one mode's (`campaign=600`) or both; `HEXA_MONKEY_BURST` is between 0 and 1. A
failing session prints its report and the command that replays it, `python -m tools.monkey <mode> <seed> <frames>
--burst <b>`, and saves both, with its last frame, to `test-artifacts/monkey-<mode>-<seed>.txt` and `.png`. Run
`tools/monkey.py` from the repository root with the venv's Python; `--log N` prints a session's last N actions and
`--digest` its digests (the same seed always plays the same session). Input that would hit a known open crash is
withheld (`KNOWN_ISSUES` in `tests/support/monkey.py`), so long runs can find other bugs; expected-failure tests pin
those crashes, and `--hit <issue>` lets that input through to reproduce one.

CI's `ui` job runs these tests on Python 3.12 with pygame 2.6.1 and adds a second coverage table, of lines
only: on 3.12 branch coverage is slow, and `HEXA_COVERAGE_BRANCH=0` switches it off in `.coveragerc`. Locally:

```bash
HEXA_COVERAGE_BRANCH=0 COVERAGE_CORE=sysmon HEXA_HOME=$(mktemp -d) .venv/bin/coverage run -m unittest discover -s tests/ui -t .
.venv/bin/coverage report
```

### Golden screenshots

`tests/ui/test_screenshots.py` draws 15 fixed-seed scenes (the start menu for each mode, Conquest map #42,
Colonisation map #5, Europe 1480 before and after choosing Portugal at the flat and the tile-art zooms, its panels,
the pause menu and its options, and random world #7) and compares each frame with its reviewed picture in
`tests/golden/linux/`. The comparison is exact first (a sha256 of the pixels); otherwise a pixel counts as
different when a channel is off by 8 or more, and a scene may have none (`max_pixels`, 0 by default). A failing
scene writes `<scene>.actual.png`, `<scene>.golden.png` and `<scene>.diff.png` (the frame darkened, the differing
pixels magenta) to `test-artifacts/` (`HEXA_TEST_ARTIFACTS`); CI attaches that folder to the failed run.

Text rendering differs a little between operating systems (FreeType moves some glyphs by a pixel on macOS), so the
goldens are made and compared on Linux, the CI reference. `tests/golden/linux/MANIFEST.json` records the
environment they were made in: the OS, Python major.minor, the pygame, SDL, SDL_ttf and FreeType versions, a hash
of pygame's bundled font, the smoothscale backend, the video driver and the desktop size. Where anything differs
(on a Mac, the OS), the screenshot tests are skipped and the skip names what differs. Three environment variables
change that:

- `HEXA_GOLDEN_STRICT=1` makes a different environment a failure instead of a skip, for a CI job that must compare.
- `HEXA_GOLDEN_ANY_OS=1` compares anyway, allowing 0.5 % of a frame's pixels to differ: a rough check on a Mac
  (measured: macOS differs from the goldens by 160 to 1,500 pixels a frame, 0.02 to 0.21 %).
- `UPDATE_GOLDEN=1` makes the goldens: every frame that isn't exactly its golden (or has none) is written as the new
  golden, `MANIFEST.json` gets the running environment, and a summary is printed and kept in
  `test-artifacts/golden-updates.txt`. It refuses to run anywhere but Linux.

Linux arm64 and x86-64 draw the same bytes (the harness forces the GENERIC smoothscale backend), so on any machine
with Docker, including an Apple Silicon Mac, this makes or checks the goldens exactly as CI's `ui` job does
(`--user` keeps the new files yours; `HOME=/tmp` lets pip install pygame for that user):

```bash
docker run --rm --platform linux/arm64 --user "$(id -u):$(id -g)" -e HOME=/tmp -e UPDATE_GOLDEN=1 \
  -v "$PWD":/work -w /work python:3.12-slim \
  sh -c 'pip install -q pygame==2.6.1 && HEXA_HOME=$(mktemp -d) python -m unittest tests.ui.test_screenshots'
```

Leave out `-e UPDATE_GOLDEN=1` (or add `-e HEXA_GOLDEN_STRICT=1`) to run the comparison instead. Without Docker,
the `goldens` workflow (`.github/workflows/goldens.yml`, run by hand from the Actions tab, optionally for another
branch or commit) makes them on GitHub's runner and uploads them as the `goldens` artifact; it never commits. Either
way, look at the new pictures (and `git diff --stat tests/golden/linux`) before committing them. A change that is
meant to alter the look of a window ships with its new goldens; only rewritten scenes change, since a golden whose
pixels are the same is left alone.

The `ui` job compares the goldens but doesn't set `HEXA_GOLDEN_STRICT=1` yet: until a CI run has shown that the
runner's environment matches `MANIFEST.json` (the scenes run, not skipped), a mismatch only skips them. Once one has,
add `HEXA_GOLDEN_STRICT: "1"` to the `ui` job's `env`.

### Nightly runs: soak, performance and long monkey sessions

`.github/workflows/nightly.yml` runs every night at 03:17 UTC, and by hand from the Actions tab with inputs for the
soak scale (`full` or `quick`) and the monkey's seeds, frames and burst. Its jobs:

- **soak** (`tools/soak.py`, no pygame): all-AI games with the world invariants checked at the start and after every
  turn (Conquest and Colonisation: every side's turn; the campaign: every season): 200 Conquest games to the end
  (seeds 0-199, each must have a winner by the turn limit), 50 Colonisation games of 40 rounds (seeds 0-49; the start
  and the goal vary with the seed), Europe 1480 for 100 seasons, and random worlds 1 to 3 for 40 seasons each. About 8
  minutes on a fast machine.
- **perf** (`tools/perf.py`, Python 3.12 with pygame): CPU time, the median of 3 runs, of building the Europe map and a
  random world from scratch, restoring the cached Europe snapshot, one all-AI season in 1480 and one in 1490, and a new
  `MapView`'s first draw at zoom 1 and 4, compared with `tests/perf_budget.json` (zoom 4 builds its landscape art a few
  hexes a frame within a time limit, so that draw is one such frame, not the whole picture). The table goes to the
  run's summary page. A time over its soft limit is noted; only one over its hard limit fails the job.
- **monkey** (one job per mode, Python 3.12 with pygame): `tests.ui.test_monkey.MonkeyTest` with
  `HEXA_MONKEY_SEEDS=50`, `HEXA_MONKEY_FRAMES=3000,campaign=600` and `HEXA_MONKEY_BURST=0.5` (a campaign session of
  3,000 frames takes about 1.5 minutes, so the campaign plays 600).

When a scheduled run fails, a last job opens an issue titled "Nightly failure" with the replay commands from the
logs, or comments on the one that is already open. Runs started by hand never touch issues. The failed jobs' logs
(and the monkey's last frames) are attached to the run.

```bash
python -m tools.soak --quick                    # every suite, a few short games (about 15 seconds)
python -m tools.soak                            # the nightly scale (about 8 minutes)
python -m tools.soak colony 0-9 --turns 20      # one suite (conquest, colony, europe, random), chosen seeds and length
python -m tools.soak conquest 17                # replay one game: a failure prints this line
python -m tools.perf                            # the timings against tests/perf_budget.json (about 1.5 minutes)
python -m tools.perf --only ai_season --runs 5  # some metrics, more runs; --list shows them with their budgets
.venv/bin/python -m tools.perf                  # with pygame, so the MapView metrics run too
```

A soak game fails on an exception or on a broken invariant that no known open bug explains (`KNOWN_OPEN` in
`tests/support/invariants.py`); it stops there and prints its report, ending with the command that replays it. Broken
invariants of known open bugs are counted as "known open" and don't fail. The same seed always plays the same game
(`--digest` prints the final world's digest). Both tools print a summary table, append it as markdown to
`$GITHUB_STEP_SUMMARY` when that is set, and exit with status 1 on a failure.

`tests/perf_budget.json` holds a `soft` and a `hard` limit in CPU seconds for each metric, and `measured`, the median
when the limits were set; its `_comment` says on what machine. The hard limits are about 4 times those medians and
the soft ones about 2 times, because shared CI runners are slower and noisier. A change that makes something slower on
purpose raises its limits in the same pull request. Timing never runs in the unit suite: `tests/test_perf.py` checks
the tool with fake metrics. Without pygame the MapView metrics are skipped with a note (`HEXA_REQUIRE_PYGAME=1`, which
the perf job sets, makes that an error). The last row of the table is information only: how much memory the world
module's caches keep as random worlds are built one after another (tracemalloc). `tests/test_memory.py` is the test of
that (#29: the caches must stay bounded; it builds four random worlds, so it is `@slow`).

### Save compatibility

Players keep their saves when they update the game, so a change to `hexa/campaign/` must not break games saved by
the code before it. The `save-compat` job of the tests workflow checks every pull request that changes
`hexa/campaign/` (or the tool): it checks out the merge base (where the pull request leaves its target branch) into a
`git worktree`, plays and saves three games with that code (`tools/save_compat.py write`: Europe 1480 as Portugal
after 3 seasons, the random world of seed 7 after 2 seasons, and a quicksave in the middle of Portugal's war with
Castile), then loads each one with the pull request's code and plays one more season (`check`). On other pull
requests the job only finds that nothing there changed and stops (plain `git diff`, no paths-filter action).

The rule, with `VERSION` in `hexa/campaign/saves.py`:

- While `VERSION` stays the same, every old save must load, keep the world invariants and play on. So a new world
  attribute or dataclass field needs a default for saves that don't have it: an entry in `WORLD_DEFAULTS` in
  `hexa/campaign/world.py`, a field default (`CampaignWorld._migrate` fills those in), or `getattr` /
  `__dict__.setdefault` where it is read. Renaming or moving a class that saves contain breaks them too.
- When old saves can't be supported, bump `VERSION`. Old saves must still never crash the game: each one is either
  refused quietly (`saves.load` returns `None` and the game says the save couldn't be loaded) or still loads and
  plays. `saves.load` reads every version from 1 to `VERSION`, so make it refuse the old version too if the migration
  can't handle it. Saves from a newer version are always refused.

A failure (exit status 1: a save broke under these rules, or the pull request's `hexa.campaign` can't even be
imported) names the save, the step that broke (loading or playing the season), the exception and the line of `hexa/`
it came from, and says how to fix it. To run it locally (any revision can be the base, and it needs no `tools/` folder
of its own):

```bash
git worktree add --detach /tmp/hexa-base master
python tools/save_compat.py write /tmp/hexa-base /tmp/hexa-compat   # saves made by /tmp/hexa-base's code (it prints which hexa it imported)
python tools/save_compat.py check /tmp/hexa-compat                  # loaded by this checkout's code
git worktree remove --force /tmp/hexa-base
```

`write` also writes `manifest.json` next to the saves (the base's `VERSION`, revision and what was saved). Exit
status 2 means a usage error (no `hexa` package in the checkout, no manifest yet) and 3 that the base's code could not
make the saves. `tests/test_save_compat.py` runs the tool end to end against temporary copies of `hexa/`: a renamed
class with and without a `VERSION` bump, a new attribute without a default, a header the save menus refuse, and a
bumped `VERSION` alone.

## Project layout

| File | What it does |
|---|---|
| `play.py` | Starts the game: menu, then the conquest window (mouse, keyboard, enemy turn timing) |
| `hexa/menu.py` | The start menu |
| `hexa/settings.py` | Player options, stored in `~/.hexa/settings.json` |
| `hexa/campaign/` | Age of Discovery: `geo.py` (real map, countries, markets, rivers), `randomgeo.py` (random worlds), `wfc.py` (wave function collapse), `art.py` (code-drawn tiles, figures, tokens), `data.py` (goods, buildings, balance), `world.py` (economy, trade, colonies, war), `ai.py`, `mapview.py`, `app.py`, `screens/` (the pause menu and the technology screen), `saves.py` (save slots), `resources.py` and `feed.py` (what the top bar, the floating text and the action log show), `hud/` (their drawing: `topbar.py`, `floating.py`, `actionlog.py`) |
| `hexa/colony/` | Colonisation mode: `rules.py`, `mapgen.py`, `world.py` (rules), `ai.py` (rivals, natives, royal army), `render.py`, `app.py` (window) |
| `hexa/rules.py` | Unit, terrain and balance numbers |
| `hexa/world.py` | Game state and rules: movement, combat, fog of war, turns, winning |
| `hexa/mapgen.py` | Random map generation |
| `hexa/ai.py` | The computer opponent |
| `hexa/render.py` | Drawing the map, units and info bar |
| `hexa/hexgrid.py` | Hex grid maths |
| `tests/` | Rule tests (see Development); shared helpers in `tests/support/`; headless window tests in `tests/ui/`; golden screenshots in `tests/golden/linux/` |
| `tools/` | Developer tools: `monkey.py` replays or hunts with the window tests' seeded monkey (`python -m tools.monkey`), `soak.py` plays long all-AI games checking the invariants every turn, `perf.py` times the slow parts against `tests/perf_budget.json` (both run nightly), `save_compat.py` checks that saves from an older revision still load (pull requests that touch `hexa/campaign/`) |
| `Hex.py`, `Game.py`, `Setting.py`, `Create_xml.py`, `Read_XML.py` | The original map editor and its XML map loading (`map*.xml`) |

## Credits

- Tile art: [Kenney Hexagon Pack](https://kenney.nl/assets/hexagon-pack) (CC0), in `hexagon-pack/`.
- Place names: GeoNames (https://www.geonames.org), licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/),
  pruned and adapted. `hexa/campaign/placenames.py` holds the pruned copy: the three biggest places in each land hex of
  the Europe map, without places that did not exist in 1480. Regions and spellings are hand-curated in `regions.py` and
  `naming.py`. The start menu's Credits button shows these lines.
