"""Colour tokens and the one font loader of the windows.

Each window keeps the look it always had, so a few tokens have two values: the Age of Discovery map window and its
pause menu use the plain names, the technology screen its ``TECH_*`` palette (a touch cooler, with its own gold) and
the start menu ``MENU_BG``. Importers rename them (``from ..ui.theme import TECH_GOLD as GOLD``) so their code
reads as before. Fonts are made through ``new_font`` / ``font`` (never ``pygame.font.SysFont`` in a window module).
"""
import pygame

# ----- the Age of Discovery window (app.py) and its pause menu (gamemenu.py) -----------------------------------
BG = (24, 28, 34)
PANEL_BG = (28, 32, 40)
LINE = (60, 68, 80)
TEXT = (235, 238, 242)
MUTED = (150, 160, 172)
FAINT = (105, 115, 128)
GOLD = (255, 214, 70)
GOOD_C = (120, 200, 120)
BAD_C = (230, 110, 100)
BUTTON_FACE = (52, 74, 112)       # a panel or top-bar button, enabled
BUTTON_FACE_HOT = (70, 95, 140)   # ... under the mouse
BUTTON_FACE_OFF = (44, 48, 56)    # ... disabled
SHADE = (12, 14, 18)              # hover cards and toasts

# the pause menu's own buttons
MENU_BUTTON = (44, 50, 62)
MENU_HOVER = (62, 70, 86)
MENU_DISABLED = (34, 38, 46)
MENU_WARN = (170, 60, 50)

# ----- the start menu (menu.py) --------------------------------------------------------------------------------
MENU_BG = (22, 28, 38)

# ----- the technology screen (techscreen.py) -------------------------------------------------------------------
TECH_BAR = (15, 18, 24)
TECH_BG = (21, 24, 31)
TECH_PANEL = (27, 31, 39)
TECH_LINE = (54, 60, 72)
TECH_TEXT = (234, 237, 242)
TECH_MUTED = (152, 160, 172)
TECH_FAINT = (96, 104, 116)
TECH_GOLD = (255, 206, 70)
TECH_GREEN = (100, 200, 120)
TECH_RED = (230, 100, 92)
TECH_WHITE = (250, 250, 250)
TECH_BUTTON = (50, 74, 112)
TECH_BUTTON_HOT = (70, 95, 140)
TECH_BUTTON_OFF = (44, 48, 56)
TECH_DARK_INK = (30, 36, 46)
TECH_QUEUE_TEXT = (200, 168, 88)

# ----- fonts ---------------------------------------------------------------------------------------------------
SANS = "segoeui,arial"
SERIF = "georgia,timesnewroman,serif"
_fonts = {}


def new_font(size, bold=False, serif=False):
    """A new font of the window's sans (or serif) family."""
    if not pygame.font.get_init():
        pygame.font.init()
    return pygame.font.SysFont(SERIF if serif else SANS, size, bold=bold)


def font(size, bold=False, serif=False):
    """The same font as new_font, made once and kept (for code that asks for a font on every frame)."""
    key = (size, bold, serif)
    if key not in _fonts:
        _fonts[key] = new_font(size, bold, serif)
    return _fonts[key]
