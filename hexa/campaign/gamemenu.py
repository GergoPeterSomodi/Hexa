"""The pause menu moved to hexa/campaign/screens/gamemenu.py; this module keeps the old import path working."""
from .screens.gamemenu import (OPTION_TEXT, QUICKLOAD_CONFIRM_MS, PauseMenu, autosave, autosave_toast, load_from,
                               quickload, save_options, save_to, toggle_fullscreen, toggle_grid)

__all__ = ["OPTION_TEXT", "QUICKLOAD_CONFIRM_MS", "PauseMenu", "autosave", "autosave_toast", "load_from", "quickload",
           "save_options", "save_to", "toggle_fullscreen", "toggle_grid"]
