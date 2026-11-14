"""The move card (castle-areas.md sections 4 item 3 and 5): with a stack of the player selected, the hex under the mouse
shows why the stack cannot take it, in the odds card's look beside the hex. The words are ``world.refusal``'s: a refusal
in red (the move does not happen), a note in the normal colour (the move happens, slowly or onto land it cannot take),
and the way out in grey. The right-click toast says the same words (``CampaignApp.right_click``).

Nothing is shown when the move simply happens, over an attack hover (the odds card has that hex), or while the map is
hidden. The answer is kept until the world, the hover or the stack changes, so the card costs one ``refusal`` per hover
change, not one per frame. This module reads the world and draws; it never changes the game.
"""
import pygame

from ...ui import kit
from ...ui.theme import BAD_C, GOLD, MUTED, TEXT
from .floating import screen_point

WIDTH, PAD, GAP = 300, 10, 14


class MoveCard:
    """The one card of the hovered hex: the refusal is read once per (world version, hover, stack, moves left)."""

    def __init__(self):
        self._key = None
        self._found = None              # (pos, (kind, text, way_out)) or None
        self._surface = None

    def why(self, ctx):
        """(pos, (kind, text, way_out)) when the selected stack has a refusal or note for the hovered hex, else None."""
        ui, world = ctx.ui, ctx.world
        if ctx.player is None or ctx.busy or ui.replay.active or ui.hover is None or ui.hover not in world.terrain:
            return None
        if ui.hover in ui.attacks:
            return None
        group = ctx.active()
        if not group or group[0].owner != ctx.player or ui.hover == group[0].pos:
            return None
        key = (world.version, ui.hover, tuple(u.id for u in group), min(u.moves_left for u in group))
        if key != self._key:
            self._key = key
            why = world.refusal(group, ui.hover)
            self._found = (ui.hover, why) if why else None
            self._surface = None
        return self._found

    def draw(self, ctx, hud):
        """Draw the card beside the hovered hex, on the map (not over the side panel or the HUD)."""
        if hud.covers(ctx, ctx.ui.mouse):
            return
        found = self.why(ctx)
        if found is None:
            return
        pos, (kind, text, way) = found
        if self._surface is None:
            self._surface = _render(ctx, pos, kind, text, way)
        surface = self._surface
        area = ctx.view_rect().copy()                 # the map, not the side panel that may cover its right edge
        if ctx.ui.panel:
            area.right = min(area.right, ctx.panel_rect().x)
        x, y = screen_point(ctx, pos)
        right = int(x + ctx.view.r + GAP)
        left = int(x - ctx.view.r - GAP - surface.get_width())
        rect = surface.get_rect(topleft=(right if right + surface.get_width() <= area.right else left,
                                         int(y - surface.get_height() / 2)))
        rect.clamp_ip(area)
        ctx.screen.set_clip(area)
        ctx.screen.blit(surface, rect)
        ctx.screen.set_clip(None)


def _render(ctx, pos, kind, text, way):
    """The card as a surface: the place's name in gold, the cause (red for a refusal, normal for a note), the way out."""
    inner = WIDTH - 2 * PAD
    prov = ctx.world.provinces.get(pos)
    title = kit.wrap(ctx.bold, prov.name if prov else "Water", inner)
    body = [(kit.wrap(ctx.font, text, inner), BAD_C if kind == "refusal" else TEXT)]
    if way:
        body.append((kit.wrap(ctx.font, way, inner), MUTED))
    height = PAD + len(title) * ctx.bold.get_linesize() + 4 + PAD
    for lines, _ in body:
        height += len(lines) * ctx.font.get_linesize() + 4
    surface = pygame.Surface((WIDTH, height), pygame.SRCALPHA)
    surface.fill((12, 14, 18, 240))
    pygame.draw.rect(surface, GOLD, surface.get_rect(), 1, border_radius=6)
    y = PAD
    for line in title:
        surface.blit(ctx.bold.render(line, True, GOLD), (PAD, y))
        y += ctx.bold.get_linesize()
    y += 4
    for lines, colour in body:
        for line in lines:
            surface.blit(ctx.font.render(line, True, colour), (PAD, y))
            y += ctx.font.get_linesize()
        y += 4
    return surface
