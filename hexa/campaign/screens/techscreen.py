"""The technology screen (T) and the new-age idea pick, as a screen on the window's stack.

The screen covers the window: a top bar (research per season and its parts, Fund research, Close), a strip with the
current research and its queue, the grid (4 branch rows x 3 age columns) and a side card for the selected tech. The
idea modal sits over the map while the player has pending idea cards: it is the same screen with the grid closed.
One TechScreen lives as long as the window (``ctx.tech``), so the selected tech is remembered between openings; it is
on the stack while the grid is open or cards are pending (``sync``). Where things go is techlayout.py, how they look
is techdraw.py; this module keeps the state and takes the input.
"""
import pygame

from .. import tech
from ..data import ERAS
from . import Screen, techdraw
from .techlayout import idea_of, max_scroll, research_order


class TechScreen(Screen):
    def __init__(self):
        self.grid_open = False    # the technology grid is showing (T); the idea modal needs only pending cards
        self.selected = None      # key of the tech shown in the side card
        self.scroll = 0           # pixels the grid body is scrolled down
        self.buttons = ()         # (screen rect, action) for every clickable thing drawn last frame

    @property
    def opaque(self):
        """The grid hides the map; the idea modal alone is drawn over it."""
        return self.grid_open

    def on_exit(self, ctx):
        self.buttons = []

    # ----- state ------------------------------------------------------------------------
    def pending(self, ctx):
        """The idea card keys the player has to choose from now (empty when none)."""
        if not ctx.player:
            return []
        return list(ctx.world.countries[ctx.player].pending_ideas)

    def sync(self, ctx):
        """Keep the screen on the stack exactly while the grid is open or idea cards are pending."""
        wanted = self.grid_open or bool(self.pending(ctx))
        if wanted and self not in ctx.screens:
            ctx.screens.push(self)
        elif not wanted:
            ctx.screens.remove(self)

    def open(self, ctx):
        if not ctx.player:
            return
        country = ctx.world.countries[ctx.player]
        self.grid_open = True
        self.scroll = 0
        if self.selected is None:
            self.selected = country.researching or None
        self.sync(ctx)

    def close(self, ctx):
        self.grid_open = False
        self.sync(ctx)

    def toggle(self, ctx):
        if self.grid_open:
            self.close(ctx)
        else:
            self.open(ctx)

    def order(self, ctx):
        """Position of each tech on the research path: 0 is the tech being researched, 1 and up the queue."""
        return research_order(ctx.world.countries[ctx.player])

    # ----- drawing ----------------------------------------------------------------------
    def draw(self, ctx):
        """The screen when the grid is open, then the idea modal while cards are pending."""
        self.buttons = []
        if self.grid_open:
            techdraw.draw_screen(ctx, self)
        if self.pending(ctx):
            techdraw.draw_idea_modal(ctx, self)

    # ----- input ------------------------------------------------------------------------
    def handle_event(self, ctx, event):
        """Every event while the tech screen or an idea modal is up is used here: nothing reaches the map."""
        self._handle(ctx, event)
        return True

    def _handle(self, ctx, event):
        if event.type == pygame.QUIT:
            ctx.running, ctx.result = False, "quit"
            return
        pending = bool(self.pending(ctx))
        if event.type == pygame.KEYDOWN and not pending:
            if event.key == pygame.K_ESCAPE:
                self.close(ctx)
            elif event.key == pygame.K_t:
                self.toggle(ctx)
        elif event.type == pygame.MOUSEMOTION:
            ctx.ui.mouse = event.pos
        elif event.type == pygame.MOUSEWHEEL and self.grid_open and not pending:
            self.scroll = max(0, min(max_scroll(ctx.screen.get_size()), self.scroll - event.y * 40))
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button in (1, 3):
            for rect, action in reversed(self.buttons):
                if rect.collidepoint(event.pos):
                    self._press(ctx, action, event.button == 3)
                    return

    def _press(self, ctx, action, right=False):
        world, tag = ctx.world, ctx.player
        country = world.countries[tag]
        kind = action[0]
        if country.pending_ideas and kind != "pick":
            return                      # the idea pick comes first
        if kind == "close":
            self.close(ctx)
        elif kind == "queue":
            if right:
                self._unqueue(ctx, action[1])
            else:
                self.selected = action[1]
        elif kind == "node":
            if right:
                self._unqueue(ctx, action[1])
            else:
                self._click(ctx, action[1])
        elif kind == "fund":
            ok, reason = world.fund_check(tag)
            if not ok:
                ctx.toast(reason)          # the reason is the button's hint
            elif not country.researching:
                ctx.toast("Pick a tech first: the points go to the tech being researched.")
            else:
                world.fund_research(tag)
        elif kind == "pick":
            idea = idea_of(action[1])
            if world.pick_idea(tag, action[1]) and idea is not None:
                ctx.toast(f"Idea adopted: {idea.name}. {idea.text}")
            else:
                ctx.toast("That card is no longer on offer.")

    def _click(self, ctx, key):
        """Research a tech: set it as the current research (its unknown prerequisites queue first)."""
        world, tag = ctx.world, ctx.player
        country = world.countries[tag]
        t = tech.tech(key)
        self.selected = key
        if t is None or key in country.techs:
            return
        if t.era > country.era:
            ctx.toast(f"{t.name} waits for the {ERAS[t.era][0]}.")
            return
        if world.set_research(tag, key):
            now = tech.tech(country.researching).name
            if country.queue:
                ctx.toast(f"Researching {now}, then {len(country.queue)} more in the queue.")
            else:
                ctx.toast(f"Researching {now}.")
        else:
            ctx.toast(f"{t.name} cannot be researched yet.")

    def _unqueue(self, ctx, key):
        t = tech.tech(key)
        if ctx.world.unqueue(ctx.player, key) and t is not None:
            ctx.toast(f"Removed {t.name} from the queue.")
