"""The action log, in the bottom-left corner (docs/design/ui/07_action_log.png). It replaces the five grey lines of
``world.log`` that were drawn there.

    expanded   a box of 470 px: a header (the scroll icon, the filters All / War / Money / Mine, a collapse arrow) and
               the lines grouped by season, newest first. A line is an icon and a keyword in the colour of its kind
               (hud/style.py), then the sentence (white for what the player did, grey for others). Its place name
               is a link: a click anywhere on the line glides the camera there, rings the hex and, if the player's
               stack stands on it, selects the stack. The mouse wheel scrolls; the log keeps two years (feed.py).
    collapsed  one line (the newest entry) and, in red, how many lines came since it was last open ("+8 new").

What the log shows comes from ``feed.of(world).entries(filter)``. The first line of the game and the notes that have
no event of their own (``world.log``) show only while the feed is empty, so a new game does not open on a blank line.
"""
import pygame

from ...ui import kit
from ...ui.icons import icon
from ...ui.theme import CARD_BG, FAINT, INFO_C, LINE, MUTED, ROW_HOVER, TEXT, new_font
from ..feed import FILTERS
from . import style

BOX_W = 470             # the expanded box
BAR_W = 400             # the collapsed one
ROW = 20                # a line
HEAD = 36               # the header
MAX_ROWS = 11           # lines shown at once: the box is always 268 px high
BADGE = (150, 56, 48)   # the "+8 new" badge
NOOP = ("log", "noop")  # the box swallows clicks that would reach the map


class LogState:
    """What the player did with the log: open or collapsed, the filter, how far it is scrolled."""

    def __init__(self):
        self.open = False
        self.filter = "all"
        self.scroll = 0
        self.box = None             # the rect it occupied on the last frame (the wheel and the clicks use it)
        self.plain = new_font(12)           # made here, not with theme.font(): that cache can outlive pygame
        self.bold = new_font(12, bold=True)


def rows_of(feed, filter):
    """The lines to show: ("head", "Summer 1481") and ("item", FeedItem), newest season first."""
    rows = []
    for _season, label, items in feed.entries(filter):
        rows.append(("head", label))
        rows += [("item", item) for item in items]
    return rows


def newest(feed):
    """The newest item of the log, or None (what the collapsed bar says)."""
    for season in sorted(feed.groups, reverse=True):
        if feed.groups[season]:
            return feed.groups[season][-1]
    return None


def press(ctx, hud, action):
    """("log", "toggle"), ("log", "filter", name) or ("log", "goto", hex): the buttons of the log."""
    state = hud.log
    if action[1] == "toggle":
        state.open, state.scroll = not state.open, 0
        ctx.game.feed.mark_read()
    elif action[1] == "filter" and action[2] in FILTERS:
        state.filter, state.scroll = action[2], 0
    elif action[1] == "goto":
        hud.go(ctx, action[2])


def wheel(ctx, hud, dy):
    """Scroll the open log if the mouse is over it; True if it did (the map does not zoom then)."""
    state = hud.log
    if not (state.open and state.box and state.box.collidepoint(ctx.ui.mouse)):
        return False
    state.scroll = max(0, state.scroll - 2 * dy)
    return True


def draw(ctx, hud):
    """Draw the log (expanded or collapsed) and register its buttons."""
    state, feed = hud.log, ctx.game.feed
    view = ctx.view_rect()
    if state.open:
        feed.mark_read()
        state.box = _expanded(ctx, state, feed, view)
    else:
        state.box = _collapsed(ctx, state, feed, view)
    if state.box.collidepoint(ctx.ui.mouse):
        ctx.ui.hover = None             # no hex card for the map under the log
    ctx.ui.buttons.append(kit.Button(state.box, "", True, NOOP))


def _frame(ctx, rect):
    kit.shade(ctx.screen, rect, (*CARD_BG, 236))
    pygame.draw.rect(ctx.screen, LINE, rect, 1, border_radius=6)


def _collapsed(ctx, state, feed, view):
    """The one-line bar: the newest entry, the badge and the arrow. The whole bar opens the log."""
    box = pygame.Rect(8, view.bottom - 10 - 30, BAR_W, 30)
    _frame(ctx, box)
    img = icon("scroll", 16)
    ctx.screen.blit(img, (box.x + 10, box.y + 7))
    last = newest(feed)
    room = box.w - 32 - 100
    if last:
        _line(ctx, state, last, pygame.Rect(box.x + 32, box.y, room, box.h), False)
    elif ctx.world.log:
        kit.text(ctx.screen, ctx.small, ctx.world.log[-1], (box.x + 32, box.centery - 7), TEXT, room)
    kit.icon_button(ctx, (box.right - 30, box.y + 4, 22, 22), "up", "Open the log", ("log", "toggle"),
                    "Open the action log")
    if feed.unread:
        badge = pygame.Rect(box.right - 82, box.y + 6, 46, 18)
        pygame.draw.rect(ctx.screen, BADGE, badge, border_radius=9)
        kit.text(ctx.screen, state.bold, f"+{feed.unread} new" if feed.unread < 100 else "99+",
                 (badge.centerx, badge.y + 1), TEXT, align="center")
    ctx.ui.buttons.append(kit.Button(box, "Open the log", True, ("log", "toggle"), "Open the action log"))
    return box


