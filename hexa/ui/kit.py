"""The drawing helpers every window shares, in today's ("classic") look. Immediate mode: call them while drawing.

A ``ctx`` is the window object that is drawing (``CampaignApp``): it has ``screen``, ``ui`` (with ``mouse`` and the
``buttons`` and ``hoverables`` lists), the fonts ``font`` / ``small`` / ``bold`` / ``title`` and the geometry methods
``panel_rect()`` and ``view_rect()``. ``button`` registers a hit box on ``ctx.ui.buttons``; the window's ``press()``
gets the action. Text helpers (``fit``, ``wrap``, ``text``) need only a font and a surface.
"""
import pygame

from .icons import icon
from .theme import (BUTTON_FACE, BUTTON_FACE_HOT, BUTTON_FACE_OFF, FAINT, GOLD, LINE, MENU_BUTTON, MENU_DISABLED,
                    MENU_HOVER, MENU_WARN, MUTED, ROW_HOVER, SHADE, TECH_BUTTON, TECH_BUTTON_HOT, TECH_BUTTON_OFF,
                    TECH_FAINT, TECH_MUTED, TECH_TEXT, TEXT, TOGGLE_FACE, TOGGLE_HOT)


class Button:
    """A hit box on screen: its rectangle, what it says, whether it works, the action to press() and its hint."""

    def __init__(self, rect, label, enabled, action, hint="", detail=""):
        self.rect, self.label, self.enabled, self.action, self.hint, self.detail = \
            rect, label, enabled, action, hint, detail


# ----- text ----------------------------------------------------------------------------------------------------
def fit(font, text, width):
    """`text` cut down to `width` pixels, ending in an ellipsis when it had to be shortened. When not even one
    letter fits, the ellipsis alone if that fits, else nothing."""
    if font.size(text)[0] <= width:
        return text
    while text and font.size(text + "…")[0] > width:
        text = text[:-1]
    if text:
        return text + "…"
    return "…" if font.size("…")[0] <= width else ""


def wrap(font, text, width):
    """`text` broken into lines of at most `width` pixels (a single longer word keeps its own line)."""
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if not line or font.size(trial)[0] <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def text(surface, font, text, pos, colour=TEXT, width=None, align="left"):
    """Draw text and return its rect. `align` says which point of the text sits at `pos`: left (top-left), center
    (top-middle) or right (top-right). `width` shortens it with an ellipsis (a width of 0 leaves nothing)."""
    if width is not None:
        text = fit(font, text, width)
    if not text:                    # nothing fits or nothing was said, and pygame cannot render "" (zero width)
        rect = pygame.Rect(0, 0, 0, 0)
        setattr(rect, {"center": "midtop", "right": "topright"}.get(align, "topleft"), pos)
        return rect
    img = font.render(text, True, colour)
    rect = img.get_rect()
    if align == "center":
        rect.midtop = pos
    elif align == "right":
        rect.topright = pos
    else:
        rect.topleft = pos
    surface.blit(img, rect)
    return rect


def shade(surface, rect, rgba):
    """Darken `rect` of the surface with a translucent colour."""
    rect = pygame.Rect(rect)
    veil = pygame.Surface(rect.size, pygame.SRCALPHA)
    veil.fill(rgba)
    surface.blit(veil, rect)


# ----- buttons -------------------------------------------------------------------------------------------------
def button(ctx, rect, label, enabled, action, hint="", detail="", small=False):
    """A panel or top-bar button: draw it, register its hit box on ctx.ui.buttons and return its rect."""
    rect = pygame.Rect(rect)
    hovered = rect.collidepoint(ctx.ui.mouse)
    colour = (BUTTON_FACE_HOT if hovered else BUTTON_FACE) if enabled else BUTTON_FACE_OFF
    pygame.draw.rect(ctx.screen, colour, rect, border_radius=5)
    font = ctx.small if small else ctx.bold
    fg = TEXT if enabled else FAINT
    if detail:
        label = fit(font, label, rect.width - 16 - ctx.small.size(detail)[0] - 8)
        img = font.render(label, True, fg)
        ctx.screen.blit(img, img.get_rect(midleft=(rect.x + 8, rect.centery)))
        img = ctx.small.render(detail, True, MUTED if enabled else FAINT)
        ctx.screen.blit(img, img.get_rect(midright=(rect.right - 8, rect.centery)))
    else:
        img = font.render(label, True, fg)
        ctx.screen.blit(img, img.get_rect(center=rect.center))
    ctx.ui.buttons.append(Button(rect, label, enabled, action, hint, detail))
    return rect


