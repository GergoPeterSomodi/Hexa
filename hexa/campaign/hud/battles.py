"""The battle marks on the map (battle slice 1, PR 6, spec 6.3): a crossed-swords badge above a battle's hex and, below
it, a tug-of-war bar with the place's battle name. Drawn over the map by ``Hud.draw_world``, above the ribbons.

Everything comes from ``battleview.battle_view`` for the player, so the fog rule is the view's: a battle the player
cannot see has no mark, one he sees near has its numbers rounded. The bar is the FRONT LINE: the split is the army
morale of each side's lanes (combat.army_morale, the measure the break test uses), not its men. The small marks on the
bar show where each side breaks on morale alone, with the other side as it stands. The badge is a sprite cached per
zoom; the bar is drawn each frame. Clicking the badge is not wired yet (the battle panel, PR 7).
"""
import pygame

from ...ui import theme
from ...ui.cache import BoundedCache
from ...ui.icons import icon
from ..battleview import battle_view
from ..data import BREAK
from . import floating

MIN_ZOOM = 2            # from this zoom index on (hex radius 8 px) the battles show on the map
NAME_ZOOM = 3           # from this one the battle's name shows under the bar
WHITE = (250, 248, 240)
INK = (12, 14, 18)
_BADGES = BoundedCache("battle_badge", 8)       # zoom index -> the badge sprite


def _badge_size(r):
    return min(56, int(10 + 1.6 * r))


def _badge(zoom, r):
    return _BADGES.get(zoom, lambda: icon("battle", _badge_size(r)))


def split(a, d):
    """The share of the bar the attacker's colour fills: its front morale over both (half when both are empty)."""
    return a / (a + d) if a + d > 0 else 0.5


def break_marks(a, d):
    """Where the two break points stand on the bar (0 to 1 from the left): the attacker's when its front reaches BREAK
    with the defender's as it is, and the defender's when its front reaches BREAK with the attacker's as it is."""
    return BREAK / (BREAK + d) if BREAK + d > 0 else 0.0, a / (a + BREAK) if a + BREAK > 0 else 1.0


class Marks:
    """The battle marks of one window. It holds the fonts (made with the window, not cached for the whole run)."""

    def __init__(self):
        self.small = theme.new_font(12, bold=True)
        self.name = theme.new_font(14, bold=True, names=theme.RIBBON)

    def draw(self, ctx, hud):
        world = ctx.world
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
            self._mark(ctx, view, x, y)
        ctx.screen.set_clip(None)

    def _mark(self, ctx, view, x, y):
        r = ctx.view.r
        att, dfn = view["sides"]["attacker"][0], view["sides"]["defender"][0]
        a, d = view["side"][att]["front_morale"], view["side"][dfn]["front_morale"]
        badge = _badge(ctx.view.zoom, r)
        ctx.screen.blit(badge, badge.get_rect(center=(int(x), int(y - r - badge.get_height() / 2 - 2))))
        width, height = max(60, int(r * 2.6)), max(8, r // 2)
        bar = pygame.Rect(0, 0, width, height)
        bar.midtop = (int(x), int(y + r + 4))
        frame = bar.inflate(4, 4)
        pygame.draw.rect(ctx.screen, INK, frame, border_radius=3)
        left = split(a, d) * width
        pygame.draw.rect(ctx.screen, ctx.world.countries[att].color, (bar.x, bar.y, max(1, round(left)), height))
        pygame.draw.rect(ctx.screen, ctx.world.countries[dfn].color,
                         (bar.x + round(left), bar.y, bar.w - round(left), height))
        for share in break_marks(a, d):
            mark = bar.x + round(share * width)
            pygame.draw.line(ctx.screen, WHITE, (mark, bar.y - 2), (mark, bar.bottom + 1), 1)
        if width >= 60:
            self._pct(f"{round(a * 100)}%", bar.x + 4, bar.centery, ctx.screen, "left")
            self._pct(f"{round(d * 100)}%", bar.right - 4, bar.centery, ctx.screen, "right")
        if ctx.view.zoom >= NAME_ZOOM:
            name = self.name.render(view["name"] or "Battle", True, WHITE)
            ctx.screen.blit(name, name.get_rect(midtop=(bar.centerx, bar.bottom + 3)))
            caption = self.small.render("front line morale", True, WHITE)
            ctx.screen.blit(caption, caption.get_rect(midtop=(bar.centerx, bar.bottom + 3 + name.get_height() - 2)))

    def _pct(self, text, x, y, screen, align):
        """A share on the bar: white, with a dark shadow so it reads on either side's colour."""
        shadow = self.small.render(text, True, INK)
        img = self.small.render(text, True, WHITE)
        rect = img.get_rect(midleft=(x, y)) if align == "left" else img.get_rect(midright=(x, y))
        screen.blit(shadow, rect.move(1, 1))
        screen.blit(img, rect)
