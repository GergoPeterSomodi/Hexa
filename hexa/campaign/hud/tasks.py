"""The task flag: one "N things to do" flag under the top bar's End season button, and the list it opens.

The lines are ``campaign/reminders.unfinished`` (most pressing first). They are worked out again only when the world
changes (``world.version``, the turn, the country) or a player action refreshes the window (``forget``), never every
frame. A click on the flag opens the list; a click on a line presses the line's action (the same actions the old
end-of-turn pop-up pressed) and closes the list; a click elsewhere on the window, or Esc, closes it. At 0 things to do
the flag is gone. The flag never ends a season or asks anything, and it is off when the "Task flag" option is off
(``settings["reminders"]``).

The flag sits under End season, or left of an open side panel; it is drawn before the hint and its list last, and they
take the clicks on themselves first (``Tasks.click``);
``Hud.covers`` keeps the map from getting hovers and drags under them.
"""
import pygame

from ...ui import kit
from ...ui.icons import icon
from ...ui.theme import GOLD, MUTED, PANEL_BG, ROW_HOVER, TEXT, FAINT
from .. import reminders
from . import style

ROW_H, ROW_GAP, BOX_W, PAD, HEAD, FOOT = 44, 2, 540, 12, 34, 28
FLAG_H, FLAG_TOP = 24, 2            # the flag's height, and the gap under the top bar
LOOK = {                            # kind of reminder -> (colour kind of hud/style.py, icon)
    "battle": ("war", "battle"), "army": ("siege", "army"), "idea": ("gain", "research"),
    "research": ("gain", "research"), "fund": ("gain", "ducats"), "merchant": ("gain", "merchants"),
    "build": ("other", "castle"),
}
NOTE = "Click a line to go there  ·  Esc or a click elsewhere closes the list"


class Tasks:
    def __init__(self):
        self.open = False
        self.cache = None               # (world, (version, turn, country), lines)
        self.flag = None                # the flag's rect, the list's box and its rows [(rect, action)], from the last frame
        self.box = None
        self.rows = []

    # ----- what is to do -------------------------------------------------------------------------------
    def lines(self, ctx):
        """The unfinished things of the player, cached until something they depend on changes: the world's version and
        turn, and the country's research, idea cards, treasury and funding (the tech screen changes these without a
        world.changed(), so they are part of the key too)."""
        world, tag = ctx.world, ctx.player
        c = world.countries[tag]
        key = (world.version, world.turn, tag, c.researching, c.research, len(c.pending_ideas), c.treasury,
               c.memory.get("funded_turn"), len(c.techs))
        if self.cache is None or self.cache[0] is not world or self.cache[1] != key:
            self.cache = (world, key, reminders.unfinished(world, tag))
        return self.cache[2]

    def forget(self):
        """The window refreshed (a player action or a season): the lines are worked out again on the next frame."""
        self.cache = None

    # ----- the state of the list -----------------------------------------------------------------------
    def toggle(self):
        self.open = not self.open

    def close(self):
        self.open = False

    def key(self, event):
        """A key press the window gave the list: Esc closes it. True if the key was used up."""
        if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE and self.open:
            self.open = False
            return True
        return False

    def covers(self, pixel):
        """Whether the flag or the open list is under `pixel`."""
        return any(rect is not None and rect.collidepoint(pixel) for rect in (self.flag, self.box))

    def clear(self):
        """Nothing is drawn (a screen is up, the option is off, nothing is to do): no flag, no list, no hits."""
        self.open = False
        self.flag = self.box = None
        self.rows = []

    # ----- input ---------------------------------------------------------------------------------------
    def click(self, ctx, pixel):
        """A left click: True if the flag or the list took it. The flag toggles the list; a line presses its action and
        closes the list; any other click closes the list and is not passed on to the map."""
        if self.flag is not None and self.flag.collidepoint(pixel):
            self.open = not self.open
            return True
        if not self.open:
            return False
        if self.box is not None and self.box.collidepoint(pixel):
            for rect, action in self.rows:
                if rect.collidepoint(pixel):
                    self.open = False
                    ctx.press(action)
                    return True
            return True
        self.open = False
        return pixel[1] >= ctx.view_rect().y        # a click on the top bar closes the list and still does its job

    # ----- drawing -------------------------------------------------------------------------------------
    def draw(self, ctx):
        """The flag under the top bar's End season button, right-aligned to it, and the list when it is open."""
        self.flag = self.box = None
        self.rows = []
        if not ctx.settings["reminders"] or not ctx.player:
            self.open = False
            return
        found = self.lines(ctx)
        if not found:
            self.open = False
            return
        view = ctx.view_rect()
        label = f"{len(found)} thing{'' if len(found) == 1 else 's'} to do"
        width = kit.flag_width(ctx, label)
        hint = "The things to do before the season ends: click for the list"
        # under End season; with a side panel open, on the map beside the panel (its header and close button stay clear)
        right = ctx.panel_rect().left - 10 if ctx.ui.panel else view.right - 10
        self.flag = kit.flag(ctx, (right - width, view.y + FLAG_TOP, width, FLAG_H), "tasks", label,
                             ("tasks",), hint, self.open)
        if self.open:
            self._list(ctx, found)

    def _list(self, ctx, found):
        view, flag = ctx.view_rect(), self.flag
        width = min(BOX_W, view.w - 20)
        room = view.bottom - (flag.bottom + 4) - HEAD - FOOT - PAD
        fits = max(1, room // (ROW_H + ROW_GAP))
        shown = found[:fits]
        extra = len(found) - len(shown)
        box = pygame.Rect(flag.right - width, flag.bottom + 4, width,
                          HEAD + len(shown) * (ROW_H + ROW_GAP) + FOOT + PAD)
        self.box = box
        pygame.draw.rect(ctx.screen, PANEL_BG, box, border_radius=10)
        pygame.draw.rect(ctx.screen, GOLD, box, 1, border_radius=10)
        kit.text(ctx.screen, ctx.bold, f"Before you end {ctx.world.date()}", (box.x + PAD, box.y + PAD), GOLD)
        y = box.y + HEAD
        for line in shown:
            self._row(ctx, box, y, line)
            y += ROW_H + ROW_GAP
        note = f"+{extra} more after these  ·  " if extra else ""
        kit.text(ctx.screen, ctx.small, note + NOTE, (box.x + PAD, box.bottom - FOOT + 6), FAINT,
                 width=box.w - 2 * PAD)

    def _row(self, ctx, box, y, line):
        row = pygame.Rect(box.x + 6, y, box.w - 12, ROW_H)
        if row.collidepoint(ctx.ui.mouse):
            pygame.draw.rect(ctx.screen, ROW_HOVER, row, border_radius=6)
        kind, glyph = LOOK.get(line.kind, ("other", "flag"))
        pygame.draw.rect(ctx.screen, style.colour(kind), (row.x, row.y + 6, 3, ROW_H - 12), border_radius=2)
        img = icon(glyph, 20)
        ctx.screen.blit(img, img.get_rect(midleft=(row.x + 12, row.centery)))
        x, right = row.x + 42, row.right - 8
        kit.text(ctx.screen, ctx.bold, kit.fit(ctx.bold, line.text, right - x), (x, row.y + 7), TEXT)
        kit.text(ctx.screen, ctx.small, kit.fit(ctx.small, f"{line.hint}  ›", right - x), (x, row.y + 25), MUTED)
        self.rows.append((row, line.action))
