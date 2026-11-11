"""The start menu: pick the game mode and, for colonisation, how to start and how to win."""
import pygame

from . import __version__
from .campaign import saves
from .colony.rules import GOAL_NAMES, START_NAMES

BG = (22, 28, 38)
TEXT = (235, 238, 242)
MUTED = (150, 160, 172)
GOLD = (255, 214, 70)

MODES = {"campaign": ("Age of Discovery", "Europe and the Mediterranean in 1480. Pick any country, build an economy "
                                         "of markets and trade, and colonise the unknown world."),
         "conquest": ("Conquest", "Small map, one rival kingdom. Capture its castle or have the best score after 40 turns."),
         "colony": ("Colonisation", "Big unknown continent. Survive the winters, deal with native tribes, "
                                    "out-grow two rival companies and trade with your homeland.")}
MAP_NAMES = {"europe": "Europe 1480", "random": "Random world"}
MAP_HELP = {"europe": "The real map: Europe, North Africa and the Mediterranean, with the Americas to discover.",
            "random": "A new world every game, grown by wave function collapse: invented countries and continents."}
START_HELP = {"sea": "Start on a ship with 2 colonists, a soldier and a pioneer. You choose where to land.",
              "land": "Start with a small colony already on the coast, plus a soldier, pioneer and scout."}
GOAL_HELP = {"survive": "After 10 years (40 seasons) the best colony wins: population, colonies, buildings, gold.",
             "independence": "Grow to 12 population and 3 soldiers, declare independence, then beat the royal army.",
             "endless": "No time limit. Build the biggest colony you can, and don't get wiped out."}


class Menu:
    def __init__(self, screen, settings):
        self.screen = screen
        self.settings = dict(settings)
        self.title = pygame.font.SysFont("segoeui,arial", 54, bold=True)
        self.head = pygame.font.SysFont("segoeui,arial", 18, bold=True)
        self.font = pygame.font.SysFont("segoeui,arial", 16)
        self.button_font = pygame.font.SysFont("segoeui,arial", 17, bold=True)
        self.hover = None
        self.error = self.settings.pop("error", None)     # e.g. a save that could not be loaded
        self.last_save = saves.latest()
        self.last_meta = saves.meta(self.last_save) if self.last_save else None

    def _rows(self):
        rows = [("mode", "Game mode", {k: v[0] for k, v in MODES.items()})]
        if self.settings["mode"] == "colony":
            rows += [("start", "Start", START_NAMES), ("goal", "Goal", GOAL_NAMES)]
        if self.settings["mode"] == "campaign":
            rows += [("map", "Map", MAP_NAMES)]
        return rows

    def _layout(self):
        """[(rect, key, value)] for every option button, plus the Start button rect."""
        buttons, y = [], 190
        for key, _, options in self._rows():
            x = 250
            for value, label in options.items():
                w = max(150, self.button_font.size(label)[0] + 30)
                buttons.append((pygame.Rect(x, y, w, 42), key, value))
                x += w + 12
            y += 100
        start = pygame.Rect(self.screen.get_width() // 2 - 110, y + 30, 220, 54)
        if self.last_meta:
            start.x += 120
        return buttons, start

    def _continue_rect(self, start):
        return pygame.Rect(start.x - 240, start.y, 220, 54) if self.last_meta else None

    def run(self):
        """Returns the chosen settings, or None if the window was closed."""
        clock = pygame.time.Clock()
        pygame.display.set_caption("Hexa")
        while True:
            buttons, start = self._layout()
            for event in pygame.event.get():
                if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE):
                    return None
                if event.type == pygame.KEYDOWN and event.key in (pygame.K_RETURN, pygame.K_SPACE):
                    return self.settings
                if event.type == pygame.MOUSEMOTION:
                    self.hover = event.pos
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    if start.collidepoint(event.pos):
                        return self.settings
                    resume = self._continue_rect(start)
                    if resume and resume.collidepoint(event.pos):
                        return dict(self.settings, mode="campaign", load=self.last_save)
                    for rect, key, value in buttons:
                        if rect.collidepoint(event.pos):
                            self.settings[key] = value
            self.draw(buttons, start)
            pygame.display.flip()
            clock.tick(60)

    def draw(self, buttons, start):
        screen = self.screen
        screen.fill(BG)
        cx = screen.get_width() // 2
        title = self.title.render("Hexa", True, GOLD)
        screen.blit(title, title.get_rect(center=(cx, 80)))
        sub = self.font.render("A small turn-based strategy game on a hex map", True, MUTED)
        screen.blit(sub, sub.get_rect(center=(cx, 128)))

        for i, (key, heading, _) in enumerate(self._rows()):
            y = 190 + i * 100
            screen.blit(self.head.render(heading, True, TEXT), (90, y + 10))
            help_text = {"mode": MODES[self.settings["mode"]][1], "start": START_HELP.get(self.settings["start"]),
                         "goal": GOAL_HELP.get(self.settings["goal"]),
                         "map": MAP_HELP.get(self.settings.get("map", "europe"))}[key]
            screen.blit(self.font.render(help_text, True, MUTED), (90, y + 54))
        for rect, key, value in buttons:
            chosen = self.settings.get(key, "europe") == value
            hovered = self.hover and rect.collidepoint(self.hover)
            color = (60, 100, 160) if chosen else (58, 64, 76) if hovered else (42, 47, 58)
            pygame.draw.rect(screen, color, rect, border_radius=8)
            if chosen:
                pygame.draw.rect(screen, GOLD, rect, 2, border_radius=8)
            label = {"mode": MODES.get(value, ("",))[0], "start": START_NAMES.get(value),
                     "goal": GOAL_NAMES.get(value), "map": MAP_NAMES.get(value)}[key]
            text = self.button_font.render(label, True, TEXT)
            screen.blit(text, text.get_rect(center=rect.center))

        hovered = self.hover and start.collidepoint(self.hover)
        pygame.draw.rect(screen, (60, 150, 80) if hovered else (50, 125, 68), start, border_radius=10)
        label = self.button_font.render("Start game", True, TEXT)
        screen.blit(label, label.get_rect(center=start.center))
        resume = self._continue_rect(start)
        if resume:
            hovered = self.hover and resume.collidepoint(self.hover)
            pygame.draw.rect(screen, (70, 90, 150) if hovered else (55, 75, 128), resume, border_radius=10)
            label = self.button_font.render("Continue", True, TEXT)
            screen.blit(label, label.get_rect(center=(resume.centerx, resume.centery - 8)))
            info = self.last_meta
            sub = self.font.render(f"{info['country'] or 'Campaign'}, {info['date']}", True, (200, 210, 230))
            screen.blit(sub, sub.get_rect(center=(resume.centerx, resume.centery + 13)))
        if self.error:
            text = self.head.render(self.error, True, (240, 120, 105))
            screen.blit(text, text.get_rect(center=(cx, start.bottom + 34)))
        foot = self.font.render("Enter: start    Esc: quit", True, MUTED)
        screen.blit(foot, foot.get_rect(center=(cx, screen.get_height() - 30)))
        version = self.font.render(f"v{__version__}", True, MUTED)
        screen.blit(version, version.get_rect(bottomright=(screen.get_width() - 14, screen.get_height() - 12)))
