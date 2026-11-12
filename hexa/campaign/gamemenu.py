"""The in-game menu of the Age of Discovery window (Esc): save, load, options, main menu and exit.

A mixin for CampaignApp; it also owns the screen mode (window size and fullscreen).
"""
import pygame

from .. import settings as options
from . import saves

TEXT = (235, 238, 242)
MUTED = (150, 160, 172)
GOLD = (255, 214, 70)
PANEL = (28, 32, 40)
BUTTON = (44, 50, 62)
HOVER = (62, 70, 86)
DISABLED = (34, 38, 46)
WARN = (170, 60, 50)
QUICKLOAD_CONFIRM_MS = 4000
OPTION_TEXT = {
    "fullscreen": ("Fullscreen", lambda v: "On" if v else "Off"),
    "window": ("Window size", str),
    "autosave": ("Autosave", lambda v: {"off": "Off", "year": "Every year", "5 years": "Every 5 years"}[v]),
    "scroll": ("Scroll speed", str.capitalize),
    "grid": ("Hex grid", lambda v: "On" if v else "Off"),
}


class GameMenu:
    menu = None               # None, "main", "save", "load" or "options"
    menu_confirm = None       # the button waiting for a second click (overwrite, exit...)
    menu_buttons = ()         # (rect, action, enabled) of the page on screen, set by draw_menu()
    menu_rect = None          # the menu box on screen; None until draw_menu() has drawn the current page
    _slots = None
    _quickload_until = 0      # ticks until which a second F9 press loads the quicksave

    # ----- the screen -----------------------------------------------------------------
    def apply_display(self):
        """Open the window (or go fullscreen) as the settings say; the map fills whatever size it gets."""
        from . import app
        if self.settings["fullscreen"]:
            self.screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
        else:
            w, h = options.window_size(self.settings)
            try:
                sizes = pygame.display.get_desktop_sizes() if hasattr(pygame.display, "get_desktop_sizes") else []
            except pygame.error:                # no video system yet: take the size as asked
                sizes = []
            if sizes:
                w, h = min(w, sizes[0][0]), min(h, sizes[0][1] - 60)
            self.screen = pygame.display.set_mode((max(1024, w), max(600, h)))
        app.WIDTH, app.HEIGHT = self.screen.get_size()
        if hasattr(self, "camera"):
            self.clamp()

    def save_options(self):
        """Keep the options for next time. If settings.json can't be written they still apply to this game."""
        if not options.save(self.settings):
            self.toast("Option changed, but it could not be saved for next time.")

    def toggle_grid(self):
        """The faint hex grid on the close zooms (G key and the options menu)."""
        self.settings["grid"] = not self.settings["grid"]
        self.save_options()
        self.toast("Hex grid on." if self.settings["grid"] else "Hex grid off.")

    def toggle_fullscreen(self):
        self.settings["fullscreen"] = not self.settings["fullscreen"]
        self.save_options()
        self.apply_display()

    # ----- saving --------------------------------------------------------------------
    def save_to(self, slot):
        if not self.player:
            self.toast("Choose your country before saving.")
            return False
        try:
            saves.save(self.world, slot)
        except saves.SAVE_ERRORS as error:
            self.toast(f"Could not save {saves.slot_name(slot)}: {saves.failure(error)}.")
            return False
        self._slots = None
        self.toast(f"Saved: {saves.slot_name(slot)} ({self.world.date()}).")
        return True

    def load_from(self, slot):
        world = saves.load(slot)
        if world is None:
            self.toast(f"{saves.slot_name(slot)} could not be loaded.")
            return False
        self.load_world(world)
        self.toast(f"Loaded {saves.slot_name(slot)}: {world.date()}.")
        return True

    def quickload(self):
        """F9: load the quicksave. Unsaved progress is lost, so the first press only asks."""
        now = pygame.time.get_ticks()
        if self.player and not self.world.over and now > self._quickload_until:
            if not saves.meta("quick"):
                self.toast("No quicksave to load.")
                return False
            self._quickload_until = now + QUICKLOAD_CONFIRM_MS
            self.toast("Press F9 again to load the quicksave (unsaved progress is lost).")
            return False
        self._quickload_until = 0
        if not self.load_from("quick"):
            return False
        self.close_menu()
        return True

    def autosave(self):
        every = options.AUTOSAVE_TURNS[self.settings["autosave"]]
        if every and self.player and self.world.turn % every == 1 and not self.world.over:
            try:
                saves.save(self.world, "auto")
            except saves.SAVE_ERRORS as error:
                self.toast(f"Could not autosave: {saves.failure(error)}.")
                return
            self._slots = None
            self.toast("Autosaved.")

    # ----- opening and closing ------------------------------------------------------
    def open_menu(self, page="main"):
        self.menu, self.menu_confirm, self._slots = page, None, None
        self.menu_buttons, self.menu_rect = (), None        # the new page is laid out when it is drawn

    def close_menu(self):
        self.menu, self.menu_confirm = None, None
        self.menu_buttons, self.menu_rect = (), None

    def menu_key(self, key):
        if key == pygame.K_ESCAPE:
            if self.menu == "main":
                self.close_menu()
            else:
                self.open_menu("main")

    def menu_handle(self, event):
        if event.type == pygame.QUIT:
            self.running, self.result = False, "quit"
        elif event.type == pygame.KEYDOWN:
            self.menu_key(event.key)
        elif event.type == pygame.MOUSEMOTION:
            self.ui.mouse = event.pos
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self.menu_rect is None:      # clicked before this page was drawn: nothing on screen to hit
                return
            for rect, action, enabled in self.menu_buttons:
                if enabled and rect.collidepoint(event.pos):
                    self.menu_press(action)
                    return
            if not self.menu_rect.collidepoint(event.pos):
                self.close_menu()
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 3:
            self.menu_key(pygame.K_ESCAPE)

    def menu_press(self, action):
        kind = action[0]
        confirm = action != self.menu_confirm
        if kind == "resume":
            self.close_menu()
        elif kind == "page":
            self.open_menu(action[1])
        elif kind == "save":
            if saves.meta(action[1]) and confirm:
                self.menu_confirm = action
                return
            if self.save_to(action[1]):
                self.close_menu()
        elif kind == "load":
            if confirm and self.player and not self.world.over:
                self.menu_confirm = action
                return
            if self.load_from(action[1]):
                self.close_menu()
        elif kind == "option":
            key = action[1]
            if key == "fullscreen":
                self.toggle_fullscreen()
            else:
                options.cycle(self.settings, key)
                self.save_options()
                if key == "window":
                    self.apply_display()
        elif kind in ("menu", "exit"):
            if confirm and self.player and not self.world.over:
                self.menu_confirm = action
                return
            self.running, self.result = False, "menu" if kind == "menu" else "quit"
        self.menu_confirm = None

    # ----- drawing -------------------------------------------------------------------
    def _menu_button(self, rect, label, action, enabled=True, detail="", danger=False):
        rect = pygame.Rect(rect)
        hovered = enabled and rect.collidepoint(self.ui.mouse)
        waiting = action == self.menu_confirm
        color = WARN if waiting or (danger and hovered) else HOVER if hovered else BUTTON if enabled else DISABLED
        pygame.draw.rect(self.screen, color, rect, border_radius=7)
        if waiting:
            pygame.draw.rect(self.screen, GOLD, rect, 2, border_radius=7)
        img = self.bold.render(label, True, TEXT if enabled else MUTED)
        if detail:
            self.screen.blit(img, (rect.x + 14, rect.y + 5))
            sub = self.small.render(detail, True, MUTED if not waiting else TEXT)
            self.screen.blit(sub, (rect.x + 14, rect.y + 25))
        else:
            self.screen.blit(img, img.get_rect(center=rect.center))
        self.menu_buttons.append((rect, action, enabled))

    def draw_menu(self):
        screen = self.screen
        w, h = screen.get_size()
        shade = pygame.Surface((w, h), pygame.SRCALPHA)
        shade.fill((5, 7, 10, 165))
        screen.blit(shade, (0, 0))
        self.menu_buttons = []
        width = 300 if self.menu == "main" else 600
        rows = {"main": 6, "save": 9, "load": 11, "options": 6}[self.menu]
        row_h = 46 if self.menu == "main" else 52
        height = 90 + rows * row_h
        box = pygame.Rect(0, 0, width, height)
        box.center = (w // 2, h // 2)
        self.menu_rect = box
        pygame.draw.rect(screen, PANEL, box, border_radius=12)
        pygame.draw.rect(screen, GOLD, box, 1, border_radius=12)
        title = {"main": "Paused", "save": "Save game", "load": "Load game", "options": "Options"}[self.menu]
        img = self.title.render(title, True, GOLD)
        screen.blit(img, img.get_rect(midtop=(box.centerx, box.y + 16)))
        sub = f"{self.world.date()}  -  {self.world.geo.name}"
        img = self.small.render(sub, True, MUTED)
        screen.blit(img, img.get_rect(midtop=(box.centerx, box.y + 46)))
        x, y = box.x + 20, box.y + 74
        bw = width - 40
        if self.menu == "main":
            confirm = self.menu_confirm or ("",)
            for label, action, enabled in (
                    ("Resume", ("resume",), True),
                    ("Save game", ("page", "save"), bool(self.player) and not self.busy),
                    ("Load game", ("page", "load"), True),
                    ("Options", ("page", "options"), True),
                    ("Click again: leave without saving" if confirm[0] == "menu" else "Main menu", ("menu",), True),
                    ("Click again: quit without saving" if confirm[0] == "exit" else "Exit to desktop", ("exit",), True)):
                self._menu_button((x, y, bw, 38), label, action, enabled, danger=action[0] in ("menu", "exit"))
                y += row_h
            hint = "Esc: back to the game    F5: quicksave    F9: quickload    F11: fullscreen"
        elif self.menu in ("save", "load"):
            if self._slots is None:
                self._slots = dict(saves.listing())
            slots = saves.SLOTS if self.menu == "save" else saves.SPECIAL + saves.SLOTS
            for slot in slots:
                info = self._slots.get(slot)
                label = saves.slot_name(slot)
                detail = saves.describe(info) if info else "Empty"
                action = (self.menu, slot)
                if action == self.menu_confirm:
                    detail = ("Click again to overwrite this save" if self.menu == "save"
                              else "Click again: load and lose unsaved progress")
                enabled = bool(info) if self.menu == "load" else True
                self._menu_button((x, y, bw, 44), label, action, enabled, detail)
                y += row_h
            self._menu_button((x, y + 4, 120, 36), "Back", ("page", "main"))
            hint = f"Saves are kept in {saves.folder()}"
        else:
            for key, (name, show) in OPTION_TEXT.items():
                enabled = not (key == "window" and self.settings["fullscreen"])
                self._menu_button((x, y, bw, 44), name, ("option", key), enabled,
                                  f"{show(self.settings[key])}   (click to change)")
                y += row_h
            self._menu_button((x, y + 4, 120, 36), "Back", ("page", "main"))
            hint = "Options are saved for next time."
        if pygame.time.get_ticks() < self.ui.toast_until:     # the toast itself is hidden under the menu box
            img = self.small.render(self.ui.toast, True, TEXT)
        else:
            img = self.small.render(hint, True, MUTED)
        screen.blit(img, img.get_rect(midtop=(box.centerx, box.bottom + 8)))
