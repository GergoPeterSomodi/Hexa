"""Rules of the Age of Discovery campaign, one module per system, as functions taking ``world``.

A system module never imports world.py, ui, render or pygame; ``CampaignWorld`` keeps a one-line facade for each
function the rest of the game calls. A module lists the world attributes it writes in OWNS.
Modules: worldgen (build time only), colonies (founding and colonial growth),
building (investment and building), military (raising, refits, drill, stacks),
debt (the debt limit, desertion and seizures),
research (techs, idea cards, ages and start techs),
trade (markets, routes, merchants and what moves along a route),
economy (prices, production, incomes, tax previews, collecting and growth).
"""
