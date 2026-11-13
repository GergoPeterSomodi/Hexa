"""The pause menu (Esc) of the Age of Discovery window, and the save, load and options work behind it.

``PauseMenu`` is a screen (see screens/__init__.py): it keeps the page that is up ("main", "save", "load", "options" or
"question", None when closed), the button waiting for a second click, the yes/no question, and where the last drawn
page put its buttons. The menu is not opaque: the map is drawn under a shade. The module's functions do what the menu
and the F5, F9 and F11 keys share, with the window as ``ctx``: save and load through ``ctx.game`` (the GameManager),
the options in ``ctx.settings``, the screen mode through ``ctx.apply_display()``.
"""
import pygame

from ... import settings as options
from ...ui.kit import menu_button as draw_menu_button, shade
from ...ui.theme import GOLD, MUTED, PANEL_BG as PANEL, TEXT
from .. import saves
from ..game import GameManager
from . import Screen

QUICKLOAD_CONFIRM_MS = 4000
OPTION_TEXT = {
    "fullscreen": ("Fullscreen", lambda v: "On" if v else "Off"),
    "window": ("Window size", str),
    "autosave": ("Autosave", lambda v: {"off": "Off", "year": "Every year", "5 years": "Every 5 years"}[v]),
    "scroll": ("Scroll speed", str.capitalize),
    "grid": ("Hex grid", lambda v: "On" if v else "Off"),
    "pass_names": ("Pass names", lambda v: "On" if v else "Off"),
    "movement": ("Movement speed", {"off": "Instant", "normal": "Normal", "slow": "Slow"}.get),
    "reminders": ("End-of-turn reminders", lambda v: "On" if v else "Off"),
    "battle_timing": ("Battle timing", {"clash": "Clash (default)", "full": "Quick battles"}.get),
}
PAGE_TITLES = {"main": "Paused", "save": "Save game", "load": "Load game", "options": "Options"}


# ----- options, saving and loading: what the menu and the keys share ---------------------------------------------
def save_options(ctx):
    """Keep the options for next time. If settings.json can't be written they still apply to this game."""
    if not options.save(ctx.settings):
        ctx.toast("Option changed, but it could not be saved for next time.")


def toggle_grid(ctx):
    """The faint hex grid on the close zooms (G key and the options menu)."""
    ctx.settings["grid"] = not ctx.settings["grid"]
    save_options(ctx)
    ctx.toast("Hex grid on." if ctx.settings["grid"] else "Hex grid off.")


def toggle_fullscreen(ctx):
    ctx.settings["fullscreen"] = not ctx.settings["fullscreen"]
    save_options(ctx)
    ctx.apply_display()


def save_to(ctx, slot):
    if not ctx.player:
        ctx.toast("Choose your country before saving.")
        return False
    try:
        ctx.game.save(slot)
    except saves.SAVE_ERRORS as error:
        ctx.toast(f"Could not save {saves.slot_name(slot)}: {saves.failure(error)}.")
        return False
    ctx.pause.slots = None
    ctx.toast(f"Saved: {saves.slot_name(slot)} ({ctx.world.date()}).")
    return True


def load_from(ctx, slot):
    game = GameManager.load(slot)
    if game is None:
        ctx.toast(f"{saves.slot_name(slot)} could not be loaded.")
        return False
    ctx.load_world(game)
    ctx.toast(f"Loaded {saves.slot_name(slot)}: {game.world.date()}.")
    return True


def quickload(ctx):
    """F9: load the quicksave. Unsaved progress is lost, so the first press only asks."""
    now = pygame.time.get_ticks()
    if ctx.player and not ctx.world.over and now > ctx.quickload_until:
        if not saves.meta("quick"):
            ctx.toast("No quicksave to load.")
            return False
        ctx.quickload_until = now + QUICKLOAD_CONFIRM_MS
        ctx.toast("Press F9 again to load the quicksave (unsaved progress is lost).")
        return False
    ctx.quickload_until = 0
    if not load_from(ctx, "quick"):
        return False
    ctx.close_menu()
    return True


def autosave(ctx):
    ctx.game.autosave_every = options.AUTOSAVE_TURNS[ctx.settings["autosave"]]
    try:
        saved = ctx.game.autosave()
    except saves.SAVE_ERRORS as error:
        return autosave_toast(ctx, False, error)
    autosave_toast(ctx, saved, None)


