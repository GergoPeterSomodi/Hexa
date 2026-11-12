"""The drawing helpers every window shares, in today's ("classic") look. Immediate mode: call them while drawing.

A ``ctx`` is the window object that is drawing (``CampaignApp``): it has ``screen``, ``ui`` (with ``mouse`` and the
``buttons`` and ``hoverables`` lists), the fonts ``font`` / ``small`` / ``bold`` / ``title`` and the geometry methods
``panel_rect()`` and ``view_rect()``. ``button`` registers a hit box on ``ctx.ui.buttons``; the window's ``press()``
gets the action. Text helpers (``fit``, ``wrap``, ``text``) need only a font and a surface.
"""
import pygame

from .theme import (BUTTON_FACE, BUTTON_FACE_HOT, BUTTON_FACE_OFF, FAINT, GOLD, LINE, MENU_BUTTON, MENU_DISABLED,
                    MENU_HOVER, MENU_WARN, MUTED, SHADE, TECH_BUTTON, TECH_BUTTON_HOT, TECH_BUTTON_OFF, TECH_FAINT,
                    TECH_MUTED, TECH_TEXT, TEXT)


class Button:
    """A hit box on screen: its rectangle, what it says, whether it works, the action to press() and its hint."""

    def __init__(self, rect, label, enabled, action, hint="", detail=""):
        self.rect, self.label, self.enabled, self.action, self.hint, self.detail = \
            rect, label, enabled, action, hint, detail


# ----- text ----------------------------------------------------------------------------------------------------
def fit(font, text, width):
    """`text` cut down to `width` pixels, ending in an ellipsis when it had to be shortened."""
    if font.size(text)[0] <= width:
        return text
    while text and font.size(text + "…")[0] > width:
        text = text[:-1]
    return text + "…" if text else ""


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
    (top-middle) or right (top-right). `width` shortens it with an ellipsis."""
    if width:
        text = fit(font, text, width)
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


def hover_card(ctx, title, lines):
    """A hover card next to the mouse: a gold title and (text, colour) lines."""
    ui = ctx.ui
    width = max([ctx.bold.size(title)[0]] + [ctx.font.size(t)[0] for t, _ in lines]) + 22
    width = min(width, 420)
    box = pygame.Rect(ui.mouse[0] + 18, ui.mouse[1] + 18, width, 32 + 19 * len(lines))
    box.clamp_ip(ctx.view_rect())
    shade(ctx.screen, box, (12, 14, 18, 240))
    pygame.draw.rect(ctx.screen, GOLD, box, 1, border_radius=6)
    ctx.text(ctx.bold, title, (box.x + 10, box.y + 6), GOLD, width - 20)
    for i, (line, colour) in enumerate(lines):
        ctx.text(ctx.font, line, (box.x + 10, box.y + 28 + i * 19), colour, width - 20)
