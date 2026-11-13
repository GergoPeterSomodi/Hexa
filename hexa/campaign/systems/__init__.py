"""Rules of the Age of Discovery campaign, one module per system, as functions taking ``world``.

A system module never imports world.py, ui, render or pygame; ``CampaignWorld`` keeps a one-line facade for each
function the rest of the game calls. A module lists the world attributes it writes in OWNS.
Modules: worldgen (build time only), colonies (founding and colonial growth),
building (investment and building), military (raising, refits, drill, stacks),
debt (the debt limit, desertion and seizures),
research (techs, idea cards, ages and start techs),
trade (markets, routes, merchants and what moves along a route),
economy (prices, production, incomes, tax previews, collecting and growth),
terrain (movement cost, winter, ridge crests, mountain passes, where a new land unit appears),
supply (who is fed, foraging and the season's attrition),
movement (reach, paths, zones of control, the march and the cost field),
war (war and peace, attacks, battles and sieges),
season (the ordered PHASES of end_round, the turn's units, sight and scores).
"""
