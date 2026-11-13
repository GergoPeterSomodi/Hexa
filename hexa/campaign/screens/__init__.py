"""Screens of the Age of Discovery window and the stack they live on.

A screen is something that covers or dims the map and takes the input while it is up: the pause menu (Esc), the
technology screen (T), the new-age idea modal and the pause menu's pages. The map itself is not a screen: it is what the
window draws when no screen hides it. The task flag under End season is not a screen either (hud/tasks.py).

    Screen          the base class: draw(ctx), handle_event(ctx, event) -> consumed, update(ctx, dt),
                    opaque (it hides the map: the window does not draw the map or the HUD under it),
                    on_enter(ctx) / on_exit(ctx) (the stack calls them as the screen goes on and off)
    ScreenStack     the screens that are up, bottom to top. push, pop, remove, replace, clear, top; the window
                    asks hides_map before it draws the map and offers each event to the top screen first.

The stack belongs to the window (``CampaignApp.screens``), not to the game manager: the architecture review
(docs/architecture/review-2026-11-12.md, 3.1) first put "the manager's stack" in campaign/game.py, but a screen is
drawn with pygame and answers to the window's mouse, fonts and size, and the manager stays pygame-free and is played
without a window by tests, tools and the AI. Game state that outlives a window (the world, saves, the autosave) stays
with the manager; what a screen shows is the window's business.

The ctx. A screen never imports the window module. It is handed the window as ``ctx`` and uses only these public
attributes and methods of it:

    drawing     ctx.screen (the surface), ctx.ui (mouse, toast, toast_until), ctx.title / ctx.small (fonts)
                and ctx for the kit helpers (``menu_button(ctx, ...)``)
    the game    ctx.game (the GameManager: save, autosave), ctx.world, ctx.player, ctx.settings, ctx.busy,
                ctx.toast(text), ctx.load_world(game), ctx.open_country(tag), ctx.apply_display(),
                ctx.press(action) (a button's action tuple) and ctx.end_turn()
    the loop    ctx.running and ctx.result (a screen that quits or leaves for the start menu sets them),
                ctx.screens (the stack itself), ctx.pause (the PauseMenu), ctx.tech (the TechScreen),
                ctx.quickload_until, ctx.close_menu()
"""


class Screen:
    """One thing on the stack. Subclasses override what they need; every hook has a harmless default."""

    opaque = False              # True: it hides the map, so the window does not draw the map or the HUD under it

    def on_enter(self, ctx):
        """The stack has just put the screen on top."""

    def on_exit(self, ctx):
        """The stack has just taken the screen off."""

    def update(self, ctx, dt):
        """Once a frame, dt milliseconds after the last."""

    def handle_event(self, ctx, event):
        """Take an event. Return True when it was used, so that nothing below sees it."""
        return False

    def draw(self, ctx):
        """Draw the screen on ctx.screen, over whatever is below it."""


class ScreenStack:
    """The screens that are up, bottom first. Made by the window, which is the ctx it hands to every screen."""

    def __init__(self, ctx):
        self.ctx = ctx
        self.items = []

    def __len__(self):
        return len(self.items)

    def __bool__(self):
        return bool(self.items)

    def __iter__(self):
        return iter(self.items)

    def __contains__(self, screen):
        return screen in self.items

    @property
    def top(self):
        """The screen on top, or None."""
        return self.items[-1] if self.items else None

    @property
    def hides_map(self):
        """Whether an opaque screen is up, so the map and the HUD under it are not drawn."""
        return any(screen.opaque for screen in self.items)

    def push(self, screen):
        self.items.append(screen)
        screen.on_enter(self.ctx)

    def pop(self):
        """Take the top screen off and return it (None when the stack is empty)."""
        if not self.items:
            return None
        screen = self.items.pop()
        screen.on_exit(self.ctx)
        return screen

    def remove(self, screen):
        """Take a screen off wherever it is in the stack. Does nothing when it is not there."""
        if screen in self.items:
            self.items.remove(screen)
            screen.on_exit(self.ctx)

    def replace(self, screen):
        """Swap the top screen for another (a plain push when the stack is empty)."""
        self.pop()
        self.push(screen)

    def clear(self):
        while self.items:
            self.pop()

    def handle_event(self, event):
        """Offer the event to the top screen first, then to the ones below it until one uses it. An opaque
        screen ends the search: what it hides gets no input. Returns whether a screen used the event."""
        for screen in reversed(list(self.items)):
            if screen.handle_event(self.ctx, event):
                return True
            if screen.opaque:
                break
        return False

    def update(self, dt):
        for screen in list(self.items):
            screen.update(self.ctx, dt)

    def draw(self):
        """Draw the screens bottom to top, starting at the highest opaque one (below it nothing shows)."""
        start = max((i for i, screen in enumerate(self.items) if screen.opaque), default=0)
        for screen in list(self.items[start:]):
            screen.draw(self.ctx)