def _expanded(ctx, state, feed, view):
    """The box with the header, the filters and the lines of the season groups."""
    rows = rows_of(feed, state.filter)
    shown = MAX_ROWS                    # a fixed height, so the filter buttons stay where the mouse is
    box = pygame.Rect(8, view.bottom - 10 - (HEAD + shown * ROW + 8), BOX_W, HEAD + shown * ROW + 8)
    _frame(ctx, box)
    _header(ctx, state, box)
    state.scroll = max(0, min(state.scroll, len(rows) - shown))
    y = box.y + HEAD + 2
    if not rows:
        empty = "Nothing to tell yet." if state.filter == "all" else "Nothing of this kind yet."
        kit.text(ctx.screen, ctx.small, empty, (box.x + 12, y + 2), FAINT)
    for kind, row in rows[state.scroll:state.scroll + shown]:
        line = pygame.Rect(box.x + 4, y, box.w - 8, ROW)
        if kind == "head":
            kit.text(ctx.screen, state.plain, row, (box.x + 10, y + 1), FAINT)
            start = box.x + 18 + state.plain.size(row)[0]
            pygame.draw.line(ctx.screen, LINE, (start, y + 9), (box.right - 12, y + 9))
        else:
            _line(ctx, state, row, line, True)
        y += ROW
    if len(rows) > shown:               # the scrollbar
        track = pygame.Rect(box.right - 6, box.y + HEAD, 3, shown * ROW)
        pygame.draw.rect(ctx.screen, (40, 45, 55), track, border_radius=2)
        thumb = max(14, track.h * shown // len(rows))
        top = track.y + (track.h - thumb) * state.scroll // max(1, len(rows) - shown)
        pygame.draw.rect(ctx.screen, (100, 108, 120), (track.x, top, 3, thumb), border_radius=2)
    return box


def _header(ctx, state, box):
    img = icon("scroll", 16)
    ctx.screen.blit(img, (box.x + 10, box.y + 9))
    kit.text(ctx.screen, ctx.bold, "Log", (box.x + 32, box.y + 7), TEXT)
    x = box.x + 72
    for name in FILTERS:
        label = name.title()
        w = ctx.small.size(label)[0] + 16
        r = kit.button(ctx, (x, box.y + 6, w, 22), label, True, ("log", "filter", name), small=True)
        if state.filter == name:
            pygame.draw.rect(ctx.screen, (255, 214, 70), r, 1, border_radius=5)
        x += w + 3
    kit.icon_button(ctx, (box.right - 30, box.y + 6, 22, 22), "down", "Collapse the log", ("log", "toggle"),
                    "Collapse the action log")
    pygame.draw.line(ctx.screen, LINE, (box.x + 1, box.y + 33), (box.right - 2, box.y + 33))


def split_place(world, item):
    """(text before, place name, text after) of an item's sentence: the place name is the link. No link when the
    item has no hex or its place is not in the sentence."""
    prov = world.provinces.get(item.pos) if item.pos else None
    place = world.place(prov) if prov else ""
    at = item.sentence.find(place) if place else -1
    if at < 0:
        return item.sentence, "", ""
    return item.sentence[:at], place, item.sentence[at + len(place):]


def squeeze(font_, parts, room):
    """`parts` (before, place, after) cut to fit `room` pixels: the text after the place first, then the text before,
    the place last."""
    parts = list(parts)
    for i in (2, 0, 1):
        others = sum(font_.size(p)[0] for j, p in enumerate(parts) if j != i)
        if others + font_.size(parts[i])[0] > room:
            parts[i] = kit.fit(font_, parts[i], max(0, room - others))
    return parts


def _line(ctx, state, item, rect, hoverable):
    """One entry: icon, keyword, sentence with its place link. With `hoverable` the line is a button that jumps."""
    colour, glyph = style.colour(item.colour_kind), style.glyph(item.colour_kind)
    hot = hoverable and rect.collidepoint(ctx.ui.mouse)
    if hot:
        pygame.draw.rect(ctx.screen, ROW_HOVER, rect, border_radius=3)
    if hoverable:
        ctx.screen.blit(icon(glyph, 14, colour), (rect.x + 6, rect.y + 3))
    x = rect.x + (26 if hoverable else 0)
    bold = state.bold
    if item.text:
        x += kit.text(ctx.screen, bold, item.text + " ", (x, rect.y + 2), colour).w
    right = rect.right - (64 if hot and item.pos else 14)
    parts = squeeze(ctx.small, split_place(ctx.world, item), right - x)
    body = TEXT if item.mine else MUTED
    x += kit.text(ctx.screen, ctx.small, parts[0], (x, rect.y + 2), body).w
    if parts[1]:
        link = kit.text(ctx.screen, bold, parts[1], (x, rect.y + 2), INFO_C)
        pygame.draw.line(ctx.screen, INFO_C, (link.x, link.bottom - 1), (link.right, link.bottom - 1))
        x = link.right
    kit.text(ctx.screen, ctx.small, parts[2], (x, rect.y + 2), body)
    if hot and item.pos:
        ctx.screen.blit(icon("target", 14), icon("target", 14).get_rect(midright=(rect.right - 8, rect.centery)))
        kit.text(ctx.screen, ctx.small, "jump", (rect.right - 28, rect.y + 2), INFO_C, align="right")
    if hoverable and item.pos:
        place = parts[1] or item.text
        hint = f"Click: the camera goes to {place}" if parts[1] else "Click: show it on the map"
        ctx.ui.buttons.append(kit.Button(rect, place, True, ("log", "goto", item.pos), hint))
