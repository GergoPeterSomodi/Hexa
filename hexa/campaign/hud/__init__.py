"""The heads-up display of the Age of Discovery window: what is drawn over the map, apart from the side panels.

    topbar.py     the resource chips, date, map modes, Menu and End season (``resources`` has the numbers)
    tasks.py      the task flag under End season and its list of unfinished things (``campaign/reminders`` says what)
    floating.py   ribbons that rise from the hex where something happened (``feed`` says what)
    battles.py    the battle marks on the map: the crossed-swords badge and the front-line bar (``battleview`` says what)
    actionlog.py  the collapsible log in the bottom-left corner (``feed`` has its lines)
    style.py      the colour and icon of each of the six kinds of event, shared by the ribbons and the log

``Hud`` holds what these remember between frames (the ribbons in the air, the log's filter and scroll, a camera glide)
and is made with each game (``CampaignApp._set_game``). The window calls its ``draw_*`` methods from ``draw()`` and
``press`` / ``wheel`` from its input code. Like the panels, the HUD reads the world and registers buttons; it never
changes the game (selecting a stack and moving the camera are the window's own state).
"""
import pygame

from ...ui.theme import INFO_C, INK
from . import actionlog, battles, odds, tasks, topbar
from .floating import Floaters

GLIDE_MS = 260          # how long the camera takes to reach a place the log names
PING_MS = 1300          # how long that hex stays ringed
MAX_AGE = 2.0           # seconds: a ribbon for something told longer ago than this is not floated


class Hud:
    def __init__(self):
        self.floaters = Floaters()
        self.marks = battles.Marks()
        self.log = actionlog.LogState()
        self.readings = None            # the top bar's cached snapshot (topbar.readings)
        self.glide = None               # (hex to show, start ms, ms of the last frame): the camera follows the hex
        self.ping = None                # (hex, start ms): the ring after a jump
        self.waiting = []               # (replay time, item): ribbons that wait for the replay to reach their hex
        self.tasks = tasks.Tasks()      # the task flag and its open list (hud/tasks.py)

    # ----- drawing ----------------------------------------------------------------------------------
    @staticmethod
    def hidden(ctx):
        """Whether the map is not on screen: a screen (the technology screen, the idea modal, the pause menu) is over
        it, so the window's stack is not empty."""
        return bool(ctx.screens)

    def covers(self, ctx, pixel):
        """Whether the HUD, not the map, is under `pixel`: the top bar, the minimap, or the action log's box (open or
        the collapsed bar). Clicks, drags and hovers there never reach the map."""
        if pixel[1] < ctx.view_rect().y or ctx.minimap_rect().inflate(6, 6).collidepoint(pixel):
            return True
        if self.tasks.covers(pixel):
            return True
        return bool(self.log.box and self.log.box.collidepoint(pixel))

    def draw_world(self, ctx):
        """Over the map, under the panels: the camera glide, the ribbons and the ring of a jump. Nothing happens while
        the map is hidden: the feed keeps what it was told, and what is older than MAX_AGE seconds when the map
        shows again is dropped."""
        if self.hidden(ctx):
            return
        now = pygame.time.get_ticks()
        self._glide(ctx, now)
        self.floaters.add(ctx, self._timed(ctx, ctx.game.feed.take_floating(MAX_AGE)), now)
        self.marks.draw(ctx, self)              # under the ribbons: a ribbon covers the badge
        odds.draw(ctx, self)                    # the odds card of the attack hover (hud/odds.py)
        self.floaters.draw(ctx, now)
        self._ring(ctx, now)

    def _timed(self, ctx, items):
        """The ribbons to float now. While the movement replay runs (campaign/replay.py) a ribbon waits until the walks
        have got to its hex, so the "Attacked!" shows when the army arrives; when it ends or is skipped, all go."""
        replay = ctx.ui.replay
        self.waiting += [(replay.ready_at(item.pos) if replay.active and item.pos else 0, item) for item in items]
        now = replay.t if replay.active else float("inf")
        ready = [item for when, item in self.waiting if when <= now]
        self.waiting = [(when, item) for when, item in self.waiting if when > now]
        return ready

    def draw_top(self, ctx):
        topbar.draw(ctx, self)

    def draw_tasks(self, ctx):
        """The task flag and its list: drawn last, over the side panel. Nothing while a screen is up."""
        if self.hidden(ctx):
            self.tasks.clear()
            return
        self.tasks.draw(ctx)

    def draw_log(self, ctx):
        actionlog.draw(ctx, self)

    # ----- input ------------------------------------------------------------------------------------
    def press(self, ctx, action):
        """A ("log", ...) action of the log's buttons."""
        actionlog.press(ctx, self, action)

    def wheel(self, ctx, dy):
        """The mouse wheel turned by `dy`: True if the log used it."""
        return actionlog.wheel(ctx, self, dy)

    def go(self, ctx, pos):
        """Glide the camera to hex `pos`, ring it, and select the player's stack that stands on it."""
        now = pygame.time.get_ticks()
        self.glide = (pos, now, now)
        self.ping = (pos, now)
        ctx.ui.province = ctx.world.provinces.get(pos)          # as a click on the map sets it
        unit = ctx.world.unit_at(pos)
        if unit is not None and unit.owner == ctx.player:
            ctx.select_unit(unit)

    # ----- the glide and the ring -------------------------------------------------------------------
    def _glide(self, ctx, now):
        """Move the camera a share of the way to the hex each frame, so that it arrives GLIDE_MS after the click. The
        target is worked out again every frame from the hex, so a zoom on the way does not leave a stale position."""
        if self.glide is None:
            return
        pos, since, last = self.glide
        if ctx.drag is not None:
            self.glide = None
            return
        here = list(ctx.camera)
        ctx.look_at(pos)                    # the camera that shows the hex (clamped): the target
        left = GLIDE_MS - (last - since)
        if now - since >= GLIDE_MS or left <= 0:
            self.glide = None
            return
        share = min(1.0, (now - last) / left)
        ctx.camera[:] = [a + (b - a) * share for a, b in zip(here, ctx.camera)]
        self.glide = (pos, since, now)

    def _ring(self, ctx, now):
        if self.ping is None:
            return
        pos, since = self.ping
        t = (now - since) / PING_MS
        if t >= 1:
            self.ping = None
            return
        rect = ctx.view_rect()
        x, y = ctx.view.center(pos)
        centre = (int(x - ctx.camera[0] + rect.x), int(y - ctx.camera[1] + rect.y))
        radius = max(14, int(ctx.view.r * 0.9)) + int(10 * t)
        ctx.screen.set_clip(rect)
        pygame.draw.circle(ctx.screen, INK, centre, radius, 4)
        pygame.draw.circle(ctx.screen, INFO_C, centre, radius, 2)
        ctx.screen.set_clip(None)
