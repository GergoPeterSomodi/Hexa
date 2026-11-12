"""The ledger panel: every country ranked by score, with its income and colonies."""
import pygame

from ...ui.kit import panel_frame
from ...ui.theme import GOLD, MUTED, TEXT


def draw(ctx, world, ui):
    """Draw the ranking (L)."""
    x, y, _w = panel_frame(ctx)
    ctx.text(ctx.title, "Ledger", (x, y))
    y += 32
    for cx, label in zip((x, x + 26, x + 190, x + 245, x + 305), ("#", "Country", "Score", "Income", "Colonies")):
        ctx.text(ctx.small, label, (cx, y), MUTED)
    y += 18
    for i, country in enumerate(world.ranking()[:28]):
        color = GOLD if country.tag == world.player else TEXT
        ctx.text(ctx.small, str(i + 1), (x, y), MUTED)
        pygame.draw.rect(ctx.screen, country.color, (x + 26, y + 4, 9, 9))
        ctx.text(ctx.small, country.name, (x + 40, y), color, 145)
        ctx.text(ctx.small, str(world.score(country.tag)), (x + 190, y), color)
        ctx.text(ctx.small, f"{country.balance:.0f}", (x + 245, y), color)
        ctx.text(ctx.small, str(len(world.colonies_of(country.tag))), (x + 305, y), color)
        y += 20
