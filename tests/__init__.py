"""The tests. Importing this package changes one default of ``hexa.settings`` for the whole test process.

The window plays the moves the player can see hex by hex and blocks End season while it does (campaign/replay.py). That is
on in the shipped game (``SHIPPED_DEFAULTS``) and off here, so the many tests that press End season and expect the next
season at once do not wait. The tests of the replay switch it on themselves (``app.settings["movement"] = "normal"``),
and ``test_settings`` checks the shipped value.
"""
from hexa import settings

SHIPPED_DEFAULTS = dict(settings.DEFAULTS)
settings.DEFAULTS.update(movement="off")