def icon_button(ctx, rect, glyph, label, action, hint="", selected=False):
    """A square toggle with an icon (the map modes, the log's arrow): draw it, register its hit box on
    ctx.ui.buttons (`label` is what hints and tests call it) and return its rect. `selected` adds a gold edge."""
    rect = pygame.Rect(rect)
    hovered = rect.collidepoint(ctx.ui.mouse)
    pygame.draw.rect(ctx.screen, TOGGLE_HOT if hovered else TOGGLE_FACE, rect, border_radius=5)
    img = icon(glyph, min(rect.w, rect.h) - 10)
    ctx.screen.blit(img, img.get_rect(center=rect.center))
    if selected:
        pygame.draw.rect(ctx.screen, GOLD, rect, 1, border_radius=5)
    ctx.ui.buttons.append(Button(rect, label, True, action, hint))
    return rect


CHIP_PAD = 6        # space around a chip's icon and text


def chip_width(ctx, value, delta="", compact=False):
    """How wide `chip` is for these texts."""
    font = ctx.font if compact else ctx.bold
    return CHIP_PAD + 18 + 4 + font.size(value)[0] + (4 + ctx.small.size(delta)[0] if delta else 0) + CHIP_PAD + 2


def chip(ctx, rect, glyph, value, delta, delta_colour, label, action, hint="", compact=False):
    """A resource chip of the top bar: an icon, a value and the change in brackets, one hit box (`hint` is the hover
    card: a (title, lines) pair for ``hover_card``). `compact` sets the value in the lighter font. Returns the rect."""
    font = ctx.font if compact else ctx.bold
    rect = pygame.Rect(rect)
    if rect.collidepoint(ctx.ui.mouse):
        pygame.draw.rect(ctx.screen, ROW_HOVER, rect, border_radius=5)
        pygame.draw.rect(ctx.screen, LINE, rect, 1, border_radius=5)
    img = icon(glyph, 18)
    ctx.screen.blit(img, img.get_rect(midleft=(rect.x + CHIP_PAD, rect.centery)))
    x = rect.x + CHIP_PAD + 22
    x += text(ctx.screen, font, value, (x, rect.centery - font.get_height() // 2), TEXT).w + 4
    if delta:
        text(ctx.screen, ctx.small, delta, (x, rect.centery - ctx.small.get_height() // 2 + 1), delta_colour)
    ctx.ui.buttons.append(Button(rect, label, True, action, hint))
    return rect


def menu_button(ctx, rect, label, enabled=True, detail="", waiting=False, danger=False):
    """A pause-menu button (rounder, with the detail under the label); `waiting` is the one that wants a second
    click. Draws only: the caller keeps the hit box. Returns the rect."""
    rect = pygame.Rect(rect)
    hovered = enabled and rect.collidepoint(ctx.ui.mouse)
    colour = (MENU_WARN if waiting or (danger and hovered) else MENU_HOVER if hovered
              else MENU_BUTTON if enabled else MENU_DISABLED)
    pygame.draw.rect(ctx.screen, colour, rect, border_radius=7)
    if waiting:
        pygame.draw.rect(ctx.screen, GOLD, rect, 2, border_radius=7)
    img = ctx.bold.render(label, True, TEXT if enabled else MUTED)
    if detail:
        ctx.screen.blit(img, (rect.x + 14, rect.y + 5))
        sub = ctx.small.render(detail, True, MUTED if not waiting else TEXT)
        ctx.screen.blit(sub, (rect.x + 14, rect.y + 25))
    else:
        ctx.screen.blit(img, img.get_rect(center=rect.center))
    return rect


def flat_button(surface, rect, label, font, small_font, mouse, enabled=True, detail=""):
    """A technology-screen button (the tech palette, label left, detail right). Draws only; returns the rect."""
    rect = pygame.Rect(rect)
    hovered = enabled and rect.collidepoint(mouse)
    colour = TECH_BUTTON_HOT if hovered else TECH_BUTTON if enabled else TECH_BUTTON_OFF
    pygame.draw.rect(surface, colour, rect, border_radius=6)
    text(surface, font, label, (rect.x + 10, rect.centery - 8), TECH_TEXT if enabled else TECH_FAINT)
    if detail:
        text(surface, small_font, detail, (rect.right - 10, rect.centery - 6),
             TECH_MUTED if enabled else TECH_FAINT, align="right")
    return rect


# ----- the side panel, hints and cards -------------------------------------------------------------------------
def panel_frame(ctx):
    """(x, y, width) of the content of the side panel: where its first line starts and how wide a line may be."""
    rect = ctx.panel_rect()
    return rect.x + 14, rect.y + 10, rect.w - 28


def heading(ctx, label, y, x=None):
    """A gold heading with a rule under it, in the side panel; returns the y of the line after it."""
    rect = ctx.panel_rect()
    x = x if x is not None else rect.x + 14
    ctx.text(ctx.bold, label, (x, y), GOLD)
    pygame.draw.line(ctx.screen, LINE, (x, y + 20), (rect.right - 14, y + 20))
    return y + 26


def tip(ctx, label):
    """A one-line hint box next to the mouse."""
    ui = ctx.ui
    img = ctx.font.render(label, True, TEXT)
    box = img.get_rect(topleft=(ui.mouse[0] + 16, ui.mouse[1] + 18)).inflate(14, 8)
    box.clamp_ip(ctx.view_rect())
    pygame.draw.rect(ctx.screen, SHADE, box, border_radius=5)
    pygame.draw.rect(ctx.screen, LINE, box, 1, border_radius=5)
    ctx.screen.blit(img, img.get_rect(center=box.center))


def _split(line):
    """A card line's (left text, right text): a tab puts the rest in a right-aligned column (the amounts)."""
    left, _, right = line.partition("\t")
    return left, right


def _colours(colour):
    """(left, right) colours of a card line: one colour, or a pair for the label and the amount."""
    return colour if isinstance(colour[0], tuple) else (colour, colour)


def hover_card(ctx, title, lines, max_width=420):
    """A hover card next to the mouse: a gold title and (text, colour) lines. A tab in a line's text starts a
    right-aligned column (an amount); ("", None) is a thin rule between groups."""
    ui = ctx.ui
    texts = [_split(t) for t, c in lines if c is not None]
    widest = max([ctx.bold.size(title)[0]] + [ctx.font.size(a)[0] + (ctx.font.size(b)[0] + 24 if b else 0)
                                              for a, b in texts])
    width = min(widest + 22, max_width)
    height = 34 + sum(19 if c is not None else 9 for t, c in lines)
    box = pygame.Rect(ui.mouse[0] + 18, ui.mouse[1] + 18, width, height)
    box.clamp_ip(ctx.view_rect())
    shade(ctx.screen, box, (12, 14, 18, 240))
    pygame.draw.rect(ctx.screen, GOLD, box, 1, border_radius=6)
    ctx.text(ctx.bold, title, (box.x + 10, box.y + 6), GOLD, width - 20)
    y = box.y + 28
    for line, colour in lines:
        if colour is None:
            pygame.draw.line(ctx.screen, LINE, (box.x + 10, y + 4), (box.right - 10, y + 4))
            y += 9
            continue
        left, right = _split(line)
        left_colour, right_colour = _colours(colour)
        room = width - 20 - (ctx.font.size(right)[0] + 12 if right else 0)
        ctx.text(ctx.font, left, (box.x + 10, y), left_colour, room)
        if right:
            text(ctx.screen, ctx.font, right, (box.right - 10, y), right_colour, align="right")
        y += 19
