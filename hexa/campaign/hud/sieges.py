"""The siege marks on the map (release 0.2.2, design docs/design/sieges-and-retreats.md 4.7): the siege badge above a
besieged place's hex (siegebadge.py: the amber dial in a ring, filled by the meter), a hover card with its numbers and,
for the defender, its relief line, the grey flash of a siege lifted (once, a second or so), and a click that opens the
province. Drawn over the map by ``Hud.draw_world``, under the ribbons, like the battle marks (hud/battles.py).

Everything comes from ``battleview.siege_view`` for the player, so the fog rule is the view's: a siege the player cannot
see has no badge, one he sees near has its numbers rounded. A battle hex is never also a siege hex (the rules), so the
two marks never meet. The sprite is cached per size (siegebadge); the card is registered as a hover area each frame.
The flash comes from the feed (``feed.take_lifted``), which told the lift while the place was in sight. Nothing here
changes the game.
"""
import pygame

from ...ui.theme import BAD_C, GOOD_C, MUTED, TEXT, WARN_C
from ..battleview import siege_view
from . import siegebadge
from .battles import MIN_ZOOM
from .floating import screen_point

FLASH_MS = 1400         # how long the grey badge of a lifted siege stays on the map
MAX_AGE = 2.0           # seconds: a lift told longer ago than this (the map was hidden) is not flashed


def _s(n):
    return "" if n == 1 else "s"


def card(view):
    """The hover card of a siege (hud/kit.hover_card's title and lines): its meter, the seasons it falls in, the stores or
    the hunger, and for the defender the relief line."""
    title = view["name"] or f"Siege of {view['place']}"
    done, need, rate = round(view["progress"]), round(view["need"]), round(view["rate"])
    lines = [(f"{done} of {need}, +{rate} a season", TEXT)]
    if view["falls_in"] is None:
        lines.append(("Too few men to take it", WARN_C))
    else:
        falls = view["falls_in"]
        lines.append((f"Falls in about {falls} season{_s(falls)}", TEXT))
    if view["starving"]:
        lines.append((f"The garrison is starving: +{view['hunger']} a season", BAD_C))
    else:
        left = view["stores_left"]
        lines.append((f"Stores for {left} more season{_s(left)}", MUTED))
    if view["relief"]:
        army = view["relief"][0]
        lines.append((f"Relief: your army of {army['men']:,} men can reach it in {army['seasons']} "
                      f"season{_s(army['seasons'])}", GOOD_C))
    return title, lines


class Marks:
    """The siege marks of one window: the badges of this frame (``hits``, for clicks) and the lifted flashes."""

    def __init__(self):
        self.hits = []          # (rect, hex) of the badges drawn this frame
        self.flashes = []       # (hex, progress, need, ms when it started): a lifted siege's grey badge

    def draw(self, ctx, hud):
        world = ctx.world
        self.hits = []
        now = pygame.time.get_ticks()
        self.flashes += [(pos, progress, need, now) for pos, progress, need in ctx.game.feed.take_lifted(MAX_AGE)]
        self.flashes = [flash for flash in self.flashes if now - flash[3] < FLASH_MS]
        if ctx.view.zoom < MIN_ZOOM:
            return
        view_rect = ctx.view_rect()
        ctx.screen.set_clip(view_rect)
        for pos in [pos for pos, prov in world.provinces.items() if prov.besieger]:
            view = siege_view(world, pos, world.player)
            if view is None or view["access"] == "hidden" or view["progress"] is None:
                continue
            self._mark(ctx, hud, view_rect, siegebadge.siege_badge(ctx.view.r, view["progress"], view["need"],
                                                                  view["rate"]), pos, card(view))
        for pos, progress, need, _ in self.flashes:
            self._mark(ctx, hud, view_rect, siegebadge.siege_badge(ctx.view.r, progress, need, lifted=True), pos, None)
        ctx.screen.set_clip(None)

    def _mark(self, ctx, hud, view_rect, badge, pos, hover):
        x, y = screen_point(ctx, pos)
        if not view_rect.inflate(80, 80).collidepoint(x, y) or hud.covers(ctx, (x, y)):
            return
        if ctx.ui.panel and ctx.panel_rect().collidepoint(x, y):
            return
        spot = badge.get_rect(center=(int(x), int(y - ctx.view.r - 1)))
        ctx.screen.blit(badge, spot)
        if hover is not None:
            self.hits.append((spot, pos))
            ctx.hoverable(spot, hover)

    def at(self, pixel):
        """The hex of the siege whose badge is under `pixel` (the marks of this frame), or None."""
        for rect, pos in self.hits:
            if rect.collidepoint(pixel):
                return pos
        return None

    def click(self, ctx, pixel):
        """A click on a siege badge opens its province (the press table's "province"). True when it did."""
        if ctx.hud.covers(ctx, pixel):
            return False
        pos = self.at(pixel)
        if pos is None:
            return False
        ctx.press(("province", ctx.world.provinces[pos]))
        return True
