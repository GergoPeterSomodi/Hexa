"""Floating action text: a ribbon tag rising from the hex where something happened (treatment C of
docs/design/ui/05_floating_text_styles.png, motion of 06_floating_text_motion.png).

The feed (campaign/feed.py) decides WHAT is told and to whom: an item floats only if the player is a party to it or
sees its hex. This module decides what the screen shows of that:

    only hexes the camera sees   the hex must be inside the map view, not under the open side panel, its ribbon not
                                 under the action log or the minimap and, if the player is not a party to it, in
                                 the player's vision. Everything else is only a
                                 line in the action log.
    several at one hex           they queue 0.3 s apart and start 18 px lower each (the oldest rises on top); at
                                 most 3 wait or fly at a hex, and 16 in all (the rest are only log lines).
    motion                       the ribbon starts above the hex, rises 40 px with an ease-out and is gone after
                                 1.1 s: it pops in within 0.06 s, holds until 0.6 s and fades out. Its size goes
                                 60 % - 120 % - 100 % in the first 0.14 s. Same size at every zoom.

A ribbon is a dark pill with an icon and the word, edged in the colour of its kind (hud/style.py), so it reads over
grass, snow, sea and towns alike. ``Floaters.draw`` follows the camera: the ribbon keeps its hex while the map pans.
"""
import pygame

from ...ui import theme
from ...ui.icons import icon
from . import style

LIFE = 1.1              # seconds a ribbon lives
RISE = 40               # pixels it rises
STAGGER = 0.3           # seconds between ribbons of one hex
PER_HEX = 3             # ribbons waiting or flying at one hex
MAX_LIVE = 16           # ribbons waiting or flying in all
LANE = 18               # pixels each ribbon of a hex starts lower than the one before (the oldest is on top)
HEIGHT = 28             # the pill
EDGE = 30               # a hex nearer than this to the edge of the map view floats nothing


def motion(t):
    """(rise in pixels, scale, alpha 0-255) of a ribbon `t` seconds after it started."""
    rise = RISE * (1 - (1 - min(t, LIFE) / LIFE) ** 2)
    if t < 0.06:
        scale = 0.6 + 0.6 * t / 0.06
    elif t < 0.14:
        scale = 1.2 - 0.2 * (t - 0.06) / 0.08
    else:
        scale = 1.0
    alpha = 255 if t <= 0.6 else max(0, int(255 * (1 - (t - 0.6) / 0.5)))
    if t < 0.06:
        alpha = int(255 * t / 0.06)
    return rise, scale, alpha


def lighter(colour, k):
    return tuple(int(v + (255 - v) * k) for v in colour)


def ribbon(font, text, kind):
    """The pill for `text` in the colours of `kind`: dark, an icon, the word, an edge and a soft shadow."""
    colour = style.colour(kind)
    word = font.render(text, True, lighter(colour, 0.2))
    width = word.get_width() + 44
    out = pygame.Surface((width + 4, HEIGHT + 4), pygame.SRCALPHA)
    pygame.draw.rect(out, (0, 0, 0, 90), (3, 4, width, HEIGHT), border_radius=14)
    pygame.draw.rect(out, (*theme.INK, 255), (0, 0, width, HEIGHT), border_radius=14)
    pygame.draw.rect(out, (22, 25, 31, 255), (1, 1, width - 2, HEIGHT - 2), border_radius=13)
    pygame.draw.rect(out, (*colour, 255), (1, 1, width - 2, HEIGHT - 2), 2, border_radius=13)
    out.blit(icon(style.glyph(kind), 16, colour), (10, 6))
    out.blit(word, (32, (HEIGHT - word.get_height()) // 2))
    return out


def screen_point(ctx, pos):
    """Where the centre of hex `pos` is on the screen."""
    rect = ctx.view_rect()
    x, y = ctx.view.center(pos)
    return x - ctx.camera[0] + rect.x, y - ctx.camera[1] + rect.y


def can_see(ctx, item):
    """Whether the camera shows the hex of a floating item now: inside the map view (an edge's width in), not under
    the open panel, and not in fog unless the player is a party to it."""
    world = ctx.world
    if item.pos is None or item.pos not in world.terrain:
        return False
    if not (item.mine or world.player is None or item.pos in world.visible):
        return False
    x, y = screen_point(ctx, item.pos)
    rect = ctx.view_rect()
    if not rect.inflate(-2 * EDGE, -2 * EDGE).collidepoint(x, y):
        return False
    if ctx.ui.panel and ctx.panel_rect().collidepoint(x, y):
        return False
    pill = pygame.Rect(0, 0, 150, HEIGHT + 4)           # about where the ribbon will be
    pill.center = (x, y - 12 - min(ctx.view.r, 34) * 0.8)
    hiding = [ctx.minimap_rect()] + ([ctx.hud.log.box] if ctx.hud.log.box else [])
    return not any(box.colliderect(pill) for box in hiding)


class Floaters:
    """The ribbons in the air: ``live`` holds [item, start (ms), lane] in the order they were told."""

    def __init__(self):
        self.live = []
        self.font = theme.new_font(17, bold=True, names=theme.RIBBON)       # not theme.font(): it can outlive pygame
        self._ribbons = {}                  # (text, kind) -> the pill, made once

    def pill(self, item):
        key = (item.text, item.colour_kind)
        if key not in self._ribbons:
            if len(self._ribbons) > 128:
                self._ribbons.clear()
            self._ribbons[key] = ribbon(self.font, *key)
        return self._ribbons[key]

    def add(self, ctx, items, now):
        """Take the items the feed told this frame; those the camera cannot see are dropped (the log has them)."""
        for item in items:
            here = [entry for entry in self.live if entry[0].pos == item.pos]
            if len(self.live) >= MAX_LIVE or len(here) >= PER_HEX or not can_see(ctx, item):
                continue
            start = max([now] + [entry[1] + int(STAGGER * 1000) for entry in here])
            self.live.append([item, start, len(here)])

    def draw(self, ctx, now):
        """Draw every ribbon that has started, over the map; forget those that are done."""
        if not self.live:
            return
        rect = ctx.view_rect()
        ctx.screen.set_clip(rect)
        keep = []
        for entry in self.live:
            item, start, lane = entry
            t = (now - start) / 1000
            if t > LIFE:
                continue
            keep.append(entry)
            if t < 0:
                continue
            rise, scale, alpha = motion(t)
            img = self.pill(item)
            if scale != 1.0:
                img = pygame.transform.smoothscale(img, (max(1, int(img.get_width() * scale)),
                                                         max(1, int(img.get_height() * scale))))
            img.set_alpha(alpha)
            x, y = screen_point(ctx, item.pos)
            base = 12 + min(ctx.view.r, 34) * 0.8
            ctx.screen.blit(img, img.get_rect(center=(int(x), int(y - base - rise + lane * LANE))))
            img.set_alpha(255)
        self.live = keep
        ctx.screen.set_clip(None)
