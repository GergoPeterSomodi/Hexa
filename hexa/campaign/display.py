"""Opening the Age of Discovery window as the options say."""
import pygame

from .. import settings as options


def open_window(settings):
    """The display surface: fullscreen, or the window size of the options kept inside the desktop."""
    if settings["fullscreen"]:
        return pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    w, h = options.window_size(settings)
    try:
        sizes = pygame.display.get_desktop_sizes() if hasattr(pygame.display, "get_desktop_sizes") else []
    except pygame.error:                # no video system yet: take the size as asked
        sizes = []
    if sizes:
        w, h = min(w, sizes[0][0]), min(h, sizes[0][1] - 60)
    return pygame.display.set_mode((max(1024, w), max(600, h)))