def autosave_toast(ctx, saved, error):
    """Tell the player how the autosave went (nothing if none was due)."""
    if error:
        ctx.toast(f"Could not autosave: {saves.failure(error)}.")
    elif saved:
        ctx.pause.slots = None
        ctx.toast("Autosaved.")


# ----- the screen --------------------------------------------------------------------------------------------------
class PauseMenu(Screen):
    page = None               # None (closed), "main", "save", "load", "options" or "question"
    confirm = None            # the button waiting for a second click (overwrite a save, load over progress)
    question = None           # (title, text lines, [(label, action, danger)]) of the "question" page
    buttons = ()              # (rect, action, enabled) of the page on screen, set by draw()
    rect = None               # the menu box on screen; None until draw() has drawn the current page
    slots = None              # {slot: header} of the save folder, read when a page needs it; None: read again

    def on_exit(self, ctx):
        self.page, self.confirm, self.question = None, None, None
        self.buttons, self.rect = (), None

    # ----- opening and closing ------------------------------------------------------
    def open(self, ctx, page="main"):
        self.page, self.confirm, self.slots = page, None, None
        self.buttons, self.rect = (), None        # the new page is laid out when it is drawn
        if self not in ctx.screens:
            ctx.screens.push(self)

    def close(self, ctx):
        self.on_exit(ctx)
        ctx.screens.remove(self)

    def ask(self, ctx, title, lines, choices):
        """Open a Yes/No style question in the pause-menu box. choices: (label, action, danger) per button."""
        self.open(ctx, "question")
        self.question = (title, list(lines), list(choices))

    def leave(self, ctx, kind):
        """Quit the program ("exit") or go to the main menu ("menu"), without asking."""
        ctx.running, ctx.result = False, "menu" if kind in ("menu", "menu_now") else "quit"

    # ----- input ----------------------------------------------------------------------
    def key(self, ctx, key):
        if key == pygame.K_ESCAPE:
            if self.page == "main":
                self.close(ctx)
            else:
                self.open(ctx, "main")

    def handle_event(self, ctx, event):
        """The menu takes every event while it is up: nothing reaches the map."""
        if event.type == pygame.QUIT:
            ctx.running, ctx.result = False, "quit"
        elif event.type == pygame.KEYDOWN:
            self.key(ctx, event.key)
        elif event.type == pygame.MOUSEMOTION:
            ctx.ui.mouse = event.pos
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            self._click(ctx, event.pos)
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 3:
            self.key(ctx, pygame.K_ESCAPE)
        return True

    def _click(self, ctx, pos):
        if self.rect is None:       # clicked before this page was drawn: nothing on screen to hit
            return
        for rect, action, enabled in self.buttons:
            if enabled and rect.collidepoint(pos):
                self.press(ctx, action)
                return
        if not self.rect.collidepoint(pos):
            self.close(ctx)

    def press(self, ctx, action):
        kind = action[0]
        confirm = action != self.confirm
        if kind == "resume":
            self.close(ctx)
        elif kind == "page":
            self.open(ctx, action[1])
        elif kind == "country":                 # the war alert: show the enemy in the country panel
            self.close(ctx)
            ctx.open_country(action[1])
            return
        elif kind == "save":
            if saves.meta(action[1]) and confirm:
                self.confirm = action
                return
            if save_to(ctx, action[1]):
                self.close(ctx)
        elif kind == "load":
            if confirm and ctx.player and not ctx.world.over:
                self.confirm = action
                return
            if load_from(ctx, action[1]):
                self.close(ctx)
        elif kind == "option":
            key = action[1]
            if key == "fullscreen":
                toggle_fullscreen(ctx)
            else:
                options.cycle(ctx.settings, key)
                save_options(ctx)
                if key == "window":
                    ctx.apply_display()
        elif kind in ("menu", "exit"):
            if ctx.player and not ctx.world.over:          # a game would be lost: ask first
                if kind == "menu":
                    self.ask(ctx, "Leave to the main menu?", ["Unsaved progress is lost. Save first to keep this game."],
                             [("Yes, main menu", ("menu_now",), True), ("No, stay", ("page", "main"), False)])
                else:
                    self.ask(ctx, "Exit to desktop?", ["Unsaved progress is lost. Save first to keep this game."],
                             [("Yes, exit", ("exit_now",), True), ("No, stay", ("page", "main"), False)])
                return
            self.leave(ctx, kind)
        elif kind in ("menu_now", "exit_now"):
            self.leave(ctx, kind)
        self.confirm = None

    # ----- drawing -------------------------------------------------------------------
    def _button(self, ctx, rect, label, action, enabled=True, detail="", danger=False):
        rect = draw_menu_button(ctx, rect, label, enabled, detail, action == self.confirm, danger)
        self.buttons.append((rect, action, enabled))

    def draw(self, ctx):
        screen = ctx.screen
        w, h = screen.get_size()
        shade(screen, (0, 0, w, h), (5, 7, 10, 165))
        self.buttons = []
        if self.page == "question":
            width = 480
            body_h = 22 * len(self.question[1]) + 14
            height = 90 + body_h + 58
        else:
            width = 300 if self.page == "main" else 600
            rows = {"main": 6, "save": 9, "load": 11, "options": len(OPTION_TEXT) + 1}[self.page]   # + the Back row
            row_h = 46 if self.page == "main" else 52
            height = 90 + rows * row_h
        box = pygame.Rect(0, 0, width, height)
        box.center = (w // 2, h // 2)
        self.rect = box
        pygame.draw.rect(screen, PANEL, box, border_radius=12)
        pygame.draw.rect(screen, GOLD, box, 1, border_radius=12)
        title = self.question[0] if self.page == "question" else PAGE_TITLES[self.page]
        img = ctx.title.render(title, True, GOLD)
        screen.blit(img, img.get_rect(midtop=(box.centerx, box.y + 16)))
        sub = f"{ctx.world.date()}  -  {ctx.world.geo.name}"
        img = ctx.small.render(sub, True, MUTED)
        screen.blit(img, img.get_rect(midtop=(box.centerx, box.y + 46)))
        x, y = box.x + 20, box.y + 74
        bw = width - 40
        if self.page == "question":
            for line in self.question[1]:
                img = ctx.small.render(line, True, MUTED)
                screen.blit(img, img.get_rect(midtop=(box.centerx, y)))
                y += 22
            y += 14
            choices = self.question[2]
            gap = 10
            cw = (bw - gap * (len(choices) - 1)) // len(choices)
            for i, (label, action, danger) in enumerate(choices):
                self._button(ctx, (x + i * (cw + gap), y, cw, 38), label, action, True, danger=danger)
            hint = "Esc: go back"
        elif self.page == "main":
            for label, action, enabled in (
                    ("Resume", ("resume",), True),
                    ("Save game", ("page", "save"), bool(ctx.player) and not ctx.busy),
                    ("Load game", ("page", "load"), True),
                    ("Options", ("page", "options"), True),
                    ("Main menu", ("menu",), True),
                    ("Exit to desktop", ("exit",), True)):
                self._button(ctx, (x, y, bw, 38), label, action, enabled, danger=action[0] in ("menu", "exit"))
                y += row_h
            hint = "Esc: back to the game    F5: quicksave    F9: quickload    F11: fullscreen"
        elif self.page in ("save", "load"):
            if self.slots is None:
                self.slots = dict(saves.listing())
            slots = saves.SLOTS if self.page == "save" else saves.SPECIAL + saves.SLOTS
            for slot in slots:
                info = self.slots.get(slot)
                label = saves.slot_name(slot)
                detail = saves.describe(info) if info else "Empty"
                action = (self.page, slot)
                if action == self.confirm:
                    detail = ("Click again to overwrite this save" if self.page == "save"
                              else "Click again: load and lose unsaved progress")
                enabled = bool(info) if self.page == "load" else True
                self._button(ctx, (x, y, bw, 44), label, action, enabled, detail)
                y += row_h
            self._button(ctx, (x, y + 4, 120, 36), "Back", ("page", "main"))
            hint = f"Saves are kept in {saves.folder()}"
        else:
            for key, (name, show) in OPTION_TEXT.items():
                enabled = not (key == "window" and ctx.settings["fullscreen"])
                self._button(ctx, (x, y, bw, 44), name, ("option", key), enabled,
                                  f"{show(ctx.settings[key])}   (click to change)")
                y += row_h
            self._button(ctx, (x, y + 4, 120, 36), "Back", ("page", "main"))
            hint = "Options are saved for next time."
        if pygame.time.get_ticks() < ctx.ui.toast_until:     # the toast itself is hidden under the menu box
            img = ctx.small.render(ctx.ui.toast, True, TEXT)
        else:
            img = ctx.small.render(hint, True, MUTED)
        screen.blit(img, img.get_rect(midtop=(box.centerx, box.bottom + 8)))
