"""The raise panel: every kind of unit the player may raise in a province, each with its cost and a hover card."""
from ...ui.kit import heading, panel_frame
from ...ui.theme import BAD_C, GOLD
from .. import tech
from ..data import CARAVEL, ERAS
from .cards import troop_card


def draw(ctx, world, ui, prov):
    """Draw the panel for raising units in `prov` (named raise_ because raise is a keyword)."""
    tag = world.player
    x, y, w = panel_frame(ctx)
    country = world.countries[tag]
    ctx.text(ctx.title, f"Raise in {world.place(prov)}", (x, y), width=w - 30)
    y += 32
    ctx.text(ctx.bold, ERAS[country.era][0], (x, y), GOLD)
    y += 22
    if country.researching:
        cur = tech.tech(country.researching)
        line = f"Researching {cur.name} {country.research:.0f}/{world.tech_cost(tag, cur.key)} · Technology (T)"
    else:
        line = "Nothing researched · Technology (T)"
    ctx.button((x, y, w, 26), line, True, ("tech",), "Research, ideas and the tech tree (T)", small=True)
    y += 32
    y = heading(ctx, "Troops", y + 4)
    for kind in world.raise_options(tag):
        if kind.naval and not prov.coastal:
            continue
        if kind is CARAVEL:
            y = heading(ctx, "Others", y + 4)
        ok, reason = world.recruit_check(tag, prov, kind)
        label = f"{kind.name}  {kind.attack}/{kind.defense}  mv {kind.moves}" if kind.war else kind.name
        title, lines = troop_card(world, kind, prov)
        if reason:
            lines = [(reason, BAD_C)] + lines
        ctx.button((x, y, w, 25), label, ok, ("recruit", prov, kind), (title, lines),
                   f"{world.unit_cost(prov, kind)} ducats", small=True)
        y += 29
    ctx.button((x, y + 6, w, 24), "Back to the province", True, ("province", prov), small=True)
