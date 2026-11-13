"""The odds card (battle slice 1, PR 7b, spec 8): what the selected stack would meet if it attacked the hex under the
mouse. A small card beside the hex: the men and morale of each side, the ground, the castle or the assault, a pass
crossing or an attack uphill, the generals, and ONE word from the strength ratio (Hopeless, Poor, Even, Favourable,
Overwhelming, or Unknown for a hidden enemy). Never a percentage.

Everything it says comes from ``battleview.odds_view``; this module only draws. It shows on the attack hover (a hex in
``ui.attacks`` under the mouse, with a stack selected that can attack it) and not under the HUD or a panel. The card is
drawn every frame, so its surface is kept on the view object: odds_view returns the same object until the world
changes, and only then is the card made again. Nothing here changes the game.
"""
import pygame

from ...ui import kit
from ...ui.theme import BAD_C, GOLD, GOOD_C, MUTED, TEXT, WARN_C
from ..battleview import odds_view
from ..data import GENERAL_TRAITS
from .floating import screen_point

WIDTH, PAD, GAP = 300, 10, 14
WORD_COLOUR = {"Hopeless": BAD_C, "Poor": WARN_C, "Even": TEXT, "Favourable": GOOD_C, "Overwhelming": GOLD,
               "Unknown": MUTED}
_CACHE = {"view": None, "surface": None}       # the last view drawn and its surface (the card is drawn each frame)


def draw(ctx, hud):
    """Draw the card for the attack hover, beside the hovered hex. Nothing when there is no attack hover."""
    ui, world = ctx.ui, ctx.world
    if ctx.player is None or ctx.busy or ui.replay.active or ui.hover is None or ui.hover not in ui.attacks:
        return
    if hud.covers(ctx, ui.mouse):
        return
    group = ctx.active()
    if not group:
        return
    view = odds_view(world, group, ui.hover, ctx.player)
    if not view["ok"]:
        return
    surface = _surface(ctx, view)
    area = ctx.view_rect().copy()                   # the map, not the side panel that may cover its right edge
    if ctx.ui.panel:
        area.right = min(area.right, ctx.panel_rect().x)
    x, y = screen_point(ctx, ui.hover)
    right = int(x + ctx.view.r + GAP)
    left = int(x - ctx.view.r - GAP - surface.get_width())
    rect = surface.get_rect(topleft=(right if right + surface.get_width() <= area.right else left,
                                     int(y - surface.get_height() / 2)))
    rect.clamp_ip(area)
    ctx.screen.set_clip(area)
    ctx.screen.blit(surface, rect)
    ctx.screen.set_clip(None)


def _surface(ctx, view):
    """The card's surface for this view: the one made last when the view is the same object, else a new one."""
    if _CACHE["view"] is not view:
        _CACHE["surface"] = _render(ctx, view)
        _CACHE["view"] = view
    return _CACHE["surface"]


def _side_line(name, figures):
    """"Name: 1,000 men, morale 80%", or "about" the men when only the hex is seen, or "unknown" when hidden."""
    if figures["men"] is None:
        return f"{name}: unknown"
    about = "about " if figures["access"] == "seen" else ""
    return f"{name}: {about}{figures['men']:,} men, morale {round(figures['morale'] * 100)}%"


def _rows(view):
    """The card's body: (text, colour) lines, and None for a thin rule between groups."""
    att, dfn = view["attack"], view["defence"]
    rows = [(_side_line(view["attacker_name"] or "Attacker", att), TEXT),
            (_side_line(view["defender_name"] or "Unknown", dfn), TEXT), None]
    if dfn["terrain"]:
        rows.append((f"Ground: {dfn['terrain']}, the defender's ground", MUTED))
    if dfn["assault"]:
        rows.append((f"Assault on a castle of level {dfn['castle']}", MUTED))
    elif dfn["castle"]:
        rows.append((f"Castle of level {dfn['castle']}", MUTED))
    if view["crossing"]:
        rows.append(("The attack crosses a pass: weaker on its first day", MUTED))
    if view["uphill"]:
        rows.append(("The attack comes up from lower ground: weaker all battle", MUTED))
    for who, figures in (("Your", att), ("Their", dfn)):
        if figures.get("general"):
            rows.append((f"{who} general: {GENERAL_TRAITS.get(figures['general'], figures['general'])}", MUTED))
    return rows


def _title(view):
    if view["name"]:
        return view["name"]
    return f"Attack on {view['place']}" if view["place"] else "Attack"


def _render(ctx, view):
    """The card as a surface: a gold title, the body's lines (wrapped), and the word under a small label."""
    inner = WIDTH - 2 * PAD
    body = []
    for row in _rows(view):
        if row is None:
            body.append(None)
        else:
            text, colour = row
            body.append((kit.wrap(ctx.font, text, inner), colour))
    title = kit.wrap(ctx.bold, _title(view), inner)
    height = PAD + len(title) * ctx.bold.get_linesize() + 4
    for entry in body:
        height += 9 if entry is None else len(entry[0]) * ctx.font.get_linesize()
    height += 6 + ctx.small.get_linesize() + ctx.title.get_linesize() + PAD
    surface = pygame.Surface((WIDTH, height), pygame.SRCALPHA)
    surface.fill((12, 14, 18, 240))
    pygame.draw.rect(surface, GOLD, surface.get_rect(), 1, border_radius=6)
    y = PAD
    for line in title:
        y += _blit(surface, ctx.bold, line, (PAD, y), GOLD)
    y += 4
    for entry in body:
        if entry is None:
            pygame.draw.line(surface, (60, 68, 80), (PAD, y + 4), (WIDTH - PAD, y + 4))
            y += 9
            continue
        lines, colour = entry
        for line in lines:
            y += _blit(surface, ctx.font, line, (PAD, y), colour)
    y += 6
    y += _blit(surface, ctx.small, "Odds", (PAD, y), MUTED)
    _blit(surface, ctx.title, view["word"], (PAD, y), WORD_COLOUR.get(view["word"], TEXT))
    return surface


def _blit(surface, font, text, pos, colour):
    """Draw one line and return its height."""
    surface.blit(font.render(text, True, colour), pos)
    return font.get_linesize()
