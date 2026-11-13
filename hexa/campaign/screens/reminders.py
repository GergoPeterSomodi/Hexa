"""The end-of-turn reminder list: a small screen over the map that shows what is unfinished before End season.

``ask(ctx)`` is what ``CampaignApp.end_turn`` calls first: with the option on and something unfinished
(campaign/reminders.py says what) it puts a `ReminderScreen` on the stack and returns True, and the season waits. The
screen is not opaque: the map shows under a shade, like the pause menu. Each line is a button that goes to the thing
it names (it takes the screen off first, then runs the line's action through ``ctx.press``). "End season anyway"
(Enter) takes the screen off and ends the season for real; "Back" (Esc, a right-click or a click outside the box)
only takes it off. Space is used up and does nothing, so a double tap on Space never ends a season the player was
warned about. The lines are worked out once, when the screen opens.
"""
import pygame

from ...ui.kit import menu_button, shade
from ...ui.theme import GOLD, MUTED, PANEL_BG
from .. import reminders
from . import Screen

ROW_H, ROW_GAP, WIDTH, PAD = 46, 8, 520, 20


def ask(ctx):
    """Open the reminder list if the option is on and the player has left something unfinished. True if it opened."""
    if not ctx.settings["reminders"] or any(isinstance(screen, ReminderScreen) for screen in ctx.screens):
        return False
    found = reminders.unfinished(ctx.world, ctx.player)
    if not found:
        return False
    ctx.screens.push(ReminderScreen(found, ctx.world))
    return True


class ReminderScreen(Screen):
    def __init__(self, found, world=None):
        self.found = list(found)            # [reminders.Reminder]
        self.world = world                  # the game they are about: a quickload while the list is up drops the screen
        self.buttons = ()                   # (rect, action) of the last frame: ("go", i), ("end",) or ("back",)
        self.rect = None                    # the box on screen; None until drawn

    def update(self, ctx, dt):
        if self.world is not None and ctx.world is not self.world:
            ctx.screens.remove(self)

    # ----- input ----------------------------------------------------------------------------
    def handle_event(self, ctx, event):
        """The list takes every event while it is up: nothing reaches the map."""
        self.update(ctx, 0)
        if self not in ctx.screens:
            return False
        if event.type == pygame.QUIT:
            ctx.running, ctx.result = False, "quit"
        elif event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                self.press(ctx, ("end",))
            elif event.key == pygame.K_ESCAPE:
                self.press(ctx, ("back",))
        elif event.type == pygame.MOUSEMOTION:
            ctx.ui.mouse = event.pos
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 3:
            self.press(ctx, ("back",))
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1 and self.rect is not None:
            for rect, action in self.buttons:
                if rect.collidepoint(event.pos):
                    self.press(ctx, action)
                    return True
            if not self.rect.collidepoint(event.pos):
                self.press(ctx, ("back",))
        return True

    def press(self, ctx, action):
        ctx.screens.remove(self)
        if action[0] == "end":
            ctx.end_turn(confirmed=True)
        elif action[0] == "go":
            ctx.press(self.found[action[1]].action)

    # ----- drawing --------------------------------------------------------------------------
    def draw(self, ctx):
        screen = ctx.screen
        w, h = screen.get_size()
        shade(screen, (0, 0, w, h), (5, 7, 10, 165))
        rows = len(self.found)
        box = pygame.Rect(0, 0, WIDTH, 76 + rows * (ROW_H + ROW_GAP) + 8 + 38 + PAD)
        box.center = (w // 2, h // 2)
        self.rect = box
        pygame.draw.rect(screen, PANEL_BG, box, border_radius=12)
        pygame.draw.rect(screen, GOLD, box, 1, border_radius=12)
        img = ctx.title.render("Before you end the season", True, GOLD)
        screen.blit(img, img.get_rect(midtop=(box.centerx, box.y + 16)))
        sub = f"{ctx.world.date()}  -  {'one thing is' if rows == 1 else f'{rows} things are'} unfinished"
        img = ctx.small.render(sub, True, MUTED)
        screen.blit(img, img.get_rect(midtop=(box.centerx, box.y + 46)))
        self.buttons = []
        x, y, bw = box.x + PAD, box.y + 76, WIDTH - 2 * PAD
        for i, line in enumerate(self.found):
            rect = menu_button(ctx, (x, y, bw, ROW_H), line.text, True, line.hint)
            self.buttons.append((rect, ("go", i)))
            y += ROW_H + ROW_GAP
        y += 8
        gap = 10
        half = (bw - gap) // 2
        self.buttons.append((menu_button(ctx, (x, y, half, 38), "End season anyway"), ("end",)))
        self.buttons.append((menu_button(ctx, (x + half + gap, y, half, 38), "Back"), ("back",)))
        img = ctx.small.render("Enter: end the season    Esc: back    Click a line to go there", True, MUTED)
        screen.blit(img, img.get_rect(midtop=(box.centerx, box.bottom + 8)))
