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
}


class GameMenu:
    menu = None               # None, "main", "save", "load" or "options"
    menu_confirm = None       # the button waiting for a second click (overwrite, exit...)
    menu_buttons = ()
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
            sizes = pygame.display.get_desktop_sizes() if hasattr(pygame.display, "get_desktop_sizes") else []
            if sizes:
                w, h = min(w, sizes[0][0]), min(h, sizes[0][1] - 60)
            self.screen = pygame.display.set_mode((max(1024, w), max(600, h)))
        app.WIDTH, app.HEIGHT = self.screen.get_size()
        if hasattr(self, "camera"):
            self.clamp()

    def toggle_fullscreen(self):
        self.settings["fullscreen"] = not self.settings["fullscreen"]
        options.save(self.settings)
        self.apply_display()

    # ----- saving --------------------------------------------------------------------
    def save_to(self, slot):
        if not self.player:
            self.toast("Choose your country before saving.")
            return False
        saves.save(self.world, slot)
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
            saves.save(self.world, "auto")
            self._slots = None
            self.toast("Autosaved.")

    # ----- opening and closing ------------------------------------------------------
    def open_menu(self, page="main"):
        self.menu, self.menu_confirm, self._slots = page, None, None

    def close_menu(self):
        self.menu, self.menu_confirm = None, None

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
            if self.load_from(action[1]):
                self.close_menu()
        elif kind == "option":
            key = action[1]
            if key == "fullscreen":
                self.toggle_fullscreen()
            else:
                options.cycle(self.settings, key)
                options.save(self.settings)
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
        rows = {"main": 6, "save": 9, "load": 11, "options": 5}[self.menu]
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
                    detail = "Click again to overwrite this save"
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
        img = self.small.render(hint, True, MUTED)
        screen.blit(img, img.get_rect(midtop=(box.centerx, box.bottom + 8)))
