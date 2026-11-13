"""The battle marks on the map (battle slice 1, PR 6, spec 6.3): a crossed-swords badge above a battle's hex and, from
zoom 3 on, a tug-of-war bar under it. Drawn over the map by ``Hud.draw_world``, under the ribbons (a ribbon covers the
badge).

Everything comes from ``battleview.battle_view`` for the player, so the fog rule is the view's: a battle the player
cannot see has no mark, one he sees near has its numbers rounded. The bar is the FRONT LINE: the split is the army
morale of each side's lanes (combat.army_morale, the measure the break test uses), not its men. The map shows no name,
caption or percentage: the battle panel (screens/battle.py) has those. A gold tick marks the middle of the bar. The
badge is a sprite cached per zoom; the bar is drawn each frame. A click on the badge or the bar opens the battle panel:
``Marks.at`` gives the hex under a pixel (CampaignApp.left_click asks it).
"""
import pygame

from ...ui.cache import BoundedCache
from ...ui.icons import icon
from ..battleview import battle_view
from . import floating

MIN_ZOOM = 2            # from this zoom index on (hex radius 8 px) the battles show on the map
BAR_ZOOM = 3            # from this one the front-line bar shows under the badge
INK = (12, 14, 18)
GOLD = (255, 214, 70)
_BADGES = BoundedCache("battle_badge", 8)       # zoom index -> the badge sprite


def _badge_size(r):
    return min(32, round(12 + 0.6 * r))


def _badge(zoom, r):
    return _BADGES.get(zoom, lambda: icon("battle", _badge_size(r)))


def split(a, d):
    """The share of the bar the attacker's colour fills: its front morale over both (half when both are empty)."""
    return a / (a + d) if a + d > 0 else 0.5


class Marks:
    """The battle marks of one window. It holds no fonts: the map shows no text."""

    def __init__(self):
        self.hits = []          # (rect, hex) of the marks drawn this frame: a click there opens that battle

    def draw(self, ctx, hud):
        world = ctx.world
        self.hits = []
        if ctx.view.zoom < MIN_ZOOM or not world.battles:
            return
        view_rect = ctx.view_rect()
        ctx.screen.set_clip(view_rect)
        for battle in world.battles:
            view = battle_view(world, battle, world.player)
            if view is None or view["access"] == "hidden":
                continue
            x, y = floating.screen_point(ctx, battle.pos)
            if not view_rect.inflate(80, 80).collidepoint(x, y) or hud.covers(ctx, (x, y)):
                continue
            if ctx.ui.panel and ctx.panel_rect().collidepoint(x, y):
                continue
            self._mark(ctx, view, x, y, battle.pos)
        ctx.screen.set_clip(None)

    def at(self, pixel):
        """The hex of the battle whose badge or bar is under `pixel` (the marks of this frame), or None."""
        for rect, pos in self.hits:
            if rect.collidepoint(pixel):
                return pos
        return None

    def _mark(self, ctx, view, x, y, pos):
        r = ctx.view.r
        att, dfn = view["sides"]["attacker"][0], view["sides"]["defender"][0]
        a, d = view["side"][att]["front_morale"], view["side"][dfn]["front_morale"]
        badge = _badge(ctx.view.zoom, r)
        spot = badge.get_rect(center=(int(x), int(y - r - 1)))
        ctx.screen.blit(badge, spot)
        self.hits.append((spot, pos))
        if ctx.view.zoom < BAR_ZOOM:
            return
        width, height = round(2.0 * r), max(5, r // 4)
        bar = pygame.Rect(0, 0, width, height)
        bar.midtop = (int(x), int(y + 0.55 * r))
        frame = bar.inflate(4, 4)
        pygame.draw.rect(ctx.screen, INK, frame, border_radius=3)
        left = split(a, d) * width
        pygame.draw.rect(ctx.screen, ctx.world.countries[att].color, (bar.x, bar.y, max(1, round(left)), height))
        pygame.draw.rect(ctx.screen, ctx.world.countries[dfn].color,
                         (bar.x + round(left), bar.y, bar.w - round(left), height))
        shine = pygame.Surface((width, max(1, height // 2)), pygame.SRCALPHA)
        shine.fill((255, 255, 255, 50))                     # the top half a shade lighter: the two-tone look
        ctx.screen.blit(shine, bar.topleft)
        pygame.draw.line(ctx.screen, GOLD, (bar.centerx, bar.y - 3), (bar.centerx, bar.bottom + 2), 2)
        self.hits.append((frame, pos))
